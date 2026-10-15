-- migrate:up

-- 0035_audit_rls – RLS na audite (návrh DB modulu 5, časť 17; Peter 15. 10. 2026 súhlasil).
-- Audit vidí iba to, čo používateľ smie vidieť: admin všetko; ostatní audit firiem, osôb, OOM, obchodov, zmlúv,
-- výnimiek, žiadostí o schválenie a poznámok, ktoré vidia. Nastavenia, používatelia, cenníky, parametre a importy
-- iba admin. Pri podriadených záznamoch (aj zmazaných) rozhoduje nadriadený záznam (id z riadku alebo z obsahu
-- zmeny v audite). Tým je splnená posledná podmienka externého tímu: crm_external_ready() = true.

-- Hodnota stĺpca z obsahu zmeny: insert/delete = celý riadok, update = {stĺpec: {old, new}}
CREATE FUNCTION audit_diff_value(p_diff jsonb, p_column text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN jsonb_typeof(p_diff -> p_column) = 'object'
              THEN coalesce(p_diff -> p_column ->> 'new', p_diff -> p_column ->> 'old')
              ELSE p_diff ->> p_column END
$$;

CREATE FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id uuid;
  d    deal;
  k    contract;
  a    approval_request;
BEGIN
  IF crm_is_service() OR crm_is_admin() THEN
    RETURN true;
  END IF;
  IF crm_active_user_id() IS NULL THEN
    RETURN false;
  END IF;

  CASE p_table
    WHEN 'company' THEN
      RETURN crm_company_access(p_record, 'view');
    WHEN 'contact' THEN
      RETURN crm_contact_access(p_record, 'view');
    WHEN 'company_contact' THEN
      v_id := coalesce((SELECT company_id FROM company_contact WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_company_access(v_id, 'view');
    WHEN 'activity' THEN
      v_id := coalesce((SELECT company_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'company_id')::uuid);
      IF v_id IS NOT NULL THEN
        RETURN crm_company_access(v_id, 'view');
      END IF;
      v_id := coalesce((SELECT contact_id FROM activity WHERE id = p_record), audit_diff_value(p_diff, 'contact_id')::uuid);
      RETURN v_id IS NOT NULL AND crm_contact_access(v_id, 'view');
    WHEN 'oom' THEN
      RETURN crm_oom_access(p_record, 'view');
    WHEN 'oom_customer', 'oom_device', 'oom_contact', 'oom_planned_change', 'oom_price_regulation_change' THEN
      v_id := audit_diff_value(p_diff, 'oom_id')::uuid;
      IF v_id IS NULL THEN
        EXECUTE format('SELECT oom_id FROM %I WHERE id = $1', p_table) INTO v_id USING p_record;
      END IF;
      RETURN v_id IS NOT NULL AND crm_oom_access(v_id, 'view');
    WHEN 'deal', 'deal_oom', 'deal_contact' THEN
      v_id := CASE WHEN p_table = 'deal' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'deal_id')::uuid,
                                 (SELECT deal_id FROM deal_oom WHERE id = p_record),
                                 (SELECT deal_id FROM deal_contact WHERE id = p_record)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'contract', 'contract_oom', 'contract_price', 'contract_flag' THEN
      v_id := CASE WHEN p_table = 'contract' THEN p_record
                   ELSE coalesce(audit_diff_value(p_diff, 'contract_id')::uuid,
                                 (SELECT contract_id FROM contract_oom WHERE id = p_record),
                                 (SELECT contract_id FROM contract_price WHERE id = p_record),
                                 (SELECT contract_id FROM contract_flag WHERE id = p_record)) END;
      SELECT * INTO k FROM contract WHERE id = v_id;
      RETURN FOUND AND k.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(k.company_id, k.person_id, k.owner_id);
    WHEN 'price_exception' THEN
      RETURN crm_sees_all_contracts()
          OR coalesce((SELECT requested_by FROM price_exception WHERE id = p_record),
                      audit_diff_value(p_diff, 'requested_by')::uuid) = crm_active_user_id();
    WHEN 'approval_request' THEN
      SELECT * INTO a FROM approval_request WHERE id = p_record;
      RETURN FOUND AND a.org_id = ANY (crm_user_orgs())
         AND (a.requested_by = crm_active_user_id() OR a.from_owner_id = crm_active_user_id()
              OR (a.kind = 'pridelenie_firmy' AND crm_approves_assignments())
              OR (a.kind <> 'pridelenie_firmy' AND crm_approves_prices()));
    WHEN 'price_parameter', 'market_price_daily' THEN
      RETURN crm_approves_prices() OR crm_can_see_margin();   -- kto smie čítať cenové parametre a trhové ceny (0023)
    ELSE
      RETURN false;   -- Nastavenia, používatelia, tímy, cenníky, importy: iba admin
  END CASE;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;     -- poškodené id v obsahu zmeny: radšej skryť
END;
$$;
COMMENT ON FUNCTION audit_row_visible(text, uuid, jsonb) IS 'RLS na audit_log: admin všetko, ostatní iba zmeny záznamov, ktoré smú vidieť (0035)';

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY audit_log_select ON audit_log FOR SELECT
  USING (audit_row_visible(table_name, record_id, diff));
-- zápis robí spúšťač audit_row s právami volajúceho – vkladať smie každý, kto mení obchodné dáta
CREATE POLICY audit_log_insert ON audit_log FOR INSERT WITH CHECK (true);
-- zmenu a zmazanie odmietne spúšťač audit_log_protect (chyba, nie tiché „0 riadkov“)
CREATE POLICY audit_log_protect_update ON audit_log FOR UPDATE USING (true);
CREATE POLICY audit_log_protect_delete ON audit_log FOR DELETE USING (true);

-- Externý tím: OOM, obchody, zmluvy aj audit majú „iba svoje“ v databáze
CREATE OR REPLACE FUNCTION crm_external_ready() RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT true
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION crm_external_ready() RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT false
$$;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id WHERE t.is_external) THEN
    RAISE EXCEPTION 'Návrat 0035: v externom tíme sú používatelia – najprv ich presuňte.';
  END IF;
END;
$$;
DROP POLICY IF EXISTS audit_log_protect_delete ON audit_log;
DROP POLICY IF EXISTS audit_log_protect_update ON audit_log;
DROP POLICY IF EXISTS audit_log_insert ON audit_log;
DROP POLICY IF EXISTS audit_log_select ON audit_log;
ALTER TABLE audit_log DISABLE ROW LEVEL SECURITY;
DROP FUNCTION IF EXISTS audit_row_visible(text, uuid, jsonb);
DROP FUNCTION IF EXISTS audit_diff_value(jsonb, text);
