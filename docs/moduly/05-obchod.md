# Modul 5 – Obchod a ponuky: zadanie

Verzia 0.2 · 14. 10. 2026 · **schválené Petrom** (v0.2 = rozhodnuté P1–P3).

Podklady:
- odpovede v `05-obchod-otazky.md` (kolá 1 a 2, 14. 10. 2026),
- 5 vzorových ponúk z HubSpotu,
- vzorový e-mail k ponuke,
- snímky formulára zmluvy v Office portáli,
- zdrojový kód Sales portálu.

Stavia na moduloch 0–4.

## 1. Čo modul rieši

Predajný proces od príležitosti po podpísanú zmluvu:
- pipeline,
- ponuky s cenou pre obchodníka a schvaľovaním výnimiek,
- PDF a stránka ponuky s elektronickou akceptáciou,
- odosielanie e-mailov z CRM cez Google Workspace,
- podklady pre zmluvu v Office portáli,
- párovanie zmlúv z importu,
- úvodná obrazovka obchodníka a provízie.

Modul nahrádza HubSpot (dealy, quotes, e-maily) aj Sales portál. Po ňom ide CRM do ostrej prevádzky.

**Nerieši:**
- hromadné a marketingové e-maily (marketing modul, Brevo),
- hovory z CloudTalku (modul servisu),
- úlohy (ostávajú v GreenTracku),
- Green Solar a EFET (neskôr),
- tvorbu zmlúv (ostáva v Office portáli).

## 2. Tok obchodu

```
Príležitosť ─► Cenová ponuka ─► Vyjednávanie ─► Akceptácia ─► Vyhraté
     │              │                │              │           ▲
     │        ponuka (varianty)  nová verzia   klik zákazníka   │ import zmluvy
     │        výnimka? schválenie               podklady pre     │ z Office portálu
     │                                          zmluvu ──────────┘ (párovanie podľa EIC)
     └──────────────────────────────► Prehraté (dôvod)
```

- **Obchod** je predajný proces. Končí ako Vyhraté alebo Prehraté.
- **Zmluva** vzniká v Office portáli a do CRM prichádza importom (modul 4). Jeden obchod môže mať viac zmlúv, napr. NN a VN. Väzba obchod : zmluva je **1 : n**.

## 3. Pipelines a štádiá

| Pipeline | Pre koho |
| --- | --- |
| B2B dodávka | firmy, obce, organizácie |
| B2B výkup | výrobcovia (FIX, SPOT, lokálny zdroj) |
| Green VIWA B2B | VIWA |
| B2C | iba domácnosti, ktoré rieši obchodník (napr. FVE s VBattery). Bežné domácnosti z webu a call centra obchod nemajú. |

**Štádiá** sú vo všetkých pipelines rovnaké:

| Štádium | Pravdepodobnosť | Povinné pri vstupe |
| --- | --- | --- |
| Príležitosť | 10 % | zákazník, vlastník, zdroj |
| Cenová ponuka | 30 % | aspoň jedno OOM, plánovaná spotreba alebo výroba |
| Vyjednávanie | 50 % | – |
| Akceptácia | 90 % | akceptovaná ponuka (variant) |
| Vyhraté | 100 % | spárovaná zmluva (nastaví sa samo, časť 10) |
| Prehraté | 0 % | dôvod prehry |

- **Pravdepodobnosť** slúži iba na odhad budúcej pridanej hodnoty v prehľadoch.
- **Dôvody prehry** sú číselník: cena, zostal u dodávateľa, iný dodávateľ, nereaguje, nesplnil podmienky, iné. Pri každom je poznámka. Číselník spravuje admin.
- **Zdroj** je číselník: vlastný kontakt, web, call centrum, odporúčanie, partner, obnova.

## 4. Obchod

**Polia:**
- zákazník (firma alebo osoba),
- pipeline, štádium, vlastník, zdroj,
- očakávané uzavretie, začiatok dodávky,
- OOM s plánovanou spotrebou VT/NT alebo výrobou,
- kontaktné osoby s rolou,
- ďalší krok s dátumom,
- predošlá zmluva (pri obnove), poznámky.

**Pravidlá:**
- **Viac obchodov:** zákazník môže mať súčasne viac otvorených obchodov typu dodávka aj výkup.
- **NN a VN:** zákazník s OOM na NN aj VN má vždy jeden obchod a jednu ponuku. Na dve zmluvy sa delí až v Office portáli (časť 9).
- **Nové OOM:**
  - Obchodník zadá EIC a základné údaje: sadzbu, napäťovú úroveň, plánovanú spotrebu VT/NT, prípadne výkon zdroja.
  - OOM vznikne v stave **Pripravované**, zatiaľ bez zmluvy. Kontrola EIC je rovnaká ako v module 2.
  - Pri prehre sa OOM, ktoré nie je na žiadnej zmluve, označí ako Neaktívne.
- **Obnova:** nočný beh z modulu 4 pri upozornení 4 mesiace pred koncom zmluvy založí aj obchod „Obnova – {číslo zmluvy}“:
  - štádium Príležitosť, vlastník = obchodník zmluvy,
  - zdroj = obnova,
  - OOM a spotreby predvyplnené zo zmluvy.

  Obchod sa nezaloží pre domácnosti, pre zmluvy s nástupcom ani vtedy, keď už otvorený obchod „Obnova“ k zmluve existuje.
- **Ďalší krok:**
  - V deň kroku príde upozornenie do zvončeka.
  - V zozname sa zvýrazní obchod bez ďalšieho kroku alebo s krokom po termíne.
- **Časová os obchodu** zobrazuje poznámky, odoslané a prijaté e-maily, zmeny štádia, ponuky a ich verzie, otvorenia stránky ponuky, akceptáciu, výnimky a spárované zmluvy.

### 4.1 Overenie firmy a vlastník (zo Sales portálu)

- **Vyhľadanie:** pri zakladaní obchodu obchodník hľadá firmu podľa IČO alebo názvu (našepkávanie z Finstatu a z CRM). CRM ukáže:
  - či firma už je v CRM a či je zákazník (má zmluvu),
  - kto je jej vlastník,
  - otvorené obchody firmy a ich vlastníkov,
  - údaje z Finstatu: tržby, zisk, zamestnanci, sídlo, vznik, dlhy, nedoplatky, konkurz, platobný rating a Altmanovo Z-skóre s pásmami (pod 1,23 riziko úpadku, 1,23–2,90 šedá zóna, nad 2,90 stabilná).
- **Nová firma:** ak firma v CRM nie je, založí sa z Finstatu jedným klikom s vlastníkom = obchodník.
- **Konflikt vlastníka** („aby si obchodníci neliezli do kapusty“):
  - Ak firmu vlastní iný obchodník, nový obchod nejde založiť.
  - Obchodník môže **požiadať o pridelenie** s dôvodom.
  - Schvaľuje manažér alebo obchodný riaditeľ. Pôvodný vlastník dostane upozornenie.
- **Výstrahy z Finstatu:**
  - Na firme, obchode aj pri ponuke sa zobrazí výstraha pri dlhoch, nedoplatkoch, konkurze, platobnom ratingu E/X alebo Z-skóre pod 1,23.
  - **Konkurz alebo rating E/X** vyžaduje pred odoslaním ponuky schválenie (časť 6).

## 5. Ponuka

### 5.1 Štruktúra

- **Ponuka** patrí k obchodu. Má číslo, verziu, jazyk (SK/EN), platnosť, kontaktnú osobu, stav a jeden alebo viac **variantov**.
- **Variant**, napr. „FIX 2027“, „FIX 2027–2028“ alebo „SPOT + aditív“, obsahuje:
  - typ ceny: FIX, SPOT + aditív alebo kombinácia,
  - obdobie dodávky (od – do alebo na neurčito),
  - tranžu (určí sa sama ako v module 4),
  - **ceny pre každé OOM a rok**: VT/1T, NT alebo aditív, pri výkupe cenu alebo aditív (€ alebo %),
  - pri VIWA balík a výkon zdroja,
  - premenné podmienky (časť 7.2).
- Zákazník prijme **jeden** variant.
- **Číslo:** `P26-000123`, nová verzia je `P26-000123/2`. Stará verzia sa uloží a dostane stav Nahradená.
- **Stavy ponuky:**
  - Koncept → Čaká na schválenie → Pripravená → Odoslaná → Otvorená → Akceptovaná,
  - alebo Zamietnutá / Vypršaná / Nahradená.

### 5.2 Cena pre obchodníka a pridaná hodnota

- Pri každej cene CRM ukáže:
  - **cenu pre obchodníka** na rok dodávky (FIX), alebo **minimálny aditív** (SPOT, podľa typu predajcu),
  - **pridanú hodnotu** za rok a spolu,
  - **odhad provízie** (pridaná hodnota × percento obchodníka).
- Výpočet je rovnaký ako v module 4: cenové parametre, BL/PL z Cockpitu, iba komodita.
- **Ponuka si uloží** cenu pre obchodníka a parametre ku dňu vytvorenia verzie. Neskorší pohyb BL/PL ponuku nemení.
- **Prepočítať na dnešné ceny** vytvorí novú verziu.
- Marža firmy sa v ponuke zobrazí iba používateľom s právom „vidieť maržu firmy“.

### 5.3 Domácnosti a malé podniky

- Ceny sa doplnia **z cenníka** podľa sadzby OOM (Green DD s energopomocou alebo bez nej, Green DMP) a obchodník ich nemení. Pridá VBattery podľa modulu 3.
- Pri plánovanej spotrebe **nad 30 MWh** CRM upozorní, že treba individuálnu ponuku.

### 5.4 Výkup a VIWA

- **Výkup:** rovnaké zložky ako výkupná zmluva v module 4:
  - FIX cena (napr. Výkup_FIX_peak),
  - SPOT − aditív v € alebo %,
  - lokálny zdroj s plánom výkupu kW × 4 × 365 × 0,1.
- **VIWA:**
  - balík Basic / Plus / Pro,
  - mesačný poplatok za účet,
  - koeficient výmeny (0,75 / 0,80 / 0,85),
  - poplatok za odchýlku za kW (0,25 / 0,20 / 0,15 €),
  - výkon zdroja.

  Pridaná hodnota z odhadu aditívu balíka sa počíta ako v module 4.

### 5.5 Platnosť

| Typ | Platnosť |
| --- | --- |
| FIX – dodávka aj výkup | do 16:00 nasledujúceho pracovného dňa |
| SPOT – dodávka aj výkup, VIWA | 14 dní (do 16:00) |

- Obchodník môže platnosť skrátiť. Predĺžiť ju môže iba schvaľovateľ cien.
- Pracovné dni berú do úvahy slovenské sviatky (kalendár z modulu 0).
- Po uplynutí platnosti prejde ponuka do stavu Vypršaná. Stránka ponuky ukáže „Platnosť ponuky uplynula“ a akceptácia už nie je možná.

## 6. Výnimky a schvaľovanie

**Kedy treba schválenie** (ponuka sa dovtedy nedá odoslať):
1. cena FIX pod cenou pre obchodníka alebo aditív SPOT pod minimálnym aditívom (podľa typu predajcu),
2. zákazník v konkurze alebo s platobným ratingom E/X,
3. predĺženie platnosti ponuky.

**Postup:**
- Obchodník požiada o schválenie s dôvodom.
- Schvaľovateľ (príznak „schvaľuje ceny“: CEO, obchodný riaditeľ) dostane upozornenie do zvončeka aj e-mailom. Schváli alebo zamietne s poznámkou.
- **Schválená výnimka platí 3 dni** na odoslanie ponuky. Ak sa ponuka v tej lehote neodošle, treba požiadať znova.
- Výnimka sa uloží k variantu ponuky. Po akceptácii ju prevezme zmluva z importu a stane sa hranicou pre pridanú hodnotu (modul 4, časť 7).
- Výnimky mimo ponúk (modul 4, platnosť 30 dní) ostávajú, ale pri obchodoch v CRM sa už nepoužívajú.

## 7. PDF ponuky, stránka ponuky a akceptácia

### 7.1 PDF podľa dnešných vzorov

Ponuka má časti v tomto poradí:
1. Hlavička: číslo, druh ponuky (dodávka / výkup / VIWA), adresa Greenlogy.
2. Údaje o odberateľovi alebo výrobcovi: názov, sídlo, IČO, IČ DPH, kontaktná osoba.
3. Predmet ponuky.
4. Cenová ponuka:
   - **pre každý variant** obdobie a tabuľka produktov s cenou alebo aditívom a popisom,
   - flexibilita, plánovaný ročný objem,
   - pri SPOT vzorec ocenenia a odkaz na OKTE.
5. Platobné podmienky (dodávka) alebo ostatné podmienky (výkup, VIWA).
6. Platnosť ponuky „do 16:00 hod. DD. MM. RRRR“.
7. Všeobecné ustanovenia.
8. „Cenovú ponuku spracoval“: meno, telefón a e-mail obchodníka.
9. Prehľad referencií (logá zákazníkov), energetický mix, Príbeh a Vízia Greenlogy.
10. **Potvrdenie o prijatí ponuky – Záväzná objednávka** (dodávka a výkup, nie VIWA) so zmluvnou pokutou.

**Rozsah cien v PDF:**
- **Firmy:** iba cena za komoditu, bez mesačných poplatkov a bez ročných nákladov.
- **Domácnosti:** ceny bez DPH aj s DPH, mesačné poplatky (OM, ZEM, VBattery) a odhad ročných nákladov na komoditu.
- Regulované poplatky sú uvedené iba informatívne textom.
- PDF rozpisuje **produkty**, nie jednotlivé OOM. Rovnaké produkty s rovnakou cenou sa zlúčia a objem sa sčíta.

**Obrázky:** titulná strana, logá referencií a energetický mix sú od Petra. Ukladajú sa v nastaveniach šablóny a admin ich môže vymeniť. Energetický mix sa mení, preto je to samostatný obrázok.

### 7.2 Šablóny a premenné polia

- **Šablóna** je jedna pre každý druh ponuky (dodávka, výkup, VIWA) a jazyk (SK, EN). Obsahuje pevné texty častí 3, 5, 7, 9 a 10.
  - Spravuje ich admin v Nastavenia → Šablóny ponúk, každá zmena sa zapíše do histórie.
  - Anglické texty pripraví Claude a Peter ich skontroluje.
- **Premenné polia mení obchodník** pre každý variant:

| Pole | Predvolená hodnota |
| --- | --- |
| Flexibilita odberu / dodávky | Plná flexibilita (alebo tolerancia v %) |
| Plánovaný ročný objem | súčet z OOM |
| Obdobie | z variantu |
| Platnosť | podľa časti 5.5 |
| Kontaktná osoba | primárny kontakt obchodu |
| Splatnosť vyúčtovacej faktúry | 14 dní |
| Výška preddavkov | 100 % z 1/12 plánovaného ročného odberu, mesačne, splatnosť 5. deň (alebo finančná zábezpeka) |
| Výkup: kompenzácia pri záporných cenách | nie |

### 7.3 Stránka ponuky a akceptácia

- **Stránka ponuky:**
  - E-mail obsahuje odkaz na stránku ponuky (bez prihlásenia, neuhádnuteľný odkaz, platný do konca platnosti + 30 dní na čítanie) a PDF v prílohe.
  - Stránka ukáže varianty, podmienky, PDF na stiahnutie a tlačidlo na akceptáciu.
- **Akceptácia dodávky a výkupu (záväzná objednávka):**
  1. Zákazník vyberie variant a vyplní meno a funkciu.
  2. Zaškrtne „Som oprávnený konať za spoločnosť a súhlasím so znením Záväznej objednávky“.
  3. Klikne **„Záväzne objednávam“**.
  - CRM uloží čas, IP adresu, prehliadač, meno, funkciu, variant a **presné znenie** záväznej objednávky (text a jeho odtlačok).
  - Zákazník dostane e-mailom potvrdenie s PDF ponuky a vyplnenou záväznou objednávkou.
  - Obchod sa presunie do Akceptácie a obchodník dostane upozornenie.
- **VIWA:** tlačidlo „Prijímam ponuku“ s rovnakým záznamom, bez zmluvnej pokuty.
- **Ručne:** obchodník môže akceptáciu zaznačiť sám (napr. po telefonáte) alebo nahrať podpísané PDF. Vždy vyberie variant.
- **Právne overenie:** Peter overí s právnikom, či klik stačí pri zmluvnej pokute. Do overenia ostávajú obe cesty (klik aj podpísané PDF).
- **Sledovanie:** CRM zapisuje prvé a posledné otvorenie stránky ponuky a počet otvorení. Pixel v e-maile sa nepoužíva.

## 8. E-maily z CRM

- **Odosielanie zo schránky obchodníka** cez Google Workspace (Gmail API):
  - Správca domény jednorazovo povolí aplikácii CRM odosielať v mene používateľov greenlogy.com (servisný účet s delegovaním).
  - E-mail je v Odoslaných obchodníka a odpovede mu chodia normálne.
  - Všetci obchodníci budú mať adresu na greenlogy.com, tí s gmail.com dostanú novú.
- **Druhy e-mailov:**
  - ponuka: text zo šablóny, odkaz na stránku a PDF,
  - potvrdenie akceptácie zákazníkovi,
  - **pripomienka platnosti:** deň pred koncom platnosti CRM pripraví koncept, obchodník ho odošle jedným klikom (nie automaticky),
  - voľný e-mail zákazníkovi z karty obchodu alebo zákazníka (prázdny alebo zo šablóny).
- **Interné upozornenia** (výnimky, akceptácie, obnovy, pridelenie firmy) idú do zvončeka. Schvaľovateľovi aj e-mailom z adresy CRM (napr. crm@greenlogy.com).
- **Záznam:**
  - CRM ukladá k zákazníkovi a obchodu iba e-maily odoslané z CRM a odpovede v tých istých vláknach.
  - Odpovede kontroluje každých 5 minút.
  - Ostatnú poštu v schránke nečíta.
- **Šablóny e-mailov:**
  - Spravuje ich admin alebo Marketing v slovenčine aj angličtine. Obchodník text pred odoslaním môže upraviť.
  - Predvolená šablóna ponuky vychádza z dnešného e-mailu: oslovenie, poďakovanie za dopyt, krátky popis ponuky, odkaz, „V prípade otázok ma neváhajte kontaktovať.“
- **Podpis** je jednotný a skladá sa z profilu používateľa: fotka, meno, funkcia, adresa, telefón, mobil, e-mail, web, sociálne siete.

## 9. Podklady pre zmluvu (Akceptácia)

- Formulár zmluvy v Office portáli chce aj údaje, ktoré ponuka nemá. Kto zmluvu zadáva, doplní ich v obchode v štádiu Akceptácia:
  - **Firma:** IBAN, fakturačné e-maily, platca DPH, sociálny podnik, názov pre zmluvu „v zastúpení“.
  - **Zástupca pre zmluvné vzťahy:** titul, meno, priezvisko, funkcia, e-mail, telefón.
  - **Zmluva:** obdobie fakturácie, typ (akvizícia), autoprolongácia, produktová rada; pri výkupe typ výkupnej zmluvy a model výpočtu výkupu.
  - **OOM:** vzťah k nehnuteľnosti, IMS (áno/nie), predchádzajúci dodávateľ alebo odberateľ.
- Údaje sa uložia k firme, kontaktu a OOM, nielen k obchodu.
- Záložka **„Podklady pre zmluvu“** ukáže všetko v poradí formulára Office portálu: hlavička, základné údaje, odberné alebo výrobné miesta, fakturácia, zástupca, individuálne ceny. Pri každom poli je tlačidlo „Kopírovať“.
- Ak má obchod OOM na NN aj VN, záložka ukáže **dve zmluvy** (NN a VN) s príslušnými OOM a cenami.
- **Kto zadáva:**
  - obchodník (firmy),
  - back office (domácnosti),
  - Nákup (výkup).

  Všetci vidia obchody v Akceptácii v prehľade „Čaká na zmluvu“.
- Keď bude Office portál vedieť načítať súbor, CRM pripraví súbor namiesto kopírovania.

## 10. Párovanie zmlúv z importu

Doplnok importu z modulu 4:
1. Pri novej zmluve CRM hľadá otvorený obchod **toho istého zákazníka** v Akceptácii (alebo Vyjednávaní), ktorého OOM sa zhodujú s OOM zmluvy podľa EIC.
2. **Jednoznačná zhoda:**
   - Zmluva dostane odkaz na obchod, akceptovanú ponuku a variant.
   - Obchod prejde do **Vyhraté** pri prvej spárovanej zmluve. Ďalšie zmluvy (VN) sa pripoja k tomu istému obchodu.
3. **Kontrola cien:** ak sa cena alebo aditív na zmluve líši od akceptovaného variantu, zmluva dostane príznak „Cena iná ako v ponuke“ a obchodník s obchodným riaditeľom dostanú upozornenie.
4. **Chýbajúce OOM:** ak niektoré OOM z akceptovaného variantu nie je ani **14 dní** po akceptácii na žiadnej zmluve, obchodník dostane upozornenie.
5. **Nejednoznačná alebo žiadna zhoda:** zmluva ide do zoznamu **„Nespárované zmluvy“** a obchodník (alebo admin) vyberie obchod ručne, alebo označí „bez obchodu“, napr. pri domácnosti z webu.
6. Výnimka z variantu prejde na zmluvu.

## 11. Úvodná obrazovka obchodníka (náhrada Sales portálu)

- **Dlaždice:**
  - cena pre obchodníka FIX na ďalšie 3 roky dodávky, so stavom „k dátumu“ a dátumom settlementu,
  - priemerná SPOT cena za 12 mesiacov (z Cockpitu),
  - minimálny aditív (podľa typu predajcu),
  - cez víkend a sviatky posledné platné ceny s poznámkou.
- **Graf vývoja** ceny pre obchodníka na roky dodávky od 1. 1. 2026 (dnes záložka „Ceny energie“).
- **Kalkulačka:** produkt FIX/SPOT, rok, objem, moja cena → pridaná hodnota a odhad provízie s mojím percentom.
- **Overenie firmy** (časť 4.1) s tlačidlom „Založiť obchod“.
- **Moje obchody:** ďalšie kroky na dnes a po termíne, ponuky čakajúce na schválenie, otvorené a vypršané ponuky.
- **Žiadosť o pomoc s ponukou** (pre externých obchodníkov): upozornenie obchodnému riaditeľovi s odkazom na obchod. Nahrádza mailto zo Sales portálu.

## 12. Provízie (posledná fáza modulu)

Preberá sa celá logika Sales portálu, so základom z CRM:
- **Nastavenia obchodníka:**
  - % z pridanej hodnoty (predvolene 40 %),
  - „počítať provízie“ áno/nie,
  - aktívny.
- **Provízia** = pridaná hodnota obchodu (súčet zmlúv obchodu, modul 4) × % obchodníka, zaokrúhlená na centy.
  - Vzniká, keď obchod prejde do Vyhraté. Kým nie je uplatnená, prepočíta sa pri zmene zmluvy (ceny, objem).
  - Pri zmluve na neurčito sa berie pridaná hodnota z prvých 12 mesiacov dodávky.
- **Stavy:** Čaká na uplatnenie → Uplatnená, alebo Zrušená.
- **Uplatnenie:**
  - Obchodník vyberie svoje provízie, vždy iba jedného obchodníka.
  - CRM vytvorí **provízny list** `CMSN-RRRR-NNNN` (číslovanie od 1 každý rok), PDF a e-mailom ho pošle obchodníkovi a obchodnému riaditeľovi.
  - Uplatnená provízia sa už neprepočítava.
- **Zrušenie provízneho listu:**
  - Iba admin, s povinným dôvodom.
  - Provízie sa vrátia na „Čaká“ a PDF sa označí ako zrušené.
- **Prehľad provízií:**
  - zoskupenie podľa trvania zmluvy,
  - súčty: nevyplatené, vyplatené tento mesiac, tento kvartál alebo rok, počet,
  - filtre: stav, obchodník (admin), hľadanie.
- **Prenos histórie:** provízie a provízne listy zo Sales portálu (Firestore) sa pri štarte ostrej prevádzky prenesú iba na čítanie, s pôvodnými číslami CMSN.

## 13. Prehľady

- **Pipeline:**
  - kanban (stĺpce = štádiá) a zoznam s filtrami: pipeline, vlastník, štádium, zdroj, ďalší krok, očakávané uzavretie,
  - súčet pridanej hodnoty a vážený súčet podľa pravdepodobnosti, podľa štádia a mesiaca uzavretia.
- **Pre manažéra:** rozpad podľa obchodníkov.
- **Zoznamy:**
  - Bez ďalšieho kroku / po termíne,
  - Čaká na schválenie,
  - Čaká na zmluvu (Akceptácia),
  - Nespárované zmluvy.
- Detailné reporty ostávajú v Cockpite. API pre Cockpit doplní obchody a ponuky, keď sa bude robiť F5 modulu 4.

## 14. Práva

| Rola | Obchody a ponuky |
| --- | --- |
| Obchodník (interný) | vidí a mení svoje obchody a obchody svojich zákazníkov |
| Externý obchodník | iba svoje (aj v databáze) |
| Manažér, obchodný riaditeľ, CEO | všetko, mení vlastníka, schvaľuje pridelenie firmy |
| Back office, Nákup | vidia všetko, dopĺňajú podklady pre zmluvu, párujú zmluvy |
| Schvaľuje ceny (CEO, obchodný riaditeľ) | výnimky, konkurz/E/X, predĺženie platnosti |
| Admin | šablóny ponúk a e-mailov, číselníky, zrušenie provízneho listu |

- Maržu firmy vidia iba používatelia s právom „vidieť maržu firmy“ (modul 4).
- Provízie vidí obchodník iba svoje, admin a obchodný riaditeľ všetky.

## 15. Prenos z HubSpotu a pilot

- Pri štarte ostrej prevádzky sa prenesú iba **otvorené B2B obchody** (dodávka, výkup, VIWA) so štádiom, vlastníkom, OOM a poslednou ponukou ako PDF prílohou.
- Uzavreté obchody sa neprenášajú. Zmluvy prídu z importu Office portálu, história e-mailov ostáva v archíve HubSpotu.
- **Pilot:** CEO, Nákup, interní obchodníci, ostatní manažéri, back office. Noví obchodníci v pilote zakladajú obchody iba v CRM, externí zatiaľ v HubSpote.

## 16. Príklady

Čísla sú ilustračné.

1. **Firma s NN aj VN, dva varianty.**
   - Obchod „Alfa 2027“ má 3 OOM na NN (40 MWh) a 1 OOM na VN (200 MWh).
   - Ponuka P26-000123 má varianty FIX 2027 (148 €/MWh) a SPOT + 9 €.
   - Cena pre obchodníka 2027 v deň ponuky je 140 €/MWh, takže pridaná hodnota FIX = 8 × 240 = **1 920 €** a odhad provízie pri 40 % = **768 €**.
   - Zákazník akceptuje FIX. Back office v podkladoch vidí dve zmluvy (NN, VN) a zadá ich do Office portálu.
   - Ráno import spáruje NN zmluvu a obchod je Vyhraté. Na druhý deň príde VN zmluva a pripojí sa k obchodu.
2. **Cena pod hranicou.**
   - Obchodník chce FIX 138 €/MWh pri cene pre obchodníka 140 €/MWh. Ponuka prejde do „Čaká na schválenie“.
   - Obchodný riaditeľ schváli výnimku 137 €. Obchodník musí ponuku odoslať do 3 dní.
   - Pridaná hodnota = (138 − 137) × objem.
3. **Firma v konkurze.**
   - Pri overení firmy sa ukáže červená výstraha.
   - Ponuku nejde odoslať, kým ju schvaľovateľ neschváli.
4. **Obnova.**
   - Zmluva končí 31. 12. 2027. 1. 9. 2027 nočný beh pošle upozornenie a založí obchod „Obnova – 26VYRP131“ s predvyplnenými OOM.
5. **Platnosť FIX.**
   - Ponuka odoslaná v piatok 10:00 platí do pondelka 16:00.
   - V pondelok 16:01 je Vypršaná a tlačidlo akceptácie zmizne.

## 17. Dopady na iné moduly

- **Dátový model:** obchod : zmluva = **1 : n**. Pribudnú tabuľky:
  - `offer_variant`, `offer_item` pre OOM × rok,
  - `offer_acceptance` (záznam akceptácie),
  - `approval_request` (výnimka, konkurz, predĺženie, pridelenie firmy),
  - `email_message` a `email_thread`,
  - `offer_template`, `email_template`,
  - `commission`, `commission_claim`.
- **Modul 0:**
  - profil používateľa: fotka, funkcia, telefón, mobil, % provízie, počítať provízie,
  - Gmail delegovanie,
  - kalendár pracovných dní a sviatkov.
- **Modul 1:**
  - našepkávanie z Finstatu podľa názvu,
  - Z-skóre, tržby, zisk a zamestnanci na firme,
  - výstrahy,
  - IBAN a fakturačné e-maily na firme.
- **Modul 2:**
  - OOM v stave Pripravované bez zmluvy,
  - nové polia: vzťah k nehnuteľnosti, IMS, predchádzajúci dodávateľ.
- **Modul 4:**
  - nočný beh zakladá obchody „Obnova“,
  - import páruje zmluvy s obchodmi a ponukami (časť 10),
  - výnimka sa preberá z ponuky,
  - nové príznaky „Cena iná ako v ponuke“ a „Bez obchodu“.
- **Cockpit:** po prechode prestane Sales portál čítať Firestore `prices_daily`. Ceny pre obchodníka bude ukazovať CRM.

## 18. Fázy (návrh pre Claude Code)

| Fáza | Obsah |
| --- | --- |
| F1 | pipelines, štádiá, obchod, OOM Pripravované, časová os, ďalší krok, overenie firmy, vlastník a pridelenie, Finstat výstrahy |
| F2 | ponuka, varianty, ceny OOM × rok, cena pre obchodníka, pridaná hodnota, verzie, platnosť, schvaľovanie |
| F3 | PDF a šablóny SK/EN, stránka ponuky, akceptácia |
| F4 | Gmail: odosielanie, vlákna, odpovede, šablóny, podpis |
| F5 | podklady pre zmluvu, párovanie importu, obnova z nočného behu |
| F6 | úvodná obrazovka obchodníka a prehľady |
| F7 | provízie a prenos histórie zo Sales portálu |

Každá fáza ide rovnakým postupom ako doteraz: návrh DB, migrácie nanečisto, dev, API a obrazovky, Test, commit po Petrovom teste.

## 19. Obrazovky

Návrhy sú v `docs/dizajn/obrazovky/30-…42-*.html` (obrázky PDF v `assets/`):

| Súbor | Obrazovka |
| --- | --- |
| 30-domov-obchodnika | úvodná obrazovka obchodníka (časť 11) |
| 31-overenie-firmy | overenie firmy, vlastník, Finstat (4.1) |
| 32-obchody-pipeline | pipeline – kanban (3, 13) |
| 33-obchod-karta | karta obchodu (4) |
| 34-ponuka-editor | editor ponuky, varianty, výnimka (5, 6) |
| 35-ponuka-pdf | PDF ponuky (7.1) |
| 36-ponuka-stranka-zakaznik | stránka ponuky a akceptácia (7.3) |
| 37-email | e-mail z CRM (8) |
| 38-podklady-pre-zmluvu | podklady pre Office portál (9) |
| 39-schvalovanie | schvaľovanie (6, 4.1) |
| 40-zmluvy-k-obchodom | čaká na zmluvu, nespárované, cena iná ako v ponuke (10) |
| 41-provizie | provízie (12) |
| 42-nastavenia-sablony-ponuk | šablóny ponúk (7.2) |

Čísla v návrhoch sú ilustračné, zákazníci vymyslení.

## 20. Bezpečnosť

- **Sales portál má v kóde (index.html) zapísaný tajný kľúč pre Make webhooky a ich adresy.** Každý, kto portál otvorí, ich vidí v zdrojovom kóde.
  - Súbor sa **nesmie dať do repozitára CRM**. Claude Code ho dostane iba do `exports/` (je v .gitignore).
  - Po prechode na CRM treba kľúč zneplatniť a webhooky vypnúť (súčasť nápravy Make).
- **Stránka ponuky:**
  - prístup iba cez neuhádnuteľný odkaz,
  - bez údajov o iných OOM a bez marže,
  - obmedzenie počtu pokusov,
  - zápis IP adresy iba pri akceptácii.
- **Gmail delegovanie** je obmedzené iba na potrebné oprávnenia (odoslanie, čítanie vlákien, ktoré CRM založilo). Kľúč servisného účtu ide iba do `wrangler secret`.

## 21. Rozhodnuté a otvorené otázky

Rozhodnuté 14. 10. 2026: kolá 1 a 2 v `05-obchod-otazky.md`.

Rozhodnuté 14. 10. 2026 (P1–P3):
- **P1** Pri zmluve na neurčito sa pridaná hodnota pre províziu počíta z **prvých 12 mesiacov dodávky**.
- **P2** Nárok na províziu vzniká pri **Vyhraté** (podpis zmluvy), ako dnes v Sales portáli.
- **P3** Priemerná SPOT cena za 12 mesiacov prichádza z **Cockpitu** (OKTE).

**Otvorené:**
- **P4. Právne overenie** akceptácie klikom (časť 7.3), na strane Petra. Do overenia funguje aj nahratie podpísaného PDF.
