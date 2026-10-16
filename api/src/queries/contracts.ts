// Zmluvy (modul 4): zoznam (obrazovka 25) a karta (obrazovka 26). Fáza z Office portálu a vypočítaný stav (0025),
// OOM v zmluve, ceny po zložkách, príznaky, história importov (0026), ročná bilancia (0027: pridaná hodnota pre každého,
// kto zmluvu vidí; marža firmy iba s právom – contract_year_calc vráti NULL).
// Čo používateľ vidí, rieši RLS (zmluvy „iba svoje“ = zákazník aj uzatvoril, „schvaľuje ceny“ vidí všetky).

import type { Sql } from '../db';

export const CONTRACT_PAGE_SIZE = 50;
export const CONTRACT_STATES = ['v_priprave', 'podpisana', 'ucinna', 'skoncena', 'odmietnuta', 'neuspesna'] as const;
export const CONTRACT_TYPES = ['dodavka_domacnost', 'dodavka_firma_nn', 'dodavka_firma_vn', 'vykup', 'viwa'] as const;
export const CONTRACT_FLAGS = ['chyba_cena', 'kontrola_importu', 'sprolongovane_bez_ceny', 'konci_do_4_mesiacov', 'pod_hranicou_bez_vynimky', 'nad_30_mwh', 'objem_xm',
  'cena_ina_ako_v_ponuke', 'nesparovana', 'bez_obchodu'] as const;
/** Tlačidlá zoznamu: stavy a príznaky. */
export const CONTRACT_CHIPS = new Set<string>(['', ...CONTRACT_STATES, ...CONTRACT_FLAGS]);

export type ContractFilter = { q: string; chip: string; type: string; owner: string; org: string; page: number; year: number };

// Končí do 4 mesiacov: podpísaná zmluva o dodávke firmy alebo výkup (odpoveď 34), skutočný koniec od dnes do 4 mesiacov
// (upozornenie posiela nočný beh, 0028)
const ENDING = `(k.state IN ('podpisana', 'ucinna') AND (k.type::text LIKE 'dodavka_firma%' OR k.type = 'vykup')
                 AND k.effective_to BETWEEN crm_today() AND (crm_today() + interval '4 months')::date)`;

// Nad 30 MWh v regulácii (0029): zmluvy regulovaného malého podniku, ktorého ročný objem je dnes nad 30 MWh
// alebo sa objem zo zmlúv a z XM Trade líši okolo hranice (iba upozornenie)
const OVER_30 = `(k.company_id IN (SELECT s.company_id FROM small_business_volume(crm_today()) s
                                    WHERE s.state IN ('vyradit', 'nesulad')))`;
// Objem ≠ XM Trade (0030): zmluvné množstvo sa dnes líši od plánovanej spotreby OOM z XM Trade o viac ako 5 %
const VOLUME_XM = `(k.id IN (SELECT d.contract_id FROM contract_volume_diff(crm_today()) d WHERE d.over))`;
// Párovanie s obchodmi (0045): nespárovaná zmluva čaká na rozhodnutie; „Bez obchodu“ je rozhodnutie (filter, nie problém)
const UNMATCHED = `(k.id IN (SELECT x.id FROM contract x WHERE x.deal_match = 'caka'))`;
const NO_DEAL = `(k.id IN (SELECT x.id FROM contract x WHERE x.deal_match = 'bez_obchodu'))`;
/** Podmienka tlačidla príznaku: uložené príznaky z contract_flag; „Končí do 4 mesiacov“, „Nad 30 MWh“, „Objem ≠ XM Trade“,
 *  „Nespárovaná“ a „Bez obchodu“ sa počítajú. */
const COMPUTED: Record<string, string> = {
  konci_do_4_mesiacov: ENDING, nad_30_mwh: OVER_30, objem_xm: VOLUME_XM, nesparovana: UNMATCHED, bez_obchodu: NO_DEAL,
};
const flagCond = (f: string) => COMPUTED[f] ?? `('${f}' = ANY (k.flags))`;

export async function listContracts(sql: Sql, f: ContractFilter, pageSize = CONTRACT_PAGE_SIZE) {
  const like = `%${f.q}%`;
  const eic = f.q.toUpperCase().replace(/\s/g, '');
  const chipCond =
    f.chip === ''
      ? sql`TRUE`
      : (CONTRACT_STATES as readonly string[]).includes(f.chip)
        ? sql`k.state = ${f.chip}`
        : f.chip in COMPUTED
          ? sql.unsafe(flagCond(f.chip))
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
             ${sql.unsafe(ENDING)} AS ending,
             k.deal_id, dl.name AS deal_name, kx.deal_match,
             count(*) OVER ()::int AS total
        FROM contract_v k
        JOIN org g ON g.id = k.org_id
        JOIN contract kx ON kx.id = k.id
        LEFT JOIN deal dl ON dl.id = k.deal_id
       WHERE ${base} AND (${chipCond})
       ORDER BY k.valid_from DESC NULLS FIRST, k.number DESC
       LIMIT ${pageSize} OFFSET ${(f.page - 1) * pageSize}`,
    sql`
      SELECT count(*)::int AS all,
             ${sql.unsafe(CONTRACT_STATES.map((s) => `count(*) FILTER (WHERE k.state = '${s}')::int AS ${s}`).join(', '))},
             ${sql.unsafe(CONTRACT_FLAGS.map((s) => `count(*) FILTER (WHERE ${flagCond(s)})::int AS ${s}`).join(', '))}
        FROM contract_v k
       WHERE ${base}`,
  ]);

  // ročná bilancia iba pre riadky strany (výpočet po mesiacoch na zmluvu)
  const ids = rows.map((r) => r.id as string);
  const balance = ids.length
    ? await sql`
        SELECT b.id, c.volume_mwh, c.added_value_eur, c.margin_eur, c.portfolio_stale, c.missing, c.months
          FROM contract b, contract_year_calc(b.id, ${f.year}::int) c
         WHERE b.id IN ${sql(ids)}`
    : [];
  const byId = new Map(balance.map((b) => [b.id as string, b]));
  return {
    page: f.page,
    pageSize,
    year: f.year,
    total: rows[0]?.total ?? 0,
    counts: counts[0],
    items: rows.map((row) => {
      const { total: _t, ...r } = row as Record<string, unknown>;
      const b = byId.get(r.id as string);
      return { ...r, year_volume_mwh: b?.volume_mwh ?? null, added_value_eur: b?.added_value_eur ?? null,
               margin_eur: b?.margin_eur ?? null, portfolio_stale: b?.portfolio_stale ?? null, balance_missing: b?.missing ?? null,
               year_months: b?.months ?? 0 };
    }),
  };
}

/** Všetky riadky podľa filtra (export, najviac 5 000) s bilanciou roka. */
export async function exportContracts(sql: Sql, f: ContractFilter) {
  const all: Record<string, unknown>[] = [];
  for (let page = 1; page <= 100; page++) {
    const r = await listContracts(sql, { ...f, page }, 50);
    all.push(...r.items);
    if (r.items.length < 50 || all.length >= 5000) break;
  }
  return all;
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
           crm_can_change_owner() AS can_change_owner,
           (crm_is_admin() OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                                       WHERE u.id = crm_active_user_id() AND t.code = 'nakup')) AS can_edit_vykup,
           crm_approves_prices() AS can_resolve_threshold,
           (SELECT to_jsonb(s) FROM small_business_volume(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.company_id) s
             WHERE k.company_id IS NOT NULL) AS regulation_check,
           (SELECT to_jsonb(d) FROM contract_volume_diff(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.id) d) AS volume_check,
           -- párovanie s obchodom (0045)
           kx.deal_match, kx.deal_matched_at, kx.deal_match_note, mu.name AS deal_matched_by_name, dl.name AS deal_name,
           (SELECT code FROM pipeline_stage WHERE id = dl.stage_id) AS deal_stage,
           offer_display_number(ov) AS offer_number, chr(64 + vv.sort_order) || ' · ' || vv.name AS offer_variant, ov.id AS offer_id,
           crm_contract_match_editor(kx) AS can_decide_deal, crm_is_admin() AS is_admin,
           CASE WHEN kx.deal_match = 'caka' THEN contract_deal_candidates(k.id) END AS deal_candidates
      FROM contract_v k
      JOIN contract kx ON kx.id = k.id
      LEFT JOIN app_user mu ON mu.id = kx.deal_matched_by
      LEFT JOIN deal dl ON dl.id = k.deal_id
      LEFT JOIN offer_variant vv ON vv.id = kx.offer_variant_id
      LEFT JOIN offer ov ON ov.id = vv.offer_id
      LEFT JOIN contract pk ON pk.id = k.previous_contract_id
      LEFT JOIN contract rk ON rk.id = k.related_contract_id
     WHERE k.id = ${id}`;
  if (!contract) return null;

  // roky bilancie: od začiatku OOM v zmluve po koniec (pri dobe neurčitej bežný a nasledujúci rok)
  const [span] = await sql<{ y1: number | null; y2: number | null }[]>`
    SELECT extract(year FROM min(valid_from))::int AS y1,
           greatest(extract(year FROM max(coalesce(valid_to, make_date(extract(year FROM crm_today())::int + 1, 12, 31))))::int,
                    extract(year FROM min(valid_from))::int) AS y2
      FROM contract_oom WHERE contract_id = ${id} AND valid_from IS NOT NULL`;
  const [ooms, prices, flags, imports, successors, balance, exceptions] = await Promise.all([
    sql`
      SELECT o.id, o.eic, o.type, o.status, o.name, o.address_street, o.address_number_orientacne, o.address_city,
             o.voltage_level, o.breaker_a, o.public_lighting, o.price_regulation,
             (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = o.pds_tariff LIMIT 1) AS tariff_label,
             p.name AS product_name, pg.name AS program_name,
             co.qty_vt_mwh, co.qty_nt_mwh, co.source_power_kw,
             CASE WHEN o.planned_consumption_vt_mwh IS NOT NULL OR o.planned_consumption_nt_mwh IS NOT NULL
                  THEN coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0) END AS xm_mwh, co.valid_from, co.valid_to, co.op_valid_to, co.is_binding,
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
      SELECT f.id, f.code, f.year, f.detail, f.raised_at, f.resolved_at, f.resolved_note, u.name AS resolved_by_name
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
    span?.y1
      ? sql`SELECT c.* FROM generate_series(${span.y1}::int, ${span.y2}::int) y, contract_year_calc(${id}::uuid, y) c ORDER BY c.year`
      : Promise.resolve([]),
    sql`
      SELECT e.id, to_jsonb(e.years) AS years, e.price_model, e.requested_value, e.threshold_value, e.state, e.decided_at, e.decided_by_name,
             e.requested_by_name, e.reason
        FROM price_exception_v e WHERE e.contract_id = ${id}`,
  ]);

  return { ...contract, ooms, prices, flag_rows: flags, imports, predecessors: successors, balance, exceptions };
}
