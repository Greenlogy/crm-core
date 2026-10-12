// Export zoznamov Zákazníci a Kontakty do .xlsx (rozhodnutie 2026-10-12): iba tímy s právom „exportovať“
// v module Zákazníci; každý export sa zapíše do export_log (kto, kedy, filter, počet riadkov – bez údajov).
// Filtre sú rovnaké ako v zozname; exportuje sa najviac MAX_ROWS riadkov.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { listContacts, ROLE_FILTER } from '../queries/contacts';
import { listCustomers, SEGMENT_FILTERS, STATUS_FILTERS } from '../queries/customers';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden } from '../validate';
import { type Cell, xlsx } from '../xlsx';

export const exportRoutes = new Hono<AppEnv>();

const MAX_ROWS = 10000;

const STATUS_LABEL: Record<string, string> = {
  marketingovy_kontakt: 'Marketingový kontakt',
  zaujemca: 'Záujemca',
  ponuka: 'Ponuka',
  cakajuci_zakaznik: 'Čakajúci zákazník',
  zakaznik: 'Zákazník',
  byvaly_zakaznik: 'Bývalý zákazník',
  zruseny_zakaznik: 'Zrušený zákazník',
};

type Def = { key: string; label: string; entity: string; field_type: string; options: { id: string; label: string }[] };

async function canExport(sql: Sql, userId: string): Promise<boolean> {
  const [r] = await sql<{ ok: boolean }[]>`
    SELECT p.can_export AS ok FROM app_user u JOIN team_permission p ON p.team_id = u.team_id AND p.module = 'zakaznici'
     WHERE u.id = ${userId} AND u.status = 'aktivny'`;
  return !!r?.ok;
}

// Vlastné polia „zobraziť v zozname“ idú aj do exportu.
async function listDefs(sql: Sql, entities: string[]): Promise<Def[]> {
  return sql<Def[]>`
    SELECT f.key, f.label, f.entity::text AS entity, f.field_type::text AS field_type,
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'label', o.label)) FROM custom_field_option o
                      WHERE o.field_id = f.id), '[]') AS options
      FROM custom_field f
     WHERE f.entity::text IN (SELECT jsonb_array_elements_text(${sql.json(entities)}::jsonb))
       AND f.show_in_list AND f.archived_at IS NULL
     ORDER BY f.sort_order, lower(f.label)`;
}

function customCell(d: Def, v: unknown): Cell {
  if (v === null || v === undefined) return null;
  const opt = (x: unknown) => d.options.find((o) => o.id === x)?.label ?? '';
  switch (d.field_type) {
    case 'ano_nie':
      return v === true ? 'áno' : 'nie';
    case 'cislo':
    case 'suma':
      return typeof v === 'number' ? v : Number(v);
    case 'vyber':
      return opt(v);
    case 'vyber_viac':
      return Array.isArray(v) ? v.map(opt).join(', ') : null;
    case 'odkaz':
      return null; // odkaz = id záznamu, v tabuľke bez významu
    default:
      return String(v);
  }
}

const day = (v: string | Date | null) =>
  v ? new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava' }).format(new Date(v)) : null;
const today = () => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Bratislava' }).format(new Date());

function file(name: string, data: Uint8Array) {
  return new Response(data, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="${name}-${today()}.xlsx"`,
      'Cache-Control': 'no-store',
    },
  });
}

exportRoutes.get('/customers/export', async (c) => {
  const sql = c.var.sql;
  if (!(await canExport(sql, c.var.userId))) throw new Forbidden('Export nemáte povolený (Nastavenia → Tímy a práva).');
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const status = c.req.query('status') ?? '';
  const segment = c.req.query('segment') ?? '';
  const owner = c.req.query('owner') ?? '';
  const org = c.req.query('org') ?? '';
  const cf = c.req.query('cf');
  if (!STATUS_FILTERS.has(status) || !SEGMENT_FILTERS.has(segment)) throw new BadRequest('Neplatný filter.');
  if ((owner && !UUID.test(owner)) || (org && !UUID.test(org))) throw new BadRequest('Neplatný filter.');

  const data = await listCustomers(sql, { q, status, segment, owner, org, cf, page: 1 }, MAX_ROWS);
  const defs = await listDefs(sql, ['firma', 'osoba']);
  const header = [
    'Názov', 'Typ', 'Segment', 'Stav', 'IČO / OIB', 'E-mail', 'Telefón', 'Mesto', 'Vlastník', 'Spoločnosť',
    'Aktívne OOM', 'Ročný objem MWh', 'Posledná aktivita', ...defs.map((d) => d.label),
  ];
  const rows: Cell[][] = data.items.map((r) => [
    r.name, r.customer_type, r.segment_label, STATUS_LABEL[r.status] ?? r.status, r.ico, r.email, r.phone, r.city,
    r.owner_name, r.org_name, Number(r.active_oom_count), r.annual_mwh === null ? null : Number(r.annual_mwh),
    day(r.last_activity_at),
    ...defs.map((d) => ((d.entity === 'firma') === (r.kind === 'company') ? customCell(d, (r.custom ?? {})[d.key]) : null)),
  ]);
  await sql`
    INSERT INTO export_log (user_id, module, filter, row_count)
    VALUES (${c.var.userId}, 'zakaznici', ${sql.json({ list: 'zakaznici', q, status, segment, owner, org, cf: cf ?? '' })}, ${rows.length})`;
  return file('zakaznici', xlsx('Zákazníci', header, rows));
});

exportRoutes.get('/contacts/export', async (c) => {
  const sql = c.var.sql;
  if (!(await canExport(sql, c.var.userId))) throw new Forbidden('Export nemáte povolený (Nastavenia → Tímy a práva).');
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const role = c.req.query('role') ?? '';
  const cf = c.req.query('cf');
  if (!ROLE_FILTER.test(role)) throw new BadRequest('Neplatná rola.');

  const data = await listContacts(sql, { q, role, cf, page: 1 }, MAX_ROWS);
  const defs = await listDefs(sql, ['osoba']);
  const header = ['Titul', 'Meno', 'E-mail', 'Telefón', 'Mobil', 'Firmy a roly', 'Domácnosť', 'Stav', 'Nechce marketing od', ...defs.map((d) => d.label)];
  const rows: Cell[][] = data.items.map((p) => [
    p.title, p.name, p.email, p.phone, p.mobile,
    (p.companies as { name: string; role_labels: string[] }[])
      .map((f) => (f.role_labels.length ? `${f.name} (${f.role_labels.join(', ').toLowerCase()})` : f.name))
      .join('; '),
    p.is_household ? 'áno' : 'nie', p.status ? (STATUS_LABEL[p.status] ?? p.status) : null, day(p.marketing_opt_out_at),
    ...defs.map((d) => customCell(d, (p.custom ?? {})[d.key])),
  ]);
  await sql`
    INSERT INTO export_log (user_id, module, filter, row_count)
    VALUES (${c.var.userId}, 'zakaznici', ${sql.json({ list: 'kontakty', q, role, cf: cf ?? '' })}, ${rows.length})`;
  return file('kontakty', xlsx('Kontakty', header, rows));
});
