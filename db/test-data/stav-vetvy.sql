-- Stav vetvy – iba čítanie, bez osobných údajov (iba počty a verzie migrácií). Spúšťa db/citanie.sh.
-- Funguje aj na prázdnej vetve (tabuľky sa zisťujú cez katalóg).

SELECT current_database() AS databaza, current_setting('server_version') AS postgres,
       current_setting('default_transaction_read_only') AS iba_citanie,
       (SELECT count(*) FROM pg_tables WHERE schemaname = 'public') AS tabuliek_public,
       (SELECT count(*) FROM pg_roles WHERE rolname IN ('crm_app', 'crm_sync')) AS roly_crm,
       to_regclass('public.schema_migrations') IS NOT NULL AS ma_schema_migrations;

DO $$
DECLARE
  t text;
  n bigint;
  v text;
BEGIN
  IF to_regclass('public.schema_migrations') IS NOT NULL THEN
    EXECUTE 'SELECT string_agg(version, '', '' ORDER BY version) FROM schema_migrations' INTO v;
    RAISE NOTICE 'migrácie: %', coalesce(v, '(žiadne)');
  END IF;
  FOREACH t IN ARRAY ARRAY['company', 'contact', 'oom', 'deal', 'contract', 'product', 'price_list', 'app_user', 'audit_log'] LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM %I', t) INTO n;
      RAISE NOTICE '%: % záznamov', t, n;
    END IF;
  END LOOP;
END;
$$;
