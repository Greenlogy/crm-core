# Modul 0 – Inventár HubSpotu

Stav: zadanie pripravené, čaká na spustenie.

## Cieľ

Zistiť presne, čo dnes v HubSpote máme, aby dátový model a migrácia nič nevynechali. Výstupom sú prehľadové súbory v `docs/inventar/`, nie zmeny v HubSpote.

## Pravidlá

- Iba čítanie. Do HubSpotu sa nič nezapisuje.
- Prístup cez HubSpot private app s read-only scopes. Token iba v `.dev.vars`, nikdy v repozitári.
- Do `docs/inventar/` ide iba štruktúra (názvy polí, typy, počty). Žiadne osobné údaje zákazníkov. Ak treba vzorku dát, ukladá sa do `exports/` (je v `.gitignore`).

## Čo zinventarizovať

1. Objekty a vlastnosti: companies, contacts, deals, tickets a custom objects OOM `2-16666415`, Zmluvné ceny `2-16395301`, Nákupné ceny `2-22997964`. Pre každú vlastnosť: interný názov, label, typ, možnosti (pri enumoch), počet vyplnených záznamov.
2. Asociácie medzi objektmi a ich typy (napr. `oom_to_deal`).
3. Pipelines a štádiá (dealy aj tickety) s počtom záznamov v každom štádiu.
4. Počty záznamov pre každý objekt, B2B vs. B2C (kontakty bez firmy).
5. Workflowy: názov, objekt, spúšťač, aktívny/neaktívny, stručne čo robí.
6. Šablóny e-mailov, sekvencie, šablóny ponúk (quotes).
7. Formuláre a ich polia.
8. Používatelia a tímy (iba mená a roly).
9. Make scenáre napojené na HubSpot: názov, čo robia, aktívny/neaktívny.
10. Marketingové súhlasy: aké typy odberu (subscription types) existujú a koľko kontaktov ich má.

## Výstupy

- `docs/inventar/objekty-a-vlastnosti.md`
- `docs/inventar/pipelines.md`
- `docs/inventar/workflowy-a-sablony.md`
- `docs/inventar/make-scenare.md`
- `docs/inventar/suhrn.md` – zhrnutie a návrh úprav dátového modelu (v0.3)

## Hotové, keď

Peter schváli `suhrn.md` a dátový model v0.3.
