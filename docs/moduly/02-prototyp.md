# Modul 2 – Prototyp na prezeranie dát

Stav: zadanie schválené 11. 10. 2026; kroky 1–4 a 6 hotové (API a frontend lokálne), nasadené na https://crm-core.peter-700.workers.dev za Cloudflare Access (iba peter@greenlogy.com). Ďalej kontrola vzorky (krok 8).

## Priebeh

- 11. 10.: zadanie schválené, technické rozhodnutia 1–3. Krok 1: `sample/select.ts` vybral 44 zákazníkov (30 firiem, 14 domácností, 166 dealov, 144 OOM, 213 zmluvných a 29 nákupných cien), všetci úplní. Návrh v `exports/prototyp/vzorka-navrh.md` čaká na schválenie.
- 11. 10.: vzorka schválená. Krok 2: pravidlá mapovania 1–8 potvrdené (nákupná cena = `cena_obchod`). `sample/load.ts` vygeneroval SQL (1 363 riadkov), nahraté na `dev` cez `sample/psql-dev.sh`, počty v DB sedia s manifestom. Zmazanie: `exports/prototyp/vzorka-delete.sql`.
- Zistenia z nahratia (53, `exports/prototyp/nahratie-zistenia.md`): 18 dealov má opakované číslo zmluvy (zmluvy bez čísla – rozpor s `contract.number` unikátnym a 1 deal = 1 zmluva); 10 veľkoobchodných cien bez smeru (nastavené „odber“); 13 zmluvných cien a 4 OOM nenahraté; 7 OOM s účinnosťou „do“ pred „od“.
- 11. 10.: krok 3 – rola `crm_prototype_ro` na `dev` (`api/db/create-prototype-role.sh` + `prototype-role.sql`): SELECT na všetko, `default_transaction_read_only`, pripojenie v `.dev.vars` ako `DATABASE_URL_DEV_RO`. Overené: SELECT prechádza, INSERT zamietnutý.
- 11. 10.: krok 4 – API v `api/` (Hono 4.13.8, postgres.js 3.4.9, wrangler 4.135.0, TypeScript 5.9.3). Lokálne `api/dev.sh` (rola iba na čítanie), test `api/smoke.sh`: všetky endpointy 200, zoznam vracia 44 zákazníkov, zlé ID 400, neexistujúci záznam 404, POST 405. Typová kontrola bez chýb. `npm audit`: produkčné balíky bez zraniteľností, 4 vysoké vo vývojových nástrojoch (wrangler).
- 11. 10.: krok 6 (pred krokom 5, Peter schválil poradie) – frontend vo `web/` (React 19.3, Vite 8.3, react-router-dom 7.18): zoznam zákazníkov, karty zákazníka, OOM a zmluvy. Tokeny generuje `web/scripts/tokens.ts` z `docs/dizajn/system/tokens.json`. Lokálne `npm run dev` s proxy `/api` na `api/dev.sh`. Build a typová kontrola bez chýb, `npm audit` bez zraniteľností.
- 11. 10.: kroky 5 a 7 – jeden Worker `crm-core` pre API aj frontend (rozhodnutie 2026-10-11, Pages sa nepoužíva). Hyperdrive `crm-core-dev` (ID `c7a47fba727d45ec83565393f125c9d0`, rola `crm_prototype_ro`, skript `api/db/create-hyperdrive.sh`). Prvé nasadenie bez verejnej adresy, Peter zapol Access „All traffic“ (Allow iba peter@greenlogy.com, Google), potom zapnutá adresa `workers.dev`. Overené: bez prihlásenia `/`, `/api/health` aj `/api/customers` vracajú 302 na `greenlogy.cloudflareaccess.com`.
- Zistenie: 21 zmlúv B2B_elektrina a 3 B2C nemajú zmluvnú cenu (pravdepodobne dealy s opakovaným číslom zmluvy – cena sa priradila najnovšiemu dealu); 5 zmlúv EFET nemá OOM ani ceny.
- Zistenie k `customer_v`: vracia 53 zákazníkov namiesto 44 – kontakt bez firmy sa počíta ako B2C, aj keď je iba kontaktom na deale firmy. Zoznam zákazníkov v API preto bude brať iba kontakty, ktoré vlastnia OOM, deal alebo zmluvu; úprava pohľadu sa navrhne samostatne.
- Zistenie pre migráciu: 297 OOM nemá deal v stave zmluvy ani ukončený deal, vlastníka nemožno odvodiť; pri 124 OOM sa vlastník odvodil z ukončeného dealu. Veľkoobchodné OOM majú iba 2 zákazníkov.

## Cieľ

Overiť dátový model v0.3.1 na skutočných dátach skôr, ako sa začne plná migrácia a zápisové funkcie.
Peter si v prehliadači prezrie 40 skutočných zákazníkov z HubSpotu nahratých do Neon vetvy `dev` a skontroluje, či firmy, kontakty, OOM, dealy, zmluvy a ceny sedia s HubSpotom.

Prototyp je **iba na čítanie a iba na `dev`**. Nič nezapisuje do HubSpotu ani do `main`.

## Pravidlá

- Každý krok nižšie sa predkladá na schválenie zvlášť. Ďalší krok začne až po Petrovom potvrdení.
- Zápis do databázy (nahratie a zmazanie vzorky), vytvorenie databázovej roly, nastavenie Cloudflare (Worker, Hyperdrive, Pages, Access) a nasadenie iba s Petrovým súhlasom.
- Skutočné osobné údaje vo vzorke sú povolené výnimkou (rozhodnutie 2026-10-11). Hosting iba v EÚ, osobné údaje sa nezapisujú do logov (ani vo Workeri, ani v skriptoch).
- Veľké výstupy (zoznamy, JSON, logy) idú do `exports/prototyp/` (nie je v gite), do chatu iba krátky súhrn.
- Prístupy iba v `.dev.vars` (`HUBSPOT_TOKEN`, `DATABASE_URL_DEV`) a vo `wrangler secret`. Nikdy v repozitári.
- Schéma databázy sa nemení. Ak prototyp ukáže chybu v modeli, zapíše sa ako zistenie a rieši sa novou migráciou samostatne.
- Vzhľad podľa `docs/dizajn/`: `system/tokens.json` ako CSS premenné, pravidlá zo `system/README.md`, obrazovky `01`–`03` ako predloha.

## Rozsah

### Krok 1 – Výber vzorky (iba čítanie z HubSpotu)

Skript `integrations/hubspot-sync/sample/` číta z HubSpotu a zostaví návrh 40 zákazníkov:

| Skupina | Počet |
| --- | --- |
| B2B firmy | 12 |
| Domácnosti (kontakt bez firmy) | 10 |
| Výrobcovia (aspoň 1 sharing a 1 veľkoobchod) | 6 |
| Firmy s viacerými OOM | 4 |
| Kontakty s viacerými firmami | 4 |
| Zákazníci s ukončenou zmluvou | 4 |

- Firmy s viacerými OOM sa zisťujú cez dealy (OOM v HubSpote nemá väzbu na firmu).
- Pri každom zákazníkovi sa načítajú aj súvisiace záznamy: kontakty, OOM, dealy, zmluvné ceny a nákupné ceny.
- Výstup: `exports/prototyp/vzorka-navrh.md` (HubSpot ID, názov, skupina, počty OOM, dealov a cien) a `exports/prototyp/vzorka-data.json` (surové dáta pre krok 2).
- Peter zoznam schváli alebo upraví.

### Krok 2 – Nahratie vzorky do `dev`

- Skript `integrations/hubspot-sync/sample/load.ts` mapuje schválenú vzorku do tabuliek jadra podľa pravidiel z `docs/01-datovy-model.md` (sekcia „Migrácia z HubSpotu“), zjednodušene:
  - produkty sa nemapujú na katalóg (iba to, čo zmluvná cena nevyhnutne potrebuje),
  - duplicity sa neriešia, chybné hodnoty (IČO, chýbajúce väzby) sa zapíšu do zoznamu zistení,
  - aktivity, e-maily, hovory, tickety a súhlasy sa nenahrávajú.
- Celé nahratie je jedna transakcia. Záznam v `sync_run` so `source = 'prototyp_vzorka'`.
- **Označenie na zmazanie:** skript zapíše `id` každého vloženého riadku (po tabuľkách) do `exports/prototyp/vzorka-manifest.json`. Zmazanie (`exports/prototyp/vzorka-delete.sql` cez `sample/psql-dev.sh`) odstráni presne tieto riadky v opačnom poradí väzieb, ich záznamy v `audit_log` a riadok v `sync_run`. Iné dáta na `dev` sa nedotkne.
- Výstup: súhrn počtov po tabuľkách a zoznam zistení v `exports/prototyp/nahratie-zistenia.md`.

### Krok 3 – Databázová rola iba na čítanie

- Rola `crm_prototype_ro` na `dev` s právom `SELECT` na tabuľky a pohľady jadra, bez zápisu.
- Pripojenie tejto roly sa použije iba pre Hyperdrive. Heslo nikdy v repozitári.
- Rola nie je súčasťou dbmate migrácií (týka sa iba prototypu na `dev`); SQL príkazy budú v `api/db/prototype-role.sql` a spustia sa iba so súhlasom.

### Krok 4 – API (Cloudflare Worker v `api/`)

- Endpointy iba na čítanie (GET), odpovede JSON:

| Endpoint | Obsah |
| --- | --- |
| `GET /api/customers?q=&segment=&page=` | zoznam zákazníkov z `customer_v` (názov, IČO, segment, počet OOM, aktívne zmluvy) |
| `GET /api/companies/:id` | karta firmy: údaje, kontakty, OOM, dealy, zmluvy |
| `GET /api/persons/:id` | karta zákazníka-domácnosti (kontakt bez firmy) v rovnakej štruktúre |
| `GET /api/oom/:id` | karta OOM: údaje, zákazník, dealy, zmluvné ceny, kontakty z `contact_oom_v` |
| `GET /api/contracts/:id` | karta zmluvy: údaje, deal, OOM, zmluvné a nákupné ceny |

- Parametrizované dotazy, žiadne skladanie SQL z textu. Chyby bez osobných údajov v logu.
- Lokálny vývoj cez `wrangler dev` s `DATABASE_URL_DEV`.

### Krok 5 – Hyperdrive pre `dev`

- Konfigurácia Hyperdrive `crm-core-dev` napojená na Neon `dev` s rolou `crm_prototype_ro`. Iba so súhlasom (nastavenie Cloudflare).

### Krok 6 – Frontend (Cloudflare Pages v `web/`)

Štyri obrazovky:

1. **Zoznam zákazníkov** – tabuľka podľa komponentu `DataTable`, vyhľadávanie podľa názvu a IČO, filter segmentu. Každý zákazník na jednom riadku.
2. **Karta zákazníka** – podľa `01-karta-firmy.html` (variant B); pre domácnosť rovnaké rozloženie bez FinStatu.
3. **Karta OOM** – podľa `02-karta-oom.html`.
4. **Karta zmluvy** – podľa `03-karta-zmluvy.html`.

- Zobrazujú sa iba polia, ktoré sú v databáze. Časti návrhov bez dát (časová os aktivít, FinStat, SLA, marža a výnosy) ostanú ako prázdny stav s vetou „V prototype nie je“.
- KPI na karte zákazníka iba z uložených údajov: počet OOM, aktívne zmluvy, plánovaná ročná spotreba a výroba (MWh).
- Svetlý a tmavý režim podľa tokenov. Každý údaj iba na čítanie, žiadne tlačidlá s akciou.

### Krok 7 – Cloudflare Access a nasadenie

- Worker aj Pages za Cloudflare Access so SSO cez Google, prístup iba pre `peter@greenlogy.com`.
- Nasadenie a nastavenie Access iba so súhlasom.

### Krok 8 – Kontrola a zmazanie vzorky

- Peter prejde vzorku a zapíše zistenia (chyby modelu, mapovania, chýbajúce polia).
- Zistenia sa prenesú do `docs/01-datovy-model.md` (otvorené otázky) alebo do zadania modulu migrácie.
- Po skončení prototypu sa vzorka zmaže (`exports/prototyp/vzorka-delete.sql` cez `sample/psql-dev.sh`), rola `crm_prototype_ro` sa zruší alebo sa jej odoberú práva. Rozhodne Peter, či Worker, Pages a Hyperdrive ostanú pre ďalšie moduly.

## Mimo rozsahu

- Zápis a úpravy dát, ponuky, pipeline, servis, SLA, prihlasovanie viacerých používateľov a roly.
- Výpočtové pohľady (výnosy, marža, provízie).
- Plná migrácia z HubSpotu, mapovanie produktov, riešenie duplicít.
- Akákoľvek zmena na vetve `main`.

## Technické rozhodnutia (11. 10. 2026)

1. **Frontend:** React + Vite + TypeScript.
2. **API:** router Hono, ovládač `postgres` (postgres.js) cez Hyperdrive.
3. **Adresy:** predvolená `crm-core.<účet>.workers.dev` za Cloudflare Access; vlastná doména neskôr. Pôvodne aj `*.pages.dev` – nahradené jedným Workerom pre API aj frontend (rozhodnutie 2026-10-11).

## Výstupy

- `integrations/hubspot-sync/sample/` (výber, nahratie, zmazanie vzorky)
- `api/` (Worker, `wrangler.toml`, `api/db/prototype-role.sql`)
- `web/` (frontend)
- `exports/prototyp/` (mimo gitu): návrh vzorky, dáta, manifest, zistenia
- `README.md` – ako spustiť API a frontend lokálne
- aktualizované `docs/STAV.md`, `docs/CHANGELOG.md`, `docs/rozhodnutia.md`, tento súbor

## Hotové, keď

- Vzorka 40 schválených zákazníkov je na `dev` a jej počty sedia s HubSpotom.
- Peter si za Cloudflare Access prezrie zoznam a karty zákazníka, OOM a zmluvy.
- Zistenia sú zapísané a vzorka je po skončení zmazaná.
