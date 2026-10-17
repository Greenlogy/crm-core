# Plán: dokončenie CRM a prechod na Ostré

Verzia 1 · 17. 10. 2026 · Peter Kalman

Tento dokument nadväzuje na koniec modulu 5. Opisuje poradie krokov od uzávierky modulu 5 až po Ostré s ostrými dátami. Každá fáza má cieľ, rozdelenie práce a podmienku ukončenia. Ďalšia fáza začína až po splnení podmienky predchádzajúcej.

Pre všetky fázy platia doterajšie pravidlá:
- Bez môjho výslovného súhlasu žiadny commit, push, deploy, migrácia, mazanie ani zmena tajomstiev.
- Migrácie idú najprv nanečisto lokálne, potom na dev a na main až po schválení.
- HubSpot je iba na čítanie.
- Tajomstvá iba cez wrangler secret alebo .dev.vars, nikdy nie do chatu.
- Ostré exporty s osobnými údajmi iba lokálne v exports/, nikdy nie na dev, Test, do chatu ani do repozitára.
- Zmeny v Cloudflare robím ja, nie CC.

---

## Prehľad

| Fáza | Obsah | Kto | Výstup |
|---|---|---|---|
| A | Uzávierka modulu 5 | CC kontroluje, ja rozhodujem | Zoznam hotové / zmenené / chýba |
| B | Finstat: firma podľa IČO bez ručnej práce | CC programuje, ja testujem | Založenie firmy iba zadaním IČO alebo názvu |
| C | Manuál v aplikácii | CC programuje a píše prvé texty, ja a tím opravujeme | Ikona 📖 na každej stránke, upraviteľný manuál |
| D | Príprava Ostrého (infraštruktúra) | CC pripraví, ja nastavujem Cloudflare a Google | Ostré beží prázdne, Test ostáva nezmenený |
| E | Konfigurácia Ostrého | Ja nastavujem na Teste, CC prenesie | Ostré s nastaveniami, bez testovacích záznamov |
| F | Import dát po krokoch | CC pripraví, spoločná kontrola, ja potvrdzujem | Firmy → kontakty → OOM → zmluvy → obchody → provízie |
| G | Zapnutie ostrej prevádzky a pilot | Ja a tím | Obchodníci pracujú v CRM, HubSpot beží súbežne |

Krok 3 fázy F7 (prenos histórie provízií zo Sales portálu) sa presúva do fázy F ako F6. Bez ostrých obchodov a zmlúv nemá zmysel.

---

## A. Uzávierka modulu 5

**Cieľ:** vedieť, či je zo zadania v0.2 všetko hotové.

CC prejde docs/moduly/05-obchod.md v0.2 (časti 1–21) a obrazovky 30–42 bod po bode. Pri každom bode uvedie jeden z troch stavov:
- hotové: migrácia, API, obrazovka,
- zmenené rozhodnutím: odkaz do rozhodnutia.md,
- chýba.

Výsledok zapíše do STAV.md ako „Modul 5 – uzávierka“. Nič nové neprogramuje.

Ja na Teste prejdem obrazovky aj na telefóne. CC ich pri šírke 390 px nevedel nasnímať. Najdôležitejšia je verejná stránka ponuky, lebo tú otvárajú zákazníci.

**Podmienka ukončenia:** každý bod v stave „chýba“ je buď doplnený, alebo vedome odložený a zapísaný v STAV.md.

---

## B. Finstat: založenie firmy bez ručnej práce

**Cieľ:** obchodník zadá IČO alebo začne písať názov. CRM firmu nájde a vyplní všetky údaje, ktoré Finstat pozná. Obchodník iba potvrdí.

**Ako to má fungovať:**
1. **Hľadanie:** pole „IČO alebo názov“ v Zákazníci → Nová firma.
   - IČO: priame vyhľadanie.
   - Názov: našepkávanie od 3 znakov, rovnaké ako pri overení firmy v module 5.
2. **Kontrola duplicity ešte pred vyplnením:**
   - Ak firma s týmto IČO v CRM už je, formulár sa nevyplní. Zobrazí sa odkaz na existujúcu firmu.
   - Ak firma patrí inému obchodníkovi, zobrazí sa tlačidlo „Požiadať o pridelenie“, ktoré už existuje v module 5.
3. **Vyplnené polia:**
   - názov, IČO, DIČ, IČ DPH,
   - právna forma, sídlo (ulica, číslo, PSČ, obec),
   - SK NACE, dátum vzniku,
   - registrový súd a číslo vložky (potrebné do zmluvy),
   - stav firmy.
   - Finančné ukazovatele z overenia firmy: tržby, zisk, zamestnanci, Z-skóre, rating, dlhy, konkurz.
4. **Štatutári:** zobrazia sa iba ako návrh „Pridať ako kontakt?“ s menom a funkciou. Kontakt sa nezakladá automaticky. Dátum narodenia sa neprenáša.
5. **Zdroj údajov:** pri poliach vyplnených z Finstatu sa zobrazí „Finstat, DD.MM.RRRR“.
   - Obchodník ich môže prepísať, napríklad korešpondenčnú adresu.
   - Prepísané pole sa označí ako ručne zmenené. Pri ďalšej aktualizácii z Finstatu sa neprepíše bez potvrdenia.
6. **Stav firmy blokuje uloženie:** firmu v likvidácii, zrušenú alebo v konkurze nemožno založiť bez výnimky. Platia rovnaké pravidlá ako pri ponuke (konkurz a rating E/X vyžadujú schválenie).
7. **Existujúce firmy:** na karte firmy bude tlačidlo „Aktualizovať z Finstatu“, ktoré ukáže rozdiely pred uložením.
8. **Výpadok Finstatu:** firmu možno založiť ručne s príznakom „neoverené vo Finstate“. Nočný beh overenie zopakuje.
9. **Spotreba kvóty:** výsledky z Finstatu sa ukladajú do vyrovnávacej pamäte (napr. 24 h na IČO) a našepkávanie má oneskorenie. Kvótu treba stráviť pri hromadnom overení firiem po importe (fáza F1), nie pri písaní.

B2C zákazníci (osoby) sa týmto nemenia, pre nich Finstat nefunguje.

**Podmienka ukončenia:** na Teste založím firmu iba zadaním IČO a po zadaní IČO nemusím nič dopisovať. Duplicita je zachytená, firma v konkurze je zablokovaná a výpadok Finstatu sa dá obísť.

---

## C. Manuál v aplikácii

**Cieľ:** na každej stránke je ikona 📖. Po kliknutí sa otvorí manuál k tej stránke. Manuál sa dá upravovať a dopĺňať priamo v aplikácii.

**Obsah manuálu ku každej stránke má päť častí:**
1. **Čo stránka obsahuje:** na čo slúži a kto ju vidí.
2. **Čo sa zobrazuje:** každé pole, stĺpec, dlaždica a súčet, odkiaľ sa berú a ako sa počítajú.
3. **Ako ju obsluhovať:** bežné postupy krok za krokom.
4. **Na čo si dať pozor:** časté chyby, obmedzenia, čo sa nedá vrátiť.
5. **Súvislosti a dopady:** čo zmena na tejto stránke spôsobí inde, napríklad na zmluvách, províziách, nočnom behu, e-mailoch zákazníkovi alebo PDF.

**Okrem stránok:**
- **Úvod manuálu:** zoznam všetkých stránok podľa menu.
- **Slovník pojmov:** OOM, EIC, PH, cena pre obchodníka, variant, výnimka, párovanie, Obnova, CMSN…
- **Procesy cez viac stránok:**
  - od nového zákazníka po podpísanú zmluvu,
  - obnova zmluvy,
  - schválenie výnimky,
  - provízie od Vyhraté po list.

**Úpravy:**
- **Text manuálu** upravuje admin a používateľ s právom „Upravovať manuál“. Každá úprava sa uloží ako nová verzia (kto, kedy) a dá sa vrátiť.
- **Podnety:** každý používateľ môže k stránke pridať podnet (myšlienka, chyba v texte, otázka). Podnet má stav Nový / Zapracovaný / Zamietnutý a editori ho vidia v zozname.
- **Formát:** text sa píše v jednoduchom formáte (Markdown) a zobrazuje sa bez spúšťania akéhokoľvek HTML alebo skriptu.
- **Časti pre vybrané roly:** časti iba pre administrátorov alebo manažérov (napr. marža, schvaľovanie) sa dajú označiť. Ostatní ich neuvidia, aby manuál neprezrádzal to, čo im aplikácia skrýva.

**Prvé texty:**
- CC ich napíše podľa skutočného správania aplikácie a zadaní, nie zo všeobecných predpokladov.
- Každé tvrdenie o výpočte musí zodpovedať kódu.
- Ja a tím ich potom opravujeme priamo v aplikácii.

**Test aj Ostré:**
- **Základ manuálu** je v repozitári (docs/manual/). Nová databáza sa z neho naplní, ak je manuál v nej prázdny.
- **Úpravy** sa robia na Ostrom, ktoré je hlavná verzia manuálu.
- **Prenos medzi prostrediami:** admin vie manuál stiahnuť ako súbor a nahrať ho na druhom prostredí. Stiahnutý súbor môže CC zapísať do repozitára ako nový základ.

**Podmienka ukončenia:** ikona 📖 je na každej stránke a každá stránka má všetkých päť častí. Úprava, história verzií aj podnety fungujú a časti pre roly sa správne skrývajú.

---

## D. Príprava Ostrého (infraštruktúra)

**Cieľ:** Ostré beží na vlastnej databáze, vlastných Workeroch a vlastnom úložisku, zatiaľ bez dát. Test ostáva funkčný presne ako dnes.

**Oddelenie prostredí.** CC najprv spíše, čo je dnes spoločné a čo oddelené:

| Časť | Test | Ostré |
|---|---|---|
| Databáza Neon | vetva dev | vetva main |
| Hyperdrive | na dev | na main |
| Worker aplikácie | samostatný | samostatný |
| Worker crm-ponuka (verejná stránka) | samostatný | samostatný, ponuka.greenlogy.com |
| R2 úložisko (EU) | samostatné | samostatné, zámok na ponuky, akceptácie a provizie/ |
| Cloudflare Access | testovacia aplikácia | ostrá aplikácia, iba zamestnanci |
| Google servisný účet / kľúč | odporúčam samostatný kľúč | samostatný kľúč |
| Cron (Montel, Gmail, nočný beh, fronty) | beží | beží |
| MAIL_ALLOWLIST | stále zapnutý | zapnutý až do štartu pilotu |

**Kroky:**
1. CC pripraví zoznam tajomstiev a nastavení pre Ostré (bez hodnôt) a poradie príkazov.
2. Migrácie 0001–0055 (a ďalšie z fáz B a C) na main, potom práva rolí crm_app, crm_public a crm_sync na main.
3. Ja: DNS, Access, WAF pravidlo s obmedzením počtu pokusov pre ponuka.greenlogy.com, R2 úložisko so zámkom, tajomstvá.
4. Prepínače na Ostrom pri štarte:
   - deal_matching vypnuté,
   - commission_crm_from prázdne,
   - MAIL_ALLOWLIST zapnutý.
5. Záloha: overiť obnovu Neon main do času (skúšobná obnova do dočasnej vetvy).
6. Kontrola po nasadení: prihlásenie, prázdne obrazovky bez chýb, cron v denníku behov, test e-mailu iba na moju adresu.

**Podmienka ukončenia:** Ostré beží prázdne a všetky kontroly z DB testov prešli na main bez testovacích dát. Test funguje ako predtým a nový deploy na Test nezasiahne Ostré.

---

## E. Konfigurácia Ostrého

**Cieľ:** Ostré má všetky nastavenia, ale žiadny testovací záznam.

Namiesto mazania testovacích záznamov odporúčam toto: Ostré sa postaví prázdne a prenesú sa naň iba nastavenia. Test si ponechá testovacie dáta na ladenie, ako chceš.

**Postup:**
1. Ja aktualizujem nastavenia na Teste:
   - spoločnosť a logo,
   - používatelia, tímy a práva,
   - číselníky (predchádzajúci dodávateľ, typy a modely výkupu),
   - produkty a cenníky,
   - šablóny ponúk a e-mailov SK/EN,
   - percentá provízií,
   - sviatky,
   - nastavenia schvaľovania.
2. CC pripraví konfiguračný export: pevný zoznam tabuliek s nastaveniami, nič z firiem, kontaktov, OOM, zmlúv, obchodov, ponúk, e-mailov ani provízií.
3. Náhľad: CC ukáže, čo sa na Ostré prenesie (počty a zoznam), a ja ho potvrdím.
4. Import konfigurácie na Ostré a kontrola na obrazovkách Nastavení.
5. Používatelia na Ostrom:
   - pre začiatok iba ja a admin,
   - ostatní až pri pilote,
   - Daniel s príznakom „vidí všetky provízie“ a ako príjemca kópie listu.

**Podmienka ukončenia:** na Ostrom sú nastavenia zhodné s Testom a žiadny záznam z obchodných tabuliek.

---

## F. Import dát po krokoch

Každý krok má rovnaký priebeh:
1. Ostrý export iba lokálne v exports/.
2. Skúška nanečisto na dočasnom lokálnom Postgrese. CC pošle správu s počtami, chybami a nespárovanými záznamami.
3. Spoločná kontrola náhľadu.
4. Import na Ostré po mojom súhlase.
5. Kontrola počtov a náhodných vzoriek na obrazovkách.
6. Zápis do STAV.md, až potom ďalší krok.

Dátum narodenia a rodné číslo sa neimportujú.

| Krok | Údaje | Zdroj | Poznámka |
|---|---|---|---|
| F1 | Firmy | HubSpot (iba čítanie) | Párovanie podľa IČO, duplicity do zoznamu na rozhodnutie. Potom hromadné overenie vo Finstate na pozadí s ohľadom na kvótu. |
| F2 | Kontakty | HubSpot | Väzba na firmy z F1. Bez dátumu narodenia a rodného čísla. |
| F3 | OOM | HubSpot / Office portál | Väzba na firmy, kontrola EIC. |
| F4 | Zmluvy | Export Office portálu | Prvý import zmluvnej bázy. Potom zapnutie denného importu zmlúv. |
| F5 | Otvorené obchody | HubSpot | Iba otvorené obchody (štádiá pred Vyhraté). Mapovanie pipeline a štádií, vlastníci. Po F5 zapnúť deal_matching. |
| F6 | Provízie | Firestore (Sales portál) | Krok 3 fázy F7: história listov CMSN, percentá, prepínače. Pokračovanie číslovania. |

**Podmienka ukončenia:** všetky kroky sú zapísané v STAV.md, nespárované záznamy sú vyriešené alebo vedome odložené a súčty sedia so zdrojom.

---

## G. Zapnutie ostrej prevádzky a pilot

1. **Pilot:** ja, Nákup, Daniel, manažéri a Back office. Potom obchodníci po skupinách.
2. **E-maily:** vypnutie MAIL_ALLOWLIST v deň, keď obchodníci začnú posielať ponuky z CRM.
3. **Prechod provízií zo Sales portálu:**
   - nastaviť commission_crm_from na deň, keď Sales portál prestane počítať,
   - zneplatniť kľúč Make,
   - vypnúť webhooky Sales portálu.
4. **Súbežná prevádzka s HubSpotom:** HubSpot iba na čítanie a porovnanie.
5. **Výpoveď HubSpotu:** obnova je 9. 7. 2027. Treba overiť výpovednú lehotu v zmluve a dátum zapísať do kalendára.

---

## Moje otvorené úlohy

- právna kontrola akceptácie kliknutím (P4),
- schválenie anglických textov ponuky a e-mailov,
- číselníky: predchádzajúci dodávateľ, typy a modely výkupu,
- polia v exporte z Office portálu,
- založenie Daniela a nastavenie jeho práv,
- zneplatnenie kľúča Make a vypnutie webhookov pri štarte,
- výpovedná lehota HubSpotu.
