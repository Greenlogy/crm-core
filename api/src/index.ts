// API jadra Greenlogy CRM – prototyp iba na čítanie (modul 2, krok 4; zoznam a karty podľa modulu Zákazníci).
// Iba GET. Do logu nejdú osobné údaje: iba cesta, stav a kód chyby.

import { Hono } from 'hono';
import { connect, type Env, type Sql } from './db';
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

type Vars = { sql: Sql };

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

const notFound = (c: { json: (b: unknown, s: 404) => Response }) => c.json({ error: 'Záznam neexistuje.' }, 404);
const badId = (c: { json: (b: unknown, s: 400) => Response }) => c.json({ error: 'Neplatné ID.' }, 400);

app.get('/health', async (c) => {
  await c.var.sql`SELECT 1`;
  return c.json({ ok: true });
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
