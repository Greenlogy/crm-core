-- migrate:up

-- 0036_ponuky – modul 5, fáza F2 (návrh DB `05-obchod-navrh-db.md` časti 1.5, 1.6, 6, 19 a odpovede 19.6):
-- percento provízie obchodníka s históriou, číslovanie dokladov, pracovné dni a platnosť ponuky, ponuka s variantmi
-- a cenami OOM × rok, snímka hraníc ku dňu verzie, spoločný výpočet pridanej hodnoty so zmluvami (modul 4),
-- verzie, „Označiť ako odoslanú“, posun obchodu do Cenovej ponuky. Schvaľovanie výnimiek, rizika a predĺženia: 0037.

-- ============================================================================
-- 0. Predpoklad: staré tabuľky ponúk sú prázdne
-- ============================================================================

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM offer) OR EXISTS (SELECT 1 FROM offer_item) THEN
    RAISE EXCEPTION 'Migrácia 0036 vyžaduje prázdne ponuky (offer, offer_item).';
  END IF;
END;
$$;

-- ============================================================================
-- 1. Percento provízie obchodníka s históriou (odpoveď 4)
-- ============================================================================

CREATE TABLE user_commission_rate (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES app_user (id),
  valid_from date NOT NULL,
  pct        numeric(5,2) NOT NULL CHECK (pct >= 0 AND pct <= 100),
  changed_by uuid REFERENCES app_user (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, valid_from)
);
COMMENT ON TABLE user_commission_rate IS 'percento provízie obchodníka z pridanej hodnoty, platí od dátumu; bez záznamu 40 %';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON user_commission_rate FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON user_commission_rate FOR EACH ROW EXECUTE FUNCTION set_updated_at();

INSERT INTO app_setting (key, value, description)
VALUES ('commission_pct_default', '40', 'predvolené percento provízie obchodníka z pridanej hodnoty (bez záznamu pri používateľovi)');

CREATE FUNCTION user_commission_pct(p_user uuid, p_on date DEFAULT crm_today()) RETURNS numeric
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce((SELECT r.pct FROM user_commission_rate r
                    WHERE r.user_id = p_user AND r.valid_from <= p_on ORDER BY r.valid_from DESC LIMIT 1),
                  (SELECT (value #>> '{}')::numeric FROM app_setting WHERE key = 'commission_pct_default'), 40)
$$;

-- Mení admin a schvaľovateľ cien (obchodný riaditeľ); platí od dnes a neskôr (minulosť iba vlastník databázy);
-- riadok sa nemení – zmena = nový riadok, budúci riadok smie autor zmazať
CREATE FUNCTION user_commission_rate_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON user_commission_rate
  FOR EACH ROW EXECUTE FUNCTION user_commission_rate_guard();

ALTER TABLE user_commission_rate ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_commission_rate_select ON user_commission_rate FOR SELECT
  USING (crm_is_service() OR user_id = crm_active_user_id() OR crm_is_admin() OR crm_approves_prices());
CREATE POLICY user_commission_rate_write ON user_commission_rate FOR ALL
  USING (crm_is_admin() OR crm_approves_prices()) WITH CHECK (crm_is_admin() OR crm_approves_prices());

-- ============================================================================
-- 2. Číslovanie dokladov (ponuky P26-000123; neskôr provízne listy CMSN)
-- ============================================================================

CREATE TABLE doc_counter (
  org_id     uuid NOT NULL REFERENCES org (id),
  kind       text NOT NULL CHECK (kind IN ('ponuka', 'provizny_list')),
  year       smallint NOT NULL,
  last_value integer NOT NULL DEFAULT 0 CHECK (last_value >= 0),
  PRIMARY KEY (org_id, kind, year)
);
COMMENT ON TABLE doc_counter IS 'počítadlá čísel dokladov po spoločnosti, druhu a roku (od 1 každý rok)';

CREATE FUNCTION doc_number_next(p_org uuid, p_kind text, p_year integer) RETURNS integer
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  INSERT INTO doc_counter (org_id, kind, year, last_value) VALUES (p_org, p_kind, p_year, 1)
  ON CONFLICT (org_id, kind, year) DO UPDATE SET last_value = doc_counter.last_value + 1
  RETURNING last_value
$$;
REVOKE EXECUTE ON FUNCTION doc_number_next(uuid, text, integer) FROM PUBLIC;

-- ============================================================================
-- 3. Pracovné dni a platnosť ponuky (časť 6, odpovede 12 a 19.6)
-- ============================================================================

CREATE FUNCTION next_working_day(p_org uuid, p_day date) RETURNS date
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- n-tý pracovný deň pred dňom (pripomienka platnosti 2 pracovné dni pred koncom)
CREATE FUNCTION working_days_before(p_org uuid, p_day date, p_n integer) RETURNS date
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT date FROM business_calendar
   WHERE org_id = coalesce(p_org, crm_default_org()) AND date < p_day AND is_working_day
   ORDER BY date DESC OFFSET greatest(p_n, 1) - 1 LIMIT 1
$$;

-- Platnosť od času odoslania: FIX a kombinácia do 16:00 nasledujúceho pracovného dňa; SPOT a VIWA 14 dní,
-- ak 14. deň nie je pracovný, posun na nasledujúci pracovný deň (Europe/Bratislava)
CREATE FUNCTION offer_default_valid_until(p_org uuid, p_sent_at timestamptz, p_fix boolean) RETURNS timestamptz
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- ============================================================================
-- 4. Ponuka, varianty, položky OOM × rok, snímka hraníc (časti 1.5, 1.6)
-- ============================================================================

ALTER TABLE offer DROP CONSTRAINT offer_deal_id_version_key;
ALTER TABLE offer ALTER COLUMN status DROP DEFAULT;
ALTER TYPE offer_status RENAME TO offer_status_0001;
CREATE TYPE offer_status AS ENUM (
  'koncept', 'caka_na_schvalenie', 'pripravena', 'odoslana', 'otvorena', 'akceptovana', 'zamietnuta', 'nahradena');
ALTER TABLE offer ALTER COLUMN status TYPE offer_status USING 'koncept'::offer_status;
ALTER TABLE offer ALTER COLUMN status SET DEFAULT 'koncept';
DROP TYPE offer_status_0001;
CREATE TYPE offer_kind AS ENUM ('dodavka', 'vykup', 'viwa');
CREATE TYPE offer_language AS ENUM ('sk', 'en');
CREATE TYPE offer_send_channel AS ENUM ('email_mimo_crm', 'osobne', 'ine', 'crm');   -- 'crm' = e-mail z CRM (F4)

ALTER TABLE offer
  DROP COLUMN total_eur,
  DROP COLUMN pdf_url,
  DROP COLUMN opened_at,
  ALTER COLUMN valid_until TYPE timestamptz USING NULL,
  ALTER COLUMN version TYPE smallint,
  ADD COLUMN number          text NOT NULL,
  ADD COLUMN kind            offer_kind NOT NULL,
  ADD COLUMN language        offer_language NOT NULL DEFAULT 'sk',
  ADD COLUMN household       boolean NOT NULL DEFAULT false,
  ADD COLUMN contact_id      uuid REFERENCES contact (id),
  ADD COLUMN priced_on       date NOT NULL DEFAULT crm_today(),
  ADD COLUMN seller_type     seller_type,
  ADD COLUMN valid_shortened boolean NOT NULL DEFAULT false,
  ADD COLUMN sent_by         uuid REFERENCES app_user (id),
  ADD COLUMN sent_channel    offer_send_channel,
  ADD COLUMN sent_note       text,
  ADD COLUMN rejected_at     timestamptz,
  ADD COLUMN rejected_note   text,
  ADD COLUMN replaced_by_id  uuid REFERENCES offer (id),
  ADD COLUMN created_by      uuid REFERENCES app_user (id),
  ADD CONSTRAINT offer_number_key UNIQUE (org_id, number, version),
  ADD CONSTRAINT offer_number_check CHECK (number ~ '^P[0-9]{2}-[0-9]{6}$'),
  ADD CONSTRAINT offer_sent_check CHECK ((status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) OR sent_at IS NOT NULL),
  ADD CONSTRAINT offer_sent_channel_check CHECK ((sent_at IS NULL) = (sent_channel IS NULL));
CREATE INDEX offer_deal_idx ON offer (deal_id);
COMMENT ON COLUMN offer.number IS 'P26-000123 – rovnaké pre všetky verzie; verzia sa zobrazí ako /2';
COMMENT ON COLUMN offer.priced_on IS 'deň snímky cien pre obchodníka a parametrov (vytvorenie verzie alebo prepočet)';
COMMENT ON COLUMN offer.valid_until IS 'koniec platnosti 16:00 Europe/Bratislava – určí sa pri odoslaní';

CREATE TYPE offer_price_kind AS ENUM ('fix', 'spot', 'kombinacia', 'cennik', 'viwa');

CREATE TABLE offer_variant (
  id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id             uuid NOT NULL REFERENCES offer (id) ON DELETE CASCADE,
  org_id               uuid NOT NULL REFERENCES org (id),
  sort_order           smallint NOT NULL CHECK (sort_order BETWEEN 1 AND 5),   -- A = 1 … najviac 5 (odpoveď 5)
  name                 text NOT NULL CHECK (btrim(name) <> ''),
  price_kind           offer_price_kind NOT NULL,
  supply_from          date NOT NULL,
  supply_to            date,                                   -- NULL = na neurčito (SPOT, výkup, VIWA)
  viwa_package         text CHECK (viwa_package IN ('basic', 'plus', 'pro')),
  flexibility_pct      numeric(5,2) CHECK (flexibility_pct > 0 AND flexibility_pct <= 100),   -- NULL = plná flexibilita
  planned_volume_mwh   numeric(12,3) CHECK (planned_volume_mwh >= 0),                        -- NULL = súčet z OOM
  invoice_due_days     smallint NOT NULL DEFAULT 14 CHECK (invoice_due_days BETWEEN 1 AND 120),
  advance_kind         text NOT NULL DEFAULT 'mesacne' CHECK (advance_kind IN ('mesacne', 'financna_zabezpeka')),
  advance_pct          numeric(5,2) DEFAULT 100 CHECK (advance_pct >= 0 AND advance_pct <= 100),
  advance_due_day      smallint DEFAULT 5 CHECK (advance_due_day BETWEEN 1 AND 31),
  negative_price_compensation boolean NOT NULL DEFAULT false,
  created_at           timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now(),
  UNIQUE (offer_id, sort_order),
  CHECK (supply_to IS NULL OR supply_to >= supply_from),
  CHECK (supply_to IS NOT NULL OR price_kind IN ('spot', 'viwa', 'cennik')),
  CHECK ((price_kind = 'viwa') = (viwa_package IS NOT NULL))
);
COMMENT ON TABLE offer_variant IS 'variant ponuky (A–E); zákazník prijme jeden';

DROP TABLE offer_item;
CREATE TABLE offer_item (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variant_id         uuid NOT NULL REFERENCES offer_variant (id) ON DELETE CASCADE,
  oom_id             uuid REFERENCES oom (id),            -- NULL iba viwa_ucet
  org_id             uuid NOT NULL REFERENCES org (id),
  year               smallint,                            -- NULL = celé obdobie variantu (SPOT, výkup, VIWA, cenník)
  slot               text NOT NULL CHECK (slot IN ('komodita', 'poplatok_om', 'zem', 'program', 'viwa_ucet', 'viwa_kw')),
  product_id         uuid NOT NULL REFERENCES product (id),
  price_model        price_model NOT NULL,
  price_list_item_id uuid REFERENCES price_list_item (id),
  price_vt_eur_mwh   numeric(12,4),
  price_nt_eur_mwh   numeric(12,4),
  additive_eur_mwh   numeric(12,4),
  additive_pct       numeric(7,4),
  fee_eur_month      numeric(12,4),
  fee_kw_eur_month   numeric(12,4),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT offer_item_key UNIQUE NULLS NOT DISTINCT (variant_id, oom_id, slot, year),
  CHECK ((oom_id IS NULL) = (slot = 'viwa_ucet')),
  CHECK ((price_model = 'cennik') = (price_list_item_id IS NOT NULL)),
  CHECK (year IS NULL OR year BETWEEN 2020 AND 2100),
  CHECK (CASE price_model
           WHEN 'fix'            THEN price_vt_eur_mwh IS NOT NULL
           WHEN 'spot_plus_eur'  THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_eur' THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_pct' THEN additive_pct IS NOT NULL
           ELSE true END)
);
CREATE INDEX offer_item_variant_idx ON offer_item (variant_id);
COMMENT ON TABLE offer_item IS 'cena zložky (komodita, poplatky, program, VIWA) pre OOM a rok – rovnaké sloty a modely ako contract_price';

-- Snímka hraníc ku dňu verzie (offer.priced_on): neskorší pohyb BL/PL ponuku nemení (časť 5.2)
CREATE TABLE offer_year_basis (
  variant_id        uuid NOT NULL REFERENCES offer_variant (id) ON DELETE CASCADE,
  year              smallint NOT NULL,
  seller_type       seller_type NOT NULL,
  trader_price      numeric(12,4),     -- FIX: cena pre obchodníka k priced_on
  portfolio_eur_mwh numeric(12,4),     -- FIX pre manažéra: odhad nákupnej ceny portfólia (odpoveď 3)
  min_additive      numeric(12,4),     -- SPOT / výkup podľa typu predajcu a lokálneho zdroja
  energopomoc_price numeric(12,4),
  viwa_additive     numeric(12,4),
  computed_on       date NOT NULL,
  PRIMARY KEY (variant_id, year)
);

-- Výnimka z ceny pri variante (schvaľovanie v 0037): hranica pre rok, model a napäťovú skupinu
CREATE TABLE approval_price_item (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  approval_id      uuid NOT NULL REFERENCES approval_request (id) ON DELETE CASCADE,
  variant_id       uuid NOT NULL REFERENCES offer_variant (id) ON DELETE CASCADE,
  year             smallint NOT NULL,
  price_model      price_model NOT NULL,
  voltage_group    text NOT NULL CHECK (voltage_group IN ('nn', 'vn', 'vsetko')),
  requested_value  numeric(12,4) NOT NULL,   -- najnižšia cena / aditív v skupine
  threshold_value  numeric(12,4) NOT NULL,   -- hranica zo snímky
  approved_value   numeric(12,4),            -- schválená hranica (môže byť iná ako žiadaná)
  volume_mwh       numeric(12,3),
  UNIQUE (approval_id, variant_id, year, price_model, voltage_group)
);

-- Žiadosti z ponuky (schvaľovanie: 0037)
ALTER TABLE approval_request
  ADD COLUMN offer_id              uuid REFERENCES offer (id) ON DELETE CASCADE,
  ADD COLUMN valid_until           timestamptz,   -- výnimka: rozhodnutie + 3 dni na odoslanie; riziko: + 30 dní
  ADD COLUMN requested_valid_until timestamptz,   -- predĺženie platnosti ponuky
  ADD COLUMN risk_snapshot         jsonb;         -- rizikový zákazník: údaje Finstatu v čase žiadosti
COMMENT ON COLUMN approval_request.valid_until IS 'výnimka z ceny platí 3 dni na odoslanie, schválenie rizika 30 dní (časť 1.8, odpoveď 9)';

-- Rizikové údaje firmy na porovnanie (schválenie rizika platí, kým sa údaje nezhoršia)
CREATE FUNCTION company_risk_snapshot(p_company uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'insolvency_kind', c.insolvency_kind,
           'payment_rating', c.payment_rating,
           'debts_count', jsonb_array_length(c.debts),
           'debts_sum', (SELECT coalesce(sum((x->>'suma_eur')::numeric), 0) FROM jsonb_array_elements(c.debts) x),
           'has_debts', c.has_debts)
    FROM company c WHERE c.id = p_company
$$;

-- Zhoršenie oproti snímke: nový konkurz / reštrukturalizácia, horší rating, nový alebo vyšší dlh
CREATE FUNCTION company_risk_worse(p_then jsonb, p_now jsonb) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT (p_now->>'insolvency_kind' IS NOT NULL AND p_then->>'insolvency_kind' IS DISTINCT FROM p_now->>'insolvency_kind')
      OR (p_now->>'payment_rating' IS NOT NULL
          AND coalesce(p_then->>'payment_rating', 'A') < p_now->>'payment_rating')
      OR coalesce((p_now->>'debts_count')::int, 0) > coalesce((p_then->>'debts_count')::int, 0)
      OR coalesce((p_now->>'debts_sum')::numeric, 0) > coalesce((p_then->>'debts_sum')::numeric, 0)
      OR (coalesce((p_now->>'has_debts')::boolean, false) AND NOT coalesce((p_then->>'has_debts')::boolean, false))
$$;

ALTER TABLE deal ADD COLUMN accepted_variant_id uuid REFERENCES offer_variant (id);
COMMENT ON COLUMN deal.accepted_variant_id IS 'akceptovaný variant ponuky (nastaví akceptácia, F3)';

-- Napäťová skupina OOM pre výnimky a rozdelenie NN / VN
CREATE FUNCTION oom_voltage_group(p_level voltage_level) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p_level IN ('vn', 'vvn') THEN 'vn' ELSE 'nn' END
$$;

-- ============================================================================
-- 5. Spoločný výpočet pridanej hodnoty pre zmluvy aj ponuky (časť 1.6)
-- ============================================================================

-- Výnos komodity riadku (druh: fix, cennik, energo, spot_plus_eur, vykup, viwa)
CREATE FUNCTION pv_revenue(p_kind text, p_model price_model, p_vt numeric, p_nt numeric, p_ad numeric, p_pct numeric,
                           p_v_vt numeric, p_v_nt numeric, p_spot_fve numeric, p_viwa_additive numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
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

-- Hranica pre pridanú hodnotu (náklad za MWh): výnimka, inak cena pre obchodníka (manažér: odhad portfólia),
-- minimálny aditív, odhad portfólia pri cenníku, nákupná cena energopomoci
CREATE FUNCTION pv_unit_cost(p_kind text, p_model price_model, p_vt numeric, p_seller seller_type, p_trader numeric,
                             p_portfolio numeric, p_energopomoc numeric, p_min_additive numeric, p_exception numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_kind
           WHEN 'fix' THEN coalesce(p_exception, CASE WHEN p_seller = 'manazer' THEN p_portfolio ELSE p_trader END)
           WHEN 'cennik' THEN p_portfolio
           WHEN 'energo' THEN p_energopomoc
           WHEN 'spot_plus_eur' THEN coalesce(p_exception, p_min_additive)
           WHEN 'vykup' THEN CASE WHEN p_model = 'fix' THEN p_vt ELSE coalesce(p_exception, p_min_additive) END
           WHEN 'viwa' THEN 0
         END
$$;

-- Náklad marže firmy za MWh (dnešný odhad portfólia)
CREATE FUNCTION pv_unit_margin_cost(p_kind text, p_model price_model, p_vt numeric, p_portfolio_today numeric,
                                    p_energopomoc numeric, p_min_additive numeric, p_exception numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_kind
           WHEN 'fix' THEN p_portfolio_today
           WHEN 'cennik' THEN p_portfolio_today
           WHEN 'energo' THEN p_energopomoc
           WHEN 'spot_plus_eur' THEN 0
           WHEN 'vykup' THEN CASE WHEN p_model = 'fix' THEN p_vt ELSE coalesce(p_exception, p_min_additive) END
           WHEN 'viwa' THEN 0
         END
$$;

-- contract_year_calc (0027) používa spoločné funkcie – výsledky sa nemenia (testy modulu 4 na halier)
CREATE OR REPLACE FUNCTION contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE (
  year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric,
  added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text,
  basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric,
  portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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


-- ============================================================================
-- 6. Snímka hraníc a výpočet ponuky
-- ============================================================================

-- Mesiace variantu: od – do; na neurčito prvých 12 mesiacov (P1)
CREATE FUNCTION offer_variant_months(v offer_variant) RETURNS TABLE (m_start date, year smallint)
LANGUAGE sql IMMUTABLE AS $$
  SELECT g::date, extract(year FROM g)::smallint
    FROM generate_series(date_trunc('month', v.supply_from),
                         date_trunc('month', coalesce(v.supply_to, (v.supply_from + interval '11 months')::date)),
                         interval '1 month') g
$$;

-- Snímka hraníc pre roky variantu k offer.priced_on (volá spúšťač variantu a prepočet)
CREATE FUNCTION offer_basis_fill(p_variant uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
REVOKE EXECUTE ON FUNCTION offer_basis_fill(uuid) FROM PUBLIC;

-- Hodnoty variantu po OOM a roku: objem (odhad z obchodu × mesiace / 12), cena, hranica, pridaná hodnota, poplatky,
-- marža firmy (iba s právom „vidieť maržu firmy“). „below“ = pridaná hodnota pod nulou → treba výnimku.
CREATE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE (
  oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model price_model, kind text,
  price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric,
  months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text,
  exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
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
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
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
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       ucost,
       CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
            WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
            WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
            WHEN kind = 'cennik' THEN 'odhad_portfolia'
            WHEN kind = 'energo' THEN 'energopomoc'
            WHEN kind = 'viwa' THEN 'viwa' END,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            WHEN kind = 'fix' AND ucost IS NULL THEN 'chýba cena pre obchodníka'
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

-- Súhrn variantu po rokoch a spolu (rok NULL): objem, pridaná hodnota, marža, odhad provízie (PH × % vlastníka obchodu)
CREATE FUNCTION offer_variant_summary(p_variant uuid) RETURNS TABLE (
  year smallint, volume_mwh numeric, added_value_eur numeric, margin_eur numeric, commission_eur numeric,
  commission_pct numeric, below boolean, missing integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- ============================================================================
-- 7. Časová os obchodu: udalosti ponúk
-- ============================================================================

ALTER TABLE deal_event
  ADD COLUMN offer_id uuid REFERENCES offer (id) ON DELETE SET NULL,
  DROP CONSTRAINT deal_event_kind_check,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik',
    'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana', 'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost',
    'schvalenie_ziadost', 'schvalenie_rozhodnutie'));

CREATE FUNCTION deal_event_offer(o offer, p_kind text, p_detail jsonb DEFAULT '{}') RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public, pg_temp AS $$
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, offer_id, detail)
  VALUES (o.deal_id, o.org_id, p_kind, crm_current_user_id(), o.id,
          jsonb_build_object('number', o.number, 'version', o.version) || coalesce(p_detail, '{}'))
$$;
REVOKE EXECUTE ON FUNCTION deal_event_offer(offer, text, jsonb) FROM PUBLIC;

-- ============================================================================
-- 8. Stav ponuky, oprávnenie, číslo
-- ============================================================================

-- Zobrazovaný stav: Vypršaná sa počíta (odoslaná / otvorená po platnosti)
CREATE FUNCTION offer_state(o offer) RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL AND now() > o.valid_until
              THEN 'vyprsana' ELSE o.status::text END
$$;

CREATE FUNCTION offer_display_number(o offer) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT o.number || CASE WHEN o.version > 1 THEN '/' || o.version ELSE '' END
$$;

-- Ponuku smie meniť, kto smie meniť obchod (RLS obchodu); vracia ponuku zamknutú na zmenu
CREATE FUNCTION offer_for_edit(p_offer uuid) RETURNS offer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
REVOKE EXECUTE ON FUNCTION offer_for_edit(uuid) FROM PUBLIC;

-- ============================================================================
-- 9. Cenníkové ceny (domácnosti a malé podniky – časť 5.3)
-- ============================================================================

-- Komodita a poplatky z cenníka podľa sadzby a regulácie OOM (produkt z párovania modulu 3), platné k začiatku dodávky
CREATE FUNCTION offer_fill_price_list(p_variant uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
REVOKE EXECUTE ON FUNCTION offer_fill_price_list(uuid) FROM PUBLIC;

-- ============================================================================
-- 10. Stráženie: ponuka sa mení iba ako koncept, kód databázy smie všetko
-- ============================================================================

CREATE FUNCTION offer_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_offer_guard BEFORE INSERT OR UPDATE OR DELETE ON offer FOR EACH ROW EXECUTE FUNCTION offer_guard();

-- Varianty a položky: iba pri ponuke v koncepte (pripravená / čakajúca sa vráti do konceptu), kontroly údajov
CREATE FUNCTION offer_child_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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

-- Zmena ponuky: čakajúce žiadosti o výnimku sa zrušia (ceny sa zmenili). Volá ich aj spúšťač s právami aplikácie,
-- preto kontrolujú, či prihlásený smie obchod upravovať.
CREATE FUNCTION offer_cancel_pending_approvals(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Ponuka späť do konceptu (zmena variantu alebo ceny pri pripravenej / čakajúcej ponuke)
CREATE FUNCTION offer_back_to_draft(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM offer_cancel_pending_approvals(p_offer);
  UPDATE offer SET status = 'koncept' WHERE id = p_offer AND status IN ('pripravena', 'caka_na_schvalenie');
END;
$$;

CREATE TRIGGER trg_child_guard BEFORE INSERT OR UPDATE OR DELETE ON offer_variant FOR EACH ROW EXECUTE FUNCTION offer_child_guard();
CREATE TRIGGER trg_child_guard BEFORE INSERT OR UPDATE OR DELETE ON offer_item FOR EACH ROW EXECUTE FUNCTION offer_child_guard();

-- Po zmene obdobia, balíka alebo pridaní variantu: snímka hraníc pre roky variantu
CREATE FUNCTION offer_variant_after() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (NEW.supply_from, NEW.supply_to, NEW.viwa_package) IS DISTINCT FROM (OLD.supply_from, OLD.supply_to, OLD.viwa_package) THEN
    PERFORM offer_basis_fill(NEW.id);
    -- položky rokov mimo nového obdobia sa odstránia
    DELETE FROM offer_item i WHERE i.variant_id = NEW.id AND i.year IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM offer_variant_months(NEW) m WHERE m.year = i.year);
    IF NEW.price_kind = 'cennik' THEN
      PERFORM offer_fill_price_list(NEW.id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_after AFTER INSERT OR UPDATE ON offer_variant FOR EACH ROW EXECUTE FUNCTION offer_variant_after();

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON offer_variant FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_variant FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON offer_item FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_item FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON approval_price_item FOR EACH ROW EXECUTE FUNCTION audit_row();

-- ============================================================================
-- 11. Funkcie ponuky: založenie, varianty, nová verzia, prepočet, kontrola, pripraviť, odoslať, zamietnuť, skrátiť
-- ============================================================================

-- Predvolený variant podľa druhu ponuky
CREATE FUNCTION offer_variant_default_name(p_kind offer_price_kind, p_from date, p_to date) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_kind WHEN 'fix' THEN 'FIX' WHEN 'spot' THEN 'SPOT + aditív' WHEN 'kombinacia' THEN 'FIX + SPOT'
                     WHEN 'cennik' THEN 'Cenník' WHEN 'viwa' THEN 'VIWA' END
         || CASE WHEN p_to IS NULL THEN ''
                 WHEN extract(year FROM p_from) = extract(year FROM p_to) THEN ' ' || extract(year FROM p_from)
                 ELSE ' ' || extract(year FROM p_from) || '–' || extract(year FROM p_to) END
$$;

CREATE FUNCTION offer_create(p_deal uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Nový variant (najviac 5); kópia cien z existujúceho variantu, ak je zadaný
CREATE FUNCTION offer_variant_add(p_offer uuid, p_price_kind offer_price_kind, p_copy_from uuid DEFAULT NULL) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Prepočet na dnešné ceny (koncept, pripravená, čakajúca): nová snímka hraníc, cenníkové ceny, žiadosti o výnimku zrušené
CREATE FUNCTION offer_reprice(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny'
     AND id IN (SELECT a.approval_id FROM approval_price_item a JOIN offer_variant x ON x.id = a.variant_id WHERE x.offer_id = o.id);
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;

-- Nová verzia odoslanej (alebo zamietnutej) ponuky: kópia variantov a cien, snímka k dnešku. Stará verzia sa označí
-- Nahradená až pri odoslaní novej (dovtedy ju zákazník môže prijať).
CREATE FUNCTION offer_new_version(p_offer uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
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
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia');
  RETURN n.id;
END;
$$;

-- Kontrola pred prípravou a odoslaním: chyby, potrebné výnimky (rok, model, napäťová skupina), rizikový zákazník
CREATE FUNCTION offer_check(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
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
                    min(b.th) AS threshold, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold, 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
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

-- Pripraviť na odoslanie: bez chýb; výnimky a rizikový zákazník → schvaľovanie (0037)
CREATE FUNCTION offer_prepare(p_offer uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Označiť ako odoslanú (odpoveď 19.6/2): čas a kanál, platnosť od času odoslania, staré verzie Nahradené,
-- obchod z Príležitosti do Cenovej ponuky (iba dopredu)
CREATE FUNCTION offer_mark_sent(p_offer uuid, p_sent_at timestamptz, p_channel offer_send_channel, p_note text) RETURNS timestamptz
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer := offer_for_edit(p_offer);
  c       jsonb;
  v_fix   boolean;
  v_until timestamptz;
  v_stage uuid;
BEGIN
  IF o.status <> 'pripravena' THEN
    RAISE EXCEPTION 'Odoslať sa dá iba pripravená ponuka (nie koncept ani ponuka čakajúca na schválenie).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_sent_at IS NULL OR p_sent_at > now() + interval '5 minutes' OR p_sent_at < o.created_at - interval '1 minute' THEN
    RAISE EXCEPTION 'Čas odoslania musí byť medzi vytvorením verzie a teraz.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_channel IS NULL THEN
    RAISE EXCEPTION 'Vyberte, ako bola ponuka odoslaná.' USING ERRCODE = 'check_violation';
  END IF;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 OR jsonb_array_length(c->'needs') > 0 OR (c->>'risk_needs_approval')::boolean THEN
    RAISE EXCEPTION 'Ponuka potrebuje opravu alebo schválenie – pripravte ju znova.' USING ERRCODE = 'check_violation';
  END IF;
  v_fix := EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'));
  IF v_fix AND o.priced_on < (p_sent_at AT TIME ZONE 'Europe/Bratislava')::date THEN
    RAISE EXCEPTION 'Ceny pre obchodníka sú z %. FIX ponuku prepočítajte na dnešné ceny.', to_char(o.priced_on, 'DD. MM. YYYY')
      USING ERRCODE = 'check_violation';
  END IF;
  v_until := offer_default_valid_until(o.org_id, p_sent_at, v_fix);
  UPDATE offer SET status = 'odoslana', sent_at = p_sent_at, sent_by = crm_current_user_id(), sent_channel = p_channel,
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
  PERFORM deal_event_offer(o, 'ponuka_odoslana',
    jsonb_build_object('channel', p_channel, 'sent_at', p_sent_at, 'valid_until', v_until));
  RETURN v_until;
END;
$$;

-- Zákazník ponuku odmietol
CREATE FUNCTION offer_reject(p_offer uuid, p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Skrátenie platnosti obchodníkom (predĺženie iba schválením – 0037)
CREATE FUNCTION offer_shorten(p_offer uuid, p_until timestamptz) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- ============================================================================
-- 12. Stav zákazníka „Ponuka“: iba odoslaná ponuka (časť 19.1, bod 9)
-- ============================================================================

CREATE OR REPLACE FUNCTION customer_status_calc(p_company_id uuid, p_person_id uuid, p_today date DEFAULT ((now() AT TIME ZONE 'Europe/Bratislava'::text))::date) RETURNS public.customer_status
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


-- ============================================================================
-- 13. RLS ponúk (podľa obchodu)
-- ============================================================================

ALTER TABLE offer ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_variant ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_year_basis ENABLE ROW LEVEL SECURITY;
ALTER TABLE approval_price_item ENABLE ROW LEVEL SECURITY;
ALTER TABLE doc_counter ENABLE ROW LEVEL SECURITY;

CREATE POLICY offer_select ON offer FOR SELECT USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id));
CREATE POLICY offer_write ON offer FOR ALL
  USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)));
CREATE POLICY offer_variant_select ON offer_variant FOR SELECT USING (EXISTS (SELECT 1 FROM offer o WHERE o.id = offer_id));
CREATE POLICY offer_variant_write ON offer_variant FOR ALL
  USING (EXISTS (SELECT 1 FROM offer o JOIN deal d ON d.id = o.deal_id
                  WHERE o.id = offer_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM offer o JOIN deal d ON d.id = o.deal_id
                       WHERE o.id = offer_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)));
CREATE POLICY offer_item_select ON offer_item FOR SELECT USING (EXISTS (SELECT 1 FROM offer_variant v WHERE v.id = variant_id));
CREATE POLICY offer_item_write ON offer_item FOR ALL
  USING (EXISTS (SELECT 1 FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
                  WHERE v.id = variant_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)))
  WITH CHECK (EXISTS (SELECT 1 FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
                       WHERE v.id = variant_id AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)));
-- snímku (obsahuje odhad portfólia) čítajú iba výpočtové funkcie; schválenia podľa žiadosti
CREATE POLICY approval_price_item_select ON approval_price_item FOR SELECT
  USING (EXISTS (SELECT 1 FROM approval_request a WHERE a.id = approval_id));

-- ============================================================================
-- 14. Audit (0035): ponuky podľa obchodu, položky výnimky podľa žiadosti, percento provízie (vlastné / schvaľovateľ)
-- ============================================================================

CREATE OR REPLACE FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
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
    WHEN 'offer', 'offer_variant', 'offer_item' THEN
      -- ponuka: podľa obchodu (0036)
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
$$;

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM offer) THEN
    RAISE EXCEPTION 'Návrat 0036 vyžaduje prázdne ponuky.';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION customer_status_calc(p_company_id uuid, p_person_id uuid, p_today date DEFAULT ((now() AT TIME ZONE 'Europe/Bratislava'::text))::date) RETURNS public.customer_status
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
                AND (f.sent_at IS NOT NULL OR f.status <> 'koncept')) THEN
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


CREATE OR REPLACE FUNCTION contract_year_calc(p_contract_id uuid, p_year integer) RETURNS TABLE (
  year integer, months integer, volume_mwh numeric, revenue_eur numeric, fees_eur numeric, cost_eur numeric,
  added_value_eur numeric, margin_cost_eur numeric, margin_eur numeric, model text, tranche text,
  basis_stored boolean, basis_source text, trader_price numeric, exception_id uuid, exception_value numeric,
  portfolio_eur_mwh numeric, portfolio_on date, portfolio_stale boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
         CASE kl.kind
           WHEN 'fix' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'cennik' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'energo' THEN kl.vt * kl.v_vt + coalesce(kl.nt, kl.vt) * kl.v_nt
           WHEN 'spot_plus_eur' THEN kl.ad * kl.vol
           WHEN 'vykup' THEN CASE kl.price_model WHEN 'spot_minus_eur' THEN kl.ad * kl.vol
                                                 WHEN 'spot_minus_pct' THEN kl.pct / 100 * (SELECT spot_fve FROM mk) * kl.vol
                                                 -- výkup s pevnou cenou: nákup = predaj, pridaná hodnota a marža 0 (otázka 33)
                                                 WHEN 'fix' THEN kl.vt * kl.vol END
           WHEN 'viwa' THEN (SELECT viwa_additive FROM b) * kl.vol
         END AS rev,
         CASE kl.kind
           WHEN 'fix' THEN coalesce((SELECT exception_value FROM b),
                                    CASE WHEN (SELECT seller_type FROM b) = 'manazer' THEN (SELECT portfolio_eur_mwh FROM b)
                                         ELSE (SELECT trader_price FROM b) END)
           WHEN 'cennik' THEN (SELECT portfolio_eur_mwh FROM b)
           WHEN 'energo' THEN (SELECT energopomoc_price FROM b)
           WHEN 'spot_plus_eur' THEN coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b))
           WHEN 'vykup' THEN CASE WHEN kl.price_model = 'fix' THEN kl.vt
                                  ELSE coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b)) END
           WHEN 'viwa' THEN 0
         END AS unit_cost,
         CASE kl.kind
           WHEN 'fix' THEN (SELECT portfolio FROM mk)
           WHEN 'cennik' THEN (SELECT portfolio FROM mk)
           WHEN 'energo' THEN (SELECT energopomoc_price FROM b)
           WHEN 'spot_plus_eur' THEN 0
           WHEN 'vykup' THEN CASE WHEN kl.price_model = 'fix' THEN kl.vt
                                  ELSE coalesce((SELECT exception_value FROM b), (SELECT min_additive FROM b)) END
           WHEN 'viwa' THEN 0
         END AS unit_mcost
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


CREATE OR REPLACE FUNCTION audit_row_visible(p_table text, p_record uuid, p_diff jsonb) RETURNS boolean
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

DROP POLICY IF EXISTS approval_price_item_select ON approval_price_item;
DROP POLICY IF EXISTS offer_item_write ON offer_item;
DROP POLICY IF EXISTS offer_item_select ON offer_item;
DROP POLICY IF EXISTS offer_variant_write ON offer_variant;
DROP POLICY IF EXISTS offer_variant_select ON offer_variant;
DROP POLICY IF EXISTS offer_write ON offer;
DROP POLICY IF EXISTS offer_select ON offer;
ALTER TABLE offer DISABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS offer_shorten(uuid, timestamptz);
DROP FUNCTION IF EXISTS offer_reject(uuid, text);
DROP FUNCTION IF EXISTS offer_mark_sent(uuid, timestamptz, offer_send_channel, text);
DROP FUNCTION IF EXISTS offer_prepare(uuid);
DROP FUNCTION IF EXISTS offer_check(uuid);
DROP FUNCTION IF EXISTS offer_new_version(uuid);
DROP FUNCTION IF EXISTS offer_reprice(uuid);
DROP FUNCTION IF EXISTS offer_variant_add(uuid, offer_price_kind, uuid);
DROP FUNCTION IF EXISTS offer_create(uuid);
DROP FUNCTION IF EXISTS offer_variant_default_name(offer_price_kind, date, date);
DROP TRIGGER IF EXISTS trg_offer_guard ON offer;
DROP FUNCTION IF EXISTS offer_guard();
DROP FUNCTION IF EXISTS offer_for_edit(uuid);
DROP FUNCTION IF EXISTS offer_variant_summary(uuid);
DROP FUNCTION IF EXISTS offer_variant_values(uuid);

DROP FUNCTION IF EXISTS offer_variant_months(offer_variant);
ALTER TABLE deal DROP COLUMN accepted_variant_id;
ALTER TABLE approval_request
  DROP COLUMN risk_snapshot,
  DROP COLUMN requested_valid_until,
  DROP COLUMN valid_until,
  DROP COLUMN offer_id;
DROP FUNCTION IF EXISTS company_risk_worse(jsonb, jsonb);
DROP FUNCTION IF EXISTS company_risk_snapshot(uuid);
DROP TABLE IF EXISTS approval_price_item;
DROP TABLE IF EXISTS offer_year_basis;
DROP TABLE IF EXISTS offer_item;
DROP TABLE IF EXISTS offer_variant;
DROP FUNCTION IF EXISTS offer_variant_after();
DROP FUNCTION IF EXISTS offer_child_guard();
DROP FUNCTION IF EXISTS offer_back_to_draft(uuid);
DROP FUNCTION IF EXISTS offer_cancel_pending_approvals(uuid);
DROP FUNCTION IF EXISTS offer_fill_price_list(uuid);
DROP FUNCTION IF EXISTS offer_basis_fill(uuid);
DROP FUNCTION IF EXISTS offer_display_number(offer);
DROP FUNCTION IF EXISTS offer_state(offer);
DROP FUNCTION IF EXISTS oom_voltage_group(voltage_level);
DROP FUNCTION IF EXISTS pv_unit_margin_cost(text, price_model, numeric, numeric, numeric, numeric, numeric);
DROP FUNCTION IF EXISTS pv_unit_cost(text, price_model, numeric, seller_type, numeric, numeric, numeric, numeric, numeric);
DROP FUNCTION IF EXISTS pv_revenue(text, price_model, numeric, numeric, numeric, numeric, numeric, numeric, numeric, numeric);
DROP TYPE IF EXISTS offer_price_kind;

-- časová os
DROP FUNCTION IF EXISTS deal_event_offer(offer, text, jsonb);
DELETE FROM deal_event WHERE kind LIKE 'ponuka_%' OR kind LIKE 'schvalenie_%';
ALTER TABLE deal_event
  DROP CONSTRAINT deal_event_kind_check,
  DROP COLUMN offer_id,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik'));

-- ponuka (0001)
DROP INDEX IF EXISTS offer_deal_idx;
ALTER TABLE offer
  DROP CONSTRAINT offer_sent_channel_check,
  DROP CONSTRAINT offer_sent_check,
  DROP CONSTRAINT offer_number_check,
  DROP CONSTRAINT offer_number_key,
  DROP COLUMN created_by,
  DROP COLUMN replaced_by_id,
  DROP COLUMN rejected_note,
  DROP COLUMN rejected_at,
  DROP COLUMN sent_note,
  DROP COLUMN sent_channel,
  DROP COLUMN sent_by,
  DROP COLUMN valid_shortened,
  DROP COLUMN seller_type,
  DROP COLUMN priced_on,
  DROP COLUMN contact_id,
  DROP COLUMN household,
  DROP COLUMN language,
  DROP COLUMN kind,
  DROP COLUMN number,
  ALTER COLUMN version TYPE integer,
  ALTER COLUMN valid_until TYPE date USING NULL,
  ADD COLUMN total_eur numeric(12,2),
  ADD COLUMN pdf_url text,
  ADD COLUMN opened_at timestamptz;
COMMENT ON COLUMN offer.valid_until IS NULL;
DROP TYPE IF EXISTS offer_send_channel;
DROP TYPE IF EXISTS offer_language;
DROP TYPE IF EXISTS offer_kind;
ALTER TABLE offer ALTER COLUMN status DROP DEFAULT;
ALTER TYPE offer_status RENAME TO offer_status_0036;
CREATE TYPE offer_status AS ENUM ('koncept', 'odoslana', 'otvorena', 'prijata', 'zamietnuta');
ALTER TABLE offer ALTER COLUMN status TYPE offer_status USING 'koncept'::offer_status;
ALTER TABLE offer ALTER COLUMN status SET DEFAULT 'koncept';
DROP TYPE offer_status_0036;
ALTER TABLE offer ADD CONSTRAINT offer_deal_id_version_key UNIQUE (deal_id, version);

CREATE TABLE offer_item (
  id uuid DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
  offer_id uuid NOT NULL REFERENCES offer (id) ON DELETE CASCADE,
  oom_id uuid REFERENCES oom (id),
  product_id uuid REFERENCES product (id),
  price_eur_mwh numeric(12,4),
  volume_mwh numeric(12,3),
  fee_eur_month numeric(12,2),
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);
CREATE INDEX offer_item_offer_id_idx ON offer_item (offer_id);
CREATE INDEX offer_item_oom_id_idx ON offer_item (oom_id);
CREATE INDEX offer_item_product_id_idx ON offer_item (product_id);
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON offer_item FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_item FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- pracovné dni, číslovanie, provízie
DROP FUNCTION IF EXISTS offer_default_valid_until(uuid, timestamptz, boolean);
DROP FUNCTION IF EXISTS working_days_before(uuid, date, integer);
DROP FUNCTION IF EXISTS next_working_day(uuid, date);
DROP FUNCTION IF EXISTS doc_number_next(uuid, text, integer);
DROP TABLE IF EXISTS doc_counter;
DROP FUNCTION IF EXISTS user_commission_pct(uuid, date);
DROP TABLE IF EXISTS user_commission_rate;
DROP FUNCTION IF EXISTS user_commission_rate_guard();
DELETE FROM app_setting WHERE key = 'commission_pct_default';
