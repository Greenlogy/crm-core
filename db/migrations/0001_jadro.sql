-- 0001_jadro.sql – databáza jadra podľa dátového modelu v0.3.1 (docs/01-datovy-model.md)
--
-- Poradie: enumy, tabuľky (ľudia a prístup, energetická doména, obchod,
-- komunikácia a SLA, marketing, systém), funkcie a spúšťače, pohľady.
-- Rozhodnutia k modulu 1: docs/rozhodnutia.md (2026-10-10, 2026-10-11).
-- Výpočtové pohľady (výnosy, marža, provízie) prídu v samostatnej migrácii.

-- migrate:up

-- ============================================================================
-- Enumy
-- ============================================================================

-- Ľudia, firmy a prístup
CREATE TYPE app_user_role AS ENUM ('admin', 'vedenie', 'obchodnik', 'servis', 'marketing');
-- Segment zákazníka, OOM, dealu a zmluvy (firma nikdy 'domacnost')
CREATE TYPE customer_segment AS ENUM ('domacnost', 'firma', 'dodavatel');
CREATE TYPE payment_rating AS ENUM ('A', 'B', 'C', 'D', 'E', 'X');
CREATE TYPE company_contact_role AS ENUM ('statutar', 'kontaktna_osoba', 'fakturacia', 'ine');

-- Energetická doména
CREATE TYPE oom_type AS ENUM ('spotreba', 'vyroba', 'sharing', 'velkoobchod');
CREATE TYPE oom_status AS ENUM ('aktivne', 'neaktivne', 'zrusene', 'odidene', 'prepisane');
CREATE TYPE source_kind AS ENUM ('fve', 'voda', 'bioplyn', 'plyn', 'vietor', 'ostatne_oze');
CREATE TYPE source_type AS ENUM ('virtualna_bateria', 'lokalny_zdroj', 'vyrobny_zdroj', 'green_viwa');
CREATE TYPE previous_supplier_notice AS ENUM (
  'akceptacia', 'bez_akceptacie', 'nezasiela_sa', 'odoslana', 'potvrdena'
);
CREATE TYPE device_type AS ENUM ('striedac', 'panely', 'bateria', 'tepelne_cerpadlo', 'wallbox');
CREATE TYPE switch_message_type AS ENUM ('xml433', 'xml43d');
CREATE TYPE switch_segment AS ENUM ('domacnost', 'organizacia');
CREATE TYPE product_kind AS ENUM ('dodavka', 'vykup', 'sluzba', 'poplatok');
CREATE TYPE product_unit AS ENUM ('eur_mwh', 'eur_mesiac');
CREATE TYPE pricing_model AS ENUM ('fix', 'spot_aditiv', 'index_spot');
CREATE TYPE contract_status AS ENUM (
  'rozpracovana', 'caka_na_podpis', 'podpisana', 'caka_na_zaradenie', 'aktivna',
  'ukoncena', 'vypoved_neakceptovana', 'zmena_neuspesna'
);
CREATE TYPE price_direction AS ENUM ('odber', 'dodavka');
CREATE TYPE contract_price_status AS ENUM ('platna', 'neplatna');

-- Obchod
CREATE TYPE offer_status AS ENUM ('koncept', 'odoslana', 'otvorena', 'prijata', 'zamietnuta');
CREATE TYPE commission_status AS ENUM (
  'vypocitana', 'cakajuca', 'uplatnena', 'schvalena', 'vyplatena', 'zrusena'
);
CREATE TYPE fve_program AS ENUM ('eco', 'standard', 'premium');
CREATE TYPE fve_status AS ENUM (
  'ponuka_odoslana', 'ponuka_akceptovana', 'zaloha_uhradena', 'dielo_prevzate', 'dielo_uhradene'
);

-- Komunikácia, marketing, systém
CREATE TYPE activity_type AS ENUM ('email', 'hovor', 'chat', 'fb', 'poznamka', 'uloha', 'web', 'kampan');
CREATE TYPE conversation_channel AS ENUM ('email', 'web_chat', 'facebook', 'telefon');
CREATE TYPE consent_purpose AS ENUM (
  'marketing_greenlogy', 'blog', 'produkty_a_sluzby', 'individualna_komunikacia', 'zakaznicke_sluzby'
);
CREATE TYPE consent_status AS ENUM ('udeleny', 'odvolany');
CREATE TYPE audit_action AS ENUM ('insert', 'update', 'delete');

-- ============================================================================
-- Ľudia, firmy a prístup
-- ============================================================================

CREATE TABLE team (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,
  hubspot_id  text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE app_user (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email             text NOT NULL,
  name              text NOT NULL,
  role              app_user_role NOT NULL,
  team_id           uuid REFERENCES team (id),
  active            boolean NOT NULL DEFAULT true,
  hubspot_owner_id  text UNIQUE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
-- Prihlásenie cez Cloudflare Access podľa e-mailu, bez ohľadu na veľkosť písmen.
CREATE UNIQUE INDEX app_user_email_key ON app_user (lower(email));
CREATE INDEX app_user_team_id_idx ON app_user (team_id);

CREATE TABLE company (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text NOT NULL,
  ico                 text,
  dic                 text,
  ic_dph              text,
  vat_payer           boolean,
  legal_form          text,
  registry_entry      text,
  nace                text,
  statutory           text,
  address             text,
  segment             customer_segment,
  payment_rating      payment_rating,
  debts_note          text,
  insolvency_note     text,
  finstat_url         text,
  finstat_updated_at  timestamptz,
  lifecycle_stage     text,
  owner_id            uuid REFERENCES app_user (id),
  hubspot_id          text UNIQUE,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT company_segment_check CHECK (segment <> 'domacnost'),
  CONSTRAINT company_ico_format_check CHECK (ico ~ '^[0-9]{8}$')
);
COMMENT ON COLUMN company.ico IS 'IČO, 8 číslic vrátane úvodných núl';
CREATE UNIQUE INDEX company_ico_key ON company (ico) WHERE ico IS NOT NULL;
CREATE INDEX company_owner_id_idx ON company (owner_id);

CREATE TABLE contact (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  first_name           text,
  last_name            text,
  title                text,
  email                text,
  phone                text,
  mobile               text,
  position             text,
  address              text,
  segment              customer_segment,
  lifecycle_stage      text,
  source               text,
  campaign             text,
  owner_id             uuid REFERENCES app_user (id),
  hubspot_id           text UNIQUE,
  posthog_distinct_id  text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
-- E-mail je kľúč na párovanie s PostHog, Chatwoot, Brevo a CloudTalk.
CREATE INDEX contact_email_idx ON contact (lower(email));
CREATE INDEX contact_owner_id_idx ON contact (owner_id);
CREATE INDEX contact_posthog_distinct_id_idx ON contact (posthog_distinct_id);

CREATE TABLE company_contact (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id  uuid NOT NULL REFERENCES company (id) ON DELETE CASCADE,
  contact_id  uuid NOT NULL REFERENCES contact (id) ON DELETE CASCADE,
  is_primary  boolean NOT NULL DEFAULT false,
  role        company_contact_role,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (company_id, contact_id)
);
CREATE INDEX company_contact_contact_id_idx ON company_contact (contact_id);
-- Kontakt má najviac jednu hlavnú firmu.
CREATE UNIQUE INDEX company_contact_one_primary_key ON company_contact (contact_id) WHERE is_primary;

-- ============================================================================
-- Energetická doména
-- ============================================================================

CREATE TABLE oom (
  id                                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id                           uuid REFERENCES company (id),
  person_id                            uuid REFERENCES contact (id),
  eic                                  text NOT NULL UNIQUE,
  type                                 oom_type NOT NULL,
  status                               oom_status NOT NULL,
  segment                              customer_segment,
  name                                 text,
  address_street                       text,
  address_number_supisne               text,
  address_number_orientacne            text,
  address_city                         text,
  address_zip                          text,
  -- distribúcia
  pds                                  text,
  pds_point_id                         text,
  pds_tariff                           text,
  voltage_level                        text,
  metering_type                        text,
  phases                               smallint,
  breaker_a                            numeric(8,2),
  reserved_capacity_kw                 numeric(12,3),
  max_reserved_capacity_kw             numeric(12,3),
  capacity_reservation_method          text,
  -- fakturácia
  price_regulation                     text,
  excise_tax                           text,
  billing_period                       text,
  advance_payment_method               text,
  advance_payment_pct                  numeric(5,2),
  -- objemy a výroba
  planned_consumption_vt_mwh           numeric(12,3),
  planned_consumption_nt_mwh           numeric(12,3),
  planned_feed_in_mwh                  numeric(12,3),
  source_power_kw                      numeric(12,3),
  source_kind                          source_kind,
  source_type                          source_type,
  feed_in_contract_type                text,
  inverter_power_kw                    numeric(12,3),
  panels_power_kw                      numeric(12,3),
  -- dodávka a zmena dodávateľa
  supply_from                          date,
  supply_to                            date,
  previous_supplier_notice             previous_supplier_notice,
  previous_supplier_notice_accepted_at timestamptz,
  hubspot_id                           text UNIQUE,
  created_at                           timestamptz NOT NULL DEFAULT now(),
  updated_at                           timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oom_customer_check CHECK (num_nonnulls(company_id, person_id) = 1),
  CONSTRAINT oom_supply_period_check CHECK (supply_to IS NULL OR supply_from IS NULL OR supply_to >= supply_from)
);
COMMENT ON COLUMN oom.supply_to IS 'NULL = na neurčito';
CREATE INDEX oom_company_id_idx ON oom (company_id);
CREATE INDEX oom_person_id_idx ON oom (person_id);
CREATE INDEX oom_status_idx ON oom (status);

CREATE TABLE oom_device (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id        uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
  device_type   device_type NOT NULL,
  brand         text,
  model         text,
  power_kw      numeric(12,3),
  capacity_kwh  numeric(12,3),
  count         integer NOT NULL DEFAULT 1 CHECK (count > 0),
  details       jsonb,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX oom_device_oom_id_idx ON oom_device (oom_id);

CREATE TABLE product (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code                    text NOT NULL UNIQUE,
  name                    text NOT NULL,
  kind                    product_kind NOT NULL,
  pricing_model           pricing_model,
  unit                    product_unit NOT NULL,
  list_price              numeric(12,4),
  valid_from              date,
  valid_to                date,
  hubspot_product_id      text,
  hubspot_contract_codes  text[],
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_validity_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
COMMENT ON COLUMN product.list_price IS 'v jednotke podľa unit (€/MWh alebo €/mesiac)';
COMMENT ON COLUMN product.pricing_model IS 'pri SPOT produktoch je aditív v contract_price.additive_eur_mwh';
CREATE INDEX product_hubspot_product_id_idx ON product (hubspot_product_id);
CREATE INDEX product_hubspot_contract_codes_idx ON product USING gin (hubspot_contract_codes);

-- ============================================================================
-- Obchod
-- ============================================================================

CREATE TABLE pipeline (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL UNIQUE,
  sort_order  integer NOT NULL DEFAULT 0,
  hubspot_id  text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE pipeline_stage (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  pipeline_id  uuid NOT NULL REFERENCES pipeline (id),
  name         text NOT NULL,
  sort_order   integer NOT NULL DEFAULT 0,
  probability  numeric(3,2) CHECK (probability BETWEEN 0 AND 1),
  is_closed    boolean NOT NULL DEFAULT false,
  is_won       boolean NOT NULL DEFAULT false,
  hubspot_id   text UNIQUE,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (pipeline_id, name),
  -- cieľ zloženého kľúča z dealu: štádium musí patriť do pipeline dealu
  UNIQUE (id, pipeline_id),
  CONSTRAINT pipeline_stage_won_is_closed_check CHECK (NOT is_won OR is_closed)
);

CREATE TABLE deal (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id      uuid REFERENCES company (id),
  person_id       uuid REFERENCES contact (id),
  pipeline_id     uuid NOT NULL REFERENCES pipeline (id),
  stage_id        uuid NOT NULL,
  name            text NOT NULL,
  segment         customer_segment,
  campaign        text,
  source          text,
  expected_close  date,
  closed_at       timestamptz,
  lost_reason     text,
  owner_id        uuid REFERENCES app_user (id),
  hubspot_id      text UNIQUE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT deal_customer_check CHECK (num_nonnulls(company_id, person_id) = 1),
  CONSTRAINT deal_stage_in_pipeline_fkey FOREIGN KEY (stage_id, pipeline_id)
    REFERENCES pipeline_stage (id, pipeline_id)
);
COMMENT ON COLUMN deal.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';
COMMENT ON COLUMN deal.closed_at IS 'skutočné uzavretie dealu (nie dátum nákupu)';
CREATE INDEX deal_company_id_idx ON deal (company_id);
CREATE INDEX deal_person_id_idx ON deal (person_id);
CREATE INDEX deal_pipeline_id_idx ON deal (pipeline_id);
CREATE INDEX deal_stage_id_idx ON deal (stage_id, pipeline_id);
CREATE INDEX deal_owner_id_idx ON deal (owner_id);

CREATE TABLE deal_oom (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL REFERENCES deal (id) ON DELETE CASCADE,
  oom_id      uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deal_id, oom_id)
);
CREATE INDEX deal_oom_oom_id_idx ON deal_oom (oom_id);

CREATE TABLE deal_contact (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL REFERENCES deal (id) ON DELETE CASCADE,
  contact_id  uuid NOT NULL REFERENCES contact (id) ON DELETE CASCADE,
  role        text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deal_id, contact_id)
);
CREATE INDEX deal_contact_contact_id_idx ON deal_contact (contact_id);

CREATE TABLE contract (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- zatiaľ 1 deal = 1 zmluva (rozhodnutie 2026-10-10)
  deal_id                 uuid UNIQUE REFERENCES deal (id),
  company_id              uuid REFERENCES company (id),
  person_id               uuid REFERENCES contact (id),
  number                  text UNIQUE,
  segment                 customer_segment,
  status                  contract_status NOT NULL DEFAULT 'rozpracovana',
  confirmed               boolean NOT NULL DEFAULT false,
  auto_prolong            boolean NOT NULL DEFAULT false,
  valid_from              date,
  valid_to                date,
  signed_at               timestamptz,
  payment_terms_days      integer CHECK (payment_terms_days >= 0),
  consumption_tolerance   numeric(5,2),
  advance_payment_pct     numeric(5,2),
  hubspot_deal_id         text UNIQUE,
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_customer_check CHECK (num_nonnulls(company_id, person_id) = 1),
  CONSTRAINT contract_validity_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
COMMENT ON COLUMN contract.valid_to IS 'NULL = na neurčito';
COMMENT ON COLUMN contract.consumption_tolerance IS 'tolerancia odberu v %';
COMMENT ON COLUMN contract.segment IS 'preberá sa od zákazníka pri vzniku, ak nie je zadaný';
CREATE INDEX contract_company_id_idx ON contract (company_id);
CREATE INDEX contract_person_id_idx ON contract (person_id);

CREATE TABLE contract_price (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id               uuid NOT NULL REFERENCES contract (id),
  oom_id                    uuid NOT NULL REFERENCES oom (id),
  product_id                uuid REFERENCES product (id),
  direction                 price_direction NOT NULL,
  price_vt_eur_mwh          numeric(12,4),
  price_nt_eur_mwh          numeric(12,4),
  additive_eur_mwh          numeric(12,4),
  imbalance_price_eur_mwh   numeric(12,4),
  additive_coefficient_pct  numeric(7,4),
  fee_oom_eur_month         numeric(12,2),
  fee_zem_eur_month         numeric(12,2),
  fee_vbattery_eur_month    numeric(12,2),
  fee_rk_eur_kw_month       numeric(12,4),
  vbattery_program          text,
  valid_from                date,
  valid_to                  date,
  status                    contract_price_status NOT NULL DEFAULT 'platna',
  hubspot_id                text UNIQUE,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_price_validity_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from)
);
COMMENT ON COLUMN contract_price.valid_to IS 'NULL = na neurčito (HubSpot 31. 12. 2099)';
COMMENT ON COLUMN contract_price.fee_rk_eur_kw_month IS 'Green VIWA poplatok za rezervovanú kapacitu, €/kW/mesiac (HubSpot green_viwa_poplatok_za_rk__pomocny_)';
CREATE INDEX contract_price_contract_id_idx ON contract_price (contract_id);
CREATE INDEX contract_price_oom_id_idx ON contract_price (oom_id);
CREATE INDEX contract_price_product_id_idx ON contract_price (product_id);
-- Najviac jedna platná cena na OOM a zmluvu (rozhodnutie 2026-10-10).
CREATE UNIQUE INDEX contract_price_one_valid_key ON contract_price (contract_id, oom_id) WHERE status = 'platna';

-- Nákupné ceny zmluvy. Zdroj je Cockpit; jedna nákupná tranža môže patriť viacerým zmluvám.
CREATE TABLE contract_purchase (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id    uuid NOT NULL REFERENCES contract (id),
  product_code   text NOT NULL,
  delivery_year  smallint NOT NULL CHECK (delivery_year BETWEEN 2000 AND 2100),
  priced_on      date NOT NULL,
  price_eur_mwh  numeric(12,4) NOT NULL,
  cockpit_ref    text,
  hubspot_id     text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN contract_purchase.product_code IS 'produkt nákupu, napr. SK BL CAL2027';
COMMENT ON COLUMN contract_purchase.priced_on IS 'dátum nákupu (HubSpot: close date dealu / dátum nákupnej ceny)';
COMMENT ON COLUMN contract_purchase.cockpit_ref IS 'odkaz na nákupnú tranžu v Cockpite; môže sa opakovať pri viacerých zmluvách';
COMMENT ON COLUMN contract_purchase.hubspot_id IS 'záznam Nákupné ceny 2-22997964; jeden záznam patrí viacerým zmluvám';
CREATE INDEX contract_purchase_contract_id_idx ON contract_purchase (contract_id);
CREATE INDEX contract_purchase_cockpit_ref_idx ON contract_purchase (cockpit_ref);
CREATE UNIQUE INDEX contract_purchase_hubspot_key ON contract_purchase (contract_id, hubspot_id) WHERE hubspot_id IS NOT NULL;

CREATE TABLE supplier_switch (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id                uuid NOT NULL REFERENCES oom (id),
  deal_id               uuid REFERENCES deal (id),
  message_type          switch_message_type NOT NULL,
  segment               switch_segment,
  message_date          date,
  effective_date        date,
  point_kind            text,
  metering_type         text,
  customer_notified_at  timestamptz,
  hubspot_id            text UNIQUE,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX supplier_switch_oom_id_idx ON supplier_switch (oom_id);
CREATE INDEX supplier_switch_deal_id_idx ON supplier_switch (deal_id);

CREATE TABLE offer (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id           uuid NOT NULL REFERENCES deal (id),
  version           integer NOT NULL DEFAULT 1 CHECK (version > 0),
  status            offer_status NOT NULL DEFAULT 'koncept',
  valid_until       date,
  total_eur         numeric(12,2),
  pdf_url           text,
  sent_at           timestamptz,
  opened_at         timestamptz,
  hubspot_quote_id  text UNIQUE,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  UNIQUE (deal_id, version)
);

CREATE TABLE offer_item (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id       uuid NOT NULL REFERENCES offer (id) ON DELETE CASCADE,
  oom_id         uuid REFERENCES oom (id),
  product_id     uuid REFERENCES product (id),
  price_eur_mwh  numeric(12,4),
  volume_mwh     numeric(12,3),
  fee_eur_month  numeric(12,2),
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX offer_item_offer_id_idx ON offer_item (offer_id);
CREATE INDEX offer_item_oom_id_idx ON offer_item (oom_id);
CREATE INDEX offer_item_product_id_idx ON offer_item (product_id);

CREATE TABLE commission_rule (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   uuid REFERENCES product (id),
  pipeline_id  uuid REFERENCES pipeline (id),
  segment      text,
  rate_type    text NOT NULL,
  rate_value   numeric(12,4) NOT NULL,
  valid_from   date NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT commission_rule_target_check CHECK (num_nonnulls(product_id, pipeline_id) >= 1)
);
CREATE INDEX commission_rule_product_id_idx ON commission_rule (product_id);
CREATE INDEX commission_rule_pipeline_id_idx ON commission_rule (pipeline_id);

CREATE TABLE commission (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid NOT NULL REFERENCES deal (id),
  user_id     uuid NOT NULL REFERENCES app_user (id),
  base_eur    numeric(12,2),
  amount_eur  numeric(12,2),
  period      date,
  status      commission_status NOT NULL DEFAULT 'vypocitana',
  pdf_url     text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN commission.period IS 'prvý deň obdobia (mesiaca), za ktoré sa provízia vypláca';
CREATE INDEX commission_deal_id_idx ON commission (deal_id);
CREATE INDEX commission_user_id_idx ON commission (user_id);

CREATE TABLE voucher (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id     uuid REFERENCES deal (id),
  contact_id  uuid REFERENCES contact (id),
  code        text UNIQUE,
  value_eur   numeric(12,2),
  sent_at     timestamptz,
  redeemed    boolean NOT NULL DEFAULT false,
  status      text,
  hubspot_id  text UNIQUE,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX voucher_deal_id_idx ON voucher (deal_id);
CREATE INDEX voucher_contact_id_idx ON voucher (contact_id);

CREATE TABLE referral (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_contact_id  uuid NOT NULL REFERENCES contact (id),
  deal_id              uuid REFERENCES deal (id),
  discount_eur         numeric(12,2),
  reward_eur           numeric(12,2),
  reward_type          text,
  status               text,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX referral_referrer_contact_id_idx ON referral (referrer_contact_id);
CREATE INDEX referral_deal_id_idx ON referral (deal_id);

CREATE TABLE fve_project (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id                 uuid NOT NULL REFERENCES deal (id),
  program                 fve_program,
  price_with_vat          numeric(12,2),
  vat_rate                numeric(5,2),
  advance_eur             numeric(12,2),
  status                  fve_status,
  partner_commission_pct  numeric(5,2),
  partner_name            text,
  discount_savings_eur    numeric(12,2),
  nep_settlement_eur      numeric(12,2),
  created_at              timestamptz NOT NULL DEFAULT now(),
  updated_at              timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN fve_project.vat_rate IS 'sadzba DPH v % (napr. 23.00)';
COMMENT ON COLUMN fve_project.partner_commission_pct IS 'provízia v % zo základu (HubSpot provizia_v__)';
COMMENT ON COLUMN fve_project.partner_name IS 'obchodník NEP; ak je vyplnený, Greenlogy má polovicu provízie (HubSpot obchodnik_nep)';
COMMENT ON COLUMN fve_project.discount_savings_eur IS 'úspora na zľave, max. 1 500 € s DPH (HubSpot uspora_na_zlave__max__1500_eur_)';
COMMENT ON COLUMN fve_project.nep_settlement_eur IS 'doúčtovanie z NEPu (HubSpot douctovanie_z_nepu)';
CREATE INDEX fve_project_deal_id_idx ON fve_project (deal_id);

-- ============================================================================
-- Komunikácia, servis a SLA
-- ============================================================================

CREATE TABLE conversation (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  chatwoot_conversation_id  bigint UNIQUE,
  channel                   conversation_channel NOT NULL,
  contact_id                uuid REFERENCES contact (id),
  company_id                uuid REFERENCES company (id),
  oom_id                    uuid REFERENCES oom (id),
  product                   text,
  quality_standard          text,
  status                    text,
  opened_at                 timestamptz NOT NULL,
  first_response_at         timestamptz,
  resolved_at               timestamptz,
  assignee_id               uuid REFERENCES app_user (id),
  rating                    smallint,
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);
COMMENT ON COLUMN conversation.quality_standard IS 'regulačný štandard kvality';
CREATE INDEX conversation_contact_id_idx ON conversation (contact_id);
CREATE INDEX conversation_company_id_idx ON conversation (company_id);
CREATE INDEX conversation_oom_id_idx ON conversation (oom_id);
CREATE INDEX conversation_assignee_id_idx ON conversation (assignee_id);
CREATE INDEX conversation_opened_at_idx ON conversation (opened_at);

CREATE TABLE activity (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type             activity_type NOT NULL,
  direction        text,
  company_id       uuid REFERENCES company (id),
  contact_id       uuid REFERENCES contact (id),
  deal_id          uuid REFERENCES deal (id),
  oom_id           uuid REFERENCES oom (id),
  conversation_id  uuid REFERENCES conversation (id),
  user_id          uuid REFERENCES app_user (id),
  occurred_at      timestamptz NOT NULL,
  subject          text,
  body_preview     text,
  source           text,
  source_id        text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source, source_id)
);
-- Časová os: indexy na cudzie kľúče sú zároveň zoradené podľa času.
CREATE INDEX activity_occurred_at_idx ON activity (occurred_at);
CREATE INDEX activity_company_id_idx ON activity (company_id, occurred_at);
CREATE INDEX activity_contact_id_idx ON activity (contact_id, occurred_at);
CREATE INDEX activity_deal_id_idx ON activity (deal_id, occurred_at);
CREATE INDEX activity_oom_id_idx ON activity (oom_id, occurred_at);
CREATE INDEX activity_conversation_id_idx ON activity (conversation_id, occurred_at);
CREATE INDEX activity_user_id_idx ON activity (user_id, occurred_at);

CREATE TABLE call (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  activity_id        uuid NOT NULL UNIQUE REFERENCES activity (id) ON DELETE CASCADE,
  cloudtalk_call_id  text UNIQUE,
  duration_s         integer CHECK (duration_s >= 0),
  recording_url      text,
  transcript         text,
  agent_id           uuid REFERENCES app_user (id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX call_agent_id_idx ON call (agent_id);

CREATE TABLE sla_record (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id     uuid NOT NULL UNIQUE REFERENCES conversation (id) ON DELETE CASCADE,
  first_response_due  timestamptz NOT NULL,
  first_response_at   timestamptz,
  resolution_due      timestamptz NOT NULL,
  resolved_at         timestamptz,
  first_response_met  boolean,
  resolution_met      boolean,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE business_calendar (
  date            date PRIMARY KEY,
  is_working_day  boolean NOT NULL,
  work_from       time,
  work_to         time,
  note            text,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT business_calendar_hours_check CHECK (
    (is_working_day AND work_from IS NOT NULL AND work_to IS NOT NULL AND work_to > work_from)
    OR (NOT is_working_day AND work_from IS NULL AND work_to IS NULL)
  )
);
COMMENT ON TABLE business_calendar IS 'pracovné dni a pracovný čas (Europe/Bratislava) pre výpočet SLA';

-- ============================================================================
-- Marketing a súhlasy
-- ============================================================================

CREATE TABLE consent (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id               uuid NOT NULL REFERENCES contact (id),
  purpose                  consent_purpose NOT NULL,
  status                   consent_status NOT NULL,
  legal_basis              text,
  source                   text,
  recorded_at              timestamptz NOT NULL,
  hubspot_subscription_id  text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now()
);
-- História súhlasov; platný je posledný záznam pre kontakt a účel.
CREATE INDEX consent_contact_purpose_idx ON consent (contact_id, purpose, recorded_at DESC);

CREATE TABLE segment (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name           text NOT NULL UNIQUE,
  definition     jsonb,
  sync_to_brevo  boolean NOT NULL DEFAULT false,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE campaign (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name               text NOT NULL,
  channel            text,
  brevo_campaign_id  text UNIQUE,
  sent_at            timestamptz,
  stats              jsonb,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE web_event (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id           uuid REFERENCES contact (id),
  posthog_distinct_id  text,
  event                text NOT NULL,
  url                  text,
  occurred_at          timestamptz NOT NULL,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX web_event_contact_id_idx ON web_event (contact_id, occurred_at);
CREATE INDEX web_event_posthog_distinct_id_idx ON web_event (posthog_distinct_id);
CREATE INDEX web_event_occurred_at_idx ON web_event (occurred_at);

-- ============================================================================
-- Systém
-- ============================================================================

CREATE TABLE audit_log (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  table_name  text NOT NULL,
  record_id   uuid NOT NULL,
  action      audit_action NOT NULL,
  changed_by  uuid,
  changed_at  timestamptz NOT NULL DEFAULT now(),
  diff        jsonb NOT NULL
);
COMMENT ON COLUMN audit_log.changed_by IS 'app_user.id z current_setting(''app.user_id''); NULL pri synchronizácii a údržbe';
COMMENT ON COLUMN audit_log.diff IS 'insert: nový riadok; update: {stĺpec: {old, new}} iba zmenené stĺpce; delete: pôvodný riadok';
CREATE INDEX audit_log_record_idx ON audit_log (table_name, record_id, changed_at);
CREATE INDEX audit_log_changed_at_idx ON audit_log (changed_at);
CREATE INDEX audit_log_changed_by_idx ON audit_log (changed_by);

CREATE TABLE sync_run (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source           text NOT NULL,
  started_at       timestamptz NOT NULL DEFAULT now(),
  finished_at      timestamptz,
  records_in       integer,
  records_updated  integer,
  errors           jsonb
);
CREATE INDEX sync_run_started_at_idx ON sync_run (source, started_at);

-- ============================================================================
-- Funkcie a spúšťače
-- ============================================================================

CREATE FUNCTION set_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

-- Zápis zmien do audit_log. Používateľa nastaví API v každej transakcii:
--   SET LOCAL app.user_id = '<uuid>';
CREATE FUNCTION audit_row() RETURNS trigger
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

-- Deal a zmluva preberajú segment od zákazníka, ak ho nikto nezadal.
CREATE FUNCTION inherit_customer_segment() RETURNS trigger
LANGUAGE plpgsql AS $$
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

CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON deal
  FOR EACH ROW EXECUTE FUNCTION inherit_customer_segment();
CREATE TRIGGER trg_inherit_segment BEFORE INSERT ON contract
  FOR EACH ROW EXECUTE FUNCTION inherit_customer_segment();

-- updated_at na všetkých tabuľkách, ktoré ho majú
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'team', 'app_user', 'company', 'contact', 'company_contact',
    'oom', 'oom_device', 'product',
    'pipeline', 'pipeline_stage', 'deal', 'deal_oom', 'deal_contact',
    'contract', 'contract_price', 'contract_purchase', 'supplier_switch', 'offer', 'offer_item',
    'commission_rule', 'commission', 'voucher', 'referral', 'fve_project',
    'conversation', 'activity', 'call', 'sla_record', 'business_calendar',
    'consent', 'segment', 'campaign', 'web_event'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
  END LOOP;
END;
$$;

-- audit_log na obchodných tabuľkách (bez audit_log, sync_run, web_event, business_calendar)
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'team', 'app_user', 'company', 'contact', 'company_contact',
    'oom', 'oom_device', 'product',
    'pipeline', 'pipeline_stage', 'deal', 'deal_oom', 'deal_contact',
    'contract', 'contract_price', 'contract_purchase', 'supplier_switch', 'offer', 'offer_item',
    'commission_rule', 'commission', 'voucher', 'referral', 'fve_project',
    'conversation', 'activity', 'call', 'sla_record',
    'consent', 'segment', 'campaign'
  ] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_row()', t);
  END LOOP;
END;
$$;

-- ============================================================================
-- Pohľady
-- ============================================================================

-- Zákazníci: firmy (B2B) + kontakty bez firmy (B2C)
CREATE VIEW customer_v AS
SELECT c.id,
       'B2B'::text AS customer_type,
       c.id        AS company_id,
       NULL::uuid  AS person_id,
       c.name,
       c.ico,
       NULL::text  AS email,
       c.segment,
       c.owner_id
  FROM company c
UNION ALL
SELECT p.id,
       'B2C'::text,
       NULL::uuid,
       p.id,
       concat_ws(' ', p.first_name, p.last_name),
       NULL::text,
       p.email,
       p.segment,
       p.owner_id
  FROM contact p
 WHERE NOT EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id);

-- Kontakt ↔ OOM cez dealy, iba OOM v stave Aktívne alebo Neaktívne
CREATE VIEW contact_oom_v AS
SELECT dc.contact_id,
       dom.oom_id,
       o.status AS oom_status,
       array_agg(DISTINCT dc.deal_id) AS deal_ids
  FROM deal_contact dc
  JOIN deal_oom dom ON dom.deal_id = dc.deal_id
  JOIN oom o        ON o.id = dom.oom_id
 WHERE o.status IN ('aktivne', 'neaktivne')
 GROUP BY dc.contact_id, dom.oom_id, o.status;

-- migrate:down

DROP VIEW IF EXISTS contact_oom_v;
DROP VIEW IF EXISTS customer_v;

DROP TABLE IF EXISTS sync_run;
DROP TABLE IF EXISTS audit_log;
DROP TABLE IF EXISTS web_event;
DROP TABLE IF EXISTS campaign;
DROP TABLE IF EXISTS segment;
DROP TABLE IF EXISTS consent;
DROP TABLE IF EXISTS business_calendar;
DROP TABLE IF EXISTS sla_record;
DROP TABLE IF EXISTS call;
DROP TABLE IF EXISTS activity;
DROP TABLE IF EXISTS conversation;
DROP TABLE IF EXISTS fve_project;
DROP TABLE IF EXISTS referral;
DROP TABLE IF EXISTS voucher;
DROP TABLE IF EXISTS commission;
DROP TABLE IF EXISTS commission_rule;
DROP TABLE IF EXISTS offer_item;
DROP TABLE IF EXISTS offer;
DROP TABLE IF EXISTS supplier_switch;
DROP TABLE IF EXISTS contract_purchase;
DROP TABLE IF EXISTS contract_price;
DROP TABLE IF EXISTS contract;
DROP TABLE IF EXISTS deal_contact;
DROP TABLE IF EXISTS deal_oom;
DROP TABLE IF EXISTS deal;
DROP TABLE IF EXISTS pipeline_stage;
DROP TABLE IF EXISTS pipeline;
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS oom_device;
DROP TABLE IF EXISTS oom;
DROP TABLE IF EXISTS company_contact;
DROP TABLE IF EXISTS contact;
DROP TABLE IF EXISTS company;
DROP TABLE IF EXISTS app_user;
DROP TABLE IF EXISTS team;

DROP FUNCTION IF EXISTS inherit_customer_segment();
DROP FUNCTION IF EXISTS audit_row();
DROP FUNCTION IF EXISTS set_updated_at();

DROP TYPE IF EXISTS audit_action;
DROP TYPE IF EXISTS consent_status;
DROP TYPE IF EXISTS consent_purpose;
DROP TYPE IF EXISTS conversation_channel;
DROP TYPE IF EXISTS activity_type;
DROP TYPE IF EXISTS fve_status;
DROP TYPE IF EXISTS fve_program;
DROP TYPE IF EXISTS commission_status;
DROP TYPE IF EXISTS offer_status;
DROP TYPE IF EXISTS contract_price_status;
DROP TYPE IF EXISTS price_direction;
DROP TYPE IF EXISTS contract_status;
DROP TYPE IF EXISTS pricing_model;
DROP TYPE IF EXISTS product_unit;
DROP TYPE IF EXISTS product_kind;
DROP TYPE IF EXISTS switch_segment;
DROP TYPE IF EXISTS switch_message_type;
DROP TYPE IF EXISTS device_type;
DROP TYPE IF EXISTS previous_supplier_notice;
DROP TYPE IF EXISTS source_type;
DROP TYPE IF EXISTS source_kind;
DROP TYPE IF EXISTS oom_status;
DROP TYPE IF EXISTS oom_type;
DROP TYPE IF EXISTS company_contact_role;
DROP TYPE IF EXISTS payment_rating;
DROP TYPE IF EXISTS customer_segment;
DROP TYPE IF EXISTS app_user_role;
