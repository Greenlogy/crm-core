-- 0006_nastavenia_jadro.sql – Modul 0 Nastavenia, časť 1 (docs/moduly/00-nastavenia-navrh-db.md v0.1)
--
-- Spoločnosti skupiny (org) s údajmi do dokumentov, logom a bankovými účtami.
-- Tím = skupina práv (team_permission: modul × vidieť / upravovať / archivovať / exportovať).
-- Používateľ: stav pozvaný / aktívny / deaktivovaný, príznak admin, prístup k spoločnostiam.
--   Rola app_user_role sa ruší (mapovanie v návrhu, časť 1.3).
-- Funkcie práv crm_user_orgs(), crm_scope(), crm_can_change_owner(); politiky Zákazníkov z 0005
--   bežia ďalej cez prechodné crm_sees_all() a crm_external_user_id(), ktoré 0008 nahradí.
-- Pracovný čas a voľné dni podľa spoločnosti; business_calendar sa z nich prepočíta.
-- Audit: zdroj zmeny, zmeny vlastných polí po kľúčoch, audit sa nedá meniť ani mazať, záznam exportov.
-- Nastavenia mení iba admin (RLS na tabuľkách Nastavení).
-- Východiskové údaje: Greenlogy a.s. (SK, EUR) + 2 pripravované spoločnosti, 6 tímov s právami,
--   Peter Kalman (admin, CEO), Eva Kalmanová (admin, Marketing), pracovný čas Po–Pi 7:30–15:30, štátne sviatky SR 2026–2028 z 0002.
--
-- Predpoklad: prázdna databáza (Test sa vyprázdni skriptom db/empty-test.sh, main je prázdny).

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM team) OR EXISTS (SELECT 1 FROM app_user)
     OR EXISTS (SELECT 1 FROM company) OR EXISTS (SELECT 1 FROM contact)
     OR EXISTS (SELECT 1 FROM deal) OR EXISTS (SELECT 1 FROM pipeline) THEN
    RAISE EXCEPTION 'Migrácia 0006 vyžaduje prázdnu databázu (najprv ./db/empty-test.sh).';
  END IF;
END;
$$;

-- ============================================================================
-- Enumy
-- ============================================================================

CREATE TYPE country_code AS ENUM ('SK', 'CZ', 'HR');                 -- nová krajina = zmena v kóde
CREATE TYPE org_status AS ENUM ('aktivna', 'pripravuje_sa');
CREATE TYPE bank_account_purpose AS ENUM ('faktury', 'zalohy', 'vykup');
CREATE TYPE crm_module AS ENUM (
  'zakaznici', 'odberne_miesta', 'obchod', 'zmluvy', 'provizie', 'servis', 'marketing'
);
CREATE TYPE access_scope AS ENUM ('nic', 'iba_svoje', 'vsetko');      -- poradie = sila práva
CREATE TYPE user_status AS ENUM ('pozvany', 'aktivny', 'deaktivovany');
CREATE TYPE day_off_kind AS ENUM ('statny_sviatok', 'firemne_volno');
CREATE TYPE audit_source AS ENUM ('aplikacia', 'system', 'synchronizacia');

-- ============================================================================
-- Spoločnosti skupiny
-- ============================================================================

CREATE TABLE org (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code               text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  country            country_code NOT NULL,
  currency           char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  status             org_status NOT NULL DEFAULT 'pripravuje_sa',
  is_default         boolean NOT NULL DEFAULT false,
  timezone           text NOT NULL DEFAULT 'Europe/Bratislava',
  legal_name         text NOT NULL CHECK (btrim(legal_name) <> ''),
  reg_no             text,
  tax_no             text,
  vat_no             text,
  address            text,
  registry_entry     text,
  statutory          text,
  support_phone      text,
  email              text,
  web                text,
  regulator_license  text,
  logo_updated_at    timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX org_one_default_key ON org (is_default) WHERE is_default;
COMMENT ON TABLE org IS 'spoločnosti skupiny Greenlogy (nie firmy zákazníkov – tie sú v company)';
COMMENT ON COLUMN org.reg_no IS 'IČO (SK, CZ) alebo OIB (HR) spoločnosti';
COMMENT ON COLUMN org.regulator_license IS 'číslo povolenia regulátora: SK ÚRSO, CZ ERÚ, HR HERA';

-- Logo zvlášť: veľký binárny obsah nejde do auditu (audit zachytí org.logo_updated_at).
CREATE TABLE org_logo (
  org_id      uuid PRIMARY KEY REFERENCES org (id),
  mime        text NOT NULL CHECK (mime IN ('image/svg+xml', 'image/png')),
  data        bytea NOT NULL CHECK (octet_length(data) <= 524288),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE org_bank_account (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  iban         text NOT NULL CHECK (iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$'),
  bic          text,
  bank_name    text,
  purposes     bank_account_purpose[] NOT NULL DEFAULT '{}',
  is_primary   boolean NOT NULL DEFAULT false,
  archived_at  timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, iban)
);
CREATE UNIQUE INDEX org_bank_account_one_primary_key ON org_bank_account (org_id)
  WHERE is_primary AND archived_at IS NULL;
COMMENT ON COLUMN org_bank_account.iban IS 'IBAN bez medzier, veľkými písmenami (upraví spúšťač)';

CREATE FUNCTION org_bank_account_normalize() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.iban := upper(regexp_replace(NEW.iban, '\s', '', 'g'));
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_normalize BEFORE INSERT OR UPDATE OF iban ON org_bank_account
  FOR EACH ROW EXECUTE FUNCTION org_bank_account_normalize();

-- Predvolená spoločnosť (Greenlogy a.s.) – predvolená hodnota org_id na záznamoch.
CREATE FUNCTION crm_default_org() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT id FROM org WHERE is_default
$$;

-- ============================================================================
-- Tímy a práva
-- ============================================================================

ALTER TABLE team
  ADD COLUMN code              text NOT NULL CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  ADD COLUMN description       text,
  ADD COLUMN all_orgs          boolean NOT NULL DEFAULT false,
  ADD COLUMN can_change_owner  boolean NOT NULL DEFAULT false,
  ADD COLUMN is_external       boolean NOT NULL DEFAULT false,
  ADD COLUMN archived_at       timestamptz,
  ADD CONSTRAINT team_code_key UNIQUE (code),
  ADD CONSTRAINT team_external_check CHECK (NOT (is_external AND (all_orgs OR can_change_owner)));
COMMENT ON COLUMN team.all_orgs IS 'tím vidí všetky spoločnosti skupiny (CEO, Nákup, Marketing)';
COMMENT ON COLUMN team.can_change_owner IS 'členovia tímu menia vlastníka (obchodníka) záznamov; okrem nich iba admin';
COMMENT ON COLUMN team.is_external IS 'externý tím: nikdy nesmie dostať „všetko“ (poistka v databáze)';

CREATE TABLE team_permission (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id      uuid NOT NULL REFERENCES team (id) ON DELETE CASCADE,
  module       crm_module NOT NULL,
  view_scope   access_scope NOT NULL DEFAULT 'nic',
  edit_scope   access_scope NOT NULL DEFAULT 'nic',
  can_archive  boolean NOT NULL DEFAULT false,
  can_export   boolean NOT NULL DEFAULT false,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (team_id, module),
  CONSTRAINT team_permission_edit_le_view_check CHECK (edit_scope <= view_scope)
);
COMMENT ON TABLE team_permission IS 'práva tímu po moduloch; „iba svoje“ = záznamy, kde je používateľ vlastníkom';

-- Nový tím dostane riadok pre každý modul (všetko „nič“); admin ich potom nastaví.
CREATE FUNCTION team_permission_init() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO team_permission (team_id, module)
  SELECT NEW.id, m FROM unnest(enum_range(NULL::crm_module)) AS m;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_team_permission_init AFTER INSERT ON team
  FOR EACH ROW EXECUTE FUNCTION team_permission_init();

-- Poistka (návrh 3.4, Peter 12. 10.): externý tím nesmie mať „všetko“ v žiadnom module.
CREATE FUNCTION team_external_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_TABLE_NAME = 'team_permission' THEN
    IF (NEW.view_scope = 'vsetko' OR NEW.edit_scope = 'vsetko')
       AND EXISTS (SELECT 1 FROM team t WHERE t.id = NEW.team_id AND t.is_external) THEN
      RAISE EXCEPTION 'Externý tím nemôže vidieť ani upravovať „všetko“ (modul %).', NEW.module
        USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.is_external AND EXISTS (SELECT 1 FROM team_permission p
                                     WHERE p.team_id = NEW.id
                                       AND (p.view_scope = 'vsetko' OR p.edit_scope = 'vsetko')) THEN
    RAISE EXCEPTION 'Tím s právom „všetko“ nemôže byť externý.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_team_external_guard BEFORE INSERT OR UPDATE ON team_permission
  FOR EACH ROW EXECUTE FUNCTION team_external_guard();
CREATE TRIGGER trg_team_external_guard BEFORE UPDATE OF is_external ON team
  FOR EACH ROW EXECUTE FUNCTION team_external_guard();

-- ============================================================================
-- Používatelia
-- ============================================================================

ALTER TABLE app_user
  ADD COLUMN status          user_status NOT NULL DEFAULT 'pozvany',
  ADD COLUMN is_admin        boolean NOT NULL DEFAULT false,
  ADD COLUMN invited_at      timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN last_login_at   timestamptz,
  ADD COLUMN deactivated_at  timestamptz,
  DROP COLUMN role,
  DROP COLUMN active,
  ALTER COLUMN team_id SET NOT NULL,
  ADD CONSTRAINT app_user_name_check CHECK (btrim(name) <> ''),
  ADD CONSTRAINT app_user_email_check CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'),
  ADD CONSTRAINT app_user_deactivated_check CHECK ((status = 'deaktivovany') = (deactivated_at IS NOT NULL));
DROP TYPE app_user_role;

COMMENT ON COLUMN app_user.status IS 'pozvany → aktivny pri prvom prihlásení (app_user_login); deaktivovany iba cez app_user_deactivate';
COMMENT ON COLUMN app_user.is_admin IS 'smie meniť Nastavenia; prihlásenie vyplýva z e-mailu (@greenlogy.com = Google, inak kód e-mailom)';
COMMENT ON COLUMN app_user.last_login_at IS 'posledné prihlásenie; nezapisuje sa do auditu';

CREATE TABLE app_user_org (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES app_user (id) ON DELETE CASCADE,
  org_id      uuid NOT NULL REFERENCES org (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, org_id)
);
CREATE INDEX app_user_org_org_id_idx ON app_user_org (org_id);
COMMENT ON TABLE app_user_org IS 'prístup používateľa k spoločnostiam; tím s all_orgs vidí všetky bez ohľadu na túto tabuľku';

-- ============================================================================
-- Kto je prihlásený a čo smie
-- ============================================================================
-- API nastaví v každej transakcii SET LOCAL app.user_id = '<uuid>' (to isté používa audit).
-- Rola aplikácie má app.require_user = 'on': bez používateľa nevidí nič.
-- Rola bez povinného používateľa (vlastník, crm_sync, Cockpit) vidí všetko.
-- Všetky funkcie sú SECURITY DEFINER: čítajú app_user a team bez ohľadu na RLS.

CREATE FUNCTION crm_require_user() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT coalesce(current_setting('app.require_user', true), '') = 'on'
$$;

-- Spojenie bez používateľa a bez povinnosti používateľa (údržba, synchronizácia, Cockpit)
CREATE FUNCTION crm_is_service() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT crm_current_user_id() IS NULL AND NOT crm_require_user()
$$;

-- Prihlásený aktívny používateľ v nearchivovanom tíme
CREATE FUNCTION crm_active_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT u.id FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.id = crm_current_user_id() AND u.status = 'aktivny' AND t.archived_at IS NULL
$$;

-- Smie vôbec niečo vidieť (služba alebo aktívny používateľ)
CREATE FUNCTION crm_session_ok() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_active_user_id() IS NOT NULL
$$;

CREATE FUNCTION crm_is_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.is_admin)
$$;

-- Smie meniť Nastavenia (admin alebo služba)
CREATE FUNCTION crm_settings_writer() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_is_admin()
$$;

-- Spoločnosti, ktoré prihlásený vidí
CREATE FUNCTION crm_user_orgs() RETURNS uuid[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE
           WHEN crm_is_service() THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           WHEN EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                         WHERE u.id = crm_active_user_id() AND t.all_orgs)
             THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           ELSE (SELECT coalesce(array_agg(uo.org_id), '{}') FROM app_user_org uo
                  WHERE uo.user_id = crm_active_user_id())
         END
$$;

-- Rozsah práva tímu prihláseného v module: p_action 'view' alebo 'edit'.
-- Služba: 'vsetko'; aplikácia bez aktívneho používateľa: 'nic'.
CREATE FUNCTION crm_scope(p_module crm_module, p_action text) RETURNS access_scope
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_scope access_scope;
BEGIN
  IF p_action NOT IN ('view', 'edit') THEN
    RAISE EXCEPTION 'crm_scope: akcia musí byť view alebo edit (zadané %)', p_action;
  END IF;
  IF crm_is_service() THEN
    RETURN 'vsetko';
  END IF;
  SELECT CASE p_action WHEN 'view' THEN p.view_scope ELSE p.edit_scope END
    INTO v_scope
    FROM app_user u
    JOIN team_permission p ON p.team_id = u.team_id AND p.module = p_module
   WHERE u.id = crm_active_user_id();
  RETURN coalesce(v_scope, 'nic');
END;
$$;

-- Smie meniť vlastníka (obchodníka): tím s can_change_owner alebo admin (Peter 12. 10., odpoveď 5)
CREATE FUNCTION crm_can_change_owner() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = crm_active_user_id() AND (u.is_admin OR t.can_change_owner))
$$;

-- Do externého tímu sa nikto nepriradí, kým nemajú politiky RLS všetky tabuľky s jeho zákazníkmi
-- (OOM, dealy, zmluvy, ponuky, aktivity – rozhodnutie 2026-10-11). Zapne to (true) migrácia
-- posledného z týchto modulov.
CREATE FUNCTION crm_external_ready() RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT false
$$;

-- Prechodne pre politiky z 0005 (0008 ich nahradí a tieto funkcie zruší):
-- „vidí všetko“ = rozsah Zákazníci vidieť = všetko; „externý“ = rozsah iba svoje.
CREATE OR REPLACE FUNCTION crm_sees_all() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_scope('zakaznici', 'view') = 'vsetko'
$$;

CREATE OR REPLACE FUNCTION crm_external_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE WHEN crm_scope('zakaznici', 'view') = 'iba_svoje' THEN crm_active_user_id() END
$$;

-- Vlastníka mení iba tím CEO (can_change_owner) a admin; výnimka rola synchronizácie crm_sync.
CREATE OR REPLACE FUNCTION owner_change_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND current_user <> 'crm_sync'
     AND NOT crm_can_change_owner() THEN
    RAISE EXCEPTION 'Vlastníka (obchodníka) môže zmeniť iba vedenie (tím CEO) alebo admin.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- Ochrana používateľov
-- ============================================================================
-- - externý tím: nie admin; priradenie až po crm_external_ready(),
-- - vždy ostane aspoň jeden aktívny admin,
-- - deaktivovaný používateľ nesmie vlastniť firmy, osoby ani otvorené dealy (najprv odovzdať).
CREATE FUNCTION app_user_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_external boolean;
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT t.is_external INTO v_external FROM team t WHERE t.id = NEW.team_id;
    IF v_external AND NEW.is_admin THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže byť admin.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_external AND NOT crm_external_ready()
       AND (TG_OP = 'INSERT' OR NEW.team_id IS DISTINCT FROM OLD.team_id) THEN
      RAISE EXCEPTION 'Do externého tímu zatiaľ nemožno priradiť používateľa: OOM, dealy, zmluvy a ponuky ešte nemajú obmedzenie „iba svoje“ v databáze.'
        USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.status = 'deaktivovany' AND (TG_OP = 'INSERT' OR OLD.status <> 'deaktivovany')
       AND (EXISTS (SELECT 1 FROM company WHERE owner_id = NEW.id)
         OR EXISTS (SELECT 1 FROM contact WHERE owner_id = NEW.id)
         OR EXISTS (SELECT 1 FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
                     WHERE d.owner_id = NEW.id AND NOT s.is_closed)) THEN
      RAISE EXCEPTION 'Používateľ ešte vlastní zákazníkov alebo otvorené dealy. Deaktivuj ho cez odovzdanie novému vlastníkovi.'
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  -- posledný aktívny admin
  IF TG_OP = 'DELETE' OR NOT (NEW.is_admin AND NEW.status = 'aktivny') THEN
    IF TG_OP <> 'INSERT' AND OLD.is_admin AND OLD.status = 'aktivny'
       AND NOT EXISTS (SELECT 1 FROM app_user u
                        WHERE u.id <> OLD.id AND u.is_admin AND u.status = 'aktivny') THEN
      RAISE EXCEPTION 'CRM musí mať aspoň jedného aktívneho admina.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_app_user_guard BEFORE INSERT OR UPDATE OR DELETE ON app_user
  FOR EACH ROW EXECUTE FUNCTION app_user_guard();

-- Prihlásenie (volá API po overení Cloudflare Access, ešte pred SET LOCAL app.user_id).
-- Pozvaný sa pri prvom prihlásení stane aktívnym. Deaktivovaný ani neznámy nedostane id.
-- Príklad: SELECT * FROM app_user_login('Peter@Greenlogy.com') → user_id, status = 'aktivny'.
CREATE FUNCTION app_user_login(p_email text)
RETURNS TABLE (user_id uuid, status user_status)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_user app_user;
BEGIN
  SELECT * INTO v_user FROM app_user u WHERE lower(u.email) = lower(btrim(p_email));
  IF NOT FOUND THEN
    RETURN;
  END IF;
  IF v_user.status = 'deaktivovany' THEN
    RETURN QUERY SELECT NULL::uuid, v_user.status;
    RETURN;
  END IF;
  UPDATE app_user u
     SET status = 'aktivny', last_login_at = now()
   WHERE u.id = v_user.id;
  RETURN QUERY SELECT v_user.id, 'aktivny'::user_status;
END;
$$;

-- Deaktivácia s odovzdaním (zadanie čl. 3, príklad 6): v jednej transakcii prepíše vlastníka firiem,
-- osôb a otvorených dealov na nového vlastníka a deaktivuje. Smie iba admin.
-- Príklad: SELECT * FROM app_user_deactivate('<id Martina>', '<id Jany>') → 120 firiem/osôb, 8 dealov.
CREATE FUNCTION app_user_deactivate(p_user_id uuid, p_new_owner_id uuid)
RETURNS TABLE (companies integer, contacts integer, open_deals integer)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_companies  integer;
  v_contacts   integer;
  v_deals      integer;
BEGIN
  IF NOT crm_settings_writer() THEN
    RAISE EXCEPTION 'Deaktivovať používateľa môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user_id = crm_current_user_id() THEN
    RAISE EXCEPTION 'Sám seba deaktivovať nemožno.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user WHERE id = p_user_id AND status <> 'deaktivovany') THEN
    RAISE EXCEPTION 'Používateľ neexistuje alebo už je deaktivovaný.' USING ERRCODE = 'no_data_found';
  END IF;

  SELECT count(*) INTO v_companies FROM company WHERE owner_id = p_user_id;
  SELECT count(*) INTO v_contacts FROM contact WHERE owner_id = p_user_id;
  SELECT count(*) INTO v_deals FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
   WHERE d.owner_id = p_user_id AND NOT s.is_closed;

  IF v_companies + v_contacts + v_deals > 0 THEN
    IF p_new_owner_id IS NULL THEN
      RAISE EXCEPTION 'Používateľ vlastní % firiem, % osôb a % otvorených dealov. Vyber nového vlastníka.',
        v_companies, v_contacts, v_deals USING ERRCODE = 'check_violation';
    END IF;
    IF p_new_owner_id = p_user_id
       OR NOT EXISTS (SELECT 1 FROM app_user WHERE id = p_new_owner_id AND status = 'aktivny') THEN
      RAISE EXCEPTION 'Nový vlastník musí byť iný aktívny používateľ.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE company SET owner_id = p_new_owner_id WHERE owner_id = p_user_id;
    UPDATE contact SET owner_id = p_new_owner_id WHERE owner_id = p_user_id;
    UPDATE deal d SET owner_id = p_new_owner_id
      FROM pipeline_stage s
     WHERE s.id = d.stage_id AND d.owner_id = p_user_id AND NOT s.is_closed;
  END IF;

  UPDATE app_user SET status = 'deaktivovany', deactivated_at = now() WHERE id = p_user_id;
  RETURN QUERY SELECT v_companies, v_contacts, v_deals;
END;
$$;

-- ============================================================================
-- Pracovný čas a voľné dni podľa spoločnosti
-- ============================================================================

CREATE TABLE org_work_hours (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES org (id),
  weekday     smallint NOT NULL CHECK (weekday BETWEEN 1 AND 7),
  work_from   time NOT NULL,
  work_to     time NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, weekday),
  CONSTRAINT org_work_hours_check CHECK (work_to > work_from)
);
COMMENT ON TABLE org_work_hours IS 'týždenný pracovný čas spoločnosti; deň bez riadku = voľno; 1 = pondelok';

CREATE TABLE org_day_off (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id      uuid NOT NULL REFERENCES org (id),
  date        date NOT NULL,
  kind        day_off_kind NOT NULL,
  name        text NOT NULL CHECK (btrim(name) <> ''),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, date)
);
COMMENT ON TABLE org_day_off IS 'štátne sviatky (iba migráciou, podľa zákona krajiny) a firemné voľno (admin)';

ALTER TABLE business_calendar ADD COLUMN org_id uuid REFERENCES org (id);
COMMENT ON TABLE business_calendar IS 'pracovné dni a čas pre výpočet SLA, podľa spoločnosti; prepočítava sa z org_work_hours a org_day_off';

-- Prepočet kalendára všetkých spoločností. Kalendár pokrýva celé roky, pre ktoré sú zadané
-- štátne sviatky (bez sviatkov sa termín SLA počítať nedá).
CREATE FUNCTION business_calendar_rebuild() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  DELETE FROM business_calendar;
  INSERT INTO business_calendar (org_id, date, is_working_day, work_from, work_to, note)
  SELECT r.org_id, d.date,
         h.org_id IS NOT NULL AND o.org_id IS NULL,
         CASE WHEN o.org_id IS NULL THEN h.work_from END,
         CASE WHEN o.org_id IS NULL THEN h.work_to END,
         o.name
    FROM (SELECT org_id,
                 make_date(extract(year FROM min(date))::int, 1, 1) AS date_from,
                 make_date(extract(year FROM max(date))::int, 12, 31) AS date_to
            FROM org_day_off WHERE kind = 'statny_sviatok'
           GROUP BY org_id) r
   CROSS JOIN LATERAL (SELECT g::date AS date FROM generate_series(r.date_from, r.date_to, interval '1 day') g) d
    LEFT JOIN org_work_hours h ON h.org_id = r.org_id AND h.weekday = extract(isodow FROM d.date)
    LEFT JOIN org_day_off o ON o.org_id = r.org_id AND o.date = d.date;
  RETURN NULL;
END;
$$;

-- ============================================================================
-- Audit
-- ============================================================================

ALTER TABLE audit_log ADD COLUMN source audit_source NOT NULL DEFAULT 'system';
COMMENT ON COLUMN audit_log.source IS 'aplikacia = prihlásený používateľ; system = údržba alebo výpočet CRM; synchronizacia = rola crm_sync. API môže prepísať cez SET LOCAL app.change_source';
COMMENT ON COLUMN audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce, vlastné polia ako custom.<kľúč>; delete: pôvodný riadok';
CREATE INDEX audit_log_table_changed_at_idx ON audit_log (table_name, changed_at);

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

-- Audit sa nedá upraviť ani zmazať; výnimkou je iba vlastník tabuľky (vyprázdnenie Testu).
CREATE FUNCTION audit_log_protect() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF current_user <> (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner
                       WHERE c.oid = 'audit_log'::regclass) THEN
    RAISE EXCEPTION 'Audit sa nedá upraviť ani zmazať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(OLD, NEW);
END;
$$;
CREATE TRIGGER trg_protect BEFORE UPDATE OR DELETE ON audit_log
  FOR EACH ROW EXECUTE FUNCTION audit_log_protect();
CREATE TRIGGER trg_protect_truncate BEFORE TRUNCATE ON audit_log
  FOR EACH STATEMENT EXECUTE FUNCTION audit_log_protect();

-- Export zoznamov (osobné údaje) musí byť dohľadateľný. Zapisuje API.
CREATE TABLE export_log (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     uuid REFERENCES app_user (id),
  module      crm_module NOT NULL,
  filter      jsonb NOT NULL DEFAULT '{}',
  row_count   integer NOT NULL CHECK (row_count >= 0),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX export_log_created_at_idx ON export_log (created_at);
COMMENT ON TABLE export_log IS 'kto, kedy a čo exportoval (bez samotných údajov)';

-- ============================================================================
-- updated_at a audit na nových tabuľkách
-- ============================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['org', 'org_bank_account', 'team_permission', 'app_user_org',
                           'org_work_hours', 'org_day_off'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_row()', t);
  END LOOP;
END;
$$;
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON org_logo
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- Nastavenia mení iba admin (RLS). Čítať smie každý aktívny používateľ a služba.
-- Vlastník tabuliek (migrácie) RLS obchádza.
-- ============================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['org', 'org_logo', 'org_bank_account', 'team', 'team_permission',
                           'app_user', 'app_user_org', 'org_work_hours', 'org_day_off'] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY settings_read ON %I FOR SELECT USING ((SELECT crm_session_ok()))', t);
    EXECUTE format('CREATE POLICY settings_insert ON %I FOR INSERT WITH CHECK ((SELECT crm_settings_writer()))', t);
    EXECUTE format('CREATE POLICY settings_update ON %I FOR UPDATE USING ((SELECT crm_settings_writer())) WITH CHECK ((SELECT crm_settings_writer()))', t);
  END LOOP;
  -- mazať sa smie iba prístup k spoločnosti, bankový účet sa archivuje, voľný deň sa dá odstrániť
  FOREACH t IN ARRAY ARRAY['app_user_org', 'org_day_off', 'org_logo'] LOOP
    EXECUTE format('CREATE POLICY settings_delete ON %I FOR DELETE USING ((SELECT crm_settings_writer()))', t);
  END LOOP;
END;
$$;

-- Štátne sviatky mení iba migrácia (zákon), admin iba firemné voľno.
CREATE POLICY settings_day_off_kind_ins ON org_day_off AS RESTRICTIVE FOR INSERT
  WITH CHECK (kind = 'firemne_volno' OR crm_is_service());
CREATE POLICY settings_day_off_kind_upd ON org_day_off AS RESTRICTIVE FOR UPDATE
  USING (kind = 'firemne_volno' OR crm_is_service())
  WITH CHECK (kind = 'firemne_volno' OR crm_is_service());
CREATE POLICY settings_day_off_kind_del ON org_day_off AS RESTRICTIVE FOR DELETE
  USING (kind = 'firemne_volno' OR crm_is_service());

-- ============================================================================
-- Východiskové údaje
-- ============================================================================

INSERT INTO org (code, country, currency, status, is_default, legal_name) VALUES
  ('greenlogy_sk', 'SK', 'EUR', 'aktivna', true, 'Greenlogy a.s.'),
  ('greenlogy_cz', 'CZ', 'CZK', 'pripravuje_sa', false, 'Česká spoločnosť (pripravuje sa)'),
  ('greenlogy_hr', 'HR', 'EUR', 'pripravuje_sa', false, 'Chorvátska spoločnosť (pripravuje sa)');

-- Tímy (zadanie čl. 3); team_permission_init založí riadky modulov s „nič“.
INSERT INTO team (name, code, description, all_orgs, can_change_owner, is_external) VALUES
  ('CEO',            'ceo',            'vedenie: všetko vidí a upravuje, mení vlastníkov', true,  true,  false),
  ('Sales_internal', 'sales_internal', 'obchodník: vidí všetko, upravuje zákazníkov a dealy', false, false, false),
  ('Sales_external', 'sales_external', 'externý obchodník: vidí a upravuje iba svojich zákazníkov', false, false, true),
  ('Servis',         'servis',         'vidí všetko, upravuje kontaktné údaje a servisné záznamy', false, false, false),
  ('Nákup',          'nakup',          'vidí všetko, upravuje odberné miesta, ceny a nákupné údaje', true,  false, false),
  ('Marketing',      'marketing',      'vidí všetko, upravuje marketingové údaje a súhlasy', true,  false, false);

-- Východiskové práva (zadanie čl. 3, Provízie podľa Petra 12. 10.). Archivovať a exportovať iba CEO;
-- admin ich môže zmeniť.
UPDATE team_permission p
   SET view_scope  = x.view_scope::access_scope,
       edit_scope  = x.edit_scope::access_scope,
       can_archive = x.ceo,
       can_export  = x.ceo
  FROM (
    SELECT tp.id,
           CASE WHEN t.code = 'sales_external' THEN
                  CASE WHEN tp.module IN ('zakaznici', 'odberne_miesta', 'obchod', 'zmluvy', 'provizie')
                       THEN 'iba_svoje' ELSE 'nic' END
                -- Provízie: CEO všetko, Sales_internal iba svoje, ostatní nič (Peter 12. 10.)
                WHEN tp.module = 'provizie' THEN
                  CASE t.code WHEN 'ceo' THEN 'vsetko' WHEN 'sales_internal' THEN 'iba_svoje' ELSE 'nic' END
                ELSE 'vsetko' END AS view_scope,
           CASE t.code
             WHEN 'ceo'            THEN 'vsetko'
             WHEN 'sales_internal' THEN CASE WHEN tp.module IN ('zakaznici', 'obchod') THEN 'vsetko' ELSE 'nic' END
             WHEN 'sales_external' THEN CASE WHEN tp.module IN ('zakaznici', 'obchod') THEN 'iba_svoje' ELSE 'nic' END
             WHEN 'servis'         THEN CASE WHEN tp.module IN ('zakaznici', 'servis') THEN 'vsetko' ELSE 'nic' END
             WHEN 'nakup'          THEN CASE WHEN tp.module IN ('odberne_miesta', 'zmluvy') THEN 'vsetko' ELSE 'nic' END
             WHEN 'marketing'      THEN CASE WHEN tp.module = 'marketing' THEN 'vsetko' ELSE 'nic' END
           END AS edit_scope,
           t.code = 'ceo' AS ceo
      FROM team_permission tp
      JOIN team t ON t.id = tp.team_id
  ) x
 WHERE p.id = x.id;

INSERT INTO app_user (email, name, team_id, is_admin, status)
SELECT 'peter@greenlogy.com', 'Peter Kalman', t.id, true, 'aktivny' FROM team t WHERE t.code = 'ceo';

-- Druhý admin (Peter 12. 10.): Eva Kalmanová, tím Marketing, spoločnosť Greenlogy a.s.
INSERT INTO app_user (email, name, team_id, is_admin, status)
SELECT 'eva@greenlogy.com', 'Eva Kalmanová', t.id, true, 'aktivny' FROM team t WHERE t.code = 'marketing';
INSERT INTO app_user_org (user_id, org_id)
SELECT u.id, crm_default_org() FROM app_user u WHERE lower(u.email) = 'eva@greenlogy.com';

-- Pracovný čas Greenlogy a.s.: Po–Pi 7:30–15:30
INSERT INTO org_work_hours (org_id, weekday, work_from, work_to)
SELECT crm_default_org(), d, time '07:30', time '15:30' FROM generate_series(1, 5) AS d;

-- Štátne sviatky SR 2026–2028 z business_calendar (0002)
INSERT INTO org_day_off (org_id, date, kind, name)
SELECT crm_default_org(), bc.date, 'statny_sviatok', bc.note
  FROM business_calendar bc
 WHERE NOT bc.is_working_day AND bc.note IS NOT NULL;

-- Kalendár podľa spoločnosti: nový kľúč (org_id, date), potom prepočet
CREATE TEMP TABLE business_calendar_0002 ON COMMIT DROP AS
  SELECT date, is_working_day, work_from, work_to, note FROM business_calendar;
ALTER TABLE business_calendar DROP CONSTRAINT business_calendar_pkey;
DELETE FROM business_calendar;
ALTER TABLE business_calendar ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE business_calendar ADD PRIMARY KEY (org_id, date);

CREATE TRIGGER trg_business_calendar AFTER INSERT OR UPDATE OR DELETE ON org_work_hours
  FOR EACH STATEMENT EXECUTE FUNCTION business_calendar_rebuild();
CREATE TRIGGER trg_business_calendar AFTER INSERT OR UPDATE OR DELETE ON org_day_off
  FOR EACH STATEMENT EXECUTE FUNCTION business_calendar_rebuild();
-- prvý prepočet (spúšťače vyššie ešte neexistovali)
UPDATE org_work_hours SET work_from = work_from;

-- SLA podľa spoločnosti (predvolene Greenlogy a.s.)
DROP FUNCTION add_business_minutes(timestamptz, integer);
CREATE FUNCTION add_business_minutes(start timestamptz, minutes integer, p_org_id uuid DEFAULT NULL)
RETURNS timestamptz
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_org        uuid := coalesce(p_org_id, crm_default_org());
  v_tz         text := (SELECT o.timezone FROM org o WHERE o.id = coalesce(p_org_id, crm_default_org()));
  v_local      timestamp;
  v_remaining  numeric := minutes;
  v_from       timestamp;
  v_to         timestamp;
  v_available  numeric;
  r            record;
BEGIN
  IF minutes IS NULL OR minutes < 0 THEN
    RAISE EXCEPTION 'add_business_minutes: počet minút musí byť 0 alebo viac (zadané %)', minutes;
  END IF;
  v_local := start AT TIME ZONE v_tz;

  FOR r IN
    SELECT bc.date, bc.work_from, bc.work_to
      FROM business_calendar bc
     WHERE bc.org_id = v_org
       AND bc.date >= v_local::date
       AND bc.is_working_day
     ORDER BY bc.date
  LOOP
    v_from := greatest(v_local, r.date + r.work_from);
    v_to   := r.date + r.work_to;
    CONTINUE WHEN v_from >= v_to;

    v_available := extract(epoch FROM v_to - v_from) / 60;
    IF v_remaining <= v_available THEN
      RETURN (v_from + make_interval(mins => v_remaining::integer)) AT TIME ZONE v_tz;
    END IF;
    v_remaining := v_remaining - v_available;
  END LOOP;

  RAISE EXCEPTION 'add_business_minutes: business_calendar nepokrýva termín od % (+% min)', start, minutes;
END;
$$;

-- Kontrola pri nasadení: kalendár po prepočte = kalendár z 0002, SLA sedí.
DO $$
DECLARE
  tz constant text := 'Europe/Bratislava';
BEGIN
  ASSERT (SELECT count(*) FROM business_calendar) = 1096, 'kalendár 2026–2028 má mať 1 096 dní';
  ASSERT NOT EXISTS (
    (SELECT date, is_working_day, work_from, work_to, note FROM business_calendar
     EXCEPT SELECT * FROM business_calendar_0002)
    UNION ALL
    (SELECT * FROM business_calendar_0002
     EXCEPT SELECT date, is_working_day, work_from, work_to, note FROM business_calendar)
  ), 'prepočítaný kalendár sa líši od kalendára z 0002';
  ASSERT add_business_minutes(timestamp '2026-10-09 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-10-12 15:00' AT TIME ZONE tz, 'SLA: piatok 15:00 + 8 h';
  ASSERT add_business_minutes(timestamp '2026-12-23 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-12-28 15:00' AT TIME ZONE tz, 'SLA: cez Vianoce';
  ASSERT add_business_minutes(timestamp '2026-05-07 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-05-08 15:00' AT TIME ZONE tz, 'SLA: 8. 5. 2026 pracovný deň';
END;
$$;

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM company) OR EXISTS (SELECT 1 FROM contact) OR EXISTS (SELECT 1 FROM deal)
     OR EXISTS (SELECT 1 FROM app_user WHERE lower(email) NOT IN ('peter@greenlogy.com', 'eva@greenlogy.com')) THEN
    RAISE EXCEPTION 'Návrat 0006 vyžaduje prázdnu databázu (okrem východiskových údajov).';
  END IF;
END;
$$;

-- SLA a kalendár ako v 0002
DROP FUNCTION IF EXISTS add_business_minutes(timestamptz, integer, uuid);
DROP TRIGGER IF EXISTS trg_business_calendar ON org_day_off;
DROP TRIGGER IF EXISTS trg_business_calendar ON org_work_hours;
DELETE FROM business_calendar WHERE org_id <> crm_default_org();
ALTER TABLE business_calendar DROP CONSTRAINT business_calendar_pkey;
ALTER TABLE business_calendar DROP COLUMN org_id;
ALTER TABLE business_calendar ADD PRIMARY KEY (date);
COMMENT ON TABLE business_calendar IS 'pracovné dni a pracovný čas (Europe/Bratislava) pre výpočet SLA';
DROP FUNCTION IF EXISTS business_calendar_rebuild();

CREATE FUNCTION add_business_minutes(start timestamptz, minutes integer) RETURNS timestamptz
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_local      timestamp := start AT TIME ZONE 'Europe/Bratislava';
  v_remaining  numeric := minutes;
  v_from       timestamp;
  v_to         timestamp;
  v_available  numeric;
  r            record;
BEGIN
  IF minutes IS NULL OR minutes < 0 THEN
    RAISE EXCEPTION 'add_business_minutes: počet minút musí byť 0 alebo viac (zadané %)', minutes;
  END IF;

  FOR r IN
    SELECT bc.date, bc.work_from, bc.work_to
      FROM business_calendar bc
     WHERE bc.date >= v_local::date
       AND bc.is_working_day
     ORDER BY bc.date
  LOOP
    v_from := greatest(v_local, r.date + r.work_from);
    v_to   := r.date + r.work_to;
    CONTINUE WHEN v_from >= v_to;

    v_available := extract(epoch FROM v_to - v_from) / 60;
    IF v_remaining <= v_available THEN
      RETURN (v_from + make_interval(mins => v_remaining::integer)) AT TIME ZONE 'Europe/Bratislava';
    END IF;
    v_remaining := v_remaining - v_available;
  END LOOP;

  RAISE EXCEPTION 'add_business_minutes: business_calendar nepokrýva termín od % (+% min)', start, minutes;
END;
$$;

-- RLS Nastavení
DO $$
DECLARE
  t text;
  p record;
BEGIN
  FOR p IN SELECT tablename, policyname FROM pg_policies
            WHERE schemaname = 'public' AND policyname LIKE 'settings\_%' LOOP
    EXECUTE format('DROP POLICY %I ON %I', p.policyname, p.tablename);
  END LOOP;
  FOREACH t IN ARRAY ARRAY['org_logo', 'org_bank_account', 'team', 'team_permission',
                           'app_user', 'app_user_org', 'org_work_hours', 'org_day_off', 'org'] LOOP
    EXECUTE format('ALTER TABLE %I DISABLE ROW LEVEL SECURITY', t);
  END LOOP;
END;
$$;

-- Audit
DROP TABLE IF EXISTS export_log;
DROP TRIGGER IF EXISTS trg_protect_truncate ON audit_log;
DROP TRIGGER IF EXISTS trg_protect ON audit_log;
DROP FUNCTION IF EXISTS audit_log_protect();
DROP INDEX IF EXISTS audit_log_table_changed_at_idx;

CREATE OR REPLACE FUNCTION audit_row() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_old   jsonb;
  v_new   jsonb;
  v_diff  jsonb;
  v_id    uuid;
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
    SELECT jsonb_object_agg(n.key, jsonb_build_object('old', v_old -> n.key, 'new', n.value))
      INTO v_diff
      FROM jsonb_each(v_new) AS n
     WHERE n.key <> 'updated_at'
       AND n.value IS DISTINCT FROM v_old -> n.key;
    IF v_diff IS NULL THEN
      RETURN NEW;  -- nič sa nezmenilo
    END IF;
  END IF;

  INSERT INTO audit_log (table_name, record_id, action, changed_by, diff)
  VALUES (TG_TABLE_NAME, v_id, lower(TG_OP)::audit_action,
          nullif(current_setting('app.user_id', true), '')::uuid, v_diff);

  RETURN coalesce(NEW, OLD);
END;
$$;
ALTER TABLE audit_log DROP COLUMN source;
COMMENT ON COLUMN audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce; delete: pôvodný riadok';

-- Používatelia a tímy: východiskové údaje preč, pôvodná rola späť
DROP TRIGGER IF EXISTS trg_app_user_guard ON app_user;
DROP FUNCTION IF EXISTS app_user_guard();
DROP FUNCTION IF EXISTS app_user_deactivate(uuid, uuid);
DROP FUNCTION IF EXISTS app_user_login(text);
DELETE FROM app_user_org;
DELETE FROM app_user;
DROP TRIGGER IF EXISTS trg_team_external_guard ON team;
DROP TRIGGER IF EXISTS trg_team_external_guard ON team_permission;
DROP FUNCTION IF EXISTS team_external_guard();
DROP TRIGGER IF EXISTS trg_team_permission_init ON team;
DROP FUNCTION IF EXISTS team_permission_init();
DROP TABLE IF EXISTS team_permission;
DELETE FROM team;
DROP TABLE IF EXISTS app_user_org;

CREATE TYPE app_user_role AS ENUM ('admin', 'vedenie', 'obchodnik', 'servis', 'marketing', 'externy_obchodnik');
ALTER TABLE app_user
  DROP CONSTRAINT app_user_deactivated_check,
  DROP CONSTRAINT app_user_email_check,
  DROP CONSTRAINT app_user_name_check,
  ALTER COLUMN team_id DROP NOT NULL,
  DROP COLUMN deactivated_at,
  DROP COLUMN last_login_at,
  DROP COLUMN invited_at,
  DROP COLUMN is_admin,
  DROP COLUMN status,
  ADD COLUMN role app_user_role NOT NULL,
  ADD COLUMN active boolean NOT NULL DEFAULT true;

ALTER TABLE team
  DROP CONSTRAINT team_external_check,
  DROP CONSTRAINT team_code_key,
  DROP COLUMN archived_at,
  DROP COLUMN is_external,
  DROP COLUMN can_change_owner,
  DROP COLUMN all_orgs,
  DROP COLUMN description,
  DROP COLUMN code;

-- Funkcie práv z 0004
CREATE OR REPLACE FUNCTION crm_sees_all() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE
           WHEN crm_current_user_id() IS NULL
             THEN coalesce(current_setting('app.require_user', true), '') <> 'on'
           ELSE EXISTS (SELECT 1 FROM app_user u
                         WHERE u.id = crm_current_user_id()
                           AND u.active
                           AND u.role::text <> 'externy_obchodnik')
         END
$$;

CREATE OR REPLACE FUNCTION crm_external_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT u.id FROM app_user u
   WHERE u.id = crm_current_user_id()
     AND u.active
     AND u.role::text = 'externy_obchodnik'
$$;

CREATE OR REPLACE FUNCTION owner_change_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_role text;
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND current_user <> 'crm_sync' THEN
    SELECT u.role::text INTO v_role
      FROM app_user u
     WHERE u.id = nullif(current_setting('app.user_id', true), '')::uuid
       AND u.active;
    IF v_role IS NULL OR v_role NOT IN ('vedenie', 'admin') THEN
      RAISE EXCEPTION 'Vlastníka (obchodníka) môže zmeniť iba vedenie.'
        USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP FUNCTION IF EXISTS crm_external_ready();
DROP FUNCTION IF EXISTS crm_can_change_owner();
DROP FUNCTION IF EXISTS crm_scope(crm_module, text);
DROP FUNCTION IF EXISTS crm_user_orgs();
DROP FUNCTION IF EXISTS crm_settings_writer();
DROP FUNCTION IF EXISTS crm_is_admin();
DROP FUNCTION IF EXISTS crm_session_ok();
DROP FUNCTION IF EXISTS crm_active_user_id();
DROP FUNCTION IF EXISTS crm_is_service();
DROP FUNCTION IF EXISTS crm_require_user();

-- Pracovný čas a spoločnosti
DROP TABLE IF EXISTS org_day_off;
DROP TABLE IF EXISTS org_work_hours;
DROP TABLE IF EXISTS org_bank_account;
DROP FUNCTION IF EXISTS org_bank_account_normalize();
DROP TABLE IF EXISTS org_logo;
DROP FUNCTION IF EXISTS crm_default_org();
DROP TABLE IF EXISTS org;

DROP TYPE IF EXISTS audit_source;
DROP TYPE IF EXISTS day_off_kind;
DROP TYPE IF EXISTS user_status;
DROP TYPE IF EXISTS access_scope;
DROP TYPE IF EXISTS crm_module;
DROP TYPE IF EXISTS bank_account_purpose;
DROP TYPE IF EXISTS org_status;
DROP TYPE IF EXISTS country_code;
