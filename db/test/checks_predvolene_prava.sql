-- Predvolené práva (0039): funkcie, ktoré vytvorí vlastník databázy v budúcich migráciách, nespustí PUBLIC;
-- aplikácia crm_app ich v schéme public dostane výslovne. Spúšťa sa ako prvé v db/test/run.sh (vlastník databázy).
DO $$
BEGIN
  ASSERT EXISTS (SELECT 1 FROM pg_default_acl d
                  WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = current_user)
                    AND d.defaclnamespace = 0 AND d.defaclobjtype = 'f'
                    AND NOT EXISTS (SELECT 1 FROM aclexplode(d.defaclacl) a WHERE a.grantee = 0)),
         'funkcie budúcich migrácií nemá PUBLIC (ALTER DEFAULT PRIVILEGES z 0039)';
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    ASSERT EXISTS (SELECT 1 FROM pg_default_acl d
                    WHERE d.defaclrole = (SELECT oid FROM pg_roles WHERE rolname = current_user)
                      AND d.defaclnamespace = 'public'::regnamespace AND d.defaclobjtype = 'f'
                      AND EXISTS (SELECT 1 FROM aclexplode(d.defaclacl) a
                                   WHERE a.grantee = (SELECT oid FROM pg_roles WHERE rolname = 'crm_app') AND a.privilege_type = 'EXECUTE')),
           'funkcie budúcich migrácií v schéme public má crm_app';
  END IF;
  ASSERT NOT has_schema_privilege('public', 'public', 'USAGE'), 'schéma public nie je pre PUBLIC';
  RAISE NOTICE 'OK: predvolené práva – nové funkcie bez PUBLIC, pre crm_app áno; schéma public nie je pre PUBLIC';
END;
$$;
-- Iba pre testy (vráti sa s transakciou): pomocné funkcie testov v pg_temp musí spustiť testovacia rola crm_rls_test.
ALTER DEFAULT PRIVILEGES GRANT EXECUTE ON FUNCTIONS TO PUBLIC;
