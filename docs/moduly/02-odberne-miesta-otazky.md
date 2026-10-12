# Modul 2 – Odberné miesta (OOM): otázky na zadanie

Stav: 12. 10. 2026 · zodpovedané, výsledok v `02-odberne-miesta.md` v0.2 (schválené).
Pri každej otázke je návrh. Stačí odpovedať „súhlas“ alebo napísať, ako to je inak.
Dnes v HubSpote: 10 151 OOM – spotreba 5 889, výroba 3 604, sharing 645, veľkoobchod 13; stavy Aktívne 8 814, Neaktívne 674, Odídené 631, Zrušené 31, Prepísané 1.

## A. Čo je odberné miesto
1. **Jedno EIC = jeden záznam OOM.** Ak má rovnaké EIC spotrebu aj výrobu (napr. domácnosť s FVE a výkupom), je to jedno OOM s oboma typmi naraz, nie dva záznamy. Alebo má výroba vždy vlastné EIC?
2. **Prepis na iného odberateľa.** EIC ostáva v CRM jeden záznam navždy. Mení sa iba zákazník: väzba OOM–zákazník má obdobie od–do. Pri prepise sa ukončí väzba so starým zákazníkom (pre neho stav Prepísané) a vznikne nová. História OOM tak ostane pokope.
3. **Kontrola EIC:** formát a kontrolná číslica slovenského EIC pri zadaní; CZ a HR až s pobočkami.

## B. Stavy
4. **Stavy:** Pripravované (zmluva podpísaná, dodávka ešte nezačala) → Aktívne → Neaktívne / Odídené / Zrušené / Prepísané. „Pripravované“ je nový stav – zodpovedá Čakajúcemu zákazníkovi.
5. **Čo presne znamená „Neaktívne“** v praxi (dočasne odpojené? skončená zmluva, ale OOM ostáva u nás? iné)?
6. **Kto mení stav:** Pripravované → Aktívne automaticky v deň začiatku dodávky, ak je zmena dodávateľa potvrdená. Odídené automaticky zo správy o odchode k inému dodávateľovi. Zrušené a Prepísané ručne (servis). Súhlas?

## C. Väzby
7. **OOM patrí v danom čase práve jednému zákazníkovi** (firma alebo domácnosť) a tej istej spoločnosti. Súhlas?
8. **Kontaktná osoba pri OOM** (napr. správca budovy, technik na prevádzke): voliteľne jedna alebo viac osôb z firmy zákazníka. Dnes sa väzba osoba–OOM odvodzuje cez dealy. Stačí návrh?

## D. Technické a fakturačné údaje
9. **Povinné pre stav Aktívne:** EIC, adresa, PDS, napäťová úroveň, sadzba distribúcie, plánovaná spotreba (VT/NT). Ostatné (číslo OP, typ merania, fázy, istič, rezervovaná kapacita…) nepovinné. Súhlas?
10. **PDS a sadzby ako číselníky v Nastaveniach** (ZSD, SSD, VSD + miestne distribučné sústavy; sadzby podľa PDS). Spravuje admin. Súhlas?
11. **Fakturačné údaje** (cenová regulácia, spotrebná daň, fakturačné obdobie, spôsob a výška záloh): patria k OOM alebo k zmluve? Návrh: k OOM, lebo sa môžu líšiť medzi OOM jednej zmluvy.
12. **Skutočná spotreba:** má CRM ukazovať aj skutočné odbery (napr. za posledných 12 mesiacov)? Odkiaľ – z fakturácie alebo z Cockpitu? Návrh: v module 2 iba plánovaná spotreba, skutočnú doplníme napojením na Cockpit neskôr.

## E. Výroba a zariadenia
13. **Údaje výroby:** druh zdroja (FVE, voda, bioplyn, vietor…), typ (Virtuálna batéria, Lokálny zdroj, Výrobný zdroj, Green VIWA), výkon zdroja, striedača a panelov, typ výkupnej zmluvy. Chýba niečo?
14. **Zariadenia na OOM** (striedač, panely, batéria, tepelné čerpadlo, wallbox – značka, model, výkon/kapacita): zoznam zariadení pri OOM. Vypĺňa ich zamestnanec v CRM, neskôr aj zákazník cez formulár. Súhlas?

## F. Zmena dodávateľa
15. **Správy XML433 / XML43D:** opíš prosím stručne, odkiaľ prichádzajú a čo znamenajú (príchod k nám, odchod od nás, iné). Návrh: v CRM sa uložia ako udalosti pri OOM (časová os) namiesto dnešných 7 370 „notifikačných“ dealov; e-mail zákazníkovi rieši modul Servis/Marketing.
16. **Prechod k nám ako postup na OOM:** výpoveď predošlému dodávateľovi odoslaná → akceptovaná → zmena dodávateľa potvrdená → začiatok dodávky. Každý krok s dátumom a CRM ukáže, kde sa proces zasekol. Súhlas?

## G. Obrazovky a práva
17. **Zoznam OOM:** EIC, názov/adresa, zákazník, typ, stav, PDS, plánovaná spotreba, dodávka od–do, vlastník. Filtre: typ, stav, PDS, spoločnosť. Hľadanie podľa EIC, adresy a zákazníka. Doplniť alebo vyhodiť?
18. **Práva:** OOM preberá vlastníka zákazníka (externý obchodník vidí iba OOM svojich zákazníkov). OOM zakladá obchodník alebo servis; technické údaje upravuje Servis a Nákup. Súhlas?
19. **Hromadný import OOM z Excelu** (napr. obec alebo sieť predajní s desiatkami OOM): áno, s kontrolou EIC a duplicít pred uložením?

## H. Nahrávanie dát z HubSpotu
20. **Čo nahrať:** OOM v stave Aktívne a Neaktívne (spolu 9 488) a Odídené za posledné 2 roky (kvôli kampaniam na návrat). Zrušené a staršie Odídené iba v archívnom exporte. Súhlas?
