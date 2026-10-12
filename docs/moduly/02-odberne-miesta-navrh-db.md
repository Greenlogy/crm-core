# Modul 2 – Odberné miesta: návrh databázy

Verzia 0.2 · 12. 10. 2026 · **odpovede zapracované** (v0.1 = návrh; v0.2 = Petrove odpovede a uzavreté otázky, časť 11).
Implementácia: migrácia `0013_oom_jadro` (napísaná, nespustená); `0014`, `0015` nasledujú.
Vychádza zo zadania `02-odberne-miesta.md` v0.2, zadania `01-zakaznici.md` v0.4 (časti 4 a 14),
návrhu Nastavení `00-nastavenia-navrh-db.md` v0.2, migrácií `0001`–`0012` a obrazoviek 17–19.

SQL v tomto dokumente je **náčrt**, nie migrácia. Presné migrácie sa napíšu až po schválení.
Nič sa nespúšťa, databáza sa nemení.

---

## 0. Východisko a poradie migrácií

**Čo už v databáze je** (z `0001`, `0004`, `0007`, `0008`):
- tabuľka `oom` (EIC unikátne, typ, stav, zákazník `company_id` / `person_id`, technické, fakturačné a výrobné údaje, dodávka od – do, `hubspot_id`), `oom_device` (zariadenia),
- `oom.org_id` – spoločnosť sa preberá od zákazníka, iná spoločnosť = chyba (`record_org_fill`, 0008),
- `oom.custom jsonb` + kontrola vlastných polí (`custom_values_check('oom')`, 0007),
- audit na `oom` a `oom_device` (0001, diff po poliach vrátane `custom.*`, 0006),
- `customer_status_calc` (0004) – pripravený, ale **nevolá sa automaticky**,
- `contact_oom_v` (0001) – osoba ↔ OOM cez dealy, stavy `aktivne` a `neaktivne`.

**Čo chýba:** väzba OOM – zákazník v čase, stav Pripravované, kontaktné osoby pri OOM, kroky prechodu
s dátumami, číselníky PDS a sadzieb, kontrola EIC, **RLS na OOM (dnes nie je zapnuté vôbec)**,
priebežný prepočet stavu zákazníka, import z Excelu.

| Migrácia | Obsah | Časť |
| --- | --- | --- |
| `0013_oom_jadro` | stav Pripravované, väzba v čase `oom_customer`, kontaktné osoby `oom_contact`, kroky prechodu a lehoty pri spoločnosti, číselníky, kontrola EIC, povinné údaje pre Aktívne, úprava stĺpcov, **nový `customer_status_calc` a `customer_is_former_calc`** (starý by po premenovaní stavu zlyhal) | 1, 2, 3.1, 4–6 |
| `0014_oom_stav_zakaznika` | priebežný prepočet stavu, segmentu „výrobca“ a príznaku „bývalý“, denná aktivácia, pohľady `customer_v`, `contact_oom_v`, `oom_v` | 3.2, 3.3, 4.4 |
| `0015_oom_rls_import` | RLS na OOM a jeho podtabuľkách, právo „importovať“, záznam importu, audit importu | 7, 8, 9 |

Predpoklad: tabuľka `oom` je na Teste (`dev`) prázdna (po vyprázdnení 12. 10.). Migrácia to overí
a inak skončí chybou – zmena enumu a nová väzba nepočítajú s existujúcimi dátami.

---

## 1. Stav OOM: Neaktívne → Pripravované

```sql
ALTER TYPE oom_status RENAME VALUE 'neaktivne' TO 'pripravovane';
-- výsledok: 'aktivne', 'pripravovane', 'zrusene', 'odidene', 'prepisane'
```

- Premenovanie hodnoty enumu (nie pridanie + zrušenie): žiadny stĺpec, index ani pohľad netreba prerábať,
  `migrate:down` ho premenuje späť.
- Všetky miesta, kde je dnes `'neaktivne'`, sa v `0014` prepíšu (`customer_status_calc`, `contact_oom_v`).
  Inde (API, obrazovky) sa `neaktivne` nepoužíva.
- Pri nahrávaní z HubSpotu (neskôr): HubSpot „Neaktívne“ → `pripravovane`.
- **Typ `velkoobchod` sa ruší** (Peter 12. 10.): enum `oom_type` = spotreba, výroba, sharing (typ sa vytvorí nanovo, OOM sú prázdne).

---

## 2. Väzba OOM – zákazník v čase (`oom_customer`)

Zadanie čl. 3–4: OOM patrí v danom čase práve jednému zákazníkovi, väzba má obdobie a dôvod ukončenia,
**stav sa viaže na obdobie väzby** (starý zákazník má OOM „Prepísané“, nový „Aktívne“).

```sql
CREATE TYPE oom_link_end_reason AS ENUM ('odchod', 'zrusenie', 'prepis');

CREATE TABLE oom_customer (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id       uuid NOT NULL REFERENCES oom (id),
  company_id   uuid REFERENCES company (id),
  person_id    uuid REFERENCES contact (id),
  org_id       uuid NOT NULL REFERENCES org (id),          -- = oom.org_id = spoločnosť zákazníka
  valid_from   date NOT NULL,
  valid_to     date,                                        -- NULL = trvá
  status       oom_status NOT NULL,                         -- stav OOM pre tohto zákazníka
  end_reason   oom_link_end_reason,
  created_at, updated_at,
  CHECK (num_nonnulls(company_id, person_id) = 1),
  CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CHECK ((end_reason = 'prepis') = (status = 'prepisane')),
  EXCLUDE USING gist (oom_id WITH =, daterange(valid_from, valid_to, '[]') WITH &&)  -- obdobia sa neprekrývajú
);
```

Neprekrývanie období vyžaduje rozšírenie `btree_gist` (Neon ho podporuje; `CREATE EXTENSION` v migrácii).

**Pravidlá (Peter 12. 10., odpoveď 1):**
- **Odchod, zrušenie a prepis väzbu uzavrú** (dátum do + dôvod). Otvorená väzba je najviac jedna
  a je vždy Pripravované alebo Aktívne; uzavretá má stav podľa dôvodu (odchod → Odídené, zrušenie → Zrušené, prepis → Prepísané).
- **Novú väzbu založí prepis alebo návrat** na to isté EIC (napr. 2023–2025 u nás, 2027 späť = dve obdobia).
- **Posledná väzba** = väzba s najneskorším `valid_from` (otvorená, alebo posledná uzavretá).
- `oom.company_id`, `oom.person_id` a `oom.status` ostávajú a **zrkadlia poslednú väzbu** (spúšťač).
  Dôvod: existujúce dopyty (karta zákazníka, zmluvy, `record_org_fill`, `mark_household`, mazanie zákazníka v 0011)
  fungujú bez zmeny a zoznam OOM nepotrebuje spojenie navyše. Ručne sa tieto stĺpce nemenia – mení ich iba
  zmena stavu alebo prepis cez funkcie nižšie.
- Prvá väzba vznikne pri založení OOM (`valid_from` = začiatok dodávky, ak už bol, inak dnes; stav Pripravované alebo Aktívne).
- Uzavretá väzba sa nemení (výnimka rola `crm_sync`); Aktívne sa nevracia na Pripravované.
- Prepis na iného zákazníka mimo tejto spoločnosti skupiny nejde (EIC patrí jednej spoločnosti, zadanie čl. 2).

**Funkcie (všetky v jednej transakcii, s auditom):**

```sql
oom_set_status(p_oom_id, p_status, p_date)   -- Aktívne; Odídené / Zrušené uzavrú väzbu k p_date
oom_transfer(p_oom_id, p_new_company_id, p_new_person_id, p_date)
  -- prepis: väzbu uzavrie k p_date − 1 (Prepísané), novú založí od p_date so stavom, aký OOM malo;
  -- kontaktné osoby starého zákazníka odoberie
oom_reconnect(p_oom_id, p_company_id, p_person_id, p_from)
  -- návrat: nová väzba Pripravované od p_from (po konci predošlej); kroky prechodu a dodávka sa vynulujú
oom_customer_at(p_oom_id, p_date) → (company_id, person_id, status)   -- „komu patrilo k dátumu“ (obrazovka 18)
```

Príklad (zadanie čl. 11, bod 4): Horváth `1. 1. 2025 – 31. 10. 2026 · Prepísané`, Kováčová `od 1. 11. 2026 · Aktívne`.
`oom_customer_at(…, '2026-03-01')` → Horváth; `…'2026-12-01'` → Kováčová.

---

## 3. Výpočet stavu zákazníka (úprava 0004/0008)

### 3.1 `customer_status_calc` – nové pravidlá (zadanie Zákazníci čl. 4 a 14)

Počíta sa zo **všetkých väzieb zákazníka** v `oom_customer` (nie z `oom.status`), takže Horváth po prepise
vidí svoje OOM ako „Prepísané“, hoci OOM samo je „Aktívne“ u Kováčovej.

| Poradie | Stav | Podmienka (zmena oproti 0004 **tučne**) |
| --- | --- | --- |
| 1 | Zákazník | väzba v stave `aktivne` (**predtým aj `neaktivne`**) |
| 2 | Čakajúci zákazník | **väzba `pripravovane`** alebo zmluva podpísaná / čaká na zaradenie / aktívna s budúcou účinnosťou |
| 3 | Ponuka | otvorený deal s odoslanou ponukou (bez zmeny) |
| 4 | Záujemca | otvorený deal (bez zmeny) |
| 5 | Bývalý zákazník | väzba `odidene` |
| 6 | Zrušený zákazník | má väzby a všetky sú `zrusene` / `prepisane` |
| 7 | Marketingový kontakt | inak |

`customer_is_former_calc` (príznak „bývalý“) = má uzavretú väzbu s dôvodom **odchod** (odpoveď 1).
Nové: `customer_is_producer_calc` = má väzbu na OOM typu `vyroba` v stave aktívne alebo pripravované,
alebo deal v pipeline druhu `b2b_vykup` (segment „· výrobca“, zadanie Zákazníci čl. 5).

### 3.2 Priebežný prepočet (zapína sa týmto modulom)

```sql
customer_refresh(p_company_id, p_person_id)   -- SECURITY DEFINER: vidí všetky OOM, deal, zmluvy bez ohľadu na RLS
  -- nastaví status, status_source = 'vypocet', is_former_customer, is_producer; audit so zdrojom 'system'
```

- Volá ho spúšťač **AFTER INSERT/UPDATE/DELETE na `oom_customer`** (stav, zákazník, obdobie) a zmena typu OOM.
  Pri prepise sa prepočítajú obaja zákazníci.
- Zmena stavu zákazníka sa v audite označí ako „Systém“ (vypočítaná zmena), aj keď ju vyvolal používateľ
  zmenou OOM – na karte vidno „Vývoj stavu“ a pri ňom zmenu OOM, ktorá ho spôsobila.
- Dealy a zmluvy (moduly 3–4) zapnú ten istý prepočet vo svojich migráciách.
- Stav prevzatý z HubSpotu (`status_source = 'hubspot'`) sa prepíše výpočtom pri prvej zmene OOM daného
  zákazníka. **Na Teste hneď, na Ostrom sa prepočet zapne až s modulom Zmluvy** (odpoveď 4) – prepínač
  v databáze (`crm_setting`/spúšťač vypnutý na `main`), spresní sa v `0014`.

### 3.3 Pohľady

- **`customer_v`**: počet aktívnych OOM a ročný objem z aktuálnych väzieb v stave `aktivne`; inak bez zmeny.
- **`contact_oom_v`** (osoba ↔ OOM): spojenie dvoch zdrojov, stav `aktivne` alebo `pripravovane`
  (**predtým `neaktivne`**), `security_invoker`:
  - `rucne` – kontaktné osoby pri OOM (`oom_contact`, časť 5),
  - `deal` – osoby na dealoch s OOM (ako dnes; v module 4 pribudne `zmluva`).
- **`oom_v`** (zoznam OOM, obrazovka 17): EIC, názov, adresa, aktuálny zákazník (meno, B2B/B2C), typ, stav,
  PDS, plánovaný objem (spotreba VT+NT alebo výkup), dodávka od – do, vlastník (= vlastník zákazníka),
  spoločnosť, príznak „prechod sa zasekol“, „prepis od“ (meno predošlého zákazníka, iba ak ho používateľ vidí).

Pravidlo v `CLAUDE.md` je upravené (odpoveď 7): kontaktné osoby priamo pri OOM, neskôr automaticky zo zmluvy;
cez dealy iba pri stave Aktívne alebo Pripravované.

---

## 4. Údaje OOM a povinné údaje pre Aktívne

### 4.1 Úprava stĺpcov `oom`

| Stĺpec dnes | Zmena | Dôvod |
| --- | --- | --- |
| `source_type` (virtuálna batéria, lokálny, výrobný, Green VIWA) | → `source_category` enum `maly_zdroj`, `lokalny_zdroj`, `vyrobny_zdroj` | zadanie čl. 7 a 14 (VB a VIWA sú produkty) |
| `segment` | zrušiť | segment patrí zákazníkovi, na OOM sa nepoužíva |
| `previous_supplier_notice`, `previous_supplier_notice_accepted_at` | → kroky prechodu (4.3) | zadanie čl. 8 |
| `pds`, `pds_tariff` (text) | kód z číselníka `pds`, `sadzba_distribucie` | zadanie čl. 6 |
| `voltage_level` (text) | enum `nn`, `vn`, `vvn` | jadro, logika cien |
| `billing_period`, `advance_payment_method`, `feed_in_contract_type`, `metering_type` (text) | kód z číselníka | hodnoty spravuje admin |
| `advance_payment_pct` | + `advance_payment_eur numeric(12,2)` | „spôsob a výška záloh“ – výška môže byť suma |
| `eic` | normalizovaný na veľké písmená bez medzier | kontrola duplicít |
| `phases` | iba 1 alebo 3 | |

### 4.2 Číselníky (`lookup_list`, spravuje admin v Nastaveniach)

Hodnoty podľa použitia v HubSpote, vyčistené Petrom 12. 10. (`exports/modul2-oom/`: `prehlad-hodnot.md`, `pds-zoznam.md`, `matica-pds-sadzba.md`).

| Zoznam | Hodnoty v `0013` |
| --- | --- |
| `pds` | ZSD, SSD, VSD + 14 miestnych DS (zlúčené duplicity); nový stĺpec `lookup_value.reg_no` = IČO (vyplnené iba kde je známe) |
| `sadzba_distribucie` | D1–D8, C1–C10, X2, X3, C2-X3 (iba ZSD), X3-C2 (iba VSD) pri PDS, kde sa použili (47 hodnôt); `lookup_value.parent_code` = PDS, kód `zsd_d3` |
| `fakturacne_obdobie` | Mesačne, Ročne, Ročne s odkladom k termínu odpočtu |
| `sposob_zaloh` | Bez záloh, Splátkový kalendár 11 mesiacov, Splátkový kalendár do konca roka, Štvrťročné zálohy, Mesačné zálohy |
| `typ_merania` | A, B, C, N – nemerané |
| `typ_vykupnej_zmluvy` | 5 hodnôt z HubSpotu |
| `rola_pri_oom` | správca budovy, technik prevádzky, kontaktná osoba |
| `predchadzajuci_dodavatel` | už existuje (0007) |

Enumy: napäťová úroveň `nn`, `vn`, `vvn` (NN, VN, VVN); druh zdroja `source_kind` + `biomasa` (bioplyn a biomasa sú dva zdroje).

Kontrola spúšťačom ako pri rolách kontaktu (`lookup_codes_check`, spoločnosť OOM); sadzba musí patriť zvolenému PDS.
Obrazovka Číselníky (Nastavenia) dostane pri sadzbách výber PDS.

**Zistenie z HubSpotu (iba čítanie, `exports/modul2-oom/`):** PDS, sadzba PDS,
napäťová úroveň, typ merania, fakturačné obdobie, spôsob zálohových faktúr, cenová regulácia a spotrebná daň
sú v HubSpote **voľný text** – zoznam hodnôt v definícii nie je. Výber má iba typ výkupnej zmluvy (5 hodnôt).
Skutočne použité hodnoty by sa dali zistiť iba zo záznamov (zoskupené počty bez osobných údajov) – na to treba tvoj súhlas.

### 4.3 Prechod k Greenlogy (zadanie čl. 8)

```sql
ALTER TABLE oom
  ADD COLUMN previous_supplier         text,     -- kód z číselníka predchadzajuci_dodavatel
  ADD COLUMN switch_notice_required    boolean NOT NULL DEFAULT true,   -- false = nová prípojka, bez výpovede
  ADD COLUMN switch_notice_sent_on     date,     -- 1. výpoveď odoslaná
  ADD COLUMN switch_notice_accepted_on date,     -- 2. výpoveď akceptovaná
  ADD COLUMN switch_confirmed_on       date;     -- 3. zmena dodávateľa potvrdená
  -- 4. začiatok dodávky = supply_from (už existuje)
```

- Kroky musia ísť po poradí (dátum kroku ≥ dátum predošlého); kontrola v databáze.
- **Prechod sa zasekol** (`oom_v.switch_stuck`): OOM je Pripravované a výpoveď je odoslaná bez akceptácie dlhšie
  ako `org.oom_switch_accept_days`, alebo akceptovaná bez potvrdenia zmeny dlhšie ako `org.oom_switch_confirm_days`.
  Východisko 14 + 14 dní, **mení admin v Nastaveniach pri spoločnosti** (odpoveď 3; obrazovka 11).
- Pri návrate bývalého OOM sa kroky prepíšu novými dátumami; predošlé ostávajú v audite a na časovej osi.
- Tabuľka `supplier_switch` (správy XML433 / XML43D) ostáva bez zmeny pre neskorší krok s OKTE.

### 4.4 Pripravované → Aktívne (automaticky)

Zadanie čl. 4 a 14: stačí „zmena dodávateľa potvrdená“ a dátum začiatku dodávky.

```sql
oom_activate_due(p_today date) → integer   -- aktivuje všetky Pripravované OOM so switch_confirmed_on
                                           --   a supply_from <= p_today, ktoré majú povinné údaje
```

- Volá ju **raz denne Cloudflare Cron Trigger** na Workeri (odpoveď 6). Cron beží v UTC, preto dva časy
  (22:05 a 23:05 UTC = 0:05 v zime aj v lete); funkcia počíta s dátumom v Europe/Bratislava a druhé spustenie
  nič nezmení. Tiež hneď pri uložení OOM, ak je dátum už v minulosti. Audit: zdroj „Systém“.
- OOM bez povinných údajov sa neaktivuje – ostane Pripravované so značkou „chýbajú údaje“ v zozname.

### 4.5 Povinné pre Aktívne (zadanie čl. 6)

Kontrola v databáze **iba pri prechode do stavu Aktívne** (staršie záznamy sa tým neblokujú):
EIC, typ, adresa (ulica alebo obec, PSČ), PDS, napäťová úroveň, sadzba, dodávka od;
pri spotrebe plánovaná spotreba (VT alebo NT), pri výrobe plánovaný výkup.
Výnimka: rola `crm_sync` (nahrávanie z HubSpotu – chýbajúce údaje rieši kontrolná tabuľka).
Sharing ako spotreba (plánovaná spotreba povinná; uzavretá otázka 5). Typ veľkoobchod sa ruší (časť 1).

### 4.6 Kontrola EIC

```sql
eic_is_valid(text) → boolean   -- IMMUTABLE: 16 znakov [0-9A-Z-], kontrolná číslica podľa ENTSO-E
ALTER TABLE oom ADD CONSTRAINT oom_eic_check CHECK (eic_is_valid(eic));
```

- Algoritmus ENTSO-E je spoločný pre SK (`24…`), CZ (`27…`) aj HR (`31…`) – netreba čakať na pobočky.
  Predčíslie krajiny podľa spoločnosti (SK OOM začína `24`) kontroluje API ako upozornenie.
- EIC sa pred uložením normalizuje (veľké písmená, bez medzier). Unikátnosť v celej skupine už platí.
- Kontrola duplicity pre „iba svoje“: funkcia `oom_eic_check(eic)` vráti iba „OOM už existuje“ a meno vlastníka,
  rovnako ako pri IČO (zadanie Zákazníci čl. 7, príklad 7 v module 2).

---

## 5. Kontaktné osoby pri OOM (`oom_contact`)

```sql
CREATE TYPE oom_contact_source AS ENUM ('rucne', 'zmluva');

CREATE TABLE oom_contact (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id      uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
  contact_id  uuid NOT NULL REFERENCES contact (id),
  roles       text[] NOT NULL DEFAULT '{}',    -- kódy z číselníka (otázka 4)
  source      oom_contact_source NOT NULL DEFAULT 'rucne',
  created_at, updated_at,
  UNIQUE (oom_id, contact_id)
);
```

- Osoba musí byť z firmy zákazníka (`company_contact`), pri domácnosti osoba tej istej spoločnosti.
- `zmluva` = prenesené automaticky v module 4; ručne pridaná osoba (`rucne`) sa pri zmene zmluvy neodoberie (zadanie čl. 5).
- Pri prepise sa kontaktné osoby starého zákazníka odoberú (patria jeho firme).

---

## 6. Spoločnosť na OOM

Stĺpec `oom.org_id` a kontrola „rovnaká spoločnosť ako zákazník“ sú hotové v `0008`. Doplní sa:
- `oom_customer.org_id` = `oom.org_id`; prepis na zákazníka inej spoločnosti → chyba,
- `oom_contact`: osoba z tej istej spoločnosti,
- číselníky (PDS, sadzby…) sa kontrolujú voči spoločnosti OOM (hodnota celej skupiny alebo tej spoločnosti),
- zoznam OOM: filter a stĺpec Spoločnosť iba pre tímy so všetkými spoločnosťami (ako Zákazníci, F4),
- `customer_org_guard` (0008) už bráni zmeniť spoločnosť zákazníka, ktorý má OOM – doplní sa `oom_customer`.

---

## 7. Obmedzenie „iba svoje“ v databáze (RLS)

Dnes `oom` RLS **nemá** a rola `crm_app` ho číta celé. Preto je externý tím zamknutý (`crm_external_ready() = false`).

### 7.1 Pravidlo
OOM preberá vlastníka zákazníka (zadanie čl. 10). Politika číta nastavenie tímu pre modul `odberne_miesta`:

```sql
-- Prístup k OOM: spoločnosť + rozsah tímu; „iba svoje“ = vlastním aktuálneho zákazníka OOM
CREATE FUNCTION crm_oom_access(p_oom_id uuid, p_action text) RETURNS boolean   -- SECURITY DEFINER, STABLE

CREATE POLICY oom_select ON oom FOR SELECT USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('odberne_miesta', 'view')) = 'vsetko'
       OR ((SELECT crm_scope('odberne_miesta', 'view')) = 'iba_svoje'
           AND crm_customer_owned(company_id, person_id))));   -- vlastník firmy / domácnosti = ja
CREATE POLICY oom_insert … WITH CHECK ( …'edit'… );
CREATE POLICY oom_update … USING ( …'edit'… ) WITH CHECK ( …'edit'… );
-- DELETE: bez politiky (pozri 7.3)
```

- **`oom_customer`**: riadok vidí, kto vidí zákazníka tej väzby (`crm_company_access` / `crm_contact_access`).
  Obchodník starého zákazníka tak na karte svojho zákazníka vidí „EIC, obdobie, Prepísané“, ale nie nového
  odberateľa. Zápis iba cez funkcie z časti 2.
- **`oom_device`, `oom_contact`**: podľa `crm_oom_access(oom_id, …)`.
- **`oom_v`, `contact_oom_v`, `customer_v`**: `security_invoker` – politiky platia automaticky.
- **Hľadanie podľa EIC** (príklad 7): cudzie OOM databáza nevráti; `oom_eic_check` povie iba „existuje“.
- Pravidlo „Aktívne OOM upravujú iba Servis a Nákup, interný obchodník iba Pripravované“ (odpoveď 2) kontroluje API,
  ako stĺpcové práva pri Zákazníkoch (databáza pozná rozsah tímu, nie stav, ktorý tím smie meniť).

### 7.2 Východiskové práva modulu Odberné miesta (zmena matice z 0006)

| Tím | Vidí | Upravuje | Import |
| --- | --- | --- | --- |
| CEO | všetko | všetko | áno |
| Sales_internal | všetko | **všetko** (dnes nič) – zakladá OOM, upravuje **iba Pripravované** (API) | nie |
| Sales_external | iba svoje | **iba svoje** (dnes nič) – zakladá a upravuje OOM svojich zákazníkov | nie |
| Servis | všetko | **všetko** (dnes nič) | áno |
| Nákup | všetko | všetko | áno |
| Marketing | všetko | nič | nie |

### 7.3 Mazanie OOM
Ako pri Zákazníkoch (0011): admin smie zmazať OOM **bez väzieb** (deal, zmluva, cena, aktivita, konverzácia)
funkciou `oom_delete(id)`; audit zapíše celý obsah. Inak sa OOM nemaže (stav Zrušené).

### 7.4 Externý tím
`crm_external_ready()` ostáva `false`, kým politiky nebudú mať aj dealy, zmluvy, ponuky a aktivity (moduly 3–4).
Po `0015` bude chránené OOM, ale externý tím sa stále nedá obsadiť – tak to určuje rozhodnutie 2026-10-12.

---

## 8. Audit

- `oom`, `oom_device` už audit majú; pribudne na `oom_customer`, `oom_contact`, `oom_import`.
- Časová os karty OOM (obrazovka 18) sa skladá z auditu: založenie, zmena stavu, prepis (väzby), zmena údajov
  (stará → nová hodnota), kroky prechodu, zariadenia, kontaktné osoby; pri každej položke kto a zdroj
  („Systém“ pri automatickej aktivácii, „import z Excelu“ pri importe).
- Audit zákazníka zapíše vypočítanú zmenu stavu so zdrojom „Systém“ (časť 3.2).
- Nová hodnota zdroja auditu `import` a stĺpec `audit_log.import_id` → zmeny z importu sa dajú spätne
  dohľadať po súboroch (obrazovka 16 dostane filter „import“).
- Osobné údaje v audite: ako doteraz (audit nie je log aplikácie, je v databáze v EÚ, iba pre admina).

---

## 9. Import z Excelu (obrazovka 19)

### 9.1 Databáza

```sql
CREATE TYPE oom_import_status AS ENUM ('ulozeny', 'zlyhal');

CREATE TABLE oom_import (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id         uuid NOT NULL REFERENCES org (id),
  user_id        uuid NOT NULL REFERENCES app_user (id),
  file_name      text NOT NULL,
  row_count      integer NOT NULL,
  created_count  integer NOT NULL,
  updated_count  integer NOT NULL,
  error_count    integer NOT NULL,      -- riadky s chybou, ktoré sa neuložili
  status         oom_import_status NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE team_permission ADD COLUMN can_import boolean NOT NULL DEFAULT false;   -- CEO, Servis, Nákup pri OOM
```

- **Náhľad sa v databáze neukladá.** API súbor prečíta, overí a vráti náhľad; pri „Uložiť“ ho pošle znova,
  API ho overí ešte raz a uloží platné riadky **v jednej transakcii** (všetko alebo nič) so `SET LOCAL app.import_id`.
  Do databázy tak nejde nič, čo používateľ nepotvrdil, a netreba upratovať rozpracované importy s osobnými údajmi.
- Samotný súbor sa neukladá (iba názov a počty).
- Právo „importovať“ je nový stĺpec matice práv (obrazovka 13), nie pevný zoznam tímov v kóde.

### 9.2 Pravidlá importu (API, na schválenie)
- Párovanie podľa EIC: existuje → zmena (náhľad: stará → nová hodnota), neexistuje → nové OOM.
- Zákazník v riadku: firma podľa IČO, domácnosť podľa e-mailu; musí existovať v tej istej spoločnosti.
  Import **nezakladá zákazníkov** a **nemení zákazníka ani stav** existujúceho OOM (to je prepis / zmena stavu).
- Kontroly: formát a kontrolná číslica EIC, duplicita EIC v súbore, povinné údaje, zákazník, číselníky (PDS, sadzba k PDS).
- Nové OOM z importu má stav Pripravované (Aktívne až po krokoch prechodu) – uzavretá otázka 7.
- Šablóna .xlsx: stĺpce jadra + vlastné polia OOM; EIC, IČO a PSČ ako text.
- Čítanie .xlsx v API bez knižnice (rozbalenie cez `DecompressionStream`), rovnako ako zápis exportu.

---

## 10. Vlastné polia OOM

Databáza je hotová z `0007`: `oom.custom jsonb`, kontrola typu a práv na úpravu (`custom_values_check('oom')`),
audit po poliach, GIN index. V module 2 sa doplní iba API a obrazovky: sekcie na karte OOM, stĺpce a filtre
v zozname OOM (ako Zákazníci F3), stĺpce v šablóne importu. Nová migrácia kvôli vlastným poliam netreba.

---

## 11. Rozhodnuté (12. 10. 2026)

**Peter:**
1. **Väzba:** odchod a zrušenie väzbu uzavrú (dátum do + dôvod); nová väzba vzniká pri prepise aj pri návrate
   na to isté EIC. Príznak „bývalý“ sa odvodí z uzavretých väzieb s dôvodom odchod.
2. **Práva:** externý obchodník zakladá a upravuje OOM svojich zákazníkov (tím ostáva zamknutý, kým nebudú mať
   RLS dealy a zmluvy). Interný obchodník zakladá OOM a upravuje ich iba v stave Pripravované; Aktívne OOM
   upravujú Servis a Nákup.
3. **Prechod sa zasekol:** 14 + 14 dní ako východisko, nastaviteľné adminom v Nastaveniach.
4. **Prepočet stavu na Ostrom** až s modulom Zmluvy.
5. **Číselníky:** zoznamy hodnôt vlastností OOM z HubSpotu iba na čítanie (definície) → `exports/modul2-oom/`, súhrn na kontrolu.
6. **Denná aktivácia** cez Cron: súhlas v princípe; čas v Europe/Bratislava, audit „Systém“.
7. **Pravidlo kontakt ↔ OOM** v `CLAUDE.md` upravené.

**Claude podľa odporúčaní (Peter sa ozve, ak nesúhlasí):**
8. **Roly pri OOM:** nový číselník `rola_pri_oom` (správca budovy, technik prevádzky, kontaktná osoba), nie roly vo firme.
9. **Povinné pre Aktívne:** sharing ako spotreba.
12. **Typ veľkoobchod sa ruší** (Peter): virtuálne OOM bez EIC; veľkoobchod = položky zmluvy bez OOM (moduly 4, 5); pri nahrávaní sa 13 virtuálnych OOM neprenesie.
10. **Import:** nové OOM vždy Pripravované; import nemení zákazníka ani stav.
11. **Fakturačné číselníky:** východiskové hodnoty z časti 4.2; admin ich upraví v Nastaveniach.

## 12. Čo bude treba od teba (iba zoznam, nič nemením)

**Rozhodnutia a údaje**
1. ~~Odpovede na otázky v časti 11~~ (hotové).
2. Hodnoty číselníkov: miestne distribučné sústavy a sadzby podľa PDS – v HubSpote sú voľný text; buď súhlas
   so zistením použitých hodnôt zo záznamov (iba zoskupené počty), alebo zoznam od teba.
3. ~~Súhlas s úpravou pravidla v `CLAUDE.md`~~ (hotové).

**Neon**
4. Súhlas so spustením migrácií `0013`–`0015` na `dev` (každá zvlášť, po kontrole); `main` až po schválení.
5. Po migráciách spustiť znova `api/db/app-role.sql` (práva `crm_app` na nové tabuľky; mazanie iba `oom_contact`).

**Cloudflare**
6. Súhlas s Cron Triggerom vo `wrangler.toml` (denná aktivácia OOM) a nasadenie Workera na Test.

**Test**
7. Testovacie scenáre po fázach (ako pri Zákazníkoch): nová domácnosť → Pripravované → Aktívne, zaseknutý prechod,
   firma s FVE (segment výrobca), prepis Horváth → Kováčová a časový rez, odchod (Bývalý), import 50 OOM s chybami,
   externý obchodník vidí iba svoje OOM (s dočasnou testovacou rolou v `db/test`, keďže externý tím je zamknutý).
