// Modul 4 Zmluvy, F1a – Nastavenia → Preklady importov (migrácia 0023, rozhodnutie 2026-10-13).
// Názov z importu Office portálu / XM Trade → hodnota CRM. Iba admin (kontrola v settings.ts aj RLS).
// Databáza overí, že cieľ existuje; systémové preklady sa nemažú ani nemenia, iba skryjú.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, bool, oneOf, readBody, str } from '../validate';

export const importAliases = new Hono<AppEnv>();

export const ALIAS_SOURCES = ['office_portal', 'xm_trade', 'vsetky'] as const;
export const ALIAS_KINDS = [
  'produkt_op', 'produkt_oom', 'sadzba', 'pds', 'obchodnik', 'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'iny',
] as const;

const PRICE_MODELS = [
  { value: 'fix', label: 'FIX' },
  { value: 'spot_plus_eur', label: 'SPOT + aditív €' },
  { value: 'spot_minus_eur', label: 'Výkup SPOT − aditív €' },
  { value: 'spot_minus_pct', label: 'Výkup SPOT − aditív %' },
  { value: 'cennik', label: 'Cenník' },
];

importAliases.get('/import-aliases', async (c) => {
  const sql = c.var.sql;
  const items = await sql`
    SELECT a.id, a.org_id, a.source, a.kind, a.name_sample, a.name_norm, a.target, a.target_extra, a.is_system,
           a.hidden_at, a.created_at, u.name AS created_by_name
      FROM import_alias a
      LEFT JOIN app_user u ON u.id = a.created_by
     WHERE a.org_id = ANY (crm_user_orgs())
     ORDER BY a.kind, a.hidden_at IS NOT NULL, lower(a.name_sample)`;
  // Cieľové hodnoty podľa druhu (sadzba = kód bez PDS, ako pri párovaní produktov)
  const tariffs = await sql`
    SELECT DISTINCT ON (substr(v.code, length(v.parent_code) + 2))
           substr(v.code, length(v.parent_code) + 2) AS value, v.label
      FROM lookup_value v
     WHERE v.list_code = 'sadzba_distribucie' AND v.hidden_at IS NULL
     ORDER BY substr(v.code, length(v.parent_code) + 2), v.sort_order`;
  const lookups = await sql`
    SELECT list_code, code AS value, label FROM lookup_value
     WHERE list_code IN ('pds', 'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh') AND hidden_at IS NULL
     ORDER BY list_code, sort_order, label`;
  const products = await sql`
    SELECT code AS value, name AS label FROM product WHERE org_id = ANY (crm_user_orgs()) AND status <> 'ukonceny'
     ORDER BY sort_order, name`;
  const users = await sql`
    SELECT id::text AS value, name AS label FROM app_user WHERE status <> 'deaktivovany' ORDER BY lower(name)`;
  const byList = (code: string) => lookups.filter((l) => l.list_code === code).map(({ value, label }) => ({ value, label }));
  return c.json({
    items,
    targets: {
      produkt_op: PRICE_MODELS,
      produkt_oom: products,
      sadzba: tariffs,
      pds: byList('pds'),
      obchodnik: users,
      typ_merania: byList('typ_merania'),
      fakturacne_obdobie: byList('fakturacne_obdobie'),
      sposob_zaloh: byList('sposob_zaloh'),
      iny: [],
    },
  });
});

importAliases.post('/import-aliases', async (c) => {
  const b = await readBody(c.req);
  const source = oneOf(b, 'source', 'Zdroj', ALIAS_SOURCES)!;
  const kind = oneOf(b, 'kind', 'Druh', ALIAS_KINDS)!;
  if (!source || !kind) throw new BadRequest('Chýba zdroj alebo druh prekladu.');
  const name = str(b, 'name_sample', 'Názov z importu', { max: 200 })!;
  const target = str(b, 'target', 'Hodnota v CRM', { max: 100 })!;
  const [row] = await c.var.sql<{ id: string }[]>`
    INSERT INTO import_alias (org_id, source, kind, name_sample, target)
    VALUES (crm_default_org(), ${source}, ${kind}, ${name}, ${target})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Skryť / obnoviť (aj systémový); zmeniť cieľ iba nesystémového (databáza)
importAliases.patch('/import-aliases/:id', async (c) => {
  const aid = c.req.param('id');
  if (!UUID.test(aid)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const hidden = bool(b, 'hidden', 'Skryť');
  const target = 'target' in b ? str(b, 'target', 'Hodnota v CRM', { max: 100 }) : undefined;
  const rows = await c.var.sql`
    UPDATE import_alias
       SET hidden_at = CASE WHEN ${hidden === undefined} THEN hidden_at
                            WHEN ${hidden ?? false} THEN coalesce(hidden_at, now()) ELSE NULL END,
           target = coalesce(${target ?? null}, target)
     WHERE id = ${aid}
    RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Záznam neexistuje.' }, 404);
  return c.json({ ok: true });
});

importAliases.delete('/import-aliases/:id', async (c) => {
  const aid = c.req.param('id');
  if (!UUID.test(aid)) throw new BadRequest('Neplatné ID.');
  const rows = await c.var.sql`DELETE FROM import_alias WHERE id = ${aid} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Záznam neexistuje.' }, 404);
  return c.json({ ok: true });
});
