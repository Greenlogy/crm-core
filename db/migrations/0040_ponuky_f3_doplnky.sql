-- migrate:up

-- 0040_ponuky_f3_doplnky – modul 5, fáza F3: doplnky k 0039 (Peter 15. 10.; 0039 už bola na dev):
-- 1. predvolené práva: funkcie budúcich migrácií nespustí PUBLIC, aplikácia crm_app ich dostane výslovne
--    (Cockpit a iné služby budú mať vlastnú rolu s výslovnými právami);
-- 2. koeficient výmeny VIWA je zmluvná podmienka balíka z programu položky cenníka (modul 3,
--    price_list_item_program.viwa_conversion_factor), nie odhad z aditívu; odhad aditívu ostáva iba na pridanú hodnotu;
-- 3. zmluvnú pokutu smie obchodník zvýšiť; zníženie pod predvolenú hodnotu šablóny (dodávka 50, výkup 30 €/MWh)
--    schvaľuje schvaľovateľ cien spolu s výnimkou z ceny (platí 3 dni).

-- ============================================================================
-- 1. Zmluvná pokuta v žiadosti o výnimku a v kontrole ponuky
-- ============================================================================

ALTER TABLE approval_request ADD COLUMN penalty_eur_mwh numeric(12,2) CHECK (penalty_eur_mwh IS NULL OR penalty_eur_mwh >= 0);
COMMENT ON COLUMN approval_request.penalty_eur_mwh IS 'výnimka z ceny: žiadaná zmluvná pokuta pod predvolenou hodnotou šablóny (schvaľuje sa spolu, platí 3 dni) – 0040';

CREATE OR REPLACE FUNCTION offer_check_internal(p_offer uuid) RETURNS jsonb
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
  v_pen   numeric;
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
  ELSIF o.blocked_by_offer_id IS NOT NULL THEN
    errors := errors || to_jsonb('Verzia je zablokovaná po akceptácii inej verzie – zákazník akceptoval inú verziu. Odblokuje ju vlastník obchodu alebo admin.'::text);
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
  -- zmluvná pokuta pod predvolenou hodnotou šablóny (dodávka 50, výkup 30 €/MWh) → schválenie ako výnimka z ceny (0039)
  v_pen := ((offer_template_for(o.id)).defaults->>'zmluvna_pokuta')::numeric;
  IF o.penalty_eur_mwh IS NOT NULL AND v_pen IS NOT NULL AND o.penalty_eur_mwh < v_pen
     AND NOT EXISTS (SELECT 1 FROM approval_request a
                      WHERE a.offer_id = o.id AND a.kind = 'vynimka_ceny' AND a.status = 'schvalena'
                        AND a.penalty_eur_mwh IS NOT NULL AND a.penalty_eur_mwh <= o.penalty_eur_mwh
                        AND CASE WHEN o.sent_at IS NULL THEN a.valid_until IS NULL OR a.valid_until > now()
                                 ELSE a.valid_until IS NULL OR o.sent_at <= a.valid_until END) THEN
    needs := needs || jsonb_build_object('type', 'pokuta', 'variant_id', NULL, 'variant', NULL, 'year', NULL, 'price_model', NULL,
                                         'voltage_group', NULL, 'requested_value', o.penalty_eur_mwh, 'threshold_value', v_pen,
                                         'threshold_source', 'zmluvna_pokuta', 'volume_mwh', NULL);
  END IF;
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

-- Žiadosť o schválenie: zmluvná pokuta pod predvolenou hodnotou ide do tej istej žiadosti o výnimku
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
      IF n->>'type' = 'pokuta' THEN   -- zmluvná pokuta pod predvolenou hodnotou (0039)
        UPDATE approval_request SET penalty_eur_mwh = (n->>'requested_value')::numeric WHERE id = v_id;
        CONTINUE;
      END IF;
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

-- ============================================================================
-- 2. Koeficient VIWA z programu položky cenníka (zmena odhadu aditívu ho nemení)
-- ============================================================================

CREATE OR REPLACE FUNCTION offer_doc_variants(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  res   jsonb := '[]';
  rows  jsonb;
  vol   numeric;
  viwa  jsonb;
  hh    jsonb;
  coef  numeric;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    -- ročný objem: plánovaný, inak súčet OOM (spotreba alebo výroba)
    SELECT coalesce(v.planned_volume_mwh,
                    sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                             THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                             ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END))
      INTO vol FROM deal_oom x WHERE x.deal_id = o.deal_id;

    -- riadky: OOM s rovnakým produktom, napätím a cenami po rokoch sa zlúčia (počet OOM, súčet objemu)
    WITH it AS (
      SELECT i.oom_id, i.product_id, i.price_model, i.year, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
             i.additive_eur_mwh AS ad, i.additive_pct AS pct,
             coalesce(li.vat_rate, p.vat_rate) AS vat
        FROM offer_item i JOIN product p ON p.id = i.product_id
        LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.oom_id IS NOT NULL
    ),
    per_oom AS (
      SELECT it.oom_id, it.product_id, it.price_model, max(it.vat) AS vat,
             jsonb_agg(jsonb_build_object('year', it.year, 'vt', it.vt, 'nt', it.nt, 'ad', it.ad, 'pct', it.pct)
                       ORDER BY it.year NULLS FIRST) AS prices
        FROM it GROUP BY 1, 2, 3
    ),
    grp AS (
      SELECT po.product_id, oom_voltage_group(m.voltage_level) AS vg, po.price_model, po.prices, max(po.vat) AS vat,
             count(*)::int AS ooms,
             sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                      THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                      ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END) AS vol
        FROM per_oom po
        JOIN oom m ON m.id = po.oom_id
        JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = po.oom_id
       GROUP BY 1, 2, 3, 4
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'product', p.name, 'voltage_group', g.vg, 'oom_count', g.ooms, 'volume_mwh', round(g.vol, 3),
             'price_model', g.price_model, 'vat_rate', g.vat,
             'prices', (SELECT jsonb_agg(jsonb_build_object(
                           'year', (e->>'year')::int,
                           'text', CASE g.price_model
                                     WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num((e->>'pct')::numeric, 2, lang) || ' %'
                                     ELSE offer_fmt_num((e->>'vt')::numeric, 2, lang)
                                          || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric, 2, lang) ELSE '' END
                                          || ' €/MWh' END,
                           'text_vat', CASE WHEN o.household AND g.price_model IN ('fix', 'cennik') AND g.vat IS NOT NULL THEN
                                         offer_fmt_num((e->>'vt')::numeric * (1 + g.vat / 100), 2, lang)
                                         || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric * (1 + g.vat / 100), 2, lang) ELSE '' END
                                         || ' €/MWh' END)
                         ORDER BY (e->>'year')::int NULLS FIRST)
                          FROM jsonb_array_elements(g.prices) e))
             ORDER BY g.vg, p.name), '[]')
      INTO rows
      FROM grp g JOIN product p ON p.id = g.product_id;

    -- VIWA: balík, mesačný poplatok účtu, €/kW za odchýlku, koeficient výmeny – zmluvná podmienka balíka z programu
    -- položky cenníka (modul 3); odhad aditívu balíka slúži iba na pridanú hodnotu a koeficient nemení
    viwa := NULL;
    IF v.price_kind = 'viwa' THEN
      SELECT pr.viwa_conversion_factor INTO coef
        FROM offer_item i JOIN price_list_item_program pr ON pr.item_id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'viwa_ucet';
      SELECT jsonb_build_object(
               'package', upper(v.viwa_package),
               'monthly_fee', (SELECT fee_eur_month FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_ucet'),
               'fee_kw', (SELECT max(fee_kw_eur_month) FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_kw'),
               'coefficient', coef,
               'power_kw', (SELECT sum(coalesce(x.source_power_kw, m.source_power_kw, 0)) FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                             WHERE x.deal_id = o.deal_id))
        INTO viwa;
    END IF;

    -- domácnosť: mesačné poplatky (OM, ZEM, VBattery) a odhad ročných nákladov na komoditu bez DPH a s DPH
    hh := NULL;
    IF o.household THEN
      SELECT jsonb_build_object(
               'fees_month', sum(coalesce(i.fee_eur_month, 0)),
               'cost_year', (SELECT sum(coalesce(c.price_vt_eur_mwh, 0) * coalesce(x.planned_vt_mwh, 0)
                                        + coalesce(c.price_nt_eur_mwh, c.price_vt_eur_mwh, 0) * coalesce(x.planned_nt_mwh, 0))
                               FROM offer_item c JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = c.oom_id
                              WHERE c.variant_id = v.id AND c.slot = 'komodita' AND c.price_model IN ('fix', 'cennik')),
               'vat_rate', max(coalesce(li.vat_rate, p.vat_rate)))
        INTO hh
        FROM offer_item i JOIN product p ON p.id = i.product_id LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id;
      hh := hh || jsonb_build_object('cost_year_total', round((hh->>'cost_year')::numeric + (hh->>'fees_month')::numeric * 12, 2));
    END IF;

    res := res || jsonb_build_object(
      'id', v.id, 'letter', chr(64 + v.sort_order), 'name', v.name, 'label', chr(64 + v.sort_order) || ' · ' || v.name,
      'price_kind', v.price_kind,
      'period', CASE WHEN v.supply_to IS NULL
                     THEN CASE lang WHEN 'sk' THEN 'od ' || offer_fmt_date(v.supply_from, lang) || ' na neurčito'
                                    ELSE 'from ' || offer_fmt_date(v.supply_from, lang) || ', indefinite' END
                     ELSE offer_fmt_date(v.supply_from, lang) || ' – ' || offer_fmt_date(v.supply_to, lang) END,
      'flexibility', CASE WHEN v.flexibility_pct IS NULL THEN CASE lang WHEN 'sk' THEN 'plnej flexibility' ELSE 'full' END
                          ELSE '± ' || offer_fmt_num(v.flexibility_pct, 0, lang) || ' %' END,
      'volume_mwh', round(vol, 3),
      'volume_text', offer_fmt_num(vol, 1, lang),
      'advance', CASE v.advance_kind
                   WHEN 'financna_zabezpeka' THEN CASE lang WHEN 'sk' THEN 'finančnej zábezpeky' ELSE 'a financial guarantee' END
                   ELSE CASE lang WHEN 'sk' THEN offer_fmt_num(v.advance_pct, 0, lang) || ' % z 1/12 plánovaného ročného odberu'
                                  ELSE offer_fmt_num(v.advance_pct, 0, lang) || '% of 1/12 of the planned annual consumption' END END,
      'advance_due', CASE WHEN v.advance_due_day IS NULL THEN NULL
                          WHEN lang = 'sk' THEN v.advance_due_day || '. deň v mesiaci'
                          ELSE 'day ' || v.advance_due_day || ' of the month' END,
      'invoice_due', v.invoice_due_days || CASE lang WHEN 'sk' THEN ' dní' ELSE ' days' END,
      'spot', EXISTS (SELECT 1 FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita'
                        AND i.price_model IN ('spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct'))
              OR v.price_kind = 'spot',
      'negative_price_compensation', v.negative_price_compensation,
      'rows', rows, 'viwa', viwa, 'household', hh);
  END LOOP;
  RETURN res;
END;
$$;

-- ============================================================================
-- 3. Predvolené práva: funkcie, ktoré vytvoria budúce migrácie (vlastník databázy), nespustí PUBLIC; aplikácia
-- crm_app ich dostane výslovne. Interná funkcia v budúcej migrácii: REVOKE EXECUTE … FROM PUBLIC, crm_app.
-- Tabuľky a sekvencie PUBLIC nedostáva (výslovne aj tu). Cockpit a iné služby: vlastná rola s výslovnými právami.
-- ============================================================================

ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO crm_app;
  END IF;
END;
$$;

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM crm_app;
  END IF;
END;
$$;
ALTER DEFAULT PRIVILEGES GRANT EXECUTE ON FUNCTIONS TO PUBLIC;

-- funkcie z 0039 / 0038 v pôvodnom znení
CREATE OR REPLACE FUNCTION offer_doc_variants(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  res   jsonb := '[]';
  rows  jsonb;
  vol   numeric;
  viwa  jsonb;
  hh    jsonb;
  coef  numeric;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    -- ročný objem: plánovaný, inak súčet OOM (spotreba alebo výroba)
    SELECT coalesce(v.planned_volume_mwh,
                    sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                             THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                             ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END))
      INTO vol FROM deal_oom x WHERE x.deal_id = o.deal_id;

    -- riadky: OOM s rovnakým produktom, napätím a cenami po rokoch sa zlúčia (počet OOM, súčet objemu)
    WITH it AS (
      SELECT i.oom_id, i.product_id, i.price_model, i.year, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
             i.additive_eur_mwh AS ad, i.additive_pct AS pct,
             coalesce(li.vat_rate, p.vat_rate) AS vat
        FROM offer_item i JOIN product p ON p.id = i.product_id
        LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.oom_id IS NOT NULL
    ),
    per_oom AS (
      SELECT it.oom_id, it.product_id, it.price_model, max(it.vat) AS vat,
             jsonb_agg(jsonb_build_object('year', it.year, 'vt', it.vt, 'nt', it.nt, 'ad', it.ad, 'pct', it.pct)
                       ORDER BY it.year NULLS FIRST) AS prices
        FROM it GROUP BY 1, 2, 3
    ),
    grp AS (
      SELECT po.product_id, oom_voltage_group(m.voltage_level) AS vg, po.price_model, po.prices, max(po.vat) AS vat,
             count(*)::int AS ooms,
             sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                      THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                      ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END) AS vol
        FROM per_oom po
        JOIN oom m ON m.id = po.oom_id
        JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = po.oom_id
       GROUP BY 1, 2, 3, 4
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'product', p.name, 'voltage_group', g.vg, 'oom_count', g.ooms, 'volume_mwh', round(g.vol, 3),
             'price_model', g.price_model, 'vat_rate', g.vat,
             'prices', (SELECT jsonb_agg(jsonb_build_object(
                           'year', (e->>'year')::int,
                           'text', CASE g.price_model
                                     WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num((e->>'pct')::numeric, 2, lang) || ' %'
                                     ELSE offer_fmt_num((e->>'vt')::numeric, 2, lang)
                                          || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric, 2, lang) ELSE '' END
                                          || ' €/MWh' END,
                           'text_vat', CASE WHEN o.household AND g.price_model IN ('fix', 'cennik') AND g.vat IS NOT NULL THEN
                                         offer_fmt_num((e->>'vt')::numeric * (1 + g.vat / 100), 2, lang)
                                         || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric * (1 + g.vat / 100), 2, lang) ELSE '' END
                                         || ' €/MWh' END)
                         ORDER BY (e->>'year')::int NULLS FIRST)
                          FROM jsonb_array_elements(g.prices) e))
             ORDER BY g.vg, p.name), '[]')
      INTO rows
      FROM grp g JOIN product p ON p.id = g.product_id;

    -- VIWA: balík, mesačný poplatok účtu, €/kW za odchýlku, koeficient výmeny (1 − aditív balíka / 100)
    viwa := NULL;
    IF v.price_kind = 'viwa' THEN
      coef := 1 - contract_param(o.org_id, 'viwa_aditiv_' || v.viwa_package, o.priced_on) / 100;
      SELECT jsonb_build_object(
               'package', upper(v.viwa_package),
               'monthly_fee', (SELECT fee_eur_month FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_ucet'),
               'fee_kw', (SELECT max(fee_kw_eur_month) FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_kw'),
               'coefficient', coef,
               'power_kw', (SELECT sum(coalesce(x.source_power_kw, m.source_power_kw, 0)) FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                             WHERE x.deal_id = o.deal_id))
        INTO viwa;
    END IF;

    -- domácnosť: mesačné poplatky (OM, ZEM, VBattery) a odhad ročných nákladov na komoditu bez DPH a s DPH
    hh := NULL;
    IF o.household THEN
      SELECT jsonb_build_object(
               'fees_month', sum(coalesce(i.fee_eur_month, 0)),
               'cost_year', (SELECT sum(coalesce(c.price_vt_eur_mwh, 0) * coalesce(x.planned_vt_mwh, 0)
                                        + coalesce(c.price_nt_eur_mwh, c.price_vt_eur_mwh, 0) * coalesce(x.planned_nt_mwh, 0))
                               FROM offer_item c JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = c.oom_id
                              WHERE c.variant_id = v.id AND c.slot = 'komodita' AND c.price_model IN ('fix', 'cennik')),
               'vat_rate', max(coalesce(li.vat_rate, p.vat_rate)))
        INTO hh
        FROM offer_item i JOIN product p ON p.id = i.product_id LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id;
      hh := hh || jsonb_build_object('cost_year_total', round((hh->>'cost_year')::numeric + (hh->>'fees_month')::numeric * 12, 2));
    END IF;

    res := res || jsonb_build_object(
      'id', v.id, 'letter', chr(64 + v.sort_order), 'name', v.name, 'label', chr(64 + v.sort_order) || ' · ' || v.name,
      'price_kind', v.price_kind,
      'period', CASE WHEN v.supply_to IS NULL
                     THEN CASE lang WHEN 'sk' THEN 'od ' || offer_fmt_date(v.supply_from, lang) || ' na neurčito'
                                    ELSE 'from ' || offer_fmt_date(v.supply_from, lang) || ', indefinite' END
                     ELSE offer_fmt_date(v.supply_from, lang) || ' – ' || offer_fmt_date(v.supply_to, lang) END,
      'flexibility', CASE WHEN v.flexibility_pct IS NULL THEN CASE lang WHEN 'sk' THEN 'plnej flexibility' ELSE 'full' END
                          ELSE '± ' || offer_fmt_num(v.flexibility_pct, 0, lang) || ' %' END,
      'volume_mwh', round(vol, 3),
      'volume_text', offer_fmt_num(vol, 1, lang),
      'advance', CASE v.advance_kind
                   WHEN 'financna_zabezpeka' THEN CASE lang WHEN 'sk' THEN 'finančnej zábezpeky' ELSE 'a financial guarantee' END
                   ELSE CASE lang WHEN 'sk' THEN offer_fmt_num(v.advance_pct, 0, lang) || ' % z 1/12 plánovaného ročného odberu'
                                  ELSE offer_fmt_num(v.advance_pct, 0, lang) || '% of 1/12 of the planned annual consumption' END END,
      'advance_due', CASE WHEN v.advance_due_day IS NULL THEN NULL
                          WHEN lang = 'sk' THEN v.advance_due_day || '. deň v mesiaci'
                          ELSE 'day ' || v.advance_due_day || ' of the month' END,
      'invoice_due', v.invoice_due_days || CASE lang WHEN 'sk' THEN ' dní' ELSE ' days' END,
      'spot', EXISTS (SELECT 1 FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita'
                        AND i.price_model IN ('spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct'))
              OR v.price_kind = 'spot',
      'negative_price_compensation', v.negative_price_compensation,
      'rows', rows, 'viwa', viwa, 'household', hh);
  END LOOP;
  RETURN res;
END;
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


CREATE OR REPLACE FUNCTION offer_check_internal(p_offer uuid) RETURNS jsonb
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
  ELSIF o.blocked_by_offer_id IS NOT NULL THEN
    errors := errors || to_jsonb('Verzia je zablokovaná po akceptácii inej verzie – zákazník akceptoval inú verziu. Odblokuje ju vlastník obchodu alebo admin.'::text);
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

ALTER TABLE approval_request DROP COLUMN penalty_eur_mwh;
