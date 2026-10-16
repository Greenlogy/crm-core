// Lokálne testovacie odpovede Workera Montel (MONTEL_FAKE=1, iba `wrangler dev`): rovnaký tvar ako greenlogy-montel-auth,
// vymyslené hodnoty. Obsahujú aj polia, ktoré CRM nesmie použiť (štvrťroky, mesiace, ďalšie priemery SPOT).

import type { MontelPath } from './montel';

const YEARS = [2027, 2028, 2029, 2030];
const base = (y: number, i = 0) => Math.round((92 - (y - 2027) * 4.5 + Math.sin(i / 9) * 6) * 100) / 100;
const peak = (y: number, i = 0) => Math.round((base(y, i) + 14.3) * 100) / 100;

export function fakeMontel(path: MontelPath, days?: number): unknown {
  if (path === '/forwards/quotes') {
    const r: Record<string, unknown> = { fetchedAt: new Date().toISOString(), healthSummary: 'all_settlement', baseQ1: 101.2, peakQ1: 118.4, baseFM: 99.9 };
    for (const y of YEARS) {
      r[`base${y}`] = base(y);
      r[`peak${y}`] = peak(y);
    }
    return r;
  }
  if (path === '/spot/aggregates') {
    return { spotAvg365: 103.42, spotAvg30days: 88.1, spotAvg7days: 79.5, spotMin365: -12.4, spotMax365: 412.9, samplesTotal: 8760 };
  }
  // /forwards/ohlc/history: obchodné dni (po – pi) za posledných `days` dní
  const dates: string[] = [];
  const now = Date.now();
  for (let i = days ?? 1; i >= 1; i--) {
    const d = new Date(now - i * 86_400_000);
    if (d.getUTCDay() !== 0 && d.getUTCDay() !== 6) dates.push(d.toISOString().slice(0, 10));
  }
  const products = YEARS.flatMap((y) =>
    (['base', 'peak'] as const).map((k) => ({
      fieldName: `${k}${y}`,
      symbolKey: `EEX FY${k === 'base' ? 'B' : 'P'} CAL-${y}`,
      kind: 'year',
      records: dates.map((date, i) => ({ date, open: null, high: null, low: null, settlement: k === 'base' ? base(y, i) : peak(y, i), close: null, volume: 10 })),
    })),
  );
  products.push({ fieldName: 'baseQ1', symbolKey: 'EEX FYB Q1', kind: 'quarter', records: dates.map((date) => ({ date, open: null, high: null, low: null, settlement: 1, close: null, volume: 1 })) });
  return { fromDate: dates[0], toDate: dates[dates.length - 1], products };
}
