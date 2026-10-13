// Modul 3 Produkty a cenníky, F1 – iba čítanie (obrazovky 20–23; zadanie 03-produkty.md čl. 11).
// Ceny s DPH, stavy verzií (Europe/Bratislava) a viditeľnosť (Návrh iba admin, spoločnosť) určuje databáza
// (pohľady price_list_*_v, RLS z 0019/0020); API ich iba číta a nič neprepočítava.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest } from '../validate';

export const priceLists = new Hono<AppEnv>();

const notFound = { error: 'Záznam neexistuje.' } as const;

/** Sadzby produktu podľa rozsahu PDS s názvami z číselníka (napr. DMP4: spoločné C4, ZSD C2-X3, VSD X3-C2). */
export function tariffs(sql: Sql) {
  return sql`
    WITH lab AS (
      SELECT DISTINCT ON (tariff_base(code, parent_code)) tariff_base(code, parent_code) AS base, label, sort_order
        FROM lookup_value
       WHERE list_code = 'sadzba_distribucie'
       ORDER BY tariff_base(code, parent_code), sort_order, label)
    SELECT t.product_id,
           json_agg(json_build_object('scope', t.scope_code, 'label', coalesce(lab.label, t.tariff_code))
                    ORDER BY s.sort_order, lab.sort_order NULLS LAST, t.tariff_code) AS tariffs
      FROM product_tariff t
      JOIN tariff_scope s ON s.code = t.scope_code
      LEFT JOIN lab ON lab.base = t.tariff_code
     GROUP BY t.product_id`;
}

// Obrazovka 20: cenníky s platnou a budúcou verziou (adminovi aj Návrh) a produktmi platnej verzie.
priceLists.get('/price-lists', async (c) => {
  const sql = c.var.sql;
  const items = await sql`
    SELECT l.id, l.code, l.name, l.segment, l.description,
           l.current_version_id, l.current_version_name, l.current_valid_from, l.current_valid_to,
           l.future_version_id, l.future_version_name, l.future_valid_from,
           l.draft_version_id, l.draft_version_name, l.draft_valid_from,
           coalesce((SELECT json_agg(i.product_name ORDER BY i.sort_order, i.product_name)
                       FROM price_list_item_v i WHERE i.version_id = l.current_version_id), '[]') AS products
      FROM price_list_current_v l
     ORDER BY l.sort_order, l.name`;
  return c.json({ items });
});

// Obrazovka 21: detail cenníka a zvolenej verzie (?version=; bez neho platná, inak najbližšia budúca, inak posledná).
// Verzia, ktorú používateľ nevidí (Návrh pre ne-admina) alebo patrí inému cenníku → 404.
priceLists.get('/price-lists/:id', async (c) => {
  const id = c.req.param('id');
  const version = c.req.query('version') ?? '';
  if (!UUID.test(id) || (version !== '' && !UUID.test(version))) throw new BadRequest('Neplatné ID.');
  const detail = await priceListDetail(c.var.sql, id, version || null);
  return detail ? c.json(detail) : c.json(notFound, 404);
});

/** Detail cenníka so zvolenou verziou (null = cenník alebo verzia neexistuje / nie je viditeľná). Používa aj F2. */
export async function priceListDetail(sql: Sql, id: string, version: string | null) {
  const [list] = await sql<{ id: string; code: string; name: string; segment: string; description: string | null; org_id: string }[]>`
    SELECT id, code, name, segment, description, org_id FROM price_list WHERE id = ${id}`;
  if (!list) return null;

  const versions = await sql<{ id: string; state: string; valid_from: string }[]>`
    SELECT id, name, valid_from, valid_to, status, state, copied_from_id, note, approved_at, approved_by_name, item_count,
           updated_at
      FROM price_list_version_v
     WHERE price_list_id = ${id}
     ORDER BY (status = 'navrh') DESC, valid_from DESC, created_at DESC`;
  let selected: string | undefined;
  if (version) {
    selected = versions.find((v) => v.id === version)?.id;
    if (!selected) return null;
  } else {
    selected =
      versions.find((v) => v.state === 'platna')?.id ??
      [...versions].filter((v) => v.state === 'buduca').sort((a, b) => (a.valid_from < b.valid_from ? -1 : 1))[0]?.id ??
      versions.find((v) => v.state !== 'navrh')?.id ??
      versions[0]?.id;
  }

  const items = selected
    ? await sql`
        SELECT i.id, i.product_id, i.product_code, i.product_name, i.category, i.tariff_type, i.product_status, i.sort_order,
               i.vat_rate, i.price_vt_eur_mwh, i.price_vt_with_vat, i.price_nt_eur_mwh, i.price_nt_with_vat,
               i.fee_oom_eur_month, i.fee_oom_with_vat, i.fee_program_eur_month, i.fee_program_with_vat,
               i.fee_kw_eur_month, i.fee_kw_with_vat,
               i.greencar, i.greencar_kwh_per_voucher, i.greencar_voucher_eur, i.greenshare, i.greenshare_fee_pct,
               i.viwa_conversion_factor, i.viwa_activation_bonus, i.viwa_credit_expiry_months,
               coalesce(t.tariffs, '[]') AS tariffs
          FROM price_list_item_v i
          LEFT JOIN (${tariffs(sql)}) t ON t.product_id = i.product_id
         WHERE i.version_id = ${selected}
         ORDER BY i.sort_order, i.product_name`
    : [];
  return { ...list, versions, selected_version_id: selected ?? null, items };
}

// Obrazovka 22: katalóg produktov. ?skupina=dodavka|vykup|sluzby|instalacia, ?ukoncene=1 zobrazí aj ukončené.
const GROUPS: Record<string, string[]> = {
  dodavka: ['dodavka_domacnost', 'dodavka_maly_podnik', 'dodavka_firma', 'velkoobchod'],
  vykup: ['vykup_firma'],
  sluzby: ['zem', 'vbattery', 'viwa', 'poplatok'],
  instalacia: ['instalacia_fve'],
};

priceLists.get('/products', async (c) => {
  const sql = c.var.sql;
  const group = c.req.query('skupina') ?? '';
  const ended = c.req.query('ukoncene') === '1';
  if (group !== '' && !GROUPS[group]) throw new BadRequest('Neplatná skupina.');
  const rows = await sql<{ category: string; status: string }[]>`
    SELECT p.id, p.code, p.name, p.category, p.segment, p.vat_rate, p.tariff_type, to_json(p.price_models) AS price_models, p.price_regulation,
           p.status, coalesce(t.tariffs, '[]') AS tariffs
      FROM product p
      LEFT JOIN (${tariffs(sql)}) t ON t.product_id = p.id
     ORDER BY p.sort_order, p.name`;
  const visible = rows.filter((p) => ended || p.status !== 'ukonceny');
  const counts: Record<string, number> = { vsetky: visible.length };
  for (const [g, cats] of Object.entries(GROUPS)) counts[g] = visible.filter((p) => cats.includes(p.category)).length;
  const items = group === '' ? visible : visible.filter((p) => GROUPS[group].includes(p.category));
  return c.json({ items, counts, ended_count: rows.filter((p) => p.status === 'ukonceny').length });
});

// Obrazovka 23: programy VBattery a VIWA z platných verzií cenníkov + produkty bez platnej ceny (napr. AKU – dobieha).
priceLists.get('/programs', async (c) => {
  const sql = c.var.sql;
  const rows = await sql`
    SELECT p.id AS product_id, p.code, p.name, p.category, p.status, p.sort_order,
           l.name AS price_list_name, l.current_version_name AS version_name, l.current_valid_from AS valid_from,
           i.vat_rate, i.fee_program_eur_month, i.fee_program_with_vat, i.fee_kw_eur_month, i.fee_kw_with_vat,
           i.greencar, i.greencar_kwh_per_voucher, i.greencar_voucher_eur, i.greenshare, i.greenshare_fee_pct,
           i.viwa_conversion_factor, i.viwa_activation_bonus, i.viwa_credit_expiry_months
      FROM product p
      LEFT JOIN price_list_current_v l
             ON EXISTS (SELECT 1 FROM price_list_item x WHERE x.version_id = l.current_version_id AND x.product_id = p.id)
      LEFT JOIN price_list_item_v i ON i.version_id = l.current_version_id AND i.product_id = p.id
     WHERE p.category IN ('vbattery', 'viwa') AND p.status <> 'ukonceny'
     ORDER BY p.sort_order, p.name`;
  return c.json({
    vbattery: rows.filter((r) => r.category === 'vbattery'),
    viwa: rows.filter((r) => r.category === 'viwa'),
  });
});
