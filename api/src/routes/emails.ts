// Modul 5, F4 – e-maily z CRM (obrazovka 37), profil do podpisu, šablóny e-mailov, overenie Gmailu a denník čítania
// schránok (návrh DB časti 1.9, 1.10, 3, 28, 29; migrácie 0042, 0043). Pravidlá stráži databáza (koncept iba autor,
// odoslanie iba so zapnutým Gmailom, RLS podľa obchodu / zákazníka); tu sa skladá PDF, odkaz a správa pre Gmail.
//
// Odoslanie beží mimo transakcie požiadavky: každý krok (odosiela sa → ID z Gmailu → dokončenie) je samostatná
// potvrdená transakcia na vlastnom pripojení (gmail/deliver.ts), aby odoslaný e-mail nikdy nezostal bez záznamu.

import { Hono } from 'hono';
import { asUser, connect } from '../db';
import { deliver, type Payload, type Runner } from '../gmail/deliver';
import { gmailCheck, gmailConfigured } from '../gmail/gmail';
import { base64, htmlToText, cleanText, recipientsAllowed, type Signature, signatureHtml } from '../gmail/mime';
import { cleanSignatureHtml, MAX_SIGNATURE_IMAGE_BYTES, signatureImageType } from '../gmail/signature';
import { sha256Hex } from '../render/pdf';
import { type AppEnv, UUID } from '../types';
import { BadRequest, type Body, EMAIL, Forbidden, oneOf, readBody, str } from '../validate';
import { newToken, storeOfferPdf } from './offers-pdf';

export const emails = new Hono<AppEnv>();

const MAX_PHOTO = 300 * 1024;
const TEMPLATE_CODES = ['ponuka_dodavka', 'ponuka_vykup', 'ponuka_viwa', 'potvrdenie_akceptacie', 'pripomienka_platnosti', 'volny'] as const;
const KINDS = ['ponuka', 'volny', 'pripomienka_platnosti'] as const;

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}
function optId(b: Body, key: string): string | null {
  const v = b[key];
  if (v === undefined || v === null || v === '') return null;
  if (typeof v !== 'string' || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}
function addresses(b: Body, key: string, label: string): string[] {
  const v = b[key] ?? [];
  if (!Array.isArray(v) || v.length > 50) throw new BadRequest(`${label}: neplatný zoznam.`);
  const out: string[] = [];
  for (const x of v) {
    const a = typeof x === 'string' ? x.trim().toLowerCase() : '';
    if (!EMAIL.test(a) || a.length > 254) throw new BadRequest(`${label}: neplatná adresa ${String(x).slice(0, 80)}.`);
    if (!out.includes(a)) out.push(a);
  }
  return out;
}

// ---------------------------------------------------------------------------------------------------------------
// Koncept a predvyplnenie
// ---------------------------------------------------------------------------------------------------------------

// Predvyplnený e-mail k ponuke (šablóna, zhrnutie variantov, oslovenie, adresát) + rozpracovaný koncept, ak je
emails.get('/offers/:id/email', async (c) => {
  const offerId = id(c.req.param('id'));
  const code = c.req.query('code') || null;
  const sql = c.var.sql;
  const [r] = await sql<{ c: unknown }[]>`SELECT email_compose_offer(${offerId}, ${code}) AS c`;
  const [me] = await sql<{ gmail_enabled: boolean; email: string }[]>`SELECT gmail_enabled, email FROM app_user WHERE id = ${c.var.userId}`;
  const [draft] = await sql`
    SELECT m.id, m.to_addrs AS to, m.cc_addrs AS cc, m.subject, m.body_text AS body, m.error, m.status::text
      FROM email_message m
     WHERE m.offer_id = ${offerId} AND m.kind = 'ponuka' AND m.status IN ('koncept', 'chyba') AND m.created_by = ${c.var.userId}
     ORDER BY m.updated_at DESC LIMIT 1`;
  return c.json({
    compose: r.c, draft: draft ?? null, gmail_enabled: me.gmail_enabled, gmail_configured: gmailConfigured(c.env),
    mailbox: me.email, environment: c.env.ENVIRONMENT ?? 'test',
  });
});

// Schránka prihláseného (dialóg pri otvorení konceptu)
emails.get('/emails/me', async (c) => {
  const [u] = await c.var.sql<{ gmail_enabled: boolean; mailbox: string }[]>`SELECT gmail_enabled, email AS mailbox FROM app_user WHERE id = ${c.var.userId}`;
  return c.json({ ...u, gmail_configured: gmailConfigured(c.env), environment: c.env.ENVIRONMENT ?? 'test' });
});

// Predvyplnený voľný e-mail z karty obchodu, firmy alebo kontaktu: platná šablóna „voľný“ v zvolenom jazyku (sk / en) alebo
// prázdny e-mail (iba oslovenie a podpis), oslovenie a adresát z hlavného kontaktu obchodu alebo z kontaktu.
// Vráti aj jazyky, v ktorých je šablóna „voľný“ platná (výber v dialógu – uzávierka modulu 5, bod 5).
emails.get('/emails/new', async (c) => {
  const deal = c.req.query('deal_id') || null;
  const company = c.req.query('company_id') || null;
  const person = c.req.query('person_id') || null;
  for (const v of [deal, company, person]) if (v && !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  if (!deal && !company && !person) throw new BadRequest('Zadajte obchod, firmu alebo kontakt.');
  const lang = c.req.query('lang') === 'en' ? 'en' : 'sk';
  const empty = c.req.query('template') === 'prazdny';
  const sql = c.var.sql;
  const [r] = await sql<{ template_version_id: string | null; subject: string; body: string; to: string[]; gmail_enabled: boolean; mailbox: string }[]>`
    WITH k AS (
      SELECT p.id, p.email FROM contact p
       WHERE p.id = coalesce(${person}::uuid,
                             (SELECT dc.contact_id FROM deal_contact dc WHERE dc.deal_id = ${deal}::uuid ORDER BY dc.is_primary DESC LIMIT 1),
                             (SELECT d.person_id FROM deal d WHERE d.id = ${deal}::uuid))
    ), t AS (
      SELECT id, subject, body FROM email_template_version
       WHERE org_id = crm_default_org() AND code = 'volny' AND language = ${lang}::offer_language AND status = 'platna' AND NOT ${empty}
    )
    SELECT (SELECT id FROM t) AS template_version_id, coalesce((SELECT subject FROM t), '') AS subject,
           replace(coalesce((SELECT body FROM t), '«oslovenie»,' || chr(10) || chr(10) || chr(10) || '«podpis»'), '«oslovenie»',
                   email_salutation((SELECT id FROM k), ${lang}::offer_language)) AS body,
           coalesce((SELECT to_jsonb(ARRAY[lower(btrim(email))]) FROM k WHERE email IS NOT NULL AND btrim(email) <> ''), '[]'::jsonb) AS to,
           u.gmail_enabled, u.email AS mailbox,
           coalesce((SELECT jsonb_agg(DISTINCT language::text) FROM email_template_version
                      WHERE org_id = crm_default_org() AND code = 'volny' AND status = 'platna'), '[]'::jsonb) AS languages
      FROM app_user u WHERE u.id = ${c.var.userId}`;
  return c.json({ ...r, gmail_configured: gmailConfigured(c.env), environment: c.env.ENVIRONMENT ?? 'test' });
});

// Uloženie konceptu (nový alebo zmena vlastného)
emails.post('/emails/drafts', async (c) => {
  const b = await readBody(c.req);
  const draftId = optId(b, 'id');
  const kind = oneOf(b, 'kind', 'Druh', KINDS) ?? 'volny';
  const p = {
    kind,
    offer_id: optId(b, 'offer_id'),
    thread_id: optId(b, 'thread_id'),
    deal_id: optId(b, 'deal_id'),
    company_id: optId(b, 'company_id'),
    person_id: optId(b, 'person_id'),
    template_version_id: optId(b, 'template_version_id'),
    to: addresses(b, 'to', 'Komu'),
    cc: addresses(b, 'cc', 'Kópia'),
    subject: str(b, 'subject', 'Predmet', { max: 998, optional: true }) ?? '',
    body: str(b, 'body', 'Text', { max: 200_000, optional: true }) ?? '',
  };
  const [r] = await c.var.sql<{ id: string }[]>`SELECT email_draft_save(${draftId}, ${c.var.sql.json(p)}) AS id`;
  return c.json({ id: r.id }, draftId ? 200 : 201);
});

emails.delete('/emails/drafts/:id', async (c) => {
  await c.var.sql`SELECT email_draft_delete(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// Po kontrole Odoslaných v Gmaile: e-mail v stave Chyba späť do konceptu (autor) alebo do fronty (admin)
emails.post('/emails/:id/retry', async (c) => {
  await c.var.sql`SELECT email_retry(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// ---------------------------------------------------------------------------------------------------------------
// Odoslanie
// ---------------------------------------------------------------------------------------------------------------

// Odoslanie konceptu. send_key vytvorí prehliadač pri otvorení dialógu – dvojklik ani opakovaná požiadavka e-mail
// znova neodošle (databáza vráti fresh = false).
emails.post('/emails/:id/send', async (c) => {
  const msgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const sendKey = typeof b.send_key === 'string' && UUID.test(b.send_key) ? b.send_key : null;
  if (!sendKey) throw new BadRequest('Chýba jednorazový kľúč odoslania.');
  if (!gmailConfigured(c.env)) throw new BadRequest('Gmail ešte nie je v CRM nastavený (chýba kľúč servisného účtu).');
  const sql = c.var.sql;
  const [m] = await sql<{ kind: string; offer_id: string | null; to: string[]; cc: string[]; status: string; send_key: string | null }[]>`
    SELECT kind, offer_id, to_addrs AS to, cc_addrs AS cc, status::text, send_key FROM email_message WHERE id = ${msgId}`;
  if (!m) return c.json({ error: 'E-mail neexistuje alebo ho nevidíte.' }, 404);
  const blocked = recipientsAllowed([...m.to, ...m.cc], c.env.ENVIRONMENT, c.env.MAIL_ALLOWLIST);
  if (blocked.length) throw new BadRequest(`Na Teste smie CRM posielať iba na @greenlogy.com a povolené adresy (nepovolené: ${blocked.length}).`);

  // PDF a odkaz ponuky: pripravia sa pred záznamom „odosiela sa“; k ponuke sa zapíšu až po odoslaní
  let pdf: { key: string; sha: string } | null = null;
  let token: string | null = null;
  if (m.kind === 'ponuka' && m.status === 'koncept' && m.send_key !== sendKey) {
    const [o] = await sql<{ status: string }[]>`SELECT status::text FROM offer WHERE id = ${m.offer_id}`;
    if (o?.status !== 'pripravena') throw new BadRequest('E-mailom sa dá odoslať iba pripravená ponuka.');
    pdf = await storeOfferPdf(sql, c.env, m.offer_id!);
    token = newToken();
  }

  const own = connect(c.env);
  const run: Runner = (fn) => asUser(own, c.var.userId, fn);
  const linkHash = token ? await sha256Hex(token) : null;
  try {
    const [r] = await run((tx) => tx<{ p: Payload }[]>`
      SELECT email_send_prepare(${msgId}, ${sendKey}, ${pdf?.key ?? null}, ${pdf?.sha ?? null}, ${linkHash}) AS p`);
    const p = r.p;
    if (!p.fresh) {
      return c.json({ state: p.status === 'odoslany' ? 'odoslany' : 'odosiela_sa', repeated: true });
    }
    const link = token ? `${c.env.PUBLIC_OFFER_URL}/p/${token}` : null;
    const res = await deliver(c.env, run, p, link);
    if (res.state === 'odmietnuty') return c.json({ state: res.state, error: res.error }, 502);
    if (res.state === 'neiste') {
      return c.json({ state: res.state, error: 'Gmail neodpovedal. Nie je isté, či e-mail odišiel – CRM ho znova neodošle. Skontrolujte Odoslané v Gmaile; stav sa doplní do 15 minút.' }, 502);
    }
    return c.json(res);
  } finally {
    c.executionCtx.waitUntil(own.end());
  }
});

// ---------------------------------------------------------------------------------------------------------------
// Vlákna a správy (časová os obchodu, firmy, kontaktu)
// ---------------------------------------------------------------------------------------------------------------

emails.get('/emails', async (c) => {
  const deal = c.req.query('deal_id');
  const company = c.req.query('company_id');
  const person = c.req.query('person_id');
  const [k, v] = deal ? ['deal', deal] : company ? ['company', company] : person ? ['person', person] : [null, null];
  if (!k || !UUID.test(v!)) throw new BadRequest('Zadajte obchod, firmu alebo kontakt.');
  const rows = await c.var.sql`
    SELECT m.id, m.thread_id, t.subject AS thread_subject, m.direction, m.status::text, m.kind, m.offer_id,
           offer_display_number(o) AS offer_number, m.from_addr AS from, m.from_name, m.to_addrs AS to, m.cc_addrs AS cc,
           m.subject, m.body_text AS body, m.error, m.sent_at, m.received_at, m.created_at, m.updated_at,
           coalesce(m.sent_at, m.received_at, m.updated_at) AS at, u.name AS author, mu.email AS mailbox,
           m.created_by = ${c.var.userId} OR (m.created_by IS NULL AND t.mailbox_user_id = ${c.var.userId}) AS mine,
           jsonb_array_length(m.attachments) AS attachment_count
      FROM email_message m
      JOIN email_thread t ON t.id = m.thread_id
      LEFT JOIN offer o ON o.id = m.offer_id
      LEFT JOIN app_user u ON u.id = m.created_by
      LEFT JOIN app_user mu ON mu.id = t.mailbox_user_id
     WHERE CASE ${k} WHEN 'deal' THEN t.deal_id = ${v}::uuid
                     WHEN 'company' THEN t.company_id = ${v}::uuid
                     ELSE t.person_id = ${v}::uuid END
     ORDER BY coalesce(m.sent_at, m.received_at, m.updated_at) DESC
     LIMIT 200`;
  return c.json({ items: rows });
});

// ---------------------------------------------------------------------------------------------------------------
// Profil do podpisu (sám alebo admin – databáza)
// ---------------------------------------------------------------------------------------------------------------

const profileId = (c: { req: { param: (k: string) => string }; var: { userId: string } }) =>
  c.req.param('id') === 'me' ? c.var.userId : id(c.req.param('id'));

emails.get('/profiles/:id', async (c) => {
  const uid = profileId(c);
  const sql = c.var.sql;
  if (uid !== c.var.userId) {
    const [adm] = await sql<{ a: boolean }[]>`SELECT crm_is_admin() AS a`;
    if (!adm.a) throw new Forbidden('Profil vidí používateľ sám alebo admin.');
  }
  const [u] = await sql`SELECT id, name, email, phone, mobile, job_title, linkedin_url, gmail_enabled FROM app_user WHERE id = ${uid}`;
  if (!u) return c.json({ error: 'Používateľ neexistuje.' }, 404);
  const [s] = await sql<{ s: Signature }[]>`SELECT email_signature(${uid}) AS s`;
  const imgs = await sql<{ cid: string }[]>`SELECT cid FROM user_signature_image WHERE user_id = ${uid} ORDER BY cid`;
  const [own] = await sql<{ mode: string; html: string | null }[]>`SELECT mode, html FROM user_signature WHERE user_id = ${uid}`;
  return c.json({
    ...u, signature: s.s, signature_html: signatureHtml(s.s, s.s.has_photo ? 'foto' : null),
    custom: { mode: own?.mode ?? 'profil', html: own?.html ?? null, images: imgs.map((i) => i.cid) },
  });
});

emails.patch('/profiles/:id', async (c) => {
  const uid = profileId(c);
  const b = await readBody(c.req);
  const phone = str(b, 'phone', 'Telefón', { max: 40, optional: true }) || null;
  const mobile = str(b, 'mobile', 'Mobil', { max: 40, optional: true }) || null;
  const job = str(b, 'job_title', 'Funkcia', { max: 80, optional: true }) || null;
  const linkedin = str(b, 'linkedin_url', 'LinkedIn', { max: 250, optional: true }) || null;
  if (linkedin && !/^https:\/\/([a-z]{2,3}\.)?linkedin\.com\/[A-Za-z0-9_/%.-]{1,200}$/.test(linkedin)) {
    throw new BadRequest('LinkedIn: zadajte adresu profilu https://www.linkedin.com/in/…');
  }
  await c.var.sql`SELECT user_profile_set(${uid}, ${phone}, ${mobile}, ${job}, ${linkedin})`;
  return c.json({ ok: true });
});

/** Rozmery PNG / JPEG z hlavičky súboru (bez dekódovania obrázka). */
export function imageSize(b: Uint8Array): { mime: 'image/png' | 'image/jpeg'; w: number; h: number } | null {
  if (b.length > 24 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) {
    const v = new DataView(b.buffer, b.byteOffset, b.byteLength);
    return { mime: 'image/png', w: v.getUint32(16), h: v.getUint32(20) };
  }
  if (b.length > 4 && b[0] === 0xff && b[1] === 0xd8) {
    let i = 2;
    while (i + 9 < b.length) {
      if (b[i] !== 0xff) return null;
      const marker = b[i + 1];
      const len = (b[i + 2] << 8) | b[i + 3];
      if (marker >= 0xc0 && marker <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marker)) {
        return { mime: 'image/jpeg', h: (b[i + 5] << 8) | b[i + 6], w: (b[i + 7] << 8) | b[i + 8] };
      }
      i += 2 + len;
    }
  }
  return null;
}

// Fotka do podpisu: prehliadač ju oreže na štvorec a zmenší; tu sa overí typ, štvorec a veľkosť (do 300 kB)
emails.put('/profiles/:id/photo', async (c) => {
  const uid = profileId(c);
  const b = await readBody(c.req);
  if (typeof b.data_base64 !== 'string' || !b.data_base64) throw new BadRequest('Chýba fotka.');
  let bin: Uint8Array;
  try {
    bin = Uint8Array.from(atob(b.data_base64), (ch) => ch.charCodeAt(0));
  } catch {
    throw new BadRequest('Fotka: neplatné dáta.');
  }
  if (bin.length > MAX_PHOTO) throw new BadRequest('Fotka môže mať najviac 300 kB.');
  const size = imageSize(bin);
  if (!size) throw new BadRequest('Fotka musí byť JPEG alebo PNG.');
  if (size.w !== size.h || size.w < 64 || size.w > 1024) throw new BadRequest('Fotka musí byť štvorec 64 až 1024 px.');
  await c.var.sql`
    INSERT INTO user_photo (user_id, mime, data, sha256) VALUES (${uid}, ${size.mime}, ${bin}, repeat('0', 64))
    ON CONFLICT (user_id) DO UPDATE SET mime = excluded.mime, data = excluded.data`;
  return c.json({ ok: true });
});

// Vlastný podpis (0044): HTML vložené cez Ctrl+V alebo ako kód → vyčistenie, obrázky (https / data:) sa stiahnu
// a uložia k podpisu (cid:), textová verzia sa vytvorí automaticky. mode = profil vráti podpis z profilu.
emails.put('/profiles/:id/signature', async (c) => {
  const uid = profileId(c);
  const b = await readBody(c.req);
  const mode = oneOf(b, 'mode', 'Podpis', ['profil', 'vlastny'] as const) ?? 'profil';
  if (mode === 'profil') {
    await c.var.sql`SELECT user_signature_set(${uid}, 'profil', NULL, NULL, '[]'::jsonb)`;
    return c.json({ ok: true, mode });
  }
  const raw = typeof b.html === 'string' ? b.html : '';
  if (!raw.trim()) throw new BadRequest('Vložte podpis.');
  if (raw.length > 2_000_000) throw new BadRequest('Podpis je príliš veľký.');
  const clean = cleanSignatureHtml(raw);
  if (!clean.html) throw new BadRequest('Z podpisu po vyčistení nič neostalo alebo je príliš dlhý.');
  let html = clean.html;
  const images: { cid: string; mime: string; data_base64: string }[] = [];
  const failed: string[] = [];
  for (const img of clean.images) {
    let data: Uint8Array | null = null;
    try {
      if (img.src.startsWith('data:')) {
        data = Uint8Array.from(atob(img.src.slice(img.src.indexOf(',') + 1)), (ch) => ch.charCodeAt(0));
      } else {
        const ctrl = new AbortController();
        const t = setTimeout(() => ctrl.abort(), 8000);
        const res = await fetch(img.src, { signal: ctrl.signal, redirect: 'follow', headers: { Accept: 'image/png,image/jpeg,image/gif' } });
        clearTimeout(t);
        const len = Number(res.headers.get('content-length') ?? '0');
        if (res.ok && len <= MAX_SIGNATURE_IMAGE_BYTES) data = new Uint8Array(await res.arrayBuffer());
      }
    } catch {
      data = null;
    }
    const mime = data && data.length <= MAX_SIGNATURE_IMAGE_BYTES ? signatureImageType(data) : null;
    if (!data || !mime) {
      failed.push(img.cid);
      html = html.replace(new RegExp(`<img src="cid:${img.cid}"[^>]*>`, 'g'), '');
      continue;
    }
    images.push({ cid: img.cid, mime, data_base64: base64(data) });
  }
  const text = cleanText(htmlToText(html.replace(/<\/td>/gi, ' </td>')).replace(/\u00a0/g, ' '));
  await c.var.sql`SELECT user_signature_set(${uid}, 'vlastny', ${html}, ${text}, ${c.var.sql.json(images)})`;
  return c.json({ ok: true, mode, removed: clean.dropped, images: images.length, images_failed: failed.length });
});

// Obrázok vlastného podpisu (náhľad v profile; sám alebo admin – RLS)
emails.get('/profiles/:id/signature-images/:cid', async (c) => {
  const cid = c.req.param('cid');
  if (!/^sig[1-5]$/.test(cid)) throw new BadRequest('Neplatný obrázok.');
  const [i] = await c.var.sql<{ mime: string; data: Uint8Array }[]>`
    SELECT mime, data FROM user_signature_image WHERE user_id = ${profileId(c)} AND cid = ${cid}`;
  if (!i) return c.json({ error: 'Obrázok nie je.' }, 404);
  return new Response(new Uint8Array(i.data), { headers: { 'Content-Type': i.mime, 'Cache-Control': 'no-store' } });
});

emails.delete('/profiles/:id/photo', async (c) => {
  await c.var.sql`DELETE FROM user_photo WHERE user_id = ${profileId(c)}`;
  return c.json({ ok: true });
});

emails.get('/profiles/:id/photo', async (c) => {
  const [p] = await c.var.sql<{ mime: string; data: Uint8Array }[]>`SELECT mime, data FROM user_photo WHERE user_id = ${profileId(c)}`;
  if (!p) return c.json({ error: 'Fotka nie je.' }, 404);
  return new Response(new Uint8Array(p.data), { headers: { 'Content-Type': p.mime, 'Cache-Control': 'no-store' } });
});

// ---------------------------------------------------------------------------------------------------------------
// Nastavenia: šablóny e-mailov (admin a Marketing – databáza), overenie Gmailu, denník čítania schránok
// ---------------------------------------------------------------------------------------------------------------

emails.get('/settings/email-templates', async (c) => {
  const sql = c.var.sql;
  const [items, vars, ed] = await Promise.all([
    sql`SELECT t.id, t.code, t.language::text, t.version, t.status, t.name, t.subject, t.body, t.note, t.created_at,
               t.published_at, cu.name AS created_by_name, pu.name AS published_by_name
          FROM email_template_version t
          LEFT JOIN app_user cu ON cu.id = t.created_by LEFT JOIN app_user pu ON pu.id = t.published_by
         WHERE t.org_id = crm_default_org()
         ORDER BY t.code, t.language, t.version DESC`,
    sql<{ v: string[] }[]>`SELECT to_jsonb(email_template_variables()) AS v`,
    sql<{ e: boolean }[]>`SELECT crm_email_template_editor() AS e`,
  ]);
  return c.json({ items, variables: vars[0].v, can_edit: ed[0].e });
});

// Nová verzia (návrh) z textu – platná sa nemení
emails.post('/settings/email-templates', async (c) => {
  const b = await readBody(c.req);
  const code = oneOf(b, 'code', 'Druh', TEMPLATE_CODES);
  const lang = oneOf(b, 'language', 'Jazyk', ['sk', 'en'] as const);
  if (!code || !lang) throw new BadRequest('Chýba druh alebo jazyk šablóny.');
  const name = str(b, 'name', 'Názov', { max: 120 })!;
  const subject = str(b, 'subject', 'Predmet', { max: 998, optional: true }) ?? '';
  const body = str(b, 'body', 'Text', { max: 20_000 })!;
  const note = str(b, 'note', 'Poznámka', { max: 500, optional: true }) || null;
  const [r] = await c.var.sql<{ id: string }[]>`
    INSERT INTO email_template_version (org_id, code, language, version, name, subject, body, note)
    VALUES (crm_default_org(), ${code}, ${lang}, 0, ${name}, ${subject}, ${body}, ${note}) RETURNING id`;
  return c.json({ id: r.id }, 201);
});

emails.patch('/settings/email-templates/:id', async (c) => {
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov', { max: 120, optional: true });
  const subject = str(b, 'subject', 'Predmet', { max: 998, optional: true });
  const body = str(b, 'body', 'Text', { max: 20_000, optional: true });
  const note = 'note' in b ? (str(b, 'note', 'Poznámka', { max: 500, optional: true }) || null) : undefined;
  const r = await c.var.sql`
    UPDATE email_template_version
       SET name = coalesce(${name ?? null}, name), subject = coalesce(${subject ?? null}, subject),
           body = coalesce(${body ?? null}, body), note = CASE WHEN ${note !== undefined} THEN ${note ?? null} ELSE note END
     WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  if (!r.length) return c.json({ error: 'Šablóna neexistuje alebo ju nemôžete meniť.' }, 404);
  return c.json({ ok: true });
});

emails.delete('/settings/email-templates/:id', async (c) => {
  const r = await c.var.sql`DELETE FROM email_template_version WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  if (!r.length) return c.json({ error: 'Šablóna neexistuje alebo ju nemôžete zmazať.' }, 404);
  return c.json({ ok: true });
});

emails.post('/settings/email-templates/:id/publish', async (c) => {
  await c.var.sql`SELECT email_template_publish(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// Overenie Gmailu pre schránku (admin): iba vydanie tokenu na odoslanie – schránka sa nečíta
emails.post('/settings/gmail-check', async (c) => {
  const sql = c.var.sql;
  const [adm] = await sql<{ a: boolean }[]>`SELECT crm_is_admin() AS a`;
  if (!adm.a) throw new Forbidden('Overenie Gmailu robí admin.');
  const b = await readBody(c.req);
  const uid = optId(b, 'user_id');
  let mailbox = 'crm@greenlogy.com';
  if (uid) {
    const [u] = await sql<{ email: string }[]>`SELECT email FROM app_user WHERE id = ${uid}`;
    if (!u) return c.json({ error: 'Používateľ neexistuje.' }, 404);
    mailbox = u.email;
  }
  if (!gmailConfigured(c.env)) return c.json({ ok: false, error: 'Chýba kľúč servisného účtu (GOOGLE_SA_KEY).' });
  try {
    await gmailCheck(c.env, mailbox);
    return c.json({ ok: true, mailbox });
  } catch (e) {
    return c.json({ ok: false, mailbox, error: e instanceof Error ? e.message : 'Chyba' });
  }
});

// Denník čítania schránok (admin – RLS)
emails.get('/settings/mailbox-access', async (c) => {
  const mailboxUser = c.req.query('mailbox_user_id');
  const filter = mailboxUser && UUID.test(mailboxUser) ? mailboxUser : null;
  const rows = await c.var.sql`
    SELECT l.id, l.at, l.method, l.format, l.gmail_thread_id, l.gmail_message_id, l.thread_id,
           u.name AS user_name, mu.name AS mailbox_name, mu.email AS mailbox, t.deal_id
      FROM mailbox_access_log l
      LEFT JOIN app_user u ON u.id = l.user_id
      JOIN app_user mu ON mu.id = l.mailbox_user_id
      JOIN email_thread t ON t.id = l.thread_id
     WHERE ${filter}::uuid IS NULL OR l.mailbox_user_id = ${filter}::uuid
     ORDER BY l.id DESC LIMIT 500`;
  return c.json({ items: rows });
});

