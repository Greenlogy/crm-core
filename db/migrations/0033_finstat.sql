-- migrate:up

-- 0033_finstat – modul 5, fáza F1 (návrh DB `05-obchod-navrh-db.md` časti 1.12, 8 a 13.3):
-- údaje Finstatu na firme (tržby, zisk, zamestnanci, vznik, Z-skóre, dlhy, konkurz), cache odpovedí 24 h,
-- denný limit požiadaviek, výstrahy (company_risk) a overenie firmy pred obchodom (company_check).
-- Finstat volá Worker (kľúče iba vo wrangler secret); databáza ukladá iba výsledok.

-- ============================================================================
-- 1. Údaje Finstatu na firme
-- ============================================================================

ALTER TABLE company
  ADD COLUMN revenue_eur      numeric(14,2),
  ADD COLUMN profit_eur       numeric(14,2),
  ADD COLUMN finance_year     smallint CHECK (finance_year BETWEEN 1990 AND 2100),
  ADD COLUMN employees_range  text,
  ADD COLUMN founded_on       date,
  ADD COLUMN z_score          numeric(6,2),
  ADD COLUMN has_debts        boolean,
  ADD COLUMN debts            jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(debts) = 'array'),
  ADD COLUMN insolvency_kind  text CHECK (insolvency_kind IN ('konkurz', 'restrukturalizacia')),
  ADD COLUMN insolvency_since date,
  ADD COLUMN cancelled_on     date;
COMMENT ON COLUMN company.revenue_eur IS 'tržby za rok finance_year (Finstat)';
COMMENT ON COLUMN company.z_score IS 'Altmanovo Z-skóre (Finstat): pod 1,23 riziko úpadku, 1,23–2,90 šedá zóna, nad 2,90 stabilná';
COMMENT ON COLUMN company.debts IS 'dlhy a nedoplatky z verejných zoznamov (Finstat): [{veritel, suma_eur, k_datumu}]';
COMMENT ON COLUMN company.insolvency_kind IS 'konkurz alebo reštrukturalizácia (Finstat); NULL = nie';
COMMENT ON COLUMN company.cancelled_on IS 'firma zrušená / vymazaná z registra (Finstat)';

-- Zápis údajov Finstatu: iba tieto stĺpce, smie každý, kto firmu vidí (verejné údaje registra); audit „synchronizácia“
CREATE FUNCTION company_apply_finstat(p_company_id uuid, p_data jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT crm_company_access(p_company_id, 'view') THEN
    RAISE EXCEPTION 'Firma neexistuje alebo ju nevidíte.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'company_apply_finstat: očakávaný objekt údajov';
  END IF;
  v_prev := current_setting('app.change_source', true);
  PERFORM set_config('app.change_source', 'synchronizacia', true);
  UPDATE company SET
    revenue_eur      = (p_data->>'revenue_eur')::numeric,
    profit_eur       = (p_data->>'profit_eur')::numeric,
    finance_year     = (p_data->>'finance_year')::smallint,
    employees_range  = nullif(p_data->>'employees_range', ''),
    founded_on       = (p_data->>'founded_on')::date,
    z_score          = (p_data->>'z_score')::numeric,
    has_debts        = (p_data->>'has_debts')::boolean,
    debts            = coalesce(p_data->'debts', '[]'),
    insolvency_kind  = nullif(p_data->>'insolvency_kind', ''),
    insolvency_since = (p_data->>'insolvency_since')::date,
    cancelled_on     = (p_data->>'cancelled_on')::date,
    payment_rating   = (nullif(p_data->>'payment_rating', ''))::payment_rating,
    finstat_url      = coalesce(nullif(p_data->>'finstat_url', ''), finstat_url),
    finstat_updated_at = now()
  WHERE id = p_company_id;
  PERFORM set_config('app.change_source', coalesce(v_prev, ''), true);
END;
$$;

-- ============================================================================
-- 2. Cache odpovedí Finstatu (24 h) a denný limit požiadaviek
-- ============================================================================

CREATE TABLE finstat_cache (
  kind       text NOT NULL CHECK (kind IN ('detail', 'autocomplete')),
  key        text NOT NULL CHECK (length(key) BETWEEN 1 AND 200),   -- IČO alebo normalizovaný dotaz
  fetched_at timestamptz NOT NULL DEFAULT now(),
  data       jsonb NOT NULL,
  PRIMARY KEY (kind, key)
);
CREATE INDEX finstat_cache_fetched_idx ON finstat_cache (fetched_at);
COMMENT ON TABLE finstat_cache IS 'odpovede Finstatu 24 h (môžu obsahovať mená štatutárov); záznamy staršie ako 7 dní sa mažú pri zápise';

CREATE TABLE finstat_usage (
  day      date PRIMARY KEY,
  requests integer NOT NULL DEFAULT 0 CHECK (requests >= 0)
);
COMMENT ON TABLE finstat_usage IS 'počet požiadaviek na Finstat za deň (Europe/Bratislava)';

INSERT INTO app_setting (key, value, description)
VALUES ('finstat_daily_limit', '500', 'najviac požiadaviek na Finstat za deň (cache 24 h sa do limitu nepočíta)');

-- Platná odpoveď z cache (najviac 24 h), inak NULL
CREATE FUNCTION finstat_cache_get(p_kind text, p_key text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT data FROM finstat_cache
   WHERE crm_session_ok() AND kind = p_kind AND key = p_key AND fetched_at > now() - interval '24 hours'
$$;

-- Povolenie jednej požiadavky na Finstat: započíta ju, ak je pod denným limitom
CREATE FUNCTION finstat_request_allow() RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_limit integer := coalesce((SELECT (value #>> '{}')::integer FROM app_setting WHERE key = 'finstat_daily_limit'), 0);
  v_n     integer;
BEGIN
  IF NOT crm_session_ok() THEN
    RETURN false;
  END IF;
  INSERT INTO finstat_usage (day, requests) VALUES (crm_today(), 1)
  ON CONFLICT (day) DO UPDATE SET requests = finstat_usage.requests + 1
  WHERE finstat_usage.requests < v_limit
  RETURNING requests INTO v_n;
  RETURN v_n IS NOT NULL AND v_n <= v_limit;
END;
$$;

-- Uloženie odpovede do cache; staré záznamy (nad 7 dní) sa pri tom zmažú
CREATE FUNCTION finstat_cache_put(p_kind text, p_key text, p_data jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_session_ok() THEN
    RAISE EXCEPTION 'Bez prihláseného používateľa.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO finstat_cache (kind, key, data) VALUES (p_kind, p_key, p_data)
  ON CONFLICT (kind, key) DO UPDATE SET data = EXCLUDED.data, fetched_at = now();
  DELETE FROM finstat_cache WHERE fetched_at < now() - interval '7 days';
END;
$$;

-- ============================================================================
-- 3. Výstrahy a overenie firmy (časť 4.1 zadania, obrazovka 31)
-- ============================================================================

-- Výstrahy firmy: dlhy, konkurz/reštrukturalizácia, rating E/X, Z-skóre pod 1,23. Schválenie: konkurz/reštr., E/X.
CREATE FUNCTION company_risk(p_company_id uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'warnings', coalesce(jsonb_agg(w.code ORDER BY w.ord) FILTER (WHERE w.code IS NOT NULL), '[]'),
           'needs_approval', bool_or(w.approval) IS TRUE,
           'z_band', CASE WHEN c.z_score IS NULL THEN NULL
                          WHEN c.z_score < 1.23 THEN 'riziko'
                          WHEN c.z_score <= 2.90 THEN 'seda_zona'
                          ELSE 'stabilna' END,
           'finstat_updated_at', c.finstat_updated_at)
    FROM company c
    LEFT JOIN LATERAL (VALUES
      (1, CASE WHEN c.has_debts OR jsonb_array_length(c.debts) > 0 THEN 'dlhy' END, false),
      (2, CASE WHEN c.insolvency_kind IS NOT NULL THEN c.insolvency_kind END, true),
      (3, CASE WHEN c.payment_rating IN ('E', 'X') THEN 'rating_' || lower(c.payment_rating::text) END,
          c.payment_rating IN ('E', 'X')),
      (4, CASE WHEN c.z_score < 1.23 THEN 'z_skore' END, false),
      (5, CASE WHEN c.cancelled_on IS NOT NULL THEN 'zrusena' END, false)
    ) AS w(ord, code, approval) ON w.code IS NOT NULL
   WHERE c.id = p_company_id
   GROUP BY c.id
$$;
COMMENT ON FUNCTION company_risk(uuid) IS 'výstrahy Finstatu pre firmu, obchod a ponuku; needs_approval = konkurz/reštrukturalizácia alebo rating E/X (bez osobných údajov)';

-- Overenie firmy podľa IČO pred založením obchodu: je v CRM, zákazník, vlastník, otvorené obchody a ich vlastníci.
-- Kto firmu nevidí, dostane iba názov, stav, meno vlastníka a mená vlastníkov otvorených obchodov (ako pri duplicite IČO).
CREATE FUNCTION company_check(p_ico text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_ico   text := regexp_replace(coalesce(p_ico, ''), '\s', '', 'g');
  c       company;
  v_sees  boolean;
BEGIN
  IF NOT crm_session_ok() THEN
    RETURN NULL;
  END IF;
  IF v_ico ~ '^[0-9]{1,8}$' THEN
    v_ico := lpad(v_ico, 8, '0');
  END IF;
  SELECT * INTO c FROM company
   WHERE ico = v_ico AND org_id = ANY (crm_user_orgs())
   ORDER BY country = 'SK' DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('exists', false, 'ico', v_ico);
  END IF;
  v_sees := crm_company_access(c.id, 'view');
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'exists', true,
    'ico', c.ico,
    'company_id', CASE WHEN v_sees THEN c.id END,
    'visible', v_sees,
    'name', c.name,
    'is_customer', c.is_customer,
    'status', c.status,
    'owner_id', c.owner_id,
    'owner_name', (SELECT name FROM app_user WHERE id = c.owner_id),
    'owner_is_me', c.owner_id = crm_active_user_id(),
    'contacts', CASE WHEN v_sees THEN (SELECT count(*) FROM company_contact WHERE company_id = c.id) END,
    'contracts', CASE WHEN v_sees THEN (
        SELECT coalesce(jsonb_agg(jsonb_build_object('number', k.number, 'state', contract_state(k),
                                                     'effective_to', contract_effective_to(k)) ORDER BY k.valid_from DESC NULLS LAST), '[]')
          FROM contract k WHERE k.company_id = c.id) END,
    'open_deals', (
        SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'deal_id', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.id END,
                 'name', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.name END,
                 'owner_name', (SELECT name FROM app_user WHERE id = d.owner_id)) ORDER BY d.created_at), '[]')
          FROM deal d WHERE d.company_id = c.id AND d.closed_at IS NULL),
    'risk', company_risk(c.id)));
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS company_check(text);
DROP FUNCTION IF EXISTS company_risk(uuid);
DROP FUNCTION IF EXISTS finstat_cache_put(text, text, jsonb);
DROP FUNCTION IF EXISTS finstat_request_allow();
DROP FUNCTION IF EXISTS finstat_cache_get(text, text);
DELETE FROM app_setting WHERE key = 'finstat_daily_limit';
DROP TABLE IF EXISTS finstat_usage;
DROP TABLE IF EXISTS finstat_cache;
DROP FUNCTION IF EXISTS company_apply_finstat(uuid, jsonb);
ALTER TABLE company
  DROP COLUMN cancelled_on,
  DROP COLUMN insolvency_since,
  DROP COLUMN insolvency_kind,
  DROP COLUMN debts,
  DROP COLUMN has_debts,
  DROP COLUMN z_score,
  DROP COLUMN founded_on,
  DROP COLUMN employees_range,
  DROP COLUMN finance_year,
  DROP COLUMN profit_eur,
  DROP COLUMN revenue_eur;
