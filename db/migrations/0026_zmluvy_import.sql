-- migrate:up

-- ============================================================================
-- 1. Importy zmlúv a história importov na zmluve
-- ============================================================================

CREATE TABLE contract_import (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  user_id      uuid REFERENCES app_user (id),
  op_file_name text,
  op_file_hash text,
  xm_file_name text,
  xm_file_hash text,
  counts       jsonb NOT NULL DEFAULT '{}',
  created_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_import_file_check CHECK (op_file_name IS NOT NULL OR xm_file_name IS NOT NULL)
);
COMMENT ON TABLE contract_import IS 'import zmlúv (Office portal) a OOM (XM Trade): kto, kedy, súbory (názov, odtlačok) a počty; súbory sa neukladajú';
COMMENT ON COLUMN contract_import.user_id IS 'kto import uložil; NULL = systém (servisný prístup)';

CREATE TABLE contract_import_change (
  import_id   uuid NOT NULL REFERENCES contract_import (id),
  contract_id uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  action      text NOT NULL CHECK (action IN ('nova', 'zmena')),
  summary     text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (import_id, contract_id)
);
CREATE INDEX contract_import_change_contract_idx ON contract_import_change (contract_id);
COMMENT ON TABLE contract_import_change IS 'história importov na karte zmluvy: čo import zmenil (bez osobných údajov)';

ALTER TABLE contract ADD COLUMN last_import_id uuid REFERENCES contract_import (id);
COMMENT ON COLUMN contract.last_import_id IS 'posledný import, ktorý zmluvu založil alebo zmenil';

-- Audit: zmeny z importu zmlúv nesú odkaz na import (import OOM zo šablóny ostáva v import_id)
ALTER TABLE audit_log ADD COLUMN contract_import_id uuid REFERENCES contract_import (id);
CREATE INDEX audit_log_contract_import_id_idx ON audit_log (contract_import_id) WHERE contract_import_id IS NOT NULL;
COMMENT ON COLUMN audit_log.contract_import_id IS 'zmena urobená importom zmlúv / XM Trade (app.contract_import_id); zdroj = import';

CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_old     jsonb;
  v_new     jsonb;
  v_diff    jsonb;
  v_id      uuid;
  v_user    uuid := nullif(current_setting('app.user_id', true), '')::uuid;
  v_import  uuid := nullif(current_setting('app.import_id', true), '')::uuid;
  v_cimport uuid := nullif(current_setting('app.contract_import_id', true), '')::uuid;
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
    CASE WHEN v_import IS NOT NULL OR v_cimport IS NOT NULL THEN 'import'
         WHEN current_user = 'crm_sync' THEN 'synchronizacia'
         WHEN v_user IS NOT NULL THEN 'aplikacia'
         ELSE 'system' END::audit_source);

  INSERT INTO audit_log (table_name, record_id, action, changed_by, diff, source, import_id, contract_import_id)
  VALUES (TG_TABLE_NAME, v_id, lower(TG_OP)::audit_action, v_user, v_diff, v_source, v_import, v_cimport);

  RETURN coalesce(NEW, OLD);
END;
$$;


-- ============================================================================
-- 2. Zákazník: Osoba_ID z Office portálu a príznak „založený importom“
-- ============================================================================

ALTER TABLE company
  ADD COLUMN op_person_id uuid,
  ADD COLUMN created_by_import uuid REFERENCES contract_import (id);
ALTER TABLE contact
  ADD COLUMN op_person_id uuid,
  ADD COLUMN created_by_import uuid REFERENCES contract_import (id);
CREATE UNIQUE INDEX company_op_person_key ON company (org_id, op_person_id) WHERE op_person_id IS NOT NULL;
CREATE UNIQUE INDEX contact_op_person_key ON contact (org_id, op_person_id) WHERE op_person_id IS NOT NULL;
COMMENT ON COLUMN company.op_person_id IS 'Osoba_ID zákazníka v Office portáli (párovanie importu zmlúv)';
COMMENT ON COLUMN contact.op_person_id IS 'Osoba_ID zákazníka v Office portáli (párovanie domácností pri importe zmlúv)';
COMMENT ON COLUMN company.created_by_import IS 'založený importom zmlúv; zruší prvá ručná úprava alebo „Skontrolované“';
COMMENT ON COLUMN contact.created_by_import IS 'založený importom zmlúv; zruší prvá ručná úprava alebo „Skontrolované“';

-- Domácnosť z Office portálu nemá e-mail ani telefón: osoba založená importom je výnimka, kým ju niekto neskontroluje
ALTER TABLE contact DROP CONSTRAINT contact_reachable_check;
ALTER TABLE contact ADD CONSTRAINT contact_reachable_check CHECK (
  num_nonnulls(nullif(btrim(email), ''), nullif(btrim(phone), ''), nullif(btrim(mobile), '')) >= 1
  OR created_by_import IS NOT NULL);

-- Prvá ručná úprava zákazníka zruší príznak „založený importom“ (nie zmeny stavu, väzieb a importu).
-- Osoba bez e-mailu a telefónu príznak drží, kým sa kontakt nedoplní (inak by úprava zlyhala na kontrole dosiahnuteľnosti).
CREATE FUNCTION customer_import_flag_clear() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  c_skip constant text[] := ARRAY['updated_at', 'status', 'status_source', 'status_changed_at', 'is_household',
                                  'is_former_customer', 'is_producer', 'op_person_id', 'created_by_import',
                                  'phone_norm', 'mobile_norm'];
  v jsonb;
BEGIN
  IF OLD.created_by_import IS NOT NULL AND NEW.created_by_import IS NOT DISTINCT FROM OLD.created_by_import
     AND coalesce(current_setting('crm.contract_import', true), '') <> 'on'
     AND (to_jsonb(NEW) - c_skip) <> (to_jsonb(OLD) - c_skip) THEN
    v := to_jsonb(NEW);
    IF TG_TABLE_NAME = 'company'
       OR num_nonnulls(nullif(btrim(v ->> 'email'), ''), nullif(btrim(v ->> 'phone'), ''), nullif(btrim(v ->> 'mobile'), '')) >= 1 THEN
      NEW.created_by_import := NULL;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_import_flag BEFORE UPDATE ON company FOR EACH ROW EXECUTE FUNCTION customer_import_flag_clear();
CREATE TRIGGER trg_import_flag BEFORE UPDATE ON contact FOR EACH ROW EXECUTE FUNCTION customer_import_flag_clear();

-- ============================================================================
-- 3. OOM: trieda TDO (XM Trade, otázka 14); import OOM: trieda TDO a zmena regulácie s „platí od“ dnes (otázka 19)
-- ============================================================================

ALTER TABLE oom ADD COLUMN tdo_class text CHECK (btrim(tdo_class) <> '');
COMMENT ON COLUMN oom.tdo_class IS 'trieda TDO z XM Trade (napr. „TDO 4“); aj pre Cockpit';

-- Import OOM (0018) s triedou TDO; zmena regulácie existujúceho OOM ide do histórie s „platí od“ dnes
CREATE OR REPLACE FUNCTION oom_import_rows(p_org uuid, p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  -- polia, ktoré import smie meniť (zákazník, stav, spoločnosť a kroky prechodu nie)
  c_cols constant text[] := ARRAY[
    'type', 'name', 'address_street', 'address_number_supisne', 'address_number_orientacne', 'address_zip', 'address_city',
    'pds', 'pds_tariff', 'pds_point_id', 'voltage_level', 'metering_type', 'phases', 'breaker_a', 'reserved_capacity_kw',
    'max_reserved_capacity_kw', 'capacity_reservation_method', 'planned_consumption_vt_mwh', 'planned_consumption_nt_mwh',
    'planned_feed_in_mwh', 'supply_from', 'price_regulation', 'excise_tax', 'billing_period', 'advance_payment_method',
    'advance_payment_pct', 'advance_payment_eur', 'source_kind', 'source_category', 'source_power_kw', 'inverter_power_kw',
    'panels_power_kw', 'feed_in_contract_type', 'tdo_class'];
  c_lookups constant jsonb := '{"pds": "pds", "metering_type": "typ_merania", "billing_period": "fakturacne_obdobie",
                                "advance_payment_method": "sposob_zaloh", "feed_in_contract_type": "typ_vykupnej_zmluvy"}';
  v_country  country_code := (SELECT country FROM org WHERE id = p_org);
  v_out      jsonb := '[]';
  v_dups     jsonb;          -- EIC, ktoré sú v súbore viackrát → čísla ich riadkov (chybné sú všetky)
  r          jsonb;
  v_res      jsonb;
  v_eic      text;
  v_fields   jsonb;
  v_custom   jsonb;
  v_cust_new jsonb;
  v_company  uuid;
  v_person   uuid;
  v_n        integer;
  v_old      oom;
  v_rec      oom;
  v_key      text;
  v_val      jsonb;
  v_def      record;
  v_changes  jsonb;
  v_cons     text;
  v_msg      text;
  v_id       uuid;
  v_touched  jsonb := '{}';   -- zákazníci nových a zmenených OOM (prepočet stavu raz na konci)
  v_cust     record;
BEGIN
  PERFORM set_config('crm.oom_bulk', 'on', true);
  SELECT coalesce(jsonb_object_agg(eic, rows_), '{}') INTO v_dups
    FROM (SELECT x ->> 'eic' AS eic, jsonb_agg(x -> 'row' ORDER BY (x ->> 'row')::int) AS rows_
            FROM jsonb_array_elements(p_rows) x
           WHERE nullif(x ->> 'eic', '') IS NOT NULL
           GROUP BY 1 HAVING count(*) > 1) d;
  FOR r IN SELECT x FROM jsonb_array_elements(p_rows) x LOOP
    v_eic := nullif(r ->> 'eic', '');
    v_res := jsonb_build_object('row', r -> 'row', 'eic', v_eic);
    IF jsonb_array_length(coalesce(r -> 'parse_errors', '[]')) > 0 THEN
      v_out := v_out || (v_res || jsonb_build_object('action', 'chyba', 'error',
                 (SELECT string_agg(e, ' ') FROM jsonb_array_elements_text(r -> 'parse_errors') e)));
      CONTINUE;
    END IF;
    IF v_eic IS NULL THEN
      v_out := v_out || (v_res || '{"action": "chyba", "error": "Chýba EIC."}');
      CONTINUE;
    END IF;
    IF v_dups ? v_eic THEN
      v_out := v_out || (v_res || jsonb_build_object('action', 'chyba',
                 'error', format('EIC je v súbore viackrát (riadky %s) – nechajte ho v jednom riadku.',
                                 (SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(v_dups -> v_eic) x))));
      CONTINUE;
    END IF;

    BEGIN
      v_fields := coalesce(r -> 'fields', '{}');
      v_custom := '{}';
      v_company := NULL;
      v_person := NULL;

      -- zákazník: ID z CRM → IČO (firma) → e-mail (domácnosť), v spoločnosti importu
      IF nullif(r ->> 'customer_id', '') IS NOT NULL THEN
        SELECT id INTO v_company FROM company WHERE id::text = r ->> 'customer_id' AND org_id = p_org;
        IF v_company IS NULL THEN
          SELECT id INTO v_person FROM contact WHERE id::text = r ->> 'customer_id' AND org_id = p_org;
        END IF;
        IF v_company IS NULL AND v_person IS NULL THEN
          RAISE EXCEPTION 'Zákazník s ID % v CRM nie je (alebo k nemu nemáte prístup).', r ->> 'customer_id' USING ERRCODE = 'P0002';
        END IF;
      ELSIF nullif(r ->> 'ico', '') IS NOT NULL THEN
        SELECT id INTO v_company FROM company
         WHERE country = v_country AND org_id = p_org
           AND ico = CASE WHEN v_country = 'HR' THEN regexp_replace(r ->> 'ico', '\D', '', 'g')
                          ELSE lpad(regexp_replace(r ->> 'ico', '\D', '', 'g'), 8, '0') END;
        IF v_company IS NULL THEN
          RAISE EXCEPTION 'Firma s IČO % v CRM nie je (alebo k nej nemáte prístup).', r ->> 'ico' USING ERRCODE = 'P0002';
        END IF;
      ELSIF nullif(r ->> 'email', '') IS NOT NULL THEN
        SELECT count(*), min(id::text)::uuid INTO v_n, v_person FROM contact
         WHERE org_id = p_org AND lower(btrim(email)) = lower(btrim(r ->> 'email'));
        IF v_n = 0 THEN
          RAISE EXCEPTION 'Osoba s e-mailom % v CRM nie je (alebo k nej nemáte prístup).', r ->> 'email' USING ERRCODE = 'P0002';
        ELSIF v_n > 1 THEN
          RAISE EXCEPTION 'E-mail % má v CRM viac osôb – použite stĺpec ID zákazníka.', r ->> 'email' USING ERRCODE = 'P0002';
        END IF;
      END IF;

      SELECT * INTO v_old FROM oom WHERE eic = v_eic;
      IF NOT FOUND AND EXISTS (SELECT 1 FROM oom_eic_check(v_eic)) THEN
        RAISE EXCEPTION 'Odberné miesto s týmto EIC už v CRM je, ale nemáte k nemu prístup (vlastník %).',
          (SELECT owner_name FROM oom_eic_check(v_eic) LIMIT 1) USING ERRCODE = 'insufficient_privilege';
      END IF;
      IF v_old.id IS NOT NULL AND v_old.org_id <> p_org THEN
        RAISE EXCEPTION 'Odberné miesto patrí inej spoločnosti skupiny.' USING ERRCODE = 'check_violation';
      END IF;

      -- číselníky: názov → kód; sadzba podľa PDS (z riadku alebo existujúceho OOM)
      FOR v_key IN SELECT jsonb_object_keys(c_lookups) LOOP
        IF nullif(v_fields ->> v_key, '') IS NOT NULL THEN
          v_fields := v_fields || jsonb_build_object(v_key, oom_import_lookup(c_lookups ->> v_key, p_org, v_fields ->> v_key));
        END IF;
      END LOOP;
      IF nullif(v_fields ->> 'pds_tariff', '') IS NOT NULL THEN
        IF coalesce(v_fields ->> 'pds', v_old.pds) IS NULL THEN
          RAISE EXCEPTION 'Sadzba bez PDS: vyplňte aj PDS.' USING ERRCODE = 'check_violation';
        END IF;
        v_fields := v_fields || jsonb_build_object('pds_tariff',
          oom_import_lookup('sadzba_distribucie', p_org, v_fields ->> 'pds_tariff', coalesce(v_fields ->> 'pds', v_old.pds)));
      END IF;

      -- vlastné polia: text → hodnota podľa typu poľa
      FOR v_key, v_val IN SELECT * FROM jsonb_each(coalesce(r -> 'custom', '{}')) LOOP
        CONTINUE WHEN v_val IS NULL OR v_val = 'null'::jsonb OR btrim(v_val #>> '{}') = '';
        SELECT f.id, f.label, f.field_type INTO v_def FROM custom_field f
         WHERE f.entity = 'oom' AND f.key = v_key AND f.archived_at IS NULL AND (f.org_id IS NULL OR f.org_id = p_org);
        IF NOT FOUND THEN
          RAISE EXCEPTION 'Neznáme vlastné pole „%“.', v_key USING ERRCODE = 'check_violation';
        END IF;
        v_custom := v_custom || jsonb_build_object(v_key, CASE v_def.field_type
          WHEN 'ano_nie' THEN CASE WHEN lower(btrim(v_val #>> '{}')) IN ('áno', 'ano', 'a', 'true', '1', 'yes') THEN 'true'::jsonb
                                   WHEN lower(btrim(v_val #>> '{}')) IN ('nie', 'n', 'false', '0', 'no') THEN 'false'::jsonb END
          WHEN 'cislo' THEN to_jsonb(replace(replace(v_val #>> '{}', ' ', ''), ',', '.')::numeric)
          WHEN 'suma' THEN to_jsonb(replace(replace(v_val #>> '{}', ' ', ''), ',', '.')::numeric)
          WHEN 'vyber' THEN (SELECT to_jsonb(o.id) FROM custom_field_option o
                              WHERE o.field_id = v_def.id AND o.hidden_at IS NULL AND lower(btrim(o.label)) = lower(btrim(v_val #>> '{}')))
          -- dátum: číslo z Excelu (dni od 30. 12. 1899), RRRR-MM-DD alebo D. M. RRRR
          WHEN 'datum' THEN to_jsonb(to_char(CASE
            WHEN jsonb_typeof(v_val) = 'number' THEN date '1899-12-30' + floor((v_val #>> '{}')::numeric)::int
            WHEN v_val #>> '{}' ~ '^\d{4}-\d{2}-\d{2}$' THEN (v_val #>> '{}')::date
            ELSE to_date(regexp_replace(v_val #>> '{}', '\s', '', 'g'), 'DD.MM.YYYY') END, 'YYYY-MM-DD'))
          WHEN 'text' THEN to_jsonb(btrim(v_val #>> '{}'))
          WHEN 'dlhy_text' THEN to_jsonb(btrim(v_val #>> '{}'))
        END);
        IF v_custom -> v_key IS NULL OR v_custom -> v_key = 'null'::jsonb THEN
          RAISE EXCEPTION 'Vlastné pole „%“: hodnota „%“ sa nedá použiť%.', v_def.label, v_val #>> '{}',
            CASE WHEN v_def.field_type IN ('vyber_viac', 'odkaz') THEN ' (tento typ poľa import nepodporuje)' ELSE '' END
            USING ERRCODE = 'check_violation';
        END IF;
      END LOOP;

      IF v_old.id IS NULL THEN
        -- nové OOM: zákazník a typ povinné, stav vždy Pripravované
        IF v_company IS NULL AND v_person IS NULL THEN
          RAISE EXCEPTION 'Nové odberné miesto: chýba zákazník (ID zákazníka, IČO alebo e-mail).' USING ERRCODE = 'check_violation';
        END IF;
        IF nullif(v_fields ->> 'type', '') IS NULL THEN
          RAISE EXCEPTION 'Nové odberné miesto: chýba typ (spotreba, výroba, sharing).' USING ERRCODE = 'check_violation';
        END IF;
        v_rec := jsonb_populate_record(NULL::oom, v_fields);
        INSERT INTO oom (company_id, person_id, eic, status, switch_notice_required, custom,
                         type, name, address_street, address_number_supisne, address_number_orientacne, address_zip, address_city,
                         pds, pds_tariff, pds_point_id, voltage_level, metering_type, phases, breaker_a, reserved_capacity_kw,
                         max_reserved_capacity_kw, capacity_reservation_method, planned_consumption_vt_mwh, planned_consumption_nt_mwh,
                         planned_feed_in_mwh, supply_from, price_regulation, excise_tax, billing_period, advance_payment_method,
                         advance_payment_pct, advance_payment_eur, source_kind, source_category, source_power_kw, inverter_power_kw,
                         panels_power_kw, feed_in_contract_type, tdo_class)
        VALUES (v_company, v_person, v_eic, 'pripravovane', true, v_custom,
                v_rec.type, v_rec.name, v_rec.address_street, v_rec.address_number_supisne, v_rec.address_number_orientacne,
                v_rec.address_zip, v_rec.address_city, v_rec.pds, v_rec.pds_tariff, v_rec.pds_point_id, v_rec.voltage_level,
                v_rec.metering_type, v_rec.phases, v_rec.breaker_a, v_rec.reserved_capacity_kw, v_rec.max_reserved_capacity_kw,
                v_rec.capacity_reservation_method, v_rec.planned_consumption_vt_mwh, v_rec.planned_consumption_nt_mwh,
                v_rec.planned_feed_in_mwh, v_rec.supply_from, v_rec.price_regulation, v_rec.excise_tax, v_rec.billing_period,
                v_rec.advance_payment_method, v_rec.advance_payment_pct, v_rec.advance_payment_eur, v_rec.source_kind,
                v_rec.source_category, v_rec.source_power_kw, v_rec.inverter_power_kw, v_rec.panels_power_kw,
                v_rec.feed_in_contract_type, v_rec.tdo_class)
        RETURNING id INTO v_id;
        v_touched := v_touched || jsonb_build_object(coalesce(v_company, v_person)::text, jsonb_build_array(v_company, v_person));
        v_res := v_res || jsonb_build_object('action', 'nove', 'oom_id', v_id,
                   'customer', (SELECT customer_name FROM oom_v WHERE id = v_id));
      ELSE
        -- zmena: zákazník (ak je v riadku) sa musí zhodovať; prázdne bunky sa nemenia
        IF (v_company IS NOT NULL OR v_person IS NOT NULL)
           AND (v_company, v_person) IS DISTINCT FROM (v_old.company_id, v_old.person_id) THEN
          RAISE EXCEPTION 'Zákazník v riadku sa nezhoduje s aktuálnym zákazníkom OOM – prepis urobte na karte OOM.'
            USING ERRCODE = 'check_violation';
        END IF;
        v_rec := jsonb_populate_record(v_old, v_fields);
        -- prázdna regulácia v súbore reguláciu nezruší (0026)
        v_rec.price_regulation := coalesce(v_rec.price_regulation, v_old.price_regulation);
        -- zmeny: iba stĺpce importu, ktorých hodnota sa líši (popisy číselníkov namiesto kódov)
        SELECT coalesce(jsonb_agg(jsonb_build_object('field', k,
                 'old', CASE WHEN c_lookups ? k THEN (SELECT label FROM lookup_value WHERE list_code = c_lookups ->> k AND code = o ->> k)
                             WHEN k = 'pds_tariff' THEN (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = o ->> k)
                             ELSE o ->> k END,
                 'new', CASE WHEN c_lookups ? k THEN (SELECT label FROM lookup_value WHERE list_code = c_lookups ->> k AND code = n ->> k)
                             WHEN k = 'pds_tariff' THEN (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = n ->> k)
                             ELSE n ->> k END)), '[]')
          INTO v_changes
          FROM unnest(c_cols) k, LATERAL (SELECT to_jsonb(v_old) o, to_jsonb(v_rec) n) x
         WHERE (o -> k) IS DISTINCT FROM (n -> k);
        SELECT v_changes || coalesce(jsonb_agg(jsonb_build_object('field', 'custom.' || ks.key, 'old', v_old.custom ->> ks.key, 'new', ks.value #>> '{}')), '[]')
          INTO v_changes
          FROM jsonb_each(v_custom) ks
         WHERE v_old.custom -> ks.key IS DISTINCT FROM ks.value;
        IF jsonb_array_length(v_changes) = 0 THEN
          v_res := v_res || jsonb_build_object('action', 'bez_zmeny', 'oom_id', v_old.id,
                     'customer', (SELECT customer_name FROM oom_v WHERE id = v_old.id));
        ELSE
          UPDATE oom SET
            type = v_rec.type, name = v_rec.name, address_street = v_rec.address_street,
            address_number_supisne = v_rec.address_number_supisne, address_number_orientacne = v_rec.address_number_orientacne,
            address_zip = v_rec.address_zip, address_city = v_rec.address_city, pds = v_rec.pds, pds_tariff = v_rec.pds_tariff,
            pds_point_id = v_rec.pds_point_id, voltage_level = v_rec.voltage_level, metering_type = v_rec.metering_type,
            phases = v_rec.phases, breaker_a = v_rec.breaker_a, reserved_capacity_kw = v_rec.reserved_capacity_kw,
            max_reserved_capacity_kw = v_rec.max_reserved_capacity_kw, capacity_reservation_method = v_rec.capacity_reservation_method,
            planned_consumption_vt_mwh = v_rec.planned_consumption_vt_mwh, planned_consumption_nt_mwh = v_rec.planned_consumption_nt_mwh,
            planned_feed_in_mwh = v_rec.planned_feed_in_mwh, supply_from = v_rec.supply_from,
            excise_tax = v_rec.excise_tax, billing_period = v_rec.billing_period,
            advance_payment_method = v_rec.advance_payment_method, advance_payment_pct = v_rec.advance_payment_pct,
            advance_payment_eur = v_rec.advance_payment_eur, source_kind = v_rec.source_kind, source_category = v_rec.source_category,
            source_power_kw = v_rec.source_power_kw, inverter_power_kw = v_rec.inverter_power_kw, panels_power_kw = v_rec.panels_power_kw,
            feed_in_contract_type = v_rec.feed_in_contract_type, tdo_class = v_rec.tdo_class,
            custom = custom || v_custom
           WHERE id = v_old.id;
          IF NOT FOUND THEN
            RAISE EXCEPTION 'Toto odberné miesto nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
          END IF;
          -- zmena cenovej regulácie = zmena s „platí od“ dnes, zapíše sa do histórie (0026, otázka 19)
          IF v_rec.price_regulation IS DISTINCT FROM v_old.price_regulation THEN
            PERFORM oom_price_regulation_set(v_old.id, v_rec.price_regulation, crm_today());
          END IF;
          v_touched := v_touched || jsonb_build_object(coalesce(v_old.company_id, v_old.person_id)::text,
                                                       jsonb_build_array(v_old.company_id, v_old.person_id));
          v_res := v_res || jsonb_build_object('action', 'zmena', 'oom_id', v_old.id, 'changes', v_changes,
                     'customer', (SELECT customer_name FROM oom_v WHERE id = v_old.id));
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_cons = CONSTRAINT_NAME, v_msg = MESSAGE_TEXT;
      v_res := v_res || jsonb_build_object('action', 'chyba', 'error', CASE coalesce(v_cons, '')
        WHEN 'oom_eic_check' THEN 'Neplatný formát alebo kontrolná číslica EIC.'
        WHEN 'oom_eic_key' THEN 'Odberné miesto s týmto EIC už v CRM je.'
        WHEN 'oom_phases_check' THEN 'Počet fáz: 1 alebo 3.'
        WHEN 'oom_advance_pct_check' THEN 'Záloha v percentách: 0 až 100.'
        WHEN 'oom_supply_period_check' THEN 'Dodávka do nemôže byť pred dodávkou od.'
        ELSE CASE WHEN SQLSTATE IN ('22P02', '22007', '22008', '22003') THEN 'Neplatná hodnota v riadku (číslo alebo dátum).'
                  ELSE v_msg END END);
    END;
    v_out := v_out || v_res;
  END LOOP;
  PERFORM set_config('crm.oom_bulk', '', true);
  IF crm_setting_on('customer_status_auto') THEN
    FOR v_cust IN SELECT (value ->> 0)::uuid AS company_id, (value ->> 1)::uuid AS person_id FROM jsonb_each(v_touched) LOOP
      PERFORM customer_refresh(v_cust.company_id, v_cust.person_id);
    END LOOP;
  END IF;
  RETURN v_out;
END;
$_$;


-- ============================================================================
-- 4. OOM v zmluve: program (VBattery) popri produkte dodávky
-- ============================================================================

ALTER TABLE contract_oom ADD COLUMN program_id uuid REFERENCES product (id);
CREATE INDEX contract_oom_program_idx ON contract_oom (program_id);
COMMENT ON COLUMN contract_oom.product_id IS 'produkt dodávky pri OOM: IN GREEN 1T/2T, DDx ANO/NIE, DMPx; pri VBattery DDx z XM Trade';
COMMENT ON COLUMN contract_oom.program_id IS 'program pri OOM (VBattery STANDARD, PREMIUM, MAX, AKU, V) z Office portálu';

-- ============================================================================
-- 5. Zmluva: balík VIWA zadá Servis v CRM (otázka 20), obchodníka zmení vedenie; ceny cenníka pri zmene balíka
-- ============================================================================

ALTER TABLE contract ADD CONSTRAINT contract_viwa_package_type_check CHECK (viwa_package IS NULL OR type = 'viwa');

CREATE OR REPLACE FUNCTION contract_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  v_crm    text[] := ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'viwa_package',
                           'updated_at'];
  r contract;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system THEN
      RAISE EXCEPTION 'Zmluva sa nemaže – opravuje sa v Office portáli a ďalším importom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_system THEN
    -- obchodníka zmluvy (Uzatvoril) zmení iba vedenie alebo admin, rovnako ako vlastníka zákazníka
    IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND crm_can_change_owner() THEN
      v_crm := v_crm || 'owner_id'::text;
    END IF;
    IF (to_jsonb(NEW) - v_crm) <> (to_jsonb(OLD) - v_crm) THEN
      RAISE EXCEPTION 'Údaje z Office portálu sa v CRM nemenia – opravte ich v Office portáli a nahrajte export.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  -- súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka
  IF NEW.related_contract_id IS NOT NULL THEN
    SELECT * INTO r FROM contract WHERE id = NEW.related_contract_id;
    IF (r.company_id, r.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)
       OR NOT ((NEW.type = 'viwa' AND r.type::text LIKE 'dodavka%') OR (r.type = 'viwa' AND NEW.type::text LIKE 'dodavka%')) THEN
      RAISE EXCEPTION 'Súvisiaca zmluva: VIWA a zmluva o dodávke toho istého zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- Cenníková cena = presná kópia položky schválenej verzie; VIWA: účet nesie mesačnú platbu, OOM poplatok za kW
CREATE OR REPLACE FUNCTION contract_price_fill() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  i  record;
BEGIN
  NEW.org_id := (SELECT org_id FROM contract WHERE id = NEW.contract_id);
  IF NEW.oom_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = NEW.contract_id AND oom_id = NEW.oom_id) THEN
    RAISE EXCEPTION 'OOM ceny nie je v zmluve.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.price_list_item_id IS NOT NULL THEN
    SELECT it.*, v.status AS version_status INTO i
      FROM price_list_item it JOIN price_list_version v ON v.id = it.version_id
     WHERE it.id = NEW.price_list_item_id;
    IF i.version_status <> 'schvalena' THEN
      RAISE EXCEPTION 'Cenníková cena musí byť zo schválenej verzie cenníka.' USING ERRCODE = 'check_violation';
    END IF;
    IF i.product_id <> NEW.product_id
       OR i.price_vt_eur_mwh IS DISTINCT FROM NEW.price_vt_eur_mwh
       OR i.price_nt_eur_mwh IS DISTINCT FROM NEW.price_nt_eur_mwh
       OR (CASE WHEN NEW.slot = 'viwa_kw' THEN NULL ELSE coalesce(i.fee_oom_eur_month, i.fee_program_eur_month) END)
          IS DISTINCT FROM NEW.fee_eur_month
       OR (CASE WHEN NEW.slot = 'viwa_ucet' THEN NULL ELSE i.fee_kw_eur_month END) IS DISTINCT FROM NEW.fee_kw_eur_month
       OR i.vat_rate IS DISTINCT FROM NEW.vat_rate THEN
      RAISE EXCEPTION 'Cenníková cena sa nezhoduje s položkou cenníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 6. Ceny z cenníkov (komodita pri cenníkovej cene, ZEM, program, mesačná platba za OM firmy, VIWA)
-- ============================================================================

-- Položky schválených verzií s produktom a ich obdobie orezané na [p_from, p_to] (p_to NULL = bez konca).
-- p_list_with: iba cenníky, ktoré majú aj tento produkt (ZEM z cenníka Domácnosti ANO alebo NIE podľa produktu DD).
CREATE FUNCTION contract_price_items(p_product_id uuid, p_from date, p_to date, p_list_with uuid DEFAULT NULL)
RETURNS TABLE (item_id uuid, valid_from date, valid_to date)
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT i.id, greatest(v.valid_from, p_from),
         CASE WHEN v.valid_to IS NULL THEN p_to WHEN p_to IS NULL THEN v.valid_to ELSE least(v.valid_to, p_to) END
    FROM price_list_item i
    JOIN price_list_version v ON v.id = i.version_id
   WHERE i.product_id = p_product_id AND v.status = 'schvalena'
     AND (v.valid_to IS NULL OR v.valid_to >= p_from)
     AND (p_to IS NULL OR v.valid_from <= p_to)
     AND (p_list_with IS NULL OR EXISTS (SELECT 1 FROM price_list_item j JOIN price_list_version w ON w.id = j.version_id
                                          WHERE w.price_list_id = v.price_list_id AND j.product_id = p_list_with))
$$;

-- Riadok ceny (jsonb) ako kópia položky cenníka
CREATE FUNCTION contract_price_list_row(p_slot text, p_oom_id uuid, p_item_id uuid, p_from date, p_to date) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'oom_id', p_oom_id, 'slot', p_slot, 'product_id', i.product_id, 'price_model', 'cennik',
           'price_list_item_id', i.id, 'valid_from', p_from, 'valid_to', p_to,
           'price_vt_eur_mwh', i.price_vt_eur_mwh, 'price_nt_eur_mwh', i.price_nt_eur_mwh,
           'fee_eur_month', CASE WHEN p_slot = 'viwa_kw' THEN NULL ELSE coalesce(i.fee_oom_eur_month, i.fee_program_eur_month) END,
           'fee_kw_eur_month', CASE WHEN p_slot = 'viwa_ucet' THEN NULL ELSE i.fee_kw_eur_month END,
           'vat_rate', i.vat_rate)
    FROM price_list_item i
   WHERE i.id = p_item_id
$$;

-- Ceny zmluvy, ktoré vyplývajú z cenníkov (zadanie časť 5, modul 3):
--   komodita pri cenníkovej cene (DD, DMP) iba pri OOM spotreby (nie výroba – VBattery, nie virtuálne – sharing);
--   ZEM pri domácnosti a OOM spotreby (z cenníka produktu DD); program (VBattery);
--   firma s individuálnou cenou FIX a automatickou prolongáciou: od konca posledného roka s cenou cenník
--   „Podnikatelia nad 30 MWh“, produkt podľa typu tarifu OOM, pri verejnom osvetlení Green 1T VO (otázka 23);
--   mesačná platba za OM pri firme s individuálnou cenou (Poplatky B2B) – mimo obdobia cenníka nad 30 MWh,
--   ktorý ju má v položke; VIWA: účet a €/kW podľa balíka.
-- Obdobie = skutočné obdobie OOM v zmluve (s prolongáciou, skrátené nástupcom) × verzie cenníka.
CREATE FUNCTION contract_price_list_rows(p_contract_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  c      contract;
  co     record;
  q      record;
  v_out  jsonb := '[]';
  v_pid  uuid;
  v_last date;
  v_open boolean;
  v_mod  price_model;
  v_list datemultirange;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  FOR co IN
    SELECT x.*, o.type AS oom_type, o.public_lighting, p.code AS product_code, p.tariff_type
      FROM contract_oom x JOIN oom o ON o.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
     WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
  LOOP
    IF c.type::text LIKE 'dodavka%' AND c.list_price AND co.product_id IS NOT NULL AND co.oom_type = 'spotreba' THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('komodita', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items(co.product_id, co.valid_from, co.valid_to) p);
    END IF;
    IF c.type = 'dodavka_domacnost' AND co.oom_type = 'spotreba' AND co.product_id IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('zem', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items((SELECT id FROM product WHERE code = 'zem'), co.valid_from, co.valid_to,
                                                     co.product_id) p);
    END IF;
    IF co.program_id IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('program', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items(co.program_id, co.valid_from, co.valid_to) p);
    END IF;
    IF c.type IN ('dodavka_firma_nn', 'dodavka_firma_vn') AND NOT c.list_price AND co.oom_type = 'spotreba' THEN
      v_list := '{}';
      -- FIX s automatickou prolongáciou: po poslednom roku s cenou cenník nad 30 MWh (otázka 23)
      SELECT max(p.valid_to), bool_or(p.valid_to IS NULL), (array_agg(p.price_model ORDER BY p.valid_from DESC))[1]
        INTO v_last, v_open, v_mod
        FROM contract_price p
       WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita' AND p.source = 'import'
         AND p.price_model <> 'cennik';
      IF c.auto_prolong AND v_mod = 'fix' AND NOT v_open AND (co.valid_to IS NULL OR co.valid_to > v_last) THEN
        v_pid := (SELECT id FROM product WHERE code = CASE WHEN co.public_lighting AND co.tariff_type = 'jednotarif'
                                                           THEN 'green_1t_vo' ELSE co.product_code END);
        FOR q IN
          SELECT i.id, greatest(v.valid_from, v_last + 1) AS f,
                 CASE WHEN v.valid_to IS NULL THEN co.valid_to WHEN co.valid_to IS NULL THEN v.valid_to
                      ELSE least(v.valid_to, co.valid_to) END AS t
            FROM price_list_item i
            JOIN price_list_version v ON v.id = i.version_id
            JOIN price_list l ON l.id = v.price_list_id
           WHERE l.code = 'podnikatelia_nad_30mwh' AND v.status = 'schvalena' AND i.product_id = v_pid
             AND (v.valid_to IS NULL OR v.valid_to > v_last) AND (co.valid_to IS NULL OR v.valid_from <= co.valid_to)
        LOOP
          v_out := v_out || contract_price_list_row('komodita', co.oom_id, q.id, q.f, q.t);
          v_list := v_list + datemultirange(daterange(q.f, q.t, '[]'));
        END LOOP;
      END IF;
      -- mesačná platba za OM (Poplatky B2B) mimo obdobia cenníka nad 30 MWh (platba je v jeho položke)
      FOR q IN SELECT unnest(datemultirange(daterange(co.valid_from, co.valid_to, '[]')) - v_list) AS rg LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('poplatok_om', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items((SELECT id FROM product WHERE code = 'poplatok_om_firmy'),
                                                       lower(q.rg), upper(q.rg) - 1) p);
      END LOOP;
    END IF;
    IF c.type = 'viwa' AND c.viwa_package IS NOT NULL THEN
      v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_kw', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                           FROM contract_price_items((SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package),
                                                     co.valid_from, co.valid_to) p);
    END IF;
  END LOOP;
  IF c.type = 'viwa' AND c.viwa_package IS NOT NULL AND c.valid_from IS NOT NULL THEN
    v_pid := (SELECT id FROM product WHERE code = 'viwa_' || c.viwa_package);
    v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('viwa_ucet', NULL, p.item_id, p.valid_from, p.valid_to)), '[]')
                         FROM contract_price_items(v_pid, c.valid_from, contract_effective_to(c)) p);
  END IF;
  RETURN v_out;
END;
$$;

-- Porovnateľný tvar cien (poradie, čísla ako numeric zo stĺpcov) – rovnaké ceny = rovnaký jsonb
CREATE FUNCTION contract_price_canon(p_rows jsonb) RETURNS jsonb
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'oom', r.oom_id, 'slot', r.slot, 'product', r.product_id, 'model', r.price_model, 'item', r.price_list_item_id,
           'from', r.valid_from, 'to', r.valid_to, 'vt', r.price_vt_eur_mwh, 'nt', r.price_nt_eur_mwh,
           'add', r.additive_eur_mwh, 'pct', r.additive_pct, 'fee', r.fee_eur_month, 'kw', r.fee_kw_eur_month,
           'vat', r.vat_rate, 'name', r.op_product_name)
           ORDER BY r.slot, r.oom_id::text NULLS FIRST, r.valid_from), '[]')
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) r
$$;

-- Nastaví ceny zmluvy zo zdroja importu: p_subset 'op' = individuálne ceny z Office portálu, 'cennik' = ceny z cenníkov.
-- Ceny prolongácie, prechodu cenníka a ďalšie zdroje nemení. Vráti true, ak sa niečo zmenilo.
CREATE FUNCTION contract_price_set(p_contract_id uuid, p_subset text, p_rows jsonb) RETURNS boolean
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
BEGIN
  IF contract_price_canon((SELECT coalesce(jsonb_agg(to_jsonb(cp)), '[]') FROM contract_price cp
                            WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                              AND (cp.price_model = 'cennik') = (p_subset = 'cennik')))
     = contract_price_canon(p_rows) THEN
    RETURN false;
  END IF;
  DELETE FROM contract_price
   WHERE contract_id = p_contract_id AND source = 'import' AND (price_model = 'cennik') = (p_subset = 'cennik');
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month,
                              fee_kw_eur_month, vat_rate, op_product_name, source)
  SELECT p_contract_id, r.oom_id, r.slot, r.product_id, r.price_model, r.price_list_item_id, r.valid_from, r.valid_to,
         r.price_vt_eur_mwh, r.price_nt_eur_mwh, r.additive_eur_mwh, r.additive_pct, r.fee_eur_month,
         r.fee_kw_eur_month, r.vat_rate, r.op_product_name, 'import'
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) r;
  RETURN true;
END;
$$;

CREATE FUNCTION contract_price_list_sync(p_contract_id uuid) RETURNS boolean
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT contract_price_set(p_contract_id, 'cennik', contract_price_list_rows(p_contract_id))
$$;
COMMENT ON FUNCTION contract_price_list_sync(uuid) IS 'ceny zmluvy z cenníkov podľa OOM v zmluve, produktov a balíka VIWA; mení iba ceny zo zdroja import s modelom cenník';

-- Príznak „Chýba cena“ (časť 7.1): OOM spotreby v zmluve o dodávke a OOM výkupu bez ceny komodity, VIWA bez balíka
-- alebo bez platby za účet. Kontroluje sa obdobie od 1. 1. bežného roka (staršie roky CRM nemá v cenníkoch),
-- pri dobe neurčitej do konca bežného roka. Odmietnuté, neúspešné a ukončené zmluvy príznak nemajú.
-- Vráti popis chýbajúcich cien alebo NULL.
CREATE FUNCTION contract_price_missing_refresh(p_contract_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') THEN
    FOR co IN
      SELECT x.*, o.eic
        FROM contract_oom x JOIN oom o ON o.id = x.oom_id
       WHERE x.contract_id = c.id
         AND ((c.type::text LIKE 'dodavka%' AND o.type = 'spotreba') OR c.type = 'vykup')
       ORDER BY o.eic
    LOOP
      IF co.valid_from IS NULL THEN
        v_miss := v_miss || format('OOM %s: chýba účinnosť od', co.eic);
        CONTINUE;
      END IF;
      v_from := greatest(co.valid_from, v_y_from);
      v_to := coalesce(co.valid_to, greatest(v_from, v_y_to));
      CONTINUE WHEN v_to < v_from;
      IF NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
                     - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                                  WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita'),
                                '{}'::datemultirange)) THEN
        v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                   to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
      END IF;
    END LOOP;
    IF c.type = 'viwa' THEN
      IF c.viwa_package IS NULL THEN
        v_miss := v_miss || 'chýba balík VIWA (doplní Servis)'::text;
      ELSIF c.valid_from IS NOT NULL THEN
        v_from := greatest(c.valid_from, v_y_from);
        v_to := coalesce(contract_effective_to(c), greatest(v_from, v_y_to));
        IF v_to >= v_from AND NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
             - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                          WHERE p.contract_id = c.id AND p.slot = 'viwa_ucet'), '{}'::datemultirange)) THEN
          v_miss := v_miss || 'chýba cena balíka VIWA v cenníku'::text;
        END IF;
      END IF;
    END IF;
  END IF;

  v_detail := nullif(array_to_string(v_miss, '; '), '');
  IF v_detail IS NULL THEN
    UPDATE contract_flag SET resolved_at = now()
     WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;

-- Balík VIWA zadaný v CRM (otázka 20) doplní ceny z cenníka Green VIWA a prepočíta príznak „Chýba cena“
CREATE FUNCTION contract_viwa_package_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM contract_price_list_sync(NEW.id);
  PERFORM contract_price_missing_refresh(NEW.id);
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_viwa_package AFTER UPDATE OF viwa_package ON contract
  FOR EACH ROW WHEN (NEW.viwa_package IS DISTINCT FROM OLD.viwa_package AND NEW.type = 'viwa')
  EXECUTE FUNCTION contract_viwa_package_sync();

-- ============================================================================
-- 7. Nástupníctvo aj vtedy, keď OOM v zmluve dostane účinnosť dodatočne (domácnosť: začiatok z XM Trade)
-- ============================================================================

CREATE OR REPLACE FUNCTION contract_oom_fill() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c contract;
BEGIN
  SELECT * INTO c FROM contract WHERE id = NEW.contract_id;
  IF (SELECT org_id FROM oom WHERE id = NEW.oom_id) <> c.org_id THEN
    RAISE EXCEPTION 'OOM patrí inej spoločnosti ako zmluva.' USING ERRCODE = 'check_violation';
  END IF;
  NEW.org_id := c.org_id;
  NEW.grp := CASE WHEN c.type IN ('vykup', 'viwa') THEN 'vykup_viwa' ELSE 'dodavka' END;
  NEW.is_binding := c.phase = 'podpisana';
  IF TG_OP = 'INSERT' THEN
    NEW.valid_from := coalesce(NEW.valid_from, c.valid_from);
    NEW.op_valid_to := c.valid_to;
    NEW.valid_to := coalesce(NEW.valid_to, contract_effective_to(c));
  END IF;
  IF NEW.is_binding AND NEW.valid_from IS NOT NULL
     AND (TG_OP = 'INSERT' OR NOT OLD.is_binding OR OLD.valid_from IS NULL OR NEW.valid_from < OLD.valid_from
          OR (NEW.valid_to IS NULL AND OLD.valid_to IS NOT NULL) OR NEW.valid_to > OLD.valid_to
          OR NEW.oom_id <> OLD.oom_id) THEN
    PERFORM contract_oom_succession(NEW, c);
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- 8. Import: pomocné funkcie
-- ============================================================================

-- EIC s neobvyklým tvarom (rozhodnutie 6): 3. znak nie je Z (okrem virtuálneho 24GREENVV) alebo prvé 2 znaky nie sú číslice
CREATE FUNCTION contract_import_eic_warning(p_eic text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_eic LIKE '24GREENVV%' THEN NULL
              WHEN p_eic !~ '^[0-9]{2}' OR substr(p_eic, 3, 1) <> 'Z'
                THEN format('EIC %s má neobvyklý tvar (nie je to kód odberného miesta) – skontrolujte.', p_eic) END
$$;

-- Kód hodnoty číselníka pre názov z XM Trade: preklad (import_alias), inak presný názov v CRM; NULL = neznámy názov.
-- Pri sadzbe p_parent = kód PDS (kód sadzby = pds_sadzba).
CREATE FUNCTION contract_import_xm_code(p_org uuid, p_kind text, p_list text, p_name text, p_parent text DEFAULT NULL)
RETURNS text
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  a import_alias;
  v text;
BEGIN
  IF nullif(btrim(p_name), '') IS NULL THEN
    RETURN NULL;
  END IF;
  a := import_alias_resolve(p_org, 'xm_trade', p_kind, p_name);
  IF a.id IS NOT NULL THEN
    v := CASE WHEN p_kind = 'sadzba' THEN p_parent || '_' || a.target ELSE a.target END;
  ELSE
    SELECT code INTO v FROM lookup_value
     WHERE list_code = p_list AND (org_id IS NULL OR org_id = p_org) AND hidden_at IS NULL
       AND (p_parent IS NULL OR parent_code = p_parent)
       AND lower(translate(btrim(label), '–—', '--')) = lower(translate(btrim(p_name), '–—', '--'))
     LIMIT 1;
  END IF;
  IF v IS NOT NULL AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = p_list AND code = v AND hidden_at IS NULL
                                     AND (org_id IS NULL OR org_id = p_org)) THEN
    v := NULL;
  END IF;
  RETURN v;
END;
$$;

CREATE FUNCTION contract_import_label(p_list text, p_code text) RETURNS text
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT label FROM lookup_value WHERE list_code = p_list AND code = p_code ORDER BY org_id NULLS LAST LIMIT 1
$$;

-- Produkt DDx ANO/NIE z produktu XM Trade „VBATTERY - DDx - ANO/NIE Energopomoc“ (rozhodnutie 4); NULL = iný produkt
CREATE FUNCTION contract_import_xm_dd(p_product text) RETURNS uuid
LANGUAGE sql STABLE SET search_path = public, pg_temp AS $$
  SELECT p.id FROM product p,
         LATERAL (SELECT regexp_match(p_product, '^\s*VBATTERY\s*-\s*DD\s*(\d+)\s*-\s*(ANO|NIE)', 'i') AS m) x
   WHERE x.m IS NOT NULL AND p.code = 'green_dd' || x.m[1] || '_' || lower(x.m[2])
$$;

-- Začiatok účinnosti domácnosti z XM Trade (Dátum začiatku dodávky) pre OOM zmluvy (rozhodnutie 3)
CREATE FUNCTION contract_import_xm_from(p_xm jsonb, p_eics text[]) RETURNS date
LANGUAGE sql IMMUTABLE AS $$
  SELECT min((x ->> 'supply_from')::date)
    FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
   WHERE x ->> 'eic' = ANY (p_eics) AND nullif(x ->> 'supply_from', '') IS NOT NULL
     AND jsonb_array_length(coalesce(x -> 'parse_errors', '[]')) = 0
$$;

-- Jeden riadok XM Trade → OOM: preklady číselníkov, sadzba a regulácia z produktu (VBattery), typ nového OOM.
-- Zápis robí import OOM (oom_import_rows): nové OOM Pripravované, stav a zákazník existujúceho sa nemenia,
-- zmena regulácie = zmena s „platí od“ dnes. Výsledok ako oom_import_rows + warnings, missing (chýbajúce preklady).
CREATE FUNCTION contract_import_xm_one(p_org uuid, r jsonb, p_company uuid, p_person uuid) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_eic     text := upper(regexp_replace(coalesce(r ->> 'eic', ''), '\s', '', 'g'));
  v_old     oom;
  v_f       jsonb := coalesce(r -> 'fields', '{}');
  v_miss    jsonb := '[]';
  v_warn    jsonb := '[]';
  v_prod    text := btrim(coalesce(r ->> 'product', ''));
  v_tariff  text := btrim(coalesce(r ->> 'tariff', ''));
  m         text[];
  v_code    text;
  v_pds     text;
  v_reg     boolean;
  v_reg_col boolean;
  v_type    text;
  k         record;
BEGIN
  SELECT * INTO v_old FROM oom WHERE eic = v_eic;
  IF contract_import_eic_warning(v_eic) IS NOT NULL THEN
    v_warn := v_warn || to_jsonb(contract_import_eic_warning(v_eic));
  END IF;

  -- číselníky: preklad XM Trade alebo presný názov; do importu OOM ide názov hodnoty v CRM
  FOR k IN SELECT * FROM (VALUES ('pds', 'pds'), ('metering_type', 'typ_merania'), ('billing_period', 'fakturacne_obdobie'),
                                 ('advance_payment_method', 'sposob_zaloh')) AS t (field, kind) LOOP
    CONTINUE WHEN nullif(btrim(v_f ->> k.field), '') IS NULL;
    v_code := contract_import_xm_code(p_org, k.kind, k.kind, v_f ->> k.field);
    IF v_code IS NULL THEN
      v_miss := v_miss || jsonb_build_object('source', 'xm_trade', 'kind', k.kind, 'name', v_f ->> k.field);
    ELSE
      v_f := v_f || jsonb_build_object(k.field, contract_import_label(k.kind, v_code));
      IF k.field = 'pds' THEN
        v_pds := v_code;
      END IF;
    END IF;
  END LOOP;
  v_pds := coalesce(v_pds, v_old.pds);

  -- produkt XM Trade: VBattery DDx ANO/NIE (sadzba Dx a regulácia), inak iba regulácia (nereg., ANO/NIE Energopomoc);
  -- stĺpec Cenová regulácia iba ak produkt reguláciu neurčí (otázka 12a: nesúlad = upozornenie, platí produkt)
  m := regexp_match(v_prod, '^VBATTERY\s*-\s*DD\s*(\d+)\s*-\s*(ANO|NIE)', 'i');
  v_reg := CASE WHEN m IS NOT NULL THEN upper(m[2]) = 'ANO'
                WHEN v_prod ~* 'nereg' THEN false
                WHEN v_prod ~* '(^|[^[:alpha:]])ANO\s+energopomoc' THEN true
                WHEN v_prod ~* '(^|[^[:alpha:]])NIE\s+energopomoc' THEN false END;
  v_reg_col := CASE import_name_norm(r ->> 'regulation') WHEN 'regulovane' THEN true WHEN 'neregulovane' THEN false END;
  IF v_reg IS NOT NULL AND v_reg_col IS NOT NULL AND v_reg <> v_reg_col THEN
    v_warn := v_warn || to_jsonb(format('Cenová regulácia: produkt „%s“ a stĺpec „%s“ sa líšia – platí produkt.',
                                        v_prod, r ->> 'regulation'));
  END IF;
  v_f := v_f - 'price_regulation';
  IF coalesce(v_reg, v_reg_col) IS NOT NULL THEN
    v_f := v_f || jsonb_build_object('price_regulation', coalesce(v_reg, v_reg_col));
  END IF;

  -- sadzba: VBattery z produktu (DDx = Dx), inak stĺpec Sadzba cez preklad; virtuálne OOM sadzbu nemá
  v_f := v_f - 'pds_tariff';
  IF v_eic NOT LIKE '24GREENVV%' THEN
    IF m IS NOT NULL THEN
      v_code := v_pds || '_d' || m[1];
      IF v_code IS NULL OR contract_import_label('sadzba_distribucie', v_code) IS NULL THEN
        v_warn := v_warn || to_jsonb(format('Sadzbu D%s z produktu „%s“ nejde priradiť (chýba PDS alebo sadzba v číselníku) – sadzba sa nemení.',
                                            m[1], v_prod));
      ELSE
        v_f := v_f || jsonb_build_object('pds_tariff', contract_import_label('sadzba_distribucie', v_code));
      END IF;
    ELSIF v_tariff <> '' AND v_tariff !~* '^VBATTERY' THEN
      v_code := CASE WHEN v_pds IS NOT NULL THEN contract_import_xm_code(p_org, 'sadzba', 'sadzba_distribucie', v_tariff, v_pds) END;
      IF v_code IS NULL THEN
        v_miss := v_miss || jsonb_build_object('source', 'xm_trade', 'kind', 'sadzba', 'name', v_tariff);
      ELSE
        v_f := v_f || jsonb_build_object('pds_tariff', contract_import_label('sadzba_distribucie', v_code));
      END IF;
    END IF;
  END IF;

  -- typ OOM (otázka 24): virtuálne 24GREENVV = sharing, „Dodávka (+)“ = výroba, „Odber (−)“ = spotreba;
  -- existujúcemu OOM sa typ nemení (pri nesúlade upozornenie)
  v_f := v_f - 'type';
  v_type := CASE WHEN v_eic LIKE '24GREENVV%' THEN 'sharing'
                 WHEN import_name_norm(r ->> 'direction') LIKE 'dodavka%' THEN 'vyroba'
                 WHEN import_name_norm(r ->> 'direction') LIKE 'odber%' THEN 'spotreba' END;
  IF v_old.id IS NULL THEN
    v_f := v_f || jsonb_build_object('type', coalesce(v_type, 'spotreba'));
    IF v_type IS NULL THEN
      v_warn := v_warn || to_jsonb(format('Odber/Dodávka „%s“ nejde preložiť – OOM je založené ako spotreba, typ skontrolujte.',
                                          coalesce(r ->> 'direction', '')));
    END IF;
  ELSIF v_type IS NOT NULL AND v_type <> v_old.type::text THEN
    v_warn := v_warn || to_jsonb(format('XM Trade uvádza %s, OOM v CRM je %s – typ sa nemení.', v_type, v_old.type));
  END IF;

  IF jsonb_array_length(v_miss) > 0 THEN
    RETURN jsonb_build_object('row', r -> 'row', 'eic', v_eic, 'action', 'chyba',
             'error', 'Neznámy názov z XM Trade: ' || (SELECT string_agg(format('%s „%s“', x ->> 'kind', x ->> 'name'), ', ')
                                                          FROM jsonb_array_elements(v_miss) x) || ' – pridajte preklad.',
             'missing', v_miss, 'warnings', v_warn);
  END IF;
  RETURN (oom_import_rows(p_org, jsonb_build_array(jsonb_build_object(
            'row', r -> 'row', 'eic', v_eic,
            'customer_id', CASE WHEN v_old.id IS NULL THEN coalesce(p_company, p_person) END,
            'fields', v_f, 'parse_errors', coalesce(r -> 'parse_errors', '[]')))) -> 0)
         || jsonb_build_object('warnings', v_warn, 'missing', '[]'::jsonb);
END;
$$;

-- Údaje z XM Trade pre existujúcu zmluvu domácnosti: začiatok účinnosti a produkt DDx pri VBattery (rozhodnutia 3, 4).
-- Vráti popisy zmien (prázdne pole = bez zmeny).
CREATE FUNCTION contract_import_xm_link(p_contract_id uuid, p_xm jsonb) RETURNS text[]
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  c     contract;
  v_chg text[] := '{}';
  v_from date;
  r     record;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.type <> 'dodavka_domacnost' OR jsonb_array_length(coalesce(p_xm, '[]')) = 0 THEN
    RETURN v_chg;
  END IF;
  v_from := contract_import_xm_from(p_xm, ARRAY(SELECT o.eic FROM contract_oom co JOIN oom o ON o.id = co.oom_id
                                                 WHERE co.contract_id = c.id));
  IF v_from IS NOT NULL AND v_from IS DISTINCT FROM c.valid_from THEN
    UPDATE contract SET valid_from = v_from WHERE id = c.id;
    v_chg := v_chg || format('Účinnosť od %s → %s (XM Trade)', coalesce(to_char(c.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                             to_char(v_from, 'FMDD. FMMM. YYYY'));
  END IF;
  FOR r IN
    SELECT co.id, co.product_id, o.eic, contract_import_xm_dd(x ->> 'product') AS dd
      FROM jsonb_array_elements(p_xm) x
      JOIN oom o ON o.eic = x ->> 'eic' AND o.type = 'spotreba'
      JOIN contract_oom co ON co.oom_id = o.id AND co.contract_id = c.id AND co.program_id IS NOT NULL
  LOOP
    CONTINUE WHEN r.dd IS NULL OR r.dd IS NOT DISTINCT FROM r.product_id;
    UPDATE contract_oom SET product_id = r.dd WHERE id = r.id;
    v_chg := v_chg || format('OOM %s: produkt %s (XM Trade)', r.eic, (SELECT name FROM product WHERE id = r.dd));
  END LOOP;
  IF cardinality(v_chg) > 0 THEN
    PERFORM contract_price_list_sync(c.id);
    PERFORM contract_price_missing_refresh(c.id);
  END IF;
  RETURN v_chg;
END;
$$;

-- Individuálne ceny zmluvy z riadkov Office portálu (zadanie časť 10, rozhodnutia 2, 3, A, otázka 4).
-- p_oom: EIC → {oom_id, product_id, tariff (1t/2t/2t_vyk), valid_from, valid_to} (skutočné obdobie OOM v zmluve).
-- Vráti {rows, errors, warnings, kontrola, missing}.
CREATE FUNCTION contract_import_op_prices(p_org uuid, c contract, p_rows jsonb, p_oom jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SET search_path = public, pg_temp AS $$
DECLARE
  r        jsonb;
  a        import_alias;
  x        jsonb;
  o        jsonb;
  v_out    jsonb := '[]';
  v_err    text[] := '{}';
  v_warn   text[] := '{}';
  v_kontr  text[] := '{}';
  v_miss   jsonb := '[]';
  v_name   text;
  v_eic    text;
  v_year   integer;
  v_from   date;
  v_to     date;
  v_prod   uuid;
  v_vt     numeric;
  v_nt     numeric;
  q        record;
BEGIN
  FOR r IN SELECT y FROM jsonb_array_elements(p_rows) y WHERE nullif(btrim(y ->> 'price_product'), '') IS NOT NULL LOOP
    v_name := btrim(r ->> 'price_product');
    v_eic := r ->> 'eic';
    a := import_alias_resolve(p_org, 'office_portal', 'produkt_op', v_name);
    IF a.id IS NULL THEN
      IF NOT v_miss @> jsonb_build_array(jsonb_build_object('source', 'office_portal', 'kind', 'produkt_op', 'name', v_name)) THEN
        v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'produkt_op', 'name', v_name);
        v_err := v_err || format('Neznámy cenový produkt „%s“ – pridajte preklad.', v_name);
      END IF;
      CONTINUE;
    END IF;
    x := a.target_extra;
    IF x ? 'kontrola' AND NOT format('%s: %s', v_name, x ->> 'kontrola') = ANY (v_kontr) THEN
      v_kontr := v_kontr || format('%s: %s', v_name, x ->> 'kontrola');
    END IF;
    o := p_oom -> v_eic;
    CONTINUE WHEN o IS NULL;                                -- OOM chýba: chybu hlási zmluva
    -- 1T / 2T: cena podľa typu tarifu produktu pri OOM (rozhodnutie 2); iný typ tarifu sa na OOM nevzťahuje
    CONTINUE WHEN x ? 'tariff' AND o ->> 'tariff' IS NOT NULL AND o ->> 'tariff' <> x ->> 'tariff';
    -- obdobie: ZZC_datum_od/do, prázdne = celý rok z názvu produktu; orezané na skutočné obdobie OOM v zmluve
    v_year := (substring(v_name FROM '(?:19|20)[0-9]{2}'))::int;
    v_from := coalesce((r ->> 'price_from')::date, make_date(v_year, 1, 1));
    v_to := coalesce((r ->> 'price_to')::date, make_date(v_year, 12, 31));
    IF v_from IS NULL OR v_to IS NULL THEN
      v_err := v_err || format('Cena „%s“ nemá obdobie ani rok v názve.', v_name);
      CONTINUE;
    END IF;
    CONTINUE WHEN o ->> 'valid_from' IS NULL;               -- bez účinnosti: „Chýba cena“
    v_from := greatest(v_from, (o ->> 'valid_from')::date);
    v_to := CASE WHEN o ->> 'valid_to' IS NULL THEN v_to ELSE least(v_to, (o ->> 'valid_to')::date) END;
    IF v_to < v_from THEN
      v_warn := v_warn || format('OOM %s: cena „%s“ je mimo účinnosti zmluvy – vynechaná.', v_eic, v_name);
      CONTINUE;
    END IF;
    -- produkt ceny: výkup B2B; dodávka = produkt pri OOM, inak podľa typu tarifu z prekladu
    v_prod := CASE WHEN (x ->> 'vykup')::boolean THEN (SELECT id FROM product WHERE code = 'vykup_b2b')
                   ELSE coalesce((o ->> 'product_id')::uuid,
                                 (SELECT id FROM product WHERE code = CASE x ->> 'tariff' WHEN '1t' THEN 'green_1t'
                                    WHEN '2t' THEN 'green_2t' WHEN '2t_vyk' THEN 'green_2t_vyk' END)) END;
    IF v_prod IS NULL THEN
      v_err := v_err || format('OOM %s: produkt pri OOM chýba – cenu „%s“ nejde priradiť.', v_eic, v_name);
      CONTINUE;
    END IF;
    v_vt := (r ->> 'price_vt')::numeric;
    v_nt := nullif((r ->> 'price_nt')::numeric, 0);
    v_out := v_out || jsonb_build_object(
      'oom_id', o ->> 'oom_id', 'slot', 'komodita', 'product_id', v_prod, 'price_model', a.target,
      'valid_from', v_from, 'valid_to', v_to, 'op_product_name', v_name,
      'price_vt_eur_mwh', CASE WHEN a.target = 'fix' THEN v_vt END,
      'price_nt_eur_mwh', CASE WHEN a.target = 'fix' AND x ->> 'tariff' IN ('2t', '2t_vyk') THEN v_nt END,
      'additive_eur_mwh', CASE WHEN a.target IN ('spot_plus_eur', 'spot_minus_eur') THEN v_vt END,
      'additive_pct', CASE WHEN a.target = 'spot_minus_pct' THEN v_vt END,
      '_eic', v_eic, '_tariff', x ->> 'tariff');
  END LOOP;

  -- rovnaké riadky (export opakuje cenu pri každom OOM a období) sa zlúčia
  SELECT coalesce(jsonb_agg(DISTINCT y), '[]') INTO v_out FROM jsonb_array_elements(v_out) y;
  -- OOM bez typu tarifu a ceny pre 1T aj 2T v jednom období = neurčiteľné (rozhodnutie 2)
  FOR q IN
    SELECT y ->> '_eic' AS eic, y ->> 'valid_from' AS f
      FROM jsonb_array_elements(v_out) y
     GROUP BY 1, 2 HAVING count(DISTINCT y ->> '_tariff') > 1
  LOOP
    v_err := v_err || format('OOM %s: od %s sú ceny pre 1T aj 2T a produkt pri OOM ich nerozlíši.', q.eic,
                             to_char(q.f::date, 'FMDD. FMMM. YYYY'));
  END LOOP;
  -- dve rôzne ceny toho istého OOM v prekrývajúcom sa období = chyba (otázka 4)
  FOR q IN
    SELECT DISTINCT a1.y ->> '_eic' AS eic, a1.y ->> 'valid_from' AS f
      FROM jsonb_array_elements(v_out) WITH ORDINALITY a1 (y, i)
      JOIN jsonb_array_elements(v_out) WITH ORDINALITY a2 (y, i) ON a2.i > a1.i
           AND a2.y ->> '_eic' = a1.y ->> '_eic' AND a2.y ->> '_tariff' IS NOT DISTINCT FROM a1.y ->> '_tariff'
           AND daterange((a1.y ->> 'valid_from')::date, (a1.y ->> 'valid_to')::date, '[]')
               && daterange((a2.y ->> 'valid_from')::date, (a2.y ->> 'valid_to')::date, '[]')
  LOOP
    v_err := v_err || format('OOM %s: dve rôzne ceny v období od %s – opravte v Office portáli.', q.eic,
                             to_char(q.f::date, 'FMDD. FMMM. YYYY'));
  END LOOP;
  -- posledné cenové obdobie platí ďalej do konca OOM v zmluve (pri dobe neurčitej bez konca): výkup (zadanie časť 5)
  -- a SPOT + aditív (otázka 23); FIX nie – po ňom cenník nad 30 MWh pri automatickej prolongácii, inak „Chýba cena“
  IF cardinality(v_err) = 0 THEN
    SELECT coalesce(jsonb_agg(CASE WHEN (c.type = 'vykup' OR y ->> 'price_model' = 'spot_plus_eur')
                                        AND y ->> 'valid_from' = (SELECT max(z ->> 'valid_from') FROM jsonb_array_elements(v_out) z
                                                                   WHERE z ->> '_eic' = y ->> '_eic')
                                   THEN y || jsonb_build_object('valid_to', p_oom -> (y ->> '_eic') -> 'valid_to') ELSE y END), '[]')
      INTO v_out FROM jsonb_array_elements(v_out) y;
  END IF;
  SELECT coalesce(jsonb_agg(y - '_eic' - '_tariff'), '[]') INTO v_out FROM jsonb_array_elements(v_out) y;
  RETURN jsonb_build_object('rows', v_out, 'errors', to_jsonb(v_err), 'warnings', to_jsonb(v_warn),
                            'kontrola', to_jsonb(v_kontr), 'missing', v_miss);
END;
$$;

-- Chyby zmluvy zozbierané pred zápisom: výnimka P0090, v DETAIL chýbajúce preklady (jsonb) pre „Pridať preklad“
CREATE FUNCTION contract_import_fail(p_err text[], p_miss jsonb) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF cardinality(p_err) > 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0090',
      MESSAGE = array_to_string(ARRAY(SELECT e FROM unnest(p_err) WITH ORDINALITY u (e, i) GROUP BY e ORDER BY min(i)), ' '),
      DETAIL = coalesce(p_miss, '[]')::text;
  END IF;
END;
$$;

-- Text chyby zmluvy pre náhľad (obmedzenia databázy → slovenská hláška)
CREATE FUNCTION contract_import_error(p_constraint text, p_state text, p_message text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE coalesce(p_constraint, '')
    WHEN 'contract_oom_overlap' THEN 'OOM je v rovnakom čase v inej podpísanej zmluve – prekrytie (opravte v Office portáli).'
    WHEN 'contract_price_overlap' THEN 'Dve ceny tej istej zložky v jednom období – opravte v Office portáli.'
    WHEN 'company_country_ico_key' THEN 'Firma s týmto IČO už v CRM je.'
    WHEN 'company_ico_format_check' THEN 'IČO firmy má nesprávny tvar.'
    WHEN 'company_op_person_key' THEN 'Osoba_ID z Office portálu je v CRM pri inej firme.'
    WHEN 'contact_op_person_key' THEN 'Osoba_ID z Office portálu je v CRM pri inej osobe.'
    WHEN 'contract_number_key' THEN 'Číslo zmluvy je v CRM pri inej zmluve.'
    WHEN 'contract_op_id_key' THEN 'ID zmluvy z Office portálu je v CRM pri inej zmluve.'
    WHEN 'contract_oom_period_check' THEN 'Účinnosť do je pred účinnosťou od.'
    WHEN 'contract_crm_valid_to_check' THEN 'Účinnosť do je pred účinnosťou od.'
    WHEN 'contract_viwa_package_type_check' THEN 'Balík VIWA sa zadáva iba pri zmluve VIWA.'
    ELSE CASE WHEN p_state IN ('22P02', '22007', '22008', '22003') THEN 'Neplatná hodnota v riadku (číslo alebo dátum).'
              ELSE p_message END
  END
$$;

-- Jedna zmluva z Office portálu (všetky jej riadky): zákazník, OOM v zmluve, ceny, príznaky (časti 8, 25).
-- p_xm: riadky XM Trade s číslom tejto zmluvy; p_deferred: nové OOM z XM Trade, ktoré čakajú na zákazníka zo zmluvy.
-- Chyba = výnimka (volajúci vráti celú zmluvu späť). Vráti {action, contract_id, changes, warnings, xm, customer_new, …}.
CREATE FUNCTION contract_import_one(p_org uuid, p_rows jsonb, p_xm jsonb, p_deferred jsonb) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  c_head constant text[] := ARRAY['op_id', 'number', 'phase', 'commodity', 'household', 'ico', 'dic', 'ic_dph', 'company_name',
    'first_name', 'last_name', 'person_op_id', 'small_business', 'list_price', 'auto_prolong', 'valid_from', 'valid_to',
    'signed_on', 'created_by_name', 'owner_name', 'updated_at', 'viwa_package', 'close_reason', 'sum_mwh'];
  c_phase constant jsonb := '{"rozpracovana": "Rozpracovaná", "caka_na_podpis": "Čaká na podpis",
    "fyzicke_podpisovanie": "Fyzické podpisovanie", "elektronicke_podpisovanie": "Elektronické podpisovanie",
    "podpisana": "Podpísaná", "odmietnuta": "Odmietnutá", "ukoncena": "Ukončená", "neuspesna": "Neúspešná"}';
  c_type constant jsonb := '{"dodavka_domacnost": "dodávka – domácnosť", "dodavka_firma_nn": "dodávka – firma NN",
    "dodavka_firma_vn": "dodávka – firma VN", "vykup": "výkup", "viwa": "VIWA"}';
  h          jsonb := p_rows -> 0;
  v_import   uuid := nullif(current_setting('app.contract_import_id', true), '')::uuid;
  v_country  country_code := (SELECT country FROM org WHERE id = p_org);
  v_err      text[] := '{}';
  v_warn     text[] := '{}';
  v_chg      text[] := '{}';
  v_kontr    text[] := '{}';
  v_miss     jsonb := '[]';
  v_xm_out   jsonb := '[]';
  v_cols     text[];
  a          import_alias;
  v_phase    contract_phase;
  v_owner    uuid;
  v_old      contract;
  v_new      contract;
  v_company  uuid;
  v_person   uuid;
  v_cust_new boolean := false;
  v_digits   text;
  v_ico      text;
  v_cust_org uuid;
  v_type     contract_type;
  v_reason   contract_close_reason;
  v_package  text;
  v_from     date;
  v_eics     text[];
  v_eic      text;
  o          oom;
  v_oom      jsonb := '{}';
  v_volt     text[];
  v_pid      uuid;
  v_prog     uuid;
  v_tmp      jsonb;
  v_prices   jsonb;
  co         record;
  v_name     text;
  v_n        integer;
  v_detail   text;
  v_vo       uuid[] := '{}';
  v_d        text[];
BEGIN
  -- 1. hlavička zmluvy je rovnaká vo všetkých riadkoch; chyby čítania súboru
  SELECT array_agg(DISTINCT k ORDER BY k) INTO v_cols
    FROM unnest(c_head) k, jsonb_array_elements(p_rows) x
   WHERE x -> k IS DISTINCT FROM h -> k;
  IF v_cols IS NOT NULL THEN
    v_err := v_err || format('Riadky zmluvy sa líšia v stĺpcoch %s – opravte export.', array_to_string(v_cols, ', '));
  END IF;
  v_err := v_err || ARRAY(SELECT DISTINCT e FROM jsonb_array_elements(p_rows) x,
                                 jsonb_array_elements_text(coalesce(x -> 'parse_errors', '[]')) e);
  IF nullif(btrim(h ->> 'number'), '') IS NULL THEN
    v_err := v_err || 'Chýba číslo zmluvy.'::text;
  END IF;

  -- 2. existujúca zmluva: ID z Office portálu, potom číslo
  IF nullif(h ->> 'op_id', '') IS NOT NULL THEN
    SELECT * INTO v_old FROM contract WHERE op_id = (h ->> 'op_id')::uuid;
  END IF;
  IF v_old.id IS NULL THEN
    SELECT * INTO v_old FROM contract WHERE number = btrim(h ->> 'number');
    IF v_old.id IS NOT NULL AND v_old.op_id IS NOT NULL AND v_old.op_id::text IS DISTINCT FROM nullif(h ->> 'op_id', '') THEN
      v_err := v_err || format('Číslo zmluvy %s je v CRM pri inej zmluve z Office portálu.', h ->> 'number');
    END IF;
  END IF;
  IF v_old.id IS NOT NULL AND v_old.org_id <> p_org THEN
    v_err := v_err || 'Zmluva patrí inej spoločnosti skupiny.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 3. bez zmeny v Office portáli (Greatest_updated_at): nespracúva sa, iba údaje z XM Trade (účinnosť, produkt DD)
  IF v_old.id IS NOT NULL AND v_old.op_updated_at IS NOT NULL AND nullif(h ->> 'updated_at', '') IS NOT NULL
     AND (h ->> 'updated_at')::timestamptz <= v_old.op_updated_at THEN
    FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
      v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_old.company_id, v_old.person_id);
    END LOOP;
    v_chg := contract_import_xm_link(v_old.id, p_xm);
    RETURN jsonb_build_object('action', CASE WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
             'contract_id', v_old.id, 'changes', to_jsonb(v_chg), 'warnings', '[]'::jsonb, 'errors', '[]'::jsonb,
             'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', false,
             'company_id', v_old.company_id, 'person_id', v_old.person_id);
  END IF;

  -- 4. fáza a obchodník cez preklady (neznámy názov = chyba s „Pridať preklad“, rozhodnutie 5; otázka 22)
  a := import_alias_resolve(p_org, 'office_portal', 'faza', coalesce(h ->> 'phase', ''));
  IF a.id IS NULL THEN
    v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'faza', 'name', coalesce(h ->> 'phase', ''));
    v_err := v_err || format('Neznáma fáza „%s“ – pridajte preklad.', coalesce(h ->> 'phase', ''));
  ELSE
    v_phase := a.target::contract_phase;
  END IF;
  IF nullif(btrim(h ->> 'owner_name'), '') IS NOT NULL THEN
    a := import_alias_resolve(p_org, 'office_portal', 'obchodnik', h ->> 'owner_name');
    IF a.id IS NULL THEN
      v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'obchodnik', 'name', btrim(h ->> 'owner_name'));
      v_err := v_err || format('Neznámy obchodník „%s“ – pridajte preklad na používateľa CRM.', btrim(h ->> 'owner_name'));
    ELSE
      v_owner := a.target::uuid;
    END IF;
  ELSIF v_old.owner_id IS NULL THEN
    -- tvorca zmluvy sa za obchodníka nedosadzuje (Peter, otázka 22), je iba informácia
    v_warn := v_warn || ('Zmluva nemá obchodníka (Uzatvoril) – uloží sa bez neho'
                         || coalesce(format(' (vytvoril: %s)', nullif(btrim(h ->> 'created_by_name'), '')), '') || '.');
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 5. zákazník (časť 8.2): firma podľa IČO, domácnosť podľa Osoba_ID; chýbajúci sa založí s príznakom
  --    „založený importom“, vlastník = obchodník zo zmluvy (doplnok b)
  v_eics := ARRAY(SELECT DISTINCT upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) FROM jsonb_array_elements(p_rows) x
                   WHERE nullif(btrim(x ->> 'eic'), '') IS NOT NULL ORDER BY 1);
  IF coalesce((h ->> 'household')::boolean, false) THEN
    v_name := btrim(concat_ws(' ', btrim(h ->> 'first_name'), btrim(h ->> 'last_name')));
    IF nullif(h ->> 'person_op_id', '') IS NOT NULL THEN
      SELECT id INTO v_person FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid;
    END IF;
    v_person := coalesce(v_person, v_old.person_id);
    IF v_person IS NULL THEN
      -- prvé párovanie (napr. po presune z HubSpotu): aktuálny zákazník-osoba OOM zmluvy s rovnakým menom
      SELECT min(p.id::text)::uuid, count(DISTINCT p.id) INTO v_person, v_n
        FROM oom x JOIN contact p ON p.id = x.person_id
       WHERE x.org_id = p_org AND x.eic = ANY (v_eics) AND p.op_person_id IS NULL
         AND import_name_norm(p.first_name || ' ' || p.last_name) = import_name_norm(v_name);
      IF v_n > 1 THEN
        v_person := NULL;
      END IF;
    END IF;
    IF v_person IS NOT NULL THEN
      IF NOT crm_contact_access(v_person, 'view') THEN
        v_err := v_err || 'Osoba zákazníka je v CRM, ale nemáte k nej prístup.'::text;
      END IF;
      UPDATE contact SET op_person_id = (h ->> 'person_op_id')::uuid
       WHERE id = v_person AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
         AND NOT EXISTS (SELECT 1 FROM contact WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
    ELSIF nullif(btrim(h ->> 'first_name'), '') IS NULL OR nullif(btrim(h ->> 'last_name'), '') IS NULL THEN
      v_err := v_err || 'Nová osoba: chýba meno alebo priezvisko.'::text;
    ELSE
      IF EXISTS (SELECT 1 FROM contact WHERE org_id = p_org
                    AND import_name_norm(first_name || ' ' || last_name) = import_name_norm(v_name)) THEN
        v_warn := v_warn || 'Možná duplicita: osoba s rovnakým menom už v CRM je – založí sa nová, skontrolujte.'::text;
        v_kontr := v_kontr || 'možná duplicita osoby'::text;
      END IF;
      INSERT INTO contact (org_id, first_name, last_name, is_household, owner_id, op_person_id, created_by_import, address)
      VALUES (p_org, btrim(h ->> 'first_name'), btrim(h ->> 'last_name'), true, v_owner,
              nullif(h ->> 'person_op_id', '')::uuid, v_import,
              (SELECT btrim(x ->> 'address') FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                WHERE nullif(btrim(x ->> 'address'), '') IS NOT NULL LIMIT 1))
      RETURNING id INTO v_person;
      v_cust_new := true;
    END IF;
  ELSE
    v_digits := regexp_replace(coalesce(h ->> 'ico', ''), '\D', '', 'g');
    v_ico := CASE WHEN v_country = 'HR' THEN v_digits ELSE lpad(v_digits, 8, '0') END;
    IF v_digits = '' THEN
      v_err := v_err || 'Chýba IČO firmy.'::text;
    ELSE
      SELECT id, org_id INTO v_company, v_cust_org FROM company WHERE country = v_country AND ico = v_ico;
      IF v_company IS NOT NULL AND v_cust_org <> p_org THEN
        v_err := v_err || format('Firma s IČO %s patrí inej spoločnosti skupiny.', v_ico);
      ELSIF v_company IS NOT NULL THEN
        IF NOT crm_company_access(v_company, 'view') THEN
          v_err := v_err || format('Firma s IČO %s je v CRM, ale nemáte k nej prístup.', v_ico);
        END IF;
        UPDATE company SET op_person_id = (h ->> 'person_op_id')::uuid
         WHERE id = v_company AND op_person_id IS NULL AND nullif(h ->> 'person_op_id', '') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM company WHERE org_id = p_org AND op_person_id = (h ->> 'person_op_id')::uuid);
      ELSIF nullif(btrim(h ->> 'company_name'), '') IS NULL THEN
        v_err := v_err || 'Nová firma: chýba názov.'::text;
      ELSE
        INSERT INTO company (org_id, name, ico, dic, ic_dph, is_customer, owner_id, op_person_id, created_by_import)
        VALUES (p_org, btrim(h ->> 'company_name'), v_ico, nullif(btrim(h ->> 'dic'), ''), nullif(btrim(h ->> 'ic_dph'), ''),
                true, v_owner, nullif(h ->> 'person_op_id', '')::uuid, v_import)
        RETURNING id INTO v_company;
        v_cust_new := true;
      END IF;
    END IF;
  END IF;
  IF v_cust_new AND v_owner IS NULL THEN
    v_warn := v_warn || 'Nový zákazník je bez vlastníka – zmluva nemá obchodníka.'::text;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 6. nové OOM z XM Trade pre zákazníka tejto zmluvy (oba súbory v jednom behu); chyba OOM = chyba zmluvy
  --    s pôvodným dôvodom (aj chýbajúci preklad z XM Trade)
  FOR v_tmp IN SELECT x FROM jsonb_array_elements(p_deferred) x LOOP
    v_xm_out := v_xm_out || contract_import_xm_one(p_org, v_tmp, v_company, v_person);
    IF v_xm_out -> -1 ->> 'action' = 'chyba' THEN
      v_err := v_err || format('OOM %s (XM Trade, riadok %s): %s', v_xm_out -> -1 ->> 'eic', v_tmp ->> 'row', v_xm_out -> -1 ->> 'error');
      v_miss := v_miss || coalesce(v_xm_out -> -1 -> 'missing', '[]');
    END IF;
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 7. OOM zmluvy: musia byť v CRM; produkt a program pri OOM, množstvo VT/NT (MWh), výkon zdroja
  IF cardinality(v_eics) = 0 THEN
    v_err := v_err || 'Zmluva nemá žiadne OOM (EIC).'::text;
  END IF;
  FOREACH v_eic IN ARRAY v_eics LOOP
    SELECT * INTO o FROM oom WHERE eic = v_eic;
    IF o.id IS NULL THEN
      v_err := v_err || format('OOM %s nie je v CRM – najprv nahrajte export z XM Trade.', v_eic);
      CONTINUE;
    ELSIF o.org_id <> p_org THEN
      v_err := v_err || format('OOM %s patrí inej spoločnosti skupiny.', v_eic);
      CONTINUE;
    END IF;
    IF contract_import_eic_warning(v_eic) IS NOT NULL THEN
      v_warn := v_warn || contract_import_eic_warning(v_eic);
    END IF;
    IF (o.company_id, o.person_id) IS DISTINCT FROM (v_company, v_person) THEN
      v_warn := v_warn || format('OOM %s má v CRM iného aktuálneho zákazníka ako zmluva (prepis?).', v_eic);
    END IF;
    v_tmp := (SELECT jsonb_agg(x ORDER BY (x ->> 'row')::int) FROM jsonb_array_elements(p_rows) x
               WHERE upper(regexp_replace(x ->> 'eic', '\s', '', 'g')) = v_eic);
    IF (SELECT count(DISTINCT jsonb_build_array(x -> 'qty_vt_mwh', x -> 'qty_nt_mwh', x -> 'source_power_kw', x -> 'product_oom'))
          FROM jsonb_array_elements(v_tmp) x) > 1 THEN
      v_warn := v_warn || format('OOM %s: riadky sa líšia v množstve, výkone alebo produkte – použije sa prvý.', v_eic);
    END IF;
    v_pid := NULL;
    v_prog := NULL;
    v_name := btrim(coalesce(v_tmp -> 0 ->> 'product_oom', ''));
    IF v_name <> '' THEN
      a := import_alias_resolve(p_org, 'office_portal', 'produkt_oom', v_name);
      IF a.id IS NULL THEN
        IF NOT v_miss @> jsonb_build_array(jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name)) THEN
          v_miss := v_miss || jsonb_build_object('source', 'office_portal', 'kind', 'produkt_oom', 'name', v_name);
          v_err := v_err || format('Neznámy produkt pri OOM „%s“ – pridajte preklad.', v_name);
        END IF;
      ELSIF coalesce((a.target_extra ->> 'program')::boolean, false) THEN
        -- VBattery: program z Office portálu, produkt DDx z XM Trade (rozhodnutie 4, otázka 12a) iba pri OOM spotreby;
        -- výrobné (otázka 24) a virtuálne OOM majú iba program
        v_prog := (SELECT id FROM product WHERE code = a.target);
        IF o.type = 'spotreba' THEN
          v_pid := coalesce(contract_import_xm_dd((SELECT x ->> 'product' FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
                                                    WHERE x ->> 'eic' = v_eic LIMIT 1)),
                            (SELECT x.product_id FROM contract_oom x WHERE x.contract_id = v_old.id AND x.oom_id = o.id));
          IF v_pid IS NULL THEN
            v_warn := v_warn || format('OOM %s: produkt DD pri VBattery doplní export z XM Trade.', v_eic);
          END IF;
        END IF;
      ELSIF a.target_extra ? 'ano' THEN
        -- DDx: ANO alebo NIE Energopomoc podľa cenovej regulácie OOM
        v_pid := (SELECT id FROM product WHERE code = CASE o.price_regulation WHEN true THEN a.target_extra ->> 'ano'
                                                                              WHEN false THEN a.target END);
        IF o.price_regulation IS NULL THEN
          v_warn := v_warn || format('OOM %s nemá cenovú reguláciu – produkt %s ANO/NIE nejde určiť.', v_eic, v_name);
        END IF;
      ELSE
        v_pid := (SELECT id FROM product WHERE code = a.target);
      END IF;
      IF coalesce((a.target_extra ->> 'verejne_osvetlenie')::boolean, false)
         OR (SELECT tariff_variant FROM product WHERE id = v_pid) = 'verejne_osvetlenie' THEN
        v_vo := v_vo || o.id;
      END IF;
    END IF;
    IF nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0) IS NOT NULL AND o.source_power_kw IS NOT NULL
       AND round((v_tmp -> 0 ->> 'source_power_kw')::numeric, 3) <> o.source_power_kw THEN
      v_warn := v_warn || format('OOM %s: výkon zdroja v zmluve %s kW, na OOM %s kW (OOM sa nemení).', v_eic,
                                 (v_tmp -> 0 ->> 'source_power_kw')::numeric, o.source_power_kw);
    END IF;
    v_oom := v_oom || jsonb_build_object(v_eic, jsonb_build_object(
               'oom_id', o.id, 'eic', v_eic, 'product_id', v_pid, 'program_id', v_prog, 'voltage', o.voltage_level,
               'qty_vt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_vt_mwh')::numeric, 0), 3),
               'qty_nt_mwh', round(coalesce((v_tmp -> 0 ->> 'qty_nt_mwh')::numeric, 0), 3),
               'source_power_kw', round(nullif((v_tmp -> 0 ->> 'source_power_kw')::numeric, 0), 3)));
  END LOOP;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 8. typ zmluvy (časť 1): výkup, VIWA, domácnosť, firma NN/VN podľa napäťovej úrovne OOM
  v_volt := ARRAY(SELECT DISTINCT coalesce(y.value ->> 'voltage', '') FROM jsonb_each(v_oom) y);
  v_type := CASE
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina_vyroba' THEN 'vykup'
    WHEN import_name_norm(h ->> 'commodity') = 'nezname' OR h ->> 'number' ~* 'VIW' THEN 'viwa'
    WHEN coalesce((h ->> 'household')::boolean, false) THEN 'dodavka_domacnost'
    WHEN import_name_norm(h ->> 'commodity') = 'elektrina' THEN
      CASE WHEN v_volt && ARRAY['vn', 'vvn'] THEN 'dodavka_firma_vn' ELSE 'dodavka_firma_nn' END
  END::contract_type;
  IF v_type IS NULL THEN
    v_err := v_err || format('Neznáma komodita „%s“.', coalesce(h ->> 'commodity', ''));
  ELSIF v_type::text LIKE 'dodavka_firma%' THEN
    IF v_volt && ARRAY['vn', 'vvn'] AND 'nn' = ANY (v_volt) THEN
      v_err := v_err || 'Zmluva má OOM na NN aj VN – NN a VN sú samostatné zmluvy.'::text;
    ELSIF '' = ANY (v_volt) THEN
      v_warn := v_warn || 'Napäťová úroveň OOM chýba – zmluva je typu firma NN.'::text;
    END IF;
  END IF;
  -- údaje CRM z exportu iba neprázdne (doplnok a); balík VIWA a dôvod uzatvorenia, keď ich zostava doplní
  v_package := lower(nullif(btrim(h ->> 'viwa_package'), ''));
  IF v_package IS NOT NULL AND v_package NOT IN ('basic', 'plus', 'pro') THEN
    v_err := v_err || format('Neznámy balík VIWA „%s“.', h ->> 'viwa_package');
  END IF;
  IF nullif(btrim(h ->> 'close_reason'), '') IS NOT NULL THEN
    v_reason := (SELECT e FROM unnest(enum_range(NULL::contract_close_reason)) e
                  WHERE e::text = replace(import_name_norm(h ->> 'close_reason'), ' ', '_'));
    IF v_reason IS NULL THEN
      v_err := v_err || format('Neznámy dôvod uzatvorenia „%s“.', h ->> 'close_reason');
    END IF;
  END IF;
  PERFORM contract_import_fail(v_err, v_miss);

  -- 9. zmluva; prázdna bunka nikdy neprepíše hodnotu v CRM (doplnok a); účinnosť domácnosti z XM Trade (rozhodnutie 3)
  v_from := CASE WHEN v_type = 'dodavka_domacnost'
                 THEN coalesce(contract_import_xm_from(p_xm, v_eics), (h ->> 'valid_from')::date, v_old.valid_from)
                 ELSE coalesce((h ->> 'valid_from')::date, v_old.valid_from) END;
  IF v_from IS NULL AND v_phase = 'podpisana' THEN
    v_warn := v_warn || CASE WHEN v_type = 'dodavka_domacnost' THEN 'Účinnosť od chýba – doplní ju export z XM Trade.'
                             ELSE 'Účinnosť od chýba.' END;
  END IF;
  IF v_old.id IS NULL THEN
    INSERT INTO contract (org_id, number, op_id, company_id, person_id, type, phase, valid_from, valid_to, signed_on,
                          auto_prolong, small_business, list_price, viwa_package, close_reason, owner_id, created_by_name,
                          last_import_id)
    VALUES (p_org, btrim(h ->> 'number'), nullif(h ->> 'op_id', '')::uuid, v_company, v_person, v_type, v_phase, v_from,
            (h ->> 'valid_to')::date, (h ->> 'signed_on')::date, coalesce((h ->> 'auto_prolong')::boolean, false),
            coalesce((h ->> 'small_business')::boolean, false), coalesce((h ->> 'list_price')::boolean, false),
            v_package, v_reason, v_owner, nullif(btrim(h ->> 'created_by_name'), ''), v_import)
    RETURNING * INTO v_new;
    v_chg := v_chg || format('Nová zmluva: %s, %s, OOM %s', c_type ->> v_type::text, c_phase ->> v_phase::text,
                             cardinality(v_eics));
  ELSE
    UPDATE contract
       SET number = btrim(h ->> 'number'), op_id = coalesce(nullif(h ->> 'op_id', '')::uuid, op_id),
           company_id = v_company, person_id = v_person, type = v_type, phase = v_phase, valid_from = v_from,
           valid_to = coalesce((h ->> 'valid_to')::date, valid_to), signed_on = coalesce((h ->> 'signed_on')::date, signed_on),
           auto_prolong = coalesce((h ->> 'auto_prolong')::boolean, auto_prolong),
           small_business = coalesce((h ->> 'small_business')::boolean, small_business),
           list_price = coalesce((h ->> 'list_price')::boolean, list_price),
           viwa_package = coalesce(v_package, viwa_package), close_reason = coalesce(v_reason, close_reason),
           owner_id = coalesce(v_owner, owner_id),
           created_by_name = coalesce(nullif(btrim(h ->> 'created_by_name'), ''), created_by_name)
     WHERE id = v_old.id
    RETURNING * INTO v_new;
    IF v_new.number <> v_old.number THEN
      v_chg := v_chg || format('Číslo %s → %s', v_old.number, v_new.number);
    END IF;
    IF v_new.phase <> v_old.phase THEN
      v_chg := v_chg || format('Fáza %s → %s', c_phase ->> v_old.phase::text, c_phase ->> v_new.phase::text);
    END IF;
    IF v_new.type <> v_old.type THEN
      v_chg := v_chg || format('Typ %s → %s', c_type ->> v_old.type::text, c_type ->> v_new.type::text);
    END IF;
    IF (v_new.company_id, v_new.person_id) IS DISTINCT FROM (v_old.company_id, v_old.person_id) THEN
      v_chg := v_chg || 'Zákazník zmluvy zmenený'::text;
    END IF;
    IF v_new.valid_from IS DISTINCT FROM v_old.valid_from THEN
      v_chg := v_chg || format('Účinnosť od %s → %s', coalesce(to_char(v_old.valid_from, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.valid_from, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.valid_to IS DISTINCT FROM v_old.valid_to THEN
      v_chg := v_chg || format('Účinnosť do %s → %s', coalesce(to_char(v_old.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'),
                               coalesce(to_char(v_new.valid_to, 'FMDD. FMMM. YYYY'), 'neurčito'));
    END IF;
    IF v_new.signed_on IS DISTINCT FROM v_old.signed_on THEN
      v_chg := v_chg || format('Platnosť od %s → %s', coalesce(to_char(v_old.signed_on, 'FMDD. FMMM. YYYY'), '–'),
                               coalesce(to_char(v_new.signed_on, 'FMDD. FMMM. YYYY'), '–'));
    END IF;
    IF v_new.owner_id IS DISTINCT FROM v_old.owner_id THEN
      v_chg := v_chg || format('Obchodník %s → %s', coalesce((SELECT name FROM app_user WHERE id = v_old.owner_id), '–'),
                               coalesce((SELECT name FROM app_user WHERE id = v_new.owner_id), '–'));
    END IF;
    IF (v_new.auto_prolong, v_new.small_business, v_new.list_price, v_new.viwa_package, v_new.close_reason)
       IS DISTINCT FROM (v_old.auto_prolong, v_old.small_business, v_old.list_price, v_old.viwa_package, v_old.close_reason) THEN
      v_chg := v_chg || 'Príznaky zmluvy (prolongácia, malý podnik, cenníková cena, balík, dôvod)'::text;
    END IF;
  END IF;

  -- 10. OOM v zmluve: odobraté, zmenené, nové (nástupníctvo a prekrytie strážia spúšťače z 0025)
  FOR co IN SELECT x.*, oo.eic FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id WHERE x.contract_id = v_new.id LOOP
    v_tmp := v_oom -> co.eic;
    IF v_tmp IS NULL THEN
      DELETE FROM contract_price WHERE contract_id = v_new.id AND oom_id = co.oom_id;
      DELETE FROM contract_oom WHERE id = co.id;
      v_chg := v_chg || format('OOM %s odobraté', co.eic);
      IF v_new.phase = 'podpisana' THEN
        v_warn := v_warn || format('OOM %s v exporte podpísanej zmluvy chýba – odobraté (zmena má byť novou zmluvou).', co.eic);
      END IF;
    ELSE
      v_d := '{}';
      IF co.qty_vt_mwh <> (v_tmp ->> 'qty_vt_mwh')::numeric OR co.qty_nt_mwh <> (v_tmp ->> 'qty_nt_mwh')::numeric THEN
        v_d := v_d || format('množstvo VT/NT %s/%s → %s/%s MWh', co.qty_vt_mwh, co.qty_nt_mwh,
                             (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric);
      END IF;
      IF co.product_id IS DISTINCT FROM (v_tmp ->> 'product_id')::uuid OR co.program_id IS DISTINCT FROM (v_tmp ->> 'program_id')::uuid THEN
        v_d := v_d || format('produkt %s → %s',
                 coalesce((SELECT string_agg(name, ' + ') FROM product WHERE id IN (co.product_id, co.program_id)), '–'),
                 coalesce((SELECT string_agg(name, ' + ') FROM product
                            WHERE id IN ((v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid)), '–'));
      END IF;
      IF co.source_power_kw IS DISTINCT FROM (v_tmp ->> 'source_power_kw')::numeric THEN
        v_d := v_d || format('výkon %s → %s kW', coalesce(co.source_power_kw::text, '–'), coalesce(v_tmp ->> 'source_power_kw', '–'));
      END IF;
      IF cardinality(v_d) > 0 THEN
        UPDATE contract_oom
           SET product_id = (v_tmp ->> 'product_id')::uuid, program_id = (v_tmp ->> 'program_id')::uuid,
               qty_vt_mwh = (v_tmp ->> 'qty_vt_mwh')::numeric, qty_nt_mwh = (v_tmp ->> 'qty_nt_mwh')::numeric,
               source_power_kw = (v_tmp ->> 'source_power_kw')::numeric
         WHERE id = co.id;
        v_chg := v_chg || format('OOM %s: %s', co.eic, array_to_string(v_d, ', '));
      END IF;
    END IF;
  END LOOP;
  FOR v_tmp IN SELECT y.value FROM jsonb_each(v_oom) y ORDER BY y.key LOOP
    IF NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = v_new.id AND oom_id = (v_tmp ->> 'oom_id')::uuid) THEN
      INSERT INTO contract_oom (contract_id, oom_id, product_id, program_id, qty_vt_mwh, qty_nt_mwh, source_power_kw)
      VALUES (v_new.id, (v_tmp ->> 'oom_id')::uuid, (v_tmp ->> 'product_id')::uuid, (v_tmp ->> 'program_id')::uuid,
              (v_tmp ->> 'qty_vt_mwh')::numeric, (v_tmp ->> 'qty_nt_mwh')::numeric, (v_tmp ->> 'source_power_kw')::numeric);
      IF v_old.id IS NOT NULL THEN
        v_chg := v_chg || format('OOM %s pridané', v_tmp ->> 'eic');
      END IF;
    END IF;
  END LOOP;
  -- verejné osvetlenie (odpoveď 4): import príznak iba nastaví, nikdy nezruší
  IF cardinality(v_vo) > 0 THEN
    PERFORM set_config('crm.oom_system', 'on', true);
    UPDATE oom SET public_lighting = true WHERE id = ANY (v_vo) AND NOT public_lighting;
    IF FOUND THEN
      v_chg := v_chg || 'Verejné osvetlenie nastavené na OOM'::text;
    END IF;
    PERFORM set_config('crm.oom_system', '', true);
  END IF;

  -- 11. ceny: individuálne z Office portálu, potom z cenníkov
  SELECT jsonb_object_agg(oo.eic, jsonb_build_object(
           'oom_id', x.oom_id, 'product_id', x.product_id, 'valid_from', x.valid_from, 'valid_to', x.valid_to,
           'tariff', CASE WHEN p.tariff_type = 'jednotarif' THEN '1t'
                          WHEN p.tariff_type = 'dvojtarif' AND p.tariff_variant = 'vykurovanie' THEN '2t_vyk'
                          WHEN p.tariff_type = 'dvojtarif' THEN '2t' END))
    INTO v_tmp
    FROM contract_oom x JOIN oom oo ON oo.id = x.oom_id LEFT JOIN product p ON p.id = x.product_id
   WHERE x.contract_id = v_new.id;
  v_prices := contract_import_op_prices(p_org, v_new, p_rows, coalesce(v_tmp, '{}'));
  v_err := v_err || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'errors'));
  v_miss := v_miss || (v_prices -> 'missing');
  PERFORM contract_import_fail(v_err, v_miss);
  v_warn := v_warn || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'warnings'));
  v_kontr := v_kontr || ARRAY(SELECT jsonb_array_elements_text(v_prices -> 'kontrola'));
  IF v_new.list_price AND jsonb_array_length(v_prices -> 'rows') > 0 THEN
    v_warn := v_warn || 'Zmluva má cenníkovú cenu aj individuálne ceny v exporte – platí cenník.'::text;
    v_prices := jsonb_set(v_prices, '{rows}', '[]');
  END IF;
  IF contract_price_set(v_new.id, 'op', v_prices -> 'rows') AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Individuálne ceny zmenené'::text;
  END IF;
  IF contract_price_list_sync(v_new.id) AND v_old.id IS NOT NULL THEN
    v_chg := v_chg || 'Ceny z cenníka zmenené'::text;
  END IF;

  -- 12. príznaky a upozornenia
  v_detail := contract_price_missing_refresh(v_new.id);
  IF v_detail IS NOT NULL THEN
    v_warn := v_warn || ('Chýba cena: ' || v_detail);
  END IF;
  IF v_old.id IS NULL THEN
    -- produkt Dobieha alebo Ukončený pri novej zmluve podpísanej po zmene stavu produktu
    v_kontr := v_kontr || ARRAY(
      SELECT DISTINCT format('produkt %s je %s', p.name, CASE p.status WHEN 'dobieha' THEN 'Dobieha' ELSE 'Ukončený' END)
        FROM contract_oom x JOIN product p ON p.id IN (x.product_id, x.program_id)
       WHERE x.contract_id = v_new.id AND p.status <> 'predava_sa'
         AND (v_new.signed_on IS NULL OR v_new.signed_on >= p.updated_at::date));
  END IF;
  IF cardinality(v_kontr) > 0 THEN
    v_detail := array_to_string(ARRAY(SELECT e FROM unnest(v_kontr) WITH ORDINALITY u (e, i) GROUP BY e ORDER BY min(i)), '; ');
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = v_new.id AND code = 'kontrola_importu' AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (v_new.id, 'kontrola_importu', v_detail);
    END IF;
    v_warn := v_warn || ('Na kontrolu: ' || v_detail);
  END IF;
  v_warn := v_warn || ARRAY(
    SELECT format('Zmluva %s na OOM %s končí %s – nastupuje táto zmluva.', k.number, oo.eic, to_char(x.valid_to, 'FMDD. FMMM. YYYY'))
      FROM contract_oom x JOIN contract k ON k.id = x.contract_id JOIN oom oo ON oo.id = x.oom_id
     WHERE x.successor_id = v_new.id ORDER BY k.number, oo.eic);
  IF nullif(h ->> 'sum_mwh', '') IS NOT NULL
     AND abs((h ->> 'sum_mwh')::numeric - (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom
                                            WHERE contract_id = v_new.id)) >= 0.001 THEN
    v_warn := v_warn || format('Súčet množstva zmluvy %s MWh sa líši od súčtu OOM %s MWh (platí množstvo pri OOM).',
                               round((h ->> 'sum_mwh')::numeric, 3),
                               (SELECT coalesce(sum(qty_vt_mwh + qty_nt_mwh), 0) FROM contract_oom WHERE contract_id = v_new.id));
  END IF;

  -- 13. čas zmeny v Office portáli a posledný import
  UPDATE contract
     SET op_updated_at = nullif(h ->> 'updated_at', '')::timestamptz,
         last_import_id = CASE WHEN v_old.id IS NULL OR cardinality(v_chg) > 0 THEN coalesce(v_import, last_import_id)
                               ELSE last_import_id END
   WHERE id = v_new.id;
  RETURN jsonb_build_object(
    'action', CASE WHEN v_old.id IS NULL THEN 'nova' WHEN cardinality(v_chg) > 0 THEN 'zmena' ELSE 'bez_zmeny' END,
    'contract_id', v_new.id, 'changes', to_jsonb(v_chg), 'warnings', to_jsonb(v_warn), 'errors', '[]'::jsonb,
    'missing', '[]'::jsonb, 'xm', v_xm_out, 'customer_new', v_cust_new, 'company_id', v_company, 'person_id', v_person);
END;
$$;

-- Celý import (oba súbory alebo jeden): najprv XM Trade (OOM), potom zmluvy Office portálu (časť 25.1).
-- Vstup pripraví API (dátumy, MWh, bez dátumu narodenia a rodného čísla). Vráti {contracts: [...], oom: [...]}.
CREATE FUNCTION contract_import_rows(p_org uuid, p_xm jsonb, p_op jsonb) RETURNS jsonb
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
DECLARE
  v_country country_code := (SELECT country FROM org WHERE id = p_org);
  v_xm      jsonb;
  v_groups  jsonb;
  v_nums    jsonb;          -- čísla zmlúv tejto dávky (bez testovacích)
  v_xm_num  jsonb;          -- číslo zmluvy → riadky XM Trade
  v_dup     text[];
  v_def     jsonb := '{}';  -- číslo zmluvy → nové OOM z XM Trade, ktoré čakajú na zákazníka zo zmluvy
  v_links   jsonb := '{}';  -- číslo zmluvy v CRM (mimo dávky) → riadky XM Trade
  v_out_c   jsonb := '[]';
  v_out_x   jsonb := '[]';
  v_touch   jsonb := '{}';
  r         jsonb;
  g         jsonb;
  h         jsonb;
  v_rows    jsonb;
  v_res     jsonb;
  v_base    jsonb;
  v_eic     text;
  v_num     text;
  v_ico     text;
  v_company uuid;
  v_person  uuid;
  v_k       contract;
  v_chg     text[];
  v_cons    text;
  v_msg     text;
  v_detail  text;
  v_state   text;
  v_cust    record;
BEGIN
  PERFORM set_config('crm.contract_import', 'on', true);
  SELECT coalesce(jsonb_agg(x || jsonb_build_object('eic', upper(regexp_replace(coalesce(x ->> 'eic', ''), '\s', '', 'g')))
                            ORDER BY (x ->> 'row')::int), '[]')
    INTO v_xm FROM jsonb_array_elements(coalesce(p_xm, '[]')) x;
  SELECT coalesce(jsonb_agg(rs ORDER BY first_row), '[]') INTO v_groups
    FROM (SELECT jsonb_agg(x ORDER BY (x ->> 'row')::int) AS rs, min((x ->> 'row')::int) AS first_row
            FROM jsonb_array_elements(coalesce(p_op, '[]')) x
           GROUP BY coalesce(nullif(x ->> 'op_id', ''), 'c:' || coalesce(btrim(x ->> 'number'), ''))) s;
  SELECT coalesce(jsonb_object_agg(n, true), '{}') INTO v_nums
    FROM (SELECT DISTINCT btrim(x ->> 'number') AS n FROM jsonb_array_elements(coalesce(p_op, '[]')) x
           WHERE NOT coalesce((x ->> 'test')::boolean, false) AND nullif(btrim(x ->> 'number'), '') IS NOT NULL) s;
  SELECT coalesce(jsonb_object_agg(n, rs), '{}') INTO v_xm_num
    FROM (SELECT btrim(x ->> 'contract_number') AS n, jsonb_agg(x) AS rs FROM jsonb_array_elements(v_xm) x
           WHERE nullif(btrim(x ->> 'contract_number'), '') IS NOT NULL GROUP BY 1) s;
  v_dup := ARRAY(SELECT x ->> 'eic' FROM jsonb_array_elements(v_xm) x WHERE x ->> 'eic' <> '' GROUP BY 1 HAVING count(*) > 1);

  -- 1. XM Trade: OOM (existujúce; nové firmy podľa IČO; nové OOM zákazníka zmluvy, ktorá už je v CRM)
  FOR r IN SELECT x FROM jsonb_array_elements(v_xm) x LOOP
    v_eic := r ->> 'eic';
    v_num := nullif(btrim(r ->> 'contract_number'), '');
    v_company := NULL;
    v_person := NULL;
    IF v_eic = '' THEN
      v_out_x := v_out_x || jsonb_build_object('row', r -> 'row', 'eic', NULL, 'action', 'chyba', 'error', 'Chýba EIC.');
      CONTINUE;
    END IF;
    IF v_eic = ANY (v_dup) THEN
      v_out_x := v_out_x || jsonb_build_object('row', r -> 'row', 'eic', v_eic, 'action', 'chyba',
                              'error', 'EIC je v súbore XM Trade viackrát – nechajte ho v jednom riadku.');
      CONTINUE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM oom WHERE eic = v_eic) AND jsonb_array_length(coalesce(r -> 'parse_errors', '[]')) = 0 THEN
      v_ico := regexp_replace(coalesce(r ->> 'ico', ''), '\D', '', 'g');
      IF v_ico <> '' THEN
        SELECT id INTO v_company FROM company
         WHERE org_id = p_org AND country = v_country
           AND ico = CASE WHEN v_country = 'HR' THEN v_ico ELSE lpad(v_ico, 8, '0') END;
      END IF;
      IF v_company IS NULL AND v_num IS NOT NULL THEN
        IF v_nums ? v_num THEN
          v_def := jsonb_set(v_def, ARRAY[v_num], coalesce(v_def -> v_num, '[]') || r);
          CONTINUE;
        END IF;
        SELECT company_id, person_id INTO v_company, v_person FROM contract WHERE number = v_num AND org_id = p_org;
      END IF;
      IF v_company IS NULL AND v_person IS NULL THEN
        v_out_x := v_out_x || jsonb_build_object('row', r -> 'row', 'eic', v_eic, 'action', 'chyba',
          'error', 'Nové OOM: zákazníka nejde určiť (IČO firmy ani číslo zmluvy v CRM) – nahrajte aj export zmlúv z Office portálu.');
        CONTINUE;
      END IF;
    END IF;
    v_res := contract_import_xm_one(p_org, r, v_company, v_person);
    v_out_x := v_out_x || v_res;
    IF v_res ->> 'action' <> 'chyba' AND v_num IS NOT NULL AND NOT v_nums ? v_num THEN
      v_links := jsonb_set(v_links, ARRAY[v_num], coalesce(v_links -> v_num, '[]') || r);
    END IF;
  END LOOP;

  -- 1b. zmluvy domácností v CRM, ktorým XM Trade dopĺňa účinnosť a produkt DD
  FOR v_num, r IN SELECT key, value FROM jsonb_each(v_links) LOOP
    SELECT * INTO v_k FROM contract WHERE number = v_num AND org_id = p_org;
    CONTINUE WHEN v_k.id IS NULL;
    BEGIN
      v_chg := contract_import_xm_link(v_k.id, r);
      IF cardinality(v_chg) > 0 THEN
        v_out_c := v_out_c || jsonb_build_object('number', v_num, 'op_id', v_k.op_id, 'source', 'xm_trade', 'rows', '[]'::jsonb,
                     'customer', (SELECT customer_name FROM contract_v WHERE id = v_k.id), 'action', 'zmena',
                     'contract_id', v_k.id, 'changes', to_jsonb(v_chg), 'warnings', '[]'::jsonb, 'errors', '[]'::jsonb);
        v_touch := v_touch || jsonb_build_object(coalesce(v_k.company_id, v_k.person_id)::text,
                                                 jsonb_build_array(v_k.company_id, v_k.person_id));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_cons = CONSTRAINT_NAME, v_msg = MESSAGE_TEXT, v_state = RETURNED_SQLSTATE;
      v_out_c := v_out_c || jsonb_build_object('number', v_num, 'op_id', v_k.op_id, 'source', 'xm_trade', 'rows', '[]'::jsonb,
                   'action', 'chyba', 'changes', '[]'::jsonb, 'warnings', '[]'::jsonb,
                   'errors', jsonb_build_array(contract_import_error(v_cons, v_state, v_msg)));
    END;
  END LOOP;

  -- 2. Office portal: zmluvy; každá v samostatnej subtransakcii – chyba v zmluve = celá zmluva sa neuloží
  FOR g IN SELECT x FROM jsonb_array_elements(v_groups) x LOOP
    h := g -> 0;
    v_num := nullif(btrim(h ->> 'number'), '');
    v_rows := (SELECT coalesce(jsonb_agg(x), '[]') FROM jsonb_array_elements(g) x WHERE NOT coalesce((x ->> 'test')::boolean, false));
    v_base := jsonb_build_object('number', v_num, 'op_id', h ->> 'op_id', 'source', 'office_portal',
                'rows', (SELECT jsonb_agg(x -> 'row') FROM jsonb_array_elements(g) x),
                'customer', coalesce(nullif(btrim(h ->> 'company_name'), ''),
                                     nullif(btrim(concat_ws(' ', btrim(h ->> 'first_name'), btrim(h ->> 'last_name'))), '')));
    IF jsonb_array_length(v_rows) = 0 THEN
      v_out_c := v_out_c || (v_base || '{"action": "preskocene", "changes": [], "warnings": [], "errors": []}');
      CONTINUE;
    END IF;
    BEGIN
      v_res := contract_import_one(p_org, v_rows, coalesce(v_xm_num -> v_num, '[]'), coalesce(v_def -> v_num, '[]'));
      v_out_x := v_out_x || coalesce(v_res -> 'xm', '[]');
      v_out_c := v_out_c || (v_base || (v_res - 'xm' - 'company_id' - 'person_id'));
      IF coalesce(v_res ->> 'company_id', v_res ->> 'person_id') IS NOT NULL THEN
        v_touch := v_touch || jsonb_build_object(coalesce(v_res ->> 'company_id', v_res ->> 'person_id'),
                                                 jsonb_build_array(v_res -> 'company_id', v_res -> 'person_id'));
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_cons = CONSTRAINT_NAME, v_msg = MESSAGE_TEXT, v_detail = PG_EXCEPTION_DETAIL,
                              v_state = RETURNED_SQLSTATE;
      v_out_c := v_out_c || (v_base || jsonb_build_object('action', 'chyba', 'changes', '[]'::jsonb, 'warnings', '[]'::jsonb,
                   'errors', jsonb_build_array(contract_import_error(v_cons, v_state, v_msg)),
                   'missing', CASE WHEN v_state = 'P0090' THEN coalesce(nullif(v_detail, ''), '[]')::jsonb ELSE '[]'::jsonb END));
      v_out_x := v_out_x || coalesce((SELECT jsonb_agg(jsonb_build_object('row', x -> 'row', 'eic', x ->> 'eic', 'action', 'chyba',
                   'error', format('Neuložilo sa – nové OOM sa založí spolu so zmluvou %s: %s', v_num,
                                   contract_import_error(v_cons, v_state, v_msg))))
                   FROM jsonb_array_elements(coalesce(v_def -> v_num, '[]')) x), '[]');
    END;
  END LOOP;

  -- 3. stav dotknutých zákazníkov raz na konci (ako import OOM)
  PERFORM set_config('crm.contract_import', '', true);
  IF crm_setting_on('customer_status_auto') THEN
    FOR v_cust IN SELECT (value ->> 0)::uuid AS company_id, (value ->> 1)::uuid AS person_id FROM jsonb_each(v_touch) LOOP
      PERFORM customer_refresh(v_cust.company_id, v_cust.person_id);
    END LOOP;
  END IF;
  RETURN jsonb_build_object(
    'contracts', v_out_c,
    'oom', (SELECT coalesce(jsonb_agg(x ORDER BY (x ->> 'row')::int), '[]') FROM jsonb_array_elements(v_out_x) x));
END;
$$;

CREATE FUNCTION contract_import_counts(p jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object(
    'zmluvy', (SELECT jsonb_build_object(
                 'spolu', count(*),
                 'nova', count(*) FILTER (WHERE x ->> 'action' = 'nova'),
                 'zmena', count(*) FILTER (WHERE x ->> 'action' = 'zmena'),
                 'bez_zmeny', count(*) FILTER (WHERE x ->> 'action' = 'bez_zmeny'),
                 'chyba', count(*) FILTER (WHERE x ->> 'action' = 'chyba'),
                 'preskocene', count(*) FILTER (WHERE x ->> 'action' = 'preskocene'),
                 'upozornenie', count(*) FILTER (WHERE x ->> 'action' IN ('nova', 'zmena', 'bez_zmeny')
                                                   AND jsonb_array_length(coalesce(x -> 'warnings', '[]')) > 0))
                 FROM jsonb_array_elements(coalesce(p -> 'contracts', '[]')) x),
    'oom', (SELECT jsonb_build_object(
              'spolu', count(*),
              'nove', count(*) FILTER (WHERE x ->> 'action' = 'nove'),
              'zmena', count(*) FILTER (WHERE x ->> 'action' = 'zmena'),
              'bez_zmeny', count(*) FILTER (WHERE x ->> 'action' = 'bez_zmeny'),
              'chyba', count(*) FILTER (WHERE x ->> 'action' = 'chyba'),
              'upozornenie', count(*) FILTER (WHERE x ->> 'action' <> 'chyba'
                                                AND jsonb_array_length(coalesce(x -> 'warnings', '[]')) > 0))
              FROM jsonb_array_elements(coalesce(p -> 'oom', '[]')) x))
$$;

-- Import zmlúv a OOM: náhľad (p_save = false, všetko sa skúsi a vráti späť) alebo uloženie (p_save = true, počty musia
-- sedieť s náhľadom, ktorý videl používateľ). Právo „import“ v module Zmluvy, pri súbore XM Trade aj v module OOM.
-- p_meta: {op_file_name, op_file_hash, xm_file_name, xm_file_hash}. Funkcia vlastníka: zmluvy aplikácia priamo nezapisuje.
CREATE FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}',
                                    p_expected jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_res    jsonb;
  v_counts jsonb;
  v_id     uuid;
BEGIN
  IF NOT crm_can_import('zmluvy') THEN
    RAISE EXCEPTION 'Import zmlúv nemáte povolený (Nastavenia → Tímy a práva).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) > 0 AND NOT crm_can_import('odberne_miesta') THEN
    RAISE EXCEPTION 'Import odberných miest z XM Trade nemáte povolený (Nastavenia → Tímy a práva).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT p_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'K tejto spoločnosti nemáte prístup.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_typeof(coalesce(p_xm, '[]')) <> 'array' OR jsonb_typeof(coalesce(p_op, '[]')) <> 'array'
     OR jsonb_array_length(coalesce(p_xm, '[]')) > 5000 OR jsonb_array_length(coalesce(p_op, '[]')) > 5000 THEN
    RAISE EXCEPTION 'Súbor má viac ako 5 000 riadkov – rozdeľte ho.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) + jsonb_array_length(coalesce(p_op, '[]')) = 0 THEN
    RAISE EXCEPTION 'Nahrajte export z Office portálu, z XM Trade alebo oba.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT p_save THEN
    BEGIN
      INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash)
      VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
              p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
              p_meta ->> 'xm_file_hash')
      RETURNING id INTO v_id;
      PERFORM set_config('app.contract_import_id', v_id::text, true);
      v_res := contract_import_rows(p_org, p_xm, p_op);
      RAISE EXCEPTION 'náhľad' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
    END;
    RETURN v_res || jsonb_build_object('counts', contract_import_counts(v_res));
  END IF;

  IF p_expected IS NULL THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL);
  END IF;
  IF coalesce((p_expected #>> '{zmluvy,nova}')::int, 0) + coalesce((p_expected #>> '{zmluvy,zmena}')::int, 0)
     + coalesce((p_expected #>> '{oom,nove}')::int, 0) + coalesce((p_expected #>> '{oom,zmena}')::int, 0) = 0 THEN
    RETURN jsonb_build_object('nothing', true, 'import_id', NULL, 'counts', p_expected);
  END IF;
  BEGIN
    INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash, counts)
    VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
            p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
            p_meta ->> 'xm_file_hash', p_expected)
    RETURNING id INTO v_id;
    PERFORM set_config('app.contract_import_id', v_id::text, true);
    v_res := contract_import_rows(p_org, p_xm, p_op);
    v_counts := contract_import_counts(v_res);
    IF v_counts IS DISTINCT FROM p_expected THEN
      RAISE EXCEPTION 'nesedí s náhľadom' USING ERRCODE = 'P0098';
    END IF;
    INSERT INTO contract_import_change (import_id, contract_id, action, summary)
    SELECT v_id, (x ->> 'contract_id')::uuid, min(x ->> 'action'),
           left(string_agg((SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(x -> 'changes') e), '; '), 4000)
      FROM jsonb_array_elements(v_res -> 'contracts') x
     WHERE x ->> 'action' IN ('nova', 'zmena') AND x ->> 'contract_id' IS NOT NULL
     GROUP BY 2;
    PERFORM set_config('app.contract_import_id', '', true);
  EXCEPTION WHEN SQLSTATE 'P0098' THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL, 'counts', v_counts);
  END;
  RETURN v_res || jsonb_build_object('import_id', v_id, 'counts', v_counts);
END;
$$;
COMMENT ON FUNCTION contract_import_run(uuid, jsonb, jsonb, boolean, jsonb, jsonb) IS
  'import zmlúv z Office portálu a OOM z XM Trade: náhľad (p_save = false) alebo uloženie s počtami z náhľadu';

-- ============================================================================
-- 9. RLS a práva
-- ============================================================================

ALTER TABLE contract_import ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_import_change ENABLE ROW LEVEL SECURITY;
CREATE POLICY contract_import_select ON contract_import FOR SELECT
  USING (crm_is_service() OR crm_is_admin()
         OR (crm_can_import('zmluvy') AND org_id = ANY ((SELECT crm_user_orgs())::uuid[])));
CREATE POLICY contract_import_change_select ON contract_import_change FOR SELECT
  USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id));

-- pomocné funkcie vlastníka nevolá aplikácia priamo (ceny a príznaky mení import, nočný beh a zmena balíka VIWA)
REVOKE EXECUTE ON FUNCTION contract_price_list_sync(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION contract_price_missing_refresh(uuid) FROM PUBLIC;

-- migrate:down

DROP POLICY IF EXISTS contract_import_change_select ON contract_import_change;
DROP POLICY IF EXISTS contract_import_select ON contract_import;
DROP FUNCTION IF EXISTS contract_import_run(uuid, jsonb, jsonb, boolean, jsonb, jsonb);
DROP FUNCTION IF EXISTS contract_import_counts(jsonb);
DROP FUNCTION IF EXISTS contract_import_rows(uuid, jsonb, jsonb);
DROP FUNCTION IF EXISTS contract_import_one(uuid, jsonb, jsonb, jsonb);
DROP FUNCTION IF EXISTS contract_import_error(text, text, text);
DROP FUNCTION IF EXISTS contract_import_fail(text[], jsonb);
DROP FUNCTION IF EXISTS contract_import_op_prices(uuid, contract, jsonb, jsonb);
DROP FUNCTION IF EXISTS contract_import_xm_link(uuid, jsonb);
DROP FUNCTION IF EXISTS contract_import_xm_one(uuid, jsonb, uuid, uuid);
DROP FUNCTION IF EXISTS contract_import_xm_from(jsonb, text[]);
DROP FUNCTION IF EXISTS contract_import_xm_dd(text);
DROP FUNCTION IF EXISTS contract_import_label(text, text);
DROP FUNCTION IF EXISTS contract_import_xm_code(uuid, text, text, text, text);
DROP FUNCTION IF EXISTS contract_import_eic_warning(text);

DROP TRIGGER IF EXISTS trg_viwa_package ON contract;
DROP FUNCTION IF EXISTS contract_viwa_package_sync();
DROP FUNCTION IF EXISTS contract_price_missing_refresh(uuid);
DROP FUNCTION IF EXISTS contract_price_list_sync(uuid);
DROP FUNCTION IF EXISTS contract_price_set(uuid, text, jsonb);
DROP FUNCTION IF EXISTS contract_price_canon(jsonb);
DROP FUNCTION IF EXISTS contract_price_list_rows(uuid);
DROP FUNCTION IF EXISTS contract_price_list_row(text, uuid, uuid, date, date);
DROP FUNCTION IF EXISTS contract_price_items(uuid, date, date, uuid);

-- funkcie ako pred 0026
CREATE OR REPLACE FUNCTION contract_oom_fill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c contract;
BEGIN
  SELECT * INTO c FROM contract WHERE id = NEW.contract_id;
  IF (SELECT org_id FROM oom WHERE id = NEW.oom_id) <> c.org_id THEN
    RAISE EXCEPTION 'OOM patrí inej spoločnosti ako zmluva.' USING ERRCODE = 'check_violation';
  END IF;
  NEW.org_id := c.org_id;
  NEW.grp := CASE WHEN c.type IN ('vykup', 'viwa') THEN 'vykup_viwa' ELSE 'dodavka' END;
  NEW.is_binding := c.phase = 'podpisana';
  IF TG_OP = 'INSERT' THEN
    NEW.valid_from := coalesce(NEW.valid_from, c.valid_from);
    NEW.op_valid_to := c.valid_to;
    NEW.valid_to := coalesce(NEW.valid_to, contract_effective_to(c));
  END IF;
  IF NEW.is_binding AND NEW.valid_from IS NOT NULL
     AND (TG_OP = 'INSERT' OR NOT OLD.is_binding OR NEW.valid_from < OLD.valid_from
          OR (NEW.valid_to IS NULL AND OLD.valid_to IS NOT NULL) OR NEW.valid_to > OLD.valid_to
          OR NEW.oom_id <> OLD.oom_id) THEN
    PERFORM contract_oom_succession(NEW, c);
  END IF;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION contract_price_fill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  i  record;
BEGIN
  NEW.org_id := (SELECT org_id FROM contract WHERE id = NEW.contract_id);
  IF NEW.oom_id IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM contract_oom WHERE contract_id = NEW.contract_id AND oom_id = NEW.oom_id) THEN
    RAISE EXCEPTION 'OOM ceny nie je v zmluve.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.price_list_item_id IS NOT NULL THEN
    SELECT it.*, v.status AS version_status INTO i
      FROM price_list_item it JOIN price_list_version v ON v.id = it.version_id
     WHERE it.id = NEW.price_list_item_id;
    IF i.version_status <> 'schvalena' THEN
      RAISE EXCEPTION 'Cenníková cena musí byť zo schválenej verzie cenníka.' USING ERRCODE = 'check_violation';
    END IF;
    IF i.product_id <> NEW.product_id
       OR i.price_vt_eur_mwh IS DISTINCT FROM NEW.price_vt_eur_mwh
       OR i.price_nt_eur_mwh IS DISTINCT FROM NEW.price_nt_eur_mwh
       OR coalesce(i.fee_oom_eur_month, i.fee_program_eur_month) IS DISTINCT FROM NEW.fee_eur_month
       OR i.fee_kw_eur_month IS DISTINCT FROM NEW.fee_kw_eur_month
       OR i.vat_rate IS DISTINCT FROM NEW.vat_rate THEN
      RAISE EXCEPTION 'Cenníková cena sa nezhoduje s položkou cenníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION contract_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  r contract;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system THEN
      RAISE EXCEPTION 'Zmluva sa nemaže – opravuje sa v Office portáli a ďalším importom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_system
     AND (to_jsonb(NEW) - ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'updated_at'])
         <> (to_jsonb(OLD) - ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'updated_at']) THEN
    RAISE EXCEPTION 'Údaje z Office portálu sa v CRM nemenia – opravte ich v Office portáli a nahrajte export.'
      USING ERRCODE = 'check_violation';
  END IF;
  -- súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka
  IF NEW.related_contract_id IS NOT NULL THEN
    SELECT * INTO r FROM contract WHERE id = NEW.related_contract_id;
    IF (r.company_id, r.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)
       OR NOT ((NEW.type = 'viwa' AND r.type::text LIKE 'dodavka%') OR (r.type = 'viwa' AND NEW.type::text LIKE 'dodavka%')) THEN
      RAISE EXCEPTION 'Súvisiaca zmluva: VIWA a zmluva o dodávke toho istého zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION oom_import_rows(p_org uuid, p_rows jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $_$
DECLARE
  -- polia, ktoré import smie meniť (zákazník, stav, spoločnosť a kroky prechodu nie)
  c_cols constant text[] := ARRAY[
    'type', 'name', 'address_street', 'address_number_supisne', 'address_number_orientacne', 'address_zip', 'address_city',
    'pds', 'pds_tariff', 'pds_point_id', 'voltage_level', 'metering_type', 'phases', 'breaker_a', 'reserved_capacity_kw',
    'max_reserved_capacity_kw', 'capacity_reservation_method', 'planned_consumption_vt_mwh', 'planned_consumption_nt_mwh',
    'planned_feed_in_mwh', 'supply_from', 'price_regulation', 'excise_tax', 'billing_period', 'advance_payment_method',
    'advance_payment_pct', 'advance_payment_eur', 'source_kind', 'source_category', 'source_power_kw', 'inverter_power_kw',
    'panels_power_kw', 'feed_in_contract_type'];
  c_lookups constant jsonb := '{"pds": "pds", "metering_type": "typ_merania", "billing_period": "fakturacne_obdobie",
                                "advance_payment_method": "sposob_zaloh", "feed_in_contract_type": "typ_vykupnej_zmluvy"}';
  v_country  country_code := (SELECT country FROM org WHERE id = p_org);
  v_out      jsonb := '[]';
  v_dups     jsonb;          -- EIC, ktoré sú v súbore viackrát → čísla ich riadkov (chybné sú všetky)
  r          jsonb;
  v_res      jsonb;
  v_eic      text;
  v_fields   jsonb;
  v_custom   jsonb;
  v_cust_new jsonb;
  v_company  uuid;
  v_person   uuid;
  v_n        integer;
  v_old      oom;
  v_rec      oom;
  v_key      text;
  v_val      jsonb;
  v_def      record;
  v_changes  jsonb;
  v_cons     text;
  v_msg      text;
  v_id       uuid;
  v_touched  jsonb := '{}';   -- zákazníci nových a zmenených OOM (prepočet stavu raz na konci)
  v_cust     record;
BEGIN
  PERFORM set_config('crm.oom_bulk', 'on', true);
  SELECT coalesce(jsonb_object_agg(eic, rows_), '{}') INTO v_dups
    FROM (SELECT x ->> 'eic' AS eic, jsonb_agg(x -> 'row' ORDER BY (x ->> 'row')::int) AS rows_
            FROM jsonb_array_elements(p_rows) x
           WHERE nullif(x ->> 'eic', '') IS NOT NULL
           GROUP BY 1 HAVING count(*) > 1) d;
  FOR r IN SELECT x FROM jsonb_array_elements(p_rows) x LOOP
    v_eic := nullif(r ->> 'eic', '');
    v_res := jsonb_build_object('row', r -> 'row', 'eic', v_eic);
    IF jsonb_array_length(coalesce(r -> 'parse_errors', '[]')) > 0 THEN
      v_out := v_out || (v_res || jsonb_build_object('action', 'chyba', 'error',
                 (SELECT string_agg(e, ' ') FROM jsonb_array_elements_text(r -> 'parse_errors') e)));
      CONTINUE;
    END IF;
    IF v_eic IS NULL THEN
      v_out := v_out || (v_res || '{"action": "chyba", "error": "Chýba EIC."}');
      CONTINUE;
    END IF;
    IF v_dups ? v_eic THEN
      v_out := v_out || (v_res || jsonb_build_object('action', 'chyba',
                 'error', format('EIC je v súbore viackrát (riadky %s) – nechajte ho v jednom riadku.',
                                 (SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(v_dups -> v_eic) x))));
      CONTINUE;
    END IF;

    BEGIN
      v_fields := coalesce(r -> 'fields', '{}');
      v_custom := '{}';
      v_company := NULL;
      v_person := NULL;

      -- zákazník: ID z CRM → IČO (firma) → e-mail (domácnosť), v spoločnosti importu
      IF nullif(r ->> 'customer_id', '') IS NOT NULL THEN
        SELECT id INTO v_company FROM company WHERE id::text = r ->> 'customer_id' AND org_id = p_org;
        IF v_company IS NULL THEN
          SELECT id INTO v_person FROM contact WHERE id::text = r ->> 'customer_id' AND org_id = p_org;
        END IF;
        IF v_company IS NULL AND v_person IS NULL THEN
          RAISE EXCEPTION 'Zákazník s ID % v CRM nie je (alebo k nemu nemáte prístup).', r ->> 'customer_id' USING ERRCODE = 'P0002';
        END IF;
      ELSIF nullif(r ->> 'ico', '') IS NOT NULL THEN
        SELECT id INTO v_company FROM company
         WHERE country = v_country AND org_id = p_org
           AND ico = CASE WHEN v_country = 'HR' THEN regexp_replace(r ->> 'ico', '\D', '', 'g')
                          ELSE lpad(regexp_replace(r ->> 'ico', '\D', '', 'g'), 8, '0') END;
        IF v_company IS NULL THEN
          RAISE EXCEPTION 'Firma s IČO % v CRM nie je (alebo k nej nemáte prístup).', r ->> 'ico' USING ERRCODE = 'P0002';
        END IF;
      ELSIF nullif(r ->> 'email', '') IS NOT NULL THEN
        SELECT count(*), min(id::text)::uuid INTO v_n, v_person FROM contact
         WHERE org_id = p_org AND lower(btrim(email)) = lower(btrim(r ->> 'email'));
        IF v_n = 0 THEN
          RAISE EXCEPTION 'Osoba s e-mailom % v CRM nie je (alebo k nej nemáte prístup).', r ->> 'email' USING ERRCODE = 'P0002';
        ELSIF v_n > 1 THEN
          RAISE EXCEPTION 'E-mail % má v CRM viac osôb – použite stĺpec ID zákazníka.', r ->> 'email' USING ERRCODE = 'P0002';
        END IF;
      END IF;

      SELECT * INTO v_old FROM oom WHERE eic = v_eic;
      IF NOT FOUND AND EXISTS (SELECT 1 FROM oom_eic_check(v_eic)) THEN
        RAISE EXCEPTION 'Odberné miesto s týmto EIC už v CRM je, ale nemáte k nemu prístup (vlastník %).',
          (SELECT owner_name FROM oom_eic_check(v_eic) LIMIT 1) USING ERRCODE = 'insufficient_privilege';
      END IF;
      IF v_old.id IS NOT NULL AND v_old.org_id <> p_org THEN
        RAISE EXCEPTION 'Odberné miesto patrí inej spoločnosti skupiny.' USING ERRCODE = 'check_violation';
      END IF;

      -- číselníky: názov → kód; sadzba podľa PDS (z riadku alebo existujúceho OOM)
      FOR v_key IN SELECT jsonb_object_keys(c_lookups) LOOP
        IF nullif(v_fields ->> v_key, '') IS NOT NULL THEN
          v_fields := v_fields || jsonb_build_object(v_key, oom_import_lookup(c_lookups ->> v_key, p_org, v_fields ->> v_key));
        END IF;
      END LOOP;
      IF nullif(v_fields ->> 'pds_tariff', '') IS NOT NULL THEN
        IF coalesce(v_fields ->> 'pds', v_old.pds) IS NULL THEN
          RAISE EXCEPTION 'Sadzba bez PDS: vyplňte aj PDS.' USING ERRCODE = 'check_violation';
        END IF;
        v_fields := v_fields || jsonb_build_object('pds_tariff',
          oom_import_lookup('sadzba_distribucie', p_org, v_fields ->> 'pds_tariff', coalesce(v_fields ->> 'pds', v_old.pds)));
      END IF;

      -- vlastné polia: text → hodnota podľa typu poľa
      FOR v_key, v_val IN SELECT * FROM jsonb_each(coalesce(r -> 'custom', '{}')) LOOP
        CONTINUE WHEN v_val IS NULL OR v_val = 'null'::jsonb OR btrim(v_val #>> '{}') = '';
        SELECT f.id, f.label, f.field_type INTO v_def FROM custom_field f
         WHERE f.entity = 'oom' AND f.key = v_key AND f.archived_at IS NULL AND (f.org_id IS NULL OR f.org_id = p_org);
        IF NOT FOUND THEN
          RAISE EXCEPTION 'Neznáme vlastné pole „%“.', v_key USING ERRCODE = 'check_violation';
        END IF;
        v_custom := v_custom || jsonb_build_object(v_key, CASE v_def.field_type
          WHEN 'ano_nie' THEN CASE WHEN lower(btrim(v_val #>> '{}')) IN ('áno', 'ano', 'a', 'true', '1', 'yes') THEN 'true'::jsonb
                                   WHEN lower(btrim(v_val #>> '{}')) IN ('nie', 'n', 'false', '0', 'no') THEN 'false'::jsonb END
          WHEN 'cislo' THEN to_jsonb(replace(replace(v_val #>> '{}', ' ', ''), ',', '.')::numeric)
          WHEN 'suma' THEN to_jsonb(replace(replace(v_val #>> '{}', ' ', ''), ',', '.')::numeric)
          WHEN 'vyber' THEN (SELECT to_jsonb(o.id) FROM custom_field_option o
                              WHERE o.field_id = v_def.id AND o.hidden_at IS NULL AND lower(btrim(o.label)) = lower(btrim(v_val #>> '{}')))
          -- dátum: číslo z Excelu (dni od 30. 12. 1899), RRRR-MM-DD alebo D. M. RRRR
          WHEN 'datum' THEN to_jsonb(to_char(CASE
            WHEN jsonb_typeof(v_val) = 'number' THEN date '1899-12-30' + floor((v_val #>> '{}')::numeric)::int
            WHEN v_val #>> '{}' ~ '^\d{4}-\d{2}-\d{2}$' THEN (v_val #>> '{}')::date
            ELSE to_date(regexp_replace(v_val #>> '{}', '\s', '', 'g'), 'DD.MM.YYYY') END, 'YYYY-MM-DD'))
          WHEN 'text' THEN to_jsonb(btrim(v_val #>> '{}'))
          WHEN 'dlhy_text' THEN to_jsonb(btrim(v_val #>> '{}'))
        END);
        IF v_custom -> v_key IS NULL OR v_custom -> v_key = 'null'::jsonb THEN
          RAISE EXCEPTION 'Vlastné pole „%“: hodnota „%“ sa nedá použiť%.', v_def.label, v_val #>> '{}',
            CASE WHEN v_def.field_type IN ('vyber_viac', 'odkaz') THEN ' (tento typ poľa import nepodporuje)' ELSE '' END
            USING ERRCODE = 'check_violation';
        END IF;
      END LOOP;

      IF v_old.id IS NULL THEN
        -- nové OOM: zákazník a typ povinné, stav vždy Pripravované
        IF v_company IS NULL AND v_person IS NULL THEN
          RAISE EXCEPTION 'Nové odberné miesto: chýba zákazník (ID zákazníka, IČO alebo e-mail).' USING ERRCODE = 'check_violation';
        END IF;
        IF nullif(v_fields ->> 'type', '') IS NULL THEN
          RAISE EXCEPTION 'Nové odberné miesto: chýba typ (spotreba, výroba, sharing).' USING ERRCODE = 'check_violation';
        END IF;
        v_rec := jsonb_populate_record(NULL::oom, v_fields);
        INSERT INTO oom (company_id, person_id, eic, status, switch_notice_required, custom,
                         type, name, address_street, address_number_supisne, address_number_orientacne, address_zip, address_city,
                         pds, pds_tariff, pds_point_id, voltage_level, metering_type, phases, breaker_a, reserved_capacity_kw,
                         max_reserved_capacity_kw, capacity_reservation_method, planned_consumption_vt_mwh, planned_consumption_nt_mwh,
                         planned_feed_in_mwh, supply_from, price_regulation, excise_tax, billing_period, advance_payment_method,
                         advance_payment_pct, advance_payment_eur, source_kind, source_category, source_power_kw, inverter_power_kw,
                         panels_power_kw, feed_in_contract_type)
        VALUES (v_company, v_person, v_eic, 'pripravovane', true, v_custom,
                v_rec.type, v_rec.name, v_rec.address_street, v_rec.address_number_supisne, v_rec.address_number_orientacne,
                v_rec.address_zip, v_rec.address_city, v_rec.pds, v_rec.pds_tariff, v_rec.pds_point_id, v_rec.voltage_level,
                v_rec.metering_type, v_rec.phases, v_rec.breaker_a, v_rec.reserved_capacity_kw, v_rec.max_reserved_capacity_kw,
                v_rec.capacity_reservation_method, v_rec.planned_consumption_vt_mwh, v_rec.planned_consumption_nt_mwh,
                v_rec.planned_feed_in_mwh, v_rec.supply_from, v_rec.price_regulation, v_rec.excise_tax, v_rec.billing_period,
                v_rec.advance_payment_method, v_rec.advance_payment_pct, v_rec.advance_payment_eur, v_rec.source_kind,
                v_rec.source_category, v_rec.source_power_kw, v_rec.inverter_power_kw, v_rec.panels_power_kw,
                v_rec.feed_in_contract_type)
        RETURNING id INTO v_id;
        v_touched := v_touched || jsonb_build_object(coalesce(v_company, v_person)::text, jsonb_build_array(v_company, v_person));
        v_res := v_res || jsonb_build_object('action', 'nove', 'oom_id', v_id,
                   'customer', (SELECT customer_name FROM oom_v WHERE id = v_id));
      ELSE
        -- zmena: zákazník (ak je v riadku) sa musí zhodovať; prázdne bunky sa nemenia
        IF (v_company IS NOT NULL OR v_person IS NOT NULL)
           AND (v_company, v_person) IS DISTINCT FROM (v_old.company_id, v_old.person_id) THEN
          RAISE EXCEPTION 'Zákazník v riadku sa nezhoduje s aktuálnym zákazníkom OOM – prepis urobte na karte OOM.'
            USING ERRCODE = 'check_violation';
        END IF;
        v_rec := jsonb_populate_record(v_old, v_fields);
        -- zmeny: iba stĺpce importu, ktorých hodnota sa líši (popisy číselníkov namiesto kódov)
        SELECT coalesce(jsonb_agg(jsonb_build_object('field', k,
                 'old', CASE WHEN c_lookups ? k THEN (SELECT label FROM lookup_value WHERE list_code = c_lookups ->> k AND code = o ->> k)
                             WHEN k = 'pds_tariff' THEN (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = o ->> k)
                             ELSE o ->> k END,
                 'new', CASE WHEN c_lookups ? k THEN (SELECT label FROM lookup_value WHERE list_code = c_lookups ->> k AND code = n ->> k)
                             WHEN k = 'pds_tariff' THEN (SELECT label FROM lookup_value WHERE list_code = 'sadzba_distribucie' AND code = n ->> k)
                             ELSE n ->> k END)), '[]')
          INTO v_changes
          FROM unnest(c_cols) k, LATERAL (SELECT to_jsonb(v_old) o, to_jsonb(v_rec) n) x
         WHERE (o -> k) IS DISTINCT FROM (n -> k);
        SELECT v_changes || coalesce(jsonb_agg(jsonb_build_object('field', 'custom.' || ks.key, 'old', v_old.custom ->> ks.key, 'new', ks.value #>> '{}')), '[]')
          INTO v_changes
          FROM jsonb_each(v_custom) ks
         WHERE v_old.custom -> ks.key IS DISTINCT FROM ks.value;
        IF jsonb_array_length(v_changes) = 0 THEN
          v_res := v_res || jsonb_build_object('action', 'bez_zmeny', 'oom_id', v_old.id,
                     'customer', (SELECT customer_name FROM oom_v WHERE id = v_old.id));
        ELSE
          UPDATE oom SET
            type = v_rec.type, name = v_rec.name, address_street = v_rec.address_street,
            address_number_supisne = v_rec.address_number_supisne, address_number_orientacne = v_rec.address_number_orientacne,
            address_zip = v_rec.address_zip, address_city = v_rec.address_city, pds = v_rec.pds, pds_tariff = v_rec.pds_tariff,
            pds_point_id = v_rec.pds_point_id, voltage_level = v_rec.voltage_level, metering_type = v_rec.metering_type,
            phases = v_rec.phases, breaker_a = v_rec.breaker_a, reserved_capacity_kw = v_rec.reserved_capacity_kw,
            max_reserved_capacity_kw = v_rec.max_reserved_capacity_kw, capacity_reservation_method = v_rec.capacity_reservation_method,
            planned_consumption_vt_mwh = v_rec.planned_consumption_vt_mwh, planned_consumption_nt_mwh = v_rec.planned_consumption_nt_mwh,
            planned_feed_in_mwh = v_rec.planned_feed_in_mwh, supply_from = v_rec.supply_from,
            price_regulation = v_rec.price_regulation, excise_tax = v_rec.excise_tax, billing_period = v_rec.billing_period,
            advance_payment_method = v_rec.advance_payment_method, advance_payment_pct = v_rec.advance_payment_pct,
            advance_payment_eur = v_rec.advance_payment_eur, source_kind = v_rec.source_kind, source_category = v_rec.source_category,
            source_power_kw = v_rec.source_power_kw, inverter_power_kw = v_rec.inverter_power_kw, panels_power_kw = v_rec.panels_power_kw,
            feed_in_contract_type = v_rec.feed_in_contract_type,
            custom = custom || v_custom
           WHERE id = v_old.id;
          IF NOT FOUND THEN
            RAISE EXCEPTION 'Toto odberné miesto nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
          END IF;
          v_touched := v_touched || jsonb_build_object(coalesce(v_old.company_id, v_old.person_id)::text,
                                                       jsonb_build_array(v_old.company_id, v_old.person_id));
          v_res := v_res || jsonb_build_object('action', 'zmena', 'oom_id', v_old.id, 'changes', v_changes,
                     'customer', (SELECT customer_name FROM oom_v WHERE id = v_old.id));
        END IF;
      END IF;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_cons = CONSTRAINT_NAME, v_msg = MESSAGE_TEXT;
      v_res := v_res || jsonb_build_object('action', 'chyba', 'error', CASE coalesce(v_cons, '')
        WHEN 'oom_eic_check' THEN 'Neplatný formát alebo kontrolná číslica EIC.'
        WHEN 'oom_eic_key' THEN 'Odberné miesto s týmto EIC už v CRM je.'
        WHEN 'oom_phases_check' THEN 'Počet fáz: 1 alebo 3.'
        WHEN 'oom_advance_pct_check' THEN 'Záloha v percentách: 0 až 100.'
        WHEN 'oom_supply_period_check' THEN 'Dodávka do nemôže byť pred dodávkou od.'
        ELSE CASE WHEN SQLSTATE IN ('22P02', '22007', '22008', '22003') THEN 'Neplatná hodnota v riadku (číslo alebo dátum).'
                  ELSE v_msg END END);
    END;
    v_out := v_out || v_res;
  END LOOP;
  PERFORM set_config('crm.oom_bulk', '', true);
  IF crm_setting_on('customer_status_auto') THEN
    FOR v_cust IN SELECT (value ->> 0)::uuid AS company_id, (value ->> 1)::uuid AS person_id FROM jsonb_each(v_touched) LOOP
      PERFORM customer_refresh(v_cust.company_id, v_cust.person_id);
    END LOOP;
  END IF;
  RETURN v_out;
END;
$_$;
CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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

ALTER TABLE contract DROP CONSTRAINT IF EXISTS contract_viwa_package_type_check;
DROP INDEX IF EXISTS contract_oom_program_idx;
ALTER TABLE contract_oom DROP COLUMN IF EXISTS program_id;
COMMENT ON COLUMN contract_oom.product_id IS NULL;
ALTER TABLE oom DROP COLUMN IF EXISTS tdo_class;

DROP TRIGGER IF EXISTS trg_import_flag ON company;
DROP TRIGGER IF EXISTS trg_import_flag ON contact;
DROP FUNCTION IF EXISTS customer_import_flag_clear();
-- pôvodná kontrola dosiahnuteľnosti; osoby založené importom bez e-mailu a telefónu ju nesplnia – vtedy ostane NOT VALID
-- (platí pre nové a menené osoby, existujúce ostanú) a návrat neskončí chybou
ALTER TABLE contact DROP CONSTRAINT contact_reachable_check;
ALTER TABLE contact ADD CONSTRAINT contact_reachable_check CHECK (
  num_nonnulls(NULLIF(btrim(email), ''::text), NULLIF(btrim(phone), ''::text), NULLIF(btrim(mobile), ''::text)) >= 1) NOT VALID;
DO $$
BEGIN
  ALTER TABLE contact VALIDATE CONSTRAINT contact_reachable_check;
EXCEPTION WHEN check_violation THEN
  RAISE NOTICE 'Osoby založené importom bez e-mailu a telefónu ostali – kontrola contact_reachable_check je NOT VALID.';
END;
$$;
DROP INDEX IF EXISTS company_op_person_key;
DROP INDEX IF EXISTS contact_op_person_key;
ALTER TABLE company DROP COLUMN IF EXISTS op_person_id, DROP COLUMN IF EXISTS created_by_import;
ALTER TABLE contact DROP COLUMN IF EXISTS op_person_id, DROP COLUMN IF EXISTS created_by_import;

DROP INDEX IF EXISTS audit_log_contract_import_id_idx;
ALTER TABLE audit_log DROP COLUMN IF EXISTS contract_import_id;
ALTER TABLE contract DROP COLUMN IF EXISTS last_import_id;
DROP TABLE IF EXISTS contract_import_change;
DROP TABLE IF EXISTS contract_import;
