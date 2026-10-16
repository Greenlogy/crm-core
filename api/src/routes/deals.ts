// Modul 5, F1 – obchody (obrazovky 32 pipeline, 33 karta; návrh DB časti 1.1–1.4, 1.13, migrácia 0032).
// Pravidlá (štádiá, povinné údaje, vlastník zákazníka, jedno OOM v jednom otvorenom obchode, prehra, znovuotvorenie)
// stráži databáza; API iba skladá dotazy a hlášky. Čo kto vidí a mení, rieši RLS („iba svoje“ = vlastné obchody
// a obchody na zákazníkoch, ktorých je vlastníkom). Externí obchodníci majú rovnaké obrazovky ako interní.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, type Body, readBody, str, uuid } from '../validate';
import { CAST, FIELDS, oomValues } from './oom-write';

export const deals = new Hono<AppEnv>();

const DATE = /^\d{4}-\d{2}-\d{2}$/;

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}
function day(b: Body, key: string, label: string): string | null | undefined {
  if (!(key in b)) return undefined;
  const v = b[key];
  if (v === null || v === '') return null;
  if (typeof v !== 'string' || !DATE.test(v)) throw new BadRequest(`${label}: neplatný dátum.`);
  return v;
}
function money(b: Body, key: string, label: string): number | null | undefined {
  if (!(key in b)) return undefined;
  const v = b[key];
  if (v === null || v === '') return null;
  const n = typeof v === 'number' ? v : Number(String(v).replace(/\s/g, '').replace(',', '.'));
  if (!Number.isFinite(n) || n < 0) throw new BadRequest(`${label}: neplatné číslo.`);
  return Math.round(n * 100) / 100;
}
function mwh(b: Body, key: string, label: string): number | null | undefined {
  if (!(key in b)) return undefined;
  const v = b[key];
  if (v === null || v === '') return null;
  const n = typeof v === 'number' ? v : Number(String(v).replace(/\s/g, '').replace(',', '.'));
  if (!Number.isFinite(n) || n < 0) throw new BadRequest(`${label}: neplatné číslo.`);
  return Math.round(n * 1000) / 1000;
}
function code(b: Body, key: string, label: string): string | null | undefined {
  if (!(key in b)) return undefined;
  const v = b[key];
  if (v === null || v === '') return null;
  if (typeof v !== 'string' || !/^[a-z0-9_]{1,63}$/.test(v)) throw new BadRequest(`${label}: neplatná hodnota.`);
  return v;
}

/** Spoločné stĺpce zoznamu a karty: zákazník, štádium, ďalší krok, PH, výstrahy Finstatu.
 *  PH (F6, 0049, uložená 0052): akceptovaný variant → hlavný variant poslednej odoslanej ponuky → odhad na obchode. */
const DEAL_COLUMNS = (sql: Sql) => sql`
  d.id, d.name, d.company_id, d.person_id, d.org_id,
  coalesce(c.name, nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')) AS customer_name,
  c.ico AS customer_ico,
  d.pipeline_id, pl.name AS pipeline_name, pl.kind AS pipeline_kind,
  d.stage_id, st.name AS stage_name, st.code AS stage_code, st.outcome AS stage_outcome, st.probability,
  d.owner_id, u.name AS owner_name,
  d.source_code, src.label AS source_label,
  d.expected_close, d.supply_start, d.next_step, d.next_step_on,
  CASE WHEN d.closed_at IS NOT NULL THEN NULL
       WHEN d.next_step_on IS NULL THEN 'bez_kroku'
       WHEN d.next_step_on < crm_today() THEN 'po_termine'
       WHEN d.next_step_on = crm_today() THEN 'dnes'
       ELSE 'planovany' END AS step_state,
  d.estimated_value_eur,
  dv.value_eur,
  dv.source AS value_source,
  round(coalesce(dv.value_eur, 0) * coalesce(st.probability, 0), 2) AS weighted_eur,
  d.lost_reason_code, lr.label AS lost_reason_label, d.lost_note,
  d.previous_contract_id, pk.number AS previous_contract_number,
  d.stage_changed_at, d.closed_at, d.created_at, d.note,
  (SELECT count(*)::int FROM deal_oom x WHERE x.deal_id = d.id) AS oom_count,
  CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END AS risk`;

const DEAL_FROM = (sql: Sql) => sql`
  FROM deal d
  JOIN pipeline pl ON pl.id = d.pipeline_id
  JOIN pipeline_stage st ON st.id = d.stage_id
  LEFT JOIN company c ON c.id = d.company_id
  LEFT JOIN contact p ON p.id = d.person_id
  LEFT JOIN app_user u ON u.id = d.owner_id
  LEFT JOIN lookup_value src ON src.list_code = 'zdroj_obchodu' AND src.code = d.source_code AND (src.org_id IS NULL OR src.org_id = d.org_id)
  LEFT JOIN lookup_value lr ON lr.list_code = 'dovod_prehry' AND lr.code = d.lost_reason_code AND (lr.org_id IS NULL OR lr.org_id = d.org_id)
  LEFT JOIN contract pk ON pk.id = d.previous_contract_id
  LEFT JOIN deal_value_cache dv ON dv.deal_id = d.id`;

// Číselníky a pipelines pre formuláre (zdroj, dôvod prehry, roly kontaktu, štádiá)
deals.get('/deals/options', async (c) => {
  const sql = c.var.sql;
  const pipelines = await sql`
    SELECT p.id, p.name, p.kind, p.org_id,
           coalesce((SELECT json_agg(json_build_object('id', s.id, 'name', s.name, 'code', s.code, 'outcome', s.outcome,
                                                       'probability', s.probability) ORDER BY s.sort_order)
                       FROM pipeline_stage s WHERE s.pipeline_id = p.id AND s.archived_at IS NULL), '[]') AS stages
      FROM pipeline p
     WHERE p.archived_at IS NULL AND p.kind IN ('b2b_dodavka', 'b2b_vykup', 'green_viwa', 'b2c_dodavka')
     ORDER BY p.sort_order, lower(p.name)`;
  const lookups = await sql`
    SELECT list_code, code, label, is_system FROM lookup_value
     WHERE list_code IN ('zdroj_obchodu', 'dovod_prehry', 'rola_kontaktu') AND hidden_at IS NULL
     ORDER BY list_code, sort_order, lower(label)`;
  const lists: Record<string, unknown[]> = {};
  for (const r of lookups) (lists[r.list_code as string] ??= []).push({ code: r.code, label: r.label, system: r.is_system });
  const [rights] = await sql<{ manager: boolean }[]>`SELECT crm_deal_manager() AS manager`;
  return c.json({ pipelines, lists, manager: rights?.manager ?? false });
});

// Možní vlastníci obchodu: aktívni používatelia (vlastníka mení iba vedenie, obchodný riaditeľ, schvaľovatelia)
deals.get('/deals/owners', async (c) => {
  const items = await c.var.sql`
    SELECT u.id, u.name FROM app_user u WHERE u.status <> 'deaktivovany' ORDER BY lower(u.name)`;
  return c.json(items);
});

/** Najviac obchodov v zozname a kanbane; súčty sú vždy cez všetky vyhovujúce (F6). */
const LIST_LIMIT = 1000;

// Zoznam a kanban (obrazovka 32). Filtre: pipeline, vlastník, štádium, zdroj, ďalší krok, uzavreté, hľadanie.
deals.get('/deals', async (c) => {
  const sql = c.var.sql;
  const q = c.req.query();
  const pipeline = q.pipeline && UUID.test(q.pipeline) ? q.pipeline : null;
  const owner = q.owner === 'ja' ? c.var.userId : q.owner && UUID.test(q.owner) ? q.owner : null;
  const stage = q.stage && UUID.test(q.stage) ? q.stage : null;
  const source = q.source && /^[a-z0-9_]{1,63}$/.test(q.source) ? q.source : null;
  const step = ['bez_kroku', 'po_termine', 'dnes', 'bez_alebo_po'].includes(q.step ?? '') ? q.step! : null;
  const closed = q.closed === 'mesiac' ? 'mesiac' : q.closed === 'vsetky' ? 'vsetky' : 'otvorene';
  const text = (q.q ?? '').trim().slice(0, 100);
  const like = `%${text.replace(/[%_\\]/g, (m) => `\\${m}`)}%`;
  const where = sql`
     WHERE (${pipeline}::uuid IS NULL OR d.pipeline_id = ${pipeline})
       AND (${owner}::uuid IS NULL OR d.owner_id = ${owner})
       AND (${stage}::uuid IS NULL OR d.stage_id = ${stage})
       AND (${source}::text IS NULL OR d.source_code = ${source})
       AND CASE ${closed}
             WHEN 'otvorene' THEN d.closed_at IS NULL
             WHEN 'mesiac' THEN d.closed_at IS NULL OR d.closed_at >= date_trunc('month', now() AT TIME ZONE 'Europe/Bratislava') AT TIME ZONE 'Europe/Bratislava'
             ELSE true END
       AND CASE ${step}::text
             WHEN 'bez_kroku' THEN d.closed_at IS NULL AND d.next_step_on IS NULL
             WHEN 'po_termine' THEN d.closed_at IS NULL AND d.next_step_on < crm_today()
             WHEN 'dnes' THEN d.next_step_on = crm_today()
             WHEN 'bez_alebo_po' THEN d.closed_at IS NULL AND (d.next_step_on IS NULL OR d.next_step_on < crm_today())
             ELSE true END
       AND (${text} = '' OR d.name ILIKE ${like} OR c.name ILIKE ${like} OR c.ico LIKE ${text.replace(/\s/g, '') + '%'}
            OR concat_ws(' ', p.first_name, p.last_name) ILIKE ${like})`;
  const [items, totals] = await Promise.all([
    sql`
    SELECT ${DEAL_COLUMNS(sql)}
    ${DEAL_FROM(sql)}
    ${where}
     ORDER BY d.closed_at IS NOT NULL, st.sort_order, d.next_step_on NULLS FIRST, d.created_at DESC
     LIMIT ${LIST_LIMIT}`,
    // Súčty cez všetky vyhovujúce obchody (nie iba zobrazené): po štádiách, vážená PH, bez kroku / po termíne, dôvody prehry
    sql`
    SELECT d.stage_id, st.outcome, count(*)::int AS count,
           coalesce(sum(dv.value_eur), 0) AS value_eur,
           coalesce(round(sum(coalesce(dv.value_eur, 0) * coalesce(st.probability, 0)), 2), 0) AS weighted_eur,
           count(*) FILTER (WHERE d.closed_at IS NULL AND (d.next_step_on IS NULL OR d.next_step_on < crm_today()))::int AS attention,
           coalesce(jsonb_agg(coalesce(lr.label, 'iné')) FILTER (WHERE st.outcome = 'prehrany'), '[]') AS lost_reasons
    ${DEAL_FROM(sql)}
    ${where}
     GROUP BY d.stage_id, st.outcome`,
  ]);
  return c.json({ items, totals, truncated: items.length >= LIST_LIMIT });
});

// Karta obchodu (obrazovka 33): obchod, OOM s objemami, kontakty s rolami, práva prihláseného
deals.get('/deals/:id', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const [deal] = await sql`
    SELECT ${DEAL_COLUMNS(sql)},
           crm_deal_editable(d.company_id, d.person_id, d.owner_id) AS can_edit,
           d.closed_at IS NULL AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)
             AND NOT EXISTS (SELECT 1 FROM app_user au JOIN team t ON t.id = au.team_id
                              WHERE au.id = crm_active_user_id() AND t.code = 'sales_internal') AS can_request_help,
           crm_deal_manager() AS can_change_owner,
           (st.code = 'prehrane' AND (d.owner_id = crm_active_user_id() OR crm_is_admin()))
             OR (st.code = 'vyhrane' AND crm_is_admin()) AS can_reopen,
           crm_customer_owner(d.company_id, d.person_id) AS customer_owner_id,
           crm_user_name(crm_customer_owner(d.company_id, d.person_id)) AS customer_owner_name
    ${DEAL_FROM(sql)}
     WHERE d.id = ${dealId}`;
  if (!deal) return c.json({ error: 'Obchod neexistuje alebo ho nevidíte.' }, 404);
  const [stages, ooms, contacts] = await Promise.all([
    sql`SELECT s.id, s.name, s.code, s.outcome, s.probability FROM pipeline_stage s
         WHERE s.pipeline_id = ${deal.pipeline_id} AND (s.archived_at IS NULL OR s.id = ${deal.stage_id})
         ORDER BY s.sort_order`,
    sql`SELECT o.id, o.eic, o.name, o.type, o.status, o.voltage_level, o.pds, o.pds_tariff,
               concat_ws(', ', nullif(concat_ws(' ', o.address_street, nullif(concat_ws('/', o.address_number_supisne, o.address_number_orientacne), '')), ''),
                         nullif(concat_ws(' ', o.address_zip, o.address_city), '')) AS address,
               x.planned_vt_mwh, x.planned_nt_mwh, x.planned_feed_in_mwh, x.source_power_kw,
               o.created_from_deal_id = d.id AS created_here
          FROM deal_oom x
          JOIN deal d ON d.id = x.deal_id
          LEFT JOIN oom o ON o.id = x.oom_id
         WHERE x.deal_id = ${dealId}
         ORDER BY o.voltage_level NULLS LAST, o.eic`,
    sql`SELECT x.contact_id AS id, nullif(btrim(concat_ws(' ', k.title, k.first_name, k.last_name)), '') AS name,
               k.position, k.email, k.phone, k.mobile, to_jsonb(x.roles) AS roles, x.is_primary
          FROM deal_contact x
          LEFT JOIN contact k ON k.id = x.contact_id
         WHERE x.deal_id = ${dealId}
         ORDER BY x.is_primary DESC, k.last_name`,
  ]);
  return c.json({ ...deal, stages, ooms, contacts });
});

// Časová os: udalosti obchodu, poznámky (activity), neskôr e-maily a ponuky
deals.get('/deals/:id/timeline', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const items = await sql`
    SELECT e.id, 'udalost' AS type, e.kind, e.occurred_at, e.reason, e.detail,
           u.name AS user_name, fs.name AS from_stage, ts.name AS to_stage, o.eic AS oom_eic,
           nullif(btrim(concat_ws(' ', k.first_name, k.last_name)), '') AS contact_name,
           (SELECT name FROM app_user WHERE id = (e.detail->>'from')::uuid) AS from_owner,
           (SELECT name FROM app_user WHERE id = coalesce(e.detail->>'to', e.detail->>'owner_id')::uuid) AS to_owner,
           lr.label AS lost_reason_label, NULL::text AS body
      FROM deal_event e
      LEFT JOIN app_user u ON u.id = e.user_id
      LEFT JOIN pipeline_stage fs ON fs.id = e.from_stage_id
      LEFT JOIN pipeline_stage ts ON ts.id = e.to_stage_id
      LEFT JOIN oom o ON o.id = e.oom_id
      LEFT JOIN contact k ON k.id = e.contact_id
      LEFT JOIN lookup_value lr ON lr.list_code = 'dovod_prehry' AND lr.code = e.detail->>'lost_reason_code'
     WHERE e.deal_id = ${dealId}
    UNION ALL
    SELECT a.id, 'poznamka', NULL, a.occurred_at, NULL, NULL, u.name, NULL, NULL, NULL, NULL, NULL, NULL, NULL, a.body
      FROM activity a
      LEFT JOIN app_user u ON u.id = a.user_id
     WHERE a.deal_id = ${dealId} AND a.type = 'poznamka'
     ORDER BY occurred_at DESC
     LIMIT 300`;
  return c.json({ items });
});

function dealValues(b: Body): Record<string, unknown> {
  const v: Record<string, unknown> = {};
  const name = str(b, 'name', 'Názov obchodu', { max: 200, optional: true });
  if (name !== undefined) {
    if (name === '') throw new BadRequest('Chýba: Názov obchodu.');
    v.name = name;
  }
  const src = code(b, 'source_code', 'Zdroj');
  if (src !== undefined) {
    if (src === null) throw new BadRequest('Chýba: Zdroj.');
    v.source_code = src;
  }
  for (const [key, label] of [['expected_close', 'Očakávané uzavretie'], ['supply_start', 'Začiatok dodávky'], ['next_step_on', 'Dátum ďalšieho kroku']] as const) {
    const d = day(b, key, label);
    if (d !== undefined) v[key] = d;
  }
  const est = money(b, 'estimated_value_eur', 'Odhad pridanej hodnoty');
  if (est !== undefined) v.estimated_value_eur = est;
  for (const [key, label, max] of [['next_step', 'Ďalší krok', 300], ['note', 'Poznámka', 5000]] as const) {
    const s = str(b, key, label, { max, optional: true });
    if (s !== undefined) v[key] = s === '' ? null : s;
  }
  if ('owner_id' in b) {
    const o = uuid(b, 'owner_id', 'Vlastník');
    if (!o) throw new BadRequest('Chýba: Vlastník.');
    v.owner_id = o;
  }
  return v;
}

// Nový obchod (vždy v Príležitosti vybranej pipeline). Vlastník = prihlásený, ak ho nezadá vedenie.
deals.post('/deals', async (c) => {
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const pipeline = uuid(b, 'pipeline_id', 'Pipeline');
  if (!pipeline) throw new BadRequest('Vyberte pipeline.');
  const company = uuid(b, 'company_id', 'Firma', true) ?? null;
  const person = uuid(b, 'person_id', 'Osoba', true) ?? null;
  if ((company === null) === (person === null)) throw new BadRequest('Vyberte zákazníka (firmu alebo domácnosť).');
  const v = dealValues(b);
  if (!v.name) throw new BadRequest('Chýba: Názov obchodu.');
  if (!v.source_code) throw new BadRequest('Chýba: Zdroj.');
  v.owner_id ??= c.var.userId;
  const [st] = await sql<{ id: string }[]>`SELECT id FROM pipeline_stage WHERE pipeline_id = ${pipeline} AND code = 'prilezitost'`;
  if (!st) throw new BadRequest('Pipeline neexistuje.');
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO deal ${sql({ ...v, pipeline_id: pipeline, stage_id: st.id, company_id: company, person_id: person })}
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

deals.patch('/deals/:id', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const v = dealValues(await readBody(c.req));
  if (Object.keys(v).length === 0) return c.json({ ok: true });
  const rows = await sql`UPDATE deal SET ${sql(v)} WHERE id = ${dealId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Obchod nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

// Zmena štádia; pri Prehraté dôvod (pri „Iné“ s poznámkou). Podmienky kontroluje databáza.
deals.post('/deals/:id/stage', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const stage = uuid(b, 'stage_id', 'Štádium');
  if (!stage) throw new BadRequest('Vyberte štádium.');
  const reason = code(b, 'lost_reason_code', 'Dôvod prehry') ?? null;
  const note = str(b, 'lost_note', 'Poznámka k prehre', { max: 2000, optional: true }) || null;
  const rows = await sql`
    UPDATE deal SET stage_id = ${stage}, lost_reason_code = ${reason}, lost_note = ${note}
     WHERE id = ${dealId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Obchod nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

deals.post('/deals/:id/reopen', async (c) => {
  const dealId = id(c.req.param('id'));
  const reason = str(await readBody(c.req), 'reason', 'Dôvod znovuotvorenia', { max: 2000 })!;
  await c.var.sql`SELECT deal_reopen(${dealId}, ${reason})`;
  return c.json({ ok: true });
});

// --- OOM na obchode ---

function volumes(b: Body): Record<string, number | null> {
  const v: Record<string, number | null> = {};
  for (const [key, label] of [
    ['planned_vt_mwh', 'Plánovaná spotreba VT'],
    ['planned_nt_mwh', 'Plánovaná spotreba NT'],
    ['planned_feed_in_mwh', 'Plánovaná výroba'],
    ['source_power_kw', 'Výkon zdroja'],
  ] as const) {
    const n = mwh(b, key, label);
    if (n !== undefined) v[key] = n;
  }
  return v;
}

// Existujúce OOM zákazníka (objemy sa predvyplnia z OOM, ak ich obchodník nezadá)
deals.post('/deals/:id/oom', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const oom = uuid(b, 'oom_id', 'OOM');
  if (!oom) throw new BadRequest('Vyberte OOM.');
  await sql`INSERT INTO deal_oom ${sql({ deal_id: dealId, oom_id: oom, ...volumes(b) })}`;
  return c.json({ ok: true }, 201);
});

// Nové OOM zákazníka obchodu: vznikne Pripravované (kontrola EIC a polí ako v module 2) a hneď sa pridá do obchodu
deals.post('/deals/:id/oom/new', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const [d] = await sql<{ company_id: string | null; person_id: string | null }[]>`
    SELECT company_id, person_id FROM deal WHERE id = ${dealId}`;
  if (!d) return c.json({ error: 'Obchod neexistuje alebo ho nevidíte.' }, 404);
  const v = oomValues(b);
  if (!v.eic) throw new BadRequest('Chýba: EIC.');
  if (!v.type) throw new BadRequest('Chýba: Typ.');
  const cols = Object.keys(v);
  const values = cols.map((k) => sql`${v[k]}::${sql.unsafe(FIELDS[k].cast ?? CAST[FIELDS[k].kind])}`);
  const list = values.reduce((acc, f) => sql`${acc}, ${f}`);
  const names = cols.map((k) => sql`${sql(k)}`).reduce((acc, f) => sql`${acc}, ${f}`);
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO oom (company_id, person_id, status, created_from_deal_id, ${names})
    VALUES (${d.company_id}::uuid, ${d.person_id}::uuid, 'pripravovane', ${dealId}, ${list})
    RETURNING id`;
  await sql`INSERT INTO deal_oom (deal_id, oom_id) VALUES (${dealId}, ${row.id})`;
  return c.json({ id: row.id }, 201);
});

deals.patch('/deals/:id/oom/:oomId', async (c) => {
  const dealId = id(c.req.param('id'));
  const oomId = id(c.req.param('oomId'));
  const sql = c.var.sql;
  const v = volumes(await readBody(c.req));
  if (Object.keys(v).length === 0) return c.json({ ok: true });
  const rows = await sql`UPDATE deal_oom SET ${sql(v)} WHERE deal_id = ${dealId} AND oom_id = ${oomId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'OOM na obchode nemôžete upravovať.' }, 403);
  return c.json({ ok: true });
});

deals.delete('/deals/:id/oom/:oomId', async (c) => {
  const dealId = id(c.req.param('id'));
  const oomId = id(c.req.param('oomId'));
  const rows = await c.var.sql`DELETE FROM deal_oom WHERE deal_id = ${dealId} AND oom_id = ${oomId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'OOM z obchodu nemôžete odobrať.' }, 403);
  return c.json({ ok: true });
});

// OOM zákazníka obchodu, ktoré sa dajú pridať (Pripravované a Aktívne, ešte nie sú na obchode)
deals.get('/deals/:id/oom-candidates', async (c) => {
  const dealId = id(c.req.param('id'));
  const items = await c.var.sql`
    SELECT o.id, o.eic, o.name, o.type, o.status, o.voltage_level, o.address_city
      FROM deal d
      JOIN oom o ON (o.company_id = d.company_id OR o.person_id = d.person_id)
     WHERE d.id = ${dealId} AND o.status IN ('pripravovane', 'aktivne')
       AND NOT EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = d.id AND x.oom_id = o.id)
     ORDER BY o.eic`;
  return c.json({ items });
});

// --- Kontakty na obchode ---

function roles(b: Body): string[] | undefined {
  if (!('roles' in b)) return undefined;
  if (!Array.isArray(b.roles) || b.roles.some((r) => typeof r !== 'string' || !/^[a-z0-9_]{1,63}$/.test(r))) {
    throw new BadRequest('Roly: neplatná hodnota.');
  }
  return [...new Set(b.roles as string[])];
}

deals.post('/deals/:id/contacts', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const contact = uuid(b, 'contact_id', 'Osoba');
  if (!contact) throw new BadRequest('Vyberte osobu.');
  const primary = b.is_primary === true;
  if (primary) await sql`UPDATE deal_contact SET is_primary = false WHERE deal_id = ${dealId} AND is_primary`;
  // pole rolí ako JSON (ovládač bez načítaných typov – fetch_types: false)
  await sql`
    INSERT INTO deal_contact (deal_id, contact_id, roles, is_primary)
    VALUES (${dealId}, ${contact}, ARRAY(SELECT jsonb_array_elements_text(${sql.json(roles(b) ?? [])}::jsonb)), ${primary})`;
  return c.json({ ok: true }, 201);
});

deals.patch('/deals/:id/contacts/:contactId', async (c) => {
  const dealId = id(c.req.param('id'));
  const contactId = id(c.req.param('contactId'));
  const sql = c.var.sql;
  const b = await readBody(c.req);
  const r = roles(b);
  if (b.is_primary === true) await sql`UPDATE deal_contact SET is_primary = false WHERE deal_id = ${dealId} AND is_primary`;
  const rows = await sql`
    UPDATE deal_contact
       SET roles = CASE WHEN ${r !== undefined} THEN ARRAY(SELECT jsonb_array_elements_text(${sql.json(r ?? [])}::jsonb)) ELSE roles END,
           is_primary = CASE WHEN ${typeof b.is_primary === 'boolean'} THEN ${b.is_primary === true} ELSE is_primary END
     WHERE deal_id = ${dealId} AND contact_id = ${contactId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Kontakt na obchode nemôžete upravovať.' }, 403);
  return c.json({ ok: true });
});

deals.delete('/deals/:id/contacts/:contactId', async (c) => {
  const dealId = id(c.req.param('id'));
  const contactId = id(c.req.param('contactId'));
  const rows = await c.var.sql`DELETE FROM deal_contact WHERE deal_id = ${dealId} AND contact_id = ${contactId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Kontakt z obchodu nemôžete odobrať.' }, 403);
  return c.json({ ok: true });
});

// Osoby, ktoré sa dajú pridať: osoby firmy obchodu (pri domácnosti ona sama)
deals.get('/deals/:id/contact-candidates', async (c) => {
  const dealId = id(c.req.param('id'));
  const items = await c.var.sql`
    SELECT k.id, nullif(btrim(concat_ws(' ', k.title, k.first_name, k.last_name)), '') AS name, k.position, k.email,
           to_jsonb(cc.roles) AS company_roles, cc.is_main_contact
      FROM deal d
      JOIN contact k ON k.id = d.person_id
                     OR k.id IN (SELECT contact_id FROM company_contact WHERE company_id = d.company_id)
      LEFT JOIN company_contact cc ON cc.company_id = d.company_id AND cc.contact_id = k.id
     WHERE d.id = ${dealId}
       AND NOT EXISTS (SELECT 1 FROM deal_contact x WHERE x.deal_id = d.id AND x.contact_id = k.id)
     ORDER BY cc.is_main_contact DESC NULLS LAST, k.last_name`;
  return c.json({ items });
});

// Poznámka na časovej osi obchodu (aj na zákazníkovi – aktivita typu poznámka, nemení sa ani nemaže)
deals.post('/deals/:id/notes', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const text = str(await readBody(c.req), 'text', 'Text poznámky', { max: 5000 })!;
  const [d] = await sql<{ company_id: string | null; person_id: string | null; can: boolean }[]>`
    SELECT company_id, person_id, crm_deal_editable(company_id, person_id, owner_id) AS can FROM deal WHERE id = ${dealId}`;
  if (!d?.can) return c.json({ error: 'Poznámku k obchodu nemôžete pridať.' }, 403);
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO activity (type, deal_id, company_id, contact_id, user_id, occurred_at, body, source)
    VALUES ('poznamka', ${dealId}, ${d.company_id}, ${d.person_id}, ${c.var.userId}, now(), ${text}, 'crm')
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Žiadosť o pomoc s ponukou (F6, 0049 / 0050): tímu Sales_internal zvonček a e-mail z crm@; žiada, kto upravuje obchod
// a nie je v Sales_internal (stráži databáza)
deals.post('/deals/:id/help', async (c) => {
  const dealId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const note = str(b, 'note', 'Poznámka', { max: 500, optional: true }) || null;
  const [r] = await c.var.sql<{ n: number }[]>`SELECT deal_help_request(${dealId}, ${note}) AS n`;
  return c.json({ recipients: r.n });
});
