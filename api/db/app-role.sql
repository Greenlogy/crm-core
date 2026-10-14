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
REVOKE INSERT, UPDATE ON app_setting FROM crm_app;     -- nastavenia systému mení iba vlastník (db/app-setting.sh, 0014)

-- Mazať: väzby (osoba vo firme, na deale, OOM na deale, položka ponuky, zariadenie OOM, kontaktná osoba pri OOM – 0013)
-- a nastavenia, ktoré sa dajú odobrať (prístup k spoločnosti, voľný deň, logo, tímy poľa,
-- povinné pole pri prechode, prázdna sekcia, pracovný deň – 0010). Ostatné sa nemaže, iba archivuje.
GRANT DELETE ON company_contact, deal_contact, deal_oom, offer_item, oom_device, oom_contact,
  app_user_org, org_day_off, org_logo, org_work_hours, custom_field_team, pipeline_stage_required_field,
  custom_field_section TO crm_app;
-- Párovanie produkt ↔ sadzba a rozsahy PDS (0019; RLS: iba admin). Produkt sa nemaže nikdy.
GRANT DELETE ON product_tariff, tariff_scope TO crm_app;
-- Cenníky (0020): mazať smie (databáza dovolí iba Návrh a cenník bez schválenej verzie); na verzii mení iba
-- názov, účinnosť a poznámku – stav, schválenie a „platná do“ mení iba funkcia (price_list_version_approve, _close).
GRANT DELETE ON price_list, price_list_version, price_list_item, price_list_item_program TO crm_app;
REVOKE UPDATE ON price_list_version FROM crm_app;
GRANT UPDATE (name, valid_from, note) ON price_list_version TO crm_app;
-- Zmluvy F1 (0023): budúci cenový parameter smie autor zrušiť; vlastný preklad importu zmazať (systémový iba skryť) –
-- pravidlá strážia spúšťače price_parameter_guard a import_alias_guard. Trhové ceny sa nemažú (market_price_guard).
GRANT DELETE ON price_parameter, import_alias TO crm_app;
-- 0024: naplánovanú (neuplatnenú) zmenu cenovej regulácie OOM smie zrušiť, kto smie OOM upraviť (RLS)
GRANT DELETE ON oom_price_regulation_change TO crm_app;
-- 0024: trhová cena sa nemení – oprava je nový záznam a „opravené“ označí databázová funkcia (vlastník);
-- aplikácia riadok trhovej ceny nemení vôbec (zatvára obídenie cez nastavenie relácie).
REVOKE UPDATE ON market_price_daily FROM crm_app;
-- 0025: zmluvy zakladá a údaje z Office portálu mení iba import (funkcia vlastníka); aplikácia mení iba údaje CRM.
-- OOM v zmluve a ceny aplikácia nemení (aj spúšťač); výnimky a príznaky podľa RLS.
REVOKE INSERT, UPDATE ON contract, contract_oom, contract_price FROM crm_app;
GRANT UPDATE (previous_contract_id, related_contract_id, close_reason, note, custom) ON contract TO crm_app;
GRANT DELETE ON price_exception TO crm_app;
-- 0026: importy zmlúv zapisuje iba funkcia importu (contract_import_run, vlastník); aplikácia ich iba číta.
-- Balík VIWA zadá Servis (otázka 20), obchodníka zmluvy zmení vedenie – stráži contract_guard.
REVOKE INSERT, UPDATE ON contract_import, contract_import_change FROM crm_app;
GRANT UPDATE (viwa_package, owner_id) ON contract TO crm_app;
-- 0027: minimálny aditív výkupu pri zmluve (Nákup) – stráži contract_guard; snímku ku dňu podpisu aplikácia nečíta
-- (bilanciu vracia contract_year_calc, marža iba s právom).
GRANT UPDATE (vykup_min_additive) ON contract TO crm_app;
REVOKE ALL ON contract_year_basis FROM crm_app;
-- 0028: upozornenia zakladá iba databáza (nočný beh, spúšťače); aplikácia číta vlastné a označí ich ako prečítané (RLS).
-- Záznam nočných behov iba číta admin (RLS).
REVOKE INSERT, UPDATE ON notification, job_run FROM crm_app;
GRANT UPDATE (read_at) ON notification TO crm_app;

-- Nikdy neobchádza RLS. („Bez používateľa nič“ zaručuje migrácia 0009 podľa mena roly;
-- ALTER ROLE … SET app.require_user na Neone nejde – vlastník nie je superuser.)
ALTER ROLE crm_app NOBYPASSRLS;
ALTER ROLE crm_app SET statement_timeout = '30s';

COMMIT;
