# Dizajn Greenlogy CRM

Stav k 11. 10. 2026 (večer, doplnené obrazovky modulu Zákazníci). Zdroj: návrhy v projekte (plátno „Greenlogy CRM – karta firmy“) a dizajnový systém „Greenlogy CRM“.

## Ako to používať

- `system/README.md` – pravidlá vzhľadu (farby, písmo, rozostupy, stavy, jazyk). Záväzné pre každú obrazovku.
- `system/tokens.json` – presné hodnoty farieb (svetlý aj tmavý režim), písma, rozostupov, zaoblení a tieňov. Prevezmi ich ako CSS premenné, nevpisuj hodnoty ručne.
- `system/komponenty/` – tlačidlo, štítok stavu, KPI karta, tabuľka, položka menu: popis a náhľad.
- `obrazovky/` – statické návrhy obrazoviek. Otvoria sa priamo v prehliadači.

## Dôležité

- **Obrazovky sú predloha vzhľadu a rozloženia, nie špecifikácia logiky.** Dáta v nich sú vymyslené. Ktoré polia, stavy a pravidlá platia, určuje schválené zadanie modulu v `docs/moduly/`.
- Písmo: Geist (Google Fonts), kódy EIC a ID: Geist Mono. Farby a rozmery z Greenlogy Cockpitu.
- Rozloženie: ľavé menu 232 px, obsah s okrajom 24 × 36 px, karty s rohmi 12 px. Každý záznam v zozname na jednom riadku, dlhý text sa skráti.
- Modul Zákazníci (zadanie `docs/moduly/01-zakaznici.md` v0.2): obrazovky 08–10 a upravená 01. Menu: „Firmy“ sa mení na „Zákazníci“, pribudla položka „Leady“ (= filter Záujemca + Ponuka). Obrazovky 02–07 majú v menu ešte „Firmy“; upravia sa pri svojich moduloch.
- Karta firmy: KPI v jednom rade; vľavo údaje a FinStat, v strede časová os, vpravo kontakty, OOM, dealy, zmluvy (rozhodnutie z 10. 10. 2026).
- Časy SLA sa počítajú v pracovnom čase Po–Pi 7:30–15:30.

| Súbor | Obrazovka |
| --- | --- |
| `01-karta-firmy.html` | Karta firmy (zvolený variant B) |
| `02-karta-oom.html` | Karta odberného miesta |
| `03-karta-zmluvy.html` | Karta zmluvy |
| `04-pipeline-dealov.html` | Pipeline dealov (kanban) |
| `05-editor-ponuky.html` | Editor ponuky |
| `06-domov-obchodnik.html` | Domovská obrazovka obchodníka |
| `07-servis-sla.html` | Servis – SLA prehľad |
| `08-zoznam-zakaznikov.html` | Zoznam zákazníkov (firmy a domácnosti, filter podľa stavu) |
| `09-kontakty.html` | Kontakty (všetky osoby) a formulár Nová osoba s kontrolou duplicity |
| `10-karta-osoby.html` | Karta osoby – domácnosť (pôsobí vo firmách, vývoj stavu) |
