-- Kontroly 0035: RLS na audite. Admin vidí všetko; obchodník iba audit záznamov, ktoré smie vidieť (obchody, firmy,
-- OOM vrátane zmazaných podriadených záznamov); Nastavenia iba admin; audit sa nedá meniť ani mazať;
-- do externého tímu sa dá priradiť používateľ (crm_external_ready).
-- Spúšťa sa iba cez db/test/run.sh po checks_obchod.sql (používatelia a obchody série B, rola crm_rls_test).

GRANT SELECT ON audit_log TO crm_rls_test;
SET LOCAL ROLE crm_rls_test;
DO $$
DECLARE
  n integer;
BEGIN
  PERFORM set_config('app.require_user', 'on', true);
  -- predajca C: vidí audit svojho obchodu na firme bez vlastníka (B8), nie obchodu B na firme A2
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 6)::text, true);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'deal' AND record_id = pg_temp.b_id('d', 3)), 'C vidí audit obchodu, ktorý vlastní';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'deal' AND record_id = pg_temp.b_id('d', 20)), 'C nevidí audit cudzieho obchodu';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'company' AND record_id = pg_temp.b_id('f', 5)), 'ani cudzej firmy';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name IN ('team_permission', 'app_user', 'price_parameter', 'lookup_value')),
         'Nastavenia a používateľov nevidí';
  -- predajca A: vidí audit firmy A2 a obchodu B na nej (zákazník je jeho), aj zmazanú väzbu OOM na svojom obchode
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 1)::text, true);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'company' AND record_id = pg_temp.b_id('f', 5)), 'A vidí audit svojej firmy';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'deal' AND record_id = pg_temp.b_id('d', 20)), 'A vidí audit obchodu na svojej firme';
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'deal_oom' AND action = 'insert'
                   AND audit_diff_value(diff, 'deal_id') = pg_temp.b_id('d', 1)::text), 'A vidí audit OOM na svojom obchode';
  -- Servis (všetko v module Obchod a Zákazníci) vidí audit obchodov, nie Nastavení
  PERFORM set_config('app.user_id', pg_temp.b_id('u', 5)::text, true);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'deal' AND record_id = pg_temp.b_id('d', 20)), 'Servis vidí audit obchodov';
  ASSERT NOT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'team_permission'), 'Servis nevidí Nastavenia';
  -- admin vidí všetko
  PERFORM set_config('app.user_id', (SELECT id FROM app_user WHERE lower(email) = 'peter@greenlogy.com')::text, true);
  ASSERT EXISTS (SELECT 1 FROM audit_log WHERE table_name = 'team_permission'), 'admin vidí Nastavenia';
  -- bez používateľa nič
  PERFORM set_config('app.user_id', '', true);
  SELECT count(*) INTO n FROM audit_log;
  ASSERT n = 0, 'bez používateľa nič';
  PERFORM set_config('app.require_user', '', true);
  RAISE NOTICE 'OK: B9 audit: obchodník iba zmeny svojich obchodov, firiem a OOM; Servis podľa práv; Nastavenia iba admin; bez používateľa nič';
END;
$$;
RESET ROLE;
DO $$
BEGIN
  ASSERT crm_external_ready(), 'externý tím odomknutý';
  INSERT INTO app_user (id, email, name, team_id, status)
  SELECT '00000000-0000-4000-8000-000000009010', 'externy.b9@example.test', 'Externý B9', t.id, 'aktivny'
    FROM team t WHERE t.code = 'sales_external';
  ASSERT EXISTS (SELECT 1 FROM app_user WHERE id = '00000000-0000-4000-8000-000000009010'), 'externý priradený';
  RAISE NOTICE 'OK: B9 do externého tímu sa dá priradiť obchodník (OOM, obchody, zmluvy aj audit majú „iba svoje“)';
END;
$$;
