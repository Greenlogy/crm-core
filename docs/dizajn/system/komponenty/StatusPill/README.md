# StatusPill

Štítok so stavom záznamu alebo výsledkom; vždy obsahuje slovo alebo číslo, nielen farbu.

- Varianty: `positive` (Aktívne, Prijatá, plán splnený), `negative` (Odídené, Zrušené, Po termíne, plán nesplnený), `warning` (SLA sa blíži, chýbajú dáta), `info` (Odoslaná, Otvorená), neutrálny (Neaktívne, Koncept).
- Stavy OOM: Aktívne = positive, Neaktívne = neutrálny, Zrušené a Odídené = negative.
- Stavy ponuky: Koncept = neutrálny, Odoslaná a Otvorená = info, Prijatá = positive, Zamietnutá = negative.
- SLA: v termíne bez štítku, menej ako 2 pracovné hodiny = warning, po termíne = negative.
- Rozmery: text `pill`, vodorovne 10 px, rohy `radius-pill`. Bodka 6 px len pri živých stavoch (aktívne, SLA beží).
