# Modul 4 – Zmluvy a ceny: otázky na zadanie

Stav: 13. 10. 2026 · kolá 1 a 2 zodpovedané; zadanie v `04-zmluvy.md`.

## Odpovede z kola 1 (13. 10. 2026)

**A. Zmluva**
- Zmluvy sa tvoria v systéme **Office portal**. Generuje číslo, PDF aj podpisovanie (fyzicky alebo elektronicky odkazom). Zatiaľ nemá API.
- **Číslovanie:**
  - výkup: rok + `VYRP` + poradové číslo (`26VYRP075`),
  - VIWA: rok + `VIWP` + poradové číslo (`26VIWP0135`),
  - dodávka firmy a domácnosti: `11` + rok + poradové číslo (`1120262000`), typ zmluvy PO alebo FO.
- **Fázy v Office portáli:** rozpracovaná → pripravená na odoslanie → fyzické alebo elektronické podpisovanie → finálne podpísaná → ukončená. Fázy mení front office; pri elektronickom podpise sa menia samy.
- **Každá zmena trvania alebo ceny je nová zmluva**, aj predĺženie. Platnosť začína dňom podpisu, účinnosť dňom začatia dodávky.
- **NN a VN sú samostatné zmluvy.** Dôvod je rezervovaná kapacita: istič platí minimálne rok, rezervovaná kapacita sa dojednáva na mesiac, štvrťrok alebo rok.
- **Trvanie:** rok, viac rokov alebo napríklad pol roka.
- **Obsah zmluvy:** údaje zákazníka, kontaktné osoby, ceny, odberné alebo výrobné miesta, pri domácnosti VBattery. PDF sa nahráva do Office portálu.

**B. Cena**
- V zmluve je buď odkaz na cenník (domácnosť, malý podnik, VIWA), alebo dojednaná cena FIX či SPOT + aditív v €.
- Pri viacročnej zmluve je cena uvedená pre každý rok zvlášť, aj keď je rovnaká.
- Výkup: FIX, SPOT − aditív v € alebo SPOT − aditív v %.
- Mesačná platba za OM: firmy 5 €, malé podniky 1,50 € podľa cenníka, výkup bez poplatku.
- Zaradenie do cenovej regulácie alebo vyradenie z nej počas roka vytvorí časový rez s novou cenou.

**D. Programy a ostatné zmluvy**
- VBattery je súčasťou zmluvy o dodávke, VIWA je samostatná zmluva.
- Veľkoobchod nemá zmluvu, iba konfirmáciu k rámcovej zmluve EFET.
- Green Solar je zmluva o dielo vo Worde, mimo Office portálu. V CRM ju chceme kvôli marži, ale ako samostatnú neskoršiu fázu.

**E. Práva**
- Zmluvu robí a generuje obchodník sám, fázy mení front office.
- Provízie sa dnes evidujú v HubSpote a Sales portáli. Počítajú sa z pridanej hodnoty: cena pre klienta musí byť vyššia ako denná cena alebo ako cena z výnimky od obchodného riaditeľa.
- Nové zmluvy sa dnes do HubSpotu nahrávajú importom z Excelu, prolongácie zadávajú kolegovia ručne.

**C. Nákup a marža** (podklad „K bodu C“, 13. 10. 2026)
- **SPOT (firmy, domácnosti):**
  - marža = aditív × objem + platba za OM × počet OM × 12 − minimálny aditív × objem,
  - pri domácnosti sa výnos navyšuje o ZEM a VBattery,
  - minimálny aditív je 6 € pre obchodníkov a 0 € pre manažérov; nižší schvaľuje CEO alebo obchodný riaditeľ.
- **FIX (firmy, domácnosti):**
  - marža = (fixná cena − nákupná cena) × objem + platba za OM × počet OM × 12,
  - nákupná cena pre obchodníka = (BL × 80 + PL × 20) / 100 + 4 € riziko a odchýlka + 4 € naša marža,
  - parametre nastavuje Greenlogy v Sales portáli; obchodník cenu prepisuje ručne do HubSpotu a kontroluje sa podľa dátumu,
  - domácnosti s energopomocou majú nákupnú cenu 72,40 € pre rok 2026 (určuje Ministerstvo hospodárstva),
  - zmluvy manažérov a domácnosti bez energopomoci majú nákupnú cenu odhadom zadanú ručne,
  - Cockpit má všetky nakúpené tranže a odhad dokupu, takže vie odhadnúť nákupnú cenu na rok.
- **VIWA:**
  - marža = (aditív − 100) × objem + platba za OM × počet × 12 + platba za kapacitu × výkon × 12 − minimálny aditív (0) × objem,
  - VIWA treba vedieť spárovať so zmluvou o dodávke toho istého zákazníka.
- **Výkup:**
  - všetky nákupné kontrakty sa evidujú v Cockpite (denník kontraktov, pokrytie portfólia),
  - lokálne zdroje majú minimálny aditív 0 €,
  - marža = (aditív − minimálny aditív) × objem; pri aditíve v % zatiaľ nie je jasné, ako ju počítať.
- **Spoločné:**
  - marža sa vždy počíta na ročnej bilancii,
  - tranže sú FIX, SPOT a dočasne SEAS (Slovenské elektrárne, domácnosti s energopomocou); mohli by sa dopĺňať automaticky podľa produktu,
  - plán výkupu lokálneho zdroja = výkon × 4 h × 365 × 0,1 a mal by sa vyplniť sám.
- **Cockpit:** po vypnutí HubSpotu musí dátový tok do Cockpitu ísť z CRM. Do Cockpitu sa dá podľa potreby dorobiť API.

## Zistenia zo vzorových zmlúv
1. **Firemná zmluva** na dobu určitú (cena 2027) sa podľa čl. VI **automaticky predlžuje o 12 mesiacov**, ak ju nikto nevypovie 3 mesiace vopred. Cena je však v zmluve iba na rok 2027.
2. **Výkupná zmluva** je na **dobu neurčitú** a má cenu (aditív 30 €/MWh) iba na rok 2026. Zmena ceny sa riadi obchodnými podmienkami výkupu (čl. 3), nie novou zmluvou.
3. **Zmluva VIWA** (čl. 5.2): mesačná platba je **za jeden VIWA účet bez ohľadu na počet odovzdávacích miest**. Zadanie modulu 3 má „za OOM“.
4. Zmluvy majú polia **Uzatvoril** (obchodník) a **Dôvod uzatvorenia** (napr. Akvizícia).
5. Technická špecifikácia uvádza pre každé OOM **zmluvné množstvo VT/JT a NT**, produkt (napr. „IN GREEN 1T“), sadzbu, istič, fázy a **predošlého dodávateľa s viazanosťou a výpovednou lehotou**.

## Kolo 2 – otázky

### Marža a ceny
1. **Dve čísla namiesto jedného:**
   - **Pridaná hodnota obchodníka** = predajná cena − cena pre obchodníka v deň ponuky (FIX: vzorec zo Sales portálu, SPOT: minimálny aditív, prípadne cena z výnimky). Z nej sa počíta provízia.
   - **Marža firmy** = predajná cena − skutočná nákupná cena roka (FIX: odhad z Cockpitu, SPOT: náklad na odchýlku a profil).
   - Dnes HubSpot ukazuje iba prvé číslo, v ktorom je navyše zahrnutá „naša marža“ 4 €. Chceš v CRM obe?
2. **Cenové parametre v CRM s históriou** (platné od dátumu):
   - pomer BL/PL, riziková prirážka, naša marža, minimálny aditív (obchodník / manažér), nákupná cena domácností s energopomocou na rok.
   - Mení ich admin alebo obchodný riaditeľ, každá zmena ide do auditu.
   - Ceny BL a PL denne z Cockpitu cez API. CRM potom vypočíta cenu pre obchodníka sám a pri ponuke a zmluve si ju uloží s dátumom, takže ručné prepisovanie a kontrola odpadnú.
   - Sales portál môže neskôr čerpať z CRM. Súhlas, alebo má výpočet ostať v Sales portáli?
3. **Výnimka z ceny:**
   - Obchodník požiada v CRM o cenu pod hranicou, schvaľuje CEO alebo obchodný riaditeľ, schválená výnimka sa uloží ku zmluve aj s menom schvaľovateľa.
   - Bez schválenia cenu pod hranicou nejde uložiť. Súhlas?
   - Kto je obchodný riaditeľ v tímoch CRM – nový príznak „schvaľuje ceny“?
4. **Nákupná cena pre zmluvy manažérov a domácnosti bez energopomoci:** odhadovaná nákupná cena roka z Cockpitu (API), aktualizovaná napr. týždenne. Súhlas?
5. **VIWA:**
   - Vysvetli prosím vzorec „(aditív − 100) × objem“ na príklade, napr. VIWA Plus s konverzným kurzom SPOT × 0,80.
   - Je mesačná platba za VIWA účet (ako v zmluve), alebo za OOM (ako v zadaní modulu 3)?
6. **Výkup s aditívom v %:** návrh marže = % × očakávaná cena SPOT pre FVE (capture price) na rok × objem. Očakávaná cena z Cockpitu. Súhlas?

### Zmluvy a obdobia
7. **Automatické predĺženie firemnej zmluvy o 12 mesiacov:** akú cenu má zákazník po predĺžení, keď je v zmluve iba cena na rok 2027? Návrh: CRM pri predĺžení vytvorí nové obdobie a upozorní obchodníka 4 mesiace pred koncom, aby dojednal novú zmluvu.
8. **Výkup na dobu neurčitú:** nová cena na ďalší rok vzniká oznámením podľa obchodných podmienok (nie novou zmluvou)? Potom má výkupná zmluva ceny po rokoch ako cenník.
9. **Objem pre maržu:** zmluvné množstvo VT/NT pri každom OOM z technickej špecifikácie. Pri viacročnej zmluve rovnaké pre každý rok? Pri polročnej zmluve iba za obdobie zmluvy?
10. **Dôvod uzatvorenia:** aké hodnoty používate (Akvizícia, Prolongácia, Prepis, Zmena ceny…)?

### Toky dát
11. **Office portal → CRM:**
    - Z čoho je dnešný Excel, ktorý nahrávaš do HubSpotu – export z Office portálu?
    - Návrh: CRM nahrá rovnaký export s náhľadom nové / zmena / chyba (ako import OOM). Zmluva sa tak nezadáva dvakrát a prolongácie pôjdu tiež importom.
    - Pošli mi prosím vzorový export (stačí so zmenenými menami).
12. **CRM → Cockpit:**
    - Ktoré údaje dnes tečú z HubSpotu do Cockpitu (cez Make)?
    - Návrh: CRM poskytne API so zmluvami po rokoch a OOM (objem, cenový model, cena, aditív, tranža FIX / SPOT / SEAS, marža). Claude Code môže dnešné toky zmapovať zo scenárov Make a z Cockpitu.
13. **Tranža automaticky:** FIX alebo SPOT podľa cenového modelu, SEAS pre domácnosti s energopomocou. Súhlas?

### Doplnky
14. **Plán výkupu lokálneho zdroja** = výkon × 4 × 365 × 0,1 sa vyplní sám, ručne sa dá prepísať (doplnok modulu 2). Súhlas?
15. **VIWA spárovaná so zmluvou o dodávke:** pole „súvisiaca zmluva“ a marža za oba spolu na karte zákazníka. Súhlas?

## Odpovede z kola 2 (13. 10. 2026)
1. Dve čísla áno. Marža firmy nie je viditeľná pre obchodníka.
2. Cenové parametre a výpočet ceny pre obchodníka v CRM. Sales portál ich neskôr prevezme z CRM.
3. Výnimky schvaľuje CEO alebo obchodný riaditeľ v CRM: súhlas. Príznak „schvaľuje ceny“: súhlas.
4. Nákupná cena pre zmluvy manažérov a domácnosti bez energopomoci = odhad z Cockpitu: súhlas.
5. **VIWA:**
   - platba je **za účet**,
   - do marže sa namiesto neznámeho SPOT použije odhad aditívu: konverzia × 0,75 → 25 €/MWh, × 0,80 → 20 €/MWh, × 0,85 → 15 €/MWh.
6. Výkup s aditívom v %: % × očakávaná cena SPOT pre FVE × objem: súhlas.
7. **Pri predĺžení sa takmer vždy dojedná nová cena a nová zmluva**, aj keď sa pôvodná automaticky predĺžila. Zákazník môže prejsť na základný firemný cenník pre podnikateľov (Peter ho pošle). Upozornenie pred koncom zmluvy: súhlas.
8. **Výkup na dobu neurčitú:**
   - cena ostáva rovnaká aj 10 rokov, lebo vychádza zo SPOT mínus aditív,
   - zmena ceny = nová zmluva.
9. Objem = zmluvné množstvo VT a NT, rovnaké pre každý rok; pri polročnej zmluve za obdobie zmluvy.
10. **Dôvod uzatvorenia:** Akvizícia, Retencia, Autoprolong, Prepis, Nové OOM.
11. **Excel na import do HubSpotu je export z fakturačného systému XM Trade**, bez cien. Ceny Peter dopĺňa ručne podľa Office portálu.
    - Office portal má vlastný export s cenami a výkonom zdroja v kW.
    - Exporty sa dajú párovať podľa EIC alebo čísla zmluvy.
    - Vzory oboch exportov sú priložené.
12. Do Cockpitu dnes tečie objem a celkový výnos dealov zo všetkých pipeline. Claude Code nech toky zmapuje.
13.–15. Súhlas (tranža automaticky, plán výkupu lokálneho zdroja, súvisiaca zmluva VIWA).
