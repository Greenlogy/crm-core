// Nastavenia (modul 0): iba pre admina. Mení iba admin a každá zmena ide do auditu (spúšťače v DB).
// Kontrola admina je tu aj v databáze (RLS Nastavení); tu iba kvôli zrozumiteľnej odpovedi.

import { Hono } from 'hono';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { auditSettings } from './settings-audit';
import { contentSettings } from './settings-content';
import { importAliases } from './settings-aliases';
import { orgSettings } from './settings-org';
import { BadRequest, bool, EMAIL, oneOf, readBody, str, uuid, uuids, type Body } from '../validate';

export const settings = new Hono<AppEnv>();

settings.use('*', async (c, next) => {
  // Cenové parametre (obrazovka 29) sú pod /api/pricing – smie ich aj „schvaľuje ceny“; ostatné Nastavenia iba admin.
  const [row] = await c.var.sql<{ ok: boolean }[]>`SELECT crm_is_admin() AS ok`;
  if (!row?.ok) return c.json({ error: 'Nastavenia môže otvoriť iba admin.' }, 403);
  await next();
});

settings.route('/', orgSettings);
settings.route('/', contentSettings);
settings.route('/', auditSettings);
settings.route('/', importAliases);

// Prehľad pre úvod Nastavení
settings.get('/', async (c) => {
  const [row] = await c.var.sql`
    SELECT (SELECT count(*) FROM app_user WHERE status <> 'deaktivovany')::int AS users,
           (SELECT count(*) FROM team WHERE archived_at IS NULL)::int AS teams,
           (SELECT count(*) FROM org)::int AS orgs`;
  return c.json(row);
});

// ============================================================================
// Používatelia (dizajn 12)
// ============================================================================

settings.get('/users', async (c) => {
  const rows = await c.var.sql`
    SELECT u.id, u.name, u.email, u.is_admin, u.status, u.last_login_at, u.invited_at, u.deactivated_at,
           u.seller_type, u.approves_prices, u.approves_assignments, u.phone, u.job_title,
           t.id AS team_id, t.code AS team_code, t.name AS team_name, t.all_orgs, t.is_external,
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'name', o.legal_name)
                                     ORDER BY o.is_default DESC, o.legal_name)
                       FROM app_user_org uo JOIN org o ON o.id = uo.org_id
                      WHERE uo.user_id = u.id), '[]') AS orgs
      FROM app_user u
      JOIN team t ON t.id = u.team_id
     ORDER BY u.status = 'deaktivovany', lower(u.name)`;
  return c.json({ items: rows });
});

// Tím a spoločnosti: tím bez „všetky spoločnosti“ potrebuje aspoň jednu pridelenú spoločnosť.
async function checkOrgs(sql: Sql, teamId: string, orgIds: string[] | undefined, userId?: string) {
  const [team] = await sql<{ all_orgs: boolean }[]>`SELECT all_orgs FROM team WHERE id = ${teamId}`;
  if (!team) throw new BadRequest('Tím neexistuje.');
  if (team.all_orgs) return;
  const count =
    orgIds !== undefined
      ? orgIds.length
      : Number((await sql`SELECT count(*)::int AS n FROM app_user_org WHERE user_id = ${userId ?? null}`)[0].n);
  if (count === 0) throw new BadRequest('Vyber aspoň jednu spoločnosť (tím nevidí všetky spoločnosti).');
}

async function setUserOrgs(sql: Sql, userId: string, orgIds: string[]) {
  await sql`DELETE FROM app_user_org
             WHERE user_id = ${userId}
               AND org_id NOT IN (SELECT x::uuid FROM jsonb_array_elements_text(${sql.json(orgIds)}::jsonb) x)`;
  await sql`INSERT INTO app_user_org (user_id, org_id)
            SELECT ${userId}, x::uuid FROM jsonb_array_elements_text(${sql.json(orgIds)}::jsonb) x
            ON CONFLICT (user_id, org_id) DO NOTHING`;
}

// Pozvanie: používateľ v stave „pozvaný“; pri prvom prihlásení sa stane aktívnym.
settings.post('/users', async (c) => {
  const b = await readBody(c.req);
  const email = str(b, 'email', 'E-mail', { max: 200 })!.toLowerCase();
  if (!EMAIL.test(email)) throw new BadRequest('E-mail nemá správny tvar.');
  const name = str(b, 'name', 'Meno a priezvisko', { max: 120 })!;
  const teamId = uuid(b, 'team_id', 'Tím')!;
  const orgIds = uuids(b, 'org_ids', 'Spoločnosti') ?? [];
  const isAdmin = bool(b, 'is_admin', 'Admin') ?? false;
  const sellerType = sellerTypeOf(b);
  const approves = bool(b, 'approves_prices', 'Schvaľuje ceny') ?? false;
  const assigns = bool(b, 'approves_assignments', 'Schvaľuje pridelenie firmy') ?? false;
  const sql = c.var.sql;
  await checkOrgs(sql, teamId, orgIds);
  const [user] = await sql<{ id: string }[]>`
    INSERT INTO app_user (email, name, team_id, is_admin, seller_type, approves_prices, approves_assignments)
    VALUES (${email}, ${name}, ${teamId}, ${isAdmin}, ${sellerType ?? null}::seller_type, ${approves}, ${assigns})
    RETURNING id`;
  await setUserOrgs(sql, user.id, orgIds);
  return c.json({ id: user.id }, 201);
});

settings.patch('/users/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Meno a priezvisko', { max: 120, optional: true });
  const teamId = uuid(b, 'team_id', 'Tím', true);
  const orgIds = uuids(b, 'org_ids', 'Spoločnosti');
  const isAdmin = bool(b, 'is_admin', 'Admin');
  const sellerType = sellerTypeOf(b);
  const approves = bool(b, 'approves_prices', 'Schvaľuje ceny');
  const assigns = bool(b, 'approves_assignments', 'Schvaľuje pridelenie firmy');
  // telefón a funkcia obchodníka do ponuky („Cenovú ponuku spracoval“, 0039)
  const phone = 'phone' in b ? (str(b, 'phone', 'Telefón', { max: 40, optional: true }) || null) : undefined;
  const jobTitle = 'job_title' in b ? (str(b, 'job_title', 'Funkcia', { max: 80, optional: true }) || null) : undefined;
  const sql = c.var.sql;
  const [cur] = await sql<{ team_id: string }[]>`SELECT team_id FROM app_user WHERE id = ${id}`;
  if (!cur) return c.json({ error: 'Používateľ neexistuje.' }, 404);
  if (name === '') throw new BadRequest('Chýba: Meno a priezvisko.');
  await sql`
    UPDATE app_user
       SET name = coalesce(${name ?? null}, name),
           team_id = coalesce(${teamId ?? null}::uuid, team_id),
           is_admin = coalesce(${isAdmin ?? null}::boolean, is_admin),
           seller_type = CASE WHEN ${sellerType !== undefined} THEN ${sellerType ?? null}::seller_type ELSE seller_type END,
           approves_prices = coalesce(${approves ?? null}::boolean, approves_prices),
           approves_assignments = coalesce(${assigns ?? null}::boolean, approves_assignments),
           phone = CASE WHEN ${phone !== undefined} THEN ${phone ?? null}::text ELSE phone END,
           job_title = CASE WHEN ${jobTitle !== undefined} THEN ${jobTitle ?? null}::text ELSE job_title END
     WHERE id = ${id}`;
  if (orgIds !== undefined) await setUserOrgs(sql, id, orgIds);
  await checkOrgs(sql, teamId ?? cur.team_id, undefined, id);
  return c.json({ ok: true });
});

// Typ predajcu: 'obchodnik' | 'manazer' | null (nepredáva); chýbajúci kľúč = bez zmeny.
function sellerTypeOf(b: Body): 'obchodnik' | 'manazer' | null | undefined {
  if (!('seller_type' in b)) return undefined;
  if (b.seller_type === null || b.seller_type === '') return null;
  return oneOf(b, 'seller_type', 'Typ predajcu', ['obchodnik', 'manazer'] as const);
}

// Čo používateľ vlastní (pred deaktiváciou) a komu sa to dá odovzdať.
settings.get('/users/:id/handover', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const [counts] = await c.var.sql`
    SELECT (SELECT count(*) FROM company WHERE owner_id = ${id})::int AS companies,
           (SELECT count(*) FROM contact WHERE owner_id = ${id})::int AS contacts,
           (SELECT count(*) FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
             WHERE d.owner_id = ${id} AND NOT s.is_closed)::int AS open_deals`;
  const owners = await c.var.sql`
    SELECT u.id, u.name, t.name AS team_name FROM app_user u JOIN team t ON t.id = u.team_id
     WHERE u.status = 'aktivny' AND u.id <> ${id} ORDER BY lower(u.name)`;
  return c.json({ ...counts, owners });
});

settings.post('/users/:id/deactivate', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const newOwner = uuid(b, 'new_owner_id', 'Nový vlastník', true) ?? null;
  const [r] = await c.var.sql`SELECT * FROM app_user_deactivate(${id}, ${newOwner})`;
  return c.json(r);
});

// ============================================================================
// Tímy a práva (dizajn 13)
// ============================================================================

export const MODULES = ['zakaznici', 'odberne_miesta', 'obchod', 'zmluvy', 'provizie', 'servis', 'marketing'] as const;
const SCOPES = ['nic', 'iba_svoje', 'vsetko'] as const;

settings.get('/teams', async (c) => {
  const rows = await c.var.sql`
    SELECT t.id, t.code, t.name, t.description, t.all_orgs, t.can_change_owner, t.is_external, t.archived_at,
           (SELECT count(*) FROM app_user u WHERE u.team_id = t.id AND u.status <> 'deaktivovany')::int AS members,
           (SELECT string_agg(x.name, ', ') FROM (
              SELECT u.name FROM app_user u WHERE u.team_id = t.id AND u.status <> 'deaktivovany'
               ORDER BY lower(u.name) LIMIT 3) x) AS member_names,
           coalesce((SELECT json_object_agg(p.module, json_build_object('view', p.view_scope, 'edit', p.edit_scope,
                                                                        'archive', p.can_archive, 'export', p.can_export,
                                                                        'import', p.can_import, 'edit_active', p.can_edit_active_oom,
                                                                        'margin', p.can_see_company_margin))
                       FROM team_permission p WHERE p.team_id = t.id), '{}') AS permissions
      FROM team t
     ORDER BY t.archived_at IS NOT NULL,
              coalesce(array_position(ARRAY['ceo','sales_internal','sales_external','servis','nakup','marketing'], t.code), 99),
              lower(t.name)`;
  return c.json({ items: rows });
});

settings.post('/teams', async (c) => {
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov tímu', { max: 60 })!;
  const description = str(b, 'description', 'Popis', { max: 200, optional: true }) || null;
  const allOrgs = bool(b, 'all_orgs', 'Všetky spoločnosti') ?? false;
  const isExternal = bool(b, 'is_external', 'Externý tím') ?? false;
  const [row] = await c.var.sql<{ id: string }[]>`
    INSERT INTO team (name, code, description, all_orgs, is_external)
    VALUES (${name}, crm_slug(${name}), ${description}, ${allOrgs}, ${isExternal})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

settings.patch('/teams/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const name = str(b, 'name', 'Názov tímu', { max: 60, optional: true });
  if (name === '') throw new BadRequest('Chýba: Názov tímu.');
  const description = str(b, 'description', 'Popis', { max: 200, optional: true });
  const allOrgs = bool(b, 'all_orgs', 'Všetky spoločnosti');
  const archived = bool(b, 'archived', 'Archivovať');
  const sql = c.var.sql;
  if (archived) {
    const [m] = await sql`SELECT count(*)::int AS n FROM app_user WHERE team_id = ${id} AND status <> 'deaktivovany'`;
    if (m.n > 0) throw new BadRequest('Tím má členov. Najprv ich presuň do iného tímu.');
  }
  await sql`
    UPDATE team
       SET name = coalesce(${name ?? null}, name),
           description = CASE WHEN ${description !== undefined} THEN nullif(${description ?? ''}, '') ELSE description END,
           all_orgs = coalesce(${allOrgs ?? null}::boolean, all_orgs),
           archived_at = CASE WHEN ${archived === undefined} THEN archived_at
                              WHEN ${archived ?? false} THEN coalesce(archived_at, now()) ELSE NULL END
     WHERE id = ${id}`;
  return c.json({ ok: true });
});

// Celá matica práv tímu naraz: { permissions: { zakaznici: { view, edit, archive, export, import, edit_active, margin }, … } }
// import, edit_active a margin sú nepovinné (staršia obrazovka ich neposiela → bez zmeny); edit_active iba pri OOM,
// margin (vidieť maržu firmy) iba pri Zmluvách.
settings.patch('/teams/:id/permissions', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  const b = await readBody(c.req);
  const perms = b.permissions;
  if (!perms || typeof perms !== 'object' || Array.isArray(perms)) throw new BadRequest('Chýbajú práva.');
  for (const [module, p] of Object.entries(perms as Record<string, unknown>)) {
    if (!(MODULES as readonly string[]).includes(module)) throw new BadRequest(`Neznámy modul ${module}.`);
    const pb = p as Body;
    const view = oneOf(pb, 'view', 'Vidieť', SCOPES)!;
    const edit = oneOf(pb, 'edit', 'Upravovať', SCOPES)!;
    const archive = bool(pb, 'archive', 'Archivovať')!;
    const exp = bool(pb, 'export', 'Exportovať')!;
    const imp = bool(pb, 'import', 'Importovať');
    const editActive = module === 'odberne_miesta' ? bool(pb, 'edit_active', 'Upravovať Aktívne OOM') : undefined;
    const margin = module === 'zmluvy' ? bool(pb, 'margin', 'Vidieť maržu firmy') : undefined;
    if ([view, edit, archive, exp].some((v) => v === undefined)) throw new BadRequest('Neúplné práva modulu.');
    await c.var.sql`
      UPDATE team_permission
         SET view_scope = ${view}::access_scope, edit_scope = ${edit}::access_scope,
             can_archive = ${archive}, can_export = ${exp},
             can_import = coalesce(${imp ?? null}::boolean, can_import),
             can_edit_active_oom = coalesce(${editActive ?? null}::boolean, can_edit_active_oom),
             can_see_company_margin = coalesce(${margin ?? null}::boolean, can_see_company_margin)
       WHERE team_id = ${id} AND module = ${module}::crm_module`;
  }
  return c.json({ ok: true });
});
