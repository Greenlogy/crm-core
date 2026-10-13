-- 0021_cennik_nahlad.sql – modul 3 F2: náhľad schválenia verzie cenníka (iba čítanie)
-- (plán F2 schválený Petrom 13. 10. 2026, odpoveď 1)
--
-- price_list_version_approve_preview(verzia) → jsonb: čo urobí price_list_version_approve (0020), bez zmeny dát.
-- Pravidlá sú tie isté ako pri schválení (jedno miesto v databáze, API ich neopakuje):
--   - dá sa schváliť? (Návrh, aspoň jedna položka, účinnosť od dnes v Europe/Bratislava – minulý dátum iba vlastník
--     databázy; budúcu verziu s rovnakým dátumom možno nahradiť, platnú nie),
--   - ktorá schválená verzia sa nahradí, ktorá predošlá sa uzavrie a dokedy, dokedy bude platiť nová,
--   - produkty platnej verzie, ktoré v návrhu chýbajú (ich zmluvy by v module 4 na novú verziu neprešli).
-- Smie iba ten, kto smie schvaľovať (admin, vlastník databázy). Nemení tabuľky ani práva.

-- migrate:up

CREATE FUNCTION price_list_version_approve_preview(p_id uuid) RETURNS jsonb
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
COMMENT ON FUNCTION price_list_version_approve_preview(uuid) IS
  'náhľad price_list_version_approve bez zmeny dát: dá sa schváliť, čo sa nahradí / uzavrie, chýbajúce produkty';

-- migrate:down

DROP FUNCTION IF EXISTS price_list_version_approve_preview(uuid);
