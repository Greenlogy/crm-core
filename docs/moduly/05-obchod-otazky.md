# Modul 5 – Obchod a ponuky: otázky na zadanie

Stav: 14. 10. 2026 · verzia 3 · kolá 1 a 2 zodpovedané; zadanie v `05-obchod.md`.
Pri každej otázke je návrh. Stačí odpovedať „súhlas“ alebo napísať, ako to je inak.

## Čo už platí (rozhodnuté skôr)

- **Obchod (deal)** je predajný proces: pipeline, štádiá, ponuky, vlastník. Končí ako vyhraný alebo prehraný.
- **Zmluva** vzniká v Office portáli a do CRM prichádza denným importom (modul 4). CRM ju nevytvára.
- **Štádiá v CRM** sú iba obchodné: Príležitosť, Cenová ponuka, Vyjednávanie, Akceptácia, Vyhraté, Prehraté. Stav zmluvy sa sleduje na zmluve.
- **Cena pre obchodníka (FIX)** na rok dodávky = (BL × 80 + PL × 20) / 100 + riziková prirážka + marža. Hodnoty sú z cenových parametrov k dátumu. Pri SPOT platí minimálny aditív (6 obchodník / 0 manažér).
- **Pridaná hodnota** = predajná cena − cena pre obchodníka, iba z komodity. Z nej sa počíta provízia. Maržu firmy vidí iba CEO, Nákup, Marketing a obchodný riaditeľ.
- **Domácnosti a malé podniky do 30 MWh** majú ceny z cenníka (modul 3). Individuálne ceny sú B2B nad 30 MWh.
- **Ostrá prevádzka** začne až po module 5 vrátane odosielania e-mailov z CRM.

## A. Pipelines a štádiá

1. **Ktoré pipelines v module 5:**
   - Návrh: B2B dodávka, B2B výkup, Green VIWA B2B.
   - GreenSolar a EFET neskôr, dovtedy ostávajú v HubSpote.
   - Domácnosti (B2C) pozri otázku 2.
2. **Domácnosti:**
   - Domácnosť dnes podpíše zmluvu najmä cez web alebo call centrum. Obchod v CRM by bol iba formalita.
   - Návrh: pre domácnosti obchod nezakladáme. Výnimka je, keď s domácnosťou rieši ponuku obchodník (napr. FVE s VBattery), vtedy ide do pipeline B2C s rovnakými štádiami.
   - Súhlas, alebo chceš sledovať aj domácnosti ako obchody (napr. dopyty z webu)?
3. **Štádiá a pravdepodobnosť:**
   - Návrh: Príležitosť 10 %, Cenová ponuka 30 %, Vyjednávanie 50 %, Akceptácia 90 %, Vyhraté 100 %, Prehraté 0 %.
   - Pravdepodobnosť slúži iba na odhad budúcej pridanej hodnoty v prehľade.
   - Chýba ti štádium (napr. „Kvalifikácia“ alebo „Čaká na podpis“)?
4. **Povinné údaje pri prechode štádiom:**
   - Návrh:
     - Cenová ponuka: zákazník, aspoň jedno OOM, plánovaná spotreba.
     - Akceptácia: prijatá ponuka.
     - Prehraté: dôvod prehry.
   - Súhlas?
5. **Dôvody prehry:**
   - Návrh: číselník (cena, zostal u dodávateľa, iný dodávateľ, nereaguje, nesplnil podmienky, iné) a poznámka.
   - Doplň alebo uprav zoznam.

## B. Obchod: zákazník, OOM, vznik

6. **Odkiaľ vznikajú obchody:**
   - Ručne obchodník, z dopytu z webu (neskôr cez marketing modul), z odporúčania, z call centra.
   - Návrh: v module 5 ručne. Pole „zdroj“ je číselník (vlastný kontakt, web, call centrum, odporúčanie, partner, obnova).
   - Samostatný objekt „lead“ nerobíme, záujemca je kontakt alebo firma a obchod v štádiu Príležitosť. Súhlas?
7. **Nové OOM v obchode:**
   - Zákazník, ktorý ešte nie je náš, má OOM, ktoré v CRM nie je.
   - Návrh: obchodník zadá EIC a základné údaje (sadzba, napäťová úroveň, plánovaná spotreba VT/NT, prípadne výkon zdroja). OOM vznikne v stave „Pripravované“ a dočasne bez zmluvy.
   - Keď príde zmluva z Office portálu, import ho spáruje podľa EIC a údaje z XM Trade ho doplnia. Pri prehre sa OOM, ktoré nie je na žiadnej zmluve, označí ako neaktívne. Súhlas?
8. **Obnova:**
   - Modul 4 posiela upozornenie 4 mesiace pred koncom zmluvy.
   - Návrh: nočný beh v tej chvíli **založí aj obchod „Obnova“** v štádiu Príležitosť pre obchodníka zmluvy. Obchod bude mať odkaz na zmluvu a predvyplnené OOM a spotreby.
   - Ak zákazník neobnoví, prehra s dôvodom; ak sa nič neudeje, zmluva sa predĺži prolongáciou. Súhlas?
9. **Vyhratie obchodu a zmluva z importu:**
   - Návrh:
     - Keď ráno príde v importe nová zmluva, CRM ju spáruje s otvoreným obchodom toho istého zákazníka, ak sa zhodujú OOM (EIC).
     - Obchod sa sám presunie do „Vyhraté“ a zmluva dostane odkaz na obchod a akceptovanú ponuku.
     - Ak sa nedá spárovať jednoznačne, zmluva ide do zoznamu „Nespárované“ a obchodník vyberie obchod ručne.
   - Súhlas?
   - Má CRM porovnať ceny na zmluve s akceptovanou ponukou a upozorniť na rozdiel?
10. **Viac obchodov naraz:** môže mať zákazník súčasne viac otvorených obchodov, napr. dodávka a výkup, alebo NN a VN? Návrh: áno, jeden obchod = jeden druh zmluvy.

## C. Ponuka a cena pre obchodníka

11. **Štruktúra ponuky:**
    - Návrh: ponuka má ceny pre každé OOM a rok dodávky, rovnako ako zmluva.
    - Obchodník nastaví začiatok a dĺžku dodávky, typ ceny (FIX / SPOT / kombinácia), tranžu a predajné ceny.
    - CRM pri každej cene ukáže cenu pre obchodníka, pridanú hodnotu za rok a spolu a odhad provízie. Súhlas?
12. **Varianty:**
    - Návrh: jedna ponuka môže mať až 3 varianty (napr. FIX 1 rok, FIX 2 roky, SPOT). Zákazník prijme jednu.
    - Alebo jedna ponuka = jeden variant a ďalší variant je nová ponuka?
13. **Platnosť ponuky a pohyb cien:**
    - Cena pre obchodníka pri FIX sa mení každý deň s BL/PL.
    - Návrh: ponuka uloží cenu pre obchodníka ku dňu vytvorenia.
      - FIX ponuka platí štandardne do konca nasledujúceho pracovného dňa.
      - SPOT ponuka platí 14 dní.
      - Po uplynutí sa dá ponuka „prepočítať“ na dnešné ceny ako nová verzia.
    - Aké lehoty používate dnes?
14. **Ponuka pod hranicou (výnimka):**
    - Na rozdiel od zmlúv z Office portálu tu CRM vie odoslanie zablokovať.
    - Návrh: ponuku s cenou pod cenou pre obchodníka (alebo SPOT pod minimálnym aditívom) nejde odoslať bez schválenia. Postup:
      1. Obchodník požiada o výnimku s dôvodom.
      2. Schvaľovateľ (príznak „schvaľuje ceny“, napr. Daniel Dérer) dostane upozornenie.
      3. Schvaľovateľ schváli alebo zamietne s poznámkou.
      4. Schválená výnimka sa uloží k ponuke a neskôr ju prevezme zmluva z importu.
    - Súhlas? Má mať výnimka lehotu platnosti?
15. **Domácnosti a malé podniky:**
    - Návrh: ak obchodník robí ponuku pre domácnosť alebo malý podnik, CRM ceny doplní z cenníka podľa sadzby OOM (Green DD / DMP, s energopomocou alebo bez) a obchodník ich nemení.
    - Pri plánovanej spotrebe nad 30 MWh CRM upozorní, že treba individuálnu ponuku. Súhlas?
16. **Výkup a VIWA v ponuke:**
    - Návrh: výkupná ponuka má rovnaké zložky ako výkupná zmluva v module 4.
    - VIWA ponuka má balík (Basic / Plus / Pro) a výkon zdroja. Odhad výnosu počíta rovnako ako modul 4 (25 / 20 / 15).
    - Súhlas, alebo chýba niečo, čo dnes v ponukách uvádzate?
17. **Čo ponuka ukazuje zákazníkovi:**
    - Návrh: ceny bez DPH (pri domácnosti aj s DPH), mesačné poplatky, platnosť ponuky a odhad ročných nákladov na komoditu.
    - Regulované poplatky iba informatívne, ako bolo rozhodnuté v module 3.
    - Má ponuka obsahovať porovnanie s terajším dodávateľom (úspora)? Ak áno, obchodník zadá terajšiu cenu.

## D. PDF, odoslanie a akceptácia

18. **Vzhľad PDF ponuky:**
    - V HubSpote je 6 aktívnych šablón ponúk.
    - Prosím pošli 2–3 vzorové ponuky (B2B FIX, B2B SPOT, výkup, prípadne VIWA). Podľa nich navrhnem šablónu v CRM.
    - Jazyk iba slovenčina, alebo aj angličtina, maďarčina?
19. **Číslovanie ponúk:**
    - Návrh: `P26-000123` (rok + poradové číslo); verzia sa pridá ako `/2`.
    - Máte dnes vlastný formát?
20. **Akceptácia zákazníkom:**
    - Návrh: e-mail s ponukou obsahuje odkaz na stránku ponuky (bez prihlasovania, s neuhádnuteľným odkazom) a PDF na stiahnutie.
    - Na stránke je tlačidlo „Prijímam ponuku“. CRM zapíše čas a meno, obchod sa presunie do Akceptácie a obchodník dostane upozornenie.
    - Obchodník môže akceptáciu zaznačiť aj ručne (napr. po telefonáte).
    - Súhlas? Alebo zákazník ponuku podpisuje (podpis cez SMS / e-podpis)?
21. **Sledovanie otvorenia:**
    - Návrh: CRM sleduje iba otvorenie stránky ponuky (prvé a posledné otvorenie, počet), nie neviditeľný pixel v e-maile. Obchodník tak vie, kedy zákazník ponuku pozeral.
    - Súhlas?
22. **Po akceptácii – podklady pre Office portál:**
    - Office portál nemá API, takže zmluvu tam obchodník zadáva ručne.
    - Návrh: obchod v Akceptácii má záložku „Podklady pre zmluvu“ so všetkými údajmi v poradí formulára Office portálu a tlačidlami „Kopírovať“.
    - Vie Office portál načítať údaje zo súboru (import)? Ak áno, CRM pripraví súbor.
    - Kto zadáva zmluvy do Office portálu – obchodník alebo back office?

## E. E-maily z CRM

23. **Aké e-maily posiela CRM v module 5:**
    - Návrh:
      - ponuka (s odkazom a PDF),
      - pripomienka pred koncom platnosti ponuky,
      - bežný e-mail zákazníkovi z karty obchodu alebo zákazníka (voľný text alebo šablóna),
      - interné upozornenia (výnimky, akceptácie, obnovy).
    - Hromadné a marketingové e-maily nie, tie prídu v marketing module (Brevo).
    - Súhlas?
24. **Odkiaľ sa e-maily odosielajú:** dve možnosti.
    - **A – zo schránky obchodníka** (Google Workspace / Microsoft 365 cez API):
      - E-mail je v jeho Odoslaných a odpovede chodia k nemu.
      - CRM vie odpovede zákazníka pripísať k obchodu.
      - Vyžaduje jednorazové povolenie správcom domény.
    - **B – cez službu na odosielanie** (napr. Brevo transakčné, Amazon SES – v EÚ):
      - Odosielateľ je meno obchodníka, odpovede idú do jeho schránky.
      - CRM dostane kópiu, odpovede zákazníka však nevidí.
    - Návrh: **A**, ak máte Google Workspace alebo Microsoft 365. Ktorý používate?
    - Majú externí obchodníci e-maily na doméne greenlogy.com, alebo vlastné?
25. **Záznam komunikácie:**
    - Návrh: CRM ukladá k zákazníkovi a obchodu iba e-maily, ktoré z CRM odišli, a odpovede v tých istých vláknach.
    - Ostatné e-maily v schránke obchodníka CRM nečíta (súkromie, GDPR). Súhlas?
26. **Šablóny e-mailov:**
    - Návrh: šablóny spravuje admin alebo Marketing; obchodník ich pri odoslaní môže upraviť.
    - Prosím pošli texty e-mailov, ktoré dnes k ponukám posielate (prenesú sa ručne, ako bolo rozhodnuté pri inventári).
    - Podpis e-mailu: jednotný podľa údajov používateľa (meno, funkcia, telefón)?

## F. Aktivity, úlohy, prehľady

27. **Aktivity na obchode:**
    - Návrh: časová os (poznámky, odoslané e-maily, zmeny štádia, ponuky, otvorenia ponuky) a pole **„Ďalší krok + dátum“**.
    - V deň kroku príde upozornenie do zvončeka. Obchod bez ďalšieho kroku alebo s krokom po termíne sa v zozname zvýrazní.
    - Hovory z CloudTalku prídu neskôr s modulom servisu. Úlohy ostávajú v GreenTracku. Súhlas?
28. **Prehľady pre obchodníka a manažéra:**
    - Návrh:
      - pipeline ako kanban (stĺpce = štádiá) a ako zoznam s filtrami,
      - súčet pridanej hodnoty podľa štádia a mesiaca očakávaného uzavretia,
      - pre manažéra rozpad podľa obchodníkov,
      - zoznam obchodov bez ďalšieho kroku.
    - Detailné reporty ostávajú v Cockpite. Čo ešte potrebuješ vidieť priamo v CRM?
29. **Úvodná obrazovka obchodníka (náhrada Sales portálu):**
    - Návrh: dlaždice s dnešnou cenou pre obchodníka na roky dodávky a SPOT minimálnym aditívom (ako dnes v Sales portáli), kalkulačka pridanej hodnoty a provízie, moje otvorené obchody a ďalšie kroky.
    - Sales portál a jeho Make scenáre sa po prechode vypnú. Súhlas?
30. **Provízie v module 5:**
    - Návrh: v module 5 iba **odhad provízie** pri ponuke a obchode.
    - Percento provízie obchodníka (dnes v Sales portáli) sa presunie do nastavení používateľa.
    - Skutočný výpočet, schvaľovanie a výplata provízií budú samostatný modul. Súhlas?

## G. Prístupy a prechod

31. **Kto čo vidí:**
    - Návrh:
      - Obchodník vidí a mení svoje obchody a obchody svojich zákazníkov.
      - Externý obchodník vidí iba svoje.
      - Manažér, obchodný riaditeľ a CEO vidia všetko a môžu zmeniť vlastníka.
      - Back office vidí obchody v Akceptácii (podklady pre zmluvu).
    - Súhlas?
32. **Prenos z HubSpotu pri štarte ostrej prevádzky:**
    - Návrh:
      - Preniesť iba otvorené B2B obchody (dodávka, výkup, VIWA) s poslednou ponukou ako prílohou.
      - Uzavreté obchody sa neprenášajú, zmluvy prídu z importu Office portálu.
      - História e-mailov ostane v archíve HubSpotu.
    - Súhlas?
33. **Súbežná prevádzka s HubSpotom:**
    - Návrh: v pilote nové obchody zakladajú pilotní obchodníci iba v CRM, ostatní ešte v HubSpote.
    - Ktorí obchodníci pôjdu do pilotu ako prví?

## Podklady, ktoré prosím pošli

- 2–3 vzorové PDF ponuky z HubSpotu (osobné údaje môžeš začierniť).
- Texty e-mailov, ktoré dnes k ponukám posielate.
- Zoznam dôvodov prehry, ak ho používate.
- Snímku alebo zoznam polí formulára zmluvy v Office portáli (pre podklady k zmluve).

---

## Odpovede – kolo 1 (Peter, 14. 10. 2026)

| # | Odpoveď |
| --- | --- |
| A1–A5 | súhlas |
| B6–B8 | súhlas |
| B9 | súhlas; CRM má upozorniť na rozdiel cien zmluvy oproti akceptovanej ponuke |
| B10 | Zákazník môže mať súčasne viac obchodov typu dodávka alebo výkup. **NN a VN je vždy jeden obchod a jedna ponuka.** Na dve zmluvy sa delí iba kvôli Office portálu. |
| C11 | súhlas |
| C12 | jedna ponuka, viac variantov |
| C13 | súhlas; FIX dnes 2 dni, **1 deň** dáva väčší zmysel |
| C14 | súhlas; **výnimka platí 3 dni** |
| C15 | súhlas |
| C16 | nič nechýba |
| C17 | **Firmy:** iba cena za komoditu, bez mesačných poplatkov a ročných nákladov. **Domácnosti:** v rozsahu návrhu. Porovnanie s iným dodávateľom sa nepoužíva. |
| D18 | vzory priložené (dodávka FIX, dodávka SPOT, výkup SPOT, výkup FIX, VIWA); jazyky **slovenčina a angličtina** |
| D19–D21 | súhlas |
| D22 | Proces áno. Office portál zatiaľ nevie načítať súbor. Zmluvy zadáva ktokoľvek s prístupom: **obchodník (firmy), back office (domácnosti), Nákup (výkup).** |
| E23 | súhlas |
| E24 | **A – Google Workspace.** Väčšina obchodníkov má greenlogy.com, **2–3 majú gmail.com.** |
| E25–E28 | súhlas |
| E29 | súhlas + zo Sales portálu prevziať **overenie firmy** (či už je u nás a komu je pridelená, aby si obchodníci „neliezli do kapusty“) a **výstrahy z Finstatu** (nedoplatky, dlhy) |
| E30 | súhlas; dá sa preklopiť celý modul provízií zo Sales portálu |
| G31 | súhlas; **back office tiež vidí všetko** |
| G32 | súhlas |
| G33 | pilot: CEO, Nákup, interní obchodníci, ostatní manažéri, back office |

### Zistenia zo vzorových ponúk

- Ponuka má časti:
  1. Údaje o odberateľovi / výrobcovi.
  2. Predmet ponuky.
  3. Cenová ponuka: produkt, popis, cena alebo aditív, obdobie, flexibilita, plánovaný ročný objem.
  4. Platobné alebo ostatné podmienky.
  5. Platnosť „do 16:00 hod. DD. MM. RRRR“.
  6. Všeobecné ustanovenia.
  - Ďalej „Cenovú ponuku spracoval“, Prehľad referencií, Príbeh a Vízia Greenlogy.
  - Na konci je **Potvrdenie o prijatí ponuky – Záväzná objednávka** s podpisom a zmluvnou pokutou (dodávka 50 €/MWh, výkup 30 €/MWh). Zákazník ju posiela na trading@greenlogy.com.
- **VIWA** nemá záväznú objednávku. Zákazník podpisuje priamo ponuku. Obsahuje balík, koeficient výmeny (0,8) a poplatok za odchýlku (0,20 €/kW/mes.).
- **Výkup:** pri SPOT aditív a obdobie na neurčito, pri FIX cena. Obsahuje doložku o záporných cenách, v jednom vzore aj s kompenzáciou za nedodanú elektrinu.
- **PDF rozpisuje produkty, nie OOM.** Ceny pre jednotlivé OOM sa v PDF nezobrazujú.
- **E-mail** k ponuke je krátky text s odkazom na ponuku a podpisom obchodníka s fotkou. Variant (napr. SPOT + 8 €/MWh) obchodník dnes píše do textu e-mailu.
- Dnešné číslo ponuky je časová pečiatka (napr. 20261013-072654672). Nový formát `P26-000123` je odsúhlasený.

## Kolo 2 – doplňujúce otázky

R1. **Akceptácia a záväzná objednávka:**
   - Dnes je prijatie ponuky podpísaná záväzná objednávka so zmluvnou pokutou. Odsúhlasili sme tlačidlo na stránke ponuky.
   - Návrh, ako to spojiť:
     - Stránka ponuky ukáže text záväznej objednávky.
     - Zákazník vyplní meno a funkciu, zaškrtne „som oprávnený konať za spoločnosť a súhlasím so znením záväznej objednávky“ a klikne „Záväzne objednávam“.
     - CRM uloží čas, IP adresu, meno, funkciu a presné znenie, ktoré zákazník videl. Potom mu pošle potvrdenie e-mailom s PDF.
     - Zostáva aj možnosť nahrať podpísané PDF, ak zákazník podpisuje ručne.
   - Je klik pre vás dostatočný pri zmluvnej pokute? Odporúčam to overiť s právnikom. Do overenia môžu bežať obe cesty.
   - Pri VIWA rovnaké tlačidlo „Prijímam ponuku“?

R2. **Obchodníci s gmail.com:**
   - Odosielanie zo schránky ide cez Google Workspace iba pre adresy na greenlogy.com.
   - Odporúčam dať im schránku na greenlogy.com (licencia Workspace).
   - Alternatíva: ich ponuky pôjdu z adresy na greenlogy.com (napr. obchod@) s odpoveďou na ich gmail. Odpovede zákazníkov však CRM neuvidí.
   - Čo zvolíš?

R3. **Provízie (E30):**
   - Návrh: celý modul provízií zo Sales portálu (výpočet, stavy, PDF, percentá obchodníkov) preklopiť ako **poslednú fázu modulu 5**. Sales portál tak pri štarte ostrej prevádzky môže skončiť celý.
   - Kde je zdrojový kód Sales portálu (repozitár alebo priečinok)? Claude Code ho prejde spolu s Make scenármi.

R4. **Jeden obchod a viac zmlúv:**
   - Z B10 vyplýva, že jeden obchod môže mať viac zmlúv (NN + VN). Dátový model mal obchod a zmluvu 1:1, zmení sa na 1:n.
   - Návrh:
     - Obchod sa presunie do Vyhraté pri prvej spárovanej zmluve.
     - Ak niektoré OOM z akceptovanej ponuky nie je ani po **14 dňoch** od akceptácie na žiadnej zmluve, obchodník dostane upozornenie. Záväzná objednávka uvádza uzavretie zmluvy do 14 dní.
   - Súhlas?

R5. **Platnosť ponuky:**
   - Návrh:
     - FIX (dodávka aj výkup) platí do 16:00 nasledujúceho pracovného dňa.
     - SPOT (dodávka aj výkup) a VIWA platia 14 dní.
     - Obchodník môže lehotu skrátiť. Predĺžiť ju môže iba schvaľovateľ cien.
   - Súhlas?

R6. **Čo obchodník v ponuke mení a čo je pevný text:**
   - Návrh: texty častí 2, 4, 6, Príbeh, Vízia a Záväznej objednávky sú šablóna pre typ ponuky (dodávka, výkup, VIWA) v slovenčine a angličtine. Spravuje ich admin a obchodník ich nemení.
   - Obchodník mení:
     - flexibilitu (plná / % tolerancia),
     - plánovaný objem,
     - obdobie,
     - platnosť,
     - kontaktnú osobu,
     - pri výkupe doložku o kompenzácii pri záporných cenách (áno/nie).
   - Chýba niečo, čo sa dnes mení (napr. splatnosť faktúr, preddavky / finančná zábezpeka, výška zmluvnej pokuty)?
   - „Prehľad referencií“ je strana s logami. Pošli ju ako obrázky alebo PDF.
   - Anglické texty pripravím ja a ty ich skontroluješ. Súhlas?

R7. **Overenie firmy a Finstat (E29):**
   - Návrh:
     - Pri zadaní IČO alebo názvu CRM ukáže, či firma už je zákazník alebo má otvorený obchod, a kto je jej vlastník.
     - Ak firmu vlastní iný obchodník, nový obchod nejde založiť. Ide iba požiadať o pridelenie, schvaľuje manažér alebo obchodný riaditeľ.
     - Výstrahy z Finstatu (dlhy, nedoplatky, konkurz, platobný rating) sa zobrazia na firme, obchode aj pri ponuke ako upozornenie.
   - Má byť ponuka pre firmu v konkurze alebo s ratingom E/X blokovaná a vyžadovať schválenie ako výnimka?

R8. **Údaje pre Office portál, ktoré ponuka nemá:**
   - Formulár zmluvy v Office portáli chce aj:
     - IBAN, fakturačné e-maily,
     - zástupcu pre zmluvné vzťahy (titul, meno, funkcia, e-mail, telefón),
     - obdobie fakturácie, typ (akvizícia), autoprolongáciu, sociálny podnik,
     - pri výrobnom mieste vzťah k nehnuteľnosti, IMS a predchádzajúceho odberateľa.
   - Návrh: v štádiu Akceptácia obchodník (alebo ten, kto zmluvu zadáva) doplní chýbajúce údaje priamo v CRM. Uložia sa k firme, kontaktu a OOM a záložka „Podklady pre zmluvu“ ich ukáže v poradí formulára Office portálu.
   - Súhlas?

## Odpovede – kolo 2 (Peter, 14. 10. 2026)

| # | Odpoveď |
| --- | --- |
| R1 | súhlas (klik „Záväzne objednávam“ + možnosť nahrať podpísané PDF; overiť s právnikom) |
| R2 | obchodníci s gmail.com dostanú adresu na greenlogy.com |
| R3 | zdrojový kód Sales portálu dodaný (index.html; obsahuje tajný kľúč Make – nie do repozitára) |
| R4 | súhlas (obchod : zmluva = 1 : n, upozornenie po 14 dňoch) |
| R5 | súhlas |
| R6 | súhlas; obchodník mení aj **splatnosť faktúr** a **výšku preddavkov** |
| R7 | súhlas; **konkurz a rating E/X vyžadujú schválenie** |
| R8 | súhlas |

Podklady: titulná strana, logá referencií (2 sady), energetický mix.
