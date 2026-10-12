# Modul 1 – Zákazníci: zadanie

Verzia 0.3 · 11. 10. 2026 · **schválené Petrom** (v0.3 = doplnky po kontrole návrhu migrácie, časť 13).
Vychádza z odpovedí v `01-zakaznici-otazky.md`. Model v0.3 je iba podklad, platí toto zadanie.

## 1. Čo modul rieši

Evidencia firiem a osôb, s ktorými Greenlogy komunikuje: od marketingového kontaktu cez záujemcu a zákazníka až po bývalého zákazníka.
Nerieši odberné miesta, zmluvy, ponuky ani súhlasy v plnom rozsahu. Tie prídu v ďalších moduloch, tu sa na ne iba odkazuje.

## 2. Záznamy

V databáze sú dva druhy záznamov a jedna väzba medzi nimi:

| Záznam | Čo to je | Kľúč proti duplicite |
| --- | --- | --- |
| **Firma** | všetko s IČO: firmy, živnostníci, obce, mestá, partneri, dodávatelia | IČO (8 číslic, s úvodnými nulami) |
| **Osoba** | človek: zákazník za domácnosť, kontakt vo firme, alebo oboje | e-mail, potom telefón |
| **Firma – osoba** | osoba pôsobí vo firme | firma + osoba |

**Lead nie je samostatný záznam.** Je to stav firmy alebo osoby. Záznam sa nikdy nekonvertuje ani neprenáša, má jednu históriu od prvého kontaktu.

### Firma
- Povinné: IČO, názov.
- Z FinStatu (denná aktualizácia, dnes cez Make): DIČ, IČ DPH, sídlo, právna forma, štatutár, NACE, platobný rating, dlhy. Používajú sa na hlavičku ponuky.
- Označenie: zákazník, partner, dodávateľ. Firma môže mať viac označení naraz (napr. partner, ktorý od nás aj odoberá). V zozname Zákazníci je firma, ktorá má označenie zákazník.

### Osoba
- Povinné: meno, priezvisko a e-mail alebo telefón.
- Jedna osoba = jeden záznam, aj keď pôsobí vo viacerých firmách alebo je zároveň zákazník za domácnosť.

### Firma – osoba
- Roly: štatutár, decision maker, kontaktná osoba, fakturácia, technik. Osoba môže mať vo firme viac rolí.
- Každá firma má jeden hlavný kontakt.

## 3. Kto je zákazník

Zákazníkom (riadkom v zozname Zákazníci) je:
- **firma**, alebo
- **osoba ako domácnosť**, t. j. osoba, ktorá podpisuje zmluvu za domácnosť, alebo osoba bez firmy, ktorá k nám prišla z webu, newslettera či kampane (stav Marketingový kontakt).

Domácnosťou sa osoba stane automaticky (deal, OOM alebo zmluva na osobu; osoba bez firmy z webu či marketingu) alebo ručne pri založení „nová domácnosť“. Automaticky sa nikdy nezruší.

Kontakt vo firme nie je zákazník, ale osoba na karte firmy. V zozname Kontakty ho nájdeš podľa mena, e-mailu alebo telefónu.

## 4. Stavy

Stav sa **nevyberá ručne, vypočíta sa** z OOM, dealov a zmlúv.

| Stav | Kedy | V zozname Zákazníci |
| --- | --- | --- |
| Marketingový kontakt | Je v databáze (newsletter, e-book…), ale nemá otvorený deal ani históriu zákazníka | predvolene skrytý |
| Záujemca | Má otvorený deal bez odoslanej ponuky | áno |
| Ponuka | Má otvorený deal s odoslanou ponukou | áno |
| Čakajúci zákazník | Má zmluvu podpísanú, čakajúcu na zaradenie alebo aktívnu s budúcou účinnosťou a nemá aktívne ani neaktívne OOM (nový alebo vracajúci sa zákazník) | áno |
| Zákazník | Má aspoň jedno OOM Aktívne alebo Neaktívne | áno |
| Bývalý zákazník | Nemá aktívne ani neaktívne OOM a aspoň jedno OOM je Odídené (asset existuje, ide ku konkurencii) | áno, cieľ kampane na návrat |
| Zrušený zákazník | Všetky jeho OOM sú Zrušené alebo Prepísané (nemá čo zazmluvniť) | nie, archív |

Poradie pri súbehu: Zákazník > Čakajúci zákazník > Ponuka > Záujemca > Bývalý > Zrušený > Marketingový kontakt.

**Archív:** zrušený zákazník sa skryje zo zoznamov, vyhľadávania a marketingu. Údaje ostávajú kvôli zmluvám a účtovníctvu. Lehotu uchovania a anonymizáciu po nej určíme v module Marketing a súhlasy.

## 5. Segment

Segment sa tiež vypočíta, nezadáva sa:

| Segment | Pravidlo |
| --- | --- |
| Domácnosť | osoba ako zákazník (pipeline B2C dodávka, Green Solar) |
| Firma | firma s IČO (pipeline B2B dodávka, Green Solar, Green VIWA); patria sem aj obce a mestá |
| + výrobca | má OOM typu výroba, alebo deal v pipeline B2B výkup |

Zobrazenie: „Domácnosť“, „Domácnosť · výrobca“, „Firma“, „Firma · výrobca“.

## 6. Vlastník a prístup

- Zákazník má jedného vlastníka (obchodníka). Zmeniť ho môže iba vedenie.
- Interní používatelia vidia všetko.
- Externý obchodník vidí a upravuje iba zákazníkov, ktorých je vlastníkom.
- Servis vidí všetko a upravuje kontaktné údaje.

## 7. Duplicity

- Firma: IČO je unikátne. CRM pri zakladaní ponúkne existujúcu firmu a nedovolí založiť druhú.
- Osoba: rovnaký e-mail, potom rovnaký telefón → CRM upozorní a ponúkne existujúcu osobu.
- E-mail sa nevynucuje ako unikátny (spoločný e-mail manželov, info@ vo firme), CRM iba upozorní.
- Externý obchodník pri duplicite osoby vidí iba „osoba už existuje“ a meno vlastníka, rovnako ako pri firme.
- O zlúčení pri migrácii rozhoduje kontrolór.

## 8. Marketing a súhlasy (v tomto module)

- Iba príznak „nechce marketing“ s dátumom a zdrojom, iba na osobe (firma ho nemá).
- Plná evidencia súhlasov príde v module Marketing.

## 9. Obrazovky

- **Zákazníci:** názov, B2B/B2C, segment, stav, počet aktívnych OOM, ročný objem MWh, vlastník, posledná aktivita. Filtre: stav, segment, vlastník. Predvolene bez Marketingových kontaktov a archívu. Položka menu „Leady“ = tento zoznam s filtrom Záujemca + Ponuka.
- **Kontakty:** všetky osoby, hľadanie podľa mena, e-mailu a telefónu, pri osobe jej firmy a role.
- **Karta firmy:** variant B (rozhodnutie z 10. 10. 2026).
- **Karta osoby:** pri domácnosti rovnaké rozloženie ako karta firmy; pri kontakte vo firme údaje, firmy a role, časová os.

## 10. Príklady dopadov

1. **Nová domácnosť.** Pani Nováková vyplní formulár na webe → osoba, stav Záujemca. Obchodník pošle ponuku → Ponuka. Podpíše zmluvu od 1. 1. 2027 → Čakajúci zákazník. 1. 1. 2027 sa OOM aktivuje → Zákazník. Jeden záznam, jedna časová os.
2. **Existujúci zákazník s novou zmluvou.** Firma ABC má aktívne OOM a podpíše novú zmluvu od 2028 → ostáva Zákazník, stav Čakajúci sa nepoužije.
3. **Odchod ku konkurencii.** Domácnosť má jediné OOM a odíde k inému dodávateľovi → Bývalý zákazník. O rok ju zaradíme do kampane na návrat.
4. **Zrušené odberné miesto.** Rodinný dom zbúraný, OOM Zrušené → Zrušený zákazník, archív, už ho neoslovujeme.
5. **Živnostník.** Ján Kováč, SZČO s IČO, má zmluvu na dielňu (B2B) a zmluvu na dom (B2C). V zozname Zákazníci sú dva riadky: firma „Ján Kováč – stolárstvo“ (Firma) a osoba Ján Kováč (Domácnosť). Osoba je jedna a je zároveň štatutár firmy. Zmena telefónu sa prejaví v oboch.
6. **Starosta.** Peter Malý je štatutár obce A, kontaktná osoba v obci B a doma odoberá od nás. Je to jedna osoba: v zozname Zákazníci ako domácnosť, na kartách obcí A a B ako kontakt.
7. **FVE na firme.** Firma XY má odberné OOM aj OOM výroba → segment „Firma · výrobca“ bez ručného nastavovania.
8. **Externý obchodník.** Obchodník partnera vidí iba svojich 40 zákazníkov. Pri hľadaní IČO, ktoré už má iný obchodník, mu CRM povie iba „firma už existuje“ a neukáže jej údaje.

## 11. Nahrávanie dát

1. Najprv zákazníci s aktívnym OOM a ich kontakty (aj s rolami).
2. Cez kontrolnú tabuľku: každý obchodník kontroluje svojich zákazníkov, zvyšok servis, sporné prípady Peter. Do CRM ide iba schválený záznam.
3. Ostatné kontakty (marketingové, bez väzby) až v module Marketing; dovtedy zostávajú v archívnom exporte z HubSpotu.
4. Kým nebudú hotové moduly OOM a Zmluvy, stav a segment sa pri nahratí vypočítajú z údajov HubSpotu a uložia ako východisková hodnota. Po spustení modulov 2 a 4 sa začnú počítať priebežne.

## 12. Doplnkové pravidlá (schválené 11. 10. 2026)

- Záujemca, ktorému deal prepadne a nikdy nebol zákazník, sa vráti na stav Marketingový kontakt.
- Bývalý zákazník, ktorému pošleme novú ponuku, má stav Ponuka s príznakom „bývalý“.
- Externý obchodník pri zadaní IČO firmy, ktorú vlastní iný obchodník, vidí hlášku „firma už existuje“ a meno vlastníka, ale nie údaje firmy.

## 13. Doplnky po kontrole návrhu migrácie (schválené 11. 10. 2026)

- **Vracajúci sa zákazník.** Bývalý zákazník, ktorý podpíše novú zmluvu s budúcou účinnosťou, má stav Čakajúci zákazník s príznakom „bývalý“.
- **Kontakt zrušenej firmy.** Osoba, ktorá je iba kontaktom firmy v archíve (nemá inú aktívnu firmu a nie je sama zákazníkom), sa skryje z Kontaktov aj z marketingu.
- **Ochrana prístupu v databáze.** Obmedzenie externého obchodníka (čl. 6) platí priamo v databáze (Row Level Security), nie iba v API. Nahrádza skoršie rozhodnutie „externý má rovnaké práva ako interný, RLS sa nerobí“.
- **Zmena vlastníka** mimo vedenia je povolená iba jednej určenej databázovej role pre synchronizáciu, nie každému spojeniu bez prihláseného používateľa.

## 14. Dokončenie modulu nad Nastaveniami (schválené 12. 10. 2026)

Plán (fázy, každá s testovacím scenárom pre Petra; nasadenie na Test robí Peter, commit až po jeho vyskúšaní):

- **F1 – Nová firma, nová osoba, úprava:** spoločnosť, krajina a IČO/OIB, označenia, vlastník; kontrola duplicít (IČO; e-mail a telefón iba upozornenie); úprava podľa práv tímu.
- **F2 – Firma – osoba, vlastník, marketing, časová os:** pridanie a odobratie osoby vo firme, roly z číselníka, hlavný kontakt; zmena vlastníka (CEO a admin); „nechce marketing“ (dátum a zdroj); poznámka na časovej osi firmy a osoby (autor a čas); „Vývoj stavu“ na karte firmy aj osoby z auditu.
- **F3 – Vlastné polia** na kartách (po sekciách), v zoznamoch ako stĺpce a filtre.
- **F4 – Zoznamy a export:** zoznam Zákazníci predvolene bez marketingových kontaktov a archívu (prepínač „zobraziť aj…“); Leady = filter Záujemca + Ponuka; hľadanie podľa názvu, IČO/OIB, e-mailu a telefónu; filter a stĺpec Spoločnosť pre tímy so všetkými spoločnosťami; export do .xlsx s právom „exportovať“ a záznamom exportu.

Rozhodnuté:

1. **FinStat:** v F1 ručné vyplnenie; napojenie podľa IČO neskôr ako samostatný krok, API kľúč iba cez `wrangler secret`.
2. **Servis** mení e-mail, telefón, mobil, adresu, „nechce marketing“, pridáva a odoberá osobu vo firme a mení jej roly. Nemení názov, IČO, označenia ani vlastníka.
3. **Mazanie:** admin smie zmazať firmu alebo osobu bez väzieb (deal, odberné miesto, zmluva, osoba vo firme, aktivita); audit zapíše kto, kedy a celý obsah záznamu. Inak iba archív.
4. **Export:** súbor .xlsx; IČO/OIB, telefóny a EIC ako text (bez straty úvodných núl).

Stav: F1 na Teste, Peter vyskúšal 12. 10. 2026 (scenár 10 krokov vrátane práv Marketing a Servis). F2–F4 na Teste, Peter vyskúšal 12. 10. 2026.
