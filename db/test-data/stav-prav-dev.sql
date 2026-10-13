-- Iba čítanie: ktoré tímy majú v module Odberné miesta právo importovať a koľko importov je v databáze (bez osobných údajov).
BEGIN TRANSACTION READ ONLY;
SELECT t.code, t.name, t.archived_at IS NOT NULL AS archivovany, p.can_import
  FROM team_permission p JOIN team t ON t.id = p.team_id
 WHERE p.module = 'odberne_miesta' ORDER BY t.code;
SELECT count(*) AS importov FROM oom_import;
ROLLBACK;
