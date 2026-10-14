-- Kontrola po migrácii 0023 – iba čítanie (READ ONLY), bez osobných údajov.
-- Matica práv modulu Zmluvy, cenové parametre, počty prekladov, lokálne zdroje (plán a príznak ručne zadaný).

BEGIN TRANSACTION READ ONLY;

SELECT (SELECT max(version) FROM schema_migrations) AS posledna_migracia;

SELECT t.code AS tim, p.view_scope AS vidiet, p.edit_scope AS upravovat, p.can_import AS import,
       p.can_see_company_margin AS marza_firmy, p.can_archive AS archivovat, p.can_export AS exportovat
  FROM team_permission p JOIN team t ON t.id = p.team_id
 WHERE p.module = 'zmluvy'
 ORDER BY t.code;

SELECT code AS parameter, delivery_year AS rok, valid_from AS plati_od, value AS hodnota
  FROM price_parameter ORDER BY code, delivery_year, valid_from;

SELECT source AS zdroj, kind AS druh, count(*) AS prekladov, count(*) FILTER (WHERE is_system) AS systemovych
  FROM import_alias GROUP BY 1, 2 ORDER BY 1, 2;

SELECT count(*) AS lokalnych_zdrojov,
       count(*) FILTER (WHERE planned_feed_in_manual) AS plan_rucne,
       count(*) FILTER (WHERE NOT planned_feed_in_manual
                          AND planned_feed_in_mwh IS NOT DISTINCT FROM oom_feed_in_formula(source_power_kw)) AS plan_vypocitany
  FROM oom WHERE source_category = 'lokalny_zdroj';

SELECT count(*) FILTER (WHERE approves_prices) AS schvaluju_ceny,
       count(*) FILTER (WHERE seller_type IS NOT NULL) AS s_typom_predajcu
  FROM app_user;

ROLLBACK;
