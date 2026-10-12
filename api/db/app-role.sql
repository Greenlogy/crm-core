-- Práva roly crm_app (aplikácia CRM: Worker cez Hyperdrive). Iba Neon vetva dev, neskôr main.
-- Rolu s heslom vytvorí api/db/create-app-role.sh, ktorý potom spustí tento súbor.
-- Nie je to dbmate migrácia: rola a jej heslo patria k prostrediu, nie k schéme.
--
-- Súbor sa dá spúšťať opakovane. Po každej migrácii s novými tabuľkami ho treba spustiť znova
-- (predvolené práva na budúce tabuľky zámerne nie sú: nová tabuľka je pre aplikáciu zatvorená,
-- kým sa vedome nepovolí).
--
-- Zásady:
--   - bez prihláseného používateľa nevidí nič (rolu crm_app rozpozná databáza, migrácia 0009; RLS 0006–0008),
--   - čítať, zakladať a meniť smie; mazať iba väzby a nastavenia, kde to dovoľujú pravidlá,
--   - audit iba číta a zapisuje (nemení, nemaže), zoznam migrácií nevidí,
--   - pracovný kalendár iba číta (prepočítava ho databáza sama),
--   - nemení štruktúru databázy (nie je vlastníkom tabuliek) a neobchádza RLS.

\set ON_ERROR_STOP on
BEGIN;

DO $$
BEGIN
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO crm_app', current_database());
END;
$$;

GRANT USAGE ON SCHEMA public TO crm_app;

-- Základ: čítať, zakladať, meniť
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO crm_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO crm_app;

-- Výnimky
REVOKE ALL ON schema_migrations FROM crm_app;
REVOKE INSERT, UPDATE ON business_calendar FROM crm_app;
REVOKE UPDATE ON audit_log, export_log FROM crm_app;
REVOKE INSERT, UPDATE ON sync_run FROM crm_app;
REVOKE INSERT, UPDATE ON lookup_list FROM crm_app;

-- Mazať: väzby (osoba vo firme, na deale, OOM na deale, položka ponuky, zariadenie OOM, kontaktná osoba pri OOM – 0013)
-- a nastavenia, ktoré sa dajú odobrať (prístup k spoločnosti, voľný deň, logo, tímy poľa,
-- povinné pole pri prechode, prázdna sekcia, pracovný deň – 0010). Ostatné sa nemaže, iba archivuje.
GRANT DELETE ON company_contact, deal_contact, deal_oom, offer_item, oom_device, oom_contact,
  app_user_org, org_day_off, org_logo, org_work_hours, custom_field_team, pipeline_stage_required_field,
  custom_field_section TO crm_app;

-- Nikdy neobchádza RLS. („Bez používateľa nič“ zaručuje migrácia 0009 podľa mena roly;
-- ALTER ROLE … SET app.require_user na Neone nejde – vlastník nie je superuser.)
ALTER ROLE crm_app NOBYPASSRLS;
ALTER ROLE crm_app SET statement_timeout = '30s';

COMMIT;
