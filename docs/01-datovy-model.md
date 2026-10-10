# Dátový model jadra – v0.2

Stav: NÁVRH na schválenie (10. 10. 2026). Po schválení sa z neho vytvorí migrácia `0001_jadro.sql`.

Zmeny oproti v0.1: B2C zákazník je kontakt bez firmy (nová logika „zákazník = firma ALEBO kontakt“), trading book vypadol (žije v Cockpite), pracovný čas pre SLA je Po–Pi 7:30–15:30.

## Princípy

- Relačný model v PostgreSQL. Väzby sú cudzie kľúče, nie kópie dát.
- Každý záznam z HubSpotu má `hubspot_id` (unikátny), aby nočná synchronizácia vedela záznam aktualizovať namiesto duplikovania.
- Stavy a typy sú enumy, aby reporty v Cockpite nemuseli porovnávať text.
- Všetky obchodné tabuľky majú `id` (uuid), `created_at`, `updated_at`, `owner_id` tam, kde existuje vlastník.

## Zákazník: firma alebo kontakt

Rovnako ako v HubSpote: B2B zákazník je firma s kontaktmi, B2C zákazník je kontakt bez firmy.
Tabuľky, ktoré patria zákazníkovi (`oom`, `deal`, `contract`), majú dva stĺpce:

- `company_id` – vyplnený pri B2B,
- `person_id` – vyplnený pri B2C (odkaz na `contact`),

a databázové pravidlo `CHECK (num_nonnulls(company_id, person_id) = 1)`, teda vždy práve jeden.
Pre reporty bude pohľad `customer_v`, ktorý obe skupiny spojí do jedného zoznamu zákazníkov (id, typ B2B/B2C, názov, IČO alebo e-mail).

## Prehľad väzieb

```
company 1───n contact            (kontakt firmy; B2C kontakt má company_id = NULL)
zákazník (company | contact) 1──n oom, deal, contract
deal    n───n oom                (deal_oom)
deal    n───n contact            (deal_contact: osoby na dealu + rola)
deal    1───n offer              (ponuky, verzie)
deal    1───1 contract           (zmluva vzniká z vyhratého dealu)
contract 1──n contract_price     (zmluvné ceny podľa obdobia)
oom     1───n purchase_price     (nákupné ceny pri výrobe / FVE)
deal    1───n commission         (provízie obchodníkov)
activity n──1 company / contact / deal / oom   (časová os)
conversation 1──n activity; sla_record 1──1 conversation
consent n───1 contact            (GDPR súhlasy a odhlásenia)
```

## Tabuľky

### Ľudia a firmy

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `app_user` | email, name, role (`obchodnik`, `servis`, `vedenie`, `admin`), active | 14 používateľov; prihlásenie cez Cloudflare Access podľa e-mailu |
| `company` | name, ico, dic, ic_dph, segment, lifecycle_stage, address, owner_id, hubspot_id | iba B2B |
| `contact` | company_id (NULL pri B2C), first_name, last_name, email, phone, position, address, is_customer, lifecycle_stage, owner_id, hubspot_id, posthog_distinct_id | e-mail je kľúč na párovanie s PostHog, Chatwoot, Brevo, CloudTalk; `is_customer = true` pri B2C zákazníkovi |

### Energetická doména

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `oom` | company_id / person_id, eic (unikátny), type (`spotreba`, `vyroba`), status (`aktivne`, `neaktivne`, `zrusene`, `odidene`), address, distribution_company, voltage_level, tariff, annual_consumption_mwh, installed_power_kw, source_type (FVE, MVE…), hubspot_id | podľa custom objektu OOM `2-16666415`; zoznam vlastností potvrdí inventár HubSpotu |
| `oom_device` | oom_id, device_type (menič, batéria, tepelné čerpadlo, wallbox), brand, model, capacity | údaje z prieskumu u FVE zákazníkov |
| `contract` | deal_id, company_id / person_id, number, product (FIX, SPOT, SPOT+ADITÍV…), valid_from, valid_to, signed_at, status | |
| `contract_price` | contract_id, oom_id (voliteľne), period_from, period_to, price_type, price_eur_mwh, fee_eur_month, hubspot_id | zo Zmluvných cien `2-16395301` |
| `purchase_price` | oom_id, contract_number, pricing_model (FIX/SPOT), price_eur_mwh, spot_discount_pct, valid_from, valid_to, hubspot_id | z Nákupných cien `2-22997964` |

### Obchod

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `pipeline`, `pipeline_stage` | name, sort_order, is_closed, is_won, hubspot_id | aktívne pipelines prenesieme 1:1 |
| `deal` | company_id / person_id, pipeline_id, stage_id, name, amount_eur, volume_mwh, expected_close, closed_at, lost_reason, owner_id, hubspot_id | |
| `deal_oom`, `deal_contact` | väzobné tabuľky (+ role pri kontakte) | z `deal_oom` sa odvodzuje pravidlo kontakt ↔ OOM |
| `offer` | deal_id, version, status (`koncept`, `odoslana`, `otvorena`, `prijata`, `zamietnuta`), valid_until, total_eur, pdf_url, sent_at, opened_at | PDF v Cloudflare R2 |
| `offer_item` | offer_id, oom_id, product, price_eur_mwh, volume_mwh, fee_eur_month | |
| `commission_rule` | product, segment, rate_type, rate_value, valid_from | logika zo Sales portálu |
| `commission` | deal_id, user_id, amount_eur, period, status (`vypocitana`, `schvalena`, `vyplatena`) | |

### Komunikácia, servis a SLA

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `activity` | type (`email`, `hovor`, `chat`, `fb`, `poznamka`, `uloha`, `web`, `kampan`), direction, company_id, contact_id, deal_id, oom_id, user_id, occurred_at, subject, body_preview, source, source_id | jedna časová os; plné texty v zdrojovom systéme, v jadre náhľad a odkaz |
| `call` | activity_id, cloudtalk_call_id, duration_s, recording_url, transcript, agent_id | z webhookov CloudTalku |
| `conversation` | chatwoot_conversation_id, channel (`email`, `web_chat`, `facebook`, `telefon`), contact_id, company_id, status, opened_at, first_response_at, resolved_at, assignee_id | |
| `sla_record` | conversation_id, first_response_due, first_response_at, resolution_due, resolved_at, first_response_met, resolution_met | termíny: +8 a +24 pracovných hodín |
| `business_calendar` | date, is_working_day, work_from (7:30), work_to (15:30), note | slovenské sviatky + pracovný čas |

### Marketing a súhlasy

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `consent` | contact_id, purpose (`marketing_email`, `newsletter`, `analytika`), status (`udeleny`, `odvolany`), source, recorded_at | migrácia súhlasov a odhlásení je povinná pred prvou kampaňou |
| `segment` | name, definition (filter JSON), sync_to_brevo | segmenty pre kampane |
| `campaign` | name, channel, brevo_campaign_id, sent_at, stats (JSON) | štatistiky pre Cockpit |
| `web_event` | contact_id, posthog_distinct_id, event, url, occurred_at | iba vybrané udalosti (formulár, cenník, kľúčové stránky) |

### Systém

| Tabuľka | Kľúčové stĺpce | Poznámka |
| --- | --- | --- |
| `audit_log` | table_name, record_id, action, changed_by, changed_at, diff (JSON) | každá zmena obchodných dát |
| `sync_run` | source, started_at, finished_at, records_in, records_updated, errors | nočná synchronizácia z HubSpotu |

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

## Otvorené otázky

1. Kompletný zoznam vlastností OOM, zmluvných a nákupných cien – doplní inventár HubSpotu (modul 0).
2. Ktoré pipelines a štádiá sú aktívne a ktoré sa pri migrácii môžu zlúčiť – doplní inventár.
