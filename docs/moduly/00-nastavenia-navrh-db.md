# Modul 0 – Nastavenia: návrh databázy

Verzia 0.2 · 12. 10. 2026 · **schválené Petrom** (v0.1 schválená 12. 10.; v0.2 = odpovede v časti 7 a odchýlky pri implementácii v časti 8).
Implementácia: migrácie `0006`–`0008`, testy `db/test/checks_nastavenia.sql`, skript `db/empty-test.sh`.
Vychádza zo zadania `00-nastavenia.md` v0.2, zadania `01-zakaznici.md` v0.3, migrácií `0001`–`0005`
a obrazoviek 11–16. Rozhodnutia z 12. 10. 2026 sú v `docs/rozhodnutia.md`.

SQL v tomto dokumente je **náčrt**, nie migrácia. Presné migrácie sa napíšu až po schválení.

---

## 0. Prehľad a poradie migrácií

| Migrácia | Obsah | Časť |
| --- | --- | --- |
| `0006_nastavenia_jadro` | spoločnosti, bankové účty, tímy a práva, používatelia a prístup k spoločnostiam, pracovný čas a voľné dni podľa spoločnosti, nové funkcie práv, audit nastavení, záznam exportov | 1.1–1.5, 1.9, 3 |
| `0007_nastavenia_obsah` | číselníky, vlastné polia (definícia + hodnoty), pipelines a stage | 1.6–1.8, 2 |
| `0008_zakaznici_spolocnost` | spoločnosť na firme, osobe, OOM, deale, zmluve a ponuke; krajina a identifikátor firmy; nové politiky RLS namiesto `0005` | 3, 4 |

Predpoklad: Test (`dev`) sa pred `0006` vyprázdni (vzorka prototypu so skutočnými osobnými údajmi
sa zmaže podľa manifestu, rola `crm_prototype_ro` sa zruší). Na to treba tvoj samostatný súhlas.

Pomenovanie: tabuľka `company` = firma zákazníka (už existuje). Spoločnosť skupiny Greenlogy
preto dostane názov **`org`** (organizácia skupiny), aby sa nepliedli.

---

## 1. Tabuľky

### 1.1 Spoločnosti skupiny (`org`)

```sql
CREATE TYPE country_code AS ENUM ('SK', 'CZ', 'HR');          -- nová krajina = zmena v kóde
CREATE TYPE org_status   AS ENUM ('aktivna', 'pripravuje_sa');

CREATE TABLE org (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code               text NOT NULL UNIQUE,         -- 'greenlogy_sk', 'greenlogy_cz', 'greenlogy_hr'
  country            country_code NOT NULL,
  currency           char(3) NOT NULL,             -- EUR, CZK
  status             org_status NOT NULL DEFAULT 'pripravuje_sa',
  is_default         boolean NOT NULL DEFAULT false, -- Greenlogy a.s.; najviac jedna
  timezone           text NOT NULL DEFAULT 'Europe/Bratislava',
  -- údaje do dokumentov (zadanie čl. 4)
  legal_name         text NOT NULL,
  reg_no             text,                         -- IČO / OIB spoločnosti
  tax_no             text,                         -- DIČ
  vat_no             text,                         -- IČ DPH
  address            text,
  registry_entry     text,                         -- zápis v obchodnom registri
  statutory          text,                         -- štatutári (viac riadkov)
  support_phone      text,
  email              text,
  web                text,
  regulator_license  text,                         -- číslo povolenia ÚRSO / ERÚ / HERA (regulátor podľa krajiny)
  logo               bytea,                        -- SVG alebo PNG, najviac 512 kB
  logo_mime          text,
  created_at, updated_at
);
CREATE UNIQUE INDEX org_one_default_key ON org (is_default) WHERE is_default;

CREATE TYPE bank_account_purpose AS ENUM ('faktury', 'zalohy', 'vykup');
CREATE TABLE org_bank_account (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES org (id),
  iban        text NOT NULL CHECK (iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$'),
  bic         text,
  bank_name   text,
  purposes    bank_account_purpose[] NOT NULL DEFAULT '{}',   -- jeden účet môže mať viac účelov
  is_primary  boolean NOT NULL DEFAULT false,
  archived_at timestamptz,                                    -- účet sa nemaže (staré dokumenty)
  created_at, updated_at,
  UNIQUE (org_id, iban)
);
CREATE UNIQUE INDEX org_bank_account_one_primary_key ON org_bank_account (org_id) WHERE is_primary AND archived_at IS NULL;
```

- Migrácia založí Greenlogy a.s. (`aktivna`, predvolená) a dve spoločnosti `pripravuje_sa` so zástupnými názvami.
- Logo v databáze (malý súbor) – netreba nové úložisko. Ak budú neskôr prílohy (zmluvy, PDF), presunie sa do R2.

### 1.2 Tímy a práva

```sql
CREATE TYPE crm_module AS ENUM (
  'zakaznici', 'odberne_miesta', 'obchod', 'zmluvy', 'provizie', 'servis', 'marketing'
);                                                     -- moduly sú jadro → enum
CREATE TYPE access_scope AS ENUM ('nic', 'iba_svoje', 'vsetko');   -- poradie = sila práva

ALTER TABLE team
  ADD COLUMN code             text UNIQUE,            -- 'ceo', 'sales_internal', 'sales_external', 'servis', 'nakup', 'marketing'
  ADD COLUMN description      text,
  ADD COLUMN all_orgs         boolean NOT NULL DEFAULT false,   -- CEO, Nákup, Marketing = true
  ADD COLUMN can_change_owner boolean NOT NULL DEFAULT false,   -- CEO = true
  ADD COLUMN is_external      boolean NOT NULL DEFAULT false,   -- Sales_external = true (poistka, pozri 3.4)
  ADD COLUMN archived_at      timestamptz;

CREATE TABLE team_permission (
  team_id     uuid NOT NULL REFERENCES team (id) ON DELETE CASCADE,
  module      crm_module NOT NULL,
  view_scope  access_scope NOT NULL DEFAULT 'nic',
  edit_scope  access_scope NOT NULL DEFAULT 'nic',
  can_archive boolean NOT NULL DEFAULT false,
  can_export  boolean NOT NULL DEFAULT false,
  created_at, updated_at,
  PRIMARY KEY (team_id, module),
  CHECK (edit_scope <= view_scope)                    -- nemôže upravovať, čo nevidí
);
```

Migrácia založí 6 tímov s východiskovými právami podľa zadania čl. 3 (napr. Sales_external:
Zákazníci, OOM, Obchod, Zmluvy = vidieť aj upravovať „iba svoje“, Servis a Marketing „nič“, bez exportu).
Presnú východiskovú maticu ti dám na odsúhlasenie s migráciou `0006`.

### 1.3 Používatelia a prístup k spoločnostiam

```sql
CREATE TYPE user_status AS ENUM ('pozvany', 'aktivny', 'deaktivovany');

ALTER TABLE app_user
  ADD COLUMN status          user_status NOT NULL DEFAULT 'pozvany',   -- nahrádza active
  ADD COLUMN is_admin        boolean NOT NULL DEFAULT false,           -- smie meniť Nastavenia
  ADD COLUMN last_login_at   timestamptz,                              -- mimo auditu (šum)
  ADD COLUMN invited_at      timestamptz,
  ADD COLUMN deactivated_at  timestamptz,
  DROP COLUMN role, DROP COLUMN active;              -- typ app_user_role sa zruší
ALTER TABLE app_user ALTER COLUMN team_id SET NOT NULL;

CREATE TABLE app_user_org (
  user_id     uuid NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
  org_id      uuid NOT NULL REFERENCES org (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, org_id)
);
```

- Spôsob prihlásenia sa neukladá, vyplýva z e-mailu (`@greenlogy.com` = Google, inak kód e-mailom).
- Tím s `all_orgs` vidí všetky spoločnosti bez ohľadu na `app_user_org`.
- **Deaktivácia** (príklad 6): funkcia `app_user_deactivate(user_id, new_owner_id)` v jednej transakcii
  prepíše vlastníka firiem, domácností a otvorených dealov, nastaví `deaktivovany` a vráti počty.
  Bez nového vlastníka skončí chybou, ak má používateľ čo odovzdať. Volať ju smie iba admin.
- Mapovanie dnešných rolí: `admin` → CEO + `is_admin`, `vedenie` → CEO, `obchodnik` → Sales_internal,
  `servis` → Servis, `marketing` → Marketing, `externy_obchodnik` → Sales_external.

### 1.4 Pracovný čas a voľné dni (podľa spoločnosti)

```sql
CREATE TABLE org_work_hours (                        -- týždenná šablóna
  org_id     uuid NOT NULL REFERENCES org (id),
  weekday    smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),   -- 1 = pondelok
  work_from  time NOT NULL,
  work_to    time NOT NULL CHECK (work_to > work_from),
  PRIMARY KEY (org_id, weekday)                      -- deň bez riadku = voľno
);

CREATE TYPE day_off_kind AS ENUM ('statny_sviatok', 'firemne_volno');
CREATE TABLE org_day_off (
  org_id   uuid NOT NULL REFERENCES org (id),
  date     date NOT NULL,
  kind     day_off_kind NOT NULL,
  name     text NOT NULL,
  PRIMARY KEY (org_id, date)
);

ALTER TABLE business_calendar ADD COLUMN org_id uuid REFERENCES org (id);  -- PK → (org_id, date)
```

- **Štátne sviatky = jadro:** dopĺňa ich migrácia podľa zákona krajiny (dnes `0002` pre SK 2026–2028).
  Admin v Nastaveniach pridáva a odoberá iba `firemne_volno`.
- `business_calendar` ostáva ako vypočítaná tabuľka pre rýchly výpočet SLA. Po každej zmene
  pracovného času alebo voľna ju funkcia `business_calendar_rebuild(org_id)` prepočíta.
- `add_business_minutes(start, minutes)` dostane parameter `org_id` (predvolene Greenlogy a.s.).

### 1.5 Číselníky (`0007`)

```sql
CREATE TABLE lookup_list (                           -- zoznamy zakladá iba migrácia (jadro)
  code        text PRIMARY KEY,   -- 'zdroj_kontaktu', 'dovod_odchodu', 'dovod_prehry', 'predchadzajuci_dodavatel', 'rola_kontaktu'
  name        text NOT NULL,
  entity      text                                   -- kde sa používa (na zobrazenie v Nastaveniach)
);

CREATE TABLE lookup_value (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  list_code    text NOT NULL REFERENCES lookup_list (code),
  org_id       uuid REFERENCES org (id),            -- NULL = celá skupina
  label        text NOT NULL,
  sort_order   integer NOT NULL DEFAULT 0,
  is_system    boolean NOT NULL DEFAULT false,       -- hodnota, na ktorej stojí logika: nedá sa skryť
  hidden_at    timestamptz,                          -- nikdy sa nemaže, iba skryje
  hubspot_value text,                                -- párovanie pri prevzatí dát
  created_at, updated_at,
  UNIQUE NULLS NOT DISTINCT (list_code, org_id, label)
);
```

- Stĺpec, ktorý číselník používa, má cudzí kľúč na `lookup_value(id)` a kontrolu, že hodnota je
  zo správneho zoznamu (spúšťač `lookup_value_check`). Napr. `contact.source` → `contact.source_id`.
- Skrytá hodnota sa nedá vybrať pri novom zázname, staré záznamy ju zobrazujú ďalej.
- Rola kontaktu vo firme je dnes enum `company_role` v `0004` – pozri otázku 2.

### 1.6 Vlastné polia – definícia (`0007`)

```sql
CREATE TYPE crm_entity AS ENUM ('firma', 'osoba', 'oom', 'deal', 'zmluva', 'ponuka');
CREATE TYPE custom_field_type AS ENUM (
  'text', 'dlhy_text', 'cislo', 'suma', 'datum', 'vyber', 'vyber_viac', 'ano_nie', 'odkaz'
);
CREATE TYPE field_edit_access AS ENUM ('vsetky_timy', 'vybrane_timy', 'iba_admin');

CREATE TABLE custom_field_section (
  id uuid PRIMARY KEY, entity crm_entity NOT NULL, name text NOT NULL, sort_order integer,
  UNIQUE (entity, name)
);

CREATE TABLE custom_field (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity        crm_entity NOT NULL,
  key           text NOT NULL CHECK (key ~ '^[a-z][a-z0-9_]{1,62}$'),  -- vznikne z názvu, nikdy sa nemení
  label         text NOT NULL,                     -- názov sa meniť dá
  field_type    custom_field_type NOT NULL,        -- po prvej uloženej hodnote sa nemení
  ref_entity    crm_entity,                        -- iba pri 'odkaz'
  section_id    uuid REFERENCES custom_field_section (id),
  sort_order    integer NOT NULL DEFAULT 0,
  is_required   boolean NOT NULL DEFAULT false,
  show_in_list  boolean NOT NULL DEFAULT false,
  filterable    boolean NOT NULL DEFAULT false,
  edit_access   field_edit_access NOT NULL DEFAULT 'vsetky_timy',
  org_id        uuid REFERENCES org (id),          -- NULL = celá skupina
  archived_at   timestamptz,                       -- archivácia, údaje ostávajú, dá sa obnoviť
  created_at, updated_at,
  UNIQUE (entity, key),
  CHECK ((field_type = 'odkaz') = (ref_entity IS NOT NULL))
);

CREATE TABLE custom_field_team (                   -- iba pri edit_access = 'vybrane_timy'
  field_id uuid REFERENCES custom_field (id) ON DELETE CASCADE,
  team_id  uuid REFERENCES team (id),
  PRIMARY KEY (field_id, team_id)
);

CREATE TABLE custom_field_option (                 -- hodnoty výberu, správajú sa ako číselník
  id uuid PRIMARY KEY, field_id uuid NOT NULL REFERENCES custom_field (id),
  label text NOT NULL, sort_order integer, hidden_at timestamptz,
  UNIQUE (field_id, label)
);
```

Polia jadra (Meno, E-mail, IČO…) v tejto tabuľke **nie sú**. Obrazovka 14 ich zobrazí so zámkom
zo zoznamu v kóde.

### 1.7 Vlastné polia – uloženie hodnôt

Odporúčanie (porovnanie v časti 2): stĺpec **`custom jsonb NOT NULL DEFAULT '{}'`** na tabuľkách
`company`, `contact`, `oom`, `deal`, `contract`, `offer`. Kľúč = `custom_field.key`.

| Typ | Uložené v JSON | Príklad |
| --- | --- | --- |
| text, dlhý text | reťazec | `"poznamka_servis": "zvoniť 2×"` |
| číslo, suma | číslo (presné, `numeric`); mena = mena spoločnosti záznamu | `"rozpocet": 12500.00` |
| dátum | `"RRRR-MM-DD"` | `"revizia_do": "2027-03-31"` |
| výber | id hodnoty (premenovanie hodnoty nič nerozbije) | `"typ_striedaca": "7f3c…"` |
| výber viac | pole id | `"zaujem": ["a1…", "b2…"]` |
| áno/nie | `true` / `false` | `"ma_tepelne_cerpadlo": true` |
| odkaz | id záznamu | `"odporucil": "e9d1…"` |

Spúšťač `custom_values_check` (BEFORE INSERT/UPDATE) na každej z 6 tabuliek:
- neznámy kľúč, pole inej entity alebo inej spoločnosti → chyba,
- zlý typ hodnoty, neexistujúca alebo skrytá hodnota výberu (pri novom zadaní), neexistujúci odkazovaný záznam → chyba,
- **kto smie pole meniť:** zmenené kľúče porovná s `edit_access` a tímom prihláseného používateľa (`app.user_id`) → obmedzenie platí aj v databáze,
- archivované pole: hodnotu nechá, ale nedovolí ju zmeniť.

„Povinné“ kontroluje API pri uložení formulára, nie databáza – inak by nové povinné pole
zablokovalo úpravu každého staršieho záznamu, ktorý ho ešte nemá.

Audit: `audit_row()` sa upraví tak, aby pri stĺpci `custom` zapisoval zmenu po jednotlivých
poliach (`custom.ma_tepelne_cerpadlo: {old, new}`), nie celý JSON.

### 1.8 Pipelines a stage (`0007`, úprava tabuliek z `0001`)

```sql
CREATE TYPE deal_kind AS ENUM ('b2c_dodavka', 'b2b_dodavka', 'b2b_vykup', 'green_solar', 'green_viwa', 'efet');
CREATE TYPE stage_outcome AS ENUM ('otvoreny', 'vyhrany', 'prehrany');

ALTER TABLE pipeline
  ADD COLUMN org_id      uuid REFERENCES org (id),   -- NULL = celá skupina
  ADD COLUMN kind        deal_kind NOT NULL,         -- druh obchodu: jadro (logika „výrobca“, segment)
  ADD COLUMN archived_at timestamptz;
-- UNIQUE (name) → UNIQUE NULLS NOT DISTINCT (org_id, name)

ALTER TABLE pipeline_stage
  ADD COLUMN outcome     stage_outcome NOT NULL DEFAULT 'otvoreny',   -- nahrádza is_closed + is_won
  ADD COLUMN archived_at timestamptz;

CREATE TABLE pipeline_stage_required_field (       -- povinné polia pri prechode do stage
  stage_id        uuid NOT NULL REFERENCES pipeline_stage (id) ON DELETE CASCADE,
  core_field      text,                            -- pole jadra zo zoznamu v kóde (napr. 'lost_reason_id')
  custom_field_id uuid REFERENCES custom_field (id),
  CHECK ((core_field IS NULL) <> (custom_field_id IS NULL))
);
```

- Pipeline ani stage, na ktorých sú dealy, sa nemažú, iba archivujú.
- Pravdepodobnosť ostáva `numeric(3,2)`, obrazovka ju ukazuje v %.
- Zoznam `deal_kind` je predbežný – presné druhy a stage navrhne modul Obchod.

### 1.9 Audit

`audit_log` z `0001` ostáva. Doplnky v `0006`:
- audit sa zapne aj na nové tabuľky Nastavení (`org`, `org_bank_account`, `team`, `team_permission`,
  `app_user_org`, `org_work_hours`, `org_day_off`, číselníky, vlastné polia, pipelines),
- stĺpec `source` (`aplikacia`, `system`, `synchronizacia`) – „Systém“ na obrazovke 16 = vypočítaná zmena,
- audit sa nedá upraviť ani zmazať: rola aplikácie nemá UPDATE/DELETE na `audit_log`, navyše spúšťač, ktorý to zakáže každému okrem vlastníka databázy,
- nová tabuľka `export_log` (kto, modul, filter, počet riadkov, kedy) – export osobných údajov musí byť dohľadateľný,
- filter „nastavenia / dáta“ podľa zoznamu tabuliek, filter podľa spoločnosti cez záznam.

---

## 2. Vlastné polia: JSONB stĺpec vs. tabuľka hodnôt

| | **A. JSONB stĺpec `custom` na záznamoch** | **B. Tabuľka hodnôt `custom_field_value` (EAV)** |
| --- | --- | --- |
| Uloženie | 1 stĺpec na tabuľku, všetky polia záznamu v jednom JSON | 1 riadok na záznam × pole; stĺpce `value_text`, `value_number`, `value_date`, `value_bool`, `value_uuid` |
| Prístup a RLS | **zdedí ich riadok** – kto nevidí firmu, nevidí ani jej polia, bez ďalšej politiky | vlastné politiky RLS pre každú entitu (záznam môže byť zo 6 tabuliek) – ďalšie miesto na chybu |
| Načítanie karty | záznam sa načíta naraz | ďalší dopyt alebo spojenie a skladanie |
| Zoznam so stĺpcami | priamo `custom->>'kluc'` | jedno spojenie (JOIN) na každý zobrazený stĺpec |
| Filter rovná sa (výber, áno/nie, viac hodnôt) | `custom @> '{"ma_tc": true}'` s indexom GIN – rýchle | index na (pole, hodnota) – rýchle |
| Filter rozsah (číslo, dátum) | bez indexu prehľadá tabuľku; pri desiatkach tisíc riadkov stále v milisekundách. Pri potrebe index na výraz pre konkrétne pole (migráciou) | indexovateľné hneď |
| Typová kontrola | spúšťač (validácia JSON) | typované stĺpce + spúšťač, že je vyplnený správny |
| Odkaz na záznam | bez cudzieho kľúča, kontrola spúšťačom | cudzí kľúč iba na jednu tabuľku – pri 6 entitách tiež spúšťač |
| Audit | jeden spúšťač na riadok (upraví sa diff po poliach) | samostatný audit tabuľky hodnôt, ťažšie čitateľný „čo sa zmenilo na firme“ |
| Cockpit a export | jeden stĺpec, čitateľný | treba pivot (riadky → stĺpce) |
| Súbežné úpravy | dvaja menia rôzne polia toho istého záznamu → API musí meniť iba zmenené kľúče (`custom || '{…}'`) | prirodzene oddelené |
| Veľkosť | malá | väčšia (riadok + indexy na každú hodnotu) |

(Tretí spôsob – skutočné stĺpce cez `ALTER TABLE` z Nastavení – zamietam: admin by menil štruktúru
databázy mimo migrácií, čo porušuje pravidlá projektu.)

**Odporúčam A (JSONB).** Hlavný dôvod je bezpečnosť: hodnoty vlastných polí sú súčasťou záznamu,
takže pravidlo „iba svoje“ (RLS) ich chráni automaticky. Pri našom objeme (jednotky až desiatky tisíc
firiem a osôb) je výkon dostatočný; GIN index pokryje bežné filtre (áno/nie, výber) a pri rozsahových
filtroch sa index na konkrétne pole doplní, keď bude treba.

---

## 3. Rola používateľa a RLS z `0005`, keď práva určuje tím

### 3.1 Čo platí dnes
- `app_user.role` (enum); `crm_sees_all()` = aktívny a nie `externy_obchodnik`; `crm_external_user_id()` = aktívny externý.
- Politiky na `company`, `contact`, `company_contact`: vidí všetko, alebo je vlastník (osoba aj cez svoju firmu).
- `owner_change_guard`: vlastníka mení `vedenie` alebo `admin`, výnimka rola `crm_sync`.

### 3.2 Čo sa zmení
Rola zmizne, otázka „čo smie“ sa pýta tímu a spoločnosti. Nové funkcie (STABLE, SECURITY DEFINER,
v politikách obalené `(SELECT …)`, aby sa vyhodnotili raz na dopyt):

```sql
crm_current_user_id()            -- bez zmeny (app.user_id)
crm_user_orgs()        → uuid[]  -- prístupné spoločnosti (všetky pri team.all_orgs);
                                 --   bez používateľa a bez app.require_user = všetky (Cockpit, crm_sync)
crm_scope(module, 'view'|'edit') → access_scope
                                 --   iba používateľ so status = 'aktivny';
                                 --   bez používateľa a bez app.require_user = 'vsetko'; s require_user = 'nic'
crm_can_change_owner() → boolean -- team.can_change_owner OR is_admin
```

Politiky sa rozdelia podľa príkazu (dnes je jedna na všetko):

```sql
-- firma (modul Zákazníci)
CREATE POLICY company_select ON company FOR SELECT USING (
  org_id = ANY ((SELECT crm_user_orgs()))
  AND ( (SELECT crm_scope('zakaznici','view')) = 'vsetko'
     OR ((SELECT crm_scope('zakaznici','view')) = 'iba_svoje' AND owner_id = (SELECT crm_current_user_id())) ));

CREATE POLICY company_insert ON company FOR INSERT WITH CHECK ( …to isté s 'edit'… );
CREATE POLICY company_update ON company FOR UPDATE USING ( …'edit'… ) WITH CHECK ( …'edit'… );
-- DELETE: žiadna politika = nikto z aplikácie nemaže (archivuje sa)
```

- Osoba: ako dnes – vlastná, alebo kontakt na firme, ktorú používateľ vidí; navyše rovnaká spoločnosť.
- `company_ico_check` a `contact_duplicate_check` použijú `crm_scope` namiesto `crm_external_user_id`; „iba svoje“ dostane iba „už existuje“ a meno vlastníka (ako dnes).
- `owner_change_guard`: `crm_can_change_owner()` namiesto zoznamu rolí; výnimka `crm_sync` ostáva; deaktivácia ide cez `app_user_deactivate` (iba admin).
- `crm_sees_all`, `crm_external_user_id`, `crm_external_owns_company`, `crm_external_sees_contact` sa zrušia.

### 3.3 Prečo „iba svoje“ pre Sales_external platí ďalej v databáze
- Politika nečíta „je to externý?“, ale **nastavenie tímu** z `team_permission`. Sales_external má
  „iba svoje“ → databáza mu nevráti cudzí riadok, nech API urobí čokoľvek.
- Rola aplikácie (`crm_app`) má `app.require_user = on`: bez prihláseného používateľa nevidí nič (ako dnes).
- Deaktivovaný používateľ má okamžite rozsah „nič“, aj keby mal ešte otvorené okno.

### 3.4 Poistka proti omylu v Nastaveniach
Tím s `is_external = true` (Sales_external) **nesmie** dostať „vidieť všetko“ pri Zákazníkoch, OOM,
Obchode a Zmluvách – kontrola v databáze (spúšťač na `team_permission`). Admin tak jedným klikom
neodhalí osobné údaje domácností externým. Pozri otázku 3.

### 3.5 Ďalšie moduly
Každý modul (OOM, Obchod, Zmluvy…) pridá rovnaké tri politiky so svojím `crm_module`.
**Pravidlo z `0005` platí ďalej:** do tímu Sales_external sa nikto nepriradí, kým nebudú mať politiky
všetky tabuľky s jeho zákazníkmi (OOM, dealy, zmluvy, ponuky, aktivity).

Stĺpcové práva (Servis mení iba kontaktné údaje) ostávajú v API, ako dnes.

---

## 4. Doplnková migrácia pre Zákazníkov (`0008_zakaznici_spolocnost`)

```sql
-- Spoločnosť na záznamoch (predvolene Greenlogy a.s.)
ALTER TABLE company  ADD COLUMN org_id uuid NOT NULL DEFAULT crm_default_org() REFERENCES org (id);
ALTER TABLE contact  ADD COLUMN org_id uuid NOT NULL DEFAULT crm_default_org() REFERENCES org (id);
-- to isté oom, deal, contract, offer (tabuľky sú z 0001, ich moduly ich ďalej upravia)

-- Krajina a identifikátor firmy
ALTER TABLE company ADD COLUMN country country_code NOT NULL DEFAULT 'SK';
-- stĺpec ico ostáva (názov), význam: národný identifikátor; na obrazovke „IČO“ alebo „OIB“
ALTER TABLE company DROP CONSTRAINT company_ico_format_check;
ALTER TABLE company ADD CONSTRAINT company_ico_format_check CHECK (
     (country IN ('SK', 'CZ') AND ico ~ '^[0-9]{8}$')
  OR (country = 'HR'          AND ico ~ '^[0-9]{11}$') );
DROP INDEX company_ico_key;
CREATE UNIQUE INDEX company_country_ico_key ON company (country, ico);
```

- Spúšťač **rovnakej spoločnosti**: osoba vo firme, deal, OOM, zmluva a ponuka musia mať rovnakú spoločnosť ako ich zákazník (zákazník nepatrí dvom spoločnostiam).
- Krajina firmy ≠ spoločnosť: slovenská spoločnosť môže mať zákazníka s českým IČO. Predvolená krajina = krajina spoločnosti.
- `company_ico_check(p_ico)` → `company_ico_check(p_country, p_ico)`; doplnenie úvodných núl iba pre SK/CZ.
- Kontrolný súčet (CZ IČO, HR OIB) iba ako upozornenie v API, nie v databáze – staré slovenské IČO ho nemusia spĺňať.
- `normalize_phone` predpokladá +421; pre CZ (+420) a HR (+385) sa upraví pred spustením pobočiek.
- Politiky RLS z `0005` sa nahradia politikami z časti 3.

---

## 5. Prihlásenie: Cloudflare Access + zoznam používateľov v CRM

Dve vrstvy. Access púšťa ľudí k aplikácii, CRM rozhoduje, či a čo smú.

**Vrstva 1 – Cloudflare Access (aplikácia na Workeri, zvlášť pre Test a Ostré):**
- Pravidlo 1: prihlásenie **Google**, e-mail končí na `@greenlogy.com`.
- Pravidlo 2: prihlásenie **jednorazovým kódom**, e-mail je v skupine Access „CRM externí“; `@greenlogy.com` vylúčené (zamestnanec ide vždy cez Google).
- Skupinu „CRM externí“ udržiava CRM samo: pri pozvaní externého ho pridá, pri deaktivácii odoberie
  a zruší jeho reláciu (Cloudflare API s úzko obmedzeným tokenom). Bez tokenu ich musíš pridávať ručne v Zero Trust.
- Dĺžka relácie: zamestnanci 24 h, externí 8 h (návrh).

**Vrstva 2 – Worker (každá požiadavka na `/api/*`):**
1. Overí podpis tokenu `Cf-Access-Jwt-Assertion` (kľúče tímu Access, `aud` aplikácie). Bez platného tokenu 401.
2. Vezme e-mail z tokenu, nájde `app_user` (bez ohľadu na veľkosť písmen).
3. Neexistuje alebo `deaktivovany` → 403, obrazovka „Nemáte prístup do CRM. Obráťte sa na administrátora.“
4. `pozvany` → pri prvom prihlásení sa zmení na `aktivny`; zapíše `last_login_at`.
5. V transakcii `SET LOCAL app.user_id` → práva tímu a RLS.

Výsledok: kto nie je aktívny v CRM, nedostane žiadne dáta, aj keby ho Access pustil. Deaktivácia
platí okamžite (stav sa kontroluje pri každej požiadavke). Používatelia sú v každom prostredí zvlášť
(Test a Ostré majú vlastnú databázu).

Pozvánka e-mailom: v prvej verzii CRM pozvánku neposiela, admin pošle odkaz sám (pozri otázku 4).

---

## 6. Čo bude treba od teba (iba zoznam, nič nemením)

**Cloudflare (Zero Trust a Workers)**
1. Zapnúť prihlásenie „One-time PIN“ v Zero Trust (Google je už nastavený pre Cockpit – overiť).
2. Aplikácia Access pre Workera Test s dvoma pravidlami z časti 5; poslať mi *team domain* a *AUD tag*.
3. Skupina Access „CRM externí“.
4. Rozhodnúť, či CRM smie skupinu meniť samo; ak áno, vytvoriť API token s právom iba na Access skupiny a relácie.
5. Druhý Worker (alebo prostredie) pre Ostré – až pred Ostrým; zatiaľ Test na `*.workers.dev`.
6. Nová konfigurácia Hyperdrive na `dev` s rolou aplikácie `crm_app` (dnes `crm_prototype_ro`).

**Neon**
7. Súhlas s vyprázdnením `dev` (vzorka prototypu podľa manifestu) a zrušením roly `crm_prototype_ro`.
8. Rolu `crm_app` vytvára **iba skript** `api/db/create-app-role.sh` (SQL), **nikdy Neon Console** – rola z Console je členom `neon_superuser` a obchádza RLS. „Bez používateľa nič“ zabezpečuje migrácia 0009 podľa mena roly. Neskôr rola `crm_sync` rovnakým spôsobom.
9. Súhlas so spustením migrácií `0006`–`0008` na `dev` (každú zvlášť, po kontrole).

**Tajomstvá**
10. Heslo `crm_app` → iba do Hyperdrive a do lokálneho `.dev.vars` (`DATABASE_URL_DEV_APP`).
11. Ak bod 4 áno: `wrangler secret put CF_ACCESS_API_TOKEN`. *Team domain* a *AUD* nie sú tajné (budú vo `wrangler.toml`).

**Údaje**
12. Zoznam používateľov na Test (meno, e-mail, tím, spoločnosti, admin). Druhý admin (Peter 12. 10.): **Eva Kalmanová**, eva@greenlogy.com, tím Marketing, spoločnosť Greenlogy a.s. – zakladá ju migrácia `0006` spolu s Petrom.
13. Údaje Greenlogy a.s.: DIČ, IČ DPH, číslo povolenia ÚRSO, bankové účty s účelom, logo (SVG), firemné voľno.

---

## 7. Rozhodnuté (Peter, 12. 10. 2026)

1. **Osoba vo dvoch spoločnostiach** = dva záznamy osoby. Kontrola duplicít osôb iba v rámci spoločnosti.
2. **Roly kontaktu vo firme** sú v číselníku `rola_kontaktu`. Štatutár, decision maker a fakturácia sú zamknuté systémové hodnoty (nedajú sa skryť ani premenovať), ostatné spravuje admin.
3. **Poistka pre externý tím:** áno.
4. **Pozvánky** zatiaľ ručne – CRM zobrazí text pozvánky na skopírovanie.
5. **Vlastníka mení** iba tím CEO a admin.

Doplnky:
- Migrácie zakladajú východiskové údaje: Greenlogy a.s. (SK, EUR), 6 tímov s právami podľa zadania čl. 3, používateľ peter@greenlogy.com (admin, tím CEO), druhý admin eva@greenlogy.com (Eva Kalmanová, tím Marketing, Greenlogy a.s.), pracovný čas Po–Pi 7:30–15:30.
- Vlastné pole „odkaz na záznam“: pri zápise sa overí, že cieľový záznam existuje a patrí tej istej spoločnosti.
- Access pre externých: zatiaľ ručne v skupine „CRM externí“. Pred Ostrým: CRM pridá a odoberie e-mail v skupine automaticky pri pozvaní a deaktivácii (úloha v `docs/STAV.md`).

## 8. Odchýlky a spresnenia pri implementácii (na kontrolu)

| Návrh v0.1 | Implementácia | Dôvod |
| --- | --- | --- |
| Hodnota číselníka sa odkazuje cez `lookup_value(id)` (napr. `contact.source_id`) | Záznamy ukladajú **kód** hodnoty (`contact.source`, `company_contact.roles text[]`); kód vznikne z názvu a nikdy sa nemení; kontrola spúšťačom `lookup_codes_check` | roly sú pole (viac naraz) – cudzí kľúč na pole nejde; kód je čitateľný v Cockpite a v API sa nemení dopyt |
| Poistka: „všetko“ zakázané pri Zákazníkoch, OOM, Obchode, Zmluvách | Externý tím nesmie mať „všetko“ v **žiadnom** module; nesmie mať ani všetky spoločnosti, meniť vlastníka a jeho člen nesmie byť admin | prísnejšie a jednoduchšie |
| Pravidlo z 0005 „externého nepriraďovať, kým nemajú politiky ďalšie moduly“ iba v dokumentácii | Platí aj v databáze: do externého tímu sa nedá priradiť používateľ, kým `crm_external_ready()` nevráti `true` (zapne migrácia posledného z modulov OOM, Obchod, Zmluvy) | dnes by externý cez API videl všetky OOM, dealy a zmluvy |
| Logo v `org.logo` | Samostatná tabuľka `org_logo`, v `org` iba `logo_updated_at` | súbor nejde do auditu |
| `pipeline_stage.is_closed`, `is_won` sa rušia | Ostávajú ako stĺpce vypočítané z `outcome` | existujúce dopyty (výpočet stavu zákazníka, API) fungujú bez zmeny |
| Spoločnosti CZ a HR | Založené so stavom `pripravuje_sa` a zástupným názvom; bez pracovného času a sviatkov (SLA pre ne zatiaľ nejde počítať) | obrazovka 11 ich ukazuje |
| Nové používateľské funkcie | `app_user_login(e-mail)` (pozvaný → aktívny pri prvom prihlásení), `app_user_deactivate(používateľ, nový vlastník)`; vždy aspoň jeden aktívny admin | zadanie čl. 3, príklad 6 |
| Východiskové práva (zadanie čl. 3) | **Provízie (Peter 12. 10.):** CEO vidí všetko, Sales_internal a Sales_external iba svoje, Servis, Nákup a Marketing nič. Ostatné moduly: „vidí všetko“ podľa zadania. Archivovať a exportovať iba CEO. Sales_external: vidí „iba svoje“ Zákazníci, OOM, Obchod, Zmluvy, Provízie; upravuje „iba svoje“ Zákazníci a Obchod. | schválené Petrom 12. 10. (body 1, 2, 4 tejto tabuľky tiež) |
