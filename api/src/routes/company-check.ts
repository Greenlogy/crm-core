// Modul 5, F1 – overenie firmy pred obchodom (obrazovka 31; zadanie 4.1, návrh DB časť 8, migrácia 0033).
// CRM časť (je v CRM, vlastník, zmluvy, otvorené obchody) vracia databáza (company_check – kto firmu nevidí,
// dostane iba vlastníka a vlastníkov obchodov). Finstat časť ide z cache 24 h, inak z Finstatu (denný limit).
// Firma v CRM, ktorú používateľ vidí, dostane pri overení čerstvé údaje Finstatu (company_apply_finstat).

import { Hono } from 'hono';
import { finstatApplyData, finstatAutocomplete, finstatDetail, FinstatUnavailable, type FinstatEnv } from '../finstat';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody, str } from '../validate';

export const companyCheck = new Hono<AppEnv>();

type Env = AppEnv & { Bindings: FinstatEnv };

function finstatError(err: unknown): string {
  if (err instanceof FinstatUnavailable) return err.message;
  throw err;
}

// Overenie podľa IČO: CRM + Finstat (Finstat môže byť nedostupný – CRM časť sa ukáže aj tak)
companyCheck.get('/company-check', async (c) => {
  const sql = c.var.sql;
  const ico = (c.req.query('ico') ?? '').replace(/\s/g, '');
  if (!/^\d{6,8}$/.test(ico)) throw new BadRequest('IČO musí mať 8 číslic.');
  const env = c.env as Env['Bindings'];
  let finstat = null;
  let finstatErr: string | null = null;
  try {
    finstat = await finstatDetail(sql, env, ico);
  } catch (err) {
    finstatErr = finstatError(err);
  }
  const [crm] = await sql<{ r: Record<string, unknown> }[]>`SELECT company_check(${ico}) AS r`;
  const check = crm?.r ?? { exists: false };
  if (finstat && check.visible && typeof check.company_id === 'string') {
    await sql`SELECT company_apply_finstat(${check.company_id}, ${sql.json(finstatApplyData(finstat) as never)})`;
    const [again] = await sql<{ r: Record<string, unknown> }[]>`SELECT company_check(${ico}) AS r`;
    return c.json({ crm: again?.r ?? check, finstat, finstat_error: finstatErr });
  }
  return c.json({ crm: check, finstat, finstat_error: finstatErr });
});

// Hľadanie podľa názvu: firmy v CRM (iba tie, ktoré používateľ vidí) + našepkávanie Finstatu s označením „v CRM“
companyCheck.get('/company-search', async (c) => {
  const sql = c.var.sql;
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  if (q.length < 3) return c.json({ crm: [], finstat: [], finstat_error: null });
  const like = `%${q.replace(/[%_\\]/g, (m) => `\\${m}`)}%`;
  const crm = await sql`
    SELECT c.id, c.name, c.ico, u.name AS owner_name
      FROM company c LEFT JOIN app_user u ON u.id = c.owner_id
     WHERE c.name ILIKE ${like} OR c.ico LIKE ${q.replace(/\s/g, '') + '%'}
     ORDER BY lower(c.name) LIMIT 10`;
  let finstat: { ico: string; name: string; city: string | null; cancelled: boolean; in_crm?: boolean; owner_name?: string | null }[] = [];
  let finstatErr: string | null = null;
  try {
    finstat = await finstatAutocomplete(sql, c.env as Env['Bindings'], q);
  } catch (err) {
    finstatErr = finstatError(err);
  }
  if (finstat.length) {
    const checks = await sql<{ ico: string; r: { exists: boolean; owner_name?: string } }[]>`
      SELECT x.ico, company_check(x.ico) AS r FROM jsonb_array_elements_text(${sql.json(finstat.map((f) => f.ico))}::jsonb) AS x(ico)`;
    const byIco = new Map(checks.map((r) => [r.ico, r.r]));
    finstat = finstat.map((f) => ({ ...f, in_crm: byIco.get(f.ico)?.exists ?? false, owner_name: byIco.get(f.ico)?.owner_name ?? null }));
  }
  return c.json({ crm, finstat, finstat_error: finstatErr });
});

// Nová firma z Finstatu jedným klikom; vlastník = prihlásený (zadanie 4.1)
companyCheck.post('/companies/from-finstat', async (c) => {
  const sql = c.var.sql;
  const [t] = await sql<{ code: string }[]>`
    SELECT t.code FROM app_user u JOIN team t ON t.id = u.team_id WHERE u.id = ${c.var.userId}`;
  if (t?.code === 'servis') throw new Forbidden('Servis nezakladá firmy.');
  const ico = (str(await readBody(c.req), 'ico', 'IČO', { max: 20 }) ?? '').replace(/\D/g, '').padStart(8, '0');
  if (!/^\d{8}$/.test(ico)) throw new BadRequest('IČO musí mať 8 číslic.');
  let f;
  try {
    f = await finstatDetail(sql, c.env as Env['Bindings'], ico);
  } catch (err) {
    return c.json({ error: finstatError(err) }, 503);
  }
  if (!f || !f.name) return c.json({ error: 'Finstat firmu s týmto IČO nepozná.' }, 404);
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO company ${sql({
      country: 'SK', ico, name: f.name, dic: f.dic, ic_dph: f.ic_dph, vat_payer: f.ic_dph ? true : null,
      address: f.address, legal_form: f.legal_form, nace: f.nace, registry_entry: f.registry_entry,
      is_customer: true, owner_id: c.var.userId,
    })}
    RETURNING id`;
  await sql`SELECT company_apply_finstat(${row.id}, ${sql.json(finstatApplyData(f) as never)})`;
  return c.json({ id: row.id }, 201);
});

// Obnova údajov Finstatu na karte firmy (z cache 24 h, inak z Finstatu)
companyCheck.post('/companies/:id/finstat-refresh', async (c) => {
  const companyId = c.req.param('id');
  if (!UUID.test(companyId)) throw new BadRequest('Neplatné ID.');
  const sql = c.var.sql;
  const [co] = await sql<{ ico: string | null; country: string }[]>`SELECT ico, country FROM company WHERE id = ${companyId}`;
  if (!co) return c.json({ error: 'Firma neexistuje alebo ju nevidíte.' }, 404);
  if (co.country !== 'SK' || !co.ico) throw new BadRequest('Finstat je iba pre slovenské firmy s IČO.');
  try {
    const f = await finstatDetail(sql, c.env as Env['Bindings'], co.ico);
    if (!f) return c.json({ error: 'Finstat firmu s týmto IČO nepozná.' }, 404);
    await sql`SELECT company_apply_finstat(${companyId}, ${sql.json(finstatApplyData(f) as never)})`;
    return c.json({ ok: true, fetched_at: f.fetched_at, from_cache: f.from_cache });
  } catch (err) {
    return c.json({ error: finstatError(err) }, 503);
  }
});

// Výstrahy firmy (karta firmy, obchod)
companyCheck.get('/companies/:id/risk', async (c) => {
  const companyId = c.req.param('id');
  if (!UUID.test(companyId)) throw new BadRequest('Neplatné ID.');
  const [r] = await c.var.sql<{ risk: unknown; data: unknown }[]>`
    SELECT company_risk(c.id) AS risk,
           json_build_object('revenue_eur', c.revenue_eur, 'profit_eur', c.profit_eur, 'finance_year', c.finance_year,
                             'employees_range', c.employees_range, 'founded_on', c.founded_on, 'z_score', c.z_score,
                             'payment_rating', c.payment_rating, 'has_debts', c.has_debts, 'debts', c.debts,
                             'insolvency_kind', c.insolvency_kind, 'insolvency_since', c.insolvency_since,
                             'cancelled_on', c.cancelled_on, 'finstat_url', c.finstat_url,
                             'finstat_updated_at', c.finstat_updated_at) AS data
      FROM company c WHERE c.id = ${companyId}`;
  if (!r) return c.json({ error: 'Firma neexistuje alebo ju nevidíte.' }, 404);
  return c.json(r);
});
