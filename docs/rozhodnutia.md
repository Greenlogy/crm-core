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
