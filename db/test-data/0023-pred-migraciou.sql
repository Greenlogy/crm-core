-- Kontrola pred migráciou 0023 – iba čítanie (READ ONLY), bez osobných údajov (bez EIC, mien, e-mailov).
-- 1. Bunky práv modulu Zmluvy: či sa ešte rovnajú východiskovým hodnotám z 0006 (0023 mení iba tie)
--    a či ich niekto menil (audit). 2. Lokálne zdroje a plán výkupu oproti vzorcu výkon × 4 × 365 × 0,1 / 1000.
-- 3. Kódy nových produktov (nesmú existovať). 4. Admini a tímy (príznak „schvaľuje ceny“ nastaví Peter).

BEGIN TRANSACTION READ ONLY;

-- 1. Matica práv modulu Zmluvy
WITH vychodiskove AS (
  SELECT t.id AS team_id, t.code,
         CASE WHEN t.code = 'sales_external' THEN 'iba_svoje' ELSE 'vsetko' END AS view_0006,
         CASE WHEN t.code IN ('ceo', 'nakup') THEN 'vsetko' ELSE 'nic' END     AS edit_0006,
         t.code = 'ceo'                                                        AS archive_export_0006
    FROM team t
   WHERE t.code IN ('ceo', 'sales_internal', 'sales_external', 'servis', 'nakup', 'marketing')
)
SELECT t.code AS tim,
       p.view_scope AS vidiet, p.edit_scope AS upravovat, p.can_import AS import,
       p.can_archive AS archivovat, p.can_export AS exportovat,
       CASE WHEN v.team_id IS NULL THEN 'nový tím (0023 nemení)'
            WHEN p.view_scope::text = v.view_0006 AND p.edit_scope::text = v.edit_0006 AND NOT p.can_import
             AND p.can_archive = v.archive_export_0006 AND p.can_export = v.archive_export_0006
            THEN 'východisková' ELSE 'UPRAVENÁ' END AS hodnota,
       (SELECT count(*) FROM audit_log a
         WHERE a.table_name = 'team_permission' AND a.record_id = p.id AND a.action = 'update') AS zmien_v_audite,
       (SELECT max(a.changed_at)::date FROM audit_log a
         WHERE a.table_name = 'team_permission' AND a.record_id = p.id AND a.action = 'update') AS posledna_zmena
  FROM team_permission p
  JOIN team t ON t.id = p.team_id
  LEFT JOIN vychodiskove v ON v.team_id = t.id
 WHERE p.module = 'zmluvy'
 ORDER BY t.code;

-- 2. Lokálne zdroje: plán výkupu oproti vzorcu (iba počty)
SELECT count(*) AS lokalnych_zdrojov,
       count(*) FILTER (WHERE planned_feed_in_mwh IS NULL)                                   AS plan_prazdny,
       count(*) FILTER (WHERE source_power_kw IS NULL)                                       AS bez_vykonu,
       count(*) FILTER (WHERE planned_feed_in_mwh = round(source_power_kw * 4 * 365 * 0.1 / 1000, 3)) AS plan_rovny_vzorcu,
       count(*) FILTER (WHERE planned_feed_in_mwh IS NOT NULL AND source_power_kw IS NOT NULL
                          AND planned_feed_in_mwh <> round(source_power_kw * 4 * 365 * 0.1 / 1000, 3)) AS plan_iny
  FROM oom
 WHERE source_category = 'lokalny_zdroj';

-- 3. Kódy nových produktov a stav Dodávka B2B
SELECT c.code AS kod, p.name AS existujuci_produkt, p.status
  FROM unnest(ARRAY['green_1t', 'green_2t', 'green_2t_vyk', 'green_1t_vo', 'vbattery_v', 'dodavka_b2b']) AS c(code)
  LEFT JOIN product p ON p.code = c.code
 ORDER BY 1;

SELECT count(*) AS poloziek_cennika_s_dodavka_b2b
  FROM price_list_item i JOIN product p ON p.id = i.product_id WHERE p.code = 'dodavka_b2b';

-- 4. Používatelia podľa tímu (počty), admini
SELECT t.code AS tim, count(u.id) AS pouzivatelov,
       count(u.id) FILTER (WHERE u.is_admin) AS adminov,
       count(u.id) FILTER (WHERE u.status = 'aktivny') AS aktivnych
  FROM team t LEFT JOIN app_user u ON u.team_id = t.id
 GROUP BY t.code ORDER BY t.code;

-- 5. Zmluvy a ceny (0024 predpokladá prázdne) a posledná migrácia
SELECT (SELECT count(*) FROM contract) AS zmluv, (SELECT count(*) FROM contract_price) AS cien,
       (SELECT count(*) FROM contract_purchase) AS nakupnych_cien,
       (SELECT max(version) FROM schema_migrations) AS posledna_migracia;

ROLLBACK;
