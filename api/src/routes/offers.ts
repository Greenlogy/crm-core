// Modul 5, F2 – ponuky (obrazovky 34 editor, 33 sekcia Ponuky; návrh DB časti 1.5–1.8, 19–21, migrácie 0036–0038).
// Stav, číslo, snímku hraníc, výpočet pridanej hodnoty, výnimky a akceptáciu stráži databáza (funkcie offer_*,
// approval_request_*); API skladá dotazy a hlášky. Hranicu z odhadu portfólia a maržu firmy databáza vráti iba
// tomu, kto ich smie vidieť (crm_sees_portfolio, crm_can_see_margin). Položky výnimky aplikácia číta iba funkciou.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, type Body, bool, oneOf, readBody, str } from '../validate';

export const offers = new Hono<AppEnv>();

const DATE = /^\d{4}-\d{2}-\d{2}$/;
const PRICE_KINDS = ['fix', 'spot', 'kombinacia', 'cennik', 'viwa'] as const;
const MODELS = ['fix', 'spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct'] as const;

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}
function day(b: Body, key: string, label: string): string | null | undefined {
  if (!(key in b)) return undefined;
  const v = b[key];
  if (v === null || v === '') return null;
  if (typeof v !== 'string' || !DATE.test(v)) throw new BadRequest(`${label}: neplatný dátum.`);
  return v;
}
function decimal(v: unknown, label: string, places: number, min = -1e9): number | null {
  if (v === null || v === undefined || v === '') return null;
  const n = typeof v === 'number' ? v : Number(String(v).replace(/\s/g, '').replace(',', '.'));
  if (!Number.isFinite(n) || n < min || Math.abs(n) > 1e9) throw new BadRequest(`${label}: neplatné číslo.`);
  const f = 10 ** places;
  return Math.round(n * f) / f;
}
function num(b: Body, key: string, label: string, places: number, min = 0): number | null | undefined {
  return key in b ? decimal(b[key], label, places, min) : undefined;
}
function instant(b: Body, key: string, label: string): string {
  const v = b[key];
  if (typeof v !== 'string' || Number.isNaN(Date.parse(v))) throw new BadRequest(`${label}: neplatný čas.`);
  return new Date(v).toISOString();
}

/** Ponuka (iba ak používateľ vidí obchod – RLS) s obchodom a právom upravovať. */
async function offerHead(sql: Sql, offerId: string) {
  const [o] = await sql`
    SELECT o.id, o.deal_id, o.number, o.version, offer_display_number(o) AS display_number, o.status,
           offer_state(o) AS state, o.kind, o.language, o.household, o.contact_id, o.priced_on, o.seller_type,
           o.valid_until, o.valid_shortened, o.sent_at, o.sent_channel, o.sent_note, su.name AS sent_by_name,
           o.rejected_at, o.rejected_note, o.replaced_by_id, o.created_at, cu.name AS created_by_name,
           d.name AS deal_name, d.owner_id, ou.name AS owner_name, d.company_id, d.person_id,
           coalesce(c.name, nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')) AS customer_name,
           st.code AS stage_code, st.name AS stage_name, d.closed_at,
           crm_deal_editable(d.company_id, d.person_id, d.owner_id) AS can_edit,
           crm_can_see_margin() AS see_margin, crm_sees_portfolio() AS see_portfolio,
           o.penalty_eur_mwh, o.pdf_key IS NOT NULL AS has_pdf, o.link_created_at, lu.name AS link_created_by_name,
           o.blocked_by_offer_id, (d.owner_id = crm_active_user_id() OR crm_is_admin()) AS can_manage_link, crm_is_admin() AS is_admin,
           (SELECT jsonb_build_object('id', t.id, 'version', t.version, 'status', t.status, 'penalty', t.defaults->'zmluvna_pokuta')
              FROM offer_template_version t
             WHERE t.org_id = o.org_id AND t.kind = o.kind AND t.language = o.language
               AND (t.id = o.template_version_id OR (o.template_version_id IS NULL AND t.status IN ('platna', 'navrh')))
             ORDER BY (t.id = o.template_version_id) DESC, (t.status = 'platna') DESC LIMIT 1) AS template,
           user_commission_pct(d.owner_id) AS commission_pct
      FROM offer o
      JOIN deal d ON d.id = o.deal_id
      JOIN pipeline_stage st ON st.id = d.stage_id
      LEFT JOIN company c ON c.id = d.company_id
      LEFT JOIN contact p ON p.id = d.person_id
      LEFT JOIN app_user ou ON ou.id = d.owner_id
      LEFT JOIN app_user su ON su.id = o.sent_by
      LEFT JOIN app_user cu ON cu.id = o.created_by
      LEFT JOIN app_user lu ON lu.id = o.link_created_by
     WHERE o.id = ${offerId}`;
  return o;
}

// Ponuky obchodu (sekcia Ponuky na karte obchodu): verzie, stav, platnosť, varianty a súhrn hlavného variantu
offers.get('/deals/:id/offers', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const items = await sql`
    SELECT o.id, o.number, o.version, offer_display_number(o) AS display_number, o.status, offer_state(o) AS state,
           o.language, o.valid_until, o.sent_at, o.created_at,
           (SELECT count(*)::int FROM offer_variant v WHERE v.offer_id = o.id) AS variants
      FROM offer o
     WHERE o.deal_id = ${dealId}
     ORDER BY o.version DESC`;
  // Hodnota obchodu (F6, deal_value 0049): akceptovaný variant, inak hlavný variant poslednej odoslanej ponuky; bez odoslanej
  // ponuky na karte hlavný variant poslednej verzie (nie nahradenej), aby obchodník videl PH rozpracovanej ponuky
  const [main] = await sql`
    SELECT v.id, v.name, v.sort_order, o.id AS offer_id, offer_display_number(o) AS display_number,
           d.accepted_variant_id = v.id AS accepted, (dv.variant_id = v.id) AS in_totals
      FROM deal d
      LEFT JOIN LATERAL deal_value(d.id) dv ON true
      JOIN offer o ON o.deal_id = d.id
      JOIN offer_variant v ON v.offer_id = o.id
     WHERE d.id = ${dealId}
       AND (v.id = dv.variant_id
            OR (dv.variant_id IS NULL AND o.status <> 'nahradena' AND v.id = offer_main_variant(o.id)))
     ORDER BY (v.id = dv.variant_id) DESC, o.version DESC
     LIMIT 1`;
  const summary = main ? await sql`SELECT * FROM offer_variant_summary(${main.id})` : [];
  return c.json({ items, main: main ? { ...main, summary } : null });
});

offers.post('/deals/:id/offers', async (c) => {
  const dealId = id(c.req.param('id'));
  const [r] = await c.var.sql<{ id: string }[]>`SELECT offer_create(${dealId}) AS id`;
  return c.json({ id: r.id }, 201);
});

// Editor ponuky: hlavička, varianty s cenami, výpočet (hodnoty a súhrn), kontrola, žiadosti, OOM a produkty
offers.get('/offers/:id', async (c) => {
  const offerId = id(c.req.param('id'));
  const sql = c.var.sql;
  const head = await offerHead(sql, offerId);
  if (!head) return c.json({ error: 'Ponuka neexistuje alebo ju nevidíte.' }, 404);
  const [variants, items, ooms, contacts, approvals, check, versions] = await Promise.all([
    sql`SELECT v.*, v.id = offer_main_variant(v.offer_id) AS main, (SELECT coalesce(jsonb_agg(m.year ORDER BY m.year), '[]') FROM
                       (SELECT DISTINCT year FROM offer_variant_months(v)) m) AS years
          FROM offer_variant v WHERE v.offer_id = ${offerId} ORDER BY v.sort_order`,
    sql`SELECT i.id, i.variant_id, i.oom_id, i.year, i.slot, i.product_id, p.name AS product_name, i.price_model,
               i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
          FROM offer_item i JOIN offer_variant v ON v.id = i.variant_id JOIN product p ON p.id = i.product_id
         WHERE v.offer_id = ${offerId}`,
    sql`SELECT o.id, o.eic, o.voltage_level, oom_voltage_group(o.voltage_level) AS voltage_group, o.pds_tariff,
               x.planned_vt_mwh, x.planned_nt_mwh, x.planned_feed_in_mwh, x.source_power_kw
          FROM deal_oom x JOIN oom o ON o.id = x.oom_id
         WHERE x.deal_id = ${head.deal_id}
         ORDER BY oom_voltage_group(o.voltage_level), o.eic`,
    sql`SELECT x.contact_id AS id, nullif(btrim(concat_ws(' ', k.title, k.first_name, k.last_name)), '') AS name, k.position
          FROM deal_contact x JOIN contact k ON k.id = x.contact_id
         WHERE x.deal_id = ${head.deal_id}
         ORDER BY x.is_primary DESC, k.last_name`,
    sql`SELECT a.id, a.kind, a.status, a.reason, a.decision_note, a.valid_until, a.requested_valid_until, a.created_at,
               a.decided_at, du.name AS decided_by_name, ru.name AS requested_by_name
          FROM approval_request a
          LEFT JOIN app_user du ON du.id = a.decided_by
          LEFT JOIN app_user ru ON ru.id = a.requested_by
         WHERE a.offer_id = ${offerId} OR (a.kind = 'rizikovy_zakaznik' AND a.deal_id = ${head.deal_id})
         ORDER BY a.created_at DESC`,
    sql`SELECT offer_check(${offerId}) AS c`,
    sql`SELECT o.id, o.version, offer_display_number(o) AS display_number, o.status, offer_state(o) AS state
          FROM offer o WHERE o.deal_id = ${head.deal_id} ORDER BY o.version`,
  ]);
  const calc = await Promise.all(
    variants.map(async (v) => ({
      variant_id: v.id as string,
      values: await sql`SELECT * FROM offer_variant_values(${v.id as string})`,
      summary: await sql`SELECT * FROM offer_variant_summary(${v.id as string})`,
    })),
  );
  const products = await sql`
    SELECT p.id, p.code, p.name, p.category, to_jsonb(p.price_models) AS price_models
      FROM product p
     WHERE p.status = 'predava_sa'
       AND p.category::text = ANY (CASE ${head.kind}::text WHEN 'vykup' THEN ARRAY['vykup_firma']
                                                           WHEN 'viwa' THEN ARRAY['viwa']
                                                           ELSE ARRAY['dodavka_firma', 'velkoobchod'] END)
     ORDER BY p.name`;
  return c.json({ ...head, variants, items, ooms, contacts, approvals, check: check[0]?.c ?? null, calc, products, versions });
});

// Hlavička: jazyk a kontaktná osoba (koncept; zmena pripravenej ju vráti do konceptu – databáza)
offers.patch('/offers/:id', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const language = oneOf(b, 'language', 'Jazyk', ['sk', 'en'] as const);
  const contact = 'contact_id' in b ? (b.contact_id === null || b.contact_id === '' ? null : id(String(b.contact_id))) : undefined;
  // zmluvná pokuta: prázdna = zo šablóny; nižšia ako v šablóne potrebuje schválenie (0040)
  const penalty = 'penalty_eur_mwh' in b ? decimal(b.penalty_eur_mwh, 'Zmluvná pokuta', 2, 0) : undefined;
  const rows = await c.var.sql`
    UPDATE offer SET language = coalesce(${language ?? null}::offer_language, language),
                     contact_id = CASE WHEN ${contact !== undefined} THEN ${contact ?? null}::uuid ELSE contact_id END,
                     penalty_eur_mwh = CASE WHEN ${penalty !== undefined} THEN ${penalty ?? null}::numeric ELSE penalty_eur_mwh END
     WHERE id = ${offerId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Ponuku nemôžete upravovať.' }, 403);
  return c.json({ ok: true });
});

offers.delete('/offers/:id', async (c) => {
  const offerId = id(c.req.param('id'));
  const rows = await c.var.sql`DELETE FROM offer WHERE id = ${offerId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Ponuku nemôžete zmazať.' }, 403);
  return c.json({ ok: true });
});

// Varianty
offers.post('/offers/:id/variants', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const kind = oneOf(b, 'price_kind', 'Typ ceny', PRICE_KINDS);
  if (!kind) throw new BadRequest('Vyberte typ ceny.');
  const copy = 'copy_from' in b && b.copy_from ? id(String(b.copy_from)) : null;
  const [r] = await c.var.sql<{ id: string }[]>`SELECT offer_variant_add(${offerId}, ${kind}, ${copy}) AS id`;
  return c.json({ id: r.id }, 201);
});

// Hlavný variant ponuky pre prehľady (F6, 0049): označí obchodník; ponuka sa nevracia do konceptu
offers.post('/offer-variants/:id/main', async (c) => {
  await c.var.sql`SELECT offer_variant_set_main(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

offers.patch('/offer-variants/:id', async (c) => {
  const variantId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov variantu', { max: 120, optional: true });
  const kind = oneOf(b, 'price_kind', 'Typ ceny', PRICE_KINDS);
  const from = day(b, 'supply_from', 'Dodávka od');
  const to = day(b, 'supply_to', 'Dodávka do');
  const pkg = oneOf(b, 'viwa_package', 'Balík VIWA', ['basic', 'plus', 'pro'] as const);
  const flex = num(b, 'flexibility_pct', 'Flexibilita', 2);
  const vol = num(b, 'planned_volume_mwh', 'Plánovaný objem', 3);
  const due = num(b, 'invoice_due_days', 'Splatnosť faktúry', 0);
  const advKind = oneOf(b, 'advance_kind', 'Preddavky', ['mesacne', 'financna_zabezpeka'] as const);
  const advPct = num(b, 'advance_pct', 'Preddavok %', 2);
  const advDay = num(b, 'advance_due_day', 'Splatnosť preddavku', 0);
  const neg = bool(b, 'negative_price_compensation', 'Kompenzácia záporných cien');
  const sql = c.var.sql;
  const rows = await sql`
    UPDATE offer_variant SET
      name = coalesce(${name ?? null}, name),
      price_kind = coalesce(${kind ?? null}::offer_price_kind, price_kind),
      supply_from = coalesce(${from ?? null}::date, supply_from),
      supply_to = CASE WHEN ${to !== undefined} THEN ${to ?? null}::date ELSE supply_to END,
      viwa_package = CASE WHEN ${pkg !== undefined} THEN ${pkg ?? null}::text ELSE viwa_package END,
      flexibility_pct = CASE WHEN ${flex !== undefined} THEN ${flex ?? null}::numeric ELSE flexibility_pct END,
      planned_volume_mwh = CASE WHEN ${vol !== undefined} THEN ${vol ?? null}::numeric ELSE planned_volume_mwh END,
      invoice_due_days = coalesce(${due ?? null}::smallint, invoice_due_days),
      advance_kind = coalesce(${advKind ?? null}, advance_kind),
      advance_pct = CASE WHEN ${advPct !== undefined} THEN ${advPct ?? null}::numeric ELSE advance_pct END,
      advance_due_day = CASE WHEN ${advDay !== undefined} THEN ${advDay ?? null}::smallint ELSE advance_due_day END,
      negative_price_compensation = coalesce(${neg ?? null}::boolean, negative_price_compensation)
     WHERE id = ${variantId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Variant nemôžete upravovať.' }, 403);
  return c.json({ ok: true });
});

offers.delete('/offer-variants/:id', async (c) => {
  const variantId = id(c.req.param('id'));
  const sql = c.var.sql;
  const [v] = await sql<{ offer_id: string; n: number }[]>`
    SELECT v.offer_id, (SELECT count(*)::int FROM offer_variant x WHERE x.offer_id = v.offer_id) AS n
      FROM offer_variant v WHERE v.id = ${variantId}`;
  if (!v) return c.json({ error: 'Variant neexistuje.' }, 404);
  if (v.n <= 1) throw new BadRequest('Ponuka musí mať aspoň jeden variant.');
  const rows = await sql`DELETE FROM offer_variant WHERE id = ${variantId} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Variant nemôžete zmazať.' }, 403);
  return c.json({ ok: true });
});

// Ceny komodity pre OOM × rok (editor): [{oom_id, year|null, product_id, price_model, price_vt, price_nt, additive,
// additive_pct}]. Prázdna cena = položka sa zmaže. Ceny z cenníka dopĺňa CRM (databáza ich nedovolí meniť).
offers.put('/offer-variants/:id/prices', async (c) => {
  const variantId = id(c.req.param('id'));
  const b = await readBody(c.req);
  if (!Array.isArray(b.items) || b.items.length > 2000) throw new BadRequest('Chýbajú ceny.');
  const sql = c.var.sql;
  for (const raw of b.items as Body[]) {
    const oom = id(String(raw.oom_id ?? ''));
    const year = raw.year === null || raw.year === undefined || raw.year === '' ? null : Number(raw.year);
    if (year !== null && (!Number.isInteger(year) || year < 2020 || year > 2100)) throw new BadRequest('Neplatný rok.');
    const model = oneOf(raw, 'price_model', 'Cenový model', MODELS);
    if (!model) throw new BadRequest('Chýba cenový model.');
    const vt = decimal(raw.price_vt, 'Cena VT', 4);
    const nt = decimal(raw.price_nt, 'Cena NT', 4);
    const ad = decimal(raw.additive, 'Aditív', 4);
    const pct = decimal(raw.additive_pct, 'Aditív %', 4);
    const empty = model === 'fix' ? vt === null : model === 'spot_minus_pct' ? pct === null : ad === null;
    if (empty) {
      await sql`DELETE FROM offer_item WHERE variant_id = ${variantId} AND oom_id = ${oom} AND slot = 'komodita'
                   AND year IS NOT DISTINCT FROM ${year}::smallint`;
      continue;
    }
    const product = id(String(raw.product_id ?? ''));
    await sql`
      INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model,
                              price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct)
      VALUES (${variantId}, ${oom}, ${year}, 'komodita', ${product}, ${model},
              ${model === 'fix' ? vt : null}, ${model === 'fix' ? nt : null},
              ${model === 'spot_plus_eur' || model === 'spot_minus_eur' ? ad : null}, ${model === 'spot_minus_pct' ? pct : null})
      ON CONFLICT ON CONSTRAINT offer_item_key DO UPDATE
        SET product_id = EXCLUDED.product_id, price_model = EXCLUDED.price_model,
            price_vt_eur_mwh = EXCLUDED.price_vt_eur_mwh, price_nt_eur_mwh = EXCLUDED.price_nt_eur_mwh,
            additive_eur_mwh = EXCLUDED.additive_eur_mwh, additive_pct = EXCLUDED.additive_pct
        WHERE (offer_item.product_id, offer_item.price_model, offer_item.price_vt_eur_mwh, offer_item.price_nt_eur_mwh,
               offer_item.additive_eur_mwh, offer_item.additive_pct)
              IS DISTINCT FROM (EXCLUDED.product_id, EXCLUDED.price_model, EXCLUDED.price_vt_eur_mwh, EXCLUDED.price_nt_eur_mwh,
                                EXCLUDED.additive_eur_mwh, EXCLUDED.additive_pct)`;
  }
  return c.json({ ok: true });
});

// Akcie ponuky (všetko kontroluje databáza)
offers.post('/offers/:id/reprice', async (c) => {
  await c.var.sql`SELECT offer_reprice(${id(c.req.param('id'))})`;
  return c.json({ ok: true });
});

// Pripraviť na odoslanie: bez potreby schválenia → Pripravená, inak žiadosť o schválenie (dôvod povinný)
offers.post('/offers/:id/prepare', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 2000, optional: true }) || null;
  const [r] = await c.var.sql<{ status: string }[]>`SELECT approval_request_offer(${offerId}, ${reason}) AS status`;
  return c.json({ status: r.status });
});

// Označenie ako odoslanej je od F3 súčasťou odoslania s PDF a odkazom (offers-pdf.ts: POST /offers/:id/send)

offers.post('/offers/:id/reject', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const note = str(b, 'note', 'Poznámka', { max: 1000, optional: true }) || null;
  await c.var.sql`SELECT offer_reject(${offerId}, ${note})`;
  return c.json({ ok: true });
});

offers.post('/offers/:id/new-version', async (c) => {
  const [r] = await c.var.sql<{ id: string }[]>`SELECT offer_new_version(${id(c.req.param('id'))}) AS id`;
  return c.json({ id: r.id }, 201);
});

offers.post('/offers/:id/shorten', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  await c.var.sql`SELECT offer_shorten(${offerId}, ${instant(b, 'until', 'Platnosť do')})`;
  return c.json({ ok: true });
});

offers.post('/offers/:id/extend', async (c) => {
  const offerId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 2000 })!;
  const [r] = await c.var.sql<{ id: string }[]>`
    SELECT approval_request_extend(${offerId}, ${instant(b, 'until', 'Platnosť do')}, ${reason}) AS id`;
  return c.json({ id: r.id }, 201);
});

// Výnimky z ponúk pre obrazovku 28 (iba čítanie; rozhoduje sa v Schvaľovaní). Hranicu z odhadu portfólia
// databáza vráti iba s právom (approval_price_detail).
offers.get('/offer-exceptions', async (c) => {
  const items = await c.var.sql`
    SELECT a.id AS approval_id, a.status, a.valid_until, a.created_at, a.decided_at, ru.name AS requested_by_name,
           d.id AS deal_id, d.name AS deal_name, o.id AS offer_id, offer_display_number(o) AS offer_number,
           coalesce(c.name, nullif(btrim(concat_ws(' ', p.first_name, p.last_name)), '')) AS customer_name,
           d.company_id, d.person_id,
           x.variant, x.year, x.price_model, x.voltage_group, x.requested_value, x.threshold_value, x.approved_value, x.volume_mwh
      FROM approval_request a
      JOIN offer o ON o.id = a.offer_id
      JOIN deal d ON d.id = a.deal_id
      LEFT JOIN company c ON c.id = d.company_id
      LEFT JOIN contact p ON p.id = d.person_id
      LEFT JOIN app_user ru ON ru.id = a.requested_by
      CROSS JOIN LATERAL approval_price_detail(a.id) x
     WHERE a.kind = 'vynimka_ceny'
     ORDER BY a.status = 'caka' DESC, a.created_at DESC, x.year
     LIMIT 500`;
  return c.json({ items });
});

// Percento provízie obchodníka s históriou (odpoveď 19.6/4): mení admin a obchodný riaditeľ („schvaľuje ceny“),
// platí od dnes alebo neskôr, riadok sa nemení, budúci sa dá zmazať (databáza: user_commission_rate_guard, RLS).
offers.get('/commission-rates/:userId', async (c) => {
  const userId = id(c.req.param('userId'));
  const sql = c.var.sql;
  const [items, [cur]] = await Promise.all([
    sql`SELECT r.id, r.valid_from, r.pct, u.name AS changed_by_name, r.created_at, r.valid_from > crm_today() AS future
          FROM user_commission_rate r LEFT JOIN app_user u ON u.id = r.changed_by
         WHERE r.user_id = ${userId} ORDER BY r.valid_from DESC`,
    sql`SELECT user_commission_pct(${userId}) AS pct, crm_is_admin() OR crm_approves_prices() AS can_edit, crm_today() AS today`,
  ]);
  return c.json({ items, current: cur.pct, can_edit: cur.can_edit, today: cur.today });
});

offers.post('/commission-rates', async (c) => {
  const b = await readBody(c.req);
  const userId = id(String(b.user_id ?? ''));
  const from = day(b, 'valid_from', 'Platí od');
  if (!from) throw new BadRequest('Zadajte dátum „platí od“.');
  const pct = decimal(b.pct, 'Percento', 2, 0);
  if (pct === null || pct > 100) throw new BadRequest('Percento musí byť 0 až 100.');
  const [r] = await c.var.sql<{ id: string }[]>`
    INSERT INTO user_commission_rate (user_id, valid_from, pct) VALUES (${userId}, ${from}, ${pct}) RETURNING id`;
  return c.json({ id: r.id }, 201);
});

offers.delete('/commission-rates/:id', async (c) => {
  const rows = await c.var.sql`DELETE FROM user_commission_rate WHERE id = ${id(c.req.param('id'))} RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Záznam neexistuje alebo ho nemôžete zmazať.' }, 403);
  return c.json({ ok: true });
});
