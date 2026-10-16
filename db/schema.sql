\restrict dbmate

-- Dumped from database version 17.11 (59c914d)
-- Dumped by pg_dump version 18.6 (Postgres.app)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: verejne; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA verejne;


--
-- Name: SCHEMA verejne; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA verejne IS 'iba funkcie pre verejnú stránku ponuky (rola crm_public) – 0039';


--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


--
-- Name: access_scope; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.access_scope AS ENUM (
    'nic',
    'iba_svoje',
    'vsetko'
);


--
-- Name: activity_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.activity_type AS ENUM (
    'email',
    'hovor',
    'chat',
    'fb',
    'poznamka',
    'uloha',
    'web',
    'kampan'
);


--
-- Name: approval_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_kind AS ENUM (
    'vynimka_ceny',
    'rizikovy_zakaznik',
    'predlzenie_platnosti',
    'pridelenie_firmy'
);


--
-- Name: approval_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.approval_status AS ENUM (
    'caka',
    'schvalena',
    'zamietnuta',
    'zrusena'
);


--
-- Name: audit_action; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_action AS ENUM (
    'insert',
    'update',
    'delete'
);


--
-- Name: audit_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.audit_source AS ENUM (
    'aplikacia',
    'system',
    'synchronizacia',
    'import'
);


--
-- Name: bank_account_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.bank_account_purpose AS ENUM (
    'faktury',
    'zalohy',
    'vykup'
);


--
-- Name: commission_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.commission_status AS ENUM (
    'vypocitana',
    'cakajuca',
    'uplatnena',
    'schvalena',
    'vyplatena',
    'zrusena'
);


--
-- Name: consent_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.consent_purpose AS ENUM (
    'marketing_greenlogy',
    'blog',
    'produkty_a_sluzby',
    'individualna_komunikacia',
    'zakaznicke_sluzby'
);


--
-- Name: consent_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.consent_status AS ENUM (
    'udeleny',
    'odvolany'
);


--
-- Name: contract_close_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_close_reason AS ENUM (
    'akvizicia',
    'retencia',
    'autoprolong',
    'prepis',
    'nove_oom'
);


--
-- Name: contract_flag_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_flag_code AS ENUM (
    'pod_hranicou_bez_vynimky',
    'chyba_cena',
    'sprolongovane_bez_ceny',
    'konci_do_4_mesiacov',
    'kontrola_importu'
);


--
-- Name: contract_phase; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_phase AS ENUM (
    'rozpracovana',
    'caka_na_podpis',
    'fyzicke_podpisovanie',
    'elektronicke_podpisovanie',
    'podpisana',
    'odmietnuta',
    'ukoncena',
    'neuspesna'
);


--
-- Name: contract_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_type AS ENUM (
    'dodavka_domacnost',
    'dodavka_firma_nn',
    'dodavka_firma_vn',
    'vykup',
    'viwa'
);


--
-- Name: conversation_channel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.conversation_channel AS ENUM (
    'email',
    'web_chat',
    'facebook',
    'telefon'
);


--
-- Name: country_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.country_code AS ENUM (
    'SK',
    'CZ',
    'HR'
);


--
-- Name: crm_entity; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.crm_entity AS ENUM (
    'firma',
    'osoba',
    'oom',
    'deal',
    'zmluva',
    'ponuka'
);


--
-- Name: crm_module; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.crm_module AS ENUM (
    'zakaznici',
    'odberne_miesta',
    'obchod',
    'zmluvy',
    'provizie',
    'servis',
    'marketing'
);


--
-- Name: custom_field_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.custom_field_type AS ENUM (
    'text',
    'dlhy_text',
    'cislo',
    'suma',
    'datum',
    'vyber',
    'vyber_viac',
    'ano_nie',
    'odkaz'
);


--
-- Name: customer_segment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_segment AS ENUM (
    'domacnost',
    'firma',
    'dodavatel'
);


--
-- Name: customer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_status AS ENUM (
    'marketingovy_kontakt',
    'zaujemca',
    'ponuka',
    'cakajuci_zakaznik',
    'zakaznik',
    'byvaly_zakaznik',
    'zruseny_zakaznik'
);


--
-- Name: day_off_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.day_off_kind AS ENUM (
    'statny_sviatok',
    'firemne_volno'
);


--
-- Name: deal_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.deal_kind AS ENUM (
    'b2c_dodavka',
    'b2b_dodavka',
    'b2b_vykup',
    'green_solar',
    'green_viwa',
    'efet'
);


--
-- Name: deal_stage_code; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.deal_stage_code AS ENUM (
    'prilezitost',
    'cenova_ponuka',
    'vyjednavanie',
    'akceptacia',
    'vyhrane',
    'prehrane'
);


--
-- Name: device_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.device_type AS ENUM (
    'striedac',
    'panely',
    'bateria',
    'tepelne_cerpadlo',
    'wallbox'
);


--
-- Name: email_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.email_status AS ENUM (
    'koncept',
    'v_rade',
    'odosiela_sa',
    'odoslany',
    'chyba',
    'prijaty'
);


--
-- Name: field_edit_access; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.field_edit_access AS ENUM (
    'vsetky_timy',
    'vybrane_timy',
    'iba_admin'
);


--
-- Name: fve_program; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fve_program AS ENUM (
    'eco',
    'standard',
    'premium'
);


--
-- Name: fve_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.fve_status AS ENUM (
    'ponuka_odoslana',
    'ponuka_akceptovana',
    'zaloha_uhradena',
    'dielo_prevzate',
    'dielo_uhradene'
);


--
-- Name: offer_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_kind AS ENUM (
    'dodavka',
    'vykup',
    'viwa'
);


--
-- Name: offer_language; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_language AS ENUM (
    'sk',
    'en'
);


--
-- Name: offer_price_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_price_kind AS ENUM (
    'fix',
    'spot',
    'kombinacia',
    'cennik',
    'viwa'
);


--
-- Name: offer_send_channel; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_send_channel AS ENUM (
    'email_mimo_crm',
    'osobne',
    'ine',
    'crm'
);


--
-- Name: offer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_status AS ENUM (
    'koncept',
    'caka_na_schvalenie',
    'pripravena',
    'odoslana',
    'otvorena',
    'akceptovana',
    'zamietnuta',
    'nahradena'
);


--
-- Name: oom_contact_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_contact_source AS ENUM (
    'rucne',
    'zmluva'
);


--
-- Name: oom_import_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_import_status AS ENUM (
    'ulozeny',
    'zlyhal'
);


--
-- Name: oom_link_end_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_link_end_reason AS ENUM (
    'odchod',
    'zrusenie',
    'prepis'
);


--
-- Name: oom_plan_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_plan_kind AS ENUM (
    'prepis',
    'odchod',
    'zrusenie'
);


--
-- Name: oom_plan_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_plan_status AS ENUM (
    'planovana',
    'vykonana',
    'zrusena',
    'zlyhala'
);


--
-- Name: oom_source_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_source_category AS ENUM (
    'maly_zdroj',
    'lokalny_zdroj',
    'vyrobny_zdroj'
);


--
-- Name: oom_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_status AS ENUM (
    'aktivne',
    'pripravovane',
    'zrusene',
    'odidene',
    'prepisane'
);


--
-- Name: oom_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_type AS ENUM (
    'spotreba',
    'vyroba',
    'sharing'
);


--
-- Name: org_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.org_status AS ENUM (
    'aktivna',
    'pripravuje_sa'
);


--
-- Name: payment_rating; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payment_rating AS ENUM (
    'A',
    'B',
    'C',
    'D',
    'E',
    'X'
);


--
-- Name: price_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_direction AS ENUM (
    'odber',
    'dodavka'
);


--
-- Name: price_exception_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_exception_status AS ENUM (
    'caka',
    'schvalena',
    'zamietnuta',
    'pouzita'
);


--
-- Name: price_list_version_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_list_version_status AS ENUM (
    'navrh',
    'schvalena',
    'nahradena'
);


--
-- Name: price_model; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_model AS ENUM (
    'cennik',
    'fix',
    'spot_plus_eur',
    'spot_minus_eur',
    'spot_minus_pct',
    'cena_diela'
);


--
-- Name: product_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_category AS ENUM (
    'dodavka_domacnost',
    'dodavka_maly_podnik',
    'dodavka_firma',
    'vykup_firma',
    'velkoobchod',
    'zem',
    'vbattery',
    'viwa',
    'instalacia_fve',
    'poplatok'
);


--
-- Name: product_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_status AS ENUM (
    'predava_sa',
    'dobieha',
    'ukonceny'
);


--
-- Name: seller_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.seller_type AS ENUM (
    'obchodnik',
    'manazer'
);


--
-- Name: source_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.source_kind AS ENUM (
    'fve',
    'voda',
    'bioplyn',
    'biomasa',
    'plyn',
    'vietor',
    'ostatne_oze'
);


--
-- Name: stage_outcome; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.stage_outcome AS ENUM (
    'otvoreny',
    'vyhrany',
    'prehrany'
);


--
-- Name: status_source; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.status_source AS ENUM (
    'hubspot',
    'vypocet'
);


--
-- Name: switch_message_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.switch_message_type AS ENUM (
    'xml433',
    'xml43d'
);


--
-- Name: switch_segment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.switch_segment AS ENUM (
    'domacnost',
    'organizacia'
);


--
-- Name: tariff_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.tariff_type AS ENUM (
    'jednotarif',
    'dvojtarif',
    'nemerany',
    'netyka_sa'
);


--
-- Name: user_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_status AS ENUM (
    'pozvany',
    'aktivny',
    'deaktivovany'
);


--
-- Name: voltage_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.voltage_level AS ENUM (
    'nn',
    'vn',
    'vvn'
);


--
-- Name: add_business_minutes(timestamp with time zone, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_business_minutes(start timestamp with time zone, minutes integer, p_org_id uuid DEFAULT NULL::uuid) RETURNS timestamp with time zone
    LANGUAGE plpgsql STABLE
    AS $$
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


--
-- Name: app_user_deactivate(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_deactivate(p_user_id uuid, p_new_owner_id uuid) RETURNS TABLE(companies integer, contacts integer, open_deals integer)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: app_user_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: app_user_login(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_login(p_email text) RETURNS TABLE(user_id uuid, status public.user_status)
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: approval_cancel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_cancel(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a approval_request;
BEGIN
  UPDATE approval_request SET status = 'zrusena'
   WHERE id = p_id AND status = 'caka' AND requested_by = crm_active_user_id()
  RETURNING * INTO a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zrušiť môžete iba vlastnú čakajúcu žiadosť.' USING ERRCODE = 'check_violation';
  END IF;
  IF a.kind IN ('vynimka_ceny', 'rizikovy_zakaznik') THEN
    UPDATE offer SET status = 'koncept' WHERE status = 'caka_na_schvalenie'
       AND (id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND deal_id = a.deal_id));
  END IF;
END;
$$;


--
-- Name: approval_decide(uuid, boolean, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_decide(p_id uuid, p_approve boolean, p_note text, p_items jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a      approval_request;
  o      offer;
  it     approval_price_item;
  v_val  numeric;
  v_user uuid := crm_active_user_id();
  v_label text;
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
  SELECT * INTO o FROM offer WHERE id = a.offer_id;

  IF p_approve THEN
    CASE a.kind
      WHEN 'pridelenie_firmy' THEN
        IF (SELECT owner_id FROM company WHERE id = a.company_id) IS DISTINCT FROM a.from_owner_id THEN
          RAISE EXCEPTION 'Vlastník firmy sa medzitým zmenil – žiadosť zamietnite alebo nech žiadateľ požiada znova.'
            USING ERRCODE = 'check_violation';
        END IF;
        PERFORM set_config('app.owner_assign', 'on', true);
        UPDATE company SET owner_id = a.requested_by WHERE id = a.company_id;
        PERFORM set_config('app.owner_assign', '', true);
      WHEN 'vynimka_ceny' THEN
        FOR it IN SELECT * FROM approval_price_item WHERE approval_id = a.id LOOP
          v_val := coalesce((SELECT (x->>'approved_value')::numeric FROM jsonb_array_elements(coalesce(p_items, '[]')) x
                              WHERE (x->>'variant_id')::uuid = it.variant_id AND (x->>'year')::smallint = it.year
                                AND x->>'price_model' = it.price_model::text AND x->>'voltage_group' = it.voltage_group),
                            it.requested_value);
          IF v_val > it.requested_value THEN
            RAISE EXCEPTION 'Schválená hranica (%) nemôže byť vyššia ako žiadaná cena (%).', v_val, it.requested_value
              USING ERRCODE = 'check_violation';
          END IF;
          UPDATE approval_price_item SET approved_value = v_val
           WHERE approval_id = it.approval_id AND variant_id = it.variant_id AND year = it.year
             AND price_model = it.price_model AND voltage_group = it.voltage_group;
        END LOOP;
        a.valid_until := now() + interval '3 days';
      WHEN 'rizikovy_zakaznik' THEN
        a.valid_until := now() + interval '30 days';
      WHEN 'predlzenie_platnosti' THEN
        IF o.status NOT IN ('odoslana', 'otvorena') THEN
          RAISE EXCEPTION 'Ponuka už nie je odoslaná – predĺženie nemá zmysel.' USING ERRCODE = 'check_violation';
        END IF;
        UPDATE offer SET valid_until = a.requested_valid_until WHERE id = o.id;
        PERFORM deal_event_offer(o, 'ponuka_platnost', jsonb_build_object('valid_until', a.requested_valid_until, 'extended', true));
    END CASE;
  END IF;

  UPDATE approval_request
     SET status = CASE WHEN p_approve THEN 'schvalena' ELSE 'zamietnuta' END::approval_status,
         decided_by = v_user, decided_at = now(), decision_note = nullif(btrim(p_note), ''),
         valid_until = CASE WHEN p_approve THEN a.valid_until END
   WHERE id = a.id;

  v_label := CASE a.kind WHEN 'pridelenie_firmy' THEN 'Pridelenie firmy' WHEN 'vynimka_ceny' THEN 'Výnimka z ceny'
                         WHEN 'rizikovy_zakaznik' THEN 'Rizikový zákazník' ELSE 'Predĺženie platnosti' END
             || CASE WHEN p_approve THEN ' schválené' ELSE ' zamietnuté' END
             || CASE WHEN o.id IS NOT NULL THEN ' – ponuka ' || offer_display_number(o) ELSE '' END;
  PERFORM notification_add_deal(ARRAY[a.requested_by], 'schvalenie_rozhodnutie', a.deal_id, a.id, NULL, v_label);
  IF a.kind = 'pridelenie_firmy' AND p_approve THEN
    PERFORM notification_add_deal(ARRAY[a.from_owner_id], 'pridelenie_firmy', NULL, a.id, NULL, 'Firma bola pridelená inému obchodníkovi');
  END IF;
  IF o.id IS NOT NULL THEN
    PERFORM deal_event_offer(o, 'schvalenie_rozhodnutie',
      jsonb_build_object('kind', a.kind, 'approval_id', a.id, 'approved', p_approve));
  END IF;

  -- ponuka čakajúca na schválenie: zamietnutie → koncept, všetko schválené → pripravená
  IF a.kind IN ('vynimka_ceny', 'rizikovy_zakaznik') THEN
    IF NOT p_approve THEN
      UPDATE offer SET status = 'koncept' WHERE status = 'caka_na_schvalenie'
         AND (id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND deal_id = a.deal_id));
    ELSE
      PERFORM offer_sync_approvals(x.id) FROM offer x
        WHERE x.status = 'caka_na_schvalenie' AND (x.id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND x.deal_id = a.deal_id));
    END IF;
  END IF;
END;
$$;


--
-- Name: approval_price_detail(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_price_detail(p_id uuid) RETURNS TABLE(variant_id uuid, variant text, year smallint, price_model public.price_model, voltage_group text, requested_value numeric, threshold_value numeric, approved_value numeric, volume_mwh numeric, added_value_requested numeric, portfolio_eur_mwh numeric, margin_requested numeric)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT i.variant_id, chr(64 + v.sort_order) || ' · ' || v.name, i.year, i.price_model, i.voltage_group,
         i.requested_value,
         CASE WHEN i.threshold_source = 'odhad_portfolia' AND NOT crm_sees_portfolio() THEN NULL ELSE i.threshold_value END,
         i.approved_value, i.volume_mwh,
         round((i.requested_value - coalesce(i.approved_value, i.requested_value)) * coalesce(i.volume_mwh, 0), 2),
         CASE WHEN crm_can_see_margin() THEN (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')) END,
         CASE WHEN crm_can_see_margin() AND i.price_model = 'fix' THEN
           round((i.requested_value - (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')))
                 * coalesce(i.volume_mwh, 0), 2) END
    FROM approval_request a
    JOIN approval_price_item i ON i.approval_id = a.id
    JOIN offer_variant v ON v.id = i.variant_id AND v.offer_id = a.offer_id   -- bez kópií prenesených do novej verzie
   WHERE a.id = p_id AND a.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR a.requested_by = crm_active_user_id() OR crm_approves_prices())
   ORDER BY v.sort_order, i.year, i.voltage_group
$$;


--
-- Name: approval_request_assign(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_request_assign(p_company_id uuid, p_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: approval_request_assign_ico(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_request_assign_ico(p_ico text, p_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
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
$_$;


--
-- Name: approval_request_extend(uuid, timestamp with time zone, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_request_extend(p_offer uuid, p_until timestamp with time zone, p_reason text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o    offer := offer_for_edit(p_offer);
  v_id uuid;
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') OR o.valid_until IS NULL THEN
    RAISE EXCEPTION 'Predĺžiť sa dá platnosť odoslanej ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_until IS NULL OR p_until <= greatest(o.valid_until, now()) THEN
    RAISE EXCEPTION 'Nová platnosť musí byť neskôr ako doterajšia.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod predĺženia.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, requested_valid_until)
  VALUES (o.org_id, 'predlzenie_platnosti', o.deal_id, o.id, (SELECT company_id FROM deal WHERE id = o.deal_id),
          btrim(p_reason), crm_active_user_id(), p_until)
  RETURNING id INTO v_id;
  PERFORM notification_add_deal(array_remove(notification_approvers(o.org_id, false), crm_active_user_id()),
                                'schvalenie_nove', o.deal_id, v_id, NULL, 'Predĺženie platnosti – ponuka ' || offer_display_number(o));
  PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'predlzenie_platnosti', 'approval_id', v_id));
  RETURN v_id;
END;
$$;


--
-- Name: approval_request_offer(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.approval_request_offer(p_offer uuid, p_reason text) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o      offer := offer_for_edit(p_offer);
  d      deal;
  c      jsonb;
  n      jsonb;
  v_id   uuid;
  v_user uuid := crm_active_user_id();
  v_appr uuid[];
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena') THEN
    RAISE EXCEPTION 'O schválenie sa žiada pri koncepte ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  c := offer_check_internal(o.id);
  IF jsonb_array_length(c->'errors') > 0 THEN
    RAISE EXCEPTION '%', (SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(c->'errors') e) USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(c->'needs') = 0 AND NOT (c->>'risk_needs_approval')::boolean THEN
    RETURN offer_prepare(o.id);
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod žiadosti o schválenie.' USING ERRCODE = 'check_violation';
  END IF;
  v_appr := array_remove(notification_approvers(o.org_id, false), v_user);

  IF jsonb_array_length(c->'needs') > 0 THEN
    UPDATE approval_request SET status = 'zrusena' WHERE offer_id = o.id AND kind = 'vynimka_ceny' AND status = 'caka';
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by)
    VALUES (o.org_id, 'vynimka_ceny', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user)
    RETURNING id INTO v_id;
    FOR n IN SELECT * FROM jsonb_array_elements(c->'needs') LOOP
      IF n->>'type' = 'pokuta' THEN   -- zmluvná pokuta pod predvolenou hodnotou (0039)
        UPDATE approval_request SET penalty_eur_mwh = (n->>'requested_value')::numeric WHERE id = v_id;
        CONTINUE;
      END IF;
      INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                       volume_mwh, threshold_source, scope)
      VALUES (v_id, (n->>'variant_id')::uuid, (n->>'year')::smallint, (n->>'price_model')::price_model, n->>'voltage_group',
              (n->>'requested_value')::numeric, coalesce((n->>'threshold_value')::numeric, 0), (n->>'volume_mwh')::numeric,
              n->>'threshold_source', offer_variant_scope((n->>'variant_id')::uuid));
    END LOOP;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Výnimka z ceny – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'vynimka_ceny', 'approval_id', v_id));
  END IF;

  IF (c->>'risk_needs_approval')::boolean
     AND NOT EXISTS (SELECT 1 FROM approval_request WHERE deal_id = o.deal_id AND kind = 'rizikovy_zakaznik' AND status = 'caka') THEN
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, risk_snapshot)
    VALUES (o.org_id, 'rizikovy_zakaznik', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user, company_risk_snapshot(d.company_id))
    RETURNING id INTO v_id;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Rizikový zákazník – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'rizikovy_zakaznik', 'approval_id', v_id));
  END IF;

  UPDATE offer SET status = 'caka_na_schvalenie' WHERE id = o.id;
  RETURN 'caka_na_schvalenie';
END;
$$;


--
-- Name: audit_diff_value(jsonb, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_diff_value(p_diff jsonb, p_column text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN jsonb_typeof(p_diff -> p_column) = 'object'
              THEN coalesce(p_diff -> p_column ->> 'new', p_diff -> p_column ->> 'old')
              ELSE p_diff ->> p_column END
$$;


--
-- Name: audit_log_protect(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_log_protect() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF current_user <> (SELECT r.rolname FROM pg_class c JOIN pg_roles r ON r.oid = c.relowner
                       WHERE c.oid = 'audit_log'::regclass) THEN
    RAISE EXCEPTION 'Audit sa nedá upraviť ani zmazať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(OLD, NEW);
END;
$$;


--
-- Name: audit_row(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_row() RETURNS trigger
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


--
-- Name: audit_row_visible(text, uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
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
    WHEN 'offer', 'offer_variant', 'offer_item' THEN
      -- ponuka: podľa obchodu (0036); ceny ponuky neobsahujú hranice ani maržu
      v_id := CASE p_table
                WHEN 'offer' THEN coalesce((SELECT deal_id FROM offer WHERE id = p_record), audit_diff_value(p_diff, 'deal_id')::uuid)
                WHEN 'offer_variant' THEN (SELECT o.deal_id FROM offer o
                                            WHERE o.id = coalesce((SELECT offer_id FROM offer_variant WHERE id = p_record),
                                                                  audit_diff_value(p_diff, 'offer_id')::uuid))
                ELSE (SELECT o.deal_id FROM offer_variant v JOIN offer o ON o.id = v.offer_id
                       WHERE v.id = coalesce((SELECT variant_id FROM offer_item WHERE id = p_record),
                                             audit_diff_value(p_diff, 'variant_id')::uuid)) END;
      SELECT * INTO d FROM deal WHERE id = v_id;
      RETURN FOUND AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id);
    WHEN 'approval_price_item' THEN
      -- hranica z odhadu portfólia (FIX manažéra) iba pre crm_sees_portfolio(); neznámy zdroj = skryť (0038)
      IF NOT crm_sees_portfolio()
         AND coalesce((SELECT threshold_source FROM approval_price_item WHERE id = p_record),
                      audit_diff_value(p_diff, 'threshold_source'), 'odhad_portfolia') = 'odhad_portfolia' THEN
        RETURN false;
      END IF;
      RETURN audit_row_visible('approval_request',
                               coalesce((SELECT approval_id FROM approval_price_item WHERE id = p_record),
                                        audit_diff_value(p_diff, 'approval_id')::uuid), NULL);
    WHEN 'user_commission_rate' THEN
      RETURN crm_approves_prices()
          OR coalesce((SELECT user_id FROM user_commission_rate WHERE id = p_record),
                      audit_diff_value(p_diff, 'user_id')::uuid) = crm_active_user_id();
    WHEN 'price_parameter', 'market_price_daily' THEN
      RETURN crm_approves_prices() OR crm_can_see_margin();   -- kto smie čítať cenové parametre a trhové ceny (0023)
    ELSE
      RETURN false;   -- Nastavenia, používatelia, tímy, cenníky, importy: iba admin
  END CASE;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN false;     -- poškodené id v obsahu zmeny: radšej skryť
END;
$_$;


--
-- Name: FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.audit_row_visible(p_table text, p_record uuid, p_diff jsonb) IS 'RLS na audit_log: admin všetko, ostatní iba zmeny záznamov, ktoré smú vidieť (0035)';


--
-- Name: business_calendar_rebuild(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.business_calendar_rebuild() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: company_apply_finstat(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_apply_finstat(p_company_id uuid, p_data jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: company_check(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_check(p_ico text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
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
$_$;


--
-- Name: company_contact_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_contact_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org uuid := (SELECT org_id FROM company WHERE id = NEW.company_id);
BEGIN
  IF v_org <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a firma patria rôznym spoločnostiam (osoba v inej spoločnosti = nový záznam).'
      USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_kontaktu', v_org, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;


--
-- Name: company_country_default(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_country_default() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.country IS NULL THEN
    SELECT o.country INTO NEW.country FROM org o WHERE o.id = NEW.org_id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: company_ico_check(public.country_code, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_ico_check(p_country public.country_code, p_ico text) RETURNS TABLE(company_exists boolean, company_id uuid, owner_name text, org_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT true,
         CASE WHEN crm_company_access(c.id, 'view') THEN c.id END,
         u.name,
         o.legal_name
    FROM company c
    JOIN org o ON o.id = c.org_id
    LEFT JOIN app_user u ON u.id = c.owner_id
   WHERE c.country = p_country
     AND c.ico = CASE WHEN p_country = 'HR' THEN regexp_replace(p_ico, '[^0-9]', '', 'g')
                      ELSE lpad(regexp_replace(p_ico, '[^0-9]', '', 'g'), 8, '0') END
$$;


--
-- Name: crm_default_org(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_default_org() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT id FROM org WHERE is_default
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: company; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    ico text NOT NULL,
    dic text,
    ic_dph text,
    vat_payer boolean,
    legal_form text,
    registry_entry text,
    nace text,
    statutory text,
    address text,
    payment_rating public.payment_rating,
    debts_note text,
    insolvency_note text,
    finstat_url text,
    finstat_updated_at timestamp with time zone,
    owner_id uuid,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    bank_account text,
    is_customer boolean DEFAULT true NOT NULL,
    is_partner boolean DEFAULT false NOT NULL,
    is_supplier boolean DEFAULT false NOT NULL,
    status public.customer_status,
    status_source public.status_source,
    status_changed_at timestamp with time zone,
    is_former_customer boolean DEFAULT false NOT NULL,
    is_producer boolean DEFAULT false NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid DEFAULT public.crm_default_org() NOT NULL,
    country public.country_code NOT NULL,
    op_person_id uuid,
    created_by_import uuid,
    revenue_eur numeric(14,2),
    profit_eur numeric(14,2),
    finance_year smallint,
    employees_range text,
    founded_on date,
    z_score numeric(6,2),
    has_debts boolean,
    debts jsonb DEFAULT '[]'::jsonb NOT NULL,
    insolvency_kind text,
    insolvency_since date,
    cancelled_on date,
    CONSTRAINT company_debts_check CHECK ((jsonb_typeof(debts) = 'array'::text)),
    CONSTRAINT company_finance_year_check CHECK (((finance_year >= 1990) AND (finance_year <= 2100))),
    CONSTRAINT company_ico_format_check CHECK ((((country = ANY (ARRAY['SK'::public.country_code, 'CZ'::public.country_code])) AND (ico ~ '^[0-9]{8}$'::text)) OR ((country = 'HR'::public.country_code) AND (ico ~ '^[0-9]{11}$'::text)))),
    CONSTRAINT company_insolvency_kind_check CHECK ((insolvency_kind = ANY (ARRAY['konkurz'::text, 'restrukturalizacia'::text]))),
    CONSTRAINT company_kind_check CHECK ((is_customer OR is_partner OR is_supplier)),
    CONSTRAINT company_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT company_status_source_check CHECK (((status IS NULL) = (status_source IS NULL)))
);


--
-- Name: COLUMN company.ico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.ico IS 'identifikátor podľa krajiny: SK, CZ = IČO 8 číslic vrátane úvodných núl; HR = OIB 11 číslic';


--
-- Name: COLUMN company.bank_account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.bank_account IS 'bankový účet firmy (zvyčajne IBAN), HubSpot bank_account';


--
-- Name: COLUMN company.is_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_customer IS 'označenie zákazník (predvolené); firma môže mať viac označení';


--
-- Name: COLUMN company.is_partner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_partner IS 'označenie partner; partner bez is_customer nie je v zozname Zákazníci';


--
-- Name: COLUMN company.is_supplier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_supplier IS 'označenie dodávateľ; dodávateľ bez is_customer nie je v zozname Zákazníci';


--
-- Name: COLUMN company.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak firma nie je zákazník';


--
-- Name: COLUMN company.is_former_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_former_customer IS 'príznak „bývalý“: mal odídené OOM; automaticky sa nezruší';


--
-- Name: COLUMN company.is_producer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.is_producer IS 'segment „+ výrobca“';


--
-- Name: COLUMN company.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN company.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.org_id IS 'spoločnosť skupiny, ktorej firma patrí (zákazník patrí práve jednej)';


--
-- Name: COLUMN company.country; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.country IS 'krajina firmy (predvolene krajina spoločnosti); určuje identifikátor v stĺpci ico';


--
-- Name: COLUMN company.op_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.op_person_id IS 'Osoba_ID zákazníka v Office portáli (párovanie importu zmlúv)';


--
-- Name: COLUMN company.created_by_import; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.created_by_import IS 'založený importom zmlúv; zruší prvá ručná úprava alebo „Skontrolované“';


--
-- Name: COLUMN company.revenue_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.revenue_eur IS 'tržby za rok finance_year (Finstat)';


--
-- Name: COLUMN company.z_score; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.z_score IS 'Altmanovo Z-skóre (Finstat): pod 1,23 riziko úpadku, 1,23–2,90 šedá zóna, nad 2,90 stabilná';


--
-- Name: COLUMN company.debts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.debts IS 'dlhy a nedoplatky z verejných zoznamov (Finstat): [{veritel, suma_eur, k_datumu}]';


--
-- Name: COLUMN company.insolvency_kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.insolvency_kind IS 'konkurz alebo reštrukturalizácia (Finstat); NULL = nie';


--
-- Name: COLUMN company.cancelled_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.cancelled_on IS 'firma zrušená / vymazaná z registra (Finstat)';


--
-- Name: company_is_archived(public.company); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_is_archived(c public.company) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT c.status IS NOT DISTINCT FROM 'zruseny_zakaznik' AND NOT c.is_partner AND NOT c.is_supplier
$$;


--
-- Name: company_risk(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_risk(p_company_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'warnings', coalesce(jsonb_agg(w.code ORDER BY w.ord) FILTER (WHERE w.code IS NOT NULL), '[]'),
           'needs_approval', bool_or(w.approval) IS TRUE,
           'z_band', CASE WHEN c.z_score IS NULL THEN NULL
                          WHEN c.z_score < 1.23 THEN 'riziko'
                          WHEN c.z_score <= 2.90 THEN 'seda_zona'
                          ELSE 'stabilna' END,
           'finstat_updated_at', c.finstat_updated_at)
    FROM company c
    LEFT JOIN LATERAL (VALUES
      (1, CASE WHEN c.has_debts OR jsonb_array_length(c.debts) > 0 THEN 'dlhy' END, false),
      (2, CASE WHEN c.insolvency_kind IS NOT NULL THEN c.insolvency_kind END, true),
      (3, CASE WHEN c.payment_rating IN ('E', 'X') THEN 'rating_' || lower(c.payment_rating::text) END,
          c.payment_rating IN ('E', 'X')),
      (4, CASE WHEN c.z_score < 1.23 THEN 'z_skore' END, false),
      (5, CASE WHEN c.cancelled_on IS NOT NULL THEN 'zrusena' END, false)
    ) AS w(ord, code, approval) ON w.code IS NOT NULL
   WHERE c.id = p_company_id
   GROUP BY c.id
$$;


--
-- Name: FUNCTION company_risk(p_company_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.company_risk(p_company_id uuid) IS 'výstrahy Finstatu pre firmu, obchod a ponuku; needs_approval = konkurz/reštrukturalizácia alebo rating E/X (bez osobných údajov)';


--
-- Name: company_risk_snapshot(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_risk_snapshot(p_company uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'insolvency_kind', c.insolvency_kind,
           'payment_rating', c.payment_rating,
           'debts_count', jsonb_array_length(c.debts),
           'debts_sum', (SELECT coalesce(sum((x->>'suma_eur')::numeric), 0) FROM jsonb_array_elements(c.debts) x),
           'has_debts', c.has_debts)
    FROM company c WHERE c.id = p_company
$$;


--
-- Name: company_risk_worse(jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.company_risk_worse(p_then jsonb, p_now jsonb) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT (p_now->>'insolvency_kind' IS NOT NULL AND p_then->>'insolvency_kind' IS DISTINCT FROM p_now->>'insolvency_kind')
      OR (p_now->>'payment_rating' IS NOT NULL
          AND coalesce(p_then->>'payment_rating', 'A') < p_now->>'payment_rating')
      OR coalesce((p_now->>'debts_count')::int, 0) > coalesce((p_then->>'debts_count')::int, 0)
      OR coalesce((p_now->>'debts_sum')::numeric, 0) > coalesce((p_then->>'debts_sum')::numeric, 0)
      OR (coalesce((p_now->>'has_debts')::boolean, false) AND NOT coalesce((p_then->>'has_debts')::boolean, false))
$$;


--
-- Name: contact_duplicate_check(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contact_duplicate_check(p_email text, p_phone text, p_org_id uuid DEFAULT NULL::uuid) RETURNS TABLE(match_on text, contact_id uuid, owner_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT m.match_on,
         CASE WHEN crm_contact_access(p.id, 'view') THEN p.id END,
         u.name
    FROM (
      SELECT 'email'::text AS match_on, p.id
        FROM contact p
       WHERE nullif(btrim(p_email), '') IS NOT NULL
         AND lower(btrim(p.email)) = lower(btrim(p_email))
      UNION
      SELECT 'telefon', p.id
        FROM contact p
       WHERE normalize_phone(p_phone) IS NOT NULL
         AND normalize_phone(p_phone) IN (p.phone_norm, p.mobile_norm)
    ) m
    JOIN contact p ON p.id = m.id
    LEFT JOIN app_user u ON u.id = p.owner_id
   WHERE p.org_id = coalesce(p_org_id, crm_default_org())
   ORDER BY m.match_on, p.created_at
$$;


--
-- Name: contact_source_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contact_source_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.source IS NOT NULL THEN
    PERFORM lookup_codes_check('zdroj_kontaktu', NEW.org_id, ARRAY[NEW.source],
                               CASE WHEN TG_OP = 'UPDATE' THEN ARRAY[OLD.source] END);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: contract_after_price_change(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_after_price_change(p_contract_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM contract_price_missing_refresh(p_contract_id);
  PERFORM contract_basis_refresh(p_contract_id);
END;
$$;


--
-- Name: contract_basis_refresh(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_basis_refresh(p_contract_id uuid) RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c      contract;
  v_from date;
  v_to   date;
  y      integer;
  v      contract_year_basis;
  s      contract_year_basis;
  e      price_exception;
  r      record;
  v_mod  text;
  v_det  text;
  v_warn text[] := '{}';
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF NOT FOUND THEN
    RETURN v_warn;
  END IF;
  SELECT min(valid_from), max(coalesce(valid_to, make_date(extract(year FROM crm_today())::int + 1, 12, 31)))
    INTO v_from, v_to FROM contract_oom WHERE contract_id = c.id AND valid_from IS NOT NULL;
  DELETE FROM contract_year_basis
   WHERE contract_id = c.id
     AND (c.signed_on IS NULL OR v_from IS NULL
          OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  UPDATE contract_flag SET resolved_at = now()
   WHERE contract_id = c.id AND code IN ('pod_hranicou_bez_vynimky', 'chyba_cena') AND year IS NOT NULL AND resolved_at IS NULL
     AND (v_from IS NULL OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  IF v_from IS NULL THEN
    RETURN v_warn;
  END IF;

  FOR y IN extract(year FROM v_from)::int .. extract(year FROM v_to)::int LOOP
    IF c.signed_on IS NOT NULL THEN
      v := contract_basis_values(c, y, c.signed_on);
      SELECT * INTO s FROM contract_year_basis WHERE contract_id = c.id AND year = y;
      v.exception_id := s.exception_id;
      v.exception_value := s.exception_value;
      IF v.exception_id IS NULL AND c.phase = 'podpisana' THEN
        v_mod := (SELECT p.price_model::text FROM contract_price p
                   WHERE p.contract_id = c.id AND p.slot = 'komodita' AND p.source = 'import' AND p.price_model <> 'cennik'
                     AND p.valid_from <= make_date(y, 12, 31) AND (p.valid_to IS NULL OR p.valid_to >= make_date(y, 1, 1))
                   ORDER BY p.valid_from DESC LIMIT 1);
        e := NULL;
        SELECT * INTO e FROM price_exception x
         WHERE x.org_id = c.org_id AND x.company_id IS NOT DISTINCT FROM c.company_id
           AND x.person_id IS NOT DISTINCT FROM c.person_id AND y = ANY (x.years) AND x.price_model::text = v_mod
           AND ((x.status = 'schvalena' AND c.signed_on <= x.valid_until) OR (x.status = 'pouzita' AND x.contract_id = c.id))
         ORDER BY x.decided_at DESC
         LIMIT 1;
        IF e.id IS NOT NULL THEN
          v.exception_id := e.id;
          v.exception_value := e.requested_value;
          UPDATE price_exception SET status = 'pouzita', contract_id = c.id WHERE id = e.id AND status = 'schvalena';
        END IF;
      END IF;
      INSERT INTO contract_year_basis (contract_id, year, ref_date, seller_type, trader_price, portfolio_eur_mwh, portfolio_on,
                                       min_additive, energopomoc_price, viwa_additive, exception_id, exception_value, source)
      VALUES (c.id, y, v.ref_date, v.seller_type, v.trader_price, v.portfolio_eur_mwh, v.portfolio_on, v.min_additive,
              v.energopomoc_price, v.viwa_additive, v.exception_id, v.exception_value, v.source)
      ON CONFLICT (contract_id, year) DO UPDATE
         SET ref_date = EXCLUDED.ref_date, seller_type = EXCLUDED.seller_type, trader_price = EXCLUDED.trader_price,
             portfolio_eur_mwh = EXCLUDED.portfolio_eur_mwh, portfolio_on = EXCLUDED.portfolio_on,
             min_additive = EXCLUDED.min_additive, energopomoc_price = EXCLUDED.energopomoc_price,
             viwa_additive = EXCLUDED.viwa_additive, exception_id = EXCLUDED.exception_id,
             exception_value = EXCLUDED.exception_value, source = EXCLUDED.source, computed_at = now()
       WHERE (contract_year_basis.ref_date, contract_year_basis.seller_type, contract_year_basis.trader_price,
              contract_year_basis.portfolio_eur_mwh, contract_year_basis.portfolio_on, contract_year_basis.min_additive,
              contract_year_basis.energopomoc_price, contract_year_basis.viwa_additive, contract_year_basis.exception_id,
              contract_year_basis.exception_value, contract_year_basis.source)
             IS DISTINCT FROM
             (EXCLUDED.ref_date, EXCLUDED.seller_type, EXCLUDED.trader_price, EXCLUDED.portfolio_eur_mwh, EXCLUDED.portfolio_on,
              EXCLUDED.min_additive, EXCLUDED.energopomoc_price, EXCLUDED.viwa_additive, EXCLUDED.exception_id,
              EXCLUDED.exception_value, EXCLUDED.source);
    END IF;

    SELECT * INTO r FROM contract_year_calc(c.id, y);
    -- Pod hranicou bez výnimky (individuálna cena)
    IF c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.model ~ '(fix|spot_plus_eur|vykup)' AND r.added_value_eur < 0
       AND r.exception_id IS NULL THEN
      v_det := format('Pridaná hodnota %s: %s € – cena pod hranicou bez schválenej výnimky.', y,
                      replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      v_warn := v_warn || format('Pod hranicou bez výnimky %s: pridaná hodnota %s €', y,
                                 replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      IF NOT EXISTS (SELECT 1 FROM contract_flag f WHERE f.contract_id = c.id AND f.code = 'pod_hranicou_bez_vynimky' AND f.year = y
                        AND (f.resolved_at IS NULL OR f.resolved_by IS NOT NULL)) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'pod_hranicou_bez_vynimky', y, v_det);
      ELSE
        UPDATE contract_flag SET detail = v_det
         WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL
           AND detail IS DISTINCT FROM v_det;
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL;
    END IF;
    -- Chýba cena pre obchodníka (podpis od 1. 1. 2026)
    IF c.signed_on >= '2026-01-01' AND c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.missing = 'cena pre obchodníka' THEN
      v_det := format('chýba cena pre obchodníka %s (ceny BL/PL ku dňu podpisu %s)', y, to_char(c.signed_on, 'FMDD. FMMM. YYYY'));
      v_warn := v_warn || ('Chýba cena: ' || v_det);
      IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'chyba_cena', y, v_det);
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL;
    END IF;
  END LOOP;
  RETURN v_warn;
END;
$$;


--
-- Name: FUNCTION contract_basis_refresh(p_contract_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_basis_refresh(p_contract_id uuid) IS 'snímka ku dňu podpisu, párovanie výnimky, príznaky Pod hranicou bez výnimky a Chýba cena pre obchodníka; vráti upozornenia';


--
-- Name: contract_basis_refresh_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_basis_refresh_trigger() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM contract_basis_refresh(NEW.id);
  RETURN NULL;
END;
$$;


--
-- Name: contract; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid,
    company_id uuid,
    person_id uuid,
    number text NOT NULL,
    segment public.customer_segment,
    auto_prolong boolean DEFAULT false NOT NULL,
    valid_from date,
    valid_to date,
    payment_terms_days integer,
    consumption_tolerance numeric(5,2),
    advance_payment_pct numeric(5,2),
    hubspot_deal_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    op_id uuid,
    type public.contract_type NOT NULL,
    phase public.contract_phase NOT NULL,
    signed_on date,
    crm_valid_to date,
    small_business boolean DEFAULT false NOT NULL,
    list_price boolean DEFAULT false NOT NULL,
    viwa_package text,
    close_reason public.contract_close_reason,
    owner_id uuid,
    created_by_name text,
    previous_contract_id uuid,
    related_contract_id uuid,
    note text,
    op_updated_at timestamp with time zone,
    last_import_id uuid,
    vykup_min_additive numeric(12,4),
    CONSTRAINT contract_crm_valid_to_check CHECK (((crm_valid_to IS NULL) OR (valid_from IS NULL) OR (crm_valid_to >= (valid_from - 1)))),
    CONSTRAINT contract_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT contract_payment_terms_days_check CHECK ((payment_terms_days >= 0)),
    CONSTRAINT contract_previous_check CHECK ((previous_contract_id IS DISTINCT FROM id)),
    CONSTRAINT contract_related_check CHECK ((related_contract_id IS DISTINCT FROM id)),
    CONSTRAINT contract_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT contract_viwa_package_check CHECK ((viwa_package = ANY (ARRAY['basic'::text, 'plus'::text, 'pro'::text]))),
    CONSTRAINT contract_viwa_package_type_check CHECK (((viwa_package IS NULL) OR (type = 'viwa'::public.contract_type))),
    CONSTRAINT contract_vykup_min_additive_check CHECK ((vykup_min_additive >= (0)::numeric)),
    CONSTRAINT contract_vykup_min_additive_type_check CHECK (((vykup_min_additive IS NULL) OR (type = 'vykup'::public.contract_type)))
);


--
-- Name: COLUMN contract.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN contract.valid_from; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.valid_from IS 'účinnosť od (Office portal; domácnosti z XM Trade)';


--
-- Name: COLUMN contract.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.valid_to IS 'účinnosť do z Office portálu; NULL = na neurčito';


--
-- Name: COLUMN contract.consumption_tolerance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.consumption_tolerance IS 'tolerancia odberu v %';


--
-- Name: COLUMN contract.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN contract.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.org_id IS 'preberá sa od zákazníka';


--
-- Name: COLUMN contract.op_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.op_id IS 'ID zmluvy v Office portáli (stabilný kľúč importu popri čísle)';


--
-- Name: COLUMN contract.phase; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.phase IS 'fáza v Office portáli; stav zmluvy sa počíta (contract_state)';


--
-- Name: COLUMN contract.signed_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.signed_on IS 'platnosť od (deň podpisu) z Office portálu';


--
-- Name: COLUMN contract.crm_valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.crm_valid_to IS 'koniec podľa CRM: automatická prolongácia alebo skrátenie nástupníckou zmluvou; NULL = podľa valid_to';


--
-- Name: COLUMN contract.owner_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.owner_id IS 'Uzatvoril (obchodník) – z Office portálu cez preklad mena';


--
-- Name: COLUMN contract.previous_contract_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.previous_contract_id IS 'predošlá zmluva (retencia, prepis, obnova); nastaví aj nástupníctvo na OOM';


--
-- Name: COLUMN contract.related_contract_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.related_contract_id IS 'súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka';


--
-- Name: COLUMN contract.last_import_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.last_import_id IS 'posledný import, ktorý zmluvu založil alebo zmenil';


--
-- Name: COLUMN contract.vykup_min_additive; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.vykup_min_additive IS 'výkup: minimálny aditív pre túto zmluvu (prepis parametra, zadá Nákup); NULL = parameter';


--
-- Name: contract_year_basis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_year_basis (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    year smallint NOT NULL,
    ref_date date NOT NULL,
    seller_type public.seller_type NOT NULL,
    trader_price numeric(12,4),
    portfolio_eur_mwh numeric(12,4),
    portfolio_on date,
    min_additive numeric(12,4),
    energopomoc_price numeric(12,4),
    viwa_additive numeric(12,4),
    exception_id uuid,
    exception_value numeric(12,4),
    source text DEFAULT 'vypocet'::text NOT NULL,
    computed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_year_basis_exception_check CHECK (((exception_id IS NULL) = (exception_value IS NULL))),
    CONSTRAINT contract_year_basis_source_check CHECK ((source = ANY (ARRAY['vypocet'::text, 'hubspot'::text]))),
    CONSTRAINT contract_year_basis_year_check CHECK (((year >= 2000) AND (year <= 2100)))
);


--
-- Name: TABLE contract_year_basis; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_year_basis IS 'snímka ku dňu podpisu pre zmluvu × rok: cena pre obchodníka, odhad portfólia, minimálny aditív, energopomoc, aditív VIWA, výnimka; pridanú hodnotu po zmene parametrov nemení';


--
-- Name: COLUMN contract_year_basis.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_year_basis.source IS 'vypocet = z cien BL/PL ku dňu podpisu; hubspot = cena pre obchodníka z nákupnej ceny pri deale (contract_purchase, zmluvy pred 2026)';


--
-- Name: contract_basis_values(public.contract, integer, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_basis_values(c public.contract, p_year integer, p_on date) RETURNS public.contract_year_basis
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  b contract_year_basis;
  m record;
BEGIN
  b.contract_id := c.id;
  b.year := p_year;
  b.ref_date := p_on;
  b.source := 'vypocet';
  b.seller_type := coalesce((SELECT seller_type FROM app_user WHERE id = c.owner_id), 'obchodnik');
  b.trader_price := trader_price(c.org_id, p_year::smallint, p_on);
  IF b.trader_price IS NULL THEN
    b.trader_price := (SELECT price_eur_mwh FROM contract_purchase
                        WHERE contract_id = c.id AND delivery_year = p_year ORDER BY priced_on DESC LIMIT 1);
    IF b.trader_price IS NOT NULL THEN
      b.source := 'hubspot';
    END IF;
  END IF;
  SELECT * INTO m FROM contract_market_value(c.org_id, p_year, p_on, 'portfolio');
  b.portfolio_eur_mwh := m.value;
  b.portfolio_on := m.on_date;
  IF c.type = 'vykup' THEN
    b.min_additive := coalesce(c.vykup_min_additive, contract_param(c.org_id,
      CASE WHEN EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                         WHERE x.contract_id = c.id AND o.source_category = 'lokalny_zdroj')
           THEN 'min_aditiv_vykup_lz' ELSE 'min_aditiv_vykup' END, p_on));
  ELSE
    b.min_additive := contract_param(c.org_id,
      CASE b.seller_type WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, p_on);
  END IF;
  b.energopomoc_price := contract_param(c.org_id, 'nakup_energopomoc', p_on, p_year::smallint);
  b.viwa_additive := CASE WHEN c.viwa_package IS NOT NULL THEN contract_param(c.org_id, 'viwa_aditiv_' || c.viwa_package, p_on) END;
  b.computed_at := now();
  RETURN b;
END;
$$;


--
-- Name: contract_child_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_child_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
BEGIN
  IF NOT (crm_owner_session()
          OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = TG_RELID)) THEN
    RAISE EXCEPTION 'OOM a ceny zmluvy mení iba import z Office portálu.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: contract_crm_end_refresh(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_crm_end_refresh(p_contract_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_end date;
  v_all boolean;
BEGIN
  SELECT max(valid_to), bool_and(valid_to IS NOT NULL) INTO v_end, v_all FROM contract_oom WHERE contract_id = p_contract_id;
  UPDATE contract
     SET crm_valid_to = CASE WHEN v_all AND v_end IS DISTINCT FROM valid_to THEN v_end ELSE NULL END
   WHERE id = p_contract_id
     AND crm_valid_to IS DISTINCT FROM (CASE WHEN v_all AND v_end IS DISTINCT FROM valid_to THEN v_end ELSE NULL END);
END;
$$;


--
-- Name: contract_daily_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_daily_run() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT contract_daily_run_at(crm_today())
$$;


--
-- Name: contract_daily_run_at(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_run     uuid;
  v_err     jsonb := '[]';
  v_touched uuid[] := '{}';
  v_id      uuid;
  r         record;
  v_ok      boolean;
  v_end     date;
  v_last    date;
  v_state   text;
  v_msg     text;
  v_n       jsonb := '{}';
  v_cnt     integer;
  v_result  jsonb;
  v_pr      record;
  v_ended   integer := 0;
  v_before  uuid[];
  v_retro   text[] := '{}';
  v_sb      text[] := '{}';
  v_vol     text[] := '{}';
  v_prev_today  text := coalesce(current_setting('crm.today', true), '');
  v_prev_source text;
BEGIN
  IF p_today IS NULL THEN
    RAISE EXCEPTION 'contract_daily_run_at: chýba dátum' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtext('crm.contract_daily_run')) THEN
    RETURN jsonb_build_object('bezi', true);
  END IF;
  PERFORM set_config('crm.today', p_today::text, true);   -- crm_today() v spojení vlastníka (ručný beh)
  v_prev_source := crm_as_system(true);
  SELECT max(run_date) INTO v_last FROM job_run
   WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL AND run_date < p_today;
  INSERT INTO job_run (job, run_date, test_date)
  VALUES ('zmluvy', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;

  -- 1. Regulácia: ceny zmlúv na OOM, ktorých zmena regulácie nastala a zmluvy ju ešte nemajú
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT ch.id, ch.oom_id, ch.valid_from FROM oom_price_regulation_change ch
              WHERE ch.contract_applied_at IS NULL AND ch.valid_from <= p_today
              ORDER BY ch.valid_from, ch.id LOOP
      v_ok := true;
      FOR v_id IN SELECT DISTINCT co.contract_id FROM contract_oom co JOIN contract k ON k.id = co.contract_id
                   WHERE co.oom_id = r.oom_id AND k.phase NOT IN ('odmietnuta', 'neuspesna')
                     AND (co.valid_to IS NULL OR co.valid_to >= r.valid_from) LOOP
        BEGIN
          IF contract_sync_checked(v_id) THEN
            PERFORM contract_after_price_change(v_id);
            v_cnt := v_cnt + 1;
            v_touched := v_touched || v_id;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_ok := false;
          v_err := v_err || job_error(v_id, 'regulacia', v_state, v_msg);
        END;
      END LOOP;
      IF v_ok THEN
        UPDATE oom_price_regulation_change SET contract_applied_at = now() WHERE id = r.id;
      END IF;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'regulacia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('regulacia', v_cnt);

  -- 2. Cenník: zmluvy s cenníkovou cenou, ktorej verzia medzitým skončila alebo bola nahradená, a zmluvy s „Chýba cena“.
  --    Nová verzia sa uplatní prvú noc po schválení; cena platná od dátumu v minulosti sa zapíše od toho dátumu
  --    a zmluva ide do zoznamu „cennik_spatne“ v denníku behu (pre Nákup).
  v_cnt := 0;
  BEGIN
    FOR v_id IN SELECT cp.contract_id FROM contract_price cp
                  JOIN price_list_item i ON i.id = cp.price_list_item_id
                  JOIN price_list_version v ON v.id = i.version_id
                 WHERE cp.source = 'import'
                   AND (v.status = 'nahradena' OR (v.valid_to IS NOT NULL AND (cp.valid_to IS NULL OR cp.valid_to > v.valid_to)))
                UNION
                SELECT f.contract_id FROM contract_flag f WHERE f.code = 'chyba_cena' AND f.resolved_at IS NULL
                ORDER BY 1 LOOP
      BEGIN
        v_before := ARRAY(SELECT id FROM contract_price WHERE contract_id = v_id);
        IF contract_sync_checked(v_id) THEN
          PERFORM contract_after_price_change(v_id);
          v_cnt := v_cnt + 1;
          v_touched := v_touched || v_id;
          IF EXISTS (SELECT 1 FROM contract_price WHERE contract_id = v_id AND price_model = 'cennik'
                        AND valid_from < p_today AND NOT id = ANY (v_before)) THEN
            v_retro := v_retro || (SELECT number FROM contract WHERE id = v_id);
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(v_id, 'cennik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'cennik', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('cennik', v_cnt,
                                    'cennik_spatne', jsonb_build_object('pocet', cardinality(v_retro), 'zmluvy', to_jsonb(v_retro)));

  -- 3. Prolongácia: skončené zmluvy s automatickou prolongáciou a aspoň jedným OOM bez nástupcu a bez pevného konca;
  --    zmluva bez Aktívneho / Pripravovaného OOM prejde do fázy Ukončená a obchodník dostane upozornenie
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number FROM contract k
              WHERE k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL
                AND contract_effective_to(k) < p_today
                AND EXISTS (SELECT 1 FROM contract_oom x
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
                               AND x.valid_from IS NOT NULL AND x.valid_to = contract_effective_to(k))
              ORDER BY k.id LOOP
      BEGIN
        SELECT * INTO v_pr FROM contract_prolong(r.id, p_today);
        IF v_pr.p_result = 'predlzena' THEN
          v_cnt := v_cnt + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'sprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s bola automaticky predĺžená do %s – Servis potvrdí produkt',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        ELSIF v_pr.p_result = 'ukoncena' THEN
          v_ended := v_ended + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'neprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s skončila %s bez prolongácie – nemá aktívne OOM, fáza Ukončená',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'prolongacia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'prolongacia', v_state, v_msg);
    v_cnt := 0;
    v_ended := 0;
  END;
  v_n := v_n || jsonb_build_object('prolongovane', v_cnt, 'ukoncene', v_ended);

  -- 4. Príznaky: „Chýba cena“ v prvom behu roka pre všetky živé zmluvy (kontrola začína 1. 1. bežného roka)
  v_cnt := 0;
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM job_run WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL
                      AND run_date >= date_trunc('year', p_today)::date AND run_date < p_today) THEN
      FOR v_id IN SELECT k.id FROM contract k
                   WHERE k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena')
                     AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= date_trunc('year', p_today)::date)
                     AND NOT k.id = ANY (v_touched)
                   ORDER BY k.id LOOP
        BEGIN
          PERFORM contract_price_missing_refresh(v_id);
          v_cnt := v_cnt + 1;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(v_id, 'priznaky', v_state, v_msg);
        END;
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'priznaky', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('chyba_cena_kontrola', v_cnt);

  -- 5. Upozornenie 4 mesiace pred koncom (firmy a výkup, odpoveď 34): raz na koniec zmluvy, iba ak niektoré
  --    Aktívne alebo Pripravované OOM ešte nemá nadväzujúcu podpísanú zmluvu
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number, k.auto_prolong, contract_effective_to(k) AS end_on FROM contract k
              WHERE k.phase = 'podpisana' AND k.type IN ('dodavka_firma_nn', 'dodavka_firma_vn', 'vykup')
                AND contract_effective_to(k) BETWEEN p_today AND (p_today + interval '4 months')::date
                AND NOT EXISTS (SELECT 1 FROM notification n
                                 WHERE n.contract_id = k.id AND n.kind = 'konci_4_mesiace' AND n.ref_date = contract_effective_to(k))
                AND EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL
                               AND x.valid_to = contract_effective_to(k)
                               AND o.status IN ('aktivne', 'pripravovane')
                               AND (o.supply_to IS NULL OR o.supply_to >= contract_effective_to(k))
                               AND NOT EXISTS (SELECT 1 FROM contract_oom y
                                                WHERE y.oom_id = x.oom_id AND y.grp = x.grp AND y.is_binding
                                                  AND y.contract_id <> k.id AND y.valid_from > x.valid_to))
              ORDER BY k.id LOOP
      BEGIN
        IF notification_add(notification_contract_users(r.id), 'konci_4_mesiace', r.id, NULL, NULL, r.end_on,
                            format('Zmluva %s končí %s – dojednaj novú zmluvu%s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                                   CASE WHEN r.auto_prolong THEN ' (inak sa automaticky predĺži s cenníkom)' ELSE '' END)) > 0 THEN
          v_cnt := v_cnt + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'upozornenia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'upozornenia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('konci_4_mesiace', v_cnt);

  -- 5b. Malý podnik nad 30 MWh (0029): regulovaní zákazníci s objemom nad 30 MWh alebo nesúladom zmluvy / XM Trade.
  --     Zmluvy do denníka; obchodník dostane upozornenie raz za rok.
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT s.company_id, s.message,
                    (SELECT array_agg(DISTINCT k.number ORDER BY k.number)
                       FROM contract k JOIN contract_oom co ON co.contract_id = k.id
                      WHERE k.company_id = s.company_id AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%'
                        AND co.valid_from <= p_today AND (co.valid_to IS NULL OR co.valid_to >= p_today)) AS numbers,
                    (SELECT k.id FROM contract k
                      WHERE k.company_id = s.company_id AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%'
                        AND k.valid_from <= p_today
                      ORDER BY k.valid_from DESC, k.number LIMIT 1) AS contract_id
               FROM small_business_volume(p_today) s
              WHERE s.state IN ('vyradit', 'nesulad')
              ORDER BY s.company_id LOOP
      BEGIN
        v_cnt := v_cnt + 1;
        v_sb := v_sb || r.numbers;
        IF r.contract_id IS NOT NULL AND NOT EXISTS (
             SELECT 1 FROM notification n JOIN contract k ON k.id = n.contract_id
              WHERE n.kind = 'maly_podnik' AND k.company_id = r.company_id
                AND n.ref_date = date_trunc('year', p_today)::date) THEN
          PERFORM notification_add(notification_contract_users(r.contract_id), 'maly_podnik', r.contract_id, NULL, NULL,
                                   date_trunc('year', p_today)::date,
                                   format('Zmluva %s: %s', (SELECT number FROM contract WHERE id = r.contract_id), r.message));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.contract_id, 'maly_podnik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'maly_podnik', v_state, v_msg);
    v_cnt := 0;
    v_sb := '{}';
  END;
  v_n := v_n || jsonb_build_object('maly_podnik', jsonb_build_object('pocet', v_cnt, 'zmluvy', to_jsonb(v_sb)));

  -- 5c. Objem zmluvy vs. XM Trade (0030): rozdiel nad 5 % – zmluvy do denníka; upozornenie obchodníkovi a schvaľovateľom
  --     cien (aj CEO) raz, znova iba pri zmene niektorého z objemov (iný text)
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT d.contract_id, d.message, k.number, k.org_id
               FROM contract_volume_diff(p_today) d JOIN contract k ON k.id = d.contract_id
              WHERE d.over
              ORDER BY k.number LOOP
      BEGIN
        v_cnt := v_cnt + 1;
        v_vol := v_vol || r.number;
        IF NOT EXISTS (SELECT 1 FROM notification n
                        WHERE n.contract_id = r.contract_id AND n.kind = 'objem_xm' AND n.detail = format('Zmluva %s: %s', r.number, r.message)) THEN
          PERFORM notification_add(notification_contract_users(r.contract_id) || notification_approvers(r.org_id, true), 'objem_xm',
                                   r.contract_id, NULL, NULL, p_today, format('Zmluva %s: %s', r.number, r.message));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.contract_id, 'objem_xm', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'objem_xm', v_state, v_msg);
    v_cnt := 0;
    v_vol := '{}';
  END;
  v_n := v_n || jsonb_build_object('objem_xm', jsonb_build_object('pocet', v_cnt, 'zmluvy', to_jsonb(v_vol)));

  -- 6. Stav zákazníka: zmluvy zmenené behom a zmluvy, ktorým od posledného behu začala alebo skončila účinnosť
  v_cnt := 0;
  IF crm_setting_on('customer_status_auto') THEN
    BEGIN
      FOR r IN SELECT DISTINCT k.company_id, k.person_id FROM contract k
                WHERE k.id = ANY (v_touched)
                   OR (k.phase = 'podpisana' AND k.valid_from > coalesce(v_last, p_today - 1) AND k.valid_from <= p_today)
                   OR (k.phase = 'podpisana' AND contract_effective_to(k) >= coalesce(v_last, p_today - 1) - 1
                       AND contract_effective_to(k) < p_today) LOOP
        BEGIN
          IF customer_refresh(r.company_id, r.person_id) THEN
            v_cnt := v_cnt + 1;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
        END;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
      v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
      v_cnt := 0;
    END;
  END IF;
  v_n := v_n || jsonb_build_object('zakaznici', v_cnt);

  v_result := v_n || jsonb_build_object('chyby', jsonb_array_length(v_err));
  UPDATE job_run SET finished_at = clock_timestamp(), result = v_result, errors = v_err WHERE id = v_run;
  IF jsonb_array_length(v_err) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT u.id FROM app_user u WHERE u.is_admin AND u.status <> 'deaktivovany'),
                             'nocny_beh_chyba', NULL, NULL, v_run, p_today,
                             format('Nočný beh zmlúv %s: %s chýb (Nastavenia → Nočný beh)',
                                    to_char(p_today, 'FMDD. FMMM. YYYY'), jsonb_array_length(v_err)));
  END IF;
  PERFORM set_config('crm.today', v_prev_today, true);
  PERFORM set_config('app.change_source', v_prev_source, true);
  RETURN v_result;
END;
$$;


--
-- Name: FUNCTION contract_daily_run_at(p_today date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_daily_run_at(p_today date) IS 'nočný beh zmlúv k dátumu – iba vlastník databázy (Cron cez contract_daily_run, ručný beh na Teste: db/test-data/zmluvy-test.sh)';


--
-- Name: contract_effective_to(public.contract); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_effective_to(c public.contract) RETURNS date
    LANGUAGE sql STABLE
    AS $$
  SELECT coalesce(c.crm_valid_to, c.valid_to)
$$;


--
-- Name: FUNCTION contract_effective_to(c public.contract); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_effective_to(c public.contract) IS 'skutočný koniec zmluvy: koniec podľa CRM (prolongácia, nástupca), inak účinnosť do z Office portálu; NULL = neurčito';


--
-- Name: contract_flag_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_flag_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  k contract;
BEGIN
  SELECT * INTO k FROM contract WHERE id = NEW.contract_id;
  PERFORM notification_add(notification_approvers(k.org_id, true), 'pod_hranicou', k.id, NULL, NULL, NULL,
                           format('Zmluva %s: cena pod hranicou bez výnimky%s', k.number,
                                  CASE WHEN NEW.year IS NOT NULL THEN format(' (rok %s)', NEW.year) ELSE '' END));
  RETURN NULL;
END;
$$;


--
-- Name: contract_flag_resolve_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_flag_resolve_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract_flag'::regclass) THEN
    RETURN NEW;
  END IF;
  IF OLD.resolved_at IS NOT NULL OR NEW.resolved_at IS NULL
     OR (NEW.contract_id, NEW.code, NEW.year, NEW.detail, NEW.raised_at)
        IS DISTINCT FROM (OLD.contract_id, OLD.code, OLD.year, OLD.detail, OLD.raised_at)
     OR NEW.resolved_by IS DISTINCT FROM crm_active_user_id() THEN
    RAISE EXCEPTION 'Príznak sa dá iba uzavrieť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.code = 'chyba_cena' THEN
    RAISE EXCEPTION '„Chýba cena“ zmizne sama, keď cena pribudne.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.code = 'pod_hranicou_bez_vynimky' THEN
    IF NOT crm_approves_prices() THEN
      RAISE EXCEPTION '„Pod hranicou bez výnimky“ uzatvára iba schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF nullif(btrim(coalesce(NEW.resolved_note, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Pri uzavretí „Pod hranicou bez výnimky“ zadajte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: contract_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  v_crm    text[] := ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'viwa_package', 'vykup_min_additive',
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
    -- minimálny aditív výkupu pri zmluve (0027, otázka 29; iba výkup – obmedzenie tabuľky): mení Nákup alebo admin
    IF NEW.vykup_min_additive IS DISTINCT FROM OLD.vykup_min_additive THEN
      IF NOT (crm_is_admin() OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                                         WHERE u.id = crm_active_user_id() AND t.code = 'nakup')) THEN
        RAISE EXCEPTION 'Minimálny aditív výkupu pri zmluve mení iba Nákup alebo admin.' USING ERRCODE = 'insufficient_privilege';
      END IF;
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


--
-- Name: contract_import_counts(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_counts(p jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
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


--
-- Name: contract_import_eic_warning(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_eic_warning(p_eic text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p_eic LIKE '24GREENVV%' THEN NULL
              WHEN p_eic !~ '^[0-9]{2}' OR substr(p_eic, 3, 1) <> 'Z'
                THEN format('EIC %s má neobvyklý tvar (nie je to kód odberného miesta) – skontrolujte.', p_eic) END
$$;


--
-- Name: contract_import_error(text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_error(p_constraint text, p_state text, p_message text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
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


--
-- Name: contract_import_fail(text[], jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_fail(p_err text[], p_miss jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF cardinality(p_err) > 0 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0090',
      MESSAGE = array_to_string(ARRAY(SELECT e FROM unnest(p_err) WITH ORDINALITY u (e, i) GROUP BY e ORDER BY min(i)), ' '),
      DETAIL = coalesce(p_miss, '[]')::text;
  END IF;
END;
$$;


--
-- Name: contract_import_label(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_label(p_list text, p_code text) RETURNS text
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT label FROM lookup_value WHERE list_code = p_list AND code = p_code ORDER BY org_id NULLS LAST LIMIT 1
$$;


--
-- Name: contract_import_one(uuid, jsonb, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_one(p_org uuid, p_rows jsonb, p_xm jsonb, p_deferred jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
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

  -- 12b. snímka ku dňu podpisu, výnimka, Pod hranicou bez výnimky, Chýba cena pre obchodníka (0027)
  v_warn := v_warn || contract_basis_refresh(v_new.id);

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


--
-- Name: contract_import_op_prices(uuid, public.contract, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_op_prices(p_org uuid, c public.contract, p_rows jsonb, p_oom jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_import_rows(uuid, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_rows(p_org uuid, p_xm jsonb, p_op jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_import_run(uuid, jsonb, jsonb, boolean, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}'::jsonb, p_expected jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
      v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
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
    v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
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


--
-- Name: FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb, p_expected jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb, p_expected jsonb) IS 'import zmlúv z Office portálu a OOM z XM Trade: náhľad (p_save = false) alebo uloženie s počtami z náhľadu';


--
-- Name: contract_import_small_business(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_small_business(p_res jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  x     jsonb;
  v_out jsonb := '[]';
  v_msg text;
BEGIN
  FOR x IN SELECT * FROM jsonb_array_elements(coalesce(p_res -> 'contracts', '[]')) LOOP
    v_msg := NULL;
    IF x ->> 'contract_id' IS NOT NULL THEN
      SELECT s.message INTO v_msg
        FROM contract k, small_business_volume(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.company_id) s
       WHERE k.id = (x ->> 'contract_id')::uuid AND k.company_id IS NOT NULL AND s.state IN ('vyradit', 'nesulad');
    END IF;
    IF v_msg IS NOT NULL THEN
      x := jsonb_set(x, '{warnings}', coalesce(x -> 'warnings', '[]') || to_jsonb(v_msg));
    END IF;
    -- objem zmluvy vs. XM Trade nad 5 % (0030)
    v_msg := NULL;
    IF x ->> 'contract_id' IS NOT NULL THEN
      SELECT d.message INTO v_msg
        FROM contract k, contract_volume_diff(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.id) d
       WHERE k.id = (x ->> 'contract_id')::uuid AND d.over;
    END IF;
    IF v_msg IS NOT NULL THEN
      x := jsonb_set(x, '{warnings}', coalesce(x -> 'warnings', '[]') || to_jsonb(v_msg));
    END IF;
    v_out := v_out || x;
  END LOOP;
  RETURN CASE WHEN p_res ? 'contracts' THEN jsonb_set(p_res, '{contracts}', v_out) ELSE p_res END;
END;
$$;


--
-- Name: contract_import_xm_code(uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_xm_code(p_org uuid, p_kind text, p_list text, p_name text, p_parent text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_import_xm_dd(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_xm_dd(p_product text) RETURNS uuid
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT p.id FROM product p,
         LATERAL (SELECT regexp_match(p_product, '^\s*VBATTERY\s*-\s*DD\s*(\d+)\s*-\s*(ANO|NIE)', 'i') AS m) x
   WHERE x.m IS NOT NULL AND p.code = 'green_dd' || x.m[1] || '_' || lower(x.m[2])
$$;


--
-- Name: contract_import_xm_from(jsonb, text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_xm_from(p_xm jsonb, p_eics text[]) RETURNS date
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT min((x ->> 'supply_from')::date)
    FROM jsonb_array_elements(coalesce(p_xm, '[]')) x
   WHERE x ->> 'eic' = ANY (p_eics) AND nullif(x ->> 'supply_from', '') IS NOT NULL
     AND jsonb_array_length(coalesce(x -> 'parse_errors', '[]')) = 0
$$;


--
-- Name: contract_import_xm_link(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_xm_link(p_contract_id uuid, p_xm jsonb) RETURNS text[]
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
    PERFORM contract_basis_refresh(c.id);
  END IF;
  RETURN v_chg;
END;
$$;


--
-- Name: contract_import_xm_one(uuid, jsonb, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_import_xm_one(p_org uuid, r jsonb, p_company uuid, p_person uuid) RETURNS jsonb
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_market_value(uuid, integer, date, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_market_value(p_org uuid, p_year integer, p_on date, p_kind text) RETURNS TABLE(value numeric, on_date date)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT CASE p_kind WHEN 'portfolio' THEN m.portfolio_eur_mwh ELSE m.spot_fve_eur_mwh END, m.on_date
    FROM market_price_daily m
   WHERE m.org_id = p_org AND m.delivery_year = p_year AND m.corrected_at IS NULL AND m.on_date <= p_on
     AND (CASE p_kind WHEN 'portfolio' THEN m.portfolio_eur_mwh ELSE m.spot_fve_eur_mwh END) IS NOT NULL
   ORDER BY m.on_date DESC
   LIMIT 1
$$;


--
-- Name: contract_oom_fill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_oom_fill() RETURNS trigger
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
     AND (TG_OP = 'INSERT' OR NOT OLD.is_binding OR OLD.valid_from IS NULL OR NEW.valid_from < OLD.valid_from
          OR (NEW.valid_to IS NULL AND OLD.valid_to IS NOT NULL) OR NEW.valid_to > OLD.valid_to
          OR NEW.oom_id <> OLD.oom_id) THEN
    PERFORM contract_oom_succession(NEW, c);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: contract_oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    org_id uuid NOT NULL,
    grp text NOT NULL,
    valid_from date,
    op_valid_to date,
    valid_to date,
    successor_id uuid,
    is_binding boolean DEFAULT false NOT NULL,
    product_id uuid,
    qty_vt_mwh numeric(12,3) DEFAULT 0 NOT NULL,
    qty_nt_mwh numeric(12,3) DEFAULT 0 NOT NULL,
    source_power_kw numeric(12,3),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    program_id uuid,
    end_fixed boolean DEFAULT false NOT NULL,
    CONSTRAINT contract_oom_grp_check CHECK ((grp = ANY (ARRAY['dodavka'::text, 'vykup_viwa'::text]))),
    CONSTRAINT contract_oom_period_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= (valid_from - 1)))),
    CONSTRAINT contract_oom_qty_nt_mwh_check CHECK ((qty_nt_mwh >= (0)::numeric)),
    CONSTRAINT contract_oom_qty_vt_mwh_check CHECK ((qty_vt_mwh >= (0)::numeric)),
    CONSTRAINT contract_oom_source_power_kw_check CHECK ((source_power_kw >= (0)::numeric)),
    CONSTRAINT contract_oom_trim_check CHECK (((successor_id IS NULL) OR (op_valid_to IS NULL) OR (valid_to >= op_valid_to)))
);


--
-- Name: TABLE contract_oom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_oom IS 'OOM v zmluve: zmluvné množstvo za rok (MWh), skutočná doba platnosti, nástupnícka zmluva';


--
-- Name: COLUMN contract_oom.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_oom.valid_to IS 'skutočný koniec OOM v zmluve: účinnosť + prolongácia, skrátený nástupcom; NULL = neurčito';


--
-- Name: COLUMN contract_oom.successor_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_oom.successor_id IS 'zmluva, ktorá na tomto OOM nastúpila a skrátila túto';


--
-- Name: COLUMN contract_oom.product_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_oom.product_id IS 'produkt dodávky pri OOM: IN GREEN 1T/2T, DDx ANO/NIE, DMPx; pri VBattery DDx z XM Trade';


--
-- Name: COLUMN contract_oom.program_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_oom.program_id IS 'program pri OOM (VBattery STANDARD, PREMIUM, MAX, AKU, V) z Office portálu';


--
-- Name: COLUMN contract_oom.end_fixed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_oom.end_fixed IS 'OOM sa pri prolongácii nepredĺžilo (nebolo Aktívne/Pripravované alebo dodávka skončila skôr); koniec zmluvy ho nepredlžuje';


--
-- Name: contract_oom_succession(public.contract_oom, public.contract); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_oom_succession(r public.contract_oom, p_new public.contract) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     record;
  v_eic text;
BEGIN
  UPDATE contract SET previous_contract_id = (
           SELECT co.contract_id FROM contract_oom co
            WHERE co.oom_id = r.oom_id AND co.grp = r.grp AND co.is_binding AND co.contract_id <> r.contract_id
              AND co.valid_to = r.valid_from - 1
            ORDER BY co.valid_to DESC LIMIT 1)
   WHERE id = r.contract_id AND previous_contract_id IS NULL
     AND EXISTS (SELECT 1 FROM contract_oom co
                  WHERE co.oom_id = r.oom_id AND co.grp = r.grp AND co.is_binding AND co.contract_id <> r.contract_id
                    AND co.valid_to = r.valid_from - 1);
  FOR o IN
    SELECT co.id, co.contract_id, co.valid_from, co.valid_to, co.op_valid_to, k.number, k.signed_on
      FROM contract_oom co JOIN contract k ON k.id = co.contract_id
     WHERE co.oom_id = r.oom_id AND co.grp = r.grp AND co.is_binding AND co.contract_id <> r.contract_id
       AND co.valid_from IS NOT NULL AND (co.valid_to IS NULL OR co.valid_to >= co.valid_from)
       AND daterange(co.valid_from, co.valid_to, '[]') && daterange(r.valid_from, r.valid_to, '[]')
  LOOP
    IF r.valid_from > o.valid_from
       AND (o.op_valid_to IS NULL OR o.op_valid_to < r.valid_from)
       AND (p_new.signed_on IS NULL OR o.signed_on IS NULL OR p_new.signed_on >= o.signed_on) THEN
      UPDATE contract_oom SET valid_to = r.valid_from - 1, successor_id = r.contract_id WHERE id = o.id;
      -- ceny starej zmluvy na tomto OOM po začiatku novej: celé obdobia preč, presahujúce skrátiť
      DELETE FROM contract_price WHERE contract_id = o.contract_id AND oom_id = r.oom_id AND valid_from >= r.valid_from;
      UPDATE contract_price SET valid_to = r.valid_from - 1
       WHERE contract_id = o.contract_id AND oom_id = r.oom_id AND (valid_to IS NULL OR valid_to >= r.valid_from);
      UPDATE contract SET previous_contract_id = o.contract_id WHERE id = r.contract_id AND previous_contract_id IS NULL;
      PERFORM contract_crm_end_refresh(o.contract_id);
      -- príznak „Sprolongované bez novej ceny“ sa uzavrie, keď má každé sprolongované OOM starej zmluvy nástupcu
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = o.contract_id AND code = 'sprolongovane_bez_ceny' AND resolved_at IS NULL
         AND NOT EXISTS (SELECT 1 FROM contract_oom x WHERE x.contract_id = o.contract_id AND x.successor_id IS NULL
                          AND x.op_valid_to IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to > x.op_valid_to));
    ELSE
      SELECT eic INTO v_eic FROM oom WHERE id = r.oom_id;
      RAISE EXCEPTION 'OOM % je v zmluve % do % – prekrytie.', v_eic, o.number,
        coalesce(to_char(o.valid_to, 'FMDD. FMMM. YYYY'), 'neurčita')
        USING ERRCODE = 'check_violation';
    END IF;
  END LOOP;
END;
$$;


--
-- Name: contract_param(uuid, text, date, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_param(p_org uuid, p_code text, p_on date, p_year smallint DEFAULT NULL::smallint) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(
    (SELECT value FROM price_parameter
      WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year AND valid_from <= p_on
      ORDER BY valid_from DESC LIMIT 1),
    (SELECT value FROM price_parameter
      WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year
      ORDER BY valid_from LIMIT 1))
$$;


--
-- Name: contract_price_canon(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_canon(p_rows jsonb) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'oom', r.oom_id, 'slot', r.slot, 'product', r.product_id, 'model', r.price_model, 'item', r.price_list_item_id,
           'from', r.valid_from, 'to', r.valid_to, 'vt', r.price_vt_eur_mwh, 'nt', r.price_nt_eur_mwh,
           'add', r.additive_eur_mwh, 'pct', r.additive_pct, 'fee', r.fee_eur_month, 'kw', r.fee_kw_eur_month,
           'vat', r.vat_rate, 'name', r.op_product_name)
           ORDER BY r.slot, r.oom_id::text NULLS FIRST, r.valid_from), '[]')
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) r
$$;


--
-- Name: contract_price_fill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_fill() RETURNS trigger
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


--
-- Name: contract_price_items(uuid, date, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_items(p_product_id uuid, p_from date, p_to date, p_list_with uuid DEFAULT NULL::uuid) RETURNS TABLE(item_id uuid, valid_from date, valid_to date)
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_price_list_row(text, uuid, uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_list_row(p_slot text, p_oom_id uuid, p_item_id uuid, p_from date, p_to date) RETURNS jsonb
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: contract_price_list_rows(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_list_rows(p_contract_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c      contract;
  co     record;
  q      record;
  s      record;
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
      FOR s IN SELECT * FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to)
                WHERE seg_product IS NOT NULL LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('komodita', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items(s.seg_product, s.seg_from, s.seg_to) p);
      END LOOP;
    END IF;
    IF c.type = 'dodavka_domacnost' AND co.oom_type = 'spotreba' AND co.product_id IS NOT NULL THEN
      FOR s IN SELECT * FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to)
                WHERE seg_product IS NOT NULL LOOP
        v_out := v_out || (SELECT coalesce(jsonb_agg(contract_price_list_row('zem', co.oom_id, p.item_id, p.valid_from, p.valid_to)), '[]')
                             FROM contract_price_items((SELECT id FROM product WHERE code = 'zem'), s.seg_from, s.seg_to,
                                                       s.seg_product) p);
      END LOOP;
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


--
-- Name: contract_price_list_sync(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_list_sync(p_contract_id uuid) RETURNS boolean
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT contract_price_set(p_contract_id, 'cennik', contract_price_list_rows(p_contract_id))
$$;


--
-- Name: FUNCTION contract_price_list_sync(p_contract_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_price_list_sync(p_contract_id uuid) IS 'ceny zmluvy z cenníkov podľa OOM v zmluve, produktov a balíka VIWA; mení iba ceny zo zdroja import s modelom cenník';


--
-- Name: contract_price_missing_refresh(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_missing_refresh(p_contract_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
  v_reg    date;
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
        -- vyradený z regulácie bez regulovaného páru produktu (malý podnik nad 30 MWh, 0029)
        v_reg := (SELECT min(s.seg_from) FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to) s
                   WHERE co.product_id IS NOT NULL AND s.seg_product IS NULL);
        IF v_reg IS NOT NULL THEN
          v_miss := v_miss || format('OOM %s: vyradený z cenovej regulácie od %s – treba novú cenu (cenník nad 30 MWh alebo individuálnu)',
                                     co.eic, to_char(v_reg, 'FMDD. FMMM. YYYY'));
        ELSE
          v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                     to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
        END IF;
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
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;


--
-- Name: contract_price_set(uuid, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_price_set(p_contract_id uuid, p_subset text, p_rows jsonb) RETURNS boolean
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_pass integer;
BEGIN
  IF contract_price_canon((SELECT coalesce(jsonb_agg(to_jsonb(cp)), '[]') FROM contract_price cp
                            WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                              AND (cp.price_model = 'cennik') = (p_subset = 'cennik')))
     = contract_price_canon(p_rows) THEN
    RETURN false;
  END IF;
  DELETE FROM contract_price cp
   WHERE cp.contract_id = p_contract_id AND cp.source = 'import' AND (cp.price_model = 'cennik') = (p_subset = 'cennik')
     AND NOT EXISTS (SELECT 1 FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
                      WHERE n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
                        AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
                        AND n.valid_from = cp.valid_from);
  FOR v_pass IN 1..2 LOOP
    UPDATE contract_price cp
       SET valid_to = n.valid_to, price_vt_eur_mwh = n.price_vt_eur_mwh, price_nt_eur_mwh = n.price_nt_eur_mwh,
           additive_eur_mwh = n.additive_eur_mwh, additive_pct = n.additive_pct, fee_eur_month = n.fee_eur_month,
           fee_kw_eur_month = n.fee_kw_eur_month, vat_rate = n.vat_rate, op_product_name = n.op_product_name
      FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
     WHERE cp.contract_id = p_contract_id AND cp.source = 'import' AND (cp.price_model = 'cennik') = (p_subset = 'cennik')
       AND n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
       AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
       AND n.valid_from = cp.valid_from
       AND (cp.valid_to, cp.price_vt_eur_mwh, cp.price_nt_eur_mwh, cp.additive_eur_mwh, cp.additive_pct, cp.fee_eur_month,
            cp.fee_kw_eur_month, cp.vat_rate, cp.op_product_name)
           IS DISTINCT FROM
           (n.valid_to, n.price_vt_eur_mwh, n.price_nt_eur_mwh, n.additive_eur_mwh, n.additive_pct, n.fee_eur_month,
            n.fee_kw_eur_month, n.vat_rate, n.op_product_name)
       AND (v_pass = 2 OR coalesce(n.valid_to, 'infinity'::date) <= coalesce(cp.valid_to, 'infinity'::date));
  END LOOP;
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, price_list_item_id, valid_from, valid_to,
                              price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month,
                              fee_kw_eur_month, vat_rate, op_product_name, source)
  SELECT p_contract_id, n.oom_id, n.slot, n.product_id, n.price_model, n.price_list_item_id, n.valid_from, n.valid_to,
         n.price_vt_eur_mwh, n.price_nt_eur_mwh, n.additive_eur_mwh, n.additive_pct, n.fee_eur_month,
         n.fee_kw_eur_month, n.vat_rate, n.op_product_name, 'import'
    FROM jsonb_populate_recordset(NULL::contract_price, coalesce(p_rows, '[]')) n
   WHERE NOT EXISTS (SELECT 1 FROM contract_price cp
                      WHERE cp.contract_id = p_contract_id AND cp.source = 'import'
                        AND n.oom_id IS NOT DISTINCT FROM cp.oom_id AND n.slot = cp.slot AND n.product_id = cp.product_id
                        AND n.price_model = cp.price_model AND n.price_list_item_id IS NOT DISTINCT FROM cp.price_list_item_id
                        AND n.valid_from = cp.valid_from);
  RETURN true;
END;
$$;


--
-- Name: contract_prolong(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_prolong(p_contract_id uuid, p_today date, OUT p_result text, OUT p_end date) RETURNS record
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  k           contract;
  co          record;
  v_end       date;
  v_target    date;
  v_next_id   uuid;
  v_next_from date;
  v_open      integer := 0;
  v_eligible  integer := 0;
BEGIN
  SELECT * INTO k FROM contract WHERE id = p_contract_id FOR UPDATE;
  v_end := contract_effective_to(k);
  IF NOT (k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL AND v_end IS NOT NULL AND v_end < p_today) THEN
    RETURN;
  END IF;
  v_target := v_end;
  WHILE v_target < p_today LOOP
    v_target := ((v_target + 1) + interval '12 months')::date - 1;
  END LOOP;

  FOR co IN SELECT x.id, x.oom_id, x.grp, x.valid_to, o.status AS oom_status, o.supply_to
              FROM contract_oom x JOIN oom o ON o.id = x.oom_id
             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
               AND x.valid_from IS NOT NULL AND x.valid_to = v_end
             ORDER BY x.id
  LOOP
    IF co.oom_status NOT IN ('aktivne', 'pripravovane') OR co.supply_to < v_end THEN
      UPDATE contract_oom SET end_fixed = true WHERE id = co.id;
      CONTINUE;
    END IF;
    v_eligible := v_eligible + 1;
    v_next_id := NULL;
    v_next_from := NULL;
    SELECT y.contract_id, y.valid_from INTO v_next_id, v_next_from FROM contract_oom y
     WHERE y.oom_id = co.oom_id AND y.grp = co.grp AND y.is_binding AND y.contract_id <> k.id AND y.valid_from > co.valid_to
     ORDER BY y.valid_from LIMIT 1;
    IF v_next_id IS NULL OR v_next_from > v_target THEN
      v_open := v_open + 1;
    ELSE
      UPDATE contract_oom SET valid_to = v_next_from - 1, successor_id = v_next_id WHERE id = co.id;
    END IF;
  END LOOP;

  IF v_eligible = 0 THEN
    UPDATE contract SET phase = 'ukoncena' WHERE id = k.id;
    PERFORM contract_price_missing_refresh(k.id);
    p_result := 'ukoncena';
    p_end := v_end;
    RETURN;
  END IF;
  IF v_open > 0 THEN
    UPDATE contract SET crm_valid_to = v_target WHERE id = k.id;
  ELSE
    PERFORM contract_crm_end_refresh(k.id);
  END IF;
  SELECT contract_effective_to(x) INTO v_target FROM contract x WHERE x.id = k.id;
  IF v_target IS NULL OR v_target <= v_end THEN
    RETURN;   -- na všetkých OOM nadväzuje iná zmluva hneď po konci (retencia)
  END IF;

  PERFORM contract_sync_checked(k.id);
  PERFORM contract_after_price_change(k.id);
  UPDATE contract_flag SET detail = format('Sprolongovaná do %s – produkt na potvrdenie', to_char(v_target, 'FMDD. FMMM. YYYY'))
   WHERE contract_id = k.id AND code = 'sprolongovane_bez_ceny' AND resolved_at IS NULL;
  IF NOT FOUND THEN
    INSERT INTO contract_flag (contract_id, code, detail)
    VALUES (k.id, 'sprolongovane_bez_ceny', format('Sprolongovaná do %s – produkt na potvrdenie', to_char(v_target, 'FMDD. FMMM. YYYY')));
  END IF;
  p_result := 'predlzena';
  p_end := v_target;
END;
$$;


--
-- Name: product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    hubspot_product_id text,
    hubspot_contract_codes text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    org_id uuid NOT NULL,
    category public.product_category NOT NULL,
    segment public.customer_segment NOT NULL,
    vat_rate numeric(5,2),
    tariff_type public.tariff_type DEFAULT 'netyka_sa'::public.tariff_type NOT NULL,
    price_models public.price_model[] NOT NULL,
    price_regulation boolean,
    status public.product_status DEFAULT 'predava_sa'::public.product_status NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    tariff_variant text,
    CONSTRAINT product_cena_diela_check CHECK ((('cena_diela'::public.price_model = ANY (price_models)) = (category = 'instalacia_fve'::public.product_category))),
    CONSTRAINT product_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,60}$'::text)),
    CONSTRAINT product_price_models_check CHECK (((cardinality(price_models) >= 1) AND (array_position(price_models, NULL::public.price_model) IS NULL))),
    CONSTRAINT product_segment_check CHECK ((segment = ANY (ARRAY['domacnost'::public.customer_segment, 'firma'::public.customer_segment]))),
    CONSTRAINT product_tariff_variant_check CHECK (((tariff_variant IS NULL) OR ((tariff_variant = 'vykurovanie'::text) AND (tariff_type = 'dvojtarif'::public.tariff_type)) OR ((tariff_variant = 'verejne_osvetlenie'::text) AND (tariff_type = 'jednotarif'::public.tariff_type)))),
    CONSTRAINT product_vat_check CHECK (((vat_rate >= (0)::numeric) AND (vat_rate <= (100)::numeric))),
    CONSTRAINT product_vat_required CHECK (((vat_rate IS NOT NULL) OR (category = 'instalacia_fve'::public.product_category)))
);


--
-- Name: TABLE product; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product IS 'katalóg produktov; ceny sú v cenníku (0020); produkt sa nemaže, iba ukončí (status)';


--
-- Name: COLUMN product.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.code IS 'nemenný kód, napr. green_dd3_nie';


--
-- Name: COLUMN product.vat_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.vat_rate IS 'sadzba DPH v % (elektrina a ZEM 19, služby 23); NULL iba inštalácia FVE (DPH podľa diela)';


--
-- Name: COLUMN product.tariff_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.tariff_type IS 'jednotarif / dvojtarif / nemeraný / netýka sa; poradie návrhu produktov podľa plánovanej spotreby NT';


--
-- Name: COLUMN product.price_models; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.price_models IS 'povolené cenové modely; individuálna cena na zmluve (modul 4) má práve jeden';


--
-- Name: COLUMN product.price_regulation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.price_regulation IS 'NULL = nezáleží; true = ANO (domácnosť s energopomocou, malý podnik), false = NIE';


--
-- Name: COLUMN product.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.status IS 'predava_sa; dobieha = existujúce zmluvy bežia, nové nie; ukonceny';


--
-- Name: COLUMN product.tariff_variant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.tariff_variant IS 'variant typu tarifu: vykurovanie (Green 2T Vykurovanie), verejne_osvetlenie (Green 1T VO, DMP10)';


--
-- Name: contract_regulated_product(public.product, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_regulated_product(p public.product, p_value boolean) RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN p.price_regulation IS NULL OR p_value IS NULL OR p_value = p.price_regulation THEN p.id
              ELSE product_regulation_pair(p.id) END
$$;


--
-- Name: contract_regulation_pair_missing(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_regulation_pair_missing(p_contract_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT string_agg(format('OOM %s: k produktu %s chýba pár pre cenovú reguláciu %s od %s', o.eic, p.name,
                           CASE WHEN p.price_regulation THEN 'NIE' ELSE 'ANO' END, to_char(s.seg_from, 'FMDD. FMMM. YYYY')),
                    '; ' ORDER BY o.eic, s.seg_from)
    FROM contract k
    JOIN contract_oom co ON co.contract_id = k.id
    JOIN oom o ON o.id = co.oom_id
    JOIN product p ON p.id = co.product_id
    CROSS JOIN LATERAL contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to) s
   WHERE k.id = p_contract_id AND k.type::text LIKE 'dodavka%' AND (k.list_price OR k.type = 'dodavka_domacnost')
     AND k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') AND o.type = 'spotreba'
     AND co.valid_from IS NOT NULL AND (co.valid_to IS NULL OR co.valid_to >= co.valid_from)
     AND p.price_regulation IS NOT NULL AND s.seg_product IS NULL
$$;


--
-- Name: contract_regulation_segments(uuid, uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_regulation_segments(p_oom_id uuid, p_product_id uuid, p_from date, p_to date) RETURNS TABLE(seg_product uuid, seg_from date, seg_to date)
    LANGUAGE plpgsql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  p      product;
  ch     record;
  v_val  boolean;
  v_prod uuid;
  v_new  uuid;
  v_from date := p_from;
BEGIN
  SELECT * INTO p FROM product WHERE id = p_product_id;
  IF p.price_regulation IS NULL THEN
    RETURN QUERY SELECT p_product_id, p_from, p_to;
    RETURN;
  END IF;
  -- regulácia na začiatku: posledná zmena do začiatku, inak hodnota pred prvou neskoršou zmenou, inak produkt bez zmeny
  SELECT x.value INTO v_val FROM oom_price_regulation_change x
   WHERE x.oom_id = p_oom_id AND x.valid_from <= p_from AND x.valid_from <= crm_today()
   ORDER BY x.valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT x.prev_value INTO v_val FROM oom_price_regulation_change x
     WHERE x.oom_id = p_oom_id AND x.valid_from > p_from AND x.valid_from <= crm_today()
     ORDER BY x.valid_from LIMIT 1;
  END IF;
  v_prod := contract_regulated_product(p, v_val);
  FOR ch IN SELECT x.valid_from, x.value FROM oom_price_regulation_change x
             WHERE x.oom_id = p_oom_id AND x.valid_from > p_from AND x.valid_from <= crm_today()
               AND (p_to IS NULL OR x.valid_from <= p_to)
             ORDER BY x.valid_from LOOP
    v_new := contract_regulated_product(p, ch.value);
    IF v_new IS DISTINCT FROM v_prod THEN
      RETURN QUERY SELECT v_prod, v_from, ch.valid_from - 1;
      v_from := ch.valid_from;
      v_prod := v_new;
    END IF;
  END LOOP;
  RETURN QUERY SELECT v_prod, v_from, p_to;
END;
$$;


--
-- Name: contract_small_business_over(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_small_business_over(p_contract_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM contract k, small_business_volume(crm_today(), k.company_id) s
                  WHERE k.id = p_contract_id AND k.company_id IS NOT NULL AND s.state IN ('vyradit', 'nesulad'))
$$;


--
-- Name: crm_today(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_today() RETURNS date
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN nullif(current_setting('crm.today', true), '') IS NOT NULL AND crm_owner_session()
              THEN current_setting('crm.today', true)::date
              ELSE (now() AT TIME ZONE 'Europe/Bratislava')::date END
$$;


--
-- Name: FUNCTION crm_today(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_today() IS 'dnes v Europe/Bratislava; v spojení vlastníka databázy testovací dátum z nastavenia crm.today (ručný nočný beh)';


--
-- Name: contract_state(public.contract, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_state(c public.contract, p_today date DEFAULT public.crm_today()) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE c.phase
           WHEN 'odmietnuta' THEN 'odmietnuta'
           WHEN 'neuspesna'  THEN 'neuspesna'
           WHEN 'ukoncena'   THEN 'skoncena'
           WHEN 'podpisana'  THEN
             CASE WHEN c.valid_from IS NULL OR c.valid_from > p_today THEN 'podpisana'
                  WHEN contract_effective_to(c) IS NOT NULL AND p_today > contract_effective_to(c) THEN 'skoncena'
                  ELSE 'ucinna' END
           ELSE 'v_priprave'
         END
$$;


--
-- Name: FUNCTION contract_state(c public.contract, p_today date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_state(c public.contract, p_today date) IS 'v_priprave, podpisana, ucinna, skoncena, odmietnuta, neuspesna';


--
-- Name: contract_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  UPDATE contract_oom
     SET valid_from = NEW.valid_from,
         op_valid_to = NEW.valid_to,
         valid_to = CASE WHEN successor_id IS NOT NULL THEN valid_to
                         WHEN end_fixed THEN least(valid_to, contract_effective_to(NEW))
                         ELSE contract_effective_to(NEW) END
   WHERE contract_id = NEW.id;
  IF NEW.phase IN ('odmietnuta', 'neuspesna') AND OLD.phase IS DISTINCT FROM NEW.phase THEN
    INSERT INTO contract_flag (contract_id, code, detail)
    SELECT DISTINCT co.contract_id, 'kontrola_importu'::contract_flag_code,
           format('Nástupnícka zmluva %s je %s – skrátenie tejto zmluvy na OOM skontrolujte.', NEW.number,
                  CASE NEW.phase WHEN 'odmietnuta' THEN 'odmietnutá' ELSE 'neúspešná' END)
      FROM contract_oom co
     WHERE co.successor_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: contract_sync_checked(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_sync_checked(p_contract_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_changed boolean := contract_price_list_sync(p_contract_id);
  v_missing text := contract_regulation_pair_missing(p_contract_id);
BEGIN
  -- malý podnik s objemom nad 30 MWh (alebo nesúladom zmluvy / XM Trade) môže byť z regulácie vyradený oprávnene:
  -- nie chyba, ale „Chýba cena“ s textom „vyradený z regulácie“ (0029, odpoveď 3)
  IF v_missing IS NOT NULL AND NOT contract_small_business_over(p_contract_id) THEN
    RAISE EXCEPTION '%', v_missing USING ERRCODE = 'check_violation';
  END IF;
  RETURN v_changed;
END;
$$;


--
-- Name: contract_viwa_package_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_viwa_package_sync() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM contract_price_list_sync(NEW.id);
  PERFORM contract_price_missing_refresh(NEW.id);
  PERFORM contract_basis_refresh(NEW.id);
  RETURN NULL;
END;
$$;


--
-- Name: contract_volume_diff(date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_volume_diff(p_on date, p_contract_id uuid DEFAULT NULL::uuid) RETURNS TABLE(contract_id uuid, contract_mwh numeric, xm_mwh numeric, diff_pct numeric, months integer, oom_count integer, oom_over integer, xm_missing integer, over boolean, message text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  WITH k AS (
    SELECT k.id, least(12, CASE WHEN contract_effective_to(k) IS NULL OR k.valid_from IS NULL THEN 12
                                ELSE ((extract(year FROM contract_effective_to(k)) - extract(year FROM k.valid_from)) * 12
                                      + extract(month FROM contract_effective_to(k)) - extract(month FROM k.valid_from) + 1)::int END) AS months
      FROM contract k
     WHERE (p_contract_id IS NULL OR k.id = p_contract_id)
       AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka%'
       AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= p_on)
  ), r AS (
    SELECT k.id, k.months, co.qty_vt_mwh + co.qty_nt_mwh AS qty,
           CASE WHEN coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0) > 0
                THEN (coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0)) * k.months / 12 END AS xm
      FROM k
      JOIN contract_oom co ON co.contract_id = k.id
      JOIN oom o ON o.id = co.oom_id
     WHERE o.type = 'spotreba' AND co.valid_from IS NOT NULL AND (co.valid_to IS NULL OR co.valid_to >= p_on)
  ), s AS (
    SELECT r.id, max(r.months) AS months, sum(r.qty) AS contract_mwh,
           CASE WHEN bool_and(r.xm IS NOT NULL) THEN sum(r.xm) END AS xm_mwh,
           count(*)::int AS oom_count,
           (count(*) FILTER (WHERE r.xm IS NOT NULL AND abs(r.qty - r.xm) > 0.05 * r.xm))::int AS oom_over,
           (count(*) FILTER (WHERE r.xm IS NULL))::int AS xm_missing
      FROM r GROUP BY r.id
  )
  SELECT s.id, s.contract_mwh, round(s.xm_mwh, 3),
         CASE WHEN s.xm_mwh > 0 THEN round((s.contract_mwh - s.xm_mwh) / s.xm_mwh * 100, 1) END,
         s.months, s.oom_count, s.oom_over, s.xm_missing,
         coalesce(s.xm_mwh > 0 AND abs(s.contract_mwh - s.xm_mwh) > 0.05 * s.xm_mwh, false),
         CASE WHEN s.xm_mwh IS NULL THEN format('XM Trade bez plánovanej spotreby pri %s z %s OOM – objem sa neporovnáva.', s.xm_missing, s.oom_count)
              ELSE format('Objem podľa zmluvy %s MWh, podľa XM Trade %s MWh%s (%s%s %%)%s – %s',
                          mwh_text(s.contract_mwh), mwh_text(s.xm_mwh),
                          CASE WHEN s.months < 12 THEN format(' za %s mesiacov', s.months) ELSE '' END,
                          CASE WHEN s.contract_mwh >= s.xm_mwh THEN '+' ELSE '−' END,
                          replace(abs(round((s.contract_mwh - s.xm_mwh) / s.xm_mwh * 100, 1))::text, '.', ','),
                          CASE WHEN s.oom_count > 1 AND s.oom_over > 0 THEN format(', rozdiel pri %s z %s OOM', s.oom_over, s.oom_count) ELSE '' END,
                          CASE WHEN abs(s.contract_mwh - s.xm_mwh) > 0.05 * s.xm_mwh
                               THEN 'rozdiel nad 5 %, overte zmluvné množstvo (ovplyvňuje pridanú hodnotu a províziu).'
                               ELSE 'v tolerancii 5 %.' END)
         END
    FROM s
$$;


--
-- Name: FUNCTION contract_volume_diff(p_on date, p_contract_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_volume_diff(p_on date, p_contract_id uuid) IS 'objem zmluvy (Office portal) vs. plánovaná spotreba OOM (XM Trade) k dňu; over = rozdiel nad 5 %; iba upozornenie';


--
-- Name: contract_year_calc(uuid, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE(year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric, added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text, basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric, portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH k AS (
  SELECT c AS rec, c.id, c.org_id, c.type, crm_can_see_margin() AS see_margin
    FROM contract c
   WHERE c.id = p_contract_id
     AND c.org_id = ANY (crm_user_orgs()) AND crm_contract_visible(c.company_id, c.person_id, c.owner_id)
),
bs AS (SELECT b.*, true AS stored FROM contract_year_basis b WHERE b.contract_id = p_contract_id AND b.year = p_year),
b AS (
  SELECT * FROM bs
  UNION ALL
  SELECT (z.v).*, false FROM (SELECT contract_basis_values(k.rec, p_year, crm_today()) AS v FROM k
                               WHERE NOT EXISTS (SELECT 1 FROM bs)) z
),
mk AS (
  SELECT (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio,
         (SELECT on_date FROM contract_market_value(k.org_id, p_year, crm_today(), 'portfolio')) AS portfolio_on,
         (SELECT value FROM contract_market_value(k.org_id, p_year, crm_today(), 'spot_fve')) AS spot_fve
    FROM k
),
mo AS (
  SELECT make_date(p_year, i, 1) AS m_start, (make_date(p_year, i, 1) + interval '1 month - 1 day')::date AS m_end
    FROM generate_series(1, 12) i
),
co AS (
  SELECT x.oom_id, x.valid_from, x.valid_to, x.qty_vt_mwh, x.qty_nt_mwh,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS power_kw, o.planned_feed_in_mwh,
         CASE WHEN x.valid_to IS NOT NULL
                   AND (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                       - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1 < 12
              THEN (extract(year FROM x.valid_to) * 12 + extract(month FROM x.valid_to))
                   - (extract(year FROM x.valid_from) * 12 + extract(month FROM x.valid_from)) + 1
              ELSE 12 END AS div
    FROM contract_oom x JOIN oom o ON o.id = x.oom_id
   WHERE x.contract_id = p_contract_id AND x.valid_from IS NOT NULL AND (x.valid_to IS NULL OR x.valid_to >= x.valid_from)
),
line AS (
  SELECT co.oom_id, mo.m_start, k.type AS ctype, p.price_model, p.price_vt_eur_mwh AS vt, p.price_nt_eur_mwh AS nt,
         p.additive_eur_mwh AS ad, p.additive_pct AS pct, pr.price_regulation AS reg,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN coalesce(co.planned_feed_in_mwh, 0) / 12 ELSE co.qty_vt_mwh / co.div END AS v_vt,
         CASE WHEN k.type IN ('vykup', 'viwa') THEN 0 ELSE co.qty_nt_mwh / co.div END AS v_nt,
         (SELECT coalesce(sum(coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * co.power_kw), 0)
            FROM (SELECT DISTINCT ON (f.slot) f.* FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.oom_id = co.oom_id
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.slot, f.valid_from DESC) f) AS fees
    FROM co
    CROSS JOIN k
    JOIN mo ON co.valid_from <= mo.m_end AND (co.valid_to IS NULL OR co.valid_to >= mo.m_start)
    LEFT JOIN LATERAL (SELECT * FROM contract_price p
                        WHERE p.contract_id = p_contract_id AND p.oom_id = co.oom_id AND p.slot = 'komodita'
                          AND p.valid_from <= mo.m_end AND (p.valid_to IS NULL OR p.valid_to >= mo.m_start)
                        ORDER BY p.valid_from DESC LIMIT 1) p ON true
    LEFT JOIN product pr ON pr.id = p.product_id
),
kl AS (
  SELECT l.*, l.v_vt + l.v_nt AS vol,
         CASE WHEN l.ctype = 'viwa' THEN 'viwa'
              WHEN l.ctype = 'vykup' THEN CASE WHEN l.price_model IS NOT NULL THEN 'vykup' END
              WHEN l.price_model = 'cennik' AND l.ctype = 'dodavka_domacnost' AND l.reg THEN 'energo'
              WHEN l.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN l.price_model::text END AS kind
    FROM line l
),
calc AS (
  SELECT kl.*,
         pv_revenue(kl.kind, kl.price_model, kl.vt, kl.nt, kl.ad, kl.pct, kl.v_vt, kl.v_nt,
                    (SELECT spot_fve FROM mk), (SELECT viwa_additive FROM b)) AS rev,
         pv_unit_cost(kl.kind, kl.price_model, kl.vt, (SELECT seller_type FROM b), (SELECT trader_price FROM b),
                      (SELECT portfolio_eur_mwh FROM b), (SELECT energopomoc_price FROM b), (SELECT min_additive FROM b),
                      (SELECT exception_value FROM b)) AS unit_cost,
         pv_unit_margin_cost(kl.kind, kl.price_model, kl.vt, (SELECT portfolio FROM mk), (SELECT energopomoc_price FROM b),
                             (SELECT min_additive FROM b), (SELECT exception_value FROM b)) AS unit_mcost
    FROM kl
),
vu AS (   -- VIWA: mesačná platba za účet (bez OOM)
  SELECT coalesce(sum(f.fee_eur_month), 0) AS fee
    FROM mo
    JOIN LATERAL (SELECT f.fee_eur_month FROM contract_price f
                   WHERE f.contract_id = p_contract_id AND f.slot = 'viwa_ucet'
                     AND f.valid_from <= mo.m_end AND (f.valid_to IS NULL OR f.valid_to >= mo.m_start)
                   ORDER BY f.valid_from DESC LIMIT 1) f ON true
),
agg AS (
  SELECT count(DISTINCT m_start)::int AS months,
         sum(vol) AS vol,
         CASE WHEN bool_and(rev IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(rev) FILTER (WHERE kind IS NOT NULL), 0) END AS rev,
         coalesce(sum(fees), 0) AS fees,
         CASE WHEN bool_and(unit_cost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_cost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS cost,
         CASE WHEN bool_and(unit_mcost IS NOT NULL) FILTER (WHERE kind IS NOT NULL) IS NOT FALSE
              THEN coalesce(sum(unit_mcost * vol) FILTER (WHERE kind IS NOT NULL), 0) END AS mcost,
         string_agg(DISTINCT kind, ',') AS model,
         CASE WHEN bool_or(kind = 'energo') THEN 'SEAS'
              WHEN bool_or(kind = 'vykup' AND price_model = 'fix') THEN 'FIX'
              WHEN bool_or(kind IN ('fix', 'cennik')) THEN 'FIX'
              WHEN bool_or(kind IN ('spot_plus_eur', 'viwa', 'vykup')) THEN 'SPOT' END AS tranche,
         CASE WHEN bool_or(kind = 'fix' AND unit_cost IS NULL) THEN 'cena pre obchodníka'
              WHEN bool_or(kind = 'cennik' AND unit_cost IS NULL) THEN 'odhad portfólia ku dňu podpisu'
              WHEN bool_or(kind = 'energo' AND unit_cost IS NULL) THEN 'nákupná cena energopomoci'
              WHEN bool_or(kind = 'viwa' AND rev IS NULL) THEN 'balík VIWA'
              WHEN bool_or(kind = 'vykup' AND price_model = 'spot_minus_pct' AND rev IS NULL) THEN 'očakávaná cena SPOT pre FVE'
              WHEN bool_or(kind IS NOT NULL AND unit_mcost IS NULL) THEN 'odhad portfólia (marža)' END AS missing
    FROM calc
)
SELECT p_year, agg.months, round(coalesce(agg.vol, 0), 3), round(agg.rev, 2), round(agg.fees + vu.fee, 2), round(agg.cost, 2),
       round(agg.rev - agg.cost, 2),
       CASE WHEN k.see_margin THEN round(agg.mcost, 2) END,
       CASE WHEN k.see_margin THEN round(agg.rev + agg.fees + vu.fee - agg.mcost, 2) END,
       agg.model, agg.tranche, b.stored, b.source, b.trader_price, b.exception_id, b.exception_value,
       CASE WHEN k.see_margin THEN mk.portfolio END, CASE WHEN k.see_margin THEN mk.portfolio_on END,
       CASE WHEN k.see_margin THEN mk.portfolio_on < crm_today() - 30 END,
       agg.missing
  FROM k CROSS JOIN agg CROSS JOIN vu CROSS JOIN mk LEFT JOIN b ON true
$$;


--
-- Name: FUNCTION contract_year_calc(p_contract_id uuid, p_year integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.contract_year_calc(p_contract_id uuid, p_year integer) IS 'ročná bilancia zmluvy: objem, výnos komodity, poplatky, pridaná hodnota, marža firmy (iba s právom), tranža; iba viditeľná zmluva';


--
-- Name: crm_active_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_active_user_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT u.id FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.id = crm_current_user_id() AND u.status = 'aktivny' AND t.archived_at IS NULL
$$;


--
-- Name: crm_approves_assignments(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_approves_assignments() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.approves_assignments)
$$;


--
-- Name: crm_approves_prices(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_approves_prices() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.approves_prices)
$$;


--
-- Name: FUNCTION crm_approves_prices(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_approves_prices() IS 'prihlásený používateľ „schvaľuje ceny“ (CEO, obchodný riaditeľ)';


--
-- Name: crm_as_system(boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_as_system(p_on boolean) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_prev text := current_setting('app.change_source', true);
BEGIN
  PERFORM set_config('app.change_source', CASE WHEN p_on THEN 'system' ELSE '' END, true);
  RETURN coalesce(v_prev, '');
END;
$$;


--
-- Name: crm_background_only(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_background_only() RETURNS void
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  IF crm_current_user_id() IS NOT NULL THEN
    RAISE EXCEPTION 'Iba pre beh na pozadí (bez prihláseného používateľa).' USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;


--
-- Name: crm_can_change_owner(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_change_owner() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = crm_active_user_id() AND (u.is_admin OR t.can_change_owner))
$$;


--
-- Name: crm_can_edit_active_oom(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_edit_active_oom() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = 'odberne_miesta' AND p.can_edit_active_oom)
$$;


--
-- Name: custom_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity public.crm_entity NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    field_type public.custom_field_type NOT NULL,
    ref_entity public.crm_entity,
    section_id uuid,
    sort_order integer DEFAULT 0 NOT NULL,
    is_required boolean DEFAULT false NOT NULL,
    show_in_list boolean DEFAULT false NOT NULL,
    filterable boolean DEFAULT false NOT NULL,
    edit_access public.field_edit_access DEFAULT 'vsetky_timy'::public.field_edit_access NOT NULL,
    org_id uuid,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_key_check CHECK ((key ~ '^[a-z][a-z0-9_]{1,62}$'::text)),
    CONSTRAINT custom_field_label_check CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT custom_field_ref_check CHECK (((field_type = 'odkaz'::public.custom_field_type) = (ref_entity IS NOT NULL)))
);


--
-- Name: COLUMN custom_field.key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.key IS 'kľúč v stĺpci custom; vznikne z názvu, nikdy sa nemení';


--
-- Name: COLUMN custom_field.field_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.field_type IS 'po prvej uloženej hodnote sa nemení';


--
-- Name: COLUMN custom_field.is_required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.is_required IS 'kontroluje API pri uložení formulára (nie databáza – staršie záznamy pole nemajú)';


--
-- Name: COLUMN custom_field.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN custom_field.archived_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.custom_field.archived_at IS 'archivované pole: údaje ostávajú, nedajú sa meniť, pole sa dá obnoviť';


--
-- Name: crm_can_edit_field(public.custom_field); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_edit_field(p_field public.custom_field) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service()
      OR (crm_active_user_id() IS NOT NULL AND CASE p_field.edit_access
            WHEN 'vsetky_timy' THEN true
            WHEN 'iba_admin'   THEN crm_is_admin()
            ELSE EXISTS (SELECT 1 FROM custom_field_team ft JOIN app_user u ON u.team_id = ft.team_id
                          WHERE ft.field_id = p_field.id AND u.id = crm_active_user_id())
          END)
$$;


--
-- Name: crm_can_import(public.crm_module); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_import(p_module public.crm_module) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = p_module AND p.can_import)
$$;


--
-- Name: crm_can_see_job_runs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_see_job_runs() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_admin()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = crm_active_user_id() AND t.code = 'nakup')
$$;


--
-- Name: crm_can_see_margin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_can_see_margin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service()
      OR crm_approves_prices()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = 'zmluvy' AND p.can_see_company_margin)
$$;


--
-- Name: FUNCTION crm_can_see_margin(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_can_see_margin() IS 'vidí maržu firmy: tím s can_see_company_margin (modul zmluvy) alebo „schvaľuje ceny“';


--
-- Name: crm_company_access(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_company_access(p_company_id uuid, p_action text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM company c
     WHERE c.id = p_company_id
       AND c.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje' AND c.owner_id = crm_active_user_id())))
$$;


--
-- Name: crm_contact_access(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contact_access(p_contact_id uuid, p_action text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM contact p
     WHERE p.id = p_contact_id
       AND p.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje'
                AND (p.owner_id = crm_active_user_id() OR crm_contact_on_own_company(p.id)))))
$$;


--
-- Name: crm_contact_on_own_company(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contact_on_own_company(p_contact_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                  WHERE cc.contact_id = p_contact_id
                    AND c.owner_id = crm_active_user_id()
                    AND c.org_id = ANY (crm_user_orgs()))
$$;


--
-- Name: crm_contract_editable(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contract_editable(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_scope('zmluvy', 'edit') = 'vsetko'
      OR (crm_scope('zmluvy', 'edit') = 'iba_svoje'
          AND (crm_customer_owned(p_company_id, p_person_id) OR p_owner_id = crm_active_user_id()))
$$;


--
-- Name: crm_contract_visible(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_contract_visible(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_sees_all_contracts()
      OR (crm_scope('zmluvy', 'view') = 'iba_svoje'
          AND (crm_customer_owned(p_company_id, p_person_id) OR p_owner_id = crm_active_user_id()))
$$;


--
-- Name: crm_current_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_current_user_id() RETURNS uuid
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN session_user::text = 'crm_public' THEN NULL
              ELSE nullif(current_setting('app.user_id', true), '')::uuid END
$$;


--
-- Name: crm_customer_owned(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_customer_owned(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM company WHERE id = p_company_id AND owner_id = crm_active_user_id())
      OR EXISTS (SELECT 1 FROM contact WHERE id = p_person_id AND owner_id = crm_active_user_id())
$$;


--
-- Name: crm_customer_owner(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_customer_owner(p_company_id uuid, p_person_id uuid) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT CASE WHEN p_company_id IS NOT NULL THEN (SELECT owner_id FROM company WHERE id = p_company_id)
              ELSE (SELECT owner_id FROM contact WHERE id = p_person_id) END
$$;


--
-- Name: crm_deal_editable(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_deal_editable(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_scope('obchod', 'edit') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
      OR (crm_scope('obchod', 'edit') = 'iba_svoje'
          AND (p_owner_id = crm_active_user_id() OR crm_customer_owned(p_company_id, p_person_id)))
$$;


--
-- Name: crm_deal_manager(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_deal_manager() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_can_change_owner() OR crm_scope('obchod', 'edit') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
$$;


--
-- Name: crm_deal_visible(uuid, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_deal_visible(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_scope('obchod', 'view') = 'vsetko'
      OR crm_approves_prices() OR crm_approves_assignments()
      OR (crm_scope('obchod', 'view') = 'iba_svoje'
          AND (p_owner_id = crm_active_user_id() OR crm_customer_owned(p_company_id, p_person_id)))
$$;


--
-- Name: crm_email_template_editor(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_email_template_editor() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_admin() OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                                    WHERE u.id = crm_active_user_id() AND t.code = 'marketing')
$$;


--
-- Name: crm_entity_table(public.crm_entity); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_entity_table(p public.crm_entity) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p WHEN 'firma' THEN 'company' WHEN 'osoba' THEN 'contact' WHEN 'oom' THEN 'oom'
                WHEN 'deal' THEN 'deal' WHEN 'zmluva' THEN 'contract' WHEN 'ponuka' THEN 'offer' END
$$;


--
-- Name: crm_external_ready(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_external_ready() RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT true
$$;


--
-- Name: crm_internal_call(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_internal_call() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'deal'::regclass)
$$;


--
-- Name: FUNCTION crm_internal_call(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_internal_call() IS 'true = beží kód databázy s právami vlastníka (funkcia / spúšťač SECURITY DEFINER, skript vlastníka), nie aplikácia ani iná rola';


--
-- Name: crm_is_admin(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_is_admin() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.is_admin)
$$;


--
-- Name: crm_is_service(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_is_service() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT crm_current_user_id() IS NULL AND NOT crm_require_user()
$$;


--
-- Name: crm_local_date(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_local_date(p_at timestamp with time zone) RETURNS date
    LANGUAGE sql STABLE
    AS $$
  SELECT (p_at AT TIME ZONE 'Europe/Bratislava')::date
$$;


--
-- Name: crm_oom_access(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_oom_access(p_oom_id uuid, p_action text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM oom o
     WHERE o.id = p_oom_id
       AND o.org_id = ANY (crm_user_orgs())
       AND (crm_scope('odberne_miesta', p_action) = 'vsetko'
            OR (crm_scope('odberne_miesta', p_action) = 'iba_svoje' AND crm_customer_owned(o.company_id, o.person_id))))
$$;


--
-- Name: crm_oom_system_step(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_oom_system_step() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT coalesce(current_setting('crm.oom_system', true), '') = 'on'
$$;


--
-- Name: crm_owner_session(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_owner_session() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT session_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'product'::regclass)
     AND current_setting('role') = 'none'
     AND NOT crm_require_user()
$$;


--
-- Name: crm_price_list_writer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_price_list_writer() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_admin() OR crm_owner_session()
$$;


--
-- Name: crm_require_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_require_user() RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT current_user = 'crm_app' OR session_user = 'crm_app'
      OR coalesce(current_setting('app.require_user', true), '') = 'on'
$$;


--
-- Name: FUNCTION crm_require_user(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_require_user() IS 'true = spojenie aplikácie: bez prihláseného používateľa nevidí nič (rola crm_app vždy, testy cez app.require_user)';


--
-- Name: crm_scope(public.crm_module, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_scope(p_module public.crm_module, p_action text) RETURNS public.access_scope
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: crm_sees_all_contracts(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_sees_all_contracts() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_scope('zmluvy', 'view') = 'vsetko' OR crm_approves_prices()
$$;


--
-- Name: FUNCTION crm_sees_all_contracts(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_sees_all_contracts() IS 'vidí všetky zmluvy a výnimky (tím „všetko“ v module zmluvy alebo „schvaľuje ceny“); použije RLS zmlúv v 0024';


--
-- Name: crm_sees_portfolio(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_sees_portfolio() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_admin() OR crm_can_see_margin()
      OR coalesce((SELECT u.seller_type = 'manazer' FROM app_user u WHERE u.id = crm_active_user_id()), false)
$$;


--
-- Name: FUNCTION crm_sees_portfolio(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.crm_sees_portfolio() IS 'odhad nákupnej ceny portfólia (hranica FIX manažéra a cenníka): admin, marža firmy, manažér (0038)';


--
-- Name: crm_session_ok(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_session_ok() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_active_user_id() IS NOT NULL
$$;


--
-- Name: crm_setting_on(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_setting_on(p_key text) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce((SELECT value = 'true'::jsonb FROM app_setting WHERE key = p_key), false)
$$;


--
-- Name: crm_settings_writer(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_settings_writer() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_is_service() OR crm_is_admin()
$$;


--
-- Name: crm_slug(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_slug(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT nullif(btrim(regexp_replace(lower(translate(p,
           'áäčďéěíĺľňóôöŕřšťúůüýžÁÄČĎÉĚÍĹĽŇÓÔÖŔŘŠŤÚŮÜÝŽ',
           'aacdeeillnooorrstuuuyzAACDEEILLNOOORRSTUUUYZ')), '[^a-z0-9]+', '_', 'g'), '_'), '')
$$;


--
-- Name: crm_user_name(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_user_name(p_user_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT name FROM app_user WHERE id = p_user_id
$$;


--
-- Name: crm_user_orgs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_user_orgs() RETURNS uuid[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT CASE
           WHEN crm_is_service() THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           WHEN EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                         WHERE u.id = crm_active_user_id() AND t.all_orgs)
             THEN (SELECT coalesce(array_agg(o.id), '{}') FROM org o)
           ELSE (SELECT coalesce(array_agg(uo.org_id), '{}') FROM app_user_org uo
                  WHERE uo.user_id = crm_active_user_id())
         END
$$;


--
-- Name: crm_user_sees_org(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.crm_user_sees_org(p_user uuid, p_org uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                  WHERE u.id = p_user
                    AND (t.all_orgs OR EXISTS (SELECT 1 FROM app_user_org uo WHERE uo.user_id = u.id AND uo.org_id = p_org)))
$$;


--
-- Name: custom_field_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_field_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
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
$_$;


--
-- Name: custom_field_option_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_field_option_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Hodnota výberu sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
END;
$$;


--
-- Name: custom_values_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.custom_values_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
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
$_$;


--
-- Name: customer_delete(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_delete(p_company_id uuid, p_person_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_name   text;
  v_links  text[];
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_delete: zadaj práve jedno z company_id / person_id';
  END IF;
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Zmazať firmu alebo osobu môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_company_id IS NOT NULL THEN
    IF NOT crm_company_access(p_company_id, 'view') THEN
      RAISE EXCEPTION 'Firma neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT name INTO v_name FROM company WHERE id = p_company_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE company_id = p_company_id) THEN 'osoby vo firme' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE company_id = p_company_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal WHERE company_id = p_company_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE company_id = p_company_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE company_id = p_company_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE company_id = p_company_id) THEN 'konverzácie' END
    ], NULL);
  ELSE
    IF NOT crm_contact_access(p_person_id, 'view') THEN
      RAISE EXCEPTION 'Osoba neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT concat_ws(' ', first_name, last_name) INTO v_name FROM contact WHERE id = p_person_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE contact_id = p_person_id) THEN 'firmy' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM deal WHERE person_id = p_person_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE person_id = p_person_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE person_id = p_person_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE contact_id = p_person_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE contact_id = p_person_id) THEN 'konverzácie' END,
      CASE WHEN EXISTS (SELECT 1 FROM consent WHERE contact_id = p_person_id) THEN 'súhlasy' END,
      CASE WHEN EXISTS (SELECT 1 FROM voucher WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM referral WHERE referrer_contact_id = p_person_id) THEN 'poukážky a odporúčania' END,
      CASE WHEN EXISTS (SELECT 1 FROM web_event WHERE contact_id = p_person_id) THEN 'udalosti z webu' END
    ], NULL);
  END IF;

  IF cardinality(v_links) > 0 THEN
    RAISE EXCEPTION 'Záznam má väzby (%), nedá sa zmazať – iba archivovať.', array_to_string(v_links, ', ')
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_company_id IS NOT NULL THEN
    DELETE FROM company WHERE id = p_company_id;
  ELSE
    DELETE FROM contact WHERE id = p_person_id;
  END IF;
  RETURN v_name;
END;
$$;


--
-- Name: customer_import_flag_clear(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_import_flag_clear() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: customer_is_former_calc(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_is_former_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS (SELECT 1 FROM oom_customer l
                  WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                    AND l.person_id IS NOT DISTINCT FROM p_person_id
                    AND l.end_reason = 'odchod')
$$;


--
-- Name: customer_is_producer_calc(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_is_producer_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT EXISTS (SELECT 1 FROM oom_customer l JOIN oom o ON o.id = l.oom_id
                  WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                    AND l.person_id IS NOT DISTINCT FROM p_person_id
                    AND o.type = 'vyroba'
                    AND l.status IN ('aktivne', 'pripravovane', 'odidene'))
      OR EXISTS (SELECT 1 FROM deal d
                   JOIN pipeline pl ON pl.id = d.pipeline_id
                   JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
                  WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                    AND d.person_id IS NOT DISTINCT FROM p_person_id
                    AND pl.kind = 'b2b_vykup'
                    AND s.outcome IN ('otvoreny', 'vyhrany'))
$$;


--
-- Name: customer_org_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_org_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.org_id IS DISTINCT FROM OLD.org_id AND (
       (TG_TABLE_NAME = 'company' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE company_id = OLD.id)))
    OR (TG_TABLE_NAME = 'contact' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE person_id = OLD.id)))) THEN
    RAISE EXCEPTION 'Spoločnosť sa nedá zmeniť, záznam má väzby (osoby, OOM, dealy, zmluvy).'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: customer_refresh(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_refresh(p_company_id uuid, p_person_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_status   customer_status;
  v_former   boolean;
  v_producer boolean;
  v_prev     text;
  v_changed  boolean;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_refresh: zadaj práve jedno z company_id / person_id';
  END IF;
  v_status   := customer_status_calc(p_company_id, p_person_id, crm_today());
  v_former   := customer_is_former_calc(p_company_id, p_person_id);
  v_producer := customer_is_producer_calc(p_company_id, p_person_id);
  v_prev     := crm_as_system(true);

  IF p_company_id IS NOT NULL THEN
    UPDATE company c
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = c.is_former_customer OR v_former, is_producer = v_producer
     WHERE c.id = p_company_id AND c.is_customer
       AND (c.status, c.status_source, c.is_former_customer, c.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, c.is_former_customer OR v_former, v_producer);
  ELSE
    UPDATE contact p
       SET status = v_status, status_source = 'vypocet',
           is_former_customer = p.is_former_customer OR v_former, is_producer = v_producer
     WHERE p.id = p_person_id AND p.is_household
       AND (p.status, p.status_source, p.is_former_customer, p.is_producer)
           IS DISTINCT FROM (v_status, 'vypocet'::status_source, p.is_former_customer OR v_former, v_producer);
  END IF;
  v_changed := FOUND;

  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_changed;
END;
$$;


--
-- Name: customer_refresh_all(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_refresh_all() RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_id uuid;
  v_n  integer := 0;
BEGIN
  FOR v_id IN SELECT id FROM company WHERE is_customer LOOP
    IF customer_refresh(v_id, NULL) THEN v_n := v_n + 1; END IF;
  END LOOP;
  FOR v_id IN SELECT id FROM contact WHERE is_household LOOP
    IF customer_refresh(NULL, v_id) THEN v_n := v_n + 1; END IF;
  END LOOP;
  RETURN v_n;
END;
$$;


--
-- Name: customer_status_calc(uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_status_calc(p_company_id uuid, p_person_id uuid, p_today date DEFAULT ((now() AT TIME ZONE 'Europe/Bratislava'::text))::date) RETURNS public.customer_status
    LANGUAGE plpgsql STABLE
    AS $$
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_status_calc: zadaj práve jedno z company_id / person_id';
  END IF;

  -- 1. aspoň jedno OOM Aktívne
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'aktivne') THEN
    RETURN 'zakaznik';
  END IF;

  -- 2. OOM Pripravované alebo podpísaná zmluva (fáza z Office portálu, 0025) s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'pripravovane')
     OR EXISTS (SELECT 1 FROM contract c
                 WHERE c.company_id IS NOT DISTINCT FROM p_company_id
                   AND c.person_id IS NOT DISTINCT FROM p_person_id
                   AND c.phase = 'podpisana'
                   AND c.valid_from > p_today) THEN
    RETURN 'cakajuci_zakaznik';
  END IF;

  -- 3. a 4. otvorený deal s odoslanou ponukou / bez nej
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
               JOIN offer f ON f.deal_id = d.id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed
                AND f.sent_at IS NOT NULL) THEN   -- 0036: iba odoslaná ponuka (Pripravená ešte nie)
    RETURN 'ponuka';
  END IF;
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed) THEN
    RETURN 'zaujemca';
  END IF;

  -- 5. aspoň jedno OOM Odídené
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'odidene') THEN
    RETURN 'byvaly_zakaznik';
  END IF;

  -- 6. má OOM a všetky sú Zrušené alebo Prepísané
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id) THEN
    RETURN 'zruseny_zakaznik';
  END IF;

  -- 7. inak (aj záujemca, ktorému deal prepadol a nikdy nebol zákazník)
  RETURN 'marketingovy_kontakt';
END;
$$;


--
-- Name: customer_status_track(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_status_track() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_is_customer boolean := CASE TG_TABLE_NAME
                             WHEN 'company' THEN (to_jsonb(NEW) ->> 'is_customer')::boolean
                             ELSE (to_jsonb(NEW) ->> 'is_household')::boolean
                           END;
BEGIN
  IF v_is_customer AND NEW.status IS NULL THEN
    NEW.status := 'marketingovy_kontakt';
    NEW.status_source := 'vypocet';
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS NOT NULL AND NEW.status_changed_at IS NULL THEN
      NEW.status_changed_at := now();
    END IF;
  ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
    NEW.status_changed_at := now();
  END IF;

  IF NEW.status = 'byvaly_zakaznik' THEN
    NEW.is_former_customer := true;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: deal_after_change(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_after_change() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_contact_org_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_contact_org_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF (SELECT org_id FROM deal WHERE id = NEW.deal_id) <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a deal patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: deal_contact_roles_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_contact_roles_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_daily_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_daily_run() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT deal_daily_run_at(crm_today())
$$;


--
-- Name: deal_daily_run_at(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_rem  integer := 0;
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
  -- pripomienka platnosti: odoslaná / otvorená ponuka bez FIX (SPOT, VIWA), od 2. pracovného dňa pred koncom platnosti
  FOR r IN
    SELECT o.id FROM offer o
     WHERE o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL
       AND (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date > p_today
       AND p_today >= working_days_before(o.org_id, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date, 2)
       AND NOT EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia', 'cennik'))
       AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('spot', 'viwa'))
       AND NOT EXISTS (SELECT 1 FROM email_message m WHERE m.offer_id = o.id AND m.kind = 'pripomienka_platnosti')
     ORDER BY o.id
  LOOP
    IF email_reminder_draft(r.id) IS NOT NULL THEN
      v_rem := v_rem + 1;
    END IF;
  END LOOP;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem);
END;
$$;


--
-- Name: deal_event_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_event_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF OLD.offer_id IS NOT NULL AND NEW.offer_id IS NULL AND (to_jsonb(NEW) - 'offer_id') = (to_jsonb(OLD) - 'offer_id') THEN
    RETURN NEW;
  END IF;
  RAISE EXCEPTION 'Udalosti časovej osi sa nemenia ani nemažú.' USING ERRCODE = 'check_violation';
END;
$$;


--
-- Name: offer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    version smallint DEFAULT 1 NOT NULL,
    status public.offer_status DEFAULT 'koncept'::public.offer_status NOT NULL,
    valid_until timestamp with time zone,
    sent_at timestamp with time zone,
    hubspot_quote_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    number text NOT NULL,
    kind public.offer_kind NOT NULL,
    language public.offer_language DEFAULT 'sk'::public.offer_language NOT NULL,
    household boolean DEFAULT false NOT NULL,
    contact_id uuid,
    priced_on date DEFAULT public.crm_today() NOT NULL,
    seller_type public.seller_type,
    valid_shortened boolean DEFAULT false NOT NULL,
    sent_by uuid,
    sent_channel public.offer_send_channel,
    sent_note text,
    rejected_at timestamp with time zone,
    rejected_note text,
    replaced_by_id uuid,
    created_by uuid,
    penalty_eur_mwh numeric(12,2),
    template_version_id uuid,
    pdf_key text,
    pdf_sha256 text,
    pdf_generated_at timestamp with time zone,
    link_hash text,
    link_created_at timestamp with time zone,
    link_created_by uuid,
    blocked_by_offer_id uuid,
    CONSTRAINT offer_link_hash_check CHECK (((link_hash IS NULL) OR (link_hash ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT offer_number_check CHECK ((number ~ '^P[0-9]{2}-[0-9]{6}$'::text)),
    CONSTRAINT offer_pdf_check CHECK (((pdf_key IS NULL) = (pdf_sha256 IS NULL))),
    CONSTRAINT offer_pdf_key_check CHECK (((pdf_key IS NULL) OR (pdf_key ~ '^ponuky/[0-9a-f-]{36}/[0-9]{4}/P[0-9]{2}-[0-9]{6}(-[0-9]+)?\.pdf$'::text))),
    CONSTRAINT offer_pdf_sha256_check CHECK (((pdf_sha256 IS NULL) OR (pdf_sha256 ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT offer_penalty_eur_mwh_check CHECK (((penalty_eur_mwh IS NULL) OR ((penalty_eur_mwh >= (0)::numeric) AND (penalty_eur_mwh <= (10000)::numeric)))),
    CONSTRAINT offer_sent_channel_check CHECK (((sent_at IS NULL) = (sent_channel IS NULL))),
    CONSTRAINT offer_sent_check CHECK (((status = ANY (ARRAY['koncept'::public.offer_status, 'caka_na_schvalenie'::public.offer_status, 'pripravena'::public.offer_status])) OR (sent_at IS NOT NULL))),
    CONSTRAINT offer_version_check CHECK ((version > 0))
);


--
-- Name: COLUMN offer.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.valid_until IS 'koniec platnosti 16:00 Europe/Bratislava – určí sa pri odoslaní';


--
-- Name: COLUMN offer.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN offer.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.org_id IS 'preberá sa od dealu';


--
-- Name: COLUMN offer.number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.number IS 'P26-000123 – rovnaké pre všetky verzie; verzia sa zobrazí ako /2';


--
-- Name: COLUMN offer.priced_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.priced_on IS 'deň snímky cien pre obchodníka a parametrov (vytvorenie verzie alebo prepočet)';


--
-- Name: COLUMN offer.penalty_eur_mwh; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.penalty_eur_mwh IS 'zmluvná pokuta €/MWh v záväznej objednávke; NULL = zo šablóny (dodávka 50, výkup 30)';


--
-- Name: COLUMN offer.link_hash; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.link_hash IS 'SHA-256 tokenu odkazu na stránku ponuky – samotný odkaz sa v databáze neuchováva';


--
-- Name: COLUMN offer.blocked_by_offer_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer.blocked_by_offer_id IS 'rozpracovaná verzia zablokovaná akceptáciou inej verzie; odblokuje iba vlastník obchodu alebo admin';


--
-- Name: deal_event_offer(public.offer, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_event_offer(o public.offer, p_kind text, p_detail jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, offer_id, detail)
  VALUES (o.deal_id, o.org_id, p_kind, crm_current_user_id(), o.id,
          jsonb_build_object('number', o.number, 'version', o.version) || coalesce(p_detail, '{}'))
$$;


--
-- Name: deal_events(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_events() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_is_renewal_of(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_is_renewal_of(p_deal_id uuid, p_oom_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM deal d JOIN contract_oom k ON k.contract_id = d.previous_contract_id
                  WHERE d.id = p_deal_id AND d.source_code = 'obnova' AND k.oom_id = p_oom_id)
$$;


--
-- Name: deal_kind_group(public.deal_kind); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_kind_group(p_kind public.deal_kind) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p_kind IN ('b2b_vykup', 'green_viwa') THEN 'vykup_viwa' ELSE 'dodavka' END
$$;


--
-- Name: deal_link_events(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_link_events() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_oom_conflict(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_oom_conflict(p_deal_id uuid, p_oom_id uuid) RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT x.owner_id
    FROM deal d JOIN pipeline p ON p.id = d.pipeline_id,
         deal_oom dx JOIN deal x ON x.id = dx.deal_id JOIN pipeline px ON px.id = x.pipeline_id
   WHERE d.id = p_deal_id AND dx.oom_id = p_oom_id AND x.id <> d.id AND x.closed_at IS NULL
     AND deal_kind_group(px.kind) = deal_kind_group(p.kind)
     AND NOT deal_is_renewal_of(x.id, p_oom_id)
     AND NOT deal_is_renewal_of(d.id, p_oom_id)
   LIMIT 1
$$;


--
-- Name: deal_oom_ready(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_oom_ready(p_deal_id uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_oom_ready_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_oom_ready_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_oom_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_oom_rules() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: deal_reopen(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_reopen(p_deal_id uuid, p_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: deal_rules(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_rules() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: deal_stage_needs_oom(public.deal_stage_code); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.deal_stage_needs_oom(p_code public.deal_stage_code) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT p_code IN ('cenova_ponuka', 'vyjednavanie', 'akceptacia', 'vyhrane')
$$;


--
-- Name: doc_number_next(uuid, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.doc_number_next(p_org uuid, p_kind text, p_year integer) RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  INSERT INTO doc_counter (org_id, kind, year, last_value) VALUES (p_org, p_kind, p_year, 1)
  ON CONFLICT (org_id, kind, year) DO UPDATE SET last_value = doc_counter.last_value + 1
  RETURNING last_value
$$;


--
-- Name: eic_is_valid(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.eic_is_valid(p text) RETURNS boolean
    LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE
    AS $_$
DECLARE
  v_chars constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';
  v_sum   integer := 0;
BEGIN
  IF p IS NULL OR p !~ '^[0-9A-Z-]{15}[0-9A-Z]$' THEN
    RETURN false;
  END IF;
  FOR i IN 1..15 LOOP
    v_sum := v_sum + (strpos(v_chars, substr(p, i, 1)) - 1) * (17 - i);
  END LOOP;
  RETURN substr(v_chars, 36 - (((v_sum - 1) % 37 + 37) % 37) + 1, 1) = substr(p, 16, 1);
END;
$_$;


--
-- Name: FUNCTION eic_is_valid(p text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.eic_is_valid(p text) IS 'formát a kontrolná číslica EIC podľa ENTSO-E';


--
-- Name: email_addr_list_ok(jsonb, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_addr_list_ok(p jsonb, p_max integer) RETURNS boolean
    LANGUAGE sql IMMUTABLE
    AS $_$
  SELECT jsonb_typeof(p) = 'array' AND jsonb_array_length(p) <= p_max
     AND NOT EXISTS (SELECT 1 FROM jsonb_array_elements(p) e
                      WHERE jsonb_typeof(e) <> 'string' OR length(e #>> '{}') > 254
                         OR (e #>> '{}') !~ '^[^@[:space:]<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
$_$;


--
-- Name: email_compose_offer(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_compose_offer(p_offer uuid, p_code text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o    offer := offer_for_edit(p_offer);
  code text := coalesce(p_code, 'ponuka_' || o.kind);
  t    email_template_version;
  vars jsonb := email_offer_vars(p_offer);
BEGIN
  IF code NOT IN ('ponuka_dodavka', 'ponuka_vykup', 'ponuka_viwa', 'pripomienka_platnosti', 'volny') THEN
    RAISE EXCEPTION 'Neznámy druh e-mailu.' USING ERRCODE = 'check_violation';
  END IF;
  t := email_template_current(o.org_id, code, o.language);
  IF t.id IS NULL THEN
    RAISE EXCEPTION 'Šablóna e-mailu ešte nie je schválená – admin alebo Marketing ju zverejní v Nastaveniach → Šablóny e-mailov.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN jsonb_build_object(
    'template_version_id', t.id, 'code', code, 'language', t.language,
    'subject', email_fill(t.subject, vars), 'body', email_fill(t.body, vars),
    'to', email_offer_recipients(p_offer), 'vars', vars);
END;
$$;


--
-- Name: email_confirmation_queue(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_confirmation_queue(p_acceptance uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a      offer_acceptance;
  o      offer;
  d      deal;
  u      app_user;
  tpl    email_template_version;
  vars   jsonb;
  v_to   jsonb;
  v_box  uuid;
  v_th   uuid;
  v      uuid;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_acceptance;
  IF a.id IS NULL OR a.confirmation_pdf_key IS NULL OR a.revoked_at IS NOT NULL OR NOT a.send_confirmation
     OR EXISTS (SELECT 1 FROM email_message WHERE acceptance_id = a.id AND kind = 'potvrdenie_akceptacie') THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE id = a.offer_id;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  v_to := email_offer_recipients(o.id);
  tpl := email_template_current(o.org_id, 'potvrdenie_akceptacie', o.language);
  IF jsonb_array_length(v_to) = 0 OR tpl.id IS NULL THEN
    RETURN NULL;
  END IF;
  v_box := CASE WHEN u.status = 'aktivny' AND u.gmail_enabled THEN u.id END;
  vars := email_offer_vars(o.id) || jsonb_build_object(
            'variant', (SELECT name FROM offer_variant WHERE id = a.variant_id),
            'dátum akceptácie', email_fmt_time(a.accepted_at, o.language));
  v_th := email_thread_for_offer(o.id, v_box, email_fill(tpl.subject, vars), NULL);
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, acceptance_id, template_version_id,
                             from_addr, reply_to, to_addrs, subject, body_text, attachments)
  VALUES (o.org_id, v_th, 'odchadzajuca', 'v_rade', 'potvrdenie_akceptacie', o.id, a.id, tpl.id,
          CASE WHEN v_box IS NOT NULL THEN lower(u.email) ELSE 'crm@greenlogy.com' END,
          CASE WHEN v_box IS NULL AND u.status = 'aktivny' THEN lower(u.email) END,
          v_to, email_fill(tpl.subject, vars), email_fill(tpl.body, vars),
          jsonb_build_array(jsonb_build_object('kind', 'potvrdenie', 'key', a.confirmation_pdf_key, 'sha256', a.confirmation_pdf_sha256)))
  RETURNING id INTO v;
  RETURN v;
END;
$$;


--
-- Name: email_draft_delete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_draft_delete(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  m email_message;
  t email_thread;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
  IF m.id IS NULL OR m.status <> 'koncept' OR crm_active_user_id() IS NULL
     OR NOT (m.created_by = crm_active_user_id() OR (m.created_by IS NULL AND t.mailbox_user_id = crm_active_user_id())) THEN
    RAISE EXCEPTION 'Koncept neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.kind = 'pripomienka_platnosti' THEN
    -- pripomienka sa nepripraví znova (jedna na ponuku): koncept ostane ako vybavený
    UPDATE email_message SET status = 'chyba', error = 'zahodené obchodníkom' WHERE id = m.id;
    RETURN;
  END IF;
  DELETE FROM email_message WHERE id = m.id;
  IF NOT EXISTS (SELECT 1 FROM email_message WHERE thread_id = t.id) THEN
    DELETE FROM email_thread WHERE id = t.id;
  END IF;
END;
$$;


--
-- Name: email_draft_save(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_draft_save(p_id uuid, p jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  me     uuid := crm_active_user_id();
  m      email_message;
  t      email_thread;
  o      offer;
  d      deal;
  v_kind text := coalesce(p->>'kind', 'volny');
  v_to   jsonb := coalesce(p->'to', '[]');
  v_cc   jsonb := coalesce(p->'cc', '[]');
  v_th   uuid;
BEGIN
  IF me IS NULL THEN
    RAISE EXCEPTION 'Prihláste sa.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT email_addr_list_ok(v_to, 50) OR NOT email_addr_list_ok(v_cc, 50) THEN
    RAISE EXCEPTION 'Neplatná e-mailová adresa príjemcu.' USING ERRCODE = 'check_violation';
  END IF;
  IF length(coalesce(p->>'subject', '')) > 998 OR length(coalesce(p->>'body', '')) > 200000 THEN
    RAISE EXCEPTION 'Predmet alebo text e-mailu je príliš dlhý.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_id IS NOT NULL THEN
    SELECT m2.* INTO m FROM email_message m2 WHERE m2.id = p_id FOR UPDATE;
    SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
    IF m.id IS NULL OR m.status <> 'koncept'
       OR NOT (m.created_by = me OR (m.created_by IS NULL AND t.mailbox_user_id = me)) THEN
      RAISE EXCEPTION 'Koncept neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    UPDATE email_message SET to_addrs = v_to, cc_addrs = v_cc, subject = coalesce(p->>'subject', ''),
                             body_text = coalesce(p->>'body', ''), created_by = me, error = NULL
     WHERE id = m.id;
    RETURN m.id;
  END IF;

  IF v_kind NOT IN ('ponuka', 'volny', 'pripomienka_platnosti') THEN
    RAISE EXCEPTION 'Tento druh e-mailu pripravuje CRM samo.' USING ERRCODE = 'check_violation';
  END IF;
  IF p->>'template_version_id' IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM email_template_version WHERE id = (p->>'template_version_id')::uuid AND org_id = ANY (crm_user_orgs())) THEN
    RAISE EXCEPTION 'Neznáma šablóna e-mailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF p->>'offer_id' IS NOT NULL THEN
    o := offer_for_edit((p->>'offer_id')::uuid);
    IF v_kind = 'ponuka' AND o.status <> 'pripravena' THEN
      RAISE EXCEPTION 'E-mailom sa dá odoslať iba pripravená ponuka.' USING ERRCODE = 'check_violation';
    END IF;
    v_th := email_thread_for_offer(o.id, me, p->>'subject', me);
  ELSIF v_kind = 'ponuka' THEN
    RAISE EXCEPTION 'Chýba ponuka.' USING ERRCODE = 'check_violation';
  ELSIF p->>'thread_id' IS NOT NULL THEN
    SELECT * INTO t FROM email_thread WHERE id = (p->>'thread_id')::uuid;
    IF t.id IS NULL OR NOT email_thread_visible(t.id) OR t.mailbox_user_id IS DISTINCT FROM me THEN
      RAISE EXCEPTION 'Odpovedať sa dá iba vo vlákne vlastnej schránky.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    v_th := t.id;
  ELSIF p->>'deal_id' IS NOT NULL THEN
    SELECT * INTO d FROM deal WHERE id = (p->>'deal_id')::uuid;
    IF d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
      RAISE EXCEPTION 'Obchod neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, deal_id, company_id, person_id, subject, created_by)
    VALUES (d.org_id, me, d.id, d.company_id, d.person_id, coalesce(p->>'subject', ''), me) RETURNING id INTO v_th;
  ELSIF p->>'company_id' IS NOT NULL THEN
    IF NOT crm_company_access((p->>'company_id')::uuid, 'view') THEN
      RAISE EXCEPTION 'Firma neexistuje alebo ju nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, company_id, subject, created_by)
    SELECT c.org_id, me, c.id, coalesce(p->>'subject', ''), me FROM company c WHERE c.id = (p->>'company_id')::uuid
    RETURNING id INTO v_th;
  ELSIF p->>'person_id' IS NOT NULL THEN
    IF NOT crm_contact_access((p->>'person_id')::uuid, 'view') THEN
      RAISE EXCEPTION 'Kontakt neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    INSERT INTO email_thread (org_id, mailbox_user_id, person_id, subject, created_by)
    SELECT k.org_id, me, k.id, coalesce(p->>'subject', ''), me FROM contact k WHERE k.id = (p->>'person_id')::uuid
    RETURNING id INTO v_th;
  ELSE
    RAISE EXCEPTION 'E-mail musí patriť k obchodu, firme alebo kontaktu.' USING ERRCODE = 'check_violation';
  END IF;

  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, template_version_id, to_addrs, cc_addrs,
                             subject, body_text, created_by)
  SELECT t2.org_id, t2.id, 'odchadzajuca', 'koncept', v_kind, o.id, (p->>'template_version_id')::uuid, v_to, v_cc,
         coalesce(p->>'subject', ''), coalesce(p->>'body', ''), me
    FROM email_thread t2 WHERE t2.id = v_th
  RETURNING id INTO v_th;
  RETURN v_th;
END;
$$;


--
-- Name: email_fill(text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_fill(p_text text, p_vars jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  k text;
  v text;
  r text := coalesce(p_text, '');
BEGIN
  FOR k, v IN SELECT key, value FROM jsonb_each_text(coalesce(p_vars, '{}')) LOOP
    r := replace(r, '«' || k || '»', coalesce(v, ''));
  END LOOP;
  RETURN r;
END;
$$;


--
-- Name: email_fmt_time(timestamp with time zone, public.offer_language); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_fmt_time(p timestamp with time zone, p_lang public.offer_language) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT to_char(p AT TIME ZONE 'Europe/Bratislava', CASE p_lang WHEN 'en' THEN 'DD/MM/YYYY, HH24:MI' ELSE 'DD. MM. YYYY, HH24:MI' END)
$$;


--
-- Name: email_message_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_message_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF crm_owner_session() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'koncept' THEN
      RAISE EXCEPTION 'Zmazať sa dá iba koncept e-mailu.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND OLD.status IN ('odoslany', 'prijaty')
     AND (NEW.status, NEW.subject, NEW.body_text, NEW.body_html, NEW.to_addrs, NEW.cc_addrs, NEW.from_addr, NEW.attachments,
          NEW.gmail_message_id, NEW.sent_at, NEW.received_at, NEW.thread_id)
         IS DISTINCT FROM (OLD.status, OLD.subject, OLD.body_text, OLD.body_html, OLD.to_addrs, OLD.cc_addrs, OLD.from_addr,
                           OLD.attachments, OLD.gmail_message_id, OLD.sent_at, OLD.received_at, OLD.thread_id) THEN
    RAISE EXCEPTION 'Odoslaný alebo prijatý e-mail sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: email_message_received(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_message_received(p_thread uuid, p jsonb) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t     email_thread;
  v     uuid;
  v_in  boolean := coalesce(p->>'direction', 'prichadzajuca') = 'prichadzajuca';
  v_at  timestamptz := least(coalesce((p->>'at')::timestamptz, now()), now());
BEGIN
  PERFORM crm_background_only();
  SELECT * INTO t FROM email_thread WHERE id = p_thread FOR UPDATE;
  IF t.id IS NULL OR t.gmail_thread_id IS NULL THEN
    RAISE EXCEPTION 'Neznáme vlákno.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT id INTO v FROM email_message WHERE thread_id = t.id AND gmail_message_id = p->>'gmail_message_id';
  IF v IS NOT NULL THEN
    RETURN v;
  END IF;
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, from_addr, from_name, to_addrs, cc_addrs,
                             subject, body_text, body_html, attachments, gmail_message_id, rfc_message_id, sent_at, received_at)
  VALUES (t.org_id, t.id, CASE WHEN v_in THEN 'prichadzajuca' ELSE 'odchadzajuca' END,
          CASE WHEN v_in THEN 'prijaty' ELSE 'odoslany' END::email_status, CASE WHEN v_in THEN 'odpoved' ELSE 'volny' END,
          t.offer_id, lower(nullif(btrim(p->>'from'), '')), left(nullif(btrim(p->>'from_name'), ''), 200),
          coalesce(p->'to', '[]'), coalesce(p->'cc', '[]'), left(coalesce(p->>'subject', ''), 998),
          left(coalesce(p->>'body_text', ''), 200000), p->>'body_html', coalesce(p->'attachments', '[]'),
          p->>'gmail_message_id', left(nullif(btrim(p->>'rfc_message_id'), ''), 998),
          CASE WHEN NOT v_in THEN v_at END, CASE WHEN v_in THEN v_at END)
  RETURNING id INTO v;
  UPDATE email_thread SET last_message_at = greatest(last_message_at, v_at),
                          watch_until = CASE WHEN v_in THEN greatest(watch_until, (v_at AT TIME ZONE 'Europe/Bratislava')::date + 30)
                                             ELSE watch_until END
   WHERE id = t.id;
  IF v_in THEN
    PERFORM notification_add_deal(ARRAY[t.mailbox_user_id], 'ponuka_odpoved', t.deal_id, NULL, NULL,
      'Odpoveď na e-mail' || coalesce(' k ponuke ' || (SELECT offer_display_number(x) FROM offer x WHERE x.id = t.offer_id), ''));
  END IF;
  RETURN v;
END;
$$;


--
-- Name: email_message_visible(uuid, public.email_status, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_message_visible(p_thread uuid, p_status public.email_status, p_created_by uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT email_thread_visible(p_thread)
     AND (p_status <> 'koncept' OR p_created_by = crm_active_user_id()
          OR (p_created_by IS NULL AND EXISTS (SELECT 1 FROM email_thread t WHERE t.id = p_thread
                                                  AND t.mailbox_user_id = crm_active_user_id())))
$$;


--
-- Name: email_offer_recipients(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_offer_recipients(p_offer uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(
    (SELECT m.to_addrs FROM email_message m JOIN offer x ON x.id = m.offer_id JOIN offer o ON o.id = p_offer
      WHERE x.org_id = o.org_id AND x.number = o.number AND m.kind = 'ponuka' AND m.status = 'odoslany'
      ORDER BY m.sent_at DESC LIMIT 1),
    (SELECT jsonb_build_array(lower(btrim(k.email))) FROM offer o JOIN deal d ON d.id = o.deal_id
       JOIN contact k ON k.id = coalesce(o.contact_id, d.person_id)
      WHERE o.id = p_offer AND email_addr_list_ok(jsonb_build_array(lower(btrim(k.email))), 1)),
    '[]')
$$;


--
-- Name: email_offer_vars(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_offer_vars(p_offer uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'oslovenie', email_salutation(coalesce(o.contact_id, d.person_id), o.language),
           'názov zákazníka', coalesce(c.name, btrim(p.first_name || ' ' || p.last_name)),
           'číslo ponuky', offer_display_number(o),
           'zhrnutie variantov', offer_variants_summary_text(o.id),
           'obchodník', u.name)
    FROM offer o
    JOIN deal d ON d.id = o.deal_id
    JOIN app_user u ON u.id = d.owner_id
    LEFT JOIN company c ON c.id = d.company_id
    LEFT JOIN contact p ON p.id = d.person_id
   WHERE o.id = p_offer
$$;


--
-- Name: email_outbox_claim(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_outbox_claim(p_limit integer DEFAULT 20) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  res jsonb;
BEGIN
  PERFORM crm_background_only();
  WITH c AS (
    SELECT id FROM email_outbox WHERE status = 'v_rade' ORDER BY created_at LIMIT greatest(least(p_limit, 50), 1) FOR UPDATE SKIP LOCKED
  ), u AS (
    UPDATE email_outbox x SET status = 'odosiela_sa', send_key = gen_random_uuid(), sending_started_at = now(), attempts = attempts + 1
      FROM c WHERE x.id = c.id RETURNING x.*
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'send_key', u.send_key, 'kind', u.kind, 'to', a.email, 'name', a.name,
                                               'deal_id', u.deal_id, 'approval_id', u.approval_id, 'detail', u.detail)
                            ORDER BY u.created_at), '[]')
    INTO res
    FROM u JOIN app_user a ON a.id = u.user_id;
  RETURN res;
END;
$$;


--
-- Name: email_outbox_result(uuid, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_outbox_result(p_id uuid, p_send_key uuid, p_gmail_message_id text, p_error text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  x email_outbox;
BEGIN
  PERFORM crm_background_only();
  SELECT * INTO x FROM email_outbox WHERE id = p_id FOR UPDATE;
  IF x.id IS NULL OR x.send_key IS DISTINCT FROM p_send_key OR x.status <> 'odosiela_sa' THEN
    RETURN;
  END IF;
  IF p_gmail_message_id IS NOT NULL THEN
    IF p_gmail_message_id !~ '^[0-9a-f]{6,32}$' THEN
      RAISE EXCEPTION 'Neplatné ID správy z Gmailu.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE email_outbox SET status = 'odoslany', gmail_message_id = p_gmail_message_id, sent_at = now(), error = NULL WHERE id = x.id;
    PERFORM gmail_mailbox_result(NULL, NULL);
  ELSE
    UPDATE email_outbox SET status = CASE WHEN x.attempts >= 3 THEN 'chyba' ELSE 'v_rade' END, send_key = NULL,
                            sending_started_at = NULL, error = left(coalesce(p_error, 'Gmail e-mail odmietol.'), 500)
     WHERE id = x.id;
    PERFORM gmail_mailbox_result(NULL, coalesce(p_error, 'odmietnuté'));
  END IF;
END;
$_$;


--
-- Name: email_pending_recover(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_pending_recover() RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  r       record;
  v_done  integer := 0;
  v_fail  integer := 0;
  v_out   integer := 0;
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT id FROM email_message WHERE status = 'odosiela_sa' AND gmail_message_id IS NOT NULL ORDER BY sending_started_at LOOP
    PERFORM email_send_complete(r.id);
    v_done := v_done + 1;
  END LOOP;
  FOR r IN SELECT m.id, m.created_by, m.offer_id, t.deal_id FROM email_message m JOIN email_thread t ON t.id = m.thread_id
            WHERE m.status = 'odosiela_sa' AND m.gmail_message_id IS NULL AND m.sending_started_at < now() - interval '15 minutes'
            ORDER BY m.sending_started_at LOOP
    UPDATE email_message SET status = 'chyba', pending = NULL,
           error = 'Nie je isté, či e-mail odišiel – skontrolujte Odoslané v Gmaile; ak tam nie je, pripravte ho znova.'
     WHERE id = r.id;
    PERFORM notification_add_deal(CASE WHEN r.created_by IS NOT NULL THEN ARRAY[r.created_by]
                                       ELSE ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny') END,
      'email_chyba', r.deal_id, NULL, NULL, 'Nie je isté, či e-mail odišiel – skontrolujte Odoslané v Gmaile');
    v_fail := v_fail + 1;
  END LOOP;
  UPDATE email_outbox SET status = 'odoslany' WHERE status = 'odosiela_sa' AND gmail_message_id IS NOT NULL;
  UPDATE email_outbox SET status = 'chyba', error = 'Nie je isté, či e-mail odišiel (bez ID z Gmailu) – neodošle sa znova.'
   WHERE status = 'odosiela_sa' AND gmail_message_id IS NULL AND sending_started_at < now() - interval '15 minutes';
  GET DIAGNOSTICS v_out = ROW_COUNT;
  RETURN jsonb_build_object('dokoncene', v_done, 'neiste', v_fail, 'interne_neiste', v_out);
END;
$$;


--
-- Name: email_queue_claim(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_queue_claim(p_limit integer DEFAULT 10) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  r   record;
  res jsonb := '[]';
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT m.id, m.acceptance_id, t.mailbox_user_id FROM email_message m JOIN email_thread t ON t.id = m.thread_id
            WHERE m.status = 'v_rade' ORDER BY m.created_at LIMIT greatest(least(p_limit, 50), 1)
            FOR UPDATE OF m SKIP LOCKED LOOP
    IF r.acceptance_id IS NOT NULL AND EXISTS (SELECT 1 FROM offer_acceptance a WHERE a.id = r.acceptance_id AND a.revoked_at IS NOT NULL) THEN
      UPDATE email_message SET status = 'chyba', error = 'Akceptácia bola zrušená – potvrdenie sa neodoslalo.' WHERE id = r.id;
      CONTINUE;
    END IF;
    IF r.mailbox_user_id IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = r.mailbox_user_id AND u.status = 'aktivny' AND u.gmail_enabled) THEN
      UPDATE email_message SET status = 'chyba', error = 'Schránka obchodníka nemá zapnutý Gmail – e-mail sa neodoslal.' WHERE id = r.id;
      PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'email_chyba',
        (SELECT deal_id FROM email_thread t JOIN email_message x ON x.thread_id = t.id WHERE x.id = r.id), NULL, NULL,
        'E-mail z fronty: schránka obchodníka nemá zapnutý Gmail');
      CONTINUE;
    END IF;
    UPDATE email_message SET status = 'odosiela_sa', send_key = gen_random_uuid(), sending_started_at = now(), attempts = attempts + 1
     WHERE id = r.id;
    res := res || jsonb_build_array(email_send_payload(r.id));
  END LOOP;
  RETURN res;
END;
$$;


--
-- Name: email_reminder_draft(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_reminder_draft(p_offer uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o    offer;
  d    deal;
  tpl  email_template_version;
  vars jsonb;
  v_th uuid;
  v    uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  tpl := email_template_current(o.org_id, 'pripomienka_platnosti', o.language);
  IF tpl.id IS NULL OR EXISTS (SELECT 1 FROM email_message WHERE offer_id = o.id AND kind = 'pripomienka_platnosti') THEN
    RETURN NULL;
  END IF;
  vars := email_offer_vars(o.id) || jsonb_build_object('platnosť', email_fmt_time(o.valid_until, o.language));
  v_th := email_thread_for_offer(o.id, d.owner_id, email_fill(tpl.subject, vars), NULL);
  INSERT INTO email_message (org_id, thread_id, direction, status, kind, offer_id, template_version_id, to_addrs, subject, body_text)
  VALUES (o.org_id, v_th, 'odchadzajuca', 'koncept', 'pripomienka_platnosti', o.id, tpl.id, email_offer_recipients(o.id),
          email_fill(tpl.subject, vars), email_fill(tpl.body, vars))
  RETURNING id INTO v;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_pripomienka', d.id, NULL, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date,
    'Pripomienka platnosti ponuky ' || offer_display_number(o) || ' – koncept e-mailu je pripravený');
  RETURN v;
END;
$$;


--
-- Name: email_retry(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_retry(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  m email_message;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR crm_active_user_id() IS NULL OR NOT email_message_visible(m.thread_id, m.status, m.created_by)
     OR NOT (m.created_by = crm_active_user_id() OR (m.created_by IS NULL AND crm_is_admin())) THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status <> 'chyba' OR m.gmail_message_id IS NOT NULL OR m.kind = 'pripomienka_platnosti' AND m.error = 'zahodené obchodníkom' THEN
    RAISE EXCEPTION 'Znova sa dá pripraviť iba e-mail v stave Chyba.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_message SET status = CASE WHEN m.created_by IS NULL THEN 'v_rade' ELSE 'koncept' END::email_status,
                           attempts = 0, send_key = NULL, pending = NULL, sending_started_at = NULL, error = NULL
   WHERE id = m.id;
END;
$$;


--
-- Name: email_salutation(uuid, public.offer_language); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_salutation(p_contact uuid, p_lang public.offer_language) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT coalesce(
           nullif(btrim(k.salutation), ''),
           CASE p_lang
             WHEN 'en' THEN CASE k.address_form WHEN 'pan' THEN 'Dear Mr ' || btrim(k.last_name)
                                                WHEN 'pani' THEN 'Dear Ms ' || btrim(k.last_name)
                                                ELSE 'Dear Sir or Madam' END
             ELSE 'Dobrý deň' || CASE k.address_form WHEN 'pan' THEN ', pán ' || btrim(k.last_name)
                                                     WHEN 'pani' THEN ', pani ' || btrim(k.last_name)
                                                     ELSE '' END
           END)
    FROM (SELECT 1) one
    LEFT JOIN contact k ON k.id = p_contact
$$;


--
-- Name: email_message; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_message (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    thread_id uuid NOT NULL,
    direction text NOT NULL,
    status public.email_status NOT NULL,
    kind text NOT NULL,
    offer_id uuid,
    acceptance_id uuid,
    template_version_id uuid,
    from_addr text,
    from_name text,
    reply_to text,
    to_addrs jsonb DEFAULT '[]'::jsonb NOT NULL,
    cc_addrs jsonb DEFAULT '[]'::jsonb NOT NULL,
    subject text DEFAULT ''::text NOT NULL,
    body_text text DEFAULT ''::text NOT NULL,
    body_html text,
    attachments jsonb DEFAULT '[]'::jsonb NOT NULL,
    send_key uuid,
    pending jsonb,
    sending_started_at timestamp with time zone,
    gmail_message_id text,
    rfc_message_id text,
    sent_at timestamp with time zone,
    received_at timestamp with time zone,
    attempts smallint DEFAULT 0 NOT NULL,
    error text,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT email_message_attachments_check CHECK ((jsonb_typeof(attachments) = 'array'::text)),
    CONSTRAINT email_message_body_html_check CHECK (((body_html IS NULL) OR (length(body_html) <= 500000))),
    CONSTRAINT email_message_body_text_check CHECK ((length(body_text) <= 200000)),
    CONSTRAINT email_message_cc_addrs_check CHECK (public.email_addr_list_ok(cc_addrs, 100)),
    CONSTRAINT email_message_check CHECK (((status = 'prijaty'::public.email_status) = (direction = 'prichadzajuca'::text))),
    CONSTRAINT email_message_check1 CHECK (((status <> ALL (ARRAY['odoslany'::public.email_status, 'prijaty'::public.email_status])) OR (gmail_message_id IS NOT NULL))),
    CONSTRAINT email_message_check2 CHECK (((status <> 'odosiela_sa'::public.email_status) OR (send_key IS NOT NULL))),
    CONSTRAINT email_message_check3 CHECK (((kind <> 'ponuka'::text) OR (offer_id IS NOT NULL))),
    CONSTRAINT email_message_check4 CHECK (((kind <> 'potvrdenie_akceptacie'::text) OR (acceptance_id IS NOT NULL))),
    CONSTRAINT email_message_direction_check CHECK ((direction = ANY (ARRAY['odchadzajuca'::text, 'prichadzajuca'::text]))),
    CONSTRAINT email_message_from_addr_check CHECK (((from_addr IS NULL) OR public.email_addr_list_ok(jsonb_build_array(from_addr), 1))),
    CONSTRAINT email_message_from_name_check CHECK (((from_name IS NULL) OR (length(from_name) <= 200))),
    CONSTRAINT email_message_gmail_message_id_check CHECK (((gmail_message_id IS NULL) OR (gmail_message_id ~ '^[0-9a-f]{6,32}$'::text))),
    CONSTRAINT email_message_kind_check CHECK ((kind = ANY (ARRAY['ponuka'::text, 'potvrdenie_akceptacie'::text, 'pripomienka_platnosti'::text, 'volny'::text, 'odpoved'::text]))),
    CONSTRAINT email_message_reply_to_check CHECK (((reply_to IS NULL) OR public.email_addr_list_ok(jsonb_build_array(reply_to), 1))),
    CONSTRAINT email_message_rfc_message_id_check CHECK (((rfc_message_id IS NULL) OR (length(rfc_message_id) <= 998))),
    CONSTRAINT email_message_subject_check CHECK ((length(subject) <= 998)),
    CONSTRAINT email_message_to_addrs_check CHECK (public.email_addr_list_ok(to_addrs, 100))
);


--
-- Name: TABLE email_message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_message IS 'e-mail CRM: koncept, fronta, odosielanie (send_key, pending), odoslaný (ID z Gmailu) alebo prijatý; obsah sa po odoslaní nemení; bez auditu riadkov (telo e-mailu nejde do audit_log, stav a ID sú v riadku) – 0042';


--
-- Name: COLUMN email_message.pending; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.email_message.pending IS 'odosielaná ponuka: pdf_key, pdf_sha256, link_hash – zapíšu sa k ponuke až po odoslaní (email_send_complete)';


--
-- Name: email_send_caller_ok(public.email_message); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_caller_ok(m public.email_message) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT crm_current_user_id() IS NULL OR (m.created_by IS NOT NULL AND m.created_by = crm_active_user_id())
$$;


--
-- Name: email_send_complete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_complete(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  m     email_message;
  o     offer;
  tpl   offer_template_version;
  v_err text;
  v_prev text;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status = 'odoslany' THEN
    RETURN jsonb_build_object('status', m.status, 'already', true, 'offer_error', m.error);
  END IF;
  IF m.status <> 'odosiela_sa' OR m.gmail_message_id IS NULL THEN
    RAISE EXCEPTION 'E-mail ešte nemá ID správy z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.kind = 'ponuka' THEN
    BEGIN
      v_prev := set_config('crm.email_send', m.id::text, true);
      SELECT * INTO o FROM offer WHERE id = m.offer_id FOR UPDATE;
      PERFORM offer_mark_sent_apply(o, m.sent_at, 'crm', NULL, m.created_by);
      tpl := offer_template_for(o.id);
      UPDATE offer SET pdf_key = m.pending->>'pdf_key', pdf_sha256 = m.pending->>'pdf_sha256', pdf_generated_at = now(),
                       template_version_id = tpl.id,
                       link_hash = m.pending->>'link_hash', link_created_at = now(), link_created_by = m.created_by
       WHERE id = o.id;
      PERFORM set_config('crm.email_send', '', true);
    EXCEPTION WHEN OTHERS THEN
      v_err := 'E-mail odišiel, ponuku sa nepodarilo označiť ako odoslanú: ' || SQLERRM;
      PERFORM set_config('crm.email_send', '', true);
    END;
  END IF;
  UPDATE email_message SET status = 'odoslany', error = v_err WHERE id = m.id;
  UPDATE email_thread SET last_message_at = greatest(last_message_at, m.sent_at),
                          watch_until = greatest(watch_until, (m.sent_at AT TIME ZONE 'Europe/Bratislava')::date + 30)
   WHERE id = (SELECT thread_id FROM email_message WHERE id = m.id);
  PERFORM gmail_mailbox_result((SELECT mailbox_user_id FROM email_thread t JOIN email_message x ON x.thread_id = t.id WHERE x.id = m.id), NULL);
  IF v_err IS NOT NULL THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE (is_admin AND status = 'aktivny') OR id = m.created_by),
      'email_chyba', (SELECT deal_id FROM offer WHERE id = m.offer_id), NULL, NULL,
      'E-mail s ponukou ' || coalesce((SELECT offer_display_number(x) FROM offer x WHERE x.id = m.offer_id), '') ||
      ' odišiel, ponuka sa neoznačila ako odoslaná – skontrolujte ju');
  END IF;
  RETURN jsonb_build_object('status', 'odoslany', 'already', false, 'offer_error', v_err);
END;
$$;


--
-- Name: email_send_failed(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_failed(p_id uuid, p_send_key uuid, p_error text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  m email_message;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) OR m.send_key IS DISTINCT FROM p_send_key THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nesedí kľúč odoslania.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.status <> 'odosiela_sa' OR m.gmail_message_id IS NOT NULL THEN
    RAISE EXCEPTION 'E-mail už odišiel alebo sa neodosiela.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_message
     SET status = CASE WHEN m.created_by IS NOT NULL THEN 'koncept'
                       WHEN m.attempts >= 3 THEN 'chyba' ELSE 'v_rade' END::email_status,
         send_key = NULL, pending = NULL, sending_started_at = NULL, error = left(coalesce(p_error, 'Gmail e-mail odmietol.'), 500)
   WHERE id = m.id;
  PERFORM gmail_mailbox_result((SELECT mailbox_user_id FROM email_thread WHERE id = m.thread_id), coalesce(p_error, 'odmietnuté'));
  IF m.created_by IS NULL AND m.attempts >= 3 THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'email_chyba',
      (SELECT deal_id FROM email_thread WHERE id = m.thread_id), NULL, NULL, 'E-mail z fronty sa nepodarilo odoslať (3 pokusy)');
  END IF;
END;
$$;


--
-- Name: email_send_payload(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_payload(p_id uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'id', m.id, 'status', m.status, 'kind', m.kind, 'send_key', m.send_key, 'offer_id', m.offer_id,
           'mailbox_user_id', t.mailbox_user_id, 'mailbox', coalesce(u.email, 'crm@greenlogy.com'),
           'from', m.from_addr, 'from_name', coalesce(u.name, 'Greenlogy'), 'signature_user_id', coalesce(t.mailbox_user_id, m.created_by, (SELECT owner_id FROM deal WHERE id = t.deal_id)),
           'reply_to', m.reply_to, 'to', m.to_addrs, 'cc', m.cc_addrs, 'subject', m.subject, 'body', m.body_text,
           'gmail_thread_id', t.gmail_thread_id, 'gmail_message_id', m.gmail_message_id,
           'references', coalesce((SELECT jsonb_agg(x.rfc_message_id ORDER BY coalesce(x.sent_at, x.received_at))
                                     FROM email_message x WHERE x.thread_id = t.id AND x.id <> m.id AND x.rfc_message_id IS NOT NULL
                                      AND x.status IN ('odoslany', 'prijaty')), '[]'),
           'attachments', m.attachments || CASE WHEN m.pending ? 'pdf_key'
                            THEN jsonb_build_array(jsonb_build_object('kind', 'ponuka', 'key', m.pending->>'pdf_key',
                                   'sha256', m.pending->>'pdf_sha256')) ELSE '[]' END)
    FROM email_message m
    JOIN email_thread t ON t.id = m.thread_id
    LEFT JOIN app_user u ON u.id = t.mailbox_user_id
   WHERE m.id = p_id
$$;


--
-- Name: email_send_prepare(uuid, uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_prepare(p_id uuid, p_send_key uuid, p_pdf_key text DEFAULT NULL::text, p_pdf_sha256 text DEFAULT NULL::text, p_link_hash text DEFAULT NULL::text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  me      uuid := crm_active_user_id();
  m       email_message;
  t       email_thread;
  u       app_user;
  o       offer;
  tpl     offer_template_version;
  v_until timestamptz;
  pend    jsonb;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id;
  IF m.id IS NULL OR me IS NULL
     OR NOT (m.created_by = me OR (m.created_by IS NULL AND t.mailbox_user_id = me)) OR t.mailbox_user_id IS DISTINCT FROM me THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nie je váš.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_send_key IS NULL THEN
    RAISE EXCEPTION 'Chýba jednorazový kľúč odoslania.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.send_key = p_send_key THEN
    RETURN email_send_payload(m.id) || jsonb_build_object('fresh', false);
  END IF;
  IF m.status <> 'koncept' THEN
    RAISE EXCEPTION 'E-mail už bol odoslaný alebo sa odosiela.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO u FROM app_user WHERE id = me;
  IF NOT u.gmail_enabled THEN
    RAISE EXCEPTION 'Odosielanie z Gmailu ešte nemáte zapnuté (pilot) – požiadajte admina.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(m.to_addrs) = 0 THEN
    RAISE EXCEPTION 'Doplňte príjemcu.' USING ERRCODE = 'check_violation';
  END IF;
  IF btrim(m.subject) = '' THEN
    RAISE EXCEPTION 'Doplňte predmet.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.kind = 'ponuka' THEN
    o := offer_for_edit(m.offer_id);
    PERFORM offer_send_check(o, now());
    tpl := offer_template_for(o.id);
    IF tpl.id IS NULL OR tpl.status = 'navrh' THEN
      RAISE EXCEPTION 'Šablóna ponuky (%, %) ešte nie je schválená – admin ju zverejní v Nastaveniach → Šablóny ponúk.',
        o.kind, upper(o.language::text) USING ERRCODE = 'check_violation';
    END IF;
    IF coalesce(p_pdf_key, '') !~ ('^ponuky/' || o.org_id || '/[0-9]{4}/' || o.number || '(-[0-9]+)?\.pdf$') OR coalesce(p_pdf_sha256, '') !~ '^[0-9a-f]{64}$'
       OR coalesce(p_link_hash, '') !~ '^[0-9a-f]{64}$' THEN
      RAISE EXCEPTION 'Chýba PDF ponuky alebo odkaz.' USING ERRCODE = 'check_violation';
    END IF;
    IF position('«odkaz na ponuku»' IN m.body_text) = 0 THEN
      RAISE EXCEPTION 'Text e-mailu musí obsahovať «odkaz na ponuku».' USING ERRCODE = 'check_violation';
    END IF;
    v_until := offer_default_valid_until(o.org_id, now(),
                 EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
    pend := jsonb_build_object('pdf_key', p_pdf_key, 'pdf_sha256', p_pdf_sha256, 'link_hash', p_link_hash);
  ELSIF m.offer_id IS NOT NULL THEN
    SELECT * INTO o FROM offer WHERE id = m.offer_id;
    v_until := o.valid_until;
  END IF;
  UPDATE email_message
     SET status = 'odosiela_sa', send_key = p_send_key, pending = pend, sending_started_at = now(), attempts = attempts + 1,
         error = NULL, created_by = me, from_addr = lower(u.email),
         subject = CASE WHEN v_until IS NULL THEN subject ELSE email_fill(subject, jsonb_build_object('platnosť', email_fmt_time(v_until, o.language))) END,
         body_text = CASE WHEN v_until IS NULL THEN body_text ELSE email_fill(body_text, jsonb_build_object('platnosť', email_fmt_time(v_until, o.language))) END
   WHERE id = m.id;
  RETURN email_send_payload(m.id) || jsonb_build_object('fresh', true);
END;
$_$;


--
-- Name: email_send_recorded(uuid, uuid, text, text, text, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_send_recorded(p_id uuid, p_send_key uuid, p_gmail_message_id text, p_gmail_thread_id text, p_rfc_message_id text, p_sent_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  m email_message;
  t email_thread;
  v uuid;
BEGIN
  SELECT * INTO m FROM email_message WHERE id = p_id FOR UPDATE;
  IF m.id IS NULL OR NOT email_send_caller_ok(m) OR m.send_key IS DISTINCT FROM p_send_key THEN
    RAISE EXCEPTION 'E-mail neexistuje alebo nesedí kľúč odoslania.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF m.gmail_message_id IS NOT NULL THEN
    IF m.gmail_message_id = p_gmail_message_id THEN
      RETURN;
    END IF;
    RAISE EXCEPTION 'E-mail už má iné ID správy z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  IF m.status <> 'odosiela_sa' THEN
    RAISE EXCEPTION 'E-mail sa neodosiela.' USING ERRCODE = 'check_violation';
  END IF;
  IF coalesce(p_gmail_message_id, '') !~ '^[0-9a-f]{6,32}$' OR coalesce(p_gmail_thread_id, '') !~ '^[0-9a-f]{6,32}$' THEN
    RAISE EXCEPTION 'Neplatné ID správy alebo vlákna z Gmailu.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO t FROM email_thread WHERE id = m.thread_id FOR UPDATE;
  IF t.gmail_thread_id IS NULL THEN
    UPDATE email_thread SET gmail_thread_id = p_gmail_thread_id WHERE id = t.id;
  ELSIF t.gmail_thread_id <> p_gmail_thread_id THEN
    -- Gmail správu zaradil do iného vlákna: nové vlákno s rovnakými väzbami (odpovede sa sledujú v ňom)
    SELECT id INTO v FROM email_thread
     WHERE mailbox_user_id IS NOT DISTINCT FROM t.mailbox_user_id AND gmail_thread_id = p_gmail_thread_id;
    IF v IS NULL THEN
      INSERT INTO email_thread (org_id, mailbox_user_id, gmail_thread_id, deal_id, company_id, person_id, offer_id, subject, created_by)
      VALUES (t.org_id, t.mailbox_user_id, p_gmail_thread_id, t.deal_id, t.company_id, t.person_id, t.offer_id, m.subject, m.created_by)
      RETURNING id INTO v;
    END IF;
    UPDATE email_message SET thread_id = v WHERE id = m.id;
  END IF;
  UPDATE email_message SET gmail_message_id = p_gmail_message_id, rfc_message_id = nullif(btrim(p_rfc_message_id), ''),
                           sent_at = least(coalesce(p_sent_at, now()), now())
   WHERE id = m.id;
END;
$_$;


--
-- Name: email_signature(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_signature(p_user uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'name', u.name, 'job_title', u.job_title, 'email', u.email, 'phone', u.phone, 'mobile', u.mobile,
           'linkedin', u.linkedin_url, 'company', coalesce(g.legal_name, 'Greenlogy a.s.'), 'address', g.address,
           'company_phone', g.support_phone, 'web', coalesce(g.web, 'www.greenlogy.com'),
           'has_photo', EXISTS (SELECT 1 FROM user_photo p WHERE p.user_id = u.id),
           'mode', coalesce(s.mode, 'profil'),
           'custom_html', CASE WHEN s.mode = 'vlastny' THEN s.html END,
           'custom_text', CASE WHEN s.mode = 'vlastny' THEN s.text_version END)
    FROM app_user u
    LEFT JOIN org g ON g.id = crm_default_org()
    LEFT JOIN user_signature s ON s.user_id = u.id
   WHERE u.id = p_user
$$;


--
-- Name: email_template_check(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_template_check(p_subject text, p_body text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  v text;
  t text := coalesce(p_subject, '') || E'\n' || coalesce(p_body, '');
BEGIN
  FOR v IN SELECT m[1] FROM regexp_matches(t, '«([^«»]*)»', 'g') m LOOP
    IF NOT v = ANY (email_template_variables()) THEN
      RETURN format('Neznáma premenná «%s».', v);
    END IF;
  END LOOP;
  IF (length(t) - length(replace(t, '«', ''))) <> (length(t) - length(replace(t, '»', ''))) THEN
    RETURN 'Neuzavretá premenná.';
  END IF;
  IF position('«podpis»' IN coalesce(p_body, '')) = 0 THEN
    RETURN 'Text musí obsahovať «podpis».';
  END IF;
  IF position('«' IN coalesce(p_subject, '')) > 0 AND p_subject ~ '«(podpis|odkaz na ponuku)»' THEN
    RETURN 'Podpis a odkaz nepatria do predmetu.';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: email_template_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_template_version (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code text NOT NULL,
    language public.offer_language NOT NULL,
    version smallint NOT NULL,
    status text DEFAULT 'navrh'::text NOT NULL,
    name text NOT NULL,
    subject text NOT NULL,
    body text NOT NULL,
    note text,
    created_by uuid,
    published_at timestamp with time zone,
    published_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT email_template_version_check CHECK (((status = 'navrh'::text) = (published_at IS NULL))),
    CONSTRAINT email_template_version_code_check CHECK ((code = ANY (ARRAY['ponuka_dodavka'::text, 'ponuka_vykup'::text, 'ponuka_viwa'::text, 'potvrdenie_akceptacie'::text, 'pripomienka_platnosti'::text, 'volny'::text]))),
    CONSTRAINT email_template_version_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT email_template_version_status_check CHECK ((status = ANY (ARRAY['navrh'::text, 'platna'::text, 'nahradena'::text])))
);


--
-- Name: TABLE email_template_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_template_version IS 'šablóny e-mailov zákazníkom – platná verzia sa nemení, zmena = nová verzia (0042)';


--
-- Name: email_template_current(uuid, text, public.offer_language); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_template_current(p_org uuid, p_code text, p_lang public.offer_language) RETURNS public.email_template_version
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT * FROM email_template_version
   WHERE org_id = p_org AND code = p_code AND status = 'platna' AND language IN (p_lang, 'sk')
   ORDER BY (language = p_lang) DESC LIMIT 1
$$;


--
-- Name: email_template_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_template_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_err text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'navrh' AND NOT (crm_owner_session() OR crm_internal_call()) THEN
      RAISE EXCEPTION 'Zmazať sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NOT (crm_owner_session() OR crm_internal_call()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.status := 'navrh';
      NEW.published_at := NULL;
      NEW.published_by := NULL;
      NEW.created_by := crm_active_user_id();
    ELSE
      IF OLD.status <> 'navrh' THEN
        RAISE EXCEPTION 'Platná šablóna sa nemení – uložte novú verziu.' USING ERRCODE = 'check_violation';
      END IF;
      IF (NEW.status, NEW.code, NEW.language, NEW.version, NEW.org_id, NEW.published_at)
         IS DISTINCT FROM (OLD.status, OLD.code, OLD.language, OLD.version, OLD.org_id, OLD.published_at) THEN
        RAISE EXCEPTION 'Druh, jazyk, verziu a stav šablóny mení iba CRM (zverejnenie).' USING ERRCODE = 'insufficient_privilege';
      END IF;
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.version := coalesce((SELECT max(version) FROM email_template_version
                              WHERE org_id = NEW.org_id AND code = NEW.code AND language = NEW.language), 0) + 1;
  END IF;
  v_err := email_template_check(NEW.subject, NEW.body);
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: email_template_publish(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_template_publish(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t email_template_version;
BEGIN
  IF NOT crm_email_template_editor() THEN
    RAISE EXCEPTION 'Šablóny e-mailov zverejňuje admin alebo Marketing.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM email_template_version WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR t.status <> 'navrh' THEN
    RAISE EXCEPTION 'Zverejniť sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_template_version SET status = 'nahradena'
   WHERE org_id = t.org_id AND code = t.code AND language = t.language AND status = 'platna';
  UPDATE email_template_version SET status = 'platna', published_at = now(), published_by = crm_active_user_id() WHERE id = t.id;
END;
$$;


--
-- Name: email_template_variables(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_template_variables() RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT ARRAY['oslovenie', 'názov zákazníka', 'číslo ponuky', 'zhrnutie variantov', 'platnosť', 'odkaz na ponuku', 'podpis',
               'obchodník', 'variant', 'dátum akceptácie']
$$;


--
-- Name: email_thread_checked(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_thread_checked(p_thread uuid, p_result text, p_error text DEFAULT NULL::text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t email_thread;
BEGIN
  PERFORM crm_background_only();
  IF p_result NOT IN ('ok', 'chyba', 'nenajdene') THEN
    RAISE EXCEPTION 'Neznámy výsledok kontroly.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE email_thread SET last_checked_at = now(), watch_until = CASE WHEN p_result = 'nenajdene' THEN NULL ELSE watch_until END
   WHERE id = p_thread RETURNING * INTO t;
  IF t.id IS NOT NULL AND p_result <> 'nenajdene' THEN
    PERFORM gmail_mailbox_result(t.mailbox_user_id, CASE WHEN p_result = 'chyba' THEN coalesce(p_error, 'chyba') END);
  END IF;
END;
$$;


--
-- Name: email_thread_for_offer(uuid, uuid, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_thread_for_offer(p_offer uuid, p_mailbox uuid, p_subject text, p_by uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer;
  d deal;
  v uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT t.id INTO v FROM email_thread t JOIN offer x ON x.id = t.offer_id
   WHERE x.org_id = o.org_id AND x.number = o.number AND t.mailbox_user_id IS NOT DISTINCT FROM p_mailbox
   ORDER BY (t.gmail_thread_id IS NOT NULL) DESC, t.last_message_at DESC NULLS LAST, t.created_at DESC LIMIT 1;
  IF v IS NULL THEN
    INSERT INTO email_thread (org_id, mailbox_user_id, deal_id, company_id, person_id, offer_id, subject, created_by)
    VALUES (o.org_id, p_mailbox, d.id, d.company_id, d.person_id, o.id, coalesce(p_subject, ''), p_by)
    RETURNING id INTO v;
  ELSE
    UPDATE email_thread SET offer_id = o.id WHERE id = v AND offer_id IS DISTINCT FROM o.id;
  END IF;
  RETURN v;
END;
$$;


--
-- Name: email_thread_visible(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_thread_visible(p_thread uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (
    SELECT 1 FROM email_thread t LEFT JOIN deal d ON d.id = t.deal_id
     WHERE t.id = p_thread AND crm_active_user_id() IS NOT NULL AND t.org_id = ANY (crm_user_orgs())
       AND (crm_is_admin() OR t.mailbox_user_id = crm_active_user_id()
            OR (d.id IS NOT NULL AND crm_deal_visible(d.company_id, d.person_id, d.owner_id))
            OR (t.deal_id IS NULL AND t.company_id IS NOT NULL AND crm_company_access(t.company_id, 'view'))
            OR (t.deal_id IS NULL AND t.company_id IS NULL AND crm_contact_access(t.person_id, 'view'))))
$$;


--
-- Name: email_watch_threads(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.email_watch_threads(p_limit integer DEFAULT 50) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  res jsonb;
BEGIN
  PERFORM crm_background_only();
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'thread_id', x.id, 'mailbox_user_id', x.mailbox_user_id, 'mailbox', x.email, 'gmail_thread_id', x.gmail_thread_id,
           'known', (SELECT coalesce(jsonb_agg(m.gmail_message_id), '[]') FROM email_message m
                      WHERE m.thread_id = x.id AND m.gmail_message_id IS NOT NULL))), '[]')
    INTO res
    FROM (SELECT t.id, t.mailbox_user_id, u.email, t.gmail_thread_id
            FROM email_thread t JOIN app_user u ON u.id = t.mailbox_user_id
           WHERE t.gmail_thread_id IS NOT NULL AND t.watch_until >= crm_today() AND u.status = 'aktivny' AND u.gmail_enabled
             AND (t.last_checked_at IS NULL
                  OR t.last_message_at > now() - interval '2 days'
                  OR t.last_checked_at < now() - interval '15 minutes')
           ORDER BY t.last_checked_at NULLS FIRST LIMIT greatest(least(p_limit, 200), 1)) x;
  RETURN res;
END;
$$;


--
-- Name: finstat_cache_get(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finstat_cache_get(p_kind text, p_key text) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT data FROM finstat_cache
   WHERE crm_session_ok() AND kind = p_kind AND key = p_key AND fetched_at > now() - interval '24 hours'
$$;


--
-- Name: finstat_cache_put(text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finstat_cache_put(p_kind text, p_key text, p_data jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NOT crm_session_ok() THEN
    RAISE EXCEPTION 'Bez prihláseného používateľa.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  INSERT INTO finstat_cache (kind, key, data) VALUES (p_kind, p_key, p_data)
  ON CONFLICT (kind, key) DO UPDATE SET data = EXCLUDED.data, fetched_at = now();
  DELETE FROM finstat_cache WHERE fetched_at < now() - interval '7 days';
END;
$$;


--
-- Name: finstat_request_allow(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.finstat_request_allow() RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_limit integer := coalesce((SELECT (value #>> '{}')::integer FROM app_setting WHERE key = 'finstat_daily_limit'), 0);
  v_n     integer;
BEGIN
  IF NOT crm_session_ok() THEN
    RETURN false;
  END IF;
  INSERT INTO finstat_usage (day, requests) VALUES (crm_today(), 1)
  ON CONFLICT (day) DO UPDATE SET requests = finstat_usage.requests + 1
  WHERE finstat_usage.requests < v_limit
  RETURNING requests INTO v_n;
  RETURN v_n IS NOT NULL AND v_n <= v_limit;
END;
$$;


--
-- Name: gmail_mailbox_result(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gmail_mailbox_result(p_mailbox uuid, p_error text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  k text := coalesce(p_mailbox::text, 'crm');
  s gmail_mailbox_state;
BEGIN
  INSERT INTO gmail_mailbox_state (mailbox) VALUES (k) ON CONFLICT (mailbox) DO NOTHING;
  IF p_error IS NULL THEN
    UPDATE gmail_mailbox_state SET consecutive_errors = 0, last_ok_at = now(), alerted_at = NULL, updated_at = now() WHERE mailbox = k;
    RETURN;
  END IF;
  UPDATE gmail_mailbox_state SET consecutive_errors = consecutive_errors + 1, last_error = left(p_error, 500),
                                 last_error_at = now(), updated_at = now()
   WHERE mailbox = k RETURNING * INTO s;
  IF s.consecutive_errors >= 3 AND s.alerted_at IS NULL THEN
    PERFORM notification_add_deal(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'gmail_chyba', NULL, NULL, NULL,
      'Gmail: schránka ' || coalesce((SELECT email FROM app_user WHERE id = p_mailbox), 'crm@greenlogy.com') || ' – 3 chyby za sebou');
    UPDATE gmail_mailbox_state SET alerted_at = now() WHERE mailbox = k;
  END IF;
END;
$$;


--
-- Name: gmail_read_authorize(uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.gmail_read_authorize(p_mailbox uuid, p_gmail_thread_id text, p_gmail_message_id text, p_method text, p_format text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t email_thread;
BEGIN
  IF p_method IS NULL OR p_method NOT IN ('threads.get', 'messages.get') THEN
    RAISE EXCEPTION 'Gmail: povolené je iba threads.get a messages.get.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_format IS NULL OR p_format NOT IN ('minimal', 'metadata', 'full') THEN
    RAISE EXCEPTION 'Gmail: povolený formát je iba minimal, metadata alebo full (nie raw).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_mailbox IS NULL THEN
    RAISE EXCEPTION 'Schránka crm@greenlogy.com sa nečíta.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM email_thread WHERE mailbox_user_id = p_mailbox AND gmail_thread_id = p_gmail_thread_id;
  IF t.id IS NULL THEN
    RAISE EXCEPTION 'Vlákno nepatrí CRM alebo tejto schránke.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = p_mailbox AND u.status = 'aktivny' AND u.gmail_enabled) THEN
    RAISE EXCEPTION 'Schránka nemá zapnutý Gmail.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF crm_current_user_id() IS NULL THEN
    IF p_method <> 'threads.get' OR p_gmail_message_id IS NOT NULL OR coalesce(t.watch_until, '-infinity') < crm_today() THEN
      RAISE EXCEPTION 'Beh na pozadí číta iba sledované vlákna (threads.get).' USING ERRCODE = 'insufficient_privilege';
    END IF;
  ELSE
    IF p_method <> 'messages.get' OR NOT email_thread_visible(t.id)
       OR NOT EXISTS (SELECT 1 FROM email_message m WHERE m.thread_id = t.id AND m.gmail_message_id = p_gmail_message_id) THEN
      RAISE EXCEPTION 'Správa nepatrí vláknu, ktoré vidíte.' USING ERRCODE = 'insufficient_privilege';
    END IF;
  END IF;
  INSERT INTO mailbox_access_log (user_id, mailbox_user_id, method, format, gmail_thread_id, gmail_message_id, thread_id)
  VALUES (crm_active_user_id(), p_mailbox, p_method, p_format, p_gmail_thread_id, p_gmail_message_id, t.id);
  RETURN t.id;
END;
$$;


--
-- Name: import_alias_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_alias_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_owner boolean := crm_owner_session();
  v_ok    boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system AND NOT v_owner THEN
      RAISE EXCEPTION 'Systémový preklad sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NOT v_owner THEN
    IF TG_OP = 'INSERT' AND NEW.is_system THEN
      RAISE EXCEPTION 'Systémový preklad zakladá iba migrácia alebo skript.' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'UPDATE' AND (NEW.is_system <> OLD.is_system
         OR (OLD.is_system AND (NEW.target <> OLD.target OR NEW.target_extra <> OLD.target_extra
                                OR NEW.name_sample <> OLD.name_sample OR NEW.kind <> OLD.kind OR NEW.source <> OLD.source))) THEN
      RAISE EXCEPTION 'Systémový preklad sa nemení, iba skryje.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Spoločnosť prekladu sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  v_ok := CASE NEW.kind
    WHEN 'produkt_op' THEN NEW.target IN ('cennik', 'fix', 'spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct')
    WHEN 'produkt_oom' THEN EXISTS (SELECT 1 FROM product p WHERE p.code = NEW.target AND p.org_id = NEW.org_id)
    WHEN 'sadzba' THEN EXISTS (SELECT 1 FROM lookup_value v
                                WHERE v.list_code = 'sadzba_distribucie' AND v.hidden_at IS NULL
                                  AND v.code = v.parent_code || '_' || NEW.target)
    WHEN 'pds' THEN EXISTS (SELECT 1 FROM lookup_value v
                             WHERE v.list_code = 'pds' AND v.code = NEW.target AND v.hidden_at IS NULL)
    WHEN 'obchodnik' THEN EXISTS (SELECT 1 FROM app_user u
                                   WHERE u.id::text = NEW.target AND u.status <> 'deaktivovany')
    WHEN 'iny' THEN true
    WHEN 'faza' THEN NEW.target IN (SELECT unnest(enum_range(NULL::contract_phase))::text)
    ELSE EXISTS (SELECT 1 FROM lookup_value v
                  WHERE v.list_code = NEW.kind AND v.code = NEW.target AND v.hidden_at IS NULL)
  END;
  IF NOT v_ok THEN
    RAISE EXCEPTION 'Preklad „%“: cieľová hodnota „%“ v CRM neexistuje.', NEW.name_sample, NEW.target
      USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' AND NOT v_owner THEN
    NEW.created_by := crm_active_user_id();
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: import_name_norm(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_name_norm(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $_$
  SELECT regexp_replace(
           btrim(regexp_replace(
             translate(lower(p), 'áäčďéěíĺľňóôöŕřšťúůüýž', 'aacdeeillnooorrstuuuyz'),
             '\s+', ' ', 'g')),
           '(^|[^0-9])(19|20)[0-9]{2}(?=[^0-9]|$)', '\1rrrr', 'g')
$_$;


--
-- Name: FUNCTION import_name_norm(p text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.import_name_norm(p text) IS 'normalizácia názvu z importu: „VBattery  - V“ = „vbattery - v“, GREEN_1T_INDIVIDUAL_2027 = green_1t_individual_rrrr';


--
-- Name: import_alias; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_alias (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    source text NOT NULL,
    kind text NOT NULL,
    name_sample text NOT NULL,
    name_norm text GENERATED ALWAYS AS (public.import_name_norm(name_sample)) STORED,
    target text NOT NULL,
    target_extra jsonb DEFAULT '{}'::jsonb NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    hidden_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT import_alias_kind_check CHECK ((kind = ANY (ARRAY['produkt_op'::text, 'produkt_oom'::text, 'sadzba'::text, 'pds'::text, 'obchodnik'::text, 'typ_merania'::text, 'fakturacne_obdobie'::text, 'sposob_zaloh'::text, 'iny'::text, 'faza'::text]))),
    CONSTRAINT import_alias_name_sample_check CHECK ((btrim(name_sample) <> ''::text)),
    CONSTRAINT import_alias_source_check CHECK ((source = ANY (ARRAY['office_portal'::text, 'xm_trade'::text, 'vsetky'::text]))),
    CONSTRAINT import_alias_target_check CHECK ((btrim(target) <> ''::text)),
    CONSTRAINT import_alias_target_extra_check CHECK ((jsonb_typeof(target_extra) = 'object'::text))
);


--
-- Name: TABLE import_alias; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.import_alias IS 'preklad názvu z importu (Office portal, XM Trade) na hodnotu CRM; spravuje admin (rozhodnutie 2026-10-13)';


--
-- Name: COLUMN import_alias.target; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.import_alias.target IS 'produkt_op: cenový model; produkt_oom: kód produktu; sadzba: kód sadzby bez PDS (d1); pds a číselníky: kód hodnoty; obchodnik: id používateľa';


--
-- Name: import_alias_resolve(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.import_alias_resolve(p_org uuid, p_source text, p_kind text, p_name text) RETURNS public.import_alias
    LANGUAGE sql STABLE
    AS $$
  SELECT a.* FROM import_alias a
   WHERE a.org_id = p_org AND a.kind = p_kind AND a.source IN (p_source, 'vsetky')
     AND a.name_norm = import_name_norm(p_name) AND a.hidden_at IS NULL
   ORDER BY (a.source = p_source) DESC
   LIMIT 1
$$;


--
-- Name: inherit_customer_segment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inherit_customer_segment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.segment IS NULL THEN
    IF NEW.company_id IS NOT NULL THEN
      SELECT CASE WHEN c.is_supplier AND NOT c.is_customer THEN 'dodavatel' ELSE 'firma' END::customer_segment
        INTO NEW.segment FROM company c WHERE c.id = NEW.company_id;
    ELSE
      NEW.segment := 'domacnost';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: job_error(uuid, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.job_error(p_contract_id uuid, p_step text, p_state text, p_message text) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT jsonb_build_object('zmluva', p_contract_id, 'krok', p_step, 'kod', p_state,
           'text', left(regexp_replace(coalesce(p_message, ''), '([0-9]{2}[A-Z])[0-9A-Z-]{13}', '\1…', 'g'), 300))
$$;


--
-- Name: lookup_code_ok(text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lookup_code_ok(p_list text, p_code text, p_org uuid) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT EXISTS (SELECT 1 FROM lookup_value v
                  WHERE v.list_code = p_list AND v.code = p_code AND v.hidden_at IS NULL
                    AND (v.org_id IS NULL OR v.org_id = p_org))
$$;


--
-- Name: lookup_codes_check(text, uuid, text[], text[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lookup_codes_check(p_list text, p_org_id uuid, p_new text[], p_old text[] DEFAULT '{}'::text[]) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: lookup_value_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.lookup_value_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_parent_list text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Hodnota číselníka sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT parent_list INTO v_parent_list FROM lookup_list WHERE code = NEW.list_code;
    IF (v_parent_list IS NULL) <> (NEW.parent_code IS NULL) THEN
      RAISE EXCEPTION 'Hodnota zoznamu % % nadradenú hodnotu.', NEW.list_code,
        CASE WHEN v_parent_list IS NULL THEN 'nemá' ELSE 'musí mať' END USING ERRCODE = 'check_violation';
    END IF;
    IF v_parent_list IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = v_parent_list AND code = NEW.parent_code) THEN
      RAISE EXCEPTION 'Nadradená hodnota „%“ nie je v číselníku %.', NEW.parent_code, v_parent_list
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.code := coalesce(NEW.code, crm_slug(concat_ws('_', NEW.parent_code, NEW.label)));
    RETURN NEW;
  END IF;
  IF NEW.code <> OLD.code OR NEW.list_code <> OLD.list_code OR NEW.is_system <> OLD.is_system
     OR NEW.parent_code IS DISTINCT FROM OLD.parent_code THEN
    RAISE EXCEPTION 'Kód, zoznam, nadradená hodnota a systémový príznak hodnoty číselníka sa nemenia.'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.is_system AND (NEW.label <> OLD.label OR NEW.hidden_at IS NOT NULL
                        OR NEW.org_id IS DISTINCT FROM OLD.org_id) THEN
    RAISE EXCEPTION 'Systémová hodnota „%“ sa nedá premenovať ani skryť.', OLD.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: mailbox_access_log_immutable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mailbox_access_log_immutable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Denník čítania schránok sa nemení ani nemaže.' USING ERRCODE = 'insufficient_privilege';
END;
$$;


--
-- Name: mark_household(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_household() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.person_id IS NOT NULL THEN
    UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: market_price_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.market_price_guard() RETURNS trigger
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


--
-- Name: mwh_text(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mwh_text(p numeric) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT replace(CASE WHEN p IS NULL THEN NULL
                      WHEN round(p, 3) = trunc(p) THEN trunc(p)::text
                      ELSE rtrim(round(p, 3)::text, '0') END, '.', ',')
$$;


--
-- Name: next_working_day(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.next_working_day(p_org uuid, p_day date) RETURNS date
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v date;
BEGIN
  SELECT min(date) INTO v FROM business_calendar
   WHERE org_id = coalesce(p_org, crm_default_org()) AND date > p_day AND is_working_day;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Pracovný kalendár nepokrýva dni po %.', p_day;
  END IF;
  RETURN v;
END;
$$;


--
-- Name: normalize_phone(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.normalize_phone(p text) RETURNS text
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT CASE
           WHEN d IS NULL OR d = '' OR d = '+' THEN NULL
           WHEN d LIKE '+%'  THEN '+' || replace(substr(d, 2), '+', '')
           WHEN d LIKE '00%' THEN '+' || substr(d, 3)
           WHEN d LIKE '421%' AND length(d) = 12 THEN '+' || d
           WHEN d LIKE '0%'  THEN '+421' || substr(d, 2)
           WHEN length(d) = 9 THEN '+421' || d
           ELSE d
         END
    FROM (SELECT regexp_replace(p, '[^0-9+]', '', 'g') AS d) x
$$;


--
-- Name: notification_add(uuid[], text, uuid, uuid, uuid, date, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_add(p_users uuid[], p_kind text, p_contract_id uuid, p_exception_id uuid, p_job_run_id uuid, p_ref_date date, p_detail text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_n integer;
BEGIN
  INSERT INTO notification (user_id, kind, contract_id, price_exception_id, job_run_id, ref_date, detail)
  SELECT DISTINCT u, p_kind, p_contract_id, p_exception_id, p_job_run_id, p_ref_date, p_detail
    FROM unnest(coalesce(p_users, '{}')) AS u
   WHERE u IS NOT NULL;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN v_n;
END;
$$;


--
-- Name: notification_add_deal(uuid[], text, uuid, uuid, date, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_add_deal(p_users uuid[], p_kind text, p_deal_id uuid, p_approval_id uuid, p_ref_date date, p_detail text) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: notification_approvers(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_approvers(p_org uuid, p_with_ceo boolean) RETURNS uuid[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(array_agg(u.id ORDER BY u.id), '{}')
    FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.status <> 'deaktivovany'
     AND (u.approves_prices OR (p_with_ceo AND t.code = 'ceo'))
     AND crm_user_sees_org(u.id, p_org)
$$;


--
-- Name: notification_assign_approvers(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_assign_approvers(p_org uuid) RETURNS uuid[]
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(array_agg(u.id ORDER BY u.id), '{}')
    FROM app_user u
   WHERE u.status <> 'deaktivovany' AND u.approves_assignments AND crm_user_sees_org(u.id, p_org)
$$;


--
-- Name: notification_contract_users(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_contract_users(p_contract_id uuid) RETURNS uuid[]
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  k      contract;
  v_user uuid;
BEGIN
  SELECT * INTO k FROM contract WHERE id = p_contract_id;
  FOREACH v_user IN ARRAY ARRAY[k.owner_id,
                                (SELECT owner_id FROM company WHERE id = k.company_id),
                                (SELECT owner_id FROM contact WHERE id = k.person_id)] LOOP
    IF v_user IS NOT NULL AND EXISTS (SELECT 1 FROM app_user WHERE id = v_user AND status <> 'deaktivovany') THEN
      RETURN ARRAY[v_user];
    END IF;
  END LOOP;
  RETURN notification_approvers(k.org_id, false);
END;
$$;


--
-- Name: notification_email_outbox(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.notification_email_outbox() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  INSERT INTO email_outbox (notification_id, user_id, kind, deal_id, approval_id, detail)
  SELECT NEW.id, NEW.user_id, NEW.kind, NEW.deal_id, NEW.approval_id, NEW.detail
   WHERE EXISTS (SELECT 1 FROM app_user u WHERE u.id = NEW.user_id AND u.status = 'aktivny');
  RETURN NEW;
END;
$$;


--
-- Name: offer_accept_apply(uuid, uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_accept_apply(p_offer uuid, p_variant uuid, p_accepted_at timestamp with time zone DEFAULT now()) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o       offer;
  d       deal;
  x       offer;
  v_stage uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ponuka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id FOR UPDATE;
  IF o.status NOT IN ('odoslana', 'otvorena') THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_accepted_at IS NULL OR p_accepted_at < o.sent_at OR p_accepted_at > now() + interval '5 minutes'
     OR o.valid_until IS NULL OR p_accepted_at >= o.valid_until THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba v platnosti ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE id = p_variant AND offer_id = o.id) THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke.' USING ERRCODE = 'check_violation';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;

  UPDATE offer SET status = 'akceptovana' WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- rozpracovaná nová verzia: späť do konceptu, čakajúce žiadosti zrušené, odoslať sa nedá (offer_check_internal)
  FOR x IN SELECT * FROM offer WHERE org_id = o.org_id AND number = o.number
                                 AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena') LOOP
    UPDATE approval_request SET status = 'zrusena' WHERE status = 'caka' AND offer_id = x.id;
    -- zablokovanie trvá aj po zrušení akceptácie – odblokuje vlastník obchodu alebo admin (0039, odpoveď F3 6)
    UPDATE offer SET status = 'koncept', blocked_by_offer_id = o.id WHERE id = x.id;
    PERFORM notification_add_deal(ARRAY[d.owner_id, x.created_by], 'ponuka_zablokovana', d.id, NULL, NULL,
      format('Zákazník akceptoval ponuku %s – rozpracovanú verziu %s nemožno odoslať.', offer_display_number(o), offer_display_number(x)));
    PERFORM deal_event_offer(x, 'ponuka_zablokovana', jsonb_build_object('accepted_offer_id', o.id, 'accepted_version', o.version));
  END LOOP;

  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'akceptacia'
   WHERE s.id = d.stage_id AND s.code IN ('prilezitost', 'cenova_ponuka', 'vyjednavanie');
  UPDATE deal SET accepted_variant_id = p_variant, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_akceptovana', d.id, NULL, NULL,
                                'Zákazník akceptoval ponuku ' || offer_display_number(o));
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_akceptovana', jsonb_build_object('variant_id', p_variant, 'accepted_at', p_accepted_at));
END;
$$;


--
-- Name: offer_accept_manual(uuid, uuid, text, text, timestamp with time zone, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_accept_manual(p_offer uuid, p_variant uuid, p_name text, p_function text, p_at timestamp with time zone, p_channel text, p_note text, p_signed_key text) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF p_channel IS NULL OR p_channel NOT IN ('telefon', 'email', 'osobne', 'podpisane_pdf') THEN
    RAISE EXCEPTION 'Vyberte, ako zákazník ponuku prijal.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_at IS NULL OR p_at > now() + interval '5 minutes' THEN
    RAISE EXCEPTION 'Zadajte čas akceptácie (nie v budúcnosti).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_signed_key IS NOT NULL AND p_signed_key !~ ('^podpisane/' || o.org_id || '/[0-9]{4}/P[0-9]{2}-[0-9]{6}(-[0-9]+)?-[0-9a-f]{8}\.pdf$') THEN
    RAISE EXCEPTION 'Neplatný súbor podpísanej ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN offer_accept_record(o.id, p_variant, 'rucne', p_channel, p_at, p_name, p_function, NULL, NULL, p_note, p_signed_key,
                             crm_active_user_id());
END;
$_$;


--
-- Name: offer_accept_record(uuid, uuid, text, text, timestamp with time zone, text, text, inet, text, text, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_accept_record(p_offer uuid, p_variant uuid, p_method text, p_channel text, p_at timestamp with time zone, p_name text, p_function text, p_ip inet, p_ua text, p_note text, p_signed_key text, p_recorded_by uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer;
  terms text;
  v_id  uuid;
BEGIN
  IF coalesce(btrim(p_name), '') = '' OR coalesce(btrim(p_function), '') = '' THEN
    RAISE EXCEPTION 'Zadajte meno a funkciu osoby, ktorá ponuku prijala.' USING ERRCODE = 'check_violation';
  END IF;
  terms := offer_terms_text(p_offer, p_variant);
  IF terms IS NULL THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke alebo chýba šablóna.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_accept_apply(p_offer, p_variant, p_at);
  SELECT * INTO o FROM offer WHERE id = p_offer;
  INSERT INTO offer_acceptance (offer_id, variant_id, org_id, method, channel, accepted_at, signer_name, signer_function, ip,
                                user_agent, terms_text, terms_sha256, offer_pdf_sha256, signed_file_key, note, recorded_by)
  VALUES (o.id, p_variant, o.org_id, p_method, p_channel, p_at, btrim(p_name), btrim(p_function), p_ip,
          left(p_ua, 500), terms, offer_terms_sha(terms), o.pdf_sha256, p_signed_key, nullif(btrim(p_note), ''), p_recorded_by)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: offer_acceptance_confirmation_attach(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_confirmation_attach(p_id uuid, p_key text, p_sha256 text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
BEGIN
  IF p_sha256 IS NULL OR p_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Neplatný odtlačok potvrdenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_key IS DISTINCT FROM offer_acceptance_confirmation_key(p_id) THEN
    RAISE EXCEPTION 'Neplatný súbor potvrdenia.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_acceptance SET confirmation_pdf_key = p_key, confirmation_pdf_sha256 = p_sha256
   WHERE id = p_id AND confirmation_pdf_key IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Potvrdenie už je uložené – nemení sa.' USING ERRCODE = 'check_violation';
  END IF;
END;
$_$;


--
-- Name: offer_acceptance_confirmation_key(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_confirmation_key(p_id uuid) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT 'potvrdenia/' || o.org_id || '/20' || substr(o.number, 2, 2) || '/' || o.number
         || CASE WHEN o.version > 1 THEN '-' || o.version ELSE '' END || '-' || left(a.id::text, 8) || '.pdf'
    FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id
   WHERE a.id = p_id
$$;


--
-- Name: offer_acceptance_confirmation_off(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_confirmation_off(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a offer_acceptance;
  o offer;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Akceptácia neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  o := offer_for_edit(a.offer_id);
  IF a.method <> 'rucne' OR a.created_at < now() - interval '10 minutes' OR a.confirmation_pdf_key IS NOT NULL OR a.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Poslanie potvrdenia sa vypína iba pri zázname ručnej akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT a.send_confirmation THEN
    RETURN;
  END IF;
  UPDATE offer_acceptance SET send_confirmation = false WHERE id = a.id;
  PERFORM deal_event_offer(o, 'potvrdenie_neodoslane', jsonb_build_object('acceptance_id', a.id));
END;
$$;


--
-- Name: offer_acceptance_confirmation_set(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_confirmation_set(p_id uuid, p_key text, p_sha256 text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a offer_acceptance;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Akceptácia neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  PERFORM offer_for_edit(a.offer_id);
  IF a.method <> 'rucne' OR a.created_at < now() - interval '10 minutes' THEN
    RAISE EXCEPTION 'Potvrdenie sa ukladá iba pri zápise akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_acceptance_confirmation_attach(p_id, p_key, p_sha256);
END;
$$;


--
-- Name: offer_acceptance_email(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_email() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM email_confirmation_queue(NEW.id);
  RETURN NEW;
END;
$$;


--
-- Name: offer_acceptance_for_confirmation(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_for_confirmation(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a offer_acceptance;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  PERFORM offer_for_edit(a.offer_id);
  RETURN offer_acceptance_result(p_id, false);
END;
$$;


--
-- Name: offer_acceptance_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF crm_internal_call() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  RAISE EXCEPTION 'Akceptáciu zapisuje a ruší iba CRM.' USING ERRCODE = 'insufficient_privilege';
END;
$$;


--
-- Name: offer_acceptance_result(uuid, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_result(p_id uuid, p_repeated boolean) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'ok', true, 'repeated', p_repeated, 'acceptance_id', a.id, 'accepted_at', a.accepted_at,
           'variant', chr(64 + v.sort_order) || ' · ' || v.name, 'method', a.method, 'channel', a.channel,
           'signer_name', a.signer_name, 'signer_function', a.signer_function, 'ip', host(a.ip),
           'terms_text', a.terms_text, 'terms_sha256', a.terms_sha256,
           'confirmation_key', offer_acceptance_confirmation_key(a.id),
           'confirmation_stored', a.confirmation_pdf_key IS NOT NULL,
           'document', offer_document_internal(a.offer_id))
    FROM offer_acceptance a JOIN offer_variant v ON v.id = a.variant_id
   WHERE a.id = p_id
$$;


--
-- Name: offer_acceptance_revoke(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_acceptance_revoke(p_id uuid, p_reason text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  a       offer_acceptance;
  o       offer;
  d       deal;
  v_stage uuid;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Akceptáciu ruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF coalesce(btrim(p_reason), '') = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod zrušenia akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR a.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Akceptácia neexistuje alebo už je zrušená.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO o FROM offer WHERE id = a.offer_id FOR UPDATE;
  SELECT * INTO d FROM deal d2 WHERE d2.id = o.deal_id FOR UPDATE;
  IF d.closed_at IS NOT NULL OR (SELECT code FROM pipeline_stage WHERE id = d.stage_id) = 'vyhrane' THEN
    RAISE EXCEPTION 'K obchodu už je spárovaná zmluva (Vyhraté) – akceptáciu nemožno zrušiť.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_acceptance SET revoked_at = now(), revoked_by = crm_active_user_id(), revoke_reason = btrim(p_reason) WHERE id = a.id;
  UPDATE offer SET status = 'odoslana' WHERE id = o.id;
  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'vyjednavanie'
   WHERE s.id = d.stage_id AND s.code = 'akceptacia';
  UPDATE deal SET accepted_variant_id = NULL, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'akceptacia_zrusena', jsonb_build_object('reason', btrim(p_reason)));
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'akceptacia_zrusena', d.id, NULL, NULL,
                                'Akceptácia ponuky ' || offer_display_number(o) || ' bola zrušená');
END;
$$;


--
-- Name: offer_asset_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_asset_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF crm_owner_session() OR crm_internal_call() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Obrázok sa nemaže – nahrajte nový.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' AND ((NEW.data, NEW.code, NEW.mime, NEW.sha256, NEW.org_id) IS DISTINCT FROM (OLD.data, OLD.code, OLD.mime, OLD.sha256, OLD.org_id)
                           OR (NEW.active AND NOT OLD.active)) THEN
    RAISE EXCEPTION 'Obrázok sa nemení – nahrajte nový.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.sha256 := encode(sha256(NEW.data), 'hex');
    NEW.created_by := crm_active_user_id();
    UPDATE offer_asset SET active = false WHERE org_id = NEW.org_id AND code = NEW.code AND active;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: offer_attach_pdf(uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_attach_pdf(p_offer uuid, p_key text, p_sha256 text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  t offer_template_version := offer_template_for(p_offer);
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') OR o.pdf_key IS NOT NULL THEN
    RAISE EXCEPTION 'PDF sa ukladá iba pri odoslaní ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF t.id IS NULL OR t.status = 'navrh' THEN
    RAISE EXCEPTION 'Šablóna ponuky (%, %) ešte nie je schválená – admin ju zverejní v Nastaveniach → Šablóny ponúk.',
      o.kind, upper(o.language::text) USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET pdf_key = p_key, pdf_sha256 = p_sha256, pdf_generated_at = now(), template_version_id = t.id
   WHERE id = o.id;
END;
$$;


--
-- Name: offer_back_to_draft(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_back_to_draft(p_offer uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  PERFORM offer_cancel_pending_approvals(p_offer);
  UPDATE offer SET status = 'koncept' WHERE id = p_offer AND status IN ('pripravena', 'caka_na_schvalenie');
END;
$$;


--
-- Name: offer_basis_fill(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_basis_fill(p_variant uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v  offer_variant;
  o  offer;
  d  deal;
  y  smallint;
  st seller_type;
  lz boolean;
BEGIN
  SELECT * INTO v FROM offer_variant WHERE id = p_variant;
  SELECT * INTO o FROM offer WHERE id = v.offer_id;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  st := coalesce(o.seller_type, 'obchodnik');
  lz := EXISTS (SELECT 1 FROM deal_oom x JOIN oom m ON m.id = x.oom_id WHERE x.deal_id = d.id AND m.source_category = 'lokalny_zdroj');
  DELETE FROM offer_year_basis b WHERE b.variant_id = v.id AND b.year NOT IN (SELECT DISTINCT year FROM offer_variant_months(v));
  FOR y IN SELECT DISTINCT year FROM offer_variant_months(v) ORDER BY 1 LOOP
    INSERT INTO offer_year_basis (variant_id, year, seller_type, trader_price, portfolio_eur_mwh, min_additive,
                                  energopomoc_price, viwa_additive, computed_on)
    VALUES (v.id, y, st,
            trader_price(o.org_id, y, o.priced_on),
            (SELECT value FROM contract_market_value(o.org_id, y, o.priced_on, 'portfolio')),
            contract_param(o.org_id,
              CASE WHEN o.kind = 'vykup' THEN CASE WHEN lz THEN 'min_aditiv_vykup_lz' ELSE 'min_aditiv_vykup' END
                   WHEN st = 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, o.priced_on),
            contract_param(o.org_id, 'nakup_energopomoc', o.priced_on, y),
            CASE WHEN v.viwa_package IS NOT NULL THEN contract_param(o.org_id, 'viwa_aditiv_' || v.viwa_package, o.priced_on) END,
            o.priced_on)
    ON CONFLICT (variant_id, year) DO UPDATE
       SET seller_type = EXCLUDED.seller_type, trader_price = EXCLUDED.trader_price,
           portfolio_eur_mwh = EXCLUDED.portfolio_eur_mwh, min_additive = EXCLUDED.min_additive,
           energopomoc_price = EXCLUDED.energopomoc_price, viwa_additive = EXCLUDED.viwa_additive,
           computed_on = EXCLUDED.computed_on;
  END LOOP;
END;
$$;


--
-- Name: offer_cancel_pending_approvals(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_cancel_pending_approvals(p_offer uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF crm_active_user_id() IS NOT NULL AND NOT EXISTS (
       SELECT 1 FROM offer o JOIN deal d ON d.id = o.deal_id
        WHERE o.id = p_offer AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Ponuku nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'caka'
     AND id IN (SELECT a.approval_id FROM approval_price_item a JOIN offer_variant v ON v.id = a.variant_id WHERE v.offer_id = p_offer);
END;
$$;


--
-- Name: offer_check(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_check(p_offer uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT CASE WHEN c IS NULL OR crm_sees_portfolio() THEN c
              ELSE jsonb_set(c, '{needs}', coalesce(
                     (SELECT jsonb_agg(CASE WHEN n->>'threshold_source' = 'odhad_portfolia'
                                            THEN jsonb_set(n, '{threshold_value}', 'null') ELSE n END ORDER BY t.ord)
                        FROM jsonb_array_elements(c->'needs') WITH ORDINALITY AS t(n, ord)), '[]')) END
    FROM offer_check_internal(p_offer) AS c
$$;


--
-- Name: offer_check_internal(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_check_internal(p_offer uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
  v_acc   offer;
  v_pen   numeric;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  -- zákazník akceptoval inú verziu: rozpracovaná verzia sa nedá pripraviť ani odoslať (0038)
  SELECT * INTO v_acc FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.id <> o.id AND x.status = 'akceptovana';
  IF FOUND THEN
    errors := errors || to_jsonb(format('Zákazník akceptoval ponuku %s – túto verziu nemožno odoslať.', offer_display_number(v_acc)));
  ELSIF o.blocked_by_offer_id IS NOT NULL THEN
    errors := errors || to_jsonb('Verzia je zablokovaná po akceptácii inej verzie – zákazník akceptoval inú verziu. Odblokuje ju vlastník obchodu alebo admin.'::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE offer_id = o.id) THEN
    errors := errors || to_jsonb('Ponuka nemá variant.'::text);
  END IF;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    FOR r IN SELECT x.year, x.missing, m.eic FROM offer_variant_values(v.id) x LEFT JOIN oom m ON m.id = x.oom_id
              WHERE x.missing IS NOT NULL ORDER BY x.year, m.eic LOOP
      errors := errors || to_jsonb(format('Variant %s (%s): %s – OOM %s, rok %s', chr(64 + v.sort_order), v.name, r.missing, r.eic, r.year));
    END LOOP;
    FOR r IN SELECT x.year, x.price_model, x.voltage_group,
                    min(CASE WHEN x.price_model = 'spot_minus_pct' THEN x.additive_pct
                             WHEN x.price_model IN ('spot_plus_eur', 'spot_minus_eur') THEN x.additive
                             ELSE least(x.price_vt, coalesce(x.price_nt, x.price_vt)) END) AS requested,
                    min(b.th) AS threshold, min(b.src) AS source, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th,
                                         CASE WHEN x.price_model <> 'fix' THEN 'min_aditiv'
                                              WHEN ob.seller_type = 'manazer' THEN 'odhad_portfolia'
                                              ELSE 'cena_pre_obchodnika' END AS src
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold,
                                           'threshold_source', coalesce(r.source, 'cena_pre_obchodnika'), 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
  -- zmluvná pokuta pod predvolenou hodnotou šablóny (dodávka 50, výkup 30 €/MWh) → schválenie ako výnimka z ceny (0039)
  v_pen := ((offer_template_for(o.id)).defaults->>'zmluvna_pokuta')::numeric;
  IF o.penalty_eur_mwh IS NOT NULL AND v_pen IS NOT NULL AND o.penalty_eur_mwh < v_pen
     AND NOT EXISTS (SELECT 1 FROM approval_request a
                      WHERE a.offer_id = o.id AND a.kind = 'vynimka_ceny' AND a.status = 'schvalena'
                        AND a.penalty_eur_mwh IS NOT NULL AND a.penalty_eur_mwh <= o.penalty_eur_mwh
                        AND CASE WHEN o.sent_at IS NULL THEN a.valid_until IS NULL OR a.valid_until > now()
                                 ELSE a.valid_until IS NULL OR o.sent_at <= a.valid_until END) THEN
    needs := needs || jsonb_build_object('type', 'pokuta', 'variant_id', NULL, 'variant', NULL, 'year', NULL, 'price_model', NULL,
                                         'voltage_group', NULL, 'requested_value', o.penalty_eur_mwh, 'threshold_value', v_pen,
                                         'threshold_source', 'zmluvna_pokuta', 'volume_mwh', NULL);
  END IF;
  v_risk := CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END;
  -- schválenie rizika platí pre celý obchod 30 dní, kým sa údaje Finstatu nezhoršia (odpoveď 9)
  v_risk_ok := EXISTS (SELECT 1 FROM approval_request a
                        WHERE a.deal_id = d.id AND a.kind = 'rizikovy_zakaznik' AND a.status = 'schvalena'
                          AND (a.valid_until IS NULL OR a.valid_until > now())
                          AND NOT company_risk_worse(a.risk_snapshot, company_risk_snapshot(d.company_id)));
  RETURN jsonb_build_object('errors', errors, 'needs', needs,
                            'risk_needs_approval', coalesce((v_risk->>'needs_approval')::boolean, false) AND NOT v_risk_ok,
                            'risk', v_risk,
                            'fix_stale', o.priced_on < crm_today()
                                         AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
END;
$$;


--
-- Name: offer_child_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_child_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_variant uuid;
  v_offer   uuid;
  o         offer;
  v         offer_variant;
  p         product;
  v_app     boolean := NOT (crm_internal_call() OR current_user = 'crm_sync');
BEGIN
  IF TG_TABLE_NAME = 'offer_variant' THEN
    v_offer := coalesce(NEW.offer_id, OLD.offer_id);
  ELSE
    v_variant := coalesce(NEW.variant_id, OLD.variant_id);
    SELECT offer_id INTO v_offer FROM offer_variant WHERE id = v_variant;
  END IF;
  SELECT * INTO o FROM offer WHERE id = v_offer;
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') AND v_app THEN
    RAISE EXCEPTION 'Odoslaná ponuka sa nemení – vytvorte novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF v_app AND o.status <> 'koncept' THEN
      PERFORM offer_back_to_draft(o.id);
    END IF;
    RETURN OLD;
  END IF;
  NEW.org_id := o.org_id;

  IF TG_TABLE_NAME = 'offer_variant' THEN
    IF NEW.offer_id IS DISTINCT FROM coalesce(OLD.offer_id, NEW.offer_id) THEN
      RAISE EXCEPTION 'Variant nepatrí inej ponuke.' USING ERRCODE = 'check_violation';
    END IF;
    IF (NEW.price_kind = 'viwa') <> (o.kind = 'viwa') THEN
      RAISE EXCEPTION 'Variant VIWA patrí iba do ponuky VIWA.' USING ERRCODE = 'check_violation';
    END IF;
  ELSE
    SELECT * INTO v FROM offer_variant WHERE id = NEW.variant_id;
    IF NEW.oom_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = o.deal_id AND x.oom_id = NEW.oom_id) THEN
      RAISE EXCEPTION 'OOM nie je na obchode ponuky.' USING ERRCODE = 'check_violation';
    END IF;
    IF NEW.year IS NOT NULL AND NOT EXISTS (SELECT 1 FROM offer_variant_months(v) m WHERE m.year = NEW.year) THEN
      RAISE EXCEPTION 'Rok % nie je v období variantu.', NEW.year USING ERRCODE = 'check_violation';
    END IF;
    SELECT * INTO p FROM product WHERE id = NEW.product_id;
    IF v_app THEN
      IF NEW.price_model = 'cennik' OR (TG_OP = 'UPDATE' AND OLD.price_model = 'cennik') THEN
        RAISE EXCEPTION 'Ceny z cenníka dopĺňa CRM a obchodník ich nemení.' USING ERRCODE = 'check_violation';
      END IF;
      IF o.household AND NEW.slot = 'komodita' AND v.price_kind = 'cennik' THEN
        RAISE EXCEPTION 'Domácnosť má ceny z cenníka.' USING ERRCODE = 'check_violation';
      END IF;
      IF p.status <> 'predava_sa' AND (TG_OP = 'INSERT' OR NEW.product_id <> OLD.product_id) THEN
        RAISE EXCEPTION 'Produkt % sa už nepredáva.', p.name USING ERRCODE = 'check_violation';
      END IF;
    END IF;
    IF NOT NEW.price_model = ANY (p.price_models) THEN
      RAISE EXCEPTION 'Produkt % nemá cenový model %.', p.name, NEW.price_model USING ERRCODE = 'check_violation';
    END IF;
  END IF;

  IF v_app AND o.status <> 'koncept' THEN
    PERFORM offer_back_to_draft(o.id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: offer_create(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_create(p_deal uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  d       deal;
  p       pipeline;
  o       offer;
  v_kind  offer_kind;
  v_pk    offer_price_kind;
  v_from  date;
  v_year  integer := extract(year FROM crm_today());
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal FOR UPDATE;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Obchod neexistuje alebo ho nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať ponuku.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE deal_id = d.id AND status <> 'nahradena') THEN
    RAISE EXCEPTION 'Obchod už má ponuku – vytvorte jej novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM deal_oom WHERE deal_id = d.id) THEN
    RAISE EXCEPTION 'Pred ponukou pridajte do obchodu aspoň jedno OOM.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO p FROM pipeline WHERE id = d.pipeline_id;
  v_kind := CASE p.kind WHEN 'b2b_vykup' THEN 'vykup' WHEN 'green_viwa' THEN 'viwa' ELSE 'dodavka' END;
  v_pk := CASE WHEN d.person_id IS NOT NULL THEN 'cennik' WHEN v_kind = 'vykup' THEN 'spot' WHEN v_kind = 'viwa' THEN 'viwa' ELSE 'fix' END;
  v_from := coalesce(d.supply_start, make_date(v_year + 1, 1, 1));

  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, contact_id, priced_on, seller_type, created_by)
  VALUES (d.id, d.org_id,
          'P' || lpad((v_year % 100)::text, 2, '0') || '-' || lpad(doc_number_next(d.org_id, 'ponuka', v_year)::text, 6, '0'),
          1, v_kind, d.person_id IS NOT NULL, 'koncept',
          (SELECT contact_id FROM deal_contact WHERE deal_id = d.id AND is_primary),
          crm_today(),
          coalesce((SELECT seller_type FROM app_user WHERE id = d.owner_id), 'obchodnik'),
          crm_current_user_id())
  RETURNING * INTO o;

  INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package)
  VALUES (o.id, o.org_id, 1,
          offer_variant_default_name(v_pk, v_from, CASE WHEN v_pk = 'fix' THEN make_date(extract(year FROM v_from)::int, 12, 31) END),
          v_pk, v_from,
          CASE WHEN v_pk = 'fix' THEN make_date(extract(year FROM v_from)::int, 12, 31) END,
          CASE WHEN v_pk = 'viwa' THEN 'plus' END);
  PERFORM deal_event_offer(o, 'ponuka_nova');
  RETURN o.id;
END;
$$;


--
-- Name: offer_default_valid_until(uuid, timestamp with time zone, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_default_valid_until(p_org uuid, p_sent_at timestamp with time zone, p_fix boolean) RETURNS timestamp with time zone
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_day date := (p_sent_at AT TIME ZONE 'Europe/Bratislava')::date;
  v_end date;
BEGIN
  IF p_fix THEN
    v_end := next_working_day(p_org, v_day);
  ELSE
    v_end := v_day + 14;
    IF NOT coalesce((SELECT is_working_day FROM business_calendar
                      WHERE org_id = coalesce(p_org, crm_default_org()) AND date = v_end), true) THEN
      v_end := next_working_day(p_org, v_end);
    END IF;
  END IF;
  RETURN (v_end + time '16:00') AT TIME ZONE 'Europe/Bratislava';
END;
$$;


--
-- Name: offer_display_number(public.offer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_display_number(o public.offer) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT o.number || CASE WHEN o.version > 1 THEN '/' || o.version ELSE '' END
$$;


--
-- Name: offer_doc_valid_until(public.offer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_doc_valid_until(o public.offer) RETURNS timestamp with time zone
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce(o.valid_until,
                  offer_default_valid_until(o.org_id, now(),
                    EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'))))
$$;


--
-- Name: offer_doc_variants(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_doc_variants(p_offer uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  res   jsonb := '[]';
  rows  jsonb;
  vol   numeric;
  viwa  jsonb;
  hh    jsonb;
  coef  numeric;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    -- ročný objem: plánovaný, inak súčet OOM (spotreba alebo výroba)
    SELECT coalesce(v.planned_volume_mwh,
                    sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                             THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                             ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END))
      INTO vol FROM deal_oom x WHERE x.deal_id = o.deal_id;

    -- riadky: OOM s rovnakým produktom, napätím a cenami po rokoch sa zlúčia (počet OOM, súčet objemu)
    WITH it AS (
      SELECT i.oom_id, i.product_id, i.price_model, i.year, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
             i.additive_eur_mwh AS ad, i.additive_pct AS pct,
             coalesce(li.vat_rate, p.vat_rate) AS vat
        FROM offer_item i JOIN product p ON p.id = i.product_id
        LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.oom_id IS NOT NULL
    ),
    per_oom AS (
      SELECT it.oom_id, it.product_id, it.price_model, max(it.vat) AS vat,
             jsonb_agg(jsonb_build_object('year', it.year, 'vt', it.vt, 'nt', it.nt, 'ad', it.ad, 'pct', it.pct)
                       ORDER BY it.year NULLS FIRST) AS prices
        FROM it GROUP BY 1, 2, 3
    ),
    grp AS (
      SELECT po.product_id, oom_voltage_group(m.voltage_level) AS vg, po.price_model, po.prices, max(po.vat) AS vat,
             count(*)::int AS ooms,
             sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                      THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                      ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END) AS vol
        FROM per_oom po
        JOIN oom m ON m.id = po.oom_id
        JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = po.oom_id
       GROUP BY 1, 2, 3, 4
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'product', p.name, 'voltage_group', g.vg, 'oom_count', g.ooms, 'volume_mwh', round(g.vol, 3),
             'price_model', g.price_model, 'vat_rate', g.vat,
             'prices', (SELECT jsonb_agg(jsonb_build_object(
                           'year', (e->>'year')::int,
                           'text', CASE g.price_model
                                     WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num((e->>'pct')::numeric, 2, lang) || ' %'
                                     ELSE offer_fmt_num((e->>'vt')::numeric, 2, lang)
                                          || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric, 2, lang) ELSE '' END
                                          || ' €/MWh' END,
                           'text_vat', CASE WHEN o.household AND g.price_model IN ('fix', 'cennik') AND g.vat IS NOT NULL THEN
                                         offer_fmt_num((e->>'vt')::numeric * (1 + g.vat / 100), 2, lang)
                                         || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric * (1 + g.vat / 100), 2, lang) ELSE '' END
                                         || ' €/MWh' END)
                         ORDER BY (e->>'year')::int NULLS FIRST)
                          FROM jsonb_array_elements(g.prices) e))
             ORDER BY g.vg, p.name), '[]')
      INTO rows
      FROM grp g JOIN product p ON p.id = g.product_id;

    -- VIWA: balík, mesačný poplatok účtu, €/kW za odchýlku, koeficient výmeny – zmluvná podmienka balíka z programu
    -- položky cenníka (modul 3); odhad aditívu balíka slúži iba na pridanú hodnotu a koeficient nemení
    viwa := NULL;
    IF v.price_kind = 'viwa' THEN
      SELECT pr.viwa_conversion_factor INTO coef
        FROM offer_item i JOIN price_list_item_program pr ON pr.item_id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'viwa_ucet';
      SELECT jsonb_build_object(
               'package', upper(v.viwa_package),
               'monthly_fee', (SELECT fee_eur_month FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_ucet'),
               'fee_kw', (SELECT max(fee_kw_eur_month) FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_kw'),
               'coefficient', coef,
               'power_kw', (SELECT sum(coalesce(x.source_power_kw, m.source_power_kw, 0)) FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                             WHERE x.deal_id = o.deal_id))
        INTO viwa;
    END IF;

    -- domácnosť: mesačné poplatky (OM, ZEM, VBattery) a odhad ročných nákladov na komoditu bez DPH a s DPH
    hh := NULL;
    IF o.household THEN
      SELECT jsonb_build_object(
               'fees_month', sum(coalesce(i.fee_eur_month, 0)),
               'cost_year', (SELECT sum(coalesce(c.price_vt_eur_mwh, 0) * coalesce(x.planned_vt_mwh, 0)
                                        + coalesce(c.price_nt_eur_mwh, c.price_vt_eur_mwh, 0) * coalesce(x.planned_nt_mwh, 0))
                               FROM offer_item c JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = c.oom_id
                              WHERE c.variant_id = v.id AND c.slot = 'komodita' AND c.price_model IN ('fix', 'cennik')),
               'vat_rate', max(coalesce(li.vat_rate, p.vat_rate)))
        INTO hh
        FROM offer_item i JOIN product p ON p.id = i.product_id LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id;
      hh := hh || jsonb_build_object('cost_year_total', round((hh->>'cost_year')::numeric + (hh->>'fees_month')::numeric * 12, 2));
    END IF;

    res := res || jsonb_build_object(
      'id', v.id, 'letter', chr(64 + v.sort_order), 'name', v.name, 'label', chr(64 + v.sort_order) || ' · ' || v.name,
      'price_kind', v.price_kind,
      'period', CASE WHEN v.supply_to IS NULL
                     THEN CASE lang WHEN 'sk' THEN 'od ' || offer_fmt_date(v.supply_from, lang) || ' na neurčito'
                                    ELSE 'from ' || offer_fmt_date(v.supply_from, lang) || ', indefinite' END
                     ELSE offer_fmt_date(v.supply_from, lang) || ' – ' || offer_fmt_date(v.supply_to, lang) END,
      'flexibility', CASE WHEN v.flexibility_pct IS NULL THEN CASE lang WHEN 'sk' THEN 'plnej flexibility' ELSE 'full' END
                          ELSE '± ' || offer_fmt_num(v.flexibility_pct, 0, lang) || ' %' END,
      'volume_mwh', round(vol, 3),
      'volume_text', offer_fmt_num(vol, 1, lang),
      'advance', CASE v.advance_kind
                   WHEN 'financna_zabezpeka' THEN CASE lang WHEN 'sk' THEN 'finančnej zábezpeky' ELSE 'a financial guarantee' END
                   ELSE CASE lang WHEN 'sk' THEN offer_fmt_num(v.advance_pct, 0, lang) || ' % z 1/12 plánovaného ročného odberu'
                                  ELSE offer_fmt_num(v.advance_pct, 0, lang) || '% of 1/12 of the planned annual consumption' END END,
      'advance_due', CASE WHEN v.advance_due_day IS NULL THEN NULL
                          WHEN lang = 'sk' THEN v.advance_due_day || '. deň v mesiaci'
                          ELSE 'day ' || v.advance_due_day || ' of the month' END,
      'invoice_due', v.invoice_due_days || CASE lang WHEN 'sk' THEN ' dní' ELSE ' days' END,
      'spot', EXISTS (SELECT 1 FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita'
                        AND i.price_model IN ('spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct'))
              OR v.price_kind = 'spot',
      'negative_price_compensation', v.negative_price_compensation,
      'rows', rows, 'viwa', viwa, 'household', hh);
  END LOOP;
  RETURN res;
END;
$$;


--
-- Name: offer_doc_vars(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_doc_vars(p_offer uuid, p_variants jsonb) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer;
  d     deal;
  c     company;
  pe    contact;
  k     contact;
  u     app_user;
  t     offer_template_version;
  lang  offer_language;
  vu    timestamptz;
  pen   numeric;
  f     text;
  per   jsonb := '{}';
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO c FROM company WHERE id = d.company_id;
  SELECT * INTO pe FROM contact WHERE id = d.person_id;
  SELECT * INTO k FROM contact WHERE id = o.contact_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  t := offer_template_for(o.id);
  lang := o.language;
  vu := offer_doc_valid_until(o);
  pen := coalesce(o.penalty_eur_mwh, (t.defaults->>'zmluvna_pokuta')::numeric);
  FOREACH f IN ARRAY ARRAY['flexibility', 'volume_text', 'advance', 'advance_due', 'invoice_due', 'period'] LOOP
    per := per || jsonb_build_object(f,
      CASE WHEN (SELECT count(DISTINCT coalesce(x->>f, '')) FROM jsonb_array_elements(p_variants) x) <= 1
           THEN (SELECT x->>f FROM jsonb_array_elements(p_variants) x LIMIT 1)
           ELSE (SELECT string_agg((x->>'letter') || ': ' || coalesce(x->>f, '–'), '; ') FROM jsonb_array_elements(p_variants) x) END);
  END LOOP;
  RETURN jsonb_build_object(
    'číslo ponuky', offer_display_number(o),
    'dátum ponuky', offer_fmt_date((coalesce(o.sent_at, now()) AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'názov', coalesce(c.name, nullif(btrim(concat_ws(' ', pe.title, pe.first_name, pe.last_name)), '')),
    'sídlo', coalesce(c.address, pe.address),
    'IČO', c.ico,
    'IČ DPH', c.ic_dph,
    'kontakt meno', nullif(btrim(concat_ws(' ', k.title, k.first_name, k.last_name)), ''),
    'kontakt e-mail', k.email,
    'kontakt telefón', coalesce(k.mobile, k.phone),
    'obchodník meno', u.name,
    'obchodník funkcia', u.job_title,
    'obchodník telefón', u.phone,
    'obchodník e-mail', u.email,
    'flexibilita', per->>'flexibility',
    'objem', per->>'volume_text',
    'výška preddavkov', per->>'advance',
    'splatnosť preddavku', per->>'advance_due',
    'splatnosť faktúr', per->>'invoice_due',
    'obdobie', per->>'period',
    'platnosť čas', to_char(vu AT TIME ZONE 'Europe/Bratislava', 'HH24:MI'),
    'platnosť dátum', offer_fmt_date((vu AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'dátum platnosti', to_char(vu AT TIME ZONE 'Europe/Bratislava', 'HH24:MI') || CASE lang WHEN 'sk' THEN ' hod. ' ELSE ' on ' END
                       || offer_fmt_date((vu AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'zmluvná pokuta', offer_fmt_num(pen, 2, lang),
    'koeficient', (SELECT CASE WHEN count(DISTINCT x->'viwa'->>'coefficient') <= 1
                               THEN offer_fmt_num(max((x->'viwa'->>'coefficient')::numeric), 2, lang)
                               ELSE string_agg((x->>'letter') || ': ' || offer_fmt_num((x->'viwa'->>'coefficient')::numeric, 2, lang), '; ') END
                     FROM jsonb_array_elements(p_variants) x WHERE x->'viwa' IS NOT NULL AND x->>'viwa' <> 'null'),
    'poplatok za kW', (SELECT CASE WHEN count(DISTINCT x->'viwa'->>'fee_kw') <= 1
                                   THEN offer_fmt_num(max((x->'viwa'->>'fee_kw')::numeric), 2, lang)
                                   ELSE string_agg((x->>'letter') || ': ' || offer_fmt_num((x->'viwa'->>'fee_kw')::numeric, 2, lang), '; ') END
                         FROM jsonb_array_elements(p_variants) x WHERE x->'viwa' IS NOT NULL AND x->>'viwa' <> 'null'));
END;
$$;


--
-- Name: offer_document(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_document(p_offer uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT offer_document_internal(o.id)
    FROM offer o JOIN deal d ON d.id = o.deal_id
   WHERE o.id = p_offer AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
$$;


--
-- Name: offer_document_internal(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_document_internal(p_offer uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o    offer;
  t    offer_template_version;
  vs   jsonb;
  vars jsonb;
  sec  jsonb := '[]';
  key  text;
  spot boolean;
  komp boolean;
  vu   timestamptz;
  acc  offer_acceptance;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  t := offer_template_for(o.id);
  vs := offer_doc_variants(o.id);
  vars := offer_doc_vars(o.id, vs);
  vu := offer_doc_valid_until(o);
  spot := EXISTS (SELECT 1 FROM jsonb_array_elements(vs) x WHERE (x->>'spot')::boolean);
  komp := EXISTS (SELECT 1 FROM jsonb_array_elements(vs) x WHERE (x->>'negative_price_compensation')::boolean);
  IF t.id IS NOT NULL THEN
    FOREACH key IN ARRAY offer_template_keys() LOOP
      CONTINUE WHEN NOT t.sections ? key OR key = 'objednavka';
      sec := sec || jsonb_build_object('key', key,
                                       'nadpis', offer_template_fill(t.sections->key->>'nadpis', vars, spot, komp),
                                       'text', offer_template_fill(t.sections->key->>'text', vars, spot, komp));
    END LOOP;
  END IF;
  SELECT * INTO acc FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  RETURN jsonb_build_object(
    'offer', jsonb_build_object('id', o.id, 'number', o.number, 'version', o.version, 'display_number', offer_display_number(o),
                                'kind', o.kind, 'language', o.language, 'household', o.household, 'status', o.status,
                                'state', offer_state(o), 'sent_at', o.sent_at, 'valid_until', vu, 'stored_valid_until', o.valid_until,
                                'pdf', o.pdf_key IS NOT NULL),
    'template', CASE WHEN t.id IS NOT NULL THEN jsonb_build_object('id', t.id, 'version', t.version, 'status', t.status,
                                                                    'order_title', offer_template_fill(t.sections->'objednavka'->>'nadpis', vars, spot, komp),
                                                                    -- znenie pre PDF: «variant» ostáva, PDF ho nahradí voľbou variantov
                                                                    'order_text', offer_template_fill(t.sections->'objednavka'->>'text', vars, spot, komp)) END,
    'vars', vars,
    'sections', sec,
    'variants', (SELECT coalesce(jsonb_agg(x || jsonb_build_object(
                    'terms', offer_terms_text(o.id, (x->>'id')::uuid),
                    'terms_sha256', offer_terms_sha(offer_terms_text(o.id, (x->>'id')::uuid)))), '[]')
                   FROM jsonb_array_elements(vs) x),
    'acceptance', CASE WHEN acc.id IS NOT NULL THEN jsonb_build_object(
                    'variant_id', acc.variant_id, 'variant', (SELECT chr(64 + sort_order) || ' · ' || name FROM offer_variant WHERE id = acc.variant_id),
                    'method', acc.method, 'channel', acc.channel, 'accepted_at', acc.accepted_at,
                    'signer_name', acc.signer_name, 'signer_function', acc.signer_function) END);
END;
$$;


--
-- Name: offer_email_lock(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_email_lock() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  r       jsonb := to_jsonb(CASE WHEN TG_OP = 'DELETE' THEN OLD ELSE NEW END);
  v_offer uuid;
  v_msg   uuid;
BEGIN
  v_offer := CASE TG_TABLE_NAME WHEN 'offer' THEN (r->>'id')::uuid
                                WHEN 'offer_variant' THEN (r->>'offer_id')::uuid
                                ELSE (SELECT offer_id FROM offer_variant WHERE id = (r->>'variant_id')::uuid) END;
  SELECT id INTO v_msg FROM email_message WHERE offer_id = v_offer AND status = 'odosiela_sa' AND kind = 'ponuka';
  IF v_msg IS NOT NULL AND coalesce(current_setting('crm.email_send', true), '') <> v_msg::text THEN
    RAISE EXCEPTION 'Ponuka sa práve odosiela e-mailom – skúste to o chvíľu.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: offer_fill_price_list(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_fill_price_list(p_variant uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v    offer_variant;
  o    offer;
  r    record;
  n    integer := 0;
BEGIN
  SELECT * INTO v FROM offer_variant WHERE id = p_variant;
  SELECT * INTO o FROM offer WHERE id = v.offer_id;
  DELETE FROM offer_item WHERE variant_id = v.id AND price_model = 'cennik';
  FOR r IN
    SELECT x.oom_id, c.product_id,
           (SELECT i.id FROM price_list_item i JOIN price_list_version pv ON pv.id = i.version_id
             WHERE i.product_id = c.product_id AND pv.status = 'schvalena'
               AND pv.valid_from <= v.supply_from AND (pv.valid_to IS NULL OR pv.valid_to >= v.supply_from)
             ORDER BY pv.valid_from DESC LIMIT 1) AS item_id,
           p.category
      FROM deal_oom x
      JOIN LATERAL product_candidates(x.oom_id) c ON true
      JOIN product p ON p.id = c.product_id
     WHERE x.deal_id = o.deal_id AND (c.rank = 1 OR c.is_addon)
  LOOP
    CONTINUE WHEN r.item_id IS NULL;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, fee_eur_month)
    SELECT v.id, r.oom_id, v.org_id, NULL,
           CASE WHEN r.category = 'zem' THEN 'zem' ELSE 'komodita' END,
           r.product_id, 'cennik', i.id, i.price_vt_eur_mwh, i.price_nt_eur_mwh, coalesce(i.fee_oom_eur_month, i.fee_program_eur_month)
      FROM price_list_item i WHERE i.id = r.item_id
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
    n := n + 1;
  END LOOP;
  RETURN n;
END;
$$;


--
-- Name: offer_fill_viwa(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_fill_viwa(p_variant uuid) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v    offer_variant;
  o    offer;
  p    product;
  it   price_list_item;
  n    integer := 0;
BEGIN
  SELECT * INTO v FROM offer_variant WHERE id = p_variant;
  IF NOT FOUND OR v.price_kind <> 'viwa' OR v.viwa_package IS NULL THEN
    RETURN 0;
  END IF;
  SELECT * INTO o FROM offer WHERE id = v.offer_id;
  DELETE FROM offer_item WHERE variant_id = v.id AND price_model = 'cennik';
  SELECT * INTO p FROM product WHERE code = 'viwa_' || v.viwa_package;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  SELECT i.* INTO it FROM price_list_item i JOIN price_list_version pv ON pv.id = i.version_id
    JOIN price_list pl ON pl.id = pv.price_list_id
   WHERE i.product_id = p.id AND pv.status = 'schvalena' AND pl.org_id = o.org_id
     AND pv.valid_from <= v.supply_from AND (pv.valid_to IS NULL OR pv.valid_to >= v.supply_from)
   ORDER BY pv.valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN 0;   -- bez cenníka: výpočet hlási „chýba cena“
  END IF;
  INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id, fee_eur_month)
  VALUES (v.id, NULL, v.org_id, NULL, 'viwa_ucet', p.id, 'cennik', it.id, it.fee_program_eur_month);
  INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id, fee_kw_eur_month)
  SELECT v.id, x.oom_id, v.org_id, NULL, s.slot, p.id, 'cennik', it.id, CASE WHEN s.slot = 'viwa_kw' THEN it.fee_kw_eur_month END
    FROM deal_oom x CROSS JOIN (VALUES ('komodita'), ('viwa_kw')) s(slot)
   WHERE x.deal_id = o.deal_id
  ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n + 1;
END;
$$;


--
-- Name: offer_fmt_date(date, public.offer_language); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_fmt_date(p date, p_lang public.offer_language) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p IS NULL THEN '–' WHEN p_lang = 'sk' THEN to_char(p, 'FMDD. FMMM. YYYY') ELSE to_char(p, 'DD/MM/YYYY') END
$$;


--
-- Name: offer_fmt_num(numeric, integer, public.offer_language); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_fmt_num(p numeric, p_dec integer, p_lang public.offer_language) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p IS NULL THEN '–'
              ELSE CASE p_lang WHEN 'sk' THEN translate(s, ',.', ' ,') ELSE s END END
    FROM (SELECT btrim(to_char(round(p, p_dec), 'FM999,999,999,990' || CASE WHEN p_dec > 0 THEN '.' || repeat('0', p_dec) ELSE '' END)) AS s) x
$$;


--
-- Name: offer_for_edit(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_for_edit(p_offer uuid) RETURNS public.offer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer;
  d deal;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF FOUND THEN
    SELECT * INTO d FROM deal WHERE id = o.deal_id;
  END IF;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Ponuka neexistuje alebo ju nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN o;
END;
$$;


--
-- Name: offer_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF crm_internal_call() OR current_user = 'crm_sync' THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'Ponuku zakladá funkcia offer_create.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'koncept' OR OLD.sent_at IS NOT NULL THEN
      RAISE EXCEPTION 'Zmazať sa dá iba koncept, ktorý nebol odoslaný.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF OLD.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslaná ponuka sa nemení – vytvorte novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF (NEW.number, NEW.version, NEW.deal_id, NEW.kind, NEW.household, NEW.priced_on, NEW.seller_type, NEW.status,
      NEW.sent_at, NEW.sent_by, NEW.sent_channel, NEW.valid_until, NEW.replaced_by_id, NEW.org_id)
     IS DISTINCT FROM
     (OLD.number, OLD.version, OLD.deal_id, OLD.kind, OLD.household, OLD.priced_on, OLD.seller_type, OLD.status,
      OLD.sent_at, OLD.sent_by, OLD.sent_channel, OLD.valid_until, OLD.replaced_by_id, OLD.org_id) THEN
    RAISE EXCEPTION 'Stav, číslo, platnosť a snímku ponuky mení iba CRM (pripraviť, odoslať, nová verzia).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.status <> 'koncept' THEN
    NEW.status := 'koncept';   -- úprava pripravenej ponuky ju vráti do konceptu (schválenie treba znova)
    PERFORM offer_cancel_pending_approvals(OLD.id);
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: offer_link_set(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_link_set(p_offer uuid, p_hash text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o offer := offer_for_edit(p_offer);
  d deal;
BEGIN
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Neplatný odtlačok odkazu.' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status NOT IN ('odoslana', 'otvorena', 'akceptovana', 'zamietnuta') THEN
    RAISE EXCEPTION 'Odkaz má iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF o.link_hash IS NOT NULL AND NOT (d.owner_id = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Nový odkaz smie vytvoriť iba vlastník obchodu alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE offer SET link_hash = p_hash, link_created_at = now(), link_created_by = crm_active_user_id() WHERE id = o.id;
  IF o.link_hash IS NOT NULL THEN
    PERFORM deal_event_offer(o, 'ponuka_odkaz', jsonb_build_object('replaced', true));
  END IF;
END;
$_$;


--
-- Name: offer_mark_sent(uuid, timestamp with time zone, public.offer_send_channel, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_mark_sent(p_offer uuid, p_sent_at timestamp with time zone, p_channel public.offer_send_channel, p_note text) RETURNS timestamp with time zone
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF p_channel IS NULL THEN
    RAISE EXCEPTION 'Vyberte, ako bola ponuka odoslaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_channel = 'crm' THEN
    RAISE EXCEPTION 'Odoslanie e-mailom z CRM zapíše CRM samo.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_send_check(o, p_sent_at);
  RETURN offer_mark_sent_apply(o, p_sent_at, p_channel, p_note, crm_current_user_id());
END;
$$;


--
-- Name: offer_mark_sent_apply(public.offer, timestamp with time zone, public.offer_send_channel, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_mark_sent_apply(o public.offer, p_sent_at timestamp with time zone, p_channel public.offer_send_channel, p_note text, p_by uuid) RETURNS timestamp with time zone
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_fix   boolean;
  v_until timestamptz;
  v_stage uuid;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  v_fix := EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'));
  v_until := offer_default_valid_until(o.org_id, p_sent_at, v_fix);
  UPDATE offer SET status = 'odoslana', sent_at = p_sent_at, sent_by = p_by, sent_channel = p_channel,
                   sent_note = nullif(btrim(p_note), ''), valid_until = v_until
   WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- obchod iba dopredu: z Príležitosti do Cenovej ponuky
  SELECT s2.id INTO v_stage
    FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id
    JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'cenova_ponuka'
   WHERE d.id = o.deal_id AND s.code = 'prilezitost';
  IF v_stage IS NOT NULL THEN
    UPDATE deal SET stage_id = v_stage WHERE id = o.deal_id;
  END IF;
  IF v_stage IS NULL AND crm_setting_on('customer_status_auto') THEN
    PERFORM customer_refresh((SELECT company_id FROM deal WHERE id = o.deal_id), (SELECT person_id FROM deal WHERE id = o.deal_id));
  END IF;
  SELECT * INTO o FROM offer WHERE id = o.id;
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, offer_id, detail)
  VALUES (o.deal_id, o.org_id, 'ponuka_odoslana', p_by, o.id,
          jsonb_build_object('number', o.number, 'version', o.version, 'channel', p_channel, 'sent_at', p_sent_at, 'valid_until', v_until));
  RETURN v_until;
END;
$$;


--
-- Name: offer_new_version(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_new_version(p_offer uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
  v_exc integer := 0;
  v_cnt integer;
BEGIN
  IF o.status IN ('koncept', 'caka_na_schvalenie', 'pripravena') THEN
    RAISE EXCEPTION 'Rozpracovanú ponuku upravte priamo (alebo prepočítajte na dnešné ceny).' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status IN ('akceptovana', 'nahradena') THEN
    RAISE EXCEPTION 'Z akceptovanej alebo nahradenej verzie sa nová verzia nerobí.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE org_id = o.org_id AND number = o.number
                                   AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) THEN
    RAISE EXCEPTION 'Rozpracovaná verzia už existuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT closed_at FROM deal WHERE id = o.deal_id) IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať novú verziu ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, language, contact_id, priced_on, seller_type,
                     custom, created_by)
  SELECT o.deal_id, o.org_id, o.number, (SELECT max(version) + 1 FROM offer WHERE org_id = o.org_id AND number = o.number),
         o.kind, o.household, 'koncept', o.language, o.contact_id, crm_today(),
         coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik'),
         o.custom, crm_current_user_id()
  RETURNING * INTO n;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                               flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                               negative_price_compensation)
    VALUES (n.id, n.org_id, v.sort_order, v.name, v.price_kind, v.supply_from, v.supply_to, v.viwa_package,
            v.flexibility_pct, v.planned_volume_mwh, v.invoice_due_days, v.advance_kind, v.advance_pct, v.advance_due_day,
            v.negative_price_compensation)
    RETURNING id INTO v_new;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_new, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i
     WHERE i.variant_id = v.id AND i.price_model <> 'cennik'
       AND (i.oom_id IS NULL OR EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = n.deal_id AND x.oom_id = i.oom_id))
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
    -- schválená výnimka v 3-dňovej lehote prejde s rozsahom zo žiadosti (0038): platí, kým sa OOM, roky a objemy
    -- nezmenia; cena pod schválenou hranicou → výpočet „pod hranicou“ → nové schválenie
    INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                     approved_value, volume_mwh, threshold_source, scope)
    SELECT a.approval_id, v_new, a.year, a.price_model, a.voltage_group, a.requested_value, a.threshold_value,
           a.approved_value, a.volume_mwh, a.threshold_source, a.scope
      FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
     WHERE a.variant_id = v.id AND r.kind = 'vynimka_ceny' AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
       AND r.valid_until > now();
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_exc := v_exc + v_cnt;
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia', CASE WHEN v_exc > 0 THEN jsonb_build_object('exceptions_carried', v_exc) END);
  RETURN n.id;
END;
$$;


--
-- Name: offer_prepare(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_prepare(p_offer uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  c jsonb;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena') THEN
    RAISE EXCEPTION 'Pripraviť sa dá iba koncept.' USING ERRCODE = 'check_violation';
  END IF;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 THEN
    RAISE EXCEPTION '%', (SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(c->'errors') e)
      USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(c->'needs') > 0 OR (c->>'risk_needs_approval')::boolean THEN
    RAISE EXCEPTION 'Ponuka potrebuje schválenie (cena pod hranicou alebo rizikový zákazník) – požiadajte o schválenie.'
      USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET status = 'pripravena' WHERE id = o.id;
  RETURN 'pripravena';
END;
$$;


--
-- Name: offer_public_accept(text, uuid, text, text, inet, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_public_accept(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text, p_terms_sha256 text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o    offer;
  a    offer_acceptance;
  v_id uuid;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  IF FOUND THEN
    IF a.variant_id = p_variant AND a.method = 'klik' THEN
      RETURN offer_acceptance_result(a.id, true);
    END IF;
    RAISE EXCEPTION 'Ponuka už bola akceptovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF offer_public_mode(o) <> 'aktivna' THEN
    RAISE EXCEPTION 'Platnosť ponuky uplynula alebo ponuka už neplatí.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_ip IS NULL THEN
    RAISE EXCEPTION 'Chýba IP adresa.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_terms_sha256 IS DISTINCT FROM offer_terms_sha(offer_terms_text(o.id, p_variant)) THEN
    RAISE EXCEPTION 'Znenie ponuky sa medzitým zmenilo – obnovte stránku.' USING ERRCODE = 'check_violation';
  END IF;
  v_id := offer_accept_record(o.id, p_variant, 'klik', NULL, now(), p_name, p_function, p_ip, p_ua, NULL, NULL, NULL);
  RETURN offer_acceptance_result(v_id, false);
END;
$_$;


--
-- Name: offer_public_mode(public.offer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_public_mode(o public.offer) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN o.id IS NULL OR o.link_hash IS NULL OR o.valid_until IS NULL THEN 'neplatny'
              WHEN o.status IN ('odoslana', 'otvorena') AND now() < o.valid_until THEN 'aktivna'
              WHEN o.status IN ('odoslana', 'otvorena', 'akceptovana', 'zamietnuta', 'nahradena')
                   AND now() <= greatest(o.valid_until,
                                         (SELECT max(a.accepted_at) FROM offer_acceptance a WHERE a.offer_id = o.id AND a.revoked_at IS NULL))
                                + interval '30 days' THEN 'len_citanie'
              ELSE 'neplatny' END
$$;


--
-- Name: offer_public_pdf(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_public_pdf(p_hash text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o offer;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash;
  IF offer_public_mode(o) = 'neplatny' OR o.pdf_key IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('pdf_key', o.pdf_key, 'file_name', 'Cenova-ponuka-' || replace(offer_display_number(o), '/', '-') || '.pdf');
END;
$_$;


--
-- Name: offer_public_view(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_public_view(p_hash text) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o    offer;
  mode text;
  doc  jsonb;
  d    deal;
  u    app_user;
  first boolean := false;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('mode', 'neplatny');
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  mode := offer_public_mode(o);
  IF mode = 'neplatny' THEN
    RETURN jsonb_build_object('mode', 'neplatny');
  END IF;
  -- otvorenie: bez IP; prvé otvorenie odoslanej ponuky → Otvorená a udalosť v časovej osi
  INSERT INTO offer_page_stat (offer_id, first_opened_at, last_opened_at, open_count) VALUES (o.id, now(), now(), 1)
  ON CONFLICT (offer_id) DO UPDATE SET last_opened_at = now(), open_count = offer_page_stat.open_count + 1
  RETURNING (xmax = 0) INTO first;
  IF o.status = 'odoslana' THEN
    UPDATE offer SET status = 'otvorena' WHERE id = o.id;
  END IF;
  IF first THEN
    PERFORM deal_event_offer(o, 'ponuka_otvorena');
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  doc := offer_document_internal(o.id);
  RETURN jsonb_build_object(
    'mode', mode,
    'reason', CASE WHEN mode = 'aktivna' THEN NULL
                   WHEN o.status = 'akceptovana' THEN 'akceptovana'
                   WHEN o.status = 'nahradena' THEN 'nahradena'
                   WHEN o.status = 'zamietnuta' THEN 'zamietnuta'
                   ELSE 'vyprsana' END,
    'document', CASE WHEN mode = 'aktivna' THEN doc
                     ELSE doc || jsonb_build_object('variants', (SELECT jsonb_agg(x - 'terms' - 'terms_sha256') FROM jsonb_array_elements(doc->'variants') x)) END,
    'seller', jsonb_build_object('name', u.name, 'job_title', u.job_title, 'email', u.email, 'phone', u.phone),
    'pdf', o.pdf_key IS NOT NULL);
END;
$_$;


--
-- Name: offer_reject(uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_reject(p_offer uuid, p_note text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') THEN
    RAISE EXCEPTION 'Zamietnuť sa dá iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET status = 'zamietnuta', rejected_at = now(), rejected_note = nullif(btrim(p_note), '') WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_zamietnuta', jsonb_build_object('note', nullif(btrim(p_note), '')));
END;
$$;


--
-- Name: offer_reprice(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_reprice(p_offer uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  -- vlastné schválené výnimky verzie sa zrušia; prevzaté zo starej verzie sa iba odpoja (stará verzia si ich ponechá)
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny' AND offer_id = o.id;
  DELETE FROM approval_price_item a
   USING offer_variant x, approval_request r
   WHERE x.id = a.variant_id AND x.offer_id = o.id AND r.id = a.approval_id AND r.offer_id IS DISTINCT FROM o.id;
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    ELSIF (SELECT price_kind FROM offer_variant WHERE id = v) = 'viwa' THEN
      PERFORM offer_fill_viwa(v);   -- 0039
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;


--
-- Name: offer_send_check(public.offer, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_send_check(o public.offer, p_sent_at timestamp with time zone) RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c     jsonb;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka (nie koncept ani ponuka čakajúca na schválenie).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_sent_at IS NULL OR p_sent_at > now() + interval '5 minutes' OR p_sent_at < o.created_at - interval '1 minute' THEN
    RAISE EXCEPTION 'Čas odoslania musí byť medzi vytvorením verzie a teraz.' USING ERRCODE = 'check_violation';
  END IF;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 OR jsonb_array_length(c->'needs') > 0 OR (c->>'risk_needs_approval')::boolean THEN
    RAISE EXCEPTION 'Ponuka potrebuje opravu alebo schválenie – pripravte ju znova.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'))
     AND o.priced_on < (p_sent_at AT TIME ZONE 'Europe/Bratislava')::date THEN
    RAISE EXCEPTION 'Ceny pre obchodníka sú z %. FIX ponuku prepočítajte na dnešné ceny.', to_char(o.priced_on, 'DD. MM. YYYY')
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;


--
-- Name: offer_shorten(uuid, timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_shorten(p_offer uuid, p_until timestamp with time zone) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') OR o.valid_until IS NULL THEN
    RAISE EXCEPTION 'Skrátiť sa dá platnosť odoslanej ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_until IS NULL OR p_until >= o.valid_until OR p_until <= now() THEN
    RAISE EXCEPTION 'Nová platnosť musí byť skôr ako doterajšia a v budúcnosti. Predĺženie schvaľuje schvaľovateľ cien.'
      USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET valid_until = p_until, valid_shortened = true WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_platnost', jsonb_build_object('valid_until', p_until, 'shortened', true));
END;
$$;


--
-- Name: offer_state(public.offer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_state(o public.offer) RETURNS text
    LANGUAGE sql STABLE
    AS $$
  SELECT CASE WHEN o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL AND now() > o.valid_until
              THEN 'vyprsana' ELSE o.status::text END
$$;


--
-- Name: offer_sync_approvals(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_sync_approvals(p_offer uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer;
  c jsonb;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND OR o.status <> 'caka_na_schvalenie' THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM approval_request a
              WHERE a.status = 'caka' AND (a.offer_id = o.id OR (a.kind = 'rizikovy_zakaznik' AND a.deal_id = o.deal_id))) THEN
    RETURN;   -- ešte niečo čaká
  END IF;
  c := offer_check(o.id);
  UPDATE offer SET status = CASE WHEN jsonb_array_length(c->'errors') = 0 AND jsonb_array_length(c->'needs') = 0
                                      AND NOT (c->>'risk_needs_approval')::boolean
                                 THEN 'pripravena' ELSE 'koncept' END::offer_status
   WHERE id = o.id;
END;
$$;


--
-- Name: offer_template_check(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_check(p_sections jsonb) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  k   text;
  t   text;
  v   text;
  b   text;
BEGIN
  IF jsonb_typeof(p_sections) <> 'object' THEN
    RETURN 'Šablóna nemá sekcie.';
  END IF;
  FOR k IN SELECT jsonb_object_keys(p_sections) LOOP
    IF NOT k = ANY (offer_template_keys()) THEN
      RETURN format('Neznáma sekcia „%s“.', k);
    END IF;
    t := coalesce(p_sections->k->>'nadpis', '') || E'\n' || coalesce(p_sections->k->>'text', '');
    FOR v IN SELECT m[1] FROM regexp_matches(t, '«([^«»]*)»', 'g') m LOOP
      IF NOT v = ANY (offer_template_variables()) THEN
        RETURN format('Neznáma premenná «%s» v sekcii „%s“.', v, k);
      END IF;
    END LOOP;
    IF t ~ '[«»]' AND (length(t) - length(replace(t, '«', ''))) <> (length(t) - length(replace(t, '»', ''))) THEN
      RETURN format('Neuzavretá premenná v sekcii „%s“.', k);
    END IF;
    FOREACH b IN ARRAY ARRAY['spot', 'kompenzacia'] LOOP
      IF (length(t) - length(replace(t, '[[' || b || ']]', ''))) / length('[[' || b || ']]')
         <> (length(t) - length(replace(t, '[[/' || b || ']]', ''))) / length('[[/' || b || ']]') THEN
        RETURN format('Blok [[%s]] v sekcii „%s“ nie je uzavretý.', b, k);
      END IF;
    END LOOP;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['hlavicka', 'udaje', 'predmet', 'cenova_ponuka', 'platnost', 'objednavka'] LOOP
    IF coalesce(btrim(p_sections->k->>'text'), '') = '' THEN
      RETURN format('Chýba text sekcie „%s“.', k);
    END IF;
  END LOOP;
  IF position('«tabuľka variantov»' IN coalesce(p_sections->'cenova_ponuka'->>'text', '')) = 0 THEN
    RETURN 'Sekcia „cenova_ponuka“ musí obsahovať «tabuľka variantov».';
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: offer_template_fill(text, jsonb, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_fill(p_text text, p_vars jsonb, p_spot boolean, p_komp boolean) RETURNS text
    LANGUAGE plpgsql IMMUTABLE
    AS $$
DECLARE
  t text := coalesce(p_text, '');
  k text;
BEGIN
  t := regexp_replace(t, '\[\[spot\]\](.*?)\[\[/spot\]\]', CASE WHEN p_spot THEN '\1' ELSE '' END, 'g');
  t := regexp_replace(t, '\[\[kompenzacia\]\](.*?)\[\[/kompenzacia\]\]', CASE WHEN p_komp THEN '\1' ELSE '' END, 'g');
  FOR k IN SELECT jsonb_object_keys(p_vars) LOOP
    IF k <> 'tabuľka variantov' THEN
      t := replace(t, '«' || k || '»', coalesce(nullif(p_vars->>k, ''), '–'));
    END IF;
  END LOOP;
  RETURN t;
END;
$$;


--
-- Name: offer_template_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_template_version (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    kind public.offer_kind NOT NULL,
    language public.offer_language NOT NULL,
    version smallint NOT NULL,
    status text DEFAULT 'navrh'::text NOT NULL,
    sections jsonb NOT NULL,
    defaults jsonb DEFAULT '{}'::jsonb NOT NULL,
    note text,
    created_by uuid,
    published_at timestamp with time zone,
    published_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offer_template_version_check CHECK (((status = 'navrh'::text) = (published_at IS NULL))),
    CONSTRAINT offer_template_version_status_check CHECK ((status = ANY (ARRAY['navrh'::text, 'platna'::text, 'nahradena'::text])))
);


--
-- Name: TABLE offer_template_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_template_version IS 'pevné texty ponuky (PDF a stránka) – platná verzia sa nemení, zmena = nová verzia (0039)';


--
-- Name: offer_template_for(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_for(p_offer uuid) RETURNS public.offer_template_version
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT t.* FROM offer o
    JOIN offer_template_version t ON t.org_id = o.org_id AND t.kind = o.kind AND t.language = o.language
   WHERE o.id = p_offer
     AND (t.id = o.template_version_id OR (o.template_version_id IS NULL AND t.status IN ('platna', 'navrh')))
   ORDER BY (t.id = o.template_version_id) DESC, (t.status = 'platna') DESC
   LIMIT 1
$$;


--
-- Name: offer_template_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_err text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'navrh' AND NOT (crm_owner_session() OR crm_internal_call()) THEN
      RAISE EXCEPTION 'Zmazať sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NOT (crm_owner_session() OR crm_internal_call()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.status := 'navrh';
      NEW.published_at := NULL;
      NEW.published_by := NULL;
      NEW.created_by := crm_active_user_id();
    ELSE
      IF OLD.status <> 'navrh' THEN
        RAISE EXCEPTION 'Platná šablóna sa nemení – uložte novú verziu.' USING ERRCODE = 'check_violation';
      END IF;
      IF (NEW.status, NEW.kind, NEW.language, NEW.version, NEW.org_id, NEW.published_at)
         IS DISTINCT FROM (OLD.status, OLD.kind, OLD.language, OLD.version, OLD.org_id, OLD.published_at) THEN
        RAISE EXCEPTION 'Druh, jazyk, verziu a stav šablóny mení iba CRM (zverejnenie).' USING ERRCODE = 'insufficient_privilege';
      END IF;
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.version := coalesce((SELECT max(version) FROM offer_template_version
                              WHERE org_id = NEW.org_id AND kind = NEW.kind AND language = NEW.language), 0) + 1;
  END IF;
  v_err := offer_template_check(NEW.sections);
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.defaults ? 'zmluvna_pokuta' AND NOT (jsonb_typeof(NEW.defaults->'zmluvna_pokuta') = 'number'
                                               AND (NEW.defaults->>'zmluvna_pokuta')::numeric BETWEEN 0 AND 10000) THEN
    RAISE EXCEPTION 'Zmluvná pokuta musí byť číslo 0 až 10 000 €/MWh.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: offer_template_keys(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_keys() RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT ARRAY['hlavicka', 'udaje', 'predmet', 'cenova_ponuka', 'podmienky', 'platnost', 'vseobecne', 'objednavka',
               'spracoval', 'pribeh', 'vizia', 'paticka']
$$;


--
-- Name: offer_template_publish(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_publish(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t offer_template_version;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Šablóny ponúk zverejňuje admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM offer_template_version WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR t.status <> 'navrh' THEN
    RAISE EXCEPTION 'Zverejniť sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_template_version SET status = 'nahradena'
   WHERE org_id = t.org_id AND kind = t.kind AND language = t.language AND status = 'platna';
  UPDATE offer_template_version SET status = 'platna', published_at = now(), published_by = crm_active_user_id()
   WHERE id = t.id;
END;
$$;


--
-- Name: offer_template_variables(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_template_variables() RETURNS text[]
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT ARRAY['číslo ponuky', 'dátum ponuky', 'názov', 'sídlo', 'IČO', 'IČ DPH', 'kontakt meno', 'kontakt e-mail',
               'kontakt telefón', 'obchodník meno', 'obchodník funkcia', 'obchodník telefón', 'obchodník e-mail',
               'tabuľka variantov', 'flexibilita', 'objem', 'výška preddavkov', 'splatnosť preddavku', 'splatnosť faktúr',
               'platnosť čas', 'platnosť dátum', 'variant', 'dátum platnosti', 'zmluvná pokuta', 'obdobie', 'koeficient',
               'poplatok za kW']
$$;


--
-- Name: offer_terms_normalize(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_terms_normalize(p text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT string_agg(l, E'\n' ORDER BY n)
    FROM (SELECT n, btrim(regexp_replace(l, '[ \t ]+', ' ', 'g')) AS l
            FROM regexp_split_to_table(normalize(replace(coalesce(p, ''), E'\r\n', E'\n'), NFC), E'\n') WITH ORDINALITY AS s(l, n)) x
   WHERE l <> ''
$$;


--
-- Name: offer_terms_sha(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_terms_sha(p_text text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT encode(sha256(convert_to(p_text, 'UTF8')), 'hex')
$$;


--
-- Name: offer_terms_text(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_terms_text(p_offer uuid, p_variant uuid) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  t    offer_template_version := offer_template_for(p_offer);
  vs   jsonb := offer_doc_variants(p_offer);
  vars jsonb := offer_doc_vars(p_offer, vs);
  v    jsonb;
BEGIN
  SELECT x INTO v FROM jsonb_array_elements(vs) x WHERE x->>'id' = p_variant::text;
  IF v IS NULL OR t.id IS NULL THEN
    RETURN NULL;
  END IF;
  vars := vars || jsonb_build_object('variant', v->>'label');
  RETURN offer_terms_normalize(
    offer_template_fill(coalesce(t.sections->'objednavka'->>'nadpis', '') || E'\n' || coalesce(t.sections->'objednavka'->>'text', ''),
                        vars, (v->>'spot')::boolean, (v->>'negative_price_compensation')::boolean));
END;
$$;


--
-- Name: offer_unblock(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_unblock(p_offer uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  d deal;
BEGIN
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT (d.owner_id = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Verziu odblokuje vlastník obchodu alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF o.blocked_by_offer_id IS NULL THEN
    RAISE EXCEPTION 'Verzia nie je zablokovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.status = 'akceptovana') THEN
    RAISE EXCEPTION 'Iná verzia je akceptovaná – najprv musí admin akceptáciu zrušiť.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET blocked_by_offer_id = NULL WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_odblokovana');
END;
$$;


--
-- Name: offer_variant_add(uuid, public.offer_price_kind, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_add(p_offer uuid, p_price_kind public.offer_price_kind, p_copy_from uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o      offer := offer_for_edit(p_offer);
  src    offer_variant;
  v_id   uuid;
  v_ord  smallint;
BEGIN
  SELECT coalesce(max(sort_order), 0) + 1 INTO v_ord FROM offer_variant WHERE offer_id = o.id;
  IF v_ord > 5 THEN
    RAISE EXCEPTION 'Ponuka má najviac 5 variantov.' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslaná ponuka sa nemení – vytvorte novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO src FROM offer_variant WHERE id = p_copy_from AND offer_id = o.id;
  IF NOT FOUND THEN
    SELECT * INTO src FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LIMIT 1;
  END IF;
  INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                             flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                             negative_price_compensation)
  VALUES (o.id, o.org_id, v_ord,
          offer_variant_default_name(p_price_kind, src.supply_from, CASE WHEN p_price_kind IN ('fix', 'kombinacia') THEN coalesce(src.supply_to, make_date(extract(year FROM src.supply_from)::int, 12, 31)) ELSE src.supply_to END),
          p_price_kind, src.supply_from,
          CASE WHEN p_price_kind IN ('fix', 'kombinacia') THEN coalesce(src.supply_to, make_date(extract(year FROM src.supply_from)::int, 12, 31)) ELSE src.supply_to END,
          CASE WHEN p_price_kind = 'viwa' THEN coalesce(src.viwa_package, 'plus') END,
          src.flexibility_pct, src.planned_volume_mwh, src.invoice_due_days, src.advance_kind, src.advance_pct, src.advance_due_day,
          src.negative_price_compensation)
  RETURNING id INTO v_id;
  IF p_copy_from IS NOT NULL THEN
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_id, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i WHERE i.variant_id = p_copy_from AND i.price_model <> 'cennik'
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
  END IF;
  PERFORM offer_back_to_draft(o.id);
  RETURN v_id;
END;
$$;


--
-- Name: offer_variant_after(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_after() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (NEW.supply_from, NEW.supply_to, NEW.viwa_package) IS DISTINCT FROM (OLD.supply_from, OLD.supply_to, OLD.viwa_package) THEN
    PERFORM offer_basis_fill(NEW.id);
    -- položky rokov mimo nového obdobia sa odstránia
    DELETE FROM offer_item i WHERE i.variant_id = NEW.id AND i.year IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM offer_variant_months(NEW) m WHERE m.year = i.year);
    IF NEW.price_kind = 'cennik' THEN
      PERFORM offer_fill_price_list(NEW.id);
    ELSIF NEW.price_kind = 'viwa' THEN
      PERFORM offer_fill_viwa(NEW.id);   -- 0039
    END IF;
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: offer_variant_default_name(public.offer_price_kind, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_default_name(p_kind public.offer_price_kind, p_from date, p_to date) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p_kind WHEN 'fix' THEN 'FIX' WHEN 'spot' THEN 'SPOT + aditív' WHEN 'kombinacia' THEN 'FIX + SPOT'
                     WHEN 'cennik' THEN 'Cenník' WHEN 'viwa' THEN 'VIWA' END
         || CASE WHEN p_to IS NULL THEN ''
                 WHEN extract(year FROM p_from) = extract(year FROM p_to) THEN ' ' || extract(year FROM p_from)
                 ELSE ' ' || extract(year FROM p_from) || '–' || extract(year FROM p_to) END
$$;


--
-- Name: offer_variant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_variant (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id uuid NOT NULL,
    org_id uuid NOT NULL,
    sort_order smallint NOT NULL,
    name text NOT NULL,
    price_kind public.offer_price_kind NOT NULL,
    supply_from date NOT NULL,
    supply_to date,
    viwa_package text,
    flexibility_pct numeric(5,2),
    planned_volume_mwh numeric(12,3),
    invoice_due_days smallint DEFAULT 14 NOT NULL,
    advance_kind text DEFAULT 'mesacne'::text NOT NULL,
    advance_pct numeric(5,2) DEFAULT 100,
    advance_due_day smallint DEFAULT 5,
    negative_price_compensation boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offer_variant_advance_due_day_check CHECK (((advance_due_day >= 1) AND (advance_due_day <= 31))),
    CONSTRAINT offer_variant_advance_kind_check CHECK ((advance_kind = ANY (ARRAY['mesacne'::text, 'financna_zabezpeka'::text]))),
    CONSTRAINT offer_variant_advance_pct_check CHECK (((advance_pct >= (0)::numeric) AND (advance_pct <= (100)::numeric))),
    CONSTRAINT offer_variant_check CHECK (((supply_to IS NULL) OR (supply_to >= supply_from))),
    CONSTRAINT offer_variant_check1 CHECK (((supply_to IS NOT NULL) OR (price_kind = ANY (ARRAY['spot'::public.offer_price_kind, 'viwa'::public.offer_price_kind, 'cennik'::public.offer_price_kind])))),
    CONSTRAINT offer_variant_check2 CHECK (((price_kind = 'viwa'::public.offer_price_kind) = (viwa_package IS NOT NULL))),
    CONSTRAINT offer_variant_flexibility_pct_check CHECK (((flexibility_pct > (0)::numeric) AND (flexibility_pct <= (100)::numeric))),
    CONSTRAINT offer_variant_invoice_due_days_check CHECK (((invoice_due_days >= 1) AND (invoice_due_days <= 120))),
    CONSTRAINT offer_variant_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT offer_variant_planned_volume_mwh_check CHECK ((planned_volume_mwh >= (0)::numeric)),
    CONSTRAINT offer_variant_sort_order_check CHECK (((sort_order >= 1) AND (sort_order <= 5))),
    CONSTRAINT offer_variant_viwa_package_check CHECK ((viwa_package = ANY (ARRAY['basic'::text, 'plus'::text, 'pro'::text])))
);


--
-- Name: TABLE offer_variant; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_variant IS 'variant ponuky (A–E); zákazník prijme jeden';


--
-- Name: offer_variant_months(public.offer_variant); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_months(v public.offer_variant) RETURNS TABLE(m_start date, year smallint)
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT g::date, extract(year FROM g)::smallint
    FROM generate_series(date_trunc('month', v.supply_from),
                         date_trunc('month', coalesce(v.supply_to, (v.supply_from + interval '11 months')::date)),
                         interval '1 month') g
$$;


--
-- Name: offer_variant_scope(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_scope(p_variant uuid) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT jsonb_build_object(
           'supply_from', v.supply_from, 'supply_to', v.supply_to, 'planned_volume_mwh', v.planned_volume_mwh,
           'oom', (SELECT coalesce(jsonb_agg(jsonb_build_array(x.oom_id, oom_voltage_group(m.voltage_level),
                                                               x.planned_vt_mwh, x.planned_nt_mwh, x.planned_feed_in_mwh,
                                                               coalesce(x.source_power_kw, m.source_power_kw))
                                             ORDER BY x.oom_id), '[]')
                     FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                    WHERE x.deal_id = o.deal_id))
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id
   WHERE v.id = p_variant
$$;


--
-- Name: offer_variant_summary(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_summary(p_variant uuid) RETURNS TABLE(year smallint, volume_mwh numeric, added_value_eur numeric, margin_eur numeric, commission_eur numeric, commission_pct numeric, below boolean, missing integer)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  WITH x AS (SELECT * FROM offer_variant_values(p_variant)),
       pct AS (SELECT user_commission_pct(d.owner_id) AS p
                 FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
                WHERE v.id = p_variant)
  SELECT x.year, sum(x.volume_mwh), sum(x.added_value_eur), sum(x.margin_eur),
         round(greatest(sum(x.added_value_eur), 0) * (SELECT p FROM pct) / 100, 2), (SELECT p FROM pct),
         bool_or(x.below), count(*) FILTER (WHERE x.missing IS NOT NULL)::int
    FROM x GROUP BY ROLLUP (x.year)
   ORDER BY x.year NULLS LAST
$$;


--
-- Name: offer_variant_values(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variant_values(p_variant uuid) RETURNS TABLE(oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model public.price_model, kind text, price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric, months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text, exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
sc AS (SELECT offer_variant_scope(p_variant) AS scope WHERE EXISTS (SELECT 1 FROM v)),
mo AS (SELECT m.m_start, m.year FROM offer_variant ov, offer_variant_months(ov) m
        WHERE ov.id = p_variant AND EXISTS (SELECT 1 FROM v)),
dm AS (
  SELECT x.oom_id, oom_voltage_group(o.voltage_level) AS vg, o.price_regulation AS reg,
         coalesce(x.planned_vt_mwh, 0) AS vt_y, coalesce(x.planned_nt_mwh, 0) AS nt_y,
         coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0) AS feed_y,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS kw
    FROM v JOIN deal_oom x ON x.deal_id = v.deal_id JOIN oom o ON o.id = x.oom_id
),
oy AS (   -- OOM × rok: mesiace a objemy
  SELECT dm.oom_id, dm.vg, dm.reg, dm.kw, mo.year, count(*)::int AS months,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN dm.feed_y ELSE dm.vt_y END * count(*) / 12 AS v_vt,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN 0 ELSE dm.nt_y END * count(*) / 12 AS v_nt
    FROM dm CROSS JOIN mo
   GROUP BY dm.oom_id, dm.vg, dm.reg, dm.kw, dm.feed_y, dm.vt_y, dm.nt_y, mo.year
),
it AS (
  SELECT oy.*, i.id AS item_id, i.price_model, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
         i.additive_eur_mwh AS ad, i.additive_pct AS pct,
         CASE WHEN (SELECT okind FROM v) = 'viwa' THEN 'viwa'
              WHEN (SELECT okind FROM v) = 'vykup' THEN CASE WHEN i.price_model IS NOT NULL THEN 'vykup' END
              WHEN i.price_model = 'cennik' AND (SELECT household FROM v) AND oy.reg THEN 'energo'
              WHEN i.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN i.price_model::text END AS kind
    FROM oy
    LEFT JOIN LATERAL (SELECT * FROM offer_item i
                        WHERE i.variant_id = p_variant AND i.oom_id = oy.oom_id AND i.slot = 'komodita'
                          AND (i.year = oy.year OR i.year IS NULL)
                        ORDER BY i.year NULLS LAST LIMIT 1) i ON true
),
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037), pri nezmenenom rozsahu variantu (0038)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
     -- neodoslaná verzia: rozsah variantu (OOM, roky, objemy) ako pri žiadosti; odoslaná si výnimku ponechá
     AND ((SELECT osent FROM v) IS NOT NULL OR a.scope = (SELECT scope FROM sc))
     -- výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá
     AND CASE WHEN (SELECT osent FROM v) IS NULL THEN r.valid_until IS NULL OR r.valid_until > now()
              ELSE r.valid_until IS NULL OR (SELECT osent FROM v) <= r.valid_until END
   GROUP BY 1, 2, 3
),
calc AS (
  SELECT it.*, b.seller_type, b.trader_price, b.portfolio_eur_mwh AS portfolio_b, b.min_additive, b.energopomoc_price,
         b.viwa_additive,
         (SELECT e.value FROM ex e WHERE e.year = it.year AND e.price_model = it.price_model
                                    AND e.voltage_group IN (it.vg, 'vsetko') ORDER BY e.value LIMIT 1) AS exc,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'portfolio')) AS portfolio_today,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'spot_fve')) AS spot_fve,
         (SELECT coalesce(sum((coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * it.kw) * it.months), 0)
            FROM offer_item f
           WHERE f.variant_id = p_variant AND f.oom_id = it.oom_id AND f.slot <> 'komodita'
             AND (f.year = it.year OR f.year IS NULL)) AS fees
    FROM it
    LEFT JOIN offer_year_basis b ON b.variant_id = p_variant AND b.year = it.year
),
val AS (
  SELECT calc.*,
         pv_revenue(kind, price_model, vt, nt, ad, pct, v_vt, v_nt, spot_fve, viwa_additive) AS rev,
         pv_unit_cost(kind, price_model, vt, seller_type, trader_price, portfolio_b, energopomoc_price, min_additive, exc) AS ucost,
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost,
         CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
              WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
              WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
              WHEN kind = 'cennik' THEN 'odhad_portfolia'
              WHEN kind = 'energo' THEN 'energopomoc'
              WHEN kind = 'viwa' THEN 'viwa' END AS src
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       CASE WHEN src = 'odhad_portfolia' AND NOT (SELECT see_portfolio FROM v) THEN NULL ELSE ucost END,
       src,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            -- 0041: pri manažérovi je hranicou odhad portfólia (hlásenie hovorí, čo chýba a čo urobiť)
            WHEN kind = 'fix' AND ucost IS NULL THEN
              CASE WHEN seller_type = 'manazer'
                   THEN 'chýba odhad portfólia (hranica manažéra) – doplňte ho v cenách dňa a ponuku prepočítajte'
                   ELSE 'chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte' END
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;


--
-- Name: offer_variants_summary_text(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.offer_variants_summary_text(p_offer uuid) RETURNS text
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  parts text[] := '{}';
  yrs   integer[];
  ys    text;
  sp    record;
  n     integer;
  t     text;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    SELECT array_agg(DISTINCT i.year ORDER BY i.year) INTO yrs
      FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.year IS NOT NULL;
    IF yrs IS NULL THEN
      yrs := ARRAY[extract(year FROM v.supply_from)::int]
             || CASE WHEN v.supply_to IS NOT NULL AND extract(year FROM v.supply_to) > extract(year FROM v.supply_from)
                     THEN ARRAY[extract(year FROM v.supply_to)::int] ELSE '{}'::int[] END;
    END IF;
    ys := CASE WHEN cardinality(yrs) = 1 THEN CASE lang WHEN 'en' THEN ' for ' ELSE ' na rok ' END || yrs[1]
               ELSE CASE lang WHEN 'en' THEN ' for ' ELSE ' na roky ' END || yrs[1] || '–' || yrs[cardinality(yrs)] END;
    t := CASE v.price_kind
           WHEN 'fix' THEN 'FIX' || ys
           WHEN 'kombinacia' THEN CASE lang WHEN 'en' THEN 'FIX and SPOT combination' ELSE 'kombinácia FIX a SPOT' END || ys
           WHEN 'cennik' THEN CASE lang WHEN 'en' THEN 'price list' ELSE 'cenník' END
           WHEN 'viwa' THEN 'Green VIWA' || coalesce(' ' || initcap(v.viwa_package), '')
           ELSE 'SPOT' END;
    IF v.price_kind = 'spot' THEN
      SELECT count(DISTINCT (i.price_model, i.additive_eur_mwh, i.additive_pct)) INTO n
        FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita';
      IF n = 1 THEN
        SELECT i.price_model, i.additive_eur_mwh AS ad, i.additive_pct AS pct INTO sp
          FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita' LIMIT 1;
        t := t || CASE sp.price_model
                    WHEN 'spot_plus_eur' THEN ' + ' || offer_fmt_num(sp.ad, 2, lang) || ' €/MWh'
                    WHEN 'spot_minus_eur' THEN ' − ' || offer_fmt_num(sp.ad, 2, lang) || ' €/MWh'
                    WHEN 'spot_minus_pct' THEN ' − ' || offer_fmt_num(sp.pct, 2, lang) || ' %'
                    ELSE '' END;
      END IF;
    END IF;
    parts := parts || t;
  END LOOP;
  n := cardinality(parts);
  RETURN CASE WHEN n = 0 THEN ''
              WHEN n = 1 THEN parts[1]
              ELSE array_to_string(parts[1:n - 1], ', ') || CASE lang WHEN 'en' THEN ' and ' ELSE ' a ' END || parts[n] END;
END;
$$;


--
-- Name: oom_activate_due(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_due() RETURNS integer
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT oom_activate_due_at(crm_today())
$$;


--
-- Name: oom_activate_due_at(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_due_at(p_today date) RETURNS integer
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_id   uuid;
  v_n    integer := 0;
  v_prev text := crm_as_system(true);
BEGIN
  FOR v_id IN SELECT o.id FROM oom o WHERE oom_activation_ready(o, p_today) ORDER BY o.id LOOP
    PERFORM oom_set_status(v_id, 'aktivne');
    v_n := v_n + 1;
  END LOOP;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_n;
END;
$$;


--
-- Name: oom_activate_on_save(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activate_on_save() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_prev text;
BEGIN
  IF oom_activation_ready(NEW, crm_today()) THEN
    v_prev := crm_as_system(true);
    PERFORM oom_set_status(NEW.id, 'aktivne');
    PERFORM set_config('app.change_source', v_prev, true);
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    person_id uuid,
    eic text NOT NULL,
    type public.oom_type NOT NULL,
    status public.oom_status NOT NULL,
    name text,
    address_street text,
    address_number_supisne text,
    address_number_orientacne text,
    address_city text,
    address_zip text,
    pds text,
    pds_point_id text,
    pds_tariff text,
    voltage_level public.voltage_level,
    metering_type text,
    phases smallint,
    breaker_a numeric(8,2),
    reserved_capacity_kw numeric(12,3),
    max_reserved_capacity_kw numeric(12,3),
    capacity_reservation_method text,
    price_regulation boolean,
    excise_tax text,
    billing_period text,
    advance_payment_method text,
    advance_payment_pct numeric(5,2),
    planned_consumption_vt_mwh numeric(12,3),
    planned_consumption_nt_mwh numeric(12,3),
    planned_feed_in_mwh numeric(12,3),
    source_power_kw numeric(12,3),
    source_kind public.source_kind,
    feed_in_contract_type text,
    inverter_power_kw numeric(12,3),
    panels_power_kw numeric(12,3),
    supply_from date,
    supply_to date,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    source_category public.oom_source_category,
    advance_payment_eur numeric(12,2),
    previous_supplier text,
    switch_notice_required boolean DEFAULT true NOT NULL,
    switch_notice_sent_on date,
    switch_notice_accepted_on date,
    switch_confirmed_on date,
    planned_feed_in_manual boolean DEFAULT false NOT NULL,
    public_lighting boolean DEFAULT false NOT NULL,
    tdo_class text,
    created_from_deal_id uuid,
    CONSTRAINT oom_advance_payment_eur_check CHECK ((advance_payment_eur >= (0)::numeric)),
    CONSTRAINT oom_advance_pct_check CHECK (((advance_payment_pct >= (0)::numeric) AND (advance_payment_pct <= (100)::numeric))),
    CONSTRAINT oom_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT oom_eic_check CHECK (public.eic_is_valid(eic)),
    CONSTRAINT oom_phases_check CHECK ((phases = ANY (ARRAY[1, 3]))),
    CONSTRAINT oom_supply_period_check CHECK (((supply_to IS NULL) OR (supply_from IS NULL) OR (supply_to >= supply_from))),
    CONSTRAINT oom_switch_steps_check CHECK (((switch_notice_required OR ((switch_notice_sent_on IS NULL) AND (switch_notice_accepted_on IS NULL))) AND ((switch_notice_accepted_on IS NULL) OR ((switch_notice_sent_on IS NOT NULL) AND (switch_notice_accepted_on >= switch_notice_sent_on))) AND ((switch_confirmed_on IS NULL) OR (NOT switch_notice_required) OR ((switch_notice_accepted_on IS NOT NULL) AND (switch_confirmed_on >= switch_notice_accepted_on))))),
    CONSTRAINT oom_tdo_class_check CHECK ((btrim(tdo_class) <> ''::text))
);


--
-- Name: COLUMN oom.company_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.company_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.person_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.status IS 'stav poslednej väzby (oom_customer); mení sa iba cez väzbu';


--
-- Name: COLUMN oom.pds; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.pds IS 'kód z číselníka pds';


--
-- Name: COLUMN oom.pds_tariff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.pds_tariff IS 'kód z číselníka sadzba_distribucie (sadzba zvoleného PDS)';


--
-- Name: COLUMN oom.metering_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.metering_type IS 'kód z číselníka typ_merania';


--
-- Name: COLUMN oom.price_regulation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.price_regulation IS 'cenová regulácia: true = ANO, false = NIE, NULL = nevyplnené; domácnosť = nárok na energopomoc, firma = cenník pre malé podniky';


--
-- Name: COLUMN oom.billing_period; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.billing_period IS 'kód z číselníka fakturacne_obdobie';


--
-- Name: COLUMN oom.advance_payment_method; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.advance_payment_method IS 'kód z číselníka sposob_zaloh';


--
-- Name: COLUMN oom.feed_in_contract_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.feed_in_contract_type IS 'kód z číselníka typ_vykupnej_zmluvy';


--
-- Name: COLUMN oom.supply_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.supply_to IS 'NULL = na neurčito';


--
-- Name: COLUMN oom.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN oom.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.org_id IS 'preberá sa od zákazníka';


--
-- Name: COLUMN oom.source_category; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.source_category IS 'kategória zdroja podľa zákona (zadanie OOM čl. 7)';


--
-- Name: COLUMN oom.previous_supplier; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.previous_supplier IS 'kód z číselníka predchadzajuci_dodavatel';


--
-- Name: COLUMN oom.switch_notice_required; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_required IS 'false = výpoveď predošlému dodávateľovi sa nezasiela (napr. nová prípojka)';


--
-- Name: COLUMN oom.switch_notice_sent_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_sent_on IS 'prechod, krok 1: výpoveď predošlému dodávateľovi odoslaná';


--
-- Name: COLUMN oom.switch_notice_accepted_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_notice_accepted_on IS 'prechod, krok 2: výpoveď akceptovaná';


--
-- Name: COLUMN oom.switch_confirmed_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.switch_confirmed_on IS 'prechod, krok 3: zmena dodávateľa potvrdená; krok 4 = supply_from';


--
-- Name: COLUMN oom.planned_feed_in_manual; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.planned_feed_in_manual IS 'plán výkupu lokálneho zdroja zadaný ručne (vzorec výkon × 4 × 365 × 0,1 / 1000 sa nepoužije)';


--
-- Name: COLUMN oom.public_lighting; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.public_lighting IS 'verejné osvetlenie (prolongácia navrhne Green 1T VO); nastaví import zmlúv pri DMP10 / 1T VO';


--
-- Name: COLUMN oom.tdo_class; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.tdo_class IS 'trieda TDO z XM Trade (napr. „TDO 4“); aj pre Cockpit';


--
-- Name: COLUMN oom.created_from_deal_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.created_from_deal_id IS 'OOM vzniklo pri obchode (pri prehre sa zruší, ak nie je inde)';


--
-- Name: oom_activation_ready(public.oom, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_activation_ready(o public.oom, p_today date) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$
  SELECT o.status = 'pripravovane'
     AND o.switch_confirmed_on IS NOT NULL
     AND o.supply_from <= p_today
     AND cardinality(oom_active_required_missing(o)) = 0
$$;


--
-- Name: oom_active_edit_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_active_edit_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: oom_active_required_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_active_required_check() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_missing text[];
BEGIN
  IF NEW.status = 'aktivne' AND (TG_OP = 'INSERT' OR OLD.status <> 'aktivne') AND current_user <> 'crm_sync' THEN
    v_missing := oom_active_required_missing(NEW);
    IF cardinality(v_missing) > 0 THEN
      RAISE EXCEPTION 'Odberné miesto nemôže byť Aktívne, chýba: %.', array_to_string(v_missing, ', ')
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_active_required_missing(public.oom); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_active_required_missing(o public.oom) RETURNS text[]
    LANGUAGE sql STABLE
    AS $$
  SELECT array_remove(ARRAY[
    CASE WHEN nullif(btrim(o.address_street), '') IS NULL AND nullif(btrim(o.address_city), '') IS NULL
         THEN 'ulica alebo obec' END,
    CASE WHEN nullif(btrim(o.address_zip), '') IS NULL THEN 'PSČ' END,
    CASE WHEN o.pds IS NULL THEN 'PDS' END,
    CASE WHEN o.voltage_level IS NULL THEN 'napäťová úroveň' END,
    CASE WHEN o.pds_tariff IS NULL THEN 'sadzba distribúcie' END,
    CASE WHEN o.supply_from IS NULL THEN 'dodávka od' END,
    CASE WHEN o.type IN ('spotreba', 'sharing')
          AND o.planned_consumption_vt_mwh IS NULL AND o.planned_consumption_nt_mwh IS NULL
         THEN 'plánovaná spotreba' END,
    CASE WHEN o.type = 'vyroba' AND o.planned_feed_in_mwh IS NULL THEN 'plánovaný výkup' END
  ], NULL)
$$;


--
-- Name: FUNCTION oom_active_required_missing(o public.oom); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.oom_active_required_missing(o public.oom) IS 'chýbajúce povinné údaje pre stav Aktívne (prázdne pole = OK)';


--
-- Name: oom_brief(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_brief(p_oom_id uuid) RETURNS TABLE(eic text, name text, address_city text, type public.oom_type)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT o.eic, o.name, o.address_city, o.type
    FROM oom o
   WHERE o.id = p_oom_id
     AND (crm_oom_access(o.id, 'view')
          OR EXISTS (SELECT 1 FROM oom_customer l
                      WHERE l.oom_id = o.id
                        AND (crm_company_access(l.company_id, 'view') OR crm_contact_access(l.person_id, 'view'))))
$$;


--
-- Name: oom_child_active_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_child_active_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF (SELECT status FROM oom WHERE id = coalesce(NEW.oom_id, OLD.oom_id)) = 'aktivne'
     AND NOT crm_oom_system_step() AND NOT crm_can_edit_active_oom() THEN
    RAISE EXCEPTION 'Aktívne odberné miesto môže upravovať iba tím s právom „upravovať Aktívne OOM“.'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: oom_contact_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_contact_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_oom oom;
BEGIN
  SELECT * INTO v_oom FROM oom WHERE id = NEW.oom_id;
  IF v_oom.company_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM company_contact WHERE company_id = v_oom.company_id AND contact_id = NEW.contact_id) THEN
      RAISE EXCEPTION 'Kontaktná osoba musí byť osobou vo firme zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF (SELECT org_id FROM contact WHERE id = NEW.contact_id) <> v_oom.org_id THEN
    RAISE EXCEPTION 'Osoba a odberné miesto patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_pri_oom', v_oom.org_id, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;


--
-- Name: oom_created_from_deal_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_created_from_deal_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_customer_at(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_at(p_oom_id uuid, p_date date) RETURNS TABLE(company_id uuid, person_id uuid, status public.oom_status, valid_from date, valid_to date)
    LANGUAGE sql STABLE
    AS $$
  SELECT l.company_id, l.person_id, l.status, l.valid_from, l.valid_to
    FROM oom_customer l
   WHERE l.oom_id = p_oom_id
     AND daterange(l.valid_from, l.valid_to, '[]') @> p_date
$$;


--
-- Name: oom_customer_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_customer_org uuid;
BEGIN
  NEW.org_id := (SELECT org_id FROM oom WHERE id = NEW.oom_id);
  v_customer_org := coalesce((SELECT org_id FROM company WHERE id = NEW.company_id),
                             (SELECT org_id FROM contact WHERE id = NEW.person_id));
  IF v_customer_org IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION 'Odberné miesto a zákazník patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.oom_id <> OLD.oom_id OR NEW.company_id IS DISTINCT FROM OLD.company_id
       OR NEW.person_id IS DISTINCT FROM OLD.person_id THEN
      RAISE EXCEPTION 'Odberné miesto ani zákazník väzby sa nemenia (prepis = nová väzba).' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.valid_to IS NOT NULL AND current_user <> 'crm_sync' THEN
      RAISE EXCEPTION 'Uzavretá väzba sa nemení.' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.status = 'aktivne' AND NEW.status = 'pripravovane' THEN
      RAISE EXCEPTION 'Aktívne odberné miesto sa nevracia do stavu Pripravované.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_customer_mark(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_mark() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_prev text := crm_as_system(true);
BEGIN
  UPDATE company SET is_customer = true WHERE id = NEW.company_id AND NOT is_customer;
  UPDATE contact SET is_household = true WHERE id = NEW.person_id AND NOT is_household;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN NULL;
END;
$$;


--
-- Name: oom_customer_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_customer_refresh() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_daily_run(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_daily_run() RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT oom_daily_run_at(crm_today())
$$;


--
-- Name: oom_daily_run_at(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_delete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_delete(p_oom_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
  DELETE FROM oom_planned_change WHERE oom_id = p_oom_id;   -- 0017: plány (aj vykonané a zrušené) patria OOM
  DELETE FROM oom_customer WHERE oom_id = p_oom_id;
  DELETE FROM oom WHERE id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  RETURN v_eic;
END;
$$;


--
-- Name: oom_eic_check(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_eic_check(p_eic text) RETURNS TABLE(oom_exists boolean, oom_id uuid, owner_name text, org_name text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_eic_normalize(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_eic_normalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.eic := upper(regexp_replace(NEW.eic, '\s', '', 'g'));
  RETURN NEW;
END;
$$;


--
-- Name: oom_feed_in_formula(numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_feed_in_formula(p_power_kw numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT round(p_power_kw * 4 * 365 * 0.1 / 1000, 3)
$$;


--
-- Name: FUNCTION oom_feed_in_formula(p_power_kw numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.oom_feed_in_formula(p_power_kw numeric) IS 'plán výkupu lokálneho zdroja [MWh] = výkon [kW] × 4 h × 365 × 0,1 / 1000 (zadanie modulu 4, časť 9)';


--
-- Name: oom_feed_in_plan(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_feed_in_plan() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_formula numeric;
BEGIN
  IF NEW.source_category IS DISTINCT FROM 'lokalny_zdroj' THEN
    RETURN NEW;
  END IF;
  v_formula := oom_feed_in_formula(NEW.source_power_kw);
  IF TG_OP = 'INSERT' THEN
    IF NEW.planned_feed_in_mwh IS NOT NULL AND NEW.planned_feed_in_mwh IS DISTINCT FROM v_formula THEN
      NEW.planned_feed_in_manual := true;
    END IF;
  ELSIF NEW.planned_feed_in_mwh IS DISTINCT FROM OLD.planned_feed_in_mwh THEN
    IF NEW.planned_feed_in_mwh IS NULL THEN
      NEW.planned_feed_in_manual := false;
    ELSIF NEW.planned_feed_in_mwh IS DISTINCT FROM v_formula THEN
      NEW.planned_feed_in_manual := true;
    END IF;
  END IF;
  IF NOT NEW.planned_feed_in_manual THEN
    NEW.planned_feed_in_mwh := v_formula;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_first_link(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_first_link() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (NEW.id, NEW.company_id, NEW.person_id, NEW.org_id, least(NEW.supply_from, crm_today()), NEW.status);
  RETURN NULL;
END;
$$;


--
-- Name: oom_import_counts(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_import_counts(p_rows jsonb) RETURNS jsonb
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT jsonb_build_object(
           'riadkov', count(*),
           'nove', count(*) FILTER (WHERE x ->> 'action' = 'nove'),
           'zmena', count(*) FILTER (WHERE x ->> 'action' = 'zmena'),
           'bez_zmeny', count(*) FILTER (WHERE x ->> 'action' = 'bez_zmeny'),
           'chyba', count(*) FILTER (WHERE x ->> 'action' = 'chyba'))
    FROM jsonb_array_elements(p_rows) x
$$;


--
-- Name: oom_import_lookup(text, uuid, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_import_lookup(p_list text, p_org uuid, p_label text, p_parent text DEFAULT NULL::text) RETURNS text
    LANGUAGE plpgsql STABLE
    AS $$
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


--
-- Name: oom_import_rows(uuid, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_import_rows(p_org uuid, p_rows jsonb) RETURNS jsonb
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


--
-- Name: oom_import_run(uuid, jsonb, boolean, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_import_run(p_org uuid, p_rows jsonb, p_save boolean, p_file_name text DEFAULT NULL::text, p_expected jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: oom_link_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_link_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('pripravovane', 'aktivne') THEN
      RAISE EXCEPTION 'Nové odberné miesto je Pripravované alebo Aktívne.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF pg_trigger_depth() < 2
        AND (NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.person_id IS DISTINCT FROM OLD.person_id
             OR NEW.status IS DISTINCT FROM OLD.status) THEN
    RAISE EXCEPTION 'Zákazník a stav odberného miesta sa menia iba zmenou stavu alebo prepisom.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_link_sync(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_link_sync() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_oom_id uuid := coalesce(NEW.oom_id, OLD.oom_id);
  v_link   oom_customer;
BEGIN
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = v_oom_id ORDER BY valid_from DESC LIMIT 1;
  IF FOUND THEN
    UPDATE oom
       SET company_id = v_link.company_id, person_id = v_link.person_id, status = v_link.status
     WHERE id = v_oom_id
       AND (company_id, person_id, status) IS DISTINCT FROM (v_link.company_id, v_link.person_id, v_link.status);
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: oom_lookup_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_lookup_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_old oom;   -- pri INSERT prázdne: každý kód je nový (skrytý sa nedá vybrať)
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_old := OLD;
  END IF;
  IF NEW.pds IS NOT NULL THEN
    PERFORM lookup_codes_check('pds', NEW.org_id, ARRAY[NEW.pds], array_remove(ARRAY[v_old.pds], NULL));
  END IF;
  IF NEW.pds_tariff IS NOT NULL THEN
    PERFORM lookup_codes_check('sadzba_distribucie', NEW.org_id, ARRAY[NEW.pds_tariff], array_remove(ARRAY[v_old.pds_tariff], NULL));
    IF NOT EXISTS (SELECT 1 FROM lookup_value
                    WHERE list_code = 'sadzba_distribucie' AND code = NEW.pds_tariff
                      AND parent_code = NEW.pds) THEN
      RAISE EXCEPTION 'Sadzba distribúcie nepatrí zvolenému PDS.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.metering_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_merania', NEW.org_id, ARRAY[NEW.metering_type], array_remove(ARRAY[v_old.metering_type], NULL));
  END IF;
  IF NEW.billing_period IS NOT NULL THEN
    PERFORM lookup_codes_check('fakturacne_obdobie', NEW.org_id, ARRAY[NEW.billing_period], array_remove(ARRAY[v_old.billing_period], NULL));
  END IF;
  IF NEW.advance_payment_method IS NOT NULL THEN
    PERFORM lookup_codes_check('sposob_zaloh', NEW.org_id, ARRAY[NEW.advance_payment_method], array_remove(ARRAY[v_old.advance_payment_method], NULL));
  END IF;
  IF NEW.feed_in_contract_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_vykupnej_zmluvy', NEW.org_id, ARRAY[NEW.feed_in_contract_type], array_remove(ARRAY[v_old.feed_in_contract_type], NULL));
  END IF;
  IF NEW.previous_supplier IS NOT NULL THEN
    PERFORM lookup_codes_check('predchadzajuci_dodavatel', NEW.org_id, ARRAY[NEW.previous_supplier], array_remove(ARRAY[v_old.previous_supplier], NULL));
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_plan_cancel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_cancel(p_plan_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  UPDATE oom_planned_change SET status = 'zrusena', cancelled_at = now(), cancelled_by = crm_active_user_id()
   WHERE id = p_plan_id AND status IN ('planovana', 'zlyhala');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plánovaná zmena neexistuje alebo sa už nedá zrušiť.' USING ERRCODE = 'no_data_found';
  END IF;
END;
$$;


--
-- Name: oom_plan_change(uuid, public.oom_plan_kind, date, uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_change(p_oom_id uuid, p_kind public.oom_plan_kind, p_date date, p_company_id uuid DEFAULT NULL::uuid, p_person_id uuid DEFAULT NULL::uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_link oom_customer;
  v_org  uuid;
  v_id   uuid;
BEGIN
  IF p_date IS NULL THEN
    RAISE EXCEPTION 'Chýba dátum.' USING ERRCODE = 'check_violation';
  END IF;
  IF (p_kind = 'prepis') <> (num_nonnulls(p_company_id, p_person_id) = 1) OR num_nonnulls(p_company_id, p_person_id) > 1 THEN
    RAISE EXCEPTION 'Pri prepise zadajte práve jedného nového odberateľa (firmu alebo domácnosť); pri odchode a zrušení žiadneho.'
      USING ERRCODE = 'check_violation';
  END IF;
  IF NOT crm_oom_access(p_oom_id, 'edit') THEN
    RAISE EXCEPTION 'Toto odberné miesto nemôžete meniť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  PERFORM oom_plan_guard(p_oom_id);
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_kind = 'prepis' THEN
    IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
      RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
    END IF;
    IF p_date <= v_link.valid_from THEN
      RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
    END IF;
    IF NOT (crm_company_access(p_company_id, 'view') OR crm_contact_access(p_person_id, 'view')) THEN
      RAISE EXCEPTION 'Nový odberateľ neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    IF crm_scope('odberne_miesta', 'edit') = 'iba_svoje' AND NOT crm_customer_owned(p_company_id, p_person_id) THEN
      RAISE EXCEPTION 'Prepísať môžete iba na vlastného zákazníka.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    v_org := coalesce((SELECT org_id FROM company WHERE id = p_company_id), (SELECT org_id FROM contact WHERE id = p_person_id));
    IF v_org <> v_link.org_id THEN
      RAISE EXCEPTION 'Nový odberateľ patrí inej spoločnosti skupiny.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF p_date < v_link.valid_from THEN
    RAISE EXCEPTION 'Posledný deň dodávky nemôže byť pred začiatkom väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  IF oom_plan_due_on(p_kind, p_date) <= crm_today() THEN
    CASE p_kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(p_oom_id, p_company_id, p_person_id, p_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(p_oom_id, 'odidene', p_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(p_oom_id, 'zrusene', p_date);
    END CASE;
    RETURN NULL;
  END IF;

  INSERT INTO oom_planned_change (oom_id, org_id, kind, effective_date, company_id, person_id, created_by)
  VALUES (p_oom_id, v_link.org_id, p_kind, p_date, p_company_id, p_person_id, crm_active_user_id())
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: oom_plan_due_on(public.oom_plan_kind, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_due_on(p_kind public.oom_plan_kind, p_date date) RETURNS date
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p_kind = 'prepis' THEN p_date ELSE p_date + 1 END
$$;


--
-- Name: oom_plan_execute(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_execute(p_plan_id uuid) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_plan oom_planned_change;
  v_prev text := crm_as_system(true);
  v_ok   boolean := true;
BEGIN
  SELECT * INTO v_plan FROM oom_planned_change WHERE id = p_plan_id AND status = 'planovana' FOR UPDATE;
  IF NOT FOUND THEN
    PERFORM set_config('app.change_source', v_prev, true);
    RETURN false;
  END IF;
  PERFORM set_config('crm.oom_plan_run', 'on', true);
  BEGIN
    CASE v_plan.kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(v_plan.oom_id, v_plan.company_id, v_plan.person_id, v_plan.effective_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(v_plan.oom_id, 'odidene', v_plan.effective_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(v_plan.oom_id, 'zrusene', v_plan.effective_date);
    END CASE;
    UPDATE oom_planned_change SET status = 'vykonana', executed_at = now() WHERE id = p_plan_id;
  EXCEPTION WHEN OTHERS THEN
    UPDATE oom_planned_change SET status = 'zlyhala', error = SQLERRM, executed_at = now() WHERE id = p_plan_id;
    v_ok := false;
  END;
  PERFORM set_config('crm.oom_plan_run', '', true);
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN v_ok;
END;
$$;


--
-- Name: oom_plan_guard(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_guard(p_oom_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF coalesce(current_setting('crm.oom_plan_run', true), '') <> 'on'
     AND EXISTS (SELECT 1 FROM oom_planned_change WHERE oom_id = p_oom_id AND status = 'planovana') THEN
    RAISE EXCEPTION 'Odberné miesto má plánovanú zmenu. Najprv ju zrušte alebo zmeňte jej dátum.'
      USING ERRCODE = 'check_violation';
  END IF;
END;
$$;


--
-- Name: oom_plan_reschedule(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_reschedule(p_plan_id uuid, p_date date) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_plan oom_planned_change;
  v_from date;
BEGIN
  SELECT * INTO v_plan FROM oom_planned_change WHERE id = p_plan_id AND status = 'planovana' FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Plánovaná zmena neexistuje alebo už nie je aktívna.' USING ERRCODE = 'no_data_found';
  END IF;
  v_from := (SELECT valid_from FROM oom_customer WHERE oom_id = v_plan.oom_id AND valid_to IS NULL);
  IF p_date IS NULL OR (v_plan.kind = 'prepis' AND p_date <= v_from) OR (v_plan.kind <> 'prepis' AND p_date < v_from) THEN
    RAISE EXCEPTION 'Dátum musí byť po začiatku väzby (%).', v_from USING ERRCODE = 'check_violation';
  END IF;
  UPDATE oom_planned_change SET effective_date = p_date WHERE id = p_plan_id;
  IF oom_plan_due_on(v_plan.kind, p_date) <= crm_today() THEN
    -- deň už nastal: zmena hneď, s právami používateľa (ako pri zadaní s dátumom v minulosti)
    PERFORM set_config('crm.oom_plan_run', 'on', true);
    CASE v_plan.kind
      WHEN 'prepis'   THEN PERFORM oom_transfer(v_plan.oom_id, v_plan.company_id, v_plan.person_id, p_date);
      WHEN 'odchod'   THEN PERFORM oom_set_status(v_plan.oom_id, 'odidene', p_date);
      WHEN 'zrusenie' THEN PERFORM oom_set_status(v_plan.oom_id, 'zrusene', p_date);
    END CASE;
    PERFORM set_config('crm.oom_plan_run', '', true);
    UPDATE oom_planned_change SET status = 'vykonana', executed_at = now() WHERE id = p_plan_id;
    RETURN NULL;
  END IF;
  RETURN p_plan_id;
END;
$$;


--
-- Name: oom_plan_row_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_plan_row_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.oom_id <> OLD.oom_id OR NEW.kind <> OLD.kind
     OR NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.person_id IS DISTINCT FROM OLD.person_id THEN
    RAISE EXCEPTION 'Druh, odberné miesto a odberateľ plánu sa nemenia (zrušte plán a zadajte nový).'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.status IN ('vykonana', 'zrusena') THEN
    RAISE EXCEPTION 'Vykonaný alebo zrušený plán sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: oom_price_regulation_apply(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_price_regulation_apply(p_oom_id uuid, p_today date) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: oom_price_regulation_cancel(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_price_regulation_cancel(p_change_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: oom_price_regulation_set(uuid, boolean, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_prev boolean;
BEGIN
  IF p_valid_from IS NULL THEN
    RAISE EXCEPTION 'Zadaj dátum „platí od“.' USING ERRCODE = 'check_violation';
  END IF;
  -- prístup k OOM a právo ho upraviť (RLS a spúšťač Aktívneho OOM) overí zápis bez zmeny hodnoty
  UPDATE oom SET price_regulation = price_regulation WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  -- regulácia deň pred zmenou: posledná skoršia zmena, inak dnešná hodnota na OOM (0028)
  SELECT value INTO v_prev FROM oom_price_regulation_change
   WHERE oom_id = p_oom_id AND valid_from < p_valid_from ORDER BY valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    SELECT price_regulation INTO v_prev FROM oom WHERE id = p_oom_id;
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, prev_value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, v_prev, NULL, crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = NULL, contract_applied_at = NULL, created_by = EXCLUDED.created_by;
  PERFORM oom_price_regulation_apply(p_oom_id, crm_today());
END;
$$;


--
-- Name: FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) IS 'zmena cenovej regulácie OOM s dátumom (minulý, dnešný, budúci); budúcu uplatní nočný beh';


--
-- Name: oom_reconnect(uuid, uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_reconnect(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_from date DEFAULT public.crm_today()) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_last date;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_reconnect: zadaj práve jedno z company_id / person_id';
  END IF;
  IF EXISTS (SELECT 1 FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL) THEN
    RAISE EXCEPTION 'Odberné miesto už je u nás (Pripravované alebo Aktívne).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT max(valid_to) INTO v_last FROM oom_customer WHERE oom_id = p_oom_id;
  IF p_from <= v_last THEN
    RAISE EXCEPTION 'Nové obdobie musí začať po konci predošlého (%).', v_last USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom
     SET supply_from = NULL, supply_to = NULL, previous_supplier = NULL, switch_notice_required = true,
         switch_notice_sent_on = NULL, switch_notice_accepted_on = NULL, switch_confirmed_on = NULL
   WHERE id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, (SELECT org_id FROM oom WHERE id = p_oom_id), p_from, 'pripravovane')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;


--
-- Name: oom_set_status(uuid, public.oom_status, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_set_status(p_oom_id uuid, p_status public.oom_status, p_date date DEFAULT public.crm_today()) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_link oom_customer;
BEGIN
  IF p_status IN ('odidene', 'zrusene') THEN
    PERFORM oom_plan_guard(p_oom_id);
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;
  CASE p_status
    WHEN 'aktivne' THEN
      UPDATE oom_customer SET status = 'aktivne' WHERE id = v_link.id;
    WHEN 'odidene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'odchod', status = 'odidene' WHERE id = v_link.id;
    WHEN 'zrusene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'zrusenie', status = 'zrusene' WHERE id = v_link.id;
    WHEN 'prepisane' THEN
      RAISE EXCEPTION 'Prepis na iného odberateľa: oom_transfer.' USING ERRCODE = 'check_violation';
    ELSE
      RAISE EXCEPTION 'Stav % sa takto nenastavuje.', p_status USING ERRCODE = 'check_violation';
  END CASE;
END;
$$;


--
-- Name: oom_tariff_scope(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_tariff_scope(p_pds text) RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce((SELECT code FROM tariff_scope WHERE pds_code = p_pds),
                  (SELECT code FROM tariff_scope WHERE pds_code IS NULL))
$$;


--
-- Name: oom_transfer(uuid, uuid, uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  PERFORM oom_plan_guard(p_oom_id);
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


--
-- Name: oom_type_refresh(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_type_refresh() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: oom_voltage_group(public.voltage_level); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.oom_voltage_group(p_level public.voltage_level) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN p_level IN ('vn', 'vvn') THEN 'vn' ELSE 'nn' END
$$;


--
-- Name: org_bank_account_normalize(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.org_bank_account_normalize() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.iban := upper(regexp_replace(NEW.iban, '\s', '', 'g'));
  RETURN NEW;
END;
$$;


--
-- Name: owner_change_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.owner_change_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: pipeline_no_delete(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pipeline_no_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  RAISE EXCEPTION 'Pipeline ani stage sa nemažú, iba archivujú.' USING ERRCODE = 'check_violation';
END;
$$;


--
-- Name: pipeline_seed_stages(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pipeline_seed_stages() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: pipeline_stage_code_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pipeline_stage_code_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: price_exception_apply(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_exception_apply() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  k uuid;
BEGIN
  FOR k IN SELECT id FROM contract
            WHERE org_id = NEW.org_id AND company_id IS NOT DISTINCT FROM NEW.company_id
              AND person_id IS NOT DISTINCT FROM NEW.person_id AND signed_on IS NOT NULL LOOP
    PERFORM contract_basis_refresh(k);
  END LOOP;
  RETURN NULL;
END;
$$;


--
-- Name: price_exception_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_exception_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'price_exception'::regclass);
BEGIN
  IF TG_OP = 'INSERT' THEN
    NEW.org_id := coalesce((SELECT org_id FROM company WHERE id = NEW.company_id), (SELECT org_id FROM contact WHERE id = NEW.person_id));
    IF NOT v_system THEN
      NEW.requested_by := crm_active_user_id();
      IF NEW.status <> 'caka' THEN
        RAISE EXCEPTION 'Nová žiadosť o výnimku čaká na schválenie.' USING ERRCODE = 'check_violation';
      END IF;
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system AND NOT (OLD.status = 'caka' AND OLD.requested_by = crm_active_user_id()) THEN
      RAISE EXCEPTION 'Zmazať možno iba vlastnú žiadosť, ktorá ešte čaká.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF v_system THEN
    RETURN NEW;
  END IF;
  IF NEW.status = 'pouzita' OR OLD.status = 'pouzita' THEN
    RAISE EXCEPTION 'Výnimku použije iba import zmluvy.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.status <> 'caka' THEN
    RAISE EXCEPTION 'O výnimke už bolo rozhodnuté – podajte novú žiadosť.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.status = 'caka' THEN
    IF OLD.requested_by IS DISTINCT FROM crm_active_user_id() THEN
      RAISE EXCEPTION 'Žiadosť môže upraviť iba jej autor.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    RETURN NEW;
  END IF;
  -- rozhodnutie
  IF NOT crm_approves_prices() THEN
    RAISE EXCEPTION 'O výnimke rozhoduje CEO alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.requested_by = crm_active_user_id() THEN
    RAISE EXCEPTION 'Vlastnú žiadosť o výnimku nemôžete schváliť ani zamietnuť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF (to_jsonb(NEW) - ARRAY['status', 'decision_note', 'decided_by', 'decided_at', 'valid_until', 'updated_at'])
     <> (to_jsonb(OLD) - ARRAY['status', 'decision_note', 'decided_by', 'decided_at', 'valid_until', 'updated_at']) THEN
    RAISE EXCEPTION 'Pri rozhodnutí sa žiadosť nemení.' USING ERRCODE = 'check_violation';
  END IF;
  NEW.decided_by := crm_active_user_id();
  NEW.decided_at := now();
  NEW.valid_until := CASE WHEN NEW.status = 'schvalena' THEN crm_today() + 30 END;
  RETURN NEW;
END;
$$;


--
-- Name: price_exception_notify(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_exception_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_years text := array_to_string(NEW.years, ', ');
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM notification_add(array_remove(notification_approvers(NEW.org_id, false), NEW.requested_by), 'vynimka_nova',
                             NULL, NEW.id, NULL, NULL, format('Nová žiadosť o výnimku z ceny (rok %s)', v_years));
  ELSIF OLD.status = 'caka' AND NEW.status IN ('schvalena', 'zamietnuta') THEN
    PERFORM notification_add(ARRAY[NEW.requested_by], 'vynimka_rozhodnutie', NULL, NEW.id, NULL, NULL,
                             format('Výnimka z ceny (rok %s) je %s', v_years,
                                    CASE NEW.status WHEN 'schvalena' THEN 'schválená' ELSE 'zamietnutá' END));
  END IF;
  RETURN NULL;
END;
$$;


--
-- Name: price_exception_threshold(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_exception_threshold() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_seller seller_type;
  v_year   smallint := (SELECT min(x) FROM unnest(NEW.years) x);
  v        numeric;
BEGIN
  IF crm_active_user_id() IS NULL THEN
    RETURN NEW;
  END IF;
  v_seller := coalesce((SELECT seller_type FROM app_user WHERE id = crm_active_user_id()), 'obchodnik');
  v := CASE NEW.price_model
         WHEN 'fix' THEN trader_price(NEW.org_id, v_year, crm_today())
         WHEN 'spot_plus_eur' THEN contract_param(NEW.org_id,
                                     CASE v_seller WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, crm_today())
         WHEN 'spot_minus_eur' THEN contract_param(NEW.org_id, 'min_aditiv_vykup', crm_today())
       END;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Hranica pre rok % dnes nie je známa (chýbajú ceny BL/PL alebo parameter v Cenových parametroch).', v_year
      USING ERRCODE = 'check_violation';
  END IF;
  NEW.threshold_value := v;
  RETURN NEW;
END;
$$;


--
-- Name: price_list_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = OLD.id AND status <> 'navrh') THEN
      RAISE EXCEPTION 'Cenník so schválenou verziou sa nemaže.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Kód a spoločnosť cenníka sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: price_list_item_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_item_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_status price_list_version_status;
  v_list   price_list;
  v_prod   product;
BEGIN
  SELECT v.status INTO v_status FROM price_list_version v
   WHERE v.id = CASE WHEN TG_OP = 'DELETE' THEN OLD.version_id ELSE NEW.version_id END;
  -- pri zmazaní Návrhu (kaskáda) už verzia nemusí byť viditeľná – schválená sa zmazať nedá
  IF v_status IS NOT NULL AND v_status <> 'navrh' THEN
    RAISE EXCEPTION 'Schválený cenník sa nedá meniť. Vytvor novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NEW.version_id <> OLD.version_id THEN
    RAISE EXCEPTION 'Položka sa nepresúva do inej verzie.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' OR NEW.product_id <> OLD.product_id THEN
    SELECT l.* INTO v_list FROM price_list l JOIN price_list_version v ON v.price_list_id = l.id WHERE v.id = NEW.version_id;
    SELECT * INTO v_prod FROM product WHERE id = NEW.product_id;
    IF v_prod.org_id <> v_list.org_id OR v_prod.segment <> v_list.segment THEN
      RAISE EXCEPTION 'Produkt „%“ nepatrí do spoločnosti a segmentu cenníka.', v_prod.name USING ERRCODE = 'check_violation';
    END IF;
    IF NOT 'cennik' = ANY (v_prod.price_models) THEN
      RAISE EXCEPTION 'Produkt „%“ nemá cenový model cenník.', v_prod.name USING ERRCODE = 'check_violation';
    END IF;
    IF v_prod.status = 'ukonceny' THEN
      RAISE EXCEPTION 'Produkt „%“ je ukončený.', v_prod.name USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  -- cena NT iba pri dvojtarifnom produkte (Peter, doplnok b k F3)
  IF NEW.price_nt_eur_mwh IS NOT NULL
     AND (SELECT tariff_type FROM product WHERE id = NEW.product_id) <> 'dvojtarif' THEN
    RAISE EXCEPTION 'Produkt „%“ nie je dvojtarif – cena NT sa nezadáva.', (SELECT name FROM product WHERE id = NEW.product_id)
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: price_list_item_program_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_item_program_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_status   price_list_version_status;
  v_category product_category;
BEGIN
  SELECT v.status, p.category INTO v_status, v_category
    FROM price_list_item i
    JOIN price_list_version v ON v.id = i.version_id
    JOIN product p ON p.id = i.product_id
   WHERE i.id = CASE WHEN TG_OP = 'DELETE' THEN OLD.item_id ELSE NEW.item_id END;
  IF v_status IS NOT NULL AND v_status <> 'navrh' THEN
    RAISE EXCEPTION 'Schválený cenník sa nedá meniť. Vytvor novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  IF NEW.item_id <> coalesce(OLD.item_id, NEW.item_id) THEN
    RAISE EXCEPTION 'Parametre sa nepresúvajú k inej položke.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_category NOT IN ('vbattery', 'viwa') THEN
    RAISE EXCEPTION 'Parametre programu má iba VBattery alebo VIWA.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_category <> 'viwa' AND num_nonnulls(NEW.viwa_conversion_factor, NEW.viwa_activation_bonus,
                                           NEW.viwa_credit_expiry_months) > 0 THEN
    RAISE EXCEPTION 'Parametre VIWA má iba program VIWA.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: price_list_version_approve(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_approve(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v      price_list_version;
  v_next date;
BEGIN
  PERFORM price_list_writer_check();
  SELECT * INTO v FROM price_list_version WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT (SELECT org_id FROM price_list WHERE id = v.price_list_id) = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Verzia cenníka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF v.status <> 'navrh' THEN
    RAISE EXCEPTION 'Schváliť sa dá iba návrh.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM price_list_item WHERE version_id = p_id) THEN
    RAISE EXCEPTION 'Návrh nemá žiadnu položku.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM price_list_item i JOIN product p ON p.id = i.product_id
              WHERE i.version_id = p_id AND p.status = 'ukonceny') THEN
    RAISE EXCEPTION 'V návrhu je ukončený produkt (%) – odoberte ho.', (SELECT string_agg(p.name, ', ') FROM price_list_item i
      JOIN product p ON p.id = i.product_id WHERE i.version_id = p_id AND p.status = 'ukonceny') USING ERRCODE = 'check_violation';
  END IF;
  IF v.valid_from < crm_today() AND NOT crm_owner_session() THEN
    RAISE EXCEPTION 'Schváliť sa dá iba verzia s účinnosťou od dnes (%) alebo neskôr.', to_char(crm_today(), 'FMDD. FMMM. YYYY')
      USING ERRCODE = 'check_violation';
  END IF;

  UPDATE price_list_item i SET vat_rate = p.vat_rate FROM product p WHERE p.id = i.product_id AND i.version_id = p_id;

  -- oprava budúceho cenníka: verzia s rovnakým dátumom účinnosti, ktorá ešte neplatí
  UPDATE price_list_version SET status = 'nahradena'
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from = v.valid_from;
  -- predošlá verzia platí do dňa pred novou
  UPDATE price_list_version SET valid_to = v.valid_from - 1
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from < v.valid_from
     AND (valid_to IS NULL OR valid_to >= v.valid_from);
  -- neskoršia schválená verzia: nová platí najdlhšie do dňa pred ňou
  SELECT min(valid_from) INTO v_next FROM price_list_version
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from > v.valid_from;
  UPDATE price_list_version
     SET status = 'schvalena', approved_at = now(), approved_by = crm_active_user_id(),
         valid_to = CASE WHEN v_next IS NULL THEN valid_to ELSE least(coalesce(valid_to, v_next - 1), v_next - 1) END
   WHERE id = p_id;
END;
$$;


--
-- Name: price_list_version_approve_preview(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_approve_preview(p_id uuid) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v        price_list_version;
  v_today  date := crm_today();
  v_errors jsonb := '[]';
  v_same   price_list_version;
  v_prev   price_list_version;
  v_next   date;
  v_cur    uuid;
BEGIN
  PERFORM price_list_writer_check();
  SELECT * INTO v FROM price_list_version WHERE id = p_id;
  IF NOT FOUND OR NOT (SELECT org_id FROM price_list WHERE id = v.price_list_id) = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Verzia cenníka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;

  IF v.status <> 'navrh' THEN
    v_errors := v_errors || to_jsonb('Schváliť sa dá iba návrh.'::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM price_list_item WHERE version_id = p_id) THEN
    v_errors := v_errors || to_jsonb('Návrh nemá žiadnu položku.'::text);
  END IF;
  IF EXISTS (SELECT 1 FROM price_list_item i JOIN product p ON p.id = i.product_id
              WHERE i.version_id = p_id AND p.status = 'ukonceny') THEN
    v_errors := v_errors || to_jsonb(format('V návrhu je ukončený produkt (%s) – odoberte ho.',
      (SELECT string_agg(p.name, ', ') FROM price_list_item i JOIN product p ON p.id = i.product_id
        WHERE i.version_id = p_id AND p.status = 'ukonceny')));
  END IF;
  IF v.valid_from < v_today AND NOT crm_owner_session() THEN
    v_errors := v_errors || to_jsonb(format('Platnosť musí začínať dnes (%s) alebo neskôr.', to_char(v_today, 'FMDD. FMMM. YYYY')));
  END IF;

  -- schválená verzia s rovnakým dátumom: budúca sa nahradí, platná nie
  SELECT * INTO v_same FROM price_list_version
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from = v.valid_from;
  IF v_same.id IS NOT NULL AND v_same.valid_from <= v_today THEN
    v_errors := v_errors || to_jsonb(format('Verzia %s s rovnakým dátumom už platí – nedá sa nahradiť. Zvoľ neskorší dátum.', v_same.name));
  END IF;
  -- predošlá verzia, ktorá sa uzavrie deň pred novou
  SELECT * INTO v_prev FROM price_list_version
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from < v.valid_from
     AND (valid_to IS NULL OR valid_to >= v.valid_from)
   ORDER BY valid_from DESC LIMIT 1;
  -- uzavrieť predošlú do minulosti nesmie nikto (spúšťač 0020); adminovi to už hovorí chyba dátumu vyššie
  IF v_prev.id IS NOT NULL AND v.valid_from < v_today AND crm_owner_session() THEN
    v_errors := v_errors || to_jsonb('Predošlú verziu by bolo treba uzavrieť do minulosti.'::text);
  END IF;
  SELECT min(valid_from) INTO v_next FROM price_list_version
   WHERE price_list_id = v.price_list_id AND status = 'schvalena' AND valid_from > v.valid_from;

  SELECT current_version_id INTO v_cur FROM price_list_current_v WHERE id = v.price_list_id;

  RETURN jsonb_build_object(
    'version_id', v.id,
    'name', v.name,
    'valid_from', v.valid_from,
    'valid_to', CASE WHEN v_next IS NULL THEN v.valid_to ELSE least(coalesce(v.valid_to, v_next - 1), v_next - 1) END,
    'item_count', (SELECT count(*) FROM price_list_item WHERE version_id = p_id),
    'can_approve', jsonb_array_length(v_errors) = 0,
    'errors', v_errors,
    'supersedes', CASE WHEN v_same.id IS NULL THEN NULL
                       ELSE jsonb_build_object('id', v_same.id, 'name', v_same.name) END,
    'closes', CASE WHEN v_prev.id IS NULL THEN NULL
                   ELSE jsonb_build_object('id', v_prev.id, 'name', v_prev.name, 'valid_to', v.valid_from - 1) END,
    'missing_products', coalesce((
      SELECT jsonb_agg(p.name ORDER BY i.sort_order, p.name)
        FROM price_list_item i JOIN product p ON p.id = i.product_id
       WHERE i.version_id = v_cur AND v_cur <> p_id
         AND NOT EXISTS (SELECT 1 FROM price_list_item n WHERE n.version_id = p_id AND n.product_id = i.product_id)), '[]')
  );
END;
$$;


--
-- Name: FUNCTION price_list_version_approve_preview(p_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.price_list_version_approve_preview(p_id uuid) IS 'náhľad price_list_version_approve bez zmeny dát: dá sa schváliť, čo sa nahradí / uzavrie, chýbajúce produkty';


--
-- Name: price_list_version_close(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_close(p_id uuid, p_valid_to date) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v price_list_version;
BEGIN
  PERFORM price_list_writer_check();
  SELECT * INTO v FROM price_list_version WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT (SELECT org_id FROM price_list WHERE id = v.price_list_id) = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Verzia cenníka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF v.status <> 'schvalena' THEN
    RAISE EXCEPTION 'Ukončiť sa dá iba schválená verzia.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_valid_to IS NULL OR p_valid_to < crm_today() OR p_valid_to < v.valid_from THEN
    RAISE EXCEPTION 'Dátum ukončenia musí byť dnes alebo neskôr a po začiatku platnosti.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE price_list_version SET valid_to = p_valid_to WHERE id = p_id;
END;
$$;


--
-- Name: price_list_version_copy(uuid, text, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_copy(p_source_id uuid, p_name text, p_valid_from date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_src     price_list_version;
  v_new     uuid;
  v_item    uuid;
  r         record;
  v_skipped jsonb := '[]';
BEGIN
  PERFORM price_list_writer_check();
  SELECT * INTO v_src FROM price_list_version WHERE id = p_source_id;
  IF NOT FOUND OR NOT (SELECT org_id FROM price_list WHERE id = v_src.price_list_id) = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Verzia cenníka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF EXISTS (SELECT 1 FROM price_list_version WHERE price_list_id = v_src.price_list_id AND status = 'navrh') THEN
    RAISE EXCEPTION 'Cenník už má rozpracovaný návrh – dokonči ho alebo zmaž.' USING ERRCODE = 'unique_violation';
  END IF;
  INSERT INTO price_list_version (price_list_id, name, valid_from, copied_from_id, note)
  VALUES (v_src.price_list_id, p_name, p_valid_from, v_src.id, NULL)
  RETURNING id INTO v_new;

  FOR r IN SELECT i.*, p.status AS product_status, p.name AS product_name
             FROM price_list_item i JOIN product p ON p.id = i.product_id
            WHERE i.version_id = v_src.id ORDER BY i.sort_order, p.name LOOP
    IF r.product_status = 'ukonceny' THEN
      v_skipped := v_skipped || to_jsonb(r.product_name);
      CONTINUE;
    END IF;
    INSERT INTO price_list_item (version_id, product_id, price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                                 fee_program_eur_month, fee_kw_eur_month, sort_order)
    VALUES (v_new, r.product_id, r.price_vt_eur_mwh, r.price_nt_eur_mwh, r.fee_oom_eur_month,
            r.fee_program_eur_month, r.fee_kw_eur_month, r.sort_order)
    RETURNING id INTO v_item;
    INSERT INTO price_list_item_program (item_id, greencar, greencar_kwh_per_voucher, greencar_voucher_eur, greenshare,
                                         greenshare_fee_pct, viwa_conversion_factor, viwa_activation_bonus,
                                         viwa_credit_expiry_months)
    SELECT v_item, greencar, greencar_kwh_per_voucher, greencar_voucher_eur, greenshare, greenshare_fee_pct,
           viwa_conversion_factor, viwa_activation_bonus, viwa_credit_expiry_months
      FROM price_list_item_program WHERE item_id = r.id;
  END LOOP;
  RETURN jsonb_build_object('version_id', v_new, 'skipped', v_skipped);
END;
$$;


--
-- Name: price_list_version_delete(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_delete(p_id uuid) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v price_list_version;
BEGIN
  PERFORM price_list_writer_check();
  SELECT * INTO v FROM price_list_version WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT (SELECT org_id FROM price_list WHERE id = v.price_list_id) = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Verzia cenníka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF v.status <> 'navrh' THEN
    RAISE EXCEPTION 'Zmazať sa dá iba návrh.' USING ERRCODE = 'check_violation';
  END IF;
  DELETE FROM price_list_version WHERE id = p_id;
END;
$$;


--
-- Name: price_list_version_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'navrh' THEN
      RAISE EXCEPTION 'Nová verzia cenníka vzniká iba ako návrh.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'navrh' THEN
      RAISE EXCEPTION 'Schválená verzia cenníka sa nemaže.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.price_list_id <> OLD.price_list_id THEN
    RAISE EXCEPTION 'Verzia sa nepresúva do iného cenníka.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.status = 'navrh' THEN
    IF NEW.status = 'nahradena' THEN
      RAISE EXCEPTION 'Návrh sa nedá nahradiť, iba zmazať.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
  END IF;
  IF OLD.status = 'nahradena' THEN
    RAISE EXCEPTION 'Nahradená verzia cenníka sa nemení.' USING ERRCODE = 'check_violation';
  END IF;

  -- schválená
  IF (to_jsonb(NEW) - ARRAY['valid_to', 'status', 'updated_at'])
     IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['valid_to', 'status', 'updated_at']) THEN
    RAISE EXCEPTION 'Schválený cenník sa nedá meniť. Vytvor novú verziu.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.status <> OLD.status THEN
    IF NEW.status <> 'nahradena' OR OLD.valid_from <= crm_today() OR NEW.valid_to IS DISTINCT FROM OLD.valid_to THEN
      RAISE EXCEPTION 'Nahradiť sa dá iba schválená verzia, ktorá ešte neplatí.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.valid_to IS DISTINCT FROM OLD.valid_to THEN
    IF NEW.valid_to IS NULL OR (OLD.valid_to IS NOT NULL AND NEW.valid_to > OLD.valid_to)
       OR NEW.valid_to < crm_today() - 1 THEN
      RAISE EXCEPTION 'Platnosť schválenej verzie sa dá iba skrátiť, najskôr ku včerajšku.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: price_list_version_state(public.price_list_version_status, date, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_version_state(p_status public.price_list_version_status, p_from date, p_to date, p_on date) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE
           WHEN p_status = 'navrh' THEN 'navrh'
           WHEN p_status = 'nahradena' OR p_to < p_on THEN 'ukoncena'
           WHEN p_from > p_on THEN 'buduca'
           ELSE 'platna'
         END
$$;


--
-- Name: price_list_writer_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_list_writer_check() RETURNS void
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NOT crm_price_list_writer() THEN
    RAISE EXCEPTION 'Cenníky spravuje iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;


--
-- Name: price_param(uuid, text, date, smallint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_param(p_org uuid, p_code text, p_on date, p_year smallint DEFAULT NULL::smallint) RETURNS numeric
    LANGUAGE sql STABLE
    AS $$
  SELECT value FROM price_parameter
   WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year AND valid_from <= p_on
   ORDER BY valid_from DESC
   LIMIT 1
$$;


--
-- Name: price_parameter_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_parameter_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'min_aditiv_vykup', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'min_aditiv_vykup', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;


--
-- Name: price_with_vat(numeric, numeric, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.price_with_vat(p_net numeric, p_vat numeric, p_scale integer) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT round(p_net * (1 + p_vat / 100), p_scale)
$$;


--
-- Name: product_candidates(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.product_candidates(p_oom_id uuid) RETURNS TABLE(product_id uuid, rank smallint, is_only boolean, is_addon boolean)
    LANGUAGE sql STABLE
    AS $$
  SELECT c.*
    FROM oom o,
         LATERAL product_candidates_by(o.org_id,
                                       CASE WHEN o.person_id IS NOT NULL THEN 'domacnost' ELSE 'firma' END::customer_segment,
                                       o.pds, o.pds_tariff, o.price_regulation,
                                       coalesce(o.planned_consumption_nt_mwh, 0) > 0) c
   WHERE o.id = p_oom_id
$$;


--
-- Name: product_candidates_by(uuid, public.customer_segment, text, text, boolean, boolean); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.product_candidates_by(p_org uuid, p_segment public.customer_segment, p_pds text, p_tariff text, p_regulation boolean, p_has_nt boolean) RETURNS TABLE(product_id uuid, rank smallint, is_only boolean, is_addon boolean)
    LANGUAGE sql STABLE
    AS $$
  WITH o AS (
    SELECT p_org AS org_id, p_regulation AS price_regulation, coalesce(p_has_nt, false) AS has_nt, p_segment AS segment,
           oom_tariff_scope(p_pds) AS scope, tariff_base(p_tariff, p_pds) AS tariff
     WHERE p_pds IS NOT NULL AND p_tariff IS NOT NULL
  ), c AS (
    SELECT p.id, p.category = 'zem' AS is_addon, p.sort_order, p.name,
           CASE WHEN p.category = 'zem' THEN 1
                WHEN (p.tariff_type = 'dvojtarif') = o.has_nt THEN 1
                ELSE 2 END::smallint AS rank
      FROM o
      JOIN product p ON p.org_id = o.org_id AND p.status = 'predava_sa' AND p.segment = o.segment
                    AND (p.price_regulation IS NULL OR o.price_regulation IS NULL
                         OR p.price_regulation = o.price_regulation)
     WHERE EXISTS (SELECT 1 FROM product_tariff t
                    WHERE t.product_id = p.id AND t.scope_code = o.scope AND t.tariff_code = o.tariff)
  )
  SELECT id, rank, NOT is_addon AND count(*) FILTER (WHERE NOT is_addon) OVER () = 1, is_addon
    FROM c
   ORDER BY is_addon, rank, sort_order, name
$$;


--
-- Name: product_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.product_guard() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Produkt sa nemaže, iba ukončí (stav Ukončený).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Kód a spoločnosť produktu sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  -- použitý produkt (je v položke cenníka): kategória, segment, typ a variant tarifu, cenová regulácia a model „cenník“ sa nemenia
  IF (NEW.category <> OLD.category OR NEW.segment <> OLD.segment OR NEW.tariff_type <> OLD.tariff_type
      OR NEW.tariff_variant IS DISTINCT FROM OLD.tariff_variant
      OR NEW.price_regulation IS DISTINCT FROM OLD.price_regulation
      OR ('cennik' = ANY (OLD.price_models) AND NOT 'cennik' = ANY (NEW.price_models)))
     AND EXISTS (SELECT 1 FROM price_list_item WHERE product_id = OLD.id) THEN
    RAISE EXCEPTION 'Produkt „%“ je v cenníku: kategória, segment, typ ani variant tarifu, cenová regulácia ani model cenník sa nemenia.', OLD.name
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: product_regulation_pair(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.product_regulation_pair(p_product_id uuid) RETURNS uuid
    LANGUAGE sql STABLE
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT q.id
    FROM product p
    JOIN import_alias x ON x.is_system AND x.kind = 'produkt_oom' AND x.target_extra ? 'ano'
                       AND p.code IN (x.target, x.target_extra ->> 'ano')
    JOIN product q ON q.code = CASE WHEN p.code = x.target THEN x.target_extra ->> 'ano' ELSE x.target END
   WHERE p.id = p_product_id
   LIMIT 1
$$;


--
-- Name: product_tariff_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.product_tariff_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_scope tariff_scope;
  v_org   uuid := (SELECT org_id FROM product WHERE id = NEW.product_id);
BEGIN
  SELECT * INTO v_scope FROM tariff_scope WHERE code = NEW.scope_code;
  IF NOT EXISTS (
       SELECT 1 FROM lookup_value v
        WHERE v.list_code = 'sadzba_distribucie' AND v.hidden_at IS NULL
          AND (v.org_id IS NULL OR v.org_id = v_org)
          AND tariff_base(v.code, v.parent_code) = NEW.tariff_code
          AND CASE WHEN v_scope.pds_code IS NOT NULL THEN v.parent_code = v_scope.pds_code
                   ELSE v.parent_code NOT IN (SELECT pds_code FROM tariff_scope WHERE pds_code IS NOT NULL) END) THEN
    RAISE EXCEPTION 'Sadzba „%“ nie je v číselníku pre rozsah %.', NEW.tariff_code, v_scope.name
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: pv_revenue(text, public.price_model, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pv_revenue(p_kind text, p_model public.price_model, p_vt numeric, p_nt numeric, p_ad numeric, p_pct numeric, p_v_vt numeric, p_v_nt numeric, p_spot_fve numeric, p_viwa_additive numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p_kind
           WHEN 'fix' THEN p_vt * p_v_vt + coalesce(p_nt, p_vt) * p_v_nt
           WHEN 'cennik' THEN p_vt * p_v_vt + coalesce(p_nt, p_vt) * p_v_nt
           WHEN 'energo' THEN p_vt * p_v_vt + coalesce(p_nt, p_vt) * p_v_nt
           WHEN 'spot_plus_eur' THEN p_ad * (p_v_vt + p_v_nt)
           WHEN 'vykup' THEN CASE p_model WHEN 'spot_minus_eur' THEN p_ad * (p_v_vt + p_v_nt)
                                          WHEN 'spot_minus_pct' THEN p_pct / 100 * p_spot_fve * (p_v_vt + p_v_nt)
                                          -- výkup s pevnou cenou: nákup = predaj, pridaná hodnota a marža 0 (otázka 33)
                                          WHEN 'fix' THEN p_vt * (p_v_vt + p_v_nt) END
           WHEN 'viwa' THEN p_viwa_additive * (p_v_vt + p_v_nt)
         END
$$;


--
-- Name: pv_unit_cost(text, public.price_model, numeric, public.seller_type, numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pv_unit_cost(p_kind text, p_model public.price_model, p_vt numeric, p_seller public.seller_type, p_trader numeric, p_portfolio numeric, p_energopomoc numeric, p_min_additive numeric, p_exception numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p_kind
           WHEN 'fix' THEN coalesce(p_exception, CASE WHEN p_seller = 'manazer' THEN p_portfolio ELSE p_trader END)
           WHEN 'cennik' THEN p_portfolio
           WHEN 'energo' THEN p_energopomoc
           WHEN 'spot_plus_eur' THEN coalesce(p_exception, p_min_additive)
           WHEN 'vykup' THEN CASE WHEN p_model = 'fix' THEN p_vt ELSE coalesce(p_exception, p_min_additive) END
           WHEN 'viwa' THEN 0
         END
$$;


--
-- Name: pv_unit_margin_cost(text, public.price_model, numeric, numeric, numeric, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.pv_unit_margin_cost(p_kind text, p_model public.price_model, p_vt numeric, p_portfolio_today numeric, p_energopomoc numeric, p_min_additive numeric, p_exception numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE p_kind
           WHEN 'fix' THEN p_portfolio_today
           WHEN 'cennik' THEN p_portfolio_today
           WHEN 'energo' THEN p_energopomoc
           WHEN 'spot_plus_eur' THEN 0
           WHEN 'vykup' THEN CASE WHEN p_model = 'fix' THEN p_vt ELSE coalesce(p_exception, p_min_additive) END
           WHEN 'viwa' THEN 0
         END
$$;


--
-- Name: record_org_fill(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.record_org_fill() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_org  uuid;
  v_ref  uuid;
BEGIN
  IF TG_TABLE_NAME = 'offer' THEN
    SELECT org_id INTO v_org FROM deal WHERE id = NEW.deal_id;
  ELSIF NEW.company_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM company WHERE id = NEW.company_id;
  ELSIF NEW.person_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM contact WHERE id = NEW.person_id;
  END IF;

  -- bez zákazníka predvolená spoločnosť, aby zlyhala kontrola zákazníka (CHECK), nie NOT NULL
  NEW.org_id := coalesce(NEW.org_id, v_org, crm_default_org());
  IF v_org IS NOT NULL AND NEW.org_id <> v_org THEN
    RAISE EXCEPTION 'Záznam musí patriť tej istej spoločnosti ako jeho zákazník.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_TABLE_NAME = 'deal' THEN
    SELECT org_id INTO v_ref FROM pipeline WHERE id = NEW.pipeline_id;
    IF v_ref IS NOT NULL AND v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Pipeline patrí inej spoločnosti ako deal.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF TG_TABLE_NAME = 'contract' THEN
    -- (NEW.deal_id iba vo vetve zmluvy: OOM stĺpec deal_id nemá)
    SELECT org_id INTO v_ref FROM deal WHERE id = NEW.deal_id;
    IF v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Deal zmluvy patrí inej spoločnosti.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: set_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;


--
-- Name: small_business_volume(date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.small_business_volume(p_on date, p_company_id uuid DEFAULT NULL::uuid) RETURNS TABLE(company_id uuid, contract_mwh numeric, xm_mwh numeric, xm_missing integer, oom_count integer, state text, message text)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  WITH r AS (
    SELECT k.company_id, k.small_business, co.oom_id, co.qty_vt_mwh + co.qty_nt_mwh AS qty,
           p.price_regulation AS product_reg, o.price_regulation AS oom_reg,
           o.planned_consumption_vt_mwh AS xm_vt, o.planned_consumption_nt_mwh AS xm_nt
      FROM contract k
      JOIN contract_oom co ON co.contract_id = k.id
      JOIN oom o ON o.id = co.oom_id
      LEFT JOIN product p ON p.id = co.product_id
     WHERE k.company_id IS NOT NULL AND (p_company_id IS NULL OR k.company_id = p_company_id)
       AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%' AND o.type = 'spotreba'
       AND co.valid_from IS NOT NULL AND co.valid_from <= p_on AND (co.valid_to IS NULL OR co.valid_to >= p_on)
  ), c AS (
    SELECT r.company_id, sum(r.qty) AS contract_mwh,
           bool_or(r.small_business OR r.product_reg IS TRUE OR r.oom_reg IS TRUE) AS regulated
      FROM r GROUP BY r.company_id
  ), x AS (
    SELECT d.company_id,
           sum(coalesce(d.xm_vt, 0) + coalesce(d.xm_nt, 0)) FILTER (WHERE d.xm_vt IS NOT NULL OR d.xm_nt IS NOT NULL) AS xm_mwh,
           (count(*) FILTER (WHERE d.xm_vt IS NULL AND d.xm_nt IS NULL))::int AS xm_missing,
           count(*)::int AS oom_count
      FROM (SELECT DISTINCT r.company_id, r.oom_id, r.xm_vt, r.xm_nt FROM r) d
     GROUP BY d.company_id
  ), s AS (
    SELECT c.company_id, c.contract_mwh, x.xm_mwh, x.xm_missing, x.oom_count,
           CASE WHEN c.contract_mwh > 30 AND (x.xm_mwh IS NULL OR x.xm_mwh > 30) THEN 'vyradit'
                WHEN c.contract_mwh > 30 OR x.xm_mwh > 30 THEN 'nesulad'
                ELSE 'ostava' END AS state,
           format('zmluvy %s MWh, XM Trade %s', mwh_text(c.contract_mwh),
                  CASE WHEN x.xm_mwh IS NULL THEN 'bez plánovanej spotreby'
                       ELSE mwh_text(x.xm_mwh) || ' MWh'
                            || CASE WHEN x.xm_missing > 0 THEN format(' (pri %s z %s OOM chýba)', x.xm_missing, x.oom_count) ELSE '' END
                  END) AS volumes
      FROM c JOIN x ON x.company_id = c.company_id
     WHERE c.regulated
  )
  SELECT s.company_id, s.contract_mwh, s.xm_mwh, s.xm_missing, s.oom_count, s.state,
         CASE s.state
           WHEN 'ostava' THEN format('Ročný objem do 30 MWh (%s) – zákazník ostáva v cenovej regulácii.', s.volumes)
           WHEN 'vyradit' THEN format('Pozor: ročný objem nad 30 MWh (%s) – zákazník nemá nárok na regulovaný cenník, treba ho vyradiť z cenovej regulácie.', s.volumes)
           ELSE format('Pozor: objem podľa zmlúv a podľa XM Trade sa líši okolo hranice 30 MWh (%s). Overte, či má zákazník nárok na regulovaný cenník.', s.volumes)
         END
    FROM s
$$;


--
-- Name: FUNCTION small_business_volume(p_on date, p_company_id uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.small_business_volume(p_on date, p_company_id uuid) IS 'malý podnik: ročný objem zo zmlúv a z XM Trade k dňu, stav ostava / vyradit / nesulad (hranica 30 MWh vrátane); iba upozornenie';


--
-- Name: tariff_base(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tariff_base(p_code text, p_parent text) RETURNS text
    LANGUAGE sql IMMUTABLE
    AS $$
  SELECT CASE WHEN left(p_code, length(p_parent) + 1) = p_parent || '_' THEN substr(p_code, length(p_parent) + 2) END
$$;


--
-- Name: tariff_scope_check(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.tariff_scope_check() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF NEW.pds_code IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = 'pds' AND code = NEW.pds_code) THEN
    RAISE EXCEPTION 'PDS „%“ nie je v číselníku.', NEW.pds_code USING ERRCODE = 'foreign_key_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: team_external_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.team_external_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_TABLE_NAME = 'team_permission' THEN
    IF (NEW.view_scope = 'vsetko' OR NEW.edit_scope = 'vsetko' OR NEW.can_see_company_margin)
       AND EXISTS (SELECT 1 FROM team t WHERE t.id = NEW.team_id AND t.is_external) THEN
      RAISE EXCEPTION 'Externý tím nemôže vidieť ani upravovať „všetko“ ani vidieť maržu firmy (modul %).', NEW.module
        USING ERRCODE = 'check_violation';
    END IF;
  ELSIF NEW.is_external AND (EXISTS (SELECT 1 FROM team_permission p
                                      WHERE p.team_id = NEW.id
                                        AND (p.view_scope = 'vsetko' OR p.edit_scope = 'vsetko' OR p.can_see_company_margin))
                             OR EXISTS (SELECT 1 FROM app_user u WHERE u.team_id = NEW.id AND u.approves_prices)) THEN
    RAISE EXCEPTION 'Tím s právom „všetko“, maržou firmy alebo členom, ktorý schvaľuje ceny, nemôže byť externý.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;


--
-- Name: team_permission_init(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.team_permission_init() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO team_permission (team_id, module)
  SELECT NEW.id, m FROM unnest(enum_range(NULL::crm_module)) AS m;
  RETURN NULL;
END;
$$;


--
-- Name: trader_price(uuid, smallint, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trader_price(p_org uuid, p_year smallint, p_on date) RETURNS numeric
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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


--
-- Name: FUNCTION trader_price(p_org uuid, p_year smallint, p_on date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.trader_price(p_org uuid, p_year smallint, p_on date) IS 'cena pre obchodníka = (BL × pomer + PL × (100 − pomer)) / 100 + riziková prirážka + naša marža k dátumu';


--
-- Name: user_commission_pct(uuid, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_commission_pct(p_user uuid, p_on date DEFAULT public.crm_today()) RETURNS numeric
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT coalesce((SELECT r.pct FROM user_commission_rate r
                    WHERE r.user_id = p_user AND r.valid_from <= p_on ORDER BY r.valid_from DESC LIMIT 1),
                  (SELECT (value #>> '{}')::numeric FROM app_setting WHERE key = 'commission_pct_default'), 40)
$$;


--
-- Name: user_commission_rate_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_commission_rate_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF crm_owner_session() OR crm_internal_call() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Percento provízie mení admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'Percento sa nemení – zadajte nové s dátumom „platí od“.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF OLD.valid_from <= crm_today() THEN
      RAISE EXCEPTION 'Zmazať sa dá iba percento s budúcim dátumom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NEW.valid_from < crm_today() THEN
    RAISE EXCEPTION 'Percento platí od dnes alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;


--
-- Name: user_photo_get(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_photo_get(p_user uuid) RETURNS TABLE(mime text, data bytea)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT mime, data FROM user_photo WHERE user_id = p_user
$$;


--
-- Name: user_photo_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_photo_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF TG_OP <> 'DELETE' THEN
    NEW.sha256 := encode(sha256(NEW.data), 'hex');
    NEW.updated_by := crm_active_user_id();
    NEW.updated_at := now();
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;


--
-- Name: user_profile_set(uuid, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_profile_set(p_user uuid, p_phone text, p_mobile text, p_job_title text, p_linkedin text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF crm_active_user_id() IS NULL OR NOT (p_user = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Profil mení používateľ sám alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE app_user SET phone = nullif(btrim(p_phone), ''), mobile = nullif(btrim(p_mobile), ''),
                      job_title = nullif(btrim(p_job_title), ''), linkedin_url = nullif(btrim(p_linkedin), '')
   WHERE id = p_user;
END;
$$;


--
-- Name: user_signature_images_get(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_signature_images_get(p_user uuid) RETURNS TABLE(cid text, mime text, data bytea)
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT i.cid, i.mime, i.data FROM user_signature_image i
    JOIN user_signature s ON s.user_id = i.user_id AND s.mode = 'vlastny'
   WHERE i.user_id = p_user
   ORDER BY i.cid
$$;


--
-- Name: user_signature_set(uuid, text, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_signature_set(p_user uuid, p_mode text, p_html text, p_text text, p_images jsonb) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  i      jsonb;
  v_cid  text;
  v_data bytea;
BEGIN
  IF crm_active_user_id() IS NULL OR NOT (p_user = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Podpis mení používateľ sám alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_mode NOT IN ('profil', 'vlastny') THEN
    RAISE EXCEPTION 'Neznámy druh podpisu.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_typeof(coalesce(p_images, '[]')) <> 'array' OR jsonb_array_length(coalesce(p_images, '[]')) > 5 THEN
    RAISE EXCEPTION 'Podpis môže mať najviac 5 obrázkov.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_mode = 'vlastny' THEN
    FOR v_cid IN SELECT m[1] FROM regexp_matches(coalesce(p_html, ''), 'cid:([A-Za-z0-9]+)', 'g') m LOOP
      IF NOT EXISTS (SELECT 1 FROM jsonb_array_elements(coalesce(p_images, '[]')) x WHERE x->>'cid' = v_cid) THEN
        RAISE EXCEPTION 'Podpis odkazuje na chýbajúci obrázok.' USING ERRCODE = 'check_violation';
      END IF;
    END LOOP;
  END IF;
  INSERT INTO user_signature (user_id, mode, html, text_version, updated_by)
  VALUES (p_user, p_mode, nullif(p_html, ''), nullif(p_text, ''), crm_active_user_id())
  ON CONFLICT (user_id) DO UPDATE SET mode = excluded.mode, html = excluded.html, text_version = excluded.text_version,
                                      updated_by = excluded.updated_by;
  DELETE FROM user_signature_image WHERE user_id = p_user;
  FOR i IN SELECT * FROM jsonb_array_elements(coalesce(p_images, '[]')) LOOP
    v_data := decode(i->>'data_base64', 'base64');
    INSERT INTO user_signature_image (user_id, cid, mime, data, sha256)
    VALUES (p_user, i->>'cid', i->>'mime', v_data, encode(sha256(v_data), 'hex'));
  END LOOP;
END;
$$;


--
-- Name: working_days_before(uuid, date, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.working_days_before(p_org uuid, p_day date, p_n integer) RETURNS date
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT date FROM business_calendar
   WHERE org_id = coalesce(p_org, crm_default_org()) AND date < p_day AND is_working_day
   ORDER BY date DESC OFFSET greatest(p_n, 1) - 1 LIMIT 1
$$;


--
-- Name: ponuka_akceptovat(text, uuid, text, text, inet, text, text); Type: FUNCTION; Schema: verejne; Owner: -
--

CREATE FUNCTION verejne.ponuka_akceptovat(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text, p_terms_sha256 text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT public.offer_public_accept(p_hash, p_variant, p_name, p_function, p_ip, p_ua, p_terms_sha256)
$$;


--
-- Name: ponuka_pdf(text); Type: FUNCTION; Schema: verejne; Owner: -
--

CREATE FUNCTION verejne.ponuka_pdf(p_hash text) RETURNS jsonb
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT public.offer_public_pdf(p_hash)
$$;


--
-- Name: ponuka_potvrdenie_pdf(text); Type: FUNCTION; Schema: verejne; Owner: -
--

CREATE FUNCTION verejne.ponuka_potvrdenie_pdf(p_hash text) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
DECLARE
  o offer;
  a offer_acceptance;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash;
  IF offer_public_mode(o) = 'neplatny' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL AND confirmation_pdf_key IS NOT NULL;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('pdf_key', a.confirmation_pdf_key,
                            'file_name', 'Potvrdenie-' || replace(offer_display_number(o), '/', '-') || '.pdf');
END;
$_$;


--
-- Name: ponuka_potvrdenie_ulozit(text, uuid, text, text); Type: FUNCTION; Schema: verejne; Owner: -
--

CREATE FUNCTION verejne.ponuka_potvrdenie_ulozit(p_hash text, p_acceptance uuid, p_key text, p_sha256 text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $_$
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' OR NOT EXISTS (
       SELECT 1 FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id
        WHERE a.id = p_acceptance AND o.link_hash = p_hash AND a.method = 'klik' AND a.revoked_at IS NULL
          AND a.created_at >= now() - interval '10 minutes') THEN
    RAISE EXCEPTION 'Potvrdenie nemožno uložiť.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM public.offer_acceptance_confirmation_attach(p_acceptance, p_key, p_sha256);
END;
$_$;


--
-- Name: ponuka_zobrazit(text); Type: FUNCTION; Schema: verejne; Owner: -
--

CREATE FUNCTION verejne.ponuka_zobrazit(p_hash text) RETURNS jsonb
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
  SELECT public.offer_public_view(p_hash)
$$;


--
-- Name: activity; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    type public.activity_type NOT NULL,
    direction text,
    company_id uuid,
    contact_id uuid,
    deal_id uuid,
    oom_id uuid,
    conversation_id uuid,
    user_id uuid,
    occurred_at timestamp with time zone NOT NULL,
    subject text,
    body_preview text,
    source text,
    source_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    body text,
    CONSTRAINT activity_note_check CHECK (((type <> 'poznamka'::public.activity_type) OR (source IS DISTINCT FROM 'crm'::text) OR ((btrim(body) <> ''::text) AND (user_id IS NOT NULL) AND (num_nonnulls(company_id, contact_id) >= 1))))
);


--
-- Name: COLUMN activity.body; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.activity.body IS 'celý text (poznámka z CRM); body_preview je náhľad z HubSpotu';


--
-- Name: app_setting; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_setting (
    key text NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    value jsonb NOT NULL,
    description text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT app_setting_key_check CHECK ((key ~ '^[a-z][a-z0-9_]{1,62}$'::text))
);


--
-- Name: TABLE app_setting; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.app_setting IS 'nastavenia systému podľa prostredia (Test / Ostré); mení ich iba vlastník databázy (db/app-setting.sh)';


--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    team_id uuid NOT NULL,
    hubspot_owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    status public.user_status DEFAULT 'pozvany'::public.user_status NOT NULL,
    is_admin boolean DEFAULT false NOT NULL,
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    last_login_at timestamp with time zone,
    deactivated_at timestamp with time zone,
    seller_type public.seller_type,
    approves_prices boolean DEFAULT false NOT NULL,
    approves_assignments boolean DEFAULT false NOT NULL,
    phone text,
    job_title text,
    gmail_enabled boolean DEFAULT false NOT NULL,
    mobile text,
    linkedin_url text,
    CONSTRAINT app_user_deactivated_check CHECK (((status = 'deaktivovany'::public.user_status) = (deactivated_at IS NOT NULL))),
    CONSTRAINT app_user_email_check CHECK ((email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'::text)),
    CONSTRAINT app_user_job_title_check CHECK (((job_title IS NULL) OR (length(job_title) <= 80))),
    CONSTRAINT app_user_linkedin_url_check CHECK (((linkedin_url IS NULL) OR (linkedin_url ~ '^https://([a-z]{2,3}\.)?linkedin\.com/[A-Za-z0-9_/%.-]{1,200}$'::text))),
    CONSTRAINT app_user_mobile_check CHECK (((mobile IS NULL) OR (length(mobile) <= 40))),
    CONSTRAINT app_user_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT app_user_phone_check CHECK (((phone IS NULL) OR (length(phone) <= 40)))
);


--
-- Name: COLUMN app_user.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.status IS 'pozvany → aktivny pri prvom prihlásení (app_user_login); deaktivovany iba cez app_user_deactivate';


--
-- Name: COLUMN app_user.is_admin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.is_admin IS 'smie meniť Nastavenia; prihlásenie vyplýva z e-mailu (@greenlogy.com = Google, inak kód e-mailom)';


--
-- Name: COLUMN app_user.last_login_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.last_login_at IS 'posledné prihlásenie; nezapisuje sa do auditu';


--
-- Name: COLUMN app_user.seller_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.seller_type IS 'typ predajcu: obchodník / manažér (minimálny aditív a cena pre obchodníka); NULL = nepredáva';


--
-- Name: COLUMN app_user.approves_prices; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.approves_prices IS '„schvaľuje ceny“ (CEO, obchodný riaditeľ): výnimky z ceny, cenové parametre; nezávisle od tímu vidí všetky zmluvy a maržu firmy';


--
-- Name: COLUMN app_user.approves_assignments; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.approves_assignments IS 'schvaľuje pridelenie firmy (Peter Kalman, Daniel Dérer, Denis Kalman)';


--
-- Name: COLUMN app_user.phone; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.phone IS 'telefón obchodníka do ponuky („Cenovú ponuku spracoval“) – 0039';


--
-- Name: COLUMN app_user.gmail_enabled; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_user.gmail_enabled IS 'pilot: e-maily z CRM cez Gmail zo schránky používateľa (zapína admin postupne) – 0042';


--
-- Name: app_user_org; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user_org (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    org_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE app_user_org; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.app_user_org IS 'prístup používateľa k spoločnostiam; tím s all_orgs vidí všetky bez ohľadu na túto tabuľku';


--
-- Name: approval_price_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_price_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    approval_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    year smallint NOT NULL,
    price_model public.price_model NOT NULL,
    voltage_group text NOT NULL,
    requested_value numeric(12,4) NOT NULL,
    threshold_value numeric(12,4) NOT NULL,
    approved_value numeric(12,4),
    volume_mwh numeric(12,3),
    threshold_source text NOT NULL,
    scope jsonb NOT NULL,
    CONSTRAINT approval_price_item_threshold_source_check CHECK ((threshold_source = ANY (ARRAY['cena_pre_obchodnika'::text, 'odhad_portfolia'::text, 'min_aditiv'::text]))),
    CONSTRAINT approval_price_item_voltage_group_check CHECK ((voltage_group = ANY (ARRAY['nn'::text, 'vn'::text, 'vsetko'::text])))
);


--
-- Name: COLUMN approval_price_item.threshold_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.approval_price_item.threshold_source IS 'odkiaľ je hranica; odhad portfólia vidí iba crm_sees_portfolio() (0038)';


--
-- Name: COLUMN approval_price_item.scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.approval_price_item.scope IS 'rozsah variantu pri žiadosti (offer_variant_scope) – výnimka platí, kým sa nezmení (0038)';


--
-- Name: approval_request; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.approval_request (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    kind public.approval_kind NOT NULL,
    deal_id uuid,
    company_id uuid,
    from_owner_id uuid,
    reason text NOT NULL,
    requested_by uuid NOT NULL,
    status public.approval_status DEFAULT 'caka'::public.approval_status NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone,
    decision_note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    offer_id uuid,
    valid_until timestamp with time zone,
    requested_valid_until timestamp with time zone,
    risk_snapshot jsonb,
    penalty_eur_mwh numeric(12,2),
    CONSTRAINT approval_request_assign_check CHECK (((kind <> 'pridelenie_firmy'::public.approval_kind) OR ((company_id IS NOT NULL) AND (from_owner_id IS NOT NULL)))),
    CONSTRAINT approval_request_decided_check CHECK (((status = ANY (ARRAY['schvalena'::public.approval_status, 'zamietnuta'::public.approval_status])) = (decided_at IS NOT NULL))),
    CONSTRAINT approval_request_offer_check CHECK (
CASE kind
    WHEN 'vynimka_ceny'::public.approval_kind THEN ((offer_id IS NOT NULL) AND (deal_id IS NOT NULL))
    WHEN 'predlzenie_platnosti'::public.approval_kind THEN ((offer_id IS NOT NULL) AND (deal_id IS NOT NULL) AND (requested_valid_until IS NOT NULL))
    WHEN 'rizikovy_zakaznik'::public.approval_kind THEN ((deal_id IS NOT NULL) AND (company_id IS NOT NULL) AND (risk_snapshot IS NOT NULL))
    ELSE true
END),
    CONSTRAINT approval_request_penalty_eur_mwh_check CHECK (((penalty_eur_mwh IS NULL) OR (penalty_eur_mwh >= (0)::numeric))),
    CONSTRAINT approval_request_reason_check CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT approval_request_self_check CHECK (((decided_by IS NULL) OR (decided_by <> requested_by)))
);


--
-- Name: TABLE approval_request; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.approval_request IS 'schvaľovanie: výnimka z ceny, rizikový zákazník, predĺženie platnosti, pridelenie firmy (obrazovka 39)';


--
-- Name: COLUMN approval_request.valid_until; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.approval_request.valid_until IS 'výnimka z ceny platí 3 dni na odoslanie, schválenie rizika 30 dní (časť 1.8, odpoveď 9)';


--
-- Name: COLUMN approval_request.penalty_eur_mwh; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.approval_request.penalty_eur_mwh IS 'výnimka z ceny: žiadaná zmluvná pokuta pod predvolenou hodnotou šablóny (schvaľuje sa spolu, platí 3 dni) – 0040';


--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    table_name text NOT NULL,
    record_id uuid NOT NULL,
    action public.audit_action NOT NULL,
    changed_by uuid,
    changed_at timestamp with time zone DEFAULT now() NOT NULL,
    diff jsonb NOT NULL,
    source public.audit_source DEFAULT 'system'::public.audit_source NOT NULL,
    import_id uuid,
    contract_import_id uuid
);


--
-- Name: COLUMN audit_log.changed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.changed_by IS 'app_user.id z current_setting(''app.user_id''); NULL pri synchronizácii a údržbe';


--
-- Name: COLUMN audit_log.diff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce, vlastné polia ako custom.<kľúč>; delete: pôvodný riadok';


--
-- Name: COLUMN audit_log.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.source IS 'aplikacia = prihlásený používateľ; system = údržba alebo výpočet CRM; synchronizacia = rola crm_sync. API môže prepísať cez SET LOCAL app.change_source';


--
-- Name: COLUMN audit_log.import_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.import_id IS 'zmena urobená importom z Excelu (API nastaví SET LOCAL app.import_id); zdroj = import';


--
-- Name: COLUMN audit_log.contract_import_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.contract_import_id IS 'zmena urobená importom zmlúv / XM Trade (app.contract_import_id); zdroj = import';


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: business_calendar; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.business_calendar (
    date date NOT NULL,
    is_working_day boolean NOT NULL,
    work_from time without time zone,
    work_to time without time zone,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    org_id uuid NOT NULL,
    CONSTRAINT business_calendar_hours_check CHECK (((is_working_day AND (work_from IS NOT NULL) AND (work_to IS NOT NULL) AND (work_to > work_from)) OR ((NOT is_working_day) AND (work_from IS NULL) AND (work_to IS NULL))))
);


--
-- Name: TABLE business_calendar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.business_calendar IS 'pracovné dni a čas pre výpočet SLA, podľa spoločnosti; prepočítava sa z org_work_hours a org_day_off';


--
-- Name: call; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.call (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    activity_id uuid NOT NULL,
    cloudtalk_call_id text,
    duration_s integer,
    recording_url text,
    transcript text,
    agent_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT call_duration_s_check CHECK ((duration_s >= 0))
);


--
-- Name: campaign; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.campaign (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    channel text,
    brevo_campaign_id text,
    sent_at timestamp with time zone,
    stats jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: commission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    user_id uuid NOT NULL,
    base_eur numeric(12,2),
    amount_eur numeric(12,2),
    period date,
    status public.commission_status DEFAULT 'vypocitana'::public.commission_status NOT NULL,
    pdf_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN commission.period; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.commission.period IS 'prvý deň obdobia (mesiaca), za ktoré sa provízia vypláca';


--
-- Name: commission_rule; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.commission_rule (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid,
    pipeline_id uuid,
    segment text,
    rate_type text NOT NULL,
    rate_value numeric(12,4) NOT NULL,
    valid_from date NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT commission_rule_target_check CHECK ((num_nonnulls(product_id, pipeline_id) >= 1))
);


--
-- Name: company_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    is_main_contact boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN company_contact.roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company_contact.roles IS 'roly osoby vo firme, kódy z číselníka rola_kontaktu (aj viac naraz)';


--
-- Name: consent; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.consent (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contact_id uuid NOT NULL,
    purpose public.consent_purpose NOT NULL,
    status public.consent_status NOT NULL,
    legal_basis text,
    source text,
    recorded_at timestamp with time zone NOT NULL,
    hubspot_subscription_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    title text,
    email text,
    phone text,
    mobile text,
    "position" text,
    address text,
    source text,
    campaign text,
    owner_id uuid,
    hubspot_id text,
    posthog_distinct_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    phone_norm text GENERATED ALWAYS AS (public.normalize_phone(phone)) STORED,
    mobile_norm text GENERATED ALWAYS AS (public.normalize_phone(mobile)) STORED,
    is_household boolean NOT NULL,
    status public.customer_status,
    status_source public.status_source,
    status_changed_at timestamp with time zone,
    is_former_customer boolean DEFAULT false NOT NULL,
    is_producer boolean DEFAULT false NOT NULL,
    marketing_opt_out_at timestamp with time zone,
    marketing_opt_out_source text,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid DEFAULT public.crm_default_org() NOT NULL,
    op_person_id uuid,
    created_by_import uuid,
    salutation text,
    address_form text,
    CONSTRAINT contact_address_form_check CHECK ((address_form = ANY (ARRAY['pan'::text, 'pani'::text]))),
    CONSTRAINT contact_email_format_check CHECK ((email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'::text)),
    CONSTRAINT contact_marketing_opt_out_check CHECK (((marketing_opt_out_at IS NULL) = (marketing_opt_out_source IS NULL))),
    CONSTRAINT contact_name_check CHECK (((btrim(first_name) <> ''::text) AND (btrim(last_name) <> ''::text))),
    CONSTRAINT contact_reachable_check CHECK (((num_nonnulls(NULLIF(btrim(email), ''::text), NULLIF(btrim(phone), ''::text), NULLIF(btrim(mobile), ''::text)) >= 1) OR (created_by_import IS NOT NULL))),
    CONSTRAINT contact_salutation_check CHECK (((salutation IS NULL) OR (length(salutation) <= 200))),
    CONSTRAINT contact_status_source_check CHECK (((status IS NULL) = (status_source IS NULL)))
);


--
-- Name: COLUMN contact.source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.source IS 'zdroj kontaktu, kód z číselníka zdroj_kontaktu';


--
-- Name: COLUMN contact.is_household; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.is_household IS 'osoba je zákazník za domácnosť (aj marketingový kontakt bez firmy); false = iba kontakt vo firme; automaticky sa nikdy nezruší';


--
-- Name: COLUMN contact.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.status IS 'stav zákazníka (čl. 4 zadania); NULL, ak osoba nie je domácnosť';


--
-- Name: COLUMN contact.marketing_opt_out_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.marketing_opt_out_at IS '„nechce marketing“ od (čl. 8); plné súhlasy prídu v module Marketing';


--
-- Name: COLUMN contact.marketing_opt_out_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.marketing_opt_out_source IS 'zdroj „nechce marketing“, napr. hubspot, brevo, telefon, email';


--
-- Name: COLUMN contact.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN contact.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.org_id IS 'spoločnosť skupiny; osoba vo dvoch spoločnostiach = dva záznamy (Peter 12. 10.)';


--
-- Name: COLUMN contact.op_person_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.op_person_id IS 'Osoba_ID zákazníka v Office portáli (párovanie domácností pri importe zmlúv)';


--
-- Name: COLUMN contact.created_by_import; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.created_by_import IS 'založený importom zmlúv; zruší prvá ručná úprava alebo „Skontrolované“';


--
-- Name: COLUMN contact.salutation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.salutation IS 'vlastné oslovenie v e-maile (má prednosť pred pán / pani), napr. „Ahoj Pavol“; prázdne = podľa address_form – 0042, 0044';


--
-- Name: COLUMN contact.address_form; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contact.address_form IS 'oslovenie v e-maile: pan / pani / NULL = neuvádzať („Dobrý deň“); vyberá obchodník – 0044';


--
-- Name: deal_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    is_primary boolean DEFAULT false NOT NULL
);


--
-- Name: COLUMN deal_contact.roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal_contact.roles IS 'kódy z číselníka rola_kontaktu';


--
-- Name: COLUMN deal_contact.is_primary; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal_contact.is_primary IS 'primárny kontakt = predvolená kontaktná osoba ponuky';


--
-- Name: deal_oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    planned_vt_mwh numeric(12,3),
    planned_nt_mwh numeric(12,3),
    planned_feed_in_mwh numeric(12,3),
    source_power_kw numeric(12,3),
    org_id uuid NOT NULL,
    CONSTRAINT deal_oom_planned_feed_in_mwh_check CHECK ((planned_feed_in_mwh >= (0)::numeric)),
    CONSTRAINT deal_oom_planned_nt_mwh_check CHECK ((planned_nt_mwh >= (0)::numeric)),
    CONSTRAINT deal_oom_planned_vt_mwh_check CHECK ((planned_vt_mwh >= (0)::numeric)),
    CONSTRAINT deal_oom_source_power_kw_check CHECK ((source_power_kw >= (0)::numeric))
);


--
-- Name: COLUMN deal_oom.planned_vt_mwh; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal_oom.planned_vt_mwh IS 'odhad ročnej spotreby VT pre ponuku (predvyplní sa z OOM, XM Trade neprepisuje)';


--
-- Name: oom_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    source public.oom_contact_source DEFAULT 'rucne'::public.oom_contact_source NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE oom_contact; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_contact IS 'kontaktné osoby pri OOM; rucne = pridal používateľ, zmluva = prenesené zo zmluvy (modul 4), ručné sa pri zmene zmluvy neodoberajú';


--
-- Name: COLUMN oom_contact.roles; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_contact.roles IS 'kódy z číselníka rola_pri_oom (aj viac naraz)';


--
-- Name: contact_oom_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contact_oom_v WITH (security_invoker='true') AS
 WITH links AS (
         SELECT oc_1.contact_id,
            oc_1.oom_id,
            NULL::uuid AS deal_id,
            (oc_1.source)::text AS source
           FROM public.oom_contact oc_1
        UNION ALL
         SELECT dc.contact_id,
            dom.oom_id,
            dc.deal_id,
            'deal'::text
           FROM (public.deal_contact dc
             JOIN public.deal_oom dom ON ((dom.deal_id = dc.deal_id)))
        )
 SELECT l.contact_id,
    l.oom_id,
    o.status AS oom_status,
    COALESCE(array_agg(DISTINCT l.deal_id) FILTER (WHERE (l.deal_id IS NOT NULL)), '{}'::uuid[]) AS deal_ids,
    COALESCE(max(oc.roles), '{}'::text[]) AS roles,
    array_agg(DISTINCT l.source ORDER BY l.source) AS sources
   FROM ((links l
     JOIN public.oom o ON ((o.id = l.oom_id)))
     LEFT JOIN public.oom_contact oc ON (((oc.oom_id = l.oom_id) AND (oc.contact_id = l.contact_id))))
  WHERE (o.status = ANY (ARRAY['aktivne'::public.oom_status, 'pripravovane'::public.oom_status]))
  GROUP BY l.contact_id, l.oom_id, o.status;


--
-- Name: VIEW contact_oom_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.contact_oom_v IS 'osoba ↔ OOM: sources = rucne, zmluva (oom_contact) a deal (osoba na deale s OOM); iba Aktívne a Pripravované';


--
-- Name: contact_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contact_v WITH (security_invoker='true') AS
 SELECT p.id,
    p.first_name,
    p.last_name,
    p.title,
    p.email,
    p.phone,
    p.mobile,
    p."position",
    p.address,
    p.source,
    p.campaign,
    p.owner_id,
    p.hubspot_id,
    p.posthog_distinct_id,
    p.created_at,
    p.updated_at,
    p.phone_norm,
    p.mobile_norm,
    p.is_household,
    p.status,
    p.status_source,
    p.status_changed_at,
    p.is_former_customer,
    p.is_producer,
    p.marketing_opt_out_at,
    p.marketing_opt_out_source,
    p.custom,
    p.org_id,
    x.archived,
    ((NOT x.archived) AND (p.marketing_opt_out_at IS NULL)) AS marketing_allowed
   FROM (public.contact p
     CROSS JOIN LATERAL ( SELECT ((NOT (p.is_household AND (p.status IS DISTINCT FROM 'zruseny_zakaznik'::public.customer_status))) AND (NOT (EXISTS ( SELECT 1
                   FROM (public.company_contact cc
                     JOIN public.company c ON ((c.id = cc.company_id)))
                  WHERE ((cc.contact_id = p.id) AND (NOT public.company_is_archived(c.*)))))) AND (p.is_household OR (EXISTS ( SELECT 1
                   FROM public.company_contact cc
                  WHERE (cc.contact_id = p.id))))) AS archived) x);


--
-- Name: VIEW contact_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';


--
-- Name: contract_flag; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_flag (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    code public.contract_flag_code NOT NULL,
    year smallint,
    detail text,
    raised_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_at timestamp with time zone,
    resolved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    resolved_note text
);


--
-- Name: TABLE contract_flag; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_flag IS 'príznaky zmluvy na kontrolu (pod hranicou, chýba cena, sprolongované bez ceny, končí, import)';


--
-- Name: COLUMN contract_flag.resolved_note; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_flag.resolved_note IS 'poznámka pri ručnom uzavretí (napr. Servis potvrdil produkt prolongácie)';


--
-- Name: contract_import; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_import (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid,
    op_file_name text,
    op_file_hash text,
    xm_file_name text,
    xm_file_hash text,
    counts jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_import_file_check CHECK (((op_file_name IS NOT NULL) OR (xm_file_name IS NOT NULL)))
);


--
-- Name: TABLE contract_import; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_import IS 'import zmlúv (Office portal) a OOM (XM Trade): kto, kedy, súbory (názov, odtlačok) a počty; súbory sa neukladajú';


--
-- Name: COLUMN contract_import.user_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_import.user_id IS 'kto import uložil; NULL = systém (servisný prístup)';


--
-- Name: contract_import_change; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_import_change (
    import_id uuid NOT NULL,
    contract_id uuid NOT NULL,
    action text NOT NULL,
    summary text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_import_change_action_check CHECK ((action = ANY (ARRAY['nova'::text, 'zmena'::text])))
);


--
-- Name: TABLE contract_import_change; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_import_change IS 'história importov na karte zmluvy: čo import zmenil (bez osobných údajov)';


--
-- Name: contract_price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    oom_id uuid,
    org_id uuid NOT NULL,
    slot text NOT NULL,
    product_id uuid NOT NULL,
    price_model public.price_model NOT NULL,
    price_list_item_id uuid,
    valid_from date NOT NULL,
    valid_to date,
    price_vt_eur_mwh numeric(12,4),
    price_nt_eur_mwh numeric(12,4),
    additive_eur_mwh numeric(12,4),
    additive_pct numeric(7,4),
    fee_eur_month numeric(12,4),
    fee_kw_eur_month numeric(12,4),
    vat_rate numeric(5,2),
    op_product_name text,
    source text DEFAULT 'import'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_price_fee_eur_month_check CHECK ((fee_eur_month >= (0)::numeric)),
    CONSTRAINT contract_price_fee_kw_eur_month_check CHECK ((fee_kw_eur_month >= (0)::numeric)),
    CONSTRAINT contract_price_list_check CHECK (((price_model = 'cennik'::public.price_model) = (price_list_item_id IS NOT NULL))),
    CONSTRAINT contract_price_model_check CHECK (
CASE price_model
    WHEN 'fix'::public.price_model THEN (price_vt_eur_mwh IS NOT NULL)
    WHEN 'spot_plus_eur'::public.price_model THEN (additive_eur_mwh IS NOT NULL)
    WHEN 'spot_minus_eur'::public.price_model THEN (additive_eur_mwh IS NOT NULL)
    WHEN 'spot_minus_pct'::public.price_model THEN (additive_pct IS NOT NULL)
    WHEN 'cena_diela'::public.price_model THEN false
    ELSE true
END),
    CONSTRAINT contract_price_oom_check CHECK (((oom_id IS NULL) = (slot = 'viwa_ucet'::text))),
    CONSTRAINT contract_price_period_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT contract_price_price_nt_eur_mwh_check CHECK ((price_nt_eur_mwh >= (0)::numeric)),
    CONSTRAINT contract_price_price_vt_eur_mwh_check CHECK ((price_vt_eur_mwh >= (0)::numeric)),
    CONSTRAINT contract_price_slot_check CHECK ((slot = ANY (ARRAY['komodita'::text, 'poplatok_om'::text, 'zem'::text, 'program'::text, 'viwa_ucet'::text, 'viwa_kw'::text]))),
    CONSTRAINT contract_price_source_check CHECK ((source = ANY (ARRAY['import'::text, 'prolongacia'::text, 'cennik_prechod'::text, 'regulacia'::text, 'crm'::text])))
);


--
-- Name: TABLE contract_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.contract_price IS 'cena zmluvy: zložka (slot) × produkt × OOM (VIWA účet bez OOM) × obdobie; cenníková cena je kópia položky schválenej verzie';


--
-- Name: COLUMN contract_price.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.valid_to IS 'NULL = bez konca (napr. výkup na neurčito)';


--
-- Name: COLUMN contract_price.fee_eur_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.fee_eur_month IS 'mesačná platba (za OM, ZEM, program, VIWA účet) bez DPH';


--
-- Name: contract_purchase; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_purchase (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    product_code text NOT NULL,
    delivery_year smallint NOT NULL,
    priced_on date NOT NULL,
    price_eur_mwh numeric(12,4) NOT NULL,
    cockpit_ref text,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_purchase_delivery_year_check CHECK (((delivery_year >= 2000) AND (delivery_year <= 2100)))
);


--
-- Name: COLUMN contract_purchase.product_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.product_code IS 'produkt nákupu, napr. SK BL CAL2027';


--
-- Name: COLUMN contract_purchase.priced_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.priced_on IS 'dátum nákupu (HubSpot: close date dealu / dátum nákupnej ceny)';


--
-- Name: COLUMN contract_purchase.cockpit_ref; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.cockpit_ref IS 'odkaz na nákupnú tranžu v Cockpite; môže sa opakovať pri viacerých zmluvách';


--
-- Name: COLUMN contract_purchase.hubspot_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_purchase.hubspot_id IS 'záznam Nákupné ceny 2-22997964; jeden záznam patrí viacerým zmluvám';


--
-- Name: contract_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contract_v WITH (security_invoker='true') AS
 SELECT k.id,
    k.deal_id,
    k.company_id,
    k.person_id,
    k.number,
    k.segment,
    k.auto_prolong,
    k.valid_from,
    k.valid_to,
    k.payment_terms_days,
    k.consumption_tolerance,
    k.advance_payment_pct,
    k.hubspot_deal_id,
    k.created_at,
    k.updated_at,
    k.custom,
    k.org_id,
    k.op_id,
    k.type,
    k.phase,
    k.signed_on,
    k.crm_valid_to,
    k.small_business,
    k.list_price,
    k.viwa_package,
    k.close_reason,
    k.owner_id,
    k.created_by_name,
    k.previous_contract_id,
    k.related_contract_id,
    k.note,
    k.op_updated_at,
    public.contract_state(k.*) AS state,
    public.contract_effective_to(k.*) AS effective_to,
        CASE
            WHEN (k.company_id IS NOT NULL) THEN 'company'::text
            ELSE 'person'::text
        END AS customer_kind,
    COALESCE(c.name, NULLIF(concat_ws(' '::text, p.first_name, p.last_name), ''::text)) AS customer_name,
    u.name AS owner_name,
    ( SELECT (count(*))::integer AS count
           FROM public.contract_oom co
          WHERE (co.contract_id = k.id)) AS oom_count,
    ( SELECT sum((co.qty_vt_mwh + co.qty_nt_mwh)) AS sum
           FROM public.contract_oom co
          WHERE (co.contract_id = k.id)) AS qty_mwh,
    COALESCE(( SELECT array_agg(DISTINCT (f.code)::text) AS array_agg
           FROM public.contract_flag f
          WHERE ((f.contract_id = k.id) AND (f.resolved_at IS NULL))), '{}'::text[]) AS flags
   FROM (((public.contract k
     LEFT JOIN public.company c ON ((c.id = k.company_id)))
     LEFT JOIN public.contact p ON ((p.id = k.person_id)))
     LEFT JOIN public.app_user u ON ((u.id = k.owner_id)));


--
-- Name: VIEW contract_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.contract_v IS 'zmluva so stavom, skutočným koncom, zákazníkom, obchodníkom, počtom OOM, ročným množstvom a príznakmi';


--
-- Name: conversation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conversation (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    chatwoot_conversation_id bigint,
    channel public.conversation_channel NOT NULL,
    contact_id uuid,
    company_id uuid,
    oom_id uuid,
    product text,
    quality_standard text,
    status text,
    opened_at timestamp with time zone NOT NULL,
    first_response_at timestamp with time zone,
    resolved_at timestamp with time zone,
    assignee_id uuid,
    rating smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN conversation.quality_standard; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.conversation.quality_standard IS 'regulačný štandard kvality';


--
-- Name: custom_field_option; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_option (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    field_id uuid NOT NULL,
    label text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hidden_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_option_label_check CHECK ((btrim(label) <> ''::text))
);


--
-- Name: TABLE custom_field_option; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.custom_field_option IS 'hodnoty výberu; v custom sa ukladá id (premenovanie nič nerozbije); nemaže sa, iba skryje';


--
-- Name: custom_field_section; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_section (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    entity public.crm_entity NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT custom_field_section_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: custom_field_team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.custom_field_team (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    field_id uuid NOT NULL,
    team_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE custom_field_team; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.custom_field_team IS 'tímy, ktoré smú pole meniť (pri edit_access = vybrane_timy)';


--
-- Name: oom_customer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_customer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    company_id uuid,
    person_id uuid,
    org_id uuid NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    status public.oom_status NOT NULL,
    end_reason public.oom_link_end_reason,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_customer_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT oom_customer_period_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from))),
    CONSTRAINT oom_customer_status_check CHECK (
CASE
    WHEN (valid_to IS NULL) THEN ((end_reason IS NULL) AND (status = ANY (ARRAY['pripravovane'::public.oom_status, 'aktivne'::public.oom_status])))
    ELSE ((end_reason IS NOT NULL) AND (status =
    CASE end_reason
        WHEN 'odchod'::public.oom_link_end_reason THEN 'odidene'::public.oom_status
        WHEN 'zrusenie'::public.oom_link_end_reason THEN 'zrusene'::public.oom_status
        WHEN 'prepis'::public.oom_link_end_reason THEN 'prepisane'::public.oom_status
        ELSE NULL::public.oom_status
    END))
END)
);


--
-- Name: TABLE oom_customer; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_customer IS 'komu OOM patrilo v ktorom období a v akom stave (zadanie OOM čl. 3–4); odchod, zrušenie a prepis väzbu uzavrú, prepis a návrat založia novú';


--
-- Name: COLUMN oom_customer.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_customer.valid_to IS 'NULL = väzba trvá (Pripravované alebo Aktívne)';


--
-- Name: COLUMN oom_customer.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_customer.status IS 'stav OOM pre tohto zákazníka v tomto období';


--
-- Name: customer_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_v WITH (security_invoker='true') AS
 WITH oom_sum AS (
         SELECT l.company_id,
            l.person_id,
            count(*) AS active_oom_count,
            sum((COALESCE(o.planned_consumption_vt_mwh, (0)::numeric) + COALESCE(o.planned_consumption_nt_mwh, (0)::numeric))) AS annual_mwh
           FROM (public.oom_customer l
             JOIN public.oom o ON ((o.id = l.oom_id)))
          WHERE ((l.valid_to IS NULL) AND (l.status = 'aktivne'::public.oom_status))
          GROUP BY l.company_id, l.person_id
        ), last_activity AS (
         SELECT a.company_id,
            a.contact_id,
            max(a.occurred_at) AS last_activity_at
           FROM public.activity a
          GROUP BY a.company_id, a.contact_id
        )
 SELECT c.id,
    'B2B'::text AS customer_type,
    c.id AS company_id,
    NULL::uuid AS person_id,
    c.name,
    c.ico,
    NULL::text AS email,
    c.status,
    c.status_source,
    c.is_former_customer,
    c.is_producer,
        CASE
            WHEN c.is_producer THEN 'Firma · výrobca'::text
            ELSE 'Firma'::text
        END AS segment_label,
    c.owner_id,
    COALESCE(s.active_oom_count, (0)::bigint) AS active_oom_count,
    COALESCE(s.annual_mwh, (0)::numeric) AS annual_mwh,
    ( SELECT max(la.last_activity_at) AS max
           FROM last_activity la
          WHERE (la.company_id = c.id)) AS last_activity_at,
    public.company_is_archived(c.*) AS archived,
    c.org_id,
    c.country
   FROM (public.company c
     LEFT JOIN oom_sum s ON ((s.company_id = c.id)))
  WHERE c.is_customer
UNION ALL
 SELECT p.id,
    'B2C'::text AS customer_type,
    NULL::uuid AS company_id,
    p.id AS person_id,
    concat_ws(' '::text, p.first_name, p.last_name) AS name,
    NULL::text AS ico,
    p.email,
    p.status,
    p.status_source,
    p.is_former_customer,
    p.is_producer,
        CASE
            WHEN p.is_producer THEN 'Domácnosť · výrobca'::text
            ELSE 'Domácnosť'::text
        END AS segment_label,
    p.owner_id,
    COALESCE(s.active_oom_count, (0)::bigint) AS active_oom_count,
    COALESCE(s.annual_mwh, (0)::numeric) AS annual_mwh,
    ( SELECT max(la.last_activity_at) AS max
           FROM last_activity la
          WHERE (la.contact_id = p.id)) AS last_activity_at,
    (NOT (p.status IS DISTINCT FROM 'zruseny_zakaznik'::public.customer_status)) AS archived,
    p.org_id,
    NULL::public.country_code AS country
   FROM (public.contact p
     LEFT JOIN oom_sum s ON ((s.person_id = p.id)))
  WHERE (p.is_household AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR (p.owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))));


--
-- Name: VIEW customer_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.customer_v IS 'zoznam Zákazníci: firmy s is_customer a osoby s is_household; archived = zrušený zákazník';


--
-- Name: deal; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid,
    person_id uuid,
    pipeline_id uuid NOT NULL,
    stage_id uuid NOT NULL,
    name text NOT NULL,
    segment public.customer_segment,
    expected_close date,
    closed_at timestamp with time zone,
    owner_id uuid NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    custom jsonb DEFAULT '{}'::jsonb NOT NULL,
    org_id uuid NOT NULL,
    source_code text NOT NULL,
    lost_reason_code text,
    lost_note text,
    supply_start date,
    next_step text,
    next_step_on date,
    next_step_notified_on date,
    previous_contract_id uuid,
    estimated_value_eur numeric(12,2),
    stage_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    note text,
    accepted_variant_id uuid,
    CONSTRAINT deal_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT deal_estimated_value_check CHECK ((estimated_value_eur >= (0)::numeric)),
    CONSTRAINT deal_lost_note_check CHECK (((lost_note IS NULL) OR (btrim(lost_note) <> ''::text))),
    CONSTRAINT deal_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT deal_next_step_check CHECK (((next_step IS NULL) OR (btrim(next_step) <> ''::text)))
);


--
-- Name: COLUMN deal.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN deal.closed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.closed_at IS 'vstup do Vyhraté / Prehraté; NULL = otvorený obchod (nastavuje databáza)';


--
-- Name: COLUMN deal.custom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.custom IS 'vlastné polia z Nastavení: {kľúč poľa: hodnota}';


--
-- Name: COLUMN deal.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.org_id IS 'preberá sa od zákazníka';


--
-- Name: COLUMN deal.source_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.source_code IS 'zdroj obchodu (číselník zdroj_obchodu)';


--
-- Name: COLUMN deal.lost_reason_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.lost_reason_code IS 'dôvod prehry (číselník dovod_prehry), iba v štádiu Prehraté';


--
-- Name: COLUMN deal.next_step_notified_on; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.next_step_notified_on IS 'deň kroku, za ktorý už odišlo upozornenie (nočný beh)';


--
-- Name: COLUMN deal.previous_contract_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.previous_contract_id IS 'predošlá zmluva (obnova)';


--
-- Name: COLUMN deal.estimated_value_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.estimated_value_eur IS 'odhad pridanej hodnoty pred prvou ponukou';


--
-- Name: COLUMN deal.accepted_variant_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.accepted_variant_id IS 'akceptovaný variant ponuky (nastaví akceptácia, F3)';


--
-- Name: deal_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    org_id uuid NOT NULL,
    kind text NOT NULL,
    occurred_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid,
    from_stage_id uuid,
    to_stage_id uuid,
    oom_id uuid,
    contact_id uuid,
    detail jsonb DEFAULT '{}'::jsonb NOT NULL,
    reason text,
    offer_id uuid,
    CONSTRAINT deal_event_kind_check CHECK ((kind = ANY (ARRAY['zalozenie'::text, 'stadium'::text, 'vlastnik'::text, 'znovuotvorenie'::text, 'oom_pridane'::text, 'oom_odobrane'::text, 'oom_zrusene'::text, 'oom_nezrusene'::text, 'kontakt_pridany'::text, 'kontakt_odobrany'::text, 'zakaznik_vlastnik'::text, 'ponuka_nova'::text, 'ponuka_verzia'::text, 'ponuka_prepocitana'::text, 'ponuka_odoslana'::text, 'ponuka_zamietnuta'::text, 'ponuka_platnost'::text, 'schvalenie_ziadost'::text, 'schvalenie_rozhodnutie'::text, 'ponuka_akceptovana'::text, 'ponuka_zablokovana'::text, 'ponuka_otvorena'::text, 'ponuka_odkaz'::text, 'akceptacia_zrusena'::text, 'ponuka_odblokovana'::text, 'potvrdenie_neodoslane'::text])))
);


--
-- Name: TABLE deal_event; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.deal_event IS 'časová os obchodu: udalosti, ktoré nie sú poznámka ani e-mail; zapisujú ich iba spúšťače, nemení sa';


--
-- Name: doc_counter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.doc_counter (
    org_id uuid NOT NULL,
    kind text NOT NULL,
    year smallint NOT NULL,
    last_value integer DEFAULT 0 NOT NULL,
    CONSTRAINT doc_counter_kind_check CHECK ((kind = ANY (ARRAY['ponuka'::text, 'provizny_list'::text]))),
    CONSTRAINT doc_counter_last_value_check CHECK ((last_value >= 0))
);


--
-- Name: TABLE doc_counter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.doc_counter IS 'počítadlá čísel dokladov po spoločnosti, druhu a roku (od 1 každý rok)';


--
-- Name: email_outbox; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_outbox (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    notification_id uuid,
    user_id uuid NOT NULL,
    kind text NOT NULL,
    deal_id uuid,
    approval_id uuid,
    detail text,
    status text DEFAULT 'v_rade'::text NOT NULL,
    send_key uuid,
    attempts smallint DEFAULT 0 NOT NULL,
    sending_started_at timestamp with time zone,
    gmail_message_id text,
    sent_at timestamp with time zone,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT email_outbox_check CHECK (((status <> 'odosiela_sa'::text) OR (send_key IS NOT NULL))),
    CONSTRAINT email_outbox_check1 CHECK (((status <> 'odoslany'::text) OR (gmail_message_id IS NOT NULL))),
    CONSTRAINT email_outbox_gmail_message_id_check CHECK (((gmail_message_id IS NULL) OR (gmail_message_id ~ '^[0-9a-f]{6,32}$'::text))),
    CONSTRAINT email_outbox_kind_check CHECK ((kind = ANY (ARRAY['schvalenie_nove'::text, 'schvalenie_rozhodnutie'::text, 'ponuka_akceptovana'::text]))),
    CONSTRAINT email_outbox_status_check CHECK ((status = ANY (ARRAY['v_rade'::text, 'odosiela_sa'::text, 'odoslany'::text, 'chyba'::text])))
);


--
-- Name: TABLE email_outbox; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_outbox IS 'interné e-maily z crm@greenlogy.com podľa upozornení (bez osobných údajov zákazníkov) – 0042';


--
-- Name: email_thread; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.email_thread (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    mailbox_user_id uuid,
    gmail_thread_id text,
    deal_id uuid,
    company_id uuid,
    person_id uuid,
    offer_id uuid,
    subject text DEFAULT ''::text NOT NULL,
    watch_until date,
    last_message_at timestamp with time zone,
    last_checked_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT email_thread_check CHECK (((deal_id IS NOT NULL) OR (company_id IS NOT NULL) OR (person_id IS NOT NULL))),
    CONSTRAINT email_thread_gmail_thread_id_check CHECK (((gmail_thread_id IS NULL) OR (gmail_thread_id ~ '^[0-9a-f]{6,32}$'::text)))
);


--
-- Name: TABLE email_thread; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.email_thread IS 'vlákno e-mailov CRM v jednej schránke (mailbox_user_id NULL = crm@greenlogy.com); odpovede sa kontrolujú iba vo vláknach s watch_until ≥ dnes (aktivita za 30 dní) – 0042';


--
-- Name: export_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.export_log (
    id bigint NOT NULL,
    user_id uuid,
    module public.crm_module NOT NULL,
    filter jsonb DEFAULT '{}'::jsonb NOT NULL,
    row_count integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT export_log_row_count_check CHECK ((row_count >= 0))
);


--
-- Name: TABLE export_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.export_log IS 'kto, kedy a čo exportoval (bez samotných údajov)';


--
-- Name: export_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.export_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.export_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: finstat_cache; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finstat_cache (
    kind text NOT NULL,
    key text NOT NULL,
    fetched_at timestamp with time zone DEFAULT now() NOT NULL,
    data jsonb NOT NULL,
    CONSTRAINT finstat_cache_key_check CHECK (((length(key) >= 1) AND (length(key) <= 200))),
    CONSTRAINT finstat_cache_kind_check CHECK ((kind = ANY (ARRAY['detail'::text, 'autocomplete'::text])))
);


--
-- Name: TABLE finstat_cache; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.finstat_cache IS 'odpovede Finstatu 24 h (môžu obsahovať mená štatutárov); záznamy staršie ako 7 dní sa mažú pri zápise';


--
-- Name: finstat_usage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.finstat_usage (
    day date NOT NULL,
    requests integer DEFAULT 0 NOT NULL,
    CONSTRAINT finstat_usage_requests_check CHECK ((requests >= 0))
);


--
-- Name: TABLE finstat_usage; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.finstat_usage IS 'počet požiadaviek na Finstat za deň (Europe/Bratislava)';


--
-- Name: fve_project; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fve_project (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    program public.fve_program,
    price_with_vat numeric(12,2),
    vat_rate numeric(5,2),
    advance_eur numeric(12,2),
    status public.fve_status,
    partner_commission_pct numeric(5,2),
    partner_name text,
    discount_savings_eur numeric(12,2),
    nep_settlement_eur numeric(12,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN fve_project.vat_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.vat_rate IS 'sadzba DPH v % (napr. 23.00)';


--
-- Name: COLUMN fve_project.partner_commission_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.partner_commission_pct IS 'provízia v % zo základu (HubSpot provizia_v__)';


--
-- Name: COLUMN fve_project.partner_name; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.partner_name IS 'obchodník NEP; ak je vyplnený, Greenlogy má polovicu provízie (HubSpot obchodnik_nep)';


--
-- Name: COLUMN fve_project.discount_savings_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.discount_savings_eur IS 'úspora na zľave, max. 1 500 € s DPH (HubSpot uspora_na_zlave__max__1500_eur_)';


--
-- Name: COLUMN fve_project.nep_settlement_eur; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.fve_project.nep_settlement_eur IS 'doúčtovanie z NEPu (HubSpot douctovanie_z_nepu)';


--
-- Name: gmail_mailbox_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gmail_mailbox_state (
    mailbox text NOT NULL,
    consecutive_errors smallint DEFAULT 0 NOT NULL,
    last_error text,
    last_error_at timestamp with time zone,
    last_ok_at timestamp with time zone,
    alerted_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT gmail_mailbox_state_mailbox_check CHECK (((mailbox = 'crm'::text) OR (mailbox ~ '^[0-9a-f-]{36}$'::text)))
);


--
-- Name: TABLE gmail_mailbox_state; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.gmail_mailbox_state IS 'stav schránky pre Gmail API: crm = crm@greenlogy.com, inak ID používateľa – 0042';


--
-- Name: job_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job text NOT NULL,
    run_date date NOT NULL,
    test_date boolean DEFAULT false NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    result jsonb DEFAULT '{}'::jsonb NOT NULL,
    errors jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT job_run_errors_check CHECK ((jsonb_typeof(errors) = 'array'::text)),
    CONSTRAINT job_run_job_check CHECK ((job = ANY (ARRAY['zmluvy'::text, 'obchody'::text])))
);


--
-- Name: TABLE job_run; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.job_run IS 'denník nočných behov: počty po krokoch, spätne zapísaný cenník a chyby (zmluva, krok, kód, text bez osobných údajov); číta admin a Nákup';


--
-- Name: COLUMN job_run.test_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.job_run.test_date IS 'ručný beh s iným ako dnešným dátumom (Test)';


--
-- Name: lookup_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lookup_list (
    code text NOT NULL,
    name text NOT NULL,
    used_on text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_list text,
    CONSTRAINT lookup_list_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,62}$'::text))
);


--
-- Name: TABLE lookup_list; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.lookup_list IS 'zoznamy číselníkov; zakladá ich iba migrácia (jadro)';


--
-- Name: COLUMN lookup_list.parent_list; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_list.parent_list IS 'zoznam nadradených hodnôt (napr. sadzby distribúcie → pds)';


--
-- Name: lookup_value; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lookup_value (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    list_code text NOT NULL,
    code text NOT NULL,
    label text NOT NULL,
    org_id uuid,
    sort_order integer DEFAULT 0 NOT NULL,
    is_system boolean DEFAULT false NOT NULL,
    hidden_at timestamp with time zone,
    hubspot_value text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    parent_code text,
    reg_no text,
    CONSTRAINT lookup_value_code_check CHECK ((code ~ '^[a-z0-9][a-z0-9_]{0,62}$'::text)),
    CONSTRAINT lookup_value_label_check CHECK ((btrim(label) <> ''::text)),
    CONSTRAINT lookup_value_reg_no_check CHECK ((reg_no ~ '^[0-9]{8}$'::text)),
    CONSTRAINT lookup_value_system_visible_check CHECK ((NOT (is_system AND (hidden_at IS NOT NULL))))
);


--
-- Name: COLUMN lookup_value.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.code IS 'kľúč, ktorým odkazujú záznamy; vznikne z názvu, nikdy sa nemení';


--
-- Name: COLUMN lookup_value.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN lookup_value.is_system; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.is_system IS 'hodnota, na ktorej stojí logika: nedá sa skryť ani premenovať (zakladá iba migrácia)';


--
-- Name: COLUMN lookup_value.hidden_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.hidden_at IS 'skrytá hodnota sa nedá vybrať pri novom zadaní, staré záznamy ju zobrazujú ďalej';


--
-- Name: COLUMN lookup_value.parent_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.parent_code IS 'kód nadradenej hodnoty zo zoznamu lookup_list.parent_list; nemení sa';


--
-- Name: COLUMN lookup_value.reg_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.lookup_value.reg_no IS 'IČO (pri PDS – prevádzkovateľ distribučnej sústavy)';


--
-- Name: mailbox_access_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mailbox_access_log (
    id bigint NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid,
    mailbox_user_id uuid NOT NULL,
    method text NOT NULL,
    gmail_thread_id text NOT NULL,
    gmail_message_id text,
    thread_id uuid NOT NULL,
    format text NOT NULL,
    CONSTRAINT mailbox_access_log_format_check CHECK ((format = ANY (ARRAY['minimal'::text, 'metadata'::text, 'full'::text]))),
    CONSTRAINT mailbox_access_log_method_check CHECK ((method = ANY (ARRAY['threads.get'::text, 'messages.get'::text])))
);


--
-- Name: TABLE mailbox_access_log; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.mailbox_access_log IS 'každé čítanie schránky cez Gmail API (user_id NULL = beh na pozadí); iba pridávanie – 0042';


--
-- Name: mailbox_access_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mailbox_access_log ALTER COLUMN id ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME public.mailbox_access_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: market_price_daily; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_price_daily (
    org_id uuid NOT NULL,
    on_date date NOT NULL,
    delivery_year smallint NOT NULL,
    bl_eur_mwh numeric(12,4),
    pl_eur_mwh numeric(12,4),
    portfolio_eur_mwh numeric(12,4),
    spot_fve_eur_mwh numeric(12,4),
    source text DEFAULT 'rucne'::text NOT NULL,
    changed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    corrected_at timestamp with time zone,
    corrected_by uuid,
    CONSTRAINT market_price_corrected_check CHECK (((corrected_by IS NULL) OR (corrected_at IS NOT NULL))),
    CONSTRAINT market_price_daily_bl_eur_mwh_check CHECK ((bl_eur_mwh >= (0)::numeric)),
    CONSTRAINT market_price_daily_check CHECK ((num_nonnulls(bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh) >= 1)),
    CONSTRAINT market_price_daily_check1 CHECK (((bl_eur_mwh IS NULL) = (pl_eur_mwh IS NULL))),
    CONSTRAINT market_price_daily_delivery_year_check CHECK (((delivery_year >= 2000) AND (delivery_year <= 2100))),
    CONSTRAINT market_price_daily_pl_eur_mwh_check CHECK ((pl_eur_mwh >= (0)::numeric)),
    CONSTRAINT market_price_daily_portfolio_eur_mwh_check CHECK ((portfolio_eur_mwh >= (0)::numeric)),
    CONSTRAINT market_price_daily_source_check CHECK ((source = ANY (ARRAY['cockpit'::text, 'rucne'::text, 'historia'::text]))),
    CONSTRAINT market_price_daily_spot_fve_eur_mwh_check CHECK ((spot_fve_eur_mwh >= (0)::numeric))
);


--
-- Name: TABLE market_price_daily; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.market_price_daily IS 'ceny BL/PL (CAL), odhad nákupnej ceny portfólia a očakávaná cena SPOT pre FVE podľa dňa a roka dodávky';


--
-- Name: COLUMN market_price_daily.corrected_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.market_price_daily.corrected_at IS 'záznam opravený novším záznamom toho istého dňa (platí najnovší); NULL = platný';


--
-- Name: market_price_history_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.market_price_history_v WITH (security_invoker='true') AS
 SELECT m.id,
    m.org_id,
    m.on_date,
    m.delivery_year,
    m.bl_eur_mwh,
    m.pl_eur_mwh,
    m.portfolio_eur_mwh,
    m.spot_fve_eur_mwh,
    m.source,
    m.created_at,
    m.changed_by,
    cu.name AS changed_by_name,
    m.corrected_at,
    m.corrected_by,
    ku.name AS corrected_by_name,
    (m.corrected_at IS NOT NULL) AS is_corrected
   FROM ((public.market_price_daily m
     LEFT JOIN public.app_user cu ON ((cu.id = m.changed_by)))
     LEFT JOIN public.app_user ku ON ((ku.id = m.corrected_by)));


--
-- Name: VIEW market_price_history_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.market_price_history_v IS 'trhové ceny dňa s opravami (opravený záznam ostáva v histórii)';


--
-- Name: notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notification (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    kind text NOT NULL,
    contract_id uuid,
    price_exception_id uuid,
    job_run_id uuid,
    ref_date date,
    detail text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    read_at timestamp with time zone,
    deal_id uuid,
    approval_id uuid,
    CONSTRAINT notification_kind_check CHECK ((kind = ANY (ARRAY['konci_4_mesiace'::text, 'sprolongovana'::text, 'neprolongovana'::text, 'pod_hranicou'::text, 'vynimka_nova'::text, 'vynimka_rozhodnutie'::text, 'nocny_beh_chyba'::text, 'maly_podnik'::text, 'objem_xm'::text, 'dalsi_krok'::text, 'schvalenie_nove'::text, 'schvalenie_rozhodnutie'::text, 'pridelenie_firmy'::text, 'ponuka_akceptovana'::text, 'ponuka_zablokovana'::text, 'akceptacia_zrusena'::text, 'ponuka_odpoved'::text, 'ponuka_pripomienka'::text, 'gmail_chyba'::text, 'email_chyba'::text])))
);


--
-- Name: TABLE notification; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.notification IS 'upozornenia v CRM (zvonček); bez auditu; detail bez osobných údajov (číslo zmluvy, rok, dátum)';


--
-- Name: COLUMN notification.ref_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.notification.ref_date IS 'konci_4_mesiace, sprolongovana, neprolongovana: koniec zmluvy, ku ktorému upozornenie patrí (posiela sa raz)';


--
-- Name: offer_acceptance; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_acceptance (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id uuid NOT NULL,
    variant_id uuid NOT NULL,
    org_id uuid NOT NULL,
    method text NOT NULL,
    channel text,
    accepted_at timestamp with time zone NOT NULL,
    signer_name text NOT NULL,
    signer_function text NOT NULL,
    ip inet,
    user_agent text,
    terms_text text NOT NULL,
    terms_sha256 text NOT NULL,
    offer_pdf_sha256 text,
    signed_file_key text,
    note text,
    recorded_by uuid,
    revoked_at timestamp with time zone,
    revoked_by uuid,
    revoke_reason text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    confirmation_pdf_key text,
    confirmation_pdf_sha256 text,
    send_confirmation boolean DEFAULT true NOT NULL,
    CONSTRAINT offer_acceptance_channel_check CHECK ((channel = ANY (ARRAY['telefon'::text, 'email'::text, 'osobne'::text, 'podpisane_pdf'::text]))),
    CONSTRAINT offer_acceptance_check CHECK (((method = 'klik'::text) = (ip IS NOT NULL))),
    CONSTRAINT offer_acceptance_check1 CHECK (((method = 'rucne'::text) = ((channel IS NOT NULL) AND (recorded_by IS NOT NULL)))),
    CONSTRAINT offer_acceptance_check2 CHECK (((signed_file_key IS NULL) OR (method = 'rucne'::text))),
    CONSTRAINT offer_acceptance_check3 CHECK ((((revoked_at IS NULL) = (revoked_by IS NULL)) AND ((revoked_at IS NULL) = (revoke_reason IS NULL)))),
    CONSTRAINT offer_acceptance_confirmation_check CHECK (((confirmation_pdf_key IS NULL) = (confirmation_pdf_sha256 IS NULL))),
    CONSTRAINT offer_acceptance_confirmation_pdf_sha256_check CHECK (((confirmation_pdf_sha256 IS NULL) OR (confirmation_pdf_sha256 ~ '^[0-9a-f]{64}$'::text))),
    CONSTRAINT offer_acceptance_method_check CHECK ((method = ANY (ARRAY['klik'::text, 'rucne'::text]))),
    CONSTRAINT offer_acceptance_note_check CHECK (((note IS NULL) OR (length(note) <= 2000))),
    CONSTRAINT offer_acceptance_signer_function_check CHECK (((btrim(signer_function) <> ''::text) AND (length(signer_function) <= 200))),
    CONSTRAINT offer_acceptance_signer_name_check CHECK (((btrim(signer_name) <> ''::text) AND (length(signer_name) <= 200))),
    CONSTRAINT offer_acceptance_terms_sha256_check CHECK ((terms_sha256 ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT offer_acceptance_user_agent_check CHECK (((user_agent IS NULL) OR (length(user_agent) <= 500)))
);


--
-- Name: TABLE offer_acceptance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_acceptance IS 'akceptácia ponuky – nemení sa; jedinou zmenou je zrušenie adminom s dôvodom (0039)';


--
-- Name: COLUMN offer_acceptance.confirmation_pdf_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer_acceptance.confirmation_pdf_key IS 'R2: potvrdenie akceptácie v PDF uložené v momente akceptácie (nemení sa) – 0041';


--
-- Name: COLUMN offer_acceptance.send_confirmation; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.offer_acceptance.send_confirmation IS 'poslať zákazníkovi potvrdenie e-mailom (ručná akceptácia: voľba obchodníka) – 0042';


--
-- Name: offer_asset; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_asset (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code text NOT NULL,
    mime text NOT NULL,
    data bytea NOT NULL,
    sha256 text NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offer_asset_code_check CHECK ((code = ANY (ARRAY['titulna'::text, 'referencie_zakaznici'::text, 'referencie_partneri'::text, 'energeticky_mix'::text]))),
    CONSTRAINT offer_asset_data_check CHECK ((octet_length(data) <= 1048576)),
    CONSTRAINT offer_asset_mime_check CHECK ((mime = ANY (ARRAY['image/png'::text, 'image/jpeg'::text]))),
    CONSTRAINT offer_asset_sha256_check CHECK ((sha256 ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: TABLE offer_asset; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_asset IS 'obrázky do PDF ponuky; bez auditu (obsahuje binárne dáta) – kto a kedy je v created_by / created_at (0039)';


--
-- Name: offer_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    variant_id uuid NOT NULL,
    oom_id uuid,
    org_id uuid NOT NULL,
    year smallint,
    slot text NOT NULL,
    product_id uuid NOT NULL,
    price_model public.price_model NOT NULL,
    price_list_item_id uuid,
    price_vt_eur_mwh numeric(12,4),
    price_nt_eur_mwh numeric(12,4),
    additive_eur_mwh numeric(12,4),
    additive_pct numeric(7,4),
    fee_eur_month numeric(12,4),
    fee_kw_eur_month numeric(12,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offer_item_check CHECK (((oom_id IS NULL) = (slot = 'viwa_ucet'::text))),
    CONSTRAINT offer_item_check1 CHECK (((price_model = 'cennik'::public.price_model) = (price_list_item_id IS NOT NULL))),
    CONSTRAINT offer_item_check2 CHECK (
CASE price_model
    WHEN 'fix'::public.price_model THEN (price_vt_eur_mwh IS NOT NULL)
    WHEN 'spot_plus_eur'::public.price_model THEN (additive_eur_mwh IS NOT NULL)
    WHEN 'spot_minus_eur'::public.price_model THEN (additive_eur_mwh IS NOT NULL)
    WHEN 'spot_minus_pct'::public.price_model THEN (additive_pct IS NOT NULL)
    ELSE true
END),
    CONSTRAINT offer_item_slot_check CHECK ((slot = ANY (ARRAY['komodita'::text, 'poplatok_om'::text, 'zem'::text, 'program'::text, 'viwa_ucet'::text, 'viwa_kw'::text]))),
    CONSTRAINT offer_item_year_check CHECK (((year IS NULL) OR ((year >= 2020) AND (year <= 2100))))
);


--
-- Name: TABLE offer_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_item IS 'cena zložky (komodita, poplatky, program, VIWA) pre OOM a rok – rovnaké sloty a modely ako contract_price';


--
-- Name: offer_page_stat; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_page_stat (
    offer_id uuid NOT NULL,
    first_opened_at timestamp with time zone NOT NULL,
    last_opened_at timestamp with time zone NOT NULL,
    open_count integer DEFAULT 1 NOT NULL
);


--
-- Name: TABLE offer_page_stat; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.offer_page_stat IS 'otvorenia stránky ponuky zákazníkom – bez IP adries (zadanie 7.3)';


--
-- Name: offer_year_basis; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_year_basis (
    variant_id uuid NOT NULL,
    year smallint NOT NULL,
    seller_type public.seller_type NOT NULL,
    trader_price numeric(12,4),
    portfolio_eur_mwh numeric(12,4),
    min_additive numeric(12,4),
    energopomoc_price numeric(12,4),
    viwa_additive numeric(12,4),
    computed_on date NOT NULL
);


--
-- Name: oom_device; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_device (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    device_type public.device_type NOT NULL,
    brand text,
    model text,
    power_kw numeric(12,3),
    capacity_kwh numeric(12,3),
    count integer DEFAULT 1 NOT NULL,
    details jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_device_count_check CHECK ((count > 0))
);


--
-- Name: oom_import; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_import (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    user_id uuid NOT NULL,
    file_name text NOT NULL,
    row_count integer NOT NULL,
    created_count integer NOT NULL,
    updated_count integer NOT NULL,
    error_count integer NOT NULL,
    status public.oom_import_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_import_counts_check CHECK ((((created_count + updated_count) + error_count) <= row_count)),
    CONSTRAINT oom_import_created_count_check CHECK ((created_count >= 0)),
    CONSTRAINT oom_import_error_count_check CHECK ((error_count >= 0)),
    CONSTRAINT oom_import_file_name_check CHECK ((btrim(file_name) <> ''::text)),
    CONSTRAINT oom_import_row_count_check CHECK ((row_count >= 0)),
    CONSTRAINT oom_import_updated_count_check CHECK ((updated_count >= 0))
);


--
-- Name: TABLE oom_import; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_import IS 'import OOM z Excelu: kto, kedy, súbor a počty (súbor ani náhľad sa neukladajú); zmeny OOM sú v audite s import_id';


--
-- Name: oom_planned_change; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_planned_change (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    org_id uuid NOT NULL,
    kind public.oom_plan_kind NOT NULL,
    effective_date date NOT NULL,
    company_id uuid,
    person_id uuid,
    status public.oom_plan_status DEFAULT 'planovana'::public.oom_plan_status NOT NULL,
    error text,
    created_by uuid,
    executed_at timestamp with time zone,
    cancelled_at timestamp with time zone,
    cancelled_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_plan_customer_check CHECK (
CASE
    WHEN (kind = 'prepis'::public.oom_plan_kind) THEN (num_nonnulls(company_id, person_id) = 1)
    ELSE (num_nonnulls(company_id, person_id) = 0)
END),
    CONSTRAINT oom_plan_error_check CHECK ((((status <> 'zlyhala'::public.oom_plan_status) OR (error IS NOT NULL)) AND ((error IS NULL) OR (status = ANY (ARRAY['zlyhala'::public.oom_plan_status, 'zrusena'::public.oom_plan_status])))))
);


--
-- Name: TABLE oom_planned_change; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_planned_change IS 'plánovaný prepis, odchod alebo zrušenie OOM k budúcemu dátumu; vykoná nočný beh (oom_daily_run)';


--
-- Name: COLUMN oom_planned_change.effective_date; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_planned_change.effective_date IS 'prepis: prvý deň nového odberateľa; odchod a zrušenie: posledný deň dodávky';


--
-- Name: COLUMN oom_planned_change.error; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_planned_change.error IS 'dôvod, prečo sa plán nedal vykonať (status zlyhala)';


--
-- Name: oom_price_regulation_change; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oom_price_regulation_change (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    valid_from date NOT NULL,
    value boolean,
    applied_at timestamp with time zone,
    created_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    prev_value boolean,
    contract_applied_at timestamp with time zone
);


--
-- Name: TABLE oom_price_regulation_change; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.oom_price_regulation_change IS 'história cenovej regulácie OOM s dátumom „platí od“ (časový rez cien zmlúv v 0027)';


--
-- Name: COLUMN oom_price_regulation_change.value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_price_regulation_change.value IS 'true = ANO, false = NIE, NULL = nevyplnené';


--
-- Name: COLUMN oom_price_regulation_change.prev_value; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_price_regulation_change.prev_value IS 'regulácia platná deň pred touto zmenou (zapíše oom_price_regulation_set)';


--
-- Name: COLUMN oom_price_regulation_change.contract_applied_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom_price_regulation_change.contract_applied_at IS 'kedy nočný beh prepočítal ceny zmlúv na OOM (krok 1)';


--
-- Name: org; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    country public.country_code NOT NULL,
    currency character(3) NOT NULL,
    status public.org_status DEFAULT 'pripravuje_sa'::public.org_status NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    timezone text DEFAULT 'Europe/Bratislava'::text NOT NULL,
    legal_name text NOT NULL,
    reg_no text,
    tax_no text,
    vat_no text,
    address text,
    registry_entry text,
    statutory text,
    support_phone text,
    email text,
    web text,
    regulator_license text,
    logo_updated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    oom_switch_accept_days smallint DEFAULT 14 NOT NULL,
    oom_switch_confirm_days smallint DEFAULT 14 NOT NULL,
    CONSTRAINT org_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::text)),
    CONSTRAINT org_currency_check CHECK ((currency ~ '^[A-Z]{3}$'::text)),
    CONSTRAINT org_legal_name_check CHECK ((btrim(legal_name) <> ''::text)),
    CONSTRAINT org_oom_switch_accept_days_check CHECK (((oom_switch_accept_days >= 1) AND (oom_switch_accept_days <= 365))),
    CONSTRAINT org_oom_switch_confirm_days_check CHECK (((oom_switch_confirm_days >= 1) AND (oom_switch_confirm_days <= 365)))
);


--
-- Name: TABLE org; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org IS 'spoločnosti skupiny Greenlogy (nie firmy zákazníkov – tie sú v company)';


--
-- Name: COLUMN org.reg_no; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.reg_no IS 'IČO (SK, CZ) alebo OIB (HR) spoločnosti';


--
-- Name: COLUMN org.regulator_license; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.regulator_license IS 'číslo povolenia regulátora: SK ÚRSO, CZ ERÚ, HR HERA';


--
-- Name: COLUMN org.oom_switch_accept_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.oom_switch_accept_days IS 'prechod sa zasekol: dni od odoslania výpovede bez akceptácie';


--
-- Name: COLUMN org.oom_switch_confirm_days; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org.oom_switch_confirm_days IS 'prechod sa zasekol: dni od akceptácie výpovede bez potvrdenia zmeny dodávateľa';


--
-- Name: oom_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.oom_v WITH (security_invoker='true') AS
 SELECT o.id,
    o.eic,
    o.name,
    o.address_street,
    o.address_number_supisne,
    o.address_number_orientacne,
    o.address_city,
    o.address_zip,
    o.type,
    o.status,
    o.company_id,
    o.person_id,
        CASE
            WHEN (o.company_id IS NOT NULL) THEN 'B2B'::text
            ELSE 'B2C'::text
        END AS customer_type,
    COALESCE(c.name, NULLIF(concat_ws(' '::text, p.first_name, p.last_name), ''::text)) AS customer_name,
    COALESCE(c.owner_id, p.owner_id) AS owner_id,
    u.name AS owner_name,
    o.org_id,
    o.pds,
    pv.label AS pds_label,
    o.pds_tariff,
    tv.label AS pds_tariff_label,
    o.voltage_level,
        CASE
            WHEN (o.type = 'vyroba'::public.oom_type) THEN o.planned_feed_in_mwh
            WHEN ((o.planned_consumption_vt_mwh IS NULL) AND (o.planned_consumption_nt_mwh IS NULL)) THEN NULL::numeric
            ELSE (COALESCE(o.planned_consumption_vt_mwh, (0)::numeric) + COALESCE(o.planned_consumption_nt_mwh, (0)::numeric))
        END AS planned_mwh,
    o.supply_from,
    o.supply_to,
    o.switch_notice_required,
    o.switch_notice_sent_on,
    o.switch_notice_accepted_on,
    o.switch_confirmed_on,
    ((o.status = 'pripravovane'::public.oom_status) AND (((o.switch_notice_sent_on IS NOT NULL) AND (o.switch_notice_accepted_on IS NULL) AND ((o.switch_notice_sent_on + (g.oom_switch_accept_days)::integer) < public.crm_today())) OR ((o.switch_notice_accepted_on IS NOT NULL) AND (o.switch_confirmed_on IS NULL) AND ((o.switch_notice_accepted_on + (g.oom_switch_confirm_days)::integer) < public.crm_today())))) AS switch_stuck,
        CASE
            WHEN (o.status = 'pripravovane'::public.oom_status) THEN public.oom_active_required_missing(o.*)
            ELSE NULL::text[]
        END AS active_missing,
    prev.customer_name AS transferred_from_name,
    (prev.valid_to + 1) AS transferred_on,
    o.custom,
    o.created_at,
    o.updated_at,
    pl.kind AS plan_kind,
    pl.effective_date AS plan_date,
    pl.id AS plan_id,
    (EXISTS ( SELECT 1
           FROM public.oom_planned_change f
          WHERE ((f.oom_id = o.id) AND (f.status = 'zlyhala'::public.oom_plan_status)))) AS plan_failed
   FROM ((((((((public.oom o
     JOIN public.org g ON ((g.id = o.org_id)))
     LEFT JOIN public.company c ON ((c.id = o.company_id)))
     LEFT JOIN public.contact p ON ((p.id = o.person_id)))
     LEFT JOIN public.app_user u ON ((u.id = COALESCE(c.owner_id, p.owner_id))))
     LEFT JOIN public.lookup_value pv ON (((pv.list_code = 'pds'::text) AND (pv.code = o.pds))))
     LEFT JOIN public.lookup_value tv ON (((tv.list_code = 'sadzba_distribucie'::text) AND (tv.code = o.pds_tariff))))
     LEFT JOIN LATERAL ( SELECT COALESCE(pc.name, NULLIF(concat_ws(' '::text, pp.first_name, pp.last_name), ''::text)) AS customer_name,
            l.valid_to
           FROM ((public.oom_customer l
             LEFT JOIN public.company pc ON ((pc.id = l.company_id)))
             LEFT JOIN public.contact pp ON ((pp.id = l.person_id)))
          WHERE ((l.oom_id = o.id) AND (l.end_reason = 'prepis'::public.oom_link_end_reason))
          ORDER BY l.valid_to DESC
         LIMIT 1) prev ON (true))
     LEFT JOIN public.oom_planned_change pl ON (((pl.oom_id = o.id) AND (pl.status = 'planovana'::public.oom_plan_status))));


--
-- Name: VIEW oom_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.oom_v IS 'zoznam OOM (obrazovka 17): zákazník a vlastník poslednej väzby, prechod sa zasekol (lehoty spoločnosti), chýbajúce údaje pre Aktívne, prepis od';


--
-- Name: org_bank_account; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_bank_account (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    iban text NOT NULL,
    bic text,
    bank_name text,
    purposes public.bank_account_purpose[] DEFAULT '{}'::public.bank_account_purpose[] NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_bank_account_iban_check CHECK ((iban ~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$'::text))
);


--
-- Name: COLUMN org_bank_account.iban; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.org_bank_account.iban IS 'IBAN bez medzier, veľkými písmenami (upraví spúšťač)';


--
-- Name: org_day_off; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_day_off (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    date date NOT NULL,
    kind public.day_off_kind NOT NULL,
    name text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_day_off_name_check CHECK ((btrim(name) <> ''::text))
);


--
-- Name: TABLE org_day_off; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org_day_off IS 'štátne sviatky (iba migráciou, podľa zákona krajiny) a firemné voľno (admin)';


--
-- Name: org_logo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_logo (
    org_id uuid NOT NULL,
    mime text NOT NULL,
    data bytea NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_logo_data_check CHECK ((octet_length(data) <= 524288)),
    CONSTRAINT org_logo_mime_check CHECK ((mime = ANY (ARRAY['image/svg+xml'::text, 'image/png'::text])))
);


--
-- Name: org_work_hours; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.org_work_hours (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    weekday smallint NOT NULL,
    work_from time without time zone NOT NULL,
    work_to time without time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT org_work_hours_check CHECK ((work_to > work_from)),
    CONSTRAINT org_work_hours_weekday_check CHECK (((weekday >= 1) AND (weekday <= 7)))
);


--
-- Name: TABLE org_work_hours; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.org_work_hours IS 'týždenný pracovný čas spoločnosti; deň bez riadku = voľno; 1 = pondelok';


--
-- Name: pipeline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    org_id uuid,
    kind public.deal_kind NOT NULL,
    archived_at timestamp with time zone
);


--
-- Name: COLUMN pipeline.org_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline.org_id IS 'NULL = celá skupina';


--
-- Name: COLUMN pipeline.kind; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline.kind IS 'druh obchodu (jadro), názov pipeline sa meniť dá';


--
-- Name: pipeline_stage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_stage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pipeline_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    probability numeric(3,2),
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    outcome public.stage_outcome DEFAULT 'otvoreny'::public.stage_outcome NOT NULL,
    archived_at timestamp with time zone,
    is_closed boolean GENERATED ALWAYS AS ((outcome <> 'otvoreny'::public.stage_outcome)) STORED,
    is_won boolean GENERATED ALWAYS AS ((outcome = 'vyhrany'::public.stage_outcome)) STORED,
    code public.deal_stage_code,
    CONSTRAINT pipeline_stage_code_outcome_check CHECK (
CASE code
    WHEN 'vyhrane'::public.deal_stage_code THEN (outcome = 'vyhrany'::public.stage_outcome)
    WHEN 'prehrane'::public.deal_stage_code THEN (outcome = 'prehrany'::public.stage_outcome)
    ELSE (outcome = 'otvoreny'::public.stage_outcome)
END),
    CONSTRAINT pipeline_stage_probability_check CHECK (((probability >= (0)::numeric) AND (probability <= (1)::numeric)))
);


--
-- Name: COLUMN pipeline_stage.outcome; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage.outcome IS 'typ stage: otvorený / vyhraný / prehraný';


--
-- Name: COLUMN pipeline_stage.is_closed; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage.is_closed IS 'vypočítané z outcome (pre staršie dopyty)';


--
-- Name: COLUMN pipeline_stage.code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage.code IS 'systémový kód štádia (logika obchodu); NULL = medzistupeň pridaný adminom';


--
-- Name: pipeline_stage_required_field; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_stage_required_field (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    stage_id uuid NOT NULL,
    core_field text,
    custom_field_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pipeline_stage_required_field_core_field_check CHECK ((core_field ~ '^[a-z][a-z0-9_]{1,62}$'::text)),
    CONSTRAINT pipeline_stage_required_field_one_check CHECK (((core_field IS NULL) <> (custom_field_id IS NULL)))
);


--
-- Name: COLUMN pipeline_stage_required_field.core_field; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.pipeline_stage_required_field.core_field IS 'pole jadra dealu zo zoznamu v kóde (napr. lost_reason)';


--
-- Name: price_exception; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_exception (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    company_id uuid,
    person_id uuid,
    years smallint[] NOT NULL,
    price_model public.price_model NOT NULL,
    requested_value numeric(12,4) NOT NULL,
    threshold_value numeric(12,4) NOT NULL,
    volume_mwh numeric(12,3),
    reason text NOT NULL,
    requested_by uuid,
    status public.price_exception_status DEFAULT 'caka'::public.price_exception_status NOT NULL,
    decided_by uuid,
    decided_at timestamp with time zone,
    decision_note text,
    valid_until date,
    contract_id uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_exception_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT price_exception_decided_check CHECK (((status <> 'caka'::public.price_exception_status) = (decided_at IS NOT NULL))),
    CONSTRAINT price_exception_price_model_check CHECK ((price_model = ANY (ARRAY['fix'::public.price_model, 'spot_plus_eur'::public.price_model, 'spot_minus_eur'::public.price_model]))),
    CONSTRAINT price_exception_reason_check CHECK ((btrim(reason) <> ''::text)),
    CONSTRAINT price_exception_used_check CHECK (((status = 'pouzita'::public.price_exception_status) = (contract_id IS NOT NULL))),
    CONSTRAINT price_exception_years_check CHECK ((cardinality(years) >= 1))
);


--
-- Name: TABLE price_exception; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_exception IS 'žiadosť obchodníka o cenu pod hranicou; schvaľuje „schvaľuje ceny“ (nie autor); platí 30 dní na podpis';


--
-- Name: price_exception_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.price_exception_v WITH (security_invoker='true') AS
 SELECT e.id,
    e.org_id,
    e.company_id,
    e.person_id,
    e.years,
    e.price_model,
    e.requested_value,
    e.threshold_value,
    e.volume_mwh,
    e.reason,
    e.requested_by,
    e.status,
    e.decided_by,
    e.decided_at,
    e.decision_note,
    e.valid_until,
    e.contract_id,
    e.created_at,
    e.updated_at,
        CASE
            WHEN ((e.status = 'schvalena'::public.price_exception_status) AND (e.valid_until < public.crm_today())) THEN 'expirovana'::text
            ELSE (e.status)::text
        END AS state,
    COALESCE(c.name, NULLIF(concat_ws(' '::text, p.first_name, p.last_name), ''::text)) AS customer_name,
    ru.name AS requested_by_name,
    du.name AS decided_by_name
   FROM ((((public.price_exception e
     LEFT JOIN public.company c ON ((c.id = e.company_id)))
     LEFT JOIN public.contact p ON ((p.id = e.person_id)))
     LEFT JOIN public.app_user ru ON ((ru.id = e.requested_by)))
     LEFT JOIN public.app_user du ON ((du.id = e.decided_by)));


--
-- Name: VIEW price_exception_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.price_exception_v IS 'výnimky so stavom (aj Expirovaná po 30 dňoch), zákazník, autor, schvaľovateľ';


--
-- Name: price_list; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    segment public.customer_segment NOT NULL,
    description text,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_list_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,60}$'::text)),
    CONSTRAINT price_list_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT price_list_segment_check CHECK ((segment = ANY (ARRAY['domacnost'::public.customer_segment, 'firma'::public.customer_segment])))
);


--
-- Name: TABLE price_list; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_list IS 'cenník (napr. Domácnosti – NIE Energopomoc); zmazať sa dá iba bez schválenej verzie';


--
-- Name: price_list_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list_version (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    price_list_id uuid NOT NULL,
    name text NOT NULL,
    valid_from date NOT NULL,
    valid_to date,
    status public.price_list_version_status DEFAULT 'navrh'::public.price_list_version_status NOT NULL,
    copied_from_id uuid,
    note text,
    approved_at timestamp with time zone,
    approved_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_list_version_approved_check CHECK (((status = 'navrh'::public.price_list_version_status) = (approved_at IS NULL))),
    CONSTRAINT price_list_version_name_check CHECK ((btrim(name) <> ''::text)),
    CONSTRAINT price_list_version_period_check CHECK (((valid_to IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: TABLE price_list_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_list_version IS 'verzia cenníka; schválená sa nemení (iba uzavretie dátumom), oprava = nová verzia';


--
-- Name: COLUMN price_list_version.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_version.valid_to IS 'NULL = do ďalšej verzie; vyplní schválenie nástupcu alebo ukončenie cenníka';


--
-- Name: COLUMN price_list_version.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_version.status IS 'navrh; schvalena; nahradena = budúca schválená verzia nahradená pred účinnosťou';


--
-- Name: COLUMN price_list_version.approved_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_version.approved_by IS 'admin, ktorý schválil; NULL pri skripte naplnenia';


--
-- Name: price_list_current_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.price_list_current_v WITH (security_invoker='true') AS
 SELECT l.id,
    l.org_id,
    l.code,
    l.name,
    l.segment,
    l.description,
    l.sort_order,
    cur.id AS current_version_id,
    cur.name AS current_version_name,
    cur.valid_from AS current_valid_from,
    cur.valid_to AS current_valid_to,
    fut.id AS future_version_id,
    fut.name AS future_version_name,
    fut.valid_from AS future_valid_from,
    dr.id AS draft_version_id,
    dr.name AS draft_version_name,
    dr.valid_from AS draft_valid_from
   FROM (((public.price_list l
     LEFT JOIN LATERAL ( SELECT v.id,
            v.price_list_id,
            v.name,
            v.valid_from,
            v.valid_to,
            v.status,
            v.copied_from_id,
            v.note,
            v.approved_at,
            v.approved_by,
            v.created_at,
            v.updated_at
           FROM public.price_list_version v
          WHERE ((v.price_list_id = l.id) AND (public.price_list_version_state(v.status, v.valid_from, v.valid_to, public.crm_today()) = 'platna'::text))
         LIMIT 1) cur ON (true))
     LEFT JOIN LATERAL ( SELECT v.id,
            v.price_list_id,
            v.name,
            v.valid_from,
            v.valid_to,
            v.status,
            v.copied_from_id,
            v.note,
            v.approved_at,
            v.approved_by,
            v.created_at,
            v.updated_at
           FROM public.price_list_version v
          WHERE ((v.price_list_id = l.id) AND (public.price_list_version_state(v.status, v.valid_from, v.valid_to, public.crm_today()) = 'buduca'::text))
          ORDER BY v.valid_from
         LIMIT 1) fut ON (true))
     LEFT JOIN LATERAL ( SELECT v.id,
            v.price_list_id,
            v.name,
            v.valid_from,
            v.valid_to,
            v.status,
            v.copied_from_id,
            v.note,
            v.approved_at,
            v.approved_by,
            v.created_at,
            v.updated_at
           FROM public.price_list_version v
          WHERE ((v.price_list_id = l.id) AND (v.status = 'navrh'::public.price_list_version_status))
         LIMIT 1) dr ON (true));


--
-- Name: price_list_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    version_id uuid NOT NULL,
    product_id uuid NOT NULL,
    price_vt_eur_mwh numeric(12,4),
    price_nt_eur_mwh numeric(12,4),
    fee_oom_eur_month numeric(12,4),
    fee_program_eur_month numeric(12,4),
    fee_kw_eur_month numeric(12,4),
    vat_rate numeric(5,2),
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_list_item_fee_kw_eur_month_check CHECK ((fee_kw_eur_month >= (0)::numeric)),
    CONSTRAINT price_list_item_fee_oom_eur_month_check CHECK ((fee_oom_eur_month >= (0)::numeric)),
    CONSTRAINT price_list_item_fee_program_eur_month_check CHECK ((fee_program_eur_month >= (0)::numeric)),
    CONSTRAINT price_list_item_nt_check CHECK (((price_nt_eur_mwh IS NULL) OR (price_vt_eur_mwh IS NOT NULL))),
    CONSTRAINT price_list_item_price_check CHECK ((num_nonnulls(price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month, fee_program_eur_month, fee_kw_eur_month) >= 1)),
    CONSTRAINT price_list_item_price_nt_eur_mwh_check CHECK ((price_nt_eur_mwh >= (0)::numeric)),
    CONSTRAINT price_list_item_price_vt_eur_mwh_check CHECK ((price_vt_eur_mwh >= (0)::numeric)),
    CONSTRAINT price_list_item_vat_rate_check CHECK (((vat_rate >= (0)::numeric) AND (vat_rate <= (100)::numeric)))
);


--
-- Name: TABLE price_list_item; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_list_item IS 'položka verzie cenníka: ceny bez DPH na 4 desatinné miesta';


--
-- Name: COLUMN price_list_item.price_vt_eur_mwh; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item.price_vt_eur_mwh IS 'VT (pri jednotarife jediná cena) €/MWh bez DPH';


--
-- Name: COLUMN price_list_item.fee_oom_eur_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item.fee_oom_eur_month IS 'mesačná platba za OM (aj ZEM, poplatok B2B) bez DPH';


--
-- Name: COLUMN price_list_item.fee_program_eur_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item.fee_program_eur_month IS 'mesačný poplatok programu bez DPH: VBattery za OOM; VIWA za účet (nie za OOM)';


--
-- Name: COLUMN price_list_item.fee_kw_eur_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item.fee_kw_eur_month IS 'VIWA: poplatok za odchýlku za kW inštalovaného výkonu mesačne bez DPH';


--
-- Name: COLUMN price_list_item.vat_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item.vat_rate IS 'kópia sadzby DPH produktu pri schválení; v Návrhu NULL (platí DPH produktu)';


--
-- Name: price_list_item_program; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_list_item_program (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    item_id uuid NOT NULL,
    greencar boolean DEFAULT false NOT NULL,
    greencar_kwh_per_voucher integer,
    greencar_voucher_eur numeric(12,2),
    greenshare boolean DEFAULT false NOT NULL,
    greenshare_fee_pct numeric(5,2),
    viwa_conversion_factor numeric(5,4),
    viwa_activation_bonus integer,
    viwa_credit_expiry_months smallint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_list_item_program_greencar_kwh_per_voucher_check CHECK ((greencar_kwh_per_voucher > 0)),
    CONSTRAINT price_list_item_program_greencar_voucher_eur_check CHECK ((greencar_voucher_eur >= (0)::numeric)),
    CONSTRAINT price_list_item_program_greenshare_fee_pct_check CHECK (((greenshare_fee_pct >= (0)::numeric) AND (greenshare_fee_pct <= (100)::numeric))),
    CONSTRAINT price_list_item_program_viwa_activation_bonus_check CHECK ((viwa_activation_bonus >= 0)),
    CONSTRAINT price_list_item_program_viwa_conversion_factor_check CHECK (((viwa_conversion_factor >= (0)::numeric) AND (viwa_conversion_factor <= (1)::numeric))),
    CONSTRAINT price_list_item_program_viwa_credit_expiry_months_check CHECK ((viwa_credit_expiry_months > 0))
);


--
-- Name: TABLE price_list_item_program; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_list_item_program IS 'parametre programu VBattery / VIWA pri položke; pevné pre balík, menia sa iba novou verziou';


--
-- Name: COLUMN price_list_item_program.greencar_kwh_per_voucher; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item_program.greencar_kwh_per_voucher IS 'VBattery: kWh za voucher (PREMIUM 400, MAX 300)';


--
-- Name: COLUMN price_list_item_program.greenshare_fee_pct; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item_program.greenshare_fee_pct IS 'VBattery: poplatok GreenShare v % z prevedených kWh (platí sa v kWh)';


--
-- Name: COLUMN price_list_item_program.viwa_conversion_factor; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.price_list_item_program.viwa_conversion_factor IS 'VIWA: konverzný kurz = SPOT × hodnota';


--
-- Name: price_list_item_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.price_list_item_v WITH (security_invoker='true') AS
 SELECT i.id,
    i.version_id,
    v.price_list_id,
    i.product_id,
    p.code AS product_code,
    p.name AS product_name,
    p.category,
    p.tariff_type,
    p.status AS product_status,
    i.sort_order,
    COALESCE(i.vat_rate, p.vat_rate) AS vat_rate,
    i.price_vt_eur_mwh,
    public.price_with_vat(i.price_vt_eur_mwh, COALESCE(i.vat_rate, p.vat_rate), 4) AS price_vt_with_vat,
    i.price_nt_eur_mwh,
    public.price_with_vat(i.price_nt_eur_mwh, COALESCE(i.vat_rate, p.vat_rate), 4) AS price_nt_with_vat,
    i.fee_oom_eur_month,
    public.price_with_vat(i.fee_oom_eur_month, COALESCE(i.vat_rate, p.vat_rate), 2) AS fee_oom_with_vat,
    i.fee_program_eur_month,
    public.price_with_vat(i.fee_program_eur_month, COALESCE(i.vat_rate, p.vat_rate), 2) AS fee_program_with_vat,
    i.fee_kw_eur_month,
    public.price_with_vat(i.fee_kw_eur_month, COALESCE(i.vat_rate, p.vat_rate), 4) AS fee_kw_with_vat,
    g.greencar,
    g.greencar_kwh_per_voucher,
    g.greencar_voucher_eur,
    g.greenshare,
    g.greenshare_fee_pct,
    g.viwa_conversion_factor,
    g.viwa_activation_bonus,
    g.viwa_credit_expiry_months
   FROM (((public.price_list_item i
     JOIN public.price_list_version v ON ((v.id = i.version_id)))
     JOIN public.product p ON ((p.id = i.product_id)))
     LEFT JOIN public.price_list_item_program g ON ((g.item_id = i.id)));


--
-- Name: price_list_version_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.price_list_version_v WITH (security_invoker='true') AS
 SELECT v.id,
    v.price_list_id,
    l.org_id,
    l.code AS price_list_code,
    l.name AS price_list_name,
    l.segment,
    v.name,
    v.valid_from,
    v.valid_to,
    v.status,
    public.price_list_version_state(v.status, v.valid_from, v.valid_to, public.crm_today()) AS state,
    v.copied_from_id,
    v.note,
    v.approved_at,
    v.approved_by,
    u.name AS approved_by_name,
    ( SELECT count(*) AS count
           FROM public.price_list_item i
          WHERE (i.version_id = v.id)) AS item_count,
    v.created_at,
    v.updated_at
   FROM ((public.price_list_version v
     JOIN public.price_list l ON ((l.id = v.price_list_id)))
     LEFT JOIN public.app_user u ON ((u.id = v.approved_by)));


--
-- Name: price_parameter; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.price_parameter (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    org_id uuid NOT NULL,
    code text NOT NULL,
    delivery_year smallint,
    valid_from date NOT NULL,
    value numeric(12,4) NOT NULL,
    note text,
    changed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT price_parameter_code_check CHECK ((code = ANY (ARRAY['pomer_bl_pct'::text, 'rizikova_prirazka'::text, 'nasa_marza'::text, 'min_aditiv_obchodnik'::text, 'min_aditiv_manazer'::text, 'min_aditiv_vykup_lz'::text, 'nakup_energopomoc'::text, 'viwa_aditiv_basic'::text, 'viwa_aditiv_plus'::text, 'viwa_aditiv_pro'::text, 'min_aditiv_vykup'::text]))),
    CONSTRAINT price_parameter_delivery_year_check CHECK (((delivery_year >= 2000) AND (delivery_year <= 2100))),
    CONSTRAINT price_parameter_ratio_check CHECK (((code <> 'pomer_bl_pct'::text) OR (value <= (100)::numeric))),
    CONSTRAINT price_parameter_value_check CHECK ((value >= (0)::numeric)),
    CONSTRAINT price_parameter_year_check CHECK (((code = 'nakup_energopomoc'::text) = (delivery_year IS NOT NULL)))
);


--
-- Name: TABLE price_parameter; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.price_parameter IS 'cenové parametre s históriou „platí od“ (zadanie modulu 4, časť 6); riadok sa nemení, zmena = nový riadok';


--
-- Name: product_tariff; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product_tariff (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    product_id uuid NOT NULL,
    scope_code text NOT NULL,
    tariff_code text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE product_tariff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.product_tariff IS 'párovanie produkt ↔ sadzba distribúcie v rozsahu PDS (obrazovka 24)';


--
-- Name: COLUMN product_tariff.tariff_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product_tariff.tariff_code IS 'kód sadzby bez PDS, napr. d3, c2_x3 (tariff_base)';


--
-- Name: referral; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.referral (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    referrer_contact_id uuid NOT NULL,
    deal_id uuid,
    discount_eur numeric(12,2),
    reward_eur numeric(12,2),
    reward_type text,
    status text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: segment; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.segment (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    definition jsonb,
    sync_to_brevo boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sla_record; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sla_record (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    conversation_id uuid NOT NULL,
    first_response_due timestamp with time zone NOT NULL,
    first_response_at timestamp with time zone,
    resolution_due timestamp with time zone NOT NULL,
    resolved_at timestamp with time zone,
    first_response_met boolean,
    resolution_met boolean,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: supplier_switch; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.supplier_switch (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    oom_id uuid NOT NULL,
    deal_id uuid,
    message_type public.switch_message_type NOT NULL,
    segment public.switch_segment,
    message_date date,
    effective_date date,
    point_kind text,
    metering_type text,
    customer_notified_at timestamp with time zone,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sync_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sync_run (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    source text NOT NULL,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    records_in integer,
    records_updated integer,
    errors jsonb
);


--
-- Name: tariff_scope; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tariff_scope (
    code text NOT NULL,
    name text NOT NULL,
    pds_code text,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT tariff_scope_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::text))
);


--
-- Name: TABLE tariff_scope; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.tariff_scope IS 'rozsah párovania sadzieb: PDS s vlastným párovaním (pds_code) alebo práve jeden spoločný rozsah (pds_code NULL)';


--
-- Name: COLUMN tariff_scope.pds_code; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.tariff_scope.pds_code IS 'kód z číselníka pds; PDS s vlastným rozsahom nikdy nepoužije spoločné riadky';


--
-- Name: team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    code text NOT NULL,
    description text,
    all_orgs boolean DEFAULT false NOT NULL,
    can_change_owner boolean DEFAULT false NOT NULL,
    is_external boolean DEFAULT false NOT NULL,
    archived_at timestamp with time zone,
    CONSTRAINT team_code_check CHECK ((code ~ '^[a-z][a-z0-9_]{1,40}$'::text)),
    CONSTRAINT team_external_check CHECK ((NOT (is_external AND (all_orgs OR can_change_owner))))
);


--
-- Name: COLUMN team.all_orgs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.all_orgs IS 'tím vidí všetky spoločnosti skupiny (CEO, Nákup, Marketing)';


--
-- Name: COLUMN team.can_change_owner; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.can_change_owner IS 'členovia tímu menia vlastníka (obchodníka) záznamov; okrem nich iba admin';


--
-- Name: COLUMN team.is_external; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team.is_external IS 'externý tím: nikdy nesmie dostať „všetko“ (poistka v databáze)';


--
-- Name: team_permission; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_permission (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    team_id uuid NOT NULL,
    module public.crm_module NOT NULL,
    view_scope public.access_scope DEFAULT 'nic'::public.access_scope NOT NULL,
    edit_scope public.access_scope DEFAULT 'nic'::public.access_scope NOT NULL,
    can_archive boolean DEFAULT false NOT NULL,
    can_export boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    can_import boolean DEFAULT false NOT NULL,
    can_edit_active_oom boolean DEFAULT false NOT NULL,
    can_see_company_margin boolean DEFAULT false NOT NULL,
    CONSTRAINT team_permission_edit_active_oom_check CHECK (((NOT can_edit_active_oom) OR (module = 'odberne_miesta'::public.crm_module))),
    CONSTRAINT team_permission_edit_le_view_check CHECK ((edit_scope <= view_scope)),
    CONSTRAINT team_permission_margin_check CHECK (((NOT can_see_company_margin) OR (module = 'zmluvy'::public.crm_module)))
);


--
-- Name: TABLE team_permission; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.team_permission IS 'práva tímu po moduloch; „iba svoje“ = záznamy, kde je používateľ vlastníkom';


--
-- Name: COLUMN team_permission.can_import; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_permission.can_import IS 'smie hromadne importovať záznamy modulu (dnes OOM z Excelu)';


--
-- Name: COLUMN team_permission.can_edit_active_oom; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_permission.can_edit_active_oom IS 'iba modul odberne_miesta: smie upravovať OOM v stave Aktívne, jeho zariadenia a kontaktné osoby';


--
-- Name: COLUMN team_permission.can_see_company_margin; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.team_permission.can_see_company_margin IS 'vidieť maržu firmy, nákupnú cenu portfólia a rizikovú prirážku (iba modul zmluvy)';


--
-- Name: trader_price_today_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.trader_price_today_v WITH (security_invoker='true') AS
 SELECT org_id,
    delivery_year,
    on_date,
    bl_eur_mwh,
    pl_eur_mwh,
    public.price_param(org_id, 'pomer_bl_pct'::text, public.crm_today()) AS bl_ratio_pct,
    round((((bl_eur_mwh * public.price_param(org_id, 'pomer_bl_pct'::text, public.crm_today())) + (pl_eur_mwh * ((100)::numeric - public.price_param(org_id, 'pomer_bl_pct'::text, public.crm_today())))) / (100)::numeric), 4) AS mix_eur_mwh,
    public.price_param(org_id, 'rizikova_prirazka'::text, public.crm_today()) AS risk_eur_mwh,
    public.price_param(org_id, 'nasa_marza'::text, public.crm_today()) AS margin_eur_mwh,
    public.trader_price(org_id, delivery_year, public.crm_today()) AS trader_price_eur_mwh,
    portfolio_eur_mwh,
    spot_fve_eur_mwh,
    source,
    id
   FROM public.market_price_daily m
  WHERE ((corrected_at IS NULL) AND (on_date = ( SELECT max(x.on_date) AS max
           FROM public.market_price_daily x
          WHERE ((x.org_id = m.org_id) AND (x.delivery_year = m.delivery_year) AND (x.on_date <= public.crm_today()) AND (x.corrected_at IS NULL)))));


--
-- Name: VIEW trader_price_today_v; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.trader_price_today_v IS 'obrazovka 29: posledné ceny BL/PL po rokoch dodávky a cena pre obchodníka dnes';


--
-- Name: user_commission_rate; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_commission_rate (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    valid_from date NOT NULL,
    pct numeric(5,2) NOT NULL,
    changed_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_commission_rate_pct_check CHECK (((pct >= (0)::numeric) AND (pct <= (100)::numeric)))
);


--
-- Name: TABLE user_commission_rate; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_commission_rate IS 'percento provízie obchodníka z pridanej hodnoty, platí od dátumu; bez záznamu 40 %';


--
-- Name: user_photo; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_photo (
    user_id uuid NOT NULL,
    mime text NOT NULL,
    data bytea NOT NULL,
    sha256 text NOT NULL,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_photo_data_check CHECK ((octet_length(data) <= 307200)),
    CONSTRAINT user_photo_mime_check CHECK ((mime = ANY (ARRAY['image/jpeg'::text, 'image/png'::text]))),
    CONSTRAINT user_photo_sha256_check CHECK ((sha256 ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: TABLE user_photo; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_photo IS 'fotka do podpisu e-mailu (štvorec, do 300 kB) – bez auditu, kto a kedy je v updated_by / updated_at (0042)';


--
-- Name: user_signature; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_signature (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    mode text DEFAULT 'profil'::text NOT NULL,
    html text,
    text_version text,
    updated_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_signature_check CHECK (((mode = 'profil'::text) OR ((html IS NOT NULL) AND (btrim(html) <> ''::text)))),
    CONSTRAINT user_signature_html_check CHECK (((html IS NULL) OR ((length(html) <= 100000) AND (html !~* '<\s*/?\s*(script|iframe|frame|object|embed|applet|form|input|button|textarea|select|meta|link|base|style|svg|math|video|audio|source)\M'::text) AND (html !~* '\son[a-z]+\s*='::text) AND (html !~* '(javascript|vbscript|data)\s*:'::text) AND (html !~* 'url\s*\('::text) AND (html !~* 'expression\s*\('::text) AND (html !~* '\ssrc\s*=\s*["'']?(?!["'']|cid:)'::text)))),
    CONSTRAINT user_signature_mode_check CHECK ((mode = ANY (ARRAY['profil'::text, 'vlastny'::text]))),
    CONSTRAINT user_signature_text_version_check CHECK (((text_version IS NULL) OR (length(text_version) <= 20000)))
);


--
-- Name: TABLE user_signature; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_signature IS 'podpis e-mailu: z profilu alebo vlastný HTML (vyčistený; obrázky iba cid: z user_signature_image) – 0044';


--
-- Name: user_signature_image; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_signature_image (
    user_id uuid NOT NULL,
    cid text NOT NULL,
    mime text NOT NULL,
    data bytea NOT NULL,
    sha256 text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_signature_image_cid_check CHECK ((cid ~ '^sig[1-5]$'::text)),
    CONSTRAINT user_signature_image_data_check CHECK ((octet_length(data) <= 307200)),
    CONSTRAINT user_signature_image_mime_check CHECK ((mime = ANY (ARRAY['image/png'::text, 'image/jpeg'::text, 'image/gif'::text]))),
    CONSTRAINT user_signature_image_sha256_check CHECK ((sha256 ~ '^[0-9a-f]{64}$'::text))
);


--
-- Name: TABLE user_signature_image; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_signature_image IS 'obrázky vlastného podpisu (najviac 5, do 300 kB) – v e-maile ako vložené prílohy cid:, bez načítania zvonka – 0044';


--
-- Name: voucher; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.voucher (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid,
    contact_id uuid,
    code text,
    value_eur numeric(12,2),
    sent_at timestamp with time zone,
    redeemed boolean DEFAULT false NOT NULL,
    status text,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: web_event; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_event (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contact_id uuid,
    posthog_distinct_id text,
    event text NOT NULL,
    url text,
    occurred_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: activity activity_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_pkey PRIMARY KEY (id);


--
-- Name: activity activity_source_source_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_source_source_id_key UNIQUE (source, source_id);


--
-- Name: app_setting app_setting_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_setting
    ADD CONSTRAINT app_setting_id_key UNIQUE (id);


--
-- Name: app_setting app_setting_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_setting
    ADD CONSTRAINT app_setting_pkey PRIMARY KEY (key);


--
-- Name: app_user app_user_hubspot_owner_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_hubspot_owner_id_key UNIQUE (hubspot_owner_id);


--
-- Name: app_user_org app_user_org_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_pkey PRIMARY KEY (id);


--
-- Name: app_user_org app_user_org_user_id_org_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_user_id_org_id_key UNIQUE (user_id, org_id);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: approval_price_item approval_price_item_approval_id_variant_id_year_price_model_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_price_item
    ADD CONSTRAINT approval_price_item_approval_id_variant_id_year_price_model_key UNIQUE (approval_id, variant_id, year, price_model, voltage_group);


--
-- Name: approval_price_item approval_price_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_price_item
    ADD CONSTRAINT approval_price_item_pkey PRIMARY KEY (id);


--
-- Name: approval_request approval_request_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: business_calendar business_calendar_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_calendar
    ADD CONSTRAINT business_calendar_pkey PRIMARY KEY (org_id, date);


--
-- Name: call call_activity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_activity_id_key UNIQUE (activity_id);


--
-- Name: call call_cloudtalk_call_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_cloudtalk_call_id_key UNIQUE (cloudtalk_call_id);


--
-- Name: call call_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_pkey PRIMARY KEY (id);


--
-- Name: campaign campaign_brevo_campaign_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_brevo_campaign_id_key UNIQUE (brevo_campaign_id);


--
-- Name: campaign campaign_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.campaign
    ADD CONSTRAINT campaign_pkey PRIMARY KEY (id);


--
-- Name: commission commission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_pkey PRIMARY KEY (id);


--
-- Name: commission_rule commission_rule_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_pkey PRIMARY KEY (id);


--
-- Name: company_contact company_contact_company_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_company_id_contact_id_key UNIQUE (company_id, contact_id);


--
-- Name: company_contact company_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_pkey PRIMARY KEY (id);


--
-- Name: company company_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: company company_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_pkey PRIMARY KEY (id);


--
-- Name: consent consent_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent
    ADD CONSTRAINT consent_pkey PRIMARY KEY (id);


--
-- Name: contact contact_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: contact contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_pkey PRIMARY KEY (id);


--
-- Name: contract contract_deal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_deal_id_key UNIQUE (deal_id);


--
-- Name: contract_flag contract_flag_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_flag
    ADD CONSTRAINT contract_flag_pkey PRIMARY KEY (id);


--
-- Name: contract contract_hubspot_deal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_hubspot_deal_id_key UNIQUE (hubspot_deal_id);


--
-- Name: contract_import_change contract_import_change_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import_change
    ADD CONSTRAINT contract_import_change_pkey PRIMARY KEY (import_id, contract_id);


--
-- Name: contract_import contract_import_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import
    ADD CONSTRAINT contract_import_pkey PRIMARY KEY (id);


--
-- Name: contract contract_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_number_key UNIQUE (number);


--
-- Name: contract_oom contract_oom_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_overlap EXCLUDE USING gist (oom_id WITH =, grp WITH =, daterange(valid_from, valid_to, '[]'::text) WITH &&) WHERE ((is_binding AND (valid_from IS NOT NULL) AND ((valid_to IS NULL) OR (valid_to >= valid_from))));


--
-- Name: contract_oom contract_oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_pkey PRIMARY KEY (id);


--
-- Name: contract_oom contract_oom_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_unique UNIQUE (contract_id, oom_id);


--
-- Name: contract contract_op_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_op_id_key UNIQUE (op_id);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: contract_price contract_price_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_overlap EXCLUDE USING gist (contract_id WITH =, COALESCE(oom_id, '00000000-0000-0000-0000-000000000000'::uuid) WITH =, slot WITH =, daterange(valid_from, valid_to, '[]'::text) WITH &&);


--
-- Name: contract_price contract_price_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_pkey PRIMARY KEY (id);


--
-- Name: contract_purchase contract_purchase_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_purchase
    ADD CONSTRAINT contract_purchase_pkey PRIMARY KEY (id);


--
-- Name: contract_year_basis contract_year_basis_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_year_basis
    ADD CONSTRAINT contract_year_basis_key UNIQUE (contract_id, year);


--
-- Name: contract_year_basis contract_year_basis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_year_basis
    ADD CONSTRAINT contract_year_basis_pkey PRIMARY KEY (id);


--
-- Name: conversation conversation_chatwoot_conversation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_chatwoot_conversation_id_key UNIQUE (chatwoot_conversation_id);


--
-- Name: conversation conversation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_pkey PRIMARY KEY (id);


--
-- Name: custom_field custom_field_entity_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_entity_key_key UNIQUE (entity, key);


--
-- Name: custom_field_option custom_field_option_field_id_label_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_field_id_label_key UNIQUE (field_id, label);


--
-- Name: custom_field_option custom_field_option_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_pkey PRIMARY KEY (id);


--
-- Name: custom_field custom_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_pkey PRIMARY KEY (id);


--
-- Name: custom_field_section custom_field_section_entity_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_section
    ADD CONSTRAINT custom_field_section_entity_name_key UNIQUE (entity, name);


--
-- Name: custom_field_section custom_field_section_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_section
    ADD CONSTRAINT custom_field_section_pkey PRIMARY KEY (id);


--
-- Name: custom_field_team custom_field_team_field_id_team_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_field_id_team_id_key UNIQUE (field_id, team_id);


--
-- Name: custom_field_team custom_field_team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_pkey PRIMARY KEY (id);


--
-- Name: deal_contact deal_contact_deal_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_deal_id_contact_id_key UNIQUE (deal_id, contact_id);


--
-- Name: deal_contact deal_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_pkey PRIMARY KEY (id);


--
-- Name: deal_event deal_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_pkey PRIMARY KEY (id);


--
-- Name: deal deal_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: deal_oom deal_oom_deal_id_oom_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_deal_id_oom_id_key UNIQUE (deal_id, oom_id);


--
-- Name: deal_oom deal_oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_pkey PRIMARY KEY (id);


--
-- Name: deal deal_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_pkey PRIMARY KEY (id);


--
-- Name: doc_counter doc_counter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doc_counter
    ADD CONSTRAINT doc_counter_pkey PRIMARY KEY (org_id, kind, year);


--
-- Name: email_message email_message_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_pkey PRIMARY KEY (id);


--
-- Name: email_message email_message_send_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_send_key_key UNIQUE (send_key);


--
-- Name: email_outbox email_outbox_notification_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_notification_id_key UNIQUE (notification_id);


--
-- Name: email_outbox email_outbox_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_pkey PRIMARY KEY (id);


--
-- Name: email_outbox email_outbox_send_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_send_key_key UNIQUE (send_key);


--
-- Name: email_template_version email_template_version_org_id_code_language_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template_version
    ADD CONSTRAINT email_template_version_org_id_code_language_version_key UNIQUE (org_id, code, language, version);


--
-- Name: email_template_version email_template_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template_version
    ADD CONSTRAINT email_template_version_pkey PRIMARY KEY (id);


--
-- Name: email_thread email_thread_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_pkey PRIMARY KEY (id);


--
-- Name: export_log export_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_log
    ADD CONSTRAINT export_log_pkey PRIMARY KEY (id);


--
-- Name: finstat_cache finstat_cache_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finstat_cache
    ADD CONSTRAINT finstat_cache_pkey PRIMARY KEY (kind, key);


--
-- Name: finstat_usage finstat_usage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.finstat_usage
    ADD CONSTRAINT finstat_usage_pkey PRIMARY KEY (day);


--
-- Name: fve_project fve_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_pkey PRIMARY KEY (id);


--
-- Name: gmail_mailbox_state gmail_mailbox_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gmail_mailbox_state
    ADD CONSTRAINT gmail_mailbox_state_pkey PRIMARY KEY (mailbox);


--
-- Name: import_alias import_alias_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_alias
    ADD CONSTRAINT import_alias_pkey PRIMARY KEY (id);


--
-- Name: job_run job_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_run
    ADD CONSTRAINT job_run_pkey PRIMARY KEY (id);


--
-- Name: lookup_list lookup_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_list
    ADD CONSTRAINT lookup_list_pkey PRIMARY KEY (code);


--
-- Name: lookup_value lookup_value_list_code_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_list_code_code_key UNIQUE (list_code, code);


--
-- Name: lookup_value lookup_value_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_pkey PRIMARY KEY (id);


--
-- Name: mailbox_access_log mailbox_access_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_access_log
    ADD CONSTRAINT mailbox_access_log_pkey PRIMARY KEY (id);


--
-- Name: market_price_daily market_price_daily_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_price_daily
    ADD CONSTRAINT market_price_daily_pkey PRIMARY KEY (id);


--
-- Name: notification notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);


--
-- Name: offer_acceptance offer_acceptance_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_pkey PRIMARY KEY (id);


--
-- Name: offer_asset offer_asset_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_asset
    ADD CONSTRAINT offer_asset_pkey PRIMARY KEY (id);


--
-- Name: offer offer_hubspot_quote_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_hubspot_quote_id_key UNIQUE (hubspot_quote_id);


--
-- Name: offer_item offer_item_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_key UNIQUE NULLS NOT DISTINCT (variant_id, oom_id, slot, year);


--
-- Name: offer_item offer_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_pkey PRIMARY KEY (id);


--
-- Name: offer offer_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_number_key UNIQUE (org_id, number, version);


--
-- Name: offer_page_stat offer_page_stat_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_page_stat
    ADD CONSTRAINT offer_page_stat_pkey PRIMARY KEY (offer_id);


--
-- Name: offer offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_pkey PRIMARY KEY (id);


--
-- Name: offer_template_version offer_template_version_org_id_kind_language_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_template_version
    ADD CONSTRAINT offer_template_version_org_id_kind_language_version_key UNIQUE (org_id, kind, language, version);


--
-- Name: offer_template_version offer_template_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_template_version
    ADD CONSTRAINT offer_template_version_pkey PRIMARY KEY (id);


--
-- Name: offer_variant offer_variant_offer_id_sort_order_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_variant
    ADD CONSTRAINT offer_variant_offer_id_sort_order_key UNIQUE (offer_id, sort_order);


--
-- Name: offer_variant offer_variant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_variant
    ADD CONSTRAINT offer_variant_pkey PRIMARY KEY (id);


--
-- Name: offer_year_basis offer_year_basis_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_year_basis
    ADD CONSTRAINT offer_year_basis_pkey PRIMARY KEY (variant_id, year);


--
-- Name: oom_contact oom_contact_oom_id_contact_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_oom_id_contact_id_key UNIQUE (oom_id, contact_id);


--
-- Name: oom_contact oom_contact_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_pkey PRIMARY KEY (id);


--
-- Name: oom_customer oom_customer_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_no_overlap EXCLUDE USING gist (oom_id WITH =, daterange(valid_from, valid_to, '[]'::text) WITH &&);


--
-- Name: oom_customer oom_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_pkey PRIMARY KEY (id);


--
-- Name: oom_device oom_device_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_device
    ADD CONSTRAINT oom_device_pkey PRIMARY KEY (id);


--
-- Name: oom oom_eic_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_eic_key UNIQUE (eic);


--
-- Name: oom oom_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: oom_import oom_import_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_import
    ADD CONSTRAINT oom_import_pkey PRIMARY KEY (id);


--
-- Name: oom oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_pkey PRIMARY KEY (id);


--
-- Name: oom_planned_change oom_planned_change_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_pkey PRIMARY KEY (id);


--
-- Name: oom_price_regulation_change oom_price_regulation_change_oom_id_valid_from_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_price_regulation_change
    ADD CONSTRAINT oom_price_regulation_change_oom_id_valid_from_key UNIQUE (oom_id, valid_from);


--
-- Name: oom_price_regulation_change oom_price_regulation_change_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_price_regulation_change
    ADD CONSTRAINT oom_price_regulation_change_pkey PRIMARY KEY (id);


--
-- Name: org_bank_account org_bank_account_org_id_iban_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_org_id_iban_key UNIQUE (org_id, iban);


--
-- Name: org_bank_account org_bank_account_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_pkey PRIMARY KEY (id);


--
-- Name: org org_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org
    ADD CONSTRAINT org_code_key UNIQUE (code);


--
-- Name: org_day_off org_day_off_org_id_date_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_org_id_date_key UNIQUE (org_id, date);


--
-- Name: org_day_off org_day_off_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_pkey PRIMARY KEY (id);


--
-- Name: org_logo org_logo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_logo
    ADD CONSTRAINT org_logo_pkey PRIMARY KEY (org_id);


--
-- Name: org org_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org
    ADD CONSTRAINT org_pkey PRIMARY KEY (id);


--
-- Name: org_work_hours org_work_hours_org_id_weekday_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_org_id_weekday_key UNIQUE (org_id, weekday);


--
-- Name: org_work_hours org_work_hours_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_pkey PRIMARY KEY (id);


--
-- Name: pipeline pipeline_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: pipeline pipeline_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage pipeline_stage_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: pipeline_stage pipeline_stage_id_pipeline_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_id_pipeline_id_key UNIQUE (id, pipeline_id);


--
-- Name: pipeline_stage pipeline_stage_pipeline_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pipeline_id_name_key UNIQUE (pipeline_id, name);


--
-- Name: pipeline_stage pipeline_stage_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_pkey PRIMARY KEY (id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_stage_id_core_field_custom_fi_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_stage_id_core_field_custom_fi_key UNIQUE NULLS NOT DISTINCT (stage_id, core_field, custom_field_id);


--
-- Name: price_exception price_exception_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_pkey PRIMARY KEY (id);


--
-- Name: price_list price_list_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list
    ADD CONSTRAINT price_list_code_key UNIQUE (code);


--
-- Name: price_list_item price_list_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_pkey PRIMARY KEY (id);


--
-- Name: price_list_item price_list_item_product_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_product_key UNIQUE (version_id, product_id);


--
-- Name: price_list_item_program price_list_item_program_item_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item_program
    ADD CONSTRAINT price_list_item_program_item_id_key UNIQUE (item_id);


--
-- Name: price_list_item_program price_list_item_program_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item_program
    ADD CONSTRAINT price_list_item_program_pkey PRIMARY KEY (id);


--
-- Name: price_list price_list_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list
    ADD CONSTRAINT price_list_pkey PRIMARY KEY (id);


--
-- Name: price_list_version price_list_version_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_name_key UNIQUE (price_list_id, name);


--
-- Name: price_list_version price_list_version_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_overlap EXCLUDE USING gist (price_list_id WITH =, daterange(valid_from, valid_to, '[]'::text) WITH &&) WHERE ((status = 'schvalena'::public.price_list_version_status));


--
-- Name: price_list_version price_list_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_pkey PRIMARY KEY (id);


--
-- Name: price_parameter price_parameter_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_parameter
    ADD CONSTRAINT price_parameter_pkey PRIMARY KEY (id);


--
-- Name: product product_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_code_key UNIQUE (code);


--
-- Name: product product_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_pkey PRIMARY KEY (id);


--
-- Name: product_tariff product_tariff_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_tariff
    ADD CONSTRAINT product_tariff_pkey PRIMARY KEY (id);


--
-- Name: product_tariff product_tariff_product_id_scope_code_tariff_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_tariff
    ADD CONSTRAINT product_tariff_product_id_scope_code_tariff_code_key UNIQUE (product_id, scope_code, tariff_code);


--
-- Name: referral referral_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: segment segment_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segment
    ADD CONSTRAINT segment_name_key UNIQUE (name);


--
-- Name: segment segment_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.segment
    ADD CONSTRAINT segment_pkey PRIMARY KEY (id);


--
-- Name: sla_record sla_record_conversation_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_conversation_id_key UNIQUE (conversation_id);


--
-- Name: sla_record sla_record_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_pkey PRIMARY KEY (id);


--
-- Name: supplier_switch supplier_switch_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: supplier_switch supplier_switch_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_pkey PRIMARY KEY (id);


--
-- Name: sync_run sync_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sync_run
    ADD CONSTRAINT sync_run_pkey PRIMARY KEY (id);


--
-- Name: tariff_scope tariff_scope_pds_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tariff_scope
    ADD CONSTRAINT tariff_scope_pds_code_key UNIQUE (pds_code);


--
-- Name: tariff_scope tariff_scope_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tariff_scope
    ADD CONSTRAINT tariff_scope_pkey PRIMARY KEY (code);


--
-- Name: team team_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_code_key UNIQUE (code);


--
-- Name: team team_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: team team_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_name_key UNIQUE (name);


--
-- Name: team_permission team_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_pkey PRIMARY KEY (id);


--
-- Name: team_permission team_permission_team_id_module_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_team_id_module_key UNIQUE (team_id, module);


--
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (id);


--
-- Name: user_commission_rate user_commission_rate_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commission_rate
    ADD CONSTRAINT user_commission_rate_pkey PRIMARY KEY (id);


--
-- Name: user_commission_rate user_commission_rate_user_id_valid_from_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commission_rate
    ADD CONSTRAINT user_commission_rate_user_id_valid_from_key UNIQUE (user_id, valid_from);


--
-- Name: user_photo user_photo_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_photo
    ADD CONSTRAINT user_photo_pkey PRIMARY KEY (user_id);


--
-- Name: user_signature_image user_signature_image_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature_image
    ADD CONSTRAINT user_signature_image_pkey PRIMARY KEY (user_id, cid);


--
-- Name: user_signature user_signature_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature
    ADD CONSTRAINT user_signature_pkey PRIMARY KEY (id);


--
-- Name: user_signature user_signature_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature
    ADD CONSTRAINT user_signature_user_id_key UNIQUE (user_id);


--
-- Name: voucher voucher_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_code_key UNIQUE (code);


--
-- Name: voucher voucher_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: voucher voucher_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_pkey PRIMARY KEY (id);


--
-- Name: web_event web_event_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_event
    ADD CONSTRAINT web_event_pkey PRIMARY KEY (id);


--
-- Name: activity_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_company_id_idx ON public.activity USING btree (company_id, occurred_at);


--
-- Name: activity_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_contact_id_idx ON public.activity USING btree (contact_id, occurred_at);


--
-- Name: activity_conversation_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_conversation_id_idx ON public.activity USING btree (conversation_id, occurred_at);


--
-- Name: activity_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_deal_id_idx ON public.activity USING btree (deal_id, occurred_at);


--
-- Name: activity_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_occurred_at_idx ON public.activity USING btree (occurred_at);


--
-- Name: activity_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_oom_id_idx ON public.activity USING btree (oom_id, occurred_at);


--
-- Name: activity_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_user_id_idx ON public.activity USING btree (user_id, occurred_at);


--
-- Name: app_user_email_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX app_user_email_key ON public.app_user USING btree (lower(email));


--
-- Name: app_user_org_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX app_user_org_org_id_idx ON public.app_user_org USING btree (org_id);


--
-- Name: app_user_team_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX app_user_team_id_idx ON public.app_user USING btree (team_id);


--
-- Name: approval_request_pending_assign_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approval_request_pending_assign_key ON public.approval_request USING btree (company_id, requested_by) WHERE ((kind = 'pridelenie_firmy'::public.approval_kind) AND (status = 'caka'::public.approval_status));


--
-- Name: approval_request_pending_offer_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approval_request_pending_offer_key ON public.approval_request USING btree (offer_id, kind) WHERE ((status = 'caka'::public.approval_status) AND (kind = ANY (ARRAY['vynimka_ceny'::public.approval_kind, 'predlzenie_platnosti'::public.approval_kind])));


--
-- Name: approval_request_pending_risk_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX approval_request_pending_risk_key ON public.approval_request USING btree (deal_id) WHERE ((status = 'caka'::public.approval_status) AND (kind = 'rizikovy_zakaznik'::public.approval_kind));


--
-- Name: audit_log_changed_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_at_idx ON public.audit_log USING btree (changed_at);


--
-- Name: audit_log_changed_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_by_idx ON public.audit_log USING btree (changed_by);


--
-- Name: audit_log_contract_import_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_contract_import_id_idx ON public.audit_log USING btree (contract_import_id) WHERE (contract_import_id IS NOT NULL);


--
-- Name: audit_log_import_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_import_id_idx ON public.audit_log USING btree (import_id) WHERE (import_id IS NOT NULL);


--
-- Name: audit_log_record_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_record_idx ON public.audit_log USING btree (table_name, record_id, changed_at);


--
-- Name: audit_log_table_changed_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_table_changed_at_idx ON public.audit_log USING btree (table_name, changed_at);


--
-- Name: call_agent_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX call_agent_id_idx ON public.call USING btree (agent_id);


--
-- Name: commission_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_deal_id_idx ON public.commission USING btree (deal_id);


--
-- Name: commission_rule_pipeline_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_rule_pipeline_id_idx ON public.commission_rule USING btree (pipeline_id);


--
-- Name: commission_rule_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_rule_product_id_idx ON public.commission_rule USING btree (product_id);


--
-- Name: commission_user_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX commission_user_id_idx ON public.commission USING btree (user_id);


--
-- Name: company_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_contact_contact_id_idx ON public.company_contact USING btree (contact_id);


--
-- Name: company_contact_one_main_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_contact_one_main_key ON public.company_contact USING btree (company_id) WHERE is_main_contact;


--
-- Name: company_country_ico_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_country_ico_key ON public.company USING btree (country, ico);


--
-- Name: company_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_custom_idx ON public.company USING gin (custom jsonb_path_ops);


--
-- Name: company_op_person_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_op_person_key ON public.company USING btree (org_id, op_person_id) WHERE (op_person_id IS NOT NULL);


--
-- Name: company_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_org_id_idx ON public.company USING btree (org_id);


--
-- Name: company_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_owner_id_idx ON public.company USING btree (owner_id);


--
-- Name: company_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_status_idx ON public.company USING btree (status) WHERE is_customer;


--
-- Name: consent_contact_purpose_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX consent_contact_purpose_idx ON public.consent USING btree (contact_id, purpose, recorded_at DESC);


--
-- Name: contact_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_custom_idx ON public.contact USING gin (custom jsonb_path_ops);


--
-- Name: contact_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_email_idx ON public.contact USING btree (lower(btrim(email)));


--
-- Name: contact_mobile_norm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_mobile_norm_idx ON public.contact USING btree (mobile_norm);


--
-- Name: contact_op_person_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contact_op_person_key ON public.contact USING btree (org_id, op_person_id) WHERE (op_person_id IS NOT NULL);


--
-- Name: contact_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_org_id_idx ON public.contact USING btree (org_id);


--
-- Name: contact_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_owner_id_idx ON public.contact USING btree (owner_id);


--
-- Name: contact_phone_norm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_phone_norm_idx ON public.contact USING btree (phone_norm);


--
-- Name: contact_posthog_distinct_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_posthog_distinct_id_idx ON public.contact USING btree (posthog_distinct_id);


--
-- Name: contact_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_status_idx ON public.contact USING btree (status) WHERE is_household;


--
-- Name: contract_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_company_id_idx ON public.contract USING btree (company_id);


--
-- Name: contract_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_custom_idx ON public.contract USING gin (custom jsonb_path_ops);


--
-- Name: contract_flag_open_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contract_flag_open_key ON public.contract_flag USING btree (contract_id, code, COALESCE((year)::integer, 0)) WHERE (resolved_at IS NULL);


--
-- Name: contract_import_change_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_import_change_contract_idx ON public.contract_import_change USING btree (contract_id);


--
-- Name: contract_oom_oom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_oom_oom_idx ON public.contract_oom USING btree (oom_id);


--
-- Name: contract_oom_program_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_oom_program_idx ON public.contract_oom USING btree (program_id);


--
-- Name: contract_oom_successor_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_oom_successor_idx ON public.contract_oom USING btree (successor_id);


--
-- Name: contract_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_org_id_idx ON public.contract USING btree (org_id);


--
-- Name: contract_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_owner_id_idx ON public.contract USING btree (owner_id);


--
-- Name: contract_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_person_id_idx ON public.contract USING btree (person_id);


--
-- Name: contract_previous_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_previous_idx ON public.contract USING btree (previous_contract_id);


--
-- Name: contract_price_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_contract_idx ON public.contract_price USING btree (contract_id);


--
-- Name: contract_price_item_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_item_idx ON public.contract_price USING btree (price_list_item_id);


--
-- Name: contract_price_oom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_oom_idx ON public.contract_price USING btree (oom_id);


--
-- Name: contract_price_product_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_product_idx ON public.contract_price USING btree (product_id);


--
-- Name: contract_purchase_cockpit_ref_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_purchase_cockpit_ref_idx ON public.contract_purchase USING btree (cockpit_ref);


--
-- Name: contract_purchase_contract_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_purchase_contract_id_idx ON public.contract_purchase USING btree (contract_id);


--
-- Name: contract_purchase_hubspot_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contract_purchase_hubspot_key ON public.contract_purchase USING btree (contract_id, hubspot_id) WHERE (hubspot_id IS NOT NULL);


--
-- Name: conversation_assignee_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_assignee_id_idx ON public.conversation USING btree (assignee_id);


--
-- Name: conversation_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_company_id_idx ON public.conversation USING btree (company_id);


--
-- Name: conversation_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_contact_id_idx ON public.conversation USING btree (contact_id);


--
-- Name: conversation_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_oom_id_idx ON public.conversation USING btree (oom_id);


--
-- Name: conversation_opened_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX conversation_opened_at_idx ON public.conversation USING btree (opened_at);


--
-- Name: deal_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_company_id_idx ON public.deal USING btree (company_id);


--
-- Name: deal_company_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_company_idx ON public.deal USING btree (company_id) WHERE (company_id IS NOT NULL);


--
-- Name: deal_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_contact_contact_id_idx ON public.deal_contact USING btree (contact_id);


--
-- Name: deal_contact_primary_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX deal_contact_primary_key ON public.deal_contact USING btree (deal_id) WHERE is_primary;


--
-- Name: deal_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_custom_idx ON public.deal USING gin (custom jsonb_path_ops);


--
-- Name: deal_event_deal_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_event_deal_idx ON public.deal_event USING btree (deal_id, occurred_at);


--
-- Name: deal_next_step_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_next_step_idx ON public.deal USING btree (next_step_on) WHERE (closed_at IS NULL);


--
-- Name: deal_oom_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_oom_oom_id_idx ON public.deal_oom USING btree (oom_id);


--
-- Name: deal_oom_oom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_oom_oom_idx ON public.deal_oom USING btree (oom_id);


--
-- Name: deal_open_renewal_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX deal_open_renewal_key ON public.deal USING btree (previous_contract_id) WHERE ((closed_at IS NULL) AND (source_code = 'obnova'::text));


--
-- Name: deal_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_org_id_idx ON public.deal USING btree (org_id);


--
-- Name: deal_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_owner_id_idx ON public.deal USING btree (owner_id);


--
-- Name: deal_owner_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_owner_idx ON public.deal USING btree (owner_id);


--
-- Name: deal_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_person_id_idx ON public.deal USING btree (person_id);


--
-- Name: deal_person_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_person_idx ON public.deal USING btree (person_id) WHERE (person_id IS NOT NULL);


--
-- Name: deal_pipeline_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_pipeline_id_idx ON public.deal USING btree (pipeline_id);


--
-- Name: deal_stage_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_stage_id_idx ON public.deal USING btree (stage_id, pipeline_id);


--
-- Name: email_message_confirmation_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_message_confirmation_key ON public.email_message USING btree (acceptance_id) WHERE (kind = 'potvrdenie_akceptacie'::text);


--
-- Name: email_message_gmail_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_message_gmail_key ON public.email_message USING btree (thread_id, gmail_message_id) WHERE (gmail_message_id IS NOT NULL);


--
-- Name: email_message_offer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_message_offer_idx ON public.email_message USING btree (offer_id);


--
-- Name: email_message_reminder_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_message_reminder_key ON public.email_message USING btree (offer_id) WHERE (kind = 'pripomienka_platnosti'::text);


--
-- Name: email_message_sending_offer_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_message_sending_offer_key ON public.email_message USING btree (offer_id) WHERE ((status = 'odosiela_sa'::public.email_status) AND (kind = 'ponuka'::text));


--
-- Name: email_message_thread_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_message_thread_idx ON public.email_message USING btree (thread_id, created_at);


--
-- Name: email_message_work_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_message_work_idx ON public.email_message USING btree (status, sending_started_at) WHERE (status = ANY (ARRAY['v_rade'::public.email_status, 'odosiela_sa'::public.email_status]));


--
-- Name: email_outbox_work_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_outbox_work_idx ON public.email_outbox USING btree (status, created_at) WHERE (status = ANY (ARRAY['v_rade'::text, 'odosiela_sa'::text]));


--
-- Name: email_template_navrh_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_template_navrh_key ON public.email_template_version USING btree (org_id, code, language) WHERE (status = 'navrh'::text);


--
-- Name: email_template_platna_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_template_platna_key ON public.email_template_version USING btree (org_id, code, language) WHERE (status = 'platna'::text);


--
-- Name: email_thread_company_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_thread_company_idx ON public.email_thread USING btree (company_id);


--
-- Name: email_thread_deal_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_thread_deal_idx ON public.email_thread USING btree (deal_id);


--
-- Name: email_thread_gmail_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX email_thread_gmail_key ON public.email_thread USING btree (COALESCE(mailbox_user_id, '00000000-0000-0000-0000-000000000000'::uuid), gmail_thread_id) WHERE (gmail_thread_id IS NOT NULL);


--
-- Name: email_thread_offer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_thread_offer_idx ON public.email_thread USING btree (offer_id);


--
-- Name: email_thread_person_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_thread_person_idx ON public.email_thread USING btree (person_id);


--
-- Name: email_thread_watch_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX email_thread_watch_idx ON public.email_thread USING btree (watch_until) WHERE ((gmail_thread_id IS NOT NULL) AND (mailbox_user_id IS NOT NULL));


--
-- Name: export_log_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX export_log_created_at_idx ON public.export_log USING btree (created_at);


--
-- Name: finstat_cache_fetched_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX finstat_cache_fetched_idx ON public.finstat_cache USING btree (fetched_at);


--
-- Name: fve_project_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fve_project_deal_id_idx ON public.fve_project USING btree (deal_id);


--
-- Name: import_alias_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX import_alias_key ON public.import_alias USING btree (org_id, source, kind, name_norm);


--
-- Name: job_run_job_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX job_run_job_date_idx ON public.job_run USING btree (job, run_date DESC);


--
-- Name: lookup_value_label_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX lookup_value_label_key ON public.lookup_value USING btree (list_code, org_id, parent_code, lower(label)) NULLS NOT DISTINCT;


--
-- Name: mailbox_access_log_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mailbox_access_log_at_idx ON public.mailbox_access_log USING btree (at);


--
-- Name: mailbox_access_log_mailbox_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mailbox_access_log_mailbox_idx ON public.mailbox_access_log USING btree (mailbox_user_id, at);


--
-- Name: market_price_daily_current_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX market_price_daily_current_key ON public.market_price_daily USING btree (org_id, on_date, delivery_year) WHERE (corrected_at IS NULL);


--
-- Name: market_price_daily_day_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX market_price_daily_day_idx ON public.market_price_daily USING btree (org_id, delivery_year, on_date);


--
-- Name: notification_contract_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_contract_idx ON public.notification USING btree (contract_id, kind, ref_date);


--
-- Name: notification_unread_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_unread_idx ON public.notification USING btree (user_id) WHERE (read_at IS NULL);


--
-- Name: notification_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notification_user_idx ON public.notification USING btree (user_id, created_at DESC);


--
-- Name: offer_acceptance_active_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX offer_acceptance_active_key ON public.offer_acceptance USING btree (offer_id) WHERE (revoked_at IS NULL);


--
-- Name: offer_acceptance_offer_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_acceptance_offer_idx ON public.offer_acceptance USING btree (offer_id);


--
-- Name: offer_asset_active_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX offer_asset_active_key ON public.offer_asset USING btree (org_id, code) WHERE active;


--
-- Name: offer_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_custom_idx ON public.offer USING gin (custom jsonb_path_ops);


--
-- Name: offer_deal_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_deal_idx ON public.offer USING btree (deal_id);


--
-- Name: offer_item_variant_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_variant_idx ON public.offer_item USING btree (variant_id);


--
-- Name: offer_link_hash_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX offer_link_hash_key ON public.offer USING btree (link_hash) WHERE (link_hash IS NOT NULL);


--
-- Name: offer_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_org_id_idx ON public.offer USING btree (org_id);


--
-- Name: offer_template_navrh_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX offer_template_navrh_key ON public.offer_template_version USING btree (org_id, kind, language) WHERE (status = 'navrh'::text);


--
-- Name: offer_template_platna_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX offer_template_platna_key ON public.offer_template_version USING btree (org_id, kind, language) WHERE (status = 'platna'::text);


--
-- Name: oom_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_company_id_idx ON public.oom USING btree (company_id);


--
-- Name: oom_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_contact_contact_id_idx ON public.oom_contact USING btree (contact_id);


--
-- Name: oom_custom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_custom_idx ON public.oom USING gin (custom jsonb_path_ops);


--
-- Name: oom_customer_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_company_id_idx ON public.oom_customer USING btree (company_id);


--
-- Name: oom_customer_one_open_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oom_customer_one_open_key ON public.oom_customer USING btree (oom_id) WHERE (valid_to IS NULL);


--
-- Name: oom_customer_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_org_id_idx ON public.oom_customer USING btree (org_id);


--
-- Name: oom_customer_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_customer_person_id_idx ON public.oom_customer USING btree (person_id);


--
-- Name: oom_device_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_device_oom_id_idx ON public.oom_device USING btree (oom_id);


--
-- Name: oom_import_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_import_created_at_idx ON public.oom_import USING btree (created_at);


--
-- Name: oom_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_org_id_idx ON public.oom USING btree (org_id);


--
-- Name: oom_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_person_id_idx ON public.oom USING btree (person_id);


--
-- Name: oom_planned_change_due_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_planned_change_due_idx ON public.oom_planned_change USING btree (effective_date) WHERE (status = 'planovana'::public.oom_plan_status);


--
-- Name: oom_planned_change_one_active_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX oom_planned_change_one_active_key ON public.oom_planned_change USING btree (oom_id) WHERE (status = 'planovana'::public.oom_plan_status);


--
-- Name: oom_price_regulation_change_oom_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_price_regulation_change_oom_idx ON public.oom_price_regulation_change USING btree (oom_id);


--
-- Name: oom_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_status_idx ON public.oom USING btree (status);


--
-- Name: org_bank_account_one_primary_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX org_bank_account_one_primary_key ON public.org_bank_account USING btree (org_id) WHERE (is_primary AND (archived_at IS NULL));


--
-- Name: org_one_default_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX org_one_default_key ON public.org USING btree (is_default) WHERE is_default;


--
-- Name: pipeline_org_name_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_org_name_key ON public.pipeline USING btree (org_id, name) NULLS NOT DISTINCT;


--
-- Name: pipeline_stage_code_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX pipeline_stage_code_key ON public.pipeline_stage USING btree (pipeline_id, code) WHERE (code IS NOT NULL);


--
-- Name: price_exception_company_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX price_exception_company_idx ON public.price_exception USING btree (company_id);


--
-- Name: price_exception_person_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX price_exception_person_idx ON public.price_exception USING btree (person_id);


--
-- Name: price_list_item_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX price_list_item_product_id_idx ON public.price_list_item USING btree (product_id);


--
-- Name: price_list_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX price_list_org_id_idx ON public.price_list USING btree (org_id);


--
-- Name: price_list_version_one_draft; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX price_list_version_one_draft ON public.price_list_version USING btree (price_list_id) WHERE (status = 'navrh'::public.price_list_version_status);


--
-- Name: price_parameter_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX price_parameter_key ON public.price_parameter USING btree (org_id, code, COALESCE((delivery_year)::integer, 0), valid_from);


--
-- Name: product_hubspot_contract_codes_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_contract_codes_idx ON public.product USING gin (hubspot_contract_codes);


--
-- Name: product_hubspot_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_product_id_idx ON public.product USING btree (hubspot_product_id);


--
-- Name: product_org_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_org_id_idx ON public.product USING btree (org_id);


--
-- Name: product_tariff_lookup_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_tariff_lookup_idx ON public.product_tariff USING btree (scope_code, tariff_code);


--
-- Name: referral_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referral_deal_id_idx ON public.referral USING btree (deal_id);


--
-- Name: referral_referrer_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX referral_referrer_contact_id_idx ON public.referral USING btree (referrer_contact_id);


--
-- Name: supplier_switch_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_switch_deal_id_idx ON public.supplier_switch USING btree (deal_id);


--
-- Name: supplier_switch_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX supplier_switch_oom_id_idx ON public.supplier_switch USING btree (oom_id);


--
-- Name: sync_run_started_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sync_run_started_at_idx ON public.sync_run USING btree (source, started_at);


--
-- Name: tariff_scope_one_common; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX tariff_scope_one_common ON public.tariff_scope USING btree (((pds_code IS NULL))) WHERE (pds_code IS NULL);


--
-- Name: voucher_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX voucher_contact_id_idx ON public.voucher USING btree (contact_id);


--
-- Name: voucher_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX voucher_deal_id_idx ON public.voucher USING btree (deal_id);


--
-- Name: web_event_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_contact_id_idx ON public.web_event USING btree (contact_id, occurred_at);


--
-- Name: web_event_occurred_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_occurred_at_idx ON public.web_event USING btree (occurred_at);


--
-- Name: web_event_posthog_distinct_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX web_event_posthog_distinct_id_idx ON public.web_event USING btree (posthog_distinct_id);


--
-- Name: oom_contact trg_active_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_active_guard BEFORE INSERT OR DELETE OR UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.oom_child_active_guard();


--
-- Name: oom_device trg_active_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_active_guard BEFORE INSERT OR DELETE OR UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.oom_child_active_guard();


--
-- Name: offer_variant trg_after; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_after AFTER INSERT OR UPDATE ON public.offer_variant FOR EACH ROW EXECUTE FUNCTION public.offer_variant_after();


--
-- Name: deal trg_after_change; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_after_change AFTER INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.deal_after_change();


--
-- Name: app_user trg_app_user_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_app_user_guard BEFORE INSERT OR DELETE OR UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.app_user_guard();


--
-- Name: price_exception trg_apply; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_apply AFTER UPDATE OF status ON public.price_exception FOR EACH ROW WHEN (((new.status = 'schvalena'::public.price_exception_status) AND (old.status = 'caka'::public.price_exception_status))) EXECUTE FUNCTION public.price_exception_apply();


--
-- Name: activity trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_setting trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_setting FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_user trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_user_org trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_user_org FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: approval_price_item trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.approval_price_item FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: approval_request trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.approval_request FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: call trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.call FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: campaign trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.campaign FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: commission trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.commission FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: commission_rule trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.commission_rule FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: company trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: company_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: consent trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.consent FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_flag trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_flag FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_price trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_purchase trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_year_basis trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_year_basis FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: conversation trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_option trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_section trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_section FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: custom_field_team trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.custom_field_team FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: deal_oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: email_template_version trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.email_template_version FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: email_thread trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.email_thread FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: fve_project trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: import_alias trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.import_alias FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: lookup_value trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: market_price_daily trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.market_price_daily FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_acceptance trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_acceptance FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_item trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_template_version trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_template_version FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_variant trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_variant FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_contact trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_customer trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_device trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_import trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_import FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_planned_change trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_planned_change FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_price_regulation_change trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_price_regulation_change FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_bank_account trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_day_off trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_day_off FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: org_work_hours trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.org_work_hours FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline_stage trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline_stage_required_field trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline_stage_required_field FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_exception trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_exception FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_list trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_list FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_list_item trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_list_item FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_list_item_program trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_list_item_program FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_list_version trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_list_version FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: price_parameter trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.price_parameter FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: product trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: product_tariff trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.product_tariff FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: referral trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.referral FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: segment trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.segment FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: sla_record trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.sla_record FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: supplier_switch trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.supplier_switch FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: tariff_scope trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.tariff_scope FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: team trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: team_permission trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: user_commission_rate trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.user_commission_rate FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: user_signature trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.user_signature FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: voucher trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract trg_basis; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_basis AFTER UPDATE OF vykup_min_additive, owner_id ON public.contract FOR EACH ROW WHEN (((new.vykup_min_additive IS DISTINCT FROM old.vykup_min_additive) OR (new.owner_id IS DISTINCT FROM old.owner_id))) EXECUTE FUNCTION public.contract_basis_refresh_trigger();


--
-- Name: org_day_off trg_business_calendar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_business_calendar AFTER INSERT OR DELETE OR UPDATE ON public.org_day_off FOR EACH STATEMENT EXECUTE FUNCTION public.business_calendar_rebuild();


--
-- Name: org_work_hours trg_business_calendar; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_business_calendar AFTER INSERT OR DELETE OR UPDATE ON public.org_work_hours FOR EACH STATEMENT EXECUTE FUNCTION public.business_calendar_rebuild();


--
-- Name: company_contact trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.company_contact_check();


--
-- Name: oom_contact trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.oom_contact_check();


--
-- Name: oom_customer trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_check();


--
-- Name: product_tariff trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE OF scope_code, tariff_code ON public.product_tariff FOR EACH ROW EXECUTE FUNCTION public.product_tariff_check();


--
-- Name: tariff_scope trg_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON public.tariff_scope FOR EACH ROW EXECUTE FUNCTION public.tariff_scope_check();


--
-- Name: offer_item trg_child_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_child_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.offer_child_guard();


--
-- Name: offer_variant trg_child_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_child_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer_variant FOR EACH ROW EXECUTE FUNCTION public.offer_child_guard();


--
-- Name: pipeline_stage trg_code_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_code_guard BEFORE INSERT OR UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.pipeline_stage_code_guard();


--
-- Name: company trg_country_default; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_country_default BEFORE INSERT ON public.company FOR EACH ROW EXECUTE FUNCTION public.company_country_default();


--
-- Name: oom trg_created_from_deal; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_created_from_deal BEFORE INSERT OR UPDATE OF created_from_deal_id ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_created_from_deal_check();


--
-- Name: company trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('firma');


--
-- Name: contact trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('osoba');


--
-- Name: contract trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('zmluva');


--
-- Name: deal trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('deal');


--
-- Name: offer trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('ponuka');


--
-- Name: oom trg_custom_values; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_custom_values BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.custom_values_check('oom');


--
-- Name: oom_customer trg_customer_mark; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_mark AFTER INSERT ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_mark();


--
-- Name: company trg_customer_org_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON public.company FOR EACH ROW EXECUTE FUNCTION public.customer_org_guard();


--
-- Name: contact trg_customer_org_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.customer_org_guard();


--
-- Name: oom_customer trg_customer_refresh; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_refresh AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_customer_refresh();


--
-- Name: company trg_customer_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.customer_status_track();


--
-- Name: contact trg_customer_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_customer_status BEFORE INSERT OR UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.customer_status_track();


--
-- Name: deal_oom trg_deal_oom_ready; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_deal_oom_ready AFTER INSERT OR DELETE OR UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.deal_oom_ready_check();


--
-- Name: deal_oom trg_deal_oom_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_deal_oom_rules BEFORE INSERT OR DELETE OR UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.deal_oom_rules();


--
-- Name: offer_acceptance trg_email_confirmation; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_email_confirmation AFTER INSERT OR UPDATE OF confirmation_pdf_key ON public.offer_acceptance FOR EACH ROW WHEN ((new.confirmation_pdf_key IS NOT NULL)) EXECUTE FUNCTION public.offer_acceptance_email();


--
-- Name: offer trg_email_lock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_email_lock BEFORE DELETE OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.offer_email_lock();


--
-- Name: offer_item trg_email_lock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_email_lock BEFORE INSERT OR DELETE OR UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.offer_email_lock();


--
-- Name: offer_variant trg_email_lock; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_email_lock BEFORE INSERT OR DELETE OR UPDATE ON public.offer_variant FOR EACH ROW EXECUTE FUNCTION public.offer_email_lock();


--
-- Name: notification trg_email_outbox; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_email_outbox AFTER INSERT ON public.notification FOR EACH ROW WHEN ((new.kind = ANY (ARRAY['schvalenie_nove'::text, 'schvalenie_rozhodnutie'::text, 'ponuka_akceptovana'::text]))) EXECUTE FUNCTION public.notification_email_outbox();


--
-- Name: deal trg_events; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_events AFTER INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.deal_events();


--
-- Name: deal_contact trg_events; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_events AFTER INSERT OR DELETE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.deal_link_events();


--
-- Name: deal_oom trg_events; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_events AFTER INSERT OR DELETE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.deal_link_events();


--
-- Name: oom trg_feed_in_plan; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_feed_in_plan BEFORE INSERT OR UPDATE OF planned_feed_in_mwh, planned_feed_in_manual, source_power_kw, source_category ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_feed_in_plan();


--
-- Name: contract_oom trg_fill; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fill BEFORE INSERT OR UPDATE ON public.contract_oom FOR EACH ROW EXECUTE FUNCTION public.contract_oom_fill();


--
-- Name: contract_price trg_fill; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_fill BEFORE INSERT OR UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.contract_price_fill();


--
-- Name: contract trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.contract_guard();


--
-- Name: contract_oom trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.contract_oom FOR EACH ROW EXECUTE FUNCTION public.contract_child_guard();


--
-- Name: contract_price trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.contract_child_guard();


--
-- Name: custom_field trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.custom_field_guard();


--
-- Name: custom_field_option trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.custom_field_option_guard();


--
-- Name: deal_event trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE UPDATE ON public.deal_event FOR EACH ROW EXECUTE FUNCTION public.deal_event_guard();


--
-- Name: email_message trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE OR UPDATE ON public.email_message FOR EACH ROW EXECUTE FUNCTION public.email_message_guard();


--
-- Name: email_template_version trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.email_template_version FOR EACH ROW EXECUTE FUNCTION public.email_template_guard();


--
-- Name: import_alias trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.import_alias FOR EACH ROW EXECUTE FUNCTION public.import_alias_guard();


--
-- Name: lookup_value trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.lookup_value_guard();


--
-- Name: market_price_daily trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.market_price_daily FOR EACH ROW EXECUTE FUNCTION public.market_price_guard();


--
-- Name: offer_acceptance trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer_acceptance FOR EACH ROW EXECUTE FUNCTION public.offer_acceptance_guard();


--
-- Name: offer_asset trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer_asset FOR EACH ROW EXECUTE FUNCTION public.offer_asset_guard();


--
-- Name: offer_template_version trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer_template_version FOR EACH ROW EXECUTE FUNCTION public.offer_template_guard();


--
-- Name: price_exception trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.price_exception FOR EACH ROW EXECUTE FUNCTION public.price_exception_guard();


--
-- Name: price_list trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE OR UPDATE ON public.price_list FOR EACH ROW EXECUTE FUNCTION public.price_list_guard();


--
-- Name: price_list_item trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.price_list_item FOR EACH ROW EXECUTE FUNCTION public.price_list_item_guard();


--
-- Name: price_list_item_program trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.price_list_item_program FOR EACH ROW EXECUTE FUNCTION public.price_list_item_program_guard();


--
-- Name: price_list_version trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.price_list_version FOR EACH ROW EXECUTE FUNCTION public.price_list_version_guard();


--
-- Name: price_parameter trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.price_parameter FOR EACH ROW EXECUTE FUNCTION public.price_parameter_guard();


--
-- Name: product trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE DELETE OR UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.product_guard();


--
-- Name: user_commission_rate trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.user_commission_rate FOR EACH ROW EXECUTE FUNCTION public.user_commission_rate_guard();


--
-- Name: user_photo trg_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_guard BEFORE INSERT OR DELETE OR UPDATE ON public.user_photo FOR EACH ROW EXECUTE FUNCTION public.user_photo_guard();


--
-- Name: mailbox_access_log trg_immutable; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_immutable BEFORE DELETE OR UPDATE ON public.mailbox_access_log FOR EACH ROW EXECUTE FUNCTION public.mailbox_access_log_immutable();


--
-- Name: mailbox_access_log trg_immutable_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_immutable_truncate BEFORE TRUNCATE ON public.mailbox_access_log FOR EACH STATEMENT EXECUTE FUNCTION public.mailbox_access_log_immutable();


--
-- Name: company trg_import_flag; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_import_flag BEFORE UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.customer_import_flag_clear();


--
-- Name: contact trg_import_flag; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_import_flag BEFORE UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.customer_import_flag_clear();


--
-- Name: contract trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.contract FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: deal trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.deal FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: oom_customer trg_link_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_link_sync AFTER INSERT OR DELETE OR UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.oom_link_sync();


--
-- Name: contract trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.contract FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: deal trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.deal FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: oom trg_mark_household; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_mark_household AFTER INSERT OR UPDATE OF person_id ON public.oom FOR EACH ROW EXECUTE FUNCTION public.mark_household();


--
-- Name: pipeline trg_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_no_delete BEFORE DELETE ON public.pipeline FOR EACH ROW WHEN ((CURRENT_USER <> 'crm_sync'::name)) EXECUTE FUNCTION public.pipeline_no_delete();


--
-- Name: pipeline_stage trg_no_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_no_delete BEFORE DELETE ON public.pipeline_stage FOR EACH ROW WHEN ((CURRENT_USER <> 'crm_sync'::name)) EXECUTE FUNCTION public.pipeline_no_delete();


--
-- Name: org_bank_account trg_normalize; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_normalize BEFORE INSERT OR UPDATE OF iban ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.org_bank_account_normalize();


--
-- Name: contract_flag trg_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify AFTER INSERT ON public.contract_flag FOR EACH ROW WHEN (((new.code = 'pod_hranicou_bez_vynimky'::public.contract_flag_code) AND (new.resolved_at IS NULL))) EXECUTE FUNCTION public.contract_flag_notify();


--
-- Name: price_exception trg_notify; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_notify AFTER INSERT OR UPDATE OF status ON public.price_exception FOR EACH ROW EXECUTE FUNCTION public.price_exception_notify();


--
-- Name: offer trg_offer_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_offer_guard BEFORE INSERT OR DELETE OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.offer_guard();


--
-- Name: oom trg_oom_active_edit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_active_edit BEFORE UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_active_edit_guard();


--
-- Name: oom trg_oom_active_required; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_active_required BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_active_required_check();


--
-- Name: oom trg_oom_eic; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_eic BEFORE INSERT OR UPDATE OF eic ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_eic_normalize();


--
-- Name: oom trg_oom_first_link; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_first_link AFTER INSERT ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_first_link();


--
-- Name: oom trg_oom_link_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_link_guard BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_link_guard();


--
-- Name: oom trg_oom_lookup; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_lookup BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.oom_lookup_check();


--
-- Name: oom trg_oom_prechod_aktivacia; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_prechod_aktivacia AFTER INSERT OR UPDATE ON public.oom FOR EACH ROW WHEN (((new.status = 'pripravovane'::public.oom_status) AND (new.switch_confirmed_on IS NOT NULL))) EXECUTE FUNCTION public.oom_activate_on_save();


--
-- Name: oom trg_oom_type_refresh; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_oom_type_refresh AFTER UPDATE OF type ON public.oom FOR EACH ROW WHEN ((new.type IS DISTINCT FROM old.type)) EXECUTE FUNCTION public.oom_type_refresh();


--
-- Name: deal_contact trg_org_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_org_check BEFORE INSERT OR UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.deal_contact_org_check();


--
-- Name: company trg_owner_change_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON public.company FOR EACH ROW EXECUTE FUNCTION public.owner_change_guard();


--
-- Name: contact trg_owner_change_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_owner_change_guard BEFORE UPDATE OF owner_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.owner_change_guard();


--
-- Name: audit_log trg_protect; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect BEFORE DELETE OR UPDATE ON public.audit_log FOR EACH ROW EXECUTE FUNCTION public.audit_log_protect();


--
-- Name: audit_log trg_protect_truncate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_protect_truncate BEFORE TRUNCATE ON public.audit_log FOR EACH STATEMENT EXECUTE FUNCTION public.audit_log_protect();


--
-- Name: contract trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: deal trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: offer trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: oom trg_record_org; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.record_org_fill();


--
-- Name: contract_flag trg_resolve_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_resolve_guard BEFORE UPDATE ON public.contract_flag FOR EACH ROW EXECUTE FUNCTION public.contract_flag_resolve_guard();


--
-- Name: deal_contact trg_roles_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_roles_check BEFORE INSERT OR UPDATE OF roles ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.deal_contact_roles_check();


--
-- Name: oom_planned_change trg_row_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_row_guard BEFORE UPDATE ON public.oom_planned_change FOR EACH ROW EXECUTE FUNCTION public.oom_plan_row_guard();


--
-- Name: deal trg_rules; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_rules BEFORE INSERT OR UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.deal_rules();


--
-- Name: pipeline trg_seed_stages; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_seed_stages AFTER INSERT ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.pipeline_seed_stages();


--
-- Name: activity trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_setting trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_setting FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_user trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_user_org trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_user_org FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: approval_request trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.approval_request FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: business_calendar trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.business_calendar FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: call trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.call FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: campaign trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.campaign FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: commission trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.commission FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: commission_rule trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.commission_rule FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.company FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: company_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.company_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: consent trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.consent FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_flag trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_flag FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_price trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_purchase trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_year_basis trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_year_basis FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: conversation trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_option trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_option FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_section trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_section FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: custom_field_team trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.custom_field_team FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: deal_oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.deal_oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: email_message trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.email_message FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: email_outbox trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.email_outbox FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: email_template_version trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.email_template_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: email_thread trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.email_thread FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: fve_project trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: import_alias trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.import_alias FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: job_run trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.job_run FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lookup_list trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.lookup_list FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: lookup_value trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.lookup_value FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: market_price_daily trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.market_price_daily FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_acceptance trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_acceptance FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_asset trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_asset FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_item trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_template_version trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_template_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_variant trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_variant FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_contact trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_contact FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_customer trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_customer FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_device trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_planned_change trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_planned_change FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_price_regulation_change trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_price_regulation_change FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_bank_account trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_bank_account FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_day_off trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_day_off FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_logo trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_logo FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: org_work_hours trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.org_work_hours FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline_stage trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline_stage_required_field trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline_stage_required_field FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_exception trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_exception FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_list trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_list FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_list_item trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_list_item FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_list_item_program trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_list_item_program FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_list_version trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_list_version FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: price_parameter trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.price_parameter FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product_tariff trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.product_tariff FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: referral trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.referral FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: segment trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.segment FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: sla_record trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.sla_record FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: supplier_switch trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.supplier_switch FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: tariff_scope trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.tariff_scope FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: team trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: team_permission trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_commission_rate trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.user_commission_rate FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: user_signature trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.user_signature FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: voucher trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: web_event trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.web_event FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contact trg_source_check; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_source_check BEFORE INSERT OR UPDATE OF source, org_id ON public.contact FOR EACH ROW EXECUTE FUNCTION public.contact_source_check();


--
-- Name: contract trg_sync; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_sync AFTER UPDATE OF phase, type, valid_from, valid_to, crm_valid_to ON public.contract FOR EACH ROW EXECUTE FUNCTION public.contract_sync();


--
-- Name: team trg_team_external_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_external_guard BEFORE UPDATE OF is_external ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_external_guard();


--
-- Name: team_permission trg_team_external_guard; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_external_guard BEFORE INSERT OR UPDATE ON public.team_permission FOR EACH ROW EXECUTE FUNCTION public.team_external_guard();


--
-- Name: team trg_team_permission_init; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_team_permission_init AFTER INSERT ON public.team FOR EACH ROW EXECUTE FUNCTION public.team_permission_init();


--
-- Name: price_exception trg_threshold; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_threshold BEFORE INSERT ON public.price_exception FOR EACH ROW EXECUTE FUNCTION public.price_exception_threshold();


--
-- Name: contract trg_viwa_package; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_viwa_package AFTER UPDATE OF viwa_package ON public.contract FOR EACH ROW WHEN (((new.viwa_package IS DISTINCT FROM old.viwa_package) AND (new.type = 'viwa'::public.contract_type))) EXECUTE FUNCTION public.contract_viwa_package_sync();


--
-- Name: activity activity_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: activity activity_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: activity activity_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversation(id);


--
-- Name: activity activity_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: activity activity_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: activity activity_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity
    ADD CONSTRAINT activity_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: app_user_org app_user_org_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: app_user_org app_user_org_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user_org
    ADD CONSTRAINT app_user_org_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: app_user app_user_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id);


--
-- Name: approval_price_item approval_price_item_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_price_item
    ADD CONSTRAINT approval_price_item_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES public.approval_request(id) ON DELETE CASCADE;


--
-- Name: approval_price_item approval_price_item_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_price_item
    ADD CONSTRAINT approval_price_item_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.offer_variant(id) ON DELETE CASCADE;


--
-- Name: approval_request approval_request_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: approval_request approval_request_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: approval_request approval_request_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.app_user(id);


--
-- Name: approval_request approval_request_from_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_from_owner_id_fkey FOREIGN KEY (from_owner_id) REFERENCES public.app_user(id);


--
-- Name: approval_request approval_request_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE CASCADE;


--
-- Name: approval_request approval_request_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: approval_request approval_request_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.approval_request
    ADD CONSTRAINT approval_request_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.app_user(id);


--
-- Name: audit_log audit_log_contract_import_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_contract_import_id_fkey FOREIGN KEY (contract_import_id) REFERENCES public.contract_import(id);


--
-- Name: audit_log audit_log_import_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_import_id_fkey FOREIGN KEY (import_id) REFERENCES public.oom_import(id);


--
-- Name: business_calendar business_calendar_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_calendar
    ADD CONSTRAINT business_calendar_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: call call_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activity(id) ON DELETE CASCADE;


--
-- Name: call call_agent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.call
    ADD CONSTRAINT call_agent_id_fkey FOREIGN KEY (agent_id) REFERENCES public.app_user(id);


--
-- Name: commission commission_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: commission_rule commission_rule_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: commission_rule commission_rule_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission_rule
    ADD CONSTRAINT commission_rule_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: commission commission_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.commission
    ADD CONSTRAINT commission_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: company_contact company_contact_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id) ON DELETE CASCADE;


--
-- Name: company_contact company_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company_contact
    ADD CONSTRAINT company_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id) ON DELETE CASCADE;


--
-- Name: company company_created_by_import_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_created_by_import_fkey FOREIGN KEY (created_by_import) REFERENCES public.contract_import(id);


--
-- Name: company company_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: company company_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.company
    ADD CONSTRAINT company_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: consent consent_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.consent
    ADD CONSTRAINT consent_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: contact contact_created_by_import_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_created_by_import_fkey FOREIGN KEY (created_by_import) REFERENCES public.contract_import(id);


--
-- Name: contact contact_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contact contact_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact
    ADD CONSTRAINT contact_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: contract contract_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: contract contract_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: contract_flag contract_flag_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_flag
    ADD CONSTRAINT contract_flag_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: contract_flag contract_flag_resolved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_flag
    ADD CONSTRAINT contract_flag_resolved_by_fkey FOREIGN KEY (resolved_by) REFERENCES public.app_user(id);


--
-- Name: contract_import_change contract_import_change_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import_change
    ADD CONSTRAINT contract_import_change_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: contract_import_change contract_import_change_import_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import_change
    ADD CONSTRAINT contract_import_change_import_id_fkey FOREIGN KEY (import_id) REFERENCES public.contract_import(id);


--
-- Name: contract_import contract_import_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import
    ADD CONSTRAINT contract_import_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contract_import contract_import_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_import
    ADD CONSTRAINT contract_import_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: contract contract_last_import_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_last_import_id_fkey FOREIGN KEY (last_import_id) REFERENCES public.contract_import(id);


--
-- Name: contract_oom contract_oom_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: contract_oom contract_oom_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: contract_oom contract_oom_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contract_oom contract_oom_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: contract_oom contract_oom_program_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_program_id_fkey FOREIGN KEY (program_id) REFERENCES public.product(id);


--
-- Name: contract_oom contract_oom_successor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_oom
    ADD CONSTRAINT contract_oom_successor_id_fkey FOREIGN KEY (successor_id) REFERENCES public.contract(id);


--
-- Name: contract contract_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contract contract_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: contract contract_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: contract contract_previous_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_previous_contract_id_fkey FOREIGN KEY (previous_contract_id) REFERENCES public.contract(id);


--
-- Name: contract_price contract_price_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: contract_price contract_price_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: contract_price contract_price_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: contract_price contract_price_price_list_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_price_list_item_id_fkey FOREIGN KEY (price_list_item_id) REFERENCES public.price_list_item(id);


--
-- Name: contract_price contract_price_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: contract_purchase contract_purchase_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_purchase
    ADD CONSTRAINT contract_purchase_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract contract_related_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_related_contract_id_fkey FOREIGN KEY (related_contract_id) REFERENCES public.contract(id);


--
-- Name: contract_year_basis contract_year_basis_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_year_basis
    ADD CONSTRAINT contract_year_basis_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: contract_year_basis contract_year_basis_exception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_year_basis
    ADD CONSTRAINT contract_year_basis_exception_id_fkey FOREIGN KEY (exception_id) REFERENCES public.price_exception(id);


--
-- Name: conversation conversation_assignee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_assignee_id_fkey FOREIGN KEY (assignee_id) REFERENCES public.app_user(id);


--
-- Name: conversation conversation_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: conversation conversation_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: conversation conversation_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conversation
    ADD CONSTRAINT conversation_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: custom_field_option custom_field_option_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_option
    ADD CONSTRAINT custom_field_option_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.custom_field(id);


--
-- Name: custom_field custom_field_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: custom_field custom_field_section_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field
    ADD CONSTRAINT custom_field_section_id_fkey FOREIGN KEY (section_id) REFERENCES public.custom_field_section(id);


--
-- Name: custom_field_team custom_field_team_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_field_id_fkey FOREIGN KEY (field_id) REFERENCES public.custom_field(id) ON DELETE CASCADE;


--
-- Name: custom_field_team custom_field_team_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.custom_field_team
    ADD CONSTRAINT custom_field_team_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id);


--
-- Name: deal deal_accepted_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_accepted_variant_id_fkey FOREIGN KEY (accepted_variant_id) REFERENCES public.offer_variant(id);


--
-- Name: deal deal_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: deal_contact deal_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id) ON DELETE CASCADE;


--
-- Name: deal_contact deal_contact_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_contact
    ADD CONSTRAINT deal_contact_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: deal_event deal_event_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: deal_event deal_event_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: deal_event deal_event_from_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_from_stage_id_fkey FOREIGN KEY (from_stage_id) REFERENCES public.pipeline_stage(id);


--
-- Name: deal_event deal_event_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE SET NULL;


--
-- Name: deal_event deal_event_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: deal_event deal_event_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: deal_event deal_event_to_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_to_stage_id_fkey FOREIGN KEY (to_stage_id) REFERENCES public.pipeline_stage(id);


--
-- Name: deal_event deal_event_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_event
    ADD CONSTRAINT deal_event_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: deal_oom deal_oom_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: deal_oom deal_oom_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: deal_oom deal_oom_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal_oom
    ADD CONSTRAINT deal_oom_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: deal deal_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: deal deal_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.app_user(id);


--
-- Name: deal deal_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: deal deal_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: deal deal_previous_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_previous_contract_id_fkey FOREIGN KEY (previous_contract_id) REFERENCES public.contract(id);


--
-- Name: deal deal_stage_in_pipeline_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_stage_in_pipeline_fkey FOREIGN KEY (stage_id, pipeline_id) REFERENCES public.pipeline_stage(id, pipeline_id);


--
-- Name: doc_counter doc_counter_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.doc_counter
    ADD CONSTRAINT doc_counter_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: email_message email_message_acceptance_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_acceptance_id_fkey FOREIGN KEY (acceptance_id) REFERENCES public.offer_acceptance(id);


--
-- Name: email_message email_message_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: email_message email_message_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id);


--
-- Name: email_message email_message_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: email_message email_message_template_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES public.email_template_version(id);


--
-- Name: email_message email_message_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_message
    ADD CONSTRAINT email_message_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.email_thread(id);


--
-- Name: email_outbox email_outbox_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: email_outbox email_outbox_notification_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_notification_id_fkey FOREIGN KEY (notification_id) REFERENCES public.notification(id) ON DELETE SET NULL;


--
-- Name: email_outbox email_outbox_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_outbox
    ADD CONSTRAINT email_outbox_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: email_template_version email_template_version_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template_version
    ADD CONSTRAINT email_template_version_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: email_template_version email_template_version_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template_version
    ADD CONSTRAINT email_template_version_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: email_template_version email_template_version_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_template_version
    ADD CONSTRAINT email_template_version_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.app_user(id);


--
-- Name: email_thread email_thread_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: email_thread email_thread_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: email_thread email_thread_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: email_thread email_thread_mailbox_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_mailbox_user_id_fkey FOREIGN KEY (mailbox_user_id) REFERENCES public.app_user(id);


--
-- Name: email_thread email_thread_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id);


--
-- Name: email_thread email_thread_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: email_thread email_thread_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.email_thread
    ADD CONSTRAINT email_thread_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: export_log export_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.export_log
    ADD CONSTRAINT export_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: fve_project fve_project_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: import_alias import_alias_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_alias
    ADD CONSTRAINT import_alias_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: import_alias import_alias_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_alias
    ADD CONSTRAINT import_alias_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: lookup_list lookup_list_parent_list_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_list
    ADD CONSTRAINT lookup_list_parent_list_fkey FOREIGN KEY (parent_list) REFERENCES public.lookup_list(code);


--
-- Name: lookup_value lookup_value_list_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_list_code_fkey FOREIGN KEY (list_code) REFERENCES public.lookup_list(code);


--
-- Name: lookup_value lookup_value_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lookup_value
    ADD CONSTRAINT lookup_value_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: mailbox_access_log mailbox_access_log_mailbox_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_access_log
    ADD CONSTRAINT mailbox_access_log_mailbox_user_id_fkey FOREIGN KEY (mailbox_user_id) REFERENCES public.app_user(id);


--
-- Name: mailbox_access_log mailbox_access_log_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_access_log
    ADD CONSTRAINT mailbox_access_log_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.email_thread(id);


--
-- Name: mailbox_access_log mailbox_access_log_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailbox_access_log
    ADD CONSTRAINT mailbox_access_log_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: market_price_daily market_price_daily_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_price_daily
    ADD CONSTRAINT market_price_daily_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.app_user(id);


--
-- Name: market_price_daily market_price_daily_corrected_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_price_daily
    ADD CONSTRAINT market_price_daily_corrected_by_fkey FOREIGN KEY (corrected_by) REFERENCES public.app_user(id);


--
-- Name: market_price_daily market_price_daily_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_price_daily
    ADD CONSTRAINT market_price_daily_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: notification notification_approval_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_approval_id_fkey FOREIGN KEY (approval_id) REFERENCES public.approval_request(id) ON DELETE CASCADE;


--
-- Name: notification notification_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id) ON DELETE CASCADE;


--
-- Name: notification notification_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id) ON DELETE CASCADE;


--
-- Name: notification notification_job_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_job_run_id_fkey FOREIGN KEY (job_run_id) REFERENCES public.job_run(id) ON DELETE CASCADE;


--
-- Name: notification notification_price_exception_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_price_exception_id_fkey FOREIGN KEY (price_exception_id) REFERENCES public.price_exception(id) ON DELETE CASCADE;


--
-- Name: notification notification_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notification
    ADD CONSTRAINT notification_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: offer_acceptance offer_acceptance_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id);


--
-- Name: offer_acceptance offer_acceptance_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer_acceptance offer_acceptance_recorded_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_recorded_by_fkey FOREIGN KEY (recorded_by) REFERENCES public.app_user(id);


--
-- Name: offer_acceptance offer_acceptance_revoked_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_revoked_by_fkey FOREIGN KEY (revoked_by) REFERENCES public.app_user(id);


--
-- Name: offer_acceptance offer_acceptance_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_acceptance
    ADD CONSTRAINT offer_acceptance_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.offer_variant(id);


--
-- Name: offer_asset offer_asset_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_asset
    ADD CONSTRAINT offer_asset_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: offer_asset offer_asset_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_asset
    ADD CONSTRAINT offer_asset_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer offer_blocked_by_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_blocked_by_offer_id_fkey FOREIGN KEY (blocked_by_offer_id) REFERENCES public.offer(id);


--
-- Name: offer offer_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: offer offer_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: offer offer_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: offer_item offer_item_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: offer_item offer_item_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer_item offer_item_price_list_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_price_list_item_id_fkey FOREIGN KEY (price_list_item_id) REFERENCES public.price_list_item(id);


--
-- Name: offer_item offer_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: offer_item offer_item_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.offer_variant(id) ON DELETE CASCADE;


--
-- Name: offer offer_link_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_link_created_by_fkey FOREIGN KEY (link_created_by) REFERENCES public.app_user(id);


--
-- Name: offer offer_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer_page_stat offer_page_stat_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_page_stat
    ADD CONSTRAINT offer_page_stat_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE CASCADE;


--
-- Name: offer offer_replaced_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_replaced_by_id_fkey FOREIGN KEY (replaced_by_id) REFERENCES public.offer(id);


--
-- Name: offer offer_sent_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_sent_by_fkey FOREIGN KEY (sent_by) REFERENCES public.app_user(id);


--
-- Name: offer_template_version offer_template_version_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_template_version
    ADD CONSTRAINT offer_template_version_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: offer offer_template_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_template_version_id_fkey FOREIGN KEY (template_version_id) REFERENCES public.offer_template_version(id);


--
-- Name: offer_template_version offer_template_version_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_template_version
    ADD CONSTRAINT offer_template_version_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer_template_version offer_template_version_published_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_template_version
    ADD CONSTRAINT offer_template_version_published_by_fkey FOREIGN KEY (published_by) REFERENCES public.app_user(id);


--
-- Name: offer_variant offer_variant_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_variant
    ADD CONSTRAINT offer_variant_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE CASCADE;


--
-- Name: offer_variant offer_variant_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_variant
    ADD CONSTRAINT offer_variant_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: offer_year_basis offer_year_basis_variant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_year_basis
    ADD CONSTRAINT offer_year_basis_variant_id_fkey FOREIGN KEY (variant_id) REFERENCES public.offer_variant(id) ON DELETE CASCADE;


--
-- Name: oom oom_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_contact oom_contact_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: oom_contact oom_contact_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_contact
    ADD CONSTRAINT oom_contact_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: oom oom_created_from_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_created_from_deal_id_fkey FOREIGN KEY (created_from_deal_id) REFERENCES public.deal(id);


--
-- Name: oom_customer oom_customer_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_customer oom_customer_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: oom_customer oom_customer_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom_customer oom_customer_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_customer
    ADD CONSTRAINT oom_customer_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: oom_device oom_device_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_device
    ADD CONSTRAINT oom_device_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: oom_import oom_import_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_import
    ADD CONSTRAINT oom_import_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom_import oom_import_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_import
    ADD CONSTRAINT oom_import_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: oom oom_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom oom_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: oom_planned_change oom_planned_change_cancelled_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_cancelled_by_fkey FOREIGN KEY (cancelled_by) REFERENCES public.app_user(id);


--
-- Name: oom_planned_change oom_planned_change_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_planned_change oom_planned_change_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: oom_planned_change oom_planned_change_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: oom_planned_change oom_planned_change_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: oom_planned_change oom_planned_change_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_planned_change
    ADD CONSTRAINT oom_planned_change_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: oom_price_regulation_change oom_price_regulation_change_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_price_regulation_change
    ADD CONSTRAINT oom_price_regulation_change_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id);


--
-- Name: oom_price_regulation_change oom_price_regulation_change_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_price_regulation_change
    ADD CONSTRAINT oom_price_regulation_change_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: org_bank_account org_bank_account_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_bank_account
    ADD CONSTRAINT org_bank_account_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_day_off org_day_off_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_day_off
    ADD CONSTRAINT org_day_off_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_logo org_logo_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_logo
    ADD CONSTRAINT org_logo_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: org_work_hours org_work_hours_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.org_work_hours
    ADD CONSTRAINT org_work_hours_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: pipeline pipeline_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: pipeline_stage pipeline_stage_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_custom_field_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_custom_field_id_fkey FOREIGN KEY (custom_field_id) REFERENCES public.custom_field(id);


--
-- Name: pipeline_stage_required_field pipeline_stage_required_field_stage_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage_required_field
    ADD CONSTRAINT pipeline_stage_required_field_stage_id_fkey FOREIGN KEY (stage_id) REFERENCES public.pipeline_stage(id) ON DELETE CASCADE;


--
-- Name: price_exception price_exception_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: price_exception price_exception_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: price_exception price_exception_decided_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_decided_by_fkey FOREIGN KEY (decided_by) REFERENCES public.app_user(id);


--
-- Name: price_exception price_exception_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: price_exception price_exception_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: price_exception price_exception_requested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_exception
    ADD CONSTRAINT price_exception_requested_by_fkey FOREIGN KEY (requested_by) REFERENCES public.app_user(id);


--
-- Name: price_list_item price_list_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: price_list_item_program price_list_item_program_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item_program
    ADD CONSTRAINT price_list_item_program_item_id_fkey FOREIGN KEY (item_id) REFERENCES public.price_list_item(id) ON DELETE CASCADE;


--
-- Name: price_list_item price_list_item_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_item
    ADD CONSTRAINT price_list_item_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.price_list_version(id) ON DELETE CASCADE;


--
-- Name: price_list price_list_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list
    ADD CONSTRAINT price_list_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: price_list_version price_list_version_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.app_user(id);


--
-- Name: price_list_version price_list_version_copied_from_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_copied_from_id_fkey FOREIGN KEY (copied_from_id) REFERENCES public.price_list_version(id) ON DELETE SET NULL;


--
-- Name: price_list_version price_list_version_price_list_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_list_version
    ADD CONSTRAINT price_list_version_price_list_id_fkey FOREIGN KEY (price_list_id) REFERENCES public.price_list(id) ON DELETE CASCADE;


--
-- Name: price_parameter price_parameter_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_parameter
    ADD CONSTRAINT price_parameter_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.app_user(id);


--
-- Name: price_parameter price_parameter_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.price_parameter
    ADD CONSTRAINT price_parameter_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: product product_org_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product
    ADD CONSTRAINT product_org_id_fkey FOREIGN KEY (org_id) REFERENCES public.org(id);


--
-- Name: product_tariff product_tariff_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_tariff
    ADD CONSTRAINT product_tariff_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: product_tariff product_tariff_scope_code_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.product_tariff
    ADD CONSTRAINT product_tariff_scope_code_fkey FOREIGN KEY (scope_code) REFERENCES public.tariff_scope(code);


--
-- Name: referral referral_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: referral referral_referrer_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.referral
    ADD CONSTRAINT referral_referrer_contact_id_fkey FOREIGN KEY (referrer_contact_id) REFERENCES public.contact(id);


--
-- Name: sla_record sla_record_conversation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sla_record
    ADD CONSTRAINT sla_record_conversation_id_fkey FOREIGN KEY (conversation_id) REFERENCES public.conversation(id) ON DELETE CASCADE;


--
-- Name: supplier_switch supplier_switch_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: supplier_switch supplier_switch_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.supplier_switch
    ADD CONSTRAINT supplier_switch_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: team_permission team_permission_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_permission
    ADD CONSTRAINT team_permission_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id) ON DELETE CASCADE;


--
-- Name: user_commission_rate user_commission_rate_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commission_rate
    ADD CONSTRAINT user_commission_rate_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.app_user(id);


--
-- Name: user_commission_rate user_commission_rate_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_commission_rate
    ADD CONSTRAINT user_commission_rate_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id);


--
-- Name: user_photo user_photo_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_photo
    ADD CONSTRAINT user_photo_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);


--
-- Name: user_photo user_photo_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_photo
    ADD CONSTRAINT user_photo_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: user_signature_image user_signature_image_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature_image
    ADD CONSTRAINT user_signature_image_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: user_signature user_signature_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature
    ADD CONSTRAINT user_signature_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.app_user(id);


--
-- Name: user_signature user_signature_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_signature
    ADD CONSTRAINT user_signature_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.app_user(id) ON DELETE CASCADE;


--
-- Name: voucher voucher_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: voucher voucher_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.voucher
    ADD CONSTRAINT voucher_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: web_event web_event_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_event
    ADD CONSTRAINT web_event_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contact(id);


--
-- Name: app_setting; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_setting ENABLE ROW LEVEL SECURITY;

--
-- Name: app_user; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_user ENABLE ROW LEVEL SECURITY;

--
-- Name: app_user_org; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.app_user_org ENABLE ROW LEVEL SECURITY;

--
-- Name: approval_price_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approval_price_item ENABLE ROW LEVEL SECURITY;

--
-- Name: approval_price_item approval_price_item_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approval_price_item_select ON public.approval_price_item FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.approval_request a
  WHERE (a.id = approval_price_item.approval_id))));


--
-- Name: approval_request; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.approval_request ENABLE ROW LEVEL SECURITY;

--
-- Name: approval_request approval_request_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY approval_request_select ON public.approval_request FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (public.crm_is_service() OR public.crm_is_admin() OR (requested_by = public.crm_active_user_id()) OR (from_owner_id = public.crm_active_user_id()) OR ((kind = 'pridelenie_firmy'::public.approval_kind) AND public.crm_approves_assignments()) OR ((kind <> 'pridelenie_firmy'::public.approval_kind) AND public.crm_approves_prices()))));


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_log audit_log_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_insert ON public.audit_log FOR INSERT WITH CHECK (true);


--
-- Name: audit_log audit_log_protect_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_protect_delete ON public.audit_log FOR DELETE USING (true);


--
-- Name: audit_log audit_log_protect_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_protect_update ON public.audit_log FOR UPDATE USING (true);


--
-- Name: audit_log audit_log_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_log_select ON public.audit_log FOR SELECT USING (public.audit_row_visible(table_name, record_id, diff));


--
-- Name: company; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company ENABLE ROW LEVEL SECURITY;

--
-- Name: company_contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.company_contact ENABLE ROW LEVEL SECURITY;

--
-- Name: contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contact ENABLE ROW LEVEL SECURITY;

--
-- Name: contract; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_flag; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_flag ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_flag contract_flag_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_flag_select ON public.contract_flag FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.contract k
  WHERE (k.id = contract_flag.contract_id))));


--
-- Name: contract_flag contract_flag_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_flag_update ON public.contract_flag FOR UPDATE USING (((EXISTS ( SELECT 1
   FROM public.contract k
  WHERE ((k.id = contract_flag.contract_id) AND public.crm_contract_editable(k.company_id, k.person_id, k.owner_id)))) OR ((code = 'pod_hranicou_bez_vynimky'::public.contract_flag_code) AND public.crm_approves_prices() AND (EXISTS ( SELECT 1
   FROM public.contract k
  WHERE (k.id = contract_flag.contract_id))))));


--
-- Name: contract_import; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_import ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_import_change; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_import_change ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_import_change contract_import_change_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_import_change_select ON public.contract_import_change FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.contract k
  WHERE (k.id = contract_import_change.contract_id))));


--
-- Name: contract_import contract_import_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_import_select ON public.contract_import FOR SELECT USING ((public.crm_is_service() OR public.crm_is_admin() OR (public.crm_can_import('zmluvy'::public.crm_module) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])))));


--
-- Name: contract_oom; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_oom ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_oom contract_oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_oom_select ON public.contract_oom FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.contract k
  WHERE (k.id = contract_oom.contract_id))));


--
-- Name: contract_price; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_price ENABLE ROW LEVEL SECURITY;

--
-- Name: contract_price contract_price_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_price_select ON public.contract_price FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.contract k
  WHERE (k.id = contract_price.contract_id))));


--
-- Name: contract contract_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_select ON public.contract FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_contract_visible(company_id, person_id, owner_id)));


--
-- Name: contract contract_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contract_update ON public.contract FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_contract_editable(company_id, person_id, owner_id))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_contract_editable(company_id, person_id, owner_id)));


--
-- Name: contract_year_basis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contract_year_basis ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_option; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_option ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_section; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_section ENABLE ROW LEVEL SECURITY;

--
-- Name: custom_field_team; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.custom_field_team ENABLE ROW LEVEL SECURITY;

--
-- Name: company_contact customer_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_delete ON public.company_contact FOR DELETE USING (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: company customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.company FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.company_contact FOR INSERT WITH CHECK (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: contact customer_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_insert ON public.contact FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.company FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.company_contact FOR SELECT USING (public.crm_company_access(company_id, 'view'::text));


--
-- Name: contact customer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_select ON public.contact FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'view'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id))))));


--
-- Name: company customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.company FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)))))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND (owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id))))));


--
-- Name: company_contact customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.company_contact FOR UPDATE USING (public.crm_company_access(company_id, 'edit'::text)) WITH CHECK (public.crm_company_access(company_id, 'edit'::text));


--
-- Name: contact customer_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY customer_update ON public.contact FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id)))))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('zakaznici'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND ((owner_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR public.crm_contact_on_own_company(id))))));


--
-- Name: deal; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_contact ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_contact deal_contact_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_contact_select ON public.deal_contact FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE (d.id = deal_contact.deal_id))));


--
-- Name: deal_contact deal_contact_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_contact_write ON public.deal_contact USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = deal_contact.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = deal_contact.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id)))));


--
-- Name: deal_event; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_event ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_event deal_event_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_event_select ON public.deal_event FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE (d.id = deal_event.deal_id))));


--
-- Name: deal deal_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_insert ON public.deal FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_deal_editable(company_id, person_id, owner_id)));


--
-- Name: deal_oom; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.deal_oom ENABLE ROW LEVEL SECURITY;

--
-- Name: deal_oom deal_oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_oom_select ON public.deal_oom FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE (d.id = deal_oom.deal_id))));


--
-- Name: deal_oom deal_oom_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_oom_write ON public.deal_oom USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = deal_oom.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = deal_oom.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id)))));


--
-- Name: deal deal_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_select ON public.deal FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_deal_visible(company_id, person_id, owner_id)));


--
-- Name: deal deal_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY deal_update ON public.deal FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_deal_editable(company_id, person_id, owner_id))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND public.crm_deal_editable(company_id, person_id, owner_id)));


--
-- Name: doc_counter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.doc_counter ENABLE ROW LEVEL SECURITY;

--
-- Name: email_message; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_message ENABLE ROW LEVEL SECURITY;

--
-- Name: email_message email_message_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_message_select ON public.email_message FOR SELECT USING (public.email_message_visible(thread_id, status, created_by));


--
-- Name: email_outbox; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;

--
-- Name: email_outbox email_outbox_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_outbox_select ON public.email_outbox FOR SELECT USING ((public.crm_is_admin() OR (user_id = public.crm_active_user_id())));


--
-- Name: email_template_version email_template_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_template_select ON public.email_template_version FOR SELECT USING (((public.crm_active_user_id() IS NOT NULL) AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: email_template_version; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_template_version ENABLE ROW LEVEL SECURITY;

--
-- Name: email_template_version email_template_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_template_write ON public.email_template_version USING ((public.crm_email_template_editor() AND (org_id = ANY (public.crm_user_orgs())))) WITH CHECK ((public.crm_email_template_editor() AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: email_thread; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.email_thread ENABLE ROW LEVEL SECURITY;

--
-- Name: email_thread email_thread_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY email_thread_select ON public.email_thread FOR SELECT USING (public.email_thread_visible(id));


--
-- Name: gmail_mailbox_state; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.gmail_mailbox_state ENABLE ROW LEVEL SECURITY;

--
-- Name: gmail_mailbox_state gmail_mailbox_state_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY gmail_mailbox_state_select ON public.gmail_mailbox_state FOR SELECT USING (public.crm_is_admin());


--
-- Name: import_alias; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.import_alias ENABLE ROW LEVEL SECURITY;

--
-- Name: import_alias import_alias_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY import_alias_read ON public.import_alias FOR SELECT USING ((( SELECT public.crm_session_ok() AS crm_session_ok) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: import_alias import_alias_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY import_alias_write ON public.import_alias USING ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])))) WITH CHECK ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: job_run; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_run ENABLE ROW LEVEL SECURITY;

--
-- Name: job_run job_run_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY job_run_select ON public.job_run FOR SELECT USING (public.crm_can_see_job_runs());


--
-- Name: lookup_list; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lookup_list ENABLE ROW LEVEL SECURITY;

--
-- Name: lookup_value; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lookup_value ENABLE ROW LEVEL SECURITY;

--
-- Name: mailbox_access_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.mailbox_access_log ENABLE ROW LEVEL SECURITY;

--
-- Name: mailbox_access_log mailbox_access_log_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY mailbox_access_log_select ON public.mailbox_access_log FOR SELECT USING (public.crm_is_admin());


--
-- Name: market_price_daily; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.market_price_daily ENABLE ROW LEVEL SECURITY;

--
-- Name: market_price_daily market_price_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY market_price_read ON public.market_price_daily FOR SELECT USING ((( SELECT public.crm_session_ok() AS crm_session_ok) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_can_see_margin() AS crm_can_see_margin))));


--
-- Name: market_price_daily market_price_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY market_price_write ON public.market_price_daily USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_approves_prices() AS crm_approves_prices)))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_approves_prices() AS crm_approves_prices))));


--
-- Name: notification; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notification ENABLE ROW LEVEL SECURITY;

--
-- Name: notification notification_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notification_select ON public.notification FOR SELECT USING ((user_id = public.crm_active_user_id()));


--
-- Name: notification notification_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY notification_update ON public.notification FOR UPDATE USING ((user_id = public.crm_active_user_id())) WITH CHECK ((user_id = public.crm_active_user_id()));


--
-- Name: offer; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_acceptance; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_acceptance ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_acceptance offer_acceptance_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_acceptance_select ON public.offer_acceptance FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.offer o
  WHERE (o.id = offer_acceptance.offer_id))));


--
-- Name: offer_asset; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_asset ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_asset offer_asset_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_asset_select ON public.offer_asset FOR SELECT USING (((public.crm_active_user_id() IS NOT NULL) AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: offer_asset offer_asset_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_asset_write ON public.offer_asset USING ((public.crm_is_admin() AND (org_id = ANY (public.crm_user_orgs())))) WITH CHECK ((public.crm_is_admin() AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: offer_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_item ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_item offer_item_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_item_select ON public.offer_item FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.offer_variant v
  WHERE (v.id = offer_item.variant_id))));


--
-- Name: offer_item offer_item_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_item_write ON public.offer_item USING ((EXISTS ( SELECT 1
   FROM ((public.offer_variant v
     JOIN public.offer o ON ((o.id = v.offer_id)))
     JOIN public.deal d ON ((d.id = o.deal_id)))
  WHERE ((v.id = offer_item.variant_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM ((public.offer_variant v
     JOIN public.offer o ON ((o.id = v.offer_id)))
     JOIN public.deal d ON ((d.id = o.deal_id)))
  WHERE ((v.id = offer_item.variant_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id)))));


--
-- Name: offer_page_stat; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_page_stat ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_page_stat offer_page_stat_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_page_stat_select ON public.offer_page_stat FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.offer o
  WHERE (o.id = offer_page_stat.offer_id))));


--
-- Name: offer offer_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_select ON public.offer FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE (d.id = offer.deal_id))));


--
-- Name: offer_template_version offer_template_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_template_select ON public.offer_template_version FOR SELECT USING (((public.crm_active_user_id() IS NOT NULL) AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: offer_template_version; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_template_version ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_template_version offer_template_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_template_write ON public.offer_template_version USING ((public.crm_is_admin() AND (org_id = ANY (public.crm_user_orgs())))) WITH CHECK ((public.crm_is_admin() AND (org_id = ANY (public.crm_user_orgs()))));


--
-- Name: offer_variant; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_variant ENABLE ROW LEVEL SECURITY;

--
-- Name: offer_variant offer_variant_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_variant_select ON public.offer_variant FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.offer o
  WHERE (o.id = offer_variant.offer_id))));


--
-- Name: offer_variant offer_variant_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_variant_write ON public.offer_variant USING ((EXISTS ( SELECT 1
   FROM (public.offer o
     JOIN public.deal d ON ((d.id = o.deal_id)))
  WHERE ((o.id = offer_variant.offer_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM (public.offer o
     JOIN public.deal d ON ((d.id = o.deal_id)))
  WHERE ((o.id = offer_variant.offer_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id)))));


--
-- Name: offer offer_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY offer_write ON public.offer USING ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = offer.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.deal d
  WHERE ((d.id = offer.deal_id) AND public.crm_deal_editable(d.company_id, d.person_id, d.owner_id)))));


--
-- Name: offer_year_basis; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.offer_year_basis ENABLE ROW LEVEL SECURITY;

--
-- Name: oom; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_contact; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_contact ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_customer; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_customer ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_contact oom_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_delete ON public.oom_contact FOR DELETE USING (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_device oom_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_delete ON public.oom_device FOR DELETE USING (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_device; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_device ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_import; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_import ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_import oom_import_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_import_insert ON public.oom_import FOR INSERT WITH CHECK ((( SELECT public.crm_can_import('odberne_miesta'::public.crm_module) AS crm_can_import) AND ((user_id = ( SELECT public.crm_active_user_id() AS crm_active_user_id)) OR ( SELECT public.crm_is_service() AS crm_is_service)) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: oom_import oom_import_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_import_select ON public.oom_import FOR SELECT USING ((( SELECT public.crm_is_service() AS crm_is_service) OR ( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_can_import('odberne_miesta'::public.crm_module) AS crm_can_import)));


--
-- Name: oom oom_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_insert ON public.oom FOR INSERT WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND public.crm_customer_owned(company_id, person_id)))));


--
-- Name: oom_contact oom_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_insert ON public.oom_contact FOR INSERT WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_customer oom_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_insert ON public.oom_customer FOR INSERT WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_device oom_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_insert ON public.oom_device FOR INSERT WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_planned_change oom_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_insert ON public.oom_planned_change FOR INSERT WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_planned_change; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_planned_change ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_price_regulation_change; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.oom_price_regulation_change ENABLE ROW LEVEL SECURITY;

--
-- Name: oom_price_regulation_change oom_regulation_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_regulation_delete ON public.oom_price_regulation_change FOR DELETE USING (((applied_at IS NULL) AND (EXISTS ( SELECT 1
   FROM public.oom o
  WHERE (o.id = oom_price_regulation_change.oom_id)))));


--
-- Name: oom_price_regulation_change oom_regulation_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_regulation_read ON public.oom_price_regulation_change FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.oom o
  WHERE (o.id = oom_price_regulation_change.oom_id))));


--
-- Name: oom_price_regulation_change oom_regulation_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_regulation_update ON public.oom_price_regulation_change FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.oom o
  WHERE (o.id = oom_price_regulation_change.oom_id)))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.oom o
  WHERE (o.id = oom_price_regulation_change.oom_id))));


--
-- Name: oom_price_regulation_change oom_regulation_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_regulation_write ON public.oom_price_regulation_change FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM public.oom o
  WHERE (o.id = oom_price_regulation_change.oom_id))));


--
-- Name: oom oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.oom FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'view'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'view'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND public.crm_customer_owned(company_id, person_id)))));


--
-- Name: oom_contact oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.oom_contact FOR SELECT USING (public.crm_oom_access(oom_id, 'view'::text));


--
-- Name: oom_customer oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.oom_customer FOR SELECT USING ((public.crm_oom_access(oom_id, 'view'::text) OR public.crm_company_access(company_id, 'view'::text) OR public.crm_contact_access(person_id, 'view'::text)));


--
-- Name: oom_device oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.oom_device FOR SELECT USING (public.crm_oom_access(oom_id, 'view'::text));


--
-- Name: oom_planned_change oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.oom_planned_change FOR SELECT USING (public.crm_oom_access(oom_id, 'view'::text));


--
-- Name: supplier_switch oom_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_select ON public.supplier_switch FOR SELECT USING (public.crm_oom_access(oom_id, 'view'::text));


--
-- Name: oom oom_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_update ON public.oom FOR UPDATE USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND public.crm_customer_owned(company_id, person_id))))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'vsetko'::public.access_scope) OR ((( SELECT public.crm_scope('odberne_miesta'::public.crm_module, 'edit'::text) AS crm_scope) = 'iba_svoje'::public.access_scope) AND public.crm_customer_owned(company_id, person_id)))));


--
-- Name: oom_contact oom_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_update ON public.oom_contact FOR UPDATE USING (public.crm_oom_access(oom_id, 'edit'::text)) WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_customer oom_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_update ON public.oom_customer FOR UPDATE USING (public.crm_oom_access(oom_id, 'edit'::text)) WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_device oom_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_update ON public.oom_device FOR UPDATE USING (public.crm_oom_access(oom_id, 'edit'::text)) WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: oom_planned_change oom_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY oom_update ON public.oom_planned_change FOR UPDATE USING (public.crm_oom_access(oom_id, 'edit'::text)) WITH CHECK (public.crm_oom_access(oom_id, 'edit'::text));


--
-- Name: org; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org ENABLE ROW LEVEL SECURITY;

--
-- Name: org_bank_account; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_bank_account ENABLE ROW LEVEL SECURITY;

--
-- Name: org_day_off; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_day_off ENABLE ROW LEVEL SECURITY;

--
-- Name: org_logo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_logo ENABLE ROW LEVEL SECURITY;

--
-- Name: org_work_hours; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.org_work_hours ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline_stage; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline_stage ENABLE ROW LEVEL SECURITY;

--
-- Name: pipeline_stage_required_field; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.pipeline_stage_required_field ENABLE ROW LEVEL SECURITY;

--
-- Name: price_exception; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_exception ENABLE ROW LEVEL SECURITY;

--
-- Name: price_exception price_exception_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_exception_delete ON public.price_exception FOR DELETE USING (((requested_by = public.crm_active_user_id()) OR public.crm_is_service()));


--
-- Name: price_exception price_exception_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_exception_insert ON public.price_exception FOR INSERT WITH CHECK ((public.crm_customer_owned(company_id, person_id) OR public.crm_sees_all_contracts() OR public.crm_is_service()));


--
-- Name: price_exception price_exception_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_exception_select ON public.price_exception FOR SELECT USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND ((requested_by = public.crm_active_user_id()) OR public.crm_sees_all_contracts() OR public.crm_is_admin() OR public.crm_is_service())));


--
-- Name: price_exception price_exception_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_exception_update ON public.price_exception FOR UPDATE USING (((requested_by = public.crm_active_user_id()) OR public.crm_approves_prices() OR public.crm_is_service()));


--
-- Name: price_list; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_list ENABLE ROW LEVEL SECURITY;

--
-- Name: price_list_item; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_list_item ENABLE ROW LEVEL SECURITY;

--
-- Name: price_list_item_program; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_list_item_program ENABLE ROW LEVEL SECURITY;

--
-- Name: price_list_item_program price_list_item_program_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_item_program_read ON public.price_list_item_program FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.price_list_item i
  WHERE (i.id = price_list_item_program.item_id))));


--
-- Name: price_list_item_program price_list_item_program_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_item_program_write ON public.price_list_item_program USING ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list_item i
  WHERE (i.id = price_list_item_program.item_id))))) WITH CHECK ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list_item i
  WHERE (i.id = price_list_item_program.item_id)))));


--
-- Name: price_list_item price_list_item_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_item_read ON public.price_list_item FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.price_list_version v
  WHERE (v.id = price_list_item.version_id))));


--
-- Name: price_list_item price_list_item_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_item_write ON public.price_list_item USING ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list_version v
  WHERE (v.id = price_list_item.version_id))))) WITH CHECK ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list_version v
  WHERE (v.id = price_list_item.version_id)))));


--
-- Name: price_list price_list_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_read ON public.price_list FOR SELECT USING ((( SELECT public.crm_session_ok() AS crm_session_ok) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: price_list_version; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_list_version ENABLE ROW LEVEL SECURITY;

--
-- Name: price_list_version price_list_version_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_version_read ON public.price_list_version FOR SELECT USING (((EXISTS ( SELECT 1
   FROM public.price_list l
  WHERE (l.id = price_list_version.price_list_id))) AND ((status <> 'navrh'::public.price_list_version_status) OR ( SELECT public.crm_price_list_writer() AS crm_price_list_writer))));


--
-- Name: price_list_version price_list_version_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_version_write ON public.price_list_version USING ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list l
  WHERE (l.id = price_list_version.price_list_id))))) WITH CHECK ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (EXISTS ( SELECT 1
   FROM public.price_list l
  WHERE (l.id = price_list_version.price_list_id)))));


--
-- Name: price_list price_list_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_list_write ON public.price_list USING ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])))) WITH CHECK ((( SELECT public.crm_price_list_writer() AS crm_price_list_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: price_parameter; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.price_parameter ENABLE ROW LEVEL SECURITY;

--
-- Name: price_parameter price_parameter_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_parameter_read ON public.price_parameter FOR SELECT USING ((( SELECT public.crm_session_ok() AS crm_session_ok) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_can_see_margin() AS crm_can_see_margin))));


--
-- Name: price_parameter price_parameter_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY price_parameter_write ON public.price_parameter USING (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_approves_prices() AS crm_approves_prices)))) WITH CHECK (((org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])) AND (( SELECT public.crm_is_admin() AS crm_is_admin) OR ( SELECT public.crm_approves_prices() AS crm_approves_prices))));


--
-- Name: product; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product ENABLE ROW LEVEL SECURITY;

--
-- Name: product product_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_insert ON public.product FOR INSERT WITH CHECK ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: product product_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_read ON public.product FOR SELECT USING ((( SELECT public.crm_session_ok() AS crm_session_ok) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: product_tariff; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.product_tariff ENABLE ROW LEVEL SECURITY;

--
-- Name: product_tariff product_tariff_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_tariff_delete ON public.product_tariff FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: product_tariff product_tariff_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_tariff_insert ON public.product_tariff FOR INSERT WITH CHECK ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (EXISTS ( SELECT 1
   FROM public.product p
  WHERE (p.id = product_tariff.product_id)))));


--
-- Name: product_tariff product_tariff_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_tariff_read ON public.product_tariff FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.product p
  WHERE (p.id = product_tariff.product_id))));


--
-- Name: product_tariff product_tariff_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_tariff_update ON public.product_tariff FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (EXISTS ( SELECT 1
   FROM public.product p
  WHERE (p.id = product_tariff.product_id)))));


--
-- Name: product product_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY product_update ON public.product FOR UPDATE USING ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[])))) WITH CHECK ((( SELECT public.crm_settings_writer() AS crm_settings_writer) AND (org_id = ANY (( SELECT public.crm_user_orgs() AS crm_user_orgs)::uuid[]))));


--
-- Name: org_day_off settings_day_off_kind_del; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_del ON public.org_day_off AS RESTRICTIVE FOR DELETE USING (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: org_day_off settings_day_off_kind_ins; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_ins ON public.org_day_off AS RESTRICTIVE FOR INSERT WITH CHECK (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: org_day_off settings_day_off_kind_upd; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_day_off_kind_upd ON public.org_day_off AS RESTRICTIVE FOR UPDATE USING (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service())) WITH CHECK (((kind = 'firemne_volno'::public.day_off_kind) OR public.crm_is_service()));


--
-- Name: app_user_org settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.app_user_org FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.custom_field_section FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.custom_field_team FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_day_off FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_logo FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.org_work_hours FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.pipeline_stage_required_field FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: tariff_scope settings_delete; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_delete ON public.tariff_scope FOR DELETE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.app_user FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user_org settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.app_user_org FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_option settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_option FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_section FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.custom_field_team FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.lookup_value FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_bank_account settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_bank_account FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_day_off FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_logo FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.org_work_hours FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline_stage FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.pipeline_stage_required_field FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: tariff_scope settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.tariff_scope FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.team FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team_permission settings_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_insert ON public.team_permission FOR INSERT WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_no_system; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_no_system ON public.lookup_value AS RESTRICTIVE FOR INSERT WITH CHECK (((NOT is_system) OR public.crm_is_service()));


--
-- Name: app_setting settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_setting FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_user FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user_org settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.app_user_org FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_option settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_option FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_section settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_section FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: custom_field_team settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.custom_field_team FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: lookup_list settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.lookup_list FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: lookup_value settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.lookup_value FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_bank_account settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_bank_account FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_day_off settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_day_off FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_logo settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_logo FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: org_work_hours settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.org_work_hours FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline_stage settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline_stage FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: pipeline_stage_required_field settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.pipeline_stage_required_field FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: tariff_scope settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.tariff_scope FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: team settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.team FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: team_permission settings_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_read ON public.team_permission FOR SELECT USING (( SELECT public.crm_session_ok() AS crm_session_ok));


--
-- Name: app_user settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.app_user FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: app_user_org settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.app_user_org FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_option settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_option FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_section settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_section FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: custom_field_team settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.custom_field_team FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: lookup_value settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.lookup_value FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_bank_account settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_bank_account FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_day_off settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_day_off FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_logo settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_logo FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: org_work_hours settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.org_work_hours FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline_stage FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: pipeline_stage_required_field settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.pipeline_stage_required_field FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: tariff_scope settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.tariff_scope FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.team FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: team_permission settings_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY settings_update ON public.team_permission FOR UPDATE USING (( SELECT public.crm_settings_writer() AS crm_settings_writer)) WITH CHECK (( SELECT public.crm_settings_writer() AS crm_settings_writer));


--
-- Name: supplier_switch; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.supplier_switch ENABLE ROW LEVEL SECURITY;

--
-- Name: tariff_scope; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tariff_scope ENABLE ROW LEVEL SECURITY;

--
-- Name: team; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team ENABLE ROW LEVEL SECURITY;

--
-- Name: team_permission; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.team_permission ENABLE ROW LEVEL SECURITY;

--
-- Name: user_commission_rate; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_commission_rate ENABLE ROW LEVEL SECURITY;

--
-- Name: user_commission_rate user_commission_rate_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_commission_rate_select ON public.user_commission_rate FOR SELECT USING ((public.crm_is_service() OR (user_id = public.crm_active_user_id()) OR public.crm_is_admin() OR public.crm_approves_prices()));


--
-- Name: user_commission_rate user_commission_rate_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_commission_rate_write ON public.user_commission_rate USING ((public.crm_is_admin() OR public.crm_approves_prices())) WITH CHECK ((public.crm_is_admin() OR public.crm_approves_prices()));


--
-- Name: user_photo; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_photo ENABLE ROW LEVEL SECURITY;

--
-- Name: user_photo user_photo_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_photo_select ON public.user_photo FOR SELECT USING (((user_id = public.crm_active_user_id()) OR public.crm_is_admin()));


--
-- Name: user_photo user_photo_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_photo_write ON public.user_photo USING (((user_id = public.crm_active_user_id()) OR public.crm_is_admin())) WITH CHECK (((user_id = public.crm_active_user_id()) OR public.crm_is_admin()));


--
-- Name: user_signature; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_signature ENABLE ROW LEVEL SECURITY;

--
-- Name: user_signature_image; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_signature_image ENABLE ROW LEVEL SECURITY;

--
-- Name: user_signature_image user_signature_image_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_signature_image_select ON public.user_signature_image FOR SELECT USING (((user_id = public.crm_active_user_id()) OR public.crm_is_admin()));


--
-- Name: user_signature user_signature_select; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_signature_select ON public.user_signature FOR SELECT USING (((user_id = public.crm_active_user_id()) OR public.crm_is_admin()));


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('0001'),
    ('0002'),
    ('0003'),
    ('0004'),
    ('0005'),
    ('0006'),
    ('0007'),
    ('0008'),
    ('0009'),
    ('0010'),
    ('0011'),
    ('0012'),
    ('0013'),
    ('0014'),
    ('0015'),
    ('0016'),
    ('0017'),
    ('0018'),
    ('0019'),
    ('0020'),
    ('0021'),
    ('0022'),
    ('0023'),
    ('0024'),
    ('0025'),
    ('0026'),
    ('0027'),
    ('0028'),
    ('0029'),
    ('0030'),
    ('0032'),
    ('0033'),
    ('0034'),
    ('0035'),
    ('0036'),
    ('0037'),
    ('0038'),
    ('0039'),
    ('0040'),
    ('0041'),
    ('0042'),
    ('0043'),
    ('0044');
