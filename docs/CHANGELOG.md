# Changelog

## 2026-10-11

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
