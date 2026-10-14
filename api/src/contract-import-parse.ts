// Modul Zmluvy, F2 – čítanie exportov pre import zmlúv (obrazovka 27; návrh DB časti 8 a 25).
// Office portal „HEO - Web Zmluvy - prehlad EE“ (jeden riadok = zmluva × OOM × cenové obdobie) a XM Trade „Prehľad“
// (jeden riadok = OOM). Výstup sú riadky pre databázovú funkciu contract_import_run (0026): dátumy RRRR-MM-DD,
// množstvá v MWh, prázdne hodnoty null. Preklady názvov (fáza, produkt, obchodník, číselníky) robí databáza.
// Dátum narodenia (Office portal) ani rodné číslo (XM Trade, stĺpec IČO / Rodné číslo) sa do výstupu nikdy nedostanú
// (rozhodnutie 9).

import * as XLSX from 'xlsx';

export type OpRow = {
  row: number;
  op_id: string | null;
  number: string | null;
  test: boolean;
  phase: string | null;
  commodity: string | null;
  household: boolean;
  first_name: string | null;
  last_name: string | null;
  company_name: string | null;
  ico: string | null;
  dic: string | null;
  ic_dph: string | null;
  person_op_id: string | null;
  eic: string | null;
  sum_mwh: number | null;
  qty_vt_mwh: number | null;
  qty_nt_mwh: number | null;
  source_power_kw: number | null;
  tariff_pds: string | null;
  product_oom: string | null;
  price_product: string | null;
  price_from: string | null;
  price_to: string | null;
  price_vt: number | null;
  price_nt: number | null;
  small_business: boolean;
  list_price: boolean;
  auto_prolong: boolean;
  valid_from: string | null;
  valid_to: string | null;
  signed_on: string | null;
  created_by_name: string | null;
  owner_name: string | null;
  updated_at: string | null;
  parse_errors: string[];
};

export type XmRow = {
  row: number;
  eic: string | null;
  contract_number: string | null;
  ico: string | null;
  household: boolean;
  supply_from: string | null;
  direction: string | null;
  product: string | null;
  regulation: string | null;
  tariff: string | null;
  address: string | null;
  fields: Record<string, string | number>;
  parse_errors: string[];
};

export type ParsedImport =
  | { source: 'office_portal'; sheet: string; rows: OpRow[] }
  | { source: 'xm_trade'; sheet: string; rows: XmRow[] };

const pad = (n: number) => String(n).padStart(2, '0');
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Hlavička bez hranatých zátvoriek Office portálu („[ID]“ = „ID“), malé písmená, jedna medzera. */
const headKey = (h: unknown) =>
  String(h ?? '')
    .replace(/^\s*\[(.*)\]\s*$/, '$1')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();

/** Prázdna hodnota: prázdna bunka, „-“ (XM Trade). */
function text(cell: XLSX.CellObject | undefined): string | null {
  if (!cell || cell.v === undefined || cell.v === null) return null;
  const t = (cell.t === 'n' && cell.w !== undefined && !/[eE]/.test(cell.w) ? String(cell.w) : String(cell.v)).trim();
  return t === '' || t === '-' ? null : t;
}

/** Číslo: číslo z Excelu alebo text s čiarkou / bodkou a medzerami. */
function num(cell: XLSX.CellObject | undefined, label: string, errors: string[]): number | null {
  if (!cell || cell.v === undefined || cell.v === null) return null;
  if (cell.t === 'n' && typeof cell.v === 'number') return cell.v;
  const t = String(cell.v).replace(/[\s ]/g, '').replace(',', '.');
  if (t === '' || t === '-') return null;
  const n = Number(t);
  if (!Number.isFinite(n)) {
    errors.push(`${label}: „${String(cell.v)}“ nie je číslo.`);
    return null;
  }
  return n;
}

function validDate(y: number, mo: number, d: number): string | null {
  const dt = new Date(Date.UTC(y, mo - 1, d));
  return dt.getUTCFullYear() === y && dt.getUTCMonth() === mo - 1 && dt.getUTCDate() === d ? `${y}-${pad(mo)}-${pad(d)}` : null;
}

/** Dátum (a čas): číslo z Excelu, RRRR-MM-DD, DD.MM.RRRR. Rok 1899/1900 = prázdne (Office portal). */
function dateParts(cell: XLSX.CellObject | undefined, date1904: boolean): { d: string; t: string } | 'chyba' | null {
  if (!cell || cell.v === undefined || cell.v === null) return null;
  if (cell.t === 'n' && typeof cell.v === 'number') {
    const p = XLSX.SSF.parse_date_code(cell.v, { date1904 });
    if (!p) return 'chyba';
    if (p.y <= 1900) return null;
    return { d: `${p.y}-${pad(p.m)}-${pad(p.d)}`, t: `${pad(p.H)}:${pad(p.M)}:${pad(Math.floor(p.S))}` };
  }
  if (cell.t === 'd' && cell.v instanceof Date) {
    const v = cell.v;
    if (v.getUTCFullYear() <= 1900) return null;
    return { d: `${v.getUTCFullYear()}-${pad(v.getUTCMonth() + 1)}-${pad(v.getUTCDate())}`, t: '00:00:00' };
  }
  const s = String(cell.v).trim();
  if (s === '' || s === '-') return null;
  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?/.exec(s);
  let d: string | null = null;
  let time = '00:00:00';
  if (m) {
    d = validDate(+m[1], +m[2], +m[3]);
    if (m[4]) time = `${pad(+m[4])}:${m[5]}:${m[6] ?? '00'}`;
  } else {
    m = /^(\d{1,2})\.\s*(\d{1,2})\.\s*(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$/.exec(s);
    if (m) {
      d = validDate(+m[3], +m[2], +m[1]);
      if (m[4]) time = `${pad(+m[4])}:${m[5]}:${m[6] ?? '00'}`;
    }
  }
  if (!d) return 'chyba';
  if (+d.slice(0, 4) <= 1900) return null;
  return { d, t: time };
}

function date(cell: XLSX.CellObject | undefined, label: string, errors: string[], date1904: boolean): string | null {
  const p = dateParts(cell, date1904);
  if (p === 'chyba') {
    errors.push(`${label}: „${String(cell?.v)}“ nie je dátum.`);
    return null;
  }
  return p ? p.d : null;
}

const yes = (cell: XLSX.CellObject | undefined) => /^(a|áno|ano|y|yes|true|1)$/i.test(text(cell) ?? '');

type Sheet = { name: string; ws: XLSX.WorkSheet; cols: Map<string, number>; last: number };

/** Hárok s hlavičkou v prvom riadku; vráti mapu „hlavička → stĺpec“. */
function sheetOf(wb: XLSX.WorkBook, name: string): Sheet {
  const ws = wb.Sheets[name];
  const range = XLSX.utils.decode_range(ws['!ref'] ?? 'A1:A1');
  const cols = new Map<string, number>();
  for (let c = range.s.c; c <= range.e.c; c++) {
    const h = headKey(ws[XLSX.utils.encode_cell({ r: range.s.r, c })]?.v);
    if (h && !cols.has(h)) cols.set(h, c);
  }
  return { name, ws, cols, last: range.e.r };
}

/** Rozpozná zostavu podľa hlavičiek: Office portal (ZmluvaHlavicka_cislo) alebo XM Trade (EAN / EIC OM). */
export function parseContractImport(data: ArrayBuffer | Uint8Array): ParsedImport {
  const wb = XLSX.read(data, { type: 'array', cellDates: false, dense: false });
  const date1904 = !!wb.Workbook?.WBProps?.date1904;
  for (const name of wb.SheetNames) {
    const sh = sheetOf(wb, name);
    if (sh.cols.has('zmluvahlavicka_cislo')) return { source: 'office_portal', sheet: name, rows: officePortal(sh, date1904) };
    if (sh.cols.has('ean / eic om')) return { source: 'xm_trade', sheet: name, rows: xmTrade(sh, date1904) };
  }
  throw new Error('Súbor nie je export z Office portálu (Web Zmluvy – prehľad EE) ani z XM Trade (Prehľad OOM).');
}

function cellAt(sh: Sheet, r: number, key: string): XLSX.CellObject | undefined {
  const c = sh.cols.get(key);
  return c === undefined ? undefined : sh.ws[XLSX.utils.encode_cell({ r, c })];
}

const isEmptyRow = (sh: Sheet, r: number) => [...sh.cols.values()].every((c) => text(sh.ws[XLSX.utils.encode_cell({ r, c })]) === null);

function officePortal(sh: Sheet, date1904: boolean): OpRow[] {
  const rows: OpRow[] = [];
  for (let r = 1; r <= sh.last; r++) {
    if (isEmptyRow(sh, r)) continue;
    const e: string[] = [];
    const g = (k: string) => cellAt(sh, r, k);
    const unit = (text(g('mj')) ?? '').toLowerCase();
    const factor = unit === 'kwh' ? 0.001 : unit === 'mwh' ? 1 : null;
    if (factor === null) e.push(`Jednotka (MJ) „${text(g('mj')) ?? ''}“: čakám kWh alebo MWh.`);
    const mwh = (k: string, label: string) => {
      const v = num(g(k), label, e);
      return v === null ? null : Math.round(v * (factor ?? 1) * 1000) / 1000;
    };
    const household = (text(g('typosoby')) ?? '').toLowerCase().replace(/\s+/g, ' ') === 'domacnost';
    const opId = text(g('id'));
    const personId = text(g('osoba_id'));
    if (opId && !UUID_RE.test(opId)) e.push('ID zmluvy nie je platné ID z Office portálu.');
    if (personId && !UUID_RE.test(personId)) e.push('Osoba_ID nie je platné ID z Office portálu.');
    const powerUnit = (text(g('zom_zdroj_vykon_mj')) ?? 'kW').toLowerCase();
    const power = num(g('zom_zdroj_vykon'), 'Výkon zdroja', e);
    const upd = dateParts(g('greatest_updated_at'), date1904);
    if (upd === 'chyba') e.push('Greatest_updated_at nie je dátum.');
    rows.push({
      row: r + 1,
      op_id: opId,
      number: text(g('zmluvahlavicka_cislo')),
      test: yes(g('ano_test')),
      phase: text(g('zmluvastatus')),
      commodity: text(g('komodita')),
      household,
      // meno iba pri domácnosti (párovanie a založenie osoby); dátum narodenia sa nečíta
      first_name: household ? text(g('meno')) : null,
      last_name: household ? text(g('priezvisko')) : null,
      company_name: household ? null : text(g('ponazov')),
      ico: household ? null : (text(g('ico'))?.replace(/\s/g, '') ?? null),
      dic: household ? null : text(g('dic')),
      ic_dph: household ? null : text(g('ic_dph')),
      person_op_id: personId,
      eic: text(g('zom_eic'))?.replace(/\s/g, '').toUpperCase() ?? null,
      sum_mwh: mwh('spotreba_sum', 'Spotreba zmluvy'),
      qty_vt_mwh: mwh('zom_spotreba_1t_vt', 'Spotreba VT/1T'),
      qty_nt_mwh: mwh('zom_spotreba_nt', 'Spotreba NT'),
      source_power_kw: power === null ? null : powerUnit === 'mw' ? power * 1000 : power,
      tariff_pds: text(g('zom_nazov_tarifa_pds')),
      product_oom: text(g('zom_nazov_tarifa_glg')),
      price_product: text(g('zmluvazmluvneceny_nazov')),
      price_from: date(g('zzc_datum_od'), 'Cena od', e, date1904),
      price_to: date(g('zzc_datum_do'), 'Cena do', e, date1904),
      price_vt: num(g('cena_1t_vt_bez_dph'), 'Cena VT/1T', e),
      price_nt: num(g('cena_2t_nt_bez_dph'), 'Cena NT', e),
      small_business: yes(g('ano_maly_podnik')),
      list_price: yes(g('cennikova_cena')),
      auto_prolong: yes(g('ano_autoprolongacia')),
      valid_from: date(g('ucinnost_od'), 'Účinnosť od', e, date1904),
      valid_to: date(g('ucinnost_do'), 'Účinnosť do', e, date1904),
      signed_on: date(g('platnost_od'), 'Platnosť od', e, date1904),
      created_by_name: text(g('vytvorilnazov')),
      owner_name: text(g('obchodniknazov')),
      updated_at: upd && upd !== 'chyba' ? `${upd.d}T${upd.t}` : null,
      parse_errors: e,
    });
  }
  return rows;
}

const VOLTAGE: Record<string, string> = { nn: 'nn', vn: 'vn', vvn: 'vvn' };

function xmTrade(sh: Sheet, date1904: boolean): XmRow[] {
  const rows: XmRow[] = [];
  const year = new Date().getUTCFullYear();
  // predpokladaná spotreba: bežný rok, inak nasledujúci (kWh → MWh)
  const planYear = [year, year + 1].find((y) => sh.cols.has(`predpokladaná spotreba ${y} (jt/vt) [kwh]`));
  for (let r = 1; r <= sh.last; r++) {
    if (isEmptyRow(sh, r)) continue;
    const e: string[] = [];
    const g = (k: string) => cellAt(sh, r, k);
    const f: Record<string, string | number> = {};
    const put = (k: string, v: string | number | null) => {
      if (v !== null) f[k] = v;
    };
    const household = (text(g('typ odberu')) ?? '').toLowerCase().startsWith('domácnost');
    const supply = date(g('dátum začiatku dodávky'), 'Dátum začiatku dodávky', e, date1904)
      ?? date(g('platné od'), 'Platné od', e, date1904);
    const volt = text(g('napäťová úroveň'))?.toLowerCase() ?? null;
    if (volt && !VOLTAGE[volt]) e.push(`Napäťová úroveň „${volt}“: čakám nn, vn alebo vvn.`);
    put('name', text(g('názov')));
    put('address_street', text(g('ulica')));
    put('address_zip', text(g('psč')));
    put('address_city', text(g('obec')));
    put('pds', text(g('sústava')) ?? text(g('pds')));
    put('pds_point_id', text(g('identifikátor pds (číslo op)')));
    put('voltage_level', volt && VOLTAGE[volt] ? VOLTAGE[volt] : null);
    put('metering_type', text(g('typ merania')));
    put('phases', num(g('počet fáz'), 'Počet fáz', e));
    put('breaker_a', num(g('veľkosť ističa [a]'), 'Istič', e));
    put('reserved_capacity_kw', num(g('rezervovaná kapacita'), 'Rezervovaná kapacita', e));
    put('max_reserved_capacity_kw', num(g('maximálna rezervovaná kapacita [kw]'), 'Max. rezervovaná kapacita', e));
    put('capacity_reservation_method', text(g('spôsob rezervovania kapacity')));
    if (planYear) {
      const vt = num(g(`predpokladaná spotreba ${planYear} (jt/vt) [kwh]`), 'Predpokladaná spotreba VT', e);
      const nt = num(g(`predpokladaná spotreba ${planYear} (nt) [kwh]`), 'Predpokladaná spotreba NT', e);
      put('planned_consumption_vt_mwh', vt === null ? null : Math.round(vt) / 1000);
      put('planned_consumption_nt_mwh', nt === null ? null : Math.round(nt) / 1000);
    }
    put('supply_from', supply);
    put('excise_tax', text(g('spotrebná daň')));
    put('billing_period', text(g('fakturačné obdobie')));
    put('advance_payment_method', text(g('spôsob zálohových faktúr')));
    put('advance_payment_pct', num(g('percento zálohy 1'), 'Percento zálohy', e));
    put('tdo_class', text(g('trieda tdo')));
    // IČO iba firmy (8 číslic); pri domácnosti je v stĺpci rodné číslo – nečíta sa (rozhodnutie 9)
    const ico = household ? null : (text(g('ičo / rodné číslo'))?.replace(/\s/g, '') ?? null);
    rows.push({
      row: r + 1,
      eic: text(g('ean / eic om'))?.replace(/\s/g, '').toUpperCase() ?? null,
      contract_number: text(g('číslo zmluvy')) ?? text(g('evidované v zmluve')),
      ico: ico && /^\d{8}$/.test(ico) ? ico : null,
      household,
      supply_from: supply,
      direction: text(g('odber/dodávka')),
      product: text(g('produkt')),
      regulation: text(g('cenová regulácia')),
      tariff: text(g('sadzba')),
      address: household ? text(g('sídlo firmy / bydlisko')) : null,
      fields: f,
      parse_errors: e,
    });
  }
  return rows;
}
