# Greenlogy CRM – dizajnová špecifikácia

**Smer:** „Krajina moderná A – firemné farby v jemných odtieňoch“
**Stav:** schválené Petrom Kalmanom, 16. 10. 2026
**Rozsah zmeny:** iba vzhľad. Obsah, polia, texty a funkcie obrazoviek (moduly 0–5) sú schválené a **nemenia sa**.

Referencie: `reference/*.html` (statické HTML 5 obrazoviek) a `screenshots/*.png` (desktop 1440 px a mobil 390 px). Keď sa táto špecifikácia a referenčné HTML líšia, platí referenčné HTML.

---

## 1. Princípy

1. **Dáta pred dekoráciou.** Jediný dekoratívny prvok je krajina v hlavičke. Všetko ostatné sú čisté biele karty, čísla a stavy.
2. **Jemné firemné farby.** Plná zelená `#05d695` a modrá `#13689e` z manuálu sa používajú len v logu, tenkých linkách, grafoch a modrá aj v texte. Plochy sú vo svetlých odtieňoch (`*-50`), aby farby „nebili do očí“.
3. **Jedna hlavná vec na obrazovke.** Na úvodnej stránke je to cena 2027 a odhad provízie, na detaile obchodu pridaná hodnota. Najviac jedno primárne tlačidlo na obrazovku.
4. **Farba znamená stav, nikdy nie sama.** Každý stav má aj slovo („po termíne“, „Aktívne“) alebo znamienko (−424,00).
5. **Slovenský formát čísel:** medzera ako oddeľovač tisícov, čiarka desatinná, jednotka za medzerou: `1 625,92 €`, `252,0 MWh`, `106,00 €/MWh`. Vždy `font-variant-numeric: tabular-nums` a čísla v tabuľkách zarovnané doprava.

---

## 2. Farby

Všetky hodnoty sú v `tokens/tokens.css`. Kontrast je overený voči WCAG AA.

### Značka a jemné odtiene

| Token | Hex | Použitie | Kontrast |
|---|---|---|---|
| `--gl-brand-green` | `#05d695` | logo, akcentové linky, bodka stavu „online“ | **nie na text** (1,9:1) |
| `--gl-brand-blue` | `#13689e` | odkazy, zvýraznené čísla (provízia, pridaná hodnota), meno v pozdrave | 6,0:1 na bielej |
| `--gl-blue-600` | `#2f78ab` | primárne tlačidlo, zvolený filter | biely text 4,8:1 |
| `--gl-blue-50` | `#e6f0f7` | aktívna položka menu, štítok „info“, avatar B2B | modrý text 5,2:1 |
| `--gl-blue-100/200` | `#cfe2ef` / `#9cc3dd` | okraj sekundárneho tlačidla / hover | – |
| `--gl-blue-400` | `#5a9bc9` | 2. séria grafu | 3,0:1 (grafika) |
| `--gl-green-400` | `#2fd09c` | hlavná séria grafu, akcentová linka pod číslom, dokončené štádium | grafika s popiskom |
| `--gl-green-700` | `#0b7a57` | zelený text (štítky OK, popisok hlavnej KPI) | 5,3:1 |
| `--gl-green-50` | `#e3f8f0` | podklad štítku OK, avatar B2C | zelený text 4,8:1 |

### Neutrálne

| Token | Hex | Použitie |
|---|---|---|
| `--gl-ink` | `#1d3a4f` | hlavný text a čísla (11,9:1) |
| `--gl-ink-2` | `#3f5868` | text priamo na krajine (6,2:1 na oblohe) |
| `--gl-ink-muted` | `#5c7080` | štítky, popisy, hlavičky tabuliek (5,1:1) |
| `--gl-neutral-400` | `#a9b7c2` | 3. séria grafu, neaktívne body (nie text) |
| `--gl-surface-page` | `#f4f8f8` | pozadie stránky |
| `--gl-surface-card` | `#ffffff` | karty |
| `--gl-surface-hover` | `#f6fafb` | hover riadku |
| `--gl-surface-shade` | `#f3f8fb` | zvýraznený stĺpec („Marža firmy“) |
| `--gl-border` / `-strong` / `--gl-divider` | `#e4eef0` / `#d6e4ea` / `#f0f5f6` | okraje kariet / polí / oddeľovače riadkov |

### Stavy (podklad + text)

| Stav | Podklad | Text | Príklady |
|---|---|---|---|
| OK | `#e3f8f0` | `#0b7a57` | Zákazník, Aktívne, Účinná, Akceptované, bez výstrah |
| Info | `#e6f0f7` | `#13689e` | Čakajúci zákazník, Pripravované, Podpísaná, Vyjednávanie, Otvorená 3× |
| Varovanie | `#fff3df` | `#94500c` | Ponuka, dnes, Končí do 4 mesiacov, prechod sa zasekol, Schvaľovanie (počet) |
| Chyba | `#fdebe9` | `#b42318` | po termíne, Vyprší dnes, Odídené, Bývalý zákazník, Pod hranicou bez výnimky |
| Neutrálny | `#eef2f4` | `#55697a` | zajtra, Záujemca, Nahradená, Skončená, NN |

### Prechody (iba tieto)

- `--gl-gradient-soft` `#c9f3e3 → #cfe3f1` (135°): **jedna** hlavná KPI dlaždica na obrazovke (cena 2027, pridaná hodnota obchodu).
- `--gl-gradient-calc` `#eaf8f2 → #e7f1f8` (160°): kalkulačka provízie.
- `--gl-hero-sky`: obloha za krajinou.
- `--gl-brand-gradient` `#05d695 → #13689e`: **iba** logo v menu.

---

## 3. Typografia

- **Písmo:** Lexend (Google Fonts) ako náhrada za **Campton** z design manuálu. Ak firma získa webovú licenciu na Campton (súbory .woff2), stačí zmeniť `--gl-font-sans`.
- **Mono:** Geist Mono pre EIC, čísla zmlúv a ponúk (`24ZSS4100078132P`, `1120262053`, `P26-000123/2`).
- Rezy podľa manuálu: Light 300 (popisy, metadáta), Regular 400 (text), Medium 500 (názvy v zoznamoch, tlačidlá), SemiBold 600 (nadpisy a čísla). Bold 700 sa nepoužíva.

| Rola | Veľkosť / váha | Poznámka |
|---|---|---|
| Pozdrav na úvodnej stránke | 48 / 600, −0,03em | meno v `--gl-brand-blue` |
| Nadpis podstránky (h1) | 44 / 600, −0,03em | na krajine |
| Nadpis karty (h2) | 19 / 600 | |
| Hlavné číslo (provízia) | 54 / 600 | `--gl-brand-blue`, pod ním zelená linka 56×5 px |
| Hlavná KPI | 42 / 600 | |
| KPI | 30–32 / 600 | jednotka 14 / 400 muted |
| Text, bunky tabuliek | 14 / 400 | |
| Malý text | 13 | |
| Popis, metadáta, pätička | 12 / 300 muted | |
| Hlavička tabuľky | 12 / 400 muted | bez verzálok |
| Položka menu | 11 / 400 (aktívna 500) | |

---

## 4. Priestor, tvary, tiene

- **Zaoblenia:** tlačidlá, vyhľadávanie, štítky a filtre 999 px · polia formulára 12 · položka menu a dátumová dlaždica 14 · karta ponuky 16 · sklenená lišta 20 · karty 22 · hlavička 28.
- **Medzery:** odstup stránky `20px 28px 48px 12px` (vľavo je menu 88 px) · medzi sekciami 20–22 · v mriežke dlaždíc 12 · vnútro karty 22–26 · bunky tabuľky 12, prvá a posledná 24.
- **Tieň karty:** `0 1px 2px rgba(29,58,79,.04), 0 12px 32px -20px rgba(29,58,79,.22)`.
- **Sklo:** `rgba(255,255,255,.62–.66)` + `backdrop-filter: blur(18px) saturate(1.3)` + okraj `rgba(255,255,255,.85)` + tieň `0 10px 30px -14px rgba(19,104,158,.28)`.

---

## 5. Kostra obrazovky

```
┌──────┬──────────────────────────────────────────────────────────┐
│ menu │  HLAVIČKA S KRAJINOU (radius 28)                          │
│ 88px │   nadpis + podnadpis vľavo · tlačidlá vpravo              │
│      │   (slnko, turbíny a panely sú v strede, nič ich nezakrýva)│
│      │  ┌──── sklenená lišta / dlaždice, prekryv −88 px ───────┐ │
│      │  └──────────────────────────────────────────────────────┘ │
│      │  obsah: biele karty, tabuľky, grafy                       │
└──────┴──────────────────────────────────────────────────────────┘
```

### 5.1 Bočné menu (rail)
- Šírka 88 px, priehľadné pozadie (splýva so stránkou), položky pod sebou: ikona 18 px (obrys 1,6) + popisok 11 px.
- Poradie: logo · Domov · Zákazníci · Kontakty · OOM · Obchody · Ponuky · Schvaľ. (odznak s počtom) · Zmluvy · Provízie · Cenníky · Viac · (medzera) · Nastavenia · stav synchronizácie / prostredia.
- Aktívna položka: podklad `--gl-blue-50`, text `--gl-brand-blue`, váha 500, `aria-current="page"`.
- Servis a Marketing sú pod „Viac“.

### 5.2 Hlavička s krajinou
- Grafika: `assets/landscape-hero.svg`, vložená inline, `preserveAspectRatio="xMidYMax slice"`. **Tvary, farby, slnko, turbíny ani panely sa nemenia.**
- Výška: úvodná stránka 320 px, podstránky 270 px (detail obchodu 290 px).
- Text na krajine: nadpis `--gl-ink`, podnadpis a drobný text `--gl-ink-2`.
- Lopatky turbín sa pomaly otáčajú (9 s, 11 s, 8 s). Pri `prefers-reduced-motion` stoja.

### 5.3 Prvok prekrývajúci krajinu (vždy jeden)
| Obrazovka | Čo prekrýva krajinu |
|---|---|
| Úvodná stránka | 5 cenových dlaždíc zo skla; cena 2027 je `--gl-gradient-soft` |
| Zoznamy (Zákazníci, OOM, Zmluvy) | sklenená lišta so stavovými filtrami (+ varovné filtre vpravo) |
| Detail obchodu | sklenená lišta so štádiami obchodu + „Prehraté…“ |

### 5.4 Zoznam (Zákazníci, Odberné miesta, Zmluvy)
1. Hlavička: názov (44 px), podnadpis (počet alebo popis), vpravo sekundárne tlačidlo (Export / Import) + jedno primárne („Nový zákazník“, „Nové odberné miesto“, „Import z Office portálu“).
2. Sklenená lišta: stavové filtre ako zaoblené čipy s počtom. Zvolený čip je `--gl-blue-600` s bielym textom. Varovné filtre (napr. „Prechod sa zasekol 4“, „Končí do 4 mesiacov 14“) sú vpravo v podfarbení stavu.
3. Karta s tabuľkou: v hornom paneli zaoblené vyhľadávanie (lupa vľavo) a výbery (Segment, Vlastník, Typ, PDS…). Pod ním tabuľka a pätička so stránkovaním alebo vysvetlivkou.
4. Riadky: prvý stĺpec obsahuje avatar alebo ikonu typu (36 px, radius 12) a názov (500) s druhým riadkom (12/300 muted). Kódy sú v mono písme.

### 5.5 Detail (Obchod)
1. Hlavička: drobčeková navigácia, názov, štítky (stav, pipeline), firma · vlastník, vpravo „Poslať e-mail“, „Ďalší krok“ a primárne „Otvoriť ponuku“.
2. Sklenená lišta so štádiami: hotové štádium má zelenú bodku `--gl-green-400` s fajkou, aktuálne je modrý kruh s bielym okrajom (`aria-current="step"`), budúce sú prázdne krúžky.
3. Rad KPI kariet: Objem · Pridaná hodnota (soft gradient) · Odhad provízie (modré číslo) · Ďalší krok (červená karta, ak je po termíne).
4. Dve dvojice kariet: Odberné miesta (tabuľka) a Ponuky (karty ponúk, aktuálna na `#eaf3f9`); Časová os a Údaje obchodu (zoznam dvojíc dt/dd).

### 5.6 Úvodná stránka (Domov obchodníka)
Krajina s pozdravom a vyhľadávaním „Overiť firmu“ + „Nový obchod“ → 5 cenových dlaždíc zo skla → vľavo graf „Vývoj ceny pre obchodníka“ a „Moje ďalšie kroky“, vpravo „Kalkulačka provízie“ (`--gl-gradient-calc`) a „Moje ponuky“.

---

## 6. Komponenty (prehľad)

Hotové CSS je v `styles/components.css` (triedy `gl-*`).

- **Tlačidlá:** výška 44 px (malé 36), plne zaoblené. Sekundárne je biele s okrajom `--gl-blue-100`, primárne `--gl-blue-600` s bielym textom. Ikona 18 px vľavo.
- **Vyhľadávanie:** zaoblené pole s lupou vľavo, výška 44 px.
- **Polia formulára:** radius 12, výška 44 px, čísla zarovnané doprava, štítok nad poľom 12 px muted.
- **Čipy (filtre):** zaoblené, výška 38 px, počet za textom v 300 muted. `aria-pressed` určuje zvolený stav.
- **Štítky stavov:** 12 px / 500, zaoblené, voliteľná bodka 6 px.
- **Karty:** biele, okraj `--gl-border`, radius 22, tieň karty. Nadpis karty 19/600, odkaz „Všetky …“ vpravo 13 px.
- **Dátumová dlaždica (ďalšie kroky):** 46 × 46 px, radius 14, deň 17/600 a mesiac 10 px, podfarbená podľa naliehavosti (po termíne červená, dnes oranžová, neskôr modrá).
- **Časová os:** ikonová dlaždica 34 px (radius 12) podfarbená podľa typu udalosti a dva riadky textu.
- **Grafy:** čiary 2,5 px (hlavná 3,5 px), hlavná séria `--gl-chart-1` s jemnou plochou pod ňou (22 % → 0 %). Mriežka `#edf3f5`, os `#d6e4ea`, popisky osí 11 px muted. **Každá séria má na konci popisok s hodnotou**, pretože zelená čiara má nízky kontrast. Legenda vpravo hore.

---

## 7. Prístupnosť

- Kontrast textu ≥ 4,5:1 (overené v tabuľkách vyššie). Zelenú `#05d695` ani `#2fd09c` nikdy nepoužívajte na text.
- Viditeľný fokus: obrys 2 px `#2f78ab`, odsadenie 2 px.
- Dotykové ciele ≥ 44 px (tlačidlá, polia), čipy 38 px.
- Ikony sú vždy s textom alebo `aria-label`. Grafika krajiny má `aria-hidden="true"`, grafy `role="img"` + `aria-label` so zhrnutím.
- Animácia turbín rešpektuje `prefers-reduced-motion`.

---

## 8. Mobil (do 760 px)

- Bočné menu sa mení na **spodnú lištu** (pevná, sklenená, vodorovne posúvateľná, položky min. 64 px). Logo a stav synchronizácie sú skryté.
- Hlavička: min. 230 px, nadpis 32 px, tlačidlá sa zalomia pod nadpis. Prekrývajúci prvok zasahuje do krajiny len −40 px.
- Dlaždice a karty sa skladajú pod seba (mriežky používajú `auto-fit`). Tabuľky sa posúvajú vodorovne vo svojom boxe, stránka sa nikdy neposúva do strany.
- Spodný odstup obsahu 96 px kvôli spodnej lište.

Pozri `screenshots/*-mobil.png`.

---

## 9. Mapovanie zo starého design systému (Cockpit/CRM v1)

| Starý token | Starý hex | Nový token |
|---|---|---|
| brand | `#1a6b4a` | `--gl-blue-600` (akcie) / `--gl-green-400` (grafika) |
| brand-text | `#155a3d` | `--gl-green-700` alebo `--gl-brand-blue` |
| brand-tint | `#e8f2ee` | `--gl-green-50` |
| surface-page | `#f6f7f8` | `--gl-surface-page` `#f4f8f8` |
| ink | `#0f172a` | `--gl-ink` `#1d3a4f` |
| ink-muted | `#64748b` | `--gl-ink-muted` `#5c7080` |
| border | `#e7e9ec` | `--gl-border` `#e4eef0` |
| info | `#2f62c8` | `--gl-info-fg` `#13689e` |
| warning | `#b45309` | `--gl-warn-fg` `#94500c` |
| negative | `#b42318` | `--gl-danger-fg` (bez zmeny) |
| chart-1/2/3 | `#1a6b4a` / `#2f6fdb` / `#e8a317` | `--gl-chart-1/2/3` |
| font Geist | – | Lexend (text), Geist Mono (kódy) |
| radius-md / lg | 8 / 12 | tlačidlá 999 · polia 12 · karty 22 |

---

## 10. Čo sa NEMENÍ

- Obsah, polia, texty, poradie sekcií a funkcie všetkých obrazoviek (moduly 0–5).
- Krajina v hlavičke (`assets/landscape-hero.svg`).
- Logika, API, dáta, oprávnenia (napr. stĺpec „Marža firmy“ zostáva viditeľný iba pre CEO, Nákup, Marketing a obchodného riaditeľa).
