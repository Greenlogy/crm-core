// Modul 5, F3 – PDF ponuky, odoslanie s odkazom, akceptácia, šablóny ponúk (obrazovky 34, 35, 42; návrh DB časti
// 1.7, 1.10, 4, 5, 23–25; migrácie 0039, 0040). Dokument ponuky skladá databáza (offer_document); tu sa iba vykreslí
// do PDF (Browser Run), uloží do R2 (jurisdikcia EÚ) a zavolajú funkcie databázy, ktoré strážia stav a práva.
// Odkaz na stránku ponuky sa ukáže iba raz – v databáze je iba jeho odtlačok (SHA-256).

import { Hono } from 'hono';
import type { Sql } from '../db';
import { bundledAssets, offerAssets } from '../render/assets';
import { confirmationHtml, offerHtml, type OfferDocument, pdfFooter } from '../render/offer-html';
import { htmlToPdf, sha256Hex } from '../render/pdf';
import { type AppEnv, UUID } from '../types';
import { BadRequest, type Body, oneOf, readBody, str } from '../validate';

export const offersPdf = new Hono<AppEnv>();

const CHANNELS = ['email_mimo_crm', 'osobne', 'ine'] as const;
const MANUAL_CHANNELS = ['telefon', 'email', 'osobne', 'podpisane_pdf'] as const;
const ASSET_CODES = ['titulna', 'referencie_zakaznici', 'referencie_partneri', 'energeticky_mix'] as const;
const MAX_SIGNED = 10 * 1024 * 1024;

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}
function instant(b: Body, key: string, label: string): string {
  const v = b[key];
  if (typeof v !== 'string' || Number.isNaN(Date.parse(v))) throw new BadRequest(`${label}: neplatný čas.`);
  return new Date(v).toISOString();
}
const pdfResponse = (pdf: Uint8Array | ReadableStream, name: string, inline = true) =>
  new Response(pdf, {
    headers: {
      'Content-Type': 'application/pdf',
      'Content-Disposition': `${inline ? 'inline' : 'attachment'}; filename="${name}"`,
      'Cache-Control': 'no-store',
    },
  });
const fileName = (displayNumber: string, suffix = '') => `Cenova-ponuka-${displayNumber.replace('/', '-')}${suffix}.pdf`;

/** Token odkazu: 32 náhodných bajtov ako base64url (43 znakov); do databázy ide iba SHA-256 reťazca tokenu. */
function newToken(): string {
  const b = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...b)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function offerRow(sql: Sql, offerId: string) {
  const [o] = await sql<{ id: string; org_id: string; number: string; version: number; display_number: string; status: string; pdf_key: string | null; deal_id: string }[]>`
    SELECT o.id, o.org_id, o.number, o.version, offer_display_number(o) AS display_number, o.status::text, o.pdf_key, o.deal_id
      FROM offer o WHERE o.id = ${offerId}`;
  if (!o) throw new BadRequest('Ponuka neexistuje alebo ju nevidíte.');
  return o;
}
async function documentOf(sql: Sql, offerId: string): Promise<OfferDocument> {
  const [r] = await sql<{ d: OfferDocument | null }[]>`SELECT offer_document(${offerId}) AS d`;
  if (!r?.d) throw new BadRequest('Ponuka neexistuje alebo ju nevidíte.');
  return r.d;
}
const yearOf = (number: string) => `20${number.slice(1, 3)}`;
const versionSuffix = (version: number) => (version > 1 ? `-${version}` : '');

// Dokument ponuky (pre editor – náhľad textov a hodnôt)
offersPdf.get('/offers/:id/document', async (c) => c.json(await documentOf(c.var.sql, id(c.req.param('id')))));

// Náhľad PDF (neukladá sa): pred odoslaním s vodotlačou NÁHĽAD, pri návrhu šablóny NÁVRH ŠABLÓNY
offersPdf.get('/offers/:id/preview.pdf', async (c) => {
  const offerId = id(c.req.param('id'));
  const sql = c.var.sql;
  const o = await offerRow(sql, offerId);
  const doc = await documentOf(sql, offerId);
  if (!doc.template) throw new BadRequest('Pre druh a jazyk ponuky nie je šablóna.');
  const html = offerHtml(doc, await offerAssets(sql, o.org_id), {
    watermark: doc.template.status === 'navrh' ? 'draft' : ['koncept', 'caka_na_schvalenie', 'pripravena'].includes(o.status) ? 'preview' : null,
  });
  return pdfResponse(await htmlToPdf(c.env.BROWSER, html, pdfFooter(doc)), fileName(o.display_number, '-nahlad'));
});

// Odoslanie (ručne, mimo CRM): v jednej transakcii stav Odoslaná + platnosť, PDF do R2, odkaz (zobrazí sa iba raz)
offersPdf.post('/offers/:id/send', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const channel = oneOf(b, 'channel', 'Spôsob odoslania', CHANNELS);
  if (!channel) throw new BadRequest('Vyberte, ako bola ponuka odoslaná.');
  const at = instant(b, 'sent_at', 'Čas odoslania');
  const note = str(b, 'note', 'Poznámka', { max: 1000, optional: true }) || null;
  const sql = c.var.sql;
  const [r] = await sql<{ until: string }[]>`SELECT offer_mark_sent(${offerId}, ${at}, ${channel}, ${note}) AS until`;
  const o = await offerRow(sql, offerId);
  const doc = await documentOf(sql, offerId);
  if (!doc.template || doc.template.status !== 'platna') {
    throw new BadRequest(`Šablóna ponuky (${doc.offer.kind}, ${doc.offer.language.toUpperCase()}) ešte nie je schválená – admin ju zverejní v Nastaveniach → Šablóny ponúk.`);
  }
  const pdf = await htmlToPdf(c.env.BROWSER, offerHtml(doc, await offerAssets(sql, o.org_id)), pdfFooter(doc));
  const sha = await sha256Hex(pdf);
  const key = `ponuky/${o.org_id}/${yearOf(o.number)}/${o.number}${versionSuffix(o.version)}.pdf`;
  await c.env.DOCS.put(key, pdf, { httpMetadata: { contentType: 'application/pdf' }, customMetadata: { offer: o.id, sha256: sha } });
  await sql`SELECT offer_attach_pdf(${offerId}, ${key}, ${sha})`;
  const token = newToken();
  await sql`SELECT offer_link_set(${offerId}, ${await sha256Hex(token)})`;
  return c.json({ valid_until: r.until, link: `${c.env.PUBLIC_OFFER_URL}/p/${token}` });
});

// Nový odkaz (vlastník obchodu alebo admin – databáza); starý prestane platiť
offersPdf.post('/offers/:id/link', async (c) => {
  const offerId = id(c.req.param('id'));
  const token = newToken();
  await c.var.sql`SELECT offer_link_set(${offerId}, ${await sha256Hex(token)})`;
  return c.json({ link: `${c.env.PUBLIC_OFFER_URL}/p/${token}` });
});

// Uložené PDF odoslanej ponuky
offersPdf.get('/offers/:id/pdf', async (c) => {
  const o = await offerRow(c.var.sql, id(c.req.param('id')));
  if (!o.pdf_key) return c.json({ error: 'Ponuka nemá uložené PDF (odoslaná pred F3 alebo ešte neodoslaná).' }, 404);
  const obj = await c.env.DOCS.get(o.pdf_key);
  if (!obj) return c.json({ error: 'PDF sa v úložisku nenašlo.' }, 404);
  return pdfResponse(obj.body, fileName(o.display_number), c.req.query('download') !== '1');
});

// Akceptácie ponuky (aj zrušené) a otvorenia stránky
offersPdf.get('/offers/:id/acceptance', async (c) => {
  const offerId = id(c.req.param('id'));
  const sql = c.var.sql;
  const [items, stat] = await Promise.all([
    sql`SELECT a.id, a.variant_id, chr(64 + v.sort_order) || ' · ' || v.name AS variant, a.method, a.channel, a.accepted_at,
               a.signer_name, a.signer_function, host(a.ip) AS ip, a.terms_sha256, a.signed_file_key IS NOT NULL AS has_signed, a.confirmation_pdf_key IS NOT NULL AS has_confirmation,
               a.note, ru.name AS recorded_by_name, a.revoked_at, vu.name AS revoked_by_name, a.revoke_reason,
               crm_is_admin() AND a.revoked_at IS NULL AS can_revoke
          FROM offer_acceptance a JOIN offer_variant v ON v.id = a.variant_id
          LEFT JOIN app_user ru ON ru.id = a.recorded_by LEFT JOIN app_user vu ON vu.id = a.revoked_by
         WHERE a.offer_id = ${offerId} ORDER BY a.created_at DESC`,
    sql`SELECT first_opened_at, last_opened_at, open_count FROM offer_page_stat WHERE offer_id = ${offerId}`,
  ]);
  return c.json({ items, page: stat[0] ?? null });
});

// Ručná akceptácia (odpoveď F3 5): variant, meno, funkcia, čas, kanál; podpísané PDF voliteľne (base64, do 10 MB)
offersPdf.post('/offers/:id/accept-manual', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const variant = id(String(b.variant_id ?? ''));
  const name = str(b, 'signer_name', 'Meno', { max: 200 })!;
  const func = str(b, 'signer_function', 'Funkcia', { max: 200 })!;
  const at = instant(b, 'accepted_at', 'Čas akceptácie');
  const channel = oneOf(b, 'channel', 'Kanál', MANUAL_CHANNELS);
  if (!channel) throw new BadRequest('Vyberte, ako zákazník ponuku prijal.');
  const note = str(b, 'note', 'Poznámka', { max: 2000, optional: true }) || null;
  const sql = c.var.sql;
  const o = await offerRow(sql, offerId);
  let key: string | null = null;
  if (typeof b.file_base64 === 'string' && b.file_base64.length > 0) {
    const bin = Uint8Array.from(atob(b.file_base64), (ch) => ch.charCodeAt(0));
    if (bin.length > MAX_SIGNED) throw new BadRequest('Podpísaná ponuka môže mať najviac 10 MB.');
    if (String.fromCharCode(...bin.subarray(0, 5)) !== '%PDF-') throw new BadRequest('Podpísaná ponuka musí byť PDF.');
    const rand = [...crypto.getRandomValues(new Uint8Array(4))].map((x) => x.toString(16).padStart(2, '0')).join('');
    key = `podpisane/${o.org_id}/${yearOf(o.number)}/${o.number}${versionSuffix(o.version)}-${rand}.pdf`;
    await c.env.DOCS.put(key, bin, { httpMetadata: { contentType: 'application/pdf' }, customMetadata: { offer: o.id, sha256: await sha256Hex(bin) } });
  }
  const [r] = await sql<{ id: string }[]>`
    SELECT offer_accept_manual(${offerId}, ${variant}, ${name}, ${func}, ${at}, ${channel}, ${note}, ${key}) AS id`;
  // potvrdenie akceptácie v PDF sa uloží hneď (dôkaz, nemení sa) – v tej istej transakcii (0041)
  await storeConfirmation(sql, c.env, r.id);
  return c.json({ id: r.id }, 201);
});

type ConfirmationData = {
  acceptance_id: string; accepted_at: string; variant: string; method: string; channel: string | null; signer_name: string;
  signer_function: string; ip: string | null; terms_text: string; terms_sha256: string; confirmation_key: string; document: OfferDocument;
};
async function storeConfirmation(sql: Sql, env: AppEnv['Bindings'], acceptanceId: string): Promise<void> {
  const [row] = await sql<{ d: ConfirmationData | null }[]>`SELECT offer_acceptance_for_confirmation(${acceptanceId}) AS d`;
  if (!row?.d) throw new BadRequest('Akceptácia neexistuje.');
  const d = row.d;
  const pdf = await htmlToPdf(env.BROWSER, confirmationHtml(d.document, d, d.variant, d.terms_text), pdfFooter(d.document));
  const sha = await sha256Hex(pdf);
  await env.DOCS.put(d.confirmation_key, pdf, { httpMetadata: { contentType: 'application/pdf' }, customMetadata: { acceptance: acceptanceId, sha256: sha } });
  await sql`SELECT offer_acceptance_confirmation_set(${acceptanceId}, ${d.confirmation_key}, ${sha})`;
}

// Podpísané PDF z ručnej akceptácie
offersPdf.get('/offer-acceptances/:id/signed.pdf', async (c) => {
  const [a] = await c.var.sql<{ key: string | null; display_number: string }[]>`
    SELECT a.signed_file_key AS key, offer_display_number(o) AS display_number
      FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id WHERE a.id = ${id(c.req.param('id'))}`;
  if (!a?.key) return c.json({ error: 'Podpísané PDF nie je.' }, 404);
  const obj = await c.env.DOCS.get(a.key);
  if (!obj) return c.json({ error: 'PDF sa v úložisku nenašlo.' }, 404);
  return pdfResponse(obj.body, fileName(a.display_number, '-podpisana'));
});

// Potvrdenie akceptácie: uložený súbor z momentu akceptácie (0041) – nevykresľuje sa znova
offersPdf.get('/offer-acceptances/:id/confirmation.pdf', async (c) => {
  const [a] = await c.var.sql<{ key: string | null; display_number: string }[]>`
    SELECT a.confirmation_pdf_key AS key, offer_display_number(o) AS display_number
      FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id WHERE a.id = ${id(c.req.param('id'))}`;
  if (!a) return c.json({ error: 'Akceptácia neexistuje alebo ju nevidíte.' }, 404);
  if (!a.key) return c.json({ error: 'Potvrdenie tejto akceptácie nebolo uložené (akceptácia pred zavedením ukladania).' }, 404);
  const obj = await c.env.DOCS.get(a.key);
  if (!obj) return c.json({ error: 'Potvrdenie sa v úložisku nenašlo.' }, 404);
  return pdfResponse(obj.body, fileName(a.display_number, '-potvrdenie'));
});

offersPdf.post('/offer-acceptances/:id/revoke', async (c) => {
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 2000 })!;
  await c.var.sql`SELECT offer_acceptance_revoke(${id(c.req.param('id'))}, ${reason})`;
  return c.json({ ok: true });
});

offersPdf.post('/offers/:id/unblock', async (c) => {
  await c.var.sql`SELECT offer_unblock(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// ---------------------------------------------------------------------------------------------------------------
// Šablóny ponúk (obrazovka 42): číta každý prihlásený, mení admin (RLS a spúšťač); platná sa nemení – nová verzia
// ---------------------------------------------------------------------------------------------------------------

offersPdf.get('/offer-templates', async (c) => {
  const items = await c.var.sql`
    SELECT t.id, t.kind, t.language, t.version, t.status, t.note, t.created_at, t.updated_at, t.published_at,
           cu.name AS created_by_name, pu.name AS published_by_name, t.defaults
      FROM offer_template_version t
      LEFT JOIN app_user cu ON cu.id = t.created_by LEFT JOIN app_user pu ON pu.id = t.published_by
     WHERE t.org_id = crm_default_org()
     ORDER BY t.kind, t.language, t.version DESC`;
  const [me] = await c.var.sql<{ admin: boolean }[]>`SELECT crm_is_admin() AS admin`;
  return c.json({ items, can_edit: me?.admin ?? false });
});

offersPdf.get('/offer-templates/:id', async (c) => {
  const [t] = await c.var.sql`
    SELECT t.id, t.kind, t.language, t.version, t.status, t.sections, t.defaults, t.note, t.published_at
      FROM offer_template_version t WHERE t.id = ${id(c.req.param('id'))}`;
  if (!t) return c.json({ error: 'Šablóna neexistuje.' }, 404);
  const [vars] = await c.var.sql<{ v: string[]; k: string[] }[]>`SELECT to_jsonb(offer_template_variables()) AS v, to_jsonb(offer_template_keys()) AS k`;
  return c.json({ ...t, variables: vars.v, keys: vars.k });
});

// Nový návrh z existujúcej verzie (kópia textov)
offersPdf.post('/offer-templates', async (c) => {
  const b = await readBody(c.req);
  const from = id(String(b.from_id ?? ''));
  const [r] = await c.var.sql<{ id: string }[]>`
    INSERT INTO offer_template_version (org_id, kind, language, sections, defaults, note)
    SELECT org_id, kind, language, sections, defaults, 'z verzie ' || version FROM offer_template_version WHERE id = ${from}
    RETURNING id`;
  if (!r) return c.json({ error: 'Šablóna neexistuje.' }, 404);
  return c.json({ id: r.id }, 201);
});

offersPdf.patch('/offer-templates/:id', async (c) => {
  const b = await readBody(c.req);
  const sections = b.sections && typeof b.sections === 'object' ? b.sections : undefined;
  const defaults = b.defaults && typeof b.defaults === 'object' ? b.defaults : undefined;
  const note = str(b, 'note', 'Poznámka', { max: 500, optional: true });
  const sql = c.var.sql;
  const rows = await sql`
    UPDATE offer_template_version SET
      sections = coalesce(${sections ? sql.json(sections as never) : null}::jsonb, sections),
      defaults = coalesce(${defaults ? sql.json(defaults as never) : null}::jsonb, defaults),
      note = coalesce(${note ?? null}, note)
     WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Šablónu nemôžete upravovať.' }, 403);
  return c.json({ ok: true });
});

offersPdf.delete('/offer-templates/:id', async (c) => {
  const rows = await c.var.sql`DELETE FROM offer_template_version WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Šablónu nemôžete zmazať.' }, 403);
  return c.json({ ok: true });
});

offersPdf.post('/offer-templates/:id/publish', async (c) => {
  await c.var.sql`SELECT offer_template_publish(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// Náhľad šablóny so vzorovými údajmi (texty vyplní databáza rovnako ako pri ponuke)
offersPdf.get('/offer-templates/:id/preview.pdf', async (c) => {
  const sql = c.var.sql;
  const [t] = await sql<{ id: string; kind: 'dodavka' | 'vykup' | 'viwa'; language: 'sk' | 'en'; version: number; status: string; org_id: string;
    sections: Record<string, { nadpis: string; text: string }>; defaults: Record<string, number> }[]>`
    SELECT id, kind, language, version, status, org_id, sections, defaults FROM offer_template_version WHERE id = ${id(c.req.param('id'))}`;
  if (!t) return c.json({ error: 'Šablóna neexistuje.' }, 404);
  const sk = t.language === 'sk';
  const vars: Record<string, string> = {
    'číslo ponuky': 'P26-000000', 'dátum ponuky': sk ? '15. 10. 2026' : '15/10/2026', 'názov': sk ? 'Vzorová firma s.r.o.' : 'Sample company Ltd.',
    'sídlo': 'Hlavná 1, 010 01 Žilina', 'IČO': '12345678', 'IČ DPH': 'SK2012345678', 'kontakt meno': 'Ing. Ján Vzorový',
    'kontakt e-mail': 'jan.vzorovy@example.com', 'kontakt telefón': '+421 900 000 000', 'obchodník meno': 'Meno Obchodníka',
    'obchodník funkcia': sk ? 'obchodník' : 'sales', 'obchodník telefón': '+421 900 000 001', 'obchodník e-mail': 'obchodnik@greenlogy.com',
    'flexibilita': sk ? 'plnej flexibility' : 'full', 'objem': sk ? '252,0' : '252.0',
    'výška preddavkov': sk ? '100 % z 1/12 plánovaného ročného odberu' : '100% of 1/12 of the planned annual consumption',
    'splatnosť preddavku': sk ? '5. deň v mesiaci' : 'day 5 of the month', 'splatnosť faktúr': sk ? '14 dní' : '14 days',
    'platnosť čas': '16:00', 'platnosť dátum': sk ? '16. 10. 2026' : '16/10/2026', 'dátum platnosti': sk ? '16:00 hod. 16. 10. 2026' : '16:00 on 16/10/2026',
    'zmluvná pokuta': sk ? `${t.defaults.zmluvna_pokuta ?? 50},00` : `${t.defaults.zmluvna_pokuta ?? 50}.00`, 'obdobie': sk ? '1. 1. 2027 – 31. 12. 2028' : '1/1/2027 – 31/12/2028',
    'koeficient': sk ? '0,80' : '0.80', 'poplatok za kW': sk ? '0,20' : '0.20',
  };
  const keys = Object.keys(t.sections);
  const filled = await sql<{ key: string; nadpis: string; text: string }[]>`
    SELECT k AS key, offer_template_fill(${sql.json(t.sections as never)}->k->>'nadpis', ${sql.json(vars as never)}, true, true) AS nadpis,
           offer_template_fill(${sql.json(t.sections as never)}->k->>'text', ${sql.json(vars as never)}, true, true) AS text
      FROM jsonb_array_elements_text(${sql.json(keys as never)}) k`;
  const doc: OfferDocument = {
    offer: { id: t.id, display_number: 'P26-000000', kind: t.kind, language: t.language, household: false, sent_at: null, valid_until: new Date().toISOString() },
    template: { id: t.id, version: t.version, status: t.status, order_title: filled.find((x) => x.key === 'objednavka')?.nadpis ?? '',
                order_text: filled.find((x) => x.key === 'objednavka')?.text ?? '' },
    vars,
    sections: filled.filter((x) => x.key !== 'objednavka'),
    variants: [{
      id: '00000000-0000-0000-0000-000000000000', letter: 'A', name: t.kind === 'viwa' ? 'VIWA Plus' : 'FIX 2027–2028',
      label: t.kind === 'viwa' ? 'A · VIWA Plus' : 'A · FIX 2027–2028', price_kind: t.kind === 'viwa' ? 'viwa' : 'fix',
      period: vars['obdobie'], flexibility: vars['flexibilita'], volume_text: vars['objem'], spot: false,
      rows: t.kind === 'viwa' ? [] : [{ product: 'Green 1T Jednotarif', voltage_group: 'nn', oom_count: 3, volume_mwh: 40, price_model: 'fix', vat_rate: null,
        prices: [{ year: 2027, text: sk ? '118,00 €/MWh' : '118.00 €/MWh', text_vat: null }, { year: 2028, text: sk ? '112,00 €/MWh' : '112.00 €/MWh', text_vat: null }] }],
      viwa: t.kind === 'viwa' ? { package: 'PLUS', monthly_fee: 6.9, fee_kw: 0.2, coefficient: 0.8, power_kw: 100 } : null,
      household: null,
    }],
    acceptance: null,
  };
  const html = offerHtml(doc, await offerAssets(sql, t.org_id), { watermark: t.status === 'navrh' ? 'draft' : 'preview' });
  return pdfResponse(await htmlToPdf(c.env.BROWSER, html, pdfFooter(doc)), `Sablona-${t.kind}-${t.language}-v${t.version}.pdf`);
});

// ---------------------------------------------------------------------------------------------------------------
// Obrázky do PDF (obrazovka 42): aktívny z Nastavení, inak pribalený; nahráva admin (RLS), starý sa iba vypne
// ---------------------------------------------------------------------------------------------------------------

offersPdf.get('/offer-assets', async (c) => {
  const rows = await c.var.sql`
    SELECT a.code, a.mime, a.sha256, a.created_at, u.name AS created_by_name
      FROM offer_asset a LEFT JOIN app_user u ON u.id = a.created_by
     WHERE a.org_id = crm_default_org() AND a.active`;
  return c.json({ items: ASSET_CODES.map((code) => ({ code, ...(rows.find((r) => r.code === code) ?? { source: 'pribaleny' }) })) });
});

offersPdf.get('/offer-assets/:code', async (c) => {
  const code = c.req.param('code') as (typeof ASSET_CODES)[number];
  if (!ASSET_CODES.includes(code)) throw new BadRequest('Neznámy obrázok.');
  const [a] = await c.var.sql<{ mime: string; data: Uint8Array }[]>`
    SELECT mime, data FROM offer_asset WHERE org_id = crm_default_org() AND code = ${code} AND active`;
  if (a) return new Response(a.data, { headers: { 'Content-Type': a.mime, 'Cache-Control': 'no-store' } });
  const uri = bundledAssets()[code];
  const bin = Uint8Array.from(atob(uri.split(',')[1]), (ch) => ch.charCodeAt(0));
  return new Response(bin, { headers: { 'Content-Type': 'image/png', 'Cache-Control': 'no-store' } });
});

offersPdf.post('/offer-assets', async (c) => {
  const b = await readBody(c.req);
  const code = oneOf(b, 'code', 'Obrázok', ASSET_CODES);
  if (!code) throw new BadRequest('Vyberte obrázok.');
  const mime = oneOf(b, 'mime', 'Typ', ['image/png', 'image/jpeg'] as const);
  if (!mime || typeof b.data_base64 !== 'string') throw new BadRequest('Nahrajte obrázok PNG alebo JPEG.');
  const bin = Uint8Array.from(atob(b.data_base64), (ch) => ch.charCodeAt(0));
  if (bin.length > 1024 * 1024) throw new BadRequest('Obrázok môže mať najviac 1 MB.');
  await c.var.sql`
    INSERT INTO offer_asset (org_id, code, mime, data, sha256)
    VALUES (crm_default_org(), ${code}, ${mime}, ${bin}, repeat('0', 64))`;
  return c.json({ ok: true }, 201);
});
