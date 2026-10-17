// Pripojenie na databázu cez Hyperdrive (postgres.js). Jedno pripojenie na požiadavku.
// Rola crm_app bez prihláseného používateľa nevidí nič; používateľa nastavuje asUser() v transakcii.

import postgres from 'postgres';
import type { AuthEnv } from './auth';
import type { FinstatEnv } from './finstat';
import type { GmailEnv } from './gmail/gmail';
import type { MontelEnv } from './montel';

export type Env = AuthEnv & FinstatEnv & GmailEnv & MontelEnv & {
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

/** Deadlock (40P01) a chyba serializácie (40001): PostgreSQL celú transakciu vrátil, dá sa bezpečne spustiť znova. */
export function isRetryable(err: unknown): boolean {
  const code = (err as { code?: string } | null)?.code;
  return code === '40P01' || code === '40001';
}

/**
 * Transakcia na samostatnom pripojení (mimo transakcie požiadavky), po deadlocku alebo chybe serializácie spustená
 * celá znova – najviac raz (Peter 17. 10., F7). fn smie robiť iba zápisy do databázy (nič mimo nej – R2, e-mail),
 * lebo pri opakovaní sa spustí druhýkrát; prvý pokus databáza vrátila celý (aj počítadlá čísel).
 * userId = null: beh na pozadí bez používateľa.
 */
export async function withRetry<T>(sql: Sql, userId: string | null, fn: (tx: Sql) => Promise<T>): Promise<T> {
  const once = () => (userId === null ? (sql.begin((tx) => fn(tx as unknown as Sql)) as Promise<T>) : asUser(sql, userId, fn));
  try {
    return await once();
  } catch (err) {
    if (!isRetryable(err)) throw err;
    console.log(`Transakcia zopakovaná po ${(err as { code?: string }).code}`);
    return once();
  }
}
