// Modul 3 Produkty a cenníky, F3 – produkty a párovanie sadzieb (plán F3 schválený Petrom 13. 10. 2026).
// Zápis iba admin; pravidlá stráži databáza (0019, 0022): produkt sa nemaže, kód a spoločnosť sa nemenia, použitý
// produkt nemení kategóriu, segment, typ tarifu, reguláciu ani model „cenník“; párovanie iba na sadzby z číselníka.
// Súbežná úprava: PATCH produktu a PUT párovania posielajú updated_at produktu, ktorý admin videl (inak 409).
// Rozsahy PDS sa v F3 iba zobrazujú (nový rozsah = migrácia).

import { Hono } from 'hono';
import type postgres from 'postgres';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody, str, type Body } from '../validate';
import { codeFromName } from './pricelists-write';

export const productsWrite = new Hono<AppEnv>();

const STALE = { error: 'Produkt medzitým upravil niekto iný, obnovte stránku.', code: 'stale' } as const;
const notFound = { error: 'Záznam neexistuje.' } as const;

const CATEGORIES = ['dodavka_domacnost', 'dodavka_maly_podnik', 'dodavka_firma', 'vykup_firma', 'velkoobchod', 'zem', 'vbattery', 'viwa', 'instalacia_fve', 'poplatok'] as const;
const MODELS = ['cennik', 'fix', 'spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct', 'cena_diela'] as const;
const TARIFFS = ['jednotarif', 'dvojtarif', 'nemerany', 'netyka_sa'] as const;
const STATUSES = ['predava_sa', 'dobieha', 'ukonceny'] as const;
/** Kategórie, ktoré sa viažu na sadzby distribúcie (obrazovka 24, odpoveď 5). */
export const MAPPED_CATEGORIES = ['dodavka_domacnost', 'dodavka_maly_podnik', 'zem'];

async function requireAdmin(sql: Sql) {
  const [r] = await sql<{ ok: boolean }[]>`SELECT crm_is_admin() AS ok`;
  if (!r?.ok) throw new Forbidden('Produkty a párovanie spravuje iba admin.');
}

const pick = <T extends string>(v: unknown, values: readonly T[], label: string): T => {
  if (typeof v !== 'string' || !values.includes(v as T)) throw new BadRequest(`${label}: neplatná hodnota.`);
  return v as T;
};

function vat(v: unknown): string | null {
  if (v === null || v === undefined || v === '') return null;
  const s = String(v).replace(/\s/g, '').replace(',', '.');
  if (!/^\d{1,3}(\.\d{1,2})?$/.test(s) || Number(s) > 100) throw new BadRequest('DPH: 0 až 100 %, najviac 2 desatinné miesta.');
  return s;
}

/** Hodnoty produktu z tela (iba poslané polia). */
function productValues(b: Body) {
  const out: Record<string, unknown> = {};
  if (b.name !== undefined) out.name = str(b, 'name', 'Názov', { max: 120 });
  if (b.category !== undefined) out.category = pick(b.category, CATEGORIES, 'Kategória');
  if (b.segment !== undefined) out.segment = pick(b.segment, ['domacnost', 'firma'] as const, 'Segment');
  if (b.vat_rate !== undefined) out.vat_rate = vat(b.vat_rate);
  if (b.tariff_type !== undefined) out.tariff_type = pick(b.tariff_type, TARIFFS, 'Typ tarifu');
  // variant tarifu (0023): vykurovanie (dvojtarif), verejné osvetlenie (jednotarif); null = bez variantu
  if (b.tariff_variant !== undefined) {
    out.tariff_variant = b.tariff_variant === null || b.tariff_variant === ''
      ? null
      : pick(b.tariff_variant, ['vykurovanie', 'verejne_osvetlenie'] as const, 'Variant tarifu');
  }
  if (b.price_models !== undefined) {
    if (!Array.isArray(b.price_models) || b.price_models.length === 0) throw new BadRequest('Cenové modely: vyberte aspoň jeden.');
    // text poľa {cennik,fix} (hodnoty iba z pevného zoznamu) – ovládač pole enumov inak nepošle správne
    out.price_models = `{${[...new Set(b.price_models.map((m) => pick(m, MODELS, 'Cenový model')))].join(',')}}`;
  }
  if (b.price_regulation !== undefined) {
    if (b.price_regulation !== null && typeof b.price_regulation !== 'boolean') throw new BadRequest('Cenová regulácia: ANO, NIE alebo nezáleží.');
    out.price_regulation = b.price_regulation;
  }
  if (b.status !== undefined) out.status = pick(b.status, STATUSES, 'Stav');
  if (b.sort_order !== undefined) {
    const n = Number(b.sort_order);
    if (!Number.isInteger(n) || n < 0 || n > 100000) throw new BadRequest('Poradie: celé číslo.');
    out.sort_order = n;
  }
  return out;
}

async function lockProduct(sql: Sql, pid: string, b: Body): Promise<'ok' | 'stale' | 'missing'> {
  if (typeof b.updated_at !== 'string' || Number.isNaN(Date.parse(b.updated_at))) {
    throw new BadRequest('Chýba čas poslednej zmeny produktu (obnovte stránku).');
  }
  const [p] = await sql<{ same: boolean }[]>`
    SELECT date_trunc('milliseconds', updated_at) = date_trunc('milliseconds', ${b.updated_at}::timestamptz) AS same
      FROM product WHERE id = ${pid} FOR UPDATE`;
  if (!p) return 'missing';
  return p.same ? 'ok' : 'stale';
}

const CAST: Record<string, string> = {
  name: 'text', category: 'product_category', segment: 'customer_segment', vat_rate: 'numeric', tariff_type: 'tariff_type',
  tariff_variant: 'text',
  price_models: 'price_model[]', price_regulation: 'boolean', status: 'product_status', sort_order: 'integer',
};

// Nový produkt: kód z názvu (skrytý, nemenný, pri zhode poradové číslo).
productsWrite.post('/products', async (c) => {
  const sql = c.var.sql;
  await requireAdmin(sql);
  const b = await readBody(c.req);
  const v = productValues(b);
  for (const k of ['name', 'category', 'segment', 'tariff_type', 'price_models'] as const) {
    if (v[k] === undefined) throw new BadRequest('Vyplňte názov, kategóriu, segment, typ tarifu a cenové modely.');
  }
  const org = b.org === undefined ? null : String(b.org);
  if (org !== null && !UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  const base = codeFromName(String(v.name));
  const tx = sql as unknown as postgres.TransactionSql;
  for (let n = 1; n <= 50; n++) {
    const code = n === 1 ? base : `${base}_${n}`;
    try {
      const [row] = await tx.savepoint((sp) => sp<{ id: string }[]>`
        INSERT INTO product (org_id, code, name, category, segment, vat_rate, tariff_type, tariff_variant, price_models,
                             price_regulation, status, sort_order)
        VALUES (coalesce(${org}::uuid, crm_default_org()), ${code}, ${v.name as string}, ${v.category as string}::product_category,
                ${v.segment as string}::customer_segment, ${(v.vat_rate as string | null) ?? null}::numeric,
                ${v.tariff_type as string}::tariff_type, ${(v.tariff_variant as string | null | undefined) ?? null}::text,
                ${v.price_models as string}::price_model[],
                ${(v.price_regulation as boolean | null | undefined) ?? null}::boolean,
                coalesce(${(v.status as string | undefined) ?? null}::product_status, 'predava_sa'),
                coalesce(${(v.sort_order as number | undefined) ?? null}::integer,
                         (SELECT coalesce(max(sort_order), 0) + 1 FROM product)))
        RETURNING id`);
      return c.json({ id: row.id }, 201);
    } catch (err) {
      if ((err as { constraint_name?: string }).constraint_name !== 'product_code_key') throw err;
    }
  }
  throw new BadRequest('Nepodarilo sa vytvoriť kód produktu, zmeňte názov.');
});

// Úprava produktu (iba poslané polia) a stavu; mazanie nie je.
productsWrite.patch('/products/:id', async (c) => {
  const sql = c.var.sql;
  await requireAdmin(sql);
  const pid = c.req.param('id');
  if (!UUID.test(pid)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const v = productValues(b);
  const lock = await lockProduct(sql, pid, b);
  if (lock === 'missing') return c.json(notFound, 404);
  if (lock === 'stale') return c.json(STALE, 409);
  const cols = Object.keys(v);
  if (cols.length === 0) return c.json({ ok: true });
  const sets = cols
    .map((k) => sql`${sql(k)} = ${v[k] as never}::${sql.unsafe(CAST[k])}`)
    .reduce((acc, f) => sql`${acc}, ${f}`);
  await sql`UPDATE product SET ${sets} WHERE id = ${pid}`;
  return c.json({ ok: true });
});

// Obrazovka 24: rozsahy PDS, sadzby na výber ku každému rozsahu, produkty viazané na sadzby a ich párovanie.
productsWrite.get('/tariff-mapping', async (c) => {
  const sql = c.var.sql;
  await requireAdmin(sql);
  const [scopes, options, products] = await Promise.all([
    sql`SELECT code, name, pds_code FROM tariff_scope ORDER BY sort_order, name`,
    // sadzby z číselníka podľa rozsahu: PDS s vlastným rozsahom – jeho sadzby; spoločný – sadzby PDS bez vlastného rozsahu
    sql`
      SELECT s.code AS scope, x.base AS code, min(x.label) AS label, min(x.sort_order) AS sort_order
        FROM tariff_scope s
        JOIN LATERAL (
          SELECT tariff_base(v.code, v.parent_code) AS base, v.label, v.sort_order
            FROM lookup_value v
           WHERE v.list_code = 'sadzba_distribucie' AND v.hidden_at IS NULL
             AND CASE WHEN s.pds_code IS NOT NULL THEN v.parent_code = s.pds_code
                      ELSE v.parent_code NOT IN (SELECT pds_code FROM tariff_scope WHERE pds_code IS NOT NULL) END) x ON true
       GROUP BY s.code, x.base
       ORDER BY s.code, min(x.sort_order), min(x.label)`,
    sql`
      SELECT p.id, p.code, p.name, p.category, p.status, p.tariff_type, p.price_regulation, p.sort_order, p.updated_at,
             coalesce((SELECT json_agg(json_build_object('scope', t.scope_code, 'code', t.tariff_code) ORDER BY t.scope_code, t.tariff_code)
                         FROM product_tariff t WHERE t.product_id = p.id), '[]') AS tariffs
        FROM product p
       WHERE (p.category IN ${sql(MAPPED_CATEGORIES)} AND p.status <> 'ukonceny')
          OR EXISTS (SELECT 1 FROM product_tariff t WHERE t.product_id = p.id)
       ORDER BY p.sort_order, p.name`,
  ]);
  return c.json({ scopes, options, products });
});

// Párovanie jedného produktu vo všetkých rozsahoch naraz: { updated_at, tariffs: { zsd: ['d1'], vsd: [...], spolocne: [...] } }.
productsWrite.put('/products/:id/tariffs', async (c) => {
  const sql = c.var.sql;
  await requireAdmin(sql);
  const pid = c.req.param('id');
  if (!UUID.test(pid)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const t = b.tariffs;
  if (!t || typeof t !== 'object' || Array.isArray(t)) throw new BadRequest('Párovanie: očakávaný objekt podľa rozsahov.');
  const scopes = (await sql<{ code: string }[]>`SELECT code FROM tariff_scope`).map((r) => r.code);
  const wanted: [string, string][] = [];
  for (const [scope, codes] of Object.entries(t as Record<string, unknown>)) {
    if (!scopes.includes(scope)) throw new BadRequest(`Neznámy rozsah PDS „${scope}“.`);
    if (!Array.isArray(codes) || codes.some((x) => typeof x !== 'string' || !/^[a-z0-9_]{1,40}$/.test(x))) {
      throw new BadRequest('Párovanie: neplatný kód sadzby.');
    }
    for (const code of new Set(codes as string[])) wanted.push([scope, code]);
  }
  const lock = await lockProduct(sql, pid, b);
  if (lock === 'missing') return c.json(notFound, 404);
  if (lock === 'stale') return c.json(STALE, 409);

  const current = await sql<{ id: string; scope_code: string; tariff_code: string }[]>`
    SELECT id, scope_code, tariff_code FROM product_tariff WHERE product_id = ${pid}`;
  const key = (s: string, x: string) => `${s}/${x}`;
  const want = new Set(wanted.map(([s, x]) => key(s, x)));
  const have = new Set(current.map((r) => key(r.scope_code, r.tariff_code)));
  for (const r of current) if (!want.has(key(r.scope_code, r.tariff_code))) await sql`DELETE FROM product_tariff WHERE id = ${r.id}`;
  for (const [s, x] of wanted) {
    if (!have.has(key(s, x))) await sql`INSERT INTO product_tariff (product_id, scope_code, tariff_code) VALUES (${pid}, ${s}, ${x})`;
  }
  // posunie čas poslednej zmeny produktu (súbežná úprava párovania sa spozná)
  await sql`UPDATE product SET sort_order = sort_order WHERE id = ${pid}`;
  const [p] = await sql<{ updated_at: string }[]>`SELECT updated_at FROM product WHERE id = ${pid}`;
  return c.json({ ok: true, updated_at: p.updated_at });
});

// Ukážka „čo CRM ponúkne“ (product_candidates_by, 0022): ?pds=zsd&sadzba=zsd_c2_x3&segment=firma&regulacia=ano|nie|&nt=1
productsWrite.get('/tariff-mapping/preview', async (c) => {
  const sql = c.var.sql;
  await requireAdmin(sql);
  const pds = c.req.query('pds') ?? '';
  const tariff = c.req.query('sadzba') ?? '';
  const segment = c.req.query('segment') ?? '';
  const reg = c.req.query('regulacia') ?? '';
  if (!/^[a-z0-9_]{1,63}$/.test(pds) || !/^[a-z0-9_]{1,63}$/.test(tariff)) throw new BadRequest('Vyberte PDS a sadzbu.');
  if (segment !== 'domacnost' && segment !== 'firma') throw new BadRequest('Segment: domácnosť alebo firma.');
  if (!['ano', 'nie', ''].includes(reg)) throw new BadRequest('Cenová regulácia: ano, nie alebo prázdne.');
  const items = await sql`
    SELECT c.product_id, p.name, c.rank, c.is_only, c.is_addon
      FROM product_candidates_by(crm_default_org(), ${segment}::customer_segment, ${pds}, ${tariff},
                                 ${reg === '' ? null : reg === 'ano'}::boolean, ${c.req.query('nt') === '1'}) c
      JOIN product p ON p.id = c.product_id
     ORDER BY c.is_addon, c.rank, p.sort_order, p.name`;
  return c.json({ items });
});
