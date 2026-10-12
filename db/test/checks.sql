-- Kontrolné dotazy jadra nad dátami zo seed.sql.
-- Každá kontrola vypíše "OK: …"; pri chybe sa beh zastaví (ON_ERROR_STOP).
-- Spúšťa sa iba cez db/test/run.sh.

-- 1. Pravidlo zákazníka: práve jedna z company_id / person_id
DO $$
BEGIN
  BEGIN
    INSERT INTO oom (company_id, person_id, eic, type, status)
    VALUES ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201',
            '24ZZS000TEST900K', 'spotreba', 'aktivne');
    RAISE EXCEPTION 'CHYBA: OOM s firmou aj kontaktom prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: OOM s firmou aj kontaktom odmietnuté';
  END;
  BEGIN
    INSERT INTO deal (pipeline_id, stage_id, name)
    VALUES ('00000000-0000-4000-8000-000000000501', '00000000-0000-4000-8000-000000000511', 'Bez zákazníka');
    RAISE EXCEPTION 'CHYBA: deal bez zákazníka prešiel';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: deal bez zákazníka odmietnutý';
  END;
  BEGIN
    INSERT INTO contract (number) VALUES ('TEST-BEZ-ZAKAZNIKA');
    RAISE EXCEPTION 'CHYBA: zmluva bez zákazníka prešla';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: zmluva bez zákazníka odmietnutá';
  END;
END;
$$;

-- 2. Firma: IČO povinné, 8 číslic, unikátne
DO $$
BEGIN
  BEGIN
    INSERT INTO company (name) VALUES ('Firma bez IČO');
    RAISE EXCEPTION 'CHYBA: firma bez IČO prešla';
  EXCEPTION WHEN not_null_violation THEN
    RAISE NOTICE 'OK: firma bez IČO odmietnutá';
  END;
  BEGIN
    INSERT INTO company (name, ico) VALUES ('Krátke IČO', '123456');
    RAISE EXCEPTION 'CHYBA: IČO so 6 číslicami prešlo';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: IČO bez 8 číslic odmietnuté';
  END;
  BEGIN
    INSERT INTO company (name, ico) VALUES ('Duplicita', '00123456');
    RAISE EXCEPTION 'CHYBA: duplicitné IČO prešlo';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: duplicitné IČO odmietnuté';
  END;
END;
$$;

-- 3. Osoba v dvoch firmách; firma má najviac jeden hlavný kontakt
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM company_contact
           WHERE contact_id = '00000000-0000-4000-8000-000000000202') = 2,
         'osoba má mať 2 firmy';
  BEGIN
    INSERT INTO company_contact (company_id, contact_id, is_main_contact)
    VALUES ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000201', true);
    RAISE EXCEPTION 'CHYBA: druhý hlavný kontakt firmy prešiel';
  EXCEPTION WHEN unique_violation THEN
    RAISE NOTICE 'OK: osoba v dvoch firmách, druhý hlavný kontakt firmy odmietnutý';
  END;
END;
$$;

-- 4. Deal a zmluva preberajú segment od zákazníka
DO $$
BEGIN
  ASSERT (SELECT segment FROM deal WHERE id = '00000000-0000-4000-8000-000000000601') = 'firma',
         'B2B deal má mať segment firma';
  ASSERT (SELECT segment FROM deal WHERE id = '00000000-0000-4000-8000-000000000602') = 'domacnost',
         'B2C deal má mať segment domacnost';
  ASSERT (SELECT segment FROM contract WHERE id = '00000000-0000-4000-8000-000000000701') = 'firma',
         'zmluva má mať segment firma';
  RAISE NOTICE 'OK: deal a zmluva prevzali segment od zákazníka';
END;
$$;

-- 5. Štádium dealu musí patriť do jeho pipeline
DO $$
BEGIN
  INSERT INTO deal (company_id, pipeline_id, stage_id, name)
  VALUES ('00000000-0000-4000-8000-000000000101', '00000000-0000-4000-8000-000000000501',
          '00000000-0000-4000-8000-000000000521', 'Cudzie štádium');
  RAISE EXCEPTION 'CHYBA: štádium z inej pipeline prešlo';
EXCEPTION WHEN foreign_key_violation THEN
  RAISE NOTICE 'OK: štádium z inej pipeline odmietnuté';
END;
$$;

-- 6. Najviac jedna platná zmluvná cena na OOM a zmluvu; nákupné ceny
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM contract_purchase
           WHERE contract_id = '00000000-0000-4000-8000-000000000701') = 2,
         'zmluva má mať 2 nákupné ceny';
  INSERT INTO contract_price (contract_id, oom_id, direction, price_vt_eur_mwh)
  VALUES ('00000000-0000-4000-8000-000000000701', '00000000-0000-4000-8000-000000000301', 'odber', 130);
  RAISE EXCEPTION 'CHYBA: druhá platná cena prešla';
EXCEPTION WHEN unique_violation THEN
  RAISE NOTICE 'OK: zmluva má 2 nákupné ceny, druhá platná cena pre OOM odmietnutá';
END;
$$;

-- 7. contact_oom_v: iba OOM v stave Aktívne alebo Pripravované
DO $$
DECLARE
  v_eva  text;
  v_jan  text;
BEGIN
  SELECT string_agg(o.eic, ',' ORDER BY o.eic) INTO v_eva
    FROM contact_oom_v v JOIN oom o ON o.id = v.oom_id
   WHERE v.contact_id = '00000000-0000-4000-8000-000000000202';
  SELECT string_agg(o.eic, ',' ORDER BY o.eic) INTO v_jan
    FROM contact_oom_v v JOIN oom o ON o.id = v.oom_id
   WHERE v.contact_id = '00000000-0000-4000-8000-000000000201';
  ASSERT v_eva = '24ZZS000TEST001H,24ZZS000TEST003D', format('Eva: očakávané OOM 001,003, je %s', v_eva);
  ASSERT v_jan = '24ZZS000TEST002F', format('Ján: očakávané OOM 002, je %s', v_jan);
  RAISE NOTICE 'OK: contact_oom_v vynecháva zrušené OOM (Eva 2 z 3, Ján 1)';
END;
$$;

-- 8. customer_v: 2 firmy so zákazníckym označením (B2B) + 1 domácnosť (B2C); dodávateľ nie
DO $$
BEGIN
  ASSERT (SELECT count(*) FROM customer_v WHERE customer_type = 'B2B') = 2, 'B2B zákazníci';
  ASSERT (SELECT count(*) FROM customer_v WHERE customer_type = 'B2C') = 1, 'B2C zákazníci';
  ASSERT (SELECT name FROM customer_v WHERE customer_type = 'B2C') = 'Ján Testovací', 'B2C meno';
  RAISE NOTICE 'OK: customer_v má 2 B2B a 1 B2C zákazníka (dodávateľ vynechaný)';
END;
$$;

-- 9. audit_log zachytí zmenu aj s používateľom
DO $$
DECLARE
  v_row  audit_log;
BEGIN
  ASSERT (SELECT count(*) FROM audit_log
           WHERE action = 'insert' AND record_id = '00000000-0000-4000-8000-000000000101') = 1,
         'insert firmy chýba v audit_log';

  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  UPDATE company SET name = 'Alfa Test Plus s.r.o.' WHERE id = '00000000-0000-4000-8000-000000000101';

  SELECT * INTO v_row FROM audit_log
   WHERE table_name = 'company' AND action = 'update'
     AND record_id = '00000000-0000-4000-8000-000000000101'
   ORDER BY id DESC LIMIT 1;
  ASSERT v_row.changed_by = '00000000-0000-4000-8000-000000000011', 'audit: changed_by';
  ASSERT v_row.diff = '{"name": {"old": "Alfa Test s.r.o.", "new": "Alfa Test Plus s.r.o."}}'::jsonb,
         format('audit: diff je %s', v_row.diff);

  -- update bez zmeny sa nezapisuje
  UPDATE company SET name = name WHERE id = '00000000-0000-4000-8000-000000000101';
  ASSERT (SELECT count(*) FROM audit_log
           WHERE table_name = 'company' AND action = 'update'
             AND record_id = '00000000-0000-4000-8000-000000000101') = 1,
         'audit: update bez zmeny sa zapísal';

  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: audit_log zachytil zmenu (iba zmenený stĺpec, používateľ)';
END;
$$;

-- 10. SLA termín
DO $$
BEGIN
  ASSERT add_business_minutes('2026-10-09 15:00 Europe/Bratislava', 480)
       = '2026-10-12 15:00 Europe/Bratislava'::timestamptz, 'SLA prvá reakcia';
  ASSERT add_business_minutes('2026-10-09 15:00 Europe/Bratislava', 1440)
       = '2026-10-14 15:00 Europe/Bratislava'::timestamptz, 'SLA odpoveď';
  RAISE NOTICE 'OK: SLA piatok 15:00 → prvá reakcia pondelok 15:00, odpoveď streda 15:00';
END;
$$;
