// Modul 5, F7 – provízie (obrazovka 41, karta obchodu, Nastavenia → Provízie obchodníkov; návrh DB časti 37–40).
// Výpočet, práva a pravidlá sú v databáze (0053–0055); tu sa iba volajú funkcie a vykreslí PDF listu.
// Zápisy (uplatnenie, zrušenie listu, preradenie, povolenie zhody) bežia v samostatnej transakcii s opakovaním po deadlocku
// (withRetry, najviac raz). PDF a e-mail až po potvrdení transakcie; ak PDF zlyhá, dokončí ho beh na pozadí (každú minútu).

import { Hono } from 'hono';
import { connect, type Env, type Sql, withRetry } from '../db';
import { claimFooter, claimHtml, type ClaimDocument } from '../render/claim-html';
import { htmlToPdf, sha256Hex } from '../render/pdf';
import { type AppEnv, UUID } from '../types';
import { BadRequest, bool, Forbidden, readBody, str, uuid, uuids } from '../validate';

export const commissions = new Hono<AppEnv>();

const STATUSES = ['caka', 'uplatnena', 'zrusena'] as const;

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}

/** Kľúč PDF v R2: provizie/{spoločnosť}/{rok}/{číslo}[-zrusene].pdf (rok z čísla CMSN-RRRR-NNNN). */
export function claimPdfKey(orgId: string, number: string, kind: 'list' | 'zrusenie'): string {
  return `provizie/${orgId}/${number.slice(5, 9)}/${number}${kind === 'zrusenie' ? '-zrusene' : ''}.pdf`;
}

/**
 * Vykreslí a uloží PDF listu (opakovateľné: ak súbor v R2 už je, nevykresľuje ani neprepisuje – iba ho zapíše k listu) (alebo zrušenia) a zapíše ho k listu – databáza potom zaradí e-mail obchodníkovi a kópii.
 * sql: pripojenie s používateľom (po uplatnení) alebo bez neho (beh na pozadí). Uložený súbor sa nikdy neprepíše.
 */
export async function storeClaimPdf(env: Env, sql: Sql, claimId: string, kind: 'list' | 'zrusenie'): Promise<boolean> {
  const [r] = await sql<{ d: (ClaimDocument & { claim: { org_id: string } }) | null }[]>`SELECT commission_claim_document(${claimId}) AS d`;
  const doc = r?.d;
  if (!doc) return false;
  const key = claimPdfKey(doc.claim.org_id, doc.claim.number, kind);
  const existing = await env.DOCS.head(key);
  let sha = existing?.customMetadata?.sha256;
  if (!existing || !sha) {
    const pdf = await htmlToPdf(env.BROWSER, claimHtml(doc, kind === 'zrusenie'), claimFooter(doc.claim.number));
    sha = await sha256Hex(pdf);
    await env.DOCS.put(key, pdf, { httpMetadata: { contentType: 'application/pdf' }, customMetadata: { claim: claimId, sha256: sha } });
  }
  const [s] = await sql<{ ok: boolean }[]>`SELECT commission_claim_pdf_set(${claimId}, ${kind}, ${key}, ${sha}) AS ok`;
  return !!s?.ok;
}

/** Zápis na samostatnom pripojení s opakovaním; potom PDF (chyba PDF neprekáža – dokončí ho beh na pozadí). */
async function writeThenPdf<T>(env: Env, userId: string, waitUntil: (p: Promise<unknown>) => void,
                              fn: (tx: Sql) => Promise<T>, pdf?: (r: T) => { claimId: string; kind: 'list' | 'zrusenie' } | null): Promise<T> {
  const own = connect(env);
  try {
    const result = await withRetry(own, userId, fn);
    const p = pdf?.(result);
    if (p) {
      try {
        await withRetry(own, userId, (tx) => storeClaimPdf(env, tx, p.claimId, p.kind));
      } catch (e) {
        console.error(`PDF listu: ${(e as Error).name} ${(e as { code?: string }).code ?? ''} – dokončí ho beh na pozadí`);
      }
    }
    return result;
  } finally {
    waitUntil(own.end());
  }
}

// ---------------------------------------------------------------------------------------------------------------
// Obrazovka 41: provízie, súčty, listy
// ---------------------------------------------------------------------------------------------------------------

commissions.get('/commissions', async (c) => {
  const sql = c.var.sql;
  const user = c.req.query('user') || null;
  const status = c.req.query('status') || null;
  const q = (c.req.query('q') ?? '').trim().slice(0, 100) || null;
  if (user && !UUID.test(user)) throw new BadRequest('Neplatný obchodník.');
  if (status && !(STATUSES as readonly string[]).includes(status)) throw new BadRequest('Neplatný stav.');
  const [flags] = await sql<{ sees_all: boolean; is_admin: boolean; scope: string }[]>`
    SELECT crm_commission_sees_all() AS sees_all, crm_is_admin() AS is_admin, crm_scope('provizie', 'view')::text AS scope`;
  const [items, [summary], claims, sellers] = await Promise.all([
    sql`SELECT * FROM commission_list(${user}, ${status}::commission_status, ${q})`,
    sql<{ s: unknown }[]>`SELECT commission_summary(${user}) AS s`,
    sql`
      SELECT k.id, k.number, k.user_id, crm_user_name(k.user_id) AS user_name, k.total_eur, k.created_at,
             crm_user_name(k.created_by) AS created_by_name, k.voided_at, crm_user_name(k.voided_by) AS voided_by_name, k.void_reason,
             k.source, k.pdf_key IS NOT NULL AS has_pdf, k.void_pdf_key IS NOT NULL AS has_void_pdf, k.legacy_pdf_url,
             (SELECT count(*) FROM jsonb_array_elements(k.items_snapshot))::int AS items
        FROM commission_claim k
       WHERE (${user}::uuid IS NULL OR k.user_id = ${user}::uuid)
       ORDER BY k.created_at DESC
       LIMIT 200`,
    flags.sees_all
      ? sql`SELECT u.id, u.name FROM app_user u
             WHERE u.status <> 'deaktivovany' AND (u.seller_type IS NOT NULL OR u.commission_enabled
                   OR EXISTS (SELECT 1 FROM commission c WHERE c.user_id = u.id))
             ORDER BY u.name`
      : Promise.resolve([]),
  ]);
  return c.json({ items, summary: summary.s, claims, sellers, me: { id: c.var.userId, ...flags } });
});

commissions.post('/commissions/claims', async (c) => {
  const b = await readBody(c.req);
  const seller = uuid(b, 'user_id', 'Obchodník')!;
  const ids = uuids(b, 'ids', 'Provízie') ?? [];
  if (ids.length === 0) throw new BadRequest('Vyberte aspoň jednu províziu.');
  const r = await writeThenPdf(c.env, c.var.userId, (p) => c.executionCtx.waitUntil(p),
    async (tx) => {
      const [row] = await tx<{ id: string }[]>`SELECT commission_claim_create(${seller}, string_to_array(${ids.join(',')}, ',')::uuid[]) AS id`;
      const [k] = await tx<{ number: string; total_eur: string }[]>`SELECT number, total_eur FROM commission_claim WHERE id = ${row.id}`;
      return { id: row.id, number: k.number, total_eur: k.total_eur };
    },
    (res) => ({ claimId: res.id, kind: 'list' }));
  return c.json(r);
});

commissions.post('/commissions/claims/:id/void', async (c) => {
  const claimId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod zrušenia', { max: 500 })!;
  await writeThenPdf(c.env, c.var.userId, (p) => c.executionCtx.waitUntil(p),
    async (tx) => {
      await tx`SELECT commission_claim_void(${claimId}, ${reason})`;
      return claimId;
    },
    () => ({ claimId, kind: 'zrusenie' }));
  return c.json({ ok: true });
});

// PDF listu (kind=list) alebo zrušenia (kind=zrusenie) – iba kto list vidí (RLS)
commissions.get('/commissions/claims/:id/pdf', async (c) => {
  const claimId = id(c.req.param('id'));
  const kind = c.req.query('kind') === 'zrusenie' ? 'zrusenie' : 'list';
  const [k] = await c.var.sql<{ number: string; pdf_key: string | null; void_pdf_key: string | null }[]>`
    SELECT number, pdf_key, void_pdf_key FROM commission_claim WHERE id = ${claimId}`;
  if (!k) return c.json({ error: 'Provízny list neexistuje.' }, 404);
  const key = kind === 'zrusenie' ? k.void_pdf_key : k.pdf_key;
  if (!key) return c.json({ error: 'PDF sa ešte pripravuje – skúste to o minútu.' }, 409);
  const obj = await c.env.DOCS.get(key);
  if (!obj) return c.json({ error: 'PDF sa nenašlo.' }, 404);
  return new Response(obj.body, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `inline; filename="${k.number}${kind === 'zrusenie' ? '-zrusene' : ''}.pdf"`,
      'Cache-Control': 'no-store',
    },
  });
});

// ---------------------------------------------------------------------------------------------------------------
// Obchod: provízia na karte (iba vlastník provízie a kto vidí všetky – RLS), preradenie, povolenie zhody
// ---------------------------------------------------------------------------------------------------------------

commissions.get('/deals/:id/commission', async (c) => {
  const dealId = id(c.req.param('id'));
  const items = await c.var.sql`
    SELECT c.id, c.user_id, crm_user_name(c.user_id) AS user_name, c.kind, c.status::text, c.won_at, c.duration_years, c.volume_mwh,
           c.base_eur, c.base_missing, c.pct, c.target_eur, c.amount_eur, c.claim_id, k.number AS claim_number, k.created_at AS claimed_at,
           c.reassigned_at, crm_user_name(c.reassigned_from) AS reassigned_from_name, c.reassign_reason, c.created_at
      FROM commission c LEFT JOIN commission_claim k ON k.id = c.claim_id
     WHERE c.deal_id = ${dealId}
     ORDER BY c.created_at`;
  const [f] = await c.var.sql<{ is_admin: boolean; legacy: boolean }[]>`
    SELECT crm_is_admin() AS is_admin,
           crm_is_admin() AND EXISTS (SELECT 1 FROM notification n WHERE n.kind = 'provizia_duplicita' AND n.deal_id = ${dealId})
             AND NOT EXISTS (SELECT 1 FROM commission_legacy_override o WHERE o.deal_id = ${dealId}) AS legacy`;
  return c.json({ items, is_admin: f.is_admin, legacy_blocked: f.legacy });
});

commissions.post('/deals/:id/commission/reassign', async (c) => {
  const dealId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const to = uuid(b, 'user_id', 'Nový obchodník')!;
  const reason = str(b, 'reason', 'Dôvod preradenia', { max: 500 })!;
  await writeThenPdf(c.env, c.var.userId, (p) => c.executionCtx.waitUntil(p), (tx) => tx`SELECT commission_reassign(${dealId}, ${to}, ${reason})`);
  return c.json({ ok: true });
});

commissions.post('/deals/:id/commission/allow', async (c) => {
  const dealId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 500 })!;
  await writeThenPdf(c.env, c.var.userId, (p) => c.executionCtx.waitUntil(p), (tx) => tx`SELECT commission_legacy_allow(${dealId}, ${reason})`);
  return c.json({ ok: true });
});

// ---------------------------------------------------------------------------------------------------------------
// Nastavenia → Provízie obchodníkov (admin; schvaľovateľ cien mení „počítať provízie“ a percento)
// ---------------------------------------------------------------------------------------------------------------

async function settingsAccess(sql: Sql): Promise<{ is_admin: boolean; approves: boolean }> {
  const [r] = await sql<{ is_admin: boolean; approves: boolean }[]>`SELECT crm_is_admin() AS is_admin, crm_approves_prices() AS approves`;
  if (!r.is_admin && !r.approves) throw new Forbidden('Nastavenia provízií vidí admin a schvaľovateľ cien.');
  return r;
}

commissions.get('/settings/commissions', async (c) => {
  const sql = c.var.sql;
  const access = await settingsAccess(sql);
  const [s] = await sql<{ crm_from: string | null; cc: string[] }[]>`
    SELECT (SELECT value #>> '{}' FROM app_setting WHERE key = 'commission_crm_from') AS crm_from,
           coalesce((SELECT value FROM app_setting WHERE key = 'commission_claim_cc'), '[]'::jsonb) AS cc`;
  const users = await sql`
    SELECT u.id, u.name, u.email, t.name AS team_name, u.seller_type, u.status::text, u.commission_enabled, u.sees_all_commissions,
           user_commission_pct(u.id) AS pct
      FROM app_user u JOIN team t ON t.id = u.team_id
     WHERE u.status <> 'deaktivovany'
     ORDER BY (u.seller_type IS NULL AND NOT u.commission_enabled), u.name`;
  return c.json({ crm_from: s.crm_from, cc: s.cc, users, can_edit: access.is_admin, approves: access.approves });
});

commissions.put('/settings/commissions', async (c) => {
  const b = await readBody(c.req);
  const from = b.crm_from;
  if (from !== null && (typeof from !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(from))) throw new BadRequest('Dátum prechodu: RRRR-MM-DD alebo prázdny.');
  const cc = uuids(b, 'cc', 'Príjemcovia kópie') ?? [];
  await c.var.sql`SELECT commission_settings_set(${from as string | null}::date, string_to_array(${cc.join(',')}, ',')::uuid[])`;
  return c.json({ ok: true });
});

commissions.patch('/settings/commissions/users/:id', async (c) => {
  const userId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const enabled = bool(b, 'commission_enabled', 'Počítať provízie');
  const all = bool(b, 'sees_all_commissions', 'Vidí všetky provízie');
  const sql = c.var.sql;
  await settingsAccess(sql);
  if (enabled !== undefined) await sql`SELECT user_commission_enabled_set(${userId}, ${enabled})`;
  if (all !== undefined) {
    const rows = await sql`UPDATE app_user SET sees_all_commissions = ${all} WHERE id = ${userId} RETURNING id`;
    if (rows.length === 0) throw new Forbidden('„Vidí všetky provízie“ mení iba admin.');
  }
  return c.json({ ok: true });
});

// ---------------------------------------------------------------------------------------------------------------
// Beh na pozadí (Cron každú minútu): fronta prepočtov a nevykreslené PDF listov
// ---------------------------------------------------------------------------------------------------------------

export async function commissionMinute(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const q = await withRetry(sql, null, async (tx) => {
      await tx`SET LOCAL statement_timeout = '120s'`;
      const [r] = await tx<{ r: { fronta_spracovane: number; fronta_preskocene: number; fronta_stara: number } }[]>`SELECT commission_queue_run() AS r`;
      return r.r;
    });
    const [p] = await sql<{ p: { id: string; kind: 'list' | 'zrusenie' }[] }[]>`SELECT commission_claim_pdf_pending(5) AS p`;
    let pdfs = 0;
    for (const item of p.p) {
      try {
        if (await withRetry(sql, null, (tx) => storeClaimPdf(env, tx, item.id, item.kind))) pdfs++;
      } catch (e) {
        console.error(`PDF listu na pozadí: ${(e as Error).name} ${(e as { code?: string }).code ?? ''}`);
      }
    }
    if (q.fronta_spracovane || q.fronta_preskocene || q.fronta_stara || pdfs) {
      console.log(`Provízie: fronta ${q.fronta_spracovane}, preskočené ${q.fronta_preskocene}, stará ${q.fronta_stara}, PDF ${pdfs}`);
    }
  } catch (err) {
    console.error(`Provízie (minúta): ${(err as Error).name} ${(err as { code?: string }).code ?? 'unknown'}`);
  } finally {
    await sql.end();
  }
}
