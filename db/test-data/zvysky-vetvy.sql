-- Iba čítanie: objekty v schéme public, ktoré nepatria rozšíreniam (po návrate všetkých migrácií má ostať iba schema_migrations).
SELECT 'funkcie' AS druh, count(*) AS pocet FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE n.nspname = 'public' AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')
UNION ALL
SELECT 'typy', count(*) FROM pg_type t JOIN pg_namespace n ON n.oid = t.typnamespace
 WHERE n.nspname = 'public' AND t.typtype IN ('e', 'c', 'd') AND t.typrelid = 0
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = t.oid AND d.deptype = 'e')
UNION ALL
SELECT 'tabuľky a pohľady', count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v', 'm', 'p')
UNION ALL
SELECT 'rozšírenia', count(*) FROM pg_extension WHERE extname <> 'plpgsql';
SELECT string_agg(c.relname, ', ') AS tabulky FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
 WHERE n.nspname = 'public' AND c.relkind IN ('r', 'v', 'm', 'p');
SELECT string_agg(extname, ', ') AS rozsirenia FROM pg_extension WHERE extname <> 'plpgsql';
