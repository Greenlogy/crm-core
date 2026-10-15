// Modul 5, F1 – schvaľovanie (obrazovka 39). V F1 iba pridelenie firmy; výnimky z ceny, rizikový zákazník
// a predĺženie platnosti pribudnú s ponukami (F2). Kto žiadosť vidí a kto ju smie schváliť, stráži databáza
// (RLS na approval_request, funkcie approval_request_assign / approval_decide / approval_cancel).

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, readBody, str, uuid } from '../validate';

export const approvals = new Hono<AppEnv>();

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}

const TABS = ['caka', 'pridelenie_firmy', 'vybavene'] as const;

approvals.get('/approvals', async (c) => {
  const tab = (TABS as readonly string[]).includes(c.req.query('tab') ?? '') ? c.req.query('tab')! : 'caka';
  const items = await c.var.sql`
    SELECT a.id, a.kind, a.status, a.reason, a.decision_note, a.created_at, a.decided_at,
           a.company_id, c.name AS company_name, c.ico AS company_ico,
           a.requested_by, ru.name AS requested_by_name,
           a.from_owner_id, fu.name AS from_owner_name, du.name AS decided_by_name,
           a.status = 'caka' AND a.requested_by <> crm_active_user_id()
             AND CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END AS can_decide,
           a.status = 'caka' AND a.requested_by = crm_active_user_id() AS can_cancel
      FROM approval_request a
      LEFT JOIN company c ON c.id = a.company_id
      LEFT JOIN app_user ru ON ru.id = a.requested_by
      LEFT JOIN app_user fu ON fu.id = a.from_owner_id
      LEFT JOIN app_user du ON du.id = a.decided_by
     WHERE CASE ${tab}
             WHEN 'caka' THEN a.status = 'caka'
             WHEN 'vybavene' THEN a.status <> 'caka'
             ELSE a.kind::text = ${tab} END
     ORDER BY a.status = 'caka' DESC, a.created_at DESC
     LIMIT 300`;
  const counts = await c.var.sql`
    SELECT count(*) FILTER (WHERE status = 'caka')::int AS caka,
           count(*) FILTER (WHERE kind = 'pridelenie_firmy')::int AS pridelenie_firmy,
           count(*) FILTER (WHERE status <> 'caka')::int AS vybavene
      FROM approval_request`;
  return c.json({ items, counts: counts[0] });
});

// Počítadlo v menu: čakajúce žiadosti, ktoré prihlásený smie schváliť
approvals.get('/approvals/count', async (c) => {
  const [r] = await c.var.sql<{ n: number }[]>`
    SELECT count(*)::int AS n FROM approval_request a
     WHERE a.status = 'caka' AND a.requested_by <> crm_active_user_id()
       AND CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END`;
  return c.json({ pending: r?.n ?? 0 });
});

// Žiadosť o pridelenie firmy (obchodník, ktorý firmu nevlastní) – s dôvodom
approvals.post('/approvals', async (c) => {
  const b = await readBody(c.req);
  if (b.kind !== 'pridelenie_firmy') throw new BadRequest('Teraz sa dá požiadať iba o pridelenie firmy.');
  const reason = str(b, 'reason', 'Dôvod', { max: 2000 })!;
  const company = uuid(b, 'company_id', 'Firma', true);
  // Firmu iného obchodníka používateľ nevidí (RLS) – žiadosť ide podľa IČO (0034)
  const ico = typeof b.ico === 'string' ? b.ico.replace(/\s/g, '') : '';
  if (!company && !/^\d{6,8}$/.test(ico)) throw new BadRequest('Vyberte firmu.');
  const [row] = company
    ? await c.var.sql<{ id: string }[]>`SELECT approval_request_assign(${company}, ${reason}) AS id`
    : await c.var.sql<{ id: string }[]>`SELECT approval_request_assign_ico(${ico}, ${reason}) AS id`;
  return c.json({ id: row.id }, 201);
});

approvals.post('/approvals/:id/decide', async (c) => {
  const approvalId = id(c.req.param('id'));
  const b = await readBody(c.req);
  if (typeof b.approve !== 'boolean') throw new BadRequest('Chýba rozhodnutie.');
  const note = str(b, 'note', 'Poznámka', { max: 2000, optional: true }) || null;
  await c.var.sql`SELECT approval_decide(${approvalId}, ${b.approve}, ${note})`;
  return c.json({ ok: true });
});

approvals.post('/approvals/:id/cancel', async (c) => {
  const approvalId = id(c.req.param('id'));
  await c.var.sql`SELECT approval_cancel(${approvalId})`;
  return c.json({ ok: true });
});
