-- migrate:up

-- 0057_spot_priemer_od_zaciatku_roka – Peter 17. 10. 2026 (variant a): priemerná SPOT cena na Domove = priemer od 1. 1.
-- aktuálneho roka po dnes (Montel spotAvgYTD), nie za posledných 365 dní (spotAvg365). Stĺpec sa premenuje, aby názov
-- nezavádzal; funkcie, ktoré ho používajú, sa prepíšu. Na dev zatiaľ nie je uložený žiadny priemer (overené 17. 10.).

ALTER TABLE spot_average_daily RENAME COLUMN avg_12m_eur_mwh TO avg_ytd_eur_mwh;
COMMENT ON TABLE spot_average_daily IS 'priemerná SPOT cena OKTE od 1. 1. aktuálneho roka po deň (Montel spotAvgYTD) – 0047, 0057';

CREATE OR REPLACE FUNCTION market_price_daily_run(p_quotes jsonb, p_spot_avg numeric, p_errors jsonb DEFAULT '[]'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org   uuid := crm_default_org();
  v_today date := crm_today();
  v_run   uuid;
  v_n     integer := 0;
  v_spot  integer := 0;
BEGIN
  PERFORM crm_background_only();
  INSERT INTO job_run (job, run_date) VALUES ('ceny', v_today) RETURNING id INTO v_run;
  v_n := market_price_import(v_org, v_today, coalesce(p_quotes, '[]'), 'cockpit', false);
  IF p_spot_avg IS NOT NULL AND p_spot_avg BETWEEN 0 AND 10000
     AND NOT EXISTS (SELECT 1 FROM spot_average_daily WHERE org_id = v_org AND on_date = v_today AND source = 'rucne') THEN
    INSERT INTO spot_average_daily (org_id, on_date, avg_ytd_eur_mwh, source) VALUES (v_org, v_today, round(p_spot_avg, 4), 'cockpit')
    ON CONFLICT (org_id, on_date) DO UPDATE SET avg_ytd_eur_mwh = excluded.avg_ytd_eur_mwh
     WHERE spot_average_daily.avg_ytd_eur_mwh IS DISTINCT FROM excluded.avg_ytd_eur_mwh;
    v_spot := 1;
  END IF;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('ceny', v_n, 'spot', v_spot),
                     errors = CASE WHEN jsonb_typeof(p_errors) = 'array' THEN p_errors ELSE '[]' END
   WHERE id = v_run;
  IF jsonb_array_length(CASE WHEN jsonb_typeof(p_errors) = 'array' THEN p_errors ELSE '[]' END) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'nocny_beh_chyba', NULL, NULL, v_run, v_today,
                             'Načítanie cien z Montelu skončilo s chybou');
  END IF;
  RETURN jsonb_build_object('ceny', v_n, 'spot', v_spot);
END;
$$;

DROP FUNCTION spot_average_on(uuid, date);
CREATE FUNCTION spot_average_on(p_org uuid, p_on date) RETURNS TABLE(on_date date, avg_ytd_eur_mwh numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT s.on_date, s.avg_ytd_eur_mwh FROM spot_average_daily s
   WHERE crm_session_ok() AND p_org = ANY (crm_user_orgs()) AND s.org_id = p_org AND s.on_date BETWEEN p_on - 7 AND p_on
   ORDER BY s.on_date DESC LIMIT 1
$$;

-- migrate:down

DROP FUNCTION spot_average_on(uuid, date);
ALTER TABLE spot_average_daily RENAME COLUMN avg_ytd_eur_mwh TO avg_12m_eur_mwh;
COMMENT ON TABLE spot_average_daily IS 'priemerná SPOT cena OKTE za posledných 12 mesiacov (Montel spotAvg365) ku dňu – 0047';

CREATE OR REPLACE FUNCTION market_price_daily_run(p_quotes jsonb, p_spot_avg numeric, p_errors jsonb DEFAULT '[]'::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org   uuid := crm_default_org();
  v_today date := crm_today();
  v_run   uuid;
  v_n     integer := 0;
  v_spot  integer := 0;
BEGIN
  PERFORM crm_background_only();
  INSERT INTO job_run (job, run_date) VALUES ('ceny', v_today) RETURNING id INTO v_run;
  v_n := market_price_import(v_org, v_today, coalesce(p_quotes, '[]'), 'cockpit', false);
  IF p_spot_avg IS NOT NULL AND p_spot_avg BETWEEN 0 AND 10000
     AND NOT EXISTS (SELECT 1 FROM spot_average_daily WHERE org_id = v_org AND on_date = v_today AND source = 'rucne') THEN
    INSERT INTO spot_average_daily (org_id, on_date, avg_12m_eur_mwh, source) VALUES (v_org, v_today, round(p_spot_avg, 4), 'cockpit')
    ON CONFLICT (org_id, on_date) DO UPDATE SET avg_12m_eur_mwh = excluded.avg_12m_eur_mwh
     WHERE spot_average_daily.avg_12m_eur_mwh IS DISTINCT FROM excluded.avg_12m_eur_mwh;
    v_spot := 1;
  END IF;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('ceny', v_n, 'spot', v_spot),
                     errors = CASE WHEN jsonb_typeof(p_errors) = 'array' THEN p_errors ELSE '[]' END
   WHERE id = v_run;
  IF jsonb_array_length(CASE WHEN jsonb_typeof(p_errors) = 'array' THEN p_errors ELSE '[]' END) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'nocny_beh_chyba', NULL, NULL, v_run, v_today,
                             'Načítanie cien z Montelu skončilo s chybou');
  END IF;
  RETURN jsonb_build_object('ceny', v_n, 'spot', v_spot);
END;
$$;

CREATE FUNCTION spot_average_on(p_org uuid, p_on date) RETURNS TABLE(on_date date, avg_12m_eur_mwh numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT s.on_date, s.avg_12m_eur_mwh FROM spot_average_daily s
   WHERE crm_session_ok() AND p_org = ANY (crm_user_orgs()) AND s.org_id = p_org AND s.on_date BETWEEN p_on - 7 AND p_on
   ORDER BY s.on_date DESC LIMIT 1
$$;
