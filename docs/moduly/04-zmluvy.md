# Modul 4 – Zmluvy a ceny: zadanie

Verzia 0.3 · 13. 10. 2026 · **schválené Petrom** (v0.2 = odpovede O1–O9 a základný firemný cenník; v0.3 = pridaná hodnota iba z komodity, O10, O11).
Vychádza z odpovedí v `04-zmluvy-otazky.md` (kolá 1 a 2, 13. 10. 2026), zo vzorových zmlúv a z exportov Office portálu a XM Trade. Stavia na moduloch 0–3.

## 1. Čo modul rieši

Evidencia zmlúv o dodávke, výkupe a VIWA s cenami po rokoch, výpočet pridanej hodnoty obchodníka a marže firmy, cenové parametre a výnimky, import zmlúv z Office portálu a tok dát do Cockpitu.

**Nerieši:**
- obchody a ponuky (modul 5),
- provízie (samostatný modul),
- zmluvy o dielo Green Solar a konfirmácie EFET (samostatná fáza neskôr),
- tvorbu a podpisovanie zmlúv – to ostáva v Office portáli.

## 2. Kto je zdrojom čoho

| Systém | Je zdrojom pre |
| --- | --- |
| **Office portal** | zmluvy: číslo, fázy, podpis, účinnosť, ceny, produkty, zmluvné množstvá, obchodník |
| **XM Trade** (fakturácia) | technické a fakturačné údaje OOM (sadzba, istič, rezervovaná kapacita, zálohy, regulácia…) |
| **Cockpit** | trhové ceny BL a PL, odhad nákupnej ceny portfólia na rok, očakávaná cena SPOT pre FVE, nákupné kontrakty |
| **CRM** | zákazníci, OOM, cenníky, cenové parametre, výnimky, pridaná hodnota a marža, prehľady; poskytuje dáta Cockpitu namiesto HubSpotu |

- Zmluva sa v CRM **nezadáva ručne**. Prichádza importom exportu z Office portálu (časť 10), rovnako ako dnes do HubSpotu, ale s cenami.
- Údaje, ktoré prišli z Office portálu, sú v CRM iba na čítanie. Opravujú sa v Office portáli a ďalší import ich prenesie.
- Údaje, ktoré vznikajú iba v CRM (súvisiaca zmluva, výnimka, dôvod uzatvorenia, poznámky), sa upravujú v CRM.

## 3. Zmluva

| Údaj | Zdroj | Poznámka |
| --- | --- | --- |
| Číslo zmluvy | Office portal | výkup `26VYRP075`, VIWA `26VIWP0135`, dodávka `1120262000` |
| Typ | odvodený | dodávka – domácnosť, dodávka – firma NN, dodávka – firma VN, výkup, VIWA; podľa typu osoby a komodity, nie podľa čísla (staré čísla „81…“ z roku 2019 platia ďalej) |
| Balík VIWA | Office portal (stĺpec sa doplní do zostavy) | Basic, Plus, Pro |
| Zákazník | Office portal | párovanie podľa IČO (firma) alebo osoby (domácnosť) |
| Fáza v Office portáli | Office portal | rozpracovaná, čaká na podpis, fyzické podpisovanie, elektronické podpisovanie, finálne podpísaná, odmietnutá, ukončená (kód 8), neúspešná (kód 9) |
| Platnosť od | Office portal | deň podpisu |
| Účinnosť od – do | Office portal | do = prázdne pri dobe neurčitej |
| Automatická prolongácia | Office portal | áno/nie |
| Malý podnik, cenníková cena | Office portal | áno/nie |
| Uzatvoril (obchodník), Vytvoril | Office portal | |
| Dôvod uzatvorenia | Office portal (stĺpec sa doplní do zostavy) | Akvizícia, Retencia, Autoprolong, Prepis, Nové OOM |
| Predošlá zmluva | CRM | pri retencii, prepise a obnove |
| Súvisiaca zmluva | CRM | VIWA ↔ zmluva o dodávke toho istého zákazníka |

**Stav zmluvy v CRM** sa počíta z fázy a dátumov:
- **V príprave:** nie je finálne podpísaná.
- **Podpísaná:** finálne podpísaná, účinnosť ešte nezačala.
- **Účinná:** podpísaná, dnes je v období účinnosti.
- **Skončená:** po dátume „účinnosť do“, alebo ukončená v Office portáli.
- **Odmietnutá / neúspešná.**

Stav zákazníka (modul 1) a OOM (modul 2) sa naďalej riadia OOM. Zmluva dopĺňa, s kým a za akú cenu.

## 4. OOM v zmluve

- Pri každom OOM zmluvy: obdobie (účinnosť), produkt Greenlogy (napr. „IN GREEN 1T“, DD2, DMP1), **zmluvné množstvo VT/JT a NT** a pri výrobe výkon zdroja v kW.
- Zmluvné množstvo platí **pre každý rok trvania rovnako**. Pri zmluve kratšej ako rok platí za obdobie zmluvy.
- OOM je v jednom čase najviac v **jednej zmluve o dodávke** a najviac v **jednej zmluve o výkupe alebo VIWA**. Prekrytie import označí ako chybu.
- **Kontaktné osoby zo zmluvy** sa prenesú na OOM (modul 2, časť 5).

## 5. Ceny na zmluve

Cena platí pre **OOM a obdobie**. Pri viacročnej zmluve je obdobie jeden rok.

| Model | Údaje | Použitie |
| --- | --- | --- |
| Cenník | odkaz na položku verzie cenníka + kópia cien | domácnosti, malé podniky, VIWA |
| FIX | VT/1T, NT [€/MWh] | firmy, domácnosti (manažéri) |
| SPOT + aditív € | aditív [€/MWh] | firmy, domácnosti |
| Výkup FIX | cena [€/MWh] | výkup |
| Výkup SPOT − aditív € / % | aditív [€/MWh] alebo [%] | výkup |

**Poplatky:**
- mesačná platba za OM: firmy 5 € (cenník Poplatky B2B), malé podniky a domácnosti 1,50 € podľa cenníka, výkup 0,
- ZEM: domácnosti 1,50 € mesačne za OM spotreby,
- VBattery: program pri výrobnom OOM domácnosti s obdobím; zmena programu = nové obdobie,
- **VBattery V = sharing:** prijímateľmi zdieľanej elektriny sú virtuálne OOM typu sharing s EIC „24GREENVV…“; program je bez mesačného poplatku,
- VIWA: mesačná platba **za účet** (nie za OOM) + poplatok za kW inštalovaného výkonu za každé výrobné OOM.

**Pravidlá:**
- **Nový cenník:** cenníková cena prejde na novú verziu automaticky od dátumu účinnosti (modul 3, časť 6).
- **Zmena cenovej regulácie** (energopomoc, malý podnik) vytvorí časový rez: stará cena do dňa pred zmenou, nová od dátumu zmeny. Ak nová cena nie je známa (vyradenie malého podniku), zmluva dostane príznak „Chýba cena“.
- **Výkup na dobu neurčitú:** cena platí bez konca, kým nevznikne nová zmluva.
- **Nové zmluvy** smú použiť iba produkt v stave „Predáva sa“; import iný produkt označí na kontrolu.

### Automatická prolongácia
- **4 mesiace pred koncom účinnosti** dostane obchodník upozornenie „Dojednaj novú zmluvu“.
- Ak do konca nepríde nová zmluva a zmluva má automatickú prolongáciu:
  - CRM predĺži účinnosť o 12 mesiacov,
  - pridá obdobie s cenou z **cenníka pre podnikateľov nad 30 MWh** (platný od 1. 10. 2026; produkt podľa typu tarifu OOM: Green 1T Jednotarif, Green 2T Dvojtarif, Green 2T Vykurovanie, Green 1T VO; mesačná platba 5 €),
  - zaradí zmluvu do prehľadu „Sprolongované bez novej ceny“.

## 6. Cenové parametre

V CRM v Nastaveniach → **Cenové parametre**. Každý parameter má históriu „platí od“ a zmenu zapíše audit.

| Parameter | Hodnota dnes | Kto mení |
| --- | --- | --- |
| Pomer BL / PL | 80 / 20 | admin, obchodný riaditeľ |
| Riziková prirážka (odchýlka) | 4 €/MWh | admin, obchodný riaditeľ |
| Naša marža v cene pre obchodníka | 4 €/MWh | admin, obchodný riaditeľ |
| Minimálny aditív – obchodník | 6 €/MWh | admin, obchodný riaditeľ |
| Minimálny aditív – manažér | 0 €/MWh | admin, obchodný riaditeľ |
| Minimálny aditív – výkup lokálny zdroj | 0 €/MWh | admin |
| Nákupná cena domácností s energopomocou, na rok | 2026: 72,40 €/MWh | admin |
| Odhad aditívu VIWA Basic / Plus / Pro | 25 / 20 / 15 €/MWh | admin |

**Z Cockpitu cez API (denne):**
- ceny BL a PL pre každý rok dodávky (CAL),
- odhad nákupnej ceny portfólia na rok,
- očakávaná cena SPOT pre FVE na rok (pre výkup s aditívom v %).

**Cena pre obchodníka (FIX) na rok dodávky** = (BL × 80 + PL × 20) / 100 + riziková prirážka + naša marža, podľa hodnôt z daného dňa. Pri zmluve sa uloží hodnota ku dňu podpisu (alebo ku dňu ponuky, keď bude modul 5).

**Typ predajcu:** pri používateľovi príznak obchodník / manažér, podľa ktorého sa volí minimálny aditív a cena pre obchodníka.

Sales portál bude neskôr čerpať tieto parametre z CRM.

## 7. Výnimky z ceny

- Obchodník požiada v CRM o výnimku: zákazník, rok, cena alebo aditív, dôvod.
- Schvaľuje **CEO alebo obchodný riaditeľ** (príznak „schvaľuje ceny“ pri používateľovi). Výnimka platí napr. 30 dní na podpis.
- Pri importe zmluvy CRM spáruje výnimku so zmluvou (zákazník + rok). Schválená výnimka sa stane hranicou pre pridanú hodnotu.
- **Zmluva sa tvorí v Office portáli, takže CRM ju nemôže zablokovať.** Zmluvu pod hranicou bez schválenej výnimky preto označí príznakom „Pod hranicou bez výnimky“, upozorní CEO a obchodného riaditeľa a zaradí ju do prehľadu.

## 8. Pridaná hodnota a marža

Počíta sa **na ročnej bilancii** pre každú zmluvu a rok. Objem = zmluvné množstvo VT + NT, poplatky za mesiace obdobia v danom roku.

**Výnos** = komodita + mesačné platby za OM + ZEM + VBattery + VIWA (platba za účet a za kW).

| Číslo | Kto vidí | Náklad |
| --- | --- | --- |
| **Pridaná hodnota obchodníka** (základ provízie) – **iba z komodity**, bez mesačných platieb za OM, ZEM, VBattery a poplatkov VIWA | všetci s prístupom k zmluve | cena pre obchodníka v deň podpisu, alebo schválená výnimka |
| **Marža firmy** – komodita **aj poplatky** | CEO, Nákup, Marketing, obchodný riaditeľ (nové právo „vidieť maržu firmy“) | skutočná nákupná cena roka |

**Náklad podľa typu:**

| Typ | Pridaná hodnota – náklad | Marža firmy – náklad |
| --- | --- | --- |
| FIX (obchodník) | cena pre obchodníka × objem | odhad nákupnej ceny portfólia × objem |
| FIX (manažér), domácnosti bez energopomoci | odhad nákupnej ceny portfólia × objem | odhad nákupnej ceny portfólia × objem |
| Domácnosti s energopomocou | nákupná cena energopomoci roka × objem | to isté |
| SPOT + aditív | minimálny aditív × objem | 0 – marža firmy = celý aditív zo zmluvy × objem |
| VIWA | výnos z kreditu = odhad aditívu balíka × objem; náklad = minimálny aditív (0) | to isté |
| Výkup SPOT − € | minimálny aditív × objem | to isté |
| Výkup SPOT − % | výnos = % × očakávaná cena SPOT pre FVE × objem | to isté |

**Tranža** pre Cockpit sa určí sama: FIX alebo SPOT podľa modelu, SEAS pre domácnosti s energopomocou.

## 9. Lokálny zdroj – plán výkupu (doplnok modulu 2)

Pri OOM výroby s kategóriou „Lokálny zdroj“ sa plánovaný výkup vyplní sám: výkon [kW] × 4 × 365 × 0,1 / 1000 [MWh]. Ručne sa dá prepísať; prepísaná hodnota sa už sama nemení.

## 10. Import z Office portálu a XM Trade

**Export z Office portálu** (zostava „Web Zmluvy – prehľad EE“):
- jeden riadok = zmluva × OOM × cenové obdobie,
- párovanie zmluvy podľa čísla zmluvy, OOM podľa EIC,
- CRM prevezme fázu, typ osoby, účinnosť, platnosť, autoprolongáciu, príznaky malý podnik a cenníková cena, OOM s produktom a zmluvným množstvom, výkon zdroja, ceny po obdobiach, obchodníka.

**Cenový model z názvu produktu:**

| Názov v Office portáli | Model |
| --- | --- |
| `GREEN_1T_INDIVIDUAL_RRRR`, `GREEN_2T_INDIVIDUAL_RRRR` | FIX |
| `GREEN_ISOTSK_PLUS_RRRR_R` | SPOT + aditív € (aditív je v stĺpci ceny 1T/VT) |
| `RRRR_GREENVYR_AK [EUR]` | výkup SPOT − aditív € |
| `RRRR_GREENVYR_AK [%]` | výkup SPOT − aditív % |
| `RRRR_GREENVYR_PC_R` | výkup FIX ročná cena |
| `…_PC_M09` (mesačné varianty) | nepoužívajú sa – import ich označí na kontrolu |
| prázdne + cenníková cena = A | cenník |

**Postup:**
- export sa zatiaľ sťahuje ručne každé ráno a nahrá do CRM (Office portal automatický export nemá),
- náhľad nové / zmena / bez zmeny / chyba, ako import OOM,
- uložia sa iba riadky zmenené od posledného importu (stĺpec `Greatest_updated_at`),
- riadky označené ako test (`ano_test = A`) sa preskočia.

**Ochrana údajov:**
- dátum narodenia a ďalšie osobné údaje, ktoré CRM nepotrebuje, sa **neimportujú**,
- súbor sa neuchováva.

**Chyby:**
- OOM chýba v CRM – najprv treba nahrať OOM z XM Trade,
- zákazník sa nedá spárovať,
- prekrytie zmlúv na OOM,
- neznámy produkt alebo fáza.

**Export z XM Trade:** slúži na založenie a aktualizáciu OOM (modul 2). CRM pozná jeho stĺpce priamo, bez prepisovania do šablóny CRM. Sadzby ako „VBATTERY-PREMIUM“ sa preložia na skutočnú sadzbu a program VBattery.

**Virtuálne OOM sharingu** (EIC „24GREENVV…“) majú 16 znakov ako bežné EIC. Ak ich kontrolná číslica nezodpovedá ENTSO-E, kontrola EIC v module 2 ich pri type sharing s predponou „24GREENVV“ prijme aj tak (overí sa na skutočných EIC).

**Importovať smú:** Servis, Nákup, CEO a front office (nové právo „import zmlúv“).

## 11. Dáta pre Cockpit

- CRM poskytne API iba na čítanie, chránené tokenom služby: zmluvy × rok × OOM s objemom, cenovým modelom, cenou alebo aditívom, tranžou, výnosom a maržou.
- Pridá aj súhrny podľa segmentov, ktoré dnes zodpovedajú pipeline v HubSpote (B2C elektrina, B2B elektrina, B2B výkup, VIWA).
- **Predtým Claude Code zmapuje dnešné toky HubSpot → Cockpit** (scenáre Make, kód Cockpitu): objem a výnos dealov zo všetkých pipeline. API musí pokryť všetko, čo Cockpit dnes číta.

## 12. Obrazovky a práva

- **Zoznam zmlúv:**
  - stĺpce: číslo, zákazník, typ, stav, účinnosť, počet OOM, objem, pridaná hodnota (+ marža firmy podľa práva), obchodník,
  - filtre: typ, stav, rok, obchodník, príznaky (Pod hranicou bez výnimky, Chýba cena, Sprolongované bez novej ceny, Končí do 4 mesiacov).
- **Karta zmluvy:**
  - hlavička a stav,
  - OOM so zmluvným množstvom,
  - ceny po rokoch a OOM,
  - ročná bilancia (výnos, pridaná hodnota, marža firmy),
  - súvisiaca a predošlá zmluva,
  - výnimka,
  - história importov.
- **Import zmlúv:** náhľad ako pri OOM.
- **Výnimky:** žiadosti obchodníkov a schvaľovanie.
- **Nastavenia → Cenové parametre:** hodnoty s históriou a dnešná cena pre obchodníka po rokoch.
- **Karta zákazníka:** sekcia Zmluvy a súčet pridanej hodnoty (a marže podľa práva) za rok.

**Práva:**
- obchodník vidí zmluvy svojich zákazníkov a pridanú hodnotu, nevidí maržu firmy, nákupnú cenu portfólia ani rizikovú prirážku,
- externý obchodník vidí iba svoje zmluvy (aj v databáze),
- úpravy údajov z CRM (dôvod, súvisiaca zmluva, poznámka): obchodník pri svojich zmluvách, Servis,
- cenové parametre: admin a obchodný riaditeľ.

## 13. Príklady

Čísla sú ilustračné; ceny BL/PL a odhad portfólia sú vymyslené.

1. **Firma FIX, 17 OOM, 21,3 MWh, cena 2027 = 133 €/MWh, obchodník.**
   - V deň podpisu BL 2027 = 95 €, PL 2027 = 110 € → cena pre obchodníka = (95 × 80 + 110 × 20) / 100 + 4 + 4 = 106 €/MWh.
   - Pridaná hodnota 2027 = (133 − 106) × 21,3 = **575,10 €** (poplatky za OM sa nezapočítavajú).
   - Marža firmy pri odhade portfólia 96 €/MWh = (133 − 96) × 21,3 + 1 020 = **1 808,10 €**. Obchodník ju nevidí.
2. **Firma SPOT + aditív 9 €, 2 OOM, 50 MWh, obchodník.**
   - Pridaná hodnota = (9 − 6) × 50 = **150 €**.
   - Marža firmy = 9 × 50 + 2 × 5 € × 12 = **570 €**.
3. **Domácnosť s energopomocou, DD2, 3 MWh.**
   - Pridaná hodnota = (89,4875 − 72,40) × 3 = **51,26 €**.
   - Marža firmy = 51,26 + 1,50 × 12 + ZEM 1,50 × 12 = **87,26 €**.
4. **VIWA Plus, 1 účet, výrobné OOM 10 kW, 12 MWh.**
   - Pridaná hodnota = 20 × 12 = **240 €**.
   - Marža firmy = 240 + 6,90 × 12 + 0,20 × 10 × 12 = **346,80 €**.
5. **Výkup lokálny zdroj 10 kW, aditív 30 €.**
   - Plán výkupu = 10 × 4 × 365 × 0,1 = 1 460 kWh = 1,46 MWh.
   - Pridaná hodnota = 30 × 1,46 = **43,80 €**.
6. **Výkup SPOT − 10 %, 100 MWh, očakávaná cena FVE 70 €/MWh.**
   - 10 % × 70 × 100 = **700 €**.
7. **Autoprolongácia.**
   - Zmluva do 31. 12. 2027 s automatickou prolongáciou; 1. 9. 2027 dostane obchodník upozornenie.
   - Nová zmluva nepríde → od 1. 1. 2028 obdobie s cenou z cenníka pre podnikateľov nad 30 MWh (napr. Green 1T Jednotarif 164 €/MWh) a príznak „Sprolongované bez novej ceny“.
8. **Cena pod hranicou.**
   - Obchodník dojedná FIX 104 € pri cene pre obchodníka 106 € bez výnimky.
   - Import zmluvu prevezme, označí „Pod hranicou bez výnimky“ a pošle upozornenie CEO a obchodnému riaditeľovi.
   - So schválenou výnimkou 103 € by bola pridaná hodnota (104 − 103) × objem.

## 14. Dopady na iné moduly

- **Modul 2:**
  - kontrola EIC prijme virtuálne OOM sharingu „24GREENVV…“ (16 znakov),
  - plán výkupu lokálneho zdroja (časť 9),
  - import OOM priamo z exportu XM Trade,
  - prenos kontaktných osôb zo zmluvy.
- **Modul 3:**
  - VIWA platba **za účet**, nie za OOM (oprava zadania a popisov),
  - program VBattery V (sharing, bez poplatku),
  - nový cenník **Podnikatelia nad 30 MWh** od 1. 10. 2026: Green 1T Jednotarif 164,00; Green 2T Dvojtarif 173,00 / 150,00; Green 2T Vykurovanie 168,00 / 164,00; Green 1T VO 162,00 €/MWh; mesačná platba 5,00 € bez DPH; DPH 19 %. Produkty sa neviažu na sadzbu distribúcie, ale na typ tarifu.
- **Modul 0:**
  - príznaky pri používateľovi: typ predajcu (obchodník / manažér), „schvaľuje ceny“,
  - nové práva: „vidieť maržu firmy“, „import zmlúv“.
- **Modul 1:** prepínač `customer_status_auto` sa zapne aj na Ostrom.

## 15. Rozhodnuté a otvorené otázky

Rozhodnuté 13. 10. 2026:
- **O1** Fáza 8 = Ukončená, 9 = Neúspešná.
- **O2** `GREENVYR_PC_R` = výkup pevná ročná cena; mesačné varianty sa nepoužívajú; pri `ISOTSK_PLUS` je aditív v stĺpci 1T/VT.
- **O3** Čísla „81…“ sú staré číslovanie z roku 2019, zmluvy platia.
- **O4** VBattery V = program sharingu bez mesačného poplatku; prijímatelia sú virtuálne OOM „24GREENVV…“.
- **O5, O6** Balík VIWA a dôvod uzatvorenia sa doplnia do zostavy v Office portáli.
- **O7** Export sa sťahuje a nahráva ručne každé ráno.
- **O8** Marža firmy pri SPOT = celý aditív zo zmluvy (náklad 0 €).
- **O9** Obchodný riaditeľ (schvaľuje ceny) = Daniel Dérer. Maržu firmy vidia CEO, Nákup, Marketing a obchodný riaditeľ.

- **O10** Fáza „Podpísaná“ = „Finálne podpísaná“.
- **O11** Green 1T VO = verejné osvetlenie (obce, mestá); sadzba C10 v SSD, C2-X3 v ZSD, X3-C2 vo VSD. Pri prolongácii CRM navrhne produkt podľa predošlého produktu OOM (verejné osvetlenie → 1T VO) a typu tarifu (1T, 2T, 2T vykurovanie); návrh potvrdí servis v prehľade „Sprolongované bez novej ceny“.
- **Provízia** sa platí iba z marže komodity, nie z poplatkov za OM – pridaná hodnota obchodníka preto obsahuje iba komoditu.

Otvorené: žiadne.

## 16. Na neskôr

- Green Solar (zmluva o dielo, marža), konfirmácie EFET.
- Provízie obchodníkov zo základu „pridaná hodnota“.
- API Office portálu a dodatky namiesto nových zmlúv.
- Napojenie Sales portálu na cenové parametre z CRM.
- Ponuky a obchody (modul 5): cena pre obchodníka sa uloží už pri ponuke.
