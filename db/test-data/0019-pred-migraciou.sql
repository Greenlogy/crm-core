-- Kontrola pred migráciou 0019_produkty – iba čítanie (transakcia READ ONLY), nič nemení.
-- 1. Dnešné hodnoty oom.price_regulation a ich prevod (ANO / NIE / prázdne).
-- 2. OOM so sadzbou ZSD C1 (pred skrytím; na dev sú iba testovacie OOM).

BEGIN TRANSACTION READ ONLY;

SELECT coalesce(price_regulation, '(prázdne)') AS hodnota,
       CASE WHEN lower(btrim(price_regulation)) IN ('áno', 'ano') THEN 'ANO'
            WHEN lower(btrim(price_regulation)) = 'nie' THEN 'NIE'
            ELSE 'prázdne' END AS prevod,
       count(*) AS pocet
  FROM oom
 GROUP BY 1, 2
 ORDER BY 3 DESC, 1;

SELECT o.eic, o.status, o.name
  FROM oom o
 WHERE o.pds_tariff = 'zsd_c1'
 ORDER BY o.eic;

ROLLBACK;
