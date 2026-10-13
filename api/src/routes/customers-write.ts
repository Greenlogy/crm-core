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
  const [orgs, owners, sources, contactRoles] = await Promise.all([
    sql`SELECT o.id, o.legal_name AS name, o.country, o.is_default
          FROM org o WHERE o.id = ANY (crm_user_orgs()) AND o.status = 'aktivna'
         ORDER BY o.is_default DESC, o.legal_name`,
    sql`SELECT u.id, u.name, t.name AS team_name FROM app_user u JOIN team t ON t.id = u.team_id
         WHERE u.status = 'aktivny' ORDER BY lower(u.name)`,
    sql`SELECT code, label, org_id FROM lookup_value
         WHERE list_code = 'zdroj_kontaktu' AND hidden_at IS NULL ORDER BY sort_order, lower(label)`,
    sql`SELECT code, label, org_id, is_system, hidden_at FROM lookup_value
         WHERE list_code = 'rola_kontaktu' ORDER BY sort_order, lower(label)`,
  ]);
  return c.json({ orgs, owners, sources, roles: contactRoles, opt_out_sources: OPT_OUT_SOURCES });
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

// ============================================================================
// F2: osoba vo firme (roly, hlavný kontakt), „nechce marketing“, poznámky
// ============================================================================

// Hľadanie osoby (pridanie existujúcej osoby do firmy) – iba v spoločnosti firmy.
customersWrite.get('/persons/search', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const org = c.req.query('org') ?? '';
  if (org !== '' && !UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (q.length < 2) return c.json({ items: [] });
  const like = '%' + q + '%';
  const rows = await c.var.sql`
    SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.email, coalesce(p.mobile, p.phone) AS phone,
           p.is_household
      FROM contact p
     WHERE (${org} = '' OR p.org_id::text = ${org})
       AND (concat_ws(' ', p.first_name, p.last_name) ILIKE ${like} OR p.email ILIKE ${like}
            OR (normalize_phone(${q}) IS NOT NULL AND normalize_phone(${q}) IN (p.phone_norm, p.mobile_norm)))
     ORDER BY p.last_name, p.first_name LIMIT 20`;
  return c.json({ items: rows });
});

function roles(b: Body): string[] | undefined {
  const v = b.roles;
  if (v === undefined) return undefined;
  if (!Array.isArray(v) || v.some((x) => typeof x !== 'string' || !/^[a-z0-9_]{1,63}$/.test(x))) {
    throw new BadRequest('Roly: neplatný zoznam.');
  }
  return [...new Set(v as string[])];
}

// Hlavný kontakt firmy je najviac jeden: nový hlavný zruší predchádzajúceho.
async function setMain(sql: Sql, companyId: string, contactId: string) {
  await sql`UPDATE company_contact SET is_main_contact = false
             WHERE company_id = ${companyId} AND is_main_contact AND contact_id <> ${contactId}`;
  await sql`UPDATE company_contact SET is_main_contact = true WHERE company_id = ${companyId} AND contact_id = ${contactId}`;
}

customersWrite.post('/companies/:id/contacts', async (c) => {
  const companyId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const contactId = uuid(b, 'contact_id', 'Osoba')!;
  const main = bool(b, 'is_main_contact', 'Hlavný kontakt') ?? false;
  if (main && (await team(sql, c.var.userId)) === 'servis') throw new Forbidden('Hlavný kontakt firmy Servis nemení.');
  await sql`INSERT INTO company_contact (company_id, contact_id, roles)
            VALUES (${companyId}, ${contactId}, ARRAY(SELECT jsonb_array_elements_text(${sql.json(roles(b) ?? [])}::jsonb)))`;
  if (main) await setMain(sql, companyId, contactId);
  return c.json({ ok: true }, 201);
});

customersWrite.patch('/companies/:id/contacts/:contactId', async (c) => {
  const companyId = id(c.req.param('id'));
  const contactId = id(c.req.param('contactId'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const r = roles(b);
  const main = bool(b, 'is_main_contact', 'Hlavný kontakt');
  if (main !== undefined && (await team(sql, c.var.userId)) === 'servis') throw new Forbidden('Hlavný kontakt firmy Servis nemení.');
  if (r !== undefined) {
    const rows = await sql`
      UPDATE company_contact SET roles = ARRAY(SELECT jsonb_array_elements_text(${sql.json(r)}::jsonb))
       WHERE company_id = ${companyId} AND contact_id = ${contactId} RETURNING id`;
    if (rows.length === 0) return c.json({ error: 'Osoba nie je vo firme alebo ju nemôžete upravovať.' }, 403);
  }
  if (main === true) await setMain(sql, companyId, contactId);
  if (main === false) {
    await sql`UPDATE company_contact SET is_main_contact = false WHERE company_id = ${companyId} AND contact_id = ${contactId}`;
  }
  return c.json({ ok: true });
});

customersWrite.delete('/companies/:id/contacts/:contactId', async (c) => {
  const companyId = id(c.req.param('id'));
  const contactId = id(c.req.param('contactId'));
  const rows = await c.var.sql`
    DELETE FROM company_contact WHERE company_id = ${companyId} AND contact_id = ${contactId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Osoba nie je vo firme alebo ju nemôžete odobrať.' }, 403);
  return c.json({ ok: true });
});

// „Nechce marketing“ (čl. 8): dátum a zdroj; zrušenie oboje vymaže.
const OPT_OUT_SOURCES = ['telefon', 'email', 'osobne', 'web', 'brevo', 'hubspot', 'ine'];

customersWrite.patch('/persons/:id/marketing', async (c) => {
  const personId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const optOut = bool(b, 'opt_out', 'Nechce marketing');
  if (optOut === undefined) throw new BadRequest('Chýba: Nechce marketing.');
  const source = optOut ? str(b, 'source', 'Zdroj', { max: 20 })! : null;
  if (source && !OPT_OUT_SOURCES.includes(source)) throw new BadRequest('Zdroj: neplatná hodnota.');
  const rows = await c.var.sql`
    UPDATE contact
       SET marketing_opt_out_at = CASE WHEN ${optOut} THEN coalesce(marketing_opt_out_at, now()) END,
           marketing_opt_out_source = ${source}
     WHERE id = ${personId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Osobu nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

// Poznámka na časovej osi (autor = prihlásený). Pridá ten, kto smie zákazníka upravovať.
async function addNote(sql: Sql, userId: string, kind: 'company' | 'person', recordId: string, text: string) {
  const [ok] = await sql<{ ok: boolean }[]>`
    SELECT ${kind === 'company'} AND crm_company_access(${recordId}, 'edit')
        OR ${kind === 'person'} AND crm_contact_access(${recordId}, 'edit') AS ok`;
  if (!ok?.ok) throw new Forbidden('Poznámku môže pridať iba ten, kto smie zákazníka upravovať.');
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO activity (type, company_id, contact_id, user_id, occurred_at, body, source)
    VALUES ('poznamka', ${kind === 'company' ? recordId : null}, ${kind === 'person' ? recordId : null},
            ${userId}, now(), ${text}, 'crm')
    RETURNING id`;
  return row.id;
}

for (const [path, kind] of [['companies', 'company'], ['persons', 'person']] as const) {
  customersWrite.post(`/${path}/:id/notes`, async (c) => {
    const recordId = id(c.req.param('id'));
    const b = await readBody(c.req);
    const text = str(b, 'text', 'Text poznámky', { max: 5000 })!;
    return c.json({ id: await addNote(c.var.sql, c.var.userId, kind, recordId, text) }, 201);
  });
}

// ============================================================================
// F3: vlastné polia na kartách
// ============================================================================

// Definície polí pre karty a zoznamy (nie Nastavenia): aj archivované – ich hodnoty sa zobrazujú.
// can_edit = smie prihlásený pole meniť (tímy poľa); platí aj v databáze.
customersWrite.get('/custom-fields', async (c) => {
  const entities = (c.req.query('entity') ?? 'firma').split(',');
  if (entities.some((e) => !['firma', 'osoba', 'oom', 'deal', 'zmluva', 'ponuka'].includes(e))) {
    throw new BadRequest('Neznámy záznam.');
  }
  const sql = c.var.sql;
  const fields = await sql`
    SELECT f.id, f.entity, f.key, f.label, f.field_type, f.ref_entity, f.section_id, s.name AS section_name,
           s.sort_order AS section_order, f.sort_order, f.is_required, f.show_in_list, f.filterable, f.org_id,
           f.archived_at, crm_can_edit_field(f) AS can_edit,
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'label', o.label, 'hidden_at', o.hidden_at)
                                     ORDER BY o.sort_order, lower(o.label))
                       FROM custom_field_option o WHERE o.field_id = f.id), '[]') AS options
      FROM custom_field f
      LEFT JOIN custom_field_section s ON s.id = f.section_id
     WHERE f.entity::text IN (SELECT jsonb_array_elements_text(${sql.json(entities)}::jsonb))
     ORDER BY s.sort_order NULLS FIRST, f.sort_order, lower(f.label)`;
  return c.json({ items: fields });
});

// Hodnoty: { values: { kľúč: hodnota | null } } – null pole vymaže; ostatné kľúče sa nemenia.
function customPatch(b: Body): { set: Record<string, unknown>; remove: string[] } {
  const v = b.values;
  if (!v || typeof v !== 'object' || Array.isArray(v)) throw new BadRequest('Chýbajú hodnoty polí.');
  const set: Record<string, unknown> = {};
  const remove: string[] = [];
  for (const [k, x] of Object.entries(v as Record<string, unknown>)) {
    if (!/^[a-z][a-z0-9_]{1,62}$/.test(k)) throw new BadRequest('Neznáme pole.');
    if (x === null || x === '' || (Array.isArray(x) && x.length === 0)) remove.push(k);
    else set[k] = x;
  }
  return { set, remove };
}

// OOM (modul Odberné miesta, F3): pri Aktívnom OOM iba s právom „upravovať Aktívne OOM“ (databáza, 0015).
for (const [path, table] of [['companies', 'company'], ['persons', 'contact'], ['oom', 'oom']] as const) {
  customersWrite.patch(`/${path}/:id/custom`, async (c) => {
    const recordId = id(c.req.param('id'));
    const sql = c.var.sql;
    if (table === 'company' && (await team(sql, c.var.userId)) === 'servis') {
      throw new Forbidden('Servis nemení údaje firmy.');
    }
    const { set, remove } = customPatch(await readBody(c.req));
    const rows = await sql`
      UPDATE ${sql(table)}
         SET custom = (custom || ${sql.json(set as Record<string, never>)}::jsonb)
                      - ARRAY(SELECT jsonb_array_elements_text(${sql.json(remove)}::jsonb))
       WHERE id = ${recordId} RETURNING id`;
    if (rows.length === 0) return c.json({ error: 'Záznam nemôžete upravovať alebo neexistuje.' }, 403);
    return c.json({ ok: true });
  });
}
