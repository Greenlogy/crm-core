# Zadanie pre novú session: fáza B a ďalej

Verzia 1 · 17. 10. 2026 · pripravil Claude Code na konci session modulu 5 (F7 a fáza A)

Riadi sa plánom `docs/plan-dokoncenie-a-ostre.md` (Peter, v1). Fáza A (uzávierka modulu 5) je uzavretá – `docs/moduly/05-obchod-uzavierka.md`, `docs/STAV.md` časť „Modul 5 – uzávierka“.

## Úvodná správa pre novú session (Peter vloží)

> Nová session – fáza B (Finstat pri založení firmy). Prečítaj `CLAUDE.md`, `docs/plan-dokoncenie-a-ostre.md`, `docs/STAV.md` (najmä „Modul 5 – uzávierka“ a „Test a Ostré – oddelenie“) a `docs/moduly/06-zadanie-faza-B-a-dalej.md`. Postupuj podľa časti B tohto zadania: najprv zistenia, potom plán na schválenie. Nič nemeň, kým plán neschválim.

## Čo si prečítať pred začatím

1. `CLAUDE.md` – pravidlá (slovenčina, plán pred zmenou, bez súhlasu žiadny commit / push / deploy / migrácia / mazanie / tajomstvá / Cloudflare).
2. `docs/plan-dokoncenie-a-ostre.md` – fázy A–G, podmienky ukončenia.
3. `docs/STAV.md` – stav, otvorené úlohy, tabuľka oddelenia Testu a Ostrého.
4. `docs/rozhodnutia.md` – posledné riadky (17. 10.): provízie, zámky, nákupná cena portfólia, SPOT od 1. 1., uzávierka.
5. `docs/moduly/05-obchod-uzavierka.md` – čo je v module 5 hotové, zmenené, odložené.
6. Pre fázu B: `docs/moduly/01-zakaznici.md`, `docs/moduly/05-obchod-navrh-db.md` časť 8 (Finstat) a 15–16 (F1), `api/src/finstat.ts`, `api/src/routes/company-check.ts`, migrácie `0033_finstat.sql`, `0034_obchod_f1_doplnky.sql`, obrazovky `CompanyCheckPage.tsx`, `CustomersPage.tsx` / formulár novej firmy (`components/customer-forms.tsx`).

## Fáza B – Finstat pri založení firmy

Podľa časti B plánu. **Najprv zistenia (bez zmien), potom plán.** Peter chce vedieť:

1. **Čo dnes robí Finstat** v module 1 (zákazníci) a pri overení firmy v module 5 a čo sa dá znovu použiť:
   - klient `api/src/finstat.ts` (podpis požiadavky, úroveň `FINSTAT_LEVEL`, cache a počítadlo `finstat_cache` / `finstat_usage` v `0033`),
   - `GET /company-check`, `/finstat/autocomplete`, `POST /companies/from-finstat` (`company-check.ts`), `company_risk`, `company_check`,
   - čo sa dnes ukladá na firmu a čo iba do cache.
2. **Ktoré polia vie náš prístup vrátiť a ktoré nie** – overiť podľa dokumentácie Finstat API a podľa reálnej odpovede (jedno volanie na známe IČO so súhlasom Petra; do chatu iba zoznam polí, nie údaje). Konkrétne: DIČ, IČ DPH, právna forma, sídlo po zložkách, SK NACE, dátum vzniku, **registrový súd a číslo vložky**, stav firmy (likvidácia, zrušená, konkurz), štatutári (meno, funkcia – bez dátumu narodenia), finančné ukazovatele. Čo Finstat nevracia, napísať ako „nie je k dispozícii“, nehádať.
3. **Kvóta a šetrenie:** aký je denný / mesačný limit nášho prístupu, ako sa dnes počíta (`finstat_usage`), ako dlho platí cache (dnes 24 h), oneskorenie našepkávania, a návrh na hromadné overenie po importe (fáza F1) s ohľadom na kvótu. Test a Ostré budú pri rovnakom kľúči zdieľať kvótu (STAV) – odporučiť riešenie.

Potom **plán v krokoch** ako pri F5–F7: migrácia nanečisto (dočasný lokálny Postgres) → `dev` po súhlase → API a obrazovky → Test → commit po Petrovom teste. Plán musí pokryť body 1–9 časti B plánu (hľadanie IČO / názov, duplicita pred vyplnením a „Požiadať o pridelenie“, vyplnené polia, štatutári ako návrh kontaktu, zdroj „Finstat, DD.MM.RRRR“ a ručne zmenené polia, blokovanie likvidácie / zrušenia / konkurzu s výnimkou ako pri ponuke, „Aktualizovať z Finstatu“ s rozdielmi, výpadok Finstatu a príznak „neoverené“ s nočným opakovaním, kvóta). Z uzávierky modulu 5 sem patrí aj **dátum vzniku firmy** na overení firmy a karte firmy.

**Podmienka ukončenia (plán):** na Teste sa firma založí iba zadaním IČO bez dopisovania, duplicita je zachytená, firma v konkurze je zablokovaná, výpadok Finstatu sa dá obísť.

## Fáza C – manuál v aplikácii

Podľa časti C plánu a Petrovho pokynu zo 17. 10.: **najprv plán, potom kód, potom texty.** Plán obsahuje:
- dátový model: stránka manuálu (kľúč podľa trasy aplikácie), verzie (kto, kedy, návrat), podnety (Nový / Zapracovaný / Zamietnutý), právo „Upravovať manuál“, časti pre roly (napr. marža, schvaľovanie) skryté podľa práv používateľa – rovnako ako aplikácia,
- bezpečné zobrazenie Markdownu bez HTML a skriptov + test na XSS,
- ikona 📖 na každej stránke a zoznam všetkých stránok podľa menu (`web/src/main.tsx`, `components/Layout.tsx`, `pages/settings/SettingsLayout.tsx`),
- základ v `docs/manual/`, naplnenie prázdnej databázy, export / import manuálu medzi prostrediami.

Texty až po schválení a nasadení funkcie; každá stránka v piatich častiach podľa skutočného kódu a zadaní; kde správanie nie je isté, napísať otázku, nie tvrdenie. **Najprv 3 vzorové stránky (Domov, Karta obchodu, Provízie)** na schválenie štýlu, až potom ostatné.

## Fázy D–G – iba príprava

Na Ostré nič nespúšťať. Známe medzery na oddelenie (STAV, tabuľka „Test a Ostré – oddelenie“):
- `MAIL_ALLOWLIST` sa pri `ENVIRONMENT = "ostre"` neuplatní (`api/src/gmail/mime.ts`) – plán chce obmedzenie do pilotu → zmena kódu pred Ostrým,
- `api/wrangler.toml` a `ponuka/wrangler.toml` majú iba Test (Hyperdrive, R2, vars, väzba `crm-ponuka` → `crm-core`, `namespace_id` obmedzenia pokusov) → prostredie pre Ostré,
- skripty rolí a Hyperdrive (`api/db/create-*.sh`) vedia iba `dev`; rola `crm_sync` neexistuje,
- testy DB na `main` sú zakázané – kontroly cez dočasnú vetvu z `main` (`skuska`),
- migrácie na `main`: `0001` až posledná (dnes `0057`, plán uvádza `0055`),
- spoločná kvóta Finstatu, samostatný kľúč Google odporúčaný.

## Otvorené úlohy Petra (prenesené)

EN šablóny ponúk (kontrola a zverejnenie na obrazovke 42), P4 právne overenie akceptácie klikom, prechod obrazoviek na telefóne (najmä verejná stránka ponuky), založenie Daniela s príznakom „vidí všetky provízie“ a ako príjemcu kópie listu (pred Ostrým), ďalšie úlohy v pláne.

## Praktické poznámky z predošlej session (overovanie)

- **Dočasný Postgres** v scratchpade: `initdb` + `pg_ctl` s `-c unix_socket_directories='' -c listen_addresses=127.0.0.1 -p 54353` (cesta scratchpadu je na Unix socket príliš dlhá), databáza z migrácií cez `node_modules/.bin/dbmate --migrations-dir … up`, cenníky `db/seed/cenniky-2026.sql` a `podnikatelia-2026.sql` – každý v **samostatnej** transakcii. Schéma po migráciách sa porovná s `db/schema.sql` (dump z `dev`).
- Testy lokálne: rovnaký zoznam ako `db/test/run.sh` v jednej transakcii s ROLLBACK (`run.sh` sám beží iba na `dev`); dnes 284 kontrol. Súbeh provízií: `db/test/subeh-provizie.sh` (iba lokálny Postgres).
- **Lokálny Worker proti kópii dočasnej databázy:** `CLOUDFLARE_HYPERDRIVE_LOCAL_CONNECTION_STRING_HYPERDRIVE=postgres://crm_app:…@127.0.0.1:54353/<kópia>` a `wrangler dev --var DEV_USER_EMAIL:… --var MONTEL_FAKE:1`; `crm_app` dostane LOGIN iba na dočasnom serveri a po skúške sa vráti NOLOGIN. Testovacie obchody a ponuky: `db/test-data/zmluvy-f5.sql`.
- Obrazovky: headless Chrome na 1440 px; šírku 390 px nevie spoľahlivo nasnímať (minimálna šírka okna) – mobil overí Peter.
- Pred commitom overiť vetvu (`main`).
