# Dátový model jadra – v0.3.1

Stav: SCHVÁLENÝ (Peter, 11. 10. 2026; v0.3 schválená 10. 10. 2026). Z neho sa vytvorí migrácia `0001_jadro.sql` (modul 1).

Podklad: inventár HubSpotu (modul 0), najmä `docs/inventar/suhrn.md`. Čísla návrhov (N1–N20) odkazujú na kapitolu 3 súhrnu.

## Zmeny oproti v0.3

- Nová tabuľka `contract_purchase`: zmluva má viac nákupných cien (dnes až 3 na deal), každú pre produkt a rok dodávky. Zo `contract` odpadajú stĺpce `purchase_price_*`.
- `product.pricing_model` (`fix`, `spot_aditiv`, `index_spot`) a samostatný `contract_price.additive_eur_mwh`. V HubSpote dnes polia VT/NT pri SPOT produktoch nesú aditív.
- Jeden enum `customer_segment` (`domacnost`, `firma`, `dodavatel`), stĺpce sa volajú `segment`. Typ kontaktu sa zjednotil so segmentom (`contact.segment`). Drží ho zákazník a OOM, deal a zmluva ho preberajú. Firma nemá segment `domacnost`; komunálni zákazníci sú `firma`.
- IČO je text s 8 číslicami (úvodné nuly) a je unikátne.
- `deal.closed_at` je skutočné uzavretie dealu, nie dátum nákupu.
- `offer.total_eur` je zámerná snímka odoslanej ponuky.
- Vstupy výpočtov: `contract_price.fee_rk_eur_kw_month` (Green VIWA), `fve_project.discount_savings_eur` a `nep_settlement_eur` (GreenSolar).
- Roly `externy_obchodnik` a `externy_dodavatel` sa rušia. Externí obchodníci majú rovnaké práva ako interní; obmedzenie na úrovni riadkov sa nerobí.
- Pohľady `contract_revenue_v`, `deal_margin_v` a `commission_base_v` nie sú v `0001`. Prídu v samostatnej migrácii po inventári produktov a vzorcov (sekcie `products`, `formulas`) a po potvrdení rollupov.

## Zmeny oproti v0.2

- Väzba firma–kontakt je n:n (`company_contact`), nie stĺpec `contact.company_id` (N2).
- OOM: 4 typy (spotreba, výroba, sharing, veľkoobchod), 5 stavov (pribudol Prepísané) a technické údaje z HubSpotu (N3, N4).
- Zmluva (`contract`) preberá zmluvné údaje, ktoré sú dnes na dealoch. Pipelines majú iba obchodné štádiá (N5, N6).
- `contract_price` podľa skutočných zmluvných cien. Nový katalóg `product` (N7, N8).
- `purchase_price` ako tabuľka v CRM nevzniká. Nákupná cena prichádza z Cockpitu a na zmluve je iba jej hodnota a odkaz (N9).
- Nové tabuľky: `team`, `supplier_switch` (zmenový proces), `voucher` (GreenCar), `referral` (odporúčania) (N10–N12, N16).
- Firma má údaje z Finstatu, kontakt má typ (N14, N15). Vo v0.3.1 typ kontaktu nahradil segment.
- Roly pre externých obchodníkov a dodávateľov s prístupom iba k vlastným záznamom (N16).
- Účely súhlasov podľa typov odberu v HubSpote (N18).
- Marža, výnosy a objemy sú pohľady, nie uložené stĺpce (N19).
- Historické tickety sa nemigrujú, iba archivujú (N17).

## Princípy

- Relačný model v PostgreSQL. Väzby sú cudzie kľúče, nie kópie dát ani textové párovacie kódy.
- Každý záznam z HubSpotu má `hubspot_id` (unikátny), aby nočná synchronizácia vedela záznam aktualizovať namiesto duplikovania.
- Stavy a typy sú enumy, aby reporty v Cockpite nemuseli porovnávať text.
- Všetky obchodné tabuľky majú `id` (uuid), `created_at`, `updated_at`; `owner_id` tam, kde existuje vlastník. Zmeny idú do `audit_log`.
- Hodnoty, ktoré sa dajú vypočítať (marža, výnos, objemy, počty OOM), sa neukladajú. Počítajú sa v pohľadoch.
- Peniaze `numeric(12,2)` EUR, ceny elektriny `numeric(12,4)` €/MWh, časy `timestamptz` (UTC).

## Zákazník: firma alebo kontakt

B2B zákazník je firma, B2C zákazník je kontakt bez firmy.
Tabuľky, ktoré patria zákazníkovi (`oom`, `deal`, `contract`), majú dva stĺpce:

- `company_id` – vyplnený pri B2B,
- `person_id` – vyplnený pri B2C (odkaz na `contact`),

a databázové pravidlo `CHECK (num_nonnulls(company_id, person_id) = 1)`, teda vždy práve jeden.
Pohľad `customer_v` spojí obe skupiny do jedného zoznamu zákazníkov (id, typ B2B/B2C, názov, IČO alebo e-mail).

**Segment** (`domacnost`, `firma`, `dodavatel`) patrí zákazníkovi, nie osobe:

- firma má segment `firma` alebo `dodavatel` (nikdy `domacnost`),
- kontakt má segment v stĺpci `contact.segment` (nahrádza typ kontaktu); B2C zákazník má spravidla `domacnost`, ten istý človek môže byť zároveň zástupcom firmy,
- OOM má vlastný segment,
- deal a zmluva segment preberajú od zákazníka pri vzniku (ak ho nikto nezadá ručne).

## Prehľad väzieb

```
company n───n contact             (company_contact: is_primary, role; B2C kontakt nemá firmu)
zákazník (company | contact) 1──n oom, deal, contract
deal     n───n oom                (deal_oom)
deal     n───n contact            (deal_contact: osoby na deale + rola)
deal     1───n offer 1──n offer_item
deal     1───1 contract           (zmluva vzniká z vyhratého dealu)
contract 1───n contract_price n──1 oom   (cena pre OOM na obdobie)
contract 1───n contract_purchase       (nákupné ceny podľa produktu a roku dodávky, zdroj Cockpit)
product  1───n contract_price, offer_item
oom      1───n oom_device
oom      1───n supplier_switch    (zmenový proces, správy XML433 / XML43D)
deal     1───n voucher, referral, commission
app_user n───1 team
activity n──1 company / contact / deal / oom   (časová os)
conversation 1──n activity; sla_record 1──1 conversation
consent  n───1 contact            (súhlasy a odhlásenia)
kontakt ↔ OOM: odvodené cez deal_oom + deal_contact (pohľad contact_oom_v)
```

## Tabuľky

### Ľudia, firmy a prístup

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `team` | name, hubspot_id | Sales_external, Sales_internal, OfficeZA, OfficeZA_Frontoffice, Marketing, Sourcing, Supplier_external, CEO |
| `app_user` | email, name, role (`admin`, `vedenie`, `obchodnik`, `servis`, `marketing`), team_id, active, hubspot_owner_id | ~30 aktívnych používateľov. Prihlásenie cez Cloudflare Access podľa e-mailu. Externí obchodníci majú rolu `obchodnik` (tím Sales_external). |
| `company` | name, ico (text, 8 číslic, unikátne), dic, ic_dph, vat_payer, legal_form, registry_entry, nace, statutory, address, segment (`firma`, `dodavatel`), payment_rating (A–E, X), debts_note, insolvency_note, finstat_url, finstat_updated_at, lifecycle_stage, owner_id, hubspot_id | iba B2B, údaje z Finstatu |
| `contact` | first_name, last_name, title, email, phone, mobile, position, address, segment (`domacnost`, `firma`, `dodavatel`), lifecycle_stage, source, campaign, owner_id, hubspot_id, posthog_distinct_id | E-mail je kľúč na párovanie s PostHog, Chatwoot, Brevo, CloudTalk. B2C zákazník = kontakt bez záznamu v `company_contact`. |
| `company_contact` | company_id, contact_id, is_primary, role (`statutar`, `kontaktna_osoba`, `fakturacia`, `ine`) | n:n, 215 kontaktov má dnes viac firiem |

### Energetická doména

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `oom` | company_id / person_id, eic (unikátny), type (`spotreba`, `vyroba`, `sharing`, `velkoobchod`), status (`aktivne`, `neaktivne`, `zrusene`, `odidene`, `prepisane`), segment (`domacnost`, `firma`, `dodavatel`), name, address_street, address_number_supisne, address_number_orientacne, address_city, address_zip, hubspot_id | podľa custom objektu OOM `2-16666415`; typ = pipeline, stav = štádium |
| | **distribúcia:** pds, pds_point_id (číslo OP), pds_tariff, voltage_level, metering_type, phases, breaker_a, reserved_capacity_kw, max_reserved_capacity_kw, capacity_reservation_method | |
| | **fakturácia:** price_regulation, excise_tax, billing_period, advance_payment_method, advance_payment_pct | |
| | **objemy a výroba:** planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh, source_power_kw, source_kind (FVE, voda, bioplyn, plyn, vietor, ostatné OZE), source_type (`virtualna_bateria`, `lokalny_zdroj`, `vyrobny_zdroj`, `green_viwa`), feed_in_contract_type, inverter_power_kw, panels_power_kw | výroba ~3 600 OOM |
| | **dodávka a zmena dodávateľa:** supply_from, supply_to (NULL = neurčito), previous_supplier_notice (`akceptacia`, `bez_akceptacie`, `nezasiela_sa`, `odoslana`, `potvrdena`), previous_supplier_notice_accepted_at | |
| `oom_device` | oom_id, device_type (`striedac`, `panely`, `bateria`, `tepelne_cerpadlo`, `wallbox`), brand, model, power_kw, capacity_kwh, count, details (JSON) | dotazník pri FVE zákazníkoch |
| `supplier_switch` | oom_id, deal_id, message_type (`xml433`, `xml43d`), segment (`domacnost`, `organizacia`), message_date, effective_date, point_kind, metering_type, customer_notified_at, hubspot_id | Zmenový proces. Dnes polia XML433/XML43D na dealoch a 7 370 „notifikačných“ dealov. |
| `product` | code, name, kind (`dodavka`, `vykup`, `sluzba`, `poplatok`), pricing_model (`fix`, `spot_aditiv`, `index_spot`), unit (`eur_mwh`, `eur_mesiac`), list_price, valid_from, valid_to, hubspot_product_id, hubspot_contract_codes (text[]) | jeden katalóg namiesto 41 produktov a 57 kódov zmluvných cien |
| `contract` | deal_id (zatiaľ unikátny: 1 deal = 1 zmluva), company_id / person_id, number (unikátne), segment (preberá od zákazníka), status (`rozpracovana`, `caka_na_podpis`, `podpisana`, `caka_na_zaradenie`, `aktivna`, `ukoncena`, `vypoved_neakceptovana`, `zmena_neuspesna`), confirmed, auto_prolong, valid_from, valid_to (NULL = neurčito), signed_at, payment_terms_days, consumption_tolerance, advance_payment_pct, hubspot_deal_id | Zmluvné údaje, ktoré sú dnes na dealoch. Štádiá „Zmluvy_RRRR“ sa prevedú na `valid_to`. |
| `contract_price` | contract_id, oom_id, product_id, direction (`odber`, `dodavka`), price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, imbalance_price_eur_mwh, additive_coefficient_pct, fee_oom_eur_month, fee_zem_eur_month, fee_vbattery_eur_month, fee_rk_eur_kw_month (Green VIWA), vbattery_program, valid_from, valid_to (NULL = neurčito), status (`platna`, `neplatna`), hubspot_id | Zo Zmluvných cien `2-16395301`. Hodnota 31. 12. 2099 sa pri migrácii mení na NULL. Najviac jedna platná cena na OOM a zmluvu. Pri SPOT produktoch je aditív v `additive_eur_mwh`, nie v cene VT/NT. |
| `contract_purchase` | contract_id, product_code (napr. `SK BL CAL2027`), delivery_year, priced_on, price_eur_mwh, cockpit_ref | Nákupné ceny zmluvy. Zdroj je Cockpit; jedna nákupná tranža môže patriť viacerým zmluvám (v HubSpote až 32 dealom), preto sa opakuje `cockpit_ref`. |

**Nákupná cena:** zdroj je Cockpit. V CRM sú nákupné ceny zmluvy v `contract_purchase` (hodnota, produkt, rok dodávky, dátum nákupu, odkaz do Cockpitu). Spôsob prenosu (zdieľaná databáza alebo API Cockpitu) sa navrhne v module marže a provízií.
Výpočet v HubSpote (pre informáciu, zdrojom bude Cockpit): cena = PXE BL × 0,8 + PXE PL × 0,2 + 4 €/MWh odchýlka + 4 €/MWh marža, ak je produkt `PXE2027`, inak pomer 0,7 / 0,3. Vzorec v HubSpote (`cena_obchod`) má chybne umiestnené zátvorky; pri migrácii treba overiť uložené hodnoty.

### Obchod

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `pipeline`, `pipeline_stage` | name, sort_order, probability, is_closed, is_won, hubspot_id | Pipelines: B2C elektrina, B2B elektrina, B2B výkup, Green VIWA B2B, GreenSolar, EFET. Štádiá iba obchodné: Príležitosť, Cenová ponuka, Vyjednávanie, Akceptácia, Vyhraté, Prehraté. |
| `deal` | company_id / person_id, pipeline_id, stage_id, name, segment (preberá od zákazníka), campaign, source, expected_close, closed_at, lost_reason, owner_id, hubspot_id | Suma a marža sú pohľady (nižšie). `closed_at` je skutočné uzavretie dealu (HubSpot close date je dnes dátum nákupu). |
| `deal_oom`, `deal_contact` | väzobné tabuľky (+ rola pri kontakte) | z nich sa odvodzuje pravidlo kontakt ↔ OOM |
| `offer` | deal_id, version, status (`koncept`, `odoslana`, `otvorena`, `prijata`, `zamietnuta`), valid_until, total_eur, pdf_url, sent_at, opened_at, hubspot_quote_id | PDF v Cloudflare R2. `total_eur` je zámerná snímka odoslanej ponuky (nepočíta sa z položiek). Migrácia z HubSpot quotes a polí `gp_*` na kontaktoch. |
| `offer_item` | offer_id, oom_id, product_id, price_eur_mwh, volume_mwh, fee_eur_month | |
| `commission_rule` | product_id / pipeline_id, segment, rate_type, rate_value, valid_from | logika zo Sales portálu a GreenSolar |
| `commission` | deal_id, user_id, base_eur, amount_eur, period, status (`vypocitana`, `cakajuca`, `uplatnena`, `schvalena`, `vyplatena`, `zrusena`), pdf_url | dnes `commission_status_sales_portal` |
| `voucher` | deal_id, contact_id, code, value_eur, sent_at, redeemed, status | GreenCar poukážky |
| `referral` | referrer_contact_id, deal_id, discount_eur, reward_eur, reward_type, status | odporúčací program (dnes Growthdrive) |
| `fve_project` | deal_id, program (`eco`, `standard`, `premium`), price_with_vat, vat_rate, advance_eur, status (`ponuka_odoslana`, `ponuka_akceptovana`, `zaloha_uhradena`, `dielo_prevzate`, `dielo_uhradene`), partner_commission_pct, partner_name (obchodník NEP), discount_savings_eur (úspora na zľave), nep_settlement_eur (doúčtovanie z NEPu) | GreenSolar (60 dealov) |

### Komunikácia, servis a SLA

Bez zmeny oproti v0.2: `activity`, `call`, `conversation`, `sla_record`, `business_calendar`.
Historické tickety z HubSpotu (61 723) sa nemigrujú. Ich export sa archivuje (umiestnenie v EÚ určí modul migrácie).

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `activity` | type (`email`, `hovor`, `chat`, `fb`, `poznamka`, `uloha`, `web`, `kampan`), direction, company_id, contact_id, deal_id, oom_id, user_id, occurred_at, subject, body_preview, source, source_id | jedna časová os; plné texty v zdrojovom systéme |
| `call` | activity_id, cloudtalk_call_id, duration_s, recording_url, transcript, agent_id | z webhookov CloudTalku |
| `conversation` | chatwoot_conversation_id, channel (`email`, `web_chat`, `facebook`, `telefon`), contact_id, company_id, oom_id, product, quality_standard, status, opened_at, first_response_at, resolved_at, assignee_id, rating | `quality_standard` = regulačné štandardy kvality |
| `sla_record` | conversation_id, first_response_due, first_response_at, resolution_due, resolved_at, first_response_met, resolution_met | termíny: +8 a +24 pracovných hodín |
| `business_calendar` | date, is_working_day, work_from (7:30), work_to (15:30), note | slovenské sviatky + pracovný čas |

### Marketing a súhlasy

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `consent` | contact_id, purpose (`marketing_greenlogy`, `blog`, `produkty_a_sluzby`, `individualna_komunikacia`, `zakaznicke_sluzby`), status (`udeleny`, `odvolany`), legal_basis, source, recorded_at, hubspot_subscription_id | podľa aktívnych typov odberu v HubSpote; migrácia je povinná pred prvou kampaňou |
| `segment` | name, definition (filter JSON), sync_to_brevo | segmenty pre kampane |
| `campaign` | name, channel, brevo_campaign_id, sent_at, stats (JSON) | štatistiky pre Cockpit |
| `web_event` | contact_id, posthog_distinct_id, event, url, occurred_at | iba vybrané udalosti. Kroky zákazníckych ciest („GRN … Engine“) sa sledujú v PostHogu, nie v stĺpcoch. |

### Systém

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `audit_log` | table_name, record_id, action, changed_by, changed_at, diff (JSON) | každá zmena obchodných dát |
| `sync_run` | source, started_at, finished_at, records_in, records_updated, errors | synchronizácia z HubSpotu počas prechodu |

## Pohľady (výpočty)

V `0001` sú iba `customer_v` a `contact_oom_v`. Výpočtové pohľady (`contract_price_volume_v`, `contract_revenue_v`, `deal_margin_v`, `commission_base_v`) prídu v samostatnej migrácii po inventári produktov a vzorcov a po potvrdení rollupov; vzorce nižšie sú východisko. Pri viacerých nákupných cenách sa určí, ktorá platí pre ktorý objem.

| Pohľad | Výpočet |
| --- | --- |
| `customer_v` | firmy (B2B) + kontakty bez firmy (B2C) |
| `contact_oom_v` | kontakt ↔ OOM cez `deal_contact` a `deal_oom`, iba OOM v stave Aktívne alebo Neaktívne |
| `contract_price_volume_v` | objemy pre zmluvnú cenu z OOM: VT = plánovaná spotreba VT, NT = plánovaná spotreba NT, výkup = plánovaný výkup |
| `contract_revenue_v` | výnos z elektriny = cena VT × objem VT + cena NT × objem NT + cena VT × objem výkupu + cena odchýlky × objem výkupu; výnos z fixov = (poplatok OM + ZEM + VBattery) × 12 |
| `deal_margin_v` | výnos = Σ výnos z elektriny + Σ výnos z fixov (+ Green VIWA poplatok za RK × 12 × výkon); hrubá marža = výnos − nákupná cena × (objem spotreby + objem výkupu); marža na MWh = hrubá marža / objem spotreby |
| `commission_base_v` | Sales portál: výnos z elektriny − nákupná cena × objem spotreby; GreenSolar: (cena s DPH / sadzba DPH − dodatočná provízia) × % + dodatočná provízia, pri partnerovi NEP polovica |

Výpočet marže podľa line items (starší model v HubSpote) sa nepreberá.

## Migrácia z HubSpotu – hlavné pravidlá

1. Zákazník OOM = firma, inak kontakt najnovšieho dealu v stave zmluvy (OOM v HubSpote nemá väzbu na firmu).
2. Deal v štádiu „Zmluvy_RRRR“, „Zmluvy_neurčito“ alebo „Úspech“ → deal „Vyhraté“ + `contract` (valid_to podľa roku, neurčito = NULL).
3. 7 370 dealov „Greenlogy_B2C_služby / Notifikačný email“ → `supplier_switch` a `voucher`, nie deal.
4. Labely asociácií, párovacie kódy, textové polia `subjekt` a `obchodnik`, `claude_audit`, polia „GRN … Engine“, forecast polia a životopisy sa nemigrujú.
5. Ak asociácia chýba, väzba sa dopočíta z čísla zmluvy alebo EIC.
6. IČO sa prevádza na text a dopĺňa úvodnými nulami na 8 číslic (HubSpot ho má ako číslo, pole `ico_new`). Kontrola 11. 10. 2026: 2 282 firiem s IČO, 123 sa doplní nulami, 1 hodnota má 10 číslic (pravdepodobne DIČ), 2 IČO sú duplicitné (4 firmy). Tieto prípady sa vyriešia pred migráciou.
7. HubSpot close date dealu je dnes dátum nákupnej ceny (workflow) → `contract_purchase.priced_on`. `deal.closed_at` = dátum vstupu do štádia výhry alebo prehry.
8. Pri SPOT produktoch sa aditív z polí VT/NT presúva do `contract_price.additive_eur_mwh` podľa `product.pricing_model`.
9. Segment: `komunal` → `firma`; typ kontaktu → `contact.segment` (mapovanie hodnôt `vyrobca`, `partner_predaj`, `partner_sluzby` určí modul migrácie).
10. Nákupné ceny (custom object `2-22997964`) → `contract_purchase` pre každú zmluvu pripojeného dealu.

## Výpočet SLA (pracovné hodiny)

Pracovný deň má 8 hodín (7:30–15:30). Termín sa počíta pripočítaním pracovných minút cez `business_calendar`:

- Prvá reakcia: +8 pracovných hodín = spravidla rovnaký čas nasledujúci pracovný deň.
- Odpoveď: +24 pracovných hodín = 3 pracovné dni.
- Správa mimo pracovného času sa počíta od najbližšieho začiatku pracovného dňa (7:30).

## Uzavreté otázky

| Otázka | Rozhodnutie |
| --- | --- |
| B2C zákazník | kontakt bez firmy |
| Trading book | mimo CRM, ostáva v Cockpite |
| Pracovný čas SLA | Po–Pi 7:30–15:30, slovenské sviatky |
| Vlastnosti OOM, zmluvných a nákupných cien | podľa inventára (modul 0) |
| Typy a stavy OOM | 4 typy, 5 stavov (pribudol Prepísané) |
| Segment | `domacnost`, `firma`, `dodavatel`; zákazník a OOM, deal a zmluva preberajú |
| Notifikačné dealy | `supplier_switch` a `voucher` |
| Historické tickety | iba archív exportu |
| Nákupné ceny | zdroj Cockpit, v CRM `contract_purchase` (viac cien na zmluvu) |
| GreenSolar, EFET | pipelines ostávajú |
| Externí obchodníci a dodávatelia | externý obchodník má rovnaké práva ako interný; rola externého dodávateľa nevzniká |
| Marža pri výkupe | rovnaký vzorec ako pri dodávke (potvrdené) |
| Marža podľa line items | nepreberá sa |

## Otvorené otázky

1. Spôsob prenosu nákupných cien z Cockpitu (zdieľaná databáza alebo API).
2. Definície rollupov v HubSpote (zdroj objemov a výnosov) – API ich nevracia. Pred implementáciou pohľadov ich treba potvrdiť v HubSpote.
3. Mapovanie 41 HubSpot produktov a 57 kódov zmluvných cien na jeden katalóg `product`.
4. Kam archivovať export historických ticketov.
