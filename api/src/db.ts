// Pripojenie na databázu cez Hyperdrive (postgres.js). Jedno pripojenie na požiadavku.

import postgres from 'postgres';

export type Env = {
  HYPERDRIVE: Hyperdrive;
};

export type Sql = postgres.Sql;

const DATE_OID = 1082;

export function connect(env: Env): Sql {
  return postgres(env.HYPERDRIVE.connectionString, {
    max: 5,
    fetch_types: false,
    // Dátum (date) ostáva text 'YYYY-MM-DD', aby sa neposúval o časové pásmo.
    types: {
      date: { to: DATE_OID, from: [DATE_OID], serialize: (v: string) => v, parse: (v: string) => v },
    },
  });
}
