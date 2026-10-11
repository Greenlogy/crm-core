// Karta odberného miesta.

import type { Sql } from '../db';

export async function oomCard(sql: Sql, id: string) {
  const [oom] = await sql`
    SELECT o.*,
           CASE WHEN o.company_id IS NOT NULL THEN 'company' ELSE 'person' END AS customer_kind,
           coalesce(c.name, concat_ws(' ', p.first_name, p.last_name)) AS customer_name
      FROM oom o
      LEFT JOIN company c ON c.id = o.company_id
      LEFT JOIN contact p ON p.id = o.person_id
     WHERE o.id = ${id}`;
  if (!oom) return null;

  const [deals, prices, contacts] = await Promise.all([
    sql`
      SELECT d.id, d.name, pl.name AS pipeline, st.name AS stage, st.is_closed, st.is_won, d.closed_at,
             k.id AS contract_id, k.number AS contract_number
        FROM deal_oom x
        JOIN deal d ON d.id = x.deal_id
        JOIN pipeline pl ON pl.id = d.pipeline_id
        JOIN pipeline_stage st ON st.id = d.stage_id
        LEFT JOIN contract k ON k.deal_id = d.id
       WHERE x.oom_id = ${id}
       ORDER BY d.closed_at DESC NULLS LAST, d.created_at DESC`,
    sql`
      SELECT cp.id, cp.contract_id, k.number AS contract_number, pr.code AS product, cp.direction,
             cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.imbalance_price_eur_mwh,
             cp.additive_coefficient_pct, cp.fee_oom_eur_month, cp.fee_zem_eur_month, cp.fee_vbattery_eur_month,
             cp.fee_rk_eur_kw_month, cp.vbattery_program, cp.valid_from, cp.valid_to, cp.status
        FROM contract_price cp
        JOIN contract k ON k.id = cp.contract_id
        LEFT JOIN product pr ON pr.id = cp.product_id
       WHERE cp.oom_id = ${id}
       ORDER BY cp.status, cp.valid_from DESC NULLS LAST`,
    // Doménové pravidlo: kontakt sa s OOM prepája cez dealy, iba pri stave Aktívne alebo Neaktívne.
    sql`
      SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.email, p.phone, p.mobile
        FROM contact_oom_v v JOIN contact p ON p.id = v.contact_id
       WHERE v.oom_id = ${id}
       ORDER BY p.last_name, p.first_name`,
  ]);

  return { ...oom, deals, prices, contacts };
}
