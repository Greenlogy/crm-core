// Karta zmluvy (0025: fáza z Office portálu a vypočítaný stav, OOM v zmluve, ceny po zložkách).
// Plná karta (obrazovka 26) príde s importom v module 4, F2; zatiaľ hlavička, OOM, ceny a nákupné ceny.

import type { Sql } from '../db';

export async function contractCard(sql: Sql, id: string) {
  const [contract] = await sql`
    SELECT k.*, k.state AS status,
           d.name AS deal_name, d.hubspot_id AS deal_hubspot_id, pl.name AS pipeline, st.name AS stage
      FROM contract_v k
      LEFT JOIN deal d ON d.id = k.deal_id
      LEFT JOIN pipeline pl ON pl.id = d.pipeline_id
      LEFT JOIN pipeline_stage st ON st.id = d.stage_id
     WHERE k.id = ${id}`;
  if (!contract) return null;

  const [ooms, prices, purchases] = await Promise.all([
    // OOM zmluvy: z OOM v zmluve aj z dealu.
    sql`
      SELECT o.id, o.eic, o.type, o.status, o.address_street, o.address_city,
             o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh, o.planned_feed_in_mwh,
             co.qty_vt_mwh, co.qty_nt_mwh, co.valid_from AS contract_valid_from, co.valid_to AS contract_valid_to
        FROM oom o
        LEFT JOIN contract_oom co ON co.oom_id = o.id AND co.contract_id = ${id}
       WHERE o.id IN (SELECT oom_id FROM contract_oom WHERE contract_id = ${id}
                      UNION
                      SELECT oom_id FROM deal_oom WHERE deal_id = ${contract.deal_id})
       ORDER BY o.eic`,
    sql`
      SELECT cp.id, cp.oom_id, o.eic, pr.code AS product, cp.slot, cp.price_model,
             cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.additive_pct,
             cp.fee_eur_month, cp.fee_kw_eur_month, cp.valid_from, cp.valid_to,
             CASE WHEN cp.valid_from <= crm_today() AND (cp.valid_to IS NULL OR cp.valid_to >= crm_today())
                  THEN 'platna' ELSE 'neplatna' END AS status
        FROM contract_price cp
        LEFT JOIN oom o ON o.id = cp.oom_id
        LEFT JOIN product pr ON pr.id = cp.product_id
       WHERE cp.contract_id = ${id}
       ORDER BY o.eic NULLS FIRST, cp.slot, cp.valid_from DESC`,
    sql`
      SELECT id, product_code, delivery_year, priced_on, price_eur_mwh, cockpit_ref
        FROM contract_purchase
       WHERE contract_id = ${id}
       ORDER BY delivery_year, priced_on`,
  ]);

  return { ...contract, ooms, prices, purchases };
}
