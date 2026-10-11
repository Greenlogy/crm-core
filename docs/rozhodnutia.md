# Rozhodnutia

| Dátum | Rozhodnutie | Dôvod |
| --- | --- | --- |
| 2026-10-10 | Vlastné CRM jadro nahradí HubSpot do obnovy 9. 7. 2027 | 3 220 €/mes. nájmu bez vlastného softvéru; doménové dáta (OOM, ceny) patria do vlastnej databázy |
| 2026-10-10 | Princíp: postaviť doménu, self-host komodity (Chatwoot), služba pri špecializácii (Brevo, sociálne siete) | najlepší pomer cena / kontrola / riziko |
| 2026-10-10 | Web ostáva na Webflow; analytika PostHog Cloud EU namiesto Hotjar; žiadny presun na HubSpot CMS | presun do systému, z ktorého odchádzame, nedáva zmysel |
| 2026-10-10 | Technológie: Postgres v EÚ + Cloudflare Workers / Pages / Access / Hyperdrive | rovnaký ekosystém ako Cockpit; relačný model pre väzby firma–kontakt–OOM–zmluva |
| 2026-10-10 | Kód píše Claude v Claude Code (VS Code), Peter schvaľuje každý krok | kontinuita cez repozitár a `CLAUDE.md` |
| 2026-10-10 | B2C zákazník = kontakt bez firmy; zákazník je firma alebo kontakt (práve jedno) | zhoda s dnešnými dátami v HubSpote |
| 2026-10-10 | Trading book sa nemigruje, ostáva v Cockpite | už tam existuje |
| 2026-10-10 | SLA: prvá reakcia 8 a odpoveď 24 pracovných hodín, pracovný čas Po–Pi 7:30–15:30 | interný štandard servisu |
| 2026-10-10 | Predajné šablóny e-mailov sa v module 0 neinventarizujú; CRM bude mať vlastnú funkciu šablón, texty sa prenesú ručne | HubSpot pre sales templates nemá verejné API |
| 2026-10-10 | Inventár asociácií počíta najviac 500 asociácií na záznam (nad tým „500+“) | deal má bežne 1–5 OOM, výnimočne viac ako 100; firma 1–10 kontaktov |
| 2026-10-10 | V inventári je kontakt B2C, ak nemá primárnu firmu (`associatedcompanyid`); súhlasy: počty odhlásených a marketingových kontaktov, bez počtu prihlásených | dostatočná presnosť bez čítania údajov každého kontaktu |
| 2026-10-10 | 7 370 „notifikačných“ dealov (Greenlogy_B2C_služby / Notifikačný email) sa nemigrujú ako dealy, ale ako záznamy zmenového procesu (`supplier_switch`) a poukážok (`voucher`) | nie sú to obchody, ale záznamy pre automatické e-maily |
| 2026-10-10 | OOM má päť stavov: Aktívne, Neaktívne, Zrušené, Odídené, Prepísané | stav „Prepísané“ existuje v HubSpote |
| 2026-10-10 | OOM má štyri typy: spotreba, výroba, sharing, veľkoobchod | zodpovedá štyrom pipelines OOM v HubSpote |
| 2026-10-10 | Historické tickety (61 723) sa nemigrujú, iba sa archivuje ich export | servis prechádza do Chatwootu, história slúži len na dohľadanie |
| 2026-10-10 | Nákupné ceny majú zdroj v Cockpite; CRM ich potrebuje na výpočet marže, nemusí ich spravovať samostatne. Spôsob prenosu z Cockpitu sa navrhne. | jeden zdroj pravdy pre nákup elektriny |
| 2026-10-10 | Pipelines GreenSolar a EFET sa ponechávajú | obchody pokračujú |
| 2026-10-10 | Externí obchodníci a dodávatelia pracujú priamo v CRM s obmedzeným prístupom (iba vlastné záznamy) | dnes majú prístup do HubSpotu |
| 2026-10-10 | Vlastník OOM sa pri migrácii odvodí z najnovšieho dealu v stave zmluvy (firma dealu, inak kontakt) | OOM v HubSpote nemá väzbu na firmu |
| 2026-10-10 | Náprava tokenu vpísaného v Make scenároch Sales portálu sa odkladá | rozhodne Peter neskôr |
| 2026-10-10 | Nákupná cena = vážený priemer PXE BL/PL + 4 €/MWh odchýlka + 4 €/MWh marža | potvrdenie významu vzorca `cena_obchod` v HubSpote |
| 2026-10-10 | Hrubá marža pri výkupe sa počíta rovnakým vzorcom ako pri dodávke | potvrdené Petrom |
| 2026-10-10 | Výpočet marže podľa line items (starší model v HubSpote) sa do jadra nepreberá | platí model podľa OOM a zmluvných cien |
| 2026-10-10 | Schválený súhrn inventára HubSpotu a dátový model jadra v0.3; modul 0 uzavretý | Peter |
| 2026-10-10 | Databáza: Neon, región EÚ (Frankfurt) | čistý Postgres; prihlasovanie rieši Cloudflare Access |
| 2026-10-10 | Bez lokálneho Postgresu: Neon vetvy `main` = produkcia, `dev` = vývoj a testy. Migrácie najprv na `dev`, na `main` až po Petrovom schválení. Pripojenia v `.dev.vars` ako `DATABASE_URL_DEV` a `DATABASE_URL_MAIN`. | izolované testovanie bez lokálnej inštalácie |
| 2026-10-10 | Migrácie cez dbmate: `db/migrations/0001_nazov.sql` so sekciami `-- migrate:up` a `-- migrate:down`; `db/schema.sql` sa commituje | číslované SQL súbory podľa konvencie, evidencia spustených migrácií |
| 2026-10-10 | Príklad SLA opravený: správa v piatok o 15:00 má termín prvej reakcie v pondelok o 15:00 (nie 14:30) | pri pracovnom čase 7:30–15:30 je 8 pracovných hodín = rovnaký čas nasledujúci pracovný deň |
| 2026-10-10 | Sviatky v `business_calendar` podľa aktuálneho znenia zákona 241/1993 Z. z.; zoznam 2026–2028 potvrdí Peter | konsolidácia menila dni pracovného pokoja |
| 2026-10-10 | Hodnoty, ktoré model nevymenúva (segment dealu a zmluvy, `lifecycle_stage`, stavy voucher/referral/conversation, smer aktivity, rola v deale, typ sadzby provízie), sú zatiaľ `text`; enumy doplní migrácia v module presunu dát | skutočné hodnoty sa zistia z HubSpotu |
| 2026-10-10 | Zatiaľ 1 deal = 1 zmluva (`contract.deal_id` unikátny); neskôr sa môže zmeniť novou migráciou | dnešný stav, predĺženia sa riešia neskôr |
| 2026-10-10 | Chýbajúce vstupy výpočtov (poplatok Green VIWA za RK, dodatočná provízia a % GreenSolar) sa doplnia ako stĺpce do `contract_price` a `fve_project`; partner NEP podľa `fve_project.partner_name` | pohľady marže a provízií potrebujú vstupy |
| 2026-10-10 | Pohľady výnosov a marže počítajú ročné hodnoty; do marže dealu idú iba zmluvné ceny v stave `platna` (najviac jedna platná cena na OOM a zmluvu) | potvrdené Petrom |
| 2026-10-10 | `audit_log` pokrýva všetky obchodné tabuľky okrem `audit_log`, `sync_run`, `web_event`, `business_calendar`; `changed_by` je uuid bez cudzieho kľúča (prázdny pri synchronizácii); diff: insert celý riadok, update iba zmenené stĺpce, delete pôvodný riadok | sledovateľnosť bez blokovania mazania používateľov |
| 2026-10-10 | `ON DELETE CASCADE` iba pri `company_contact`, `deal_oom`, `deal_contact`, `offer_item`, `oom_device`, `call`, `sla_record`; inak `RESTRICT` | závislé záznamy bez samostatného významu |
| 2026-10-10 | dbmate sa inštaluje cez npm (`package.json`, pevná verzia); psql a pg_dump z Postgres.app | Homebrew na stroji nie je |
| 2026-10-11 | Dátový model v0.3.1 schválený (pripomienky k v0.3) | podklad pre `0001_jadro.sql` |
| 2026-10-11 | Nákupné ceny zmluvy v tabuľke `contract_purchase` (produkt, rok dodávky, dátum nákupu, cena, odkaz do Cockpitu); zo `contract` odpadajú `purchase_price_*`. Nahrádza rozhodnutie „v CRM hodnota na zmluve“. | deal má dnes až 3 nákupné ceny; jedna tranža patrí až 32 dealom |
| 2026-10-11 | `product.pricing_model` (`fix`, `spot_aditiv`, `index_spot`) a `contract_price.additive_eur_mwh`; aditív sa pri migrácii oddelí z polí VT/NT podľa produktu | polia VT/NT v HubSpote pri SPOT produktoch nesú aditív |
| 2026-10-11 | Jeden enum `segment`: `domacnost`, `firma`, `dodavatel`. Drží ho zákazník (firma: `firma`/`dodavatel`, B2C kontakt: `domacnost`) a OOM; deal a zmluva ho preberajú. `komunal` → `firma`. Nahrádza segment dealu a zmluvy ako `text`. | jednotné reporty; ten istý človek môže byť domácnosť aj zástupca firmy |
| 2026-10-11 | IČO = text s 8 číslicami (úvodné nuly), čiastočný unikátny index | HubSpot ukladá IČO ako číslo a nuly stráca |
| 2026-10-11 | `deal.closed_at` = skutočné uzavretie; HubSpot close date (dnes dátum nákupu) → `contract_purchase.priced_on` | workflow „Close date = dátum nákupnej ceny“ |
| 2026-10-11 | `offer.total_eur` je zámerná snímka odoslanej ponuky | ponuka sa po odoslaní nemení |
| 2026-10-11 | Výpočtové pohľady (`contract_price_volume_v`, `contract_revenue_v`, `deal_margin_v`, `commission_base_v`) nie sú v `0001`; prídu samostatnou migráciou po inventári `products` a `formulas` a potvrdení rollupov. Rozhodnutia z 2026-10-10 o vstupoch a ročných hodnotách platia pre túto migráciu. | vzorce a rollupy nie sú overené |
| 2026-10-11 | Roly `externy_obchodnik` a `externy_dodavatel` sa rušia; externý obchodník má rovnaké práva ako interný. RLS sa nerobí. Nahrádza rozhodnutie o obmedzenom prístupe externých. | Peter |
| 2026-10-11 | Typ kontaktu sa zjednocuje so segmentom: `contact.type` nahrádza `contact.segment` (enum `segment`) | typ kontaktu a segment sú ten istý pojem |
| 2026-10-11 | Prototyp na prezeranie dát (modul 2) používa na `dev` vzorku 40 skutočných zákazníkov z HubSpotu vrátane osobných údajov domácností. Výnimka z pravidla modulu 1 „na `dev` iba vymyslené dáta“. Vzorka sa po skončení prototypu zmaže podľa manifestu. | kontrola modelu na skutočných dátach; hosting v EÚ (Neon Frankfurt), prístup iba Peter cez Cloudflare Access |
| 2026-10-11 | Frontend CRM: React + Vite + TypeScript (potvrdenie frameworku z CLAUDE.md) | rozšírený, vhodný aj pre zložité obrazovky (pipeline, editor ponuky) |
| 2026-10-11 | API: Cloudflare Worker s routerom Hono a ovládačom `postgres` (postgres.js) cez Hyperdrive | ľahký router; ovládač odporúčaný Cloudflare pre Hyperdrive |
| 2026-10-11 | Prototyp beží na predvolených adresách `*.workers.dev` a `*.pages.dev` za Cloudflare Access; vlastná doména neskôr | bez zmien DNS počas prototypu |
| 2026-10-11 | Frontend sa nenasadzuje na Cloudflare Pages, ale ako statické súbory toho istého Workera ako API (`crm-core`): `/api/*` ide do Workera, ostatné na frontend. Access cez „Protect this Worker behind Access“ (All traffic). Nahrádza „Frontend: Cloudflare Pages“ v CLAUDE.md a adresu `*.pages.dev` z rozhodnutia o adresách prototypu. | Access pre `pages.dev` sa nedá nastaviť pred existenciou projektu a vyžaduje dve pravidlá; jeden Worker = jedna doména, jedno pravidlo Access, bez CORS a medzivrstvy |
| 2026-10-11 | Prvé nasadenie Workera bez verejnej adresy (`workers_dev = false`); adresa `workers.dev` sa zapne až po zapnutí Access | skutočné osobné údaje nesmú byť ani chvíľu verejne dostupné |
