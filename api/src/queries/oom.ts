// Zoznam a karta odberného miesta – modul Odberné miesta (migrácie 0013–0015, dizajn 17 a 18).
// Zoznam ide z pohľadu oom_v; práva („iba svoje“, spoločnosti) stráži databáza (RLS), API ich neopakuje.

import type { Sql } from '../db';

export const OOM_PAGE_SIZE = 50;
export const OOM_STATUSES = ['pripravovane', 'aktivne', 'odidene', 'zrusene'] as const;
export const OOM_TYPES = ['spotreba', 'vyroba', 'sharing'] as const;
// '' = všetky; stav; 'prepisane' = OOM s prepisom na iného odberateľa; 'zasekol' = prechod sa zasekol
export const OOM_CHIPS = new Set<string>(['', ...OOM_STATUSES, 'prepisane', 'zasekol', 'zlyhal']);

export type OomFilter = { q: string; chip: string; type: string; pds: string; owner: string; org: string; page: number };

export async function listOom(sql: Sql, f: OomFilter, pageSize = OOM_PAGE_SIZE) {
  const like = `%${f.q}%`;
  const eic = f.q.toUpperCase().replace(/\s/g, '');
  const chipCond =
    f.chip === ''
      ? sql`TRUE`
      : f.chip === 'prepisane'
        ? sql`v.transferred_from_name IS NOT NULL OR EXISTS (SELECT 1 FROM oom_customer l WHERE l.oom_id = v.id AND l.end_reason = 'prepis')`
        : f.chip === 'zasekol'
          ? sql`v.switch_stuck`
          : f.chip === 'zlyhal'
            ? sql`v.plan_failed`
            : sql`v.status = ${f.chip}`;
  // Hľadanie a filtre platia aj pre počty v tlačidlách; tlačidlo (stav) iba pre riadky.
  const base = sql`
    (${f.q} = '' OR v.eic LIKE ${'%' + eic + '%'} OR v.name ILIKE ${like} OR v.customer_name ILIKE ${like}
      OR concat_ws(' ', v.address_street, v.address_number_supisne, v.address_number_orientacne, v.address_zip, v.address_city) ILIKE ${like})
    AND (${f.type} = '' OR v.type::text = ${f.type})
    AND (${f.pds} = '' OR v.pds = ${f.pds})
    AND (${f.owner} = '' OR v.owner_id::text = ${f.owner})
    AND (${f.org} = '' OR v.org_id::text = ${f.org})`;

  const [rows, counts] = await Promise.all([
    sql`
      SELECT v.id, v.eic, v.name, v.address_street, v.address_number_supisne, v.address_number_orientacne,
             v.address_city, v.address_zip, v.type, v.status, v.company_id, v.person_id, v.customer_type, v.customer_name,
             v.owner_id, v.owner_name, v.org_id, g.legal_name AS org_name, v.pds, v.pds_label, v.pds_tariff_label,
             v.planned_mwh, v.supply_from, v.supply_to, v.switch_stuck, to_jsonb(v.active_missing) AS active_missing,
             v.transferred_from_name, v.transferred_on, v.plan_kind, v.plan_date, v.plan_failed,
             count(*) OVER ()::int AS total
        FROM oom_v v
        JOIN org g ON g.id = v.org_id
       WHERE ${base} AND (${chipCond})
       ORDER BY v.customer_name NULLS LAST, v.name NULLS LAST, v.eic
       LIMIT ${pageSize} OFFSET ${(f.page - 1) * pageSize}`,
    sql`
      SELECT count(*)::int AS all,
             count(*) FILTER (WHERE v.status = 'pripravovane')::int AS pripravovane,
             count(*) FILTER (WHERE v.status = 'aktivne')::int AS aktivne,
             count(*) FILTER (WHERE v.status = 'odidene')::int AS odidene,
             count(*) FILTER (WHERE v.status = 'zrusene')::int AS zrusene,
             count(*) FILTER (WHERE EXISTS (SELECT 1 FROM oom_customer l WHERE l.oom_id = v.id AND l.end_reason = 'prepis'))::int AS prepisane,
             count(*) FILTER (WHERE v.switch_stuck)::int AS zasekol,
             count(*) FILTER (WHERE v.plan_failed)::int AS zlyhal
        FROM oom_v v
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

// Možnosti filtrov zoznamu: PDS a vlastníci, ktorí majú aspoň jedno OOM (iba z toho, čo používateľ vidí).
export async function oomFilters(sql: Sql) {
  const [pds, owners] = await Promise.all([
    sql`
      SELECT v.code, v.label
        FROM lookup_value v
       WHERE v.list_code = 'pds' AND EXISTS (SELECT 1 FROM oom o WHERE o.pds = v.code)
       ORDER BY v.sort_order, v.label`,
    sql`
      SELECT DISTINCT v.owner_id AS id, v.owner_name AS name
        FROM oom_v v
       WHERE v.owner_id IS NOT NULL
       ORDER BY v.owner_name`,
  ]);
  return { pds, owners };
}

// Popis hodnoty číselníka (kód → názov) priamo v dotaze
const LABEL = (list: string, column: string) =>
  `(SELECT lv.label FROM lookup_value lv WHERE lv.list_code = '${list}' AND lv.code = o.${column})`;

export async function oomCard(sql: Sql, id: string) {
  const [oom] = await sql`
    SELECT o.*, v.customer_type, v.customer_name, v.owner_id, v.owner_name, v.pds_label, v.pds_tariff_label,
           v.planned_mwh, v.switch_stuck, to_jsonb(v.active_missing) AS active_missing, v.transferred_from_name, v.transferred_on,
           v.plan_kind, v.plan_date, v.plan_id, v.plan_failed,
           CASE WHEN o.company_id IS NOT NULL THEN 'company' ELSE 'person' END AS customer_kind,
           g.legal_name AS org_name, g.oom_switch_accept_days, g.oom_switch_confirm_days,
           ${sql.unsafe(LABEL('typ_merania', 'metering_type'))} AS metering_type_label,
           ${sql.unsafe(LABEL('fakturacne_obdobie', 'billing_period'))} AS billing_period_label,
           ${sql.unsafe(LABEL('sposob_zaloh', 'advance_payment_method'))} AS advance_payment_method_label,
           ${sql.unsafe(LABEL('typ_vykupnej_zmluvy', 'feed_in_contract_type'))} AS feed_in_contract_type_label,
           ${sql.unsafe(LABEL('predchadzajuci_dodavatel', 'previous_supplier'))} AS previous_supplier_label,
           crm_oom_access(o.id, 'edit') AS can_edit,
           crm_can_edit_active_oom() AS can_edit_active
      FROM oom o
      JOIN oom_v v ON v.id = o.id
      JOIN org g ON g.id = o.org_id
     WHERE o.id = ${id}`;
  if (!oom) return null;

  const [links, devices, contacts, deals, prices, timeline, plans] = await Promise.all([
    // História väzieb: iba riadky, ktoré používateľ vidí (RLS); meno zákazníka iba ak ho smie vidieť.
    sql`
      SELECT l.id, l.company_id, l.person_id, l.valid_from, l.valid_to, l.status, l.end_reason,
             coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
             CASE WHEN l.company_id IS NOT NULL THEN 'company' ELSE 'person' END AS customer_kind
        FROM oom_customer l
        LEFT JOIN company c ON c.id = l.company_id
        LEFT JOIN contact p ON p.id = l.person_id
       WHERE l.oom_id = ${id}
       ORDER BY l.valid_from DESC`,
    sql`
      SELECT id, device_type, brand, model, power_kw, capacity_kwh, count
        FROM oom_device
       WHERE oom_id = ${id}
       ORDER BY device_type, created_at`,
    // Kontaktné osoby pri OOM a osoby z dealov (contact_oom_v): iba pri Aktívnom alebo Pripravovanom OOM.
    sql`
      SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.email, p.phone, p.mobile,
             to_jsonb(v.sources) AS sources, to_jsonb(v.roles) AS roles,
             coalesce((SELECT jsonb_agg(lv.label ORDER BY lv.sort_order) FROM lookup_value lv
                        WHERE lv.list_code = 'rola_pri_oom' AND lv.code = ANY (v.roles)), '[]') AS role_labels
        FROM contact_oom_v v
        JOIN contact p ON p.id = v.contact_id
       WHERE v.oom_id = ${id}
       ORDER BY p.last_name, p.first_name`,
    sql`
      SELECT d.id, d.name, pl.name AS pipeline, st.name AS stage, st.is_closed, st.is_won, d.closed_at,
             u.name AS owner_name, k.id AS contract_id, k.number AS contract_number
        FROM deal_oom x
        JOIN deal d ON d.id = x.deal_id
        JOIN pipeline pl ON pl.id = d.pipeline_id
        JOIN pipeline_stage st ON st.id = d.stage_id
        LEFT JOIN contract k ON k.deal_id = d.id
        LEFT JOIN app_user u ON u.id = d.owner_id
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
    // Časová os z auditu: OOM, väzby, zariadenia a kontaktné osoby tohto OOM (aj zmazané).
    // Obrazovka udalosti pomenuje sama; tu iba surové zmeny, kto, kedy, zdroj a súbor importu.
    sql`
      SELECT a.id, a.table_name, a.record_id, a.action, a.diff, a.changed_at, a.source, u.name AS user_name, i.file_name AS import_file
        FROM audit_log a
        LEFT JOIN app_user u ON u.id = a.changed_by
        LEFT JOIN oom_import i ON i.id = a.import_id
       WHERE ((a.table_name = 'oom' AND a.record_id = ${id})
              OR (a.table_name IN ('oom_customer', 'oom_device', 'oom_contact', 'oom_planned_change')
                  AND (a.record_id IN (SELECT l.id FROM oom_customer l WHERE l.oom_id = ${id}
                                       UNION ALL SELECT pl.id FROM oom_planned_change pl WHERE pl.oom_id = ${id}
                                       UNION ALL SELECT d.id FROM oom_device d WHERE d.oom_id = ${id}
                                       UNION ALL SELECT k.id FROM oom_contact k WHERE k.oom_id = ${id})
                       -- zmazané zariadenia a osoby: oom_id je v obsahu zmazaného riadku
                       OR coalesce(a.diff ->> 'oom_id', a.diff -> 'oom_id' ->> 'old') = ${id}::text)))
         -- iba od posledného založenia (testovacie dáta s rovnakým id sa môžu zmazať a nahrať znova)
         AND a.changed_at >= coalesce((SELECT max(z.changed_at) FROM audit_log z
                                        WHERE z.table_name = 'oom' AND z.record_id = ${id} AND z.action = 'insert'), '-infinity')
       ORDER BY a.changed_at DESC, a.id DESC
       LIMIT 200`,
    // Plány: aktívny, zlyhané a posledné vykonané / zrušené (0016)
    sql`
      SELECT pl.id, pl.kind, pl.effective_date, pl.status, pl.error, pl.company_id, pl.person_id,
             coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
             u.name AS created_by_name, pl.created_at, pl.executed_at, pl.cancelled_at, cu.name AS cancelled_by_name
        FROM oom_planned_change pl
        LEFT JOIN company c ON c.id = pl.company_id
        LEFT JOIN contact p ON p.id = pl.person_id
        LEFT JOIN app_user u ON u.id = pl.created_by
        LEFT JOIN app_user cu ON cu.id = pl.cancelled_by
       WHERE pl.oom_id = ${id}
       ORDER BY pl.status = 'planovana' DESC, pl.status = 'zlyhala' DESC, pl.created_at DESC
       LIMIT 10`,
  ]);

  // Mená osôb a zákazníkov v časovej osi (iba tie, ktoré používateľ vidí)
  const personIds = new Set<string>();
  for (const t of timeline) {
    const d = t.diff as Record<string, unknown>;
    for (const k of ['contact_id', 'person_id', 'company_id']) {
      const v = d?.[k];
      if (typeof v === 'string') personIds.add(v);
    }
  }
  const names = personIds.size
    ? await sql`
        SELECT id, name FROM company WHERE id = ANY (string_to_array(${[...personIds].join(',')}, ',')::uuid[])
        UNION ALL
        SELECT id, concat_ws(' ', first_name, last_name) FROM contact
         WHERE id = ANY (string_to_array(${[...personIds].join(',')}, ',')::uuid[])`
    : [];

  return { ...oom, links, devices, contacts, deals, prices, timeline, plans, names: Object.fromEntries(names.map((n) => [n.id, n.name])) };
}
