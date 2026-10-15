// Modul 5 – schvaľovanie (obrazovka 39): pridelenie firmy (F1), výnimka z ceny ponuky, rizikový zákazník (konkurz /
// rating E/X) a predĺženie platnosti (F2). Kto žiadosť vidí a kto ju smie schváliť, stráži databáza (RLS na
// approval_request, funkcie approval_request_* / approval_decide / approval_cancel). Hranicu z odhadu portfólia
// a maržu vráti approval_price_detail iba s právom.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, readBody, str, uuid } from '../validate';

export const approvals = new Hono<AppEnv>();

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}

const TABS = ['caka', 'vynimka_ceny', 'rizikovy_zakaznik', 'predlzenie_platnosti', 'pridelenie_firmy', 'vybavene'] as const;

approvals.get('/approvals', async (c) => {
  const tab = (TABS as readonly string[]).includes(c.req.query('tab') ?? '') ? c.req.query('tab')! : 'caka';
  const items = await c.var.sql`
    SELECT a.id, a.kind, a.status, a.reason, a.decision_note, a.created_at, a.decided_at,
           a.company_id, c.name AS company_name, c.ico AS company_ico,
           a.requested_by, ru.name AS requested_by_name,
           a.from_owner_id, fu.name AS from_owner_name, du.name AS decided_by_name,
           a.deal_id, d.name AS deal_name, a.offer_id, offer_display_number(o) AS offer_number,
           a.valid_until, a.requested_valid_until, o.valid_until AS offer_valid_until, a.risk_snapshot, a.penalty_eur_mwh,
           CASE WHEN a.kind = 'vynimka_ceny' THEN
             (SELECT jsonb_agg(jsonb_build_object('year', x.year, 'price_model', x.price_model, 'voltage_group', x.voltage_group,
                                                  'requested_value', x.requested_value, 'threshold_value', x.threshold_value,
                                                  'approved_value', x.approved_value, 'volume_mwh', x.volume_mwh, 'variant', x.variant))
                FROM approval_price_detail(a.id) x) END AS items,
           a.status = 'caka' AND a.requested_by <> crm_active_user_id()
             AND CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END AS can_decide,
           a.status = 'caka' AND a.requested_by = crm_active_user_id() AS can_cancel
      FROM approval_request a
      LEFT JOIN company c ON c.id = a.company_id
      LEFT JOIN app_user ru ON ru.id = a.requested_by
      LEFT JOIN app_user fu ON fu.id = a.from_owner_id
      LEFT JOIN app_user du ON du.id = a.decided_by
      LEFT JOIN deal d ON d.id = a.deal_id
      LEFT JOIN offer o ON o.id = a.offer_id
     WHERE CASE ${tab}
             WHEN 'caka' THEN a.status = 'caka'
             WHEN 'vybavene' THEN a.status <> 'caka'
             ELSE a.kind::text = ${tab} END
     ORDER BY a.status = 'caka' DESC, a.created_at DESC
     LIMIT 300`;
  const counts = await c.var.sql`
    SELECT count(*) FILTER (WHERE status = 'caka')::int AS caka,
           count(*) FILTER (WHERE kind = 'vynimka_ceny')::int AS vynimka_ceny,
           count(*) FILTER (WHERE kind = 'rizikovy_zakaznik')::int AS rizikovy_zakaznik,
           count(*) FILTER (WHERE kind = 'predlzenie_platnosti')::int AS predlzenie_platnosti,
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
  // Výnimka: schválená hranica pre položky (môže byť iná, nie vyššia ako žiadaná – databáza)
  let items: Record<string, unknown>[] | null = null;
  if (Array.isArray(b.items)) {
    items = (b.items as Record<string, unknown>[]).slice(0, 200).map((x) => {
      const v = Number(String(x.approved_value ?? '').replace(/\s/g, '').replace(',', '.'));
      if (!UUID.test(String(x.variant_id)) || !Number.isFinite(v)) throw new BadRequest('Neplatná schválená hranica.');
      return { variant_id: x.variant_id, year: Number(x.year), price_model: String(x.price_model), voltage_group: String(x.voltage_group), approved_value: v };
    });
  }
  await c.var.sql`SELECT approval_decide(${approvalId}, ${b.approve}, ${note}, ${items ? c.var.sql.json(items as never) : null})`;
  return c.json({ ok: true });
});

approvals.post('/approvals/:id/cancel', async (c) => {
  const approvalId = id(c.req.param('id'));
  await c.var.sql`SELECT approval_cancel(${approvalId})`;
  return c.json({ ok: true });
});

// Detail žiadosti (pravý panel): položky výnimky (hranica a marža podľa práva), výstrahy Finstatu, iné čakajúce žiadosti obchodu
approvals.get('/approvals/:id', async (c) => {
  const approvalId = id(c.req.param('id'));
  const sql = c.var.sql;
  const [a] = await sql`
    SELECT a.id, a.kind, a.status, a.deal_id, a.offer_id, a.company_id, a.requested_by,
           CASE WHEN a.deal_id IS NOT NULL THEN
             (SELECT company_risk(d.company_id) FROM deal d WHERE d.id = a.deal_id AND d.company_id IS NOT NULL) END AS risk,
           (SELECT coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'kind', x.kind)), '[]') FROM approval_request x
             WHERE x.deal_id = a.deal_id AND x.id <> a.id AND x.status = 'caka') AS other_pending,
           crm_can_see_margin() AS see_margin
      FROM approval_request a WHERE a.id = ${approvalId}`;
  if (!a) return c.json({ error: 'Žiadosť neexistuje alebo ju nevidíte.' }, 404);
  const items = a.kind === 'vynimka_ceny' ? await sql`SELECT * FROM approval_price_detail(${approvalId})` : [];
  return c.json({ ...a, items });
});
