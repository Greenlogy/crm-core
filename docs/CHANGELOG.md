# Changelog

## 2026-10-11

- Frontend prototypu podľa dizajnu modulu Zákazníci (obrazovky 01, 08–10): menu Zákazníci / Leady (s počtom) / Kontakty; zoznam zákazníkov s filtrom stavu a počtami, segmentom, vlastníkom a prepínačom marketingových kontaktov a archívu; Leady; nový zoznam Kontakty; karta firmy so stavom, označeniami, rolami a hlavným kontaktom; nová karta osoby (domácnosť aj kontakt vo firme) s vývojom stavu z `audit_log`; karty domácností na `/osoby/:id` (staré `/domacnosti/:id` presmeruje); stredný a pravý stĺpec karty užšie, aby sa pri 1 440 px nezalamovali
- API: `GET /api/contacts` (hľadanie podľa mena, e-mailu, začiatku telefónu), `GET /api/counts`, v zozname počty podľa stavov, mesto a väzby domácnosti na firmy, na kartách vývoj stavu a ďalšie firmy kontaktu
- Nasadený Worker `crm-core` (verzia `dd5f4185`), Access overený (bez prihlásenia 302)
- Modul Zákazníci (zadanie v0.3): migrácie `0004_zakaznici.sql` (príznaky firmy, povinné IČO a údaje osoby, `is_household`, stav a jeho výpočet, „nechce marketing“, roly a hlavný kontakt, normalizovaný telefón, ochrana vlastníka, nové `customer_v` a `contact_v`) a `0005_rls_zakaznici.sql` (RLS pre externého obchodníka, kontrola duplicít IČO a osoby) – spustené na Neon `dev` po zmazaní vzorky prototypu, testy prešli (36 kontrol)
- Testy: `db/test/seed.sql` a `checks.sql` upravené na novú schému, nové `db/test/checks_zakaznici.sql` (22 kontrol vrátane RLS s dočasnou rolou; pridelenie roly kvôli PostgreSQL 16+ bez superusera), `run.sh` ich spúšťa
- `integrations/hubspot-sync/sample/load.ts` na schému 0004: firma bez IČO a osoba bez mena alebo kontaktu sa nenahrá; označenia firmy zo segmentu HubSpotu (dodávateľ s OOM alebo dealom je aj zákazník); `is_household`; hlavný kontakt iba pri jedinom kontakte firmy; výrobca (OOM výroba alebo pipeline B2B výkup); východiskový stav cez `customer_status_calc` (zdroj `hubspot`); na konci vygeneruje zmazanie cez `delete.ts`
- API prototypu na schému 0004: zoznam z `customer_v` s filtrami stav (predvolene bez marketingových kontaktov a archívu, `leady`, `vsetky`), segment (domácnosť, firma, výrobca) a obchodník; nový `GET /api/owners`; karty so stavom, príznakmi, označeniami firmy, „nechce marketing“, rolami a hlavným kontaktom; `smoke.sh` s novými filtrami
- Nová vzorka (1 340 riadkov) nahratá na `dev` (Peter)
- `integrations/hubspot-sync/sample/delete.ts`: zmazanie vzorky prototypu s kontrolami pred a po, skúška (ROLLBACK) a ostré zmazanie
- Modul 2 (prototyp): zadanie `docs/moduly/02-prototyp.md`, technické rozhodnutia (React + Vite, Hono + postgres.js, adresy `*.workers.dev`/`*.pages.dev`)
- `integrations/hubspot-sync/sample/`: výber vzorky (`select.ts`, iba čítanie), generátor SQL (`load.ts`), spoločné pravidlo vlastníka OOM (`owners.ts`), spúšťač iba pre `dev` (`psql-dev.sh`); klient HubSpotu povoľuje aj hromadné čítanie záznamov
- Rola `crm_prototype_ro` (iba čítanie) na Neon `dev`: `api/db/prototype-role.sql`, `api/db/create-prototype-role.sh`
- API prototypu v `api/` (Cloudflare Worker, Hono, postgres.js): zoznam zákazníkov, karty firmy, domácnosti, OOM a zmluvy, iba GET; `api/dev.sh`, `api/smoke.sh`
- Frontend prototypu vo `web/` (React + Vite): zoznam zákazníkov, karty zákazníka, OOM a zmluvy; CSS premenné generované z `docs/dizajn/system/tokens.json`
- Migrácia `0003_company_bank_account` (model v0.3.2); `db/dbmate.sh` aktualizuje `schema.sql` (pg_dump z Postgres.app)
- Prototyp: obchodník (vlastník z HubSpotu) na firme, kontakte a deale; Firemné informácie ako v HubSpote (bankový účet, platobný rating); širší ľavý stĺpec s údajmi pod popisom; FinStat Áno/Nie
- Nasadenie prototypu: jeden Worker `crm-core` (API + frontend), Hyperdrive `crm-core-dev` s rolou iba na čítanie, Cloudflare Access iba pre peter@greenlogy.com; `CLAUDE.md` – frontend cez Worker namiesto Pages
- Vzorka 44 zákazníkov (1 363 riadkov) nahratá na Neon `dev`, výnimka pre skutočné osobné údaje v `docs/rozhodnutia.md`
- Modul 1: migrácie `0001_jadro.sql` (35 tabuliek, 27 enumov, `updated_at`, `audit_log`, preberanie segmentu, pohľady `customer_v` a `contact_oom_v`) a `0002_pracovny_kalendar.sql` (kalendár 2026–2028, `add_business_minutes`) na vetve `dev`
- `db/schema.sql`, spúšťač `db/dbmate.sh`, dbmate cez npm (`package.json`)
- Testy `db/test/` (vymyslené dáta, 14 kontrol, transakcia sa vracia)
- Dátový model v0.3.1: `contract_purchase`, `pricing_model`, `additive_eur_mwh`, jeden enum segmentu (aj pre kontakt), IČO s 8 číslicami, zrušené externé roly, výpočtové pohľady presunuté do samostatnej migrácie
- Kontrola IČO v HubSpote: 2 duplicity po doplnení núl, 1 hodnota s 10 číslicami
- `CLAUDE.md`: opravený príklad SLA (piatok 15:00 → pondelok 15:00)
- `README.md`: sekcia Databáza

## 2026-10-10

- Zadanie modulu 1 (databáza jadra) v `docs/moduly/01-databaza.md`
- `CLAUDE.md`: databáza Neon (Frankfurt), vetvy `main`/`dev`, migrácie dbmate
- Modul 0 uzavretý: Peter schválil súhrn inventára a dátový model v0.3
- Modul 0: skript na inventár HubSpotu (`integrations/hubspot-sync/inventory`, iba čítanie)
- Modul 0: inventár HubSpotu a Make scenárov v `docs/inventar/` (objekty a vlastnosti, pipelines, workflowy a šablóny, Make scenáre, súhrn)
- Dátový model jadra v0.3 podľa inventára
- `CLAUDE.md`: OOM má 4 typy (spotreba, výroba, sharing, veľkoobchod) a 5 stavov (pribudol Prepísané)
- Rozhodnutia modulu 0 zapísané v `docs/rozhodnutia.md`
- Založený repozitár `crm-core`
- Pridané pravidlá projektu `CLAUDE.md`
- Pridaný návrh dátového modelu jadra v0.2
