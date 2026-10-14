// Modul Zmluvy, F2 – import zmlúv z Office portálu a OOM z XM Trade (obrazovka 27; návrh DB časť 25).
// Jeden alebo dva súbory naraz (zostava sa rozpozná podľa hlavičiek). API súbory prečíta (contract-import-parse.ts:
// dátumy, MWh, bez dátumu narodenia a rodného čísla) a pošle riadky do databázy (contract_import_run, 0026):
// náhľad všetko skúsi a vráti späť, uloženie prijme iba tie isté súbory (odtlačky) a rovnaké počty ako náhľad.
// Súbory sa nikde neukladajú; súbor s chybami sa vytvorí až pri stiahnutí.

import { Hono } from 'hono';
import { parseContractImport, type OpRow, type XmRow } from '../contract-import-parse';
import type { Sql } from '../db';
import { type AppEnv, UUID } from '../types';
import { BadRequest, Forbidden, readBody, type Body } from '../validate';
import { type Cell, xlsxBook } from '../xlsx';

export const contractImport = new Hono<AppEnv>();

const MAX_BYTES = 10 * 1024 * 1024;
const MAX_ROWS = 5000;

type Source = 'office_portal' | 'xm_trade';
type Loaded = { source: Source; file_name: string; sheet: string; hash: string; op: OpRow[]; xm: XmRow[] };
type Missing = { source: string; kind: string; name: string };
type ContractResult = {
  number: string | null;
  op_id: string | null;
  source: Source;
  rows: number[];
  customer: string | null;
  action: 'nova' | 'zmena' | 'bez_zmeny' | 'chyba' | 'preskocene';
  contract_id?: string;
  changes: string[];
  warnings: string[];
  errors: string[];
  missing?: Missing[];
  customer_new?: boolean;
};
type OomResult = { row: number; eic: string | null; action: string; error?: string; warnings?: string[]; missing?: Missing[]; customer?: string | null; oom_id?: string };
type Counts = {
  zmluvy: { spolu: number; nova: number; zmena: number; bez_zmeny: number; chyba: number; preskocene: number; upozornenie: number };
  oom: { spolu: number; nove: number; zmena: number; bez_zmeny: number; chyba: number; upozornenie: number };
};
type DbResult = { contracts?: ContractResult[]; oom?: OomResult[]; counts: Counts; mismatch?: boolean; nothing?: boolean; import_id?: string | null };

async function canImport(sql: Sql): Promise<boolean> {
  const [r] = await sql<{ ok: boolean }[]>`SELECT crm_can_import('zmluvy') AS ok`;
  return !!r?.ok;
}
const NO_RIGHT = 'Import zmlúv nemáte povolený (Nastavenia → Tímy a práva → Zmluvy → Importovať).';

/** Súbory z tela požiadavky: { org, files: [{ file_name, data_base64 }] } – najviac jeden z každej zostavy. */
async function filesFrom(b: Body): Promise<{ org: string; files: Loaded[] }> {
  const org = typeof b.org === 'string' && UUID.test(b.org) ? b.org : '';
  if (!org) throw new BadRequest('Neplatná spoločnosť.');
  const list = Array.isArray(b.files) ? (b.files as Body[]) : [];
  if (list.length === 0 || list.length > 2) throw new BadRequest('Nahrajte export z Office portálu, z XM Trade alebo oba.');
  const files: Loaded[] = [];
  for (const f of list) {
    const name = typeof f.file_name === 'string' ? f.file_name.slice(0, 200) : 'import.xlsx';
    if (typeof f.data_base64 !== 'string' || f.data_base64 === '') throw new BadRequest('Chýba súbor.');
    if (f.data_base64.length > Math.ceil((MAX_BYTES * 4) / 3) + 4) throw new BadRequest(`${name}: súbor je väčší ako 10 MB.`);
    let bytes: Uint8Array;
    try {
      bytes = Uint8Array.from(atob(f.data_base64), (ch) => ch.charCodeAt(0));
    } catch {
      throw new BadRequest(`${name}: súbor sa nedá prečítať.`);
    }
    if (bytes.length > MAX_BYTES) throw new BadRequest(`${name}: súbor je väčší ako 10 MB.`);
    const digest = await crypto.subtle.digest('SHA-256', bytes);
    const hash = [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, '0')).join('');
    let parsed: ReturnType<typeof parseContractImport>;
    try {
      parsed = parseContractImport(bytes);
    } catch (e) {
      throw new BadRequest(`${name}: ${e instanceof Error ? e.message : 'súbor sa nedá prečítať.'}`);
    }
    if (parsed.rows.length === 0) throw new BadRequest(`${name}: v súbore nie je žiadny riadok s údajmi.`);
    if (parsed.rows.length > MAX_ROWS) throw new BadRequest(`${name}: súbor má viac ako 5 000 riadkov – rozdeľte ho.`);
    if (files.some((x) => x.source === parsed.source)) {
      throw new BadRequest(parsed.source === 'office_portal' ? 'Dva exporty z Office portálu – nahrajte jeden.' : 'Dva exporty z XM Trade – nahrajte jeden.');
    }
    files.push({
      source: parsed.source,
      file_name: name,
      sheet: parsed.sheet,
      hash,
      op: parsed.source === 'office_portal' ? parsed.rows : [],
      xm: parsed.source === 'xm_trade' ? parsed.rows : [],
    });
  }
  return { org, files };
}

const opFile = (files: Loaded[]) => files.find((f) => f.source === 'office_portal');
const xmFile = (files: Loaded[]) => files.find((f) => f.source === 'xm_trade');

async function run(sql: Sql, org: string, files: Loaded[], save: boolean, expected?: unknown): Promise<DbResult> {
  const op = opFile(files);
  const xm = xmFile(files);
  const meta = { op_file_name: op?.file_name, op_file_hash: op?.hash, xm_file_name: xm?.file_name, xm_file_hash: xm?.hash };
  const [r] = await sql<{ r: DbResult }[]>`
    SELECT contract_import_run(${org}::uuid, ${sql.json((xm?.xm ?? []) as never)}::jsonb, ${sql.json((op?.op ?? []) as never)}::jsonb,
                               ${save}, ${sql.json(meta as never)}::jsonb,
                               ${expected === undefined ? null : sql.json(expected as never)}::jsonb) AS r`;
  return r.r;
}

// Náhľad: nič sa neuloží; vráti odtlačky súborov a počty, ktoré musí potvrdiť uloženie.
contractImport.post('/contract-import/preview', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden(NO_RIGHT);
  const t0 = Date.now();
  const { org, files } = await filesFrom(await readBody(c.req));
  const t1 = Date.now();
  const res = await run(sql, org, files, false);
  return c.json({
    files: files.map((f) => ({ source: f.source, file_name: f.file_name, sheet: f.sheet, hash: f.hash, rows: f.op.length + f.xm.length })),
    counts: res.counts,
    contracts: res.contracts ?? [],
    oom: res.oom ?? [],
    timing_ms: { citanie: t1 - t0, kontrola: Date.now() - t1 },
  });
});

// Uloženie: iba tie isté súbory (odtlačky) a iba ak počty sedia s náhľadom; inak 409 a nový náhľad.
contractImport.post('/contract-import/save', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden(NO_RIGHT);
  const b = await readBody(c.req);
  const { org, files } = await filesFrom(b);
  const hashes = (b.hashes ?? {}) as Record<string, unknown>;
  if (files.some((f) => hashes[f.source] !== f.hash) || Object.keys(hashes).length !== files.length) {
    return c.json({ error: 'Súbory sa od náhľadu zmenili. Urobte nový náhľad.', code: 'hash' }, 409);
  }
  const res = await run(sql, org, files, true, b.counts);
  if (res.mismatch) {
    return c.json({ error: 'Údaje sa od náhľadu zmenili (iný počet nových, zmenených alebo chybných zmlúv). Nič sa neuložilo – urobte nový náhľad.', code: 'mismatch', counts: res.counts }, 409);
  }
  if (res.nothing) return c.json({ error: 'Nie je čo uložiť – žiadna nová ani zmenená zmluva či OOM.', code: 'nothing' }, 409);
  return c.json({ import_id: res.import_id, counts: res.counts });
});

// Chybné riadky ako .xlsx (vytvorí sa iba pri stiahnutí): zmluvy a OOM s chybou, číslo riadku a text chyby.
// Bez údajov osôb – stačí číslo riadku v pôvodnom súbore.
contractImport.post('/contract-import/errors', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden(NO_RIGHT);
  const { org, files } = await filesFrom(await readBody(c.req));
  const res = await run(sql, org, files, false);
  const contracts: Cell[][] = (res.contracts ?? [])
    .filter((x) => x.action === 'chyba')
    .map((x) => [x.source === 'xm_trade' ? 'XM Trade' : 'Office portal', x.rows.join(', '), x.number, x.errors.join(' ')]);
  const ooms: Cell[][] = (res.oom ?? []).filter((x) => x.action === 'chyba').map((x) => ['XM Trade', x.row, x.eic, x.error ?? '']);
  const data = xlsxBook([
    { name: 'Zmluvy', header: ['Súbor', 'Riadky', 'Číslo zmluvy', 'Chyba'], rows: contracts },
    { name: 'OOM', header: ['Súbor', 'Riadok', 'EIC', 'Chyba'], rows: ooms },
  ]);
  return new Response(data, {
    headers: {
      'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'Content-Disposition': 'attachment; filename="zmluvy-import-chyby.xlsx"',
      'Cache-Control': 'no-store',
    },
  });
});

// História importov (posledných 30): kto, kedy, súbory a počty
contractImport.get('/contract-import/history', async (c) => {
  const sql = c.var.sql;
  if (!(await canImport(sql))) throw new Forbidden(NO_RIGHT);
  const items = await sql`
    SELECT i.id, i.created_at, i.op_file_name, i.xm_file_name, i.counts, u.name AS user_name
      FROM contract_import i
      LEFT JOIN app_user u ON u.id = i.user_id
     ORDER BY i.created_at DESC
     LIMIT 30`;
  return c.json({ items });
});
