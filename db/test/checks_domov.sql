-- Kontroly modulu 5, fáza F6, krok 2 (0049): hlavný variant ponuky (predvolene prvý, označí ho obchodník, prejde do novej
-- verzie), pridaná hodnota obchodu v prehľadoch (akceptovaný variant → hlavný variant poslednej odoslanej ponuky → odhad;
-- záporná PH ostane), žiadosť o pomoc s ponukou (tím Sales_internal, zvonček a e-mail, časová os), Domov (iba cena pre
-- obchodníka a jej vývoj, môj minimálny aditív a percento provízie). 0050: žiadosť o pomoc iba kto upravuje obchod mimo
-- Sales_internal; kalkulačka FIX – odhad portfólia iba manažér s právom vidieť maržu, ostatní cena pre obchodníka.
-- 0051: bez aktívneho člena Sales_internal žiadosť dostanú admini, v časovej osi komu išla.
-- Spúšťa sa iba cez db/test/run.sh po checks_ceny_spot.sql (pomocné funkcie a používatelia série F, rola crm_rls_test).
-- Vlastné záznamy: obchody …-0000000f0320, 21; OOM …-0000000f0220, 21.

-- ============================================================================
-- Príprava (vlastník databázy)
-- ============================================================================
INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh)
SELECT pg_temp.f_id('oom', n), pg_temp.f_id('f', 2), pg_temp.f_eic(n), 'spotreba', 'pripravovane', 'nn', 40
  FROM generate_series(20, 21) n;
SELECT pg_temp.f_deal(20, 2, 'cenova_ponuka', ARRAY[20, 21]);
UPDATE deal SET estimated_value_eur = 1234.00 WHERE id = pg_temp.f_id('d', 20);

GRANT EXECUTE ON FUNCTION offer_main_variant(uuid), offer_variant_set_main(uuid), deal_value(uuid), deal_help_request(uuid, text),
  trader_prices_home(uuid, date, integer), trader_price_series(uuid, smallint, date, date), my_sales_terms(uuid),
  offer_create(uuid), offer_variant_add(uuid, offer_price_kind, uuid), offer_prepare(uuid),
  offer_mark_sent(uuid, timestamptz, offer_send_channel, text), offer_new_version(uuid), offer_variant_summary(uuid) TO crm_rls_test;

-- ponuka s variantmi A a B (FIX 2027, rôzne ceny), pripravená a odoslaná obchodníkom
CREATE TEMP TABLE h_ids (k text PRIMARY KEY, id uuid);
CREATE TEMP TABLE h_num (k text PRIMARY KEY, n integer);
GRANT SELECT, INSERT ON h_ids, h_num TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid;
  v_b     uuid;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  v_offer := offer_create(pg_temp.f_id('d', 20));
  v_b := offer_variant_add(v_offer, 'fix', NULL);
  INSERT INTO h_ids VALUES ('offer', v_offer), ('a', (SELECT id FROM offer_variant WHERE offer_id = v_offer AND sort_order = 1)), ('b', v_b);
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
SELECT v.id, pg_temp.f_id('oom', n), 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix',
       CASE WHEN v.sort_order = 1 THEN 300 ELSE 350 END
  FROM offer_variant v CROSS JOIN generate_series(20, 21) n
 WHERE v.offer_id = (SELECT id FROM h_ids WHERE k = 'offer')
ON CONFLICT DO NOTHING;
DELETE FROM offer_item i USING offer_variant v
 WHERE v.id = i.variant_id AND v.offer_id = (SELECT id FROM h_ids WHERE k = 'offer') AND i.year IS DISTINCT FROM 2027;

-- ============================================================================
-- H0. Hlavný variant: predvolene prvý; označí ho iba ten, kto smie upravovať obchod; vždy najviac jeden; ide aj pri
--     odoslanej ponuke (bez návratu do konceptu); nová verzia ho preberie
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_offer uuid := (SELECT id FROM h_ids WHERE k = 'offer');
  v_a     uuid := (SELECT id FROM h_ids WHERE k = 'a');
  v_b     uuid := (SELECT id FROM h_ids WHERE k = 'b');
  v_new   uuid;
  r       record;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  ASSERT offer_main_variant(v_offer) = v_a, 'predvolene prvý variant';
  -- pred odoslaním: odhad na obchode
  SELECT * INTO r FROM deal_value(pg_temp.f_id('d', 20));
  ASSERT r.source = 'odhad' AND r.added_value_eur = 1234.00 AND r.variant_id IS NULL, 'odhad: ' || r::text;

  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));                 -- iný obchodník
  BEGIN
    PERFORM offer_variant_set_main(v_b);
    RAISE EXCEPTION 'CHYBA: hlavný variant označil cudzí obchodník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  ASSERT NOT EXISTS (SELECT 1 FROM deal_value(pg_temp.f_id('d', 20))), 'cudzí obchod: bez hodnoty';

  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  PERFORM offer_variant_set_main(v_b);
  PERFORM offer_variant_set_main(v_b);
  ASSERT offer_main_variant(v_offer) = v_b, 'hlavný B';
  PERFORM offer_variant_set_main(v_a);
  ASSERT offer_main_variant(v_offer) = v_a AND (SELECT count(*) FROM offer_variant WHERE offer_id = v_offer AND is_main) = 1, 'jeden hlavný';
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'koncept', 'koncept ostáva';

  PERFORM offer_prepare(v_offer);
  PERFORM offer_mark_sent(v_offer, now(), 'osobne', NULL);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'odoslana', 'odoslaná';

  -- odoslaná ponuka: hlavný variant poslednej odoslanej ponuky
  SELECT * INTO r FROM deal_value(pg_temp.f_id('d', 20));
  ASSERT r.source = 'ponuka' AND r.variant_id = v_a
     AND r.added_value_eur = (SELECT added_value_eur FROM offer_variant_summary(v_a) WHERE year IS NULL), 'PH hlavného variantu A: ' || r::text;
  PERFORM offer_variant_set_main(v_b);
  ASSERT (SELECT status FROM offer WHERE id = v_offer) = 'odoslana', 'odoslaná ponuka sa nevrátila do konceptu';
  SELECT * INTO r FROM deal_value(pg_temp.f_id('d', 20));
  ASSERT r.variant_id = v_b AND r.added_value_eur = (SELECT added_value_eur FROM offer_variant_summary(v_b) WHERE year IS NULL)
     AND r.added_value_eur > (SELECT added_value_eur FROM offer_variant_summary(v_a) WHERE year IS NULL), 'PH hlavného variantu B (nie najvyššieho automaticky)';

  -- nová verzia (koncept) preberie hlavný variant; súčty ostávajú z poslednej odoslanej
  v_new := offer_new_version(v_offer);
  ASSERT (SELECT sort_order FROM offer_variant WHERE id = offer_main_variant(v_new)) = 2
     AND (SELECT count(*) FROM offer_variant WHERE offer_id = v_new AND is_main) = 1, 'nová verzia preberie hlavný variant B';
  ASSERT (SELECT variant_id FROM deal_value(pg_temp.f_id('d', 20))) = v_b, 'koncept novej verzie sa do súčtov nepočíta';
  INSERT INTO h_ids VALUES ('new', v_new), ('new_a', (SELECT id FROM offer_variant WHERE offer_id = v_new AND sort_order = 1));
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: H0 hlavný variant: predvolene prvý, označí iba kto smie upravovať obchod, jeden, aj pri odoslanej ponuke bez návratu do konceptu, nová verzia ho preberie; PH: odhad → hlavný variant odoslanej ponuky';
END;
$$;
RESET ROLE;

-- ============================================================================
-- H1. Akceptovaný variant má prednosť; záporná PH ostane záporná (nie odhad, nie 0)
-- ============================================================================
UPDATE offer_item SET price_vt_eur_mwh = 1 WHERE variant_id = (SELECT id FROM h_ids WHERE k = 'new_a');
UPDATE deal SET accepted_variant_id = (SELECT id FROM h_ids WHERE k = 'new_a') WHERE id = pg_temp.f_id('d', 20);
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r record;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  SELECT * INTO r FROM deal_value(pg_temp.f_id('d', 20));
  ASSERT r.source = 'akceptovany' AND r.variant_id = (SELECT id FROM h_ids WHERE k = 'new_a') AND r.added_value_eur < 0,
         'akceptovaný variant so zápornou PH: ' || r::text;
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: H1 akceptovaný variant má prednosť pred hlavným; záporná PH ostane záporná';
END;
$$;
RESET ROLE;
UPDATE deal SET accepted_variant_id = NULL WHERE id = pg_temp.f_id('d', 20);

-- ============================================================================
-- H2. Žiadosť o pomoc s ponukou: aktívnym členom Sales_internal so spoločnosťou obchodu (nie žiadateľovi), zvonček aj
--     e-mail z crm@, časová os; iba kto upravuje obchod a nie je v Sales_internal (0050); nie opakovane do 10 minút;
--     poznámka najviac 500 znakov
-- ============================================================================
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_n integer;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 20), 'cudzí');
    RAISE EXCEPTION 'CHYBA: pomoc k cudziemu obchodu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 6));                 -- Nákup obchod vidí, ale neupravuje
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 20), 'Nákup');
    RAISE EXCEPTION 'CHYBA: pomoc od používateľa, ktorý obchod neupravuje';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 20), repeat('x', 501));
    RAISE EXCEPTION 'CHYBA: dlhá poznámka';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  v_n := deal_help_request(pg_temp.f_id('d', 20), '  zákazník chce kombináciu FIX a SPOT  ');
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 20), 'znova');
    RAISE EXCEPTION 'CHYBA: opakovaná žiadosť do 10 minút';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- člen Sales_internal (schvaľovateľ obchod vidí aj smie upravovať) o pomoc nežiada – 0050
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 3));
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 20), NULL);
    RAISE EXCEPTION 'CHYBA: žiadosť o pomoc zo Sales_internal';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
  INSERT INTO h_num VALUES ('prijemcovia', v_n);
END;
$$;
RESET ROLE;
DO $$
DECLARE
  v_n   integer := (SELECT n FROM h_num WHERE k = 'prijemcovia');
  v_exp integer := (SELECT count(*) FROM app_user u JOIN team t ON t.id = u.team_id
                     WHERE t.code = 'sales_internal' AND u.status = 'aktivny' AND u.id <> pg_temp.f_id('u', 1)
                       AND EXISTS (SELECT 1 FROM app_user_org x WHERE x.user_id = u.id AND x.org_id = crm_default_org()));
BEGIN
  ASSERT v_n = v_exp AND v_n >= 2, 'počet príjemcov ' || v_n || ' / ' || v_exp;
  ASSERT (SELECT array_agg(DISTINCT user_id ORDER BY user_id) FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 20)
            AND user_id IN (pg_temp.f_id('u', 2), pg_temp.f_id('u', 3), pg_temp.f_id('u', 4), pg_temp.f_id('u', 5), pg_temp.f_id('u', 6)))
         = ARRAY[pg_temp.f_id('u', 2), pg_temp.f_id('u', 3)], 'zvonček iba Sales_internal (admin, schvaľovateľ), nie iný obchodník, Servis, Nákup';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'pomoc_s_ponukou' AND user_id = pg_temp.f_id('u', 1)), 'žiadateľ nie';
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'pomoc_s_ponukou' AND user_id = pg_temp.f_id('u', 2)) = 1, 'raz';
  ASSERT (SELECT count(*) FROM email_outbox WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 20))
         = (SELECT count(*) FROM notification n JOIN app_user u ON u.id = n.user_id
             WHERE n.kind = 'pomoc_s_ponukou' AND n.deal_id = pg_temp.f_id('d', 20) AND u.status = 'aktivny'), 'e-mail z crm@ ku každému upozorneniu';
  ASSERT EXISTS (SELECT 1 FROM notification WHERE kind = 'pomoc_s_ponukou' AND user_id = pg_temp.f_id('u', 2)
                   AND detail = 'Obchodník F žiada o pomoc s ponukou: zákazník chce kombináciu FIX a SPOT'), 'text upozornenia';
  ASSERT (SELECT count(*) FROM deal_event WHERE deal_id = pg_temp.f_id('d', 20) AND kind = 'pomoc_ziadost'
            AND user_id = pg_temp.f_id('u', 1) AND reason = 'zákazník chce kombináciu FIX a SPOT' AND detail->>'komu' = 'sales_internal') = 1,
         'časová os obchodu (komu: Sales_internal, 0051)';
  RAISE NOTICE 'OK: H2 žiadosť o pomoc: Sales_internal zvonček aj e-mail, nie žiadateľ ani iné tímy; časová os; iba kto upravuje obchod mimo Sales_internal; nie do 10 minút znova; poznámka do 500 znakov';
END;
$$;

-- ============================================================================
-- H3. Domov: cena pre obchodníka na 3 roky a jej vývoj – iba cena pre obchodníka (bez BL / PL), iba prihlásený;
--     môj minimálny aditív podľa typu predajcu a moje percento provízie
-- ============================================================================
CREATE TEMP TABLE h_exp AS
SELECT contract_param(crm_default_org(), 'min_aditiv_obchodnik', crm_today()) AS min_o,
       contract_param(crm_default_org(), 'min_aditiv_manazer', crm_today()) AS min_m,
       user_commission_pct(pg_temp.f_id('u', 1)) AS pct1;
GRANT SELECT ON h_exp TO crm_rls_test;
UPDATE app_user SET seller_type = 'manazer' WHERE id = pg_temp.f_id('u', 4);
-- ceny roka 2091 pred 1. 1. 2026 a v budúcnosti (do grafu nepatria)
INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, source) VALUES
  (crm_default_org(), '2025-12-30', 2091, 50, 60, 'historia'),
  (crm_default_org(), crm_today() + 3, 2091, 51, 61, 'rucne');
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r     record;
  v_org uuid := crm_default_org();
  y     integer := extract(year FROM crm_today())::integer;
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  ASSERT (SELECT array_agg(delivery_year ORDER BY delivery_year) FROM trader_prices_home(v_org, crm_today())) = ARRAY[y + 1, y + 2, y + 3]::smallint[],
         'tri nasledujúce roky';
  ASSERT NOT EXISTS (SELECT 1 FROM trader_prices_home(v_org, crm_today()) h WHERE h.trader_price IS DISTINCT FROM trader_price(v_org, h.delivery_year, crm_today())),
         'cena pre obchodníka';
  ASSERT (SELECT array_agg(k ORDER BY k) FROM (SELECT jsonb_object_keys(to_jsonb(h)) k FROM (SELECT * FROM trader_prices_home(v_org, crm_today()) LIMIT 1) h) x)
         = ARRAY['delivery_year', 'price_date', 'trader_price'], 'dlaždice bez BL / PL';
  -- vývoj ceny roka 2091 (séria S): iba platné dni, iba cena pre obchodníka
  ASSERT (SELECT count(*) FROM trader_price_series(v_org, 2091::smallint, '2026-01-01', crm_today())) >= 1, 'vývoj ceny';
  ASSERT NOT EXISTS (SELECT 1 FROM trader_price_series(v_org, 2091::smallint, '2026-01-01', crm_today()) s
                      WHERE s.trader_price IS DISTINCT FROM trader_price(v_org, 2091::smallint, s.on_date)), 'vývoj = cena pre obchodníka';
  ASSERT (SELECT array_agg(k ORDER BY k) FROM (SELECT jsonb_object_keys(to_jsonb(s)) k
            FROM (SELECT * FROM trader_price_series(v_org, 2091::smallint, '2026-01-01', crm_today()) LIMIT 1) s) x) = ARRAY['on_date', 'trader_price'], 'graf bez BL / PL';
  ASSERT NOT EXISTS (SELECT 1 FROM trader_price_series(v_org, 2091::smallint, crm_today() + 1, crm_today() + 30)), 'nie do budúcnosti';
  ASSERT NOT EXISTS (SELECT 1 FROM trader_price_series(v_org, 2091::smallint, '2025-01-01', '2025-12-31')), 'nie pred 1. 1. 2026';
  ASSERT (SELECT min(on_date) >= '2026-01-01' AND max(on_date) <= crm_today()
            FROM trader_price_series(v_org, 2091::smallint, '2025-06-01', crm_today() + 30)), 'široké obdobie orezané na 2026 – dnes';
  SELECT * INTO r FROM my_sales_terms(v_org);
  ASSERT r.seller_type = 'obchodnik' AND r.min_additive_eur_mwh = (SELECT min_o FROM h_exp) AND r.commission_pct = (SELECT pct1 FROM h_exp),
         'obchodník: minimálny aditív a provízia ' || r::text;
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));
  SELECT * INTO r FROM my_sales_terms(v_org);
  ASSERT r.seller_type = 'manazer' AND r.min_additive_eur_mwh = (SELECT min_m FROM h_exp), 'manažér: minimálny aditív manažéra';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 2));
  ASSERT (SELECT seller_type FROM my_sales_terms(v_org)) = 'obchodnik', 'bez typu predajcu = obchodník';
  PERFORM pg_temp.f_as(NULL);
  ASSERT NOT EXISTS (SELECT 1 FROM trader_prices_home(v_org, crm_today())) AND NOT EXISTS (SELECT 1 FROM my_sales_terms(v_org))
     AND NOT EXISTS (SELECT 1 FROM trader_price_series(v_org, 2091::smallint, '2026-01-01', crm_today())), 'bez prihlásenia nič';
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: H3 Domov: cena pre obchodníka na 3 roky a jej vývoj bez BL / PL, iba prihlásený; minimálny aditív podľa typu predajcu, percento provízie';
END;
$$;
RESET ROLE;
UPDATE app_user SET seller_type = 'obchodnik' WHERE id = pg_temp.f_id('u', 4);

-- ============================================================================
-- H4. Kalkulačka FIX (0050): obchodník (interný aj externý) dostane iba cenu pre obchodníka, nikdy odhad portfólia;
--     manažér s právom vidieť maržu firmy odhad portfólia (ako v ponuke); manažér bez tohto práva cenu pre obchodníka
-- ============================================================================
GRANT EXECUTE ON FUNCTION calculator_fix_basis(uuid, date, integer) TO crm_rls_test;
UPDATE app_user SET seller_type = 'manazer' WHERE id IN (pg_temp.c_id(4), pg_temp.f_id('u', 4));   -- schvaľovateľ S (marža), iný obchodník F (bez)
CREATE TEMP TABLE h_port AS
SELECT y::smallint AS delivery_year, (SELECT value FROM contract_market_value(crm_default_org(), y, crm_today(), 'portfolio')) AS portfolio
  FROM generate_series(extract(year FROM crm_today())::integer + 1, extract(year FROM crm_today())::integer + 3) y;
GRANT SELECT ON h_port TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_org uuid := crm_default_org();
  u     uuid;
BEGIN
  ASSERT (SELECT count(*) FROM h_port WHERE portfolio IS NOT NULL) >= 1, 'test potrebuje odhad portfólia (séria Z3: rok 2027)';
  -- obchodník interný (Sales_internal), externý (Sales_external), obchodník F a manažér bez marže: iba cena pre obchodníka
  FOREACH u IN ARRAY ARRAY[pg_temp.c_id(1), pg_temp.c_id(2), pg_temp.f_id('u', 1), pg_temp.f_id('u', 4)] LOOP
    PERFORM pg_temp.f_as(u);
    ASSERT (SELECT count(*) FROM calculator_fix_basis(v_org, crm_today())) = 3, 'tri roky ' || u;
    ASSERT NOT EXISTS (SELECT 1 FROM calculator_fix_basis(v_org, crm_today()) b
                        WHERE b.basis <> 'cena_pre_obchodnika' OR b.basis_eur_mwh IS DISTINCT FROM trader_price(v_org, b.delivery_year, crm_today())),
           'iba cena pre obchodníka ' || u;
    ASSERT NOT EXISTS (SELECT 1 FROM calculator_fix_basis(v_org, crm_today()) b JOIN h_port p USING (delivery_year)
                        WHERE p.portfolio IS NOT NULL AND b.basis_eur_mwh = p.portfolio AND p.portfolio IS DISTINCT FROM trader_price(v_org, b.delivery_year, crm_today())),
           'nikdy odhad portfólia ' || u;
  END LOOP;
  -- manažér s právom vidieť maržu: odhad portfólia ako v ponuke
  PERFORM pg_temp.f_as(pg_temp.c_id(4));
  ASSERT NOT EXISTS (SELECT 1 FROM calculator_fix_basis(v_org, crm_today()) b JOIN h_port p USING (delivery_year)
                      WHERE b.basis <> 'odhad_portfolia' OR b.basis_eur_mwh IS DISTINCT FROM p.portfolio), 'manažér s maržou: odhad portfólia';
  PERFORM pg_temp.f_as(NULL);
  ASSERT NOT EXISTS (SELECT 1 FROM calculator_fix_basis(v_org, crm_today())), 'bez prihlásenia nič';
  INSERT INTO h_num VALUES ('h4', 1);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: H4 kalkulačka FIX: obchodník interný, externý, s maržou aj manažér bez marže iba cena pre obchodníka (nikdy odhad portfólia); manažér s maržou odhad portfólia';
END;
$$;
RESET ROLE;
UPDATE app_user SET seller_type = 'obchodnik' WHERE id = pg_temp.f_id('u', 4);
UPDATE app_user SET seller_type = NULL WHERE id = pg_temp.c_id(4);
-- obchodník (nie manažér) s právom vidieť maržu: tiež iba cena pre obchodníka
UPDATE app_user SET seller_type = 'obchodnik' WHERE id = pg_temp.c_id(4);
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.f_as(pg_temp.c_id(4));
  ASSERT crm_can_see_margin(), 'vidí maržu';
  ASSERT NOT EXISTS (SELECT 1 FROM calculator_fix_basis(crm_default_org(), crm_today()) b
                      WHERE b.basis <> 'cena_pre_obchodnika' OR b.basis_eur_mwh IS DISTINCT FROM trader_price(crm_default_org(), b.delivery_year, crm_today())),
         'obchodník s maržou: iba cena pre obchodníka';
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
UPDATE app_user SET seller_type = NULL WHERE id = pg_temp.c_id(4);

-- ============================================================================
-- H5. Žiadosť o pomoc bez aktívneho člena Sales_internal (0051): dostanú ju aktívni admini so spoločnosťou obchodu
--     (zvonček aj e-mail z crm@, nie žiadateľ); časová os uvedie, komu išla
-- ============================================================================
SELECT pg_temp.f_deal(21, 2, 'cenova_ponuka', ARRAY[]::integer[]);
UPDATE app_user SET team_id = (SELECT id FROM team WHERE code = 'servis')
 WHERE team_id = (SELECT id FROM team WHERE code = 'sales_internal');
UPDATE app_user SET team_id = (SELECT id FROM team WHERE code = 'ceo') WHERE id = pg_temp.f_id('u', 2);   -- admin F upravuje obchody
CREATE TEMP TABLE h_admins AS
SELECT u.id FROM app_user u
 WHERE u.is_admin AND u.status = 'aktivny' AND u.id <> pg_temp.f_id('u', 1) AND crm_user_sees_org(u.id, crm_default_org());
GRANT SELECT ON h_admins TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  ASSERT deal_help_request(pg_temp.f_id('d', 21), 'nikto v tíme') = (SELECT count(*) FROM h_admins), 'počet adminov';
  -- žiada admin (mimo Sales_internal): sám sebe nie
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 2));
  BEGIN
    PERFORM deal_help_request(pg_temp.f_id('d', 21), 'admin');
  EXCEPTION WHEN check_violation THEN NULL;                -- iný aktívny admin nemusí existovať
  END;
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM h_admins) >= 1 AND pg_temp.f_id('u', 2) IN (SELECT id FROM h_admins), 'test potrebuje admina F';
  ASSERT (SELECT array_agg(DISTINCT user_id ORDER BY user_id) FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21))
         = (SELECT array_agg(id ORDER BY id) FROM h_admins), 'zvonček adminom';
  ASSERT (SELECT count(*) FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21) AND user_id = pg_temp.f_id('u', 2)) = 1,
         'admin žiadateľ sám sebe nie';
  ASSERT NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21)
                      AND user_id IN (pg_temp.f_id('u', 1), pg_temp.f_id('u', 3))), 'nie žiadateľ ani schvaľovateľ bez admina';
  ASSERT (SELECT count(*) FROM email_outbox WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21))
         = (SELECT count(*) FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21)), 'e-mail z crm@ ku každému upozorneniu';
  ASSERT (SELECT detail FROM notification WHERE kind = 'pomoc_s_ponukou' AND deal_id = pg_temp.f_id('d', 21) AND user_id = pg_temp.f_id('u', 2) LIMIT 1)
         = 'Obchodník F žiada o pomoc s ponukou (v tíme Sales_internal nie je nikto aktívny): nikto v tíme', 'text';
  ASSERT (SELECT detail FROM deal_event WHERE deal_id = pg_temp.f_id('d', 21) AND kind = 'pomoc_ziadost' AND user_id = pg_temp.f_id('u', 1))
         = jsonb_build_object('prijemcovia', (SELECT count(*) FROM h_admins), 'komu', 'admini'), 'časová os: komu išla';
  RAISE NOTICE 'OK: H5 žiadosť o pomoc bez aktívneho člena Sales_internal: admini (zvonček aj e-mail, nie žiadateľ), v časovej osi komu išla';
END;
$$;

-- ============================================================================
-- H6. Uložená pridaná hodnota obchodu (0052): po každej zmene rovnaká ako priamy výpočet – odhad, odoslanie, hlavný
--     variant, nová verzia, akceptácia a jej zrušenie, objem OOM na obchode; nočná poistka opraví rozdiel a zapíše ho;
--     aplikácia uloženú hodnotu iba číta (RLS obchodu); jadro výpočtu nie je pre aplikáciu
-- ============================================================================
CREATE FUNCTION pg_temp.h_same() RETURNS integer LANGUAGE sql AS $f$
  SELECT count(*)::int FROM deal d
    LEFT JOIN deal_value_cache c ON c.deal_id = d.id
    LEFT JOIN LATERAL deal_value_compute(d.id) x ON true
   WHERE c.deal_id IS NULL OR (c.value_eur, c.source, c.variant_id) IS DISTINCT FROM (x.added_value_eur, x.source, x.variant_id)
$f$;
DO $$
DECLARE
  v_deal uuid := pg_temp.f_id('d', 20);
  v_b    uuid := (SELECT id FROM h_ids WHERE k = 'b');
  v_a    uuid := (SELECT id FROM h_ids WHERE k = 'a');
  r      jsonb;
BEGIN
  ASSERT pg_temp.h_same() = 0, 'všetky obchody: uložená PH = výpočet (' || pg_temp.h_same() || ')';
  -- po H0–H5: hlavný variant B odoslanej ponuky
  ASSERT (SELECT (source, variant_id) FROM deal_value_cache WHERE deal_id = v_deal) = ROW('ponuka'::text, v_b), 'hlavný variant B';
  -- zmena objemu OOM na obchode zmení PH odoslanej ponuky
  UPDATE deal_oom SET planned_vt_mwh = 77 WHERE deal_id = v_deal AND oom_id = pg_temp.f_id('oom', 20);
  ASSERT (SELECT value_eur FROM deal_value_cache WHERE deal_id = v_deal) = (SELECT sum(added_value_eur) FROM offer_variant_values_core(v_b))
     AND pg_temp.h_same() = 0, 'objem OOM';
  -- hlavný variant A
  UPDATE offer_variant SET is_main = false WHERE id = v_b;
  ASSERT (SELECT variant_id FROM deal_value_cache WHERE deal_id = v_deal) = v_a, 'hlavný variant A (prvý)';
  -- akceptácia a jej zrušenie
  UPDATE deal SET accepted_variant_id = v_b WHERE id = v_deal;
  ASSERT (SELECT (source, variant_id) FROM deal_value_cache WHERE deal_id = v_deal) = ROW('akceptovany'::text, v_b), 'akceptovaný';
  UPDATE deal SET accepted_variant_id = NULL WHERE id = v_deal;
  ASSERT (SELECT source FROM deal_value_cache WHERE deal_id = v_deal) = 'ponuka', 'po zrušení akceptácie ponuka';
  -- obchod bez ponuky: odhad a jeho zmena
  UPDATE deal SET estimated_value_eur = 4321 WHERE id = pg_temp.f_id('d', 21);
  ASSERT (SELECT (value_eur, source) FROM deal_value_cache WHERE deal_id = pg_temp.f_id('d', 21)) = ROW(4321.00::numeric, 'odhad'::text), 'odhad';
  ASSERT pg_temp.h_same() = 0, 'po zmenách všetky rovnaké';

  -- nočná poistka: pokazená uložená hodnota sa opraví a rozdiel sa zapíše k dnešnému behu obchodov
  UPDATE deal_value_cache SET value_eur = value_eur + 1 WHERE deal_id = v_deal;
  PERFORM set_config('app.user_id', '', true);
  PERFORM deal_daily_run_at(crm_today());
  r := deal_value_daily();
  ASSERT (r->>'ph_rozdiel')::int = 1 AND (r->>'ph_prepocitane')::int = (SELECT count(*) FROM deal), 'poistka: ' || r::text;
  ASSERT pg_temp.h_same() = 0, 'opravené';
  ASSERT (SELECT result->>'ph_rozdiel' FROM job_run WHERE job = 'obchody' AND run_date = crm_today() ORDER BY started_at DESC LIMIT 1) = '1', 'v denníku';
  RAISE NOTICE 'OK: H6 uložená PH = výpočet po každej zmene (odhad, odoslanie, hlavný variant, akceptácia a zrušenie, objem OOM); nočná poistka opraví a zapíše rozdiel';
END;
$$;
GRANT SELECT ON deal_value_cache TO crm_rls_test;
GRANT EXECUTE ON FUNCTION deal_value_daily() TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 1));
  ASSERT EXISTS (SELECT 1 FROM deal_value_cache WHERE deal_id = pg_temp.f_id('d', 20)), 'vlastník vidí PH obchodu';
  ASSERT (SELECT added_value_eur FROM deal_value(pg_temp.f_id('d', 20))) = (SELECT value_eur FROM deal_value_cache WHERE deal_id = pg_temp.f_id('d', 20)),
         'deal_value = uložená';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 4));
  ASSERT NOT EXISTS (SELECT 1 FROM deal_value_cache WHERE deal_id = pg_temp.f_id('d', 20)), 'cudzí obchodník nevidí';
  PERFORM pg_temp.f_as(pg_temp.f_id('u', 2));                -- ani admin nespustí nočnú poistku
  BEGIN
    PERFORM deal_value_daily();
    RAISE EXCEPTION 'CHYBA: nočnú poistku PH spustil prihlásený používateľ';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.f_as(NULL);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ASSERT NOT has_function_privilege('crm_app', 'offer_variant_values_core(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('crm_app', 'deal_value_refresh(uuid)', 'EXECUTE')
       AND NOT has_function_privilege('crm_app', 'deal_value_compute(uuid)', 'EXECUTE'), 'interné funkcie';
    ASSERT has_function_privilege('crm_app', 'deal_value_daily()', 'EXECUTE')
       AND NOT has_table_privilege('crm_app', 'deal_value_cache', 'INSERT') AND NOT has_table_privilege('crm_app', 'deal_value_cache', 'UPDATE'),
           'aplikácia PH iba číta (app-role.sql)';
  END IF;
  RAISE NOTICE 'OK: H6 práva: PH obchodu podľa RLS obchodu, aplikácia iba číta, jadro výpočtu interné';
END;
$$;
