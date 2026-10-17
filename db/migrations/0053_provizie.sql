-- migrate:up

-- 0053_provizie – modul 5, fáza F7, krok 1 (plán: návrh DB časť 37, Peter 17. 10. 2026, úpravy A–C a odpovede 1–10).
-- Provízia = pridaná hodnota spárovaných podpísaných zmlúv obchodu × percento obchodníka platné v deň Vyhraté.
-- Na obchod najviac jedna čakajúca položka = cieľová provízia − súčet uplatnených (vyrovnanie). Po prvom uplatnení sa
-- vyrovnanie tvorí iba pri spárovaní / zrušení spárovania zmluvy a pri zmene štádia; import ani nočný beh ho nemenia.
-- Provízie z CRM vznikajú až od dátumu prechodu commission_crm_from (prázdny = vypnuté, úprava A); obchod s províziou
-- zo Sales portálu (ID dealu z HubSpotu alebo EIC + obdobie, úprava B) províziu z CRM nedostane.
-- Províziu vidí iba jej vlastník a kto vidí všetky provízie (admin, tím „Provízie – všetko“, príznak pri používateľovi);
-- Back office a Nákup nie, hoci obchod vidia (úprava C). PDF a e-mail listu sú v kroku 2, prenos histórie v kroku 3.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM commission) OR EXISTS (SELECT 1 FROM commission_rule) THEN
    RAISE EXCEPTION '0053: tabuľky commission / commission_rule nie sú prázdne – migrácia ich prerába';
  END IF;
END;
$$;

-- ============================================================================
-- 1. Bilancia zmluvy: jadro bez kontroly prístupu (provízia sa počíta rovnako pre každého, aj v nočnom behu)
--    a obal pre aplikáciu s kontrolou ako doteraz – vzor offer_variant_values v 0052
-- ============================================================================

CREATE FUNCTION contract_year_calc_core(p_contract_id uuid, p_year integer, p_until date DEFAULT NULL) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH k AS (
  SELECT c AS rec, c.id, c.org_id, c.type, crm_can_see_margin() AS see_margin
    FROM contract c
   WHERE c.id = p_contract_id
),
bs AS (SELECT b.*, true AS stored FROM contract_year_basis b WHERE b.contract_id = p_contract_id AND b.year = p_year),
b AS (
  SELECT * FROM bs
  UNION ALL
  SELECT (z.v).*, false FROM (SELECT contract_basis_values(k.rec, p_year, crm_today()) AS v FROM k
                               WHERE NOT EXISTS (SELECT 1 FROM bs)) z
),
mk AS (
  SELECT (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio,
         (SELECT on_date FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio_on,
         (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'spot_fve')) AS spot_fve
    FROM k
),
mo AS (
  SELECT make_date(p_year, i, 1) AS m_start, (make_date(p_year, i, 1) + interval '1 month - 1 day')::date AS m_end
    FROM generate_series(1, 12) i
   WHERE p_until IS NULL OR make_date(p_year, i, 1) <= p_until   -- 0053: koniec obdobia (provízia: zmluva z Office portálu, neurčito 12 mesiacov)
),
co AS (
  SELECT x.oom_id, x.valid_from, x.valid_to, x.qty_vt_mwh, x.qty_nt_mwh,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS power_kw, o.planned_feed_in_mwh,
         CASE WHEN x.valid_to IS NOT NULL
                   AND (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                       - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1 < 12
              THEN (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                   - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1
              ELSE 12 END AS div
    FROM contract_oom x JOIN oom o ON o.id = x.oom_id
   WHERE x.contract_id = p_contract_id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
),
line AS (
  SELECT co.oom_id, mo.m_start, k.type AS ctype, p.price_model, p.price_vt_eur_mwh AS vt, p.price_nt_eur_mwh AS nt,
         p.additive_eur_mwh AS ad, p.additive_pct AS pct, pr.price_regulation AS reg,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN coalesce(co.planned_feed_in_mwh, 0) / 12 ELSE co.qty_vt_mwh / co.div END AS v_vt,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN 0 ELSE co.qty_nt_mwh / co.div END AS v_nt,
         (SELECT coalesce(sum(coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * co.power_kw), 0)
            FROM (SELECT DISTINCT ON (f.slot) f.* FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.oom_id = co.oom_id
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.slot, f.valid_from DESC) f) AS fees
    FROM co
    CROSS JOIN k
    JOIN mo ON co.valid_from <= mo.m_end AND (co.valid_to IS NULL OR co.valid_to >= mo.m_start)
    LEFT JOIN LATERAL (SELECT * FROM contract_price p
                        WHERE p.contract_id = p_contract_id AND p.oom_id = co.oom_id AND p.slot = 'komodita'
                          AND p.valid_from <= mo.m_end AND (p.valid_to IS NULL OR p.valid_to >= mo.m_start)
                        ORDER BY p.valid_from DESC LIMIT 1) p ON true
    LEFT JOIN product pr ON pr.id = p.product_id
),
kl AS (
  SELECT l.*, l.v_vt + l.v_nt AS vol,
         CASE WHEN l.ctype = 'viwa' THEN 'viwa'
              WHEN l.ctype = 'vykup' THEN CASE WHEN l.price_model IS NOT NULL THEN 'vykup' END
              WHEN l.price_model = 'cennik' AND l.ctype = 'dodavka_domacnost' AND l.reg THEN 'energo'
              WHEN l.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN l.price_model::text END AS kind
    FROM line l
),
calc AS (
  SELECT kl.*,
         pv_revenue(kl.kind, kl.price_model, kl.vt, kl.nt, kl.ad, kl.pct, kl.v_vt, kl.v_nt,
                    (SELECT spot_fve FROM mk), (SELECT viwa_additive FROM b)) AS rev,
         pv_unit_cost(kl.kind, kl.price_model, kl.vt, (SELECT seller_type FROM b), (SELECT trader_price FROM b),
                      (SELECT portfolio_eur_mwh FROM b), (SELECT energopomoc_price FROM b), (SELECT min_additive FROM b),
                      (SELECT exception_value FROM b)) AS unit_cost,
         pv_unit_margin_cost(kl.kind, kl.price_model, kl.vt, (SELECT portfolio FROM mk), (SELECT energopomoc_price FROM b),
                             (SELECT min_additive FROM b), (SELECT exception_value FROM b)) AS unit_mcost
    FROM kl
),
vu AS (   -- VIWA: mesačná platba za účet (bez OOM)
  SELECT coalesce(sum(f.fee_eur_month), 0) AS fee
    FROM mo
    JOIN LATERAL (SELECT f.fee_eur_month FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.slot = 'viwa_ucet'
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.valid_from DESC LIMIT 1) f ON true
),
agg AS (
  SELECT count(DISTINCT m_start)::int AS months,
         sum(vol) AS vol,
         CASE WHEN bool_and(rev IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(rev) FILTER (WHERE kind IS NOT NULL), 0) END AS rev,
         coalesce(sum(fees), 0) AS fees,
         CASE WHEN bool_and(unit_cost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_cost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS cost,
         CASE WHEN bool_and(unit_mcost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_mcost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS mcost,
         string_agg(DISTINCT kind, ',') AS model,
         CASE WHEN bool_or(kind = 'energo') THEN 'SEAS'
              WHEN bool_or(kind = 'vykup' AND price_model = 'fix') THEN 'FIX'
              WHEN bool_or(kind IN ('fix', 'cennik')) THEN 'FIX'
              WHEN bool_or(kind IN ('spot_plus_eur', 'viwa', 'vykup')) THEN 'SPOT' END AS tranche,
         CASE WHEN bool_or(kind = 'fix' AND unit_cost IS NULL) THEN 'cena pre obchodníka'
              WHEN bool_or(kind = 'cennik' AND unit_cost IS NULL) THEN 'odhad portfólia ku dňu podpisu'
              WHEN bool_or(kind = 'energo' AND unit_cost IS NULL) THEN 'nákupná cena energopomoci'
              WHEN bool_or(kind = 'viwa' AND rev IS NULL) THEN 'balík VIWA'
              WHEN bool_or(kind = 'vykup' AND price_model = 'spot_minus_pct' AND rev IS NULL) THEN 'očakávaná cena SPOT pre FVE'
              WHEN bool_or(kind IS NOT NULL AND unit_mcost IS NULL) THEN 'odhad portfólia (marža)' END AS missing
    FROM calc
)
SELECT p_year, agg.months, round(coalesce(agg.vol, 0), 3), round(agg.rev, 2), round(agg.fees + vu.fee, 2), round(agg.cost, 2),
       round(agg.rev - agg.cost, 2),
       CASE WHEN k.see_margin THEN round(agg.mcost, 2) END,
       CASE WHEN k.see_margin THEN round(agg.rev + agg.fees + vu.fee - agg.mcost, 2) END,
       agg.model, agg.tranche, b.stored, b.source, b.trader_price, b.exception_id, b.exception_value,
       CASE WHEN k.see_margin THEN mk.portfolio END, CASE WHEN k.see_margin THEN mk.portfolio_on END,
       CASE WHEN k.see_margin THEN mk.portfolio_on < crm_today() - 30 END,
       agg.missing
  FROM k CROSS JOIN agg CROSS JOIN vu CROSS JOIN mk LEFT JOIN b ON true
$$;
COMMENT ON FUNCTION contract_year_calc_core(uuid, integer, date) IS 'jadro ročnej bilancie zmluvy bez kontroly prístupu (interné, 0053); p_until = posledný deň započítaného obdobia (mesiace od neho ďalej sa nepočítajú)';

CREATE OR REPLACE FUNCTION contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT c.* FROM contract_year_calc_core(p_contract_id, p_year, NULL) c
   WHERE EXISTS (SELECT 1 FROM contract k WHERE k.id = p_contract_id
                    AND k.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(k.company_id, k.person_id, k.owner_id))
$$;

-- ============================================================================
-- 2. Tabuľky
-- ============================================================================

DROP TABLE commission_rule;            -- nepoužité; pravidlo je percento obchodníka
DROP TABLE commission;
DROP TYPE commission_status;
CREATE TYPE commission_status AS ENUM ('caka', 'uplatnena', 'zrusena');

ALTER TABLE app_user
  ADD COLUMN commission_enabled   boolean NOT NULL DEFAULT false,
  ADD COLUMN sees_all_commissions boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN app_user.commission_enabled IS 'počítať provízie (predvolene vypnuté, odpoveď 5); mení admin a schvaľovateľ cien; platí pre obchody vyhraté s províziou odteraz';
COMMENT ON COLUMN app_user.sees_all_commissions IS 'vidí všetky provízie aj bez práva tímu „Provízie – všetko“ (napr. obchodný riaditeľ v Sales_internal); mení admin';

CREATE TABLE commission_claim (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  number          text NOT NULL CHECK (number ~ '^CMSN-[0-9]{4}-[0-9]{4,}$'),
  user_id         uuid NOT NULL REFERENCES app_user (id),        -- vždy jeden obchodník
  total_eur       numeric(12,2) NOT NULL CHECK (total_eur >= 0),
  by_duration     jsonb NOT NULL DEFAULT '{}',                   -- medzisúčty podľa trvania zmluvy (snímka): {"1": …, "neurcito": …}
  pdf_key         text,                                          -- R2 (krok 2)
  void_pdf_key    text,                                          -- PDF s pečiatkou ZRUŠENÉ (krok 2)
  emailed_at      timestamptz,
  created_by      uuid REFERENCES app_user (id),                 -- kto uplatnil (obchodník sám alebo admin)
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  voided_at       timestamptz,
  voided_by       uuid REFERENCES app_user (id),
  void_reason     text CHECK (void_reason IS NULL OR length(btrim(void_reason)) >= 3),
  source          text NOT NULL DEFAULT 'crm' CHECK (source IN ('crm', 'sales_portal')),
  legacy_id       text,                                          -- Firestore id
  legacy_pdf_url  text,                                          -- Google Drive (história)
  UNIQUE (org_id, number),
  CHECK ((voided_at IS NULL) = (void_reason IS NULL)),
  CHECK ((source = 'sales_portal') = (legacy_id IS NOT NULL))
);
COMMENT ON TABLE commission_claim IS 'provízny list CMSN-RRRR-NNNN (0053): jeden obchodník, súčet ≥ 0; zrušiť smie admin s dôvodom, číslo sa znova nepoužije; história zo Sales portálu iba na čítanie';
CREATE UNIQUE INDEX commission_claim_legacy_key ON commission_claim (legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX commission_claim_user_idx ON commission_claim (user_id);

CREATE TABLE commission (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id             uuid NOT NULL REFERENCES org (id),
  deal_id            uuid REFERENCES deal (id),                  -- NULL iba pri histórii zo Sales portálu
  user_id            uuid NOT NULL REFERENCES app_user (id),
  kind               text NOT NULL DEFAULT 'provizia' CHECK (kind IN ('provizia', 'vyrovnanie')),
  status             commission_status NOT NULL DEFAULT 'caka',
  won_at             date,
  duration_years     smallint CHECK (duration_years > 0),        -- trvanie zmluvy (zoskupenie, obrazovka 41); NULL = neurčito
  volume_mwh         numeric(12,3),
  base_eur           numeric(12,2) NOT NULL,                     -- pridaná hodnota obchodu (môže byť záporná)
  base_missing       text,                                       -- neúplný základ (chýba cena…) – nedá sa uplatniť
  pct                numeric(5,2) NOT NULL CHECK (pct BETWEEN 0 AND 100),
  target_eur         numeric(12,2) NOT NULL CHECK (target_eur >= 0),  -- cieľová provízia obchodu = round(max(PH, 0) × % / 100, 2)
  amount_eur         numeric(12,2) NOT NULL,                     -- položka: cieľ − súčet uplatnených (vyrovnanie môže byť záporné)
  claim_id           uuid REFERENCES commission_claim (id),
  recalculated_at    timestamptz,
  reassigned_from    uuid REFERENCES app_user (id),
  reassigned_by      uuid REFERENCES app_user (id),
  reassigned_at      timestamptz,
  reassign_reason    text CHECK (reassign_reason IS NULL OR length(btrim(reassign_reason)) >= 3),
  source             text NOT NULL DEFAULT 'crm' CHECK (source IN ('crm', 'sales_portal')),
  legacy_id          text,                                       -- Firestore id
  legacy_hubspot_deal_id text,
  legacy_deal_name   text,
  legacy_eics        text[],                                     -- EIC dealu z HubSpotu (kontrola duplicít, úprava B)
  legacy_supply_from date,
  legacy_supply_to   date,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CHECK ((source = 'crm') = (deal_id IS NOT NULL)),
  CHECK ((source = 'sales_portal') = (legacy_id IS NOT NULL)),
  CHECK ((status = 'uplatnena') = (claim_id IS NOT NULL)),
  CHECK (kind = 'provizia' OR source = 'crm'),
  CHECK ((reassigned_at IS NULL) = (reassign_reason IS NULL))
);
COMMENT ON TABLE commission IS 'provízia obchodníka (0053): položka obchodu Čaká → Uplatnená (list) alebo Zrušená; na obchod najviac jedna čakajúca; zapisujú iba funkcie';
COMMENT ON COLUMN commission.kind IS 'provizia = prvá položka obchodu; vyrovnanie = rozdiel po uplatnení (spárovanie / zrušenie spárovania zmluvy, zmena štádia)';
CREATE UNIQUE INDEX commission_deal_pending_key ON commission (deal_id) WHERE status = 'caka';
CREATE UNIQUE INDEX commission_legacy_key ON commission (legacy_id) WHERE legacy_id IS NOT NULL;
CREATE INDEX commission_deal_idx ON commission (deal_id);
CREATE INDEX commission_user_idx ON commission (user_id, status);
CREATE INDEX commission_claim_idx ON commission (claim_id);
CREATE INDEX commission_legacy_hubspot_idx ON commission (legacy_hubspot_deal_id) WHERE legacy_hubspot_deal_id IS NOT NULL;

-- povolenie provízie napriek zhode so Sales portálom (admin s dôvodom)
CREATE TABLE commission_legacy_override (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL UNIQUE REFERENCES deal (id),
  org_id      uuid NOT NULL REFERENCES org (id),
  legacy_commission_id uuid REFERENCES commission (id),
  reason      text NOT NULL CHECK (length(btrim(reason)) >= 3),
  decided_by  uuid NOT NULL REFERENCES app_user (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE commission_legacy_override IS 'admin povolil províziu z CRM napriek zhode so Sales portálom (0053)';

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON commission_claim FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON commission FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON commission_legacy_override FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON commission_claim FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON commission FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON commission_legacy_override FOR EACH ROW EXECUTE FUNCTION audit_row();

-- upozornenia
ALTER TABLE notification ADD COLUMN commission_claim_id uuid REFERENCES commission_claim (id);
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve', 'pomoc_s_ponukou',
  'provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena']::text[]));

-- nastavenia (úprava A, odpoveď 6)
INSERT INTO app_setting (key, value, description) VALUES
  ('commission_crm_from', 'null', 'provízie z CRM od dátumu Vyhraté (RRRR-MM-DD); prázdne = vypnuté. Nastaví Peter v deň, keď Sales portál prestane počítať (0053)'),
  ('commission_claim_cc', '[]', 'používatelia, ktorí dostanú kópiu provízneho listu (zoznam id; 0053)');

-- ============================================================================
-- 3. Viditeľnosť (úprava C, odpoveď 2)
-- ============================================================================

CREATE FUNCTION crm_commission_sees_all() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_is_admin() OR crm_scope('provizie', 'view') = 'vsetko'
      OR EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.sees_all_commissions)
$$;
COMMENT ON FUNCTION crm_commission_sees_all() IS 'všetky provízie: admin, tím „Provízie – všetko“, príznak používateľa (0053); nie schvaľovateľ cien ani Back office / Nákup';

CREATE FUNCTION crm_commission_visible(p_org uuid, p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT p_org = ANY (crm_user_orgs())
     AND (crm_commission_sees_all()
          OR (p_user = crm_active_user_id() AND crm_scope('provizie', 'view') <> 'nic'))
$$;

CREATE POLICY commission_read ON commission FOR SELECT USING (crm_commission_visible(org_id, user_id));
CREATE POLICY commission_claim_read ON commission_claim FOR SELECT USING (crm_commission_visible(org_id, user_id));
CREATE POLICY commission_legacy_override_read ON commission_legacy_override FOR SELECT USING (crm_is_admin() OR crm_is_service());
ALTER TABLE commission ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_claim ENABLE ROW LEVEL SECURITY;
ALTER TABLE commission_legacy_override ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. Stráženie: uplatnená položka a história sa nemenia, nič sa nemaže
-- ============================================================================

CREATE FUNCTION commission_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Provízia sa nemaže (iba zruší).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.status = 'zrusena' AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'Zrušená provízia sa nemení.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (NEW.org_id, NEW.deal_id, NEW.source, NEW.kind, NEW.legacy_id) IS DISTINCT FROM (OLD.org_id, OLD.deal_id, OLD.source, OLD.kind, OLD.legacy_id) THEN
    RAISE EXCEPTION 'Obchod, zdroj a druh provízie sa nemenia.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- história zo Sales portálu: iba stav a list (uplatnenie čakajúcej, zrušenie listu v CRM)
  IF OLD.source = 'sales_portal'
     AND ((NEW.user_id, NEW.won_at, NEW.duration_years, NEW.volume_mwh, NEW.base_eur, NEW.pct, NEW.target_eur, NEW.amount_eur,
           NEW.legacy_hubspot_deal_id, NEW.legacy_deal_name, NEW.legacy_eics, NEW.legacy_supply_from, NEW.legacy_supply_to)
          IS DISTINCT FROM
          (OLD.user_id, OLD.won_at, OLD.duration_years, OLD.volume_mwh, OLD.base_eur, OLD.pct, OLD.target_eur, OLD.amount_eur,
           OLD.legacy_hubspot_deal_id, OLD.legacy_deal_name, OLD.legacy_eics, OLD.legacy_supply_from, OLD.legacy_supply_to)
          OR NEW.status = 'zrusena') THEN
    RAISE EXCEPTION 'Provízia zo Sales portálu sa nemení.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- uplatnená sa neprepočítava ani nepreradí (zmení sa iba návrat na Čaká pri zrušení listu)
  IF OLD.status = 'uplatnena' AND NEW.status = 'uplatnena'
     AND (NEW.user_id, NEW.base_eur, NEW.pct, NEW.target_eur, NEW.amount_eur, NEW.claim_id, NEW.volume_mwh, NEW.duration_years)
         IS DISTINCT FROM (OLD.user_id, OLD.base_eur, OLD.pct, OLD.target_eur, OLD.amount_eur, OLD.claim_id, OLD.volume_mwh, OLD.duration_years) THEN
    RAISE EXCEPTION 'Uplatnená provízia sa nemení.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.status = 'uplatnena' AND NEW.status = 'zrusena' THEN
    RAISE EXCEPTION 'Uplatnenú províziu nemožno zrušiť – najprv zrušte provízny list.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON commission FOR EACH ROW EXECUTE FUNCTION commission_guard();

CREATE FUNCTION commission_claim_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Provízny list sa nemaže (iba zruší).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (NEW.org_id, NEW.number, NEW.user_id, NEW.total_eur, NEW.by_duration, NEW.created_by, NEW.created_at, NEW.source, NEW.legacy_id, NEW.legacy_pdf_url)
     IS DISTINCT FROM
     (OLD.org_id, OLD.number, OLD.user_id, OLD.total_eur, OLD.by_duration, OLD.created_by, OLD.created_at, OLD.source, OLD.legacy_id, OLD.legacy_pdf_url) THEN
    RAISE EXCEPTION 'Provízny list sa nemení (iba PDF, odoslanie a zrušenie).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.voided_at IS NOT NULL AND (NEW.voided_at, NEW.voided_by, NEW.void_reason) IS DISTINCT FROM (OLD.voided_at, OLD.voided_by, OLD.void_reason) THEN
    RAISE EXCEPTION 'Zrušenie listu sa nemení.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.source = 'sales_portal' AND NEW IS DISTINCT FROM OLD THEN
    RAISE EXCEPTION 'Provízny list zo Sales portálu je iba na čítanie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.pdf_key IS NOT NULL AND NEW.pdf_key IS DISTINCT FROM OLD.pdf_key THEN
    RAISE EXCEPTION 'PDF listu sa neprepisuje.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON commission_claim FOR EACH ROW EXECUTE FUNCTION commission_claim_guard();

-- ============================================================================
-- 5. Výpočet
-- ============================================================================

-- základ obchodu (interné): Σ PH spárovaných podpísaných zmlúv za obdobie zmluvy z Office portálu, zmluva na neurčito
-- prvých 12 mesiacov dodávky (P1); objem, trvanie (najdlhšia zmluva v celých rokoch, neurčito = NULL), chýbajúce vstupy
CREATE FUNCTION commission_deal_base(p_deal uuid) RETURNS TABLE (base_eur numeric, volume_mwh numeric, duration_years smallint, contracts integer, missing text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c       contract;
  v_from  date;
  v_until date;
  y       integer;
  r       record;
  v_base  numeric := 0;
  v_vol   numeric := 0;
  v_dur   integer := 0;
  v_open  boolean := false;
  v_n     integer := 0;
  v_miss  text[] := '{}';
BEGIN
  FOR c IN SELECT * FROM contract k
            WHERE k.deal_id = p_deal AND k.deal_match IN ('auto', 'rucne') AND k.signed_on IS NOT NULL
              AND k.phase NOT IN ('odmietnuta', 'neuspesna')
            ORDER BY k.number LOOP
    SELECT coalesce(min(x.valid_from), c.valid_from) INTO v_from FROM contract_oom x WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL;
    IF v_from IS NULL THEN
      v_miss := v_miss || format('zmluva %s bez začiatku dodávky', c.number);
      CONTINUE;
    END IF;
    v_n := v_n + 1;
    IF c.valid_to IS NULL THEN
      v_open := true;
      v_until := (v_from + interval '12 months' - interval '1 day')::date;
    ELSE
      v_until := greatest(c.valid_to, v_from);
      v_dur := greatest(v_dur, ceil(((extract(year FROM v_until) * 12 + extract(month FROM v_until))
                                     - (extract(year FROM v_from) * 12 + extract(month FROM v_from)) + 1) / 12.0)::integer);
    END IF;
    FOR y IN extract(year FROM v_from)::integer .. extract(year FROM v_until)::integer LOOP
      SELECT * INTO r FROM contract_year_calc_core(c.id, y, v_until);
      IF r.months > 0 AND r.added_value_eur IS NULL THEN
        v_miss := v_miss || format('zmluva %s, rok %s: %s', c.number, y, coalesce(r.missing, 'chýba vstup'));
      END IF;
      v_base := v_base + coalesce(r.added_value_eur, 0);
      v_vol := v_vol + coalesce(r.volume_mwh, 0);
    END LOOP;
  END LOOP;
  RETURN QUERY SELECT round(v_base, 2), round(v_vol, 3),
                      CASE WHEN v_open OR v_dur = 0 THEN NULL ELSE v_dur END::smallint, v_n,
                      nullif(array_to_string(v_miss, '; '), '');
END;
$$;

-- zhoda so Sales portálom (úprava B): rovnaké ID dealu z HubSpotu, alebo spoločné EIC so zmluvou obchodu
-- a prekrývajúce sa obdobie (neznáme obdobie z HubSpotu = stačí EIC)
CREATE FUNCTION commission_legacy_match(p_deal uuid) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT c.id
    FROM deal d
    JOIN commission c ON c.source = 'sales_portal' AND c.status <> 'zrusena' AND c.org_id = d.org_id
   WHERE d.id = p_deal
     AND ((d.hubspot_id IS NOT NULL AND c.legacy_hubspot_deal_id = d.hubspot_id)
          OR EXISTS (SELECT 1 FROM contract k
                       JOIN contract_oom x ON x.contract_id = k.id
                       JOIN oom o ON o.id = x.oom_id
                      WHERE k.deal_id = d.id AND k.deal_match IN ('auto', 'rucne')
                        AND o.eic = ANY (c.legacy_eics)
                        AND (c.legacy_supply_from IS NULL
                             OR daterange(c.legacy_supply_from, coalesce(c.legacy_supply_to, 'infinity'), '[]')
                                && daterange(coalesce(x.valid_from, k.valid_from, '-infinity'), coalesce(x.valid_to, k.valid_to, 'infinity'), '[]'))))
   ORDER BY c.won_at DESC NULLS LAST, c.id
   LIMIT 1
$$;

-- upozornenie (interné): aktívnym adminom spoločnosti
CREATE FUNCTION commission_notify_admins(p_org uuid, p_kind text, p_deal uuid, p_detail text) RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  INSERT INTO notification (user_id, kind, deal_id, detail)
  SELECT u.id, p_kind, p_deal, p_detail
    FROM app_user u
   WHERE u.is_admin AND u.status = 'aktivny' AND crm_user_sees_org(u.id, p_org)
$$;

-- Prepočet provízie obchodu (interné; spúšťače, nočná poistka, zrušenie listu). p_structural = spárovanie / zrušenie
-- spárovania zmluvy alebo zmena štádia – iba vtedy sa po uplatnení tvorí vyrovnanie. Vráti true pri zmene.
CREATE FUNCTION commission_sync(p_deal uuid, p_structural boolean) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d         deal;
  v_won     boolean;
  v_claimed numeric;
  v_hasclm  boolean;
  p         commission;
  v_ref     commission;
  v_user    uuid;
  v_pct     numeric;
  v_wonon   date;
  v_from    date;
  v_legacy  uuid;
  b         record;
  v_target  numeric;
  v_diff    numeric;
  v_n       integer;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL THEN
    RETURN false;
  END IF;
  -- súbežné prepočty toho istého obchodu po sebe
  PERFORM pg_advisory_xact_lock(hashtextextended('commission:' || p_deal::text, 0));
  v_won := (SELECT s.code FROM pipeline_stage s WHERE s.id = d.stage_id) = 'vyhrane';
  SELECT coalesce(sum(amount_eur), 0), count(*) > 0 INTO v_claimed, v_hasclm
    FROM commission WHERE deal_id = p_deal AND status = 'uplatnena';
  IF v_hasclm AND NOT p_structural THEN
    RETURN false;   -- odpoveď 1: po uplatnení iba štrukturálne zmeny
  END IF;
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  -- vlastník a percento: čakajúca položka, inak posledná nezrušená (preradenie platí aj pre budúce vyrovnania)
  IF p.id IS NOT NULL THEN
    v_ref := p;
  ELSE
    SELECT * INTO v_ref FROM commission WHERE deal_id = p_deal AND status <> 'zrusena' ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_ref.id IS NULL THEN
    -- vznik: Vyhraté, od dátumu prechodu, vlastník počíta provízie, bez provízie zo Sales portálu
    IF NOT v_won OR d.closed_at IS NULL THEN
      RETURN false;
    END IF;
    v_wonon := crm_local_date(d.closed_at);
    v_from := (SELECT (value #>> '{}')::date FROM app_setting WHERE key = 'commission_crm_from');
    IF v_from IS NULL OR v_wonon < v_from THEN
      RETURN false;
    END IF;
    IF NOT coalesce((SELECT commission_enabled FROM app_user WHERE id = d.owner_id), false) THEN
      RETURN false;
    END IF;
    v_legacy := commission_legacy_match(p_deal);
    IF v_legacy IS NOT NULL AND NOT EXISTS (SELECT 1 FROM commission_legacy_override WHERE deal_id = p_deal) THEN
      IF NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'provizia_duplicita' AND deal_id = p_deal) THEN
        PERFORM commission_notify_admins(d.org_id, 'provizia_duplicita', p_deal,
          'Obchod má províziu zo Sales portálu – provízia z CRM nevznikla. Ak ide o iný obchod, povoľte ju.');
      END IF;
      RETURN false;
    END IF;
    v_user := d.owner_id;
    v_pct := user_commission_pct(d.owner_id, v_wonon);
  ELSE
    v_user := v_ref.user_id;
    v_pct := v_ref.pct;
    v_wonon := CASE WHEN v_won AND d.closed_at IS NOT NULL THEN crm_local_date(d.closed_at) ELSE v_ref.won_at END;
  END IF;

  SELECT * INTO b FROM commission_deal_base(p_deal);
  v_target := CASE WHEN v_won THEN round(greatest(b.base_eur, 0) * v_pct / 100, 2) ELSE 0 END;
  v_diff := v_target - v_claimed;

  IF p.id IS NOT NULL THEN
    IF (NOT v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff = 0) THEN
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE id = p.id;
      RETURN true;
    END IF;
    UPDATE commission
       SET amount_eur = v_diff, target_eur = v_target, base_eur = b.base_eur, base_missing = b.missing,
           volume_mwh = b.volume_mwh, duration_years = b.duration_years, won_at = v_wonon, recalculated_at = now()
     WHERE id = p.id
       AND (amount_eur, target_eur, base_eur, base_missing, volume_mwh, duration_years, won_at)
           IS DISTINCT FROM (v_diff, v_target, b.base_eur, b.missing, b.volume_mwh, b.duration_years, v_wonon);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n > 0;
  END IF;

  IF (v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff <> 0) THEN
    INSERT INTO commission (org_id, deal_id, user_id, kind, status, won_at, duration_years, volume_mwh, base_eur, base_missing,
                            pct, target_eur, amount_eur, recalculated_at)
    VALUES (d.org_id, p_deal, v_user, CASE WHEN v_hasclm THEN 'vyrovnanie' ELSE 'provizia' END, 'caka', v_wonon,
            b.duration_years, b.volume_mwh, b.base_eur, b.missing, v_pct, v_target, v_diff, now());
    IF v_hasclm THEN
      INSERT INTO notification (user_id, kind, deal_id, detail)
      VALUES (v_user, 'provizia_vyrovnanie', p_deal,
              'Vyrovnanie už uplatnenej provízie po zmene obchodu – nová čakajúca položka.');
    END IF;
    RETURN true;
  END IF;
  RETURN false;
END;
$$;
COMMENT ON FUNCTION commission_sync(uuid, boolean) IS 'prepočet provízie obchodu (0053): jedna čakajúca položka = cieľ − Σ uplatnených; po uplatnení iba pri štrukturálnej zmene';

-- spúšťače
CREATE FUNCTION commission_on_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r_new jsonb := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END;
  r_old jsonb := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END;
  v_new uuid;
  v_old uuid;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'deal' THEN
      PERFORM commission_sync((r_new->>'id')::uuid, true);
    WHEN 'contract' THEN
      v_new := (r_new->>'deal_id')::uuid;
      v_old := (r_old->>'deal_id')::uuid;
      IF v_old IS DISTINCT FROM v_new THEN
        IF v_old IS NOT NULL THEN
          PERFORM commission_sync(v_old, true);
        END IF;
        IF v_new IS NOT NULL THEN
          PERFORM commission_sync(v_new, true);
        END IF;
      ELSIF v_new IS NOT NULL THEN
        PERFORM commission_sync(v_new, false);
      END IF;
    ELSE   -- contract_oom, contract_price, contract_year_basis: bilancia zmluvy
      SELECT k.deal_id INTO v_new FROM contract k WHERE k.id = (coalesce(r_new, r_old)->>'contract_id')::uuid;
      IF v_new IS NOT NULL THEN
        PERFORM commission_sync(v_new, false);
      END IF;
  END CASE;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_commission AFTER INSERT ON deal FOR EACH ROW EXECUTE FUNCTION commission_on_change();
CREATE TRIGGER trg_commission_upd AFTER UPDATE OF stage_id ON deal FOR EACH ROW
  WHEN (OLD.stage_id IS DISTINCT FROM NEW.stage_id) EXECUTE FUNCTION commission_on_change();
CREATE TRIGGER trg_commission AFTER INSERT OR DELETE OR UPDATE OF deal_id, deal_match, phase, signed_on, valid_from, valid_to ON contract
  FOR EACH ROW EXECUTE FUNCTION commission_on_change();
CREATE TRIGGER trg_commission AFTER INSERT OR DELETE OR UPDATE ON contract_oom FOR EACH ROW EXECUTE FUNCTION commission_on_change();
CREATE TRIGGER trg_commission AFTER INSERT OR DELETE OR UPDATE ON contract_price FOR EACH ROW EXECUTE FUNCTION commission_on_change();
CREATE TRIGGER trg_commission AFTER INSERT OR DELETE OR UPDATE ON contract_year_basis FOR EACH ROW EXECUTE FUNCTION commission_on_change();

-- Nočná poistka (beh na pozadí po nočnom behu obchodov a PH): prepočet vyhratých obchodov a obchodov s províziou
-- bez uplatnenia (aj vznik, ak sa napr. zapol dátum prechodu); počty do denníka behu obchodov
CREATE FUNCTION commission_daily() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_all  integer := 0;
  v_diff integer := 0;
  r      record;
  v_res  jsonb;
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT d.id FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE s.code = 'vyhrane'
           UNION
           SELECT c.deal_id FROM commission c WHERE c.status = 'caka' AND c.deal_id IS NOT NULL LOOP
    v_all := v_all + 1;
    IF commission_sync(r.id, false) THEN
      v_diff := v_diff + 1;
    END IF;
  END LOOP;
  v_res := jsonb_build_object('provizie_prepocitane', v_all, 'provizie_zmena', v_diff);
  UPDATE job_run SET result = result || v_res
   WHERE id = (SELECT id FROM job_run WHERE job = 'obchody' AND run_date = crm_today() ORDER BY started_at DESC LIMIT 1);
  RETURN v_res;
END;
$$;

-- ============================================================================
-- 6. Uplatnenie, zrušenie listu, preradenie, povolenie zhody, nastavenia
-- ============================================================================

CREATE FUNCTION commission_claim_create(p_user uuid, p_ids uuid[]) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me    uuid := crm_active_user_id();
  v_org   uuid;
  v_n     integer;
  v_total numeric;
  v_year  integer := extract(year FROM crm_today())::integer;
  v_no    text;
  v_claim uuid;
  v_cc    uuid[];
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Uplatniť províziu môže iba prihlásený používateľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user IS DISTINCT FROM v_me AND NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu za iného obchodníka uplatní iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user = v_me AND NOT crm_is_admin() AND crm_scope('provizie', 'view') = 'nic' THEN
    RAISE EXCEPTION 'Nemáte právo na provízie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF coalesce(cardinality(p_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Vyberte aspoň jednu províziu.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM 1 FROM commission WHERE id = ANY (p_ids) ORDER BY id FOR UPDATE;
  SELECT count(*), min(org_id::text)::uuid, sum(amount_eur) INTO v_n, v_org, v_total FROM commission WHERE id = ANY (p_ids);
  IF v_n <> (SELECT count(DISTINCT x) FROM unnest(p_ids) x) THEN
    RAISE EXCEPTION 'Niektorá provízia neexistuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND (status <> 'caka' OR user_id <> p_user OR org_id <> v_org)) THEN
    RAISE EXCEPTION 'Uplatniť sa dajú iba čakajúce provízie jedného obchodníka v jednej spoločnosti.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Spoločnosť provízie nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND base_missing IS NOT NULL) THEN
    RAISE EXCEPTION 'Provízia s neúplným základom (chýba cena) sa nedá uplatniť – doplňte ceny.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_total < 0 OR NOT EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND amount_eur > 0) THEN
    RAISE EXCEPTION 'Súčet listu musí byť aspoň 0 € a list musí obsahovať kladnú províziu (záporné vyrovnanie sa samostatne neuplatňuje).'
      USING ERRCODE = 'check_violation';
  END IF;

  v_no := format('CMSN-%s-%s', v_year, lpad(doc_number_next(v_org, 'provizny_list', v_year)::text, 4, '0'));
  INSERT INTO commission_claim (org_id, number, user_id, total_eur, by_duration, created_by)
  SELECT v_org, v_no, p_user, v_total,
         coalesce((SELECT jsonb_object_agg(k, s) FROM (SELECT coalesce(duration_years::text, 'neurcito') AS k, sum(amount_eur) AS s
                                                        FROM commission WHERE id = ANY (p_ids) GROUP BY 1) z), '{}'),
         v_me
  RETURNING id INTO v_claim;
  UPDATE commission SET status = 'uplatnena', claim_id = v_claim WHERE id = ANY (p_ids);

  -- upozornenia: obchodníkovi, ak uplatnil admin; príjemcom kópie (bez súm – nemusia vidieť všetky provízie)
  IF p_user <> v_me THEN
    INSERT INTO notification (user_id, kind, commission_claim_id, detail)
    VALUES (p_user, 'provizny_list', v_claim, format('Provízny list %s uplatnil za vás %s.', v_no, crm_user_name(v_me)));
  END IF;
  SELECT coalesce(array_agg(x::uuid), '{}') INTO v_cc
    FROM jsonb_array_elements_text(coalesce((SELECT value FROM app_setting WHERE key = 'commission_claim_cc'), '[]')) x;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  SELECT u.id, 'provizny_list', v_claim, format('Nový provízny list %s – %s.', v_no, crm_user_name(p_user))
    FROM app_user u
   WHERE u.id = ANY (v_cc) AND u.id <> p_user AND u.status = 'aktivny' AND crm_user_sees_org(u.id, v_org);
  RETURN v_claim;
END;
$$;
COMMENT ON FUNCTION commission_claim_create(uuid, uuid[]) IS 'uplatnenie provízií (0053): obchodník sám alebo admin za neho; jedna transakcia, číslo CMSN-RRRR-NNNN, súčet ≥ 0';

CREATE FUNCTION commission_claim_void(p_claim uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k commission_claim;
  r record;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Provízny list zruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod zrušenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO k FROM commission_claim WHERE id = p_claim FOR UPDATE;
  IF k.id IS NULL OR NOT k.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Provízny list neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF k.voided_at IS NOT NULL THEN
    RAISE EXCEPTION 'Provízny list je už zrušený.' USING ERRCODE = 'check_violation';
  END IF;
  IF k.source = 'sales_portal' THEN
    RAISE EXCEPTION 'Provízny list zo Sales portálu je iba na čítanie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE commission_claim SET voided_at = now(), voided_by = crm_active_user_id(), void_reason = btrim(p_reason) WHERE id = k.id;
  FOR r IN SELECT id, deal_id FROM commission WHERE claim_id = k.id ORDER BY id LOOP
    IF r.deal_id IS NOT NULL THEN
      -- najviac jedna čakajúca na obchod: nová čakajúca položka (vyrovnanie) sa zruší a prepočet ju zahrnie
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE deal_id = r.deal_id AND status = 'caka';
    END IF;
    UPDATE commission SET status = 'caka', claim_id = NULL WHERE id = r.id;
    IF r.deal_id IS NOT NULL THEN
      PERFORM commission_sync(r.deal_id, true);
    END IF;
  END LOOP;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  VALUES (k.user_id, 'provizny_list_zruseny', k.id, format('Provízny list %s bol zrušený, provízie sa vrátili na Čaká.', k.number));
END;
$$;

CREATE FUNCTION commission_reassign(p_deal uuid, p_user uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  p commission;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu preradí iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod preradenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  IF p.id IS NULL OR NOT p.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Obchod nemá čakajúcu províziu.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p.user_id = p_user THEN
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = p_user AND u.status = 'aktivny') OR NOT crm_user_sees_org(p_user, p.org_id) THEN
    RAISE EXCEPTION 'Nový obchodník musí byť aktívny a v spoločnosti provízie.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE commission
     SET user_id = p_user, reassigned_from = p.user_id, reassigned_by = crm_active_user_id(), reassigned_at = now(),
         reassign_reason = btrim(p_reason)
   WHERE id = p.id;
  INSERT INTO notification (user_id, kind, deal_id, detail)
  VALUES (p_user, 'provizia_preradena', p_deal, format('%s vám preradil čakajúcu províziu.', crm_user_name(crm_active_user_id()))),
         (p.user_id, 'provizia_preradena', p_deal, format('%s preradil vašu čakajúcu províziu – %s.', crm_user_name(crm_active_user_id()), crm_user_name(p_user)));
END;
$$;

CREATE FUNCTION commission_legacy_allow(p_deal uuid, p_reason text) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d deal;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu napriek zhode so Sales portálom povolí iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL OR NOT d.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Obchod neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  INSERT INTO commission_legacy_override (deal_id, org_id, legacy_commission_id, reason, decided_by)
  VALUES (p_deal, d.org_id, commission_legacy_match(p_deal), btrim(p_reason), crm_active_user_id())
  ON CONFLICT (deal_id) DO NOTHING;
  RETURN commission_sync(p_deal, true);
END;
$$;

CREATE FUNCTION user_commission_enabled_set(p_user uuid, p_on boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION '„Počítať provízie“ mení admin alebo schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_on IS NULL THEN
    RAISE EXCEPTION 'Zadajte áno alebo nie.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE app_user SET commission_enabled = p_on WHERE id = p_user AND commission_enabled IS DISTINCT FROM p_on;
END;
$$;

CREATE FUNCTION commission_settings_set(p_from date, p_cc uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Nastavenia provízií mení iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF EXISTS (SELECT 1 FROM unnest(coalesce(p_cc, '{}')) x WHERE NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = x AND u.status = 'aktivny')) THEN
    RAISE EXCEPTION 'Príjemca kópie musí byť aktívny používateľ.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE app_setting SET value = coalesce(to_jsonb(p_from), 'null'::jsonb)
   WHERE key = 'commission_crm_from' AND value IS DISTINCT FROM coalesce(to_jsonb(p_from), 'null'::jsonb);
  UPDATE app_setting SET value = to_jsonb(coalesce((SELECT array_agg(DISTINCT x ORDER BY x) FROM unnest(p_cc) x), '{}'::uuid[]))
   WHERE key = 'commission_claim_cc';
END;
$$;

-- ============================================================================
-- 7. Čítanie pre aplikáciu (obrazovka 41, karta obchodu)
-- ============================================================================

CREATE FUNCTION commission_list(p_user uuid DEFAULT NULL, p_status commission_status DEFAULT NULL, p_q text DEFAULT NULL)
RETURNS TABLE (id uuid, deal_id uuid, deal_name text, customer_name text, user_id uuid, user_name text, kind text,
               status commission_status, won_at date, duration_years smallint, volume_mwh numeric, base_eur numeric,
               base_missing text, pct numeric, target_eur numeric, amount_eur numeric, claim_id uuid, claim_number text,
               claimed_at timestamptz, source text, reassigned_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT c.id, c.deal_id, coalesce(d.name, c.legacy_deal_name),
         coalesce(co.name, nullif(btrim(concat_ws(' ', ct.first_name, ct.last_name)), '')),
         c.user_id, crm_user_name(c.user_id), c.kind, c.status, c.won_at, c.duration_years, c.volume_mwh, c.base_eur,
         c.base_missing, c.pct, c.target_eur, c.amount_eur, c.claim_id, k.number, k.created_at, c.source, c.reassigned_at
    FROM commission c
    LEFT JOIN deal d ON d.id = c.deal_id
    LEFT JOIN company co ON co.id = d.company_id
    LEFT JOIN contact ct ON ct.id = d.person_id
    LEFT JOIN commission_claim k ON k.id = c.claim_id
   WHERE crm_commission_visible(c.org_id, c.user_id)
     AND (p_user IS NULL OR c.user_id = p_user)
     AND (p_status IS NULL OR c.status = p_status)
     AND (p_status IS NOT NULL OR c.status <> 'zrusena')
     AND (p_q IS NULL OR btrim(p_q) = ''
          OR concat_ws(' ', d.name, c.legacy_deal_name, co.name, ct.first_name, ct.last_name, k.number) ILIKE '%' || btrim(p_q) || '%')
   ORDER BY c.duration_years NULLS LAST, c.won_at DESC NULLS LAST, c.id
$$;
COMMENT ON FUNCTION commission_list(uuid, commission_status, text) IS 'provízie pre obrazovku 41 (0053): iba viditeľné (vlastné, alebo všetky s právom); zrušené iba na vyžiadanie';

CREATE FUNCTION commission_summary(p_user uuid DEFAULT NULL) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  WITH c AS (
    SELECT c.*, k.created_at AS claimed_at, k.number
      FROM commission c LEFT JOIN commission_claim k ON k.id = c.claim_id
     WHERE crm_commission_visible(c.org_id, c.user_id) AND (p_user IS NULL OR c.user_id = p_user)
  ), t AS (SELECT crm_today() AS today)
  SELECT jsonb_build_object(
    'unpaid_eur',   coalesce((SELECT sum(amount_eur) FROM c WHERE status = 'caka'), 0),
    'unpaid_deals', (SELECT count(DISTINCT coalesce(deal_id::text, id::text)) FROM c WHERE status = 'caka'),
    'month_eur',    coalesce((SELECT sum(amount_eur) FROM c, t WHERE status = 'uplatnena' AND date_trunc('month', crm_local_date(claimed_at)) = date_trunc('month', t.today)), 0),
    'month_last_claim', (SELECT number FROM c, t WHERE status = 'uplatnena' AND date_trunc('month', crm_local_date(claimed_at)) = date_trunc('month', t.today)
                          ORDER BY claimed_at DESC LIMIT 1),
    'quarter_eur',  coalesce((SELECT sum(amount_eur) FROM c, t WHERE status = 'uplatnena' AND date_trunc('quarter', crm_local_date(claimed_at)) = date_trunc('quarter', t.today)), 0),
    'year_eur',     coalesce((SELECT sum(amount_eur) FROM c, t WHERE status = 'uplatnena' AND date_trunc('year', crm_local_date(claimed_at)) = date_trunc('year', t.today)), 0),
    'deals_year',   (SELECT count(DISTINCT coalesce(deal_id::text, legacy_id)) FROM c, t WHERE status <> 'zrusena' AND won_at >= date_trunc('year', t.today)::date))
$$;
COMMENT ON FUNCTION commission_summary(uuid) IS 'súčty obrazovky 41 (0053): nevyplatené = čakajúce; uplatnené podľa dátumu uplatnenia (nie výhry)';

-- interné funkcie aplikácia nespúšťa
REVOKE EXECUTE ON FUNCTION contract_year_calc_core(uuid, integer, date), commission_deal_base(uuid), commission_legacy_match(uuid),
  commission_notify_admins(uuid, text, uuid, text), commission_sync(uuid, boolean) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION contract_year_calc_core(uuid, integer, date), commission_deal_base(uuid), commission_legacy_match(uuid),
      commission_notify_admins(uuid, text, uuid, text), commission_sync(uuid, boolean) FROM crm_app;
  END IF;
END;
$$;

-- migrate:down

DROP FUNCTION commission_summary(uuid);
DROP FUNCTION commission_list(uuid, commission_status, text);
DROP FUNCTION commission_settings_set(date, uuid[]);
DROP FUNCTION user_commission_enabled_set(uuid, boolean);
DROP FUNCTION commission_legacy_allow(uuid, text);
DROP FUNCTION commission_reassign(uuid, uuid, text);
DROP FUNCTION commission_claim_void(uuid, text);
DROP FUNCTION commission_claim_create(uuid, uuid[]);
DROP FUNCTION commission_daily();
DROP TRIGGER trg_commission ON contract_year_basis;
DROP TRIGGER trg_commission ON contract_price;
DROP TRIGGER trg_commission ON contract_oom;
DROP TRIGGER trg_commission ON contract;
DROP TRIGGER trg_commission_upd ON deal;
DROP TRIGGER trg_commission ON deal;
DROP FUNCTION commission_on_change();
DROP FUNCTION commission_sync(uuid, boolean);
DROP FUNCTION commission_notify_admins(uuid, text, uuid, text);
DROP FUNCTION commission_legacy_match(uuid);
DROP FUNCTION commission_deal_base(uuid);

DELETE FROM notification WHERE kind IN ('provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena');
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace'::text, 'sprolongovana'::text, 'neprolongovana'::text, 'pod_hranicou'::text, 'vynimka_nova'::text, 'vynimka_rozhodnutie'::text, 'nocny_beh_chyba'::text, 'maly_podnik'::text, 'objem_xm'::text, 'dalsi_krok'::text, 'schvalenie_nove'::text, 'schvalenie_rozhodnutie'::text, 'pridelenie_firmy'::text, 'ponuka_akceptovana'::text, 'ponuka_zablokovana'::text, 'akceptacia_zrusena'::text, 'ponuka_odpoved'::text, 'ponuka_pripomienka'::text, 'gmail_chyba'::text, 'email_chyba'::text, 'nesparovana_zmluva'::text, 'cena_ina_ako_v_ponuke'::text, 'obnova'::text, 'chyba_oom_na_zmluve'::text, 'pomoc_s_ponukou'::text]));
ALTER TABLE notification DROP COLUMN commission_claim_id;
DELETE FROM app_setting WHERE key IN ('commission_crm_from', 'commission_claim_cc');

DROP TABLE commission_legacy_override;
DROP TABLE commission;
DROP TABLE commission_claim;
DROP FUNCTION commission_claim_guard();
DROP FUNCTION commission_guard();
DROP FUNCTION crm_commission_visible(uuid, uuid);
DROP FUNCTION crm_commission_sees_all();
DROP TYPE commission_status;
ALTER TABLE app_user DROP COLUMN sees_all_commissions, DROP COLUMN commission_enabled;

CREATE TYPE commission_status AS ENUM ('vypocitana', 'cakajuca', 'uplatnena', 'schvalena', 'vyplatena', 'zrusena');
CREATE TABLE commission (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    deal_id uuid NOT NULL REFERENCES deal (id),
    user_id uuid NOT NULL REFERENCES app_user (id),
    base_eur numeric(12,2),
    amount_eur numeric(12,2),
    period date,
    status commission_status DEFAULT 'vypocitana'::commission_status NOT NULL,
    pdf_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);
COMMENT ON COLUMN commission.period IS 'prvý deň obdobia (mesiaca), za ktoré sa provízia vypláca';
CREATE INDEX commission_deal_id_idx ON commission USING btree (deal_id);
CREATE INDEX commission_user_id_idx ON commission USING btree (user_id);
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON commission FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON commission FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TABLE commission_rule (
    id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    product_id uuid REFERENCES product (id),
    pipeline_id uuid REFERENCES pipeline (id),
    segment text,
    rate_type text NOT NULL,
    rate_value numeric(12,4) NOT NULL,
    valid_from date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT commission_rule_target_check CHECK ((num_nonnulls(product_id, pipeline_id) >= 1))
);
CREATE INDEX commission_rule_pipeline_id_idx ON commission_rule USING btree (pipeline_id);
CREATE INDEX commission_rule_product_id_idx ON commission_rule USING btree (product_id);
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON commission_rule FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON commission_rule FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE OR REPLACE FUNCTION contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH k AS (
  SELECT c AS rec, c.id, c.org_id, c.type, crm_can_see_margin() AS see_margin
    FROM contract c
   WHERE c.id = p_contract_id
     AND c.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(c.company_id, c.person_id, c.owner_id)
),
bs AS (SELECT b.*, true AS stored FROM contract_year_basis b WHERE b.contract_id = p_contract_id AND b.year = p_year),
b AS (
  SELECT * FROM bs
  UNION ALL
  SELECT (z.v).*, false FROM (SELECT contract_basis_values(k.rec, p_year, crm_today()) AS v FROM k
                               WHERE NOT EXISTS (SELECT 1 FROM bs)) z
),
mk AS (
  SELECT (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio,
         (SELECT on_date FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio_on,
         (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'spot_fve')) AS spot_fve
    FROM k
),
mo AS (
  SELECT make_date(p_year, i, 1) AS m_start, (make_date(p_year, i, 1) + interval '1 month - 1 day')::date AS m_end
    FROM generate_series(1, 12) i
),
co AS (
  SELECT x.oom_id, x.valid_from, x.valid_to, x.qty_vt_mwh, x.qty_nt_mwh,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS power_kw, o.planned_feed_in_mwh,
         CASE WHEN x.valid_to IS NOT NULL
                   AND (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                       - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1 < 12
              THEN (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                   - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1
              ELSE 12 END AS div
    FROM contract_oom x JOIN oom o ON o.id = x.oom_id
   WHERE x.contract_id = p_contract_id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
),
line AS (
  SELECT co.oom_id, mo.m_start, k.type AS ctype, p.price_model, p.price_vt_eur_mwh AS vt, p.price_nt_eur_mwh AS nt,
         p.additive_eur_mwh AS ad, p.additive_pct AS pct, pr.price_regulation AS reg,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN coalesce(co.planned_feed_in_mwh, 0) / 12 ELSE co.qty_vt_mwh / co.div END AS v_vt,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN 0 ELSE co.qty_nt_mwh / co.div END AS v_nt,
         (SELECT coalesce(sum(coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * co.power_kw), 0)
            FROM (SELECT DISTINCT ON (f.slot) f.* FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.oom_id = co.oom_id
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.slot, f.valid_from DESC) f) AS fees
    FROM co
    CROSS JOIN k
    JOIN mo ON co.valid_from <= mo.m_end AND (co.valid_to IS NULL OR co.valid_to >= mo.m_start)
    LEFT JOIN LATERAL (SELECT * FROM contract_price p
                        WHERE p.contract_id = p_contract_id AND p.oom_id = co.oom_id AND p.slot = 'komodita'
                          AND p.valid_from <= mo.m_end AND (p.valid_to IS NULL OR p.valid_to >= mo.m_start)
                        ORDER BY p.valid_from DESC LIMIT 1) p ON true
    LEFT JOIN product pr ON pr.id = p.product_id
),
kl AS (
  SELECT l.*, l.v_vt + l.v_nt AS vol,
         CASE WHEN l.ctype = 'viwa' THEN 'viwa'
              WHEN l.ctype = 'vykup' THEN CASE WHEN l.price_model IS NOT NULL THEN 'vykup' END
              WHEN l.price_model = 'cennik' AND l.ctype = 'dodavka_domacnost' AND l.reg THEN 'energo'
              WHEN l.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN l.price_model::text END AS kind
    FROM line l
),
calc AS (
  SELECT kl.*,
         pv_revenue(kl.kind, kl.price_model, kl.vt, kl.nt, kl.ad, kl.pct, kl.v_vt, kl.v_nt,
                    (SELECT spot_fve FROM mk), (SELECT viwa_additive FROM b)) AS rev,
         pv_unit_cost(kl.kind, kl.price_model, kl.vt, (SELECT seller_type FROM b), (SELECT trader_price FROM b),
                      (SELECT portfolio_eur_mwh FROM b), (SELECT energopomoc_price FROM b), (SELECT min_additive FROM b),
                      (SELECT exception_value FROM b)) AS unit_cost,
         pv_unit_margin_cost(kl.kind, kl.price_model, kl.vt, (SELECT portfolio FROM mk), (SELECT energopomoc_price FROM b),
                             (SELECT min_additive FROM b), (SELECT exception_value FROM b)) AS unit_mcost
    FROM kl
),
vu AS (   -- VIWA: mesačná platba za účet (bez OOM)
  SELECT coalesce(sum(f.fee_eur_month), 0) AS fee
    FROM mo
    JOIN LATERAL (SELECT f.fee_eur_month FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.slot = 'viwa_ucet'
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.valid_from DESC LIMIT 1) f ON true
),
agg AS (
  SELECT count(DISTINCT m_start)::int AS months,
         sum(vol) AS vol,
         CASE WHEN bool_and(rev IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(rev) FILTER (WHERE kind IS NOT NULL), 0) END AS rev,
         coalesce(sum(fees), 0) AS fees,
         CASE WHEN bool_and(unit_cost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_cost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS cost,
         CASE WHEN bool_and(unit_mcost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_mcost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS mcost,
         string_agg(DISTINCT kind, ',') AS model,
         CASE WHEN bool_or(kind = 'energo') THEN 'SEAS'
              WHEN bool_or(kind = 'vykup' AND price_model = 'fix') THEN 'FIX'
              WHEN bool_or(kind IN ('fix', 'cennik')) THEN 'FIX'
              WHEN bool_or(kind IN ('spot_plus_eur', 'viwa', 'vykup')) THEN 'SPOT' END AS tranche,
         CASE WHEN bool_or(kind = 'fix' AND unit_cost IS NULL) THEN 'cena pre obchodníka'
              WHEN bool_or(kind = 'cennik' AND unit_cost IS NULL) THEN 'odhad portfólia ku dňu podpisu'
              WHEN bool_or(kind = 'energo' AND unit_cost IS NULL) THEN 'nákupná cena energopomoci'
              WHEN bool_or(kind = 'viwa' AND rev IS NULL) THEN 'balík VIWA'
              WHEN bool_or(kind = 'vykup' AND price_model = 'spot_minus_pct' AND rev IS NULL) THEN 'očakávaná cena SPOT pre FVE'
              WHEN bool_or(kind IS NOT NULL AND unit_mcost IS NULL) THEN 'odhad portfólia (marža)' END AS missing
    FROM calc
)
SELECT p_year, agg.months, round(coalesce(agg.vol, 0), 3), round(agg.rev, 2), round(agg.fees + vu.fee, 2), round(agg.cost, 2),
       round(agg.rev - agg.cost, 2),
       CASE WHEN k.see_margin THEN round(agg.mcost, 2) END,
       CASE WHEN k.see_margin THEN round(agg.rev + agg.fees + vu.fee - agg.mcost, 2) END,
       agg.model, agg.tranche, b.stored, b.source, b.trader_price, b.exception_id, b.exception_value,
       CASE WHEN k.see_margin THEN mk.portfolio END, CASE WHEN k.see_margin THEN mk.portfolio_on END,
       CASE WHEN k.see_margin THEN mk.portfolio_on < crm_today() - 30 END,
       agg.missing
  FROM k CROSS JOIN agg CROSS JOIN vu CROSS JOIN mk LEFT JOIN b ON true
$$;
DROP FUNCTION contract_year_calc_core(uuid, integer, date);
