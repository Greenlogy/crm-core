-- Zmazanie testovacích zmlúv nočného behu (zmluvy-test.sql): iba záznamy s id 7e570000-0000-4000-9000-…
-- (zmluvy TEST-NB-…, ich OOM a zákazníci). S nimi zmiznú ich ceny, príznaky a upozornenia. Nič iné sa nemaže.
-- Cenník a produkt „TEST – nočný beh“ ostávajú (schválená verzia cenníka sa nemaže); audit zmien ostáva.
-- Ak by na testovacích zákazníkoch alebo OOM bolo niečo iné (napr. zmluva z importu), skript skončí chybou
-- a celý sa vráti (nič sa nezmaže).

\set ON_ERROR_STOP on
BEGIN;
SET LOCAL app.change_source = 'system';
SET LOCAL crm.oom_system = 'on';

DELETE FROM contract WHERE id::text LIKE '7e570000-0000-4000-9000-%';
DELETE FROM oom_customer WHERE oom_id::text LIKE '7e570000-0000-4000-9000-%';
DELETE FROM oom WHERE id::text LIKE '7e570000-0000-4000-9000-%';
DELETE FROM contact WHERE id::text LIKE '7e570000-0000-4000-9000-%';
DELETE FROM company WHERE id::text LIKE '7e570000-0000-4000-9000-%';

COMMIT;

SELECT (SELECT count(*) FROM contract WHERE id::text LIKE '7e570000-0000-4000-9000-%') AS zostava_zmluv,
       (SELECT count(*) FROM oom WHERE id::text LIKE '7e570000-0000-4000-9000-%') AS zostava_oom,
       (SELECT count(*) FROM company WHERE id::text LIKE '7e570000-0000-4000-9000-%')
     + (SELECT count(*) FROM contact WHERE id::text LIKE '7e570000-0000-4000-9000-%') AS zostava_zakaznikov;
