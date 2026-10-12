-- 0015_oom_rls_import.sql – modul Odberné miesta: „iba svoje“ v databáze, práva, import, mazanie
-- (docs/moduly/02-odberne-miesta-navrh-db.md v0.4, časti 7–9)
--
-- RLS na oom, oom_customer, oom_device, oom_contact, supplier_switch podľa práv tímu v module
--   Odberné miesta a spoločnosti; „iba svoje“ = OOM, ktorého aktuálny zákazník patrí prihlásenému.
--   Väzbu (históriu) vidí aj ten, kto vidí zákazníka väzby (Peter 12. 10., odpoveď 1).
-- Nové práva tímu: can_import (import z Excelu) a can_edit_active_oom (úprava Aktívneho OOM, jeho
--   zariadení a kontaktných osôb) – Peter 12. 10. Zmena stavu a prepis ostávajú podľa práva upravovať.
-- Východiskové práva modulu: upravovať Sales_internal a Servis „všetko“, Sales_external „iba svoje“;
--   import a úprava Aktívnych: CEO, Servis, Nákup. Mení sa iba bunka s východiskovou hodnotou (odpoveď 2).
-- Kontrola duplicity EIC (oom_eic_check), záznam importu (oom_import) a import v audite,
--   mazanie OOM bez väzieb iba adminom (oom_delete, odpoveď 4).
-- Externý tím ostáva zamknutý (crm_external_ready), kým RLS nemajú dealy a zmluvy.

-- migrate:up

-- ============================================================================
-- Práva tímu: import a úprava Aktívnych OOM
-- ============================================================================

ALTER TABLE team_permission
  ADD COLUMN can_import          boolean NOT NULL DEFAULT false,
  ADD COLUMN can_edit_active_oom boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT team_permission_edit_active_oom_check CHECK (NOT can_edit_active_oom OR module = 'odberne_miesta');
COMMENT ON COLUMN team_permission.can_import IS 'smie hromadne importovať záznamy modulu (dnes OOM z Excelu)';
COMMENT ON COLUMN team_permission.can_edit_active_oom IS 'iba modul odberne_miesta: smie upravovať OOM v stave Aktívne, jeho zariadenia a kontaktné osoby';

-- Východiskové práva modulu Odberné miesta (návrh 7.2); iba bunky, ktoré admin ešte nemenil.
UPDATE team_permission p SET edit_scope = 'vsetko'
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'odberne_miesta' AND t.code IN ('sales_internal', 'servis')
   AND p.edit_scope = 'nic' AND p.view_scope = 'vsetko';
UPDATE team_permission p SET edit_scope = 'iba_svoje'
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'odberne_miesta' AND t.code = 'sales_external'
   AND p.edit_scope = 'nic' AND p.view_scope = 'iba_svoje';
UPDATE team_permission p SET can_import = true, can_edit_active_oom = true
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'odberne_miesta' AND t.code IN ('ceo', 'servis', 'nakup');

CREATE FUNCTION crm_can_import(p_module crm_module) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = p_module AND p.can_import)
$$;

CREATE FUNCTION crm_can_edit_active_oom() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = 'odberne_miesta' AND p.can_edit_active_oom)
$$;

-- ============================================================================
-- Prístup k OOM
-- ============================================================================

-- Zákazník (firma alebo domácnosť) patrí prihlásenému
CREATE FUNCTION crm_customer_owned(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company WHERE id = p_company_id AND owner_id = crm_active_user_id())
      OR EXISTS (SELECT 1 FROM contact WHERE id = p_person_id AND owner_id = crm_active_user_id())
$$;

-- Prístup k jednému OOM (pre podtabuľky a väzby): spoločnosť + rozsah tímu v module Odberné miesta
CREATE FUNCTION crm_oom_access(p_oom_id uuid, p_action text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM oom o
     WHERE o.id = p_oom_id
       AND o.org_id = ANY (crm_user_orgs())
       AND (crm_scope('odberne_miesta', p_action) = 'vsetko'
            OR (crm_scope('odberne_miesta', p_action) = 'iba_svoje' AND crm_customer_owned(o.company_id, o.person_id))))
$$;

ALTER TABLE oom ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON oom FOR SELECT USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('odberne_miesta', 'view')) = 'vsetko'
       OR ((SELECT crm_scope('odberne_miesta', 'view')) = 'iba_svoje' AND crm_customer_owned(company_id, person_id))));
CREATE POLICY oom_insert ON oom FOR INSERT WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('odberne_miesta', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('odberne_miesta', 'edit')) = 'iba_svoje' AND crm_customer_owned(company_id, person_id))));
CREATE POLICY oom_update ON oom FOR UPDATE USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('odberne_miesta', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('odberne_miesta', 'edit')) = 'iba_svoje' AND crm_customer_owned(company_id, person_id))))
WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('odberne_miesta', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('odberne_miesta', 'edit')) = 'iba_svoje' AND crm_customer_owned(company_id, person_id))));
-- DELETE: bez politiky – maže iba oom_delete (admin)

-- Väzby: vidí, kto vidí OOM alebo zákazníka väzby (história na karte starého zákazníka); mení, kto upravuje OOM.
ALTER TABLE oom_customer ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON oom_customer FOR SELECT USING (
  crm_oom_access(oom_id, 'view') OR crm_company_access(company_id, 'view') OR crm_contact_access(person_id, 'view'));
CREATE POLICY oom_insert ON oom_customer FOR INSERT WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_update ON oom_customer FOR UPDATE
  USING (crm_oom_access(oom_id, 'edit')) WITH CHECK (crm_oom_access(oom_id, 'edit'));

ALTER TABLE oom_device ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON oom_device FOR SELECT USING (crm_oom_access(oom_id, 'view'));
CREATE POLICY oom_insert ON oom_device FOR INSERT WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_update ON oom_device FOR UPDATE
  USING (crm_oom_access(oom_id, 'edit')) WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_delete ON oom_device FOR DELETE USING (crm_oom_access(oom_id, 'edit'));

ALTER TABLE oom_contact ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON oom_contact FOR SELECT USING (crm_oom_access(oom_id, 'view'));
CREATE POLICY oom_insert ON oom_contact FOR INSERT WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_update ON oom_contact FOR UPDATE
  USING (crm_oom_access(oom_id, 'edit')) WITH CHECK (crm_oom_access(oom_id, 'edit'));
CREATE POLICY oom_delete ON oom_contact FOR DELETE USING (crm_oom_access(oom_id, 'edit'));

-- Správy OKTE / PDS (neskôr): iba čítanie podľa prístupu k OOM, zapisuje synchronizácia
ALTER TABLE supplier_switch ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_select ON supplier_switch FOR SELECT USING (crm_oom_access(oom_id, 'view'));

-- ============================================================================
-- Úprava Aktívneho OOM iba s právom (Peter 12. 10.)
-- ============================================================================

-- Systémové kroky (prepis, mazanie adminom) si to povolia lokálne: set_config('crm.oom_system', 'on', true).
CREATE FUNCTION crm_oom_system_step() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT coalesce(current_setting('crm.oom_system', true), '') = 'on'
$$;

-- OOM: pri stave Aktívne sa bez práva nesmie zmeniť nič okrem zákazníka a stavu (tie menia
-- iba väzby – oom_set_status, oom_transfer – cez spúšťače, pg_trigger_depth >= 2).
CREATE FUNCTION oom_active_edit_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.status = 'aktivne' AND pg_trigger_depth() < 2 AND NOT crm_oom_system_step()
     AND NOT crm_can_edit_active_oom()
     AND (to_jsonb(NEW) - ARRAY['company_id', 'person_id', 'status', 'updated_at'])
         IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['company_id', 'person_id', 'status', 'updated_at']) THEN
    RAISE EXCEPTION 'Aktívne odberné miesto môže upravovať iba tím s právom „upravovať Aktívne OOM“.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_oom_active_edit BEFORE UPDATE ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_active_edit_guard();

-- Zariadenia a kontaktné osoby Aktívneho OOM
CREATE FUNCTION oom_child_active_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF (SELECT status FROM oom WHERE id = coalesce(NEW.oom_id, OLD.oom_id)) = 'aktivne'
     AND NOT crm_oom_system_step() AND NOT crm_can_edit_active_oom() THEN
    RAISE EXCEPTION 'Aktívne odberné miesto môže upravovať iba tím s právom „upravovať Aktívne OOM“.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_active_guard BEFORE INSERT OR UPDATE OR DELETE ON oom_device
  FOR EACH ROW EXECUTE FUNCTION oom_child_active_guard();
CREATE TRIGGER trg_active_guard BEFORE INSERT OR UPDATE OR DELETE ON oom_contact
  FOR EACH ROW EXECUTE FUNCTION oom_child_active_guard();

-- Prepis (0013) odoberá kontaktné osoby starého zákazníka aj pri Aktívnom OOM: systémový krok.
CREATE OR REPLACE FUNCTION oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prepísať sa dá iba Pripravované alebo Aktívne odberné miesto.' USING ERRCODE = 'check_violation';
  END IF;
  IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
    RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_date <= v_link.valid_from THEN
    RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom_customer SET valid_to = p_date - 1, end_reason = 'prepis', status = 'prepisane' WHERE id = v_link.id;
  PERFORM set_config('crm.oom_system', 'on', true);
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- ============================================================================
-- Kontrola duplicity EIC (príklad 7): iba „existuje“, vlastník a spoločnosť
-- ============================================================================

-- oom_id vráti iba tomu, kto OOM vidí. Príklad: SELECT * FROM oom_eic_check(' 24zzs… ');
CREATE FUNCTION oom_eic_check(p_eic text)
RETURNS TABLE (oom_exists boolean, oom_id uuid, owner_name text, org_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT true,
         CASE WHEN crm_oom_access(o.id, 'view') THEN o.id END,
         u.name,
         g.legal_name
    FROM oom o
    JOIN org g ON g.id = o.org_id
    LEFT JOIN company c ON c.id = o.company_id
    LEFT JOIN contact p ON p.id = o.person_id
    LEFT JOIN app_user u ON u.id = coalesce(c.owner_id, p.owner_id)
   WHERE o.eic = upper(regexp_replace(p_eic, '\s', '', 'g'))
$$;

-- ============================================================================
-- Import z Excelu: záznam a audit (návrh časť 9)
-- ============================================================================

CREATE TYPE oom_import_status AS ENUM ('ulozeny', 'zlyhal');

CREATE TABLE oom_import (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id         uuid NOT NULL REFERENCES org (id),
  user_id        uuid NOT NULL REFERENCES app_user (id),
  file_name      text NOT NULL CHECK (btrim(file_name) <> ''),
  row_count      integer NOT NULL CHECK (row_count >= 0),
  created_count  integer NOT NULL CHECK (created_count >= 0),
  updated_count  integer NOT NULL CHECK (updated_count >= 0),
  error_count    integer NOT NULL CHECK (error_count >= 0),
  status         oom_import_status NOT NULL,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oom_import_counts_check CHECK (created_count + updated_count + error_count <= row_count)
);
CREATE INDEX oom_import_created_at_idx ON oom_import (created_at);
COMMENT ON TABLE oom_import IS 'import OOM z Excelu: kto, kedy, súbor a počty (súbor ani náhľad sa neukladajú); zmeny OOM sú v audite s import_id';

ALTER TABLE oom_import ENABLE ROW LEVEL SECURITY;
CREATE POLICY oom_import_select ON oom_import FOR SELECT USING (
  (SELECT crm_is_service()) OR (SELECT crm_is_admin()) OR (SELECT crm_can_import('odberne_miesta')));
CREATE POLICY oom_import_insert ON oom_import FOR INSERT WITH CHECK (
  (SELECT crm_can_import('odberne_miesta'))
  AND (user_id = (SELECT crm_active_user_id()) OR (SELECT crm_is_service()))
  AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
-- UPDATE, DELETE: bez politiky – záznam importu sa nemení
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON oom_import FOR EACH ROW EXECUTE FUNCTION audit_row();

ALTER TYPE audit_source ADD VALUE IF NOT EXISTS 'import';   -- po návrate 0015 hodnota ostáva
ALTER TABLE audit_log ADD COLUMN import_id uuid REFERENCES oom_import (id);
CREATE INDEX audit_log_import_id_idx ON audit_log (import_id) WHERE import_id IS NOT NULL;
COMMENT ON COLUMN audit_log.import_id IS 'zmena urobená importom z Excelu (API nastaví SET LOCAL app.import_id); zdroj = import';

-- Ako v 0006, navyše import: app.import_id → audit_log.import_id a zdroj 'import'.
CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_old     jsonb;
  v_new     jsonb;
  v_diff    jsonb;
  v_id      uuid;
  v_user    uuid := nullif(current_setting('app.user_id', true), '')::uuid;
  v_import  uuid := nullif(current_setting('app.import_id', true), '')::uuid;
  v_source  audit_source;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_new  := to_jsonb(NEW);
    v_id   := NEW.id;
    v_diff := v_new;
  ELSIF TG_OP = 'DELETE' THEN
    v_old  := to_jsonb(OLD);
    v_id   := OLD.id;
    v_diff := v_old;
  ELSE
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_id  := NEW.id;
    -- bežné stĺpce (bez updated_at a last_login_at) + vlastné polia po kľúčoch
    SELECT jsonb_object_agg(d.k, jsonb_build_object('old', d.o, 'new', d.n))
      INTO v_diff
      FROM (
        SELECT n.key AS k, v_old -> n.key AS o, n.value AS n
          FROM jsonb_each(v_new) AS n
         WHERE n.key NOT IN ('updated_at', 'last_login_at', 'custom')
           AND n.value IS DISTINCT FROM v_old -> n.key
        UNION ALL
        SELECT 'custom.' || ks.key, v_old -> 'custom' -> ks.key, v_new -> 'custom' -> ks.key
          FROM (SELECT jsonb_object_keys(CASE jsonb_typeof(v_new -> 'custom') WHEN 'object' THEN v_new -> 'custom' ELSE '{}' END)
                UNION
                SELECT jsonb_object_keys(CASE jsonb_typeof(v_old -> 'custom') WHEN 'object' THEN v_old -> 'custom' ELSE '{}' END)
               ) AS ks (key)
         WHERE v_new -> 'custom' -> ks.key IS DISTINCT FROM v_old -> 'custom' -> ks.key
      ) d;
    IF v_diff IS NULL THEN
      RETURN NEW;  -- nič sa nezmenilo (alebo iba čas prihlásenia)
    END IF;
  END IF;

  v_source := coalesce(
    nullif(current_setting('app.change_source', true), '')::audit_source,
    CASE WHEN v_import IS NOT NULL THEN 'import'
         WHEN current_user = 'crm_sync' THEN 'synchronizacia'
         WHEN v_user IS NOT NULL THEN 'aplikacia'
         ELSE 'system' END::audit_source);

  INSERT INTO audit_log (table_name, record_id, action, changed_by, diff, source, import_id)
  VALUES (TG_TABLE_NAME, v_id, lower(TG_OP)::audit_action, v_user, v_diff, v_source, v_import);

  RETURN coalesce(NEW, OLD);
END;
$$;

-- ============================================================================
-- Mazanie OOM (iba admin, iba bez väzieb – ako 0011 pri zákazníkoch)
-- ============================================================================

-- Väzby na zákazníka, kontaktné osoby a zariadenia sa zmažú spolu s OOM; audit zapíše celý obsah.
-- Príklad: SELECT oom_delete('<id>') → '24ZZS…'
CREATE FUNCTION oom_delete(p_oom_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_eic   text;
  v_links text[];
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Zmazať odberné miesto môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT crm_oom_access(p_oom_id, 'view') THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT eic INTO v_eic FROM oom WHERE id = p_oom_id;
  v_links := array_remove(ARRAY[
    CASE WHEN EXISTS (SELECT 1 FROM deal_oom WHERE oom_id = p_oom_id) THEN 'dealy' END,
    CASE WHEN EXISTS (SELECT 1 FROM contract_price WHERE oom_id = p_oom_id) THEN 'ceny zo zmlúv' END,
    CASE WHEN EXISTS (SELECT 1 FROM offer_item WHERE oom_id = p_oom_id) THEN 'položky ponúk' END,
    CASE WHEN EXISTS (SELECT 1 FROM activity WHERE oom_id = p_oom_id) THEN 'aktivity' END,
    CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE oom_id = p_oom_id) THEN 'konverzácie' END,
    CASE WHEN EXISTS (SELECT 1 FROM supplier_switch WHERE oom_id = p_oom_id) THEN 'správy OKTE / PDS' END
  ], NULL);
  IF cardinality(v_links) > 0 THEN
    RAISE EXCEPTION 'Odberné miesto má väzby (%), nedá sa zmazať – iba zrušiť.', array_to_string(v_links, ', ')
      USING ERRCODE = 'check_violation';
  END IF;

  PERFORM set_config('crm.oom_system', 'on', true);
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  DELETE FROM oom_device WHERE oom_id = p_oom_id;
  DELETE FROM oom_customer WHERE oom_id = p_oom_id;
  DELETE FROM oom WHERE id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  RETURN v_eic;
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS oom_delete(uuid);

-- audit_row ako v 0006 (bez importu); hodnota 'import' v enume audit_source ostáva (enum sa nezmenšuje)
CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_old     jsonb;
  v_new     jsonb;
  v_diff    jsonb;
  v_id      uuid;
  v_user    uuid := nullif(current_setting('app.user_id', true), '')::uuid;
  v_source  audit_source;
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_new  := to_jsonb(NEW);
    v_id   := NEW.id;
    v_diff := v_new;
  ELSIF TG_OP = 'DELETE' THEN
    v_old  := to_jsonb(OLD);
    v_id   := OLD.id;
    v_diff := v_old;
  ELSE
    v_old := to_jsonb(OLD);
    v_new := to_jsonb(NEW);
    v_id  := NEW.id;
    -- bežné stĺpce (bez updated_at a last_login_at) + vlastné polia po kľúčoch
    SELECT jsonb_object_agg(d.k, jsonb_build_object('old', d.o, 'new', d.n))
      INTO v_diff
      FROM (
        SELECT n.key AS k, v_old -> n.key AS o, n.value AS n
          FROM jsonb_each(v_new) AS n
         WHERE n.key NOT IN ('updated_at', 'last_login_at', 'custom')
           AND n.value IS DISTINCT FROM v_old -> n.key
        UNION ALL
        SELECT 'custom.' || ks.key, v_old -> 'custom' -> ks.key, v_new -> 'custom' -> ks.key
          FROM (SELECT jsonb_object_keys(CASE jsonb_typeof(v_new -> 'custom') WHEN 'object' THEN v_new -> 'custom' ELSE '{}' END)
                UNION
                SELECT jsonb_object_keys(CASE jsonb_typeof(v_old -> 'custom') WHEN 'object' THEN v_old -> 'custom' ELSE '{}' END)
               ) AS ks (key)
         WHERE v_new -> 'custom' -> ks.key IS DISTINCT FROM v_old -> 'custom' -> ks.key
      ) d;
    IF v_diff IS NULL THEN
      RETURN NEW;  -- nič sa nezmenilo (alebo iba čas prihlásenia)
    END IF;
  END IF;

  v_source := coalesce(
    nullif(current_setting('app.change_source', true), '')::audit_source,
    CASE WHEN current_user = 'crm_sync' THEN 'synchronizacia'
         WHEN v_user IS NOT NULL THEN 'aplikacia'
         ELSE 'system' END::audit_source);

  INSERT INTO audit_log (table_name, record_id, action, changed_by, diff, source)
  VALUES (TG_TABLE_NAME, v_id, lower(TG_OP)::audit_action, v_user, v_diff, v_source);

  RETURN coalesce(NEW, OLD);
END;
$$;

DROP INDEX IF EXISTS audit_log_import_id_idx;
ALTER TABLE audit_log DROP COLUMN IF EXISTS import_id;
DROP TABLE IF EXISTS oom_import;
DROP TYPE IF EXISTS oom_import_status;

DROP FUNCTION IF EXISTS oom_eic_check(text);

-- oom_transfer ako v 0013
CREATE OR REPLACE FUNCTION oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prepísať sa dá iba Pripravované alebo Aktívne odberné miesto.' USING ERRCODE = 'check_violation';
  END IF;
  IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
    RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_date <= v_link.valid_from THEN
    RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom_customer SET valid_to = p_date - 1, end_reason = 'prepis', status = 'prepisane' WHERE id = v_link.id;
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

DROP TRIGGER IF EXISTS trg_active_guard ON oom_contact;
DROP TRIGGER IF EXISTS trg_active_guard ON oom_device;
DROP FUNCTION IF EXISTS oom_child_active_guard();
DROP TRIGGER IF EXISTS trg_oom_active_edit ON oom;
DROP FUNCTION IF EXISTS oom_active_edit_guard();
DROP FUNCTION IF EXISTS crm_oom_system_step();

DROP POLICY IF EXISTS oom_select ON supplier_switch;
ALTER TABLE supplier_switch DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oom_delete ON oom_contact;
DROP POLICY IF EXISTS oom_update ON oom_contact;
DROP POLICY IF EXISTS oom_insert ON oom_contact;
DROP POLICY IF EXISTS oom_select ON oom_contact;
ALTER TABLE oom_contact DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oom_delete ON oom_device;
DROP POLICY IF EXISTS oom_update ON oom_device;
DROP POLICY IF EXISTS oom_insert ON oom_device;
DROP POLICY IF EXISTS oom_select ON oom_device;
ALTER TABLE oom_device DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oom_update ON oom_customer;
DROP POLICY IF EXISTS oom_insert ON oom_customer;
DROP POLICY IF EXISTS oom_select ON oom_customer;
ALTER TABLE oom_customer DISABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS oom_update ON oom;
DROP POLICY IF EXISTS oom_insert ON oom;
DROP POLICY IF EXISTS oom_select ON oom;
ALTER TABLE oom DISABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS crm_oom_access(uuid, text);
DROP FUNCTION IF EXISTS crm_customer_owned(uuid, uuid);
DROP FUNCTION IF EXISTS crm_can_edit_active_oom();
DROP FUNCTION IF EXISTS crm_can_import(crm_module);

-- Východiskové práva modulu Odberné miesta späť (iba bunky, ktoré 0015 nastavila)
UPDATE team_permission p SET edit_scope = 'nic'
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'odberne_miesta' AND t.code IN ('sales_internal', 'servis')
   AND p.edit_scope = 'vsetko';
UPDATE team_permission p SET edit_scope = 'nic'
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'odberne_miesta' AND t.code = 'sales_external'
   AND p.edit_scope = 'iba_svoje';
ALTER TABLE team_permission
  DROP CONSTRAINT IF EXISTS team_permission_edit_active_oom_check,
  DROP COLUMN IF EXISTS can_edit_active_oom,
  DROP COLUMN IF EXISTS can_import;
