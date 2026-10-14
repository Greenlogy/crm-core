-- Kontroly nočného behu zmlúv (0028, návrh DB časť 27): prolongácia (bez nástupcu, retencia, čiastočný nástupca,
-- dobehnutie viacerých rokov, verejné osvetlenie, bez prolongácie), upozornenie 4 mesiace pred koncom raz, časový rez
-- pri zmene regulácie (domácnosť ANO → NIE; chýbajúci pár ANO ↔ NIE = chyba v denníku), prechod na novú verziu cenníka
-- (audit iba zmien, spätne platná cena v denníku), OOM bez dodávky sa nepredlžuje, zmluva bez aktívneho OOM = Ukončená,
-- chyba jednej zmluvy nezastaví beh a dobehne sa, druhé spustenie nič nezmení, testovací dátum z aplikácie nefunguje,
-- upozornenia na udalosti a RLS, stav zákazníka.
-- Spúšťa sa iba cez db/test/run.sh po checks_zmluvy_bilancia.sql. Predpoklad: skripty cenníkov 2026 a podnikatelia-2026.
-- Beh spracuje aj iné zmluvy v databáze (Test); kontroly sa pozerajú iba na vlastné záznamy (…-0000000075xx/76xx/77xx).

-- Obchodník Z4 (7501), firma a domácnosť obchodníka, firma bez vlastníka
INSERT INTO app_user (id, email, name, team_id, status, seller_type)
SELECT '00000000-0000-4000-8000-000000007501', 'obchodnik.z4@example.test', 'Obchodník Z4', t.id, 'aktivny', 'obchodnik'
  FROM team t WHERE t.code = 'sales_internal';
INSERT INTO app_user_org (user_id, org_id) VALUES ('00000000-0000-4000-8000-000000007501', crm_default_org());
INSERT INTO company (id, name, ico, is_customer, owner_id) VALUES
  ('00000000-0000-4000-8000-000000007511', 'Nočný beh Z4 s.r.o.', '99999941', true, '00000000-0000-4000-8000-000000007501'),
  ('00000000-0000-4000-8000-000000007512', 'Bez obchodníka Z4 s.r.o.', '99999942', true, '00000000-0000-4000-8000-000000007501'),
  ('00000000-0000-4000-8000-000000007513', 'Budúca zmluva Z4 s.r.o.', '99999943', true, NULL),
  ('00000000-0000-4000-8000-000000007515', 'Malý podnik Z4 s.r.o.', '99999944', true, '00000000-0000-4000-8000-000000007501');
INSERT INTO contact (id, first_name, last_name, email, is_household, owner_id) VALUES
  ('00000000-0000-4000-8000-000000007514', 'Domácnosť', 'Nočný beh Z4', 'nocny.z4@example.test', true, '00000000-0000-4000-8000-000000007501');

CREATE FUNCTION pg_temp.z4_eic(p_n integer) RETURNS text LANGUAGE plpgsql AS $f$
DECLARE
  l text;
  c text;
BEGIN
  FOREACH l IN ARRAY string_to_array('KLMNPQRSTUVW', NULL) LOOP
    FOREACH c IN ARRAY string_to_array('0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ', NULL) LOOP
      IF eic_is_valid('24ZZS000NOCB' || l || lpad(p_n::text, 2, '0') || c) THEN
        RETURN '24ZZS000NOCB' || l || lpad(p_n::text, 2, '0') || c;
      END IF;
    END LOOP;
  END LOOP;
END;
$f$;
CREATE FUNCTION pg_temp.z4_id(p_kind text, p_n integer) RETURNS uuid LANGUAGE sql AS $f$
  SELECT ('00000000-0000-4000-8000-0000000' || CASE p_kind WHEN 'oom' THEN '76' ELSE '77' END || lpad(p_n::text, 3, '0'))::uuid
$f$;
-- OOM firmy Z4 (alebo domácnosti); Odídené / Zrušené cez oom_set_status k 15. 11. 2026
CREATE FUNCTION pg_temp.z4_oom(p_n integer, p_person boolean DEFAULT false, p_lighting boolean DEFAULT false,
                               p_regulation boolean DEFAULT NULL, p_status text DEFAULT 'pripravovane',
                               p_supply_to date DEFAULT NULL,
                               p_company uuid DEFAULT '00000000-0000-4000-8000-000000007511') RETURNS uuid
LANGUAGE plpgsql AS $f$
BEGIN
  INSERT INTO oom (id, company_id, person_id, eic, type, status, public_lighting, price_regulation, supply_to)
  VALUES (pg_temp.z4_id('oom', p_n), CASE WHEN p_person THEN NULL ELSE p_company END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000007514'::uuid END, pg_temp.z4_eic(p_n), 'spotreba',
          'pripravovane', p_lighting, p_regulation, p_supply_to);
  IF p_status <> 'pripravovane' THEN
    PERFORM oom_set_status(pg_temp.z4_id('oom', p_n), p_status::oom_status, '2026-11-15');
  END IF;
  RETURN pg_temp.z4_id('oom', p_n);
END;
$f$;
-- Zmluva (vlastník databázy = ako import)
CREATE FUNCTION pg_temp.z4_k(p_n integer, p_type text, p_from date, p_to date, p_signed date, p_prolong boolean DEFAULT true,
                             p_owner uuid DEFAULT '00000000-0000-4000-8000-000000007501', p_list boolean DEFAULT false,
                             p_person boolean DEFAULT false,
                             p_company uuid DEFAULT '00000000-0000-4000-8000-000000007511') RETURNS uuid LANGUAGE sql AS $f$
  INSERT INTO contract (id, number, company_id, person_id, type, phase, valid_from, valid_to, signed_on, owner_id, list_price,
                        auto_prolong, small_business)
  VALUES (pg_temp.z4_id('k', p_n), 'Z4-' || p_n, CASE WHEN p_person THEN NULL ELSE p_company END,
          CASE WHEN p_person THEN '00000000-0000-4000-8000-000000007514'::uuid END, p_type::contract_type, 'podpisana',
          p_from, p_to, p_signed, p_owner, p_list, p_prolong, p_list AND NOT p_person)
  RETURNING id
$f$;
CREATE FUNCTION pg_temp.z4_ko(p_k integer, p_o integer, p_product text, p_vt numeric DEFAULT 10, p_nt numeric DEFAULT 0)
RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, qty_nt_mwh, product_id)
  VALUES (pg_temp.z4_id('k', p_k), pg_temp.z4_id('oom', p_o), p_vt, p_nt, (SELECT id FROM product WHERE code = p_product))
$f$;
-- Individuálna cena FIX pre všetky OOM zmluvy (VT, pri dvojtarife aj NT)
CREATE FUNCTION pg_temp.z4_fix(p_k integer, p_vt numeric, p_from date, p_to date) RETURNS void LANGUAGE sql AS $f$
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh)
  SELECT co.contract_id, co.oom_id, 'komodita', co.product_id, 'fix', p_from, p_to, p_vt,
         CASE WHEN co.qty_nt_mwh > 0 THEN p_vt - 20 END
    FROM contract_oom co WHERE co.contract_id = pg_temp.z4_id('k', p_k)
$f$;
CREATE FUNCTION pg_temp.z4_ready(p_k integer) RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  PERFORM contract_price_list_sync(pg_temp.z4_id('k', p_k));
  PERFORM contract_after_price_change(pg_temp.z4_id('k', p_k));
END;
$f$;
-- Cena komodity OOM zmluvy k dňu: produkt a VT
CREATE FUNCTION pg_temp.z4_price(p_k integer, p_o integer, p_on date) RETURNS text LANGUAGE sql AS $f$
  SELECT string_agg(pr.code || ' ' || cp.price_model || ' ' || coalesce(cp.price_vt_eur_mwh::numeric(12,2)::text, '-'), '; ')
    FROM contract_price cp JOIN product pr ON pr.id = cp.product_id
   WHERE cp.contract_id = pg_temp.z4_id('k', p_k) AND cp.oom_id = pg_temp.z4_id('oom', p_o) AND cp.slot = 'komodita'
     AND p_on BETWEEN cp.valid_from AND coalesce(cp.valid_to, 'infinity')
$f$;
CREATE FUNCTION pg_temp.z4_end(p_k integer) RETURNS date LANGUAGE sql AS $f$
  SELECT contract_effective_to(k) FROM contract k WHERE k.id = pg_temp.z4_id('k', p_k)
$f$;
CREATE FUNCTION pg_temp.z4_notes(p_k integer, p_kind text) RETURNS bigint LANGUAGE sql AS $f$
  SELECT count(*) FROM notification WHERE contract_id = pg_temp.z4_id('k', p_k) AND kind = p_kind
$f$;

-- Z4-1. Upozornenie 4 mesiace pred koncom (firmy a výkup, raz; nie pri nadväzujúcej zmluve ani domácnosti)
DO $$
DECLARE
  r jsonb;
BEGIN
  -- 1: firma do 30. 4. 2027 bez prolongácie; 2: to isté s nadväzujúcou zmluvou 3; 4: firma bez obchodníka;
  -- 5: domácnosť do 30. 4. 2027
  PERFORM pg_temp.z4_k(1, 'dodavka_firma_nn', '2026-05-01', '2027-04-30', '2026-04-01', false);
  PERFORM pg_temp.z4_oom(1);
  PERFORM pg_temp.z4_ko(1, 1, 'green_1t');
  PERFORM pg_temp.z4_k(2, 'dodavka_firma_nn', '2026-05-01', '2027-04-30', '2026-04-01', false);
  PERFORM pg_temp.z4_oom(2);
  PERFORM pg_temp.z4_ko(2, 2, 'green_1t');
  PERFORM pg_temp.z4_k(3, 'dodavka_firma_nn', '2027-05-01', '2027-12-31', '2026-10-01', false);
  PERFORM pg_temp.z4_ko(3, 2, 'green_1t');
  PERFORM pg_temp.z4_k(4, 'dodavka_firma_nn', '2026-05-01', '2027-04-30', '2026-04-01', false, NULL,
                       p_company => '00000000-0000-4000-8000-000000007512');
  PERFORM pg_temp.z4_oom(4);
  PERFORM pg_temp.z4_ko(4, 4, 'green_1t');
  -- 6: firma s jediným OOM Odídené – bez upozornenia (nepredĺži sa ani nebude čo dojednať)
  PERFORM pg_temp.z4_k(6, 'dodavka_firma_nn', '2026-05-01', '2027-04-30', '2026-04-01', false);
  PERFORM pg_temp.z4_oom(6, p_status => 'odidene');
  PERFORM pg_temp.z4_ko(6, 6, 'green_1t');
  PERFORM pg_temp.z4_k(5, 'dodavka_domacnost', '2026-05-01', '2027-04-30', '2026-04-01', false, p_person => true);
  PERFORM pg_temp.z4_oom(5, true);
  PERFORM pg_temp.z4_ko(5, 5, 'green_dd2_nie');

  r := contract_daily_run_at('2026-12-29');   -- 30. 4. 2027 − 4 mesiace = 30. 12. 2026 → ešte nie
  ASSERT pg_temp.z4_notes(1, 'konci_4_mesiace') = 0, '29. 12. bez upozornenia';
  r := contract_daily_run_at('2026-12-30');
  ASSERT (SELECT array_agg(user_id) FROM notification WHERE contract_id = pg_temp.z4_id('k', 1) AND kind = 'konci_4_mesiace')
         = ARRAY['00000000-0000-4000-8000-000000007501'::uuid]
     AND (SELECT ref_date FROM notification WHERE contract_id = pg_temp.z4_id('k', 1) AND kind = 'konci_4_mesiace') = '2027-04-30',
         'upozornenie obchodníkovi zmluvy s koncom 30. 4. 2027';
  ASSERT pg_temp.z4_notes(2, 'konci_4_mesiace') = 0, 'na OOM nadväzuje podpísaná zmluva → bez upozornenia';
  ASSERT (SELECT array_agg(user_id) FROM notification WHERE contract_id = pg_temp.z4_id('k', 4) AND kind = 'konci_4_mesiace')
         = ARRAY['00000000-0000-4000-8000-000000007501'::uuid], 'zmluva bez obchodníka → vlastník zákazníka (odpoveď 35)';
  ASSERT pg_temp.z4_notes(5, 'konci_4_mesiace') = 0, 'domácnosť bez upozornenia (odpoveď 34)';
  ASSERT pg_temp.z4_notes(6, 'konci_4_mesiace') = 0, 'zmluva bez Aktívneho / Pripravovaného OOM bez upozornenia';
  r := contract_daily_run_at('2026-12-31');
  ASSERT pg_temp.z4_notes(1, 'konci_4_mesiace') = 1, 'upozornenie iba raz';
  ASSERT crm_today() = (now() AT TIME ZONE 'Europe/Bratislava')::date, 'po behu platí znova skutočný dnešok';
  RAISE NOTICE 'OK: Z4-1 upozornenie 4 mesiace pred koncom raz, obchodník alebo vlastník zákazníka, nie pri nadväzujúcej zmluve, domácnosti ani bez aktívneho OOM';
END;
$$;

-- Z4-2. Automatická prolongácia
DO $$
DECLARE
  r      jsonb;
  v_rows bigint;
BEGIN
  -- 10: firma FIX 2026 s prolongáciou, OOM 1T, 2T a 1T s verejným osvetlením
  PERFORM pg_temp.z4_k(10, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z4_oom(10); PERFORM pg_temp.z4_oom(11); PERFORM pg_temp.z4_oom(12, false, true);
  PERFORM pg_temp.z4_ko(10, 10, 'green_1t'); PERFORM pg_temp.z4_ko(10, 11, 'green_2t', 6, 4); PERFORM pg_temp.z4_ko(10, 12, 'green_1t');
  PERFORM pg_temp.z4_fix(10, 140, '2026-01-01', '2026-12-31');
  PERFORM pg_temp.z4_ready(10);
  -- 11: retencia bez prekrytia (nová 12 od 1. 1. 2027); 13: čiastočný nástupca (14 na jednom z dvoch OOM od 1. 4. 2027)
  PERFORM pg_temp.z4_k(11, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z4_oom(13); PERFORM pg_temp.z4_ko(11, 13, 'green_1t');
  PERFORM pg_temp.z4_fix(11, 140, '2026-01-01', '2026-12-31');
  PERFORM pg_temp.z4_k(12, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-11-15', false);
  PERFORM pg_temp.z4_ko(12, 13, 'green_1t');
  PERFORM pg_temp.z4_k(13, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z4_oom(14); PERFORM pg_temp.z4_oom(15);
  PERFORM pg_temp.z4_ko(13, 14, 'green_1t'); PERFORM pg_temp.z4_ko(13, 15, 'green_1t');
  PERFORM pg_temp.z4_fix(13, 140, '2026-01-01', '2026-12-31');
  PERFORM pg_temp.z4_k(14, 'dodavka_firma_nn', '2027-04-01', '2027-12-31', '2026-12-15', false);
  PERFORM pg_temp.z4_ko(14, 15, 'green_1t');
  -- 18: dve OOM predĺžené, jedno Odídené a jedno s koncom dodávky 30. 11. 2026 nie (bod 1);
  -- 19: žiadne Aktívne / Pripravované OOM → Ukončená
  PERFORM pg_temp.z4_k(18, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z4_oom(18); PERFORM pg_temp.z4_oom(19, p_status => 'odidene');
  PERFORM pg_temp.z4_oom(22, p_supply_to => '2026-11-30');
  PERFORM pg_temp.z4_ko(18, 18, 'green_1t'); PERFORM pg_temp.z4_ko(18, 19, 'green_1t'); PERFORM pg_temp.z4_ko(18, 22, 'green_1t');
  PERFORM pg_temp.z4_fix(18, 140, '2026-01-01', '2026-12-31');
  PERFORM pg_temp.z4_k(19, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01');
  PERFORM pg_temp.z4_oom(23, p_status => 'odidene'); PERFORM pg_temp.z4_oom(24, p_status => 'zrusene');
  PERFORM pg_temp.z4_ko(19, 23, 'green_1t'); PERFORM pg_temp.z4_ko(19, 24, 'green_1t');
  PERFORM pg_temp.z4_fix(19, 140, '2026-01-01', '2026-12-31');
  -- 15: bez automatickej prolongácie; 16: skončila 31. 12. 2025 (vynechané roky sa dobehnú naraz)
  PERFORM pg_temp.z4_k(15, 'dodavka_firma_nn', '2026-01-01', '2026-12-31', '2025-11-01', false);
  PERFORM pg_temp.z4_oom(16); PERFORM pg_temp.z4_ko(15, 16, 'green_1t');
  PERFORM pg_temp.z4_k(16, 'vykup', '2025-01-01', '2025-12-31', '2024-11-01');
  PERFORM pg_temp.z4_oom(17); PERFORM pg_temp.z4_ko(16, 17, NULL);

  r := contract_daily_run_at('2026-12-31');
  ASSERT pg_temp.z4_end(10) = '2026-12-31', 'v posledný deň účinnosti sa ešte nepredlžuje';
  ASSERT pg_temp.z4_end(16) = '2026-12-31', 'výkup skončený 2025 dobehnutý o rok (do 31. 12. 2026)';
  r := contract_daily_run_at('2027-01-01');
  ASSERT (r ->> 'prolongovane')::int >= 3, 'počet prolongácií ' || r::text;
  ASSERT pg_temp.z4_end(10) = '2027-12-31'
     AND NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = pg_temp.z4_id('k', 10) AND valid_to <> '2027-12-31'),
         'zmluva 10 aj všetky OOM do 31. 12. 2027';
  ASSERT pg_temp.z4_price(10, 10, '2027-06-01') = 'green_1t cennik 164.00'
     AND pg_temp.z4_price(10, 11, '2027-06-01') = 'green_2t cennik 173.00'
     AND pg_temp.z4_price(10, 12, '2027-06-01') = 'green_1t_vo cennik 162.00'
     AND pg_temp.z4_price(10, 10, '2026-06-01') = 'green_1t fix 140.00',
         'ceny prolongácie z cenníka nad 30 MWh (1T, 2T, VO), rok 2026 bez zmeny';
  ASSERT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z4_id('k', 10) AND code = 'sprolongovane_bez_ceny'
                    AND resolved_at IS NULL AND detail LIKE '%31. 12. 2027%'), 'príznak Sprolongované bez novej ceny';
  ASSERT NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z4_id('k', 10) AND code = 'chyba_cena' AND resolved_at IS NULL),
         'prolongovaná zmluva bez „Chýba cena“';
  ASSERT (SELECT ref_date FROM notification WHERE contract_id = pg_temp.z4_id('k', 10) AND kind = 'sprolongovana'
             AND user_id = '00000000-0000-4000-8000-000000007501') = '2027-12-31', 'upozornenie obchodníkovi o prolongácii';
  ASSERT pg_temp.z4_end(11) = '2026-12-31'
     AND (SELECT successor_id FROM contract_oom WHERE contract_id = pg_temp.z4_id('k', 11)) = pg_temp.z4_id('k', 12)
     AND NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z4_id('k', 11) AND code = 'sprolongovane_bez_ceny'),
         'retencia: bez prolongácie, nástupca = nová zmluva';
  ASSERT pg_temp.z4_end(13) = '2027-12-31'
     AND (SELECT valid_to FROM contract_oom WHERE contract_id = pg_temp.z4_id('k', 13) AND oom_id = pg_temp.z4_id('oom', 14)) = '2027-12-31'
     AND (SELECT valid_to::text || '/' || (successor_id = pg_temp.z4_id('k', 14))::text FROM contract_oom
           WHERE contract_id = pg_temp.z4_id('k', 13) AND oom_id = pg_temp.z4_id('oom', 15)) = '2027-03-31/true',
         'čiastočný nástupca: druhé OOM do 31. 3. 2027';
  ASSERT pg_temp.z4_end(15) = '2026-12-31', 'bez automatickej prolongácie sa nepredlžuje';
  ASSERT pg_temp.z4_end(18) = '2027-12-31'
     AND (SELECT valid_to FROM contract_oom WHERE contract_id = pg_temp.z4_id('k', 18) AND oom_id = pg_temp.z4_id('oom', 18)) = '2027-12-31'
     AND (SELECT string_agg(valid_to::text || '/' || end_fixed::text, ',' ORDER BY oom_id) FROM contract_oom
           WHERE contract_id = pg_temp.z4_id('k', 18) AND oom_id <> pg_temp.z4_id('oom', 18)) = '2026-12-31/true,2026-12-31/true'
     AND pg_temp.z4_price(18, 19, '2027-06-01') IS NULL AND pg_temp.z4_price(18, 22, '2027-06-01') IS NULL,
         'predĺžené iba Pripravované OOM; Odídené a s koncom dodávky ostávajú do 31. 12. 2026 bez ceny';
  ASSERT (SELECT phase FROM contract WHERE id = pg_temp.z4_id('k', 19)) = 'ukoncena' AND pg_temp.z4_end(19) = '2026-12-31'
     AND (SELECT ref_date FROM notification WHERE contract_id = pg_temp.z4_id('k', 19) AND kind = 'neprolongovana'
             AND user_id = '00000000-0000-4000-8000-000000007501') = '2026-12-31'
     AND NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z4_id('k', 19) AND code = 'sprolongovane_bez_ceny'),
         'bez Aktívneho / Pripravovaného OOM: neprolongovaná, fáza Ukončená, upozornenie obchodníkovi';
  ASSERT (r ->> 'ukoncene')::int >= 1, 'počet ukončených ' || r::text;
  ASSERT pg_temp.z4_end(16) = '2027-12-31', 'výkup ďalší rok';

  -- druhé spustenie v ten istý deň nič nezmení
  SELECT count(*) INTO v_rows FROM contract_price WHERE contract_id = pg_temp.z4_id('k', 10);
  r := contract_daily_run_at('2027-01-01');
  ASSERT (SELECT count(*) FROM contract_price WHERE contract_id = pg_temp.z4_id('k', 10)) = v_rows
     AND pg_temp.z4_end(10) = '2027-12-31' AND pg_temp.z4_notes(10, 'sprolongovana') = 1
     AND pg_temp.z4_notes(19, 'neprolongovana') = 1 AND pg_temp.z4_end(18) = '2027-12-31', 'druhé spustenie nič nezmení';
  -- zmena konca zmluvy z Office portálu OOM s pevným koncom nepredĺži
  UPDATE contract SET valid_to = '2027-12-31' WHERE id = pg_temp.z4_id('k', 18);
  ASSERT (SELECT count(*) FROM contract_oom WHERE contract_id = pg_temp.z4_id('k', 18) AND valid_to = '2026-12-31') = 2,
         'OOM s pevným koncom ostáva pri zmene konca zmluvy';
  -- nová zmluva počas prolongácie (retencia od 1. 4. 2027) skráti prolongáciu a uzavrie príznak (0025)
  PERFORM pg_temp.z4_k(17, 'dodavka_firma_nn', '2027-04-01', '2027-12-31', '2027-02-01', false);
  PERFORM pg_temp.z4_ko(17, 10, 'green_1t'); PERFORM pg_temp.z4_ko(17, 11, 'green_2t'); PERFORM pg_temp.z4_ko(17, 12, 'green_1t');
  ASSERT pg_temp.z4_end(10) = '2027-03-31'
     AND pg_temp.z4_price(10, 10, '2027-05-01') IS NULL AND pg_temp.z4_price(10, 10, '2027-03-01') = 'green_1t cennik 164.00'
     AND NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = pg_temp.z4_id('k', 10) AND code = 'sprolongovane_bez_ceny'
                        AND resolved_at IS NULL), 'retencia počas prolongácie skráti prolongáciu';
  RAISE NOTICE 'OK: Z4-2 prolongácia (cenník nad 30 MWh 1T/2T/VO, príznak, upozornenie), iba Aktívne/Pripravované OOM, bez nich Ukončená s upozornením, retencia, čiastočný nástupca, bez prolongácie, dobehnutie rokov, druhé spustenie, retencia počas prolongácie';
END;
$$;

-- Z4-3. Časový rez pri zmene regulácie a prechod na novú verziu cenníka
DO $$
DECLARE
  r       jsonb;
  v_row   uuid;
  v_ver   uuid;
  v_new   uuid;
  v_err   jsonb;
BEGIN
  -- 20: domácnosť DD2 ANO na dobu neurčitú; 21: malý podnik DMP1 do konca 2027
  PERFORM pg_temp.z4_k(20, 'dodavka_domacnost', '2026-01-01', NULL, '2025-12-01', false, p_list => true, p_person => true);
  PERFORM pg_temp.z4_oom(20, true, false, true);
  PERFORM pg_temp.z4_ko(20, 20, 'green_dd2_ano');
  PERFORM pg_temp.z4_ready(20);
  SELECT id INTO v_row FROM contract_price
   WHERE contract_id = pg_temp.z4_id('k', 20) AND slot = 'komodita' AND valid_from = '2026-01-01';
  PERFORM pg_temp.z4_k(21, 'dodavka_firma_nn', '2026-01-01', '2027-12-31', '2025-12-01', false, p_list => true,
                       p_company => '00000000-0000-4000-8000-000000007515');
  PERFORM pg_temp.z4_oom(21, false, false, true, p_company => '00000000-0000-4000-8000-000000007515');
  PERFORM pg_temp.z4_ko(21, 21, 'green_dmp1');
  PERFORM pg_temp.z4_ready(21);
  ASSERT pg_temp.z4_price(20, 20, '2027-06-01') LIKE 'green_dd2_ano cennik %'
     AND pg_temp.z4_price(21, 21, '2027-06-01') LIKE 'green_dmp1 cennik %', 'východisko: ANO a DMP1 bez konca';

  -- zmena regulácie s budúcim dátumom: domácnosť NIE od 1. 3. 2027, malý podnik vyradený od 1. 2. 2027
  PERFORM oom_price_regulation_set(pg_temp.z4_id('oom', 20), false, '2027-03-01');
  PERFORM oom_price_regulation_set(pg_temp.z4_id('oom', 21), false, '2027-02-01');
  ASSERT (SELECT prev_value FROM oom_price_regulation_change WHERE oom_id = pg_temp.z4_id('oom', 20)), 'hodnota pred zmenou = ANO';
  r := contract_daily_run_at('2027-01-15');
  ASSERT pg_temp.z4_price(20, 20, '2027-06-01') LIKE 'green_dd2_ano %', 'pred dátumom zmeny sa ceny nemenia';
  r := contract_daily_run_at('2027-03-01');
  ASSERT pg_temp.z4_price(20, 20, '2027-02-28') LIKE 'green_dd2_ano cennik %'
     AND pg_temp.z4_price(20, 20, '2027-03-01') LIKE 'green_dd2_nie cennik %',
         'domácnosť: ANO do 28. 2., NIE od 1. 3. 2027 – ' || coalesce(pg_temp.z4_price(20, 20, '2027-03-01'), '–');
  ASSERT EXISTS (SELECT 1 FROM contract_price p JOIN product pr ON pr.id = p.product_id
                  WHERE p.contract_id = pg_temp.z4_id('k', 20) AND p.slot = 'zem' AND p.valid_from = '2027-03-01'),
         'ZEM od 1. 3. z cenníka NIE';
  ASSERT (SELECT valid_to FROM contract_price WHERE id = v_row) = '2027-02-28'
     AND EXISTS (SELECT 1 FROM audit_log WHERE record_id = v_row AND action = 'update' AND source = 'system'),
         'pôvodný riadok sa iba skrátil (audit úprava so zdrojom Systém), nezmazal';
  -- malý podnik vyradený: k DMP1 nie je pár NIE → chyba zmluvy v denníku, ceny bez zmeny, ďalšiu noc znova (bod 2)
  ASSERT pg_temp.z4_price(21, 21, '2027-06-01') LIKE 'green_dmp1 cennik %', 'malý podnik: ceny ostávajú do vyriešenia';
  SELECT e INTO v_err FROM job_run j, jsonb_array_elements(j.errors) e
   WHERE j.run_date = '2027-03-01' AND e ->> 'zmluva' = pg_temp.z4_id('k', 21)::text;
  ASSERT v_err ->> 'krok' = 'regulacia' AND v_err ->> 'text' LIKE '%chýba pár pre cenovú reguláciu NIE od 1. 2. 2027%'
     AND v_err ->> 'text' LIKE '%24Z…%' AND position(pg_temp.z4_eic(21) IN v_err ->> 'text') = 0,
         'chýbajúci pár: chyba v denníku so skráteným EIC – ' || coalesce(v_err::text, 'žiadna');
  ASSERT (SELECT contract_applied_at IS NULL FROM oom_price_regulation_change WHERE oom_id = pg_temp.z4_id('oom', 21))
     AND EXISTS (SELECT 1 FROM notification n JOIN job_run j ON j.id = n.job_run_id
                  WHERE n.kind = 'nocny_beh_chyba' AND j.run_date = '2027-03-01'), 'zmena nespracovaná, admin upozornený';
  r := contract_daily_run_at('2027-03-02');
  ASSERT EXISTS (SELECT 1 FROM job_run j, jsonb_array_elements(j.errors) e
                  WHERE j.run_date = '2027-03-02' AND e ->> 'zmluva' = pg_temp.z4_id('k', 21)::text), 'ďalšiu noc znova';
  ASSERT (SELECT contract_applied_at IS NOT NULL FROM oom_price_regulation_change WHERE oom_id = pg_temp.z4_id('oom', 20)),
         'zmena regulácie spracovaná';
  -- ďalší import po dátume zmeny (produkt podľa dnešnej regulácie = NIE) rez nezruší
  PERFORM set_config('crm.today', '2027-03-02', true);
  UPDATE contract_oom SET product_id = (SELECT id FROM product WHERE code = 'green_dd2_nie')
   WHERE contract_id = pg_temp.z4_id('k', 20);
  ASSERT NOT contract_price_list_sync(pg_temp.z4_id('k', 20)), 'import s produktom NIE nemení ceny';
  PERFORM set_config('crm.today', '', true);

  -- nová verzia cenníka Domácnosti NIE od 1. 6. 2027 (VT +10 €): rez v deň účinnosti
  SELECT v.id INTO v_ver FROM price_list_version v JOIN price_list l ON l.id = v.price_list_id
   WHERE l.code = 'domacnosti_nie_energopomoc' AND l.org_id = crm_default_org() AND v.status = 'schvalena' AND v.valid_to IS NULL;
  v_new := (price_list_version_copy(v_ver, 'Z4 2027', '2027-06-01') ->> 'version_id')::uuid;
  UPDATE price_list_item SET price_vt_eur_mwh = price_vt_eur_mwh + 10 WHERE version_id = v_new;
  PERFORM price_list_version_approve(v_new);
  r := contract_daily_run_at('2027-06-05');   -- prvá noc po schválení, platnosť od 1. 6. je už v minulosti
  ASSERT (r ->> 'cennik')::int >= 1, 'krok cenník ' || r::text;
  ASSERT r -> 'cennik_spatne' -> 'zmluvy' ? 'Z4-20' AND (r -> 'cennik_spatne' ->> 'pocet')::int >= 1,
         'spätne platná cena: zmluva v zozname denníka – ' || r::text;
  ASSERT (SELECT p.valid_to FROM contract_price p JOIN price_list_item i ON i.id = p.price_list_item_id
           WHERE p.contract_id = pg_temp.z4_id('k', 20) AND p.slot = 'komodita' AND i.version_id = v_ver) = '2027-05-31'
     AND (SELECT p.price_vt_eur_mwh - i0.price_vt_eur_mwh FROM contract_price p
            JOIN price_list_item i ON i.id = p.price_list_item_id
            JOIN price_list_item i0 ON i0.version_id = v_ver AND i0.product_id = i.product_id
           WHERE p.contract_id = pg_temp.z4_id('k', 20) AND p.slot = 'komodita' AND i.version_id = v_new) = 10,
         'nová verzia: stará cena do 31. 5., nová od 1. 6. 2027 (+10)';
  RAISE NOTICE 'OK: Z4-3 regulácia (ANO → NIE v deň zmeny, ZEM, audit iba skrátenia, import rez nezruší; chýbajúci pár = chyba v denníku, admin, znova ďalšiu noc), nová verzia cenníka (spätne od 1. 6., zoznam zmlúv v denníku)';
END;
$$;

-- Z4-4. Chyba jednej zmluvy nezastaví beh, zapíše sa bez EIC a dobehne sa ďalšiu noc
CREATE FUNCTION z4_fail() RETURNS trigger LANGUAGE plpgsql AS $f$
BEGIN
  IF NEW.id = '00000000-0000-4000-8000-000000077030' THEN
    RAISE EXCEPTION 'Test Z4: OOM % zlyhalo', (SELECT eic FROM oom WHERE id = '00000000-0000-4000-8000-000000076030');
  END IF;
  RETURN NEW;
END;
$f$;
CREATE TRIGGER z4_fail BEFORE UPDATE ON contract FOR EACH ROW EXECUTE FUNCTION z4_fail();
DO $$
DECLARE
  r      jsonb;
  v_err  jsonb;
  v_eic  text := pg_temp.z4_eic(30);
BEGIN
  PERFORM pg_temp.z4_k(30, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-11-01');
  PERFORM pg_temp.z4_oom(30); PERFORM pg_temp.z4_ko(30, 30, 'green_1t');
  PERFORM pg_temp.z4_k(31, 'dodavka_firma_nn', '2027-01-01', '2027-12-31', '2026-11-01');
  PERFORM pg_temp.z4_oom(31); PERFORM pg_temp.z4_ko(31, 31, 'green_1t');
  r := contract_daily_run_at('2028-01-01');
  SELECT e INTO v_err FROM job_run j, jsonb_array_elements(j.errors) e
   WHERE j.run_date = '2028-01-01' AND e ->> 'zmluva' = pg_temp.z4_id('k', 30)::text;
  ASSERT v_err ->> 'krok' = 'prolongacia' AND v_err ->> 'kod' = 'P0001'
     AND v_err ->> 'text' LIKE '%24Z…%' AND position(v_eic IN v_err ->> 'text') = 0,
         'chyba zapísaná s krokom a kódom, EIC skrátené – ' || coalesce(v_err::text, 'žiadna');
  ASSERT pg_temp.z4_end(30) = '2027-12-31' AND pg_temp.z4_end(31) = '2028-12-31', 'chybná zmluva vrátená, ostatné pokračujú';
  ASSERT (SELECT test_date FROM job_run WHERE run_date = '2028-01-01' ORDER BY started_at DESC LIMIT 1), 'beh k inému dátumu = testovací';
  ASSERT EXISTS (SELECT 1 FROM notification n JOIN job_run j ON j.id = n.job_run_id
                  WHERE n.kind = 'nocny_beh_chyba' AND j.run_date = '2028-01-01'), 'admin dostal upozornenie o chybe';
  DROP TRIGGER z4_fail ON contract;
  r := contract_daily_run_at('2028-01-02');
  ASSERT pg_temp.z4_end(30) = '2028-12-31', 'ďalšia noc zmluvu dobehne';
  RAISE NOTICE 'OK: Z4-4 chyba jednej zmluvy: ostatné pokračujú, záznam v job_run bez EIC, upozornenie admina, dobehnutie ďalšiu noc';
END;
$$;
DROP FUNCTION z4_fail();

-- Z4-5. Stav zákazníka: zmluva s budúcou účinnosťou → po začiatku sa stav prepočíta
DO $$
DECLARE
  r jsonb;
BEGIN
  UPDATE app_setting SET value = 'true' WHERE key = 'customer_status_auto';
  PERFORM pg_temp.z4_k(40, 'dodavka_firma_nn', '2029-01-01', '2029-12-31', '2026-10-01', false,
                       p_company => '00000000-0000-4000-8000-000000007513');
  PERFORM customer_refresh('00000000-0000-4000-8000-000000007513', NULL);
  ASSERT (SELECT status FROM company WHERE id = '00000000-0000-4000-8000-000000007513') = 'cakajuci_zakaznik', 'pred začiatkom Čakajúci';
  r := contract_daily_run_at('2029-01-01');
  ASSERT (SELECT status FROM company WHERE id = '00000000-0000-4000-8000-000000007513') <> 'cakajuci_zakaznik',
         'po začiatku účinnosti stav prepočítaný';
  UPDATE app_setting SET value = 'false' WHERE key = 'customer_status_auto';
  RAISE NOTICE 'OK: Z4-5 stav zákazníka k dátumu behu';
END;
$$;

-- Z4-6. Aplikácia: testovací dátum nefunguje, beh k dátumu nespustí, upozornenia iba vlastné, udalosti
GRANT SELECT, UPDATE ON notification TO crm_rls_test;
GRANT SELECT ON job_run TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  v_exc uuid;
  v_n   uuid;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  PERFORM set_config('crm.today', '2030-01-01', true);
  ASSERT crm_today() = (now() AT TIME ZONE 'Europe/Bratislava')::date, 'aplikácia testovací dátum nepodstrčí';
  PERFORM set_config('crm.today', '', true);
  ASSERT NOT has_function_privilege('crm_rls_test', 'contract_daily_run_at(date)', 'EXECUTE')
     AND has_function_privilege('crm_rls_test', 'contract_daily_run()', 'EXECUTE'), 'beh k dátumu iba vlastník';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000007501', true);
  ASSERT (SELECT count(*) FROM notification) > 0
     AND NOT EXISTS (SELECT 1 FROM notification WHERE user_id <> '00000000-0000-4000-8000-000000007501'), 'iba vlastné upozornenia';
  ASSERT NOT EXISTS (SELECT 1 FROM job_run), 'obchodník nevidí nočné behy';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004002', true);
  ASSERT EXISTS (SELECT 1 FROM job_run), 'Nákup vidí denník nočných behov';
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000007501', true);
  SELECT id INTO v_n FROM notification LIMIT 1;
  UPDATE notification SET read_at = now() WHERE id = v_n;
  ASSERT (SELECT read_at IS NOT NULL FROM notification WHERE id = v_n), 'označenie prečítania';
  -- nová žiadosť o výnimku → schvaľovateľ (4001)
  INSERT INTO price_exception (company_id, years, price_model, requested_value, threshold_value, reason)
  VALUES ('00000000-0000-4000-8000-000000007511', '{2027}', 'fix', 103, 0, 'Z4') RETURNING id INTO v_exc;
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000004001', true);
  ASSERT EXISTS (SELECT 1 FROM notification WHERE price_exception_id = v_exc AND kind = 'vynimka_nova'), 'schvaľovateľ: nová žiadosť';
  UPDATE price_exception SET status = 'zamietnuta', decision_note = 'Z4' WHERE id = v_exc;
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000007501', true);
  ASSERT EXISTS (SELECT 1 FROM notification WHERE price_exception_id = v_exc AND kind = 'vynimka_rozhodnutie'), 'autor: rozhodnutie';
  PERFORM set_config('app.user_id', '', true);
  PERFORM set_config('app.require_user', '', true);
END;
$$;
RESET ROLE;
DO $$
BEGIN
  -- Pod hranicou bez výnimky → schvaľovatelia a CEO hneď (spúšťač)
  INSERT INTO contract_flag (contract_id, code, year) VALUES (pg_temp.z4_id('k', 1), 'pod_hranicou_bez_vynimky', 2027);
  ASSERT EXISTS (SELECT 1 FROM notification WHERE contract_id = pg_temp.z4_id('k', 1) AND kind = 'pod_hranicou'
                    AND user_id = '00000000-0000-4000-8000-000000004001'), 'Pod hranicou: schvaľovateľ';
  ASSERT NOT has_table_privilege('crm_app', 'notification', 'INSERT')
     AND NOT has_column_privilege('crm_app', 'notification', 'detail', 'UPDATE')
     AND has_column_privilege('crm_app', 'notification', 'read_at', 'UPDATE')
     AND NOT has_table_privilege('crm_app', 'job_run', 'INSERT'), 'práva aplikácie (app-role.sql)';
  RAISE NOTICE 'OK: Z4-6 aplikácia: testovací dátum nie, beh k dátumu nie, iba vlastné upozornenia, prečítanie, výnimka (nová, rozhodnutie), Pod hranicou, práva';
END;
$$;
