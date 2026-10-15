-- migrate:up

-- 0032_obchod_jadro – modul 5, fáza F1 (návrh DB `05-obchod-navrh-db.md` časti 1.1–1.4, 1.8, 1.13–1.15 a 13.2):
-- systémové štádiá a pipelines, číselníky, obchod a jeho pravidlá, OOM a kontakty na obchode, časová os,
-- pridelenie firmy (schvaľovanie), upozornenie na ďalší krok, RLS obchodov.
-- Externí obchodníci = všetci predajcovia (Peter 15. 10.): obmedzuje sa iba rozsah dát („iba svoje“), nie funkcie.
--
-- „Kód databázy“ (crm_internal_call) = current_user je vlastník tabuliek: funkcia alebo spúšťač SECURITY DEFINER,
-- skript vlastníka. Aplikácia (crm_app) ho nastavením relácie nezíska.

-- ============================================================================
-- 0. Predpoklad: obchody, ponuky, provízie a pipelines sú prázdne
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM deal) OR EXISTS (SELECT 1 FROM deal_oom) OR EXISTS (SELECT 1 FROM deal_contact)
     OR EXISTS (SELECT 1 FROM offer) OR EXISTS (SELECT 1 FROM offer_item) OR EXISTS (SELECT 1 FROM commission)
     OR EXISTS (SELECT 1 FROM pipeline) OR EXISTS (SELECT 1 FROM pipeline_stage) THEN
    RAISE EXCEPTION 'Migrácia 0032 vyžaduje prázdne pipelines, dealy, ponuky a provízie.';
  END IF;
END;
$$;

CREATE FUNCTION crm_internal_call() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'deal'::regclass)
$$;
COMMENT ON FUNCTION crm_internal_call() IS 'true = beží kód databázy s právami vlastníka (funkcia / spúšťač SECURITY DEFINER, skript vlastníka), nie aplikácia ani iná rola';

-- ============================================================================
-- 1. Systémové štádiá a pipelines (časť 1.1)
-- ============================================================================

CREATE TYPE deal_stage_code AS ENUM ('prilezitost', 'cenova_ponuka', 'vyjednavanie', 'akceptacia', 'vyhrane', 'prehrane');

ALTER TABLE pipeline_stage
  ADD COLUMN code deal_stage_code,
  ADD CONSTRAINT pipeline_stage_code_outcome_check CHECK (
    CASE code
      WHEN 'vyhrane'  THEN outcome = 'vyhrany'
      WHEN 'prehrane' THEN outcome = 'prehrany'
      ELSE outcome = 'otvoreny'            -- systémové otvorené štádiá aj stage pridané adminom (bez logiky)
    END);
CREATE UNIQUE INDEX pipeline_stage_code_key ON pipeline_stage (pipeline_id, code) WHERE code IS NOT NULL;
COMMENT ON COLUMN pipeline_stage.code IS 'systémový kód štádia (logika obchodu); NULL = medzistupeň pridaný adminom';

CREATE FUNCTION pipeline_stage_code_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.code IS NOT NULL AND NOT crm_internal_call() THEN
      RAISE EXCEPTION 'Systémové štádiá zakladá iba databáza pri novej pipeline.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.code IS DISTINCT FROM OLD.code OR NEW.pipeline_id <> OLD.pipeline_id THEN
    RAISE EXCEPTION 'Kód štádia ani pipeline štádia sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.code IS NOT NULL AND NEW.archived_at IS NOT NULL THEN
    RAISE EXCEPTION 'Systémové štádium sa nedá archivovať (dá sa iba premenovať).' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_code_guard BEFORE INSERT OR UPDATE ON pipeline_stage
  FOR EACH ROW EXECUTE FUNCTION pipeline_stage_code_guard();

-- Nová pipeline dostane 6 systémových štádií (nahrádza „Nový, Vyhraný, Prehraný“ z API modulu 0)
CREATE FUNCTION pipeline_seed_stages() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  INSERT INTO pipeline_stage (pipeline_id, name, sort_order, probability, outcome, code) VALUES
    (NEW.id, 'Príležitosť',   1,  0.10, 'otvoreny', 'prilezitost'),
    (NEW.id, 'Cenová ponuka', 2,  0.30, 'otvoreny', 'cenova_ponuka'),
    (NEW.id, 'Vyjednávanie',  3,  0.50, 'otvoreny', 'vyjednavanie'),
    (NEW.id, 'Akceptácia',    4,  0.90, 'otvoreny', 'akceptacia'),
    (NEW.id, 'Vyhraté',       90, 1.00, 'vyhrany',  'vyhrane'),
    (NEW.id, 'Prehraté',      91, 0.00, 'prehrany', 'prehrane');
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_seed_stages AFTER INSERT ON pipeline
  FOR EACH ROW EXECUTE FUNCTION pipeline_seed_stages();

INSERT INTO pipeline (name, kind, org_id, sort_order) VALUES
  ('B2B dodávka',    'b2b_dodavka', NULL, 1),
  ('B2B výkup',      'b2b_vykup',   NULL, 2),
  ('Green VIWA B2B', 'green_viwa',  NULL, 3),
  ('B2C',            'b2c_dodavka', NULL, 4);

-- Skupina obchodu pre pravidlo „jedno OOM v jednom otvorenom obchode“ (rovnaká ako skupina OOM v zmluve)
CREATE FUNCTION deal_kind_group(p_kind deal_kind) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_kind IN ('b2b_vykup', 'green_viwa') THEN 'vykup_viwa' ELSE 'dodavka' END
$$;

-- ============================================================================
-- 2. Číselníky: dôvod prehry, zdroj obchodu (časť 1.1)
-- ============================================================================

INSERT INTO lookup_list (code, name, used_on) VALUES ('zdroj_obchodu', 'Zdroj obchodu', 'deal');

INSERT INTO lookup_value (list_code, code, label, sort_order, is_system) VALUES
  ('dovod_prehry', 'cena',                'Cena',                   1, false),
  ('dovod_prehry', 'zostal_u_dodavatela', 'Zostal u dodávateľa',    2, false),
  ('dovod_prehry', 'iny_dodavatel',       'Iný dodávateľ',          3, false),
  ('dovod_prehry', 'nereaguje',           'Nereaguje',              4, false),
  ('dovod_prehry', 'nesplnil_podmienky',  'Nesplnil podmienky',     5, false),
  ('dovod_prehry', 'ine',                 'Iné',                    99, true),   -- pri „iné“ povinná poznámka
  ('zdroj_obchodu', 'vlastny_kontakt',    'Vlastný kontakt',        1, false),
  ('zdroj_obchodu', 'web',                'Web',                    2, false),
  ('zdroj_obchodu', 'call_centrum',       'Call centrum',           3, false),
  ('zdroj_obchodu', 'odporucanie',        'Odporúčanie',            4, false),
  ('zdroj_obchodu', 'partner',            'Partner',                5, false),
  ('zdroj_obchodu', 'obnova',             'Obnova',                 6, true);    -- zakladá nočný beh (F5)

CREATE FUNCTION lookup_code_ok(p_list text, p_code text, p_org uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM lookup_value v
                  WHERE v.list_code = p_list AND v.code = p_code AND v.hidden_at IS NULL
                    AND (v.org_id IS NULL OR v.org_id = p_org))
$$;

-- ============================================================================
-- 3. Schvaľovanie pridelenia firmy – príznak používateľa (časť 1.8, odpoveď 6)
-- ============================================================================

ALTER TABLE app_user ADD COLUMN approves_assignments boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN app_user.approves_assignments IS 'schvaľuje pridelenie firmy (Peter Kalman, Daniel Dérer, Denis Kalman)';

CREATE FUNCTION crm_approves_assignments() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.approves_assignments)
$$;

-- app_user_guard: člen externého tímu nemôže schvaľovať ani pridelenie firmy (doplnené k 0006/0023)
CREATE OR REPLACE FUNCTION app_user_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_external boolean;
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT t.is_external INTO v_external FROM team t WHERE t.id = NEW.team_id;
    IF v_external AND NEW.is_admin THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže byť admin.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_external AND NEW.approves_prices THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže schvaľovať ceny.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_external AND NEW.approves_assignments THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže schvaľovať pridelenie firmy.' USING ERRCODE = 'check_violation';
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

UPDATE app_user SET approves_assignments = true
 WHERE lower(email) = 'peter@greenlogy.com'
    OR (lower(name) IN ('daniel dérer', 'daniel derer', 'denis kalman')
        AND NOT EXISTS (SELECT 1 FROM team t WHERE t.id = app_user.team_id AND t.is_external));

-- Vlastník zákazníka: okrem tímu CEO a admina ho smie nastaviť kód databázy pri obchode (zákazník bez vlastníka,
-- odpoveď 4) a pri schválenom pridelení firmy – iba s príznakom relácie a v privilegovanom kontexte.
CREATE OR REPLACE FUNCTION owner_change_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id AND current_user <> 'crm_sync'
     AND NOT crm_can_change_owner()
     AND NOT (crm_internal_call() AND coalesce(current_setting('app.owner_assign', true), '') = 'on') THEN
    RAISE EXCEPTION 'Vlastníka (obchodníka) môže zmeniť iba vedenie (tím CEO) alebo admin.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;

-- OOM na obchode: odhad objemov pre ponuku (pravidlá v časti 5)
ALTER TABLE deal_oom
  ADD COLUMN planned_vt_mwh      numeric(12,3) CHECK (planned_vt_mwh >= 0),
  ADD COLUMN planned_nt_mwh      numeric(12,3) CHECK (planned_nt_mwh >= 0),
  ADD COLUMN planned_feed_in_mwh numeric(12,3) CHECK (planned_feed_in_mwh >= 0),
  ADD COLUMN source_power_kw     numeric(12,3) CHECK (source_power_kw >= 0),
  ADD COLUMN org_id              uuid NOT NULL REFERENCES org (id);   -- (obchod, OOM) je unikátne už od 0001
CREATE INDEX deal_oom_oom_idx ON deal_oom (oom_id);
COMMENT ON COLUMN deal_oom.planned_vt_mwh IS 'odhad ročnej spotreby VT pre ponuku (predvyplní sa z OOM, XM Trade neprepisuje)';

-- ============================================================================
-- 4. Obchod (časť 1.2)
-- ============================================================================

ALTER TABLE deal
  DROP COLUMN source,
  DROP COLUMN lost_reason,
  DROP COLUMN campaign,
  ADD COLUMN source_code           text NOT NULL,
  ADD COLUMN lost_reason_code      text,
  ADD COLUMN lost_note             text,
  ADD COLUMN supply_start          date,
  ADD COLUMN next_step             text,
  ADD COLUMN next_step_on          date,
  ADD COLUMN next_step_notified_on date,
  ADD COLUMN previous_contract_id  uuid REFERENCES contract (id),
  ADD COLUMN estimated_value_eur   numeric(12,2),
  ADD COLUMN stage_changed_at      timestamptz NOT NULL DEFAULT now(),
  ADD COLUMN note                  text,
  ALTER COLUMN owner_id SET NOT NULL,
  ADD CONSTRAINT deal_name_check CHECK (btrim(name) <> ''),
  ADD CONSTRAINT deal_estimated_value_check CHECK (estimated_value_eur >= 0),
  ADD CONSTRAINT deal_next_step_check CHECK (next_step IS NULL OR btrim(next_step) <> ''),
  ADD CONSTRAINT deal_lost_note_check CHECK (lost_note IS NULL OR btrim(lost_note) <> '');
COMMENT ON COLUMN deal.source_code IS 'zdroj obchodu (číselník zdroj_obchodu)';
COMMENT ON COLUMN deal.lost_reason_code IS 'dôvod prehry (číselník dovod_prehry), iba v štádiu Prehraté';
COMMENT ON COLUMN deal.closed_at IS 'vstup do Vyhraté / Prehraté; NULL = otvorený obchod (nastavuje databáza)';
COMMENT ON COLUMN deal.next_step_notified_on IS 'deň kroku, za ktorý už odišlo upozornenie (nočný beh)';
COMMENT ON COLUMN deal.previous_contract_id IS 'predošlá zmluva (obnova)';
COMMENT ON COLUMN deal.estimated_value_eur IS 'odhad pridanej hodnoty pred prvou ponukou';

CREATE UNIQUE INDEX deal_open_renewal_key ON deal (previous_contract_id)
  WHERE closed_at IS NULL AND source_code = 'obnova';
CREATE INDEX deal_owner_idx ON deal (owner_id);
CREATE INDEX deal_company_idx ON deal (company_id) WHERE company_id IS NOT NULL;
CREATE INDEX deal_person_idx ON deal (person_id) WHERE person_id IS NOT NULL;
CREATE INDEX deal_next_step_idx ON deal (next_step_on) WHERE closed_at IS NULL;

-- Vlastník zákazníka a meno používateľa aj pre zákazníka, ktorého prihlásený nevidí (iba na kontroly a hlášky)
CREATE FUNCTION crm_customer_owner(p_company_id uuid, p_person_id uuid) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE WHEN p_company_id IS NOT NULL THEN (SELECT owner_id FROM company WHERE id = p_company_id)
              ELSE (SELECT owner_id FROM contact WHERE id = p_person_id) END
$$;
CREATE FUNCTION crm_user_name(p_user_id uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT name FROM app_user WHERE id = p_user_id
$$;

-- Môže meniť vlastníka obchodu a zakladať obchody aj na cudzích zákazníkoch: CEO / admin, „všetko“ v module
-- Obchod (obchodný riaditeľ v Sales_internal), schvaľovateľ cien alebo pridelenia.
CREATE FUNCTION crm_deal_manager() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_can_change_owner() OR crm_scope('obchod', 'edit') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
$$;

-- Sú OOM obchodu pripravené na ponuku: aspoň jedno, každé s plánovanou spotrebou (dodávka) alebo výrobou / výkonom
CREATE FUNCTION deal_oom_ready(p_deal_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM deal_oom WHERE deal_id = p_deal_id)
     AND NOT EXISTS (
       SELECT 1 FROM deal_oom o
         JOIN deal d ON d.id = o.deal_id
         JOIN pipeline p ON p.id = d.pipeline_id
        WHERE o.deal_id = p_deal_id
          AND CASE deal_kind_group(p.kind)
                WHEN 'dodavka' THEN coalesce(o.planned_vt_mwh, 0) + coalesce(o.planned_nt_mwh, 0) <= 0
                ELSE coalesce(o.planned_feed_in_mwh, 0) <= 0 AND coalesce(o.source_power_kw, 0) <= 0
              END)
$$;

CREATE FUNCTION deal_stage_needs_oom(p_code deal_stage_code) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT p_code IN ('cenova_ponuka', 'vyjednavanie', 'akceptacia', 'vyhrane')
$$;

-- Pravidlá obchodu (BEFORE, s právami volajúceho – aby sa dal rozlíšiť kód databázy od aplikácie)
CREATE FUNCTION deal_rules() RETURNS trigger
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
CREATE TRIGGER trg_rules BEFORE INSERT OR UPDATE ON deal   -- názov po trg_record_org (spoločnosť už je vyplnená)
  FOR EACH ROW EXECUTE FUNCTION deal_rules();

-- Znovuotvorenie (odpoveď 2): Prehraté vlastník obchodu alebo admin, Vyhraté iba admin; vždy s dôvodom → Príležitosť
CREATE FUNCTION deal_reopen(p_deal_id uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d       deal;
  v_code  deal_stage_code;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal_id FOR UPDATE;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Obchod neexistuje alebo ho nevidíte.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod znovuotvorenia.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT code INTO v_code FROM pipeline_stage WHERE id = d.stage_id;
  IF v_code = 'prehrane' THEN
    IF NOT (d.owner_id = crm_active_user_id() OR crm_is_admin()) THEN
      RAISE EXCEPTION 'Prehratý obchod znova otvorí iba jeho vlastník alebo admin.' USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSIF v_code = 'vyhrane' THEN
    IF NOT crm_is_admin() THEN
      RAISE EXCEPTION 'Vyhratý obchod znova otvorí iba admin.' USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSE
    RAISE EXCEPTION 'Obchod je otvorený.' USING ERRCODE = 'check_violation';
  END IF;

  PERFORM set_config('app.deal_reopen', d.id::text, true);
  PERFORM set_config('app.deal_reopen_reason', btrim(p_reason), true);
  UPDATE deal SET stage_id = (SELECT id FROM pipeline_stage WHERE pipeline_id = d.pipeline_id AND code = 'prilezitost')
   WHERE id = d.id;
  PERFORM set_config('app.deal_reopen', '', true);
  PERFORM set_config('app.deal_reopen_reason', '', true);
END;
$$;

-- ============================================================================
-- 5. OOM na obchode, kontakty, pôvod OOM (časti 1.3, 1.4)
-- ============================================================================

ALTER TABLE oom ADD COLUMN created_from_deal_id uuid REFERENCES deal (id);
COMMENT ON COLUMN oom.created_from_deal_id IS 'OOM vzniklo pri obchode (pri prehre sa zruší, ak nie je inde)';

-- Obnova k zmluve, na ktorej OOM je (výnimka z pravidla jedného otvoreného obchodu, odpoveď 5)
CREATE FUNCTION deal_is_renewal_of(p_deal_id uuid, p_oom_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM deal d JOIN contract_oom k ON k.contract_id = d.previous_contract_id
                  WHERE d.id = p_deal_id AND d.source_code = 'obnova' AND k.oom_id = p_oom_id)
$$;

-- Iný otvorený obchod rovnakej skupiny s týmto OOM (aj taký, ktorý prihlásený nevidí); Obnova k zmluve OOM sa nepočíta
CREATE FUNCTION deal_oom_conflict(p_deal_id uuid, p_oom_id uuid) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT x.owner_id
    FROM deal d JOIN pipeline p ON p.id = d.pipeline_id,
         deal_oom dx JOIN deal x ON x.id = dx.deal_id JOIN pipeline px ON px.id = x.pipeline_id
   WHERE d.id = p_deal_id AND dx.oom_id = p_oom_id AND x.id <> d.id AND x.closed_at IS NULL
     AND deal_kind_group(px.kind) = deal_kind_group(p.kind)
     AND NOT deal_is_renewal_of(x.id, p_oom_id)
     AND NOT deal_is_renewal_of(d.id, p_oom_id)
   LIMIT 1
$$;

-- Pravidlá OOM na obchode (s právami volajúceho: aplikácia vs. kód databázy)
CREATE FUNCTION deal_oom_rules() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  d        deal;
  o        oom;
  v_other  uuid;
  v_app    boolean := NOT (crm_internal_call() OR current_user = 'crm_sync');
BEGIN
  SELECT * INTO d FROM deal WHERE id = coalesce(NEW.deal_id, OLD.deal_id);
  IF v_app AND d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'OOM uzavretého obchodu sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND (NEW.deal_id <> OLD.deal_id OR NEW.oom_id <> OLD.oom_id) THEN
    RAISE EXCEPTION 'Väzba OOM na obchode sa nemení – odoberte ju a pridajte znova.' USING ERRCODE = 'check_violation';
  END IF;

  SELECT * INTO o FROM oom WHERE id = NEW.oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'OOM neexistuje alebo ho nevidíte.' USING ERRCODE = 'no_data_found';
  END IF;
  NEW.org_id := d.org_id;
  IF o.org_id <> d.org_id THEN
    RAISE EXCEPTION 'OOM patrí inej spoločnosti ako obchod.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    IF v_app AND o.status NOT IN ('pripravovane', 'aktivne') THEN
      RAISE EXCEPTION 'Do obchodu sa dá pridať iba Pripravované alebo Aktívne OOM.' USING ERRCODE = 'check_violation';
    END IF;
    NEW.planned_vt_mwh      := coalesce(NEW.planned_vt_mwh, o.planned_consumption_vt_mwh);
    NEW.planned_nt_mwh      := coalesce(NEW.planned_nt_mwh, o.planned_consumption_nt_mwh);
    NEW.planned_feed_in_mwh := coalesce(NEW.planned_feed_in_mwh, o.planned_feed_in_mwh);
    NEW.source_power_kw     := coalesce(NEW.source_power_kw, o.source_power_kw);

    -- jedno OOM najviac v jednom otvorenom obchode rovnakej skupiny; výnimka Obnova k zmluve, na ktorej OOM je
    IF d.closed_at IS NULL THEN
      v_other := deal_oom_conflict(d.id, NEW.oom_id);
      IF v_other IS NOT NULL THEN
        RAISE EXCEPTION 'OOM už je v inom otvorenom obchode (vlastník %).', crm_user_name(v_other)
          USING ERRCODE = 'check_violation';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_deal_oom_rules BEFORE INSERT OR UPDATE OR DELETE ON deal_oom
  FOR EACH ROW EXECUTE FUNCTION deal_oom_rules();

-- Po zmene OOM: obchod v štádiu Cenová ponuka a ďalej musí mať OOM s objemami
CREATE FUNCTION deal_oom_ready_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_id   uuid := coalesce(NEW.deal_id, OLD.deal_id);
  v_code deal_stage_code;
BEGIN
  SELECT s.code INTO v_code FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE d.id = v_id AND d.closed_at IS NULL;
  IF deal_stage_needs_oom(v_code) AND NOT deal_oom_ready(v_id) THEN
    RAISE EXCEPTION 'Obchod v štádiu ponuky musí mať aspoň jedno OOM a pri každom plánovanú spotrebu (pri výkupe výrobu alebo výkon).'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_deal_oom_ready AFTER INSERT OR UPDATE OR DELETE ON deal_oom
  FOR EACH ROW EXECUTE FUNCTION deal_oom_ready_check();

-- OOM založené pri obchode: obchod je otvorený, zákazník OOM = zákazník obchodu; pôvod sa potom nemení
CREATE FUNCTION oom_created_from_deal_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d deal;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.created_from_deal_id IS DISTINCT FROM OLD.created_from_deal_id THEN
    RAISE EXCEPTION 'Pôvod OOM (obchod) sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' AND NEW.created_from_deal_id IS NOT NULL THEN
    SELECT * INTO d FROM deal WHERE id = NEW.created_from_deal_id;
    IF d.closed_at IS NOT NULL OR (d.company_id, d.person_id) IS DISTINCT FROM (NEW.company_id, NEW.person_id) THEN
      RAISE EXCEPTION 'OOM z obchodu musí patriť zákazníkovi otvoreného obchodu.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_created_from_deal BEFORE INSERT OR UPDATE OF created_from_deal_id ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_created_from_deal_check();

ALTER TABLE deal_contact
  DROP COLUMN role,
  ADD COLUMN roles      text[] NOT NULL DEFAULT '{}',
  ADD COLUMN is_primary boolean NOT NULL DEFAULT false;   -- (obchod, kontakt) je unikátne už od 0001
CREATE UNIQUE INDEX deal_contact_primary_key ON deal_contact (deal_id) WHERE is_primary;
COMMENT ON COLUMN deal_contact.roles IS 'kódy z číselníka rola_kontaktu';
COMMENT ON COLUMN deal_contact.is_primary IS 'primárny kontakt = predvolená kontaktná osoba ponuky';

CREATE FUNCTION deal_contact_roles_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r     text;
  v_org uuid := (SELECT org_id FROM deal WHERE id = NEW.deal_id);
BEGIN
  FOREACH r IN ARRAY NEW.roles LOOP
    IF NOT lookup_code_ok('rola_kontaktu', r, v_org)
       AND (TG_OP = 'INSERT' OR NOT r = ANY (OLD.roles)) THEN
      RAISE EXCEPTION 'Neznáma rola kontaktu.' USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_roles_check BEFORE INSERT OR UPDATE OF roles ON deal_contact
  FOR EACH ROW EXECUTE FUNCTION deal_contact_roles_check();

-- ============================================================================
-- 6. Časová os obchodu (časť 1.13)
-- ============================================================================

CREATE TABLE deal_event (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL REFERENCES deal (id) ON DELETE CASCADE,
  org_id      uuid NOT NULL REFERENCES org (id),
  kind        text NOT NULL CHECK (kind IN (
                'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
                'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik')),
  occurred_at timestamptz NOT NULL DEFAULT now(),
  user_id     uuid REFERENCES app_user (id),         -- NULL = systém
  from_stage_id uuid REFERENCES pipeline_stage (id),
  to_stage_id   uuid REFERENCES pipeline_stage (id),
  oom_id      uuid REFERENCES oom (id),
  contact_id  uuid REFERENCES contact (id),
  detail      jsonb NOT NULL DEFAULT '{}',           -- bez osobných údajov (id, kódy)
  reason      text                                   -- dôvod znovuotvorenia (zadal používateľ)
);
CREATE INDEX deal_event_deal_idx ON deal_event (deal_id, occurred_at);
COMMENT ON TABLE deal_event IS 'časová os obchodu: udalosti, ktoré nie sú poznámka ani e-mail; zapisujú ich iba spúšťače, nemení sa';

CREATE FUNCTION deal_event_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'Udalosti časovej osi sa nemenia ani nemažú.' USING ERRCODE = 'check_violation';
END;
$$;
CREATE TRIGGER trg_guard BEFORE UPDATE ON deal_event FOR EACH ROW EXECUTE FUNCTION deal_event_guard();

CREATE FUNCTION deal_events() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_user uuid := crm_current_user_id();
  v_reason text := nullif(current_setting('app.deal_reopen_reason', true), '');
  v_code deal_stage_code;
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, to_stage_id, detail)
    VALUES (NEW.id, NEW.org_id, 'zalozenie', v_user, NEW.stage_id, jsonb_build_object('owner_id', NEW.owner_id));
    RETURN NULL;
  END IF;
  IF NEW.stage_id <> OLD.stage_id THEN
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, from_stage_id, to_stage_id, detail, reason)
    VALUES (NEW.id, NEW.org_id,
            CASE WHEN current_setting('app.deal_reopen', true) = NEW.id::text THEN 'znovuotvorenie' ELSE 'stadium' END,
            v_user, OLD.stage_id, NEW.stage_id,
            jsonb_strip_nulls(jsonb_build_object('lost_reason_code', NEW.lost_reason_code)),
            CASE WHEN current_setting('app.deal_reopen', true) = NEW.id::text THEN v_reason END);
  END IF;
  IF NEW.owner_id <> OLD.owner_id THEN
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, detail)
    VALUES (NEW.id, NEW.org_id, 'vlastnik', v_user, jsonb_build_object('from', OLD.owner_id, 'to', NEW.owner_id));
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_events AFTER INSERT OR UPDATE ON deal FOR EACH ROW EXECUTE FUNCTION deal_events();

CREATE FUNCTION deal_link_events() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r      record := coalesce(NEW, OLD);
  v_org  uuid := (SELECT org_id FROM deal WHERE id = r.deal_id);
BEGIN
  IF v_org IS NULL THEN
    RETURN NULL;   -- obchod sa práve maže (kaskáda)
  END IF;
  IF TG_TABLE_NAME = 'deal_oom' THEN
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, oom_id)
    VALUES (r.deal_id, v_org, CASE TG_OP WHEN 'INSERT' THEN 'oom_pridane' ELSE 'oom_odobrane' END,
            crm_current_user_id(), r.oom_id);
  ELSE
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, contact_id)
    VALUES (r.deal_id, v_org, CASE TG_OP WHEN 'INSERT' THEN 'kontakt_pridany' ELSE 'kontakt_odobrany' END,
            crm_current_user_id(), r.contact_id);
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_events AFTER INSERT OR DELETE ON deal_oom FOR EACH ROW EXECUTE FUNCTION deal_link_events();
CREATE TRIGGER trg_events AFTER INSERT OR DELETE ON deal_contact FOR EACH ROW EXECUTE FUNCTION deal_link_events();

-- ============================================================================
-- 7. Po zmene obchodu: vlastník zákazníka bez vlastníka, OOM pri prehre, stav zákazníka
-- ============================================================================

CREATE FUNCTION deal_after_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_code  deal_stage_code;
  v_oom   record;
BEGIN
  -- zákazník bez vlastníka → vlastník obchodu (odpoveď 4)
  IF TG_OP = 'INSERT' OR (NEW.company_id, NEW.person_id, NEW.owner_id) IS DISTINCT FROM (OLD.company_id, OLD.person_id, OLD.owner_id) THEN
    IF crm_customer_owner(NEW.company_id, NEW.person_id) IS NULL THEN
      PERFORM set_config('app.owner_assign', 'on', true);
      IF NEW.company_id IS NOT NULL THEN
        UPDATE company SET owner_id = NEW.owner_id WHERE id = NEW.company_id AND owner_id IS NULL;
      ELSE
        UPDATE contact SET owner_id = NEW.owner_id WHERE id = NEW.person_id AND owner_id IS NULL;
      END IF;
      PERFORM set_config('app.owner_assign', '', true);
      INSERT INTO deal_event (deal_id, org_id, kind, user_id, detail)
      VALUES (NEW.id, NEW.org_id, 'zakaznik_vlastnik', crm_current_user_id(), jsonb_build_object('owner_id', NEW.owner_id));
    END IF;
  END IF;

  -- prehra: OOM z tohto obchodu bez zmluvy a bez iného otvoreného obchodu → Zrušené (odpoveď 1)
  IF TG_OP = 'UPDATE' AND NEW.stage_id <> OLD.stage_id THEN
    SELECT code INTO v_code FROM pipeline_stage WHERE id = NEW.stage_id;
    IF v_code = 'prehrane' THEN
      FOR v_oom IN
        SELECT o.id FROM oom o
         WHERE o.created_from_deal_id = NEW.id AND o.status = 'pripravovane'
           AND NOT EXISTS (SELECT 1 FROM contract_oom k WHERE k.oom_id = o.id)
           AND NOT EXISTS (SELECT 1 FROM deal_oom x JOIN deal y ON y.id = x.deal_id
                            WHERE x.oom_id = o.id AND y.id <> NEW.id AND y.closed_at IS NULL)
      LOOP
        BEGIN
          PERFORM oom_set_status(v_oom.id, 'zrusene');
          INSERT INTO deal_event (deal_id, org_id, kind, user_id, oom_id, detail)
          VALUES (NEW.id, NEW.org_id, 'oom_zrusene', crm_current_user_id(), v_oom.id, '{"dovod": "obchod prehraný"}');
        EXCEPTION WHEN check_violation THEN
          -- napr. naplánovaná zmena OOM: OOM ostane, v časovej osi je dôvod
          INSERT INTO deal_event (deal_id, org_id, kind, user_id, oom_id, detail)
          VALUES (NEW.id, NEW.org_id, 'oom_nezrusene', crm_current_user_id(), v_oom.id,
                  jsonb_build_object('dovod', SQLERRM));
        END;
      END LOOP;
    END IF;
  END IF;

  -- stav zákazníka (Záujemca) podľa otvorených obchodov
  IF crm_setting_on('customer_status_auto')
     AND (TG_OP = 'INSERT' OR NEW.stage_id <> OLD.stage_id
          OR (NEW.company_id, NEW.person_id) IS DISTINCT FROM (OLD.company_id, OLD.person_id)) THEN
    PERFORM customer_refresh(NEW.company_id, NEW.person_id);
    IF TG_OP = 'UPDATE' AND (NEW.company_id, NEW.person_id) IS DISTINCT FROM (OLD.company_id, OLD.person_id) THEN
      PERFORM customer_refresh(OLD.company_id, OLD.person_id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_after_change AFTER INSERT OR UPDATE ON deal FOR EACH ROW EXECUTE FUNCTION deal_after_change();

-- ============================================================================
-- 8. RLS obchodov (časť 1.15; Peter 15. 10.: Sales_external = všetci obchodníci, „iba svoje“ = vlastné obchody
--    a obchody na zákazníkoch, ktorých sú vlastníkom; Sales_internal, Servis, Nákup podľa matice práv)
-- ============================================================================

CREATE FUNCTION crm_deal_visible(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_scope('obchod', 'view') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
      OR (crm_scope('obchod', 'view') = 'iba_svoje'
          AND (p_owner_id = crm_active_user_id() OR crm_customer_owned(p_company_id, p_person_id)))
$$;
CREATE FUNCTION crm_deal_editable(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_scope('obchod', 'edit') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
      OR (crm_scope('obchod', 'edit') = 'iba_svoje'
          AND (p_owner_id = crm_active_user_id() OR crm_customer_owned(p_company_id, p_person_id)))
$$;

ALTER TABLE deal ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_oom ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE deal_event ENABLE ROW LEVEL SECURITY;

CREATE POLICY deal_select ON deal FOR SELECT
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_deal_visible(company_id, person_id, owner_id));
CREATE POLICY deal_insert ON deal FOR INSERT
  WITH CHECK (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_deal_editable(company_id, person_id, owner_id));
CREATE POLICY deal_update ON deal FOR UPDATE
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_deal_editable(company_id, person_id, owner_id))
  WITH CHECK (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_deal_editable(company_id, person_id, owner_id));

CREATE POLICY deal_oom_select ON deal_oom FOR SELECT USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id));
CREATE POLICY deal_oom_write ON deal_oom FOR ALL
  USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)));
CREATE POLICY deal_contact_select ON deal_contact FOR SELECT USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id));
CREATE POLICY deal_contact_write ON deal_contact FOR ALL
  USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)));
CREATE POLICY deal_event_select ON deal_event FOR SELECT USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id));

-- ============================================================================
-- 9. Schvaľovanie – pridelenie firmy (časť 1.8; ostatné druhy v F2)
-- ============================================================================

CREATE TYPE approval_kind AS ENUM ('vynimka_ceny', 'rizikovy_zakaznik', 'predlzenie_platnosti', 'pridelenie_firmy');
CREATE TYPE approval_status AS ENUM ('caka', 'schvalena', 'zamietnuta', 'zrusena');

CREATE TABLE approval_request (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        uuid NOT NULL REFERENCES org (id),
  kind          approval_kind NOT NULL,
  deal_id       uuid REFERENCES deal (id),
  company_id    uuid REFERENCES company (id),
  from_owner_id uuid REFERENCES app_user (id),      -- pridelenie: pôvodný vlastník
  reason        text NOT NULL CHECK (btrim(reason) <> ''),
  requested_by  uuid NOT NULL REFERENCES app_user (id),
  status        approval_status NOT NULL DEFAULT 'caka',
  decided_by    uuid REFERENCES app_user (id),
  decided_at    timestamptz,
  decision_note text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT approval_request_decided_check CHECK ((status IN ('schvalena', 'zamietnuta')) = (decided_at IS NOT NULL)),
  CONSTRAINT approval_request_self_check CHECK (decided_by IS NULL OR decided_by <> requested_by),
  CONSTRAINT approval_request_assign_check CHECK (kind <> 'pridelenie_firmy' OR (company_id IS NOT NULL AND from_owner_id IS NOT NULL))
);
CREATE UNIQUE INDEX approval_request_pending_assign_key ON approval_request (company_id, requested_by)
  WHERE kind = 'pridelenie_firmy' AND status = 'caka';
COMMENT ON TABLE approval_request IS 'schvaľovanie: výnimka z ceny, rizikový zákazník, predĺženie platnosti, pridelenie firmy (obrazovka 39)';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON approval_request FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON approval_request FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE approval_request ENABLE ROW LEVEL SECURITY;
CREATE POLICY approval_request_select ON approval_request FOR SELECT
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[])
         AND (crm_is_service() OR crm_is_admin()
              OR requested_by = crm_active_user_id() OR from_owner_id = crm_active_user_id()
              OR (kind = 'pridelenie_firmy' AND crm_approves_assignments())
              OR (kind <> 'pridelenie_firmy' AND crm_approves_prices())));

-- Upozornenia: väzby na obchod a žiadosť, nové druhy
ALTER TABLE notification
  ADD COLUMN deal_id     uuid REFERENCES deal (id) ON DELETE CASCADE,
  ADD COLUMN approval_id uuid REFERENCES approval_request (id) ON DELETE CASCADE,
  DROP CONSTRAINT notification_kind_check,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm',
    'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy'));

CREATE FUNCTION notification_add_deal(p_users uuid[], p_kind text, p_deal_id uuid, p_approval_id uuid,
                                      p_ref_date date, p_detail text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_n integer;
BEGIN
  INSERT INTO notification (user_id, kind, deal_id, approval_id, ref_date, detail)
  SELECT DISTINCT u, p_kind, p_deal_id, p_approval_id, p_ref_date, p_detail
    FROM unnest(coalesce(p_users, '{}')) AS u
   WHERE u IS NOT NULL AND EXISTS (SELECT 1 FROM app_user a WHERE a.id = u AND a.status <> 'deaktivovany');
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;
REVOKE EXECUTE ON FUNCTION notification_add_deal(uuid[], text, uuid, uuid, date, text) FROM PUBLIC;

CREATE FUNCTION notification_assign_approvers(p_org uuid) RETURNS uuid[]
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(array_agg(u.id ORDER BY u.id), '{}')
    FROM app_user u
   WHERE u.status <> 'deaktivovany' AND u.approves_assignments AND crm_user_sees_org(u.id, p_org)
$$;

-- Žiadosť o pridelenie firmy (obchodník, ktorý firmu nevlastní)
CREATE FUNCTION approval_request_assign(p_company_id uuid, p_reason text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c      company;
  v_user uuid := crm_active_user_id();
  v_id   uuid;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Žiadosť zakladá prihlásený používateľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO c FROM company WHERE id = p_company_id;
  IF NOT FOUND OR NOT c.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Firma neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF c.owner_id IS NULL THEN
    RAISE EXCEPTION 'Firma nemá vlastníka – založte na nej obchod, stanete sa vlastníkom.' USING ERRCODE = 'check_violation';
  END IF;
  IF c.owner_id = v_user THEN
    RAISE EXCEPTION 'Firmu už vlastníte.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod žiadosti.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM approval_request WHERE company_id = c.id AND requested_by = v_user
                                              AND kind = 'pridelenie_firmy' AND status = 'caka') THEN
    RAISE EXCEPTION 'Žiadosť o pridelenie tejto firmy už čaká na schválenie.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO approval_request (org_id, kind, company_id, from_owner_id, reason, requested_by)
  VALUES (c.org_id, 'pridelenie_firmy', c.id, c.owner_id, btrim(p_reason), v_user)
  RETURNING id INTO v_id;
  PERFORM notification_add_deal(array_remove(notification_assign_approvers(c.org_id), v_user),
                                'schvalenie_nove', NULL, v_id, NULL, 'Žiadosť o pridelenie firmy');
  RETURN v_id;
END;
$$;

-- Rozhodnutie o žiadosti. Pridelenie: iba „schvaľuje pridelenie firmy“; ostatné druhy (F2): „schvaľuje ceny“.
CREATE FUNCTION approval_decide(p_id uuid, p_approve boolean, p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a      approval_request;
  v_user uuid := crm_active_user_id();
BEGIN
  SELECT * INTO a FROM approval_request WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT a.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Žiadosť neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF a.status <> 'caka' THEN
    RAISE EXCEPTION 'Žiadosť už je vybavená.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_user IS NULL OR NOT (CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END) THEN
    RAISE EXCEPTION 'Túto žiadosť nemôžete schváliť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF a.requested_by = v_user THEN
    RAISE EXCEPTION 'Vlastnú žiadosť schváliť nemožno.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_approve IS NULL THEN
    RAISE EXCEPTION 'Chýba rozhodnutie.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT p_approve AND (p_note IS NULL OR btrim(p_note) = '') THEN
    RAISE EXCEPTION 'Pri zamietnutí zadajte poznámku.' USING ERRCODE = 'check_violation';
  END IF;
  IF a.kind <> 'pridelenie_firmy' THEN
    RAISE EXCEPTION 'Tento druh žiadosti sa schvaľuje až s ponukami (F2).' USING ERRCODE = 'feature_not_supported';
  END IF;

  IF p_approve THEN
    IF (SELECT owner_id FROM company WHERE id = a.company_id) IS DISTINCT FROM a.from_owner_id THEN
      RAISE EXCEPTION 'Vlastník firmy sa medzitým zmenil – žiadosť zamietnite alebo nech žiadateľ požiada znova.'
        USING ERRCODE = 'check_violation';
    END IF;
    PERFORM set_config('app.owner_assign', 'on', true);
    UPDATE company SET owner_id = a.requested_by WHERE id = a.company_id;
    PERFORM set_config('app.owner_assign', '', true);
  END IF;

  UPDATE approval_request
     SET status = CASE WHEN p_approve THEN 'schvalena' ELSE 'zamietnuta' END::approval_status,
         decided_by = v_user, decided_at = now(), decision_note = nullif(btrim(p_note), '')
   WHERE id = a.id;

  PERFORM notification_add_deal(ARRAY[a.requested_by], 'schvalenie_rozhodnutie', NULL, a.id, NULL,
          CASE WHEN p_approve THEN 'Pridelenie firmy schválené' ELSE 'Pridelenie firmy zamietnuté' END);
  IF p_approve THEN
    PERFORM notification_add_deal(ARRAY[a.from_owner_id], 'pridelenie_firmy', NULL, a.id, NULL,
                                  'Firma bola pridelená inému obchodníkovi');
  END IF;
END;
$$;

-- Žiadateľ svoju čakajúcu žiadosť zruší
CREATE FUNCTION approval_cancel(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE approval_request SET status = 'zrusena'
   WHERE id = p_id AND status = 'caka' AND requested_by = crm_active_user_id();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zrušiť môžete iba vlastnú čakajúcu žiadosť.' USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

-- ============================================================================
-- 10. Nočný beh obchodov: upozornenie v deň ďalšieho kroku (časť 1.2)
-- ============================================================================

ALTER TABLE job_run
  DROP CONSTRAINT job_run_job_check,
  ADD CONSTRAINT job_run_job_check CHECK (job IN ('zmluvy', 'obchody'));

CREATE FUNCTION deal_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_prev text := crm_as_system(true);
  r      record;
BEGIN
  INSERT INTO job_run (job, run_date, test_date) VALUES ('obchody', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;
  -- deň kroku (dobieha 7 dní, keby beh vypadol); raz pre každý dátum kroku
  FOR r IN
    SELECT d.id, d.owner_id, d.next_step_on FROM deal d
     WHERE d.closed_at IS NULL AND d.next_step_on BETWEEN p_today - 7 AND p_today
       AND d.next_step_notified_on IS DISTINCT FROM d.next_step_on
     ORDER BY d.id
  LOOP
    PERFORM notification_add_deal(ARRAY[r.owner_id], 'dalsi_krok', r.id, NULL, r.next_step_on, 'Ďalší krok obchodu');
    UPDATE deal SET next_step_notified_on = r.next_step_on WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n);
END;
$$;
CREATE FUNCTION deal_daily_run() RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT deal_daily_run_at(crm_today())
$$;
REVOKE EXECUTE ON FUNCTION deal_daily_run_at(date) FROM PUBLIC;

-- migrate:down

DROP FUNCTION IF EXISTS deal_daily_run();
DROP FUNCTION IF EXISTS deal_daily_run_at(date);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM job_run WHERE job = 'obchody') THEN
    DELETE FROM job_run WHERE job = 'obchody';
  END IF;
END;
$$;
ALTER TABLE job_run
  DROP CONSTRAINT job_run_job_check,
  ADD CONSTRAINT job_run_job_check CHECK (job = 'zmluvy');

DROP FUNCTION IF EXISTS approval_cancel(uuid);
DROP FUNCTION IF EXISTS approval_decide(uuid, boolean, text);
DROP FUNCTION IF EXISTS approval_request_assign(uuid, text);
DROP FUNCTION IF EXISTS notification_assign_approvers(uuid);
DROP FUNCTION IF EXISTS notification_add_deal(uuid[], text, uuid, uuid, date, text);
DELETE FROM notification WHERE deal_id IS NOT NULL OR approval_id IS NOT NULL
   OR kind IN ('dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy');
ALTER TABLE notification
  DROP CONSTRAINT notification_kind_check,
  DROP COLUMN approval_id,
  DROP COLUMN deal_id,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm'));
DROP TABLE IF EXISTS approval_request;
DROP TYPE IF EXISTS approval_status;
DROP TYPE IF EXISTS approval_kind;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM deal) THEN
    RAISE EXCEPTION 'Návrat 0032 vyžaduje prázdne dealy.';
  END IF;
END;
$$;

DROP POLICY IF EXISTS deal_event_select ON deal_event;
DROP POLICY IF EXISTS deal_contact_write ON deal_contact;
DROP POLICY IF EXISTS deal_contact_select ON deal_contact;
DROP POLICY IF EXISTS deal_oom_write ON deal_oom;
DROP POLICY IF EXISTS deal_oom_select ON deal_oom;
DROP POLICY IF EXISTS deal_update ON deal;
DROP POLICY IF EXISTS deal_insert ON deal;
DROP POLICY IF EXISTS deal_select ON deal;
ALTER TABLE deal DISABLE ROW LEVEL SECURITY;
ALTER TABLE deal_oom DISABLE ROW LEVEL SECURITY;
ALTER TABLE deal_contact DISABLE ROW LEVEL SECURITY;
DROP FUNCTION IF EXISTS crm_deal_editable(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS crm_deal_visible(uuid, uuid, uuid);

DROP TRIGGER IF EXISTS trg_after_change ON deal;
DROP FUNCTION IF EXISTS deal_after_change();
DROP TRIGGER IF EXISTS trg_events ON deal_contact;
DROP TRIGGER IF EXISTS trg_events ON deal_oom;
DROP TRIGGER IF EXISTS trg_events ON deal;
DROP FUNCTION IF EXISTS deal_link_events();
DROP FUNCTION IF EXISTS deal_events();
DROP TABLE IF EXISTS deal_event;
DROP FUNCTION IF EXISTS deal_event_guard();

DROP TRIGGER IF EXISTS trg_roles_check ON deal_contact;
DROP FUNCTION IF EXISTS deal_contact_roles_check();
DROP INDEX IF EXISTS deal_contact_primary_key;
ALTER TABLE deal_contact
  DROP COLUMN is_primary,
  DROP COLUMN roles,
  ADD COLUMN role text;

DROP TRIGGER IF EXISTS trg_created_from_deal ON oom;
DROP FUNCTION IF EXISTS oom_created_from_deal_check();
DROP TRIGGER IF EXISTS trg_deal_oom_ready ON deal_oom;
DROP FUNCTION IF EXISTS deal_oom_ready_check();
DROP TRIGGER IF EXISTS trg_deal_oom_rules ON deal_oom;
DROP FUNCTION IF EXISTS deal_oom_rules();
DROP FUNCTION IF EXISTS deal_oom_conflict(uuid, uuid);
DROP FUNCTION IF EXISTS deal_is_renewal_of(uuid, uuid);
ALTER TABLE oom DROP COLUMN created_from_deal_id;
DROP INDEX IF EXISTS deal_oom_oom_idx;
ALTER TABLE deal_oom
  DROP COLUMN org_id,
  DROP COLUMN source_power_kw,
  DROP COLUMN planned_feed_in_mwh,
  DROP COLUMN planned_nt_mwh,
  DROP COLUMN planned_vt_mwh;

DROP FUNCTION IF EXISTS deal_reopen(uuid, text);
DROP TRIGGER IF EXISTS trg_rules ON deal;
DROP FUNCTION IF EXISTS deal_rules();
DROP FUNCTION IF EXISTS deal_stage_needs_oom(deal_stage_code);
DROP FUNCTION IF EXISTS deal_oom_ready(uuid);
DROP FUNCTION IF EXISTS crm_deal_manager();
DROP FUNCTION IF EXISTS crm_user_name(uuid);
DROP FUNCTION IF EXISTS crm_customer_owner(uuid, uuid);
DROP INDEX IF EXISTS deal_next_step_idx;
DROP INDEX IF EXISTS deal_person_idx;
DROP INDEX IF EXISTS deal_company_idx;
DROP INDEX IF EXISTS deal_owner_idx;
DROP INDEX IF EXISTS deal_open_renewal_key;
ALTER TABLE deal
  DROP CONSTRAINT deal_lost_note_check,
  DROP CONSTRAINT deal_next_step_check,
  DROP CONSTRAINT deal_estimated_value_check,
  DROP CONSTRAINT deal_name_check,
  ALTER COLUMN owner_id DROP NOT NULL,
  DROP COLUMN note,
  DROP COLUMN stage_changed_at,
  DROP COLUMN estimated_value_eur,
  DROP COLUMN previous_contract_id,
  DROP COLUMN next_step_notified_on,
  DROP COLUMN next_step_on,
  DROP COLUMN next_step,
  DROP COLUMN supply_start,
  DROP COLUMN lost_note,
  DROP COLUMN lost_reason_code,
  DROP COLUMN source_code,
  ADD COLUMN campaign text,
  ADD COLUMN lost_reason text,
  ADD COLUMN source text;
COMMENT ON COLUMN deal.closed_at IS 'skutočné uzavretie dealu (nie dátum nákupu)';

-- owner_change_guard a app_user_guard ako po 0006
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
CREATE OR REPLACE FUNCTION app_user_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_external boolean;
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT t.is_external INTO v_external FROM team t WHERE t.id = NEW.team_id;
    IF v_external AND NEW.is_admin THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže byť admin.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_external AND NEW.approves_prices THEN
      RAISE EXCEPTION 'Člen externého tímu nemôže schvaľovať ceny.' USING ERRCODE = 'check_violation';
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
DROP FUNCTION IF EXISTS crm_approves_assignments();
ALTER TABLE app_user DROP COLUMN approves_assignments;

DROP FUNCTION IF EXISTS lookup_code_ok(text, text, uuid);
ALTER TABLE lookup_value DISABLE TRIGGER trg_guard;
DELETE FROM lookup_value WHERE list_code IN ('zdroj_obchodu', 'dovod_prehry');
ALTER TABLE lookup_value ENABLE TRIGGER trg_guard;
DELETE FROM lookup_list WHERE code = 'zdroj_obchodu';

DROP FUNCTION IF EXISTS deal_kind_group(deal_kind);
DROP TRIGGER IF EXISTS trg_seed_stages ON pipeline;
DROP FUNCTION IF EXISTS pipeline_seed_stages();
DROP TRIGGER IF EXISTS trg_code_guard ON pipeline_stage;
DROP FUNCTION IF EXISTS pipeline_stage_code_guard();
-- pipelines z migrácie (bez dealov) – mazanie stráži pipeline_no_delete, preto ako crm_sync nie; vypne sa spúšťač
ALTER TABLE pipeline_stage DISABLE TRIGGER trg_no_delete;
ALTER TABLE pipeline DISABLE TRIGGER trg_no_delete;
DELETE FROM pipeline_stage_required_field;
DELETE FROM pipeline_stage;
DELETE FROM pipeline;
ALTER TABLE pipeline_stage ENABLE TRIGGER trg_no_delete;
ALTER TABLE pipeline ENABLE TRIGGER trg_no_delete;
DROP INDEX IF EXISTS pipeline_stage_code_key;
ALTER TABLE pipeline_stage
  DROP CONSTRAINT pipeline_stage_code_outcome_check,
  DROP COLUMN code;
DROP TYPE IF EXISTS deal_stage_code;
DROP FUNCTION IF EXISTS crm_internal_call();
