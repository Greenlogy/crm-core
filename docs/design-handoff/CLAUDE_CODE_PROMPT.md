# Zadanie pre Claude Code – nový vzhľad Greenlogy CRM

> Skopírujte priečinok `greenlogy-crm-design-handoff/` do koreňa repozitára CRM (napr. `docs/design-handoff/`) a vložte Claude Code text nižšie.

---

Ahoj, potrebujem zmeniť **vzhľad** našej aplikácie Greenlogy CRM podľa schváleného návrhu. Podklady sú v priečinku `docs/design-handoff/`:

- `DESIGN_SPEC.md` – kompletná špecifikácia (farby, písmo, komponenty, rozloženie, mobil, prístupnosť, mapovanie starých tokenov),
- `tokens/tokens.css` (+ `tokens.json`, `tailwind.theme.js`) – dizajnové tokeny ako CSS premenné,
- `styles/components.css` – hotové štýly komponentov (triedy `gl-*`),
- `assets/landscape-hero.svg` – krajina do hlavičky (tvary a farby nemeniť), `assets/logo-mark.svg`,
- `reference/*.html` – 5 referenčných obrazoviek ako statické HTML,
- `screenshots/*.png` – ako majú obrazovky vyzerať (desktop 1440 px a mobil 390 px),
- `assets/brand/Design_manual_Greenlogy_2021.pdf` – firemný design manuál.

## Pravidlá
1. **Meníme iba vzhľad.** Nemeň obsah, texty, polia, poradie sekcií, logiku, API, dáta ani oprávnenia. Ak niečo z referencie v appke chýba alebo je navyše, neprerábaj funkciu. Napíš mi to do zoznamu otázok.
2. Všetky farby, veľkosti, zaoblenia a tiene ber z `tokens/tokens.css`. **Žiadne natvrdo zapísané hex hodnoty** v komponentoch, s výnimkou SVG krajiny.
3. Firemnú zelenú `#05d695` nepoužívaj na text. Text je `--gl-ink`, `--gl-ink-muted` alebo `--gl-brand-blue`.
4. Na obrazovke je najviac jedno primárne tlačidlo.
5. Čísla v slovenskom formáte (`1 625,92 €`), `tabular-nums`, v tabuľkách zarovnané doprava.
6. Zachovaj prístupnosť: fokus, `aria-current`, `aria-pressed`, popisy grafov, `prefers-reduced-motion`.

## Postup
1. **Prieskum (bez zmien):** zisti stack (framework, CSS prístup, kde sú layout, menu, tabuľky, karty a grafy) a ako sa dnes načítajú farby a písma. Pošli mi krátky plán: ktoré súbory zmeníš a v akom poradí.
2. **Základ:** pridaj tokeny (CSS premenné, prípadne Tailwind theme z `tailwind.theme.js`), písma Lexend a Geist Mono a globálne štýly (`body`, odkazy, fokus). Staré tokeny nahraď podľa tabuľky v `DESIGN_SPEC.md` § 9.
3. **Spoločné prvky:** úzke bočné menu (88 px, na mobile spodná lišta), hlavička s krajinou (`landscape-hero.svg` inline + animácia lopatiek), sklenená lišta, karty, tlačidlá, polia, čipy, štítky stavov, tabuľka, KPI dlaždice, dátumová dlaždica, časová os, štádiá a grafy.
4. **Obrazovky v tomto poradí** (každú porovnaj so screenshotom a s `reference/*.html`):
   1. Úvodná stránka obchodníka → `01-uvodna-stranka`
   2. Zoznam zákazníkov → `02-zakaznici`
   3. Zoznam odberných miest → `03-odberne-miesta`
   4. Detail obchodu → `04-obchod-detail`
   5. Zoznam zmlúv → `05-zmluvy`
5. **Ostatné obrazovky** (karty firmy, osoby, OOM, zmluvy, ponuka, nastavenia, cenníky, provízie, schvaľovanie…): použi rovnaké vzory. Zoznamy podľa 02/03/05, detaily podľa 04, formuláre podľa kalkulačky na 01.
6. **Kontrola:** po každej obrazovke ju spusti, urob screenshot na 1440 px a 390 px a porovnaj s `screenshots/`. Skontroluj, že stránka sa na mobile neposúva do strany a že kontrast textu je ≥ 4,5:1.
7. Rob malé commity po krokoch (napr. `design: tokens`, `design: rail + hero`, `design: zoznam zákazníkov`…). Na konci mi pošli zoznam zmenených obrazoviek a otázky.

Ak niečo v podkladoch chýba alebo si nie si istý, opýtaj sa, nevymýšľaj.
