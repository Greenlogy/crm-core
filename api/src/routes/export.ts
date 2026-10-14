// Export zoznamov Zákazníci, Kontakty a Odberné miesta do .xlsx (rozhodnutie 2026-10-12): iba tímy s právom
// „exportovať“ v danom module; každý export sa zapíše do export_log (kto, kedy, filter, počet riadkov – bez údajov).
// IČO, telefóny, EIC a PSČ idú ako text (bez straty úvodných núl).
// Filtre sú rovnaké ako v zozname; exportuje sa najviac MAX_ROWS riadkov.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { listContacts, ROLE_FILTER } from '../queries/contacts';
import { listCustomers, SEGMENT_FILTERS, STATUS_FILTERS } from '../queries/customers';
import { listOom, OOM_CHIPS, OOM_TYPES } from '../queries/oom';
import { customLabel, OOM_COLUMNS, READONLY_SUFFIX } from './oom-import';
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

async function canExport(sql: Sql, userId: string, module: 'zakaznici' | 'odberne_miesta' = 'zakaznici'): Promise<boolean> {
  const [r] = await sql<{ ok: boolean }[]>`
    SELECT p.can_export AS ok FROM app_user u JOIN team_permission p ON p.team_id = u.team_id AND p.module = ${module}::crm_module
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

// --- Odberné miesta (modul 2, F3) ---

const OOM_STATUS_LABEL: Record<string, string> = {
  pripravovane: 'Pripravované',
  aktivne: 'Aktívne',
  odidene: 'Odídené',
  zrusene: 'Zrušené',
  prepisane: 'Prepísané',
};
const OOM_TYPE_LABEL: Record<string, string> = { spotreba: 'Spotreba', vyroba: 'Výroba', sharing: 'Sharing' };
const PLAN_LABEL: Record<string, string> = { prepis: 'prepis', odchod: 'odchod', zrusenie: 'zrušenie' };

exportRoutes.get('/oom/export', async (c) => {
  const sql = c.var.sql;
  if (!(await canExport(sql, c.var.userId, 'odberne_miesta'))) {
    throw new Forbidden('Export odberných miest nemáte povolený (Nastavenia → Tímy a práva).');
  }
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const chip = c.req.query('stav') ?? '';
  const type = c.req.query('typ') ?? '';
  const pds = c.req.query('pds') ?? '';
  const owner = c.req.query('owner') ?? '';
  const org = c.req.query('org') ?? '';
  const cf = c.req.query('cf');
  if (!OOM_CHIPS.has(chip) || (type !== '' && !(OOM_TYPES as readonly string[]).includes(type)) || !/^[a-z0-9_]{0,63}$/.test(pds)) {
    throw new BadRequest('Neplatný filter.');
  }
  if ((owner && !UUID.test(owner)) || (org && !UUID.test(org))) throw new BadRequest('Neplatný filter.');

  const data = await listOom(sql, { q, chip, type, pds, owner, org, cf, page: 1 }, MAX_ROWS);
  // Stĺpce ako šablóna importu (export → úprava v Exceli → import); hodnoty číselníkov názvom.
  const ids = data.items.map((o) => o.id).join(',');
  const details = ids
    ? await sql`
        SELECT o.*, coalesce(o.company_id, o.person_id) AS customer_id, c.ico AS customer_ico,
               CASE WHEN o.person_id IS NOT NULL THEN p.email END AS customer_email,
               (SELECT label FROM lookup_value WHERE list_code = 'pds' AND code = o.pds) AS pds_l,
               (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = o.pds_tariff) AS tariff_l,
               (SELECT label FROM lookup_value WHERE list_code = 'typ_merania' AND code = o.metering_type) AS metering_l,
               (SELECT label FROM lookup_value WHERE list_code = 'fakturacne_obdobie' AND code = o.billing_period) AS billing_l,
               (SELECT label FROM lookup_value WHERE list_code = 'sposob_zaloh' AND code = o.advance_payment_method) AS advance_l,
               (SELECT label FROM lookup_value WHERE list_code = 'typ_vykupnej_zmluvy' AND code = o.feed_in_contract_type) AS feed_in_l
          FROM oom o
          LEFT JOIN company c ON c.id = o.company_id
          LEFT JOIN contact p ON p.id = o.person_id
         WHERE o.id = ANY (string_to_array(${ids}, ',')::uuid[])`
    : [];
  const byId = new Map(details.map((d) => [d.id as string, d]));
  // všetky vlastné polia OOM (ako šablóna), nielen „zobraziť v zozname“; výber viac a odkaz iba na čítanie
  const defs = await sql<Def[]>`
    SELECT f.key, f.label, f.entity::text AS entity, f.field_type::text AS field_type,
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'label', o.label)) FROM custom_field_option o
                      WHERE o.field_id = f.id), '[]') AS options
      FROM custom_field f
     WHERE f.entity = 'oom' AND f.archived_at IS NULL
     ORDER BY f.sort_order, lower(f.label)`;
  const cdefs = defs.filter((d) => d.field_type !== 'vyber_viac' && d.field_type !== 'odkaz');
  const extra = defs.filter((d) => !cdefs.some((x) => x.key === d.key));
  const ro = (label: string) => label + READONLY_SUFFIX;
  const header = [
    ...OOM_COLUMNS.map((col) => col.label), ...cdefs.map(customLabel),
    ro('Zákazník'), ro('Stav'), ro('Vlastník'), ro('Spoločnosť'), ro('Dodávka do'), ro('Prechod sa zasekol'),
    ro('Plánovaná zmena'), ro('Prepis od'), ro('Verejné osvetlenie'), ro('Plán výkupu zadaný ručne'),
    ...extra.map((d) => ro(d.label)),
  ];
  const date = (v: string | null) => (v ? v.split('-').reverse().map(Number).join('. ') : null);
  const SOURCE_KIND_L: Record<string, string> = {
    fve: 'FVE', voda: 'Voda', bioplyn: 'Bioplyn', biomasa: 'Biomasa', plyn: 'Plyn', vietor: 'Vietor', ostatne_oze: 'Ostatné OZE',
  };
  const CATEGORY_L: Record<string, string> = { maly_zdroj: 'Malý zdroj', lokalny_zdroj: 'Lokálny zdroj', vyrobny_zdroj: 'Výrobný zdroj' };
  const num = (v: unknown) => (v === null || v === undefined ? null : Number(v));
  const rows: Cell[][] = data.items.map((o) => {
    const d = byId.get(o.id) ?? {};
    const value: Record<string, Cell> = {
      eic: o.eic, customer_id: d.customer_id, ico: d.customer_ico, email: d.customer_email,
      type: OOM_TYPE_LABEL[o.type] ?? o.type, name: o.name, address_street: o.address_street,
      address_number_supisne: o.address_number_supisne, address_number_orientacne: o.address_number_orientacne,
      address_zip: o.address_zip, address_city: o.address_city, pds: d.pds_l, pds_tariff: d.tariff_l, pds_point_id: d.pds_point_id,
      voltage_level: d.voltage_level ? String(d.voltage_level).toUpperCase() : null, metering_type: d.metering_l,
      phases: num(d.phases), breaker_a: num(d.breaker_a), reserved_capacity_kw: num(d.reserved_capacity_kw),
      max_reserved_capacity_kw: num(d.max_reserved_capacity_kw), capacity_reservation_method: d.capacity_reservation_method,
      planned_consumption_vt_mwh: num(d.planned_consumption_vt_mwh), planned_consumption_nt_mwh: num(d.planned_consumption_nt_mwh),
      planned_feed_in_mwh: num(d.planned_feed_in_mwh), supply_from: date(o.supply_from), price_regulation: d.price_regulation === null || d.price_regulation === undefined ? null : d.price_regulation ? 'ANO' : 'NIE',
      excise_tax: d.excise_tax, billing_period: d.billing_l, advance_payment_method: d.advance_l,
      advance_payment_pct: num(d.advance_payment_pct), advance_payment_eur: num(d.advance_payment_eur),
      source_kind: d.source_kind ? SOURCE_KIND_L[d.source_kind] : null, source_category: d.source_category ? CATEGORY_L[d.source_category] : null,
      source_power_kw: num(d.source_power_kw), inverter_power_kw: num(d.inverter_power_kw), panels_power_kw: num(d.panels_power_kw),
      feed_in_contract_type: d.feed_in_l,
    };
    return [
      ...OOM_COLUMNS.map((col) => value[col.key] ?? null),
      ...cdefs.map((cd) => customCell(cd, (o.custom ?? {})[cd.key])),
      o.customer_name, OOM_STATUS_LABEL[o.status] ?? o.status, o.owner_name, o.org_name, date(o.supply_to),
      o.switch_stuck ? 'áno' : null,
      o.plan_kind ? `${PLAN_LABEL[o.plan_kind]} k ${date(o.plan_date)}` : o.plan_failed ? 'plán zlyhal' : null,
      o.transferred_from_name,
      d.public_lighting ? 'áno' : null,
      d.source_category === 'lokalny_zdroj' ? (d.planned_feed_in_manual ? 'áno' : 'nie (výpočet)') : null,
      ...extra.map((cd) => customCell(cd, (o.custom ?? {})[cd.key])),
    ];
  });
  await sql`
    INSERT INTO export_log (user_id, module, filter, row_count)
    VALUES (${c.var.userId}, 'odberne_miesta', ${sql.json({ list: 'oom', q, stav: chip, typ: type, pds, owner, org, cf: cf ?? '' })}, ${rows.length})`;
  return file('odberne-miesta', xlsx('Odberné miesta', header, rows));
});
