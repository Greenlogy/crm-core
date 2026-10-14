// Upozornenia v CRM (zvonček, 0028): 4 mesiace pred koncom zmluvy, prolongácia, zmluva bez prolongácie, Pod hranicou,
// výnimky z ceny, chyby nočného behu. Zakladá ich iba databáza (nočný beh, spúšťače); používateľ vidí iba vlastné (RLS)
// a označí ich ako prečítané. Text upozornenia je bez osobných údajov (číslo zmluvy, rok, dátum).

import { Hono } from 'hono';
import { type AppEnv, UUID } from '../types';
import { BadRequest } from '../validate';

export const notifications = new Hono<AppEnv>();

notifications.get('/notifications/count', async (c) => {
  const [row] = await c.var.sql<{ unread: number }[]>`
    SELECT count(*)::int AS unread FROM notification WHERE read_at IS NULL`;
  return c.json({ unread: row?.unread ?? 0 });
});

// Posledných 100 upozornení (neprečítané navrchu); odkaz na zmluvu iba ak ju používateľ vidí (RLS na contract)
notifications.get('/notifications', async (c) => {
  const items = await c.var.sql`
    SELECT n.id, n.kind, n.detail, n.created_at, n.read_at, n.ref_date,
           k.id AS contract_id, k.number AS contract_number, n.price_exception_id, n.job_run_id
      FROM notification n
      LEFT JOIN contract k ON k.id = n.contract_id
     ORDER BY n.read_at IS NOT NULL, n.created_at DESC
     LIMIT 100`;
  const unread = items.filter((n) => n.read_at === null).length;
  return c.json({ unread, items });
});

notifications.post('/notifications/:id/read', async (c) => {
  const id = c.req.param('id');
  if (!UUID.test(id)) throw new BadRequest('Neplatné ID.');
  await c.var.sql`UPDATE notification SET read_at = now() WHERE id = ${id} AND read_at IS NULL`;
  return c.json({ ok: true });
});

notifications.post('/notifications/read-all', async (c) => {
  const rows = await c.var.sql`UPDATE notification SET read_at = now() WHERE read_at IS NULL RETURNING id`;
  return c.json({ ok: true, read: rows.length });
});
