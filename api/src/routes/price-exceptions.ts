// Modul Zmluvy, F3 – výnimky z ceny (obrazovka 28; zadanie časť 7, návrh DB časť 5 a 26).
// Obchodník požiada pri svojom zákazníkovi; hranicu (cena pre obchodníka dnes / minimálny aditív) doplní databáza.
// Schvaľuje alebo zamieta iba „schvaľuje ceny“ a nie autor (databáza). Schválená platí 30 dní na podpis a pri importe
// (alebo hneď po schválení) sa spáruje so zmluvou zákazníka – stane sa hranicou pre pridanú hodnotu (0027).
// Čo kto vidí, rieši RLS (autor, „schvaľuje ceny“ a tímy so všetkými zmluvami, admin).

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, oneOf, readBody, str } from '../validate';

export const priceExceptions = new Hono<AppEnv>();

const STATES = ['caka', 'schvalena', 'zamietnuta', 'pouzita', 'expirovana'] as const;
const MODELS = ['fix', 'spot_plus_eur', 'spot_minus_eur'] as const;

priceExceptions.get('/price-exceptions', async (c) => {
  const sql = c.var.sql;
  const state = c.req.query('stav') ?? '';
  if (state && !(STATES as readonly string[]).includes(state)) throw new BadRequest('Neznámy stav.');
  const items = await sql`
    SELECT e.id, e.company_id, e.person_id, e.customer_name, to_jsonb(e.years) AS years, e.price_model, e.requested_value, e.threshold_value,
           e.volume_mwh, e.reason, e.state, e.requested_by, e.requested_by_name, e.decided_by_name, e.decided_at,
           e.decision_note, e.valid_until, e.created_at, e.contract_id, k.number AS contract_number,
           trader_price(e.org_id, (SELECT min(y) FROM unnest(e.years) y)::smallint, crm_today()) AS trader_price_today,
           CASE WHEN crm_can_see_margin() THEN
             (SELECT m.portfolio_eur_mwh FROM market_price_daily m
               WHERE m.org_id = e.org_id AND m.delivery_year = (SELECT min(y) FROM unnest(e.years) y)
                 AND m.corrected_at IS NULL AND m.portfolio_eur_mwh IS NOT NULL AND m.on_date <= crm_today()
               ORDER BY m.on_date DESC LIMIT 1) END AS portfolio_today,
           (e.state = 'caka' AND crm_approves_prices() AND e.requested_by IS DISTINCT FROM crm_active_user_id()) AS can_decide,
           (e.state = 'caka' AND e.requested_by = crm_active_user_id()) AS can_delete
      FROM price_exception_v e
      LEFT JOIN contract k ON k.id = e.contract_id
     WHERE ${state} = '' OR e.state = ${state}
     ORDER BY (e.state = 'caka') DESC, e.created_at DESC
     LIMIT 500`;
  const counts = await sql`SELECT state, count(*)::int AS n FROM price_exception_v GROUP BY state`;
  const [me] = await sql<{ approves: boolean; margin: boolean }[]>`
    SELECT crm_approves_prices() AS approves, crm_can_see_margin() AS margin`;
  return c.json({
    items,
    counts: Object.fromEntries([['all', counts.reduce((n, r) => n + (r.n as number), 0)], ...counts.map((r) => [r.state, r.n])]),
    approves: me?.approves ?? false,
    margin: me?.margin ?? false,
  });
});

// Nová žiadosť: zákazník (firma alebo domácnosť), roky dodávky, model, žiadaná cena / aditív, objem, dôvod
priceExceptions.post('/price-exceptions', async (c) => {
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const customer = typeof b.customer_id === 'string' && UUID.test(b.customer_id) ? b.customer_id : '';
  if (!customer) throw new BadRequest('Vyberte zákazníka.');
  const model = oneOf(b, 'price_model', 'Model ceny', MODELS);
  if (!model) throw new BadRequest('Vyberte model ceny.');
  const years = Array.isArray(b.years) ? [...new Set((b.years as unknown[]).map(Number))].sort() : [];
  if (years.length === 0 || years.some((y) => !Number.isInteger(y) || y < 2020 || y > 2100)) throw new BadRequest('Vyberte roky dodávky.');
  const value = Number(String(b.requested_value ?? '').replace(',', '.').replace(/\s/g, ''));
  if (!Number.isFinite(value)) throw new BadRequest('Žiadaná cena / aditív: neplatné číslo.');
  const volume = b.volume_mwh === undefined || b.volume_mwh === null || b.volume_mwh === ''
    ? null : Number(String(b.volume_mwh).replace(',', '.').replace(/\s/g, ''));
  if (volume !== null && (!Number.isFinite(volume) || volume < 0)) throw new BadRequest('Objem: neplatné číslo.');
  const reason = str(b, 'reason', 'Dôvod', { max: 2000 })!;
  const [kind] = await sql<{ company: boolean; person: boolean }[]>`
    SELECT EXISTS (SELECT 1 FROM company WHERE id = ${customer}) AS company, EXISTS (SELECT 1 FROM contact WHERE id = ${customer}) AS person`;
  if (!kind?.company && !kind?.person) throw new BadRequest('Zákazník neexistuje alebo k nemu nemáte prístup.');
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO price_exception (company_id, person_id, years, price_model, requested_value, threshold_value, volume_mwh, reason)
    VALUES (${kind.company ? customer : null}, ${kind.company ? null : customer}, ${years}::smallint[], ${model}::price_model,
            ${value}, 0, ${volume}, ${reason})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Rozhodnutie: schváliť (platí 30 dní na podpis) alebo zamietnuť s komentárom – databáza stráži, kto smie
priceExceptions.patch('/price-exceptions/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const status = oneOf(b, 'status', 'Rozhodnutie', ['schvalena', 'zamietnuta'] as const);
  if (!status) throw new BadRequest('Chýba rozhodnutie.');
  const note = str(b, 'decision_note', 'Komentár', { max: 2000, optional: true }) || null;
  const rows = await c.var.sql`
    UPDATE price_exception SET status = ${status}::price_exception_status, decision_note = ${note} WHERE id = ${id} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Žiadosť neexistuje alebo o nej nemôžete rozhodnúť.' }, 403);
  return c.json({ ok: true });
});

// Zmazať smie autor iba čakajúcu žiadosť (databáza)
priceExceptions.delete('/price-exceptions/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const rows = await c.var.sql`DELETE FROM price_exception WHERE id = ${id} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Žiadosť neexistuje alebo ju nemôžete zmazať.' }, 403);
  return c.json({ ok: true });
});
