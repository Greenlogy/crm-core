// Modul Zákazníci – zakladanie a úprava firmy a osoby, kontrola duplicít, zmazanie bez väzieb
// (zadanie 01-zakaznici.md v0.3, čl. 2, 6, 7, 12, 14). Kto čo vidí a smie meniť, stráži databáza (RLS
// podľa tímu a spoločnosti, vlastníka mení iba CEO a admin). API navyše obmedzuje stĺpce pre tím
// Servis (Peter 12. 10.): na osobe iba kontaktné údaje, na firme nič.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, bool, EMAIL, Forbidden, readBody, str, uuid, type Body } from '../validate';

export const customersWrite = new Hono<AppEnv>();

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

// Stĺpce osoby, ktoré smie meniť Servis (Peter 12. 10.; „nechce marketing“ a firmy osoby v F2).
const SERVIS_PERSON_FIELDS = new Set(['email', 'phone', 'mobile', 'address']);

async function team(sql: Sql, userId: string): Promise<string> {
  const [r] = await sql<{ code: string }[]>`
    SELECT t.code FROM app_user u JOIN team t ON t.id = u.team_id WHERE u.id = ${userId}`;
  return r?.code ?? '';
}

/** IČO / OIB: iba číslice; SK a CZ doplní úvodné nuly na 8 (HubSpot ich stratil). */
function normalizeIco(country: string, raw: string): string {
  const digits = raw.replace(/\D/g, '');
  return country === 'HR' ? digits : digits.padStart(8, '0');
}

// ============================================================================
// Možnosti formulárov a kontrola duplicít
// ============================================================================

customersWrite.get('/customers/options', async (c) => {
  const sql = c.var.sql;
  const [orgs, owners, sources] = await Promise.all([
    sql`SELECT o.id, o.legal_name AS name, o.country, o.is_default
          FROM org o WHERE o.id = ANY (crm_user_orgs()) AND o.status = 'aktivna'
         ORDER BY o.is_default DESC, o.legal_name`,
    sql`SELECT u.id, u.name, t.name AS team_name FROM app_user u JOIN team t ON t.id = u.team_id
         WHERE u.status = 'aktivny' ORDER BY lower(u.name)`,
    sql`SELECT code, label, org_id FROM lookup_value
         WHERE list_code = 'zdroj_kontaktu' AND hidden_at IS NULL ORDER BY sort_order, lower(label)`,
  ]);
  return c.json({ orgs, owners, sources });
});

// Firma je v CRM raz (krajina + IČO/OIB). Kto ju nevidí, dostane iba „existuje“, vlastníka a spoločnosť.
customersWrite.get('/check/company', async (c) => {
  const country = c.req.query('country') ?? 'SK';
  if (!['SK', 'CZ', 'HR'].includes(country)) throw new BadRequest('Neplatná krajina.');
  const ico = (c.req.query('ico') ?? '').replace(/\D/g, '');
  if (ico.length < 6) return c.json({ items: [] });
  const rows = await c.var.sql`SELECT * FROM company_ico_check(${country}::country_code, ${ico})`;
  return c.json({ items: rows });
});

// Osoba: rovnaký e-mail, potom telefón v rámci spoločnosti – iba upozornenie (čl. 7).
customersWrite.get('/check/contact', async (c) => {
  const email = (c.req.query('email') ?? '').trim();
  const phone = (c.req.query('phone') ?? '').trim();
  const org = c.req.query('org') ?? '';
  if (org !== '' && !UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (!email && !phone) return c.json({ items: [] });
  const rows = await c.var.sql`
    SELECT d.match_on, d.contact_id, d.owner_name,
           (SELECT concat_ws(' ', p.first_name, p.last_name) FROM contact p WHERE p.id = d.contact_id) AS name
      FROM contact_duplicate_check(${email || null}, ${phone || null}, ${org || null}::uuid) d`;
  return c.json({ items: rows });
});

// Hľadanie firmy (aj partner, dodávateľ) – pri zakladaní kontaktu vo firme.
customersWrite.get('/companies/search', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  if (q.length < 2) return c.json({ items: [] });
  const rows = await c.var.sql`
    SELECT c.id, c.name, c.ico, c.country, c.org_id
      FROM company c
     WHERE c.name ILIKE ${'%' + q + '%'} OR c.ico LIKE ${q.replace(/\s/g, '') + '%'}
     ORDER BY c.name LIMIT 20`;
  return c.json({ items: rows });
});

// ============================================================================
// Firma
// ============================================================================

// Polia firmy: [kľúč v API = stĺpec, popis, najviac znakov]
const COMPANY_TEXT = [
  ['name', 'Názov', 200],
  ['dic', 'DIČ', 20],
  ['ic_dph', 'IČ DPH', 20],
  ['address', 'Sídlo', 300],
  ['bank_account', 'Bankový účet', 50],
  ['legal_form', 'Právna forma', 100],
  ['registry_entry', 'Zápis v obchodnom registri', 300],
  ['statutory', 'Štatutár', 500],
  ['nace', 'SK NACE', 100],
] as const;

function companyValues(b: Body, creating: boolean): Record<string, unknown> {
  const v: Record<string, unknown> = {};
  for (const [key, label, max] of COMPANY_TEXT) {
    const s = str(b, key, label, { max, optional: !(creating && key === 'name') });
    if (s !== undefined) v[key] = s === '' ? null : s;
  }
  if (v.name === null) throw new BadRequest('Chýba: Názov.');
  for (const [key, label] of [
    ['is_customer', 'Zákazník'],
    ['is_partner', 'Partner'],
    ['is_supplier', 'Dodávateľ'],
  ] as const) {
    const x = bool(b, key, label);
    if (x !== undefined) v[key] = x;
  }
  const owner = b.owner_id === null ? null : uuid(b, 'owner_id', 'Vlastník', true);
  if (b.owner_id !== undefined) v.owner_id = owner ?? null;
  const org = uuid(b, 'org_id', 'Spoločnosť', true);
  if (org) v.org_id = org;
  return v;
}

customersWrite.post('/companies', async (c) => {
  const sql = c.var.sql;
  if ((await team(sql, c.var.userId)) === 'servis') throw new Forbidden('Servis nezakladá firmy.');
  const b = await readBody(c.req);
  const country = str(b, 'country', 'Krajina', { max: 2 })!;
  if (!['SK', 'CZ', 'HR'].includes(country)) throw new BadRequest('Neplatná krajina.');
  const ico = normalizeIco(country, str(b, 'ico', country === 'HR' ? 'OIB' : 'IČO', { max: 20 })!);
  const v = companyValues(b, true);
  if (v.owner_id === undefined) v.owner_id = c.var.userId;
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO company ${sql({ ...v, country, ico })} RETURNING id`;
  return c.json({ id: row.id }, 201);
});

customersWrite.patch('/companies/:id', async (c) => {
  const companyId = id(c.req.param('id'));
  const sql = c.var.sql;
  if ((await team(sql, c.var.userId)) === 'servis') {
    throw new Forbidden('Servis nemení údaje firmy (iba kontaktné údaje osôb).');
  }
  const b = await readBody(c.req);
  const v = companyValues(b, false);
  if (b.ico !== undefined || b.country !== undefined) {
    const [cur] = await sql<{ country: string }[]>`SELECT country FROM company WHERE id = ${companyId}`;
    const country = str(b, 'country', 'Krajina', { max: 2, optional: true }) || cur?.country || 'SK';
    if (!['SK', 'CZ', 'HR'].includes(country)) throw new BadRequest('Neplatná krajina.');
    v.country = country;
    if (b.ico !== undefined) v.ico = normalizeIco(country, str(b, 'ico', 'IČO', { max: 20 })!);
  }
  if (Object.keys(v).length === 0) return c.json({ ok: true });
  const rows = await sql`UPDATE company SET ${sql(v)} WHERE id = ${companyId} RETURNING id`;
  // RLS: firmu, ktorú používateľ nesmie upravovať, UPDATE nenájde
  if (rows.length === 0) return c.json({ error: 'Firmu nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

customersWrite.delete('/companies/:id', async (c) => {
  const companyId = id(c.req.param('id'));
  const [r] = await c.var.sql<{ name: string }[]>`SELECT customer_delete(${companyId}, NULL) AS name`;
  return c.json({ ok: true, name: r.name });
});

// ============================================================================
// Osoba
// ============================================================================

const PERSON_TEXT = [
  ['first_name', 'Meno', 80],
  ['last_name', 'Priezvisko', 80],
  ['title', 'Titul', 40],
  ['email', 'E-mail', 200],
  ['phone', 'Telefón', 40],
  ['mobile', 'Mobil', 40],
  ['position', 'Pozícia', 100],
  ['address', 'Adresa', 300],
  ['source', 'Zdroj', 63],
] as const;

function personValues(b: Body, creating: boolean): Record<string, unknown> {
  const v: Record<string, unknown> = {};
  for (const [key, label, max] of PERSON_TEXT) {
    const required = creating && (key === 'first_name' || key === 'last_name');
    const s = str(b, key, label, { max, optional: !required });
    if (s !== undefined) v[key] = s === '' ? null : s;
  }
  if (v.first_name === null || v.last_name === null) throw new BadRequest('Chýba meno alebo priezvisko.');
  if (typeof v.email === 'string') {
    v.email = v.email.toLowerCase();
    if (!EMAIL.test(v.email as string)) throw new BadRequest('E-mail nemá správny tvar.');
  }
  const household = bool(b, 'is_household', 'Domácnosť');
  if (household !== undefined) v.is_household = household;
  if (b.owner_id !== undefined) v.owner_id = b.owner_id === null ? null : uuid(b, 'owner_id', 'Vlastník');
  const org = uuid(b, 'org_id', 'Spoločnosť', true);
  if (org) v.org_id = org;
  return v;
}

// Nová osoba: domácnosť (is_household) alebo kontakt vo firme (company_id; roly v F2).
customersWrite.post('/persons', async (c) => {
  const sql = c.var.sql;
  if ((await team(sql, c.var.userId)) === 'servis') throw new Forbidden('Servis nezakladá osoby (pridáva iba existujúce do firmy).');
  const b = await readBody(c.req);
  const v = personValues(b, true);
  const companyId = uuid(b, 'company_id', 'Firma', true);
  if (v.is_household === undefined) v.is_household = !companyId;
  if (!v.is_household && !companyId) throw new BadRequest('Kontakt vo firme potrebuje firmu (alebo založte domácnosť).');
  if (!v.email && !v.phone && !v.mobile) throw new BadRequest('Zadajte e-mail alebo telefón.');
  if (v.owner_id === undefined) v.owner_id = c.var.userId;
  if (companyId && !v.org_id) {
    // kontakt vo firme patrí spoločnosti firmy
    const [f] = await sql<{ org_id: string }[]>`SELECT org_id FROM company WHERE id = ${companyId}`;
    if (!f) throw new BadRequest('Firma neexistuje.');
    v.org_id = f.org_id;
  }
  const [row] = await sql<{ id: string }[]>`INSERT INTO contact ${sql(v)} RETURNING id`;
  if (companyId) await sql`INSERT INTO company_contact (company_id, contact_id) VALUES (${companyId}, ${row.id})`;
  return c.json({ id: row.id }, 201);
});

customersWrite.patch('/persons/:id', async (c) => {
  const personId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const v = personValues(b, false);
  if ((await team(sql, c.var.userId)) === 'servis') {
    const denied = Object.keys(v).filter((k) => !SERVIS_PERSON_FIELDS.has(k));
    if (denied.length) throw new Forbidden('Servis mení iba e-mail, telefón, mobil a adresu.');
  }
  if (Object.keys(v).length === 0) return c.json({ ok: true });
  const rows = await sql`UPDATE contact SET ${sql(v)} WHERE id = ${personId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Osobu nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

customersWrite.delete('/persons/:id', async (c) => {
  const personId = id(c.req.param('id'));
  const [r] = await c.var.sql<{ name: string }[]>`SELECT customer_delete(NULL, ${personId}) AS name`;
  return c.json({ ok: true, name: r.name });
});
