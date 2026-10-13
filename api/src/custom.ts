// Vlastné polia v zoznamoch (Zákazníci F3, Odberné miesta F3): filtre podľa polí „dá sa filtrovať“.
// Hodnoty sú v stĺpci custom (jsonb); typ a pravidlá stráži databáza (custom_values_check, 0007).

import type { Fragment } from 'postgres';
import type { Sql } from './db';
import { BadRequest } from './validate';

export type Entity = 'firma' | 'osoba' | 'oom';

/** ?cf={"kluc":"hodnota",…} → objekt; prázdne hodnoty sa vynechajú. */
export function parseCustomFilter(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  let v: unknown;
  try {
    v = JSON.parse(raw);
  } catch {
    throw new BadRequest('Filter vlastných polí: neplatný zápis.');
  }
  if (!v || typeof v !== 'object' || Array.isArray(v)) throw new BadRequest('Filter vlastných polí: neplatný zápis.');
  const out: Record<string, string> = {};
  for (const [k, x] of Object.entries(v as Record<string, unknown>)) {
    if (!/^[a-z][a-z0-9_]{1,62}$/.test(k)) throw new BadRequest('Filter vlastných polí: neznáme pole.');
    if (typeof x === 'string' && x.trim() !== '') out[k] = x.trim().slice(0, 100);
  }
  return out;
}

/**
 * Podmienka WHERE pre filtre vlastných polí. `custom` = výraz s hodnotami záznamu (jsonb).
 * Filtrovať sa dá iba podľa nearchivovaných polí s príznakom „dá sa filtrovať“.
 * Vracia { cond } – samotný fragment by sa pri await spustil ako dopyt (postgres.js je „thenable“).
 */
export async function customCondition(
  sql: Sql,
  entities: Entity[],
  filters: Record<string, string>,
  custom: Fragment,
): Promise<{ cond: Fragment }> {
  const keys = Object.keys(filters);
  if (keys.length === 0) return { cond: sql`TRUE` };
  const defs = await sql<{ key: string; field_type: string }[]>`
    SELECT DISTINCT ON (key) key, field_type FROM custom_field
     WHERE entity::text IN (SELECT jsonb_array_elements_text(${sql.json(entities)}::jsonb))
       AND filterable AND archived_at IS NULL
       AND key IN (SELECT jsonb_array_elements_text(${sql.json(keys)}::jsonb))`;
  let cond = sql`TRUE`;
  for (const d of defs) {
    const v = filters[d.key];
    let c: Fragment;
    switch (d.field_type) {
      case 'ano_nie':
        if (v !== 'true' && v !== 'false') throw new BadRequest('Filter áno/nie: neplatná hodnota.');
        c = sql`${custom} @> ${sql.json({ [d.key]: v === 'true' })}::jsonb`;
        break;
      case 'vyber':
      case 'odkaz':
        c = sql`${custom} @> ${sql.json({ [d.key]: v })}::jsonb`;
        break;
      case 'vyber_viac':
        c = sql`${custom} @> ${sql.json({ [d.key]: [v] })}::jsonb`;
        break;
      case 'cislo':
      case 'suma': {
        const n = Number(v.replace(',', '.'));
        if (!Number.isFinite(n)) throw new BadRequest('Filter čísla: neplatná hodnota.');
        c = sql`(${custom} ->> ${d.key})::numeric = ${n}`;
        break;
      }
      case 'datum':
        if (!/^\d{4}-\d{2}-\d{2}$/.test(v)) throw new BadRequest('Filter dátumu: RRRR-MM-DD.');
        c = sql`${custom} ->> ${d.key} = ${v}`;
        break;
      default: // text, dlhý text
        c = sql`${custom} ->> ${d.key} ILIKE ${'%' + v + '%'}`;
    }
    cond = sql`${cond} AND ${c}`;
  }
  return { cond };
}
