// Testy F7 – opakovanie transakcie po deadlocku a chybe serializácie (withRetry, Peter 17. 10.): opakuje sa celá
// transakcia, najviac raz; iné chyby sa neopakujú. Bez databázy (náhradné pripojenie). Spustenie: cd api && npm test
// Test so skutočnou databázou (jeden list a jedno číslo CMSN po opakovaní): test/retry-db.test.ts cez db/test/subeh-provizie.sh.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { isRetryable, type Sql, withRetry } from '../src/db.ts';

function fakeSql(failures: unknown[]): { sql: Sql; begins: () => number } {
  let begins = 0;
  const sql = {
    begin: async (fn: (tx: unknown) => Promise<unknown>) => {
      begins++;
      const f = failures.shift();
      if (f) throw f;
      return fn({});
    },
  } as unknown as Sql;
  return { sql, begins: () => begins };
}

test('deadlock 40P01 a serializácia 40001 sa opakujú, iné chyby nie', () => {
  assert.equal(isRetryable({ code: '40P01' }), true);
  assert.equal(isRetryable({ code: '40001' }), true);
  for (const code of ['23505', '42501', 'P0001', '57014', undefined]) assert.equal(isRetryable({ code }), false);
  assert.equal(isRetryable(null), false);
});

test('po deadlocku sa celá transakcia spustí ešte raz a vráti výsledok', async () => {
  const { sql, begins } = fakeSql([{ code: '40P01' }]);
  assert.equal(await withRetry(sql, null, async () => 'ok'), 'ok');
  assert.equal(begins(), 2);
});

test('najviac raz: druhý deadlock sa vráti volajúcemu', async () => {
  const { sql, begins } = fakeSql([{ code: '40P01' }, { code: '40001' }]);
  await assert.rejects(withRetry(sql, null, async () => 'ok'), (e: { code?: string }) => e.code === '40001');
  assert.equal(begins(), 2);
});

test('chyba z pravidiel CRM sa neopakuje', async () => {
  const { sql, begins } = fakeSql([{ code: '23514', message: 'Súčet listu musí byť aspoň 0 €' }]);
  await assert.rejects(withRetry(sql, null, async () => 'ok'), (e: { code?: string }) => e.code === '23514');
  assert.equal(begins(), 1);
});
