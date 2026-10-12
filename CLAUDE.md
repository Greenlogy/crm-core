# Greenlogy CRM (crm-core) – pravidlá projektu

Tento súbor Claude Code číta na začiatku každej session. Platí vždy, bez ohľadu na zadanie.

## O projekte

Vlastné CRM jadro Greenlogy a.s., ktoré nahrádza HubSpot. HubSpot sa k obnove 9. 7. 2027 nepredĺži.
Jadro je jediný zdroj pravdy o zákazníkoch, odberných miestach (OOM), zmluvách, cenách, dealoch, ponukách, províziách a komunikácii.
Ostatné systémy (Chatwoot, CloudTalk, Brevo, PostHog, Webflow, Cockpit, Make) sa naň napájajú cez API.

Vlastník projektu a schvaľovateľ: Peter Kalman (CEO). Kód píše Claude, Peter zadáva, kontroluje a schvaľuje.

## Spôsob práce (záväzné)

1. Komunikuj po slovensky.
2. Pred každou zmenou kódu najprv navrhni plán: čo zmeníš, v ktorých súboroch a prečo. Čakaj na Petrov súhlas.
3. Bez výslovného súhlasu nikdy nerob: commit, push, deploy, spustenie migrácie databázy, mazanie súborov alebo dát, zmenu tajomstiev a nastavení Cloudflare.
4. Pracuj v malých krokoch. Po každom kroku krátko zhrň, čo je hotové, a navrhni ďalší krok. Ďalej nepokračuj, kým Peter nepotvrdí.
5. Príkazy do terminálu dávaj vždy kompletné, vrátane `cd ~/projects/greenlogy/crm-core`.
6. Keď niečo nie je jasné, opýtaj sa. Obchodnú logiku nehádaj.
7. Dokumentácia sa vedie priebežne: po dokončení úlohy aktualizuj `docs/STAV.md`, `docs/CHANGELOG.md` a dokument modulu, ktorého sa zmena týka. Rozhodnutia zapisuj do `docs/rozhodnutia.md`.
8. Každý modul začína novou session a zadaním v `docs/moduly/`.
9. Existujúce súbory v `docs/` mení iba Claude Code. Od Clauda z chatu prichádzajú len nové súbory alebo pokyn „doplň do súboru X časť Y“. Ak by sa zmena z chatu predsa dotkla existujúceho súboru, pred commitom ju porovnaj s poslednou verziou v repozitári (`git diff`) a upozorni Petra na všetko, čo by sa zmazalo.

## Technológie

| Vrstva | Technológia |
| --- | --- |
| Databáza | PostgreSQL na Neone (EÚ, Frankfurt), vetvy `main` = produkcia a `dev` = vývoj. Migrácie dbmate v `db/migrations/` (`-- migrate:up` / `-- migrate:down`), `db/schema.sql` sa commituje. Migrácie najprv na `dev`, na `main` až po schválení. |
| API | Cloudflare Workers, TypeScript, napojenie na DB cez Cloudflare Hyperdrive |
| Frontend | React + Vite + TypeScript, servíruje ho ten istý Cloudflare Worker ako API (statické súbory, rozhodnutie 2026-10-11) |
| Prihlasovanie | Cloudflare Access so SSO cez Google, rovnako ako Cockpit; na Workeri „Protect this Worker behind Access“ (All traffic) |
| Servis | Chatwoot (self-host, Google Cloud) |
| Call centrum | CloudTalk (API a webhooky: hovory, nahrávky, prepisy, udalosti v reálnom čase) |
| E-mail marketing | Brevo |
| Web a analytika | Webflow + PostHog Cloud EU |
| Integrácie | Make (existujúce scenáre), webhooky jadra |
| Reporting | Greenlogy Cockpit číta z rovnakej databázy |

## Konvencie

- Identifikátory v kóde a databáze po anglicky: `snake_case` v DB, `camelCase` v TypeScripte. Texty v aplikácii po slovensky.
- Každá zmena štruktúry DB je nová číslovaná migrácia (`db/migrations/0001_nazov.sql`). Existujúce migrácie sa nemenia.
- Tajomstvá nikdy nepatria do repozitára: `wrangler secret`, lokálne `.dev.vars` (je v `.gitignore`).
- Osobné údaje: hosting iba v EÚ, osobné údaje sa nezapisujú do logov.
- Každá tabuľka s obchodnými dátami má `created_at`, `updated_at`; zmeny sa zapisujú do `audit_log`.
- Záznamy prevzaté z HubSpotu majú stĺpec `hubspot_id` kvôli synchronizácii a kontrole migrácie.
- Peniaze v `numeric(12,2)` (EUR), ceny elektriny v `numeric(12,4)` €/MWh, časy v `timestamptz` (UTC), zobrazenie v Europe/Bratislava.

## Štruktúra repozitára

```
crm-core/
  CLAUDE.md            pravidlá projektu (tento súbor)
  README.md            ako projekt spustiť
  docs/
    STAV.md            aktuálny stav a ďalší krok
    CHANGELOG.md       čo sa zmenilo a kedy
    rozhodnutia.md     prijaté rozhodnutia s dôvodmi
    01-datovy-model.md dátový model jadra
    moduly/            zadania jednotlivých modulov
  db/migrations/       SQL migrácie
  api/                 Cloudflare Worker (API jadra)
  web/                 frontend (React + Vite, nasadzuje sa s Workerom z api/)
  integrations/        hubspot-sync, chatwoot, cloudtalk, posthog, brevo
```

## Doménové pravidlá

- OOM (odberné miesto) má jedinečný EIC kód. Typ: spotreba, výroba, sharing alebo veľkoobchod. Stav: Aktívne, Neaktívne, Zrušené, Odídené, Prepísané.
- Kontakt sa s OOM prepája cez dealy: OOM sa priraďuje všetkým kontaktom na jeho dealoch, iba pri stave Aktívne alebo Neaktívne.
- Jeden zákazník môže mať viac OOM, vrátane FVE (výroba).
- SLA servisu na všetkých kanáloch: prvá reakcia do 8 pracovných hodín, odpoveď do 24 pracovných hodín. Počíta sa iba v pracovnom čase v pracovných dňoch podľa slovenského kalendára sviatkov. Pracovný čas: Po–Pi 7:30–15:30 (Europe/Bratislava). Príklad: správa prijatá v piatok o 15:00 má termín prvej reakcie v pondelok o 15:00.
- B2C zákazník je kontakt bez firmy. Zákazník (vlastník OOM, dealu, zmluvy) je teda buď firma, alebo kontakt – vždy práve jedno z nich.
- Trading book nie je súčasťou CRM. Žije v Cockpite a z HubSpotu sa nemigruje.

## Súvisiace systémy

- HubSpot portal `5964726` – zdroj dát až do prechodu. Custom objects: OOM `2-16666415`, Zmluvné ceny `2-16395301`, Nákupné ceny `2-22997964`, Trading book `2-17012865`.
- Greenlogy Cockpit: samostatné repozitáre `cockpit-*`, Cloudflare Pages + Workers + Access.
- GreenTrack: správa úloh tímu (Firebase PWA).
