-- 0007_nastavenia_obsah.sql – Modul 0 Nastavenia, časť 2 (docs/moduly/00-nastavenia-navrh-db.md v0.1)
--
-- Číselníky: zoznamy zakladá migrácia, hodnoty pridáva admin; hodnota sa nikdy nemaže, iba skryje.
--   Systémové hodnoty (is_system) sa nedajú skryť ani premenovať. Záznamy odkazujú na hodnotu
--   jej kódom (code), ktorý sa nikdy nemení.
-- Vlastné polia: definícia (custom_field, sekcie, hodnoty výberu, tímy) a hodnoty v stĺpci
--   custom jsonb na firme, osobe, OOM, deale, zmluve a ponuke (kľúč = custom_field.key).
--   Spúšťač custom_values_check kontroluje kľúč, typ, hodnotu výberu, odkaz (existuje a patrí
--   tej istej spoločnosti), archiváciu a tím, ktorý smie pole meniť. „Povinné“ kontroluje API.
-- Pipelines a stage: spoločnosť, druh obchodu (jadro), archivácia; stage má výsledok
--   otvorený / vyhraný / prehraný (is_closed a is_won sú z neho vypočítané), povinné polia pri prechode.
-- Nastavenia mení iba admin (RLS).

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pipeline) OR EXISTS (SELECT 1 FROM deal) THEN
    RAISE EXCEPTION 'Migrácia 0007 vyžaduje prázdne pipelines a dealy (najprv ./db/empty-test.sh).';
  END IF;
END;
$$;

-- ============================================================================
-- Pomocné
-- ============================================================================

-- Kód z názvu: 'Má tepelné čerpadlo' → 'ma_tepelne_cerpadlo'
CREATE FUNCTION crm_slug(p text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT nullif(btrim(regexp_replace(lower(translate(p,
           'áäčďéěíĺľňóôöŕřšťúůüýžÁÄČĎÉĚÍĹĽŇÓÔÖŔŘŠŤÚŮÜÝŽ',
           'aacdeeillnooorrstuuuyzAACDEEILLNOOORRSTUUUYZ')), '[^a-z0-9]+', '_', 'g'), '_'), '')
$$;

CREATE TYPE crm_entity AS ENUM ('firma', 'osoba', 'oom', 'deal', 'zmluva', 'ponuka');

-- Tabuľka záznamov entity
CREATE FUNCTION crm_entity_table(p crm_entity) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p WHEN 'firma' THEN 'company' WHEN 'osoba' THEN 'contact' WHEN 'oom' THEN 'oom'
                WHEN 'deal' THEN 'deal' WHEN 'zmluva' THEN 'contract' WHEN 'ponuka' THEN 'offer' END
$$;

-- ============================================================================
-- Číselníky
-- ============================================================================

CREATE TABLE lookup_list (
  code        text PRIMARY KEY CHECK (code ~ '^[a-z][a-z0-9_]{1,62}$'),
  name        text NOT NULL,
  used_on     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE lookup_list IS 'zoznamy číselníkov; zakladá ich iba migrácia (jadro)';

CREATE TABLE lookup_value (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  list_code      text NOT NULL REFERENCES lookup_list (code),
  code           text NOT NULL CHECK (code ~ '^[a-z0-9][a-z0-9_]{0,62}$'),
  label          text NOT NULL CHECK (btrim(label) <> ''),
  org_id         uuid REFERENCES org (id),
  sort_order     integer NOT NULL DEFAULT 0,
  is_system      boolean NOT NULL DEFAULT false,
  hidden_at      timestamptz,
  hubspot_value  text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (list_code, code),
  CONSTRAINT lookup_value_system_visible_check CHECK (NOT (is_system AND hidden_at IS NOT NULL))
);
CREATE UNIQUE INDEX lookup_value_label_key ON lookup_value (list_code, org_id, lower(label)) NULLS NOT DISTINCT;
COMMENT ON COLUMN lookup_value.code IS 'kľúč, ktorým odkazujú záznamy; vznikne z názvu, nikdy sa nemení';
COMMENT ON COLUMN lookup_value.org_id IS 'NULL = celá skupina';
COMMENT ON COLUMN lookup_value.is_system IS 'hodnota, na ktorej stojí logika: nedá sa skryť ani premenovať (zakladá iba migrácia)';
COMMENT ON COLUMN lookup_value.hidden_at IS 'skrytá hodnota sa nedá vybrať pri novom zadaní, staré záznamy ju zobrazujú ďalej';

-- Kód z názvu, nemenný kód a zoznam, zamknuté systémové hodnoty, žiadne mazanie.
CREATE FUNCTION lookup_value_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Hodnota číselníka sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.code := coalesce(NEW.code, crm_slug(NEW.label));
    RETURN NEW;
  END IF;
  IF NEW.code <> OLD.code OR NEW.list_code <> OLD.list_code OR NEW.is_system <> OLD.is_system THEN
    RAISE EXCEPTION 'Kód, zoznam a systémový príznak hodnoty číselníka sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.is_system AND (NEW.label <> OLD.label OR NEW.hidden_at IS NOT NULL
                        OR NEW.org_id IS DISTINCT FROM OLD.org_id) THEN
    RAISE EXCEPTION 'Systémová hodnota „%“ sa nedá premenovať ani skryť.', OLD.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON lookup_value
  FOR EACH ROW EXECUTE FUNCTION lookup_value_guard();

-- Kontrola kódov zo stĺpca záznamu: každý kód existuje v zozname (pre celú skupinu alebo
-- spoločnosť záznamu); novo pridaný kód nesmie byť skrytý. Používajú ju spúšťače modulov.
-- Príklad: PERFORM lookup_codes_check('rola_kontaktu', org_id, NEW.roles, OLD.roles).
CREATE FUNCTION lookup_codes_check(p_list text, p_org_id uuid, p_new text[], p_old text[] DEFAULT '{}')
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_code  text;
  v_val   lookup_value;
BEGIN
  FOREACH v_code IN ARRAY coalesce(p_new, '{}') LOOP
    SELECT * INTO v_val FROM lookup_value
     WHERE list_code = p_list AND code = v_code AND (org_id IS NULL OR org_id = p_org_id);
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Hodnota „%“ nie je v číselníku %.', v_code, p_list USING ERRCODE = 'foreign_key_violation';
    END IF;
    IF v_val.hidden_at IS NOT NULL AND NOT v_code = ANY (coalesce(p_old, '{}')) THEN
      RAISE EXCEPTION 'Hodnota „%“ je skrytá, nedá sa vybrať.', v_val.label USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;
END;
$$;

-- ============================================================================
-- Vlastné polia: definícia
-- ============================================================================

CREATE TYPE custom_field_type AS ENUM (
  'text', 'dlhy_text', 'cislo', 'suma', 'datum', 'vyber', 'vyber_viac', 'ano_nie', 'odkaz'
);
CREATE TYPE field_edit_access AS ENUM ('vsetky_timy', 'vybrane_timy', 'iba_admin');

CREATE TABLE custom_field_section (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity      crm_entity NOT NULL,
  name        text NOT NULL CHECK (btrim(name) <> ''),
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entity, name)
);

CREATE TABLE custom_field (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity        crm_entity NOT NULL,
  key           text NOT NULL CHECK (key ~ '^[a-z][a-z0-9_]{1,62}$'),
  label         text NOT NULL CHECK (btrim(label) <> ''),
  field_type    custom_field_type NOT NULL,
  ref_entity    crm_entity,
  section_id    uuid REFERENCES custom_field_section (id),
  sort_order    integer NOT NULL DEFAULT 0,
  is_required   boolean NOT NULL DEFAULT false,
  show_in_list  boolean NOT NULL DEFAULT false,
  filterable    boolean NOT NULL DEFAULT false,
  edit_access   field_edit_access NOT NULL DEFAULT 'vsetky_timy',
  org_id        uuid REFERENCES org (id),
  archived_at   timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (entity, key),
  CONSTRAINT custom_field_ref_check CHECK ((field_type = 'odkaz') = (ref_entity IS NOT NULL))
);
COMMENT ON COLUMN custom_field.key IS 'kľúč v stĺpci custom; vznikne z názvu, nikdy sa nemení';
COMMENT ON COLUMN custom_field.field_type IS 'po prvej uloženej hodnote sa nemení';
COMMENT ON COLUMN custom_field.is_required IS 'kontroluje API pri uložení formulára (nie databáza – staršie záznamy pole nemajú)';
COMMENT ON COLUMN custom_field.org_id IS 'NULL = celá skupina';
COMMENT ON COLUMN custom_field.archived_at IS 'archivované pole: údaje ostávajú, nedajú sa meniť, pole sa dá obnoviť';

CREATE TABLE custom_field_team (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id    uuid NOT NULL REFERENCES custom_field (id) ON DELETE CASCADE,
  team_id     uuid NOT NULL REFERENCES team (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (field_id, team_id)
);
COMMENT ON TABLE custom_field_team IS 'tímy, ktoré smú pole meniť (pri edit_access = vybrane_timy)';

CREATE TABLE custom_field_option (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id    uuid NOT NULL REFERENCES custom_field (id),
  label       text NOT NULL CHECK (btrim(label) <> ''),
  sort_order  integer NOT NULL DEFAULT 0,
  hidden_at   timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (field_id, label)
);
COMMENT ON TABLE custom_field_option IS 'hodnoty výberu; v custom sa ukladá id (premenovanie nič nerozbije); nemaže sa, iba skryje';

-- Pole: kľúč a entita sa nemenia; typ a cieľ odkazu iba kým pole nemá hodnoty; nemaže sa (archivuje).
CREATE FUNCTION custom_field_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_used boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Vlastné pole sa nemaže, iba archivuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.key := coalesce(NEW.key, crm_slug(NEW.label));
    RETURN NEW;
  END IF;
  IF NEW.key <> OLD.key OR NEW.entity <> OLD.entity THEN
    RAISE EXCEPTION 'Kľúč a záznam vlastného poľa sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.field_type <> OLD.field_type OR NEW.ref_entity IS DISTINCT FROM OLD.ref_entity THEN
    EXECUTE format('SELECT EXISTS (SELECT 1 FROM %I WHERE custom ? $1)', crm_entity_table(OLD.entity))
      INTO v_used USING OLD.key;
    IF v_used THEN
      RAISE EXCEPTION 'Typ poľa „%“ sa nedá zmeniť, pole už má uložené hodnoty.', OLD.label
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON custom_field
  FOR EACH ROW EXECUTE FUNCTION custom_field_guard();

CREATE FUNCTION custom_field_option_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Hodnota výberu sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
END;
$$;
CREATE TRIGGER trg_guard BEFORE DELETE ON custom_field_option
  FOR EACH ROW EXECUTE FUNCTION custom_field_option_guard();

-- Smie prihlásený meniť hodnotu poľa (návrh 1.7)
CREATE FUNCTION crm_can_edit_field(p_field custom_field) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service()
      OR (crm_active_user_id() IS NOT NULL AND CASE p_field.edit_access
            WHEN 'vsetky_timy' THEN true
            WHEN 'iba_admin'   THEN crm_is_admin()
            ELSE EXISTS (SELECT 1 FROM custom_field_team ft JOIN app_user u ON u.team_id = ft.team_id
                          WHERE ft.field_id = p_field.id AND u.id = crm_active_user_id())
          END)
$$;

-- ============================================================================
-- Vlastné polia: hodnoty (stĺpec custom) a ich kontrola
-- ============================================================================

-- Spúšťač BEFORE INSERT OR UPDATE; TG_ARGV[0] = entita (firma, osoba, oom, deal, zmluva, ponuka).
-- Kontroluje iba zmenené kľúče: nezmenená hodnota archivovaného poľa alebo skrytej možnosti ostáva.
-- Spoločnosť záznamu berie zo stĺpca org_id (od 0008); bez neho sa spoločnosť nekontroluje.
CREATE FUNCTION custom_values_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_entity   crm_entity := TG_ARGV[0]::crm_entity;
  v_new      jsonb := coalesce(NEW.custom, '{}');
  v_old      jsonb := CASE WHEN TG_OP = 'UPDATE' THEN coalesce(OLD.custom, '{}') ELSE '{}' END;
  v_org      uuid := (to_jsonb(NEW) ->> 'org_id')::uuid;
  v_org_old  uuid := CASE WHEN TG_OP = 'UPDATE' THEN (to_jsonb(OLD) ->> 'org_id')::uuid END;
  v_key      text;
  v_val      jsonb;
  v_f        custom_field;
  v_item     jsonb;
  v_ref_org  text;
  v_found    boolean;
BEGIN
  IF jsonb_typeof(v_new) <> 'object' THEN
    RAISE EXCEPTION 'Vlastné polia musia byť objekt JSON.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' AND v_new = v_old AND v_org IS NOT DISTINCT FROM v_org_old THEN
    RETURN NEW;
  END IF;

  FOR v_key IN
    SELECT k FROM jsonb_object_keys(v_new) k
    UNION
    SELECT k FROM jsonb_object_keys(v_old) k
  LOOP
    v_val := v_new -> v_key;   -- NULL = kľúč odstránený
    CONTINUE WHEN v_val IS NOT DISTINCT FROM v_old -> v_key AND v_org IS NOT DISTINCT FROM v_org_old;

    SELECT * INTO v_f FROM custom_field WHERE entity = v_entity AND key = v_key;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Neznáme vlastné pole „%“ (%).', v_key, v_entity USING ERRCODE = 'check_violation';
    END IF;
    IF v_f.org_id IS NOT NULL AND v_org IS NOT NULL AND v_f.org_id <> v_org AND v_val IS NOT NULL
       AND v_val <> 'null' THEN
      RAISE EXCEPTION 'Pole „%“ platí pre inú spoločnosť.', v_f.label USING ERRCODE = 'check_violation';
    END IF;
    CONTINUE WHEN v_val IS NOT DISTINCT FROM v_old -> v_key;   -- zmenila sa iba spoločnosť
    IF v_f.archived_at IS NOT NULL THEN
      RAISE EXCEPTION 'Pole „%“ je archivované, nedá sa meniť.', v_f.label USING ERRCODE = 'check_violation';
    END IF;
    IF NOT crm_can_edit_field(v_f) THEN
      RAISE EXCEPTION 'Pole „%“ nemôžeš meniť (nastavenie tímov poľa).', v_f.label
        USING ERRCODE = 'insufficient_privilege';
    END IF;
    CONTINUE WHEN v_val IS NULL OR v_val = 'null';   -- vymazanie hodnoty

    CASE v_f.field_type
      WHEN 'text', 'dlhy_text' THEN
        IF jsonb_typeof(v_val) <> 'string' THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný text.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'cislo', 'suma' THEN
        IF jsonb_typeof(v_val) <> 'number' THEN
          RAISE EXCEPTION 'Pole „%“: očakávané číslo.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'ano_nie' THEN
        IF jsonb_typeof(v_val) <> 'boolean' THEN
          RAISE EXCEPTION 'Pole „%“: očakávané áno/nie.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'datum' THEN
        IF jsonb_typeof(v_val) <> 'string' OR (v_val #>> '{}') !~ '^\d{4}-\d{2}-\d{2}$'
           OR pg_input_is_valid(v_val #>> '{}', 'date') IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný dátum RRRR-MM-DD.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
      WHEN 'vyber', 'vyber_viac' THEN
        IF v_f.field_type = 'vyber' AND jsonb_typeof(v_val) <> 'string'
           OR v_f.field_type = 'vyber_viac' AND jsonb_typeof(v_val) <> 'array' THEN
          RAISE EXCEPTION 'Pole „%“: očakávaná hodnota výberu.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
        FOR v_item IN
          SELECT x FROM jsonb_array_elements(CASE jsonb_typeof(v_val) WHEN 'array' THEN v_val
                                                                       ELSE jsonb_build_array(v_val) END) x
        LOOP
          IF jsonb_typeof(v_item) <> 'string' OR pg_input_is_valid(v_item #>> '{}', 'uuid') IS NOT TRUE
             OR NOT EXISTS (SELECT 1 FROM custom_field_option o
                             WHERE o.field_id = v_f.id AND o.id = (v_item #>> '{}')::uuid) THEN
            RAISE EXCEPTION 'Pole „%“: neznáma hodnota výberu.', v_f.label USING ERRCODE = 'check_violation';
          END IF;
          -- skrytú hodnotu možno ponechať, nie nanovo vybrať
          IF EXISTS (SELECT 1 FROM custom_field_option o
                      WHERE o.id = (v_item #>> '{}')::uuid AND o.hidden_at IS NOT NULL)
             AND NOT (coalesce(v_old -> v_key, 'null') = v_item
                      OR (jsonb_typeof(v_old -> v_key) = 'array' AND (v_old -> v_key) @> jsonb_build_array(v_item))) THEN
            RAISE EXCEPTION 'Pole „%“: hodnota je skrytá, nedá sa vybrať.', v_f.label USING ERRCODE = 'check_violation';
          END IF;
        END LOOP;
      WHEN 'odkaz' THEN
        IF jsonb_typeof(v_val) <> 'string' OR pg_input_is_valid(v_val #>> '{}', 'uuid') IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: očakávaný odkaz na záznam.', v_f.label USING ERRCODE = 'check_violation';
        END IF;
        -- cieľ existuje (a prihlásený ho vidí) a patrí tej istej spoločnosti (Peter 12. 10.)
        EXECUTE format('SELECT true, to_jsonb(t) ->> ''org_id'' FROM %I t WHERE t.id = $1',
                       crm_entity_table(v_f.ref_entity))
          INTO v_found, v_ref_org USING (v_val #>> '{}')::uuid;
        IF v_found IS NOT TRUE THEN
          RAISE EXCEPTION 'Pole „%“: odkazovaný záznam neexistuje.', v_f.label USING ERRCODE = 'foreign_key_violation';
        END IF;
        IF v_org IS NOT NULL AND v_ref_org IS NOT NULL AND v_ref_org::uuid <> v_org THEN
          RAISE EXCEPTION 'Pole „%“: odkazovaný záznam patrí inej spoločnosti.', v_f.label
            USING ERRCODE = 'check_violation';
        END IF;
    END CASE;
  END LOOP;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  e crm_entity;
  t text;
BEGIN
  FOREACH e IN ARRAY enum_range(NULL::crm_entity) LOOP
    t := crm_entity_table(e);
    EXECUTE format('ALTER TABLE %I ADD COLUMN custom jsonb NOT NULL DEFAULT ''{}''', t);
    EXECUTE format('COMMENT ON COLUMN %I.custom IS ''vlastné polia z Nastavení: {kľúč poľa: hodnota}''', t);
    EXECUTE format('CREATE INDEX %I ON %I USING gin (custom jsonb_path_ops)', t || '_custom_idx', t);
    EXECUTE format('CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON %I '
                   'FOR EACH ROW EXECUTE FUNCTION custom_values_check(%L)', t, e);
  END LOOP;
END;
$$;

-- ============================================================================
-- Pipelines a stage
-- ============================================================================

-- Druh obchodu je jadro (logika „výrobca“, segment); presný zoznam potvrdí modul Obchod.
CREATE TYPE deal_kind AS ENUM ('b2c_dodavka', 'b2b_dodavka', 'b2b_vykup', 'green_solar', 'green_viwa', 'efet');
CREATE TYPE stage_outcome AS ENUM ('otvoreny', 'vyhrany', 'prehrany');

ALTER TABLE pipeline
  ADD COLUMN org_id       uuid REFERENCES org (id),
  ADD COLUMN kind         deal_kind NOT NULL,
  ADD COLUMN archived_at  timestamptz,
  DROP CONSTRAINT pipeline_name_key;
CREATE UNIQUE INDEX pipeline_org_name_key ON pipeline (org_id, name) NULLS NOT DISTINCT;
COMMENT ON COLUMN pipeline.org_id IS 'NULL = celá skupina';
COMMENT ON COLUMN pipeline.kind IS 'druh obchodu (jadro), názov pipeline sa meniť dá';

ALTER TABLE pipeline_stage
  DROP CONSTRAINT pipeline_stage_won_is_closed_check,
  DROP COLUMN is_closed,
  DROP COLUMN is_won,
  ADD COLUMN outcome      stage_outcome NOT NULL DEFAULT 'otvoreny',
  ADD COLUMN archived_at  timestamptz;
ALTER TABLE pipeline_stage
  ADD COLUMN is_closed boolean GENERATED ALWAYS AS (outcome <> 'otvoreny') STORED,
  ADD COLUMN is_won    boolean GENERATED ALWAYS AS (outcome = 'vyhrany') STORED;
COMMENT ON COLUMN pipeline_stage.outcome IS 'typ stage: otvorený / vyhraný / prehraný';
COMMENT ON COLUMN pipeline_stage.is_closed IS 'vypočítané z outcome (pre staršie dopyty)';

-- Pipeline a stage sa nemažú (archivujú sa); stage s dealmi chráni aj cudzí kľúč.
CREATE FUNCTION pipeline_no_delete() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Pipeline ani stage sa nemažú, iba archivujú.' USING ERRCODE = 'check_violation';
END;
$$;
CREATE TRIGGER trg_no_delete BEFORE DELETE ON pipeline
  FOR EACH ROW WHEN (current_user <> 'crm_sync') EXECUTE FUNCTION pipeline_no_delete();
CREATE TRIGGER trg_no_delete BEFORE DELETE ON pipeline_stage
  FOR EACH ROW WHEN (current_user <> 'crm_sync') EXECUTE FUNCTION pipeline_no_delete();

-- Povinné polia pri prechode do stage (kontroluje API pri zmene stage)
CREATE TABLE pipeline_stage_required_field (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage_id         uuid NOT NULL REFERENCES pipeline_stage (id) ON DELETE CASCADE,
  core_field       text CHECK (core_field ~ '^[a-z][a-z0-9_]{1,62}$'),
  custom_field_id  uuid REFERENCES custom_field (id),
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pipeline_stage_required_field_one_check CHECK ((core_field IS NULL) <> (custom_field_id IS NULL)),
  UNIQUE NULLS NOT DISTINCT (stage_id, core_field, custom_field_id)
);
COMMENT ON COLUMN pipeline_stage_required_field.core_field IS 'pole jadra dealu zo zoznamu v kóde (napr. lost_reason)';

-- ============================================================================
-- updated_at, audit, RLS
-- ============================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['lookup_value', 'custom_field_section', 'custom_field', 'custom_field_team',
                           'custom_field_option', 'pipeline_stage_required_field'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_row()', t);
  END LOOP;
  EXECUTE 'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON lookup_list FOR EACH ROW EXECUTE FUNCTION set_updated_at()';

  -- čítať: každý aktívny používateľ; meniť: admin (zoznamy číselníkov iba migrácia)
  FOREACH t IN ARRAY ARRAY['lookup_list', 'lookup_value', 'custom_field_section', 'custom_field',
                           'custom_field_team', 'custom_field_option', 'pipeline', 'pipeline_stage',
                           'pipeline_stage_required_field'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY settings_read ON %I FOR SELECT USING ((SELECT crm_session_ok()))', t);
    CONTINUE WHEN t = 'lookup_list';
    EXECUTE format('CREATE POLICY settings_insert ON %I FOR INSERT WITH CHECK ((SELECT crm_settings_writer()))', t);
    EXECUTE format('CREATE POLICY settings_update ON %I FOR UPDATE USING ((SELECT crm_settings_writer())) WITH CHECK ((SELECT crm_settings_writer()))', t);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['custom_field_team', 'pipeline_stage_required_field', 'custom_field_section'] LOOP
    EXECUTE format('CREATE POLICY settings_delete ON %I FOR DELETE USING ((SELECT crm_settings_writer()))', t);
  END LOOP;
END;
$$;

-- Systémové hodnoty zakladá iba migrácia (admin nie)
CREATE POLICY settings_no_system ON lookup_value AS RESTRICTIVE FOR INSERT
  WITH CHECK (NOT is_system OR crm_is_service());

-- ============================================================================
-- Východiskové údaje
-- ============================================================================

INSERT INTO lookup_list (code, name, used_on) VALUES
  ('zdroj_kontaktu',           'Zdroj kontaktu',                    'osoba'),
  ('dovod_odchodu',            'Dôvod odchodu zákazníka',           'firma, osoba'),
  ('dovod_prehry',             'Dôvod prehratého dealu',            'deal'),
  ('predchadzajuci_dodavatel', 'Predchádzajúci dodávateľ',          'odberné miesto'),
  ('rola_kontaktu',            'Rola kontaktu vo firme',            'firma – osoba');

-- Roly kontaktu (Peter 12. 10., odpoveď 2): štatutár, decision maker a fakturácia sú systémové.
INSERT INTO lookup_value (list_code, code, label, sort_order, is_system) VALUES
  ('rola_kontaktu', 'statutar',        'Štatutár',         1, true),
  ('rola_kontaktu', 'decision_maker',  'Decision maker',   2, true),
  ('rola_kontaktu', 'fakturacia',      'Fakturácia',       3, true),
  ('rola_kontaktu', 'kontaktna_osoba', 'Kontaktná osoba',  4, false),
  ('rola_kontaktu', 'technik',         'Technik',          5, false);

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pipeline) OR EXISTS (SELECT 1 FROM custom_field) THEN
    RAISE EXCEPTION 'Návrat 0007 vyžaduje prázdne pipelines a vlastné polia.';
  END IF;
END;
$$;

-- contact_v (p.*) závisí od stĺpca custom: zruší sa a znova vytvorí bez neho
DROP VIEW contact_v;

DO $$
DECLARE
  p record;
  t text;
  e crm_entity;
BEGIN
  FOR p IN SELECT tablename, policyname FROM pg_policies
            WHERE schemaname = 'public'
              AND tablename IN ('lookup_list', 'lookup_value', 'custom_field_section', 'custom_field',
                                'custom_field_team', 'custom_field_option', 'pipeline', 'pipeline_stage',
                                'pipeline_stage_required_field') LOOP
    EXECUTE format('DROP POLICY %I ON %I', p.policyname, p.tablename);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['pipeline', 'pipeline_stage'] LOOP
    EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t);
  END LOOP;
  FOREACH e IN ARRAY enum_range(NULL::crm_entity) LOOP
    t := crm_entity_table(e);
    EXECUTE format('DROP TRIGGER IF EXISTS trg_custom_values ON %I', t);
    EXECUTE format('ALTER TABLE %I DROP COLUMN custom', t);
  END LOOP;
END;
$$;

CREATE VIEW contact_v WITH (security_invoker = true) AS
SELECT p.*,
       x.archived,
       (NOT x.archived AND p.marketing_opt_out_at IS NULL) AS marketing_allowed
  FROM contact p
  CROSS JOIN LATERAL (
    SELECT NOT (p.is_household AND p.status IS DISTINCT FROM 'zruseny_zakaznik')
           AND NOT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                            WHERE cc.contact_id = p.id AND NOT company_is_archived(c))
           AND (p.is_household OR EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id))
           AS archived
  ) x;
COMMENT ON VIEW contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';

DROP TABLE IF EXISTS pipeline_stage_required_field;
DROP TRIGGER IF EXISTS trg_no_delete ON pipeline_stage;
DROP TRIGGER IF EXISTS trg_no_delete ON pipeline;
DROP FUNCTION IF EXISTS pipeline_no_delete();
ALTER TABLE pipeline_stage
  DROP COLUMN is_won,
  DROP COLUMN is_closed,
  DROP COLUMN archived_at,
  DROP COLUMN outcome,
  ADD COLUMN is_closed boolean NOT NULL DEFAULT false,
  ADD COLUMN is_won boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT pipeline_stage_won_is_closed_check CHECK (NOT is_won OR is_closed);
DROP INDEX IF EXISTS pipeline_org_name_key;
ALTER TABLE pipeline
  DROP COLUMN archived_at,
  DROP COLUMN kind,
  DROP COLUMN org_id,
  ADD CONSTRAINT pipeline_name_key UNIQUE (name);
DROP TYPE IF EXISTS stage_outcome;
DROP TYPE IF EXISTS deal_kind;

DROP FUNCTION IF EXISTS custom_values_check();
DROP FUNCTION IF EXISTS crm_can_edit_field(custom_field);
DROP TABLE IF EXISTS custom_field_option;
DROP FUNCTION IF EXISTS custom_field_option_guard();
DROP TABLE IF EXISTS custom_field_team;
DROP TABLE IF EXISTS custom_field;
DROP FUNCTION IF EXISTS custom_field_guard();
DROP TABLE IF EXISTS custom_field_section;
DROP TYPE IF EXISTS field_edit_access;
DROP TYPE IF EXISTS custom_field_type;

DROP FUNCTION IF EXISTS lookup_codes_check(text, uuid, text[], text[]);
DROP TABLE IF EXISTS lookup_value;
DROP FUNCTION IF EXISTS lookup_value_guard();
DROP TABLE IF EXISTS lookup_list;

DROP FUNCTION IF EXISTS crm_entity_table(crm_entity);
DROP TYPE IF EXISTS crm_entity;
DROP FUNCTION IF EXISTS crm_slug(text);
