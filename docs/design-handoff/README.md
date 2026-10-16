# Greenlogy CRM – podklady na zmenu dizajnu

Schválený smer: **„Krajina moderná A – firemné farby v jemných odtieňoch“** (16. 10. 2026).

## Ako to použiť
1. Skopírujte celý priečinok do repozitára CRM, napr. do `docs/design-handoff/`.
2. Otvorte Claude Code v repozitári a vložte text zo súboru **`CLAUDE_CODE_PROMPT.md`**.
3. Claude Code najprv pošle plán. Po jeho schválení prerába vzhľad po krokoch a každú obrazovku porovnáva so screenshotmi.

## Obsah
| Súbor | Čo to je |
|---|---|
| `CLAUDE_CODE_PROMPT.md` | hotové zadanie pre Claude Code (pravidlá + postup) |
| `DESIGN_SPEC.md` | úplná špecifikácia: farby s kontrastmi, písmo, rozmery, komponenty, rozloženia, mobil, prístupnosť, mapovanie starých tokenov |
| `tokens/tokens.css` | dizajnové tokeny ako CSS premenné (jediný zdroj hodnôt) |
| `tokens/tokens.json` | tie isté tokeny v JSON (pre design systém alebo iné nástroje) |
| `tokens/tailwind.theme.js` | rozšírenie témy, ak appka používa Tailwind |
| `styles/components.css` | hotové CSS komponentov (`gl-*`): menu, hlavička, sklo, karty, tlačidlá, polia, čipy, štítky, tabuľky, KPI, štádiá, časová os, mobil |
| `assets/landscape-hero.svg` | krajina do hlavičky (schválená, nemeniť) |
| `assets/logo-mark.svg` | dočasná značka do menu (nahraďte oficiálnym symbolom z manuálu, ak ho máte v SVG) |
| `assets/brand/Design_manual_Greenlogy_2021.pdf` | firemný design manuál |
| `reference/01–05*.html` | 5 referenčných obrazoviek ako statické HTML (otvoríte v prehliadači) |
| `screenshots/*.png` | obrazovky na 1440 px a na mobile 390 px (`*-mobil.png`) |

## Referenčné obrazovky
1. Úvodná stránka obchodníka
2. Zákazníci (zoznam)
3. Odberné miesta (zoznam)
4. Obchod – detail (Agro Turiec 2027)
5. Zmluvy (zoznam)

Ostatné obrazovky sa prerobia podľa rovnakých vzorov (zoznam, detail, formulár).

## Otvorené body
- **Písmo Campton:** manuál predpisuje Campton. Návrh dočasne používa Lexend. Po získaní webovej licencie (súbory .woff2) stačí zmeniť `--gl-font-sans` v `tokens.css`.
- **Logo v menu:** `logo-mark.svg` je zjednodušené „g“. Ideálne ho nahradiť oficiálnym symbolom zo značky.
- **Doplnky oproti schváleným obrazovkám:** ikona typu pri odberných miestach (blesk = spotreba, slnko = výroba), štítok „Výroba“ v zelenej a záporná pridaná hodnota v červenej. Ak ich nechcete, Claude Code ich vynechá.
