-- 0020_cenniky.sql – modul 3 Produkty a cenníky, časť 2: cenníky, verzie, položky, parametre programov
-- (návrh docs/moduly/03-produkty-navrh-db.md v0.3, časti 3, 4, 9; plán 0020 schválený Petrom 13. 10. 2026)
--
-- Cenník má verzie s platnosťou od – do. Uložené stavy: Návrh, Schválená, Nahradená (budúca schválená verzia,
-- ktorú pred účinnosťou nahradila opravená verzia s rovnakým dátumom). Budúca / Platná / Ukončená sa počíta z dátumov.
-- Schválená verzia sa nedá zmeniť pre žiadnu rolu (ani vlastníka): položky, parametre programov ani verziu;
-- povolené je iba uzavretie dátumom „platná do“ (od včera ďalej) a prechod budúcej verzie na Nahradená.
-- Nová verzia vzniká kópiou predošlej (price_list_version_copy), schvaľuje admin (price_list_version_approve):
-- účinnosť od dnes ďalej; minulý dátum smie iba vlastník databázy (skript naplnenia), nikdy rola crm_app.
-- Všetky porovnania s „dnes“ v Europe/Bratislava (crm_today, crm_local_date).
-- Ceny bez DPH v numeric(12,4); pri schválení sa do položky skopíruje sadzba DPH produktu; cena s DPH sa iba dopočíta.
-- Práva: cenníky mení iba admin, čítajú všetci aktívni používatelia svojej spoločnosti; Návrhy vidí iba admin.

-- migrate:up

-- ============================================================================
-- Dátum a rola
-- ============================================================================

-- Dátum okamihu v Europe/Bratislava (23:30 UTC v októbri = nasledujúci deň). crm_today() = crm_local_date(now()).
CREATE FUNCTION crm_local_date(p_at timestamptz) RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT (p_at AT TIME ZONE 'Europe/Bratislava')::date
$$;

-- Spojenie vlastníka databázy (migrácie, skript naplnenia): prihlásený vlastník tabuliek bez SET ROLE
-- a nie spojenie aplikácie. Funguje aj vo funkcii SECURITY DEFINER (current_user tam je vždy vlastník,
-- preto sa kontroluje session_user a nastavenie role, ktoré SET ROLE crm_app zmení).
CREATE FUNCTION crm_owner_session() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT session_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'product'::regclass)
     AND current_setting('role') = 'none'
     AND NOT crm_require_user()
$$;

-- Cenníky smie meniť admin, alebo vlastník databázy (skript naplnenia).
CREATE FUNCTION crm_price_list_writer() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_is_admin() OR crm_owner_session()
$$;

-- Cena s DPH: €/MWh na 4, mesačné sumy na 2 desatinné miesta (120,7275 × 1,19 = 143,6657; 1,50 × 1,19 = 1,79).
CREATE FUNCTION price_with_vat(p_net numeric, p_vat numeric, p_scale integer) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT round(p_net * (1 + p_vat / 100), p_scale)
$$;

-- ============================================================================
-- Tabuľky
-- ============================================================================

CREATE TYPE price_list_version_status AS ENUM ('navrh', 'schvalena', 'nahradena');

CREATE TABLE price_list (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  code         text NOT NULL UNIQUE CHECK (code ~ '^[a-z][a-z0-9_]{1,60}$'),
  name         text NOT NULL CHECK (btrim(name) <> ''),
  segment      customer_segment NOT NULL CHECK (segment IN ('domacnost', 'firma')),
  description  text,
  sort_order   integer NOT NULL DEFAULT 0,
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX price_list_org_id_idx ON price_list (org_id);
COMMENT ON TABLE price_list IS 'cenník (napr. Domácnosti – NIE Energopomoc); zmazať sa dá iba bez schválenej verzie';

CREATE TABLE price_list_version (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  price_list_id   uuid NOT NULL REFERENCES price_list (id) ON DELETE CASCADE,
  name            text NOT NULL CHECK (btrim(name) <> ''),
  valid_from      date NOT NULL,
  valid_to        date,
  status          price_list_version_status NOT NULL DEFAULT 'navrh',
  copied_from_id  uuid REFERENCES price_list_version (id) ON DELETE SET NULL,
  note            text,
  approved_at     timestamptz,
  approved_by     uuid REFERENCES app_user (id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT price_list_version_name_key UNIQUE (price_list_id, name),
  CONSTRAINT price_list_version_period_check CHECK (valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT price_list_version_approved_check CHECK ((status = 'navrh') = (approved_at IS NULL)),
  CONSTRAINT price_list_version_overlap
    EXCLUDE USING gist (price_list_id WITH =, daterange(valid_from, valid_to, '[]') WITH &&) WHERE (status = 'schvalena')
);
CREATE UNIQUE INDEX price_list_version_one_draft ON price_list_version (price_list_id) WHERE status = 'navrh';
COMMENT ON TABLE price_list_version IS 'verzia cenníka; schválená sa nemení (iba uzavretie dátumom), oprava = nová verzia';
COMMENT ON COLUMN price_list_version.valid_to IS 'NULL = do ďalšej verzie; vyplní schválenie nástupcu alebo ukončenie cenníka';
COMMENT ON COLUMN price_list_version.status IS 'navrh; schvalena; nahradena = budúca schválená verzia nahradená pred účinnosťou';
COMMENT ON COLUMN price_list_version.approved_by IS 'admin, ktorý schválil; NULL pri skripte naplnenia';

CREATE TABLE price_list_item (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version_id             uuid NOT NULL REFERENCES price_list_version (id) ON DELETE CASCADE,
  product_id             uuid NOT NULL REFERENCES product (id),
  price_vt_eur_mwh       numeric(12,4) CHECK (price_vt_eur_mwh >= 0),
  price_nt_eur_mwh       numeric(12,4) CHECK (price_nt_eur_mwh >= 0),
  fee_oom_eur_month      numeric(12,4) CHECK (fee_oom_eur_month >= 0),
  fee_program_eur_month  numeric(12,4) CHECK (fee_program_eur_month >= 0),
  fee_kw_eur_month       numeric(12,4) CHECK (fee_kw_eur_month >= 0),
  vat_rate               numeric(5,2) CHECK (vat_rate BETWEEN 0 AND 100),
  sort_order             integer NOT NULL DEFAULT 0,
  created_at             timestamptz NOT NULL DEFAULT now(),
  updated_at             timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT price_list_item_product_key UNIQUE (version_id, product_id),
  CONSTRAINT price_list_item_price_check CHECK (num_nonnulls(price_vt_eur_mwh, price_nt_eur_mwh, fee_oom_eur_month,
                                                             fee_program_eur_month, fee_kw_eur_month) >= 1),
  CONSTRAINT price_list_item_nt_check CHECK (price_nt_eur_mwh IS NULL OR price_vt_eur_mwh IS NOT NULL)
);
CREATE INDEX price_list_item_product_id_idx ON price_list_item (product_id);
COMMENT ON TABLE price_list_item IS 'položka verzie cenníka: ceny bez DPH na 4 desatinné miesta';
COMMENT ON COLUMN price_list_item.price_vt_eur_mwh IS 'VT (pri jednotarife jediná cena) €/MWh bez DPH';
COMMENT ON COLUMN price_list_item.fee_oom_eur_month IS 'mesačná platba za OM (aj ZEM, poplatok B2B) bez DPH';
COMMENT ON COLUMN price_list_item.fee_program_eur_month IS 'mesačný poplatok programu (VBattery, VIWA za OOM) bez DPH';
COMMENT ON COLUMN price_list_item.fee_kw_eur_month IS 'VIWA: poplatok za odchýlku za kW inštalovaného výkonu mesačne bez DPH';
COMMENT ON COLUMN price_list_item.vat_rate IS 'kópia sadzby DPH produktu pri schválení; v Návrhu NULL (platí DPH produktu)';

CREATE TABLE price_list_item_program (
  id                         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id                    uuid NOT NULL UNIQUE REFERENCES price_list_item (id) ON DELETE CASCADE,
  greencar                   boolean NOT NULL DEFAULT false,
  greencar_kwh_per_voucher   integer CHECK (greencar_kwh_per_voucher > 0),
  greencar_voucher_eur       numeric(12,2) CHECK (greencar_voucher_eur >= 0),
  greenshare                 boolean NOT NULL DEFAULT false,
  greenshare_fee_pct         numeric(5,2) CHECK (greenshare_fee_pct BETWEEN 0 AND 100),
  viwa_conversion_factor     numeric(5,4) CHECK (viwa_conversion_factor BETWEEN 0 AND 1),
  viwa_activation_bonus      integer CHECK (viwa_activation_bonus >= 0),
  viwa_credit_expiry_months  smallint CHECK (viwa_credit_expiry_months > 0),
  created_at                 timestamptz NOT NULL DEFAULT now(),
  updated_at                 timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE price_list_item_program IS 'parametre programu VBattery / VIWA pri položke; pevné pre balík, menia sa iba novou verziou';
COMMENT ON COLUMN price_list_item_program.greencar_kwh_per_voucher IS 'VBattery: kWh za voucher (PREMIUM 400, MAX 300)';
COMMENT ON COLUMN price_list_item_program.greenshare_fee_pct IS 'VBattery: poplatok GreenShare v % z prevedených kWh (platí sa v kWh)';
COMMENT ON COLUMN price_list_item_program.viwa_conversion_factor IS 'VIWA: konverzný kurz = SPOT × hodnota';

-- ============================================================================
-- Kontroly v databáze
-- ============================================================================

-- Stav verzie k dátumu (zobrazenie): navrh / buduca / platna / ukoncena.
CREATE FUNCTION price_list_version_state(p_status price_list_version_status, p_from date, p_to date, p_on date)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
           WHEN p_status = 'navrh' THEN 'navrh'
           WHEN p_status = 'nahradena' OR p_to < p_on THEN 'ukoncena'
           WHEN p_from > p_on THEN 'buduca'
           ELSE 'platna'
         END
$$;

-- Cenník: kód a spoločnosť sa nemenia; zmazať iba bez schválenej (alebo nahradenej) verzie.
CREATE FUNCTION price_list_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_guard BEFORE UPDATE OR DELETE ON price_list
  FOR EACH ROW EXECUTE FUNCTION price_list_guard();

-- Verzia: nová iba ako Návrh; schválená sa mení iba uzavretím (valid_to od včera, iba skrátiť)
-- alebo prechodom budúcej verzie na Nahradená; nahradená sa nemení; schválená ani nahradená sa nemaže.
-- Platí pre každú rolu.
CREATE FUNCTION price_list_version_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
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
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON price_list_version
  FOR EACH ROW EXECUTE FUNCTION price_list_version_guard();

-- Položka: iba v Návrhu (pre každú rolu); produkt tej istej spoločnosti a segmentu ako cenník,
-- s modelom „cenník“ a nie ukončený.
CREATE FUNCTION price_list_item_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON price_list_item
  FOR EACH ROW EXECUTE FUNCTION price_list_item_guard();

-- Parametre programu: iba v Návrhu; iba VBattery a VIWA; stĺpce viwa_* iba pri VIWA.
CREATE FUNCTION price_list_item_program_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON price_list_item_program
  FOR EACH ROW EXECUTE FUNCTION price_list_item_program_guard();

-- ============================================================================
-- Funkcie: kópia, schválenie, ukončenie, zmazanie Návrhu
-- ============================================================================

CREATE FUNCTION price_list_writer_check() RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NOT crm_price_list_writer() THEN
    RAISE EXCEPTION 'Cenníky spravuje iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
END;
$$;

-- Nová verzia (Návrh) ako kópia: položky a parametre programov; ukončené produkty vynechá.
-- Vráti { version_id, skipped: [názvy vynechaných produktov] }.
CREATE FUNCTION price_list_version_copy(p_source_id uuid, p_name text, p_valid_from date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Schválenie Návrhu: aspoň jedna položka; účinnosť od dnes (Europe/Bratislava), minulý dátum iba vlastník
-- databázy; kópia DPH do položiek; budúca schválená verzia s rovnakým dátumom → Nahradená; predošlá verzia
-- sa uzavrie deň pred novou; pred neskoršou schválenou verziou sa uzavrie nová.
CREATE FUNCTION price_list_version_approve(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Ukončenie cenníka bez nástupcu: schválená verzia platí do zadaného dňa (dnes alebo neskôr).
CREATE FUNCTION price_list_version_close(p_id uuid, p_valid_to date) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Zmazanie Návrhu (položky a parametre s ním).
CREATE FUNCTION price_list_version_delete(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- ============================================================================
-- Pohľady (práva volajúceho)
-- ============================================================================

CREATE VIEW price_list_version_v WITH (security_invoker = true) AS
SELECT v.id, v.price_list_id, l.org_id, l.code AS price_list_code, l.name AS price_list_name, l.segment,
       v.name, v.valid_from, v.valid_to, v.status,
       price_list_version_state(v.status, v.valid_from, v.valid_to, crm_today()) AS state,
       v.copied_from_id, v.note, v.approved_at, v.approved_by, u.name AS approved_by_name,
       (SELECT count(*) FROM price_list_item i WHERE i.version_id = v.id) AS item_count,
       v.created_at, v.updated_at
  FROM price_list_version v
  JOIN price_list l ON l.id = v.price_list_id
  LEFT JOIN app_user u ON u.id = v.approved_by;

CREATE VIEW price_list_item_v WITH (security_invoker = true) AS
SELECT i.id, i.version_id, v.price_list_id, i.product_id, p.code AS product_code, p.name AS product_name,
       p.category, p.tariff_type, p.status AS product_status, i.sort_order,
       coalesce(i.vat_rate, p.vat_rate) AS vat_rate,
       i.price_vt_eur_mwh, price_with_vat(i.price_vt_eur_mwh, coalesce(i.vat_rate, p.vat_rate), 4) AS price_vt_with_vat,
       i.price_nt_eur_mwh, price_with_vat(i.price_nt_eur_mwh, coalesce(i.vat_rate, p.vat_rate), 4) AS price_nt_with_vat,
       i.fee_oom_eur_month, price_with_vat(i.fee_oom_eur_month, coalesce(i.vat_rate, p.vat_rate), 2) AS fee_oom_with_vat,
       i.fee_program_eur_month, price_with_vat(i.fee_program_eur_month, coalesce(i.vat_rate, p.vat_rate), 2) AS fee_program_with_vat,
       i.fee_kw_eur_month, price_with_vat(i.fee_kw_eur_month, coalesce(i.vat_rate, p.vat_rate), 4) AS fee_kw_with_vat,
       g.greencar, g.greencar_kwh_per_voucher, g.greencar_voucher_eur, g.greenshare, g.greenshare_fee_pct,
       g.viwa_conversion_factor, g.viwa_activation_bonus, g.viwa_credit_expiry_months
  FROM price_list_item i
  JOIN price_list_version v ON v.id = i.version_id
  JOIN product p ON p.id = i.product_id
  LEFT JOIN price_list_item_program g ON g.item_id = i.id;

-- Pre každý cenník platná a najbližšia budúca verzia (obrazovka 20); Návrh iba pre admina (RLS).
CREATE VIEW price_list_current_v WITH (security_invoker = true) AS
SELECT l.id, l.org_id, l.code, l.name, l.segment, l.description, l.sort_order,
       cur.id AS current_version_id, cur.name AS current_version_name, cur.valid_from AS current_valid_from,
       cur.valid_to AS current_valid_to,
       fut.id AS future_version_id, fut.name AS future_version_name, fut.valid_from AS future_valid_from,
       dr.id AS draft_version_id, dr.name AS draft_version_name, dr.valid_from AS draft_valid_from
  FROM price_list l
  LEFT JOIN LATERAL (SELECT v.* FROM price_list_version v
                      WHERE v.price_list_id = l.id
                        AND price_list_version_state(v.status, v.valid_from, v.valid_to, crm_today()) = 'platna'
                      LIMIT 1) cur ON true
  LEFT JOIN LATERAL (SELECT v.* FROM price_list_version v
                      WHERE v.price_list_id = l.id
                        AND price_list_version_state(v.status, v.valid_from, v.valid_to, crm_today()) = 'buduca'
                      ORDER BY v.valid_from LIMIT 1) fut ON true
  LEFT JOIN LATERAL (SELECT v.* FROM price_list_version v
                      WHERE v.price_list_id = l.id AND v.status = 'navrh' LIMIT 1) dr ON true;

-- ============================================================================
-- updated_at, audit, RLS
-- ============================================================================

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['price_list', 'price_list_version', 'price_list_item', 'price_list_item_program'] LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()', t);
    EXECUTE format(
      'CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON %I FOR EACH ROW EXECUTE FUNCTION audit_row()', t);
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
  END LOOP;
END;
$$;

-- Cenník: čítajú aktívni používatelia (aj externí) svojej spoločnosti; mení admin.
CREATE POLICY price_list_read ON price_list FOR SELECT
  USING ((SELECT crm_session_ok()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));
CREATE POLICY price_list_write ON price_list FOR ALL
  USING ((SELECT crm_price_list_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]))
  WITH CHECK ((SELECT crm_price_list_writer()) AND org_id = ANY ((SELECT crm_user_orgs())::uuid[]));

-- Verzia: kto vidí cenník, vidí schválené a nahradené verzie; Návrh iba admin.
CREATE POLICY price_list_version_read ON price_list_version FOR SELECT
  USING (EXISTS (SELECT 1 FROM price_list l WHERE l.id = price_list_id)
         AND (status <> 'navrh' OR (SELECT crm_price_list_writer())));
CREATE POLICY price_list_version_write ON price_list_version FOR ALL
  USING ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list l WHERE l.id = price_list_id))
  WITH CHECK ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list l WHERE l.id = price_list_id));

-- Položka a parametre: podľa viditeľnosti verzie; mení admin (obsah stráži spúšťač).
CREATE POLICY price_list_item_read ON price_list_item FOR SELECT
  USING (EXISTS (SELECT 1 FROM price_list_version v WHERE v.id = version_id));
CREATE POLICY price_list_item_write ON price_list_item FOR ALL
  USING ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list_version v WHERE v.id = version_id))
  WITH CHECK ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list_version v WHERE v.id = version_id));
CREATE POLICY price_list_item_program_read ON price_list_item_program FOR SELECT
  USING (EXISTS (SELECT 1 FROM price_list_item i WHERE i.id = item_id));
CREATE POLICY price_list_item_program_write ON price_list_item_program FOR ALL
  USING ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list_item i WHERE i.id = item_id))
  WITH CHECK ((SELECT crm_price_list_writer()) AND EXISTS (SELECT 1 FROM price_list_item i WHERE i.id = item_id));

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM price_list) THEN
    RAISE EXCEPTION 'Návrat 0020: v cenníkoch sú dáta (schválená verzia sa nemaže).';
  END IF;
END;
$$;

DROP VIEW IF EXISTS price_list_current_v;
DROP VIEW IF EXISTS price_list_item_v;
DROP VIEW IF EXISTS price_list_version_v;
DROP FUNCTION IF EXISTS price_list_version_delete(uuid);
DROP FUNCTION IF EXISTS price_list_version_close(uuid, date);
DROP FUNCTION IF EXISTS price_list_version_approve(uuid);
DROP FUNCTION IF EXISTS price_list_version_copy(uuid, text, date);
DROP FUNCTION IF EXISTS price_list_writer_check();
DROP TABLE IF EXISTS price_list_item_program;
DROP TABLE IF EXISTS price_list_item;
DROP TABLE IF EXISTS price_list_version;
DROP TABLE IF EXISTS price_list;
DROP FUNCTION IF EXISTS price_list_item_program_guard();
DROP FUNCTION IF EXISTS price_list_item_guard();
DROP FUNCTION IF EXISTS price_list_version_guard();
DROP FUNCTION IF EXISTS price_list_guard();
DROP FUNCTION IF EXISTS price_list_version_state(price_list_version_status, date, date, date);
DROP TYPE IF EXISTS price_list_version_status;
DROP FUNCTION IF EXISTS price_with_vat(numeric, numeric, integer);
DROP FUNCTION IF EXISTS crm_price_list_writer();
DROP FUNCTION IF EXISTS crm_owner_session();
DROP FUNCTION IF EXISTS crm_local_date(timestamptz);
