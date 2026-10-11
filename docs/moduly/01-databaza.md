# Modul 1 – Databáza jadra

Stav: hotové na `dev` (11. 10. 2026), čaká na nasadenie na `main`.

## Priebeh

- 10. 10.: plán, odpovede na otázky 1–8 (`docs/rozhodnutia.md`), dbmate cez npm, Postgres.app.
- 11. 10.: model v0.3.1, kontrola IČO v HubSpote, `0001` a `0002` na `dev` (up → down → up bez chýb), testy `db/test/run.sh` – 14 kontrol OK.
- Zistenie: enum a tabuľka nemôžu mať rovnaký názov (tabuľka vytvára typ) – enum segmentu sa volá `customer_segment`.
- Testy bežia cez `db/test/run.sh` v transakcii, ktorá sa vracia; na `dev` neostávajú testovacie dáta.

## Cieľ

Vytvoriť databázu jadra podľa schváleného dátového modelu v0.3.1 (`docs/01-datovy-model.md`) ako prvú migráciu `db/migrations/0001_jadro.sql`, overiť ju na Neon vetve `dev` a po schválení nasadiť na `main`.
Bez dát z HubSpotu – presun dát je samostatný modul.

## Pravidlá

- Databáza: Neon, región EÚ (Frankfurt). Vetvy: `main` = produkcia, `dev` = vývoj a testy. Lokálny Postgres sa nepoužíva.
- Pripojenia iba v `.dev.vars`: `DATABASE_URL_DEV`, `DATABASE_URL_MAIN`. Nikdy v repozitári, v logoch ani vo výpisoch príkazov.
- Migrácie cez dbmate: `db/migrations/0001_nazov.sql` so sekciami `-- migrate:up` a `-- migrate:down`. Po každej migrácii sa aktualizuje a commituje `db/schema.sql`.
- Každé spustenie migrácie (aj na `dev`) iba s Petrovým súhlasom. Na `main` až po schválení výsledkov z `dev`.
- Existujúce migrácie sa po nasadení na `main` nemenia; zmena = nová migrácia.
- Testovacie dáta sú vymyslené, žiadne osobné údaje zákazníkov. Na `main` sa testovacie dáta nenahrávajú.
- Nastavenia Cloudflare (Hyperdrive) nie sú súčasťou modulu – patria do modulu API.

## Rozsah

### 1. Príprava prostredia

- Neon projekt v regióne Frankfurt s vetvami `main` a `dev`. Projekt a vetvy založí Peter (alebo Claude cez `neonctl` s Petrovým súhlasom) a vloží pripojenia do `.dev.vars`.
- dbmate: inštalácia (návrh: `brew install dbmate`) a malý spúšťací skript `db/dbmate.sh dev|main <príkaz>`, ktorý načíta správne pripojenie z `.dev.vars` a pri `main` vyžaduje potvrdenie.
- Konfigurácia dbmate: `--migrations-dir db/migrations`, `--schema-file db/schema.sql`, bez automatického vytvárania databázy.

### 2. Migrácia `0001_jadro.sql`

Podľa modelu v0.3.1:

- **Enumy:** typ a stav OOM, typ kontaktu, segmenty, roly používateľov, stavy zmluvy, zmluvnej ceny, ponuky, provízie, typy aktivít a kanálov, účely a stavy súhlasov a ďalšie z modelu.
- **Tabuľky** zo všetkých sekcií modelu (ľudia a prístup, energetická doména, obchod, komunikácia a SLA, marketing, systém), vrátane:
  - `id uuid` (`gen_random_uuid()`), `created_at`, `updated_at` (`timestamptz`, UTC),
  - `hubspot_id` unikátny tam, kde záznam pochádza z HubSpotu,
  - peniaze `numeric(12,2)`, ceny elektriny `numeric(12,4)`.
- **Pravidlo zákazníka:** `CHECK (num_nonnulls(company_id, person_id) = 1)` na `oom`, `deal`, `contract`.
- **Integrita:** cudzie kľúče s premysleným `ON DELETE` (predvolene `RESTRICT`, väzobné tabuľky `CASCADE`), unikátny `oom.eic`, `contract.number`, `product.code`, jedna hlavná firma na kontakt (čiastočný unikátny index na `company_contact`).
- **Indexy:** na všetky cudzie kľúče, `contact.email`, `company.ico`, `hubspot_id`, časové stĺpce v `activity`.
- **Spúšťače:**
  - `updated_at` na všetkých obchodných tabuľkách,
  - `audit_log` (insert / update / delete, diff ako JSON); používateľ sa číta z `current_setting('app.user_id', true)`, ktorý nastaví API v každej transakcii.
- **Pohľady:** `customer_v`, `contact_oom_v`. Výpočtové pohľady (`contract_price_volume_v`, `contract_revenue_v`, `deal_margin_v`, `commission_base_v`) prídu v samostatnej migrácii po inventári `products` a `formulas` a po potvrdení rollupov.
- **Sekcia `-- migrate:down`** zmaže všetko v opačnom poradí.

### 3. Pracovný kalendár (`0002_pracovny_kalendar.sql`)

- Naplnenie `business_calendar` pre roky 2026–2028: pracovné dni Po–Pi 7:30–15:30, slovenské štátne sviatky a dni pracovného pokoja.
- Funkcia `add_business_minutes(start timestamptz, minutes int)` pre výpočet termínov SLA (Europe/Bratislava), s testom na príklade z `CLAUDE.md` (piatok 15:00 → pondelok 15:00).

### 3a. Inventár pred migráciou (iba čítanie z HubSpotu)

- Počet duplicít IČO po doplnení na 8 číslic.
- Sekcie `products` a `formulas` inventárneho skriptu ako podklad pre výpočtové pohľady.

### 4. Overenie na `dev`

- `dbmate up`, `dbmate down`, znova `up` – musí prejsť bez chýb.
- Testovacie dáta v `db/test/seed.sql` (vymyslené): B2B aj B2C zákazník, OOM všetkých typov, deal so zmluvou a zmluvnými cenami, kontakt s dvoma firmami.
- Kontrolné dotazy v `db/test/checks.sql`: pravidlo zákazníka odmietne zlý záznam, `contact_oom_v` vráti iba OOM v stave Aktívne/Neaktívne, `audit_log` zachytí zmenu, SLA funkcia vráti správny termín.

### 5. Nasadenie na `main`

Až po Petrovom schválení výsledkov z `dev`: `dbmate up` na `main` (bez testovacích dát) a commit `db/schema.sql`.

## Mimo rozsahu

- API (Cloudflare Workers), Hyperdrive, Cloudflare Access – modul API.
- Obmedzenie prístupu na úrovni riadkov (RLS) – nerobí sa: externí obchodníci majú rovnaké práva ako interní, rola externého dodávateľa nevzniká (rozhodnutie 2026-10-11).
- Výpočtové pohľady marže, výnosov a provízií – samostatná migrácia (pozri Pohľady).
- Presun dát z HubSpotu, mapovanie produktov, archív ticketov – modul migrácie.
- Prenos nákupných cien z Cockpitu – modul marže a provízií.

## Otvorené body, ktoré ovplyvňujú modul

- Definície rollupov v HubSpote (objemy, výnosy) nie sú potvrdené. Výpočtové pohľady preto nie sú v `0001`; prídu samostatnou migráciou po potvrdení.

## Výstupy

- `db/migrations/0001_jadro.sql`, `db/migrations/0002_pracovny_kalendar.sql`
- `db/schema.sql`
- `db/dbmate.sh`
- `db/test/seed.sql`, `db/test/checks.sql`, `db/test/run.sh`
- `package.json` (dbmate)
- `README.md` – sekcia „Databáza“ (ako spustiť migrácie na `dev` a `main`)
- aktualizované `docs/STAV.md`, `docs/CHANGELOG.md`, tento súbor

## Hotové, keď

- Migrácie prejdú na `dev` hore aj dole a kontrolné dotazy dajú očakávané výsledky.
- Peter schváli výsledky a migrácie sú nasadené na `main`.
- `db/schema.sql` zodpovedá stavu `main` a je v repozitári.
