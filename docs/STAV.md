# Stav projektu

Aktualizované: 12. 10. 2026 (neskoro večer)

## Hotové

- Plán náhrady HubSpotu (obnova 9. 7. 2027, rozhodnutie o záložnej variante 31. 5. 2027)
- Pravidlá projektu (`CLAUDE.md`)
- Repozitár `crm-core` a Claude Code vo VS Code
- Modul 0: inventár HubSpotu a Make scenárov (`docs/inventar/`), skript `integrations/hubspot-sync/inventory` (iba čítanie)
- Dátový model jadra v0.3.1 (`docs/01-datovy-model.md`) – schválený 11. 10. 2026
- Modul 1 na vetve `dev`: migrácie `0001_jadro` a `0002_pracovny_kalendar`, testy `db/test/run.sh` prešli (14 kontrol)

## Prebieha

- Modul 0 Nastavenia: návrh databázy schválený (v0.2). Test (`dev`) vyprázdnený, rola `crm_prototype_ro` zrušená, migrácie `0006_nastavenia_jadro`, `0007_nastavenia_obsah`, `0008_zakaznici_spolocnost` spustené na `dev` (Peter, 12. 10.), testy `db/test/run.sh` prešli (88 kontrol). Na Teste: 3 spoločnosti, 6 tímov, admini Peter a Eva, kalendár SK 2026–2028, žiadne dáta zákazníkov. Na `main` zatiaľ nie. Prototyp (Worker `crm-core`) po zrušení roly nefunguje – nahradí ho nové API.
- **Modul 1 Zákazníci uzavretý** (Peter, 12. 10. 2026): F1–F4 na Teste (commity `7b40c4c`, `527992a`), zadanie v0.4 s časťou 15. Na `main` (Ostré) zatiaľ nie.
- **Modul 2 Odberné miesta – databáza hotová na `dev`:** návrh v0.4 (`docs/moduly/02-odberne-miesta-navrh-db.md`), migrácie `0013`–`0015` (Peter, 12. 10.), testy prešli (108 kontrol), prepínač `customer_status_auto` na `dev` zapnutý (na `main` vypnutý do modulu Zmluvy), Cron dennej aktivácie na Teste. OOM má „iba svoje“ v databáze; externý tím ostáva zamknutý, kým RLS nemajú dealy a zmluvy.
- Modul 2: prototyp na prezeranie dát – kroky 1 (výber vzorky), 2 (nahratie na `dev`) 1–7 hotové, prototyp nasadený za Cloudflare Access

- Modul 1: databáza jadra – hotové na `dev`, čaká na nasadenie na `main` (Peter rozhodne, kedy; zatiaľ sa na `main` nič nespúšťa)

## Otvorené

- **Podmienka odomknutia externého tímu** (`crm_external_ready`): okrem RLS na dealoch a zmluvách aj RLS na `audit_log` – dnes ho prihlásený používateľ vie čítať celý, vrátane zmien cudzích záznamov (Peter 12. 10.)
- IČO PDS v číselníku (ZSD, SSD, VSD, SLOVNAFT, JAVYS) doplnené z pamäti – Peter overí vo FinState / ORSR; ostatné miestne DS bez IČO
- C2-X3 pri miestnych DS (18 OOM) a X3-C2 pri miestnych DS (3 OOM): do číselníka nedané (pravidlo iba ZSD / iba VSD) – potvrdiť pri nahrávaní
- **Pred Ostrým:** CRM pri pozvaní a deaktivácii externého používateľa samo pridá / odoberie e-mail v skupine Cloudflare Access „CRM externí“ (dovtedy ručne); treba API token s právom iba na skupiny a relácie Access
- Prototyp (Worker `crm-core`) nefunguje od zrušenia roly `crm_prototype_ro` (12. 10.); Hyperdrive `crm-core-dev` ešte ukazuje na zrušenú rolu – prepojí sa na rolu `crm_app`
- `db/dbmate.sh`: dbmate vypíše „Applied“ aj pri migrácii, ktorá potom zlyhá a vráti sa – zvážiť kontrolu stavu po migrácii (pred Ostrým)
- Zistiť v Neon (Monitoring / Operations), kto alebo čo 12. 10. zmazalo vetvu `dev`; ak nie automatická expirácia, preveriť prístupy k projektu
- Neon free plán: Hyperdrive drží spojenie na `dev` a výpočet sa neuspáva (limit 100 CU-hodín/mesiac) – sledovať Billing / Usage
- Opakované čísla zmlúv na dealoch (18 vo vzorke) vs. `contract.number` unikátne a 1 deal = 1 zmluva – rozhodnúť pred migráciou
- Smer zmluvných cien pri veľkoobchodných OOM (pole `typ_oom` prázdne)
- `customer_v`: B2C zákazník = kontakt bez firmy, ktorý vlastní OOM, deal alebo zmluvu (nie každý kontakt bez firmy)

- Prenos nákupných cien z Cockpitu (zdieľaná DB alebo API)
- Potvrdiť definície rollupov v HubSpote (objemy, výnosy)
- Mapovanie produktov na jeden katalóg
- Archív exportu historických ticketov
- Výpočtové pohľady (výnosy, marža, provízie) – samostatná migrácia po potvrdení rollupov v HubSpote
- Pred migráciou dát vyriešiť IČO: 2 duplicity (4 firmy) a 1 hodnota s 10 číslicami
- Mapovanie typov kontaktu `vyrobca`, `partner_predaj`, `partner_sluzby` na segment (modul migrácie)
- Pracovný kalendár na rok 2029 doplniť novou migráciou najneskôr v roku 2028 (a pri každej zmene zákona o sviatkoch)
- Bezpečnosť Make: HubSpot token vpísaný v scenároch Sales portálu, webhook bez overenia (odložené)

## Ďalší krok

- Modul 2 Odberné miesta: F1 na Teste; F2a (stav, prepis, návrat, plánované zmeny, migrácia `0016`, nočný beh `oom_daily_run`) hotová. Ďalej F2b (založenie a úprava OOM, kroky prechodu), potom F2c (zariadenia, kontakty, mazanie, Nastavenia), F3, F4. Testovacie dáta `db/test-data/oom-test.sh dev vytvor|zmaz|beh RRRR-MM-DD`.
- Modul 0 Nastavenia: kroky A–C hotové na Teste (12. 10.): rola `crm_app` (migrácia 0009), Hyperdrive `crm-core-dev` → `crm_app` s vypnutou cache, Worker nasadený s prihlásením (overenie tokenu Access + používateľ CRM); `/api/me` overené (Peter: CEO, admin, 3 spoločnosti). Ďalej: v Access povoliť @greenlogy.com (Google), potom obrazovky Nastavení (11–16) a zápis v API.
- Obrazovky Nastavení: fáza 1 na Teste (commit `70c2099`). Fázy 2–6 napísané a lokálne overené (API aj obrazovky): Používatelia (pozvanie s textom pozvánky, úprava, deaktivácia s odovzdaním), Tímy a práva (matica, nový tím, archív), Spoločnosť (údaje, logo, bankové účty, pracovný čas, firemné voľno), Číselníky, Vlastné polia (typy, hodnoty výberu, sekcie, tímy, archív), Pipelines a stage (poradie, pravdepodobnosť, typ, povinné polia), Audit (filtre, stránkovanie). Nová migrácia `0010_work_hours_delete`. Na Teste (12. 10.): migrácia 0010, práva roly, nasadenie; Peter overil, všetko funguje.
- Modul 2 – prototyp (`docs/moduly/02-prototyp.md`): vzorka 44 zákazníkov nahratá na `dev`. Rola `crm_prototype_ro` hotová. Prototyp beží na https://crm-core.peter-700.workers.dev (Access, iba Peter). Ďalej krok 8: Peter prezrie vzorku a zapíše zistenia.
- Nasadenie modulu 1 na `main` po Petrovom pokyne.
