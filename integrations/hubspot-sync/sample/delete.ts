// Zmazanie vzorky prototypu z Neon vetvy dev podľa manifestu, s kontrolami pred a po.
//
// Vstup:  exports/prototyp/vzorka-manifest.json
// Výstup: exports/prototyp/vzorka-zmazanie-skuska.sql – to isté, ale na konci ROLLBACK (nič nezmaže)
//         exports/prototyp/vzorka-zmazanie.sql        – zmazanie s COMMIT
//
// Kontroly (pri chybe sa celá transakcia vráti):
//   pred: v každej tabuľke je presne toľko riadkov z manifestu, koľko manifest uvádza;
//   po:   žiadny riadok z manifestu nezostal, audit_log nemá žiadny záznam k týmto riadkom
//         (ani záznamy „delete“, ktoré vznikli pri mazaní), sync_run vzorky je preč.
// Vypíše počty riadkov po tabuľkách a koľko riadkov v tabuľke zostalo (iné dáta sa nemažú).
//
// Použitie: node sample/delete.ts
// SQL sa spúšťa samostatne cez sample/psql-dev.sh, iba s Petrovým súhlasom.

import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../../..');
const outDir = join(root, 'exports/prototyp');

type Manifest = { generatedAt: string; source: string; syncRunId: string; tables: Record<string, string[]> };
const manifest: Manifest = JSON.parse(readFileSync(join(outDir, 'vzorka-manifest.json'), 'utf8'));

// Poradie nahrávania (rodičia pred deťmi); maže sa opačne.
const ORDER = [
  'team', 'app_user', 'company', 'contact', 'company_contact', 'pipeline', 'pipeline_stage',
  'oom', 'deal', 'deal_oom', 'deal_contact', 'contract', 'product', 'contract_price', 'contract_purchase',
];
const missing = Object.keys(manifest.tables).filter((t) => !ORDER.includes(t));
if (missing.length) throw new Error(`Manifest má neznáme tabuľky: ${missing.join(', ')}`);

const tables = ORDER.filter((t) => manifest.tables[t]?.length);
const ids = (t: string) => `'{${manifest.tables[t].join(',')}}'::uuid[]`;
const allIds = `'{${tables.flatMap((t) => manifest.tables[t]).join(',')}}'::uuid[]`;
const total = tables.reduce((n, t) => n + manifest.tables[t].length, 0);

function build(commit: boolean): string {
  return [
    `-- Zmazanie vzorky prototypu podľa manifestu z ${manifest.generatedAt} (${total} riadkov). Iba Neon vetva dev.`,
    commit
      ? '-- OSTRÉ: na konci COMMIT.'
      : '-- SKÚŠKA: urobí a skontroluje všetko, na konci ROLLBACK – nič sa nezmaže.',
    '-- Vygenerované skriptom integrations/hubspot-sync/sample/delete.ts.',
    '\\set ON_ERROR_STOP on',
    'BEGIN;',
    '',
    '-- Kontrola pred zmazaním: v DB sú presne riadky z manifestu',
    'DO $$',
    'DECLARE n bigint;',
    'BEGIN',
    ...tables.flatMap((t) => [
      `  SELECT count(*) INTO n FROM ${t} WHERE id = ANY(${ids(t)});`,
      `  IF n <> ${manifest.tables[t].length} THEN RAISE EXCEPTION '${t}: v DB % z ${manifest.tables[t].length} riadkov manifestu', n; END IF;`,
    ]),
    `  IF NOT EXISTS (SELECT 1 FROM sync_run WHERE id = '${manifest.syncRunId}') THEN RAISE EXCEPTION 'chýba sync_run vzorky'; END IF;`,
    `  SELECT count(*) INTO n FROM audit_log WHERE record_id = ANY(${allIds});`,
    `  RAISE NOTICE 'Pred zmazaním: % riadkov vzorky sedí s manifestom, audit_log k nim: % záznamov', ${total}, n;`,
    'END;',
    '$$;',
    '',
    '-- Zmazanie (deti pred rodičmi), potom audit_log aj so záznamami „delete“ z tohto mazania',
    'CREATE TEMP TABLE vzorka_zmazane (tabulka text, riadkov bigint) ON COMMIT DROP;',
    ...[...tables].reverse().map(
      (t) =>
        `WITH d AS (DELETE FROM ${t} WHERE id = ANY(${ids(t)}) RETURNING 1) INSERT INTO vzorka_zmazane SELECT '${t}', count(*) FROM d;`,
    ),
    `WITH d AS (DELETE FROM audit_log WHERE record_id = ANY(${allIds}) RETURNING 1) INSERT INTO vzorka_zmazane SELECT 'audit_log', count(*) FROM d;`,
    `WITH d AS (DELETE FROM sync_run WHERE id = '${manifest.syncRunId}' RETURNING 1) INSERT INTO vzorka_zmazane SELECT 'sync_run', count(*) FROM d;`,
    '',
    '-- Kontrola po zmazaní',
    'DO $$',
    'DECLARE n bigint;',
    'BEGIN',
    ...tables.flatMap((t) => [
      `  IF EXISTS (SELECT 1 FROM ${t} WHERE id = ANY(${ids(t)})) THEN RAISE EXCEPTION '${t}: riadky vzorky zostali'; END IF;`,
    ]),
    `  SELECT count(*) INTO n FROM audit_log WHERE record_id = ANY(${allIds});`,
    `  IF n > 0 THEN RAISE EXCEPTION 'audit_log: zostalo % záznamov vzorky', n; END IF;`,
    `  IF EXISTS (SELECT 1 FROM sync_run WHERE id = '${manifest.syncRunId}') THEN RAISE EXCEPTION 'sync_run vzorky zostal'; END IF;`,
    `  RAISE NOTICE 'Po zmazaní: žiadny riadok vzorky ani jej audit nezostal';`,
    'END;',
    '$$;',
    '',
    '\\echo Zmazané riadky a čo v tabuľke zostalo:',
    'SELECT z.tabulka, z.riadkov AS zmazane, x.zostava',
    '  FROM vzorka_zmazane z',
    '  CROSS JOIN LATERAL (SELECT (xpath(\'/row/c/text()\', query_to_xml(format(\'SELECT count(*) AS c FROM %I\', z.tabulka), false, true, \'\')))[1]::text::bigint AS zostava) x;',
    '',
    commit ? 'COMMIT;' : 'ROLLBACK;',
    commit ? "\\echo 'Vzorka zmazaná (COMMIT).'" : "\\echo 'Skúška hotová, nič sa nezmazalo (ROLLBACK).'",
    '',
  ].join('\n');
}

writeFileSync(join(outDir, 'vzorka-zmazanie-skuska.sql'), build(false));
writeFileSync(join(outDir, 'vzorka-zmazanie.sql'), build(true));
console.log(`Vygenerované: vzorka-zmazanie-skuska.sql a vzorka-zmazanie.sql (${tables.length} tabuliek, ${total} riadkov + audit_log + sync_run).`);
