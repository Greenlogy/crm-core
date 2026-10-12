// Nastavenia – Audit (dizajn 16): kto, čo a kedy zmenil, stará a nová hodnota.
// Iba pre admina (kontrola v settings.ts). Audit obsahuje zmeny osobných údajov, preto sa nevypisuje do logu.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest } from '../validate';

export const auditSettings = new Hono<AppEnv>();

// Tabuľky Nastavení (filter „nastavenia“); ostatné sú dáta.
const SETTINGS_TABLES = [
  'org', 'org_bank_account', 'team', 'team_permission', 'app_user', 'app_user_org', 'org_work_hours', 'org_day_off',
  'lookup_value', 'custom_field_section', 'custom_field', 'custom_field_team', 'custom_field_option', 'pipeline',
  'pipeline_stage', 'pipeline_stage_required_field',
];

const PAGE = 50;

auditSettings.get('/audit', async (c) => {
  const user = c.req.query('user') ?? '';
  const kind = c.req.query('kind') ?? '';
  const from = c.req.query('from') ?? '';
  const to = c.req.query('to') ?? '';
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const page = Math.max(1, Number.parseInt(c.req.query('page') ?? '1', 10) || 1);
  if (user !== '' && user !== 'system' && !UUID.test(user)) throw new BadRequest('Neplatný používateľ.');
  if (!['', 'nastavenia', 'data'].includes(kind)) throw new BadRequest('Neplatný typ.');
  for (const d of [from, to]) if (d && !/^\d{4}-\d{2}-\d{2}$/.test(d)) throw new BadRequest('Dátum zadaj ako RRRR-MM-DD.');
  const sql = c.var.sql;

  const rows = await sql`
    WITH a AS (
      SELECT a.*,
             coalesce(CASE a.table_name
               WHEN 'company' THEN (SELECT x.name FROM company x WHERE x.id = a.record_id)
               WHEN 'contact' THEN (SELECT concat_ws(' ', x.first_name, x.last_name) FROM contact x WHERE x.id = a.record_id)
               WHEN 'company_contact' THEN (SELECT concat_ws(' ', p.first_name, p.last_name) || ' · ' || f.name
                                              FROM company_contact x JOIN contact p ON p.id = x.contact_id
                                              JOIN company f ON f.id = x.company_id WHERE x.id = a.record_id)
               WHEN 'oom' THEN (SELECT x.eic FROM oom x WHERE x.id = a.record_id)
               WHEN 'deal' THEN (SELECT x.name FROM deal x WHERE x.id = a.record_id)
               WHEN 'contract' THEN (SELECT x.number FROM contract x WHERE x.id = a.record_id)
               WHEN 'app_user' THEN (SELECT x.name FROM app_user x WHERE x.id = a.record_id)
               WHEN 'team' THEN (SELECT x.name FROM team x WHERE x.id = a.record_id)
               WHEN 'team_permission' THEN (SELECT t.name || ' · ' || x.module FROM team_permission x
                                              JOIN team t ON t.id = x.team_id WHERE x.id = a.record_id)
               WHEN 'app_user_org' THEN (SELECT u.name || ' · ' || o.legal_name FROM app_user_org x
                                           JOIN app_user u ON u.id = x.user_id JOIN org o ON o.id = x.org_id
                                          WHERE x.id = a.record_id)
               WHEN 'org' THEN (SELECT x.legal_name FROM org x WHERE x.id = a.record_id)
               WHEN 'org_bank_account' THEN (SELECT x.iban FROM org_bank_account x WHERE x.id = a.record_id)
               WHEN 'org_work_hours' THEN (SELECT o.legal_name || ' · deň ' || x.weekday FROM org_work_hours x
                                             JOIN org o ON o.id = x.org_id WHERE x.id = a.record_id)
               WHEN 'org_day_off' THEN (SELECT x.name || ' ' || to_char(x.date, 'DD. MM. YYYY') FROM org_day_off x WHERE x.id = a.record_id)
               WHEN 'lookup_value' THEN (SELECT x.list_code || ' · ' || x.label FROM lookup_value x WHERE x.id = a.record_id)
               WHEN 'custom_field' THEN (SELECT x.entity || ' · ' || x.label FROM custom_field x WHERE x.id = a.record_id)
               WHEN 'custom_field_option' THEN (SELECT f.label || ' · ' || x.label FROM custom_field_option x
                                                  JOIN custom_field f ON f.id = x.field_id WHERE x.id = a.record_id)
               WHEN 'custom_field_section' THEN (SELECT x.name FROM custom_field_section x WHERE x.id = a.record_id)
               WHEN 'pipeline' THEN (SELECT x.name FROM pipeline x WHERE x.id = a.record_id)
               WHEN 'pipeline_stage' THEN (SELECT p.name || ' · ' || x.name FROM pipeline_stage x
                                             JOIN pipeline p ON p.id = x.pipeline_id WHERE x.id = a.record_id)
               WHEN 'pipeline_stage_required_field' THEN (SELECT p.name || ' · ' || st.name || ' · povinné pole'
                                                            FROM pipeline_stage_required_field x
                                                            JOIN pipeline_stage st ON st.id = x.stage_id
                                                            JOIN pipeline p ON p.id = st.pipeline_id WHERE x.id = a.record_id)
               WHEN 'custom_field_team' THEN (SELECT f.label || ' · ' || t.name FROM custom_field_team x
                                                JOIN custom_field f ON f.id = x.field_id JOIN team t ON t.id = x.team_id
                                               WHERE x.id = a.record_id)
             END,
             a.diff ->> 'name', a.diff ->> 'label', a.diff ->> 'legal_name',
             nullif(concat_ws(' ', a.diff ->> 'first_name', a.diff ->> 'last_name'), ''), a.diff ->> 'email') AS record_label
        FROM audit_log a
       WHERE (${user} = '' OR (${user} = 'system' AND a.changed_by IS NULL)
              OR (${user} NOT IN ('', 'system') AND a.changed_by::text = ${user}))
         AND (${kind} = '' OR (a.table_name IN (SELECT jsonb_array_elements_text(${sql.json(SETTINGS_TABLES)}::jsonb))) = (${kind} = 'nastavenia'))
         AND (${from} = '' OR a.changed_at >= (${from || null}::date)::timestamp AT TIME ZONE 'Europe/Bratislava')
         AND (${to} = '' OR a.changed_at < ((${to || null}::date + 1)::timestamp AT TIME ZONE 'Europe/Bratislava'))
    )
    SELECT a.id, a.changed_at, a.table_name, a.record_id, a.action, a.source, a.diff, a.record_label,
           u.name AS user_name, count(*) OVER ()::int AS total
      FROM a
      LEFT JOIN app_user u ON u.id = a.changed_by
     WHERE ${q} = '' OR a.record_label ILIKE ${'%' + q + '%'}
     ORDER BY a.changed_at DESC, a.id DESC
     LIMIT ${PAGE} OFFSET ${(page - 1) * PAGE}`;

  const users = await sql`
    SELECT DISTINCT u.id, u.name FROM audit_log a JOIN app_user u ON u.id = a.changed_by ORDER BY u.name`;
  return c.json({
    page,
    pageSize: PAGE,
    total: rows[0]?.total ?? 0,
    items: rows.map(({ total: _t, ...r }) => r),
    users,
  });
});
