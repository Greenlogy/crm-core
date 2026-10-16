// API jadra Greenlogy CRM. Čítanie (GET) a zápis (POST, PATCH, DELETE – zatiaľ iba Nastavenia).
// Každá požiadavka: overenie prihlásenia (Cloudflare Access) → používateľ z CRM (app_user_login)
// → transakcia s app.user_id, takže platia práva tímu a spoločností priamo v databáze.
// Do logu nejdú osobné údaje: iba cesta, stav a kód chyby.

import { WorkerEntrypoint } from 'cloudflare:workers';
import { Hono } from 'hono';
import { accessEmail } from './auth';
import { asUser, connect, type Env } from './db';
import { dbErrorResponse } from './errors';
import { contractImport } from './routes/contract-import';
import { contracts } from './routes/contracts';
import { customersWrite } from './routes/customers-write';
import { exportRoutes } from './routes/export';
import { oomImport } from './routes/oom-import';
import { oomWrite } from './routes/oom-write';
import { priceLists } from './routes/pricelists';
import { priceListsWrite } from './routes/pricelists-write';
import { priceExceptions } from './routes/price-exceptions';
import { pricing } from './routes/pricing';
import { productsWrite } from './routes/products-write';
import { settings } from './routes/settings';
import { approvals } from './routes/approvals';
import { companyCheck } from './routes/company-check';
import { deals } from './routes/deals';
import { offers } from './routes/offers';
import { offersPdf } from './routes/offers-pdf';
import { emails } from './routes/emails';
import { type AppEnv, UUID } from './types';
import { BadRequest, Forbidden } from './validate';
import { listContacts, ROLE_FILTER } from './queries/contacts';
import {
  customerCard,
  listCustomers,
  listOwners,
  menuCounts,
  SEGMENT_FILTERS,
  STATUS_FILTERS,
  type CustomerKind,
} from './queries/customers';
import { listOom, OOM_CHIPS, OOM_TYPES, oomCard, oomFilters } from './queries/oom';
import { nightlyRun } from './jobs';
import { emailKick, emailRun } from './email-jobs';
import { jobRuns } from './routes/job-runs';
import { notifications } from './routes/notifications';

const app = new Hono<AppEnv>().basePath('/api');

const WRITE_METHODS = new Set(['POST', 'PUT', 'PATCH', 'DELETE']);

// Zápis iba ako JSON z vlastnej stránky: cudzia stránka nemôže v mene prihláseného nič zmeniť
// (formulár inej stránky nepošle JSON a prehliadač pošle jej Origin).
app.use('*', async (c, next) => {
  const method = c.req.method;
  if (method === 'GET' || method === 'HEAD') return next();
  if (!WRITE_METHODS.has(method)) return c.json({ error: 'Nepovolená metóda.' }, 405);
  const origin = c.req.header('origin');
  if (origin && new URL(origin).host !== new URL(c.req.url).host) {
    return c.json({ error: 'Požiadavka z inej stránky.' }, 403);
  }
  if (method !== 'DELETE' && !(c.req.header('content-type') ?? '').startsWith('application/json')) {
    return c.json({ error: 'Očakávaný JSON.' }, 415);
  }
  await next();
});

// Pripojenie na požiadavku; zatvorí sa po odoslaní odpovede.
app.use('*', async (c, next) => {
  const sql = connect(c.env);
  c.set('sql', sql);
  try {
    await next();
  } finally {
    c.executionCtx.waitUntil(sql.end());
  }
  c.header('Cache-Control', 'no-store');
  // po úspešnom zápise (transakcia je už potvrdená) hneď odošli e-maily, ktoré zápis zaradil (F4)
  if (c.req.method !== 'GET' && c.res.status < 400) c.executionCtx.waitUntil(emailKick(c.env));
});

// Prihlásenie: kto nie je aktívny používateľ CRM, nedostane nič (návrh Nastavení, časť 5).
app.use('*', async (c, next) => {
  if (c.req.path === '/api/health') return next();
  const email = await accessEmail(c.req.raw, c.env);
  if (!email) return c.json({ error: 'Neprihlásený.' }, 401);
  const [login] = await c.var.sql<{ user_id: string | null }[]>`
    SELECT user_id FROM app_user_login(${email})`;
  if (!login?.user_id) return c.json({ error: 'Nemáte prístup do CRM. Obráťte sa na administrátora.' }, 403);
  c.set('userId', login.user_id);

  // Celá požiadavka v jednej transakcii s používateľom; chyba v obsluhe ju vráti späť.
  try {
    await asUser(c.var.sql, login.user_id, async (tx) => {
      c.set('sql', tx);
      await next();
      if (c.error) throw c.error;
    });
  } catch (err) {
    if (err !== c.error) throw err;
  }
});

const notFound = (c: { json: (b: unknown, s: 404) => Response }) => c.json({ error: 'Záznam neexistuje.' }, 404);
const badId = (c: { json: (b: unknown, s: 400) => Response }) => c.json({ error: 'Neplatné ID.' }, 400);

app.get('/health', async (c) => {
  await c.var.sql`SELECT 1`;
  return c.json({ ok: true });
});

// Prihlásený používateľ: tím, admin, spoločnosti a práva po moduloch (frontend podľa nich skryje,
// čo používateľ nesmie; skutočné obmedzenie je v databáze).
app.get('/me', async (c) => {
  const [me] = await c.var.sql`
    SELECT u.id, u.name, u.email, u.is_admin, t.code AS team_code, t.name AS team_name,
           t.can_change_owner OR u.is_admin AS can_change_owner,
           u.seller_type, u.approves_prices, u.approves_assignments, crm_deal_manager() AS deal_manager,
           crm_can_see_margin() AS can_see_margin,
           crm_can_see_job_runs() AS can_see_job_runs,
           ${c.env.ENVIRONMENT ?? 'test'}::text AS environment,
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'name', o.legal_name, 'country', o.country,
                                                       'currency', o.currency, 'status', o.status, 'default', o.is_default)
                                     ORDER BY o.is_default DESC, o.legal_name)
                       FROM org o WHERE o.id = ANY (crm_user_orgs())), '[]') AS orgs,
           coalesce((SELECT json_object_agg(p.module, json_build_object('view', p.view_scope, 'edit', p.edit_scope,
                                                                        'archive', p.can_archive, 'export', p.can_export,
                                                                        'import', p.can_import, 'edit_active', p.can_edit_active_oom,
                                                                        'margin', p.can_see_company_margin))
                       FROM team_permission p WHERE p.team_id = u.team_id), '{}') AS permissions
      FROM app_user u
      JOIN team t ON t.id = u.team_id
     WHERE u.id = ${c.var.userId}`;
  return me ? c.json(me) : c.json({ error: 'Nemáte prístup do CRM.' }, 403);
});

// Zákazníci – zakladanie, úpravy, duplicity (pred kartami: /companies/search nie je id)
app.route('/', contractImport);
app.route('/', contracts);
app.route('/', customersWrite);
app.route('/', exportRoutes);
app.route('/', oomImport);
app.route('/', oomWrite);
app.route('/', priceLists);
app.route('/', priceListsWrite);
app.route('/', productsWrite);
app.route('/', pricing);
app.route('/', priceExceptions);
app.route('/', notifications);
app.route('/', jobRuns);
app.route('/', deals);
app.route('/', offers);
app.route('/', offersPdf);
app.route('/', emails);
app.route('/', approvals);
app.route('/', companyCheck);

// Filtre: status ('' = bez marketingových kontaktov a archívu, 'leady', 'vsetky', alebo jeden stav),
// segment (domacnost, firma, vyrobca), owner (uuid obchodníka).
app.get('/customers', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const status = c.req.query('status') ?? '';
  const segment = c.req.query('segment') ?? '';
  const owner = c.req.query('owner') ?? '';
  const page = Math.max(1, Number.parseInt(c.req.query('page') ?? '1', 10) || 1);
  if (!STATUS_FILTERS.has(status)) return c.json({ error: 'Neplatný stav.' }, 400);
  if (!SEGMENT_FILTERS.has(segment)) return c.json({ error: 'Neplatný segment.' }, 400);
  const org = c.req.query('org') ?? '';
  if (owner !== '' && !UUID.test(owner)) return c.json({ error: 'Neplatný obchodník.' }, 400);
  if (org !== '' && !UUID.test(org)) return c.json({ error: 'Neplatná spoločnosť.' }, 400);
  return c.json(await listCustomers(c.var.sql, { q, status, segment, owner, org, cf: c.req.query('cf'), page }));
});

app.get('/owners', async (c) => c.json(await listOwners(c.var.sql)));
app.get('/counts', async (c) => c.json(await menuCounts(c.var.sql)));

// Kontakty: q (meno, e-mail, telefón), role (rola vo firme), page.
app.get('/contacts', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const role = c.req.query('role') ?? '';
  const page = Math.max(1, Number.parseInt(c.req.query('page') ?? '1', 10) || 1);
  if (!ROLE_FILTER.test(role)) return c.json({ error: 'Neplatná rola.' }, 400);
  return c.json(await listContacts(c.var.sql, { q, role, cf: c.req.query('cf'), page }));
});

const card = (kind: CustomerKind) =>
  app.get(`/${kind === 'company' ? 'companies' : 'persons'}/:id`, async (c) => {
    const id = c.req.param('id');
    if (!UUID.test(id)) return badId(c);
    const result = await customerCard(c.var.sql, kind, id);
    return result ? c.json(result) : notFound(c);
  });
card('company');
card('person');

// Zoznam OOM: q (EIC, názov, adresa, zákazník), stav (tlačidlo: stav, prepisane, zasekol), typ, pds, owner, org, page.
app.get('/oom', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const chip = c.req.query('stav') ?? '';
  const type = c.req.query('typ') ?? '';
  const pds = c.req.query('pds') ?? '';
  const owner = c.req.query('owner') ?? '';
  const org = c.req.query('org') ?? '';
  const page = Math.max(1, Number.parseInt(c.req.query('page') ?? '1', 10) || 1);
  if (!OOM_CHIPS.has(chip)) return c.json({ error: 'Neplatný stav.' }, 400);
  if (type !== '' && !(OOM_TYPES as readonly string[]).includes(type)) return c.json({ error: 'Neplatný typ.' }, 400);
  if (!/^[a-z0-9_]{0,63}$/.test(pds)) return c.json({ error: 'Neplatné PDS.' }, 400);
  if (owner !== '' && !UUID.test(owner)) return c.json({ error: 'Neplatný vlastník.' }, 400);
  if (org !== '' && !UUID.test(org)) return c.json({ error: 'Neplatná spoločnosť.' }, 400);
  return c.json(await listOom(c.var.sql, { q, chip, type, pds, owner, org, cf: c.req.query('cf'), page }));
});

app.get('/oom-filters', async (c) => c.json(await oomFilters(c.var.sql)));

app.get('/oom/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) return badId(c);
  const result = await oomCard(c.var.sql, id);
  return result ? c.json(result) : notFound(c);
});

app.route('/settings', settings);

app.notFound((c) => c.json({ error: 'Neznáma cesta.' }, 404));

app.onError((err, c) => {
  if (err instanceof BadRequest) return c.json({ error: err.message }, 400);
  if (err instanceof Forbidden) return c.json({ error: err.message }, 403);
  const known = dbErrorResponse(err);
  if (known) return c.json(known.body, known.status);
  // Bez správy chyby: môže obsahovať hodnoty z databázy (aj osobné údaje). Do logu iba kód, obmedzenie a miesto v databáze;
  // používateľ dostane všeobecnú správu, nikdy text SQL.
  const e = err as { code?: string; constraint_name?: string; routine?: string; table_name?: string };
  console.error(
    `API chyba ${c.req.method} ${c.req.routePath}: ${err.name} ${e.code ?? 'unknown'}` +
      `${e.constraint_name ? ` obmedzenie=${e.constraint_name}` : ''}${e.table_name ? ` tabuľka=${e.table_name}` : ''}` +
      `${e.routine ? ` rutina=${e.routine}` : ''}`,
  );
  return c.json({ error: 'Chyba servera.' }, 500);
});

// Worker: API (fetch) a naplánované úlohy (scheduled, Cron v wrangler.toml).
export default {
  fetch: app.fetch,
  async scheduled(controller: ScheduledController, env: Env, ctx: ExecutionContext) {
    // každú minútu: e-maily (F4); ostatné časy: nočný beh
    ctx.waitUntil(controller.cron === '* * * * *' ? emailRun(env) : nightlyRun(env));
  },
} satisfies ExportedHandler<Env>;

/**
 * Interné prepojenie pre Worker crm-ponuka (service binding, bez verejnej adresy): po akceptácii klikom hneď odošle
 * potvrdenie zákazníkovi a interný e-mail obchodníkovi. Nič neprijíma, iba spustí odoslanie zaradených e-mailov.
 */
export class EmailKick extends WorkerEntrypoint<Env> {
  async kick(): Promise<void> {
    await emailKick(this.env);
  }
}
