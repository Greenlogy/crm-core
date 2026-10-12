// Zoznam zákazníkov, karta firmy a karta osoby – modul Zákazníci (migrácia 0004, dizajn 01, 08, 10).
// Zoznam ide z customer_v: firmy s označením zákazník + osoby-domácnosti (zadanie čl. 3, 9).

import type { Sql } from '../db';

export const PAGE_SIZE = 50;
export type CustomerKind = 'company' | 'person';

export const STATUSES = [
  'marketingovy_kontakt', 'zaujemca', 'ponuka', 'cakajuci_zakaznik', 'zakaznik', 'byvaly_zakaznik', 'zruseny_zakaznik',
] as const;
// '' = predvolený zoznam (bez marketingových kontaktov a archívu), 'leady' = Záujemca + Ponuka, 'vsetky' = aj archív
export const STATUS_FILTERS = new Set<string>(['', 'leady', 'vsetky', ...STATUSES]);
export const SEGMENT_FILTERS = new Set(['', 'domacnost', 'firma', 'vyrobca']);

export type CustomerFilter = { q: string; status: string; segment: string; owner: string; page: number };

// Mesto z adresy „ulica, PSČ mesto“ (posledná časť bez PSČ).
const CITY = (address: string) =>
  `nullif(btrim(regexp_replace(split_part(${address}, ',', array_length(string_to_array(${address}, ','), 1)), '^[0-9 ]+', '')), '')`;

export async function listCustomers(sql: Sql, f: CustomerFilter) {
  const like = `%${f.q}%`;
  const statusCond =
    f.status === ''
      ? sql`cu.status IS DISTINCT FROM 'marketingovy_kontakt' AND NOT cu.archived`
      : f.status === 'leady'
        ? sql`cu.status IN ('zaujemca', 'ponuka')`
        : f.status === 'vsetky'
          ? sql`TRUE`
          : sql`cu.status = ${f.status}`;
  // Hľadanie, segment a obchodník platia aj pre počty v tlačidlách stavov; stav iba pre riadky.
  const base = sql`
    (${f.q} = '' OR cu.name ILIKE ${like} OR cu.ico LIKE ${f.q.replace(/\s/g, '') + '%'} OR cu.email ILIKE ${like})
    AND ${
      f.segment === 'domacnost'
        ? sql`cu.customer_type = 'B2C'`
        : f.segment === 'firma'
          ? sql`cu.customer_type = 'B2B'`
          : f.segment === 'vyrobca'
            ? sql`cu.is_producer`
            : sql`TRUE`
    }
    AND (${f.owner} = '' OR cu.owner_id::text = ${f.owner})`;

  const [rows, counts] = await Promise.all([
    sql`
      SELECT CASE cu.customer_type WHEN 'B2B' THEN 'company' ELSE 'person' END AS kind,
             cu.id, cu.name, cu.ico, cu.customer_type, cu.status, cu.status_source, cu.is_former_customer, cu.is_producer,
             cu.segment_label, cu.owner_id, u.name AS owner_name, cu.active_oom_count, cu.annual_mwh, cu.last_activity_at,
             cu.archived, x.city, x.company_count, x.is_statutory,
             (SELECT min(k.valid_from) FROM contract k
               WHERE (k.company_id = cu.id OR k.person_id = cu.id) AND k.valid_from > current_date
                 AND k.status IN ('podpisana', 'caka_na_zaradenie', 'aktivna')) AS future_from,
             count(*) OVER ()::int AS total
        FROM customer_v cu
        LEFT JOIN app_user u ON u.id = cu.owner_id
        CROSS JOIN LATERAL (
          SELECT ${sql.unsafe(CITY('a.address'))} AS city,
                 (SELECT count(*)::int FROM company_contact cc WHERE cc.contact_id = cu.person_id) AS company_count,
                 EXISTS (SELECT 1 FROM company_contact cc
                          WHERE cc.contact_id = cu.person_id AND 'statutar' = ANY (cc.roles)) AS is_statutory
            FROM (SELECT coalesce((SELECT address FROM company WHERE id = cu.company_id),
                                  (SELECT address FROM contact WHERE id = cu.person_id)) AS address) a
        ) x
       WHERE ${base} AND ${statusCond}
       ORDER BY cu.name, cu.id
       LIMIT ${PAGE_SIZE} OFFSET ${(f.page - 1) * PAGE_SIZE}`,
    sql`
      SELECT cu.status, cu.archived, count(*)::int AS n
        FROM customer_v cu
       WHERE ${base}
       GROUP BY cu.status, cu.archived`,
  ]);

  const byStatus: Record<string, number> = Object.fromEntries(STATUSES.map((s) => [s, 0]));
  let archived = 0;
  let visible = 0;
  for (const c of counts) {
    if (c.archived) archived += c.n;
    else if (c.status) byStatus[c.status] += c.n;
    if (!c.archived && c.status !== 'marketingovy_kontakt') visible += c.n;
  }

  const total = rows[0]?.total ?? 0;
  return {
    page: f.page,
    pageSize: PAGE_SIZE,
    total,
    counts: { visible, archived, all: counts.reduce((n, c) => n + c.n, 0), byStatus },
    items: rows.map(({ total: _t, ...r }) => r),
  };
}

// Počty do menu: leady a zákazníci (predvolený zoznam).
export async function menuCounts(sql: Sql) {
  const [r] = await sql`
    SELECT count(*) FILTER (WHERE status IN ('zaujemca', 'ponuka'))::int AS leads,
           count(*) FILTER (WHERE status IS DISTINCT FROM 'marketingovy_kontakt' AND NOT archived)::int AS customers
      FROM customer_v`;
  return r;
}

// Obchodníci, ktorí vlastnia aspoň jedného zákazníka (filter zoznamu).
export async function listOwners(sql: Sql) {
  return sql`
    SELECT u.id, u.name
      FROM app_user u
     WHERE EXISTS (SELECT 1 FROM customer_v cu WHERE cu.owner_id = u.id)
     ORDER BY u.name`;
}

// Vývoj stavu z audit_log: vloženie so stavom a každá zmena stavu (najnovšie prvé).
// Z jednej transakcie (rovnaký čas) sa berie iba posledná zmena – napr. pri nahratí z HubSpotu.
function statusHistory(sql: Sql, table: 'company' | 'contact', id: string) {
  return sql`
    SELECT status, source, changed_at
      FROM (
        SELECT DISTINCT ON (a.changed_at)
               CASE a.action WHEN 'insert' THEN a.diff ->> 'status' ELSE a.diff -> 'status' ->> 'new' END AS status,
               CASE a.action WHEN 'insert' THEN a.diff ->> 'status_source' ELSE a.diff -> 'status_source' ->> 'new' END AS source,
               a.changed_at
          FROM audit_log a
         WHERE a.table_name = ${table} AND a.record_id = ${id}
           AND (a.diff ? 'status') AND a.action IN ('insert', 'update')
         ORDER BY a.changed_at, a.id DESC
      ) h
     WHERE status IS NOT NULL
     ORDER BY changed_at DESC`;
}

export async function customerCard(sql: Sql, kind: CustomerKind, id: string) {
  const owner = kind === 'company' ? sql`company_id = ${id}` : sql`person_id = ${id}`;

  const [head] =
    kind === 'company'
      ? await sql`
          SELECT c.id, c.name, c.ico, c.dic, c.ic_dph, c.vat_payer, c.legal_form, c.registry_entry, c.nace, c.statutory,
                 c.address, c.bank_account, c.payment_rating, c.debts_note, c.insolvency_note, c.finstat_url,
                 c.finstat_updated_at, c.is_customer, c.is_partner, c.is_supplier,
                 c.status, c.status_source, c.status_changed_at, c.is_former_customer, c.is_producer,
                 CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
                 company_is_archived(c) AS archived, ${sql.unsafe(CITY('c.address'))} AS city,
                 c.hubspot_id, c.created_at, c.updated_at, u.name AS owner_name, t.name AS owner_team
            FROM company c
            LEFT JOIN app_user u ON u.id = c.owner_id
            LEFT JOIN team t ON t.id = u.team_id
           WHERE c.id = ${id}`
      : await sql`
          SELECT p.id, p.first_name, p.last_name, concat_ws(' ', p.first_name, p.last_name) AS name, p.title, p.email,
                 p.phone, p.mobile, p.position, p.address, p.source, p.is_household,
                 p.status, p.status_source, p.status_changed_at, p.is_former_customer, p.is_producer,
                 CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END AS segment_label,
                 p.archived, p.marketing_allowed, p.marketing_opt_out_at, p.marketing_opt_out_source,
                 ${sql.unsafe(CITY('p.address'))} AS city,
                 p.hubspot_id, p.created_at, p.updated_at, u.name AS owner_name, t.name AS owner_team
            FROM contact_v p
            LEFT JOIN app_user u ON u.id = p.owner_id
            LEFT JOIN team t ON t.id = u.team_id
           WHERE p.id = ${id}`;
  if (!head) return null;

  const [kpi, contacts, companies, ooms, deals, contracts, history] = await Promise.all([
    sql`
      SELECT count(*)::int AS oom_count,
             count(*) FILTER (WHERE status = 'aktivne')::int AS oom_active,
             sum(coalesce(planned_consumption_vt_mwh, 0) + coalesce(planned_consumption_nt_mwh, 0))
               FILTER (WHERE type <> 'vyroba') AS planned_consumption_mwh,
             count(*) FILTER (WHERE type <> 'vyroba' AND status = 'aktivne')::int AS consumption_active,
             sum(planned_feed_in_mwh) AS planned_feed_in_mwh,
             sum(source_power_kw) AS source_power_kw,
             count(*) FILTER (WHERE type = 'vyroba')::int AS production_count,
             (SELECT count(*)::int FROM contract WHERE ${owner} AND status = 'aktivna') AS active_contracts
        FROM oom WHERE ${owner}`,
    kind === 'company'
      ? sql`
          SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.title, p.email, p.phone, p.mobile,
                 p.position, cc.is_main_contact, to_jsonb(cc.roles) AS roles, p.is_household, p.marketing_opt_out_at,
                 (SELECT count(*)::int FROM company_contact o WHERE o.contact_id = p.id AND o.company_id <> ${id})
                   AS other_companies
            FROM company_contact cc JOIN contact p ON p.id = cc.contact_id
           WHERE cc.company_id = ${id}
           ORDER BY cc.is_main_contact DESC, p.last_name, p.first_name`
      : sql`SELECT NULL LIMIT 0`,
    kind === 'person'
      ? sql`
          SELECT c.id, c.name, c.ico, cc.is_main_contact, to_jsonb(cc.roles) AS roles, c.is_customer, c.status,
                 CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
                 company_is_archived(c) AS archived
            FROM company_contact cc JOIN company c ON c.id = cc.company_id
           WHERE cc.contact_id = ${id}
           ORDER BY cc.is_main_contact DESC, c.name`
      : sql`SELECT NULL LIMIT 0`,
    sql`
      SELECT id, eic, type, status, segment, address_street, address_city, address_zip,
             planned_consumption_vt_mwh, planned_consumption_nt_mwh, planned_feed_in_mwh, source_power_kw,
             supply_from, supply_to
        FROM oom WHERE ${owner}
       ORDER BY status, eic`,
    sql`
      SELECT d.id, d.name, pl.name AS pipeline, st.name AS stage, st.is_closed, st.is_won,
             d.closed_at, d.created_at, d.hubspot_id, u.name AS owner_name,
             (SELECT count(*)::int FROM deal_oom x WHERE x.deal_id = d.id) AS oom_count,
             k.id AS contract_id
        FROM deal d
        JOIN pipeline pl ON pl.id = d.pipeline_id
        JOIN pipeline_stage st ON st.id = d.stage_id
        LEFT JOIN contract k ON k.deal_id = d.id
        LEFT JOIN app_user u ON u.id = d.owner_id
       WHERE d.${sql(kind === 'company' ? 'company_id' : 'person_id')} = ${id}
       ORDER BY d.closed_at DESC NULLS LAST, d.created_at DESC`,
    sql`
      SELECT k.id, k.number, k.status, k.confirmed, k.valid_from, k.valid_to, d.name AS deal_name, pl.name AS pipeline,
             (SELECT count(DISTINCT oom_id)::int FROM contract_price cp WHERE cp.contract_id = k.id) AS oom_count,
             (SELECT count(*)::int FROM contract_price cp WHERE cp.contract_id = k.id) AS price_count
        FROM contract k
        LEFT JOIN deal d ON d.id = k.deal_id
        LEFT JOIN pipeline pl ON pl.id = d.pipeline_id
       WHERE k.${sql(kind === 'company' ? 'company_id' : 'person_id')} = ${id}
       ORDER BY k.valid_to DESC NULLS FIRST, k.valid_from DESC`,
    statusHistory(sql, kind === 'company' ? 'company' : 'contact', id),
  ]);

  return { kind, ...head, kpi: kpi[0], contacts, companies, ooms, deals, contracts, history };
}
