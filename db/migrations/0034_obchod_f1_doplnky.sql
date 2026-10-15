-- migrate:up

-- 0034_obchod_f1_doplnky – modul 5, F1 (API a obrazovky): doplnky zistené pri obrazovke 31 (overenie firmy).
-- 1. Žiadosť o pridelenie firmy podľa IČO: firmu iného obchodníka žiadateľ nevidí (RLS), API preto nepozná jej id.
-- 2. company_check vráti id aj pri firme bez vlastníka – obchodník na nej založí obchod a stane sa vlastníkom
--    (0032); pri firme iného vlastníka id ostáva skryté.
-- 3. Oprava hlášky v deal_rules (0032): „Firmu vlastní Peter Kalmans“ → „Firmu vlastní Peter Kalman“.
-- 4. company_apply_finstat: platobný rating sa prepíše iba vtedy, keď ho údaje obsahujú (Finstat ho neposiela).

CREATE FUNCTION approval_request_assign_ico(p_ico text, p_reason text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_ico text := regexp_replace(coalesce(p_ico, ''), '\s', '', 'g');
  v_id  uuid;
BEGIN
  IF v_ico ~ '^[0-9]{1,8}$' THEN
    v_ico := lpad(v_ico, 8, '0');
  END IF;
  SELECT id INTO v_id FROM company
   WHERE ico = v_ico AND org_id = ANY (crm_user_orgs())
   ORDER BY country = 'SK' DESC LIMIT 1;
  IF v_id IS NULL THEN
    RAISE EXCEPTION 'Firma s týmto IČO v CRM nie je.' USING ERRCODE = 'no_data_found';
  END IF;
  RETURN approval_request_assign(v_id, p_reason);
END;
$$;

CREATE OR REPLACE FUNCTION company_check(p_ico text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_ico   text := regexp_replace(coalesce(p_ico, ''), '\s', '', 'g');
  c       company;
  v_sees  boolean;
BEGIN
  IF NOT crm_session_ok() THEN
    RETURN NULL;
  END IF;
  IF v_ico ~ '^[0-9]{1,8}$' THEN
    v_ico := lpad(v_ico, 8, '0');
  END IF;
  SELECT * INTO c FROM company
   WHERE ico = v_ico AND org_id = ANY (crm_user_orgs())
   ORDER BY country = 'SK' DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('exists', false, 'ico', v_ico);
  END IF;
  v_sees := crm_company_access(c.id, 'view');
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'exists', true,
    'ico', c.ico,
    -- id aj pri firme bez vlastníka: obchodník na nej založí obchod a stane sa vlastníkom (0032, odpoveď 4)
    'company_id', CASE WHEN v_sees OR c.owner_id IS NULL THEN c.id END,
    'visible', v_sees,
    'name', c.name,
    'is_customer', c.is_customer,
    'status', c.status,
    'owner_id', c.owner_id,
    'owner_name', (SELECT name FROM app_user WHERE id = c.owner_id),
    'owner_is_me', c.owner_id = crm_active_user_id(),
    'contacts', CASE WHEN v_sees THEN (SELECT count(*) FROM company_contact WHERE company_id = c.id) END,
    'contracts', CASE WHEN v_sees THEN (
        SELECT coalesce(jsonb_agg(jsonb_build_object('number', k.number, 'state', contract_state(k),
                                                     'effective_to', contract_effective_to(k)) ORDER BY k.valid_from DESC NULLS LAST), '[]')
          FROM contract k WHERE k.company_id = c.id) END,
    'open_deals', (
        SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'deal_id', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.id END,
                 'name', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.name END,
                 'owner_name', (SELECT name FROM app_user WHERE id = d.owner_id)) ORDER BY d.created_at), '[]')
          FROM deal d WHERE d.company_id = c.id AND d.closed_at IS NULL),
    'risk', company_risk(c.id)));
END;
$$;

-- 3. Hláška pri konflikte vlastníka (preklep %s v 0032)
CREATE OR REPLACE FUNCTION deal_rules() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_kind      deal_kind;
  v_stage     pipeline_stage;
  v_old_stage pipeline_stage;
  v_cust_own  uuid;
  v_internal  boolean := crm_internal_call() OR current_user = 'crm_sync';   -- kód databázy alebo prenos z HubSpotu
BEGIN
  SELECT p.kind INTO v_kind FROM pipeline p WHERE p.id = NEW.pipeline_id AND p.archived_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pipeline neexistuje alebo je archivovaná.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_stage FROM pipeline_stage s WHERE s.id = NEW.stage_id AND s.pipeline_id = NEW.pipeline_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Štádium nepatrí do pipeline obchodu.' USING ERRCODE = 'check_violation';
  END IF;

  -- zákazník podľa druhu pipeline
  IF v_kind IN ('b2c_dodavka', 'green_solar') AND NEW.person_id IS NULL THEN
    RAISE EXCEPTION 'Obchod v pipeline B2C patrí domácnosti (osobe), nie firme.' USING ERRCODE = 'check_violation';
  ELSIF v_kind NOT IN ('b2c_dodavka', 'green_solar') AND NEW.company_id IS NULL THEN
    RAISE EXCEPTION 'Obchod v tejto pipeline patrí firme.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT lookup_code_ok('zdroj_obchodu', NEW.source_code, NEW.org_id)
     AND (TG_OP = 'INSERT' OR NEW.source_code IS DISTINCT FROM OLD.source_code) THEN
    RAISE EXCEPTION 'Neznámy zdroj obchodu.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.source_code = 'obnova' AND (TG_OP = 'INSERT' OR OLD.source_code <> 'obnova') AND NOT v_internal THEN
    RAISE EXCEPTION 'Zdroj „Obnova“ nastavuje iba nočný beh.' USING ERRCODE = 'check_violation';
  END IF;

  -- vlastník obchodu: aktívny používateľ; zmena iba vedenie, „všetko“ v module Obchod, schvaľovatelia, kód databázy
  IF TG_OP = 'INSERT' OR NEW.owner_id <> OLD.owner_id THEN
    IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = NEW.owner_id AND u.status <> 'deaktivovany') THEN
      RAISE EXCEPTION 'Vlastník obchodu musí byť aktívny používateľ.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.owner_id <> OLD.owner_id AND NOT v_internal AND current_user <> 'crm_sync'
     AND NOT crm_deal_manager() THEN
    RAISE EXCEPTION 'Vlastníka obchodu môže zmeniť iba vedenie alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'INSERT' AND NEW.owner_id <> crm_active_user_id() AND NOT v_internal AND NOT crm_deal_manager() THEN
    RAISE EXCEPTION 'Obchod môžete založiť iba pre seba.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- konflikt vlastníka zákazníka (časť 4.1 zadania): iný vlastník → pridelenie firmy
  IF TG_OP = 'INSERT' OR (NEW.company_id, NEW.person_id, NEW.owner_id) IS DISTINCT FROM (OLD.company_id, OLD.person_id, OLD.owner_id) THEN
    v_cust_own := crm_customer_owner(NEW.company_id, NEW.person_id);
    IF v_cust_own IS NOT NULL AND v_cust_own <> NEW.owner_id AND NOT v_internal AND current_user <> 'crm_sync'
       AND NOT crm_deal_manager() THEN
      RAISE EXCEPTION '% vlastní % – nový obchod nejde založiť. Požiadajte o pridelenie.',
        CASE WHEN NEW.company_id IS NOT NULL THEN 'Firmu' ELSE 'Osobu' END, crm_user_name(v_cust_own)
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- štádium
  IF TG_OP = 'INSERT' THEN
    IF v_stage.code IS DISTINCT FROM 'prilezitost' AND NOT v_internal THEN
      RAISE EXCEPTION 'Nový obchod začína v štádiu Príležitosť.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.stage_id <> OLD.stage_id THEN
    SELECT * INTO v_old_stage FROM pipeline_stage WHERE id = OLD.stage_id;
    IF v_stage.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'Štádium je archivované.' USING ERRCODE = 'check_violation';
    END IF;
    -- z uzavretého štádia iba znovuotvorením (deal_reopen)
    IF v_old_stage.outcome <> 'otvoreny'
       AND NOT (v_internal AND current_setting('app.deal_reopen', true) = NEW.id::text) THEN
      RAISE EXCEPTION 'Uzavretý obchod sa dá iba znova otvoriť (s dôvodom).' USING ERRCODE = 'check_violation';
    END IF;
    IF v_stage.code = 'akceptacia' AND NOT v_internal THEN
      RAISE EXCEPTION 'Do Akceptácie sa obchod presunie sám pri akceptácii ponuky.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_stage.code = 'vyhrane' AND NOT v_internal AND NOT crm_is_admin() THEN
      RAISE EXCEPTION 'Vyhraté nastaví spárovaná zmluva (alebo admin).' USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR NEW.stage_id <> OLD.stage_id THEN
    IF deal_stage_needs_oom(v_stage.code) AND NOT v_internal AND NOT deal_oom_ready(NEW.id) THEN
      RAISE EXCEPTION 'Pre štádium % treba aspoň jedno OOM a pri každom plánovanú spotrebu (pri výkupe výrobu alebo výkon).',
        v_stage.name USING ERRCODE = 'check_violation';
    END IF;
    NEW.stage_changed_at := now();
    NEW.closed_at := CASE WHEN v_stage.outcome <> 'otvoreny' THEN now() END;
  ELSE
    NEW.stage_changed_at := OLD.stage_changed_at;
    NEW.closed_at := OLD.closed_at;
  END IF;

  -- dôvod prehry iba v Prehraté, pri „iné“ s poznámkou
  IF v_stage.code = 'prehrane' THEN
    IF NEW.lost_reason_code IS NULL OR NOT lookup_code_ok('dovod_prehry', NEW.lost_reason_code, NEW.org_id)
       AND (TG_OP = 'INSERT' OR NEW.lost_reason_code IS DISTINCT FROM OLD.lost_reason_code) THEN
      RAISE EXCEPTION 'Pri prehre vyberte dôvod prehry.' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.lost_reason_code = 'ine' AND NEW.lost_note IS NULL THEN
      RAISE EXCEPTION 'Pri dôvode „Iné“ doplňte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  ELSE
    NEW.lost_reason_code := NULL;
    NEW.lost_note := NULL;
  END IF;

  -- upozornenie na ďalší krok: nové dátum = znova; stĺpec nastavuje iba nočný beh
  IF TG_OP = 'INSERT' THEN
    NEW.next_step_notified_on := CASE WHEN v_internal THEN NEW.next_step_notified_on END;
  ELSIF NOT v_internal THEN
    NEW.next_step_notified_on := CASE WHEN NEW.next_step_on IS NOT DISTINCT FROM OLD.next_step_on
                                      THEN OLD.next_step_notified_on END;
  END IF;
  RETURN NEW;
END;
$$;

-- 4. Zápis Finstatu nemaže platobný rating
CREATE OR REPLACE FUNCTION company_apply_finstat(p_company_id uuid, p_data jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT crm_company_access(p_company_id, 'view') THEN
    RAISE EXCEPTION 'Firma neexistuje alebo ju nevidíte.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'company_apply_finstat: očakávaný objekt údajov';
  END IF;
  v_prev := current_setting('app.change_source', true);
  PERFORM set_config('app.change_source', 'synchronizacia', true);
  UPDATE company SET
    revenue_eur      = (p_data->>'revenue_eur')::numeric,
    profit_eur       = (p_data->>'profit_eur')::numeric,
    finance_year     = (p_data->>'finance_year')::smallint,
    employees_range  = nullif(p_data->>'employees_range', ''),
    founded_on       = (p_data->>'founded_on')::date,
    z_score          = (p_data->>'z_score')::numeric,
    has_debts        = (p_data->>'has_debts')::boolean,
    debts            = coalesce(p_data->'debts', '[]'),
    insolvency_kind  = nullif(p_data->>'insolvency_kind', ''),
    insolvency_since = (p_data->>'insolvency_since')::date,
    cancelled_on     = (p_data->>'cancelled_on')::date,
    -- Finstat platobný rating A–E/X neposiela: bez kľúča ostáva hodnota na firme (z CRM / HubSpotu)
    payment_rating   = CASE WHEN p_data ? 'payment_rating' THEN (nullif(p_data->>'payment_rating', ''))::payment_rating ELSE payment_rating END,
    finstat_url      = coalesce(nullif(p_data->>'finstat_url', ''), finstat_url),
    finstat_updated_at = now()
  WHERE id = p_company_id;
  PERFORM set_config('app.change_source', coalesce(v_prev, ''), true);
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS approval_request_assign_ico(text, text);

CREATE OR REPLACE FUNCTION company_check(p_ico text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_ico   text := regexp_replace(coalesce(p_ico, ''), '\s', '', 'g');
  c       company;
  v_sees  boolean;
BEGIN
  IF NOT crm_session_ok() THEN
    RETURN NULL;
  END IF;
  IF v_ico ~ '^[0-9]{1,8}$' THEN
    v_ico := lpad(v_ico, 8, '0');
  END IF;
  SELECT * INTO c FROM company
   WHERE ico = v_ico AND org_id = ANY (crm_user_orgs())
   ORDER BY country = 'SK' DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('exists', false, 'ico', v_ico);
  END IF;
  v_sees := crm_company_access(c.id, 'view');
  RETURN jsonb_strip_nulls(jsonb_build_object(
    'exists', true,
    'ico', c.ico,
    'company_id', CASE WHEN v_sees THEN c.id END,
    'visible', v_sees,
    'name', c.name,
    'is_customer', c.is_customer,
    'status', c.status,
    'owner_id', c.owner_id,
    'owner_name', (SELECT name FROM app_user WHERE id = c.owner_id),
    'owner_is_me', c.owner_id = crm_active_user_id(),
    'contacts', CASE WHEN v_sees THEN (SELECT count(*) FROM company_contact WHERE company_id = c.id) END,
    'contracts', CASE WHEN v_sees THEN (
        SELECT coalesce(jsonb_agg(jsonb_build_object('number', k.number, 'state', contract_state(k),
                                                     'effective_to', contract_effective_to(k)) ORDER BY k.valid_from DESC NULLS LAST), '[]')
          FROM contract k WHERE k.company_id = c.id) END,
    'open_deals', (
        SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'deal_id', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.id END,
                 'name', CASE WHEN v_sees AND crm_deal_visible(d.company_id, d.person_id, d.owner_id) THEN d.name END,
                 'owner_name', (SELECT name FROM app_user WHERE id = d.owner_id)) ORDER BY d.created_at), '[]')
          FROM deal d WHERE d.company_id = c.id AND d.closed_at IS NULL),
    'risk', company_risk(c.id)));
END;
$$;

CREATE OR REPLACE FUNCTION deal_rules() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_kind      deal_kind;
  v_stage     pipeline_stage;
  v_old_stage pipeline_stage;
  v_cust_own  uuid;
  v_internal  boolean := crm_internal_call() OR current_user = 'crm_sync';   -- kód databázy alebo prenos z HubSpotu
BEGIN
  SELECT p.kind INTO v_kind FROM pipeline p WHERE p.id = NEW.pipeline_id AND p.archived_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pipeline neexistuje alebo je archivovaná.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO v_stage FROM pipeline_stage s WHERE s.id = NEW.stage_id AND s.pipeline_id = NEW.pipeline_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Štádium nepatrí do pipeline obchodu.' USING ERRCODE = 'check_violation';
  END IF;

  -- zákazník podľa druhu pipeline
  IF v_kind IN ('b2c_dodavka', 'green_solar') AND NEW.person_id IS NULL THEN
    RAISE EXCEPTION 'Obchod v pipeline B2C patrí domácnosti (osobe), nie firme.' USING ERRCODE = 'check_violation';
  ELSIF v_kind NOT IN ('b2c_dodavka', 'green_solar') AND NEW.company_id IS NULL THEN
    RAISE EXCEPTION 'Obchod v tejto pipeline patrí firme.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT lookup_code_ok('zdroj_obchodu', NEW.source_code, NEW.org_id)
     AND (TG_OP = 'INSERT' OR NEW.source_code IS DISTINCT FROM OLD.source_code) THEN
    RAISE EXCEPTION 'Neznámy zdroj obchodu.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.source_code = 'obnova' AND (TG_OP = 'INSERT' OR OLD.source_code <> 'obnova') AND NOT v_internal THEN
    RAISE EXCEPTION 'Zdroj „Obnova“ nastavuje iba nočný beh.' USING ERRCODE = 'check_violation';
  END IF;

  -- vlastník obchodu: aktívny používateľ; zmena iba vedenie, „všetko“ v module Obchod, schvaľovatelia, kód databázy
  IF TG_OP = 'INSERT' OR NEW.owner_id <> OLD.owner_id THEN
    IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = NEW.owner_id AND u.status <> 'deaktivovany') THEN
      RAISE EXCEPTION 'Vlastník obchodu musí byť aktívny používateľ.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.owner_id <> OLD.owner_id AND NOT v_internal AND current_user <> 'crm_sync'
     AND NOT crm_deal_manager() THEN
    RAISE EXCEPTION 'Vlastníka obchodu môže zmeniť iba vedenie alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'INSERT' AND NEW.owner_id <> crm_active_user_id() AND NOT v_internal AND NOT crm_deal_manager() THEN
    RAISE EXCEPTION 'Obchod môžete založiť iba pre seba.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  -- konflikt vlastníka zákazníka (časť 4.1 zadania): iný vlastník → pridelenie firmy
  IF TG_OP = 'INSERT' OR (NEW.company_id, NEW.person_id, NEW.owner_id) IS DISTINCT FROM (OLD.company_id, OLD.person_id, OLD.owner_id) THEN
    v_cust_own := crm_customer_owner(NEW.company_id, NEW.person_id);
    IF v_cust_own IS NOT NULL AND v_cust_own <> NEW.owner_id AND NOT v_internal AND current_user <> 'crm_sync'
       AND NOT crm_deal_manager() THEN
      RAISE EXCEPTION '% vlastní %s – nový obchod nejde založiť. Požiadajte o pridelenie.',
        CASE WHEN NEW.company_id IS NOT NULL THEN 'Firmu' ELSE 'Osobu' END, crm_user_name(v_cust_own)
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- štádium
  IF TG_OP = 'INSERT' THEN
    IF v_stage.code IS DISTINCT FROM 'prilezitost' AND NOT v_internal THEN
      RAISE EXCEPTION 'Nový obchod začína v štádiu Príležitosť.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.stage_id <> OLD.stage_id THEN
    SELECT * INTO v_old_stage FROM pipeline_stage WHERE id = OLD.stage_id;
    IF v_stage.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'Štádium je archivované.' USING ERRCODE = 'check_violation';
    END IF;
    -- z uzavretého štádia iba znovuotvorením (deal_reopen)
    IF v_old_stage.outcome <> 'otvoreny'
       AND NOT (v_internal AND current_setting('app.deal_reopen', true) = NEW.id::text) THEN
      RAISE EXCEPTION 'Uzavretý obchod sa dá iba znova otvoriť (s dôvodom).' USING ERRCODE = 'check_violation';
    END IF;
    IF v_stage.code = 'akceptacia' AND NOT v_internal THEN
      RAISE EXCEPTION 'Do Akceptácie sa obchod presunie sám pri akceptácii ponuky.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_stage.code = 'vyhrane' AND NOT v_internal AND NOT crm_is_admin() THEN
      RAISE EXCEPTION 'Vyhraté nastaví spárovaná zmluva (alebo admin).' USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF TG_OP = 'INSERT' OR NEW.stage_id <> OLD.stage_id THEN
    IF deal_stage_needs_oom(v_stage.code) AND NOT v_internal AND NOT deal_oom_ready(NEW.id) THEN
      RAISE EXCEPTION 'Pre štádium % treba aspoň jedno OOM a pri každom plánovanú spotrebu (pri výkupe výrobu alebo výkon).',
        v_stage.name USING ERRCODE = 'check_violation';
    END IF;
    NEW.stage_changed_at := now();
    NEW.closed_at := CASE WHEN v_stage.outcome <> 'otvoreny' THEN now() END;
  ELSE
    NEW.stage_changed_at := OLD.stage_changed_at;
    NEW.closed_at := OLD.closed_at;
  END IF;

  -- dôvod prehry iba v Prehraté, pri „iné“ s poznámkou
  IF v_stage.code = 'prehrane' THEN
    IF NEW.lost_reason_code IS NULL OR NOT lookup_code_ok('dovod_prehry', NEW.lost_reason_code, NEW.org_id)
       AND (TG_OP = 'INSERT' OR NEW.lost_reason_code IS DISTINCT FROM OLD.lost_reason_code) THEN
      RAISE EXCEPTION 'Pri prehre vyberte dôvod prehry.' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.lost_reason_code = 'ine' AND NEW.lost_note IS NULL THEN
      RAISE EXCEPTION 'Pri dôvode „Iné“ doplňte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  ELSE
    NEW.lost_reason_code := NULL;
    NEW.lost_note := NULL;
  END IF;

  -- upozornenie na ďalší krok: nové dátum = znova; stĺpec nastavuje iba nočný beh
  IF TG_OP = 'INSERT' THEN
    NEW.next_step_notified_on := CASE WHEN v_internal THEN NEW.next_step_notified_on END;
  ELSIF NOT v_internal THEN
    NEW.next_step_notified_on := CASE WHEN NEW.next_step_on IS NOT DISTINCT FROM OLD.next_step_on
                                      THEN OLD.next_step_notified_on END;
  END IF;
  RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION company_apply_finstat(p_company_id uuid, p_data jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_prev text;
BEGIN
  IF NOT crm_company_access(p_company_id, 'view') THEN
    RAISE EXCEPTION 'Firma neexistuje alebo ju nevidíte.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_data IS NULL OR jsonb_typeof(p_data) <> 'object' THEN
    RAISE EXCEPTION 'company_apply_finstat: očakávaný objekt údajov';
  END IF;
  v_prev := current_setting('app.change_source', true);
  PERFORM set_config('app.change_source', 'synchronizacia', true);
  UPDATE company SET
    revenue_eur      = (p_data->>'revenue_eur')::numeric,
    profit_eur       = (p_data->>'profit_eur')::numeric,
    finance_year     = (p_data->>'finance_year')::smallint,
    employees_range  = nullif(p_data->>'employees_range', ''),
    founded_on       = (p_data->>'founded_on')::date,
    z_score          = (p_data->>'z_score')::numeric,
    has_debts        = (p_data->>'has_debts')::boolean,
    debts            = coalesce(p_data->'debts', '[]'),
    insolvency_kind  = nullif(p_data->>'insolvency_kind', ''),
    insolvency_since = (p_data->>'insolvency_since')::date,
    cancelled_on     = (p_data->>'cancelled_on')::date,
    payment_rating   = (nullif(p_data->>'payment_rating', ''))::payment_rating,
    finstat_url      = coalesce(nullif(p_data->>'finstat_url', ''), finstat_url),
    finstat_updated_at = now()
  WHERE id = p_company_id;
  PERFORM set_config('app.change_source', coalesce(v_prev, ''), true);
END;
$$;

