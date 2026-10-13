-- Stav Testu (Neon dev) – iba čítanie (transakcia READ ONLY), nič nemení, bez osobných údajov (iba počty).
-- Použitie: ./integrations/hubspot-sync/sample/psql-dev.sh db/test-data/stav-dev.sql
-- Pred db/test/run.sh musia byť všetky počty záznamov 0 (testy zatiaľ počítajú celé tabuľky).

BEGIN TRANSACTION READ ONLY;

SELECT (SELECT count(*) FROM company)  AS firmy,
       (SELECT count(*) FROM contact)  AS osoby,
       (SELECT count(*) FROM oom)      AS oom,
       (SELECT count(*) FROM deal)     AS dealy,
       (SELECT count(*) FROM contract) AS zmluvy,
       (SELECT count(*) FROM product)  AS produkty,
       (SELECT count(*) FROM oom WHERE id::text LIKE '7e570000-%') AS testovacie_oom;

SELECT (SELECT max(version) FROM schema_migrations) AS posledna_migracia,
       (SELECT data_type FROM information_schema.columns
         WHERE table_name = 'oom' AND column_name = 'price_regulation') AS typ_cenovej_regulacie,
       (SELECT CASE WHEN hidden_at IS NULL THEN 'viditeľná' ELSE 'skrytá' END
          FROM lookup_value WHERE code = 'zsd_c1') AS zsd_c1,
       (SELECT count(*) FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND label = 'C11') AS sadzby_c11,
       (SELECT count(*) FROM pg_class WHERE relname IN ('tariff_scope', 'product_tariff')) AS nove_tabulky;

ROLLBACK;
