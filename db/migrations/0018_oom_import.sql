-- 0018_oom_import.sql – import OOM z Excelu v databáze (zadanie OOM čl. 9, 15, F4; Peter 13. 10. 2026)
--
-- API súbor prečíta (SheetJS) a pošle všetky riadky naraz ako JSON; kontrolu aj uloženie robí databáza
-- jednou funkciou (žiadne riadky po jednom cez sieť):
--   oom_import_run(org, riadky, uložiť?, názov súboru, očakávané počty) → { rows, counts } alebo { import_id, counts }
-- Náhľad: každý riadok sa skúsi uložiť (s právami prihláseného, RLS, kontrolami) a všetko sa vráti späť.
-- Uloženie: jeden prechod so záznamom importu a app.import_id (audit „import“); ak počty nesedia s náhľadom,
-- ktorý videl používateľ (niekto medzitým zmenil dáta), všetko sa vráti späť a nič sa neuloží.
-- Výkon: stav zákazníka sa počas importu neprepočítava pri každom riadku (crm.oom_bulk), ale raz na konci
-- pre každého dotknutého zákazníka (pri 2 000 riadkoch inak desiatky sekúnd).
-- Pravidlá (Peter 13. 10.): prázdna bunka pri zmene = bez zmeny; zákazník ID → IČO → e-mail; pri existujúcom OOM
-- sa zákazník musí zhodovať; číselníky názvom bez ohľadu na veľkosť písmen, skrytá hodnota = chyba, pomlčky
-- v sadzbách zjednotené; stav OOM sa importom nemení (nové = Pripravované), kroky prechodu nie; najviac 5 000 riadkov.

-- migrate:up

-- Spúšťače prepočtu stavu zákazníka (0014) počas hromadného importu nič nerobia (crm.oom_bulk = on);
-- import potom prepočíta každého dotknutého zákazníka raz.
CREATE OR REPLACE FUNCTION oom_customer_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_setting_on('customer_status_auto') OR coalesce(current_setting('crm.oom_bulk', true), '') = 'on' THEN
    RETURN NULL;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    PERFORM customer_refresh(NEW.company_id, NEW.person_id);
  END IF;
  IF TG_OP <> 'INSERT' AND (TG_OP = 'DELETE' OR (OLD.company_id, OLD.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)) THEN
    PERFORM customer_refresh(OLD.company_id, OLD.person_id);
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION oom_type_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_link record;
BEGIN
  IF crm_setting_on('customer_status_auto') AND coalesce(current_setting('crm.oom_bulk', true), '') <> 'on' THEN
    FOR v_link IN SELECT DISTINCT company_id, person_id FROM oom_customer WHERE oom_id = NEW.id LOOP
      PERFORM customer_refresh(v_link.company_id, v_link.person_id);
    END LOOP;
  END IF;
  RETURN NULL;
END;
$$;

-- Číselníková hodnota podľa názvu (bez ohľadu na veľkosť písmen, dlhá pomlčka = „-“) pre spoločnosť;
-- pri sadzbe aj podľa PDS. Vráti kód; chyba pri neznámej alebo skrytej hodnote.
CREATE FUNCTION oom_import_lookup(p_list text, p_org uuid, p_label text, p_parent text DEFAULT NULL) RETURNS text
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v lookup_value;
BEGIN
  SELECT * INTO v FROM lookup_value
   WHERE list_code = p_list AND (org_id IS NULL OR org_id = p_org)
     AND (p_parent IS NULL OR parent_code = p_parent)
     AND lower(translate(btrim(label), '–—', '--')) = lower(translate(btrim(p_label), '–—', '--'))
   ORDER BY hidden_at NULLS FIRST
   LIMIT 1;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Neznáma hodnota „%“ (%).', p_label,
      CASE p_list WHEN 'pds' THEN 'PDS' WHEN 'sadzba_distribucie' THEN 'sadzba – pre zvolené PDS'
                  WHEN 'typ_merania' THEN 'typ merania' WHEN 'fakturacne_obdobie' THEN 'fakturačné obdobie'
                  WHEN 'sposob_zaloh' THEN 'zálohy' WHEN 'typ_vykupnej_zmluvy' THEN 'typ výkupnej zmluvy' ELSE p_list END
      USING ERRCODE = 'check_violation';
  END IF;
  IF v.hidden_at IS NOT NULL THEN
    RAISE EXCEPTION 'Hodnota „%“ je v číselníku skrytá, nedá sa vybrať.', v.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN v.code;
END;
$$;

-- Riadky importu (jeden prechod). Každý riadok v samostatnej subtransakcii: chybný riadok sa vráti späť,
-- ostatné pokračujú. Vráti pole výsledkov { row, eic, action: nove|zmena|bez_zmeny|chyba, error, changes, customer }.
-- Vstupný riadok: { row, eic, customer_id, ico, email, fields: {stĺpec: hodnota}, custom: {kľúč: text}, parse_errors: [] }
-- (hodnoty číselníkov sú názvy; enumy, čísla a dátumy už previedlo API).
CREATE FUNCTION oom_import_rows(p_org uuid, p_rows jsonb) RETURNS jsonb
LANGUAGE plpgsql AS $$
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
$$;

CREATE FUNCTION oom_import_counts(p_rows jsonb) RETURNS jsonb
LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object(
           'riadkov', count(*),
           'nove', count(*) FILTER (WHERE x ->> 'action' = 'nove'),
           'zmena', count(*) FILTER (WHERE x ->> 'action' = 'zmena'),
           'bez_zmeny', count(*) FILTER (WHERE x ->> 'action' = 'bez_zmeny'),
           'chyba', count(*) FILTER (WHERE x ->> 'action' = 'chyba'))
    FROM jsonb_array_elements(p_rows) x
$$;

-- Import: náhľad (p_save = false) alebo uloženie (p_save = true, s počtami z náhľadu).
-- Príklad: SELECT oom_import_run(org, '[{"row": 2, "eic": "24…", "ico": "36361518", "fields": {"type": "spotreba"}}]', false);
CREATE FUNCTION oom_import_run(p_org uuid, p_rows jsonb, p_save boolean, p_file_name text DEFAULT NULL,
                               p_expected jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  v_rows   jsonb;
  v_counts jsonb;
  v_id     uuid;
  v_prev   text;
BEGIN
  IF NOT crm_can_import('odberne_miesta') THEN
    RAISE EXCEPTION 'Import odberných miest nemáte povolený (Nastavenia → Tímy a práva).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT p_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'K tejto spoločnosti nemáte prístup.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_typeof(p_rows) <> 'array' OR jsonb_array_length(p_rows) > 5000 THEN
    RAISE EXCEPTION 'Súbor má viac ako 5 000 riadkov – rozdeľte ho.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT p_save THEN
    -- náhľad: všetko sa skúsi a vráti späť (premenná v_rows ostáva)
    BEGIN
      v_rows := oom_import_rows(p_org, p_rows);
      RAISE EXCEPTION 'náhľad' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
    END;
    RETURN jsonb_build_object('rows', v_rows, 'counts', oom_import_counts(v_rows));
  END IF;

  -- uloženie: počty musia sedieť s náhľadom, ktorý videl používateľ; inak sa všetko vráti späť
  IF p_expected IS NULL OR (p_expected ->> 'nove')::int + (p_expected ->> 'zmena')::int = 0 THEN
    RETURN jsonb_build_object('mismatch', p_expected IS NULL, 'import_id', NULL, 'counts', p_expected);
  END IF;
  BEGIN
    INSERT INTO oom_import (org_id, user_id, file_name, row_count, created_count, updated_count, error_count, status)
    VALUES (p_org, crm_active_user_id(), coalesce(nullif(btrim(p_file_name), ''), 'import.xlsx'), (p_expected ->> 'riadkov')::int,
            (p_expected ->> 'nove')::int, (p_expected ->> 'zmena')::int, (p_expected ->> 'chyba')::int, 'ulozeny')
    RETURNING id INTO v_id;
    v_prev := current_setting('app.import_id', true);
    PERFORM set_config('app.import_id', v_id::text, true);
    v_rows := oom_import_rows(p_org, p_rows);
    PERFORM set_config('app.import_id', coalesce(v_prev, ''), true);
    v_counts := oom_import_counts(v_rows);
    IF v_counts IS DISTINCT FROM p_expected THEN
      RAISE EXCEPTION 'nesedí s náhľadom' USING ERRCODE = 'P0098';
    END IF;
  EXCEPTION WHEN SQLSTATE 'P0098' THEN
    PERFORM set_config('app.import_id', coalesce(v_prev, ''), true);
    RETURN jsonb_build_object('mismatch', true, 'counts', v_counts);
  END;
  RETURN jsonb_build_object('import_id', v_id, 'counts', v_counts);
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS oom_import_run(uuid, jsonb, boolean, text, jsonb);
DROP FUNCTION IF EXISTS oom_import_rows(uuid, jsonb);
DROP FUNCTION IF EXISTS oom_import_counts(jsonb);
DROP FUNCTION IF EXISTS oom_import_lookup(text, uuid, text, text);

-- spúšťače prepočtu ako v 0014 (bez prepínača hromadnej zmeny)
CREATE OR REPLACE FUNCTION oom_customer_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_setting_on('customer_status_auto') THEN
    RETURN NULL;
  END IF;
  IF TG_OP <> 'DELETE' THEN
    PERFORM customer_refresh(NEW.company_id, NEW.person_id);
  END IF;
  IF TG_OP <> 'INSERT' AND (TG_OP = 'DELETE' OR (OLD.company_id, OLD.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id)) THEN
    PERFORM customer_refresh(OLD.company_id, OLD.person_id);
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION oom_type_refresh() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_link record;
BEGIN
  IF crm_setting_on('customer_status_auto') THEN
    FOR v_link IN SELECT DISTINCT company_id, person_id FROM oom_customer WHERE oom_id = NEW.id LOOP
      PERFORM customer_refresh(v_link.company_id, v_link.person_id);
    END LOOP;
  END IF;
  RETURN NULL;
END;
$$;
