// Nastavenia (modul 0): iba pre admina. Mení iba admin a každá zmena ide do auditu (spúšťače v DB).
// Kontrola admina je tu aj v databáze (RLS Nastavení); tu iba kvôli zrozumiteľnej odpovedi.

import { Hono } from 'hono';
import type { AppEnv } from '../types';

export const settings = new Hono<AppEnv>();

settings.use('*', async (c, next) => {
  const [row] = await c.var.sql<{ ok: boolean }[]>`SELECT crm_is_admin() AS ok`;
  if (!row?.ok) return c.json({ error: 'Nastavenia môže otvoriť iba admin.' }, 403);
  await next();
});

// Prehľad pre úvod Nastavení
settings.get('/', async (c) => {
  const [row] = await c.var.sql`
    SELECT (SELECT count(*) FROM app_user WHERE status <> 'deaktivovany')::int AS users,
           (SELECT count(*) FROM team WHERE archived_at IS NULL)::int AS teams,
           (SELECT count(*) FROM org)::int AS orgs`;
  return c.json(row);
});
