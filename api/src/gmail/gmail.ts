// Modul 5, F4 – Gmail API cez servisný účet s delegovaním na doménu (návrh DB časť 3.7). Kľúč servisného účtu je iba
// v secrete GOOGLE_SA_KEY. Token sa vydá pre jednu schránku a jedno oprávnenie (odoslanie alebo čítanie).
//
// Čítanie (gmailRead) je jediné miesto čítania schránky: pred každým volaním gmail_read_authorize v databáze (povolí iba
// threads.get sledovaného vlákna CRM pre beh na pozadí, formát bez príloh; zapíše denník čítania), potom adresa
// z endpoints.ts (iba threads.get / messages.get). Nikdy list, search, history ani attachments.get.
// Do logu nejdú adresy, predmety ani texty – iba kód chyby.

import { importPKCS8, SignJWT } from 'jose';
import type { Sql } from '../db';
import { readUrl, type ReadFormat, type ReadMethod, SCOPE_READ, SCOPE_SEND, sendUrl, TOKEN_URL } from './endpoints';
import type { GmailMessage } from './mime';
import { base64url, recipientsAllowed } from './mime';

export type GmailEnv = {
  GOOGLE_SA_KEY?: string;    // JSON kľúča servisného účtu (wrangler secret)
  MAIL_ALLOWLIST?: string;   // Test: adresy mimo @greenlogy.com, na ktoré smie CRM posielať (wrangler secret)
  ENVIRONMENT?: string;      // test | ostre | lokal
  GMAIL_FAKE?: string;       // iba lokálne (ENVIRONMENT=lokal): odoslanie a čítanie bez Google, ID sa vymyslia
};

/** Chyba Gmailu: definitive = správa určite neodišla (odmietnutie); inak nie je isté (sieť, 5xx). */
export class GmailError extends Error {
  constructor(message: string, readonly status: number, readonly definitive: boolean) {
    super(message);
  }
}

const fake = (env: GmailEnv) => env.ENVIRONMENT === 'lokal' && env.GMAIL_FAKE === '1';

export function gmailConfigured(env: GmailEnv): boolean {
  return fake(env) || !!env.GOOGLE_SA_KEY;
}

type SaKey = { client_email: string; private_key: string };
const tokens = new Map<string, { token: string; until: number }>();

async function accessToken(env: GmailEnv, mailbox: string, scope: string): Promise<string> {
  const k = `${mailbox}|${scope}`;
  const hit = tokens.get(k);
  if (hit && hit.until > Date.now() + 60_000) return hit.token;
  if (!env.GOOGLE_SA_KEY) throw new GmailError('Gmail nie je nastavený (chýba GOOGLE_SA_KEY).', 0, true);
  let sa: SaKey;
  try {
    sa = JSON.parse(env.GOOGLE_SA_KEY) as SaKey;
  } catch {
    throw new GmailError('Gmail: neplatný kľúč servisného účtu.', 0, true);
  }
  const key = await importPKCS8(sa.private_key, 'RS256');
  const assertion = await new SignJWT({ scope })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(sa.client_email)
    .setSubject(mailbox)
    .setAudience(TOKEN_URL)
    .setIssuedAt()
    .setExpirationTime('55m')
    .sign(key);
  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }),
  });
  if (!res.ok) {
    // 400/401 invalid_grant: delegovanie, schránka alebo oprávnenie – odoslanie určite neprebehlo
    const err = ((await res.json().catch(() => ({}))) as { error?: string }).error ?? 'chyba';
    throw new GmailError(`Gmail: token pre schránku sa nevydal (${res.status} ${err}).`, res.status, true);
  }
  const j = (await res.json()) as { access_token: string; expires_in: number };
  tokens.set(k, { token: j.access_token, until: Date.now() + j.expires_in * 1000 });
  return j.access_token;
}

/** Overenie nastavenia (Nastavenia → Gmail): iba vydanie tokenu na odoslanie, schránka sa nečíta. */
export async function gmailCheck(env: GmailEnv, mailbox: string): Promise<void> {
  if (fake(env)) return;
  await accessToken(env, mailbox, SCOPE_SEND);
}

export type SendResult = { id: string; threadId: string };

/**
 * Odoslanie hotovej správy MIME (users.messages.send). Na Teste iba na @greenlogy.com a MAIL_ALLOWLIST.
 * 4xx (okrem 408) = odmietnuté, správa neodišla; sieť / 5xx / 408 = nie je isté – kód nesmie skúšať znova.
 */
export async function gmailSend(env: GmailEnv, mailbox: string, mime: string, recipients: string[], threadId: string | null): Promise<SendResult> {
  const blocked = recipientsAllowed(recipients, env.ENVIRONMENT, env.MAIL_ALLOWLIST);
  if (blocked.length) throw new GmailError('Na Teste smie CRM posielať iba na @greenlogy.com a povolené adresy.', 0, true);
  if (fake(env)) {
    const hex = () => [...crypto.getRandomValues(new Uint8Array(8))].map((b) => b.toString(16).padStart(2, '0')).join('');
    return { id: hex(), threadId: threadId ?? hex() };
  }
  const token = await accessToken(env, mailbox, SCOPE_SEND);
  let res: Response;
  try {
    res = await fetch(sendUrl(mailbox), {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ raw: base64url(new TextEncoder().encode(mime)), ...(threadId ? { threadId } : {}) }),
    });
  } catch {
    throw new GmailError('Gmail neodpovedal – nie je isté, či e-mail odišiel.', 0, false);
  }
  if (!res.ok) {
    const definitive = res.status >= 400 && res.status < 500 && res.status !== 408;
    throw new GmailError(`Gmail odmietol e-mail (${res.status}).`, res.status, definitive);
  }
  const j = (await res.json()) as { id?: string; threadId?: string };
  if (!j.id || !j.threadId) throw new GmailError('Gmail nevrátil ID správy – nie je isté, či e-mail odišiel.', res.status, false);
  return { id: j.id, threadId: j.threadId };
}

export type ReadRequest = {
  mailboxUserId: string;
  mailbox: string;
  gmailThreadId: string;
  gmailMessageId?: string | null;
  method: ReadMethod;
  format: ReadFormat;
};

/**
 * JEDINÉ čítanie schránky. Databáza najprv povolí čítanie (vlákno CRM, metóda, formát) a zapíše ho do denníka;
 * až potom sa zavolá Gmail. Volá sa bez transakcie (zápis do denníka sa potvrdí hneď).
 */
export async function gmailRead(env: GmailEnv, sql: Sql, r: ReadRequest): Promise<{ status: number; data: unknown }> {
  await sql`SELECT gmail_read_authorize(${r.mailboxUserId}, ${r.gmailThreadId}, ${r.gmailMessageId ?? null}, ${r.method}, ${r.format})`;
  const url = readUrl(r.method, r.mailbox, r.method === 'threads.get' ? r.gmailThreadId : (r.gmailMessageId ?? ''), r.format);
  if (fake(env)) return { status: 200, data: { id: r.gmailThreadId, messages: [] as GmailMessage[] } };
  const token = await accessToken(env, r.mailbox, SCOPE_READ);
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  if (!res.ok) return { status: res.status, data: null };
  return { status: 200, data: await res.json() };
}
