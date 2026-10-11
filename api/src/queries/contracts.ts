// Karta zmluvy.

import type { Sql } from '../db';

export async function contractCard(sql: Sql, id: string) {
  const [contract] = await sql`
    SELECT k.*,
           CASE WHEN k.company_id IS NOT NULL THEN 'company' ELSE 'person' END AS customer_kind,
           coalesce(c.name, concat_ws(' ', p.first_name, p.last_name)) AS customer_name,
           d.name AS deal_name, d.hubspot_id AS deal_hubspot_id, pl.name AS pipeline, st.name AS stage
      FROM contract k
      LEFT JOIN company c ON c.id = k.company_id
      LEFT JOIN contact p ON p.id = k.person_id
      LEFT JOIN deal d ON d.id = k.deal_id
      LEFT JOIN pipeline pl ON pl.id = d.pipeline_id
      LEFT JOIN pipeline_stage st ON st.id = d.stage_id
     WHERE k.id = ${id}`;
  if (!contract) return null;

  const [ooms, prices, purchases] = await Promise.all([
    // OOM zmluvy: zo zmluvných cien aj z dealu.
    sql`
      SELECT o.id, o.eic, o.type, o.status, o.address_street, o.address_city,
             o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh, o.planned_feed_in_mwh
        FROM oom o
       WHERE o.id IN (SELECT oom_id FROM contract_price WHERE contract_id = ${id}
                      UNION
                      SELECT oom_id FROM deal_oom WHERE deal_id = ${contract.deal_id})
       ORDER BY o.eic`,
    sql`
      SELECT cp.id, cp.oom_id, o.eic, pr.code AS product, cp.direction,
             cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.imbalance_price_eur_mwh,
             cp.additive_coefficient_pct, cp.fee_oom_eur_month, cp.fee_zem_eur_month, cp.fee_vbattery_eur_month,
             cp.fee_rk_eur_kw_month, cp.vbattery_program, cp.valid_from, cp.valid_to, cp.status
        FROM contract_price cp
        JOIN oom o ON o.id = cp.oom_id
        LEFT JOIN product pr ON pr.id = cp.product_id
       WHERE cp.contract_id = ${id}
       ORDER BY o.eic, cp.status, cp.valid_from DESC NULLS LAST`,
    sql`
      SELECT id, product_code, delivery_year, priced_on, price_eur_mwh, cockpit_ref
        FROM contract_purchase
       WHERE contract_id = ${id}
       ORDER BY delivery_year, priced_on`,
  ]);

  return { ...contract, ooms, prices, purchases };
}
