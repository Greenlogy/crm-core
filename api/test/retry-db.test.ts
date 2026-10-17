// Test F7 so skutočnou databázou (iba dočasný lokálny Postgres – spúšťa ho db/test/subeh-provizie.sh na kópii databázy):
// uplatnenie v withRetry, prvý pokus po zápise listu skončí deadlockom → databáza vráti celý pokus (aj počítadlo čísel),
// druhý pokus uplatní – výsledok: jeden list, jedno číslo CMSN (hneď po poslednom), položky na jednom liste.
// Bez CRM_TEST_DB_URL sa preskočí (npm test ho nespúšťa proti dev ani main).

import assert from 'node:assert/strict';
import { test } from 'node:test';
import postgres from 'postgres';
import { type Sql, withRetry } from '../src/db.ts';

const url = process.env.CRM_TEST_DB_URL;
const local = !!url && ['127.0.0.1', 'localhost'].includes(new URL(url).hostname);
const SELLER = '00000000-0000-4000-8000-000000a79001';
const ADMIN = '00000000-0000-4000-8000-000000a79002';

test('uplatnenie po deadlocku: jeden list a jedno číslo CMSN', { skip: !local && 'iba s CRM_TEST_DB_URL na lokálny Postgres' }, async () => {
  const sql = postgres(url!, { max: 2, onnotice: () => {} }) as unknown as Sql;
  try {
    // vyhratý obchod s kladnou čakajúcou províziou obchodníka zo skriptu súbehu
    const ids = (await sql<{ id: string }[]>`
      SELECT id FROM commission WHERE user_id = ${SELLER} AND status = 'caka' AND amount_eur > 0 AND base_missing IS NULL ORDER BY id LIMIT 2`).map((r) => r.id);
    assert.ok(ids.length > 0, 'fixture: čakajúce provízie obchodníka');
    const before = await sql<{ n: number; last: number }[]>`
      SELECT (SELECT count(*) FROM commission_claim)::int AS n,
             coalesce((SELECT last_value FROM doc_counter WHERE kind = 'provizny_list' AND year = extract(year FROM crm_today())), 0) AS last`;
    let attempts = 0;
    const claim = await withRetry(sql, SELLER, async (tx) => {
      await tx`SELECT set_config('app.require_user', 'on', true)`;
      attempts++;
      const [r] = await tx<{ id: string }[]>`SELECT commission_claim_create(${SELLER}, string_to_array(${ids.join(',')}, ',')::uuid[]) AS id`;
      if (attempts === 1) throw Object.assign(new Error('deadlock (test)'), { code: '40P01' });
      return r.id;
    });
    assert.equal(attempts, 2);
    const [after] = await sql<{ n: number; last: number; number: string; items: number }[]>`
      SELECT (SELECT count(*) FROM commission_claim)::int AS n,
             (SELECT last_value FROM doc_counter WHERE kind = 'provizny_list' AND year = extract(year FROM crm_today())) AS last,
             (SELECT number FROM commission_claim WHERE id = ${claim}) AS number,
             (SELECT count(*) FROM commission WHERE claim_id = ${claim})::int AS items`;
    assert.equal(after.n, before[0].n + 1, 'jeden nový list');
    assert.equal(after.last, before[0].last + 1, 'počítadlo čísel o jedno');
    assert.match(after.number, new RegExp(`-${String(before[0].last + 1).padStart(4, '0')}$`), 'číslo hneď po poslednom');
    assert.equal(after.items, ids.length, 'položky na jednom liste');
    // späť: admin list zruší (súbeh pokračuje s čakajúcimi províziami)
    await withRetry(sql, ADMIN, async (tx) => {
      await tx`SELECT set_config('app.require_user', 'on', true)`;
      await tx`SELECT commission_claim_void(${claim}, 'test opakovania')`;
    });
  } finally {
    await (sql as unknown as { end: () => Promise<void> }).end();
  }
});
