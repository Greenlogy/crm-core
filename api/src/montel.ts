// Modul 5, F6 – ceny z Workera greenlogy-montel-auth (návrh DB časť 36.1; Peter 16. 10.).
// Spojenie iba cez service binding MONTEL (bez verejnej adresy), kľúč MONTEL_API_KEY iba vo wrangler secret.
// Povolené sú iba tri GET adresy (MONTEL_PATHS); kontroluje ich test a `npm run typecheck` (scripts/check-montel.mjs).
// Z odpovedí sa vyberú iba BL / PL rokov dodávky a priemer SPOT od 1. 1. aktuálneho roka (0057) – celé odpovede sa neukladajú ani nelogujú.

export type MontelEnv = {
  MONTEL?: Fetcher;          // service binding na Worker greenlogy-montel-auth
  MONTEL_API_KEY?: string;   // wrangler secret (zadáva Peter)
  MONTEL_FAKE?: string;      // '1' = lokálne testovacie odpovede bez Montelu (iba `wrangler dev`)
};

export const MONTEL_PATHS = ['/forwards/quotes', '/forwards/ohlc/history', '/spot/aggregates'] as const;
export type MontelPath = (typeof MONTEL_PATHS)[number];

/** Chyba spojenia s Montelom: iba kód a adresa, nikdy text odpovede. */
export class MontelError extends Error {
  readonly kod: string;
  readonly path: MontelPath;
  constructor(kod: string, path: MontelPath) {
    super(`Montel ${path}: ${kod}`);
    this.name = 'MontelError';
    this.kod = kod;
    this.path = path;
  }
}

/** Adresa požiadavky: iba povolená cesta; `days` (1–1000) iba pri histórii. Hostiteľ je iba formálny (service binding). */
export function montelUrl(path: MontelPath, days?: number): string {
  if (!(MONTEL_PATHS as readonly string[]).includes(path)) throw new Error('Nepovolená adresa Montelu.');
  const u = new URL(`https://montel.internal${path}`);
  if (path === '/forwards/ohlc/history') {
    if (days === undefined || !Number.isInteger(days) || days < 1 || days > 1000) throw new Error('História Montelu: days 1 až 1000.');
    u.searchParams.set('days', String(days));
  } else if (days !== undefined) {
    throw new Error('Parameter days iba pri histórii.');
  }
  return u.toString();
}

/** Jediné volanie Montelu v kóde: GET na povolenú cestu s kľúčom v hlavičke X-API-Key. */
export async function montelGet(env: MontelEnv, path: MontelPath, days?: number): Promise<unknown> {
  const address = montelUrl(path, days);
  if (env.MONTEL_FAKE === '1') return (await import('./montel-fake')).fakeMontel(path, days);
  if (!env.MONTEL || !env.MONTEL_API_KEY) throw new MontelError('nenastavené', path);
  let res: Response;
  try {
    res = await env.MONTEL.fetch(address, { method: 'GET', headers: { 'X-API-Key': env.MONTEL_API_KEY, Accept: 'application/json' } });
  } catch {
    throw new MontelError('nedostupný', path);
  }
  if (!res.ok) {
    await res.body?.cancel();
    throw new MontelError(`HTTP ${res.status}`, path);
  }
  try {
    return await res.json();
  } catch {
    throw new MontelError('neplatná odpoveď', path);
  }
}

export type YearPrice = { year: number; bl: number; pl: number };
export type HistoryDay = { on_date: string; rows: YearPrice[] };

const num = (v: unknown): number | null => (typeof v === 'number' && Number.isFinite(v) && v >= 0 && v <= 10000 ? v : null);
const obj = (v: unknown): Record<string, unknown> => (v && typeof v === 'object' && !Array.isArray(v) ? (v as Record<string, unknown>) : {});

/** /forwards/quotes: BL (baseRRRR) a PL (peakRRRR) rokov dodávky, iba roky s oboma hodnotami. Ostatné polia sa ignorujú. */
export function extractQuotes(json: unknown): YearPrice[] {
  const o = obj(json);
  const out: YearPrice[] = [];
  for (const k of Object.keys(o)) {
    const m = /^base(\d{4})$/.exec(k);
    if (!m) continue;
    const bl = num(o[k]);
    const pl = num(o[`peak${m[1]}`]);
    if (bl !== null && pl !== null) out.push({ year: Number(m[1]), bl, pl });
  }
  return out.sort((a, b) => a.year - b.year);
}

/** /spot/aggregates: iba priemer SPOT od 1. 1. aktuálneho roka po dnes (spotAvgYTD; Peter 17. 10., predtým spotAvg365). */
export function extractSpotAvg(json: unknown): number | null {
  return num(obj(json).spotAvgYTD);
}

/** Deň ceny v CRM k obchodnému dňu settlementu: settlement dňa T je ráno dňa T + 1 cenou dňa (ako pri dennom behu). */
export function priceDayOf(tradeDate: string): string {
  const d = new Date(`${tradeDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}

/**
 * /forwards/ohlc/history: settlement ročných produktov (baseRRRR / peakRRRR) po dňoch → ceny dňa od `from` do `to`.
 * Mesačné a štvrťročné produkty, objemy a ostatné polia sa ignorujú; deň bez BL aj PL roka sa vynechá.
 */
export function extractHistory(json: unknown, from: string, to: string): HistoryDay[] {
  const products = obj(json).products;
  const byDay = new Map<string, Map<number, { bl?: number; pl?: number }>>();
  for (const p of Array.isArray(products) ? products : []) {
    const po = obj(p);
    const m = typeof po.fieldName === 'string' ? /^(base|peak)(\d{4})$/.exec(po.fieldName) : null;
    if (po.kind !== 'year' || !m || !Array.isArray(po.records)) continue;
    const year = Number(m[2]);
    for (const r of po.records) {
      const ro = obj(r);
      const v = num(ro.settlement);
      if (typeof ro.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(ro.date) || v === null) continue;
      const day = priceDayOf(ro.date);
      if (day < from || day > to) continue;
      const years = byDay.get(day) ?? new Map<number, { bl?: number; pl?: number }>();
      const y = years.get(year) ?? {};
      if (m[1] === 'base') y.bl = v;
      else y.pl = v;
      years.set(year, y);
      byDay.set(day, years);
    }
  }
  return [...byDay.entries()]
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([on_date, years]) => ({
      on_date,
      rows: [...years.entries()]
        .filter(([, y]) => y.bl !== undefined && y.pl !== undefined)
        .map(([year, y]) => ({ year, bl: y.bl as number, pl: y.pl as number }))
        .sort((a, b) => a.year - b.year),
    }))
    .filter((d) => d.rows.length > 0);
}

/** Začiatok histórie cien v CRM (Peter: od 1. 1. 2026). */
export const HISTORY_FROM = '2026-01-01';

/** Počet dní histórie pre Montel: od posledného obchodného dňa pred HISTORY_FROM po dnes (najviac 1000). */
export function historyDays(today: string): number {
  const ms = Date.parse(`${today}T00:00:00Z`) - Date.parse(`${HISTORY_FROM}T00:00:00Z`);
  return Math.min(1000, Math.max(1, Math.round(ms / 86_400_000) + 5));
}
