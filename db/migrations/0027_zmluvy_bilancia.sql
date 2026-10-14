-- migrate:up

-- ============================================================================
-- 1. Parameter „Minimálny aditív – výkup“ (otázka 29) a prepis pri výkupnej zmluve (Nákup)
-- ============================================================================

ALTER TABLE price_parameter DROP CONSTRAINT price_parameter_code_check;
ALTER TABLE price_parameter ADD CONSTRAINT price_parameter_code_check CHECK (code IN (
  'pomer_bl_pct', 'rizikova_prirazka', 'nasa_marza', 'min_aditiv_obchodnik', 'min_aditiv_manazer', 'min_aditiv_vykup_lz',
  'nakup_energopomoc', 'viwa_aditiv_basic', 'viwa_aditiv_plus', 'viwa_aditiv_pro', 'min_aditiv_vykup'));
INSERT INTO price_parameter (org_id, code, valid_from, value, note)
SELECT o.id, 'min_aditiv_vykup', '2026-01-01', 0, 'východisková hodnota (0027, otázka 29)'
  FROM org o
 WHERE NOT EXISTS (SELECT 1 FROM price_parameter p WHERE p.org_id = o.id AND p.code = 'min_aditiv_vykup');

CREATE OR REPLACE FUNCTION price_parameter_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_owner boolean := crm_owner_session();
BEGIN
  IF v_owner THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    IF OLD.valid_from <= crm_today() THEN
      RAISE EXCEPTION 'Platný parameter sa nemení ani nemaže – zadaj novú hodnotu s dátumom „platí od“.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.changed_by IS DISTINCT FROM crm_active_user_id() THEN
      RAISE EXCEPTION 'Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor.' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id OR NEW.delivery_year IS DISTINCT FROM OLD.delivery_year THEN
      RAISE EXCEPTION 'Parameter, spoločnosť a rok sa nemenia.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.valid_from < crm_today() THEN
    RAISE EXCEPTION 'Platí od musí byť dnes alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR (crm_approves_prices()
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'min_aditiv_vykup', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'min_aditiv_vykup', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;

ALTER TABLE contract ADD COLUMN vykup_min_additive numeric(12,4) CHECK (vykup_min_additive >= 0);
ALTER TABLE contract ADD CONSTRAINT contract_vykup_min_additive_type_check CHECK (vykup_min_additive IS NULL OR type = 'vykup');
COMMENT ON COLUMN contract.vykup_min_additive IS 'výkup: minimálny aditív pre túto zmluvu (prepis parametra, zadá Nákup); NULL = parameter';

CREATE OR REPLACE FUNCTION contract_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  v_crm    text[] := ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'viwa_package', 'vykup_min_additive',
                           'updated_at'];
  r contract;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system THEN
      RAISE EXCEPTION 'Zmluva sa nemaže – opravuje sa v Office portáli a ďalším importom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_system THEN
    -- obchodníka zmluvy (Uzatvoril) zmení iba vedenie alebo admin, rovnako ako vlastníka zákazníka
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND crm_can_change_owner() THEN
      v_crm := v_crm || 'owner_id'::text;
    END IF;
    IF (to_jsonb(NEW) - v_crm) <> (to_jsonb(OLD) - v_crm) THEN
      RAISE EXCEPTION 'Údaje z Office portálu sa v CRM nemenia – opravte ich v Office portáli a nahrajte export.'
        USING ERRCODE = 'check_violation';
    END IF;
    -- minimálny aditív výkupu pri zmluve (0027, otázka 29; iba výkup – obmedzenie tabuľky): mení Nákup alebo admin
    IF NEW.vykup_min_additive IS DISTINCT FROM OLD.vykup_min_additive THEN
      IF NOT (crm_is_admin() OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                                         WHERE u.id = crm_active_user_id() AND t.code = 'nakup')) THEN
        RAISE EXCEPTION 'Minimálny aditív výkupu pri zmluve mení iba Nákup alebo admin.' USING ERRCODE = 'insufficient_privilege';
      END IF;
    END IF;
  END IF;
  -- súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka
  IF NEW.related_contract_id IS NOT NULL THEN
    SELECT * INTO r FROM contract WHERE id = NEW.related_contract_id;
    IF (r.company_id, r.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)
       OR NOT ((NEW.type = 'viwa' AND r.type::text LIKE 'dodavka%') OR (r.type = 'viwa' AND NEW.type::text LIKE 'dodavka%')) THEN
      RAISE EXCEPTION 'Súvisiaca zmluva: VIWA a zmluva o dodávke toho istého zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 2. Snímka hodnôt ku dňu podpisu (časť 6.1, 26.2)
-- ============================================================================

CREATE TABLE contract_year_basis (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id       uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  year              smallint NOT NULL CHECK (year BETWEEN 2000 AND 2100),
  ref_date          date NOT NULL,
  seller_type       seller_type NOT NULL,
  trader_price      numeric(12,4),
  portfolio_eur_mwh numeric(12,4),
  portfolio_on      date,
  min_additive      numeric(12,4),
  energopomoc_price numeric(12,4),
  viwa_additive     numeric(12,4),
  exception_id      uuid REFERENCES price_exception (id),
  exception_value   numeric(12,4),
  source            text NOT NULL DEFAULT 'vypocet' CHECK (source IN ('vypocet', 'hubspot')),
  computed_at       timestamptz NOT NULL DEFAULT now(),
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_year_basis_key UNIQUE (contract_id, year),
  CONSTRAINT contract_year_basis_exception_check CHECK ((exception_id IS NULL) = (exception_value IS NULL))
);
COMMENT ON TABLE contract_year_basis IS 'snímka ku dňu podpisu pre zmluvu × rok: cena pre obchodníka, odhad portfólia, minimálny aditív, energopomoc, aditív VIWA, výnimka; pridanú hodnotu po zmene parametrov nemení';
COMMENT ON COLUMN contract_year_basis.source IS 'vypocet = z cien BL/PL ku dňu podpisu; hubspot = cena pre obchodníka z nákupnej ceny pri deale (contract_purchase, zmluvy pred 2026)';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON contract_year_basis FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON contract_year_basis FOR EACH ROW EXECUTE FUNCTION set_updated_at();
-- aplikácia snímku nečíta ani nemení (obsahuje odhad portfólia); bilanciu vracia contract_year_calc
ALTER TABLE contract_year_basis ENABLE ROW LEVEL SECURITY;

-- Hodnota parametra k dátumu; pred prvou platnosťou najstaršia hodnota (zmluvy podpísané pred zavedením parametra)
CREATE FUNCTION contract_param(p_org uuid, p_code text, p_on date, p_year smallint DEFAULT NULL) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(
    (SELECT value FROM price_parameter
      WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year AND valid_from <= p_on
      ORDER BY valid_from DESC LIMIT 1),
    (SELECT value FROM price_parameter
      WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year
      ORDER BY valid_from LIMIT 1))
$$;

-- Posledná zadaná trhová hodnota roka k dátumu: odhad portfólia alebo očakávaná cena SPOT pre FVE (otázka 32)
CREATE FUNCTION contract_market_value(p_org uuid, p_year integer, p_on date, p_kind text)
RETURNS TABLE (value numeric, on_date date)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE p_kind WHEN 'portfolio' THEN m.portfolio_eur_mwh ELSE m.spot_fve_eur_mwh END, m.on_date
    FROM market_price_daily m
   WHERE m.org_id = p_org AND m.delivery_year = p_year AND m.corrected_at IS NULL AND m.on_date <= p_on
     AND (CASE p_kind WHEN 'portfolio' THEN m.portfolio_eur_mwh ELSE m.spot_fve_eur_mwh END) IS NOT NULL
   ORDER BY m.on_date DESC
   LIMIT 1
$$;

-- Hodnoty pre zmluvu × rok k dátumu (deň podpisu, pri nepodpísanej dnes). Typ predajcu z obchodníka zmluvy,
-- bez obchodníka ako obchodník (otázka 28). Bez cien BL/PL ku dňu podpisu cena pre obchodníka z nákupnej ceny
-- pri deale z HubSpotu (contract_purchase, otázka 26).
CREATE FUNCTION contract_basis_values(c contract, p_year integer, p_on date) RETURNS contract_year_basis
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  b contract_year_basis;
  m record;
BEGIN
  b.contract_id := c.id;
  b.year := p_year;
  b.ref_date := p_on;
  b.source := 'vypocet';
  b.seller_type := coalesce((SELECT seller_type FROM app_user WHERE id = c.owner_id), 'obchodnik');
  b.trader_price := trader_price(c.org_id, p_year::smallint, p_on);
  IF b.trader_price IS NULL THEN
    b.trader_price := (SELECT price_eur_mwh FROM contract_purchase
                        WHERE contract_id = c.id AND delivery_year = p_year ORDER BY priced_on DESC LIMIT 1);
    IF b.trader_price IS NOT NULL THEN
      b.source := 'hubspot';
    END IF;
  END IF;
  SELECT * INTO m FROM contract_market_value(c.org_id, p_year, p_on, 'portfolio');
  b.portfolio_eur_mwh := m.value;
  b.portfolio_on := m.on_date;
  IF c.type = 'vykup' THEN
    b.min_additive := coalesce(c.vykup_min_additive, contract_param(c.org_id,
      CASE WHEN EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                         WHERE x.contract_id = c.id AND o.source_category = 'lokalny_zdroj')
           THEN 'min_aditiv_vykup_lz' ELSE 'min_aditiv_vykup' END, p_on));
  ELSE
    b.min_additive := contract_param(c.org_id,
      CASE b.seller_type WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, p_on);
  END IF;
  b.energopomoc_price := contract_param(c.org_id, 'nakup_energopomoc', p_on, p_year::smallint);
  b.viwa_additive := CASE WHEN c.viwa_package IS NOT NULL THEN contract_param(c.org_id, 'viwa_aditiv_' || c.viwa_package, p_on) END;
  b.computed_at := now();
  RETURN b;
END;
$$;

-- ============================================================================
-- 3. Ročná bilancia zmluvy po mesiacoch (časť 6.2, 26.1)
-- ============================================================================

-- Bilancia zmluvy za rok: objem, výnos komodity, poplatky, pridaná hodnota (náklad zo snímky ku dňu podpisu alebo
-- z výnimky), marža firmy (náklad z dnešného odhadu portfólia; iba s právom „vidieť maržu“, inak NULL), tranža.
-- Po mesiacoch OOM v zmluve: začatý mesiac celý, neúplný rok = mesiace / 12, zmluva kratšia ako 12 mesiacov
-- = množstvo za celé obdobie rozdelené po mesiacoch (odpovede 1, 17). Výkup a VIWA: plán výkupu OOM / 12.
-- Výkup s pevnou cenou: nákup = predaj, pridaná hodnota aj marža 0 € (skutočný nákup dopĺňa trader v Cockpite, otázka 33).
-- Vráti riadok iba pre zmluvu, ktorú používateľ vidí.
CREATE FUNCTION contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE (
  year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric,
  added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text,
  basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric,
  portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
         CASE kl.kind
           WHEN 'fix' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'cennik' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'energo' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'spot_plus_eur' THEN kl.ad * kl.vol
           WHEN 'vykup' THEN CASE kl.price_model WHEN 'spot_minus_eur' THEN kl.ad * kl.vol
                                                 WHEN 'spot_minus_pct' THEN kl.pct / 100 * (SELECT spot_fve FROM mk) * kl.vol
                                                 -- výkup s pevnou cenou: nákup = predaj, pridaná hodnota a marža 0 (otázka 33)
                                                 WHEN 'fix' THEN kl.vt * kl.vol END
           WHEN 'viwa' THEN (SELECT viwa_additive FROM b) * kl.vol
         END AS rev,
         CASE kl.kind
           WHEN 'fix' THEN coalesce((SELECT exception_value FROM b),
                                    CASE WHEN (SELECT seller_type FROM b) = 'manazer' THEN (SELECT portfolio_eur_mwh FROM b)
                                         ELSE (SELECT trader_price FROM b) END)
           WHEN 'cennik' THEN (SELECT portfolio_eur_mwh FROM b)
           WHEN 'energo' THEN (SELECT energopomoc_price FROM b)
           WHEN 'spot_plus_eur' THEN coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b))
           WHEN 'vykup' THEN CASE WHEN kl.price_model = 'fix' THEN kl.vt
                                  ELSE coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b)) END
           WHEN 'viwa' THEN 0
         END AS unit_cost,
         CASE kl.kind
           WHEN 'fix' THEN (SELECT portfolio FROM mk)
           WHEN 'cennik' THEN (SELECT portfolio FROM mk)
           WHEN 'energo' THEN (SELECT energopomoc_price FROM b)
           WHEN 'spot_plus_eur' THEN 0
           WHEN 'vykup' THEN CASE WHEN kl.price_model = 'fix' THEN kl.vt
                                  ELSE coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b)) END
           WHEN 'viwa' THEN 0
         END AS unit_mcost
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
COMMENT ON FUNCTION contract_year_calc(uuid, integer) IS
  'ročná bilancia zmluvy: objem, výnos komodity, poplatky, pridaná hodnota, marža firmy (iba s právom), tranža; iba viditeľná zmluva';

-- ============================================================================
-- 4. Snímka, párovanie výnimiek a príznaky „Pod hranicou bez výnimky“ a „Chýba cena pre obchodníka“
-- ============================================================================

-- Pri podpísanej zmluve uloží snímku pre roky zmluvy (deň podpisu) a spáruje schválenú výnimku (zákazník, rok,
-- model individuálnej ceny z importu, podpis do „platná do“; najnovšia sa stane Použitou a hranicou). Potom pre každý rok bilancia a príznaky:
--   Pod hranicou bez výnimky – individuálna cena (FIX, SPOT + aditív, výkup), pridaná hodnota < 0, bez výnimky
--     (otázka 30); príznak uzavretý schvaľovateľom sa znova neotvorí;
--   Chýba cena pre obchodníka – podpis od 1. 1. 2026 a FIX bez ceny pre obchodníka ku dňu podpisu (otázka 26).
-- Vráti upozornenia pre náhľad importu.
CREATE FUNCTION contract_basis_refresh(p_contract_id uuid) RETURNS text[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c      contract;
  v_from date;
  v_to   date;
  y      integer;
  v      contract_year_basis;
  s      contract_year_basis;
  e      price_exception;
  r      record;
  v_mod  text;
  v_det  text;
  v_warn text[] := '{}';
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF NOT FOUND THEN
    RETURN v_warn;
  END IF;
  SELECT min(valid_from), max(coalesce(valid_to, make_date(extract(year FROM crm_today())::int + 1, 12, 31)))
    INTO v_from, v_to FROM contract_oom WHERE contract_id = c.id AND valid_from IS NOT NULL;
  DELETE FROM contract_year_basis
   WHERE contract_id = c.id
     AND (c.signed_on IS NULL OR v_from IS NULL
          OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  UPDATE contract_flag SET resolved_at = now()
   WHERE contract_id = c.id AND code IN ('pod_hranicou_bez_vynimky', 'chyba_cena') AND year IS NOT NULL AND resolved_at IS NULL
     AND (v_from IS NULL OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  IF v_from IS NULL THEN
    RETURN v_warn;
  END IF;

  FOR y IN extract(year FROM v_from)::int .. extract(year FROM v_to)::int LOOP
    IF c.signed_on IS NOT NULL THEN
      v := contract_basis_values(c, y, c.signed_on);
      SELECT * INTO s FROM contract_year_basis WHERE contract_id = c.id AND year = y;
      v.exception_id := s.exception_id;
      v.exception_value := s.exception_value;
      IF v.exception_id IS NULL AND c.phase = 'podpisana' THEN
        v_mod := (SELECT p.price_model::text FROM contract_price p
                   WHERE p.contract_id = c.id AND p.slot = 'komodita' AND p.source = 'import' AND p.price_model <> 'cennik'
                     AND p.valid_from <= make_date(y, 12, 31) AND (p.valid_to IS NULL OR p.valid_to >= make_date(y, 1, 1))
                   ORDER BY p.valid_from DESC LIMIT 1);
        e := NULL;
        SELECT * INTO e FROM price_exception x
         WHERE x.org_id = c.org_id AND x.company_id IS NOT DISTINCT FROM c.company_id
           AND x.person_id IS NOT DISTINCT FROM c.person_id AND y = ANY (x.years) AND x.price_model::text = v_mod
           AND ((x.status = 'schvalena' AND c.signed_on <= x.valid_until) OR (x.status = 'pouzita' AND x.contract_id = c.id))
         ORDER BY x.decided_at DESC
         LIMIT 1;
        IF e.id IS NOT NULL THEN
          v.exception_id := e.id;
          v.exception_value := e.requested_value;
          UPDATE price_exception SET status = 'pouzita', contract_id = c.id WHERE id = e.id AND status = 'schvalena';
        END IF;
      END IF;
      INSERT INTO contract_year_basis (contract_id, year, ref_date, seller_type, trader_price, portfolio_eur_mwh, portfolio_on,
                                       min_additive, energopomoc_price, viwa_additive, exception_id, exception_value, source)
      VALUES (c.id, y, v.ref_date, v.seller_type, v.trader_price, v.portfolio_eur_mwh, v.portfolio_on, v.min_additive,
              v.energopomoc_price, v.viwa_additive, v.exception_id, v.exception_value, v.source)
      ON CONFLICT (contract_id, year) DO UPDATE
         SET ref_date = EXCLUDED.ref_date, seller_type = EXCLUDED.seller_type, trader_price = EXCLUDED.trader_price,
             portfolio_eur_mwh = EXCLUDED.portfolio_eur_mwh, portfolio_on = EXCLUDED.portfolio_on,
             min_additive = EXCLUDED.min_additive, energopomoc_price = EXCLUDED.energopomoc_price,
             viwa_additive = EXCLUDED.viwa_additive, exception_id = EXCLUDED.exception_id,
             exception_value = EXCLUDED.exception_value, source = EXCLUDED.source, computed_at = now()
       WHERE (contract_year_basis.ref_date, contract_year_basis.seller_type, contract_year_basis.trader_price,
              contract_year_basis.portfolio_eur_mwh, contract_year_basis.portfolio_on, contract_year_basis.min_additive,
              contract_year_basis.energopomoc_price, contract_year_basis.viwa_additive, contract_year_basis.exception_id,
              contract_year_basis.exception_value, contract_year_basis.source)
             IS DISTINCT FROM
             (EXCLUDED.ref_date, EXCLUDED.seller_type, EXCLUDED.trader_price, EXCLUDED.portfolio_eur_mwh, EXCLUDED.portfolio_on,
              EXCLUDED.min_additive, EXCLUDED.energopomoc_price, EXCLUDED.viwa_additive, EXCLUDED.exception_id,
              EXCLUDED.exception_value, EXCLUDED.source);
    END IF;

    SELECT * INTO r FROM contract_year_calc(c.id, y);
    -- Pod hranicou bez výnimky (individuálna cena)
    IF c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.model ~ '(fix|spot_plus_eur|vykup)' AND r.added_value_eur < 0
       AND r.exception_id IS NULL THEN
      v_det := format('Pridaná hodnota %s: %s € – cena pod hranicou bez schválenej výnimky.', y,
                      replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      v_warn := v_warn || format('Pod hranicou bez výnimky %s: pridaná hodnota %s €', y,
                                 replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      IF NOT EXISTS (SELECT 1 FROM contract_flag f WHERE f.contract_id = c.id AND f.code = 'pod_hranicou_bez_vynimky' AND f.year = y
                        AND (f.resolved_at IS NULL OR f.resolved_by IS NOT NULL)) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'pod_hranicou_bez_vynimky', y, v_det);
      ELSE
        UPDATE contract_flag SET detail = v_det
         WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL
           AND detail IS DISTINCT FROM v_det;
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL;
    END IF;
    -- Chýba cena pre obchodníka (podpis od 1. 1. 2026)
    IF c.signed_on >= '2026-01-01' AND c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.missing = 'cena pre obchodníka' THEN
      v_det := format('chýba cena pre obchodníka %s (ceny BL/PL ku dňu podpisu %s)', y, to_char(c.signed_on, 'FMDD. FMMM. YYYY'));
      v_warn := v_warn || ('Chýba cena: ' || v_det);
      IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'chyba_cena', y, v_det);
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL;
    END IF;
  END LOOP;
  RETURN v_warn;
END;
$$;
COMMENT ON FUNCTION contract_basis_refresh(uuid) IS
  'snímka ku dňu podpisu, párovanie výnimky, príznaky Pod hranicou bez výnimky a Chýba cena pre obchodníka; vráti upozornenia';

-- „Chýba cena“ z 0026 (komodita, balík VIWA) je príznak bez roka; s rokom = chýba cena pre obchodníka (snímka)
CREATE OR REPLACE FUNCTION contract_price_missing_refresh(p_contract_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') THEN
    FOR co IN
      SELECT x.*, o.eic
        FROM contract_oom x JOIN oom o ON o.id = x.oom_id
       WHERE x.contract_id = c.id
         AND ((c.type::text LIKE 'dodavka%' AND o.type = 'spotreba') OR c.type = 'vykup')
       ORDER BY o.eic
    LOOP
      IF co.valid_from IS NULL THEN
        v_miss := v_miss || format('OOM %s: chýba účinnosť od', co.eic);
        CONTINUE;
      END IF;
      v_from := greatest(co.valid_from, v_y_from);
      v_to := coalesce(co.valid_to, greatest(v_from, v_y_to));
      CONTINUE WHEN v_to < v_from;
      IF NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
                     - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                                  WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita'),
                                '{}'::datemultirange)) THEN
        v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                   to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
      END IF;
    END LOOP;
    IF c.type = 'viwa' THEN
      IF c.viwa_package IS NULL THEN
        v_miss := v_miss || 'chýba balík VIWA (doplní Servis)'::text;
      ELSIF c.valid_from IS NOT NULL THEN
        v_from := greatest(c.valid_from, v_y_from);
        v_to := coalesce(contract_effective_to(c), greatest(v_from, v_y_to));
        IF v_to >= v_from AND NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
             - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                          WHERE p.contract_id = c.id AND p.slot = 'viwa_ucet'), '{}'::datemultirange)) THEN
          v_miss := v_miss || 'chýba cena balíka VIWA v cenníku'::text;
        END IF;
      END IF;
    END IF;
  END IF;

  v_detail := nullif(array_to_string(v_miss, '; '), '');
  IF v_detail IS NULL THEN
    UPDATE contract_flag SET resolved_at = now()
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;

-- Import, doplnenie z XM Trade a balík VIWA prepočítajú aj snímku a príznaky
CREATE OR REPLACE FUNCTION contract_import_one(p_org uuid, p_rows jsonb, p_xm jsonb, p_deferred jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c_head constant text[] := ARRAY['op_id', 'number', 'phase', 'commodity', 'household', 'ico', 'dic', 'ic_dph', 'company_name',
    'first_name', 'last_name', 'person_op_id', 'small_business', 'list_price', 'auto_prolong', 'valid_from', 'valid_to',
    'signed_on', 'created_by_name', 'owner_name', 'updated_at', 'viwa_package', 'close_reason', 'sum_mwh'];
  c_phase constant jsonb := '{"rozpracovana": "Rozpracovaná", "caka_na_podpis": "Čaká na podpis",
    "fyzicke_podpisovanie": "Fyzické podpisovanie", "elektronicke_podpisovanie": "Elektronické podpisovanie",
    "podpisana": "Podpísaná", "odmietnuta": "Odmietnutá", "ukoncena": "Ukončená", "neuspesna": "Neúspešná"}';
  c_type constant jsonb := '{"dodavka_domacnost": "dodávka – domácnosť", "dodavka_firma_nn": "dodávka – firma NN",
    "dodavka_firma_vn": "dodávka – firma VN", "vykup": "výkup", "viwa": "VIWA"}';
  h          jsonb := p_rows -> 0;
  v_import   uuid := nullif(current_setting('app.contract_import_id', true), '')::uuid;
  v_country  country_code := (SELECT country FROM org WHERE id = p_org);
  v_err      text[] := '{}';
  v_warn     text[] := '{}';
  v_chg      text[] := '{}';
  v_kontr    text[] := '{}';
  v_miss     jsonb := '[]';
  v_xm_out   jsonb := '[]';
  v_cols     text[];
  a          import_alias;
  v_phase    contract_phase;
  v_owner    uuid;
  v_old      contract;
  v_new      contract;
  v_company  uuid;
  v_person   uuid;
  v_cust_new boolean := false;
  v_digits   text;
  v_ico      text;
  v_cust_org uuid;
  v_type     contract_type;
  v_reason   contract_close_reason;
  v_package  text;
  v_from     date;
  v_eics     text[];
  v_eic      text;
  o          oom;
  v_oom      jsonb := '{}';
  v_volt     text[];
  v_pid      uuid;
  v_prog     uuid;
  v_tmp      jsonb;
  v_prices   jsonb;
  co         record;
  v_name     text;
  v_n        integer;
  v_detail   text;
  v_vo       uuid[] := '{}';
  v_d        text[];
BEGIN
  -- 1. hlavička zmluvy je rovnaká vo všetkých riadkoch; chyby čítania súboru
  SELECT array_agg(DISTINCT k ORDER BY k) INTO v_cols
    FROM unnest(c_head) k, jsonb_array_elements(p_rows) x
   WHERE x -> k IS DISTINCT FROM h -> k;
  IF v_cols IS NOT NULL THEN
    v_err := v_err || format('Riadky zmluvy sa líšia v stĺpcoch %s – opravte export.', array_to_string(v_cols, ', '));
  END IF;
  v_err := v_err || ARRAY(SELECT DISTINCT e FROM jsonb_array_elements(p_rows) x,
                                 jsonb_array_elements_text(coalesce(x -> 'parse_errors', '[]')) e);
  IF nullif(btrim(h ->> 'number'), '') IS NULL THEN
    v_err := v_err || 'Chýba číslo zmluvy.'::text;
  END IF;

  -- 2. existujúca zmluva: ID z Office portálu, potom číslo
  IF nullif(h ->> 'op_id', '') IS NOT NULL THEN
    SELECT * INTO v_old FROM contract WHERE op_id = (h ->> 'op_id')::uuid;
  END IF;
  IF v_old.id IS NULL THEN
    SELECT * INTO v_old FROM contract WHERE number = btrim(h ->> 'number');
    IF v_old.id IS NOT NULL AND v_old.op_id IS NOT NULL AND v_old.op_id::text IS DISTINCT FROM nullif(h ->> 'op_id', '') THEN
      v_err := v_err || format('Číslo zmluvy %s je v CRM pri inej zmluve z Office portálu.', h ->> 'number');
    END IF;
  END IF;
  IF v_old.id IS NOT NULL AND v_old.org_id <> p_org THEN
    v_err := v_err || 'Zmluva patrí inej spoločnosti skupiny.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 3. bez zmeny v Office portáli (Greatest_updated_at): nespracúva sa, iba údaje z XM Trade (účinnosť, produkt DD)
  IF v_old.id IS NOT NULL AND v_old.op_updated_at IS NOT NULL AND nullif(h ->> 'updated_at', '') IS NOT NULL
     AND (h ->> 'updated_at')::timestamptz <= v_old.op_updated_at THEN
    FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
      v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_old.company_id, v_old.person_id);
    END LOOP;
    v_chg := contract_import_xm_link(v_old.id, p_xm);
    RETURN jsonb_build_object('action', CASE WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
             'contract_id', v_old.id, 'changes', to_jsonb(v_chg), 'warnings', '[]'::jsonb, 'errors', '[]'::jsonb,
             'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', false,
             'company_id', v_old.company_id, 'person_id', v_old.person_id);
  END IF;

  -- 4. fáza a obchodník cez preklady (neznámy názov = chyba s „Pridať preklad“, rozhodnutie 5; otázka 22)
  a := import_alias_resolve(p_org, 'office_portal', 'faza', coalesce(h ->> 'phase', ''));
  IF a.id IS NULL THEN
    v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'faza', 'name', coalesce(h ->> 'phase', ''));
    v_err := v_err || format('Neznáma fáza „%s“ – pridajte preklad.', coalesce(h ->> 'phase', ''));
  ELSE
    v_phase := a.target::contract_phase;
  END IF;
  IF nullif(btrim(h ->> 'owner_name'), '') IS NOT NULL THEN
    a := import_alias_resolve(p_org, 'office_portal', 'obchodnik', h ->> 'owner_name');
    IF a.id IS NULL THEN
      v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'obchodnik', 'name', btrim(h ->> 'owner_name'));
      v_err := v_err || format('Neznámy obchodník „%s“ – pridajte preklad na používateľa CRM.', btrim(h ->> 'owner_name'));
    ELSE
      v_owner := a.target::uuid;
    END IF;
  ELSIF v_old.owner_id IS NULL THEN
    -- tvorca zmluvy sa za obchodníka nedosadzuje (Peter, otázka 22), je iba informácia
    v_warn := v_warn || ('Zmluva nemá obchodníka (Uzatvoril) – uloží sa bez neho'
                         || coalesce(format(' (vytvoril: %s)', nullif(btrim(h ->> 'created_by_name'), '')), '') || '.');
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 5. zákazník (časť 8.2): firma podľa IČO, domácnosť podľa Osoba_ID; chýbajúci sa založí s príznakom
  --    „založený importom“, vlastník = obchodník zo zmluvy (doplnok b)
  v_eics := ARRAY(SELECT DISTINCT upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) FROM jsonb_array_elements(p_rows) x
                   WHERE nullif(btrim(x ->> 'eic'), '') IS NOT NULL ORDER BY 1);
  IF coalesce((h ->> 'household')::boolean, false) THEN
    v_name := btrim(concat_ws(' ', btrim(h ->> 'first_name'), btrim(h ->> 'last_name')));
    IF nullif(h ->> 'person_op_id', '') IS NOT NULL THEN
      SELECT id INTO v_person FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid;
    END IF;
    v_person := coalesce(v_person, v_old.person_id);
    IF v_person IS NULL THEN
      -- prvé párovanie (napr. po presune z HubSpotu): aktuálny zákazník-osoba OOM zmluvy s rovnakým menom
      SELECT min(p.id::text)::uuid, count(DISTINCT p.id) INTO v_person, v_n
        FROM oom x JOIN contact p ON p.id = x.person_id
       WHERE x.org_id = p_org AND x.eic = ANY (v_eics) AND p.op_person_id IS NULL
         AND import_name_norm(p.first_name || ' ' || p.last_name) = import_name_norm(v_name);
      IF v_n > 1 THEN
        v_person := NULL;
      END IF;
    END IF;
    IF v_person IS NOT NULL THEN
      IF NOT crm_contact_access(v_person, 'view') THEN
        v_err := v_err || 'Osoba zákazníka je v CRM, ale nemáte k nej prístup.'::text;
      END IF;
      UPDATE contact SET op_person_id = (h ->> 'person_op_id')::uuid
       WHERE id = v_person AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
    ELSIF nullif(btrim(h ->> 'first_name'), '') IS NULL OR nullif(btrim(h ->> 'last_name'), '') IS NULL THEN
      v_err := v_err || 'Nová osoba: chýba meno alebo priezvisko.'::text;
    ELSE
      IF EXISTS (SELECT 1 FROM contact WHERE org_id = p_org
                    AND import_name_norm(first_name || ' ' || last_name) = import_name_norm(v_name)) THEN
        v_warn := v_warn || 'Možná duplicita: osoba s rovnakým menom už v CRM je – založí sa nová, skontrolujte.'::text;
        v_kontr := v_kontr || 'možná duplicita osoby'::text;
      END IF;
      INSERT INTO contact (org_id, first_name, last_name, is_household, owner_id, op_person_id, created_by_import, address)
      VALUES (p_org, btrim(h ->> 'first_name'), btrim(h ->> 'last_name'), true, v_owner,
              nullif(h ->> 'person_op_id', '')::uuid, v_import,
              (SELECT btrim(x ->> 'address') FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                WHERE nullif(btrim(x ->> 'address'), '') IS NOT NULL LIMIT 1))
      RETURNING id INTO v_person;
      v_cust_new := true;
    END IF;
  ELSE
    v_digits := regexp_replace(coalesce(h ->> 'ico', ''), '\D', '', 'g');
    v_ico := CASE WHEN v_country = 'HR' THEN v_digits ELSE lpad(v_digits, 8, '0') END;
    IF v_digits = '' THEN
      v_err := v_err || 'Chýba IČO firmy.'::text;
    ELSE
      SELECT id, org_id INTO v_company, v_cust_org FROM company WHERE country = v_country AND ico = v_ico;
      IF v_company IS NOT NULL AND v_cust_org <> p_org THEN
        v_err := v_err || format('Firma s IČO %s patrí inej spoločnosti skupiny.', v_ico);
      ELSIF v_company IS NOT NULL THEN
        IF NOT crm_company_access(v_company, 'view') THEN
          v_err := v_err || format('Firma s IČO %s je v CRM, ale nemáte k nej prístup.', v_ico);
        END IF;
        UPDATE company SET op_person_id = (h ->> 'person_op_id')::uuid
         WHERE id = v_company AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM company WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
      ELSIF nullif(btrim(h ->> 'company_name'), '') IS NULL THEN
        v_err := v_err || 'Nová firma: chýba názov.'::text;
      ELSE
        INSERT INTO company (org_id, name, ico, dic, ic_dph, is_customer, owner_id, op_person_id, created_by_import)
        VALUES (p_org, btrim(h ->> 'company_name'), v_ico, nullif(btrim(h ->> 'dic'), ''), nullif(btrim(h ->> 'ic_dph'), ''),
                true, v_owner, nullif(h ->> 'person_op_id', '')::uuid, v_import)
        RETURNING id INTO v_company;
        v_cust_new := true;
      END IF;
    END IF;
  END IF;
  IF v_cust_new AND v_owner IS NULL THEN
    v_warn := v_warn || 'Nový zákazník je bez vlastníka – zmluva nemá obchodníka.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 6. nové OOM z XM Trade pre zákazníka tejto zmluvy (oba súbory v jednom behu); chyba OOM = chyba zmluvy
  --    s pôvodným dôvodom (aj chýbajúci preklad z XM Trade)
  FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
    v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_company, v_person);
    IF v_xm_out -> -1 ->> 'action' = 'chyba' THEN
      v_err := v_err || format('OOM %s (XM Trade, riadok %s): %s', v_xm_out -> -1 ->> 'eic', v_tmp ->> 'row', v_xm_out -> -1 ->> 'error');
      v_miss := v_miss || coalesce(v_xm_out -> -1 -> 'missing', '[]');
    END IF;
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 7. OOM zmluvy: musia byť v CRM; produkt a program pri OOM, množstvo VT/NT (MWh), výkon zdroja
  IF cardinality(v_eics) = 0 THEN
    v_err := v_err || 'Zmluva nemá žiadne OOM (EIC).'::text;
  END IF;
  FOREACH v_eic IN ARRAY v_eics LOOP
    SELECT * INTO o FROM oom WHERE eic = v_eic;
    IF o.id IS NULL THEN
      v_err := v_err || format('OOM %s nie je v CRM – najprv nahrajte export z XM Trade.', v_eic);
      CONTINUE;
    ELSIF o.org_id <> p_org THEN
      v_err := v_err || format('OOM %s patrí inej spoločnosti skupiny.', v_eic);
      CONTINUE;
    END IF;
    IF contract_import_eic_warning(v_eic) IS NOT NULL THEN
      v_warn := v_warn || contract_import_eic_warning(v_eic);
    END IF;
    IF (o.company_id, o.person_id) IS DISTINCT FROM (v_company, v_person) THEN
      v_warn := v_warn || format('OOM %s má v CRM iného aktuálneho zákazníka ako zmluva (prepis?).', v_eic);
    END IF;
    v_tmp := (SELECT jsonb_agg(x ORDER BY (x ->> 'row')::int) FROM jsonb_array_elements(p_rows) x
               WHERE upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) = v_eic);
    IF (SELECT count(DISTINCT jsonb_build_array(x -> 'qty_vt_mwh', x -> 'qty_nt_mwh', x -> 'source_power_kw', x -> 'product_oom'))
          FROM jsonb_array_elements(v_tmp) x) > 1 THEN
      v_warn := v_warn || format('OOM %s: riadky sa líšia v množstve, výkone alebo produkte – použije sa prvý.', v_eic);
    END IF;
    v_pid := NULL;
    v_prog := NULL;
    v_name := btrim(coalesce(v_tmp -> 0 ->> 'product_oom', ''));
    IF v_name <> '' THEN
      a := import_alias_resolve(p_org, 'office_portal', 'produkt_oom', v_name);
      IF a.id IS NULL THEN
        IF NOT v_miss @> jsonb_build_array(jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name)) THEN
          v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name);
          v_err := v_err || format('Neznámy produkt pri OOM „%s“ – pridajte preklad.', v_name);
        END IF;
      ELSIF coalesce((a.target_extra ->> 'program')::boolean, false) THEN
        -- VBattery: program z Office portálu, produkt DDx z XM Trade (rozhodnutie 4, otázka 12a) iba pri OOM spotreby;
        -- výrobné (otázka 24) a virtuálne OOM majú iba program
        v_prog := (SELECT id FROM product WHERE code = a.target);
        IF o.type = 'spotreba' THEN
          v_pid := coalesce(contract_import_xm_dd((SELECT x ->> 'product' FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                                                    WHERE x ->> 'eic' = v_eic LIMIT 1)),
                            (SELECT x.product_id FROM contract_oom x WHERE x.contract_id = v_old.id AND x.oom_id = o.id));
          IF v_pid IS NULL THEN
            v_warn := v_warn || format('OOM %s: produkt DD pri VBattery doplní export z XM Trade.', v_eic);
          END IF;
        END IF;
      ELSIF a.target_extra ? 'ano' THEN
        -- DDx: ANO alebo NIE Energopomoc podľa cenovej regulácie OOM
        v_pid := (SELECT id FROM product WHERE code = CASE o.price_regulation WHEN true THEN a.target_extra ->> 'ano'
                                                                              WHEN false THEN a.target END);
        IF o.price_regulation IS NULL THEN
          v_warn := v_warn || format('OOM %s nemá cenovú reguláciu – produkt %s ANO/NIE nejde určiť.', v_eic, v_name);
        END IF;
      ELSE
        v_pid := (SELECT id FROM product WHERE code = a.target);
      END IF;
      IF coalesce((a.target_extra ->> 'verejne_osvetlenie')::boolean, false)
         OR (SELECT tariff_variant FROM product WHERE id = v_pid) = 'verejne_osvetlenie' THEN
        v_vo := v_vo || o.id;
      END IF;
    END IF;
    IF nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0) IS NOT NULL AND o.source_power_kw IS NOT NULL
       AND round((v_tmp -> 0 ->> 'source_power_kw')::numeric, 3) <> o.source_power_kw THEN
      v_warn := v_warn || format('OOM %s: výkon zdroja v zmluve %s kW, na OOM %s kW (OOM sa nemení).', v_eic,
                                 (v_tmp -> 0 ->> 'source_power_kw')::numeric, o.source_power_kw);
    END IF;
    v_oom := v_oom || jsonb_build_object(v_eic, jsonb_build_object(
               'oom_id', o.id, 'eic', v_eic, 'product_id', v_pid, 'program_id', v_prog, 'voltage', o.voltage_level,
               'qty_vt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_vt_mwh')::numeric, 0), 3),
               'qty_nt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_nt_mwh')::numeric, 0), 3),
               'source_power_kw', round(nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0), 3)));
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 8. typ zmluvy (časť 1): výkup, VIWA, domácnosť, firma NN/VN podľa napäťovej úrovne OOM
  v_volt := ARRAY(SELECT DISTINCT coalesce(y.value ->> 'voltage', '') FROM jsonb_each(v_oom) y);
  v_type := CASE
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina_vyroba' THEN 'vykup'
    WHEN import_name_norm(h ->> 'commodity') = 'nezname' OR h ->> 'number' ~* 'VIW' THEN 'viwa'
    WHEN coalesce((h ->> 'household')::boolean, false) THEN 'dodavka_domacnost'
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina' THEN
      CASE WHEN v_volt && ARRAY['vn', 'vvn'] THEN 'dodavka_firma_vn' ELSE 'dodavka_firma_nn' END
  END::contract_type;
  IF v_type IS NULL THEN
    v_err := v_err || format('Neznáma komodita „%s“.', coalesce(h ->> 'commodity', ''));
  ELSIF v_type::text LIKE 'dodavka_firma%' THEN
    IF v_volt && ARRAY['vn', 'vvn'] AND 'nn' = ANY (v_volt) THEN
      v_err := v_err || 'Zmluva má OOM na NN aj VN – NN a VN sú samostatné zmluvy.'::text;
    ELSIF '' = ANY (v_volt) THEN
      v_warn := v_warn || 'Napäťová úroveň OOM chýba – zmluva je typu firma NN.'::text;
    END IF;
  END IF;
  -- údaje CRM z exportu iba neprázdne (doplnok a); balík VIWA a dôvod uzatvorenia, keď ich zostava doplní
  v_package := lower(nullif(btrim(h ->> 'viwa_package'), ''));
  IF v_package IS NOT NULL AND v_package NOT IN ('basic', 'plus', 'pro') THEN
    v_err := v_err || format('Neznámy balík VIWA „%s“.', h ->> 'viwa_package');
  END IF;
  IF nullif(btrim(h ->> 'close_reason'), '') IS NOT NULL THEN
    v_reason := (SELECT e FROM unnest(enum_range(NULL::contract_close_reason)) e
                  WHERE e::text = replace(import_name_norm(h ->> 'close_reason'), ' ', '_'));
    IF v_reason IS NULL THEN
      v_err := v_err || format('Neznámy dôvod uzatvorenia „%s“.', h ->> 'close_reason');
    END IF;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 9. zmluva; prázdna bunka nikdy neprepíše hodnotu v CRM (doplnok a); účinnosť domácnosti z XM Trade (rozhodnutie 3)
  v_from := CASE WHEN v_type = 'dodavka_domacnost'
                 THEN coalesce(contract_import_xm_from(p_xm, v_eics), (h ->> 'valid_from')::date, v_old.valid_from)
                 ELSE coalesce((h ->> 'valid_from')::date, v_old.valid_from) END;
  IF v_from IS NULL AND v_phase = 'podpisana' THEN
    v_warn := v_warn || CASE WHEN v_type = 'dodavka_domacnost' THEN 'Účinnosť od chýba – doplní ju export z XM Trade.'
                             ELSE 'Účinnosť od chýba.' END;
  END IF;
  IF v_old.id IS NULL THEN
    INSERT INTO contract (org_id, number, op_id, company_id, person_id, type, phase, valid_from, valid_to, signed_on,
                          auto_prolong, small_business, list_price, viwa_package, close_reason, owner_id, created_by_name,
                          last_import_id)
    VALUES (p_org, btrim(h ->> 'number'), nullif(h ->> 'op_id', '')::uuid, v_company, v_person, v_type, v_phase, v_from,
            (h ->> 'valid_to')::date, (h ->> 'signed_on')::date, coalesce((h ->> 'auto_prolong')::boolean, false),
            coalesce((h ->> 'small_business')::boolean, false), coalesce((h ->> 'list_price')::boolean, false),
            v_package, v_reason, v_owner, nullif(btrim(h ->> 'created_by_name'), ''), v_import)
    RETURNING * INTO v_new;
    v_chg := v_chg || format('Nová zmluva: %s, %s, OOM %s', c_type ->> v_type::text, c_phase ->> v_phase::text,
                             cardinality(v_eics));
  ELSE
    UPDATE contract
       SET number = btrim(h ->> 'number'), op_id = coalesce(nullif(h ->> 'op_id', '')::uuid, op_id),
           company_id = v_company, person_id = v_person, type = v_type, phase = v_phase, valid_from = v_from,
           valid_to = coalesce((h ->> 'valid_to')::date, valid_to), signed_on = coalesce((h ->> 'signed_on')::date, signed_on),
           auto_prolong = coalesce((h ->> 'auto_prolong')::boolean, auto_prolong),
           small_business = coalesce((h ->> 'small_business')::boolean, small_business),
           list_price = coalesce((h ->> 'list_price')::boolean, list_price),
           viwa_package = coalesce(v_package, viwa_package), close_reason = coalesce(v_reason, close_reason),
           owner_id = coalesce(v_owner, owner_id),
           created_by_name = coalesce(nullif(btrim(h ->> 'created_by_name'), ''), created_by_name)
     WHERE id = v_old.id
    RETURNING * INTO v_new;
    IF v_new.number <> v_old.number THEN
      v_chg := v_chg || format('Číslo %s → %s', v_old.number, v_new.number);
    END IF;
    IF v_new.phase <> v_old.phase THEN
      v_chg := v_chg || format('Fáza %s → %s', c_phase ->> v_old.phase::text, c_phase ->> v_new.phase::text);
    END IF;
    IF v_new.type <> v_old.type THEN
      v_chg := v_chg || format('Typ %s → %s', c_type ->> v_old.type::text, c_type ->> v_new.type::text);
    END IF;
    IF (v_new.company_id, v_new.person_id) IS DISTINCT FROM (v_old.company_id, v_old.person_id) THEN
      v_chg := v_chg || 'Zákazník zmluvy zmenený'::text;
    END IF;
    IF v_new.valid_from IS DISTINCT FROM v_old.valid_from THEN
      v_chg := v_chg || format('Účinnosť od %s → %s', coalesce(to_char(v_old.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.valid_from, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.valid_to IS DISTINCT FROM v_old.valid_to THEN
      v_chg := v_chg || format('Účinnosť do %s → %s', coalesce(to_char(v_old.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'),
                               coalesce(to_char(v_new.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'));
    END IF;
    IF v_new.signed_on IS DISTINCT FROM v_old.signed_on THEN
      v_chg := v_chg || format('Platnosť od %s → %s', coalesce(to_char(v_old.signed_on, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.signed_on, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.owner_id IS DISTINCT FROM v_old.owner_id THEN
      v_chg := v_chg || format('Obchodník %s → %s', coalesce((SELECT name FROM app_user WHERE id = v_old.owner_id), '–'),
                               coalesce((SELECT name FROM app_user WHERE id = v_new.owner_id), '–'));
    END IF;
    IF (v_new.auto_prolong, v_new.small_business, v_new.list_price, v_new.viwa_package, v_new.close_reason)
       IS DISTINCT FROM (v_old.auto_prolong, v_old.small_business, v_old.list_price, v_old.viwa_package, v_old.close_reason) THEN
      v_chg := v_chg || 'Príznaky zmluvy (prolongácia, malý podnik, cenníková cena, balík, dôvod)'::text;
    END IF;
  END IF;

  -- 10. OOM v zmluve: odobraté, zmenené, nové (nástupníctvo a prekrytie strážia spúšťače z 0025)
  FOR co IN SELECT x.*, oo.eic FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id WHERE x.contract_id = v_new.id LOOP
    v_tmp := v_oom -> co.eic;
    IF v_tmp IS NULL THEN
      DELETE FROM contract_price WHERE contract_id = v_new.id AND oom_id = co.oom_id;
      DELETE FROM contract_oom WHERE id = co.id;
      v_chg := v_chg || format('OOM %s odobraté', co.eic);
      IF v_new.phase = 'podpisana' THEN
        v_warn := v_warn || format('OOM %s v exporte podpísanej zmluvy chýba – odobraté (zmena má byť novou zmluvou).', co.eic);
      END IF;
    ELSE
      v_d := '{}';
      IF co.qty_vt_mwh <> (v_tmp ->> 'qty_vt_mwh')::numeric OR co.qty_nt_mwh <> (v_tmp ->> 'qty_nt_mwh')::numeric THEN
        v_d := v_d || format('množstvo VT/NT %s/%s → %s/%s MWh', co.qty_vt_mwh, co.qty_nt_mwh,
                             (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric);
      END IF;
      IF co.product_id IS DISTINCT FROM (v_tmp ->> 'product_id')::uuid OR co.program_id IS DISTINCT FROM (v_tmp ->> 'program_id')::uuid THEN
        v_d := v_d || format('produkt %s → %s',
                 coalesce((SELECT string_agg(name, ' + ') FROM product WHERE id IN (co.product_id, co.program_id)), '–'),
                 coalesce((SELECT string_agg(name, ' + ') FROM product
                            WHERE id IN ((v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid)), '–'));
      END IF;
      IF co.source_power_kw IS DISTINCT FROM (v_tmp ->> 'source_power_kw')::numeric THEN
        v_d := v_d || format('výkon %s → %s kW', coalesce(co.source_power_kw::text, '–'), coalesce(v_tmp ->> 'source_power_kw', '–'));
      END IF;
      IF cardinality(v_d) > 0 THEN
        UPDATE contract_oom
           SET product_id = (v_tmp ->> 'product_id')::uuid, program_id = (v_tmp ->> 'program_id')::uuid,
               qty_vt_mwh = (v_tmp ->> 'qty_vt_mwh')::numeric, qty_nt_mwh = (v_tmp ->> 'qty_nt_mwh')::numeric,
               source_power_kw = (v_tmp ->> 'source_power_kw')::numeric
         WHERE id = co.id;
        v_chg := v_chg || format('OOM %s: %s', co.eic, array_to_string(v_d, ', '));
      END IF;
    END IF;
  END LOOP;
  FOR v_tmp IN SELECT y.value FROM jsonb_each(v_oom) y ORDER BY y.key LOOP
    IF NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = v_new.id AND oom_id = (v_tmp ->> 'oom_id')::uuid) THEN
      INSERT INTO contract_oom (contract_id, oom_id, product_id, program_id, qty_vt_mwh, qty_nt_mwh, source_power_kw)
      VALUES (v_new.id, (v_tmp ->> 'oom_id')::uuid, (v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid,
              (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric, (v_tmp ->> 'source_power_kw')::numeric);
      IF v_old.id IS NOT NULL THEN
        v_chg := v_chg || format('OOM %s pridané', v_tmp ->> 'eic');
      END IF;
    END IF;
  END LOOP;
  -- verejné osvetlenie (odpoveď 4): import príznak iba nastaví, nikdy nezruší
  IF cardinality(v_vo) > 0 THEN
    PERFORM set_config('crm.oom_system', 'on', true);
    UPDATE oom SET public_lighting = true WHERE id = ANY (v_vo) AND NOT public_lighting;
    IF FOUND THEN
      v_chg := v_chg || 'Verejné osvetlenie nastavené na OOM'::text;
    END IF;
    PERFORM set_config('crm.oom_system', '', true);
  END IF;

  -- 11. ceny: individuálne z Office portálu, potom z cenníkov
  SELECT jsonb_object_agg(oo.eic, jsonb_build_object(
           'oom_id', x.oom_id, 'product_id', x.product_id, 'valid_from', x.valid_from, 'valid_to', x.valid_to,
           'tariff', CASE WHEN p.tariff_type = 'jednotarif' THEN '1t'
                          WHEN p.tariff_type = 'dvojtarif' AND p.tariff_variant = 'vykurovanie' THEN '2t_vyk'
                          WHEN p.tariff_type = 'dvojtarif' THEN '2t' END))
    INTO v_tmp
    FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
   WHERE x.contract_id = v_new.id;
  v_prices := contract_import_op_prices(p_org, v_new, p_rows, coalesce(v_tmp, '{}'));
  v_err := v_err || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'errors'));
  v_miss := v_miss || (v_prices -> 'missing');
  PERFORM contract_import_fail(v_err, v_miss);
  v_warn := v_warn || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'warnings'));
  v_kontr := v_kontr || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'kontrola'));
  IF v_new.list_price AND jsonb_array_length(v_prices -> 'rows') > 0 THEN
    v_warn := v_warn || 'Zmluva má cenníkovú cenu aj individuálne ceny v exporte – platí cenník.'::text;
    v_prices := jsonb_set(v_prices, '{rows}', '[]');
  END IF;
  IF contract_price_set(v_new.id, 'op', v_prices -> 'rows') AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Individuálne ceny zmenené'::text;
  END IF;
  IF contract_price_list_sync(v_new.id) AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Ceny z cenníka zmenené'::text;
  END IF;

  -- 12. príznaky a upozornenia
  v_detail := contract_price_missing_refresh(v_new.id);
  IF v_detail IS NOT NULL THEN
    v_warn := v_warn || ('Chýba cena: ' || v_detail);
  END IF;
  IF v_old.id IS NULL THEN
    -- produkt Dobieha alebo Ukončený pri novej zmluve podpísanej po zmene stavu produktu
    v_kontr := v_kontr || ARRAY(
      SELECT DISTINCT format('produkt %s je %s', p.name, CASE p.status WHEN 'dobieha' THEN 'Dobieha' ELSE 'Ukončený' END)
        FROM contract_oom x JOIN product p ON p.id IN (x.product_id, x.program_id)
       WHERE x.contract_id = v_new.id AND p.status <> 'predava_sa'
         AND (v_new.signed_on IS NULL OR v_new.signed_on >= p.updated_at::date));
  END IF;
  IF cardinality(v_kontr) > 0 THEN
    v_detail := array_to_string(ARRAY(SELECT e FROM unnest(v_kontr) WITH ORDINALITY u (e, i) GROUP BY e ORDER BY min(i)), '; ');
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (v_new.id, 'kontrola_importu', v_detail);
    END IF;
    v_warn := v_warn || ('Na kontrolu: ' || v_detail);
  END IF;
  v_warn := v_warn || ARRAY(
    SELECT format('Zmluva %s na OOM %s končí %s – nastupuje táto zmluva.', k.number, oo.eic, to_char(x.valid_to, 'FMDD. FMMM. YYYY'))
      FROM contract_oom x JOIN contract k ON k.id = x.contract_id JOIN oom oo ON oo.id = x.oom_id
     WHERE x.successor_id = v_new.id ORDER BY k.number, oo.eic);
  IF nullif(h ->> 'sum_mwh', '') IS NOT NULL
     AND abs((h ->> 'sum_mwh')::numeric - (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom
                                            WHERE contract_id = v_new.id)) >= 0.001 THEN
    v_warn := v_warn || format('Súčet množstva zmluvy %s MWh sa líši od súčtu OOM %s MWh (platí množstvo pri OOM).',
                               round((h ->> 'sum_mwh')::numeric, 3),
                               (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom WHERE contract_id = v_new.id));
  END IF;

  -- 12b. snímka ku dňu podpisu, výnimka, Pod hranicou bez výnimky, Chýba cena pre obchodníka (0027)
  v_warn := v_warn || contract_basis_refresh(v_new.id);

  -- 13. čas zmeny v Office portáli a posledný import
  UPDATE contract
     SET op_updated_at = nullif(h ->> 'updated_at', '')::timestamptz,
         last_import_id = CASE WHEN v_old.id IS NULL OR cardinality(v_chg) > 0 THEN coalesce(v_import, last_import_id)
                               ELSE last_import_id END
   WHERE id = v_new.id;
  RETURN jsonb_build_object(
    'action', CASE WHEN v_old.id IS NULL THEN 'nova' WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
    'contract_id', v_new.id, 'changes', to_jsonb(v_chg), 'warnings', to_jsonb(v_warn), 'errors', '[]'::jsonb,
    'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', v_cust_new, 'company_id', v_company, 'person_id', v_person);
END;
$$;
CREATE OR REPLACE FUNCTION contract_import_xm_link(p_contract_id uuid, p_xm jsonb) RETURNS text[]
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c     contract;
  v_chg text[] := '{}';
  v_from date;
  r     record;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.type <> 'dodavka_domacnost' OR jsonb_array_length(coalesce(p_xm, '[]')) = 0 THEN
    RETURN v_chg;
  END IF;
  v_from := contract_import_xm_from(p_xm, ARRAY(SELECT o.eic FROM contract_oom co JOIN oom o ON o.id = co.oom_id
                                                 WHERE co.contract_id = c.id));
  IF v_from IS NOT NULL AND v_from IS DISTINCT FROM c.valid_from THEN
    UPDATE contract SET valid_from = v_from WHERE id = c.id;
    v_chg := v_chg || format('Účinnosť od %s → %s (XM Trade)', coalesce(to_char(c.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                             to_char(v_from, 'FMDD. FMMM. YYYY'));
  END IF;
  FOR r IN
    SELECT co.id, co.product_id, o.eic, contract_import_xm_dd(x ->> 'product') AS dd
      FROM jsonb_array_elements(p_xm) x
      JOIN oom o ON o.eic = x ->> 'eic' AND o.type = 'spotreba'
      JOIN contract_oom co ON co.oom_id = o.id AND co.contract_id = c.id AND co.program_id IS NOT NULL
  LOOP
    CONTINUE WHEN r.dd IS NULL OR r.dd IS NOT DISTINCT FROM r.product_id;
    UPDATE contract_oom SET product_id = r.dd WHERE id = r.id;
    v_chg := v_chg || format('OOM %s: produkt %s (XM Trade)', r.eic, (SELECT name FROM product WHERE id = r.dd));
  END LOOP;
  IF cardinality(v_chg) > 0 THEN
    PERFORM contract_price_list_sync(c.id);
    PERFORM contract_price_missing_refresh(c.id);
    PERFORM contract_basis_refresh(c.id);
  END IF;
  RETURN v_chg;
END;
$$;
CREATE OR REPLACE FUNCTION contract_viwa_package_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM contract_price_list_sync(NEW.id);
  PERFORM contract_price_missing_refresh(NEW.id);
  PERFORM contract_basis_refresh(NEW.id);
  RETURN NULL;
END;
$$;

-- Prepis minimálneho aditívu výkupu (Nákup) prepočíta snímku
CREATE FUNCTION contract_basis_refresh_trigger() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM contract_basis_refresh(NEW.id);
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_basis AFTER UPDATE OF vykup_min_additive, owner_id ON contract
  FOR EACH ROW WHEN (NEW.vykup_min_additive IS DISTINCT FROM OLD.vykup_min_additive OR NEW.owner_id IS DISTINCT FROM OLD.owner_id)
  EXECUTE FUNCTION contract_basis_refresh_trigger();

-- ============================================================================
-- 5. Výnimky: hranicu doplní databáza; schválenie spáruje už importované zmluvy
-- ============================================================================

-- Hranica v deň žiadosti: FIX = cena pre obchodníka prvého roka dnes; SPOT + aditív = minimálny aditív podľa typu
-- predajcu autora; výkup = minimálny aditív výkupu. Iba pri žiadosti z aplikácie (import a skripty zadávajú samy).
CREATE FUNCTION price_exception_threshold() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_seller seller_type;
  v_year   smallint := (SELECT min(x) FROM unnest(NEW.years) x);
  v        numeric;
BEGIN
  IF crm_active_user_id() IS NULL THEN
    RETURN NEW;
  END IF;
  v_seller := coalesce((SELECT seller_type FROM app_user WHERE id = crm_active_user_id()), 'obchodnik');
  v := CASE NEW.price_model
         WHEN 'fix' THEN trader_price(NEW.org_id, v_year, crm_today())
         WHEN 'spot_plus_eur' THEN contract_param(NEW.org_id,
                                     CASE v_seller WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, crm_today())
         WHEN 'spot_minus_eur' THEN contract_param(NEW.org_id, 'min_aditiv_vykup', crm_today())
       END;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Hranica pre rok % dnes nie je známa (chýbajú ceny BL/PL alebo parameter v Cenových parametroch).', v_year
      USING ERRCODE = 'check_violation';
  END IF;
  NEW.threshold_value := v;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_threshold BEFORE INSERT ON price_exception FOR EACH ROW EXECUTE FUNCTION price_exception_threshold();

-- Schválená výnimka sa hneď spáruje so zmluvami zákazníka, ktoré už prišli importom (príznak Pod hranicou zmizne)
CREATE FUNCTION price_exception_apply() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k uuid;
BEGIN
  FOR k IN SELECT id FROM contract
            WHERE org_id = NEW.org_id AND company_id IS NOT DISTINCT FROM NEW.company_id
              AND person_id IS NOT DISTINCT FROM NEW.person_id AND signed_on IS NOT NULL LOOP
    PERFORM contract_basis_refresh(k);
  END LOOP;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_apply AFTER UPDATE OF status ON price_exception
  FOR EACH ROW WHEN (NEW.status = 'schvalena' AND OLD.status = 'caka') EXECUTE FUNCTION price_exception_apply();

-- ============================================================================
-- 6. Práva a naplnenie pre zmluvy, ktoré už sú v CRM
-- ============================================================================

REVOKE EXECUTE ON FUNCTION contract_param(uuid, text, date, smallint) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION contract_market_value(uuid, integer, date, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION contract_basis_values(contract, integer, date) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION contract_basis_refresh(uuid) FROM PUBLIC;

SELECT count(contract_basis_refresh(id)) FROM contract;

-- migrate:down

DROP TRIGGER IF EXISTS trg_apply ON price_exception;
DROP TRIGGER IF EXISTS trg_threshold ON price_exception;
DROP FUNCTION IF EXISTS price_exception_apply();
DROP FUNCTION IF EXISTS price_exception_threshold();
DROP TRIGGER IF EXISTS trg_basis ON contract;
DROP FUNCTION IF EXISTS contract_basis_refresh_trigger();

-- funkcie ako v 0026
CREATE OR REPLACE FUNCTION contract_viwa_package_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM contract_price_list_sync(NEW.id);
  PERFORM contract_price_missing_refresh(NEW.id);
  RETURN NULL;
END;
$$;
CREATE OR REPLACE FUNCTION contract_import_xm_link(p_contract_id uuid, p_xm jsonb) RETURNS text[]
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c     contract;
  v_chg text[] := '{}';
  v_from date;
  r     record;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.type <> 'dodavka_domacnost' OR jsonb_array_length(coalesce(p_xm, '[]')) = 0 THEN
    RETURN v_chg;
  END IF;
  v_from := contract_import_xm_from(p_xm, ARRAY(SELECT o.eic FROM contract_oom co JOIN oom o ON o.id = co.oom_id
                                                 WHERE co.contract_id = c.id));
  IF v_from IS NOT NULL AND v_from IS DISTINCT FROM c.valid_from THEN
    UPDATE contract SET valid_from = v_from WHERE id = c.id;
    v_chg := v_chg || format('Účinnosť od %s → %s (XM Trade)', coalesce(to_char(c.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                             to_char(v_from, 'FMDD. FMMM. YYYY'));
  END IF;
  FOR r IN
    SELECT co.id, co.product_id, o.eic, contract_import_xm_dd(x ->> 'product') AS dd
      FROM jsonb_array_elements(p_xm) x
      JOIN oom o ON o.eic = x ->> 'eic' AND o.type = 'spotreba'
      JOIN contract_oom co ON co.oom_id = o.id AND co.contract_id = c.id AND co.program_id IS NOT NULL
  LOOP
    CONTINUE WHEN r.dd IS NULL OR r.dd IS NOT DISTINCT FROM r.product_id;
    UPDATE contract_oom SET product_id = r.dd WHERE id = r.id;
    v_chg := v_chg || format('OOM %s: produkt %s (XM Trade)', r.eic, (SELECT name FROM product WHERE id = r.dd));
  END LOOP;
  IF cardinality(v_chg) > 0 THEN
    PERFORM contract_price_list_sync(c.id);
    PERFORM contract_price_missing_refresh(c.id);
  END IF;
  RETURN v_chg;
END;
$$;
CREATE OR REPLACE FUNCTION contract_import_one(p_org uuid, p_rows jsonb, p_xm jsonb, p_deferred jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c_head constant text[] := ARRAY['op_id', 'number', 'phase', 'commodity', 'household', 'ico', 'dic', 'ic_dph', 'company_name',
    'first_name', 'last_name', 'person_op_id', 'small_business', 'list_price', 'auto_prolong', 'valid_from', 'valid_to',
    'signed_on', 'created_by_name', 'owner_name', 'updated_at', 'viwa_package', 'close_reason', 'sum_mwh'];
  c_phase constant jsonb := '{"rozpracovana": "Rozpracovaná", "caka_na_podpis": "Čaká na podpis",
    "fyzicke_podpisovanie": "Fyzické podpisovanie", "elektronicke_podpisovanie": "Elektronické podpisovanie",
    "podpisana": "Podpísaná", "odmietnuta": "Odmietnutá", "ukoncena": "Ukončená", "neuspesna": "Neúspešná"}';
  c_type constant jsonb := '{"dodavka_domacnost": "dodávka – domácnosť", "dodavka_firma_nn": "dodávka – firma NN",
    "dodavka_firma_vn": "dodávka – firma VN", "vykup": "výkup", "viwa": "VIWA"}';
  h          jsonb := p_rows -> 0;
  v_import   uuid := nullif(current_setting('app.contract_import_id', true), '')::uuid;
  v_country  country_code := (SELECT country FROM org WHERE id = p_org);
  v_err      text[] := '{}';
  v_warn     text[] := '{}';
  v_chg      text[] := '{}';
  v_kontr    text[] := '{}';
  v_miss     jsonb := '[]';
  v_xm_out   jsonb := '[]';
  v_cols     text[];
  a          import_alias;
  v_phase    contract_phase;
  v_owner    uuid;
  v_old      contract;
  v_new      contract;
  v_company  uuid;
  v_person   uuid;
  v_cust_new boolean := false;
  v_digits   text;
  v_ico      text;
  v_cust_org uuid;
  v_type     contract_type;
  v_reason   contract_close_reason;
  v_package  text;
  v_from     date;
  v_eics     text[];
  v_eic      text;
  o          oom;
  v_oom      jsonb := '{}';
  v_volt     text[];
  v_pid      uuid;
  v_prog     uuid;
  v_tmp      jsonb;
  v_prices   jsonb;
  co         record;
  v_name     text;
  v_n        integer;
  v_detail   text;
  v_vo       uuid[] := '{}';
  v_d        text[];
BEGIN
  -- 1. hlavička zmluvy je rovnaká vo všetkých riadkoch; chyby čítania súboru
  SELECT array_agg(DISTINCT k ORDER BY k) INTO v_cols
    FROM unnest(c_head) k, jsonb_array_elements(p_rows) x
   WHERE x -> k IS DISTINCT FROM h -> k;
  IF v_cols IS NOT NULL THEN
    v_err := v_err || format('Riadky zmluvy sa líšia v stĺpcoch %s – opravte export.', array_to_string(v_cols, ', '));
  END IF;
  v_err := v_err || ARRAY(SELECT DISTINCT e FROM jsonb_array_elements(p_rows) x,
                                 jsonb_array_elements_text(coalesce(x -> 'parse_errors', '[]')) e);
  IF nullif(btrim(h ->> 'number'), '') IS NULL THEN
    v_err := v_err || 'Chýba číslo zmluvy.'::text;
  END IF;

  -- 2. existujúca zmluva: ID z Office portálu, potom číslo
  IF nullif(h ->> 'op_id', '') IS NOT NULL THEN
    SELECT * INTO v_old FROM contract WHERE op_id = (h ->> 'op_id')::uuid;
  END IF;
  IF v_old.id IS NULL THEN
    SELECT * INTO v_old FROM contract WHERE number = btrim(h ->> 'number');
    IF v_old.id IS NOT NULL AND v_old.op_id IS NOT NULL AND v_old.op_id::text IS DISTINCT FROM nullif(h ->> 'op_id', '') THEN
      v_err := v_err || format('Číslo zmluvy %s je v CRM pri inej zmluve z Office portálu.', h ->> 'number');
    END IF;
  END IF;
  IF v_old.id IS NOT NULL AND v_old.org_id <> p_org THEN
    v_err := v_err || 'Zmluva patrí inej spoločnosti skupiny.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 3. bez zmeny v Office portáli (Greatest_updated_at): nespracúva sa, iba údaje z XM Trade (účinnosť, produkt DD)
  IF v_old.id IS NOT NULL AND v_old.op_updated_at IS NOT NULL AND nullif(h ->> 'updated_at', '') IS NOT NULL
     AND (h ->> 'updated_at')::timestamptz <= v_old.op_updated_at THEN
    FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
      v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_old.company_id, v_old.person_id);
    END LOOP;
    v_chg := contract_import_xm_link(v_old.id, p_xm);
    RETURN jsonb_build_object('action', CASE WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
             'contract_id', v_old.id, 'changes', to_jsonb(v_chg), 'warnings', '[]'::jsonb, 'errors', '[]'::jsonb,
             'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', false,
             'company_id', v_old.company_id, 'person_id', v_old.person_id);
  END IF;

  -- 4. fáza a obchodník cez preklady (neznámy názov = chyba s „Pridať preklad“, rozhodnutie 5; otázka 22)
  a := import_alias_resolve(p_org, 'office_portal', 'faza', coalesce(h ->> 'phase', ''));
  IF a.id IS NULL THEN
    v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'faza', 'name', coalesce(h ->> 'phase', ''));
    v_err := v_err || format('Neznáma fáza „%s“ – pridajte preklad.', coalesce(h ->> 'phase', ''));
  ELSE
    v_phase := a.target::contract_phase;
  END IF;
  IF nullif(btrim(h ->> 'owner_name'), '') IS NOT NULL THEN
    a := import_alias_resolve(p_org, 'office_portal', 'obchodnik', h ->> 'owner_name');
    IF a.id IS NULL THEN
      v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'obchodnik', 'name', btrim(h ->> 'owner_name'));
      v_err := v_err || format('Neznámy obchodník „%s“ – pridajte preklad na používateľa CRM.', btrim(h ->> 'owner_name'));
    ELSE
      v_owner := a.target::uuid;
    END IF;
  ELSIF v_old.owner_id IS NULL THEN
    -- tvorca zmluvy sa za obchodníka nedosadzuje (Peter, otázka 22), je iba informácia
    v_warn := v_warn || ('Zmluva nemá obchodníka (Uzatvoril) – uloží sa bez neho'
                         || coalesce(format(' (vytvoril: %s)', nullif(btrim(h ->> 'created_by_name'), '')), '') || '.');
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 5. zákazník (časť 8.2): firma podľa IČO, domácnosť podľa Osoba_ID; chýbajúci sa založí s príznakom
  --    „založený importom“, vlastník = obchodník zo zmluvy (doplnok b)
  v_eics := ARRAY(SELECT DISTINCT upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) FROM jsonb_array_elements(p_rows) x
                   WHERE nullif(btrim(x ->> 'eic'), '') IS NOT NULL ORDER BY 1);
  IF coalesce((h ->> 'household')::boolean, false) THEN
    v_name := btrim(concat_ws(' ', btrim(h ->> 'first_name'), btrim(h ->> 'last_name')));
    IF nullif(h ->> 'person_op_id', '') IS NOT NULL THEN
      SELECT id INTO v_person FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid;
    END IF;
    v_person := coalesce(v_person, v_old.person_id);
    IF v_person IS NULL THEN
      -- prvé párovanie (napr. po presune z HubSpotu): aktuálny zákazník-osoba OOM zmluvy s rovnakým menom
      SELECT min(p.id::text)::uuid, count(DISTINCT p.id) INTO v_person, v_n
        FROM oom x JOIN contact p ON p.id = x.person_id
       WHERE x.org_id = p_org AND x.eic = ANY (v_eics) AND p.op_person_id IS NULL
         AND import_name_norm(p.first_name || ' ' || p.last_name) = import_name_norm(v_name);
      IF v_n > 1 THEN
        v_person := NULL;
      END IF;
    END IF;
    IF v_person IS NOT NULL THEN
      IF NOT crm_contact_access(v_person, 'view') THEN
        v_err := v_err || 'Osoba zákazníka je v CRM, ale nemáte k nej prístup.'::text;
      END IF;
      UPDATE contact SET op_person_id = (h ->> 'person_op_id')::uuid
       WHERE id = v_person AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
    ELSIF nullif(btrim(h ->> 'first_name'), '') IS NULL OR nullif(btrim(h ->> 'last_name'), '') IS NULL THEN
      v_err := v_err || 'Nová osoba: chýba meno alebo priezvisko.'::text;
    ELSE
      IF EXISTS (SELECT 1 FROM contact WHERE org_id = p_org
                    AND import_name_norm(first_name || ' ' || last_name) = import_name_norm(v_name)) THEN
        v_warn := v_warn || 'Možná duplicita: osoba s rovnakým menom už v CRM je – založí sa nová, skontrolujte.'::text;
        v_kontr := v_kontr || 'možná duplicita osoby'::text;
      END IF;
      INSERT INTO contact (org_id, first_name, last_name, is_household, owner_id, op_person_id, created_by_import, address)
      VALUES (p_org, btrim(h ->> 'first_name'), btrim(h ->> 'last_name'), true, v_owner,
              nullif(h ->> 'person_op_id', '')::uuid, v_import,
              (SELECT btrim(x ->> 'address') FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                WHERE nullif(btrim(x ->> 'address'), '') IS NOT NULL LIMIT 1))
      RETURNING id INTO v_person;
      v_cust_new := true;
    END IF;
  ELSE
    v_digits := regexp_replace(coalesce(h ->> 'ico', ''), '\D', '', 'g');
    v_ico := CASE WHEN v_country = 'HR' THEN v_digits ELSE lpad(v_digits, 8, '0') END;
    IF v_digits = '' THEN
      v_err := v_err || 'Chýba IČO firmy.'::text;
    ELSE
      SELECT id, org_id INTO v_company, v_cust_org FROM company WHERE country = v_country AND ico = v_ico;
      IF v_company IS NOT NULL AND v_cust_org <> p_org THEN
        v_err := v_err || format('Firma s IČO %s patrí inej spoločnosti skupiny.', v_ico);
      ELSIF v_company IS NOT NULL THEN
        IF NOT crm_company_access(v_company, 'view') THEN
          v_err := v_err || format('Firma s IČO %s je v CRM, ale nemáte k nej prístup.', v_ico);
        END IF;
        UPDATE company SET op_person_id = (h ->> 'person_op_id')::uuid
         WHERE id = v_company AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM company WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
      ELSIF nullif(btrim(h ->> 'company_name'), '') IS NULL THEN
        v_err := v_err || 'Nová firma: chýba názov.'::text;
      ELSE
        INSERT INTO company (org_id, name, ico, dic, ic_dph, is_customer, owner_id, op_person_id, created_by_import)
        VALUES (p_org, btrim(h ->> 'company_name'), v_ico, nullif(btrim(h ->> 'dic'), ''), nullif(btrim(h ->> 'ic_dph'), ''),
                true, v_owner, nullif(h ->> 'person_op_id', '')::uuid, v_import)
        RETURNING id INTO v_company;
        v_cust_new := true;
      END IF;
    END IF;
  END IF;
  IF v_cust_new AND v_owner IS NULL THEN
    v_warn := v_warn || 'Nový zákazník je bez vlastníka – zmluva nemá obchodníka.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 6. nové OOM z XM Trade pre zákazníka tejto zmluvy (oba súbory v jednom behu); chyba OOM = chyba zmluvy
  --    s pôvodným dôvodom (aj chýbajúci preklad z XM Trade)
  FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
    v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_company, v_person);
    IF v_xm_out -> -1 ->> 'action' = 'chyba' THEN
      v_err := v_err || format('OOM %s (XM Trade, riadok %s): %s', v_xm_out -> -1 ->> 'eic', v_tmp ->> 'row', v_xm_out -> -1 ->> 'error');
      v_miss := v_miss || coalesce(v_xm_out -> -1 -> 'missing', '[]');
    END IF;
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 7. OOM zmluvy: musia byť v CRM; produkt a program pri OOM, množstvo VT/NT (MWh), výkon zdroja
  IF cardinality(v_eics) = 0 THEN
    v_err := v_err || 'Zmluva nemá žiadne OOM (EIC).'::text;
  END IF;
  FOREACH v_eic IN ARRAY v_eics LOOP
    SELECT * INTO o FROM oom WHERE eic = v_eic;
    IF o.id IS NULL THEN
      v_err := v_err || format('OOM %s nie je v CRM – najprv nahrajte export z XM Trade.', v_eic);
      CONTINUE;
    ELSIF o.org_id <> p_org THEN
      v_err := v_err || format('OOM %s patrí inej spoločnosti skupiny.', v_eic);
      CONTINUE;
    END IF;
    IF contract_import_eic_warning(v_eic) IS NOT NULL THEN
      v_warn := v_warn || contract_import_eic_warning(v_eic);
    END IF;
    IF (o.company_id, o.person_id) IS DISTINCT FROM (v_company, v_person) THEN
      v_warn := v_warn || format('OOM %s má v CRM iného aktuálneho zákazníka ako zmluva (prepis?).', v_eic);
    END IF;
    v_tmp := (SELECT jsonb_agg(x ORDER BY (x ->> 'row')::int) FROM jsonb_array_elements(p_rows) x
               WHERE upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) = v_eic);
    IF (SELECT count(DISTINCT jsonb_build_array(x -> 'qty_vt_mwh', x -> 'qty_nt_mwh', x -> 'source_power_kw', x -> 'product_oom'))
          FROM jsonb_array_elements(v_tmp) x) > 1 THEN
      v_warn := v_warn || format('OOM %s: riadky sa líšia v množstve, výkone alebo produkte – použije sa prvý.', v_eic);
    END IF;
    v_pid := NULL;
    v_prog := NULL;
    v_name := btrim(coalesce(v_tmp -> 0 ->> 'product_oom', ''));
    IF v_name <> '' THEN
      a := import_alias_resolve(p_org, 'office_portal', 'produkt_oom', v_name);
      IF a.id IS NULL THEN
        IF NOT v_miss @> jsonb_build_array(jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name)) THEN
          v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name);
          v_err := v_err || format('Neznámy produkt pri OOM „%s“ – pridajte preklad.', v_name);
        END IF;
      ELSIF coalesce((a.target_extra ->> 'program')::boolean, false) THEN
        -- VBattery: program z Office portálu, produkt DDx z XM Trade (rozhodnutie 4, otázka 12a) iba pri OOM spotreby;
        -- výrobné (otázka 24) a virtuálne OOM majú iba program
        v_prog := (SELECT id FROM product WHERE code = a.target);
        IF o.type = 'spotreba' THEN
          v_pid := coalesce(contract_import_xm_dd((SELECT x ->> 'product' FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                                                    WHERE x ->> 'eic' = v_eic LIMIT 1)),
                            (SELECT x.product_id FROM contract_oom x WHERE x.contract_id = v_old.id AND x.oom_id = o.id));
          IF v_pid IS NULL THEN
            v_warn := v_warn || format('OOM %s: produkt DD pri VBattery doplní export z XM Trade.', v_eic);
          END IF;
        END IF;
      ELSIF a.target_extra ? 'ano' THEN
        -- DDx: ANO alebo NIE Energopomoc podľa cenovej regulácie OOM
        v_pid := (SELECT id FROM product WHERE code = CASE o.price_regulation WHEN true THEN a.target_extra ->> 'ano'
                                                                              WHEN false THEN a.target END);
        IF o.price_regulation IS NULL THEN
          v_warn := v_warn || format('OOM %s nemá cenovú reguláciu – produkt %s ANO/NIE nejde určiť.', v_eic, v_name);
        END IF;
      ELSE
        v_pid := (SELECT id FROM product WHERE code = a.target);
      END IF;
      IF coalesce((a.target_extra ->> 'verejne_osvetlenie')::boolean, false)
         OR (SELECT tariff_variant FROM product WHERE id = v_pid) = 'verejne_osvetlenie' THEN
        v_vo := v_vo || o.id;
      END IF;
    END IF;
    IF nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0) IS NOT NULL AND o.source_power_kw IS NOT NULL
       AND round((v_tmp -> 0 ->> 'source_power_kw')::numeric, 3) <> o.source_power_kw THEN
      v_warn := v_warn || format('OOM %s: výkon zdroja v zmluve %s kW, na OOM %s kW (OOM sa nemení).', v_eic,
                                 (v_tmp -> 0 ->> 'source_power_kw')::numeric, o.source_power_kw);
    END IF;
    v_oom := v_oom || jsonb_build_object(v_eic, jsonb_build_object(
               'oom_id', o.id, 'eic', v_eic, 'product_id', v_pid, 'program_id', v_prog, 'voltage', o.voltage_level,
               'qty_vt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_vt_mwh')::numeric, 0), 3),
               'qty_nt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_nt_mwh')::numeric, 0), 3),
               'source_power_kw', round(nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0), 3)));
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 8. typ zmluvy (časť 1): výkup, VIWA, domácnosť, firma NN/VN podľa napäťovej úrovne OOM
  v_volt := ARRAY(SELECT DISTINCT coalesce(y.value ->> 'voltage', '') FROM jsonb_each(v_oom) y);
  v_type := CASE
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina_vyroba' THEN 'vykup'
    WHEN import_name_norm(h ->> 'commodity') = 'nezname' OR h ->> 'number' ~* 'VIW' THEN 'viwa'
    WHEN coalesce((h ->> 'household')::boolean, false) THEN 'dodavka_domacnost'
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina' THEN
      CASE WHEN v_volt && ARRAY['vn', 'vvn'] THEN 'dodavka_firma_vn' ELSE 'dodavka_firma_nn' END
  END::contract_type;
  IF v_type IS NULL THEN
    v_err := v_err || format('Neznáma komodita „%s“.', coalesce(h ->> 'commodity', ''));
  ELSIF v_type::text LIKE 'dodavka_firma%' THEN
    IF v_volt && ARRAY['vn', 'vvn'] AND 'nn' = ANY (v_volt) THEN
      v_err := v_err || 'Zmluva má OOM na NN aj VN – NN a VN sú samostatné zmluvy.'::text;
    ELSIF '' = ANY (v_volt) THEN
      v_warn := v_warn || 'Napäťová úroveň OOM chýba – zmluva je typu firma NN.'::text;
    END IF;
  END IF;
  -- údaje CRM z exportu iba neprázdne (doplnok a); balík VIWA a dôvod uzatvorenia, keď ich zostava doplní
  v_package := lower(nullif(btrim(h ->> 'viwa_package'), ''));
  IF v_package IS NOT NULL AND v_package NOT IN ('basic', 'plus', 'pro') THEN
    v_err := v_err || format('Neznámy balík VIWA „%s“.', h ->> 'viwa_package');
  END IF;
  IF nullif(btrim(h ->> 'close_reason'), '') IS NOT NULL THEN
    v_reason := (SELECT e FROM unnest(enum_range(NULL::contract_close_reason)) e
                  WHERE e::text = replace(import_name_norm(h ->> 'close_reason'), ' ', '_'));
    IF v_reason IS NULL THEN
      v_err := v_err || format('Neznámy dôvod uzatvorenia „%s“.', h ->> 'close_reason');
    END IF;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 9. zmluva; prázdna bunka nikdy neprepíše hodnotu v CRM (doplnok a); účinnosť domácnosti z XM Trade (rozhodnutie 3)
  v_from := CASE WHEN v_type = 'dodavka_domacnost'
                 THEN coalesce(contract_import_xm_from(p_xm, v_eics), (h ->> 'valid_from')::date, v_old.valid_from)
                 ELSE coalesce((h ->> 'valid_from')::date, v_old.valid_from) END;
  IF v_from IS NULL AND v_phase = 'podpisana' THEN
    v_warn := v_warn || CASE WHEN v_type = 'dodavka_domacnost' THEN 'Účinnosť od chýba – doplní ju export z XM Trade.'
                             ELSE 'Účinnosť od chýba.' END;
  END IF;
  IF v_old.id IS NULL THEN
    INSERT INTO contract (org_id, number, op_id, company_id, person_id, type, phase, valid_from, valid_to, signed_on,
                          auto_prolong, small_business, list_price, viwa_package, close_reason, owner_id, created_by_name,
                          last_import_id)
    VALUES (p_org, btrim(h ->> 'number'), nullif(h ->> 'op_id', '')::uuid, v_company, v_person, v_type, v_phase, v_from,
            (h ->> 'valid_to')::date, (h ->> 'signed_on')::date, coalesce((h ->> 'auto_prolong')::boolean, false),
            coalesce((h ->> 'small_business')::boolean, false), coalesce((h ->> 'list_price')::boolean, false),
            v_package, v_reason, v_owner, nullif(btrim(h ->> 'created_by_name'), ''), v_import)
    RETURNING * INTO v_new;
    v_chg := v_chg || format('Nová zmluva: %s, %s, OOM %s', c_type ->> v_type::text, c_phase ->> v_phase::text,
                             cardinality(v_eics));
  ELSE
    UPDATE contract
       SET number = btrim(h ->> 'number'), op_id = coalesce(nullif(h ->> 'op_id', '')::uuid, op_id),
           company_id = v_company, person_id = v_person, type = v_type, phase = v_phase, valid_from = v_from,
           valid_to = coalesce((h ->> 'valid_to')::date, valid_to), signed_on = coalesce((h ->> 'signed_on')::date, signed_on),
           auto_prolong = coalesce((h ->> 'auto_prolong')::boolean, auto_prolong),
           small_business = coalesce((h ->> 'small_business')::boolean, small_business),
           list_price = coalesce((h ->> 'list_price')::boolean, list_price),
           viwa_package = coalesce(v_package, viwa_package), close_reason = coalesce(v_reason, close_reason),
           owner_id = coalesce(v_owner, owner_id),
           created_by_name = coalesce(nullif(btrim(h ->> 'created_by_name'), ''), created_by_name)
     WHERE id = v_old.id
    RETURNING * INTO v_new;
    IF v_new.number <> v_old.number THEN
      v_chg := v_chg || format('Číslo %s → %s', v_old.number, v_new.number);
    END IF;
    IF v_new.phase <> v_old.phase THEN
      v_chg := v_chg || format('Fáza %s → %s', c_phase ->> v_old.phase::text, c_phase ->> v_new.phase::text);
    END IF;
    IF v_new.type <> v_old.type THEN
      v_chg := v_chg || format('Typ %s → %s', c_type ->> v_old.type::text, c_type ->> v_new.type::text);
    END IF;
    IF (v_new.company_id, v_new.person_id) IS DISTINCT FROM (v_old.company_id, v_old.person_id) THEN
      v_chg := v_chg || 'Zákazník zmluvy zmenený'::text;
    END IF;
    IF v_new.valid_from IS DISTINCT FROM v_old.valid_from THEN
      v_chg := v_chg || format('Účinnosť od %s → %s', coalesce(to_char(v_old.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.valid_from, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.valid_to IS DISTINCT FROM v_old.valid_to THEN
      v_chg := v_chg || format('Účinnosť do %s → %s', coalesce(to_char(v_old.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'),
                               coalesce(to_char(v_new.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'));
    END IF;
    IF v_new.signed_on IS DISTINCT FROM v_old.signed_on THEN
      v_chg := v_chg || format('Platnosť od %s → %s', coalesce(to_char(v_old.signed_on, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.signed_on, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.owner_id IS DISTINCT FROM v_old.owner_id THEN
      v_chg := v_chg || format('Obchodník %s → %s', coalesce((SELECT name FROM app_user WHERE id = v_old.owner_id), '–'),
                               coalesce((SELECT name FROM app_user WHERE id = v_new.owner_id), '–'));
    END IF;
    IF (v_new.auto_prolong, v_new.small_business, v_new.list_price, v_new.viwa_package, v_new.close_reason)
       IS DISTINCT FROM (v_old.auto_prolong, v_old.small_business, v_old.list_price, v_old.viwa_package, v_old.close_reason) THEN
      v_chg := v_chg || 'Príznaky zmluvy (prolongácia, malý podnik, cenníková cena, balík, dôvod)'::text;
    END IF;
  END IF;

  -- 10. OOM v zmluve: odobraté, zmenené, nové (nástupníctvo a prekrytie strážia spúšťače z 0025)
  FOR co IN SELECT x.*, oo.eic FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id WHERE x.contract_id = v_new.id LOOP
    v_tmp := v_oom -> co.eic;
    IF v_tmp IS NULL THEN
      DELETE FROM contract_price WHERE contract_id = v_new.id AND oom_id = co.oom_id;
      DELETE FROM contract_oom WHERE id = co.id;
      v_chg := v_chg || format('OOM %s odobraté', co.eic);
      IF v_new.phase = 'podpisana' THEN
        v_warn := v_warn || format('OOM %s v exporte podpísanej zmluvy chýba – odobraté (zmena má byť novou zmluvou).', co.eic);
      END IF;
    ELSE
      v_d := '{}';
      IF co.qty_vt_mwh <> (v_tmp ->> 'qty_vt_mwh')::numeric OR co.qty_nt_mwh <> (v_tmp ->> 'qty_nt_mwh')::numeric THEN
        v_d := v_d || format('množstvo VT/NT %s/%s → %s/%s MWh', co.qty_vt_mwh, co.qty_nt_mwh,
                             (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric);
      END IF;
      IF co.product_id IS DISTINCT FROM (v_tmp ->> 'product_id')::uuid OR co.program_id IS DISTINCT FROM (v_tmp ->> 'program_id')::uuid THEN
        v_d := v_d || format('produkt %s → %s',
                 coalesce((SELECT string_agg(name, ' + ') FROM product WHERE id IN (co.product_id, co.program_id)), '–'),
                 coalesce((SELECT string_agg(name, ' + ') FROM product
                            WHERE id IN ((v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid)), '–'));
      END IF;
      IF co.source_power_kw IS DISTINCT FROM (v_tmp ->> 'source_power_kw')::numeric THEN
        v_d := v_d || format('výkon %s → %s kW', coalesce(co.source_power_kw::text, '–'), coalesce(v_tmp ->> 'source_power_kw', '–'));
      END IF;
      IF cardinality(v_d) > 0 THEN
        UPDATE contract_oom
           SET product_id = (v_tmp ->> 'product_id')::uuid, program_id = (v_tmp ->> 'program_id')::uuid,
               qty_vt_mwh = (v_tmp ->> 'qty_vt_mwh')::numeric, qty_nt_mwh = (v_tmp ->> 'qty_nt_mwh')::numeric,
               source_power_kw = (v_tmp ->> 'source_power_kw')::numeric
         WHERE id = co.id;
        v_chg := v_chg || format('OOM %s: %s', co.eic, array_to_string(v_d, ', '));
      END IF;
    END IF;
  END LOOP;
  FOR v_tmp IN SELECT y.value FROM jsonb_each(v_oom) y ORDER BY y.key LOOP
    IF NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = v_new.id AND oom_id = (v_tmp ->> 'oom_id')::uuid) THEN
      INSERT INTO contract_oom (contract_id, oom_id, product_id, program_id, qty_vt_mwh, qty_nt_mwh, source_power_kw)
      VALUES (v_new.id, (v_tmp ->> 'oom_id')::uuid, (v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid,
              (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric, (v_tmp ->> 'source_power_kw')::numeric);
      IF v_old.id IS NOT NULL THEN
        v_chg := v_chg || format('OOM %s pridané', v_tmp ->> 'eic');
      END IF;
    END IF;
  END LOOP;
  -- verejné osvetlenie (odpoveď 4): import príznak iba nastaví, nikdy nezruší
  IF cardinality(v_vo) > 0 THEN
    PERFORM set_config('crm.oom_system', 'on', true);
    UPDATE oom SET public_lighting = true WHERE id = ANY (v_vo) AND NOT public_lighting;
    IF FOUND THEN
      v_chg := v_chg || 'Verejné osvetlenie nastavené na OOM'::text;
    END IF;
    PERFORM set_config('crm.oom_system', '', true);
  END IF;

  -- 11. ceny: individuálne z Office portálu, potom z cenníkov
  SELECT jsonb_object_agg(oo.eic, jsonb_build_object(
           'oom_id', x.oom_id, 'product_id', x.product_id, 'valid_from', x.valid_from, 'valid_to', x.valid_to,
           'tariff', CASE WHEN p.tariff_type = 'jednotarif' THEN '1t'
                          WHEN p.tariff_type = 'dvojtarif' AND p.tariff_variant = 'vykurovanie' THEN '2t_vyk'
                          WHEN p.tariff_type = 'dvojtarif' THEN '2t' END))
    INTO v_tmp
    FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
   WHERE x.contract_id = v_new.id;
  v_prices := contract_import_op_prices(p_org, v_new, p_rows, coalesce(v_tmp, '{}'));
  v_err := v_err || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'errors'));
  v_miss := v_miss || (v_prices -> 'missing');
  PERFORM contract_import_fail(v_err, v_miss);
  v_warn := v_warn || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'warnings'));
  v_kontr := v_kontr || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'kontrola'));
  IF v_new.list_price AND jsonb_array_length(v_prices -> 'rows') > 0 THEN
    v_warn := v_warn || 'Zmluva má cenníkovú cenu aj individuálne ceny v exporte – platí cenník.'::text;
    v_prices := jsonb_set(v_prices, '{rows}', '[]');
  END IF;
  IF contract_price_set(v_new.id, 'op', v_prices -> 'rows') AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Individuálne ceny zmenené'::text;
  END IF;
  IF contract_price_list_sync(v_new.id) AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Ceny z cenníka zmenené'::text;
  END IF;

  -- 12. príznaky a upozornenia
  v_detail := contract_price_missing_refresh(v_new.id);
  IF v_detail IS NOT NULL THEN
    v_warn := v_warn || ('Chýba cena: ' || v_detail);
  END IF;
  IF v_old.id IS NULL THEN
    -- produkt Dobieha alebo Ukončený pri novej zmluve podpísanej po zmene stavu produktu
    v_kontr := v_kontr || ARRAY(
      SELECT DISTINCT format('produkt %s je %s', p.name, CASE p.status WHEN 'dobieha' THEN 'Dobieha' ELSE 'Ukončený' END)
        FROM contract_oom x JOIN product p ON p.id IN (x.product_id, x.program_id)
       WHERE x.contract_id = v_new.id AND p.status <> 'predava_sa'
         AND (v_new.signed_on IS NULL OR v_new.signed_on >= p.updated_at::date));
  END IF;
  IF cardinality(v_kontr) > 0 THEN
    v_detail := array_to_string(ARRAY(SELECT e FROM unnest(v_kontr) WITH ORDINALITY u (e, i) GROUP BY e ORDER BY min(i)), '; ');
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (v_new.id, 'kontrola_importu', v_detail);
    END IF;
    v_warn := v_warn || ('Na kontrolu: ' || v_detail);
  END IF;
  v_warn := v_warn || ARRAY(
    SELECT format('Zmluva %s na OOM %s končí %s – nastupuje táto zmluva.', k.number, oo.eic, to_char(x.valid_to, 'FMDD. FMMM. YYYY'))
      FROM contract_oom x JOIN contract k ON k.id = x.contract_id JOIN oom oo ON oo.id = x.oom_id
     WHERE x.successor_id = v_new.id ORDER BY k.number, oo.eic);
  IF nullif(h ->> 'sum_mwh', '') IS NOT NULL
     AND abs((h ->> 'sum_mwh')::numeric - (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom
                                            WHERE contract_id = v_new.id)) >= 0.001 THEN
    v_warn := v_warn || format('Súčet množstva zmluvy %s MWh sa líši od súčtu OOM %s MWh (platí množstvo pri OOM).',
                               round((h ->> 'sum_mwh')::numeric, 3),
                               (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom WHERE contract_id = v_new.id));
  END IF;

  -- 13. čas zmeny v Office portáli a posledný import
  UPDATE contract
     SET op_updated_at = nullif(h ->> 'updated_at', '')::timestamptz,
         last_import_id = CASE WHEN v_old.id IS NULL OR cardinality(v_chg) > 0 THEN coalesce(v_import, last_import_id)
                               ELSE last_import_id END
   WHERE id = v_new.id;
  RETURN jsonb_build_object(
    'action', CASE WHEN v_old.id IS NULL THEN 'nova' WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
    'contract_id', v_new.id, 'changes', to_jsonb(v_chg), 'warnings', to_jsonb(v_warn), 'errors', '[]'::jsonb,
    'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', v_cust_new, 'company_id', v_company, 'person_id', v_person);
END;
$$;
CREATE OR REPLACE FUNCTION contract_price_missing_refresh(p_contract_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') THEN
    FOR co IN
      SELECT x.*, o.eic
        FROM contract_oom x JOIN oom o ON o.id = x.oom_id
       WHERE x.contract_id = c.id
         AND ((c.type::text LIKE 'dodavka%' AND o.type = 'spotreba') OR c.type = 'vykup')
       ORDER BY o.eic
    LOOP
      IF co.valid_from IS NULL THEN
        v_miss := v_miss || format('OOM %s: chýba účinnosť od', co.eic);
        CONTINUE;
      END IF;
      v_from := greatest(co.valid_from, v_y_from);
      v_to := coalesce(co.valid_to, greatest(v_from, v_y_to));
      CONTINUE WHEN v_to < v_from;
      IF NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
                     - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                                  WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita'),
                                '{}'::datemultirange)) THEN
        v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                   to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
      END IF;
    END LOOP;
    IF c.type = 'viwa' THEN
      IF c.viwa_package IS NULL THEN
        v_miss := v_miss || 'chýba balík VIWA (doplní Servis)'::text;
      ELSIF c.valid_from IS NOT NULL THEN
        v_from := greatest(c.valid_from, v_y_from);
        v_to := coalesce(contract_effective_to(c), greatest(v_from, v_y_to));
        IF v_to >= v_from AND NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
             - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                          WHERE p.contract_id = c.id AND p.slot = 'viwa_ucet'), '{}'::datemultirange)) THEN
          v_miss := v_miss || 'chýba cena balíka VIWA v cenníku'::text;
        END IF;
      END IF;
    END IF;
  END IF;

  v_detail := nullif(array_to_string(v_miss, '; '), '');
  IF v_detail IS NULL THEN
    UPDATE contract_flag SET resolved_at = now()
     WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;
CREATE OR REPLACE FUNCTION contract_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  v_crm    text[] := ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'viwa_package',
                           'updated_at'];
  r contract;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system THEN
      RAISE EXCEPTION 'Zmluva sa nemaže – opravuje sa v Office portáli a ďalším importom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_system THEN
    -- obchodníka zmluvy (Uzatvoril) zmení iba vedenie alebo admin, rovnako ako vlastníka zákazníka
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND crm_can_change_owner() THEN
      v_crm := v_crm || 'owner_id'::text;
    END IF;
    IF (to_jsonb(NEW) - v_crm) <> (to_jsonb(OLD) - v_crm) THEN
      RAISE EXCEPTION 'Údaje z Office portálu sa v CRM nemenia – opravte ich v Office portáli a nahrajte export.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  -- súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka
  IF NEW.related_contract_id IS NOT NULL THEN
    SELECT * INTO r FROM contract WHERE id = NEW.related_contract_id;
    IF (r.company_id, r.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)
       OR NOT ((NEW.type = 'viwa' AND r.type::text LIKE 'dodavka%') OR (r.type = 'viwa' AND NEW.type::text LIKE 'dodavka%')) THEN
      RAISE EXCEPTION 'Súvisiaca zmluva: VIWA a zmluva o dodávke toho istého zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION price_parameter_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_owner boolean := crm_owner_session();
BEGIN
  IF v_owner THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    IF OLD.valid_from <= crm_today() THEN
      RAISE EXCEPTION 'Platný parameter sa nemení ani nemaže – zadaj novú hodnotu s dátumom „platí od“.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.changed_by IS DISTINCT FROM crm_active_user_id() THEN
      RAISE EXCEPTION 'Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor.' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id OR NEW.delivery_year IS DISTINCT FROM OLD.delivery_year THEN
      RAISE EXCEPTION 'Parameter, spoločnosť a rok sa nemenia.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.valid_from < crm_today() THEN
    RAISE EXCEPTION 'Platí od musí byť dnes alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR (crm_approves_prices()
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;

DROP FUNCTION IF EXISTS contract_basis_refresh(uuid);
DROP FUNCTION IF EXISTS contract_year_calc(uuid, integer);
DROP FUNCTION IF EXISTS contract_basis_values(contract, integer, date);
DROP FUNCTION IF EXISTS contract_market_value(uuid, integer, date, text);
DROP FUNCTION IF EXISTS contract_param(uuid, text, date, smallint);
DROP TABLE IF EXISTS contract_year_basis;
DELETE FROM contract_flag WHERE code IN ('pod_hranicou_bez_vynimky', 'chyba_cena') AND year IS NOT NULL;
UPDATE price_exception SET status = 'schvalena', contract_id = NULL WHERE status = 'pouzita';
ALTER TABLE contract DROP COLUMN IF EXISTS vykup_min_additive;
DELETE FROM price_parameter WHERE code = 'min_aditiv_vykup';
ALTER TABLE price_parameter DROP CONSTRAINT price_parameter_code_check;
ALTER TABLE price_parameter ADD CONSTRAINT price_parameter_code_check CHECK (code IN (
  'pomer_bl_pct', 'rizikova_prirazka', 'nasa_marza', 'min_aditiv_obchodnik', 'min_aditiv_manazer', 'min_aditiv_vykup_lz',
  'nakup_energopomoc', 'viwa_aditiv_basic', 'viwa_aditiv_plus', 'viwa_aditiv_pro'));
