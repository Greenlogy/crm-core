# Modul 3 – Produkty a cenníky: otázky na zadanie

Stav: 13. 10. 2026 · verzia 2 · zodpovedané; zadanie v `03-produkty.md`.
Verzia 2 je upravená po dohode o logike Obchod / Zmluva / Cena a po cenníkoch 2026.
Pri každej otázke je návrh. Stačí odpovedať „súhlas“ alebo napísať, ako to je inak.

## Rozhodnuté 13. 10. 2026 – logika záznamov

- **Obchod (deal)** je predajný proces: pipeline, fázy, ponuky, vlastník. Končí ako vyhraný alebo prehraný.
- **Zmluva** je záväzok: číslo, typ, stav, platnosť, OOM pod zmluvou, ceny. Vzniká z vyhraného obchodu.
- **Cena na zmluve** platí pre OOM a obdobie. Jej zdrojom je cenník alebo individuálna ponuka. Zmluva si cenu uloží, takže zmena cenníka ju neprepíše.
- **Obnova** je zatiaľ nová zmluva s odkazom na predošlú. Dodatky prídu neskôr, keď ich zvládne systém na tvorbu zmlúv.
- **B2B:**
  - Zmluva môže mať ľubovoľný počet OOM a každé OOM môže mať inú cenu (napr. jednotarif a dvojtarif).
  - Zmluvy sú oddelené na NN a VN. Ak má klient OOM na oboch napäťových úrovniach, vzniknú automaticky dve zmluvy.
- **Domácnosť:** 1 zmluva = 1 OOM spotreba, alebo 1 OOM spotreba + 1 OOM výroba.
- **Dodávka a výkup** sú vždy samostatné zmluvy. Výkupná zmluva môže mať viac výrobných OOM.
- **VBattery** je doplnková služba na zmluve o dodávke, iba pre domácnosti. Platí sa mesačný poplatok za OOM.
- **Green VIWA** je samostatná zmluva, ktorá nahrádza výkup. Má tri zložky:
  - mesačný poplatok za OOM,
  - násobiteľ hodnoty uloženia do virtuálnej peňaženky (Basic 0,75 / Plus 0,80 / Pro 0,85),
  - mesačný poplatok za kW inštalovaného výkonu (Basic 0,25 € / Plus 0,20 € / Pro 0,15 €).
- **Domácnosti majú dva cenníky**, s energopomocou a bez nej. Rozhoduje produkt, napr. „Green DD1 – ANO Energopomoc“ a „Green DD1 – NIE Energopomoc“.

## Čo vyplýva z cenníkov 2026

| Cenník | Platí od | Obsah |
| --- | --- | --- |
| Domácnosti s energopomocou | 1. 1. 2026 | ZEM 1,50 €/mes., Green DD1–DD8: mesačná platba za OM 1,50 €, VT a NT €/MWh |
| Domácnosti bez energopomoci | 1. 1. 2026 | rovnaká štruktúra, ceny vyššie |
| VBattery (časť cenníkov domácností) | 1. 4. 2026 | STANDARD 1,80 €, PREMIUM 4,80 €, MAX 9,53 € mesačne s DPH; GreenCar a GreenShare pre PREMIUM a MAX |
| Malé podniky (do 30 MWh/rok) | 1. 1. 2026 | Green DMP1–DMP11: mesačná platba za OM 1,50 €, VT a NT €/MWh |
| Green VIWA | 1. 10. 2025 | Basic 3,90 €, Plus 6,90 €, Pro 9,90 € mesačne bez DPH; aktivačný bonus 25 / 50 / 75 GreenCredit; expirácia 12 / 24 / 24 mesiacov |

Postrehy:
- **Energopomoc:** cenník s energopomocou je pri všetkých sadzbách nižší o rovnakých **31,24 €/MWh**, pri VT aj NT.
- **Dve sadzby DPH:** elektrina a ZEM majú **19 %**, služby VBattery a VIWA **23 %**. Sadzba DPH preto patrí k produktu.
- **Ceny majú 4 desatinné miesta** (napr. 116,2426 €/MWh) a CRM ich musí uložiť presne.

## A. Doplnenie k logike zmlúv
1. **Domácnosť so spotrebou aj výrobou:** výrobné OOM je v tej istej zmluve, lebo ide o VBattery (bez platby za výkup). Ak domácnosť chce výkup za peniaze, je to samostatná výkupná zmluva. Je to tak?
2. **Malé podniky (DMP):**
   - Platí aj pre ne zmluva NN/VN, teda viac OOM na zmluve?
   - Alebo jedna zmluva na jedno OOM ako pri domácnostiach?

## B. Produkty a cenníky
3. **Produkt = riadok cenníka viazaný na sadzbu distribúcie.**
   - Green DD1–DD8 zodpovedajú D1–D8 (dvakrát: ANO a NIE energopomoc), Green DMP1–DMP11 zodpovedajú sadzbám C.
   - Pri zakladaní zmluvy CRM ponúkne produkt podľa sadzby OOM (D3 → Green DD3). Súhlas?
   - Prosím o presné párovanie DMP1–DMP11 na sadzby. Náš číselník má C1–C10 a DMP9 nemá v cenníku cenu.
4. **Energopomoc:**
   - Návrh: príznak „nárok na energopomoc ANO/NIE“ na OOM domácnosti a CRM podľa neho ponúkne správny cenník.
   - Kto príznak mení a čo sa stane, keď zákazník nárok získa alebo stratí počas roka? Dostane novú cenu od dátumu zmeny?
   - Je to iná vec než pole „cenová regulácia“ na OOM, alebo to isté?
5. **Verzie cenníka:** cenník má platnosť od – do. Nový cenník (napr. „Domácnosti 2027“) je nová verzia, staré verzie ostávajú v histórii. Súhlas?
6. **Prechod na nový cenník:**
   - Návrh: domácnosti a malé podniky so zmluvou na neurčito prejdú na nový cenník hromadne. CRM pridá novú cenu od dátumu účinnosti na všetky dotknuté zmluvy a pripraví zoznam na oznámenie zákazníkom.
   - Alebo niektorí ostávajú pri starej cene (napr. fixácia na 2 roky)?
7. **Hranica 30 MWh pre malé podniky:** má CRM pri plánovanej spotrebe nad 30 MWh varovať, že cenník neplatí a treba individuálnu ponuku?
8. **Upratanie dnešného stavu:**
   - Claude Code vytiahne z HubSpotu (iba čítanie) zoznam 41 produktov a 57 kódov zmluvných cien s počtom použití.
   - Ty určíš, ktoré ostávajú a ako sa zlúčia. Súhlas?

## C. VBattery a VIWA
9. **VBattery programy:**
   - Cenník má 3 programy, HubSpot 6. Bežia ešte staré programy u existujúcich zákazníkov? Ak áno, evidujeme ich ako ukončené (bez predaja nových)?
10. **VBattery – väzba:**
    - Viaže sa na výrobné OOM domácnosti (podmienka: výrobné miesto v bilančnej skupine Greenlogy)?
    - Môže byť na zmluve len jeden program?
11. **GreenCar a GreenShare:**
    - Návrh: parametre (konverzia 400 / 300 kWh → voucher 25 €, poplatok 7,5 % / 5 % z prevedených kWh) evidujeme pri programe v cenníku. CRM ich nepočíta, počíta to fakturácia.
    - Vouchery a odporúčania (Growthdrive) patria do modulu Marketing. Súhlas?
12. **VIWA – štandardné hodnoty:**
    - Násobiteľ (0,75 / 0,80 / 0,85) a poplatok za kW (0,25 / 0,20 / 0,15 €) v PDF cenníku nie sú. Sú to pevné hodnoty balíka, alebo ich obchodník môže v ponuke zmeniť?
    - „Poplatok za odchýlku a konverzný kurz v zmysle cenovej ponuky“ sú vždy individuálne pre zákazníka?
13. **VIWA – kW inštalovaného výkonu:** berie sa z OOM (výkon zdroja) a počíta sa za každé výrobné OOM zmluvy zvlášť?

## D. Ceny mimo cenníka
14. **Cenové modely:**
    - FIX, SPOT + aditív, kombinácia (časť fix, časť spot). Ktoré používate a pre koho (B2B dodávka, výkup, veľkoobchod)?
    - Individuálna cena sa zadá na zmluve pre každé OOM. Detail (nákup, marža, schvaľovanie) bude v module 4.
15. **Zložky individuálnej ceny:**
    - VT/1T, NT, aditív [€/MWh], aditívny koeficient [%], cena odchýlky, mesačná platba za OM, ZEM. Čo presne je aditívny koeficient a kedy sa používa?
    - Má aj B2B zmluva ZEM? Chýba niečo?
16. **Výkup elektriny:** aký je model ceny výkupu (fix, spot mínus odpočet, percento zo spotu…) a aké poplatky sa pri výkupe účtujú?
17. **Green Solar (inštalácia FVE):** návrh – samostatný druh obchodu s produktom „inštalácia FVE“ (cena diela, záloha, DPH, provízia partnera NEP). Alebo to evidujete inde?

## E. Správa cenníkov a DPH
18. **Kto tvorí a schvaľuje cenník** (Nákup, CEO)? Kto ho môže zmeniť?
19. **DPH:**
    - Ceny sa ukladajú bez DPH a sadzba DPH je vlastnosť produktu (elektrina a ZEM 19 %, služby 23 %). Cena s DPH sa dopočíta a v ponuke domácnosti sa zobrazí.
    - VBattery má v cenníku iba ceny s DPH. Uložíme cenu bez DPH (napr. 1,46 € → 1,80 €), alebo má byť pevná cena s DPH?
20. **Regulované poplatky** (distribúcia, TPS, odvod do NJF, spotrebná daň) CRM nepočíta, v ponuke ich uvedie iba informatívne. Súhlas?

## Na neskôr (modul 4 Zmluvy a ceny)
- Individuálne B2B ceny: nákupná cena z Cockpitu, nákupné tranže, marža, hranice a schvaľovanie výnimiek.
- Automatické rozdelenie OOM do zmlúv NN a VN.
- Väzba obnovy na predošlú zmluvu; dodatky.
- Výpočet marže pri SPOT zmluvách.
- Vzorec nákupnej ceny „cena_obchod“ (vážený priemer BL/PL + 8 €/MWh): overiť, či ho HubSpot počíta správne.
