// Modul Odberné miesta, F2a – zmena stavu, prepis, návrat a plánované zmeny (zadanie čl. 15, migrácia 0016).
// Pravidlá stráži databáza: práva (RLS, „iba svoje“, upravovať Aktívne OOM), blokovanie aktívnym plánom,
// dátumy väzby. Ak deň zmeny už nastal, zmena sa urobí hneď; inak sa uloží plán (vykoná ho nočný beh).
// Dátum: prepis = prvý deň nového odberateľa; odchod a zrušenie = posledný deň dodávky.

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, oneOf, readBody, uuid, type Body } from '../validate';

export const oomWrite = new Hono<AppEnv>();

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

const DATE = /^\d{4}-\d{2}-\d{2}$/;
function day(b: Body, key: string, label: string): string {
  const v = b[key];
  if (typeof v !== 'string' || !DATE.test(v) || Number.isNaN(Date.parse(v))) throw new BadRequest(`Chýba alebo je neplatný dátum: ${label}.`);
  return v;
}

/** Nový zákazník: práve jedno z company_id / person_id. */
function customer(b: Body): { company: string | null; person: string | null } {
  const company = uuid(b, 'company_id', 'Firma', true) ?? null;
  const person = uuid(b, 'person_id', 'Domácnosť', true) ?? null;
  if ((company === null) === (person === null)) throw new BadRequest('Vyberte práve jedného zákazníka (firmu alebo domácnosť).');
  return { company, person };
}

// Zmena stavu: aktivne (hneď, ak má povinné údaje), odidene / zrusene k poslednému dňu dodávky (hneď alebo plán).
oomWrite.post('/oom/:id/status', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const status = oneOf(b, 'status', 'Stav', ['aktivne', 'odidene', 'zrusene'] as const)!;
  if (!status) throw new BadRequest('Chýba stav.');
  if (status === 'aktivne') {
    await c.var.sql`SELECT oom_set_status(${oomId}, 'aktivne')`;
    return c.json({ executed: true, plan_id: null });
  }
  const date = day(b, 'date', 'Posledný deň dodávky');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`
    SELECT oom_plan_change(${oomId}, ${status === 'odidene' ? 'odchod' : 'zrusenie'}::oom_plan_kind, ${date}::date) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

// Prepis na iného odberateľa k prvému dňu nového odberateľa (hneď alebo plán).
oomWrite.post('/oom/:id/transfer', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const { company, person } = customer(b);
  const date = day(b, 'date', 'Prvý deň nového odberateľa');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`
    SELECT oom_plan_change(${oomId}, 'prepis', ${date}::date, ${company}::uuid, ${person}::uuid) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

// Návrat OOM k Greenlogy (odídené alebo zrušené): nová väzba Pripravované od dátumu.
oomWrite.post('/oom/:id/reconnect', async (c) => {
  const oomId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const { company, person } = customer(b);
  const date = day(b, 'date', 'Začiatok nového obdobia');
  await c.var.sql`SELECT oom_reconnect(${oomId}, ${company}::uuid, ${person}::uuid, ${date}::date)`;
  return c.json({ ok: true });
});

// Zmena dátumu plánu (ak deň už nastal, vykoná sa hneď) a zrušenie plánu (aj zlyhaného).
oomWrite.patch('/oom-plans/:id', async (c) => {
  const planId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const date = day(b, 'date', 'Dátum');
  const [r] = await c.var.sql<{ plan_id: string | null }[]>`SELECT oom_plan_reschedule(${planId}, ${date}::date) AS plan_id`;
  return c.json({ executed: r.plan_id === null, plan_id: r.plan_id });
});

oomWrite.delete('/oom-plans/:id', async (c) => {
  const planId = id(c.req.param('id'));
  await c.var.sql`SELECT oom_plan_cancel(${planId})`;
  return c.json({ ok: true });
});

// Hľadanie zákazníka (firma alebo domácnosť) pre prepis a návrat: iba tí, ktorých používateľ vidí,
// v spoločnosti OOM (zákazník a OOM patria jednej spoločnosti skupiny).
oomWrite.get('/oom-customers', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const org = c.req.query('org') ?? '';
  if (!UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  if (q.length < 2) return c.json({ items: [] });
  const like = `%${q}%`;
  const rows = await c.var.sql`
    SELECT CASE cu.customer_type WHEN 'B2B' THEN 'company' ELSE 'person' END AS kind,
           cu.id, cu.name, cu.ico, cu.email, cu.status, cu.archived
      FROM customer_v cu
     WHERE cu.org_id = ${org}
       AND (cu.name ILIKE ${like} OR cu.ico LIKE ${q.replace(/\s/g, '') + '%'} OR cu.email ILIKE ${like})
     ORDER BY cu.archived, cu.name
     LIMIT 20`;
  return c.json({ items: rows });
});

// ============================================================================
// F2b – založenie a úprava OOM, kroky prechodu
// ============================================================================

// Polia OOM, ktoré smie meniť formulár (zákazník, stav a spoločnosť nie – tie idú cez väzby).
// Typ určuje kontrolu v API a pretypovanie v SQL; pravidlá CRM (povinné pre Aktívne, číselníky,
// sadzba k PDS, poradie krokov, právo upravovať Aktívne OOM) stráži databáza.
type FieldKind = 'text' | 'num' | 'int' | 'date' | 'bool' | 'code' | 'enum';
const FIELDS: Record<string, { kind: FieldKind; label: string; max?: number; cast?: string; values?: readonly string[] }> = {
  eic: { kind: 'text', label: 'EIC', max: 20 },
  type: { kind: 'enum', label: 'Typ', cast: 'oom_type', values: ['spotreba', 'vyroba', 'sharing'] },
  name: { kind: 'text', label: 'Názov', max: 120 },
  address_street: { kind: 'text', label: 'Ulica', max: 120 },
  address_number_supisne: { kind: 'text', label: 'Súpisné číslo', max: 20 },
  address_number_orientacne: { kind: 'text', label: 'Orientačné číslo', max: 20 },
  address_city: { kind: 'text', label: 'Obec', max: 80 },
  address_zip: { kind: 'text', label: 'PSČ', max: 10 },
  pds: { kind: 'code', label: 'PDS' },
  pds_point_id: { kind: 'text', label: 'Číslo OP', max: 40 },
  pds_tariff: { kind: 'code', label: 'Sadzba' },
  voltage_level: { kind: 'enum', label: 'Napäťová úroveň', cast: 'voltage_level', values: ['nn', 'vn', 'vvn'] },
  metering_type: { kind: 'code', label: 'Typ merania' },
  phases: { kind: 'int', label: 'Fázy' },
  breaker_a: { kind: 'num', label: 'Istič' },
  reserved_capacity_kw: { kind: 'num', label: 'Rezervovaná kapacita' },
  max_reserved_capacity_kw: { kind: 'num', label: 'Max. rezervovaná kapacita' },
  capacity_reservation_method: { kind: 'text', label: 'Spôsob rezervácie kapacity', max: 80 },
  price_regulation: { kind: 'text', label: 'Cenová regulácia', max: 80 },
  excise_tax: { kind: 'text', label: 'Spotrebná daň', max: 80 },
  billing_period: { kind: 'code', label: 'Fakturačné obdobie' },
  advance_payment_method: { kind: 'code', label: 'Zálohy' },
  advance_payment_pct: { kind: 'num', label: 'Záloha [%]' },
  advance_payment_eur: { kind: 'num', label: 'Záloha [€]' },
  planned_consumption_vt_mwh: { kind: 'num', label: 'Plánovaná spotreba VT' },
  planned_consumption_nt_mwh: { kind: 'num', label: 'Plánovaná spotreba NT' },
  planned_feed_in_mwh: { kind: 'num', label: 'Plánovaný výkup' },
  source_kind: {
    kind: 'enum',
    label: 'Druh zdroja',
    cast: 'source_kind',
    values: ['fve', 'voda', 'bioplyn', 'biomasa', 'plyn', 'vietor', 'ostatne_oze'],
  },
  source_category: { kind: 'enum', label: 'Kategória zdroja', cast: 'oom_source_category', values: ['maly_zdroj', 'lokalny_zdroj', 'vyrobny_zdroj'] },
  source_power_kw: { kind: 'num', label: 'Výkon zdroja' },
  inverter_power_kw: { kind: 'num', label: 'Výkon striedača' },
  panels_power_kw: { kind: 'num', label: 'Výkon panelov' },
  feed_in_contract_type: { kind: 'code', label: 'Typ výkupnej zmluvy' },
  supply_from: { kind: 'date', label: 'Dodávka od' },
  supply_to: { kind: 'date', label: 'Dodávka do' },
  previous_supplier: { kind: 'code', label: 'Predošlý dodávateľ' },
  switch_notice_required: { kind: 'bool', label: 'Výpoveď sa zasiela' },
  switch_notice_sent_on: { kind: 'date', label: 'Výpoveď odoslaná' },
  switch_notice_accepted_on: { kind: 'date', label: 'Výpoveď akceptovaná' },
  switch_confirmed_on: { kind: 'date', label: 'Zmena dodávateľa potvrdená' },
};
const CAST: Record<FieldKind, string> = { text: 'text', num: 'numeric', int: 'smallint', date: 'date', bool: 'boolean', code: 'text', enum: '' };

/** Hodnoty polí z tela požiadavky (iba známe polia; prázdne = NULL). */
function oomValues(b: Body): Record<string, string | number | boolean | null> {
  const out: Record<string, string | number | boolean | null> = {};
  for (const [key, f] of Object.entries(FIELDS)) {
    if (!(key in b)) continue;
    const v = b[key];
    if (v === null || v === '') {
      if (key === 'eic' || key === 'type' || key === 'switch_notice_required') throw new BadRequest(`Chýba: ${f.label}.`);
      out[key] = null;
      continue;
    }
    switch (f.kind) {
      case 'text': {
        if (typeof v !== 'string') throw new BadRequest(`${f.label}: očakávaný text.`);
        // EIC: veľké písmená bez medzier; PSČ bez medzery (014 01 → 01401, zobrazí sa s medzerou)
        const t = key === 'eic' ? v.toUpperCase().replace(/\s/g, '') : key === 'address_zip' ? v.replace(/\s/g, '') : v.trim();
        if (t.length > (f.max ?? 200)) throw new BadRequest(`${f.label}: najviac ${f.max} znakov.`);
        out[key] = t === '' ? null : t;
        break;
      }
      case 'num':
      case 'int': {
        const n = typeof v === 'number' ? v : typeof v === 'string' ? Number(v.replace(',', '.').replace(/\s/g, '')) : Number.NaN;
        if (!Number.isFinite(n) || n < 0 || (f.kind === 'int' && !Number.isInteger(n))) throw new BadRequest(`${f.label}: neplatné číslo.`);
        out[key] = n;
        break;
      }
      case 'date':
        if (typeof v !== 'string' || !DATE.test(v)) throw new BadRequest(`${f.label}: neplatný dátum.`);
        out[key] = v;
        break;
      case 'bool':
        if (typeof v !== 'boolean') throw new BadRequest(`${f.label}: očakávané áno/nie.`);
        out[key] = v;
        break;
      case 'code':
        if (typeof v !== 'string' || !/^[a-z0-9_]{1,63}$/.test(v)) throw new BadRequest(`${f.label}: neplatná hodnota.`);
        out[key] = v;
        break;
      case 'enum':
        if (typeof v !== 'string' || !f.values!.includes(v)) throw new BadRequest(`${f.label}: neplatná hodnota.`);
        out[key] = v;
        break;
    }
  }
  return out;
}

// Možnosti formulára: číselníky OOM pre spoločnosť (skryté hodnoty iba pri existujúcom zázname – obrazovka ich ukáže).
oomWrite.get('/oom-options', async (c) => {
  const org = c.req.query('org') ?? '';
  if (!UUID.test(org)) throw new BadRequest('Neplatná spoločnosť.');
  const rows = await c.var.sql`
    SELECT list_code, code, label, parent_code, hidden_at IS NOT NULL AS hidden
      FROM lookup_value
     WHERE list_code IN ('pds', 'sadzba_distribucie', 'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh',
                         'typ_vykupnej_zmluvy', 'predchadzajuci_dodavatel')
       AND (org_id IS NULL OR org_id = ${org})
     ORDER BY list_code, sort_order, lower(label)`;
  const lists: Record<string, unknown[]> = {};
  for (const r of rows) (lists[r.list_code as string] ??= []).push({ code: r.code, label: r.label, parent: r.parent_code, hidden: r.hidden });
  return c.json(lists);
});

// Kontrola EIC počas písania: formát a kontrolná číslica, „už existuje“ (vlastník; id iba ak OOM vidí).
oomWrite.get('/oom-check-eic', async (c) => {
  const eic = (c.req.query('eic') ?? '').toUpperCase().replace(/\s/g, '').slice(0, 20);
  if (eic.length < 16) return c.json({ eic, valid: false, complete: false, existing: [] });
  const [[v], existing] = await Promise.all([
    c.var.sql<{ valid: boolean }[]>`SELECT eic_is_valid(${eic}) AS valid`,
    c.var.sql`SELECT * FROM oom_eic_check(${eic})`,
  ]);
  return c.json({ eic, valid: v.valid, complete: true, existing });
});

// Nové OOM: zákazník (firma alebo domácnosť), EIC, typ; vždy Pripravované (Aktívne až po krokoch prechodu
// alebo tlačidlom Aktivovať). Spoločnosť preberá od zákazníka.
oomWrite.post('/oom', async (c) => {
  const b = await readBody(c.req);
  const { company, person } = customer(b);
  const v = oomValues(b);
  if (!v.eic) throw new BadRequest('Chýba: EIC.');
  if (!v.type) throw new BadRequest('Chýba: Typ.');
  const sql = c.var.sql;
  const cols = Object.keys(v);
  const values = cols.map((k) => sql`${v[k]}::${sql.unsafe(FIELDS[k].cast ?? CAST[FIELDS[k].kind])}`);
  const list = values.reduce((acc, f) => sql`${acc}, ${f}`);
  const names = cols.map((k) => sql`${sql(k)}`).reduce((acc, f) => sql`${acc}, ${f}`);
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO oom (company_id, person_id, status, ${names})
    VALUES (${company}::uuid, ${person}::uuid, 'pripravovane', ${list})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// Úprava údajov OOM: iba poslané polia. Aktívne OOM iba s právom „upravovať Aktívne OOM“ (databáza).
oomWrite.patch('/oom/:id', async (c) => {
  const oomId = id(c.req.param('id'));
  const v = oomValues(await readBody(c.req));
  const cols = Object.keys(v);
  if (cols.length === 0) return c.json({ ok: true });
  const sql = c.var.sql;
  const sets = cols.map((k) => sql`${sql(k)} = ${v[k]}::${sql.unsafe(FIELDS[k].cast ?? CAST[FIELDS[k].kind])}`);
  const set = sets.reduce((acc, f) => sql`${acc}, ${f}`);
  const rows = await sql`UPDATE oom SET ${set} WHERE id = ${oomId} RETURNING id`;
  // RLS: OOM, ktoré používateľ nesmie upravovať, UPDATE nenájde
  if (rows.length === 0) return c.json({ error: 'Odberné miesto nemôžete upravovať alebo neexistuje.' }, 403);
  return c.json({ ok: true });
});
