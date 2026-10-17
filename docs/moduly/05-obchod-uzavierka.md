# Modul 5 – uzávierka (fáza A plánu `docs/plan-dokoncenie-a-ostre.md`)

Stav k 17. 10. 2026. Porovnané zadanie `05-obchod.md` v0.2 (časti 1–21) a obrazovky 30–42 s kódom (migrácie `0032`–`0057`, API `api/src/routes/`, obrazovky `web/src/pages/`, Worker `ponuka/`). Overené v kóde, nie podľa STAV.md. Nič nové sa neprogramovalo.

Stavy: **hotové** (migrácia / API / obrazovka) · **zmenené rozhodnutím** (odkaz do `docs/rozhodnutia.md`, dátum) · **čiastočne** · **chýba** · **presunuté** (do inej fázy plánu).
Skratky: M = `db/migrations/00xx`, R = riadok `docs/rozhodnutia.md` s dátumom.

## 3. Pipelines a štádiá – hotové

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| 4 pipelines, B2C iba domácnosti | hotové | M0032 (`pipeline_seed_stages`, `deal_rules`), `deals.ts` |
| Štádiá a pravdepodobnosti 10/30/50/90/100/0, systémové zamknuté | hotové | M0032 |
| Povinné pri vstupe (zákazník, vlastník, zdroj; OOM so spotrebou; akceptovaná ponuka; spárovaná zmluva; dôvod prehry) | hotové | M0032 `deal_rules`, `deal_oom_ready`; M0039, M0045 |
| Číselníky dôvodov prehry a zdroja, spravuje admin | hotové | M0032; Nastavenia → Číselníky |

## 4. Obchod – hotové okrem e-mailov v časovej osi

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Polia obchodu (zákazník, pipeline, štádium, vlastník, zdroj, uzavretie, začiatok dodávky, OOM so spotrebou, kontakty s rolou, ďalší krok, predošlá zmluva, poznámky) | hotové | M0032; `deals.ts`; `DealPage.tsx` |
| Viac otvorených obchodov dodávka aj výkup; NN + VN jeden obchod a jedna ponuka | hotové | M0032 `deal_oom_conflict`; R 2026-10-15 |
| Nové OOM Pripravované, kontrola EIC | hotové | `deals.ts` (`oomValues`) |
| Pri prehre OOM bez zmluvy → Neaktívne | zmenené rozhodnutím | → **Zrušené** („obchod prehraný“), R 2026-10-15; M0032 `deal_after_change` |
| Obnova 4 mesiace pred koncom, Príležitosť, vlastník, zdroj, OOM zo zmluvy; nie domácnosti, nie s nástupcom, nie pri existujúcej Obnove | hotové | M0046 `contract_renewal`; M0032 `deal_open_renewal_key` |
| Obnova pri existujúcom bežnom obchode doplní predošlú zmluvu | zmenené rozhodnutím | R 2026-10-15; M0046 |
| Ďalší krok: upozornenie v deň kroku, zvýraznenie bez kroku / po termíne | hotové | M0032 `deal_daily_run_at`; `DealsPage.tsx` |
| Časová os: poznámky, štádiá, ponuky a verzie, otvorenia, akceptácia, výnimky, spárované zmluvy | hotové | M0032 `deal_events`, M0036–M0045 |
| Časová os: odoslané a prijaté e-maily | **čiastočne** | e-maily sú v samostatnej karte „E-maily a odpovede“ na obchode, v osi je iba odoslanie ponuky |

## 4.1 Overenie firmy a vlastník – hotové okrem dvoch zobrazení

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Hľadanie IČO / názov (Finstat + CRM), je v CRM, zákazník, vlastník, otvorené obchody | hotové | M0033, M0034 `company_check`; `company-check.ts`; `CompanyCheckPage.tsx` |
| Finstat: tržby, zisk, zamestnanci, sídlo, dlhy, nedoplatky, konkurz, Z-skóre s pásmami | hotové | M0033 `company_risk` |
| Finstat: dátum vzniku | **čiastočne** | v DB aj API (`founded_on`), na obrazovke 31 ani na karte firmy sa nezobrazí |
| Platobný rating z Finstatu | zmenené rozhodnutím | ručný na firme, Finstat ho neposiela, R 2026-10-15 |
| Nová firma z Finstatu jedným klikom, vlastník = obchodník | hotové | `POST /companies/from-finstat` |
| Konflikt vlastníka, požiadať o pridelenie, upozornenie pôvodnému vlastníkovi | hotové | M0032, M0034 `approval_request_assign*` |
| Schvaľuje manažér / obchodný riaditeľ | zmenené rozhodnutím | príznak „schvaľuje pridelenie firmy“, R 2026-10-15 |
| Výstrahy na firme a obchode | hotové | `FinstatCompanyCard`, `RiskPills` |
| Výstrahy pri ponuke (dlhy, nedoplatky, konkurz, E/X, Z-skóre < 1,23) | **čiastočne** | pri ponuke iba „rizikový zákazník“ (konkurz / E/X); dlhy, nedoplatky a Z-skóre sa neukážu |
| Konkurz / E/X → schválenie pred odoslaním | hotové | M0037 `rizikovy_zakaznik`, 30 dní (R 2026-10-15) |

## 5. Ponuka – hotové okrem upozornenia nad 30 MWh a tranže

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Číslo P26-000123, verzia /2, jedna ponuka na obchod | hotové | M0036, M0038 `offer_new_version` |
| Stará verzia Nahradená | zmenené rozhodnutím | až pri odoslaní novej, R 2026-10-15 |
| Stavy (vrátane Vypršaná – počíta sa) | hotové | M0036 enum, `offer_state` |
| Varianty: FIX / SPOT + aditív / kombinácia, obdobie aj na neurčito, ceny OOM × rok, výkup € / %, VIWA balík a výkon, najviac 5 variantov | hotové | M0036, M0039, M0041; `OfferPage.tsx` |
| Tranža | **čiastočne** | ponuka ju neurčuje ani neukazuje (iba zmluvy), návrh 34 má pole „Tranža“ |
| Snímka ceny pre obchodníka ku dňu verzie | hotové | `offer.priced_on`, `offer_year_basis` |
| „Prepočítať na dnešné ceny“ vytvorí novú verziu | zmenené rozhodnutím | rozpracovaná verzia sa prepočíta na mieste, odoslaná novou verziou, FIX zo staršieho dňa nejde odoslať; R 2026-10-15, návrh 19.6 |
| Cena pre obchodníka / min. aditív, PH za rok a spolu, odhad provízie, marža iba s právom | hotové | `offer_variant_values` (M0052, M0056) |
| Domácnosti: ceny z cenníka podľa sadzby, VBattery | hotové | M0036 `offer_fill_price_list` |
| **Upozornenie nad 30 MWh** (individuálna ponuka) | **chýba** | žiadna kontrola v ponuke, API ani editore |
| Výkup (FIX, SPOT − €/%, lokálny zdroj) a VIWA (poplatok, koeficient, poplatok za kW) | hotové | M0036, M0040 (koeficient z programu cenníka, R 2026-10-15), M0041 |
| Platnosť FIX / SPOT / VIWA, sviatky, skrátenie, predĺženie iba schvaľovateľom, Vypršaná na stránke | hotové | M0036, M0037, M0039; Worker |

## 6. Výnimky a schvaľovanie – hotové

Cena pod hranicou, konkurz / E/X, predĺženie; bez schválenia sa nedá odoslať; dôvod a poznámka; zvonček aj e-mail z crm@; výnimka 3 dni; k variantu; prechod na zmluvu (M0036, M0037, M0040, M0045; `ApprovalsPage.tsx`). Doplnky rozhodnutím: schválenie nižšej zmluvnej pokuty, výnimka sa neprenáša na novú verziu inak ako v lehote (R 2026-10-15).

## 7. PDF, šablóny, stránka ponuky a akceptácia – hotové okrem EN šablón

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| PDF časti 1–10 v poradí, SPOT vzorec a OKTE, referencie, mix, záväzná objednávka (VIWA bez pokuty) | hotové | `render/offer-html.ts`, šablóny M0039 |
| Rozsah cien firmy / domácnosti, regulované poplatky textom, zlúčenie produktov | hotové | M0040 `offer_doc_variants` |
| Obrázky vymieňa admin | hotové | M0039 `offer_asset`; Šablóny ponúk |
| PDF cez Browser Run do R2 | zmenené rozhodnutím | R 2026-10-15 |
| Šablóny 3 druhy × SK / EN s históriou, iba admin | hotové | M0039 |
| **EN šablóny** | **čiastočne** | v migrácii sú Návrh; ponuku v EN nejde odoslať, kým ich Peter nezverejní (R 2026-10-15) – úloha Petra |
| Premenné polia a predvolené hodnoty (tabuľka 7.2), zmluvná pokuta | hotové | M0036; pokuta R 2026-10-15 |
| Predvolená splatnosť a preddavky nastaviteľné na šablóne (návrh 42) | **čiastočne** | pevné v databáze, na šablóne iba zmluvná pokuta |
| Stránka ponuky: neuhádnuteľný odkaz, platnosť + 30 dní, varianty, PDF, akceptácia (meno, funkcia, súhlas, „Záväzne objednávam“, čas, IP, prehliadač, znenie a odtlačok) | hotové | M0039, M0041; `ponuka/src/index.ts` |
| Potvrdenie zákazníkovi | zmenené rozhodnutím | s PDF potvrdenia uloženým pri akceptácii (nie PDF ponuky), R 2026-10-15 a 2026-10-16 |
| Obchod → Akceptácia + upozornenie; VIWA „Prijímam ponuku“; ručná akceptácia a podpísané PDF; zrušenie akceptácie adminom | hotové | M0039; `offers-pdf.ts` |
| Sledovanie otvorení bez pixelu | hotové | M0039 `offer_page_stat` |

## 8. E-maily z CRM – hotové okrem výberu šablóny voľného e-mailu

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Odosielanie zo schránky obchodníka (servisný účet), Odoslané, odpovede | hotové | `api/src/gmail/`, M0042 |
| Ponuka s odkazom a PDF; potvrdenie akceptácie; pripomienka platnosti 2 prac. dni pred koncom iba SPOT / VIWA ako koncept | hotové | M0042, M0043; R 2026-10-16 |
| **Voľný e-mail prázdny alebo zo šablóny** | **čiastočne** | vždy šablóna „volny“ v SK; výber šablóny, „Prázdny“ a EN chýbajú (návrh 37 ich má) |
| Interné upozornenia, e-mail z crm@ | zmenené rozhodnutím | e-mailom iba schvaľovateľom, akceptácia, pomoc, provízny list; R 2026-10-16 |
| Ukladá iba poštu z CRM a odpovede vo vláknach | hotové | M0042, M0043 `gmail_read_authorize` |
| Kontrola odpovedí každých 5 min | zmenené rozhodnutím | každú minútu, R 2026-10-16 |
| Šablóny SK / EN (admin, Marketing), úprava pred odoslaním, predvolená šablóna ponuky | hotové | M0042, M0044 |
| Podpis z profilu | **čiastočne** | zo sociálnych sietí iba LinkedIn (ostatné cez vlastný HTML podpis) |

## 9. Podklady pre zmluvu – hotové

Všetky polia firmy, zástupcu, zmluvy a OOM, uloženie k firme / kontaktu / OOM, poradie Office portálu, „Kopírovať“, dve zmluvy NN / VN, kto zadáva (obchodník, Servis, Nákup), „Čaká na zmluvu“ (M0045, `contract-deals.ts`, `ContractInputPage.tsx`). Súbor pre Office portál – budúca práca podľa zadania.

## 10. Párovanie zmlúv z importu – hotové

Body 1–6 (M0045, M0046): kandidáti Akceptácia / Vyjednávanie (spresnené R 2026-10-16), Vyhraté pri prvej zmluve a pripojenie VN, „Cena iná ako v ponuke“ (upozornenie všetkým schvaľovateľom cien, R 2026-10-16), 14 dní, Nespárované a „Bez obchodu“ (stav párovania, nie príznak zmluvy), výnimka na zmluvu. Párovanie iba po zapnutí `deal_matching` (R 2026-10-16).

## 11. Domov obchodníka – hotové okrem dvoch drobností

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Dlaždice FIX na 3 roky „stav k“, min. aditív, víkendy a sviatky | hotové | `home.ts`, `HomePage.tsx` |
| Dátum settlementu na dlaždici | **čiastočne** | ukazuje sa iba „stav k“ (návrh 30 má „settlement …“) |
| SPOT priemer 12 mesiacov z Cockpitu | zmenené rozhodnutím | Montel, od 1. 1. aktuálneho roka, R 2026-10-17 (P3 zmenené) – `0057` ešte nie je na `dev` |
| Graf od 1. 1. 2026, kalkulačka, overenie firmy so „Založiť obchod“ | hotové | `home.ts`, M0049, M0050 |
| Moje kroky (dnes, po termíne, zajtra), ponuky na schválenie a otvorené | hotové | `home.ts` |
| **Vypršané ponuky** | **chýba** | iba „Vyprší dnes“ |
| Žiadosť o pomoc | zmenené rozhodnutím | tlačidlo na karte obchodu, ide Sales_internal / adminom, R 2026-10-16 |
| Domov ako úvodná stránka podľa roly | zmenené rozhodnutím | R 2026-10-16 |

## 12. Provízie – hotové, prenos histórie presunutý

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Percento s históriou, „počítať provízie“, aktívny | hotové | M0036 `user_commission_rate`, M0053 `commission_enabled` |
| Provízia = PH obchodu × %, vznik pri Vyhraté, neurčito 12 mesiacov, prepočet pred uplatnením | hotové | M0053 `commission_sync`, `commission_deal_base` |
| Po uplatnení iba vyrovnanie pri spárovaní / zrušení spárovania a zmene štádia | zmenené rozhodnutím | R 2026-10-17 |
| Stavy, uplatnenie jedného obchodníka, CMSN od 1 každý rok, uplatnená sa neprepočítava | hotové | M0053 |
| PDF a e-mail obchodníkovi a obchodnému riaditeľovi | zmenené rozhodnutím | kópiu dostanú príjemcovia vybraní v Nastaveniach, R 2026-10-17; M0055 |
| Zrušenie listu adminom s dôvodom, PDF ZRUŠENÉ | hotové | M0053, M0055 |
| Prehľad: zoskupenie podľa trvania, súčty, filtre | hotové | `CommissionsPage.tsx`; „vyplatené“ = uplatnené (stav Vyplatená sa nezavádza, R 2026-10-15) |
| Filter obchodníka „admin“ | zmenené rozhodnutím | kto vidí všetky provízie, R 2026-10-17 |
| **Prenos histórie zo Sales portálu** | **presunuté** | do fázy F, krok F6 (Peter 17. 10.); v DB pripravené stĺpce histórie a kontrola duplicít (M0053), skript exportu a import chýbajú zámerne |

## 13. Prehľady – čiastočne

| Bod | Stav | Dôkaz |
| --- | --- | --- |
| Kanban a zoznam, filtre pipeline, vlastník, ďalší krok | hotové | `DealsPage.tsx`, `deals.ts` |
| Filtre štádium a zdroj | **čiastočne** | v API áno, na obrazovke nie |
| **Filter očakávané uzavretie** | **chýba** | ani API, ani obrazovka |
| Súčet PH a vážený súčet | hotové | `deals.ts` `totals` (M0052) |
| Vážená PH po štádiách | **čiastočne** | API ju vracia, kanban ju neukazuje |
| **Súčty podľa mesiaca uzavretia** | **chýba** | žiadne zoskupenie podľa očakávaného uzavretia |
| Rozpad podľa obchodníkov | hotové | na Domove pre manažéra (návrh 36.2) |
| Zoznamy bez kroku / po termíne, čaká na schválenie, čaká na zmluvu, nespárované | hotové | `DealsPage`, `ApprovalsPage`, `ContractMatchingPage` |
| API pre Cockpit | presunuté | s F5 modulu 4 pri prechode z HubSpotu (STAV) |

## 14. Práva – hotové

Externý „iba svoje“ v DB (M0032 RLS), vedenie mení vlastníka, Back office a Nákup vidia všetko a dopĺňajú podklady / párujú, schvaľovatelia cien, admin (šablóny, číselníky, zrušenie listu), marža iba s právom. Zmenené rozhodnutím: Sales_internal = „všetko“ a obchodníci v Sales_external (R 2026-10-15), schvaľovanie pridelenia príznakom (R 2026-10-15), všetky provízie admin + „Provízie – všetko“ + príznak „vidí všetky provízie“ (R 2026-10-17), nákupnú cenu portfólia zadáva admin a Nákup (R 2026-10-17).

## 15. Prenos z HubSpotu a pilot – presunuté

Do fázy F plánu (F5 otvorené obchody). Pripravené: `deal.hubspot_id`, `offer.hubspot_quote_id`, výnimka pre rolu `crm_sync` (rola zatiaľ neexistuje). Pilot: prepínače `gmail_enabled`, `deal_matching`, `commission_crm_from`.

## 16. Príklady – všetkých 5 podporovaných

NN + VN dve zmluvy, cena pod hranicou s výnimkou na 3 dni, konkurz blokuje odoslanie, Obnova, platnosť FIX (M0036, M0037, M0045, M0046).

## 17. Dopady na iné moduly – hotové

Tabuľky (šablóny ako `offer_template_version` a `email_template_version`), profil používateľa, Gmail, kalendár, Finstat na firme, IBAN a fakturačné e-maily, OOM Pripravované a nové polia, Obnova a párovanie v module 4. „Bez obchodu“ je stav párovania, nie príznak. Cockpit (Sales portál prestane čítať `prices_daily`) – pri prechode, fáza G.

## 18. Fázy F1–F7 – F1 až F7 krok 2 hotové, krok 3 presunutý do F6

## 19. Obrazovky 30–42

| Obrazovka | Stav | Odchýlka |
| --- | --- | --- |
| 30 Domov | hotové | chýba settlement na dlaždici a vypršané ponuky; SPOT od 1. 1. (rozhodnutie) |
| 31 Overenie firmy | hotové | chýba dátum vzniku |
| 32 Obchody | čiastočne | filtre štádium, zdroj, uzavretie; vážená PH v stĺpci; súčty podľa mesiaca uzavretia |
| 33 Karta obchodu | hotové | e-maily v samostatnej karte |
| 34 Editor ponuky | hotové | chýba pole Tranža a upozornenie nad 30 MWh |
| 35 PDF ponuky | hotové | – |
| 36 Stránka ponuky | hotové | – (na telefóne overí Peter) |
| 37 E-mail | čiastočne | výber šablóny, „Prázdny“, EN |
| 38 Podklady pre zmluvu | hotové | – |
| 39 Schvaľovanie | hotové | – |
| 40 Zmluvy k obchodom | hotové | – |
| 41 Provízie | hotové | – |
| 42 Šablóny ponúk | hotové | predvolená splatnosť a preddavky nie sú na šablóne |

Šírku 390 px Claude nevedel spoľahlivo nasnímať (headless Chrome) – na telefóne prejde Peter, najmä verejnú stránku ponuky.

## 20. Bezpečnosť – hotové, dve úlohy pri prechode

Sales portál nie je v repozitári (`exports/` v `.gitignore`); stránka ponuky (odkaz, bez iných OOM a marže, obmedzenie pokusov Workers Rate Limiting, IP iba pri akceptácii); Gmail `gmail.send` + `gmail.readonly` s poistkami (zmenené rozhodnutím R 2026-10-15/16); kľúč iba vo `wrangler secret`. Pri prechode: zneplatniť kľúč Make a webhooky (fáza G), pravidlo WAF na `ponuka.greenlogy.com` (fáza D).

## 21. Otvorené otázky

P4 právne overenie akceptácie klikom – úloha Petra (obe cesty fungujú).

---

## Zoznam „chýba“ a „čiastočne“ s návrhom

| # | Bod | Návrh |
| --- | --- | --- |
| 1 | Upozornenie nad 30 MWh v ponuke (5.3) | **doplniť hneď** – kontrola pri pripravení ponuky domácnosti / malého podniku (rovnaká hranica ako `small_business_volume`) |
| 2 | Výstrahy pri ponuke: dlhy, nedoplatky, Z-skóre < 1,23 (4.1) | **doplniť hneď** – rovnaké štítky ako na obchode (`RiskPills`) |
| 3 | Prehľady (13): filter očakávané uzavretie, filtre štádium a zdroj na obrazovke, vážená PH v stĺpcoch kanbanu, súčty podľa mesiaca uzavretia | **doplniť hneď** – pred pilotom ich potrebuje vedenie |
| 4 | Domov: vypršané ponuky, dátum settlementu (11) | **doplniť hneď** – drobnosti |
| 5 | Voľný e-mail: výber šablóny, „Prázdny“, EN (8, obrazovka 37) | **doplniť hneď** |
| 6 | Tranža v editore ponuky (5.1, obrazovka 34) | doplniť hneď iba zobrazenie (FIX / SPOT podľa variantu), alebo odložiť – rozhodne Peter |
| 7 | Dátum vzniku firmy (4.1, obrazovka 31) | presunúť do fázy B (Finstat pri založení firmy) |
| 8 | E-maily v časovej osi obchodu (4) | odložiť vedome – sú v samostatnej karte na tom istom obchode |
| 9 | Predvolená splatnosť a preddavky na šablóne (obrazovka 42) | odložiť – pevné hodnoty v DB zodpovedajú zadaniu |
| 10 | Podpis: ďalšie sociálne siete okrem LinkedIn (8) | odložiť – rieši vlastný HTML podpis |
| 11 | EN šablóny ponúk | úloha Petra (kontrola a zverejnenie na obrazovke 42) |
| 12 | Prenos histórie provízií (12), prenos obchodov z HubSpotu (15), API pre Cockpit (13) | presunuté do fázy F (F5, F6) |
| 13 | Make kľúč a webhooky, WAF, Cockpit `prices_daily` (17, 20) | fázy D a G |

## Výsledok (Peter 17. 10. 2026)

Body 1–6 schválené a **doplnené** (bez migrácie, iba API a obrazovky; lokálne overené proti kópii dočasnej databázy s testovacími dátami F5):

1. **Upozornenie nad 30 MWh** – v kontrole ponuky (`OfferPage.tsx` `CheckCard`): cenníková ponuka (domácnosť alebo variant s cenníkom) a plánovaný ročný objem OOM obchodu nad 30 MWh → „treba individuálnu ponuku“; objem vracia API ponuky (`planned_mwh`).
2. **Výstrahy pri ponuke** – riadok „Finstat“ v karte Ponuka so štítkami ako na obchode (dlhy, nedoplatky, konkurz, E/X, Z-skóre); API ponuky vracia `company_risk`.
3. **Prehľady obchodov** – filtre štádium, zdroj a očakávané uzavretie (mesiac od – do; API `close_from`, `close_to`), vážená PH v hlavičke stĺpcov kanbanu, karta „Otvorené obchody podľa mesiaca očakávaného uzavretia“ (počet, PH, vážená PH; API `by_month`).
4. **Domov** – „Vypršané (30 dní)“ v Moje ponuky a obchody; na dlaždiciach ceny „settlement …“ (predošlý pracovný deň pred dňom ceny).
5. **Voľný e-mail** – výber šablóny v dialógu: Voľný e-mail slovensky / anglicky (iba platné šablóny) a Prázdny e-mail (oslovenie a podpis); API `/emails/new?lang=…&template=prazdny`.
6. **Tranža** – riadok v súhrne variantu ponuky (FIX / SPOT / SEAS po rokoch, rovnako ako pri zmluve).

Odklady (body 7–10) a presuny (11–13) Peter schválil.
