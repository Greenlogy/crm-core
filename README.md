# crm-core

Vlastné CRM jadro Greenlogy a.s. – náhrada HubSpotu.

- Pravidlá projektu a technológie: [`CLAUDE.md`](CLAUDE.md)
- Aktuálny stav: [`docs/STAV.md`](docs/STAV.md)
- Dátový model: [`docs/01-datovy-model.md`](docs/01-datovy-model.md)
- Rozhodnutia: [`docs/rozhodnutia.md`](docs/rozhodnutia.md)

## Databáza

PostgreSQL na Neone (Frankfurt). Vetvy: `dev` = vývoj a testy, `main` = produkcia. Lokálny Postgres sa nepoužíva.

### Príprava (raz)

1. Postgres.app (https://postgresapp.com) kvôli `psql` a `pg_dump`, cesta v `PATH`:
   `echo 'export PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"' >> ~/.zprofile`
2. dbmate (verzia pevne v `package.json`):
   `cd ~/projects/greenlogy/crm-core && npm install`
3. Pripojenia v `.dev.vars` (nie je v repozitári): `DATABASE_URL_DEV`, `DATABASE_URL_MAIN` (priame pripojenie, nie pooler, `sslmode=require`).

### Migrácie

Spúšťač `db/dbmate.sh dev|main <príkaz>` načíta pripojenie z `.dev.vars` a nikde ho nevypisuje. Pri `main` treba napísať „main“. Príkazy `create` a `drop` sú zakázané, `up` = `migrate`.

```
cd ~/projects/greenlogy/crm-core && ./db/dbmate.sh dev status
cd ~/projects/greenlogy/crm-core && ./db/dbmate.sh dev up
cd ~/projects/greenlogy/crm-core && ./db/dbmate.sh dev rollback
cd ~/projects/greenlogy/crm-core && ./db/dbmate.sh main up
```

- Migrácie: `db/migrations/NNNN_nazov.sql` so sekciami `-- migrate:up` a `-- migrate:down`. Nová migrácia: `./db/dbmate.sh dev new nazov` a premenovať na ďalšie číslo.
- Každá migrácia najprv na `dev`, na `main` až po schválení. Migrácia nasadená na `main` sa nemení, zmena = nová migrácia.
- Po každom `up`/`rollback` dbmate zapíše `db/schema.sql`; commituje sa stav zodpovedajúci `main`.
- Každé spustenie migrácie (aj na `dev`) iba so súhlasom Petra.

### Testy

```
cd ~/projects/greenlogy/crm-core && ./db/test/run.sh
```

Nahrá vymyslené dáta (`db/test/seed.sql`), spustí kontroly (`db/test/checks.sql`) a transakciu vráti. Beží iba na `dev`.
