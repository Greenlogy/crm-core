# Modul 0 – Inventár HubSpotu

Stav: výstupy hotové (10. 10. 2026), čaká na schválenie `suhrn.md` a dátového modelu v0.3.

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

## Výsledok

- Skript: `integrations/hubspot-sync/inventory` (Node 24, bez závislostí, iba čítanie). Spustenie:
  `node integrations/hubspot-sync/inventory/inventory.ts --check | --collect [--only=…] [--refresh] | --render`.
  Surové dáta sa ukladajú do `exports/inventar/raw/` (mimo gitu).
- Výstupy: všetky súbory zo zoznamu vyššie + produkty, line items a vzorce vypočítaných polí v `objekty-a-vlastnosti.md`.
- `make-scenare.md` je písaný ručne z Make API (konektor, iba čítanie).
- Rozhodnutia: `docs/rozhodnutia.md` (10. 10. 2026).
- Mimo rozsahu: šablóny predajných e-mailov (nemajú API, texty sa prenesú ručne), slovný opis akcií jednotlivých workflowov (doplní modul, ktorý ich nahrádza).
