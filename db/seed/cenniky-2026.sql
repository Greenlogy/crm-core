-- Naplnenie modulu 3: produkty, párovanie so sadzbami a cenníky 2026 (dáta, nie migrácia).
-- Zdroj: zadanie 03-produkty.md v0.3 (katalóg, párovanie, programy) a PDF v exports/cenniky-2026/:
--   Domácnosti bez / s energopomocou od 1. 1. 2026 (+ VBattery od 1. 4. 2026), Malé podniky od 1. 1. 2026,
--   Green VIWA od 1. 10. 2025; Poplatky B2B 5 € (zadanie čl. 4, O6). Údaje z HubSpotu sa nenahrávajú.
-- Spúšťa db/seed/cenniky-2026.sh (vlastník databázy, jedna transakcia). Ceny bez DPH sú prepísané z PDF;
-- na konci sa ceny s DPH porovnajú so stĺpcom „s DPH“ v PDF a ANO = NIE − 31,24 €/MWh – pri rozdiele chyba a nič sa neuloží.
-- Opakované spustenie: existujúce produkty, párovanie, cenníky a verzie (podľa kódu / názvu) nechá tak.

\set ON_ERROR_STOP on
SET LOCAL app.change_source = 'system';

-- ============================================================================
-- Produkty (40)
-- ============================================================================

CREATE TEMP TABLE s_product (code text, name text, category product_category, segment customer_segment,
  vat numeric, tariff tariff_type, models price_model[], regulation boolean, status product_status, sort integer) ON COMMIT DROP;

INSERT INTO s_product
SELECT 'green_dd' || n || '_' || r.k, 'Green DD' || n || ' – ' || r.l || ' Energopomoc', 'dodavka_domacnost', 'domacnost', 19,
       CASE WHEN n <= 2 THEN 'jednotarif' ELSE 'dvojtarif' END::tariff_type, '{cennik,spot_plus_eur}', r.reg, 'predava_sa',
       r.base + n
  FROM generate_series(1, 8) n,
       (VALUES ('nie', 'NIE', false, 100), ('ano', 'ANO', true, 200)) r(k, l, reg, base);
INSERT INTO s_product
SELECT 'green_dmp' || n, 'Green DMP' || n, 'dodavka_maly_podnik', 'firma', 19,
       CASE WHEN n BETWEEN 4 AND 8 THEN 'dvojtarif' WHEN n = 9 THEN 'nemerany' ELSE 'jednotarif' END::tariff_type,
       '{cennik}', true, 'predava_sa', 300 + n
  FROM generate_series(1, 11) n;
INSERT INTO s_product VALUES
  ('dodavka_b2b',       'Dodávka B2B',                   'dodavka_firma',  'firma',     19, 'netyka_sa', '{fix,spot_plus_eur}',                   NULL, 'predava_sa', 400),
  ('poplatok_om_firmy', 'Mesačná platba za OM – firmy',  'poplatok',       'firma',     19, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 401),
  ('vykup_b2b',         'Výkup B2B',                     'vykup_firma',    'firma',     19, 'netyka_sa', '{fix,spot_minus_eur,spot_minus_pct}',   NULL, 'predava_sa', 410),
  ('velkoobchod',       'Veľkoobchod',                   'velkoobchod',    'firma',     19, 'netyka_sa', '{fix,spot_plus_eur}',                   NULL, 'predava_sa', 420),
  ('zem',               'ZEM',                           'zem',            'domacnost', 19, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 500),
  ('vbattery_standard', 'VBattery STANDARD',             'vbattery',       'domacnost', 23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 600),
  ('vbattery_premium',  'VBattery PREMIUM',              'vbattery',       'domacnost', 23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 601),
  ('vbattery_max',      'VBattery MAX',                  'vbattery',       'domacnost', 23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 602),
  ('vbattery_aku',      'VBattery AKU',                  'vbattery',       'domacnost', 23, 'netyka_sa', '{cennik}',                              NULL, 'dobieha',    603),
  ('viwa_basic',        'Green VIWA Basic',              'viwa',           'firma',     23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 700),
  ('viwa_plus',         'Green VIWA Plus',               'viwa',           'firma',     23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 701),
  ('viwa_pro',          'Green VIWA Pro',                'viwa',           'firma',     23, 'netyka_sa', '{cennik}',                              NULL, 'predava_sa', 702),
  ('green_solar',       'Green Solar – inštalácia FVE',  'instalacia_fve', 'domacnost', NULL, 'netyka_sa', '{cena_diela}',                        NULL, 'predava_sa', 800);

INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, price_models, price_regulation, status, sort_order)
SELECT (SELECT id FROM org WHERE code = 'greenlogy_sk'), code, name, category, segment, vat, tariff, models, regulation, status, sort
  FROM s_product
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- Párovanie produkt ↔ sadzba (zadanie čl. 5): 105 riadkov
-- ============================================================================

CREATE TEMP TABLE s_tariff (code text, scope text, tariff text) ON COMMIT DROP;
INSERT INTO s_tariff                                    -- DD ANO / NIE a ZEM: D1–D8 vo všetkých rozsahoch
SELECT p, s, 'd' || n
  FROM generate_series(1, 8) n, unnest(ARRAY['zsd', 'vsd', 'spolocne']) s,
       LATERAL unnest(ARRAY['green_dd' || n || '_nie', 'green_dd' || n || '_ano']) p;
INSERT INTO s_tariff SELECT 'zem', s, 'd' || n FROM generate_series(1, 8) n, unnest(ARRAY['zsd', 'vsd', 'spolocne']) s;
INSERT INTO s_tariff                                    -- DMP1–DMP8, DMP10: ZSD C2-X3, VSD X3-C2, inak Cn
SELECT 'green_dmp' || n, x.s, CASE x.s WHEN 'zsd' THEN 'c2_x3' WHEN 'vsd' THEN 'x3_c2' ELSE 'c' || n END
  FROM (SELECT generate_series(1, 8) UNION SELECT 10) g(n), (VALUES ('zsd'), ('vsd'), ('spolocne')) x(s);
INSERT INTO s_tariff                                    -- DMP9 = C9, DMP11 = C11 všade
SELECT 'green_dmp' || n, s, 'c' || n FROM unnest(ARRAY[9, 11]) n, unnest(ARRAY['zsd', 'vsd', 'spolocne']) s;

INSERT INTO product_tariff (product_id, scope_code, tariff_code)
SELECT p.id, t.scope, t.tariff FROM s_tariff t JOIN product p ON p.code = t.code
ON CONFLICT (product_id, scope_code, tariff_code) DO NOTHING;

-- ============================================================================
-- Cenníky a položky (ceny bez DPH z PDF; stĺpce *_pdf = „s DPH“ z PDF na kontrolu)
-- ============================================================================

CREATE TEMP TABLE s_list (code text, name text, segment customer_segment, description text, sort integer,
  version text, valid_from date) ON COMMIT DROP;
INSERT INTO s_list VALUES
  ('domacnosti_nie_energopomoc', 'Domácnosti – NIE Energopomoc', 'domacnost', 'domácnosti s cenovou reguláciou NIE (bez nároku na energopomoc)', 1, '2026', '2026-01-01'),
  ('domacnosti_ano_energopomoc', 'Domácnosti – ANO Energopomoc', 'domacnost', 'domácnosti s cenovou reguláciou ANO (nárok na energopomoc)', 2, '2026', '2026-01-01'),
  ('male_podniky',               'Malé podniky (do 30 MWh)',    'firma',     'firmy s cenovou reguláciou ANO, súčet plánovanej spotreby zmluvy do 30 MWh/rok', 3, '2026', '2026-01-01'),
  ('virtualna_bateria',          'Virtuálna batéria',           'domacnost', 'VBattery – doplnková služba na zmluve o dodávke domácnosti', 4, '2026', '2026-04-01'),
  ('green_viwa',                 'Green VIWA',                  'firma',     'virtuálna peňaženka – samostatná zmluva namiesto výkupu', 5, '2025', '2025-10-01'),
  ('poplatky_b2b',               'Poplatky B2B',                'firma',     'mesačná platba za OM pri firmách s individuálnou cenou', 6, '2026', '2026-01-01');

CREATE TEMP TABLE s_item (list text, product text, vt numeric, nt numeric, oom numeric, prog numeric, kw numeric,
  vt_pdf numeric, nt_pdf numeric, oom_pdf numeric, prog_pdf numeric, sort integer) ON COMMIT DROP;
INSERT INTO s_item VALUES
  -- Domácnosti bez energopomoci (PDF: Cennik_domacnosti_2026_bez_energopomoci + vbattery.pdf)
  ('domacnosti_nie_energopomoc', 'green_dd1_nie', 116.2426, NULL,     1.50, NULL, NULL, 138.3287, NULL,     1.79, NULL, 1),
  ('domacnosti_nie_energopomoc', 'green_dd2_nie', 120.7275, NULL,     1.50, NULL, NULL, 143.6657, NULL,     1.79, NULL, 2),
  ('domacnosti_nie_energopomoc', 'green_dd3_nie', 133.0608, 96.0608,  1.50, NULL, NULL, 158.3424, 114.3124, 1.79, NULL, 3),
  ('domacnosti_nie_energopomoc', 'green_dd4_nie', 133.0608, 96.0608,  1.50, NULL, NULL, 158.3424, 114.3124, 1.79, NULL, 4),
  ('domacnosti_nie_energopomoc', 'green_dd5_nie', 137.5457, 108.9547, 1.50, NULL, NULL, 163.6794, 129.6561, 1.79, NULL, 5),
  ('domacnosti_nie_energopomoc', 'green_dd6_nie', 137.5457, 108.9547, 1.50, NULL, NULL, 163.6794, 129.6561, 1.79, NULL, 6),
  ('domacnosti_nie_energopomoc', 'green_dd7_nie', 133.0608, 96.0608,  1.50, NULL, NULL, 158.3424, 114.3124, 1.79, NULL, 7),
  ('domacnosti_nie_energopomoc', 'green_dd8_nie', 133.0608, 96.0608,  1.50, NULL, NULL, 158.3424, 114.3124, 1.79, NULL, 8),
  ('domacnosti_nie_energopomoc', 'zem',           NULL,     NULL,     1.50, NULL, NULL, NULL,     NULL,     1.79, NULL, 9),
  -- Domácnosti s energopomocou (PDF: Cennik_domacnosti_2026_s_energopomocou + vbattery.pdf)
  ('domacnosti_ano_energopomoc', 'green_dd1_ano', 85.0026,  NULL,     1.50, NULL, NULL, 101.1531, NULL,     1.79, NULL, 1),
  ('domacnosti_ano_energopomoc', 'green_dd2_ano', 89.4875,  NULL,     1.50, NULL, NULL, 106.4901, NULL,     1.79, NULL, 2),
  ('domacnosti_ano_energopomoc', 'green_dd3_ano', 101.8208, 64.8208,  1.50, NULL, NULL, 121.1668, 77.1368,  1.79, NULL, 3),
  ('domacnosti_ano_energopomoc', 'green_dd4_ano', 101.8208, 64.8208,  1.50, NULL, NULL, 121.1668, 77.1368,  1.79, NULL, 4),
  ('domacnosti_ano_energopomoc', 'green_dd5_ano', 106.3057, 77.7147,  1.50, NULL, NULL, 126.5038, 92.4805,  1.79, NULL, 5),
  ('domacnosti_ano_energopomoc', 'green_dd6_ano', 106.3057, 77.7147,  1.50, NULL, NULL, 126.5038, 92.4805,  1.79, NULL, 6),
  ('domacnosti_ano_energopomoc', 'green_dd7_ano', 101.8208, 64.8208,  1.50, NULL, NULL, 121.1668, 77.1368,  1.79, NULL, 7),
  ('domacnosti_ano_energopomoc', 'green_dd8_ano', 101.8208, 64.8208,  1.50, NULL, NULL, 121.1668, 77.1368,  1.79, NULL, 8),
  ('domacnosti_ano_energopomoc', 'zem',           NULL,     NULL,     1.50, NULL, NULL, NULL,     NULL,     1.79, NULL, 9),
  -- Malé podniky (PDF: cennik zelenej elektirny pre male podniky 2026 (1).pdf)
  ('male_podniky', 'green_dmp1',  120.1214, NULL,     1.50, NULL, NULL, 142.9445, NULL,     1.79, NULL, 1),
  ('male_podniky', 'green_dmp2',  120.1214, NULL,     1.50, NULL, NULL, 142.9445, NULL,     1.79, NULL, 2),
  ('male_podniky', 'green_dmp3',  120.1214, NULL,     1.50, NULL, NULL, 142.9445, NULL,     1.79, NULL, 3),
  ('male_podniky', 'green_dmp4',  136.9396, 110.5911, 1.50, NULL, NULL, 162.9581, 131.6034, 1.79, NULL, 4),
  ('male_podniky', 'green_dmp5',  136.9396, 110.5911, 1.50, NULL, NULL, 162.9581, 131.6034, 1.79, NULL, 5),
  ('male_podniky', 'green_dmp6',  136.9396, 110.5911, 1.50, NULL, NULL, 162.9581, 131.6034, 1.79, NULL, 6),
  ('male_podniky', 'green_dmp7',  142.5457, 110.5911, 1.50, NULL, NULL, 169.6294, 131.6034, 1.79, NULL, 7),
  ('male_podniky', 'green_dmp8',  142.5457, 110.5911, 1.50, NULL, NULL, 169.6294, 131.6034, 1.79, NULL, 8),
  ('male_podniky', 'green_dmp9',  NULL,     NULL,     1.50, NULL, NULL, NULL,     NULL,     1.79, NULL, 9),
  ('male_podniky', 'green_dmp10', 120.1214, NULL,     1.50, NULL, NULL, 142.9445, NULL,     1.79, NULL, 10),
  ('male_podniky', 'green_dmp11', 120.1214, NULL,     1.50, NULL, NULL, 142.9445, NULL,     1.79, NULL, 11),
  -- VBattery od 1. 4. 2026 (PDF uvádza iba s DPH; bez DPH podľa zadania O3)
  ('virtualna_bateria', 'vbattery_standard', NULL, NULL, NULL, 1.4634, NULL, NULL, NULL, NULL, 1.80, 1),
  ('virtualna_bateria', 'vbattery_premium',  NULL, NULL, NULL, 3.9024, NULL, NULL, NULL, NULL, 4.80, 2),
  ('virtualna_bateria', 'vbattery_max',      NULL, NULL, NULL, 7.7480, NULL, NULL, NULL, NULL, 9.53, 3),
  -- Green VIWA od 1. 10. 2025 (PDF: Green_VIWA CENNIK.pdf; poplatok za odchýlku €/kW podľa zadania O4)
  ('green_viwa', 'viwa_basic', NULL, NULL, NULL, 3.90, 0.25, NULL, NULL, NULL, 4.80,  1),
  ('green_viwa', 'viwa_plus',  NULL, NULL, NULL, 6.90, 0.20, NULL, NULL, NULL, 8.49,  2),
  ('green_viwa', 'viwa_pro',   NULL, NULL, NULL, 9.90, 0.15, NULL, NULL, NULL, 12.18, 3),
  -- Poplatky B2B (zadanie čl. 4, O6): mesačná platba za OM 5 € bez DPH
  ('poplatky_b2b', 'poplatok_om_firmy', NULL, NULL, 5.00, NULL, NULL, NULL, NULL, 5.95, NULL, 1);

CREATE TEMP TABLE s_program (product text, greencar boolean, kwh integer, voucher numeric, greenshare boolean,
  share_pct numeric, factor numeric, bonus integer, expiry smallint) ON COMMIT DROP;
INSERT INTO s_program VALUES
  ('vbattery_standard', false, NULL, NULL, false, NULL, NULL, NULL, NULL),
  ('vbattery_premium',  true,  400,  25,   true,  7.5,  NULL, NULL, NULL),
  ('vbattery_max',      true,  300,  25,   true,  5.0,  NULL, NULL, NULL),
  ('viwa_basic',        false, NULL, NULL, true,  NULL, 0.75, 25,   12),
  ('viwa_plus',         true,  NULL, NULL, true,  NULL, 0.80, 50,   24),
  ('viwa_pro',          true,  NULL, NULL, true,  NULL, 0.85, 75,   24);

INSERT INTO price_list (org_id, code, name, segment, description, sort_order)
SELECT (SELECT id FROM org WHERE code = 'greenlogy_sk'), code, name, segment, description, sort FROM s_list
ON CONFLICT (code) DO NOTHING;

-- Verzie: iba ak cenník takú ešte nemá; Návrh → položky → parametre → schválenie (vlastník smie minulý dátum)
DO $$
DECLARE
  l      record;
  v_id   uuid;
  v_item uuid;
  i      record;
BEGIN
  FOR l IN SELECT s.*, p.id AS list_id FROM s_list s JOIN price_list p ON p.code = s.code ORDER BY s.sort LOOP
    CONTINUE WHEN EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = l.list_id AND name = l.version);
    INSERT INTO price_list_version (price_list_id, name, valid_from, note)
    VALUES (l.list_id, l.version, l.valid_from, 'cenník 2026 z PDF (db/seed/cenniky-2026.sql)')
    RETURNING id INTO v_id;
    FOR i IN SELECT s.*, p.id AS product_id FROM s_item s JOIN product p ON p.code = s.product
              WHERE s.list = l.code ORDER BY s.sort LOOP
      INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                                   fee_program_eur_month, fee_kw_eur_month, sort_order)
      VALUES (v_id, i.product_id, i.vt, i.nt, i.oom, i.prog, i.kw, i.sort)
      RETURNING id INTO v_item;
      INSERT INTO price_list_item_program (item_id, greencar, greencar_kwh_per_voucher, greencar_voucher_eur, greenshare,
                                           greenshare_fee_pct, viwa_conversion_factor, viwa_activation_bonus,
                                           viwa_credit_expiry_months)
      SELECT v_item, greencar, kwh, voucher, greenshare, share_pct, factor, bonus, expiry
        FROM s_program WHERE product = i.product;
    END LOOP;
    PERFORM price_list_version_approve(v_id);
  END LOOP;
END;
$$;

-- ============================================================================
-- Kontrola: počty, ceny s DPH podľa PDF, ANO = NIE − 31,24 €/MWh
-- ============================================================================

DO $$
DECLARE
  n   integer;
  bad text;
BEGIN
  n := (SELECT count(*) FROM product p JOIN s_product s ON s.code = p.code);
  ASSERT n = 40, format('produktov %s, čakám 40', n);
  n := (SELECT count(*) FROM product_tariff t JOIN product p ON p.id = t.product_id JOIN s_tariff s
          ON s.code = p.code AND s.scope = t.scope_code AND s.tariff = t.tariff_code);
  ASSERT n = 105, format('párovaní %s, čakám 105', n);
  n := (SELECT count(*) FROM price_list_version v JOIN price_list l ON l.id = v.price_list_id JOIN s_list s
          ON s.code = l.code AND s.version = v.name WHERE v.status = 'schvalena');
  ASSERT n = 6, format('schválených verzií %s, čakám 6', n);

  SELECT string_agg(format('%s/%s', s.list, s.product), ', ') INTO bad
    FROM s_item s
    LEFT JOIN price_list_item_v v ON v.product_code = s.product
     AND v.version_id = (SELECT pv.id FROM price_list_version pv JOIN price_list l ON l.id = pv.price_list_id
                          JOIN s_list sl ON sl.code = l.code WHERE l.code = s.list AND pv.name = sl.version)
   WHERE v.id IS NULL
      OR v.price_vt_eur_mwh IS DISTINCT FROM s.vt OR v.price_nt_eur_mwh IS DISTINCT FROM s.nt
      OR v.fee_oom_eur_month IS DISTINCT FROM s.oom OR v.fee_program_eur_month IS DISTINCT FROM s.prog
      OR v.fee_kw_eur_month IS DISTINCT FROM s.kw
      OR v.price_vt_with_vat IS DISTINCT FROM s.vt_pdf OR v.price_nt_with_vat IS DISTINCT FROM s.nt_pdf
      OR v.fee_oom_with_vat IS DISTINCT FROM s.oom_pdf OR v.fee_program_with_vat IS DISTINCT FROM s.prog_pdf;
  ASSERT bad IS NULL, 'ceny nesedia s PDF: ' || bad;

  SELECT string_agg(a.product, ', ') INTO bad
    FROM s_item a JOIN s_item b ON b.list = 'domacnosti_nie_energopomoc'
     AND b.product = replace(a.product, '_ano', '_nie')
   WHERE a.list = 'domacnosti_ano_energopomoc' AND a.product <> 'zem'
     AND (a.vt <> b.vt - 31.24 OR a.nt IS DISTINCT FROM b.nt - 31.24);
  ASSERT bad IS NULL, 'ANO ≠ NIE − 31,24: ' || bad;

  ASSERT (SELECT count(*) FROM price_list_item_program g JOIN price_list_item i ON i.id = g.item_id
           JOIN product p ON p.id = i.product_id WHERE p.code IN (SELECT product FROM s_program)) = 6, 'parametre programov';
  RAISE NOTICE 'OK: 40 produktov, 105 párovaní, 6 schválených cenníkov (36 položiek), ceny s DPH = PDF, ANO = NIE − 31,24';
END;
$$;

SELECT l.name AS cennik, v.name AS verzia, to_char(v.valid_from, 'FMDD. FMMM. YYYY') AS platna_od, v.state AS stav, v.item_count AS poloziek
  FROM price_list_version_v v JOIN price_list l ON l.id = v.price_list_id
 WHERE l.code IN (SELECT code FROM s_list)
 ORDER BY l.sort_order;
