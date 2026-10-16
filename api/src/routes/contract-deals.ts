// Modul 5, F5 – zmluvy k obchodom (návrh DB časti 2, 32, 33; migrácia 0045): podklady pre zmluvu (obrazovka 38),
// prehľad Zmluvy k obchodom (40: čaká na zmluvu, nespárované, cena iná ako v ponuke) a ručné rozhodnutia pri zmluve
// (vybrať obchod, bez obchodu, zrušiť spárovanie). Pravidlá a práva stráži databáza.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, readBody, str } from '../validate';

export const contractDeals = new Hono<AppEnv>();

function id(v: string | undefined): string {
  if (!v || !UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
}

const LISTS = ['fakturacne_obdobie', 'typ_vykupnej_zmluvy', 'model_vypoctu_vykupu', 'vztah_k_nehnutelnosti', 'predchadzajuci_dodavatel'];

// Podklady pre zmluvu: údaje v poradí formulára Office portálu + možnosti číselníkov
contractDeals.get('/deals/:id/contract-input', async (c) => {
  const dealId = id(c.req.param('id'));
  const sql = c.var.sql;
  const [r] = await sql<{ v: Record<string, unknown> | null }[]>`SELECT deal_contract_input_view(${dealId}) AS v`;
  if (!r?.v) return c.json({ error: 'Obchod neexistuje alebo ho nevidíte.' }, 404);
  const lookups = await sql<{ list_code: string; code: string; label: string }[]>`
    SELECT v.list_code, v.code, v.label FROM lookup_value v
     WHERE v.list_code IN ${sql(LISTS)} AND v.hidden_at IS NULL
       AND (v.org_id IS NULL OR v.org_id = (SELECT org_id FROM deal WHERE id = ${dealId}))
     ORDER BY v.list_code, v.sort_order, v.label`;
  const options: Record<string, { code: string; label: string }[]> = {};
  for (const l of lookups) (options[l.list_code] ??= []).push({ code: l.code, label: l.label });
  return c.json({ ...r.v, options });
});

// Uloženie podkladov naraz k firme, zástupcovi, OOM a obchodu (kľúč, ktorý v tele nie je, sa nemení)
contractDeals.put('/deals/:id/contract-input', async (c) => {
  const dealId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const p: Record<string, unknown> = {};
  for (const k of ['company', 'representative', 'contract'] as const) {
    if (b[k] !== undefined) {
      if (typeof b[k] !== 'object' || b[k] === null || Array.isArray(b[k])) throw new BadRequest('Neplatné údaje.');
      p[k] = b[k];
    }
  }
  if (b.ooms !== undefined) {
    if (!Array.isArray(b.ooms) || b.ooms.length > 200) throw new BadRequest('Neplatné údaje OOM.');
    p.ooms = b.ooms;
  }
  await c.var.sql`SELECT deal_contract_input_save(${dealId}, ${c.var.sql.json(p as never)})`;
  return c.json({ ok: true });
});

// Zmluvy k obchodom (obrazovka 40)
contractDeals.get('/contract-matching', async (c) => {
  const sql = c.var.sql;
  const [waiting, unmatched, prices] = await Promise.all([
    // Čaká na zmluvu: obchody v Akceptácii, očakávané zmluvy (dodávka firme: NN a VN zvlášť), spárované, lehota 14 dní
    sql`
      SELECT d.id, d.name, d.company_id, d.person_id,
             coalesce(co.name, concat_ws(' ', pe.first_name, pe.last_name)) AS customer,
             a.accepted_at, a.accepted_at + interval '14 days' AS due,
             p.kind,
             (SELECT CASE WHEN p.kind = 'b2b_dodavka' THEN count(DISTINCT oom_voltage_group(m.voltage_level)) ELSE 1 END
                FROM deal_oom x JOIN oom m ON m.id = x.oom_id WHERE x.deal_id = d.id)::int AS expected,
             (SELECT coalesce(jsonb_agg(DISTINCT upper(oom_voltage_group(m.voltage_level))), '[]')
                FROM deal_oom x JOIN oom m ON m.id = x.oom_id WHERE x.deal_id = d.id AND p.kind = 'b2b_dodavka') AS groups,
             (SELECT count(*) FROM contract k WHERE k.deal_id = d.id AND k.deal_match IN ('auto', 'rucne'))::int AS matched,
             (SELECT coalesce(jsonb_agg(DISTINCT m.eic), '[]') FROM offer_item i JOIN oom m ON m.id = i.oom_id
               WHERE i.variant_id = d.accepted_variant_id
                 AND NOT EXISTS (SELECT 1 FROM contract_oom ko JOIN contract k ON k.id = ko.contract_id
                                  WHERE k.deal_id = d.id AND ko.oom_id = i.oom_id)) AS missing_eic,
             deal_contract_input_missing(d.id) AS completeness,
             u.name AS owner_name
        FROM deal d
        JOIN pipeline p ON p.id = d.pipeline_id
        JOIN pipeline_stage s ON s.id = d.stage_id
        JOIN app_user u ON u.id = d.owner_id
        LEFT JOIN company co ON co.id = d.company_id
        LEFT JOIN contact pe ON pe.id = d.person_id
        LEFT JOIN LATERAL (SELECT x.accepted_at FROM offer_acceptance x JOIN offer o ON o.id = x.offer_id
                            WHERE o.deal_id = d.id AND x.revoked_at IS NULL ORDER BY x.accepted_at DESC LIMIT 1) a ON true
       WHERE s.code = 'akceptacia'
       ORDER BY a.accepted_at NULLS LAST, d.name`,
    sql<{ u: unknown }[]>`SELECT contract_unmatched() AS u`,
    // Cena iná ako v ponuke (neuzavreté príznaky zmlúv, ktoré používateľ vidí)
    sql`
      SELECT f.id, f.year, f.detail, f.raised_at, k.id AS contract_id, k.number, k.deal_id, d.name AS deal_name,
             offer_display_number(o) AS offer_number, chr(64 + v.sort_order) AS variant, crm_approves_prices() AS can_resolve
        FROM contract_flag f
        JOIN contract k ON k.id = f.contract_id
        LEFT JOIN deal d ON d.id = k.deal_id
        LEFT JOIN offer_variant v ON v.id = k.offer_variant_id
        LEFT JOIN offer o ON o.id = v.offer_id
       WHERE f.code::text = 'cena_ina_ako_v_ponuke' AND f.resolved_at IS NULL
       ORDER BY f.raised_at DESC`,
  ]);
  return c.json({ waiting, unmatched: unmatched[0].u, prices });
});

// Ručne: vybrať obchod (vlastník zákazníka alebo admin)
contractDeals.post('/contracts/:id/deal', async (c) => {
  const b = await readBody(c.req);
  const dealId = typeof b.deal_id === 'string' && UUID.test(b.deal_id) ? b.deal_id : null;
  if (!dealId) throw new BadRequest('Vyberte obchod.');
  await c.var.sql`SELECT contract_deal_pick(${id(c.req.param('id'))}, ${dealId})`;
  return c.json({ ok: true });
});

// Ručne: Bez obchodu (vlastník zákazníka alebo admin)
contractDeals.post('/contracts/:id/no-deal', async (c) => {
  const b = await readBody(c.req);
  const note = str(b, 'note', 'Poznámka', { max: 500, optional: true }) || null;
  await c.var.sql`SELECT contract_deal_none(${id(c.req.param('id'))}, ${note})`;
  return c.json({ ok: true });
});

// Zrušiť spárovanie (admin, s dôvodom)
contractDeals.post('/contracts/:id/unlink', async (c) => {
  const b = await readBody(c.req);
  const reason = str(b, 'reason', 'Dôvod', { max: 500 })!;
  await c.var.sql`SELECT contract_deal_unlink(${id(c.req.param('id'))}, ${reason})`;
  return c.json({ ok: true });
});
