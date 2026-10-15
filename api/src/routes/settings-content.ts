// Nastavenia – Číselníky, Vlastné polia (dizajn 14) a Pipelines a stage (dizajn 15).
// Pripája sa pod /api/settings (kontrola admina je v settings.ts). Pravidlá (zamknuté systémové
// hodnoty, nemenný kľúč poľa, typ poľa s hodnotami, nemazanie) stráži databáza (migrácia 0007).

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, bool, oneOf, readBody, str, uuid, uuids, type Body } from '../validate';

export const contentSettings = new Hono<AppEnv>();

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

function int(b: Body, key: string, label: string, min: number, max: number): number | undefined {
  const v = b[key];
  if (v === undefined) return undefined;
  if (typeof v !== 'number' || !Number.isInteger(v) || v < min || v > max) throw new BadRequest(`${label}: neplatné číslo.`);
  return v;
}

// org_id: undefined = nemeniť, null = celá skupina
function orgId(b: Body): string | null | undefined {
  if (b.org_id === undefined) return undefined;
  if (b.org_id === null || b.org_id === '') return null;
  return uuid(b, 'org_id', 'Spoločnosť');
}

// ============================================================================
// Číselníky
// ============================================================================

/** IČO hodnoty číselníka (PDS): 8 číslic (doplní úvodné nuly), '' = vymazať, undefined = bez zmeny. */
function regNoOf(b: Record<string, unknown>): string | null | undefined {
  if (!('reg_no' in b)) return undefined;
  const v = b.reg_no;
  if (v === null || v === '') return null;
  if (typeof v !== 'string' || !/^\d{1,8}$/.test(v.replace(/\s/g, ''))) throw new BadRequest('IČO: najviac 8 číslic.');
  return v.replace(/\s/g, '').padStart(8, '0');
}

contentSettings.get('/lookups', async (c) => {
  const rows = await c.var.sql`
    SELECT l.code, l.name, l.used_on, l.parent_list,
           coalesce((SELECT json_agg(json_build_object(
                       'id', v.id, 'code', v.code, 'label', v.label, 'org_id', v.org_id, 'org_name', o.legal_name,
                       'sort_order', v.sort_order, 'is_system', v.is_system, 'hidden_at', v.hidden_at,
                       'hubspot_value', v.hubspot_value, 'parent_code', v.parent_code, 'reg_no', v.reg_no)
                     ORDER BY v.hidden_at IS NOT NULL, v.sort_order, lower(v.label))
                       FROM lookup_value v LEFT JOIN org o ON o.id = v.org_id
                      WHERE v.list_code = l.code), '[]') AS "values"
      FROM lookup_list l
     ORDER BY l.name`;
  return c.json({ items: rows });
});

contentSettings.post('/lookups/:list/values', async (c) => {
  const list = c.req.param('list');
  const b = await readBody(c.req);
  const label = str(b, 'label', 'Názov hodnoty', { max: 100 })!;
  const org = orgId(b) ?? null;
  // Sadzba patrí PDS (parent_code, 0013); IČO iba pri PDS. Kontrolu nadradenej hodnoty robí databáza.
  const parent = str(b, 'parent_code', 'Nadradená hodnota', { max: 63, optional: true }) || null;
  const regNo = regNoOf(b);
  const [{ n }] = await c.var.sql`SELECT coalesce(max(sort_order), 0) + 1 AS n FROM lookup_value WHERE list_code = ${list}`;
  const [row] = await c.var.sql<{ id: string }[]>`
    INSERT INTO lookup_value (list_code, label, org_id, sort_order, parent_code, reg_no)
    VALUES (${list}, ${label}, ${org}, ${n}, ${parent}, ${list === 'pds' ? (regNo ?? null) : null})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

contentSettings.patch('/lookup-values/:id', async (c) => {
  const valueId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const label = str(b, 'label', 'Názov hodnoty', { max: 100, optional: true });
  if (label === '') throw new BadRequest('Chýba: Názov hodnoty.');
  const hidden = bool(b, 'hidden', 'Skryť');
  const sort = int(b, 'sort_order', 'Poradie', 0, 100000);
  const org = orgId(b);
  const regNo = regNoOf(b);
  await c.var.sql`
    UPDATE lookup_value
       SET label = coalesce(${label ?? null}, label),
           reg_no = CASE WHEN ${regNo !== undefined} AND list_code = 'pds' THEN ${regNo ?? null} ELSE reg_no END,
           sort_order = coalesce(${sort ?? null}::int, sort_order),
           org_id = CASE WHEN ${org !== undefined} THEN ${org ?? null}::uuid ELSE org_id END,
           hidden_at = CASE WHEN ${hidden === undefined} THEN hidden_at
                            WHEN ${hidden ?? false} THEN coalesce(hidden_at, now()) ELSE NULL END
     WHERE id = ${valueId}`;
  return c.json({ ok: true });
});

// ============================================================================
// Vlastné polia
// ============================================================================

const ENTITIES = ['firma', 'osoba', 'oom', 'deal', 'zmluva', 'ponuka'] as const;
const FIELD_TYPES = ['text', 'dlhy_text', 'cislo', 'suma', 'datum', 'vyber', 'vyber_viac', 'ano_nie', 'odkaz'] as const;
const EDIT_ACCESS = ['vsetky_timy', 'vybrane_timy', 'iba_admin'] as const;

contentSettings.get('/custom-fields', async (c) => {
  const entity = c.req.query('entity') ?? 'firma';
  if (!(ENTITIES as readonly string[]).includes(entity)) throw new BadRequest('Neznámy záznam.');
  const sql = c.var.sql;
  const fields = await sql`
    SELECT f.id, f.entity, f.key, f.label, f.field_type, f.ref_entity, f.section_id, s.name AS section_name,
           f.sort_order, f.is_required, f.show_in_list, f.filterable, f.edit_access, f.org_id, o.legal_name AS org_name,
           f.archived_at,
           coalesce((SELECT json_agg(json_build_object('id', t.id, 'name', t.name) ORDER BY lower(t.name))
                       FROM custom_field_team ft JOIN team t ON t.id = ft.team_id WHERE ft.field_id = f.id), '[]') AS teams,
           coalesce((SELECT json_agg(json_build_object('id', op.id, 'label', op.label, 'hidden_at', op.hidden_at)
                                     ORDER BY op.sort_order, lower(op.label))
                       FROM custom_field_option op WHERE op.field_id = f.id), '[]') AS options
      FROM custom_field f
      LEFT JOIN custom_field_section s ON s.id = f.section_id
      LEFT JOIN org o ON o.id = f.org_id
     WHERE f.entity = ${entity}::crm_entity
     ORDER BY f.archived_at IS NOT NULL, s.sort_order NULLS FIRST, f.sort_order, lower(f.label)`;
  const sections = await sql`
    SELECT id, name, sort_order FROM custom_field_section WHERE entity = ${entity}::crm_entity ORDER BY sort_order, name`;
  return c.json({ fields, sections });
});

async function setFieldTeams(sql: Sql, fieldId: string, teamIds: string[]) {
  await sql`DELETE FROM custom_field_team
             WHERE field_id = ${fieldId}
               AND team_id NOT IN (SELECT x::uuid FROM jsonb_array_elements_text(${sql.json(teamIds)}::jsonb) x)`;
  await sql`INSERT INTO custom_field_team (field_id, team_id)
            SELECT ${fieldId}, x::uuid FROM jsonb_array_elements_text(${sql.json(teamIds)}::jsonb) x
            ON CONFLICT (field_id, team_id) DO NOTHING`;
}

async function addOptions(sql: Sql, fieldId: string, labels: string[]) {
  const [{ n }] = await sql`SELECT coalesce(max(sort_order), 0) AS n FROM custom_field_option WHERE field_id = ${fieldId}`;
  let order = Number(n);
  for (const label of labels) {
    order += 1;
    await sql`INSERT INTO custom_field_option (field_id, label, sort_order) VALUES (${fieldId}, ${label}, ${order})`;
  }
}

function optionLabels(b: Body): string[] {
  const v = b.options;
  if (v === undefined) return [];
  if (!Array.isArray(v) || v.some((x) => typeof x !== 'string')) throw new BadRequest('Hodnoty výberu: neplatný zoznam.');
  const labels = (v as string[]).map((x) => x.trim()).filter(Boolean);
  if (labels.some((x) => x.length > 100)) throw new BadRequest('Hodnota výberu: najviac 100 znakov.');
  return [...new Set(labels)];
}

contentSettings.post('/custom-fields', async (c) => {
  const b = await readBody(c.req);
  const entity = oneOf(b, 'entity', 'Záznam', ENTITIES)!;
  const label = str(b, 'label', 'Názov poľa', { max: 80 })!;
  const type = oneOf(b, 'field_type', 'Typ', FIELD_TYPES);
  if (!entity || !type) throw new BadRequest('Chýba záznam alebo typ poľa.');
  const refEntity = type === 'odkaz' ? oneOf(b, 'ref_entity', 'Odkaz na', ENTITIES) : undefined;
  if (type === 'odkaz' && !refEntity) throw new BadRequest('Vyber, na aký záznam pole odkazuje.');
  const sectionId = uuid(b, 'section_id', 'Sekcia', true) ?? null;
  const editAccess = oneOf(b, 'edit_access', 'Upravujú', EDIT_ACCESS) ?? 'vsetky_timy';
  const teamIds = uuids(b, 'team_ids', 'Tímy') ?? [];
  if (editAccess === 'vybrane_timy' && teamIds.length === 0) throw new BadRequest('Vyber aspoň jeden tím, ktorý pole upravuje.');
  const options = optionLabels(b);
  if ((type === 'vyber' || type === 'vyber_viac') && options.length === 0) throw new BadRequest('Pridaj aspoň jednu hodnotu výberu.');
  const sql = c.var.sql;
  const [{ n }] = await sql`SELECT coalesce(max(sort_order), 0) + 1 AS n FROM custom_field WHERE entity = ${entity}::crm_entity`;
  const [row] = await sql<{ id: string; key: string }[]>`
    INSERT INTO custom_field (entity, label, field_type, ref_entity, section_id, sort_order, is_required, show_in_list,
                              filterable, edit_access, org_id)
    VALUES (${entity}::crm_entity, ${label}, ${type}::custom_field_type, ${refEntity ?? null}::crm_entity, ${sectionId}, ${n},
            ${bool(b, 'is_required', 'Povinné') ?? false}, ${bool(b, 'show_in_list', 'V zozname') ?? false},
            ${bool(b, 'filterable', 'Filter') ?? false}, ${editAccess}::field_edit_access, ${orgId(b) ?? null})
    RETURNING id, key`;
  if (editAccess === 'vybrane_timy') await setFieldTeams(sql, row.id, teamIds);
  await addOptions(sql, row.id, options);
  return c.json(row, 201);
});

contentSettings.patch('/custom-fields/:id', async (c) => {
  const fieldId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const label = str(b, 'label', 'Názov poľa', { max: 80, optional: true });
  if (label === '') throw new BadRequest('Chýba: Názov poľa.');
  const type = oneOf(b, 'field_type', 'Typ', FIELD_TYPES);
  const refEntity = oneOf(b, 'ref_entity', 'Odkaz na', ENTITIES);
  const editAccess = oneOf(b, 'edit_access', 'Upravujú', EDIT_ACCESS);
  const teamIds = uuids(b, 'team_ids', 'Tímy');
  const archived = bool(b, 'archived', 'Archivovať');
  const org = orgId(b);
  const sectionSet = b.section_id !== undefined;
  const sectionId = b.section_id === null || b.section_id === '' ? null : uuid(b, 'section_id', 'Sekcia', true);
  const sql = c.var.sql;
  await sql`
    UPDATE custom_field
       SET label = coalesce(${label ?? null}, label),
           field_type = coalesce(${type ?? null}::custom_field_type, field_type),
           ref_entity = CASE WHEN coalesce(${type ?? null}::custom_field_type, field_type) = 'odkaz'
                             THEN coalesce(${refEntity ?? null}::crm_entity, ref_entity) ELSE NULL END,
           section_id = CASE WHEN ${sectionSet} THEN ${sectionId ?? null}::uuid ELSE section_id END,
           sort_order = coalesce(${int(b, 'sort_order', 'Poradie', 0, 100000) ?? null}::int, sort_order),
           is_required = coalesce(${bool(b, 'is_required', 'Povinné') ?? null}::boolean, is_required),
           show_in_list = coalesce(${bool(b, 'show_in_list', 'V zozname') ?? null}::boolean, show_in_list),
           filterable = coalesce(${bool(b, 'filterable', 'Filter') ?? null}::boolean, filterable),
           edit_access = coalesce(${editAccess ?? null}::field_edit_access, edit_access),
           org_id = CASE WHEN ${org !== undefined} THEN ${org ?? null}::uuid ELSE org_id END,
           archived_at = CASE WHEN ${archived === undefined} THEN archived_at
                              WHEN ${archived ?? false} THEN coalesce(archived_at, now()) ELSE NULL END
     WHERE id = ${fieldId}`;
  if (teamIds !== undefined) await setFieldTeams(sql, fieldId, teamIds);
  const [f] = await sql<{ edit_access: string; n: number; field_type: string; options: number }[]>`
    SELECT f.edit_access, f.field_type,
           (SELECT count(*)::int FROM custom_field_team WHERE field_id = f.id) AS n,
           (SELECT count(*)::int FROM custom_field_option WHERE field_id = f.id AND hidden_at IS NULL) AS options
      FROM custom_field f WHERE f.id = ${fieldId}`;
  if (f?.edit_access === 'vybrane_timy' && f.n === 0) throw new BadRequest('Vyber aspoň jeden tím, ktorý pole upravuje.');
  const newOptions = optionLabels(b);
  await addOptions(sql, fieldId, newOptions);
  if ((f?.field_type === 'vyber' || f?.field_type === 'vyber_viac') && f.options + newOptions.length === 0) {
    throw new BadRequest('Pole výberu potrebuje aspoň jednu viditeľnú hodnotu.');
  }
  return c.json({ ok: true });
});

contentSettings.patch('/custom-field-options/:id', async (c) => {
  const optionId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const label = str(b, 'label', 'Hodnota výberu', { max: 100, optional: true });
  if (label === '') throw new BadRequest('Chýba: Hodnota výberu.');
  const hidden = bool(b, 'hidden', 'Skryť');
  await c.var.sql`
    UPDATE custom_field_option
       SET label = coalesce(${label ?? null}, label),
           sort_order = coalesce(${int(b, 'sort_order', 'Poradie', 0, 100000) ?? null}::int, sort_order),
           hidden_at = CASE WHEN ${hidden === undefined} THEN hidden_at
                            WHEN ${hidden ?? false} THEN coalesce(hidden_at, now()) ELSE NULL END
     WHERE id = ${optionId}`;
  return c.json({ ok: true });
});

contentSettings.post('/custom-field-sections', async (c) => {
  const b = await readBody(c.req);
  const entity = oneOf(b, 'entity', 'Záznam', ENTITIES);
  if (!entity) throw new BadRequest('Chýba: Záznam.');
  const name = str(b, 'name', 'Názov sekcie', { max: 60 })!;
  const [{ n }] = await c.var.sql`SELECT coalesce(max(sort_order), 0) + 1 AS n FROM custom_field_section WHERE entity = ${entity}::crm_entity`;
  const [row] = await c.var.sql<{ id: string }[]>`
    INSERT INTO custom_field_section (entity, name, sort_order) VALUES (${entity}::crm_entity, ${name}, ${n}) RETURNING id`;
  return c.json({ id: row.id }, 201);
});

// ============================================================================
// Pipelines a stage
// ============================================================================

const DEAL_KINDS = ['b2c_dodavka', 'b2b_dodavka', 'b2b_vykup', 'green_solar', 'green_viwa', 'efet'] as const;
const OUTCOMES = ['otvoreny', 'vyhrany', 'prehrany'] as const;
// Polia jadra dealu, ktoré môžu byť povinné pri prechode (zoznam v kóde; modul Obchod ho doplní).
// Polia jadra obchodu, ktoré môže admin vyžadovať pri vstupe do stage. Zákazník, vlastník, zdroj a dôvod prehry
// vynucuje databáza vždy (0032), preto tu nie sú.
export const DEAL_CORE_FIELDS = ['expected_close', 'supply_start', 'next_step', 'estimated_value_eur'] as const;

contentSettings.get('/pipelines', async (c) => {
  const rows = await c.var.sql`
    SELECT p.id, p.name, p.kind, p.org_id, o.legal_name AS org_name, p.sort_order, p.archived_at,
           (SELECT count(*)::int FROM deal d WHERE d.pipeline_id = p.id) AS deals,
           coalesce((SELECT json_agg(json_build_object(
                       'id', s.id, 'name', s.name, 'sort_order', s.sort_order, 'probability', s.probability,
                       'outcome', s.outcome, 'code', s.code, 'archived_at', s.archived_at,
                       'deals', (SELECT count(*) FROM deal d WHERE d.stage_id = s.id),
                       'required', coalesce((SELECT json_agg(json_build_object(
                                     'core_field', r.core_field, 'custom_field_id', r.custom_field_id, 'label', cf.label))
                                     FROM pipeline_stage_required_field r
                                     LEFT JOIN custom_field cf ON cf.id = r.custom_field_id
                                    WHERE r.stage_id = s.id), '[]'))
                     ORDER BY s.archived_at IS NOT NULL, s.sort_order)
                       FROM pipeline_stage s WHERE s.pipeline_id = p.id), '[]') AS stages
      FROM pipeline p
      LEFT JOIN org o ON o.id = p.org_id
     ORDER BY p.archived_at IS NOT NULL, p.sort_order, lower(p.name)`;
  const dealFields = await c.var.sql`
    SELECT id, label FROM custom_field WHERE entity = 'deal' AND archived_at IS NULL ORDER BY lower(label)`;
  return c.json({ items: rows, core_fields: DEAL_CORE_FIELDS, deal_custom_fields: dealFields });
});

contentSettings.post('/pipelines', async (c) => {
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov pipeline', { max: 80 })!;
  const kind = oneOf(b, 'kind', 'Druh obchodu', DEAL_KINDS);
  if (!kind) throw new BadRequest('Chýba: Druh obchodu.');
  const sql = c.var.sql;
  const [{ n }] = await sql`SELECT coalesce(max(sort_order), 0) + 1 AS n FROM pipeline`;
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO pipeline (name, kind, org_id, sort_order) VALUES (${name}, ${kind}::deal_kind, ${orgId(b) ?? null}, ${n})
    RETURNING id`;
  // 6 systémových štádií (Príležitosť … Vyhraté, Prehraté) založí databáza (0032); dajú sa premenovať.
  return c.json({ id: row.id }, 201);
});

contentSettings.patch('/pipelines/:id', async (c) => {
  const pipelineId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov pipeline', { max: 80, optional: true });
  if (name === '') throw new BadRequest('Chýba: Názov pipeline.');
  const archived = bool(b, 'archived', 'Archivovať');
  const org = orgId(b);
  await c.var.sql`
    UPDATE pipeline
       SET name = coalesce(${name ?? null}, name),
           org_id = CASE WHEN ${org !== undefined} THEN ${org ?? null}::uuid ELSE org_id END,
           sort_order = coalesce(${int(b, 'sort_order', 'Poradie', 0, 100000) ?? null}::int, sort_order),
           archived_at = CASE WHEN ${archived === undefined} THEN archived_at
                              WHEN ${archived ?? false} THEN coalesce(archived_at, now()) ELSE NULL END
     WHERE id = ${pipelineId}`;
  return c.json({ ok: true });
});

function probability(b: Body): number | undefined {
  const v = b.probability;
  if (v === undefined) return undefined;
  if (typeof v !== 'number' || v < 0 || v > 100) throw new BadRequest('Pravdepodobnosť: 0 až 100 %.');
  return Math.round(v) / 100;
}

contentSettings.post('/pipelines/:id/stages', async (c) => {
  const pipelineId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov stage', { max: 80 })!;
  // Vyhraté a Prehraté sú systémové štádiá (0032); pridať sa dá iba otvorený medzistupeň.
  const outcome = oneOf(b, 'outcome', 'Typ', OUTCOMES) ?? 'otvoreny';
  if (outcome !== 'otvoreny') throw new BadRequest('Vyhraté a Prehraté sú systémové štádiá – pridať sa dá iba otvorené štádium.');
  const sql = c.var.sql;
  // nová otvorená stage ide pred uzavreté (vyhraný/prehraný)
  const [{ n }] = await sql`
    SELECT coalesce(max(sort_order) FILTER (WHERE outcome = 'otvoreny'), 0) + 1 AS n
      FROM pipeline_stage WHERE pipeline_id = ${pipelineId}`;
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO pipeline_stage (pipeline_id, name, sort_order, probability, outcome)
    VALUES (${pipelineId}, ${name}, ${outcome === 'otvoreny' ? n : Number(n) + 100}, ${probability(b) ?? null},
            ${outcome}::stage_outcome)
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

contentSettings.patch('/stages/:id', async (c) => {
  const stageId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov stage', { max: 80, optional: true });
  if (name === '') throw new BadRequest('Chýba: Názov stage.');
  if (b.outcome !== undefined) throw new BadRequest('Typ štádia sa nemení (systémové štádiá určuje databáza).');
  const archived = bool(b, 'archived', 'Archivovať');
  const prob = probability(b);
  await c.var.sql`
    UPDATE pipeline_stage
       SET name = coalesce(${name ?? null}, name),
           probability = CASE WHEN ${b.probability !== undefined} THEN ${prob ?? null}::numeric ELSE probability END,
           archived_at = CASE WHEN ${archived === undefined} THEN archived_at
                              WHEN ${archived ?? false} THEN coalesce(archived_at, now()) ELSE NULL END
     WHERE id = ${stageId}`;
  return c.json({ ok: true });
});

// Poradie stage: { ids: [prvá, druhá, …] }
contentSettings.patch('/pipelines/:id/stage-order', async (c) => {
  const pipelineId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const ids = uuids(b, 'ids', 'Poradie') ?? [];
  const sql = c.var.sql;
  await sql`
    UPDATE pipeline_stage s SET sort_order = x.ord
      FROM (SELECT v::uuid AS id, ord::int FROM jsonb_array_elements_text(${sql.json(ids)}::jsonb) WITH ORDINALITY AS t (v, ord)) x
     WHERE s.id = x.id AND s.pipeline_id = ${pipelineId}`;
  return c.json({ ok: true });
});

// Povinné polia pri prechode: { core_fields: [...], custom_field_ids: [...] } (nahradí celý zoznam)
contentSettings.patch('/stages/:id/required', async (c) => {
  const stageId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const core = Array.isArray(b.core_fields) ? (b.core_fields as string[]) : [];
  if (core.some((x) => typeof x !== 'string' || !(DEAL_CORE_FIELDS as readonly string[]).includes(x))) {
    throw new BadRequest('Neznáme pole jadra.');
  }
  const custom = uuids(b, 'custom_field_ids', 'Vlastné polia') ?? [];
  const sql = c.var.sql;
  await sql`DELETE FROM pipeline_stage_required_field WHERE stage_id = ${stageId}`;
  await sql`
    INSERT INTO pipeline_stage_required_field (stage_id, core_field)
    SELECT ${stageId}, x FROM jsonb_array_elements_text(${sql.json(core)}::jsonb) x`;
  await sql`
    INSERT INTO pipeline_stage_required_field (stage_id, custom_field_id)
    SELECT ${stageId}, x::uuid FROM jsonb_array_elements_text(${sql.json(custom)}::jsonb) x`;
  return c.json({ ok: true });
});
