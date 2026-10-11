// Zoznam zákazníkov a karta zákazníka (firma alebo domácnosť).
// Zákazník = firma, alebo kontakt, ktorý vlastní OOM, deal alebo zmluvu (person_id).
// Nepoužíva customer_v: ten počíta každý kontakt bez firmy ako B2C (zistenie z kroku 2).

import type { Sql } from '../db';

export const PAGE_SIZE = 50;
export type CustomerKind = 'company' | 'person';

export async function listCustomers(sql: Sql, opts: { q: string; segment: string; page: number }) {
  const like = `%${opts.q}%`;
  const rows = await sql`
    WITH customer AS (
      SELECT 'company' AS kind, c.id, c.name, c.ico, c.segment::text AS segment, c.hubspot_id
        FROM company c
      UNION ALL
      SELECT 'person', p.id, concat_ws(' ', p.first_name, p.last_name), NULL, p.segment::text, p.hubspot_id
        FROM contact p
       WHERE EXISTS (SELECT 1 FROM oom o WHERE o.person_id = p.id)
          OR EXISTS (SELECT 1 FROM deal d WHERE d.person_id = p.id)
          OR EXISTS (SELECT 1 FROM contract k WHERE k.person_id = p.id)
    )
    SELECT cu.kind, cu.id, cu.name, cu.ico, cu.segment, cu.hubspot_id,
           o.oom_count, o.oom_active, o.planned_consumption_mwh, o.planned_feed_in_mwh,
           (SELECT count(*)::int FROM contract k
             WHERE (k.company_id = cu.id OR k.person_id = cu.id) AND k.status = 'aktivna') AS active_contracts,
           count(*) OVER ()::int AS total
      FROM customer cu
      CROSS JOIN LATERAL (
        SELECT count(*)::int AS oom_count,
               count(*) FILTER (WHERE status = 'aktivne')::int AS oom_active,
               sum(coalesce(planned_consumption_vt_mwh, 0) + coalesce(planned_consumption_nt_mwh, 0)) AS planned_consumption_mwh,
               sum(planned_feed_in_mwh) AS planned_feed_in_mwh
          FROM oom WHERE company_id = cu.id OR person_id = cu.id
      ) o
     WHERE (${opts.q} = '' OR cu.name ILIKE ${like} OR cu.ico LIKE ${opts.q + '%'})
       AND (${opts.segment} = '' OR cu.segment = ${opts.segment})
     ORDER BY cu.name, cu.id
     LIMIT ${PAGE_SIZE} OFFSET ${(opts.page - 1) * PAGE_SIZE}
  `;
  const total = rows[0]?.total ?? 0;
  return {
    page: opts.page,
    pageSize: PAGE_SIZE,
    total,
    items: rows.map(({ total: _t, ...r }) => r),
  };
}

export async function customerCard(sql: Sql, kind: CustomerKind, id: string) {
  const owner = kind === 'company' ? sql`company_id = ${id}` : sql`person_id = ${id}`;

  const [head] =
    kind === 'company'
      ? await sql`
          SELECT id, name, ico, dic, ic_dph, vat_payer, legal_form, registry_entry, nace, statutory, address,
                 segment, payment_rating, debts_note, insolvency_note, finstat_url, finstat_updated_at,
                 lifecycle_stage, hubspot_id, created_at, updated_at
            FROM company WHERE id = ${id}`
      : await sql`
          SELECT id, first_name, last_name, concat_ws(' ', first_name, last_name) AS name, title, email, phone,
                 mobile, position, address, segment, lifecycle_stage, source, hubspot_id, created_at, updated_at
            FROM contact WHERE id = ${id}`;
  if (!head) return null;

  const [kpi, contacts, companies, ooms, deals, contracts] = await Promise.all([
    sql`
      SELECT count(*)::int AS oom_count,
             count(*) FILTER (WHERE status = 'aktivne')::int AS oom_active,
             sum(coalesce(planned_consumption_vt_mwh, 0) + coalesce(planned_consumption_nt_mwh, 0)) AS planned_consumption_mwh,
             sum(planned_feed_in_mwh) AS planned_feed_in_mwh,
             sum(source_power_kw) AS source_power_kw,
             (SELECT count(*)::int FROM contract WHERE ${owner} AND status = 'aktivna') AS active_contracts
        FROM oom WHERE ${owner}`,
    kind === 'company'
      ? sql`
          SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.title, p.email, p.phone, p.mobile,
                 p.position, cc.is_primary, cc.role
            FROM company_contact cc JOIN contact p ON p.id = cc.contact_id
           WHERE cc.company_id = ${id}
           ORDER BY cc.is_primary DESC, p.last_name, p.first_name`
      : sql`SELECT NULL LIMIT 0`,
    kind === 'person'
      ? sql`
          SELECT c.id, c.name, c.ico, cc.is_primary
            FROM company_contact cc JOIN company c ON c.id = cc.company_id
           WHERE cc.contact_id = ${id}
           ORDER BY c.name`
      : sql`SELECT NULL LIMIT 0`,
    sql`
      SELECT id, eic, type, status, segment, address_street, address_city, address_zip,
             planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh, source_power_kw,
             supply_from, supply_to
        FROM oom WHERE ${owner}
       ORDER BY status, eic`,
    sql`
      SELECT d.id, d.name, pl.name AS pipeline, st.name AS stage, st.is_closed, st.is_won,
             d.closed_at, d.created_at, d.hubspot_id,
             (SELECT count(*)::int FROM deal_oom x WHERE x.deal_id = d.id) AS oom_count,
             k.id AS contract_id
        FROM deal d
        JOIN pipeline pl ON pl.id = d.pipeline_id
        JOIN pipeline_stage st ON st.id = d.stage_id
        LEFT JOIN contract k ON k.deal_id = d.id
       WHERE d.${sql(kind === 'company' ? 'company_id' : 'person_id')} = ${id}
       ORDER BY d.closed_at DESC NULLS LAST, d.created_at DESC`,
    sql`
      SELECT k.id, k.number, k.status, k.confirmed, k.valid_from, k.valid_to, d.name AS deal_name,
             (SELECT count(DISTINCT oom_id)::int FROM contract_price cp WHERE cp.contract_id = k.id) AS oom_count,
             (SELECT count(*)::int FROM contract_price cp WHERE cp.contract_id = k.id) AS price_count
        FROM contract k LEFT JOIN deal d ON d.id = k.deal_id
       WHERE k.${sql(kind === 'company' ? 'company_id' : 'person_id')} = ${id}
       ORDER BY k.valid_to DESC NULLS FIRST, k.valid_from DESC`,
  ]);

  return { kind, ...head, kpi: kpi[0], contacts, companies, ooms, deals, contracts };
}
