-- migrate:up

-- 0056_nakupna_cena_portfolia – Peter 17. 10. 2026 (odpovede 1–4): „odhad portfólia“ = nákupná cena portfólia pre rok dodávky,
-- mení sa v čase. Marža firmy sa počíta vždy s poslednou cenou (prepočíta sa na všetkých zmluvách a obchodoch); pridaná hodnota,
-- uplatnené provízie a ponuky spárované so zmluvou sa nemenia.
-- 1. Zadanie nákupnej ceny pre rok dodávky „platí od“ dňa – dnes alebo spätne od 1. 1. 2026; iba admin a Nákup (aj dnešnú –
--    obchodný riaditeľ už nie; ručné BL, PL a SPOT pre FVE ostávajú admin a schvaľovateľ cien). Chýbajúce snímky zmlúv sa doplnia.
-- 2. Marža ponuky spárovanej so zmluvou sa zmrazí ku dňu spárovania.
-- 3. Texty „odhad portfólia“ → „nákupná cena portfólia“.

CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_correction', true) = 'on' THEN
    RETURN NEW;                                   -- označenie opravy z tejto funkcie (nižšie)
  END IF;
  -- 0056: nákupná cena portfólia (market_price_portfolio_set) – funkcia vlastníka zachová BL, PL a zdroj dňa
  IF TG_OP = 'INSERT' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_portfolio', true) = 'on' THEN
    RETURN NEW;
  END IF;
  -- 0047: načítanie z Montelu (market_price_import) – funkcia vlastníka označí zdroj a zachová ručné hodnoty dňa
  IF TG_OP = 'INSERT' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_import', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF crm_owner_session() THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM set_config('crm.market_price_correction', 'on', true);
      UPDATE market_price_daily SET corrected_at = now(), corrected_by = NULL
       WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
      PERFORM set_config('crm.market_price_correction', '', true);
    END IF;
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú – chybný záznam oprav novým.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Trhová cena sa nemení – chybný záznam oprav novým (tlačidlo Opraviť).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- 0056: nákupnú cenu portfólia mení iba admin a Nákup cez market_price_portfolio_set; ručné ceny dňa ju prevezmú zo dňa
  IF NEW.portfolio_eur_mwh IS DISTINCT FROM (SELECT m.portfolio_eur_mwh FROM market_price_daily m
                                               WHERE m.org_id = NEW.org_id AND m.on_date = NEW.on_date AND m.delivery_year = NEW.delivery_year
                                                 AND m.corrected_at IS NULL) THEN
    RAISE EXCEPTION 'Nákupnú cenu portfólia zadáva admin alebo Nákup tlačidlom „Nákupná cena portfólia – zadať pre obdobie“.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  NEW.corrected_at := NULL;
  NEW.corrected_by := NULL;
  PERFORM set_config('crm.market_price_correction', 'on', true);
  UPDATE market_price_daily SET corrected_at = now(), corrected_by = NEW.changed_by
   WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
  PERFORM set_config('crm.market_price_correction', '', true);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION market_price_flag_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (current_setting('crm.market_price_import', true) = 'on' OR current_setting('crm.market_price_correction', true) = 'on'
      OR current_setting('crm.market_price_portfolio', true) = 'on')
     AND NOT crm_internal_call() THEN
    RAISE EXCEPTION 'Trhové ceny z Montelu zapisuje iba denný beh alebo načítanie histórie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;

-- Nákup (tím s kódom nakup): zadáva nákupnú cenu portfólia spolu s adminom
CREATE FUNCTION crm_is_purchase() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id WHERE u.id = crm_active_user_id() AND t.code = 'nakup')
$$;

-- Nákupná cena portfólia pre rok dodávky platná od dňa (dnes alebo spätne od 1. 1. 2026): nový záznam dňa prevezme BL, PL,
-- cenu SPOT pre FVE a zdroj platného záznamu toho dňa (Montel ich nezablokuje), pôvodný ostane v histórii ako opravený.
-- Platí od dňa po ďalší deň s vlastnou nákupnou cenou (contract_market_value berie poslednú k dňu). Marža firmy sa počíta
-- vždy s poslednou cenou – prepočíta sa sama. Snímkam ku dňu podpisu sa doplní iba chýbajúca cena (zmluvy podpísané
-- od dňa, bez ceny v snímke); existujúce snímky, pridaná hodnota a uplatnené provízie sa nemenia.
CREATE FUNCTION market_price_portfolio_set(p_org uuid, p_on date, p_year integer, p_value numeric) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  cur     market_price_daily;
  v_me    uuid := crm_active_user_id();
  v_val   numeric := round(p_value, 4);
  v_next  date;
  v_n     integer := 0;
  c       record;
BEGIN
  IF v_me IS NULL OR NOT (crm_is_admin() OR crm_is_purchase()) THEN
    RAISE EXCEPTION 'Nákupnú cenu portfólia zadáva admin alebo Nákup.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT p_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Spoločnosť nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_on IS NULL OR p_on < '2026-01-01' OR p_on > crm_today() THEN
    RAISE EXCEPTION 'Deň „platí od“: od 1. 1. 2026 do dnes.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_year IS NULL OR p_year < 2026 OR p_year > 2100 THEN
    RAISE EXCEPTION 'Rok dodávky: 2026 až 2100.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_val IS NULL OR v_val < 0 OR v_val > 10000 THEN
    RAISE EXCEPTION 'Nákupná cena portfólia: 0 až 10 000 €/MWh.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO cur FROM market_price_daily
   WHERE org_id = p_org AND on_date = p_on AND delivery_year = p_year AND corrected_at IS NULL FOR UPDATE;
  IF cur.id IS NOT NULL AND cur.portfolio_eur_mwh = v_val THEN
    RETURN jsonb_build_object('zmena', false);
  END IF;
  IF cur.id IS NOT NULL THEN
    PERFORM set_config('crm.market_price_correction', 'on', true);
    UPDATE market_price_daily SET corrected_at = now(), corrected_by = v_me WHERE id = cur.id;
    PERFORM set_config('crm.market_price_correction', '', true);
  END IF;
  PERFORM set_config('crm.market_price_portfolio', 'on', true);
  INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh, source, changed_by)
  VALUES (p_org, p_on, p_year, cur.bl_eur_mwh, cur.pl_eur_mwh, v_val, cur.spot_fve_eur_mwh, coalesce(cur.source, 'rucne'), v_me);
  PERFORM set_config('crm.market_price_portfolio', '', true);
  -- snímky zmlúv ku dňu podpisu bez nákupnej ceny portfólia (napr. podpis v deň bez ceny)
  FOR c IN SELECT DISTINCT k.id FROM contract k JOIN contract_year_basis b ON b.contract_id = k.id
            WHERE k.org_id = p_org AND b.year = p_year AND b.portfolio_eur_mwh IS NULL AND k.signed_on >= p_on
            ORDER BY k.id LOOP
    PERFORM contract_basis_refresh(c.id);
    v_n := v_n + 1;
  END LOOP;
  SELECT min(m.on_date) INTO v_next FROM market_price_daily m
   WHERE m.org_id = p_org AND m.delivery_year = p_year AND m.corrected_at IS NULL AND m.on_date > p_on AND m.portfolio_eur_mwh IS NOT NULL;
  RETURN jsonb_build_object('zmena', true, 'zmluvy_doplnene', v_n, 'plati_do', v_next - 1);
END;
$$;
COMMENT ON FUNCTION market_price_portfolio_set(uuid, date, integer, numeric) IS 'nákupná cena portfólia pre rok dodávky od dňa (admin, Nákup; 0056); BL/PL dňa ostanú; snímkam doplní iba chýbajúcu cenu';

-- História nákupných cien portfólia (Nastavenia → Cenové parametre): platné záznamy dňa s cenou, kto a kedy
CREATE FUNCTION market_price_portfolio_history(p_org uuid) RETURNS TABLE (delivery_year smallint, on_date date, value numeric, source text, changed_by_name text, created_at timestamptz, is_current boolean)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT m.delivery_year, m.on_date, m.portfolio_eur_mwh, m.source, crm_user_name(m.changed_by), m.created_at,
         m.on_date = max(m.on_date) FILTER (WHERE m.on_date <= crm_today()) OVER (PARTITION BY m.delivery_year)
    FROM market_price_daily m
   WHERE m.org_id = p_org AND m.corrected_at IS NULL AND m.portfolio_eur_mwh IS NOT NULL
     AND p_org = ANY (crm_user_orgs()) AND (crm_is_admin() OR crm_is_purchase() OR crm_sees_portfolio())
     -- iba dni, keď sa cena zmenila oproti predošlému dňu s cenou (Montel ju denne prenáša ďalej)
     AND m.portfolio_eur_mwh IS DISTINCT FROM (SELECT p.portfolio_eur_mwh FROM market_price_daily p
                                                WHERE p.org_id = m.org_id AND p.delivery_year = m.delivery_year AND p.corrected_at IS NULL
                                                  AND p.portfolio_eur_mwh IS NOT NULL AND p.on_date < m.on_date
                                                ORDER BY p.on_date DESC LIMIT 1)
   ORDER BY m.delivery_year, m.on_date DESC
$$;

CREATE OR REPLACE FUNCTION offer_variant_values_core(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio,
         -- 0056: marža ponuky spárovanej so zmluvou sa zmrazí ku dňu spárovania (živá marža je na zmluve); ostatné dnes
         coalesce((SELECT crm_local_date(min(k.deal_matched_at)) FROM contract k
                    WHERE k.offer_variant_id = v.id AND k.deal_match IN ('auto', 'rucne')), crm_today()) AS margin_on
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
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, (SELECT margin_on FROM v), 'portfolio')) AS portfolio_today,
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
                   THEN 'chýba nákupná cena portfólia (hranica manažéra) – doplňte ju v cenových parametroch a ponuku prepočítajte'
                   ELSE 'chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte' END
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

CREATE OR REPLACE FUNCTION contract_year_calc_core(p_contract_id uuid, p_year integer, p_until date DEFAULT NULL::date) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
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
              WHEN bool_or(kind = 'cennik' AND unit_cost IS NULL) THEN 'nákupná cena portfólia ku dňu podpisu'
              WHEN bool_or(kind = 'energo' AND unit_cost IS NULL) THEN 'nákupná cena energopomoci'
              WHEN bool_or(kind = 'viwa' AND rev IS NULL) THEN 'balík VIWA'
              WHEN bool_or(kind = 'vykup' AND price_model = 'spot_minus_pct' AND rev IS NULL) THEN 'očakávaná cena SPOT pre FVE'
              WHEN bool_or(kind IS NOT NULL AND unit_mcost IS NULL) THEN 'nákupná cena portfólia (marža)' END AS missing
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

-- interné: bez PUBLIC; aplikácia volá iba zadanie a históriu (kontrolujú práva samy)
REVOKE EXECUTE ON FUNCTION crm_is_purchase() FROM PUBLIC;

-- migrate:down

DROP FUNCTION market_price_portfolio_history(uuid);
DROP FUNCTION market_price_portfolio_set(uuid, date, integer, numeric);
DROP FUNCTION crm_is_purchase();
CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_correction', true) = 'on' THEN
    RETURN NEW;                                   -- označenie opravy z tejto funkcie (nižšie)
  END IF;
  -- 0047: načítanie z Montelu (market_price_import) – funkcia vlastníka označí zdroj a zachová ručné hodnoty dňa
  IF TG_OP = 'INSERT' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_import', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF crm_owner_session() THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM set_config('crm.market_price_correction', 'on', true);
      UPDATE market_price_daily SET corrected_at = now(), corrected_by = NULL
       WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
      PERFORM set_config('crm.market_price_correction', '', true);
    END IF;
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú – chybný záznam oprav novým.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Trhová cena sa nemení – chybný záznam oprav novým (tlačidlo Opraviť).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  NEW.corrected_at := NULL;
  NEW.corrected_by := NULL;
  PERFORM set_config('crm.market_price_correction', 'on', true);
  UPDATE market_price_daily SET corrected_at = now(), corrected_by = NEW.changed_by
   WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
  PERFORM set_config('crm.market_price_correction', '', true);
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION market_price_flag_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF (current_setting('crm.market_price_import', true) = 'on' OR current_setting('crm.market_price_correction', true) = 'on')
     AND NOT crm_internal_call() THEN
    RAISE EXCEPTION 'Trhové ceny z Montelu zapisuje iba denný beh alebo načítanie histórie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;

CREATE OR REPLACE FUNCTION offer_variant_values_core(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
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

CREATE OR REPLACE FUNCTION contract_year_calc_core(p_contract_id uuid, p_year integer, p_until date DEFAULT NULL::date) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
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
