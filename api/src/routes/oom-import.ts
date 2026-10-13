// Modul Odberné miesta, F4 – import z Excelu (obrazovka 19; zadanie OOM čl. 9, 15; Peter 13. 10. 2026).
// Súbor .xlsx číta SheetJS 0.20.3 (cdn.sheetjs.com, pripnutý kontrolným súčtom); export ostáva vlastný (xlsx.ts).
// API prevedie bunky na hodnoty (čísla, dátumy, enumy) a pošle všetky riadky naraz do databázy
// (oom_import_run, 0018): tá urobí kontrolu aj uloženie s právami prihláseného. Súbor sa nikde neukladá.
// Šablóna a export OOM majú rovnaké stĺpce (export → úprava v Exceli → import).

import { Hono } from 'hono';
import * as XLSX from 'xlsx';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody, type Body } from '../validate';
import { type Cell, xlsxBook } from '../xlsx';

export const oomImport = new Hono<AppEnv>();

const MAX_BYTES = 10 * 1024 * 1024;
const MAX_ROWS = 5000;

type Kind = 'eic' | 'customer_id' | 'ico' | 'email' | 'text' | 'zip' | 'num' | 'int' | 'date' | 'lookup' | 'enum' | 'bool';
type Col = { key: string; label: string; kind: Kind; values?: Record<string, string>; hint: string; required?: boolean };

const OOM_TYPE: Record<string, string> = { spotreba: 'spotreba', vyroba: 'vyroba', 'výroba': 'vyroba', sharing: 'sharing' };
const VOLTAGE: Record<string, string> = { nn: 'nn', vn: 'vn', vvn: 'vvn' };
const SOURCE_KIND: Record<string, string> = {
  fve: 'fve', 'fotovoltická elektráreň': 'fve', 'fotovoltika': 'fve', voda: 'voda', 'vodná elektráreň': 'voda',
  bioplyn: 'bioplyn', biomasa: 'biomasa', plyn: 'plyn', 'plynová elektráreň': 'plyn', vietor: 'vietor',
  'veterná elektráreň': 'vietor', 'ostatné oze': 'ostatne_oze', ostatne_oze: 'ostatne_oze',
};
/** Cenová regulácia ANO / NIE (0019); prázdna bunka = bez zmeny. */
const YES_NO: Record<string, boolean> = { ano: true, 'áno': true, nie: false };
const SOURCE_CATEGORY: Record<string, string> = {
  'malý zdroj': 'maly_zdroj', 'maly zdroj': 'maly_zdroj', 'lokálny zdroj': 'lokalny_zdroj', 'lokalny zdroj': 'lokalny_zdroj',
  'výrobný zdroj': 'vyrobny_zdroj', 'vyrobny zdroj': 'vyrobny_zdroj',
};

/** Stĺpce šablóny a exportu (poradie = poradie v súbore). Kľúč = stĺpec oom alebo údaj zákazníka. */
export const OOM_COLUMNS: Col[] = [
  { key: 'eic', label: 'EIC', kind: 'eic', required: true, hint: '16 znakov; medzery a malé písmená sa upravia. Podľa EIC sa páruje: existuje = zmena, neexistuje = nové OOM.' },
  { key: 'customer_id', label: 'ID zákazníka', kind: 'customer_id', hint: 'ID firmy alebo domácnosti z CRM (je v exporte). Má prednosť pred IČO a e-mailom.' },
  { key: 'ico', label: 'IČO zákazníka', kind: 'ico', hint: 'Firma podľa IČO (úvodné nuly sa doplnia).' },
  { key: 'email', label: 'E-mail zákazníka', kind: 'email', hint: 'Domácnosť podľa e-mailu (iba ak je v CRM jediná osoba s týmto e-mailom).' },
  { key: 'type', label: 'Typ', kind: 'enum', values: OOM_TYPE, hint: 'Spotreba, Výroba alebo Sharing; pri novom OOM povinné.' },
  { key: 'name', label: 'Názov', kind: 'text', hint: 'napr. Hala A, Rodinný dom' },
  { key: 'address_street', label: 'Ulica', kind: 'text', hint: '' },
  { key: 'address_number_supisne', label: 'Súpisné číslo', kind: 'text', hint: '' },
  { key: 'address_number_orientacne', label: 'Orientačné číslo', kind: 'text', hint: '' },
  { key: 'address_zip', label: 'PSČ', kind: 'zip', hint: '5 číslic, úvodná nula ostane (aj „014 01“)' },
  { key: 'address_city', label: 'Obec', kind: 'text', hint: '' },
  { key: 'pds', label: 'PDS', kind: 'lookup', hint: 'názov ako v CRM, napr. ZSD (hárok Pokyny)' },
  { key: 'pds_tariff', label: 'Sadzba', kind: 'lookup', hint: 'sadzba zvoleného PDS, napr. D2, C2-X3 (hárok Pokyny)' },
  { key: 'pds_point_id', label: 'Číslo OP', kind: 'text', hint: '' },
  { key: 'voltage_level', label: 'Napäťová úroveň', kind: 'enum', values: VOLTAGE, hint: 'NN, VN alebo VVN' },
  { key: 'metering_type', label: 'Typ merania', kind: 'lookup', hint: 'A, B, C, N – nemerané' },
  { key: 'phases', label: 'Fázy', kind: 'int', hint: '1 alebo 3' },
  { key: 'breaker_a', label: 'Istič [A]', kind: 'num', hint: '' },
  { key: 'reserved_capacity_kw', label: 'Rezervovaná kapacita [kW]', kind: 'num', hint: '' },
  { key: 'max_reserved_capacity_kw', label: 'Max. rezervovaná kapacita [kW]', kind: 'num', hint: '' },
  { key: 'capacity_reservation_method', label: 'Spôsob rezervácie kapacity', kind: 'text', hint: '' },
  { key: 'planned_consumption_vt_mwh', label: 'Plánovaná spotreba VT [MWh]', kind: 'num', hint: 'desatinná čiarka alebo bodka' },
  { key: 'planned_consumption_nt_mwh', label: 'Plánovaná spotreba NT [MWh]', kind: 'num', hint: '' },
  { key: 'planned_feed_in_mwh', label: 'Plánovaný výkup [MWh]', kind: 'num', hint: 'pri výrobe' },
  { key: 'supply_from', label: 'Dodávka od', kind: 'date', hint: 'dátum (1. 1. 2027); kroky prechodu sa zadávajú na karte OOM' },
  { key: 'price_regulation', label: 'Cenová regulácia', kind: 'bool', hint: 'ANO alebo NIE (domácnosť: nárok na energopomoc; firma: cenník pre malé podniky)' },
  { key: 'excise_tax', label: 'Spotrebná daň', kind: 'text', hint: '' },
  { key: 'billing_period', label: 'Fakturačné obdobie', kind: 'lookup', hint: 'Mesačne, Ročne, Ročne s odkladom k termínu odpočtu' },
  { key: 'advance_payment_method', label: 'Zálohy', kind: 'lookup', hint: 'napr. Bez záloh, Mesačné zálohy' },
  { key: 'advance_payment_pct', label: 'Záloha [%]', kind: 'num', hint: '' },
  { key: 'advance_payment_eur', label: 'Záloha [€]', kind: 'num', hint: '' },
  { key: 'source_kind', label: 'Druh zdroja', kind: 'enum', values: SOURCE_KIND, hint: 'FVE, Voda, Bioplyn, Biomasa, Plyn, Vietor, Ostatné OZE' },
  { key: 'source_category', label: 'Kategória zdroja', kind: 'enum', values: SOURCE_CATEGORY, hint: 'Malý zdroj, Lokálny zdroj, Výrobný zdroj' },
  { key: 'source_power_kw', label: 'Výkon zdroja [kW]', kind: 'num', hint: '' },
  { key: 'inverter_power_kw', label: 'Výkon striedača [kW]', kind: 'num', hint: '' },
  { key: 'panels_power_kw', label: 'Výkon panelov [kW]', kind: 'num', hint: '' },
  { key: 'feed_in_contract_type', label: 'Typ výkupnej zmluvy', kind: 'lookup', hint: 'hárok Pokyny' },
];
/** Stĺpce exportu za stĺpcami šablóny: iba na čítanie, import ich vynechá. */
export const READONLY_SUFFIX = ' (len na čítanie)';

const norm = (s: string) => s.toLowerCase().replace(/[–—]/g, '-').replace(/\s+/g, ' ').trim();

type CustomDef = { key: string; label: string; field_type: string };

async function customDefs(sql: Sql, org: string): Promise<CustomDef[]> {
  return sql<CustomDef[]>`
    SELECT key, label, field_type::text AS field_type FROM custom_field
     WHERE entity = 'oom' AND archived_at IS NULL AND (org_id IS NULL OR org_id = ${org})
       AND field_type NOT IN ('vyber_viac', 'odkaz')
     ORDER BY sort_order, lower(label)`;
}

/** Hlavička vlastného poľa (ak by sa zhodovala so stĺpcom jadra, dostane príponu). */
export const customLabel = (d: { label: string }) =>
  OOM_COLUMNS.some((c) => norm(c.label) === norm(d.label)) ? `${d.label} (vlastné pole)` : d.label;

const yesNo = (v: string | null) => (v === 'true' ? 'ANO' : v === 'false' ? 'NIE' : v);

async function canImport(sql: Sql): Promise<boolean> {
  const [r] = await sql<{ ok: boolean }[]>`SELECT crm_can_import('odberne_miesta') AS ok`;
  return !!r?.ok;
}

// ---------------------------------------------------------------------------
// Čítanie súboru
// ---------------------------------------------------------------------------

type ParsedRow = {
  row: number;
  eic: string | null;
  customer_id: string | null;
  ico: string | null;
  email: string | null;
  fields: Record<string, string | number | boolean>;
  custom: Record<string, string | number>;
  parse_errors: string[];
};
type Parsed = { sheet: string; rows: ParsedRow[]; original: { row: number; cells: string[] }[]; header: string[]; ignored: string[] };

const pad = (n: number) => String(n).padStart(2, '0');

/** Dátum z bunky: číslo z Excelu (aj 1904), RRRR-MM-DD alebo D. M. RRRR. */
function cellDate(cell: XLSX.CellObject, date1904: boolean): string | null {
  if (cell.t === 'n' && typeof cell.v === 'number') {
    const p = XLSX.SSF.parse_date_code(cell.v, { date1904 });
    return p ? `${p.y}-${pad(p.m)}-${pad(p.d)}` : null;
  }
  const t = String(cell.v ?? '').trim();
  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(t);
  if (m) return valid(+m[1], +m[2], +m[3]);
  m = /^(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})$/.exec(t);
  if (m) return valid(+m[3], +m[2], +m[1]);
  return null;
}
function valid(y: number, mo: number, d: number): string | null {
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d ? `${y}-${pad(mo)}-${pad(d)}` : null;
}
/** Text bunky: pri čísle s formátom (napr. 00000000) zobrazený text, aby ostali úvodné nuly. */
function cellText(cell: XLSX.CellObject | undefined): string {
  if (!cell || cell.v === undefined || cell.v === null) return '';
  if (cell.t === 'n' && cell.w !== undefined) return String(cell.w).trim();
  return String(cell.v).trim();
}
function cellNumber(cell: XLSX.CellObject): number | null {
  if (cell.t === 'n' && typeof cell.v === 'number') return cell.v;
  const t = String(cell.v ?? '').replace(/\s/g, '').replace(',', '.');
  if (t === '') return null;
  const n = Number(t);
  return Number.isFinite(n) ? n : Number.NaN;
}

function parseWorkbook(bytes: Uint8Array, defs: CustomDef[]): Parsed {
  let wb: XLSX.WorkBook;
  try {
    wb = XLSX.read(bytes, { type: 'array', cellDates: false, cellFormula: false, cellHTML: false, sheetStubs: false });
  } catch {
    throw new BadRequest('Súbor sa nedá prečítať. Nahrajte .xlsx (Excel).');
  }
  const date1904 = !!wb.Workbook?.WBProps?.date1904;
  // hárok „OOM“, inak prvý hárok, ktorý má v hlavičke stĺpec EIC
  const headerRow = (ws: XLSX.WorkSheet): number => {
    if (!ws['!ref']) return -1;
    const range = XLSX.utils.decode_range(ws['!ref']);
    for (let r = range.s.r; r <= Math.min(range.e.r, range.s.r + 9); r++) {
      for (let c = range.s.c; c <= range.e.c; c++) if (norm(cellText(ws[XLSX.utils.encode_cell({ r, c })])) === 'eic') return r;
    }
    return -1;
  };
  const name =
    wb.SheetNames.find((n) => norm(n) === 'oom' && headerRow(wb.Sheets[n]) >= 0) ??
    wb.SheetNames.find((n) => headerRow(wb.Sheets[n]) >= 0);
  if (!name) throw new BadRequest('V súbore chýba hárok so stĺpcom „EIC“ (použite šablónu).');
  const ws = wb.Sheets[name];
  const hr = headerRow(ws);
  const range = XLSX.utils.decode_range(ws['!ref']!);

  const byLabel = new Map<string, { col?: Col; custom?: CustomDef }>();
  for (const c of OOM_COLUMNS) byLabel.set(norm(c.label), { col: c });
  for (const d of defs) byLabel.set(norm(customLabel(d)), { custom: d });
  const header: string[] = [];
  const mapping: ({ col?: Col; custom?: CustomDef } | null)[] = [];
  const ignored: string[] = [];
  for (let c = range.s.c; c <= range.e.c; c++) {
    const h = cellText(ws[XLSX.utils.encode_cell({ r: hr, c })]);
    header.push(h);
    const m = h ? (byLabel.get(norm(h)) ?? null) : null;
    mapping.push(m);
    if (h && !m && !h.endsWith(READONLY_SUFFIX)) ignored.push(h);
  }

  const rows: ParsedRow[] = [];
  const original: Parsed['original'] = [];
  for (let r = hr + 1; r <= range.e.r; r++) {
    const cells: (XLSX.CellObject | undefined)[] = [];
    for (let c = range.s.c; c <= range.e.c; c++) cells.push(ws[XLSX.utils.encode_cell({ r, c })]);
    const texts = cells.map(cellText);
    if (texts.every((t) => t === '')) continue; // prázdny riadok
    if (rows.length >= MAX_ROWS) throw new BadRequest(`Súbor má viac ako 5 000 riadkov – rozdeľte ho.`);
    const out: ParsedRow = { row: r + 1, eic: null, customer_id: null, ico: null, email: null, fields: {}, custom: {}, parse_errors: [] };
    cells.forEach((cell, i) => {
      const m = mapping[i];
      const text = texts[i];
      if (!m || !cell || text === '') return; // prázdna bunka = bez zmeny
      if (m.custom) {
        out.custom[m.custom.key] = cell.t === 'n' && typeof cell.v === 'number' && m.custom.field_type !== 'text' ? cell.v : text;
        return;
      }
      const col = m.col!;
      switch (col.kind) {
        case 'eic':
          out.eic = text.toUpperCase().replace(/\s/g, '');
          break;
        case 'customer_id':
          if (UUID.test(text)) out.customer_id = text.toLowerCase();
          else out.parse_errors.push(`ID zákazníka: neplatné ID „${text}“.`);
          break;
        case 'ico':
          out.ico = text.replace(/\D/g, '');
          break;
        case 'email':
          out.email = text;
          break;
        case 'zip':
          out.fields[col.key] = text.replace(/\s/g, '');
          break;
        case 'text':
        case 'lookup':
          out.fields[col.key] = text;
          break;
        case 'num':
        case 'int': {
          const n = cellNumber(cell);
          if (n === null) return;
          if (Number.isNaN(n) || n < 0 || (col.kind === 'int' && !Number.isInteger(n))) out.parse_errors.push(`${col.label}: neplatné číslo „${text}“.`);
          else out.fields[col.key] = n;
          break;
        }
        case 'date': {
          const d = cellDate(cell, date1904);
          if (d) out.fields[col.key] = d;
          else out.parse_errors.push(`${col.label}: neplatný dátum „${text}“.`);
          break;
        }
        case 'bool': {
          const b = YES_NO[norm(text)];
          if (b === undefined) out.parse_errors.push(`${col.label}: ANO alebo NIE, nie „${text}“.`);
          else out.fields[col.key] = b;
          break;
        }
        case 'enum': {
          const v = col.values![norm(text)];
          if (v) out.fields[col.key] = v;
          else out.parse_errors.push(`${col.label}: neznáma hodnota „${text}“.`);
          break;
        }
      }
    });
    rows.push(out);
    original.push({ row: r + 1, cells: texts });
  }
  if (rows.length === 0) throw new BadRequest('V súbore nie je žiadny riadok s údajmi.');
  return { sheet: name, rows, original, header, ignored };
}

async function fileFrom(b: Body): Promise<{ bytes: Uint8Array; name: string; hash: string; org: string }> {
  const name = typeof b.file_name === 'string' ? b.file_name.slice(0, 200) : 'import.xlsx';
  const org = typeof b.org === 'string' && UUID.test(b.org) ? b.org : '';
  if (!org) throw new BadRequest('Neplatná spoločnosť.');
  if (typeof b.data_base64 !== 'string' || b.data_base64 === '') throw new BadRequest('Chýba súbor.');
  if (b.data_base64.length > Math.ceil((MAX_BYTES * 4) / 3) + 4) throw new BadRequest('Súbor je väčší ako 10 MB.');
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(b.data_base64), (ch) => ch.charCodeAt(0));
  } catch {
    throw new BadRequest('Súbor sa nedá prečítať.');
  }
  if (bytes.length > MAX_BYTES) throw new BadRequest('Súbor je väčší ako 10 MB.');
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  const hash = [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, '0')).join('');
  return { bytes, name, hash, org };
}

type DbResult = {
  rows?: { row: number; eic: string | null; action: string; error?: string; changes?: { field: string; old: string | null; new: string | null }[]; customer?: string | null; oom_id?: string }[];
  counts: { riadkov: number; nove: number; zmena: number; bez_zmeny: number; chyba: number };
  mismatch?: boolean;
  import_id?: string | null;
};

async function run(sql: Sql, org: string, rows: ParsedRow[], save: boolean, fileName?: string, expected?: unknown): Promise<DbResult> {
  const [r] = await sql<{ r: DbResult }[]>`
    SELECT oom_import_run(${org}::uuid, ${sql.json(rows as never)}::jsonb, ${save}, ${fileName ?? null},
                          ${expected === undefined ? null : sql.json(expected as never)}::jsonb) AS r`;
  return r.r;
}

// ---------------------------------------------------------------------------
// Trasy
// ---------------------------------------------------------------------------

// Šablóna: hárok OOM (hlavička) a hárok Pokyny (stĺpce a povolené hodnoty číselníkov).
oomImport.get('/oom-import/template', async (c) => {
  const sql = c.var.sql;
  const org = c.req.query('org') ?? '';
  if (!UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (!(await canImport(sql))) throw new Forbidden('Import odberných miest nemáte povolený (Nastavenia → Tímy a práva).');
  const defs = await customDefs(sql, org);
  const lookups = await sql<{ list_code: string; label: string; parent_label: string | null }[]>`
    SELECT v.list_code, v.label, p.label AS parent_label
      FROM lookup_value v
      LEFT JOIN lookup_value p ON p.list_code = 'pds' AND p.code = v.parent_code
     WHERE v.list_code IN ('pds', 'sadzba_distribucie', 'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'typ_vykupnej_zmluvy')
       AND v.hidden_at IS NULL AND (v.org_id IS NULL OR v.org_id = ${org})
     ORDER BY v.list_code, p.sort_order NULLS FIRST, v.sort_order, lower(v.label)`;
  const values = (list: string) => lookups.filter((l) => l.list_code === list).map((l) => l.label).join(', ');
  const tariffs = [...new Set(lookups.filter((l) => l.list_code === 'sadzba_distribucie').map((l) => l.parent_label))]
    .map((p) => `${p}: ${lookups.filter((l) => l.list_code === 'sadzba_distribucie' && l.parent_label === p).map((l) => l.label).join(', ')}`);
  const header = [...OOM_COLUMNS.map((col) => col.label), ...defs.map(customLabel)];
  const help: Cell[][] = [
    ...OOM_COLUMNS.map((col) => [col.label, col.required ? 'áno' : '', col.hint]),
    ...defs.map((d) => [customLabel(d), '', `vlastné pole (${d.field_type === 'ano_nie' ? 'áno / nie' : d.field_type === 'datum' ? 'dátum' : d.field_type === 'vyber' ? 'hodnota výberu' : d.field_type})`]),
    [],
    ['Pravidlá', '', 'Prázdna bunka pri existujúcom OOM = bez zmeny. Nové OOM vznikne ako Pripravované. Stav, zákazníka (prepis) a kroky prechodu import nemení.'],
    ['', '', 'Zákazník sa hľadá podľa ID zákazníka, potom IČO, potom e-mailu. Pri existujúcom OOM musí sedieť s aktuálnym zákazníkom.'],
    ['', '', 'Najviac 5 000 riadkov a 10 MB. Hodnoty číselníkov názvom ako v CRM (veľké a malé písmená nevadia).'],
    [],
    ['PDS', '', values('pds')],
    ['Sadzby podľa PDS', '', tariffs.join(' | ')],
    ['Typ merania', '', values('typ_merania')],
    ['Fakturačné obdobie', '', values('fakturacne_obdobie')],
    ['Zálohy', '', values('sposob_zaloh')],
    ['Typ výkupnej zmluvy', '', values('typ_vykupnej_zmluvy')],
  ];
  const data = xlsxBook([
    { name: 'OOM', header, rows: [] },
    { name: 'Pokyny', header: ['Stĺpec', 'Povinné', 'Popis a povolené hodnoty'], rows: help },
  ]);
  return new Response(data, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename="odberne-miesta-sablona.xlsx"',
      'Cache-Control': 'no-store',
    },
  });
});

// Náhľad: nič sa neuloží; vráti odtlačok súboru a počty, ktoré musí potvrdiť uloženie.
oomImport.post('/oom-import/preview', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden('Import odberných miest nemáte povolený (Nastavenia → Tímy a práva).');
  const f = await fileFrom(await readBody(c.req));
  const defs = await customDefs(sql, f.org);
  const t0 = Date.now();
  const parsed = parseWorkbook(f.bytes, defs);
  const t1 = Date.now();
  const res = await run(sql, f.org, parsed.rows, false);
  const labels = new Map<string, string>([
    ...OOM_COLUMNS.map((col): [string, string] => [col.key, col.label]),
    ...defs.map((d): [string, string] => [`custom.${d.key}`, customLabel(d)]),
  ]);
  return c.json({
    hash: f.hash,
    file_name: f.name,
    sheet: parsed.sheet,
    ignored_columns: parsed.ignored,
    counts: res.counts,
    timing_ms: { citanie: t1 - t0, kontrola: Date.now() - t1 },
    rows: (res.rows ?? []).map((r) => ({
      ...r,
      changes: (r.changes ?? []).map((ch) => ({
        ...ch,
        ...(ch.field === 'price_regulation' ? { old: yesNo(ch.old), new: yesNo(ch.new) } : {}),
        label: labels.get(ch.field) ?? ch.field,
      })),
    })),
  });
});

// Uloženie: iba ten istý súbor (odtlačok) a iba ak počty sedia s náhľadom; inak 409 a nový náhľad.
oomImport.post('/oom-import/save', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden('Import odberných miest nemáte povolený (Nastavenia → Tímy a práva).');
  const b = await readBody(c.req);
  const f = await fileFrom(b);
  if (b.hash !== f.hash) return c.json({ error: 'Súbor sa od náhľadu zmenil. Urobte nový náhľad.', code: 'hash' }, 409);
  const defs = await customDefs(sql, f.org);
  const parsed = parseWorkbook(f.bytes, defs);
  const res = await run(sql, f.org, parsed.rows, true, f.name, b.counts);
  if (res.mismatch) {
    return c.json({ error: 'Údaje sa od náhľadu zmenili (iný počet nových, zmenených alebo chybných riadkov). Nič sa neuložilo – urobte nový náhľad.', code: 'mismatch', counts: res.counts }, 409);
  }
  return c.json({ import_id: res.import_id, counts: res.counts });
});

// Chybné riadky ako .xlsx (vytvorí sa iba pri stiahnutí, nikde sa neukladá): pôvodné bunky + stĺpec „Chyba“.
oomImport.post('/oom-import/errors', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden('Import odberných miest nemáte povolený (Nastavenia → Tímy a práva).');
  const f = await fileFrom(await readBody(c.req));
  const defs = await customDefs(sql, f.org);
  const parsed = parseWorkbook(f.bytes, defs);
  const res = await run(sql, f.org, parsed.rows, false);
  const errors = new Map((res.rows ?? []).filter((r) => r.action === 'chyba').map((r) => [r.row, r.error ?? '']));
  const rows: Cell[][] = parsed.original.filter((o) => errors.has(o.row)).map((o) => [...o.cells, errors.get(o.row)!, o.row]);
  const data = xlsxBook([{ name: 'OOM', header: [...parsed.header, 'Chyba', 'Pôvodný riadok'], rows }]);
  return new Response(data, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename="odberne-miesta-chyby.xlsx"',
      'Cache-Control': 'no-store',
    },
  });
});
