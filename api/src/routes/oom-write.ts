// Modul Odberné miesta, F2a – zmena stavu, prepis, návrat a plánované zmeny (zadanie čl. 15, migrácia 0016).
// Pravidlá stráži databáza: práva (RLS, „iba svoje“, upravovať Aktívne OOM), blokovanie aktívnym plánom,
// dátumy väzby. Ak deň zmeny už nastal, zmena sa urobí hneď; inak sa uloží plán (vykoná ho nočný beh).
// Dátum: prepis = prvý deň nového odberateľa; odchod a zrušenie = posledný deň dodávky.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, oneOf, readBody, uuid, type Body } from '../validate';

export const oomWrite = new Hono<AppEnv>();

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

const DATE = /^\d{4}-\d{2}-\d{2}$/;
function day(b: Body, key: string, label: string): string {
  const v = b[key];
  if (typeof v !== 'string' || !DATE.test(v) || Number.isNaN(Date.parse(v))) throw new BadRequest(`Chýba alebo je neplatný dátum: ${label}.`);
  return v;
}

/** Nový zákazník: práve jedno z company_id / person_id. */
function customer(b: Body): { company: string | null; person: string | null } {
  const company = uuid(b, 'company_id', 'Firma', true) ?? null;
  const person = uuid(b, 'person_id', 'Domácnosť', true) ?? null;
  if ((company === null) === (person === null)) throw new BadRequest('Vyberte práve jedného zákazníka (firmu alebo domácnosť).');
  return { company, person };
}

// Zmena stavu: aktivne (hneď, ak má povinné údaje), odidene / zrusene k poslednému dňu dodávky (hneď alebo plán).
oomWrite.post('/oom/:id/status', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const status = oneOf(b, 'status', 'Stav', ['aktivne', 'odidene', 'zrusene'] as const)!;
  if (!status) throw new BadRequest('Chýba stav.');
  if (status === 'aktivne') {
    await c.var.sql`SELECT oom_set_status(${oomId}, 'aktivne')`;
    return c.json({ executed: true, plan_id: null });
  }
  const date = day(b, 'date', 'Posledný deň dodávky');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`
    SELECT oom_plan_change(${oomId}, ${status === 'odidene' ? 'odchod' : 'zrusenie'}::oom_plan_kind, ${date}::date) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

// Prepis na iného odberateľa k prvému dňu nového odberateľa (hneď alebo plán).
oomWrite.post('/oom/:id/transfer', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const { company, person } = customer(b);
  const date = day(b, 'date', 'Prvý deň nového odberateľa');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`
    SELECT oom_plan_change(${oomId}, 'prepis', ${date}::date, ${company}::uuid, ${person}::uuid) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

// Návrat OOM k Greenlogy (odídené alebo zrušené): nová väzba Pripravované od dátumu.
oomWrite.post('/oom/:id/reconnect', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const { company, person } = customer(b);
  const date = day(b, 'date', 'Začiatok nového obdobia');
  await c.var.sql`SELECT oom_reconnect(${oomId}, ${company}::uuid, ${person}::uuid, ${date}::date)`;
  return c.json({ ok: true });
});

// Zmena dátumu plánu (ak deň už nastal, vykoná sa hneď) a zrušenie plánu (aj zlyhaného).
oomWrite.patch('/oom-plans/:id', async (c) => {
  const planId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const date = day(b, 'date', 'Dátum');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`SELECT oom_plan_reschedule(${planId}, ${date}::date) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

oomWrite.delete('/oom-plans/:id', async (c) => {
  const planId = id(c.req.param('id'));
  await c.var.sql`SELECT oom_plan_cancel(${planId})`;
  return c.json({ ok: true });
});

// Hľadanie zákazníka (firma alebo domácnosť) pre prepis a návrat: iba tí, ktorých používateľ vidí,
// v spoločnosti OOM (zákazník a OOM patria jednej spoločnosti skupiny).
oomWrite.get('/oom-customers', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const org = c.req.query('org') ?? '';
  if (!UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (q.length < 2) return c.json({ items: [] });
  const like = `%${q}%`;
  const rows = await c.var.sql`
    SELECT CASE cu.customer_type WHEN 'B2B' THEN 'company' ELSE 'person' END AS kind,
           cu.id, cu.name, cu.ico, cu.email, cu.status, cu.archived
      FROM customer_v cu
     WHERE cu.org_id = ${org}
       AND (cu.name ILIKE ${like} OR cu.ico LIKE ${q.replace(/\s/g, '') + '%'} OR cu.email ILIKE ${like})
     ORDER BY cu.archived, cu.name
     LIMIT 20`;
  return c.json({ items: rows });
});
