-- 0019_produkty.sql – modul 3 Produkty a cenníky, časť 1: katalóg produktov a párovanie so sadzbami
-- (návrh docs/moduly/03-produkty-navrh-db.md v0.2, časti 1, 2, 8, 9; Peter 13. 10. 2026)
--
-- Produkt: spoločnosť, kategória, segment, sadzba DPH, typ tarifu, povolené cenové modely, cenová regulácia, stav.
-- Ceny a platnosť sa z produktu presúvajú do cenníka (0020). Produkt sa nikdy nemaže, iba ukončí.
-- Párovanie produkt ↔ sadzba distribúcie: rozsah PDS je uložený výslovne (tariff_scope: ZSD, VSD, „SSD a miestne DS“);
-- PDS s vlastným rozsahom používa iba svoje riadky, spoločné riadky sa preň nepoužijú nikdy.
-- product_candidates(OOM) navrhne produkty pre OOM; pri plánovanej spotrebe NT najprv dvojtarifné.
-- Číselník sadzieb: + C11 (ZSD, VSD, SSD), D4–D8 (ZSD, VSD), C9 (VSD), D7 (SSD); ZSD C1 sa skryje, ak ju nepoužíva žiadne OOM.
-- Cenová regulácia OOM: text → ANO / NIE / prázdne (boolean NULL); jasné áno/ano → ANO, jasné nie → NIE, ostatné prázdne.
-- Práva: produkty, rozsahy a párovanie mení iba admin, čítajú všetci aktívni používatelia (aj externí) svojej spoločnosti.
--
-- Predpoklad: tabuľka product je prázdna (na Teste áno). Inak migrácia skončí chybou.
--
-- ZNÁME OBMEDZENIE migrate:down: pôvodné texty cenovej regulácie sa nevrátia. Down zapíše iba „ANO“, „NIE“
-- alebo prázdne (texty, ktoré sa pri prevode zmenili na prázdne, sú iba v audite). Down tiež vyžaduje prázdnu
-- tabuľku product a OOM bez sadzieb pridaných touto migráciou.

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM product) THEN
    RAISE EXCEPTION 'Tabuľka product nie je prázdna – migrácia 0019 mení stĺpce produktu.';
  END IF;
END;
$$;

-- ============================================================================
-- Produkt
-- ============================================================================

CREATE TYPE product_category AS ENUM (
  'dodavka_domacnost',    -- Green DD1–DD8 ANO / NIE Energopomoc
  'dodavka_maly_podnik',  -- Green DMP1–DMP11
  'dodavka_firma',        -- Dodávka B2B
  'vykup_firma',          -- Výkup B2B
  'velkoobchod',          -- Veľkoobchod (položky zmluvy bez OOM, modul 4)
  'zem',                  -- služba ZEM
  'vbattery',             -- VBattery STANDARD, PREMIUM, MAX, AKU
  'viwa',                 -- Green VIWA Basic, Plus, Pro
  'instalacia_fve',       -- Green Solar – zmluva o dielo
  'poplatok'              -- Mesačná platba za OM – firmy
);
CREATE TYPE price_model AS ENUM ('cennik', 'fix', 'spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct', 'cena_diela');
CREATE TYPE product_status AS ENUM ('predava_sa', 'dobieha', 'ukonceny');
CREATE TYPE tariff_type AS ENUM ('jednotarif', 'dvojtarif', 'nemerany', 'netyka_sa');

ALTER TABLE product
  DROP CONSTRAINT product_validity_check,
  DROP COLUMN kind,
  DROP COLUMN pricing_model,
  DROP COLUMN unit,
  DROP COLUMN list_price,
  DROP COLUMN valid_from,
  DROP COLUMN valid_to,
  ADD COLUMN org_id           uuid NOT NULL REFERENCES org (id),
  ADD COLUMN category         product_category NOT NULL,
  ADD COLUMN segment          customer_segment NOT NULL,
  ADD COLUMN vat_rate         numeric(5,2),
  ADD COLUMN tariff_type      tariff_type NOT NULL DEFAULT 'netyka_sa',
  ADD COLUMN price_models     price_model[] NOT NULL,
  ADD COLUMN price_regulation boolean,
  ADD COLUMN status           product_status NOT NULL DEFAULT 'predava_sa',
  ADD COLUMN sort_order       integer NOT NULL DEFAULT 0,
  ADD CONSTRAINT product_code_check CHECK (code ~ '^[a-z][a-z0-9_]{1,60}$'),
  ADD CONSTRAINT product_segment_check CHECK (segment IN ('domacnost', 'firma')),
  ADD CONSTRAINT product_vat_check CHECK (vat_rate BETWEEN 0 AND 100),
  ADD CONSTRAINT product_vat_required CHECK (vat_rate IS NOT NULL OR category = 'instalacia_fve'),
  ADD CONSTRAINT product_price_models_check
    CHECK (cardinality(price_models) >= 1 AND array_position(price_models, NULL) IS NULL),
  ADD CONSTRAINT product_cena_diela_check
    CHECK (('cena_diela' = ANY (price_models)) = (category = 'instalacia_fve'));
DROP TYPE pricing_model;
DROP TYPE product_kind;
DROP TYPE product_unit;
CREATE INDEX product_org_id_idx ON product (org_id);

COMMENT ON TABLE product IS 'katalóg produktov; ceny sú v cenníku (0020); produkt sa nemaže, iba ukončí (status)';
COMMENT ON COLUMN product.code IS 'nemenný kód, napr. green_dd3_nie';
COMMENT ON COLUMN product.vat_rate IS 'sadzba DPH v % (elektrina a ZEM 19, služby 23); NULL iba inštalácia FVE (DPH podľa diela)';
COMMENT ON COLUMN product.tariff_type IS 'jednotarif / dvojtarif / nemeraný / netýka sa; poradie návrhu produktov podľa plánovanej spotreby NT';
COMMENT ON COLUMN product.price_models IS 'povolené cenové modely; individuálna cena na zmluve (modul 4) má práve jeden';
COMMENT ON COLUMN product.price_regulation IS 'NULL = nezáleží; true = ANO (domácnosť s energopomocou, malý podnik), false = NIE';
COMMENT ON COLUMN product.status IS 'predava_sa; dobieha = existujúce zmluvy bežia, nové nie; ukonceny';

-- Produkt sa nemaže (žiadna rola); kód a spoločnosť sa nemenia.
CREATE FUNCTION product_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Produkt sa nemaže, iba ukončí (stav Ukončený).' USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.code <> OLD.code OR NEW.org_id <> OLD.org_id THEN
    RAISE EXCEPTION 'Kód a spoločnosť produktu sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON product
  FOR EACH ROW EXECUTE FUNCTION product_guard();

-- ============================================================================
-- Rozsahy PDS a párovanie produkt ↔ sadzba
-- ============================================================================

CREATE TABLE tariff_scope (
  code        text PRIMARY KEY CHECK (code ~ '^[a-z][a-z0-9_]{1,40}$'),
  name        text NOT NULL,
  pds_code    text UNIQUE,
  sort_order  integer NOT NULL DEFAULT 0,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX tariff_scope_one_common ON tariff_scope ((pds_code IS NULL)) WHERE pds_code IS NULL;
COMMENT ON TABLE tariff_scope IS 'rozsah párovania sadzieb: PDS s vlastným párovaním (pds_code) alebo práve jeden spoločný rozsah (pds_code NULL)';
COMMENT ON COLUMN tariff_scope.pds_code IS 'kód z číselníka pds; PDS s vlastným rozsahom nikdy nepoužije spoločné riadky';

CREATE TABLE product_tariff (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id   uuid NOT NULL REFERENCES product (id),
  scope_code   text NOT NULL REFERENCES tariff_scope (code),
  tariff_code  text NOT NULL,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, scope_code, tariff_code)
);
CREATE INDEX product_tariff_lookup_idx ON product_tariff (scope_code, tariff_code);
COMMENT ON TABLE product_tariff IS 'párovanie produkt ↔ sadzba distribúcie v rozsahu PDS (obrazovka 24)';
COMMENT ON COLUMN product_tariff.tariff_code IS 'kód sadzby bez PDS, napr. d3, c2_x3 (tariff_base)';

-- Kód sadzby bez PDS: ('zsd_c2_x3', 'zsd') → 'c2_x3'. Kód hodnoty číselníka sa nemení (0013), preto je stabilný.
CREATE FUNCTION tariff_base(p_code text, p_parent text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN left(p_code, length(p_parent) + 1) = p_parent || '_' THEN substr(p_code, length(p_parent) + 2) END
$$;

-- Rozsah párovania pre PDS: vlastný, inak spoločný.
CREATE FUNCTION oom_tariff_scope(p_pds text) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce((SELECT code FROM tariff_scope WHERE pds_code = p_pds),
                  (SELECT code FROM tariff_scope WHERE pds_code IS NULL))
$$;

-- Rozsah: PDS musí byť v číselníku.
CREATE FUNCTION tariff_scope_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.pds_code IS NOT NULL
     AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = 'pds' AND code = NEW.pds_code) THEN
    RAISE EXCEPTION 'PDS „%“ nie je v číselníku.', NEW.pds_code USING ERRCODE = 'foreign_key_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON tariff_scope
  FOR EACH ROW EXECUTE FUNCTION tariff_scope_check();

-- Párovanie: sadzba musí byť v číselníku (neskrytá) pri PDS rozsahu; pri spoločnom rozsahu
-- aspoň pri jednom PDS bez vlastného rozsahu. Hodnota celej skupiny alebo spoločnosti produktu.
CREATE FUNCTION product_tariff_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE OF scope_code, tariff_code ON product_tariff
  FOR EACH ROW EXECUTE FUNCTION product_tariff_check();

INSERT INTO tariff_scope (code, name, pds_code, sort_order) VALUES
  ('zsd',      'ZSD',               'zsd', 1),
  ('vsd',      'VSD',               'vsd', 2),
  ('spolocne', 'SSD a miestne DS',  NULL,  3);

-- ============================================================================
-- Číselník sadzieb (Peter, odpoveď 9)
-- ============================================================================

INSERT INTO lookup_value (list_code, parent_code, code, label, sort_order) VALUES
  ('sadzba_distribucie', 'zsd', 'zsd_d4', 'D4', 4),
  ('sadzba_distribucie', 'zsd', 'zsd_d5', 'D5', 5),
  ('sadzba_distribucie', 'zsd', 'zsd_d6', 'D6', 6),
  ('sadzba_distribucie', 'zsd', 'zsd_d7', 'D7', 7),
  ('sadzba_distribucie', 'zsd', 'zsd_d8', 'D8', 8),
  ('sadzba_distribucie', 'zsd', 'zsd_c11', 'C11', 18),
  ('sadzba_distribucie', 'vsd', 'vsd_d4', 'D4', 4),
  ('sadzba_distribucie', 'vsd', 'vsd_d5', 'D5', 5),
  ('sadzba_distribucie', 'vsd', 'vsd_d6', 'D6', 6),
  ('sadzba_distribucie', 'vsd', 'vsd_d7', 'D7', 7),
  ('sadzba_distribucie', 'vsd', 'vsd_d8', 'D8', 8),
  ('sadzba_distribucie', 'vsd', 'vsd_c9', 'C9', 17),
  ('sadzba_distribucie', 'vsd', 'vsd_c11', 'C11', 18),
  ('sadzba_distribucie', 'ssd', 'ssd_d7', 'D7', 7),
  ('sadzba_distribucie', 'ssd', 'ssd_c11', 'C11', 18);

-- ZSD C1 neexistuje: skryť (nemazať) – iba ak ju nepoužíva žiadne OOM; inak nič nemeniť (rozhodne Peter).
DO $$
DECLARE
  n integer := (SELECT count(*) FROM oom WHERE pds_tariff = 'zsd_c1');
BEGIN
  IF n > 0 THEN
    RAISE NOTICE 'Sadzba ZSD C1 sa NESKRYLA: používa ju % OOM. Zoznam: SELECT eic FROM oom WHERE pds_tariff = ''zsd_c1''.', n;
  ELSE
    UPDATE lookup_value SET hidden_at = now()
     WHERE list_code = 'sadzba_distribucie' AND code = 'zsd_c1' AND hidden_at IS NULL;
  END IF;
END;
$$;

-- ============================================================================
-- Cenová regulácia OOM: ANO / NIE / nevyplnené (Peter, odpoveď 8)
-- ============================================================================

-- Najprv prevod textu (audit zapíše starú a novú hodnotu), potom zmena typu.
-- lower() v lokalizácii C nemení „Á“, preto aj „Áno“.
SELECT set_config('crm.oom_system', 'on', true);
UPDATE oom
   SET price_regulation = CASE WHEN lower(btrim(price_regulation)) IN ('áno', 'Áno', 'ano') THEN 'true'
                               WHEN lower(btrim(price_regulation)) = 'nie' THEN 'false' END
 WHERE price_regulation IS NOT NULL;
SELECT set_config('crm.oom_system', '', true);
ALTER TABLE oom ALTER COLUMN price_regulation TYPE boolean USING price_regulation::boolean;
COMMENT ON COLUMN oom.price_regulation IS
  'cenová regulácia: true = ANO, false = NIE, NULL = nevyplnené; domácnosť = nárok na energopomoc, firma = cenník pre malé podniky';

-- ============================================================================
-- Návrh produktov pre OOM (po zmene typu cenovej regulácie)
-- ============================================================================

-- Návrh produktov pre OOM (práva volajúceho: cudzie OOM nevráti nič).
-- Produkty v stave Predáva sa, spoločnosť a segment zákazníka OOM, párovanie v rozsahu PDS OOM;
-- cenová regulácia: produkt NULL pasuje vždy, OOM NULL (nevyplnené) dostane ANO aj NIE.
-- rank 1 = navrchu: pri plánovanej spotrebe NT dvojtarifné, inak ostatné. ZEM = doplnková položka (is_addon).
-- is_only = jediný produkt dodávky → CRM ho vyplní samo.
CREATE FUNCTION product_candidates(p_oom_id uuid)
RETURNS TABLE (product_id uuid, rank smallint, is_only boolean, is_addon boolean)
LANGUAGE sql STABLE AS $$
  WITH o AS (
    SELECT o.org_id, o.price_regulation,
           coalesce(o.planned_consumption_nt_mwh, 0) > 0 AS has_nt,
           CASE WHEN o.person_id IS NOT NULL THEN 'domacnost' ELSE 'firma' END::customer_segment AS segment,
           oom_tariff_scope(o.pds) AS scope,
           tariff_base(o.pds_tariff, o.pds) AS tariff
      FROM oom o
     WHERE o.id = p_oom_id AND o.pds IS NOT NULL AND o.pds_tariff IS NOT NULL
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

-- ============================================================================
-- updated_at, audit, RLS
-- ============================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['tariff_scope', 'product_tariff'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_row()', t);
  END LOOP;
END;
$$;

-- Produkt: čítajú aktívni používatelia (aj externí) v spoločnostiach, ktoré vidia; zakladá a mení admin.
-- DELETE bez politiky (a spúšťač zakáže mazanie aj vlastníkovi).
ALTER TABLE product ENABLE ROW LEVEL SECURITY;
CREATE POLICY product_read ON product FOR SELECT
  USING ((SELECT crm_session_ok()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
CREATE POLICY product_insert ON product FOR INSERT
  WITH CHECK ((SELECT crm_settings_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
CREATE POLICY product_update ON product FOR UPDATE
  USING ((SELECT crm_settings_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]))
  WITH CHECK ((SELECT crm_settings_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));

-- Rozsahy: číta každý, mení admin.
ALTER TABLE tariff_scope ENABLE ROW LEVEL SECURITY;
CREATE POLICY settings_read ON tariff_scope FOR SELECT USING ((SELECT crm_session_ok()));
CREATE POLICY settings_insert ON tariff_scope FOR INSERT WITH CHECK ((SELECT crm_settings_writer()));
CREATE POLICY settings_update ON tariff_scope FOR UPDATE
  USING ((SELECT crm_settings_writer())) WITH CHECK ((SELECT crm_settings_writer()));
CREATE POLICY settings_delete ON tariff_scope FOR DELETE USING ((SELECT crm_settings_writer()));

-- Párovanie: riadok vidí, kto vidí produkt; mení a maže admin.
ALTER TABLE product_tariff ENABLE ROW LEVEL SECURITY;
CREATE POLICY product_tariff_read ON product_tariff FOR SELECT
  USING (EXISTS (SELECT 1 FROM product p WHERE p.id = product_id));
CREATE POLICY product_tariff_insert ON product_tariff FOR INSERT
  WITH CHECK ((SELECT crm_settings_writer()) AND EXISTS (SELECT 1 FROM product p WHERE p.id = product_id));
CREATE POLICY product_tariff_update ON product_tariff FOR UPDATE
  USING ((SELECT crm_settings_writer()))
  WITH CHECK ((SELECT crm_settings_writer()) AND EXISTS (SELECT 1 FROM product p WHERE p.id = product_id));
CREATE POLICY product_tariff_delete ON product_tariff FOR DELETE USING ((SELECT crm_settings_writer()));

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM product) THEN
    RAISE EXCEPTION 'Návrat 0019: tabuľka product nie je prázdna (produkt sa nemaže).';
  END IF;
  IF EXISTS (SELECT 1 FROM oom WHERE pds_tariff IN ('zsd_d4', 'zsd_d5', 'zsd_d6', 'zsd_d7', 'zsd_d8', 'zsd_c11',
             'vsd_d4', 'vsd_d5', 'vsd_d6', 'vsd_d7', 'vsd_d8', 'vsd_c9', 'vsd_c11', 'ssd_d7', 'ssd_c11')) THEN
    RAISE EXCEPTION 'Návrat 0019: niektoré OOM používajú sadzbu pridanú touto migráciou.';
  END IF;
END;
$$;

-- Cenová regulácia späť na text: iba „ANO“ / „NIE“ / prázdne (pôvodné texty sa nevrátia – pozri hlavičku).
ALTER TABLE oom ALTER COLUMN price_regulation TYPE text
  USING CASE WHEN price_regulation THEN 'ANO' WHEN NOT price_regulation THEN 'NIE' END;
COMMENT ON COLUMN oom.price_regulation IS NULL;

-- Číselník: ZSD C1 znova viditeľná, pridané sadzby preč (spúšťač mazanie inak nedovolí)
UPDATE lookup_value SET hidden_at = NULL WHERE list_code = 'sadzba_distribucie' AND code = 'zsd_c1';
ALTER TABLE lookup_value DISABLE TRIGGER trg_guard;
DELETE FROM lookup_value
 WHERE list_code = 'sadzba_distribucie'
   AND code IN ('zsd_d4', 'zsd_d5', 'zsd_d6', 'zsd_d7', 'zsd_d8', 'zsd_c11',
                'vsd_d4', 'vsd_d5', 'vsd_d6', 'vsd_d7', 'vsd_d8', 'vsd_c9', 'vsd_c11', 'ssd_d7', 'ssd_c11');
ALTER TABLE lookup_value ENABLE TRIGGER trg_guard;

DROP FUNCTION IF EXISTS product_candidates(uuid);
DROP TABLE IF EXISTS product_tariff;
DROP TABLE IF EXISTS tariff_scope;
DROP FUNCTION IF EXISTS product_tariff_check();
DROP FUNCTION IF EXISTS tariff_scope_check();
DROP FUNCTION IF EXISTS oom_tariff_scope(text);
DROP FUNCTION IF EXISTS tariff_base(text, text);

DROP POLICY IF EXISTS product_read ON product;
DROP POLICY IF EXISTS product_insert ON product;
DROP POLICY IF EXISTS product_update ON product;
ALTER TABLE product DISABLE ROW LEVEL SECURITY;
DROP TRIGGER IF EXISTS trg_guard ON product;
DROP FUNCTION IF EXISTS product_guard();
DROP INDEX IF EXISTS product_org_id_idx;
COMMENT ON TABLE product IS NULL;
COMMENT ON COLUMN product.code IS NULL;

CREATE TYPE product_kind AS ENUM ('dodavka', 'vykup', 'sluzba', 'poplatok');
CREATE TYPE product_unit AS ENUM ('eur_mwh', 'eur_mesiac');
CREATE TYPE pricing_model AS ENUM ('fix', 'spot_aditiv', 'index_spot');
ALTER TABLE product
  DROP CONSTRAINT product_code_check,
  DROP COLUMN org_id,
  DROP COLUMN category,
  DROP COLUMN segment,
  DROP COLUMN vat_rate,
  DROP COLUMN tariff_type,
  DROP COLUMN price_models,
  DROP COLUMN price_regulation,
  DROP COLUMN status,
  DROP COLUMN sort_order,
  ADD COLUMN kind          product_kind NOT NULL,
  ADD COLUMN pricing_model pricing_model,
  ADD COLUMN unit          product_unit NOT NULL,
  ADD COLUMN list_price    numeric(12,4),
  ADD COLUMN valid_from    date,
  ADD COLUMN valid_to      date,
  ADD CONSTRAINT product_validity_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from);
COMMENT ON COLUMN product.list_price IS 'v jednotke podľa unit (€/MWh alebo €/mesiac)';
COMMENT ON COLUMN product.pricing_model IS 'pri SPOT produktoch je aditív v contract_price.additive_eur_mwh';

DROP TYPE IF EXISTS tariff_type;
DROP TYPE IF EXISTS product_status;
DROP TYPE IF EXISTS price_model;
DROP TYPE IF EXISTS product_category;
