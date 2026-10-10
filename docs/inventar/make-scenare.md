# Inventár Make scenárov napojených na HubSpot

Zdroj: Make API cez konektor (iba čítanie), organizácia „My Organization“ (eu1), tím „Greenlogy team“, stav k 10. 10. 2026.
Súbor je písaný ručne (nie je generovaný skriptom).

- Scenárov spolu: **83**, aktívnych 45, neaktívnych 38.
- S HubSpotom pracuje **52** scenárov (49 cez HubSpot modul, 3 iba cez HTTP), z toho **42 aktívnych**.
- Stĺpec „Behy / operácie“ je štatistika Make za posledných 30 dní.
- Popis „čo robí“ vychádza z názvu a použitých modulov. Detailne (z blueprintu) sú overené iba scenáre označené ✔.

## Bezpečnostné zistenia

1. **HubSpot token priamo v scenároch.** Scenáre „založiť kontakt sales portal Hubspot“ ✔, „Sales portál – Asociácia Kontakt-Firma“ ✔ a „Integration Webhooks, HTTP“ ✔ volajú HubSpot cez HTTP modul a private app token majú vpísaný ako text v hlavičke `Authorization`. Ktokoľvek s prístupom do Make (alebo k exportu blueprintu) token vidí. Odporúčanie: token presunúť do Make kľúčenky alebo HubSpot connection a následne ho v HubSpote zneplatniť a vydať nový.
2. **Webhook bez overenia.** „Integration Webhooks, HTTP“ ✔ nekontroluje tajný kľúč a vracia zoznam všetkých aktívnych vlastníkov z HubSpotu (mená, e-maily) komukoľvek, kto pozná URL webhooku. Ostatné Sales portál webhooky kontrolujú `_secret`, ten je však tiež vpísaný ako text vo filtri.
3. **CORS `*`.** Odpovede Sales portál webhookov povoľujú volanie z ľubovoľnej domény.

Žiadna z týchto vecí sa v module 0 nemení; ide o návrh na samostatné rozhodnutie.

## Aktívne scenáre s HubSpotom

### Sales portál (webhooky volané z obchodného portálu)

| Scenár | Spúšťač | HubSpot operácie | Čo robí | Behy / operácie |
| --- | --- | --- | --- | --- |
| založiť kontakt sales portal Hubspot ✔ | webhook | HTTP: vytvorenie / úprava kontaktu, asociácia kontakt–firma, čítanie kontaktu | Založí kontakt (alebo pri duplicite vráti existujúci), priradí vlastníka a firmu; aktualizuje existujúci kontakt | – |
| Sales portál – Asociácia Kontakt-Firma ✔ | webhook | HTTP: asociácia kontakt–firma | Prepojí kontakt s firmou | 0 / 0 |
| Sales portál – create company | webhook | vytvorenie firmy | Založí firmu | 0 / 0 |
| Sales portál – Finstat | webhook | vyhľadávanie, čítanie kontaktu a používateľa + HTTP (Finstat) | Vyhľadá firmu vo Finstate a v HubSpote | 0 / 0 |
| Sales portál – Načítanie provízií z HubSpotu | webhook | vyhľadávanie dealov | Načíta provízie z dealov v pipeline stages 2026–2029 | 1 / 4 |
| Sales portál – Update provízie | webhook | úprava dealu + Firestore, Drive, e-mail | Zapíše zmenu provízie do dealu | 0 / 0 |
| Sales portál – Zrušiť províziu | webhook | úprava záznamu, API volanie + Drive | Zruší províziu na deale | 0 / 0 |
| Integration Webhooks, HTTP ✔ | webhook | HTTP: zoznam vlastníkov | Vráti zoznam aktívnych vlastníkov (pre výber obchodníka v portáli) | 0 / 0 |

### Vstup obchodov a kontaktov

| Scenár | Spúšťač | HubSpot operácie | Čo robí | Behy / operácie |
| --- | --- | --- | --- | --- |
| Greenlogy HUBSPOT XMT XML433 Domacnosti 202305 | webhook | hľadanie a vytvorenie kontaktu, vytvorenie dealu, asociácia | Zo správy o zmene dodávateľa (XML433, domácnosti – spotreba) založí kontakt a deal | 0 / 0 |
| Greenlogy HUBSPOT XMT XML43D Domacnosti 202403 | webhook | rovnaké | To isté pre výrobu (XML43D), domácnosti | 0 / 0 |
| Greenlogy HUBSPOT XMT XML43D Organizacie 202403 | webhook | rovnaké | To isté pre výrobu (XML43D), organizácie | 0 / 0 |
| Greenlogy HUBSPOT CenovaPonukaDomacnosti 202211 | webhook | vytvorenie / úprava kontaktu + MySQL, SendGrid | Cenová ponuka pre domácnosti z webu: uloží kontakt, pošle ponuku e-mailom | 0 / 0 |
| Greenlogy HUBSPOT GreenCAR odoslanie poukazky 202403 | webhook | hľadanie a vytvorenie kontaktu, vytvorenie dealu, asociácia | Poukážka GreenCar: kontakt + deal, odoslanie poukážky | 49 / 295 |
| twin webformular | webhook | vytvorenie záznamu | Webový formulár Twinlogy → záznam v HubSpote | 0 / 0 |
| TEST ponuky.optest – Greenlogy CP 202204 | webhook | vytvorenie / úprava kontaktu, vytvorenie záznamu | Testovacia verzia cenovej ponuky – **aktívna, hoci je to test** | 0 / 0 |

### Údržba dát (plánované)

| Scenár | Spúšťač | HubSpot operácie | Čo robí | Behy / operácie |
| --- | --- | --- | --- | --- |
| FINSTAT (cron) – Greenlogy HUBSPOT – Update organizacie 3min. 202403 | každé 3 min | vyhľadávanie a úprava firiem + HTTP (Finstat) | Dopĺňa údaje firiem z Finstatu; **najvyťaženejší scenár** | 14 369 / 17 654 |
| HubSpot: prepojenie kontaktov s OOM (údržba) | každú hodinu | API volania + data store, kód | Priraďuje OOM kontaktom podľa dealov (doménové pravidlo kontakt–OOM) | 290 / 4 058 |
| Greenlogy – HUBSPOT CRM – vymaže @greenlogy.com kontakty denne o 12:00 | denne | čítanie, mazanie | Maže interné kontakty s doménou greenlogy.com | 30 / 412 |
| Megawatts – HUBSPOT CRM – vymaže @megawatts.eu kontakty denne o 12:00 (copy) | denne | čítanie, mazanie | Maže kontakty s doménou megawatts.eu | 30 / 840 |
| Greenlogy HUBSPOT Vymaz firmy bez nazvu 1x denne | denne | vyhľadávanie, mazanie firiem | Maže firmy bez názvu | 30 / 81 |

### Tickety

| Scenár | Spúšťač | HubSpot operácie | Čo robí | Behy / operácie |
| --- | --- | --- | --- | --- |
| Megawatts Tickets OdpovedalZakaznik hubspot | každých 30 min | zoznam a úprava ticketov | Mení stav ticketu, keď odpovedal zákazník | 1 440 / 1 444 |
| Megawatts Tickets REopen hubspot | každých 30 min | zoznam a úprava ticketov | Znovu otvára tickety | 1 440 / 1 449 |

### Reporting

| Scenár | Spúšťač | HubSpot operácie | Čo robí | Behy / operácie |
| --- | --- | --- | --- | --- |
| CEO Weekly Brief | týždenne | vyhľadávanie v CRM + Kalendár, Docs, Drive, e-mail, Slack | Týždenný prehľad pre CEO | 4 / 80 |

### Jednorazové nástroje na čistenie dát (spúšťané na požiadanie)

19 scenárov vytvorených v júni a júli 2026, volaných ako nástroje (scenario-service + HubSpot API volanie). Väčšinou 0 behov za posledných 30 dní. Do nového CRM sa neprenášajú – ich úlohu prevezme migrácia.

B2C OOM trace, Get OOM detail, List OOM page, Search OOM by eic, OOM eic by id, OOM read deals, OOM deal batch update, OOM flag matched, OOM dup audit (read), OOM page dump (read), OOM pipelines meta (read), OOM verify by eic (read), OOM set active SPOTREBA, OOM set active VYROBA, Greenlogy – Parovanie OOM na dealy 2027 v5, company audit writer, company lifecycle batch, lost deal audit part1, lost deal orphan part2.

## Neaktívne scenáre s HubSpotom

| Scenár | Posledná úprava | Poznámka |
| --- | --- | --- |
| HUBSPOT_XM TRADE_HEO_synchronizácia_OOM_CREATE | 2023-07-14 | Google Sheets → OOM; pravdepodobne pôvodný import OOM |
| HUBSPOT_XM TRADE_HEO_synchronizácia_ZML.CENY_CREATE | 2023-07-15 | Google Sheets → Zmluvné ceny; pravdepodobne pôvodný import |
| Sales portál – synchro users | 2026-05-28 | HubSpot → Firestore (používatelia portálu) |
| Megawatts Hubspot NOTIFY | 2026-06-09 | |
| BACKUP Greenlogy HUBSPOT CenovaPonukaDomacnosti 202211 (copy) | 2024-02-01 | záloha |
| Greenlogy CP 202204 | 2022-10-14 | staršia verzia cenovej ponuky |
| NEPOUZIVAT Finstat_Hubspot_2024_FINAL VER. | 2024-02-02 | |
| NEPOUZIVAT Greenlogy HUBSPOT – Update organizacie FINSTAT TEST POISTKA | 2024-04-01 | |
| hubspot (ig) webhook finstat_GLG | 2024-01-27 | |
| TEST Greenlogy GreenCAR odoslanie poukazky TEST 20240331 | 2024-03-31 | |

## Scenáre bez HubSpotu (pre úplnosť)

- **Aktívne:** FINSTAT (jadro) (volá ho cron vyššie), Sales portál – Finstat autocomplete, Posli SMS API.
- **Neaktívne:** EVERFIN (6 scenárov, prod a stage), Delta Green (2), Greenlogy – Daily Forward / SK spot prices → Firestore, DIAG – Montel Spot, Integration HTTP, Integration Slack, Sales portál – HS kontakty, BACKUP Sales portál – Kontakt, NEPOUZIVAT FINSTAT (jadro) (copy), NEPOUZIVAT Integration Webhooks, testy odoslania CP s VBattery (11), sbook test.

## Dôsledky pre nové CRM

1. **Sales portál** dnes píše do HubSpotu cez Make. V novom CRM ho treba napojiť priamo na API jadra (kontakty, firmy, asociácie, provízie, vlastníci). Make tu odpadá.
2. **Vstup zo správ o zmene dodávateľa (XML433, XML43D)** zakladá kontakty a dealy. Treba ho presmerovať na webhook jadra.
3. **Údržbu dát** prevezme samotné jadro: priradenie OOM kontaktom je doménové pravidlo, mazanie interných kontaktov a firiem bez názvu nahradí validácia pri zápise.
4. **Finstat** zostane ako služba na obohatenie firiem, volaná z jadra namiesto cronu každé 3 minúty.
5. **Tickety Megawatts** (zmena stavu po odpovedi, znovuotvorenie) patria do servisného modulu, resp. do Chatwootu.
6. **CEO Weekly Brief** bude čítať z databázy jadra (prípadne cez Cockpit).
