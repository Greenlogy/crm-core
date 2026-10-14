-- migrate:up

-- 0028_zmluvy_nocny_beh – modul 4, fáza F4 (návrh DB časť 27, odpovede 34–36):
-- nočný beh zmlúv (regulácia, cenník, prolongácia, príznaky, upozornenia, stav zákazníka), upozornenia (zvonček),
-- záznam behov, testovací dátum pre ručný beh na Teste.
-- Cron sa nemení: Worker volá contract_daily_run() v tom istom behu ako oom_daily_run() (22:05 a 23:05 UTC).

-- ============================================================================
-- 1. Testovací „dnešný“ dátum (iba spojenie vlastníka databázy, časť 27.7)
-- ============================================================================

-- crm.today nastaví contract_daily_run_at na čas transakcie. Spojenie aplikácie (crm_app) ho ignoruje,
-- takže aplikácia dátum podstrčiť nevie.
CREATE OR REPLACE FUNCTION crm_today() RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN nullif(current_setting('crm.today', true), '') IS NOT NULL AND crm_owner_session()
              THEN current_setting('crm.today', true)::date
              ELSE (now() AT TIME ZONE 'Europe/Bratislava')::date END
$$;
COMMENT ON FUNCTION crm_today() IS 'dnes v Europe/Bratislava; v spojení vlastníka databázy testovací dátum z nastavenia crm.today (ručný nočný beh)';

-- Stav zákazníka k crm_today() (doteraz now()), aby ručný beh k dátumu počítal stav k tomu istému dňu
CREATE OR REPLACE FUNCTION customer_refresh(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_status   customer_status;
  v_former   boolean;
  v_producer boolean;
  v_prev     text;
  v_changed  boolean;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_refresh: zadaj práve jedno z company_id / person_id';
  END IF;
  v_status   := customer_status_calc(p_company_id, p_person_id, crm_today());
  v_former   := customer_is_former_calc(p_company_id, p_person_id);
  v_producer := customer_is_producer_calc(p_company_id, p_person_id);
  v_prev     := crm_as_system(true);

  IF p_company_id IS NOT NULL THEN
    UPDATE company c
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = c.is_former_customer OR v_former, is_producer = v_producer
     WHERE c.id = p_company_id AND c.is_customer
       AND (c.status, c.status_source, c.is_former_customer, c.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, c.is_former_customer OR v_former, v_producer);
  ELSE
    UPDATE contact p
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = p.is_former_customer OR v_former, is_producer = v_producer
     WHERE p.id = p_person_id AND p.is_household
       AND (p.status, p.status_source, p.is_former_customer, p.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, p.is_former_customer OR v_former, v_producer);
  END IF;
  v_changed := FOUND;

  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_changed;
END;
$$;

-- ============================================================================
-- 2. Záznam behov (časť 27.6) a upozornenia (časť 27.5)
-- ============================================================================

CREATE TABLE job_run (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  job         text NOT NULL CHECK (job IN ('zmluvy')),
  run_date    date NOT NULL,
  test_date   boolean NOT NULL DEFAULT false,
  started_at  timestamptz NOT NULL DEFAULT now(),
  finished_at timestamptz,
  result      jsonb NOT NULL DEFAULT '{}',
  errors      jsonb NOT NULL DEFAULT '[]' CHECK (jsonb_typeof(errors) = 'array'),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX job_run_job_date_idx ON job_run (job, run_date DESC);
COMMENT ON TABLE job_run IS 'denník nočných behov: počty po krokoch, spätne zapísaný cenník a chyby (zmluva, krok, kód, text bez osobných údajov); číta admin a Nákup';
COMMENT ON COLUMN job_run.test_date IS 'ručný beh s iným ako dnešným dátumom (Test)';
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON job_run FOR EACH ROW EXECUTE FUNCTION set_updated_at();
ALTER TABLE job_run ENABLE ROW LEVEL SECURITY;
-- Denník behov číta admin a Nákup (zmluvy so spätne zapísaným cenníkom)
CREATE FUNCTION crm_can_see_job_runs() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_admin()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = crm_active_user_id() AND t.code = 'nakup')
$$;
CREATE POLICY job_run_select ON job_run FOR SELECT USING (crm_can_see_job_runs());

CREATE TABLE notification (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id            uuid NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
  kind               text NOT NULL CHECK (kind IN ('konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova',
                                                   'vynimka_rozhodnutie', 'nocny_beh_chyba')),
  contract_id        uuid REFERENCES contract (id) ON DELETE CASCADE,
  price_exception_id uuid REFERENCES price_exception (id) ON DELETE CASCADE,
  job_run_id         uuid REFERENCES job_run (id) ON DELETE CASCADE,
  ref_date           date,
  detail             text,
  created_at         timestamptz NOT NULL DEFAULT now(),
  read_at            timestamptz
);
CREATE INDEX notification_user_idx ON notification (user_id, created_at DESC);
CREATE INDEX notification_unread_idx ON notification (user_id) WHERE read_at IS NULL;
CREATE INDEX notification_contract_idx ON notification (contract_id, kind, ref_date);
COMMENT ON TABLE notification IS 'upozornenia v CRM (zvonček); bez auditu; detail bez osobných údajov (číslo zmluvy, rok, dátum)';
COMMENT ON COLUMN notification.ref_date IS 'konci_4_mesiace, sprolongovana, neprolongovana: koniec zmluvy, ku ktorému upozornenie patrí (posiela sa raz)';
ALTER TABLE notification ENABLE ROW LEVEL SECURITY;
CREATE POLICY notification_select ON notification FOR SELECT USING (user_id = crm_active_user_id());
CREATE POLICY notification_update ON notification FOR UPDATE USING (user_id = crm_active_user_id())
  WITH CHECK (user_id = crm_active_user_id());

-- Používateľ vidí spoločnosť (tím so všetkými spoločnosťami alebo priradenie)
CREATE FUNCTION crm_user_sees_org(p_user uuid, p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = p_user
                    AND (t.all_orgs OR EXISTS (SELECT 1 FROM app_user_org uo WHERE uo.user_id = u.id AND uo.org_id = p_org)))
$$;
REVOKE EXECUTE ON FUNCTION crm_user_sees_org(uuid, uuid) FROM PUBLIC;

-- Schvaľovatelia cien spoločnosti (a pri p_with_ceo aj tím CEO), nie deaktivovaní
CREATE FUNCTION notification_approvers(p_org uuid, p_with_ceo boolean) RETURNS uuid[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(array_agg(u.id ORDER BY u.id), '{}')
    FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.status <> 'deaktivovany'
     AND (u.approves_prices OR (p_with_ceo AND t.code = 'ceo'))
     AND crm_user_sees_org(u.id, p_org)
$$;
REVOKE EXECUTE ON FUNCTION notification_approvers(uuid, boolean) FROM PUBLIC;

-- Komu ide upozornenie k zmluve (odpoveď 35): obchodník zmluvy, inak vlastník zákazníka, inak schvaľovatelia cien
CREATE FUNCTION notification_contract_users(p_contract_id uuid) RETURNS uuid[]
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k      contract;
  v_user uuid;
BEGIN
  SELECT * INTO k FROM contract WHERE id = p_contract_id;
  FOREACH v_user IN ARRAY ARRAY[k.owner_id,
                                (SELECT owner_id FROM company WHERE id = k.company_id),
                                (SELECT owner_id FROM contact WHERE id = k.person_id)] LOOP
    IF v_user IS NOT NULL AND EXISTS (SELECT 1 FROM app_user WHERE id = v_user AND status <> 'deaktivovany') THEN
      RETURN ARRAY[v_user];
    END IF;
  END LOOP;
  RETURN notification_approvers(k.org_id, false);
END;
$$;
REVOKE EXECUTE ON FUNCTION notification_contract_users(uuid) FROM PUBLIC;

CREATE FUNCTION notification_add(p_users uuid[], p_kind text, p_contract_id uuid, p_exception_id uuid, p_job_run_id uuid,
                                 p_ref_date date, p_detail text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_n integer;
BEGIN
  INSERT INTO notification (user_id, kind, contract_id, price_exception_id, job_run_id, ref_date, detail)
  SELECT DISTINCT u, p_kind, p_contract_id, p_exception_id, p_job_run_id, p_ref_date, p_detail
    FROM unnest(coalesce(p_users, '{}')) AS u
   WHERE u IS NOT NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION notification_add(uuid[], text, uuid, uuid, uuid, date, text) FROM PUBLIC;

-- Upozornenia na udalosti (hneď, nie v noci): Pod hranicou bez výnimky; nová žiadosť o výnimku; rozhodnutie
CREATE FUNCTION contract_flag_notify() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k contract;
BEGIN
  SELECT * INTO k FROM contract WHERE id = NEW.contract_id;
  PERFORM notification_add(notification_approvers(k.org_id, true), 'pod_hranicou', k.id, NULL, NULL, NULL,
                           format('Zmluva %s: cena pod hranicou bez výnimky%s', k.number,
                                  CASE WHEN NEW.year IS NOT NULL THEN format(' (rok %s)', NEW.year) ELSE '' END));
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_notify AFTER INSERT ON contract_flag FOR EACH ROW
  WHEN (NEW.code = 'pod_hranicou_bez_vynimky' AND NEW.resolved_at IS NULL) EXECUTE FUNCTION contract_flag_notify();

CREATE FUNCTION price_exception_notify() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_years text := array_to_string(NEW.years, ', ');
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM notification_add(array_remove(notification_approvers(NEW.org_id, false), NEW.requested_by), 'vynimka_nova',
                             NULL, NEW.id, NULL, NULL, format('Nová žiadosť o výnimku z ceny (rok %s)', v_years));
  ELSIF OLD.status = 'caka' AND NEW.status IN ('schvalena', 'zamietnuta') THEN
    PERFORM notification_add(ARRAY[NEW.requested_by], 'vynimka_rozhodnutie', NULL, NEW.id, NULL, NULL,
                             format('Výnimka z ceny (rok %s) je %s', v_years,
                                    CASE NEW.status WHEN 'schvalena' THEN 'schválená' ELSE 'zamietnutá' END));
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_notify AFTER INSERT OR UPDATE OF status ON price_exception FOR EACH ROW
  EXECUTE FUNCTION price_exception_notify();

-- Potvrdenie navrhnutého produktu prolongácie (odpoveď 36): uzavretie príznaku s poznámkou
ALTER TABLE contract_flag ADD COLUMN resolved_note text;
COMMENT ON COLUMN contract_flag.resolved_note IS 'poznámka pri ručnom uzavretí (napr. Servis potvrdil produkt prolongácie)';

-- ============================================================================
-- 3. Časový rez pri zmene cenovej regulácie (časť 27.3)
-- ============================================================================

-- Ten istý tarif v druhom cenníku (ANO ↔ NIE) zo systémových prekladov produktov OOM (DDx → NIE, target_extra.ano → ANO).
-- Odvodzuje sa za behu, lebo produkty zakladá skript cenníkov až po migrácii. NULL = pár neexistuje (malé podniky).
CREATE FUNCTION product_regulation_pair(p_product_id uuid) RETURNS uuid
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT q.id
    FROM product p
    JOIN import_alias x ON x.is_system AND x.kind = 'produkt_oom' AND x.target_extra ? 'ano'
                       AND p.code IN (x.target, x.target_extra ->> 'ano')
    JOIN product q ON q.code = CASE WHEN p.code = x.target THEN x.target_extra ->> 'ano' ELSE x.target END
   WHERE p.id = p_product_id
   LIMIT 1
$$;

-- Hodnota regulácie pred zmenou (aby výpočet vedel produkt aj pred prvou zapísanou zmenou) a značka nočného behu
ALTER TABLE oom_price_regulation_change
  ADD COLUMN prev_value          boolean,
  ADD COLUMN contract_applied_at timestamptz;
COMMENT ON COLUMN oom_price_regulation_change.prev_value IS 'regulácia platná deň pred touto zmenou (zapíše oom_price_regulation_set)';
COMMENT ON COLUMN oom_price_regulation_change.contract_applied_at IS 'kedy nočný beh prepočítal ceny zmlúv na OOM (krok 1)';
-- zmeny, ktoré už platia, nočný beh zmlúv nespracúva znova (pred 0028 ceny zmlúv reguláciu nepoznali)
UPDATE oom_price_regulation_change SET contract_applied_at = now() WHERE valid_from <= crm_today();

CREATE OR REPLACE FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_prev boolean;
BEGIN
  IF p_valid_from IS NULL THEN
    RAISE EXCEPTION 'Zadaj dátum „platí od“.' USING ERRCODE = 'check_violation';
  END IF;
  -- prístup k OOM a právo ho upraviť (RLS a spúšťač Aktívneho OOM) overí zápis bez zmeny hodnoty
  UPDATE oom SET price_regulation = price_regulation WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  -- regulácia deň pred zmenou: posledná skoršia zmena, inak dnešná hodnota na OOM (0028)
  SELECT value INTO v_prev FROM oom_price_regulation_change
   WHERE oom_id = p_oom_id AND valid_from < p_valid_from ORDER BY valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT price_regulation INTO v_prev FROM oom WHERE id = p_oom_id;
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, prev_value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, v_prev, NULL, crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = NULL, contract_applied_at = NULL, created_by = EXCLUDED.created_by;
  PERFORM oom_price_regulation_apply(p_oom_id, crm_today());
END;
$$;

CREATE FUNCTION contract_regulated_product(p product, p_value boolean) RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN p.price_regulation IS NULL OR p_value IS NULL OR p_value = p.price_regulation THEN p.id
              ELSE product_regulation_pair(p.id) END
$$;

-- Obdobie OOM v zmluve rozdelené podľa zmien regulácie, ktoré už nastali (≤ dnes); pre každú časť produkt
-- podľa regulácie (NULL = pár neexistuje → bez ceny). Produkt, ktorý od regulácie nezávisí, ostáva v celom období.
CREATE FUNCTION contract_regulation_segments(p_oom_id uuid, p_product_id uuid, p_from date, p_to date)
RETURNS TABLE (seg_product uuid, seg_from date, seg_to date)
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  p      product;
  ch     record;
  v_val  boolean;
  v_prod uuid;
  v_new  uuid;
  v_from date := p_from;
BEGIN
  SELECT * INTO p FROM product WHERE id = p_product_id;
  IF p.price_regulation IS NULL THEN
    RETURN QUERY SELECT p_product_id, p_from, p_to;
    RETURN;
  END IF;
  -- regulácia na začiatku: posledná zmena do začiatku, inak hodnota pred prvou neskoršou zmenou, inak produkt bez zmeny
  SELECT x.value INTO v_val FROM oom_price_regulation_change x
   WHERE x.oom_id = p_oom_id AND x.valid_from <= p_from AND x.valid_from <= crm_today()
   ORDER BY x.valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT x.prev_value INTO v_val FROM oom_price_regulation_change x
     WHERE x.oom_id = p_oom_id AND x.valid_from > p_from AND x.valid_from <= crm_today()
     ORDER BY x.valid_from LIMIT 1;
  END IF;
  v_prod := contract_regulated_product(p, v_val);
  FOR ch IN SELECT x.valid_from, x.value FROM oom_price_regulation_change x
             WHERE x.oom_id = p_oom_id AND x.valid_from > p_from AND x.valid_from <= crm_today()
               AND (p_to IS NULL OR x.valid_from <= p_to)
             ORDER BY x.valid_from LOOP
    v_new := contract_regulated_product(p, ch.value);
    IF v_new IS DISTINCT FROM v_prod THEN
      RETURN QUERY SELECT v_prod, v_from, ch.valid_from - 1;
      v_from := ch.valid_from;
      v_prod := v_new;
    END IF;
  END LOOP;
  RETURN QUERY SELECT v_prod, v_from, p_to;
END;
$$;

-- Ceny z cenníkov (0026) s časovým rezom podľa regulácie: komodita a ZEM po častiach obdobia s produktom podľa regulácie
CREATE OR REPLACE FUNCTION contract_price_list_rows(p_contract_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  c      contract;
  co     record;
  q      record;
  s      record;
  v_out  jsonb := '[]';
  v_pid  uuid;
  v_last date;
  v_open boolean;
  v_mod  price_model;
  v_list datemultirange;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  FOR co IN
    SELECT x.*, o.type AS oom_type, o.public_lighting, p.code AS product_code, p.tariff_type
      FROM contract_oom x JOIN oom o ON o.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
     WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
  LOOP
    IF c.type::text LIKE 'dodavka%' AND c.list_price AND co.product_id IS NOT NULL AND co.oom_type = 'spotreba' THEN
      FOR s IN SELECT * FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to)
                WHERE seg_product IS NOT NULL LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('komodita', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items(s.seg_product, s.seg_from, s.seg_to) p);
      END LOOP;
    END IF;
    IF c.type = 'dodavka_domacnost' AND co.oom_type = 'spotreba' AND co.product_id IS NOT NULL THEN
      FOR s IN SELECT * FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to)
                WHERE seg_product IS NOT NULL LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('zem', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items((SELECT id FROM product WHERE code = 'zem'), s.seg_from, s.seg_to,
                                                       s.seg_product) p);
      END LOOP;
    END IF;
    IF co.program_id IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('program', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items(co.program_id, co.valid_from, co.valid_to) p);
    END IF;
    IF c.type IN ('dodavka_firma_nn', 'dodavka_firma_vn') AND NOT c.list_price AND co.oom_type = 'spotreba' THEN
      v_list := '{}';
      -- FIX s automatickou prolongáciou: po poslednom roku s cenou cenník nad 30 MWh (otázka 23)
      SELECT max(p.valid_to), bool_or(p.valid_to IS NULL), (array_agg(p.price_model ORDER BY p.valid_from DESC))[1]
        INTO v_last, v_open, v_mod
        FROM contract_price p
       WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita' AND p.source = 'import'
         AND p.price_model <> 'cennik';
      IF c.auto_prolong AND v_mod = 'fix' AND NOT v_open AND (co.valid_to IS NULL OR co.valid_to > v_last) THEN
        v_pid := (SELECT id FROM product WHERE code = CASE WHEN co.public_lighting AND co.tariff_type = 'jednotarif'
                                                           THEN 'green_1t_vo' ELSE co.product_code END);
        FOR q IN
          SELECT i.id, greatest(v.valid_from, v_last + 1) AS f,
                 CASE WHEN v.valid_to IS NULL THEN co.valid_to WHEN co.valid_to IS NULL THEN v.valid_to
                      ELSE least(v.valid_to, co.valid_to) END AS t
            FROM price_list_item i
            JOIN price_list_version v ON v.id = i.version_id
            JOIN price_list l ON l.id = v.price_list_id
           WHERE l.code = 'podnikatelia_nad_30mwh' AND v.status = 'schvalena' AND i.product_id = v_pid
             AND (v.valid_to IS NULL OR v.valid_to > v_last) AND (co.valid_to IS NULL OR v.valid_from <= co.valid_to)
        LOOP
          v_out := v_out || contract_price_list_row('komodita', co.oom_id, q.id, q.f, q.t);
          v_list := v_list + datemultirange(daterange(q.f, q.t, '[]'));
        END LOOP;
      END IF;
      -- mesačná platba za OM (Poplatky B2B) mimo obdobia cenníka nad 30 MWh (platba je v jeho položke)
      FOR q IN SELECT unnest(datemultirange(daterange(co.valid_from, co.valid_to, '[]')) - v_list) AS rg LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('poplatok_om', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items((SELECT id FROM product WHERE code = 'poplatok_om_firmy'),
                                                       lower(q.rg), upper(q.rg) - 1) p);
      END LOOP;
    END IF;
    IF c.type = 'viwa' AND c.viwa_package IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_kw', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items((SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package),
                                                     co.valid_from, co.valid_to) p);
    END IF;
  END LOOP;
  IF c.type = 'viwa' AND c.viwa_package IS NOT NULL AND c.valid_from IS NOT NULL THEN
    v_pid := (SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package);
    v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_ucet', NULL, p.item_id, p.valid_from, p.valid_to)), '[]')
                         FROM contract_price_items(v_pid, c.valid_from, contract_effective_to(c)) p);
  END IF;
  RETURN v_out;
END;
$$;

-- ============================================================================
-- 4. Ceny zmluvy: rozdielový zápis (audit iba skutočných zmien, časť 27.3)
-- ============================================================================

-- Pár riadku = rovnaké OOM, zložka, produkt, model, položka cenníka a začiatok. Riadky bez páru sa zmažú alebo vložia,
-- spárované s inými hodnotami sa upravia (najprv skrátenia, potom predĺženia – kvôli obmedzeniu proti prekrytiu).
CREATE OR REPLACE FUNCTION contract_price_set(p_contract_id uuid, p_subset text, p_rows jsonb) RETURNS boolean
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_pass integer;
BEGIN
  IF contract_price_canon((SELECT coalesce(jsonb_agg(to_jsonb(cp)), '[]') FROM contract_price cp
                            WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                              AND (cp.price_model = 'cennik') = (p_subset = 'cennik')))
     = contract_price_canon(p_rows) THEN
    RETURN false;
  END IF;
  DELETE FROM contract_price cp
   WHERE cp.contract_id = p_contract_id AND cp.source = 'import' AND (cp.price_model = 'cennik') = (p_subset = 'cennik')
     AND NOT EXISTS (SELECT 1 FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
                      WHERE n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
                        AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
                        AND n.valid_from = cp.valid_from);
  FOR v_pass IN 1..2 LOOP
    UPDATE contract_price cp
       SET valid_to = n.valid_to, price_vt_eur_mwh = n.price_vt_eur_mwh, price_nt_eur_mwh = n.price_nt_eur_mwh,
           additive_eur_mwh = n.additive_eur_mwh, additive_pct = n.additive_pct, fee_eur_month = n.fee_eur_month,
           fee_kw_eur_month = n.fee_kw_eur_month, vat_rate = n.vat_rate, op_product_name = n.op_product_name
      FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
     WHERE cp.contract_id = p_contract_id AND cp.source = 'import' AND (cp.price_model = 'cennik') = (p_subset = 'cennik')
       AND n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
       AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
       AND n.valid_from = cp.valid_from
       AND (cp.valid_to, cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.additive_pct, cp.fee_eur_month,
            cp.fee_kw_eur_month, cp.vat_rate, cp.op_product_name)
           IS DISTINCT FROM
           (n.valid_to, n.price_vt_eur_mwh, n.price_nt_eur_mwh, n.additive_eur_mwh, n.additive_pct, n.fee_eur_month,
            n.fee_kw_eur_month, n.vat_rate, n.op_product_name)
       AND (v_pass = 2 OR coalesce(n.valid_to, 'infinity'::date) <= coalesce(cp.valid_to, 'infinity'::date));
  END LOOP;
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month,
                              fee_kw_eur_month, vat_rate, op_product_name, source)
  SELECT p_contract_id, n.oom_id, n.slot, n.product_id, n.price_model, n.price_list_item_id, n.valid_from, n.valid_to,
         n.price_vt_eur_mwh, n.price_nt_eur_mwh, n.additive_eur_mwh, n.additive_pct, n.fee_eur_month,
         n.fee_kw_eur_month, n.vat_rate, n.op_product_name, 'import'
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
   WHERE NOT EXISTS (SELECT 1 FROM contract_price cp
                      WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                        AND n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
                        AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
                        AND n.valid_from = cp.valid_from);
  RETURN true;
END;
$$;

-- ============================================================================
-- 5. Nočný beh zmlúv (časti 7.2 a 27)
-- ============================================================================

-- Chyba do záznamu behu: bez osobných údajov (EIC skrátené na predponu), najviac 300 znakov
CREATE FUNCTION job_error(p_contract_id uuid, p_step text, p_state text, p_message text) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('zmluva', p_contract_id, 'krok', p_step, 'kod', p_state,
           'text', left(regexp_replace(coalesce(p_message, ''), '([0-9]{2}[A-Z])[0-9A-Z-]{13}', '\1…', 'g'), 300))
$$;

-- OOM v zmluve, pri ktorom k produktu chýba pár pre reguláciu ANO ↔ NIE (časť obdobia by ostala bez ceny).
-- Vráti popis (EIC skráti až záznam behu) alebo NULL. Kontroluje sa v nočnom behu – nesmie prejsť potichu.
CREATE FUNCTION contract_regulation_pair_missing(p_contract_id uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT string_agg(format('OOM %s: k produktu %s chýba pár pre cenovú reguláciu %s od %s', o.eic, p.name,
                           CASE WHEN p.price_regulation THEN 'NIE' ELSE 'ANO' END, to_char(s.seg_from, 'FMDD. FMMM. YYYY')),
                    '; ' ORDER BY o.eic, s.seg_from)
    FROM contract k
    JOIN contract_oom co ON co.contract_id = k.id
    JOIN oom o ON o.id = co.oom_id
    JOIN product p ON p.id = co.product_id
    CROSS JOIN LATERAL contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to) s
   WHERE k.id = p_contract_id AND k.type::text LIKE 'dodavka%' AND (k.list_price OR k.type = 'dodavka_domacnost')
     AND k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') AND o.type = 'spotreba'
     AND co.valid_from IS NOT NULL AND (co.valid_to IS NULL OR co.valid_to >= co.valid_from)
     AND p.price_regulation IS NOT NULL AND s.seg_product IS NULL
$$;
REVOKE EXECUTE ON FUNCTION contract_regulation_pair_missing(uuid) FROM PUBLIC;

-- Ceny z cenníkov v nočnom behu: ako contract_price_list_sync, ale chýbajúci pár ANO ↔ NIE je chyba zmluvy
-- (záznam v denníku, upozornenie admina, ďalšiu noc znova). Vráti true, ak sa ceny zmenili.
CREATE FUNCTION contract_sync_checked(p_contract_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_changed boolean := contract_price_list_sync(p_contract_id);
  v_missing text := contract_regulation_pair_missing(p_contract_id);
BEGIN
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION '%', v_missing USING ERRCODE = 'check_violation';
  END IF;
  RETURN v_changed;
END;
$$;
REVOKE EXECUTE ON FUNCTION contract_sync_checked(uuid) FROM PUBLIC;

-- OOM, ktoré sa pri prolongácii nepredĺžilo, si koniec ponechá (koniec zmluvy ho už nepredlžuje)
ALTER TABLE contract_oom ADD COLUMN end_fixed boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN contract_oom.end_fixed IS 'OOM sa pri prolongácii nepredĺžilo (nebolo Aktívne/Pripravované alebo dodávka skončila skôr); koniec zmluvy ho nepredlžuje';

-- Zmena fázy, účinnosti alebo typu zmluvy sa prenesie na jej OOM (neskrátené OOM dostanú skutočný koniec zmluvy;
-- OOM s pevným koncom z prolongácie najviac do konca zmluvy). Odmietnutá alebo neúspešná zmluva, ktorá už skrátila
-- iné zmluvy, im dá príznak „Na kontrolu“ (skrátenie sa nevracia).
CREATE OR REPLACE FUNCTION contract_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE contract_oom
     SET valid_from = NEW.valid_from,
         op_valid_to = NEW.valid_to,
         valid_to = CASE WHEN successor_id IS NOT NULL THEN valid_to
                         WHEN end_fixed THEN least(valid_to, contract_effective_to(NEW))
                         ELSE contract_effective_to(NEW) END
   WHERE contract_id = NEW.id;
  IF NEW.phase IN ('odmietnuta', 'neuspesna') AND OLD.phase IS DISTINCT FROM NEW.phase THEN
    INSERT INTO contract_flag (contract_id, code, detail)
    SELECT DISTINCT co.contract_id, 'kontrola_importu'::contract_flag_code,
           format('Nástupnícka zmluva %s je %s – skrátenie tejto zmluvy na OOM skontrolujte.', NEW.number,
                  CASE NEW.phase WHEN 'odmietnuta' THEN 'odmietnutá' ELSE 'neúspešná' END)
      FROM contract_oom co
     WHERE co.successor_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

-- Po zmene cien: príznak „Chýba cena“ a snímka bilancie (Pod hranicou, Chýba cena pre obchodníka)
CREATE FUNCTION contract_after_price_change(p_contract_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM contract_price_missing_refresh(p_contract_id);
  PERFORM contract_basis_refresh(p_contract_id);
END;
$$;
REVOKE EXECUTE ON FUNCTION contract_after_price_change(uuid) FROM PUBLIC;

-- Automatická prolongácia zmluvy k dňu p_today (krok 3, odpovede 34 a Peter k 0028 bod 1): podpísaná zmluva
-- s automatickou prolongáciou a pevným koncom, ktorá skončila pred p_today, sa predĺži o 12 mesiacov (opakovane,
-- kým nepokryje p_today).
--   - predĺžia sa iba OOM, ktoré sú Aktívne alebo Pripravované a ich dodávka neskončila pred koncom zmluvy;
--     ostatné si ponechajú koniec (end_fixed);
--   - OOM, na ktorom nadväzuje iná podpísaná zmluva toho istého druhu, ju dostane ako nástupcu a predĺži sa najviac
--     do dňa pred ňou;
--   - ak zmluva k dátumu konca nemá žiadne také OOM, nepredĺži sa a prejde do fázy Ukončená.
-- Ceny dopočíta contract_sync_checked (FIX firmy → cenník nad 30 MWh, SPOT a výkup → posledný aditív alebo cena,
-- cenník → cenník). Výsledok: p_result 'predlzena' (p_end = nový koniec), 'ukoncena' (p_end = koniec), inak NULL.
CREATE FUNCTION contract_prolong(p_contract_id uuid, p_today date, OUT p_result text, OUT p_end date)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k           contract;
  co          record;
  v_end       date;
  v_target    date;
  v_next_id   uuid;
  v_next_from date;
  v_open      integer := 0;
  v_eligible  integer := 0;
BEGIN
  SELECT * INTO k FROM contract WHERE id = p_contract_id FOR UPDATE;
  v_end := contract_effective_to(k);
  IF NOT (k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL AND v_end IS NOT NULL AND v_end < p_today) THEN
    RETURN;
  END IF;
  v_target := v_end;
  WHILE v_target < p_today LOOP
    v_target := ((v_target + 1) + interval '12 months')::date - 1;
  END LOOP;

  FOR co IN SELECT x.id, x.oom_id, x.grp, x.valid_to, o.status AS oom_status, o.supply_to
              FROM contract_oom x JOIN oom o ON o.id = x.oom_id
             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
               AND x.valid_from IS NOT NULL AND x.valid_to = v_end
             ORDER BY x.id
  LOOP
    IF co.oom_status NOT IN ('aktivne', 'pripravovane') OR co.supply_to < v_end THEN
      UPDATE contract_oom SET end_fixed = true WHERE id = co.id;
      CONTINUE;
    END IF;
    v_eligible := v_eligible + 1;
    v_next_id := NULL;
    v_next_from := NULL;
    SELECT y.contract_id, y.valid_from INTO v_next_id, v_next_from FROM contract_oom y
     WHERE y.oom_id = co.oom_id AND y.grp = co.grp AND y.is_binding AND y.contract_id <> k.id AND y.valid_from > co.valid_to
     ORDER BY y.valid_from LIMIT 1;
    IF v_next_id IS NULL OR v_next_from > v_target THEN
      v_open := v_open + 1;
    ELSE
      UPDATE contract_oom SET valid_to = v_next_from - 1, successor_id = v_next_id WHERE id = co.id;
    END IF;
  END LOOP;

  IF v_eligible = 0 THEN
    UPDATE contract SET phase = 'ukoncena' WHERE id = k.id;
    PERFORM contract_price_missing_refresh(k.id);
    p_result := 'ukoncena';
    p_end := v_end;
    RETURN;
  END IF;
  IF v_open > 0 THEN
    UPDATE contract SET crm_valid_to = v_target WHERE id = k.id;
  ELSE
    PERFORM contract_crm_end_refresh(k.id);
  END IF;
  SELECT contract_effective_to(x) INTO v_target FROM contract x WHERE x.id = k.id;
  IF v_target IS NULL OR v_target <= v_end THEN
    RETURN;   -- na všetkých OOM nadväzuje iná zmluva hneď po konci (retencia)
  END IF;

  PERFORM contract_sync_checked(k.id);
  PERFORM contract_after_price_change(k.id);
  UPDATE contract_flag SET detail = format('Sprolongovaná do %s – produkt na potvrdenie', to_char(v_target, 'FMDD. FMMM. YYYY'))
   WHERE contract_id = k.id AND code = 'sprolongovane_bez_ceny' AND resolved_at IS NULL;
  IF NOT FOUND THEN
    INSERT INTO contract_flag (contract_id, code, detail)
    VALUES (k.id, 'sprolongovane_bez_ceny', format('Sprolongovaná do %s – produkt na potvrdenie', to_char(v_target, 'FMDD. FMMM. YYYY')));
  END IF;
  p_result := 'predlzena';
  p_end := v_target;
END;
$$;
REVOKE EXECUTE ON FUNCTION contract_prolong(uuid, date) FROM PUBLIC;

-- Nočný beh zmlúv k dňu p_today (iba vlastník databázy: Cron cez contract_daily_run, ručný beh na Teste skriptom).
-- Kroky: 1 regulácia, 2 cenník, 3 prolongácia, 4 príznaky, 5 upozornenia, 6 stav zákazníka (časť 27.2).
-- Každá zmluva v každom kroku je samostatná podtransakcia: chyba vráti iba ju, beh pokračuje a chyba sa zapíše
-- do job_run. Kroky sú dobiehajúce (≤ dnes, ešte nevykonané) – zlyhaná zmluva alebo vynechaná noc sa dobehne.
CREATE FUNCTION contract_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run     uuid;
  v_err     jsonb := '[]';
  v_touched uuid[] := '{}';
  v_id      uuid;
  r         record;
  v_ok      boolean;
  v_end     date;
  v_last    date;
  v_state   text;
  v_msg     text;
  v_n       jsonb := '{}';
  v_cnt     integer;
  v_result  jsonb;
  v_pr      record;
  v_ended   integer := 0;
  v_before  uuid[];
  v_retro   text[] := '{}';
  v_prev_today  text := coalesce(current_setting('crm.today', true), '');
  v_prev_source text;
BEGIN
  IF p_today IS NULL THEN
    RAISE EXCEPTION 'contract_daily_run_at: chýba dátum' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtext('crm.contract_daily_run')) THEN
    RETURN jsonb_build_object('bezi', true);
  END IF;
  PERFORM set_config('crm.today', p_today::text, true);   -- crm_today() v spojení vlastníka (ručný beh)
  v_prev_source := crm_as_system(true);
  SELECT max(run_date) INTO v_last FROM job_run
   WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL AND run_date < p_today;
  INSERT INTO job_run (job, run_date, test_date)
  VALUES ('zmluvy', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;

  -- 1. Regulácia: ceny zmlúv na OOM, ktorých zmena regulácie nastala a zmluvy ju ešte nemajú
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT ch.id, ch.oom_id, ch.valid_from FROM oom_price_regulation_change ch
              WHERE ch.contract_applied_at IS NULL AND ch.valid_from <= p_today
              ORDER BY ch.valid_from, ch.id LOOP
      v_ok := true;
      FOR v_id IN SELECT DISTINCT co.contract_id FROM contract_oom co JOIN contract k ON k.id = co.contract_id
                   WHERE co.oom_id = r.oom_id AND k.phase NOT IN ('odmietnuta', 'neuspesna')
                     AND (co.valid_to IS NULL OR co.valid_to >= r.valid_from) LOOP
        BEGIN
          IF contract_sync_checked(v_id) THEN
            PERFORM contract_after_price_change(v_id);
            v_cnt := v_cnt + 1;
            v_touched := v_touched || v_id;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_ok := false;
          v_err := v_err || job_error(v_id, 'regulacia', v_state, v_msg);
        END;
      END LOOP;
      IF v_ok THEN
        UPDATE oom_price_regulation_change SET contract_applied_at = now() WHERE id = r.id;
      END IF;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'regulacia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('regulacia', v_cnt);

  -- 2. Cenník: zmluvy s cenníkovou cenou, ktorej verzia medzitým skončila alebo bola nahradená, a zmluvy s „Chýba cena“.
  --    Nová verzia sa uplatní prvú noc po schválení; cena platná od dátumu v minulosti sa zapíše od toho dátumu
  --    a zmluva ide do zoznamu „cennik_spatne“ v denníku behu (pre Nákup).
  v_cnt := 0;
  BEGIN
    FOR v_id IN SELECT cp.contract_id FROM contract_price cp
                  JOIN price_list_item i ON i.id = cp.price_list_item_id
                  JOIN price_list_version v ON v.id = i.version_id
                 WHERE cp.source = 'import'
                   AND (v.status = 'nahradena' OR (v.valid_to IS NOT NULL AND (cp.valid_to IS NULL OR cp.valid_to > v.valid_to)))
                UNION
                SELECT f.contract_id FROM contract_flag f WHERE f.code = 'chyba_cena' AND f.resolved_at IS NULL
                ORDER BY 1 LOOP
      BEGIN
        v_before := ARRAY(SELECT id FROM contract_price WHERE contract_id = v_id);
        IF contract_sync_checked(v_id) THEN
          PERFORM contract_after_price_change(v_id);
          v_cnt := v_cnt + 1;
          v_touched := v_touched || v_id;
          IF EXISTS (SELECT 1 FROM contract_price WHERE contract_id = v_id AND price_model = 'cennik'
                        AND valid_from < p_today AND NOT id = ANY (v_before)) THEN
            v_retro := v_retro || (SELECT number FROM contract WHERE id = v_id);
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(v_id, 'cennik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'cennik', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('cennik', v_cnt,
                                    'cennik_spatne', jsonb_build_object('pocet', cardinality(v_retro), 'zmluvy', to_jsonb(v_retro)));

  -- 3. Prolongácia: skončené zmluvy s automatickou prolongáciou a aspoň jedným OOM bez nástupcu a bez pevného konca;
  --    zmluva bez Aktívneho / Pripravovaného OOM prejde do fázy Ukončená a obchodník dostane upozornenie
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number FROM contract k
              WHERE k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL
                AND contract_effective_to(k) < p_today
                AND EXISTS (SELECT 1 FROM contract_oom x
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
                               AND x.valid_from IS NOT NULL AND x.valid_to = contract_effective_to(k))
              ORDER BY k.id LOOP
      BEGIN
        SELECT * INTO v_pr FROM contract_prolong(r.id, p_today);
        IF v_pr.p_result = 'predlzena' THEN
          v_cnt := v_cnt + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'sprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s bola automaticky predĺžená do %s – Servis potvrdí produkt',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        ELSIF v_pr.p_result = 'ukoncena' THEN
          v_ended := v_ended + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'neprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s skončila %s bez prolongácie – nemá aktívne OOM, fáza Ukončená',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'prolongacia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'prolongacia', v_state, v_msg);
    v_cnt := 0;
    v_ended := 0;
  END;
  v_n := v_n || jsonb_build_object('prolongovane', v_cnt, 'ukoncene', v_ended);

  -- 4. Príznaky: „Chýba cena“ v prvom behu roka pre všetky živé zmluvy (kontrola začína 1. 1. bežného roka)
  v_cnt := 0;
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM job_run WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL
                      AND run_date >= date_trunc('year', p_today)::date AND run_date < p_today) THEN
      FOR v_id IN SELECT k.id FROM contract k
                   WHERE k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena')
                     AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= date_trunc('year', p_today)::date)
                     AND NOT k.id = ANY (v_touched)
                   ORDER BY k.id LOOP
        BEGIN
          PERFORM contract_price_missing_refresh(v_id);
          v_cnt := v_cnt + 1;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(v_id, 'priznaky', v_state, v_msg);
        END;
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'priznaky', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('chyba_cena_kontrola', v_cnt);

  -- 5. Upozornenie 4 mesiace pred koncom (firmy a výkup, odpoveď 34): raz na koniec zmluvy, iba ak niektoré
  --    Aktívne alebo Pripravované OOM ešte nemá nadväzujúcu podpísanú zmluvu
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number, k.auto_prolong, contract_effective_to(k) AS end_on FROM contract k
              WHERE k.phase = 'podpisana' AND k.type IN ('dodavka_firma_nn', 'dodavka_firma_vn', 'vykup')
                AND contract_effective_to(k) BETWEEN p_today AND (p_today + interval '4 months')::date
                AND NOT EXISTS (SELECT 1 FROM notification n
                                 WHERE n.contract_id = k.id AND n.kind = 'konci_4_mesiace' AND n.ref_date = contract_effective_to(k))
                AND EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL
                               AND x.valid_to = contract_effective_to(k)
                               AND o.status IN ('aktivne', 'pripravovane')
                               AND (o.supply_to IS NULL OR o.supply_to >= contract_effective_to(k))
                               AND NOT EXISTS (SELECT 1 FROM contract_oom y
                                                WHERE y.oom_id = x.oom_id AND y.grp = x.grp AND y.is_binding
                                                  AND y.contract_id <> k.id AND y.valid_from > x.valid_to))
              ORDER BY k.id LOOP
      BEGIN
        IF notification_add(notification_contract_users(r.id), 'konci_4_mesiace', r.id, NULL, NULL, r.end_on,
                            format('Zmluva %s končí %s – dojednaj novú zmluvu%s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                                   CASE WHEN r.auto_prolong THEN ' (inak sa automaticky predĺži s cenníkom)' ELSE '' END)) > 0 THEN
          v_cnt := v_cnt + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'upozornenia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'upozornenia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('konci_4_mesiace', v_cnt);

  -- 6. Stav zákazníka: zmluvy zmenené behom a zmluvy, ktorým od posledného behu začala alebo skončila účinnosť
  v_cnt := 0;
  IF crm_setting_on('customer_status_auto') THEN
    BEGIN
      FOR r IN SELECT DISTINCT k.company_id, k.person_id FROM contract k
                WHERE k.id = ANY (v_touched)
                   OR (k.phase = 'podpisana' AND k.valid_from > coalesce(v_last, p_today - 1) AND k.valid_from <= p_today)
                   OR (k.phase = 'podpisana' AND contract_effective_to(k) >= coalesce(v_last, p_today - 1) - 1
                       AND contract_effective_to(k) < p_today) LOOP
        BEGIN
          IF customer_refresh(r.company_id, r.person_id) THEN
            v_cnt := v_cnt + 1;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
        END;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
      v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
      v_cnt := 0;
    END;
  END IF;
  v_n := v_n || jsonb_build_object('zakaznici', v_cnt);

  v_result := v_n || jsonb_build_object('chyby', jsonb_array_length(v_err));
  UPDATE job_run SET finished_at = clock_timestamp(), result = v_result, errors = v_err WHERE id = v_run;
  IF jsonb_array_length(v_err) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT u.id FROM app_user u WHERE u.is_admin AND u.status <> 'deaktivovany'),
                             'nocny_beh_chyba', NULL, NULL, v_run, p_today,
                             format('Nočný beh zmlúv %s: %s chýb (Nastavenia → Nočný beh)',
                                    to_char(p_today, 'FMDD. FMMM. YYYY'), jsonb_array_length(v_err)));
  END IF;
  PERFORM set_config('crm.today', v_prev_today, true);
  PERFORM set_config('app.change_source', v_prev_source, true);
  RETURN v_result;
END;
$$;
REVOKE EXECUTE ON FUNCTION contract_daily_run_at(date) FROM PUBLIC;
COMMENT ON FUNCTION contract_daily_run_at(date) IS 'nočný beh zmlúv k dátumu – iba vlastník databázy (Cron cez contract_daily_run, ručný beh na Teste: db/test-data/zmluvy-test.sh)';

-- Denný beh (Cron na Workeri) k dnešku v Europe/Bratislava, rovnako ako oom_daily_run
CREATE FUNCTION contract_daily_run() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT contract_daily_run_at(crm_today())
$$;


-- migrate:down

DROP FUNCTION contract_daily_run();
DROP FUNCTION contract_daily_run_at(date);
DROP FUNCTION contract_prolong(uuid, date);
DROP FUNCTION contract_sync_checked(uuid);
DROP FUNCTION contract_regulation_pair_missing(uuid);
DROP FUNCTION contract_after_price_change(uuid);
DROP FUNCTION job_error(uuid, text, text, text);

CREATE OR REPLACE FUNCTION contract_price_set(p_contract_id uuid, p_subset text, p_rows jsonb) RETURNS boolean
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF contract_price_canon((SELECT coalesce(jsonb_agg(to_jsonb(cp)), '[]') FROM contract_price cp
                            WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                              AND (cp.price_model = 'cennik') = (p_subset = 'cennik')))
     = contract_price_canon(p_rows) THEN
    RETURN false;
  END IF;
  DELETE FROM contract_price
   WHERE contract_id = p_contract_id AND source = 'import' AND (price_model = 'cennik') = (p_subset = 'cennik');
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month,
                              fee_kw_eur_month, vat_rate, op_product_name, source)
  SELECT p_contract_id, r.oom_id, r.slot, r.product_id, r.price_model, r.price_list_item_id, r.valid_from, r.valid_to,
         r.price_vt_eur_mwh, r.price_nt_eur_mwh, r.additive_eur_mwh, r.additive_pct, r.fee_eur_month,
         r.fee_kw_eur_month, r.vat_rate, r.op_product_name, 'import'
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) r;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION contract_price_list_rows(p_contract_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  c      contract;
  co     record;
  q      record;
  v_out  jsonb := '[]';
  v_pid  uuid;
  v_last date;
  v_open boolean;
  v_mod  price_model;
  v_list datemultirange;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  FOR co IN
    SELECT x.*, o.type AS oom_type, o.public_lighting, p.code AS product_code, p.tariff_type
      FROM contract_oom x JOIN oom o ON o.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
     WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
  LOOP
    IF c.type::text LIKE 'dodavka%' AND c.list_price AND co.product_id IS NOT NULL AND co.oom_type = 'spotreba' THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('komodita', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items(co.product_id, co.valid_from, co.valid_to) p);
    END IF;
    IF c.type = 'dodavka_domacnost' AND co.oom_type = 'spotreba' AND co.product_id IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('zem', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items((SELECT id FROM product WHERE code = 'zem'), co.valid_from, co.valid_to,
                                                     co.product_id) p);
    END IF;
    IF co.program_id IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('program', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items(co.program_id, co.valid_from, co.valid_to) p);
    END IF;
    IF c.type IN ('dodavka_firma_nn', 'dodavka_firma_vn') AND NOT c.list_price AND co.oom_type = 'spotreba' THEN
      v_list := '{}';
      -- FIX s automatickou prolongáciou: po poslednom roku s cenou cenník nad 30 MWh (otázka 23)
      SELECT max(p.valid_to), bool_or(p.valid_to IS NULL), (array_agg(p.price_model ORDER BY p.valid_from DESC))[1]
        INTO v_last, v_open, v_mod
        FROM contract_price p
       WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita' AND p.source = 'import'
         AND p.price_model <> 'cennik';
      IF c.auto_prolong AND v_mod = 'fix' AND NOT v_open AND (co.valid_to IS NULL OR co.valid_to > v_last) THEN
        v_pid := (SELECT id FROM product WHERE code = CASE WHEN co.public_lighting AND co.tariff_type = 'jednotarif'
                                                           THEN 'green_1t_vo' ELSE co.product_code END);
        FOR q IN
          SELECT i.id, greatest(v.valid_from, v_last + 1) AS f,
                 CASE WHEN v.valid_to IS NULL THEN co.valid_to WHEN co.valid_to IS NULL THEN v.valid_to
                      ELSE least(v.valid_to, co.valid_to) END AS t
            FROM price_list_item i
            JOIN price_list_version v ON v.id = i.version_id
            JOIN price_list l ON l.id = v.price_list_id
           WHERE l.code = 'podnikatelia_nad_30mwh' AND v.status = 'schvalena' AND i.product_id = v_pid
             AND (v.valid_to IS NULL OR v.valid_to > v_last) AND (co.valid_to IS NULL OR v.valid_from <= co.valid_to)
        LOOP
          v_out := v_out || contract_price_list_row('komodita', co.oom_id, q.id, q.f, q.t);
          v_list := v_list + datemultirange(daterange(q.f, q.t, '[]'));
        END LOOP;
      END IF;
      -- mesačná platba za OM (Poplatky B2B) mimo obdobia cenníka nad 30 MWh (platba je v jeho položke)
      FOR q IN SELECT unnest(datemultirange(daterange(co.valid_from, co.valid_to, '[]')) - v_list) AS rg LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('poplatok_om', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items((SELECT id FROM product WHERE code = 'poplatok_om_firmy'),
                                                       lower(q.rg), upper(q.rg) - 1) p);
      END LOOP;
    END IF;
    IF c.type = 'viwa' AND c.viwa_package IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_kw', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items((SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package),
                                                     co.valid_from, co.valid_to) p);
    END IF;
  END LOOP;
  IF c.type = 'viwa' AND c.viwa_package IS NOT NULL AND c.valid_from IS NOT NULL THEN
    v_pid := (SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package);
    v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_ucet', NULL, p.item_id, p.valid_from, p.valid_to)), '[]')
                         FROM contract_price_items(v_pid, c.valid_from, contract_effective_to(c)) p);
  END IF;
  RETURN v_out;
END;
$$;

DROP FUNCTION contract_regulation_segments(uuid, uuid, date, date);
DROP FUNCTION contract_regulated_product(product, boolean);
DROP FUNCTION product_regulation_pair(uuid);

CREATE OR REPLACE FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_valid_from IS NULL THEN
    RAISE EXCEPTION 'Zadaj dátum „platí od“.' USING ERRCODE = 'check_violation';
  END IF;
  -- prístup k OOM a právo ho upraviť (RLS a spúšťač Aktívneho OOM) overí zápis bez zmeny hodnoty
  UPDATE oom SET price_regulation = price_regulation WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, NULL, crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = NULL, created_by = EXCLUDED.created_by;
  PERFORM oom_price_regulation_apply(p_oom_id, crm_today());
END;
$$;

ALTER TABLE oom_price_regulation_change DROP COLUMN contract_applied_at, DROP COLUMN prev_value;
ALTER TABLE contract_flag DROP COLUMN resolved_note;

CREATE OR REPLACE FUNCTION contract_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE contract_oom
     SET valid_from = NEW.valid_from,
         op_valid_to = NEW.valid_to,
         valid_to = CASE WHEN successor_id IS NULL THEN contract_effective_to(NEW) ELSE valid_to END
   WHERE contract_id = NEW.id;
  IF NEW.phase IN ('odmietnuta', 'neuspesna') AND OLD.phase IS DISTINCT FROM NEW.phase THEN
    INSERT INTO contract_flag (contract_id, code, detail)
    SELECT DISTINCT co.contract_id, 'kontrola_importu'::contract_flag_code,
           format('Nástupnícka zmluva %s je %s – skrátenie tejto zmluvy na OOM skontrolujte.', NEW.number,
                  CASE NEW.phase WHEN 'odmietnuta' THEN 'odmietnutá' ELSE 'neúspešná' END)
      FROM contract_oom co
     WHERE co.successor_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;
ALTER TABLE contract_oom DROP COLUMN end_fixed;

DROP TRIGGER trg_notify ON price_exception;
DROP FUNCTION price_exception_notify();
DROP TRIGGER trg_notify ON contract_flag;
DROP FUNCTION contract_flag_notify();
DROP FUNCTION notification_add(uuid[], text, uuid, uuid, uuid, date, text);
DROP FUNCTION notification_contract_users(uuid);
DROP FUNCTION notification_approvers(uuid, boolean);
DROP FUNCTION crm_user_sees_org(uuid, uuid);
DROP TABLE notification;
DROP TABLE job_run;
DROP FUNCTION crm_can_see_job_runs();

CREATE OR REPLACE FUNCTION customer_refresh(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_status   customer_status;
  v_former   boolean;
  v_producer boolean;
  v_prev     text;
  v_changed  boolean;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_refresh: zadaj práve jedno z company_id / person_id';
  END IF;
  v_status   := customer_status_calc(p_company_id, p_person_id);
  v_former   := customer_is_former_calc(p_company_id, p_person_id);
  v_producer := customer_is_producer_calc(p_company_id, p_person_id);
  v_prev     := crm_as_system(true);

  IF p_company_id IS NOT NULL THEN
    UPDATE company c
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = c.is_former_customer OR v_former, is_producer = v_producer
     WHERE c.id = p_company_id AND c.is_customer
       AND (c.status, c.status_source, c.is_former_customer, c.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, c.is_former_customer OR v_former, v_producer);
  ELSE
    UPDATE contact p
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = p.is_former_customer OR v_former, is_producer = v_producer
     WHERE p.id = p_person_id AND p.is_household
       AND (p.status, p.status_source, p.is_former_customer, p.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, p.is_former_customer OR v_former, v_producer);
  END IF;
  v_changed := FOUND;

  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_changed;
END;
$$;

CREATE OR REPLACE FUNCTION crm_today() RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT (now() AT TIME ZONE 'Europe/Bratislava')::date
$$;
COMMENT ON FUNCTION crm_today() IS NULL;
