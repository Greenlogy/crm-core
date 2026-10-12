-- Zmazanie testovacích dát modulu Odberné miesta (oom-test.sql): iba záznamy s id 7e570000-….
-- Audit zmien ostáva (nedá sa mazať); záznamy v ňom sú vymyslené.

\set ON_ERROR_STOP on
BEGIN;
SET LOCAL app.change_source = 'system';
SET LOCAL crm.oom_system = 'on';

DELETE FROM oom_contact  WHERE oom_id::text LIKE '7e570000-%' OR contact_id::text LIKE '7e570000-%';
DELETE FROM oom_device   WHERE oom_id::text LIKE '7e570000-%';
DELETE FROM oom_customer WHERE oom_id::text LIKE '7e570000-%';
DELETE FROM oom          WHERE id::text LIKE '7e570000-%';
DELETE FROM company_contact WHERE company_id::text LIKE '7e570000-%' OR contact_id::text LIKE '7e570000-%';
DELETE FROM contact WHERE id::text LIKE '7e570000-%';
DELETE FROM company WHERE id::text LIKE '7e570000-%';

COMMIT;

SELECT (SELECT count(*) FROM oom WHERE id::text LIKE '7e570000-%') AS zostava_oom,
       (SELECT count(*) FROM company WHERE id::text LIKE '7e570000-%')
     + (SELECT count(*) FROM contact WHERE id::text LIKE '7e570000-%') AS zostava_zakaznikov;
