// Modul 5, F4 – beh na pozadí e-mailov (Cron každú minútu, wrangler.toml; okamžité odoslanie emailKick). Beží bez prihláseného používateľa ako crm_app;
// volá iba funkcie databázy pre beh na pozadí (crm_background_only). Poradie:
//   1. dokončenie nedokončených odoslaní podľa ID z Gmailu, neisté bez ID → Chyba (email_pending_recover),
//   2. fronta e-mailov zákazníkom (potvrdenie akceptácie) – email_queue_claim → deliver,
//   3. interné e-maily z crm@greenlogy.com (schválenia, akceptácia) – email_outbox_claim,
//   4. odpovede: sledované vlákna (aktivita za 30 dní) → threads.get (full) → iba text a hlavičky → email_message_received.
// Do logu idú iba počty a kódy chýb, nikdy adresy, predmety ani texty.

import { connect, type Env, type Sql } from './db';
import { deliver, CRM_MAILBOX, type Payload, type Runner } from './gmail/deliver';
import { GmailError, gmailConfigured, gmailRead, gmailSend } from './gmail/gmail';
import { buildMime, type GmailMessage, parseGmailMessage } from './gmail/mime';

type OutboxItem = { id: string; send_key: string; kind: string; to: string; name: string; deal_id: string | null; approval_id: string | null; detail: string | null;
  commission_claim_id?: string | null; pdf_key?: string | null };
type WatchItem = { thread_id: string; mailbox_user_id: string; mailbox: string; gmail_thread_id: string; known: string[] };

/** Text interného e-mailu (bez osobných údajov zákazníkov – iba detail upozornenia a odkaz do CRM). */
export function outboxMessage(o: OutboxItem, crmUrl: string): { subject: string; text: string } {
  const base = crmUrl.replace(/\/+$/, '');
  const link = o.kind === 'schvalenie_nove' || o.kind === 'schvalenie_rozhodnutie' ? `${base}/schvalovanie`
    : o.kind === 'provizny_list' || o.kind === 'provizny_list_zruseny' ? `${base}/provizie`
    : o.deal_id ? `${base}/obchody/${o.deal_id}` : `${base}/upozornenia`;
  const subject = o.kind === 'schvalenie_nove' ? 'CRM: nová žiadosť o schválenie'
    : o.kind === 'schvalenie_rozhodnutie' ? 'CRM: rozhodnutie o vašej žiadosti'
    : o.kind === 'pomoc_s_ponukou' ? 'CRM: žiadosť o pomoc s ponukou'
    // F7: provízny list s PDF v prílohe (detail = číslo listu)
    : o.kind === 'provizny_list' ? `CRM: provízny list ${o.detail ?? ''}`.trim()
    : o.kind === 'provizny_list_zruseny' ? `CRM: zrušený provízny list ${o.detail ?? ''}`.trim()
    : 'CRM: zákazník prijal ponuku';
  if (o.kind === 'provizny_list' || o.kind === 'provizny_list_zruseny') {
    const text = [
      'Dobrý deň,', '',
      o.kind === 'provizny_list'
        ? `v prílohe je provízny list ${o.detail ?? ''}.`
        : `provízny list ${o.detail ?? ''} bol zrušený – provízie sa vrátili na „Čaká na uplatnenie“. V prílohe je list s pečiatkou ZRUŠENÉ.`,
      '', `Provízie v CRM: ${link}`, '', 'Greenlogy CRM (automatická správa, neodpovedajte na ňu)',
    ].join('\n');
    return { subject, text };
  }
  const text = [
    'Dobrý deň,',
    '',
    `${subject.replace(/^CRM: /, '').replace(/^./, (c) => c.toUpperCase())}${o.detail ? ` – ${o.detail}` : ''}.`,
    '',
    `Otvoriť v CRM: ${link}`,
    '',
    'Greenlogy CRM (automatická správa, neodpovedajte na ňu)',
  ].join('\n');
  return { subject, text };
}

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

async function sendOutbox(env: Env, sql: Sql, o: OutboxItem): Promise<'ok' | 'chyba'> {
  const { subject, text } = outboxMessage(o, env.CRM_URL);
  try {
    // F7: PDF provízneho listu z R2 ako príloha
    let attachments: { filename: string; mime: string; data: Uint8Array }[] | undefined;
    if (o.pdf_key) {
      const obj = await env.DOCS.get(o.pdf_key);
      if (!obj) throw new Error('PDF listu sa nenašlo v úložisku.');
      attachments = [{ filename: o.pdf_key.split('/').pop()!, mime: 'application/pdf', data: new Uint8Array(await obj.arrayBuffer()) }];
    }
    const mime = buildMime({
      from: CRM_MAILBOX, fromName: 'Greenlogy CRM', to: [o.to], subject, text,
      html: `<div style="font-family:Arial,sans-serif;font-size:14px">${esc(text).replace(/\n/g, '<br>')}</div>`,
      messageId: `<crm-oznam-${o.id}@greenlogy.com>`,
      attachments,
    });
    const r = await gmailSend(env, CRM_MAILBOX, mime, [o.to], null);
    await sql`SELECT email_outbox_result(${o.id}, ${o.send_key}, ${r.id}, NULL)`;
    return 'ok';
  } catch (e) {
    if (e instanceof GmailError && !e.definitive) return 'chyba';   // neisté: po 15 min Chyba, znova sa neodošle
    await sql`SELECT email_outbox_result(${o.id}, ${o.send_key}, NULL, ${e instanceof Error ? e.message : 'chyba'})`;
    return 'chyba';
  }
}

async function checkThread(env: Env, sql: Sql, w: WatchItem): Promise<number> {
  let res: { status: number; data: unknown };
  try {
    res = await gmailRead(env, sql, {
      mailboxUserId: w.mailbox_user_id, mailbox: w.mailbox, gmailThreadId: w.gmail_thread_id, method: 'threads.get', format: 'full',
    });
  } catch (e) {
    await sql`SELECT email_thread_checked(${w.thread_id}, 'chyba', ${e instanceof Error ? e.message.slice(0, 200) : 'chyba'})`;
    return 0;
  }
  if (res.status === 404) {
    await sql`SELECT email_thread_checked(${w.thread_id}, 'nenajdene', NULL)`;
    return 0;
  }
  if (res.status !== 200) {
    await sql`SELECT email_thread_checked(${w.thread_id}, 'chyba', ${`Gmail ${res.status}`})`;
    return 0;
  }
  const messages = ((res.data as { messages?: GmailMessage[] }).messages ?? []).filter((m) => !w.known.includes(m.id));
  let n = 0;
  for (const m of messages) {
    // obsah príloh sa zahodí hneď tu – ukladá sa iba text a hlavičky vlákna
    const p = parseGmailMessage(m, w.mailbox, env.PUBLIC_OFFER_URL);
    await sql`SELECT email_message_received(${w.thread_id}, ${sql.json(p)})`;
    n++;
  }
  await sql`SELECT email_thread_checked(${w.thread_id}, 'ok', NULL)`;
  return n;
}

/**
 * Okamžité odoslanie (Peter 16. 10.): fronta zákazníkom a interné e-maily z crm@ hneď po zápise, ktorý ich vytvoril
 * (každý úspešný zápis v CRM, akceptácia na stránke ponuky cez interné prepojenie Workerov). Bez kontroly odpovedí.
 * Prevzatie s jednorazovým kľúčom (SKIP LOCKED) – súbežný beh ani Cron nič neodošle dvakrát.
 */
export async function emailKick(env: Env): Promise<void> {
  if (!gmailConfigured(env)) return;
  const sql = connect(env);
  const run: Runner = (fn) => sql.begin((tx) => fn(tx as unknown as Sql)) as never;
  try {
    const [q] = await sql<{ q: Payload[] }[]>`SELECT email_queue_claim(10) AS q`;
    for (const p of q.q) await deliver(env, run, p, null);
    const [ob] = await sql<{ q: OutboxItem[] }[]>`SELECT email_outbox_claim(20) AS q`;
    for (const o of ob.q) await sendOutbox(env, sql, o);
    if (q.q.length || ob.q.length) console.log(`E-maily hneď: fronta ${q.q.length}, interné ${ob.q.length}`);
  } catch (err) {
    console.error(`E-maily hneď: ${(err as Error).name} ${(err as { code?: string }).code ?? 'unknown'}`);
  } finally {
    await sql.end();
  }
}

export async function emailRun(env: Env): Promise<void> {
  if (!gmailConfigured(env)) {
    console.log('E-maily: Gmail nie je nastavený, preskočené');
    return;
  }
  const sql = connect(env);
  const run: Runner = (fn) => sql.begin((tx) => fn(tx as unknown as Sql)) as never;
  const count = { dokoncene: 0, neiste: 0, fronta: 0, interne: 0, odpovede: 0, chyby: 0 };
  try {
    const [rec] = await sql<{ r: { dokoncene: number; neiste: number } }[]>`SELECT email_pending_recover() AS r`;
    count.dokoncene = rec.r.dokoncene;
    count.neiste = rec.r.neiste;

    const [q] = await sql<{ q: Payload[] }[]>`SELECT email_queue_claim(10) AS q`;
    for (const p of q.q) {
      const r = await deliver(env, run, p, null);
      if (r.state === 'odoslany' || r.state === 'dokonci_sa') count.fronta++;
      else count.chyby++;
    }

    const [ob] = await sql<{ q: OutboxItem[] }[]>`SELECT email_outbox_claim(20) AS q`;
    for (const o of ob.q) {
      if ((await sendOutbox(env, sql, o)) === 'ok') count.interne++;
      else count.chyby++;
    }

    const [w] = await sql<{ w: WatchItem[] }[]>`SELECT email_watch_threads(50) AS w`;
    for (const t of w.w) {
      try {
        count.odpovede += await checkThread(env, sql, t);
      } catch (e) {
        count.chyby++;
        console.error(`E-maily: vlákno sa nespracovalo: ${(e as { code?: string }).code ?? (e as Error).name}`);
      }
    }
    console.log(`E-maily: dokončené ${count.dokoncene}, neisté ${count.neiste}, fronta ${count.fronta}, interné ${count.interne}, odpovede ${count.odpovede}, chyby ${count.chyby}`);
  } catch (err) {
    console.error(`E-maily: beh zlyhal: ${(err as Error).name} ${(err as { code?: string }).code ?? 'unknown'}`);
    throw err;
  } finally {
    await sql.end();
  }
}
