// Nastavenia – Spoločnosť (dizajn 11): údaje do dokumentov, logo, bankové účty, pracovný čas, voľné dni.
// Pripája sa pod /api/settings (kontrola admina je v settings.ts).

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest, bool, readBody, str, type Body } from '../validate';

export const orgSettings = new Hono<AppEnv>();

const id = (v: string) => {
  if (!UUID.test(v)) throw new BadRequest('Neplatné ID.');
  return v;
};

// Údaje do dokumentov, ktoré smie meniť admin (krajina, mena a stav spoločnosti sú jadro).
const ORG_FIELDS = [
  ['legal_name', 'Obchodné meno', 200],
  ['reg_no', 'IČO / OIB', 20],
  ['tax_no', 'DIČ', 20],
  ['vat_no', 'IČ DPH', 20],
  ['address', 'Sídlo', 300],
  ['registry_entry', 'Zápis v obchodnom registri', 300],
  ['statutory', 'Štatutári', 500],
  ['support_phone', 'Zákaznícka linka', 40],
  ['email', 'E-mail', 200],
  ['web', 'Web', 200],
  ['regulator_license', 'Povolenie regulátora', 100],
] as const;

orgSettings.get('/orgs', async (c) => {
  const rows = await c.var.sql`
    SELECT o.id, o.code, o.country, o.currency, o.status, o.is_default, o.timezone, o.legal_name, o.reg_no, o.tax_no,
           o.vat_no, o.address, o.registry_entry, o.statutory, o.support_phone, o.email, o.web, o.regulator_license,
           o.logo_updated_at
      FROM org o
     ORDER BY o.is_default DESC, o.status, o.legal_name`;
  return c.json({ items: rows });
});

// Detail spoločnosti: bankové účty, pracovný čas, voľné dni (štátne sviatky od tohto roka).
orgSettings.get('/orgs/:id/detail', async (c) => {
  const orgId = id(c.req.param('id'));
  const sql = c.var.sql;
  const accounts = await sql`
    SELECT id, iban, bic, bank_name, to_jsonb(purposes) AS purposes, is_primary, archived_at
      FROM org_bank_account WHERE org_id = ${orgId}
     ORDER BY archived_at IS NOT NULL, is_primary DESC, created_at`;
  const hours = await sql`
    SELECT weekday, to_char(work_from, 'HH24:MI') AS work_from, to_char(work_to, 'HH24:MI') AS work_to
      FROM org_work_hours WHERE org_id = ${orgId} ORDER BY weekday`;
  const daysOff = await sql`
    SELECT id, date, kind, name FROM org_day_off
     WHERE org_id = ${orgId} AND date >= make_date(extract(year FROM current_date)::int, 1, 1)
     ORDER BY date`;
  const [cal] = await sql`
    SELECT min(date) AS calendar_from, max(date) AS calendar_to FROM business_calendar WHERE org_id = ${orgId}`;
  return c.json({ accounts, hours, days_off: daysOff, ...cal });
});

orgSettings.patch('/orgs/:id', async (c) => {
  const orgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const values: Record<string, string | null> = {};
  for (const [key, label, max] of ORG_FIELDS) {
    const v = str(b, key, label, { max, optional: true });
    if (v !== undefined) values[key] = v === '' ? null : v;
  }
  if (values.legal_name === null) throw new BadRequest('Chýba: Obchodné meno.');
  if (Object.keys(values).length === 0) return c.json({ ok: true });
  await c.var.sql`UPDATE org SET ${c.var.sql(values)} WHERE id = ${orgId}`;
  return c.json({ ok: true });
});

// --- Logo (SVG alebo PNG do 512 kB) ---

const LOGO_MIME = new Set(['image/svg+xml', 'image/png']);

orgSettings.get('/orgs/:id/logo', async (c) => {
  const orgId = id(c.req.param('id'));
  const [logo] = await c.var.sql<{ mime: string; data: Uint8Array }[]>`SELECT mime, data FROM org_logo WHERE org_id = ${orgId}`;
  if (!logo) return c.json({ error: 'Logo nie je nahraté.' }, 404);
  return new Response(logo.data, {
    headers: {
      'Content-Type': logo.mime,
      'Cache-Control': 'no-store',
      'X-Content-Type-Options': 'nosniff',
      // SVG môže obsahovať skript: pri priamom otvorení sa nesmie spustiť nič.
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:",
    },
  });
});

orgSettings.post('/orgs/:id/logo', async (c) => {
  const orgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const mime = str(b, 'mime', 'Typ súboru', { max: 40 })!;
  if (!LOGO_MIME.has(mime)) throw new BadRequest('Logo musí byť SVG alebo PNG.');
  const base64 = str(b, 'data', 'Súbor', { max: 800_000 })!;
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(base64), (ch) => ch.charCodeAt(0));
  } catch {
    throw new BadRequest('Súbor sa nedá prečítať.');
  }
  if (bytes.length > 524_288) throw new BadRequest('Logo môže mať najviac 512 kB.');
  const sql = c.var.sql;
  await sql`
    INSERT INTO org_logo (org_id, mime, data) VALUES (${orgId}, ${mime}, ${bytes})
    ON CONFLICT (org_id) DO UPDATE SET mime = excluded.mime, data = excluded.data`;
  await sql`UPDATE org SET logo_updated_at = now() WHERE id = ${orgId}`;
  return c.json({ ok: true });
});

orgSettings.delete('/orgs/:id/logo', async (c) => {
  const orgId = id(c.req.param('id'));
  await c.var.sql`DELETE FROM org_logo WHERE org_id = ${orgId}`;
  await c.var.sql`UPDATE org SET logo_updated_at = NULL WHERE id = ${orgId}`;
  return c.json({ ok: true });
});

// --- Bankové účty ---

const PURPOSES = ['faktury', 'zalohy', 'vykup'];

function purposes(b: Body): string[] | undefined {
  const v = b.purposes;
  if (v === undefined) return undefined;
  if (!Array.isArray(v) || v.some((x) => typeof x !== 'string' || !PURPOSES.includes(x))) {
    throw new BadRequest('Účel účtu: neplatná hodnota.');
  }
  return [...new Set(v as string[])];
}

orgSettings.post('/orgs/:id/bank-accounts', async (c) => {
  const orgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const iban = str(b, 'iban', 'IBAN', { max: 50 })!.replace(/\s/g, '').toUpperCase();
  const bic = str(b, 'bic', 'BIC', { max: 20, optional: true }) || null;
  const bankName = str(b, 'bank_name', 'Banka', { max: 100, optional: true }) || null;
  const p = purposes(b) ?? [];
  const primary = bool(b, 'is_primary', 'Hlavný') ?? false;
  const sql = c.var.sql;
  if (primary) await sql`UPDATE org_bank_account SET is_primary = false WHERE org_id = ${orgId} AND is_primary`;
  const [row] = await sql<{ id: string }[]>`
    INSERT INTO org_bank_account (org_id, iban, bic, bank_name, purposes, is_primary)
    VALUES (${orgId}, ${iban}, ${bic}, ${bankName},
            ARRAY(SELECT jsonb_array_elements_text(${sql.json(p)}::jsonb)::bank_account_purpose), ${primary})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

orgSettings.patch('/bank-accounts/:id', async (c) => {
  const accId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const bic = str(b, 'bic', 'BIC', { max: 20, optional: true });
  const bankName = str(b, 'bank_name', 'Banka', { max: 100, optional: true });
  const p = purposes(b);
  const primary = bool(b, 'is_primary', 'Hlavný');
  const archived = bool(b, 'archived', 'Archivovať');
  const sql = c.var.sql;
  if (primary || archived) {
    // hlavný môže byť iba jeden nearchivovaný účet
    await sql`UPDATE org_bank_account SET is_primary = false
               WHERE org_id = (SELECT org_id FROM org_bank_account WHERE id = ${accId}) AND is_primary
                 AND (${primary ?? false} OR id = ${accId})`;
  }
  await sql`
    UPDATE org_bank_account
       SET bic = CASE WHEN ${bic !== undefined} THEN nullif(${bic ?? ''}, '') ELSE bic END,
           bank_name = CASE WHEN ${bankName !== undefined} THEN nullif(${bankName ?? ''}, '') ELSE bank_name END,
           purposes = CASE WHEN ${p !== undefined}
                           THEN ARRAY(SELECT jsonb_array_elements_text(${sql.json(p ?? [])}::jsonb)::bank_account_purpose)
                           ELSE purposes END,
           is_primary = CASE WHEN ${archived ?? false} THEN false ELSE coalesce(${primary ?? null}::boolean, is_primary) END,
           archived_at = CASE WHEN ${archived === undefined} THEN archived_at
                              WHEN ${archived ?? false} THEN coalesce(archived_at, now()) ELSE NULL END
     WHERE id = ${accId}`;
  return c.json({ ok: true });
});

// --- Pracovný čas: celý týždeň naraz { days: [{ weekday: 1–7, from: 'HH:MM', to: 'HH:MM' }] } ---

const TIME = /^([01]\d|2[0-3]):[0-5]\d$/;

orgSettings.patch('/orgs/:id/work-hours', async (c) => {
  const orgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  if (!Array.isArray(b.days)) throw new BadRequest('Chýba pracovný čas.');
  const days = (b.days as Body[]).map((d) => {
    const weekday = d.weekday;
    if (typeof weekday !== 'number' || !Number.isInteger(weekday) || weekday < 1 || weekday > 7) {
      throw new BadRequest('Deň v týždni: neplatná hodnota.');
    }
    const from = str(d, 'from', 'Od')!;
    const to = str(d, 'to', 'Do')!;
    if (!TIME.test(from) || !TIME.test(to)) throw new BadRequest('Čas zadaj ako HH:MM.');
    if (to <= from) throw new BadRequest('Koniec pracovného času musí byť po začiatku.');
    return { weekday, from, to };
  });
  if (new Set(days.map((d) => d.weekday)).size !== days.length) throw new BadRequest('Deň v týždni je zadaný dvakrát.');
  const sql = c.var.sql;
  await sql`
    DELETE FROM org_work_hours
     WHERE org_id = ${orgId}
       AND weekday NOT IN (SELECT (x ->> 'weekday')::int FROM jsonb_array_elements(${sql.json(days)}::jsonb) x)`;
  await sql`
    INSERT INTO org_work_hours (org_id, weekday, work_from, work_to)
    SELECT ${orgId}, (x ->> 'weekday')::smallint, (x ->> 'from')::time, (x ->> 'to')::time
      FROM jsonb_array_elements(${sql.json(days)}::jsonb) x
    ON CONFLICT (org_id, weekday) DO UPDATE SET work_from = excluded.work_from, work_to = excluded.work_to`;
  return c.json({ ok: true });
});

// --- Firemné voľno (štátne sviatky mení iba migrácia) ---

orgSettings.post('/orgs/:id/days-off', async (c) => {
  const orgId = id(c.req.param('id'));
  const b = await readBody(c.req);
  const date = str(b, 'date', 'Dátum', { max: 10 })!;
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new BadRequest('Dátum zadaj ako RRRR-MM-DD.');
  const name = str(b, 'name', 'Názov', { max: 100 })!;
  const [row] = await c.var.sql<{ id: string }[]>`
    INSERT INTO org_day_off (org_id, date, kind, name) VALUES (${orgId}, ${date}::date, 'firemne_volno', ${name})
    RETURNING id`;
  return c.json({ id: row.id }, 201);
});

orgSettings.delete('/days-off/:id', async (c) => {
  const dayId = id(c.req.param('id'));
  const rows = await c.var.sql`DELETE FROM org_day_off WHERE id = ${dayId} AND kind = 'firemne_volno' RETURNING id`;
  if (rows.length === 0) return c.json({ error: 'Voľný deň neexistuje alebo je to štátny sviatok.' }, 400);
  return c.json({ ok: true });
});
