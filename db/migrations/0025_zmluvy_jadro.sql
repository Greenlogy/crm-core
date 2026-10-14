-- 0025_zmluvy_jadro.sql – modul 4, fáza F2 (časť 1): jadro zmlúv (plán schválený Petrom 13. 10. 2026,
-- docs/moduly/04-zmluvy-navrh-db.md časť 23).
--
-- Zmluva: fáza z Office portálu a vypočítaný stav (v príprave / podpísaná / účinná / skončená / odmietnutá / neúspešná);
--   koniec podľa CRM (prolongácia, skrátenie nástupcom) v crm_valid_to, údaje z Office portálu sa nemenia.
-- OOM v zmluve (contract_oom): zmluvné množstvo VT/NT v MWh, skutočná doba platnosti; podpísané zmluvy jedného druhu
--   (dodávka; výkup/VIWA) sa na OOM neprekrývajú (EXCLUDE). Nástupníctvo (doplnok a, odpoveď 16): nová podpísaná
--   zmluva s neskorším podpisom a začiatkom skráti predošlú na tom OOM (prolongáciu aj dobu neurčitú) a dostane
--   väzbu „predošlá zmluva“; prekrytie účinností z Office portálu je chyba.
-- Ceny (contract_price, prerobené): zložka × produkt × OOM (VIWA účet bez OOM) × obdobie, cenový model, kópia položky cenníka.
-- Príznaky (contract_flag), výnimky z ceny (price_exception), ochrana stĺpcov z Office portálu, RLS:
--   „iba svoje“ = vlastník zákazníka alebo obchodník, ktorý zmluvu uzavrel (odpoveď 3b); „schvaľuje ceny“ vidí všetky.
-- Stav zákazníka: „Čakajúci“ z podpísanej zmluvy s budúcou účinnosťou (fáza namiesto starého stavu).
-- Preklady importu: druh „fáza“ a systémové preklady fáz Office portálu (O1, O10).
-- Kontrola pred migráciou na dev (db/test-data/0025-pred-migraciou.sql): zmluvy, ceny a dealy prázdne, posledná 0024.

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM contract) OR EXISTS (SELECT 1 FROM contract_price) THEN
    RAISE EXCEPTION 'Tabuľky contract a contract_price musia byť prázdne (0025 ich prerába).';
  END IF;
END;
$$;

-- ============================================================================
-- 1. Enumy
-- ============================================================================

CREATE TYPE contract_type AS ENUM ('dodavka_domacnost', 'dodavka_firma_nn', 'dodavka_firma_vn', 'vykup', 'viwa');
CREATE TYPE contract_phase AS ENUM (
  'rozpracovana', 'caka_na_podpis', 'fyzicke_podpisovanie', 'elektronicke_podpisovanie',
  'podpisana', 'odmietnuta', 'ukoncena', 'neuspesna');
CREATE TYPE contract_close_reason AS ENUM ('akvizicia', 'retencia', 'autoprolong', 'prepis', 'nove_oom');
CREATE TYPE contract_flag_code AS ENUM (
  'pod_hranicou_bez_vynimky', 'chyba_cena', 'sprolongovane_bez_ceny', 'konci_do_4_mesiacov', 'kontrola_importu');
CREATE TYPE price_exception_status AS ENUM ('caka', 'schvalena', 'zamietnuta', 'pouzita');

-- ============================================================================
-- 2. Zmluva
-- ============================================================================

ALTER TABLE contract
  DROP COLUMN status,
  DROP COLUMN confirmed,
  DROP COLUMN signed_at,
  ADD COLUMN op_id                uuid,
  ADD COLUMN type                 contract_type NOT NULL,
  ADD COLUMN phase                contract_phase NOT NULL,
  ADD COLUMN signed_on            date,
  ADD COLUMN crm_valid_to         date,
  ADD COLUMN small_business       boolean NOT NULL DEFAULT false,
  ADD COLUMN list_price           boolean NOT NULL DEFAULT false,
  ADD COLUMN viwa_package         text,
  ADD COLUMN close_reason         contract_close_reason,
  ADD COLUMN owner_id             uuid REFERENCES app_user (id),
  ADD COLUMN created_by_name      text,
  ADD COLUMN previous_contract_id uuid REFERENCES contract (id),
  ADD COLUMN related_contract_id  uuid REFERENCES contract (id),
  ADD COLUMN note                 text,
  ADD COLUMN op_updated_at        timestamptz,
  ALTER COLUMN number SET NOT NULL,
  ADD CONSTRAINT contract_op_id_key UNIQUE (op_id),
  ADD CONSTRAINT contract_viwa_package_check CHECK (viwa_package IN ('basic', 'plus', 'pro')),
  ADD CONSTRAINT contract_crm_valid_to_check CHECK (crm_valid_to IS NULL OR valid_from IS NULL OR crm_valid_to >= valid_from - 1),
  ADD CONSTRAINT contract_previous_check CHECK (previous_contract_id IS DISTINCT FROM id),
  ADD CONSTRAINT contract_related_check CHECK (related_contract_id IS DISTINCT FROM id);
DROP TYPE contract_status;
CREATE INDEX contract_owner_id_idx ON contract (owner_id);
CREATE INDEX contract_previous_idx ON contract (previous_contract_id);

COMMENT ON COLUMN contract.op_id IS 'ID zmluvy v Office portáli (stabilný kľúč importu popri čísle)';
COMMENT ON COLUMN contract.phase IS 'fáza v Office portáli; stav zmluvy sa počíta (contract_state)';
COMMENT ON COLUMN contract.valid_from IS 'účinnosť od (Office portal; domácnosti z XM Trade)';
COMMENT ON COLUMN contract.valid_to IS 'účinnosť do z Office portálu; NULL = na neurčito';
COMMENT ON COLUMN contract.crm_valid_to IS 'koniec podľa CRM: automatická prolongácia alebo skrátenie nástupníckou zmluvou; NULL = podľa valid_to';
COMMENT ON COLUMN contract.signed_on IS 'platnosť od (deň podpisu) z Office portálu';
COMMENT ON COLUMN contract.owner_id IS 'Uzatvoril (obchodník) – z Office portálu cez preklad mena';
COMMENT ON COLUMN contract.previous_contract_id IS 'predošlá zmluva (retencia, prepis, obnova); nastaví aj nástupníctvo na OOM';
COMMENT ON COLUMN contract.related_contract_id IS 'súvisiaca zmluva: VIWA ↔ dodávka toho istého zákazníka';

CREATE FUNCTION contract_effective_to(c contract) RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT coalesce(c.crm_valid_to, c.valid_to)
$$;
COMMENT ON FUNCTION contract_effective_to(contract) IS 'skutočný koniec zmluvy: koniec podľa CRM (prolongácia, nástupca), inak účinnosť do z Office portálu; NULL = neurčito';

-- Stav zmluvy (zadanie časť 3, návrh časť 1.1); dnes v Europe/Bratislava
CREATE FUNCTION contract_state(c contract, p_today date DEFAULT crm_today()) RETURNS text
LANGUAGE sql STABLE AS $$
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
COMMENT ON FUNCTION contract_state(contract, date) IS 'v_priprave, podpisana, ucinna, skoncena, odmietnuta, neuspesna';

-- ============================================================================
-- 3. OOM v zmluve a nástupníctvo
-- ============================================================================

CREATE TABLE contract_oom (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id     uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  oom_id          uuid NOT NULL REFERENCES oom (id),
  org_id          uuid NOT NULL REFERENCES org (id),
  grp             text NOT NULL CHECK (grp IN ('dodavka', 'vykup_viwa')),
  valid_from      date,
  op_valid_to     date,
  valid_to        date,
  successor_id    uuid REFERENCES contract (id),
  is_binding      boolean NOT NULL DEFAULT false,
  product_id      uuid REFERENCES product (id),
  qty_vt_mwh      numeric(12,3) NOT NULL DEFAULT 0 CHECK (qty_vt_mwh >= 0),
  qty_nt_mwh      numeric(12,3) NOT NULL DEFAULT 0 CHECK (qty_nt_mwh >= 0),
  source_power_kw numeric(12,3) CHECK (source_power_kw >= 0),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_oom_unique UNIQUE (contract_id, oom_id),
  CONSTRAINT contract_oom_period_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from - 1),
  CONSTRAINT contract_oom_trim_check CHECK (successor_id IS NULL OR op_valid_to IS NULL OR valid_to >= op_valid_to),
  CONSTRAINT contract_oom_overlap EXCLUDE USING gist (
    oom_id WITH =, grp WITH =, daterange(valid_from, valid_to, '[]') WITH &&)
    WHERE (is_binding AND valid_from IS NOT NULL AND (valid_to IS NULL OR valid_to >= valid_from))
);
CREATE INDEX contract_oom_oom_idx ON contract_oom (oom_id);
CREATE INDEX contract_oom_successor_idx ON contract_oom (successor_id);
COMMENT ON TABLE contract_oom IS 'OOM v zmluve: zmluvné množstvo za rok (MWh), skutočná doba platnosti, nástupnícka zmluva';
COMMENT ON COLUMN contract_oom.valid_to IS 'skutočný koniec OOM v zmluve: účinnosť + prolongácia, skrátený nástupcom; NULL = neurčito';
COMMENT ON COLUMN contract_oom.successor_id IS 'zmluva, ktorá na tomto OOM nastúpila a skrátila túto';

-- Koniec zmluvy podľa CRM z jej OOM: ak majú všetky OOM koniec a líši sa od Office portálu, uloží sa do crm_valid_to
CREATE FUNCTION contract_crm_end_refresh(p_contract_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Nástupníctvo na jednom OOM (časť 2.1): nová podpísaná zmluva r skráti staršiu podpísanú zmluvu toho istého druhu,
-- ak začína neskôr, bola podpísaná neskôr (alebo dátum podpisu chýba) a stará na OOM už iba „dobieha“
-- (prolongácia alebo doba neurčitá – účinnosť z Office portálu skončila pred začiatkom novej alebo nie je).
-- Inak je to skutočné prekrytie z Office portálu → chyba. Zmluva, ktorá na OOM nadväzuje deň po konci staršej
-- (retencia bez prekrytia), dostane väzbu „predošlá zmluva“ bez skracovania.
CREATE FUNCTION contract_oom_succession(r contract_oom, p_new contract) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Riadok OOM v zmluve: spoločnosť, druh a záväznosť zo zmluvy; pri založení obdobie zo zmluvy; nástupníctvo
-- vždy, keď sa riadok stane záväzným alebo sa jeho obdobie rozšíri.
CREATE FUNCTION contract_oom_fill() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
     AND (TG_OP = 'INSERT' OR NOT OLD.is_binding OR NEW.valid_from < OLD.valid_from
          OR (NEW.valid_to IS NULL AND OLD.valid_to IS NOT NULL) OR NEW.valid_to > OLD.valid_to
          OR NEW.oom_id <> OLD.oom_id) THEN
    PERFORM contract_oom_succession(NEW, c);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_fill BEFORE INSERT OR UPDATE ON contract_oom FOR EACH ROW EXECUTE FUNCTION contract_oom_fill();

-- Zmena fázy, účinnosti alebo typu zmluvy sa prenesie na jej OOM (neskrátené OOM dostanú skutočný koniec zmluvy).
-- Odmietnutá alebo neúspešná zmluva, ktorá už skrátila iné zmluvy, im dá príznak „Na kontrolu“ (skrátenie sa nevracia).
CREATE FUNCTION contract_sync() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE contract_oom
     SET valid_from = NEW.valid_from,
         op_valid_to = NEW.valid_to,
         valid_to = CASE WHEN successor_id IS NULL THEN contract_effective_to(NEW) ELSE valid_to END
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
CREATE TRIGGER trg_sync AFTER UPDATE OF phase, type, valid_from, valid_to, crm_valid_to ON contract
  FOR EACH ROW EXECUTE FUNCTION contract_sync();

-- ============================================================================
-- 4. Ceny na zmluve (prerobenie)
-- ============================================================================

DROP TABLE contract_price;
DROP TYPE contract_price_status;

CREATE TABLE contract_price (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id        uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  oom_id             uuid REFERENCES oom (id),
  org_id             uuid NOT NULL REFERENCES org (id),
  slot               text NOT NULL CHECK (slot IN ('komodita', 'poplatok_om', 'zem', 'program', 'viwa_ucet', 'viwa_kw')),
  product_id         uuid NOT NULL REFERENCES product (id),
  price_model        price_model NOT NULL,
  price_list_item_id uuid REFERENCES price_list_item (id),
  valid_from         date NOT NULL,
  valid_to           date,
  price_vt_eur_mwh   numeric(12,4) CHECK (price_vt_eur_mwh >= 0),
  price_nt_eur_mwh   numeric(12,4) CHECK (price_nt_eur_mwh >= 0),
  additive_eur_mwh   numeric(12,4),
  additive_pct       numeric(7,4),
  fee_eur_month      numeric(12,4) CHECK (fee_eur_month >= 0),
  fee_kw_eur_month   numeric(12,4) CHECK (fee_kw_eur_month >= 0),
  vat_rate           numeric(5,2),
  op_product_name    text,
  source             text NOT NULL DEFAULT 'import' CHECK (source IN ('import', 'prolongacia', 'cennik_prechod', 'regulacia', 'crm')),
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_price_period_check CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT contract_price_list_check CHECK ((price_model = 'cennik') = (price_list_item_id IS NOT NULL)),
  CONSTRAINT contract_price_oom_check CHECK ((oom_id IS NULL) = (slot = 'viwa_ucet')),
  CONSTRAINT contract_price_model_check CHECK (CASE price_model
           WHEN 'fix'            THEN price_vt_eur_mwh IS NOT NULL
           WHEN 'spot_plus_eur'  THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_eur' THEN additive_eur_mwh IS NOT NULL
           WHEN 'spot_minus_pct' THEN additive_pct IS NOT NULL
           WHEN 'cena_diela'     THEN false
           ELSE true END),
  CONSTRAINT contract_price_overlap EXCLUDE USING gist (
    contract_id WITH =, (coalesce(oom_id, '00000000-0000-0000-0000-000000000000'::uuid)) WITH =, slot WITH =,
    daterange(valid_from, valid_to, '[]') WITH &&)
);
CREATE INDEX contract_price_contract_idx ON contract_price (contract_id);
CREATE INDEX contract_price_oom_idx ON contract_price (oom_id);
CREATE INDEX contract_price_product_idx ON contract_price (product_id);
CREATE INDEX contract_price_item_idx ON contract_price (price_list_item_id);
COMMENT ON TABLE contract_price IS 'cena zmluvy: zložka (slot) × produkt × OOM (VIWA účet bez OOM) × obdobie; cenníková cena je kópia položky schválenej verzie';
COMMENT ON COLUMN contract_price.fee_eur_month IS 'mesačná platba (za OM, ZEM, program, VIWA účet) bez DPH';
COMMENT ON COLUMN contract_price.valid_to IS 'NULL = bez konca (napr. výkup na neurčito)';

-- Spoločnosť zo zmluvy; OOM musí byť v zmluve; cenníková cena = presná kópia položky schválenej verzie
CREATE FUNCTION contract_price_fill() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
       OR coalesce(i.fee_oom_eur_month, i.fee_program_eur_month) IS DISTINCT FROM NEW.fee_eur_month
       OR i.fee_kw_eur_month IS DISTINCT FROM NEW.fee_kw_eur_month
       OR i.vat_rate IS DISTINCT FROM NEW.vat_rate THEN
      RAISE EXCEPTION 'Cenníková cena sa nezhoduje s položkou cenníka.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_fill BEFORE INSERT OR UPDATE ON contract_price FOR EACH ROW EXECUTE FUNCTION contract_price_fill();

-- ============================================================================
-- 5. Príznaky a výnimky z ceny
-- ============================================================================

CREATE TABLE contract_flag (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id uuid NOT NULL REFERENCES contract (id) ON DELETE CASCADE,
  code        contract_flag_code NOT NULL,
  year        smallint,
  detail      text,
  raised_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  resolved_by uuid REFERENCES app_user (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX contract_flag_open_key ON contract_flag (contract_id, code, coalesce(year, 0)) WHERE resolved_at IS NULL;
COMMENT ON TABLE contract_flag IS 'príznaky zmluvy na kontrolu (pod hranicou, chýba cena, sprolongované bez ceny, končí, import)';

CREATE TABLE price_exception (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id          uuid NOT NULL REFERENCES org (id),
  company_id      uuid REFERENCES company (id),
  person_id       uuid REFERENCES contact (id),
  years           smallint[] NOT NULL CHECK (cardinality(years) >= 1),
  price_model     price_model NOT NULL CHECK (price_model IN ('fix', 'spot_plus_eur', 'spot_minus_eur')),
  requested_value numeric(12,4) NOT NULL,
  threshold_value numeric(12,4) NOT NULL,
  volume_mwh      numeric(12,3),
  reason          text NOT NULL CHECK (btrim(reason) <> ''),
  requested_by    uuid REFERENCES app_user (id),
  status          price_exception_status NOT NULL DEFAULT 'caka',
  decided_by      uuid REFERENCES app_user (id),
  decided_at      timestamptz,
  decision_note   text,
  valid_until     date,
  contract_id     uuid REFERENCES contract (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT price_exception_customer_check CHECK (num_nonnulls(company_id, person_id) = 1),
  CONSTRAINT price_exception_decided_check CHECK ((status <> 'caka') = (decided_at IS NOT NULL)),
  CONSTRAINT price_exception_used_check CHECK ((status = 'pouzita') = (contract_id IS NOT NULL))
);
CREATE INDEX price_exception_company_idx ON price_exception (company_id);
CREATE INDEX price_exception_person_idx ON price_exception (person_id);
COMMENT ON TABLE price_exception IS 'žiadosť obchodníka o cenu pod hranicou; schvaľuje „schvaľuje ceny“ (nie autor); platí 30 dní na podpis';

-- Žiadosť: autor = prihlásený, stav Čaká. Rozhodnutie iba „schvaľuje ceny“ a nie autor; schválená platí 30 dní.
-- Použitá iba z importu (vlastník databázy / funkcia). Po rozhodnutí sa údaje žiadosti nemenia.
CREATE FUNCTION price_exception_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
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
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON price_exception FOR EACH ROW EXECUTE FUNCTION price_exception_guard();

CREATE VIEW price_exception_v WITH (security_invoker = true) AS
SELECT e.*,
       CASE WHEN e.status = 'schvalena' AND e.valid_until < crm_today() THEN 'expirovana' ELSE e.status::text END AS state,
       coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
       ru.name AS requested_by_name, du.name AS decided_by_name
  FROM price_exception e
  LEFT JOIN company c ON c.id = e.company_id
  LEFT JOIN contact p ON p.id = e.person_id
  LEFT JOIN app_user ru ON ru.id = e.requested_by
  LEFT JOIN app_user du ON du.id = e.decided_by;
COMMENT ON VIEW price_exception_v IS 'výnimky so stavom (aj Expirovaná po 30 dňoch), zákazník, autor, schvaľovateľ';

-- ============================================================================
-- 6. Ochrana stĺpcov zmluvy (údaje z Office portálu mení iba import a nočný beh)
-- ============================================================================

CREATE FUNCTION contract_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
DECLARE
  v_system boolean := crm_owner_session()
    OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract'::regclass);
  r contract;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF NOT v_system THEN
      RAISE EXCEPTION 'Zmluva sa nemaže – opravuje sa v Office portáli a ďalším importom.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF TG_OP = 'UPDATE' AND NOT v_system
     AND (to_jsonb(NEW) - ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'updated_at'])
         <> (to_jsonb(OLD) - ARRAY['previous_contract_id', 'related_contract_id', 'close_reason', 'note', 'custom', 'updated_at']) THEN
    RAISE EXCEPTION 'Údaje z Office portálu sa v CRM nemenia – opravte ich v Office portáli a nahrajte export.'
      USING ERRCODE = 'check_violation';
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
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON contract FOR EACH ROW EXECUTE FUNCTION contract_guard();

-- Zápis do OOM v zmluve a cien iba import, nočný beh a vlastník databázy
CREATE FUNCTION contract_child_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$  -- práva volajúceho: current_user = skutočná rola (import a nočný beh = vlastník)
BEGIN
  IF NOT (crm_owner_session()
          OR current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = TG_RELID)) THEN
    RAISE EXCEPTION 'OOM a ceny zmluvy mení iba import z Office portálu.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN coalesce(NEW, OLD);
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON contract_oom FOR EACH ROW EXECUTE FUNCTION contract_child_guard();
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON contract_price FOR EACH ROW EXECUTE FUNCTION contract_child_guard();

-- ============================================================================
-- 7. Pohľad zmlúv
-- ============================================================================

CREATE VIEW contract_v WITH (security_invoker = true) AS
SELECT k.*,
       contract_state(k) AS state,
       contract_effective_to(k) AS effective_to,
       CASE WHEN k.company_id IS NOT NULL THEN 'company' ELSE 'person' END AS customer_kind,
       coalesce(c.name, nullif(concat_ws(' ', p.first_name, p.last_name), '')) AS customer_name,
       u.name AS owner_name,
       (SELECT count(*)::int FROM contract_oom co WHERE co.contract_id = k.id) AS oom_count,
       (SELECT sum(co.qty_vt_mwh + co.qty_nt_mwh) FROM contract_oom co WHERE co.contract_id = k.id) AS qty_mwh,
       coalesce((SELECT array_agg(DISTINCT f.code::text) FROM contract_flag f
                  WHERE f.contract_id = k.id AND f.resolved_at IS NULL), '{}') AS flags
  FROM contract k
  LEFT JOIN company c ON c.id = k.company_id
  LEFT JOIN contact p ON p.id = k.person_id
  LEFT JOIN app_user u ON u.id = k.owner_id;
COMMENT ON VIEW contract_v IS 'zmluva so stavom, skutočným koncom, zákazníkom, obchodníkom, počtom OOM, ročným množstvom a príznakmi';

-- ============================================================================
-- 8. Stav zákazníka: „Čakajúci“ z podpísanej zmluvy s budúcou účinnosťou
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

-- ============================================================================
-- 9. Preklady importu: druh „fáza“
-- ============================================================================

ALTER TABLE import_alias DROP CONSTRAINT import_alias_kind_check,
  ADD CONSTRAINT import_alias_kind_check CHECK (kind IN ('produkt_op', 'produkt_oom', 'sadzba', 'pds', 'obchodnik',
    'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'iny', 'faza'));

CREATE OR REPLACE FUNCTION import_alias_guard() RETURNS trigger
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

INSERT INTO import_alias (org_id, source, kind, name_sample, target, is_system)
SELECT crm_default_org(), 'office_portal', 'faza', v.n, v.t, true
  FROM (VALUES
    ('Rozpracovaná', 'rozpracovana'), ('Čaká na podpis', 'caka_na_podpis'), ('Pripravená na odoslanie', 'caka_na_podpis'),
    ('Fyzické podpisovanie', 'fyzicke_podpisovanie'), ('Elektronické podpisovanie', 'elektronicke_podpisovanie'),
    ('Finálne podpísaná', 'podpisana'), ('Podpísaná', 'podpisana'), ('Odmietnutá', 'odmietnuta'),
    ('Ukončená', 'ukoncena'), ('8', 'ukoncena'), ('Neúspešná', 'neuspesna'), ('9', 'neuspesna')
  ) AS v (n, t);

-- ============================================================================
-- 10. RLS a audit
-- ============================================================================

-- Vidí zmluvu: tím „všetko“ alebo „schvaľuje ceny“ (crm_sees_all_contracts), inak pri „iba svoje“ vlastník zákazníka
-- alebo obchodník, ktorý zmluvu uzavrel (odpoveď 3b). Upraviť (iba údaje CRM): právo upravovať v module Zmluvy.
CREATE FUNCTION crm_contract_visible(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_sees_all_contracts()
      OR (crm_scope('zmluvy', 'view') = 'iba_svoje'
          AND (crm_customer_owned(p_company_id, p_person_id) OR p_owner_id = crm_active_user_id()))
$$;
CREATE FUNCTION crm_contract_editable(p_company_id uuid, p_person_id uuid, p_owner_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_service() OR crm_scope('zmluvy', 'edit') = 'vsetko'
      OR (crm_scope('zmluvy', 'edit') = 'iba_svoje'
          AND (crm_customer_owned(p_company_id, p_person_id) OR p_owner_id = crm_active_user_id()))
$$;

ALTER TABLE contract ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_oom ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_price ENABLE ROW LEVEL SECURITY;
ALTER TABLE contract_flag ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_exception ENABLE ROW LEVEL SECURITY;

CREATE POLICY contract_select ON contract FOR SELECT
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_contract_visible(company_id, person_id, owner_id));
CREATE POLICY contract_update ON contract FOR UPDATE
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_contract_editable(company_id, person_id, owner_id))
  WITH CHECK (org_id = ANY ((SELECT crm_user_orgs())::uuid[]) AND crm_contract_editable(company_id, person_id, owner_id));
CREATE POLICY contract_oom_select ON contract_oom FOR SELECT USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id));
CREATE POLICY contract_price_select ON contract_price FOR SELECT USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id));
CREATE POLICY contract_flag_select ON contract_flag FOR SELECT USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id));
-- príznak uzavrie, kto smie zmluvu upraviť
CREATE POLICY contract_flag_update ON contract_flag FOR UPDATE
  USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id AND crm_contract_editable(k.company_id, k.person_id, k.owner_id)));

CREATE POLICY price_exception_select ON price_exception FOR SELECT
  USING (org_id = ANY ((SELECT crm_user_orgs())::uuid[])
         AND (requested_by = crm_active_user_id() OR crm_sees_all_contracts() OR crm_is_admin() OR crm_is_service()));
CREATE POLICY price_exception_insert ON price_exception FOR INSERT
  WITH CHECK (crm_customer_owned(company_id, person_id) OR crm_sees_all_contracts() OR crm_is_service());
CREATE POLICY price_exception_update ON price_exception FOR UPDATE
  USING (requested_by = crm_active_user_id() OR crm_approves_prices() OR crm_is_service());
CREATE POLICY price_exception_delete ON price_exception FOR DELETE
  USING (requested_by = crm_active_user_id() OR crm_is_service());

CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON contract_oom FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON contract_price FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON contract_flag FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON price_exception FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON contract_oom FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON contract_price FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON contract_flag FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON price_exception FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- migrate:down

-- Návrat do stavu 0024 (zmluvy a ceny sú prázdne – 0025 to vyžaduje, dáta sa nestrácajú).
-- Stĺpce status, confirmed, signed_at sa vrátia na koniec tabuľky contract (poradie stĺpcov sa líši od 0024).

DROP VIEW IF EXISTS contract_v;
DROP VIEW IF EXISTS price_exception_v;
DROP POLICY IF EXISTS contract_select ON contract;
DROP POLICY IF EXISTS contract_update ON contract;
ALTER TABLE contract DISABLE ROW LEVEL SECURITY;
DROP TRIGGER IF EXISTS trg_guard ON contract;
DROP TRIGGER IF EXISTS trg_sync ON contract;
DROP FUNCTION IF EXISTS contract_oom_succession(contract_oom, contract);   -- parameter typu contract_oom
DROP TABLE IF EXISTS price_exception;
DROP TABLE IF EXISTS contract_flag;
DROP TABLE IF EXISTS contract_price;
DROP TABLE IF EXISTS contract_oom;
DROP FUNCTION IF EXISTS crm_contract_visible(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS crm_contract_editable(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS contract_guard();
DROP FUNCTION IF EXISTS contract_child_guard();
DROP FUNCTION IF EXISTS contract_sync();
DROP FUNCTION IF EXISTS contract_oom_fill();
DROP FUNCTION IF EXISTS contract_crm_end_refresh(uuid);
DROP FUNCTION IF EXISTS contract_price_fill();
DROP FUNCTION IF EXISTS price_exception_guard();
DROP FUNCTION IF EXISTS contract_state(contract, date);
DROP FUNCTION IF EXISTS contract_effective_to(contract);

-- Preklady: bez druhu „fáza“ (ako 0023)
DELETE FROM import_alias WHERE kind = 'faza';
ALTER TABLE import_alias DROP CONSTRAINT import_alias_kind_check,
  ADD CONSTRAINT import_alias_kind_check CHECK (kind IN ('produkt_op', 'produkt_oom', 'sadzba', 'pds', 'obchodnik',
    'typ_merania', 'fakturacne_obdobie', 'sposob_zaloh', 'iny'));

CREATE OR REPLACE FUNCTION import_alias_guard() RETURNS trigger
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

-- Stav zákazníka ako pred 0025
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

  -- 2. OOM Pripravované alebo podpísaná zmluva s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'pripravovane')
     OR EXISTS (SELECT 1 FROM contract c
                 WHERE c.company_id IS NOT DISTINCT FROM p_company_id
                   AND c.person_id IS NOT DISTINCT FROM p_person_id
                   AND c.status IN ('podpisana', 'caka_na_zaradenie', 'aktivna')
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

-- Zmluva ako v 0024
DROP INDEX IF EXISTS contract_owner_id_idx;
DROP INDEX IF EXISTS contract_previous_idx;
ALTER TABLE contract
  DROP CONSTRAINT IF EXISTS contract_op_id_key,
  DROP CONSTRAINT IF EXISTS contract_viwa_package_check,
  DROP CONSTRAINT IF EXISTS contract_crm_valid_to_check,
  DROP CONSTRAINT IF EXISTS contract_previous_check,
  DROP CONSTRAINT IF EXISTS contract_related_check,
  DROP COLUMN op_id, DROP COLUMN type, DROP COLUMN phase, DROP COLUMN signed_on, DROP COLUMN crm_valid_to,
  DROP COLUMN small_business, DROP COLUMN list_price, DROP COLUMN viwa_package, DROP COLUMN close_reason,
  DROP COLUMN owner_id, DROP COLUMN created_by_name, DROP COLUMN previous_contract_id, DROP COLUMN related_contract_id,
  DROP COLUMN note, DROP COLUMN op_updated_at,
  ALTER COLUMN number DROP NOT NULL;
CREATE TYPE contract_status AS ENUM (
  'rozpracovana', 'caka_na_podpis', 'podpisana', 'caka_na_zaradenie', 'aktivna', 'ukoncena',
  'vypoved_neakceptovana', 'zmena_neuspesna');
ALTER TABLE contract
  ADD COLUMN status contract_status NOT NULL DEFAULT 'rozpracovana',
  ADD COLUMN confirmed boolean NOT NULL DEFAULT false,
  ADD COLUMN signed_at timestamptz;
COMMENT ON COLUMN contract.valid_from IS NULL;
COMMENT ON COLUMN contract.valid_to IS 'NULL = na neurčito';

-- Ceny zmluvy ako v 0001
CREATE TYPE contract_price_status AS ENUM ('platna', 'neplatna');
CREATE TABLE contract_price (
  id                       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contract_id              uuid NOT NULL REFERENCES contract (id),
  oom_id                   uuid NOT NULL REFERENCES oom (id),
  product_id               uuid REFERENCES product (id),
  direction                price_direction NOT NULL,
  price_vt_eur_mwh         numeric(12,4),
  price_nt_eur_mwh         numeric(12,4),
  additive_eur_mwh         numeric(12,4),
  imbalance_price_eur_mwh  numeric(12,4),
  additive_coefficient_pct numeric(7,4),
  fee_oom_eur_month        numeric(12,2),
  fee_zem_eur_month        numeric(12,2),
  fee_vbattery_eur_month   numeric(12,2),
  fee_rk_eur_kw_month      numeric(12,4),
  vbattery_program         text,
  valid_from               date,
  valid_to                 date,
  status                   contract_price_status NOT NULL DEFAULT 'platna',
  hubspot_id               text,
  created_at               timestamptz NOT NULL DEFAULT now(),
  updated_at               timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT contract_price_validity_check CHECK (valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from),
  CONSTRAINT contract_price_hubspot_id_key UNIQUE (hubspot_id)
);
CREATE INDEX contract_price_contract_id_idx ON contract_price (contract_id);
CREATE UNIQUE INDEX contract_price_one_valid_key ON contract_price (contract_id, oom_id) WHERE status = 'platna';
CREATE INDEX contract_price_oom_id_idx ON contract_price (oom_id);
CREATE INDEX contract_price_product_id_idx ON contract_price (product_id);
COMMENT ON COLUMN contract_price.fee_rk_eur_kw_month IS 'Green VIWA poplatok za rezervovanú kapacitu, €/kW/mesiac (HubSpot green_viwa_poplatok_za_rk__pomocny_)';
COMMENT ON COLUMN contract_price.valid_to IS 'NULL = na neurčito (HubSpot 31. 12. 2099)';
CREATE TRIGGER trg_audit AFTER INSERT OR DELETE OR UPDATE ON contract_price FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON contract_price FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TYPE IF EXISTS price_exception_status;
DROP TYPE IF EXISTS contract_flag_code;
DROP TYPE IF EXISTS contract_close_reason;
DROP TYPE IF EXISTS contract_phase;
DROP TYPE IF EXISTS contract_type;
