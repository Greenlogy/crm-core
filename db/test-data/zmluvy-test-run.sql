-- Nočný beh (OOM aj zmluvy) k dátumu :d na Teste – iba cez db/test-data/zmluvy-test.sh (beh / nanecisto).
-- Beží ako vlastník databázy: testovací dátum (crm.today) platí iba v tomto spojení, aplikácia ho podstrčiť nevie.
-- Na konci vypíše výsledok behu a zmeny (zmluvy, ceny, upozornenia, chyby) – bez osobných údajov.
-- Premenná :end = COMMIT (beh) alebo ROLLBACK (nanecisto).

\set ON_ERROR_STOP on
\pset footer off
BEGIN;
\o /dev/null
SELECT set_config('crm.today', :'d', true);
CREATE TEMP TABLE t_before ON COMMIT DROP AS
  SELECT k.id, k.phase, contract_effective_to(k) AS end_on FROM contract k;
CREATE TEMP TABLE t_notif ON COMMIT DROP AS SELECT id FROM notification;
\o
\echo
\echo '== Nočný beh OOM'
SELECT jsonb_pretty(oom_daily_run_at(:'d'::date)) AS vysledok;
\echo '== Nočný beh zmlúv'
SELECT jsonb_pretty(contract_daily_run_at(:'d'::date)) AS vysledok;

\echo '== Zmluvy so zmenou konca alebo fázy'
SELECT k.number AS zmluva, b.phase || ' → ' || k.phase AS faza,
       coalesce(to_char(b.end_on, 'DD. MM. YYYY'), 'neurčito') || ' → ' || coalesce(to_char(contract_effective_to(k), 'DD. MM. YYYY'), 'neurčito') AS koniec
  FROM contract k JOIN t_before b ON b.id = k.id
 WHERE b.phase IS DISTINCT FROM k.phase OR b.end_on IS DISTINCT FROM contract_effective_to(k)
 ORDER BY k.number;

\echo '== Ceny zmlúv (riadky: nové / upravené / zmazané)'
SELECT k.number AS zmluva,
       count(*) FILTER (WHERE a.action = 'insert') AS nove,
       count(*) FILTER (WHERE a.action = 'update') AS upravene,
       count(*) FILTER (WHERE a.action = 'delete') AS zmazane
  FROM audit_log a
  LEFT JOIN contract_price cp ON cp.id = a.record_id
  JOIN contract k ON k.id = coalesce(cp.contract_id, (a.diff ->> 'contract_id')::uuid)
 WHERE a.table_name = 'contract_price' AND a.changed_at = now()
 GROUP BY k.number ORDER BY k.number;

\echo '== Nové upozornenia'
SELECT n.kind AS druh, n.detail AS text, count(*) AS prijemcov
  FROM notification n
 WHERE NOT EXISTS (SELECT 1 FROM t_notif t WHERE t.id = n.id)
 GROUP BY n.kind, n.detail ORDER BY n.kind, n.detail;

\echo '== Chyby behu zmlúv (EIC skrátené)'
SELECT e ->> 'krok' AS krok, k.number AS zmluva, e ->> 'kod' AS kod, e ->> 'text' AS text
  FROM job_run j CROSS JOIN LATERAL jsonb_array_elements(j.errors) e
  LEFT JOIN contract k ON k.id = (e ->> 'zmluva')::uuid
 WHERE j.started_at = now()
 ORDER BY 1, 2;

:end;
\echo
SELECT CASE WHEN :'end' = 'COMMIT' THEN 'Beh uložený.' ELSE 'Nanečisto: nič sa neuložilo (ROLLBACK).' END AS koniec;
