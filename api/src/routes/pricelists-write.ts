// Modul 3 Produkty a cenníky, F2 – úpravy cenníkov adminom (plán F2 schválený Petrom 13. 10. 2026).
// Pravidlá stráži databáza (0020/0021): iba admin, schválená verzia sa nemení, jeden návrh na cenník, účinnosť od dnes
// (Europe/Bratislava), uzavretie a nahradenie. API iba skontroluje tvar údajov a súbežnú úpravu návrhu:
// PATCH verzie, PUT položiek a schválenie pošlú updated_at návrhu, ktorý admin videl; ak sa medzitým zmenil → 409.
// Ceny: nezáporné, najviac 4 desatinné miesta (viac sa odmietne – databáza by zaokrúhlila), čiarka aj bodka.

import { Hono } from 'hono';
import type postgres from 'postgres';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody, str, type Body } from '../validate';
import { type Cell, xlsxBook } from '../xlsx';
import { priceListDetail } from './pricelists';

export const priceListsWrite = new Hono<AppEnv>();

const STALE = { error: 'Návrh medzitým upravil niekto iný, obnovte stránku.', code: 'stale' } as const;
const notFound = { error: 'Záznam neexistuje.' } as const;

async function requireWriter(sql: Sql) {
  const [r] = await sql<{ ok: boolean }[]>`SELECT crm_price_list_writer() AS ok`;
  if (!r?.ok) throw new Forbidden('Cenníky spravuje iba admin.');
}

function id(v: string, label = 'ID'): string {
  if (!UUID.test(v)) throw new BadRequest(`Neplatné ${label}.`);
  return v;
}

/** Cena: null/'' = bez ceny; inak nezáporné číslo s najviac 4 desatinnými miestami (text, bez prevodu na float). */
export function price(v: unknown, label: string): string | null {
  if (v === null || v === undefined || v === '') return null;
  const s = (typeof v === 'number' ? String(v) : typeof v === 'string' ? v : '').replace(/[\s ]/g, '').replace(',', '.');
  if (!/^\d+(\.\d+)?$/.test(s)) throw new BadRequest(`${label}: neplatné číslo (iba nezáporné, desatinná čiarka).`);
  if ((s.split('.')[1] ?? '').length > 4) throw new BadRequest(`${label}: najviac 4 desatinné miesta.`);
  if (s.replace('.', '').replace(/^0+/, '').length > 12) throw new BadRequest(`${label}: číslo je príliš veľké.`);
  return s;
}

function int(v: unknown, label: string, min = 0): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(String(v).replace(/\s/g, ''));
  if (!Number.isInteger(n) || n < min || n > 1_000_000) throw new BadRequest(`${label}: celé číslo od ${min}.`);
  return n;
}

function day(v: unknown, label: string): string {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) throw new BadRequest(`${label}: dátum v tvare RRRR-MM-DD.`);
  const [y, m, d] = v.split('-').map(Number);
  const dt = new Date(Date.UTC(y, m - 1, d));
  if (dt.getUTCFullYear() !== y || dt.getUTCMonth() !== m - 1 || dt.getUTCDate() !== d) throw new BadRequest(`${label}: neplatný dátum.`);
  return v;
}

function seen(b: Body): string {
  if (typeof b.updated_at !== 'string' || Number.isNaN(Date.parse(b.updated_at))) {
    throw new BadRequest('Chýba čas poslednej zmeny návrhu (obnovte stránku).');
  }
  return b.updated_at;
}

/** Návrh zamknutý na zápis; false = medzitým ho niekto zmenil (porovnanie na milisekundy, ako ho videl web). */
async function lockDraft(sql: Sql, vid: string, updatedAt: string): Promise<'ok' | 'stale' | 'missing'> {
  const [v] = await sql<{ same: boolean }[]>`
    SELECT date_trunc('milliseconds', updated_at) = date_trunc('milliseconds', ${updatedAt}::timestamptz) AS same
      FROM price_list_version WHERE id = ${vid} FOR UPDATE`;
  if (!v) return 'missing';
  return v.same ? 'ok' : 'stale';
}

/** Kód cenníka z názvu: bez diakritiky a bez roka (rok patrí verzii); pri zhode poradové číslo. */
export function codeFromName(name: string): string {
  const base = name
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/\b(19|20)\d{2}\b/g, ' ')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 50)
    .replace(/_+$/, '');
  return /^[a-z][a-z0-9_]{1,}$/.test(base) ? base : `cennik_${base}`.replace(/_+$/, '');
}

// ---------------------------------------------------------------------------
// Cenník
// ---------------------------------------------------------------------------

priceListsWrite.post('/price-lists', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov', { max: 120 })!;
  const segment = b.segment;
  if (segment !== 'domacnost' && segment !== 'firma') throw new BadRequest('Segment: domácnosť alebo firma.');
  const description = str(b, 'description', 'Popis', { max: 300, optional: true }) || null;
  const org = b.org === undefined ? null : id(String(b.org), 'spoločnosť');
  const base = codeFromName(name);
  const tx = sql as unknown as postgres.TransactionSql;
  for (let n = 1; n <= 50; n++) {
    const code = n === 1 ? base : `${base}_${n}`;
    try {
      const [row] = await tx.savepoint((sp) => sp<{ id: string }[]>`
        INSERT INTO price_list (org_id, code, name, segment, description, sort_order)
        VALUES (coalesce(${org}::uuid, crm_default_org()), ${code}, ${name}, ${segment}, ${description},
                coalesce((SELECT max(sort_order) FROM price_list), 0) + 1)
        RETURNING id`);
      return c.json({ id: row.id }, 201);
    } catch (err) {
      if ((err as { constraint_name?: string }).constraint_name !== 'price_list_code_key') throw err;
    }
  }
  throw new BadRequest('Nepodarilo sa vytvoriť kód cenníka, zmeňte názov.');
});

priceListsWrite.patch('/price-lists/:id', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const lid = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = b.name === undefined ? undefined : str(b, 'name', 'Názov', { max: 120 });
  const description = b.description === undefined ? undefined : str(b, 'description', 'Popis', { max: 300, optional: true }) || null;
  const rows = await sql`
    UPDATE price_list
       SET name = coalesce(${name ?? null}, name),
           description = CASE WHEN ${description !== undefined} THEN ${description ?? null} ELSE description END
     WHERE id = ${lid} RETURNING id`;
  return rows.length ? c.json({ ok: true }) : c.json(notFound, 404);
});

priceListsWrite.delete('/price-lists/:id', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const rows = await sql`DELETE FROM price_list WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  return rows.length ? c.json({ ok: true }) : c.json(notFound, 404);
});

// ---------------------------------------------------------------------------
// Verzia
// ---------------------------------------------------------------------------

// Prvá (prázdna) verzia cenníka – Návrh.
priceListsWrite.post('/price-lists/:id/versions', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const lid = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov verzie', { max: 40 })!;
  const from = day(b.valid_from, 'Platná od');
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO price_list_version (price_list_id, name, valid_from)
    SELECT id, ${name}, ${from} FROM price_list WHERE id = ${lid}
    RETURNING id`;
  return row ? c.json({ id: row.id }, 201) : c.json(notFound, 404);
});

// Nová verzia kópiou; vráti aj vynechané ukončené produkty.
priceListsWrite.post('/price-list-versions/:vid/copy', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov verzie', { max: 40 })!;
  const from = day(b.valid_from, 'Platná od');
  const [r] = await sql<{ r: { version_id: string; skipped: string[] } }[]>`
    SELECT price_list_version_copy(${vid}, ${name}, ${from}) AS r`;
  return c.json({ id: r.r.version_id, skipped: r.r.skipped }, 201);
});

// Návrh: názov, platná od, poznámka (súbežná úprava → 409).
priceListsWrite.patch('/price-list-versions/:vid', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const b = await readBody(c.req);
  const lock = await lockDraft(sql, vid, seen(b));
  if (lock === 'missing') return c.json(notFound, 404);
  if (lock === 'stale') return c.json(STALE, 409);
  const name = b.name === undefined ? null : str(b, 'name', 'Názov verzie', { max: 40 })!;
  const from = b.valid_from === undefined ? null : day(b.valid_from, 'Platná od');
  const note = b.note === undefined ? undefined : str(b, 'note', 'Poznámka', { max: 500, optional: true }) || null;
  await sql`
    UPDATE price_list_version
       SET name = coalesce(${name}, name),
           valid_from = coalesce(${from}::date, valid_from),
           note = CASE WHEN ${note !== undefined} THEN ${note ?? null} ELSE note END
     WHERE id = ${vid}`;
  return c.json({ ok: true });
});

type ItemIn = {
  id: string | null;
  product_id: string;
  vt: string | null;
  nt: string | null;
  oom: string | null;
  program: string | null;
  kw: string | null;
  sort: number;
  params: null | {
    greencar: boolean;
    greencar_kwh_per_voucher: number | null;
    greencar_voucher_eur: string | null;
    greenshare: boolean;
    greenshare_fee_pct: string | null;
    viwa_conversion_factor: string | null;
    viwa_activation_bonus: number | null;
    viwa_credit_expiry_months: number | null;
  };
};

function itemsIn(b: Body): ItemIn[] {
  if (!Array.isArray(b.items) || b.items.length > 500) throw new BadRequest('Položky: očakávaný zoznam.');
  const out: ItemIn[] = [];
  b.items.forEach((x, i) => {
    if (!x || typeof x !== 'object') throw new BadRequest(`Položka ${i + 1}: neplatná.`);
    const r = x as Body;
    const n = typeof r.product_name === 'string' ? r.product_name : `Položka ${i + 1}`;
    const pid = typeof r.product_id === 'string' && UUID.test(r.product_id) ? r.product_id : null;
    if (!pid) throw new BadRequest(`${n}: chýba produkt.`);
    const p = r.program as Body | null | undefined;
    out.push({
      id: typeof r.id === 'string' && UUID.test(r.id) ? r.id : null,
      product_id: pid,
      vt: price(r.price_vt_eur_mwh, `${n} – VT`),
      nt: price(r.price_nt_eur_mwh, `${n} – NT`),
      oom: price(r.fee_oom_eur_month, `${n} – mesačná platba za OM`),
      program: price(r.fee_program_eur_month, `${n} – mesačný poplatok`),
      kw: price(r.fee_kw_eur_month, `${n} – €/kW`),
      sort: i + 1,
      params: p
        ? {
            greencar: p.greencar === true,
            greencar_kwh_per_voucher: int(p.greencar_kwh_per_voucher, `${n} – kWh za voucher`, 1),
            greencar_voucher_eur: price(p.greencar_voucher_eur, `${n} – hodnota voucheru`),
            greenshare: p.greenshare === true,
            greenshare_fee_pct: price(p.greenshare_fee_pct, `${n} – GreenShare %`),
            viwa_conversion_factor: price(p.viwa_conversion_factor, `${n} – konverzný kurz`),
            viwa_activation_bonus: int(p.viwa_activation_bonus, `${n} – aktivačný bonus`),
            viwa_credit_expiry_months: int(p.viwa_credit_expiry_months, `${n} – expirácia`, 1),
          }
        : null,
    });
  });
  const dup = out.find((x, i) => out.findIndex((y) => y.product_id === x.product_id) !== i);
  if (dup) throw new BadRequest('Produkt je vo verzii dvakrát.');
  return out;
}

// Uloženie celej tabuľky návrhu naraz (pridané, zmenené, odobraté položky a parametre programov); všetko alebo nič.
// Vráti nový detail – ceny s DPH z databázy.
priceListsWrite.put('/price-list-versions/:vid/items', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const b = await readBody(c.req);
  const items = itemsIn(b);
  const lock = await lockDraft(sql, vid, seen(b));
  if (lock === 'missing') return c.json(notFound, 404);
  if (lock === 'stale') return c.json(STALE, 409);

  const keep = items.map((x) => x.id).filter((x): x is string => x !== null);
  if (keep.length) await sql`DELETE FROM price_list_item WHERE version_id = ${vid} AND id NOT IN ${sql(keep)}`;
  else await sql`DELETE FROM price_list_item WHERE version_id = ${vid}`;
  for (const x of items) {
    const [row] = x.id
      ? await sql<{ id: string }[]>`
          UPDATE price_list_item
             SET product_id = ${x.product_id}, price_vt_eur_mwh = ${x.vt}::numeric, price_nt_eur_mwh = ${x.nt}::numeric,
                 fee_oom_eur_month = ${x.oom}::numeric, fee_program_eur_month = ${x.program}::numeric,
                 fee_kw_eur_month = ${x.kw}::numeric, sort_order = ${x.sort}
           WHERE id = ${x.id} AND version_id = ${vid}
          RETURNING id`
      : await sql<{ id: string }[]>`
          INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                                       fee_program_eur_month, fee_kw_eur_month, sort_order)
          VALUES (${vid}, ${x.product_id}, ${x.vt}::numeric, ${x.nt}::numeric, ${x.oom}::numeric, ${x.program}::numeric,
                  ${x.kw}::numeric, ${x.sort})
          RETURNING id`;
    if (!row) throw new BadRequest('Položka už vo verzii nie je – obnovte stránku.');
    if (x.params) {
      const p = x.params;
      await sql`
        INSERT INTO price_list_item_program (item_id, greencar, greencar_kwh_per_voucher, greencar_voucher_eur, greenshare,
                                             greenshare_fee_pct, viwa_conversion_factor, viwa_activation_bonus,
                                             viwa_credit_expiry_months)
        VALUES (${row.id}, ${p.greencar}, ${p.greencar_kwh_per_voucher}, ${p.greencar_voucher_eur}::numeric, ${p.greenshare},
                ${p.greenshare_fee_pct}::numeric, ${p.viwa_conversion_factor}::numeric, ${p.viwa_activation_bonus},
                ${p.viwa_credit_expiry_months})
        ON CONFLICT (item_id) DO UPDATE SET
          greencar = EXCLUDED.greencar, greencar_kwh_per_voucher = EXCLUDED.greencar_kwh_per_voucher,
          greencar_voucher_eur = EXCLUDED.greencar_voucher_eur, greenshare = EXCLUDED.greenshare,
          greenshare_fee_pct = EXCLUDED.greenshare_fee_pct, viwa_conversion_factor = EXCLUDED.viwa_conversion_factor,
          viwa_activation_bonus = EXCLUDED.viwa_activation_bonus, viwa_credit_expiry_months = EXCLUDED.viwa_credit_expiry_months`;
    } else {
      await sql`DELETE FROM price_list_item_program WHERE item_id = ${row.id}`;
    }
  }
  // posunie čas poslednej zmeny návrhu (aj keď sa zmenili iba položky) – súbežná úprava sa tak spozná
  await sql`UPDATE price_list_version SET note = note WHERE id = ${vid}`;
  const [v] = await sql<{ price_list_id: string }[]>`SELECT price_list_id FROM price_list_version WHERE id = ${vid}`;
  return c.json(await priceListDetail(sql, v.price_list_id, vid));
});

// Produkty, ktoré sa dajú pridať do návrhu (spoločnosť a segment cenníka, model cenník, nie ukončený, ešte nie vo verzii).
priceListsWrite.get('/price-list-versions/:vid/addable-products', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const items = await sql`
    SELECT p.id, p.name, p.category
      FROM price_list_version v
      JOIN price_list l ON l.id = v.price_list_id
      JOIN product p ON p.org_id = l.org_id AND p.segment = l.segment AND 'cennik' = ANY (p.price_models)
                    AND p.status <> 'ukonceny'
     WHERE v.id = ${vid}
       AND NOT EXISTS (SELECT 1 FROM price_list_item i WHERE i.version_id = v.id AND i.product_id = p.id)
     ORDER BY p.sort_order, p.name`;
  return c.json({ items });
});

priceListsWrite.get('/price-list-versions/:vid/approve-preview', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const [r] = await sql<{ r: unknown }[]>`SELECT price_list_version_approve_preview(${id(c.req.param('vid'))}) AS r`;
  return c.json(r.r);
});

priceListsWrite.post('/price-list-versions/:vid/approve', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const lock = await lockDraft(sql, vid, seen(await readBody(c.req)));
  if (lock === 'missing') return c.json(notFound, 404);
  if (lock === 'stale') return c.json(STALE, 409);
  await sql`SELECT price_list_version_approve(${vid})`;
  return c.json({ ok: true });
});

// Ukončenie cenníka bez nástupcu (posledná schválená verzia platí do zadaného dňa).
priceListsWrite.post('/price-list-versions/:vid/close', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  const vid = id(c.req.param('vid'));
  const to = day((await readBody(c.req)).valid_to, 'Platná do');
  await sql`SELECT price_list_version_close(${vid}, ${to}::date)`;
  return c.json({ ok: true });
});

priceListsWrite.delete('/price-list-versions/:vid', async (c) => {
  const sql = c.var.sql;
  await requireWriter(sql);
  await sql`SELECT price_list_version_delete(${id(c.req.param('vid'))})`;
  return c.json({ ok: true });
});

// ---------------------------------------------------------------------------
// Export verzie (.xlsx): schválenú ktokoľvek, kto ju vidí; Návrh iba admin (RLS) s výrazným označením.
// Bez export_log (verejný dokument, rozhodnutie 2026-10-13).
// ---------------------------------------------------------------------------

const num = (v: unknown): Cell => (v === null || v === undefined ? null : Number(v));

priceListsWrite.get('/price-list-versions/:vid/export', async (c) => {
  const sql = c.var.sql;
  const vid = id(c.req.param('vid'));
  const [v] = await sql<{ price_list_id: string; status: string; name: string }[]>`
    SELECT price_list_id, status, name FROM price_list_version WHERE id = ${vid}`;
  if (!v) return c.json(notFound, 404);
  const d = await priceListDetail(sql, v.price_list_id, vid);
  if (!d) return c.json(notFound, 404);
  const ver = d.versions.find((x) => x.id === vid) as unknown as {
    name: string; valid_from: string; valid_to: string | null; state: string; approved_at: string | null; approved_by_name: string | null;
  };
  const draft = v.status === 'navrh';
  const fmt = (s: string | null) => (s ? s.split('-').reverse().map(Number).join('. ') : '');
  const STATE: Record<string, string> = { navrh: 'Návrh', buduca: 'Budúca', platna: 'Platná', ukoncena: 'Ukončená' };
  const items = d.items as Record<string, unknown>[];
  const has = (k: string) => items.some((i) => i[k] !== null);
  const cols: [string, string, string][] = [
    ['fee_oom_eur_month', 'fee_oom_with_vat', 'Mesačná platba za OM [€]'],
    ['fee_program_eur_month', 'fee_program_with_vat', 'Mesačný poplatok [€]'],
    ['fee_kw_eur_month', 'fee_kw_with_vat', 'Poplatok za odchýlku [€/kW mesačne]'],
    ['price_vt_eur_mwh', 'price_vt_with_vat', 'VT [€/MWh]'],
    ['price_nt_eur_mwh', 'price_nt_with_vat', 'NT [€/MWh]'],
  ].filter(([k]) => has(k)) as [string, string, string][];
  const programs = items.some((i) => i.greencar !== null);
  const header = [
    'Produkt', 'DPH [%]',
    ...cols.flatMap(([, , t]) => [`${t} bez DPH`, `${t} s DPH`]),
    ...(programs ? ['GreenCar [kWh za voucher]', 'Voucher [€]', 'GreenShare [%]', 'Konverzný kurz (× SPOT)', 'Aktivačný bonus', 'Expirácia [mes.]'] : []),
  ];
  const rows: Cell[][] = items.map((i) => [
    String(i.product_name), num(i.vat_rate),
    ...cols.flatMap(([n, g]) => [num(i[n]), num(i[g])]),
    ...(programs
      ? [num(i.greencar_kwh_per_voucher), num(i.greencar_voucher_eur), num(i.greenshare_fee_pct), num(i.viwa_conversion_factor),
         num(i.viwa_activation_bonus), num(i.viwa_credit_expiry_months)]
      : []),
  ]);
  const title: Cell[][] = [
    ...(draft ? [['NÁVRH – neplatný cenník']] : []),
    [`${d.name} · verzia ${ver.name}`],
    [`Platnosť: ${ver.valid_to ? `${fmt(ver.valid_from)} – ${fmt(ver.valid_to)}` : `od ${fmt(ver.valid_from)}`} · stav: ${STATE[ver.state] ?? ver.state}`],
    ['Ceny bez DPH sú uložené na 4 desatinné miesta, ceny s DPH sú dopočítané podľa sadzby DPH produktu.'],
  ];
  const data = xlsxBook([{ name: draft ? 'NÁVRH' : 'Cenník', title, header, rows }]);
  const file = `cennik-${String(d.code).replace(/_/g, '-')}-${v.name.replace(/[^A-Za-z0-9]+/g, '-')}${draft ? '-NAVRH' : ''}.xlsx`;
  return new Response(data, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${file}"`,
      'Cache-Control': 'no-store',
    },
  });
});
