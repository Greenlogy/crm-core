// Modul 5, F4 – doručenie pripraveného e-mailu (payload z email_send_prepare alebo email_queue_claim, 0042).
// Každý krok databázy je samostatná potvrdená transakcia (odpoveď 8):
//   odosiela sa (už zapísané) → Gmail → email_send_recorded (ID hneď) → email_send_complete.
// Ak po odoslaní zlyhá zápis, dokončí ho beh na pozadí (email_pending_recover) podľa ID – nikdy sa neodošle znova.
// Gmail e-mail odmietol (určite neodišiel) → email_send_failed. Nie je isté (sieť, 5xx) → nič; po 15 min Chyba.

import type { Env, Sql } from '../db';
import { GmailError, gmailSend } from './gmail';
import { buildMime, type MimeAttachment, renderBody, type Signature } from './mime';

export const CRM_MAILBOX = 'crm@greenlogy.com';

export type Payload = {
  id: string;
  status: string;
  kind: string;
  send_key: string;
  offer_id: string | null;
  mailbox_user_id: string | null;
  mailbox: string;
  from: string | null;
  from_name: string;
  signature_user_id: string | null;
  reply_to: string | null;
  to: string[];
  cc: string[];
  subject: string;
  body: string;
  gmail_thread_id: string | null;
  references: string[];
  attachments: { kind: string; key: string; sha256?: string }[];
  fresh?: boolean;
};

/** Spustí fn v novej, hneď potvrdenej transakcii (ako používateľ alebo bez neho – beh na pozadí). */
export type Runner = <T>(fn: (sql: Sql) => Promise<T>) => Promise<T>;

export type DeliverResult =
  | { state: 'odoslany'; offer_error: string | null }
  | { state: 'dokonci_sa' }            // odišiel, zápis dokončí beh na pozadí
  | { state: 'odmietnuty'; error: string }
  | { state: 'neiste'; error: string };

const hex = (b: ArrayBuffer) => [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, '0')).join('');

async function attachmentFiles(env: Env, p: Payload): Promise<MimeAttachment[]> {
  const out: MimeAttachment[] = [];
  for (const a of p.attachments) {
    const obj = await env.DOCS.get(a.key);
    if (!obj) throw new GmailError('Príloha sa v úložisku nenašla.', 0, true);
    const data = new Uint8Array(await obj.arrayBuffer());
    if (a.sha256 && hex(await crypto.subtle.digest('SHA-256', data)) !== a.sha256) {
      throw new GmailError('Príloha nezodpovedá uloženému odtlačku.', 0, true);
    }
    const base = a.key.split('/').pop()!.replace(/-[0-9a-f]{8}\.pdf$/, '.pdf');
    out.push({ filename: a.kind === 'potvrdenie' ? `Potvrdenie-prijatia-${base}` : `Cenova-ponuka-${base}`, mime: 'application/pdf', data });
  }
  return out;
}

export async function deliver(env: Env, run: Runner, p: Payload, link: string | null): Promise<DeliverResult> {
  let sent: { id: string; threadId: string };
  const messageId = `<crm-${p.id}-${crypto.randomUUID().slice(0, 8)}@greenlogy.com>`;
  try {
    const { sig, photo } = await run(async (sql) => {
      const [s] = p.signature_user_id
        ? await sql<{ s: Signature | null }[]>`SELECT email_signature(${p.signature_user_id}) AS s`
        : [{ s: null }];
      const ph = s?.s?.has_photo
        ? (await sql<{ mime: string; data: Uint8Array }[]>`SELECT mime, data FROM user_photo_get(${p.signature_user_id})`)[0]
        : undefined;
      return { sig: s?.s ?? null, photo: ph };
    });
    const photoCid = photo ? `podpis-${p.id}@greenlogy.com` : null;
    const { text, html } = renderBody(p.body, link, sig, photoCid);
    const files = await attachmentFiles(env, p);
    const mailbox = p.mailbox_user_id ? p.mailbox : CRM_MAILBOX;
    const mime = buildMime({
      from: p.from ?? mailbox,
      fromName: p.mailbox_user_id ? p.from_name : sig ? `${sig.name} | Greenlogy` : 'Greenlogy',
      to: p.to,
      cc: p.cc,
      replyTo: p.reply_to,
      subject: p.subject,
      text,
      html,
      messageId,
      inReplyTo: p.references.at(-1) ?? null,
      references: p.references,
      inline: photo ? [{ filename: 'podpis.' + (photo.mime === 'image/png' ? 'png' : 'jpg'), mime: photo.mime, data: new Uint8Array(photo.data), cid: photoCid! }] : [],
      attachments: files,
    });
    sent = await gmailSend(env, mailbox, mime, [...p.to, ...p.cc], p.gmail_thread_id);
  } catch (e) {
    const err = e instanceof GmailError ? e : new GmailError(e instanceof Error ? e.message : 'Chyba', 0, true);
    if (!err.definitive) return { state: 'neiste', error: err.message };
    await run((sql) => sql`SELECT email_send_failed(${p.id}, ${p.send_key}, ${err.message})`);
    return { state: 'odmietnuty', error: err.message };
  }
  try {
    await run((sql) => sql`SELECT email_send_recorded(${p.id}, ${p.send_key}, ${sent.id}, ${sent.threadId}, ${messageId}, ${new Date().toISOString()})`);
    const [r] = await run((sql) => sql<{ r: { offer_error: string | null } }[]>`SELECT email_send_complete(${p.id}) AS r`);
    return { state: 'odoslany', offer_error: r.r.offer_error };
  } catch (e) {
    console.error(`E-mail odišiel, zápis sa dokončí na pozadí: ${(e as { code?: string }).code ?? 'unknown'}`);
    return { state: 'dokonci_sa' };
  }
}
