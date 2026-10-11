Vizuálny jazyk Greenlogy CRM. Vychádza z aplikácie Greenlogy Cockpit, aby obe pôsobili ako jedna rodina: pokojné sivé pozadie, biele karty, jedna tmavozelená farba značky a čísla ako hlavná vec na obrazovke.

## Princípy

- **Dáta pred dekoráciou.** Obrazovka je pracovný nástroj pre 14 ľudí, ktorí v nej trávia celý deň. Žiadne ilustrácie, prechody farieb ani dekoratívne ikony.
- **Jedna hlavná vec na obrazovku.** Najdôležitejšie číslo alebo meno záznamu je v `kpi-xl` alebo `page-title`; všetko ostatné je tichšie.
- **Farba znamená stav.** `brand` je pre akciu a značku, `positive`, `negative`, `warning` a `info` iba pre stav. Stav sa vždy povie aj slovom alebo znamienkom (+, −), nikdy len farbou.
- **Zdroj je vždy viditeľný.** Pri číslach a dátach patrí do `caption` odkiaľ sú a kedy sa obnovili (rovnako ako „Odkiaľ sú dáta · ako aktualizovať“ v Cockpite).

## Obsah a jazyk

- Rozhranie je po slovensky, vykanie sa nepoužíva: tlačidlá v rozkazovacom spôsobe („Uložiť“, „Odoslať ponuku“, „Pridať OOM“).
- Malé písmená vo vetách, veľké len na začiatku: „Plnenie ročného plánu“, nie „Plnenie Ročného Plánu“.
- Čísla v slovenskom formáte: medzera ako oddeľovač tisícov, čiarka ako desatinná (`1 018,08 €`, `66 267,7 MWh`). Jednotka za číslom s medzerou. Ceny elektriny v `€/MWh`.
- Dátumy `8. 10. 2026`, v hlavičkách aj „8. októbra 2026 (štvrtok)“. Čas 24-hodinový.
- Odborné skratky tak, ako ich používa tím: OOM, EIC, FVE, SPOT, FIX, SLA. Bez emoji.

## Farby

- Pozadie stránky `surface-page`, karty a panely `surface-card` s okrajom `border` a tieňom `shadow-card`. Ľavé menu `surface-sidebar`.
- Text `ink`, popisy a štítky polí `ink-muted`. `ink-subtle` iba na placeholder, poradové čísla a ikony – nie na text, ktorý treba prečítať.
- Primárne tlačidlo je `brand` s textom `on-brand`; na obrazovke najviac jedno (napríklad „Odoslať ponuku“, „Cockpit PDF“). Ostatné akcie sú sekundárne tlačidlá.
- Stavové štítky: text `positive-strong` na `positive-tint`, `negative` na `negative-tint`, `warning` na `warning-tint`, `info` na `info-tint`.
- Kladné a záporné odchýlky: `positive` a `negative`, vždy so znamienkom.
- Grafy: série v poradí `chart-1` až `chart-6`; zelená `chart-1` je vždy hlavná séria alebo skutočnosť.
- Tmavý režim má každý token; prepína sa tlačidlom „Tmavý režim“ v spodnej časti menu ako v Cockpite.

## Typografia

- Jedna rodina `sans` = **Geist** (Google Fonts, rovnako ako Cockpit), `mono` = Geist Mono iba na EIC, ID a API cesty v štýle `code`.
- Základ aplikácie je `body` 14 px. Hierarchia: `page-title` 24 px → `section-title` 15 px → `body` 14 px → `label` a `caption` 12 px → `pill` a `group-label` 11 px.
- Čísla: `kpi-xl` raz na obrazovke, `kpi-lg` 22 px v KPI kartách, vždy s tabuľkovými číslicami (`font-variant-numeric: tabular-nums`). Pod číslom porovnanie v `caption`.
- Tabuľky: hlavička `label` (12 px, 500, `ink-muted`, bez verzálok), bunky `body`, názvy `body-strong`, čísla zarovnané doprava. Riadky oddelené `surface-muted`, pod hlavičkou `border`.
- Údaje v zoznamoch a kartách patria na jeden riadok: názov, kód a stav vedľa seba; dlhý text sa skráti trojbodkou, nezalamuje sa.

## Priestor, tvary a rozloženie

- Medzery z rady `space-1` až `space-6`: vnútro karty `space-5`, medzi kartami `space-4`, medzi sekciami `space-6`.
- Rohy: karty a bannery `radius-lg`, tlačidlá a polia `radius-md`, štítky a progres bary `radius-pill`.
- Rozloženie: ľavé menu ~232 px na `surface-card` s okrajom `border` (logo, skupiny v `group-label`, stav synchronizácie dole), obsah s okrajom 28 px hore a `space-page` po stranách, sekcie oddelené `space-6`. Vnútro karty 18 × 20 px. Hlavička stránky: vľavo `page-title` a popis, vpravo sekundárne akcie a jedno primárne tlačidlo.
- Filtre a prepínače (deň / mesiac / rok, roky) v bielej lište nad obsahom; segmentový prepínač so zvolenou položkou na `surface-muted` alebo `brand`.

## Stavy a interakcie

- Hover riadku tabuľky a položky menu `surface-muted`; aktívna položka menu `surface-muted` + `body-strong`.
- Fokus klávesnice: obrys 2 px `focus-ring`, odsadený 2 px.
- Načítavanie: kostra (sivé bloky `surface-muted`), nie točiace sa koliesko cez celú stránku.
- Prázdny stav: jedna veta v `ink-muted` a jedno tlačidlo na ďalší krok („Zatiaľ žiadne OOM – Pridať OOM“).

## Ikonografia

- Tenké obrysové ikony 16 px (v menu, ako Cockpit) a 14–16 px v tlačidlách, čiara 1,5 px, farba `ink-muted` alebo `ink`.
- Ikona nikdy nenesie význam sama; vždy je pri nej text alebo popis.
- Logo: zelený štvorec `brand` so zaoblením `radius-md` a bielym bleskom, vedľa „Greenlogy“ a pod ním názov aplikácie („CRM“). Súbor loga v systéme zatiaľ nie je – doplniť z repozitára Cockpitu.

## Komponenty

Náhľady komponentov ukazujú základné stavebné prvky: tlačidlo, štítok stavu, KPI kartu, tabuľku a položku menu. Obrazovky CRM (karta firmy, OOM, pipeline, ponuka) sa z nich skladajú.
