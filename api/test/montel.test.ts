// Testy F6 – ceny z Workera Montel a čas behu cien (čisté funkcie, bez siete a databázy). Spustenie: cd api && npm test
// Peter 16. 10.: iba tri povolené GET adresy; do CRM iba BL / PL rokov dodávky a 12-mesačný priemer SPOT;
// beh po – pi o 7:00 a 13:00 v Bratislave v zimnom aj letnom čase.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
  extractHistory, extractQuotes, extractSpotAvg, historyDays, MONTEL_PATHS, MontelError, montelGet, montelUrl, priceDayOf,
} from '../src/montel.ts';
import { isPriceSlot, PRICE_CRON } from '../src/schedule.ts';

test('povolené sú iba tri adresy Montelu', () => {
  assert.deepEqual([...MONTEL_PATHS], ['/forwards/quotes', '/forwards/ohlc/history', '/spot/aggregates']);
  assert.equal(montelUrl('/forwards/quotes'), 'https://montel.internal/forwards/quotes');
  assert.equal(montelUrl('/spot/aggregates'), 'https://montel.internal/spot/aggregates');
  assert.equal(montelUrl('/forwards/ohlc/history', 300), 'https://montel.internal/forwards/ohlc/history?days=300');
  for (const bad of ['/spot/history', '/forwards/quotes/', '/forwards/quotes?debug=1', '/forwards/quotes/../spot/history', '/health', '/token', '']) {
    assert.throws(() => montelUrl(bad as never), /Nepovolená/, bad);
  }
  assert.throws(() => montelUrl('/forwards/ohlc/history'), /days/);
  assert.throws(() => montelUrl('/forwards/ohlc/history', 1001), /days/);
  assert.throws(() => montelUrl('/forwards/ohlc/history', 2.5), /days/);
  assert.throws(() => montelUrl('/forwards/quotes', 5), /days/);
});

type Call = { url: string; init?: RequestInit };
function fetcher(res: () => Response, calls: Call[]): Fetcher {
  return { fetch: async (url: string, init?: RequestInit) => (calls.push({ url, init }), res()) } as unknown as Fetcher;
}

test('volanie: GET s kľúčom v hlavičke, chyba bez textu odpovede', async () => {
  const calls: Call[] = [];
  const env = { MONTEL: fetcher(() => Response.json({ base2027: 90 }), calls), MONTEL_API_KEY: 'k-test' };
  assert.deepEqual(await montelGet(env, '/forwards/quotes'), { base2027: 90 });
  assert.equal(calls.length, 1);
  assert.equal(calls[0].url, 'https://montel.internal/forwards/quotes');
  assert.equal(calls[0].init?.method, 'GET');
  assert.equal((calls[0].init?.headers as Record<string, string>)['X-API-Key'], 'k-test');
  assert.equal(calls[0].init?.body, undefined);

  const bad = { MONTEL: fetcher(() => new Response('tajný text 401 Unauthorized k-test', { status: 401 }), []), MONTEL_API_KEY: 'k-test' };
  await assert.rejects(montelGet(bad, '/spot/aggregates'), (e: unknown) => {
    assert.ok(e instanceof MontelError);
    assert.equal(e.kod, 'HTTP 401');
    assert.ok(!e.message.includes('tajný') && !e.message.includes('k-test'));
    return true;
  });
  await assert.rejects(montelGet({ MONTEL_API_KEY: 'k' }, '/forwards/quotes'), (e: unknown) => e instanceof MontelError && e.kod === 'nenastavené');
  await assert.rejects(montelGet({ MONTEL: fetcher(() => Response.json({}), []) }, '/forwards/quotes'), /nenastavené/);
  const html = { MONTEL: fetcher(() => new Response('<html>', { status: 200 }), []), MONTEL_API_KEY: 'k' };
  await assert.rejects(montelGet(html, '/forwards/quotes'), (e: unknown) => e instanceof MontelError && e.kod === 'neplatná odpoveď');
});

test('z /forwards/quotes iba BL a PL rokov dodávky s oboma hodnotami', () => {
  const quotes = {
    fetchedAt: '2026-10-16T05:00:01Z', healthSummary: 'all_settlement', tokenCached: true,
    base2027: 92.15, peak2027: 106.45, base2028: 87.6, peak2028: 101.9, base2029: 84, peak2029: null, peak2030: 99,
    baseQ1: 101.2, peakQ1: 118.4, baseFM: 99.9, 'baseQ1-27': 100, base2031: -5, peak2031: 10, base2032: '90', peak2032: 100,
    _debug: { products: [{ settlement: 1 }] },
  };
  assert.deepEqual(extractQuotes(quotes), [
    { year: 2027, bl: 92.15, pl: 106.45 },
    { year: 2028, bl: 87.6, pl: 101.9 },
  ]);
  assert.deepEqual(extractQuotes(null), []);
  assert.deepEqual(extractQuotes([1, 2]), []);
});

test('z /spot/aggregates iba 12-mesačný priemer', () => {
  assert.equal(extractSpotAvg({ spotAvg365: 103.42, spotAvg30days: 88, spotMin365: -12 }), 103.42);
  assert.equal(extractSpotAvg({ spotAvg30days: 88 }), null);
  assert.equal(extractSpotAvg({ spotAvg365: Number.NaN }), null);
  assert.equal(extractSpotAvg({ spotAvg365: '103' }), null);
});

test('história: settlement ročných produktov dňa T je cenou dňa T + 1, od 1. 1. 2026 po dnes', () => {
  assert.equal(priceDayOf('2026-01-30'), '2026-01-31');
  assert.equal(priceDayOf('2025-12-31'), '2026-01-01');
  const rec = (date: string, settlement: unknown) => ({ date, open: 1, high: 2, low: 0, settlement, close: 3, volume: 10, openInterest: 5 });
  const json = {
    fromDate: '2025-12-20', toDate: '2026-10-15',
    products: [
      { fieldName: 'base2027', kind: 'year', records: [rec('2025-12-30', 80), rec('2025-12-31', 81), rec('2026-01-02', 82), rec('2026-10-16', 99)] },
      { fieldName: 'peak2027', kind: 'year', records: [rec('2025-12-31', 95), rec('2026-01-02', 96), rec('2026-10-16', 110)] },
      { fieldName: 'base2028', kind: 'year', records: [rec('2026-01-02', 70)] },
      { fieldName: 'peak2028', kind: 'year', records: [rec('2026-01-02', null)] },
      { fieldName: 'baseQ1', kind: 'quarter', records: [rec('2026-01-02', 1)] },
      { fieldName: 'peakQ1', kind: 'quarter', records: [rec('2026-01-02', 1)] },
      { fieldName: 'base2029', kind: 'month', records: [rec('2026-01-02', 1)] },
    ],
  };
  assert.deepEqual(extractHistory(json, '2026-01-01', '2026-10-16'), [
    { on_date: '2026-01-01', rows: [{ year: 2027, bl: 81, pl: 95 }] },
    { on_date: '2026-01-03', rows: [{ year: 2027, bl: 82, pl: 96 }] },
  ]);
  assert.deepEqual(extractHistory({}, '2026-01-01', '2026-10-16'), []);
  assert.equal(historyDays('2026-10-16'), 293);
  assert.equal(historyDays('2030-01-01'), 1000);
});

test('beh cien po – pi o 7:00 a 13:00 v Bratislave (zimný aj letný čas)', () => {
  const at = (iso: string) => Date.parse(iso);
  // zima (UTC+1): 6:00 a 12:00 UTC áno, 5:00 a 11:00 UTC nie
  assert.equal(isPriceSlot(at('2027-01-15T06:00:00Z')), true);
  assert.equal(isPriceSlot(at('2027-01-15T12:00:00Z')), true);
  assert.equal(isPriceSlot(at('2027-01-15T05:00:00Z')), false);
  assert.equal(isPriceSlot(at('2027-01-15T11:00:00Z')), false);
  // leto (UTC+2): 5:00 a 11:00 UTC áno, 6:00 a 12:00 UTC nie
  assert.equal(isPriceSlot(at('2027-07-15T05:00:00Z')), true);
  assert.equal(isPriceSlot(at('2027-07-15T11:00:00Z')), true);
  assert.equal(isPriceSlot(at('2027-07-15T06:00:00Z')), false);
  assert.equal(isPriceSlot(at('2027-07-15T12:00:00Z')), false);
  // pondelok po zmene času (28. 3. 2027 na letný, 25. 10. 2026 na zimný)
  assert.equal(isPriceSlot(at('2027-03-29T05:00:00Z')), true);
  assert.equal(isPriceSlot(at('2027-03-29T06:00:00Z')), false);
  assert.equal(isPriceSlot(at('2026-10-26T06:00:00Z')), true);
  assert.equal(isPriceSlot(at('2026-10-26T05:00:00Z')), false);
  // víkend nie; oneskorené spustenie (do 30 minút) áno
  assert.equal(isPriceSlot(at('2027-01-16T06:00:00Z')), false);
  assert.equal(isPriceSlot(at('2027-01-15T06:12:00Z')), true);
  assert.equal(isPriceSlot(at('2027-01-15T06:45:00Z')), false);
});

test('celý rok spustení Cronu: každý pracovný deň presne dva behy (7:00 a 13:00), cez víkend žiadny', () => {
  assert.equal(PRICE_CRON, '0 5,6,11,12 * * 1-5');
  assert.ok(readFileSync(new URL('../wrangler.toml', import.meta.url), 'utf8').includes(`"${PRICE_CRON}"`), 'Cron vo wrangler.toml');
  const local = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Bratislava', dateStyle: 'short', timeStyle: 'short' });
  const perDay = new Map<string, string[]>();
  for (let t = Date.parse('2026-10-01T00:00:00Z'); t < Date.parse('2027-11-01T00:00:00Z'); t += 3_600_000) {
    const d = new Date(t);
    const dow = d.getUTCDay();
    if (dow === 0 || dow === 6 || ![5, 6, 11, 12].includes(d.getUTCHours())) continue;   // časy Cronu (UTC)
    if (!isPriceSlot(t)) continue;
    const [day, time] = local.format(d).split(' ');
    perDay.set(day, [...(perDay.get(day) ?? []), time]);
  }
  for (const [day, times] of perDay) assert.deepEqual(times, ['07:00', '13:00'], day);
  // každý pracovný deň (po – pi) od 1. 10. 2026 do 31. 10. 2027 má beh
  let weekdays = 0;
  for (let t = Date.parse('2026-10-01T12:00:00Z'); t < Date.parse('2027-11-01T00:00:00Z'); t += 86_400_000) {
    if (![0, 6].includes(new Date(t).getUTCDay())) weekdays++;
  }
  assert.equal(perDay.size, weekdays);
});
