-- Zmazanie testovacích dát modulu Odberné miesta (oom-test.sql): záznamy s id 7e570000-… a OOM ich zákazníkov
-- (aj založené pri skúškach, napr. importom) a aktivity (poznámky) pri nich. Dealy a zmluvy nemaže – ak by
-- nejaké na testovacích zákazníkoch boli, skript skončí chybou a celý sa vráti (nič sa nezmaže).
-- Audit zmien ostáva (nedá sa mazať); záznamy v ňom sú vymyslené.

\set ON_ERROR_STOP on
BEGIN;
SET LOCAL app.change_source = 'system';
SET LOCAL crm.oom_system = 'on';

-- OOM testovacích dát + OOM, ktoré vznikli pri skúškach (import, nové OOM) u testovacích zákazníkov
CREATE TEMP TABLE t_oom ON COMMIT DROP AS
  SELECT id FROM oom WHERE id::text LIKE '7e570000-%'
  UNION SELECT oom_id FROM oom_customer WHERE company_id::text LIKE '7e570000-%' OR person_id::text LIKE '7e570000-%';

-- aktivity testovacích zákazníkov a ich OOM (napr. poznámky z časovej osi pri skúšaní na Teste)
DELETE FROM activity WHERE oom_id IN (SELECT id FROM t_oom)
                        OR company_id::text LIKE '7e570000-%' OR contact_id::text LIKE '7e570000-%';
DELETE FROM oom_planned_change WHERE company_id::text LIKE '7e570000-%' OR person_id::text LIKE '7e570000-%';
DELETE FROM oom_contact  WHERE oom_id IN (SELECT id FROM t_oom) OR contact_id::text LIKE '7e570000-%';
DELETE FROM oom_device   WHERE oom_id IN (SELECT id FROM t_oom);
DELETE FROM oom_planned_change WHERE oom_id IN (SELECT id FROM t_oom);
DELETE FROM oom_customer WHERE oom_id IN (SELECT id FROM t_oom);
DELETE FROM oom          WHERE id IN (SELECT id FROM t_oom);
DELETE FROM company_contact WHERE company_id::text LIKE '7e570000-%' OR contact_id::text LIKE '7e570000-%';
DELETE FROM contact WHERE id::text LIKE '7e570000-%';
DELETE FROM company WHERE id::text LIKE '7e570000-%';

COMMIT;

SELECT (SELECT count(*) FROM oom WHERE id::text LIKE '7e570000-%') AS zostava_oom,
       (SELECT count(*) FROM company WHERE id::text LIKE '7e570000-%')
     + (SELECT count(*) FROM contact WHERE id::text LIKE '7e570000-%') AS zostava_zakaznikov,
       (SELECT count(*) FROM activity WHERE company_id::text LIKE '7e570000-%' OR contact_id::text LIKE '7e570000-%') AS zostava_aktivit;
