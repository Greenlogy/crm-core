-- Kontroly zápisu modulu Zákazníci (migrácia 0011: zmazanie omylom založenej firmy alebo osoby).
-- Vymyslené údaje, uuid s prefixom 00000000-0000-4000-8000-00000003….
-- Spúšťa sa iba cez db/test/run.sh, po checks_nastavenia.sql (transakcia sa na konci vráti).

-- K1. Zmazať smie iba admin, iba záznam bez väzieb; audit zapíše kto a celý riadok
INSERT INTO company (id, name, ico) VALUES
  ('00000000-0000-4000-8000-000000003001', 'Omylom s.r.o.', '99990001');
INSERT INTO contact (id, first_name, last_name, email, is_household) VALUES
  ('00000000-0000-4000-8000-000000003002', 'Omylom', 'Založená', 'omylom@example.test', true);

DO $$
DECLARE
  v_peter uuid := (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com');
  r       audit_log;
BEGIN
  -- obchodník (nie admin) nezmaže
  PERFORM set_config('app.user_id', '00000000-0000-4000-8000-000000000011', true);
  BEGIN
    PERFORM customer_delete('00000000-0000-4000-8000-000000003001', NULL);
    RAISE EXCEPTION 'CHYBA: neadmin zmazal firmu';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'OK: zmazať firmu môže iba admin';
  END;

  -- admin: firma s osobou vo firme sa nezmaže (väzba by zmizla potichu)
  PERFORM set_config('app.user_id', v_peter::text, true);
  BEGIN
    PERFORM customer_delete('00000000-0000-4000-8000-000000000101', NULL);
    RAISE EXCEPTION 'CHYBA: firma s väzbami zmazaná';
  EXCEPTION WHEN check_violation THEN
    ASSERT SQLERRM LIKE '%osoby vo firme%', SQLERRM;
    RAISE NOTICE 'OK: firma s väzbami sa nezmaže (%)', SQLERRM;
  END;
  BEGIN
    PERFORM customer_delete(NULL, '00000000-0000-4000-8000-000000000202');
    RAISE EXCEPTION 'CHYBA: osoba vo firme zmazaná';
  EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: osoba vo firme sa nezmaže';
  END;

  -- admin: bez väzieb sa zmaže; audit má celý riadok a používateľa
  ASSERT customer_delete('00000000-0000-4000-8000-000000003001', NULL) = 'Omylom s.r.o.', 'názov zmazanej firmy';
  ASSERT customer_delete(NULL, '00000000-0000-4000-8000-000000003002') = 'Omylom Založená', 'meno zmazanej osoby';
  ASSERT NOT EXISTS (SELECT 1 FROM company WHERE id = '00000000-0000-4000-8000-000000003001'), 'firma ostala';
  SELECT * INTO r FROM audit_log
   WHERE record_id = '00000000-0000-4000-8000-000000003001' AND action = 'delete';
  ASSERT r.changed_by = v_peter AND r.diff ->> 'ico' = '99990001' AND r.source = 'aplikacia',
         format('audit zmazania: %s', r);
  PERFORM set_config('app.user_id', '', true);
  RAISE NOTICE 'OK: admin zmaže firmu a osobu bez väzieb; audit má kto, kedy a celý obsah';
END;
$$;
