// Slovenský formát čísel a dátumov: medzera ako oddeľovač tisícov, čiarka ako desatinná, „8. 10. 2026“.

import type { Num } from './api';

export const EMPTY = '—';

const formatters = new Map<number, Intl.NumberFormat>();
function nf(maxDecimals: number, minDecimals = 0) {
  const key = maxDecimals * 10 + minDecimals;
  let f = formatters.get(key);
  if (!f) {
    f = new Intl.NumberFormat('sk-SK', { maximumFractionDigits: maxDecimals, minimumFractionDigits: minDecimals });
    formatters.set(key, f);
  }
  return f;
}

const toNumber = (v: Num | undefined) => {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
};

export function num(v: Num | undefined, maxDecimals = 2, unit?: string): string {
  const n = toNumber(v);
  if (n === null) return EMPTY;
  const s = nf(maxDecimals).format(n);
  return unit ? `${s} ${unit}` : s;
}

export const mwh = (v: Num | undefined) => num(v, 1, 'MWh');
export const kw = (v: Num | undefined) => num(v, 1, 'kW');
export const eurMwh = (v: Num | undefined) => {
  const n = toNumber(v);
  return n === null ? EMPTY : `${nf(4, 2).format(n)} €/MWh`;
};
export const eurMonth = (v: Num | undefined) => {
  const n = toNumber(v);
  return n === null ? EMPTY : `${nf(2, 2).format(n)} €/mes.`;
};
export const pct = (v: Num | undefined) => num(v, 2, '%');

// 'YYYY-MM-DD' alebo ISO čas → „8. 10. 2026“ (čas v Europe/Bratislava).
export function date(v: string | null | undefined): string {
  if (!v) return EMPTY;
  if (/^\d{4}-\d{2}-\d{2}$/.test(v)) {
    const [y, m, d] = v.split('-').map(Number);
    return `${d}. ${m}. ${y}`;
  }
  const dt = new Date(v);
  if (Number.isNaN(dt.getTime())) return EMPTY;
  const parts = new Intl.DateTimeFormat('sk-SK', {
    timeZone: 'Europe/Bratislava',
    day: 'numeric',
    month: 'numeric',
    year: 'numeric',
  }).formatToParts(dt);
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? '';
  return `${get('day')}. ${get('month')}. ${get('year')}`;
}

export const period = (from: string | null, to: string | null) => `${date(from)} – ${to ? date(to) : 'neurčito'}`;

export const text = (v: string | number | null | undefined) => (v === null || v === undefined || v === '' ? EMPTY : String(v));

export const sumNum = (...values: Num[]) => {
  const ns = values.map(toNumber).filter((n): n is number => n !== null);
  return ns.length ? ns.reduce((a, b) => a + b, 0) : null;
};

export function initials(name: string): string {
  const words = name.replace(/[,.]/g, ' ').split(/\s+/).filter(Boolean);
  return ((words[0]?.[0] ?? '') + (words[1]?.[0] ?? '')).toUpperCase() || '?';
}

// Čas poslednej aktivity: „dnes 11:42“, „včera“, inak dátum (Europe/Bratislava).
export function lastSeen(v: string | null | undefined): string {
  if (!v) return EMPTY;
  const dt = new Date(v);
  if (Number.isNaN(dt.getTime())) return EMPTY;
  const day = (d: Date) => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Bratislava' }).format(d);
  const today = day(new Date());
  const yesterday = day(new Date(Date.now() - 86_400_000));
  if (day(dt) === today) {
    const hm = new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', minute: '2-digit' }).format(dt);
    return `dnes ${hm}`;
  }
  if (day(dt) === yesterday) return 'včera';
  return date(v);
}
