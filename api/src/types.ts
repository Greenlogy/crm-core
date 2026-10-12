// Spoločné typy Hono aplikácie (prostredie Workera a premenné požiadavky).

import type { Env, Sql } from './db';

export type Vars = { sql: Sql; userId: string };
export type AppEnv = { Bindings: Env; Variables: Vars };

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
