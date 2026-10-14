// Denník nočných behov zmlúv (0028, Nastavenia → Nočný beh): počty po krokoch, zmluvy so spätne zapísaným cenníkom
// (pre Nákup) a chyby jednotlivých zmlúv (krok, kód, text so skráteným EIC). Číta admin a Nákup (RLS na job_run).

import { Hono } from 'hono';
import type { AppEnv } from '../types';

export const jobRuns = new Hono<AppEnv>();

jobRuns.get('/job-runs', async (c) => {
  const sql = c.var.sql;
  const [row] = await sql<{ ok: boolean }[]>`SELECT crm_can_see_job_runs() AS ok`;
  if (!row?.ok) return c.json({ error: 'Denník nočných behov vidí admin a Nákup.' }, 403);
  const items = await sql`
    SELECT j.id, j.job, j.run_date, j.test_date, j.started_at, j.finished_at, j.result,
           coalesce((SELECT jsonb_agg(e || jsonb_build_object('cislo', k.number) ORDER BY e ->> 'krok', k.number)
                       FROM jsonb_array_elements(j.errors) e
                       LEFT JOIN contract k ON k.id = (e ->> 'zmluva')::uuid), '[]') AS errors
      FROM job_run j
     ORDER BY j.started_at DESC
     LIMIT 30`;
  return c.json({ items });
});
