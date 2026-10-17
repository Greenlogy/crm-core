// Modul 4 Zmluvy, F1a – Nastavenia → Cenové parametre (obrazovka 29; migrácie 0023, 0024; modul 5 F6: 0047, 0048).
// Otvorí admin alebo používateľ so „schvaľuje ceny“ (obchodný riaditeľ). Pravidlá stráži databáza pre každú rolu:
// kto smie ktorý parameter, „platí od“ iba dnes a neskôr, riadok sa nemení (iba autorov budúci), trhová cena
// sa neprepisuje – oprava je nový záznam toho istého dňa a pôvodný ostane v histórii ako „opravené“.
// F6: ceny dňa načítava Montel (Cron po – pi 7:00 a 13:00); pri každom dni zdroj (Montel / ručne, kto a kedy);
// admin zmaže ručne zadanú cenu dňa s dôvodom (ďalší beh ju načíta z Montelu) a jednorazovo načíta históriu od 1. 1. 2026.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { extractHistory, HISTORY_FROM, historyDays, MontelError, montelGet } from '../montel';
import { BadRequest, Forbidden, readBody, str, type Body } from '../validate';
import { price } from './pricelists-write';

export const pricing = new Hono<AppEnv>();

export const PARAMETER_CODES = [
  'pomer_bl_pct', 'rizikova_prirazka', 'nasa_marza',
  'min_aditiv_obchodnik', 'min_aditiv_manazer', 'min_aditiv_vykup_lz',
  'nakup_energopomoc', 'viwa_aditiv_basic', 'viwa_aditiv_plus', 'viwa_aditiv_pro', 'min_aditiv_vykup',
] as const;

const DAY = /^\d{4}-\d{2}-\d{2}$/;

function day(v: unknown, label: string): string {
  if (typeof v !== 'string' || !DAY.test(v) || Number.isNaN(Date.parse(`${v}T00:00:00Z`))) {
    throw new BadRequest(`${label}: neplatný dátum (RRRR-MM-DD).`);
  }
  return v;
}

function year(v: unknown, label: string): number {
  const n = typeof v === 'number' ? v : typeof v === 'string' ? Number.parseInt(v, 10) : Number.NaN;
  if (!Number.isInteger(n) || n < 2000 || n > 2100) throw new BadRequest(`${label}: rok 2000 až 2100.`);
  return n;
}

function id(v: string): string {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}

/** Spoločnosť: zadaná (musí ju používateľ vidieť), inak predvolená, inak prvá viditeľná. */
async function orgOf(sql: Sql, org: unknown): Promise<string> {
  if (org !== undefined && org !== null && org !== '') {
    if (typeof org !== 'string' || !UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
    const [r] = await sql<{ ok: boolean }[]>`SELECT ${org}::uuid = ANY (crm_user_orgs()) AS ok`;
    if (!r?.ok) throw new Forbidden('K tejto spoločnosti nemáte prístup.');
    return org;
  }
  const [r] = await sql<{ id: string | null }[]>`
    SELECT coalesce(CASE WHEN crm_default_org() = ANY (crm_user_orgs()) THEN crm_default_org() END,
                    (crm_user_orgs())[1]) AS id`;
  if (!r?.id) throw new Forbidden('Nemáte pridelenú žiadnu spoločnosť.');
  return r.id;
}

pricing.use('/pricing/*', async (c, next) => {
  // 0056: Nákup zadáva nákupnú cenu portfólia, preto obrazovku otvorí aj Nákup (ostatné zmeny stráži databáza)
  const [r] = await c.var.sql<{ ok: boolean }[]>`SELECT crm_is_admin() OR crm_approves_prices() OR crm_is_purchase() AS ok`;
  if (!r?.ok) return c.json({ error: 'Cenové parametre môže otvoriť admin, obchodný riaditeľ alebo Nákup.' }, 403);
  await next();
});
pricing.use('/pricing', async (c, next) => {
  const [r] = await c.var.sql<{ ok: boolean }[]>`SELECT crm_is_admin() OR crm_approves_prices() OR crm_is_purchase() AS ok`;
  if (!r?.ok) return c.json({ error: 'Cenové parametre môže otvoriť admin, obchodný riaditeľ alebo Nákup.' }, 403);
  await next();
});

// Celá obrazovka 29: parametre s históriou, ceny dňa (platné a opravené za 60 dní), cena pre obchodníka dnes.
pricing.get('/pricing', async (c) => {
  const sql = c.var.sql;
  const org = await orgOf(sql, c.req.query('org'));
  const [meta] = await sql`
    SELECT crm_today() AS today, crm_is_admin() AS is_admin, crm_approves_prices() AS approves_prices, crm_is_purchase() AS purchase,
           crm_active_user_id() AS user_id`;
  const parameters = await sql`
    SELECT p.id, p.code, p.delivery_year, p.valid_from, p.value, p.note, p.created_at, p.updated_at,
           p.changed_by, u.name AS changed_by_name,
           p.valid_from > crm_today() AS is_future,
           p.valid_from > crm_today() AND p.changed_by = crm_active_user_id() AS can_edit
      FROM price_parameter p
      LEFT JOIN app_user u ON u.id = p.changed_by
     WHERE p.org_id = ${org}
     ORDER BY p.code, p.delivery_year NULLS FIRST, p.valid_from DESC`;
  const today = await sql`
    SELECT t.id, t.delivery_year, t.on_date, t.bl_eur_mwh, t.pl_eur_mwh, t.bl_ratio_pct, t.mix_eur_mwh, t.risk_eur_mwh, t.margin_eur_mwh,
           t.trader_price_eur_mwh, t.portfolio_eur_mwh, t.spot_fve_eur_mwh, t.source, h.created_at, h.changed_by_name
      FROM trader_price_today_v t
      JOIN market_price_history_v h ON h.id = t.id
     WHERE t.org_id = ${org}
     ORDER BY t.delivery_year`;
  const history = await sql`
    SELECT h.id, h.on_date, h.delivery_year, h.bl_eur_mwh, h.pl_eur_mwh, h.portfolio_eur_mwh, h.spot_fve_eur_mwh, h.source,
           h.created_at, h.changed_by_name, h.corrected_at, h.corrected_by_name, h.is_corrected, m.removed_reason
      FROM market_price_history_v h
      JOIN market_price_daily m ON m.id = h.id
     WHERE h.org_id = ${org} AND h.on_date >= crm_today() - 60
     ORDER BY h.on_date DESC, h.delivery_year, h.created_at DESC`;
  // posledný beh cien z Montelu a 12-mesačný priemer SPOT (denník behov vidí admin a Nákup)
  const [montel] = await sql`
    SELECT j.started_at, j.result, jsonb_array_length(j.errors) AS errors
      FROM job_run j WHERE j.job = 'ceny' ORDER BY j.started_at DESC LIMIT 1`;
  const [spot] = await sql`
    SELECT on_date, avg_12m_eur_mwh FROM spot_average_daily WHERE org_id = ${org} ORDER BY on_date DESC LIMIT 1`;
  // nákupná cena portfólia po rokoch dodávky: dni zmeny, platná dnes (0056)
  const portfolio = await sql`SELECT * FROM market_price_portfolio_history(${org})`;
  return c.json({ org_id: org, ...meta, parameters, today, history, portfolio, montel: montel ?? null, spot: spot ?? null });
});

// Nová hodnota parametra s „platí od“ (dnes a neskôr; kto smie ktorý parameter, stráži databáza)
pricing.post('/pricing/parameters', async (c) => {
  const b = await readBody(c.req);
  const sql = c.var.sql;
  const org = await orgOf(sql, b.org_id);
  const code = b.code;
  if (typeof code !== 'string' || !(PARAMETER_CODES as readonly string[]).includes(code)) {
    throw new BadRequest('Neznámy cenový parameter.');
  }
  const deliveryYear = code === 'nakup_energopomoc' ? year(b.delivery_year, 'Rok dodávky') : null;
  const validFrom = day(b.valid_from, 'Platí od');
  const value = price(b.value, 'Hodnota');
  if (value === null) throw new BadRequest('Chýba: Hodnota.');
  const note = str(b, 'note', 'Poznámka', { max: 300, optional: true }) || null;
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO price_parameter (org_id, code, delivery_year, valid_from, value, note)
    VALUES (${org}, ${code}, ${deliveryYear}, ${validFrom}, ${value}, ${note})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Oprava vlastného budúceho parametra (hodnota, dátum, poznámka) – iné riadky databáza odmietne
pricing.patch('/pricing/parameters/:id', async (c) => {
  const pid = id(c.req.param('id'));
  const b: Body = await readBody(c.req);
  const value = 'value' in b ? price(b.value, 'Hodnota') : undefined;
  if (value === null) throw new BadRequest('Chýba: Hodnota.');
  const validFrom = 'valid_from' in b ? day(b.valid_from, 'Platí od') : undefined;
  const note = 'note' in b ? str(b, 'note', 'Poznámka', { max: 300, optional: true }) || null : undefined;
  const rows = await c.var.sql`
    UPDATE price_parameter
       SET value = coalesce(${value ?? null}::numeric, value),
           valid_from = coalesce(${validFrom ?? null}::date, valid_from),
           note = CASE WHEN ${note !== undefined} THEN ${note ?? null} ELSE note END
     WHERE id = ${pid}
    RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Záznam neexistuje.' }, 404);
  return c.json({ ok: true });
});

// Zrušenie vlastnej naplánovanej (budúcej) zmeny parametra
pricing.delete('/pricing/parameters/:id', async (c) => {
  const pid = id(c.req.param('id'));
  const rows = await c.var.sql`DELETE FROM price_parameter WHERE id = ${pid} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Záznam neexistuje.' }, 404);
  return c.json({ ok: true });
});

// Ceny dňa pre rok dodávky (ručne, kým nebude API Cockpitu). Ďalší záznam toho istého dňa a roka je oprava:
// platí najnovší, pôvodný ostane v histórii „opravené“ (databáza, 0024).
pricing.post('/pricing/market-prices', async (c) => {
  const b = await readBody(c.req);
  const sql = c.var.sql;
  const org = await orgOf(sql, b.org_id);
  const deliveryYear = year(b.delivery_year, 'Rok dodávky');
  const onDate = b.on_date === undefined || b.on_date === null || b.on_date === '' ? null : day(b.on_date, 'Deň');
  const bl = price(b.bl_eur_mwh, 'BL');
  const pl = price(b.pl_eur_mwh, 'PL');
  const spotFve = price(b.spot_fve_eur_mwh, 'Očakávaná cena SPOT pre FVE');
  if ((bl === null) !== (pl === null)) throw new BadRequest('Zadajte BL aj PL (alebo ani jedno).');
  if ([bl, pl, spotFve].every((v) => v === null)) throw new BadRequest('Zadajte aspoň jednu cenu.');
  // 0056: nákupná cena portfólia sa tu nemení – prevezme sa z platného záznamu dňa (zadáva ju admin a Nákup samostatne)
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh)
    SELECT ${org}, d.on_date, ${deliveryYear}, ${bl}, ${pl},
           (SELECT m.portfolio_eur_mwh FROM market_price_daily m
             WHERE m.org_id = ${org} AND m.on_date = d.on_date AND m.delivery_year = ${deliveryYear} AND m.corrected_at IS NULL),
           ${spotFve}
      FROM (SELECT coalesce(${onDate}::date, crm_today()) AS on_date) d
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Nákupná cena portfólia pre rok dodávky „platí od“ dňa – dnes alebo spätne od 1. 1. 2026 (iba admin a Nákup, 0056).
// Platí po ďalší deň s vlastnou cenou; marža sa prepočíta sama, snímkam zmlúv sa doplní iba chýbajúca cena.
pricing.post('/pricing/portfolio', async (c) => {
  const b = await readBody(c.req);
  const sql = c.var.sql;
  const org = await orgOf(sql, b.org_id);
  const onDate = day(b.on_date, 'Platí od');
  const deliveryYear = year(b.delivery_year, 'Rok dodávky');
  const value = price(b.value, 'Nákupná cena portfólia');
  if (value === null) throw new BadRequest('Zadajte nákupnú cenu portfólia.');
  const [r] = await sql<{ r: { zmena: boolean; zmluvy_doplnene?: number; plati_do?: string | null } }[]>`
    SELECT market_price_portfolio_set(${org}, ${onDate}::date, ${deliveryYear}, ${value}) AS r`;
  return c.json(r.r);
});

// Zmazanie ručne zadanej ceny dňa s dôvodom (iba admin, 0048): riadok ostane v histórii ako zmazaný; ďalší beh ju načíta z Montelu
pricing.post('/pricing/market-prices/:id/remove', async (c) => {
  const pid = id(c.req.param('id'));
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 500 })!;
  await c.var.sql`SELECT market_price_manual_remove(${pid}, ${reason})`;
  return c.json({ ok: true });
});

// História cien z Montelu od 1. 1. 2026 (iba admin, 0047): settlement ročných produktov po dňoch; dni s cenou sa nemenia
pricing.post('/pricing/market-history', async (c) => {
  const sql = c.var.sql;
  const [r] = await sql<{ ok: boolean; today: string }[]>`SELECT crm_is_admin() AS ok, crm_today() AS today`;
  if (!r?.ok) throw new Forbidden('Históriu cien načítava admin.');
  let json: unknown;
  try {
    json = await montelGet(c.env, '/forwards/ohlc/history', historyDays(r.today));
  } catch (err) {
    if (err instanceof MontelError) return c.json({ error: `Montel neodpovedá (${err.kod}). Skúste neskôr.` }, 502);
    throw err;
  }
  const days = extractHistory(json, HISTORY_FROM, r.today);
  if (days.length === 0) return c.json({ error: 'Montel nevrátil žiadne ceny ročných produktov.' }, 502);
  const [res] = await sql<{ r: { dni: number; riadky: number } }[]>`SELECT market_price_history_import(${sql.json(days)}) AS r`;
  return c.json({ ...res.r, montel_dni: days.length });
});
