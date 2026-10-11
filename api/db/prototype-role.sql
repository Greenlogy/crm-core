-- Práva roly crm_prototype_ro: iba čítanie (modul 2, krok 3). Iba Neon vetva dev.
-- Rolu s heslom vytvorí api/db/create-prototype-role.sh, ktorý potom spustí tento súbor.
-- Nie je to dbmate migrácia: rola patrí iba k prototypu a po jeho skončení sa zruší.
--
-- Zrušenie roly (po prototype, iba so súhlasom):
--   REVOKE ALL ON ALL TABLES IN SCHEMA public FROM crm_prototype_ro;
--   ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE SELECT ON TABLES FROM crm_prototype_ro;
--   DROP OWNED BY crm_prototype_ro;
--   DROP ROLE crm_prototype_ro;

\set ON_ERROR_STOP on
BEGIN;

DO $$
BEGIN
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO crm_prototype_ro', current_database());
END;
$$;

GRANT USAGE ON SCHEMA public TO crm_prototype_ro;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO crm_prototype_ro;

-- Tabuľky a pohľady z ďalších migrácií (vytvára ich rovnaký vlastník) budú tiež čitateľné.
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO crm_prototype_ro;

-- Poistka: každá transakcia roly je iba na čítanie, aj keby niekto omylom pridal právo zápisu.
ALTER ROLE crm_prototype_ro SET default_transaction_read_only = on;

COMMIT;
