# Modul 1 – Zákazníci: zadanie

Verzia 0.2 · 11. 10. 2026 · **schválené Petrom**.
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
- Označenie: zákazník (predvolené), partner, dodávateľ. Partner a dodávateľ sa nepočítajú medzi zákazníkov.

### Osoba
- Povinné: meno, priezvisko a e-mail alebo telefón.
- Jedna osoba = jeden záznam, aj keď pôsobí vo viacerých firmách alebo je zároveň zákazník za domácnosť.

### Firma – osoba
- Roly: štatutár, decision maker, kontaktná osoba, fakturácia, technik. Osoba môže mať vo firme viac rolí.
- Každá firma má jeden hlavný kontakt.

## 3. Kto je zákazník

Zákazníkom (riadkom v zozname Zákazníci) je:
- **firma**, alebo
- **osoba ako domácnosť**, t. j. osoba, ktorá podpisuje zmluvu za domácnosť.

Kontakt vo firme nie je zákazník, ale osoba na karte firmy. V zozname Kontakty ho nájdeš podľa mena, e-mailu alebo telefónu.

## 4. Stavy

Stav sa **nevyberá ručne, vypočíta sa** z OOM, dealov a zmlúv.

| Stav | Kedy | V zozname Zákazníci |
| --- | --- | --- |
| Marketingový kontakt | Je v databáze (newsletter, e-book…), ale nemá otvorený deal ani históriu zákazníka | predvolene skrytý |
| Záujemca | Má otvorený deal bez odoslanej ponuky | áno |
| Ponuka | Má otvorený deal s odoslanou ponukou | áno |
| Čakajúci zákazník | Podpísal zmluvu s budúcou účinnosťou a nikdy nemal aktívne OOM | áno |
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
- O zlúčení pri migrácii rozhoduje kontrolór.

## 8. Marketing a súhlasy (v tomto module)

- Iba príznak „nechce marketing“ s dátumom a zdrojom.
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
