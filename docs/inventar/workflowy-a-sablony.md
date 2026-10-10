# Inventár HubSpotu – workflowy, šablóny, formuláre, používatelia

Vygenerované skriptom `integrations/hubspot-sync/inventory` (10. októbra 2026) z HubSpot portálu 5964726.
Ručne needitovať – pri ďalšom behu sa súbor prepíše. Komentáre a závery patria do `suhrn.md`.

## Workflowy

Spolu 220, aktívnych 170, neaktívnych 50.
Typy akcií sú HubSpot `actionTypeId` (napr. `0-5`). Čo workflow robí slovne, dopíšem do `suhrn.md` po prečítaní definícií.

| Názov | Objekt | Aktívny | Spúšťač | Opak. zápis | Akcií | Typy akcií | Upravené |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Ak je kontakt neznámy(cloudtalk) alebo konkurent - nastav stage Other | Kontakty | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-04-10 |
| B2B výkup_follow up email_7 dní od ponuky | Dealy | áno | LIST_BASED | áno | 7 | 0-35×3, 0-4×2, 0-5×1, LIST_BRANCH×1 | 2025-10-14 |
| Change ticket status when a customer replies to an email | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Close date = dátum nákupnej ceny - B2B, B2C | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-03-16 |
| COPY EIC z OOM do Zmluvnej ceny | Zmluvné ceny | áno | LIST_BASED | nie | 1 | 0-5×1 | 2024-01-14 |
| Customer Loyalty Survey Follow-Up: Detractors 0 - 6 | Kontakty | áno | MANUAL | áno | 1 | 0-8×1 | 2023-05-14 |
| Customer Satisfaction Survey Follow-Up: Neutral | Kontakty | áno | MANUAL | áno | 1 | 0-14×1 | 2022-05-05 |
| Customer Satisfaction Survey Follow-Up: Unhappy | Kontakty | áno | MANUAL | áno | 1 | 0-14×1 | 2022-05-05 |
| Deal_Quotes_dopln splatnosť a flexibilitu | Dealy | áno | LIST_BASED | áno | 2 | 0-5×2 | 2024-02-02 |
| Deal_vytvor kód pre párovanie s Nákupné ceny | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-03-16 |
| Denis_odošli CP_zmen stage na CP odoslaná | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2023-05-23 |
| Denis_odošli zmluvu_zmen stage na zmluva odoslaná (cloned) | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2023-05-23 |
| Denis_vytvaranie dealov | Kontakty | áno | LIST_BASED | áno | 6 | LIST_BRANCH×2, 0-14×1, 0-1×1, 0-5×2 | 2023-07-03 |
| Doplň výkon zdroja kW | OOM | áno | LIST_BASED | áno | 2 | 0-33×1, 0-5×1 | 2025-10-23 |
| Doplniť kampaň z Kontaktu do Dealu a Tiketu | Kontakty | áno | LIST_BASED | áno | 4 | LIST_BRANCH×1, 0-5×3 | 2022-08-19 |
| download_ebook Green ViWA | Kontakty | áno | LIST_BASED | áno | 3 | 0-11×1, 0-4×1, 0-1×1 | 2025-10-08 |
| FB FORM - ticket Green Solar | Kontakty | áno | EVENT_BASED | áno | 3 | 0-11×1, 0-14×1, 0-5×1 | 2025-05-09 |
| FB messenger/Chat je aktívny | 0-11 | áno | LIST_BASED | áno | 1 | 0-8×1 | 2026-08-27 |
| Filter deals with signed contract and Vbattery_ELEKTRINA in name and active service status | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2026-05-26 |
| Follow up_ručné odoslanie_výkup | Dealy | áno | LIST_BASED | nie | 1 | 0-4×1 | 2024-06-06 |
| Forecast Category Mapping for Pipeline: Greenlogy_B2B_elektrina | Dealy | áno | LIST_BASED | áno | 5 | LIST_BRANCH×1, 0-5×4 | 2025-03-30 |
| Forecast Category Mapping for Pipeline: Greenlogy_B2B_výkup elektriny | Dealy | áno | LIST_BASED | áno | 6 | LIST_BRANCH×1, 0-5×5 | 2025-03-30 |
| Forecast Category Mapping for Pipeline: Greenlogy_B2C_elektrina | Dealy | áno | LIST_BASED | áno | 5 | LIST_BRANCH×1, 0-5×4 | 2025-03-30 |
| Forecast Probability Mapping for Pipeline: Greenlogy - 100% zelená elektrina | Dealy | áno | LIST_BASED | áno | 6 | LIST_BRANCH×1, 0-5×5 | 2026-08-27 |
| Forecast Probability Mapping for Pipeline: Greenlogy - veľkoobchod | Dealy | áno | LIST_BASED | áno | 6 | LIST_BRANCH×1, 0-5×5 | 2026-08-27 |
| Frontoffice: Change ticket status when an email is sent to a sales rep | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| GD_priraď promoter v HS | Kontakty | áno | LIST_BASED | áno | 10 | LIST_BRANCH×5, 1-55448244×5 | 2024-09-22 |
| Green Car_hodnota kupónu | Dealy | áno | LIST_BASED | áno | 6 | LIST_BRANCH×3, 0-5×3 | 2023-03-03 |
| Green Solar_pošli notifikáciu Mirke T. | Dealy | áno | LIST_BASED | áno | 1 | 0-14×1 | 2025-03-17 |
| Green VIWA poplatok za RK je prázdny | Dealy | áno | LIST_BASED | áno | 1 | 0-33×1 | 2025-10-26 |
| Green VIWA_poplatok za odchýlku | Dealy | áno | LIST_BASED | áno | 9 | LIST_BRANCH×3, 0-33×3, 0-5×3 | 2025-10-23 |
| GreenCAR - Automaticke poslanie emailu + Vytvorenie Dealu - PRODUKCIA | Dealy | áno | LIST_BASED | nie | 5 | 0-4×1, 0-5×3, 0-1×1 | 2023-05-08 |
| GreenCar - pošli 100EUR kupón | Dealy | áno | LIST_BASED | nie | 1 | 0-4×1 | 2023-02-27 |
| GreenCar - pošli 25EUR kupón | Dealy | áno | LIST_BASED | nie | 1 | 0-4×1 | 2023-02-27 |
| GreenCar - pošli 50EUR kupón | Dealy | áno | LIST_BASED | nie | 1 | 0-4×1 | 2023-02-27 |
| GreenConnect B2C - Do. Sep 03 2026 13:45:52 GMT+02:00 | Kontakty | áno | LIST_BASED | áno | 2 | 0-5×2 | 2026-09-11 |
| Greenlogy - tiket otvorený | Tickety | áno | LIST_BASED | áno | 5 | LIST_BRANCH×3, 0-4×1, 0-1×1 | 2026-08-27 |
| Greenlogy - tiket zatvorený | Tickety | áno | LIST_BASED | áno | 4 | 0-4×1, LIST_BRANCH×3 | 2026-08-27 |
| GreenSolar_copy čistá marža do Amount | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-12-06 |
| GreenSolar_doplň správnu DPH do výpočtu_DPH properties | Dealy | áno | LIST_BASED | áno | 5 | LIST_BRANCH×2, 0-5×3 | 2025-03-17 |
| GreenSolar_podľa programu - nastav výšku provízie v % | Dealy | áno | LIST_BASED | áno | 4 | STATIC_BRANCH×1, 0-5×3 | 2024-12-06 |
| GRN / Affiliate Partners / 1 Visited Partner Page | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Affiliate Partners / 2 Book Partner Demo | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Affiliate Partners / 3 Apply to Partner Program | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Affiliate Partners / 4 Partner Onboarding | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Affiliate Partners / 5 Active Partners | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2B / 1 Visited Page Charging Stations pre Firmy | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2B / 2 Download EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2B / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2B / 4 Accept Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2B / 5 Installation and technical support | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2C / 1 Visited page Charging stations B2C | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2C / 2 Download EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2C / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2C / 4 Accept Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Charging Stations B2C / 5 Installation and technical support | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 1 Visited Energia pre firmy | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 2 Download EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 4 Contract Creation | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 5 Contract Signed | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 6 Proces Zmeny (Success / Fail) | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 7 Welcome / Portal Onboarding | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2B / 8 Zelena elektrina customer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 1 Visited Page Energia pre Domacnosti | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 10 Virtualna bateria customer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 2 Download Product EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 4 Open Email / SMS Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 5 Contract Creation | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 6 Contract Signed | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 7 Proces Zmeny (Success / Fail) | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / 9 Zelena elektrina customer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Energia B2C / Welcome / 8 Portal Onboarding | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2B / 1 Visited Page Fotovoltika B2B | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2B / 2 Download Ebook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2B / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2B / 4 Accept Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2B / 5 Installation and technical support | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2C / 1 Visited Page Fotovoltika B2C | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2C / 2 Download EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2C / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2C / 4 Accept Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Fotovoltika B2C / 5 Installation and technical support | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 1 Visit Use Case Page - Vykup | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 2 Download EBook | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 3 Request Offer | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 4 Contract Creation | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 6 Proces Zmeny | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 7 Aktivacia - Portal Onboarding | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Producenti B2B / 8 Aktivny Producent | Kontakty | áno | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| Growthdrive_zadanie marže pre províziu | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-02-02 |
| Kopíruj hrubú maržu do Amount | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-02-08 |
| mhsr dotacie | Dealy | áno | LIST_BASED | nie | 1 | 0-4×1 | 2023-03-07 |
| Nákupné ceny_vytvor kód pre párovanie s Deal | Nákupné ceny | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-03-16 |
| Nastav LEAD ako kvalifikovaný ak má kontakt už deal | Kontakty | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-04-08 |
| Nastav MQL, ak Paid, Organic search, Email MRKT, Social | Kontakty | áno | LIST_BASED | áno | 2 | 0-5×2 | 2024-01-21 |
| Nastav SQL, ak vyplnil Formulár | Kontakty | áno | LIST_BASED | áno | 2 | 0-5×2 | 2024-01-21 |
| Nastavenie Legal Basis pre kontakty | Kontakty | áno | LIST_BASED | nie | 3 | 0-5×2, LIST_BRANCH×1 | 2024-01-22 |
| Nevytvoriť ticket z odpovede na Ticket uzavretý alebo otvorený | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2022-05-05 |
| OOM Aktívne = set B2C Zmluva Potvrdená/Nepotvrdená | OOM | áno | LIST_BASED | áno | 4 | 0-5×2, LIST_BRANCH×2 | 2025-09-25 |
| OOM_NEW_doba neurčitá_doplň 31.12.2099 | OOM | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-16 |
| Oslovenie UniCredit Bank (zákazníci B2B | Kontakty | áno | LIST_BASED | nie | 2 | 0-23×1, 0-1×1 | 2025-01-21 |
| Pipeline is "Greenlogy - 100% zelená elektrina", deal stage is "Zmenový neprešiel - technický problém" | Dealy | áno | LIST_BASED | áno | 2 | 0-3×1, 0-5×1 | 2026-08-27 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Čaká na podpis" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Čakáme na zaradenie do BS" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Cenová ponuka" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "CP akceptovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Finálne podpísaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Neúspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Príležitosť" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Rozpracovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Ukončená" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_elektrina", deal stage is "Úspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Čaká na podpis" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Čaká na zaradenie do BS" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Cenová ponuka" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Finálne podpísaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Neúspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Príležitosť" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Rozpracovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Ukončená" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Úspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-22 |
| Pipeline is "Greenlogy_B2B_výkup elektriny", deal stage is "Zmluvy_2024" | Dealy | áno | LIST_BASED | áno | 0 |  | 2024-02-07 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Čaká na podpis" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Čakáme na zaradenie PDS" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Cenová ponuka" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "CP akceptovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Eskalačný email 1" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Eskalačný email 2" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Eskalačný email 3" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Finálne podpísaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Neúspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Príležitosť" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Rozpracovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Ukončená" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Úspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Výpoveď neakceptovaná" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy_B2C_elektrina", deal stage is "Zmenový proces neúspešný - technický problém" | Dealy | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-21 |
| Pipeline is "Greenlogy", deal stage is "Výpoveď neakceptovaná" | Dealy | áno | LIST_BASED | áno | 2 | 0-3×1, 0-5×1 | 2026-08-27 |
| Pipeline is "Office", Ticket status is "Čakáme na vyjadrenie obchodníka" | Tickety | áno | LIST_BASED | nie | 0 |  | 2024-03-18 |
| Pipeline is "Predaj komodity", deal stage is "Neúspech" | Dealy | áno | LIST_BASED | áno | 1 | 0-3×1 | 2026-08-27 |
| Set a lifecycle stage to Opportunity | Kontakty | áno | LIST_BASED | áno | 3 | 0-5×2, 0-11×1 | 2024-11-29 |
| Set a lifecycle stage to SQL | Kontakty | áno | LIST_BASED | áno | 1 | 0-5×1 | 2022-05-24 |
| Skopíruj Company name do Subjekt_ak poznáš IČO | Firmy | áno | LIST_BASED | áno | 2 | 0-1×1, 0-5×1 | 2025-04-18 |
| Spárovanie a copy NC do deal vs. nákupné ceny cez Hubspot | Dealy | áno | LIST_BASED | áno | 6 | 0-63189541×1, 0-61139476×1, 0-1×1, 0-5×1, LIST_BRANCH×2 | 2025-10-22 |
| Spárovanie Deal vs Zml.ceny cez Hubspot | Dealy | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-15 |
| Spárovanie Deal vs. OOM cez Hubspot | Dealy | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-15 |
| Spárovanie dealu a firmy | Firmy | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-22 |
| Spárovanie nákupné ceny vs. deal cez Hubspot | Nákupné ceny | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-16 |
| Spárovanie OOM vs. Deal cez Hubspot | OOM | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-07-14 |
| Spárovanie OOM vs. Zml.ceny cez Hubspot | Zmluvné ceny | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-15 |
| Spárovanie Zml.cena vs Deal cez Hubspot | Zmluvné ceny | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-15 |
| Spárovanie Zml.ceny vs. OOM cez Hubspot | OOM | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-15 |
| Spáruj firmu a deal | Dealy | áno | LIST_BASED | áno | 1 | 0-63189541×1 | 2025-03-22 |
| Subscriptions pri vytvorení kontaktu | Kontakty | áno | LIST_BASED | nie | 3 | 0-43347357×3 | 2025-04-17 |
| Ticket status "Čakáme na vyjadrenie zákazníka" - zmena na Aktualizovane zakaznikom /cca zbytocny workflow, lebo pipeline Office/ | Tickety | áno | LIST_BASED | nie | 2 | 0-5×1, 0-8×1 | 2025-08-16 |
| Ticket_znovuotvorenie ked niekto urobí v close tickete aktivitu (20250710) | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2025-07-10 |
| VBattery - Cenová Ponuka vbatt. Domacnosti - PRODUKCIA | Kontakty | áno | LIST_BASED | áno | 22 | 0-4×4, 0-5×8, LIST_BRANCH×1, 0-43347357×3, 0-3×1, 0-11×4, 0-1×1 | 2024-11-29 |
| Výkup elektriny: Automatically change ticket status when an email is sent to a customer. | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Výkup: Change ticket status when an email is sent to a sales rep | Tickety | áno | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Vyplnenie Contact Name (association) pre Domácnosť | Kontakty | áno | EVENT_BASED | nie | 2 | CUSTOM_CODE×1, 0-5×1 | 2026-06-02 |
| Vypočítaj províziu pre obchodníka | Dealy | áno | LIST_BASED | áno | 1 | 1-39798786×1 | 2024-02-02 |
| xml433Domacnost - Automaticke poslanie emailu + Vytvorenie Dealu - PRODUKCIA | Dealy | áno | LIST_BASED | nie | 5 | 0-4×1, 0-5×3, 0-1×1 | 2023-05-21 |
| xml43DDomacnost - Automaticke poslanie emailu + Vytvorenie Dealu - PRODUKCIA | Dealy | áno | LIST_BASED | nie | 5 | 0-4×1, 0-5×3, 0-1×1 | 2023-09-23 |
| xml43DOrganizacia - Automaticke poslanie emailu + Vytvorenie Dealu - PRODUKCIA (cloned) | Dealy | áno | LIST_BASED | nie | 5 | 0-4×1, 0-5×3, 0-1×1 | 2023-09-25 |
| Zapis LZ/VZ do dealu podla OOM | Dealy | áno | LIST_BASED | áno | 4 | LIST_BRANCH×2, 0-5×2 | 2024-04-06 |
| ZC_copy Subjekt do Zmluvná cena | Zmluvné ceny | áno | LIST_BASED | áno | 1 | 0-5×1 | 2023-12-20 |
| ZC_doba neurčitá_doplň 31.12.2099 | Zmluvné ceny | áno | LIST_BASED | áno | 1 | 0-5×1 | 2024-01-16 |
| Znovuoslovenie VB (MQL) | Kontakty | áno | LIST_BASED | nie | 3 | 0-1×1, 0-23×1, 0-11×1 | 2024-11-29 |
| BACKUP VBattery - Cenová Ponuka vbatt. Domacnosti - PRODUKCIA (cloned) | Kontakty | nie | LIST_BASED | áno | 9 | 0-4×2, 0-5×4, LIST_BRANCH×1, 0-43347357×1, 0-3×1 | 2026-05-15 |
| Change ticket status when an email is sent to a customer | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| EES_Elektromobilita Workflow | Kontakty | nie | LIST_BASED | nie | 3 | 0-5×2, 0-14×1 | 2026-01-27 |
| Elektromobilita Customers | Kontakty | nie | LIST_BASED | nie | 2 | 0-1×1, 0-23×1 | 2024-03-22 |
| Frontoffice TWL: Automatically change ticket status when a customer replies to an email. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Frontoffice TWL: Automatically change ticket status when an email is sent to a customer. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Frontoffice: Change ticket status when a customer replies to an email | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Frontoffice: Change ticket status when an email is sent to a customer | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Green - eskalačný email 1 | Dealy | nie | LIST_BASED | áno | 3 | 0-1×1, 0-4×1, 0-5×1 | 2026-08-27 |
| Green - eskalačný email 2 | Dealy | nie | LIST_BASED | áno | 3 | 0-1×1, 0-4×1, 0-5×1 | 2026-08-27 |
| Green - eskalačný email 3 | Dealy | nie | LIST_BASED | áno | 3 | 0-1×1, 0-4×1, 0-5×1 | 2026-08-27 |
| Green - eskalačný email uzavretie dealu | Dealy | nie | LIST_BASED | áno | 2 | 0-1×1, 0-5×1 | 2026-08-27 |
| GRN / Energia B2B / Blog Subscribe | Kontakty | nie | LIST_BASED | nie | 1 | 0-5×1 | 2026-08-18 |
| GRN / Energia B2C / Blog Subscribe | Kontakty | nie | LIST_BASED | nie | 1 | 0-5×1 | 2026-08-18 |
| GRN / Producenti B2B / 5 Contract Signed | Kontakty | nie | LIST_BASED | nie | 1 | 0-5×1 | 2022-09-20 |
| GRN / Referral Program / 1 Visited Referral Page | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Referral Program / 2 Virtual Promoter | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Referral Program / 3 Active Promoter | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Reseller / 1 Visited Reseller Page | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Reseller / 2 Book Resellers Demo | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Reseller / 3 Apply to reseller program | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Reseller / 4 Reseller Onboarded | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| GRN / Reseller / 5 Active Reseller | Kontakty | nie | LIST_BASED | áno | 0 |  | 2022-09-20 |
| Lead_diskvalifikovaný_vymaž kontakt | 0-136 | nie | LIST_BASED | áno | 2 | 0-5×2 | 2026-06-30 |
| Nastav LEAD diskvalifikovaný podľa lifecycle stage (kontakt) | Kontakty | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-06-30 |
| Nastav Stav OOM do Zmluvnej ceny (Platne/Neplatne) | OOM | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-06-30 |
| Nastav typ kontaktu podľa dealu_B2B | Dealy | nie | LIST_BASED | áno | 2 | 0-5×1, LIST_BRANCH×1 | 2026-06-30 |
| Nastav typ kontaktu podľa dealu_B2B_Výkup | Dealy | nie | LIST_BASED | áno | 2 | LIST_BRANCH×1, 0-5×1 | 2026-06-30 |
| Nastav typ kontaktu podľa dealu_B2C | Dealy | nie | LIST_BASED | áno | 4 | 0-5×2, LIST_BRANCH×2 | 2026-06-30 |
| OOM Aktívne = set B2B Výkup_Zmluva Potvrdená/Nepotvrdená | OOM | nie | LIST_BASED | áno | 6 | 0-5×4, LIST_BRANCH×2 | 2026-06-30 |
| OOM Aktívne = set B2B Zmluva Potvrdená/Nepotvrdená | OOM | nie | LIST_BASED | áno | 6 | 0-5×4, LIST_BRANCH×2 | 2026-06-30 |
| Oslovenie UniCredit Bank | Kontakty | nie | LIST_BASED | nie | 2 | 0-23×1, 0-1×1 | 2025-05-20 |
| Pipeline is "NEPOUZIVAT TWL - Backoffice", Ticket status is "Zatvorený" | Tickety | nie | LIST_BASED | nie | 0 |  | 2021-10-21 |
| Send a follow-up email after form submission | Kontakty | nie | LIST_BASED | áno | 1 | 0-4×1 | 2024-02-10 |
| Send a follow-up email after form submission | Kontakty | nie | LIST_BASED | áno | 0 |  | 2024-02-10 |
| Správa pohľadávok TWL: Automatically change ticket status when a customer replies to an email. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Správa pohľadávok TWL: Automatically change ticket status when an email is sent to a customer. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Správa pohľadávok: Change ticket status when a customer replies to an email | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Správa pohľadávok: Change ticket status when an email is sent to a customer | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| test | Kontakty | nie | MANUAL | nie | 0 |  | 2025-03-15 |
| Ticket_znovuotvorenie ked niekto urobí v close tickete aktivitu | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2025-07-10 |
| Vianočné poďakovanie_jednorázovo | Kontakty | nie | LIST_BASED | nie | 1 | 0-4×1 | 2024-01-25 |
| Výkup elektriny: Automatically change ticket status when a customer replies to an email. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| ZAKAZANY Ticket status "Čakáme na vyjadrenie zákazníka" znovuotvorenie | Tickety | nie | LIST_BASED | nie | 0 |  | 2025-08-15 |
| Zákaznícke služby TWL: Automatically change ticket status when a customer replies to an email. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Zákaznícke služby TWL: Automatically change ticket status when an email is sent to a customer. | Tickety | nie | LIST_BASED | áno | 1 | 0-5×1 | 2026-08-27 |
| Zapíš OWNER podľa Dealu do Kontaktu a Company | Dealy | nie | LIST_BASED | áno | 2 | 0-5×2 | 2024-03-06 |
| Zapíš owner z dealu do Zmluvné ceny a OOM | Dealy | nie | LIST_BASED | áno | 2 | 0-5×2 | 2024-02-08 |
| zmena OP green car | Kontakty | nie | LIST_BASED | nie | 1 | 0-23×1 | 2023-06-27 |
| Znovuoslovenie VB (Opp) | Kontakty | nie | LIST_BASED | nie | 2 | 0-1×1, 0-23×1 | 2024-03-25 |

## Marketingové e-maily

| Názov | Predmet | Typ | Stav | Upravené |
| --- | --- | --- | --- | --- |
| Ticket created | [{{ ticket.hs_ticket_id }}] Your ticket has been received | TICKET_EMAIL | AUTOMATED | 2019-06-13 |
| Ticket closed | [{{ ticket.hs_ticket_id }}] Your ticket has been closed | TICKET_EMAIL | AUTOMATED | 2019-06-13 |
| Zákaznícka lojalita_Greenlogy | Greenlogy_Pomôžte nám zlepšovať sa | FEEDBACK_NPS_EMAIL | AUTOMATED | 2024-08-01 |
| Prieskum spokojnosti_Greenlogy | Dobrý deň p. {{ contact.lastname }}, ako ste bol/la s nami spokojný/ná? | FEEDBACK_CUSTOM_EMAIL | AUTOMATED | 2024-08-01 |
| Nová Zmluva - Vitajte v Greenlogy | Dobrý deň p. {{ contact.lastname }} vitajte v Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2021-08-05 |
| Eskalačný email 1 - Greenlogy - ponuka_DOM | Greenlogy - 100% zelená elektrina zo Slovenska | AUTOMATED_EMAIL | AUTOMATED | 2021-08-05 |
| Ticket closed | Your ticket '{{ticket.subject}}' has been closed | TICKET_EMAIL | AUTOMATED | 2020-04-22 |
| Ticket received | Your ticket '{{ticket.subject}}' has been received | TICKET_EMAIL | AUTOMATED | 2020-04-22 |
| Greenlogy blog - prihlásenie na odber | Prihlásenie k odberu informácií z Greenlogy blogu | FOLLOWUP_EMAIL | AUTOMATED_FOR_FORM | 2020-10-19 |
| Znovuprihlásenie k odberu emailov | p. {{ contact.lastname }} chceli by ste sa znova prihlásiť k odberu e-mailových správ z Greenlogy? | RESUBSCRIBE_EMAIL | PUBLISHED | 2023-03-08 |
| Tiket uzavretý GR - nový vizuál | Dobrý deň, tím Greenlogy má pre Vás dobrú správu | AUTOMATED_EMAIL | AUTOMATED | 2025-09-18 |
| Eskalačný email 2 - Greenlogy - ponuka_DOM | Greenlogy - 100% zelená elektrina zo Slovenska | AUTOMATED_EMAIL | AUTOMATED | 2021-08-05 |
| Eskalačný email 3 - Greenlogy - ponuka_DOM | Greenlogy - 100% zelená elektrina zo Slovenska | AUTOMATED_EMAIL | AUTOMATED | 2021-08-02 |
| Greenlogy - GreenCar voucher_100EUR | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2022-10-07 |
| Greenlogy - GreenCar voucher_50EUR | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2022-11-08 |
| Tiket otvorený GR - nový vizuál | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2026-01-07 |
| Tiket otvorený GR - TEST | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2022-05-26 |
| Ponuka pre výkup elektriny | Vaša ponuka na výkup elektriny od ⚡ Greenlogy | BATCH_EMAIL | PUBLISHED | 2022-09-27 |
| Greenlogy_virtualna bateria | Greenlogy služba virtuálnej batérie | AUTOMATED_EMAIL | AUTOMATED | 2024-04-10 |
| Greenlogy_virtualna bateria_Max | Greenlogy služba virtuálnej batérie | BATCH_EMAIL | PUBLISHED | 2022-09-22 |
| Greenlogy_virtualna bateria (MQL) | Greenlogy služba virtuálnej batérie | AUTOMATED_EMAIL | AUTOMATED | 2024-06-04 |
| Greenlogy_Opportunity VBattery2023 | Greenlogy služba virtuálnej batérie | AUTOMATED_EMAIL | AUTOMATED_DRAFT | 2023-03-13 |
| Greenlogy VBattery - cenova ponuka | Greenlogy VBattery - cenova ponuka | AUTOMATED_EMAIL | AUTOMATED | 2023-03-09 |
| Greenlogy_Vianoce | Vianočný pozdrav | AUTOMATED_EMAIL | AUTOMATED | 2022-12-15 |
| Greenlogy_App | Už máte našu novú mobilnú aplikáciu? | BATCH_EMAIL | PUBLISHED | 2023-01-21 |
| Cenová ponuka online opäť dostupná | Cenová ponuka online opäť dostupná | BATCH_EMAIL | DRAFT | 2023-02-21 |
| Greenlogy_OP AKU | Zmena obchodných podmienok GreenVBattery od 1.4.2023 | BATCH_EMAIL | PUBLISHED | 2023-02-24 |
| Greenlogy - GreenCar voucher_25EUR | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2023-02-27 |
| E-mail energodotácie MHSR | Energodotácie Ministerstvo Hospodárstva SR | AUTOMATED_EMAIL | AUTOMATED | 2023-03-07 |
| Greenlogy VBattery - cenova ponuka + nabijanie elektromobilu | Greenlogy VBattery - cenova ponuka + nabijanie elektromobilu | AUTOMATED_EMAIL | AUTOMATED | 2023-03-08 |
| New email |  | AUTOMATED_EMAIL | AUTOMATED_DRAFT | 2023-03-08 |
| Greenlogy VBattery - cenova ponuka ANO VB + NIE GreenCar (Clone EVA) | Greenlogy VBattery - cenova ponuka | AUTOMATED_EMAIL | AUTOMATED | 2025-02-20 |
| Greenlogy VBattery - cenova ponuka ANO VB + ANO GreenCar (Clone EVA) | Greenlogy VBattery - cenova ponuka + nabijanie elektromobilu | AUTOMATED_EMAIL | AUTOMATED | 2025-02-20 |
| Customer Loyalty Survey 2 | Hey, how are we doing? | FEEDBACK_NPS_EMAIL | AUTOMATED | 2024-08-01 |
| E-mail energodotácie MHSR info feb | Energodotácie Ministerstvo Hospodárstva SR_februar | AUTOMATED_EMAIL | AUTOMATED_DRAFT | 2023-03-10 |
| CP_VBattery_Opportunity_regular | Greenlogy služba virtuálnej batérie | BATCH_EMAIL | PUBLISHED | 2023-03-13 |
| Ponuka_elektromobilita_firmy LZ | Postavte si vlastnú nabíjaciu stanicu pre elektromobily | BATCH_EMAIL | PUBLISHED | 2023-04-12 |
| Greenlogy - GreenCar voucher (EMAIL AUTOMAT) | Dobrý deň, pozdravujeme z Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2025-10-21 |
| Vykup B2B reoslovenie SQL | Výkup elektriny Greenlogy | AUTOMATED_EMAIL | AUTOMATED_DRAFT | 2023-08-22 |
| Greenlogy - XML433 Domacnost - OM preslo do BS GLG (EMAIL AUTOMAT) | Vase odberne miesto {{ personalization_token('deal.xml433domacnosti_eic', '-') }} uspesne prejde ku Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2025-01-21 |
| Greenlogy - XML354 Domacnost - OM NEPRESLO do BS GLG (EMAIL AUTOMAT) | Vasemu odbernemu miestu sa nepodarilo prejst do Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2023-05-22 |
| Ponuka_elektromobilita_firmy LZ (workflow) | Postavte si vlastnú nabíjaciu stanicu pre elektromobily | AUTOMATED_EMAIL | AUTOMATED | 2023-05-29 |
| Greenlogy_zmena OP Green Car | Zmena obchodných podmienok pre službu Green Car | BATCH_EMAIL | PUBLISHED | 2023-06-29 |
| Greenlogy_zmena OP GreenCar | Služba GreenCar dostupná aj pre klientov s aktívnou službou AKU | BATCH_EMAIL | PUBLISHED | 2023-08-17 |
| Greenlogy_Financovanie_draft | Využite možnosť financovania pre modernizáciu vašej domácnosti s Greenlogy a UniCredit Bank | AUTOMATED_EMAIL | AUTOMATED | 2023-09-19 |
| Greenlogy - XML43D Domacnost - OM preslo do BS GLG (EMAIL AUTOMAT) | Vase vyrobne miesto {{ personalization_token('deal.xml43ddomacnosti_eic', '-') }} uspesne prejde ku Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2025-01-07 |
| Greenlogy - XML43D Organizacia - OM preslo do BS GLG (EMAIL AUTOMAT) | Vase vyrobne miesto {{ personalization_token('deal.xml43dorganizacie_eic', '-') }} uspesne prejde ku Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2024-03-01 |
| Greenlogy_GreenShare | Služba zdieľania energie je tu! GreenShare | BATCH_EMAIL | PUBLISHED | 2023-10-12 |
| Greenlogy_Vianoce new | Vianočný pozdrav | AUTOMATED_EMAIL | AUTOMATED | 2023-12-14 |
| Greenlogy VBattery - cenova ponuka NIE VB + NIE GreenCar (Clone EVA) | Greenlogy_Cenova ponuka | AUTOMATED_EMAIL | AUTOMATED | 2024-05-24 |
| Greenlogy VBattery - cenova ponuka NIE VB + ANO GreenCar (Clone EVA) | Greenlogy_cenova ponuka + nabijanie elektromobilu | AUTOMATED_EMAIL | AUTOMATED | 2025-02-20 |
| CP_Vykup B2B Denis test | Cenová ponuka Výkup Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2024-06-06 |
| CP_Vykup B2B Denis test_ručne | Cenová ponuka Výkup Greenlogy | BATCH_EMAIL | DRAFT | 2024-06-06 |
| CP_Vykup B2B Denis test_ručný zoznam | Cenová ponuka Výkup Greenlogy | AUTOMATED_EMAIL | AUTOMATED | 2024-06-06 |
| Pomôžete nám vymyslieť nové rozšírenie služby?🙏 | Pomôžete nám vymyslieť nové rozšírenie služby?🙏 | BATCH_EMAIL | PUBLISHED | 2024-10-22 |
| New email |  | BATCH_EMAIL | DRAFT | 2024-10-31 |
| Greenlogy_zmena OP VB 5.3.2025 | Zmena obchodných podmienok Green VBattery od 5.3.2025 | BATCH_EMAIL | PUBLISHED | 2025-02-07 |
| GreenSolar - notifikácia pre Mirku | GreenSolar - notifikácia o podpísanej zmluve | AUTOMATED_EMAIL | AUTOMATED | 2025-03-17 |
| TEST Greenlogy VBattery - cenova ponuka NIE VB + NIE GreenCar (Clone EVA) (Clone) | Greenlogy_Cenova ponuka | AUTOMATED_EMAIL | AUTOMATED_DRAFT | 2025-03-28 |
| Batériové úložisko_check in | Greenlogy - Prieskum k batériovým úložiskám | BATCH_EMAIL | PUBLISHED | 2025-04-09 |
| Batériové úložisko_check in_firmy | Greenlogy - Prieskum k batériovým úložiskám | BATCH_EMAIL | PUBLISHED | 2025-04-09 |
| Greenlogy_GreenViWA | Pripravujeme pre vás novú službu: Green ViWA | BATCH_EMAIL | PUBLISHED | 2025-09-04 |
| Greenlogy_Green VIWA po ebooku | Green ViWA virtualna penazenka pre firmy | AUTOMATED_EMAIL | AUTOMATED | 2025-10-08 |
| GREEN ViWA NEP leads | Green ViWA virtuálna peňaženka pre vašu firemnú energiu | BATCH_EMAIL | PUBLISHED | 2025-10-08 |
| pozvánka na webinár | Pozvánka na bezplatný webinár Greenlogy a GreenWay | BATCH_EMAIL | PUBLISHED | 2025-11-10 |
| Greenlogy_Green VIWA manuál | Green ViWA manual | BATCH_EMAIL | PUBLISHED | 2025-11-28 |
| Zmena cien VB | Informácia o úprave cien služby virtuálnej batérie od 1. 4. 2026 | BATCH_EMAIL | PUBLISHED | 2026-01-12 |
| Zmena cien VB (čakačka) | Informácia o úprave cien služby virtuálnej batérie od 1. 4. 2026 | BATCH_EMAIL | PUBLISHED | 2026-01-19 |
| Greenlogy_zmena OP VB 1.7.2026 | Zmena obchodných podmienok Green VBattery od 1.7.2026 | BATCH_EMAIL | PUBLISHED | 2026-05-28 |
| Greenlogy_zmena OP VB 1.7.2026 | Zmena obchodných podmienok Green VBattery od 1.7.2026 | BATCH_EMAIL | PUBLISHED | 2026-05-29 |
| Greenlogy_zmena OP VB 1.10.2026 | Zmena obchodných podmienok Green VBattery od 1.10.2026 | BATCH_EMAIL | DRAFT | 2026-08-28 |
| Dotaznik_FVE | Pomôžte nám pripraviť služby na mieru Vašej fotovoltike | BATCH_EMAIL | PUBLISHED | 2026-10-07 |
| Dotaznik_FVE (dotaznik2) | Pomôžte nám pripraviť služby na mieru Vašej fotovoltike | BATCH_EMAIL | PUBLISHED | 2026-10-08 |
| Dotaznik_FVE (dotaznik3) | Pomôžte nám pripraviť služby na mieru Vašej fotovoltike | BATCH_EMAIL | PUBLISHED | 2026-10-09 |
| Dotaznik_FVE (dotaznik4) | Pomôžte nám pripraviť služby na mieru Vašej fotovoltike | BATCH_EMAIL | SCHEDULED | 2026-10-09 |
| Dotaznik_FVE (dotaznik5) | Pomôžte nám pripraviť služby na mieru Vašej fotovoltike | BATCH_EMAIL | SCHEDULED | 2026-10-09 |

## Šablóny predajných e-mailov

Vynechané z inventára – HubSpot pre ne nemá verejné API. Rozhodnutie (2026-10-10): funkcia šablón bude v CRM, texty sa prenesú ručne.

## Sekvencie

_žiadne_

## Ponuky (quotes)

Ponúk spolu: 2 436.

### Šablóny ponúk

| Názov | Aktívna |
| --- | --- |
| 3_GLG_ELEKTRINA_VYKUP_NEW | false |
| GLG_ELEKTRINA_DODATOK_NEW | false |
| GLG_ELEKTRINA_NEW_SPOT | false |
| GLG_ELEKTRINA_VYKUP_SPOT_NEW | false |
| Default Basic | false |
| Default Modern | false |
| Default Original | false |
| 1_GLG_ELEKTRINA_NEW_V2_spotreba | false |
| 3_GLG_ELEKTRINA_NEW_V2_vykup_FTVE | false |
| 4_GLG_ELEKTRINA_NEW_V2_vykup_FIX | false |
| 2_GLG_ELEKTRINA_NEW_V2_spotreba_bez záloh | false |
| CP_greenlogy_VÝKUP_FIX_elektriny s objednávkou | true |
| CP_greenlogy_VÝKUP_SPOT_elektriny s objednávkou | true |
| CP_greenlogy_GREEN_VIWA_2025 | true |
| CP_greenlogy_DODÁVKA_FIX_elektriny_2025 | false |
| CP_greenlogy_DODÁVKA_SPOT_elektriny_2025 | false |
| CP_ELEKTRINA_FIX s objednávkou | true |
| CP_ELEKTRINA_SPOT s objednávkou | true |

## Formuláre

Aktívnych formulárov: 21 (archivovaných 0).

### Výkup elektriny - form

Typ: hubspot, vytvorený 2020-05-07.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `company` | Názov spoločnosti | single_line_text | Kontakty | áno | nie |
| `ico_new` | IČO | number | Firmy | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefónne číslo | mobile_phone | Kontakty | áno | nie |
| `distribucna_oblast` | Distribučná oblasť | dropdown | Tickety | nie | nie |
| `lokalny_zdroj1` | Lokálny zdroj | dropdown | Tickety | nie | nie |
| `vykon_zdroja` | Výkon zdroja | number | Tickety | áno | nie |
| `podpora_vyroby_elektriny_doplatkom_pripaltkom` | Podpora doplatkom/príplatkom | dropdown | Tickety | nie | nie |
| `typ_vyrobneho_zdroja` | Typ výrobného zdroja | dropdown | Tickety | nie | nie |
| `prajete_si_vypracovat_cenovu_ponuku_aj_na_dodavku_elektriny_` | Prajete si vypracovať cenovú ponuku aj na dodávku elektriny? | dropdown | Tickety | nie | nie |
| `content` | Tu môžete doplniť ďalšie infomácie | multi_line_text | Tickety | nie | nie |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |
| `subject` | Názov požiadavky | single_line_text | Tickety | nie | áno |

### GD form_reseller program

Typ: hubspot, vytvorený 2024-02-08.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | áno | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `phone` | Telefónne číslo | phone | Kontakty | áno | nie |
| `subjekt` | Názov firmy | single_line_text | Kontakty | nie | nie |
| `reseller_produkt` | Doporučil som | multiple_checkboxes | Kontakty | nie | nie |

### GREENLOGY - GreenViWA form

Typ: hubspot, vytvorený 2025-05-14.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `company` | Názov spoločnosti | single_line_text | Kontakty | áno | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `ico` | IČO | single_line_text | OOM | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefón | mobile_phone | Kontakty | áno | nie |
| `ste_zakaznikom_greenlogy__new` | Ste zákazníkom Greenlogy? | radio | Kontakty | áno | nie |
| `ake_sluzby_mate_u_nas_zazmluvnene_` | Aké služby máte u nás zazmluvnené? | radio | Firmy | nie | áno |
| `subject` | Požiadavka - názov tiketu | single_line_text | Tickety | nie | áno |
| `ako_vas_mame_kontaktovat_` | Ako Vás máme kontaktovať? | multiple_checkboxes | Kontakty | áno | nie |
| `content` | Chcete nás ešte o niečom informovať? | multi_line_text | Tickety | nie | nie |

### Subscribe to Blog Greenlogy Notifications 11732875214

Typ: hubspot, vytvorený 2019-07-31.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `email` | E-mail | email | Kontakty | áno | nie |
| `blog_blog_greenlogy_11732875214_subscription` | Notification Frequency | radio | Kontakty | nie | áno |

### GREENLOGY - servisná požiadavka - tiket

Typ: hubspot, vytvorený 2019-06-03.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Krstné meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefón | mobile_phone | Kontakty | nie | nie |
| `subject` | Požiadavka - názov tiketu | single_line_text | Tickety | áno | nie |
| `content` | Popis požiadavky | multi_line_text | Tickety | áno | nie |
| `ako_vas_mame_kontaktovat_` | Ako Vás máme kontaktovať? | multiple_checkboxes | Kontakty | áno | nie |
| `hs_file_upload` | Priložiť prílohu | file | Tickety | nie | nie |
| `priloha` | Priložiť prílohu | file | Tickety | nie | nie |
| `hs_ticket_priority` | Priorita | dropdown | Tickety | nie | áno |
| `hs_ticket_category` | Kategória | multiple_checkboxes | Tickety | nie | áno |

### Green VBattery domacnosti - formular

Typ: hubspot, vytvorený 2022-10-20.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefónne číslo | mobile_phone | Kontakty | áno | nie |
| `subject` | Názov ticketu | single_line_text | Tickety | nie | áno |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |
| `content` | Poznámka | multi_line_text | Tickety | nie | nie |
| `hs_ticket_category` | Kategória | multiple_checkboxes | Tickety | nie | áno |

### GREENLOGY - GreenShare form

Typ: hubspot, vytvorený 2023-09-26.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Krstné meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefón | mobile_phone | Kontakty | nie | nie |
| `ste_zakaznikom_greenlogy__new` | Ste zákazníkom Greenlogy? | radio | Kontakty | nie | nie |
| `mate_aktivnu_sluzbu_virtualnej_baterie_v_greenlogy__new` | Máte aktívnu službu Virtuálnej batérie v Greenlogy?&nbsp; | radio | Kontakty | nie | nie |
| `ako_chcete_vyuzivat_sluzbu_greenshare__new` | Ako chcete využívať službu GreenShare?&nbsp; | radio | Kontakty | nie | nie |
| `subject` | Požiadavka - názov tiketu | single_line_text | Tickety | nie | áno |
| `ako_vas_mame_kontaktovat_` | Ako Vás máme kontaktovať? | multiple_checkboxes | Kontakty | áno | nie |
| `content` | Chcete nás ešte o niečom informovať? | multi_line_text | Tickety | nie | nie |

### GD form_referral program

Typ: hubspot, vytvorený 2024-02-10.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | áno | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `phone` | Telefónne číslo | phone | Kontakty | áno | nie |
| `reseller_produkt` | Doporučil som | multiple_checkboxes | Kontakty | nie | nie |

### eBook download_WEB_Green VIWA

Typ: hubspot, vytvorený 2025-08-15.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `email` | E-mail | email | Kontakty | áno | nie |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | nie | nie |
| `company` | Company name | single_line_text | Kontakty | áno | nie |

### GreenConnect - prevzatie zodpovednosti B2C

Typ: hubspot, vytvorený 2026-09-03.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Krstné meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefón | mobile_phone | Kontakty | áno | nie |
| `subject` | Žiadosť o prevzatie zodpovednosti za odchýlku B2C | single_line_text | Tickety | áno | nie |
| `content` | Popis požiadavky | multi_line_text | Tickety | nie | nie |
| `priloha` | Zmluva o pripojení malého výrobného zdroja | file | Tickety | nie | nie |
| `hs_ticket_priority` | Priorita | dropdown | Tickety | nie | áno |
| `hs_ticket_category` | Kategória | multiple_checkboxes | Tickety | nie | áno |

### Green SOLAR_domácnosti - form

Typ: hubspot, vytvorený 2021-09-09.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefónne číslo | mobile_phone | Kontakty | áno | nie |
| `country` | Obec | single_line_text | Kontakty | áno | nie |
| `distribucna_oblast` | Región | dropdown | Tickety | nie | nie |
| `rocna_spotreba_na_om` | Uveďte Vašu ročnú spotrebu na odbernom mieste | number | Kontakty | nie | nie |
| `subject` | Názov ticketu | single_line_text | Tickety | nie | áno |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |
| `content` | Poznámka | multi_line_text | Tickety | nie | nie |

### Career

Typ: hubspot, vytvorený 2023-05-03.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `message` | Poznámka | multi_line_text | Kontakty | nie | nie |
| `zivotopis` | Životopis | file | Kontakty | nie | nie |

### Legitimate interest - Blog GLG

Typ: hubspot, vytvorený 2020-05-14.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `email` |  | email | Kontakty | nie | nie |

### Registrácia_partnerský program

Typ: hubspot, vytvorený 2024-02-10.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | <strong>Meno</strong> | single_line_text | Kontakty | nie | nie |
| `lastname` | <strong>Priezvisko</strong> | single_line_text | Kontakty | nie | nie |
| `email` | <strong>E-mail</strong> | email | Kontakty | áno | nie |
| `phone` | <strong>Telefónne číslo</strong> | phone | Kontakty | nie | nie |
| `company` | <strong>Názov spoločnosti</strong> | single_line_text | Kontakty | nie | nie |
| `o_aky_typ_partnerstva_mate_zaujem_` | <strong>O aký typ partnerstva máte záujem?</strong> | multiple_checkboxes | Kontakty | nie | nie |

### eBook download_WEB_september_2021

Typ: hubspot, vytvorený 2021-09-08.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |

### Green SOLAR_firmy - form

Typ: hubspot, vytvorený 2021-10-04.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `company` | Názov spoločnosti | single_line_text | Kontakty | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefónne číslo | mobile_phone | Kontakty | áno | nie |
| `distribucna_oblast` | Región | dropdown | Tickety | nie | nie |
| `subject` | Názov ticketu | single_line_text | Tickety | nie | áno |
| `content` | Poznámka | multi_line_text | Tickety | nie | nie |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |

### Formulár pre web Bez napätia

Typ: hubspot, vytvorený 2020-06-04.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `magazin_bez_napatia_` | <strong>Magazín "Bez napätia"</strong> | dropdown | Kontakty | nie | nie |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | nie | nie |
| `company` | Názov spoločnosti | single_line_text | Kontakty | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefónne číslo | mobile_phone | Kontakty | nie | nie |

### GREENLOGY - PONUKY - Firmy

Typ: hubspot, vytvorený 2021-02-18.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `company` | Názov firmy | single_line_text | Kontakty | áno | nie |
| `ico_new` | IČO | number | Firmy | nie | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `phone` | Telefónne číslo | phone | Kontakty | nie | nie |
| `komodita_slu_ba` | Produkt | dropdown | Tickety | nie | nie |
| `planovany_objem_vykupu__mwh_` | Predpokladaná ročná spotreba [MWh] | number | OOM | áno | nie |
| `content` | Doplňujúce informácie | multi_line_text | Tickety | nie | nie |
| `priloz_subor` | Vložte prílohu | file | Kontakty | nie | nie |
| `subject` | Názov ticketu | single_line_text | Tickety | nie | áno |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |
| `typ_zmluvy` | Typ zmluvy | single_line_text | Kontakty | nie | áno |
| `koniec_zmluvy` | Koniec Zmluvy | single_line_text | Kontakty | nie | áno |

### E-Mobility

Typ: hubspot, vytvorený 2023-02-06.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `e_mobility__mam_zaujem_o_blizsie_informacie_ohladom` | Mám záujem o bližšie informácie ohľadom | dropdown | Kontakty | nie | nie |
| `firstname` | Meno | single_line_text | Kontakty | nie | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | nie | nie |
| `name` | Názov spoločnosti | single_line_text | Firmy | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `phone` | Telefónne číslo | phone | Kontakty | nie | nie |
| `segment` | Typ kontaktu | multiple_checkboxes | Kontakty | nie | áno |

### Offer Form

Typ: hubspot, vytvorený 2020-06-18.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `firstname` | Krstné meno | single_line_text | Kontakty | áno | nie |
| `email` | Email | email | Kontakty | áno | nie |
| `phone` | Telefón | phone | Kontakty | nie | nie |
| `suhlasim_so_spracovanim_udajov_` | Súhlasím so spracovaním údajov&nbsp; | single_checkbox | Kontakty | áno | nie |
| `pscd` | PSČ | number | Kontakty | áno | nie |
| `poznam_svoju_tarifu_a_rocnu_spotrebu_` | Poznám svoju tarifu a ročnú spotrebu? | radio | Kontakty | nie | nie |
| `vybrat_tarifu_` | Vybrať tarifu... | dropdown | Kontakty | áno | nie |
| `kwhf` | kWh | number | Kontakty | áno | nie |
| `chcete_pridat_dalsie_odberne_miesto_` | Chcete pridať ďalšie odberné miesto? | radio | Kontakty | nie | nie |

### GREENLOGY - GreenShare pre firmy form

Typ: hubspot, vytvorený 2025-08-18.

| Pole | Label | Typ | Objekt | Povinné | Skryté |
| --- | --- | --- | --- | --- | --- |
| `company` | Názov spoločnosti | single_line_text | Kontakty | áno | nie |
| `lastname` | Priezvisko | single_line_text | Kontakty | áno | nie |
| `email` | E-mail | email | Kontakty | áno | nie |
| `mobilephone` | Telefón | mobile_phone | Kontakty | nie | nie |
| `ste_zakaznikom_greenlogy__new` | Ste zákazníkom Greenlogy? | radio | Kontakty | áno | nie |
| `ako_chcete_vyuzivat_sluzbu_darovania_kreditov_` | Ako chcete využívať službu darovania kreditov? | radio | Kontakty | áno | nie |
| `subject` | Požiadavka - názov tiketu | single_line_text | Tickety | nie | áno |
| `ako_vas_mame_kontaktovat_` | Ako Vás máme kontaktovať? | multiple_checkboxes | Kontakty | áno | nie |
| `content` | Chcete nás ešte o niečom informovať? | multi_line_text | Tickety | nie | nie |

## Používatelia a tímy

| Meno | Rola | Tímy | Stav |
| --- | --- | --- | --- |
| Greenlogy | – | – | iba vlastník |
| (bez mena) | – | Sales_external | aktívny |
| (bez mena) | – | Sales_external | aktívny |
| (bez mena) | – | Sales_external | aktívny |
| (bez mena) | – | Sales_external | aktívny |
| (bez mena) | – | Sales_external | aktívny |
| (bez mena) | – | Sales_external | aktívny |
| Ondrej Chovanec | Sales_external | Sales_external | aktívny |
| Daniel Dérer | Super Admin | Sales_internal | aktívny |
| Michaela Foltánová | Super Admin | – | aktívny |
| Denisa Hajdúková | – | – | aktívny |
| Lucia Hubočanová | OfficeZA_Frontoffice | OfficeZA_Frontoffice | aktívny |
| Eva Husková | OfficeZA | OfficeZA | aktívny |
| Sidonia Jeskova/Levice | Sales_external | Sales_external | aktívny |
| Michal Jirasek | – | Supplier_external | aktívny |
| Peter Kalman | Super Admin | CEO, Marketing | aktívny |
| Denis Kalman | Super Admin | Sourcing | aktívny |
| Eva Kalmanová | Super Admin | Marketing | aktívny |
| Martin Kuchár | – | Sales_external | aktívny |
| Anna Machyniakova | OfficeZA | OfficeZA | aktívny |
| Ján Macko | Sales_external | Sales_external | aktívny |
| Dominika Mihalíková | OfficeZA | OfficeZA | aktívny |
| Katarína Mores | OfficeZA | OfficeZA | aktívny |
| Andreas Muňoz | Sales_external | Sales_external | aktívny |
| Zlatica Muráriková | OfficeZA_Frontoffice | OfficeZA | aktívny |
| Roman Muska | – | – | aktívny |
| Natália Ružičková | OfficeZA_Frontoffice | OfficeZA_Frontoffice | aktívny |
| Pavol Sekelský | Super Admin | Supplier_external | aktívny |
| Eva Ševčíková | – | OfficeZA | aktívny |
| - System | Super Admin | Supplier_external | aktívny |
| Miroslava Tomčíková | OfficeZA | OfficeZA | aktívny |
| (bez mena) | – | – | archivovaný |
| (bez mena) | – | – | archivovaný |
| (bez mena) | – | – | archivovaný |
| (bez mena) | – | – | archivovaný |
| (bez mena) | – | – | archivovaný |
| Edita Angyalova | – | – | archivovaný |
| Roman Beňo | – | – | archivovaný |
| Mikulas Beskyd | – | – | archivovaný |
| Ondrej Chovanec | – | – | archivovaný |
| Martin Čižmár/Košice | – | – | archivovaný |
| Michal Daníšek | – | – | archivovaný |
| Karel Dlugoš | – | – | archivovaný |
| Dušan Fedoročko | – | – | archivovaný |
| Dušan Fedoročko/RKS | – | – | archivovaný |
| Sven Gerlach | – | – | archivovaný |
| Zlatica Gešková | – | – | archivovaný |
| Denisa Hajdúková | – | – | archivovaný |
| Miroslava Hoštáková | – | – | archivovaný |
| Eva Husková | – | – | archivovaný |
| Sidónia Ješková | – | – | archivovaný |
| Vladimír Kajan/N.Zámky | – | – | archivovaný |
| Denis Kalman | – | – | archivovaný |
| Denis Kalman | – | – | archivovaný |
| Peter Kalman | – | – | archivovaný |
| Eva Kalmanová | – | – | archivovaný |
| Jakub Kaščák | – | – | archivovaný |
| Michael Klimik | – | – | archivovaný |
| Andrea Kováčová | – | – | archivovaný |
| Martin Kuchár | – | – | archivovaný |
| alex kuna | – | – | archivovaný |
| Peter Laucik | – | – | archivovaný |
| Miroslava Lehotská | – | – | archivovaný |
| Katarína Lojová | – | – | archivovaný |
| A Lumakon | – | – | archivovaný |
| Denisa Majsniarová | – | – | archivovaný |
| Barbora Majtánová | – | – | archivovaný |
| tím Melonberries | – | – | archivovaný |
| Trujay Migrations | – | – | archivovaný |
| Andreas Muňoz | – | – | archivovaný |
| Roman Muska | – | – | archivovaný |
| Petra Očovay | – | – | archivovaný |
| Zuzka Pčolková | – | – | archivovaný |
| Michaela Ryčeková | – | – | archivovaný |
| Eva Ševčíková | – | – | archivovaný |
| Miroslav Šimko | – | – | archivovaný |
| Miroslav ŠImko | – | – | archivovaný |
| Rastislav Sopko | – | – | archivovaný |
| Rastislav Sopko | – | – | archivovaný |
| Boris Surovčík | – | – | archivovaný |
| Matej Tóth | – | – | archivovaný |
| Michaela Turošíková | – | – | archivovaný |
| Daniela Virostko | – | – | archivovaný |
| Obchodnik X - Oportunity | – | – | archivovaný |

### Tímy

| Tím | Členov |
| --- | --- |
| Sales_external | 11 |
| Marketing | 2 |
| Supplier_external | 3 |
| Sales_internal | 1 |
| Sourcing | 2 |
| CEO | 2 |
| OfficeZA | 7 |
| OfficeZA_Frontoffice | 2 |

## Typy odberu (marketingové súhlasy)

| Ukazovateľ | Kontaktov | % |
| --- | --- | --- |
| Kontaktov spolu | 8 506 |  |
| Marketingové kontakty (`hs_marketable_status`) | 8 293 | 97,5 % |
| Odhlásení zo všetkého (`hs_email_optout`) | 59 | 0,7 % |

| Typ odberu | ID | Aktívny | Predvolený | Interný | Odhlásených |
| --- | --- | --- | --- | --- | --- |
| Marketingové informácie Greenlogy | 6832158 | áno | áno | nie | 162 |
| Prihlásenie na odber blogu značky Greenlogy | 7135946 | áno | nie | nie | 135 |
| Správa produktov a služieb | 43828489 | áno | nie | nie | 82 |
| Individuálna komunikácia s klientom | 6832757 | áno | áno | áno | 68 |
| Komunikácia so zákazníckymi službami | 6904363 | áno | áno | áno | 78 |
| Default Greenlogy Blog Subscription | 6889720 | nie | nie | nie | 45 |
| Marketingové informácie Twinlogy | 20169478 | nie | nie | nie | 46 |
| Prihlásenie na odber blogu značky Twinlogy | 9356736 | nie | nie | nie | 46 |

Počet prihlásených sa nezisťuje (vyžadoval by čítanie súhlasov každého kontaktu).
