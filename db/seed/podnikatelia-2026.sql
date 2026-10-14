-- Naplnenie modulu 4, F1: produkty pre firmy podľa typu tarifu a cenník „Podnikatelia nad 30 MWh“ od 1. 10. 2026
-- (dáta, nie migrácia). Predpoklad: migrácie 0023, 0024 a skript db/seed/cenniky-2026.sh.
-- Zdroj: zadanie 04-zmluvy.md v0.3 časť 5 a 14, návrh DB 04-zmluvy-navrh-db.md časť 11.3, Petrove odpovede 2 a 4
-- (13. 10. 2026) a PDF exports/cenniky-2026/GLG_Cennik_podnikatelia_nad_30MWh_od_1_10_2026.pdf.
--
-- Obsah (doplnené 14. 10. 2026: verzia „2026 (1.–9.)“ cenníka nad 30 MWh od 1. 1. do 30. 9. 2026, rovnaké ceny):
--   - produkty Green 1T Jednotarif, Green 2T Dvojtarif, Green 2T Vykurovanie, Green 1T VO (dodávka firmy; modely cenník,
--     FIX, SPOT + aditív €; typ a variant tarifu) a VBattery V (sharing, bez poplatku);
--   - Dodávka B2B → Dobieha (nahrádza ju sada Green, odpoveď 2; nemaže sa);
--   - cenník „Podnikatelia nad 30 MWh“, verzia 2026 od 1. 10. 2026 (mesačná platba za OM 5 € v položke, DPH 19 %);
--   - systémové preklady produktov pri OOM (IN GREEN 1T/2T/2T VYK, DD1–DD8, DMP1–DMP11, VBattery).
--   - cenník „VBattery V (sharing)“, verzia 2026 od 1. 1. 2026: VBattery V bezplatne (Peter, otázka 15). Samostatný cenník,
--     lebo schválená verzia Virtuálnej batérie platí od 1. 4. 2026 a nedá sa meniť ani predbehnúť;
--   - cenník „VBattery AKU (dobieha)“, verzia 2026 od 1. 1. 2026: VBattery AKU 1,00 € mesačne bez DPH (Peter, otázka 12b);
-- Nie je tu: variant verejné osvetlenie pri DMP10 (produkt je už v cenníku a variant sa mu nemení – 0023; import zmlúv
-- rozpozná DMP10 podľa kódu).
--
-- Spúšťa db/seed/podnikatelia-2026.sh (vlastník databázy, jedna transakcia). Na konci sa ceny s DPH porovnajú s PDF;
-- pri rozdiele chyba a nič sa neuloží. Opakované spustenie: existujúce produkty, cenník, verziu a preklady nechá tak.

\set ON_ERROR_STOP on
SET LOCAL app.change_source = 'system';

-- ============================================================================
-- Produkty
-- ============================================================================

CREATE TEMP TABLE s_product (code text, name text, category product_category, segment customer_segment,
  vat numeric, tariff tariff_type, variant text, models price_model[], status product_status, sort integer) ON COMMIT DROP;
INSERT INTO s_product VALUES
  ('green_1t',     'Green 1T Jednotarif',  'dodavka_firma', 'firma',     19, 'jednotarif', NULL,                 '{cennik,fix,spot_plus_eur}', 'predava_sa', 390),
  ('green_2t',     'Green 2T Dvojtarif',   'dodavka_firma', 'firma',     19, 'dvojtarif',  NULL,                 '{cennik,fix,spot_plus_eur}', 'predava_sa', 391),
  ('green_2t_vyk', 'Green 2T Vykurovanie', 'dodavka_firma', 'firma',     19, 'dvojtarif',  'vykurovanie',        '{cennik,fix,spot_plus_eur}', 'predava_sa', 392),
  ('green_1t_vo',  'Green 1T VO',          'dodavka_firma', 'firma',     19, 'jednotarif', 'verejne_osvetlenie', '{cennik,fix,spot_plus_eur}', 'predava_sa', 393),
  ('vbattery_v',   'VBattery V (sharing)', 'vbattery',      'domacnost', 23, 'netyka_sa',  NULL,                 '{cennik}',                   'predava_sa', 604);

INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, tariff_variant, price_models, price_regulation,
                     status, sort_order)
SELECT (SELECT id FROM org WHERE code = 'greenlogy_sk'), code, name, category, segment, vat, tariff, variant, models, NULL, status, sort
  FROM s_product
ON CONFLICT (code) DO NOTHING;

-- Dodávka B2B dobieha (odpoveď 2): žiadna nová zmluva ho nepoužije, nemaže sa
UPDATE product SET status = 'dobieha' WHERE code = 'dodavka_b2b' AND status = 'predava_sa';

-- ============================================================================
-- Cenník Podnikatelia nad 30 MWh (ceny bez DPH z PDF; *_pdf = „s DPH“ z PDF na kontrolu)
-- ============================================================================

CREATE TEMP TABLE s_item (product text, vt numeric, nt numeric, oom numeric, vt_pdf numeric, nt_pdf numeric, oom_pdf numeric,
  sort integer) ON COMMIT DROP;
INSERT INTO s_item VALUES
  ('green_1t',     164.00, NULL,   5.00, 195.16, NULL,   5.95, 1),
  ('green_2t',     173.00, 150.00, 5.00, 205.87, 178.50, 5.95, 2),
  ('green_2t_vyk', 168.00, 164.00, 5.00, 199.92, 195.16, 5.95, 3),
  ('green_1t_vo',  162.00, NULL,   5.00, 192.78, NULL,   5.95, 4);

INSERT INTO price_list (org_id, code, name, segment, description, sort_order)
VALUES ((SELECT id FROM org WHERE code = 'greenlogy_sk'), 'podnikatelia_nad_30mwh', 'Podnikatelia nad 30 MWh', 'firma',
        'firmy s ročnou spotrebou nad 30 MWh; cena pri prolongácii bez novej ceny (zadanie modulu 4, časť 5)', 7)
ON CONFLICT (code) DO NOTHING;

-- Verzia 2026 od 1. 10. 2026: iba ak ju cenník ešte nemá; Návrh → položky → schválenie (vlastník smie minulý dátum)
DO $$
DECLARE
  v_list uuid := (SELECT id FROM price_list WHERE code = 'podnikatelia_nad_30mwh');
  v_id   uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = v_list AND name = '2026') THEN
    RETURN;
  END IF;
  INSERT INTO price_list_version (price_list_id, name, valid_from, note)
  VALUES (v_list, '2026', '2026-10-01', 'cenník z PDF platný od 1. 10. 2026 (db/seed/podnikatelia-2026.sql)')
  RETURNING id INTO v_id;
  INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month, sort_order)
  SELECT v_id, p.id, s.vt, s.nt, s.oom, s.sort FROM s_item s JOIN product p ON p.code = s.product;
  PERFORM price_list_version_approve(v_id);
END;
$$;

-- Verzia „2026 (1.–9.)“ od 1. 1. 2026 s rovnakými cenami (Peter, 14. 10. 2026: ceny platia bez zmeny od 1. 1. 2026).
-- Schválenie ju ukončí 30. 9. 2026 (deň pred verziou 2026). Iba ak ju cenník ešte nemá.
DO $$
DECLARE
  v_list uuid := (SELECT id FROM price_list WHERE code = 'podnikatelia_nad_30mwh');
  v_id   uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = v_list AND valid_from = '2026-01-01' AND status = 'schvalena') THEN
    RETURN;
  END IF;
  INSERT INTO price_list_version (price_list_id, name, valid_from, note)
  VALUES (v_list, '2026 (1.–9.)', '2026-01-01', 'rovnaké ceny ako od 1. 10. 2026 – platia od 1. 1. 2026 (Peter, 14. 10. 2026; db/seed/podnikatelia-2026.sql)')
  RETURNING id INTO v_id;
  INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month, sort_order)
  SELECT v_id, p.id, s.vt, s.nt, s.oom, s.sort FROM s_item s JOIN product p ON p.code = s.product;
  PERFORM price_list_version_approve(v_id);
END;
$$;

-- ============================================================================
-- Cenník VBattery V (sharing) od 1. 1. 2026 – služba je bezplatná (Peter, otázka 15)
-- ============================================================================

INSERT INTO price_list (org_id, code, name, segment, description, sort_order)
VALUES ((SELECT id FROM org WHERE code = 'greenlogy_sk'), 'vbattery_v_sharing', 'VBattery V (sharing)', 'domacnost',
        'program sharingu VBattery V – prijímatelia sú virtuálne OOM „24GREENVV…“; bez mesačného poplatku', 8)
ON CONFLICT (code) DO NOTHING;

DO $$
DECLARE
  v_list uuid := (SELECT id FROM price_list WHERE code = 'vbattery_v_sharing');
  v_id   uuid;
  v_item uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = v_list AND name = '2026') THEN
    RETURN;
  END IF;
  INSERT INTO price_list_version (price_list_id, name, valid_from, note)
  VALUES (v_list, '2026', '2026-01-01', 'VBattery V bezplatne od 1. 1. 2026 (Peter, 13. 10. 2026; db/seed/podnikatelia-2026.sql)')
  RETURNING id INTO v_id;
  INSERT INTO price_list_item (version_id, product_id, fee_program_eur_month, sort_order)
  VALUES (v_id, (SELECT id FROM product WHERE code = 'vbattery_v'), 0, 1)
  RETURNING id INTO v_item;
  INSERT INTO price_list_item_program (item_id, greencar, greenshare) VALUES (v_item, false, false);
  PERFORM price_list_version_approve(v_id);
END;
$$;

-- ============================================================================
-- Cenník VBattery AKU (dobieha) od 1. 1. 2026 – 1,00 € mesačne bez DPH (Peter, otázka 12b); produkt ostáva Dobieha
-- ============================================================================

INSERT INTO price_list (org_id, code, name, segment, description, sort_order)
VALUES ((SELECT id FROM org WHERE code = 'greenlogy_sk'), 'vbattery_aku', 'VBattery AKU (dobieha)', 'domacnost',
        'program VBattery AKU pre existujúce zmluvy; nové zmluvy ho nepoužijú (stav Dobieha)', 9)
ON CONFLICT (code) DO NOTHING;

DO $$
DECLARE
  v_list uuid := (SELECT id FROM price_list WHERE code = 'vbattery_aku');
  v_id   uuid;
BEGIN
  IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = v_list AND name = '2026') THEN
    RETURN;
  END IF;
  INSERT INTO price_list_version (price_list_id, name, valid_from, note)
  VALUES (v_list, '2026', '2026-01-01', 'VBattery AKU 1,00 € mesačne bez DPH od 1. 1. 2026 (Peter, 13. 10. 2026; db/seed/podnikatelia-2026.sql)')
  RETURNING id INTO v_id;
  INSERT INTO price_list_item (version_id, product_id, fee_program_eur_month, sort_order)
  VALUES (v_id, (SELECT id FROM product WHERE code = 'vbattery_aku'), 1.00, 1);
  PERFORM price_list_version_approve(v_id);
END;
$$;

-- ============================================================================
-- Preklady produktov pri OOM (Office portal: ZOM_nazov_tarifa_glg; XM Trade: Sadzba VBATTERY-*)
-- DDx: cieľ = produkt NIE Energopomoc, target_extra.ano = produkt ANO – import vyberie podľa cenovej regulácie OOM
-- ============================================================================

CREATE TEMP TABLE s_alias (source text, name text, target text, extra jsonb) ON COMMIT DROP;
INSERT INTO s_alias VALUES
  ('office_portal', 'IN GREEN 1T',     'green_1t',     '{}'),
  ('office_portal', 'IN GREEN 2T',     'green_2t',     '{}'),
  ('office_portal', 'IN GREEN 2T VYK', 'green_2t_vyk', '{}');
INSERT INTO s_alias
SELECT 'vsetky', 'DD' || n, 'green_dd' || n || '_nie', jsonb_build_object('ano', 'green_dd' || n || '_ano')
  FROM generate_series(1, 8) n;
INSERT INTO s_alias
SELECT 'vsetky', 'DMP' || n, 'green_dmp' || n, CASE WHEN n = 10 THEN '{"verejne_osvetlenie": true}'::jsonb ELSE '{}' END
  FROM generate_series(1, 11) n;
INSERT INTO s_alias
SELECT 'office_portal', 'VBattery - ' || upper(v), 'vbattery_' || v, '{"program": true}'::jsonb FROM unnest(ARRAY['standard', 'premium', 'max', 'aku', 'v']) v
UNION ALL
SELECT 'xm_trade', 'VBATTERY-' || upper(v), 'vbattery_' || v, '{"program": true}'::jsonb FROM unnest(ARRAY['standard', 'premium', 'max', 'aku', 'v']) v;

INSERT INTO import_alias (org_id, source, kind, name_sample, target, target_extra, is_system)
SELECT (SELECT id FROM org WHERE code = 'greenlogy_sk'), source, 'produkt_oom', name, target, extra, true
  FROM s_alias
ON CONFLICT (org_id, source, kind, name_norm) DO NOTHING;

-- ============================================================================
-- Kontrola: produkty, cenník, ceny s DPH podľa PDF, preklady
-- ============================================================================

DO $$
DECLARE
  n   integer;
  bad text;
BEGIN
  n := (SELECT count(*) FROM product p JOIN s_product s ON s.code = p.code
         WHERE p.category = s.category AND p.tariff_type = s.tariff AND p.tariff_variant IS NOT DISTINCT FROM s.variant);
  ASSERT n = 5, format('produktov %s, čakám 5', n);
  ASSERT (SELECT status FROM product WHERE code = 'dodavka_b2b') = 'dobieha', 'Dodávka B2B dobieha';
  ASSERT (SELECT count(*) FROM price_list_version v JOIN price_list l ON l.id = v.price_list_id
           WHERE l.code = 'podnikatelia_nad_30mwh' AND v.name = '2026' AND v.status = 'schvalena'
             AND v.valid_from = '2026-10-01') = 1, 'schválená verzia 2026 od 1. 10. 2026';
  ASSERT (SELECT count(*) FROM price_list_version v JOIN price_list l ON l.id = v.price_list_id
           WHERE l.code = 'podnikatelia_nad_30mwh' AND v.status = 'schvalena'
             AND v.valid_from = '2026-01-01' AND v.valid_to = '2026-09-30'
             AND (SELECT count(*) FROM price_list_item i WHERE i.version_id = v.id) = 4) = 1,
         'verzia 2026 (1.–9.) od 1. 1. do 30. 9. 2026 so 4 položkami';

  SELECT string_agg(s.product, ', ') INTO bad
    FROM s_item s
    LEFT JOIN price_list_item_v v ON v.product_code = s.product
     AND v.version_id = (SELECT pv.id FROM price_list_version pv JOIN price_list l ON l.id = pv.price_list_id
                          WHERE l.code = 'podnikatelia_nad_30mwh' AND pv.name = '2026')
   WHERE v.id IS NULL
      OR v.price_vt_eur_mwh IS DISTINCT FROM s.vt OR v.price_nt_eur_mwh IS DISTINCT FROM s.nt
      OR v.fee_oom_eur_month IS DISTINCT FROM s.oom
      OR v.price_vt_with_vat IS DISTINCT FROM s.vt_pdf OR v.price_nt_with_vat IS DISTINCT FROM s.nt_pdf
      OR v.fee_oom_with_vat IS DISTINCT FROM s.oom_pdf;
  ASSERT bad IS NULL, 'ceny nesedia s PDF: ' || bad;

  ASSERT (SELECT count(*) FROM price_list_item_v v JOIN price_list_version pv ON pv.id = v.version_id
            JOIN price_list l ON l.id = pv.price_list_id
           WHERE l.code = 'vbattery_v_sharing' AND pv.name = '2026' AND pv.status = 'schvalena' AND pv.valid_from = '2026-01-01'
             AND v.product_code = 'vbattery_v' AND v.fee_program_eur_month = 0 AND v.fee_program_with_vat = 0) = 1,
         'VBattery V bezplatne od 1. 1. 2026';
  ASSERT (SELECT count(*) FROM price_list_item_v v JOIN price_list_version pv ON pv.id = v.version_id
            JOIN price_list l ON l.id = pv.price_list_id
           WHERE l.code = 'vbattery_aku' AND pv.name = '2026' AND pv.status = 'schvalena' AND pv.valid_from = '2026-01-01'
             AND v.product_code = 'vbattery_aku' AND v.fee_program_eur_month = 1.00 AND v.fee_program_with_vat = 1.23) = 1,
         'VBattery AKU 1,00 € (s DPH 1,23 €) od 1. 1. 2026';
  ASSERT (SELECT status FROM product WHERE code = 'vbattery_aku') = 'dobieha', 'VBattery AKU ostáva Dobieha';
  n := (SELECT count(*) FROM import_alias a JOIN s_alias s
          ON a.source = s.source AND a.kind = 'produkt_oom' AND a.name_norm = import_name_norm(s.name) AND a.target = s.target);
  ASSERT n = 32, format('prekladov produktov %s, čakám 32', n);
  RAISE NOTICE 'OK: 5 produktov, Dodávka B2B dobieha, cenník Podnikatelia nad 30 MWh od 1. 1. 2026 (verzie 1.–9. a od 1. 10., 4 položky, ceny s DPH = PDF), VBattery V bezplatne a VBattery AKU 1,00 € od 1. 1. 2026, 32 prekladov';
END;
$$;

SELECT p.name AS produkt, to_char(i.price_vt_eur_mwh, 'FM990.00') AS vt, to_char(i.price_nt_eur_mwh, 'FM990.00') AS nt,
       to_char(i.fee_oom_eur_month, 'FM990.00') AS platba_om, to_char(v.price_vt_with_vat, 'FM990.00') AS vt_s_dph,
       to_char(v.price_nt_with_vat, 'FM990.00') AS nt_s_dph
  FROM price_list_item i
  JOIN price_list_item_v v ON v.id = i.id
  JOIN product p ON p.id = i.product_id
  JOIN price_list_version pv ON pv.id = i.version_id
  JOIN price_list l ON l.id = pv.price_list_id
 WHERE l.code = 'podnikatelia_nad_30mwh'
 ORDER BY i.sort_order;
