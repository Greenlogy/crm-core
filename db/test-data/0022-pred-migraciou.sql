-- Kontrola pred migráciou 0022 – iba čítanie (READ ONLY): položky cenníkov s cenou NT pri produkte,
-- ktorý nie je dvojtarif (0022 to zakáže), a ukončené produkty v návrhoch.

BEGIN TRANSACTION READ ONLY;

SELECT l.name AS cennik, v.name AS verzia, v.status, p.name AS produkt, p.tariff_type, i.price_nt_eur_mwh
  FROM price_list_item i
  JOIN price_list_version v ON v.id = i.version_id
  JOIN price_list l ON l.id = v.price_list_id
  JOIN product p ON p.id = i.product_id
 WHERE i.price_nt_eur_mwh IS NOT NULL AND p.tariff_type <> 'dvojtarif'
 ORDER BY 1, 2, 4;

SELECT (SELECT count(*) FROM price_list_item WHERE price_nt_eur_mwh IS NOT NULL) AS poloziek_s_nt,
       (SELECT count(*) FROM price_list_item i JOIN product p ON p.id = i.product_id
         WHERE i.price_nt_eur_mwh IS NOT NULL AND p.tariff_type = 'dvojtarif') AS z_toho_dvojtarif,
       (SELECT count(*) FROM price_list_item i JOIN price_list_version v ON v.id = i.version_id
          JOIN product p ON p.id = i.product_id WHERE v.status = 'navrh' AND p.status = 'ukonceny') AS ukoncene_v_navrhoch;

ROLLBACK;
