# Modul 3 – Produkty a cenníky: návrh databázy

Verzia 0.3 · 13. 10. 2026 · **schválené Petrom** (v0.1 = návrh; v0.2 = odpovede 1–13, výslovný rozsah PDS
v párovaní, cenová regulácia s prázdnou hodnotou, skrytie ZSD C1, export iba schválených verzií, inventár z HubSpotu;
v0.3 = plán `0019` schválený so zmenami: typ tarifu je vlastnosť produktu, kód modulu 2 sa nasadí spolu s `0019`).
Implementácia: `0019_produkty` na `dev` (13. 10., Peter otestoval na Teste). `0020_cenniky` na `dev` (13. 10.)
(plán schválený so zmenami: „dnes“ v Europe/Bratislava, minulý dátum pri schválení iba vlastník databázy – časť 4).
Vychádza zo zadania `03-produkty.md` v0.3, odpovedí `03-produkty-otazky.md` (verzia 2), obrazoviek 20–24,
`docs/rozhodnutia.md`, migrácií `0001`–`0018` a cenníkov 2026 (PDF v `exports/cenniky-2026/`).

SQL v tomto dokumente je **náčrt**, nie migrácia. Presné migrácie sa napíšu až po schválení.
Nič sa nespúšťa, databáza sa nemení.

---

## 0. Východisko a poradie migrácií

**Čo už v databáze je:**
- tabuľka `product` (0001): `code` (unikátny), `name`, `kind` (`dodavka`, `vykup`, `sluzba`, `poplatok`),
  jeden `pricing_model` (`fix`, `spot_aditiv`, `index_spot`), `unit`, `list_price`, `valid_from`/`valid_to`,
  `hubspot_product_id`, `hubspot_contract_codes`; audit áno, RLS nie. Odkazujú naň `contract_price`, `offer_item`, `commission_rule`.
- `contract_price` (0001): kópie zložiek ceny (VT, NT, aditív, poplatky), **bez odkazu na cenník**;
  poplatky v `numeric(12,2)`.
- číselníky `pds` a `sadzba_distribucie` (0013): sadzba patrí PDS, kód vzniká z PDS a názvu (`zsd_c2_x3`),
  sú v ňom iba sadzby použité v HubSpote (47 hodnôt, bez C11).
- `oom.price_regulation` – **voľný text** (0001), v API, formulári, importe aj exporte modulu 2 ako text do 80 znakov.
- `oom.source_power_kw` (výkon zdroja – pre VIWA), `oom.planned_consumption_nt_mwh` (pomôcka dvojtarif).
- `btree_gist` (0013), `crm_today()`, `crm_is_admin()`, `crm_user_orgs()`, `crm_session_ok()`.

**Čo chýba:** cenníky a verzie, položky, parametre programov, párovanie produkt ↔ sadzba, ochrana schválenej verzie,
RLS, cenová regulácia ako ANO/NIE, sadzba C11.

| Migrácia | Obsah | Časť |
| --- | --- | --- |
| `0019_produkty` | prerobenie `product` (kategória, segment, DPH, cenové modely, cenová regulácia, stav, spoločnosť), zákaz mazania, rozsahy PDS `tariff_scope`, párovanie `product_tariff`, funkcia `product_candidates`, C11 a ďalšie sadzby do číselníka, skrytie ZSD C1, `oom.price_regulation` → ANO/NIE/prázdne (aj import), RLS, audit | 1, 2, 5, 8, 9 |
| `0020_cenniky` | `price_list`, `price_list_version`, `price_list_item`, `price_list_item_program`, ochrana schválenej verzie, funkcie kópia / schválenie / ukončenie, pohľad `price_list_version_v`, RLS, audit | 3, 4, 6, 9 |
| skript `db/seed/cenniky-2026.sh` | produkty, párovanie a cenníky 2026 – **dáta, nie migrácia**, najprv iba `dev` | 10 |

Predpoklad: `product`, `contract_price`, `offer_item`, `commission_rule` sú na Teste prázdne. Migrácia `0019` to overí
a inak skončí chybou (stĺpce produktu sa rušia).

---

## 1. Produkt (`product`, úprava)

```sql
CREATE TYPE product_category AS ENUM (
  'dodavka_domacnost',    -- Green DD1–DD8 ANO / NIE Energopomoc
  'dodavka_maly_podnik',  -- Green DMP1–DMP11
  'dodavka_firma',        -- Dodávka B2B
  'vykup_firma',          -- Výkup B2B
  'velkoobchod',          -- Veľkoobchod (položky zmluvy bez OOM, modul 4)
  'zem',                  -- služba ZEM
  'vbattery',             -- VBattery STANDARD, PREMIUM, MAX, AKU
  'viwa',                 -- Green VIWA Basic, Plus, Pro
  'instalacia_fve',       -- Green Solar – zmluva o dielo
  'poplatok'              -- Mesačná platba za OM – firmy (odpoveď 6)
);
CREATE TYPE price_model AS ENUM (
  'cennik', 'fix', 'spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct',
  'cena_diela'            -- Green Solar (odpoveď 10)
);
CREATE TYPE product_status AS ENUM ('predava_sa', 'dobieha', 'ukonceny');

ALTER TABLE product
  DROP COLUMN kind, DROP COLUMN pricing_model, DROP COLUMN unit,
  DROP COLUMN list_price, DROP COLUMN valid_from, DROP COLUMN valid_to,   -- ceny a platnosť sú v cenníku
  ADD COLUMN org_id           uuid NOT NULL REFERENCES org (id),          -- otázka 1
  ADD COLUMN category         product_category NOT NULL,
  ADD COLUMN segment          customer_segment NOT NULL CHECK (segment IN ('domacnost', 'firma')),
  ADD COLUMN vat_rate         numeric(5,2) CHECK (vat_rate BETWEEN 0 AND 100),   -- 19.00 / 23.00; NULL iba inštalácia FVE
  ADD COLUMN tariff_type      tariff_type NOT NULL DEFAULT 'netyka_sa',           -- jednotarif / dvojtarif / nemerany / netyka_sa
  ADD COLUMN price_models     price_model[] NOT NULL CHECK (cardinality(price_models) >= 1),
  ADD COLUMN price_regulation boolean,      -- NULL = nezáleží; true = ANO (energopomoc / malé podniky), false = NIE
  ADD COLUMN status           product_status NOT NULL DEFAULT 'predava_sa',
  ADD COLUMN sort_order       integer NOT NULL DEFAULT 0;
DROP TYPE pricing_model, product_kind, product_unit;
```

**Pravidlá (kontrola v databáze):**
- **Produkt sa nikdy nemaže** – spúšťač `BEFORE DELETE` vždy vyhodí chybu (pre každú rolu); `crm_app` nemá právo DELETE.
  Koniec predaja = stav Dobieha alebo Ukončený.
- `code` sa po založení nemení (odkazuje naň skript naplnenia a mapovanie z HubSpotu).
- `vat_rate` je povinná okrem kategórie `instalacia_fve` (DPH podľa diela, `fve_project.vat_rate`).
- `price_models`: FIX a SPOT sú dva modely; kombinácia na jednej cene sa nerieši tu, ale v module 4 (cena má práve jeden model).
- Stavy: **Predáva sa** → nové zmluvy áno; **Dobieha** → existujúce zmluvy bežia, nové nie (modul 4), môže byť v cenníku
  (zmluvy prejdú na novú cenu); **Ukončený** → nesmie byť v novom návrhu cenníka.
- Zmena DPH, cenovej regulácie alebo stavu je v audite; DPH už schválených cien chráni kópia v položke (časť 3.3).
- `hubspot_product_id`, `hubspot_contract_codes` ostávajú pre mapovanie z HubSpotu (časť 11).

**Skupiny na obrazovke 22** (Dodávka / Výkup / Služby a programy / Inštalácia) sa odvodia z kategórie, netreba stĺpec.
**Typ tarifu je vlastnosť produktu** (Peter, v0.3), nie odvodenina z cenníka: DD1–DD2, DMP1–DMP3, DMP10, DMP11 jednotarif;
DD3–DD8, DMP4–DMP8 dvojtarif; DMP9 nemeraný; ostatné netýka sa. Hodnoty nastaví skript naplnenia (časť 10).

---

## 2. Párovanie produkt ↔ sadzba distribúcie (`product_tariff`, obrazovka 24)

Zadanie čl. 5: ZSD a VSD majú vlastné pravidlá, **SSD a miestne DS spoločné**. Sadzby v číselníku sú po PDS
(`zsd_c2_x3`, `ssd_c4`), ale párovanie hovorí o sadzbe ako takej (C4). Preto párovanie ukladá **kód sadzby bez PDS**
(`c4`, `c2_x3`) – časť kódu za PDS, ktorá sa nemení ani pri premenovaní hodnoty v číselníku.

**Rozsah PDS je uložený výslovne** (Peter, doplnok v0.2), nie ako implicitné pravidlo:

```sql
CREATE TABLE tariff_scope (
  code        text PRIMARY KEY CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'),   -- 'zsd', 'vsd', 'spolocne'
  name        text NOT NULL,             -- 'ZSD', 'VSD', 'SSD a miestne DS'
  pds_code    text UNIQUE,               -- PDS s vlastným párovaním; NULL = spoločný rozsah
  sort_order  integer NOT NULL DEFAULT 0,
  created_at, updated_at
);
CREATE UNIQUE INDEX tariff_scope_one_common ON tariff_scope ((true)) WHERE pds_code IS NULL;  -- práve jeden spoločný

CREATE TABLE product_tariff (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   uuid NOT NULL REFERENCES product (id),
  scope_code   text NOT NULL REFERENCES tariff_scope (code),   -- 'zsd', 'vsd', 'spolocne'
  tariff_code  text NOT NULL,                                  -- kód sadzby bez PDS: 'd3', 'c9', 'c2_x3'
  created_at, updated_at,
  UNIQUE (product_id, scope_code, tariff_code)
);

tariff_base(p_code text, p_parent text) → text   -- IMMUTABLE: 'zsd_c2_x3', 'zsd' → 'c2_x3'
oom_tariff_scope(p_pds text) → text              -- rozsah PDS: vlastný riadok tariff_scope, inak 'spolocne'
```

Migrácia založí rozsahy `zsd` (ZSD), `vsd` (VSD), `spolocne` (SSD a miestne DS). Nový PDS s vlastným párovaním
= nový riadok `tariff_scope` (admin).

**Pravidlo výberu** pre OOM s PDS `p` a sadzbou `t`: rozsah `s = oom_tariff_scope(p)`; produkt pasuje, ak má riadok
`(s, t)`. **PDS s vlastným rozsahom (ZSD, VSD) používa iba svoje riadky – spoločné riadky sa preň nepoužijú nikdy**,
ani pre sadzbu, ktorú vo vlastnom rozsahu nemá.

| Produkt | ZSD | VSD | spoločné |
| --- | --- | --- | --- |
| Green DD1–DD8 (ANO aj NIE) | d1–d8 | d1–d8 | d1–d8 |
| ZEM | d1–d8 | d1–d8 | d1–d8 |
| Green DMP1–DMP8 | c2_x3 | x3_c2 | c1–c8 |
| Green DMP9 | c9 | c9 | c9 |
| Green DMP10 | c2_x3 | x3_c2 | c10 |
| Green DMP11 | c11 | c11 | c11 |
| Dodávka B2B, Výkup, VBattery, VIWA… | – | – | – (produkt sa neviaže na sadzbu) |

Spolu 16×3 (DD) + 8×3 (ZEM) + 8×3 (DMP1–8) + 3×3 (DMP9–11) = **105 riadkov**.

**Kontroly:** `tariff_code` existuje ako **neskrytá** sadzba pri PDS rozsahu (pri spoločnom rozsahu aspoň pri jednom
PDS bez vlastného rozsahu). Preto treba do číselníka doplniť C11 a ďalšie sadzby (časť 8.1).

**Návrh produktov pre OOM** (funkcia, `STABLE`, práva volajúceho):

```sql
product_candidates(p_oom_id uuid)
  RETURNS TABLE (product_id uuid, rank smallint, is_only boolean, is_addon boolean)
```
- iba produkty v stave Predáva sa, segment = druh zákazníka OOM (domácnosť / firma),
- cenová regulácia: produkt NULL pasuje vždy; inak sa musí rovnať regulácii OOM; **OOM s nevyplnenou reguláciou**
  dostane produkty ANO aj NIE a vyberá obchodník (Peter, odpoveď 8); pri firme s nevyplnenou reguláciou rovnako,
  CRM pri DMP upozorní (zadanie čl. 8),
- párovanie podľa pravidla vyššie; ZEM sa vracia ako doplnková položka pri domácnosti,
- `rank`: ak má OOM plánovanú spotrebu NT > 0, najprv dvojtarifné produkty (`tariff_type`), inak ostatné (už v `0019`),
- `is_only = true`, keď ostane jediný produkt dodávky → CRM ho vyplní samo; inak vyberá obchodník.

Kontrola na príkladoch: príklad 1 (D2, ZSD, NIE) → DD2 – NIE, ZEM; príklad 4 (SSD C2, C10, C11, ANO) →
DMP2, DMP10, DMP11, každý `is_only`; príklad 8 (ZSD C2-X3, NT 4 MWh) → DMP4–DMP8 rank 1, DMP1–3 a DMP10 rank 2.

Párovanie a rozsahy mení iba admin (časť 9); obrazovka 24 zobrazuje stĺpce podľa `tariff_scope`.

---

## 3. Cenník, verzia, položka

### 3.1 Cenník (`price_list`)

```sql
CREATE TABLE price_list (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES org (id),
  code        text NOT NULL UNIQUE,        -- 'domacnosti_nie_energopomoc'; nemení sa
  name        text NOT NULL,               -- 'Domácnosti – NIE Energopomoc'
  segment     customer_segment NOT NULL CHECK (segment IN ('domacnost', 'firma')),
  description text,
  sort_order  integer NOT NULL DEFAULT 0,
  created_at, updated_at
);
```
Cenník sa nemaže (ako produkt); bez schválenej verzie ho admin zmazať smie (omylom založený).

### 3.2 Verzia (`price_list_version`)

```sql
CREATE TYPE price_list_version_status AS ENUM ('navrh', 'schvalena', 'nahradena');

CREATE TABLE price_list_version (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id   uuid NOT NULL REFERENCES price_list (id),
  name            text NOT NULL,                  -- '2026'
  valid_from      date NOT NULL,
  valid_to        date,                           -- NULL = do ďalšej verzie
  status          price_list_version_status NOT NULL DEFAULT 'navrh',
  copied_from_id  uuid REFERENCES price_list_version (id),
  note            text,
  approved_at     timestamptz,
  approved_by     uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (price_list_id, name),
  CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CHECK ((status = 'navrh') = (approved_at IS NULL)),
  -- schválené verzie jedného cenníka sa neprekrývajú
  EXCLUDE USING gist (price_list_id WITH =, daterange(valid_from, valid_to, '[]') WITH &&)
    WHERE (status = 'schvalena')
);
CREATE UNIQUE INDEX price_list_version_one_draft ON price_list_version (price_list_id) WHERE status = 'navrh';  -- otázka 4
```

**Stavy (odpoveď 2):** uložené sú iba tie, ktoré mení človek – Návrh, Schválená, a Nahradená (schválená budúca verzia,
ktorú pred účinnosťou nahradila opravená verzia s rovnakým dátumom). Ako sa verzia zobrazí, závisí od dátumu
a počíta sa v pohľade `price_list_version_v.state`:

| `state` | Podmienka |
| --- | --- |
| Návrh | `status = 'navrh'` |
| Budúca | schválená, `valid_from > dnes` |
| Platná | schválená, `valid_from <= dnes <= coalesce(valid_to, ∞)` |
| Ukončená | schválená s `valid_to < dnes`, alebo nahradená |

Takto stav „ukončená“ nemusí meniť nočný beh a nemôže sa rozísť s dátumom.

### 3.3 Položka (`price_list_item`)

```sql
CREATE TABLE price_list_item (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id             uuid NOT NULL REFERENCES price_list_version (id) ON DELETE CASCADE,
  product_id             uuid NOT NULL REFERENCES product (id),
  price_vt_eur_mwh       numeric(12,4) CHECK (price_vt_eur_mwh >= 0),   -- VT / jednotarif
  price_nt_eur_mwh       numeric(12,4) CHECK (price_nt_eur_mwh >= 0),
  fee_oom_eur_month      numeric(12,4) CHECK (fee_oom_eur_month >= 0),  -- mesačná platba za OM (aj ZEM, poplatok B2B)
  fee_program_eur_month  numeric(12,4) CHECK (fee_program_eur_month >= 0), -- mesačný poplatok programu (VBattery, VIWA za OOM)
  fee_kw_eur_month       numeric(12,4) CHECK (fee_kw_eur_month >= 0),   -- VIWA: poplatok za odchýlku za kW výkonu mesačne
  vat_rate               numeric(5,2),          -- kópia DPH produktu, vyplní schválenie (odpoveď 7)
  sort_order             integer NOT NULL DEFAULT 0,
  created_at, updated_at,
  UNIQUE (version_id, product_id),
  CHECK (num_nonnulls(price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                      fee_program_eur_month, fee_kw_eur_month) >= 1),
  CHECK (price_nt_eur_mwh IS NULL OR price_vt_eur_mwh IS NOT NULL)
);
```
- **Ceny bez DPH, 4 desatinné miesta** – aj mesačné poplatky (VBattery 1,4634 €). Odchýlka od konvencie
  „peniaze v `numeric(12,2)`“ v `CLAUDE.md` – zapíše sa do `rozhodnutia.md`.
- Produkt položky musí mať model `cennik` a nesmie byť Ukončený (pri vkladaní do návrhu).
- Jeden produkt môže byť v dvoch cenníkoch naraz (ZEM v ANO aj NIE). Zmluva odkazuje na konkrétnu položku, nie na produkt.
- **Cena s DPH sa neukladá**, počíta ju funkcia (rovnaké výsledky ako v PDF):

```sql
price_with_vat(p_net numeric, p_vat numeric, p_scale int) → numeric   -- IMMUTABLE, round(p_net * (1 + p_vat/100), p_scale)
-- €/MWh na 4 miesta: 120,7275 × 1,19 = 143,6657;  mesačne na 2 miesta: 1,50 × 1,19 = 1,79;  1,4634 × 1,23 = 1,80
```

### 3.4 Parametre programov (`price_list_item_program`)

Parametre VBattery a VIWA sú **súčasť položky cenníka**, takže sa menia iba novou verziou a zmluva si ich vie
skopírovať (odpoveď 11). Typované stĺpce, nie JSON – kontrola rozsahov v databáze.

```sql
CREATE TABLE price_list_item_program (
  item_id                   uuid PRIMARY KEY REFERENCES price_list_item (id) ON DELETE CASCADE,
  greencar                  boolean NOT NULL DEFAULT false,
  greencar_kwh_per_voucher  integer CHECK (greencar_kwh_per_voucher > 0),   -- VBattery: 400 / 300 kWh
  greencar_voucher_eur      numeric(12,2),                                  -- VBattery: 25 €
  greenshare                boolean NOT NULL DEFAULT false,
  greenshare_fee_pct        numeric(5,2),       -- VBattery: 7,5 / 5 % z prevedených kWh (platí sa v kWh)
  viwa_conversion_factor    numeric(5,4) CHECK (viwa_conversion_factor BETWEEN 0 AND 1),  -- SPOT × 0,75 / 0,80 / 0,85
  viwa_activation_bonus     integer,            -- GreenCredit: 25 / 50 / 75
  viwa_credit_expiry_months smallint,           -- 12 / 24 / 24
  created_at, updated_at
);
```
- Riadok smie mať iba položka produktu kategórie `vbattery` alebo `viwa`; stĺpce `viwa_*` iba pri VIWA (spúšťač).
- Poplatok za odchýlku VIWA (€/kW) je cena, preto je v položke (`fee_kw_eur_month`), nie tu.

| Položka | fee_program | fee_kw | greencar | greenshare | VIWA |
| --- | --- | --- | --- | --- | --- |
| VBattery STANDARD | 1,4634 | – | nie | nie | – |
| VBattery PREMIUM | 3,9024 | – | 400 kWh → 25 € | 7,5 % | – |
| VBattery MAX | 7,7480 | – | 300 kWh → 25 € | 5 % | – |
| VIWA Basic | 3,9000 | 0,2500 | nie | áno | 0,75 · 25 · 12 mes. |
| VIWA Plus | 6,9000 | 0,2000 | áno | áno | 0,80 · 50 · 24 mes. |
| VIWA Pro | 9,9000 | 0,1500 | áno | áno | 0,85 · 75 · 24 mes. |

---

## 4. Schválená verzia sa nedá zmeniť (kontrola v databáze)

Ochrana platí **pre každú rolu** (aj vlastníka databázy a `crm_sync`), nielen pre API:

| Tabuľka | Spúšťač `BEFORE INSERT/UPDATE/DELETE` |
| --- | --- |
| `price_list_item`, `price_list_item_program` | ak verzia nie je Návrh → chyba „Schválený cenník sa nedá meniť. Vytvor novú verziu.“ |
| `price_list_version` | Návrh: všetko povolené. Schválená: povolené **iba** (a) nastavenie `valid_to` z prázdneho alebo neskoršieho na dátum ≥ včera (uzavretie nasledujúcou verziou alebo ukončenie cenníka), (b) zmena stavu na Nahradená, ak verzia ešte nezačala platiť. Nič iné, ani mazanie. Nahradená: nič. |

**Dnes** = dátum v Europe/Bratislava (`crm_today()`, `crm_local_date(čas)`; 23:30 UTC v októbri je už nasledujúci deň) –
pri schválení, ukončení, „platná do od včera“ aj pri stavoch Budúca / Platná / Ukončená (Peter, plán 0020).
**Minulý dátum pri schválení** smie iba vlastník databázy (skript naplnenia): `crm_owner_session()` = prihlásený vlastník
tabuliek bez `SET ROLE` a nie spojenie aplikácie; rola `crm_app` nikdy, ani bez `app.user_id` (Peter, plán 0020).
Parametre programu majú vlastné `id` (audit) a unikátne `item_id`.

Navyše `crm_app` má na `price_list_version` právo UPDATE iba na stĺpce `name`, `valid_from`, `note`
(oprávnenie po stĺpcoch). Stav, schválenie a `valid_to` mení iba funkcia nižšie (`SECURITY DEFINER`, kontroluje admina).

**Funkcie (jedna transakcia, audit):**

```sql
price_list_version_copy(p_source_id uuid, p_name text, p_valid_from date) → uuid
  -- nový Návrh s kópiou položiek a parametrov programov; copied_from_id; ukončené produkty vynechá a vráti ich v hlásení
price_list_version_approve(p_id uuid) → void
  -- iba admin; Návrh musí mať aspoň jednu položku;
  -- valid_from >= dnes (otázka 3; výnimka iba spojenie bez používateľa = skript naplnenia);
  -- vyplní vat_rate položiek z produktov;
  -- predošlá schválená verzia: valid_to = nový valid_from − 1;
  -- schválená verzia s rovnakým valid_from, ktorá ešte neplatí → Nahradená (oprava budúceho cenníka);
  -- ak existuje neskoršia schválená verzia, nová dostane valid_to = jej valid_from − 1
price_list_version_close(p_id uuid, p_valid_to date) → void
  -- iba admin; ukončenie cenníka bez nástupcu (valid_to >= dnes)
price_list_version_delete(p_id uuid) → void
  -- iba admin, iba Návrh
```

Príklad 7 zo zadania: úprava schválenej položky → databáza odmietne, API ponúkne „Nová verzia (kópia)“.

**Pohľady:**
- `price_list_version_v` – verzia + `state` (časť 3.2), počet položiek, kto schválil;
  stĺpec „zmluvy, ktoré prejdú“ pribudne v module 4.
- `price_list_item_v` – položka + produkt + ceny s DPH (`price_with_vat`, DPH z kópie, pri Návrhu z produktu).
- `price_list_current_v` – pre každý cenník platná a budúca verzia (obrazovka 20).

---

## 5. Cenové modely (zadanie čl. 4)

| `price_model` | Zložky na zmluve (modul 4) | Povolené pri |
| --- | --- | --- |
| `cennik` | z položky: VT, NT, mesačná platba za OM, poplatok programu, €/kW | DD, DMP, ZEM, VBattery, VIWA, poplatok B2B |
| `fix` | VT/1T, NT [€/MWh]; pri dodávke firmám + mesačná platba za OM z cenníka „Poplatky B2B“ | Dodávka B2B, Výkup B2B, Veľkoobchod |
| `spot_plus_eur` | aditív [€/MWh] | DD (domácnosti), Dodávka B2B, Veľkoobchod |
| `spot_minus_eur` | aditív [€/MWh] | Výkup B2B |
| `spot_minus_pct` | aditív [%] | Výkup B2B |
| `cena_diela` | cena diela | Green Solar (modul 5) |

Modul 3 ukladá iba **povolené** modely produktu. Individuálne ceny vznikajú na zmluve v module 4.

---

## 6. Príprava na modul 4 (iba návrh, nič sa nestavia)

### 6.1 Väzba ceny na zmluve na položku cenníka

Do `contract_price` v module 4 pribudne:

```sql
ALTER TABLE contract_price
  ADD COLUMN price_model         price_model,                                   -- práve jeden model
  ADD COLUMN price_list_item_id  uuid REFERENCES price_list_item (id),          -- ON DELETE RESTRICT
  ADD COLUMN fee_program_eur_month numeric(12,4),
  ADD COLUMN fee_kw_eur_month      numeric(12,4),
  ADD COLUMN vat_rate              numeric(5,2),
  ADD COLUMN additive_pct          numeric(7,4);
-- poplatky fee_oom / fee_zem / fee_vbattery z numeric(12,2) na numeric(12,4) (kópia musí byť presná)
```
- `price_model = 'cennik'` ⇔ `price_list_item_id` vyplnené. Spúšťač pri vložení overí, že položka je zo **schválenej**
  verzie a skopírované hodnoty sa s položkou zhodujú; potom ich už zmena cenníka nemôže prepísať.
- Na návrh sa zmluva odkazovať nemôže (schválenie je podmienka), takže mazanie návrhov je bezpečné.
- Pravdepodobne jedna cena = jeden produkt (dodávka, ZEM, VBattery ako samostatné riadky s vlastnou položkou) –
  rozhodne sa v module 4.

### 6.2 Automatický prechod na novú verziu (pravidlo, postaví sa v module 4)

Nočný beh (rovnaký Cron ako `oom_daily_run`) v deň `valid_from` schválenej verzie V (predošlá verzia P):
1. Vyberie platné ceny s modelom `cennik`, ktorých položka patrí verzii P.
2. Pre každú nájde v V položku **toho istého produktu**: starej cene nastaví `valid_to = V.valid_from − 1`,
   založí novú cenu od `V.valid_from` s kópiou hodnôt z novej položky. Audit „Systém“.
3. Produkt, ktorý vo V chýba → cena sa nemení a zmluva ide do zoznamu výnimiek (pre admina).
4. Ceny `fix`, `spot_*` (individuálne aj SPOT + aditív pri domácnosti) sa nemenia.

Pred schválením: počet zmlúv, ktoré prejdú (obrazovka 21) = platné ceny s položkou z P; „Zoznam na oznámenie“ =
zákazníci týchto zmlúv (osobné údaje → právo „exportovať“ v module Zmluvy a záznam v `export_log`).
Zmena cenovej regulácie OOM (energopomoc) = rovnaký mechanizmus, iba cieľová položka je ten istý tarif v druhom cenníku.

---

## 7. Spoločnosť

Produkt aj cenník majú `org_id` (odpoveď 1): DPH, mena aj produkty českej a chorvátskej spoločnosti budú iné.
Položka a verzia preberajú spoločnosť cenníka; položka smie obsahovať iba produkt tej istej spoločnosti (spúšťač).
Párovanie preberá spoločnosť produktu.

---

## 8. Dopad na modul 2

### 8.1 Číselník sadzieb (Peter, odpoveď 9)

Nové hodnoty `sadzba_distribucie` v `0019` (kód vznikne ako doteraz z PDS a názvu):

| PDS | Pridať |
| --- | --- |
| ZSD | C11; D4–D8 |
| VSD | C11; D4–D8; C9 |
| SSD | C11; D7 |

**ZSD C1 sa skryje** (`hidden_at`, nemaže sa) – takú sadzbu ZSD nemá. Skrytú hodnotu už dnes nejde vybrať na OOM
(`lookup_codes_check`) ani nahrať importom (`oom_import_lookup`). Pred skrytím sa na `dev` overí, či ju používa
nejaké OOM: **ak áno, migrácia ju neskryje** (iba upozornenie) a Peter dostane zoznam (EIC sú testovacie).
Stav na `dev` 13. 10.: používa ju 1 testovacie OOM zo skriptu `db/test-data/oom-test.sql` (zrušené, „Stará hala“).
Miestne DS: bez zmeny (admin pridá v Nastaveniach).

### 8.2 Cenová regulácia ANO / NIE / nevyplnené (Peter, odpoveď 8)

Pole sa **nepremenúva**, mení sa typ: `oom.price_regulation text` → `boolean NULL`
(ANO = true, NIE = false, prázdne = nevyplnené).
- **Pred prevodom** dostane Peter zoznam dnešných hodnôt na `dev` (hodnota a počet, iba čítanie).
- Prevod: jasné `áno`/`ano` (bez ohľadu na veľkosť písmen a medzery) → ANO, jasné `nie` → NIE, všetko ostatné → prázdne.
  Prevod zapíše audit „Systém“.
- Import: ANO / NIE (aj áno, ano, nie) prevedie API na true / false (ako enumy a čísla), prázdna bunka = bez zmeny,
  iné → chyba riadku; funkcia importu v databáze (`0018`) sa nemení.
- Dátum zmeny (príklad 3 „od 1. 3.“) až v module 4; dovtedy história v audite.
- **Kód modulu 2** (samostatný krok po migrácii): `oom-write.ts` (typ poľa ano/nie/prázdne), `oom-forms.tsx`
  (výber ANO / NIE / nevyplnené), `OomPage.tsx`, import (`oom-import.ts` + šablóna a pokyny), export (`export.ts`), `api.ts`.

---

## 9. Práva a audit

**RLS na všetkých nových tabuľkách a na `product`:**

```sql
-- čítanie: každý aktívny používateľ (aj externý) v spoločnostiach, ktoré vidí
CREATE POLICY product_select ON product FOR SELECT
  USING (crm_session_ok() AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
-- zápis: iba admin
CREATE POLICY product_write ON product FOR ALL USING (crm_is_admin()) WITH CHECK (crm_is_admin());
```
- `price_list_version`: ne-admin vidí iba schválené verzie (platné, budúce aj ukončené), **nie Návrhy** (odpoveď 5).
  Položky a parametre programov sa riadia viditeľnosťou verzie.
- Párovanie, produkty, cenníky mení iba admin (`app_user.is_admin`) – rovnaký príznak ako Nastavenia, nie matica tímov.
  Neplatí „iba svoje“ (cenníky nie sú osobné údaje), externý tím ich číta celé; `crm_external_ready()` sa nemení.
- `crm_app` (`api/db/app-role.sql`): SELECT, INSERT, UPDATE na nové tabuľky (verzia iba vymenované stĺpce);
  DELETE iba `price_list_item`, `price_list_item_program`, `product_tariff`, `tariff_scope`; produkt nikdy.
- Export cenníka (obrazovka 21): **schválenú verziu** (aj históriu) smie exportovať každý, kto ju vidí, bez práva
  „exportovať“ a bez záznamu v `export_log` (verejný dokument). **Návrh exportuje iba admin** (odpoveď 12).
- `tariff_scope` a `product_tariff` mení iba admin, čítajú všetci.

**Audit:** `product` už má; pribudne na `price_list`, `price_list_version`, `price_list_item`,
`price_list_item_program`, `product_tariff`, `tariff_scope`. Schválenie, kópia a ukončenie sú v audite s menom admina.
V audite nie sú osobné údaje.

---

## 10. Naplnenie – cenníky 2026 (skript, nie migrácia)

`db/seed/cenniky-2026.sh dev` (+ `cenniky-2026.sql`) – spúšťa Peter, na `main` až po schválení na Teste (odpoveď 11).
Beží ako vlastník databázy (bez používateľa), preto smie schváliť verzie s dátumom v minulosti. Opakované spustenie
nič nezduplikuje (kódy produktov a cenníkov), už schválené verzie nemení.

| Obsah | Počet |
| --- | --- |
| Produkty: DD1–DD8 ANO, DD1–DD8 NIE, DMP1–DMP11, Dodávka B2B, Výkup B2B, Veľkoobchod, ZEM, VBattery STANDARD/PREMIUM/MAX/AKU (Dobieha), VIWA Basic/Plus/Pro, Green Solar, Mesačná platba za OM – firmy | 40 |
| Rozsahy PDS sú v migrácii; párovanie podľa časti 2 | 105 riadkov |
| Domácnosti – NIE Energopomoc, verzia 2026 od 1. 1. 2026: DD1–DD8 NIE + ZEM | 9 položiek |
| Domácnosti – ANO Energopomoc, verzia 2026 od 1. 1. 2026: DD1–DD8 ANO + ZEM | 9 |
| Malé podniky (do 30 MWh), verzia 2026 od 1. 1. 2026: DMP1–DMP11 (DMP9 iba mesačná platba) | 11 |
| Virtuálna batéria, verzia 2026 od 1. 4. 2026: STANDARD, PREMIUM, MAX + parametre | 3 |
| Green VIWA, verzia 2025 od 1. 10. 2025: Basic, Plus, Pro + parametre | 3 |
| Poplatky B2B, verzia 2026 od 1. 1. 2026: mesačná platba za OM 5,0000 € | 1 |

- Ceny bez DPH sa prepíšu z PDF ručne do SQL; skript na konci **porovná ceny s DPH** (`price_with_vat`) so stĺpcom
  „s DPH“ z PDF a pri rozdiele skončí chybou. Kontrola navyše: ANO = NIE − 31,24 €/MWh pri VT aj NT.
- VBattery AKU nemá položku (pôvodná cena ostáva na zmluvách).
- Implementácia: `db/seed/cenniky-2026.sh dev [--skuska]`; Poplatky B2B 5,00 € (s DPH 5,95 € – dopočítané, nie z PDF);
  Green Solar má segment domácnosť (Peter). Na Teste nahraté 13. 10.
- Údaje z HubSpotu sa nenahrávajú.
- PDF cenníkov sú v `exports/cenniky-2026/` (presunuté 13. 10.).

---

## 11. Inventár produktov z HubSpotu (hotové 13. 10. 2026)

Skript `integrations/hubspot-sync/modul3/produkty.ts` (iba čítanie, 331 požiadaviek), výstup v `exports/modul3-produkty/`:
`hubspot-produkty.json` a `prehlad-produktov.md` so stĺpcom „Nový produkt“ na mapovanie (vyplní Peter).
Bez osobných údajov: názov, SKU, cena a popis produktu, kódy a počty. Nič sa nenahráva.

- **HubSpot produkty:** 41, line items používa 24 (5 972 line items). Najviac Green_E_1T_FIX, Výkup_INDEX_SPOT,
  Green_E_1T_SPOT+ aditív, Green_E_2T FIX (VT/NT), Green_E_OM.
- **Kódy v Zmluvných cenách:** 57, použitých 54, s dnes platnou cenou 52; zmluvných cien 11 798, bez kódu 76.
  Najčastejšie: Green DD1–DD6, VBATTERY DD1–DD6 (VBattery je v HubSpote kódovaná podľa sadzby DD),
  IN Green 1T/2T Individual, GREENVYR_AK (výkup podľa roka), GREEN_ISOTSK_PLUS podľa roka.
- Mapovanie na katalóg (časť 1) určí Peter; použije sa až pri presune dát (`hubspot_product_id`, `hubspot_contract_codes`).

---

## 12. Rozhodnuté (Peter, 13. 10. 2026)

1. Povinná spoločnosť pri produkte a cenníku.
2. Ukladať Návrh / Schválená / Nahradená; Budúca / Platná / Ukončená počítať z dátumov.
3. Schvaľovať iba s účinnosťou od dneška; oprava budúcej verzie = nová verzia s rovnakým dátumom.
4. Najviac jeden Návrh na cenník.
5. Ostatní vidia históriu schválených verzií, Návrhy nie.
6. Poplatok B2B 5 € = produkt „Mesačná platba za OM – firmy“.
7. Kópia sadzby DPH do položky pri schválení.
8. Cenová regulácia ANO / NIE / prázdne; prevod a úprava modulu 2 podľa časti 8.2; nevyplnená → ANO aj NIE.
9. Sadzby podľa časti 8.1; ZSD C1 skryť (nie ak ju používa OOM – potom zoznam).
10. Model „cena diela“ pre Green Solar.
11. Jeden skript naplnenia; `main` až po schválení na Teste.
12. Export schválenej verzie bez práva a `export_log`; Návrh exportuje iba admin.
13. Inventár z HubSpotu – hotový (časť 11); PDF presunuté do `exports/cenniky-2026/`.
- Doplnok: rozsah PDS v párovaní výslovne (`tariff_scope`), PDS s vlastným párovaním nikdy nepoužije spoločné riadky.

## 13. Čo bude treba od teba (iba zoznam, nič nemením)

**Neon**
1. Súhlas s čítaním na `dev` pred migráciou: zoznam hodnôt `oom.price_regulation` (hodnota, počet) a OOM so sadzbou ZSD C1.
2. Súhlas so spustením `0019_produkty` a `0020_cenniky` na `dev` (každá zvlášť, po overení nanečisto); `main` až po schválení.
3. Po migráciách znova `api/db/app-role.sql` (práva `crm_app` na nové tabuľky).
4. Súhlas so skriptom `db/seed/cenniky-2026.sh dev`.

**Mapovanie:** stĺpec „Nový produkt“ v `exports/modul3-produkty/prehlad-produktov.md` (kedykoľvek pred presunom dát).

**Test** – `db/test/checks_produkty.sql`:
- ZSD C1 nejde vybrať na novom OOM ani nahrať importom,
- SSD + C1 → DMP1 (`is_only`); ZSD + C2-X3 + NT > 0 → DMP4–DMP8 navrchu, potom DMP1–3, DMP10; ZSD + C11 → DMP11,
- PDS s vlastným rozsahom nepoužije spoločné riadky; domácnosť s nevyplnenou reguláciou → DD ANO aj NIE,
- schválená verzia sa nedá zmeniť (položka, parametre, verzia, mazanie) ani vlastníkom; produkt sa nedá zmazať,
- ne-admin nezapíše nič a nevidí Návrh; externý číta; kópia a schválenie (uzavretie predošlej, Nahradená),
- ceny s DPH podľa PDF; prevod a import cenovej regulácie.
