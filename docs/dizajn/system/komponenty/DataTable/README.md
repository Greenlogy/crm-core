# DataTable

Tabuľka záznamov (firmy, OOM, dealy, ponuky) v bielej karte; čísla zarovnané doprava s tabuľkovými číslicami.

- Hlavička v štýle `label` (12 px, `ink-muted`, bez verzálok), pod ňou čiara `border`; riadky oddelené `surface-muted`, hover `surface-muted`. Každý riadok je na jednom riadku, dlhý text sa skráti.
- Prvý stĺpec je názov (`body-strong`) s avatarom iniciál (`brand-tint` / `brand-text`, `radius-sm`); klik na riadok otvorí kartu záznamu.
- EIC a ID v štýle `code`. Stav ako StatusPill. Čísla v slovenskom formáte, jednotka v hlavičke stĺpca („Spotreba MWh“).
- Konzument dodáva stĺpce, riadky a akciu na klik; triedenie a filtre sú v lište nad tabuľkou.
- Údaje v náhľade sú vymyslené.
