# KpiCard

Karta s jedným číslom, porovnaním s plánom a progresom; ukladajú sa do mriežky 2–4 vedľa seba.

- Obsah: názov (`label`, `ink-muted`), štítok s percentom plnenia vpravo, hodnota `kpi-lg`, porovnanie „vs plán X · ±rozdiel“ v `label`, progres bar.
- Rozdiel je `positive` alebo `negative` a vždy so znamienkom. Progres zelený (`chart-1`) pri pláne ≥ 100 %, inak `negative`.
- Bez plánu sa zobrazí štítok „plán only“ alebo „—“ namiesto hodnoty; nikdy 0, ak dáta chýbajú.
- Karta: `surface-card`, okraj `border`, rohy `radius-lg`, vnútro `space-5`, medzera v mriežke `space-4`.
