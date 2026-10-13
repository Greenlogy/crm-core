# Modul 3 – Produkty a cenníky: zadanie

Verzia 0.3 · 13. 10. 2026 · **schválené Petrom** (v0.2 = odpovede O0–O6, v0.3 = O7).
Vychádza z odpovedí v `03-produkty-otazky.md` (verzia 2, 13. 10. 2026) a z cenníkov 2026. Stavia na moduloch 0 (Nastavenia), 1 (Zákazníci) a 2 (OOM).

## 1. Čo modul rieši

Katalóg produktov a programov, cenníky s verziami a pravidlá, podľa ktorých sa cena z cenníka dostane na zmluvu.
Nerieši zmluvy, individuálne ceny, nákup a maržu (modul 4) ani obchody a ponuky (modul 5).

## 2. Logika záznamov (rozhodnuté 13. 10. 2026)

| Záznam | Čo to je | Modul |
| --- | --- | --- |
| **Obchod** | predajný proces: pipeline, fázy, ponuky, vlastník; končí vyhraný / prehraný | 5 |
| **Zmluva** | záväzok: číslo, typ, stav, platnosť, OOM pod zmluvou | 4 |
| **Cena na zmluve** | cena pre OOM a obdobie; zdroj = cenník alebo individuálna | 4 |
| **Produkt** | čo predávame (Green DD3, VBattery PREMIUM, VIWA Pro…) | 3 |
| **Cenník** | verzia cien produktov s platnosťou od – do | 3 |

Pravidlá zmlúv, ktoré ovplyvňujú tento modul:
- **Obnova:** zatiaľ vzniká nová zmluva s odkazom na predošlú. Dodatky prídu neskôr.
- **B2B a malé podniky:** zmluva môže mať viac OOM a každé OOM môže mať inú cenu. Zmluvy sú oddelené na NN a VN.
- **Domácnosť:** 1 zmluva = 1 OOM spotreba, prípadne aj 1 OOM výroba (VBattery). Priamy výkup od domácností Greenlogy nerobí.
- **Dodávka a výkup** sú vždy samostatné zmluvy. Výkupná zmluva môže mať viac výrobných OOM.
- **VBattery** je doplnková služba na zmluve o dodávke domácnosti. Časom ju pre domácnosti nahradí VIWA.
- **Green VIWA** je samostatná zmluva a nahrádza výkup.

## 3. Katalóg produktov

| Kategória | Produkty | Cena |
| --- | --- | --- |
| Dodávka – domácnosti | Green DD1–DD8 – ANO Energopomoc, Green DD1–DD8 – NIE Energopomoc | cenník, alebo SPOT + aditív € |
| Dodávka – malé podniky | Green DMP1–DMP11 | cenník |
| Dodávka – firmy | Dodávka B2B | individuálna: FIX alebo SPOT + aditív €; mesačná platba za OM 5 € bez DPH |
| Výkup – firmy | Výkup B2B | individuálna: FIX, SPOT − aditív €, alebo SPOT − aditív % |
| Veľkoobchod | Veľkoobchod | individuálna: FIX alebo SPOT + aditív € |
| Služba ZEM | ZEM | cenník; platia iba domácnosti, za každé OOM spotreby mesačne |
| Virtuálna batéria | VBattery STANDARD, PREMIUM, MAX; AKU (dobieha) | cenník |
| Virtuálna peňaženka | Green VIWA Basic, Plus, Pro | cenník |
| Inštalácia FVE | Green Solar – zmluva o dielo | pevná cena za dielo |

**Údaje produktu:**
- názov, kód, kategória, segment (domácnosť / firma),
- sadzba DPH: elektrina a ZEM 19 %, služby 23 %,
- povolené cenové modely,
- väzba na sadzby distribúcie (časť 5),
- cenová regulácia ANO/NIE (domácnosti: s energopomocou / bez nej),
- stav.

**Stavy produktu:**
- **Predáva sa.**
- **Dobieha:** existujúce zmluvy bežia, nové sa nepredávajú. Príklad: VBattery AKU.
- **Ukončený.**

Produkt sa nikdy nemaže, iba sa ukončí.

## 4. Cenové modely

| Model | Zložky | Použitie |
| --- | --- | --- |
| **Cenník** | podľa produktu: VT, NT [€/MWh], mesačná platba za OM, mesačný poplatok programu | domácnosti, malé podniky, VBattery, VIWA, ZEM |
| **FIX** | VT/1T, NT [€/MWh]; pri dodávke firmám aj mesačná platba za OM | firmy dodávka, výkup, veľkoobchod |
| **SPOT + aditív €** | prirážka k spotu [€/MWh] | domácnosti, firmy dodávka, veľkoobchod |
| **SPOT − aditív €** | zľava zo spotu [€/MWh] | výkup |
| **SPOT − aditív %** | zľava zo spotu [%] | výkup |

- Aditívny koeficient = prirážka k spotu pri odbere, alebo zľava zo spotu pri výkupe (v € alebo %). V CRM sa volá **aditív** a má jednotku €/MWh alebo %.
- Kombinácia FIX a SPOT na jednej cene sa nepoužíva.
- **Mesačná platba za OM pri firmách s individuálnou cenou je 5 € bez DPH.** Hodnotu spravuje admin ako súčasť cenníka „Poplatky B2B“.
- Výkup nemá žiadny iný poplatok (ani za OOM).
- Samostatná cena odchýlky sa nepoužíva.
- Individuálne ceny sa zadávajú na zmluve v module 4. Modul 3 iba určuje, aké modely má produkt povolené.

## 5. Párovanie produkt – sadzba distribúcie

CRM pri zmluve ponúkne produkt podľa sadzby OOM a cenovej regulácie.

| Produkt | ZSD | VSD | SSD a miestne DS |
| --- | --- | --- | --- |
| Green DD1–DD8 | D1–D8 | D1–D8 | D1–D8 |
| Green DMP1–DMP8 | C2-X3 ⚠ | X3-C2 ⚠ | C1–C8 |
| Green DMP9 | C9 | C9 | C9 |
| Green DMP10 | C2-X3 ⚠ | X3-C2 ⚠ | C10 |
| Green DMP11 | C11 | C11 | C11 |

⚠ ZSD a VSD majú pre 9 taríf dodávky (DMP1–DMP8, DMP10) jedinú distribučnú sadzbu (C2-X3, resp. X3-C2), bez ohľadu na to, či je meranie jednotarifné, dvojtarifné alebo ide o vykurovanie. CRM preto produkt zo sadzby neurčí:
- CRM ponúkne iba produkty povolené pre sadzbu OOM (tu DMP1–DMP8 a DMP10) a obchodník vyberie správny.
- Pomôcka: ak má OOM plánovanú spotrebu NT, CRM navrchu ukáže dvojtarifné produkty (DMP4–DMP8), inak jednotarifné (DMP1–DMP3, DMP10). Výber ostáva na obchodníkovi.
- Pri SSD a miestnych DS určí sadzba produkt jednoznačne a CRM ho vyplní sám.
- Miestne distribučné sústavy majú párovanie ako SSD (odpoveď O1).
- Číselník sadzieb treba doplniť o **C11** (dnes C1–C10).
- Párovanie spravuje admin v Nastaveniach, lebo PDS môžu sadzby meniť.

## 6. Cenník a verzie

- Cenník (napr. „Domácnosti – NIE Energopomoc“) má **verzie s platnosťou od – do**, napr. „2026“ od 1. 1. 2026 a „2027“ od 1. 1. 2027. Staré verzie ostávajú v histórii.
- **Položka cenníka** = produkt + ceny: VT, NT [€/MWh], mesačná platba za OM [€], prípadne mesačný poplatok programu.
- **Ceny sa ukladajú bez DPH na 4 desatinné miesta.** Cena s DPH sa dopočíta podľa sadzby DPH produktu a zobrazí sa v ponuke domácnosti.
- **Nová verzia** vznikne kópiou predošlej, admin upraví ceny a nastaví dátum účinnosti.
- **Schválenie:** verzia je Návrh, kým ju admin neschváli. Po schválení sa už nedá meniť, opraviť sa dá iba novou verziou.
- **Cenníky spravuje iba admin.** Všetci ostatní vrátane externých obchodníkov vidia platné a budúce verzie.

### Automatický prechod na nový cenník

- Zmluvy, ktorých cena pochádza z cenníka, prejdú na novú verziu **automaticky** od dátumu jej účinnosti.
- CRM pridá na zmluvu novú cenu od dátumu účinnosti. Stará cena ostane v histórii.
- CRM pripraví zoznam dotknutých zákazníkov a export na oznámenie.
- Zmluvy s individuálnou cenou alebo SPOT + aditív sa nemenia.
- Mechanizmus zmeny cien na zmluvách sa postaví v module 4. Modul 3 definuje pravidlo.

## 7. Cenová regulácia (energopomoc a malé podniky)

- Na OOM ostáva pole **Cenová regulácia ANO/NIE** z modulu 2 (bez premenovania). Význam závisí od segmentu:
  - **domácnosť:** ANO = nárok na energopomoc → CRM ponúkne produkt „– ANO Energopomoc“, inak „– NIE Energopomoc“,
  - **firma:** ANO = nárok na cenník pre malé podniky (Green DMP).
- Príznak mení Greenlogy ručne podľa informácie z Ministerstva hospodárstva. Neskôr sa bude dopĺňať importom z XM Trade (fakturácia).
- Pri zmene príznaku počas zmluvy sa zmení produkt a cena od dátumu zmeny (riešenie v module 4).

## 8. Malé podniky (do 30 MWh)

- Cenník pre malé podniky platí, keď **súčet plánovanej spotreby všetkých OOM zmluvy** je najviac 30 MWh za rok.
- Pri vyššom súčte CRM varuje: cenník neplatí, treba individuálnu ponuku. Varovanie neblokuje uloženie.
- OOM s cenou z cenníka pre malé podniky má mať cenovú reguláciu ANO; ak nemá, CRM tiež varuje.
- **Green DMP9 (C9, nemeraný odber)** má iba pevnú mesačnú platbu, bez ceny za MWh.

## 9. Programy VBattery a VIWA

Všetky parametre sú pevné pre balík, nič nie je individuálne. Parametre CRM eviduje, výpočty (kredity, vouchery, poplatky v kWh) robí fakturácia.

**VBattery** – iba domácnosti, na výrobnom OOM zmluvy o dodávke, jeden program na zmluvu.

| Program | Mesačný poplatok | GreenCar | GreenShare |
| --- | --- | --- | --- |
| STANDARD | 1,80 € s DPH | – | – |
| PREMIUM | 4,80 € s DPH | 400 kWh → voucher 25 € | 7,5 % z prevedených kWh |
| MAX | 9,53 € s DPH | 300 kWh → voucher 25 € | 5 % z prevedených kWh |
| AKU | dobieha | | |

Ceny sa uložia bez DPH na 4 desatinné miesta: STANDARD 1,4634 €, PREMIUM 3,9024 €, MAX 7,7480 € (sadzba DPH 23 %).

**Green VIWA** – samostatná zmluva, poplatky sa počítajú za každé výrobné OOM zmluvy.

| Balík | Mesačne za OOM | Konverzný kurz (hodnota uloženia) | Poplatok za odchýlku – mesačne za kW inštalovaného výkonu | Aktivačný bonus | Expirácia kreditu | GreenCar |
| --- | --- | --- | --- | --- | --- | --- |
| Basic | 3,90 € | SPOT × 0,75 | 0,25 € | 25 GreenCredit | 12 mesiacov | nie |
| Plus | 6,90 € | SPOT × 0,80 | 0,20 € | 50 GreenCredit | 24 mesiacov | áno |
| Pro | 9,90 € | SPOT × 0,85 | 0,15 € | 75 GreenCredit | 24 mesiacov | áno |

- Ceny sú bez DPH. Všetky balíky majú GreenShare.
- Inštalovaný výkon sa berie z OOM (výkon zdroja, modul 2).

Benefity (GreenCar vouchery, odporúčania Growthdrive) patria do modulu Marketing.

## 10. Regulované poplatky

Distribúcia, TPS, odvod do NJF a spotrebnú daň Greenlogy iba refakturuje. CRM ich nepočíta. Ponuka obsahuje iba poznámku, že regulované ceny distribúcie a OKTE sú rovnaké pre všetkých dodávateľov.

## 11. Obrazovky

- **Cenníky:** zoznam cenníkov s aktuálnou verziou a stavom (platný / budúci / návrh).
- **Detail verzie cenníka:**
  - tabuľka produktov s cenami bez DPH a s DPH,
  - tlačidlá Nová verzia (kópia), Schváliť, Export,
  - pri budúcej verzii počet zmlúv, ktoré na ňu prejdú.
- **Produkty:** zoznam s kategóriou, segmentom, sadzbou DPH, cenovými modelmi a stavom.
- **Programy:** VBattery a VIWA s parametrami balíkov.
- **Nastavenia → Párovanie sadzieb:** tabuľka z časti 5 (iba admin).
- Hlavné menu: položka **Cenníky** (vidia všetci), úpravy iba admin.

## 12. Príklady dopadov

1. **Nová domácnosť bez energopomoci (cenová regulácia NIE), sadzba D2 (ZSD).** CRM ponúkne Green DD2 – NIE Energopomoc za 120,7275 €/MWh bez DPH (143,6657 € s DPH), mesačná platba za OM 1,50 € a ZEM 1,50 €. Zmluva si cenu uloží.
2. **Nový cenník 2027.** Admin skopíruje verziu 2026, upraví ceny, nastaví účinnosť od 1. 1. 2027 a schváli. CRM ukáže počet zmlúv, ktoré prejdú (napr. „prejde 4 000 zmlúv“), a vytvorí zoznam na oznámenie. 1. 1. 2027 dostanú všetky cenníkové zmluvy novú cenu, ceny 2026 ostanú v histórii.
3. **Domácnosť stratí nárok na energopomoc.** Servis zmení cenovú reguláciu na OOM na NIE od 1. 3. a zmluva dostane od 1. 3. produkt a cenu „– NIE Energopomoc“.
4. **Malý podnik s 3 OOM na SSD** (sadzby C2, C10, C11, cenová regulácia ANO) s plánovanou spotrebou spolu 24 MWh. CRM ponúkne DMP2, DMP10 a DMP11 a mesačnú platbu 1,50 € za každé OM. Keby bol súčet 34 MWh, CRM upozorní na individuálnu ponuku.
5. **Domácnosť s FVE** si objedná VBattery PREMIUM. Program sa pridá na výrobné OOM zmluvy o dodávke. Na zmluve je 4,80 € mesačne s DPH a parametre GreenCar a GreenShare z cenníka.
6. **Firma s FVE si zvolí VIWA Plus.** Vznikne samostatná zmluva s 2 výrobnými OOM (50 kW a 30 kW). Mesačne platí 2 × 6,90 € + 80 kW × 0,20 € = 29,80 € bez DPH.
7. **Pokus o úpravu schváleného cenníka:** CRM ho nedovolí a ponúkne novú verziu.
8. **Malý podnik na ZSD so sadzbou C2-X3** a plánovanou spotrebou NT 4 MWh. CRM ponúkne DMP1–DMP8 a DMP10, navrchu dvojtarifné DMP4–DMP8. Obchodník vyberie DMP4.
9. **Firma s individuálnou cenou FIX, 12 OOM.** Na zmluve je FIX VT/NT podľa ponuky a mesačná platba 12 × 5 € = 60 € bez DPH. ZEM sa neúčtuje.

## 13. Upratanie dnešného stavu

Claude Code vytiahne z HubSpotu (iba čítanie, bez osobných údajov) zoznam 41 produktov a 57 kódov zmluvných cien s počtom použití do `exports/`. Peter určí, ktoré ostávajú a ako sa namapujú na katalóg z časti 3. Nič sa nenahráva.

## 14. Rozhodnuté a otvorené otázky

Rozhodnuté 13. 10. 2026:
- **O1** Miestne distribučné sústavy majú párovanie ako SSD.
- **O2** Pole „cenová regulácia“ ostáva: pri domácnosti znamená nárok na energopomoc, pri firme nárok na cenník pre malé podniky.
- **O3** Ceny VBattery bez DPH na 4 desatinné miesta.
- **O4** VIWA: konverzný kurz = SPOT × 0,75 / 0,80 / 0,85; poplatok za odchýlku = 0,25 / 0,20 / 0,15 € za kW mesačne.
- **O5** DMP9 (C9, nemeraný odber) má iba pevnú mesačnú platbu.
- **O6** Firmy s individuálnou cenou platia 5 € bez DPH mesačne za OM. Samostatná cena odchýlky sa nepoužíva.

- **O7** ZSD a VSD majú pre DMP1–DMP8 a DMP10 jedinú sadzbu (C2-X3, resp. X3-C2). Produkt vyberá obchodník (časť 5).

Otvorené: žiadne.

## 15. Na neskôr

- **Modul 4:**
  - individuálne ceny, nákup z Cockpitu, marža a schvaľovanie,
  - delenie zmlúv na NN a VN,
  - mechanizmus zmeny cien na zmluvách (nový cenník, energopomoc),
  - väzba obnovy na predošlú zmluvu a dodatky.
- **Modul 5:** obchody a ponuky, Green Solar ako samostatný druh obchodu (zmluva o dielo).
- VIWA pre domácnosti ako náhrada VBattery.
- Import príznaku energopomoci z XM Trade.
