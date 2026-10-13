-- 0017_oom_delete_plany.sql – zmazanie OOM zmaže aj jeho plánované zmeny (oprava k 0015/0016)
--
-- oom_delete (0015) vznikol pred tabuľkou plánov (0016): OOM, ktoré malo niekedy plán (aj vykonaný
-- alebo zrušený), sa nedalo zmazať (cudzí kľúč). Plány patria OOM, zmažú sa s ním; audit zapíše obsah.
-- Ostatné pravidlá bez zmeny: iba admin, iba OOM bez dealov, cien, ponúk, aktivít, konverzácií a správ OKTE.

-- migrate:up

CREATE OR REPLACE FUNCTION oom_delete(p_oom_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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


-- migrate:down

CREATE OR REPLACE FUNCTION oom_delete(p_oom_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
  DELETE FROM oom_customer WHERE oom_id = p_oom_id;
  DELETE FROM oom WHERE id = p_oom_id;
  PERFORM set_config('crm.oom_system', '', true);
  RETURN v_eic;
END;
$$;

