-- Kontroly importu zmlúv z Office portálu a OOM z XM Trade (0026): náhľad a uloženie, nový zákazník (firma aj domácnosť)
-- s príznakom „založený importom“ a vlastníkom = obchodník (doplnok b), výber ceny 1T/2T podľa produktu OOM, mesačná
-- platba za OM, cenník domácností so ZEM, VBattery (produkt DD a regulácia z XM Trade), výkup na neurčito, VIWA bez
-- balíka a balík zadaný v CRM (otázka 20), opakovaný import = bez zmeny (doplnok c), prázdna bunka neprepíše hodnotu
-- v CRM (doplnok a), chyby (preklady, OOM mimo CRM, dve ceny, 1T/2T, prekrytie), účinnosť domácnosti z XM Trade
-- dodatočne, zmena regulácie s „platí od“ dnes (otázka 19), RLS „iba svoje“, príznak „založený importom“ po úprave.
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy.sql. Predpoklad: skripty db/seed/cenniky-2026.sh
-- a db/seed/podnikatelia-2026.sh (produkty, cenníky 2026, preklady produktov). Hodnoty cien sa porovnávajú s položkami
-- cenníkov, nie s pevnými číslami. Import beží ako používateľ Servisu (6001), RLS ako obchodník „iba svoje“ (6002).

DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM product WHERE code = 'green_dd2_ano') AND EXISTS (SELECT 1 FROM price_list WHERE code = 'poplatky_b2b')
     AND (import_alias_resolve(crm_default_org(), 'office_portal', 'produkt_oom', 'IN GREEN 1T')).target = 'green_1t',
         'testy importu potrebujú skripty db/seed/cenniky-2026.sh a db/seed/podnikatelia-2026.sh';
END;
$$;

-- Servis Z2 (import zmlúv aj OOM), obchodník Z2 v tíme „iba svoje“ (zákazníci, OOM, zmluvy), preklad mena obchodníka
INSERT INTO team (id, code, name) VALUES ('00000000-0000-4000-8000-000000006900', 'test_z2', 'Test Z2 iba svoje');
UPDATE team_permission SET view_scope = 'iba_svoje', edit_scope = 'iba_svoje', can_import = false   -- riadky založí spúšťač tímu
 WHERE team_id = '00000000-0000-4000-8000-000000006900' AND module IN ('zakaznici', 'odberne_miesta', 'zmluvy');
INSERT INTO app_user (id, email, name, team_id, status)
SELECT '00000000-0000-4000-8000-000000006001', 'servis.z2@example.test', 'Servis Z2', t.id, 'aktivny' FROM team t WHERE t.code = 'servis';
INSERT INTO app_user (id, email, name, team_id, status)
VALUES ('00000000-0000-4000-8000-000000006002', 'obchodnik.z2@example.test', 'Obchodník Z2', '00000000-0000-4000-8000-000000006900', 'aktivny');
INSERT INTO app_user_org (user_id, org_id) VALUES
  ('00000000-0000-4000-8000-000000006001', crm_default_org()), ('00000000-0000-4000-8000-000000006002', crm_default_org());
INSERT INTO import_alias (org_id, source, kind, name_sample, target)
VALUES (crm_default_org(), 'office_portal', 'obchodnik', 'Obchodník Import Z2', '00000000-0000-4000-8000-000000006002');

CREATE FUNCTION pg_temp.z2_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000IMPT' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000IMPT' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
-- Riadok Office portálu (ako ho pripraví API): predvolene firma Gama Z2, podpísaná, 1. 3. – 31. 12. 2026
CREATE FUNCTION pg_temp.z2_op(p_row integer, p_number text, p_eic integer, p_x jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object(
    'row', p_row, 'op_id', md5('z2-' || p_number)::uuid, 'number', p_number, 'test', false, 'phase', 'Finálne podpísaná',
    'commodity', 'Elektrina', 'household', false, 'ico', '99999921', 'company_name', 'Gama Z2 s.r.o.',
    'person_op_id', md5('z2-osoba-gama')::uuid, 'eic', pg_temp.z2_eic(p_eic), 'qty_vt_mwh', 10, 'qty_nt_mwh', 0,
    'small_business', false, 'list_price', false, 'auto_prolong', true, 'valid_from', '2026-03-01', 'valid_to', '2026-12-31',
    'signed_on', '2026-02-01', 'created_by_name', 'Tvorca Z2', 'owner_name', 'Obchodník Import Z2',
    'updated_at', '2026-05-07T10:00:00Z', 'parse_errors', '[]'::jsonb) || p_x
$f$;
-- Riadok XM Trade (ako ho pripraví API): OOM na NN v ZSD, začiatok dodávky 1. 10. 2026
CREATE FUNCTION pg_temp.z2_xm(p_row integer, p_eic integer, p_number text, p_x jsonb DEFAULT '{}') RETURNS jsonb LANGUAGE sql AS $f$
  SELECT jsonb_build_object(
    'row', p_row, 'eic', pg_temp.z2_eic(p_eic), 'contract_number', p_number, 'supply_from', '2026-10-01',
    'direction', 'Odber (-)', 'product', '', 'regulation', '', 'tariff', '',
    'fields', jsonb_build_object('pds', 'Západoslovenská distribučná (24X-ZSE-PDS----5)', 'voltage_level', 'nn',
                                 'supply_from', '2026-10-01'),
    'parse_errors', '[]'::jsonb) || p_x
$f$;
-- Náhľad a (voliteľne) uloženie s počtami z náhľadu
CREATE FUNCTION pg_temp.z2_run(p_xm jsonb, p_op jsonb, p_save boolean DEFAULT true) RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE
  v jsonb;
BEGIN
  v := contract_import_run(crm_default_org(), p_xm, p_op, false, '{"op_file_name": "z2-op.xlsx", "xm_file_name": "z2-xm.xlsx"}');
  IF p_save THEN
    v := contract_import_run(crm_default_org(), p_xm, p_op, true, '{"op_file_name": "z2-op.xlsx", "xm_file_name": "z2-xm.xlsx"}',
                             v -> 'counts');
  END IF;
  RETURN v;
END;
$f$;
CREATE FUNCTION pg_temp.z2_c(p jsonb, p_number text) RETURNS jsonb LANGUAGE sql AS $f$
  SELECT x FROM jsonb_array_elements(p -> 'contracts') x WHERE x ->> 'number' = p_number LIMIT 1
$f$;
CREATE FUNCTION pg_temp.z2_k(p_number text) RETURNS contract LANGUAGE sql AS $f$
  SELECT * FROM contract WHERE number = p_number
$f$;
-- Položka schválenej verzie cenníka s produktom platná k dátumu
CREATE FUNCTION pg_temp.z2_item(p_list text, p_product text, p_on date) RETURNS price_list_item LANGUAGE sql AS $f$
  SELECT i.* FROM price_list_item i JOIN price_list_version v ON v.id = i.version_id JOIN price_list l ON l.id = v.price_list_id
    JOIN product p ON p.id = i.product_id
   WHERE l.code = p_list AND p.code = p_product AND v.status = 'schvalena' AND v.valid_from <= p_on
     AND (v.valid_to IS NULL OR v.valid_to >= p_on)
$f$;

SELECT set_config('app.user_id', '00000000-0000-4000-8000-000000006001', true),
       set_config('app.require_user', 'on', true);

-- Z2-1. Nová firma, OOM z XM Trade v tom istom behu, individuálne ceny 1T/2T podľa produktu OOM, platba za OM
DO $$
DECLARE
  v_xm  jsonb := jsonb_build_array(
                   pg_temp.z2_xm(2, 1, '1120269001', '{"ico": "99999921"}'), pg_temp.z2_xm(3, 2, '1120269001', '{"ico": "99999921"}'));
  v_op  jsonb;
  v     jsonb;
  k     contract;
  c     company;
  i     price_list_item;
BEGIN
  v_op := jsonb_build_array(
    pg_temp.z2_op(2, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
    pg_temp.z2_op(3, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'),
    pg_temp.z2_op(4, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
    pg_temp.z2_op(5, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'));

  -- náhľad nič neuloží
  v := pg_temp.z2_run(v_xm, v_op, false);
  ASSERT v #>> '{counts,zmluvy,nova}' = '1' AND v #>> '{counts,oom,nove}' = '2', 'náhľad: 1 nová zmluva, 2 nové OOM; ' || (v -> 'counts')::text;
  ASSERT NOT EXISTS (SELECT 1 FROM company WHERE ico = '99999921') AND pg_temp.z2_k('1120269001') IS NULL,
         'náhľad nič neuložil';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_import WHERE op_file_name = 'z2-op.xlsx'), 'náhľad nezapísal import';

  v := pg_temp.z2_run(v_xm, v_op);
  ASSERT v ->> 'import_id' IS NOT NULL AND v #>> '{counts,zmluvy,nova}' = '1', 'uložené: ' || coalesce((v -> 'counts')::text, v::text);
  k := pg_temp.z2_k('1120269001');
  SELECT * INTO c FROM company WHERE ico = '99999921';
  ASSERT k.company_id = c.id AND k.type = 'dodavka_firma_nn' AND k.phase = 'podpisana' AND k.valid_from = '2026-03-01'
     AND k.owner_id = '00000000-0000-4000-8000-000000006002' AND k.op_id = md5('z2-1120269001')::uuid
     AND k.op_updated_at = '2026-05-07T10:00:00Z' AND k.created_by_name = 'Tvorca Z2', 'zmluva firmy';
  ASSERT c.created_by_import = (v ->> 'import_id')::uuid AND c.owner_id = '00000000-0000-4000-8000-000000006002'
     AND c.op_person_id = md5('z2-osoba-gama')::uuid, 'firma založená importom, vlastník = obchodník zo zmluvy (doplnok b)';
  ASSERT (SELECT count(*) FROM oom WHERE eic IN (pg_temp.z2_eic(1), pg_temp.z2_eic(2)) AND company_id = c.id
            AND status = 'pripravovane' AND pds = 'zsd') = 2, 'OOM z XM Trade založené pre firmu zo zmluvy';
  ASSERT (SELECT count(*) FROM contract_oom co JOIN product p ON p.id = co.product_id
           WHERE co.contract_id = k.id AND ((p.code = 'green_1t' AND co.qty_vt_mwh = 10 AND co.qty_nt_mwh = 0)
                                         OR (p.code = 'green_2t' AND co.qty_vt_mwh = 5 AND co.qty_nt_mwh = 3))) = 2,
         'OOM v zmluve: produkt a množstvo';
  -- OOM 1 (1T): FIX 120 od účinnosti; OOM 2 (2T): FIX 130/110
  ASSERT (SELECT count(*) FROM contract_price p JOIN oom o ON o.id = p.oom_id
           WHERE p.contract_id = k.id AND p.slot = 'komodita' AND p.price_model = 'fix' AND p.source = 'import'
             AND p.valid_from = '2026-03-01' AND p.valid_to = '2026-12-31'
             AND ((o.eic = pg_temp.z2_eic(1) AND p.price_vt_eur_mwh = 120 AND p.price_nt_eur_mwh IS NULL
                   AND p.op_product_name = 'GREEN_1T_INDIVIDUAL_2026')
               OR (o.eic = pg_temp.z2_eic(2) AND p.price_vt_eur_mwh = 130 AND p.price_nt_eur_mwh = 110))) = 2
     AND (SELECT count(*) FROM contract_price WHERE contract_id = k.id AND slot = 'komodita') = 2,
         'cena 1T/2T podľa produktu OOM (rozhodnutie 2), orezaná na účinnosť';
  i := pg_temp.z2_item('poplatky_b2b', 'poplatok_om_firmy', '2026-03-01');
  ASSERT (SELECT count(*) FROM contract_price WHERE contract_id = k.id AND slot = 'poplatok_om' AND price_model = 'cennik'
            AND price_list_item_id = i.id AND fee_eur_month = i.fee_oom_eur_month AND valid_from = '2026-03-01') = 2,
         'mesačná platba za OM z cenníka Poplatky B2B pri každom OOM';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND resolved_at IS NULL AND year IS NULL),
         'bez príznakov importu (príznaky snímky ku dňu podpisu s rokom testuje Z3)';
  ASSERT (SELECT action = 'nova' AND summary LIKE 'Nová zmluva%' FROM contract_import_change
           WHERE contract_id = k.id AND import_id = (v ->> 'import_id')::uuid), 'história importu na zmluve';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'contract' AND record_id = k.id AND action = 'insert'
                    AND source = 'import' AND contract_import_id = (v ->> 'import_id')::uuid), 'audit so zdrojom import';
  RAISE NOTICE 'OK: Z2-1 náhľad nič neuloží; nová firma a OOM z XM Trade v jednom behu, vlastník = obchodník, ceny 1T/2T podľa produktu OOM orezané na účinnosť, platba za OM z Poplatkov B2B, história a audit importu';
END;
$$;

-- Z2-2. Opakovaný import toho istého súboru = všetko „bez zmeny“ (doplnok c); novší čas zmeny bez zmeny údajov tiež
DO $$
DECLARE
  v_xm jsonb := jsonb_build_array(
                  pg_temp.z2_xm(2, 1, '1120269001', '{"ico": "99999921"}'), pg_temp.z2_xm(3, 2, '1120269001', '{"ico": "99999921"}'));
  v_op jsonb;
  v    jsonb;
  n    integer := (SELECT count(*) FROM audit_log);
BEGIN
  v_op := jsonb_build_array(
    pg_temp.z2_op(2, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
    pg_temp.z2_op(3, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'),
    pg_temp.z2_op(4, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
    pg_temp.z2_op(5, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'));
  v := pg_temp.z2_run(v_xm, v_op);
  ASSERT v #>> '{counts,zmluvy,bez_zmeny}' = '1' AND v #>> '{counts,zmluvy,nova}' = '0' AND v #>> '{counts,zmluvy,zmena}' = '0'
     AND v #>> '{counts,oom,bez_zmeny}' = '2' AND v #>> '{counts,oom,zmena}' = '0' AND (v ->> 'nothing')::boolean,
         'rovnaký súbor = bez zmeny; ' || v::text;
  -- novší čas zmeny v Office portáli, údaje rovnaké → spracuje sa, ale nič sa nezmení (okrem času zmeny)
  SELECT jsonb_agg(x || '{"updated_at": "2026-06-01T08:00:00Z"}') INTO v_op FROM jsonb_array_elements(v_op) x;
  v := pg_temp.z2_run('[]', v_op, false);
  ASSERT v #>> '{counts,zmluvy,bez_zmeny}' = '1', 'novší čas bez zmeny údajov = bez zmeny; ' || (v -> 'counts')::text;
  ASSERT (SELECT count(*) FROM audit_log) = n, 'opakovaný import nič nezapísal';
  RAISE NOTICE 'OK: Z2-2 opakovaný import toho istého súboru = bez zmeny (zmluvy aj OOM), novší čas bez zmeny údajov = bez zmeny';
END;
$$;

-- Z2-3. Domácnosti: XM Trade + Office portal v jednom behu; nová osoba bez kontaktu (založená importom), účinnosť z XM,
--       cenník ANO/NIE podľa regulácie z produktu XM, ZEM; VBattery: produkt DD a sadzba z XM, program z Office portálu
DO $$
DECLARE
  v_xm jsonb := jsonb_build_array(
    pg_temp.z2_xm(2, 10, '1120269010', '{"product": "Green DD2 - ANO Energopomoc", "regulation": "Neregulované", "address": "Hlavná 1, Senec"}'),
    pg_temp.z2_xm(3, 11, '1120269011', '{"product": "VBATTERY - DD3 - NIE Energopomoc", "tariff": "VBATTERY-PREMIUM"}'));
  v_h  jsonb := '{"household": true, "ico": null, "company_name": null, "list_price": true, "valid_from": null, "valid_to": null, "auto_prolong": false, "qty_vt_mwh": 3}';
  v    jsonb;
  k    contract;
  p    contact;
  o    oom;
  i    price_list_item;
BEGIN
  v := pg_temp.z2_run(v_xm, jsonb_build_array(
    pg_temp.z2_op(2, '1120269010', 10, v_h || jsonb_build_object('first_name', 'Jana', 'last_name', 'Importová Z2',
                                       'person_op_id', md5('z2-osoba-1'), 'product_oom', 'DD2')),
    pg_temp.z2_op(3, '1120269011', 11, v_h || jsonb_build_object('first_name', 'Ján', 'last_name', 'Batéria Z2',
                                       'person_op_id', md5('z2-osoba-2'), 'product_oom', 'VBattery  - PREMIUM'))));
  ASSERT v #>> '{counts,zmluvy,nova}' = '2' AND v #>> '{counts,oom,nove}' = '2', 'domácnosti: ' || (v -> 'counts')::text;

  k := pg_temp.z2_k('1120269010');
  SELECT * INTO p FROM contact WHERE id = k.person_id;
  SELECT * INTO o FROM oom WHERE eic = pg_temp.z2_eic(10);
  ASSERT p.first_name = 'Jana' AND p.is_household AND p.email IS NULL AND p.created_by_import IS NOT NULL
     AND p.owner_id = '00000000-0000-4000-8000-000000006002' AND p.op_person_id = md5('z2-osoba-1')::uuid
     AND p.address = 'Hlavná 1, Senec', 'nová osoba bez kontaktu, založená importom, bydlisko z XM Trade';
  ASSERT o.person_id = p.id AND o.price_regulation AND o.type = 'spotreba', 'OOM z XM Trade pre osobu zo zmluvy, regulácia ANO z produktu';
  ASSERT k.type = 'dodavka_domacnost' AND k.valid_from = '2026-10-01' AND k.valid_to IS NULL AND k.list_price,
         'účinnosť domácnosti z XM Trade (rozhodnutie 3)';
  ASSERT (SELECT p2.code FROM contract_oom co JOIN product p2 ON p2.id = co.product_id WHERE co.contract_id = k.id) = 'green_dd2_ano',
         'DD2 ANO podľa regulácie OOM';
  i := pg_temp.z2_item('domacnosti_ano_energopomoc', 'green_dd2_ano', '2026-10-01');
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita' AND price_model = 'cennik'
                    AND price_list_item_id = i.id AND price_vt_eur_mwh = i.price_vt_eur_mwh AND valid_from = '2026-10-01'),
         'komodita z cenníka Domácnosti ANO';
  i := pg_temp.z2_item('domacnosti_ano_energopomoc', 'zem', '2026-10-01');
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'zem' AND price_list_item_id = i.id
                    AND fee_eur_month = i.fee_oom_eur_month), 'ZEM pri OOM spotreby domácnosti';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL),
         'cena nechýba';

  -- VBattery: produkt DD3 NIE a sadzba D3 z XM Trade, program PREMIUM z Office portálu
  k := pg_temp.z2_k('1120269011');
  SELECT * INTO o FROM oom WHERE eic = pg_temp.z2_eic(11);
  ASSERT NOT o.price_regulation AND o.pds_tariff = 'zsd_d3', 'VBattery: regulácia NIE a sadzba D3 z produktu XM Trade';
  ASSERT (SELECT p1.code || '+' || p2.code FROM contract_oom co JOIN product p1 ON p1.id = co.product_id
            JOIN product p2 ON p2.id = co.program_id WHERE co.contract_id = k.id) = 'green_dd3_nie+vbattery_premium',
         'VBattery: produkt DD3 NIE + program PREMIUM';
  ASSERT (SELECT array_agg(slot ORDER BY slot) FROM contract_price WHERE contract_id = k.id) = '{komodita,program,zem}',
         'VBattery: komodita, ZEM, program';
  i := pg_temp.z2_item('virtualna_bateria', 'vbattery_premium', '2026-10-01');
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'program' AND price_list_item_id = i.id
                    AND fee_eur_month = i.fee_program_eur_month), 'program z cenníka Virtuálna batéria';
  RAISE NOTICE 'OK: Z2-3 domácnosti z XM + OP v jednom behu (nová osoba bez kontaktu, účinnosť z XM, DD ANO podľa regulácie, ZEM), VBattery (DD a sadzba z XM, program z OP)';
END;
$$;

-- Z2-4. Chyby: neznáma fáza a obchodník (chýbajúci preklad), OOM mimo CRM, dve rôzne ceny, 1T/2T neurčiteľné,
--       prekrytie podpísaných zmlúv; testovací riadok preskočený
DO $$
DECLARE
  v jsonb;
  e jsonb;
BEGIN
  v := pg_temp.z2_run(jsonb_build_array(pg_temp.z2_xm(2, 20, '1120269027')), jsonb_build_array(
    pg_temp.z2_op(2, '1120269021', 1, '{"phase": "Fáza Z2", "product_oom": "IN GREEN 1T"}'),
    pg_temp.z2_op(3, '1120269022', 1, '{"owner_name": "Neznámy Obchodník Z2", "product_oom": "IN GREEN 1T"}'),
    pg_temp.z2_op(4, '1120269023', 30, '{"product_oom": "IN GREEN 1T"}'),
    pg_temp.z2_op(5, '1120269024', 1, '{"phase": "Rozpracovaná", "product_oom": "IN GREEN 1T", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_vt": 120}'),
    pg_temp.z2_op(6, '1120269024', 1, '{"phase": "Rozpracovaná", "product_oom": "IN GREEN 1T", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_vt": 125}'),
    pg_temp.z2_op(7, '1120269025', 1, '{"valid_from": "2026-06-01", "signed_on": "2026-05-01", "product_oom": "IN GREEN 1T"}'),
    pg_temp.z2_op(8, '1120269026', 1, '{"test": true}'),
    pg_temp.z2_op(9, '1120269027', 20, '{"phase": "Rozpracovaná", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_vt": 120}'),
    pg_temp.z2_op(10, '1120269027', 20, '{"phase": "Rozpracovaná", "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_vt": 130, "price_nt": 110}')),
    false);
  ASSERT v #>> '{counts,zmluvy,chyba}' = '6' AND v #>> '{counts,zmluvy,preskocene}' = '1', 'chyby: ' || (v -> 'counts')::text;
  e := pg_temp.z2_c(v, '1120269021');
  ASSERT e -> 'missing' @> '[{"kind": "faza", "name": "Fáza Z2"}]' AND e ->> 'errors' LIKE '%Neznáma fáza%', 'neznáma fáza: ' || e::text;
  e := pg_temp.z2_c(v, '1120269022');
  ASSERT e -> 'missing' @> '[{"kind": "obchodnik", "name": "Neznámy Obchodník Z2"}]', 'neznámy obchodník: ' || e::text;
  ASSERT pg_temp.z2_c(v, '1120269023') ->> 'errors' LIKE '%nie je v CRM – najprv nahrajte export z XM Trade%', 'OOM mimo CRM';
  ASSERT pg_temp.z2_c(v, '1120269024') ->> 'errors' LIKE '%dve rôzne ceny%', 'dve rôzne ceny v období (otázka 4)';
  ASSERT pg_temp.z2_c(v, '1120269025') ->> 'errors' LIKE '%prekrytie%', 'prekrytie podpísaných zmlúv';
  ASSERT pg_temp.z2_c(v, '1120269027') ->> 'errors' LIKE '%1T aj 2T%', '1T/2T neurčiteľné: ' || (pg_temp.z2_c(v, '1120269027'))::text;
  ASSERT (SELECT x ->> 'action' FROM jsonb_array_elements(v -> 'oom') x WHERE x ->> 'eic' = pg_temp.z2_eic(20)) = 'chyba',
         'nové OOM chybnej zmluvy sa nezaloží';
  -- nové OOM zmluvy so sadzbou, ktorú nejde preložiť: chyba zmluvy s pôvodným dôvodom a ponukou prekladu
  v := pg_temp.z2_run(jsonb_build_array(pg_temp.z2_xm(2, 21, '1120269028', '{"tariff": "Sadzba Z2"}')),
                      jsonb_build_array(pg_temp.z2_op(2, '1120269028', 21, '{"product_oom": "IN GREEN 1T"}')), false);
  e := pg_temp.z2_c(v, '1120269028');
  ASSERT e ->> 'action' = 'chyba' AND e ->> 'errors' LIKE '%XM Trade, riadok 2%sadzba „Sadzba Z2“%'
     AND e -> 'missing' @> '[{"kind": "sadzba", "name": "Sadzba Z2", "source": "xm_trade"}]', 'chyba nového OOM pri zmluve: ' || e::text;
  RAISE NOTICE 'OK: Z2-4 chyby (neznáma fáza a obchodník s prekladom na doplnenie, OOM mimo CRM, dve rôzne ceny, 1T/2T neurčiteľné, prekrytie), testovací riadok preskočený';
END;
$$;

-- Z2-5. Prázdna bunka neprepíše hodnotu v CRM (doplnok a); VIWA bez balíka → „Chýba cena“, balík zadá Servis v CRM
DO $$
DECLARE
  v_op jsonb;
  v    jsonb;
  k    contract;
  g    uuid := (SELECT id FROM company WHERE ico = '99999921');
BEGIN
  INSERT INTO oom (company_id, eic, type, status) VALUES (g, pg_temp.z2_eic(4), 'vyroba', 'pripravovane');
  v := pg_temp.z2_run('[]', jsonb_build_array(pg_temp.z2_op(2, '26VIWP9001', 4,
         '{"commodity": "nezname", "valid_from": "2026-09-01", "valid_to": null, "auto_prolong": false, "qty_vt_mwh": 0, "source_power_kw": 10}')));
  k := pg_temp.z2_k('26VIWP9001');
  ASSERT k.type = 'viwa' AND k.viwa_package IS NULL, 'VIWA bez balíka';
  ASSERT (SELECT detail FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL) LIKE '%balík VIWA%',
         'VIWA bez balíka: Chýba cena (otázka 20)';
  -- prázdne bunky (obchodník, účinnosť do, podpis, tvorca) pri novšom exporte zmluvy firmy nič neprepíšu
  SELECT jsonb_agg(x || '{"updated_at": "2026-07-01T08:00:00Z", "owner_name": "", "valid_to": null, "signed_on": null, "created_by_name": ""}')
    INTO v_op FROM jsonb_array_elements(jsonb_build_array(
      pg_temp.z2_op(2, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
      pg_temp.z2_op(3, '1120269001', 1, '{"product_oom": "IN GREEN 1T", "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'),
      pg_temp.z2_op(4, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_1T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 120, "price_nt": 0}'),
      pg_temp.z2_op(5, '1120269001', 2, '{"product_oom": "IN GREEN 2T", "qty_vt_mwh": 5, "qty_nt_mwh": 3, "price_product": "GREEN_2T_INDIVIDUAL_2026", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 130, "price_nt": 110}'))) x;
  v := pg_temp.z2_run('[]', v_op, false);
  ASSERT v #>> '{counts,zmluvy,bez_zmeny}' = '1', 'prázdne bunky = bez zmeny: ' || (pg_temp.z2_c(v, '1120269001'))::text;
  PERFORM pg_temp.z2_run('[]', v_op, true);
  k := pg_temp.z2_k('1120269001');
  ASSERT k.owner_id = '00000000-0000-4000-8000-000000006002' AND k.valid_to = '2026-12-31' AND k.signed_on = '2026-02-01'
     AND k.created_by_name = 'Tvorca Z2', 'prázdna bunka neprepísala hodnotu (doplnok a)';
END;
$$;
-- balík VIWA zadá Servis v CRM (aplikácia: iba stĺpec balíka); ceny z cenníka Green VIWA, príznak sa uzavrie
GRANT SELECT ON company, contact, oom, contract_import_change TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
UPDATE contract SET viwa_package = 'plus' WHERE number = '26VIWP9001';
RESET ROLE;
DO $$
DECLARE
  k contract := pg_temp.z2_k('26VIWP9001');
  i price_list_item := pg_temp.z2_item('green_viwa', 'viwa_plus', '2026-09-01');
  v jsonb;
BEGIN
  ASSERT k.viwa_package = 'plus', 'Servis zadal balík';
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'viwa_ucet' AND oom_id IS NULL
                    AND price_list_item_id = i.id AND fee_eur_month = i.fee_program_eur_month AND fee_kw_eur_month IS NULL)
     AND EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'viwa_kw' AND oom_id IS NOT NULL
                    AND price_list_item_id = i.id AND fee_kw_eur_month = i.fee_kw_eur_month AND fee_eur_month IS NULL),
         'VIWA: platba za účet a €/kW z cenníka Green VIWA';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL),
         'príznak Chýba cena uzavretý';
  -- novší export bez balíka balík zo CRM neprepíše
  v := pg_temp.z2_run('[]', jsonb_build_array(pg_temp.z2_op(2, '26VIWP9001', 4,
         '{"commodity": "nezname", "valid_from": "2026-09-01", "valid_to": null, "auto_prolong": false, "qty_vt_mwh": 0, "source_power_kw": 10, "updated_at": "2026-08-01T08:00:00Z"}')));
  ASSERT (pg_temp.z2_k('26VIWP9001')).viwa_package = 'plus', 'balík VIWA z CRM ostal (doplnok a)';
  BEGIN
    UPDATE contract SET viwa_package = 'pro' WHERE number = '1120269001';
    RAISE EXCEPTION 'CHYBA: balík VIWA pri zmluve o dodávke';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
  RAISE NOTICE 'OK: Z2-5 prázdna bunka neprepíše hodnotu v CRM (obchodník, účinnosť do, podpis, tvorca, balík VIWA); VIWA bez balíka = Chýba cena, balík zadaný v CRM doplní ceny Green VIWA a príznak uzavrie';
END;
$$;

-- Z2-6. Výkup na neurčito: posledné cenové obdobie bez konca, SPOT − €; mesačná cena _PC_M09 = Na kontrolu
DO $$
DECLARE
  v jsonb;
  k contract;
  g uuid := (SELECT id FROM company WHERE ico = '99999921');
BEGIN
  INSERT INTO oom (company_id, eic, type, status) VALUES (g, pg_temp.z2_eic(5), 'vyroba', 'pripravovane'),
                                                         (g, pg_temp.z2_eic(6), 'vyroba', 'pripravovane');
  v := pg_temp.z2_run('[]', jsonb_build_array(
    pg_temp.z2_op(2, '26VYRP9001', 5, '{"commodity": "Elektrina_vyroba", "valid_from": "2026-01-01", "valid_to": null, "qty_vt_mwh": 0, "price_product": "2026_GREENVYR_AK [EUR]", "price_from": "2026-01-01", "price_to": "2026-12-31", "price_vt": 20}'),
    pg_temp.z2_op(3, '26VYRP9001', 5, '{"commodity": "Elektrina_vyroba", "valid_from": "2026-01-01", "valid_to": null, "qty_vt_mwh": 0, "price_product": "2027_GREENVYR_AK [EUR]", "price_vt": 22}'),
    pg_temp.z2_op(4, '26VYRP9002', 6, '{"commodity": "Elektrina_vyroba", "valid_from": "2026-01-01", "valid_to": null, "qty_vt_mwh": 0, "price_product": "2026_GREENVYR_PC_M09", "price_from": "2026-09-01", "price_to": "2026-09-30", "price_vt": 4}')));
  ASSERT v #>> '{counts,zmluvy,nova}' = '2', 'výkupy: ' || (v -> 'counts')::text;
  k := pg_temp.z2_k('26VYRP9001');
  ASSERT k.type = 'vykup', 'výkup';
  ASSERT (SELECT array_agg(valid_from::text || '..' || coalesce(valid_to::text, '') || '=' || additive_eur_mwh::numeric(6,2)
                           ORDER BY valid_from)
            FROM contract_price p JOIN product pr ON pr.id = p.product_id
           WHERE p.contract_id = k.id AND p.price_model = 'spot_minus_eur' AND pr.code = 'vykup_b2b')
         = '{2026-01-01..2026-12-31=20.00,2027-01-01..=22.00}', 'výkup: rok z názvu, posledné obdobie bez konca';
  k := pg_temp.z2_k('26VYRP9002');
  ASSERT (SELECT detail FROM contract_flag WHERE contract_id = k.id AND code = 'kontrola_importu' AND resolved_at IS NULL)
         LIKE '%PC_M09%', 'mesačná cena výkupu = Na kontrolu (O2)';
  RAISE NOTICE 'OK: Z2-6 výkup na neurčito (rok z názvu produktu, posledné obdobie bez konca, SPOT − €, Výkup B2B), _PC_M09 na kontrolu';
END;
$$;

-- Z2-7. Domácnosť bez XM Trade: prvé párovanie podľa mena (uloží Osoba_ID), bez účinnosti = Chýba cena;
--       neskorší samotný XM Trade doplní účinnosť a ceny; zmena regulácie z XM = zmena s „platí od“ dnes (otázka 19)
INSERT INTO contact (id, first_name, last_name, email, is_household)
VALUES ('00000000-0000-4000-8000-000000006101', 'Mária', 'Párová Z2', 'parova.z2@example.test', true);
INSERT INTO oom (company_id, person_id, eic, type, status, pds, price_regulation)
VALUES (NULL, '00000000-0000-4000-8000-000000006101', pg_temp.z2_eic(12), 'spotreba', 'pripravovane', 'zsd', true);
DO $$
DECLARE
  v_h jsonb := '{"household": true, "ico": null, "company_name": null, "list_price": true, "valid_from": null, "valid_to": null, "auto_prolong": false, "qty_vt_mwh": 2, "owner_name": "", "first_name": "Mária", "last_name": "Párová Z2", "product_oom": "DD1"}';
  v   jsonb;
  k   contract;
  e   jsonb;
BEGIN
  v := pg_temp.z2_run('[]', jsonb_build_array(pg_temp.z2_op(2, '1120269012', 12, v_h || jsonb_build_object('person_op_id', md5('z2-osoba-3')))));
  e := pg_temp.z2_c(v, '1120269012');
  k := pg_temp.z2_k('1120269012');
  ASSERT k.person_id = '00000000-0000-4000-8000-000000006101' AND k.owner_id IS NULL AND k.valid_from IS NULL, 'párovanie podľa mena, bez obchodníka';
  ASSERT (SELECT op_person_id FROM contact WHERE id = '00000000-0000-4000-8000-000000006101') = md5('z2-osoba-3')::uuid,
         'Osoba_ID uložené pri osobe';
  ASSERT e ->> 'warnings' LIKE '%nemá obchodníka%' AND e ->> 'warnings' LIKE '%vytvoril: Tvorca Z2%'
     AND e ->> 'warnings' LIKE '%Účinnosť od chýba%', 'upozornenia: bez obchodníka (tvorca iba informácia), bez účinnosti';
  ASSERT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL),
         'bez účinnosti = Chýba cena';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id), 'bez účinnosti bez cien';

  -- samotný XM Trade: začiatok dodávky 1. 11. 2026, regulácia NIE
  v := pg_temp.z2_run(jsonb_build_array(pg_temp.z2_xm(2, 12, '1120269012',
         '{"supply_from": "2026-11-01", "product": "DD1 - NIE Energopomoc"}')), '[]');
  e := pg_temp.z2_c(v, '1120269012');
  ASSERT e ->> 'action' = 'zmena' AND e ->> 'source' = 'xm_trade' AND e ->> 'changes' LIKE '%Účinnosť od – → 1. 11. 2026%',
         'XM Trade doplnil účinnosť: ' || coalesce(e::text, v::text);
  k := pg_temp.z2_k('1120269012');
  ASSERT k.valid_from = '2026-11-01' AND EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita'),
         'účinnosť a ceny doplnené';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL),
         'Chýba cena uzavretá';
  ASSERT EXISTS (SELECT 1 FROM oom_price_regulation_change r JOIN oom o ON o.id = r.oom_id
                  WHERE o.eic = pg_temp.z2_eic(12) AND NOT r.value AND r.valid_from = crm_today() AND r.applied_at IS NOT NULL)
     AND NOT (SELECT price_regulation FROM oom WHERE eic = pg_temp.z2_eic(12)), 'zmena regulácie z XM = história s „platí od“ dnes';
  ASSERT EXISTS (SELECT 1 FROM contract_import_change c JOIN contract_import i ON i.id = c.import_id
                  WHERE c.contract_id = k.id AND c.action = 'zmena' AND i.xm_file_name = 'z2-xm.xlsx'),
         'zmena z XM Trade v histórii importov zmluvy';
  RAISE NOTICE 'OK: Z2-7 domácnosť bez XM (párovanie podľa mena a Osoba_ID, bez obchodníka s tvorcom ako informáciou, Chýba cena), samotný XM Trade doplní účinnosť a ceny, regulácia z XM s „platí od“ dnes';
END;
$$;

-- Z2-8. Malý podnik s cenníkovou cenou: DMP10 = cenník Malé podniky a verejné osvetlenie na OOM
DO $$
DECLARE
  g uuid := (SELECT id FROM company WHERE ico = '99999921');
  k contract;
  i price_list_item := pg_temp.z2_item('male_podniky', 'green_dmp10', '2026-03-01');
BEGIN
  INSERT INTO oom (company_id, eic, type, status, voltage_level) VALUES (g, pg_temp.z2_eic(7), 'spotreba', 'pripravovane', 'nn');
  PERFORM pg_temp.z2_run('[]', jsonb_build_array(
    pg_temp.z2_op(2, '1120269013', 7, '{"small_business": true, "list_price": true, "product_oom": "DMP10"}')));
  k := pg_temp.z2_k('1120269013');
  ASSERT k.small_business AND k.list_price, 'malý podnik, cenníková cena';
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita' AND price_list_item_id = i.id)
     AND NOT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'poplatok_om'),
         'DMP10 z cenníka Malé podniky, platba za OM je v položke';
  ASSERT (SELECT public_lighting FROM oom WHERE eic = pg_temp.z2_eic(7)), 'DMP10 nastaví verejné osvetlenie (odpoveď 4)';
  RAISE NOTICE 'OK: Z2-8 malý podnik s cenníkom (DMP10 z cenníka Malé podniky), verejné osvetlenie na OOM';
END;
$$;

-- Z2-9. RLS „iba svoje“ (doplnok b): obchodník vidí zákazníka založeného importom a jeho zmluvu, cudziu zmluvu nie;
--       bez práva importu import nespustí
SET LOCAL ROLE crm_rls_test;
DO $$
BEGIN
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000006002', true);
  ASSERT EXISTS (SELECT 1 FROM company WHERE ico = '99999921'), 'obchodník vidí firmu založenú importom (vlastník)';
  ASSERT EXISTS (SELECT 1 FROM contract WHERE number = '1120269001'), 'obchodník vidí jej zmluvu';
  ASSERT EXISTS (SELECT 1 FROM contact WHERE last_name = 'Importová Z2') AND EXISTS (SELECT 1 FROM contract WHERE number = '1120269010'),
         'obchodník vidí domácnosť založenú importom a jej zmluvu';
  ASSERT NOT EXISTS (SELECT 1 FROM contract WHERE number = '1120269012'), 'zmluvu bez obchodníka cudzej osoby nevidí';
  ASSERT EXISTS (SELECT 1 FROM contract_import_change c JOIN contract k ON k.id = c.contract_id WHERE k.number = '1120269001'),
         'históriu importov svojej zmluvy vidí';
  BEGIN
    PERFORM contract_import_run(crm_default_org(), '[]', jsonb_build_array(pg_temp.z2_op(2, '1120269099', 1)), false);
    RAISE EXCEPTION 'CHYBA: import bez práva';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000006001', true);
  RAISE NOTICE 'OK: Z2-9 RLS iba svoje: obchodník vidí zákazníkov založených importom (vlastník) a ich zmluvy, cudziu nie; bez práva importu nič';
END;
$$;
RESET ROLE;

-- Z2-10. Príznak „založený importom“ zruší prvá ručná úprava; osoba bez kontaktu ho drží, kým sa kontakt nedoplní
DO $$
DECLARE
  v_id uuid := (SELECT id FROM contact WHERE last_name = 'Importová Z2');
BEGIN
  UPDATE company SET name = 'Gama Z2 upravená s.r.o.' WHERE ico = '99999921';
  ASSERT (SELECT created_by_import IS NULL FROM company WHERE ico = '99999921'), 'úprava firmy zrušila príznak';
  UPDATE contact SET first_name = 'Janka' WHERE id = v_id;
  ASSERT (SELECT created_by_import IS NOT NULL FROM contact WHERE id = v_id), 'osoba bez kontaktu príznak drží';
  UPDATE contact SET email = 'janka.z2@example.test' WHERE id = v_id;
  ASSERT (SELECT created_by_import IS NULL FROM contact WHERE id = v_id), 'po doplnení kontaktu príznak zrušený';
  RAISE NOTICE 'OK: Z2-10 príznak „založený importom“ zruší prvá ručná úprava (osoba až s kontaktom)';
END;
$$;

-- Z2-11. Cena po poslednom roku (otázka 23): SPOT + aditív platí ďalej; FIX s automatickou prolongáciou = cenník
--        „Podnikatelia nad 30 MWh“ podľa typu tarifu OOM (verejné osvetlenie = Green 1T VO) a platba za OM iba mimo neho;
--        FIX bez prolongácie = bez ceny
DO $$
DECLARE
  g  uuid := (SELECT id FROM company WHERE ico = '99999921');
  v  jsonb;
  k  contract;
  i  price_list_item;
  b  price_list_item := pg_temp.z2_item('poplatky_b2b', 'poplatok_om_firmy', '2026-01-01');
  c0 jsonb := '{"valid_from": "2025-01-01", "valid_to": "2026-12-31", "signed_on": "2024-12-01", "product_oom": "IN GREEN 1T"}';
BEGIN
  INSERT INTO oom (company_id, eic, type, status, voltage_level, public_lighting)
  SELECT g, pg_temp.z2_eic(n), 'spotreba', 'pripravovane', 'nn', n = 34 FROM generate_series(31, 34) n;
  v := pg_temp.z2_run('[]', jsonb_build_array(
    pg_temp.z2_op(2, '1120269031', 31, c0 || '{"price_product": "GREEN_ISOTSK_PLUS_2025_R", "price_from": "2025-01-01", "price_to": "2025-12-31", "price_vt": 6}'),
    pg_temp.z2_op(3, '1120269032', 32, c0 || '{"price_product": "GREEN_1T_INDIVIDUAL_2025", "price_from": "2025-01-01", "price_to": "2025-12-31", "price_vt": 110}'),
    pg_temp.z2_op(4, '1120269033', 33, c0 || '{"auto_prolong": false, "price_product": "GREEN_1T_INDIVIDUAL_2025", "price_from": "2025-01-01", "price_to": "2025-12-31", "price_vt": 110}'),
    pg_temp.z2_op(5, '1120269034', 34, c0 || '{"price_product": "GREEN_1T_INDIVIDUAL_2025", "price_from": "2025-01-01", "price_to": "2025-12-31", "price_vt": 110}')));
  ASSERT v #>> '{counts,zmluvy,nova}' = '4', 'zmluvy: ' || (v -> 'counts')::text;
  -- SPOT + aditív 2025 platí do konca účinnosti
  k := pg_temp.z2_k('1120269031');
  ASSERT (SELECT array_agg(price_model::text || ' ' || valid_from || '..' || valid_to ORDER BY valid_from)
            FROM contract_price WHERE contract_id = k.id AND slot = 'komodita') = '{"spot_plus_eur 2025-01-01..2026-12-31"}',
         'SPOT + aditív platí ďalej';
  ASSERT (SELECT array_agg(valid_from || '..' || valid_to) FROM contract_price WHERE contract_id = k.id AND slot = 'poplatok_om')
         = ARRAY[greatest('2025-01-01'::date, (SELECT v2.valid_from FROM price_list_version v2 WHERE v2.id = b.version_id)) || '..2026-12-31'],
         'SPOT: platba za OM z Poplatkov B2B';
  -- FIX + prolongácia: cenník nad 30 MWh od 1. 1. 2026 (podľa verzií), platba za OM iba mimo neho
  k := pg_temp.z2_k('1120269032');
  i := pg_temp.z2_item('podnikatelia_nad_30mwh', 'green_1t', '2026-12-31');
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita' AND price_model = 'cennik'
                    AND price_list_item_id = i.id AND valid_to = '2026-12-31' AND fee_eur_month = i.fee_oom_eur_month),
         'FIX + prolongácia: cenník nad 30 MWh (Green 1T)';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_price c1 JOIN contract_price c2 ON c2.contract_id = c1.contract_id
                       AND c2.oom_id = c1.oom_id AND c2.slot = 'komodita' AND c2.price_model = 'cennik'
                      WHERE c1.contract_id = k.id AND c1.slot = 'poplatok_om'
                        AND daterange(c1.valid_from, c1.valid_to, '[]') && daterange(c2.valid_from, c2.valid_to, '[]')),
         'platba za OM sa neprekrýva s cenníkom nad 30 MWh';
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita' AND price_model = 'fix'
                    AND valid_to = '2025-12-31'), 'FIX 2025 ostáva';
  -- FIX bez prolongácie: po roku 2025 nič
  k := pg_temp.z2_k('1120269033');
  ASSERT (SELECT count(*) FROM contract_price WHERE contract_id = k.id AND slot = 'komodita') = 1, 'FIX bez prolongácie: iba 2025';
  -- verejné osvetlenie: Green 1T VO
  k := pg_temp.z2_k('1120269034');
  i := pg_temp.z2_item('podnikatelia_nad_30mwh', 'green_1t_vo', '2026-12-31');
  ASSERT EXISTS (SELECT 1 FROM contract_price WHERE contract_id = k.id AND slot = 'komodita' AND price_list_item_id = i.id),
         'verejné osvetlenie: cenník Green 1T VO';
  RAISE NOTICE 'OK: Z2-11 po poslednom roku s cenou: SPOT + aditív platí ďalej, FIX s prolongáciou = cenník nad 30 MWh (1T, 1T VO) a platba za OM mimo neho, FIX bez prolongácie bez ceny';
END;
$$;

-- Z2-12. Typ OOM z XM Trade (otázka 24): „Dodávka (+)“ = výroba bez upozornenia; existujúcemu sa typ nemení (upozornenie);
--        VBattery na výrobnom OOM: iba program, bez komodity a ZEM a bez „Chýba cena“
DO $$
DECLARE
  v jsonb;
  x jsonb;
  k contract;
BEGIN
  v := pg_temp.z2_run(jsonb_build_array(
         pg_temp.z2_xm(2, 36, '1120269036', '{"direction": "Dodávka (+)", "product": "VBATTERY - DD2 - ANO Energopomoc", "tariff": "VBATTERY-MAX"}'),
         pg_temp.z2_xm(3, 1, '1120269001', '{"ico": "99999921", "direction": "Dodávka (+)"}')),
       jsonb_build_array(pg_temp.z2_op(2, '1120269036', 36, '{"household": true, "ico": null, "company_name": null, "list_price": true, "valid_from": null, "valid_to": null, "auto_prolong": false, "qty_vt_mwh": 0, "first_name": "Viktor", "last_name": "Výroba Z2", "product_oom": "VBattery - MAX"}'::jsonb || jsonb_build_object('person_op_id', md5('z2-osoba-4')))));
  x := (SELECT y FROM jsonb_array_elements(v -> 'oom') y WHERE y ->> 'eic' = pg_temp.z2_eic(36));
  ASSERT x ->> 'action' = 'nove' AND jsonb_array_length(x -> 'warnings') = 0, 'Dodávka (+) bez upozornenia: ' || x::text;
  ASSERT (SELECT type FROM oom WHERE eic = pg_temp.z2_eic(36)) = 'vyroba', 'Dodávka (+) = výroba';
  x := (SELECT y FROM jsonb_array_elements(v -> 'oom') y WHERE y ->> 'eic' = pg_temp.z2_eic(1));
  ASSERT x ->> 'warnings' LIKE '%typ sa nemení%' AND (SELECT type FROM oom WHERE eic = pg_temp.z2_eic(1)) = 'spotreba',
         'existujúcemu OOM sa typ nemení: ' || x::text;
  k := pg_temp.z2_k('1120269036');
  ASSERT (SELECT array_agg(slot) FROM contract_price WHERE contract_id = k.id) = '{program}', 'VBattery na výrobnom OOM: iba program';
  ASSERT (SELECT product_id IS NULL FROM contract_oom WHERE contract_id = k.id), 'výrobné OOM bez produktu DD';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = k.id AND code = 'chyba_cena' AND resolved_at IS NULL),
         'výrobné OOM bez „Chýba cena“';
  RAISE NOTICE 'OK: Z2-12 typ OOM z XM Trade (Dodávka = výroba bez upozornenia, existujúcemu sa nemení), VBattery na výrobnom OOM iba program';
END;
$$;

SELECT set_config('app.user_id', '', true), set_config('app.require_user', '', true);
