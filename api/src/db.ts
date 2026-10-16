// Pripojenie na databázu cez Hyperdrive (postgres.js). Jedno pripojenie na požiadavku.
// Rola crm_app bez prihláseného používateľa nevidí nič; používateľa nastavuje asUser() v transakcii.

import postgres from 'postgres';
import type { AuthEnv } from './auth';
import type { FinstatEnv } from './finstat';
import type { GmailEnv } from './gmail/gmail';

export type Env = AuthEnv & FinstatEnv & GmailEnv & {
  HYPERDRIVE: Hyperdrive;
  BROWSER: Fetcher;        // Browser Run – PDF ponuky (F3)
  DOCS: R2Bucket;          // R2 crm-dokumenty-* (jurisdikcia EÚ): PDF ponúk, podpísané ponuky
  PUBLIC_OFFER_URL: string; // adresa stránky ponuky (Worker crm-ponuka)
  CRM_URL: string;          // adresa CRM (odkazy v interných e-mailoch z crm@greenlogy.com)
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

/**
 * Spustí fn v transakcii s prihláseným používateľom (SET LOCAL app.user_id): platia práva tímu (RLS)
 * a audit zapíše, kto zmenu urobil. Nastavenie sa končí s transakciou, takže sa nedostane
 * k inej požiadavke cez spoločné pripojenia Hyperdrive.
 */
export async function asUser<T>(sql: Sql, userId: string, fn: (tx: Sql) => Promise<T>): Promise<T> {
  return (await sql.begin(async (tx) => {
    await tx`SELECT set_config('app.user_id', ${userId}, true)`;
    return fn(tx as unknown as Sql);
  })) as T;
}
