-- Kontroly modulu Produkty a cenníky, časť 2 (0020): dátum v Europe/Bratislava, cena s DPH, schválená verzia
-- sa nedá zmeniť (ani vlastníkom), kópia, schválenie, nahradenie, ukončenie, kontroly položky a programu,
-- pohľady, práva (obchodník, iná spoločnosť, admin), rola crm_app a minulý dátum, audit.
-- Spúšťa sa iba cez db/test/run.sh (po checks_produkty.sql – rola crm_rls_test, používatelia 011 a 2501).
-- Dátumy sú relatívne k crm_today(), aby testy platili v ktorýkoľvek deň.

-- Testovacie produkty a cenníky (vlastník databázy)
INSERT INTO product (id, org_id, code, name, category, segment, vat_rate, tariff_type, price_models) VALUES
  ('00000000-0000-4000-8000-000000005001', crm_default_org(), 'c_dd', 'C DD', 'dodavka_domacnost', 'domacnost', 19, 'jednotarif', '{cennik,spot_plus_eur}'),
  ('00000000-0000-4000-8000-000000005002', crm_default_org(), 'c_zem', 'C ZEM', 'zem', 'domacnost', 19, 'netyka_sa', '{cennik}'),
  ('00000000-0000-4000-8000-000000005003', crm_default_org(), 'c_vb', 'C VBattery', 'vbattery', 'domacnost', 23, 'netyka_sa', '{cennik}'),
  ('00000000-0000-4000-8000-000000005004', crm_default_org(), 'c_viwa', 'C VIWA', 'viwa', 'firma', 23, 'netyka_sa', '{cennik}'),
  ('00000000-0000-4000-8000-000000005005', crm_default_org(), 'c_fix', 'C FIX', 'dodavka_firma', 'firma', 19, 'netyka_sa', '{fix}'),
  ('00000000-0000-4000-8000-000000005006', crm_default_org(), 'c_old', 'C starý', 'dodavka_domacnost', 'domacnost', 19, 'jednotarif', '{cennik}'),
  ('00000000-0000-4000-8000-000000005007', (SELECT id FROM org WHERE code = 'greenlogy_cz'), 'c_cz', 'C CZ', 'dodavka_domacnost', 'domacnost', 21, 'jednotarif', '{cennik}');
INSERT INTO price_list (id, org_id, code, name, segment) VALUES
  ('00000000-0000-4000-8000-000000005101', crm_default_org(), 'c_domacnosti', 'C Domácnosti', 'domacnost'),
  ('00000000-0000-4000-8000-000000005102', crm_default_org(), 'c_firmy', 'C Firmy', 'firma'),
  ('00000000-0000-4000-8000-000000005103', crm_default_org(), 'c_prazdny', 'C Prázdny', 'domacnost');

CREATE FUNCTION pg_temp.t_item(p_ver uuid, p_prod uuid, p_vt numeric, p_nt numeric, p_oom numeric,
                               p_prog numeric DEFAULT NULL, p_kw numeric DEFAULT NULL) RETURNS uuid
LANGUAGE sql AS $f$
  INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                               fee_program_eur_month, fee_kw_eur_month)
  VALUES (p_ver, p_prod, p_vt, p_nt, p_oom, p_prog, p_kw) RETURNING id
$f$;

-- C1. Dátum v Europe/Bratislava a stav verzie z dátumov
DO $$
BEGIN
  ASSERT crm_local_date('2026-10-13 23:30+00') = '2026-10-14', '23:30 UTC v októbri = nasledujúci deň (CEST)';
  ASSERT crm_local_date('2026-01-13 23:30+00') = '2026-01-14', '23:30 UTC v januári = nasledujúci deň (CET)';
  ASSERT crm_local_date('2026-10-13 21:59+00') = '2026-10-13', '21:59 UTC v októbri = ten istý deň';
  ASSERT crm_today() = crm_local_date(now()), 'crm_today = dnešok v Bratislave';
  -- verzia platná od 14. 10.: o 23:30 UTC 13. 10. je v Bratislave už Platná (podľa UTC by bola Budúca)
  ASSERT price_list_version_state('schvalena', '2026-10-14', NULL, crm_local_date('2026-10-13 23:30+00')) = 'platna',
         'stav podľa Bratislavy';
  ASSERT price_list_version_state('schvalena', '2026-10-14', NULL, ('2026-10-13 23:30+00'::timestamptz AT TIME ZONE 'UTC')::date) = 'buduca',
         'podľa UTC by bola budúca';
  ASSERT price_list_version_state('navrh', '2020-01-01', NULL, '2026-10-13') = 'navrh', 'návrh';
  ASSERT price_list_version_state('schvalena', '2026-01-01', '2026-10-12', '2026-10-13') = 'ukoncena', 'ukončená dátumom';
  ASSERT price_list_version_state('nahradena', '2027-01-01', NULL, '2026-10-13') = 'ukoncena', 'nahradená = ukončená';
  RAISE NOTICE 'OK: dátum a stav verzie v Europe/Bratislava (23:30 UTC = nasledujúci deň)';
END;
$$;

-- C2. Cena s DPH podľa PDF cenníkov 2026
DO $$
BEGIN
  ASSERT price_with_vat(120.7275, 19, 4) = 143.6657, 'DD2 NIE VT';
  ASSERT price_with_vat(116.2426, 19, 4) = 138.3287, 'DD1 NIE VT';
  ASSERT price_with_vat(110.5911, 19, 4) = 131.6034, 'DMP4 NT';
  ASSERT price_with_vat(1.50, 19, 2) = 1.79, 'mesačná platba za OM';
  ASSERT price_with_vat(1.4634, 23, 2) = 1.80, 'VBattery STANDARD';
  ASSERT price_with_vat(3.9024, 23, 2) = 4.80, 'VBattery PREMIUM';
  ASSERT price_with_vat(7.7480, 23, 2) = 9.53, 'VBattery MAX';
  ASSERT price_with_vat(6.90, 23, 2) = 8.49 AND price_with_vat(9.90, 23, 2) = 12.18, 'VIWA Plus, Pro';
  ASSERT price_with_vat(NULL, 19, 4) IS NULL, 'bez ceny';
  RAISE NOTICE 'OK: cena s DPH (€/MWh na 4, mesačne na 2 desatinné miesta) ako v PDF';
END;
$$;

-- C3. Skript naplnenia (vlastník): minulý dátum smie; schválená verzia sa potom nedá zmeniť ani vlastníkom
DO $$
DECLARE
  v0 constant uuid := '00000000-0000-4000-8000-000000005201';
  t  constant date := crm_today();
  i  uuid;
BEGIN
  ASSERT crm_owner_session() AND crm_price_list_writer(), 'testy bežia ako vlastník databázy';
  INSERT INTO price_list_version (id, price_list_id, name, valid_from)
  VALUES (v0, '00000000-0000-4000-8000-000000005101', 'v0', t - 400);
  i := pg_temp.t_item(v0, '00000000-0000-4000-8000-000000005001', 116.2426, NULL, 1.50);
  PERFORM pg_temp.t_item(v0, '00000000-0000-4000-8000-000000005002', NULL, NULL, 1.50);
  PERFORM pg_temp.t_item(v0, '00000000-0000-4000-8000-000000005006', 120.0000, NULL, 1.50);
  ASSERT (SELECT vat_rate FROM price_list_item WHERE id = i) IS NULL, 'v návrhu bez kópie DPH';
  PERFORM price_list_version_approve(v0);
  ASSERT (SELECT status = 'schvalena' AND approved_by IS NULL AND approved_at IS NOT NULL FROM price_list_version WHERE id = v0),
         'schválená skriptom';
  ASSERT (SELECT bool_and(vat_rate = 19) FROM price_list_item WHERE version_id = v0), 'kópia DPH v položkách';
  ASSERT (SELECT state FROM price_list_version_v WHERE id = v0) = 'platna', 'platná';

  BEGIN
    UPDATE price_list_item SET price_vt_eur_mwh = 1 WHERE id = i;
    RAISE EXCEPTION 'CHYBA: cena v schválenej verzii sa dala zmeniť (vlastník)';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM pg_temp.t_item(v0, '00000000-0000-4000-8000-000000005003', NULL, NULL, NULL, 1.4634);
    RAISE EXCEPTION 'CHYBA: položka sa dala pridať do schválenej verzie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM price_list_item WHERE id = i;
    RAISE EXCEPTION 'CHYBA: položka sa dala zmazať zo schválenej verzie';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE price_list_version SET name = 'iný' WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: názov schválenej verzie sa dal zmeniť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE price_list_version SET valid_from = t - 300 WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: účinnosť schválenej verzie sa dala zmeniť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE price_list_version SET status = 'navrh', approved_at = NULL WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: schválená verzia sa dala vrátiť na návrh';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    DELETE FROM price_list_version WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: schválená verzia sa dala zmazať';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    INSERT INTO price_list_version (price_list_id, name, valid_from, status, approved_at)
    VALUES ('00000000-0000-4000-8000-000000005101', 'rovno schválená', t + 900, 'schvalena', now());
    RAISE EXCEPTION 'CHYBA: verzia vznikla rovno schválená';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- „platná do“: iba skrátiť, najskôr ku včerajšku
  BEGIN
    UPDATE price_list_version SET valid_to = t - 2 WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: platnosť sa dala ukončiť do minulosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  UPDATE price_list_version SET valid_to = t + 500 WHERE id = v0;
  BEGIN
    UPDATE price_list_version SET valid_to = t + 600 WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: platnosť sa dala predĺžiť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE price_list_version SET valid_to = NULL WHERE id = v0;
    RAISE EXCEPTION 'CHYBA: ukončenie sa dalo zrušiť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: schválená verzia sa nemení ani vlastníkom (položky, názov, účinnosť, stav, mazanie); platná do iba skrátiť od včera';
END;
$$;

-- C4. Kontroly položky a parametrov programu (Návrh)
DO $$
DECLARE
  d  constant uuid := '00000000-0000-4000-8000-000000005202';
  df constant uuid := '00000000-0000-4000-8000-000000005203';
  i  uuid;
BEGIN
  INSERT INTO price_list_version (id, price_list_id, name, valid_from)
  VALUES (d, '00000000-0000-4000-8000-000000005103', 'kontroly', crm_today() + 1000),
         (df, '00000000-0000-4000-8000-000000005102', 'firmy', crm_today() - 100);
  BEGIN
    PERFORM pg_temp.t_item(d, '00000000-0000-4000-8000-000000005004', NULL, NULL, NULL, 3.90);
    RAISE EXCEPTION 'CHYBA: produkt firmy v cenníku domácností';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM pg_temp.t_item(df, '00000000-0000-4000-8000-000000005005', 100, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: produkt bez modelu cenník';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM pg_temp.t_item(d, '00000000-0000-4000-8000-000000005007', 100, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: produkt inej spoločnosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM pg_temp.t_item(d, '00000000-0000-4000-8000-000000005001', NULL, 90, NULL);
    RAISE EXCEPTION 'CHYBA: NT bez VT';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    PERFORM pg_temp.t_item(d, '00000000-0000-4000-8000-000000005002', NULL, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: položka bez ceny';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  -- programy
  i := pg_temp.t_item(d, '00000000-0000-4000-8000-000000005003', NULL, NULL, NULL, 3.9024);
  INSERT INTO price_list_item_program (item_id, greencar, greencar_kwh_per_voucher, greencar_voucher_eur, greenshare, greenshare_fee_pct)
  VALUES (i, true, 400, 25, true, 7.5);
  BEGIN
    UPDATE price_list_item_program SET viwa_conversion_factor = 0.75 WHERE item_id = i;
    RAISE EXCEPTION 'CHYBA: parametre VIWA pri VBattery';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  i := pg_temp.t_item(d, '00000000-0000-4000-8000-000000005001', 120.7275, NULL, 1.50);
  BEGIN
    INSERT INTO price_list_item_program (item_id, greencar) VALUES (i, true);
    RAISE EXCEPTION 'CHYBA: parametre programu pri dodávke';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  i := pg_temp.t_item(df, '00000000-0000-4000-8000-000000005004', NULL, NULL, NULL, 6.90, 0.20);
  INSERT INTO price_list_item_program (item_id, greencar, greenshare, viwa_conversion_factor, viwa_activation_bonus, viwa_credit_expiry_months)
  VALUES (i, true, true, 0.80, 50, 24);
  PERFORM price_list_version_approve(df);
  BEGIN
    UPDATE price_list_item_program SET viwa_activation_bonus = 99 WHERE item_id = i;
    RAISE EXCEPTION 'CHYBA: parametre programu v schválenej verzii sa dali zmeniť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  ASSERT (SELECT fee_program_with_vat = 8.49 AND fee_kw_with_vat = 0.2460 AND viwa_conversion_factor = 0.80
            FROM price_list_item_v WHERE id = i), 'pohľad položky VIWA Plus';
  -- ukončený produkt nejde pridať
  UPDATE product SET status = 'ukonceny' WHERE code = 'c_old';
  BEGIN
    PERFORM pg_temp.t_item(d, '00000000-0000-4000-8000-000000005006', 100, NULL, NULL);
    RAISE EXCEPTION 'CHYBA: ukončený produkt v návrhu';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: položka (spoločnosť, segment, model cenník, ukončený produkt, NT, cena) a parametre programov';
END;
$$;

-- C5. Admin: kópia, schválenie, nahradenie, minulý dátum, ukončenie, verzia medzi dvoma
GRANT SELECT, INSERT, UPDATE, DELETE ON price_list, price_list_version, price_list_item, price_list_item_program TO crm_rls_test;
GRANT SELECT ON price_list_version_v, price_list_item_v, price_list_current_v, product TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;

DO $$
DECLARE
  v0    constant uuid := '00000000-0000-4000-8000-000000005201';
  t     constant date := crm_today();
  v_peter uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  r     jsonb;
  v_new uuid;
  v_fix uuid;
  v_mid uuid;
  v_past uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', v_peter::text, true);
  ASSERT NOT crm_owner_session() AND crm_price_list_writer(), 'admin, nie vlastník';

  r := price_list_version_copy(v0, '2027', t + 30);
  v_new := (r ->> 'version_id')::uuid;
  ASSERT r -> 'skipped' = '["C starý"]'::jsonb, 'kópia vynechá ukončený produkt: ' || r::text;
  ASSERT (SELECT count(*) FROM price_list_item WHERE version_id = v_new AND vat_rate IS NULL) = 2, 'kópia: 2 položky bez DPH';
  ASSERT (SELECT copied_from_id FROM price_list_version WHERE id = v_new) = v0, 'kópia z v0';
  BEGIN
    PERFORM price_list_version_copy(v0, 'druhý', t + 40);
    RAISE EXCEPTION 'CHYBA: druhý návrh v tom istom cenníku';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  UPDATE price_list_item SET price_vt_eur_mwh = 125.0000 WHERE version_id = v_new
     AND product_id = '00000000-0000-4000-8000-000000005001';
  PERFORM price_list_version_approve(v_new);
  ASSERT (SELECT valid_to FROM price_list_version WHERE id = v0) = t + 29, 'predošlá verzia platí do dňa pred novou';
  ASSERT (SELECT status = 'schvalena' AND approved_by = v_peter FROM price_list_version WHERE id = v_new), 'schválil Peter';
  ASSERT (SELECT bool_and(vat_rate = 19) FROM price_list_item WHERE version_id = v_new), 'kópia DPH';
  ASSERT (SELECT state FROM price_list_version_v WHERE id = v0) = 'platna'
         AND (SELECT state FROM price_list_version_v WHERE id = v_new) = 'buduca', 'platná a budúca';
  ASSERT (SELECT current_version_id = v0 AND future_version_id = v_new AND draft_version_id IS NULL
            FROM price_list_current_v WHERE code = 'c_domacnosti'), 'prehľad cenníkov';

  -- oprava budúceho cenníka: nová verzia s rovnakým dátumom, pôvodná Nahradená
  v_fix := (price_list_version_copy(v_new, '2027 oprava', t + 30) ->> 'version_id')::uuid;
  PERFORM price_list_version_approve(v_fix);
  ASSERT (SELECT status FROM price_list_version WHERE id = v_new) = 'nahradena', 'pôvodná nahradená';
  ASSERT (SELECT state FROM price_list_version_v WHERE id = v_new) = 'ukoncena', 'nahradená sa zobrazí ako ukončená';
  ASSERT (SELECT valid_to FROM price_list_version WHERE id = v0) = t + 29, 'predošlá bez zmeny';
  BEGIN
    UPDATE price_list_version SET valid_to = t + 40 WHERE id = v_new;
    RAISE EXCEPTION 'CHYBA: nahradená verzia sa dala zmeniť';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- minulý dátum: admin nesmie
  v_past := (price_list_version_copy(v_fix, 'spätne', t - 1) ->> 'version_id')::uuid;
  BEGIN
    PERFORM price_list_version_approve(v_past);
    RAISE EXCEPTION 'CHYBA: admin schválil verziu s minulým dátumom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM price_list_version_delete(v_past);
  ASSERT NOT EXISTS (SELECT 1 FROM price_list_version WHERE id = v_past), 'návrh zmazaný';
  BEGIN
    PERFORM price_list_version_delete(v_fix);
    RAISE EXCEPTION 'CHYBA: schválená verzia sa dala zmazať funkciou';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  -- verzia medzi platnou a budúcou: predošlá sa skráti, nová platí do dňa pred budúcou
  v_mid := (price_list_version_copy(v0, 'medzi', t + 10) ->> 'version_id')::uuid;
  PERFORM price_list_version_approve(v_mid);
  ASSERT (SELECT valid_to FROM price_list_version WHERE id = v0) = t + 9, 'v0 do t+9';
  ASSERT (SELECT valid_to FROM price_list_version WHERE id = v_mid) = t + 29, 'medzi do t+29';

  -- ukončenie cenníka bez nástupcu
  BEGIN
    PERFORM price_list_version_close(v_fix, t - 1);
    RAISE EXCEPTION 'CHYBA: ukončenie do minulosti';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  PERFORM price_list_version_close(v_fix, t + 365);
  ASSERT (SELECT valid_to FROM price_list_version WHERE id = v_fix) = t + 365, 'ukončené';

  -- Návrh v cenníku (pre kontrolu práv nižšie)
  PERFORM price_list_version_copy(v_fix, 'rozpracovaný', t + 400);
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;

-- C6. Práva: obchodník a iná spoločnosť (crm_rls_test)
DO $$
DECLARE
  n integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '', true);
  ASSERT (SELECT count(*) FROM price_list) = 0, 'bez používateľa vidí cenníky';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  ASSERT (SELECT count(*) FROM price_list WHERE code LIKE 'c\_%') = 3, 'obchodník vidí cenníky';
  ASSERT NOT EXISTS (SELECT 1 FROM price_list_version WHERE status = 'navrh'), 'obchodník vidí návrh';
  ASSERT EXISTS (SELECT 1 FROM price_list_version WHERE status = 'nahradena'), 'obchodník vidí históriu (nahradená)';
  ASSERT (SELECT count(*) FROM price_list_item i JOIN price_list_version v ON v.id = i.version_id WHERE v.status = 'navrh') = 0,
         'obchodník vidí položky návrhu';
  ASSERT (SELECT draft_version_id IS NULL FROM price_list_current_v WHERE code = 'c_domacnosti'), 'prehľad bez návrhu';
  BEGIN
    INSERT INTO price_list (org_id, code, name, segment) VALUES (crm_default_org(), 'c_obchodnik', 'X', 'firma');
    RAISE EXCEPTION 'CHYBA: obchodník založil cenník';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM price_list_version_copy('00000000-0000-4000-8000-000000005201', 'x', crm_today() + 500);
    RAISE EXCEPTION 'CHYBA: obchodník skopíroval verziu';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE price_list SET name = 'zmena' WHERE code = 'c_domacnosti';
  ASSERT NOT FOUND, 'obchodník zmenil cenník';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000002501', true);
  ASSERT (SELECT count(*) FROM price_list) = 0 AND (SELECT count(*) FROM price_list_item_v) = 0,
         'CZ obchodník vidí SK cenníky';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: kópia, schválenie (uzavretie predošlej, nahradenie, medzi), minulý dátum adminovi nie, ukončenie; práva (obchodník číta schválené aj históriu, nevidí návrh, nezapíše; iná spoločnosť nič)';
END;
$$;

RESET ROLE;

-- C7. Rola crm_app: bez app.user_id nesmie schváliť verziu s minulým dátumom (ani nič iné); s adminom
-- tiež nie minulý dátum; stav verzie nezmení priamo (právo na stĺpec)
DO $$
BEGIN
  INSERT INTO price_list_version (id, price_list_id, name, valid_from)
  VALUES ('00000000-0000-4000-8000-000000005204', '00000000-0000-4000-8000-000000005102', 'minulý', crm_today() - 10);
  PERFORM pg_temp.t_item('00000000-0000-4000-8000-000000005204', '00000000-0000-4000-8000-000000005004', NULL, NULL, NULL, 3.90);
END;
$$;
GRANT crm_app TO CURRENT_USER WITH SET TRUE, INHERIT FALSE;
SET LOCAL ROLE crm_app;

DO $$
BEGIN
  PERFORM set_config('app.user_id', '', true);
  ASSERT NOT crm_owner_session(), 'crm_app nie je vlastník';
  BEGIN
    PERFORM price_list_version_approve('00000000-0000-4000-8000-000000005204');
    RAISE EXCEPTION 'CHYBA: crm_app bez používateľa schválila verziu s minulým dátumom';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')::text, true);
  BEGIN
    PERFORM price_list_version_approve('00000000-0000-4000-8000-000000005204');
    RAISE EXCEPTION 'CHYBA: crm_app s adminom schválila verziu s minulým dátumom';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  BEGIN
    UPDATE price_list_version SET status = 'schvalena', approved_at = now() WHERE id = '00000000-0000-4000-8000-000000005204';
    RAISE EXCEPTION 'CHYBA: crm_app zmenila stav verzie priamo';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  UPDATE price_list_version SET name = 'minulý – premenovaný' WHERE id = '00000000-0000-4000-8000-000000005204';
  ASSERT FOUND, 'crm_app (admin) smie premenovať návrh';
  PERFORM set_config('app.user_id', '', true);
END;
$$;

RESET ROLE;

-- C8. Mazanie cenníka, audit
DO $$
BEGIN
  ASSERT (SELECT status FROM price_list_version WHERE id = '00000000-0000-4000-8000-000000005204') = 'navrh', 'minulý ostal návrh';
  BEGIN
    DELETE FROM price_list WHERE code = 'c_domacnosti';
    RAISE EXCEPTION 'CHYBA: cenník so schválenou verziou sa dal zmazať';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  DELETE FROM price_list WHERE code = 'c_prazdny';    -- iba návrh: zmaže sa aj s ním
  ASSERT NOT EXISTS (SELECT 1 FROM price_list_version WHERE id = '00000000-0000-4000-8000-000000005202'),
         'návrh zmazaný s cenníkom';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'price_list_version' AND action = 'update'
                   AND diff ? 'status' AND changed_by = (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')),
         'audit schválenia';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'price_list_item' AND action = 'insert'), 'audit položky';
  RAISE NOTICE 'OK: crm_app bez používateľa ani s adminom neschváli minulý dátum, stav nezmení priamo; mazanie cenníka; audit';
END;
$$;

-- C9. Náhľad schválenia (0021): nahradenie, uzavretie predošlej, chýbajúce produkty, chyby; nič nemení
DO $$
DECLARE
  t   constant date := crm_today();
  d   uuid := (SELECT v.id FROM price_list_version v JOIN price_list l ON l.id = v.price_list_id
                WHERE l.code = 'c_domacnosti' AND v.status = 'navrh');
  r   jsonb;
  n   bigint := (SELECT count(*) FROM audit_log);
BEGIN
  r := price_list_version_approve_preview(d);
  ASSERT (r ->> 'can_approve')::boolean AND r -> 'supersedes' = 'null'::jsonb AND r -> 'closes' = 'null'::jsonb, 'bez dôsledkov: ' || r::text;
  ASSERT r -> 'missing_products' = '["C starý"]'::jsonb, 'chýbajúci produkt z platnej verzie: ' || r::text;

  UPDATE price_list_version SET valid_from = t + 30 WHERE id = d;   -- dátum budúcej schválenej verzie
  r := price_list_version_approve_preview(d);
  ASSERT r -> 'supersedes' ->> 'name' = '2027 oprava' AND (r ->> 'can_approve')::boolean, 'nahradí budúcu: ' || r::text;

  UPDATE price_list_version SET valid_from = t + 5 WHERE id = d;    -- počas platnej verzie v0, pred „medzi“
  r := price_list_version_approve_preview(d);
  ASSERT r -> 'closes' ->> 'name' = 'v0' AND (r -> 'closes' ->> 'valid_to')::date = t + 4, 'uzavrie v0: ' || r::text;
  ASSERT (r ->> 'valid_to')::date = t + 9, 'nová platí do dňa pred „medzi“: ' || r::text;

  UPDATE price_list_version SET valid_from = t - 400 WHERE id = d;  -- rovnaký dátum ako platná v0 (vlastník smie minulosť)
  r := price_list_version_approve_preview(d);
  ASSERT NOT (r ->> 'can_approve')::boolean AND r -> 'errors' ->> 0 LIKE '%už platí%', 'platnú nenahradí: ' || r::text;

  ASSERT (SELECT count(*) FROM audit_log) = n + 3, 'náhľad nič nezapísal (iba 3 zmeny dátumu v teste)';
  ASSERT (SELECT status FROM price_list_version WHERE name = 'v0' AND price_list_id = '00000000-0000-4000-8000-000000005101') = 'schvalena',
         'náhľad nezmenil verzie';
END;
$$;

SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  r jsonb;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  BEGIN
    PERFORM price_list_version_approve_preview('00000000-0000-4000-8000-000000005204');
    RAISE EXCEPTION 'CHYBA: obchodník videl náhľad schválenia';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')::text, true);
  r := price_list_version_approve_preview('00000000-0000-4000-8000-000000005204');   -- návrh s minulým dátumom
  ASSERT NOT (r ->> 'can_approve')::boolean AND r -> 'errors' ->> 0 LIKE 'Platnosť musí začínať dnes%', 'admin: minulý dátum: ' || r::text;
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: náhľad schválenia (nahradenie, uzavretie predošlej, platnosť do, chýbajúce produkty, chyby; iba admin; nič nemení)';
END;
$$;
RESET ROLE;
