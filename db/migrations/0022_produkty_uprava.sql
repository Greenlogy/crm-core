-- 0022_produkty_uprava.sql – modul 3 F3: úprava produktov a párovania (plán F3 schválený Petrom 13. 10. 2026)
--
-- Použitý produkt (je v položke cenníka): nemení sa kategória, segment, typ tarifu, cenová regulácia ani model „cenník“
-- (DPH sa meniť smie – schválené verzie chráni kópia DPH v položke). Cena NT v položke iba pri dvojtarifnom produkte.
-- Ukončený produkt v návrhu: schválenie aj náhľad ho odmietnu (kontrola pri pridaní položky nestačila).
-- Produkt Dobieha sa smie pridať do návrhu aj skopírovať do novej verzie (existujúce zmluvy potrebujú nové ceny);
-- nové zmluvy (modul 4) smú použiť iba produkt Predáva sa.
-- product_candidates_by(spoločnosť, segment, PDS, sadzba, regulácia, NT) – návrh produktov podľa údajov (ukážka na
-- obrazovke 24); product_candidates(OOM) ju volá, pravidlo je na jednom mieste.
-- Kontrola pred migráciou na dev (db/test-data/0022-pred-migraciou.sql): 17 položiek s NT, všetky dvojtarif.

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM price_list_item i JOIN product p ON p.id = i.product_id
              WHERE i.price_nt_eur_mwh IS NOT NULL AND p.tariff_type <> 'dvojtarif') THEN
    RAISE EXCEPTION 'Niektorá položka cenníka má cenu NT pri produkte, ktorý nie je dvojtarif (db/test-data/0022-pred-migraciou.sql).';
  END IF;
END;
$$;

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

CREATE OR REPLACE FUNCTION price_list_item_guard() RETURNS trigger
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
  -- cena NT iba pri dvojtarifnom produkte (Peter, doplnok b k F3)
  IF NEW.price_nt_eur_mwh IS NOT NULL
     AND (SELECT tariff_type FROM product WHERE id = NEW.product_id) <> 'dvojtarif' THEN
    RAISE EXCEPTION 'Produkt „%“ nie je dvojtarif – cena NT sa nezadáva.', (SELECT name FROM product WHERE id = NEW.product_id)
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION price_list_version_approve(p_id uuid) RETURNS void
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

CREATE OR REPLACE FUNCTION price_list_version_approve_preview(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Návrh produktov podľa údajov (spoločnosť, segment zákazníka, PDS, sadzba z číselníka, cenová regulácia, plánovaná NT).
-- Jediné miesto pravidla (0019): product_candidates(OOM) ju iba zavolá; ukážka na obrazovke 24 ju volá priamo.
CREATE FUNCTION product_candidates_by(p_org uuid, p_segment customer_segment, p_pds text, p_tariff text,
                                      p_regulation boolean, p_has_nt boolean)
RETURNS TABLE (product_id uuid, rank smallint, is_only boolean, is_addon boolean)
LANGUAGE sql STABLE AS $$
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

CREATE OR REPLACE FUNCTION product_candidates(p_oom_id uuid)
RETURNS TABLE (product_id uuid, rank smallint, is_only boolean, is_addon boolean)
LANGUAGE sql STABLE AS $$
  SELECT c.*
    FROM oom o,
         LATERAL product_candidates_by(o.org_id,
                                       CASE WHEN o.person_id IS NOT NULL THEN 'domacnost' ELSE 'firma' END::customer_segment,
                                       o.pds, o.pds_tariff, o.price_regulation,
                                       coalesce(o.planned_consumption_nt_mwh, 0) > 0) c
   WHERE o.id = p_oom_id
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION product_candidates(p_oom_id uuid)
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

DROP FUNCTION IF EXISTS product_candidates_by(uuid, customer_segment, text, text, boolean, boolean);

CREATE OR REPLACE FUNCTION price_list_version_approve_preview(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

CREATE OR REPLACE FUNCTION price_list_version_approve(p_id uuid) RETURNS void
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

CREATE OR REPLACE FUNCTION price_list_item_guard() RETURNS trigger
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

CREATE OR REPLACE FUNCTION product_guard() RETURNS trigger
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
