-- migrate:up

-- 0038_ponuky_doplnky – modul 5, fáza F2: doplnky pred API (Peter 15. 10., návrh DB časť 21)
-- 1. Hranica z odhadu portfólia (FIX manažéra, cenník) sa nezobrazí tomu, kto nevidí maržu firmy a nie je manažér:
--    hodnoty variantu, kontrola ponuky, detail výnimky a audit položiek výnimky. Položky výnimky aplikácia číta
--    iba funkciou (approval_price_detail), snímku hraníc vôbec.
-- 2. Schválená výnimka prejde na novú verziu, ak je v 3-dňovej lehote a OOM, roky a objemy variantu sa nezmenili;
--    cena pod schválenou hranicou znamená nové schválenie (výpočet ju označí „pod hranicou“).
-- 3. Akceptácia verzie (jadro pre F3 – klik zákazníka aj ručný záznam): ostatné odoslané verzie Nahradené, rozpracovaná
--    nová verzia sa zablokuje (nedá sa pripraviť ani odoslať, čakajúce žiadosti sa zrušia) a vlastník dostane upozornenie.

-- ============================================================================
-- 1. Kto vidí odhad portfólia: admin, „vidieť maržu firmy“ alebo „schvaľuje ceny“, predajca typu manažér
-- ============================================================================

CREATE FUNCTION crm_sees_portfolio() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_admin() OR crm_can_see_margin()
      OR coalesce((SELECT u.seller_type = 'manazer' FROM app_user u WHERE u.id = crm_active_user_id()), false)
$$;
COMMENT ON FUNCTION crm_sees_portfolio() IS 'odhad nákupnej ceny portfólia (hranica FIX manažéra a cenníka): admin, marža firmy, manažér (0038)';

-- Rozsah variantu pre platnosť výnimky: obdobie, plánovaný objem a OOM obchodu s napäťovou skupinou a objemami
CREATE FUNCTION offer_variant_scope(p_variant uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'supply_from', v.supply_from, 'supply_to', v.supply_to, 'planned_volume_mwh', v.planned_volume_mwh,
           'oom', (SELECT coalesce(jsonb_agg(jsonb_build_array(x.oom_id, oom_voltage_group(m.voltage_level),
                                                               x.planned_vt_mwh, x.planned_nt_mwh, x.planned_feed_in_mwh,
                                                               coalesce(x.source_power_kw, m.source_power_kw))
                                             ORDER BY x.oom_id), '[]')
                     FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                    WHERE x.deal_id = o.deal_id))
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id
   WHERE v.id = p_variant
$$;
REVOKE EXECUTE ON FUNCTION offer_variant_scope(uuid) FROM PUBLIC;

ALTER TABLE approval_price_item
  ADD COLUMN threshold_source text CHECK (threshold_source IN ('cena_pre_obchodnika', 'odhad_portfolia', 'min_aditiv')),
  ADD COLUMN scope            jsonb;
COMMENT ON COLUMN approval_price_item.threshold_source IS 'odkiaľ je hranica; odhad portfólia vidí iba crm_sees_portfolio() (0038)';
COMMENT ON COLUMN approval_price_item.scope IS 'rozsah variantu pri žiadosti (offer_variant_scope) – výnimka platí, kým sa nezmení (0038)';
UPDATE approval_price_item i
   SET scope = offer_variant_scope(i.variant_id),
       threshold_source = CASE WHEN i.price_model = 'fix' THEN
                            CASE WHEN (SELECT b.seller_type FROM offer_year_basis b WHERE b.variant_id = i.variant_id AND b.year = i.year) = 'manazer'
                                 THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
                          ELSE 'min_aditiv' END;
ALTER TABLE approval_price_item ALTER COLUMN threshold_source SET NOT NULL, ALTER COLUMN scope SET NOT NULL;

-- ============================================================================
-- 2. Hodnoty variantu: výnimka iba pri nezmenenom rozsahu; hranica z odhadu portfólia iba s právom
-- ============================================================================

CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE (
  oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model price_model, kind text,
  price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric,
  months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text,
  exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
            WHEN kind = 'fix' AND ucost IS NULL THEN 'chýba cena pre obchodníka'
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

-- ============================================================================
-- 3. Kontrola ponuky: úplná (kód databázy) a pre aplikáciu (bez hranice z odhadu portfólia); akceptovaná iná verzia
-- ============================================================================

CREATE FUNCTION offer_check_internal(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
  v_acc   offer;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  -- zákazník akceptoval inú verziu: rozpracovaná verzia sa nedá pripraviť ani odoslať (0038)
  SELECT * INTO v_acc FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.id <> o.id AND x.status = 'akceptovana';
  IF FOUND THEN
    errors := errors || to_jsonb(format('Zákazník akceptoval ponuku %s – túto verziu nemožno odoslať.', offer_display_number(v_acc)));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE offer_id = o.id) THEN
    errors := errors || to_jsonb('Ponuka nemá variant.'::text);
  END IF;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    FOR r IN SELECT x.year, x.missing, m.eic FROM offer_variant_values(v.id) x LEFT JOIN oom m ON m.id = x.oom_id
              WHERE x.missing IS NOT NULL ORDER BY x.year, m.eic LOOP
      errors := errors || to_jsonb(format('Variant %s (%s): %s – OOM %s, rok %s', chr(64 + v.sort_order), v.name, r.missing, r.eic, r.year));
    END LOOP;
    FOR r IN SELECT x.year, x.price_model, x.voltage_group,
                    min(CASE WHEN x.price_model = 'spot_minus_pct' THEN x.additive_pct
                             WHEN x.price_model IN ('spot_plus_eur', 'spot_minus_eur') THEN x.additive
                             ELSE least(x.price_vt, coalesce(x.price_nt, x.price_vt)) END) AS requested,
                    min(b.th) AS threshold, min(b.src) AS source, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th,
                                         CASE WHEN x.price_model <> 'fix' THEN 'min_aditiv'
                                              WHEN ob.seller_type = 'manazer' THEN 'odhad_portfolia'
                                              ELSE 'cena_pre_obchodnika' END AS src
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold,
                                           'threshold_source', coalesce(r.source, 'cena_pre_obchodnika'), 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
  v_risk := CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END;
  -- schválenie rizika platí pre celý obchod 30 dní, kým sa údaje Finstatu nezhoršia (odpoveď 9)
  v_risk_ok := EXISTS (SELECT 1 FROM approval_request a
                        WHERE a.deal_id = d.id AND a.kind = 'rizikovy_zakaznik' AND a.status = 'schvalena'
                          AND (a.valid_until IS NULL OR a.valid_until > now())
                          AND NOT company_risk_worse(a.risk_snapshot, company_risk_snapshot(d.company_id)));
  RETURN jsonb_build_object('errors', errors, 'needs', needs,
                            'risk_needs_approval', coalesce((v_risk->>'needs_approval')::boolean, false) AND NOT v_risk_ok,
                            'risk', v_risk,
                            'fix_stale', o.priced_on < crm_today()
                                         AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_check_internal(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION offer_check(p_offer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE WHEN c IS NULL OR crm_sees_portfolio() THEN c
              ELSE jsonb_set(c, '{needs}', coalesce(
                     (SELECT jsonb_agg(CASE WHEN n->>'threshold_source' = 'odhad_portfolia'
                                            THEN jsonb_set(n, '{threshold_value}', 'null') ELSE n END ORDER BY t.ord)
                        FROM jsonb_array_elements(c->'needs') WITH ORDINALITY AS t(n, ord)), '[]')) END
    FROM offer_check_internal(p_offer) AS c
$$;

-- ============================================================================
-- 4. Žiadosť o výnimku: rozsah variantu a zdroj hranice; detail iba pôvodnej ponuky žiadosti, hranica podľa práva
-- ============================================================================

CREATE OR REPLACE FUNCTION approval_request_offer(p_offer uuid, p_reason text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o      offer := offer_for_edit(p_offer);
  d      deal;
  c      jsonb;
  n      jsonb;
  v_id   uuid;
  v_user uuid := crm_active_user_id();
  v_appr uuid[];
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena') THEN
    RAISE EXCEPTION 'O schválenie sa žiada pri koncepte ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  c := offer_check_internal(o.id);
  IF jsonb_array_length(c->'errors') > 0 THEN
    RAISE EXCEPTION '%', (SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(c->'errors') e) USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(c->'needs') = 0 AND NOT (c->>'risk_needs_approval')::boolean THEN
    RETURN offer_prepare(o.id);
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod žiadosti o schválenie.' USING ERRCODE = 'check_violation';
  END IF;
  v_appr := array_remove(notification_approvers(o.org_id, false), v_user);

  IF jsonb_array_length(c->'needs') > 0 THEN
    UPDATE approval_request SET status = 'zrusena' WHERE offer_id = o.id AND kind = 'vynimka_ceny' AND status = 'caka';
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by)
    VALUES (o.org_id, 'vynimka_ceny', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user)
    RETURNING id INTO v_id;
    FOR n IN SELECT * FROM jsonb_array_elements(c->'needs') LOOP
      INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                       volume_mwh, threshold_source, scope)
      VALUES (v_id, (n->>'variant_id')::uuid, (n->>'year')::smallint, (n->>'price_model')::price_model, n->>'voltage_group',
              (n->>'requested_value')::numeric, coalesce((n->>'threshold_value')::numeric, 0), (n->>'volume_mwh')::numeric,
              n->>'threshold_source', offer_variant_scope((n->>'variant_id')::uuid));
    END LOOP;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Výnimka z ceny – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'vynimka_ceny', 'approval_id', v_id));
  END IF;

  IF (c->>'risk_needs_approval')::boolean
     AND NOT EXISTS (SELECT 1 FROM approval_request WHERE deal_id = o.deal_id AND kind = 'rizikovy_zakaznik' AND status = 'caka') THEN
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, risk_snapshot)
    VALUES (o.org_id, 'rizikovy_zakaznik', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user, company_risk_snapshot(d.company_id))
    RETURNING id INTO v_id;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Rizikový zákazník – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'rizikovy_zakaznik', 'approval_id', v_id));
  END IF;

  UPDATE offer SET status = 'caka_na_schvalenie' WHERE id = o.id;
  RETURN 'caka_na_schvalenie';
END;
$$;

CREATE OR REPLACE FUNCTION approval_price_detail(p_id uuid) RETURNS TABLE (
  variant_id uuid, variant text, year smallint, price_model price_model, voltage_group text,
  requested_value numeric, threshold_value numeric, approved_value numeric, volume_mwh numeric,
  added_value_requested numeric, portfolio_eur_mwh numeric, margin_requested numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT i.variant_id, chr(64 + v.sort_order) || ' · ' || v.name, i.year, i.price_model, i.voltage_group,
         i.requested_value,
         CASE WHEN i.threshold_source = 'odhad_portfolia' AND NOT crm_sees_portfolio() THEN NULL ELSE i.threshold_value END,
         i.approved_value, i.volume_mwh,
         round((i.requested_value - coalesce(i.approved_value, i.requested_value)) * coalesce(i.volume_mwh, 0), 2),
         CASE WHEN crm_can_see_margin() THEN (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')) END,
         CASE WHEN crm_can_see_margin() AND i.price_model = 'fix' THEN
           round((i.requested_value - (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')))
                 * coalesce(i.volume_mwh, 0), 2) END
    FROM approval_request a
    JOIN approval_price_item i ON i.approval_id = a.id
    JOIN offer_variant v ON v.id = i.variant_id AND v.offer_id = a.offer_id   -- bez kópií prenesených do novej verzie
   WHERE a.id = p_id AND a.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR a.requested_by = crm_active_user_id() OR crm_approves_prices())
   ORDER BY v.sort_order, i.year, i.voltage_group
$$;

-- ============================================================================
-- 5. Nová verzia preberie platnú výnimku; prepočet ruší iba vlastné výnimky verzie
-- ============================================================================

CREATE OR REPLACE FUNCTION offer_new_version(p_offer uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
  v_exc integer := 0;
  v_cnt integer;
BEGIN
  IF o.status IN ('koncept', 'caka_na_schvalenie', 'pripravena') THEN
    RAISE EXCEPTION 'Rozpracovanú ponuku upravte priamo (alebo prepočítajte na dnešné ceny).' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status IN ('akceptovana', 'nahradena') THEN
    RAISE EXCEPTION 'Z akceptovanej alebo nahradenej verzie sa nová verzia nerobí.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE org_id = o.org_id AND number = o.number
                                   AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) THEN
    RAISE EXCEPTION 'Rozpracovaná verzia už existuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT closed_at FROM deal WHERE id = o.deal_id) IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať novú verziu ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, language, contact_id, priced_on, seller_type,
                     custom, created_by)
  SELECT o.deal_id, o.org_id, o.number, (SELECT max(version) + 1 FROM offer WHERE org_id = o.org_id AND number = o.number),
         o.kind, o.household, 'koncept', o.language, o.contact_id, crm_today(),
         coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik'),
         o.custom, crm_current_user_id()
  RETURNING * INTO n;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                               flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                               negative_price_compensation)
    VALUES (n.id, n.org_id, v.sort_order, v.name, v.price_kind, v.supply_from, v.supply_to, v.viwa_package,
            v.flexibility_pct, v.planned_volume_mwh, v.invoice_due_days, v.advance_kind, v.advance_pct, v.advance_due_day,
            v.negative_price_compensation)
    RETURNING id INTO v_new;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_new, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i
     WHERE i.variant_id = v.id AND i.price_model <> 'cennik'
       AND (i.oom_id IS NULL OR EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = n.deal_id AND x.oom_id = i.oom_id))
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
    -- schválená výnimka v 3-dňovej lehote prejde s rozsahom zo žiadosti (0038): platí, kým sa OOM, roky a objemy
    -- nezmenia; cena pod schválenou hranicou → výpočet „pod hranicou“ → nové schválenie
    INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                     approved_value, volume_mwh, threshold_source, scope)
    SELECT a.approval_id, v_new, a.year, a.price_model, a.voltage_group, a.requested_value, a.threshold_value,
           a.approved_value, a.volume_mwh, a.threshold_source, a.scope
      FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
     WHERE a.variant_id = v.id AND r.kind = 'vynimka_ceny' AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
       AND r.valid_until > now();
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_exc := v_exc + v_cnt;
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia', CASE WHEN v_exc > 0 THEN jsonb_build_object('exceptions_carried', v_exc) END);
  RETURN n.id;
END;
$$;

CREATE OR REPLACE FUNCTION offer_reprice(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  -- vlastné schválené výnimky verzie sa zrušia; prevzaté zo starej verzie sa iba odpoja (stará verzia si ich ponechá)
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny' AND offer_id = o.id;
  DELETE FROM approval_price_item a
   USING offer_variant x, approval_request r
   WHERE x.id = a.variant_id AND x.offer_id = o.id AND r.id = a.approval_id AND r.offer_id IS DISTINCT FROM o.id;
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;

-- ============================================================================
-- 6. Akceptácia verzie (jadro; F3 doplní záznam offer_acceptance, klik zákazníka a ručný záznam)
-- ============================================================================

ALTER TABLE deal_event
  DROP CONSTRAINT deal_event_kind_check,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik',
    'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana', 'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost',
    'schvalenie_ziadost', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'ponuka_zablokovana'));

ALTER TABLE notification
  DROP CONSTRAINT notification_kind_check,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm',
    'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy',
    'ponuka_akceptovana', 'ponuka_zablokovana'));

-- Zmazaný koncept ponuky: cudzí kľúč nastaví deal_event.offer_id na NULL – iba táto zmena je povolená (udalosť ostane
-- s číslom a verziou v detaile). Bez toho sa koncept s udalosťou „nová ponuka / verzia“ nedal zmazať (chyba 0036).
CREATE OR REPLACE FUNCTION deal_event_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.offer_id IS NOT NULL AND NEW.offer_id IS NULL AND (to_jsonb(NEW) - 'offer_id') = (to_jsonb(OLD) - 'offer_id') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Udalosti časovej osi sa nemenia ani nemažú.' USING ERRCODE = 'check_violation';
END;
$$;

-- Akceptácia variantu odoslanej verzie (čas databázy, v platnosti). Volá ju iba kód databázy (F3: klik, ručný záznam).
CREATE FUNCTION offer_accept_apply(p_offer uuid, p_variant uuid, p_accepted_at timestamptz DEFAULT now()) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  x       offer;
  v_stage uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ponuka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id FOR UPDATE;
  IF o.status NOT IN ('odoslana', 'otvorena') THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_accepted_at IS NULL OR p_accepted_at < o.sent_at OR p_accepted_at > now() + interval '5 minutes'
     OR o.valid_until IS NULL OR p_accepted_at >= o.valid_until THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba v platnosti ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE id = p_variant AND offer_id = o.id) THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke.' USING ERRCODE = 'check_violation';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;

  UPDATE offer SET status = 'akceptovana' WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- rozpracovaná nová verzia: späť do konceptu, čakajúce žiadosti zrušené, odoslať sa nedá (offer_check_internal)
  FOR x IN SELECT * FROM offer WHERE org_id = o.org_id AND number = o.number
                                 AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena') LOOP
    UPDATE approval_request SET status = 'zrusena' WHERE status = 'caka' AND offer_id = x.id;
    UPDATE offer SET status = 'koncept' WHERE id = x.id AND status <> 'koncept';
    PERFORM notification_add_deal(ARRAY[d.owner_id, x.created_by], 'ponuka_zablokovana', d.id, NULL, NULL,
      format('Zákazník akceptoval ponuku %s – rozpracovanú verziu %s nemožno odoslať.', offer_display_number(o), offer_display_number(x)));
    PERFORM deal_event_offer(x, 'ponuka_zablokovana', jsonb_build_object('accepted_offer_id', o.id, 'accepted_version', o.version));
  END LOOP;

  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'akceptacia'
   WHERE s.id = d.stage_id AND s.code IN ('prilezitost', 'cenova_ponuka', 'vyjednavanie');
  UPDATE deal SET accepted_variant_id = p_variant, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_akceptovana', d.id, NULL, NULL,
                                'Zákazník akceptoval ponuku ' || offer_display_number(o));
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_akceptovana', jsonb_build_object('variant_id', p_variant, 'accepted_at', p_accepted_at));
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_accept_apply(uuid, uuid, timestamptz) FROM PUBLIC;

-- ============================================================================
-- 7. Audit: položky výnimky s hranicou z odhadu portfólia iba s právom
-- ============================================================================

CREATE OR REPLACE FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  d    deal;
  k    contract;
  a    approval_request;
BEGIN
  IF crm_is_service() OR crm_is_admin() THEN
    RETURN true;
  END IF;
  IF crm_active_user_id() IS NULL THEN
    RETURN false;
  END IF;

  CASE p_table
    WHEN 'company' THEN
      RETURN crm_company_access(p_record, 'view');
    WHEN 'contact' THEN
      RETURN crm_contact_access(p_record, 'view');
    WHEN 'company_contact' THEN
      v_id := coalesce((SELECT company_id FROM company_contact WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_company_access(v_id, 'view');
    WHEN 'activity' THEN
      v_id := coalesce((SELECT company_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      IF v_id IS NOT NULL THEN
        RETURN crm_company_access(v_id, 'view');
      END IF;
      v_id := coalesce((SELECT contact_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'contact_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_contact_access(v_id, 'view');
    WHEN 'oom' THEN
      RETURN crm_oom_access(p_record, 'view');
    WHEN 'oom_customer', 'oom_device', 'oom_contact', 'oom_planned_change', 'oom_price_regulation_change' THEN
      v_id := audit_diff_value(p_diff, 'oom_id')::uuid;
      IF v_id IS NULL THEN
        EXECUTE format('SELECT oom_id FROM %I WHERE id = $1', p_table) INTO v_id USING p_record;
      END IF;
      RETURN v_id IS NOT NULL AND crm_oom_access(v_id, 'view');
    WHEN 'deal', 'deal_oom', 'deal_contact' THEN
      v_id := CASE WHEN p_table = 'deal' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'deal_id')::uuid,
                                 (SELECT deal_id FROM deal_oom WHERE id = p_record),
                                 (SELECT deal_id FROM deal_contact WHERE id = p_record)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'contract', 'contract_oom', 'contract_price', 'contract_flag' THEN
      v_id := CASE WHEN p_table = 'contract' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'contract_id')::uuid,
                                 (SELECT contract_id FROM contract_oom WHERE id = p_record),
                                 (SELECT contract_id FROM contract_price WHERE id = p_record),
                                 (SELECT contract_id FROM contract_flag WHERE id = p_record)) END;
      SELECT * INTO k FROM contract WHERE id = v_id;
      RETURN FOUND AND k.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(k.company_id, k.person_id, k.owner_id);
    WHEN 'price_exception' THEN
      RETURN crm_sees_all_contracts()
          OR coalesce((SELECT requested_by FROM price_exception WHERE id = p_record),
                      audit_diff_value(p_diff, 'requested_by')::uuid) = crm_active_user_id();
    WHEN 'approval_request' THEN
      SELECT * INTO a FROM approval_request WHERE id = p_record;
      RETURN FOUND AND a.org_id = ANY (crm_user_orgs())
         AND (a.requested_by = crm_active_user_id() OR a.from_owner_id = crm_active_user_id()
              OR (a.kind = 'pridelenie_firmy' AND crm_approves_assignments())
              OR (a.kind <> 'pridelenie_firmy' AND crm_approves_prices()));
    WHEN 'offer', 'offer_variant', 'offer_item' THEN
      -- ponuka: podľa obchodu (0036); ceny ponuky neobsahujú hranice ani maržu
      v_id := CASE p_table
                WHEN 'offer' THEN coalesce((SELECT deal_id FROM offer WHERE id = p_record), audit_diff_value(p_diff, 'deal_id')::uuid)
                WHEN 'offer_variant' THEN (SELECT o.deal_id FROM offer o
                                            WHERE o.id = coalesce((SELECT offer_id FROM offer_variant WHERE id = p_record),
                                                                  audit_diff_value(p_diff, 'offer_id')::uuid))
                ELSE (SELECT o.deal_id FROM offer_variant v JOIN offer o ON o.id = v.offer_id
                       WHERE v.id = coalesce((SELECT variant_id FROM offer_item WHERE id = p_record),
                                             audit_diff_value(p_diff, 'variant_id')::uuid)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'approval_price_item' THEN
      -- hranica z odhadu portfólia (FIX manažéra) iba pre crm_sees_portfolio(); neznámy zdroj = skryť (0038)
      IF NOT crm_sees_portfolio()
         AND coalesce((SELECT threshold_source FROM approval_price_item WHERE id = p_record),
                      audit_diff_value(p_diff, 'threshold_source'), 'odhad_portfolia') = 'odhad_portfolia' THEN
        RETURN false;
      END IF;
      RETURN audit_row_visible('approval_request',
                               coalesce((SELECT approval_id FROM approval_price_item WHERE id = p_record),
                                        audit_diff_value(p_diff, 'approval_id')::uuid), NULL);
    WHEN 'user_commission_rate' THEN
      RETURN crm_approves_prices()
          OR coalesce((SELECT user_id FROM user_commission_rate WHERE id = p_record),
                      audit_diff_value(p_diff, 'user_id')::uuid) = crm_active_user_id();
    WHEN 'price_parameter', 'market_price_daily' THEN
      RETURN crm_approves_prices() OR crm_can_see_margin();   -- kto smie čítať cenové parametre a trhové ceny (0023)
    ELSE
      RETURN false;   -- Nastavenia, používatelia, tímy, cenníky, importy: iba admin
  END CASE;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;     -- poškodené id v obsahu zmeny: radšej skryť
END;
$$;

-- migrate:down

-- funkcie z 0036 / 0037 v pôvodnom znení
CREATE OR REPLACE FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  d    deal;
  k    contract;
  a    approval_request;
BEGIN
  IF crm_is_service() OR crm_is_admin() THEN
    RETURN true;
  END IF;
  IF crm_active_user_id() IS NULL THEN
    RETURN false;
  END IF;

  CASE p_table
    WHEN 'company' THEN
      RETURN crm_company_access(p_record, 'view');
    WHEN 'contact' THEN
      RETURN crm_contact_access(p_record, 'view');
    WHEN 'company_contact' THEN
      v_id := coalesce((SELECT company_id FROM company_contact WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_company_access(v_id, 'view');
    WHEN 'activity' THEN
      v_id := coalesce((SELECT company_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      IF v_id IS NOT NULL THEN
        RETURN crm_company_access(v_id, 'view');
      END IF;
      v_id := coalesce((SELECT contact_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'contact_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_contact_access(v_id, 'view');
    WHEN 'oom' THEN
      RETURN crm_oom_access(p_record, 'view');
    WHEN 'oom_customer', 'oom_device', 'oom_contact', 'oom_planned_change', 'oom_price_regulation_change' THEN
      v_id := audit_diff_value(p_diff, 'oom_id')::uuid;
      IF v_id IS NULL THEN
        EXECUTE format('SELECT oom_id FROM %I WHERE id = $1', p_table) INTO v_id USING p_record;
      END IF;
      RETURN v_id IS NOT NULL AND crm_oom_access(v_id, 'view');
    WHEN 'deal', 'deal_oom', 'deal_contact' THEN
      v_id := CASE WHEN p_table = 'deal' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'deal_id')::uuid,
                                 (SELECT deal_id FROM deal_oom WHERE id = p_record),
                                 (SELECT deal_id FROM deal_contact WHERE id = p_record)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'contract', 'contract_oom', 'contract_price', 'contract_flag' THEN
      v_id := CASE WHEN p_table = 'contract' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'contract_id')::uuid,
                                 (SELECT contract_id FROM contract_oom WHERE id = p_record),
                                 (SELECT contract_id FROM contract_price WHERE id = p_record),
                                 (SELECT contract_id FROM contract_flag WHERE id = p_record)) END;
      SELECT * INTO k FROM contract WHERE id = v_id;
      RETURN FOUND AND k.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(k.company_id, k.person_id, k.owner_id);
    WHEN 'price_exception' THEN
      RETURN crm_sees_all_contracts()
          OR coalesce((SELECT requested_by FROM price_exception WHERE id = p_record),
                      audit_diff_value(p_diff, 'requested_by')::uuid) = crm_active_user_id();
    WHEN 'approval_request' THEN
      SELECT * INTO a FROM approval_request WHERE id = p_record;
      RETURN FOUND AND a.org_id = ANY (crm_user_orgs())
         AND (a.requested_by = crm_active_user_id() OR a.from_owner_id = crm_active_user_id()
              OR (a.kind = 'pridelenie_firmy' AND crm_approves_assignments())
              OR (a.kind <> 'pridelenie_firmy' AND crm_approves_prices()));
    WHEN 'offer', 'offer_variant', 'offer_item' THEN
      -- ponuka: podľa obchodu (0036)
      v_id := CASE p_table
                WHEN 'offer' THEN coalesce((SELECT deal_id FROM offer WHERE id = p_record), audit_diff_value(p_diff, 'deal_id')::uuid)
                WHEN 'offer_variant' THEN (SELECT o.deal_id FROM offer o
                                            WHERE o.id = coalesce((SELECT offer_id FROM offer_variant WHERE id = p_record),
                                                                  audit_diff_value(p_diff, 'offer_id')::uuid))
                ELSE (SELECT o.deal_id FROM offer_variant v JOIN offer o ON o.id = v.offer_id
                       WHERE v.id = coalesce((SELECT variant_id FROM offer_item WHERE id = p_record),
                                             audit_diff_value(p_diff, 'variant_id')::uuid)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'approval_price_item' THEN
      RETURN audit_row_visible('approval_request',
                               coalesce((SELECT approval_id FROM approval_price_item WHERE id = p_record),
                                        audit_diff_value(p_diff, 'approval_id')::uuid), NULL);
    WHEN 'user_commission_rate' THEN
      RETURN crm_approves_prices()
          OR coalesce((SELECT user_id FROM user_commission_rate WHERE id = p_record),
                      audit_diff_value(p_diff, 'user_id')::uuid) = crm_active_user_id();
    WHEN 'price_parameter', 'market_price_daily' THEN
      RETURN crm_approves_prices() OR crm_can_see_margin();   -- kto smie čítať cenové parametre a trhové ceny (0023)
    ELSE
      RETURN false;   -- Nastavenia, používatelia, tímy, cenníky, importy: iba admin
  END CASE;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;     -- poškodené id v obsahu zmeny: radšej skryť
END;
$$;

CREATE OR REPLACE FUNCTION offer_reprice(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny'
     AND id IN (SELECT a.approval_id FROM approval_price_item a JOIN offer_variant x ON x.id = a.variant_id WHERE x.offer_id = o.id);
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;

CREATE OR REPLACE FUNCTION offer_new_version(p_offer uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
BEGIN
  IF o.status IN ('koncept', 'caka_na_schvalenie', 'pripravena') THEN
    RAISE EXCEPTION 'Rozpracovanú ponuku upravte priamo (alebo prepočítajte na dnešné ceny).' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status IN ('akceptovana', 'nahradena') THEN
    RAISE EXCEPTION 'Z akceptovanej alebo nahradenej verzie sa nová verzia nerobí.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE org_id = o.org_id AND number = o.number
                                   AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) THEN
    RAISE EXCEPTION 'Rozpracovaná verzia už existuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT closed_at FROM deal WHERE id = o.deal_id) IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať novú verziu ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, language, contact_id, priced_on, seller_type,
                     custom, created_by)
  SELECT o.deal_id, o.org_id, o.number, (SELECT max(version) + 1 FROM offer WHERE org_id = o.org_id AND number = o.number),
         o.kind, o.household, 'koncept', o.language, o.contact_id, crm_today(),
         coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik'),
         o.custom, crm_current_user_id()
  RETURNING * INTO n;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                               flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                               negative_price_compensation)
    VALUES (n.id, n.org_id, v.sort_order, v.name, v.price_kind, v.supply_from, v.supply_to, v.viwa_package,
            v.flexibility_pct, v.planned_volume_mwh, v.invoice_due_days, v.advance_kind, v.advance_pct, v.advance_due_day,
            v.negative_price_compensation)
    RETURNING id INTO v_new;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_new, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i
     WHERE i.variant_id = v.id AND i.price_model <> 'cennik'
       AND (i.oom_id IS NULL OR EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = n.deal_id AND x.oom_id = i.oom_id))
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia');
  RETURN n.id;
END;
$$;

CREATE OR REPLACE FUNCTION approval_price_detail(p_id uuid) RETURNS TABLE (
  variant_id uuid, variant text, year smallint, price_model price_model, voltage_group text,
  requested_value numeric, threshold_value numeric, approved_value numeric, volume_mwh numeric,
  added_value_requested numeric, portfolio_eur_mwh numeric, margin_requested numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT i.variant_id, chr(64 + v.sort_order) || ' · ' || v.name, i.year, i.price_model, i.voltage_group,
         i.requested_value, i.threshold_value, i.approved_value, i.volume_mwh,
         round((i.requested_value - coalesce(i.approved_value, i.requested_value)) * coalesce(i.volume_mwh, 0), 2),
         CASE WHEN crm_can_see_margin() THEN (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')) END,
         CASE WHEN crm_can_see_margin() AND i.price_model = 'fix' THEN
           round((i.requested_value - (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')))
                 * coalesce(i.volume_mwh, 0), 2) END
    FROM approval_request a
    JOIN approval_price_item i ON i.approval_id = a.id
    JOIN offer_variant v ON v.id = i.variant_id
   WHERE a.id = p_id AND a.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR a.requested_by = crm_active_user_id() OR crm_approves_prices())
   ORDER BY v.sort_order, i.year, i.voltage_group
$$;

CREATE OR REPLACE FUNCTION approval_request_offer(p_offer uuid, p_reason text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o      offer := offer_for_edit(p_offer);
  d      deal;
  c      jsonb;
  n      jsonb;
  v_id   uuid;
  v_user uuid := crm_active_user_id();
  v_appr uuid[];
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena') THEN
    RAISE EXCEPTION 'O schválenie sa žiada pri koncepte ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 THEN
    RAISE EXCEPTION '%', (SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(c->'errors') e) USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(c->'needs') = 0 AND NOT (c->>'risk_needs_approval')::boolean THEN
    RETURN offer_prepare(o.id);
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod žiadosti o schválenie.' USING ERRCODE = 'check_violation';
  END IF;
  v_appr := array_remove(notification_approvers(o.org_id, false), v_user);

  IF jsonb_array_length(c->'needs') > 0 THEN
    UPDATE approval_request SET status = 'zrusena' WHERE offer_id = o.id AND kind = 'vynimka_ceny' AND status = 'caka';
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by)
    VALUES (o.org_id, 'vynimka_ceny', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user)
    RETURNING id INTO v_id;
    FOR n IN SELECT * FROM jsonb_array_elements(c->'needs') LOOP
      INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value, volume_mwh)
      VALUES (v_id, (n->>'variant_id')::uuid, (n->>'year')::smallint, (n->>'price_model')::price_model, n->>'voltage_group',
              (n->>'requested_value')::numeric, coalesce((n->>'threshold_value')::numeric, 0), (n->>'volume_mwh')::numeric);
    END LOOP;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Výnimka z ceny – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'vynimka_ceny', 'approval_id', v_id));
  END IF;

  IF (c->>'risk_needs_approval')::boolean
     AND NOT EXISTS (SELECT 1 FROM approval_request WHERE deal_id = o.deal_id AND kind = 'rizikovy_zakaznik' AND status = 'caka') THEN
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, risk_snapshot)
    VALUES (o.org_id, 'rizikovy_zakaznik', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user, company_risk_snapshot(d.company_id))
    RETURNING id INTO v_id;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Rizikový zákazník – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'rizikovy_zakaznik', 'approval_id', v_id));
  END IF;

  UPDATE offer SET status = 'caka_na_schvalenie' WHERE id = o.id;
  RETURN 'caka_na_schvalenie';
END;
$$;

CREATE OR REPLACE FUNCTION offer_check(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE offer_id = o.id) THEN
    errors := errors || to_jsonb('Ponuka nemá variant.'::text);
  END IF;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    FOR r IN SELECT x.year, x.missing, m.eic FROM offer_variant_values(v.id) x LEFT JOIN oom m ON m.id = x.oom_id
              WHERE x.missing IS NOT NULL ORDER BY x.year, m.eic LOOP
      errors := errors || to_jsonb(format('Variant %s (%s): %s – OOM %s, rok %s', chr(64 + v.sort_order), v.name, r.missing, r.eic, r.year));
    END LOOP;
    FOR r IN SELECT x.year, x.price_model, x.voltage_group,
                    min(CASE WHEN x.price_model = 'spot_minus_pct' THEN x.additive_pct
                             WHEN x.price_model IN ('spot_plus_eur', 'spot_minus_eur') THEN x.additive
                             ELSE least(x.price_vt, coalesce(x.price_nt, x.price_vt)) END) AS requested,
                    min(b.th) AS threshold, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold, 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
  v_risk := CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END;
  -- schválenie rizika platí pre celý obchod 30 dní, kým sa údaje Finstatu nezhoršia (odpoveď 9)
  v_risk_ok := EXISTS (SELECT 1 FROM approval_request a
                        WHERE a.deal_id = d.id AND a.kind = 'rizikovy_zakaznik' AND a.status = 'schvalena'
                          AND (a.valid_until IS NULL OR a.valid_until > now())
                          AND NOT company_risk_worse(a.risk_snapshot, company_risk_snapshot(d.company_id)));
  RETURN jsonb_build_object('errors', errors, 'needs', needs,
                            'risk_needs_approval', coalesce((v_risk->>'needs_approval')::boolean, false) AND NOT v_risk_ok,
                            'risk', v_risk,
                            'fix_stale', o.priced_on < crm_today()
                                         AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
END;
$$;

CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE (
  oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model price_model, kind text,
  price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric,
  months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text,
  exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
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
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
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
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       ucost,
       CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
            WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
            WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
            WHEN kind = 'cennik' THEN 'odhad_portfolia'
            WHEN kind = 'energo' THEN 'energopomoc'
            WHEN kind = 'viwa' THEN 'viwa' END,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            WHEN kind = 'fix' AND ucost IS NULL THEN 'chýba cena pre obchodníka'
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

DROP FUNCTION IF EXISTS offer_accept_apply(uuid, uuid, timestamptz);
CREATE OR REPLACE FUNCTION deal_event_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Udalosti časovej osi sa nemenia ani nemažú.' USING ERRCODE = 'check_violation';
END;
$$;
DROP FUNCTION IF EXISTS offer_check_internal(uuid);
DELETE FROM notification WHERE kind IN ('ponuka_akceptovana', 'ponuka_zablokovana');
ALTER TABLE notification
  DROP CONSTRAINT notification_kind_check,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm',
    'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy'));
DELETE FROM deal_event WHERE kind IN ('ponuka_akceptovana', 'ponuka_zablokovana');
ALTER TABLE deal_event
  DROP CONSTRAINT deal_event_kind_check,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik',
    'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana', 'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost',
    'schvalenie_ziadost', 'schvalenie_rozhodnutie'));
-- výnimky prenesené do novej verzie (iná ponuka ako žiadosť) sa odstránia
DELETE FROM approval_price_item a USING offer_variant v, approval_request r
 WHERE v.id = a.variant_id AND r.id = a.approval_id AND r.offer_id IS DISTINCT FROM v.offer_id;
ALTER TABLE approval_price_item DROP COLUMN scope, DROP COLUMN threshold_source;
DROP FUNCTION IF EXISTS offer_variant_scope(uuid);
DROP FUNCTION IF EXISTS crm_sees_portfolio();
