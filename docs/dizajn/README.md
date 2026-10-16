# Dizajn Greenlogy CRM

Stav k 13. 10. 2026 (doplnené obrazovky modulu Produkty a cenníky 20–24). Zdroj: návrhy v projekte (plátno „Greenlogy CRM – karta firmy“) a dizajnový systém „Greenlogy CRM“.

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
- Modul 0 Nastavenia (zadanie `docs/moduly/00-nastavenia.md` v0.2): obrazovky 11–16. Nastavenia majú vlastné vnútorné menu (Spoločnosť, Používatelia, Tímy a práva, Číselníky, Vlastné polia, Pipelines a stage, Audit); položka Nastavenia je dole v hlavnom menu. Obrazovka Číselníky nie je nakreslená – použije rovnaký vzor ako Vlastné polia (zoznam + panel úpravy). Údaje firmy v hranatých zátvorkách sú zástupné.
- Modul 2 Odberné miesta (zadanie `docs/moduly/02-odberne-miesta.md` v0.2): obrazovky 17–19. Platia namiesto staršej `02-karta-oom.html`. Karta OOM ukazuje históriu väzieb na zákazníkov s časovým rezom k dátumu a postup prechodu k Greenlogy; import z Excelu ukazuje náhľad (nové / zmena / chyba).
- Modul 3 Produkty a cenníky (zadanie `docs/moduly/03-produkty.md` v0.3, hotové – fázy F1–F3): obrazovky 20–24. Hlavné menu: položka **Cenníky** (pod Zmluvami, vidia ju všetci vrátane externých); obrazovky 20–23 majú záložky Cenníky / Produkty / Programy (adresy `/cenniky`, `/cenniky/produkty`, `/cenniky/programy`, detail `/cenniky/:id?verzia=`). Nastavenia majú novú položku **Párovanie sadzieb** (obrazovka 24, iba admin, za Číselníkmi). Odchýlky implementácie od návrhu: stĺpce „Zmluvy s cenou z cenníka“ (20, 23) a „prejde X zmlúv“ (21) sú skryté do modulu 4; detail cenníka ukazuje stĺpce podľa obsahu verzie (VBattery, VIWA a Poplatky B2B bez VT/NT); tlačidlo „Upraviť“ na obrazovke 24 je pri názve skupiny a úprava sa robí po produktoch (zaškrtávacie políčka sadzieb pre každý rozsah PDS); úpravy cien, kópia, schválenie s náhľadom, ukončenie a nový produkt sú bočné panely (vzor Vlastných polí). Ceny s DPH počíta databáza, čísla v sk-SK (€/MWh 4 desatinné miesta, mesačné sumy 2, pri presnejšej cene 4).
- Karta firmy: KPI v jednom rade; vľavo údaje a FinStat, v strede časová os, vpravo kontakty, OOM, dealy, zmluvy (rozhodnutie z 10. 10. 2026).
- Časy SLA sa počítajú v pracovnom čase Po–Pi 7:30–15:30.

| Súbor | Obrazovka |
| --- | --- |
| `01-karta-firmy.html` | Karta firmy (zvolený variant B) |
| `02-karta-oom.html` | Karta odberného miesta (starší návrh, nahradená 18) |
| `03-karta-zmluvy.html` | Karta zmluvy |
| `04-pipeline-dealov.html` | Pipeline dealov (kanban) |
| `05-editor-ponuky.html` | Editor ponuky |
| `06-domov-obchodnik.html` | Domovská obrazovka obchodníka |
| `07-servis-sla.html` | Servis – SLA prehľad |
| `08-zoznam-zakaznikov.html` | Zoznam zákazníkov (firmy a domácnosti, filter podľa stavu) |
| `09-kontakty.html` | Kontakty (všetky osoby) a formulár Nová osoba s kontrolou duplicity |
| `10-karta-osoby.html` | Karta osoby – domácnosť (pôsobí vo firmách, vývoj stavu) |
| `11-nastavenia-spolocnost.html` | Nastavenia – Spoločnosť (údaje do dokumentov, logo, pracovný čas) |
| `12-nastavenia-pouzivatelia.html` | Nastavenia – Používatelia (pozvanie, deaktivácia s odovzdaním zákazníkov) |
| `13-nastavenia-timy-a-prava.html` | Nastavenia – Tímy a práva (matica modulov) |
| `14-nastavenia-vlastne-polia.html` | Nastavenia – Vlastné polia (polia jadra zamknuté) |
| `15-nastavenia-pipelines.html` | Nastavenia – Pipelines a stage (ukážka) |
| `16-nastavenia-audit.html` | Nastavenia – Audit |
| `17-oom-zoznam.html` | Odberné miesta – zoznam (filter stavov, „Prechod sa zasekol“) |
| `18-oom-karta.html` | Karta OOM (komu patrí v čase, prechod, zariadenia) |
| `19-oom-import.html` | Import OOM z Excelu – náhľad a kontrola |
| `20-cenniky.html` | Cenníky – zoznam s platnou a budúcou verziou (modul 3) |
| `21-cennik-detail.html` | Detail cenníka – položky verzie bez DPH a s DPH, verzie, schválenie |
| `22-produkty.html` | Produkty – katalóg (kategória, sadzby, DPH, cenové modely, stav) |
| `23-programy.html` | Programy – VBattery a Green VIWA s parametrami balíkov |
| `24-nastavenia-parovanie-sadzieb.html` | Nastavenia – Párovanie sadzieb (produkt ↔ sadzba podľa PDS, ukážka) |

## Nahradené novým vzhľadom (16. 10. 2026)

Od 16. 10. 2026 platí pre vzhľad `docs/design-handoff/` (DESIGN_SPEC.md, tokeny, komponenty, referenčné obrazovky 01–05). Hodnoty z `system/tokens.json` sa už nepoužívajú. Obrazovky v `obrazovky/` ostávajú predlohou rozloženia a obsahu jednotlivých modulov.
