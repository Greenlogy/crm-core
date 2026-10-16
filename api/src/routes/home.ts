// Modul 5, F6 – Domov (obrazovka 30; návrh DB časť 36.2; migrácie 0049, 0050). Úvodná stránka obchodníka a tímu
// Sales_internal: cena pre obchodníka na 3 roky a jej vývoj (nikdy BL / PL), 12-mesačný SPOT priemer, hranica FIX pre
// kalkulačku (manažér s maržou odhad portfólia, ostatní cena pre obchodníka), môj minimálny aditív a percento provízie,
// moje ďalšie kroky, moje ponuky a pridaná hodnota (uložená, 0052); pre manažéra rozpad podľa obchodníkov. Čo kto vidí,
// stráži databáza.

import { Hono } from 'hono';
import type { AppEnv } from '../types';

export const home = new Hono<AppEnv>();

home.get('/home', async (c) => {
  const sql = c.var.sql;
  const [ctx] = await sql<{ org: string | null; today: string; manager: boolean }[]>`
    SELECT coalesce(CASE WHEN crm_default_org() = ANY (crm_user_orgs()) THEN crm_default_org() END, (crm_user_orgs())[1]) AS org,
           crm_today() AS today, crm_deal_manager() AS manager`;
  if (!ctx?.org) return c.json({ error: 'Nemáte pridelenú žiadnu spoločnosť.' }, 403);
  const org = ctx.org;
  const me = c.var.userId;

  const [prices, basis, spot, terms, steps, offers, value] = await Promise.all([
    sql`SELECT delivery_year, trader_price, price_date FROM trader_prices_home(${org}, crm_today(), 3) ORDER BY delivery_year`,
    sql`SELECT delivery_year, basis, basis_eur_mwh, price_date FROM calculator_fix_basis(${org}, crm_today(), 3) ORDER BY delivery_year`,
    sql`SELECT on_date, avg_12m_eur_mwh FROM spot_average_on(${org}, crm_today())`,
    sql`SELECT seller_type, min_additive_eur_mwh, commission_pct FROM my_sales_terms(${org})`,
    // moje ďalšie kroky: po termíne, dnes, zajtra (otvorené obchody, ktorých som vlastník); počet bez kroku
    sql`
      SELECT d.id, d.name, d.next_step, d.next_step_on,
             coalesce(co.name, nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')) AS customer_name,
             CASE WHEN d.next_step_on < crm_today() THEN 'po_termine' WHEN d.next_step_on = crm_today() THEN 'dnes' ELSE 'zajtra' END AS state
        FROM deal d
        LEFT JOIN company co ON co.id = d.company_id
        LEFT JOIN contact p ON p.id = d.person_id
       WHERE d.owner_id = ${me} AND d.closed_at IS NULL AND d.next_step_on <= crm_today() + 1
       ORDER BY d.next_step_on, d.name
       LIMIT 50`,
    // moje ponuky (posledná verzia ponuky mojich otvorených obchodov a akceptované bez zmluvy)
    sql`
      SELECT count(*) FILTER (WHERE o.status = 'caka_na_schvalenie')::int AS waiting_approval,
             count(*) FILTER (WHERE o.status IN ('odoslana', 'otvorena') AND (o.valid_until IS NULL OR o.valid_until >= now()))::int AS sent,
             count(*) FILTER (WHERE o.status = 'otvorena' AND (o.valid_until IS NULL OR o.valid_until >= now()))::int AS opened,
             count(*) FILTER (WHERE o.status IN ('odoslana', 'otvorena') AND (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date = crm_today())::int AS expires_today,
             (SELECT count(*)::int FROM deal x JOIN pipeline_stage s ON s.id = x.stage_id
               WHERE x.owner_id = ${me} AND s.code = 'akceptacia') AS accepted_waiting_contract
        FROM deal d
        JOIN offer o ON o.deal_id = d.id AND o.status <> 'nahradena'
       WHERE d.owner_id = ${me} AND d.closed_at IS NULL`,
    // pridaná hodnota mojich otvorených obchodov a vážená podľa pravdepodobnosti štádia; počet bez kroku
    sql`
      SELECT count(*)::int AS open_deals,
             coalesce(sum(dv.value_eur), 0) AS value_eur,
             coalesce(round(sum(coalesce(dv.value_eur, 0) * coalesce(s.probability, 0)), 2), 0) AS weighted_eur,
             count(*) FILTER (WHERE d.next_step_on IS NULL)::int AS without_step
        FROM deal d
        JOIN pipeline_stage s ON s.id = d.stage_id
        LEFT JOIN deal_value_cache dv ON dv.deal_id = d.id
       WHERE d.owner_id = ${me} AND d.closed_at IS NULL`,
  ]);

  // Pre manažéra (vedenie, obchodný riaditeľ): rozpad podľa obchodníkov z obchodov, ktoré vidí
  const team = ctx.manager
    ? await sql`
        SELECT u.id AS owner_id, u.name AS owner_name,
               count(*) FILTER (WHERE d.closed_at IS NULL)::int AS open_deals,
               coalesce(sum(dv.value_eur) FILTER (WHERE d.closed_at IS NULL), 0) AS value_eur,
               coalesce(round(sum(coalesce(dv.value_eur, 0) * coalesce(s.probability, 0)) FILTER (WHERE d.closed_at IS NULL), 2), 0) AS weighted_eur,
               count(*) FILTER (WHERE s.code = 'vyhrane'
                                  AND d.closed_at >= date_trunc('month', now() AT TIME ZONE 'Europe/Bratislava') AT TIME ZONE 'Europe/Bratislava')::int AS won_month,
               coalesce(sum(dv.value_eur) FILTER (WHERE s.code = 'vyhrane'
                                  AND d.closed_at >= date_trunc('month', now() AT TIME ZONE 'Europe/Bratislava') AT TIME ZONE 'Europe/Bratislava'), 0) AS won_month_eur,
               count(*) FILTER (WHERE d.closed_at IS NULL AND (d.next_step_on IS NULL OR d.next_step_on < crm_today()))::int AS attention
          FROM deal d
          JOIN pipeline_stage s ON s.id = d.stage_id
          JOIN app_user u ON u.id = d.owner_id
          LEFT JOIN deal_value_cache dv ON dv.deal_id = d.id
         WHERE d.closed_at IS NULL
            OR d.closed_at >= date_trunc('month', now() AT TIME ZONE 'Europe/Bratislava') AT TIME ZONE 'Europe/Bratislava'
         GROUP BY u.id, u.name
         ORDER BY value_eur DESC, u.name`
    : null;

  // vývoj ceny pre obchodníka po rokoch dlaždíc od 1. 1. 2026 (iba cena pre obchodníka)
  const series = await Promise.all(
    prices.map(async (p) => ({
      delivery_year: p.delivery_year as number,
      points: await sql`SELECT on_date, trader_price FROM trader_price_series(${org}, ${p.delivery_year as number}::smallint, '2026-01-01', crm_today())`,
    })),
  );

  return c.json({
    today: ctx.today,
    org_id: org,
    prices,
    basis,
    series,
    spot: spot[0] ?? null,
    terms: terms[0] ?? null,
    steps,
    offers: offers[0],
    value: value[0],
    team,
  });
});
