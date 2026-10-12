-- Vyprázdnenie Testu (Neon vetva dev). Spúšťa sa iba cez db/empty-test.sh.
-- Premenná psql skuska = true → na konci ROLLBACK (nič sa nezmaže), false → COMMIT.
--
-- Zmaže všetky dáta v schéme public okrem:
--   - schema_migrations (zoznam spustených migrácií) a business_calendar (pracovný kalendár z migrácií),
--   - Nastavení, ak už existujú (po migrácii 0006: spoločnosti, tímy a práva, používatelia, pracovný čas,
--     číselníky, vlastné polia, pipelines a stage).
-- Pred 0006 sa zmažú aj tímy, používatelia, pipelines a produkty zo vzorky prototypu (HubSpot).
-- Kontroly: po zmazaní sú všetky mazané tabuľky prázdne a ponechané tabuľky majú rovnaký počet riadkov.

\set ON_ERROR_STOP on
BEGIN;

CREATE TEMP TABLE empty_test_plan (table_name text PRIMARY KEY, keep boolean NOT NULL, rows_before bigint) ON COMMIT DROP;

DO $$
DECLARE
  v_settings constant text[] := ARRAY[
    'org', 'org_logo', 'org_bank_account', 'team', 'team_permission', 'app_user', 'app_user_org',
    'org_work_hours', 'org_day_off', 'lookup_list', 'lookup_value', 'custom_field_section', 'custom_field',
    'custom_field_team', 'custom_field_option', 'pipeline', 'pipeline_stage', 'pipeline_stage_required_field'];
  v_keep  text[] := ARRAY['schema_migrations', 'business_calendar'];
  t       record;
  n       bigint;
BEGIN
  IF to_regclass('public.org') IS NOT NULL THEN
    v_keep := v_keep || v_settings;   -- Nastavenia (0006+) ostávajú
  END IF;
  FOR t IN SELECT c.relname FROM pg_class c JOIN pg_namespace s ON s.oid = c.relnamespace
            WHERE s.nspname = 'public' AND c.relkind IN ('r', 'p') ORDER BY c.relname LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t.relname) INTO n;
    INSERT INTO empty_test_plan VALUES (t.relname, t.relname = ANY (v_keep), n);
  END LOOP;
END;
$$;

\echo ''
\echo 'Zmaže sa (tabuľka, počet riadkov):'
SELECT table_name AS tabulka, rows_before AS riadkov FROM empty_test_plan WHERE NOT keep AND rows_before > 0 ORDER BY 1;
\echo 'Ostáva (tabuľka, počet riadkov):'
SELECT table_name AS tabulka, rows_before AS riadkov FROM empty_test_plan WHERE keep ORDER BY 1;

-- Všetko naraz (cudzie kľúče medzi mazanými tabuľkami); bez CASCADE, aby sa nezmazala ponechaná tabuľka.
DO $$
DECLARE
  v_list text;
BEGIN
  SELECT string_agg(format('public.%I', table_name), ', ') INTO v_list FROM empty_test_plan WHERE NOT keep;
  IF v_list IS NOT NULL THEN
    EXECUTE 'TRUNCATE ' || v_list || ' RESTART IDENTITY';
  END IF;
END;
$$;

-- Kontrola po zmazaní
DO $$
DECLARE
  t  empty_test_plan;
  n  bigint;
BEGIN
  FOR t IN SELECT * FROM empty_test_plan LOOP
    EXECUTE format('SELECT count(*) FROM public.%I', t.table_name) INTO n;
    IF NOT t.keep AND n <> 0 THEN
      RAISE EXCEPTION '%: zostalo % riadkov', t.table_name, n;
    END IF;
    IF t.keep AND n <> t.rows_before THEN
      RAISE EXCEPTION '%: ponechaná tabuľka sa zmenila (% → %)', t.table_name, t.rows_before, n;
    END IF;
  END LOOP;
  RAISE NOTICE 'Kontrola: mazané tabuľky sú prázdne, ponechané bez zmeny.';
END;
$$;

\if :skuska
ROLLBACK;
\echo 'SKÚŠKA: všetko prebehlo a skontrolovalo sa, transakcia vrátená – nič sa nezmazalo.'
\else
COMMIT;
\echo 'HOTOVO: Test je vyprázdnený.'
\endif
