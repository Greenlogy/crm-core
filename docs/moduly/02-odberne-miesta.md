# Modul 2 – Odberné miesta (OOM): zadanie

Verzia 0.2 · 12. 10. 2026 · **schválené Petrom** (v0.2 = rozhodnuté otvorené otázky, časť 14).
Vychádza z odpovedí v `02-odberne-miesta-otazky.md` (12. 10. 2026). Stavia na moduloch 0 (Nastavenia) a 1 (Zákazníci v0.4).

## 1. Čo modul rieši

Evidencia odberných a odovzdávacích miest elektriny: ku ktorému zákazníkovi a v akom období patria, v akom sú stave, technické a fakturačné údaje, výroba a zariadenia, priebeh prechodu k Greenlogy.
Nerieši ceny a zmluvy (modul 4), produkty (modul 3) ani správy XML z OKTE a PDS (samostatný krok neskôr, podľa technickej špecifikácie od Petra).

## 2. OOM a EIC

- **Jedno EIC = jeden záznam OOM navždy.** EIC je unikátne v celej skupine.
- OOM má **práve jeden typ**: spotreba, výroba, sharing. Spotreba a výroba nikdy nemajú spoločné EIC – každá strana má vlastné EIC, teda vlastné OOM.
- **Typ veľkoobchod sa ruší** (Peter 12. 10. 2026): v HubSpote to boli virtuálne OOM bez skutočného EIC, aby deal vedel spočítať maržu. Veľkoobchod budú v novom CRM **položky zmluvy bez OOM** (produkt, obdobie, objem MWh, cena) – rieši modul 4 (Zmluvy) a 5.
- Pri zadaní CRM overí formát a kontrolnú číslicu slovenského EIC. CZ a HR sa doplnia s pobočkami.
- OOM patrí jednej spoločnosti skupiny (Nastavenia, časť 2).

## 3. Väzba OOM – zákazník v čase

- OOM patrí v danom čase **práve jednému zákazníkovi** (firma alebo domácnosť).
- Väzba má **obdobie od – do** a **dôvod ukončenia** (odchod ku konkurencii, zrušenie, prepis na iného odberateľa).
- Dôležitý je časový rez: CRM vie povedať, komu OOM patrilo k ľubovoľnému dátumu (napr. k 1. 3. 2025).
- Pri prepise sa ukončí väzba so starým zákazníkom a vznikne nová s novým. História OOM ostáva pokope.

## 4. Stavy

| Stav | Kedy | Kto ho mení |
| --- | --- | --- |
| **Pripravované** | zmluva podpísaná, dodávka ešte nezačala (v HubSpote „Neaktívne“) | vznikne pri založení OOM k podpísanej zmluve |
| **Aktívne** | Greenlogy dodáva / vykupuje | automaticky v deň začiatku dodávky, ak je zmena dodávateľa potvrdená |
| **Odídené** | OOM odišlo k inému dodávateľovi | servis ručne; neskôr automaticky zo správy OKTE |
| **Zrušené** | OOM zaniklo (napr. zbúraný dom) | servis ručne |
| **Prepísané** | OOM prešlo na iného odberateľa (pre pôvodného zákazníka) | servis ručne pri prepise |

- Stav **Neaktívne sa ruší** (bol to dnešný názov pre Pripravované).
- Stav sa viaže na obdobie väzby: pri prepise má starý zákazník OOM „Prepísané“ a nový zákazník ho má ďalej „Aktívne“.
- Zmena stavu OOM prepočíta stav zákazníka (modul 1, časť 4 v0.4).

## 5. Kontaktné osoby pri OOM

- Pri OOM môže byť jedna alebo viac osôb z firmy zákazníka (napr. správca budovy, technik prevádzky) s rolou z číselníka.
- V module 4 (Zmluvy) sa kontaktné osoby zo zmluvy **automaticky prenesú** na OOM zmluvy, aby sa eliminovala ručná práca. Ručne pridaná osoba ostáva.

## 6. Údaje OOM

| Skupina | Údaje | Povinné pre Aktívne |
| --- | --- | --- |
| Základ | EIC, typ, názov, adresa (ulica, súpisné a orientačné číslo, obec, PSČ) | EIC, typ, adresa |
| Distribúcia | PDS, číslo OP, sadzba distribúcie, napäťová úroveň, typ merania, počet fáz, istič [A], rezervovaná kapacita [kW], maximálna rezervovaná kapacita [kW], interval / spôsob rezervácie kapacity | PDS, napäťová úroveň, sadzba |
| Fakturácia | cenová regulácia (ANO / NIE / nevyplnené – od `0019`, modul 3), spotrebná daň, fakturačné obdobie, spôsob a výška záloh | – |
| Objemy | plánovaná spotreba VT a NT [MWh], plánovaný výkup [MWh] | plánovaná spotreba (pri spotrebe), plánovaný výkup (pri výrobe) |
| Dodávka | dodávka od – do (do = neurčito, ak prázdne) | dodávka od |

- **PDS a sadzby distribúcie sú číselníky** v Nastaveniach (ZSD, SSD, VSD a miestne distribučné sústavy; sadzby podľa PDS).
- Fakturačné údaje patria k OOM, lebo sa môžu líšiť medzi OOM jednej zmluvy.
- **Skutočná spotreba** sa v module 2 nezobrazuje; doplní sa napojením na Cockpit neskôr.
- Vlastné polia z Nastavení fungujú aj pre OOM.

## 7. Výroba a zariadenia

- Pri OOM typu výroba: druh zdroja (FVE, voda, bioplyn, plyn, vietor, ostatné OZE), **kategória zdroja podľa zákona (Malý zdroj, Lokálny zdroj, Výrobný zdroj)**, výkon zdroja [kW], výkon striedača a panelov [kW], typ výkupnej zmluvy.
- **Zariadenia pri OOM:** zoznam (striedač, panely, batéria, tepelné čerpadlo, wallbox) so značkou, modelom, výkonom / kapacitou a počtom. Vypĺňa zamestnanec v CRM; formulár pre zákazníka neskôr.

## 8. Prechod k Greenlogy

Postup na OOM, každý krok s dátumom:
1. výpoveď predošlému dodávateľovi odoslaná,
2. výpoveď akceptovaná,
3. zmena dodávateľa potvrdená,
4. začiatok dodávky → OOM sa stane Aktívne.

CRM ukáže, kde sa proces zasekol (napr. výpoveď odoslaná pred 30 dňami a stále bez akceptácie). Kroky zatiaľ zadáva servis ručne; po napojení správ z OKTE a PDS sa budú dopĺňať automaticky.

## 9. Import z Excelu

- Hromadné založenie a aktualizácia OOM **nahratím Excelu** rovnako ako v Cockpite: šablóna na stiahnutie → nahratie → náhľad s kontrolou → potvrdenie.
- Kontrola pred uložením: formát a kontrolná číslica EIC, duplicity, povinné údaje, existencia zákazníka, hodnoty číselníkov (PDS, sadzba).
- Import smie zakladať nové OOM aj **hromadne aktualizovať existujúce** (párovanie podľa EIC). Náhľad ukáže pri každom riadku, či ide o nové OOM alebo zmenu, a pri zmene starú → novú hodnotu.
- Importovať smú tímy Servis, Nákup a CEO.
- Import zapíše do auditu, kto, kedy a koľko riadkov nahral.

## 10. Obrazovky a práva

- **Zoznam OOM:** EIC, názov/adresa, zákazník, typ, stav, PDS, plánovaná spotreba, dodávka od – do, vlastník. Filtre: typ, stav, PDS, spoločnosť. Hľadanie podľa EIC, adresy a zákazníka.
- **Karta OOM:** údaje po skupinách (časť 6), výroba a zariadenia, prechod k Greenlogy, história väzieb na zákazníkov, kontaktné osoby, časová os.
- **Karta zákazníka:** sekcia OOM so skutočnými údajmi, počet aktívnych OOM a ročný objem v zozname Zákazníci.
- **Práva:** OOM preberá vlastníka zákazníka – externý obchodník vidí iba OOM svojich zákazníkov (aj v databáze). OOM zakladá obchodník alebo servis; technické údaje upravuje Servis a Nákup. Import z Excelu: Servis, Nákup, CEO.

## 11. Príklady dopadov

1. **Nová domácnosť.** Pani Nováková podpíše zmluvu od 1. 1. 2027 → jej OOM je Pripravované, ona je Čakajúci zákazník. Servis zapíše akceptáciu výpovede a potvrdenie zmeny. 1. 1. 2027 sa OOM stane Aktívne a ona Zákazník – automaticky.
2. **Zaseknutý prechod.** Výpoveď odoslaná 1. 9., akceptácia stále chýba → OOM sa ukáže v zozname „Prechod sa zasekol“ a servis vie, komu volať.
3. **Firma s FVE.** Kovovýroba Váh má halu (EIC spotreby) a FVE na streche (iné EIC výroby) → dve OOM, firma dostane segment „Firma · výrobca“.
4. **Prepis.** Pán Horváth predá dom pani Kováčovej, ktorá ostane u nás. EIC ostáva jeden záznam: u pána Horvátha je OOM od 1. 11. „Prepísané“, u pani Kováčovej od 1. 11. „Aktívne“. K 1. 3. 2026 CRM ukáže pána Horvátha, k 1. 12. 2026 pani Kováčovú.
5. **Odchod ku konkurencii.** OOM firmy ABC je Odídené → ak nemá iné Aktívne OOM, firma je Bývalý zákazník.
6. **Obec s 50 OOM.** Servis stiahne šablónu, vyplní 50 riadkov, nahrá Excel. Náhľad ukáže 2 chybné EIC a 1 neznámu sadzbu; po oprave sa uloží 50 OOM naraz.
7. **Externý obchodník** vidí OOM iba svojich zákazníkov; OOM iného zákazníka mu databáza nevráti ani pri hľadaní podľa EIC.

## 12. Nahrávanie dát z HubSpotu

Zatiaľ sa nič nenahráva (rozhodnutie 12. 10. 2026). Plán nahrávania sa určí neskôr. Už rozhodnuté:

- **Virtuálne veľkoobchodné OOM sa neprenesú** (v HubSpote 13: typ „Veľkoobchod“ alebo stav „Veľkoobchod“). Ich objemy a ceny prejdú ako položky zmluvy v module 4.
- HubSpot stav „Neaktívne“ → Pripravované.
- **Sadzba distribúcie:** ~3 200 OOM (3 232) má v HubSpote namiesto sadzby program virtuálnej batérie (VBATTERY-MAX, -PREMIUM, -V, -STANDARD, -AKU, -ECO). Program patrí do modulov 3/4; skutočnú sadzbu bude treba pri prenose doplniť.
- **LZ_NN, LZ_VN, VZ_NN, VZ_VN, VN** (416 OOM) nie sú sadzby: rozdeliť na kategóriu zdroja (LZ = lokálny, VZ = výrobný zdroj) a napäťovú úroveň; sadzbu doplniť.
- Ďalšie zápisy sadzby mimo číselníka (81 OOM): predpona `465_` (napr. 465_C1 → C1), C9a, C11, X2-N, X2-S, X3-C9a, X4-D1 až X4-D3, „AB&B C2-X3“, „-“ – rozhodnúť pri prenose. C2-X3 pri miestnych DS (18 OOM) a X3-C2 pri miestnych DS (3 OOM) sa do číselníka nedostali (C2-X3 iba ZSD, X3-C2 iba VSD).
- **PDS:** duplicitné zápisy sa zlúčia (PPA POWER DS / PPA Power DS, UR P6 a.s. / UR P6 s. r. o.).
- **Druh zdroja:** 9 záznamov s internou hodnotou „Biomasa“ (popis v HubSpote „Bioplyn“) sa zapíše ako **Bioplyn**.
- **Fakturačné obdobie:** „Mesiac“ → Mesačne, „Rok“ → Ročne, „Ročne (s odkladom k termínu odpočtu)“ → Ročne s odkladom; „Ročne (s odkladom)“ (52) a „0“ rozhodnúť pri prenose.
- **Spôsob záloh:** „Kvartálne“ → Štvrťročné zálohy; „0“ (19) rozhodnúť pri prenose.
- Napäťová úroveň „NN“ / „nn“ → NN; typ merania „Typ merania A“ → A, „N - Nemerané“ → N.

## 13. Odložené

- Správy XML z OKTE a PDS (vrátane XML433 / XML43D) – Peter pošle technickú špecifikáciu komunikácie; spracuje sa ako samostatný krok. Nahradí dnešné „notifikačné“ dealy a doplní automaticky kroky prechodu a stavy Aktívne / Odídené.
- Skutočná spotreba z Cockpitu.
- Formulár zariadení pre zákazníka.

## 14. Rozhodnuté 12. 10. 2026

- Na OOM je kategória zdroja podľa zákona (Malý / Lokálny / Výrobný zdroj). Virtuálna batéria a Green VIWA sú produkty / programy – patria do modulov 3 a 4.
- Import z Excelu zakladá nové OOM aj hromadne aktualizuje existujúce podľa EIC, s náhľadom zmien.
- Pripravované → Aktívne: stačí, keď servis označí „zmena dodávateľa potvrdená“ a nastane dátum začiatku dodávky.
- Importovať smú Servis, Nákup a CEO.

## 15. Dokončenie modulu: API a obrazovky (F1–F4)

Schválené 12. 10. 2026. Postup ako pri Zákazníkoch: každá fáza má testovací scenár pre Petra, nasadenie na Test robí Peter, commit až po jeho vyskúšaní. Databáza je hotová (migrácie `0013`–`0015`, návrh `02-odberne-miesta-navrh-db.md`).

- **F1 – Zoznam a karta OOM (čítanie):** zoznam (obrazovka 17) s tlačidlami stavov a počtami, „Prepísané“ a „Prechod sa zasekol“, filtre typ, PDS, vlastník, spoločnosť, hľadanie podľa EIC (aj s medzerami a malými písmenami), názvu, adresy a zákazníka; karta (obrazovka 18) so záložkami Prehľad, Zmluvy a ceny, Kontaktné osoby; história väzieb a „Komu patrilo k dátumu“, prechod k Greenlogy, zariadenia, časová os z auditu; sekcia OOM na karte zákazníka zo všetkých väzieb.
- **F2 – Zápis:** nové OOM (kontrola EIC hneď pri písaní), úprava údajov (sadzby podľa PDS, práva podľa stavu), kroky prechodu, zmena stavu, prepis, návrat, zariadenia, kontaktné osoby, zmazanie (admin); v Nastaveniach lehoty „Prechod sa zasekol“ (obrazovka 11) a sadzby s PDS a IČO pri PDS (Číselníky).
- **F3 – Vlastné polia a export:** vlastné polia OOM na karte a v zozname; **export zoznamu OOM do .xlsx** s právom „exportovať“ a záznamom exportu (EIC, IČO a PSČ ako text) – doplnené rovnako ako pri Zákazníkoch.
- **F4 – Import z Excelu (obrazovka 19):** šablóna, nahratie, náhľad, uloženie platných riadkov v jednej transakcii, záznam importu, audit. **Na čítanie .xlsx sa použije overená knižnica** (nie vlastný parser); export môže ostať vlastný. Test importu na súboroch: dátum ako číslo, úvodné nuly v IČO a PSČ, vzorec v bunke, prázdne riadky, viac hárkov, EIC s medzerami a malými písmenami.

Rozhodnuté:
1. Poradie F1 → F2 → F3 → F4.
2. Záložka „Dokumenty“ na karte OOM je zatiaľ skrytá (úložisko súborov príde neskôr).
3. Export zoznamu OOM patrí do modulu (F3).
4. Testovacie dáta na Test: skript `db/test-data/oom-test.sh dev vytvor|zmaz` (10 zákazníkov a 20 OOM so znakom „TEST“, iba vymyslené údaje); spúšťa Peter.

Stav: F1 na Teste, Peter vyskúšal 12. 10. 2026.

Rozhodnuté po F1 (12. 10. 2026):
5. **Plánované zmeny:** prepis, odchod a zrušenie možno zadať k budúcemu dátumu; vykoná ich nočný beh v ten deň (ako aktiváciu Pripravovaných). Dovtedy sa stavy nemenia, karta OOM aj zákazníka ukáže „Plánovaný prepis / odchod / zrušenie k dátumu“; plán možno pred termínom zrušiť alebo zmeniť dátum. Audit: zadanie plánu (meno) aj vykonanie („Systém“). Rieši migrácia `0016` vo fáze F2.
6. **História po prepise pre „iba svoje“:** obchodník starého zákazníka vidí v histórii aj EIC (funkcia v databáze, `0016`).
7. **RLS na audite** je podmienkou odomknutia externého tímu (`docs/STAV.md`).

F2b (rozhodnuté pri implementácii, Peter môže zmeniť):
8. Nové OOM je vždy **Pripravované**; Aktívne bude automaticky (potvrdená zmena + začiatok dodávky) alebo tlačidlom Aktivovať, ak má povinné údaje.
9. **EIC sa dá opraviť** (preklep) – s kontrolou formátu, kontrolnej číslice a duplicity; zmena je v audite.

F4 – import z Excelu (Peter schválil 13. 10. 2026, lokálne overené):
10. **Knižnica:** SheetJS 0.20.3 z cdn.sheetjs.com, pripnutá kontrolným súčtom (sha512) v `package-lock.json`; súbor číta Worker, databáza dostane celý súbor naraz ako JSON pole riadkov (jedna funkcia `oom_import_run`, migrácia `0018`).
11. **Šablóna = export:** šablóna a export zoznamu OOM majú rovnaké stĺpce (EIC, ID zákazníka, IČO zákazníka, E-mail zákazníka, údaje OOM, vlastné polia). Export navyše obsahuje stĺpce „(len na čítanie)“, ktoré import vynechá. Postup export → úprava v Exceli → import.
12. **Zákazník** sa páruje podľa ID zákazníka → IČO → e-mailu (e-mail musí byť jednoznačný). Pri existujúcom OOM musí sedieť s aktuálnym zákazníkom, inak chyba „prepis urobte na karte OOM“; prázdny zákazník pri zmene je povolený. Nové OOM zákazníka a typ potrebuje.
13. **Prázdna bunka = bez zmeny.** Číselníky sa zadávajú názvom (veľkosť písmen nerozhoduje, pomlčky – a — = -), skrytú hodnotu import neprijme; sadzba musí patriť k PDS. Vlastné polia podľa typu; „výber viacerých“ a „odkaz“ import nemení.
14. **Stav OOM import nemení**, nové OOM vznikne ako Pripravované; z krokov prechodu iba „Dodávka od“.
15. **Uloženie musí sedieť s náhľadom:** rovnaký súbor (odtlačok SHA-256) a rovnaké počty nové / zmena / bez zmeny / chyba; inak sa neuloží nič a treba nový náhľad. Uložia sa platné riadky, chybné nie. Záznam v `oom_import`, audit so zdrojom „import“.
16. **Súbor sa nikde neukladá;** súbor s chybnými riadkami (pôvodné bunky + Chyba + Pôvodný riadok) sa vytvorí až pri stiahnutí.
17. **Limit 5 000 riadkov a 10 MB** (Peter 13. 10., pôvodne 2 000 a 5 MB). Väčší súbor treba rozdeliť. Lokálne 5 000 riadkov: náhľad 6,0 s, uloženie 6,6 s; na Teste overené (Peter, 13. 10.).
18. **EIC v súbore viackrát:** chybné sú všetky riadky s týmto EIC (neuloží sa ani prvý), všetky idú do súboru s chybami. Súbor s chybami má vždy toľko riadkov, koľko chýb ukáže náhľad.
