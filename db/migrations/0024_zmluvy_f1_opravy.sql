-- 0024_zmluvy_f1_opravy.sql – modul 4, fáza F1: úpravy Petra k plánu F1 (13. 10. 2026)
--
-- 1. Trhové ceny dňa sa neprepisujú: chybný záznam sa opraví novým záznamom pre ten istý deň (platí posledný),
--    pôvodný ostane v histórii označený „opravené“ s menom a časom; oboje v audite. Cena pre obchodníka
--    a obrazovka 29 berú iba platný (neopravený) záznam.
-- 2. Zmena cenovej regulácie OOM s „platí od“ v minulosti, dnes aj v budúcnosti: na OOM platí hodnota
--    najneskoršej zmeny s dátumom do dneška; budúcu zmenu uplatní nočný beh (oom_daily_run) v deň platnosti.
--    Neuplatnenú budúcu zmenu smie zrušiť, kto smie OOM upravovať.
-- 3. Cenový parameter: pri cudzej naplánovanej zmene hláška „iba jej autor“ (nie „platný parameter“).

-- migrate:up

-- ============================================================================
-- 1. Trhové ceny: oprava novým záznamom
-- ============================================================================

ALTER TABLE market_price_daily DROP CONSTRAINT market_price_daily_pkey;
ALTER TABLE market_price_daily
  ADD COLUMN id           uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN corrected_at timestamptz,
  ADD COLUMN corrected_by uuid REFERENCES app_user (id),
  ADD PRIMARY KEY (id),
  ADD CONSTRAINT market_price_corrected_check CHECK (corrected_by IS NULL OR corrected_at IS NOT NULL);
CREATE UNIQUE INDEX market_price_daily_current_key ON market_price_daily (org_id, on_date, delivery_year)
  WHERE corrected_at IS NULL;
CREATE INDEX market_price_daily_day_idx ON market_price_daily (org_id, delivery_year, on_date);
COMMENT ON COLUMN market_price_daily.corrected_at IS 'záznam opravený novším záznamom toho istého dňa (platí najnovší); NULL = platný';

-- Zápis z aplikácie: iba nový záznam pre dnešný deň alebo neskôr. Ak pre deň a rok už platný záznam je,
-- nový ho opraví (pôvodný dostane „opravené“, kto a kedy). Záznam sa nemení ani nemaže – iba vlastník
-- databázy (história) a táto funkcia pri označení opravy.
CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Cena pre obchodníka: iba platný (neopravený) záznam
CREATE OR REPLACE FUNCTION trader_price(p_org uuid, p_year smallint, p_on date) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_bl numeric; v_pl numeric; v_ratio numeric; v_risk numeric; v_margin numeric;
BEGIN
  IF NOT crm_session_ok() OR NOT p_org = ANY (crm_user_orgs()) THEN
    RETURN NULL;
  END IF;
  SELECT bl_eur_mwh, pl_eur_mwh INTO v_bl, v_pl
    FROM market_price_daily
   WHERE org_id = p_org AND delivery_year = p_year AND bl_eur_mwh IS NOT NULL AND corrected_at IS NULL
     AND on_date BETWEEN p_on - 7 AND p_on
   ORDER BY on_date DESC
   LIMIT 1;
  v_ratio  := price_param(p_org, 'pomer_bl_pct', p_on);
  v_risk   := price_param(p_org, 'rizikova_prirazka', p_on);
  v_margin := price_param(p_org, 'nasa_marza', p_on);
  IF v_bl IS NULL OR v_ratio IS NULL OR v_risk IS NULL OR v_margin IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN round((v_bl * v_ratio + v_pl * (100 - v_ratio)) / 100 + v_risk + v_margin, 4);
END;
$$;

CREATE OR REPLACE VIEW trader_price_today_v WITH (security_invoker = true) AS
SELECT m.org_id, m.delivery_year, m.on_date,
       m.bl_eur_mwh, m.pl_eur_mwh,
       price_param(m.org_id, 'pomer_bl_pct', crm_today()) AS bl_ratio_pct,
       round((m.bl_eur_mwh * price_param(m.org_id, 'pomer_bl_pct', crm_today())
              + m.pl_eur_mwh * (100 - price_param(m.org_id, 'pomer_bl_pct', crm_today()))) / 100, 4) AS mix_eur_mwh,
       price_param(m.org_id, 'rizikova_prirazka', crm_today()) AS risk_eur_mwh,
       price_param(m.org_id, 'nasa_marza', crm_today()) AS margin_eur_mwh,
       trader_price(m.org_id, m.delivery_year, crm_today()) AS trader_price_eur_mwh,
       m.portfolio_eur_mwh, m.spot_fve_eur_mwh, m.source,
       m.id
  FROM market_price_daily m
 WHERE m.corrected_at IS NULL
   AND m.on_date = (SELECT max(x.on_date) FROM market_price_daily x
                     WHERE x.org_id = m.org_id AND x.delivery_year = m.delivery_year
                       AND x.on_date <= crm_today() AND x.corrected_at IS NULL);

-- História cien dňa vrátane opravených (obrazovka 29): kto zadal, kto opravil
CREATE VIEW market_price_history_v WITH (security_invoker = true) AS
SELECT m.id, m.org_id, m.on_date, m.delivery_year, m.bl_eur_mwh, m.pl_eur_mwh, m.portfolio_eur_mwh, m.spot_fve_eur_mwh,
       m.source, m.created_at, m.changed_by, cu.name AS changed_by_name,
       m.corrected_at, m.corrected_by, ku.name AS corrected_by_name,
       m.corrected_at IS NOT NULL AS is_corrected
  FROM market_price_daily m
  LEFT JOIN app_user cu ON cu.id = m.changed_by
  LEFT JOIN app_user ku ON ku.id = m.corrected_by;
COMMENT ON VIEW market_price_history_v IS 'trhové ceny dňa s opravami (opravený záznam ostáva v histórii)';

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON market_price_daily FOR EACH ROW EXECUTE FUNCTION audit_row();

-- ============================================================================
-- 2. Cenová regulácia OOM: aj budúci dátum, uplatní nočný beh
-- ============================================================================

-- Na OOM platí hodnota najneskoršej zmeny s „platí od“ do dňa p_today; uplatnené zmeny dostanú applied_at.
-- Vracia true, ak sa niečo uplatnilo. Práva volajúceho (RLS a úprava Aktívneho OOM) – nočný beh je SECURITY DEFINER.
CREATE FUNCTION oom_price_regulation_apply(p_oom_id uuid, p_today date) RETURNS boolean
LANGUAGE plpgsql AS $$
DECLARE
  v_value boolean;
  v_found boolean;
BEGIN
  SELECT value, true INTO v_value, v_found
    FROM oom_price_regulation_change
   WHERE oom_id = p_oom_id AND valid_from <= p_today
   ORDER BY valid_from DESC
   LIMIT 1;
  IF NOT coalesce(v_found, false) THEN
    RETURN false;
  END IF;
  UPDATE oom SET price_regulation = v_value WHERE id = p_oom_id AND price_regulation IS DISTINCT FROM v_value;
  UPDATE oom_price_regulation_change SET applied_at = now()
   WHERE oom_id = p_oom_id AND valid_from <= p_today AND applied_at IS NULL;
  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_valid_from IS NULL THEN
    RAISE EXCEPTION 'Zadaj dátum „platí od“.' USING ERRCODE = 'check_violation';
  END IF;
  -- prístup k OOM a právo ho upraviť (RLS a spúšťač Aktívneho OOM) overí zápis bez zmeny hodnoty
  UPDATE oom SET price_regulation = price_regulation WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, NULL, crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = NULL, created_by = EXCLUDED.created_by;
  PERFORM oom_price_regulation_apply(p_oom_id, crm_today());
END;
$$;
COMMENT ON FUNCTION oom_price_regulation_set(uuid, boolean, date) IS 'zmena cenovej regulácie OOM s dátumom (minulý, dnešný, budúci); budúcu uplatní nočný beh';

-- Neuplatnenú budúcu zmenu smie zrušiť, kto smie OOM upraviť; uplatnená ostáva v histórii
CREATE FUNCTION oom_price_regulation_cancel(p_change_id uuid) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_oom uuid;
BEGIN
  SELECT oom_id INTO v_oom FROM oom_price_regulation_change
   WHERE id = p_change_id AND applied_at IS NULL AND valid_from > crm_today();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Naplánovaná zmena neexistuje alebo už platí.' USING ERRCODE = 'P0002';
  END IF;
  UPDATE oom SET price_regulation = price_regulation WHERE id = v_oom;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  DELETE FROM oom_price_regulation_change WHERE id = p_change_id;
END;
$$;

CREATE POLICY oom_regulation_delete ON oom_price_regulation_change FOR DELETE
  USING (applied_at IS NULL AND EXISTS (SELECT 1 FROM oom o WHERE o.id = oom_id));

-- Nočný beh OOM (0016) rozšírený: splatné zmeny cenovej regulácie
CREATE OR REPLACE FUNCTION oom_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id     uuid;
  v_done   integer := 0;
  v_failed integer := 0;
  v_reg    integer := 0;
BEGIN
  FOR v_id IN SELECT id FROM oom_planned_change
               WHERE status = 'planovana' AND oom_plan_due_on(kind, effective_date) <= p_today
               ORDER BY effective_date, created_at LOOP
    IF oom_plan_execute(v_id) THEN v_done := v_done + 1; ELSE v_failed := v_failed + 1; END IF;
  END LOOP;
  FOR v_id IN SELECT DISTINCT oom_id FROM oom_price_regulation_change
               WHERE applied_at IS NULL AND valid_from <= p_today LOOP
    IF oom_price_regulation_apply(v_id, p_today) THEN v_reg := v_reg + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('plany_vykonane', v_done, 'plany_zlyhali', v_failed,
                            'aktivovane', oom_activate_due_at(p_today), 'regulacia', v_reg);
END;
$$;

-- ============================================================================
-- 3. Cenové parametre: zrozumiteľná hláška pri cudzej naplánovanej zmene (inak ako 0023)
-- ============================================================================

CREATE OR REPLACE FUNCTION price_parameter_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_owner boolean := crm_owner_session();
BEGIN
  IF v_owner THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    IF OLD.valid_from <= crm_today() THEN
      RAISE EXCEPTION 'Platný parameter sa nemení ani nemaže – zadaj novú hodnotu s dátumom „platí od“.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.changed_by IS DISTINCT FROM crm_active_user_id() THEN
      RAISE EXCEPTION 'Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor.' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id OR NEW.delivery_year IS DISTINCT FROM OLD.delivery_year THEN
      RAISE EXCEPTION 'Parameter, spoločnosť a rok sa nemenia.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.valid_from < crm_today() THEN
    RAISE EXCEPTION 'Platí od musí byť dnes alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR (crm_approves_prices()
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;

-- migrate:down

-- Cenové parametre: hláška ako v 0023
CREATE OR REPLACE FUNCTION price_parameter_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_owner boolean := crm_owner_session();
BEGIN
  IF v_owner THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    IF NOT (OLD.valid_from > crm_today() AND OLD.changed_by IS NOT DISTINCT FROM crm_active_user_id()) THEN
      RAISE EXCEPTION 'Platný parameter sa nemení ani nemaže – zadaj novú hodnotu s dátumom „platí od“.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'DELETE' THEN
      RETURN OLD;
    END IF;
    IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id OR NEW.delivery_year IS DISTINCT FROM OLD.delivery_year THEN
      RAISE EXCEPTION 'Parameter, spoločnosť a rok sa nemenia.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.valid_from < crm_today() THEN
    RAISE EXCEPTION 'Platí od musí byť dnes alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR (crm_approves_prices()
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION oom_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id     uuid;
  v_done   integer := 0;
  v_failed integer := 0;
BEGIN
  FOR v_id IN SELECT id FROM oom_planned_change
               WHERE status = 'planovana' AND oom_plan_due_on(kind, effective_date) <= p_today
               ORDER BY effective_date, created_at LOOP
    IF oom_plan_execute(v_id) THEN v_done := v_done + 1; ELSE v_failed := v_failed + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('plany_vykonane', v_done, 'plany_zlyhali', v_failed,
                            'aktivovane', oom_activate_due_at(p_today));
END;
$$;

DROP POLICY IF EXISTS oom_regulation_delete ON oom_price_regulation_change;
DROP FUNCTION IF EXISTS oom_price_regulation_cancel(uuid);
-- budúce (neuplatnené) zmeny 0023 nepozná
DELETE FROM oom_price_regulation_change WHERE applied_at IS NULL;
CREATE OR REPLACE FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_valid_from IS NULL OR p_valid_from > crm_today() THEN
    RAISE EXCEPTION 'Zmena cenovej regulácie s budúcim dátumom zatiaľ nie je možná – zadaj dnešný alebo minulý dátum.'
      USING ERRCODE = 'check_violation';
  END IF;
  UPDATE oom SET price_regulation = p_value WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, now(), crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = EXCLUDED.applied_at, created_by = EXCLUDED.created_by;
END;
$$;
COMMENT ON FUNCTION oom_price_regulation_set(uuid, boolean, date) IS NULL;
DROP FUNCTION IF EXISTS oom_price_regulation_apply(uuid, date);

DROP TRIGGER IF EXISTS trg_audit ON market_price_daily;
DROP VIEW IF EXISTS market_price_history_v;
DROP VIEW IF EXISTS trader_price_today_v;
-- opravené záznamy 0023 nepozná (jeden záznam na deň a rok)
DELETE FROM market_price_daily WHERE corrected_at IS NOT NULL;
DROP INDEX IF EXISTS market_price_daily_day_idx;
DROP INDEX IF EXISTS market_price_daily_current_key;
ALTER TABLE market_price_daily DROP CONSTRAINT market_price_daily_pkey,
  DROP CONSTRAINT IF EXISTS market_price_corrected_check,
  DROP COLUMN corrected_by, DROP COLUMN corrected_at, DROP COLUMN id;
ALTER TABLE market_price_daily ADD PRIMARY KEY (org_id, on_date, delivery_year);

CREATE OR REPLACE FUNCTION trader_price(p_org uuid, p_year smallint, p_on date) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_bl numeric; v_pl numeric; v_ratio numeric; v_risk numeric; v_margin numeric;
BEGIN
  IF NOT crm_session_ok() OR NOT p_org = ANY (crm_user_orgs()) THEN
    RETURN NULL;
  END IF;
  SELECT bl_eur_mwh, pl_eur_mwh INTO v_bl, v_pl
    FROM market_price_daily
   WHERE org_id = p_org AND delivery_year = p_year AND bl_eur_mwh IS NOT NULL
     AND on_date BETWEEN p_on - 7 AND p_on
   ORDER BY on_date DESC
   LIMIT 1;
  v_ratio  := price_param(p_org, 'pomer_bl_pct', p_on);
  v_risk   := price_param(p_org, 'rizikova_prirazka', p_on);
  v_margin := price_param(p_org, 'nasa_marza', p_on);
  IF v_bl IS NULL OR v_ratio IS NULL OR v_risk IS NULL OR v_margin IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN round((v_bl * v_ratio + v_pl * (100 - v_ratio)) / 100 + v_risk + v_margin, 4);
END;
$$;

CREATE VIEW trader_price_today_v WITH (security_invoker = true) AS
SELECT m.org_id, m.delivery_year, m.on_date,
       m.bl_eur_mwh, m.pl_eur_mwh,
       price_param(m.org_id, 'pomer_bl_pct', crm_today()) AS bl_ratio_pct,
       round((m.bl_eur_mwh * price_param(m.org_id, 'pomer_bl_pct', crm_today())
              + m.pl_eur_mwh * (100 - price_param(m.org_id, 'pomer_bl_pct', crm_today()))) / 100, 4) AS mix_eur_mwh,
       price_param(m.org_id, 'rizikova_prirazka', crm_today()) AS risk_eur_mwh,
       price_param(m.org_id, 'nasa_marza', crm_today()) AS margin_eur_mwh,
       trader_price(m.org_id, m.delivery_year, crm_today()) AS trader_price_eur_mwh,
       m.portfolio_eur_mwh, m.spot_fve_eur_mwh, m.source
  FROM market_price_daily m
 WHERE m.on_date = (SELECT max(x.on_date) FROM market_price_daily x
                     WHERE x.org_id = m.org_id AND x.delivery_year = m.delivery_year AND x.on_date <= crm_today());
COMMENT ON VIEW trader_price_today_v IS 'obrazovka 29: posledné ceny BL/PL po rokoch dodávky a cena pre obchodníka dnes';

CREATE OR REPLACE FUNCTION market_price_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF crm_owner_session() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() OR (TG_OP = 'UPDATE' AND OLD.on_date < crm_today()) THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;
