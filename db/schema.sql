\restrict dbmate

-- Dumped from database version 17.11 (fcae950)
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
-- Name: app_user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.app_user_role AS ENUM (
    'admin',
    'vedenie',
    'obchodnik',
    'servis',
    'marketing'
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
-- Name: company_contact_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.company_contact_role AS ENUM (
    'statutar',
    'kontaktna_osoba',
    'fakturacia',
    'ine'
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
-- Name: contract_price_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_price_status AS ENUM (
    'platna',
    'neplatna'
);


--
-- Name: contract_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.contract_status AS ENUM (
    'rozpracovana',
    'caka_na_podpis',
    'podpisana',
    'caka_na_zaradenie',
    'aktivna',
    'ukoncena',
    'vypoved_neakceptovana',
    'zmena_neuspesna'
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
-- Name: customer_segment; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_segment AS ENUM (
    'domacnost',
    'firma',
    'dodavatel'
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
-- Name: offer_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.offer_status AS ENUM (
    'koncept',
    'odoslana',
    'otvorena',
    'prijata',
    'zamietnuta'
);


--
-- Name: oom_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.oom_status AS ENUM (
    'aktivne',
    'neaktivne',
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
    'sharing',
    'velkoobchod'
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
-- Name: previous_supplier_notice; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.previous_supplier_notice AS ENUM (
    'akceptacia',
    'bez_akceptacie',
    'nezasiela_sa',
    'odoslana',
    'potvrdena'
);


--
-- Name: price_direction; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.price_direction AS ENUM (
    'odber',
    'dodavka'
);


--
-- Name: pricing_model; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pricing_model AS ENUM (
    'fix',
    'spot_aditiv',
    'index_spot'
);


--
-- Name: product_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_kind AS ENUM (
    'dodavka',
    'vykup',
    'sluzba',
    'poplatok'
);


--
-- Name: product_unit; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.product_unit AS ENUM (
    'eur_mwh',
    'eur_mesiac'
);


--
-- Name: source_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.source_kind AS ENUM (
    'fve',
    'voda',
    'bioplyn',
    'plyn',
    'vietor',
    'ostatne_oze'
);


--
-- Name: source_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.source_type AS ENUM (
    'virtualna_bateria',
    'lokalny_zdroj',
    'vyrobny_zdroj',
    'green_viwa'
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
-- Name: add_business_minutes(timestamp with time zone, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_business_minutes(start timestamp with time zone, minutes integer) RETURNS timestamp with time zone
    LANGUAGE plpgsql STABLE
    AS $$
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


--
-- Name: audit_row(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_row() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: inherit_customer_segment(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.inherit_customer_segment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.segment IS NULL THEN
    IF NEW.company_id IS NOT NULL THEN
      SELECT c.segment INTO NEW.segment FROM company c WHERE c.id = NEW.company_id;
    ELSE
      SELECT p.segment INTO NEW.segment FROM contact p WHERE p.id = NEW.person_id;
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


SET default_tablespace = '';

SET default_table_access_method = heap;

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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    role public.app_user_role NOT NULL,
    team_id uuid,
    active boolean DEFAULT true NOT NULL,
    hubspot_owner_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
    diff jsonb NOT NULL
);


--
-- Name: COLUMN audit_log.changed_by; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.changed_by IS 'app_user.id z current_setting(''app.user_id''); NULL pri synchronizácii a údržbe';


--
-- Name: COLUMN audit_log.diff; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce; delete: pôvodný riadok';


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
    CONSTRAINT business_calendar_hours_check CHECK (((is_working_day AND (work_from IS NOT NULL) AND (work_to IS NOT NULL) AND (work_to > work_from)) OR ((NOT is_working_day) AND (work_from IS NULL) AND (work_to IS NULL))))
);


--
-- Name: TABLE business_calendar; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.business_calendar IS 'pracovné dni a pracovný čas (Europe/Bratislava) pre výpočet SLA';


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
-- Name: company; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    ico text,
    dic text,
    ic_dph text,
    vat_payer boolean,
    legal_form text,
    registry_entry text,
    nace text,
    statutory text,
    address text,
    segment public.customer_segment,
    payment_rating public.payment_rating,
    debts_note text,
    insolvency_note text,
    finstat_url text,
    finstat_updated_at timestamp with time zone,
    lifecycle_stage text,
    owner_id uuid,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    bank_account text,
    CONSTRAINT company_ico_format_check CHECK ((ico ~ '^[0-9]{8}$'::text)),
    CONSTRAINT company_segment_check CHECK ((segment <> 'domacnost'::public.customer_segment))
);


--
-- Name: COLUMN company.ico; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.ico IS 'IČO, 8 číslic vrátane úvodných núl';


--
-- Name: COLUMN company.bank_account; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.company.bank_account IS 'bankový účet firmy (zvyčajne IBAN), HubSpot bank_account';


--
-- Name: company_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.company_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    company_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    is_primary boolean DEFAULT false NOT NULL,
    role public.company_contact_role,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
    first_name text,
    last_name text,
    title text,
    email text,
    phone text,
    mobile text,
    "position" text,
    address text,
    segment public.customer_segment,
    lifecycle_stage text,
    source text,
    campaign text,
    owner_id uuid,
    hubspot_id text,
    posthog_distinct_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: deal_contact; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_contact (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    contact_id uuid NOT NULL,
    role text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: deal_oom; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.deal_oom (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
    segment public.customer_segment,
    name text,
    address_street text,
    address_number_supisne text,
    address_number_orientacne text,
    address_city text,
    address_zip text,
    pds text,
    pds_point_id text,
    pds_tariff text,
    voltage_level text,
    metering_type text,
    phases smallint,
    breaker_a numeric(8,2),
    reserved_capacity_kw numeric(12,3),
    max_reserved_capacity_kw numeric(12,3),
    capacity_reservation_method text,
    price_regulation text,
    excise_tax text,
    billing_period text,
    advance_payment_method text,
    advance_payment_pct numeric(5,2),
    planned_consumption_vt_mwh numeric(12,3),
    planned_consumption_nt_mwh numeric(12,3),
    planned_feed_in_mwh numeric(12,3),
    source_power_kw numeric(12,3),
    source_kind public.source_kind,
    source_type public.source_type,
    feed_in_contract_type text,
    inverter_power_kw numeric(12,3),
    panels_power_kw numeric(12,3),
    supply_from date,
    supply_to date,
    previous_supplier_notice public.previous_supplier_notice,
    previous_supplier_notice_accepted_at timestamp with time zone,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT oom_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT oom_supply_period_check CHECK (((supply_to IS NULL) OR (supply_from IS NULL) OR (supply_to >= supply_from)))
);


--
-- Name: COLUMN oom.supply_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.oom.supply_to IS 'NULL = na neurčito';


--
-- Name: contact_oom_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.contact_oom_v AS
 SELECT dc.contact_id,
    dom.oom_id,
    o.status AS oom_status,
    array_agg(DISTINCT dc.deal_id) AS deal_ids
   FROM ((public.deal_contact dc
     JOIN public.deal_oom dom ON ((dom.deal_id = dc.deal_id)))
     JOIN public.oom o ON ((o.id = dom.oom_id)))
  WHERE (o.status = ANY (ARRAY['aktivne'::public.oom_status, 'neaktivne'::public.oom_status]))
  GROUP BY dc.contact_id, dom.oom_id, o.status;


--
-- Name: contract; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid,
    company_id uuid,
    person_id uuid,
    number text,
    segment public.customer_segment,
    status public.contract_status DEFAULT 'rozpracovana'::public.contract_status NOT NULL,
    confirmed boolean DEFAULT false NOT NULL,
    auto_prolong boolean DEFAULT false NOT NULL,
    valid_from date,
    valid_to date,
    signed_at timestamp with time zone,
    payment_terms_days integer,
    consumption_tolerance numeric(5,2),
    advance_payment_pct numeric(5,2),
    hubspot_deal_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1)),
    CONSTRAINT contract_payment_terms_days_check CHECK ((payment_terms_days >= 0)),
    CONSTRAINT contract_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN contract.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN contract.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.valid_to IS 'NULL = na neurčito';


--
-- Name: COLUMN contract.consumption_tolerance; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract.consumption_tolerance IS 'tolerancia odberu v %';


--
-- Name: contract_price; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contract_price (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    contract_id uuid NOT NULL,
    oom_id uuid NOT NULL,
    product_id uuid,
    direction public.price_direction NOT NULL,
    price_vt_eur_mwh numeric(12,4),
    price_nt_eur_mwh numeric(12,4),
    additive_eur_mwh numeric(12,4),
    imbalance_price_eur_mwh numeric(12,4),
    additive_coefficient_pct numeric(7,4),
    fee_oom_eur_month numeric(12,2),
    fee_zem_eur_month numeric(12,2),
    fee_vbattery_eur_month numeric(12,2),
    fee_rk_eur_kw_month numeric(12,4),
    vbattery_program text,
    valid_from date,
    valid_to date,
    status public.contract_price_status DEFAULT 'platna'::public.contract_price_status NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contract_price_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN contract_price.fee_rk_eur_kw_month; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.fee_rk_eur_kw_month IS 'Green VIWA poplatok za rezervovanú kapacitu, €/kW/mesiac (HubSpot green_viwa_poplatok_za_rk__pomocny_)';


--
-- Name: COLUMN contract_price.valid_to; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.contract_price.valid_to IS 'NULL = na neurčito (HubSpot 31. 12. 2099)';


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
-- Name: customer_v; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.customer_v AS
 SELECT c.id,
    'B2B'::text AS customer_type,
    c.id AS company_id,
    NULL::uuid AS person_id,
    c.name,
    c.ico,
    NULL::text AS email,
    c.segment,
    c.owner_id
   FROM public.company c
UNION ALL
 SELECT p.id,
    'B2C'::text AS customer_type,
    NULL::uuid AS company_id,
    p.id AS person_id,
    concat_ws(' '::text, p.first_name, p.last_name) AS name,
    NULL::text AS ico,
    p.email,
    p.segment,
    p.owner_id
   FROM public.contact p
  WHERE (NOT (EXISTS ( SELECT 1
           FROM public.company_contact cc
          WHERE (cc.contact_id = p.id))));


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
    campaign text,
    source text,
    expected_close date,
    closed_at timestamp with time zone,
    lost_reason text,
    owner_id uuid,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT deal_customer_check CHECK ((num_nonnulls(company_id, person_id) = 1))
);


--
-- Name: COLUMN deal.segment; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';


--
-- Name: COLUMN deal.closed_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.deal.closed_at IS 'skutočné uzavretie dealu (nie dátum nákupu)';


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
-- Name: offer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    deal_id uuid NOT NULL,
    version integer DEFAULT 1 NOT NULL,
    status public.offer_status DEFAULT 'koncept'::public.offer_status NOT NULL,
    valid_until date,
    total_eur numeric(12,2),
    pdf_url text,
    sent_at timestamp with time zone,
    opened_at timestamp with time zone,
    hubspot_quote_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT offer_version_check CHECK ((version > 0))
);


--
-- Name: offer_item; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.offer_item (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    offer_id uuid NOT NULL,
    oom_id uuid,
    product_id uuid,
    price_eur_mwh numeric(12,4),
    volume_mwh numeric(12,3),
    fee_eur_month numeric(12,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: pipeline; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: pipeline_stage; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.pipeline_stage (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    pipeline_id uuid NOT NULL,
    name text NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    probability numeric(3,2),
    is_closed boolean DEFAULT false NOT NULL,
    is_won boolean DEFAULT false NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT pipeline_stage_probability_check CHECK (((probability >= (0)::numeric) AND (probability <= (1)::numeric))),
    CONSTRAINT pipeline_stage_won_is_closed_check CHECK (((NOT is_won) OR is_closed))
);


--
-- Name: product; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.product (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    kind public.product_kind NOT NULL,
    pricing_model public.pricing_model,
    unit public.product_unit NOT NULL,
    list_price numeric(12,4),
    valid_from date,
    valid_to date,
    hubspot_product_id text,
    hubspot_contract_codes text[],
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT product_validity_check CHECK (((valid_to IS NULL) OR (valid_from IS NULL) OR (valid_to >= valid_from)))
);


--
-- Name: COLUMN product.pricing_model; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.pricing_model IS 'pri SPOT produktoch je aditív v contract_price.additive_eur_mwh';


--
-- Name: COLUMN product.list_price; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.product.list_price IS 'v jednotke podľa unit (€/MWh alebo €/mesiac)';


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
-- Name: team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    hubspot_id text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


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
-- Name: app_user app_user_hubspot_owner_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_hubspot_owner_id_key UNIQUE (hubspot_owner_id);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (id);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: business_calendar business_calendar_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.business_calendar
    ADD CONSTRAINT business_calendar_pkey PRIMARY KEY (date);


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
-- Name: contract contract_hubspot_deal_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_hubspot_deal_id_key UNIQUE (hubspot_deal_id);


--
-- Name: contract contract_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_number_key UNIQUE (number);


--
-- Name: contract contract_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_pkey PRIMARY KEY (id);


--
-- Name: contract_price contract_price_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_hubspot_id_key UNIQUE (hubspot_id);


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
-- Name: fve_project fve_project_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_pkey PRIMARY KEY (id);


--
-- Name: offer offer_deal_id_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deal_id_version_key UNIQUE (deal_id, version);


--
-- Name: offer offer_hubspot_quote_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_hubspot_quote_id_key UNIQUE (hubspot_quote_id);


--
-- Name: offer_item offer_item_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_pkey PRIMARY KEY (id);


--
-- Name: offer offer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_pkey PRIMARY KEY (id);


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
-- Name: oom oom_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_pkey PRIMARY KEY (id);


--
-- Name: pipeline pipeline_hubspot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_hubspot_id_key UNIQUE (hubspot_id);


--
-- Name: pipeline pipeline_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline
    ADD CONSTRAINT pipeline_name_key UNIQUE (name);


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
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (id);


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
-- Name: app_user_team_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX app_user_team_id_idx ON public.app_user USING btree (team_id);


--
-- Name: audit_log_changed_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_at_idx ON public.audit_log USING btree (changed_at);


--
-- Name: audit_log_changed_by_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_changed_by_idx ON public.audit_log USING btree (changed_by);


--
-- Name: audit_log_record_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_log_record_idx ON public.audit_log USING btree (table_name, record_id, changed_at);


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
-- Name: company_contact_one_primary_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_contact_one_primary_key ON public.company_contact USING btree (contact_id) WHERE is_primary;


--
-- Name: company_ico_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX company_ico_key ON public.company USING btree (ico) WHERE (ico IS NOT NULL);


--
-- Name: company_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX company_owner_id_idx ON public.company USING btree (owner_id);


--
-- Name: consent_contact_purpose_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX consent_contact_purpose_idx ON public.consent USING btree (contact_id, purpose, recorded_at DESC);


--
-- Name: contact_email_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_email_idx ON public.contact USING btree (lower(email));


--
-- Name: contact_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_owner_id_idx ON public.contact USING btree (owner_id);


--
-- Name: contact_posthog_distinct_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_posthog_distinct_id_idx ON public.contact USING btree (posthog_distinct_id);


--
-- Name: contract_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_company_id_idx ON public.contract USING btree (company_id);


--
-- Name: contract_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_person_id_idx ON public.contract USING btree (person_id);


--
-- Name: contract_price_contract_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_contract_id_idx ON public.contract_price USING btree (contract_id);


--
-- Name: contract_price_one_valid_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contract_price_one_valid_key ON public.contract_price USING btree (contract_id, oom_id) WHERE (status = 'platna'::public.contract_price_status);


--
-- Name: contract_price_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_oom_id_idx ON public.contract_price USING btree (oom_id);


--
-- Name: contract_price_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contract_price_product_id_idx ON public.contract_price USING btree (product_id);


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
-- Name: deal_contact_contact_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_contact_contact_id_idx ON public.deal_contact USING btree (contact_id);


--
-- Name: deal_oom_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_oom_oom_id_idx ON public.deal_oom USING btree (oom_id);


--
-- Name: deal_owner_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_owner_id_idx ON public.deal USING btree (owner_id);


--
-- Name: deal_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_person_id_idx ON public.deal USING btree (person_id);


--
-- Name: deal_pipeline_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_pipeline_id_idx ON public.deal USING btree (pipeline_id);


--
-- Name: deal_stage_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX deal_stage_id_idx ON public.deal USING btree (stage_id, pipeline_id);


--
-- Name: fve_project_deal_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX fve_project_deal_id_idx ON public.fve_project USING btree (deal_id);


--
-- Name: offer_item_offer_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_offer_id_idx ON public.offer_item USING btree (offer_id);


--
-- Name: offer_item_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_oom_id_idx ON public.offer_item USING btree (oom_id);


--
-- Name: offer_item_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX offer_item_product_id_idx ON public.offer_item USING btree (product_id);


--
-- Name: oom_company_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_company_id_idx ON public.oom USING btree (company_id);


--
-- Name: oom_device_oom_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_device_oom_id_idx ON public.oom_device USING btree (oom_id);


--
-- Name: oom_person_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_person_id_idx ON public.oom USING btree (person_id);


--
-- Name: oom_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX oom_status_idx ON public.oom USING btree (status);


--
-- Name: product_hubspot_contract_codes_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_contract_codes_idx ON public.product USING gin (hubspot_contract_codes);


--
-- Name: product_hubspot_product_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX product_hubspot_product_id_idx ON public.product USING btree (hubspot_product_id);


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
-- Name: activity trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: app_user trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.audit_row();


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
-- Name: contract_price trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract_purchase trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: conversation trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.audit_row();


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
-- Name: fve_project trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: offer_item trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: oom_device trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: pipeline_stage trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: product trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.audit_row();


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
-- Name: team trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: voucher trg_audit; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.audit_row();


--
-- Name: contract trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.contract FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: deal trg_inherit_segment; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON public.deal FOR EACH ROW EXECUTE FUNCTION public.inherit_customer_segment();


--
-- Name: activity trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.activity FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: app_user trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.app_user FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: contract_price trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_price FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: contract_purchase trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.contract_purchase FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: conversation trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.conversation FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: fve_project trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.fve_project FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: offer_item trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.offer_item FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: oom_device trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.oom_device FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: pipeline_stage trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.pipeline_stage FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: product trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.product FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: team trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.team FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: voucher trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.voucher FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


--
-- Name: web_event trg_set_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON public.web_event FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


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
-- Name: app_user app_user_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.team(id);


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
-- Name: contract contract_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract
    ADD CONSTRAINT contract_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: contract_price contract_price_contract_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_contract_id_fkey FOREIGN KEY (contract_id) REFERENCES public.contract(id);


--
-- Name: contract_price contract_price_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contract_price
    ADD CONSTRAINT contract_price_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


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
-- Name: deal deal_stage_in_pipeline_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.deal
    ADD CONSTRAINT deal_stage_in_pipeline_fkey FOREIGN KEY (stage_id, pipeline_id) REFERENCES public.pipeline_stage(id, pipeline_id);


--
-- Name: fve_project fve_project_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fve_project
    ADD CONSTRAINT fve_project_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: offer offer_deal_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer
    ADD CONSTRAINT offer_deal_id_fkey FOREIGN KEY (deal_id) REFERENCES public.deal(id);


--
-- Name: offer_item offer_item_offer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_offer_id_fkey FOREIGN KEY (offer_id) REFERENCES public.offer(id) ON DELETE CASCADE;


--
-- Name: offer_item offer_item_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id);


--
-- Name: offer_item offer_item_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.offer_item
    ADD CONSTRAINT offer_item_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.product(id);


--
-- Name: oom oom_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.company(id);


--
-- Name: oom_device oom_device_oom_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom_device
    ADD CONSTRAINT oom_device_oom_id_fkey FOREIGN KEY (oom_id) REFERENCES public.oom(id) ON DELETE CASCADE;


--
-- Name: oom oom_person_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oom
    ADD CONSTRAINT oom_person_id_fkey FOREIGN KEY (person_id) REFERENCES public.contact(id);


--
-- Name: pipeline_stage pipeline_stage_pipeline_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.pipeline_stage
    ADD CONSTRAINT pipeline_stage_pipeline_id_fkey FOREIGN KEY (pipeline_id) REFERENCES public.pipeline(id);


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
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('0001'),
    ('0002'),
    ('0003');
