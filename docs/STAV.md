# Stav projektu

Aktualizované: 11. 10. 2026

## Hotové

- Plán náhrady HubSpotu (obnova 9. 7. 2027, rozhodnutie o záložnej variante 31. 5. 2027)
- Pravidlá projektu (`CLAUDE.md`)
- Repozitár `crm-core` a Claude Code vo VS Code
- Modul 0: inventár HubSpotu a Make scenárov (`docs/inventar/`), skript `integrations/hubspot-sync/inventory` (iba čítanie)
- Dátový model jadra v0.3.1 (`docs/01-datovy-model.md`) – schválený 11. 10. 2026
- Modul 1 na vetve `dev`: migrácie `0001_jadro` a `0002_pracovny_kalendar`, testy `db/test/run.sh` prešli (14 kontrol)

## Prebieha

- Modul 2: prototyp na prezeranie dát – kroky 1 (výber vzorky), 2 (nahratie na `dev`) 3 (rola iba na čítanie), 4 (API) a 6 (frontend) hotové lokálne

- Modul 1: databáza jadra – hotové na `dev`, čaká na nasadenie na `main` (Peter rozhodne, kedy; zatiaľ sa na `main` nič nespúšťa)

## Otvorené

- Opakované čísla zmlúv na dealoch (18 vo vzorke) vs. `contract.number` unikátne a 1 deal = 1 zmluva – rozhodnúť pred migráciou
- Smer zmluvných cien pri veľkoobchodných OOM (pole `typ_oom` prázdne)
- `customer_v`: B2C zákazník = kontakt bez firmy, ktorý vlastní OOM, deal alebo zmluvu (nie každý kontakt bez firmy)
- Po skončení prototypu zmazať vzorku z `dev` (`exports/prototyp/vzorka-delete.sql`)

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

- Modul 2 – prototyp (`docs/moduly/02-prototyp.md`): vzorka 44 zákazníkov nahratá na `dev`. Rola `crm_prototype_ro` hotová. API a frontend bežia lokálne (`api/dev.sh`, `web` → `npm run dev`). Ďalej nasadenie: Hyperdrive, Worker, Pages a Cloudflare Access.
- Nasadenie modulu 1 na `main` po Petrovom pokyne.
