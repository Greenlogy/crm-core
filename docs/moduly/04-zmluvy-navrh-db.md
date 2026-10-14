# Modul 4 – Zmluvy a ceny: návrh databázy

Verzia 0.15 · 14. 10. 2026 · `0027_zmluvy_bilancia` na `dev`, F3 na Teste otestovaná (časti 26.6, 26.7) · **`0023`–`0025` na `dev` (podľa `db/schema.sql`, commit `b301345`); `0026_zmluvy_import` overená nanečisto (časť 25.7), na `dev` nespustená**.
- v0.1 = návrh;
- v0.2 = Petrove odpovede 1–6 k časti 16 a doplnky a, b: pomerné množstvo v neúplnom roku, produkty Green namiesto Dodávka B2B, zákazník založený importom a `Osoba_ID`, príznak verejného osvetlenia, ručné trhové ceny, X2 /VN/, prekrytie nad skutočnou dobou platnosti s nástupníctvom, lokálne overenie importu na vzorových exportoch; plán migrácie `0023` (časť 18);
- v0.14 = odpovede 26–32, `0027` napísaná a overená nanečisto (časť 26.6);
- v0.13 = plán F3 `0027_zmluvy_bilancia` (časť 26);
- v0.12 = odpovede 23–25 v `0026`, API importu a obrazovky 25–27 lokálne overené (časť 25.8);
- v0.11 = `0026_zmluvy_import` napísaná a overená nanečisto vrátane vzorových exportov, odpovede 20–22 a doplnky a–c (časť 25.7);
- v0.10 = plán `0026_zmluvy_import` (časť 25);
- v0.9 = migrácia `0025` overená nanečisto, úpravy pri implementácii (časť 24);
- v0.8 = odpovede kola 3 (otázky 3b, 4, 8, 10–14, 19), VBattery AKU 1,00 € od 1. 1. 2026 v skripte, plán `0025_zmluvy_jadro` (časť 23);
- v0.7 = skript `db/seed/podnikatelia-2026.sh` (časť 22);
- v0.6 = kód F1b (časť 21): karta a formulár OOM, export OOM, variant tarifu produktu, VIWA za účet;
- v0.5 = Petrove úpravy k F1: oprava ceny dňa novým záznamom (pôvodný ostane „opravené“, kto a kedy, audit; tlačidlo „Opraviť“ na obrazovke 29) a zmena cenovej regulácie OOM aj s budúcim dátumom (uplatní nočný beh, na karte „naplánované“) – nová migrácia `0024_zmluvy_f1_opravy` (časť 19); migrácie zmlúv sa posúvajú na `0025`–`0029`;
- v0.4 = doplnok „schvaľuje ceny“ (vidí všetky zmluvy a maržu firmy nezávisle od tímu); `0023` overená nanečisto (časť 18.6), zápis parametrov, cien a prekladov priamo do tabuliek so strážením v databáze (časť 18.3);
- v0.3 = odpovede 6, 16–18 (front office = Servis, neurčito ako prolongácia v rámci druhu, krátka zmluva podľa mesiacov, „platí od“ iba dnes a neskôr); čítanie na `dev` pred `0023` (časť 18.1).

Vychádza z týchto podkladov:
- zadanie `04-zmluvy.md` v0.3 a otázky `04-zmluvy-otazky.md`;
- obrazovky 25–29 a `docs/rozhodnutia.md`;
- migrácie `0001`–`0022`;
- analýzy z kroku 1: `exports/importy-vzor-analyza.md` (vzorové exporty Office portálu a XM Trade) a `exports/cockpit-toky.md` (dnešné toky HubSpot → Cockpit);
- Petrove rozhodnutia ku kroku 2 (body 1–9, A, B; časť 15).

SQL v tomto dokumente je **náčrt**, nie migrácia. Presné migrácie sa napíšu až po schválení.
Nič sa nespúšťa, databáza sa nemení.

---

## 0. Východisko a poradie migrácií

**Čo už v databáze je (z modulu 0 / dátového modelu v0.3.1):**
- `contract` (0001):
  - `number` unikátne, `deal_id` unikátne (1 deal = 1 zmluva), zákazník firma/osoba, `segment`;
  - `status` (enum `contract_status`: rozpracovana, caka_na_podpis, podpisana, caka_na_zaradenie, aktivna, ukoncena, vypoved_neakceptovana, zmena_neuspesna);
  - `valid_from` / `valid_to`, `signed_at`, `auto_prolong`, `hubspot_deal_id`, `custom`, `org_id`;
  - audit, vlastné polia, dedenie segmentu; **bez RLS**.
- `contract_price` (0001):
  - riadok na zmluvu × OOM s `direction`, VT/NT, aditívom, koeficientom, poplatkami (OM, ZEM, VBattery v `numeric(12,2)`, RK €/kW), `vbattery_program` text, `status` platna/neplatna;
  - unikátna platná cena na zmluvu × OOM;
  - **bez väzby na cenník a bez cenového modelu**.
- `contract_purchase` (0001, rozhodnutie 2026-10-11): nákupné ceny z HubSpotu (produkt, rok, dátum nákupu, cena, odkaz do Cockpitu).
  Modul 4 ju nemení a výpočty ju nepoužívajú (marža firmy berie odhad portfólia z Cockpitu, zadanie časť 8).
  Ostáva pre presun dát z HubSpotu a porovnanie.
- `customer_status_calc` (0014): pravidlo 2 číta `contract.status IN ('podpisana','caka_na_zaradenie','aktivna') AND valid_from > dnes`.
- `oom`:
  - `planned_feed_in_mwh`, `source_power_kw`, `source_category` (lokálny zdroj), `voltage_level`, `pds`, `pds_tariff`, `price_regulation` (ANO/NIE/prázdne);
  - kontrola EIC `eic_is_valid` (formát + kontrolná číslica);
  - import OOM `oom_import_run` (0018) zo šablóny CRM.
- Modul 3: `product`, `price_list*`, `price_model` (cennik, fix, spot_plus_eur, spot_minus_eur, spot_minus_pct, cena_diela), `product_tariff`, `product_candidates`, `price_with_vat`.
- Modul 0: tímy a `team_permission` (modul `zmluvy`, `can_import`), `app_user.is_admin`, `lookup_list/lookup_value` (s jedným `hubspot_value` na hodnotu), `crm_external_ready()`.

**Predpoklad:** `contract`, `contract_price`, `contract_purchase` sú na Teste prázdne (dáta z HubSpotu sa ešte nenahrávali). Migrácia `0025` to overí a inak skončí chybou, rovnako ako `0019`.

| Migrácia | Obsah | Časť | Fáza |
| --- | --- | --- | --- |
| `0023_zmluvy_priprava` | modul 0: typ predajcu, „schvaľuje ceny“, právo „vidieť maržu firmy“, východiskové práva modulu Zmluvy; cenové parametre s históriou; trhové ceny (ručne); prekladová tabuľka `import_alias` so systémovými aliasmi; modul 2: plán výkupu lokálneho zdroja, verejné osvetlenie, história cenovej regulácie OOM; modul 3: variant tarifu produktu, VIWA za účet (popisy) – plán v časti 18 | 4, 9, 11, 18 | F1 |
| skript `db/seed/cenniky-2026.sh` (doplnok) | produkty Green 1T / 2T / 2T Vykurovanie / 1T VO, Dodávka B2B → Dobieha, VBattery V, cenník „Podnikatelia nad 30 MWh“ od 1. 10. 2026 | 11.3 | F1 |
| `0024_zmluvy_f1_opravy` | oprava ceny dňa novým záznamom s históriou, budúca zmena cenovej regulácie OOM (nočný beh), hláška pri cudzej naplánovanej zmene parametra – časť 19 | 4.2, 11.2, 19 | F1 |
| `0025_zmluvy_jadro` | prerobenie `contract`, nové `contract_oom` s nástupníctvom, prerobenie `contract_price`, `contract_flag`, `price_exception`, RLS a audit, úprava `customer_status_calc` | 1–3, 5, 7, 12 | F2 |
| `0026_zmluvy_import` | `contract_import`, `Osoba_ID` a príznak „založený importom“ pri zákazníkovi, funkcie náhľadu a uloženia importu Office portálu, import OOM priamo z XM Trade | 8 | F2 |
| `0027_zmluvy_bilancia` | cena pre obchodníka, ročná bilancia (pridaná hodnota, marža firmy), príznaky Pod hranicou / Chýba cena | 4, 6, 7 | F3 |
| `0028_zmluvy_nocny_beh` | upozornenia, automatická prolongácia, prechod na novú verziu cenníka, časový rez pri zmene regulácie | 7 | F4 |
| `0029_zmluvy_cockpit` | rola `crm_cockpit`, pohľady pre Cockpit (zrkadlo dealov a OOM, ročné riadky, súhrny) | 10 | F5 |

---

## 1. Zmluva (`contract`, úprava)

```sql
CREATE TYPE contract_type AS ENUM (
  'dodavka_domacnost', 'dodavka_firma_nn', 'dodavka_firma_vn', 'vykup', 'viwa'
  -- neskôr: 'velkoobchod' (konfirmácie EFET), 'green_solar' (zmluva o dielo) – zadanie časť 16
);
CREATE TYPE contract_phase AS ENUM (        -- fáza v Office portáli (zadanie časť 3, O1, O10)
  'rozpracovana', 'caka_na_podpis', 'fyzicke_podpisovanie', 'elektronicke_podpisovanie',
  'podpisana',                              -- „Finálne podpísaná“ aj „Podpísaná“
  'odmietnuta', 'ukoncena',                 -- kód 8
  'neuspesna'                               -- kód 9
);
CREATE TYPE contract_close_reason AS ENUM ('akvizicia', 'retencia', 'autoprolong', 'prepis', 'nove_oom');

ALTER TABLE contract
  DROP COLUMN status,                       -- nahrádza phase + vypočítaný stav (časť 1.1)
  DROP COLUMN confirmed, DROP COLUMN signed_at,
  ADD COLUMN op_id              uuid UNIQUE,           -- [ID] z Office portálu; stabilný kľúč popri čísle
  ADD COLUMN type               contract_type NOT NULL,
  ADD COLUMN phase              contract_phase NOT NULL,
  ADD COLUMN signed_on          date,                  -- platnosť od (deň podpisu)
  -- valid_from / valid_to (existujú) = účinnosť od – do z Office portálu, do NULL = neurčito
  ADD COLUMN prolonged_to       date,                  -- automatická prolongácia v CRM (časť 7.2); údaje z OP sa nemenia
  ADD COLUMN small_business     boolean NOT NULL DEFAULT false,
  ADD COLUMN list_price         boolean NOT NULL DEFAULT false,   -- cenníková cena
  ADD COLUMN viwa_package       text,                  -- kód produktu VIWA (basic / plus / pro), keď ho zostava doplní (O5)
  ADD COLUMN close_reason       contract_close_reason, -- z OP, keď ho zostava doplní (O6); dovtedy z CRM
  ADD COLUMN owner_id           uuid REFERENCES app_user (id),   -- „Uzatvoril“ (obchodník)
  ADD COLUMN created_by_name    text,                  -- „Vytvoril“ v OP (iba text, nie používateľ CRM)
  ADD COLUMN previous_contract_id uuid REFERENCES contract (id),  -- CRM: retencia, prepis, obnova
  ADD COLUMN related_contract_id  uuid REFERENCES contract (id),  -- CRM: VIWA ↔ dodávka
  ADD COLUMN note               text,                  -- CRM
  ADD COLUMN op_updated_at      timestamptz,           -- Greatest_updated_at posledného importu
  ALTER COLUMN number SET NOT NULL;
-- last_import_id → contract_import pribudne v 0026 (tabuľka importov vzniká až tam)
DROP TYPE contract_status;
```

- **Typ zmluvy** určí import (časť 8.3): domácnosť → `dodavka_domacnost`; `Elektrina_vyroba` → `vykup`; VIWA podľa balíka alebo čísla `RRVIWP…`; inak firma NN/VN podľa napäťovej úrovne OOM (vn, vvn → VN). Zmluva s OOM na NN aj VN je chyba riadku, pretože NN a VN sú samostatné zmluvy.
- **Kto čo mení:**
  - stĺpce z Office portálu (číslo, typ, fáza, dátumy, príznaky, balík, obchodník) mení **iba import** (spúšťač: zmena týchto stĺpcov mimo funkcie importu → chyba);
  - stĺpce z CRM (`previous_contract_id`, `related_contract_id`, `close_reason` kým ho OP neposiela, `note`, `custom`) mení obchodník pri svojich zmluvách a Servis.
- `deal_id` ostáva (modul 5 prepojí deal so zmluvou); import ho nevypĺňa.
- `signed_at` (timestamptz) nahrádza `signed_on` (date) – Office portal posiela iba dátum.

### 1.1 Stav zmluvy (vypočítaný, nie uložený)

Ako pri cenníkoch (rozhodnutie 2026-10-13): uložená je iba fáza z Office portálu. Stav sa počíta z fázy a dátumov v Europe/Bratislava a nemôže sa rozísť s dátumom.

```sql
contract_effective_to(c contract) → date   -- coalesce(prolonged_to, valid_to)
contract_state(c contract, p_today date default crm_today()) → text
```

| Stav | Podmienka |
| --- | --- |
| V príprave | fáza rozpracovaná, čaká na podpis, fyzické alebo elektronické podpisovanie |
| Podpísaná | fáza podpísaná a (`valid_from` prázdne alebo > dnes) |
| Účinná | fáza podpísaná, `valid_from` ≤ dnes ≤ `contract_effective_to` (prázdne = neurčito) |
| Skončená | fáza ukončená, alebo podpísaná a dnes > `contract_effective_to` |
| Odmietnutá / Neúspešná | fáza odmietnutá / neúspešná |

**`customer_status_calc` (pravidlo 2)** sa zmení na `c.phase = 'podpisana' AND c.valid_from > p_today` a pravidlo 1 zostáva na OOM (zadanie časť 3: stav zákazníka sa naďalej riadi OOM). Pohľad `contract_v` pridá `state`, `effective_to`, počty OOM a príznaky (časť 7).

---

## 2. OOM v zmluve (`contract_oom`, nová)

```sql
CREATE TYPE contract_oom_group AS ENUM ('dodavka', 'vykup_viwa');   -- OOM najviac v jednej zmluve z každej skupiny

CREATE TABLE contract_oom (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id      uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  oom_id           uuid NOT NULL REFERENCES oom (id),
  org_id           uuid NOT NULL REFERENCES org (id),
  grp              contract_oom_group NOT NULL,      -- z typu zmluvy (spúšťač)
  valid_from       date,                             -- začiatok účinnosti (kópia z contract.valid_from)
  op_valid_to      date,                             -- koniec účinnosti z Office portálu (kópia z contract.valid_to)
  valid_to         date,                             -- SKUTOČNÝ koniec OOM v zmluve: účinnosť + prolongácia,
                                                     -- skrátený nástupníckou zmluvou (doplnok a); NULL = neurčito
  successor_id     uuid REFERENCES contract (id),    -- zmluva, ktorá na tomto OOM nastúpila a skrátila prolongáciu
  is_binding       boolean NOT NULL DEFAULT false,   -- fáza podpísaná (kópia, spúšťač)
  product_id       uuid REFERENCES product (id),     -- produkt Greenlogy pri OOM: IN GREEN 1T, DD2, DMP1… (ZOM_nazov_tarifa_glg)
  qty_vt_mwh       numeric(12,3) NOT NULL DEFAULT 0 CHECK (qty_vt_mwh >= 0),   -- zmluvné množstvo VT/JT za rok, v MWh
  qty_nt_mwh       numeric(12,3) NOT NULL DEFAULT 0 CHECK (qty_nt_mwh >= 0),
  source_power_kw  numeric(12,3) CHECK (source_power_kw >= 0),                 -- výkon zdroja z OP (výkup, VIWA, VBattery)
  created_at, updated_at,
  UNIQUE (contract_id, oom_id),
  CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from),
  -- skrátiť sa smie iba prolongácia, nie účinnosť z Office portálu
  CHECK (successor_id IS NULL OR op_valid_to IS NULL OR valid_to >= op_valid_to),
  -- OOM je v jednom čase najviac v jednej podpísanej zmluve o dodávke a jednej o výkupe / VIWA (zadanie časť 4);
  -- obmedzenie je nad SKUTOČNOU dobou platnosti (doplnok a)
  EXCLUDE USING gist (oom_id WITH =, grp WITH =,
                      daterange(valid_from, valid_to, '[]') WITH &&)
    WHERE (is_binding AND valid_from IS NOT NULL)
);
```

### 2.1 Nástupníctvo a prekrytie (doplnok a)

Databáza nedovolí prekrytie skutočných dôb platnosti. Predtým, ako sa nová zmluva na OOM uloží, funkcia `contract_oom_succession(p_new contract_oom)` (volá ju import aj nočný beh) rozhodne podľa toho, či sa nová účinnosť prekrýva so starou:

| Nová zmluva začne … | Výsledok |
| --- | --- |
| po skutočnom konci starej | nič, obdobia sa neprekrývajú |
| počas **prolongácie** starej (po `op_valid_to`) | stará na tomto OOM skončí deň pred novou (`valid_to = nová.valid_from − 1`, `successor_id`), ceny prolongácie po tomto dni sa zmažú (zdroj `prolongacia`) a príznak „Sprolongované bez novej ceny“ sa uzavrie. Nová dostane `previous_contract_id` = stará, ak ho ešte nemá. Platí pre retenciu (ten istý zákazník) aj prepis (iný zákazník) |
| počas **účinnosti z Office portálu** starej | **chyba riadku** „OOM … je v zmluve … do … – prekrytie“ (obrazovka 27), nič sa neuloží |

- Skrátenie ide **po OOM**: zmluva s 3 OOM, z ktorých 1 prešlo do novej zmluvy, beží na ostatných 2 ďalej.
- `contract.prolonged_to` = najneskorší `valid_to` jej OOM.
- Ak sa nová zmluva zruší (fáza Odmietnutá alebo Neúspešná po podpise), skrátenie sa **nevracia samo**: stará dostane príznak „Na kontrolu“ a Servis rozhodne.
- **Zmluvy na dobu neurčitú** (domácnosti, výkup, VIWA – Office portal nemá „účinnosť do“; Peter, odpoveď 16):
  - správajú sa ako prolongácia, **iba v rámci toho istého druhu** (`grp`: dodávka – dodávka, výkup/VIWA – výkup/VIWA);
  - nová podpísaná zmluva s neskorším podpisom a neskorším začiatkom ukončí starú na tom OOM deň pred sebou (`successor_id`, `previous_contract_id`);
  - náhľad ukáže upozornenie „zmluva na neurčito … ukončená nástupcom“;
  - nová VIWA na OOM ukončí výkup na tom OOM, zmluvu o dodávke nechá (iná skupina);
  - chybou ostáva prekrytie dvoch zmlúv s vyplneným „účinnosť do“ z OP a nová zmluva podpísaná skôr ako stará;
  - CHECK `valid_to >= op_valid_to` platí iba pri vyplnenom `op_valid_to`, takže skrátenie neurčitej zmluvy prejde.

- **Zmluvné množstvo** (rozhodnutie 1):
  - hodnoty pri OOM (`ZOM_spotreba_1t_vt`, `ZOM_spotreba_nt`) prevedené podľa `MJ` na MWh (kWh / 1000);
  - súčet za zmluvu (`spotreba_sum`) sa neukladá, nesúlad je iba upozornenie v náhľade;
  - množstvo platí pre každý rok rovnako (zadanie časť 4).
- **Výkup a VIWA** (rozhodnutie 3):
  - Office portal množstvo neposiela, `qty_*` ostáva 0;
  - bilancia berie plán výkupu z OOM `oom.planned_feed_in_mwh` (časť 11.2), nie kópiu – zmena plánu na OOM sa prejaví hneď.
- **Prekrytie** (časť 2.1):
  - vynucuje databáza iba pri podpísaných zmluvách, nad skutočnou dobou platnosti;
  - zmluvy v príprave sa smú prekrývať (retencia sa pripravuje ešte počas starej zmluvy);
  - skutočné prekrytie účinností z Office portálu ukáže import v náhľade ako chybu riadku (obrazovka 27).
- **OOM, ktoré v novom exporte zmluvy chýba:** zo zmluvy sa odstráni (cena aj riadok), v náhľade je to „Zmena – OOM odobraté“. Pri podpísanej zmluve upozornenie, lebo zmena by mala byť novou zmluvou.
- **Kontaktné osoby zo zmluvy na OOM** (zadanie časť 4, modul 2 časť 5): Office portal ich v zostave neposiela. Pripraví sa iba zdroj `oom_contact_source = 'zmluva'`, prenos príde, keď zostava stĺpce doplní (otázka 13).

---

## 3. Ceny na zmluve (`contract_price`, prerobenie)

Jeden riadok = **jedna zložka ceny jedného produktu pre OOM (alebo pre celú zmluvu) a jedno obdobie**. Komodita, mesačná platba za OM, ZEM, VBattery a VIWA sú samostatné riadky s vlastným produktom. Prechod na novú verziu cenníka (modul 3, časť 6.2) tak ide po produktoch.

```sql
CREATE TYPE price_slot AS ENUM (
  'komodita',        -- dodávka / výkup: FIX, SPOT ±, cenník (DD, DMP, IN GREEN po prolongácii)
  'poplatok_om',     -- mesačná platba za OM (Poplatky B2B 5 €, pri DD/DMP je v položke komodity)
  'zem',             -- ZEM domácnosti
  'program',         -- VBattery (STANDARD, PREMIUM, MAX, AKU, V)
  'viwa_ucet',       -- VIWA mesačná platba za účet (oom_id NULL)
  'viwa_kw'          -- VIWA poplatok za kW výkonu výrobného OOM
);

-- contract_price sa zruší a založí znova (na Teste je prázdna, migrácia to overí)
CREATE TABLE contract_price (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id           uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  oom_id                uuid REFERENCES oom (id),           -- NULL iba viwa_ucet (a neskôr veľkoobchod)
  org_id                uuid NOT NULL REFERENCES org (id),
  slot                  price_slot NOT NULL,
  product_id            uuid NOT NULL REFERENCES product (id),
  price_model           price_model NOT NULL,
  price_list_item_id    uuid REFERENCES price_list_item (id),   -- iba model cennik
  valid_from            date NOT NULL,
  valid_to              date,                                   -- NULL = bez konca (výkup na neurčito)
  price_vt_eur_mwh      numeric(12,4),     -- FIX VT/1T, výkup FIX; pri cenníku kópia
  price_nt_eur_mwh      numeric(12,4),
  additive_eur_mwh      numeric(12,4),     -- SPOT + € / výkup SPOT − €
  additive_pct          numeric(7,4),      -- výkup SPOT − %
  fee_eur_month         numeric(12,4),     -- mesačná platba (OM, ZEM, program, VIWA účet)
  fee_kw_eur_month      numeric(12,4),     -- VIWA €/kW
  vat_rate              numeric(5,2),      -- kópia pri cenníku
  op_product_name       text,              -- názov z OP (GREEN_1T_INDIVIDUAL_2027) – pre históriu a kontrolu
  source                text NOT NULL CHECK (source IN ('import', 'prolongacia', 'cennik_prechod', 'regulacia', 'crm')),
  created_at, updated_at,
  CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CHECK ((price_model = 'cennik') = (price_list_item_id IS NOT NULL)),
  CHECK ((oom_id IS NULL) = (slot = 'viwa_ucet')),
  CHECK (CASE price_model
           WHEN 'fix'            THEN price_vt_eur_mwh IS NOT NULL
           WHEN 'spot_plus_eur'  THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_eur' THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_pct' THEN additive_pct IS NOT NULL
           ELSE true END),
  EXCLUDE USING gist (contract_id WITH =, coalesce(oom_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =,
                      slot WITH =, daterange(valid_from, valid_to, '[]') WITH &&)
);
DROP TYPE contract_price_status;   -- „platná“ = obdobie obsahuje dátum
```

- **Obdobie ceny** = cenové obdobie z OP (`ZZC_datum_od` / `_do`, rozhodnutie 3), **orezané na účinnosť zmluvy** (v exporte 20 riadkov začína skôr). Pri viacročnej zmluve je obdobie jeden rok (zadanie časť 5).
- **Cenníková cena:** spúšťač overí, že položka je zo schválenej verzie a skopírované hodnoty sa s ňou zhodujú. Potom ich zmena cenníka neprepíše (modul 3, časť 6.1).
- **Viac cien v jednom roku** (rozhodnutie 2): pre OOM sa vyberie cena podľa typu tarifu produktu pri OOM (IN GREEN 1T → 1T, IN GREEN 2T a 2T VYK → 2T). Ak sa nedá určiť, je to chyba riadku.
- **Produkt komodity** pri individuálnej cene: produkt pri OOM (IN GREEN 1T / 2T / 2T VYK). Cenový model určí názov produktu v OP podľa tabuľky v zadaní časti 10 a `GREEN_2T_VYK_INDIVIDUAL` = FIX (rozhodnutie A). Pri domácnosti produkt DDx s reguláciou podľa OOM, pri VBattery podľa XM Trade (rozhodnutie 4).
- **Mesačná platba za OM pri firmách:** individuálna zmluva dostane riadok `poplatok_om` s položkou cenníka „Poplatky B2B“ platnou k začiatku obdobia. Pri DD a DMP je poplatok v položke komodity (cenník modulu 3), takže samostatný riadok netreba.
- **Bez ceny:** zmluva s modelom cenník, ku ktorej sa nenájde položka (produkt nie je v platnej verzii), dostane príznak „Chýba cena“ (časť 7).
- Precision: všetky ceny a poplatky `numeric(12,4)` ako v cenníku (rozhodnutie 2026-10-13); výsledky bilancie `numeric(12,2)`.

---

## 4. Cenové parametre a trhové ceny

### 4.1 Cenové parametre s históriou (`price_parameter`, obrazovka 29)

```sql
CREATE TABLE price_parameter (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        uuid NOT NULL REFERENCES org (id),
  code          text NOT NULL CHECK (code IN (
                  'pomer_bl_pct',            -- 80 (PL = 100 − BL)
                  'rizikova_prirazka',       -- 4 €/MWh
                  'nasa_marza',              -- 4 €/MWh
                  'min_aditiv_obchodnik',    -- 6
                  'min_aditiv_manazer',      -- 0
                  'min_aditiv_vykup_lz',     -- 0
                  'nakup_energopomoc',       -- 72,40 €/MWh pre rok dodávky
                  'viwa_aditiv_basic', 'viwa_aditiv_plus', 'viwa_aditiv_pro')),  -- 25 / 20 / 15
  delivery_year smallint,            -- iba nakup_energopomoc (cena pre rok dodávky), inak NULL
  valid_from    date NOT NULL,
  value         numeric(12,4) NOT NULL,
  note          text,
  changed_by    uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (org_id, code, delivery_year, valid_from),
  CHECK ((code = 'nakup_energopomoc') = (delivery_year IS NOT NULL))
);
price_param(p_org uuid, p_code text, p_on date, p_year smallint default null) → numeric   -- hodnota platná k dátumu
```

- Riadok sa nemení ani nemaže: zmena = nový riadok s „platí od“. Výnimkou je riadok s budúcim dátumom, ten smie autor opraviť.
- **„Platí od“ iba dnes a neskôr** (Peter, odpoveď 18). Minulý dátum smie iba vlastník databázy (`crm_owner_session()`, skript východiskových hodnôt a jednorazovej histórie), nikdy aplikácia. Platí aj pre `market_price_daily`: história BL/PL od 1. 1. 2026 iba skriptom.
- Mení **admin a používateľ s príznakom „schvaľuje ceny“** (rozhodnutie 7, zadanie časť 6). „Minimálny aditív – výkup lokálny zdroj“ a „Nákupná cena energopomoci“ mení podľa zadania iba admin.
- **Čítanie:**
  - obchodník nevidí rizikovú prirážku, našu maržu ani odhad portfólia (zadanie časť 12);
  - vidí iba výslednú cenu pre obchodníka a minimálne aditívy;
  - celú tabuľku čítajú admin, „schvaľuje ceny“ a tímy s právom „vidieť maržu firmy“ (RLS, časť 12).
- Migrácia založí východiskové hodnoty zo zadania s „platí od“ 1. 1. 2026 (VIWA 1. 10. 2025) a bez autora.

### 4.2 Trhové ceny z Cockpitu (`market_price_daily`)

```sql
CREATE TABLE market_price_daily (
  on_date             date NOT NULL,          -- deň, ku ktorému hodnota platí (Europe/Bratislava)
  delivery_year       smallint NOT NULL,      -- CAL rok
  bl_eur_mwh          numeric(12,4),
  pl_eur_mwh          numeric(12,4),
  portfolio_eur_mwh   numeric(12,4),          -- odhad nákupnej ceny portfólia na rok
  spot_fve_eur_mwh    numeric(12,4),          -- očakávaná cena SPOT pre FVE (výkup v %)
  source              text NOT NULL CHECK (source IN ('cockpit', 'rucne', 'historia')),
  changed_by          uuid REFERENCES app_user (id),   -- pri ručnom zadaní
  fetched_at          timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (on_date, delivery_year)
);
trader_price(p_org uuid, p_year smallint, p_on date) → numeric
  -- (BL × pomer + PL × (100 − pomer)) / 100 + riziková prirážka + naša marža, všetko k dátumu p_on
  -- chýba BL/PL k dátumu → posledný predošlý deň (najviac 7 dní), inak NULL
```

- **Kým Cockpit nemá API** (Peter, odpoveď 5):
  - hodnoty zadáva ručne admin alebo „schvaľuje ceny“ na obrazovke 29 („Zadať ceny dňa“: rok dodávky, BL, PL, odhad portfólia, očakávaná cena FVE);
  - chýbajúci deň preklenie posledná hodnota (najviac 7 dní, potom príznak „Chýba cena“).
- **Neskôr:** denný Cron Workera (ako `oom_daily_run`) stiahne hodnoty z API Cockpitu (`source = 'cockpit'`); ručná hodnota toho istého dňa sa neprepíše.
- **História BL/PL od 1. 1. 2026** sa nahrá jednorazovo skriptom (`source = 'historia'`) zo zdroja, ktorý určí Peter (Sales portál alebo Cockpit), aby zmluvy podpísané od 1. 1. 2026 mali cenu pre obchodníka ku dňu podpisu.
- Cena pre obchodníka **ku dňu podpisu** sa uloží pri zmluve (časť 6.1). Po zmene parametrov alebo cien sa nemení.

---

## 5. Výnimky z ceny (`price_exception`, obrazovka 28)

```sql
CREATE TYPE price_exception_status AS ENUM ('caka', 'schvalena', 'zamietnuta', 'pouzita');  -- Expirovaná sa počíta

CREATE TABLE price_exception (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           uuid NOT NULL REFERENCES org (id),
  company_id       uuid REFERENCES company (id),
  person_id        uuid REFERENCES contact (id),
  years            smallint[] NOT NULL CHECK (cardinality(years) >= 1),
  price_model      price_model NOT NULL CHECK (price_model IN ('fix', 'spot_plus_eur', 'spot_minus_eur')),
  requested_value  numeric(12,4) NOT NULL,      -- FIX cena alebo aditív
  threshold_value  numeric(12,4) NOT NULL,      -- hranica v deň žiadosti (cena pre obchodníka / min. aditív) – snímka
  volume_mwh       numeric(12,3),               -- informatívne
  reason           text NOT NULL,
  requested_by     uuid NOT NULL REFERENCES app_user (id),
  status           price_exception_status NOT NULL DEFAULT 'caka',
  decided_by       uuid REFERENCES app_user (id),
  decided_at       timestamptz,
  decision_note    text,
  valid_until      date,                        -- schválenie + 30 dní na podpis
  contract_id      uuid REFERENCES contract (id),   -- pri stave pouzita
  created_at, updated_at,
  CHECK (num_nonnulls(company_id, person_id) = 1),
  CHECK ((status IN ('schvalena', 'zamietnuta', 'pouzita')) = (decided_at IS NOT NULL)),
  CHECK ((status = 'pouzita') = (contract_id IS NOT NULL))
);
```

- **Schvaľovanie a zamietnutie:**
  - smie iba používateľ s príznakom „schvaľuje ceny“ (CEO, obchodný riaditeľ), nikdy autor žiadosti – kontrola v databáze;
  - lehota 30 dní je parameter funkcie, nie konštanta v kóde.
- **Expirovaná** = schválená a `valid_until < dnes`. Počíta sa, neukladá (ako stavy cenníka).
- **Párovanie pri importe:**
  - podmienky: zmluva toho istého zákazníka, rok zmluvy ∈ `years`, rovnaký model, schválená, `signed_on ≤ valid_until`;
  - pri viacerých sa použije najnovšia;
  - výnimka prejde do stavu Použitá a stane sa hranicou pre pridanú hodnotu (časť 6).
- Žiadosť zakladá obchodník pri svojich zákazníkoch, vidia ju autor, schvaľovatelia a admin.

---

## 6. Ročná bilancia: pridaná hodnota a marža firmy

### 6.1 Snímka nákladu pri podpise (`contract_year_basis`)

Pridaná hodnota sa počíta z hodnôt **ku dňu podpisu**. Neskoršia zmena parametrov ju nesmie zmeniť, preto sa snímka uloží.

```sql
CREATE TABLE contract_year_basis (
  contract_id        uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  year               smallint NOT NULL,
  seller_type        seller_type,                 -- obchodník / manažér z owner_id v deň podpisu
  trader_price       numeric(12,4),               -- FIX: cena pre obchodníka k signed_on
  min_additive       numeric(12,4),               -- SPOT / výkup: minimálny aditív podľa typu predajcu / lokálny zdroj
  energopomoc_price  numeric(12,4),               -- domácnosti ANO: nákupná cena energopomoci roka
  viwa_additive      numeric(12,4),               -- odhad aditívu balíka
  exception_id       uuid REFERENCES price_exception (id),   -- ak je, hranica = jej hodnota
  computed_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (contract_id, year)
);
```

- Vypĺňa ju import pri prvom importe podpísanej zmluvy, pri zmene `signed_on` alebo ceny prepočíta.
- Bez BL/PL k dňu podpisu (staršie zmluvy) je `trader_price` NULL a zmluva dostane príznak „Chýba cena“ s textom „chýba cena pre obchodníka“.

### 6.2 Výpočet (pohľad `contract_year_balance_v`, iba čítanie)

Pre zmluvu × rok bilancie:
- **Objem** = Σ cez OOM (`qty_vt_mwh` + `qty_nt_mwh`) × podiel roka. Pri výkupe a VIWA sa namiesto toho berie `oom.planned_feed_in_mwh`.
  - **Podiel roka** (Peter, odpoveď 1):
    - celý rok v skutočnej dobe platnosti OOM = 1;
    - neúplný rok viacročnej zmluvy = počet mesiacov v roku / 12, napr. 1. 9. – 31. 12. 2026 = 4/12;
    - začatý mesiac sa počíta celý, rovnako ako poplatky.
  - **Zmluva kratšia ako 12 mesiacov:** množstvo v zmluve platí za celé obdobie a **nedelí sa** (neprepočítava sa na rok). Ak obdobie zasahuje do dvoch rokov, rozdelí sa do ročných bilancií **podľa mesiacov** (Peter, odpoveď 17). Príklad: 1. 10. 2026 – 31. 3. 2027, 10 MWh → 2026 = 5 MWh, 2027 = 5 MWh.
  - Neurčito (výkup, VIWA, domácnosti): každý rok od začiatku je celý, prvý rok pomerne.
- **Mesiace poplatkov** = počet mesiacov obdobia ceny v danom roku.
- **Výnos komodity:**

| Model | Výnos komodity |
| --- | --- |
| FIX / cenník | VT × qty_vt + NT × qty_nt (jednotarif: VT × celý objem) |
| SPOT + aditív | aditív × objem |
| výkup SPOT − € | aditív × objem |
| výkup SPOT − % | % × očakávaná cena SPOT pre FVE roka × objem |
| VIWA | odhad aditívu balíka × objem |

- **Pridaná hodnota obchodníka** = výnos komodity − náklad podľa tabuľky zadania časť 8. Iba komodita, bez poplatkov.
- **Marža firmy** = výnos komodity + poplatky (OM, ZEM, VBattery, VIWA účet a kW) − náklad marže. Náklad FIX je **dnešný** odhad portfólia roka z `market_price_daily`, pretože marža firmy sleduje skutočnú nákupnú cenu.
- Kontrola na príkladoch zo zadania časť 13:
  - FIX 21,3 MWh → 575,10 € / 1 808,10 €;
  - SPOT 9 € → 150 € / 570 €;
  - DD2 ANO → 51,26 € / 87,26 €;
  - VIWA Plus → 240 € / 346,80 €;
  - LZ 10 kW → 43,80 €;
  - výkup −10 % → 700 €.
- Dva pohľady:
  - `contract_year_value_v`: objem, výnos, pridaná hodnota – pre všetkých, kto zmluvu vidí;
  - `contract_year_margin_v`: marža firmy a náklad portfólia – vracia riadky iba pri `crm_can_see_margin()` (časť 12).
- **Tranža pre Cockpit** (zadanie časť 8): FIX pri `fix` a cenníku bez energopomoci, SPOT pri `spot_*` a VIWA, SEAS pri domácnosti s energopomocou.

---

## 7. Príznaky, upozornenia a nočný beh

### 7.1 Príznaky (`contract_flag`)

```sql
CREATE TYPE contract_flag_code AS ENUM (
  'pod_hranicou_bez_vynimky', 'chyba_cena', 'sprolongovane_bez_ceny', 'konci_do_4_mesiacov', 'kontrola_importu');
CREATE TABLE contract_flag (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  code        contract_flag_code NOT NULL,
  year        smallint,                 -- pri cene a hranici
  detail      text,                     -- bez osobných údajov
  raised_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES app_user (id),
  UNIQUE NULLS NOT DISTINCT (contract_id, code, year, resolved_at)
);
```

- **Pod hranicou bez výnimky:**
  - vznikne pri importe, keď pridaná hodnota roka < 0 a zmluva nemá spárovanú výnimku;
  - vyrieši ju schválenie výnimky dodatočne alebo ručné uzavretie schvaľovateľom s poznámkou.
- **Chýba cena:**
  - vznikne pri importe, prolongácii alebo časovom reze, keď časť účinnosti nemá cenu komodity;
  - zmizne sama, keď cena pribudne.
- **Sprolongované bez novej ceny:** z prolongácie; Servis potvrdí navrhnutý produkt (O11) a tým príznak uzavrie.
- **Končí do 4 mesiacov:** počíta sa v pohľade, ukladá sa iba kvôli jednorazovému upozorneniu.
- **Na kontrolu z importu:** napríklad produkt nie je v stave Predáva sa (zadanie časť 5) alebo mesačný variant `_PC_M09`.

### 7.2 Nočný beh (`contract_daily_run`, rovnaký Cron ako `oom_daily_run`, audit „Systém“)

1. **Upozornenie 4 mesiace pred koncom:**
   - kedy: zmluva o dodávke firmy, ktorá je podpísaná a má `contract_effective_to − 4 mesiace = dnes` (alebo neskôr bez upozornenia);
   - upozornenie dostane `owner_id` (časť 11.1, `notification`).
2. **Automatická prolongácia v deň po `contract_effective_to`:**
   - podmienky: zmluva má `auto_prolong`, je podpísaná a OOM nemá nástupcu (podpísaná zmluva o dodávke na tom istom OOM so začiatkom ≤ deň po konci);
   - `contract_oom.valid_to` += 12 mesiacov (iba OOM bez nástupcu), `prolonged_to` = najneskorší koniec;
   - keď nástupnícka zmluva príde neskôr, prolongáciu skráti podľa časti 2.1;
   - pre každé OOM sa založí cena z cenníka „Podnikatelia nad 30 MWh“: produkt navrhnutý podľa predošlého produktu OOM a typu tarifu (O11, časť 11.3) a mesačná platba za OM 5 € je v položke;
   - zmluva dostane príznak „Sprolongované bez novej ceny“;
   - keď produkt nejde určiť, cena sa nezaloží a vznikne príznak „Chýba cena“.
3. **Prechod na novú verziu cenníka:** v deň `valid_from` schválenej verzie podľa modulu 3, časť 6.2 (ceny s modelom `cennik` po produktoch; produkt chýba → „Chýba cena“).
4. **Časový rez pri zmene cenovej regulácie OOM:**
   - vstup: história regulácie (časť 11.2);
   - cenníková cena sa ukončí deň pred zmenou a od dátumu zmeny sa založí položka toho istého tarifu v druhom cenníku (ANO ↔ NIE);
   - pri vyradení malého podniku bez novej ceny vznikne „Chýba cena“ (zadanie časť 5).
5. Prepočet stavu zákazníka pre dotknutých zákazníkov (keď je zapnutý `customer_status_auto`).

---

## 8. Import Office portálu a XM Trade (obrazovka 27)

### 8.1 Princíp (ako import OOM, rozhodnutie 2026-10-13)

- **API:**
  - prečíta .xlsx (SheetJS, pripnutý kontrolným súčtom);
  - znormalizuje bunky: dátum 1900-01-01 = prázdne, kWh → MWh podľa `MJ`, IČO bez medzier, aliasy (časť 9);
  - pošle celý súbor ako JSON do databázy.
- **Databázová funkcia** `contract_import_run(p_org, p_rows jsonb, p_apply boolean)`:
  - náhľad: `p_apply = false`, iba čítanie;
  - uloženie: `p_apply = true`, v jednej transakcii, iba pri rovnakom odtlačku súboru a rovnakých počtoch ako v náhľade.
- **Súbor sa neukladá.** Do databázy nejde dátum narodenia ani rodné číslo – API ich zahodí ešte pred odoslaním (rozhodnutie 9).
- **Limity:** 5 000 riadkov, 10 MB. Prepočet stavu zákazníkov raz na konci, ako pri OOM.
- **Výsledok riadku** (zmluva × OOM × obdobie, zoskupený po zmluvách):
  - akcie: Nová, Zmena, Bez zmeny, Upozornenie, Chyba, Preskočené (test);
  - chyba v riadku zmluvy = **celá zmluva sa neuloží** (čiastočná zmluva by mala zlé bilancie), ostatné zmluvy áno.
- **Inkrementálne:**
  - zmluva s `Greatest_updated_at` ≤ `contract.op_updated_at` je „Bez zmeny“ a nespracúva sa;
  - riadky s `ano_test = A` sa preskočia.

```sql
CREATE TABLE contract_import (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id uuid NOT NULL REFERENCES org (id),
  user_id uuid NOT NULL REFERENCES app_user (id),
  source text NOT NULL CHECK (source IN ('office_portal', 'xm_trade')),
  file_name text NOT NULL, file_hash text NOT NULL,
  row_count integer NOT NULL, created_count integer NOT NULL, updated_count integer NOT NULL,
  unchanged_count integer NOT NULL, warning_count integer NOT NULL, error_count integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE contract_import_change (           -- „História importov“ na karte zmluvy
  import_id uuid NOT NULL REFERENCES contract_import (id),
  contract_id uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action IN ('nova', 'zmena')),
  summary text NOT NULL,                        -- „Fáza Čaká na podpis → Finálne podpísaná“; bez osobných údajov
  PRIMARY KEY (import_id, contract_id)
);
```

### 8.2 Párovanie

| Čo | Podľa čoho | Chyba |
| --- | --- | --- |
| Zmluva | `ID` (op_id), potom číslo zmluvy | číslo existuje s iným `ID` |
| OOM | EIC (`ZOM_eic`) | „OOM … nie je v CRM – najprv nahrajte export z XM Trade“ |
| Zákazník – firma | IČO (8 číslic, bez medzier); `Osoba_ID` sa uloží pri firme (`company.op_person_id`) | nenájdená → **založí sa** (nižšie); IČO je v CRM, ale firmu nevidíte → chyba |
| Zákazník – domácnosť | `Osoba_ID` (`contact.op_person_id`, unikátne v spoločnosti) | nenájdená → **založí sa** (nižšie) |
| Zákazník vs. OOM | zákazník zmluvy = aktuálny zákazník OOM | upozornenie (nie chyba) – prepis môže prísť neskôr |
| Obchodník | `ObchodnikNazov` → alias `obchodnik` (časť 9) → `app_user` | neznámy = chyba s ponukou „pridať alias“ |
| Fáza, produkt, sadzba | aliasy (časť 9) | neznámy názov = chyba s ponukou „pridať alias“ |
| Výnimka | zákazník + rok + model (časť 5) | – |

**Zákazník, ktorý chýba** (Peter, odpoveď 3), sa založí s príznakom „založený importom“:

```sql
ALTER TABLE company ADD COLUMN op_person_id uuid, ADD COLUMN created_by_import uuid REFERENCES contract_import (id);
ALTER TABLE contact ADD COLUMN op_person_id uuid, ADD COLUMN created_by_import uuid REFERENCES contract_import (id);
CREATE UNIQUE INDEX company_op_person_key ON company (org_id, op_person_id) WHERE op_person_id IS NOT NULL;
CREATE UNIQUE INDEX contact_op_person_key ON contact (org_id, op_person_id) WHERE op_person_id IS NOT NULL;
```

- **Firma:**
  - údaje: IČO, DIČ, IČ DPH, názov (`PONazov`);
  - vlastník = obchodník zmluvy;
  - kontrola duplicity IČO platí ako pri ručnom založení.
- **Domácnosť:**
  - údaje: meno, priezvisko, `Osoba_ID`, `is_household`;
  - bydlisko z XM Trade (`Sídlo firmy / bydlisko`), ak je k zmluve nahratý;
  - vlastník = obchodník zmluvy;
  - **dátum narodenia sa neukladá** (rozhodnutie 9);
  - kontrola duplicít osôb (e-mail, telefón) iba upozorní, ako v module 1.
- **Prvé párovanie existujúcej domácnosti** (pred prvým `Osoba_ID`, napr. po presune z HubSpotu):
  - ak má OOM zmluvy aktuálneho zákazníka-osobu s rovnakým menom, použije sa a uloží sa jej `Osoba_ID`;
  - inak sa založí nová osoba a náhľad ukáže upozornenie „možná duplicita s …“ (bez osobných údajov v logu).
- Príznak „založený importom“ sa zobrazí v zozname Zákazníci (filter) a na karte. Zruší ho prvá ručná úprava zákazníka alebo tlačidlo „Skontrolované“.

### 8.3 Pravidlá polí (rozhodnutia 1–4, 6)

- **Dátumy:**
  - účinnosť zo stĺpcov `ucinnost_od` / `_do`, cenové obdobia zo `ZZC_datum_od` / `_do` (stĺpce `ZmluvaZmluvneCeny_Datum_*` sa ignorujú);
  - 1900-01-01 = prázdne;
  - prázdne cenové obdobie pri produkte s rokom v názve = celý rok z názvu (13 riadkov vo vzorke).
- **Účinnosť domácností:** z XM Trade (`Dátum začiatku dodávky` OOM zmluvy, párovanie cez číslo zmluvy alebo EIC). Office portal ju pri domácnostiach neposiela (77 zo 77).
  - Účinnosť do: z OP (zatiaľ prázdne = neurčito).
  - Ak XM Trade ešte nebol nahratý, zmluva sa uloží bez `valid_from` (stav Podpísaná) s upozornením a doplní ju import XM.
- **Množstvo** (rozhodnutie 1): pri OOM, prevedené na MWh; nesúlad so `spotreba_sum` je iba upozornenie.
- **Výber ceny pri 1T aj 2T** (rozhodnutie 2): podľa typu tarifu produktu pri OOM; neurčiteľné je chyba riadku. Dva riadky toho istého produktu a obdobia s rôznou cenou sú tiež chyba (4 prípady vo vzorke, otázka 4).
- **Výkup a VIWA** (rozhodnutie 3): množstvo z plánu výkupu OOM. Výkon zdroja z OP sa uloží do `contract_oom.source_power_kw`; ak sa líši od OOM, náhľad dá upozornenie (OOM sa nemení).
- **VBattery** (rozhodnutie 4):
  - z produktu XM Trade „VBATTERY - DDx - ANO/NIE Energopomoc“ sa odvodí produkt Green DDx ANO/NIE, sadzba Dx (párovanie DDx = Dx) a cenová regulácia;
  - program (STANDARD, PREMIUM, MAX, AKU, V) je zo sadzby XM (`VBATTERY-PREMIUM`) alebo z tarify v OP;
  - zmluva dostane riadok `program` s položkou cenníka VBattery (AKU nemá položku – cena chýba, otázka 12).
- **EIC s podozrivým tvarom** (rozhodnutie 6): upozornenie, nie chyba. Podozrivý tvar:
  - 3. znak nie je `Z`, okrem sharingu s predponou `24GREENVV`;
  - alebo prvé 2 znaky nie sú číslice.
  - Kontrolná číslica ostáva povinná (`eic_is_valid`). Všetky EIC vo vzorkách ju majú správnu, vrátane `24GREENVV`.
- **Verejné osvetlenie** (Peter, odpoveď 4): ak má OOM v zmluve produkt verejného osvetlenia (DMP10, Green 1T VO), import nastaví na OOM `public_lighting = true` (časť 11.2). Príznak sa importom nikdy nezruší.
- **Produkt v stave Dobieha alebo Ukončený** pri novej zmluve (podpis po dátume zmeny stavu) → príznak „Na kontrolu“.
- `_PC_M09` (mesačná cena) → príznak „Na kontrolu“ (O2).

### 8.4 Import OOM priamo z exportu XM Trade (dopad na modul 2)

- **Formát:** CRM pozná stĺpce XM Trade priamo, bez prepisovania do šablóny (zadanie časť 10). API preloží hlavičky XM na polia šablóny OOM a zavolá existujúci `oom_import_run` (0018). Funkcia sa rozšíri iba o nové polia (planned_feed_in, zdroj účinnosti).
- **Hodnoty:** dátumy `DD.MM.RRRR`, `-` = prázdne, čísla ako text, kWh → MWh.

| XM Trade | OOM |
| --- | --- |
| EAN / EIC OM | `eic` |
| Napäťová úroveň (`nn`, `vn`) | `voltage_level` |
| Sústava (EIC PDS v zátvorke) / PDS | `pds` (alias) |
| Sadzba | `pds_tariff` (alias; `VBATTERY-*` → sadzba z produktu, rozhodnutie 4) |
| Produkt | cenová regulácia (`ANO/NIE Energopomoc`, `nereg.`), produkt DD pri VBattery |
| Cenová regulácia | iba ak produkt reguláciu neurčí (otázka 12) |
| Veľkosť ističa, RK, MRK, spôsob rezervovania, počet fáz, typ merania, TDO, spotrebná daň, fakturačné obdobie, spôsob záloh, percento zálohy | rovnomenné polia (aliasy pre texty) |
| Predpokladaná spotreba RRRR (JT/VT, NT) [kWh] | `planned_consumption_vt/nt_mwh` (rok bežný, inak nasledujúci) |
| Dátum začiatku dodávky, Platné do | `supply_from`, `supply_to`; účinnosť domácnosti (8.3) |
| Číslo zmluvy | väzba na zmluvu o dodávke (párovanie domácností) |
| Ulica, PSČ, Obec | adresa OOM |
| IČO / Rodné číslo | iba 8-ciferné IČO firmy; **rodné číslo sa zahodí v API** |
| Sprostredkovateľ, Odberateľ, Sídlo | iba párovanie (nie uloženie); osobné údaje |
| Trieda TDO | nové pole OOM `tdo_class` (Peter, otázka 14; aj pre Cockpit) – `0026` |
| Pásmo TSS/TPS, Typ zmluvy distribúcie, Stav zmluvy | neimportovať (Peter, otázka 14) |

**Zákazník nového OOM z XM Trade:**
- firma podľa IČO;
- domácnosť cez číslo zmluvy a `Osoba_ID` zo zmluvy; chýbajúca sa založí s príznakom „založený importom“ (časť 8.2).
- Preto sa pri spoločnom nahratí spracuje najprv XM Trade (OOM), potom Office portal (zmluvy). Ak domácnosť ešte nemá zmluvu v CRM, nové OOM z XM Trade čaká v náhľade s chybou „najprv nahrajte zmluvu z Office portálu“. Pri dvoch súboroch naraz ich import spáruje v jednom behu.

Import zakladá OOM ako Pripravované a stav ani zákazníka existujúceho OOM nemení (pravidlo modulu 2 ostáva).

---

## 9. Prekladová tabuľka pre importy (`import_alias`, rozhodnutie 5)

```sql
CREATE TABLE import_alias (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES org (id),
  source      text NOT NULL CHECK (source IN ('office_portal', 'xm_trade', 'vsetky')),
  kind        text NOT NULL CHECK (kind IN (
                'faza', 'produkt_op',        -- GREEN_1T_INDIVIDUAL → model + produkt
                'produkt_oom',               -- IN GREEN 1T, DD2, VBattery - V → produkt / program
                'sadzba', 'pds', 'obchodnik', 'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'iny')),
  name_norm   text NOT NULL,       -- normalizovaný názov z importu: malé písmená, viac medzier → jedna, bez diakritiky
  name_sample text NOT NULL,       -- ako prišiel (na zobrazenie)
  target      text NOT NULL,       -- kód hodnoty CRM: enum, kód číselníka, kód produktu, id používateľa
  target_extra jsonb NOT NULL DEFAULT '{}',   -- napr. {"price_model":"fix","tariff":"2t_vyk"}; {"year_from_name":true}
  is_system   boolean NOT NULL DEFAULT false, -- založené migráciou / skriptom; admin ich môže skryť, nie zmazať
  hidden_at   timestamptz,
  created_by  uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (org_id, source, kind, name_norm)
);
import_alias_resolve(p_org uuid, p_source text, p_kind text, p_name text) → text   -- NULL = neznámy
```

- **Normalizácia** (`import_name_norm`) zjednotí rozdiely ako „VBattery - V“ / „VBattery  - V“ alebo „TDO 4 “. Rok v názve produktu (`GREEN_1T_INDIVIDUAL_2027`, `2026_GREENVYR_AK [EUR]`) sa pred hľadaním nahradí `RRRR`; rok si import vezme z názvu.
- **Overenie cieľa:**
  - spúšťač overí, že `target` existuje (hodnota enumu, neskrytá hodnota číselníka, produkt, aktívny používateľ);
  - pri `sadzba` cieľ je kód sadzby bez PDS (`d1`) a PDS sa berie z OOM, ako pri párovaní produktov (modul 3, časť 2).
- **Neznámy názov = chyba riadku** s tlačidlom „Pridať alias“ v náhľade. Admin vyberie hodnotu z číselníka a náhľad sa prepočíta.
- **Spravuje admin** v Nastaveniach (nová stránka „Preklady importov“ pod Číselníkmi). Každá zmena ide do auditu.
- `lookup_value.hubspot_value` ostáva pre presun z HubSpotu. Aliasy sú iba pre importy Office portálu a XM Trade.

**Východiskové aliasy (skript, `is_system`):**

| Druh | Názov z importu | Cieľ |
| --- | --- | --- |
| fáza | Rozpracovaná, Čaká na podpis, Fyzické podpisovanie, Elektronické podpisovanie | rovnomenné |
| fáza | Finálne podpísaná, Podpísaná (O10) | `podpisana` |
| fáza | Odmietnutá; `8`; `9` (O1) | `odmietnuta`; `ukoncena`; `neuspesna` |
| produkt_op | `GREEN_1T_INDIVIDUAL_RRRR`, `GREEN_2T_INDIVIDUAL_RRRR` | FIX 1T / 2T |
| produkt_op | `GREEN_2T_VYK_INDIVIDUAL_RRRR` (**rozhodnutie A**) | FIX 2T vykurovanie |
| produkt_op | `GREEN_ISOTSK_PLUS_RRRR_R` | SPOT + aditív € (aditív v 1T/VT) |
| produkt_op | `RRRR_GREENVYR_AK [EUR]` / `[%]` / `RRRR_GREENVYR_PC_R` | výkup SPOT − € / − % / FIX |
| produkt_op | `RRRR_GREENVYR_PC_M09` | výkup FIX + príznak „Na kontrolu“ |
| produkt_oom | IN GREEN 1T / 2T / 2T VYK | produkty IN GREEN (časť 11.3) |
| produkt_oom | DD1–DD8, DMP1–DMP11 | Green DDx / DMPx (ANO/NIE podľa regulácie OOM) |
| produkt_oom | VBattery - STANDARD / PREMIUM / MAX / AKU / V | program VBattery |
| sadzba | X4-D1, X4-D2, X4-D3, X4-D5 (**rozhodnutie B**) | `d1`, `d2`, `d3`, `d5` (a X4-D4, X4-D6–D8 rovnako) |
| sadzba | D3 Aktiv /bývalá D3/, D3 Aktiv /bývalá D5/ (**rozhodnutie B**) | `d3` |
| sadzba | X2 /VN/ (Peter, odpoveď 6) | `x2` |
| pds | Západoslovenská distribučná (24X-ZSE-PDS----5), … | `zsd`, `ssd`, `vsd` |
| obchodník | mená z OP a XM | používatelia CRM – doplní admin pri prvom importe |

---

## 10. API pre Cockpit (rozhodnutie 8)

Cieľ: nahradiť Worker `greenlogy-hubspot-sync` zdrojom z CRM **bez zmeny agregácie v Cockpite** (`cockpit-uploads`), potom obidva zdroje porovnať.

### 10.1 Prístup

- Endpointy `GET /api/cockpit/v1/…` na Workeri `crm-core`, prístup cez Cloudflare Access **service token** (nie používateľ).
- Worker pre tieto cesty použije samostatné pripojenie (Hyperdrive) s rolou **`crm_cockpit`**:
  - iba SELECT na pohľady `cockpit_*_v`, nič iné;
  - bez povinného používateľa, ako predpokladá rozhodnutie 2026-10-11 („Cockpit vidí všetko“).
- **Bez osobných údajov domácností:**
  - pri osobe sa namiesto mena posiela iba ID zmluvy a zákazníka;
  - pri OOM osoby sa neposiela adresa ani meno (otázka 10);
  - firmy (názov, IČO) áno, ako dnes.

### 10.2 Zrkadlo dealov – `GET /api/cockpit/v1/deals?modified_since=…`

Pohľad `cockpit_deal_v` vracia **rovnaké polia ako dokument `cockpit_hubspot_deals`** (`exports/cockpit-toky.md`, časť 2.3). Riadok = zmluva.

| Pole Cockpitu | Z CRM |
| --- | --- |
| `deal_id` | `contract.hubspot_deal_id` (po presune dát), inak `contract.id`; navyše `contract_id`, `cislo_zmluvy` |
| `pipeline`, `pipeline_label` | mapovanie typu zmluvy na pôvodné ID: dodávka firma NN/VN → `641521`, výkup → `66703953`, VIWA → `794962763`, domácnosť → `639134` (Cockpit ju dnes vynechá; B2C ide ručne) |
| `dealstage` | pre `641521` s dobou neurčitou „etapa roka začiatku“ podľa tabuľky `B2B_ELEKTRINA_STAGE_TO_YEAR` (2024–2029); LZ výkup → `1036970423`; VIWA → `1165493894`; inak NULL |
| `hs_is_closed_won`, `status` | fáza podpísaná → true / `active`; inak `inflight` |
| `trvanie_zmluvy_list` | roky účinnosti (2026, 2027…); doba neurčitá → `["neurčito"]` |
| `innos_zmluvy_od/do`, `closedate`, `createdate` | `valid_from`, `contract_effective_to`, `signed_on`, `created_at` |
| `celkovy_objem_z_oom_mwh` | Σ ročné zmluvné množstvo OOM (výkup a VIWA: Σ plán výkupu) |
| `pocet_oom_spotreba`, `pocet_oom_dodavka`, `test_pocet_om` | počet OOM zmluvy |
| `priemerna_predajna_cena_z_oom` | objemom vážená cena komodity bežného roka (pri SPOT aditív, ako v HubSpote) |
| `n_kupn_cena` | cena pre obchodníka ku dňu podpisu (rozhodnutie 2026-10-10: nákupná cena = BL/PL + 4 + 4) |
| `new_hruba_marza` | **kompatibilná hodnota**: pridaná hodnota + mesačné platby za OM bežného roka (definícia HubSpotu z kola 1, C); potvrdiť porovnaním (otázka 11) |
| `nakupna_tranza`, `pricing_model` | FIX / SPOT / SEAS (časť 6.2) |
| `amount` | NULL (GreenSolar je mimo modulu 4) |
| `green_viwa___aditiv_konverzie`, `viwa_product_tier` | odhad aditívu balíka 25 / 20 / 15; basic / plus / pro |
| `is_local_purchase`, `lz_vykon_kw`, `lz_plan_mwh`, `lz_pocet_oom`, `lz_vynos_eur_total` | výkup s OOM lokálny zdroj: Σ výkon, Σ plán výkupu, počet OOM, aditív × plán |
| `hubspot_owner_id` | `app_user.hubspot_owner_id` obchodníka (kvôli porovnaniu), navyše e-mail |
| `hs_lastmodifieddate` | najneskoršia zmena zmluvy, jej OOM alebo cien |
| `subjekt` | názov firmy; pri domácnosti NULL |

- `GET /api/cockpit/v1/deals/ids` vráti všetky ID na „orphan reconcile“, rovnako ako dnes.
- **Medzery oproti HubSpotu:** pipelines **EFET** `702873630` a **GreenSolar** `8470397` z CRM zatiaľ neprídu (konfirmácie EFET a zmluvy o dielo sú v zadaní časť 16 „na neskôr“). Pri prepnutí musí Cockpit tieto dve pipelines brať ďalej z HubSpotu, kým nebudú v CRM (otázka 11).

### 10.3 Zrkadlo OOM – `GET /api/cockpit/v1/oom?modified_since=…`

Pohľad `cockpit_oom_v`:
- **Filter ako dnes:** Aktívne a (výrobný alebo lokálny zdroj, alebo firma). Polia ako `cockpit_hubspot_oom`: EIC, stav, typ, druh zdroja, plány, výkon, RK, istič, PDS, sadzba, napätie, IČO a adresa iba pri firme, obchodník, číslo zmluvy.
- **Naviac na rozdiel od HubSpotu:** `GET /api/cockpit/v1/oom/ids` (aj OOM, ktoré prestali byť aktívne). Rieši chybu dnešného inkrementálneho syncu, ktorý ich nevidí (`cockpit-toky.md`, časť 6, bod 2).

### 10.4 Natívne ročné údaje (zadanie časť 11)

- `GET /api/cockpit/v1/contract-years?year=…`: zmluva × rok × OOM s objemom, modelom, cenou alebo aditívom, tranžou, výnosom, pridanou hodnotou a maržou firmy (`crm_cockpit` vidí maržu).
- `GET /api/cockpit/v1/summary?year=…`: súhrny podľa segmentov B2C elektrina, B2B elektrina, B2B výkup, VIWA.

Tieto endpointy sú presnejšie ako zrkadlo, lebo objem neopakujú celý v každom roku. Cockpit na ne môže prejsť neskôr.

### 10.5 Porovnanie a prepnutie (Cockpit, mimo tohto repozitára)

1. **Najprv stiahnuť nasadený kód** `greenlogy-hubspot-sync` v0.5.0 do jeho repozitára (dnes v gite nie je).
2. Do sync Workera pridať zdroj CRM, ktorý zapisuje do **samostatných kolekcií** `cockpit_crm_deals` / `cockpit_crm_oom` a prípadne report rozdielov podľa čísla zmluvy:
   - objem, cena, marža, roky, počet OOM;
   - chýbajúce na jednej strane.
3. Prepnúť čítanie v `cockpit-uploads` až po Petrovom schválení rozdielov.

---

## 11. Dopady na moduly 0–3 (zadanie časť 14)

### 11.1 Modul 0 – používatelia, práva, upozornenia (`0023`)

```sql
CREATE TYPE seller_type AS ENUM ('obchodnik', 'manazer');
ALTER TABLE app_user
  ADD COLUMN seller_type     seller_type,              -- NULL = nepredáva
  ADD COLUMN approves_prices boolean NOT NULL DEFAULT false;   -- „schvaľuje ceny“ (CEO, obchodný riaditeľ)
ALTER TABLE team_permission
  ADD COLUMN can_see_company_margin boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT team_permission_margin_check CHECK (NOT can_see_company_margin OR module = 'zmluvy');
crm_can_see_margin() → boolean   -- tím má can_see_company_margin (modul zmluvy) ALEBO používateľ approves_prices
crm_approves_prices() → boolean
```

- **Typ predajcu a „schvaľuje ceny“** mení iba admin v Nastaveniach → Používatelia (obrazovka 12 dostane dve polia). Zmena ide do auditu.
- **„Vidieť maržu firmy“:**
  - nový stĺpec v matici práv modulu Zmluvy (obrazovka 13);
  - východiskovo CEO, Nákup, Marketing;
  - obchodný riaditeľ ju má cez príznak „schvaľuje ceny“ (O9), bez ohľadu na tím;
  - **„schvaľuje ceny“ navyše nezávisle od tímu dáva „vidieť všetky zmluvy“ (aj výnimky)** – Peter, doplnok k `0023`. Dôvod: obchodný riaditeľ je v tíme Sales_internal s „iba svoje“. Funkcia `crm_sees_all_contracts()` = tím s „všetko“ v module Zmluvy alebo „schvaľuje ceny“;
  - externý tím ju mať nesmie (poistka 2026-10-12, kontrola v databáze).
- **„Import zmlúv“:** existujúce `can_import` v module Zmluvy, východiskovo CEO, Servis, Nákup. Front office pozri otázku 6.
- **Práva modulu Zmluvy (východiskové hodnoty, mení admin).** Dnes (z `0006`) má modul Zmluvy:
  - Vidieť: všetko pri všetkých interných tímoch, iba svoje pri Sales_external;
  - Upravovať: všetko CEO a Nákup, ostatní nič.

  Podľa zadania (časť 12) sa zmení:

  | Tím | Vidieť | Upravovať údaje CRM | Import | Marža firmy |
  | --- | --- | --- | --- | --- |
  | CEO | všetko | všetko | áno | áno |
  | Nákup | všetko | všetko | áno | áno |
  | Marketing | všetko | nič | nie | áno |
  | Servis | všetko | **všetko** (dnes nič) | **áno** | nie |
  | Sales_internal | **iba svoje** (dnes všetko) | **iba svoje** (dnes nič) | nie | nie |
  | Sales_external | iba svoje | **iba svoje** (dnes nič) | nie | nie (poistka) |

  Migrácia mení **iba bunky, ktoré majú ešte východiskovú hodnotu** z `0006` (rovnako ako pri OOM, rozhodnutie 2026-10-12). Bunky, ktoré admin zmenil, ostanú a Peter dostane ich zoznam.

- **Upozornenia (`notification`, nová tabuľka v `0028`, kde sa prvý raz použije):**
  - stĺpce: `user_id`, `kind`, odkaz na zmluvu alebo výnimku, `created_at`, `read_at`;
  - v CRM zvonček a zoznam, e-mail neskôr (otázka 8);
  - použitie: 4 mesiace pred koncom (obchodník), Pod hranicou bez výnimky (všetci so „schvaľuje ceny“ + CEO), nová žiadosť o výnimku (schvaľovatelia), rozhodnutie o výnimke (autor).
- **Obrazovka 29** (rozhodnutie 7): parametre mení admin a „schvaľuje ceny“. Spoločná poznámka v menu Nastavení „Mení iba admin“ sa na tejto stránke nahradí textom „Mení admin a obchodný riaditeľ“ a položku menu uvidí aj používateľ so „schvaľuje ceny“. Ostatné Nastavenia ostávajú iba pre admina.
- **Nastavenia → Preklady importov** (časť 9): iba admin.

### 11.2 Modul 2 – odberné miesta (`0023`)

- **Plán výkupu lokálneho zdroja** (zadanie časť 9):

  ```sql
  ALTER TABLE oom ADD COLUMN planned_feed_in_manual boolean NOT NULL DEFAULT false;
  -- spúšťač: source_category = 'lokalny_zdroj' AND NOT planned_feed_in_manual
  --          → planned_feed_in_mwh = round(source_power_kw × 4 × 365 × 0,1 / 1000, 3)
  ```

  - Ručná zmena plánu vo formulári alebo importe nastaví `planned_feed_in_manual = true` a odvtedy sa plán sám nemení.
  - Tlačidlo „Vrátiť výpočet“ príznak zruší.
  - Príklad: 10 kW → 1,460 MWh.
- **Verejné osvetlenie** (Peter, odpoveď 4):

  ```sql
  ALTER TABLE oom ADD COLUMN public_lighting boolean NOT NULL DEFAULT false;
  ```

  - nastaví ho import zmlúv pri produkte DMP10 alebo Green 1T VO (časť 8.3);
  - ručne ho mení, kto smie upravovať OOM (pri Aktívnom iba s právom upravovať Aktívne);
  - prolongácia podľa neho navrhne Green 1T VO (časť 11.3).
- **Import OOM priamo z exportu XM Trade** (časť 8.4): nový formát v API a obrazovke 19 alebo 27; funkcia `oom_import_run` dostane nové polia.
- **Virtuálne EIC sharingu:**
  - `24GREENVV…` prejdú kontrolnou číslicou, kontrola EIC sa **nemení** (výnimka zo zadania časť 10 netreba);
  - formulár a import OOM dajú upozornenie pri podozrivom tvare EIC (rozhodnutie 6, časť 8.3), sharing s `24GREENVV` je v poriadku.
- **História cenovej regulácie** (dátum zmeny, odložený z modulu 3, časť 8.2):

  ```sql
  CREATE TABLE oom_price_regulation_change (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    oom_id uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
    valid_from date NOT NULL,
    value boolean,                 -- ANO / NIE / nevyplnené
    applied_at timestamptz,        -- kedy nočný beh urobil časový rez cien (časť 7.2)
    created_by uuid REFERENCES app_user (id), created_at,
    UNIQUE (oom_id, valid_from)
  );
  ```

  Zmena regulácie vo formulári OOM sa pýta „platí od“. Budúci dátum vykoná nočný beh, ako plánované zmeny OOM (0016).
- **Sadzby:** číselník sa nemení. X4-Dx a D3 Aktiv sú iba aliasy (rozhodnutie B).
- **Kontaktné osoby zo zmluvy:** až keď zostava OP stĺpce doplní (otázka 13).

### 11.3 Modul 3 – produkty a cenníky (`0023` + skript)

- **VIWA platba za účet** (O5 kolo 2):
  - oprava zadania `03-produkty.md` a popisov;
  - komentár pri `price_list_item.fee_program_eur_month` znie „VBattery mesačne; VIWA mesačne za účet“;
  - zmluva ho uloží ako riadok `viwa_ucet` bez OOM (časť 3);
  - text na obrazovkách 21 a 22 „za OOM“ → „za účet“.
- **VBattery V:**
  - nový produkt kategórie `vbattery`, stav Predáva sa, typ tarifu netýka sa;
  - položka v cenníku Virtuálna batéria 2026 s `fee_program_eur_month = 0` a bez GreenCar a GreenShare;
  - prijímatelia sú OOM typu sharing s EIC `24GREENVV…`;
  - **VBattery V platí od 1. 1. 2026 a je bezplatná** (Peter, otázka 15). Je v samostatnom cenníku „VBattery V (sharing)“, verzia 2026 od 1. 1. 2026, poplatok 0,00 €. Schválená verzia Virtuálnej batérie platí od 1. 4. 2026 a nedá sa meniť ani predbehnúť.
- **Produkty pre firmy podľa typu tarifu:**
  - z OP prichádzajú pri OOM produkty IN GREEN 1T / 2T / 2T VYK;
  - cenník „Podnikatelia nad 30 MWh“ má Green 1T Jednotarif, Green 2T Dvojtarif, Green 2T Vykurovanie, Green 1T VO;
  - **jedna sada produktov kategórie `dodavka_firma`** nahrádza „Dodávka B2B“ (Peter, odpoveď 2) a používajú ju individuálne zmluvy aj cenník nad 30 MWh. Povolené modely: cenník (nad 30 MWh), FIX, SPOT + aditív €. Typ tarifu produktu určuje výber ceny pri 1T + 2T (rozhodnutie 2).

  | Produkt (kód) | Typ tarifu | Variant | Modely | Alias z OP |
  | --- | --- | --- | --- | --- |
  | Green 1T Jednotarif (`green_1t`) | jednotarif | – | cenník, FIX, SPOT + € | IN GREEN 1T |
  | Green 2T Dvojtarif (`green_2t`) | dvojtarif | – | cenník, FIX, SPOT + € | IN GREEN 2T |
  | Green 2T Vykurovanie (`green_2t_vyk`) | dvojtarif | vykurovanie | cenník, FIX, SPOT + € | IN GREEN 2T VYK |
  | Green 1T VO (`green_1t_vo`) | jednotarif | verejné osvetlenie | cenník, FIX, SPOT + € | – (podľa `oom.public_lighting`) |

  ```sql
  ALTER TABLE product ADD COLUMN tariff_variant text CHECK (tariff_variant IN ('vykurovanie', 'verejne_osvetlenie'));
  ```

  - **Dodávka B2B** z modulu 3 prejde skriptom na stav Dobieha (nemaže sa, žiadna zmluva ho nepoužije). Produkty sa neviažu na sadzbu distribúcie (bez `product_tariff`) – rozhoduje typ tarifu a variant (zadanie časť 14).
- **Cenník „Podnikatelia nad 30 MWh“** (skript, nie migrácia), verzia 2026 od **1. 10. 2026**, segment firma, DPH 19 %:

  | Položka | VT/1T | NT | Mesačná platba |
  | --- | --- | --- | --- |
  | Green 1T Jednotarif | 164,0000 | – | 5,0000 € |
  | Green 2T Dvojtarif | 173,0000 | 150,0000 | 5,0000 € |
  | Green 2T Vykurovanie | 168,0000 | 164,0000 | 5,0000 € |
  | Green 1T VO | 162,0000 | – | 5,0000 € |

  - Schválenie s dátumom v minulosti smie iba skript (rozhodnutie 2026-10-13).
  - Ceny sa prepíšu z PDF `exports/cenniky-2026/GLG_Cennik_podnikatelia_nad_30MWh_od_1_10_2026.pdf`.
  - Skript na konci porovná ceny s DPH s PDF.
- **Výber produktu pri prolongácii (O11):**
  - OOM s príznakom verejné osvetlenie → Green 1T VO;
  - inak podľa typu tarifu a variantu predošlého produktu: 1T → Jednotarif, 2T → Dvojtarif, 2T vykurovanie → Vykurovanie;
  - bez predošlého produktu podľa plánovanej spotreby NT (> 0 → 2T);
  - návrh potvrdí Servis (príznak „Sprolongované bez novej ceny“).
- Pohľad `price_list_version_v` dostane stĺpec „zmluvy, ktoré prejdú“ (modul 3, časť 4).

### 11.4 Modul 1

Prepínač `customer_status_auto` sa po F4 zapne aj na Ostrom (zadanie časť 14). Pravidlo zmluvy v `customer_status_calc` podľa časti 1.1.

---

## 12. Práva, RLS a audit

**RLS na `contract`** a všetkom, čo z nej visí (`contract_oom`, `contract_price`, `contract_flag`, `contract_year_basis`, `contract_import_change`):
- **„Všetko“:** spoločnosti používateľa (`crm_user_orgs()`); platí aj pre používateľa so „schvaľuje ceny“ bez ohľadu na tím (`crm_sees_all_contracts()`, `0023`).
- **„Iba svoje“:** zákazník zmluvy patrí prihlásenému (vlastník firmy alebo osoby, ako pri OOM), **alebo** prihlásený zmluvu uzatvoril (`owner_id`). Pozri otázku 3b.
- **Externý obchodník:** iba svoje, aj v databáze (zadanie časť 12).
- **Ochrana stĺpcov:**
  - stĺpce z Office portálu mení iba funkcia importu a nočný beh (`SECURITY DEFINER`); spúšťač odmietne zmenu z aplikácie;
  - `crm_app` má na `contract` UPDATE iba na stĺpce CRM (`previous_contract_id`, `related_contract_id`, `close_reason`, `note`, `custom`);
  - `contract_price` a `contract_oom` z aplikácie nemení nič.
- **Marža firmy:** pohľad `contract_year_margin_v` (security_invoker + podmienka `crm_can_see_margin()`). Parametre rizikovej prirážky, našej marže a odhad portfólia (`price_parameter`, `market_price_daily`) čítajú iba admin, „schvaľuje ceny“ a tímy s „vidieť maržu firmy“. Cenu pre obchodníka vidí každý cez funkciu, ktorá vráti iba výsledok.
- **`price_exception`:** zakladá obchodník (iba svoji zákazníci), číta autor, admin a `crm_sees_all_contracts()` (tímy so „všetko“ v module Zmluvy a „schvaľuje ceny“); rozhodnutie iba `crm_approves_prices()`.
- **`crm_external_ready()`** sa po F2 rozšíri o kontrolu RLS na `contract` (podmienka odomknutia externého tímu: OOM, Obchod, Zmluvy). RLS na `audit_log` ostáva otvorená podmienka (STAV).
- **`crm_app`:** práva na nové tabuľky v `api/db/app-role.sql`; DELETE iba `import_alias` (nie systémové), `notification` (vlastné).
- **`crm_cockpit`:** iba SELECT na `cockpit_*_v` (časť 10).

**Audit:** `contract`, `contract_oom`, `contract_price`, `contract_flag`, `price_exception`, `price_parameter`, `import_alias`, `oom_price_regulation_change`, nové stĺpce `app_user` a `team_permission`.
- Import zapisuje so zdrojom `import`, nočný beh so zdrojom `system`.
- Bez auditu (technické): `market_price_daily`, `contract_import_change`, `notification`.
- V audite nie sú osobné údaje navyše oproti záznamu.

**Export zoznamu zmlúv** (obrazovka 25): právo „exportovať“ a `export_log`; marža firmy iba s právom. Čísla OOM a EIC ako text.

---

## 13. Fázy

Ku každej fáze testovací scenár pre Petra a kontroly v `db/test/checks_zmluvy.sql`. Nasadenie na Test robí Peter, commit až po vyskúšaní.

| Fáza | Obsah | Migrácia | Obrazovky |
| --- | --- | --- | --- |
| **F1** Nastavenia a príprava | typ predajcu a „schvaľuje ceny“, „vidieť maržu firmy“, cenové parametre s históriou, trhové ceny (ručne, kým nie je API Cockpitu), cena pre obchodníka dnes, preklady importov; modul 2: plán výkupu LZ, história regulácie; modul 3: produkty Green 1T/2T/VYK/VO, VBattery V, cenník nad 30 MWh (skript), VIWA za účet | `0023` + skript | 12, 13, 29, nová Preklady importov, úpravy 18, 21, 22 |
| **F2** Zmluvy a import | zmluva, OOM v zmluve, ceny; import Office portálu a XM Trade s náhľadom; zoznam a karta zmluvy bez bilancie; RLS | `0025`, `0026` | 25, 26, 27 |
| **F3** Bilancia a výnimky | snímka nákladu, ročná bilancia (pridaná hodnota, marža firmy), výnimky a schvaľovanie, príznaky Pod hranicou a Chýba cena, sekcia Zmluvy na karte zákazníka | `0027` | 25, 26 (bilancia), 28, karta zákazníka |
| **F4** Nočný beh | upozornenia (`notification`), prolongácia, prechod cenníka, časový rez regulácie; zapnutie `customer_status_auto` | `0028` | zvonček, prehľady príznakov |
| **F5** Cockpit | rola `crm_cockpit`, pohľady a endpointy, service token; porovnanie v Cockpite (mimo repozitára) | `0029` | – |

---

## 14. Testy (výber, `db/test/checks_zmluvy.sql`)

- **Stav zmluvy:** podpísaná s budúcou účinnosťou = Podpísaná; po účinnosti Účinná; po `valid_to` Skončená; prolongácia posunie koniec.
- **Prekrytie a nástupníctvo** (doplnok a, časť 2.1). Každý scenár s dátumami a kontrolou `valid_to`, `successor_id`, `previous_contract_id`, cien a príznakov:
  - **Retencia:**
    - stará zmluva firmy 1. 1. – 31. 12. 2026 s autoprolongáciou;
    - nová zmluva toho istého zákazníka od 1. 1. 2027, podpísaná v novembri 2026;
    - prolongácia nenastane a nová má predošlú zmluvu.
  - **Retencia počas prolongácie:**
    - stará je sprolongovaná do 31. 12. 2027 s cenou nad 30 MWh;
    - nová od 1. 4. 2027;
    - stará skončí 31. 3. 2027, ceny prolongácie od 1. 4. sa zmažú, príznak „Sprolongované bez novej ceny“ sa uzavrie.
  - **Autoprolongácia bez nástupcu:** v deň po konci +12 mesiacov, cena z cenníka nad 30 MWh podľa typu tarifu a verejného osvetlenia, príznak.
  - **Autoprolongácia s čiastočným nástupcom:** zmluva s 3 OOM, nová zmluva na 1 OOM; skráti sa iba to OOM a `prolonged_to` = koniec zvyšných.
  - **Prepis počas prolongácie:**
    - nový zákazník na tom istom OOM od 1. 6. 2027;
    - stará zmluva na OOM skončí 31. 5. 2027 a nová má predošlú zmluvu (iný zákazník).
  - **Skutočné prekrytie:** nová zmluva od 1. 6. 2026 pri účinnosti starej z OP do 31. 12. 2026 je chyba riadku a nič sa neuloží; databáza odmietne aj priamy zápis.
  - **Iná skupina:** dodávka + výkup na tom istom OOM v rovnakom čase prejde.
  - **Zrušenie nástupcu:** nová zmluva prejde na Odmietnutá → stará dostane „Na kontrolu“, skrátenie sa nevráti samo.
- **Ceny:**
  - cenníková cena s nezhodnou kópiou sa neuloží;
  - dve ceny komodity v jednom období sa neuložia;
  - kombinácia modelu a stĺpcov podľa CHECK.
- **Import:**
  - kWh → MWh;
  - 1900-01-01 = prázdne;
  - výber 1T/2T podľa produktu OOM, neurčiteľné = chyba;
  - VBattery z XM → DDx, Dx, regulácia;
  - neznámy alias = chyba;
  - test riadok preskočený;
  - inkrementálne „Bez zmeny“;
  - dátum narodenia sa do databázy nedostane;
  - chýbajúci zákazník sa založí s príznakom „založený importom“, druhý import ho nájde podľa `Osoba_ID` / IČO;
  - DMP10 nastaví verejné osvetlenie.
- **Lokálne overenie importu na vzorových exportoch** (doplnok b, pri F2):
  - beh na dočasnom lokálnom Postgrese v scratchpade (ako pri `0019`–`0022`), **na `dev` sa nič nenahráva**;
  - schéma ako `dev` a vymyslené zákazníci, OOM a cenníky, ktoré vzorka potrebuje;
  - výstup pre Petra: počty nová / zmena / bez zmeny / upozornenie / chyba / preskočené a príklady chýb a upozornení **bez osobných údajov** (číslo zmluvy skrátené, EIC iba predpona, bez mien);
  - dočasná databáza sa po behu zmaže.
- **Bilancia:**
  - všetky príklady zo zadania časť 13 na halier;
  - neúplný rok (1. 9. 2026 – 31. 12. 2027: 2026 = 4/12);
  - zmluva na 6 mesiacov (množstvo za celé obdobie, nedelí sa).
- **Výnimka:**
  - autor ju neschváli;
  - po 30 dňoch Expirovaná;
  - párovanie zákazník + rok;
  - zmluva pod hranicou bez výnimky dostane príznak a upozornenie.
- **Práva:**
  - **používateľ v Sales_internal s príznakom „schvaľuje ceny“ vidí cudzie zmluvy, výnimky a maržu firmy; bez príznaku nie** (Peter, doplnok k `0023`; funkcie overuje už Z0-2 v `0023`, RLS zmlúv test v `0025`);
  - obchodník nevidí maržu firmy, rizikovú prirážku ani odhad portfólia;
  - „iba svoje“;
  - externý nevidí cudziu zmluvu;
  - stĺpce z OP z aplikácie nezmení.
- **Nočný beh:** upozornenie 4 mesiace pred koncom raz; prolongácia s cenníkom nad 30 MWh a návrhom produktu; prechod cenníka; rez regulácie.
- **Cockpit:** `crm_cockpit` číta iba `cockpit_*_v`; pri domácnosti nie je meno ani adresa.

---


## 15. Rozhodnuté (Peter, 13. 10. 2026)

**Ku kroku 2:**
1. Zmluvné množstvo = hodnoty pri OOM prevedené podľa `MJ` na MWh; súčet za zmluvu iba informatívny, nesúlad = upozornenie.
2. Viac cien v jednom roku (1T aj 2T): cena podľa typu tarifu produktu pri OOM (IN GREEN 1T / 2T); neurčiteľné = chyba riadku.
3. Účinnosť domácností z XM Trade (Dátum začiatku dodávky); množstvo pri výkupe a VIWA z plánu výkupu OOM; cenové obdobia zo `ZZC_datum_od/_do`; 1900-01-01 = prázdne.
4. VBattery: z produktu XM Trade „VBATTERY - DDx - ANO/NIE Energopomoc“ produkt DDx, sadzba Dx a cenová regulácia.
5. Prekladová tabuľka aliasov pre importy v Nastaveniach, spravuje admin, audit, neznámy názov = chyba s „pridať alias“.
   - **A:** `GREEN_2T_VYK_INDIVIDUAL` = individuálna FIX cena pre dvojtarif s vykurovaním.
   - **B:** X4-D1 až X4-D5 = D1 až D5 (atď.); „D3 Aktiv“ (bývalá D3 aj bývalá D5) = D3.
6. EIC s podozrivým tvarom: upozornenie, nie chyba.
7. Obrazovka 29: cenové parametre mení admin a obchodný riaditeľ; poznámka v menu Nastavení sa pri tejto stránke prepíše.
8. Nový zdroj pre Cockpit nahradí `greenlogy-hubspot-sync` – API s rovnakými údajmi (dealy, aktívne OOM), potom porovnanie starého a nového zdroja.
9. Neimportovať dátum narodenia ani rodné číslo.

**K časti 16 návrhu v0.1:**
1. Neúplný rok viacročnej zmluvy = pomerné množstvo podľa mesiacov; zmluva kratšia ako 12 mesiacov = množstvo za celé obdobie, nedelí sa (časť 6.2).
2. „Dodávka B2B“ nahradí sada Green 1T / 2T / 2T Vykurovanie / 1T VO; modely cenník (nad 30 MWh), FIX, SPOT + aditív €; typ tarifu určuje výber ceny pri 1T + 2T (časť 11.3).
3. Chýbajúceho zákazníka import založí s príznakom „založený importom“; pri zákazníkovi sa ukladá `Osoba_ID`, domácnosti sa párujú podľa neho, firmy podľa IČO (časť 8.2).
4. Príznak verejného osvetlenia na OOM; import ho nastaví pri produkte DMP10 alebo 1T VO (časti 8.3, 11.2).
5. Trhové ceny ručne, kým nebude API Cockpitu; história BL/PL od 1. 1. 2026 jednorazovo, zdroj (Sales portál / Cockpit) doplní Peter (časť 4.2).
6. „X2 /VN/“ = X2 cez aliasy (časť 9).

**Doplnky:**
- **a)** Prekrytie zmlúv na OOM sa obmedzuje v databáze nad skutočnou dobou platnosti (účinnosť + prolongácia). Nová zmluva na OOM skráti prolongáciu predošlej na deň pred svojím začiatkom a dostane väzbu „predošlá zmluva“. Chybou je iba skutočné prekrytie účinností z Office portálu. Testy pre retenciu, autoprolongáciu a prepis (časti 2.1, 14).
- **b)** Import sa overí lokálne na vzorových exportoch (počty, príklady chýb bez osobných údajov); na `dev` sa s nimi nič nenahráva (časť 14).

---

## 16. Otázky – zodpovedané (Peter, 13. 10. 2026, kolo 3)

Všetky otázky z v0.1–v0.7 sú zodpovedané (`04-zmluvy-otazky.md`, kolo 3):

| # | Rozhodnutie | Kde v návrhu |
| --- | --- | --- |
| 3b | „Iba svoje“ = vlastník zákazníka **aj** obchodník, ktorý zmluvu uzavrel (`owner_id`) | 12, 23 |
| 4 | Dva cenové riadky toho istého produktu a obdobia s rôznou cenou = chyba riadku | 8.3 |
| 8 | Upozornenia zatiaľ iba v CRM (zvonček, zoznam); e-mail neskôr | 11.1 |
| 10 | API pre Cockpit: pri domácnostiach iba ID zmluvy a zákazníka (bez mena, adresy) | 10.1 |
| 11 | a) `new_hruba_marza` podľa HubSpotu + natívne pridaná hodnota a marža firmy; b) EFET a GreenSolar ďalej z HubSpotu | 10.2 |
| 12 | a) Pri VBattery rozhoduje produkt XM Trade, nesúlad = upozornenie v náhľade; b) VBattery AKU 1,00 € mesačne bez DPH od 1. 1. 2026 (samostatný cenník „VBattery AKU (dobieha)“, skript) | 8.3, 22 |
| 13 | Balík VIWA, dôvod uzatvorenia a kontaktné osoby Office portal doplní; import začne bez nich | 1, 2 |
| 14 | Z XM Trade ponechať **triedu TDO** (nové pole OOM, aj pre Cockpit, v `0026`); ostatné polia (pásmo TSS/TPS, typ zmluvy distribúcie, stav zmluvy v XM) ignorovať | 8.4 |
| 15 | VBattery V od 1. 1. 2026 bezplatne (samostatný cenník) | 11.3, 22 |
| 16–18 | Neurčito v rámci druhu; krátka zmluva podľa mesiacov; „platí od“ iba dnes a neskôr | 2.1, 6.2, 4.1 |
| 19 | Zmena regulácie importom OOM = zmena s „platí od“ dnes (úprava importu v `0026`) | 21 |

## 17. Čo bude treba od teba (iba zoznam, nič nemením)

**Neon** (každé zvlášť, po overení nanečisto):
1. Čítanie na `dev` pred `0023` (časť 18.1).
2. `0023` na `dev` → `app-role.sql` → nasadenie F1; potom skript (produkty Green, Dodávka B2B Dobieha, VBattery V, cenník nad 30 MWh, aliasy produktov).
3. `0025` + `0026` na `dev` (overí prázdne `contract*`) → F2.
4. `0027`, `0028`, `0029` postupne s F3–F5.

`main` až po schválení na Teste a overení na skúšobnej vetve (rozhodnutie 2026-10-13).

**Cloudflare:**
- service token Access pre Cockpit;
- druhá konfigurácia Hyperdrive pre rolu `crm_cockpit` (F5).

**Office portal:** doplniť do zostavy „Web Zmluvy – prehľad EE“ balík VIWA, dôvod uzatvorenia a kontaktné osoby (O5, O6, otázka 13).

**Cockpit** (samostatné repozitáre):
- stiahnuť nasadený `greenlogy-hubspot-sync` do gitu;
- API denných cien;
- zdroj CRM a porovnanie (časť 10.5).

**Dáta:** zdroj histórie BL/PL od 1. 1. 2026 (Sales portál alebo Cockpit) a formát (súbor alebo prístup).

**Odpovede:** všetky zodpovedané (časť 16).

---

## 18. Plán migrácie `0023_zmluvy_priprava` (fáza F1)

Rovnaký postup ako pri `0019`–`0022`:
1. Migrácia sa napíše a **overí nanečisto na dočasnom lokálnom Postgrese** (hore, testy, dole, hore, porovnanie schémy).
2. Kód F1 sa pripraví lokálne.
3. Na `dev` ju spustí až Peter: migrácia → `api/db/app-role.sql` → nasadenie.

`main` nie.

### 18.1 Čítanie na `dev` pred migráciou (iba čítanie, so súhlasom)

Skript `db/test-data/0023-pred-migraciou.sql` cez `db/citanie.sh dev`:
- bunky `team_permission` modulu Zmluvy (tím, vidieť, upravovať, import) – ktoré sa ešte rovnajú východiskovým z `0006`;
- OOM s kategóriou lokálny zdroj: počet, koľko má plán výkupu prázdny, rovný vzorcu a iný (bez EIC a mien);
- kódy produktov `green_1t`, `green_2t`, `green_2t_vyk`, `green_1t_vo`, `vbattery_v` – nesmú existovať (pre skript);
- používatelia s príznakom admin a tím (kvôli „schvaľuje ceny“ – nastaví ho Peter v Nastaveniach, migrácia nie).

**Výsledok na `dev` (13. 10., Peter súhlasil s čítaním):**
- Matica modulu Zmluvy: **všetkých 6 buniek má východiskovú hodnotu z `0006`**; jediný záznam v audite pri každej je zápis samotnej migrácie `0006` (12. 10.). Upravená bunka, ktorá by ostala bez zmeny, nie je žiadna.
- Lokálne zdroje: 1 OOM (testovacie), plán výkupu iný ako vzorec → `0023` mu nastaví `planned_feed_in_manual = true`, hodnotu nezmení.
- Nové kódy produktov neexistujú; `dodavka_b2b` existuje (Predáva sa), v žiadnej položke cenníka nie je.
- Zmluvy, ceny, nákupné ceny: 0; posledná migrácia `0022`.

### 18.2 Obsah (`-- migrate:up`)

| # | Objekt | Podrobnosti |
| --- | --- | --- |
| 1 | `seller_type` (enum), `app_user.seller_type`, `app_user.approves_prices` | spúšťač: externý tím nesmie mať „schvaľuje ceny“ (rozšírenie poistky z `0006`); zmena iba admin (stĺpce mimo práv `crm_app` pre ne-adminov – kontrola v existujúcom spúšťači úpravy používateľa) |
| 2 | `crm_approves_prices()`, `crm_can_see_margin()`, `crm_sees_all_contracts()` | `STABLE SECURITY DEFINER`, ako `crm_can_import`; marža = tím alebo „schvaľuje ceny“; všetky zmluvy = tím „všetko“ alebo „schvaľuje ceny“ (doplnok) |
| 3 | `team_permission.can_see_company_margin` | `CHECK (NOT can_see_company_margin OR module = 'zmluvy')`; externý tím nikdy (rozšírenie spúšťača poistky); východiskovo CEO, Nákup, Marketing |
| 4 | východiskové práva modulu Zmluvy | podľa tabuľky v časti 11.1; **iba bunky s východiskovou hodnotou z `0006`**, ostatné sa vypíšu ako `NOTICE` |
| 5 | `price_parameter` | tabuľka (časť 4.1); `price_param(org, code, dátum, rok)`; zápis priamo do tabuľky – RLS (admin, „schvaľuje ceny“) a spúšťač `price_parameter_guard`: `min_aditiv_vykup_lz` a `nakup_energopomoc` iba admin, „platí od“ iba dnes a neskôr (minulosť iba vlastník databázy), riadok sa nemení ani nemaže okrem budúceho riadku jeho autorom, `changed_by` doplní databáza; východiskové hodnoty zo zadania (bez autora) |
| 6 | `market_price_daily` (+ `org_id`) | tabuľka (časť 4.2); zápis priamo – RLS (admin, „schvaľuje ceny“) a spúšťač `market_price_guard` (iba dnes a neskôr, zdroj „ručne“, nemaže sa; história iba vlastník); `trader_price(org, rok, dátum)` – `SECURITY DEFINER`, vráti iba výslednú cenu (každý prihlásený); pohľad `trader_price_today_v` pre obrazovku 29 (zložky iba admin a marža firmy) |
| 7 | `import_alias` | tabuľka (časť 9); `import_name_norm(text)` (`IMMUTABLE`: malé písmená, bez diakritiky, viac medzier → jedna, orezanie, rok → `RRRR`); `import_alias_resolve(...)`; spúšťač overenia cieľa pre druhy `produkt_op`, `produkt_oom`, `sadzba`, `pds`, `obchodnik`, číselníky; druh `faza` sa pridá až v `0025` spolu s enumom `contract_phase` |
| 8 | systémové aliasy | `produkt_op` (8 vzorov), `sadzba` (X4-D1…X4-D8 → d1…d8, D3 Aktiv ×2 → d3, X2 /VN/ → x2), `pds` (názvy a „Sústava“ z XM pre ZSD, SSD, VSD); aliasy produktov OOM pridá skript, keď budú produkty |
| 9 | `oom.planned_feed_in_manual` | spúšťač na `oom` pri lokálnom zdroji (časť 11.2); doplnenie: prázdny plán alebo plán rovný vzorcu → výpočet, iný → `manual = true` (bez zmeny hodnoty); funkcia importu `0018` sa nemení (spúšťač rozpozná ručnú hodnotu) |
| 10 | `oom.public_lighting` | `boolean NOT NULL DEFAULT false`; úprava podľa práv OOM (Aktívne iba s `can_edit_active_oom`) |
| 11 | `oom_price_regulation_change` | tabuľka (časť 11.2); funkcia `oom_price_regulation_set(oom, hodnota, platí_od)`: v `0023` iba dnes alebo minulý dátum (zapíše hneď do `oom.price_regulation`); budúci dátum a rez cien pribudnú v `0028`; RLS podľa prístupu k OOM |
| 12 | `product.tariff_variant` | `CHECK (tariff_variant IN ('vykurovanie','verejne_osvetlenie'))`; použitý produkt variant nemení (doplnenie ochrany z `0022`) |
| 13 | popisy VIWA | `COMMENT ON COLUMN price_list_item.fee_program_eur_month` = „VBattery mesačne; VIWA mesačne za účet“ |
| 14 | RLS a audit | RLS na `price_parameter`, `market_price_daily` (čítanie: admin, „schvaľuje ceny“, `crm_can_see_margin()`), `import_alias` (čítanie: každý prihlásený, zápis: admin), `oom_price_regulation_change`; audit na `price_parameter`, `import_alias`, `oom_price_regulation_change`, nových stĺpcoch `app_user`, `team_permission`, `oom`, `product` (existujúce spúšťače); `market_price_daily` bez auditu (zapisuje sa `changed_by`) |

`-- migrate:down`: všetko v opačnom poradí; vrátenie práv modulu Zmluvy iba v bunkách, ktoré `0023` zmenila (zapamätá si ich v dočasnej tabuľke migrácie – alebo down vráti východiskové hodnoty `0006`; spresní sa pri písaní).

### 18.3 `api/db/app-role.sql`

- `crm_app` (zmena oproti plánu, Claude pri implementácii: bez osobitných funkcií na zápis – pravidlá strážia RLS a spúšťače v databáze pre každú rolu, rovnako ako pri cenníkoch):
  - SELECT, INSERT, UPDATE na nové tabuľky (základ `app-role.sql`);
  - DELETE na `price_parameter` (budúci riadok autorom) a `import_alias` (nesystémový) – nový riadok v `app-role.sql`;
  - `market_price_daily` a `oom_price_regulation_change` sa nemažú;
  - cenová regulácia s dátumom cez funkciu `oom_price_regulation_set` (práva volajúceho, RLS OOM).
- `app_user`: stĺpce `seller_type`, `approves_prices` iba cez existujúcu adminskú úpravu používateľa.

### 18.4 Testy `db/test/checks_zmluvy_priprava.sql` (Z0)

- **Typ predajcu a „schvaľuje ceny“:**
  - mení iba admin;
  - externý tím ich nedostane;
  - `crm_can_see_margin()`: CEO, Nákup, Marketing áno, Servis a Sales nie, používateľ so „schvaľuje ceny“ v Sales áno.
- **Matica:** po migrácii zodpovedá časti 11.1 v testovacej transakcii; zmenená bunka sa neprepíše.
- **Cenové parametre:**
  - `price_param` k dátumu (história);
  - obchodník nečíta tabuľku, ale `trader_price` mu vráti výsledok;
  - príklad zo zadania BL 95, PL 110 → 106,00 €/MWh;
  - riadok sa nedá zmeniť ani zmazať;
  - `min_aditiv_vykup_lz` nezmení „schvaľuje ceny“ bez admina.
- **Trhové ceny:** ručné zadanie; chýbajúci deň → posledná hodnota do 7 dní, potom NULL.
- **Aliasy:**
  - normalizácia („VBattery  - V“ = „vbattery - v“, „TDO 4 “, diakritika, rok → RRRR);
  - X4-D2 → d2 pri OOM v ZSD, D3 Aktiv /bývalá D5/ → d3, X2 /VN/ → x2;
  - cieľ, ktorý neexistuje, sa neuloží;
  - systémový alias sa nedá zmazať;
  - ne-admin nezapíše.
- **Plán výkupu LZ:**
  - 10 kW → 1,460 MWh;
  - zmena výkonu prepočíta;
  - ručná hodnota nastaví `manual` a ďalšia zmena výkonu ju nezmení;
  - reset vráti výpočet;
  - import (`oom_import_run`) s ručnou hodnotou sa správa rovnako.
- **Verejné osvetlenie:** Aktívne OOM bez práva nezmení.
- **Cenová regulácia s dátumom:** dnes/minulý dátum zapíše históriu aj OOM; budúci dátum v `0023` odmietne.
- **Produkt:** `tariff_variant` použitého produktu sa nezmení.

Spolu so starými testami `run.sh` (dnes 126 kontrol); testy si potrebné práva nastavia v transakcii a prejdú aj s inými dátami (rozhodnutie 2026-10-13).

### 18.5 Kód F1 (po migrácii, rovnaký krok nasadenia)

**API a web:**
- Používatelia (obrazovka 12): typ predajcu, „schvaľuje ceny“.
- Tímy a práva (13): stĺpec „Vidieť maržu firmy“ pri module Zmluvy.
- Cenové parametre (29):
  - história, zmena parametra, zadanie cien dňa, cena pre obchodníka dnes;
  - viditeľné pre admina a „schvaľuje ceny“, s textom „Mení admin a obchodný riaditeľ“ (rozhodnutie 7).
- Nastavenia → Preklady importov: zoznam podľa druhu, pridanie, skrytie, audit.
- OOM (18):
  - verejné osvetlenie;
  - plán výkupu LZ (vypočítaný / ručný, „Vrátiť výpočet“);
  - zmena cenovej regulácie s „platí od“;
  - import a export OOM s novými stĺpcami.
- Produkty (22): variant tarifu; texty VIWA „za účet“ (21, 22, 23).

**Skript cenníkov** (samostatný súhlas):
- produkty Green 1T / 2T / 2T Vykurovanie / 1T VO a VBattery V;
- Dodávka B2B → Dobieha;
- cenník „Podnikatelia nad 30 MWh“ 2026 od 1. 10. 2026 s kontrolou cien s DPH proti PDF;
- verzia VB s položkou V (otázka 15);
- aliasy produktov OOM (IN GREEN, DD, DMP, VBattery).

**Testovací scenár pre Petra na Teste:**
- nastaviť typ predajcu a schvaľovateľa;
- zmeniť parameter s budúcim dátumom a overiť históriu;
- zadať ceny dňa a skontrolovať cenu pre obchodníka (príklad 106,00);
- pridať alias;
- OOM lokálny zdroj 10 kW → 1,46 MWh, prepísať, vrátiť;
- verejné osvetlenie;
- regulácia s dátumom;
- obchodník nevidí Cenové parametre ani rizikovú prirážku.

### 18.6 Overenie nanečisto (13. 10. 2026)

Dočasný lokálny Postgres 18 (scratchpad, vlastník bez superuser práv ako na Neone), migrácie `0001`–`0022` z repozitára, rola `crm_app` s `app-role.sql`. **Na Neone sa nič nespúšťalo.**

| Krok | Výsledok |
| --- | --- |
| Testy na `0022` (východisko) | 126 kontrol OK |
| `0023` hore | OK. Prvý pokus zlyhal na syntaxi (`CASE` v podmienke `IF`), opravené. dbmate pritom vypísal „Applied“, hoci sa migrácia vrátila – známy bod v STAV; stav treba vždy overiť cez `schema_migrations` |
| Matica Zmluvy po `0023` | podľa časti 11.1 (CEO, Nákup: všetko/všetko/import/marža; Marketing: všetko/nič/marža; Servis: všetko/všetko/import; Sales_internal a Sales_external: iba svoje/iba svoje) |
| Parametre, preklady | 10 východiskových parametrov; 36 systémových prekladov (8 produktov OP, 11 sadzieb, 5 PDS, 12 číselníkov XM) |
| Testy na `0023` | **135 kontrol OK** (126 + Z0-1 až Z0-8) |
| `0023` dole | schéma = schéma po `0022` (0 riadkov rozdielu; prvý beh našiel nevrátený komentár stĺpca – opravené), testy 126 OK |
| Lokálne zdroje existujúce pred migráciou | plán iný ako vzorec → ručný, hodnota ostala (2,5 MWh); prázdny → vypočítaný (20 kW → 2,920); rovný vzorcu → nie ručný |
| `0023` znova hore | rovnaká schéma ako pri prvom behu; testy 135 OK |

---

## 19. Migrácia `0024_zmluvy_f1_opravy` (Petrove úpravy k plánu F1, 13. 10. 2026)

**1. Oprava ceny dňa** (obrazovka 29, tlačidlo „Opraviť“):
- `market_price_daily` dostane `id` (primárny kľúč), `corrected_at`, `corrected_by`; unikátny je iba **platný** záznam pre spoločnosť, deň a rok (`corrected_at IS NULL`);
- nový záznam pre ten istý deň a rok je oprava: databáza starému nastaví „opravené“, kto a kedy (spúšťač, aj pri skripte histórie);
- záznam sa nemení ani nemaže (ani autorom) – oprava je vždy nový záznam; audit má zápis aj označenie opravy;
- `trader_price` a `trader_price_today_v` berú iba platný záznam; pohľad `market_price_history_v` ukáže všetky vrátane opravených (mená).

**2. Zmena cenovej regulácie OOM s dátumom v minulosti, dnes aj v budúcnosti:**
- na OOM platí hodnota **najneskoršej zmeny s „platí od“ do dneška** (staršia zmena zadaná neskôr neprebije novšiu);
- budúca zmena čaká ako „naplánovaná“ (`applied_at` prázdne) a uplatní ju nočný beh `oom_daily_run` v deň platnosti (výsledok `regulacia`);
- naplánovanú zmenu smie zrušiť, kto smie OOM upraviť (`oom_price_regulation_cancel`), uplatnenú nie;
- rez cien zmlúv pri zmene regulácie pribudne s nočným behom zmlúv (`0028`).

**3.** Pri cudzej naplánovanej zmene cenového parametra hláška „Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor“ (v `0023` bola zavádzajúca „Platný parameter sa nemení“).

**Overenie nanečisto:** testy 135 OK (Z0-4 a Z0-7 rozšírené: oprava ceny mení cenu pre obchodníka v ten deň, história ostane; budúca regulácia, nočný beh, zrušenie, staršia neprebije novšiu); `down` = schéma po `0023` (126 OK), znova `up` = rovnaká schéma.

## 20. Kód F1a (Nastavenia) – lokálne overený

- **API:**
  - `/api/me`: typ predajcu, „schvaľuje ceny“, „vidí maržu firmy“, právo `margin`;
  - `routes/settings.ts`: používateľ (typ predajcu, „schvaľuje ceny“), matica (`margin` pri Zmluvách);
  - `routes/pricing.ts` (`/api/pricing`, parametre, ceny dňa, oprava) – admin alebo „schvaľuje ceny“;
  - `routes/settings-aliases.ts` (`/api/settings/import-aliases`) – iba admin;
  - `errors.ts`: hlášky nových obmedzení.
- **Web:**
  - Používatelia (typ predajcu, „schvaľuje ceny“);
  - Tímy a práva (Importovať pri Zmluvách, stĺpec Marža firmy);
  - nové stránky Cenové parametre (29) a Preklady importov;
  - menu Nastavení: obchodný riaditeľ bez admina vidí iba Cenové parametre s textom „Mení admin a obchodný riaditeľ“.
- **Overenie:**
  - lokálne API proti dočasnej databáze (nie `dev`), traja vymyslení používatelia (admin, obchodný riaditeľ v Sales_internal, obchodník): práva, parametre, ceny dňa s opravou, preklady, používatelia a matica podľa pravidiel;
  - typová kontrola API aj webu a build webu bez chyby;
  - obrazovky vizuálne overí Peter na Teste.

## 21. Kód F1b (OOM a produkty) – lokálne overený

- **API:**
  - karta OOM (`queries/oom.ts`): verejné osvetlenie, plán výkupu vypočítaný alebo ručný, história a naplánované zmeny cenovej regulácie;
  - `routes/oom-write.ts`: polia `public_lighting` a `planned_feed_in_manual` (false = „Vrátiť výpočet“);
  - **cenová regulácia existujúceho OOM sa mení iba s dátumom:** `POST /api/oom/:id/price-regulation`, zrušenie naplánovanej `DELETE /api/oom-regulation/:id`; úprava cez bežný formulár ju odmietne s vysvetlením (pri založení OOM ostáva bežné pole);
  - export OOM: stĺpce „Verejné osvetlenie“ a „Plán výkupu zadaný ručne“ (iba na čítanie);
  - produkty: `tariff_variant` v zápise aj zozname.
- **Web:**
  - karta OOM: „Zmeniť reguláciu“ (panel s dátumom, históriou a zrušením naplánovanej), pri regulácii štítok „naplánované od …“, riadok Verejné osvetlenie, pri lokálnom zdroji „vypočítané z výkonu / zadané ručne“ a „Vrátiť výpočet“;
  - formulár OOM: verejné osvetlenie; regulácia iba pri založení (pri úprave odkaz na kartu); nápoveda plánu výkupu lokálneho zdroja;
  - produkty: variant tarifu (vykurovanie pri dvojtarife, verejné osvetlenie pri jednotarife), v zozname za typom tarifu;
  - texty VIWA „za účet“: obrazovky 21–23 a príklad (1 účet, 2 OOM 50 + 30 kW → 22,90 € mesačne); opravené aj zadanie a návrh modulu 3.
- **Import OOM zo šablóny verejné osvetlenie nemení:** databázová funkcia importu (`0018`) má pevný zoznam stĺpcov a verejné osvetlenie podľa odpovede 4 nastaví import zmlúv (F2). Import zo šablóny ďalej mení cenovú reguláciu priamo, bez dátumu a histórie – otázka 19.
- **Overenie:**
  - dočasná databáza `0001`–`0024`, testy 135 OK;
  - API ako admin a ako Marketing (iba vidí OOM): verejné osvetlenie, regulácia dnes / naplánovaná / zrušená, Marketing nezmení (404), ručný plán, zmena výkonu nezmení ručný plán, „Vrátiť výpočet“ (20 kW → 2,920 MWh), produkt VO, VO pri dvojtarife odmietnuté, export so stĺpcami;
  - typová kontrola a build bez chyby; obrazovky vizuálne overí Peter na Teste.

## 22. Skript `db/seed/podnikatelia-2026.sh` (dáta, nie migrácia) – lokálne overený

Spúšťa Peter (`dev --skuska`, potom `dev`), predpoklad `0023`, `0024` a `cenniky-2026.sh`. Beží ako vlastník databázy v jednej transakcii.
- **Produkty:**
  - Green 1T Jednotarif, Green 2T Dvojtarif, Green 2T Vykurovanie (variant vykurovanie), Green 1T VO (variant verejné osvetlenie): dodávka firmy, DPH 19 %, modely cenník, FIX, SPOT + aditív €;
  - VBattery V (sharing, DPH 23 %);
  - Dodávka B2B → Dobieha.
- **Cenník „Podnikatelia nad 30 MWh“**, verzia 2026 od 1. 10. 2026, schválená: Green 1T 164,00; Green 2T 173,00 / 150,00; Green 2T Vykurovanie 168,00 / 164,00; Green 1T VO 162,00 €/MWh; mesačná platba za OM 5,00 € v každej položke. Ceny s DPH sa na konci porovnajú s PDF (195,16; 205,87 / 178,50; 199,92 / 195,16; 192,78; 5,95).
- **32 systémových prekladov produktov pri OOM:**
  - IN GREEN 1T / 2T / 2T VYK;
  - DD1–DD8 (cieľ NIE, `target_extra.ano` = produkt ANO, import vyberie podľa regulácie OOM);
  - DMP1–DMP11 (DMP10 s príznakom verejné osvetlenie);
  - VBattery STANDARD / PREMIUM / MAX / AKU / V z Office portálu aj XM Trade.
- **Cenník „VBattery V (sharing)“**, verzia 2026 od 1. 1. 2026, schválená: VBattery V za 0,00 € mesačne (Peter, otázka 15).
- **Cenník „VBattery AKU (dobieha)“**, verzia 2026 od 1. 1. 2026, schválená: VBattery AKU za 1,00 € mesačne bez DPH (s DPH 1,23 €; Peter, otázka 12b); produkt ostáva Dobieha.
- **Nie je v skripte:**
  - variant pri DMP10 – použitý produkt variant nemení (`0023`); import zmlúv rozpozná DMP10 podľa kódu a prekladu.
- **Overenie (dočasná databáza `0001`–`0024` + `cenniky-2026.sql`):**
  - skúška nič neuloží;
  - uloženie: 45 produktov, 68 prekladov;
  - opakované spustenie bez zmeny;
  - testy 135 OK.

---

## 23. Plán migrácie `0025_zmluvy_jadro` (fáza F2, časť 1) – na schválenie

Rovnaký postup ako pri `0023`: čítanie na `dev` (so súhlasom) → migrácia a testy nanečisto na dočasnom lokálnom Postgrese → výsledok a príkazy pre `dev`. **Migrácia sa na `dev` spustí spolu s úpravou API**, lebo dnešné dotazy čítajú stĺpce, ktoré `0025` mení (časť 23.4).

### 23.1 Čítanie na `dev` pred migráciou (iba čítanie, so súhlasom)

`db/test-data/0025-pred-migraciou.sql`: počty `contract`, `contract_price`, `contract_purchase`, `deal` (zmluvy a ceny musia byť 0 – overené už pred `0023`, overí sa znova); či niektorá zmluva odkazuje na deal; posledná migrácia `0024`.

### 23.2 Obsah (`-- migrate:up`)

| # | Objekt | Podrobnosti |
| --- | --- | --- |
| 1 | kontrola | `contract`, `contract_price` prázdne, inak chyba (ako `0019`) |
| 2 | enumy | `contract_type`, `contract_phase` (+ druh prekladu `faza` v `import_alias` a systémové preklady fáz O1, O10), `contract_close_reason`, `contract_oom_group`, `price_slot`, `contract_flag_code`, `price_exception_status` |
| 3 | `contract` (úprava, časť 1) | zrušiť `status`, `confirmed`, `signed_at` (a enum `contract_status`); pridať `op_id`, `type`, `phase`, `signed_on`, `prolonged_to`, `small_business`, `list_price`, `viwa_package`, `close_reason`, `owner_id`, `created_by_name`, `previous_contract_id`, `related_contract_id`, `note`, `op_updated_at`; `number NOT NULL`; `deal_id` ostáva |
| 4 | stav zmluvy | `contract_effective_to(contract)`, `contract_state(contract, dnes)`; pohľad `contract_v` (stav, skutočný koniec, počet OOM, objem za rok, príznaky, obchodník) |
| 5 | `contract_oom` (časť 2) | s `op_valid_to`, `valid_to` (skutočný koniec), `successor_id`, `is_binding`, `grp`; `EXCLUDE` nad skutočnou dobou platnosti iba pri podpísaných |
| 6 | nástupníctvo (časť 2.1) | `contract_oom_succession(nová zmluva)`: skrátenie prolongácie alebo zmluvy na neurčito v tom istom druhu (dodávka – dodávka, výkup/VIWA – výkup/VIWA), `previous_contract_id`, zmazanie cien prolongácie po dátume, príznak „Na kontrolu“ pri zrušení nástupcu; skutočné prekrytie z OP = chyba; volá ju import (`0026`) aj nočný beh (`0028`) |
| 7 | `contract_price` (prerobenie, časť 3) | zrušiť a založiť znova so `slot`, `price_model`, `price_list_item_id`, obdobím, VT/NT, aditívom €/%, poplatkami, DPH, `op_product_name`, `source`; CHECK podľa modelu; `EXCLUDE` jednej ceny na zmluvu × OOM × slot × obdobie; spúšťač: cenníková cena = kópia položky schválenej verzie; enum `contract_price_status` sa ruší |
| 8 | `contract_flag` (časť 7.1) | príznaky Pod hranicou, Chýba cena, Sprolongované bez ceny, Končí do 4 mesiacov, Na kontrolu |
| 9 | `price_exception` (časť 5) | výnimky; schvaľuje iba „schvaľuje ceny“ a nie autor; Expirovaná sa počíta (`valid_until < dnes`) |
| 10 | ochrana stĺpcov | stĺpce z Office portálu mení iba import a nočný beh (funkcie `SECURITY DEFINER`); aplikácia iba `previous_contract_id`, `related_contract_id`, `close_reason`, `note`, `custom`; `contract_oom` a `contract_price` aplikácia nemení |
| 11 | RLS (časť 12) | `contract` a všetko pod ním: spoločnosti používateľa a (`crm_sees_all_contracts()` **alebo** „iba svoje“ = vlastník zákazníka **alebo** `owner_id` = prihlásený – odpoveď 3b); úprava CRM stĺpcov podľa „upravovať“ v module Zmluvy; `price_exception`: autor, „všetko“ / „schvaľuje ceny“, admin; marža sa obmedzí až v pohľadoch `0027` |
| 12 | `customer_status_calc` | pravidlo 2: `phase = 'podpisana' AND valid_from > dnes` (časť 1.1) |
| 13 | ostatné funkcie | kontroly mazania zákazníka a OOM (`… EXISTS contract / contract_price`) ostávajú platné; `crm_external_ready()` ostáva `false` (dealy a ponuky ešte nemajú RLS) |
| 14 | audit | `contract`, `contract_oom`, `contract_price`, `contract_flag`, `price_exception` |

`contract_purchase` sa nemení (presun z HubSpotu). `-- migrate:down`: návrat do stavu `0024` (tabuľky zmlúv sú prázdne, dáta sa nestrácajú).

### 23.3 Testy `db/test/checks_zmluvy.sql` (Z1)

- **Stav zmluvy:** v príprave / podpísaná s budúcou účinnosťou / účinná / skončená / prolongovaná; stav zákazníka „Čakajúci“ z podpísanej zmluvy s budúcou účinnosťou.
- **Nástupníctvo (doplnok a), Petrove scenáre:**
  - retencia (nová zmluva po konci starej);
  - retencia počas prolongácie (skrátenie, zmazanie cien prolongácie, väzba predošlá);
  - čiastočný nástupca (3 OOM → 1 prejde);
  - prepis počas prolongácie (iný zákazník);
  - zmluva na neurčito v rámci druhu (dodávka – dodávka; VIWA ukončí výkup, dodávku nie);
  - skutočné prekrytie z OP = chyba (aj priamy zápis);
  - zrušenie nástupcu → „Na kontrolu“.
- **Ceny:** model ↔ stĺpce, cenníková cena so zlou kópiou sa neuloží, dve ceny komodity v jednom období sa neuložia, VIWA účet bez OOM.
- **RLS:**
  - obchodník vidí zmluvu svojho zákazníka aj zmluvu, ktorú uzavrel pri cudzom zákazníkovi, inú nie;
  - **Sales_internal so „schvaľuje ceny“ vidí cudzie zmluvy a výnimky, bez príznaku nie** (Petrov doplnok k `0023`);
  - stĺpce z OP aplikácia nezmení, CRM stĺpce áno.
- **Výnimky:** autor neschváli, schvaľovateľ áno, Expirovaná po 30 dňoch.
- Spolu so staršími testami (dnes 135).

### 23.4 Úprava API v tom istom nasadení

Dotazy, ktoré čítajú zrušené stĺpce, sa prispôsobia (zmluvy sú na Teste prázdne, obrazovky ukážu nulu):
- karta zmluvy `queries/contracts.ts`;
- karta zákazníka (počet aktívnych zmlúv podľa `contract_v.state = 'ucinna'`, zoznam zmlúv);
- karta OOM (ceny zo zmlúv z nového `contract_price`).

Plné obrazovky 25–27 (zoznam, karta, import) prídu v `0026` + kóde F2.

### 23.5 Čo potom

- `0026_zmluvy_import`: import Office portálu a XM Trade (vrátane triedy TDO, regulácie s dátumom dnes, `Osoba_ID` a zákazníka založeného importom); lokálne overenie na vzorových exportoch (doplnok b); obrazovky 25–27.
- `0027` bilancia a výnimky, `0028` nočný beh a upozornenia, `0029` Cockpit.

## 24. Migrácia `0025_zmluvy_jadro` – overená nanečisto (14. 10. 2026)

Čítanie na `dev` pred migráciou (so súhlasom): posledná migrácia `0024`; zmluvy, ceny zmlúv, nákupné ceny a dealy 0.

**Úpravy oproti plánu (časť 23) pri implementácii:**
- `contract.prolonged_to` sa volá **`crm_valid_to`**: koniec podľa CRM, teda prolongácia aj skrátenie nástupcom (aj pri dobe neurčitej). Skutočný koniec = `contract_effective_to()`.
- Nástupníctvo beží **v spúšťači `contract_oom`** vždy, keď sa riadok stane záväzným (podpis) alebo sa jeho obdobie rozšíri. Import a nočný beh ho teda nemusia volať zvlášť. Zmluva, ktorá na OOM nadväzuje deň po konci staršej (retencia bez prekrytia), dostane väzbu „predošlá zmluva“ bez skracovania.
- Príznak „Sprolongované bez novej ceny“ sa uzavrie, keď má každé sprolongované OOM starej zmluvy nástupcu.
- `grp` a `slot` sú text s CHECK (nie enum) – obmedzenie proti prekrytiu potrebuje nemenné výrazy a nezávisí od verzie `btree_gist`.
- **Strážne spúšťače bežia s právami volajúceho** (nie `SECURITY DEFINER`): „iba import“ = vlastník databázy alebo funkcia vlastníka. Pri `SECURITY DEFINER` by kontrola prepustila každého – odhalil to test Z1-4.
- **Rovnaká slabina v `0024` (trhové ceny, už na `dev`):** admin alebo „schvaľuje ceny“ by po nastavení premennej relácie mohol riadok ceny dňa priamo prepísať. Uzavreté bez migrácie: `api/db/app-role.sql` odoberá aplikácii UPDATE na `market_price_daily` (označenie „opravené“ robí funkcia vlastníka).
- `api/db/app-role.sql` pre zmluvy: aplikácia zmluvy nezakladá; na `contract` mení iba stĺpce CRM (`previous_contract_id`, `related_contract_id`, `close_reason`, `note`, `custom`); `contract_oom` a `contract_price` nemení; výnimky smie zmazať (iba vlastnú čakajúcu – spúšťač).
- Návrat (`down`) vráti stĺpce `status`, `confirmed`, `signed_at` na koniec tabuľky `contract`. Schéma sa od `0024` líši iba poradím týchto troch stĺpcov.

**Overenie (dočasný Postgres, `0001`–`0024` + cenníky 2026 + `podnikatelia-2026`, nie Neon):**

| Krok | Výsledok |
| --- | --- |
| `0025` hore | OK |
| Testy | **140 kontrol OK** (135 + Z1-1 až Z1-5) |
| `0025` dole | schéma = `0024` okrem poradia 3 stĺpcov zmluvy |
| `0025` znova hore | rovnaká schéma (0 riadkov rozdielu) |
| Práva `crm_app` | UPDATE trhových cien nie, INSERT zmluvy nie, UPDATE `note` áno, UPDATE `phase` nie |
| API (lokálne, vymyslená zmluva) | karta zmluvy (stav účinná, OOM, cena komodita FIX platná), karta firmy (1 aktívna zmluva), karta OOM (cena zo zmluvy) |

**Testy Z1** (`db/test/checks_zmluvy.sql`):
- stav zmluvy a „Čakajúci“ zákazník;
- nástupníctvo: retencia, retencia počas prolongácie, čiastočný nástupca, prepis, doba neurčitá v rámci druhu (VIWA ukončí výkup, dodávku nie), skutočné prekrytie a podpis skôr = chyba, zmluva v príprave sa prekrýva, zrušenie nástupcu = „Na kontrolu“;
- ceny;
- RLS (zákazník aj uzatvoril; „schvaľuje ceny“ v Sales_internal vidí všetky zmluvy a výnimky, bez príznaku nie);
- ochrana stĺpcov;
- výnimky;
- preklady fáz.

Upravené aj staršie testovacie dáta (`seed.sql`, `checks.sql`, `checks_zakaznici.sql`) na novú štruktúru zmluvy.

**Kód v tom istom nasadení:**
- API: `queries/contracts.ts`, `queries/customers.ts` (aktívne zmluvy podľa stavu, zoznam), `queries/oom.ts` (ceny zo zmlúv);
- web: karta zmluvy, karta OOM, karta zákazníka a osoby (stav zmluvy, zložka ceny namiesto smeru, bez „potvrdená“).

---

## 25. Plán migrácie `0026_zmluvy_import` a kódu F2 (časť 2) – schválený (Peter, 14. 10. 2026)

Cieľ: zmluvy sa dostanú do CRM importom exportu Office portálu (s cenami) a OOM importom exportu XM Trade, s náhľadom ako pri OOM (obrazovka 27). Pravidlá polí sú v častiach 8 a 9; tu poradie, objekty, výpočet cien a overenie.

### 25.1 Postup jedného importu (oba súbory naraz alebo každý zvlášť)

1. **API prečíta súbory** (SheetJS, ako import OOM):
   - rozpozná zostavu podľa hlavičiek: Office portal „HEO - Web Zmluvy - prehlad EE“, XM Trade „Prehľad“;
   - **zahodí dátum narodenia a rodné číslo** (rozhodnutie 9) – do databázy nejdú ani v náhľade;
   - znormalizuje bunky: 1900-01-01 = prázdne, `-` = prázdne, kWh → MWh podľa `MJ`, `DD.MM.RRRR` → dátum, IČO bez medzier;
   - pošle do databázy JSON.
2. **Databáza** – jedna funkcia `contract_import_run(org, xm_rows, op_rows, uložiť, odtlačok, očakávané počty)`, náhľad iba číta, uloženie v jednej transakcii. Pri uložení:
   - **XM Trade najprv:** OOM sa založia alebo aktualizujú (rovnaké pravidlá ako import OOM `0018`: nové OOM Pripravované, stav a zákazníka existujúceho OOM nemení). Nové OOM domácnosti dostane zákazníka cez zmluvu z Office portálu v tom istom behu (číslo zmluvy → `Osoba_ID`).
   - **Office portal potom:** zmluvy, OOM v zmluve, ceny.
   - Prepočet stavu dotknutých zákazníkov raz na konci (ako `0018`).
3. **Náhľad po zmluvách:** Nová, Zmena (s popisom, napr. „Fáza Čaká na podpis → Finálne podpísaná“), Bez zmeny (`Greatest_updated_at`), Upozornenie, Chyba, Preskočené (test). Chyba v zmluve = celá zmluva sa neuloží, ostatné áno. Neznámy názov (fáza, produkt, sadzba, obchodník) = chyba s „Pridať preklad“ (rozhodnutie 5).
4. **Súbor sa neukladá** – uloží sa záznam `contract_import` (kto, kedy, názov a odtlačok súboru, počty) a `contract_import_change` na kartu zmluvy.

### 25.2 Objekty (`-- migrate:up`)

| # | Objekt | Podrobnosti |
| --- | --- | --- |
| 1 | `contract_import`, `contract_import_change` | časť 8.1; čítajú tímy s právom „import zmlúv“ a admin |
| 2 | `company.op_person_id`, `contact.op_person_id`, `created_by_import` | časť 8.2; jedinečné v spoločnosti; príznak „založený importom“ zruší prvá ručná úprava alebo „Skontrolované“ |
| 3 | `oom.tdo_class` | trieda TDO z XM Trade (otázka 14), text; export a import OOM |
| 4 | `oom_import_run` (úprava `0018`) | zmena cenovej regulácie existujúceho OOM sa zapíše ako zmena s „platí od“ dnes (otázka 19); nové pole `tdo_class` |
| 5 | `contract_import_run(...)` | celý import (časť 25.1), `SECURITY DEFINER`, iba s právom „import zmlúv“; nástupníctvo a prekrytie rieši spúšťač z `0025` |
| 6 | pomocné funkcie | `contract_import_price_rows(...)` – výpočet cien zmluvy (časť 25.3); `contract_import_customer(...)` – nájdi alebo založ zákazníka |
| 7 | `import_alias` | druh `obchodnik` už je; systémové preklady sa nepridávajú (mená obchodníkov pridá admin pri prvom importe) |
| 8 | práva | `crm_app`: SELECT nových tabuliek, EXECUTE importu; zápis iba cez funkciu |

### 25.3 Ceny pri importe

| Zmluva | Riadky ceny (`contract_price`) |
| --- | --- |
| Firma, individuálna cena (`GREEN_*_INDIVIDUAL`, `ISOTSK_PLUS`) | **komodita** podľa modelu z prekladu, obdobie z `ZZC` orezané na účinnosť, pri 1T + 2T cena podľa typu tarifu produktu OOM (rozhodnutie 2); **poplatok za OM** – položka cenníka „Poplatky B2B“ platná v danom období |
| Firma, cenníková cena (malý podnik, DMPx) | **komodita** = položka platnej verzie cenníka „Malé podniky“ pre produkt OOM, po verziách (každá verzia = vlastné obdobie) |
| Domácnosť (cenníková cena) | **komodita** = položka cenníka Domácnosti ANO alebo NIE podľa regulácie OOM, produkt DDx z prekladu (`target_extra.ano`), po verziách; **ZEM** pri každom OOM spotreby (zadanie modulu 3: „platia iba domácnosti, za každé OOM spotreby“); **VBattery** program z prekladu a cenníka VBattery / VBattery V / VBattery AKU |
| Výkup | komodita (výkup FIX / SPOT − € / SPOT − %) z prekladu, cena na rok; pri dobe neurčitej posledné obdobie bez konca (zadanie časť 5) |
| VIWA | **mesačná platba za účet** a **€/kW** z položky cenníka Green VIWA podľa balíka – otázka 20 |

- **Chýba cena** (príznak): obdobie účinnosti bez komodity, položka cenníka chýba, cenníková cena pri produkte, ktorý nie je v platnej verzii.
- **Na kontrolu** (príznak): produkt Dobieha alebo Ukončený pri novej zmluve, `_PC_M09`, nesúlad regulácie VBattery (XM vs. produkt), nesúlad výkonu zdroja (OP vs. OOM), možná duplicita osoby, zmluva na neurčito ukončená nástupcom.
- Pridaná hodnota, marža firmy, snímka ceny pre obchodníka, príznak „Pod hranicou“ a párovanie výnimiek prídu v `0027` (bilancia).

### 25.4 Kód F2

- **API:** `routes/contract-import.ts` (náhľad, uloženie, chybné riadky .xlsx), `routes/contracts.ts` (zoznam s filtrami, karta, úprava údajov CRM, export), preklady importu z náhľadu.
- **Web:** obrazovky 25 (zoznam zmlúv), 26 (karta zmluvy), 27 (import: dva súbory, náhľad po zmluvách, „Pridať preklad“, uloženie); položka menu Zmluvy; Zákazníci → filter „založený importom“.

### 25.5 Overenie

- **Databáza nanečisto:** dočasný Postgres, testy `checks_zmluvy_import.sql` s vymyslenými riadkami. Pokrytie:
  - nová, zmena, bez zmeny, test riadok;
  - 1T + 2T, kWh;
  - domácnosť s účinnosťou z XM, nový zákazník;
  - VBattery, ZEM, výkup na neurčito, nástupníctvo z importu;
  - chyby: neznámy preklad, prekrytie, chýbajúce OOM, dva cenové riadky.
- **Vzorové exporty (doplnok b):**
  - celý import oboch vzorových súborov na dočasnej lokálnej databáze s vymyslenými zákazníkmi a cenníkmi, **na `dev` nič**;
  - Peter dostane počty nová / zmena / bez zmeny / upozornenie / chyba / preskočené a príklady chýb **bez osobných údajov**;
  - dočasná databáza sa zmaže.
- **API a obrazovky:** lokálne proti dočasnej databáze; na Teste Peter s vlastným exportom (osobitný súhlas – na `dev` by išli skutočné osobné údaje; rozhodnutie 2026-10-12 hovorí o vymyslených dátach na Teste).

### 25.6 Otázky

- **20. VIWA bez balíka:** kým Office portal nedoplní stĺpec balíka (O5), import VIWA nevie, ktorá položka cenníka platí. **Odporúčam:** zmluvu VIWA založiť bez cien s príznakom „Chýba cena“; balík doplní Servis v CRM (nový údaj CRM na zmluve, kým ho neprinesie import).
- **21. Skutočné exporty na Teste:** Test (`dev`) má dnes iba vymyslené dáta. Import skutočného exportu by tam priniesol osobné údaje zákazníkov. **Odporúčam:**
  - na Teste skúšať iba vymyslený export (pripravím ho z vzorovej štruktúry s vymyslenými menami a EIC);
  - skutočné exporty až na Ostrom.
- **22. Obchodník podľa mena:** v exporte je meno („Uzatvoril“), nie e-mail. **Odporúčam:**
  - preklad meno → používateľ CRM (druh `obchodnik`), ktorý admin pridá pri prvom importe z náhľadu;
  - prázdne meno = zmluva bez obchodníka (vo vzorke 46 z 179 riadkov) a upozornenie.

### 25.7 Odpovede, implementácia a overenie nanečisto (14. 10. 2026)

**Peter:** plán schválený.
- **20:** VIWA bez balíka sa uloží bez cien s príznakom „Chýba cena“, balík doplní Servis.
- **21:** na Teste iba vymyslený export; prvý skutočný import až na Ostrom, najprv iba náhľad, ktorý prejdeme spolu.
- **22:** obchodník cez „Pridať preklad“. Prázdny obchodník sa nenahrádza tvorcom zmluvy – zmluva sa uloží bez obchodníka s upozornením, tvorca je iba informácia.
- **Doplnky:** a) prázdna bunka v exporte nikdy neprepíše hodnotu v CRM; b) zákazník založený importom má vlastníka = obchodník zo zmluvy, bez obchodníka ostane bez vlastníka s upozornením; c) opakovaný import toho istého súboru = všetko „bez zmeny“. Ku každému test.

**„Uzatvoril“ (overenie k otázke 22):**
- 5 vzorových zmlúv v PDF má pole „Uzatvoril“ v tvare „meno / spoločnosť“. Žiadna z nich nie je vo vzorovom exporte, priamo porovnať sa nedajú.
- V exporte je `ObchodnikNazov` = `VytvorilNazov` v 104 zo 105 zmlúv, kde sú vyplnené obe. 9 mien je iba vo `VytvorilNazov` (tvorcovia, nie obchodníci). 2 mená z PDF sú medzi menami exportu (v oboch stĺpcoch).
- Import berie `ObchodnikNazov`. Overí sa na prvom skutočnom exporte (náhľad na Ostrom).

**Úpravy oproti plánu pri implementácii:**
- `contract_import`: počty v jednom stĺpci `counts`, názov a odtlačok súboru Office portálu aj XM Trade. Zmeny z importu majú v audite odkaz `audit_log.contract_import_id` (import OOM zo šablóny ostáva v `import_id`). Zmluva má `last_import_id`.
- **Osoba založená importom môže byť bez e-mailu a telefónu** (Office portal ich neposiela). Príznak „založený importom“ drží, kým sa kontakt nedoplní; potom ho zruší prvá ručná úprava alebo „Skontrolované“.
- `contract_oom.program_id`: program VBattery popri produkte DD (DD z XM Trade, program z Office portálu).
- **Balík VIWA zadá Servis v CRM** (aplikácia mení iba tento stĺpec; balík iba pri zmluve VIWA – obmedzenie). Spúšťač doplní ceny Green VIWA (platba za účet, €/kW pri OOM) a uzavrie „Chýba cena“. Obchodníka zmluvy zmení v CRM iba vedenie alebo admin, rovnako ako vlastníka zákazníka.
- **Oprava `0025`:** nástupníctvo sa spustí aj vtedy, keď OOM v zmluve dostane účinnosť dodatočne (domácnosť: začiatok dodávky z neskoršieho importu XM Trade). Predtým by prolongácia staršej zmluvy nebola skrátená a import by skončil chybou prekrytia.
- Ceny:
  - z cenníkov počíta `contract_price_list_sync`: komodita pri cenníkovej cene (DD, DMP), ZEM, program, mesačná platba za OM firmy, VIWA;
  - individuálne ceny z Office portálu počíta `contract_import_op_prices`;
  - zapisujú sa iba pri zmene, takže opakovaný import nič nezapíše.
- **„Chýba cena“ sa kontroluje od 1. 1. bežného roka** (staršie roky CRM v cenníkoch nemá); pri dobe neurčitej do konca bežného roka. Otázka 25.
- **Prázdna bunka (doplnok a)** neprepíše ani údaje z Office portálu, ktoré už v CRM sú (účinnosť do, podpis, tvorca, obchodník, balík VIWA, dôvod uzatvorenia).
- Zmluva so starším alebo rovnakým `Greatest_updated_at` sa nespracúva; doplnia sa iba údaje z XM Trade (účinnosť domácnosti, produkt DD pri VBattery).
- **Import OOM zo šablóny (`0018`):**
  - trieda TDO;
  - zmena cenovej regulácie existujúceho OOM sa zapíše do histórie s „platí od“ dnes (otázka 19);
  - prázdna regulácia v súbore reguláciu nezruší.
- **Čítanie exportov:** `api/src/contract-import-parse.ts` (použije ho aj API):
  - rozpozná zostavu podľa hlavičiek, aj s hranatými zátvorkami Office portálu;
  - prevedie kWh na MWh a dátumy (1900 = prázdne);
  - dátum narodenia a rodné číslo nečíta vôbec.

**Overenie (dočasný Postgres, `0001`–`0026` + skripty cenníkov 2026, nie Neon):**

| Krok | Výsledok |
| --- | --- |
| `0026` hore | OK |
| Testy | **150 kontrol OK** (140 + Z2-1 až Z2-10, `db/test/checks_zmluvy_import.sql`) |
| `0026` dole | schéma = `0025` (0 riadkov rozdielu) |
| `0026` znova hore | rovnaká schéma ako prvé `up` |
| Vzorka Office portálu – prevod | 179 riadkov, 150 zmlúv, bez chýb čítania; kWh → MWh; bez dátumu narodenia |
| OOM pre vzorku | 151 vymyslených riadkov XM Trade (EIC, číslo zmluvy, PDS podľa predpony EIC, NN/VN); vzorky XM a OP sa neprekrývajú |
| Náhľad bez prekladov obchodníkov | 40 nových, 109 chýb „Neznámy obchodník“ (13 mien) s ponukou prekladu |
| Náhľad po doplnení 13 prekladov | **149 nových, 0 chýb, 1 preskočená (test)**, 94 s upozornením; OOM 151 nových; 0,6 s |
| Uloženie, potom ten istý import znova | **149 zmlúv a 151 OOM „bez zmeny“** (0,16 s) |
| Skutočný XM Trade (5 riadkov) | bez zmlúv v CRM 5 chýb „zákazníka nejde určiť“; s vymyslenými zmluvami 5 nových OOM, všetky stĺpce preložené (PDS, sadzba D3, D4, X2, typ merania, fakturačné obdobie, zálohy, trieda TDO, plán v MWh), virtuálne OOM = sharing |
| Dočasná databáza | zmazaná |

Upozornenia vo vzorke (zmluvy):
- 64 nesúlad súčtu množstva zmluvy a OOM (rozhodnutie 1);
- 40 bez obchodníka (tvorca ako informácia);
- 37 nový zákazník bez vlastníka;
- **17 „Chýba cena“**: 14 firiem s cenou iba za starší rok (otázka 23), 2 VIWA bez balíka, 1 domácnosť bez produktu pri OOM;
- 2 EIC neobvyklého tvaru;
- 1 mesačná cena výkupu `_PC_M09` na kontrolu;
- 1 cena mimo účinnosti (vynechaná).

XM Trade: 4 nesúlady regulácie (produkt „ANO Energopomoc“, stĺpec „Neregulované“ – platí produkt), 2 „Dodávka (+)“ (otázka 24).

**Otázky:**
- **23. Cena iba za starší rok:** 14 firemných zmlúv vo vzorke je účinných aj v roku 2026 (niektoré na neurčito), ale export má cenu iba za rok 2023, 2024 alebo 2025. Najčastejšie ide o SPOT + aditív (`GREEN_ISOTSK_PLUS_RRRR_R`), niekde o FIX. Import pre rok 2026 hlási „Chýba cena“. Platí aditív (alebo FIX) posledného roka aj pre ďalšie roky účinnosti? **Odporúčam:** pri SPOT + aditív áno (posledné obdobie bez konca, ako pri výkupe), pri FIX nie (Chýba cena, rieši Servis alebo prolongácia).
- **24. „Dodávka (+)“ v XM Trade** (VBattery domácnosti): nové OOM sa zakladá ako spotreba s upozornením. **Odporúčam** ponechať (typ OOM sa dá na karte zmeniť).
- **25. Obdobie kontroly „Chýba cena“:** od 1. 1. bežného roka (pri dobe neurčitej do konca bežného roka). **Odporúčam** ponechať; staršie roky dopĺňa iba presun z HubSpotu.

**Odpovede 23–25 (Peter, 14. 10. 2026) – zapracované do `0026`:**
- **23:** SPOT + aditív: aditív posledného roka platí ďalej (do konca OOM v zmluve, pri dobe neurčitej bez konca), rovnako ako výkup. FIX: ak má zmluva automatickú prolongáciu, od konca posledného roka s cenou platí cenník „Podnikatelia nad 30 MWh“ (produkt podľa typu tarifu OOM, pri verejnom osvetlení Green 1T VO). Mesačná platba za OM z Poplatkov B2B sa v tom období nepridáva, lebo je v položke cenníka. Bez prolongácie „Chýba cena“.
- **24:** „Dodávka (+)“ v XM Trade = OOM typu výroba, „Odber (−)“ = spotreba, bez upozornenia. Nepreložiteľná hodnota = spotreba s upozornením. Existujúcemu OOM sa typ nemení; pri nesúlade upozornenie. **Dôsledok:** VBattery sa viaže na výrobné OOM, takže v zmluve o dodávke má výrobné OOM iba program VBattery. Komodita, ZEM a „Chýba cena“ sa počítajú iba pri OOM spotreby; produkt DD z XM Trade sa ukladá iba pri OOM spotreby.
- **25:** kontrola „Chýba cena“ od 1. 1. bežného roka – áno.

Testy po úprave: **152 kontrol** (+ Z2-11 cena po poslednom roku, Z2-12 typ OOM z XM Trade). Vzorka: 149 nových zmlúv, 0 chýb; „Chýba cena“ 11 namiesto 17:
- 8 firiem s FIX – bez prolongácie, alebo s prolongáciou, ale cenník nad 30 MWh platí až od 1. 10. 2026 (január – september 2026 bez ceny);
- 2 VIWA bez balíka;
- 1 domácnosť bez produktu.

### 25.8 API importu a obrazovky 25–27 – lokálne overené (14. 10. 2026)

**API:**
- `routes/contract-import.ts`:
  - `POST /api/contract-import/preview` – jeden alebo dva súbory, zostava sa rozpozná sama;
  - `POST /api/contract-import/save` – iba rovnaké odtlačky súborov a počty ako v náhľade, inak 409;
  - `POST /api/contract-import/errors` – .xlsx s chybami: riadok, číslo zmluvy alebo EIC, text chyby, bez údajov osôb;
  - `GET /api/contract-import/history`;
  - právo „importovať“ v module Zmluvy (pri XM Trade aj v module OOM – stráži databáza).
- `routes/contracts.ts`:
  - `GET /api/contracts` – stav, príznak, typ, obchodník (aj „bez obchodníka“), hľadanie podľa čísla, zákazníka a EIC; počty v tlačidlách;
  - `GET /api/contract-filters`, `GET /api/contracts/:id` (karta);
  - `PATCH /api/contracts/:id` – poznámka, dôvod uzatvorenia, predošlá a súvisiaca zmluva (zadávajú sa číslom), balík VIWA, obchodník (iba vedenie a admin);
  - `POST /api/contract-flags/:id/resolve`.
- Preklady importov: nový druh **fáza** (API aj stránka Nastavení).

**Web:**
- **25 Zoznam zmlúv:** tlačidlá stavov a príznakov, filtre, menu Zmluvy zapnuté. Bez stĺpcov bilancie – prídu v F3 (`0027`).
- **26 Karta zmluvy:**
  - zahŕňa príznaky s tlačidlom „Vyriešené“ (okrem „Chýba cena“, ktorá zmizne sama), ceny po zložkách a obdobiach, OOM v zmluve (nástupca), údaje zmluvy, históriu importov a panel „Upraviť údaje CRM“;
  - bilancia príde v F3.
- **27 Import:**
  - nahratie jedného alebo dvoch súborov, náhľad po zmluvách (filtre) a OOM z XM Trade;
  - chýbajúce preklady s tlačidlom „Pridať preklad“ (admin) a prepočtom náhľadu;
  - „Čo sa stane“, stiahnutie chýb, uloženie, história importov.
- **Export zoznamu zmlúv** (tlačidlo na obrazovke 25) zatiaľ nie je – príde s bilanciou v F3.

**Overenie (lokálny Worker ako Peter proti dočasnej databáze; vzorové exporty; OOM pre vzorku vymyslené jednej testovacej firme):**

| Krok | Výsledok |
| --- | --- |
| Náhľad Office portal + XM Trade | 149 nových zmlúv, 0 chýb, 1 testovacia preskočená; 5 OOM z XM Trade s chybou (ich zmluvy v CRM nie sú); 0,3 s |
| Uloženie s iným odtlačkom | 409 |
| Uloženie, potom ten istý náhľad | 149 „bez zmeny“ |
| Zoznam, filtre, hľadanie podľa EIC, karta | OK |
| Balík VIWA v CRM | ceny Green VIWA (účet, €/kW), „Chýba cena“ uzavretá |
| Balík pri zmluve o dodávke, súvisiaca zmluva iného zákazníka | odmietnuté so slovenskou hláškou |
| Uzavretie príznaku „Na kontrolu“ | OK |
| Testy databázy | 152 OK; `0026` dole = schéma `0025`, znova hore rovnaká |

Typy (`tsc`) a zostavenie webu prešli. Obrazovky som v prehliadači neprezeral (iba API a zostavenie).

### 25.9 Pred nasadením na Test (14. 10. 2026)

- **VBattery** (Peter potvrdil): pravidlo z časti 25.7 platí, test Z2-12.
- **Cenník nad 30 MWh od 1. 1. 2026:** skript `db/seed/podnikatelia-2026` pridá verziu „2026 (1.–9.)“ od 1. 1. 2026 s rovnakými cenami; schválenie ju ukončí 30. 9. 2026. Opakovateľné.
- **`0026` doplnená:**
  - chyba nového OOM z XM Trade (napr. neznáma sadzba) sa ukáže pri zmluve aj s ponukou prekladu (test v Z2-4);
  - návrat (`down`) neskončí chybou, ak na Teste ostanú osoby založené importom bez kontaktu – kontrola dosiahnuteľnosti ostane `NOT VALID`; bez nich je schéma presne `0025`.
- **Snímky obrazoviek 25–27** (headless Chrome, vymyslený export) porovnané s dizajnom. Opravené:
  - pád zoznamu (príznaky z databázy ako text → `to_jsonb`);
  - karta: drobčeková navigácia, veľké číslo, ceny zlúčené naprieč OOM („všetky (n)“), stav ceny pri období, rozloženie ako návrh (údaje zmluvy a časová os vedľa seba);
  - import: dva stĺpce, karty Office portal / XM Trade, „Čo sa stane“ vpravo, „História importov“ v hlavičke, správne tvary čísloviek, späť na Zmluvy;
  - zoznam: zákazník ako odkaz.
- Vedome chýba (príde v F3 `0027`): stĺpce a karta bilancie, filter „Rok bilancie“, export zoznamu, „Otvoriť v Office portáli“, záložky Kontaktné osoby a Dokumenty.
- **Vymyslené exporty** na skúšku: `exports/importy-test/` (README so scenárom, generátor `vytvor.cjs`).
- Testy 152 OK; `0026` hore / dole / hore bez rozdielu.

### 25.10 Skúška na Teste a uzavretie F2 (14. 10. 2026)

- `0026`, `app-role.sql`, skript `podnikatelia-2026` a nasadenie na Test spustil Peter.
- Oprava po nasadení: zoznam Zákazníci a Leady čítal zrušený `contract.status` (z `0025`).
- Skúška: import 3 zmlúv a 4 OOM prešiel; produkty a služby priradené správne.
- **Úpravy obrazovky importu:**
  - samostatné políčka pre Office portal a XM Trade; prvý import potrebuje oba súbory naraz;
  - import OOM (19) rozpozná exporty z XM Trade a Office portálu a pošle ich na import zmlúv.
- **Rozhodnutie (Peter):** veľkoobchod a GreenSolar sa nerobia ako zmluvy v CRM. Veľkoobchod ide iba do Cockpitu, GreenSolar cez deal do Cockpitu. Ručné zmluvy nie sú. Nové služby sa doriešia neskôr.

---

## 26. Plán F3 – migrácia `0027_zmluvy_bilancia` a kód – na schválenie

Cieľ: ročná bilancia každej zmluvy (pridaná hodnota obchodníka a marža firmy), výnimky z ceny so schvaľovaním (obrazovka 28), príznak „Pod hranicou bez výnimky“. Bilancia sa zobrazí v zozname, na karte zmluvy a na karte zákazníka; export zoznamu zmlúv. Pravidlá výpočtu sú v zadaní (časti 6–8, príklady časť 13) a v časti 6 návrhu; tu poradie, objekty a otvorené body.

### 26.1 Výpočet po mesiacoch

Bilancia roka sa počíta **po mesiacoch** OOM v zmluve. Pravidlá „začatý mesiac sa počíta celý“, „neúplný rok = mesiace / 12“ a „krátka zmluva sa nedelí“ (odpovede 1, 17) z toho vyplynú bez výnimiek.

- **Mesiace OOM:** mesiace skutočného obdobia OOM v zmluve (`contract_oom.valid_from` – `valid_to`, s prolongáciou, skrátené nástupcom), ktoré zasahujú do roka. Pri dobe neurčitej do konca roka.
- **Objem mesiaca:**
  - zmluva na 12 mesiacov a viac (alebo na neurčito): ročné zmluvné množstvo / 12;
  - kratšia: množstvo / počet mesiacov zmluvy;
  - výkup a VIWA: plán výkupu OOM / 12 (dnešná hodnota na OOM, rozhodnutie 3).
- **Cena mesiaca:** riadok ceny zložky, ktorý platí v mesiaci (pri zmene v strede mesiaca platí novší).
- **Výnos komodity:** Σ mesiacov cena × objem podľa modelu:
  - FIX a cenník: VT × objem VT + NT × objem NT;
  - SPOT + aditív a výkup SPOT − €: aditív × objem;
  - výkup SPOT − %: % × očakávaná cena SPOT pre FVE roka × objem;
  - VIWA: odhad aditívu balíka × objem.
- **Poplatky:** Σ mesiacov mesačnej platby (za OM, ZEM, VBattery, VIWA účet) a €/kW × výkon zdroja.
- **Náklad pridanej hodnoty** (snímka ku dňu podpisu – 26.2, alebo schválená výnimka):

| Model / prípad | Náklad |
| --- | --- |
| FIX, predajca obchodník | cena pre obchodníka roka ku dňu podpisu |
| FIX, predajca manažér; cenník bez energopomoci | odhad portfólia roka ku dňu podpisu |
| domácnosť s energopomocou | nákupná cena energopomoci roka |
| SPOT + aditív | minimálny aditív (obchodník / manažér) |
| výkup | minimálny aditív výkupu (otázka 29) |
| VIWA | 0 |

- **Náklad marže firmy:**
  - FIX a cenník bez energopomoci: **dnešný** odhad portfólia roka;
  - SPOT + aditív: 0 (marža = celý aditív);
  - energopomoc, výkup a VIWA: rovnaký ako pri pridanej hodnote.
- **Marža firmy** = výnos komodity + poplatky − náklad marže.
- **Pridaná hodnota** = výnos komodity − náklad (bez poplatkov).
- **Tranža pre Cockpit:** FIX (FIX, cenník bez energopomoci), SPOT (SPOT, VIWA), SEAS (energopomoc).
- Overenie: všetkých 6 príkladov zo zadania časť 13 na halier (testy).

### 26.2 Objekty (`-- migrate:up`)

| # | Objekt | Podrobnosti |
| --- | --- | --- |
| 1 | `contract_year_basis` | snímka ku dňu podpisu pre zmluvu × rok: typ predajcu, cena pre obchodníka, odhad portfólia, minimálny aditív, cena energopomoci, odhad aditívu VIWA, spárovaná výnimka. Zapisuje import (a nové funkcie nižšie), pri zmene podpisu, obchodníka alebo cien sa prepočíta. Pri migrácii sa naplní pre zmluvy, ktoré už sú na Teste |
| 2 | `contract_basis_refresh(contract)` | vytvorí alebo prepočíta snímku pre roky zmluvy; spáruje výnimku |
| 3 | `contract_balance(p_year)` | ročná bilancia všetkých zmlúv, ktoré používateľ vidí (RLS): objem, výnos komodity, poplatky, pridaná hodnota, tranža; marža firmy a náklad portfólia iba pri práve „vidieť maržu“ (inak NULL) |
| 4 | párovanie výnimiek | pri importe: zákazník, rok zmluvy ∈ roky výnimky, model, schválená, podpis ≤ platná do; najnovšia sa stane Použitou a hranicou |
| 5 | príznak „Pod hranicou bez výnimky“ | pri importe a prepočte snímky; uzavrie ho spárovaná výnimka alebo ručné uzavretie schvaľovateľom s poznámkou |
| 6 | „Končí do 4 mesiacov“ | počíta sa (podpísaná zmluva firmy, koniec do 4 mesiacov) – iba filter v zozname; upozornenie pošle nočný beh v F4 |
| 7 | `price_exception_new(...)` | žiadosť: hranicu (snímku) doplní databáza – cena pre obchodníka roka dnes, alebo minimálny aditív podľa typu predajcu autora |
| 8 | práva a audit | `contract_year_basis` iba čítanie pre aplikáciu; audit snímky |

### 26.3 Kód

- **API:**
  - `GET /api/contracts?rok=` s bilanciou;
  - `GET /api/contracts/:id` s bilanciou po rokoch;
  - export zoznamu zmlúv (.xlsx, právo „exportovať“, `export_log`, marža iba s právom);
  - `routes/price-exceptions.ts` – zoznam, nová žiadosť, schválenie a zamietnutie, zmazanie vlastnej čakajúcej;
  - karta zákazníka: zmluvy a súčet pridanej hodnoty (a marže) za rok.
- **Web:**
  - zoznam 25: stĺpce Prid. hodnota a Marža firmy, filter „Rok bilancie“, tlačidlo Export;
  - karta 26: KPI pridaná hodnota a marža, karta „Ročná bilancia“ s prepínaním rokov, výnimka;
  - obrazovka 28 Výnimky: zoznam so stavmi, nová žiadosť, detail so schválením;
  - karta zákazníka: sekcia Zmluvy so súčtom.
- Upozornenia CEO a obchodnému riaditeľovi („Pod hranicou“) pošle až nočný beh a zvonček v F4 (`0028`). V F3 je príznak a filter.

### 26.4 Overenie

- Testy `checks_zmluvy_bilancia.sql` (Z3): 6 príkladov zo zadania, neúplný rok (4/12), krátka zmluva cez dva roky (5 + 5 MWh), zmena ceny v roku, výnimka (párovanie, Použitá, hranica, expirovaná sa nespáruje), „Pod hranicou“, práva (obchodník nevidí maržu, `contract_year_basis` nemení).
- Lokálne: API a snímky obrazoviek 25, 26, 28 s vymysleným exportom (doplnený o BL/PL a parametre).

### 26.5 Otázky

- **26. Zmluvy podpísané pred históriou cien:** cena pre obchodníka ku dňu podpisu potrebuje BL/PL toho dňa. Kým nie je história od 1. 1. 2026 (zdroj určíš ty), a pre zmluvy podpísané skôr, chýba. **Odporúčam:** pridaná hodnota „–“ bez príznaku pri zmluvách podpísaných pred 1. 1. 2026; od 1. 1. 2026 bez ceny príznak „Chýba cena pre obchodníka“.
- **27. FIX manažér a cenník bez energopomoci:** náklad pridanej hodnoty = odhad portfólia **ku dňu podpisu** (snímka), marža firmy = dnešný. **Odporúčam** tak.
- **28. Zmluva bez obchodníka** (46 vo vzorke): ktorý minimálny aditív a cena? **Odporúčam:** ako obchodník (prísnejšie). Pri FIX cena pre obchodníka.
- **29. Výkup, ktorý nie je lokálny zdroj:** náklad pridanej hodnoty = „minimálny aditív – výkup lokálny zdroj“ (0) aj pre ostatné výkupy, alebo iný parameter? **Odporúčam:** jeden parameter „minimálny aditív – výkup“ pre všetky výkupy (dnes 0).
- **30. „Pod hranicou bez výnimky“ iba pri individuálnej cene** (FIX, SPOT + aditív, výkup). Pri cenníkových zmluvách (domácnosti, malé podniky, prolongácia nad 30 MWh) cenu nevyjednáva obchodník. **Odporúčam:** pri cenníku príznak nie.
- **31. Rok bilancie predvolene:** bežný rok, alebo nasledujúci (v jeseni sa predáva najmä na ďalší rok; návrh obrazovky 25 ukazuje 2027)? **Odporúčam:** bežný rok, s prepínačom.
- **32. Odhad portfólia a cena FVE pre marža:** posledná zadaná hodnota roka bez obmedzenia veku, alebo najviac 7 dní ako BL/PL? **Odporúčam:** posledná zadaná (marža je odhad); ak neexistuje, marža „–“.

### 26.6 Odpovede 26–32 a overenie nanečisto (14. 10. 2026)

**Peter:**
- **26:** áno. Zmluvy pred 2026 bez príznaku. Snímku ceny pre obchodníka doplní prenos z HubSpotu (nákupná cena pri deale). História BL/PL od 1. 1. 2026 príde z Cockpitu (dáta sú vo Firebase) – samostatný skript.
- **27:** áno – pridaná hodnota z odhadu ku dňu podpisu, marža firmy z dnešného.
- **28:** áno – zmluva bez obchodníka sa počíta ako obchodník.
- **29:** parameter „Minimálny aditív – výkup“ (0 €) a prepis pri konkrétnej výkupnej zmluve, ktorý zadá Nákup.
- **30:** áno – „Pod hranicou“ iba pri individuálnej cene.
- **31:** áno – rok bilancie predvolene bežný, s prepínačom.
- **32:** áno – pri marži dátum použitého odhadu; starší ako 30 dní = „starý odhad“.

**Implementácia `0027_zmluvy_bilancia`:**
- `contract_year_basis`: snímka pre podpísanú zmluvu × rok.
  - Obsahuje typ predajcu, cenu pre obchodníka, odhad portfólia s dátumom, minimálny aditív, cenu energopomoci, aditív VIWA a výnimku.
  - Zdroj `vypocet` (BL/PL ku dňu podpisu) alebo **`hubspot`**: miesto pre zmluvy pred 2026 je existujúca tabuľka `contract_purchase` (nákupná cena z HubSpotu, rok dodávky). Prenos ju naplní a snímka si cenu vezme odtiaľ, ak BL/PL ku dňu podpisu chýbajú.
  - Aplikácia snímku nečíta (obsahuje odhad portfólia); bilanciu vracia `contract_year_calc`.
- `contract_year_calc(zmluva, rok)`:
  - bilancia po mesiacoch (časť 26.1);
  - marža, odhad portfólia a jeho dátum iba s právom „vidieť maržu“, inak NULL;
  - príznak „starý odhad“ (`portfolio_stale`);
  - riadok iba pre zmluvu, ktorú používateľ vidí.
- `contract_basis_refresh`: snímka, párovanie výnimky, príznaky.
  - Volá ho import (aj doplnenie z XM Trade), zmena balíka VIWA, obchodníka a aditívu výkupu a schválenie výnimky.
  - Pri migrácii sa prepočítajú všetky zmluvy, ktoré už sú na Teste.
- **Párovanie výnimky:** iba s individuálnou cenou z importu (cena prolongácie výnimku nespotrebuje); schválenie spáruje aj už importované zmluvy (dodatočné schválenie).
- **„Chýba cena pre obchodníka“** je príznak „Chýba cena“ **s rokom**; „Chýba cena“ z `0026` (komodita, balík VIWA) je bez roka.
- **Hranica výnimky** sa doplní v databáze pri žiadosti z aplikácie:
  - FIX: cena pre obchodníka prvého roka dnes;
  - SPOT: minimálny aditív podľa typu predajcu autora;
  - výkup: minimálny aditív výkupu;
  - keď hodnota chýba, žiadosť sa odmietne s hláškou.
- **Minimálny aditív výkupu:**
  - parameter `min_aditiv_vykup` (0 €, mení admin; pri lokálnom zdroji ostáva `min_aditiv_vykup_lz`);
  - pri zmluve `contract.vykup_min_additive` – iba výkup (obmedzenie tabuľky), mení Nákup alebo admin.

**Overenie (dočasný Postgres, `0001`–`0027` + cenníky 2026, nie Neon):**

| Krok | Výsledok |
| --- | --- |
| `0027` hore | OK |
| Testy | **155 kontrol OK** (152 + Z3-1 až Z3-3 v `db/test/checks_zmluvy_bilancia.sql`) |
| **Príklady zo zadania** | **všetkých 6 na halier:** FIX 575,10 / 1 808,10 · SPOT 150 / 570 · energopomoc 51,26 / 87,26 · VIWA 240 / 346,80 · lokálny zdroj 43,80 · výkup −10 % 700 |
| Neúplný rok, krátka zmluva | 2026 = 4/12; 1. 10. 2026 – 31. 3. 2027, 10 MWh = 5 + 5 |
| Manažér | pridaná hodnota z odhadu ku dňu podpisu (97), marža z dnešného (96) s dátumom |
| Výnimka | hranica 106 z databázy (nie zo žiadosti); po schválení Použitá, pridaná hodnota (104 − 103) × 50 = 50, príznak uzavretý; expirovaná sa nespáruje |
| Príznaky | FIX pod cenou pre obchodníka = „Pod hranicou“; cenník pod odhadom bez príznaku; podpis od 2026 bez BL/PL = „Chýba cena pre obchodníka“; pred 2026 bez príznaku; cena z HubSpotu doplní snímku |
| Práva | obchodník vidí pridanú hodnotu, nie maržu; snímku nečíta; aditív výkupu nezmení |
| `0027` dole / znova hore | schéma = `0026` / rovnaká |

Upravené staršie testy:
- Z1-4: výnimka na rok 2029 a ceny BL/PL dňa, lebo hranicu dopĺňa databáza;
- Z2-1: príznaky bez roka.

**Otázka 33 – výkup s pevnou cenou** (`GREENVYR_PC_R`): zadanie (časť 8) nepopisovalo pridanú hodnotu výkupu FIX.

**Odpoveď (Peter, 14. 10.):** výkup s pevnou cenou nemá žiadnu zložku SPOT. Nákup doplní trader ručne a rovná sa predaju, takže pridaná hodnota aj marža firmy sú vždy 0 €. V `contract_year_calc` platí pre výkup FIX: výnos = pevná cena × objem, náklad aj náklad marže = pevná cena (tranša FIX); test Z3-1 overuje 0 / 0.

### 26.7 API a obrazovky F3 (lokálne overené 14. 10. 2026)

**API:**
- `GET /api/contracts?rok=` – stĺpce „Pridaná hodnota“ a „Marža firmy“ za rok (marža iba s právom), výpočet `contract_year_calc` iba pre zmluvy na stránke; čip „Končí do 4 mesiacov“.
- `GET /api/contracts/export` – .xlsx podľa filtra, právo „exportovať“ v module Zmluvy, záznam v `export_log`; stĺpec marže iba s právom.
- `GET /api/contracts/:id` – bilancia po rokoch, výnimky zákazníka, `can_edit_vykup`; `PATCH` aj s `vykup_min_additive` (Nákup alebo admin, iba výkup – stráži databáza).
- `/api/price-exceptions` – zoznam s počtami podľa stavu, nová žiadosť (hranicu doplní databáza), rozhodnutie (iba „schvaľuje ceny“ a nie autor), zmazanie čakajúcej autorom.
- Karta zákazníka: sekcia Zmluvy so súčtom pridanej hodnoty (a marže s právom) za bežný rok.
- Cenové parametre: nový parameter `min_aditiv_vykup`.
- Hyperdrive nečíta typy, polia (`text[]`, `smallint[]`) chodia ako text: v dotazoch `to_jsonb(...)` a `IN ${sql(ids)}`.

**Obrazovky** (snímky v headless prehliadači, porovnané s dizajnom):
- 25 Zoznam: rok bilancie, stĺpce Pridaná hodnota a Marža firmy, Export, čip „Končí do 4 mesiacov“.
- 26 Karta: KPI pridanej hodnoty a marže za rok (marža s dátumom odhadu, „starý odhad“ nad 30 dní), karta Bilancia s prepínačom rokov, výnimky, minimálny aditív výkupu v úprave CRM údajov. Opravené po snímke: preširoká tabuľka OOM, orezaný popis KPI.
- 28 Výnimky z ceny (`/vynimky`, položka menu): čipy stavov, tabuľka, detail so schválením / zamietnutím, nová žiadosť. Opravené po snímke: orezané stĺpce.
- 29 Cenové parametre: riadok „Minimálny aditív – výkup“; poznámka pod tabuľkou, že pri konkrétnej výkupnej zmluve ho prepíše Nákup.

**Úmyselné rozdiely oproti dizajnu:**
- 26: chýba „Otvoriť v Office portáli“ a záložky Kontaktné osoby a Dokumenty (zatiaľ bez zdroja údajov).
- 29: aditívy VIWA nie sú zoskupené do jedného riadku a energopomoc nie je po rokoch (stav z F1).

