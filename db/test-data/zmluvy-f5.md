# Skúška párovania zmlúv s obchodmi (modul 5, F5) na Teste

Vymyslené údaje bez osobných údajov: firmy „Testovacia Epsilon / Zeta / Théta“ (IČO 99999905–07), domácnosť „Eva Pokusná“,
EIC `24ZZS99TESTF…`, zmluvy `1129995001`–`06`. Súbory sú v presnom formáte exportov (hárok „HEO - Web Zmluvy - prehlad EE +“
a XM Trade „Prehľad“). Znova ich vytvorí `node db/test-data/zmluvy-f5-vytvor.cjs` (aj SQL na založenie a zmazanie).

## Postup

1. Párovanie musí byť zapnuté: `./db/app-setting.sh dev deal_matching on`.
2. Založiť obchody a ponuky: `./db/test-data/zmluvy-f5.sh dev vytvor` (obchodník = peter@greenlogy.com; iný e-mail ako tretí parameter).
   - **TEST F5 Epsilon 2027 (NN + VN)** – Akceptácia, ponuka FIX 2027: NN `…A01K` 120 €/MWh, VN `…A02I` 110 €/MWh;
   - **TEST F5 Zeta 2027 (iná cena)** – Akceptácia, ponuka FIX 2027: NN `…A03G` 125 €/MWh;
   - **TEST F5 Théta 2027 (Vyjednávanie)** – bez ponuky, OOM `…A05C`;
   - OOM `…A04E` (Epsilon) nie je na žiadnom obchode.
   Ponuky sú zaznačené ako ručne akceptované – obchodníkovi príde upozornenie a interný e-mail z crm@ „zákazník prijal ponuku“.
3. CRM → Zmluvy → Import: nahrať naraz `db/test-data/zmluvy-f5-office-portal.xlsx` a `zmluvy-f5-xm-trade.xlsx`.
   Ak náhľad hlási „Neznámy obchodník – Testovací Obchodník A“, pridať preklad (admin) na seba. Náhľad: 6 nových zmlúv. Uložiť.
4. Očakávaný výsledok (Zmluvy k obchodom, zoznam a karty zmlúv):

| Zmluva | Prípad | Výsledok |
| --- | --- | --- |
| 1129995001 | a) NN, rovnaké EIC a cena | spárovaná s Epsilon, obchod Vyhraté, bez príznaku |
| 1129995002 | b) VN k tomu istému obchodu | pripojená k Epsilon (Vyhraté) |
| 1129995003 | c) cena 119 namiesto 125 | spárovaná so Zeta, príznak „Cena iná ako v ponuke“ (obchodník + schvaľovatelia) |
| 1129995004 | d) OOM bez obchodu | Nespárované, upozornenie vlastníkovi zákazníka; kandidát Epsilon (EIC 0/1) |
| 1129995005 | e) domácnosť bez obchodu B2C | Bez obchodu |
| 1129995006 | f) obchod vo Vyjednávaní | spárovaná s Théta bez akceptovanej ponuky (časová os), ceny sa nekontrolujú |

5. Vyskúšať: na karte 1129995004 „Bez obchodu“ alebo „Vybrať obchod“, na 1129995001 „Zrušiť spárovanie“ (obchod ostane
   Vyhraté – má VN), uzavretie príznaku 1129995003 schvaľovateľom s poznámkou, Podklady pre zmluvu na obchode Epsilon.

Zmazanie všetkého vrátane importovaných zmlúv: `./db/test-data/zmluvy-f5.sh dev zmaz`. Ceny pod hranicou cien dňa na Teste
môžu pridať aj príznak modulu 4 „Pod hranicou bez výnimky“ – s párovaním nesúvisí.
