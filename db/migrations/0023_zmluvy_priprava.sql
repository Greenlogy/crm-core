-- 0023_zmluvy_priprava.sql – modul 4, fáza F1: príprava (plán schválený Petrom 13. 10. 2026,
-- docs/moduly/04-zmluvy-navrh-db.md časť 18).
--
-- Modul 0: typ predajcu a „schvaľuje ceny“ pri používateľovi; právo tímu „vidieť maržu firmy“; východiskové
--   práva modulu Zmluvy podľa zadania (iba bunky s hodnotou z 0006). „Schvaľuje ceny“ pridáva nezávisle od tímu
--   „vidieť všetky zmluvy“ (aj výnimky) a maržu firmy (Peter: obchodný riaditeľ je v Sales_internal s „iba svoje“).
-- Cenové parametre s históriou (platí od iba dnes a neskôr; minulosť iba vlastník databázy) a trhové ceny
--   (ručne, kým nebude API Cockpitu); cena pre obchodníka = (BL × pomer + PL × (100 − pomer)) / 100 + riziko + marža.
-- Prekladová tabuľka importov (import_alias) so systémovými aliasmi (produkty Office portálu, sadzby X4-Dx,
--   D3 Aktiv, X2 /VN/, PDS a číselníky XM Trade). Druh „fáza“ pribudne v 0024 spolu s enumom fáz.
-- Modul 2: plán výkupu lokálneho zdroja (výkon × 4 × 365 × 0,1 / 1000, ručný prepis), verejné osvetlenie,
--   história cenovej regulácie (v 0023 iba dnes a minulý dátum; budúci dátum a rez cien v 0027).
-- Modul 3: variant tarifu produktu (vykurovanie, verejné osvetlenie), popis VIWA „za účet“.
-- Kontrola pred migráciou na dev (db/test-data/0023-pred-migraciou.sql): matica Zmluvy celá východisková,
-- 1 lokálny zdroj s plánom iným ako vzorec (dostane príznak ručne zadaný, hodnota sa nemení).

-- migrate:up

-- ============================================================================
-- 1. Používateľ: typ predajcu, „schvaľuje ceny“
-- ============================================================================

CREATE TYPE seller_type AS ENUM ('obchodnik', 'manazer');

ALTER TABLE app_user
  ADD COLUMN seller_type     seller_type,
  ADD COLUMN approves_prices boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN app_user.seller_type IS 'typ predajcu: obchodník / manažér (minimálny aditív a cena pre obchodníka); NULL = nepredáva';
COMMENT ON COLUMN app_user.approves_prices IS '„schvaľuje ceny“ (CEO, obchodný riaditeľ): výnimky z ceny, cenové parametre; nezávisle od tímu vidí všetky zmluvy a maržu firmy';

ALTER TABLE team_permission
  ADD COLUMN can_see_company_margin boolean NOT NULL DEFAULT false,
  ADD CONSTRAINT team_permission_margin_check CHECK (NOT can_see_company_margin OR module = 'zmluvy');
COMMENT ON COLUMN team_permission.can_see_company_margin IS 'vidieť maržu firmy, nákupnú cenu portfólia a rizikovú prirážku (iba modul zmluvy)';

-- Poistka externého tímu (0006) rozšírená: ani maržu firmy
CREATE OR REPLACE FUNCTION team_external_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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

-- Používateľ (0006) rozšírený: člen externého tímu nemôže schvaľovať ceny
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

CREATE FUNCTION crm_approves_prices() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM app_user u WHERE u.id = crm_active_user_id() AND u.approves_prices)
$$;
COMMENT ON FUNCTION crm_approves_prices() IS 'prihlásený používateľ „schvaľuje ceny“ (CEO, obchodný riaditeľ)';

CREATE FUNCTION crm_can_see_margin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service()
      OR crm_approves_prices()
      OR EXISTS (SELECT 1 FROM app_user u JOIN team_permission p ON p.team_id = u.team_id
                  WHERE u.id = crm_active_user_id() AND p.module = 'zmluvy' AND p.can_see_company_margin)
$$;
COMMENT ON FUNCTION crm_can_see_margin() IS 'vidí maržu firmy: tím s can_see_company_margin (modul zmluvy) alebo „schvaľuje ceny“';

CREATE FUNCTION crm_sees_all_contracts() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_scope('zmluvy', 'view') = 'vsetko' OR crm_approves_prices()
$$;
COMMENT ON FUNCTION crm_sees_all_contracts() IS 'vidí všetky zmluvy a výnimky (tím „všetko“ v module zmluvy alebo „schvaľuje ceny“); použije RLS zmlúv v 0024';

-- ============================================================================
-- 2. Východiskové práva modulu Zmluvy (zadanie modulu 4, časť 12) – iba bunky s hodnotou z 0006
-- ============================================================================

DO $$
DECLARE
  r       record;
  v_kept  text[] := '{}';
BEGIN
  FOR r IN
    SELECT p.id, t.code, p.view_scope::text AS v, p.edit_scope::text AS e, p.can_import, p.can_archive, p.can_export
      FROM team_permission p JOIN team t ON t.id = p.team_id
     WHERE p.module = 'zmluvy'
       AND t.code IN ('ceo', 'sales_internal', 'sales_external', 'servis', 'nakup', 'marketing')
  LOOP
    IF r.v = (CASE WHEN r.code = 'sales_external' THEN 'iba_svoje' ELSE 'vsetko' END)
       AND r.e = (CASE WHEN r.code IN ('ceo', 'nakup') THEN 'vsetko' ELSE 'nic' END)
       AND NOT r.can_import AND r.can_archive = (r.code = 'ceo') AND r.can_export = (r.code = 'ceo') THEN
      UPDATE team_permission
         SET view_scope = CASE WHEN r.code IN ('sales_internal', 'sales_external') THEN 'iba_svoje' ELSE 'vsetko' END::access_scope,
             edit_scope = CASE r.code WHEN 'ceo' THEN 'vsetko' WHEN 'nakup' THEN 'vsetko' WHEN 'servis' THEN 'vsetko'
                                      WHEN 'sales_internal' THEN 'iba_svoje' WHEN 'sales_external' THEN 'iba_svoje'
                                      ELSE 'nic' END::access_scope,
             can_import = r.code IN ('ceo', 'nakup', 'servis')
       WHERE id = r.id;
    ELSE
      v_kept := v_kept || r.code;
    END IF;
  END LOOP;
  IF cardinality(v_kept) > 0 THEN
    RAISE NOTICE 'Práva modulu Zmluvy upravené adminom – ostali bez zmeny: %', array_to_string(v_kept, ', ');
  END IF;
END;
$$;

-- Marža firmy je nové právo: CEO, Nákup, Marketing (obchodný riaditeľ cez „schvaľuje ceny“)
UPDATE team_permission p SET can_see_company_margin = true
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'zmluvy' AND t.code IN ('ceo', 'nakup', 'marketing') AND NOT t.is_external;

-- ============================================================================
-- 3. Cenové parametre s históriou (obrazovka 29)
-- ============================================================================

CREATE TABLE price_parameter (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id        uuid NOT NULL REFERENCES org (id),
  code          text NOT NULL CHECK (code IN (
                  'pomer_bl_pct', 'rizikova_prirazka', 'nasa_marza',
                  'min_aditiv_obchodnik', 'min_aditiv_manazer', 'min_aditiv_vykup_lz',
                  'nakup_energopomoc', 'viwa_aditiv_basic', 'viwa_aditiv_plus', 'viwa_aditiv_pro')),
  delivery_year smallint CHECK (delivery_year BETWEEN 2000 AND 2100),
  valid_from    date NOT NULL,
  value         numeric(12,4) NOT NULL CHECK (value >= 0),
  note          text,
  changed_by    uuid REFERENCES app_user (id),
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT price_parameter_year_check CHECK ((code = 'nakup_energopomoc') = (delivery_year IS NOT NULL)),
  CONSTRAINT price_parameter_ratio_check CHECK (code <> 'pomer_bl_pct' OR value <= 100)
);
CREATE UNIQUE INDEX price_parameter_key ON price_parameter (org_id, code, coalesce(delivery_year, 0), valid_from);
COMMENT ON TABLE price_parameter IS 'cenové parametre s históriou „platí od“ (zadanie modulu 4, časť 6); riadok sa nemení, zmena = nový riadok';

-- Kto mení: admin alebo „schvaľuje ceny“; minimálny aditív výkupu LZ a nákupnú cenu energopomoci iba admin.
-- „Platí od“ iba dnes a neskôr; minulý dátum iba vlastník databázy (skript). Riadok sa nemení ani nemaže,
-- okrem budúceho riadku jeho autorom (oprava plánovanej zmeny).
CREATE FUNCTION price_parameter_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_owner boolean := crm_owner_session();
BEGIN
  IF v_owner THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    IF NOT (OLD.valid_from > crm_today() AND OLD.changed_by IS NOT DISTINCT FROM crm_active_user_id()) THEN
      RAISE EXCEPTION 'Platný parameter sa nemení ani nemaže – zadaj novú hodnotu s dátumom „platí od“.'
        USING ERRCODE = 'check_violation';
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
                             AND NEW.code NOT IN ('min_aditiv_vykup_lz', 'nakup_energopomoc'))) THEN
    RAISE EXCEPTION 'Tento cenový parameter smie meniť iba admin%.',
      CASE WHEN NEW.code IN ('min_aditiv_vykup_lz', 'nakup_energopomoc') THEN '' ELSE ' alebo obchodný riaditeľ' END
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON price_parameter
  FOR EACH ROW EXECUTE FUNCTION price_parameter_guard();

-- Hodnota parametra platná k dátumu (práva volajúceho: obchodník tabuľku nečíta)
CREATE FUNCTION price_param(p_org uuid, p_code text, p_on date, p_year smallint DEFAULT NULL) RETURNS numeric
LANGUAGE sql STABLE AS $$
  SELECT value FROM price_parameter
   WHERE org_id = p_org AND code = p_code AND delivery_year IS NOT DISTINCT FROM p_year AND valid_from <= p_on
   ORDER BY valid_from DESC
   LIMIT 1
$$;

-- Východiskové hodnoty zo zadania modulu 4, časť 6 (vlastník databázy, bez autora)
INSERT INTO price_parameter (org_id, code, delivery_year, valid_from, value, note)
SELECT crm_default_org(), v.code, v.y, v.d::date, v.val, 'východisková hodnota zo zadania modulu 4'
  FROM (VALUES
    ('pomer_bl_pct',         NULL::smallint, '2026-01-01', 80.00),
    ('rizikova_prirazka',    NULL,           '2026-01-01', 4.00),
    ('nasa_marza',           NULL,           '2026-01-01', 4.00),
    ('min_aditiv_obchodnik', NULL,           '2026-01-01', 6.00),
    ('min_aditiv_manazer',   NULL,           '2026-01-01', 0.00),
    ('min_aditiv_vykup_lz',  NULL,           '2026-01-01', 0.00),
    ('nakup_energopomoc',    2026,           '2026-01-01', 72.40),
    ('viwa_aditiv_basic',    NULL,           '2025-10-01', 25.00),
    ('viwa_aditiv_plus',     NULL,           '2025-10-01', 20.00),
    ('viwa_aditiv_pro',      NULL,           '2025-10-01', 15.00)
  ) AS v (code, y, d, val);

-- ============================================================================
-- 4. Trhové ceny (ručne, kým nebude API Cockpitu) a cena pre obchodníka
-- ============================================================================

CREATE TABLE market_price_daily (
  org_id             uuid NOT NULL REFERENCES org (id),
  on_date            date NOT NULL,
  delivery_year      smallint NOT NULL CHECK (delivery_year BETWEEN 2000 AND 2100),
  bl_eur_mwh         numeric(12,4) CHECK (bl_eur_mwh >= 0),
  pl_eur_mwh         numeric(12,4) CHECK (pl_eur_mwh >= 0),
  portfolio_eur_mwh  numeric(12,4) CHECK (portfolio_eur_mwh >= 0),
  spot_fve_eur_mwh   numeric(12,4) CHECK (spot_fve_eur_mwh >= 0),
  source             text NOT NULL DEFAULT 'rucne' CHECK (source IN ('cockpit', 'rucne', 'historia')),
  changed_by         uuid REFERENCES app_user (id),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (org_id, on_date, delivery_year),
  CHECK (num_nonnulls(bl_eur_mwh, pl_eur_mwh, portfolio_eur_mwh, spot_fve_eur_mwh) >= 1),
  CHECK ((bl_eur_mwh IS NULL) = (pl_eur_mwh IS NULL))
);
COMMENT ON TABLE market_price_daily IS 'ceny BL/PL (CAL), odhad nákupnej ceny portfólia a očakávaná cena SPOT pre FVE podľa dňa a roka dodávky';

-- Aplikácia zapisuje iba dnešný a budúci deň (ručne); minulosť (história od 1. 1. 2026) iba vlastník databázy.
-- Zapisuje admin alebo „schvaľuje ceny“ (RLS); zdroj z aplikácie je vždy „ručne“.
CREATE FUNCTION market_price_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF crm_owner_session() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Trhové ceny sa nemažú.' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.on_date < crm_today() OR (TG_OP = 'UPDATE' AND OLD.on_date < crm_today()) THEN
    RAISE EXCEPTION 'Ceny sa zadávajú iba pre dnešný deň alebo neskôr.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT (crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION 'Trhové ceny zadáva admin alebo obchodný riaditeľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  NEW.source := 'rucne';
  NEW.changed_by := crm_active_user_id();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON market_price_daily
  FOR EACH ROW EXECUTE FUNCTION market_price_guard();

-- Cena pre obchodníka (FIX) na rok dodávky k dátumu: hodnoty BL/PL z daného dňa, chýbajúci deň preklenie
-- posledná hodnota najviac 7 dní dozadu, inak NULL. Vracia iba výsledok – obchodník nevidí zložky.
CREATE FUNCTION trader_price(p_org uuid, p_year smallint, p_on date) RETURNS numeric
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_bl numeric; v_pl numeric; v_ratio numeric; v_risk numeric; v_margin numeric;
BEGIN
  IF NOT crm_session_ok() OR NOT p_org = ANY (crm_user_orgs()) THEN
    RETURN NULL;
  END IF;
  SELECT bl_eur_mwh, pl_eur_mwh INTO v_bl, v_pl
    FROM market_price_daily
   WHERE org_id = p_org AND delivery_year = p_year AND bl_eur_mwh IS NOT NULL
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
COMMENT ON FUNCTION trader_price(uuid, smallint, date) IS 'cena pre obchodníka = (BL × pomer + PL × (100 − pomer)) / 100 + riziková prirážka + naša marža k dátumu';

-- Obrazovka 29 „Cena pre obchodníka dnes“: zložky vidí iba admin, „schvaľuje ceny“ a marža firmy (RLS tabuliek)
CREATE VIEW trader_price_today_v WITH (security_invoker = true) AS
SELECT m.org_id, m.delivery_year, m.on_date,
       m.bl_eur_mwh, m.pl_eur_mwh,
       price_param(m.org_id, 'pomer_bl_pct', crm_today()) AS bl_ratio_pct,
       round((m.bl_eur_mwh * price_param(m.org_id, 'pomer_bl_pct', crm_today())
              + m.pl_eur_mwh * (100 - price_param(m.org_id, 'pomer_bl_pct', crm_today()))) / 100, 4) AS mix_eur_mwh,
       price_param(m.org_id, 'rizikova_prirazka', crm_today()) AS risk_eur_mwh,
       price_param(m.org_id, 'nasa_marza', crm_today()) AS margin_eur_mwh,
       trader_price(m.org_id, m.delivery_year, crm_today()) AS trader_price_eur_mwh,
       m.portfolio_eur_mwh, m.spot_fve_eur_mwh, m.source
  FROM market_price_daily m
 WHERE m.on_date = (SELECT max(x.on_date) FROM market_price_daily x
                     WHERE x.org_id = m.org_id AND x.delivery_year = m.delivery_year AND x.on_date <= crm_today());
COMMENT ON VIEW trader_price_today_v IS 'obrazovka 29: posledné ceny BL/PL po rokoch dodávky a cena pre obchodníka dnes';

-- ============================================================================
-- 5. Prekladová tabuľka importov (Nastavenia → Preklady importov)
-- ============================================================================

-- Normalizovaný názov: malé písmená, bez diakritiky, viac medzier → jedna, orezanie, rok 19xx/20xx → rrrr
CREATE FUNCTION import_name_norm(p text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT regexp_replace(
           btrim(regexp_replace(
             translate(lower(p), 'áäčďéěíĺľňóôöŕřšťúůüýž', 'aacdeeillnooorrstuuuyz'),
             '\s+', ' ', 'g')),
           '(^|[^0-9])(19|20)[0-9]{2}(?=[^0-9]|$)', '\1rrrr', 'g')
$$;
COMMENT ON FUNCTION import_name_norm(text) IS 'normalizácia názvu z importu: „VBattery  - V“ = „vbattery - v“, GREEN_1T_INDIVIDUAL_2027 = green_1t_individual_rrrr';

CREATE TABLE import_alias (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  source       text NOT NULL CHECK (source IN ('office_portal', 'xm_trade', 'vsetky')),
  kind         text NOT NULL CHECK (kind IN ('produkt_op', 'produkt_oom', 'sadzba', 'pds', 'obchodnik',
                                             'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'iny')),
  name_sample  text NOT NULL CHECK (btrim(name_sample) <> ''),
  name_norm    text GENERATED ALWAYS AS (import_name_norm(name_sample)) STORED,
  target       text NOT NULL CHECK (btrim(target) <> ''),
  target_extra jsonb NOT NULL DEFAULT '{}' CHECK (jsonb_typeof(target_extra) = 'object'),
  is_system    boolean NOT NULL DEFAULT false,
  hidden_at    timestamptz,
  created_by   uuid REFERENCES app_user (id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX import_alias_key ON import_alias (org_id, source, kind, name_norm);
COMMENT ON TABLE import_alias IS 'preklad názvu z importu (Office portal, XM Trade) na hodnotu CRM; spravuje admin (rozhodnutie 2026-10-13)';
COMMENT ON COLUMN import_alias.target IS 'produkt_op: cenový model; produkt_oom: kód produktu; sadzba: kód sadzby bez PDS (d1); pds a číselníky: kód hodnoty; obchodnik: id používateľa';

-- Cieľ musí existovať; systémové aliasy zakladá iba vlastník databázy, nemažú sa (iba skryjú), cieľ nemení iba vlastník
CREATE FUNCTION import_alias_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON import_alias
  FOR EACH ROW EXECUTE FUNCTION import_alias_guard();

-- Preklad názvu: najprv alias zdroja, potom spoločný („vsetky“); skrytý sa nepoužije. NULL = neznámy názov.
CREATE FUNCTION import_alias_resolve(p_org uuid, p_source text, p_kind text, p_name text) RETURNS import_alias
LANGUAGE sql STABLE AS $$
  SELECT a.* FROM import_alias a
   WHERE a.org_id = p_org AND a.kind = p_kind AND a.source IN (p_source, 'vsetky')
     AND a.name_norm = import_name_norm(p_name) AND a.hidden_at IS NULL
   ORDER BY (a.source = p_source) DESC
   LIMIT 1
$$;

-- Systémové aliasy: produkty Office portálu (zadanie časť 10, O2, rozhodnutie A)
INSERT INTO import_alias (org_id, source, kind, name_sample, target, target_extra, is_system)
SELECT crm_default_org(), 'office_portal', 'produkt_op', v.n, v.t, v.x::jsonb, true
  FROM (VALUES
    ('GREEN_1T_INDIVIDUAL_RRRR',     'fix',            '{"year_from_name": true, "tariff": "1t"}'),
    ('GREEN_2T_INDIVIDUAL_RRRR',     'fix',            '{"year_from_name": true, "tariff": "2t"}'),
    ('GREEN_2T_VYK_INDIVIDUAL_RRRR', 'fix',            '{"year_from_name": true, "tariff": "2t_vyk"}'),
    ('GREEN_ISOTSK_PLUS_RRRR_R',     'spot_plus_eur',  '{"year_from_name": true, "additive_column": "vt"}'),
    ('RRRR_GREENVYR_AK [EUR]',       'spot_minus_eur', '{"year_from_name": true, "vykup": true}'),
    ('RRRR_GREENVYR_AK [%]',         'spot_minus_pct', '{"year_from_name": true, "vykup": true}'),
    ('RRRR_GREENVYR_PC_R',           'fix',            '{"year_from_name": true, "vykup": true}'),
    ('RRRR_GREENVYR_PC_M09',         'fix',            '{"year_from_name": true, "vykup": true, "kontrola": "mesačná cena sa nepoužíva"}')
  ) AS v (n, t, x);

-- Sadzby (rozhodnutie B, odpoveď 6): X4-Dx = Dx, D3 Aktiv = D3, X2 /VN/ = X2 – pre Office portal aj XM Trade
INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system)
SELECT crm_default_org(), 'vsetky', 'sadzba', 'X4-D' || n, 'd' || n, true
  FROM generate_series(1, 8) AS n
 WHERE EXISTS (SELECT 1 FROM lookup_value v WHERE v.list_code = 'sadzba_distribucie' AND v.hidden_at IS NULL
                AND v.code = v.parent_code || '_d' || n);
INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system) VALUES
  (crm_default_org(), 'vsetky', 'sadzba', 'D3 Aktiv /bývalá D3/', 'd3', true),
  (crm_default_org(), 'vsetky', 'sadzba', 'D3 Aktiv /bývalá D5/', 'd3', true),
  (crm_default_org(), 'vsetky', 'sadzba', 'X2 /VN/',              'x2', true);

-- PDS z XM Trade („Sústava“ s EIC PDS a celý názov)
INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system)
SELECT crm_default_org(), 'xm_trade', 'pds', v.n, v.t, true
  FROM (VALUES
    ('Západoslovenská distribučná (24X-ZSE-PDS----5)', 'zsd'),
    ('Stredoslovenská distribučná (24X-SSE-PDS----F)', 'ssd'),
    ('Západoslovenská distribučná, a.s.',              'zsd'),
    ('Stredoslovenská distribučná, a.s.',              'ssd'),
    ('Východoslovenská distribučná, a.s.',             'vsd')
  ) AS v (n, t)
 WHERE EXISTS (SELECT 1 FROM lookup_value l WHERE l.list_code = 'pds' AND l.code = v.t AND l.hidden_at IS NULL);

-- Číselníky XM Trade = zápis v HubSpote (lookup_value.hubspot_value), napr. „Typ merania A“, „Rok“, „Mesiac“
INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system)
SELECT DISTINCT ON (import_name_norm(v.hubspot_value), v.list_code)
       crm_default_org(), 'xm_trade', v.list_code, v.hubspot_value, v.code, true
  FROM lookup_value v
 WHERE v.list_code IN ('typ_merania', 'fakturacne_obdobie', 'sposob_zaloh')
   AND v.hubspot_value IS NOT NULL AND v.hidden_at IS NULL
 ORDER BY import_name_norm(v.hubspot_value), v.list_code, v.sort_order;

-- ============================================================================
-- 6. Modul 2: plán výkupu lokálneho zdroja, verejné osvetlenie, história cenovej regulácie
-- ============================================================================

ALTER TABLE oom
  ADD COLUMN planned_feed_in_manual boolean NOT NULL DEFAULT false,
  ADD COLUMN public_lighting        boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN oom.planned_feed_in_manual IS 'plán výkupu lokálneho zdroja zadaný ručne (vzorec výkon × 4 × 365 × 0,1 / 1000 sa nepoužije)';
COMMENT ON COLUMN oom.public_lighting IS 'verejné osvetlenie (prolongácia navrhne Green 1T VO); nastaví import zmlúv pri DMP10 / 1T VO';

CREATE FUNCTION oom_feed_in_formula(p_power_kw numeric) RETURNS numeric
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
  SELECT round(p_power_kw * 4 * 365 * 0.1 / 1000, 3)
$$;
COMMENT ON FUNCTION oom_feed_in_formula(numeric) IS 'plán výkupu lokálneho zdroja [MWh] = výkon [kW] × 4 h × 365 × 0,1 / 1000 (zadanie modulu 4, časť 9)';

-- Doplnenie: plán iný ako vzorec = ručný (hodnota sa nemení); prázdny plán sa vypočíta
UPDATE oom SET planned_feed_in_manual = true
 WHERE source_category = 'lokalny_zdroj' AND planned_feed_in_mwh IS NOT NULL
   AND planned_feed_in_mwh IS DISTINCT FROM oom_feed_in_formula(source_power_kw);
UPDATE oom SET planned_feed_in_mwh = oom_feed_in_formula(source_power_kw)
 WHERE source_category = 'lokalny_zdroj' AND NOT planned_feed_in_manual AND source_power_kw IS NOT NULL
   AND planned_feed_in_mwh IS DISTINCT FROM oom_feed_in_formula(source_power_kw);

-- Lokálny zdroj: kým plán nie je ručný, počíta sa z výkonu. Ručná hodnota (iná ako vzorec) nastaví príznak –
-- aj z importu OOM (0018) bez jeho zmeny. Vyprázdnenie plánu alebo zrušenie príznaku vráti výpočet.
CREATE FUNCTION oom_feed_in_plan() RETURNS trigger
LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_feed_in_plan BEFORE INSERT OR UPDATE OF planned_feed_in_mwh, planned_feed_in_manual,
  source_power_kw, source_category ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_feed_in_plan();

CREATE TABLE oom_price_regulation_change (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id      uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
  valid_from  date NOT NULL,
  value       boolean,
  applied_at  timestamptz,
  created_by  uuid REFERENCES app_user (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (oom_id, valid_from)
);
CREATE INDEX oom_price_regulation_change_oom_idx ON oom_price_regulation_change (oom_id);
COMMENT ON TABLE oom_price_regulation_change IS 'história cenovej regulácie OOM s dátumom „platí od“ (časový rez cien zmlúv v 0027)';
COMMENT ON COLUMN oom_price_regulation_change.value IS 'true = ANO, false = NIE, NULL = nevyplnené';

-- Zmena cenovej regulácie s dátumom: v 0023 iba dnes alebo minulý dátum (zapíše sa hneď do OOM);
-- budúci dátum vykoná nočný beh až od 0027. Práva volajúceho – platí RLS a úprava Aktívneho OOM.
CREATE FUNCTION oom_price_regulation_set(p_oom_id uuid, p_value boolean, p_valid_from date) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  IF p_valid_from IS NULL OR p_valid_from > crm_today() THEN
    RAISE EXCEPTION 'Zmena cenovej regulácie s budúcim dátumom zatiaľ nie je možná – zadaj dnešný alebo minulý dátum.'
      USING ERRCODE = 'check_violation';
  END IF;
  UPDATE oom SET price_regulation = p_value WHERE id = p_oom_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto neexistuje alebo k nemu nemáte prístup.' USING ERRCODE = 'P0002';
  END IF;
  INSERT INTO oom_price_regulation_change (oom_id, valid_from, value, applied_at, created_by)
  VALUES (p_oom_id, p_valid_from, p_value, now(), crm_active_user_id())
  ON CONFLICT (oom_id, valid_from) DO UPDATE
     SET value = EXCLUDED.value, applied_at = EXCLUDED.applied_at, created_by = EXCLUDED.created_by;
END;
$$;

-- ============================================================================
-- 7. Modul 3: variant tarifu produktu, VIWA za účet
-- ============================================================================

ALTER TABLE product
  ADD COLUMN tariff_variant text,
  ADD CONSTRAINT product_tariff_variant_check CHECK (
    tariff_variant IS NULL
    OR (tariff_variant = 'vykurovanie' AND tariff_type = 'dvojtarif')
    OR (tariff_variant = 'verejne_osvetlenie' AND tariff_type = 'jednotarif'));
COMMENT ON COLUMN product.tariff_variant IS 'variant typu tarifu: vykurovanie (Green 2T Vykurovanie), verejne_osvetlenie (Green 1T VO, DMP10)';

-- Ochrana použitého produktu (0022) rozšírená o variant tarifu
CREATE OR REPLACE FUNCTION product_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

COMMENT ON COLUMN price_list_item.fee_program_eur_month IS 'mesačný poplatok programu bez DPH: VBattery za OOM; VIWA za účet (nie za OOM)';

-- ============================================================================
-- 8. RLS, audit, čas zmeny
-- ============================================================================

ALTER TABLE price_parameter ENABLE ROW LEVEL SECURITY;
ALTER TABLE market_price_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE import_alias ENABLE ROW LEVEL SECURITY;
ALTER TABLE oom_price_regulation_change ENABLE ROW LEVEL SECURITY;

-- Cenové parametre a trhové ceny: čítajú admin, „schvaľuje ceny“ a marža firmy; zapisujú admin a „schvaľuje ceny“
-- (podrobnosti v spúšťačoch). Obchodník dostane iba výslednú cenu cez trader_price().
CREATE POLICY price_parameter_read ON price_parameter FOR SELECT
  USING ((SELECT crm_session_ok()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[])
         AND ((SELECT crm_is_admin()) OR (SELECT crm_can_see_margin())));
CREATE POLICY price_parameter_write ON price_parameter FOR ALL
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND ((SELECT crm_is_admin()) OR (SELECT crm_approves_prices())))
  WITH CHECK (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND ((SELECT crm_is_admin()) OR (SELECT crm_approves_prices())));
CREATE POLICY market_price_read ON market_price_daily FOR SELECT
  USING ((SELECT crm_session_ok()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[])
         AND ((SELECT crm_is_admin()) OR (SELECT crm_can_see_margin())));
CREATE POLICY market_price_write ON market_price_daily FOR ALL
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND ((SELECT crm_is_admin()) OR (SELECT crm_approves_prices())))
  WITH CHECK (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND ((SELECT crm_is_admin()) OR (SELECT crm_approves_prices())));

-- Preklady: číta každý prihlásený (náhľad importu), mení admin
CREATE POLICY import_alias_read ON import_alias FOR SELECT
  USING ((SELECT crm_session_ok()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
CREATE POLICY import_alias_write ON import_alias FOR ALL
  USING ((SELECT crm_settings_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]))
  WITH CHECK ((SELECT crm_settings_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));

-- História regulácie: podľa prístupu k OOM (RLS OOM v poddotaze); zapisuje, kto smie OOM upraviť (funkcia mení OOM)
CREATE POLICY oom_regulation_read ON oom_price_regulation_change FOR SELECT
  USING (EXISTS (SELECT 1 FROM oom o WHERE o.id = oom_id));
CREATE POLICY oom_regulation_write ON oom_price_regulation_change FOR INSERT
  WITH CHECK (EXISTS (SELECT 1 FROM oom o WHERE o.id = oom_id));
CREATE POLICY oom_regulation_update ON oom_price_regulation_change FOR UPDATE
  USING (EXISTS (SELECT 1 FROM oom o WHERE o.id = oom_id))
  WITH CHECK (EXISTS (SELECT 1 FROM oom o WHERE o.id = oom_id));

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON price_parameter FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON import_alias FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON oom_price_regulation_change FOR EACH ROW EXECUTE FUNCTION audit_row();

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON price_parameter FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON market_price_daily FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON import_alias FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON oom_price_regulation_change FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- migrate:down

DROP TRIGGER IF EXISTS trg_feed_in_plan ON oom;
DROP FUNCTION IF EXISTS oom_feed_in_plan();
DROP FUNCTION IF EXISTS oom_price_regulation_set(uuid, boolean, date);
DROP TABLE IF EXISTS oom_price_regulation_change;
DROP FUNCTION IF EXISTS oom_feed_in_formula(numeric);
ALTER TABLE oom DROP COLUMN IF EXISTS planned_feed_in_manual, DROP COLUMN IF EXISTS public_lighting;

DROP FUNCTION IF EXISTS import_alias_resolve(uuid, text, text, text);
DROP TABLE IF EXISTS import_alias;
DROP FUNCTION IF EXISTS import_alias_guard();
DROP FUNCTION IF EXISTS import_name_norm(text);

DROP VIEW IF EXISTS trader_price_today_v;
DROP FUNCTION IF EXISTS trader_price(uuid, smallint, date);
DROP TABLE IF EXISTS market_price_daily;
DROP FUNCTION IF EXISTS market_price_guard();
DROP FUNCTION IF EXISTS price_param(uuid, text, date, smallint);
DROP TABLE IF EXISTS price_parameter;
DROP FUNCTION IF EXISTS price_parameter_guard();

-- Ochrana produktu ako v 0022
CREATE OR REPLACE FUNCTION product_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Produkt sa nemaže, iba ukončí (stav Ukončený).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Kód a spoločnosť produktu sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  -- použitý produkt (je v položke cenníka): kategória, segment, typ tarifu, cenová regulácia a model „cenník“ sa nemenia
  IF (NEW.category <> OLD.category OR NEW.segment <> OLD.segment OR NEW.tariff_type <> OLD.tariff_type
      OR NEW.price_regulation IS DISTINCT FROM OLD.price_regulation
      OR ('cennik' = ANY (OLD.price_models) AND NOT 'cennik' = ANY (NEW.price_models)))
     AND EXISTS (SELECT 1 FROM price_list_item WHERE product_id = OLD.id) THEN
    RAISE EXCEPTION 'Produkt „%“ je v cenníku: kategória, segment, typ tarifu, cenová regulácia ani model cenník sa nemenia.', OLD.name
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
ALTER TABLE product DROP CONSTRAINT IF EXISTS product_tariff_variant_check, DROP COLUMN IF EXISTS tariff_variant;
COMMENT ON COLUMN price_list_item.fee_program_eur_month IS 'mesačný poplatok programu (VBattery, VIWA za OOM) bez DPH';

-- Práva modulu Zmluvy späť na hodnoty z 0006 (iba bunky, ktoré majú hodnotu nastavenú v 0023)
UPDATE team_permission p
   SET view_scope = CASE WHEN t.code = 'sales_external' THEN 'iba_svoje' ELSE 'vsetko' END::access_scope,
       edit_scope = CASE WHEN t.code IN ('ceo', 'nakup') THEN 'vsetko' ELSE 'nic' END::access_scope,
       can_import = false
  FROM team t
 WHERE t.id = p.team_id AND p.module = 'zmluvy'
   AND t.code IN ('ceo', 'sales_internal', 'sales_external', 'servis', 'nakup', 'marketing')
   AND p.view_scope = CASE WHEN t.code IN ('sales_internal', 'sales_external') THEN 'iba_svoje' ELSE 'vsetko' END::access_scope
   AND p.edit_scope = CASE t.code WHEN 'ceo' THEN 'vsetko' WHEN 'nakup' THEN 'vsetko' WHEN 'servis' THEN 'vsetko'
                                  WHEN 'sales_internal' THEN 'iba_svoje' WHEN 'sales_external' THEN 'iba_svoje'
                                  ELSE 'nic' END::access_scope
   AND p.can_import = (t.code IN ('ceo', 'nakup', 'servis'));

DROP FUNCTION IF EXISTS crm_sees_all_contracts();
DROP FUNCTION IF EXISTS crm_can_see_margin();
DROP FUNCTION IF EXISTS crm_approves_prices();

-- Poistky ako v 0006
CREATE OR REPLACE FUNCTION team_external_guard() RETURNS trigger
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

ALTER TABLE team_permission DROP CONSTRAINT IF EXISTS team_permission_margin_check,
  DROP COLUMN IF EXISTS can_see_company_margin;
ALTER TABLE app_user DROP COLUMN IF EXISTS seller_type, DROP COLUMN IF EXISTS approves_prices;
DROP TYPE IF EXISTS seller_type;
