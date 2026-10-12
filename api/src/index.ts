// API jadra Greenlogy CRM. Zatiaľ iba čítanie (GET); zápis príde s obrazovkami Nastavení.
// Každá požiadavka: overenie prihlásenia (Cloudflare Access) → používateľ z CRM (app_user_login)
// → transakcia s app.user_id, takže platia práva tímu a spoločností priamo v databáze.
// Do logu nejdú osobné údaje: iba cesta, stav a kód chyby.

import { Hono } from 'hono';
import { accessEmail } from './auth';
import { asUser, connect, type Env, type Sql } from './db';
import { listContacts, ROLE_FILTERS } from './queries/contacts';
import { contractCard } from './queries/contracts';
import {
  customerCard,
  listCustomers,
  listOwners,
  menuCounts,
  SEGMENT_FILTERS,
  STATUS_FILTERS,
  type CustomerKind,
} from './queries/customers';
import { oomCard } from './queries/oom';

type Vars = { sql: Sql; userId: string };

const app = new Hono<{ Bindings: Env; Variables: Vars }>().basePath('/api');

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

app.use('*', async (c, next) => {
  if (c.req.method !== 'GET') return c.json({ error: 'Povolené je iba čítanie (GET).' }, 405);
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
           coalesce((SELECT json_agg(json_build_object('id', o.id, 'name', o.legal_name, 'country', o.country,
                                                       'currency', o.currency, 'status', o.status, 'default', o.is_default)
                                     ORDER BY o.is_default DESC, o.legal_name)
                       FROM org o WHERE o.id = ANY (crm_user_orgs())), '[]') AS orgs,
           coalesce((SELECT json_object_agg(p.module, json_build_object('view', p.view_scope, 'edit', p.edit_scope,
                                                                        'archive', p.can_archive, 'export', p.can_export))
                       FROM team_permission p WHERE p.team_id = u.team_id), '{}') AS permissions
      FROM app_user u
      JOIN team t ON t.id = u.team_id
     WHERE u.id = ${c.var.userId}`;
  return me ? c.json(me) : c.json({ error: 'Nemáte prístup do CRM.' }, 403);
});

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
  if (owner !== '' && !UUID.test(owner)) return c.json({ error: 'Neplatný obchodník.' }, 400);
  return c.json(await listCustomers(c.var.sql, { q, status, segment, owner, page }));
});

app.get('/owners', async (c) => c.json(await listOwners(c.var.sql)));
app.get('/counts', async (c) => c.json(await menuCounts(c.var.sql)));

// Kontakty: q (meno, e-mail, telefón), role (rola vo firme), page.
app.get('/contacts', async (c) => {
  const q = (c.req.query('q') ?? '').trim().slice(0, 100);
  const role = c.req.query('role') ?? '';
  const page = Math.max(1, Number.parseInt(c.req.query('page') ?? '1', 10) || 1);
  if (!ROLE_FILTERS.has(role)) return c.json({ error: 'Neplatná rola.' }, 400);
  return c.json(await listContacts(c.var.sql, { q, role, page }));
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

app.get('/oom/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) return badId(c);
  const result = await oomCard(c.var.sql, id);
  return result ? c.json(result) : notFound(c);
});

app.get('/contracts/:id', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) return badId(c);
  const result = await contractCard(c.var.sql, id);
  return result ? c.json(result) : notFound(c);
});

app.notFound((c) => c.json({ error: 'Neznáma cesta.' }, 404));

app.onError((err, c) => {
  // Bez správy chyby: môže obsahovať hodnoty z databázy.
  const code = (err as { code?: string }).code ?? 'unknown';
  console.error(`API chyba ${c.req.method} ${c.req.routePath}: ${err.name} ${code}`);
  return c.json({ error: 'Chyba servera.' }, 500);
});

export default app;
