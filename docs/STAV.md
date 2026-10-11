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

- Modul 1: databáza jadra – hotové na `dev`, čaká na nasadenie na `main` (Peter rozhodne, kedy; zatiaľ sa na `main` nič nespúšťa)

## Otvorené

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

- Prototyp na prezeranie dát (iba čítanie, iba `dev`): vzorka 40 zákazníkov z HubSpotu, API (Worker + Hyperdrive), frontend (Pages, 4 obrazovky), Cloudflare Access. Postup po krokoch so schválením každého kroku.
- Nasadenie modulu 1 na `main` po Petrovom pokyne.
