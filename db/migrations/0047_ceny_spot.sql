-- migrate:up

-- 0047_ceny_spot – modul 5, fáza F6, krok 1 (návrh DB časti 7, 36.1; Peter 16. 10.): ceny z Workera Montel.
-- - BL a PL rokov dodávky z /forwards/quotes (denne po pracovných dňoch 7:00 a 13:00) a história od 1. 1. 2026
--   z /forwards/ohlc/history → market_price_daily (zdroj cockpit / historia). Ručne zadaná cena dňa sa neprepíše;
--   odhad portfólia a očakávaná SPOT pre FVE zadané v ten deň sa prenesú do nového záznamu.
-- - 12-mesačný priemer SPOT (spotAvg365) → spot_average_daily.
-- - Ukladajú sa iba tieto hodnoty, nie odpovede Montelu. Surové BL, PL, históriu a SPOT priemer v tabuľkách vidí iba admin
--   a kto vidí maržu firmy (RLS); obchodníci dostanú iba cenu pre obchodníka (trader_price) a SPOT priemer cez funkcie.
-- - Beh sa zapíše do denníka (job_run, job 'ceny').

CREATE TABLE spot_average_daily (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  on_date         date NOT NULL,
  avg_12m_eur_mwh numeric(12,4) NOT NULL,
  source          text NOT NULL DEFAULT 'cockpit' CHECK (source IN ('cockpit', 'rucne')),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, on_date)
);
COMMENT ON TABLE spot_average_daily IS 'priemerná SPOT cena OKTE za posledných 12 mesiacov (Montel spotAvg365) ku dňu – 0047';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON spot_average_daily FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON spot_average_daily FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE POLICY spot_average_read ON spot_average_daily FOR SELECT
  USING (crm_session_ok() AND org_id = ANY (crm_user_orgs()) AND (crm_is_admin() OR crm_can_see_margin()));
ALTER TABLE spot_average_daily ENABLE ROW LEVEL SECURITY;

ALTER TABLE job_run DROP CONSTRAINT job_run_job_check;
ALTER TABLE job_run ADD CONSTRAINT job_run_job_check CHECK (job IN ('zmluvy', 'obchody', 'ceny'));

CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_correction', true) = 'on' THEN
    RETURN NEW;                                   -- označenie opravy z tejto funkcie (nižšie)
  END IF;
  -- 0047: načítanie z Montelu (market_price_import) – funkcia vlastníka označí zdroj a zachová ručné hodnoty dňa
  IF TG_OP = 'INSERT' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_import', true) = 'on' THEN
    RETURN NEW;
  END IF;
  IF crm_owner_session() THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM set_config('crm.market_price_correction', 'on', true);
      UPDATE market_price_daily SET corrected_at = now(), corrected_by = NULL
       WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
      PERFORM set_config('crm.market_price_correction', '', true);
    END IF;
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú – chybný záznam oprav novým.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Trhová cena sa nemení – chybný záznam oprav novým (tlačidlo Opraviť).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  NEW.corrected_at := NULL;
  NEW.corrected_by := NULL;
  PERFORM set_config('crm.market_price_correction', 'on', true);
  UPDATE market_price_daily SET corrected_at = now(), corrected_by = NEW.changed_by
   WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
  PERFORM set_config('crm.market_price_correction', '', true);
  RETURN NEW;
END;
$$;

-- Strážca beží s právami vlastníka (current_user je v ňom vždy vlastník), preto príznaky importu a opravy overí
-- tento spúšťač bez SECURITY DEFINER pred ním: príznak smie nastaviť iba kód databázy (funkcia vlastníka), nie aplikácia.
CREATE FUNCTION market_price_flag_check() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF (current_setting('crm.market_price_import', true) = 'on' OR current_setting('crm.market_price_correction', true) = 'on')
     AND NOT crm_internal_call() THEN
    RAISE EXCEPTION 'Trhové ceny z Montelu zapisuje iba denný beh alebo načítanie histórie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_flag_check BEFORE INSERT OR UPDATE ON market_price_daily FOR EACH ROW EXECUTE FUNCTION market_price_flag_check();

-- Zápis cien dňa z Montelu: p_rows [{year, bl, pl}] (iba roky dodávky s oboma hodnotami). p_keep_existing = true (história):
-- deň, ktorý už má cenu, sa nemení. Inak: ručne zadaná BL/PL dňa sa neprepíše; zhodná hodnota sa nezapíše znova;
-- odhad portfólia a SPOT pre FVE z platného záznamu dňa sa prenesú. Vráti počet zapísaných riadkov.
CREATE FUNCTION market_price_import(p_org uuid, p_on date, p_rows jsonb, p_source text, p_keep_existing boolean) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r     jsonb;
  cur   market_price_daily;
  v_y   smallint;
  v_bl  numeric;
  v_pl  numeric;
  v_n   integer := 0;
BEGIN
  IF p_source NOT IN ('cockpit', 'historia') OR jsonb_typeof(coalesce(p_rows, '[]')) <> 'array' OR p_on IS NULL THEN
    RAISE EXCEPTION 'Neplatné údaje cien.' USING ERRCODE = 'check_violation';
  END IF;
  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_y := (r->>'year')::smallint;
    v_bl := round((r->>'bl')::numeric, 4);
    v_pl := round((r->>'pl')::numeric, 4);
    IF v_y IS NULL OR v_y NOT BETWEEN 2000 AND 2100 OR v_bl IS NULL OR v_pl IS NULL OR v_bl < 0 OR v_pl < 0 OR v_bl > 10000 OR v_pl > 10000 THEN
      CONTINUE;
    END IF;
    SELECT * INTO cur FROM market_price_daily
     WHERE org_id = p_org AND on_date = p_on AND delivery_year = v_y AND corrected_at IS NULL;
    IF cur.id IS NOT NULL AND (p_keep_existing OR (cur.source = 'rucne' AND cur.bl_eur_mwh IS NOT NULL)
                               OR (cur.bl_eur_mwh = v_bl AND cur.pl_eur_mwh = v_pl)) THEN
      CONTINUE;
    END IF;
    IF cur.id IS NOT NULL THEN
      PERFORM set_config('crm.market_price_correction', 'on', true);
      UPDATE market_price_daily SET corrected_at = now(), corrected_by = NULL WHERE id = cur.id;
      PERFORM set_config('crm.market_price_correction', '', true);
    END IF;
    PERFORM set_config('crm.market_price_import', 'on', true);
    INSERT INTO market_price_daily (org_id, on_date, delivery_year, bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh, source)
    VALUES (p_org, p_on, v_y, v_bl, v_pl, cur.portfolio_eur_mwh, cur.spot_fve_eur_mwh, p_source);
    PERFORM set_config('crm.market_price_import', '', true);
    v_n := v_n + 1;
  END LOOP;
  RETURN v_n;
END;
$$;

-- Denný beh cien (Cron, bez prihláseného používateľa): BL / PL z /forwards/quotes a SPOT priemer z /spot/aggregates
-- (kód z odpovedí vyberie iba tieto hodnoty). Zapíše sa do denníka behov.
CREATE FUNCTION market_price_daily_run(p_quotes jsonb, p_spot_avg numeric, p_errors jsonb DEFAULT '[]') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- História cien od 1. 1. 2026 (admin, jednorazovo): p_days [{on_date, rows: [{year, bl, pl}]}]; dni s cenou sa nemenia
CREATE FUNCTION market_price_history_import(p_days jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     jsonb;
  v_org uuid := crm_default_org();
  v_n   integer := 0;
  v_d   integer := 0;
BEGIN
  IF crm_active_user_id() IS NULL OR NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Históriu cien načítava admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_typeof(coalesce(p_days, '[]')) <> 'array' OR jsonb_array_length(coalesce(p_days, '[]')) > 2000 THEN
    RAISE EXCEPTION 'Neplatná história cien.' USING ERRCODE = 'check_violation';
  END IF;
  FOR d IN SELECT * FROM jsonb_array_elements(p_days) LOOP
    IF (d->>'on_date')::date BETWEEN '2026-01-01' AND crm_today() THEN
      v_n := v_n + market_price_import(v_org, (d->>'on_date')::date, d->'rows', 'historia', true);
      v_d := v_d + 1;
    END IF;
  END LOOP;
  RETURN jsonb_build_object('dni', v_d, 'riadky', v_n);
END;
$$;

-- SPOT priemer za 12 mesiacov ku dňu (posledný do 7 dní dozadu) – pre dlaždicu Domova (vidí každý prihlásený)
CREATE FUNCTION spot_average_on(p_org uuid, p_on date) RETURNS TABLE (on_date date, avg_12m_eur_mwh numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT s.on_date, s.avg_12m_eur_mwh FROM spot_average_daily s
   WHERE crm_session_ok() AND p_org = ANY (crm_user_orgs()) AND s.org_id = p_org AND s.on_date BETWEEN p_on - 7 AND p_on
   ORDER BY s.on_date DESC LIMIT 1
$$;

REVOKE EXECUTE ON FUNCTION market_price_import(uuid, date, jsonb, text, boolean) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION market_price_import(uuid, date, jsonb, text, boolean) FROM crm_app;
  END IF;
END;
$$;

-- migrate:down

DROP FUNCTION spot_average_on(uuid, date);
DROP FUNCTION market_price_history_import(jsonb);
DROP FUNCTION market_price_daily_run(jsonb, numeric, jsonb);
DROP FUNCTION market_price_import(uuid, date, jsonb, text, boolean);
DROP TRIGGER trg_flag_check ON market_price_daily;
DROP FUNCTION market_price_flag_check();
CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'market_price_daily'::regclass)
     AND current_setting('crm.market_price_correction', true) = 'on' THEN
    RETURN NEW;                                   -- označenie opravy z tejto funkcie (nižšie)
  END IF;
  IF crm_owner_session() THEN
    IF TG_OP = 'INSERT' THEN
      PERFORM set_config('crm.market_price_correction', 'on', true);
      UPDATE market_price_daily SET corrected_at = now(), corrected_by = NULL
       WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
      PERFORM set_config('crm.market_price_correction', '', true);
    END IF;
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú – chybný záznam oprav novým.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Trhová cena sa nemení – chybný záznam oprav novým (tlačidlo Opraviť).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  NEW.corrected_at := NULL;
  NEW.corrected_by := NULL;
  PERFORM set_config('crm.market_price_correction', 'on', true);
  UPDATE market_price_daily SET corrected_at = now(), corrected_by = NEW.changed_by
   WHERE org_id = NEW.org_id AND on_date = NEW.on_date AND delivery_year = NEW.delivery_year AND corrected_at IS NULL;
  PERFORM set_config('crm.market_price_correction', '', true);
  RETURN NEW;
END;
$$;
DELETE FROM job_run WHERE job = 'ceny';
ALTER TABLE job_run DROP CONSTRAINT job_run_job_check;
ALTER TABLE job_run ADD CONSTRAINT job_run_job_check CHECK (job IN ('zmluvy', 'obchody'));
DROP TABLE spot_average_daily;
