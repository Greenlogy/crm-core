# Inventár HubSpotu – súhrn a návrh dátového modelu v0.3

Stav: NÁVRH na schválenie (10. 10. 2026), rozhodnutia zapracované. Podklady: `objekty-a-vlastnosti.md`, `pipelines.md`, `workflowy-a-sablony.md`, `make-scenare.md`.
Po schválení sa zmeny prenesú do `docs/01-datovy-model.md` ako verzia v0.3.

## 1. Čo v HubSpote máme

| Objekt | Záznamov | Vlastné vlastnosti (s dátami / spolu) | Poznámka |
| --- | --- | --- | --- |
| Firmy | 3 003 | 34 / 46 | väčšinou údaje z Finstatu |
| Kontakty | 8 506 | 78 / 117 | 69 % B2C (bez firmy) |
| Dealy | 15 601 | 111 / 121 | v skutočnosti obchod **aj zmluva** |
| Tickety | 61 723 | 20 / 21 | 92 % v pipeline „Office“ |
| OOM | 10 151 | 75 / 84 (z toho ~20 s dátami pod 1 %) | 4 pipelines = typ OOM, štádium = stav |
| Zmluvné ceny | 11 797 | 25 / 26 | cena pre OOM na obdobie |
| Nákupné ceny | 1 163 | 8 / 8 | veľkoobchodná nákupná cena k dealu, nie k OOM |
| Ponuky (quotes) | 2 436 | – | 18 šablón, 6 aktívnych |

Ďalej: 220 workflowov (170 aktívnych), 21 formulárov, 76 marketingových e-mailov, 0 sekvencií, 8 typov odberu (5 aktívnych), 30 aktívnych používateľov v 8 tímoch, 52 Make scenárov napojených na HubSpot (42 aktívnych).

## 2. Hlavné zistenia

### 2.1 Väzby (podľa počtov asociácií)

| Väzba | Skutočnosť | Dôsledok pre model |
| --- | --- | --- |
| OOM – firma | prepojené iba 2 z 10 151 OOM | Vlastník OOM sa dnes nikde priamo neeviduje. Pri migrácii ho treba odvodiť z dealu. |
| OOM – deal | 99,9 % OOM má deal (80 % jeden, 20 % 2–5) | `deal_oom` je kľúčová väzba |
| OOM – kontakt | 92 % OOM má kontakt | Vzniká Make scenárom „prepojenie kontaktov s OOM“ podľa dealov, teda podľa doménového pravidla. V jadre bude odvodená, nie uložená. |
| OOM – zmluvná cena | 90 % jedna, 10 % 2–5 | `contract_price.oom_id` povinné |
| Deal – zmluvná cena | 88 % zmluvných cien má práve 1 deal | `contract_price` patrí k zmluve (dealu) |
| Nákupná cena – deal | 28 % nákupných cien má deal, deal má najviac 3 | `purchase_price.deal_id`, nie `oom_id` |
| Deal – firma | iba 25 % dealov má firmu | zodpovedá B2C väčšine |
| Deal – kontakt | 97 % dealov má kontakt | |
| Kontakt – firma | 2 528 kontaktov má 1 firmu, **215 kontaktov 2–6 firiem** | Stĺpec `contact.company_id` nestačí, treba väzbu n:n. |
| Deal bez OOM | 8 449 dealov (54 %) | Takmer určite 7 370 dealov v štádiu „Notifikačný email“ pipeline Greenlogy_B2C_služby (pozri 2.3). |

**Labely asociácií nesú dáta.** Labely ako „Číslo Greenlogy zmluvy“ (11 618), „EIC“, „XML433Domacnosti_eic“ alebo „Subjekt“ vznikli ako pomôcka pri párovaní. V jadre ich nahradia cudzie kľúče a v migrácii sa ignorujú. Ostatné labely kontakt–firma (Owner, Manager, Billing Contact…) sa nepoužívajú.

**Párovanie cez text.** Objekty sa dnes prepájajú cez textové kódy: číslo zmluvy, EIC, „Párovací kód_Deal_Nákupné ceny“ a „Subjekt“ ako názov zákazníka v texte. Robí to 9 workflowov („Spárovanie X vs. Y cez HubSpot“) a niekoľko Make scenárov. V relačnom modeli tieto kroky odpadnú. Pri migrácii ich však použijeme ako zdroj väzieb tam, kde asociácia chýba.

### 2.2 OOM

- **Typ = pipeline:** Elektrina_výroba 3 604, Elektrina – spotreba 5 889, Elektrina – Sharing 645, Elektrina_veľkoobchod 13.
- **Stav = štádium pipeline:** Aktívne 8 814, Neaktívne 674, Odídené 631, Zrušené 31, **Prepísané 1**.
  - Vlastnosť `stav_oom` stav duplikuje a má navyše hodnotu „Veľkoobchod“.
  - `CLAUDE.md` pozná iba 4 stavy. „Prepísané“ treba buď doplniť, alebo pri migrácii zlúčiť.
- **Technické údaje, vyplnené takmer na 100 %:**
  - adresa (ulica, obec, PSČ),
  - PDS a identifikátor PDS (číslo OP), sadzba PDS, napäťová úroveň, typ merania, počet fáz, istič [A],
  - rezervovaná a maximálna rezervovaná kapacita [kW], spôsob rezervovania,
  - cenová regulácia, spotrebná daň, fakturačné obdobie, spôsob a výška záloh,
  - plánovaná spotreba VT a NT [MWh], plánovaný výkup [MWh], výkon zdroja [kW],
  - účinnosť OOM od/do.
- **Výroba:** druh zdroja (FVE, voda, bioplyn…), typ zdroja (Virtuálna batéria, Lokálny, Výrobný, Green VIWA), typ výkupnej zmluvy, výkon striedača a panelov (~2 750 OOM).
- **Dotazník zariadení:** striedač, batéria, tepelné čerpadlo, wallbox. Vyplnený iba pri desiatkach OOM, čo potvrdzuje tabuľku `oom_device` z v0.2.
- **Zmena dodávateľa:** výpoveď predošlému dodávateľovi (6 737) a dátum akceptácie výpovede (1 423).
- **Text namiesto väzieb:** `subjekt` je názov zákazníka ako text, `obchodnik` je meno obchodníka ako text, číslo zmluvy je text. V jadre sa nahradia väzbami.

### 2.3 Dealy = obchod + zmluva

HubSpot nemá objekt zmluvy, zmluvu reprezentuje deal:
- Číslo zmluvy (6 947), stav zmluvy (Potvrdený / Nepotvrdený / Ukončená), fáza zmluvy (7 hodnôt).
- Účinnosť od/do, trvanie (roky), splatnosť faktúr, flexibilita odberu, výška preddavku.
- Nákupná cena a nákupná tranža, hrubá marža a provízia.

**Štádiá kódujú rok zmluvy:** „Zmluvy_2024“ … „Zmluvy_2029“, „Zmluvy_neurčito“. Štádium tak nehovorí, kde je obchod, ale do kedy platí zmluva.

| Pipeline | Dealov | Poznámka |
| --- | --- | --- |
| B2C_elektrina | 4 108 | 3 797 v „Zmluvy_neurčito“, väčšina ostatných štádií je prázdna |
| B2B_elektrina | 2 558 | zmluvy 2024–2029, 386 neúspech |
| B2B_výkup elektriny | 1 363 | 693 v „Zmluvy_neurčito“ |
| **Greenlogy_B2C_služby** | 7 387 | **7 370 v štádiu „Notifikačný email“.** Nejde o obchody, ale o záznamy pre automatické e-maily: správy XML433/XML43D o zmene dodávateľa a poukážky GreenCar. |
| GreenSolar | 60 | inštalácie FVE: cena diela, DPH, záloha, provízia NEP |
| EFET_elektrina | 15 | veľkoobchod (EFET zmluvy) |
| Green VIWA_B2B | 109 | |

Ďalšie skupiny vlastností na dealoch:
- **Správy o zmene dodávateľa:** XML433 (domácnosti, spotreba) a XML43D (výroba, domácnosti aj organizácie): dátum správy, dátum platnosti, EIC, druh odberného miesta, typ merania, odoslanie e-mailu. Spolu ~5 700 dealov.
- **GreenCar poukážky:** kód, hodnota, dátum odoslania (1 815).
- **Odporúčania (Growthdrive):** referral discount, reward, stav (~960).
- **Marža a provízie:** viac ako 15 vypočítaných polí (hrubá marža, priemerná cena, výnos z fixov…) plus `commission_status_sales_portal` a `commission_pdf_url` zo Sales portálu.
- **Line items:** 2 607 dealov má položky. Produkty a line items sme zatiaľ neinventarizovali (pozri kapitolu 5).

### 2.4 Zmluvné ceny

Pre jedno OOM a jedno obdobie (účinnosť od/do; „neurčito“ = 31. 12. 2099) obsahujú:
- **Produkt:** 57 kódov, napr. `2025_GREENVYR_AK [EUR]`, `Green DD1`.
- **Ceny [EUR/MWh]:** VT/1T a NT (aditív), cena odchýlky, aditívny koeficient [%].
- **Mesačné poplatky [EUR/mesiac]:** za OOM, za ZEM, za VBattery.
- **Ostatné:** program VBattery (6 programov), typ (Odber / Dodávka), stav Platné / Neplatné.
- **Vypočítané:** objemy (rollup z OOM) a výnosy.

`trading_book = „V bloku“` je vyplnené pri 241 cenách. Ide o príznak, samotný trading book sa nemigruje.

### 2.5 Nákupné ceny

Nejde o nákupné ceny výroby pri OOM, ako predpokladal model v0.2. Je to **veľkoobchodná nákupná cena elektriny k dealu**:
- cena PXE BL a PL, dátum nákupu, produkt nákupu (`SK BL CAL2026`…), obdobie (2025–2030),
- vypočítaná „Cena_obchod“ a párovací kód na deal.

Workflow „Close date = dátum nákupnej ceny“ nastavuje dátum uzavretia dealu podľa dátumu nákupu.

### 2.6 Kontakty a firmy

- **Typ kontaktu:** Domácnosť, Firma, Komunal, Výrobca, Externý partner_sales, Externý partner_služby. Externí obchodní partneri sú teda tiež kontakty.
- **Ponuky uložené na kontakte:** 1 426 kontaktov má polia `gp_*` (cena 1–3, spotreba VT/NT, VBattery, platnosť, číslo ponuky). Patria do tabuliek `offer` a `offer_item`.
- **Marketingové cesty:** polia „GRN … Engine“ zaznamenávajú kroky zákazníckej cesty (navštívil stránku → ebook → ponuka → zmluva → onboarding). Nastavuje ich 50 workflowov „GRN / …“. Patrí to do PostHogu a Brevo, nie do stĺpcov CRM.
- **Firmy z Finstatu:** IČO (uložené ako **číslo**, čo stratí úvodné nuly), DIČ, IČ DPH, zápis v OR, NACE, dlhy a nedoplatky, konkurzy, platobný rating, štatutár, bankový účet.
- **Spotreba na firme** (plánovaná, skutočná VT/NT) duplikuje údaje z OOM.
- **Súbory na kontaktoch:** prílohy, faktúry, **životopisy (10)**. Životopisy do CRM nepatria (GDPR).

### 2.7 Tickety

- **Objem:** 61 723 ticketov, z toho 56 513 v pipeline „Office“ a 5 207 v pipelines „NEPOUZIVAT“ (TWL a GR).
- **EIC ako text:** 26 259 ticketov má vyplnený EIC, ale s OOM sú prepojené iba 2. Pri migrácii ich treba spárovať cez EIC.
- **Štandardy kvality** (1 129): regulačné štandardy kvality (overenie vyúčtovania, odstránenie nedostatkov…), dôležité pre servisný modul.
- **Ďalšie polia:** produkt, segment, hodnotenie ticketu.
- **Podozrivý kontakt:** jeden kontakt má 500 a viac ticketov, pravdepodobne systémová adresa. Pri migrácii ho treba preveriť.

### 2.8 Automatizácia (workflowy a Make)

| Skupina | Počet aktívnych | Kam v novom systéme |
| --- | --- | --- |
| Marketingové cesty „GRN / …“ | 50 | PostHog + Brevo |
| Deal: „Pipeline is X, deal stage is Y“ | 39 | Prechody štádií. Mnohé odkazujú na štádiá, ktoré už neexistujú (Finálne podpísaná, Čaká na podpis), pravdepodobne nastavujú „Fáza zmluvy“. Pri návrhu pipelines v jadre prejdeme jednotlivo. |
| Párovanie objektov a kódy na párovanie | 12 | Odpadá, väzby nahradia cudzie kľúče. |
| Dopĺňanie dát (subjekt, 31. 12. 2099, výkon zdroja, LZ/VZ) | 8 | Odpadá alebo validácia v jadre. |
| Marža a provízie | 7 | Výpočty v jadre (`commission_rule`) |
| Automatické e-maily (XML433/43D, GreenCar, VBattery ponuka, follow-upy, prieskumy) | 15 | Jadro (udalosti) + Brevo |
| Životný cyklus kontaktu (MQL, SQL, legal basis, súhlasy) | 8 | Jadro + `consent` |
| Tickety (zmena stavu, znovuotvorenie) | 10 | Chatwoot |
| Forecast mapping | 5 | Odpadá |

Make: Sales portál zapisuje do HubSpotu cez 8 scenárov, FINSTAT cron beží každé 3 minúty a prichádzajú sem správy o zmene dodávateľa (XML433/43D). Všetko toto sa presmeruje na API jadra (detail v `make-scenare.md`).

### 2.9 Používatelia a súhlasy

- **Používatelia:** 30 aktívnych, nie 14 ako vo v0.2.
- **Roly:** Super Admin, Sales_external, OfficeZA, OfficeZA_Frontoffice.
- **Tímy:** Sales_external (11), OfficeZA (7), Supplier_external (3)…
- **Prístup externých obchodníkov:** externí obchodníci a dodávatelia potrebujú obmedzený prístup iba k svojim záznamom.
- **Typy odberu:** 5 aktívnych, z toho 2 interné (individuálna komunikácia, zákaznícke služby).
- **Marketingové kontakty:** 8 293 (97,5 %), úplne odhlásených 59.

### 2.10 Produkty, line items a výpočet marže

**Produkty:** v HubSpote je 41 produktov a 8 464 line items. Prakticky sa používa iba 10 z nich:

| Produkt | Cena | Line items |
| --- | --- | --- |
| Green_E_1T_FIX | 189 €/MWh | 1 868 |
| Výkup_INDEX_SPOT | 30 | 1 328 |
| Green_E_1T_SPOT+ aditív | 30 | 841 |
| Green_E_2T/NT_FIX a Green_E_2T/VT_FIX | 189 | 637 + 634 |
| Green_E_OM | 3 €/mesiac | 208 |
| Výkup FIX_base | 180 | 105 |
| Green VIWA Pro, Plus, Basic | 9,9 / 6,9 / 3,9 €/mesiac | 93 / 61 / 15 |
| Výkup_FIX_peak | 200 | 35 |
| Green_E_1T_FIX_2026 – 2029 | 120 / 128 / 122 / 115 | 33 / 24 / 10 / 6 |

Produkty „Green DD1 – DD8“ a VBattery nemajú takmer žiadne line items.

**Dva katalógy produktov:** HubSpot produkty (41) a zoznam produktov v zmluvných cenách (57 kódov, napr. `2025_GREENVYR_AK [EUR]`) sú dva rôzne katalógy. V jadre budú jeden katalóg (`product`) s mapovaním oboch.

**Dva paralelné výpočty marže** (vzorce sú v `objekty-a-vlastnosti.md`, časť „Vypočítané vlastnosti“):

1. **Podľa OOM a zmluvných cien (`new_hruba_marza`, 6 493 dealov):**
   - Zmluvná cena, výnos z elektriny = cena VT × objem VT + cena NT × objem NT + cena VT × objem výkupu + cena odchýlky × objem výkupu. Objemy sú rollupy z plánovanej spotreby a výkupu OOM.
   - Zmluvná cena, výnos z fixov = (poplatok za OM + ZEM + VBattery) × 12.
   - Deal, výnos = Σ výnos z elektriny + Σ výnos z fixov + poplatok Green VIWA za RK × 12 × výkon zdrojov.
   - Deal, **hrubá marža = výnos − nákupná cena × objem spotreby − nákupná cena × objem výkupu**.
   - Priemerná marža na MWh = hrubá marža / objem spotreby.
2. **Podľa line items (`hruba_marza`, ~2 070 dealov):** súčet line items − nákupná cena × objem z line items. Ide o starší spôsob.

**Ostatné výpočty:**
- **Provízia zo Sales portálu:** základ = výnos z elektriny − nákupná cena × objem spotreby (bez fixov a výkupu).
- **Provízia GreenSolar:**
  - cena diela bez DPH = cena s DPH / DPH,
  - základ = cena bez DPH − dodatočná provízia,
  - celková provízia = základ × % + dodatočná provízia,
  - čistá provízia Greenlogy = polovica, ak je obchodník NEP, inak celá + doúčtovanie z NEP.
- **Nákupná cena (`cena_obchod`):** `cena × 800 + cena_pxe_pl × 200 / 1000 + 4 + 4` pre PXE2027, inak pomer 700/300. Kvôli prednosti operátorov sa tu pravdepodobne počíta inak, než bolo zamýšľané. Zámer je zrejme vážený priemer 80 % BL + 20 % PL (resp. 70/30) + 8 €/MWh: `(cena × 800 + cena_pxe_pl × 200) / 1000 + 8`. Treba overiť (otázka 9).
- **Rollupy:** HubSpot API nevracia definíciu rollupov (zdrojovú vlastnosť a funkciu). Ich význam je odvodený z názvov a pred implementáciou ho treba potvrdiť.

## 3. Návrh zmien dátového modelu v0.3

| # | Zmena | Dôvod |
| --- | --- | --- |
| 1 | **Zákazník OOM** sa pri migrácii odvodí z dealu: firma dealu, inak kontakt dealu. Pri viacerých dealoch rozhodne najnovší deal v stave zmluvy. | OOM nemá väzbu na firmu (2.1) |
| 2 | **`company_contact` (n:n)** s `is_primary` a `role` namiesto `contact.company_id`. B2C ostáva kontakt bez záznamu v `company_contact`. | 215 kontaktov má viac firiem |
| 3 | **`oom`** rozšíriť o technické polia z 2.2: `pds`, `pds_point_id`, `pds_tariff`, `voltage_level`, `metering_type`, `phases`, `breaker_a`, `reserved_capacity_kw`, `max_reserved_capacity_kw`, `capacity_reservation_method`, `price_regulation`, `excise_tax`, `billing_period`, `advance_payment_method`, `advance_payment_pct`, `planned_consumption_vt_mwh`, `planned_consumption_nt_mwh`, `planned_feed_in_mwh`, `source_power_kw`, `source_kind`, `source_type`, `feed_in_contract_type`, `supply_from`, `supply_to`, `customer_segment` (domácnosť / firma), adresa po zložkách | sú vyplnené takmer na 100 % |
| 4 | **`oom.type`**: `spotreba`, `vyroba`, `sharing`, `velkoobchod`. **`oom.status`**: doplniť `prepisane` (rozhodnutia 2 a 3). | 4 pipelines OOM |
| 5 | **`contract`** ostáva samostatná tabuľka (1:1 k vyhratému dealu). Číslo zmluvy, účinnosť, trvanie, stav, fáza, splatnosť, flexibilita a preddavok sa presunú z dealu do zmluvy. Štádiá „Zmluvy_RRRR“ sa pri migrácii prevedú na `contract.valid_to` a deal dostane štádium „Vyhraté“. | deal je dnes aj zmluva (2.3) |
| 6 | **Pipelines v jadre** majú iba obchodné štádiá: Príležitosť, Cenová ponuka, Vyjednávanie, Akceptácia, Vyhraté, Prehraté. Stav zmluvy (platná, ukončená, výpoveď neakceptovaná, zmenový proces neúspešný) sa sleduje na `contract`. | štádiá dnes miešajú obchod a zmluvu |
| 7 | **`contract_price`**: `oom_id` povinné, `contract_id` povinné, `product_id`, `price_vt_eur_mwh`, `price_nt_eur_mwh`, `imbalance_price_eur_mwh`, `additive_coefficient_pct`, `fee_oom_eur_month`, `fee_zem_eur_month`, `fee_vbattery_eur_month`, `vbattery_program`, `direction` (odber / dodávka), `valid_from`, `valid_to` (NULL = na neurčito), `status` | 2.4 |
| 8 | **`product`**: jeden katalóg (kód, názov, typ: dodávka / výkup / služba / poplatok, jednotka €/MWh alebo €/mesiac, cenníková cena, platnosť) s mapovaním na 41 HubSpot produktov aj 57 kódov zo zmluvných cien | dva katalógy dnes (2.10) |
| 9 | **Nákupná cena** (rozhodnutie 5): zdroj je Cockpit. V CRM bude na zmluve iba `purchase_price_eur_mwh` + `purchase_priced_on` a odkaz na záznam v Cockpite; tabuľka `purchase_price` v CRM nevzniká. Spôsob prenosu (zdieľaná DB alebo API Cockpitu) navrhneme v module marže a provízií. | 2.5, 2.10 |
| 10 | **`supplier_switch`** (nová tabuľka, zmenový proces): `oom_id`, `deal_id`, `message_type` (XML433, XML43D), `message_date`, `effective_date`, `point_kind`, `metering_type`, `notice_to_previous_supplier`, `notice_accepted_at`, `customer_notified_at` | Dnes sú to polia na dealoch a 7 370 „notifikačných“ dealov. |
| 11 | **`voucher`** (GreenCar): `deal_id`, `code`, `value_eur`, `sent_at`, `status` | 1 815 dealov |
| 12 | **`referral`** (odporúčania): `contact_id` odporúčateľa, `deal_id`, `discount_eur`, `reward_eur`, `status` | Growthdrive polia |
| 13 | **`offer`, `offer_item`** ostávajú. Pri migrácii sa naplnia z HubSpot quotes, line items a polí `gp_*` na kontaktoch. | 2 436 ponúk + 1 426 kontaktov |
| 14 | **`company`**: `ico` ako text, Finstat polia (`vat_payer`, `registry_entry`, `nace`, `statutory`, `payment_rating`, `debts_note`, `insolvency_note`, `finstat_url`, `finstat_updated_at`) | 2.6 |
| 15 | **`contact.type`** (domácnosť, firma, komunál, výrobca, externý partner – predaj, externý partner – služby) | 2.6 |
| 16 | **`app_user`**: roly rozšíriť o `externy_obchodnik` a `externy_dodavatel` s prístupom iba k vlastným záznamom. Pribudne tabuľka `team`. | 2.9 |
| 17 | ~~`ticket`~~ – **nevzniká**. Historické tickety sa iba archivujú (export). | rozhodnutie 4 |
| 18 | **`consent.purpose`** podľa aktívnych typov odberu: `marketing_greenlogy`, `blog`, `produkty_a_sluzby`, `individualna_komunikacia`, `zakaznicke_sluzby`, plus `legal_basis` | 2.9 |
| 19 | **Vypočítané polia** (marža, výnosy, objemy, počty OOM) sa neukladajú. Budú v pohľadoch (views) nad dátami: `contract_revenue_v` (výnos zo zmluvných cien), `deal_margin_v` (hrubá marža podľa 2.10, model 1), `commission_base_v`. Marža podľa line items (model 2) sa nepreberá. | 2.10 |
| 20 | **Nemigruje sa:** labely asociácií, párovacie kódy, `subjekt`, `obchodnik` (text), `claude_audit`, polia marketingových ciest „GRN … Engine“, forecast polia, životopisy | duplicitné, technické alebo nevhodné dáta |

## 4. Rozhodnutia (Peter, 10. 10. 2026)

| # | Otázka | Rozhodnutie |
| --- | --- | --- |
| 1 | Notifikačné dealy (7 370) | Nemigrujú sa ako dealy, ale ako `supplier_switch` a `voucher`. |
| 2 | Stav OOM „Prepísané“ | Doplniť ako piaty stav (aj do `CLAUDE.md`). |
| 3 | Sharing a veľkoobchod | Samostatné typy OOM. |
| 4 | Historické tickety | Nemigrujú sa, iba sa archivuje export. |
| 5 | Nákupné ceny | Zdroj je Cockpit. CRM ich potrebuje na výpočet marže, nemusí ich spravovať samostatne. Spôsob prenosu z Cockpitu treba navrhnúť (návrh 9 sa podľa toho upraví). |
| 6 | GreenSolar a EFET | Ponechať. |
| 7 | Externí obchodníci a dodávatelia | Pracujú v CRM s obmedzeným prístupom. |
| 8 | Vlastník OOM pri migrácii | Najnovší deal v stave zmluvy (návrh 1). |
| 9 | Vzorec `cena_obchod` | Vážený priemer BL/PL + 4 €/MWh odchýlka + 4 €/MWh marža. Zátvorky vo vzorci v HubSpote treba pri migrácii overiť na uložených hodnotách. |
| 10 | Marža pri výkupe | Vzorec je správny, platí rovnako ako pri dodávke. |
| 11 | Marža podľa line items | Nepreberá sa. |

Dátový model v0.3 je zapísaný v `docs/01-datovy-model.md`.

## 5. Čo inventár nepokryl

- **Produkty a line items:** skript je doplnený (sekcia `products`), čaká na spustenie.
- **Vzorce vypočítaných polí:** skript je doplnený (sekcia `formulas`), čaká na spustenie.
- **Akcie workflowov** sú zatiaľ iba spočítané podľa typu. Slovný opis jednotlivých workflowov dopíšeme pri module, ktorý ich nahrádza.
- **Šablóny predajných e-mailov:** vynechané podľa rozhodnutia, texty sa prenesú ručne.

## 6. Bezpečnosť (z inventára Make)

V troch Make scenároch Sales portálu je HubSpot token vpísaný ako text a jeden webhook vracia zoznam vlastníkov bez overenia. Odporúčanie: token zneplatniť a vydať nový, uložiť ho do Make connection a doplniť overenie webhooku. Detaily sú v `make-scenare.md`. Náprava je podľa rozhodnutia odložená.
