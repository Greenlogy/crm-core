// Modul Zmluvy, F2 – zoznam (obrazovka 25), karta (26) a údaje CRM zmluvy.
// Údaje z Office portálu mení iba import; aplikácia mení iba poznámku, dôvod uzatvorenia, predošlú a súvisiacu
// zmluvu, balík VIWA (Servis, otázka 20) a obchodníka (iba vedenie / admin). Pravidlá stráži databáza
// (contract_guard, RLS, práva crm_app na stĺpce).

import { Hono } from 'hono';
import type { Context } from 'hono';
import { CONTRACT_CHIPS, CONTRACT_TYPES, contractCard, contractFilters, exportContracts, listContracts, type ContractFilter } from '../queries/contracts';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody } from '../validate';
import { type Cell, xlsx } from '../xlsx';

export const contracts = new Hono<AppEnv>();

const CLOSE_REASONS = ['akvizicia', 'retencia', 'autoprolong', 'prepis', 'nove_oom'] as const;
const VIWA_PACKAGES = ['basic', 'plus', 'pro'] as const;

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

const TYPE_LABEL: Record<string, string> = {
  dodavka_domacnost: 'Dodávka – domácnosť', dodavka_firma_nn: 'Dodávka – firma NN', dodavka_firma_vn: 'Dodávka – firma VN',
  vykup: 'Výkup', viwa: 'VIWA',
};
const STATE_LABEL: Record<string, string> = {
  v_priprave: 'V príprave', podpisana: 'Podpísaná', ucinna: 'Účinná', skoncena: 'Skončená', odmietnuta: 'Odmietnutá', neuspesna: 'Neúspešná',
};

/** Filter zoznamu z adresy; rok bilancie predvolene bežný (otázka 31). */
function filterOf(c: Context<AppEnv>, page: number): ContractFilter {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const chip = c.req.query('stav') ?? '';
  const type = c.req.query('typ') ?? '';
  const owner = c.req.query('obchodnik') ?? '';
  const org = c.req.query('org') ?? '';
  const year = Number(c.req.query('rok') ?? '') || new Date().getUTCFullYear();
  if (!CONTRACT_CHIPS.has(chip)) throw new BadRequest('Neznámy filter stavu.');
  if (type && !(CONTRACT_TYPES as readonly string[]).includes(type)) throw new BadRequest('Neznámy typ zmluvy.');
  if (owner && owner !== 'bez' && !UUID.test(owner)) throw new BadRequest('Neplatný obchodník.');
  if (org && !UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (!Number.isInteger(year) || year < 2000 || year > 2100) throw new BadRequest('Neplatný rok.');
  return { q, chip, type, owner, org, page, year };
}

contracts.get('/contracts', async (c) => {
  const page = Math.max(1, Number(c.req.query('page') ?? '1') || 1);
  return c.json(await listContracts(c.var.sql, filterOf(c, page)));
});

// Export zoznamu podľa filtra (.xlsx): právo „exportovať“ v module Zmluvy, zápis do export_log; marža iba s právom
// (contract_year_calc ju inak vráti prázdnu, stĺpec sa vynechá).
contracts.get('/contracts/export', async (c) => {
  const sql = c.var.sql;
  const [perm] = await sql<{ ok: boolean; margin: boolean }[]>`
    SELECT coalesce((SELECT p.can_export FROM app_user u JOIN team_permission p ON p.team_id = u.team_id AND p.module = 'zmluvy'
                      WHERE u.id = crm_active_user_id()), false) AS ok,
           crm_can_see_margin() AS margin`;
  if (!perm?.ok) throw new Forbidden('Export zmlúv nemáte povolený (Nastavenia → Tímy a práva → Zmluvy → Exportovať).');
  const f = filterOf(c, 1);
  const items = await exportContracts(sql, f);
  const header = ['Číslo zmluvy', 'Typ', 'Stav', 'Príznaky', 'Zákazník', 'Obchodník', 'Účinnosť od', 'Účinnosť do', 'OOM',
    `Objem ${f.year} [MWh]`, `Pridaná hodnota ${f.year} [€]`, ...(perm.margin ? [`Marža firmy ${f.year} [€]`] : []), 'Spoločnosť'];
  const num = (v: unknown): Cell => (v === null || v === undefined ? null : Number(v));
  const rows: Cell[][] = items.map((k) => [
    k.number as string, TYPE_LABEL[k.type as string] ?? (k.type as string), STATE_LABEL[k.state as string] ?? (k.state as string),
    ((k.flags as string[]) ?? []).join(', '), k.customer_name as string, (k.owner_name as string) ?? '',
    (k.valid_from as string) ?? '', (k.effective_to as string) ?? '', num(k.oom_count), num(k.year_volume_mwh), num(k.added_value_eur),
    ...(perm.margin ? [num(k.margin_eur)] : []), k.org_name as string,
  ]);
  await sql`
    INSERT INTO export_log (user_id, module, filter, row_count)
    VALUES (${c.var.userId}, 'zmluvy', ${sql.json({ list: 'zmluvy', q: f.q, stav: f.chip, typ: f.type, obchodnik: f.owner, org: f.org, rok: f.year })}, ${rows.length})`;
  return new Response(xlsx('Zmluvy', header, rows), {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': `attachment; filename="zmluvy-${f.year}.xlsx"`,
      'Cache-Control': 'no-store',
    },
  });
});

contracts.get('/contract-filters', async (c) => c.json(await contractFilters(c.var.sql)));

contracts.get('/contracts/:id', async (c) => {
  const result = await contractCard(c.var.sql, id(c.req.param('id')));
  return result ? c.json(result) : c.json({ error: 'Zmluva neexistuje alebo k nej nemáte prístup.' }, 404);
});

// Údaje CRM zmluvy. Predošlá a súvisiaca zmluva sa zadávajú číslom (prázdne = zrušiť väzbu).
contracts.patch('/contracts/:id', async (c) => {
  const kid = id(c.req.param('id'));
  const b = await readBody(c.req);
  const sql = c.var.sql;
  const sets: ReturnType<typeof sql>[] = [];

  if ('note' in b) {
    if (b.note !== null && typeof b.note !== 'string') throw new BadRequest('Poznámka: očakávaný text.');
    const t = ((b.note as string | null) ?? '').trim();
    if (t.length > 2000) throw new BadRequest('Poznámka: najviac 2 000 znakov.');
    sets.push(sql`note = ${t || null}`);
  }
  if ('close_reason' in b) {
    const v = b.close_reason;
    if (v !== null && v !== '' && !(CLOSE_REASONS as readonly unknown[]).includes(v)) throw new BadRequest('Dôvod uzatvorenia: neplatná hodnota.');
    sets.push(sql`close_reason = ${(v as string) || null}::contract_close_reason`);
  }
  if ('viwa_package' in b) {
    const v = b.viwa_package;
    if (v !== null && v !== '' && !(VIWA_PACKAGES as readonly unknown[]).includes(v)) throw new BadRequest('Balík VIWA: neplatná hodnota.');
    sets.push(sql`viwa_package = ${(v as string) || null}`);
  }
  if ('vykup_min_additive' in b) {
    // minimálny aditív výkupu pri zmluve (otázka 29) – iba výkup, mení Nákup alebo admin (databáza)
    const v = b.vykup_min_additive;
    const n = v === null || v === '' ? null : Number(String(v).replace(',', '.').replace(/\s/g, ''));
    if (n !== null && (!Number.isFinite(n) || n < 0)) throw new BadRequest('Minimálny aditív výkupu: neplatné číslo.');
    sets.push(sql`vykup_min_additive = ${n}::numeric`);
  }
  if ('owner_id' in b) {
    const v = b.owner_id;
    if (v !== null && v !== '' && (typeof v !== 'string' || !UUID.test(v))) throw new BadRequest('Obchodník: neplatný identifikátor.');
    sets.push(sql`owner_id = ${(v as string) || null}::uuid`);
  }
  for (const [key, col, label] of [
    ['previous_number', 'previous_contract_id', 'Predošlá zmluva'],
    ['related_number', 'related_contract_id', 'Súvisiaca zmluva'],
  ] as const) {
    if (!(key in b)) continue;
    const v = b[key];
    if (v !== null && typeof v !== 'string') throw new BadRequest(`${label}: očakávané číslo zmluvy.`);
    const num = ((v as string | null) ?? '').trim();
    let ref: string | null = null;
    if (num) {
      const [r] = await sql<{ id: string }[]>`SELECT id FROM contract WHERE number = ${num}`;
      if (!r) throw new BadRequest(`${label}: zmluva ${num} v CRM nie je (alebo k nej nemáte prístup).`);
      if (r.id === kid) throw new BadRequest(`${label}: nemôže to byť tá istá zmluva.`);
      ref = r.id;
    }
    sets.push(sql`${sql(col)} = ${ref}::uuid`);
  }
  if (sets.length === 0) return c.json({ ok: true });
  const set = sets.reduce((acc, f) => sql`${acc}, ${f}`);
  const rows = await sql`UPDATE contract SET ${set} WHERE id = ${kid} RETURNING id`;
  // RLS: zmluvu, ktorú používateľ nesmie upravovať, UPDATE nenájde
  if (rows.length === 0) return c.json({ error: 'Zmluvu nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});

// Uzavretie príznaku (Na kontrolu, Sprolongované bez novej ceny…) – kto smie zmluvu upraviť (RLS)
contracts.post('/contract-flags/:id/resolve', async (c) => {
  const fid = id(c.req.param('id'));
  const rows = await c.var.sql`
    UPDATE contract_flag SET resolved_at = now(), resolved_by = crm_active_user_id()
     WHERE id = ${fid} AND resolved_at IS NULL
    RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Príznak nemôžete uzavrieť alebo už je uzavretý.' }, 403);
  return c.json({ ok: true });
});
