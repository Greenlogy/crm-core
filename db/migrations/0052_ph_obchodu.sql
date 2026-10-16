-- migrate:up

-- 0052_ph_obchodu – modul 5, fáza F6, krok 2 (Peter 16. 10., meranie: 2 000 obchodov → zoznam a Domov pre toho, kto vidí
-- všetky obchody, nad 1 s): pridaná hodnota obchodu sa ukladá (deal_value_cache) a prepočíta sa pri zmene, ktorá ju mení –
-- odoslanie / nahradenie / zmazanie ponuky, hlavný variant, akceptácia a jej zrušenie, odhad na obchode, objemy OOM na
-- obchode, rozhodnutie o výnimke z ceny. Poistka: nočný beh obchodov prepočíta všetko a rozdiely zapíše do denníka.
-- Výpočet PH variantu je rozdelený na jadro bez kontroly prístupu (offer_variant_values_core, interné – uložená PH je rovnaká
-- pre každého a počíta sa aj v nočnom behu) a obal pre aplikáciu s kontrolou ako doteraz (offer_variant_values).

CREATE FUNCTION offer_variant_values_core(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
),
sc AS (SELECT offer_variant_scope(p_variant) AS scope WHERE EXISTS (SELECT 1 FROM v)),
mo AS (SELECT m.m_start, m.year FROM offer_variant ov, offer_variant_months(ov) m
        WHERE ov.id = p_variant AND EXISTS (SELECT 1 FROM v)),
dm AS (
  SELECT x.oom_id, oom_voltage_group(o.voltage_level) AS vg, o.price_regulation AS reg,
         coalesce(x.planned_vt_mwh, 0) AS vt_y, coalesce(x.planned_nt_mwh, 0) AS nt_y,
         coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0) AS feed_y,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS kw
    FROM v JOIN deal_oom x ON x.deal_id = v.deal_id JOIN oom o ON o.id = x.oom_id
),
oy AS (   -- OOM × rok: mesiace a objemy
  SELECT dm.oom_id, dm.vg, dm.reg, dm.kw, mo.year, count(*)::int AS months,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN dm.feed_y ELSE dm.vt_y END * count(*) / 12 AS v_vt,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN 0 ELSE dm.nt_y END * count(*) / 12 AS v_nt
    FROM dm CROSS JOIN mo
   GROUP BY dm.oom_id, dm.vg, dm.reg, dm.kw, dm.feed_y, dm.vt_y, dm.nt_y, mo.year
),
it AS (
  SELECT oy.*, i.id AS item_id, i.price_model, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
         i.additive_eur_mwh AS ad, i.additive_pct AS pct,
         CASE WHEN (SELECT okind FROM v) = 'viwa' THEN 'viwa'
              WHEN (SELECT okind FROM v) = 'vykup' THEN CASE WHEN i.price_model IS NOT NULL THEN 'vykup' END
              WHEN i.price_model = 'cennik' AND (SELECT household FROM v) AND oy.reg THEN 'energo'
              WHEN i.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN i.price_model::text END AS kind
    FROM oy
    LEFT JOIN LATERAL (SELECT * FROM offer_item i
                        WHERE i.variant_id = p_variant AND i.oom_id = oy.oom_id AND i.slot = 'komodita'
                          AND (i.year = oy.year OR i.year IS NULL)
                        ORDER BY i.year NULLS LAST LIMIT 1) i ON true
),
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037), pri nezmenenom rozsahu variantu (0038)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
     -- neodoslaná verzia: rozsah variantu (OOM, roky, objemy) ako pri žiadosti; odoslaná si výnimku ponechá
     AND ((SELECT osent FROM v) IS NOT NULL OR a.scope = (SELECT scope FROM sc))
     -- výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá
     AND CASE WHEN (SELECT osent FROM v) IS NULL THEN r.valid_until IS NULL OR r.valid_until > now()
              ELSE r.valid_until IS NULL OR (SELECT osent FROM v) <= r.valid_until END
   GROUP BY 1, 2, 3
),
calc AS (
  SELECT it.*, b.seller_type, b.trader_price, b.portfolio_eur_mwh AS portfolio_b, b.min_additive, b.energopomoc_price,
         b.viwa_additive,
         (SELECT e.value FROM ex e WHERE e.year = it.year AND e.price_model = it.price_model
                                    AND e.voltage_group IN (it.vg, 'vsetko') ORDER BY e.value LIMIT 1) AS exc,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'portfolio')) AS portfolio_today,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'spot_fve')) AS spot_fve,
         (SELECT coalesce(sum((coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * it.kw) * it.months), 0)
            FROM offer_item f
           WHERE f.variant_id = p_variant AND f.oom_id = it.oom_id AND f.slot <> 'komodita'
             AND (f.year = it.year OR f.year IS NULL)) AS fees
    FROM it
    LEFT JOIN offer_year_basis b ON b.variant_id = p_variant AND b.year = it.year
),
val AS (
  SELECT calc.*,
         pv_revenue(kind, price_model, vt, nt, ad, pct, v_vt, v_nt, spot_fve, viwa_additive) AS rev,
         pv_unit_cost(kind, price_model, vt, seller_type, trader_price, portfolio_b, energopomoc_price, min_additive, exc) AS ucost,
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost,
         CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
              WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
              WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
              WHEN kind = 'cennik' THEN 'odhad_portfolia'
              WHEN kind = 'energo' THEN 'energopomoc'
              WHEN kind = 'viwa' THEN 'viwa' END AS src
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       CASE WHEN src = 'odhad_portfolia' AND NOT (SELECT see_portfolio FROM v) THEN NULL ELSE ucost END,
       src,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            -- 0041: pri manažérovi je hranicou odhad portfólia (hlásenie hovorí, čo chýba a čo urobiť)
            WHEN kind = 'fix' AND ucost IS NULL THEN
              CASE WHEN seller_type = 'manazer'
                   THEN 'chýba odhad portfólia (hranica manažéra) – doplňte ho v cenách dňa a ponuku prepočítajte'
                   ELSE 'chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte' END
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

-- pre aplikáciu: jadro iba pre obchod, ktorý používateľ vidí (rovnaký výsledok ako pred 0052)
CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT c.* FROM offer_variant_values_core(p_variant) c
   WHERE EXISTS (SELECT 1 FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
                  WHERE v.id = p_variant AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id))
   ORDER BY c.year, c.voltage_group, c.oom_id
$$;

CREATE TABLE deal_value_cache (
  deal_id     uuid PRIMARY KEY REFERENCES deal (id) ON DELETE CASCADE,
  org_id      uuid NOT NULL REFERENCES org (id),
  value_eur   numeric(12,2),
  source      text NOT NULL CHECK (source IN ('akceptovany', 'ponuka', 'odhad')),
  variant_id  uuid REFERENCES offer_variant (id) ON DELETE SET NULL,
  computed_at timestamptz NOT NULL DEFAULT now(),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE deal_value_cache IS 'uložená pridaná hodnota obchodu pre prehľady (0052): akceptovaný variant → hlavný variant poslednej odoslanej ponuky → odhad; odvodený údaj, prepočíta ho databáza';
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON deal_value_cache FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE POLICY deal_value_cache_read ON deal_value_cache FOR SELECT
  USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_value_cache.deal_id));   -- RLS obchodu
ALTER TABLE deal_value_cache ENABLE ROW LEVEL SECURITY;

-- výpočet PH obchodu (interný, bez kontroly prístupu): akceptovaný variant → hlavný variant poslednej odoslanej ponuky → odhad
CREATE FUNCTION deal_value_compute(p_deal uuid) RETURNS TABLE (added_value_eur numeric, source text, variant_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     deal;
  v_var uuid;
  v_src text;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL THEN
    RETURN;
  END IF;
  IF d.accepted_variant_id IS NOT NULL THEN
    v_var := d.accepted_variant_id;
    v_src := 'akceptovany';
  ELSE
    SELECT offer_main_variant(o.id) INTO v_var FROM offer o
     WHERE o.deal_id = d.id AND o.sent_at IS NOT NULL AND o.status <> 'nahradena'
     ORDER BY o.sent_at DESC LIMIT 1;
    v_src := 'ponuka';
  END IF;
  IF v_var IS NOT NULL THEN
    RETURN QUERY SELECT sum(c.added_value_eur), v_src, v_var FROM offer_variant_values_core(v_var) c;
  ELSE
    RETURN QUERY SELECT d.estimated_value_eur, 'odhad'::text, NULL::uuid;
  END IF;
END;
$$;

-- uloží PH obchodu, ak sa zmenila; vráti true pri zmene
CREATE FUNCTION deal_value_refresh(p_deal uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r     record;
  v_org uuid;
  v_n   integer;
BEGIN
  SELECT org_id INTO v_org FROM deal WHERE id = p_deal;
  IF v_org IS NULL THEN
    RETURN false;
  END IF;
  SELECT * INTO r FROM deal_value_compute(p_deal);
  INSERT INTO deal_value_cache (deal_id, org_id, value_eur, source, variant_id)
  VALUES (p_deal, v_org, r.added_value_eur, r.source, r.variant_id)
  ON CONFLICT (deal_id) DO UPDATE
     SET value_eur = excluded.value_eur, source = excluded.source, variant_id = excluded.variant_id, computed_at = now()
   WHERE (deal_value_cache.value_eur, deal_value_cache.source, deal_value_cache.variant_id)
         IS DISTINCT FROM (excluded.value_eur, excluded.source, excluded.variant_id);
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n > 0;
END;
$$;

-- spúšťače: zmeny, ktoré menia PH obchodu
CREATE FUNCTION deal_value_on_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r jsonb := to_jsonb(CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);
BEGIN
  PERFORM deal_value_refresh(CASE TG_TABLE_NAME
    WHEN 'deal' THEN (r->>'id')::uuid
    WHEN 'offer' THEN (r->>'deal_id')::uuid
    WHEN 'offer_variant' THEN (SELECT o.deal_id FROM offer o WHERE o.id = (r->>'offer_id')::uuid)
    WHEN 'deal_oom' THEN (r->>'deal_id')::uuid
    WHEN 'approval_request' THEN (SELECT o.deal_id FROM offer o WHERE o.id = (r->>'offer_id')::uuid) END);
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_deal_value AFTER INSERT ON deal FOR EACH ROW EXECUTE FUNCTION deal_value_on_change();
CREATE TRIGGER trg_deal_value_upd AFTER UPDATE OF accepted_variant_id, estimated_value_eur ON deal FOR EACH ROW
  WHEN (OLD.accepted_variant_id IS DISTINCT FROM NEW.accepted_variant_id OR OLD.estimated_value_eur IS DISTINCT FROM NEW.estimated_value_eur)
  EXECUTE FUNCTION deal_value_on_change();
CREATE TRIGGER trg_deal_value AFTER INSERT OR DELETE OR UPDATE OF status, sent_at, replaced_by_id ON offer
  FOR EACH ROW EXECUTE FUNCTION deal_value_on_change();
CREATE TRIGGER trg_deal_value AFTER DELETE OR UPDATE OF is_main ON offer_variant
  FOR EACH ROW EXECUTE FUNCTION deal_value_on_change();
CREATE TRIGGER trg_deal_value AFTER INSERT OR DELETE OR UPDATE OF planned_vt_mwh, planned_nt_mwh, planned_feed_in_mwh, source_power_kw ON deal_oom
  FOR EACH ROW EXECUTE FUNCTION deal_value_on_change();
CREATE TRIGGER trg_deal_value AFTER UPDATE OF status ON approval_request
  FOR EACH ROW WHEN (NEW.offer_id IS NOT NULL) EXECUTE FUNCTION deal_value_on_change();

-- PH pre aplikáciu: uložená hodnota, iba obchod, ktorý používateľ vidí
CREATE OR REPLACE FUNCTION deal_value(p_deal uuid) RETURNS TABLE (added_value_eur numeric, source text, variant_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  RETURN QUERY
    SELECT c.value_eur, c.source, c.variant_id
      FROM deal d JOIN deal_value_cache c ON c.deal_id = d.id
     WHERE d.id = p_deal AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
END;
$$;

-- Nočná poistka (beh na pozadí po nočnom behu obchodov): prepočíta PH všetkých obchodov (aj PH, ktorá závisí od cien dňa);
-- počet rozdielov zapíše k dnešnému behu obchodov v denníku
CREATE FUNCTION deal_value_daily() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_all  integer := 0;
  v_diff integer := 0;
  d      record;
  v_res  jsonb;
BEGIN
  PERFORM crm_background_only();
  FOR d IN SELECT id FROM deal LOOP
    v_all := v_all + 1;
    IF deal_value_refresh(d.id) THEN
      v_diff := v_diff + 1;
    END IF;
  END LOOP;
  v_res := jsonb_build_object('ph_prepocitane', v_all, 'ph_rozdiel', v_diff);
  UPDATE job_run SET result = result || v_res
   WHERE id = (SELECT id FROM job_run WHERE job = 'obchody' AND run_date = crm_today() ORDER BY started_at DESC LIMIT 1);
  RETURN v_res;
END;
$$;

REVOKE EXECUTE ON FUNCTION offer_variant_values_core(uuid), deal_value_compute(uuid), deal_value_refresh(uuid) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION offer_variant_values_core(uuid), deal_value_compute(uuid), deal_value_refresh(uuid) FROM crm_app;
  END IF;
END;
$$;

-- naplnenie pre existujúce obchody
SELECT deal_value_refresh(id) FROM deal;

-- migrate:down

DROP FUNCTION deal_value_daily();
CREATE OR REPLACE FUNCTION deal_value(p_deal uuid) RETURNS TABLE (added_value_eur numeric, source text, variant_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     deal;
  v_var uuid;
  v_src text;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN;
  END IF;
  IF d.accepted_variant_id IS NOT NULL THEN
    v_var := d.accepted_variant_id;
    v_src := 'akceptovany';
  ELSE
    SELECT offer_main_variant(o.id) INTO v_var FROM offer o
     WHERE o.deal_id = d.id AND o.sent_at IS NOT NULL AND o.status <> 'nahradena'
     ORDER BY o.sent_at DESC LIMIT 1;
    v_src := 'ponuka';
  END IF;
  IF v_var IS NOT NULL THEN
    RETURN QUERY SELECT s.added_value_eur, v_src, v_var FROM offer_variant_summary(v_var) s WHERE s.year IS NULL;
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;
  RETURN QUERY SELECT d.estimated_value_eur, 'odhad'::text, NULL::uuid;
END;
$$;
DROP TRIGGER trg_deal_value ON approval_request;
DROP TRIGGER trg_deal_value ON deal_oom;
DROP TRIGGER trg_deal_value ON offer_variant;
DROP TRIGGER trg_deal_value ON offer;
DROP TRIGGER trg_deal_value_upd ON deal;
DROP TRIGGER trg_deal_value ON deal;
DROP FUNCTION deal_value_on_change();
DROP FUNCTION deal_value_refresh(uuid);
DROP FUNCTION deal_value_compute(uuid);
DROP TABLE deal_value_cache;
CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
sc AS (SELECT offer_variant_scope(p_variant) AS scope WHERE EXISTS (SELECT 1 FROM v)),
mo AS (SELECT m.m_start, m.year FROM offer_variant ov, offer_variant_months(ov) m
        WHERE ov.id = p_variant AND EXISTS (SELECT 1 FROM v)),
dm AS (
  SELECT x.oom_id, oom_voltage_group(o.voltage_level) AS vg, o.price_regulation AS reg,
         coalesce(x.planned_vt_mwh, 0) AS vt_y, coalesce(x.planned_nt_mwh, 0) AS nt_y,
         coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0) AS feed_y,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS kw
    FROM v JOIN deal_oom x ON x.deal_id = v.deal_id JOIN oom o ON o.id = x.oom_id
),
oy AS (   -- OOM × rok: mesiace a objemy
  SELECT dm.oom_id, dm.vg, dm.reg, dm.kw, mo.year, count(*)::int AS months,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN dm.feed_y ELSE dm.vt_y END * count(*) / 12 AS v_vt,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN 0 ELSE dm.nt_y END * count(*) / 12 AS v_nt
    FROM dm CROSS JOIN mo
   GROUP BY dm.oom_id, dm.vg, dm.reg, dm.kw, dm.feed_y, dm.vt_y, dm.nt_y, mo.year
),
it AS (
  SELECT oy.*, i.id AS item_id, i.price_model, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
         i.additive_eur_mwh AS ad, i.additive_pct AS pct,
         CASE WHEN (SELECT okind FROM v) = 'viwa' THEN 'viwa'
              WHEN (SELECT okind FROM v) = 'vykup' THEN CASE WHEN i.price_model IS NOT NULL THEN 'vykup' END
              WHEN i.price_model = 'cennik' AND (SELECT household FROM v) AND oy.reg THEN 'energo'
              WHEN i.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN i.price_model::text END AS kind
    FROM oy
    LEFT JOIN LATERAL (SELECT * FROM offer_item i
                        WHERE i.variant_id = p_variant AND i.oom_id = oy.oom_id AND i.slot = 'komodita'
                          AND (i.year = oy.year OR i.year IS NULL)
                        ORDER BY i.year NULLS LAST LIMIT 1) i ON true
),
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037), pri nezmenenom rozsahu variantu (0038)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
     -- neodoslaná verzia: rozsah variantu (OOM, roky, objemy) ako pri žiadosti; odoslaná si výnimku ponechá
     AND ((SELECT osent FROM v) IS NOT NULL OR a.scope = (SELECT scope FROM sc))
     -- výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá
     AND CASE WHEN (SELECT osent FROM v) IS NULL THEN r.valid_until IS NULL OR r.valid_until > now()
              ELSE r.valid_until IS NULL OR (SELECT osent FROM v) <= r.valid_until END
   GROUP BY 1, 2, 3
),
calc AS (
  SELECT it.*, b.seller_type, b.trader_price, b.portfolio_eur_mwh AS portfolio_b, b.min_additive, b.energopomoc_price,
         b.viwa_additive,
         (SELECT e.value FROM ex e WHERE e.year = it.year AND e.price_model = it.price_model
                                    AND e.voltage_group IN (it.vg, 'vsetko') ORDER BY e.value LIMIT 1) AS exc,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'portfolio')) AS portfolio_today,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'spot_fve')) AS spot_fve,
         (SELECT coalesce(sum((coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * it.kw) * it.months), 0)
            FROM offer_item f
           WHERE f.variant_id = p_variant AND f.oom_id = it.oom_id AND f.slot <> 'komodita'
             AND (f.year = it.year OR f.year IS NULL)) AS fees
    FROM it
    LEFT JOIN offer_year_basis b ON b.variant_id = p_variant AND b.year = it.year
),
val AS (
  SELECT calc.*,
         pv_revenue(kind, price_model, vt, nt, ad, pct, v_vt, v_nt, spot_fve, viwa_additive) AS rev,
         pv_unit_cost(kind, price_model, vt, seller_type, trader_price, portfolio_b, energopomoc_price, min_additive, exc) AS ucost,
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost,
         CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
              WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
              WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
              WHEN kind = 'cennik' THEN 'odhad_portfolia'
              WHEN kind = 'energo' THEN 'energopomoc'
              WHEN kind = 'viwa' THEN 'viwa' END AS src
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       CASE WHEN src = 'odhad_portfolia' AND NOT (SELECT see_portfolio FROM v) THEN NULL ELSE ucost END,
       src,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            -- 0041: pri manažérovi je hranicou odhad portfólia (hlásenie hovorí, čo chýba a čo urobiť)
            WHEN kind = 'fix' AND ucost IS NULL THEN
              CASE WHEN seller_type = 'manazer'
                   THEN 'chýba odhad portfólia (hranica manažéra) – doplňte ho v cenách dňa a ponuku prepočítajte'
                   ELSE 'chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte' END
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;
DROP FUNCTION offer_variant_values_core(uuid);
