-- Kontrola pred migráciou 0025 – iba čítanie (READ ONLY), bez osobných údajov.
-- 0025 prerába contract a contract_price: obe tabuľky musia byť prázdne. Ďalej počty dealov a nákupných cien
-- a posledná migrácia (0025 nadväzuje na 0024).

BEGIN TRANSACTION READ ONLY;

SELECT (SELECT max(version) FROM schema_migrations) AS posledna_migracia,
       (SELECT count(*) FROM contract) AS zmluv,
       (SELECT count(*) FROM contract_price) AS cien_zmluv,
       (SELECT count(*) FROM contract_purchase) AS nakupnych_cien,
       (SELECT count(*) FROM deal) AS dealov,
       (SELECT count(*) FROM deal_oom) AS dealov_s_oom;

ROLLBACK;
