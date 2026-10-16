# Modul 5 – Obchod a ponuky: návrh databázy a riešenia

Verzia 0.7 · 15. 10. 2026 · **F2 krok 1: obrazovky F1 dorovnané, `0036`, `0037` overené nanečisto (časť 20), na `dev` nespustené**
- v0.1 (14. 10.) = analýza a návrh, 21 otázok;
- v0.2 (15. 10.) = Petrove odpovede 1–21 a poistky Gmailu zapracované do textu, odhad ceny R2 a Browser Rendering (časť 12), plán F1 – migrácie `0032_obchod_jadro` a `0033_finstat` (časť 13);
- v0.7 (15. 10.) = odpovede k F2 (19.6), dorovnanie obrazoviek F1, `0036_ponuky` a `0037_schvalovanie_ponuk` overené nanečisto (časť 20);
- v0.6 (15. 10.) = F1 uzavretá, plán F2 (časť 19) s dorovnaním obrazoviek F1 s návrhmi;
- v0.5 (15. 10.) = Peter súhlasil s návrhom k platobnému ratingu a s plánom `0035`; `0035_audit_rls` napísaná a overená nanečisto (časť 17);
- v0.4 (15. 10.) = API a obrazovky F1 (31, 32, 33, 39), `0034` (žiadosť o pridelenie podľa IČO, firma bez vlastníka v overení, oprava hlášky, platobný rating pri zápise Finstatu), Finstat overený 3 volaniami, plán `0035` RLS na audite;
- v0.3 (15. 10.) = Petrov súhlas s plánom F1 a doplnky (Obnova pri existujúcom obchode, Sales_internal/external, dátum prechodu provízií ako nastavenie, Gmail iba vlákna s aktivitou 30 dní, región PDF otvorený do F3, externí = všetci predajcovia); F1 migrácie a testy overené nanečisto (časť 15).

Podklady:
- zadanie `05-obchod.md` v0.2 (schválené) a odpovede kôl 1 a 2 v `05-obchod-otazky.md`,
- dátový model v0.3.2, `rozhodnutia.md`, návrhy DB modulov 0–4 (najmä `04-zmluvy-navrh-db.md` v0.20),
- súčasná schéma `db/schema.sql` (migrácie `0001`–`0030` na `dev`),
- obrazovky `docs/dizajn/obrazovky/30-…42-*.html` a obrázky v `assets/`,
- zdrojový kód Sales portálu (`exports/sales-portal/index.html`, mimo repozitára; kľúč a adresy webhookov sa v tomto dokumente zámerne neuvádzajú),
- repozitáre Cockpitu (`~/Projects/greenlogy/cockpit-*`, iba čítanie).

SQL v tomto dokumente je **náčrt**, nie migrácia. Presné migrácie sa napíšu až po schválení každej fázy. Databáza sa nemení.

---

## 0. Východisko

### 0.1 Čo už v databáze je

| Objekt | Stav | Čo s ním modul 5 urobí |
| --- | --- | --- |
| `pipeline` (`kind` = `deal_kind`), `pipeline_stage` (`probability`, `outcome`), `pipeline_stage_required_field` | modul 0, spravuje admin v Nastaveniach (obrazovka 15) | doplniť systémový kód štádia, naplniť 4 pipelines |
| `lookup_list` `dovod_prehry` | existuje, bez hodnôt | naplniť hodnoty zo zadania |
| `deal` | 0001, prázdna, **bez RLS** | doplniť polia a pravidlá, RLS |
| `deal_oom`, `deal_contact` | 0001, iba väzby, bez RLS | doplniť plánované objemy a rolu, RLS |
| `offer`, `offer_item`, enum `offer_status` | 0001, prázdne, starý model (1 ponuka = 1 zoznam položiek) | prerobiť: ponuka → varianty → položky OOM × rok |
| `commission`, `commission_rule`, enum `commission_status` | 0001, prázdne | prerobiť podľa Sales portálu; `commission_rule` zrušiť |
| `contract.deal_id` | **unikátny** (`contract_deal_id_key`, 1 deal = 1 zmluva) | zrušiť unikátnosť (1 : n) |
| `contract_flag_code` | 5 hodnôt | pridať „Cena iná ako v ponuke“ |
| `price_exception` | modul 4, výnimky mimo ponúk (30 dní) | ostáva; výnimka z ponuky sa na ňu premietne pri párovaní |
| `notification` (`kind` CHECK, väzby na zmluvu, výnimku, beh) | modul 4 | nové druhy a väzby na obchod, ponuku, žiadosť |
| `business_calendar` (per spoločnosť, SK sviatky 2026–2028), `add_business_minutes` | modul 0 | nová funkcia „nasledujúci pracovný deň“ |
| `trader_price()`, `price_parameter`, `market_price_daily` | modul 4 (ceny zadávané ručne) | použiť pre ponuky; denné napĺňanie z Cockpitu (časť 7) |
| `app_user` (`seller_type`, `approves_prices`) | modul 0/4 | profil (fotka, funkcia, telefóny), provízie |
| `company` (`payment_rating`, `debts_note`, `insolvency_note`, `finstat_*`, `bank_account`) | modul 1, Finstat nenapojený | nové polia Finstatu a pre zmluvu |
| `oom.previous_supplier` | modul 2 | ostáva; pribudne vzťah k nehnuteľnosti a IMS |
| R2, KV, Browser Rendering, fronty | **nie sú** (Worker má iba Hyperdrive) | R2 a Browser Rendering pribudnú (časti 4, 5) |

**Predpoklad:** `deal`, `deal_oom`, `deal_contact`, `offer`, `offer_item`, `commission` sú na Teste prázdne. Migrácie to overia a inak skončia chybou, ako `0019` a `0025`.

### 0.2 Zistenia zo Sales portálu (dôležité pre návrh)

- **Provízia v portáli** = hrubá marža z HubSpotu (`new_hruba_marza_pre_vypocet_provizie_gd`) × % obchodníka, zaokrúhlená na centy. Portál sám nič nenásobí objemom ani rokmi. V CRM bude základom **pridaná hodnota zo zmlúv obchodu** (modul 4), teda čísla sa budú od portálu líšiť. Prenesená história ostane s pôvodnými sumami.
- **Stavy v portáli** sú iba `pending` (Čaká) a `claimed` (Uplatnená). Zrušenie listu vráti provízie na Čaká; samostatný stav „Vyplatená“ neexistuje.
- **Číslo listu** `CMSN-RRRR-NNNN` dáva Firestore počítadlo `settings/commission_counter` (rok + posledné číslo, od 1 každý rok). Zrušené číslo sa znova nepoužije.
- **PDF a e-mail provízneho listu** robí Make (Google Drive, odkaz `pdfUrl`, `pdfFileId`).
- **Finstat** ide cez Make (vyhľadanie podľa IČO aj našepkávanie podľa názvu). Portál zobrazuje názov, DIČ, IČ DPH, predmet činnosti, tržby, zisk, zamestnancov, sídlo, vznik, dlhy (text) a „rating“. **Z-skóre portál nepočíta**, hodnotu „rating“ zobrazuje ako Z-skóre. Výstrahy pre konkurz, nedoplatky ani platobný rating v portáli nie sú. Žiadosť o pridelenie firmy v portáli nie je (je nová).
- **Ceny:** dlaždice počítajú cenu v prehliadači z `prices_daily` (BL, PL podľa Montelu) a nastavení s iným vzorcom (predvolene 70/30 + odchýlka + prevádzkové náklady). Záložka „Ceny energie“ číta hotové `nakupna2027–2029`. **Dva zdroje, ktoré sa môžu rozísť.** Roky 2027–2029 sú natvrdo, minimálny aditív je jeden pre všetkých. CRM bude mať jeden výpočet (`trader_price`, modul 4).
- **Chyby portálu** (iba na vedomie): nefunkčné hľadanie v províziách, roly iba v prehliadači, kontakty v `localStorage`, uplatnenie nie je atomické.

### 0.3 Nezrovnalosti v obrazovkách (riadim sa zadaním)

Čísla v návrhoch sú ilustračné. Pri implementácii platí zadanie:
- obchod prechádza do Vyhraté **pri prvej spárovanej zmluve** (obrazovky 32, 40, 41 to miestami ukazujú inak),
- FIX platí do 16:00 nasledujúceho pracovného dňa (verzia /2 na obrazovke 33 má o deň dlhšiu platnosť),
- výkupné a VIWA obchody patria do vlastných pipelines (na obrazovke 32 sú v B2B dodávke),
- stav OOM „Aktívne – iný dodávateľ“ (obrazovka 33) bol iba popis a nezavádza sa; OOM nového zákazníka je Pripravované (odpoveď 3),
- „Vyplatené tento mesiac“ na obrazovke 41 = uplatnené; stav Vyplatená sa nezavádza (odpoveď 14),
- názvy produktov: ponuka používa produkty modulu 3 (Green 1T, 2T…), Podklady pre zmluvu ukážu názov produktu Office portálu (`GREEN_1T_INDIVIDUAL_2027`) z prekladovej tabuľky modulu 4.

---

## 1. Dátový model

### 1.1 Pipelines a štádiá

Štádiá sú vo všetkých pipelines rovnaké a logika (povinné údaje, automatické prechody, párovanie) na nich stojí. Admin ich môže premenovať, ale nie zmeniť ich význam. Preto dostanú **systémový kód** (rovnaký princíp ako číselníky: jadro sa mení iba migráciou, rozhodnutie 2026-10-12).

```sql
CREATE TYPE deal_stage_code AS ENUM (
  'prilezitost', 'cenova_ponuka', 'vyjednavanie', 'akceptacia', 'vyhrane', 'prehrane');

ALTER TABLE pipeline_stage
  ADD COLUMN code deal_stage_code;                 -- NULL = stage pridaná adminom (iba medzistupeň bez logiky)
CREATE UNIQUE INDEX pipeline_stage_code_key ON pipeline_stage (pipeline_id, code) WHERE code IS NOT NULL;
-- spúšťač: code sa nemení; outcome musí sedieť (vyhrane ↔ vyhrany, prehrane ↔ prehrany, ostatné otvoreny);
-- systémovú stage nejde archivovať
```

- **Naplnenie** (migrácia, iba ak na Teste nie sú pipelines s dealmi): B2B dodávka (`b2b_dodavka`), B2B výkup (`b2b_vykup`), Green VIWA B2B (`green_viwa`), B2C (`b2c_dodavka`), každá so 6 štádiami a pravdepodobnosťou 10 / 30 / 50 / 90 / 100 / 0 %. GreenSolar a EFET sa nezakladajú (ostávajú v HubSpote).
- **Nová pipeline** v Nastaveniach dostane namiesto dnešných „Nový, Vyhraný, Prehraný“ (`0010`) týchto 6 systémových štádií.
- **Povinné polia** pri vstupe do štádia: jednoduché polia cez existujúcu `pipeline_stage_required_field` (zákazník, vlastník, zdroj), zložené podmienky v databázovej funkcii `deal_stage_check` (časť 1.2).
- **Číselníky** (`lookup_value`, spravuje admin):
  - `dovod_prehry`: cena, zostal u dodávateľa, iný dodávateľ, nereaguje, nesplnil podmienky, iné;
  - nový `zdroj_obchodu`: vlastný kontakt, web, call centrum, odporúčanie, partner, **obnova** (systémová hodnota, používa ju nočný beh).

### 1.2 Obchod (`deal`, úprava)

```sql
ALTER TABLE deal
  DROP COLUMN source, DROP COLUMN lost_reason, DROP COLUMN campaign,
  ADD COLUMN source_code          text NOT NULL,          -- lookup zdroj_obchodu
  ADD COLUMN lost_reason_code     text,                   -- lookup dovod_prehry
  ADD COLUMN lost_note            text,
  ADD COLUMN supply_start         date,                   -- začiatok dodávky
  ADD COLUMN next_step            text,
  ADD COLUMN next_step_on         date,
  ADD COLUMN next_step_notified_on date,                  -- upozornenie v deň kroku už odišlo
  ADD COLUMN previous_contract_id uuid REFERENCES contract (id),   -- obnova
  ADD COLUMN estimated_value_eur  numeric(12,2),          -- odhad PH pred prvou ponukou („≈ 400 €“, obrazovka 32)
  ADD COLUMN accepted_variant_id  uuid,                   -- FK na offer_variant (nastaví akceptácia)
  ADD COLUMN accepted_at          timestamptz,
  ADD COLUMN stage_changed_at     timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN note                 text;
-- closed_at (existuje) = vstup do Vyhraté / Prehraté; NULL = otvorený obchod
CREATE UNIQUE INDEX deal_open_renewal_key ON deal (previous_contract_id)
  WHERE closed_at IS NULL AND source_code = 'obnova';        -- najviac jedna otvorená Obnova k zmluve
```

**Pravidlá v databáze (spúšťače a funkcia `deal_stage_check`):**

| Vstup do štádia | Podmienka |
| --- | --- |
| Príležitosť | zákazník, vlastník, zdroj |
| Cenová ponuka | aspoň jedno OOM; každé má plánovanú spotrebu (VT + NT > 0) alebo pri výkupe a VIWA výrobu alebo výkon zdroja |
| Vyjednávanie | – |
| Akceptácia | akceptovaný variant (`accepted_variant_id`); nastaví ho akceptácia sama |
| Vyhraté | iba párovanie zmluvy (časť 2.1) alebo admin |
| Prehraté | dôvod prehry; pri „iné“ povinná poznámka |

- **Zákazník a pipeline:** B2C iba osoba (domácnosť), ostatné pipelines iba firma.
- **Konflikt vlastníka** (časť 4.1 zadania): obchod pre firmu, ktorú vlastní iný obchodník, odmietne databáza („Firmu vlastní … – požiadajte o pridelenie“). Výnimka: tím CEO (`can_change_owner`), admin a `crm_sync`. **Firma (alebo domácnosť) bez vlastníka:** kto na nej zakladá obchod, stane sa jej vlastníkom (iba z prázdneho vlastníka; odpoveď 4).
- **Znovuotvorenie:** Prehraté znova otvorí vlastník obchodu, Vyhraté iba admin (napr. po zrušení spárovania). Vždy s povinným dôvodom, ktorý ide do auditu a časovej osi (odpoveď 2).
- **Pri prehre:** OOM, ktoré vzniklo pri tomto obchode a nie je na žiadnej zmluve ani v inom otvorenom obchode, prejde do stavu **Zrušené** (väzba so zákazníkom sa uzavrie dôvodom `zrusenie`, v časovej osi „obchod prehraný“). Obnoviť ho možno ako v module 2 (odpoveď 1).
- **Pri Vyhraté:** zápis do časovej osi, upozornenie, provízia (F7), prepočet stavu zákazníka.
- **Ďalší krok:** nočný beh pošle v deň kroku upozornenie do zvončeka (`next_step_notified_on` stráži „raz“). Zoznam zvýrazní obchod bez kroku alebo s krokom po termíne (počíta sa v pohľade `deal_v`).
- **Hodnoty v prehľadoch** (pohľad `deal_v`, nič sa neukladá): PH obchodu = PH akceptovaného variantu, inak hlavného variantu (A) poslednej verzie ponuky, inak `estimated_value_eur`; vážená PH = PH × pravdepodobnosť štádia.

### 1.3 OOM na obchode (`deal_oom`) a kontakty (`deal_contact`)

```sql
ALTER TABLE deal_oom
  ADD COLUMN planned_vt_mwh      numeric(12,3) CHECK (planned_vt_mwh >= 0),   -- ročne; predvyplní sa z OOM
  ADD COLUMN planned_nt_mwh      numeric(12,3) CHECK (planned_nt_mwh >= 0),
  ADD COLUMN planned_feed_in_mwh numeric(12,3) CHECK (planned_feed_in_mwh >= 0),
  ADD COLUMN source_power_kw     numeric(12,3) CHECK (source_power_kw >= 0),
  ADD COLUMN org_id              uuid NOT NULL REFERENCES org (id),
  ADD CONSTRAINT deal_oom_key UNIQUE (deal_id, oom_id);

ALTER TABLE deal_contact
  ADD COLUMN is_primary boolean NOT NULL DEFAULT false,   -- primárny kontakt = predvolená kontaktná osoba ponuky
  ADD CONSTRAINT deal_contact_key UNIQUE (deal_id, contact_id);
-- role: kódy z číselníka rola_kontaktu (pole text[] ako pri firme), najviac jeden primárny kontakt na obchod
```

- **Objemy na obchode** sú odhad pre ponuku (obchodník ich môže upraviť). Plánovaná spotreba OOM z XM Trade sa nimi neprepisuje (rozhodnutie 2026-10-14, objem z XM Trade).
- **OOM patrí zákazníkovi obchodu** (aktuálna väzba `oom_customer`). OOM iného zákazníka (budúci prepis) sa pridať dá, s upozornením.
- **Jedno OOM najviac v jednom otvorenom obchode** v každej skupine (dodávka / výkup a VIWA) – spúšťač. Inak by dvaja obchodníci ponúkali to isté miesto. **Výnimka:** obchod „Obnova“ k zmluve, na ktorej OOM práve je – OOM môže byť súčasne v ňom a v jednom ďalšom otvorenom obchode (odpoveď 5).
- **NN a VN** sú v jednom obchode; rozdelenie na zmluvy podľa `oom.voltage_level` (NN; VN a VVN) robia až Podklady pre zmluvu.

### 1.4 Nové OOM v stave Pripravované bez zmluvy

- OOM v stave Pripravované bez zmluvy už dnes vzniknúť môže (modul 2) a samo sa neaktivuje: nočná aktivácia vyžaduje potvrdený zmenový proces (`switch_confirmed_on`) a dátum dodávky (`oom_activation_ready`). **Nová štruktúra netreba.**
- Pridá sa iba **pôvod**: `oom.created_from_deal_id uuid REFERENCES deal (id)`, aby sa pri prehre vedelo, ktoré OOM vzniklo pri obchode.
- Obchodník zakladá OOM z karty obchodu tou istou funkciou ako v module 2 (kontrola EIC formát + kontrolná číslica, duplicita, povinné polia Pripravovaného OOM) a v tom istom kroku ho pridá do `deal_oom` s objemami.
- Interný aj externý obchodník smie zakladať a upravovať Pripravované OOM svojich zákazníkov (rozhodnutia 2026-10-12).

### 1.5 Ponuka (`offer`, prerobenie)

Jeden riadok `offer` = **jedna verzia** ponuky. Číslo je spoločné pre všetky verzie, verzia sa pridá ako `/2`.

```sql
DROP TYPE offer_status;   -- tabuľka je prázdna, prerobí sa
CREATE TYPE offer_status AS ENUM (
  'koncept', 'caka_na_schvalenie', 'pripravena', 'odoslana', 'otvorena',
  'akceptovana', 'zamietnuta', 'nahradena');
-- „Vypršaná“ sa počíta: odoslana/otvorena a now() > valid_until (ako stavy cenníka a zmluvy)
CREATE TYPE offer_kind AS ENUM ('dodavka', 'vykup', 'viwa');      -- z druhu pipeline
CREATE TYPE offer_language AS ENUM ('sk', 'en');

CREATE TABLE offer (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id              uuid NOT NULL REFERENCES org (id),
  deal_id             uuid NOT NULL REFERENCES deal (id),
  number              text NOT NULL,                 -- P26-000123 (rovnaké pre všetky verzie)
  version             smallint NOT NULL DEFAULT 1 CHECK (version > 0),
  kind                offer_kind NOT NULL,
  language            offer_language NOT NULL DEFAULT 'sk',
  household           boolean NOT NULL,              -- zákazník je domácnosť (ceny s DPH, poplatky)
  status              offer_status NOT NULL DEFAULT 'koncept',
  contact_id          uuid REFERENCES contact (id),  -- kontaktná osoba (predvolene primárny kontakt obchodu)
  priced_on           date NOT NULL,                 -- deň ceny pre obchodníka (snímka, časť 1.6)
  seller_type         seller_type,                   -- typ predajcu vlastníka v deň snímky
  valid_until         timestamptz,                   -- 16:00 Europe/Bratislava; určí sa pri odoslaní
  valid_shortened     boolean NOT NULL DEFAULT false,
  template_version_id uuid REFERENCES offer_template_version (id),   -- šablóna použitá pri odoslaní
  customer_snapshot   jsonb,                         -- názov, sídlo, IČO, DIČ, IČ DPH v deň odoslania (pre PDF)
  pdf_key             text,                          -- R2, nemenné po odoslaní
  pdf_sha256          text,
  public_token_hash   bytea UNIQUE,                  -- SHA-256 tokenu stránky ponuky (token sa neukladá)
  sent_at             timestamptz,
  sent_by             uuid REFERENCES app_user (id),
  sent_manually       boolean NOT NULL DEFAULT false, -- „Označiť ako odoslanú“ (PDF poslané inak)
  replaced_by_id      uuid REFERENCES offer (id),
  hubspot_quote_id    text,                          -- prenos poslednej ponuky z HubSpotu (PDF príloha)
  custom              jsonb NOT NULL DEFAULT '{}',
  created_by          uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (org_id, number, version),
  CHECK (status IN ('koncept','caka_na_schvalenie','pripravena') OR sent_at IS NOT NULL)
);

-- počítadlá otvorení oddelene, aby každé otvorenie nezapisovalo audit ponuky
CREATE TABLE offer_page_stat (
  offer_id        uuid PRIMARY KEY REFERENCES offer (id) ON DELETE CASCADE,
  first_opened_at timestamptz NOT NULL,
  last_opened_at  timestamptz NOT NULL,
  open_count      integer NOT NULL DEFAULT 1
);
```

- **Číslo** `P{RR}-{NNNNNN}` z počítadla `doc_counter` (spoločnosť, druh, rok; bez medzier v rade v rámci transakcie). Počítadlo začína každý rok od 1, napr. `P27-000001` (odpoveď 13). Prvá verzia je bez prípony, ďalšie `/2`, `/3`.
- **Nová verzia** (aj „Prepočítať na dnešné ceny“) skopíruje varianty a položky, urobí novú snímku cien a starú verziu označí Nahradená. Odkaz starej verzie ukáže „Ponuka bola nahradená novšou verziou“.
- **Po odoslaní sa ponuka nemení** (spúšťač): menia sa iba stav, počítadlá, predĺženie platnosti schválením a väzba na novú verziu.
- **Stavy:**
  - Koncept = rozpracovaná, mení sa.
  - „Pripraviť na odoslanie“ overí podmienky. Ak treba schválenie (časť 1.8), stav je Čaká na schválenie, inak Pripravená. Úprava Pripravenej ponuky ju vráti do Konceptu.
  - Odoslaná → Otvorená (prvé otvorenie stránky) → Akceptovaná, alebo Zamietnutá (obchodník zaznačí), Nahradená (nová verzia), Vypršaná (počíta sa).
- **Firma vs. domácnosť** (`household`): v PDF a na stránke iba cena komodity pri firme; pri domácnosti ceny s DPH, mesačné poplatky a odhad ročných nákladov (zadanie 7.1).

### 1.6 Variant a ceny OOM × rok (`offer_variant`, `offer_item`, `offer_year_basis`)

```sql
CREATE TYPE offer_price_kind AS ENUM ('fix', 'spot', 'kombinacia', 'cennik', 'viwa');

CREATE TABLE offer_variant (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id             uuid NOT NULL REFERENCES offer (id) ON DELETE CASCADE,
  org_id               uuid NOT NULL REFERENCES org (id),
  sort_order           smallint NOT NULL,             -- A = 1 (hlavný variant pre prehľady)
  name                 text NOT NULL,                 -- „FIX 2027–2028“ (predvolený z typu a obdobia, dá sa zmeniť)
  price_kind           offer_price_kind NOT NULL,
  supply_from          date NOT NULL,
  supply_to            date,                          -- NULL = na neurčito
  tranche              text,                          -- FIX / SPOT / SEAS – vypočíta sa ako v module 4
  viwa_package         text,                          -- basic / plus / pro
  -- premenné polia (zadanie 7.2), predvolené zo šablóny a obchodu
  flexibility_pct      numeric(5,2),                  -- NULL = plná flexibilita, inak tolerancia ± %
  planned_volume_mwh   numeric(12,3),                 -- NULL = súčet z OOM
  invoice_due_days     smallint NOT NULL DEFAULT 14,
  advance_kind         text NOT NULL DEFAULT 'mesacne',   -- mesacne / financna_zabezpeka
  advance_pct          numeric(5,2) DEFAULT 100,          -- % z 1/12 plánovaného ročného odberu
  advance_due_day      smallint DEFAULT 5,
  negative_price_compensation boolean NOT NULL DEFAULT false,   -- iba výkup
  created_at, updated_at,
  UNIQUE (offer_id, sort_order),
  CHECK (supply_to IS NULL OR supply_to >= supply_from)
);

-- jeden riadok = jedna zložka ceny pre OOM a rok (rovnaké sloty a modely ako contract_price, modul 4)
CREATE TABLE offer_item (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variant_id         uuid NOT NULL REFERENCES offer_variant (id) ON DELETE CASCADE,
  oom_id             uuid REFERENCES oom (id),        -- NULL iba viwa_ucet
  org_id             uuid NOT NULL REFERENCES org (id),
  year               smallint,                        -- NULL = celé obdobie (SPOT/VIWA na neurčito, cenník)
  slot               price_slot NOT NULL,             -- komodita, poplatok_om, zem, program, viwa_ucet, viwa_kw
  product_id         uuid NOT NULL REFERENCES product (id),   -- iba produkt v stave Predáva sa
  price_model        price_model NOT NULL,
  price_list_item_id uuid REFERENCES price_list_item (id),     -- domácnosti a malé podniky: cena z cenníka
  price_vt_eur_mwh   numeric(12,4),
  price_nt_eur_mwh   numeric(12,4),
  additive_eur_mwh   numeric(12,4),
  additive_pct       numeric(7,4),
  fee_eur_month      numeric(12,4),
  fee_kw_eur_month   numeric(12,4),
  volume_vt_mwh      numeric(12,3),                   -- snímka z deal_oom × podiel roka (ako bilancia modulu 4)
  volume_nt_mwh      numeric(12,3),
  created_at, updated_at,
  UNIQUE NULLS NOT DISTINCT (variant_id, oom_id, slot, year),
  CHECK ((oom_id IS NULL) = (slot = 'viwa_ucet')),
  CHECK ((price_model = 'cennik') = (price_list_item_id IS NOT NULL))
  -- + rovnaké CHECK hodnôt podľa modelu ako contract_price
);

-- snímka hraníc ku dňu verzie (ako contract_year_basis pri zmluve)
CREATE TABLE offer_year_basis (
  variant_id        uuid NOT NULL REFERENCES offer_variant (id) ON DELETE CASCADE,
  year              smallint NOT NULL,
  trader_price      numeric(12,4),     -- FIX: cena pre obchodníka k offer.priced_on
  min_additive      numeric(12,4),     -- SPOT / výkup podľa typu predajcu a lokálneho zdroja
  energopomoc_price numeric(12,4),
  viwa_additive     numeric(12,4),
  PRIMARY KEY (variant_id, year)
);
```

- **Cena pre obchodníka a pridaná hodnota:** jeden výpočet pre zmluvu aj ponuku. Výpočet riadku z bilancie modulu 4 sa vyčlení do spoločnej funkcie (`value_line(model, cena, hranica, objem…)`), ktorú použije `contract_year_value_v` aj nový `offer_value_v`. Testy modulu 4 musia dať po úprave rovnaké čísla.
- **Snímka:** `offer_year_basis` sa vyplní pri založení verzie k `priced_on` (dnes) a potom sa nemení. Neskorší pohyb BL/PL ponuku nemení (zadanie 5.2). **FIX ponuka s `priced_on` < dnes:** pri odoslaní CRM upozorní a ponúkne „Prepočítať na dnešné ceny“; bez prepočtu sa dá odoslať iba v deň vytvorenia verzie (odpoveď 11).
- **Pohľady:**
  - `offer_value_v`: položka a variant × rok – objem, hranica (alebo schválená výnimka), PH, odhad provízie (PH × % vlastníka). Vidí každý, kto vidí obchod.
  - `offer_margin_v`: marža firmy (komodita + poplatky − odhad portfólia **dnes**, ako v module 4) iba pri `crm_can_see_margin()`.
- **Domácnosti a malé podniky** (zadanie 5.3): položky s modelom `cennik` naplní CRM podľa sadzby a regulácie OOM (`product_candidates_by`, modul 3) a obchodník ich nemení (spúšťač). Pri plánovanej spotrebe nad 30 MWh CRM upozorní (rovnaké pravidlo ako `small_business_volume`).
- **Výkup a VIWA** (zadanie 5.4): sloty a modely ako na výkupnej zmluve (FIX, SPOT − €, SPOT − %, lokálny zdroj s plánom kW × 4 × 365 × 0,1; VIWA balík, účet, €/kW, koeficient).
- **„Rovnaká cena pre NN“** (obrazovka 34) je iba pomôcka editora – uloží sa rovnaká hodnota do všetkých položiek.

### 1.7 Akceptácia (`offer_acceptance`)

```sql
CREATE TYPE acceptance_method AS ENUM ('klik', 'rucne', 'podpisane_pdf');

CREATE TABLE offer_acceptance (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id           uuid NOT NULL UNIQUE REFERENCES offer (id),
  variant_id         uuid NOT NULL REFERENCES offer_variant (id),
  org_id             uuid NOT NULL REFERENCES org (id),
  method             acceptance_method NOT NULL,
  accepted_at        timestamptz NOT NULL DEFAULT now(),
  signer_name        text NOT NULL,
  signer_function    text,
  ip                 inet,                 -- iba pri kliku (zadanie 20)
  user_agent         text,                 -- iba pri kliku
  terms_text         text,                 -- presné znenie záväznej objednávky (alebo prijatia pri VIWA)
  terms_sha256       text,                 -- odtlačok znenia
  offer_pdf_sha256   text NOT NULL,        -- ktoré PDF zákazník prijímal
  signed_file_key    text,                 -- R2: nahraté podpísané PDF
  confirmation_pdf_key text,               -- R2: PDF s vyplnenou záväznou objednávkou
  recorded_by        uuid REFERENCES app_user (id),   -- ručná akceptácia
  note               text,
  revoked_at         timestamptz,          -- iba admin, s dôvodom (omyl pri ručnom zázname)
  revoked_by         uuid REFERENCES app_user (id),
  revoke_reason      text,
  CHECK ((method = 'klik') = (ip IS NOT NULL AND terms_sha256 IS NOT NULL)),
  CHECK ((method = 'podpisane_pdf') = (signed_file_key IS NOT NULL))
);
```

- **Záznam sa nemení ani nemaže** (spúšťač); jedinou zmenou je zrušenie adminom s dôvodom, ktoré vráti obchod do Vyjednávania.
- Akceptácia v jednej transakcii: ponuka → Akceptovaná, ostatné otvorené verzie toho istého obchodu → Nahradená, `deal.accepted_variant_id` a `accepted_at`, obchod → Akceptácia, upozornenie vlastníkovi, e-mail s potvrdením do fronty odosielania (časť 3.5).
- Akceptovať sa dá iba pri stave Odoslaná / Otvorená a `now() < valid_until` (čas databázy, nie prehliadača).

### 1.8 Schvaľovanie (`approval_request`)

Jedna fronta pre všetky štyri druhy (obrazovka 39).

```sql
CREATE TYPE approval_kind AS ENUM ('vynimka_ceny', 'rizikovy_zakaznik', 'predlzenie_platnosti', 'pridelenie_firmy');
CREATE TYPE approval_status AS ENUM ('caka', 'schvalena', 'zamietnuta', 'zrusena');   -- Expirovaná sa počíta

CREATE TABLE approval_request (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  kind            approval_kind NOT NULL,
  deal_id         uuid REFERENCES deal (id),
  offer_id        uuid REFERENCES offer (id),           -- výnimka, riziko, predĺženie
  variant_id      uuid REFERENCES offer_variant (id),   -- výnimka
  company_id      uuid REFERENCES company (id),         -- pridelenie firmy, riziko
  from_owner_id   uuid REFERENCES app_user (id),        -- pridelenie: pôvodný vlastník
  requested_valid_until timestamptz,                    -- predĺženie
  risk_snapshot   jsonb,                                -- riziko: konkurz / rating v čase žiadosti
  reason          text NOT NULL CHECK (btrim(reason) <> ''),
  requested_by    uuid NOT NULL REFERENCES app_user (id),
  status          approval_status NOT NULL DEFAULT 'caka',
  decided_by      uuid REFERENCES app_user (id),
  decided_at      timestamptz,
  decision_note   text,
  valid_until     timestamptz,                          -- výnimka: rozhodnutie + 3 dni na odoslanie
  created_at, updated_at,
  CHECK ((status IN ('schvalena','zamietnuta')) = (decided_at IS NOT NULL)),
  CHECK (decided_by IS NULL OR decided_by <> requested_by)
);

-- výnimka z ceny: hranica pre rok, model a napäťovú skupinu variantu
CREATE TABLE approval_price_item (
  approval_id      uuid NOT NULL REFERENCES approval_request (id) ON DELETE CASCADE,
  year             smallint NOT NULL,
  price_model      price_model NOT NULL,
  voltage_group    text NOT NULL CHECK (voltage_group IN ('nn', 'vn', 'vsetko')),
  requested_value  numeric(12,4) NOT NULL,   -- najnižšia cena / aditív vo variante
  threshold_value  numeric(12,4) NOT NULL,   -- hranica v deň snímky (cena pre obchodníka / min. aditív)
  approved_value   numeric(12,4),            -- schválená hranica (môže byť iná ako žiadaná, obrazovka 39)
  volume_mwh       numeric(12,3),
  PRIMARY KEY (approval_id, year, price_model, voltage_group)
);
```

| Druh | Kedy | Kto schvaľuje | Účinok |
| --- | --- | --- | --- |
| Výnimka z ceny | FIX pod cenou pre obchodníka alebo aditív pod minimom (podľa typu predajcu) | „schvaľuje ceny“ | hranica = schválená hodnota; ponuku treba odoslať do 3 dní |
| Rizikový zákazník | konkurz / reštrukturalizácia alebo rating E/X (Finstat) | „schvaľuje ceny“ | platí pre **celý obchod** (všetky verzie ponuky) **30 dní**, alebo kým sa údaje z Finstatu nezhoršia (nový konkurz alebo reštrukturalizácia, horší rating, nový dlh alebo vyššia suma dlhu oproti `risk_snapshot`); potom nové schválenie (odpoveď 9) |
| Predĺženie platnosti | obchodník chce dlhšiu platnosť | „schvaľuje ceny“ | `offer.valid_until` = nová hodnota; stránka ponuky ju hneď ukáže |
| Pridelenie firmy | firmu vlastní iný obchodník | príznak používateľa **„schvaľuje pridelenie firmy“** (Peter Kalman, Daniel Dérer, Denis Kalman; odpoveď 6) | `company.owner_id` = žiadateľ, pôvodný vlastník dostane upozornenie; jeho otvorené obchody ostávajú jemu |

- **Odoslanie ponuky** (`offer_send_check`) overí: každá položka ≥ hranica alebo ≥ schválená hodnota platnej výnimky; výnimka neexpirovala; pri rizikovom zákazníkovi schválenie existuje. Inak chyba s popisom, čo chýba.
- **Zmena variantu po schválení:** ak nová cena klesne pod schválenú hodnotu, treba novú žiadosť; zmena nad hodnotou schválenie nemení.
- **Schvaľovateľ nikdy neschvaľuje vlastnú žiadosť** (databáza).
- **Upozornenie** schvaľovateľom do zvončeka aj e-mailom z adresy CRM (časť 3.6); žiadateľovi výsledok do zvončeka.
- **Výnimka → zmluva:** časť 2.2.

### 1.9 E-maily (`email_thread`, `email_message`, `email_outbox`)

```sql
CREATE TABLE email_thread (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           uuid NOT NULL REFERENCES org (id),
  mailbox_user_id  uuid NOT NULL REFERENCES app_user (id),   -- schránka obchodníka, z ktorej vlákno vzniklo
  gmail_thread_id  text NOT NULL,
  subject          text,
  deal_id          uuid REFERENCES deal (id),
  company_id       uuid REFERENCES company (id),
  contact_id       uuid REFERENCES contact (id),
  offer_id         uuid REFERENCES offer (id),
  last_message_at  timestamptz,
  watch_until      date,                       -- dokedy sa kontrolujú odpovede: posledná aktivita + 30 dní (Peter 15. 10.)
  created_at, updated_at,
  UNIQUE (mailbox_user_id, gmail_thread_id),
  CHECK (num_nonnulls(deal_id, company_id, contact_id) >= 1)
);

CREATE TYPE email_kind AS ENUM ('ponuka', 'potvrdenie_akceptacie', 'pripomienka_platnosti', 'volny', 'odpoved');
CREATE TYPE email_status AS ENUM ('koncept', 'odosiela_sa', 'odoslany', 'chyba', 'prijaty');

CREATE TABLE email_message (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id         uuid REFERENCES email_thread (id),   -- NULL pri koncepte nového vlákna
  org_id            uuid NOT NULL REFERENCES org (id),
  kind              email_kind NOT NULL,
  status            email_status NOT NULL,
  direction         text NOT NULL CHECK (direction IN ('out', 'in')),
  gmail_message_id  text,
  rfc_message_id    text,                -- hlavička Message-ID (nadväznosť odpovedí)
  from_addr         text, to_addrs text[], cc_addrs text[],
  subject           text,
  body_html         text,                -- odoslané: náš text; prijaté: vyčistené HTML (bez skriptov, obrázkov z webu)
  body_text         text,
  attachments       jsonb NOT NULL DEFAULT '[]',   -- názov, typ, veľkosť, gmail attachment id (obsah sa neukladá)
  template_version_id uuid REFERENCES email_template_version (id),
  offer_id          uuid REFERENCES offer (id),
  sent_by           uuid REFERENCES app_user (id),
  occurred_at       timestamptz,         -- odoslanie / prijatie
  error             text,                -- bez osobných údajov
  created_at, updated_at
);

CREATE TABLE gmail_mailbox_state (     -- stav kontroly odpovedí pre schránku
  user_id         uuid PRIMARY KEY REFERENCES app_user (id),
  last_checked_at timestamptz,
  last_error      text,
  error_count     smallint NOT NULL DEFAULT 0
);
```

- **Časová os** obchodu a zákazníka číta `email_message` priamo (aktivita typu e-mail sa neduplikuje).
- **Prílohy prijatých e-mailov** sa neukladajú. Na stiahnutie ich API načíta z Gmailu podľa id (menej osobných údajov v CRM).
- **Koncept pripomienky platnosti** (zadanie 8) vznikne ako `email_message` so stavom koncept **2 pracovné dni pred koncom platnosti**, iba pri SPOT a VIWA (pri FIX a kombinácii nie); obchodník ho odošle jedným klikom (odpoveď 12).
- **Denník čítania schránok** (poistka k `gmail.readonly`, časť 3.1):

```sql
CREATE TABLE mailbox_access_log (      -- iba pridávanie, nemení sa ani nemaže (spúšťač)
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  mailbox_user_id  uuid NOT NULL REFERENCES app_user (id),  -- čia schránka
  gmail_thread_id  text NOT NULL,
  gmail_message_id text,
  method           text NOT NULL CHECK (method IN ('threads.get', 'messages.get', 'attachments.get', 'history.list')),
  triggered_by     uuid REFERENCES app_user (id),            -- NULL = Cron
  accessed_at      timestamptz NOT NULL DEFAULT now()
);
```
  Vidí ho admin v Nastavenia → Audit (filter „Čítanie schránok“).

### 1.10 Šablóny ponúk a e-mailov

```sql
CREATE TABLE offer_template_version (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        uuid NOT NULL REFERENCES org (id),
  kind          offer_kind NOT NULL,
  language      offer_language NOT NULL,
  version       smallint NOT NULL,
  status        text NOT NULL CHECK (status IN ('navrh', 'platna', 'nahradena')),
  sections      jsonb NOT NULL,   -- predmet, cenova_ponuka_body, platobne_podmienky / ostatne_podmienky,
                                  -- vseobecne_ustanovenia, pribeh, vizia, zavazna_objednavka
  defaults      jsonb NOT NULL,   -- zmluvná pokuta €/MWh (50 / 30), splatnosť 14, preddavky 100 % 1/12, 5. deň
  created_by    uuid REFERENCES app_user (id),
  published_at  timestamptz,
  published_by  uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (org_id, kind, language, version)
);
-- najviac jedna platná a jeden návrh pre druh × jazyk; platná verzia sa nemení (ako cenníky)

CREATE TABLE offer_asset (           -- obrázky PDF, spoločné pre všetky šablóny
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id    uuid NOT NULL REFERENCES org (id),
  code      text NOT NULL CHECK (code IN ('titulna', 'referencie_zakaznici', 'referencie_partneri', 'energeticky_mix')),
  mime      text NOT NULL CHECK (mime IN ('image/png', 'image/jpeg')),
  data      bytea NOT NULL CHECK (octet_length(data) <= 1048576),
  sha256    text NOT NULL,
  active    boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES app_user (id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE email_template_version (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     uuid NOT NULL REFERENCES org (id),
  code       text NOT NULL,          -- ponuka_dodavka, ponuka_vykup, ponuka_viwa, potvrdenie_akceptacie,
                                     -- pripomienka_platnosti, alebo vlastná (voľný e-mail)
  language   offer_language NOT NULL,
  name       text NOT NULL,
  version    smallint NOT NULL,
  status     text NOT NULL CHECK (status IN ('navrh', 'platna', 'nahradena', 'archiv')),
  subject    text NOT NULL,
  body_html  text NOT NULL,
  created_by uuid REFERENCES app_user (id),
  created_at, updated_at,
  UNIQUE (org_id, code, language, version)
);
```

- **Premenné** v tvare `«…»` (obrazovka 42), iba zo zoznamu povolených: «číslo ponuky», «platnosť», «oslovenie», «odkaz na ponuku», «výška preddavkov», «splatnosť faktúr», «zmluvná pokuta», «obchodník»… Neznáma premenná = chyba pri uložení.
- **História:** každá zmena = nová verzia; ponuka a e-mail si pamätajú verziu, s ktorou odišli. Platná verzia sa nemení.
- **Obrázky:** pôvodné súbory z `docs/dizajn/obrazovky/assets/` sa pribalia do aplikácie ako východiskové (migrácia ich nevkladá; pri prázdnej `offer_asset` sa použijú pribalené). Admin ich v Nastaveniach vymení (nová verzia, stará ostane kvôli odoslaným ponukám). Najväčší obrázok má 433 kB, preto stačí databáza a R2 netreba.
- **Kto mení:** šablóny ponúk admin; šablóny e-mailov admin a tím Marketing. Anglické texty pripravím a označím ako návrh na Petrovu kontrolu.
- **Interné e-maily** (schvaľovateľom, provízne listy) majú pevný text v kóde, nie šablónu.

### 1.11 Provízie (`commission`, `commission_claim`) – fáza F7

```sql
DROP TABLE commission_rule;            -- nepoužité; pravidlo je % obchodníka
DROP TYPE commission_status;
CREATE TYPE commission_status AS ENUM ('caka', 'uplatnena', 'zrusena');

CREATE TABLE commission_claim (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  number          text NOT NULL,                   -- CMSN-2026-0042
  user_id         uuid NOT NULL REFERENCES app_user (id),   -- jeden obchodník
  total_eur       numeric(12,2) NOT NULL,
  by_duration     jsonb NOT NULL,                  -- medzisúčty podľa trvania zmluvy (snímka)
  pdf_key         text,                            -- R2
  emailed_at      timestamptz,
  created_by      uuid REFERENCES app_user (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  voided_at       timestamptz,
  voided_by       uuid REFERENCES app_user (id),
  void_reason     text CHECK (void_reason IS NULL OR length(btrim(void_reason)) >= 3),
  source          text NOT NULL DEFAULT 'crm' CHECK (source IN ('crm', 'sales_portal')),
  legacy_id       text,                            -- Firestore id
  legacy_pdf_url  text,                            -- Google Drive (história)
  UNIQUE (org_id, number),
  CHECK ((voided_at IS NULL) = (void_reason IS NULL))
);

CREATE TABLE commission (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id           uuid NOT NULL REFERENCES org (id),
  deal_id          uuid REFERENCES deal (id),      -- NULL iba pri histórii zo Sales portálu
  user_id          uuid NOT NULL REFERENCES app_user (id),
  status           commission_status NOT NULL DEFAULT 'caka',
  won_at           date,
  duration_years   smallint,                       -- trvanie zmluvy (zoskupenie, obrazovka 41); NULL = neurčito
  volume_mwh       numeric(12,3),
  base_eur         numeric(12,2) NOT NULL,         -- pridaná hodnota obchodu
  pct              numeric(5,2) NOT NULL,
  amount_eur       numeric(12,2) NOT NULL,         -- round(base × pct / 100, 2)
  claim_id         uuid REFERENCES commission_claim (id),
  recalculated_at  timestamptz,
  source           text NOT NULL DEFAULT 'crm' CHECK (source IN ('crm', 'sales_portal')),
  legacy_id        text, legacy_hubspot_deal_id text, legacy_deal_name text,
  created_at, updated_at,
  CHECK ((source = 'crm') = (deal_id IS NOT NULL)),
  CHECK ((status = 'uplatnena') = (claim_id IS NOT NULL))
);
CREATE UNIQUE INDEX commission_deal_key ON commission (deal_id) WHERE status <> 'zrusena';
```

- **Vznik:** pri prechode obchodu do Vyhraté, ak má vlastník zapnuté „počítať provízie“.
- **Základ** = Σ pridanej hodnoty spárovaných podpísaných zmlúv obchodu za celé obdobie (modul 4, `contract_year_value_v`); pri zmluve na neurčito prvých 12 mesiacov dodávky (P1). **Záporná zmluva sa započíta voči kladnej; ak je súčet celého obchodu záporný, provízia je 0 €** (odpoveď 15).
- **Dátum prechodu 1. 11. 2026** (odpoveď 16) je **nastavenie** `commission_crm_from` (`app_setting`), nie konštanta v kóde – pred štartom Ostrého sa potvrdí alebo posunie (Peter 15. 10.). obchody vyhraté pred ním majú províziu iba zo Sales portálu, od neho iba z CRM. CRM províziu nezaloží, ak `deal.closed_at` < 1. 11. 2026 alebo ak k tomu istému HubSpot dealu (`deal.hubspot_id` = `commission.legacy_hubspot_deal_id`) už je provízia zo Sales portálu – kontrola v databáze.
- **Prepočet:** kým je provízia v stave Čaká, prepočíta ju zmena zmluvy (import, nočný beh) aj zmena % obchodníka. Uplatnená sa nemení (spúšťač).
- **Zrušená:** obchod prestal byť Vyhraté alebo vlastník má vypnuté provízie (portál takú províziu maže; CRM ju ponechá so stavom Zrušená kvôli auditu).
- **Uplatnenie** (jedna transakcia, na rozdiel od portálu): obchodník vyberie svoje provízie v stave Čaká → číslo `CMSN-RRRR-NNNN` z `doc_counter` → list → provízie Uplatnená → PDF (R2) a e-mail obchodníkovi a obchodnému riaditeľovi do fronty odosielania.
- **Zrušenie listu:** iba admin s dôvodom (aspoň 3 znaky); provízie späť na Čaká; PDF dostane pečiatku ZRUŠENÉ (nový súbor, pôvodný ostáva); číslo sa znova nepoužije.
- **Prehľad** (obrazovka 41): zoskupenie podľa trvania zmluvy, súčty nevyplatené / uplatnené tento mesiac / kvartál alebo rok (počítané podľa dátumu uplatnenia, nie výhry – portál tu sčítava aj čakajúce), filtre stav, obchodník, hľadanie.

**Prenos histórie zo Sales portálu** (pri štarte ostrej prevádzky, iba na čítanie):

| Firestore | CRM |
| --- | --- |
| `owners/{HubSpot owner ID}` (`commissionPercent`, `trackCommissions`, `email`) | `app_user.commission_pct`, `commission_enabled` (spárovanie podľa `hubspot_owner_id`, inak e-mailu) |
| `commission_claims` (číslo, obchodník, suma, `byYear`, `pdfUrl`, zrušenie) | `commission_claim` so `source = 'sales_portal'`, pôvodné číslo CMSN, odkaz na Drive |
| `commissions` (deal, názov, dátum, trvanie, objem, marža, %, provízia, stav, `claimId`) | `commission` so `source = 'sales_portal'`, `deal_id` NULL (uzavreté dealy sa z HubSpotu neprenášajú), pôvodné sumy |
| `settings/commission_counter` | `doc_counter` – CRM pokračuje po poslednom čísle roka |
| `prices_daily` | neprenáša sa do provízií; BL/PL história – časť 7 |
| `settings/*`, `settings_log`, `allowed_users` | neprenáša sa (cenové parametre má CRM vlastné) |

- História (`source = 'sales_portal'`) sa nemení a neprepočítava (spúšťač). **Čakajúce provízie zo Sales portálu** sa prenesú s pôvodnými sumami a **dajú sa uplatniť** v CRM (zmení sa iba stav a list); uplatnené a zrušené iba na čítanie (odpoveď 16).
- Export Firestore pripravím ako skript iba na čítanie, ktorý spustí Peter so svojím prihlásením do Google Cloud; výstup do `exports/` (obsahuje mená firiem a e-maily obchodníkov).

### 1.12 Nové polia (zadanie časť 17)

| Tabuľka | Polia | Kto mení |
| --- | --- | --- |
| `company` | `billing_emails text[]`, `social_enterprise boolean`, `contract_name text` („v zastúpení“); Finstat: `revenue_eur`, `profit_eur`, `finance_year`, `employees_range`, `founded_on`, `z_score numeric(6,2)`, `has_debts`, `debts jsonb` (veriteľ, suma), `insolvency_kind` (konkurz / reštrukturalizácia / NULL), `insolvency_since`, `cancelled`; existujúce `bank_account` (IBAN, s kontrolou formátu), `payment_rating`, `vat_payer`, `registry_entry` | Finstat polia iba načítanie z Finstatu; podklady aj Servis a Nákup (časť 2.4) |
| `contact` | `salutation text` (oslovenie v e-maile, napr. „pán Mráz“); existujúce `title`, `position`, `email`, `phone` | ako doteraz |
| `company_contact` | nová systémová rola `zastupca_zmluvy` (zástupca pre zmluvné vzťahy) v číselníku `rola_kontaktu` | |
| `oom` | `property_relation` (číselník `vztah_k_nehnutelnosti`), `has_ims boolean`, `created_from_deal_id`; existujúce `previous_supplier` | obchodník pri Pripravovanom, podklady aj Servis a Nákup |
| `app_user` | `position text`, `phone text`, `mobile text`, `gmail_enabled boolean` (pilot Gmailu), `commission_pct numeric(5,2) DEFAULT 40`, `commission_enabled boolean`, `approves_assignments boolean` („schvaľuje pridelenie firmy“, odpoveď 6), fotka v `app_user_photo (user_id, mime, data bytea ≤ 256 kB)` | admin; profil (fotka, telefóny) aj používateľ sám |
| `org` | sociálne siete do podpisu (`social_links jsonb`), adresa a web existujú | admin |
| `notification` | väzby `deal_id`, `offer_id`, `approval_id`, `commission_claim_id`; nové druhy v časti 1.14 | |

Číselník `vztah_k_nehnutelnosti` (podľa formulára Office portálu, odpoveď 18): Vlastník nehnuteľnosti, Spoluvlastník nehnuteľnosti, Nájomca nehnuteľnosti, Rodinný príslušník vlastníka, Oprávnený užívateľ nehnuteľnosti, Iný právny vzťah. Možnosti polí „typ výkupnej zmluvy“ a „model výpočtu výkupu“ ešte chýbajú (potrebné až v F5).

### 1.13 Pomocné objekty

- **`doc_counter`** `(org_id, kind ('ponuka', 'provizny_list'), year, last_value)` – číslovanie bez medzier v rámci transakcie (`UPDATE … RETURNING`).
- **`deal_event`** – časová os obchodu pre udalosti, ktoré nie sú e-mail ani poznámka: zmena štádia (z → do, kto), nová verzia ponuky, odoslanie, prvé otvorenie stránky, akceptácia, žiadosť a rozhodnutie schvaľovania, spárovaná zmluva, provízia. Stĺpce `deal_id, kind, occurred_at, user_id, offer_id, approval_id, contract_id, detail jsonb` (bez osobných údajov). Zapisujú ju spúšťače, nemení sa. Časová os = `deal_event` ∪ poznámky (`activity`) ∪ `email_message`.
- **`next_working_day(org, date)`** a **`offer_default_valid_until(org, sent_at, price_kind)`** – časť 6.
- **`company_risk(company)`** – zoznam výstrah (dlhy, nedoplatky, konkurz, rating E/X, Z-skóre pod 1,23) a príznak „treba schválenie“ (konkurz, rating E/X). Počíta sa, neukladá.

### 1.14 Upozornenia (nové druhy `notification.kind`)

| Druh | Kedy | Komu | E-mail |
| --- | --- | --- | --- |
| `dalsi_krok` | v deň ďalšieho kroku (nočný beh) | vlastník obchodu | nie |
| `schvalenie_nove` | nová žiadosť | schvaľovatelia podľa druhu | áno (z adresy CRM) |
| `schvalenie_rozhodnutie` | schválenie / zamietnutie | žiadateľ | nie |
| `pridelenie_firmy` | schválené pridelenie | pôvodný vlastník | nie |
| `ponuka_akceptovana` | akceptácia | vlastník obchodu | nie |
| `ponuka_odpoved` | odpoveď zákazníka vo vlákne | vlastník schránky | nie (príde mu do Gmailu) |
| `ponuka_pripomienka` | koncept pripomienky platnosti je pripravený | vlastník obchodu | nie |
| `obnova` | nočný beh založil obchod Obnova | obchodník zmluvy | nie |
| `cena_ina_ako_v_ponuke` | párovanie zmluvy | obchodník + schvaľovatelia cien | nie |
| `chyba_oom_na_zmluve` | 14 dní po akceptácii chýba OOM na zmluve | vlastník obchodu | nie |
| `nesparovana_zmluva` | zmluva bez jednoznačnej zhody | obchodník zmluvy (inak admini) | nie |
| `pomoc_s_ponukou` | žiadosť externého obchodníka | obchodný riaditeľ (schvaľovatelia cien) | áno |
| `gmail_chyba` | 3 chyby kontroly schránky za sebou | admini | nie |
| `provizny_list` | nový alebo zrušený list | obchodník + obchodný riaditeľ | áno (s PDF) |

### 1.15 Práva, RLS a audit

**Obchod a všetko pod ním** (`deal`, `deal_oom`, `deal_contact`, `deal_event`, `offer*`, `offer_acceptance`, `offer_page_stat`, `email_*` naviazané na obchod):

| Kto | Vidí | Mení |
| --- | --- | --- |
| Obchodník (interný), „iba svoje“ | obchody, ktoré vlastní, a obchody zákazníkov, ktorých vlastní | to isté |
| Externý obchodník | iba obchody, ktoré vlastní (aj v databáze) | to isté |
| Tím CEO, schvaľovateľ cien, „schvaľuje pridelenie firmy“ (`crm_sees_all_deals()`) | všetko v svojich spoločnostiach | všetko, vlastník obchodu |
| Servis (back office), Nákup | všetko (`view_scope = vsetko`) | iba podklady pre zmluvu a párovanie zmlúv (funkcie `SECURITY DEFINER` s kontrolou) |
| Admin | Nastavenia: šablóny, číselníky; zrušenie provízneho listu a akceptácie | |

- Funkcie `crm_deal_visible(deal)`, `crm_deal_editable(deal)` rovnakým vzorom ako `crm_contract_visible/editable` (modul 4).
- **Marža firmy** iba cez `offer_margin_v` s `crm_can_see_margin()`.
- **`approval_request`:** žiadateľ, schvaľovatelia daného druhu, pri pridelení aj pôvodný vlastník, admin.
- **Provízie:** vlastné; všetky admin, tím s „Provízie – všetko“ (CEO) a schvaľovateľ cien (obchodný riaditeľ je v tíme Sales_internal s „iba svoje“, rozhodnutie 2026-10-13).
- **Šablóny:** čítajú všetci; mení admin (ponuky), admin a Marketing (e-maily).
- **`crm_external_ready()`** sa po F1 rozšíri o RLS obchodov. Otvorená ostáva podmienka RLS na `audit_log` (STAV).
- **Audit:** `deal`, `deal_oom`, `deal_contact`, `offer`, `offer_variant`, `offer_item`, `offer_acceptance`, `approval_request`, `approval_price_item`, `offer_template_version`, `offer_asset` (bez obsahu obrázka), `email_template_version`, `commission`, `commission_claim`, nové stĺpce firmy, kontaktu, OOM a používateľa.
- **Bez auditu** (záznamy, ktoré sa nemenia, alebo technické): `deal_event`, `offer_page_stat`, `offer_year_basis`, `email_thread`, `email_message`, `gmail_mailbox_state`, `email_outbox`, `doc_counter`, `notification`, `finstat_cache`. `mailbox_access_log` je sám denníkom (iba pridávanie).
- **`crm_app`:** práva na nové tabuľky v `api/db/app-role.sql`; mazanie iba konceptov e-mailov a väzieb obchodu (OOM, kontakt).

---

## 2. Väzby na modul 4

### 2.1 Párovanie zmlúv z importu (zadanie časť 10)

```sql
ALTER TABLE contract
  DROP CONSTRAINT contract_deal_id_key,                    -- 1 obchod : n zmlúv
  ADD COLUMN offer_variant_id uuid REFERENCES offer_variant (id),
  ADD COLUMN deal_match       text CHECK (deal_match IN ('auto', 'rucne', 'bez_obchodu')),
  ADD COLUMN deal_matched_at  timestamptz,
  ADD COLUMN deal_matched_by  uuid REFERENCES app_user (id),
  ADD CONSTRAINT contract_deal_match_check CHECK ((deal_id IS NOT NULL) = (deal_match IN ('auto','rucne')));
ALTER TYPE contract_flag_code ADD VALUE 'cena_ina_ako_v_ponuke';
```

**Ktoré zmluvy sa párujú:** zmluvy prvýkrát importované po dátume spustenia párovania (nastavenie `deal_matching_from`, aby sa staré zmluvy z prvého importu neobjavili ako nespárované), vo fáze inej ako Odmietnutá alebo Neúspešná, bez obchodu a bez „bez obchodu“.

**Postup** (funkcia `contract_deal_match`, volá ju uloženie importu po zápise zmlúv; spúšťa sa aj ručne):
1. **Kandidáti:** obchody toho istého zákazníka a zodpovedajúceho druhu (dodávka firma NN/VN → B2B dodávka; domácnosť → B2C; výkup → B2B výkup; VIWA → Green VIWA), ktoré sú:
   - v Akceptácii alebo Vyjednávaní, **alebo**
   - Vyhraté z párovania, ak OOM tejto zmluvy sú v akceptovanom variante a ešte nie sú na inej zmluve toho obchodu (druhá zmluva VN).
2. **Zhoda:** všetky OOM zmluvy (EIC) sú v akceptovanom variante obchodu (vo Vyjednávaní v OOM obchodu).
3. **Jednoznačná zhoda** (práve jeden kandidát): `contract.deal_id`, `offer_variant_id`, `deal_match = 'auto'`; obchod pri prvej zmluve → Vyhraté (`closed_at`); udalosť v časovej osi.
4. **Žiadna alebo viac zhôd:** zmluva ostane nespárovaná → zoznam „Nespárované zmluvy“ (obrazovka 40) s kandidátmi a dôvodom; upozornenie `nesparovana_zmluva`. Obchodník zákazníka alebo admin vyberie obchod (`rucne`) alebo „Bez obchodu“. **Zmluva domácnosti, ktorá nemá otvorený obchod B2C, sa automaticky označí „Bez obchodu“** (odpoveď 7).
5. **Kontrola cien:** pre každé OOM a rok porovná komoditu zmluvy (`contract_price`) s akceptovaným variantom (`offer_item`): FIX VT/NT, aditív € alebo %. Rozdiel nad 0,0001 → príznak `cena_ina_ako_v_ponuke` (rok, text bez osobných údajov) a upozornenie. Príznak uzatvára schvaľovateľ cien s poznámkou (rovnako ako „Pod hranicou“).
6. **Chýbajúce OOM:** nočný beh 14 dní po akceptácii pošle `chyba_oom_na_zmluve` raz, ak niektoré OOM akceptovaného variantu nie je na zmluve obchodu.

**Zrušenie spárovania** (admin, s dôvodom): zmluva späť medzi nespárované; obchod sa vráti do Akceptácie, ak už nemá inú zmluvu; čakajúca provízia sa prepočíta alebo zruší.

### 2.2 Výnimka z ponuky → zmluva

- Pri spárovaní dostane zmluva pre každý rok, pre ktorý má akceptovaný variant schválenú výnimku (zhodný rok, model a napäťová skupina zmluvy), záznam `price_exception` so stavom **Použitá** (`contract_id`, nový stĺpec `approval_request_id`, hodnota = schválená hranica).
- `contract_year_basis.exception_id` sa prepočíta → schválená hranica je hranicou pre pridanú hodnotu (modul 4, časť 6). Príznak „Pod hranicou bez výnimky“ sa tým uzavrie sám.
- Párovanie výnimiek modulu 4 (zákazník + rok + model, 30 dní) sa pre zmluvy spárované s obchodom nepoužije; pre zmluvy bez obchodu ostáva.
- Obrazovka 28 (Výnimky) ukáže aj výnimky z ponúk (iba na čítanie, odkaz do Schvaľovania).

### 2.3 Nočný beh zakladá obchod „Obnova“

Doplnenie kroku 5 v `contract_daily_run_at` (upozornenie 4 mesiace pred koncom):
- **Podmienky:** zákazník je firma (domácnosti nie), zmluva nemá nástupcu, k zmluve nie je otvorený obchod Obnova (`deal_open_renewal_key`).
- **Už existuje bežný otvorený obchod** rovnakého druhu, ktorý obsahuje niektoré OOM zo zmluvy (Peter 15. 10.): Obnova sa **nezaloží**; tomu obchodu sa iba doplní predošlá zmluva (`previous_contract_id`, ak ju ešte nemá) a zapíše sa to do časovej osi („predošlá zmluva doplnená nočným behom“).
- **Obchod:** názov „Obnova – {číslo zmluvy}“, pipeline podľa typu zmluvy (dodávka NN/VN → B2B dodávka, výkup → B2B výkup, VIWA → Green VIWA), štádium Príležitosť, zdroj Obnova, `previous_contract_id`, vlastník = obchodník zmluvy (ak je neaktívny alebo chýba, vlastník zákazníka, inak admini dostanú upozornenie), očakávané uzavretie = koniec zmluvy − 1 mesiac, začiatok dodávky = deň po konci.
- **OOM:** OOM zmluvy, ktoré sú ešte Aktívne alebo Pripravované, s objemami zo zmluvy (`contract_oom.qty_*`; výkup a VIWA plán výkupu a výkon).
- **Kontakty:** kontakty z prechádzajúceho obchodu zmluvy, inak hlavný kontakt firmy.
- Upozornenie `obnova` nahradí pre obchodníka samostatné `konci_4_mesiace` (jedno upozornenie s odkazom na obchod).
- Pri spárovaní novej zmluvy s obchodom Obnova sa nová zmluva navyše prepojí `previous_contract_id` (modul 4 to už robí podľa OOM).

### 2.4 Príznaky a podklady pre zmluvu

- **„Cena iná ako v ponuke“** – nová hodnota `contract_flag_code` (časť 2.1, bod 5).
- **„Bez obchodu“** – nie je problém na riešenie, ale rozhodnutie. Preto nie je v `contract_flag`, ale v stĺpci `contract.deal_match = 'bez_obchodu'` (kto a kedy). V zozname zmlúv sa zobrazí ako príznak a filter.
- **Podklady pre zmluvu** (zadanie 9, obrazovka 38): údaje zmluvy, ktoré sa neukladajú k firme, kontaktu ani OOM, sú v tabuľke `deal_contract_input`:

```sql
CREATE TABLE deal_contract_input (
  deal_id               uuid PRIMARY KEY REFERENCES deal (id) ON DELETE CASCADE,
  billing_period        text,     -- obdobie fakturácie (číselník OOM)
  contract_close_reason contract_close_reason DEFAULT 'akvizicia',
  auto_prolong          boolean DEFAULT true,
  product_line          text DEFAULT 'Greenlogy',
  feed_in_contract_type text,     -- výkup: typ výkupnej zmluvy
  feed_in_calc_model    text,     -- výkup: model výpočtu
  representative_contact_id uuid REFERENCES contact (id),   -- zástupca pre zmluvné vzťahy
  updated_by uuid, updated_at timestamptz
);
```

- Ostatné polia (IBAN, fakturačné e-maily, platca DPH, sociálny podnik, „v zastúpení“, vzťah k nehnuteľnosti, IMS, predchádzajúci dodávateľ, zástupca) sa ukladajú k firme, kontaktu a OOM funkciou `deal_contract_input_save`, ktorú smie obchodník obchodu, Servis a Nákup.
- **Úplnosť** „12/14“ počíta `deal_contract_input_missing(deal)` (zoznam chýbajúcich polí podľa druhu zmluvy).
- **Rozdelenie NN / VN** a názvy produktov Office portálu (`GREEN_1T_INDIVIDUAL_2027`) sa počítajú pri zobrazení (prekladová tabuľka `import_alias`, opačný smer).
- Prehľad „Čaká na zmluvu“ = obchody v Akceptácii s počtom očakávaných a spárovaných zmlúv a lehotou 14 dní.

---

## 3. Gmail cez Google Workspace

### 3.1 Princíp

- **Servisný účet s delegovaním na doménu** (domain-wide delegation). Worker si pre konkrétneho obchodníka vyžiada krátkodobý prístupový token „v jeho mene“ a cez Gmail API odošle e-mail z jeho schránky. E-mail je v jeho Odoslaných a odpovede mu chodia normálne.
- **Oprávnenia (scopes):**
  - `https://www.googleapis.com/auth/gmail.send` – odoslanie;
  - `https://www.googleapis.com/auth/gmail.readonly` – čítanie odpovedí.
- **Dôležité obmedzenie:** Google **nemá oprávnenie „iba vlákna, ktoré založila aplikácia“**. `gmail.readonly` technicky dovoľuje čítať celú schránku. Slabšie `gmail.metadata` nedovolí prečítať text odpovede, takže nestačí. Obmedzenie na vlákna CRM preto zabezpečí **náš kód** (poistky podľa Petra, 15. 10.):
  1. **Iba `threads.get` a `messages.get`** (a `attachments.get` pri stiahnutí prílohy) na `gmail_thread_id` uložené v `email_thread`. **Nikdy `messages.list`, `threads.list` ani vyhľadávanie (`q`).**
  2. **Jedna funkcia** `gmailRead(mailbox, threadId, …)` v `api/src/gmail.ts` je jediné miesto, ktoré volá čítanie Gmail API. Pred volaním overí v databáze, že vlákno patrí CRM a schránke; iné cesty kód nemá (kontrola v teste: žiadny iný súbor nevolá `gmail.googleapis.com` na čítanie, a funkcia odmietne neznáme vlákno aj „list“/„search“).
  3. **Každé čítanie** sa zapíše do `mailbox_access_log` (čia schránka, thread_id, message_id, metóda, kto/Cron, čas) – časť 1.9.
  4. Kľúč servisného účtu **iba vo `wrangler secret`** (časť 3.3).
  5. **Delegovanie sa zapína postupne (pilot):** príznak `app_user.gmail_enabled` (mení admin). Token sa vyžiada iba pre aktívneho používateľa s @greenlogy.com a zapnutým príznakom; ostatní e-mail z CRM neodošlú (tlačidlo „Stiahnuť PDF“ ostáva).
  - **Kontrola odpovedí bez `history.list`?** `history.list` vráti iba id zmien celej schránky (bez obsahu), CRM z nich ponechá iba svoje vlákna. Ak je to pre teba príliš široké, Cron môže namiesto toho volať `threads.get` na každé sledované vlákno (viac požiadaviek, ale nikdy nič mimo CRM). **Návrh: iba `threads.get`** – presne podľa poistky 1; pri ~25 schránkach a desiatkach otvorených vlákien je to stále málo požiadaviek.
- **Externí obchodníci** dostanú adresy na greenlogy.com (rozhodnutie R2).

### 3.2 Podpis JWT vo Workeri

- Knižnica **`jose`** (už ju používame na overenie tokenu Access) vie podpísať JWT kľúčom RS256 vo Workeri (WebCrypto). **Nová závislosť netreba.**
- Postup pre schránku `obchodnik@greenlogy.com`:
  1. JWT: `iss` = e-mail servisného účtu, `sub` = e-mail obchodníka, `scope` = obe oprávnenia, `aud` = `https://oauth2.googleapis.com/token`, `iat`, `exp` = +1 hodina.
  2. Podpis súkromným kľúčom servisného účtu (`importPKCS8`, RS256).
  3. `POST https://oauth2.googleapis.com/token` s `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer` → prístupový token na 1 hodinu.
  4. Token ostáva iba v pamäti Workera (najviac 55 minút), nikam sa neukladá ani neloguje.
- **Odoslanie:** `POST /upload/gmail/v1/users/me/messages/send?uploadType=multipart` so správou MIME (HTML + text, PDF v prílohe, fotka podpisu ako vložený obrázok `cid:`, bez sledovacích pixelov). Pri odpovedi vo vlákne `threadId` a hlavičky `In-Reply-To` / `References`. Limit prílohy 35 MB, PDF ponuky bude rádovo 1–2 MB.

### 3.3 Uloženie kľúča

- JSON kľúč servisného účtu ide **iba** cez `wrangler secret put GOOGLE_SA_KEY` (Test a Ostré zvlášť) a lokálne do `.dev.vars`. Do repozitára ani do chatu nikdy; vkladá ho Peter.
- Kód číta z kľúča iba `client_email` a `private_key`.
- **Výmena kľúča** raz ročne alebo pri podozrení: nový kľúč v Google Cloud → `wrangler secret put` → zmazať starý kľúč v Google Cloud.
- **Test:** odosielanie na Teste iba na adresy @greenlogy.com a na zoznam povolených adries v `MAIL_ALLOWLIST` (`wrangler secret` / `.dev.vars`), aby sa skúšobná ponuka nedostala k zákazníkovi (odpoveď 10). Kontrola je v tej istej funkcii, ktorá odosiela; na Ostrom sa premenná nenastaví.

### 3.4 Kontrola odpovedí každých 5 minút

- Nový Cron Workera `*/5 * * * *` (k dnešným nočným časom). Obsluha `scheduled` rozlíši časovač podľa `event.cron`.
- **Iba vlákna s aktivitou za posledných 30 dní** (`watch_until ≥ dnes`, Peter 15. 10.). Staršie vlákno sa znova zaradí, keď z neho CRM odošle správu (odoslanie posunie `watch_until`).
- Pre každé sledované vlákno (schránka so zapnutým Gmailom):
  1. `threads.get` s `format=metadata` (iba id správ a hlavičky) cez `gmailRead`;
  2. nové správy (id, ktoré ešte nie sú v `email_message`) načíta `messages.get` a uloží do `email_message` (smer `in`, vyčistený text, zoznam príloh bez obsahu), posunie `last_message_at` a pošle upozornenie `ponuka_odpoved`;
  3. každé volanie zapíše do `mailbox_access_log`.
- `history.list` sa nepoužíva (poistka 1); `gmail_mailbox_state.history_id` odpadá, tabuľka drží iba stav a chyby.
- Chyba jednej schránky nezastaví ostatné (`gmail_mailbox_state.last_error`); po 3 chybách za sebou dostanú admini upozornenie `gmail_chyba`.
- **Limity Gmail API:** `threads.get` (metadata) stojí 10 jednotiek, `messages.get` 5; limit je 250 jednotiek za sekundu na používateľa. Cron volá schránky postupne, najviac 10 požiadaviek za sekundu na schránku, a pri odpovedi 429 / `rateLimitExceeded` čaká s narastajúcim odstupom (a zvyšok presunie na ďalší beh).
- Odhad záťaže: desiatky sledovaných vlákien × 288 behov denne = rádovo tisíce požiadaviek denne, hlboko pod limitmi Gmail API.

### 3.5 Fronta odosielania (`email_outbox`)

- E-maily, ktoré nevznikajú priamo klikom obchodníka (potvrdenie akceptácie, provízny list, interné upozornenia), sa zapíšu do `email_outbox` a odošle ich Cron. Používa sa aj pri chybe Gmailu (opakovanie 3×).
- Potvrdenie akceptácie odíde **zo schránky obchodníka do vlákna ponuky**, najneskôr do 5 minút.
- Odoslanie klikom (ponuka, voľný e-mail) ide hneď; pri chybe ostane koncept s textom chyby.

### 3.6 Adresa CRM pre interné e-maily

- Interné e-maily (schvaľovateľom, provízne listy) z adresy `crm@greenlogy.com`. Delegovanie funguje iba pre skutočného používateľa Workspace, nie pre skupinu ani alias – Peter ho založí (odpoveď 8). Schránka `crm@` iba odosiela; CRM z nej nečíta.

### 3.7 Čo treba nastaviť v Google Workspace (Peter, krok po kroku)

Nič z toho sa nerobí teraz; až pri fáze F4.

1. **Google Cloud Console** (console.cloud.google.com, účet správcu greenlogy.com):
   1. Vytvoriť projekt „greenlogy-crm“ (v organizácii greenlogy.com).
   2. APIs & Services → Library → zapnúť **Gmail API**.
   3. IAM & Admin → Service Accounts → **Create service account** „crm-gmail“. Žiadne roly v projekte nepridávať.
   4. Pri servisnom účte → Keys → Add key → **JSON**. Súbor sa stiahne. Ak to zakáže politika organizácie (`iam.disableServiceAccountKeyCreation`), postupujte podľa bodu 1a.
   5. Opísať **Unique ID** (Client ID, číslo) servisného účtu.

   **1a. Ak organizácia blokuje vytváranie kľúčov** (hláška „Service account key creation is disabled“ – pravidlo `iam.disableServiceAccountKeyCreation`, v nových organizáciách Google ho zapína predvolene). Výnimka **iba pre projekt CRM**, pravidlo pre zvyšok organizácie ostáva:
   1. Účet správcu potrebuje rolu **Organization Policy Administrator** (`roles/orgpolicy.policyAdmin`) na úrovni **organizácie**: IAM & Admin → IAM → v hornom výbere zvoliť organizáciu greenlogy.com → Grant access → účet správcu → rola „Organization Policy Administrator“ → Save. (Rolu má iba správca organizácie; po vytvorení kľúča ju môžete odobrať.)
   2. V hornom výbere zvoliť **projekt greenlogy-crm** (nie organizáciu) → IAM & Admin → **Organization Policies**.
   3. Vyhľadať „**Disable service account key creation**“ (`iam.disableServiceAccountKeyCreation`; ak je tam aj „managed“ verzia `iam.managed.disableServiceAccountKeyCreation`, upraviť tú, ktorá je vynútená).
   4. **Manage policy** → Policy source: **Override parent's policy** → Rules: **Add a rule** → Enforcement: **Off** → **Set policy**. Prejavenie trvá zvyčajne do 2 minút.
   5. Vytvoriť kľúč JSON podľa bodu 4.
   6. Odporúčanie: pravidlo pre projekt znova zapnúť (Manage policy → Inherit parent's policy → Set policy). Vytvorený kľúč funguje ďalej; pri ročnej výmene kľúča sa výnimka zopakuje.
   - Rovnako cez `gcloud` (Cloud Shell, ako správca): `gcloud resource-manager org-policies disable-enforce iam.disableServiceAccountKeyCreation --project=greenlogy-crm` a po vytvorení kľúča `gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --project=greenlogy-crm` (projekt znova dedí pravidlo organizácie).
2. **Google Admin** (admin.google.com):
   1. Security → Access and data control → **API controls** → **Manage Domain Wide Delegation** → Add new.
   2. Client ID = číslo z bodu 1.5; OAuth scopes (presne, oddelené čiarkou):
      `https://www.googleapis.com/auth/gmail.send,https://www.googleapis.com/auth/gmail.readonly`
   3. Uložiť. Prejavenie trvá do niekoľkých minút až 24 hodín.
   4. Users: založiť adresy na greenlogy.com obchodníkom s gmail.com a používateľa `crm@greenlogy.com`. Overiť, že majú zapnutý Gmail.
   5. Delegovanie platí technicky pre celú doménu; ktorí používatelia ho v CRM naozaj používajú, určuje príznak „Gmail zapnutý“ v CRM (pilot, zapína admin postupne).
3. **Kľúč do Workera** (Peter v termináli, súbor sa nikam nekopíruje):
   ```
   cd ~/projects/greenlogy/crm-core/api && npx wrangler secret put GOOGLE_SA_KEY < ~/Downloads/greenlogy-crm-XXXX.json
   ```
   Potom stiahnutý súbor zmazať z Downloads.
4. **Skúška:** CRM má v Nastaveniach tlačidlo „Overiť spojenie s Gmailom“, ktoré pre prihláseného používateľa vyžiada token a prečíta iba profil schránky (adresu), nič iné.

---

## 4. PDF ponuky

### 4.1 Odporúčanie: Cloudflare Browser Rendering

| Možnosť | Za | Proti |
| --- | --- | --- |
| **Browser Rendering** (Chromium v Cloudflare, `@cloudflare/puppeteer`, binding `BROWSER`) | PDF z **toho istého HTML** ako náhľad (obrazovka 35) a stránka ponuky; slovenské znaky, tabuľky, zalomenie strán cez CSS; rovnaký spôsob pre provízny list | nová služba v Cloudflare; render 2–5 s; miesto spracovania treba overiť (nižšie) |
| Knižnica bez prehliadača (`pdf-lib`) | rýchle (~0,1 s), beží priamo vo Workeri | každý prvok sa kreslí súradnicami (zalomenie textu, tabuľky, strany ručne); dvojitá práca s HTML náhľadom; knižnica sa od 2021 nevyvíja |
| Typst / iné cez WASM | kvalitná sadzba | príliš veľké pre Worker (limit veľkosti) |

**Návrh: Browser Rendering.**
- Worker zostaví HTML ponuky (jedna funkcia pre náhľad, PDF aj stránku), obrázky vloží priamo do HTML (`data:`), takže prehliadač nič nesťahuje z CRM za Access ani z internetu.
- `page.setContent(html)` → `page.pdf({ format: 'A4', printBackground: true })` → SHA-256 → uloženie do **R2** (bucket s jurisdikciou EÚ) → `offer.pdf_key`, `pdf_sha256`.
- PDF sa generuje **pri odoslaní** (vtedy je známa platnosť) a potom sa nemení. Náhľad počas úprav sa generuje na požiadanie a neukladá sa.
- **Výkon a cena:** jedna ponuka ~3 s prehliadača. Platený plán Workers má 10 hodín prehliadača mesačne v cene, bezplatný 10 minút denne (~150 ponúk denne). Pri desiatkach ponúk denne je cena prakticky nulová. Súbežne sa generuje najviac jedno PDF na požiadavku.
- **EÚ:** dáta v pokoji ostávajú v EÚ (Neon Frankfurt, R2 s jurisdikciou EÚ). Samotné vykreslenie prebehne v sieti Cloudflare, rovnako ako dnes každá požiadavka Workera; Cloudflare je už sprostredkovateľ. Dokumentácia Cloudflare (služba sa dnes volá **Browser Run**) neuvádza voľbu regiónu pre prehliadač (overené 15. 10. 2026); jurisdikciu EÚ majú R2, D1, KV a Durable Objects. Ak by to bola podmienka, záložné riešenie je `pdf-lib`.
- **Cena:** časť 12.

### 4.2 Úložisko PDF: R2

- Bucket `crm-dokumenty` (Test a Ostré zvlášť), **jurisdikcia EÚ**, súkromný (bez verejnej adresy).
- Kľúče: `ponuky/{org}/{rok}/{číslo-verzia}.pdf`, `akceptacie/…`, `provizne-listy/…`, `podpisane/…`.
- Súbory sa neprepisujú; zrušený provízny list = nový súbor s pečiatkou.
- Do databázy iba kľúč a odtlačok. Ukladať PDF do Postgresu by pri ~1,5 MB na ponuku rýchlo minulo kapacitu Neonu.
- Peter súhlasil so zapnutím R2 (bucket s jurisdikciou EÚ) a Browser Rendering, plán Workers Paid (odpoveď 17). Zapína sa až pred F3, po odsúhlasení odhadu ceny (časť 12).

### 4.3 Obsah PDF

Podľa zadania 7.1 a obrazovky 35. Navyše:
- produkty sa zlúčia: rovnaký produkt, napätie a cena → jeden riadok so súčtom objemu; OOM ani EIC v PDF nie sú;
- číslo strany a číslo ponuky v päte;
- záväzná objednávka s variantmi na výber, lehotou 14 dní a zmluvnou pokutou zo šablóny (dodávka 50 €/MWh, výkup 30 €/MWh); pri VIWA „Prijatie ponuky“ bez pokuty;
- **potvrdenie akceptácie** = rovnaké PDF ponuky + vyplnená záväzná objednávka (čas do sekúnd, meno, funkcia, IP, odtlačok znenia), uložené zvlášť.

---

## 5. Verejná stránka ponuky

### 5.1 Mimo Cloudflare Access: samostatný Worker

- Hlavný Worker `crm-core` je celý za Access („All traffic“). Výnimku pre jednu cestu na adrese `workers.dev` nastaviť nejde a miešať verejné a chránené cesty v jednom Workeri je zbytočné riziko.
- **Návrh:** samostatný malý Worker **`crm-ponuka`**:
  - vlastná adresa (na Teste `*.workers.dev`, na Ostrom **`ponuka.greenlogy.com`**, odpoveď 19 – vyžaduje doménu greenlogy.com v Cloudflare DNS alebo záznam CNAME podľa návodu Cloudflare);
  - vlastné pripojenie k databáze s rolou **`crm_public`**, ktorá nemá prístup k žiadnej tabuľke, iba `EXECUTE` na tri funkcie `SECURITY DEFINER`:
    - `offer_public_view(token_hash)` – údaje na zobrazenie (+ započíta otvorenie),
    - `offer_public_pdf(token_hash)` – kľúč PDF v R2,
    - `offer_public_accept(token_hash, variant, meno, funkcia, ip, prehliadač, odtlačok_znenia)`;
  - R2 iba na čítanie PDF; žiadne tajomstvá Gmailu ani Finstatu.
- Aj keby niekto Worker zneužil, databáza mu nevráti nič iné ako jednu ponuku podľa platného tokenu.

### 5.2 Token a obmedzenie pokusov

- **Token:** 32 náhodných bajtov (`crypto.getRandomValues`, 256 bitov), v adrese ako base64url (43 znakov): `/p/{token}`. V databáze iba SHA-256 tokenu; z databázy sa odkaz zrekonštruovať nedá.
- Jeden token na verziu ponuky, vzniká pri odoslaní.
- **Platnosť odkazu:** do `valid_until` akceptácia, potom do `valid_until + 30 dní` iba čítanie s textom „Platnosť ponuky uplynula“; potom stránka „Odkaz už neplatí“ (bez údajov).
- **Obmedzenie pokusov** (Workers Rate Limiting binding, podľa IP):
  - zobrazenie: 30 požiadaviek za minútu;
  - neplatný token: 10 za 10 minút, potom 429 na hodinu;
  - akceptácia: 5 za hodinu.
  - Na Ostrom navyše pravidlo WAF na doméne.
- **Hlavičky:** `Referrer-Policy: no-referrer` (token je v adrese), `X-Robots-Tag: noindex`, prísna CSP bez skriptov tretích strán (žiadny PostHog), `Cache-Control: no-store`.

### 5.3 Čo sa zobrazí a čo nie

| Zobrazí sa | Nezobrazí sa |
| --- | --- |
| číslo a dátum ponuky, názov zákazníka, počet OOM a plánovaný odber (spolu, NN/VN) | EIC, adresy a údaje jednotlivých OOM, iné OOM zákazníka |
| varianty: obdobie, ceny podľa produktu a napätia (ako PDF), flexibilita, pri SPOT vzorec ocenenia a odkaz na OKTE | cena pre obchodníka, hranica, pridaná hodnota, marža, provízia |
| podmienky, platnosť do 16:00 DD. MM. RRRR | výnimky, schvaľovanie, interné stavy a poznámky |
| PDF na stiahnutie, kontakt obchodníka (meno, funkcia, e-mail, telefón) | iné ponuky a verzie, história e-mailov |
| formulár akceptácie, po akceptácii „Akceptované dňa … (variant …)“ | IP adresy, počty otvorení |

Pri domácnosti ceny s DPH, mesačné poplatky a odhad ročných nákladov ako v PDF.

### 5.4 Zápis akceptácie

1. Stránka zobrazí znenie záväznej objednávky (pri VIWA prijatia ponuky) vyskladané zo šablóny a údajov ponuky.
2. Znenie sa pred výpočtom odtlačku zjednotí (Unicode NFC, konce riadkov `\n`, bez nadbytočných medzier). Stránka odošle so žiadosťou odtlačok znenia, ktoré zákazník videl.
3. `offer_public_accept` v jednej transakcii zamkne ponuku, znovu vyskladá znenie, overí zhodu odtlačku, stav a platnosť (čas databázy), uloží `offer_acceptance` (čas, IP z `CF-Connecting-IP`, prehliadač, meno, funkcia, variant, znenie, odtlačok, odtlačok PDF) a vykoná kroky z časti 1.7.
4. Opakované odoslanie (dvojklik) vráti ten istý výsledok, druhý záznam nevznikne.
5. IP sa zapisuje **iba pri akceptácii** (zadanie 20); otvorenia sa počítajú bez IP.
6. Potvrdenie s PDF odíde e-mailom z fronty (časť 3.5).

### 5.5 SK / EN

- Jazyk ponuky (`offer.language`) určuje **obsah**: texty, záväzná objednávka a jej odtlačok, PDF.
- Prepínač SK/EN na stránke mení iba popisky stránky (tlačidlá, nadpisy). Právny text ostáva v jazyku ponuky, aby zákazník prijímal presne to znenie, ktoré je v PDF.

---

## 6. Pracovné dni a sviatky SR pre platnosť ponuky

- Zdroj: `business_calendar` spoločnosti (SK sviatky 2026–2028 a firemné voľno z modulu 0). Nová tabuľka netreba.
- Nové funkcie:
  - `next_working_day(org, d date) → date` – prvý pracovný deň **po** dni `d`;
  - `offer_default_valid_until(org, sent_at timestamptz, price_kind) → timestamptz`:
    - FIX, kombinácia a cenník → `next_working_day(lokálny dátum odoslania)` o 16:00 Europe/Bratislava;
    - SPOT a VIWA → lokálny dátum odoslania + 14 kalendárnych dní o 16:00; ak to nie je pracovný deň, posun na nasledujúci pracovný deň (odpoveď 12);
    - kombinácia FIX + SPOT platí podľa FIX.
  - `working_days_before(org, d date, n) → date` – pre koncept pripomienky 2 pracovné dni pred koncom platnosti (iba SPOT a VIWA).
- Ak kalendár deň nepokrýva, funkcia skončí chybou (ako `add_business_minutes`). Rok 2029 treba doplniť migráciou do konca roka 2028 (STAV).
- **Kontrolné príklady:**
  - odoslané v piatok 10:00 → pondelok 16:00 (zadanie, príklad 5);
  - odoslané v piatok 17:30 → pondelok 16:00;
  - odoslané 30. 12. 2026 → 31. 12. 2026 16:00;
  - odoslané 31. 12. 2026 → 1. 1. a 6. 1. sú sviatky, 2. – 3. 1. víkend → pondelok 4. 1. 2027 16:00.
- **Skrátenie** obchodníkom: iba na skôr, nie do minulosti. **Predĺženie**: iba cez schválenie (časť 1.8).
- **Vypršanie** sa počíta (`now() > valid_until`), netreba Cron. Stránka a odoslanie ho kontrolujú v čase databázy.

---

## 7. Cockpit: ceny pre obchodníka a SPOT

### 7.1 Čo Cockpit poskytuje dnes

- Cockpit **nemá vlastnú databázu na Neone**. Ceny sú vo Firestore (`greensaleshub/prices_daily`) a v dvoch Workeroch:
  - **`greenlogy-montel-auth`** (kľúč `X-API-Key`), údaje priamo z Montelu:
    - `/forwards/ohlc/history?days=…` – denná história settlementov BL a PL pre roky 2027–2030 (najviac 1 000 dní, teda celé obdobie od 1. 1. 2026);
    - `/forwards/quotes` – aktuálny settlement;
    - `/spot/aggregates` – agregáty OKTE vrátane **`spotAvg365`** (priemer za 12 mesiacov);
  - **`greenlogy-data-fetcher`** – po pracovných dňoch o 6:05 zapíše forwardy a o 12:05 SPOT do `prices_daily` (Sales portál z nich číta).
- CRM dnes ceny zadáva ručne (`market_price_daily`, obrazovka 29), funkcia `trader_price` počíta cenu pre obchodníka k ľubovoľnému dňu z parametrov platných v ten deň.

### 7.2 Návrh: CRM číta priamo z Workera Montel

- **Denný beh v CRM** (Cron, po pracovných dňoch o 7:00 a 13:00 Europe/Bratislava):
  - BL a PL pre roky dodávky (bežný rok + 3) z `/forwards/quotes` → `market_price_daily` so zdrojom `cockpit` (ručná hodnota toho istého dňa sa neprepíše, ako je navrhnuté v module 4);
  - `spotAvg365` z `/spot/aggregates` → nová tabuľka `spot_average_daily (org_id, on_date, avg_12m_eur_mwh, source)`.
- **Spojenie** (odpoveď 20, schválené): Service binding na Worker `greenlogy-montel-auth` (rovnaký účet Cloudflare, bez verejnej siete), **iba na čítanie** – CRM volá výlučne GET `/forwards/quotes`, `/forwards/ohlc/history` a `/spot/aggregates` (zoznam povolených ciest v jednej funkcii). Kľúč `MONTEL_API_KEY` iba cez `wrangler secret`.
- **História od 1. 1. 2026** pre graf (obrazovka 30): jednorazový skript vlastníka databázy z `/forwards/ohlc/history` (zdroj `historia`) a kontrolné porovnanie s `prices_daily` vo Firestore. Graf a dlaždice = `trader_price(rok, deň)` pre každý pracovný deň, **vzorcom CRM z cenových parametrov modulu 4**. Rozdiel oproti Sales portálu je v poriadku (odpoveď 20).
- **Víkendy a sviatky:** dlaždice ukážu poslednú platnú hodnotu s poznámkou „settlement z …“ (už to robí 7-dňový mostík v `trader_price`).
- Tým sa zároveň vyrieši ručné zadávanie cien z modulu 4 a časť odloženej fázy F5 („História BL/PL“).

### 7.3 Čo treba doplniť v Cockpite

- Nič povinné. Endpointy existujú.
- Odporúčanie: po prechode vypnúť zápis `nakupna*` a `prices_daily` pre Sales portál (zadanie časť 17) – mimo tohto repozitára.
- Ak Peter chce, aby CRM čítalo údaje iba z Cockpitu (nie priamo z Montelu), treba v Cockpite pridať endpoint s hotovými dennými hodnotami. Montel Worker je však už dnes zdrojom Cockpitu, takže výsledok je rovnaký.

---

## 8. Finstat

### 8.1 Čo vie terajší prístup

- **V CRM nič:** firma má polia z Finstatu (`payment_rating`, `debts_note`, `insolvency_note`, `finstat_url`, `finstat_updated_at`), ale vypĺňajú sa ručne (rozhodnutie 2026-10-12). Kľúč Finstatu v CRM nie je.
- **Dnes sa Finstat volá cez Make** (Sales portál a scenár, ktorý každé 3 minúty aktualizuje HubSpot). Kľúč je v Make.
- V CRM existuje iba vyhľadanie vlastných firiem podľa názvu alebo IČO (`GET /api/companies/search`).

### 8.2 Návrh

- **Priame volanie Finstat API z Workera** (bez Make): API kľúč a súkromný kľúč iba cez `wrangler secret` (`FINSTAT_API_KEY`, `FINSTAT_PRIVATE_KEY`). Každá požiadavka sa podpisuje hashom podľa dokumentácie Finstatu.
- **Našepkávanie podľa názvu:** endpoint Autocomplete (od 3 znakov, oneskorenie 300 ms). Výsledok sa zlúči s firmami v CRM: firma v CRM je navrchu so štítkom vlastníka; zrušené firmy so štítkom „zrušená“.
- **Detail podľa IČO:** rozšírený detail (tržby, zisk, zamestnanci, vznik, sídlo, DIČ, IČ DPH, štatutári, dlhy, konkurz a reštrukturalizácia, platobný rating, Z-skóre). Licencia je **Ultimate** (odpoveď 21); presné názvy polí a hash overím v dokumentácii Finstat API pri implementácii F1.
- **Cache 24 hodín** (odpoveď 21): každá odpoveď Finstatu (detail aj našepkávanie) sa uloží do `finstat_cache` a 24 hodín sa Finstat pre ten istý dotaz znova nevolá. Denné počítadlo požiadaviek (`finstat_usage`) a strop v nastaveniach (`finstat_daily_limit`) zabránia prekročeniu limitu.
- **Ukladanie:**
  - firma v CRM → polia firmy (časť 1.12) a `finstat_updated_at`;
  - firma mimo CRM (iba overenie) → iba cache, kým ju obchodník nezaloží.
- **Obnova údajov:** pri overení a pred odoslaním ponuky, ak sú staršie ako 24 hodín (z cache, inak z Finstatu). Nočná obnova firiem s otvoreným obchodom sa zatiaľ nerobí (šetrí limit); doplní sa, ak bude treba.
- **Výstrahy** (`company_risk`): dlhy, nedoplatky, konkurz alebo reštrukturalizácia, rating E/X, Z-skóre pod 1,23 → výstraha na firme, obchode a ponuke. **Schválenie** iba pri konkurze / reštrukturalizácii a ratingu E/X (zadanie 4.1, R7).
- **Z-skóre:** ak ho licencia neposiela, vypočítam ho z účtovných výkazov Finstatu (Altman pre súkromné firmy). Pásma: pod 1,23 riziko úpadku, 1,23–2,90 šedá zóna, nad 2,90 stabilná.
- Make scenáre Finstatu sa po prechode vypnú (náprava Make).

---

## 9. Fázy F1–F7

Každá fáza: plán → migrácia nanečisto (dočasný Postgres) → `dev` po súhlase → API a obrazovky → Test → commit po Petrovom teste. Čísla migrácií sú orientačné (`0031` je rezervovaná pre Cockpit modulu 4).

| Fáza | Obsah | Migrácie | API | Obrazovky |
| --- | --- | --- | --- | --- |
| **F1** Obchod | systémové štádiá a naplnenie pipelines, číselníky (dôvod prehry, zdroj), `deal` + pravidlá štádií, `deal_oom` s objemami, `deal_contact`, OOM Pripravované z obchodu, `deal_event` a časová os, ďalší krok, overenie firmy (Finstat, CRM, vlastník), pridelenie firmy (`approval_request` – iba tento druh), výstrahy, RLS obchodov | `0032_obchod_jadro`, `0033_finstat` | `/deals` (zoznam, kanban, karta, štádium, OOM, kontakty, poznámky, ďalší krok), `/company-check` (Finstat + CRM), `/finstat/autocomplete`, `/approvals` (pridelenie) | 31, 32, 33 (bez ponúk), 39 (pridelenie), úprava 15 |
| **F2** Ponuka | `offer`, `offer_variant`, `offer_item`, `offer_year_basis`, `doc_counter`, spoločný výpočet PH s modulom 4, verzie, platnosť (`next_working_day`), schvaľovanie výnimiek, rizika a predĺženia, `offer_margin_v` | `0034_ponuky`, `0035_schvalovanie` | `/offers` (editor, verzia, prepočet, pripraviť), `/approvals` (všetky druhy) | 34, 39, 33 (ponuky), 28 (výnimky z ponúk) |
| **F3** PDF, stránka, akceptácia | šablóny ponúk a obrázky, PDF (Browser Rendering, R2), Worker `crm-ponuka` a rola `crm_public`, token, akceptácia (klik, ručne, podpísané PDF), `offer_page_stat` | `0036_ponuky_pdf_akceptacia` | `/offers/:id/pdf`, `/offers/:id/send-manual`, `/offers/:id/accept-manual`, `/settings/offer-templates`; verejné `/p/:token`, `/p/:token/pdf`, `/p/:token/accept` | 35, 36, 42 |
| **F4** Gmail | servisný účet, odoslanie ponuky, vlákna, Cron 5 min, odpovede, `email_outbox`, šablóny e-mailov, podpis z profilu (fotka, funkcia, telefóny), interné e-maily schvaľovateľom, pripomienka platnosti | `0037_emaily` | `/emails` (koncept, odoslať, vlákno, príloha), `/settings/email-templates`, `/me/profile`, `/settings/gmail-check` | 37, profil používateľa, Nastavenia → Šablóny e-mailov |
| **F5** Zmluvy k obchodom | podklady pre zmluvu (`deal_contract_input`, nové polia firmy, kontaktu, OOM), párovanie importu, „Cena iná ako v ponuke“, „Bez obchodu“, výnimka → zmluva, 14 dní, Obnova v nočnom behu | `0038_parovanie_zmluv` | `/deals/:id/contract-input`, `/contract-matching` (nespárované, vybrať obchod, bez obchodu, zrušiť), úprava importu a nočného behu | 38, 40, úprava 25, 26 |
| **F6** Domov a prehľady | ceny z Montel Workera (denne + história od 1. 1. 2026), `spot_average_daily`, dlaždice, graf, kalkulačka, moje obchody a ponuky, žiadosť o pomoc, prehľady pipeline a manažérsky rozpad | `0039_ceny_spot` + skript histórie | `/home`, `/pricing/history`, `/deals/summary` | 30, 32 (súčty), zoznamy „Bez kroku“, „Čaká na schválenie“, „Čaká na zmluvu“, „Nespárované“ |
| **F7** Provízie | `commission`, `commission_claim`, % a „počítať provízie“ pri používateľovi, výpočet a prepočet, uplatnenie, PDF a e-mail, zrušenie, prehľad, prenos histórie zo Sales portálu | `0040_provizie` + skript prenosu | `/commissions` (zoznam, súčty, uplatniť, zrušiť list, PDF), `/settings/commissions` | 41, Nastavenia → Provízie obchodníkov |

**Závislosti:** F3 potrebuje R2 a Browser Rendering (súhlas so zmenou Cloudflare), F4 nastavenie Google Workspace, F6 prístup k Montel Workeru, F7 export Firestore. F1 a F2 sa dajú robiť hneď.

**Poznámka k F6:** napojenie cien by sa dalo urobiť aj skôr (hneď po F1), pretože odstráni ručné zadávanie cien z modulu 4 a editor ponuky v F2 bude mať živé ceny. Na Teste však F2 funguje aj s ručne zadanými cenami.

---


## 10. Otázky – zodpovedané (Peter, 15. 10. 2026)

| # | Rozhodnutie | Kde v návrhu |
| --- | --- | --- |
| 1 | OOM z prehratého obchodu → **Zrušené** („obchod prehraný“), iba ak nie je v inom otvorenom obchode ani na zmluve | 1.2 |
| 2 | Prehraté znova otvorí vlastník, Vyhraté iba admin; **dôvod povinný, do auditu** | 1.2 |
| 3 | „Aktívne – iný dodávateľ“ sa nezavádza (iba popis na obrazovke) | 0.3 |
| 4 | Kto zakladá obchod na zákazníkovi bez vlastníka, stane sa vlastníkom | 1.2 |
| 5 | OOM najviac v jednom otvorenom obchode toho istého druhu; **výnimka: obchod Obnova k zmluve, na ktorej OOM je** | 1.3 |
| 6 | Pridelenie firmy schvaľujú Peter Kalman, Daniel Dérer, Denis Kalman – príznak „schvaľuje pridelenie firmy“ | 1.8, 1.12 |
| 7 | Zmluvy domácností bez otvoreného obchodu → automaticky „Bez obchodu“ | 2.1 |
| 8 | `crm@greenlogy.com` založí Peter | 3.6 |
| 9 | Schválenie rizika platí pre celý obchod **30 dní** alebo do zhoršenia údajov Finstatu | 1.8 |
| 10 | Test: iba @greenlogy.com a zoznam povolených adries (`MAIL_ALLOWLIST`) | 3.3 |
| 11 | FIX zo staršieho dňa: upozorniť a ponúknuť prepočet | 1.6 |
| 12 | SPOT/VIWA 14 dní s posunom na pracovný deň; kombinácia podľa FIX; **pripomienka 2 pracovné dni pred koncom, pri FIX nie** | 1.9, 6 |
| 13 | Číslovanie ponúk od 1 každý rok | 1.5 |
| 14 | Stav Vyplatená sa nezavádza | 0.3, 1.11 |
| 15 | Provízia zo súčtu PH celého obchodu (záporná zmluva sa započíta), záporný súčet = 0 € | 1.11 |
| 16 | Čakajúce provízie zo Sales portálu sa prenesú s pôvodnou sumou a dajú sa uplatniť; **dátum prechodu 1. 11. 2026**, obchod nesmie mať províziu z oboch | 1.11 |
| 17 | R2 (jurisdikcia EÚ) a Browser Rendering áno, Workers Paid; pred zapnutím odhad ceny | 4, 12 |
| 18 | Vzťah k nehnuteľnosti: 6 možností z Office portálu | 1.12 |
| 19 | Stránka ponuky na Ostrom: `ponuka.greenlogy.com` | 5.1 |
| 20 | Ceny z Montel Workera iba na čítanie, kľúč v secret; graf a dlaždice vzorcom CRM | 7.2 |
| 21 | Finstat Ultimate, cache 24 h | 8.2 |
| Gmail | poistky k `gmail.readonly`: iba `threads.get` / `messages.get` na vlákna CRM, jedna funkcia s testom, denník čítania, kľúč v secret, pilot | 3.1, 3.4, 1.9 |

**Odpoveď 5 – potvrdené (Peter 15. 10.):** obchod Obnova k zmluve X smie obsahovať OOM zo zmluvy X, aj keď je to OOM už v inom otvorenom obchode – a naopak, nový obchod smie obsahovať OOM, ktoré je v otvorenej Obnove. Dva bežné otvorené obchody s tým istým OOM ostávajú zakázané.

## 11. Otvorené

- Možnosti polí „typ výkupnej zmluvy“ a „model výpočtu výkupu“ z Office portálu (obe prílohy ukazovali vzťah k nehnuteľnosti) – treba až v F5.
- Právne overenie akceptácie klikom (zadanie P4) – na strane Petra; dovtedy aj nahratie podpísaného PDF.
- Miesto behu prehliadača Browser Rendering (EÚ) – dokumentácia voľbu regiónu neuvádza (časť 4.1). Ostáva otvorené do F3, vtedy sa rozhodne medzi Browser Run a `pdf-lib` (Peter 15. 10.).

## 12. Odhad mesačnej ceny R2 a Browser Rendering (~300 ponúk mesačne)

Cenník Cloudflare (overené v dokumentácii 15. 10. 2026; Browser Rendering sa dnes volá Browser Run):
- **Browser Run** (Workers Paid): 10 hodín prehliadača mesačne v cene, potom 0,09 $ za hodinu; 10 súbežných prehliadačov v cene (priemer denných špičiek za mesiac), potom 2 $ za prehliadač.
- **R2** (Standard): 10 GB mesačne v cene, potom 0,015 $ za GB a mesiac; 1 mil. zápisov (trieda A) a 10 mil. čítaní (trieda B) mesačne v cene; bez poplatku za prenos dát.

| Položka | Predpoklad | Mesačne |
| --- | --- | --- |
| Vykreslenia PDF | 300 odoslaných + ~600 náhľadov + ~100 potvrdení akceptácie + ~20 provízných listov ≈ 1 000 × ~4 s | ~1,1 h z 10 h v cene → **0 $** |
| Súbežnosť | najviac 1–3 prehliadače naraz (denná špička) | v cene → **0 $** |
| Úložisko R2 | uložené iba odoslané PDF, potvrdenia a listy ≈ 420 × ~1,5 MB ≈ 0,6 GB mesačne pribudne | 1. rok do ~7,5 GB → **0 $**; potom ~0,01 $ za každý ďalší mesiac (napr. po 2 rokoch ~0,08 $) |
| Operácie R2 | ~500 zápisov, ~2 000 čítaní (stiahnutia, stránka ponuky) | v cene → **0 $** |
| **Spolu** | | **≈ 0 € mesačne** (pri 10-násobku ponúk stále pod 1 € za vykresľovanie) |

Náhľady sa neukladajú. Paušál Workers Paid (5 $) už platíte a nemení sa.

---

## 13. Plán F1 – migrácie `0032_obchod_jadro`, `0033_finstat` a kód (na schválenie)

Rozsah F1 (časť 9): pipelines a štádiá, obchod, OOM Pripravované z obchodu, časová os, ďalší krok, overenie firmy, vlastník a pridelenie, výstrahy Finstatu, RLS obchodov. Ponuky (F2) ešte nie – karta obchodu bude mať sekciu Ponuky skrytú.

### 13.1 Čítanie na `dev` pred migráciou (iba čítanie, so súhlasom)

- počty riadkov `pipeline`, `pipeline_stage`, `deal`, `deal_oom`, `deal_contact`, `offer`, `offer_item`, `commission`, `commission_rule` a hodnoty `lookup_value` zoznamov `dovod_prehry`;
- či na Teste existujú pipelines vytvorené pri skúšaní Nastavení (názov, druh, štádiá) – migrácia ich potom nepremenuje, iba označí štádiá kódmi podľa poradia a typu, alebo skončí chybou so zoznamom na tvoje rozhodnutie;
- bunky matice práv modulu „obchod“ (či sú ešte východiskové);
- e-maily používateľov Daniel Dérer a Denis Kalman (či už sú v CRM, kvôli príznaku pridelenia).

### 13.2 `0032_obchod_jadro` (`-- migrate:up`)

1. **Kontrola:** `deal`, `deal_oom`, `deal_contact`, `offer`, `offer_item`, `commission` musia byť prázdne, inak chyba.
2. **Štádiá:** enum `deal_stage_code`, `pipeline_stage.code` + unikátny index; spúšťač `pipeline_stage_code_guard` (kód sa nemení, súlad s `outcome`, systémovú stage nejde archivovať); nová pipeline dostane 6 systémových štádií (nahrádza „Nový, Vyhraný, Prehraný“ z `0010`).
3. **Pipelines:** B2B dodávka, B2B výkup, Green VIWA B2B, B2C (`org_id` NULL = celá skupina), štádiá 10 / 30 / 50 / 90 / 100 / 0 %.
4. **Číselníky:** hodnoty `dovod_prehry` (cena, zostal u dodávateľa, iný dodávateľ, nereaguje, nesplnil podmienky, iné – „iné“ systémová); nový zoznam `zdroj_obchodu` (vlastný kontakt, web, call centrum, odporúčanie, partner; **obnova** systémová).
5. **`deal`** (časť 1.2, bez `accepted_variant_id` – príde s ponukami v F2):
   - zrušiť `source`, `lost_reason`, `campaign`; pridať `source_code`, `lost_reason_code`, `lost_note`, `supply_start`, `next_step`, `next_step_on`, `next_step_notified_on`, `previous_contract_id`, `estimated_value_eur`, `stage_changed_at`, `note`; `owner_id NOT NULL`;
   - index `deal_open_renewal_key`;
   - spúšťač `deal_rules` (BEFORE): stage patrí pipeline; zákazník vs. druh pipeline (B2C = osoba, ostatné = firma); podmienky vstupu do štádia (`deal_stage_check`); `closed_at` a `stage_changed_at`; Vyhraté iba systém alebo admin; návrat z uzavretého štádia iba cez funkciu `deal_reopen(deal, dôvod)`;
   - spúšťač `deal_customer_owner` (BEFORE INSERT a zmena zákazníka alebo vlastníka): zákazník s iným vlastníkom → chyba s menom vlastníka a ponukou pridelenia (okrem `crm_can_change_owner()` a `crm_sync`); zákazník bez vlastníka → vlastník = vlastník obchodu (úzka výnimka v `owner_change_guard` iba z prázdneho vlastníka, nastavená touto funkciou);
   - zmena vlastníka obchodu: `crm_can_change_owner()`, schvaľovateľ cien alebo „schvaľuje pridelenie firmy“;
   - spúšťač po prechode do Prehraté: OOM s `created_from_deal_id` = obchod, stav Pripravované, bez `contract_oom` a bez iného otvoreného obchodu → `oom_set_status(…, 'zrusene')` a udalosť v časovej osi.
6. **`deal_oom`:** objemy, `org_id`, unikátne (obchod, OOM); spúšťač: predvyplnenie objemov z OOM, pravidlo jedného otvoreného obchodu na skupinu (`contract_oom_group`) s výnimkou Obnovy (časť 10, odpoveď 5); pri zmene štádia „Cenová ponuka“ kontrola objemov.
7. **`deal_contact`:** `roles text[]` (kódy `rola_kontaktu`) namiesto `role`, `is_primary` (najviac jeden), unikátne (obchod, kontakt).
8. **`oom.created_from_deal_id`.**
9. **`deal_event`** + spúšťače: založenie, zmena štádia (z → do), zmena vlastníka, znovuotvorenie s dôvodom, pridanie a odobratie OOM, OOM zrušené pri prehre, pridelenie firmy.
10. **`approval_request`** (celá tabuľka a enumy, v F1 sa používa iba `pridelenie_firmy`; `approval_price_item` až v F2):
    - `approval_request_create` (pridelenie: firma má iného vlastníka, žiadateľ nie je vlastník, najviac jedna čakajúca žiadosť žiadateľa na firmu);
    - `approval_decide(id, schváliť, poznámka)`: iba príslušný schvaľovateľ, nie vlastná žiadosť; pri schválení `company.owner_id` = žiadateľ (cez tú istú úzku výnimku), upozornenia žiadateľovi a pôvodnému vlastníkovi;
    - `app_user.approves_assignments` + `crm_approves_assignments()`; migrácia ho zapne pre peter@greenlogy.com a pre Daniela Dérera a Denisa Kalmana, ak sú už v CRM (inak ho nastavíš v Nastaveniach).
11. **`notification`:** stĺpce `deal_id`, `approval_id`; nové druhy `dalsi_krok`, `schvalenie_nove`, `schvalenie_rozhodnutie`, `pridelenie_firmy`; `notification_add` dostane variant s obchodom a žiadosťou.
12. **Nočný beh obchodov** `deal_daily_run_at(dnes)`: upozornenie `dalsi_krok` v deň kroku (raz); `job_run.job` povolí `obchody`. Worker ho zavolá po behu zmlúv (rovnaký Cron, nový Cron netreba).
13. **RLS** na `deal`, `deal_oom`, `deal_contact`, `deal_event`, `approval_request`:
    - `crm_deal_visible(company, person, owner)`: služba; `crm_scope('obchod','view') = 'vsetko'`; schvaľovateľ cien alebo pridelenia; „iba svoje“ = vlastník obchodu **alebo** (iba interný tím) vlastník zákazníka;
    - `crm_deal_editable` rovnako s `edit`;
    - **matica práv:** Sales_internal má dnes pri module Obchod „všetko“; zadanie (časť 14) chce „svoje obchody a obchody svojich zákazníkov“ → bunky zmením na „iba svoje“ **iba ak sú ešte východiskové**; Servis a Nákup ostávajú „vidieť všetko“, upravovať nič (podklady v F5 cez funkcie);
    - `approval_request`: žiadateľ, príslušní schvaľovatelia, pôvodný vlastník pri pridelení, admin;
    - `crm_external_ready()` ostáva `false` (chýba RLS na `audit_log`).
14. **Audit** na `approval_request`; `deal`, `deal_oom`, `deal_contact` ho už majú. `deal_event` bez auditu.

`-- migrate:down`: všetko späť (vyžaduje prázdne obchody, žiadosti a udalosti; pipelines vytvorené migráciou sa odstránia iba bez obchodov).

### 13.3 `0033_finstat` (`-- migrate:up`)

1. **Firma:** `revenue_eur numeric(14,2)`, `profit_eur numeric(14,2)`, `finance_year smallint`, `employees_range text`, `founded_on date`, `z_score numeric(6,2)`, `has_debts boolean`, `debts jsonb` (veriteľ, suma, dátum), `insolvency_kind text` (konkurz / reštrukturalizácia), `insolvency_since date`, `cancelled_on date`. Existujúce `debts_note`, `insolvency_note` ostávajú na ručné poznámky.
2. **`company_apply_finstat(company, údaje jsonb)`** (`SECURITY DEFINER`): mení iba polia Finstatu a `finstat_updated_at`; smie každý, kto firmu vidí (verejné údaje registra); audit so zdrojom `finstat`.
3. **`finstat_cache`** `(kind ('detail', 'autocomplete'), key, fetched_at, data jsonb)`, platnosť 24 h; nočný beh maže záznamy staršie ako 7 dní (obsahujú mená štatutárov). Prístup iba cez funkcie `finstat_cache_get/put`.
4. **`finstat_usage`** `(day, requests)` a nastavenie `finstat_daily_limit` (východiskovo 500, zmeníš podľa zmluvy s Finstatom); nad limit API vráti „Denný limit Finstatu je vyčerpaný“, cache ďalej funguje.
5. **`company_risk(company) → jsonb`**: výstrahy (dlhy, nedoplatky, konkurz/reštrukturalizácia, rating E/X, Z-skóre pod 1,23) a `needs_approval` (konkurz/reštrukturalizácia, rating E/X); pásmo Z-skóre.
6. **`company_check(ičo)`** (`SECURITY DEFINER`, overenie firmy, obrazovka 31): či je firma v CRM, typ a stav zákazníka, vlastník, počet kontaktov, zmluvy (číslo, stav) a otvorené obchody (názov, vlastník). Kto firmu nevidí, dostane iba meno vlastníka a mená vlastníkov otvorených obchodov (ako pri duplicite IČO v module 1).

`-- migrate:down`: zrušiť objekty a stĺpce.

### 13.4 `api/db/app-role.sql`

SELECT/INSERT/UPDATE pre `crm_app` na nové tabuľky podľa RLS; DELETE iba `deal_oom`, `deal_contact`; `finstat_cache`, `finstat_usage` bez priameho prístupu (iba funkcie); `deal_event` iba SELECT.

### 13.5 Kód F1

- **Finstat klient** `api/src/finstat.ts`: detail a našepkávanie, hash podľa dokumentácie Finstatu, kľúče `FINSTAT_API_KEY`, `FINSTAT_PRIVATE_KEY` (`wrangler secret`, lokálne `.dev.vars` – vložíš ty), cache a denné počítadlo, do logu nič z odpovede.
- **API:**
  - `GET /deals` (zoznam s filtrami: pipeline, vlastník, štádium, zdroj, ďalší krok – bez / dnes / po termíne, očakávané uzavretie), `GET /deals/board?pipeline=` (kanban: počty a súčty odhadu PH podľa štádia, vážená PH);
  - `POST /deals`, `GET /deals/:id`, `PATCH /deals/:id`, `POST /deals/:id/stage`, `POST /deals/:id/reopen`;
  - `POST /deals/:id/oom` (existujúce OOM alebo nové Pripravované cez rovnakú kontrolu ako `POST /oom` modulu 2), `PATCH`/`DELETE /deals/:id/oom/:oomId`;
  - `POST`/`PATCH`/`DELETE /deals/:id/contacts`, `POST /deals/:id/notes`, `GET /deals/:id/timeline`;
  - `GET /company-check?ico=` (CRM + Finstat), `GET /finstat/autocomplete?q=` (Finstat + firmy v CRM), `POST /companies/from-finstat`, `POST /companies/:id/finstat-refresh`;
  - `GET /approvals`, `GET /approvals/count`, `POST /approvals` (pridelenie), `POST /approvals/:id/decide`;
  - upozornenia: nové druhy v existujúcom zvončeku.
- **Obrazovky:** 31 (overenie firmy, „Založiť firmu z Finstatu“, „Požiadať o pridelenie“, „Založiť obchod“), 32 (kanban a zoznam bez odznakov ponúk), 33 (karta obchodu bez ponúk a e-mailov: OOM s objemami a nové OOM, kontakty s rolami, časová os, ďalší krok, štádiá s dialógom prehry a znovuotvorenia), 39 (záložky Čakajú, Pridelenie firmy, Vybavené), menu Obchody a Schvaľovanie s počítadlom, karta firmy (Finstat údaje, výstrahy, obchody), Nastavenia: zamknuté systémové štádiá (15), príznak „schvaľuje pridelenie firmy“ (12).
- **Testovacie dáta:** `db/test-data/obchody-test.sh dev vytvor|zmaz` s vymyslenými firmami „TEST“ (spúšťaš ty).

### 13.6 Testy (`db/test/checks_obchod.sql`, séria B)

- B1 štádiá: povinné údaje pri vstupe, Vyhraté iba systém/admin, znovuotvorenie s dôvodom (vlastník Prehraté áno, Vyhraté nie), audit a časová os.
- B2 zákazník a vlastník: konflikt vlastníka, zákazník bez vlastníka → vlastník obchodu, B2C iba osoba, zmena vlastníka obchodu podľa práv.
- B3 OOM: jedno OOM v dvoch otvorených obchodoch → chyba, výnimka Obnova, prehra → Zrušené iba bez zmluvy a iného obchodu.
- B4 pridelenie firmy: žiadosť, schválenie iba so správnym príznakom, nie vlastná, zmena vlastníka, upozornenia.
- B5 RLS: interný „iba svoje“ (vlastné obchody + obchody vlastných zákazníkov), externý iba vlastné, Servis vidí a nemení, schvaľovateľ vidí všetko.
- B6 Finstat: `company_risk` (pásma Z-skóre, E/X, konkurz), `company_check` bez prístupu k firme, cache 24 h, denný limit.
- B7 nočný beh: ďalší krok raz.
- Všetky predchádzajúce kontroly (167) musia prejsť.

### 13.7 Overenie a nasadenie

1. Nanečisto na dočasnom Postgrese: `0001`–`0033` hore, testy, `down` `0033` a `0032` = schéma `0030`, znova hore = rovnaká.
2. Kód lokálne proti dočasnej databáze; Finstat iba s tvojím súhlasom na pár skúšobných IČO (napr. Greenlogy).
3. Po tvojom súhlase: `0032`, `0033` na `dev` → `app-role.sql` → nasadenie na Test (robíš ty) → tvoj test → commit.

## 14. Čo treba od teba teraz

- Súhlas s plánom F1 (časť 13) a s interpretáciou odpovede 5 (časť 10).
- Súhlas s čítaním na `dev` podľa časti 13.1.
- Kľúče Finstat API (vložíš sám do `.dev.vars` a neskôr cez `wrangler secret`) a súhlas so skúšobnými volaniami Finstatu.

---

## 15. F1 – migrácie `0032`, `0033` overené nanečisto (15. 10. 2026)

**Petrove doplnky k plánu (15. 10.):**
- Sales_internal ostáva „všetko“ (obchodný riaditeľ a asistent: všetky obchody, ponuky, provízie, zmena vlastníka obchodu). Všetci obchodníci budú v Sales_external: vidia iba svoje obchody a obchody na firmách a osobách, ktorých sú vlastníkom (RLS). Back office a Nákup vidia všetko. **Matica práv sa nemení.**
- **Externí = všetci predajcovia:** v module 5 sa im žiadna funkcia neskryje (domov, kalkulačka, ponuky, provízie), obmedzuje sa iba rozsah dát.
- Obnova pri existujúcom bežnom obchode – časť 2.3 (F5). Dátum prechodu provízií ako nastavenie – časť 1.11 (F7). Gmail iba vlákna s aktivitou 30 dní a limity API – časť 3.4 (F4).

**Čítanie na `dev` (iba SELECT, 15. 10.):** pipelines, štádiá, dealy, OOM a kontakty dealov, ponuky, položky ponúk, provízie, pravidlá provízií a hodnoty „dôvod prehry“ = 0 riadkov; firmy 10, OOM 37, zmluvy 14 (testovacie); posledná migrácia `0030`; `crm_external_ready()` = false; aktívni používatelia iba v tímoch CEO a Marketing; Daniel Dérer ani Denis Kalman zatiaľ v CRM nie sú.
- **Matica Sales_external (overené):** obchod, zákazníci, OOM, zmluvy – vidieť aj upravovať „iba svoje“; provízie vidieť „iba svoje“, upravovať nič. Zodpovedá zadaniu.
- **Sales_internal:** obchod, zákazníci, OOM „všetko“; zmluvy a provízie „iba svoje“. Obchodný riaditeľ zmluvy aj tak vidí všetky cez „schvaľuje ceny“ (`crm_sees_all_contracts`); provízie všetkých rieši F7 tým istým príznakom. Asistent bez príznaku by zmluvy a provízie videl iba svoje – na rozhodnutie pri F7.

**`0032_obchod_jadro` – odchýlky a spresnenia oproti plánu 13.2:**
- **„Kód databázy“** (`crm_internal_call`) = `current_user` je vlastník tabuliek (funkcia alebo spúšťač `SECURITY DEFINER`, skript vlastníka). Pravidlá obchodu (`deal_rules`, `deal_oom_rules`) bežia s právami volajúceho, preto rozlíšia aplikáciu od kódu databázy; príznaky relácie (`app.deal_reopen`, `app.owner_assign`) platia iba v kóde databázy – aplikácia si ich nastaviť vie, ale nič nimi nezíska (test B1, B2). Rola `crm_sync` (prenos z HubSpotu) sa správa ako kód databázy.
- Kód databázy (nočný beh, párovanie, prenos) smie založiť obchod v ľubovoľnom štádiu a bez kontroly OOM; aplikácia iba v Príležitosti, Akceptáciu a Vyhraté nenastaví (Vyhraté iba admin).
- Unikátnosť (obchod, OOM) a (obchod, kontakt) už bola v `0001` – nepridáva sa.
- `deal_contact.role` (text) → `roles text[]` z číselníka `rola_kontaktu`.
- Pipeline druhu `green_solar` patrí osobe (ako B2C); ostatné firme.
- Zmenu vlastníka obchodu smie tím CEO, admin, „všetko“ v module Obchod (obchodný riaditeľ), schvaľovateľ cien a schvaľovateľ pridelenia (`crm_deal_manager`). Tí smú založiť obchod aj pre iného obchodníka a aj na cudzom zákazníkovi.
- Príznak „schvaľuje pridelenie firmy“ zapne migrácia pre peter@greenlogy.com (a pre Daniela Dérera a Denisa Kalmana, ak už v CRM sú – na `dev` nie sú); člen externého tímu ho mať nesmie (`app_user_guard`).
- Upozornenia obchodu: `notification_add_deal` (väzby `deal_id`, `approval_id`).
- Nočný beh obchodov `deal_daily_run()` volá Worker po behu zmlúv (rovnaký Cron); `job_run.job` = `obchody`.

**`0033_finstat`:** podľa plánu 13.3. Zápis údajov Finstatu sa v audite označí zdrojom `synchronizacia` (nový zdroj by vyžadoval zmenu enumu, ktorá sa nedá vrátiť). Výstrahy `company_risk`: `dlhy`, `konkurz` / `restrukturalizacia`, `rating_e` / `rating_x`, `z_skore`, `zrusena`; pásma Z-skóre `riziko` / `seda_zona` / `stabilna`.

**Úpravy kódu, ktoré musia ísť spolu s migráciou** (inak by na Teste prestalo fungovať zakladanie pipeline):
- `api/src/routes/settings-content.ts`: nová pipeline už nezakladá vlastné štádiá (robí to databáza); pridať sa dá iba otvorené štádium; typ štádia sa nemení; povinné polia jadra = očakávané uzavretie, začiatok dodávky, ďalší krok, odhad PH; zoznam štádií vracia `code`.
- `web/src/pages/settings/PipelinesPage.tsx`, `web/src/lib/settings.ts`: typ štádia iba na zobrazenie, systémové štádium bez tlačidla Archivovať, nový text.
- `api/src/errors.ts`: hláška k `pipeline_stage_code_outcome_check`.
- `api/src/jobs.ts`: `dailyDealRun` po behu zmlúv.
- `api/db/app-role.sql`: `deal_event`, `approval_request` bez INSERT/UPDATE; `finstat_cache`, `finstat_usage` bez prístupu (iba funkcie).

**Úpravy existujúcich testov** (overujú to isté, iba zakladajú obchody po novom): `seed.sql` (pipelines dostanú systémové štádiá, pevné id sa priradia podľa kódu; dealy so zdrojom; roly kontaktu), `checks.sql` (štádium z inej pipeline odmietne spúšťač – `check_violation`), `checks_zakaznici.sql` (štádiá B2C podľa kódu, dealy so zdrojom a vlastníkom, prehra s dôvodom), `checks_nastavenia.sql` (dealy so zdrojom; číselník „Odporúčanie“ hľadá iba v zozname zdroj kontaktu – rovnaký názov má teraz aj zdroj obchodu). `run.sh` spúšťa nový `checks_obchod.sql`.

**Overenie (dočasný Postgres 18 v scratchpade, nie Neon):**
- čistá databáza: `0001`–`0033` hore bez chyby, `app-role.sql`, cenníky 2026 a podnikatelia 2026;
- **178 kontrol OK** (167 doterajších + 11 nových B0–B7 v `checks_obchod.sql`);
- mutačná skúška: po vypnutí pravidla „jedno OOM v jednom otvorenom obchode“ test B3 zlyhá (testy chybu naozaj zachytia);
- rola `crm_app`: zápis do `deal_event`, `approval_request` a čítanie `finstat_cache` odmietnuté; `crm_internal_call()` = false;
- `down` `0033` a `0032` = schéma `0030` (jediný rozdiel: stĺpce `deal.source`, `lost_reason`, `campaign` a `deal_contact.role` sú po návrate na konci tabuľky – poradie stĺpcov sa pri ich novom pridaní nedá zachovať, obsah a typy sú rovnaké); znova hore = rovnaká schéma ako prvé `up`;
- lokálne API proti dočasnej databáze: 4 pipelines so 6 systémovými štádiami; nová pipeline dostane 6 štádií; pridanie „vyhraného“ štádia, archivácia systémového štádia a zmena typu odmietnuté so slovenskou hláškou; premenovanie a pravdepodobnosť áno; nočný beh (OOM, zmluvy, obchody) prebehol bez chyby.

**Otvorené pred pilotom (dôležité):** do tímu Sales_external sa dnes nedá priradiť používateľ (`crm_external_ready()` = false). Po F1 majú RLS OOM, zmluvy aj obchody; chýba už iba **RLS na `audit_log`** (dnes ho prihlásený používateľ číta celý, aj zmeny cudzích záznamov – STAV). Keďže všetci obchodníci budú externí, treba to vyriešiť samostatnou malou migráciou pred pilotom.

**Ďalej:** `0032`, `0033` na `dev` → `app-role.sql` → nasadenie úprav kódu (Peter) → `db/test/run.sh` na `dev` → potom API a obrazovky F1 (časť 13.5).

---

## 16. F1 – API a obrazovky, `0034_obchod_f1_doplnky` (lokálne overené 15. 10. 2026)

`0032` a `0033` spustil Peter na `dev` (15. 10.). API a obrazovky boli overené lokálne proti dočasnej databáze s vymyslenými údajmi „TEST“, nie na `dev`.

**API (nové súbory):**
- `api/src/routes/deals.ts` – `GET /deals/options`, `/deals/owners`, `/deals` (filtre: pipeline, vlastník, štádium, zdroj, ďalší krok, uzavreté tento mesiac, hľadanie), `/deals/:id`, `/deals/:id/timeline`; `POST /deals`, `PATCH /deals/:id`, `POST /deals/:id/stage`, `/deals/:id/reopen`; OOM na obchode (`POST /deals/:id/oom`, `/deals/:id/oom/new` – nové Pripravované OOM rovnakými kontrolami ako modul 2, `PATCH`/`DELETE /deals/:id/oom/:oomId`, `GET /deals/:id/oom-candidates`); kontakty (`POST`/`PATCH`/`DELETE /deals/:id/contacts…`, `GET /deals/:id/contact-candidates`); `POST /deals/:id/notes`.
- `api/src/routes/approvals.ts` – `GET /approvals?tab=caka|pridelenie_firmy|vybavene`, `/approvals/count` (počítadlo v menu), `POST /approvals` (pridelenie firmy podľa id alebo IČO), `/approvals/:id/decide`, `/approvals/:id/cancel`.
- `api/src/routes/company-check.ts` + `api/src/finstat.ts` – `GET /company-check?ico=` (CRM + Finstat; firma, ktorú používateľ vidí, dostane čerstvé údaje Finstatu), `/company-search?q=` (CRM + našepkávanie Finstatu s označením „v CRM“ a vlastníkom), `POST /companies/from-finstat`, `/companies/:id/finstat-refresh`, `GET /companies/:id/risk`.
- Úpravy: `/me` (`approves_assignments`, `deal_manager`), upozornenia (odkaz na obchod a schvaľovanie), Nastavenia → Používatelia (príznak „schvaľuje pridelenie firmy“), karta zákazníka (obchody s odkazom; 1 obchod : n zmlúv), `api/dev.sh` (lokálne odovzdá iba `FINSTAT_*` z `.dev.vars` cez dočasný súbor).

**Obrazovky:** 32 Obchody (záložky pipelines, kanban a zoznam, KPI otvorené / PH / vážená PH / bez kroku alebo po termíne, filtre vlastník, ďalší krok, hľadanie), 33 karta obchodu (štádiá – Akceptácia a Vyhraté zamknuté s vysvetlením, prehra s dôvodom, znovuotvorenie s dôvodom, OOM s objemami a nové OOM, kontakty s rolami a primárnym kontaktom, ďalší krok, úprava, časová os s poznámkami, výstrahy Finstatu), 31 Overenie firmy (IČO alebo názov s našepkávaním, CRM časť, Finstat karta s Z-skóre a pásmom, „Založiť firmu z Finstatu“, „Požiadať o pridelenie“, „Založiť obchod“), 39 Schvaľovanie (Čakajú, Pridelenie firmy, Vybavené; schválenie, zamietnutie s poznámkou, zrušenie vlastnej žiadosti). Menu: Obchody, Overenie firmy, Schvaľovanie s počítadlom. Karta firmy: FinStat (údaje, výstrahy, „Načítať z Finstatu“). **Všetko rovnaké pre interných aj externých obchodníkov** – rozsah dát určuje databáza.

**`0034_obchod_f1_doplnky`** (zistené pri obrazovke 31 a skúške Finstatu; `0033` už je na `dev`, preto nová migrácia):
1. `approval_request_assign_ico(ičo, dôvod)` – firmu iného obchodníka žiadateľ nevidí (RLS), API preto nepozná jej id.
2. `company_check` vráti id aj pri firme **bez vlastníka** – obchodník na nej založí obchod a stane sa vlastníkom; pri firme iného vlastníka id ostáva skryté.
3. Oprava hlášky v `deal_rules`: „Firmu vlastní Peter Kalman**s**“ (preklep `%s` v `0032`).
4. `company_apply_finstat` prepíše platobný rating iba vtedy, keď ho údaje obsahujú.

**Finstat – skúšobné volania (Peter povolil najviac 10):** použité **3** (detail Greenlogy 53223713, 2× našepkávanie „Greenlogy“ – prvé zlyhalo na chybe v našom kóde, ktorá je opravená). Odpovede iba v dočasnej databáze v scratchpade, nie v repozitári ani na `dev`; súbor s kľúčmi zmazaný. Overené polia (licencia Ultimate): `RevenueActual`, `ProfitActual`, `ActualYear`, `EmployeeText` / `EmployeesNumber`, `CreditScoreValue` (Altmanovo Z-skóre), `HasDebt`, `Debts`, `Bankrupt`, `Restructuring`, `PreventiveRestructuring`, `Liquidation`, `Cancelled`, `Url`; našepkávanie `Results` / `Suggestions`. **Platobný rating A–E/X Finstat neposiela** (otázka 1 v časti 18).

**Overenie:**
- čistá dočasná databáza `0001`–`0034`, **179 kontrol OK** (+ B8: žiadosť podľa IČO bez prístupu k firme, id firmy bez vlastníka, zápis Finstatu nezmaže rating); `0034` down = schéma `0033`, znova hore bez rozdielu;
- lokálne API, dvaja používatelia (Peter – admin, CEO; „Obchodník TEST“ v tíme s „iba svoje“): založenie obchodu, nové OOM, kontakt s rolami, štádiá, Vyhraté (admin), znovuotvorenie, prehra s „Iné“ bez poznámky odmietnutá, prehra → nové OOM Zrušené, časová os; obchodník nevidí cudzie obchody ani firmu, obchod na cudzej firme odmietnutý s hláškou, žiadosť o pridelenie podľa IČO, Peter zamietnutie bez poznámky odmietnuté, schválenie → obchodník je vlastník a vidí firmu aj obchody na nej; upozornenia oboch; overenie firmy a našepkávanie;
- `tsc` API aj web bez chýb, `npm run build` web OK. Obrazovky som nevidel v prehliadači – vizuálnu kontrolu robíš ty na Teste.

**Poznámka:** volanie Finstatu beží v transakcii požiadavky; ak požiadavka potom skončí chybou, počítadlo denného limitu sa vráti spolu s ňou (volanie sa nezapočíta). Pri limite 500 denne to nevadí.

## 17. `0035_audit_rls` – RLS na audite (podmienka externého tímu) – schválené, overené nanečisto

Cieľ: audit vidí iba to, čo používateľ smie vidieť; potom `crm_external_ready()` = true a obchodníkov pôjde priradiť do Sales_external.

| Záznamy auditu | Kto ich vidí |
| --- | --- |
| všetky | admin (Nastavenia → Audit ostáva iba pre admina) |
| `company`, `company_contact` (podľa firmy v diff) | kto firmu vidí (`crm_company_access`) |
| `contact` | kto osobu vidí (`crm_contact_access`) |
| OOM a jeho podriadené (`oom`, `oom_customer`, `oom_device`, `oom_contact`, `oom_planned_change`, `oom_price_regulation_change`) | kto OOM vidí (`crm_oom_access`) |
| `deal`, `deal_oom`, `deal_contact` | kto obchod vidí (`crm_deal_visible`) |
| `contract`, `contract_oom`, `contract_price`, `contract_flag`, `price_exception` | kto zmluvu vidí (`crm_contract_visible`) |
| `approval_request` | podľa jej pravidiel (žiadateľ, pôvodný vlastník, schvaľovateľ) |
| `activity` (poznámky) | kto vidí firmu alebo osobu poznámky |
| `price_parameter`, `market_price_daily` | kto smie tieto tabuľky čítať: schvaľovateľ cien, právo „vidieť maržu firmy“ (doplnené pri overení – obchodný riaditeľ vidí audit parametrov, ktoré mení) |
| ostatné (Nastavenia, používatelia, tímy, cenníky, importy) | iba admin |

- Karta zákazníka („Vývoj stavu“ z auditu) funguje ďalej, lebo číta audit firmy alebo osoby, ktorú používateľ vidí.
- `crm_external_ready()` vráti true; test: externý používateľ sa dá priradiť, vidí iba audit svojich záznamov.
- Podriadené záznamy (aj zmazané, napr. zariadenie OOM alebo OOM na obchode) sa posudzujú podľa nadriadeného záznamu – id z riadku alebo z obsahu zmeny (`audit_diff_value`). Zmazaný hlavný záznam (firma, OOM, obchod, zmluva) vidí iba admin.
- Zmena a zmazanie auditu ostávajú zakázané spúšťačom `audit_log_protect` (politiky UPDATE/DELETE pustia riadok k spúšťaču, aby skončil chybou, nie tichým „0 riadkov“).
- **Overenie (15. 10.):** dočasná databáza `0001`–`0035`, **181 kontrol OK** (+ B9 v `db/test/checks_audit_rls.sql`: obchodník vidí audit svojich obchodov, firiem a OOM na svojom obchode, nie cudzích ani Nastavení; Servis podľa práv; admin všetko; bez používateľa nič; do externého tímu sa dá priradiť používateľ); down = schéma `0034`, znova hore bez rozdielu.
- Doteraz audit čítajú: Nastavenia → Audit (admin), „Vývoj stavu“ na karte firmy a osoby, časová os OOM – všetky čítajú záznamy, ktoré používateľ vidí.

## 18. Otázky (15. 10. 2026)

1. **Platobný rating A–E/X** – *rozhodnuté (Peter 15. 10.): súhlas s návrhom.* Finstat ho v odpovedi (Ultimate) neposiela. Posiela Altmanovo Z-skóre, FinStat skóre, Index 05, index daňovej spoľahlivosti a stupne kreditného skóre (číslo). Odkiaľ je dnes rating v HubSpote? Návrh: kým sa nezistí zdroj, ostáva rating na firme ručný (alebo z HubSpotu pri prenose) a schválenie spúšťa konkurz / reštrukturalizácia a rating E/X, ak je vyplnený.

---

## 19. Plán F2 – ponuka, varianty, ceny OOM × rok, schvaľovanie (na schválenie)

F1 je uzavretá (commit `803cfd8`, 15. 10.). F2 podľa časti 9: ponuka, varianty, ceny OOM × rok, cena pre obchodníka, pridaná hodnota, verzie, platnosť, schvaľovanie výnimiek, rizika a predĺženia. PDF, stránka ponuky a akceptácia sú F3, e-mail F4.

### 19.0 Dorovnanie obrazoviek F1 s návrhmi (prvý krok F2)

Obrazovky F1 sú funkčne hotové, vzhľadom však zjednodušené. Pred ponukami ich dorovnám s návrhmi:
- **31 Overenie firmy:** prepínač IČO / Názov; hlavička firmy (názov, IČO · DIČ · IČ DPH · adresa, stav Aktívna); rad dlaždíc (tržby, zisk, zamestnanci, dlhy, platobný rating, konkurz); Z-skóre ako stupnica 0 – 1,23 – 2,90 – 5+ s pásmami; vedľa karta „V CRM“ s dôvodom žiadosti priamo v karte (nie v bočnom paneli); text o výstrahách pod údajmi. Tabuľka „Ďalšie stavy overenia“ v návrhu je iba vysvetlenie pre teba, do aplikácie nepatrí.
- **32, 33, 39:** porovnám s návrhmi a doplním chýbajúce prvky (napr. odznaky na kartách kanbanu, uzavreté v mesiaci podľa dôvodu prehry, rozpad objemu NN/VN). Prvky ponúk sa doplnia s ponukami.

### 19.1 `0036_ponuky` (`-- migrate:up`)

1. **Počítadlo dokladov** `doc_counter (org_id, kind, year, last_value)` a `doc_number_next(org, 'ponuka', rok)` → `P26-000123` (od 1 každý rok).
2. **Pracovné dni:** `next_working_day(org, deň)`, `working_days_before(org, deň, n)`, `offer_default_valid_until(org, odoslané, druh)` – FIX a kombinácia do 16:00 nasledujúceho pracovného dňa; SPOT a VIWA 14 dní, posun na pracovný deň (časť 6).
3. **Ponuka** podľa časti 1.5: stará tabuľka `offer` a `offer_item` (prázdne) sa prerobia; nový `offer_status`; `offer_variant`, `offer_item` (OOM × rok × zložka), `offer_year_basis` (snímka hraníc ku dňu verzie); `deal.accepted_variant_id` (vyplní akceptácia v F3).
4. **Spoločný výpočet pridanej hodnoty** so zmluvami: výnos a náklad riadku sa vyčlení z `contract_year_calc` (modul 4) do spoločných funkcií; `contract_year_calc` ich začne používať. Testy modulu 4 musia dať rovnaké čísla na halier.
5. **Výpočet ponuky** `offer_variant_calc(variant)` po rokoch: objem (z obchodu, podiel roka ako v bilancii), hranica (cena pre obchodníka / minimálny aditív podľa typu predajcu, alebo schválená výnimka), pridaná hodnota, odhad provízie (PH × % vlastníka); marža firmy iba s právom „vidieť maržu firmy“.
6. **Funkcie ponuky:**
   - `offer_create(obchod)` – číslo, verzia 1, snímka hraníc, variant A s OOM obchodu;
   - `offer_new_version(ponuka, prepočítať)` – kópia variantov a cien, nová snímka, stará verzia Nahradená;
   - `offer_prepare(ponuka)` – kontrola (ceny vyplnené, hranice, výnimky, rizikový zákazník) → Čaká na schválenie alebo Pripravená;
   - `offer_mark_sent(ponuka)` – ručné „Označiť ako odoslanú“ (PDF a e-mail prídu v F3 a F4): platnosť podľa pravidiel, ponuka sa už nemení, obchod z Príležitosti do Cenovej ponuky (otázka 1);
   - zamietnutá (zákazník odmietol), zmazanie konceptu, ktorý nebol odoslaný.
7. **Domácnosti a malé podniky:** ceny z cenníka podľa sadzby a regulácie OOM (`product_candidates_by`, modul 3), obchodník ich nemení; upozornenie nad 30 MWh.
8. **Percento provízie obchodníka** `app_user.commission_pct` (predvolene 40 %) už teraz, kvôli odhadu provízie v editore (otázka 4); celé provízie sú F7.
9. **Stav zákazníka** (`customer_status_calc`, „Ponuka“): iba odoslaná ponuka (`sent_at`), nie Pripravená.
10. RLS (podľa obchodu), audit, práva `crm_app`.

### 19.2 `0037_schvalovanie_ponuk`

- `approval_price_item` (rok, model, napäťová skupina, žiadaná hodnota, hranica, schválená hodnota) – časť 1.8.
- Žiadosti z ponuky: výnimka z ceny (platí 3 dni na odoslanie), rizikový zákazník (celý obchod 30 dní alebo do zhoršenia Finstatu), predĺženie platnosti; `approval_decide` pre tieto druhy („schvaľuje ceny“, schválená hranica môže byť iná ako žiadaná).
- Upozornenia schvaľovateľom do zvončeka (e-mail až s Gmailom v F4).

### 19.3 API a obrazovky

- **API:** `/offers` (založenie z obchodu, karta, hlavička, varianty, uloženie cien po rokoch, prepočítať / nová verzia, pripraviť, označiť ako odoslanú, zamietnutá, zmazať koncept); `/approvals` doplní tri druhy a detail výnimky (ponuka, variant, roky, hranica, objem, PH s výnimkou, marža s právom).
- **Obrazovky:** 34 editor ponuky (varianty, ceny OOM × rok s hranicou a PH, „Rovnaká cena pre NN“, podmienky, súhrn PH a provízie, marža s právom, platnosť), 33 sekcia Ponuky na karte obchodu a PH obchodu z ponuky, 39 záložky Výnimky z ceny, Konkurz / rating, Predĺženie platnosti, 28 výnimky z ponúk iba na čítanie.

### 19.4 Overenie

Ako doteraz: nanečisto na dočasnej databáze (nové testy série C + všetky doterajšie, vrátane bilancie modulu 4 na halier), down/up, lokálne API a obrazovky, potom `dev` po tvojom súhlase, Test, commit po tvojom teste.

### 19.5 Otázky k F2

1. **Štádium pri odoslaní:** keď sa ponuka odošle (zatiaľ ručne „Označiť ako odoslanú“), obchod v Príležitosti sa sám presunie do Cenovej ponuky. Súhlas?
2. **Ručné „Označiť ako odoslanú“** už v F2 (kým nie je PDF a e-mail), aby sa dala vyskúšať platnosť a schvaľovanie; ostane aj potom pre ponuky poslané mimo CRM. Súhlas?
3. **Manažér a FIX:** v bilancii zmlúv (modul 4) je pri predajcovi typu „manažér“ nákladom FIX odhad portfólia, nie cena pre obchodníka. Návrh: v ponuke rovnako – hranica FIX pre manažéra = odhad portfólia, pre obchodníka = cena pre obchodníka. Súhlas?
4. **Percento provízie** pridať k používateľovi už v F2 (predvolene 40 %, mení admin v Nastaveniach), aby editor ukazoval odhad provízie. Súhlas?
5. **Počet variantov:** najviac 5 v jednej ponuke. Súhlas?

### 19.6 Odpovede (Peter, 15. 10. 2026) – plán F2 schválený

1. Odoslanie ponuky posunie obchod z Príležitosti do Cenovej ponuky, **iba dopredu** – obchod vo Vyjednávaní alebo neskôr sa novou verziou nevracia.
2. „Označiť ako odoslanú“ už v F2 a ostáva aj neskôr:
   - nedá sa pri ponuke, ktorá čaká na schválenie alebo má zamietnutú či prepadnutú výnimku;
   - zadá sa **dátum a čas odoslania** a **kanál** (e-mail mimo CRM, osobne, iné); zapíše sa do časovej osi a auditu;
   - platnosť sa počíta od času odoslania;
   - verzia z predošlého pracovného dňa pri FIX → upozornenie a „Prepočítať na dnešné ceny“.
3. Manažér: hranica FIX = odhad nákupnej ceny portfólia (ako bilancia modulu 4), pri SPOT minimálny aditív pre manažéra.
4. Percento provízie pri používateľovi už v F2, predvolene 40 %; mení **admin a obchodný riaditeľ** (schvaľuje ceny); **história „platí od“** a audit; provízia si pri Vyhraté uloží percento platné v tej chvíli (F7), neskoršia zmena ju nemení.
5. Najviac 5 variantov.
- Dokumentácia plánu F2 ide do commitu F2.

## 20. F2 – krok 1: dorovnanie obrazoviek F1, migrácie `0036`, `0037` overené nanečisto (15. 10. 2026)

**Dorovnanie obrazoviek F1 s návrhmi (19.0):**
- 31 Overenie firmy: prepínač IČO / Názov, hlavička firmy (IČO · DIČ · IČ DPH · adresa, Aktívna / Zrušená), dlaždice (tržby, zisk, zamestnanci, dlhy, platobný rating, konkurz), stupnica Z-skóre 0 – 1,23 – 2,90 – 5+, karta „V CRM“ s dôvodom žiadosti priamo v karte, text o výstrahách.
- 32 Obchody: kanban iba otvorené štádiá, súhrn „Uzavreté v mesiaci“ (vyhraté s PH, prehraté podľa dôvodu), predvolený filter „Vlastník: ja“ pre obchodníka, výstrahy navrchu karty, zvýraznenie bez kroku / po termíne, popisy KPI ako v návrhu.
- 33 Karta obchodu: ✓ pri prejdených štádiách, kontaktná osoba a stav Finstatu v údajoch obchodu, filter časovej osi (všetko / poznámky / udalosti). Ponuky, odhad provízie a e-mail pribudnú s API F2.

**`0036_ponuky`** (podľa 19.1 a odpovedí 19.6) – spresnenia oproti plánu:
- percento provízie ako **tabuľka s históriou** `user_commission_rate` (platí od dnes, mení admin a schvaľovateľ cien, riadok sa nemení, budúci sa dá zmazať, audit); `user_commission_pct(používateľ, deň)`, predvolene 40 % (`app_setting`);
- stĺpce schvaľovania (`approval_request.offer_id`, `valid_until`, `requested_valid_until`, `risk_snapshot`), `approval_price_item` a porovnanie rizika (`company_risk_snapshot`, `company_risk_worse`) sú už v `0036`, lebo ich potrebuje výpočet ponuky (výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá);
- `contract_year_calc` používa spoločné funkcie `pv_revenue`, `pv_unit_cost`, `pv_unit_margin_cost`; testy bilancie modulu 4 dávajú rovnaké čísla na halier;
- stará verzia ponuky dostane stav Nahradená **až pri odoslaní novej** (dovtedy ju zákazník môže prijať); naraz je rozpracovaná najviac jedna verzia;
- ponuka na obchod je jedna (ďalšie sú jej verzie); „Prepočítať na dnešné ceny“ pri rozpracovanej verzii prepočíta snímku na mieste, odoslaná dostane novú verziu;
- audit (`0035`) rozšírený o ponuky, varianty, ceny, položky výnimky a percento provízie;
- zložka ceny (`slot`) je text s rovnakými hodnotami ako pri zmluve.

**`0037_schvalovanie_ponuk`:** `approval_request_offer` (výnimky z kontroly ponuky + rizikový zákazník, bez potreby schválenia iba pripraví), `approval_request_extend`, `approval_decide` pre všetky druhy (schválená hranica ≤ žiadaná cena, výnimka 3 dni, riziko 30 dní, predĺženie zapíše platnosť), `approval_cancel` vráti ponuku do konceptu, `approval_price_detail` pre obrazovku 39 (marža iba s právom).

**Overenie (dočasný Postgres, `0001`–`0037` + cenníky):** **191 kontrol OK** (+ C0–C6 v `db/test/checks_ponuky.sql`: pracovné dni a sviatky, platnosť FIX a SPOT, číslo a variant, stráženie zmien, PH s cenou pre obchodníka / minimálnym aditívom / manažér = portfólio, snímka sa nemení s BL/PL, marža iba s právom, RLS, výnimka s inou hranicou a 3 dňami, prepadnutá výnimka, FIX zo starého dňa, kanál a čas odoslania, posun obchodu iba dopredu, nová verzia, skrátenie a predĺženie, zamietnutie, Vypršaná, rizikový zákazník 30 dní a zhoršenie, percento provízie); mutačná skúška (manažér = cena pre obchodníka) zlyhá už v teste bilancie modulu 4; `0037` + `0036` down = schéma `0035`, znova hore bez rozdielu. Existujúci test `checks_zakaznici.sql` zakladá ponuku s číslom a kanálom odoslania.

**Ďalej:** po tvojom súhlase `0036`, `0037` na `dev` → `app-role.sql`; potom API a obrazovky F2 (34 editor, 33 ponuky na karte obchodu, 39 výnimky / riziko / predĺženie, 28 výnimky z ponúk, percento provízie v Nastaveniach).

## 21. F2 – krok 2: `0038_ponuky_doplnky` pred API (Peterove body 1–4, 15. 10. 2026)

`0036` a `0037` už boli na `dev`, preto doplnky idú do novej migrácie (existujúce sa nemenia).

**1. Skryté údaje (odhad portfólia, marža, riziková prirážka):**
- `crm_sees_portfolio()` = admin, „vidieť maržu firmy“ / „schvaľuje ceny“ **alebo predajca typu manažér** (svoju hranicu potrebuje na nacenenie; odhad portfólia je pre rok rovnaký pre všetkých manažérov).
- Hranica z odhadu portfólia (FIX manažéra, cenník) je pre ostatných `NULL` v `offer_variant_values` (`threshold_source` ostáva „odhad_portfolia“), v `offer_check` (`needs[].threshold_value`) a v `approval_price_detail`. Marža firmy ostáva iba s právom (0036).
- `approval_price_item` dostala `threshold_source`; audit jej riadkov s hranicou z odhadu portfólia vidí iba `crm_sees_portfolio()` (neznámy zdroj = skryť). Aplikácia tabuľku nečíta vôbec (`REVOKE ALL`, iba funkcia), snímku `offer_year_basis` tiež nie.
- `offer_item` obsahuje iba ceny (žiadna hranica, snímka ani marža) – overené testom stĺpcov; RLS podľa obchodu.
- **Vedomé rozhodnutie (Peter, 15. 10.):** pridaná hodnota a odhad provízie ostávajú viditeľné každému, kto vidí obchod – rovnako ako PH zmluvy v module 4 –, hoci sa pri ponuke manažéra z PH, ceny a objemu dá odhad portfólia dopočítať. Riziko je iba interné (externí obchodníci obchody manažéra nevidia). Manažér svoju hranicu vidí (Peter potvrdil).

**2. Výnimka pri novej verzii:** prejde, ak (a) je schválená a v 3-dňovej lehote (`valid_until > now()`), (b) ceny nie sú pod schválenou hranicou (inak výpočet „pod hranicou“ → nové schválenie), (c) rozsah variantu je rovnaký ako pri žiadosti – `approval_price_item.scope` = `offer_variant_scope()` (obdobie, plánovaný objem, OOM obchodu s napäťovou skupinou a objemami). Rozsah sa kontroluje iba pri **neodoslanej** verzii; odoslaná si výnimku ponechá (inak by zmena OOM na obchode zmenila už odoslanú alebo akceptovanú ponuku a prenos výnimky do zmluvy v F5). Prevzatá výnimka je kópia položky so žiadosťou pôvodnej verzie; „Prepočítať na dnešné ceny“ ju odpojí (vlastné výnimky verzie zruší ako doteraz), stará verzia ju má ďalej. Detail žiadosti (39) ukazuje iba položky pôvodnej ponuky. Časová os: „nová verzia“ s počtom prevzatých výnimiek.

**3. Akceptácia starej verzie počas prípravy novej:** jadro `offer_accept_apply(ponuka, variant, čas)` – volá ho iba kód databázy (F3 doplní `offer_acceptance`, klik zákazníka a ručný záznam). Akceptovať sa dá odoslanú / otvorenú verziu v platnosti; ostatné odoslané verzie → Nahradená; obchod → Akceptácia s `accepted_variant_id`; upozornenie `ponuka_akceptovana`. Rozpracovaná nová verzia → koncept, čakajúce žiadosti zrušené, upozornenie `ponuka_zablokovana` (vlastník obchodu a autor verzie), udalosť v časovej osi; kontrola ponuky hlási chybu „Zákazník akceptoval ponuku …“, takže verzia sa nedá pripraviť, poslať na schválenie ani odoslať. Koncept sa dá zmazať.

**4.** Schválená hranica ≤ žiadaná cena a jedna ponuka na obchod (ďalšie sú verzie) – potvrdené, bez zmeny.

**Oprava chyby z `0036`:** koncept ponuky sa nedal zmazať (cudzí kľúč `deal_event.offer_id → NULL` narazil na zákaz zmien časovej osi). `deal_event_guard` povolí iba túto jednu zmenu; udalosť ostane s číslom a verziou v detaile.

**Overenie (dočasný Postgres, `0001`–`0038`):** **195 kontrol OK** (+ C7 prenos výnimky a podmienky a–c, prepočet, detail bez kópií; C8 akceptácia a zablokovaná verzia; C9 interný obchodník: ponuka manažéra a jej audit áno, hranica z odhadu portfólia / marža / snímka nie – aj vo vlastnej žiadosti o výnimku na obchode manažéra, externý predajca nič; C4 upravená: platná výnimka prejde). Mutačná skúška – 9 zmien (skrytie v hodnotách, kontrole, detaile a audite; prenos; rozsah; zablokovanie; detail; prepočet), každú test zachytí. `0038` down = schéma `dev` pri `0037` (`db/schema.sql`), znova hore bez rozdielu.

## 22. F2 – krok 3: obrazovka 31 dorovnaná, API a obrazovky F2 (lokálne overené 15. 10. 2026)

`0036`–`0038` sú na `dev` (Peter). Rozhodnutia k bodu 21: manažér svoju hranicu vidí; PH ostáva viditeľná každému, kto vidí obchod (vedomé rozhodnutie – riziko iba interné).

**31 Overenie firmy – dorovnanie s návrhom:** nadpis s podtitulom v riadku, vyhľadávanie s ikonou a obmedzenou šírkou (tlačidlo funguje aj pri hľadaní podľa názvu – overí prvú zhodu), štítok Aktívna / Zrušená s bodkou, dlaždice 4 v riadku na sivom podklade (tržby a zisk v celých eurách, zisk zelený / červený, zamestnanci „25–49“), Z-skóre na 2 desatinné miesta s farbou pásma a plnou trojfarebnou stupnicou, päta oddelená čiarou, karta V CRM s tučným vlastníkom, číslom zmluvy, výstrahou s ikonou a tlačidlami na celú šírku. **Príčina chýbajúcej zelenej:** generátor `web/scripts/tokens.ts` neprekladal odkaz na iný token z `tokens.json` (`{brand-tint}`, `{surface-card}`), takže `--positive-tint` a `--surface-sidebar` boli neplatné – generátor ich teraz prekladá na `var(--…)`; týka sa to zelených štítkov v celej aplikácii.

**API (`api/src/routes/offers.ts`, rozšírené `approvals.ts`):**
- `GET/POST /deals/:id/offers` – verzie ponuky a súhrn hlavného variantu (akceptovaný, inak A poslednej nenahradenej verzie); nová ponuka.
- `GET/PATCH/DELETE /offers/:id` – editor (varianty, ceny, výpočet, kontrola, žiadosti, OOM, produkty, verzie); jazyk a kontaktná osoba; zmazanie konceptu.
- `POST /offers/:id/variants`, `PATCH/DELETE /offer-variants/:id`, `PUT /offer-variants/:id/prices` (komodita OOM × rok; prázdna cena = zmazať).
- `POST /offers/:id/reprice | prepare (bez potreby schválenia pripraví, inak žiadosť s dôvodom) | mark-sent | reject | new-version | shorten | extend`.
- `GET /offer-exceptions` (obrazovka 28, cez `approval_price_detail`); `GET/POST /commission-rates`, `DELETE /commission-rates/:id`.
- Schvaľovanie: záložky výnimky / konkurz-rating / predĺženie, súhrn žiadosti, `GET /approvals/:id` (položky, výstrahy, iná čakajúca žiadosť obchodu), rozhodnutie so schválenou hranicou po položkách.

**Obrazovky:** 34 editor ponuky (`/ponuky/:id`: varianty A–E, typ ceny, obdobie, produkt, model po rokoch pri FIX + SPOT a pri výkupe, ceny OOM × rok s hranicou a PH, „Vyplniť NN“, podmienky, súhrn s odhadom provízie a maržou s právom, kontrola, žiadosti, panely Pripraviť / Označiť ako odoslanú / Zákazník odmietol / Skrátiť / Požiadať o predĺženie / Zmazať koncept, prepínač verzií); 33 sekcia Ponuky, PH a odhad provízie z ponuky v KPI, udalosti ponúk v časovej osi; 39 záložky a detail výnimky so schválenou hranicou („Schváliť na 3 dni“); 28 karta „Výnimky z ponúk“ (iba čítanie); Nastavenia → Používatelia: percento provízie s históriou (admin; obchodný riaditeľ cez API, obrazovku dostane s Províziami v F7). Zvonček: popisy upozornení obchodov presunuté zo zlej mapy (chyba F1) a nové druhy.

**Overenie:** API celým tokom na dočasnej databáze s vymyslenými údajmi „TEST“ (ponuka, ceny, výnimka, schválenie inej hranice, odoslanie, nová verzia s prevzatou výnimkou, druhá výnimka), snímky obrazoviek porovnané s návrhmi 31, 33, 34, 39, 28; databázové testy 195 kontrol OK.

**Mimo F2 (zámerne):** PDF, stránka ponuky a akceptácia (F3), e-mail z CRM (F4); ponuka VIWA sa dá založiť, ale ceny VIWA (účet, €/kW z cenníka) dopĺňa až F3 – variant VIWA zatiaľ hlási „chýba cena“; zoznam Ponuky v menu nie je v zadaní F2; PH v zozname obchodov ostáva odhad obchodníka (iba karta obchodu počíta z ponuky).

## 23. Plán F3 – PDF, stránka ponuky, akceptácia (na schválenie, 15. 10. 2026)

F2 je uzavretá (commit `d6ab0a9`). F3 podľa častí 1.7, 1.10, 4, 5 a zadania 7.1–7.3; obrazovky 35, 36, 42 a úpravy 33, 34.

### 23.1 Cloudflare (zmena nastavení – iba s Petrovým súhlasom, príkazy spúšťa Peter)

1. R2 bucket `crm-dokumenty-test` s jurisdikciou EÚ, súkromný (Ostré neskôr zvlášť).
2. Browser Rendering (Browser Run) – binding `BROWSER` vo Workeri `crm-core` (Workers Paid už je).
3. Nový Worker `crm-ponuka` (priečinok `ponuka/`) mimo Access, na Teste adresa `*.workers.dev`; vlastná konfigurácia Hyperdrive pre rolu `crm_public`; R2 iba na čítanie; Rate Limiting bindings (zobrazenie 30/min, neplatný token 10/10 min, akceptácia 5/h).
4. Rola `crm_public` na `dev` (skript ako `create-app-role.sh`, heslo iba v `.dev.vars` a Hyperdrive): žiadna tabuľka, iba `EXECUTE` na tri verejné funkcie.

### 23.2 Migrácia `0039_ponuky_pdf_akceptacia`

- `offer_template_version` (druh × jazyk, verzie Návrh / Platná / Nahradená, sekcie a predvolené hodnoty, premenné «…» iba zo zoznamu), `offer_asset` (obrázky PDF, bytea do 1 MB; pri prázdnej tabuľke pribalené z `docs/dizajn/obrazovky/assets/`). Úvodné šablóny SK: dodávka, výkup, VIWA; EN ako návrh na Petrovu kontrolu.
- `offer`: `template_version_id`, `pdf_key`, `pdf_sha256`, `pdf_generated_at`, `link_hash` (SHA-256 tokenu), `link_created_at`; `offer_page_stat` (prvé a posledné otvorenie, počet – bez IP). Prvé otvorenie: Odoslaná → Otvorená, udalosť v časovej osi.
- `offer_acceptance` podľa 1.7 (klik / ručne / podpísané PDF; nemení sa, iba zrušenie adminom s dôvodom → obchod späť do Vyjednávania, verzia späť Odoslaná, zablokovaná verzia sa odblokuje).
- `offer_terms_text(ponuka, variant, meno, funkcia)` – znenie záväznej objednávky (VIWA: prijatie ponuky) zo šablóny, zjednotené (NFC, `\n`); odtlačok počíta databáza, stránka posiela odtlačok, ktorý zákazník videl.
- `offer_accept_apply` (0038) dostane zápis `offer_acceptance`; `offer_accept_manual(...)` pre obchodníka (variant, meno a funkcia podpisujúceho, čas, poznámka, voliteľne kľúč podpísaného PDF); `offer_acceptance_revoke(id, dôvod)` iba admin.
- Verejné funkcie pre `crm_public` (`SECURITY DEFINER`): `offer_public_view(hash)`, `offer_public_pdf(hash)`, `offer_public_accept(hash, variant, meno, funkcia, ip, prehliadač, odtlačok)`. Platnosť odkazu: do `valid_until` akceptácia, potom 30 dní iba čítanie, potom „Odkaz už neplatí“.
- RLS, audit, upozornenie `ponuka_otvorena` sa nezavádza (iba časová os); testy `checks_ponuky_f3.sql` (séria D): token a platnosť, čo verejná funkcia vráti a čo nie (žiadne EIC, hranica, PH, marža), odtlačok znenia, dvojklik, akceptácia po platnosti, ručná akceptácia, zrušenie adminom, rola `crm_public` bez prístupu k tabuľkám.

### 23.3 API a Worker

- `crm-core`: `GET /offers/:id/preview.pdf` (náhľad, neukladá sa); `POST /offers/:id/send-manual` = doterajšie „Označiť ako odoslanú“ + PDF do R2 + odkaz (token sa ukáže **iba raz**, v databáze je len jeho odtlačok; „Nový odkaz“ starý zneplatní); `GET /offers/:id/pdf`; `POST /offers/:id/accept-manual` (+ nahratie podpísaného PDF do 10 MB); `POST /offer-acceptances/:id/revoke`; `/settings/offer-templates` a `/settings/offer-assets`.
- Jedna funkcia skladá HTML ponuky pre náhľad aj PDF (obrázky vložené ako `data:`, žiadne sťahovanie z internetu); produkty zlúčené podľa produktu, napätia a ceny, bez EIC; päta s číslom strany a ponuky.
- `crm-ponuka`: `GET /p/:token`, `GET /p/:token/pdf`, `POST /p/:token/accept`; hlavičky `no-referrer`, `noindex`, prísna CSP, `no-store`; prepínač SK/EN mení iba popisky.

### 23.4 Obrazovky

35 PDF ponuky, 36 stránka pre zákazníka, 42 Nastavenia → Šablóny ponúk (texty po sekciách, verzie, predvolené hodnoty, obrázky); 34 editor: Náhľad PDF, odoslanie s odkazom na skopírovanie a PDF na stiahnutie, ručná akceptácia, údaje akceptácie; 33 časová os (otvorenie, akceptácia).

### 23.5 Otázky k F3

1. **PDF: Browser Run alebo `pdf-lib`?** Browser Run nemá voľbu regiónu (vykreslenie prebehne v sieti Cloudflare, uložené dáta ostávajú v EÚ). **Odporúčam Browser Run** – jedno HTML pre náhľad, PDF aj stránku.
2. **Texty šablón:** máte dnešné vzory PDF (dodávka, výkup, VIWA)? Dajte ich do `exports/ponuky-vzory/`. Inak úvodné texty vezmem z návrhu 35 ako návrh a doplníte ich na obrazovke 42.
3. **Cloudflare (23.1):** súhlasíte so zmenami 1–4? Nasadenie a zmeny Cloudflare môj nástroj blokuje – príkazy vám dám presne, alebo ich povolíte v nastaveniach Claude Code.
4. **Odkaz na stránku** sa ukáže iba raz pri odoslaní (bezpečnejšie); „Nový odkaz“ starý zneplatní. Súhlas?
5. **Ručná akceptácia:** povinný variant, meno a funkcia podpisujúceho a čas; podpísané PDF voliteľné. Súhlas?
6. **Zrušenie akceptácie adminom:** obchod späť do Vyjednávania, ponuka späť Odoslaná. Súhlas?
7. **Potvrdenie zákazníkovi e-mailom** pribudne s Gmailom (F4); v F3 stránka ukáže potvrdenie a PDF so záväznou objednávkou a obchodník dostane upozornenie. Súhlas?

### 23.6 Odpovede (Peter, 15. 10. 2026) – plán F3 schválený

1. PDF cez Browser Run – áno. 2. Texty: `docs/moduly/05-sablony-ponuk-texty.md`, prvé verzie šablón v `0039`. 3. Zmeny Cloudflare a nasadenie spúšťa Peter podľa presných príkazov. 4. Odkaz iba raz, v DB odtlačok; nový odkaz iba vlastník obchodu alebo admin, starý zneplatní, audit, platnosť sa nemení. 5. Ručná akceptácia: variant, meno, funkcia, čas, kanál (telefón, e-mail, osobne, podpísané PDF) povinné, PDF voliteľné, zapíše sa kto. 6. Zrušenie akceptácie: admin, dôvod, iba bez spárovanej zmluvy; po platnosti Vypršaná; zablokovaná verzia sa neodblokuje sama. 7. Potvrdenie e-mailom až v F4. Akceptácia klikom čaká na P4 – dovtedy musí fungovať ručná s podpísaným PDF. (Rozhodnutia 15. 10.)

## 24. F3 – krok 1: `0039_ponuky_pdf_akceptacia` overená nanečisto (15. 10. 2026)

**Obsah:**
- `app_user.phone`, `job_title` (do „Cenovú ponuku spracoval“; do profilu v F4, zatiaľ zadá admin).
- `offer_template_version` (druh × jazyk, Návrh / Platná / Nahradená, sekcie `{nadpis, text}`, kontrola povolených premenných a blokov, `offer_template_publish` iba admin) + prvé verzie z textov (SK platné, EN návrh); `offer_asset` (obrázky, bez auditu kvôli binárnym dátam, nemenia sa – iba vypnú).
- `offer`: `penalty_eur_mwh`, `template_version_id`, `pdf_key`, `pdf_sha256`, `link_hash` (iba SHA-256), `blocked_by_offer_id`; `offer_page_stat` (otvorenia bez IP, prvé otvorenie → Otvorená + časová os).
- Ceny VIWA z cenníka (`offer_fill_viwa`: mesačný poplatok účtu, €/kW, komodita podľa balíka) – doplnené aj do prepočtu a vytvorenia variantu. Koeficient v `0039` z odhadu aditívu – opravené v `0040` (časť 25).
- Dokument ponuky na jednom mieste v databáze (`offer_document`, `offer_document_internal`): vyplnené sekcie šablóny, premenné (rovnaká hodnota raz, inak po variantoch), varianty s riadkami zlúčenými podľa produktu, napätia a cien (bez EIC), VIWA a pri domácnosti ceny s DPH, mesačné poplatky a odhad ročných nákladov; znenie objednávky po variantoch (`offer_terms_text`, zjednotené NFC) a jeho odtlačok.
- `offer_attach_pdf` (raz, pri odoslaní; šablóna sa zafixuje – musí byť platná, EN návrh neodíde), `offer_link_set` (prvý odkaz pri odoslaní, nový iba vlastník obchodu alebo admin, časová os, audit).
- `offer_acceptance` (klik / ručne s kanálom, znenie a odtlačok, odtlačok PDF, kto zaznačil; nemení sa, iba zrušenie), `offer_accept_manual`, `offer_acceptance_revoke` (admin, dôvod, nie pri Vyhraté; ponuka Odoslaná / Vypršaná, obchod Vyjednávanie), `offer_unblock` (vlastník obchodu alebo admin); zablokovanie verzie je trvalý príznak (nezruší ho zrušenie akceptácie).
- Verejné funkcie (`offer_public_view / _pdf / _accept`) cez schému **`verejne`** (`ponuka_zobrazit`, `ponuka_pdf`, `ponuka_akceptovat`). **Izolácia:** schéma `public` už nie je prístupná všetkým (PUBLIC), výslovne ju má `crm_app` (a `crm_sync`, `neon_superuser`, ak existujú); `crm_public` má iba schému `verejne`; `crm_current_user_id()` pri prihlásení `crm_public` ignoruje `app.user_id`. Bez toho by zneužitý verejný Worker mohol volať funkcie s právami vlastníka (napr. odhad portfólia) aj s cudzou identitou.
- RLS: šablóny a obrázky číta každý prihlásený, mení admin; akceptácie a otvorenia podľa ponuky, zapisuje iba databáza. Nové druhy časovej osi a upozornení (`ponuka_otvorena`, `ponuka_odkaz`, `akceptacia_zrusena`, `ponuka_odblokovana`).
- `api/db/app-role.sql`: ponuku aplikácia mení iba v jazyku, kontakte, vlastných poliach a pokute; akceptácie a otvorenia iba číta. Nové `api/db/public-role.sql` a `api/db/create-public-role.sh` (rola `crm_public`, heslo iba do `.dev.vars`, overenie izolácie).

**Overenie (dočasný Postgres):** **205 kontrol OK** (+ D0–D6 v `db/test/checks_ponuky_f3.sql`: šablóny a verzie, VIWA, dokument bez EIC a interných hodnôt, PDF a odkaz, verejná rola – izolácia, otvorenia, akceptácia s odtlačkom, dvojklik, po platnosti a po 30 dňoch, ručná akceptácia, zrušenie, zablokovanie a odblokovanie); mutačná skúška 6 zmien (odtlačok znenia, nový odkaz, zrušenie pri Vyhraté, zablokovanie, 30 dní, iba admin) – každú test zachytí; `0039` down = schéma `dev` pri `0038`, znova hore bez rozdielu; `app-role.sql` a `public-role.sql` prejdú, prihlásenie ako `crm_public` nevidí tabuľky ani funkcie v `public`. Existujúci test `checks_zakaznici.sql` dáva roli `crm_rls_test` schému `public` výslovne.

**Ďalej:** po tvojom súhlase `0039` na `dev` → `app-role.sql` → rola `crm_public` → `run.sh`; potom API, Worker `crm-ponuka`, obrazovky 35, 36, 42 a úpravy 33, 34 a presné príkazy pre Cloudflare.

## 25. F3 – krok 2: `0040_ponuky_f3_doplnky` (Peterove body 1–4, 15. 10. 2026)

`0039` už bola na `dev` (Peter, vrátane `app-role.sql` a roly `crm_public`), preto doplnky idú do `0040`; súbor `0039` je presne v podobe z `dev` (overené porovnaním schémy s `db/schema.sql`).

1. **Predvolené práva:** `ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC` (aj tabuľky a sekvencie výslovne), v schéme `public` `GRANT EXECUTE ON FUNCTIONS TO crm_app`. Funkcie budúcich migrácií teda PUBLIC nespustí; interná funkcia v novej migrácii sa odoberie `FROM PUBLIC, crm_app`. Cockpit a iné služby: vlastná rola. Testy: `db/test/checks_predvolene_prava.sql` (prvý v `run.sh`) overí predvolené práva vlastníka a potom ich **iba v transakcii testov** vráti PUBLIC, aby pomocné funkcie testov v `pg_temp` spúšťala testovacia rola. D8: verejná rola (`crm_public_test` aj skutočná `crm_public`, ak existuje) nemá schému `public`, nečíta žiadnu tabuľku a spustí iba tri funkcie v `verejne`; novú funkciu má aplikácia.
2. **Koeficient VIWA** zo schválenej položky cenníka (`price_list_item_program.viwa_conversion_factor` cez položku „účet“ variantu); odhad aditívu iba pre pridanú hodnotu. Test D1: nový odhad aditívu (40) koeficient 0,85 nezmení.
3. **Zmluvná pokuta:** zvýšiť smie obchodník; nižšia ako v šablóne → v kontrole ponuky potreba schválenia (`type: pokuta`), žiadosť `vynimka_ceny` dostane `penalty_eur_mwh` (bez položiek ceny, ak iné výnimky nie sú), schvaľuje „schvaľuje ceny“, platí 3 dni na odoslanie, odoslaná si ju ponechá. Test D7.
4. Úpravy textov šablón – súhlas; EN schváli Peter na obrazovke 42.

**Overenie (dočasný Postgres, `0001`–`0040`):** **209 kontrol OK**; mutácia (pokuta bez kontroly) zlyhá v D7; bez `0040` zlyhajú predvolené práva; `0040` down = schéma `dev` (pri `0039`) a bez predvolených práv, znova hore bez rozdielu.

## 26. F3 – krok 3: API, Worker `crm-ponuka`, obrazovky (lokálne overené 15. 10. 2026)

**Cloudflare (Peter):** R2 `crm-dokumenty-test` (jurisdikcia EÚ, `-J eu`), Hyperdrive `crm-ponuka-dev` (rola `crm_public`, cache vypnutá, ID `6f5c43b3d47749f4b509a32043e75ef7`). Browser Run bez príkazu (Workers Paid). `0039`, `0040` na `dev`, `app-role.sql`, rola `crm_public`; lokálne API proti `dev` (rola `crm_app`, iba čítanie) – hlavné obrazovky 200.

**`crm-core` (API):** `api/src/routes/offers-pdf.ts`
- `GET /offers/:id/document`, `/preview.pdf` (vodotlač NÁHĽAD / NÁVRH ŠABLÓNY, neukladá sa), `POST /offers/:id/send` (v jednej transakcii: stav Odoslaná a platnosť, PDF cez Browser Run do R2 `ponuky/{org}/{rok}/{číslo}[-verzia].pdf`, šablóna sa zafixuje, odkaz – token 32 bajtov base64url, do DB iba SHA-256; odkaz sa vráti iba raz), `POST /offers/:id/link` (nový odkaz), `GET /offers/:id/pdf`.
- Akceptácia: `GET /offers/:id/acceptance` (aj otvorenia stránky), `POST /offers/:id/accept-manual` (podpísané PDF base64 do 10 MB, kontrola `%PDF-`, R2 `podpisane/…`), `GET /offer-acceptances/:id/signed.pdf`, `/confirmation.pdf` (z uloženého znenia, s IP a odtlačkom), `POST /offer-acceptances/:id/revoke`, `POST /offers/:id/unblock`.
- Šablóny (obrazovka 42): `GET/POST/PATCH/DELETE /offer-templates`, `/publish`, `/preview.pdf` (vzorové údaje, texty vyplní DB). Obrázky: `GET /offer-assets`, `GET /offer-assets/:code`, `POST /offer-assets` (admin, do 1 MB).
- Zmluvná pokuta v `PATCH /offers/:id`; editor dostane PDF, odkaz, zablokovanie, šablónu a jej predvolenú pokutu. „Označiť ako odoslanú“ (F2) nahradilo odoslanie s PDF a odkazom. Nastavenia → Používatelia: telefón a funkcia.
- `api/src/render/offer-html.ts` (HTML ponuky 35 a potvrdenia, zdieľa aj `crm-ponuka`), `render/pdf.ts` (`@cloudflare/puppeteer` 1.4.0), `render/assets.ts` (obrázky z Nastavení, inak pribalené `api/src/assets/*.png`). `wrangler.toml`: `[browser]`, R2 `DOCS` (jurisdikcia EÚ), pravidlo `Data` pre PNG, `PUBLIC_OFFER_URL`.

**Worker `crm-ponuka` (`ponuka/`):** `GET /p/:token` (stránka 36 bez JavaScriptu, prepínač SK/EN mení iba popisky), `GET /p/:token/pdf`, `GET /p/:token/potvrdenie.pdf` (vykreslí sa na požiadanie, neukladá sa), `POST /p/:token/accept` (formulár; variant nesie odtlačok znenia, ktoré zákazník videl; IP z `CF-Connecting-IP`; presmerovanie s kódom hlášky). Volá iba `verejne.*`. Hlavičky: prísna CSP bez skriptov, `no-referrer`, `noindex`, `no-store`, `nosniff`. Obmedzenie pokusov podľa IP (Workers Rate Limiting – obdobie iba 10 alebo 60 s): zobrazenie 30/min, neplatný odkaz 10/min, akceptácia 5/min (návrh 5.2 mal 10/10 min a 5/h – bližšie po nasadení na Ostrom cez pravidlo WAF na doméne).

**Obrazovky:** 34 editor (Odoslať zákazníkovi – PDF a odkaz zobrazený raz s kopírovaním, Náhľad PDF / PDF ponuky, Nový odkaz, Zaznačiť akceptáciu s podpísaným PDF, karta Akceptácia s otvoreniami, potvrdením, podpísaným PDF a zrušením, banner zablokovanej verzie s odblokovaním, banner EN šablóny v návrhu, zmluvná pokuta v podmienkach, potreba schválenia pokuty v kontrole); 33 časová os (otvorenie, nový odkaz, zrušenie akceptácie, odblokovanie); 39 pokuta v žiadosti; 42 Nastavenia → Šablóny ponúk (verzie, úprava návrhu po sekciách, náhľad PDF, zverejnenie, obrázky); 36 stránka ponuky; 35 PDF.

**Overenie (dočasná DB, lokálny R2 a Browser Run):** náhľad PDF (5 strán: titulná, ponuka, referencie s príbehom a víziou, záväzná objednávka), odoslanie (PDF v R2, odkaz, šablóna zafixovaná), verejná stránka (hlavičky, PDF, neplatný odkaz 404), akceptácia formulárom (bez potvrdenia, so zmeneným znením, úspech, dvojklik), potvrdenie v PDF zo stránky aj z CRM, IP a otvorenia v CRM, zrušenie akceptácie (bez dôvodu odmietne), ručná akceptácia s podpísaným PDF, šablóny (zverejnenie, náhľad, neznáma premenná odmietnutá). Databázové testy 209 OK; typová kontrola `api`, `ponuka`, `web`.

## 27. F3 – krok 4: `0041_potvrdenie_akceptacie` (Peterove body 1–3, 15. 10. 2026)

1. **Potvrdenie akceptácie sa ukladá v momente akceptácie** (mení časť 26): `offer_acceptance.confirmation_pdf_key`, `confirmation_pdf_sha256`; kľúč určuje databáza (`potvrdenia/{org}/{rok}/{číslo}[-verzia]-{id8}.pdf`). Klik: Worker `crm-ponuka` v jednej transakcii zavolá `verejne.ponuka_akceptovat` (vráti uložené znenie, IP, odtlačok, dokument a kľúč), vykreslí potvrdenie, uloží ho do R2 a odtlačok cez `verejne.ponuka_potvrdenie_ulozit` (iba ku klik-akceptácii tejto ponuky, do 10 minút, raz). Ručne: `crm-core` po `offer_accept_manual` cez `offer_acceptance_for_confirmation` a `offer_acceptance_confirmation_set`. Stiahnutie (CRM aj stránka cez `verejne.ponuka_potvrdenie_pdf`) vracia uložený súbor – overené: zo stránky aj z CRM rovnaký súbor, odtlačok sa zhoduje s DB. Potvrdenie ručnej akceptácie uvádza aj kanál. Interná `offer_acceptance_confirmation_attach` nie je pre PUBLIC ani `crm_app` (odobratie podmienené existenciou roly – `main` ju ešte nemá). Testy D4 (uloženie raz, iba správny kľúč a odkaz), D6 (ručná), D8 (verejná rola iba funkcie v `verejne`).
2. **WAF na Ostrom** – zapísané do úloh pred Ostrým (STAV). Na ochranu dôkazov odporúčam R2 **bucket lock** (súbory v `ponuky/`, `potvrdenia/`, `podpisane/` nemožno prepísať ani zmazať).
3. **Doplnky z predošlej správy sú v `0040`, nie v `0039`** (0039 už bola na `dev`): predvolené práva (`ALTER DEFAULT PRIVILEGES` – test `checks_predvolene_prava.sql` a D8), koeficient VIWA z programu cenníka (D1, zmena odhadu aditívu ho nemení), schválenie nižšej zmluvnej pokuty (D7).
4. **Hlásenie chýbajúcej hranice** (Peter, test na dev: ponuka manažéra založená pred doplnením odhadu portfólia): pri manažérovi „chýba odhad portfólia (hranica manažéra) – doplňte ho v cenách dňa a ponuku prepočítajte“, pri obchodníkovi „chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte“ (`offer_variant_values` v `0041`, test D9). Ponuka si ceny fixuje k dátumu verzie – po doplnení cien dňa ju treba prepočítať.

## 28. Plán F4 – e-maily z CRM cez Gmail (na schválenie, 15. 10. 2026)

F3 je uzavretá (commit `3228296`). F4 podľa častí 1.9, 1.10 (e-maily), 3 (Gmail) a zadania 8; obrazovka 37, profil používateľa, Nastavenia → Šablóny e-mailov.

### 28.1 Predpoklady (Peter)

1. Google Workspace podľa časti 3.7: projekt v Google Cloud, Gmail API, servisný účet `crm-gmail`, kľúč JSON, delegovanie na doménu s oprávneniami `gmail.send` a `gmail.readonly`, schránka `crm@greenlogy.com`.
2. Cloudflare: `wrangler secret put GOOGLE_SA_KEY` (Test), na Teste `MAIL_ALLOWLIST` (adresy mimo @greenlogy.com, na ktoré smie Test posielať); nový Cron `*/5 * * * *` (kontrola odpovedí a fronta) – vo `wrangler.toml`.

### 28.2 Migrácia `0042_emaily`

- `app_user`: `gmail_enabled` (pilot, mení admin), profil do podpisu – `mobile`, `photo` (bytea do 300 kB) a `linkedin_url` (telefón a funkcia už sú z `0039`).
- `email_thread`, `email_message`, `email_outbox`, `gmail_mailbox_state`, `mailbox_access_log` podľa 1.9 (denník čítania iba pridávanie, nemení sa ani nemaže); `email_template_version` podľa 1.10 (verzie ako pri šablónach ponúk; mení admin a Marketing) s prvými verziami SK (EN návrh): ponuka dodávka / výkup / VIWA, potvrdenie akceptácie, pripomienka platnosti, voľný e-mail.
- `gmail_thread_allowed(schránka, thread_id)` – jediná kontrola v databáze, či vlákno patrí CRM a schránke (volá ju `gmailRead` pred každým čítaním); zápis do denníka čítania.
- Odoslanie ponuky e-mailom: kanál `crm` (už v `offer_send_channel`) – v jednej transakcii stav Odoslaná, PDF, odkaz a záznam e-mailu; ak Gmail odmietne, transakcia sa vráti a ponuka ostane Pripravená.
- Koncept pripomienky platnosti v nočnom behu: 2 pracovné dni pred koncom platnosti, iba SPOT a VIWA (odpoveď 12) – odošle ho obchodník jedným klikom.
- Upozornenia `ponuka_odpoved`, `ponuka_pripomienka`, `gmail_chyba`; RLS: vlákna a správy podľa obchodu / zákazníka, denník čítania iba admin; audit.
- Testy séria E: denník čítania sa nedá meniť, `gmail_thread_allowed` odmietne cudzie vlákno a cudziu schránku, fronta, pripomienka (pracovné dni, iba SPOT/VIWA), RLS, šablóny (povolené premenné).

### 28.3 Kód

- `api/src/gmail.ts`: token cez `jose` (JWT RS256, oprávnenia `gmail.send` + `gmail.readonly`, iba pre aktívneho používateľa @greenlogy.com so zapnutým Gmailom), `gmailSend` (MIME: HTML + text, PDF ponuky v prílohe, fotka podpisu `cid:`, bez sledovacích pixelov, vo vlákne `In-Reply-To` / `References`; na Teste iba @greenlogy.com a `MAIL_ALLOWLIST`), **`gmailRead`** – jediné miesto čítania (`threads.get`, `messages.get`, `attachments.get`), pred volaním `gmail_thread_allowed`, každé čítanie do denníka; nikdy `list`, `search` ani `history.list`. Kontrola v repozitári (skript `api/scripts/check-gmail.mjs` v `npm run typecheck`): žiadny iný súbor nevolá čítanie Gmail API a `gmailRead` odmietne `list` / `q`.
- Cron `*/5`: sledované vlákna (`watch_until` ≥ dnes – aktivita za 30 dní) → `threads.get` (metadata) → nové správy `messages.get` → `email_message` (vyčistené HTML cez HTMLRewriter – bez skriptov, štýlov, rámcov, obrázkov z webu a `javascript:` odkazov; prílohy iba zoznam), upozornenie vlastníkovi; fronta `email_outbox` (potvrdenie akceptácie zákazníkovi do vlákna ponuky, e-mail schvaľovateľom z `crm@`), 3 pokusy; chyba schránky → `gmail_mailbox_state`, po 3 chybách upozornenie adminom.
- API: `/emails` (koncept, odoslať, vlákno, príloha na stiahnutie cez `gmailRead`), `/me/profile` (fotka, telefóny, LinkedIn, náhľad podpisu), `/settings/email-templates`, `/settings/gmail-check` (token + iba profil schránky).
- Obrazovky: 37 nový e-mail (z editora ponuky „Odoslať e-mailom“ s odkazom a PDF, z karty obchodu a zákazníka voľný e-mail, šablóna, úprava textu, podpis z profilu, koncept), časová os obchodu a zákazníka s e-mailmi a odpoveďami, profil používateľa, Nastavenia → Šablóny e-mailov, Nastavenia → Používatelia (Gmail zapnutý – pilot), Audit (filter „Čítanie schránok“).

### 28.4 Otázky k F4

1. **Google Workspace (28.1):** kedy bude pripravený servisný účet, delegovanie a `crm@greenlogy.com`? Kód a testy viem urobiť skôr (lokálne bez Gmailu), skutočné odoslanie až s kľúčom.
2. **Text dnešného e-mailu s ponukou** (predvolená šablóna podľa zadania 8): pošlete mi ho? Inak vezmem text z návrhu 37 ako návrh na úpravu na obrazovke šablón.
3. **Pripomienka platnosti:** zadanie 8 hovorí „deň pred koncom“, odpoveď 12 „2 pracovné dni pred koncom, iba SPOT a VIWA“. **Odporúčam odpoveď 12.** Súhlas?
4. **Potvrdenie akceptácie zákazníkovi, keď obchodník ešte nemá zapnutý Gmail (pilot):** odoslať z `crm@greenlogy.com` s odpoveďou na obchodníka (Reply-To), alebo neposielať? **Odporúčam `crm@` s Reply-To.**
5. **E-mailom z `crm@` posielať iba** novú žiadosť o schválenie schvaľovateľom (tabuľka 1.14); ostatné upozornenia ostávajú iba v zvončeku. Súhlas?
6. **Fotka do podpisu:** v databáze (do 300 kB, ako obrázky PDF). Súhlas?
7. **`MAIL_ALLOWLIST` na Teste:** okrem @greenlogy.com ktoré adresy (napr. vaša súkromná na skúšku)?

### 28.5 Odpovede (Peter, 16. 10. 2026) – plán F4 schválený

1. Google Workspace a `crm@greenlogy.com` sú pripravené; kód a testy hneď. Do 3.7 doplnený bod 1a (výnimka z `iam.disableServiceAccountKeyCreation` iba pre projekt CRM).
2. Šablóna e-mailu s ponukou podľa dnešného e-mailu obchodníkov (predmet „Cenová ponuka «číslo ponuky» – «názov zákazníka»“, «oslovenie», «zhrnutie variantov», «platnosť», «odkaz na ponuku», «podpis»). «oslovenie» je pole pri kontakte (predvolene „Dobrý deň“, obchodník ho zmení); «zhrnutie variantov» predvyplní CRM (napr. „FIX na rok 2027 a SPOT + 8,00 €/MWh“), obchodník ho môže upraviť. SK platné, EN návrh.
3. Koncept pripomienky platnosti 2 pracovné dni pred koncom, iba SPOT a VIWA (zadanie 8 opravené).
4. Potvrdenie akceptácie zákazníkovi: s zapnutým Gmailom zo schránky obchodníka do vlákna ponuky, inak z `crm@greenlogy.com` s Reply-To na obchodníka; vždy s PDF potvrdenia uloženým pri akceptácii.
5. Z `crm@`: schvaľovateľom nová žiadosť o schválenie; obchodníkovi akceptácia zákazníkom a výsledok jeho žiadosti. Ostatné iba zvonček.
6. Fotka do podpisu v DB do 300 kB, pri nahratí orezaná na štvorec a zmenšená; mení ju používateľ sám alebo admin.
7. `MAIL_ALLOWLIST` na Teste: Petrova súkromná adresa na skúšku – iba ako secret, nie v kóde ani v dokumentoch.
8. **Odoslanie ponuky e-mailom – odolnosť:** najprv záznam „odosiela sa“ s jednorazovým kľúčom, potom odoslanie, potom ID správy z Gmailu a stav Odoslaná. Ak sa po odoslaní nepodarí dokončiť zápis, ďalší beh fronty / nočná kontrola nájde ponuky „odosiela sa“ a podľa ID správy ich dokončí, nikdy neodošle znova. Test.

## 29. F4 – krok 1: `0042_emaily` (overená nanečisto 16. 10. 2026)

- **Profil a podpis:** `app_user.gmail_enabled` (pilot, zapína admin), `mobile`, `linkedin_url` (iba `https://…linkedin.com/…`); `user_photo` (do 300 kB, PNG/JPEG, odtlačok; mení sám alebo admin – RLS; bez auditu riadkov); `user_profile_set`, `email_signature`, `user_photo_get`. `contact.salutation` – «oslovenie», prázdne = „Dobrý deň“ (EN „Dear Sir or Madam“).
- **Šablóny e-mailov** `email_template_version` (ako šablóny ponúk): `ponuka_dodavka / _vykup / _viwa`, `potvrdenie_akceptacie`, `pripomienka_platnosti`, `volny`; SK platné, EN návrh; mení admin a tím Marketing (`crm_email_template_editor`), platná sa nemení, `email_template_publish`. Kontrola premenných, «podpis» povinný, odkaz a podpis nie v predmete. Pripomienka odkaz neobsahuje (v DB je iba odtlačok) – odkazuje na pôvodný e-mail.
- **Vlákna a správy:** `email_thread` (schránka; `NULL` = crm@; väzba na obchod / firmu / kontakt / ponuku; `watch_until`), `email_message` (stavy koncept, v rade, odosiela sa, odoslaný, chyba, prijatý; `send_key`, `pending`; po odoslaní sa nemení; telo nejde do auditu). Zápis iba funkciami; RLS podľa obchodu / zákazníka a schránky, koncept vidí iba autor (koncept pripomienky vlastník schránky).
- **Odoslanie (odpoveď 8):** `email_compose_offer` (predvyplnenie, zhrnutie variantov `offer_variants_summary_text`, adresát) → `email_draft_save` → `email_send_prepare(id, kľúč, PDF, odtlačok odkazu)` (kontrola ako pri odoslaní, `fresh = false` pri rovnakom kľúči – kód neodošle znova; doplní «platnosť») → Gmail → `email_send_recorded` (ID správy a vlákna hneď, samostatne) → `email_send_complete` (ponuka Odoslaná kanálom `crm`, PDF, šablóna, odkaz; vlákno sa sleduje 30 dní). Počas odosielania je ponuka zamknutá (`offer_email_lock`). Ak sa ponuka nedá dokončiť, e-mail ostane Odoslaný a autor + admin dostanú upozornenie `email_chyba`. Gmail odmietol → `email_send_failed` (koncept s chybou). `email_pending_recover` (beh na pozadí): s ID dokončí, bez ID po 15 min Chyba + upozornenie, **nikdy neodošle znova**; obchodník po kontrole Odoslaných vráti do konceptu (`email_retry`). `offer_mark_sent` rozdelená na `offer_send_check` + `offer_mark_sent_apply` (správanie rovnaké; kanál `crm` ručne nejde).
- **Čítanie Gmailu:** `gmail_read_authorize(schránka, vlákno, správa, metóda)` – jediná kontrola: iba `threads.get` / `messages.get` / `attachments.get`, iba vlákno CRM v danej schránke, crm@ sa nečíta; beh na pozadí iba `threads.get` sledovaného vlákna, používateľ iba známu správu vo vlákne, ktoré vidí. Každé povolené čítanie → `mailbox_access_log` (nemení sa ani nemaže, ani vlastník; vidí admin). `email_watch_threads`, `email_message_received` (raz podľa ID; predĺži sledovanie, upozornenie `ponuka_odpoved`), `email_thread_checked` (3 chyby schránky → `gmail_chyba` adminom raz; zmazané vlákno sa prestane sledovať).
- **Fronta:** potvrdenie akceptácie po uložení PDF potvrdenia (`email_confirmation_queue`): so zapnutým Gmailom zo schránky obchodníka do vlákna ponuky, inak z crm@ s Reply-To; zrušená akceptácia sa neodošle; `email_queue_claim`. Interné e-maily z crm@ (`email_outbox` podľa upozornení `schvalenie_nove`, `schvalenie_rozhodnutie`, `ponuka_akceptovana`): `email_outbox_claim`, `email_outbox_result`.
- **Pripomienka platnosti** v nočnom behu obchodov (`deal_daily_run_at`): ponuka bez FIX / kombinácie / cenníka so SPOT alebo VIWA, od 2. pracovného dňa pred koncom platnosti, raz; koncept v schránke obchodníka + upozornenie `ponuka_pripomienka`.
- Testy séria E (E0–E8, `checks_emaily.sql`), mutácie: čítanie na pozadí, idempotencia kľúča, neisté odoslanie, zámok ponuky, denník, pripomienka pri FIX, zhrnutie, kľúč pri zápise ID – všetky zachytené. `down` vráti schému zhodnú s 0041.
- Poznámka pre kód: kód nahrádza «odkaz na ponuku» a «podpis» až pri odoslaní (token odkazu sa neukladá); z uložených odpovedí zákazníka treba odkaz s tokenom odstrániť (citovaný pôvodný e-mail).

### 29.1 `0043_emaily_doplnky` (Peter 16. 10., body 1–4; `0042` už bola na `dev`)

1. **Čítanie Gmailu** – zoznam povolených operácií je v databáze (`gmail_read_authorize`), nie iba v kóde: iba `threads.get` (beh na pozadí, sledované vlákno) a `messages.get` (používateľ, známa správa vo viditeľnom vlákne), formát iba `minimal` / `metadata` / `full`. `attachments.get` a `raw` sú zakázané funkciou aj obmedzením stĺpcov denníka (`method`, nový `format`). `gmail.ts` posiela iba tieto hodnoty. Test E4 (attachments.get, raw), mutácie zachytené dvakrát (funkcia aj obmedzenie). Prílohy z odpovedí sa ukladajú iba ako zoznam (názov, typ, veľkosť).
2. Pripomienka nie pri FIX / kombinácii / cenníku – súhlas (bez zmeny).
3. Adresát potvrdenia: posledný adresát e-mailu s ponukou, inak kontaktná osoba, inak sa neposiela – súhlas (bez zmeny).
4. **Ručná akceptácia:** `offer_acceptance.send_confirmation` (predvolene `true`); `offer_acceptance_confirmation_off(id)` volá kód pri vypnutej voľbe pred uložením PDF potvrdenia (iba ručná, do 10 minút, kto smie upravovať ponuku); zapíše `potvrdenie_neodoslane` do časovej osi; `email_confirmation_queue` potvrdenie nezaradí. Test E7.

## 30. F4 – krok 2: API, beh na pozadí a obrazovky (16. 10. 2026)

- **Gmail (`api/src/gmail/`):** `endpoints.ts` – jediné miesto adries Gmail API (čítanie iba `threads.get` / `messages.get` vo formáte minimal / metadata / full, odoslanie `messages.send`); `gmail.ts` – token servisného účtu (`jose`, RS256) zvlášť pre schránku a oprávnenie (`gmail.send` / `gmail.readonly`), `gmailSend` (na Teste iba @greenlogy.com a `MAIL_ALLOWLIST`), **`gmailRead` – jediné čítanie**, pred ním `gmail_read_authorize` (denník); `mime.ts` – skladanie správy (text + HTML, fotka podpisu `cid:`, PDF, bez sledovacích prvkov, hlavičky bez vloženia ďalších) a spracovanie prijatej správy; `deliver.ts` – odoslanie v potvrdených krokoch (odosiela sa → Gmail → ID → dokončenie). Kontrola `api/scripts/check-gmail.mjs` (v `npm run typecheck`): adresa Gmailu iba v `endpoints.ts`, volanie iba v `gmail.ts`, nikde list, search, history, attachments, watch ani `raw`.
- **Prijatá správa (Peter 16. 10.):** z formátu `full` sa časti s prílohami – názov súboru, `attachmentId`, `Content-Disposition: attachment`, `inline` s názvom, `Content-ID`, iný typ než text – preskočia **bez dekódovania**; ukladá sa iba text (text/plain, inak text z HTML bez skriptov, štýlov a obrázkov) a hlavičky vlákna (odosielateľ, adresáti, predmet, Message-ID, čas). Odkaz na stránku ponuky s tokenom sa z citovaného textu nahradí „[odkaz na ponuku]“. Testy `api/test/gmail.test.ts` (`npm test`, 11 testov; neplatné base64 v prílohách dokazuje, že sa obsah ani nečíta; mutácie pravidiel zachytené).
- **Beh na pozadí** (`email-jobs.ts`, Cron `*/5 * * * *`): `email_pending_recover` → fronta potvrdení akceptácie (`email_queue_claim` → `deliver`) → interné e-maily z crm@ (`email_outbox_claim`, odkaz do CRM `CRM_URL`) → sledované vlákna (`threads.get`, `full`) → `email_message_received`, `email_thread_checked`. Do logu iba počty.
- **API (`routes/emails.ts`):** predvyplnenie k ponuke a voľného e-mailu, koncepty, odoslanie (PDF a odkaz sa pripravia pred „odosiela sa“, k ponuke sa zapíšu až po odoslaní; `send_key` z prehliadača – dvojklik neodošle znova), návrat po chybe, e-maily obchodu / firmy / kontaktu, profil a fotka (štvorec 64–1024 px, do 300 kB), šablóny e-mailov, overenie Gmailu (iba vydanie tokenu – schránka sa nečíta), denník čítania. Ručná akceptácia: `send_confirmation`. Používatelia: `gmail_enabled`. Kontakt: `salutation`.
- **Obrazovky:** 37 Nový e-mail (z ponuky „Odoslať e-mailom“, voľný e-mail z karty obchodu / firmy / kontaktu, koncept pripomienky jedným klikom), karta „E-maily a odpovede“ na obchode, firme a kontakte, Môj profil (`/profil`; admin `/profil/:id`), Nastavenia → Šablóny e-mailov (admin a Marketing) a Čítanie schránok, Používatelia → Gmail (pilot) a overenie, oslovenie pri kontakte, voľba potvrdenia pri ručnej akceptácii. „Odoslané mimo CRM“ ostáva pre ponuky odovzdané inak.
- Lokálne overené s `ENVIRONMENT=lokal`, `GMAIL_FAKE=1` (bez Google): odoslanie ponuky (stav Odoslaná, kanál crm, PDF, odkaz, platnosť), opakovanie s rovnakým kľúčom (bez druhého odoslania), potvrdenie akceptácie do vlákna ponuky, interný e-mail z crm@, čítanie vlákna v denníku, blokovanie adresy mimo zoznamu na Teste, fotka.

## 31. F4 po teste – `0044_emaily_podpis_oslovenie` (Peter 16. 10., body 1–3)

- **Oslovenie:** `contact.address_form` (pan / pani / NULL = neuvádzať), `email_salutation(kontakt, jazyk)` → „Dobrý deň, pán Mráz“ / „Dear Mr Mráz“, bez titulu; `contact.salutation` je vlastné oslovenie s prednosťou. Príčina chyby z testu: pole oslovenia obsahovalo „Pán“ a vkladalo sa doslova. Migrácia prevedie „Pán“ / „Pani“ na voľbu.
- **Vlastný podpis:** `user_signature` (režim profil / vlastný, vyčistené HTML do 100 kB, textová verzia; audit) a `user_signature_image` (najviac 5, PNG / JPEG / GIF do 300 kB, `cid:sig1`–`sig5`). Zápis iba `user_signature_set` (sám alebo admin; každý `cid:` v HTML musí mať obrázok). Databáza ako druhá vrstva odmietne skripty, rámce, formuláre, štýly, `on…=`, `javascript:` / `data:`, `url(` a obrázky mimo `cid:`. `email_signature` vracia `mode`, `custom_html`, `custom_text`; obrázky pre kód `user_signature_images_get`. Čistenie HTML a stiahnutie obrázkov urobí kód pri uložení.
- **Kontrola odpovedí:** `email_watch_threads` – vlákna s aktivitou za 2 dni pri každom behu (Cron každú minútu), staršie raz za 15 minút.
- Testy E9 (oslovenie, podpis, frekvencia), mutácie zachytené; `down` vráti schému z `dev` (0043).
- **Kód:** `api/src/gmail/signature.ts` – čistenie vloženého podpisu (povolené značky, atribúty a štýly, odkazy https / mailto / tel, obsah skriptov / štýlov / rámcov / formulárov sa zahodí, obrázky → `cid:sig1–5`, text, ktorý by vyzeral ako nebezpečný zápis, sa zakóduje ako entita); test overuje, že výsledok vždy prejde obmedzením v databáze. `PUT /profiles/:id/signature` stiahne obrázky (https do 300 kB, typ podľa hlavičky súboru; nedostupný obrázok sa vynechá) a uloží cez `user_signature_set`. Odosielanie: vlastný podpis s vloženými obrázkami namiesto podpisu z profilu. **Okamžité odoslanie:** `emailKick` (fronta + interné e-maily) po každom úspešnom zápise v CRM a z `crm-ponuka` po akceptácii cez service binding (`EmailKick.kick()`, bez verejnej adresy); Cron `* * * * *` ako poistka a na odpovede. Kontakt: voľba „Oslovujeme“ (pán / pani / neuvádzať) a vlastné oslovenie.

## 32. Plán F5 – zmluvy k obchodom (na schválenie, 16. 10. 2026)

Podľa zadania 9 a 10, návrhu časti 2 a obrazoviek 38, 40 (úprava 25, 26). Dva kroky, každý: migrácia nanečisto → `dev` → API a obrazovky → Test.

### 32.1 Krok 1 – `0045_zmluvy_k_obchodom`: podklady pre zmluvu a párovanie importu

- **Nové polia:** firma – fakturačné e-maily (zoznam), sociálny podnik, názov pre zmluvu „v zastúpení“ (IBAN = existujúci `bank_account`, platca DPH = `vat_payer`); OOM – vzťah k nehnuteľnosti (číselník podľa Office portálu), IMS (áno / nie) (predchádzajúci dodávateľ, obdobie fakturácie a typ výkupnej zmluvy už sú); `deal_contract_input` (typ zmluvy, autoprolongácia, produktová rada, obdobie fakturácie, pri výkupe typ výkupnej zmluvy a model výpočtu, zástupca pre zmluvné vzťahy = kontakt).
- **`deal_contract_input_save`** – uloží údaje k firme, kontaktu, OOM a obchodu naraz; smie obchodník obchodu, Servis (domácnosti) a Nákup (výkup), admin. **`deal_contract_input_view`** – podklady v poradí formulára Office portálu, rozdelené na zmluvu NN a VN (OOM, ceny po rokoch, názvy produktov Office portálu, výnimka), so zoznamom chýbajúcich polí („12 / 14“).
- **Párovanie** (`contract_deal_match`, volá ho uloženie importu): `contract` 1 obchod : n zmlúv (zrušenie `contract_deal_id_key`), `offer_variant_id`, `deal_match` (auto / ručne / bez obchodu, kto a kedy). Kandidát = obchod toho istého zákazníka a zodpovedajúceho druhu v Akceptácii alebo Vyjednávaní (alebo Vyhraté s ďalšou zmluvou VN), všetky EIC zmluvy sú v akceptovanom variante. Jednoznačná zhoda → spárovať, obchod pri prvej zmluve Vyhraté, časová os. Inak „Nespárované zmluvy“ + upozornenie; zmluva domácnosti bez otvoreného obchodu B2C → „Bez obchodu“ automaticky. Párujú sa iba zmluvy prvýkrát importované po dátume spustenia (nastavenie `deal_matching_from`).
- **Kontrola cien** → príznak `cena_ina_ako_v_ponuke` (rok, ponuka vs. zmluva) a upozornenie obchodníkovi a schvaľovateľom cien; uzatvára schvaľovateľ cien s poznámkou.
- **Výnimka z ponuky → zmluva:** schválená výnimka akceptovaného variantu (rok, model, napäťová skupina) sa zapíše ako Použitá k zmluve a prepočíta hranicu zmluvy (`contract_year_basis`); párovanie výnimiek modulu 4 (30 dní) sa pre spárované zmluvy nepoužije.
- **Ručne:** vybrať obchod, „Bez obchodu“ (obchodník zákazníka alebo admin), zrušiť spárovanie (admin s dôvodom – obchod späť do Akceptácie, ak nemá inú zmluvu).
- Obrazovky: 38 Podklady pre zmluvu (záložka obchodu, „Kopírovať“ pri poli, „Kopírovať všetko“, chýbajúce polia na doplnenie priamo v podkladoch), 40 Zmluvy k obchodom (Čaká na zmluvu, Nespárované, Cena iná ako v ponuke), 25 / 26 príznaky a filter „Bez obchodu“, odkaz zmluva ↔ obchod.

### 32.2 Krok 2 – `0046_obnova_nocny_beh`

- Nočný beh zmlúv (krok 4 mesiace pred koncom) založí obchod **Obnova** podľa časti 2.3 (iba firmy; ak existuje bežný otvorený obchod s OOM zmluvy, iba mu doplní predošlú zmluvu); upozornenie `obnova` nahradí `konci_4_mesiace` pre obchodníka.
- Nočný beh obchodov: **14 dní po akceptácii** upozornenie `chyba_oom_na_zmluve` raz, ak niektoré OOM akceptovaného variantu nie je na zmluve obchodu.
- Lehota 14 dní a stav podkladov v prehľade „Čaká na zmluvu“.

## 33. F5 – krok 1: `0045_zmluvy_k_obchodom` (overená nanečisto 16. 10. 2026)

- **Číselníky:** `vztah_k_nehnutelnosti` (6 hodnôt podľa formulára Office portálu), `model_vypoctu_vykupu` („ISOT SK – Základný výpočet (zápor. ceny)“); `typ_vykupnej_zmluvy` už existoval. Predchádzajúci dodávateľ je číselník `predchadzajuci_dodavatel` (modul 2).
- **Podklady:** firma `billing_emails`, `social_enterprise`, `contract_name`; OOM `property_relation`, `has_ims`; `deal_contract_input` (typ zmluvy, autoprolongácia, produktová rada, obdobie fakturácie, typ výkupnej zmluvy, model výpočtu, zástupca). `deal_contract_input_save` (obchodník obchodu, Servis, Nákup, admin – `crm_contract_input_editor`; IBAN s kontrolnou číslicou `iban_ok`), `deal_contract_input_view` (zmluvy podľa napäťovej skupiny pri dodávke firme, OOM, ceny akceptovaného variantu po rokoch, výnimky, zástupca, kontakty na výber), `deal_contract_input_missing` (vyplnené / spolu, zoznam chýbajúcich).
- **Párovanie:** `contract` 1 obchod : n zmlúv, `offer_variant_id`, `deal_match` (caka / auto / rucne / bez_obchodu; NULL = mimo párovania), kto a kedy, poznámka, `deal_match_notified_at`. Nové zmluvy z importu dostanú „caka“ iba pri zapnutom `deal_matching` (trigger podľa `app.contract_import_id`). `contract_import_run` po uložení zavolá `contract_deal_match_pending`. Kandidáti (`contract_deal_candidates`): Akceptácia – EIC v akceptovanom variante; Vyjednávanie – EIC na obchode; Vyhraté – s akceptovaným variantom, už má spárovanú zmluvu a OOM nie sú na inej jeho zmluve. Jeden vyhovujúci → `contract_deal_link` (odkaz, variant iba mimo Vyjednávania, obchod Vyhraté, časová os `zmluva_sparovana` s „spárované bez akceptovanej ponuky“, kontrola cien, výnimky). Domácnosť bez otvoreného obchodu B2C → Bez obchodu. Inak „caka“ + upozornenie `nesparovana_zmluva` raz.
- **Cena iná ako v ponuke:** `contract_offer_price_check` – pre OOM × rok komodita zmluvy vs. akceptovaný variant (model, FIX VT/NT, aditív €, %); príznak s rokom a textom „EIC: ponuka …, zmluva …“; upozornenie `cena_ina_ako_v_ponuke` obchodníkovi a schvaľovateľom cien; uzatvára schvaľovateľ s poznámkou (guard aj RLS úpravy príznaku).
- **Výnimka z ponuky → zmluva:** `contract_offer_exceptions` – schválené položky výnimky akceptovaného variantu (rok, model, napäťová skupina zmluvy) ako `price_exception` Použitá s `approval_request_id` (hranica zo schválenia, bez upozornenia „nová žiadosť“); výnimky modulu 4 pri tejto zmluve sa uvoľnia a `contract_basis_refresh` ich pre spárované zmluvy nepoužije.
- **Ručne:** `contract_deal_pick` / `contract_deal_none` (vlastník zákazníka alebo admin), `contract_deal_unlink` (admin s dôvodom – zmluva späť medzi nespárované; obchod s ďalšou spárovanou zmluvou ostáva Vyhraté, pri poslednej zmluve sa vráti do štádia, z ktorého bol spárovaný: Akceptácia, ak mala zmluva akceptovaný variant, inak Vyjednávanie – Peter 16. 10.; výnimky z ponuky a príznaky ceny sa zrušia, časová os `zmluva_odparovana` so štádiom). `contract_unmatched` – zoznam Nespárované pre toho, kto zmluvu vidí alebo o nej rozhoduje.
- Testy séria F (`checks_zmluvy_obchody.sql`, F0–F7), mutácie zachytené (Vyjednávanie, kontrola cien, nastavenie, domácnosť, upozornenie raz, výnimka modulu 4, práva). `down` vráti schému z `dev` okrem hodnoty enumu `cena_ina_ako_v_ponuke` (PostgreSQL ju neodstráni; nepoužíva sa).
- **Úloha pre F7 (provízie):** čo sa stane s províziou, ak admin zruší spárovanie zmluvy s obchodom po jej vzniku – zvlášť pre **čakajúcu** a pre **uplatnenú** províziu (zrušiť, prepočítať, ponechať a vyrovnať v ďalšom liste?). Rozhodne Peter pri pláne F7.

## 34. F5 – krok 1: API a obrazovky (lokálne overené 16. 10. 2026)

- **API (`api/src/routes/contract-deals.ts`):** `GET/PUT /deals/:id/contract-input` (podklady + možnosti číselníkov), `GET /contract-matching` (Čaká na zmluvu: obchody v Akceptácii s očakávanými zmluvami NN / VN, spárovanými, chýbajúcimi EIC, lehotou 14 dní a stavom podkladov; Nespárované s kandidátmi; Cena iná ako v ponuke), `POST /contracts/:id/deal | no-deal | unlink`. Zoznam zmlúv: tlačidlá „Cena iná ako v ponuke“, „Nespárovaná s obchodom“, „Bez obchodu“ a obchod v riadku; karta zmluvy: obchod, ponuka a variant, spôsob a čas spárovania, kandidáti a rozhodnutia.
- **Obrazovky:** 38 `/obchody/:id/podklady` (záložky zmlúv NN / VN, sekcie v poradí Office portálu s „Kopírovať“, chýbajúce polia zvýraznené, „Kopírovať všetko“, „Doplniť údaje“ v paneli, stav podkladov), 40 `/zmluvy-k-obchodom` (menu), karta zmluvy – karta „Obchod“, „Cena iná ako v ponuke“ uzatvára schvaľovateľ s poznámkou. Na obchode v Akceptácii / Vyhraté tlačidlo „Podklady pre zmluvu“.
- Lokálne overené: párovanie po simulovanom importe (automaticky, príznak ceny), nespárovaná zmluva s kandidátmi, uloženie podkladov (zlý IBAN odmietnutý), zrušenie spárovania, výber obchodu, „Bez obchodu“, filtre zoznamu.

## 35. F5 – krok 2: `0046_obnova_nocny_beh` (overená nanečisto 16. 10. 2026)

- **`contract_renewal(zmluva)`** (volá krok 5 nočného behu zmlúv – zmluvy firiem a výkupu 4 mesiace pred koncom): ak je otvorená Obnova k zmluve, nič; ak existuje bežný otvorený obchod rovnakého druhu s niektorým OOM zmluvy, iba mu doplní predošlú zmluvu (časová os `predosla_zmluva` „predošlá zmluva doplnená nočným behom“); inak založí obchod „Obnova – {číslo}“ (pipeline podľa typu zmluvy, Príležitosť, zdroj Obnova, predošlá zmluva, očakávané uzavretie = koniec − 1 mesiac, začiatok dodávky = deň po konci, vlastník = obchodník zmluvy, inak vlastník zákazníka), OOM zmluvy Aktívne / Pripravované s objemami zo zmluvy (výkup a VIWA plán výkupu a výkon; OOM v inom otvorenom obchode sa preskočí), kontakty z predošlého obchodu, inak hlavný kontakt firmy. Bez aktívneho obchodníka aj vlastníka zákazníka sa nezaloží – upozornenie `obnova` adminom.
- Obchodník dostane namiesto `konci_4_mesiace` jedno upozornenie **`obnova`** s odkazom na obchod (raz na koniec zmluvy). Log nočného behu: počet založených obnov.
- **Nočný beh obchodov:** pri zapnutom `deal_matching` obchod v Akceptácii / Vyhraté, ktorého akceptovaný variant má OOM bez zmluvy obchodu aj 14 dní po akceptácii → upozornenie **`chyba_oom_na_zmluve`** obchodníkovi raz.
- Testy F8, F9; test modulu 4 Z4-1 upravený (pri firme Obnova namiesto „Končí do 4 mesiacov“). Mutácie zachytené; `down` vráti schému z `dev` (0045).

## 36. Plán F6 – Domov obchodníka a prehľady (schválený 16. 10. 2026)

Podľa zadania 11, 13, návrhu časti 7 a obrazoviek 30, 32. Dva kroky, každý: migrácia nanečisto → `dev` → API a obrazovky → Test.

### 36.1 Krok 1 – ceny z Workera Montel (`0047_ceny_spot`)

- **Spojenie:** service binding na Worker `greenlogy-montel-auth` (rovnaký účet Cloudflare), kľúč `MONTEL_API_KEY` iba cez `wrangler secret`. Iba GET `/forwards/quotes`, `/forwards/ohlc/history`, `/spot/aggregates` – zoznam povolených ciest v jednej funkcii (`api/src/montel.ts`) s testom a kontrolou v `npm run typecheck`, ako pri Gmaile.
- **Denný beh** (Cron po pracovných dňoch 7:00 a 13:00 Europe/Bratislava): BL a PL (base / peak) rokov 2027–2030 → `market_price_daily` so zdrojom `cockpit` (ručná hodnota dňa sa neprepíše); `spotAvg365` → nová tabuľka `spot_average_daily (org_id, on_date, avg_12m_eur_mwh, source)`. Do denníka nočných behov (`job_run`, obrazovka Nastavenia → Nočný beh).
- **História od 1. 1. 2026:** jednorazovo tlačidlom v Nastaveniach → Cenové parametre („Načítať históriu z Montelu“, admin) cez `/forwards/ohlc/history` (settlement BL/PL po dňoch, zdroj `historia`; existujúce hodnoty dňa sa neprepíšu). Ručné zadávanie cien (obrazovka 29) ostáva ako záloha.

**Hotové (16. 10., Peter otestoval na Teste):**

- `0047_ceny_spot`: `spot_average_daily` (RLS: admin a kto vidí maržu, aplikácia nezapisuje); `market_price_import` (interná – iba BL / PL s oboma hodnotami, ručne zadaná BL / PL dňa sa neprepíše, zhodná hodnota sa nezapíše znova, odhad portfólia a SPOT pre FVE z platného záznamu dňa sa prenesú); `market_price_daily_run` (iba beh na pozadí, `job_run` job `ceny`, chyby Montelu ako `{krok: 'montel', kod, text}` a upozornenie adminom); `market_price_history_import` (iba admin, dni 1. 1. 2026 – dnes, dni s cenou sa nemenia); `spot_average_on` (SPOT priemer pre Domov, posledný najviac 7 dní starý, vidí každý prihlásený). Strážca `market_price_guard` prijme zápis importu iba z funkcie vlastníka – nový spúšťač `trg_flag_check` (bez SECURITY DEFINER) odmietne príznaky `crm.market_price_import` / `crm.market_price_correction` nastavené aplikáciou.
- `0048_ceny_rucne_zmazanie`: `market_price_daily.removed_reason`, `market_price_manual_remove(id, dôvod)` – iba admin, iba platná ručná cena; riadok sa označí ako opravený (kto, kedy, dôvod), ostane v histórii a audite; ďalší beh deň načíta z Montelu.
- História: settlement obchodného dňa T = cena dňa T + 1 (ako denný beh ráno; Peter 16. 10.).
- Kód: `api/src/montel.ts` (`MONTEL_PATHS`, `montelGet` – jediné volanie GET s `X-API-Key`, chyba iba s kódom; výber hodnôt `extractQuotes`, `extractSpotAvg`, `extractHistory`), `montel-fake.ts` (lokálne `MONTEL_FAKE=1`), `schedule.ts` (Cron `0 5,6,11,12 * * 1-5`, `isPriceSlot` = po – pi 7:00 a 13:00 Bratislava), `jobs.ts` `pricesRun`, `routes/pricing.ts` (zdroj a história, `POST /pricing/market-prices/:id/remove`, `POST /pricing/market-history`), kontrola `scripts/check-montel.mjs`, testy `test/montel.test.ts`.
- Testy DB séria S0–S6 (`checks_ceny_spot.sql`), mutácie zachytené; `down` 0047 aj 0048 vráti schému 0046.

### 36.2 Krok 2 – Domov a prehľady (`0049_domov_prehlady`; číslo 0048 použila oprava ručnej ceny v kroku 1)

- **Domov (obrazovka 30, nová úvodná stránka):** dlaždice ceny pre obchodníka FIX na 3 nasledujúce roky (`trader_price` k dnešku, „stav k … · settlement z …“; cez víkend a sviatky posledná hodnota s poznámkou), priemerná SPOT za 12 mesiacov, minimálny aditív podľa typu predajcu; **graf** vývoja ceny pre obchodníka po rokoch od 1. 1. 2026; **kalkulačka** (FIX / SPOT, rok, objem, moja cena / aditív → pridaná hodnota a odhad provízie s mojím percentom, „Vytvoriť obchod s touto cenou“); **overenie firmy**; **moje ďalšie kroky** (po termíne, dnes, zajtra); **moje ponuky** (čakajú na schválenie, odoslané / otvorené, vyprší dnes, akceptované čakajú na zmluvu, PH otvorených a vážená).
- **Žiadosť o pomoc s ponukou** (externí obchodníci): tlačidlo na obchode → upozornenie obchodnému riaditeľovi s odkazom na obchod a poznámkou.
- **Pridaná hodnota obchodu v prehľadoch:** akceptovaný variant, inak najvyšší variant poslednej platnej ponuky, inak odhad PH na obchode (dnes sa používa iba odhad). Kanban a zoznam (32): súčty PH a vážená PH podľa pravdepodobnosti štádia, stĺpec „Uzavreté v mesiaci“ (Vyhraté / Prehraté).
- **Pre manažéra:** rozpad podľa obchodníkov (počet otvorených, PH, vážená PH, vyhraté v mesiaci, bez kroku / po termíne).
- **Zoznamy:** Bez ďalšieho kroku / po termíne (filter Obchodov už je), Čaká na schválenie (Schvaľovanie), Čaká na zmluvu a Nespárované (Zmluvy k obchodom) – odkazy z Domova.

### 36.3 Otázky

1. **Kľúč a spojenie:** pošlete mi (nie do chatu) cez `wrangler secret put MONTEL_API_KEY` pre `crm-core`; service binding na `greenlogy-montel-auth` pridám do `wrangler.toml`. Súhlas?
2. **Žiadosť o pomoc:** komu – všetkým so „schvaľuje ceny“ (obchodný riaditeľ)? Iba zvonček, alebo aj e-mail z crm@ (nahrádza mailto zo Sales portálu – **odporúčam aj e-mail**)?
3. **Pridaná hodnota obchodu** v súčtoch podľa 36.2 (akceptovaný variant → najvyšší variant poslednej ponuky → odhad). Súhlas, alebo radšej priemer variantov?
4. **Kalkulačka SPOT:** pridaná hodnota = (môj aditív − minimálny aditív podľa typu predajcu) × objem. Súhlas?
5. **Domov ako úvodná stránka** po prihlásení pre všetkých (dnes je to Zákazníci), alebo iba pre obchodníkov?

**Odpovede (Peter, 16. 10.):**

1. Áno, service binding, iba tri adresy s testom, kľúč zadá Peter. Obchodníci (aj externí) vidia na Domove, v grafe aj v kalkulačke **iba cenu pre obchodníka**, nikdy surové BL a PL (z nich a zo vzorca by sa dala dopočítať riziková prirážka a marža). Surové BL, PL a históriu z Montelu vidí iba „vidieť maržu firmy“ a admin. Do CRM iba potrebné hodnoty. Overiť testom API aj práv v DB. Doplnky: Cron 7:00 a 13:00 Bratislava v letnom aj zimnom čase s testom; zdroj ceny pri každom dni, zmazanie ručnej ceny adminom s dôvodom. SPOT priemer na Domove pre obchodníkov áno; surové BL / PL pre Nákup a Marketing v poriadku (modul 4).
2. Žiadosť o pomoc s ponukou: tímu **Sales_internal** (zvonček + e-mail z crm@), nie všetkým so „schvaľuje ceny“.
3. PH v súčtoch: **akceptovaný variant; inak hlavný variant poslednej odoslanej ponuky** (predvolene prvý, obchodník ho môže v ponuke označiť); inak odhad na obchode. Nie najvyšší variant.
4. Kalkulačka SPOT: (môj aditív − minimálny aditív podľa typu predajcu) × objem. Zápornú PH ukázať, provízia je vtedy 0 €.
5. Domov ako úvodná stránka pre rolu obchodník (interný aj externý) a tím Sales_internal; ostatní Zákazníci.

