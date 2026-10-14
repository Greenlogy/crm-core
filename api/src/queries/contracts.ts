// Zmluvy (modul 4): zoznam (obrazovka 25) a karta (obrazovka 26). Fáza z Office portálu a vypočítaný stav (0025),
// OOM v zmluve, ceny po zložkách, príznaky, história importov (0026). Bilancia (pridaná hodnota, marža) príde v 0027.
// Čo používateľ vidí, rieši RLS (zmluvy „iba svoje“ = zákazník aj uzatvoril, „schvaľuje ceny“ vidí všetky).

import type { Sql } from '../db';

export const CONTRACT_PAGE_SIZE = 50;
export const CONTRACT_STATES = ['v_priprave', 'podpisana', 'ucinna', 'skoncena', 'odmietnuta', 'neuspesna'] as const;
export const CONTRACT_TYPES = ['dodavka_domacnost', 'dodavka_firma_nn', 'dodavka_firma_vn', 'vykup', 'viwa'] as const;
export const CONTRACT_FLAGS = ['chyba_cena', 'kontrola_importu', 'sprolongovane_bez_ceny', 'konci_do_4_mesiacov', 'pod_hranicou_bez_vynimky'] as const;
/** Tlačidlá zoznamu: stavy a príznaky. */
export const CONTRACT_CHIPS = new Set<string>(['', ...CONTRACT_STATES, ...CONTRACT_FLAGS]);

export type ContractFilter = { q: string; chip: string; type: string; owner: string; org: string; page: number };

export async function listContracts(sql: Sql, f: ContractFilter, pageSize = CONTRACT_PAGE_SIZE) {
  const like = `%${f.q}%`;
  const eic = f.q.toUpperCase().replace(/\s/g, '');
  const chipCond =
    f.chip === ''
      ? sql`TRUE`
      : (CONTRACT_STATES as readonly string[]).includes(f.chip)
        ? sql`k.state = ${f.chip}`
        : sql`${f.chip} = ANY (k.flags)`;
  // Hľadanie a filtre platia aj pre počty v tlačidlách; tlačidlo iba pre riadky.
  const base = sql`
    (${f.q} = '' OR k.number ILIKE ${like} OR k.customer_name ILIKE ${like}
      OR EXISTS (SELECT 1 FROM contract_oom co JOIN oom o ON o.id = co.oom_id
                  WHERE co.contract_id = k.id AND o.eic LIKE ${'%' + eic + '%'}))
    AND (${f.type} = '' OR k.type::text = ${f.type})
    AND (${f.owner} = '' OR k.owner_id::text = ${f.owner} OR (${f.owner} = 'bez' AND k.owner_id IS NULL))
    AND (${f.org} = '' OR k.org_id::text = ${f.org})`;

  const [rows, counts] = await Promise.all([
    sql`
      SELECT k.id, k.number, k.type, k.phase, k.state, k.valid_from, k.valid_to, k.effective_to, k.crm_valid_to,
             k.auto_prolong, k.customer_kind, k.customer_name, k.company_id, k.person_id, k.owner_id, k.owner_name,
             k.oom_count, k.qty_mwh, to_jsonb(k.flags) AS flags, k.org_id, g.legal_name AS org_name,
             count(*) OVER ()::int AS total
        FROM contract_v k
        JOIN org g ON g.id = k.org_id
       WHERE ${base} AND (${chipCond})
       ORDER BY k.valid_from DESC NULLS FIRST, k.number DESC
       LIMIT ${pageSize} OFFSET ${(f.page - 1) * pageSize}`,
    sql`
      SELECT count(*)::int AS all,
             ${sql.unsafe(CONTRACT_STATES.map((s) => `count(*) FILTER (WHERE k.state = '${s}')::int AS ${s}`).join(', '))},
             ${sql.unsafe(CONTRACT_FLAGS.map((s) => `count(*) FILTER (WHERE '${s}' = ANY (k.flags))::int AS ${s}`).join(', '))}
        FROM contract_v k
       WHERE ${base}`,
  ]);

  return {
    page: f.page,
    pageSize,
    total: rows[0]?.total ?? 0,
    counts: counts[0],
    items: rows.map(({ total: _t, ...r }) => r),
  };
}

/** Možnosti filtra: obchodníci s aspoň jednou viditeľnou zmluvou; aktívni používatelia (zmena obchodníka zmluvy). */
export async function contractFilters(sql: Sql) {
  const [owners, users] = await Promise.all([
    sql`SELECT DISTINCT u.id, u.name FROM contract k JOIN app_user u ON u.id = k.owner_id ORDER BY u.name`,
    sql`SELECT id, name FROM app_user WHERE status <> 'deaktivovany' ORDER BY lower(name)`,
  ]);
  return { owners, users };
}

export async function contractCard(sql: Sql, id: string) {
  const [contract] = await sql`
    SELECT k.*, to_jsonb(k.flags) AS flags,
           pk.number AS previous_number, rk.number AS related_number, rk.type AS related_type,
           crm_contract_editable(k.company_id, k.person_id, k.owner_id) AS can_edit,
           crm_can_change_owner() AS can_change_owner
      FROM contract_v k
      LEFT JOIN contract pk ON pk.id = k.previous_contract_id
      LEFT JOIN contract rk ON rk.id = k.related_contract_id
     WHERE k.id = ${id}`;
  if (!contract) return null;

  const [ooms, prices, flags, imports, successors] = await Promise.all([
    sql`
      SELECT o.id, o.eic, o.type, o.status, o.name, o.address_street, o.address_number_orientacne, o.address_city,
             o.voltage_level, o.breaker_a, o.public_lighting, o.price_regulation,
             (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = o.pds_tariff LIMIT 1) AS tariff_label,
             p.name AS product_name, pg.name AS program_name,
             co.qty_vt_mwh, co.qty_nt_mwh, co.source_power_kw, co.valid_from, co.valid_to, co.op_valid_to, co.is_binding,
             sk.id AS successor_id, sk.number AS successor_number
        FROM contract_oom co
        JOIN oom o ON o.id = co.oom_id
        LEFT JOIN product p ON p.id = co.product_id
        LEFT JOIN product pg ON pg.id = co.program_id
        LEFT JOIN contract sk ON sk.id = co.successor_id
       WHERE co.contract_id = ${id}
       ORDER BY o.eic`,
    sql`
      SELECT cp.id, cp.oom_id, o.eic, pr.code AS product, pr.name AS product_name, cp.op_product_name, cp.slot, cp.price_model,
             cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.additive_pct,
             cp.fee_eur_month, cp.fee_kw_eur_month, cp.valid_from, cp.valid_to, cp.source,
             l.name AS price_list_name, v.name AS price_list_version,
             CASE WHEN cp.valid_from <= crm_today() AND (cp.valid_to IS NULL OR cp.valid_to >= crm_today())
                  THEN 'platna' ELSE 'neplatna' END AS status
        FROM contract_price cp
        LEFT JOIN oom o ON o.id = cp.oom_id
        LEFT JOIN product pr ON pr.id = cp.product_id
        LEFT JOIN price_list_item i ON i.id = cp.price_list_item_id
        LEFT JOIN price_list_version v ON v.id = i.version_id
        LEFT JOIN price_list l ON l.id = v.price_list_id
       WHERE cp.contract_id = ${id}
       ORDER BY cp.valid_from, cp.slot, o.eic NULLS FIRST`,
    sql`
      SELECT f.id, f.code, f.year, f.detail, f.raised_at, f.resolved_at, u.name AS resolved_by_name
        FROM contract_flag f
        LEFT JOIN app_user u ON u.id = f.resolved_by
       WHERE f.contract_id = ${id}
       ORDER BY f.resolved_at IS NOT NULL, f.raised_at DESC`,
    sql`
      SELECT c.import_id, c.action, c.summary, i.created_at, i.op_file_name, i.xm_file_name, u.name AS user_name
        FROM contract_import_change c
        JOIN contract_import i ON i.id = c.import_id
        LEFT JOIN app_user u ON u.id = i.user_id
       WHERE c.contract_id = ${id}
       ORDER BY i.created_at DESC`,
    // zmluvy, ktoré táto na niektorom OOM skrátila (nástupníctvo)
    sql`
      SELECT DISTINCT k.id, k.number FROM contract_oom co JOIN contract k ON k.id = co.contract_id
       WHERE co.successor_id = ${id} ORDER BY k.number`,
  ]);

  return { ...contract, ooms, prices, flag_rows: flags, imports, predecessors: successors };
}
