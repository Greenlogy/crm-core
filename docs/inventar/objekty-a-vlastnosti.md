# Inventár HubSpotu – objekty a vlastnosti

Vygenerované skriptom `integrations/hubspot-sync/inventory` (10. októbra 2026) z HubSpot portálu 5964726.
Ručne needitovať – pri ďalšom behu sa súbor prepíše. Komentáre a závery patria do `suhrn.md`.

## Počty záznamov

| Objekt | HubSpot typ | Záznamov |
| --- | --- | --- |
| Firmy | `companies` | 3 003 |
| Kontakty | `contacts` | 8 506 |
| Dealy | `deals` | 15 601 |
| Tickety | `tickets` | 61 723 |
| OOM | `2-16666415` | 10 151 |
| Zmluvné ceny | `2-16395301` | 11 797 |
| Nákupné ceny | `2-22997964` | 1 163 |

| Kontakty | Počet | % |
| --- | --- | --- |
| s firmou (B2B) | 2 628 | 30,9 % |
| bez firmy (B2C) | 5 878 | 69,1 % |

B2B/B2C sa určuje podľa primárnej firmy kontaktu (`associatedcompanyid`).

## Custom objekty

| objectTypeId | Názov | Label | Zobrazovaná vlastnosť | Povinné vlastnosti | Vytvorené |
| --- | --- | --- | --- | --- | --- |
| `2-17012865` | trading_books | 4. Trading_book | protistrana | protistrana | 2023-07-25 |
| `2-16666415` | oom | 1. OOM | subjekt | subjekt | 2023-07-13 |
| `2-16395301` | zmluvn__ceny | 2. Zmluvné ceny | cenn_k | cenn_k | 2023-07-04 |
| `2-22997964` | nakupne_ceny | 3. Nákupné ceny | produkt | produkt | 2024-01-27 |

## Asociácie

### Typy asociácií

| Z | Do | Kategória | typeId | Label |
| --- | --- | --- | --- | --- |
| Firmy | Kontakty | USER_DEFINED | 6 | Board Member |
| Firmy | Kontakty | USER_DEFINED | 8 | Manager |
| Firmy | Kontakty | HUBSPOT_DEFINED | 280 | (bez labelu) |
| Firmy | Kontakty | HUBSPOT_DEFINED | 2 | Contact with Primary Company |
| Firmy | Kontakty | USER_DEFINED | 10 | Owner |
| Firmy | Kontakty | USER_DEFINED | 12 | Contractor |
| Firmy | Kontakty | USER_DEFINED | 2 | Advisor |
| Firmy | Kontakty | HUBSPOT_DEFINED | 930 | Billing Contact |
| Firmy | Kontakty | USER_DEFINED | 4 | Partner |
| Firmy | Dealy | HUBSPOT_DEFINED | 342 | (bez labelu) |
| Firmy | Dealy | HUBSPOT_DEFINED | 6 | Deal with Primary Company |
| Firmy | Dealy | USER_DEFINED | 234 | Subjekt |
| Firmy | Tickety | HUBSPOT_DEFINED | 340 | (bez labelu) |
| Firmy | Tickety | HUBSPOT_DEFINED | 25 | Ticket with Primary Company |
| Firmy | OOM | USER_DEFINED | 194 | Subjekt |
| Firmy | OOM | USER_DEFINED | 192 | (bez labelu) |
| Firmy | Zmluvné ceny | USER_DEFINED | 145 | (bez labelu) |
| Firmy | Zmluvné ceny | USER_DEFINED | 147 | Subjekt |
| Kontakty | Firmy | USER_DEFINED | 3 | Partner |
| Kontakty | Firmy | USER_DEFINED | 1 | Advisor |
| Kontakty | Firmy | HUBSPOT_DEFINED | 279 | (bez labelu) |
| Kontakty | Firmy | HUBSPOT_DEFINED | 931 | Billing Contact |
| Kontakty | Firmy | HUBSPOT_DEFINED | 1 | Primary |
| Kontakty | Firmy | USER_DEFINED | 5 | Board Member |
| Kontakty | Firmy | USER_DEFINED | 7 | Manager |
| Kontakty | Firmy | USER_DEFINED | 11 | Contractor |
| Kontakty | Firmy | USER_DEFINED | 9 | Owner |
| Kontakty | Dealy | USER_DEFINED | 236 | Subjekt |
| Kontakty | Dealy | HUBSPOT_DEFINED | 4 | (bez labelu) |
| Kontakty | Dealy | USER_DEFINED | 18 | Párovanie contact-Deal |
| Kontakty | Tickety | HUBSPOT_DEFINED | 15 | (bez labelu) |
| Kontakty | Tickety | USER_DEFINED | 21 | Last name |
| Kontakty | OOM | USER_DEFINED | 196 | (bez labelu) |
| Kontakty | OOM | USER_DEFINED | 238 | Subjekt |
| Kontakty | Zmluvné ceny | USER_DEFINED | 170 | Company name |
| Kontakty | Zmluvné ceny | USER_DEFINED | 164 | (bez labelu) |
| Kontakty | Zmluvné ceny | USER_DEFINED | 166 | Subjekt |
| Dealy | Firmy | HUBSPOT_DEFINED | 5 | Primary |
| Dealy | Firmy | USER_DEFINED | 233 | Company name |
| Dealy | Firmy | HUBSPOT_DEFINED | 341 | (bez labelu) |
| Dealy | Kontakty | HUBSPOT_DEFINED | 3 | (bez labelu) |
| Dealy | Kontakty | USER_DEFINED | 235 | Subjekt_firma |
| Dealy | Kontakty | USER_DEFINED | 17 | Párovanie contact-Deal |
| Dealy | Tickety | HUBSPOT_DEFINED | 27 | (bez labelu) |
| Dealy | Tickety | USER_DEFINED | 19 | Subjekt |
| Dealy | OOM | USER_DEFINED | 206 | Číslo Greenlogy zmluvy |
| Dealy | OOM | USER_DEFINED | 210 | XML433Domacnosti_eic |
| Dealy | OOM | USER_DEFINED | 198 | (bez labelu) |
| Dealy | OOM | USER_DEFINED | 231 | EIC |
| Dealy | OOM | USER_DEFINED | 264 | Číslo zmluvy Greenlogy |
| Dealy | Zmluvné ceny | USER_DEFINED | 154 | Číslo Greenlogy zmluvy |
| Dealy | Zmluvné ceny | USER_DEFINED | 152 | (bez labelu) |
| Dealy | Nákupné ceny | USER_DEFINED | 256 | (bez labelu) |
| Dealy | Nákupné ceny | USER_DEFINED | 258 | Cena |
| Dealy | Nákupné ceny | USER_DEFINED | 262 | Dátum nákupnej ceny |
| Tickety | Firmy | HUBSPOT_DEFINED | 26 | Primary |
| Tickety | Firmy | HUBSPOT_DEFINED | 339 | (bez labelu) |
| Tickety | Kontakty | HUBSPOT_DEFINED | 16 | (bez labelu) |
| Tickety | Kontakty | USER_DEFINED | 22 | Last name |
| Tickety | Dealy | HUBSPOT_DEFINED | 28 | (bez labelu) |
| Tickety | Dealy | USER_DEFINED | 20 | Subjekt |
| Tickety | OOM | USER_DEFINED | 200 | (bez labelu) |
| Tickety | OOM | USER_DEFINED | 212 | EIC |
| Tickety | Zmluvné ceny | USER_DEFINED | 160 | (bez labelu) |
| Tickety | Zmluvné ceny | USER_DEFINED | 162 | EIC |
| OOM | Firmy | USER_DEFINED | 193 | Subjekt |
| OOM | Firmy | USER_DEFINED | 191 | (bez labelu) |
| OOM | Kontakty | USER_DEFINED | 237 | Subjekt_firma |
| OOM | Kontakty | USER_DEFINED | 195 | (bez labelu) |
| OOM | Dealy | USER_DEFINED | 263 | test číslo zmluvy |
| OOM | Dealy | USER_DEFINED | 232 | XML43DDomacnosti_eic |
| OOM | Dealy | USER_DEFINED | 197 | (bez labelu) |
| OOM | Dealy | USER_DEFINED | 205 | Číslo Greenlogy zmluvy |
| OOM | Dealy | USER_DEFINED | 209 | XML433Domacnosti_eic |
| OOM | Tickety | USER_DEFINED | 211 | EIC |
| OOM | Tickety | USER_DEFINED | 199 | (bez labelu) |
| OOM | Zmluvné ceny | USER_DEFINED | 201 | (bez labelu) |
| OOM | Zmluvné ceny | USER_DEFINED | 213 | EIC |
| Zmluvné ceny | Firmy | USER_DEFINED | 146 | (bez labelu) |
| Zmluvné ceny | Firmy | USER_DEFINED | 148 | Subjekt |
| Zmluvné ceny | Kontakty | USER_DEFINED | 163 | (bez labelu) |
| Zmluvné ceny | Kontakty | USER_DEFINED | 169 | Company name |
| Zmluvné ceny | Kontakty | USER_DEFINED | 165 | Subjekt |
| Zmluvné ceny | Dealy | USER_DEFINED | 151 | (bez labelu) |
| Zmluvné ceny | Dealy | USER_DEFINED | 153 | Číslo Greenlogy zmluvy |
| Zmluvné ceny | Tickety | USER_DEFINED | 161 | EIC |
| Zmluvné ceny | Tickety | USER_DEFINED | 159 | (bez labelu) |
| Zmluvné ceny | OOM | USER_DEFINED | 202 | (bez labelu) |
| Zmluvné ceny | OOM | USER_DEFINED | 214 | EIC |
| Nákupné ceny | Dealy | USER_DEFINED | 257 | Cena |
| Nákupné ceny | Dealy | USER_DEFINED | 261 | Dátum nákupnej ceny |
| Nákupné ceny | Dealy | USER_DEFINED | 255 | (bez labelu) |

### Počty asociácií na záznam

Na jeden záznam sa počíta najviac 500 asociácií; viac je v stĺpci „500+“.

| Z | Do | Záznamov | 0 | 1 | 2–5 | 6–10 | 11–50 | 51–100 | 101–500 | 500+ | Max | Priemer |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Firmy | Kontakty | 3 003 | 590 | 2 026 | 377 | 7 | 3 | 0 | 0 | 0 | 32 | 1 |
| Firmy | Dealy | 3 003 | 1 114 | 986 | 841 | 56 | 6 | 0 | 0 | 0 | 19 | 1,31 |
| Firmy | Tickety | 3 003 | 899 | 605 | 646 | 390 | 432 | 25 | 6 | 0 | 381 | 5,59 |
| Firmy | OOM | 3 003 | 3 001 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Firmy | Zmluvné ceny | 3 003 | 3 000 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Kontakty | Firmy | 8 506 | 5 763 | 2 528 | 214 | 1 | 0 | 0 | 0 | 0 | 6 | 0,35 |
| Kontakty | Dealy | 8 506 | 3 209 | 1 552 | 3 162 | 408 | 174 | 1 | 0 | 0 | 51 | 1,98 |
| Kontakty | Tickety | 8 506 | 1 694 | 1 824 | 1 789 | 1 704 | 1 463 | 27 | 5 | 0 | 500 | 5,69 |
| Kontakty | OOM | 8 506 | 4 198 | 988 | 3 084 | 159 | 61 | 16 | 0 | 0 | 76 | 1,4 |
| Kontakty | Zmluvné ceny | 8 506 | 8 504 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Dealy | Firmy | 15 601 | 11 709 | 3 847 | 45 | 0 | 0 | 0 | 0 | 0 | 2 | 0,25 |
| Dealy | Kontakty | 15 601 | 466 | 14 178 | 924 | 18 | 15 | 0 | 0 | 0 | 32 | 1,08 |
| Dealy | Tickety | 15 601 | 13 459 | 1 485 | 597 | 38 | 22 | 0 | 0 | 0 | 30 | 0,24 |
| Dealy | OOM | 15 601 | 8 449 | 3 162 | 3 854 | 69 | 57 | 9 | 1 | 0 | 112 | 0,89 |
| Dealy | Zmluvné ceny | 15 601 | 8 804 | 2 814 | 3 847 | 65 | 61 | 9 | 1 | 0 | 112 | 0,87 |
| Dealy | Nákupné ceny | 15 601 | 14 734 | 859 | 8 | 0 | 0 | 0 | 0 | 0 | 3 | 0,06 |
| Tickety | Firmy | 61 722 | 45 851 | 15 016 | 855 | 0 | 0 | 0 | 0 | 0 | 4 | 0,27 |
| Tickety | Kontakty | 61 722 | 16 152 | 43 229 | 2 311 | 27 | 3 | 0 | 0 | 0 | 16 | 0,78 |
| Tickety | Dealy | 61 722 | 58 951 | 2 150 | 612 | 8 | 1 | 0 | 0 | 0 | 13 | 0,06 |
| Tickety | OOM | 61 722 | 61 720 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Tickety | Zmluvné ceny | 61 722 | 61 722 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| OOM | Firmy | 10 151 | 10 149 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| OOM | Kontakty | 10 151 | 778 | 8 301 | 982 | 12 | 78 | 0 | 0 | 0 | 32 | 1,18 |
| OOM | Dealy | 10 151 | 15 | 8 093 | 2 038 | 4 | 1 | 0 | 0 | 0 | 11 | 1,36 |
| OOM | Tickety | 10 151 | 10 149 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| OOM | Zmluvné ceny | 10 151 | 2 | 9 148 | 1 001 | 0 | 0 | 0 | 0 | 0 | 5 | 1,16 |
| Zmluvné ceny | Firmy | 11 797 | 11 794 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Zmluvné ceny | Kontakty | 11 797 | 11 795 | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 |
| Zmluvné ceny | Dealy | 11 797 | 70 | 10 426 | 1 299 | 2 | 0 | 0 | 0 | 0 | 6 | 1,15 |
| Zmluvné ceny | Tickety | 11 797 | 11 797 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| Zmluvné ceny | OOM | 11 797 | 46 | 11 745 | 6 | 0 | 0 | 0 | 0 | 0 | 2 | 1 |
| Nákupné ceny | Dealy | 1 163 | 842 | 136 | 151 | 23 | 11 | 0 | 0 | 0 | 32 | 0,75 |

### Asociácie podľa labelu

| Z | Do | Label | Počet asociácií |
| --- | --- | --- | --- |
| Firmy | Kontakty | (bez labelu, typ 280) | 3 002 |
| Firmy | Kontakty | Contact with Primary Company | 2 628 |
| Firmy | Dealy | Subjekt | 2 458 |
| Firmy | Dealy | (bez labelu, typ 342) | 3 937 |
| Firmy | Dealy | Deal with Primary Company | 3 860 |
| Firmy | Tickety | (bez labelu, typ 340) | 16 776 |
| Firmy | Tickety | Ticket with Primary Company | 15 570 |
| Firmy | OOM | (bez labelu, typ 192) | 2 |
| Firmy | Zmluvné ceny | (bez labelu, typ 145) | 3 |
| Kontakty | Firmy | (bez labelu, typ 279) | 3 002 |
| Kontakty | Firmy | Primary | 2 628 |
| Kontakty | Dealy | (bez labelu, typ 4) | 16 869 |
| Kontakty | Dealy | Párovanie contact-Deal | 514 |
| Kontakty | Dealy | Subjekt | 1 237 |
| Kontakty | Tickety | (bez labelu, typ 15) | 48 448 |
| Kontakty | Tickety | Last name | 1 |
| Kontakty | OOM | (bez labelu, typ 196) | 11 941 |
| Kontakty | OOM | Subjekt | 199 |
| Kontakty | Zmluvné ceny | (bez labelu, typ 164) | 2 |
| Dealy | Firmy | Primary | 3 860 |
| Dealy | Firmy | (bez labelu, typ 341) | 3 937 |
| Dealy | Firmy | Company name | 2 458 |
| Dealy | Kontakty | (bez labelu, typ 3) | 16 869 |
| Dealy | Kontakty | Párovanie contact-Deal | 514 |
| Dealy | Kontakty | Subjekt_firma | 1 237 |
| Dealy | Tickety | (bez labelu, typ 27) | 3 685 |
| Dealy | OOM | XML433Domacnosti_eic | 245 |
| Dealy | OOM | (bez labelu, typ 198) | 13 839 |
| Dealy | OOM | Číslo Greenlogy zmluvy | 11 618 |
| Dealy | OOM | EIC | 110 |
| Dealy | Zmluvné ceny | Číslo Greenlogy zmluvy | 11 014 |
| Dealy | Zmluvné ceny | (bez labelu, typ 152) | 13 516 |
| Dealy | Nákupné ceny | (bez labelu, typ 256) | 878 |
| Dealy | Nákupné ceny | Dátum nákupnej ceny | 878 |
| Tickety | Firmy | Primary | 15 570 |
| Tickety | Firmy | (bez labelu, typ 339) | 16 776 |
| Tickety | Kontakty | (bez labelu, typ 16) | 48 450 |
| Tickety | Kontakty | Last name | 1 |
| Tickety | Dealy | (bez labelu, typ 28) | 3 685 |
| Tickety | OOM | (bez labelu, typ 200) | 2 |
| OOM | Firmy | (bez labelu, typ 191) | 2 |
| OOM | Kontakty | (bez labelu, typ 195) | 11 941 |
| OOM | Kontakty | Subjekt_firma | 199 |
| OOM | Dealy | Číslo Greenlogy zmluvy | 11 618 |
| OOM | Dealy | (bez labelu, typ 197) | 13 839 |
| OOM | Dealy | XML433Domacnosti_eic | 245 |
| OOM | Dealy | XML43DDomacnosti_eic | 110 |
| OOM | Tickety | (bez labelu, typ 199) | 2 |
| OOM | Zmluvné ceny | (bez labelu, typ 201) | 11 757 |
| OOM | Zmluvné ceny | EIC | 11 241 |
| Zmluvné ceny | Firmy | (bez labelu, typ 146) | 3 |
| Zmluvné ceny | Kontakty | (bez labelu, typ 163) | 2 |
| Zmluvné ceny | Dealy | Číslo Greenlogy zmluvy | 11 014 |
| Zmluvné ceny | Dealy | (bez labelu, typ 151) | 13 516 |
| Zmluvné ceny | OOM | EIC | 11 241 |
| Zmluvné ceny | OOM | (bez labelu, typ 202) | 11 757 |
| Nákupné ceny | Dealy | Dátum nákupnej ceny | 878 |
| Nákupné ceny | Dealy | (bez labelu, typ 255) | 878 |

## Vlastnosti

### Firmy (`companies`)

Vlastností spolu: 322 (vlastné 46, HubSpot 276). Záznamov: 3 003.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `ake_sluzby_mate_u_nas_zazmluvnene_` | Aké služby máte u nás zazmluvnené? | enumeration / radio | companyinformation | 0 | 0 % | 3 možností |
| `aky_je_vykon_vasho_zdroja_v_kwp_` | Aký je výkon Vášho zdroja v kWp? | string / text | companyinformation | 17 | 0,6 % |  |
| `claude_audit` | Claude audit | enumeration / select | companyinformation | 1 645 | 54,8 % | 2 možností |
| `historickyobchodnik` | HistorickyObchodnik | string / text | companyinformation | 0 | 0 % |  |
| `ico_form_viwa` | IČO_form VIWA | string / text | companyinformation | 0 | 0 % | jedinečná |
| `ico_new` | IČO_NEW | number / number | companyinformation | 2 282 | 76 % | jedinečná |
| `kampan` | Kampaň | enumeration / checkbox | companyinformation | 429 | 14,3 % | 2 možností |
| `platca_dph` | Plátca DPH | enumeration / select | companyinformation | 2 | 0,1 % | 2 možností |
| `pomocne_pole_1` | Pomocne pole 1 | string / text | companyinformation | 382 | 12,7 % |  |
| `predmet_cinnosti` | Predmet činnosti | string / text | companyinformation | 2 | 0,1 % |  |
| `rocny_plan_spotreby_mwh` | Ročný plán spotreby_MWh | number / number | companyinformation | 1 595 | 53,1 % |  |
| `segment_zakaznika` | Segment zákazníka | enumeration / checkbox | companyinformation | 1 862 | 62 % | 4 možností |
| `sidlo` | Sídlo | string / text | companyinformation | 2 | 0,1 % |  |
| `skutocna_rocna_spotreba_celkom_mwh` | Skutočná ročná spotreba celkom_MWh | number / number | companyinformation | 1 582 | 52,7 % |  |
| `skutocna_rocna_spotreba_nt_mwh` | Skutočná ročná spotreba NT_MWh | number / number | companyinformation | 1 582 | 52,7 % |  |
| `skutocna_rocna_spotreba_vt_mwh` | Skutočná ročná spotreba VT_MWh | number / number | companyinformation | 863 | 28,7 % |  |
| `subjekt` | Subjekt | string / text | companyinformation | 2 285 | 76,1 % |  |
| `zisk` | Zisk | number / number | companyinformation | 2 | 0,1 % |  |
| `ake_sluzby_mate_zazmluvnene_v_greenlogy_` | Aké služby máte zazmluvnené v Greenlogy? | enumeration / radio | eviden_n___daje | 20 | 0,7 % | 3 možností |
| `bank_account` | Bank account | string / textarea | eviden_n___daje | 107 | 3,6 % |  |
| `dic` | DIČ | string / text | eviden_n___daje | 2 263 | 75,4 % |  |
| `i_dph` | IČ DPH | string / text | eviden_n___daje | 2 070 | 68,9 % |  |
| `platobn_rating` | Platobný rating | enumeration / select | eviden_n___daje | 14 | 0,5 % | 6 možností |
| `z_pis_v_or` | Zapísaný v Obchodnom registri | string / textarea | eviden_n___daje | 2 181 | 72,6 % |  |
| `zast_pen_` | Zastúpený | string / textarea | eviden_n___daje | 990 | 33 % |  |
| `dlhy_a_nedoplatky` | Dlhy a nedoplatky | string / text | finstat_d_ta | 2 270 | 75,6 % |  |
| `finstat_datum_aktualizacie` | Finstat_dátum aktualizácie | date / date | finstat_d_ta | 0 | 0 % |  |
| `finstat_url` | Finstat URL | string / text | finstat_d_ta | 2 267 | 75,5 % |  |
| `konkurzy_a_re_trukturaliz_cie` | Konkurzy a reštrukturalizácie | string / text | finstat_d_ta | 330 | 11 % |  |
| `lastupdatedbyintegromat` | lastupdatedbyintegromat | date / date | finstat_d_ta | 868 | 28,9 % |  |
| `poh_ad_vky_t_tu` | Pohľadávky štátu | string / text | finstat_d_ta | 2 | 0,1 % |  |
| `sk_nace_group` | sk_nace_group | string / text | finstat_d_ta | 2 162 | 72 % |  |
| `grn_charging_stations_b2b_engine` | GRN Charging Stations B2B Engine | enumeration / checkbox | greenlogy_engines | 41 | 1,4 % | 5 možností |
| `grn_energia_b2b_engine` | GRN Energia B2B Engine | enumeration / checkbox | greenlogy_engines | 1 472 | 49 % | 19 možností |
| `grn_fotovoltika_b2b_engine` | GRN Fotovoltika B2B Engine | enumeration / checkbox | greenlogy_engines | 58 | 1,9 % | 5 možností |
| `grn_marketing_partners_engine` | GRN Marketing Partners Engine | enumeration / checkbox | greenlogy_engines | 0 | 0 % | 5 možností |
| `grn_producenti_b2b_engine` | GRN Producenti B2B Engine | enumeration / checkbox | greenlogy_engines | 174 | 5,8 % | 14 možností |
| `orgcharthub_has_org_chart` | Has Org Chart | enumeration / booleancheckbox | orgcharthub | 0 | 0 % | 2 možností |
| `orgcharthub_num_contacts_on_chart` | Number of Contacts on Org Chart | number / number | orgcharthub | 0 | 0 % |  |
| `orgcharthub_num_hubspot_contacts_on_chart` | Number of HubSpot Contacts on Org Chart | number / number | orgcharthub | 0 | 0 % |  |
| `orgcharthub_num_placeholder_contacts_on_chart` | Number of Placeholder Contacts on Org Chart | number / number | orgcharthub | 0 | 0 % |  |
| `orgcharthub_org_chart_last_updated_at` | Org Chart Last Updated At | date / date | orgcharthub | 0 | 0 % |  |
| `bateriove_ulozisko` | Batériové úložisko | enumeration / select | spotrebiteľské_informácie | 0 | 0 % | 2 možností |
| `pocet_elektroaut` | Počet elektroáut | number / number | spotrebiteľské_informácie | 132 | 4,4 % |  |
| `vasa_rocna_spotreba_` | Vaša ročná spotreba? | string / text | spotrebiteľské_informácie | 16 | 0,5 % |  |
| `vykon_bess_v_kwh` | Výkon BESS v kWh | number / number | spotrebiteľské_informácie | 0 | 0 % |  |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `days_to_close` | Days to Close | number / calculation_equation | analyticsinformation | 1 388 | 46,2 % |  |
| `hs_analytics_first_timestamp` | Time First Seen | datetime / date | analyticsinformation | 2 124 | 70,7 % |  |
| `hs_analytics_first_touch_converting_campaign` | First Touch Converting Campaign | string / text | analyticsinformation | 41 | 1,4 % |  |
| `hs_analytics_first_visit_timestamp` | Time of First Session | datetime / date | analyticsinformation | 845 | 28,1 % |  |
| `hs_analytics_last_timestamp` | Time Last Seen | datetime / date | analyticsinformation | 845 | 28,1 % |  |
| `hs_analytics_last_touch_converting_campaign` | Last Touch Converting Campaign | string / text | analyticsinformation | 336 | 11,2 % |  |
| `hs_analytics_last_visit_timestamp` | Time of Last Session | datetime / date | analyticsinformation | 850 | 28,3 % |  |
| `hs_analytics_num_page_views` | Number of Pageviews | number / number | analyticsinformation | 2 124 | 70,7 % |  |
| `hs_analytics_num_visits` | Number of Sessions | number / number | analyticsinformation | 2 124 | 70,7 % |  |
| `hs_analytics_source` | Original Source Type | enumeration / select | analyticsinformation | 2 413 | 80,4 % | 10 možností |
| `hs_analytics_source_data_1` | Original Source Data 1 | string / text | analyticsinformation | 2 403 | 80 % |  |
| `hs_analytics_source_data_2` | Original Source Data 2 | string / text | analyticsinformation | 2 146 | 71,5 % |  |
| `hs_customer_success_ticket_sentiment` | Recent Ticket Sentiment | number / number | company_activity | 1 003 | 33,4 % |  |
| `hs_last_logged_outgoing_email_date` | Last Logged Outgoing Email Date | datetime / calculation_rollup | company_activity | 2 293 | 76,4 % |  |
| `hs_last_sales_activity_type` | Last Engagement Type | enumeration / select | company_activity | 1 542 | 51,3 % | 8 možností |
| `hs_lastmodifieddate` | Last Modified Date | datetime / date | company_activity | 3 003 | 100 % |  |
| `hs_count_intent_signals_created_last_14_days` | Count of intent signals created in last 14 days | number / number | company_signals | 3 | 0,1 % |  |
| `hs_count_intent_signals_created_last_30_days` | Count of intent signals created in last 30 days | number / number | company_signals | 3 | 0,1 % |  |
| `hs_count_intent_signals_created_last_7_days` | Count of intent signals created in last 7 days | number / number | company_signals | 3 | 0,1 % |  |
| `hs_intent_page_views_last_30_days` | Tracked Page Views (Last 30 Days) | number / number | company_signals | 3 | 0,1 % |  |
| `hs_intent_paid_up_to_date` | Intent paid up to date | date / date | company_signals | 3 | 0,1 % |  |
| `hs_intent_signals_enabled` | Intent Signals active | bool / booleancheckbox | company_signals | 3 | 0,1 % | 2 možností |
| `hs_intent_visitors_last_30_days` | Tracked Visitors (Last 30 Days) | number / number | company_signals | 3 | 0,1 % |  |
| `hs_latest_intent_signal_occurred_at` | Latest Intent Signal Occurred At | datetime / date | company_signals | 2 | 0,1 % |  |
| `hs_latest_intent_signal_timestamp` | Latest intent signal timestamp | number / number | company_signals | 3 | 0,1 % |  |
| `hs_most_recent_de_anonymized_visit` | Last Tracked Visit Time | datetime / date | company_signals | 3 | 0,1 % |  |
| `about_us` | About Us | string / text | companyinformation | 118 | 3,9 % |  |
| `address` | Street Address | string / text | companyinformation | 2 405 | 80,1 % |  |
| `address2` | Street Address 2 | string / text | companyinformation | 6 | 0,2 % |  |
| `annualrevenue` | Annual Revenue | number / number | companyinformation | 351 | 11,7 % |  |
| `city` | City | string / text | companyinformation | 2 398 | 79,9 % |  |
| `closedate` | Close Date | datetime / date | companyinformation | 1 388 | 46,2 % |  |
| `country` | Country/Region | string / text | companyinformation | 2 610 | 86,9 % |  |
| `createdate` | Create Date | datetime / date | companyinformation | 3 003 | 100 % |  |
| `description` | Description | string / textarea | companyinformation | 547 | 18,2 % |  |
| `domain` | Company Domain Name | string / text | companyinformation | 1 815 | 60,4 % |  |
| `engagements_last_meeting_booked` | Date of last meeting booked in meetings tool | datetime / date | companyinformation | 4 | 0,1 % |  |
| `first_contact_createdate` | First Contact Create Date | datetime / date | companyinformation | 2 124 | 70,7 % |  |
| `first_deal_created_date` | First Deal Created Date | datetime / date | companyinformation | 1 889 | 62,9 % |  |
| `founded_year` | Year Founded | string / text | companyinformation | 2 520 | 83,9 % |  |
| `hs_additional_domains` | Additional Domains | enumeration / checkbox | companyinformation | 19 | 0,6 % |  |
| `hs_all_accessible_team_ids` | All teams | enumeration / select | companyinformation | 2 657 | 88,5 % |  |
| `hs_all_assigned_business_unit_ids` | Brands | enumeration / checkbox | companyinformation | 818 | 27,2 % |  |
| `hs_all_owner_ids` | All owner IDs | enumeration / select | companyinformation | 2 828 | 94,2 % |  |
| `hs_all_team_ids` | All team IDs | enumeration / select | companyinformation | 2 657 | 88,5 % |  |
| `hs_analytics_latest_source` | Latest Traffic Source | enumeration / select | companyinformation | 2 413 | 80,4 % | 10 možností |
| `hs_analytics_latest_source_data_1` | Latest Traffic Source Data 1 | string / text | companyinformation | 2 413 | 80,4 % |  |
| `hs_analytics_latest_source_data_2` | Latest Traffic Source Data 2 | string / text | companyinformation | 2 041 | 68 % |  |
| `hs_analytics_latest_source_timestamp` | Latest Traffic Source Timestamp | datetime / date | companyinformation | 2 413 | 80,4 % |  |
| `hs_annual_revenue_currency_code` | Annual Revenue Currency Code | string / calculation_equation | companyinformation | 1 762 | 58,7 % |  |
| `hs_calculated_phone_number` | Calculated Phone Number in International Format | string / phonenumber | companyinformation | 694 | 23,1 % | výpočet |
| `hs_country_code` | Country/Region Code | string / text | companyinformation | 366 | 12,2 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | companyinformation | 1 493 | 49,7 % |  |
| `hs_createdate` | Object create date/time | datetime / date | companyinformation | 3 003 | 100 % |  |
| `hs_current_customer` | Current Customer | enumeration / select | companyinformation | 3 003 | 100 % | 2 možností |
| `hs_domain_status` | Domain status | enumeration / select | companyinformation | 270 | 9 % | 3 možností |
| `hs_employee_range` | Employee range | string / text | companyinformation | 289 | 9,6 % |  |
| `hs_geohash_1` | geohash_1 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_geohash_2` | geohash_2 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_geohash_3` | geohash_3 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_geohash_4` | geohash_4 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_geohash_5` | geohash_5 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_geohash_6` | geohash_6 | string / text | companyinformation | 445 | 14,8 % |  |
| `hs_gps_error` | GPS Error | string / text | companyinformation | 10 | 0,3 % |  |
| `hs_industry_group` | Industry group | string / text | companyinformation | 361 | 12 % |  |
| `hs_is_enriched` | Has been enriched | bool / booleancheckbox | companyinformation | 650 | 21,6 % | 2 možností |
| `hs_keywords` | Company Keywords | enumeration / checkbox | companyinformation | 356 | 11,9 % | 1583 možností |
| `hs_last_booked_meeting_date` | Last Booked Meeting Date | datetime / date | companyinformation | 33 | 1,1 % |  |
| `hs_last_logged_call_date` | Last Logged Call Date | datetime / date | companyinformation | 674 | 22,4 % |  |
| `hs_last_metered_enrichment_timestamp` | Last Metered Enrichment Timestamp | datetime / date | companyinformation | 3 | 0,1 % |  |
| `hs_last_open_task_date` | Last Open Task Date | datetime / date | companyinformation | 64 | 2,1 % |  |
| `hs_last_sales_activity_date` | last sales activity date old | datetime / date | companyinformation | 1 891 | 63 % |  |
| `hs_last_sales_activity_timestamp` | Last Engagement Date | datetime / date | companyinformation | 1 585 | 52,8 % |  |
| `hs_latest_meeting_activity` | Latest meeting activity | datetime / date | companyinformation | 33 | 1,1 % |  |
| `hs_latitude` | Latitude | number / number | companyinformation | 2 602 | 86,6 % |  |
| `hs_lead_status` | Lead Status | enumeration / radio | companyinformation | 180 | 6 % | 4 možností |
| `hs_linkedin_handle` | Linkedin handle | string / text | companyinformation | 140 | 4,7 % |  |
| `hs_logo_url` | Logo URL | string / text | companyinformation | 918 | 30,6 % |  |
| `hs_longitude` | Longitude | number / number | companyinformation | 2 602 | 86,6 % |  |
| `hs_merged_object_ids` | Merged Company IDs | enumeration / checkbox | companyinformation | 227 | 7,6 % |  |
| `hs_notes_last_activity` | Last Activity | object_coordinates / text | companyinformation | 2 543 | 84,7 % |  |
| `hs_notes_next_activity` | Next Activity | object_coordinates / text | companyinformation | 8 | 0,3 % |  |
| `hs_notes_next_activity_type` | Next Activity Type | enumeration / select | companyinformation | 8 | 0,3 % | 13 možností |
| `hs_num_active_contracts` | Number of Active Contracts | number / calculation_rollup | companyinformation | 221 | 7,4 % |  |
| `hs_num_child_companies` | Number of child companies | number / number | companyinformation | 2 995 | 99,7 % |  |
| `hs_num_open_deals` | Number of open deals | number / number | companyinformation | 3 003 | 100 % |  |
| `hs_object_id` | Record ID | number / number | companyinformation | 3 003 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | companyinformation | 3 003 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | companyinformation | 1 398 | 46,6 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | companyinformation | 1 | 0 % |  |
| `hs_object_source_detail_3` | Record source detail 3 | string / text | companyinformation | 1 | 0 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | companyinformation | 2 999 | 99,9 % |  |
| `hs_object_source_label` | Record source | enumeration / select | companyinformation | 3 003 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | companyinformation | 1 409 | 46,9 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | companyinformation | 2 657 | 88,5 % |  |
| `hs_pinned_engagement_id` | Pinned Engagement ID | number / number | companyinformation | 5 | 0,2 % |  |
| `hs_pipeline` | Pipeline | enumeration / select | companyinformation | 2 977 | 99,1 % |  |
| `hs_predictivecontactscore_v2` | Likelihood to close | number / number | companyinformation | 703 | 23,4 % |  |
| `hs_redirect_domain` | Redirect domain | string / text | companyinformation | 18 | 0,6 % |  |
| `hs_redirect_url` | Redirect URL | string / text | companyinformation | 18 | 0,6 % |  |
| `hs_revenue_range` | Revenue range | string / text | companyinformation | 246 | 8,2 % |  |
| `hs_sales_email_last_replied` | Recent Sales Email Replied Date | datetime / date | companyinformation | 1 705 | 56,8 % |  |
| `hs_searchable_calculated_international_phone_number` | Calculated Phone Number with country code | string / phonenumber | companyinformation | 694 | 23,1 % |  |
| `hs_searchable_calculated_phone_number` | Calculated Phone Number without country code | string / phonenumber | companyinformation | 720 | 24 % | výpočet |
| `hs_state_code` | State/Region Code | string / text | companyinformation | 170 | 5,7 % |  |
| `hs_target_account_probability` | Target Account Probability | number / number | companyinformation | 2 181 | 72,6 % |  |
| `hs_task_label` | Company task label | string / calculation_equation | companyinformation | 2 995 | 99,7 % | výpočet |
| `hs_total_deal_value` | Total open deal value | number / number | companyinformation | 36 | 1,2 % |  |
| `hs_unique_creation_key` | Unique creation key | string / text | companyinformation | 55 | 1,8 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | companyinformation | 2 215 | 73,8 % |  |
| `hs_user_ids_of_all_notification_recipients` | All company notification recipients | enumeration / checkbox | companyinformation | 2 828 | 94,2 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | companyinformation | 2 828 | 94,2 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | companyinformation | 1 765 | 58,8 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | companyinformation | 2 828 | 94,2 % |  |
| `hubspot_owner_id` | Company owner | enumeration / select | companyinformation | 2 828 | 94,2 % |  |
| `hubspot_team_id` | HubSpot Team | enumeration / select | companyinformation | 2 657 | 88,5 % |  |
| `industry` | Industry | enumeration / select | companyinformation | 791 | 26,3 % | 148 možností |
| `is_public` | Is Public | bool / booleancheckbox | companyinformation | 934 | 31,1 % | 2 možností |
| `lifecyclestage` | Lifecycle Stage | enumeration / radio | companyinformation | 3 003 | 100 % | 16 možností |
| `name` | Company name | string / text | companyinformation | 3 003 | 100 % |  |
| `notes_last_contacted` | Last Contacted | datetime / date | companyinformation | 2 310 | 76,9 % |  |
| `notes_last_updated` | Last Activity Date | datetime / date | companyinformation | 2 543 | 84,7 % |  |
| `notes_next_activity_date` | Next Activity Date | datetime / date | companyinformation | 8 | 0,3 % |  |
| `num_associated_contacts` | Number of Associated Contacts | number / calculation_rollup | companyinformation | 3 002 | 100 % |  |
| `num_associated_deals` | Number of Associated Deals | number / calculation_rollup | companyinformation | 1 889 | 62,9 % |  |
| `num_contacted_notes` | Number of times contacted | number / number | companyinformation | 2 487 | 82,8 % |  |
| `num_notes` | Number of Sales Activities | number / number | companyinformation | 2 845 | 94,7 % |  |
| `numberofemployees` | Number of Employees | number / number | companyinformation | 540 | 18 % |  |
| `phone` | Phone Number | string / phonenumber | companyinformation | 720 | 24 % |  |
| `recent_deal_amount` | Recent Deal Amount | number / number | companyinformation | 1 137 | 37,9 % |  |
| `recent_deal_close_date` | Recent Deal Close Date | datetime / date | companyinformation | 1 174 | 39,1 % |  |
| `state` | State/Region | string / text | companyinformation | 429 | 14,3 % |  |
| `timezone` | Time Zone | string / text | companyinformation | 561 | 18,7 % |  |
| `total_money_raised` | Total Money Raised | string / text | companyinformation | 38 | 1,3 % |  |
| `total_revenue` | Total Revenue | number / calculation_rollup | companyinformation | 1 154 | 38,4 % |  |
| `web_technologies` | Web Technologies | enumeration / checkbox | companyinformation | 877 | 29,2 % | 712 možností |
| `website` | Website URL | string / text | companyinformation | 1 823 | 60,7 % |  |
| `zip` | Postal Code | string / text | companyinformation | 2 412 | 80,3 % |  |
| `hs_v2_cumulative_time_in_1178563195` | Cumulative time in "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 | 0,1 % |  |
| `hs_v2_cumulative_time_in_132044134` | Cumulative time in "Vymazať (Lifecycle Stage Pipeline)" | number / number | companylcs | 523 | 17,4 % |  |
| `hs_v2_cumulative_time_in_53965359` | Cumulative time in "Čakajúci zákazník (Lifecycle Stage Pipeline)" | number / number | companylcs | 217 | 7,2 % |  |
| `hs_v2_cumulative_time_in_54180979` | Cumulative time in "Odídený zákazník (Lifecycle Stage Pipeline)" | number / number | companylcs | 39 | 1,3 % |  |
| `hs_v2_cumulative_time_in_77667470` | Cumulative time in "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | number / number | companylcs | 37 | 1,2 % |  |
| `hs_v2_cumulative_time_in_customer` | Cumulative time in "Customer (Lifecycle Stage Pipeline)" | number / number | companylcs | 415 | 13,8 % |  |
| `hs_v2_cumulative_time_in_evangelist` | Cumulative time in "Spolupracovníci (Lifecycle Stage Pipeline)" | number / number | companylcs | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_lead` | Cumulative time in "Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 018 | 67,2 % |  |
| `hs_v2_cumulative_time_in_marketingqualifiedlead` | Cumulative time in "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 17 | 0,6 % |  |
| `hs_v2_cumulative_time_in_opportunity` | Cumulative time in "Opportunity (Lifecycle Stage Pipeline)" | number / number | companylcs | 1 007 | 33,5 % |  |
| `hs_v2_cumulative_time_in_other` | Cumulative time in "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 | 0,1 % |  |
| `hs_v2_cumulative_time_in_salesqualifiedlead` | Cumulative time in "Sales Qualified Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 778 | 25,9 % |  |
| `hs_v2_cumulative_time_in_subscriber` | Cumulative time in "Subscriber (Lifecycle Stage Pipeline)" | number / number | companylcs | 17 | 0,6 % |  |
| `hs_v2_date_entered_1178563195` | Date entered "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 10 | 0,3 % |  |
| `hs_v2_date_entered_132044134` | Date entered "Vymazať (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 550 | 18,3 % |  |
| `hs_v2_date_entered_53965359` | Date entered "Čakajúci zákazník (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 294 | 9,8 % |  |
| `hs_v2_date_entered_54180979` | Date entered "Odídený zákazník (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 88 | 2,9 % |  |
| `hs_v2_date_entered_77667470` | Date entered "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 481 | 16 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | companylcs | 3 003 | 100 % | výpočet |
| `hs_v2_date_entered_customer` | Date entered "Customer (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 1 388 | 46,2 % |  |
| `hs_v2_date_entered_evangelist` | Date entered "Spolupracovníci (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 | 0,1 % |  |
| `hs_v2_date_entered_lead` | Date entered "Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 615 | 87,1 % |  |
| `hs_v2_date_entered_marketingqualifiedlead` | Date entered "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 29 | 1 % |  |
| `hs_v2_date_entered_opportunity` | Date entered "Opportunity (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 1 206 | 40,2 % |  |
| `hs_v2_date_entered_other` | Date entered "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 | 0,1 % |  |
| `hs_v2_date_entered_salesqualifiedlead` | Date entered "Sales Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 1 068 | 35,6 % |  |
| `hs_v2_date_entered_subscriber` | Date entered "Subscriber (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 17 | 0,6 % |  |
| `hs_v2_date_exited_1178563195` | Date exited "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 | 0,1 % |  |
| `hs_v2_date_exited_132044134` | Date exited "Vymazať (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 523 | 17,4 % |  |
| `hs_v2_date_exited_53965359` | Date exited "Čakajúci zákazník (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 217 | 7,2 % |  |
| `hs_v2_date_exited_54180979` | Date exited "Odídený zákazník (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 39 | 1,3 % |  |
| `hs_v2_date_exited_77667470` | Date exited "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 37 | 1,2 % |  |
| `hs_v2_date_exited_customer` | Date exited "Customer (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 415 | 13,8 % |  |
| `hs_v2_date_exited_evangelist` | Date exited "Spolupracovníci (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 1 | 0 % |  |
| `hs_v2_date_exited_lead` | Date exited "Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 018 | 67,2 % |  |
| `hs_v2_date_exited_marketingqualifiedlead` | Date exited "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 17 | 0,6 % |  |
| `hs_v2_date_exited_opportunity` | Date exited "Opportunity (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 1 007 | 33,5 % |  |
| `hs_v2_date_exited_other` | Date exited "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 2 | 0,1 % |  |
| `hs_v2_date_exited_salesqualifiedlead` | Date exited "Sales Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 778 | 25,9 % |  |
| `hs_v2_date_exited_subscriber` | Date exited "Subscriber (Lifecycle Stage Pipeline)" | datetime / date | companylcs | 17 | 0,6 % |  |
| `hs_v2_latest_time_in_1178563195` | Latest time in "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 | 0,1 % |  |
| `hs_v2_latest_time_in_132044134` | Latest time in "Vymazať (Lifecycle Stage Pipeline)" | number / number | companylcs | 523 | 17,4 % |  |
| `hs_v2_latest_time_in_53965359` | Latest time in "Čakajúci zákazník (Lifecycle Stage Pipeline)" | number / number | companylcs | 217 | 7,2 % |  |
| `hs_v2_latest_time_in_54180979` | Latest time in "Odídený zákazník (Lifecycle Stage Pipeline)" | number / number | companylcs | 39 | 1,3 % |  |
| `hs_v2_latest_time_in_77667470` | Latest time in "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | number / number | companylcs | 37 | 1,2 % |  |
| `hs_v2_latest_time_in_customer` | Latest time in "Customer (Lifecycle Stage Pipeline)" | number / number | companylcs | 415 | 13,8 % |  |
| `hs_v2_latest_time_in_evangelist` | Latest time in "Spolupracovníci (Lifecycle Stage Pipeline)" | number / number | companylcs | 1 | 0 % |  |
| `hs_v2_latest_time_in_lead` | Latest time in "Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 018 | 67,2 % |  |
| `hs_v2_latest_time_in_marketingqualifiedlead` | Latest time in "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 17 | 0,6 % |  |
| `hs_v2_latest_time_in_opportunity` | Latest time in "Opportunity (Lifecycle Stage Pipeline)" | number / number | companylcs | 1 007 | 33,5 % |  |
| `hs_v2_latest_time_in_other` | Latest time in "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | number / number | companylcs | 2 | 0,1 % |  |
| `hs_v2_latest_time_in_salesqualifiedlead` | Latest time in "Sales Qualified Lead (Lifecycle Stage Pipeline)" | number / number | companylcs | 778 | 25,9 % |  |
| `hs_v2_latest_time_in_subscriber` | Latest time in "Subscriber (Lifecycle Stage Pipeline)" | number / number | companylcs | 17 | 0,6 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | companylcs | 3 003 | 100 % | výpočet |
| `first_conversion_date` | First Conversion Date | datetime / date | conversioninformation | 631 | 21 % |  |
| `first_conversion_event_name` | First Conversion | string / text | conversioninformation | 631 | 21 % |  |
| `num_conversion_events` | Number of Form Submissions | number / number | conversioninformation | 2 069 | 68,9 % |  |
| `recent_conversion_date` | Recent Conversion Date | datetime / date | conversioninformation | 631 | 21 % |  |
| `recent_conversion_event_name` | Recent Conversion | string / text | conversioninformation | 631 | 21 % |  |
| `facebook_company_page` | Facebook Company Page | string / text | socialmediainformation | 265 | 8,8 % |  |
| `linkedin_company_page` | LinkedIn Company Page | string / text | socialmediainformation | 370 | 12,3 % |  |
| `linkedinbio` | LinkedIn Bio | string / text | socialmediainformation | 500 | 16,7 % |  |
| `twitterhandle` | Twitter Handle | string / text | socialmediainformation | 121 | 4 % |  |
| `hs_is_target_account` | Target Account | bool / booleancheckbox | targetaccountsinformation | 5 | 0,2 % | 2 možností |
| `hs_num_blockers` | Number of blockers | number / number | targetaccountsinformation | 3 003 | 100 % |  |
| `hs_num_contacts_with_buying_roles` | Number of contacts with a buying role | number / number | targetaccountsinformation | 3 003 | 100 % |  |
| `hs_num_decision_makers` | Number of decision makers | number / number | targetaccountsinformation | 3 003 | 100 % |  |

#### HubSpot vlastnosti bez dát (71)

`hs_analytics_last_timestamp_timestamp_latest_value_4e16365a`, `hs_analytics_last_touch_converting_campaign_timestamp_latest_value_81a64e30`, `hs_analytics_last_visit_timestamp_timestamp_latest_value_999a0fce`, `hs_analytics_num_page_views_cardinality_sum_e46e85b0`, `hs_analytics_num_visits_cardinality_sum_53d952a6`, `hs_inferred_domain`, `hs_is_intent_monitored`, `hs_paid_for_intent_signals`, `hs_recent_intent_signals`, `hs_signals_summary`, `engagements_last_meeting_booked_campaign`, `engagements_last_meeting_booked_medium`, `engagements_last_meeting_booked_source`, `first_contact_createdate_timestamp_earliest_value_78b50eea`, `hs_active_contracts_arr`, `hs_active_contracts_mrr`, `hs_active_contracts_tcv`, `hs_avatar_filemanager_key`, `hs_csm_sentiment`, `hs_gps_latitude`, `hs_gps_longitude`, `hs_latest_createdate_of_active_subscriptions`, `hs_live_enrichment_deadline`, `hs_next_renewal_date`, `hs_parent_company_id`, `hs_predictivecontactscore_v2_next_max_max_d4e58c1e`, `hs_quick_context`, `hs_read_only`, `hs_research_agent_execution_id`, `hs_research_agent_id`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_source_object_id`, `hs_target_account`, `hs_target_account_recommendation_snooze_time`, `hs_target_account_recommendation_state`, `hs_tax_id`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `hubspotscore`, `owneremail`, `ownername`, `type`, `hs_v2_cumulative_time_in_1046796415`, `hs_v2_cumulative_time_in_1068476447`, `hs_v2_cumulative_time_in_1371734699`, `hs_v2_date_entered_1046796415`, `hs_v2_date_entered_1068476447`, `hs_v2_date_entered_1371734699`, `hs_v2_date_exited_1046796415`, `hs_v2_date_exited_1068476447`, `hs_v2_date_exited_1371734699`, `hs_v2_latest_time_in_1046796415`, `hs_v2_latest_time_in_1068476447`, `hs_v2_latest_time_in_1371734699`, `num_conversion_events_cardinality_sum_d095f14b`, `recent_conversion_date_timestamp_latest_value_72856da1`, `recent_conversion_event_name_timestamp_latest_value_66c820bf`, `hs_excluded_from_cross_account_data_mirroring`, `hs_latest_prospecting_agent_monitoring_date`, `hs_latest_suggested_contact_date`, `hs_latest_suggested_contact_timestamp`, `hs_max_recommendation_score`, `hs_plays`, `hs_reason_to_reach_out`, `hs_suggested_contact_count`, `facebookfans`, `googleplus_page`, `twitterbio`, `twitterfollowers`, `hs_ideal_customer_profile`

#### Možnosti výberových polí

- **`ake_sluzby_mate_u_nas_zazmluvnene_`** (Aké služby máte u nás zazmluvnené?): `Výkup elektriny` = Výkup elektriny; `Dodávku elektriny` = Dodávku elektriny; `Výkup aj dodávku elektriny` = Výkup aj dodávku elektriny
- **`claude_audit`** (Claude audit): `Áno` = Áno; `Nie` = Nie
- **`kampan`** (Kampaň): `NEP` = NEP; `Green VIWA` = Green VIWA
- **`platca_dph`** (Plátca DPH): `Platca DPH` = Platca DPH; `Neplatca DPH` = Neplatca DPH
- **`segment_zakaznika`** (Segment zákazníka): `Domácnosť` = Domácnosť; `Komunal` = Komunal; `Firma` = Firma; `Dodávateľ` = Dodávateľ
- **`ake_sluzby_mate_zazmluvnene_v_greenlogy_`** (Aké služby máte zazmluvnené v Greenlogy?): `Dodávku elektriny` = Dodávku elektriny; `Výkup` = Výkup; `Dodávku aj výkup elektriny` = Dodávku aj výkup elektriny
- **`platobn_rating`** (Platobný rating): `A - bez meškania` = A - veľmi dobrá; `B - občasné meškanie` = B - občasné omeškanie; `C - opakované meškania` = C - pravidelné omeškanie; `D - BLACK LIST` = D - neplatič; `E - ARCA CAPITAL` = E - skupinoví odberatelia; `X - bez histórie` = X - bez histórie
- **`grn_charging_stations_b2b_engine`** (GRN Charging Stations B2B Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Charging Stations; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Sales Process (KAM)` = Accept Offer; `Contract Creation` = Installation and Technical Support
- **`grn_energia_b2b_engine`** (GRN Energia B2B Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Energia pre Firmy; `Blog Subscribe` = Blog Subscribe; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Contract Creation` = Contract Creation; `Contract Signed` = Contract Signed; `Proces Zmeny (Success / Fail)` = Proces Zmeny (Success / Fail); `Welcome / Portal Onboarding` = Welcome / Portal Onboarding; `Zelena Elektrina Customer` = Zelena Elektrina Customer; `Elektromobilita Kupon` = Elektromobilita Kupon; `Virtualna Bateria Customer` = Virtualna Bateria Customer; `Testimonial / Case Study` = Testimonial / Case Study; `NPS Detractor` = NPS Detractor; `NPS Neutral` = NPS Neutral; `NPS Survey` = NPS Promoter; `Employee Bonus` = Employee Bonus; `Badge` = Badge; `Referral Activation` = Referral Activation; `Active Referrals` = Active Referrals
- **`grn_fotovoltika_b2b_engine`** (GRN Fotovoltika B2B Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Fotovoltika pre Firmy; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Sales Process (KAM)` = Accept Offer; `Contract Creation` = Installation and Technical Support
- **`grn_marketing_partners_engine`** (GRN Marketing Partners Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Partner Page; `Blog Subscribe` = Book Partner Demo; `Apply to Partner Program` = Apply to Partner Program; `Partner Onboarding` = Partner Onboarding; `Active Partners` = Active Partners
- **`grn_producenti_b2b_engine`** (GRN Producenti B2B Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Vykup; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Contract Creation` = Contract Creation; `Contract Signed` = Contract Signed; `Proces Zmeny (Success / Fail)` = Proces Zmeny (Success / Fail); `Welcome / Portal Onboarding` = Aktivacia / Portal Onboarding; `Aktivny Producent` = Aktivny Producent; `Testimonial / Case Study` = Testimonial / Case Study; `NPS Detractor` = NPS Detractor; `NPS Neutral` = NPS Neutral; `NPS Survey` = NPS Promoter; `Referral Activation` = Referral Activation; `Active Referrals` = Active Referrals
- **`orgcharthub_has_org_chart`** (Has Org Chart): `true` = Yes; `false` = No
- **`bateriove_ulozisko`** (Batériové úložisko): `ÁNO` = ÁNO; `NIE` = NIE
- **`hs_analytics_source`** (Original Source Type): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_last_sales_activity_type`** (Last Engagement Type): `COMPANYPROSPECTS_REVISIT` = Company Website Visit; `PRESENTATION_REVISIT` = Document View; `EMAIL_CLICK` = Email Click; `EMAIL_OPEN` = Email Open; `EMAIL_REPLY` = Email Reply; `FORM_SUBMITTED` = Form Submitted; `MEETING_BOOKED` = Meeting Booked; `HUBSPOT_REVISIT` = Website Visit
- **`hs_intent_signals_enabled`** (Intent Signals active): `true` = Yes; `false` = No
- **`hs_analytics_latest_source`** (Latest Traffic Source): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_current_customer`** (Current Customer): `yes` = Yes; `no` = No
- **`hs_domain_status`** (Domain status): `ACTIVE` = Active; `INACTIVE` = Inactive; `REDIRECT` = Redirect
- **`hs_is_enriched`** (Has been enriched): `true` = Yes; `false` = No
- **`hs_keywords`** (Company Keywords): `net_development` = .NET Development; `3d_printing` = 3D Printing; `abrasives` = Abrasives; `academic_programs` = Academic Programs; `academic_research` = Academic Research; `academics` = Academics; `access_management` = Access Management; `accident_claims` = Accident Claims; `accountability` = Accountability; `accounting` = Accounting; `acoustics` = Acoustics; `addiction_treatment` = Addiction Treatment; `adhesive` = Adhesive; `adhesives` = Adhesives; `administrative_consulting` = Administrative Consulting; `administrative_support` = Administrative Support; `adtech` = AdTech; `adult_clothing` = Adult Clothing; `adult_entertainment` = Adult Entertainment; `advanced_analytics` = Advanced Analytics; `advanced_manufacturing` = Advanced Manufacturing; `adventure_activities` = Adventure Activities; `advertising` = Advertising; `advertising_marketing` = Advertising & Marketing; `advertising_campaigns` = Advertising Campaigns; `advertising_management` = Advertising Management; `advice_and_advisory_services` = Advice and Advisory Services; `advisory_commissions` = Advisory Commissions; `advocacy` = Advocacy; `advocacy_group` = Advocacy Group; `aerospace_defense` = Aerospace & Defense; `aerospace_manufacturing` = Aerospace Manufacturing; `aesthetic_medicine` = Aesthetic Medicine; `affordable_healthcare_services` = Affordable Healthcare Services; `after_sales_service` = After Sales Service; `after_school_programs` = After School Programs; `agency` = Agency; `agile_development` = Agile Development; `agribusiness` = Agribusiness; `agricultural_equipment` = Agricultural Equipment; `agricultural_production` = Agricultural Production; `agriculture` = Agriculture; `air_bags` = Air Bags; `air_force` = Air Force; `air_quality_and_filtration` = Air Quality and Filtration; `airconditioning` = Air-Conditioning; `aircraft` = Aircraft; `airlines` = Airlines; `airport_services` = Airport Services; `alarm` = Alarm … a ďalších 1533
- **`hs_lead_status`** (Lead Status): `NEW` = Nový; `OPEN_DEAL` = Otvorený deal; `IN_PROGRESS` = V riešení; `UNQUALIFIED` = Irelevantný
- **`hs_notes_next_activity_type`** (Next Activity Type): `CALL` = Call; `CONVERSATION_SESSION` = Conversation session; `INCOMING_EMAIL` = Email reply from contact; `EMAIL` = Email sent to contact; `FORWARDED_EMAIL` = Forwarded email; `LINKEDIN_MESSAGE` = LinkedIn message; `MEETING` = Meeting; `NOTE` = Note; `POSTAL_MAIL` = Postal mail; `PUBLISHING_TASK` = Publishing task; `SMS` = SMS; `TASK` = Task; `WHATS_APP` = WhatsApp
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False
- **`industry`** (Industry): `ACCOUNTING` = Accounting; `AIRLINES_AVIATION` = Airlines/Aviation; `ALTERNATIVE_DISPUTE_RESOLUTION` = Alternative Dispute Resolution; `ALTERNATIVE_MEDICINE` = Alternative Medicine; `ANIMATION` = Animation; `APPAREL_FASHION` = Apparel & Fashion; `ARCHITECTURE_PLANNING` = Architecture & Planning; `ARTS_AND_CRAFTS` = Arts and Crafts; `AUTOMOTIVE` = Automotive; `AVIATION_AEROSPACE` = Aviation & Aerospace; `BANKING` = Banking; `BIOTECHNOLOGY` = Biotechnology; `BROADCAST_MEDIA` = Broadcast Media; `BUILDING_MATERIALS` = Building Materials; `BUSINESS_SUPPLIES_AND_EQUIPMENT` = Business Supplies and Equipment; `CAPITAL_MARKETS` = Capital Markets; `CHEMICALS` = Chemicals; `CIVIC_SOCIAL_ORGANIZATION` = Civic & Social Organization; `CIVIL_ENGINEERING` = Civil Engineering; `COMMERCIAL_REAL_ESTATE` = Commercial Real Estate; `COMPUTER_NETWORK_SECURITY` = Computer & Network Security; `COMPUTER_GAMES` = Computer Games; `COMPUTER_HARDWARE` = Computer Hardware; `COMPUTER_NETWORKING` = Computer Networking; `COMPUTER_SOFTWARE` = Computer Software; `INTERNET` = Internet; `CONSTRUCTION` = Construction; `CONSUMER_ELECTRONICS` = Consumer Electronics; `CONSUMER_GOODS` = Consumer Goods; `CONSUMER_SERVICES` = Consumer Services; `COSMETICS` = Cosmetics; `DAIRY` = Dairy; `DEFENSE_SPACE` = Defense & Space; `DESIGN` = Design; `EDUCATION_MANAGEMENT` = Education Management; `E_LEARNING` = E-Learning; `ELECTRICAL_ELECTRONIC_MANUFACTURING` = Electrical/Electronic Manufacturing; `ENTERTAINMENT` = Entertainment; `ENVIRONMENTAL_SERVICES` = Environmental Services; `EVENTS_SERVICES` = Events Services; `EXECUTIVE_OFFICE` = Executive Office; `FACILITIES_SERVICES` = Facilities Services; `FARMING` = Farming; `FINANCIAL_SERVICES` = Financial Services; `FINE_ART` = Fine Art; `FISHERY` = Fishery; `FOOD_BEVERAGES` = Food & Beverages; `FOOD_PRODUCTION` = Food Production; `FUND_RAISING` = Fund-Raising; `FURNITURE` = Furniture … a ďalších 98
- **`is_public`** (Is Public): `true` = True; `false` = False
- **`lifecyclestage`** (Lifecycle Stage): `evangelist` = Spolupracovníci; `subscriber` = Subscriber; `lead` = Lead; `marketingqualifiedlead` = Marketing Qualified Lead; `salesqualifiedlead` = Sales Qualified Lead; `opportunity` = Opportunity; `53965359` = Čakajúci zákazník; `1046796415` = Čakačka VB; `1178563195` = Lead Green ViWA firma; `1068476447` = Green Solar DOM; `other` = Ostatní_Nezaradení; `customer` = Customer; `54180979` = Odídený zákazník; `77667470` = Neúspešná príležitosť; `132044134` = Vymazať; `1371734699` = TEST Claude
- **`web_technologies`** (Web Technologies): `1_and_1_hosting` = 1&1 Hosting; `3d_cart` = 3d Cart; `acquisio` = Acquisio; `activecampaign` = Activecampaign; `add_to_any` = Add To Any; `adobe_business_catalyst` = Adobe Business Catalyst; `adobe_connect` = Adobe Connect; `adobe_dynamic_tag_management` = Adobe Dynamic Tag Management; `adroll` = AdRoll; `airbrake` = Airbrake; `akamai` = Akamai; `akamai_dns` = Akamai DNS; `alexa` = Alexa; `altocloud` = Altocloud; `amazon_associates` = Amazon Associates; `amazon_payments` = Amazon Payments; `amazon_s3` = Amazon S3; `amazon_ses` = Amazon Simple Email Service; `amcharts` = amCharts; `amplitude` = Amplitude; `android` = Android; `apache` = Apache; `app_nexus` = App Nexus; `appboy` = Appboy; `appcues` = Appcues; `appdynamics` = AppDynamics; `apteligent` = Apteligent; `asp_net` = ASP.Net; `attribution` = Attribution; `authorizenet` = Authorizenet; `autopilot` = Autopilot; `aweber` = Aweber; `aws_ec2` = Amazon Web Services; `aws_route_53` = Route 53; `bazaarvoice` = Bazaarvoice; `benchmarkemail` = Benchmarkemail; `big_cartel` = Big Cartel; `bigcommerce` = Bigcommerce; `bing_ads` = Bing Ads; `bing_advertiser` = Bing Advertiser; `bing_maps` = Bing Maps; `bloomreach` = Bloomreach; `bluehost_hosting` = Bluehost Hosting; `braintree` = Braintree; `branch` = Branch; `brightcove` = Brightcove; `bug_herd` = Bug Herd; `bugsnag` = Bugsnag; `calq` = Calq; `campaignmonitor` = Campaignmonitor … a ďalších 662
- **`hs_is_target_account`** (Target Account): `true` = True; `false` = False

### Kontakty (`contacts`)

Vlastností spolu: 556 (vlastné 117, HubSpot 439). Záznamov: 8 506.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `ako_chcete_vyuzivat_sluzbu_darovania_kreditov_` | Ako chcete využívať službu darovania kreditov? | enumeration / radio | contactinformation | 3 | 0 % | 2 možností |
| `ako_chcete_vyuzivat_sluzbu_greenshare__new` | Ako chcete využívať službu GreenShare? New | enumeration / radio | contactinformation | 139 | 1,6 % | 3 možností |
| `ako_vas_mame_kontaktovat_` | Ako Vás máme kontaktovať? | enumeration / checkbox | contactinformation | 1 253 | 14,7 % | 2 možností |
| `aku_sluzbu_virtualnej_baterie_mate_aktivovanu_` | Akú službu Virtuálnej batérie máte aktivovanú? | enumeration / select | contactinformation | 37 | 0,4 % | 5 možností |
| `chcete_pridat_dalsie_odberne_miesto_` | Chcete pridať ďalšie odberné miesto? | enumeration / radio | contactinformation | 0 | 0 % | 2 možností |
| `claude_audit` | Claude audit | enumeration / select | contactinformation | 4 791 | 56,3 % | 2 možností |
| `contact_name_association` | Contact Name (association) | string / text | contactinformation | 5 325 | 62,6 % |  |
| `e_mobility__mam_zaujem_o_blizsie_informacie_ohladom` | E-Mobility: Mám záujem o bližšie informácie ohľadom | enumeration / select | contactinformation | 9 | 0,1 % | 5 možností |
| `faza_zakaznika` | Fáza zákazníka | enumeration / select | contactinformation | 4 107 | 48,3 % | 2 možností |
| `hodnotenie_kontaktu__problemovost_` | Hodnotenie kontaktu (problémovosť) | number / calculation_rollup | contactinformation | 1 490 | 17,5 % | výpočet |
| `hubspotscore` | Greenlogy score | number / calculation_score | contactinformation | 6 790 | 79,8 % |  |
| `kampan` | Kampaň | enumeration / checkbox | contactinformation | 625 | 7,3 % | 5 možností |
| `koniec_zmluvy` | Koniec Zmluvy | string / text | contactinformation | 1 | 0 % |  |
| `kwhf` | kWhf | number / number | contactinformation | 0 | 0 % |  |
| `lead_perdoo` | Lead_Perdoo | enumeration / checkbox | contactinformation | 78 | 0,9 % | 5 možností |
| `magazin_bez_napatia_` | Magazín "Bez napätia" | enumeration / select | contactinformation | 0 | 0 % | 2 možností |
| `mam_zaujem_o_tento_program_virtualnej_baterie` | Mám záujem o tento program virtuálnej batérie | enumeration / checkbox | contactinformation | 0 | 0 % | 4 možností |
| `mam_zaujem_o_tuto_sluzbu_virtualnej_baterie` | Mám záujem o túto službu virtuálnej batérie | enumeration / select | contactinformation | 122 | 1,4 % | 5 možností |
| `mate_aktivnu_sluzbu_virtualnej_baterie_v_greenlogy__new` | Máte aktívnu službu Virtuálnej batérie v Greenlogy? New | enumeration / radio | contactinformation | 2 302 | 27,1 % | 2 možností |
| `mate_aktivovanu_sluzbu_green_viwa_pre_firmy_` | Máte aktivovanú službu Green ViWA pre firmy? | enumeration / checkbox | contactinformation | 2 | 0 % | 2 možností |
| `mate_aktivovanu_sluzbu_virtualnej_baterie_v_greenlogy_` | Máte aktivovanú službu Virtuálnej batérie v Greenlogy? | string / textarea | contactinformation | 0 | 0 % |  |
| `mate_vyuctovaciu_fakturu_zmluvu_o_pripojeni` | Máte vyúčtovaciu faktúru? Zmluvu o pripojení? | string / file | contactinformation | 72 | 0,8 % |  |
| `mobile_phone_number_2` | Mobile phone number 2 | string / text | contactinformation | 5 | 0,1 % |  |
| `nasim_zakaznikom_je_vasa_` | Naším zákazníkom je Vaša: | enumeration / select | contactinformation | 0 | 0 % | 2 možností |
| `o_aky_program_virtualnej_baterie_by_ste_mali_zaujem` | O aký program virtuálnej batérie by ste mali záujem? | enumeration / booleancheckbox | contactinformation | 0 | 0 % | 2 možností |
| `o_aky_typ_partnerstva_mate_zaujem_` | O aký typ partnerstva máte záujem? | enumeration / checkbox | contactinformation | 0 | 0 % | 3 možností |
| `parovanie_contact_deal_oom_zml_cena` | Párovanie Contact_Deal_OOM_Zml.cena | string / text | contactinformation | 2 194 | 25,8 % |  |
| `pomocne_pole_1` | Pomocné pole 1 | string / text | contactinformation | 1 945 | 22,9 % |  |
| `poznam_svoju_tarifu_a_rocnu_spotrebu_` | Poznám svoju tarifu a ročnú spotrebu? | enumeration / radio | contactinformation | 0 | 0 % | 2 možností |
| `predpokladana_rocna_spotreba_na_vasom_odbernom_mieste` | Predpokladaná ročná spotreba na vašom odbernom mieste? | number / number | contactinformation | 122 | 1,4 % |  |
| `priloz_subor` | Prilož súbor | string / file | contactinformation | 41 | 0,5 % |  |
| `pscd` | PSČd | number / number | contactinformation | 0 | 0 % |  |
| `rocna_spotreba_na_om` | Ročná spotreba na OM | number / number | contactinformation | 177 | 2,1 % |  |
| `segment` | Typ kontaktu | enumeration / checkbox | contactinformation | 8 202 | 96,4 % | 11 možností |
| `ste_zakaznikom_greenlogy__new` | Ste zákazníkom Greenlogy? New | enumeration / radio | contactinformation | 199 | 2,3 % | 2 možností |
| `subjekt` | Subjekt_firma | string / text | contactinformation | 1 271 | 14,9 % |  |
| `suhlasim_so_spracovanim_udajov_` | Súhlasím so spracovaním údajov * | enumeration / booleancheckbox | contactinformation | 51 | 0,6 % | 2 možností |
| `text` | text | string / text | contactinformation | 0 | 0 % |  |
| `titul` | Titul | string / text | contactinformation | 510 | 6 % |  |
| `typ_zmluvy` | Typ zmluvy | string / text | contactinformation | 7 | 0,1 % |  |
| `vybrat_tarifu_` | Vybrať tarifu... | enumeration / select | contactinformation | 0 | 0 % | 8 možností |
| `zdroj_kontaktu_ako_vznikol_` | Zdroj kontaktu - ako vznikol? | enumeration / checkbox | contactinformation | 1 697 | 20 % | 9 možností |
| `zivotopis` | Životopis | string / file | contactinformation | 10 | 0,1 % |  |
| `ako_chcete_vyuzivat_sluzbu_greenshare_pre_firmy_` | Ako chcete využívať službu GreenShare pre firmy? | enumeration / checkbox | conversioninformation | 0 | 0 % | 2 možností |
| `nazov_programu_vbattery` | Názov programu VBattery | string / text | frontoffice_info | 316 | 3,7 % |  |
| `uvedenie_vz_lz_do_prevadzky` | Uvedenie VZ/LZ do prevádzky | date / date | frontoffice_info | 291 | 3,4 % |  |
| `vypoved_podana` | Výpoveď podaná | enumeration / booleancheckbox | frontoffice_info | 9 | 0,1 % | 2 možností |
| `zaradeny_do_zmenoveho_k` | Zaradený do zmenového k | date / date | frontoffice_info | 1 075 | 12,6 % |  |
| `grn_charging_stations_b2c_engine` | GRN Charging Stations B2C Engine | enumeration / checkbox | greenlogy | 337 | 4 % | 5 možností |
| `grn_energia_b2c_engine` | GRN Energia B2C Engine | enumeration / checkbox | greenlogy | 4 490 | 52,8 % | 18 možností |
| `grn_fotovoltika_b2c_engine` | GRN Fotovoltika B2C Engine | enumeration / checkbox | greenlogy | 447 | 5,3 % | 5 možností |
| `gp_ano_nabijanie_elektromobilu` | Gp_ano_nabijanie_elektromobilu | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_ano_virtualna_bateria` | Gp_ano_virtualna_bateria | number / number | greenlogyponuky | 1 173 | 13,8 % |  |
| `gp_butt_url_1` | Gp_butt_url_1 | string / text | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_cena_1` | Gp_cena_1 | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_cena_1n` | Gp_cena_1n | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_cena_2` | Gp_cena_2 | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_cena_3` | Gp_cena_3 | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_cena_om_mes` | Gp_cena_om_mes | number / number | greenlogyponuky | 919 | 10,8 % |  |
| `gp_cislo_ponuky` | Gp_cislo_ponuky | string / text | greenlogyponuky | 1 420 | 16,7 % |  |
| `gp_eauto_suma` | Gp_eauto_suma | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_nazov_tarifa_pds` | Gp_nazov_tarifa_pds | string / text | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_ponukaplatnado` | Gp_PonukaPlatnaDo | date / date | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_predmet` | Gp_Predmet | string / text | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_spotreba_1t_vt` | Gp_Spotreba_1t_vt | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_spotreba_nt` | Gp_Spotreba_nt | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_spotreba_plan_celkom` | Gp_Spotreba_Plan_Celkom | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_suma` | Gp_suma | number / number | greenlogyponuky | 1 426 | 16,8 % |  |
| `gp_vbattery_nazov` | Gp_VBattery_Nazov | string / text | greenlogyponuky | 1 426 | 16,8 % |  |
| `gpanoodoslatponuku` | GpAnoOdoslatPonuku | enumeration / booleancheckbox | greenlogyponuky | 1 420 | 16,7 % | 2 možností |
| `gpdatumodoslaniaemailu` | GpDatumOdoslaniaEmailu | date / date | greenlogyponuky | 1 420 | 16,7 % |  |
| `dashboardlink_994f447a_aef7_4808_8e60_1acd0c373580` | Dashboard link - Referral Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `dashboardlink_a0c1f03e_9c3b_4ba7_b5a7_9ecb837598e7` | Dashboard link - Reseller Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `dashboardlink_a6748c29_f1ae_40a5_9026_bc3f0cc286bb` | Dashboard link - Full Sales partner Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `gwdcomment` | Promoters Comment | string / text | growthdrive | 0 | 0 % |  |
| `gwdcontactinitiation` | Contact Initiation | bool / booleancheckbox | growthdrive | 0 | 0 % | 2 možností |
| `gwddisablematching` | Disable Matching | bool / booleancheckbox | growthdrive | 0 | 0 % | 2 možností |
| `gwdearnedrewards` | Earned Rewards | number / number | growthdrive | 5 | 0,1 % |  |
| `gwdmatchingmethod` | Matching Method | string / text | growthdrive | 180 | 2,1 % |  |
| `gwdstatus` | Referral Status | string / text | growthdrive | 349 | 4,1 % |  |
| `gwdtiers` | Tiers | string / text | growthdrive | 0 | 0 % |  |
| `gwdtotaldealsvalue` | Total Deals Value | number / number | growthdrive | 5 | 0,1 % |  |
| `gwdtotalrewards` | Total Rewards | number / number | growthdrive | 5 | 0,1 % |  |
| `gwdunpaidrewards` | Unpaid Rewards | number / number | growthdrive | 5 | 0,1 % |  |
| `lastreferraldate` | Last Referral Date | date / date | growthdrive | 5 | 0,1 % |  |
| `lastrewarddate` | Last Reward Date | date / date | growthdrive | 5 | 0,1 % |  |
| `partnercode` | Referral Code Submitted | string / text | growthdrive | 0 | 0 % |  |
| `partnerid` | Promoter ID | string / text | growthdrive | 0 | 0 % |  |
| `partnerstatus` | Promoter Status | string / text | growthdrive | 0 | 0 % |  |
| `payoutmethod_994f447a_aef7_4808_8e60_1acd0c373580` | Payout Method - Referral Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `payoutmethod_a0c1f03e_9c3b_4ba7_b5a7_9ecb837598e7` | Payout Method - Reseller Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `payoutmethod_a6748c29_f1ae_40a5_9026_bc3f0cc286bb` | Payout Method - Full Sales partner Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referralcode_994f447a_aef7_4808_8e60_1acd0c373580` | Referral code - Referral Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referralcode_a0c1f03e_9c3b_4ba7_b5a7_9ecb837598e7` | Referral code - Reseller Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referralcode_a6748c29_f1ae_40a5_9026_bc3f0cc286bb` | Referral code - Full Sales partner Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referrallink_994f447a_aef7_4808_8e60_1acd0c373580` | Referral link - Referral Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referrallink_a0c1f03e_9c3b_4ba7_b5a7_9ecb837598e7` | Referral link - Reseller Program Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referrallink_a6748c29_f1ae_40a5_9026_bc3f0cc286bb` | Referral link - Full Sales partner Greenlogy | string / text | growthdrive | 0 | 0 % |  |
| `referralsource` | Referral Source Email | string / text | growthdrive | 100 | 1,2 % |  |
| `referraltier` | Referral Source Tier | string / text | growthdrive | 349 | 4,1 % |  |
| `referredleads` | Total Number of Referrals | number / number | growthdrive | 5 | 0,1 % |  |
| `reseller_produkt` | Reseller produkt | enumeration / checkbox | growthdrive | 0 | 0 % | 4 možností |
| `virtualpartner` | Virtual Promoter | bool / booleancheckbox | growthdrive | 5 | 0,1 % | 2 možností |
| `facebook_consent_checkbox_consent_checkbox_0` | Facebook Consent: súhlasím_so_zasielaním_ďalších_správ_z_greenlogy | enumeration / booleancheckbox | lead_ads | 3 | 0 % | 2 možností |
| `facebook_consent_checkbox_explicit_consent` | Facebook Consent: súhlasím_s_ukladaním_a_spracovaním_mojich_osobných_údajov_greenlogy | enumeration / booleancheckbox | lead_ads | 3 | 0 % | 2 možností |
| `linkedin_consent_checkbox_i_agree_that_greenlogy_impose_and_process_my_personal_information` | LinkedIn Consent: i_agree_that_greenlogy_impose_and_process_my_personal_information. | enumeration / booleancheckbox | lead_ads | 1 | 0 % | 2 možností |
| `mali_by_ste_zujem_o_obhliadku_zadarmo` | Mali by ste záujem o obhliadku zadarmo? | string / text | lead_ads | 50 | 0,6 % |  |
| `orgcharthub_contact_on_orgchart` | OrgChartHub Is On Org Chart | enumeration / booleancheckbox | orgcharthub | 0 | 0 % | 2 možností |
| `pocet_elektroaut` | Počet elektroáut | number / number | spotrebiteľské_informácie | 687 | 8,1 % |  |
| `sluzba` | Služba | enumeration / checkbox | výkup_elektriny | 161 | 1,9 % | 4 možností |
| `typ_vyrobneho_zdroja__cloned_` | Typ výrobného zdroja | enumeration / checkbox | výkup_elektriny | 1 101 | 12,9 % | 6 možností |
| `vykon_zdroja_v_mw` | Výkon zdroja v MW | number / number | výkup_elektriny | 151 | 1,8 % |  |
| `initial_zoom_webinar_attendance_average_duration` | Total attendance duration percentage before Attendance API migration | number / number | zoom | 0 | 0 % |  |
| `zoom_webinar_attendance_average_duration` | Average Zoom webinar attendance duration | number / number | zoom | 0 | 0 % |  |
| `zoom_webinar_attendance_count` | Total number of Zoom webinars attended | number / number | zoom | 0 | 0 % |  |
| `zoom_webinar_joinlink` | Last registered Zoom webinar | string / text | zoom | 0 | 0 % |  |
| `zoom_webinar_registration_count` | Total number of Zoom webinar registrations | number / number | zoom | 0 | 0 % |  |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_analytics_average_page_views` | Average Pageviews | number / number | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_first_referrer` | First Referring Site | string / text | analyticsinformation | 2 390 | 28,1 % |  |
| `hs_analytics_first_timestamp` | Time First Seen | datetime / date | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_first_touch_converting_campaign` | First Touch Converting Campaign | string / text | analyticsinformation | 115 | 1,4 % |  |
| `hs_analytics_first_url` | First Page Seen | string / text | analyticsinformation | 3 964 | 46,6 % |  |
| `hs_analytics_first_visit_timestamp` | Time of First Session | datetime / date | analyticsinformation | 3 964 | 46,6 % |  |
| `hs_analytics_last_referrer` | Last Referring Site | string / text | analyticsinformation | 3 214 | 37,8 % |  |
| `hs_analytics_last_timestamp` | Time Last Seen | datetime / date | analyticsinformation | 3 964 | 46,6 % |  |
| `hs_analytics_last_touch_converting_campaign` | Last Touch Converting Campaign | string / text | analyticsinformation | 736 | 8,7 % |  |
| `hs_analytics_last_url` | Last Page Seen | string / text | analyticsinformation | 3 964 | 46,6 % |  |
| `hs_analytics_last_visit_timestamp` | Time of Last Session | datetime / date | analyticsinformation | 4 022 | 47,3 % |  |
| `hs_analytics_num_event_completions` | Number of event completions | number / number | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_num_page_views` | Number of Pageviews | number / number | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_num_visits` | Number of Sessions | number / number | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_revenue` | Event Revenue | number / number | analyticsinformation | 8 506 | 100 % |  |
| `hs_analytics_source` | Original Source | enumeration / select | analyticsinformation | 8 506 | 100 % | 10 možností |
| `hs_analytics_source_data_1` | Original Source Drill-Down 1 | string / text | analyticsinformation | 8 457 | 99,4 % |  |
| `hs_analytics_source_data_2` | Original Source Drill-Down 2 | string / text | analyticsinformation | 7 370 | 86,6 % |  |
| `hs_latest_source` | Latest Traffic Source | enumeration / select | analyticsinformation | 8 506 | 100 % | 10 možností |
| `hs_latest_source_data_1` | Latest Traffic Source Drill-Down 1 | string / text | analyticsinformation | 8 506 | 100 % |  |
| `hs_latest_source_data_2` | Latest Traffic Source Drill-Down 2 | string / text | analyticsinformation | 6 897 | 81,1 % |  |
| `hs_latest_source_timestamp` | Latest Traffic Source Date | datetime / date | analyticsinformation | 8 506 | 100 % |  |
| `address` | Street Address | string / text | contactinformation | 70 | 0,8 % |  |
| `associatedcompanyid` | Primary Associated Company ID | number / number | contactinformation | 2 628 | 30,9 % |  |
| `city` | City | string / text | contactinformation | 816 | 9,6 % |  |
| `closedate` | Close Date | datetime / date | contactinformation | 5 219 | 61,4 % |  |
| `company` | Company Name | string / text | contactinformation | 924 | 10,9 % |  |
| `country` | Country/Region | string / text | contactinformation | 220 | 2,6 % |  |
| `createdate` | Create Date | datetime / date | contactinformation | 8 506 | 100 % |  |
| `date_of_birth` | Dátum narodenia | date / date | contactinformation | 324 | 3,8 % |  |
| `days_to_close` | Days To Close | number / number | contactinformation | 5 208 | 61,2 % | výpočet |
| `email` | Email | string / text | contactinformation | 8 501 | 99,9 % | jedinečná |
| `engagements_last_meeting_booked` | Date of last meeting booked in meetings tool | datetime / date | contactinformation | 7 | 0,1 % |  |
| `engagements_last_meeting_booked_campaign` | Campaign of last booking in meetings tool | string / text | contactinformation | 1 | 0 % |  |
| `engagements_last_meeting_booked_medium` | Medium of last booking in meetings tool | string / text | contactinformation | 1 | 0 % |  |
| `engagements_last_meeting_booked_source` | Source of last booking in meetings tool | string / text | contactinformation | 1 | 0 % |  |
| `fax` | Fax Number | string / phonenumber | contactinformation | 6 | 0,1 % |  |
| `first_deal_created_date` | First Deal Created Date | datetime / date | contactinformation | 5 297 | 62,3 % |  |
| `firstname` | First Name | string / text | contactinformation | 8 303 | 97,6 % |  |
| `hs_additional_emails` | Additional email addresses | enumeration / select | contactinformation | 313 | 3,7 % | jedinečná |
| `hs_all_accessible_team_ids` | All teams | enumeration / select | contactinformation | 7 153 | 84,1 % |  |
| `hs_all_assigned_business_unit_ids` | Brands | enumeration / checkbox | contactinformation | 1 822 | 21,4 % |  |
| `hs_all_contact_vids` | All vids for a contact | enumeration / select | contactinformation | 8 506 | 100 % | výpočet |
| `hs_all_owner_ids` | All owner IDs | enumeration / select | contactinformation | 8 490 | 99,8 % |  |
| `hs_all_team_ids` | All team IDs | enumeration / select | contactinformation | 7 153 | 84,1 % |  |
| `hs_associated_target_accounts` | Associated Target Accounts | number / calculation_rollup | contactinformation | 5 822 | 68,4 % |  |
| `hs_avatar_filemanager_key` | Avatar FileManager key | string / text | contactinformation | 4 | 0 % |  |
| `hs_buying_role` | Buying Role | enumeration / checkbox | contactinformation | 4 442 | 52,2 % | 9 možností |
| `hs_calculated_form_submissions` | The 800 most recent form submissions for a contact | enumeration / select | contactinformation | 2 470 | 29 % | výpočet |
| `hs_calculated_merged_vids` | Merged vids with timestamps of a contact | enumeration / select | contactinformation | 391 | 4,6 % | výpočet |
| `hs_calculated_mobile_number` | Calculated Mobile Number in International Format | string / text | contactinformation | 6 258 | 73,6 % | výpočet |
| `hs_calculated_phone_number` | Calculated Phone Number in International Format | string / text | contactinformation | 1 159 | 13,6 % | výpočet |
| `hs_calculated_phone_number_country_code` | Calculated Phone Number Country Code | string / text | contactinformation | 1 159 | 13,6 % | výpočet |
| `hs_content_membership_email` | Member email | string / text | contactinformation | 161 | 1,9 % |  |
| `hs_content_membership_registered_at` | Registered At | datetime / date | contactinformation | 48 | 0,6 % |  |
| `hs_content_membership_registration_domain_sent_to` | Domain to which registration email was sent | string / text | contactinformation | 161 | 1,9 % |  |
| `hs_content_membership_registration_email_sent_at` | Time registration email was sent | datetime / date | contactinformation | 161 | 1,9 % |  |
| `hs_content_membership_status` | Status | enumeration / select | contactinformation | 1 188 | 14 % | 2 možností |
| `hs_count_is_unworked` | Count of unengaged contacts | number / calculation_equation | contactinformation | 8 490 | 99,8 % |  |
| `hs_count_is_worked` | Count of engaged contacts | number / calculation_equation | contactinformation | 8 490 | 99,8 % |  |
| `hs_created_by_conversations` | Created By Conversations | bool / booleancheckbox | contactinformation | 555 | 6,5 % | 2 možností |
| `hs_created_by_user_id` | Created by user ID | number / number | contactinformation | 3 492 | 41,1 % |  |
| `hs_createdate` | Object create date/time | datetime / date | contactinformation | 8 506 | 100 % |  |
| `hs_current_customer` | Current Customer | enumeration / select | contactinformation | 893 | 10,5 % | 2 možností |
| `hs_currently_enrolled_in_prospecting_agent` | Currently Enrolled in Prospecting Agent | bool / calculation_equation | contactinformation | 5 580 | 65,6 % | výpočet, 2 možností |
| `hs_email_domain` | Email Domain | string / text | contactinformation | 8 501 | 99,9 % | výpočet |
| `hs_feedback_last_csat_survey_date` | Last CSAT survey date | datetime / calculation_rollup | contactinformation | 393 | 4,6 % |  |
| `hs_feedback_last_csat_survey_follow_up` | Last CSAT survey comment | string / calculation_rollup | contactinformation | 160 | 1,9 % |  |
| `hs_feedback_last_csat_survey_rating` | Last CSAT survey rating | number / calculation_rollup | contactinformation | 393 | 4,6 % |  |
| `hs_feedback_last_nps_follow_up` | Last NPS survey comment | string / text | contactinformation | 86 | 1 % |  |
| `hs_feedback_last_nps_rating` | Last NPS survey rating | enumeration / select | contactinformation | 251 | 3 % | 11 možností |
| `hs_feedback_last_nps_rating_number` | Latest NPS survey rating | number / calculation_rollup | contactinformation | 252 | 3 % |  |
| `hs_feedback_last_survey_date` | Last NPS survey date | datetime / date | contactinformation | 252 | 3 % |  |
| `hs_first_engagement_object_id` | ID of first engagement | number / number | contactinformation | 4 547 | 53,5 % | výpočet |
| `hs_first_outreach_date` | First outreach date | datetime / date | contactinformation | 7 174 | 84,3 % | výpočet |
| `hs_full_name_or_email` | Full name or email | string / calculation_equation | contactinformation | 8 506 | 100 % | výpočet |
| `hs_geohash_1` | geohash_1 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_geohash_2` | geohash_2 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_geohash_3` | geohash_3 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_geohash_4` | geohash_4 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_geohash_5` | geohash_5 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_geohash_6` | geohash_6 | string / text | contactinformation | 53 | 0,6 % |  |
| `hs_gps_error` | GPS Error | string / text | contactinformation | 5 | 0,1 % |  |
| `hs_is_contact` | Is a contact | bool / calculation_read_time | contactinformation | 8 506 | 100 % | výpočet, 2 možností |
| `hs_is_enriched` | Has been enriched | bool / booleancheckbox | contactinformation | 12 | 0,1 % | 2 možností |
| `hs_is_unworked` | Contact unworked | bool / calculation_equation | contactinformation | 8 506 | 100 % | 2 možností |
| `hs_last_sales_activity_date` | last sales activity date old | datetime / date | contactinformation | 6 766 | 79,5 % |  |
| `hs_last_sales_activity_timestamp` | Last Engagement Date | datetime / date | contactinformation | 6 117 | 71,9 % |  |
| `hs_last_sales_activity_type` | Last Engagement Type | enumeration / select | contactinformation | 6 076 | 71,4 % | 8 možností |
| `hs_latest_meeting_activity` | Latest meeting activity | datetime / date | contactinformation | 35 | 0,4 % |  |
| `hs_latest_open_lead_date` | Latest Open Lead Date | datetime / calculation_rollup | contactinformation | 110 | 1,3 % | výpočet |
| `hs_latest_qualified_lead_date` | Latest Qualified Lead Date | datetime / calculation_rollup | contactinformation | 3 | 0 % | výpočet |
| `hs_latitude` | Latitude | number / number | contactinformation | 991 | 11,7 % |  |
| `hs_lead_status` | Lead Status | enumeration / radio | contactinformation | 1 530 | 18 % | 4 možností |
| `hs_legal_basis` | Legal basis for processing contact's data | enumeration / checkbox | contactinformation | 8 505 | 100 % | 6 možností |
| `hs_longitude` | Longitude | number / number | contactinformation | 991 | 11,7 % |  |
| `hs_marketable_reason_id` | Marketing contact status source name | string / text | contactinformation | 18 | 0,2 % |  |
| `hs_marketable_reason_type` | Marketing contact status source type | enumeration / select | contactinformation | 8 293 | 97,5 % | 11 možností |
| `hs_marketable_status` | Marketing contact status | enumeration / booleancheckbox | contactinformation | 8 506 | 100 % | 2 možností |
| `hs_marketable_until_renewal` | Marketing contact until next update | enumeration / booleancheckbox | contactinformation | 8 506 | 100 % | 2 možností |
| `hs_membership_last_private_content_access_date` | Membership last private content access date | datetime / date | contactinformation | 2 | 0 % |  |
| `hs_merged_object_ids` | Merged Contact IDs | enumeration / checkbox | contactinformation | 390 | 4,6 % |  |
| `hs_notes_last_activity` | Last Activity | object_coordinates / text | contactinformation | 7 238 | 85,1 % |  |
| `hs_notes_next_activity` | Next Activity | object_coordinates / text | contactinformation | 2 | 0 % |  |
| `hs_notes_next_activity_type` | Next Activity Type | enumeration / select | contactinformation | 2 | 0 % | 13 možností |
| `hs_num_active_contracts` | Number of Active Contracts | number / calculation_rollup | contactinformation | 280 | 3,3 % |  |
| `hs_num_associated_open_deals` | Number of open deals | number / calculation_rollup | contactinformation | 1 611 | 18,9 % |  |
| `hs_object_id` | Record ID | number / number | contactinformation | 8 506 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | contactinformation | 8 505 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | contactinformation | 2 831 | 33,3 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | contactinformation | 8 335 | 98 % |  |
| `hs_object_source_label` | Record source | enumeration / select | contactinformation | 8 505 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | contactinformation | 3 611 | 42,5 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | contactinformation | 7 153 | 84,1 % |  |
| `hs_pinned_engagement_id` | Pinned engagement ID | number / number | contactinformation | 161 | 1,9 % |  |
| `hs_pipeline` | Pipeline | enumeration / select | contactinformation | 8 506 | 100 % |  |
| `hs_predictivecontactscore_v2` | Likelihood to close | number / number | contactinformation | 3 287 | 38,6 % |  |
| `hs_predictivescoringtier` | Contact priority | enumeration / radio | contactinformation | 8 506 | 100 % | 5 možností |
| `hs_prospecting_agent_actively_enrolled_count` | Prospecting Agent Actively Enrolled Count | number / calculation_rollup | contactinformation | 4 775 | 56,1 % |  |
| `hs_prospecting_agent_total_enrolled_count` | Prospecting Agent Total Enrolled Count | number / calculation_rollup | contactinformation | 2 077 | 24,4 % |  |
| `hs_registration_method` | Registration Method | string / text | contactinformation | 48 | 0,6 % |  |
| `hs_sa_first_engagement_date` | Date of first engagement | datetime / date | contactinformation | 4 547 | 53,5 % |  |
| `hs_sa_first_engagement_descr` | Description of first engagement | enumeration / select | contactinformation | 4 547 | 53,5 % | výpočet, 25 možností |
| `hs_sa_first_engagement_object_type` | Type of first engagement | enumeration / select | contactinformation | 4 547 | 53,5 % | výpočet, 5 možností |
| `hs_sales_email_last_clicked` | Recent Sales Email Clicked Date | datetime / date | contactinformation | 693 | 8,1 % |  |
| `hs_sales_email_last_opened` | Recent Sales Email Opened Date | datetime / date | contactinformation | 5 914 | 69,5 % |  |
| `hs_sales_email_last_replied` | Recent Sales Email Replied Date | datetime / date | contactinformation | 5 505 | 64,7 % |  |
| `hs_searchable_calculated_international_mobile_number` | Calculated Mobile Number with country code | string / phonenumber | contactinformation | 6 259 | 73,6 % | výpočet |
| `hs_searchable_calculated_international_phone_number` | Calculated Phone Number with country code | string / phonenumber | contactinformation | 1 159 | 13,6 % | výpočet |
| `hs_searchable_calculated_mobile_number` | Calculated Mobile Number without country code | phone_number / phonenumber | contactinformation | 6 427 | 75,6 % | výpočet |
| `hs_searchable_calculated_phone_number` | Calculated Phone Number without country code | phone_number / phonenumber | contactinformation | 1 231 | 14,5 % | výpočet |
| `hs_sequences_actively_enrolled_count` | Number of sequences actively enrolled | number / number | contactinformation | 8 392 | 98,7 % |  |
| `hs_sequences_is_enrolled` | Currently in Sequence | bool / booleancheckbox | contactinformation | 11 | 0,1 % | výpočet, 2 možností |
| `hs_shared_user_ids` | Shared users | enumeration / checkbox | contactinformation | 2 | 0 % |  |
| `hs_time_between_contact_creation_and_deal_close` | Time between contact creation and deal close | number / calculation_equation | contactinformation | 5 225 | 61,4 % |  |
| `hs_time_between_contact_creation_and_deal_creation` | Time between contact creation and deal creation | number / calculation_equation | contactinformation | 5 296 | 62,3 % |  |
| `hs_time_to_first_engagement` | Lead response time | number / number | contactinformation | 4 547 | 53,5 % | výpočet |
| `hs_time_to_move_from_lead_to_customer` | Time to move from lead to customer | number / calculation_equation | contactinformation | 4 350 | 51,1 % |  |
| `hs_time_to_move_from_marketingqualifiedlead_to_customer` | Time to move from marketing qualified lead to customer | number / calculation_equation | contactinformation | 122 | 1,4 % |  |
| `hs_time_to_move_from_opportunity_to_customer` | Time to move from opportunity to customer | number / calculation_equation | contactinformation | 1 666 | 19,6 % |  |
| `hs_time_to_move_from_salesqualifiedlead_to_customer` | Time to move from sales qualified lead to customer | number / calculation_equation | contactinformation | 1 495 | 17,6 % |  |
| `hs_time_to_move_from_subscriber_to_customer` | Time to move from subscriber to customer | number / calculation_equation | contactinformation | 213 | 2,5 % |  |
| `hs_timezone` | Time Zone | enumeration / select | contactinformation | 5 294 | 62,2 % | 525 možností |
| `hs_unique_creation_key` | Unique creation key | string / text | contactinformation | 175 | 2,1 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | contactinformation | 8 452 | 99,4 % |  |
| `hs_user_ids_of_all_notification_recipients` | All contact notification recipients | enumeration / checkbox | contactinformation | 8 490 | 99,8 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | contactinformation | 8 490 | 99,8 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | contactinformation | 4 331 | 50,9 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | contactinformation | 8 490 | 99,8 % |  |
| `hubspot_owner_id` | Contact owner | enumeration / select | contactinformation | 8 490 | 99,8 % |  |
| `hubspot_team_id` | HubSpot Team | enumeration / select | contactinformation | 7 153 | 84,1 % |  |
| `industry` | Industry | string / text | contactinformation | 1 484 | 17,4 % |  |
| `job_function` | Job function | string / text | contactinformation | 370 | 4,3 % |  |
| `jobtitle` | Job Title | string / text | contactinformation | 269 | 3,2 % |  |
| `lastmodifieddate` | Last Modified Date | datetime / date | contactinformation | 8 506 | 100 % |  |
| `lastname` | Last Name | string / text | contactinformation | 8 280 | 97,3 % |  |
| `lifecyclestage` | Lifecycle Stage | enumeration / radio | contactinformation | 8 506 | 100 % | 16 možností |
| `message` | Message | string / textarea | contactinformation | 19 | 0,2 % |  |
| `mobilephone` | Mobile Phone Number | string / phonenumber | contactinformation | 6 427 | 75,6 % |  |
| `notes_last_contacted` | Last Contacted | datetime / date | contactinformation | 7 076 | 83,2 % |  |
| `notes_last_updated` | Last Activity Date | datetime / date | contactinformation | 7 238 | 85,1 % |  |
| `notes_next_activity_date` | Next Activity Date | datetime / date | contactinformation | 2 | 0 % |  |
| `num_associated_deals` | Number of Associated Deals | number / calculation_rollup | contactinformation | 5 297 | 62,3 % |  |
| `num_contacted_notes` | Number of times contacted | number / number | contactinformation | 7 254 | 85,3 % |  |
| `num_notes` | Number of Sales Activities | number / number | contactinformation | 7 641 | 89,8 % |  |
| `phone` | Phone Number | string / phonenumber | contactinformation | 1 231 | 14,5 % |  |
| `recent_deal_amount` | Recent Deal Amount | number / number | contactinformation | 4 570 | 53,7 % |  |
| `recent_deal_close_date` | Recent Deal Close Date | datetime / date | contactinformation | 4 605 | 54,1 % |  |
| `state` | State/Region | string / text | contactinformation | 11 | 0,1 % |  |
| `total_revenue` | Total Revenue | number / number | contactinformation | 4 595 | 54 % |  |
| `website` | Website URL | string / text | contactinformation | 65 | 0,8 % |  |
| `work_email` | Work email | string / text | contactinformation | 31 | 0,4 % |  |
| `zip` | Postal Code | string / text | contactinformation | 596 | 7 % |  |
| `hs_v2_cumulative_time_in_1046796415` | Cumulative time in "Čakačka VB (Lifecycle Stage Pipeline)" | number / number | contactlcs | 133 | 1,6 % |  |
| `hs_v2_cumulative_time_in_1068476447` | Cumulative time in "Green Solar DOM (Lifecycle Stage Pipeline)" | number / number | contactlcs | 50 | 0,6 % |  |
| `hs_v2_cumulative_time_in_1178563195` | Cumulative time in "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | number / number | contactlcs | 15 | 0,2 % |  |
| `hs_v2_cumulative_time_in_132044134` | Cumulative time in "Vymazať (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 025 | 12,1 % |  |
| `hs_v2_cumulative_time_in_53965359` | Cumulative time in "Čakajúci zákazník (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 267 | 14,9 % |  |
| `hs_v2_cumulative_time_in_54180979` | Cumulative time in "Odídený zákazník (Lifecycle Stage Pipeline)" | number / number | contactlcs | 246 | 2,9 % |  |
| `hs_v2_cumulative_time_in_77667470` | Cumulative time in "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | number / number | contactlcs | 751 | 8,8 % |  |
| `hs_v2_cumulative_time_in_customer` | Cumulative time in "Customer (Lifecycle Stage Pipeline)" | number / number | contactlcs | 4 895 | 57,5 % |  |
| `hs_v2_cumulative_time_in_evangelist` | Cumulative time in "Spolupracovníci (Lifecycle Stage Pipeline)" | number / number | contactlcs | 21 | 0,2 % |  |
| `hs_v2_cumulative_time_in_lead` | Cumulative time in "Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 5 616 | 66 % |  |
| `hs_v2_cumulative_time_in_marketingqualifiedlead` | Cumulative time in "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 299 | 3,5 % |  |
| `hs_v2_cumulative_time_in_opportunity` | Cumulative time in "Opportunity (Lifecycle Stage Pipeline)" | number / number | contactlcs | 2 058 | 24,2 % |  |
| `hs_v2_cumulative_time_in_other` | Cumulative time in "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | number / number | contactlcs | 247 | 2,9 % |  |
| `hs_v2_cumulative_time_in_salesqualifiedlead` | Cumulative time in "Sales Qualified Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 909 | 22,4 % |  |
| `hs_v2_cumulative_time_in_subscriber` | Cumulative time in "Subscriber (Lifecycle Stage Pipeline)" | number / number | contactlcs | 242 | 2,8 % |  |
| `hs_v2_date_entered_1046796415` | Date entered "Čakačka VB (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 424 | 5 % |  |
| `hs_v2_date_entered_1068476447` | Date entered "Green Solar DOM (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 131 | 1,5 % |  |
| `hs_v2_date_entered_1178563195` | Date entered "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 57 | 0,7 % |  |
| `hs_v2_date_entered_132044134` | Date entered "Vymazať (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 1 257 | 14,8 % |  |
| `hs_v2_date_entered_53965359` | Date entered "Čakajúci zákazník (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 1 366 | 16,1 % |  |
| `hs_v2_date_entered_54180979` | Date entered "Odídený zákazník (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 791 | 9,3 % |  |
| `hs_v2_date_entered_77667470` | Date entered "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 772 | 9,1 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | contactlcs | 8 038 | 94,5 % | výpočet |
| `hs_v2_date_entered_customer` | Date entered "Customer (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 5 272 | 62 % |  |
| `hs_v2_date_entered_evangelist` | Date entered "Spolupracovníci (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 41 | 0,5 % |  |
| `hs_v2_date_entered_lead` | Date entered "Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 6 595 | 77,5 % |  |
| `hs_v2_date_entered_marketingqualifiedlead` | Date entered "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 431 | 5,1 % |  |
| `hs_v2_date_entered_opportunity` | Date entered "Opportunity (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 2 710 | 31,9 % |  |
| `hs_v2_date_entered_other` | Date entered "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 250 | 2,9 % |  |
| `hs_v2_date_entered_salesqualifiedlead` | Date entered "Sales Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 2 518 | 29,6 % |  |
| `hs_v2_date_entered_subscriber` | Date entered "Subscriber (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 248 | 2,9 % |  |
| `hs_v2_date_exited_1046796415` | Date exited "Čakačka VB (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 133 | 1,6 % |  |
| `hs_v2_date_exited_1068476447` | Date exited "Green Solar DOM (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 50 | 0,6 % |  |
| `hs_v2_date_exited_1178563195` | Date exited "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 15 | 0,2 % |  |
| `hs_v2_date_exited_132044134` | Date exited "Vymazať (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 1 025 | 12,1 % |  |
| `hs_v2_date_exited_53965359` | Date exited "Čakajúci zákazník (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 1 267 | 14,9 % |  |
| `hs_v2_date_exited_54180979` | Date exited "Odídený zákazník (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 246 | 2,9 % |  |
| `hs_v2_date_exited_77667470` | Date exited "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 751 | 8,8 % |  |
| `hs_v2_date_exited_customer` | Date exited "Customer (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 4 891 | 57,5 % |  |
| `hs_v2_date_exited_evangelist` | Date exited "Spolupracovníci (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 21 | 0,2 % |  |
| `hs_v2_date_exited_lead` | Date exited "Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 5 614 | 66 % |  |
| `hs_v2_date_exited_marketingqualifiedlead` | Date exited "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 299 | 3,5 % |  |
| `hs_v2_date_exited_opportunity` | Date exited "Opportunity (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 2 057 | 24,2 % |  |
| `hs_v2_date_exited_other` | Date exited "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 247 | 2,9 % |  |
| `hs_v2_date_exited_salesqualifiedlead` | Date exited "Sales Qualified Lead (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 1 908 | 22,4 % |  |
| `hs_v2_date_exited_subscriber` | Date exited "Subscriber (Lifecycle Stage Pipeline)" | datetime / date | contactlcs | 242 | 2,8 % |  |
| `hs_v2_latest_time_in_1046796415` | Latest time in "Čakačka VB (Lifecycle Stage Pipeline)" | number / number | contactlcs | 133 | 1,6 % |  |
| `hs_v2_latest_time_in_1068476447` | Latest time in "Green Solar DOM (Lifecycle Stage Pipeline)" | number / number | contactlcs | 50 | 0,6 % |  |
| `hs_v2_latest_time_in_1178563195` | Latest time in "Lead Green ViWA firma  (Lifecycle Stage Pipeline)" | number / number | contactlcs | 15 | 0,2 % |  |
| `hs_v2_latest_time_in_132044134` | Latest time in "Vymazať (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 025 | 12,1 % |  |
| `hs_v2_latest_time_in_53965359` | Latest time in "Čakajúci zákazník (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 267 | 14,9 % |  |
| `hs_v2_latest_time_in_54180979` | Latest time in "Odídený zákazník (Lifecycle Stage Pipeline)" | number / number | contactlcs | 246 | 2,9 % |  |
| `hs_v2_latest_time_in_77667470` | Latest time in "Neúspešná príležitosť (Lifecycle Stage Pipeline)" | number / number | contactlcs | 751 | 8,8 % |  |
| `hs_v2_latest_time_in_customer` | Latest time in "Customer (Lifecycle Stage Pipeline)" | number / number | contactlcs | 4 891 | 57,5 % |  |
| `hs_v2_latest_time_in_evangelist` | Latest time in "Spolupracovníci (Lifecycle Stage Pipeline)" | number / number | contactlcs | 21 | 0,2 % |  |
| `hs_v2_latest_time_in_lead` | Latest time in "Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 5 614 | 66 % |  |
| `hs_v2_latest_time_in_marketingqualifiedlead` | Latest time in "Marketing Qualified Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 299 | 3,5 % |  |
| `hs_v2_latest_time_in_opportunity` | Latest time in "Opportunity (Lifecycle Stage Pipeline)" | number / number | contactlcs | 2 057 | 24,2 % |  |
| `hs_v2_latest_time_in_other` | Latest time in "Ostatní_Nezaradení (Lifecycle Stage Pipeline)" | number / number | contactlcs | 247 | 2,9 % |  |
| `hs_v2_latest_time_in_salesqualifiedlead` | Latest time in "Sales Qualified Lead (Lifecycle Stage Pipeline)" | number / number | contactlcs | 1 908 | 22,4 % |  |
| `hs_v2_latest_time_in_subscriber` | Latest time in "Subscriber (Lifecycle Stage Pipeline)" | number / number | contactlcs | 242 | 2,8 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | contactlcs | 8 038 | 94,5 % | výpočet |
| `hs_membership_has_accessed_private_content` | Member has accessed private content | number / calculation_equation | contactscripted | 5 871 | 69 % | výpočet |
| `hs_registered_member` | Registered member | number / calculation_equation | contactscripted | 8 505 | 100 % | výpočet |
| `first_conversion_date` | First Conversion Date | datetime / date | conversioninformation | 2 470 | 29 % | výpočet |
| `first_conversion_event_name` | First Conversion | string / text | conversioninformation | 2 470 | 29 % | výpočet |
| `hs_facebook_ad_clicked` | Clicked Facebook ad | bool / booleancheckbox | conversioninformation | 67 | 0,8 % | 2 možností |
| `hs_facebook_click_id` | Facebook Click ID | string / text | conversioninformation | 53 | 0,6 % |  |
| `hs_google_click_id` | Google Click ID | string / text | conversioninformation | 1 317 | 15,5 % |  |
| `hs_ip_timezone` | IP Timezone | string / text | conversioninformation | 5 340 | 62,8 % |  |
| `ip_city` | IP City | string / text | conversioninformation | 3 969 | 46,7 % |  |
| `ip_country` | IP Country | string / text | conversioninformation | 5 340 | 62,8 % |  |
| `ip_country_code` | IP Country Code | string / text | conversioninformation | 5 340 | 62,8 % |  |
| `ip_state` | IP State/Region | string / text | conversioninformation | 4 878 | 57,3 % |  |
| `ip_state_code` | IP State Code/Region Code | string / text | conversioninformation | 4 876 | 57,3 % |  |
| `ip_zipcode` | IP Zipcode | string / text | conversioninformation | 1 086 | 12,8 % |  |
| `num_conversion_events` | Number of Form Submissions | number / number | conversioninformation | 8 412 | 98,9 % | výpočet |
| `num_unique_conversion_events` | Number of Unique Forms Submitted | number / number | conversioninformation | 8 412 | 98,9 % | výpočet |
| `recent_conversion_date` | Recent Conversion Date | datetime / date | conversioninformation | 2 470 | 29 % | výpočet |
| `recent_conversion_event_name` | Recent Conversion | string / text | conversioninformation | 2 470 | 29 % | výpočet |
| `currentlyinworkflow` | Currently in workflow (discontinued) | enumeration / booleancheckbox | emailinformation | 5 862 | 68,9 % | 2 možností |
| `hs_email_bad_address` | Invalid email address | bool / booleancheckbox | emailinformation | 2 | 0 % | 2 možností |
| `hs_email_bounce` | Marketing emails bounced | number / number | emailinformation | 80 | 0,9 % |  |
| `hs_email_click` | Marketing emails clicked | number / number | emailinformation | 3 119 | 36,7 % |  |
| `hs_email_communication_subscriptions_opted_in` | Email subscription types: subscribed | enumeration / checkbox | emailinformation | 8 349 | 98,2 % |  |
| `hs_email_communication_subscriptions_opted_out` | Email subscription types: unsubscribed | enumeration / checkbox | emailinformation | 230 | 2,7 % |  |
| `hs_email_delivered` | Marketing emails delivered | number / number | emailinformation | 7 518 | 88,4 % |  |
| `hs_email_first_click_date` | First marketing email click date | datetime / date | emailinformation | 2 861 | 33,6 % |  |
| `hs_email_first_open_date` | First marketing email open date | datetime / date | emailinformation | 5 495 | 64,6 % |  |
| `hs_email_first_reply_date` | First marketing email reply date | datetime / date | emailinformation | 894 | 10,5 % |  |
| `hs_email_first_send_date` | First marketing email send date | datetime / date | emailinformation | 7 002 | 82,3 % |  |
| `hs_email_hard_bounce_reason_enum` | Email hard bounce reason | enumeration / radio | emailinformation | 72 | 0,8 % | 6 možností |
| `hs_email_last_click_date` | Last marketing email click date | datetime / date | emailinformation | 3 119 | 36,7 % |  |
| `hs_email_last_email_name` | Last marketing email name | string / text | emailinformation | 7 579 | 89,1 % |  |
| `hs_email_last_open_date` | Last marketing email open date | datetime / date | emailinformation | 5 917 | 69,6 % |  |
| `hs_email_last_reply_date` | Last marketing email reply date | datetime / date | emailinformation | 894 | 10,5 % |  |
| `hs_email_last_send_date` | Last marketing email send date | datetime / date | emailinformation | 7 518 | 88,4 % |  |
| `hs_email_open` | Marketing emails opened | number / number | emailinformation | 5 912 | 69,5 % |  |
| `hs_email_optimal_send_day_of_week` | Optimal marketing email send day of week | string / text | emailinformation | 1 669 | 19,6 % |  |
| `hs_email_optimal_send_time_of_day` | Optimal marketing email send time of day | string / text | emailinformation | 2 241 | 26,3 % |  |
| `hs_email_optout` | Unsubscribed from all email | bool / booleancheckbox | emailinformation | 59 | 0,7 % | 2 možností |
| `hs_email_optout_20169478` | Opted out of email: Marketingové informácie Twinlogy | enumeration / booleancheckbox | emailinformation | 46 | 0,5 % | 2 možností |
| `hs_email_optout_43828489` | Opted out of email: Správa produktov a služieb | enumeration / booleancheckbox | emailinformation | 82 | 1 % | 2 možností |
| `hs_email_optout_6832158` | Opted out of email: Marketingové informácie Greenlogy | enumeration / booleancheckbox | emailinformation | 162 | 1,9 % | 2 možností |
| `hs_email_optout_6832757` | Opted out of email: Individuálna komunikácia s klientom | enumeration / booleancheckbox | emailinformation | 68 | 0,8 % | 2 možností |
| `hs_email_optout_6889720` | Opted out of email: Default Greenlogy Blog Subscription | enumeration / booleancheckbox | emailinformation | 45 | 0,5 % | 2 možností |
| `hs_email_optout_6904363` | Opted out of email: Komunikácia so zákazníckymi službami | enumeration / booleancheckbox | emailinformation | 78 | 0,9 % | 2 možností |
| `hs_email_optout_7135946` | Opted out of email: Prihlásenie na odber blogu značky Greenlogy | enumeration / booleancheckbox | emailinformation | 135 | 1,6 % | 2 možností |
| `hs_email_optout_9356736` | Opted out of email: Prihlásenie na odber blogu značky Twinlogy | enumeration / booleancheckbox | emailinformation | 46 | 0,5 % | 2 možností |
| `hs_email_replied` | Marketing emails replied | number / number | emailinformation | 894 | 10,5 % |  |
| `hs_email_sends_since_last_engagement` | Sends Since Last Engagement | number / number | emailinformation | 7 583 | 89,1 % |  |
| `hs_messaging_engagement_score` | Messaging engagement score | number / number | emailinformation | 5 898 | 69,3 % |  |
| `hs_social_facebook_clicks` | Facebook Clicks | number / number | socialmediainformation | 8 506 | 100 % |  |
| `hs_social_google_plus_clicks` | Google Plus Clicks | number / number | socialmediainformation | 8 506 | 100 % |  |
| `hs_social_last_engagement` | Most Recent Social Click | datetime / date | socialmediainformation | 34 | 0,4 % |  |
| `hs_social_linkedin_clicks` | LinkedIn Clicks | number / number | socialmediainformation | 8 506 | 100 % |  |
| `hs_social_num_broadcast_clicks` | Broadcast Clicks | number / number | socialmediainformation | 8 506 | 100 % |  |
| `hs_social_twitter_clicks` | Twitter Clicks | number / number | socialmediainformation | 8 506 | 100 % |  |

#### HubSpot vlastnosti bez dát (148)

`hs_analytics_source_composite_data`, `hs_latest_source_composite_data`, `annualrevenue`, `associatedcompanylastupdated`, `blog_blog_greenlogy_11732875214_subscription`, `company_size`, `degree`, `field_of_study`, `gender`, `graduation_date`, `hs_active_contracts_arr`, `hs_active_contracts_mrr`, `hs_active_contracts_tcv`, `hs_calculated_phone_number_area_code`, `hs_calculated_phone_number_region_code`, `hs_chat_assistant_iql_date`, `hs_chat_assistant_source`, `hs_chat_assistant_summary`, `hs_contact_enrichment_opt_out`, `hs_contact_enrichment_opt_out_timestamp`, `hs_content_membership_email_confirmed`, `hs_content_membership_follow_up_enqueued_at`, `hs_content_membership_notes`, `hs_conversations_visitor_email`, `hs_country_region_code`, `hs_customer_agent_lead_status`, `hs_data_privacy_ads_consent`, `hs_document_last_revisited`, `hs_email_live_sourcing_restricted`, `hs_feedback_show_nps_web_survey`, `hs_first_subscription_create_date`, `hs_gps_latitude`, `hs_gps_longitude`, `hs_has_active_subscription`, `hs_inferred_language_codes`, `hs_intent_paid_up_to_date`, `hs_intent_signals_enabled`, `hs_is_mass_marketing_activation_disallowed`, `hs_is_merge_revertible`, `hs_journey_stage`, `hs_language`, `hs_last_metered_enrichment_timestamp`, `hs_lastmodifieddate`, `hs_latest_disqualified_lead_date`, `hs_latest_sequence_ended_date`, `hs_latest_sequence_enrolled`, `hs_latest_sequence_enrolled_date`, `hs_latest_sequence_finished_date`, `hs_latest_sequence_unenrolled_date`, `hs_latest_subscription_create_date`, `hs_live_enrichment_deadline`, `hs_manual_campaign_ids`, `hs_mobile_sdk_push_tokens`, `hs_next_renewal_date`, `hs_object_source_detail_2`, `hs_object_source_detail_3`, `hs_persona`, `hs_predictivecontactscore`, `hs_predictivecontactscorebucket`, `hs_prospecting_agent_last_enrolled`, `hs_read_only`, `hs_role`, `hs_seniority`, `hs_sequences_enrolled_count`, `hs_shared_team_ids`, `hs_source_object_id`, `hs_source_portal_id`, `hs_sourced_contact_origin`, `hs_state_code`, `hs_sub_role`, `hs_testrollback`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `hs_whatsapp_bsuids`, `hs_whatsapp_phone_number`, `marital_status`, `military_status`, `numemployees`, `ownername`, `relationship_status`, `salutation`, `school`, `seniority`, `start_date`, `surveymonkeyeventlastupdated`, `twitterhandle`, `webinareventlastupdated`, `hs_inbound_agent_qualification_status`, `hs_v2_cumulative_time_in_1371734699`, `hs_v2_date_entered_1371734699`, `hs_v2_date_exited_1371734699`, `hs_v2_latest_time_in_1371734699`, `hs_bing_ad_clicked`, `hs_bing_click_id`, `hs_chatgpt_ad_clicked`, `hs_chatgpt_click_id`, `hs_clicked_linkedin_ad`, `hs_inbound_agent_inquiry_type`, `hs_inbound_agent_last_conversation_date`, `hs_linkedin_ad_clicked`, `hs_linkedin_click_id`, `hs_reddit_ad_clicked`, `hs_reddit_click_id`, `hs_tiktok_ad_clicked`, `hs_tiktok_click_id`, `ip_latlon`, `hs_consent_to_email_tracking`, `hs_email_customer_quarantined_reason`, `hs_email_engagement_likelihood_category`, `hs_email_hard_bounce_reason`, `hs_email_is_ineligible`, `hs_email_quarantined`, `hs_email_quarantined_reason`, `hs_email_recipient_fatigue_recovery_time`, `hs_email_type`, `hs_emailconfirmationstatus`, `hs_employment_change_detected_date`, `hs_enforce_double_opt_in`, `hs_enriched_email_bounce_detected`, `hs_job_change_detected_date`, `hs_quarantined_emails`, `hs_returning_to_office_detected_date`, `hs_cross_account_note`, `hs_cross_sell_opportunity`, `hs_excluded_from_cross_account_data_mirroring`, `hs_first_closed_order_id`, `hs_first_order_closed_date`, `hs_recent_closed_order_date`, `hs_prospecting_agent_activation_email_id`, `hs_prospecting_agent_activation_status`, `hs_prospecting_agent_enrollment_status`, `hs_prospecting_agent_enrollment_status_raw`, `hs_prospecting_agent_sender`, `hs_why_this_contact`, `hs_last_sms_send_date`, `hs_last_sms_send_name`, `followercount`, `hs_facebookid`, `hs_googleplusid`, `hs_linkedin_url`, `hs_linkedinid`, `hs_twitterid`, `kloutscoregeneral`, `linkedinbio`, `linkedinconnections`, `photo`, `twitterbio`, `twitterprofilephoto`

#### Vypočítané vlastnosti (vlastné)

| Interný názov | Label | Typ | Vzorec / definícia |
| --- | --- | --- | --- |
| `hodnotenie_kontaktu__problemovost_` | Hodnotenie kontaktu (problémovosť) | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `hubspotscore` | Greenlogy score | calculation_score | – (API definíciu nevracia) |

#### Možnosti výberových polí

- **`ako_chcete_vyuzivat_sluzbu_darovania_kreditov_`** (Ako chcete využívať službu darovania kreditov?): `Ako Darca - chcem darovať kredity z výrobného miesta na iné odberné miesto` = Ako Darca - chcem darovať kredity z výrobného miesta na iné odberné miesto; `Ako Príjemca - chcem len prijímať darovaný kredit` = Ako Príjemca - chcem len prijímať darovaný kredit
- **`ako_chcete_vyuzivat_sluzbu_greenshare__new`** (Ako chcete využívať službu GreenShare? New): `Ako Darca - chcem darovať svoju prebytočnú elektrinu z virtuálnej batérie` = Ako Darca - chcem darovať svoju prebytočnú elektrinu z virtuálnej batérie; `Ako Príjímateľ - chcem len prijímať prebytky od svojich blízkych` = Ako Príjímateľ - chcem len prijímať prebytky od svojich blízkych; `Ako Darca aj Príjemca` = Ako Darca aj Príjemca
- **`ako_vas_mame_kontaktovat_`** (Ako Vás máme kontaktovať?): `E-mail` = E-mail; `Telefonicky` = Telefonicky
- **`aku_sluzbu_virtualnej_baterie_mate_aktivovanu_`** (Akú službu Virtuálnej batérie máte aktivovanú?): `ECO` = ECO; `STANDARD` = STANDARD; `PREMIUM` = PREMIUM; `MAX` = MAX; `AKU` = AKU
- **`chcete_pridat_dalsie_odberne_miesto_`** (Chcete pridať ďalšie odberné miesto?): `Nie` = Nie; `Áno` = Áno
- **`claude_audit`** (Claude audit): `Áno` = Áno; `Nie` = Nie
- **`e_mobility__mam_zaujem_o_blizsie_informacie_ohladom`** (E-Mobility: Mám záujem o bližšie informácie ohľadom): `Operatívneho leasingu vozidiel` = Operatívneho leasingu vozidiel; `Elektromobilov` = Elektromobilov; `Nabíjacej infraštruktúry` = Nabíjacej infraštruktúry; `Telematiky` = Telematiky; `výstavby FTV elektrárne` = výstavby FTV elektrárne
- **`faza_zakaznika`** (Fáza zákazníka): `Čakajúci zákazník` = Čakajúci zákazník; `Aktívny zákazník` = Aktívny zákazník
- **`kampan`** (Kampaň): `NEP` = NEP; `Kampaň 1` = Kampaň 1; `GreenShare` = GreenShare; `GreenSolar` = GreenSolar; `ViWA` = ViWA
- **`lead_perdoo`** (Lead_Perdoo): `B2B lead` = B2B lead; `B2C lead` = B2C lead; `VIWA lead` = VIWA lead; `Solar lead` = Solar lead; `Bess lead` = Bess lead
- **`magazin_bez_napatia_`** (Magazín "Bez napätia"): `Mám tip na reportáž` = Mám tip na reportáž; `Mám záujem o inzerciu alebo product placement` = Mám záujem o inzerciu alebo product placement
- **`mam_zaujem_o_tento_program_virtualnej_baterie`** (Mám záujem o tento program virtuálnej batérie): `Green VBattery Premium` = Green VBattery Premium; `Green VBattery MAX` = Green VBattery MAX; `Green VBattery AKU` = Green VBattery AKU; `Green VBattery Standard` = Green VBattery Standard
- **`mam_zaujem_o_tuto_sluzbu_virtualnej_baterie`** (Mám záujem o túto službu virtuálnej batérie): `Green VBattery MAX` = Green VBattery MAX; `Green VBattery Premium` = Green VBattery Premium; `Green VBattery AKU` = Green VBattery AKU; `Green VBattery Standard` = Green VBattery Standard; `chcem len zazmluvniť odber` = chcem len zazmluvniť odber
- **`mate_aktivnu_sluzbu_virtualnej_baterie_v_greenlogy__new`** (Máte aktívnu službu Virtuálnej batérie v Greenlogy? New): `Áno` = Áno; `Ešte nie` = Ešte nie
- **`mate_aktivovanu_sluzbu_green_viwa_pre_firmy_`** (Máte aktivovanú službu Green ViWA pre firmy?): `Áno` = Áno; `Ešte nie` = Ešte nie
- **`nasim_zakaznikom_je_vasa_`** (Naším zákazníkom je Vaša:): `Option 1` = Domácnosť; `Option 2` = Firma
- **`o_aky_program_virtualnej_baterie_by_ste_mali_zaujem`** (O aký program virtuálnej batérie by ste mali záujem?): `true` = Yes; `false` = No
- **`o_aky_typ_partnerstva_mate_zaujem_`** (O aký typ partnerstva máte záujem?): `Referral partner` = Referral partner; `Reseller partner` = Reseller partner; `Full sales partner` = Full sales partner
- **`poznam_svoju_tarifu_a_rocnu_spotrebu_`** (Poznám svoju tarifu a ročnú spotrebu?): `Nie` = Nie; `Áno` = Áno
- **`segment`** (Typ kontaktu): `Domácnosť` = Domácnosť; `Firma` = Firma; `Komunal` = Komunal; `Dodávateľ` = Výrobca; `Externý partner_sales` = Externý partner_sales; `Externý partner_služby` = Externý partner_služby; `Zamestnanec` = Zamestnanec; `Odídený` = Odídený zákazník; `Na výmaz kontaktu` = Na výmaz kontaktu; `Distribučky, OKTE, konkurenti` = Distribučky, OKTE, konkurenti; `Elektromobilita` = Elektromobilita
- **`ste_zakaznikom_greenlogy__new`** (Ste zákazníkom Greenlogy? New): `Áno` = Áno; `Ešte nie` = Ešte nie
- **`suhlasim_so_spracovanim_udajov_`** (Súhlasím so spracovaním údajov *): `true` = Yes; `false` = No
- **`vybrat_tarifu_`** (Vybrať tarifu...): `D1` = D1; `D2` = D2; `D3` = D3; `D4` = D4; `D5` = D5; `D6` = D6; `D7` = D7; `D8` = D8
- **`zdroj_kontaktu_ako_vznikol_`** (Zdroj kontaktu - ako vznikol?): `Email integration` = Email; `Ručné založenie` = Manual; `Formulár z webu` = Web; `Formulár z Linkedin` = Linkedin; `Formulár z Facebook` = Facebook; `Finstat databáza` = Finstat; `Referencia` = Referencia; `Ticket` = Ticket; `Sales portal` = Sales portal
- **`ako_chcete_vyuzivat_sluzbu_greenshare_pre_firmy_`** (Ako chcete využívať službu GreenShare pre firmy?): `Ako Darca (mám výrobný zdroj)` = Ako Darca (mám výrobný zdroj); `Ako Príjemca (odberné miesto bez výrobného zdroja)` = Ako Príjemca (odberné miesto bez výrobného zdroja)
- **`vypoved_podana`** (Výpoveď podaná): `true` = Yes; `false` = No
- **`grn_charging_stations_b2c_engine`** (GRN Charging Stations B2C Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Charging Stations B2C; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Sales Process (KAM)` = Accept Offer; `Contract Creation` = Installation and Technical Support
- **`grn_energia_b2c_engine`** (GRN Energia B2C Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Energia pre Domasnosti; `Blog Subscribe` = Blog Subscribe; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Open Email / SMS Offer` = Open Email / SMS Offer; `Contract Creation` = Contract Creation; `Contract Signed` = Contract Signed; `Proces Zmeny (Success / Fail)` = Proces Zmeny (Success / Fail); `Welcome / Portal Onboarding` = Welcome / Portal Onboarding; `Zelena Elektrina Customer` = Zelena Elektrina Customer; `Elektromobilita Kupon` = Elektromobilita Kupon; `Virtualna Bateria Customer` = Virtualna Bateria Customer; `Testimonial / Case Study` = Testimonial / Case Study; `NPS Detractor` = NPS Detractor; `NPS Neutral` = NPS Neutral; `NPS Survey` = NPS Promoter; `Referral Activation` = Referral Activation; `Active Referrals` = Active Referrals
- **`grn_fotovoltika_b2c_engine`** (GRN Fotovoltika B2C Engine): `Visited Page - Energia pre Domasnosti` = Visited Page - Fotovoltika B2C; `Download Ebook` = Download Ebook; `Request Offer` = Request Offer; `Sales Process (KAM)` = Accept Offer; `Contract Creation` = Installation and Technical Support
- **`gpanoodoslatponuku`** (GpAnoOdoslatPonuku): `true` = Yes; `false` = No
- **`gwdcontactinitiation`** (Contact Initiation): `true` = Yes; `false` = No
- **`gwddisablematching`** (Disable Matching): `true` = Yes; `false` = No
- **`reseller_produkt`** (Reseller produkt): `Dodávka zelenej elektriny` = Dodávka zelenej elektriny; `Virtuálna batéria a sharing` = Virtuálna batéria a sharing; `Výkup elektriny` = Výkup elektriny; `GreenCar` = GreenCar
- **`virtualpartner`** (Virtual Promoter): `false` = No; `true` = Yes
- **`facebook_consent_checkbox_consent_checkbox_0`** (Facebook Consent: súhlasím_so_zasielaním_ďalších_správ_z_greenlogy): `false` = No; `true` = Yes
- **`facebook_consent_checkbox_explicit_consent`** (Facebook Consent: súhlasím_s_ukladaním_a_spracovaním_mojich_osobných_údajov_greenlogy): `false` = No; `true` = Yes
- **`linkedin_consent_checkbox_i_agree_that_greenlogy_impose_and_process_my_personal_information`** (LinkedIn Consent: i_agree_that_greenlogy_impose_and_process_my_personal_information.): `false` = No; `true` = Yes
- **`orgcharthub_contact_on_orgchart`** (OrgChartHub Is On Org Chart): `true` = Yes; `false` = No
- **`sluzba`** (Služba): `Výkup` = Výkup; `Dodávka` = Dodávka; `Green Solar` = Green Solar; `Záruky` = Záruky
- **`typ_vyrobneho_zdroja__cloned_`** (Typ výrobného zdroja): `Slnko` = Slnko; `Vietor` = Vietor; `Voda` = Voda; `Bioplyn` = Bioplyn; `Biomasa` = Biomasa; `KVET` = KVET
- **`hs_analytics_source`** (Original Source): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_latest_source`** (Latest Traffic Source): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_buying_role`** (Buying Role): `BLOCKER` = Blocker; `BUDGET_HOLDER` = Budget Holder; `CHAMPION` = Champion; `DECISION_MAKER` = Decision Maker; `END_USER` = End User; `EXECUTIVE_SPONSOR` = Executive Sponsor; `INFLUENCER` = Influencer; `LEGAL_AND_COMPLIANCE` = Legal & Compliance; `OTHER` = Other
- **`hs_content_membership_status`** (Status): `active` = Active; `inactive` = Inactive
- **`hs_created_by_conversations`** (Created By Conversations): `true` = True; `false` = False
- **`hs_current_customer`** (Current Customer): `yes` = Yes; `no` = No
- **`hs_currently_enrolled_in_prospecting_agent`** (Currently Enrolled in Prospecting Agent): `true` = Yes; `false` = No
- **`hs_feedback_last_nps_rating`** (Last NPS survey rating): `0` = 0; `1` = 1; `2` = 2; `3` = 3; `4` = 4; `5` = 5; `6` = 6; `7` = 7; `8` = 8; `9` = 9; `10` = 10
- **`hs_is_contact`** (Is a contact): `true` = True; `false` = False
- **`hs_is_enriched`** (Has been enriched): `true` = Yes; `false` = No
- **`hs_is_unworked`** (Contact unworked): `true` = True; `false` = False
- **`hs_last_sales_activity_type`** (Last Engagement Type): `COMPANYPROSPECTS_REVISIT` = Company Website Visit; `PRESENTATION_REVISIT` = Document View; `EMAIL_CLICK` = Email Click; `EMAIL_OPEN` = Email Open; `EMAIL_REPLY` = Email Reply; `FORM_SUBMITTED` = Form Submitted; `MEETING_BOOKED` = Meeting Booked; `HUBSPOT_REVISIT` = Website Visit
- **`hs_lead_status`** (Lead Status): `NEW` = Nový; `IN_PROGRESS` = V riešení; `OPEN_DEAL` = Rozpracovaný deal; `UNQUALIFIED` = Irelevantný
- **`hs_legal_basis`** (Legal basis for processing contact's data): `Legitimate interest – prospect/lead` = Legitimate interest - prospect/lead; `Legitimate interest – existing customer` = Legitimate interest - existing customer; `Legitimate interest - other` = Legitimate interest - other; `Performance of a contract` = Performance of a contract; `Freely given consent from contact` = Freely given consent from contact; `Not applicable` = Not applicable
- **`hs_marketable_reason_type`** (Marketing contact status source type): `AD` = Ad; `CONTACT_IMPORT` = Contact Import; `CONVERSATION` = Conversation; `FORM_SUBMISSION` = Form Submission; `INITIAL_STATE` = Initial State; `INTEGRATOR_SET` = Integrator Set; `USER_SET` = User Set; `WORKFLOW` = Workflow; `EMAIL` = Email; `SAMPLE_CONTACT` = Sample Contact; `FEEDBACK_SUBMISSION` = Feedback Submission
- **`hs_marketable_status`** (Marketing contact status): `true` = Marketing contact; `false` = Non-marketing contact
- **`hs_marketable_until_renewal`** (Marketing contact until next update): `true` = Yes; `false` = --
- **`hs_notes_next_activity_type`** (Next Activity Type): `CALL` = Call; `CONVERSATION_SESSION` = Conversation session; `INCOMING_EMAIL` = Email reply from contact; `EMAIL` = Email sent to contact; `FORWARDED_EMAIL` = Forwarded email; `LINKEDIN_MESSAGE` = LinkedIn message; `MEETING` = Meeting; `NOTE` = Note; `POSTAL_MAIL` = Postal mail; `PUBLISHING_TASK` = Publishing task; `SMS` = SMS; `TASK` = Task; `WHATS_APP` = WhatsApp
- **`hs_predictivescoringtier`** (Contact priority): `tier_1` = Very High; `tier_2` = High; `tier_3` = Medium; `tier_4` = Low; `closed_won` = Closed Won
- **`hs_sa_first_engagement_descr`** (Description of first engagement): `EMPTY_DESCRIPTION` = ; `BOUNCED` = Bounced; `BUSY` = Busy; `CALLING_CRM_USER` = Calling CRM user (skrytá); `CANCELED` = Canceled; `COMPLETED` = Completed; `CONNECTING` = Connecting (skrytá); `DEFERRED` = Deferred; `FB_MESSENGER` = Facebook Messenger; `FAILED` = Failed; `IN_PROGRESS` = In progress (skrytá); `LIVE_CHAT` = Live chat; `LOGGED_CALL` = Logged call; `NO_ANSWER` = No answer; `NO_SHOW` = No show; `NOT_STARTED` = Not started; `QUEUED` = Queued (skrytá); `RESCHEDULED` = Rescheduled; `RINGING` = Ringing (skrytá); `SCHEDULED` = Scheduled; `SENDING` = Sending; `SENT` = Sent; `WAITING` = Waiting; `MISSED` = Missed; `HOLD` = On Hold
- **`hs_sa_first_engagement_object_type`** (Type of first engagement): `CALL` = Call; `CONVERSATION_SESSION` = Conversation session; `EMAIL` = Email; `MEETING_EVENT` = Meeting; `TASK` = Task
- **`hs_sequences_is_enrolled`** (Currently in Sequence): `true` = True; `false` = False
- **`hs_timezone`** (Time Zone): `pacific_slash_midway` = UTC -11:00 Pacific Midway; `pacific_slash_niue` = UTC -11:00 Pacific Niue; `pacific_slash_pago_pago` = UTC -11:00 Pacific Pago Pago; `pacific_slash_samoa` = UTC -11:00 Pacific Samoa; `us_slash_samoa` = UTC -11:00 US Samoa; `pacific_slash_honolulu` = UTC -10:00 Pacific Honolulu; `pacific_slash_johnston` = UTC -10:00 Pacific Johnston; `pacific_slash_rarotonga` = UTC -10:00 Pacific Rarotonga; `pacific_slash_tahiti` = UTC -10:00 Pacific Tahiti; `us_slash_hawaii` = UTC -10:00 US Hawaii; `pacific_slash_marquesas` = UTC -09:30 Pacific Marquesas; `america_slash_adak` = UTC -09:00 America Adak; `america_slash_atka` = UTC -09:00 America Atka; `pacific_slash_gambier` = UTC -09:00 Pacific Gambier; `us_slash_aleutian` = UTC -09:00 US Aleutian; `america_slash_anchorage` = UTC -08:00 America Anchorage; `america_slash_juneau` = UTC -08:00 America Juneau; `america_slash_metlakatla` = UTC -08:00 America Metlakatla; `america_slash_nome` = UTC -08:00 America Nome; `america_slash_sitka` = UTC -08:00 America Sitka; `america_slash_yakutat` = UTC -08:00 America Yakutat; `pacific_slash_pitcairn` = UTC -08:00 Pacific Pitcairn; `us_slash_alaska` = UTC -08:00 US Alaska; `america_slash_creston` = UTC -07:00 America Creston; `america_slash_dawson` = UTC -07:00 America Dawson; `america_slash_dawson_creek` = UTC -07:00 America Dawson Creek; `america_slash_ensenada` = UTC -07:00 America Ensenada; `america_slash_fort_nelson` = UTC -07:00 America Fort Nelson; `america_slash_hermosillo` = UTC -07:00 America Hermosillo; `america_slash_los_angeles` = UTC -07:00 America Los Angeles; `america_slash_phoenix` = UTC -07:00 America Phoenix; `america_slash_santa_isabel` = UTC -07:00 America Santa Isabel; `america_slash_tijuana` = UTC -07:00 America Tijuana; `america_slash_vancouver` = UTC -07:00 America Vancouver; `america_slash_whitehorse` = UTC -07:00 America Whitehorse; `canada_slash_pacific` = UTC -07:00 Canada Pacific; `canada_slash_yukon` = UTC -07:00 Canada Yukon; `mexico_slash_bajanorte` = UTC -07:00 Mexico BajaNorte; `us_slash_arizona` = UTC -07:00 US Arizona; `us_slash_pacific` = UTC -07:00 US Pacific; `us_slash_pacific_hyphen_new` = UTC -07:00 US Pacific-New; `america_slash_belize` = UTC -06:00 America Belize; `america_slash_boise` = UTC -06:00 America Boise; `america_slash_cambridge_bay` = UTC -06:00 America Cambridge Bay; `america_slash_chihuahua` = UTC -06:00 America Chihuahua; `america_slash_costa_rica` = UTC -06:00 America Costa Rica; `america_slash_denver` = UTC -06:00 America Denver; `america_slash_edmonton` = UTC -06:00 America Edmonton; `america_slash_el_salvador` = UTC -06:00 America El Salvador; `america_slash_guatemala` = UTC -06:00 America Guatemala … a ďalších 475
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False
- **`lifecyclestage`** (Lifecycle Stage): `evangelist` = Spolupracovníci; `subscriber` = Subscriber; `lead` = Lead; `marketingqualifiedlead` = Marketing Qualified Lead; `salesqualifiedlead` = Sales Qualified Lead; `opportunity` = Opportunity; `53965359` = Čakajúci zákazník; `1046796415` = Čakačka VB; `1178563195` = Lead Green ViWA firma; `1068476447` = Green Solar DOM; `other` = Ostatní_Nezaradení; `customer` = Customer; `54180979` = Odídený zákazník; `77667470` = Neúspešná príležitosť; `132044134` = Vymazať; `1371734699` = TEST Claude
- **`hs_facebook_ad_clicked`** (Clicked Facebook ad): `true` = True; `false` = False
- **`currentlyinworkflow`** (Currently in workflow (discontinued)): `true` = True; `false` = False
- **`hs_email_bad_address`** (Invalid email address): `true` = True; `false` = False
- **`hs_email_hard_bounce_reason_enum`** (Email hard bounce reason): `CONTENT` = Content; `MAILBOX_FULL` = Mailbox full; `OTHER` = Other; `POLICY` = Policy; `SPAM` = Spam; `UNKNOWN_USER` = Unknown user
- **`hs_email_optout`** (Unsubscribed from all email): `true` = True; `false` = False
- **`hs_email_optout_20169478`** (Opted out of email: Marketingové informácie Twinlogy): `false` = No; `true` = Yes
- **`hs_email_optout_43828489`** (Opted out of email: Správa produktov a služieb): `false` = No; `true` = Yes
- **`hs_email_optout_6832158`** (Opted out of email: Marketingové informácie Greenlogy): `false` = No; `true` = Yes
- **`hs_email_optout_6832757`** (Opted out of email: Individuálna komunikácia s klientom): `false` = No; `true` = Yes
- **`hs_email_optout_6889720`** (Opted out of email: Default Greenlogy Blog Subscription): `false` = No; `true` = Yes
- **`hs_email_optout_6904363`** (Opted out of email: Komunikácia so zákazníckymi službami): `false` = No; `true` = Yes
- **`hs_email_optout_7135946`** (Opted out of email: Prihlásenie na odber blogu značky Greenlogy): `false` = No; `true` = Yes
- **`hs_email_optout_9356736`** (Opted out of email: Prihlásenie na odber blogu značky Twinlogy): `false` = No; `true` = Yes

### Dealy (`deals`)

Vlastností spolu: 613 (vlastné 121, HubSpot 492). Záznamov: 15 601.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `faza_obchodu` | Fáza zmluvy | enumeration / select | deal_activity | 7 240 | 46,4 % | 7 možností |
| `aditivny_koeficient_vykup` | Aditívny koeficient výkup | number / number | dealinformation | 0 | 0 % |  |
| `akceptacia_vypovede` | Akceptácia výpovede | enumeration / checkbox | dealinformation | 0 | 0 % | 3 možností |
| `claude_audit` | Claude audit | enumeration / select | dealinformation | 6 186 | 39,7 % | 2 možností |
| `commission_pdf_url` | commission_pdf_url | string / text | dealinformation | 2 | 0 % |  |
| `commission_status_sales_portal` | commission_status_sales_portal | enumeration / select | dealinformation | 1 642 | 10,5 % | 2 možností |
| `commission_updated_date` | commission_updated_date | date / date | dealinformation | 3 | 0 % |  |
| `dovod_ukoncenia_dealu` | Dôvod ukončenia dealu | enumeration / checkbox | dealinformation | 0 | 0 % | 6 možností |
| `email_pre_faktury_b2b` | Email pre faktury (B2B) | string / text | dealinformation | 0 | 0 % |  |
| `email_pre_upomienky_b2b` | Email pre upomienky (B2B) | string / text | dealinformation | 0 | 0 % |  |
| `green_viwa_poplatok_za_rk__pomocny_` | Green VIWA_Poplatok za RK (pomocný) | number / number | dealinformation | 13 313 | 85,3 % |  |
| `nahradene_dealom_id` | Nahradené dealom ID | string / text | dealinformation | 0 | 0 % |  |
| `parovaci_kod_deal_nakupne_ceny` | Párovací kód_Deal_Nákupné ceny | string / text | dealinformation | 2 590 | 16,6 % |  |
| `parovanie_zml_cena_vs__deal__trvanie_zmluvy_` | Párovanie Zml.cena vs. Deal (trvanie zmluvy) | string / text | dealinformation | 794 | 5,1 % |  |
| `pocet_elektroaut` | Počet elektroáut | number / number | dealinformation | 98 | 0,6 % |  |
| `predchadzajuce_cislo_zmluvy` | Predchádzajúce číslo zmluvy | string / text | dealinformation | 0 | 0 % |  |
| `stav_zakazky_fve` | Stav zákazky FVE | enumeration / select | dealinformation | 60 | 0,4 % | 5 možností |
| `typ_viwa_zmluvy` | Typ VIWA zmluvy | enumeration / checkbox | dealinformation | 0 | 0 % | 3 možností |
| `vyska_preddavkovej_platby` | Výška preddavkovej platby | enumeration / select | dealinformation | 97 | 0,6 % | 7 možností |
| `vyuctovane_nepom` | Vyúčtované NEPom | enumeration / select | dealinformation | 33 | 0,2 % | 2 možností |
| `hs_weighted_new_hruba_marza` | HubSpot Weighted new_hruba_marza | number / calculation_equation | dealscripted | 6 493 | 41,6 % | výpočet |
| `hubspot_weighted_new_hruba_marza` | HubSpot Weighted new_hruba_marza | number / calculation_equation | dealscripted | 6 493 | 41,6 % | výpočet |
| `greencar_anoodoslatponuku` | greencar_AnoOdoslatPonuku | enumeration / booleancheckbox | greencar | 1 815 | 11,6 % | 2 možností |
| `greencar_datumodoslaniaemailu` | greencar_DatumOdoslaniaEmailu | date / date | greencar | 1 815 | 11,6 % |  |
| `greencar_hodnota_kuponu_eur` | greencar_hodnota_kuponu_eur | number / number | greencar | 1 815 | 11,6 % |  |
| `greencar_kupon_kod` | greencar_kupon_kod | string / text | greencar | 1 815 | 11,6 % |  |
| `greencar_pocet_kwh` | greencar_pocet_kwh | number / number | greencar | 3 | 0 % |  |
| `celkova_cena_diela__bez_dph` | Celková cena diela (bez DPH) | number / calculation_equation | greensolar | 60 | 0,4 % | výpočet |
| `celkova_cena_diela__bez_dph_` | Celková cena diela (bez DPH)_stare | number / number | greensolar | 8 | 0,1 % |  |
| `celkova_cena_s_dph` | Celková cena (s DPH) | number / number | greensolar | 60 | 0,4 % |  |
| `celkova_vyska_provizie` | Celková výška provízie | number / calculation_equation | greensolar | 60 | 0,4 % | výpočet |
| `cista_provizia_greenlogy__marza_` | Čistá provízia_Greenlogy (marža) | number / calculation_equation | greensolar | 60 | 0,4 % | výpočet |
| `dodatocna_provizia` | Dodatočná provízia-stare | number / number | greensolar | 8 | 0,1 % |  |
| `dodatocna_provizia_new` | Dodatočná provízia | number / calculation_equation | greensolar | 60 | 0,4 % | výpočet |
| `dph` | DPH | number / number | greensolar | 60 | 0,4 % |  |
| `dph_new` | DPH_20-23% | enumeration / select | greensolar | 59 | 0,4 % | 3 možností |
| `obchodnik_nep` | Obchodník_NEP | string / text | greensolar | 75 | 0,5 % |  |
| `program_greensolar` | Program GreenSolar | enumeration / select | greensolar | 59 | 0,4 % | 3 možností |
| `provizia_v__` | Provízia v % | number / number | greensolar | 60 | 0,4 % |  |
| `skutocna_provizia_nep` | Skutočná provízia NEP | number / number | greensolar | 37 | 0,2 % |  |
| `uspora_na_zlave__max__1500_eur_` | Úspora na zľave (max. 1500 EUR) | number / number | greensolar | 60 | 0,4 % |  |
| `zaklad_pre_vypocet_provizie` | Základ pre výpočet provízie | number / calculation_equation | greensolar | 60 | 0,4 % | výpočet |
| `zalohova_platba_60_` | Zálohová platba 60% | number / number | greensolar | 55 | 0,4 % |  |
| `zelena_poukaza___eur` | Zelená poukážka - EUR | number / number | greensolar | 53 | 0,3 % |  |
| `zelena_poukazka___stav_uhrady` | Zelená poukážka - stav úhrady | enumeration / select | greensolar | 51 | 0,3 % | 2 možností |
| `green_viwa___aditiv_konverzie` | Green VIWA - aditív konverzie | enumeration / select | greenviwa | 108 | 0,7 % | 4 možností |
| `green_viwa_poplatok_za_rezervovanu_kapacitu` | Green VIWA_Poplatok za rezervovanú kapacitu | enumeration / select | greenviwa | 108 | 0,7 % | 3 možností |
| `discount` | Referral Discount | number / number | growthdrive | 963 | 6,2 % |  |
| `gwdamount` | Custom Deal Amount | number / number | growthdrive | 2 882 | 18,5 % |  |
| `gwdstatus` | Reward Status | string / text | growthdrive | 552 | 3,5 % |  |
| `gwdtype` | Reward Type | string / text | growthdrive | 553 | 3,5 % |  |
| `reward` | Reward Amount | number / number | growthdrive | 962 | 6,2 % |  |
| `amount_pomocny_z_oom` | Amount_pomocný | number / calculation_equation | kalkulácie | 6 516 | 41,8 % | výpočet |
| `celkovy_objem_vykupu_z_oom__mwh_` | Celkový objem výkupu [MWh] | number / calculation_rollup | kalkulácie | 7 152 | 45,8 % | výpočet |
| `celkovy_objem_z_oom__mwh_` | Celkový objem spotreby [MWh] | number / calculation_rollup | kalkulácie | 6 556 | 42 % | výpočet |
| `celkovy_vykon_v_mw` | Celkový výkon zdrojov v kW | number / calculation_rollup | kalkulácie | 7 152 | 45,8 % | výpočet |
| `celkovy_vynos_zo_zmluvy__komodita_oom_sluzby_` | Celkový výnos zo zmluvy (komodita+OOM+služby) | number / calculation_equation | kalkulácie | 6 554 | 42 % | výpočet |
| `douctovanie_z_nepu` | Doúčtovanie z NEPu | number / number | kalkulácie | 60 | 0,4 % |  |
| `n_kupn_cena` | Nákupná cena | number / number | kalkulácie | 7 754 | 49,7 % |  |
| `new_celkovy_vynos_z_fixov__eur_mwh_` | Celkový výnos z fixov [EUR/MWh] | number / calculation_rollup | kalkulácie | 6 554 | 42 % | výpočet |
| `new_hruba_marza` | Hrubá marža | number / calculation_equation | kalkulácie | 6 493 | 41,6 % | výpočet |
| `new_hruba_marza_pre_vypocet_provizie_gd` | Hrubá marža pre výpočet provízie_Sales portál | number / calculation_equation | kalkulácie | 6 521 | 41,8 % | výpočet |
| `pocet_oom_celkom__dodavka_` | Počet OOM_Celkom (dodávka) | number / calculation_rollup | kalkulácie | 15 601 | 100 % | výpočet |
| `pocet_oom_celkom__spotreba_` | Počet OOM_Celkom (spotreba) | number / calculation_rollup | kalkulácie | 15 601 | 100 % | výpočet |
| `priemerna_hruba_marza_mwh` | Priemerná hrubá marža_MWh | number / calculation_equation | kalkulácie | 5 491 | 35,2 % | výpočet |
| `priemerna_predajna_cena_z_oom` | Priemerná cena na OOM | number / calculation_equation | kalkulácie | 6 402 | 41 % | výpočet |
| `test` | Celkový výnos z elektriny [EUR/MWh] | number / calculation_rollup | kalkulácie | 6 556 | 42 % | výpočet |
| `test_pocet_om` | Počet OOM_Celkom | number / calculation_rollup | kalkulácie | 15 601 | 100 % | výpočet |
| `help__objem_vybrany_z_line_items` | Objem dodávky v MWh_line items | number / calculation_rollup | line_items_verzia | 2 363 | 15,1 % | výpočet |
| `hruba_marza` | Hrubá marža_line items | number / calculation_equation | line_items_verzia | 2 067 | 13,2 % | výpočet |
| `line_items_subtotal` | Line items_subtotal | number / calculation_rollup | line_items_verzia | 2 607 | 16,7 % | výpočet |
| `cislo_zmluvy` | Číslo Greenlogy zmluvy | string / text | obchodn__inform_cie | 6 947 | 44,5 % |  |
| `datum_nakupnej_ceny` | Dátum nákupnej ceny | date / date | obchodn__inform_cie | 7 080 | 45,4 % |  |
| `innos_zmluvy_do` | Účinnosť zmluvy do | date / date | obchodn__inform_cie | 3 849 | 24,7 % |  |
| `innos_zmluvy_od` | Účinnosť zmluvy od | date / date | obchodn__inform_cie | 7 831 | 50,2 % |  |
| `kampan` | Kampaň | enumeration / checkbox | obchodn__inform_cie | 200 | 1,3 % | 8 možností |
| `kontrola_provizie` | Kontrola provízie | enumeration / select | obchodn__inform_cie | 37 | 0,2 % | 2 možností |
| `mhsr` | MHSR | enumeration / booleancheckbox | obchodn__inform_cie | 0 | 0 % | 2 možností |
| `nakupna_tranza` | Nákupná tranža | string / text | obchodn__inform_cie | 5 658 | 36,3 % |  |
| `segment_zakaznika` | Zákaznícky segment | enumeration / checkbox | obchodn__inform_cie | 7 893 | 50,6 % | 3 možností |
| `stav_zmluvy` | Stav zmluvy | enumeration / select | obchodn__inform_cie | 7 566 | 48,5 % | 3 možností |
| `subjekt` | Subjekt | string / text | obchodn__inform_cie | 7 096 | 45,5 % |  |
| `test_cislo_zmluvy` | test číslo zmluvy | string / text | obchodn__inform_cie | 0 | 0 % |  |
| `trvanie_zmluvy` | Trvanie zmluvy | enumeration / checkbox | obchodn__inform_cie | 7 968 | 51,1 % | 10 možností |
| `vypoved_odosiela` | Výpoveď odosiela | enumeration / checkbox | obchodn__inform_cie | 9 | 0,1 % | 2 možností |
| `z_skan_od` | Predošlý dodávateľ | enumeration / checkbox | obchodn__inform_cie | 13 | 0,1 % | 9 možností |
| `zapis_v_trading_sales_book` | Zápis v Trading/sales book | enumeration / booleancheckbox | obchodn__inform_cie | 747 | 4,8 % | 2 možností |
| `naklad_na_odchylku_v_eur_mwh__samostatne_fakturovany_` | Platba za prevzatie zodpovednosti za odchýlku [EUR/MWh] | number / number | quotas_data | 491 | 3,1 % |  |
| `objem_do_ponuky___mwh_` | Objem do ponuky  [MWh] | number / number | quotas_data | 1 218 | 7,8 % |  |
| `planovany_objem_vykupu_v_mwh` | Plánovaný objem výkupu v MWh | number / number | quotas_data | 522 | 3,3 % |  |
| `splatnost_faktur` | Splatnosť faktúr | enumeration / checkbox | quotas_data | 5 033 | 32,3 % | 6 možností |
| `tolerancia_odberu_bez_obmedzeni_a_pokut` | Flexibilita odberu | enumeration / select | quotas_data | 3 900 | 25 % | 6 možností |
| `typ_vyrobneho_zdroja` | Typ výrobného zdroja | enumeration / checkbox | quotas_data | 1 020 | 6,5 % | 8 možností |
| `vykon_zdroja` | Výkon zdroja v MW | number / number | quotas_data | 459 | 2,9 % |  |
| `xml433domacnosti_anoodoslatemail` | XML433Domacnosti_AnoOdoslatEmail | enumeration / booleancheckbox | xml433domacnosti | 3 464 | 22,2 % | 2 možností |
| `xml433domacnosti_datumodoslaniaemailu` | XML433Domacnosti_DatumOdoslaniaEmailu | date / date | xml433domacnosti | 3 464 | 22,2 % |  |
| `xml433domacnosti_datumplastnostik` | XML433Domacnosti_datumplastnostik | date / date | xml433domacnosti | 3 453 | 22,1 % |  |
| `xml433domacnosti_datumspravy` | XML433Domacnosti_datumspravy | date / date | xml433domacnosti | 3 453 | 22,1 % |  |
| `xml433domacnosti_druhodbm` | XML433Domacnosti_druhodbm | string / text | xml433domacnosti | 3 453 | 22,1 % |  |
| `xml433domacnosti_eic` | XML433Domacnosti_eic | string / text | xml433domacnosti | 3 453 | 22,1 % |  |
| `xml433domacnosti_typmerania` | XML433Domacnosti_typmerania | string / text | xml433domacnosti | 3 453 | 22,1 % |  |
| `xml43ddomacnosti_anoodoslatemail` | XML43DDomacnosti_AnoOdoslatEmail | enumeration / booleancheckbox | xml43ddomacnosti | 1 680 | 10,8 % | 2 možností |
| `xml43ddomacnosti_datumodoslaniaemailu` | XML43DDomacnosti_DatumOdoslaniaEmailu | date / date | xml43ddomacnosti | 1 680 | 10,8 % |  |
| `xml43ddomacnosti_datumplastnostik` | XML43DDomacnosti_datumplastnostik | date / date | xml43ddomacnosti | 1 675 | 10,7 % |  |
| `xml43ddomacnosti_datumspravy` | XML43DDomacnosti_datumspravy | date / date | xml43ddomacnosti | 1 675 | 10,7 % |  |
| `xml43ddomacnosti_druhodbm` | XML43DDomacnosti_druhodbm | string / text | xml43ddomacnosti | 1 675 | 10,7 % |  |
| `xml43ddomacnosti_eic` | XML43DDomacnosti_eic | string / text | xml43ddomacnosti | 1 675 | 10,7 % |  |
| `xml43ddomacnosti_typmerania__cloned_` | XML43DDomacnosti_typmerania | string / text | xml43ddomacnosti | 1 675 | 10,7 % |  |
| `xml43dorganizacie_anoodoslatemail` | XML43DOrganizacie_AnoOdoslatEmail | enumeration / booleancheckbox | xml43dorganizacie | 637 | 4,1 % | 2 možností |
| `xml43dorganizacie_datumodoslaniaemailu` | XML43DOrganizacie_DatumOdoslaniaEmailu | date / date | xml43dorganizacie | 637 | 4,1 % |  |
| `xml43dorganizacie_datumplatnostik` | XML43DOrganizacie_datumplatnostik | date / date | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_datumspravy` | XML43DOrganizacie_datumspravy | date / date | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_druhodbm` | XML43DOrganizacie_druhodbm | string / text | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_eic` | XML43DOrganizacie_eic | string / text | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_ico` | XML43DOrganizacie_ico | string / text | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_nazov` | XML43DOrganizacie_nazov | string / text | xml43dorganizacie | 612 | 3,9 % |  |
| `xml43dorganizacie_typmerania` | XML43DOrganizacie_typmerania | string / text | xml43dorganizacie | 612 | 3,9 % |  |
| `cislo_kuponu_greencar` | Číslo kupónu GreenCar | string / text | zrušit | 17 | 0,1 % |  |
| `hodnota_kuponu_greencar` | Hodnota kupónu GreenCar | enumeration / select | zrušit | 17 | 0,1 % | 3 možností |
| `priemerna_predajna_cena` | Priemerná predajná cena_line items | number / calculation_equation | zrušit | 1 641 | 10,5 % | výpočet |
| `sluzba_greencar` | Služba GreenCar | enumeration / booleancheckbox | zrušit | 17 | 0,1 % | 2 možností |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_analytics_latest_source` | Latest Traffic Source | enumeration / calculation_equation | analyticsinformation | 15 214 | 97,5 % | výpočet, 10 možností |
| `hs_analytics_latest_source_company` | Latest Traffic Source Company | enumeration / select | analyticsinformation | 3 531 | 22,6 % | 10 možností |
| `hs_analytics_latest_source_contact` | Latest Traffic Source Contact | enumeration / select | analyticsinformation | 15 135 | 97 % | 10 možností |
| `hs_analytics_latest_source_data_1` | Latest Traffic Source Data 1 | string / text | analyticsinformation | 15 214 | 97,5 % | výpočet |
| `hs_analytics_latest_source_data_1_company` | Latest Traffic Source Data 1 Company | string / text | analyticsinformation | 3 531 | 22,6 % |  |
| `hs_analytics_latest_source_data_1_contact` | Latest Traffic Source Data 1 Contact | string / text | analyticsinformation | 15 135 | 97 % |  |
| `hs_analytics_latest_source_data_2` | Latest Traffic Source Data 2 | string / text | analyticsinformation | 12 093 | 77,5 % | výpočet |
| `hs_analytics_latest_source_data_2_company` | Latest Traffic Source Data 2 Company | string / text | analyticsinformation | 2 939 | 18,8 % |  |
| `hs_analytics_latest_source_data_2_contact` | Latest Traffic Source Data 2 Contact | string / text | analyticsinformation | 12 023 | 77,1 % |  |
| `hs_analytics_latest_source_timestamp` | Latest Traffic Source Timestamp | datetime / number | analyticsinformation | 15 214 | 97,5 % | výpočet |
| `hs_analytics_latest_source_timestamp_company` | Latest Traffic Source Timestamp Company | datetime / date | analyticsinformation | 3 508 | 22,5 % |  |
| `hs_analytics_latest_source_timestamp_contact` | Latest Traffic Source Timestamp Contact | datetime / date | analyticsinformation | 15 135 | 97 % |  |
| `hs_analytics_source` | Original Traffic Source | enumeration / select | analyticsinformation | 15 196 | 97,4 % | 10 možností |
| `hs_analytics_source_data_1` | Original Traffic Source Drill-Down 1 | string / text | analyticsinformation | 15 021 | 96,3 % |  |
| `hs_analytics_source_data_2` | Original Traffic Source Drill-Down 2 | string / text | analyticsinformation | 13 465 | 86,3 % |  |
| `hs_has_last_conversation_follow_ups` | Has Last Conversation Follow Ups | bool / calculation_equation | deal_activity | 2 269 | 14,5 % | výpočet, 2 možností |
| `hs_has_last_meeting_followups` | Has Last Meeting Follow Ups | bool / calculation_equation | deal_activity | 3 059 | 19,6 % | výpočet, 2 možností |
| `hs_is_active_shared_deal` | Is Active Shared Deal | bool / booleancheckbox | deal_activity | 3 473 | 22,3 % | 2 možností |
| `hs_is_closed_lost` | Is closed lost | bool / calculation_equation | deal_activity | 15 601 | 100 % | výpočet, 2 možností |
| `hs_is_closed_won` | Is Closed Won | bool / calculation_equation | deal_activity | 15 601 | 100 % | 2 možností |
| `hs_lastmodifieddate` | Last Modified Date | datetime / date | deal_activity | 15 601 | 100 % |  |
| `hs_num_associated_active_deal_registrations` | Number of Active Deal Registrations | number / number | deal_activity | 15 601 | 100 % | výpočet |
| `hs_num_associated_deal_registrations` | Number of Deal Registrations | number / number | deal_activity | 15 601 | 100 % | výpočet |
| `hs_num_associated_deal_splits` | Number of Deal Splits | number / number | deal_activity | 15 601 | 100 % | výpočet |
| `amount_in_home_currency` | Amount in company currency | number / calculation_equation | dealinformation | 14 565 | 93,4 % | výpočet |
| `closedate` | Close Date | datetime / date | dealinformation | 15 229 | 97,6 % |  |
| `createdate` | Create Date | datetime / date | dealinformation | 15 601 | 100 % |  |
| `days_to_close` | Days to close | number / calculation_equation | dealinformation | 15 601 | 100 % |  |
| `deal_currency_code` | Currency | enumeration / select | dealinformation | 15 566 | 99,8 % |  |
| `engagements_last_meeting_booked` | Date of last meeting booked in meetings tool | datetime / date | dealinformation | 1 | 0 % |  |
| `hs_actual_duration` | Actual duration | number / calculation_equation | dealinformation | 15 215 | 97,5 % | výpočet |
| `hs_acv` | Annual contract value | number / number | dealinformation | 2 607 | 16,7 % | výpočet |
| `hs_all_accessible_team_ids` | All teams | enumeration / select | dealinformation | 6 996 | 44,8 % |  |
| `hs_all_assigned_business_unit_ids` | Brands | enumeration / checkbox | dealinformation | 1 778 | 11,4 % |  |
| `hs_all_collaborator_owner_ids` | Deal Collaborator | enumeration / checkbox | dealinformation | 1 | 0 % |  |
| `hs_all_deal_split_owner_ids` | Deal Split Users | enumeration / checkbox | dealinformation | 8 004 | 51,3 % | výpočet |
| `hs_all_owner_ids` | All owner IDs | enumeration / select | dealinformation | 8 004 | 51,3 % |  |
| `hs_all_team_ids` | All team IDs | enumeration / select | dealinformation | 6 996 | 44,8 % |  |
| `hs_arr` | Annual recurring revenue | number / number | dealinformation | 2 607 | 16,7 % | výpočet |
| `hs_attributed_team_ids` | Attributed reporting team | enumeration / checkbox | dealinformation | 5 518 | 35,4 % |  |
| `hs_closed_amount` | Closed Deal Amount | number / calculation_equation | dealinformation | 15 534 | 99,6 % |  |
| `hs_closed_amount_in_home_currency` | Closed deal amount in home currency | number / calculation_equation | dealinformation | 15 534 | 99,6 % |  |
| `hs_closed_won_count` | Closed won count | number / calculation_equation | dealinformation | 15 601 | 100 % | výpočet |
| `hs_closed_won_date` | Closed Won Date (Internal) | datetime / date | dealinformation | 14 319 | 91,8 % | výpočet |
| `hs_created_by_user_id` | Created by user ID | number / number | dealinformation | 7 324 | 46,9 % |  |
| `hs_createdate` | HubSpot Create Date | datetime / date | dealinformation | 15 601 | 100 % |  |
| `hs_days_to_close_raw` | Days to close (without rounding) | number / calculation_equation | dealinformation | 15 598 | 100 % | výpočet |
| `hs_deal_score` | Deal Score | number / number | dealinformation | 345 | 2,2 % |  |
| `hs_deal_stage_probability` | Deal probability | number / number | dealinformation | 15 601 | 100 % |  |
| `hs_deal_stage_probability_shadow` | Deal stage probability shadow | number / calculation_equation | dealinformation | 15 601 | 100 % |  |
| `hs_exchange_rate` | Exchange rate | number / number | dealinformation | 15 566 | 99,8 % |  |
| `hs_forecast_amount` | Forecast amount | number / number | dealinformation | 14 565 | 93,4 % | výpočet |
| `hs_forecast_probability` | Forecast probability | number / number | dealinformation | 2 576 | 16,5 % |  |
| `hs_is_closed` | Is Deal Closed? | bool / calculation_equation | dealinformation | 15 600 | 100 % | výpočet, 2 možností |
| `hs_is_closed_count` | Is Closed (numeric) | number / calculation_equation | dealinformation | 15 600 | 100 % | výpočet |
| `hs_is_deal_split` | Deal Split Added | bool / calculation_equation | dealinformation | 15 601 | 100 % | 2 možností |
| `hs_is_in_first_deal_stage` | Is In First Deal Stage | bool / booleancheckbox | dealinformation | 13 734 | 88 % | 2 možností |
| `hs_is_open_count` | Is Open (numeric) | number / calculation_equation | dealinformation | 15 600 | 100 % | výpočet |
| `hs_latest_meeting_activity` | Latest meeting activity | datetime / date | dealinformation | 15 | 0,1 % |  |
| `hs_line_item_global_term_recurringbillingfrequency` | Global Term Line Item Recurring Billing Frequency | string / text | dealinformation | 1 | 0 % |  |
| `hs_manual_forecast_category` | Forecast category | enumeration / select | dealinformation | 8 024 | 51,4 % | 5 možností |
| `hs_merged_object_ids` | Merged Deal IDs | enumeration / checkbox | dealinformation | 11 | 0,1 % |  |
| `hs_mrr` | Monthly recurring revenue | number / number | dealinformation | 2 607 | 16,7 % | výpočet |
| `hs_next_step` | Next step | string / textarea | dealinformation | 6 | 0 % |  |
| `hs_next_step_updated_at` | Next Step Updated At | datetime / calculation_equation | dealinformation | 4 | 0 % | výpočet |
| `hs_notes_last_activity` | Last Activity | object_coordinates / text | dealinformation | 2 027 | 13 % |  |
| `hs_num_of_associated_line_items` | Number of Associated Line Items | number / number | dealinformation | 15 601 | 100 % | výpočet |
| `hs_num_target_accounts` | Number of target accounts | number / number | dealinformation | 15 601 | 100 % |  |
| `hs_object_id` | Record ID | number / number | dealinformation | 15 601 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | dealinformation | 15 601 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | dealinformation | 11 385 | 73 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | dealinformation | 596 | 3,8 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | dealinformation | 15 599 | 100 % |  |
| `hs_object_source_label` | Record source | enumeration / select | dealinformation | 15 601 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | dealinformation | 7 324 | 46,9 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | dealinformation | 6 996 | 44,8 % |  |
| `hs_pinned_engagement_id` | Pinned Engagement ID | number / number | dealinformation | 6 | 0 % |  |
| `hs_primary_associated_company` | Primary Associated Company | number / calculation_rollup | dealinformation | 3 860 | 24,7 % |  |
| `hs_projected_amount` | Weighted amount | number / calculation_equation | dealinformation | 14 565 | 93,4 % |  |
| `hs_projected_amount_in_home_currency` | Weighted amount in company currency | number / calculation_equation | dealinformation | 14 565 | 93,4 % |  |
| `hs_sales_email_last_replied` | Recent Sales Email Replied Date | datetime / date | dealinformation | 1 106 | 7,1 % |  |
| `hs_tcv` | Total contract value | number / number | dealinformation | 2 607 | 16,7 % | výpočet |
| `hs_unique_creation_key` | Unique creation key | string / text | dealinformation | 1 309 | 8,4 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | dealinformation | 13 559 | 86,9 % |  |
| `hs_user_ids_of_all_notification_recipients` | All deal notification recipients | enumeration / checkbox | dealinformation | 8 004 | 51,3 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | dealinformation | 8 004 | 51,3 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | dealinformation | 5 419 | 34,7 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | dealinformation | 8 004 | 51,3 % |  |
| `hubspot_team_id` | HubSpot Team | enumeration / select | dealinformation | 6 996 | 44,8 % |  |
| `notes_last_contacted` | Last Contacted | datetime / date | dealinformation | 1 720 | 11 % |  |
| `notes_last_updated` | Last Activity Date | datetime / date | dealinformation | 2 027 | 13 % |  |
| `num_associated_contacts` | Number of Associated Contacts | number / calculation_rollup | dealinformation | 15 601 | 100 % | výpočet |
| `num_contacted_notes` | Number of times contacted | number / number | dealinformation | 2 029 | 13 % |  |
| `num_notes` | Number of Sales Activities | number / number | dealinformation | 9 289 | 59,5 % |  |
| `hs_average_deal_owner_duration_in_current_stage` | Average Deal Owner Duration In Current Stage | number / number | dealscripted | 315 | 2 % |  |
| `hs_closed_deal_close_date` | Closed Deal Close Date | number / calculation_equation | dealscripted | 15 591 | 99,9 % | výpočet |
| `hs_closed_deal_create_date` | Closed Deal Create Date | number / calculation_equation | dealscripted | 15 591 | 99,9 % | výpočet |
| `hs_is_stalled` | Is Stalled | bool / calculation_equation | dealscripted | 3 494 | 22,4 % | 2 možností |
| `hs_is_stalled_after_timestamp` | Is Stalled After Timestamp | datetime / date | dealscripted | 315 | 2 % |  |
| `hs_open_deal_create_date` | Open deal create date | number / calculation_equation | dealscripted | 15 600 | 100 % | výpočet |
| `hs_v2_cumulative_time_in_1026837897` | Cumulative time in "Objednávka (EFET_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_1026837901` | Cumulative time in "Closed Won (EFET_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_1031520383` | Cumulative time in "Zmluvy_2028 (B2B_elektrina)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_1036963710` | Cumulative time in "Zmluvy_neurčito (B2C_elektrina)" | number / number | dealstages | 126 | 0,8 % |  |
| `hs_v2_cumulative_time_in_1036970423` | Cumulative time in "Zmluvy_neurčito (B2B_výkup elektriny)" | number / number | dealstages | 75 | 0,5 % |  |
| `hs_v2_cumulative_time_in_1037603880` | Cumulative time in "Zmluva_2025 (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_1037603881` | Cumulative time in "Zmluva_2026 (GreenSolar)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_1037611791` | Cumulative time in "Zmluva_2024 (GreenSolar)" | number / number | dealstages | 2 | 0 % |  |
| `hs_v2_cumulative_time_in_1165493892` | Cumulative time in "Cenová ponuka (Green VIWA_B2B)" | number / number | dealstages | 40 | 0,3 % |  |
| `hs_v2_cumulative_time_in_1165493893` | Cumulative time in "Akceptácia/Rozpracovaná zmluva (Green VIWA_B2B)" | number / number | dealstages | 17 | 0,1 % |  |
| `hs_v2_cumulative_time_in_1165493894` | Cumulative time in "Zmluvy_neurčito (Green VIWA_B2B)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_cumulative_time_in_1165493897` | Cumulative time in "Neúspech (Green VIWA_B2B)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_1213762845` | Cumulative time in "Zmluvy_2027 (B2B_výkup elektriny)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_130300546` | Cumulative time in "Cenová ponuka (B2B_výkup elektriny)" | number / number | dealstages | 362 | 2,3 % |  |
| `hs_v2_cumulative_time_in_130300547` | Cumulative time in "Akceptácia/Rozpracovaná zmluva (B2B_výkup elektriny)" | number / number | dealstages | 192 | 1,2 % |  |
| `hs_v2_cumulative_time_in_130300551` | Cumulative time in "Neúspech (B2B_výkup elektriny)" | number / number | dealstages | 105 | 0,7 % |  |
| `hs_v2_cumulative_time_in_130360420` | Cumulative time in "Ukončená (B2B_výkup elektriny)" | number / number | dealstages | 33 | 0,2 % |  |
| `hs_v2_cumulative_time_in_1310450690` | Cumulative time in "EFET_2027 (EFET_elektrina)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_1373177381` | Cumulative time in "Zmluva_neúplná (B2C_elektrina)" | number / number | dealstages | 42 | 0,3 % |  |
| `hs_v2_cumulative_time_in_144330920` | Cumulative time in "Ukončená (B2B_elektrina)" | number / number | dealstages | 7 | 0 % |  |
| `hs_v2_cumulative_time_in_144537899` | Cumulative time in "Ukončená (B2C_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_144577400` | Cumulative time in "Akceptácia/Rozpracovaná zmluva (B2B_elektrina)" | number / number | dealstages | 212 | 1,4 % |  |
| `hs_v2_cumulative_time_in_147171988` | Cumulative time in "Akceptácia/Rozpracovaná zmluva (B2C_elektrina)" | number / number | dealstages | 16 | 0,1 % |  |
| `hs_v2_cumulative_time_in_147171989` | Cumulative time in "Príležitosť (B2B_výkup elektriny)" | number / number | dealstages | 298 | 1,9 % |  |
| `hs_v2_cumulative_time_in_152706457` | Cumulative time in "Zmluvy_2024 (B2B_elektrina)" | number / number | dealstages | 80 | 0,5 % |  |
| `hs_v2_cumulative_time_in_152706458` | Cumulative time in "Zmluvy_2025 (B2B_elektrina)" | number / number | dealstages | 126 | 0,8 % |  |
| `hs_v2_cumulative_time_in_152706459` | Cumulative time in "Zmluvy_2026 (B2B_elektrina)" | number / number | dealstages | 66 | 0,4 % |  |
| `hs_v2_cumulative_time_in_152722253` | Cumulative time in "Zmluvy_2024 (B2B_výkup elektriny)" | number / number | dealstages | 513 | 3,3 % |  |
| `hs_v2_cumulative_time_in_152722254` | Cumulative time in "Zmluvy_2025 (B2B_výkup elektriny)" | number / number | dealstages | 113 | 0,7 % |  |
| `hs_v2_cumulative_time_in_152722255` | Cumulative time in "Zmluvy_2026 (B2B_výkup elektriny)" | number / number | dealstages | 2 | 0 % |  |
| `hs_v2_cumulative_time_in_152728100` | Cumulative time in "Zmluvy_2024 (B2C_elektrina)" | number / number | dealstages | 1 327 | 8,5 % |  |
| `hs_v2_cumulative_time_in_152728101` | Cumulative time in "Zmluvy_2025 (B2C_elektrina)" | number / number | dealstages | 2 484 | 15,9 % |  |
| `hs_v2_cumulative_time_in_152728102` | Cumulative time in "Zmluvy_2026 (B2C_elektrina)" | number / number | dealstages | 6 | 0 % |  |
| `hs_v2_cumulative_time_in_152779939` | Cumulative time in "Zmluvy_2027 (B2B_elektrina)" | number / number | dealstages | 8 | 0,1 % |  |
| `hs_v2_cumulative_time_in_193271659` | Cumulative time in "Vyjednávanie (B2B_výkup elektriny)" | number / number | dealstages | 39 | 0,2 % |  |
| `hs_v2_cumulative_time_in_2105412` | Cumulative time in "Príležitosť (B2C_elektrina)" | number / number | dealstages | 77 | 0,5 % |  |
| `hs_v2_cumulative_time_in_2105413` | Cumulative time in "Cenová ponuka (B2C_elektrina)" | number / number | dealstages | 57 | 0,4 % |  |
| `hs_v2_cumulative_time_in_2105417` | Cumulative time in "Úspech_XML (B2C_elektrina)" | number / number | dealstages | 817 | 5,2 % |  |
| `hs_v2_cumulative_time_in_2105418` | Cumulative time in "Neúspech (B2C_elektrina)" | number / number | dealstages | 10 | 0,1 % |  |
| `hs_v2_cumulative_time_in_2107990` | Cumulative time in "Zmenový proces neúspešný - technický problém (B2C_elektrina)" | number / number | dealstages | 8 | 0,1 % |  |
| `hs_v2_cumulative_time_in_24250897` | Cumulative time in "Dopyt (GreenSolar)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_cumulative_time_in_24250899` | Cumulative time in "Cenová ponuka_akceptovaná (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_24250901` | Cumulative time in "Uhradená záloha (GreenSolar)" | number / number | dealstages | 9 | 0,1 % |  |
| `hs_v2_cumulative_time_in_24250902` | Cumulative time in "Dielo zrealizované a prevzaté (GreenSolar)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_60256333` | Cumulative time in "Zmluva doručená (Greenlogy_B2C_služby)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_60256335` | Cumulative time in "Úspech (Greenlogy_B2C_služby)" | number / number | dealstages | 20 | 0,1 % |  |
| `hs_v2_cumulative_time_in_60435043` | Cumulative time in "Čakáme na zaradenie PDS (Greenlogy_B2C_služby)" | number / number | dealstages | 43 | 0,3 % |  |
| `hs_v2_cumulative_time_in_641523` | Cumulative time in "Príležitosť (B2B_elektrina)" | number / number | dealstages | 141 | 0,9 % |  |
| `hs_v2_cumulative_time_in_641525` | Cumulative time in "Neúspech (B2B_elektrina)" | number / number | dealstages | 13 | 0,1 % |  |
| `hs_v2_cumulative_time_in_641527` | Cumulative time in "Cenová ponuka (B2B_elektrina)" | number / number | dealstages | 767 | 4,9 % |  |
| `hs_v2_cumulative_time_in_73644134` | Cumulative time in "Notifikačný email (Greenlogy_B2C_služby)" | number / number | dealstages | 225 | 1,4 % |  |
| `hs_v2_cumulative_time_in_741794` | Cumulative time in "Výpoveď neakceptovaná (B2B_elektrina)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_970090121` | Cumulative time in "Dielo uhradené (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_997673` | Cumulative time in "Zmenový proces neúspešný - technický problém (B2B_elektrina)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_date_entered_1026837897` | Date entered "Objednávka (EFET_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_entered_1026837901` | Date entered "Closed Won (EFET_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_entered_1031520383` | Date entered "Zmluvy_2028 (B2B_elektrina)" | datetime / date | dealstages | 53 | 0,3 % |  |
| `hs_v2_date_entered_1036963710` | Date entered "Zmluvy_neurčito (B2C_elektrina)" | datetime / date | dealstages | 3 881 | 24,9 % |  |
| `hs_v2_date_entered_1036970423` | Date entered "Zmluvy_neurčito (B2B_výkup elektriny)" | datetime / date | dealstages | 746 | 4,8 % |  |
| `hs_v2_date_entered_1037487976` | Date entered "EFET_2025 (EFET_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_entered_1037487977` | Date entered "EFET_2026 (EFET_elektrina)" | datetime / date | dealstages | 8 | 0,1 % |  |
| `hs_v2_date_entered_1037603880` | Date entered "Zmluva_2025 (GreenSolar)" | datetime / date | dealstages | 37 | 0,2 % |  |
| `hs_v2_date_entered_1037603881` | Date entered "Zmluva_2026 (GreenSolar)" | datetime / date | dealstages | 24 | 0,2 % |  |
| `hs_v2_date_entered_1037611791` | Date entered "Zmluva_2024 (GreenSolar)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_entered_1165493892` | Date entered "Cenová ponuka (Green VIWA_B2B)" | datetime / date | dealstages | 85 | 0,5 % |  |
| `hs_v2_date_entered_1165493893` | Date entered "Akceptácia/Rozpracovaná zmluva (Green VIWA_B2B)" | datetime / date | dealstages | 17 | 0,1 % |  |
| `hs_v2_date_entered_1165493894` | Date entered "Zmluvy_neurčito (Green VIWA_B2B)" | datetime / date | dealstages | 56 | 0,4 % |  |
| `hs_v2_date_entered_1165493897` | Date entered "Neúspech (Green VIWA_B2B)" | datetime / date | dealstages | 14 | 0,1 % |  |
| `hs_v2_date_entered_1213762845` | Date entered "Zmluvy_2027 (B2B_výkup elektriny)" | datetime / date | dealstages | 23 | 0,1 % |  |
| `hs_v2_date_entered_1213762846` | Date entered "Zmluvy_2028 (B2B_výkup elektriny)" | datetime / date | dealstages | 2 | 0 % |  |
| `hs_v2_date_entered_130300546` | Date entered "Cenová ponuka (B2B_výkup elektriny)" | datetime / date | dealstages | 366 | 2,3 % |  |
| `hs_v2_date_entered_130300547` | Date entered "Akceptácia/Rozpracovaná zmluva (B2B_výkup elektriny)" | datetime / date | dealstages | 213 | 1,4 % |  |
| `hs_v2_date_entered_130300551` | Date entered "Neúspech (B2B_výkup elektriny)" | datetime / date | dealstages | 453 | 2,9 % |  |
| `hs_v2_date_entered_130360420` | Date entered "Ukončená (B2B_výkup elektriny)" | datetime / date | dealstages | 102 | 0,7 % |  |
| `hs_v2_date_entered_1310450690` | Date entered "EFET_2027 (EFET_elektrina)" | datetime / date | dealstages | 6 | 0 % |  |
| `hs_v2_date_entered_1346481045` | Date entered "Zmluvy_2029 (B2B_elektrina)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_entered_1373177381` | Date entered "Zmluva_neúplná (B2C_elektrina)" | datetime / date | dealstages | 119 | 0,8 % |  |
| `hs_v2_date_entered_144330920` | Date entered "Ukončená (B2B_elektrina)" | datetime / date | dealstages | 56 | 0,4 % |  |
| `hs_v2_date_entered_144537899` | Date entered "Ukončená (B2C_elektrina)" | datetime / date | dealstages | 9 | 0,1 % |  |
| `hs_v2_date_entered_144577400` | Date entered "Akceptácia/Rozpracovaná zmluva (B2B_elektrina)" | datetime / date | dealstages | 222 | 1,4 % |  |
| `hs_v2_date_entered_147171988` | Date entered "Akceptácia/Rozpracovaná zmluva (B2C_elektrina)" | datetime / date | dealstages | 16 | 0,1 % |  |
| `hs_v2_date_entered_147171989` | Date entered "Príležitosť (B2B_výkup elektriny)" | datetime / date | dealstages | 336 | 2,2 % |  |
| `hs_v2_date_entered_152706457` | Date entered "Zmluvy_2024 (B2B_elektrina)" | datetime / date | dealstages | 409 | 2,6 % |  |
| `hs_v2_date_entered_152706458` | Date entered "Zmluvy_2025 (B2B_elektrina)" | datetime / date | dealstages | 623 | 4 % |  |
| `hs_v2_date_entered_152706459` | Date entered "Zmluvy_2026 (B2B_elektrina)" | datetime / date | dealstages | 664 | 4,3 % |  |
| `hs_v2_date_entered_152722253` | Date entered "Zmluvy_2024 (B2B_výkup elektriny)" | datetime / date | dealstages | 537 | 3,4 % |  |
| `hs_v2_date_entered_152722254` | Date entered "Zmluvy_2025 (B2B_výkup elektriny)" | datetime / date | dealstages | 154 | 1 % |  |
| `hs_v2_date_entered_152722255` | Date entered "Zmluvy_2026 (B2B_výkup elektriny)" | datetime / date | dealstages | 69 | 0,4 % |  |
| `hs_v2_date_entered_152728100` | Date entered "Zmluvy_2024 (B2C_elektrina)" | datetime / date | dealstages | 1 329 | 8,5 % |  |
| `hs_v2_date_entered_152728101` | Date entered "Zmluvy_2025 (B2C_elektrina)" | datetime / date | dealstages | 2 486 | 15,9 % |  |
| `hs_v2_date_entered_152728102` | Date entered "Zmluvy_2026 (B2C_elektrina)" | datetime / date | dealstages | 6 | 0 % |  |
| `hs_v2_date_entered_152779939` | Date entered "Zmluvy_2027 (B2B_elektrina)" | datetime / date | dealstages | 362 | 2,3 % |  |
| `hs_v2_date_entered_193271659` | Date entered "Vyjednávanie (B2B_výkup elektriny)" | datetime / date | dealstages | 48 | 0,3 % |  |
| `hs_v2_date_entered_2105412` | Date entered "Príležitosť (B2C_elektrina)" | datetime / date | dealstages | 78 | 0,5 % |  |
| `hs_v2_date_entered_2105413` | Date entered "Cenová ponuka (B2C_elektrina)" | datetime / date | dealstages | 57 | 0,4 % |  |
| `hs_v2_date_entered_2105417` | Date entered "Úspech_XML (B2C_elektrina)" | datetime / date | dealstages | 1 042 | 6,7 % |  |
| `hs_v2_date_entered_2105418` | Date entered "Neúspech (B2C_elektrina)" | datetime / date | dealstages | 10 | 0,1 % |  |
| `hs_v2_date_entered_2107990` | Date entered "Zmenový proces neúspešný - technický problém (B2C_elektrina)" | datetime / date | dealstages | 8 | 0,1 % |  |
| `hs_v2_date_entered_24250897` | Date entered "Dopyt (GreenSolar)" | datetime / date | dealstages | 5 | 0 % |  |
| `hs_v2_date_entered_24250899` | Date entered "Cenová ponuka_akceptovaná (GreenSolar)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_entered_24250901` | Date entered "Uhradená záloha (GreenSolar)" | datetime / date | dealstages | 9 | 0,1 % |  |
| `hs_v2_date_entered_24250902` | Date entered "Dielo zrealizované a prevzaté (GreenSolar)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_entered_24250903` | Date entered "Closed lost (GreenSolar)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_entered_60256331` | Date entered "Cenová ponuka (Greenlogy_B2C_služby)" | datetime / date | dealstages | 2 | 0 % |  |
| `hs_v2_date_entered_60256333` | Date entered "Zmluva doručená (Greenlogy_B2C_služby)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_entered_60256335` | Date entered "Úspech (Greenlogy_B2C_služby)" | datetime / date | dealstages | 35 | 0,2 % |  |
| `hs_v2_date_entered_60435043` | Date entered "Čakáme na zaradenie PDS (Greenlogy_B2C_služby)" | datetime / date | dealstages | 43 | 0,3 % |  |
| `hs_v2_date_entered_641523` | Date entered "Príležitosť (B2B_elektrina)" | datetime / date | dealstages | 215 | 1,4 % |  |
| `hs_v2_date_entered_641525` | Date entered "Neúspech (B2B_elektrina)" | datetime / date | dealstages | 398 | 2,6 % |  |
| `hs_v2_date_entered_641527` | Date entered "Cenová ponuka (B2B_elektrina)" | datetime / date | dealstages | 915 | 5,9 % |  |
| `hs_v2_date_entered_73644134` | Date entered "Notifikačný email (Greenlogy_B2C_služby)" | datetime / date | dealstages | 7 595 | 48,7 % |  |
| `hs_v2_date_entered_741794` | Date entered "Výpoveď neakceptovaná (B2B_elektrina)" | datetime / date | dealstages | 15 | 0,1 % |  |
| `hs_v2_date_entered_970090121` | Date entered "Dielo uhradené (GreenSolar)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_entered_997673` | Date entered "Zmenový proces neúspešný - technický problém (B2B_elektrina)" | datetime / date | dealstages | 19 | 0,1 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | dealstages | 15 600 | 100 % | výpočet |
| `hs_v2_date_exited_1026837897` | Date exited "Objednávka (EFET_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_1026837901` | Date exited "Closed Won (EFET_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_1031520383` | Date exited "Zmluvy_2028 (B2B_elektrina)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_exited_1036963710` | Date exited "Zmluvy_neurčito (B2C_elektrina)" | datetime / date | dealstages | 126 | 0,8 % |  |
| `hs_v2_date_exited_1036970423` | Date exited "Zmluvy_neurčito (B2B_výkup elektriny)" | datetime / date | dealstages | 75 | 0,5 % |  |
| `hs_v2_date_exited_1037603880` | Date exited "Zmluva_2025 (GreenSolar)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_1037603881` | Date exited "Zmluva_2026 (GreenSolar)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_exited_1037611791` | Date exited "Zmluva_2024 (GreenSolar)" | datetime / date | dealstages | 2 | 0 % |  |
| `hs_v2_date_exited_1165493892` | Date exited "Cenová ponuka (Green VIWA_B2B)" | datetime / date | dealstages | 40 | 0,3 % |  |
| `hs_v2_date_exited_1165493893` | Date exited "Akceptácia/Rozpracovaná zmluva (Green VIWA_B2B)" | datetime / date | dealstages | 17 | 0,1 % |  |
| `hs_v2_date_exited_1165493894` | Date exited "Zmluvy_neurčito (Green VIWA_B2B)" | datetime / date | dealstages | 5 | 0 % |  |
| `hs_v2_date_exited_1165493897` | Date exited "Neúspech (Green VIWA_B2B)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_1213762845` | Date exited "Zmluvy_2027 (B2B_výkup elektriny)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_exited_130300546` | Date exited "Cenová ponuka (B2B_výkup elektriny)" | datetime / date | dealstages | 362 | 2,3 % |  |
| `hs_v2_date_exited_130300547` | Date exited "Akceptácia/Rozpracovaná zmluva (B2B_výkup elektriny)" | datetime / date | dealstages | 192 | 1,2 % |  |
| `hs_v2_date_exited_130300551` | Date exited "Neúspech (B2B_výkup elektriny)" | datetime / date | dealstages | 105 | 0,7 % |  |
| `hs_v2_date_exited_130360420` | Date exited "Ukončená (B2B_výkup elektriny)" | datetime / date | dealstages | 33 | 0,2 % |  |
| `hs_v2_date_exited_1310450690` | Date exited "EFET_2027 (EFET_elektrina)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_exited_1373177381` | Date exited "Zmluva_neúplná (B2C_elektrina)" | datetime / date | dealstages | 42 | 0,3 % |  |
| `hs_v2_date_exited_144330920` | Date exited "Ukončená (B2B_elektrina)" | datetime / date | dealstages | 7 | 0 % |  |
| `hs_v2_date_exited_144537899` | Date exited "Ukončená (B2C_elektrina)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_144577400` | Date exited "Akceptácia/Rozpracovaná zmluva (B2B_elektrina)" | datetime / date | dealstages | 212 | 1,4 % |  |
| `hs_v2_date_exited_147171988` | Date exited "Akceptácia/Rozpracovaná zmluva (B2C_elektrina)" | datetime / date | dealstages | 16 | 0,1 % |  |
| `hs_v2_date_exited_147171989` | Date exited "Príležitosť (B2B_výkup elektriny)" | datetime / date | dealstages | 298 | 1,9 % |  |
| `hs_v2_date_exited_152706457` | Date exited "Zmluvy_2024 (B2B_elektrina)" | datetime / date | dealstages | 80 | 0,5 % |  |
| `hs_v2_date_exited_152706458` | Date exited "Zmluvy_2025 (B2B_elektrina)" | datetime / date | dealstages | 126 | 0,8 % |  |
| `hs_v2_date_exited_152706459` | Date exited "Zmluvy_2026 (B2B_elektrina)" | datetime / date | dealstages | 66 | 0,4 % |  |
| `hs_v2_date_exited_152722253` | Date exited "Zmluvy_2024 (B2B_výkup elektriny)" | datetime / date | dealstages | 513 | 3,3 % |  |
| `hs_v2_date_exited_152722254` | Date exited "Zmluvy_2025 (B2B_výkup elektriny)" | datetime / date | dealstages | 113 | 0,7 % |  |
| `hs_v2_date_exited_152722255` | Date exited "Zmluvy_2026 (B2B_výkup elektriny)" | datetime / date | dealstages | 2 | 0 % |  |
| `hs_v2_date_exited_152728100` | Date exited "Zmluvy_2024 (B2C_elektrina)" | datetime / date | dealstages | 1 327 | 8,5 % |  |
| `hs_v2_date_exited_152728101` | Date exited "Zmluvy_2025 (B2C_elektrina)" | datetime / date | dealstages | 2 484 | 15,9 % |  |
| `hs_v2_date_exited_152728102` | Date exited "Zmluvy_2026 (B2C_elektrina)" | datetime / date | dealstages | 6 | 0 % |  |
| `hs_v2_date_exited_152779939` | Date exited "Zmluvy_2027 (B2B_elektrina)" | datetime / date | dealstages | 8 | 0,1 % |  |
| `hs_v2_date_exited_193271659` | Date exited "Vyjednávanie (B2B_výkup elektriny)" | datetime / date | dealstages | 39 | 0,2 % |  |
| `hs_v2_date_exited_2105412` | Date exited "Príležitosť (B2C_elektrina)" | datetime / date | dealstages | 77 | 0,5 % |  |
| `hs_v2_date_exited_2105413` | Date exited "Cenová ponuka (B2C_elektrina)" | datetime / date | dealstages | 57 | 0,4 % |  |
| `hs_v2_date_exited_2105417` | Date exited "Úspech_XML (B2C_elektrina)" | datetime / date | dealstages | 817 | 5,2 % |  |
| `hs_v2_date_exited_2105418` | Date exited "Neúspech (B2C_elektrina)" | datetime / date | dealstages | 10 | 0,1 % |  |
| `hs_v2_date_exited_2107990` | Date exited "Zmenový proces neúspešný - technický problém (B2C_elektrina)" | datetime / date | dealstages | 8 | 0,1 % |  |
| `hs_v2_date_exited_24250897` | Date exited "Dopyt (GreenSolar)" | datetime / date | dealstages | 5 | 0 % |  |
| `hs_v2_date_exited_24250899` | Date exited "Cenová ponuka_akceptovaná (GreenSolar)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_24250901` | Date exited "Uhradená záloha (GreenSolar)" | datetime / date | dealstages | 9 | 0,1 % |  |
| `hs_v2_date_exited_24250902` | Date exited "Dielo zrealizované a prevzaté (GreenSolar)" | datetime / date | dealstages | 3 | 0 % |  |
| `hs_v2_date_exited_60256333` | Date exited "Zmluva doručená (Greenlogy_B2C_služby)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_exited_60256335` | Date exited "Úspech (Greenlogy_B2C_služby)" | datetime / date | dealstages | 20 | 0,1 % |  |
| `hs_v2_date_exited_60435043` | Date exited "Čakáme na zaradenie PDS (Greenlogy_B2C_služby)" | datetime / date | dealstages | 43 | 0,3 % |  |
| `hs_v2_date_exited_641523` | Date exited "Príležitosť (B2B_elektrina)" | datetime / date | dealstages | 141 | 0,9 % |  |
| `hs_v2_date_exited_641525` | Date exited "Neúspech (B2B_elektrina)" | datetime / date | dealstages | 13 | 0,1 % |  |
| `hs_v2_date_exited_641527` | Date exited "Cenová ponuka (B2B_elektrina)" | datetime / date | dealstages | 767 | 4,9 % |  |
| `hs_v2_date_exited_73644134` | Date exited "Notifikačný email (Greenlogy_B2C_služby)" | datetime / date | dealstages | 225 | 1,4 % |  |
| `hs_v2_date_exited_741794` | Date exited "Výpoveď neakceptovaná (B2B_elektrina)" | datetime / date | dealstages | 1 | 0 % |  |
| `hs_v2_date_exited_970090121` | Date exited "Dielo uhradené (GreenSolar)" | datetime / date | dealstages | 4 | 0 % |  |
| `hs_v2_date_exited_997673` | Date exited "Zmenový proces neúspešný - technický problém (B2B_elektrina)" | datetime / date | dealstages | 5 | 0 % |  |
| `hs_v2_latest_time_in_1026837897` | Latest time in "Objednávka (EFET_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_1026837901` | Latest time in "Closed Won (EFET_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_1031520383` | Latest time in "Zmluvy_2028 (B2B_elektrina)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_1036963710` | Latest time in "Zmluvy_neurčito (B2C_elektrina)" | number / number | dealstages | 126 | 0,8 % |  |
| `hs_v2_latest_time_in_1036970423` | Latest time in "Zmluvy_neurčito (B2B_výkup elektriny)" | number / number | dealstages | 75 | 0,5 % |  |
| `hs_v2_latest_time_in_1037603880` | Latest time in "Zmluva_2025 (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_1037603881` | Latest time in "Zmluva_2026 (GreenSolar)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_1037611791` | Latest time in "Zmluva_2024 (GreenSolar)" | number / number | dealstages | 2 | 0 % |  |
| `hs_v2_latest_time_in_1165493892` | Latest time in "Cenová ponuka (Green VIWA_B2B)" | number / number | dealstages | 40 | 0,3 % |  |
| `hs_v2_latest_time_in_1165493893` | Latest time in "Akceptácia/Rozpracovaná zmluva (Green VIWA_B2B)" | number / number | dealstages | 17 | 0,1 % |  |
| `hs_v2_latest_time_in_1165493894` | Latest time in "Zmluvy_neurčito (Green VIWA_B2B)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_latest_time_in_1165493897` | Latest time in "Neúspech (Green VIWA_B2B)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_1213762845` | Latest time in "Zmluvy_2027 (B2B_výkup elektriny)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_130300546` | Latest time in "Cenová ponuka (B2B_výkup elektriny)" | number / number | dealstages | 362 | 2,3 % |  |
| `hs_v2_latest_time_in_130300547` | Latest time in "Akceptácia/Rozpracovaná zmluva (B2B_výkup elektriny)" | number / number | dealstages | 192 | 1,2 % |  |
| `hs_v2_latest_time_in_130300551` | Latest time in "Neúspech (B2B_výkup elektriny)" | number / number | dealstages | 105 | 0,7 % |  |
| `hs_v2_latest_time_in_130360420` | Latest time in "Ukončená (B2B_výkup elektriny)" | number / number | dealstages | 33 | 0,2 % |  |
| `hs_v2_latest_time_in_1310450690` | Latest time in "EFET_2027 (EFET_elektrina)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_1373177381` | Latest time in "Zmluva_neúplná (B2C_elektrina)" | number / number | dealstages | 42 | 0,3 % |  |
| `hs_v2_latest_time_in_144330920` | Latest time in "Ukončená (B2B_elektrina)" | number / number | dealstages | 7 | 0 % |  |
| `hs_v2_latest_time_in_144537899` | Latest time in "Ukončená (B2C_elektrina)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_144577400` | Latest time in "Akceptácia/Rozpracovaná zmluva (B2B_elektrina)" | number / number | dealstages | 212 | 1,4 % |  |
| `hs_v2_latest_time_in_147171988` | Latest time in "Akceptácia/Rozpracovaná zmluva (B2C_elektrina)" | number / number | dealstages | 16 | 0,1 % |  |
| `hs_v2_latest_time_in_147171989` | Latest time in "Príležitosť (B2B_výkup elektriny)" | number / number | dealstages | 298 | 1,9 % |  |
| `hs_v2_latest_time_in_152706457` | Latest time in "Zmluvy_2024 (B2B_elektrina)" | number / number | dealstages | 80 | 0,5 % |  |
| `hs_v2_latest_time_in_152706458` | Latest time in "Zmluvy_2025 (B2B_elektrina)" | number / number | dealstages | 126 | 0,8 % |  |
| `hs_v2_latest_time_in_152706459` | Latest time in "Zmluvy_2026 (B2B_elektrina)" | number / number | dealstages | 66 | 0,4 % |  |
| `hs_v2_latest_time_in_152722253` | Latest time in "Zmluvy_2024 (B2B_výkup elektriny)" | number / number | dealstages | 513 | 3,3 % |  |
| `hs_v2_latest_time_in_152722254` | Latest time in "Zmluvy_2025 (B2B_výkup elektriny)" | number / number | dealstages | 113 | 0,7 % |  |
| `hs_v2_latest_time_in_152722255` | Latest time in "Zmluvy_2026 (B2B_výkup elektriny)" | number / number | dealstages | 2 | 0 % |  |
| `hs_v2_latest_time_in_152728100` | Latest time in "Zmluvy_2024 (B2C_elektrina)" | number / number | dealstages | 1 327 | 8,5 % |  |
| `hs_v2_latest_time_in_152728101` | Latest time in "Zmluvy_2025 (B2C_elektrina)" | number / number | dealstages | 2 484 | 15,9 % |  |
| `hs_v2_latest_time_in_152728102` | Latest time in "Zmluvy_2026 (B2C_elektrina)" | number / number | dealstages | 6 | 0 % |  |
| `hs_v2_latest_time_in_152779939` | Latest time in "Zmluvy_2027 (B2B_elektrina)" | number / number | dealstages | 8 | 0,1 % |  |
| `hs_v2_latest_time_in_193271659` | Latest time in "Vyjednávanie (B2B_výkup elektriny)" | number / number | dealstages | 39 | 0,2 % |  |
| `hs_v2_latest_time_in_2105412` | Latest time in "Príležitosť (B2C_elektrina)" | number / number | dealstages | 77 | 0,5 % |  |
| `hs_v2_latest_time_in_2105413` | Latest time in "Cenová ponuka (B2C_elektrina)" | number / number | dealstages | 57 | 0,4 % |  |
| `hs_v2_latest_time_in_2105417` | Latest time in "Úspech_XML (B2C_elektrina)" | number / number | dealstages | 817 | 5,2 % |  |
| `hs_v2_latest_time_in_2105418` | Latest time in "Neúspech (B2C_elektrina)" | number / number | dealstages | 10 | 0,1 % |  |
| `hs_v2_latest_time_in_2107990` | Latest time in "Zmenový proces neúspešný - technický problém (B2C_elektrina)" | number / number | dealstages | 8 | 0,1 % |  |
| `hs_v2_latest_time_in_24250897` | Latest time in "Dopyt (GreenSolar)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_latest_time_in_24250899` | Latest time in "Cenová ponuka_akceptovaná (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_24250901` | Latest time in "Uhradená záloha (GreenSolar)" | number / number | dealstages | 9 | 0,1 % |  |
| `hs_v2_latest_time_in_24250902` | Latest time in "Dielo zrealizované a prevzaté (GreenSolar)" | number / number | dealstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_60256333` | Latest time in "Zmluva doručená (Greenlogy_B2C_služby)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_60256335` | Latest time in "Úspech (Greenlogy_B2C_služby)" | number / number | dealstages | 20 | 0,1 % |  |
| `hs_v2_latest_time_in_60435043` | Latest time in "Čakáme na zaradenie PDS (Greenlogy_B2C_služby)" | number / number | dealstages | 43 | 0,3 % |  |
| `hs_v2_latest_time_in_641523` | Latest time in "Príležitosť (B2B_elektrina)" | number / number | dealstages | 141 | 0,9 % |  |
| `hs_v2_latest_time_in_641525` | Latest time in "Neúspech (B2B_elektrina)" | number / number | dealstages | 13 | 0,1 % |  |
| `hs_v2_latest_time_in_641527` | Latest time in "Cenová ponuka (B2B_elektrina)" | number / number | dealstages | 767 | 4,9 % |  |
| `hs_v2_latest_time_in_73644134` | Latest time in "Notifikačný email (Greenlogy_B2C_služby)" | number / number | dealstages | 225 | 1,4 % |  |
| `hs_v2_latest_time_in_741794` | Latest time in "Výpoveď neakceptovaná (B2B_elektrina)" | number / number | dealstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_970090121` | Latest time in "Dielo uhradené (GreenSolar)" | number / number | dealstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_997673` | Latest time in "Zmenový proces neúspešný - technický problém (B2B_elektrina)" | number / number | dealstages | 5 | 0 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | dealstages | 15 600 | 100 % | výpočet |
| `hs_open_amount_in_home_currency` | Open amount in home currency | number / calculation_equation | hubspotmetrics | 15 250 | 97,8 % |  |
| `hs_weighted_pipeline_in_company_currency` | Weighted open pipeline in company currency | number / calculation_equation | hubspotmetrics | 15 206 | 97,5 % | výpočet |
| `amount` | Amount | number / number | kalkulácie | 14 565 | 93,4 % |  |
| `dealname` | Deal Name | string / text | obchodn__inform_cie | 15 601 | 100 % |  |
| `dealstage` | Deal Stage | enumeration / radio | obchodn__inform_cie | 15 600 | 100 % |  |
| `dealtype` | Deal Type | enumeration / radio | obchodn__inform_cie | 7 979 | 51,1 % | 8 možností |
| `description` | Deal Description | string / textarea | obchodn__inform_cie | 843 | 5,4 % |  |
| `hs_tag_ids` | Deal Tags | enumeration / checkbox | obchodn__inform_cie | 352 | 2,3 % |  |
| `hubspot_owner_id` | Deal owner | enumeration / select | obchodn__inform_cie | 8 004 | 51,3 % |  |
| `pipeline` | Pipeline | enumeration / select | obchodn__inform_cie | 15 600 | 100 % |  |
| `hs_average_call_duration` | Average call duration | number / calculation_rollup | predictive_deal_score_feature_properties | 212 | 1,4 % |  |
| `hs_latest_marketing_email_click_date` | Latest marketing email click date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 10 179 | 65,2 % |  |
| `hs_latest_marketing_email_open_date` | Latest marketing email open date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 13 547 | 86,8 % |  |
| `hs_latest_marketing_email_reply_date` | Latest marketing email reply date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 3 322 | 21,3 % |  |
| `hs_latest_sales_email_click_date` | Latest sales email click date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 1 921 | 12,3 % |  |
| `hs_latest_sales_email_open_date` | Latest sales email open date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 14 108 | 90,4 % |  |
| `hs_latest_sales_email_reply_date` | Latest sales email reply date | datetime / calculation_rollup | predictive_deal_score_feature_properties | 13 686 | 87,7 % |  |
| `hs_number_of_call_engagements` | Number of call engagements | number / calculation_rollup | predictive_deal_score_feature_properties | 15 601 | 100 % |  |
| `hs_number_of_inbound_calls` | Number of inbound calls | number / calculation_rollup | predictive_deal_score_feature_properties | 15 601 | 100 % |  |
| `hs_number_of_outbound_calls` | Number of outbound calls | number / calculation_rollup | predictive_deal_score_feature_properties | 15 601 | 100 % |  |
| `hs_number_of_overdue_tasks` | Number of overdue tasks | number / calculation_rollup | predictive_deal_score_feature_properties | 15 601 | 100 % |  |
| `hs_number_of_scheduled_meetings` | Number of scheduled meetings | number / calculation_rollup | predictive_deal_score_feature_properties | 15 | 0,1 % |  |

#### HubSpot vlastnosti bez dát (146)

`hs_associated_deal_registration_deal_type`, `hs_associated_deal_registration_product_interests`, `hs_deal_registration_mrr`, `hs_deal_registration_mrr_currency_code`, `hs_last_call_id_with_followups`, `hs_last_conversation_with_followups_object_coordinates`, `hs_last_email_with_followups_object_coordinates`, `hs_last_followup_timestamp`, `hs_last_gs_shared_message`, `hs_last_meeting_id_with_followups`, `hs_last_partner_shared_message_date`, `hs_last_shared_message_create_date`, `hs_latest_approval_status`, `hs_latest_approval_status_approval_id`, `hs_net_pipeline_impact`, `hs_primary_quote_data_updated_at`, `hs_synced_deal_owner_name_and_email`, `closed_lost_reason`, `closed_won_reason`, `engagements_last_meeting_booked_campaign`, `engagements_last_meeting_booked_medium`, `engagements_last_meeting_booked_source`, `hs_campaign`, `hs_deal_amount_calculation_preference`, `hs_form_id`, `hs_has_empty_conditional_stage_properties`, `hs_likelihood_to_close`, `hs_line_item_global_term_hs_discount_percentage`, `hs_line_item_global_term_hs_discount_percentage_enabled`, `hs_line_item_global_term_hs_recurring_billing_period`, `hs_line_item_global_term_hs_recurring_billing_period_enabled`, `hs_line_item_global_term_hs_recurring_billing_start_date`, `hs_line_item_global_term_hs_recurring_billing_start_date_enabled`, `hs_line_item_global_term_recurringbillingfrequency_enabled`, `hs_manual_campaign_ids`, `hs_next_meeting_id`, `hs_next_meeting_name`, `hs_next_meeting_start_time`, `hs_notes_next_activity`, `hs_notes_next_activity_type`, `hs_object_source_detail_3`, `hs_partner_tech_win`, `hs_predicted_amount`, `hs_predicted_amount_in_home_currency`, `hs_price_book_reassignment_status`, `hs_priority`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_source_object_id`, `hs_submission_idempotent_id`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `notes_next_activity_date`, `hs_v2_cumulative_time_in_1026837900`, `hs_v2_cumulative_time_in_1026837902`, `hs_v2_cumulative_time_in_1037487976`, `hs_v2_cumulative_time_in_1037487977`, `hs_v2_cumulative_time_in_1165517684`, `hs_v2_cumulative_time_in_1213762846`, `hs_v2_cumulative_time_in_1338732192`, `hs_v2_cumulative_time_in_1346481045`, `hs_v2_cumulative_time_in_2105414`, `hs_v2_cumulative_time_in_2107986`, `hs_v2_cumulative_time_in_2107987`, `hs_v2_cumulative_time_in_2107988`, `hs_v2_cumulative_time_in_2107989`, `hs_v2_cumulative_time_in_24250898`, `hs_v2_cumulative_time_in_24250903`, `hs_v2_cumulative_time_in_60244030`, `hs_v2_cumulative_time_in_60244031`, `hs_v2_cumulative_time_in_60244032`, `hs_v2_cumulative_time_in_60244033`, `hs_v2_cumulative_time_in_60244034`, `hs_v2_cumulative_time_in_60256331`, `hs_v2_cumulative_time_in_60256334`, `hs_v2_cumulative_time_in_60256336`, `hs_v2_date_entered_1026837900`, `hs_v2_date_entered_1026837902`, `hs_v2_date_entered_1165517684`, `hs_v2_date_entered_1338732192`, `hs_v2_date_entered_2105414`, `hs_v2_date_entered_2107986`, `hs_v2_date_entered_2107987`, `hs_v2_date_entered_2107988`, `hs_v2_date_entered_2107989`, `hs_v2_date_entered_24250898`, `hs_v2_date_entered_60244030`, `hs_v2_date_entered_60244031`, `hs_v2_date_entered_60244032`, `hs_v2_date_entered_60244033`, `hs_v2_date_entered_60244034`, `hs_v2_date_entered_60256334`, `hs_v2_date_entered_60256336`, `hs_v2_date_exited_1026837900`, `hs_v2_date_exited_1026837902`, `hs_v2_date_exited_1037487976`, `hs_v2_date_exited_1037487977`, `hs_v2_date_exited_1165517684`, `hs_v2_date_exited_1213762846`, `hs_v2_date_exited_1338732192`, `hs_v2_date_exited_1346481045`, `hs_v2_date_exited_2105414`, `hs_v2_date_exited_2107986`, `hs_v2_date_exited_2107987`, `hs_v2_date_exited_2107988`, `hs_v2_date_exited_2107989`, `hs_v2_date_exited_24250898`, `hs_v2_date_exited_24250903`, `hs_v2_date_exited_60244030`, `hs_v2_date_exited_60244031`, `hs_v2_date_exited_60244032`, `hs_v2_date_exited_60244033`, `hs_v2_date_exited_60244034`, `hs_v2_date_exited_60256331`, `hs_v2_date_exited_60256334`, `hs_v2_date_exited_60256336`, `hs_v2_latest_time_in_1026837900`, `hs_v2_latest_time_in_1026837902`, `hs_v2_latest_time_in_1037487976`, `hs_v2_latest_time_in_1037487977`, `hs_v2_latest_time_in_1165517684`, `hs_v2_latest_time_in_1213762846`, `hs_v2_latest_time_in_1338732192`, `hs_v2_latest_time_in_1346481045`, `hs_v2_latest_time_in_2105414`, `hs_v2_latest_time_in_2107986`, `hs_v2_latest_time_in_2107987`, `hs_v2_latest_time_in_2107988`, `hs_v2_latest_time_in_2107989`, `hs_v2_latest_time_in_24250898`, `hs_v2_latest_time_in_24250903`, `hs_v2_latest_time_in_60244030`, `hs_v2_latest_time_in_60244031`, `hs_v2_latest_time_in_60244032`, `hs_v2_latest_time_in_60244033`, `hs_v2_latest_time_in_60244034`, `hs_v2_latest_time_in_60256331`, `hs_v2_latest_time_in_60256334`, `hs_v2_latest_time_in_60256336`, `hs_cross_account_note`, `hs_cross_sell_opportunity`, `recurring_revenue_amount`, `recurring_revenue_deal_type`, `recurring_revenue_inactive_date`, `recurring_revenue_inactive_reason`

#### Vypočítané vlastnosti (vlastné)

| Interný názov | Label | Typ | Vzorec / definícia |
| --- | --- | --- | --- |
| `amount_pomocny_z_oom` | Amount_pomocný | calculation_equation | `test + new_celkovy_vynos_z_fixov__eur_mwh_ + green_viwa_poplatok_za_rk__pomocny_ * 12 * celkovy_vykon_v_mw` |
| `celkova_cena_diela__bez_dph` | Celková cena diela (bez DPH) | calculation_equation | `celkova_cena_s_dph / dph` |
| `celkova_vyska_provizie` | Celková výška provízie | calculation_equation | `zaklad_pre_vypocet_provizie * provizia_v__ + dodatocna_provizia_new` |
| `celkovy_objem_vykupu_z_oom__mwh_` | Celkový objem výkupu [MWh] | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `celkovy_objem_z_oom__mwh_` | Celkový objem spotreby [MWh] | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `celkovy_vykon_v_mw` | Celkový výkon zdrojov v kW | calculation_rollup | – (API definíciu nevracia) |
| `celkovy_vynos_zo_zmluvy__komodita_oom_sluzby_` | Celkový výnos zo zmluvy (komodita+OOM+služby) | calculation_equation | `new_celkovy_vynos_z_fixov__eur_mwh_ + test` |
| `cista_provizia_greenlogy__marza_` | Čistá provízia_Greenlogy (marža) | calculation_equation | `if is_present(string(obchodnik_nep)) then celkova_vyska_provizie / 2 else celkova_vyska_provizie + douctovanie_z_nepu` |
| `dodatocna_provizia_new` | Dodatočná provízia | calculation_equation | `uspora_na_zlave__max__1500_eur_ / dph` |
| `help__objem_vybrany_z_line_items` | Objem dodávky v MWh_line items | calculation_rollup | – (API definíciu nevracia) |
| `hruba_marza` | Hrubá marža_line items | calculation_equation | `line_items_subtotal - n_kupn_cena * help__objem_vybrany_z_line_items` |
| `hs_weighted_new_hruba_marza` | HubSpot Weighted new_hruba_marza | calculation_equation | `(if is_present(string(hs_deal_stage_probability)) then (new_hruba_marza * hs_deal_stage_probability) else new_hruba_marza)` |
| `hubspot_weighted_new_hruba_marza` | HubSpot Weighted new_hruba_marza | calculation_equation | `(if is_present(string(hs_deal_stage_probability)) then (new_hruba_marza * hs_deal_stage_probability) else new_hruba_marza)` |
| `line_items_subtotal` | Line items_subtotal | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `new_celkovy_vynos_z_fixov__eur_mwh_` | Celkový výnos z fixov [EUR/MWh] | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `new_hruba_marza` | Hrubá marža | calculation_equation | `(((amount_pomocny_z_oom * 1) - (n_kupn_cena * celkovy_objem_z_oom__mwh_)) - (n_kupn_cena * celkovy_objem_vykupu_z_oom__mwh_))` |
| `new_hruba_marza_pre_vypocet_provizie_gd` | Hrubá marža pre výpočet provízie_Sales portál | calculation_equation | `test - n_kupn_cena * celkovy_objem_z_oom__mwh_` |
| `pocet_oom_celkom__dodavka_` | Počet OOM_Celkom (dodávka) | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `pocet_oom_celkom__spotreba_` | Počet OOM_Celkom (spotreba) | calculation_rollup | – (API definíciu nevracia) |
| `priemerna_hruba_marza_mwh` | Priemerná hrubá marža_MWh | calculation_equation | `new_hruba_marza / celkovy_objem_z_oom__mwh_` |
| `priemerna_predajna_cena` | Priemerná predajná cena_line items | calculation_equation | `(amount / help__objem_vybrany_z_line_items)` |
| `priemerna_predajna_cena_z_oom` | Priemerná cena na OOM | calculation_equation | `((test + new_celkovy_vynos_z_fixov__eur_mwh_) / (celkovy_objem_z_oom__mwh_ + celkovy_objem_vykupu_z_oom__mwh_))` |
| `test` | Celkový výnos z elektriny [EUR/MWh] | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `test_pocet_om` | Počet OOM_Celkom | calculation_rollup | – (API definíciu nevracia) |
| `zaklad_pre_vypocet_provizie` | Základ pre výpočet provízie | calculation_equation | `celkova_cena_diela__bez_dph - dodatocna_provizia_new` |

#### Možnosti výberových polí

- **`faza_obchodu`** (Fáza zmluvy): `Akceptácia/Rozpracovaná zmluva` = Akceptácia/Rozpracovaná zmluva; `Čaká na podpis` = Čaká na podpis; `Finálne podpísaná` = Finálne podpísaná; `Čakáme na zaradenie do BS` = Čakáme na zaradenie do BS; `Úspech` = Úspech; `Autoprolong` = Autoprolong; `Zmluva chýba` = Zmluva chýba
- **`akceptacia_vypovede`** (Akceptácia výpovede): `Akceptované` = Akceptované; `Neakceptované` = Neakceptované; `Bez infomácie` = Bez infomácie
- **`claude_audit`** (Claude audit): `Áno` = Áno; `Nie` = Nie
- **`commission_status_sales_portal`** (commission_status_sales_portal): `Čaká na uplatnenie` = Čaká na uplatnenie; `Uplatnená` = Uplatnená
- **`dovod_ukoncenia_dealu`** (Dôvod ukončenia dealu): `Prolongácia` = Prolongácia; `Prepis zákazníka` = Prepis zákazníka; `Výpoveď zo strany zákazníka` = Výpoveď zo strany zákazníka; `Výpoveď zo strany Greenlogy` = Výpoveď zo strany Greenlogy; `Uplynutie zmluvnej doby` = Uplynutie zmluvnej doby; `Neobnovenie zmluvy` = Neobnovenie zmluvy
- **`stav_zakazky_fve`** (Stav zákazky FVE): `Cenová ponuka_odoslaná` = Cenová ponuka_odoslaná; `Cenová ponuka_akceptovaná` = Cenová ponuka_akceptovaná; `Uhradená záloha` = Uhradená záloha; `Dielo zrealizované a prevzaté` = Dielo zrealizované a prevzaté; `Dielo uhradené` = Dielo uhradené
- **`typ_viwa_zmluvy`** (Typ VIWA zmluvy): `Green VIWA Basic` = Green VIWA Basic; `Green VIWA Plus` = Green VIWA Plus; `Green VIWA Pro` = Green VIWA Pro
- **`vyska_preddavkovej_platby`** (Výška preddavkovej platby): `0%` = 0%; `50%` = 50%; `60%` = 60%; `70%` = 70%; `80%` = 80%; `90%` = 90%; `100%` = 100%
- **`vyuctovane_nepom`** (Vyúčtované NEPom): `Yes` = Yes; `No` = No
- **`greencar_anoodoslatponuku`** (greencar_AnoOdoslatPonuku): `true` = Yes; `false` = No
- **`dph_new`** (DPH_20-23%): `20%` = 20%; `23%` = 23%; `0%` = 0%
- **`program_greensolar`** (Program GreenSolar): `Eco` = Eco; `Standard` = Standard; `Premium` = Premium
- **`zelena_poukazka___stav_uhrady`** (Zelená poukážka - stav úhrady): `Preplatená` = Preplatená; `Nepreplatená` = Nepreplatená
- **`green_viwa___aditiv_konverzie`** (Green VIWA - aditív konverzie): `15 €` = 0,85; `20 €` = 0,8; `25 €` = 0,75; `10 €` = 0,9
- **`green_viwa_poplatok_za_rezervovanu_kapacitu`** (Green VIWA_Poplatok za rezervovanú kapacitu): `Basic_0,25 €/kW` = 0,25 €/kW; `Plus_0,20 €/kW` = 0,20 €/kW; `Pro_0,15 €/kW` = 0,15 €/kW
- **`kampan`** (Kampaň): `Akcia_2024_60%` = Akcia_2024_60% (skrytá); `Google kampane` = Google kampane; `WEB Greenlogy` = WEB Greenlogy; `NEP` = NEP; `Doporučenie` = Doporučenie; `Direct email GRN` = Direct email GRN; `Iné` = Iné; `Akcia_Máj25_109EUR` = Akcia_Máj25_109EUR
- **`kontrola_provizie`** (Kontrola provízie): `Yes` = Yes; `No` = No
- **`mhsr`** (MHSR): `true` = Yes; `false` = No
- **`segment_zakaznika`** (Zákaznícky segment): `Domácnosť` = Domácnosti; `Firma` = Firmy a organizácie; `Dodávateľ` = Výrobca
- **`stav_zmluvy`** (Stav zmluvy): `Potvrdený` = Potvrdený; `Nepotvrdený` = Nepotvrdený; `Ukončená` = Ukončená
- **`trvanie_zmluvy`** (Trvanie zmluvy): `neurčito` = neurčito; `2023` = 2023; `2024` = 2024; `2025` = 2025; `2026` = 2026; `2027` = 2027; `2028` = 2028; `2029` = 2029; `2030` = 2030; `2022` = 2022
- **`vypoved_odosiela`** (Výpoveď odosiela): `Zákazník` = Zákazník; `Greenlogy` = Dodávateľ
- **`z_skan_od`** (Predošlý dodávateľ): `ZSE energia` = ZSE energia; `SSE` = SSE; `VSE/innogy` = VSE; `SPP` = SPP; `Magna energia` = Magna energia; `Energie 2` = Energie 2; `Elgas` = Elgas; `SE - energetické služby` = SE - energetické služby; `Iné` = Iné
- **`zapis_v_trading_sales_book`** (Zápis v Trading/sales book): `true` = Yes; `false` = No
- **`splatnost_faktur`** (Splatnosť faktúr): `7 dní` = 7 dní; `14 dní` = 14 dní; `21 dní` = 21 dní; `30 dní` = 30 dní; `24.` = 24.; `10.` = 10.
- **`tolerancia_odberu_bez_obmedzeni_a_pokut`** (Flexibilita odberu): `+5% / - 5%` = +5% / - 5%; `+10% / - 10%` = +10% / - 10%; `+20% / - 20%` = +20% / - 20%; `+30% / - 30%` = +30% / - 30%; `+50% / - 50%` = +50% / - 50%; `+100% / - 100%` = PLNÁ FLEXIBILITA
- **`typ_vyrobneho_zdroja`** (Typ výrobného zdroja): `Slnko` = Slnko; `Vietor` = Vietor; `Voda` = Voda; `Bioplyn` = Bioplyn; `Biomasa` = Biomasa; `KVET` = KVET; `Lokálny zdroj` = Lokálny zdroj; `Výrobný zdroj` = Výrobný zdroj
- **`xml433domacnosti_anoodoslatemail`** (XML433Domacnosti_AnoOdoslatEmail): `true` = Yes; `false` = No
- **`xml43ddomacnosti_anoodoslatemail`** (XML43DDomacnosti_AnoOdoslatEmail): `true` = Yes; `false` = No
- **`xml43dorganizacie_anoodoslatemail`** (XML43DOrganizacie_AnoOdoslatEmail): `true` = Yes; `false` = No
- **`hodnota_kuponu_greencar`** (Hodnota kupónu GreenCar): `25 Eur` = 25 Eur; `50 Eur` = 50 Eur; `100 Eur` = 100 Eur
- **`sluzba_greencar`** (Služba GreenCar): `true` = Yes; `false` = No
- **`hs_analytics_latest_source`** (Latest Traffic Source): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_analytics_latest_source_company`** (Latest Traffic Source Company): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_analytics_latest_source_contact`** (Latest Traffic Source Contact): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_analytics_source`** (Original Traffic Source): `ORGANIC_SEARCH` = Organic Search; `PAID_SEARCH` = Paid Search; `EMAIL_MARKETING` = Email Marketing; `SOCIAL_MEDIA` = Organic Social; `REFERRALS` = Referrals; `OTHER_CAMPAIGNS` = Other Campaigns; `DIRECT_TRAFFIC` = Direct Traffic; `OFFLINE` = Offline Sources; `PAID_SOCIAL` = Paid Social; `AI_REFERRALS` = AI Referrals
- **`hs_has_last_conversation_follow_ups`** (Has Last Conversation Follow Ups): `true` = Yes; `false` = No
- **`hs_has_last_meeting_followups`** (Has Last Meeting Follow Ups): `true` = True; `false` = False
- **`hs_is_active_shared_deal`** (Is Active Shared Deal): `true` = Yes; `false` = No
- **`hs_is_closed_lost`** (Is closed lost): `true` = True; `false` = False
- **`hs_is_closed_won`** (Is Closed Won): `true` = True; `false` = False
- **`hs_is_closed`** (Is Deal Closed?): `true` = True; `false` = False
- **`hs_is_deal_split`** (Deal Split Added): `true` = True; `false` = False
- **`hs_is_in_first_deal_stage`** (Is In First Deal Stage): `true` = Yes; `false` = No
- **`hs_manual_forecast_category`** (Forecast category): `OMIT` = Not forecasted; `PIPELINE` = Menej pravdepodobné; `BEST_CASE` = Vysoko pravdepodobné; `COMMIT` = 100% isté; `CLOSED` = Closed won
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False
- **`hs_is_stalled`** (Is Stalled): `true` = true; `false` = false
- **`dealtype`** (Deal Type): `newbusiness` = Akvizícia; `existingbusiness` = Retencia; `Nové pripojenie` = Nové OM; `Prepis OM` = Zmena odberateľa; `Služba` = GreenSolar_B2C; `Služba_GreenSolar_B2B` = GreenSolar_B2B; `Veľkoobchod` = Velkoobchod; `Odchádzajúci` = Odchádzajúci

### Tickety (`tickets`)

Vlastností spolu: 520 (vlastné 21, HubSpot 499). Záznamov: 61 723.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `anoodlozene` | AnoOdlozene | enumeration / booleancheckbox | ticket_activity | 140 | 0,2 % | 2 možností |
| `priloha` | Priložiť prílohu | string / file | ticket_activity | 100 | 0,2 % |  |
| `eic_pod` | EIC | string / text | ticketinformation | 26 259 | 42,5 % |  |
| `green_solar_produkt` | Green SOLAR produkt | enumeration / select | ticketinformation | 143 | 0,2 % | 6 možností |
| `hodnotenie_ticketu` | Hodnotenie ticketu | number / number | ticketinformation | 2 729 | 4,4 % |  |
| `kampan` | Kampaň | enumeration / checkbox | ticketinformation | 1 150 | 1,9 % | 1 možností |
| `komodita_slu_ba` | Produkt | enumeration / select | ticketinformation | 36 867 | 59,7 % | 10 možností |
| `notifikacia_emailom` | Notifikácia emailom | enumeration / select | ticketinformation | 34 217 | 55,4 % | 2 možností |
| `prajete_si_vypracovat_cenovu_ponuku_aj_na_dodavku_elektriny_` | Prajete si vypracovať cenovú ponuku aj na dodávku elektriny? | enumeration / select | ticketinformation | 154 | 0,2 % | 2 možností |
| `segment` | Segment | enumeration / select | ticketinformation | 33 202 | 53,8 % | 2 možností |
| `standardy_kvality` | Štandardy kvality | enumeration / checkbox | ticketinformation | 1 129 | 1,8 % | 11 možností |
| `subjekt` | Subjekt | string / text | ticketinformation | 6 | 0 % |  |
| `typ_kontaktu` | Typ kontaktu | enumeration / checkbox | ticketinformation | 3 433 | 5,6 % | 7 možností |
| `zelate_si_vypracovat_cenovu_ponuku_aj_na_dodavku_elektriny_` | Želáte si vypracovať cenovú ponuku aj na dodávku elektriny? | enumeration / booleancheckbox | ticketinformation | 0 | 0 % | 2 možností |
| `zelena_domacnostiam` | Zelená domácnostiam | enumeration / select | ticketinformation | 125 | 0,2 % | 2 možností |
| `distribucna_oblast` | Distribučná oblasť | enumeration / select | výkup_elektriny | 1 247 | 2 % | 4 možností |
| `lokalny_zdroj1` | Lokálny zdroj | enumeration / select | výkup_elektriny | 804 | 1,3 % | 2 možností |
| `podpora_vyroby_elektriny_doplatkom_pripaltkom` | Podpora výroby elektriny doplatkom/príplatkom | enumeration / select | výkup_elektriny | 678 | 1,1 % | 2 možností |
| `typ_strechy` | Typ strechy | enumeration / select | výkup_elektriny | 144 | 0,2 % | 2 možností |
| `typ_vyrobneho_zdroja` | Typ výrobného zdroja | enumeration / select | výkup_elektriny | 810 | 1,3 % | 6 možností |
| `vykon_zdroja` | Výkon zdroja | number / number | výkup_elektriny | 806 | 1,3 % |  |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `closed_date` | Close date | datetime / date | ticket_activity | 61 446 | 99,6 % |  |
| `createdate` | Create date | datetime / date | ticket_activity | 61 722 | 100 % |  |
| `first_agent_reply_date` | First agent email response date | datetime / date | ticket_activity | 37 675 | 61 % |  |
| `hs_all_conversation_mentions` | All conversation mentions | enumeration / calculation_rollup | ticket_activity | 7 | 0 % |  |
| `hs_assignment_method` | Assignment Method | enumeration / checkbox | ticket_activity | 99 | 0,2 % | 15 možností |
| `hs_draft_user_ids` | Draft UserIds | enumeration / select | ticket_activity | 2 | 0 % |  |
| `hs_is_callback_request` | Callback request | bool / calculation_equation | ticket_activity | 2 167 | 3,5 % | výpočet |
| `hs_last_closed_date` | Last Closed Date | datetime / date | ticket_activity | 61 485 | 99,6 % |  |
| `hs_last_csat_comment` | Last CSAT survey comment | string / calculation_rollup | ticket_activity | 1 | 0 % |  |
| `hs_last_csat_date` | Last CSAT survey date | datetime / calculation_rollup | ticket_activity | 1 | 0 % |  |
| `hs_last_csat_rating` | Last CSAT survey rating | string / calculation_rollup | ticket_activity | 1 | 0 % |  |
| `hs_lastactivitydate` | Last activity date | datetime / date | ticket_activity | 60 733 | 98,4 % |  |
| `hs_lastcontacted` | Last contacted date | datetime / date | ticket_activity | 42 183 | 68,3 % |  |
| `hs_lastmodifieddate` | Last modified date | datetime / date | ticket_activity | 61 723 | 100 % |  |
| `hs_mentioned_note_user_ids` | mentioned_note_user_ids | enumeration / calculation_equation | ticket_activity | 2 128 | 3,4 % | výpočet |
| `hs_mentions_user_ids` | mentions_user_ids | enumeration / calculation_equation | ticket_activity | 2 135 | 3,5 % | výpočet |
| `hs_nextactivitydate` | Next activity date | datetime / date | ticket_activity | 40 | 0,1 % |  |
| `hs_seen_by_agent_ids` | Users interaction | enumeration / checkbox | ticket_activity | 2 047 | 3,3 % |  |
| `hs_ticket_reopened_at` | Ticket reopen date | datetime / date | ticket_activity | 3 036 | 4,9 % |  |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | ticket_activity | 61 712 | 100 % |  |
| `last_reply_date` | Last customer reply date | datetime / date | ticket_activity | 38 585 | 62,5 % |  |
| `hs_first_visitor_message_sentiment` | (Deprecated) First message sentiment | enumeration / calculation_equation | ticket_ai_enrichment | 281 | 0,5 % | výpočet, 3 možností |
| `hs_first_visitor_message_sentiment_score` | First message sentiment score | number / number | ticket_ai_enrichment | 281 | 0,5 % |  |
| `hs_last_visitor_message_sentiment` | (Deprecated) Last message sentiment | enumeration / calculation_equation | ticket_ai_enrichment | 281 | 0,5 % | výpočet, 3 možností |
| `hs_last_visitor_message_sentiment_score` | Latest message sentiment score | number / number | ticket_ai_enrichment | 281 | 0,5 % |  |
| `hs_overall_visitor_messages_sentiment` | (Deprecated) Average ticket sentiment | enumeration / calculation_equation | ticket_ai_enrichment | 281 | 0,5 % | výpočet, 3 možností |
| `hs_overall_visitor_messages_sentiment_score` | Average ticket sentiment score | number / number | ticket_ai_enrichment | 281 | 0,5 % |  |
| `hs_ticket_language_ai_tag` | Language | enumeration / select | ticket_ai_enrichment | 19 699 | 31,9 % | 171 možností |
| `content` | Ticket description | string / textarea | ticketinformation | 36 233 | 58,7 % |  |
| `created_by` | Created by | number / number | ticketinformation | 41 127 | 66,6 % |  |
| `hs_all_accessible_team_ids` | All teams | enumeration / select | ticketinformation | 59 607 | 96,6 % |  |
| `hs_all_assigned_business_unit_ids` | Brands | enumeration / checkbox | ticketinformation | 16 202 | 26,2 % |  |
| `hs_all_associated_contact_companies` | All associated contact companies | string / calculation_rollup | ticketinformation | 6 055 | 9,8 % | výpočet |
| `hs_all_associated_contact_emails` | All associated contact emails | string / calculation_rollup | ticketinformation | 45 567 | 73,8 % | výpočet |
| `hs_all_associated_contact_firstnames` | All associated contact first names | string / calculation_rollup | ticketinformation | 45 007 | 72,9 % | výpočet |
| `hs_all_associated_contact_lastnames` | All associated contact last names | string / calculation_rollup | ticketinformation | 45 268 | 73,3 % | výpočet |
| `hs_all_associated_contact_mobilephones` | All associated contact mobile phones | string / calculation_rollup | ticketinformation | 40 011 | 64,8 % | výpočet |
| `hs_all_associated_contact_phones` | All associated contact phones | string / calculation_rollup | ticketinformation | 11 451 | 18,6 % | výpočet |
| `hs_all_owner_ids` | All owner IDs | enumeration / select | ticketinformation | 61 712 | 100 % |  |
| `hs_all_team_ids` | All team IDs | enumeration / select | ticketinformation | 59 607 | 96,6 % |  |
| `hs_assigned_team_ids` | Assigned teams | enumeration / checkbox | ticketinformation | 8 482 | 13,7 % |  |
| `hs_auto_generated_from_thread_id` | Auto-generated from thread id | number / number | ticketinformation | 36 105 | 58,5 % | jedinečná |
| `hs_conversations_originating_message_id` | Originating Conversations Message Id | string / text | ticketinformation | 33 570 | 54,4 % |  |
| `hs_conversations_originating_thread_id` | Conversations originating thread id | number / number | ticketinformation | 37 820 | 61,3 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | ticketinformation | 24 127 | 39,1 % |  |
| `hs_createdate` | HubSpot create date | datetime / date | ticketinformation | 61 722 | 100 % |  |
| `hs_current_generic_channel_id` | Current channel | enumeration / select | ticketinformation | 48 356 | 78,3 % |  |
| `hs_email_subject` | Email subject | string / calculation_rollup | ticketinformation | 34 794 | 56,4 % |  |
| `hs_file_upload` | File upload | string / file | ticketinformation | 306 | 0,5 % |  |
| `hs_first_agent_message_sent_at` | First agent response date | datetime / calculation_rollup | ticketinformation | 31 592 | 51,2 % | výpočet |
| `hs_first_agent_message_sent_by` | First responding rep | enumeration / select | ticketinformation | 8 389 | 13,6 % |  |
| `hs_form_id` | Form | enumeration / select | ticketinformation | 2 489 | 4 % |  |
| `hs_form_submission_conversion_id` | Form submission conversion ID | string / text | ticketinformation | 2 489 | 4 % |  |
| `hs_helpdesk_sort_timestamp` | Helpdesk Sort Timestamp | datetime / calculation_rollup | ticketinformation | 61 721 | 100 % |  |
| `hs_in_helpdesk` | In Help Desk | bool / booleancheckbox | ticketinformation | 303 | 0,5 % | 2 možností |
| `hs_is_closed` | Closed | bool / calculation_equation | ticketinformation | 61 722 | 100 % | výpočet, 2 možností |
| `hs_is_latest_message_failed` | Is latest message failed | bool / calculation_rollup | ticketinformation | 34 885 | 56,5 % | 2 možností |
| `hs_is_latest_message_hidden_from_all` | Is latest message hidden from all | bool / calculation_rollup | ticketinformation | 30 097 | 48,8 % | 2 možností |
| `hs_is_one_touch_ticket` | First contact resolution | bool / booleancheckbox | ticketinformation | 298 | 0,5 % | 2 možností |
| `hs_is_visible_in_help_desk` | Is Visible in Help desk | bool / booleancheckbox | ticketinformation | 61 721 | 100 % | 2 možností |
| `hs_last_email_activity` | Last email activity | enumeration / select | ticketinformation | 61 163 | 99,1 % | 3 možností |
| `hs_last_email_date` | Last email date | datetime / date | ticketinformation | 52 776 | 85,5 % |  |
| `hs_last_email_details` | Last email details | string / text | ticketinformation | 52 884 | 85,7 % |  |
| `hs_last_email_type` | Last Email Type | string / text | ticketinformation | 52 874 | 85,7 % |  |
| `hs_last_message_from_visitor` | Last message from visitor | bool / calculation_equation | ticketinformation | 61 721 | 100 % | 2 možností |
| `hs_last_message_received_at` | Last message received date | datetime / calculation_rollup | ticketinformation | 40 826 | 66,1 % | výpočet |
| `hs_last_message_sent_at` | Last response date | datetime / calculation_rollup | ticketinformation | 35 276 | 57,2 % | výpočet |
| `hs_latest_message_attachment_types` | Latest message attachment types | enumeration / calculation_rollup | ticketinformation | 34 878 | 56,5 % | 13 možností |
| `hs_latest_message_is_forwarded_email` | Latest message is forwarded email | bool / calculation_rollup | ticketinformation | 34 878 | 56,5 % | 2 možností |
| `hs_latest_message_is_thread_comment` | Latest message is thread comment | bool / calculation_rollup | ticketinformation | 34 885 | 56,5 % | 2 možností |
| `hs_latest_message_seen_by_agent_ids` | Latest message seen by agent ids | enumeration / calculation_rollup | ticketinformation | 32 815 | 53,2 % | výpočet |
| `hs_latest_message_visible_to_visitor` | Latest message visible to visitor | string / calculation_rollup | ticketinformation | 3 462 | 5,6 % |  |
| `hs_latest_message_visible_to_visitor_sent_at` | Latest message visible to visitor sent at | datetime / calculation_rollup | ticketinformation | 29 749 | 48,2 % |  |
| `hs_merged_object_ids` | Merged Ticket IDs | enumeration / checkbox | ticketinformation | 2 533 | 4,1 % |  |
| `hs_notes_last_activity` | Last Activity | object_coordinates / text | ticketinformation | 60 765 | 98,4 % |  |
| `hs_notes_next_activity` | Next Activity | object_coordinates / text | ticketinformation | 20 | 0 % |  |
| `hs_notes_next_activity_type` | Next Activity Type | enumeration / select | ticketinformation | 20 | 0 % | 13 možností |
| `hs_num_associated_companies` | Number of Associated Companies | number / number | ticketinformation | 61 722 | 100 % | výpočet |
| `hs_num_associated_conversations` | Number of Associated Conversations | number / number | ticketinformation | 61 721 | 100 % |  |
| `hs_num_times_contacted` | Number of times contacted | number / number | ticketinformation | 61 618 | 99,8 % |  |
| `hs_number_of_touches` | Number of touches | number / number | ticketinformation | 298 | 0,5 % |  |
| `hs_object_id` | Record ID | number / number | ticketinformation | 61 722 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | ticketinformation | 61 719 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | ticketinformation | 760 | 1,2 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | ticketinformation | 647 | 1 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | ticketinformation | 27 628 | 44,8 % |  |
| `hs_object_source_label` | Record source | enumeration / select | ticketinformation | 61 719 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | ticketinformation | 19 871 | 32,2 % |  |
| `hs_originating_channel_instance_id` | Originating channel account | enumeration / calculation_rollup | ticketinformation | 48 249 | 78,2 % | výpočet |
| `hs_originating_email_engagement_id` | Originating email engagement id | number / number | ticketinformation | 34 088 | 55,2 % |  |
| `hs_originating_generic_channel_id` | Originating channel type | enumeration / calculation_rollup | ticketinformation | 48 249 | 78,2 % | výpočet |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | ticketinformation | 59 607 | 96,6 % |  |
| `hs_pinned_engagement_id` | Pinned Engagement ID | number / number | ticketinformation | 1 601 | 2,6 % |  |
| `hs_pipeline` | Pipeline | enumeration / select | ticketinformation | 61 722 | 100 % |  |
| `hs_pipeline_stage` | Ticket status | enumeration / select | ticketinformation | 61 723 | 100 % |  |
| `hs_primary_company` | Primary Company | string / calculation_rollup | ticketinformation | 15 569 | 25,2 % | výpočet |
| `hs_primary_company_id` | Primary Company ID | number / calculation_rollup | ticketinformation | 15 569 | 25,2 % | výpočet |
| `hs_primary_company_name` | Primary Company Name | string / calculation_rollup | ticketinformation | 15 569 | 25,2 % | výpočet |
| `hs_sales_email_last_replied` | Recent Sales Email Replied Date | datetime / date | ticketinformation | 38 465 | 62,3 % |  |
| `hs_shared_user_ids` | Shared users | enumeration / checkbox | ticketinformation | 1 | 0 % |  |
| `hs_source_url` | Source url | string / calculation_rollup | ticketinformation | 3 409 | 5,5 % |  |
| `hs_tag_ids` | Ticket Tags | enumeration / checkbox | ticketinformation | 1 761 | 2,9 % |  |
| `hs_thread_ids_to_restore` | Thread IDs To Restore | enumeration / checkbox | ticketinformation | 48 124 | 78 % |  |
| `hs_ticket_category` | Category | enumeration / checkbox | ticketinformation | 43 403 | 70,3 % | 12 možností |
| `hs_ticket_id` | Ticket ID | number / calculation_equation | ticketinformation | 61 722 | 100 % | výpočet |
| `hs_ticket_priority` | Priority | enumeration / select | ticketinformation | 48 123 | 78 % | 4 možností |
| `hs_time_to_first_rep_assignment` | Time to first rep assignment | number / number | ticketinformation | 14 785 | 24 % |  |
| `hs_updated_by_user_id` | Updated by user ID | number / number | ticketinformation | 61 463 | 99,6 % |  |
| `hs_user_ids_of_all_notification_followers` | User IDs of all notification followers | enumeration / checkbox | ticketinformation | 1 | 0 % |  |
| `hs_user_ids_of_all_notification_recipients` | All ticket notification recipients | enumeration / checkbox | ticketinformation | 61 711 | 100 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | ticketinformation | 61 712 | 100 % |  |
| `hubspot_owner_id` | Ticket owner | enumeration / select | ticketinformation | 61 712 | 100 % |  |
| `hubspot_team_id` | HubSpot team | enumeration / select | ticketinformation | 59 607 | 96,6 % |  |
| `last_engagement_date` | Date of last engagement | datetime / date | ticketinformation | 51 595 | 83,6 % |  |
| `notes_last_contacted` | Last Contacted (Ticket Note) | datetime / date | ticketinformation | 40 588 | 65,8 % |  |
| `notes_last_updated` | Last Activity Date (Ticket Note) | datetime / date | ticketinformation | 60 590 | 98,2 % |  |
| `notes_next_activity_date` | Next Activity Date (Ticket Note) | datetime / date | ticketinformation | 20 | 0 % |  |
| `num_contacted_notes` | Number of times contacted (Ticket Note) | number / number | ticketinformation | 57 793 | 93,6 % |  |
| `num_notes` | Number of Sales Activities | number / number | ticketinformation | 60 915 | 98,7 % |  |
| `source_type` | Source | enumeration / select | ticketinformation | 54 284 | 87,9 % | 4 možností |
| `subject` | Ticket name | string / text | ticketinformation | 61 722 | 100 % |  |
| `time_to_close` | Time to close | number / calculation_equation | ticketinformation | 61 446 | 99,6 % |  |
| `time_to_first_agent_reply` | Time to first agent email reply | number / number | ticketinformation | 37 675 | 61 % |  |
| `hs_v2_cumulative_time_in_1` | Cumulative time in "Nový (Office)" | number / number | ticketstages | 56 445 | 91,4 % |  |
| `hs_v2_cumulative_time_in_10559238` | Cumulative time in "Čakáme na zmenu legislatívy (Office)" | number / number | ticketstages | 28 | 0 % |  |
| `hs_v2_cumulative_time_in_11398928` | Cumulative time in "Aktualizovaný /zákazníkom/ (Office)" | number / number | ticketstages | 13 408 | 21,7 % |  |
| `hs_v2_cumulative_time_in_1259356` | Cumulative time in "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_1259396` | Cumulative time in "Čakáme na vyjadrenie obchodníka (Office)" | number / number | ticketstages | 1 119 | 1,8 % |  |
| `hs_v2_cumulative_time_in_1259397` | Cumulative time in "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 38 | 0,1 % |  |
| `hs_v2_cumulative_time_in_1259398` | Cumulative time in "Čakáme na vyjadrenia obchodníka (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 9 | 0 % |  |
| `hs_v2_cumulative_time_in_165449580` | Cumulative time in "Aktualizovný /obchodníkom/ (Office)" | number / number | ticketstages | 744 | 1,2 % |  |
| `hs_v2_cumulative_time_in_18941836` | Cumulative time in "Odložený - zaparkovaný (Office)" | number / number | ticketstages | 375 | 0,6 % |  |
| `hs_v2_cumulative_time_in_2` | Cumulative time in "Čakáme na vyjadrenie zákazníka (Office)" | number / number | ticketstages | 3 950 | 6,4 % |  |
| `hs_v2_cumulative_time_in_2413906` | Cumulative time in "Znovuotvorený (Office)" | number / number | ticketstages | 6 732 | 10,9 % |  |
| `hs_v2_cumulative_time_in_2413920` | Cumulative time in "Znovu otvorený (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_2413923` | Cumulative time in "Znovu otvorený (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_3` | Cumulative time in "Spracovávaný (Office)" | number / number | ticketstages | 7 339 | 11,9 % |  |
| `hs_v2_cumulative_time_in_4` | Cumulative time in "Zatvorený (Office)" | number / number | ticketstages | 14 780 | 23,9 % |  |
| `hs_v2_cumulative_time_in_606577` | Cumulative time in "Čakáme na vyjadrenie PDS (Office)" | number / number | ticketstages | 3 282 | 5,3 % |  |
| `hs_v2_cumulative_time_in_606578` | Cumulative time in "Čakáme na vyjadrenie pôvod. dodávateľa (Office)" | number / number | ticketstages | 314 | 0,5 % |  |
| `hs_v2_cumulative_time_in_606585` | Cumulative time in "Iné (Office)" | number / number | ticketstages | 45 | 0,1 % |  |
| `hs_v2_cumulative_time_in_641780` | Cumulative time in "Spracovávaný (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 5 | 0 % |  |
| `hs_v2_cumulative_time_in_641781` | Cumulative time in "Zatvorený (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 64 | 0,1 % |  |
| `hs_v2_cumulative_time_in_641782` | Cumulative time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 4 | 0 % |  |
| `hs_v2_cumulative_time_in_644185` | Cumulative time in "Nový (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 236 | 0,4 % |  |
| `hs_v2_cumulative_time_in_644187` | Cumulative time in "Nový (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 13 | 0 % |  |
| `hs_v2_cumulative_time_in_644200` | Cumulative time in "Spracovávaný (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 76 | 0,1 % |  |
| `hs_v2_cumulative_time_in_644201` | Cumulative time in "Zatvorený (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 52 | 0,1 % |  |
| `hs_v2_cumulative_time_in_644202` | Cumulative time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 93 | 0,2 % |  |
| `hs_v2_cumulative_time_in_644205` | Cumulative time in "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_644207` | Cumulative time in "Iné (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_cumulative_time_in_753378` | Cumulative time in "Nový (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 220 | 0,4 % |  |
| `hs_v2_cumulative_time_in_753379` | Cumulative time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 30 | 0 % |  |
| `hs_v2_cumulative_time_in_753380` | Cumulative time in "Iné (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_753381` | Cumulative time in "Spracovávaný (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 28 | 0 % |  |
| `hs_v2_cumulative_time_in_753382` | Cumulative time in "Zatvorené (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 21 | 0 % |  |
| `hs_v2_cumulative_time_in_753386` | Cumulative time in "Nový (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 442 | 0,7 % |  |
| `hs_v2_cumulative_time_in_753387` | Cumulative time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 117 | 0,2 % |  |
| `hs_v2_cumulative_time_in_753388` | Cumulative time in "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_cumulative_time_in_753389` | Cumulative time in "Spracovávaný (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 81 | 0,1 % |  |
| `hs_v2_cumulative_time_in_753391` | Cumulative time in "Zatvorený (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 34 | 0,1 % |  |
| `hs_v2_cumulative_time_in_753394` | Cumulative time in "Nový (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 678 | 1,1 % |  |
| `hs_v2_cumulative_time_in_753395` | Cumulative time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 4 312 | 7 % |  |
| `hs_v2_cumulative_time_in_753396` | Cumulative time in "Čakáme na vyjadrenie PDS (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 84 | 0,1 % |  |
| `hs_v2_cumulative_time_in_753397` | Cumulative time in "Čakáme na vyjadrenie pôv.dodávateľa (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 7 | 0 % |  |
| `hs_v2_cumulative_time_in_753398` | Cumulative time in "Iné (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 7 | 0 % |  |
| `hs_v2_cumulative_time_in_753399` | Cumulative time in "Spracovávaný (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 157 | 0,3 % |  |
| `hs_v2_cumulative_time_in_753400` | Cumulative time in "Zatvorený (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 4 130 | 6,7 % |  |
| `hs_v2_cumulative_time_in_92916080` | Cumulative time in "Nový (Výkup elektriny)" | number / number | ticketstages | 2 | 0 % |  |
| `hs_v2_date_entered_1` | Date entered "Nový (Office)" | datetime / date | ticketstages | 56 484 | 91,5 % |  |
| `hs_v2_date_entered_10559238` | Date entered "Čakáme na zmenu legislatívy (Office)" | datetime / date | ticketstages | 28 | 0 % |  |
| `hs_v2_date_entered_11398928` | Date entered "Aktualizovaný /zákazníkom/ (Office)" | datetime / date | ticketstages | 13 443 | 21,8 % |  |
| `hs_v2_date_entered_1259356` | Date entered "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 4 | 0 % |  |
| `hs_v2_date_entered_1259396` | Date entered "Čakáme na vyjadrenie obchodníka (Office)" | datetime / date | ticketstages | 1 118 | 1,8 % |  |
| `hs_v2_date_entered_1259397` | Date entered "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 38 | 0,1 % |  |
| `hs_v2_date_entered_1259398` | Date entered "Čakáme na vyjadrenia obchodníka (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 9 | 0 % |  |
| `hs_v2_date_entered_165449580` | Date entered "Aktualizovný /obchodníkom/ (Office)" | datetime / date | ticketstages | 748 | 1,2 % |  |
| `hs_v2_date_entered_18941836` | Date entered "Odložený - zaparkovaný (Office)" | datetime / date | ticketstages | 378 | 0,6 % |  |
| `hs_v2_date_entered_2` | Date entered "Čakáme na vyjadrenie zákazníka (Office)" | datetime / date | ticketstages | 4 062 | 6,6 % |  |
| `hs_v2_date_entered_2413906` | Date entered "Znovuotvorený (Office)" | datetime / date | ticketstages | 6 757 | 10,9 % |  |
| `hs_v2_date_entered_2413920` | Date entered "Znovu otvorený (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_entered_2413923` | Date entered "Znovu otvorený (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_entered_3` | Date entered "Spracovávaný (Office)" | datetime / date | ticketstages | 7 378 | 12 % |  |
| `hs_v2_date_entered_4` | Date entered "Zatvorený (Office)" | datetime / date | ticketstages | 56 285 | 91,2 % |  |
| `hs_v2_date_entered_606577` | Date entered "Čakáme na vyjadrenie PDS (Office)" | datetime / date | ticketstages | 3 319 | 5,4 % |  |
| `hs_v2_date_entered_606578` | Date entered "Čakáme na vyjadrenie pôvod. dodávateľa (Office)" | datetime / date | ticketstages | 315 | 0,5 % |  |
| `hs_v2_date_entered_606585` | Date entered "Iné (Office)" | datetime / date | ticketstages | 47 | 0,1 % |  |
| `hs_v2_date_entered_641780` | Date entered "Spracovávaný (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 5 | 0 % |  |
| `hs_v2_date_entered_641781` | Date entered "Zatvorený (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 81 | 0,1 % |  |
| `hs_v2_date_entered_641782` | Date entered "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 4 | 0 % |  |
| `hs_v2_date_entered_644185` | Date entered "Nový (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 236 | 0,4 % |  |
| `hs_v2_date_entered_644187` | Date entered "Nový (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 13 | 0 % |  |
| `hs_v2_date_entered_644200` | Date entered "Spracovávaný (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 76 | 0,1 % |  |
| `hs_v2_date_entered_644201` | Date entered "Zatvorený (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 185 | 0,3 % |  |
| `hs_v2_date_entered_644202` | Date entered "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 93 | 0,2 % |  |
| `hs_v2_date_entered_644205` | Date entered "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_entered_644207` | Date entered "Iné (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_entered_753378` | Date entered "Nový (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 220 | 0,4 % |  |
| `hs_v2_date_entered_753379` | Date entered "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 30 | 0 % |  |
| `hs_v2_date_entered_753380` | Date entered "Iné (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_entered_753381` | Date entered "Spracovávaný (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 28 | 0 % |  |
| `hs_v2_date_entered_753382` | Date entered "Zatvorené (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 667 | 1,1 % |  |
| `hs_v2_date_entered_753386` | Date entered "Nový (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 442 | 0,7 % |  |
| `hs_v2_date_entered_753387` | Date entered "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 117 | 0,2 % |  |
| `hs_v2_date_entered_753388` | Date entered "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_entered_753389` | Date entered "Spracovávaný (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 81 | 0,1 % |  |
| `hs_v2_date_entered_753391` | Date entered "Zatvorený (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 346 | 0,6 % |  |
| `hs_v2_date_entered_753394` | Date entered "Nový (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 678 | 1,1 % |  |
| `hs_v2_date_entered_753395` | Date entered "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 4 312 | 7 % |  |
| `hs_v2_date_entered_753396` | Date entered "Čakáme na vyjadrenie PDS (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 84 | 0,1 % |  |
| `hs_v2_date_entered_753397` | Date entered "Čakáme na vyjadrenie pôv.dodávateľa (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 7 | 0 % |  |
| `hs_v2_date_entered_753398` | Date entered "Iné (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 7 | 0 % |  |
| `hs_v2_date_entered_753399` | Date entered "Spracovávaný (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 157 | 0,3 % |  |
| `hs_v2_date_entered_753400` | Date entered "Zatvorený (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 4 668 | 7,6 % |  |
| `hs_v2_date_entered_92916080` | Date entered "Nový (Výkup elektriny)" | datetime / date | ticketstages | 2 | 0 % |  |
| `hs_v2_date_entered_92916083` | Date entered "Zatvorený (Výkup elektriny)" | datetime / date | ticketstages | 2 | 0 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | ticketstages | 12 251 | 19,8 % | výpočet |
| `hs_v2_date_exited_1` | Date exited "Nový (Office)" | datetime / date | ticketstages | 56 445 | 91,4 % |  |
| `hs_v2_date_exited_10559238` | Date exited "Čakáme na zmenu legislatívy (Office)" | datetime / date | ticketstages | 28 | 0 % |  |
| `hs_v2_date_exited_11398928` | Date exited "Aktualizovaný /zákazníkom/ (Office)" | datetime / date | ticketstages | 13 408 | 21,7 % |  |
| `hs_v2_date_exited_1259356` | Date exited "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 4 | 0 % |  |
| `hs_v2_date_exited_1259396` | Date exited "Čakáme na vyjadrenie obchodníka (Office)" | datetime / date | ticketstages | 1 119 | 1,8 % |  |
| `hs_v2_date_exited_1259397` | Date exited "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 38 | 0,1 % |  |
| `hs_v2_date_exited_1259398` | Date exited "Čakáme na vyjadrenia obchodníka (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 9 | 0 % |  |
| `hs_v2_date_exited_165449580` | Date exited "Aktualizovný /obchodníkom/ (Office)" | datetime / date | ticketstages | 744 | 1,2 % |  |
| `hs_v2_date_exited_18941836` | Date exited "Odložený - zaparkovaný (Office)" | datetime / date | ticketstages | 375 | 0,6 % |  |
| `hs_v2_date_exited_2` | Date exited "Čakáme na vyjadrenie zákazníka (Office)" | datetime / date | ticketstages | 3 950 | 6,4 % |  |
| `hs_v2_date_exited_2413906` | Date exited "Znovuotvorený (Office)" | datetime / date | ticketstages | 6 732 | 10,9 % |  |
| `hs_v2_date_exited_2413920` | Date exited "Znovu otvorený (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_exited_2413923` | Date exited "Znovu otvorený (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_exited_3` | Date exited "Spracovávaný (Office)" | datetime / date | ticketstages | 7 339 | 11,9 % |  |
| `hs_v2_date_exited_4` | Date exited "Zatvorený (Office)" | datetime / date | ticketstages | 14 780 | 23,9 % |  |
| `hs_v2_date_exited_606577` | Date exited "Čakáme na vyjadrenie PDS (Office)" | datetime / date | ticketstages | 3 282 | 5,3 % |  |
| `hs_v2_date_exited_606578` | Date exited "Čakáme na vyjadrenie pôvod. dodávateľa (Office)" | datetime / date | ticketstages | 314 | 0,5 % |  |
| `hs_v2_date_exited_606585` | Date exited "Iné (Office)" | datetime / date | ticketstages | 45 | 0,1 % |  |
| `hs_v2_date_exited_641780` | Date exited "Spracovávaný (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 5 | 0 % |  |
| `hs_v2_date_exited_641781` | Date exited "Zatvorený (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 64 | 0,1 % |  |
| `hs_v2_date_exited_641782` | Date exited "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 4 | 0 % |  |
| `hs_v2_date_exited_644185` | Date exited "Nový (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 236 | 0,4 % |  |
| `hs_v2_date_exited_644187` | Date exited "Nový (NEPOUZIVAT GR - Správa pohľadávok)" | datetime / date | ticketstages | 13 | 0 % |  |
| `hs_v2_date_exited_644200` | Date exited "Spracovávaný (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 76 | 0,1 % |  |
| `hs_v2_date_exited_644201` | Date exited "Zatvorený (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 52 | 0,1 % |  |
| `hs_v2_date_exited_644202` | Date exited "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 93 | 0,2 % |  |
| `hs_v2_date_exited_644205` | Date exited "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_exited_644207` | Date exited "Iné (NEPOUZIVAT GR - Frontoffice)" | datetime / date | ticketstages | 1 | 0 % |  |
| `hs_v2_date_exited_753378` | Date exited "Nový (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 220 | 0,4 % |  |
| `hs_v2_date_exited_753379` | Date exited "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 30 | 0 % |  |
| `hs_v2_date_exited_753380` | Date exited "Iné (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_exited_753381` | Date exited "Spracovávaný (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 28 | 0 % |  |
| `hs_v2_date_exited_753382` | Date exited "Zatvorené (NEPOUZIVAT TWL - Správa pohľadávok)" | datetime / date | ticketstages | 21 | 0 % |  |
| `hs_v2_date_exited_753386` | Date exited "Nový (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 442 | 0,7 % |  |
| `hs_v2_date_exited_753387` | Date exited "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 117 | 0,2 % |  |
| `hs_v2_date_exited_753388` | Date exited "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 3 | 0 % |  |
| `hs_v2_date_exited_753389` | Date exited "Spracovávaný (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 81 | 0,1 % |  |
| `hs_v2_date_exited_753391` | Date exited "Zatvorený (NEPOUZIVAT TWL - Frontoffice)" | datetime / date | ticketstages | 34 | 0,1 % |  |
| `hs_v2_date_exited_753394` | Date exited "Nový (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 678 | 1,1 % |  |
| `hs_v2_date_exited_753395` | Date exited "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 4 312 | 7 % |  |
| `hs_v2_date_exited_753396` | Date exited "Čakáme na vyjadrenie PDS (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 84 | 0,1 % |  |
| `hs_v2_date_exited_753397` | Date exited "Čakáme na vyjadrenie pôv.dodávateľa (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 7 | 0 % |  |
| `hs_v2_date_exited_753398` | Date exited "Iné (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 7 | 0 % |  |
| `hs_v2_date_exited_753399` | Date exited "Spracovávaný (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 157 | 0,3 % |  |
| `hs_v2_date_exited_753400` | Date exited "Zatvorený (NEPOUZIVAT TWL - Backoffice)" | datetime / date | ticketstages | 4 130 | 6,7 % |  |
| `hs_v2_date_exited_92916080` | Date exited "Nový (Výkup elektriny)" | datetime / date | ticketstages | 2 | 0 % |  |
| `hs_v2_latest_time_in_1` | Latest time in "Nový (Office)" | number / number | ticketstages | 56 445 | 91,4 % |  |
| `hs_v2_latest_time_in_10559238` | Latest time in "Čakáme na zmenu legislatívy (Office)" | number / number | ticketstages | 28 | 0 % |  |
| `hs_v2_latest_time_in_11398928` | Latest time in "Aktualizovaný /zákazníkom/ (Office)" | number / number | ticketstages | 13 408 | 21,7 % |  |
| `hs_v2_latest_time_in_1259356` | Latest time in "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_1259396` | Latest time in "Čakáme na vyjadrenie obchodníka (Office)" | number / number | ticketstages | 1 119 | 1,8 % |  |
| `hs_v2_latest_time_in_1259397` | Latest time in "Čakáme na vyjadrenie obchodníka (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 38 | 0,1 % |  |
| `hs_v2_latest_time_in_1259398` | Latest time in "Čakáme na vyjadrenia obchodníka (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 9 | 0 % |  |
| `hs_v2_latest_time_in_165449580` | Latest time in "Aktualizovný /obchodníkom/ (Office)" | number / number | ticketstages | 744 | 1,2 % |  |
| `hs_v2_latest_time_in_18941836` | Latest time in "Odložený - zaparkovaný (Office)" | number / number | ticketstages | 375 | 0,6 % |  |
| `hs_v2_latest_time_in_2` | Latest time in "Čakáme na vyjadrenie zákazníka (Office)" | number / number | ticketstages | 3 950 | 6,4 % |  |
| `hs_v2_latest_time_in_2413906` | Latest time in "Znovuotvorený (Office)" | number / number | ticketstages | 6 732 | 10,9 % |  |
| `hs_v2_latest_time_in_2413920` | Latest time in "Znovu otvorený (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_2413923` | Latest time in "Znovu otvorený (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_3` | Latest time in "Spracovávaný (Office)" | number / number | ticketstages | 7 339 | 11,9 % |  |
| `hs_v2_latest_time_in_4` | Latest time in "Zatvorený (Office)" | number / number | ticketstages | 14 780 | 23,9 % |  |
| `hs_v2_latest_time_in_606577` | Latest time in "Čakáme na vyjadrenie PDS (Office)" | number / number | ticketstages | 3 282 | 5,3 % |  |
| `hs_v2_latest_time_in_606578` | Latest time in "Čakáme na vyjadrenie pôvod. dodávateľa (Office)" | number / number | ticketstages | 314 | 0,5 % |  |
| `hs_v2_latest_time_in_606585` | Latest time in "Iné (Office)" | number / number | ticketstages | 45 | 0,1 % |  |
| `hs_v2_latest_time_in_641780` | Latest time in "Spracovávaný (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 5 | 0 % |  |
| `hs_v2_latest_time_in_641781` | Latest time in "Zatvorený (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 64 | 0,1 % |  |
| `hs_v2_latest_time_in_641782` | Latest time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 4 | 0 % |  |
| `hs_v2_latest_time_in_644185` | Latest time in "Nový (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 236 | 0,4 % |  |
| `hs_v2_latest_time_in_644187` | Latest time in "Nový (NEPOUZIVAT GR - Správa pohľadávok)" | number / number | ticketstages | 13 | 0 % |  |
| `hs_v2_latest_time_in_644200` | Latest time in "Spracovávaný (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 76 | 0,1 % |  |
| `hs_v2_latest_time_in_644201` | Latest time in "Zatvorený (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 52 | 0,1 % |  |
| `hs_v2_latest_time_in_644202` | Latest time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 93 | 0,2 % |  |
| `hs_v2_latest_time_in_644205` | Latest time in "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_644207` | Latest time in "Iné (NEPOUZIVAT GR - Frontoffice)" | number / number | ticketstages | 1 | 0 % |  |
| `hs_v2_latest_time_in_753378` | Latest time in "Nový (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 220 | 0,4 % |  |
| `hs_v2_latest_time_in_753379` | Latest time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 30 | 0 % |  |
| `hs_v2_latest_time_in_753380` | Latest time in "Iné (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_753381` | Latest time in "Spracovávaný (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 28 | 0 % |  |
| `hs_v2_latest_time_in_753382` | Latest time in "Zatvorené (NEPOUZIVAT TWL - Správa pohľadávok)" | number / number | ticketstages | 21 | 0 % |  |
| `hs_v2_latest_time_in_753386` | Latest time in "Nový (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 442 | 0,7 % |  |
| `hs_v2_latest_time_in_753387` | Latest time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 117 | 0,2 % |  |
| `hs_v2_latest_time_in_753388` | Latest time in "Čakáme na vyjadrenie pôv. dodávateľa (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 3 | 0 % |  |
| `hs_v2_latest_time_in_753389` | Latest time in "Spracovávaný (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 81 | 0,1 % |  |
| `hs_v2_latest_time_in_753391` | Latest time in "Zatvorený (NEPOUZIVAT TWL - Frontoffice)" | number / number | ticketstages | 34 | 0,1 % |  |
| `hs_v2_latest_time_in_753394` | Latest time in "Nový (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 678 | 1,1 % |  |
| `hs_v2_latest_time_in_753395` | Latest time in "Čakáme na vyjadrenie zákazníka (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 4 312 | 7 % |  |
| `hs_v2_latest_time_in_753396` | Latest time in "Čakáme na vyjadrenie PDS (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 84 | 0,1 % |  |
| `hs_v2_latest_time_in_753397` | Latest time in "Čakáme na vyjadrenie pôv.dodávateľa (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 7 | 0 % |  |
| `hs_v2_latest_time_in_753398` | Latest time in "Iné (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 7 | 0 % |  |
| `hs_v2_latest_time_in_753399` | Latest time in "Spracovávaný (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 157 | 0,3 % |  |
| `hs_v2_latest_time_in_753400` | Latest time in "Zatvorený (NEPOUZIVAT TWL - Backoffice)" | number / number | ticketstages | 4 130 | 6,7 % |  |
| `hs_v2_latest_time_in_92916080` | Latest time in "Nový (Výkup elektriny)" | number / number | ticketstages | 2 | 0 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | ticketstages | 12 251 | 19,8 % | výpočet |

#### HubSpot vlastnosti bez dát (189)

`hs_added_to_waitlist_at`, `hs_callback_fulfilled_at`, `hs_callback_original_wait_seconds`, `hs_callback_requested_at`, `hs_feedback_last_nps_rating_number`, `hs_feedback_last_survey_date`, `hs_in_waitlist`, `hs_last_nps_survey_comment`, `hs_mentions_resolved_user_ids`, `hs_retroactive_sla_update_at`, `hs_snoozed_by_user_ids`, `hs_snoozed_for_portal`, `hs_waitlist_routing_targets`, `hs_waitlist_sort_value`, `hs_cx_negative_signals`, `hs_cx_negative_signals_v1`, `hs_cx_positive_signals`, `hs_cx_positive_signals_v1`, `hs_all_topics_added_by_user`, `hs_all_topics_mentioned`, `hs_all_topics_removed_by_user`, `hs_applied_sla_rule_config_at`, `hs_applied_sla_rule_config_id`, `hs_applied_sla_schedule_at`, `hs_applied_sla_schedule_id`, `hs_copied_at`, `hs_copied_by_user`, `hs_copied_from_ticket`, `hs_copied_ticket_source`, `hs_custom_inbox`, `hs_customer_agent_escalated_time`, `hs_customer_agent_matched_segment`, `hs_customer_agent_status_updated_time`, `hs_customer_agent_ticket_status`, `hs_cx_score_range`, `hs_exclude_from_cx_score`, `hs_exclude_from_qa_score`, `hs_external_object_ids`, `hs_feedback_last_ces_follow_up`, `hs_feedback_last_ces_rating`, `hs_first_assignee_type`, `hs_has_live_chat_ended_or_email_sent`, `hs_help_desk_onboarding_ticket`, `hs_inbox_id`, `hs_is_closed_in_time_to_close_sla_count`, `hs_is_closed_in_time_to_first_response_sla_count`, `hs_most_relevant_sla_status`, `hs_most_relevant_sla_type`, `hs_msteams_message_id`, `hs_object_source_detail_3`, `hs_outbound_ticket`, `hs_predicted_cx_score`, `hs_predicted_cx_score_evidence`, `hs_primary_topic`, `hs_primary_topic_drilldown_1`, `hs_primary_topic_drilldown_2`, `hs_read_only`, `hs_resolution`, `hs_shared_team_ids`, `hs_sla_operating_hours`, `hs_sla_pause_status`, `hs_source_object_id`, `hs_summarized_ticket_owner_type`, `hs_ticket_owner_type`, `hs_time_to_close_in_operating_hours`, `hs_time_to_close_sla_at`, `hs_time_to_close_sla_status`, `hs_time_to_first_assign`, `hs_time_to_first_response_in_operating_hours`, `hs_time_to_first_response_sla_at`, `hs_time_to_first_response_sla_status`, `hs_time_to_next_response_sla_at`, `hs_time_to_next_response_sla_status`, `hs_unique_creation_key`, `hs_user_ids_of_all_notification_unfollowers`, `hs_was_imported`, `nps_follow_up_answer`, `nps_follow_up_question_version`, `nps_score`, `source_ref`, `source_thread_id`, `tags`, `hs_v2_cumulative_time_in_10560411`, `hs_v2_cumulative_time_in_1127922251`, `hs_v2_cumulative_time_in_1127922252`, `hs_v2_cumulative_time_in_1127922253`, `hs_v2_cumulative_time_in_1127922254`, `hs_v2_cumulative_time_in_1127970108`, `hs_v2_cumulative_time_in_1127970109`, `hs_v2_cumulative_time_in_1127970110`, `hs_v2_cumulative_time_in_1127970111`, `hs_v2_cumulative_time_in_1127970112`, `hs_v2_cumulative_time_in_165350572`, `hs_v2_cumulative_time_in_2413907`, `hs_v2_cumulative_time_in_2413921`, `hs_v2_cumulative_time_in_2413922`, `hs_v2_cumulative_time_in_641783`, `hs_v2_cumulative_time_in_753390`, `hs_v2_cumulative_time_in_92916081`, `hs_v2_cumulative_time_in_92916082`, `hs_v2_cumulative_time_in_92916083`, `hs_v2_cumulative_time_in_92929715`, `hs_v2_cumulative_time_in_92929716`, `hs_v2_cumulative_time_in_92929717`, `hs_v2_cumulative_time_in_92929718`, `hs_v2_cumulative_time_in_92929719`, `hs_v2_cumulative_time_in_92929720`, `hs_v2_cumulative_time_in_92929721`, `hs_v2_cumulative_time_in_92929792`, `hs_v2_date_entered_10560411`, `hs_v2_date_entered_1127922251`, `hs_v2_date_entered_1127922252`, `hs_v2_date_entered_1127922253`, `hs_v2_date_entered_1127922254`, `hs_v2_date_entered_1127970108`, `hs_v2_date_entered_1127970109`, `hs_v2_date_entered_1127970110`, `hs_v2_date_entered_1127970111`, `hs_v2_date_entered_1127970112`, `hs_v2_date_entered_165350572`, `hs_v2_date_entered_2413907`, `hs_v2_date_entered_2413921`, `hs_v2_date_entered_2413922`, `hs_v2_date_entered_641783`, `hs_v2_date_entered_753390`, `hs_v2_date_entered_92916081`, `hs_v2_date_entered_92916082`, `hs_v2_date_entered_92929715`, `hs_v2_date_entered_92929716`, `hs_v2_date_entered_92929717`, `hs_v2_date_entered_92929718`, `hs_v2_date_entered_92929719`, `hs_v2_date_entered_92929720`, `hs_v2_date_entered_92929721`, `hs_v2_date_entered_92929792`, `hs_v2_date_exited_10560411`, `hs_v2_date_exited_1127922251`, `hs_v2_date_exited_1127922252`, `hs_v2_date_exited_1127922253`, `hs_v2_date_exited_1127922254`, `hs_v2_date_exited_1127970108`, `hs_v2_date_exited_1127970109`, `hs_v2_date_exited_1127970110`, `hs_v2_date_exited_1127970111`, `hs_v2_date_exited_1127970112`, `hs_v2_date_exited_165350572`, `hs_v2_date_exited_2413907`, `hs_v2_date_exited_2413921`, `hs_v2_date_exited_2413922`, `hs_v2_date_exited_641783`, `hs_v2_date_exited_753390`, `hs_v2_date_exited_92916081`, `hs_v2_date_exited_92916082`, `hs_v2_date_exited_92916083`, `hs_v2_date_exited_92929715`, `hs_v2_date_exited_92929716`, `hs_v2_date_exited_92929717`, `hs_v2_date_exited_92929718`, `hs_v2_date_exited_92929719`, `hs_v2_date_exited_92929720`, `hs_v2_date_exited_92929721`, `hs_v2_date_exited_92929792`, `hs_v2_latest_time_in_10560411`, `hs_v2_latest_time_in_1127922251`, `hs_v2_latest_time_in_1127922252`, `hs_v2_latest_time_in_1127922253`, `hs_v2_latest_time_in_1127922254`, `hs_v2_latest_time_in_1127970108`, `hs_v2_latest_time_in_1127970109`, `hs_v2_latest_time_in_1127970110`, `hs_v2_latest_time_in_1127970111`, `hs_v2_latest_time_in_1127970112`, `hs_v2_latest_time_in_165350572`, `hs_v2_latest_time_in_2413907`, `hs_v2_latest_time_in_2413921`, `hs_v2_latest_time_in_2413922`, `hs_v2_latest_time_in_641783`, `hs_v2_latest_time_in_753390`, `hs_v2_latest_time_in_92916081`, `hs_v2_latest_time_in_92916082`, `hs_v2_latest_time_in_92916083`, `hs_v2_latest_time_in_92929715`, `hs_v2_latest_time_in_92929716`, `hs_v2_latest_time_in_92929717`, `hs_v2_latest_time_in_92929718`, `hs_v2_latest_time_in_92929719`, `hs_v2_latest_time_in_92929720`, `hs_v2_latest_time_in_92929721`, `hs_v2_latest_time_in_92929792`

#### Možnosti výberových polí

- **`anoodlozene`** (AnoOdlozene): `true` = Yes; `false` = No
- **`green_solar_produkt`** (Green SOLAR produkt): `3,75 kWp` = 3,24 kWp; `4,05 kWp` = 4,05 kWp; `5,27 kWp` = 5,27 kWp; `6,00 kWp` = 7,29 kWp; `10,125 kWp` = 10,125 kWp; `Individual` = Individual
- **`kampan`** (Kampaň): `NEP` = NEP
- **`komodita_slu_ba`** (Produkt): `Elektrina` = Zelená elektrina; `Zelená elektrina + VBattery` = Zelená elektrina + VBattery; `Fotovoltika - malý zdroj do 10kW` = Malý zdroj do 10kW; `Lokálny/Výrobný zdroj` = Lokálny/Výrobný zdroj; `Zelená elektrina + vBattery / virtuálna batéria` = VBattery; `GreenShare` = GreenShare; `Zelená elektrina + eAuto` = GreenCar; `GreenSolar` = GreenSolar; `Iné` = Iné; `GreenViWA` = Green ViWA
- **`notifikacia_emailom`** (Notifikácia emailom): `Áno` = Áno; `Nie` = Nie
- **`prajete_si_vypracovat_cenovu_ponuku_aj_na_dodavku_elektriny_`** (Prajete si vypracovať cenovú ponuku aj na dodávku elektriny?): `Áno.` = Áno.; `Nie, ďakujem.` = Nie, ďakujem.
- **`segment`** (Segment): `Domácnosť` = Domácnosť; `Firma` = Firma
- **`standardy_kvality`** (Štandardy kvality): `a_overenie správnosti vyúčtovania platby` = a_overenie správnosti vyúčtovania platby; `b_odstránenie nedostatkov vo vyúčtovaní` = b_odstránenie nedostatkov vo vyúčtovaní; `c_odoslanie platby podľa opravného účtovného dokladu` = c_odoslanie platby podľa opravného účtovného dokladu; `d_požiadanie o obnovenie distribúcie elektriny` = d_požiadanie o obnovenie distribúcie elektriny; `e_odoslanie podania odberateľa na PDS` = e_odoslanie podania odberateľa na PDS; `f_predloženie podpísaného návrhu zmluvy o dodávke elektriny` = f_predloženie podpísaného návrhu zmluvy o dodávke elektriny; `g_odoslanie kompenzačnej platby a oznámenia` = g_odoslanie kompenzačnej platby a oznámenia; `h_oznámenie/odoslanie stanoviska k podaniu týkajúcemu sa sumy záloh / zmeny sadzby odberu` = h_oznámenie/odoslanie stanoviska k podaniu týkajúcemu sa sumy záloh / zmeny sadzby odberu; `i_poskytnutie informácie o každej zmene ceny/VOP za dodávku` = i_poskytnutie informácie o každej zmene ceny/VOP za dodávku; `j_odoslanie alebo predloženie podpísaného návrhu_návrat do regulácie` = j_odoslanie alebo predloženie podpísaného návrhu_návrat do regulácie; `k_vyhotovenie vyúčtovacej faktúry v lehote podľa  zmluvy` = k_vyhotovenie vyúčtovacej faktúry v lehote podľa  zmluvy
- **`typ_kontaktu`** (Typ kontaktu): `Lead` = Lead; `Subscriber` = Subscriber; `Opportunity` = Opportunity; `Customer` = Customer; `Other` = Other; `Evangelist` = Evangelist; `Odídený` = Odídený
- **`zelate_si_vypracovat_cenovu_ponuku_aj_na_dodavku_elektriny_`** (Želáte si vypracovať cenovú ponuku aj na dodávku elektriny?): `true` = Yes; `false` = No
- **`zelena_domacnostiam`** (Zelená domácnostiam): `Uplatňujem poukážku` = Uplatňujem poukážku; `Neuplatňujem poukážku` = Neuplatňujem poukážku
- **`distribucna_oblast`** (Distribučná oblasť): `Západoslovenská distribučná a.s.` = Západoslovenská distribučná a.s.; `Stredoslovenská distribučná a.s.` = Stredoslovenská distribučná a.s.; `Východoslovenská distribučná a.s.` = Východoslovenská distribučná a.s.; `Iné` = Iné
- **`lokalny_zdroj1`** (Lokálny zdroj): `Áno` = Áno; `Nie` = Nie
- **`podpora_vyroby_elektriny_doplatkom_pripaltkom`** (Podpora výroby elektriny doplatkom/príplatkom): `Áno` = Áno; `Nie` = Nie
- **`typ_strechy`** (Typ strechy): `Rovná` = Rovná; `Šikmá` = Šikmá
- **`typ_vyrobneho_zdroja`** (Typ výrobného zdroja): `Slnko` = Slnko; `Voda` = Voda; `Bioplyn` = Bioplyn; `Biomasa` = Biomasa; `KVET` = KVET; `Vietor` = Vietor
- **`hs_assignment_method`** (Assignment Method): `0` = UNKNOWN; `1` = API_AGENT_MANUAL; `2` = API_BOTS_HANDOFF; `3` = SYSTEM_AUTOMATIC; `4` = SYSTEM_MIGRATION; `5` = SYSTEM_TEST; `6` = SKILL_BASED_ROUTING; `7` = ASSIGN_CONVERSATION_OWNER_ACTION; `8` = AI_CHATBOT_HANDOFF; `9` = ROTATE_OWNER_ACTION; `10` = WAITLIST; `11` = ROTATE_CONVERSATION_OWNER_ACTION; `12` = ASSIGN_TO_CUSTOMER_AGENT_ACTION; `13` = API_PUBLIC; `14` = ROTATE_OWNER_BY_SKILL_ACTION
- **`hs_first_visitor_message_sentiment`** ((Deprecated) First message sentiment): `Positive` = Positive; `Neutral` = Neutral; `Negative` = Negative
- **`hs_last_visitor_message_sentiment`** ((Deprecated) Last message sentiment): `Positive` = Positive; `Neutral` = Neutral; `Negative` = Negative
- **`hs_overall_visitor_messages_sentiment`** ((Deprecated) Average ticket sentiment): `Positive` = Positive; `Neutral` = Neutral; `Negative` = Negative
- **`hs_ticket_language_ai_tag`** (Language): `af` = Afrikaans; `als` = Alsatian; `am` = Amharic; `an` = Aragonese; `ar` = Arabic; `arz` = Egyptian Arabic; `as` = Assamese; `ast` = Asturian; `av` = Avaric; `az` = Azerbaijani; `azb` = South Azerbaijani; `ba` = Bashkir; `bar` = Bavarian; `bcl` = Central Bikol; `be` = Belarusian; `bg` = Bulgarian; `bh` = Bhojpuri; `bn` = Bengali; `bo` = Tibetan; `bpy` = Bishnupriya; `br` = Breton; `bs` = Bosnian; `bxr` = Buryat; `ca` = Catalan; `cbk` = Chavacano; `ce` = Chechen; `ceb` = Cebuano; `ckb` = Central Kurdish; `co` = Corsican; `cs` = Czech; `cv` = Chuvash; `cy` = Welsh; `da` = Danish; `de` = German; `diq` = Zazaki; `dsb` = Lower Sorbian; `dty` = Doteli; `dv` = Divehi; `el` = Greek; `eml` = Emilian; `en` = English; `eo` = Esperanto; `es` = Spanish; `et` = Estonian; `eu` = Basque; `fa` = Persian; `fi` = Finnish; `fr` = French; `frr` = Northern Frisian; `fy` = Western Frisian … a ďalších 121
- **`hs_in_helpdesk`** (In Help Desk): `true` = True; `false` = False
- **`hs_is_closed`** (Closed): `true` = True; `false` = False
- **`hs_is_latest_message_failed`** (Is latest message failed): `true` = Yes; `false` = No
- **`hs_is_latest_message_hidden_from_all`** (Is latest message hidden from all): `true` = Yes; `false` = No
- **`hs_is_one_touch_ticket`** (First contact resolution): `true` = Yes; `false` = No
- **`hs_is_visible_in_help_desk`** (Is Visible in Help desk): `true` = Yes; `false` = No
- **`hs_last_email_activity`** (Last email activity): `ORIGINAL_FROM_CONTACT` = First email received from contact; `SENT_TO_CONTACT` = Email sent to contact; `REPLY_FROM_CONTACT` = Email received from contact
- **`hs_last_message_from_visitor`** (Last message from visitor): `true` = True; `false` = False
- **`hs_latest_message_attachment_types`** (Latest message attachment types): `0` = Files; `1` = Inline Images; `2` = Quick Replies; `3` = Mentions; `4` = Email Metadata; `5` = Rich Media Templates; `6` = Call Metadata; `7` = Message Position Descriptor; `8` = Location; `9` = Message Header; `10` = Contact Attachment; `11` = WhatsApp Template Metadata; `12` = Unsupported Content Attachment
- **`hs_latest_message_is_forwarded_email`** (Latest message is forwarded email): `true` = Yes; `false` = No
- **`hs_latest_message_is_thread_comment`** (Latest message is thread comment): `true` = Yes; `false` = No
- **`hs_notes_next_activity_type`** (Next Activity Type): `CALL` = Call; `CONVERSATION_SESSION` = Conversation session; `INCOMING_EMAIL` = Email reply from contact; `EMAIL` = Email sent to contact; `FORWARDED_EMAIL` = Forwarded email; `LINKEDIN_MESSAGE` = LinkedIn message; `MEETING` = Meeting; `NOTE` = Note; `POSTAL_MAIL` = Postal mail; `PUBLISHING_TASK` = Publishing task; `SMS` = SMS; `TASK` = Task; `WHATS_APP` = WhatsApp
- **`hs_ticket_category`** (Category): `Zmluva` = Zmluvy; `Zmenový proces` = Zmenový proces; `Zmena údajov` = Oprava údajov; `Fakturácia` = Fakturácia; `FIN-Uhrady-Zapocty-Pohladavky` = Správa pohľadávok; `Aktivácia služby/zmena programu` = Aktivácia služby/zmena programu; `OM-Pripojenia-Ukoncenia` = Pripojenie_Odpojenie, služby PDS; `Otázka` = Otázky - Všeobecné; `Cenová ponuka` = Cenová ponuka - Kalkulácia; `Kontaktovanie klienta` = Kontaktovanie klienta; `Reklamacie` = Reklamácie; `Hibern. CP VBatt domacnosti` = Hibern. CP VBatt domacnosti
- **`hs_ticket_priority`** (Priority): `LOW` = Low; `MEDIUM` = Medium; `HIGH` = High; `URGENT` = Urgent
- **`source_type`** (Source): `CHAT` = Chat; `EMAIL` = Email; `FORM` = Form; `PHONE` = Telefón

### OOM (`2-16666415`)

Vlastností spolu: 220 (vlastné 84, HubSpot 136). Záznamov: 10 151.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `bateriove_ulozisko` | Batériové úložisko | enumeration / radio | batériové_úložisko | 90 | 0,9 % | 3 možností |
| `bess__kapacita_v_kwh` | BESS - kapacita v kWh | number / number | batériové_úložisko | 88 | 0,9 % |  |
| `bess__typ` | BESS - typové označenie | string / text | batériové_úložisko | 9 | 0,1 % |  |
| `bess__vyrobca` | BESS - výrobca | string / text | batériové_úložisko | 9 | 0,1 % |  |
| `dot__datum` | Dotazník – dátum vyplnenia | date / date | dotaznik | 4 | 0 % |  |
| `dot__fotky` | Dotazník – fotky štítkov | string / textarea | dotaznik | 0 | 0 % |  |
| `dot__poznamka` | Dotazník – poznámka klienta | string / textarea | dotaznik | 0 | 0 % |  |
| `dot__vyplnil` | Dotazník – vyplnil (e-mail) | string / text | dotaznik | 4 | 0 % |  |
| `dot__zaujem` | Dotazník – záujem o služby | enumeration / checkbox | dotaznik | 4 | 0 % | 6 možností |
| `fotovoltika` | Fotovoltika | enumeration / radio | fotovoltika | 3 535 | 34,8 % | 3 možností |
| `fv__kto_vam_fve_instaloval` | FV - kto Vám FVE inštaloval | string / text | fotovoltika | 46 | 0,5 % |  |
| `fv__pocet_panelov` | FV - počet panelov | number / number | fotovoltika | 47 | 0,5 % |  |
| `fv__pocet_stringov` | FV - počet stringov | number / number | fotovoltika | 46 | 0,5 % |  |
| `fv__typ_panelov` | FV - typ panelov | string / text | fotovoltika | 46 | 0,5 % |  |
| `fv__vykon_panelov` | FV - výkon panelov | number / number | fotovoltika | 2 746 | 27,1 % |  |
| `fve__vyrobca_panelov` | FV - výrobca panelov | string / text | fotovoltika | 47 | 0,5 % |  |
| `ak_mam_ims__chcem_vyuctovanie__cloned_` | Ak mám IMS, chcem vyúčtovanie | string / text | obchodné_dáta | 5 | 0 % |  |
| `akceptacia_vypovede_ineho_dodavatela_k_datumu` | Akceptácia výpovede iného dodávateľa k dátumu | date / date | obchodné_dáta | 1 423 | 14 % |  |
| `cenova_regulacia` | Cenová regulácia | string / text | obchodné_dáta | 10 107 | 99,6 % |  |
| `cislo_greenlogy_zmluvy` | Číslo Greenlogy zmluvy | string / text | obchodné_dáta | 10 119 | 99,7 % |  |
| `cislo_zmluvy_greenlogy` | Číslo zmluvy Greenlogy | string / textarea | obchodné_dáta | 7 492 | 73,8 % |  |
| `fakturacne_obdobie` | Fakturačné obdobie | string / text | obchodné_dáta | 10 103 | 99,5 % |  |
| `obchodnik` | Obchodník | string / text | obchodné_dáta | 10 140 | 99,9 % |  |
| `sposob_zalohovych_faktur` | Spôsob zálohových faktúr | string / text | obchodné_dáta | 10 104 | 99,5 % |  |
| `spotrebna_dan` | Spotrebná daň | string / text | obchodné_dáta | 10 104 | 99,5 % |  |
| `subjekt` | Subjekt | string / text | obchodné_dáta | 10 151 | 100 % |  |
| `trvanie_zmluvy_new` | Trvanie zmluvy_NEW | enumeration / checkbox | obchodné_dáta | 10 123 | 99,7 % | 10 možností |
| `typ_vykupnej_zmluvy` | Typ výkupnej zmluvy | enumeration / select | obchodné_dáta | 1 008 | 9,9 % | 5 možností |
| `vypoved_predoslemu_dodavatelovi` | Akceptácia výpovede inému dodávateľovi | enumeration / select | obchodné_dáta | 6 737 | 66,4 % | 5 možností |
| `zalohova_platba____` | Zálohová platba [%] | string / text | obchodné_dáta | 10 106 | 99,6 % |  |
| `celkova_spotreba_na_oom__mwh_` | SUM_[MWh] na OOM | number / calculation_equation | objemy_[mwh] | 10 150 | 100 % | výpočet |
| `planovana_spotreba_1t_vt__mwh_` | Plánovaná spotreba_1T/VT [MWh] | number / number | objemy_[mwh] | 10 151 | 100 % |  |
| `planovana_spotreba_nt__mwh_` | Plánovaná spotreba_NT [MWh] | number / number | objemy_[mwh] | 10 151 | 100 % |  |
| `planovany_objem_vykupu__mwh_` | Plánovaný objem výkupu [MWh] | number / number | objemy_[mwh] | 10 150 | 100 % |  |
| `claude_audit` | Claude audit | enumeration / select | oom_information | 8 370 | 82,5 % | 2 možností |
| `nazov_om` | Nazov OM | string / text | oom_information | 13 | 0,1 % |  |
| `fv__monitoring` | Aplikácia na sledovanie výroby | string / text | striedac | 1 | 0 % |  |
| `fv__pretoky` | Posielate prebytky do siete | enumeration / select | striedac | 48 | 0,5 % | 3 možností |
| `fve_striedac` | Striedač - výrobca | enumeration / select | striedac | 48 | 0,5 % | 18 možností |
| `st__druh` | Striedač – druh | enumeration / select | striedac | 48 | 0,5 % | 3 možností |
| `st__pocet` | Striedač – počet | number / number | striedac | 49 | 0,5 % |  |
| `st__typ` | Striedač – typové označenie | string / text | striedac | 48 | 0,5 % |  |
| `st__vykon_kw` | Striedač – výkon [kW] | number / number | striedac | 2 747 | 27,1 % |  |
| `st__wifi` | Wi-Fi pri striedači | enumeration / select | striedac | 1 | 0 % | 2 možností |
| `adresa_obec` | Adresa_Obec | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `adresa_orientacne_c_` | Adresa_Orientačné č. | string / text | technické_dáta | 4 | 0 % |  |
| `adresa_psc` | Adresa_PSČ | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `adresa_supisne_c_` | Adresa_Súpisné č. | string / text | technické_dáta | 12 | 0,1 % |  |
| `adresa_ulica` | Adresa_Ulica | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `description` | Description | string / text | technické_dáta | 0 | 0 % |  |
| `druh_vyrobneho_zdroja` | Druh výrobného zdroja | enumeration / select | technické_dáta | 3 608 | 35,5 % | 6 možností |
| `eic` | EIC | string / text | technické_dáta | 10 146 | 100 % |  |
| `ico` | IČO | string / text | technické_dáta | 0 | 0 % |  |
| `identifikator_pds__cislo_op_` | Identifikátor PDS [číslo OP] | string / text | technické_dáta | 10 086 | 99,4 % |  |
| `mam_ims` | Mám IMS | string / text | technické_dáta | 5 | 0 % |  |
| `maximalna_rezervovana_kapacita__kw_` | Maximálna rezervovaná kapacita [kW] | number / number | technické_dáta | 10 105 | 99,5 % |  |
| `napatova_uroven` | Napäťová úroveň | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `pds` | PDS | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `pocet_faz` | Počet fáz | string / text | technické_dáta | 10 103 | 99,5 % |  |
| `rezervovana_kapacita__kw_` | Rezervovaná kapacita [kW] | number / number | technické_dáta | 10 068 | 99,2 % |  |
| `sadzba_pds` | Sadzba PDS | string / text | technické_dáta | 10 105 | 99,5 % |  |
| `sposob_rezervovania_kapacity` | Spôsob rezervovania kapacity | string / text | technické_dáta | 10 067 | 99,2 % |  |
| `stav_oom` | Stav OOM | enumeration / select | technické_dáta | 10 146 | 100 % | 6 možností |
| `typ_merania` | Typ merania | string / text | technické_dáta | 10 107 | 99,6 % |  |
| `typ_odberu` | Typ odberu | enumeration / select | technické_dáta | 10 141 | 99,9 % | 2 možností |
| `typ_oom` | Typ OOM | string / text | technické_dáta | 10 151 | 100 % |  |
| `typ_zdroja` | Typ zdroja | enumeration / select | technické_dáta | 3 608 | 35,5 % | 4 možností |
| `typ_zdroja_podla_eic` | Typ zdroja podľa EIC | string / text | technické_dáta | 10 101 | 99,5 % |  |
| `ucinnost_oom_do` | Účinnosť OOM do | date / date | technické_dáta | 10 151 | 100 % |  |
| `ucinnost_oom_od` | Účinnosť OOM od | date / date | technické_dáta | 10 149 | 100 % |  |
| `velkost_istica__a_` | Veľkosť ističa [A] | number / number | technické_dáta | 10 102 | 99,5 % |  |
| `vykon_zdroja__kw_` | Výkon zdroja [kW] | number / number | technické_dáta | 10 151 | 100 % |  |
| `xml433domacnosti_eic` | XML433Domacnosti_eic | string / text | technické_dáta | 0 | 0 % |  |
| `tc__ohrev_teplej_vody` | TČ - Ohrev teplej vody | enumeration / checkbox | tepelné_čerpadlo | 1 | 0 % | 2 možností |
| `tc__podporuje_sg_ready__externe_riadenie` | TČ - Podporuje externé riadenie? | enumeration / radio | tepelné_čerpadlo | 0 | 0 % | 2 možností |
| `tc__tepelny_vykon_v_kw` | TČ - tepelný výkon v kW | number / number | tepelné_čerpadlo | 1 | 0 % |  |
| `tc__typ` | TČ - typové označenie | string / text | tepelné_čerpadlo | 1 | 0 % |  |
| `tc__vyrobca` | TČ - výrobca | string / text | tepelné_čerpadlo | 1 | 0 % |  |
| `tepelne_cerpadlo` | Tepelné čerpadlo | enumeration / radio | tepelné_čerpadlo | 224 | 2,2 % | 3 možností |
| `wallbox` | Wallbox | enumeration / radio | wallbox | 1 | 0 % | 3 možností |
| `wb__nabijaci_vykon_v_kw` | WB - nabíjací výkon v kW | number / number | wallbox | 0 | 0 % |  |
| `wb__pocet_elektromobilov` | WB - počet elektromobilov | number / number | wallbox | 154 | 1,5 % |  |
| `wb__typove_oznacenie` | WB - typové označenie | string / text | wallbox | 0 | 0 % |  |
| `wb__vyrobca` | WB - výrobca | string / text | wallbox | 0 | 0 % |  |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_v2_cumulative_time_in_1041960295` | Cumulative time in "Aktívne (Elektrina - Sharing)" | number / number | customobjectstages | 585 | 5,8 % |  |
| `hs_v2_cumulative_time_in_1041960296` | Cumulative time in "Neaktívne (Elektrina - Sharing)" | number / number | customobjectstages | 424 | 4,2 % |  |
| `hs_v2_cumulative_time_in_130379833` | Cumulative time in "Aktívne (Elektrina_vyroba)" | number / number | customobjectstages | 4 544 | 44,8 % |  |
| `hs_v2_cumulative_time_in_130379834` | Cumulative time in "Neaktívne (Elektrina_vyroba)" | number / number | customobjectstages | 3 554 | 35 % |  |
| `hs_v2_cumulative_time_in_144188057` | Cumulative time in "Aktívne (Elektrina - spotreba)" | number / number | customobjectstages | 5 426 | 53,5 % |  |
| `hs_v2_cumulative_time_in_144188058` | Cumulative time in "Neaktívne (Elektrina - spotreba)" | number / number | customobjectstages | 5 574 | 54,9 % |  |
| `hs_v2_cumulative_time_in_144977239` | Cumulative time in "Odídené (Elektrina_vyroba)" | number / number | customobjectstages | 32 | 0,3 % |  |
| `hs_v2_cumulative_time_in_144998702` | Cumulative time in "Odídené (Elektrina - spotreba)" | number / number | customobjectstages | 43 | 0,4 % |  |
| `hs_v2_cumulative_time_in_208648567` | Cumulative time in "Zrušené (Elektrina - spotreba)" | number / number | customobjectstages | 9 | 0,1 % |  |
| `hs_v2_cumulative_time_in_208657937` | Cumulative time in "Zrušené (Elektrina_vyroba)" | number / number | customobjectstages | 5 | 0 % |  |
| `hs_v2_date_entered_1041960295` | Date entered "Aktívne (Elektrina - Sharing)" | datetime / date | customobjectstages | 999 | 9,8 % |  |
| `hs_v2_date_entered_1041960296` | Date entered "Neaktívne (Elektrina - Sharing)" | datetime / date | customobjectstages | 491 | 4,8 % |  |
| `hs_v2_date_entered_1163219038` | Date entered "Aktívne (Elektrina_veľkoobchod)" | datetime / date | customobjectstages | 12 | 0,1 % |  |
| `hs_v2_date_entered_1163219039` | Date entered "Neaktívne (Elektrina_veľkoobchod)" | datetime / date | customobjectstages | 1 | 0 % |  |
| `hs_v2_date_entered_130379833` | Date entered "Aktívne (Elektrina_vyroba)" | datetime / date | customobjectstages | 5 435 | 53,5 % |  |
| `hs_v2_date_entered_130379834` | Date entered "Neaktívne (Elektrina_vyroba)" | datetime / date | customobjectstages | 3 716 | 36,6 % |  |
| `hs_v2_date_entered_144188057` | Date entered "Aktívne (Elektrina - spotreba)" | datetime / date | customobjectstages | 7 533 | 74,2 % |  |
| `hs_v2_date_entered_144188058` | Date entered "Neaktívne (Elektrina - spotreba)" | datetime / date | customobjectstages | 5 894 | 58,1 % |  |
| `hs_v2_date_entered_144977239` | Date entered "Odídené (Elektrina_vyroba)" | datetime / date | customobjectstages | 126 | 1,2 % |  |
| `hs_v2_date_entered_144998702` | Date entered "Odídené (Elektrina - spotreba)" | datetime / date | customobjectstages | 578 | 5,7 % |  |
| `hs_v2_date_entered_208648566` | Date entered "Prepísané (Elektrina - spotreba)" | datetime / date | customobjectstages | 1 | 0 % |  |
| `hs_v2_date_entered_208648567` | Date entered "Zrušené (Elektrina - spotreba)" | datetime / date | customobjectstages | 31 | 0,3 % |  |
| `hs_v2_date_entered_208657937` | Date entered "Zrušené (Elektrina_vyroba)" | datetime / date | customobjectstages | 13 | 0,1 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | customobjectstages | 10 151 | 100 % | výpočet |
| `hs_v2_date_exited_1041960295` | Date exited "Aktívne (Elektrina - Sharing)" | datetime / date | customobjectstages | 585 | 5,8 % |  |
| `hs_v2_date_exited_1041960296` | Date exited "Neaktívne (Elektrina - Sharing)" | datetime / date | customobjectstages | 424 | 4,2 % |  |
| `hs_v2_date_exited_130379833` | Date exited "Aktívne (Elektrina_vyroba)" | datetime / date | customobjectstages | 4 544 | 44,8 % |  |
| `hs_v2_date_exited_130379834` | Date exited "Neaktívne (Elektrina_vyroba)" | datetime / date | customobjectstages | 3 554 | 35 % |  |
| `hs_v2_date_exited_144188057` | Date exited "Aktívne (Elektrina - spotreba)" | datetime / date | customobjectstages | 5 426 | 53,5 % |  |
| `hs_v2_date_exited_144188058` | Date exited "Neaktívne (Elektrina - spotreba)" | datetime / date | customobjectstages | 5 574 | 54,9 % |  |
| `hs_v2_date_exited_144977239` | Date exited "Odídené (Elektrina_vyroba)" | datetime / date | customobjectstages | 32 | 0,3 % |  |
| `hs_v2_date_exited_144998702` | Date exited "Odídené (Elektrina - spotreba)" | datetime / date | customobjectstages | 43 | 0,4 % |  |
| `hs_v2_date_exited_208648567` | Date exited "Zrušené (Elektrina - spotreba)" | datetime / date | customobjectstages | 9 | 0,1 % |  |
| `hs_v2_date_exited_208657937` | Date exited "Zrušené (Elektrina_vyroba)" | datetime / date | customobjectstages | 5 | 0 % |  |
| `hs_v2_latest_time_in_1041960295` | Latest time in "Aktívne (Elektrina - Sharing)" | number / number | customobjectstages | 585 | 5,8 % |  |
| `hs_v2_latest_time_in_1041960296` | Latest time in "Neaktívne (Elektrina - Sharing)" | number / number | customobjectstages | 424 | 4,2 % |  |
| `hs_v2_latest_time_in_130379833` | Latest time in "Aktívne (Elektrina_vyroba)" | number / number | customobjectstages | 4 544 | 44,8 % |  |
| `hs_v2_latest_time_in_130379834` | Latest time in "Neaktívne (Elektrina_vyroba)" | number / number | customobjectstages | 3 554 | 35 % |  |
| `hs_v2_latest_time_in_144188057` | Latest time in "Aktívne (Elektrina - spotreba)" | number / number | customobjectstages | 5 426 | 53,5 % |  |
| `hs_v2_latest_time_in_144188058` | Latest time in "Neaktívne (Elektrina - spotreba)" | number / number | customobjectstages | 5 574 | 54,9 % |  |
| `hs_v2_latest_time_in_144977239` | Latest time in "Odídené (Elektrina_vyroba)" | number / number | customobjectstages | 32 | 0,3 % |  |
| `hs_v2_latest_time_in_144998702` | Latest time in "Odídené (Elektrina - spotreba)" | number / number | customobjectstages | 43 | 0,4 % |  |
| `hs_v2_latest_time_in_208648567` | Latest time in "Zrušené (Elektrina - spotreba)" | number / number | customobjectstages | 9 | 0,1 % |  |
| `hs_v2_latest_time_in_208657937` | Latest time in "Zrušené (Elektrina_vyroba)" | number / number | customobjectstages | 5 | 0 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | customobjectstages | 10 151 | 100 % | výpočet |
| `hubspot_owner_id` | Owner | enumeration / select | obchodné_dáta | 10 133 | 99,8 % |  |
| `hs_all_accessible_team_ids` | All teams | enumeration / checkbox | oom_information | 9 872 | 97,3 % |  |
| `hs_all_assigned_business_unit_ids` | Business units | enumeration / checkbox | oom_information | 33 | 0,3 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | oom_information | 10 151 | 100 % |  |
| `hs_createdate` | Object create date/time | datetime / date | oom_information | 10 151 | 100 % |  |
| `hs_lastmodifieddate` | Object last modified date/time | datetime / date | oom_information | 10 151 | 100 % |  |
| `hs_object_id` | Record ID | number / number | oom_information | 10 151 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | oom_information | 10 151 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | oom_information | 6 455 | 63,6 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | oom_information | 9 | 0,1 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | oom_information | 10 151 | 100 % |  |
| `hs_object_source_label` | Record source | enumeration / select | oom_information | 10 151 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | oom_information | 10 151 | 100 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | oom_information | 9 872 | 97,3 % |  |
| `hs_pinned_engagement_id` | Pinned Engagement ID | number / number | oom_information | 1 | 0 % |  |
| `hs_pipeline` | OOM pipeline | enumeration / select | oom_information | 10 151 | 100 % |  |
| `hs_pipeline_stage` | OOM pipeline stage | enumeration / select | oom_information | 10 151 | 100 % |  |
| `hs_unique_creation_key` | Unique creation key | string / text | oom_information | 2 841 | 28 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | oom_information | 10 151 | 100 % |  |
| `hs_user_ids_of_all_notification_recipients` | All 1. oom notification recipients | enumeration / checkbox | oom_information | 10 133 | 99,8 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | oom_information | 10 133 | 99,8 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | oom_information | 10 136 | 99,9 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | oom_information | 10 133 | 99,8 % |  |
| `hubspot_team_id` | Owner's main team | enumeration / select | oom_information | 9 872 | 97,3 % |  |

#### HubSpot vlastnosti bez dát (67)

`hs_v2_cumulative_time_in_1041956472`, `hs_v2_cumulative_time_in_1163219038`, `hs_v2_cumulative_time_in_1163219039`, `hs_v2_cumulative_time_in_208648566`, `hs_v2_cumulative_time_in_208657936`, `hs_v2_date_entered_1041956472`, `hs_v2_date_entered_208657936`, `hs_v2_date_exited_1041956472`, `hs_v2_date_exited_1163219038`, `hs_v2_date_exited_1163219039`, `hs_v2_date_exited_208648566`, `hs_v2_date_exited_208657936`, `hs_v2_latest_time_in_1041956472`, `hs_v2_latest_time_in_1163219038`, `hs_v2_latest_time_in_1163219039`, `hs_v2_latest_time_in_208648566`, `hs_v2_latest_time_in_208657936`, `hs_all_owner_ids`, `hs_all_team_ids`, `hs_avatar_filemanager_key`, `hs_date_entered_1041956472`, `hs_date_entered_1041960295`, `hs_date_entered_1041960296`, `hs_date_entered_130379833`, `hs_date_entered_130379834`, `hs_date_entered_144188057`, `hs_date_entered_144188058`, `hs_date_entered_144977239`, `hs_date_entered_144998702`, `hs_date_entered_208648566`, `hs_date_entered_208648567`, `hs_date_entered_208657936`, `hs_date_entered_208657937`, `hs_date_exited_1041956472`, `hs_date_exited_1041960295`, `hs_date_exited_1041960296`, `hs_date_exited_130379833`, `hs_date_exited_130379834`, `hs_date_exited_144188057`, `hs_date_exited_144188058`, `hs_date_exited_144977239`, `hs_date_exited_144998702`, `hs_date_exited_208648566`, `hs_date_exited_208648567`, `hs_date_exited_208657936`, `hs_date_exited_208657937`, `hs_merged_object_ids`, `hs_object_source_detail_3`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_time_in_1041956472`, `hs_time_in_1041960295`, `hs_time_in_1041960296`, `hs_time_in_130379833`, `hs_time_in_130379834`, `hs_time_in_144188057`, `hs_time_in_144188058`, `hs_time_in_144977239`, `hs_time_in_144998702`, `hs_time_in_208648566`, `hs_time_in_208648567`, `hs_time_in_208657936`, `hs_time_in_208657937`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `submission_idempotent_id`

#### Vypočítané vlastnosti (vlastné)

| Interný názov | Label | Typ | Vzorec / definícia |
| --- | --- | --- | --- |
| `celkova_spotreba_na_oom__mwh_` | SUM_[MWh] na OOM | calculation_equation | `planovana_spotreba_1t_vt__mwh_ + planovana_spotreba_nt__mwh_ + planovany_objem_vykupu__mwh_` |

#### Možnosti výberových polí

- **`bateriove_ulozisko`** (Batériové úložisko): `ANO` = ÁNO; `NIE` = NIE; `PLÁNUJEM` = PLÁNUJEM
- **`dot__zaujem`** (Dotazník – záujem o služby): `Green Battery Box` = Green Battery Box; `Green VIWA TRADE – riadenie FVE a batérie` = Green VIWA TRADE – riadenie FVE a batérie; `Green VIWA TRADE – ochrana pred zápornými cenami` = Green VIWA TRADE – ochrana pred zápornými cenami; `Tepelné čerpadlo` = Tepelné čerpadlo; `GreenCar – wallbox` = GreenCar – wallbox; `Len aktualizácia údajov` = Len aktualizácia údajov
- **`fotovoltika`** (Fotovoltika): `ÁNO` = ÁNO; `NIE` = NIE; `PLÁNUJEM` = PLÁNUJEM
- **`trvanie_zmluvy_new`** (Trvanie zmluvy_NEW): `neurčito` = neurčito; `2026` = 2026; `2027` = 2027; `2028` = 2028; `2029` = 2029; `2030` = 2030; `2031` = 2031; `2023` = 2023; `2024` = 2024; `2025` = 2025
- **`typ_vykupnej_zmluvy`** (Typ výkupnej zmluvy): `Lokálny zdroj [EUR]` = Lokálny zdroj [EUR]; `Lokálny zdroj [%]` = Lokálny zdroj [%]; `Výrobný zdroj - cena Aditív [EUR]` = Výrobný zdroj - cena Aditív [EUR]; `Výrobný zdroj - cena Aditív [%]` = Výrobný zdroj - cena Aditív [%]; `Výrobný zdroj - cena Fix [EUR]` = Výrobný zdroj - cena Fix [EUR]
- **`vypoved_predoslemu_dodavatelovi`** (Akceptácia výpovede inému dodávateľovi): `Akceptácia výpovede` = Akceptácia výpovede; `Bez akceptácie` = Bez akceptácie; `Výpoveď sa nezasiela` = Výpoveď sa nezasiela; `Výpoveď odoslaná` = Výpoveď odoslaná; `Výpoveď potvrdená` = Výpoveď potvrdená
- **`claude_audit`** (Claude audit): `Áno` = Áno; `Nie` = Nie
- **`fv__pretoky`** (Posielate prebytky do siete): `ÁNO` = ÁNO; `NIE` = NIE; `NEVIEM` = NEVIEM
- **`fve_striedac`** (Striedač - výrobca): `FoxEss` = FoxEss; `Fronius` = Fronius; `Huawei` = Huawei; `Sofar Solar` = Sofar Solar; `SolarEdge` = SolarEdge; `Solax` = Solax; `GoodWe` = GoodWe; `SMA` = SMA; `Growatt` = Growatt; `Deye` = Deye; `Solis` = Solis; `Sungrow` = Sungrow; `Victron` = Victron; `Kostal` = Kostal; `Wattsonic` = Wattsonic; `Solinteg` = Solinteg; `Mikrostriedače` = Mikrostriedače; `Iný` = Iný
- **`st__druh`** (Striedač – druh): `Hybridný` = Hybridný; `Sieťový` = (On-Grid) Sieťový; `Neviem` = Neviem
- **`st__wifi`** (Wi-Fi pri striedači): `ÁNO` = ÁNO; `NIE` = NIE
- **`druh_vyrobneho_zdroja`** (Druh výrobného zdroja): `Fotovoltická elektráreň` = Fotovoltická elektráreň; `Vodná elektráreň` = Vodná elektráreň; `Biomasa` = Bioplyn; `Plynová elektráreň` = Plynová elektráreň; `Veterná elektráreň` = Veterná elektráreň; `Ostatné OZE` = Ostatné OZE
- **`stav_oom`** (Stav OOM): `Aktívne` = Aktívne; `Neaktívne` = Neaktívne; `Odídené` = Odídené; `Prepísané` = Prepísané; `Zrušené` = Zrušené; `Veľkoobchod` = Veľkoobchod
- **`typ_odberu`** (Typ odberu): `Domácnosti` = Domácnosti; `Firmy a organizácie` = Firmy a organizácie
- **`typ_zdroja`** (Typ zdroja): `Virtuálna batéria` = Virtuálna batéria; `Lokálny zdroj` = Lokálny zdroj; `Výrobný zdroj` = Výrobný zdroj; `Green VIWA` = Green VIWA
- **`tc__ohrev_teplej_vody`** (TČ - Ohrev teplej vody): `ÁNO` = ÁNO; `NIE` = NIE
- **`tc__podporuje_sg_ready__externe_riadenie`** (TČ - Podporuje externé riadenie?): `ÁNO` = ÁNO; `NIE` = NIE
- **`tepelne_cerpadlo`** (Tepelné čerpadlo): `ÁNO` = ÁNO; `Nie` = NIE; `PLÁNUJEM` = PLÁNUJEM
- **`wallbox`** (Wallbox): `ÁNO` = ÁNO; `NIE` = NIE; `PLÁNUJEM` = PLÁNUJEM
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False

### Zmluvné ceny (`2-16395301`)

Vlastností spolu: 76 (vlastné 26, HubSpot 50). Záznamov: 11 797.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `aditivny_koeficient____` | Aditívny koeficient [%] | number / number | ceny | 1 625 | 13,8 % |  |
| `cena_1t_2t_vt__eur_mwh_` | Cena 1T/2T_VT_Aditív [EUR/MWh] | number / number | ceny | 11 796 | 100 % |  |
| `cena_2t_nt__eur_mwh_` | Cena 2T_NT_Aditív [EUR/MWh] | number / number | ceny | 11 796 | 100 % |  |
| `cena_odchylky__eur_mwh_` | Cena odchýlky [EUR_MWh] | number / number | ceny | 11 796 | 100 % |  |
| `platba_za_odberne_miesto__eur_mesiac_` | Cena za odberné miesto [EUR/mesiac] | number / number | ceny | 11 796 | 100 % |  |
| `platba_za_vbattery__eur_mesiac_` | Cena za VBattery [EUR/mesiac] | number / number | ceny | 11 788 | 99,9 % |  |
| `platba_za_zem__eur_mesiac_` | Cena za ZEM [EUR/mesiac] | number / number | ceny | 11 795 | 100 % |  |
| `produkt` | Produkt | enumeration / select | ceny | 11 721 | 99,4 % | 57 možností |
| `celkovy_objem_1t_2t_vt` | Celkový objem 1T/2T_VT [MWh] | number / calculation_rollup | kalkulácie | 11 751 | 99,6 % | výpočet |
| `celkovy_objem_2t_nt` | Celkový objem 2T_NT [MWh] | number / calculation_rollup | kalkulácie | 11 751 | 99,6 % | výpočet |
| `celkovy_objem_spotreby__mwh_` | Celkový objem spotreby [MWh] | number / calculation_equation | kalkulácie | 11 751 | 99,6 % | výpočet |
| `celkovy_objem_vykupu` | Celkový objem výkupu [MWh] | number / calculation_rollup | kalkulácie | 11 750 | 99,6 % | výpočet |
| `celkovy_vynos_z_elektriny__eur_mwh_` | Celkový výnos z elektriny [EUR/MWh] | number / calculation_equation | kalkulácie | 11 749 | 99,6 % | výpočet |
| `celkovy_vynos_z_fixov__eur_mwh_` | Celkový výnos z fixov [EUR/MWh] | number / calculation_equation | kalkulácie | 11 787 | 99,9 % | výpočet |
| `cenn_k` | Zmluvná cena | string / text | zmluvn__ceny_information | 11 797 | 100 % |  |
| `cislo_zmluvy` | Číslo Greenlogy zmluvy | string / text | zmluvn__ceny_information | 11 696 | 99,1 % |  |
| `claude_audit` | Claude audit | enumeration / select | zmluvn__ceny_information | 0 | 0 % | 2 možností |
| `eic` | EIC | string / text | zmluvn__ceny_information | 11 797 | 100 % |  |
| `parovanie_zml_cena_vs__deal__trvanie_zmluvy_` | Párovanie Zml.cena vs. Deal (trvanie zmluvy) | string / text | zmluvn__ceny_information | 2 | 0 % |  |
| `program_vbattery` | Program VBattery | enumeration / select | zmluvn__ceny_information | 3 221 | 27,3 % | 6 možností |
| `subjekt` | Subjekt | string / text | zmluvn__ceny_information | 11 797 | 100 % |  |
| `trading_book` | Trading book | enumeration / radio | zmluvn__ceny_information | 241 | 2 % | 1 možností |
| `trvanie_zmluvy` | Trvanie zmluvy | enumeration / checkbox | zmluvn__ceny_information | 11 787 | 99,9 % | 10 možností |
| `typ_oom` | Typ OOM | enumeration / select | zmluvn__ceny_information | 10 728 | 90,9 % | 2 možností |
| `ucinnost_ceny_do` | Účinnosť ceny do | date / date | zmluvn__ceny_information | 11 797 | 100 % |  |
| `ucinnost_ceny_od` | Účinnosť ceny od | date / date | zmluvn__ceny_information | 11 787 | 99,9 % |  |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_v2_cumulative_time_in_89395221` | Cumulative time in "Platné (Zmluvné ceny)" | number / number | customobjectstages | 872 | 7,4 % |  |
| `hs_v2_cumulative_time_in_89395222` | Cumulative time in "Neplatné (Zmluvné ceny)" | number / number | customobjectstages | 33 | 0,3 % |  |
| `hs_v2_date_entered_89395221` | Date entered "Platné (Zmluvné ceny)" | datetime / date | customobjectstages | 11 792 | 100 % |  |
| `hs_v2_date_entered_89395222` | Date entered "Neplatné (Zmluvné ceny)" | datetime / date | customobjectstages | 876 | 7,4 % |  |
| `hs_v2_date_entered_current_stage` | Date entered current stage | datetime / calculation_equation | customobjectstages | 11 797 | 100 % | výpočet |
| `hs_v2_date_exited_89395221` | Date exited "Platné (Zmluvné ceny)" | datetime / date | customobjectstages | 872 | 7,4 % |  |
| `hs_v2_date_exited_89395222` | Date exited "Neplatné (Zmluvné ceny)" | datetime / date | customobjectstages | 33 | 0,3 % |  |
| `hs_v2_latest_time_in_89395221` | Latest time in "Platné (Zmluvné ceny)" | number / number | customobjectstages | 872 | 7,4 % |  |
| `hs_v2_latest_time_in_89395222` | Latest time in "Neplatné (Zmluvné ceny)" | number / number | customobjectstages | 33 | 0,3 % |  |
| `hs_v2_time_in_current_stage` | Time in current stage | datetime / calculation_equation | customobjectstages | 11 797 | 100 % | výpočet |
| `hs_all_accessible_team_ids` | All teams | enumeration / checkbox | zmluvn__ceny_information | 9 161 | 77,7 % |  |
| `hs_all_assigned_business_unit_ids` | Business units | enumeration / checkbox | zmluvn__ceny_information | 392 | 3,3 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | zmluvn__ceny_information | 11 794 | 100 % |  |
| `hs_createdate` | Object create date/time | datetime / date | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_lastmodifieddate` | Object last modified date/time | datetime / date | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_merged_object_ids` | Merged record IDs | enumeration / checkbox | zmluvn__ceny_information | 1 | 0 % |  |
| `hs_object_id` | Record ID | number / number | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | zmluvn__ceny_information | 7 666 | 65 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | zmluvn__ceny_information | 546 | 4,6 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_object_source_label` | Record source | enumeration / select | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | zmluvn__ceny_information | 11 794 | 100 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | zmluvn__ceny_information | 9 161 | 77,7 % |  |
| `hs_pipeline` | Zmluvná cena pipeline | enumeration / select | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_pipeline_stage` | Zmluvná cena pipeline stage | enumeration / select | zmluvn__ceny_information | 11 797 | 100 % |  |
| `hs_unique_creation_key` | Unique creation key | string / text | zmluvn__ceny_information | 3 116 | 26,4 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | zmluvn__ceny_information | 11 796 | 100 % |  |
| `hs_user_ids_of_all_notification_recipients` | All 2. zmluvná cena notification recipients | enumeration / checkbox | zmluvn__ceny_information | 11 012 | 93,3 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | zmluvn__ceny_information | 11 012 | 93,3 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | zmluvn__ceny_information | 10 801 | 91,6 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | zmluvn__ceny_information | 11 012 | 93,3 % |  |
| `hubspot_owner_id` | Owner | enumeration / select | zmluvn__ceny_information | 11 012 | 93,3 % |  |
| `hubspot_team_id` | Owner's main team | enumeration / select | zmluvn__ceny_information | 9 161 | 77,7 % |  |

#### HubSpot vlastnosti bez dát (16)

`hs_all_owner_ids`, `hs_all_team_ids`, `hs_avatar_filemanager_key`, `hs_date_entered_89395221`, `hs_date_entered_89395222`, `hs_date_exited_89395221`, `hs_date_exited_89395222`, `hs_object_source_detail_3`, `hs_pinned_engagement_id`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_time_in_89395221`, `hs_time_in_89395222`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`

#### Vypočítané vlastnosti (vlastné)

| Interný názov | Label | Typ | Vzorec / definícia |
| --- | --- | --- | --- |
| `celkovy_objem_1t_2t_vt` | Celkový objem 1T/2T_VT [MWh] | calculation_rollup | `{"numberDisplayHint":"formatted"}` |
| `celkovy_objem_2t_nt` | Celkový objem 2T_NT [MWh] | calculation_rollup | – (API definíciu nevracia) |
| `celkovy_objem_spotreby__mwh_` | Celkový objem spotreby [MWh] | calculation_equation | `(celkovy_objem_1t_2t_vt + celkovy_objem_2t_nt)` |
| `celkovy_objem_vykupu` | Celkový objem výkupu [MWh] | calculation_rollup | – (API definíciu nevracia) |
| `celkovy_vynos_z_elektriny__eur_mwh_` | Celkový výnos z elektriny [EUR/MWh] | calculation_equation | `((((cena_1t_2t_vt__eur_mwh_ * celkovy_objem_1t_2t_vt) + (cena_2t_nt__eur_mwh_ * celkovy_objem_2t_nt)) + (cena_1t_2t_vt__eur_mwh_ * celkovy_objem_vykupu)) + (cena_odchylky__eur_mwh_ * celkovy_objem_vykupu))` |
| `celkovy_vynos_z_fixov__eur_mwh_` | Celkový výnos z fixov [EUR/MWh] | calculation_equation | `platba_za_odberne_miesto__eur_mesiac_ * 12 + platba_za_zem__eur_mesiac_ * 12 + platba_za_vbattery__eur_mesiac_ * 12` |

#### Možnosti výberových polí

- **`produkt`** (Produkt): `2023_GREENVYR_AK [EUR]` = 2023_GREENVYR_AK [EUR]; `2024_GREENVYR_AK [EUR]` = 2024_GREENVYR_AK [EUR]; `2025_GREENVYR_AK [EUR]` = 2025_GREENVYR_AK [EUR]; `2023_GREENVYR_PC_R` = 2023_GREENVYR_PC_R; `2024_GREENVYR_PC_R` = 2024_GREENVYR_PC_R; `2025_GREENVYR_PC_R` = 2025_GREENVYR_PC_R; `2023_GREENVYR_AK [%]` = 2023_GREENVYR_AK [%]; `2024_GREENVYR_AK [%]` = 2024_GREENVYR_AK [%]; `` = 2025_GREENVYR_AK [%]; `Green DD1` = Green DD1; `Green DD2` = Green DD2; `Green DD3` = Green DD3; `Green DD4` = Green DD4; `Green DD5` = Green DD5; `Green DD6` = Green DD6; `Green DD7` = Green DD7; `Green DD8` = Green DD8; `VBATTERY  DD1` = VBATTERY  DD1; `VBATTERY  DD2` = VBATTERY  DD2; `VBATTERY  DD3` = VBATTERY  DD3; `VBATTERY  DD4` = VBATTERY  DD4; `VBATTERY  DD5` = VBATTERY  DD5; `VBATTERY  DD6` = VBATTERY  DD6; `VBATTERY  DD7` = VBATTERY  DD7; `VBATTERY  DD8` = VBATTERY  DD8; `GREEN_ISOTSK_PLUS_2024_R` = GREEN_ISOTSK_PLUS_2024_R; `GREEN_ISOTSK_PLUS_2025_R` = GREEN_ISOTSK_PLUS_2025_R; `GREEN_ISOTSK_PLUS_2026_R` = GREEN_ISOTSK_PLUS_2026_R; `ISOT TRENČÍN 2024` = ISOT TRENČÍN 2024; `ERES property - Indiv. 1T` = ERES property - Indiv. 1T; `KOMTERM BD` = KOMTERM BD; `IN Green 1T Individual` = IN Green 1T Individual; `IN Green 2T Individual` = IN Green 2T Individual; `VBATTERY-V` = VBATTERY-V; `Green DMP1` = Green DMP1; `Green DMP2` = Green DMP2; `Green DMP3` = Green DMP3; `Green DMP7` = Green DMP7; `Green ODCH` = Green ODCH; `Veľkoobchod` = Veľkoobchod; `WIVA firmy` = ViWA firmy; `Green DD1 - ANO Energopomoc` = Green DD1 - ANO Energopomoc; `Green DD2 - ANO Energopomoc` = Green DD2 - ANO Energopomoc; `Green DD3 - ANO Energopomoc` = Green DD3 - ANO Energopomoc; `Green DD4 - ANO Energopomoc` = Green DD4 - ANO Energopomoc; `Green DD5 - ANO Energopomoc` = Green DD5 - ANO Energopomoc; `Green DD6 - ANO Energopomoc` = Green DD6 - ANO Energopomoc; `Green DD7 - ANO Energopomoc` = Green DD7 - ANO Energopomoc; `Green DD8 - ANO Energopomoc` = Green DD8 - ANO Energopomoc; `Green DD1 - NIE Energopomoc` = Green DD1 - NIE Energopomoc … a ďalších 7
- **`claude_audit`** (Claude audit): `Áno` = Áno; `Nie` = Nie
- **`program_vbattery`** (Program VBattery): `ECO` = VBattery-ECO; `STANDARD` = VBattery-STANDARD; `PREMIUM` = VBattery-PREMIUM; `MAX` = VBattery-MAX; `AKU` = VBattery-AKU; `VBattery - V` = VBattery-V
- **`trading_book`** (Trading book): `V bloku` = V bloku
- **`trvanie_zmluvy`** (Trvanie zmluvy): `2023` = 2023; `2024` = 2024; `2025` = 2025; `2026` = 2026; `2027` = 2027; `2028` = 2028; `2029` = 2029; `neurčito` = neurčito; `2023, 2024` = 2023, 2024; `2023, 2024, 2025` = 2023, 2024, 2025
- **`typ_oom`** (Typ OOM): `Odber` = Odber; `Dodávka` = Dodávka
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False

### Nákupné ceny (`2-22997964`)

Vlastností spolu: 42 (vlastné 8, HubSpot 34). Záznamov: 1 163.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `cena` | Cena PXE BL | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `cena_obchod` | Cena_obchod | number / calculation_equation | nakupne_ceny_information | 1 163 | 100 % | výpočet |
| `cena_pxe_pl` | Cena PXE PL | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `datum_nakupnej_ceny` | Dátum nákupnej ceny | date / date | nakupne_ceny_information | 1 163 | 100 % |  |
| `obdobie_produktu` | Obdobie produktu | enumeration / select | nakupne_ceny_information | 1 163 | 100 % | 6 možností |
| `parovaci_kod_deal_nakupne_ceny` | Párovací kód_Deal_Nákupné ceny | string / text | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `produkt` | Sales | string / text | nakupne_ceny_information | 1 163 | 100 % |  |
| `produkt_nakupu` | Produkt nákupu | enumeration / checkbox | nakupne_ceny_information | 1 163 | 100 % | 12 možností |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_all_accessible_team_ids` | All teams | enumeration / checkbox | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hs_all_assigned_business_unit_ids` | Business units | enumeration / checkbox | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_createdate` | Object create date/time | datetime / date | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_lastmodifieddate` | Object last modified date/time | datetime / date | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_object_id` | Record ID | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | nakupne_ceny_information | 33 | 2,8 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_object_source_label` | Record source | enumeration / select | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_owning_teams` | Owning Teams | enumeration / checkbox | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hs_updated_by_user_id` | Updated by user ID | number / number | nakupne_ceny_information | 1 163 | 100 % |  |
| `hs_user_ids_of_all_notification_recipients` | All 3. nákupné ceny notification recipients | enumeration / checkbox | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hs_user_ids_of_all_owners` | User IDs of all owners | enumeration / checkbox | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | nakupne_ceny_information | 33 | 2,8 % | 2 možností |
| `hubspot_owner_assigneddate` | Owner assigned date | datetime / date | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hubspot_owner_id` | Owner | enumeration / select | nakupne_ceny_information | 1 130 | 97,2 % |  |
| `hubspot_team_id` | Owner's main team | enumeration / select | nakupne_ceny_information | 1 130 | 97,2 % |  |

#### HubSpot vlastnosti bez dát (15)

`hs_all_owner_ids`, `hs_all_team_ids`, `hs_avatar_filemanager_key`, `hs_merged_object_ids`, `hs_object_source_detail_2`, `hs_object_source_detail_3`, `hs_pinned_engagement_id`, `hs_pipeline`, `hs_pipeline_stage`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_unique_creation_key`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`

#### Vypočítané vlastnosti (vlastné)

| Interný názov | Label | Typ | Vzorec / definícia |
| --- | --- | --- | --- |
| `cena_obchod` | Cena_obchod | calculation_equation | `if string(produkt) equals 'PXE2027' then cena * 800 + cena_pxe_pl * 200 / 1000 + 4 + 4 else cena * 700 + cena_pxe_pl * 300 / 1000 + 4 + 4` |

#### Možnosti výberových polí

- **`obdobie_produktu`** (Obdobie produktu): `2025` = 2025; `2026` = 2026; `2027` = 2027; `2028` = 2028; `2029` = 2029; `2030` = 2030
- **`produkt_nakupu`** (Produkt nákupu): `SK BL CAL2025` = SK BL CAL2025; `SK BL CAL2026` = SK BL CAL2026; `SK BL CAL2027` = SK BL CAL2027; `SK BL CAL2028` = SK BL CAL2028; `SK BL CAL2029` = SK BL CAL2029; `SK BL CAL2030` = SK BL CAL2030; `SK PL CAL2025` = SK PL CAL2025; `SK PL CAL2026` = SK PL CAL2026; `SK PL CAL2027` = SK PL CAL2027; `SK PL CAL2028` = SK PL CAL2028; `SK PL CAL2029` = SK PL CAL2029; `SK PL CAL2030` = SK PL CAL2030
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False

## Produkty a line items

Produktov: 41, line items: 8 464.

| Produkt | SKU | Cena | Typ | Fakturácia | Line items | Vytvorený |
| --- | --- | --- | --- | --- | --- | --- |
| Green_E_1T_FIX |  | 189 |  | annually | 1 868 | 2021-03-11 |
| Výkup_INDEX_SPOT |  | 30 |  | annually | 1 328 | 2021-08-02 |
| Green_E_1T_SPOT+ aditív |  | 30 |  | annually | 841 | 2022-05-02 |
| Green_E_2T/NT_FIX |  | 189 |  | annually | 637 | 2021-03-19 |
| Green_E_2T/VT_FIX | MWh | 189 |  | annually | 634 | 2021-03-19 |
| Green_E_OM |  | 3 |  | monthly | 208 | 2021-03-31 |
| Výkup FIX_base |  | 180 |  | annually | 105 | 2021-08-02 |
| Green VIWA Pro |  | 9.9 |  | monthly | 93 | 2025-09-09 |
| Green VIWA Plus |  | 6.9 |  | monthly | 61 | 2025-09-09 |
| Výkup_FIX_peak |  | 200 |  |  | 35 | 2021-08-02 |
| Green_E_1T_FIX_2026 |  | 120 |  | annually | 33 | 2025-09-02 |
| Green_E_1T_FIX_2027 |  | 128 |  |  | 24 | 2025-09-02 |
| Platba za odchýlku |  | 0 |  | annually | 19 | 2024-06-03 |
| Vbat_test |  | 0 |  | annually | 18 | 2023-03-02 |
| Green VIWA Basic |  | 3.9 | service | monthly | 15 | 2025-09-09 |
| Green_E_3T_weekend_FIX |  | 189 |  | annually | 15 | 2021-10-13 |
| Green_E_OM_B2C |  | 1.5 |  | monthly | 11 | 2023-02-22 |
| Green_E_1T_FIX_2028 |  | 122 |  |  | 10 | 2026-09-09 |
| Green_E_1T_FIX_2029 |  | 115 |  |  | 6 | 2026-09-09 |
| Green VBattery Premium |  | 2 |  | annually | 2 | 2021-04-09 |
| GreenCar kredit 25EUR |  | 0 |  | annually | 2 | 2023-03-03 |
| Green DD2 |  | 75.5385 |  | annually | 1 | 2023-02-22 |
| Green VBattery MAX |  | 5 |  | annually | 1 | 2022-10-10 |
| Green_E_1T_PXE* index |  | 1.24 |  | annually | 1 | 2024-01-16 |
| Green DD1 |  | 75.5385 |  | annually | 0 | 2021-10-15 |
| Green DD3_NT |  | 59.6084 |  | annually | 0 | 2023-02-22 |
| Green DD3_VT |  | 87.848 |  | annually | 0 | 2023-02-22 |
| Green DD4_NT |  | 59.6084 |  | annually | 0 | 2023-02-22 |
| Green DD4_VT |  | 87.848 |  | annually | 0 | 2023-02-22 |
| Green DD5_NT |  | 71.4111 |  | annually | 0 | 2023-02-22 |
| Green DD5_VT |  | 100.8817 |  | annually | 0 | 2023-02-22 |
| Green DD6_NT |  | 71.4111 |  | annually | 0 | 2023-02-22 |
| Green DD6_VT |  | 100.8817 |  | annually | 0 | 2023-02-22 |
| Green DD7_NT |  | 59.6084 |  | annually | 0 | 2023-02-22 |
| Green DD7_VT |  | 87.848 |  | annually | 0 | 2023-02-22 |
| Green DD8_NT |  | 59.6084 |  | annually | 0 | 2023-02-22 |
| Green DD8_VT |  | 87.848 |  | annually | 0 | 2023-02-22 |
| Green VBattery AKU |  | 1 |  | monthly | 0 | 2023-02-22 |
| Green VBattery ECO |  | 0 |  | annually | 0 | 2021-04-09 |
| Green VBattery Standard |  | 1.5 |  | annually | 0 | 2021-04-09 |
| Green ZEM |  | 1 |  | monthly | 0 | 2021-04-09 |

### Produkty (`products`)

Vlastností spolu: 73 (vlastné 4, HubSpot 69). Záznamov: 41.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `aditiv_vykupu_v__` | Aditív výkupu v % | string / text | price | 0 | 0 % |  |
| `splatnost_faktur` | Splatnosť faktúr | number / number | price | 0 | 0 % |  |
| `objem` | Objem | number / number | productinformation | 3 | 7,3 % |  |
| `jednotka` | Jednotka | enumeration / select | term | 5 | 12,2 % | 3 možností |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_price_eur` | Price EUR | number / number | multi_currency_prices | 41 | 100 % |  |
| `hs_product_supported_currencies` | Product supported currencies | enumeration / checkbox | multi_currency_prices | 41 | 100 % |  |
| `hs_supported_currencies` | Supported currencies | enumeration / calculation_equation | multi_currency_prices | 41 | 100 % | výpočet |
| `hs_cost_of_goods_sold` | Unit cost | number / number | price | 3 | 7,3 % |  |
| `hs_pricing_model` | Pricing model | enumeration / select | price | 41 | 100 % | 4 možností |
| `price` | Unit price | number / number | price | 41 | 100 % |  |
| `recurringbillingfrequency` | Billing frequency | enumeration / select | price | 37 | 90,2 % | 10 možností |
| `createdate` | Create Date | datetime / date | productinformation | 41 | 100 % |  |
| `description` | Product description | string / textarea | productinformation | 40 | 97,6 % |  |
| `hs_bundle_type` | Bundle type | enumeration / select | productinformation | 7 | 17,1 % | 3 možností |
| `hs_created_by_user_id` | Created by user ID | number / number | productinformation | 41 | 100 % |  |
| `hs_createdate` | Object create date/time | datetime / date | productinformation | 41 | 100 % |  |
| `hs_folder` | Folder | enumeration / select | productinformation | 38 | 92,7 % | 6 možností |
| `hs_folder_id` | Folder Id | number / number | productinformation | 33 | 80,5 % |  |
| `hs_folder_name` | Folder name | string / text | productinformation | 38 | 92,7 % |  |
| `hs_images` | Image Url | string / text | productinformation | 3 | 7,3 % |  |
| `hs_lastmodifieddate` | Last Modified Date | datetime / date | productinformation | 41 | 100 % |  |
| `hs_object_id` | Record ID | number / number | productinformation | 41 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | productinformation | 41 | 100 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | productinformation | 33 | 80,5 % |  |
| `hs_object_source_label` | Record source | enumeration / select | productinformation | 41 | 100 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | productinformation | 41 | 100 % |  |
| `hs_product_classification` | Product Classification | enumeration / select | productinformation | 41 | 100 % | 4 možností |
| `hs_product_type` | Product type | enumeration / select | productinformation | 1 | 2,4 % | 3 možností |
| `hs_rich_text_description` | Description | string / html | productinformation | 40 | 97,6 % |  |
| `hs_sku` | SKU | string / text | productinformation | 1 | 2,4 % | jedinečná |
| `hs_status` | Status | enumeration / select | productinformation | 41 | 100 % | 2 možností |
| `hs_updated_by_user_id` | Updated by user ID | number / number | productinformation | 41 | 100 % |  |
| `name` | Name | string / text | productinformation | 41 | 100 % |  |

#### HubSpot vlastnosti bez dát (40)

`hs_price_che`, `hs_price_czk`, `hs_price_hrk`, `hs_product_bundle_supported_currencies`, `amount`, `discount`, `hs_bundle_pricing_type`, `hs_discount_percentage`, `hs_tier_prices`, `hs_tier_ranges`, `tax`, `hs_all_accessible_team_ids`, `hs_all_assigned_business_unit_ids`, `hs_all_owner_ids`, `hs_all_team_ids`, `hs_avatar_filemanager_key`, `hs_bundle_grouping_config_id`, `hs_inventory_quantity`, `hs_merged_object_ids`, `hs_object_source_detail_1`, `hs_object_source_detail_2`, `hs_object_source_detail_3`, `hs_owning_teams`, `hs_pinned_engagement_id`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_tax_category`, `hs_unique_creation_key`, `hs_url`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `hs_user_ids_of_all_owners`, `hs_was_imported`, `hubspot_owner_assigneddate`, `hubspot_owner_id`, `hubspot_team_id`, `quantity`, `hs_recurring_billing_period`, `hs_recurring_billing_start_date`

#### Možnosti výberových polí

- **`jednotka`** (Jednotka): `MWh` = MWh; `ks` = ks; `mesiac` = mesiac
- **`hs_pricing_model`** (Pricing model): `flat` = Flat; `volume` = Volume-based; `stairstep` = Stair-step; `graduated` = Graduated
- **`recurringbillingfrequency`** (Billing frequency): `weekly` = Weekly; `biweekly` = Every two weeks; `monthly` = Monthly; `quarterly` = Quarterly; `per_six_months` = Semi-annually; `annually` = Annually; `per_two_years` = Every two years; `per_three_years` = Every three years; `per_four_years` = Every four years; `per_five_years` = Every five years
- **`hs_bundle_type`** (Bundle type): `none` = None; `open` = Open; `closed` = Closed
- **`hs_folder`** (Folder): `Elektrina_B2B (auto_generated_f1313876-78a1-4f6e-a707-afd7e8ffc381)` = Elektrina_B2B; `Elektrina_B2C (auto_generated_4da37db3-37ad-4f3e-b40f-bb3a293a1c4d)` = Elektrina_B2C; `Greenlogy_služby (auto_generated_372351ba-5645-4ab8-9cfa-a512e221460a)` = Greenlogy_služby; `Greenlogy_výkup (auto_generated_dbf9d90d-b2c6-4911-a5e4-08927805c901)` = Greenlogy_výkup; `Služby_B2C (VBattery) (auto_generated_e5d75061-998f-43ad-bff1-4fc5ab040073)` = Služby_B2C (VBattery); `Green VIWA` = Green VIWA
- **`hs_product_classification`** (Product Classification): `standalone` = Standalone; `variant` = Variant; `bundle` = Bundle; `primary_variant` = Primary Variant
- **`hs_product_type`** (Product type): `inventory` = Inventory; `non_inventory` = Non-Inventory; `service` = Service
- **`hs_status`** (Status): `active` = Active; `inactive` = Inactive

### Line items (`line_items`)

Vlastností spolu: 142 (vlastné 4, HubSpot 138). Záznamov: 8 464.

#### Vlastné vlastnosti

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `objem` | Objem | number / number | lineiteminformation | 281 | 3,3 % |  |
| `aditiv_vykupu_v__` | Aditív výkupu v % | string / text | price | 2 | 0 % |  |
| `splatnost_faktur` | Splatnosť faktúr | number / number | price | 8 | 0,1 % |  |
| `jednotka` | Jednotka | enumeration / select | term | 4 815 | 56,9 % | 3 možností |

#### HubSpot vlastnosti s dátami

| Interný názov | Label | Typ | Skupina | Vyplnené | % | Poznámka |
| --- | --- | --- | --- | --- | --- | --- |
| `hs_num_child_line_items` | Number of child Line Items | number / calculation_rollup | bundleinformation | 701 | 8,3 % |  |
| `createdate` | Create date | datetime / date | lineiteminformation | 8 464 | 100 % |  |
| `description` | Description | string / textarea | lineiteminformation | 6 557 | 77,5 % |  |
| `hs_created_by_user_id` | Created by user ID | number / number | lineiteminformation | 7 690 | 90,9 % |  |
| `hs_createdate` | Object create date/time | datetime / date | lineiteminformation | 8 464 | 100 % |  |
| `hs_images` | Image URL | string / text | lineiteminformation | 2 | 0 % |  |
| `hs_lastmodifieddate` | Object last modified date/time | datetime / date | lineiteminformation | 8 464 | 100 % |  |
| `hs_line_item_currency_code` | Currency | enumeration / select | lineiteminformation | 8 439 | 99,7 % |  |
| `hs_locked` | Locked | bool / booleancheckbox | lineiteminformation | 8 464 | 100 % | 2 možností |
| `hs_object_id` | Record ID | number / number | lineiteminformation | 8 464 | 100 % |  |
| `hs_object_source` | Record creation source | string / text | lineiteminformation | 8 457 | 99,9 % |  |
| `hs_object_source_detail_1` | Record source detail 1 | string / text | lineiteminformation | 118 | 1,4 % |  |
| `hs_object_source_detail_2` | Record source detail 2 | string / text | lineiteminformation | 77 | 0,9 % |  |
| `hs_object_source_id` | Record creation source ID | string / text | lineiteminformation | 8 176 | 96,6 % |  |
| `hs_object_source_label` | Record source | enumeration / select | lineiteminformation | 8 457 | 99,9 % |  |
| `hs_object_source_user_id` | Record creation source user ID | number / number | lineiteminformation | 7 690 | 90,9 % |  |
| `hs_origin_key` | Origin key | string / text | lineiteminformation | 434 | 5,1 % |  |
| `hs_position_on_quote` | Position on quote | number / number | lineiteminformation | 8 450 | 99,8 % |  |
| `hs_product_id` | Product | number / number | lineiteminformation | 6 554 | 77,4 % |  |
| `hs_product_type` | Product type | enumeration / select | lineiteminformation | 15 | 0,2 % | 3 možností |
| `hs_rich_text_description` | Line Item Description | string / html | lineiteminformation | 6 557 | 77,5 % |  |
| `hs_sku` | SKU | string / text | lineiteminformation | 495 | 5,8 % |  |
| `hs_unique_creation_key` | Unique creation key | string / text | lineiteminformation | 138 | 1,6 % | jedinečná |
| `hs_updated_by_user_id` | Updated by user ID | number / number | lineiteminformation | 7 740 | 91,4 % |  |
| `hs_was_imported` | Performed in an import | bool / booleancheckbox | lineiteminformation | 1 887 | 22,3 % | 2 možností |
| `hubspot_owner_id` | Owner | enumeration / select | lineiteminformation | 4 562 | 53,9 % |  |
| `hubspot_team_id` | Owner's main team | enumeration / select | lineiteminformation | 4 561 | 53,9 % |  |
| `name` | Name | string / text | lineiteminformation | 8 464 | 100 % |  |
| `amount` | Net price | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_acv` | Annual contract value | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_arr` | Annual recurring revenue | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_cost_of_goods_sold` | Unit cost | number / number | price | 3 461 | 40,9 % |  |
| `hs_discount_percentage` | Discount percentage | number / number | price | 1 | 0 % |  |
| `hs_effective_unit_price` | Effective unit price | number / number | price | 8 464 | 100 % |  |
| `hs_margin` | Margin | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_margin_acv` | Annual contract value margin | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_margin_arr` | Annual recurring revenue margin | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_margin_mrr` | Monthly recurring revenue margin | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_margin_tcv` | Total contract value margin | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_mrr` | Monthly recurring revenue | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_post_tax_amount` | Net price after tax | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_pre_discount_amount` | Pre discount amount | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_pricing_model` | Pricing model | enumeration / select | price | 8 464 | 100 % | 4 možností |
| `hs_recurring_billing_number_of_payments` | Number of payments | number / calculation_equation | price | 905 | 10,7 % | výpočet |
| `hs_recurring_billing_terms` | Billing terms | enumeration / calculation_equation | price | 7 156 | 84,5 % | výpočet, 2 možností |
| `hs_tax_amount` | Tax amount | number / calculation_equation | price | 5 | 0,1 % | výpočet |
| `hs_tax_assessed` | Tax assessed | bool / calculation_equation | price | 1 038 | 12,3 % | výpočet, 2 možností |
| `hs_tcv` | Total contract value | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_term_in_months` | Term in months | number / calculation_equation | price | 290 | 3,4 % | výpočet |
| `hs_total_discount` | Calculated total discount | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_unscaled_amount` | Unscaled amount | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_unscaled_pre_discount_amount` | Unscaled pre discount amount | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `hs_unscaled_total_discount` | Unscaled total discount | number / calculation_equation | price | 8 464 | 100 % | výpočet |
| `price` | Unit price | number / number | price | 8 464 | 100 % |  |
| `quantity` | Quantity | number / number | price | 8 093 | 95,6 % |  |
| `recurringbillingfrequency` | Billing frequency | enumeration / select | price | 7 604 | 89,8 % | 10 možností |
| `hs_has_prorating_leading` | Has leading prorating | bool / calculation_equation | term | 1 213 | 14,3 % | výpočet, 2 možností |
| `hs_has_prorating_trailing` | Has trailing prorating | bool / calculation_equation | term | 1 213 | 14,3 % | výpočet, 2 možností |
| `hs_recurring_billing_end_date` | Billing end date | date / calculation_read_time | term | 6 | 0,1 % | výpočet |
| `hs_recurring_billing_period` | Term | string / text | term | 290 | 3,4 % |  |
| `hs_recurring_billing_start_date` | Billing start date | date / date | term | 8 | 0,1 % |  |

#### HubSpot vlastnosti bez dát (77)

`hs_bundle_id`, `hs_bundle_item_quantity`, `hs_is_parent`, `hs_line_item_group_config_id`, `hs_line_item_group_instance_key`, `hs_parent_line_item_id`, `hs_all_accessible_team_ids`, `hs_all_assigned_business_unit_ids`, `hs_all_owner_ids`, `hs_all_team_ids`, `hs_allow_buyer_selected_quantity`, `hs_buyer_selected_quantity_max`, `hs_buyer_selected_quantity_min`, `hs_external_id`, `hs_group_key`, `hs_hierarchy_type`, `hs_is_optional`, `hs_merged_object_ids`, `hs_object_source_detail_3`, `hs_optional_metadata`, `hs_owning_teams`, `hs_parent_object_type_id`, `hs_pinned_engagement_id`, `hs_prorating_scale`, `hs_ramp_group_name`, `hs_ramp_key`, `hs_ramp_phase_key`, `hs_ramp_phase_name`, `hs_read_only`, `hs_shared_team_ids`, `hs_shared_user_ids`, `hs_sync_amount`, `hs_tax_calculation_id`, `hs_tax_category`, `hs_url`, `hs_use_prorating`, `hs_user_ids_of_all_notification_followers`, `hs_user_ids_of_all_notification_unfollowers`, `hs_user_ids_of_all_owners`, `hs_variant_id`, `hubspot_owner_assigneddate`, `hs_exchange_rate`, `discount`, `hs_auto_tax_amount`, `hs_external_tax_rate_id`, `hs_is_editable_price`, `hs_price_book_id`, `hs_tax_label`, `hs_tax_rate`, `hs_tax_rate_group_id`, `hs_tier_amount`, `hs_tier_prices`, `hs_tier_ranges`, `tax`, `hs_billing_cycle_anchor_date`, `hs_billing_pause_mode`, `hs_billing_period_end_date`, `hs_billing_period_start_date`, `hs_billing_start_delay_days`, `hs_billing_start_delay_months`, `hs_billing_start_delay_type`, `hs_milestone_billing_enabled`, `hs_prorating_leading_amount`, `hs_prorating_leading_end_date`, `hs_prorating_leading_post_tax_amount`, `hs_prorating_leading_scale`, `hs_prorating_leading_start_date`, `hs_prorating_leading_tax_amount`, `hs_prorating_leading_term_length`, `hs_prorating_trailing_amount`, `hs_prorating_trailing_end_date`, `hs_prorating_trailing_post_tax_amount`, `hs_prorating_trailing_scale`, `hs_prorating_trailing_start_date`, `hs_prorating_trailing_tax_amount`, `hs_prorating_trailing_term_length`, `hs_recurring_billing_day_of_month`

#### Možnosti výberových polí

- **`jednotka`** (Jednotka): `MWh` = MWh; `ks` = ks; `mesiac` = mesiac
- **`hs_locked`** (Locked): `true` = Yes; `false` = No
- **`hs_product_type`** (Product type): `inventory` = Inventory; `non_inventory` = Non-Inventory; `service` = Service
- **`hs_was_imported`** (Performed in an import): `true` = True; `false` = False
- **`hs_pricing_model`** (Pricing model): `flat` = Flat; `volume` = Volume-based; `stairstep` = Stair-step; `graduated` = Graduated
- **`hs_recurring_billing_terms`** (Billing terms): `FIXED` = Fixed number of payments; `AUTOMATICALLY_RENEW` = Automatically renew until canceled
- **`hs_tax_assessed`** (Tax assessed): `true` = Yes; `false` = No
- **`recurringbillingfrequency`** (Billing frequency): `weekly` = Weekly; `biweekly` = Every two weeks; `monthly` = Monthly; `quarterly` = Quarterly; `per_six_months` = Semi-annually; `annually` = Annually; `per_two_years` = Every two years; `per_three_years` = Every three years; `per_four_years` = Every four years; `per_five_years` = Every five years
- **`hs_has_prorating_leading`** (Has leading prorating): `true` = Yes; `false` = No
- **`hs_has_prorating_trailing`** (Has trailing prorating): `true` = Yes; `false` = No
