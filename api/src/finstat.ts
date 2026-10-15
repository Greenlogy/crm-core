// Finstat API (modul 5, F1 – návrh DB časť 8, migrácia 0033).
// Volá ho iba Worker; kľúče FINSTAT_API_KEY a FINSTAT_PRIVATE_KEY sú iba vo wrangler secret / .dev.vars.
// Podpis požiadavky: SHA-256 z "SomeSalt+{apiKey}+{privateKey}++{IČO alebo dotaz}+ended" (rovnako ako verejný klient
// Finstatu), odpoveď JSON (adresa s príponou .json).
// Každá odpoveď ide do cache na 24 h (finstat_cache) a požiadavka sa započíta do denného limitu (finstat_request_allow).
// Do logu ide iba kód chyby, nikdy IČO, dotaz ani obsah odpovede.
//
// Polia overené skúšobným volaním (15. 10. 2026, licencia Ultimate): RevenueActual / ProfitActual / ActualYear,
// EmployeesNumber / EmployeeText, CreditScoreValue (Altmanovo Z-skóre; FinStat skóre a Index 05 majú vlastné polia),
// HasDebt, Debts, Bankrupt, Restructuring, PreventiveRestructuring, Liquidation (null = nie), Cancelled, Url.
// Platobný rating A–E/X Finstat neposiela – na firme ostáva hodnota z CRM (otázka na Petra).

import type { Sql } from './db';
import { BadRequest } from './validate';

export type FinstatEnv = {
  FINSTAT_API_KEY?: string;
  FINSTAT_PRIVATE_KEY?: string;
  /** úroveň detailu podľa licencie: detail / extended / ultimate (predvolene ultimate – licencia Greenlogy) */
  FINSTAT_LEVEL?: string;
};

const BASE = 'https://www.finstat.sk/api';

export class FinstatUnavailable extends Error {}

/** Údaje firmy z Finstatu v tvare pre company_apply_finstat a obrazovku 31 (bez osobných údajov okrem verejného registra). */
export type FinstatCompany = {
  ico: string;
  name: string | null;
  dic: string | null;
  ic_dph: string | null;
  address: string | null;
  city: string | null;
  legal_form: string | null;
  nace: string | null;
  registry_entry: string | null;
  founded_on: string | null;
  cancelled: boolean;
  cancelled_on: string | null;
  revenue_eur: number | null;
  profit_eur: number | null;
  finance_year: number | null;
  employees_range: string | null;
  z_score: number | null;
  payment_rating: string | null;
  has_debts: boolean | null;
  debts: { veritel: string; suma_eur: number | null; k_datumu: string | null }[];
  insolvency_kind: 'konkurz' | 'restrukturalizacia' | null;
  insolvency_since: string | null;
  finstat_url: string | null;
  fetched_at: string;
  from_cache: boolean;
};

export type FinstatSuggestion = { ico: string; name: string; city: string | null; cancelled: boolean };

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

function keys(env: FinstatEnv): { apiKey: string; privateKey: string } {
  if (!env.FINSTAT_API_KEY || !env.FINSTAT_PRIVATE_KEY) {
    throw new FinstatUnavailable('Finstat nie je nastavený (chýbajú kľúče).');
  }
  return { apiKey: env.FINSTAT_API_KEY, privateKey: env.FINSTAT_PRIVATE_KEY };
}

async function call(env: FinstatEnv, path: string, param: 'Ico' | 'Query', value: string): Promise<unknown> {
  const { apiKey, privateKey } = keys(env);
  const hash = await sha256Hex(`SomeSalt+${apiKey}+${privateKey}++${value}+ended`);
  const body = new URLSearchParams({ [param]: value, apiKey, Hash: hash, StationName: 'Greenlogy CRM' });
  const res = await fetch(`${BASE}/${path}.json`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', Accept: 'application/json' },
    body,
  });
  if (res.status === 404) return null; // firma neexistuje
  if (!res.ok) {
    console.error(`Finstat ${path}: HTTP ${res.status}`);
    throw new FinstatUnavailable(
      res.status === 402 || res.status === 403 ? 'Finstat odmietol požiadavku (licencia alebo limit).' : 'Finstat je nedostupný.',
    );
  }
  return res.json();
}

/** Povolí požiadavku podľa denného limitu (databáza ju započíta). */
async function allow(sql: Sql): Promise<void> {
  const [r] = await sql<{ ok: boolean }[]>`SELECT finstat_request_allow() AS ok`;
  if (!r?.ok) throw new FinstatUnavailable('Denný limit požiadaviek na Finstat je vyčerpaný. Skúste zajtra alebo použite údaje v CRM.');
}

// Cache: do databázy sa ukladá { at, raw } – čas načítania sa zobrazí („Údaje z Finstatu k …“)
async function cached(sql: Sql, kind: 'detail' | 'autocomplete', key: string): Promise<{ raw: unknown; at: string } | null> {
  const [r] = await sql<{ data: { raw: unknown; at: string } | null }[]>`SELECT finstat_cache_get(${kind}, ${key}) AS data`;
  return r?.data ?? null;
}

async function store(sql: Sql, kind: 'detail' | 'autocomplete', key: string, raw: unknown): Promise<string> {
  const at = new Date().toISOString();
  await sql`SELECT finstat_cache_put(${kind}, ${key}, ${sql.json({ at, raw } as never)})`;
  return at;
}

// --- Parser: odolný voči rôznym úrovniam licencie a názvom polí ---

type Obj = Record<string, unknown>;

function pick(o: Obj, ...names: string[]): unknown {
  const lower = new Map(Object.keys(o).map((k) => [k.toLowerCase(), k]));
  for (const n of names) {
    const k = lower.get(n.toLowerCase());
    if (k !== undefined && o[k] !== null && o[k] !== '') return o[k];
  }
  return undefined;
}
const asText = (v: unknown): string | null => (typeof v === 'string' ? v.trim() || null : typeof v === 'number' ? String(v) : null);
function asNum(v: unknown): number | null {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const n = Number(v.replace(/\s/g, '').replace(',', '.'));
    return Number.isFinite(n) ? n : null;
  }
  return null;
}
function asDate(v: unknown): string | null {
  const s = asText(v);
  const m = s?.match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : null;
}
const asBool = (v: unknown): boolean => v === true || v === 'true' || v === 1;

/** Posledný rok finančných údajov, ak ich licencia posiela ako zoznam rokov. */
function latestFinancials(o: Obj): Obj | null {
  const list = pick(o, 'Financials', 'FinancialData', 'IncomeStatements', 'Years');
  if (!Array.isArray(list) || list.length === 0) return null;
  return [...(list as Obj[])].sort((a, b) => (asNum(pick(b, 'Year')) ?? 0) - (asNum(pick(a, 'Year')) ?? 0))[0];
}

export function parseDetail(raw: unknown, ico: string, at: string, fromCache: boolean): FinstatCompany {
  const o = (raw ?? {}) as Obj;
  const fin = latestFinancials(o);
  const indicators = (pick(o, 'JudgementIndicators') as Obj[] | undefined) ?? [];
  const activeIndicator = (re: RegExp) =>
    indicators.find((i) => re.test(String(pick(i, 'Name') ?? '')) && asBool(pick(i, 'Value')));
  // Konkurz a reštrukturalizácia: samostatné polia (objekt / dátum / true), inak indikátory súdnych rozhodnutí
  const present = (v: unknown) => v !== undefined && v !== null && v !== false && v !== '';
  const bankruptRaw = pick(o, 'Bankrupt');
  const restructRaw = pick(o, 'Restructuring', 'PreventiveRestructuring');
  const bankruptcy = present(bankruptRaw) ? bankruptRaw : activeIndicator(/konkurz/i);
  const restructuring = present(restructRaw) ? restructRaw : activeIndicator(/re[sš]truktur/i);
  const sinceOf = (v: unknown): string | null =>
    typeof v === 'string' ? asDate(v) : v && typeof v === 'object' ? asDate(pick(v as Obj, 'Start', 'StartDate', 'Date', 'PublishDate', 'ValidFrom', 'From')) : null;

  const debtsRaw = (pick(o, 'Debts', 'DebtList') as Obj[] | undefined) ?? [];
  const debts = debtsRaw.map((d) => ({
    veritel: asText(pick(d, 'Source', 'Creditor', 'Name')) ?? 'neuvedený',
    suma_eur: asNum(pick(d, 'Value', 'Amount')),
    k_datumu: asDate(pick(d, 'ValidFrom', 'Date')),
  }));
  const hasDebtFlag = pick(o, 'HasDebt', 'HasDebts', 'Debt');

  const street = [asText(pick(o, 'Street')), asText(pick(o, 'StreetNumber'))].filter(Boolean).join(' ');
  const city = asText(pick(o, 'City'));
  const zip = asText(pick(o, 'ZipCode'));
  const address = [street, [zip, city].filter(Boolean).join(' ')].filter(Boolean).join(', ') || null;

  const rating = asText(pick(o, 'PaymentRating', 'CreditRating', 'Rating'));
  return {
    ico,
    name: asText(pick(o, 'Name')),
    dic: asText(pick(o, 'Dic')),
    ic_dph: asText(pick(o, 'IcDPH', 'IcDph')),
    address,
    city,
    legal_form: asText(pick(o, 'LegalFormText')),
    nace: [asText(pick(o, 'SkNaceCode')), asText(pick(o, 'SkNaceText'))].filter(Boolean).join(' ') || null,
    registry_entry: asText(pick(o, 'RegisterNumberText')),
    founded_on: asDate(pick(o, 'Created')),
    cancelled: present(pick(o, 'Cancelled')),
    cancelled_on: present(pick(o, 'Cancelled')) ? asDate(pick(o, 'Cancelled')) : null,
    revenue_eur: asNum(pick(o, 'RevenueActual') ?? (fin ? pick(fin, 'Revenue', 'Sales') : undefined)),
    profit_eur: asNum(pick(o, 'ProfitActual') ?? (fin ? pick(fin, 'Profit', 'NetProfit') : undefined)),
    finance_year: asNum(pick(o, 'ActualYear') ?? (fin ? pick(fin, 'Year') : undefined)),
    employees_range: asText(pick(o, 'EmployeesNumber')) ?? asText(pick(o, 'EmployeeText', 'EmployeeCode')),
    z_score: asNum(pick(o, 'CreditScoreValue', 'AltmanZScore', 'ZScore')),
    payment_rating: rating && /^[A-EX]$/i.test(rating) ? rating.toUpperCase() : null,
    has_debts: hasDebtFlag !== undefined ? asBool(hasDebtFlag) : debts.length > 0 ? true : null,
    debts,
    insolvency_kind: present(bankruptcy) ? 'konkurz' : present(restructuring) ? 'restrukturalizacia' : null,
    insolvency_since: present(bankruptcy) ? sinceOf(bankruptcy) : present(restructuring) ? sinceOf(restructuring) : null,
    finstat_url: asText(pick(o, 'Url')),
    fetched_at: at,
    from_cache: fromCache,
  };
}

/** Detail firmy podľa IČO (8 číslic): z cache 24 h, inak z Finstatu (započíta sa do limitu). null = firma neexistuje. */
export async function finstatDetail(sql: Sql, env: FinstatEnv, rawIco: string): Promise<FinstatCompany | null> {
  const ico = rawIco.replace(/\D/g, '').padStart(8, '0');
  if (!/^\d{8}$/.test(ico)) throw new BadRequest('IČO musí mať 8 číslic.');
  const hit = await cached(sql, 'detail', ico);
  if (hit) return hit.raw ? parseDetail(hit.raw, ico, hit.at, true) : null;
  await allow(sql);
  const level = ['detail', 'extended', 'ultimate'].includes(env.FINSTAT_LEVEL ?? '') ? env.FINSTAT_LEVEL! : 'ultimate';
  const raw = await call(env, level, 'Ico', ico);
  const at = await store(sql, 'detail', ico, raw ?? null);
  return raw ? parseDetail(raw, ico, at, false) : null;
}

/** Našepkávanie podľa názvu (od 3 znakov): z cache 24 h, inak z Finstatu. */
export async function finstatAutocomplete(sql: Sql, env: FinstatEnv, rawQuery: string): Promise<FinstatSuggestion[]> {
  const query = rawQuery.trim().replace(/\s+/g, ' ');
  if (query.length < 3) return [];
  const key = query.toLowerCase().slice(0, 200);
  const hit = await cached(sql, 'autocomplete', key);
  let raw: unknown = hit?.raw;
  if (!hit) {
    await allow(sql);
    raw = await call(env, 'autocomplete', 'Query', query);
    await store(sql, 'autocomplete', key, raw ?? []);
  }
  const o = (raw ?? {}) as Obj;
  const results = (Array.isArray(raw) ? raw : (pick(o, 'Results') as unknown[] | undefined) ?? []) as Obj[];
  return results.slice(0, 20).map((r) => ({
    ico: (asText(pick(r, 'Ico')) ?? '').padStart(8, '0'),
    name: asText(pick(r, 'Name')) ?? '',
    city: asText(pick(r, 'City')),
    cancelled: asBool(pick(r, 'Cancelled')),
  })).filter((r) => /^\d{8}$/.test(r.ico) && r.name);
}

/** Údaje pre company_apply_finstat (iba stĺpce Finstatu). */
export function finstatApplyData(f: FinstatCompany): Record<string, unknown> {
  return {
    revenue_eur: f.revenue_eur,
    profit_eur: f.profit_eur,
    finance_year: f.finance_year,
    employees_range: f.employees_range,
    founded_on: f.founded_on,
    z_score: f.z_score,
    has_debts: f.has_debts,
    debts: f.debts,
    insolvency_kind: f.insolvency_kind,
    insolvency_since: f.insolvency_since,
    cancelled_on: f.cancelled ? f.cancelled_on ?? f.fetched_at.slice(0, 10) : null,
    // platobný rating Finstat neposiela: kľúč sa vynechá a hodnota na firme ostane (0034)
    ...(f.payment_rating ? { payment_rating: f.payment_rating } : {}),
    finstat_url: f.finstat_url,
  };
}
