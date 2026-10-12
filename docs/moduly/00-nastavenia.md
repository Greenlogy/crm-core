# Modul 0 – Nastavenia: zadanie

Verzia 0.2 · 12. 10. 2026 · **schválené Petrom** (v0.2 = zapracované odpovede na otvorené otázky).
Vychádza z odpovedí v `00-nastavenia-otazky.md` (12. 10. 2026).

## 1. Čo modul rieši

Všetko, čo CRM potrebuje, aby fungovalo pre viac spoločností a tímov, bez zásahu programátora:
spoločnosti skupiny, používatelia a ich práva, údaje firmy do dokumentov, pracovný čas, číselníky, vlastné polia, pipelines a stage, audit.

**Princíp:** v Nastaveniach sa dá **pridávať** (polia, hodnoty výberov, pipelines, stage, odkazy na záznamy), ale **nie meniť jadro** (IČO, EIC, stavy zákazníka, väzby, na ktorých stojí logika). Jadro sa mení iba v kóde cez schválené zadanie. Nastavenia mení iba admin a každá zmena ide do auditu.

## 2. Spoločnosti skupiny (viac krajín)

CRM bude slúžiť Greenlogy na Slovensku a pobočkám v Česku a Chorvátsku. Preto má každý dôležitý záznam určené, ku ktorej spoločnosti patrí.

Pobočky sú samostatné firmy s vlastným IČO (CZ) alebo OIB (HR). Začnú CRM používať najskôr koncom 2027, možno 2028.

| Spoločnosť | Krajina | Mena | Identifikátor firiem zákazníkov | Register firiem |
| --- | --- | --- | --- | --- |
| Greenlogy a.s. | SK | EUR | IČO, 8 číslic | FinStat |
| česká spoločnosť | CZ | CZK | IČO, 8 číslic | ARES (napojí sa neskôr) |
| chorvátska spoločnosť | HR | EUR | OIB, 11 číslic | súdny register (napojí sa neskôr) |

**Teraz sa pripraví iba štruktúra:** každý záznam má spoločnosť (predvolene Greenlogy a.s.), používateľ má prístup k spoločnostiam, nastavenia (údaje do dokumentov, pracovný čas, mena) sú pre každú spoločnosť zvlášť. Registre ARES a chorvátsky register, preklady aplikácie a práca s CZK sa doplnia pred spustením pobočiek.

Pravidlá:
- Spoločnosť má vlastné údaje do dokumentov (časť 4), vlastný pracovný čas a sviatky (časť 5) a vlastnú menu.
- Zákazník (firma aj osoba), odberné miesto, deal, zmluva a ponuka patria práve jednej spoločnosti. Ten istý zákazník nemôže byť zákazníkom dvoch spoločností.
- Tímy CEO, Marketing a Nákup vidia všetky spoločnosti skupiny. Ostatní vidia iba spoločnosť (spoločnosti), ku ktorým im admin dal prístup.
- Číselníky, vlastné polia a pipelines môžu byť spoločné pre celú skupinu alebo iba pre jednu spoločnosť.
- Jazyk aplikácie: zatiaľ slovenčina, preklady sa doplnia pri spustení pobočky.

**Dopad na modul 1 Zákazníci:** firma dostane krajinu a identifikátor podľa krajiny. Pravidlo „IČO = 8 číslic“ platí pre SK a CZ, pre HR platí OIB s 11 číslicami. Unikátnosť je krajina + identifikátor. To je drobná doplnková migrácia k `0004`.

## 3. Používatelia, tímy a práva

### Používateľ
- Pridáva a deaktivuje ho iba admin (Peter + jeden zástupca).
- Prihlásenie: zamestnanci cez Google účet @greenlogy.com, externí cez jednorazový kód poslaný e-mailom.
- Patrí do jedného tímu, má prístup k jednej alebo viacerým spoločnostiam, môže mať príznak **admin** (smie meniť Nastavenia).
- Pri deaktivácii CRM vyžiada nového vlastníka pre jeho zákazníkov a otvorené dealy.

### Tím = skupina práv
Práva sa nastavujú tímu, nie jednotlivým ľuďom. Používateľ dostane práva svojho tímu.

| Tím | Typ prístupu (východiskový) |
| --- | --- |
| CEO | vedenie: všetko vidí a upravuje, mení vlastníkov |
| Sales_internal | obchodník: vidí všetko, upravuje zákazníkov a dealy |
| Sales_external | externý obchodník: vidí a upravuje iba svojich zákazníkov (časť 6 zadania Zákazníci) |
| Servis | vidí všetko, upravuje kontaktné údaje a servisné záznamy |
| Nákup | vidí všetko, upravuje odberné miesta, ceny a nákupné údaje |
| Marketing | vidí všetko, upravuje marketingové údaje a súhlasy |

Rola externý dodávateľ ostáva v systéme pripravená. Tím pre ňu sa založí, keď bude treba.

### Nastavenie práv tímu
Pre každý modul (Zákazníci, Odberné miesta, Obchod, Zmluvy, Servis, Marketing, Provízie):
- **Vidieť:** všetko / iba svoje / nič
- **Upravovať:** všetko / iba svoje / nič
- **Archivovať:** áno / nie
- **Exportovať:** áno / nie

„Iba svoje“ = záznamy, kde je používateľ vlastníkom. Pri tíme Sales_external platí obmedzenie aj priamo v databáze (RLS), nielen v aplikácii.

## 4. Údaje spoločnosti do dokumentov

Pre každú spoločnosť: obchodné meno, IČO, DIČ, IČ DPH, sídlo, zápis v obchodnom registri, štatutári, bankové účty (viac, s označením účelu), logo, zákaznícka linka, e-mail, web, číslo povolenia regulátora (SK ÚRSO, CZ ERÚ, HR HERA).
Použijú sa v hlavičke ponúk, zmlúv a e-mailov.

## 5. Pracovný čas a sviatky

- Pre každú spoločnosť zvlášť. SK: Po–Pi 7:30–15:30.
- Štátne sviatky krajiny sa doplnia automaticky, admin pridá ďalšie dni (firemné voľno).
- Používa sa na výpočet SLA (8 a 24 pracovných hodín).

## 6. Číselníky

- Zdroj kontaktu, dôvod odchodu zákazníka, dôvod prehratého dealu, predchádzajúci dodávateľ (konkurencia), roly kontaktu vo firme.
- Hodnota sa nikdy nemaže, iba skryje. Staré záznamy ju zobrazujú ďalej.

## 7. Vlastné polia

- Pre záznamy: firma, osoba, odberné miesto, deal, zmluva, ponuka.
- Typy: text, dlhý text, číslo, suma v mene spoločnosti, dátum, výber jednej hodnoty, výber viacerých hodnôt, áno/nie, odkaz na iný záznam.
- Nastavenia poľa: názov, povinné áno/nie, sekcia na karte, poradie, zobraziť ako stĺpec v zozname, filtrovať podľa neho, ktoré tímy ho môžu upravovať, platí pre celú skupinu alebo jednu spoločnosť.
- Zrušenie: pole sa archivuje, údaje ostanú, dá sa obnoviť.

## 8. Pipelines a stage

- Pipeline: názov, spoločnosť, pre aký druh obchodu.
- Stage: názov, poradie, pravdepodobnosť %, typ otvorený / vyhraný / prehraný, povinné polia pri prechode.
- Konkrétne pipelines a stage sa navrhnú v module Obchod.

## 9. Audit

Prehľad zmien v Nastaveniach aj v dátach: kto, čo, kedy, stará a nová hodnota. Filter podľa používateľa, záznamu, obdobia.

## 10. Prostredia a adresy

- **Test** (Neon `dev`): na skúšanie, testovacie údaje sa môžu kedykoľvek zmazať.
- **Ostré** (Neon `main`): modul sa nasadí až po schválení na Teste.
- Adresy `test-crm.greenlogy.sk` a `crm.greenlogy.sk` vyžadujú presun DNS domény greenlogy.sk do Cloudflare (časť 12).

## 11. Príklady dopadov

1. **Nový obchodník.** Admin pridá Jana Malého, tím Sales_internal, spoločnosť Greenlogy SK. Jano sa prihlási Google účtom a hneď má práva tímu. Nikto mu nenastavuje práva jednotlivo.
2. **Zmena práv tímu.** Vedenie rozhodne, že Servis môže exportovať zoznamy. Admin zapne export v tíme Servis a platí to pre všetkých 5 ľudí naraz.
3. **Externý partner.** Admin pridá obchodníka partnera s e-mailom mimo Google, tím Sales_external. Prihlási sa kódom z e-mailu a vidí iba svojich zákazníkov.
4. **Česká spoločnosť (od 2027/2028).** Český obchodník má prístup iba k spoločnosti CZ. Založí firmu s IČO, CRM overí údaje v ARES, sumy sú v CZK. Slovenských zákazníkov nevidí. Marketing a Nákup vidia zákazníkov všetkých spoločností.
5. **Nové pole.** Marketing chce pri osobe pole „Má tepelné čerpadlo“ (áno/nie). Admin ho pridá v Nastaveniach, zobrazí sa na karte osoby a dá sa podľa neho filtrovať. Programátor netreba.
6. **Odchod zamestnanca.** Admin deaktivuje obchodníka. CRM ukáže jeho 120 zákazníkov a 8 otvorených dealov a vyžiada si nového vlastníka, inak deaktiváciu nedokončí.

## 12. Rozhodnuté 12. 10. 2026

- Pobočky v CZ a HR sú samostatné firmy s vlastným IČO / OIB.
- Zákazník patrí iba jednej spoločnosti, nemôže byť zákazníkom dvoch.
- Všetky spoločnosti vidia tímy CEO, Marketing a Nákup; ostatní iba svoju.
- Pobočky začnú najskôr koncom 2027 (možno 2028): teraz iba štruktúra, registre a preklady neskôr.
- DNS: Test beží na adrese od Cloudflare; presun DNS greenlogy.sk do Cloudflare až pred spustením Ostrého, so zálohou všetkých záznamov (e-mail, Webflow).
