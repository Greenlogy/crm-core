-- 0011_customer_delete.sql – zmazanie omylom založenej firmy alebo osoby (Peter 12. 10. 2026)
--
-- Firmu alebo osobu bez väzieb smie zmazať iba admin. Väzby: osoba vo firme, osoba na deale,
-- OOM, deal, zmluva, aktivita, konverzácia; pri osobe aj súhlas, poukážka, odporúčanie, udalosť z webu.
-- Osoba vo firme a osoba na deale sa pri zmazaní mažú automaticky (ON DELETE CASCADE), preto sa
-- kontrolujú vopred – nesmú zmiznúť potichu. Audit (spúšťač audit_row) zapíše kto, kedy a celý
-- pôvodný riadok. Rola aplikácie nemá na company a contact právo DELETE; maže iba táto funkcia.

-- migrate:up

-- Príklad: SELECT customer_delete(NULL, '<id osoby>') → 'Ján Testovací'
CREATE FUNCTION customer_delete(p_company_id uuid, p_person_id uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_name   text;
  v_links  text[];
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_delete: zadaj práve jedno z company_id / person_id';
  END IF;
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Zmazať firmu alebo osobu môže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;

  IF p_company_id IS NOT NULL THEN
    IF NOT crm_company_access(p_company_id, 'view') THEN
      RAISE EXCEPTION 'Firma neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT name INTO v_name FROM company WHERE id = p_company_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE company_id = p_company_id) THEN 'osoby vo firme' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE company_id = p_company_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal WHERE company_id = p_company_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE company_id = p_company_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE company_id = p_company_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE company_id = p_company_id) THEN 'konverzácie' END
    ], NULL);
  ELSE
    IF NOT crm_contact_access(p_person_id, 'view') THEN
      RAISE EXCEPTION 'Osoba neexistuje.' USING ERRCODE = 'no_data_found';
    END IF;
    SELECT concat_ws(' ', first_name, last_name) INTO v_name FROM contact WHERE id = p_person_id;
    v_links := array_remove(ARRAY[
      CASE WHEN EXISTS (SELECT 1 FROM company_contact WHERE contact_id = p_person_id) THEN 'firmy' END,
      CASE WHEN EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM deal WHERE person_id = p_person_id) THEN 'dealy' END,
      CASE WHEN EXISTS (SELECT 1 FROM oom WHERE person_id = p_person_id) THEN 'odberné miesta' END,
      CASE WHEN EXISTS (SELECT 1 FROM contract WHERE person_id = p_person_id) THEN 'zmluvy' END,
      CASE WHEN EXISTS (SELECT 1 FROM activity WHERE contact_id = p_person_id) THEN 'aktivity' END,
      CASE WHEN EXISTS (SELECT 1 FROM conversation WHERE contact_id = p_person_id) THEN 'konverzácie' END,
      CASE WHEN EXISTS (SELECT 1 FROM consent WHERE contact_id = p_person_id) THEN 'súhlasy' END,
      CASE WHEN EXISTS (SELECT 1 FROM voucher WHERE contact_id = p_person_id)
             OR EXISTS (SELECT 1 FROM referral WHERE referrer_contact_id = p_person_id) THEN 'poukážky a odporúčania' END,
      CASE WHEN EXISTS (SELECT 1 FROM web_event WHERE contact_id = p_person_id) THEN 'udalosti z webu' END
    ], NULL);
  END IF;

  IF cardinality(v_links) > 0 THEN
    RAISE EXCEPTION 'Záznam má väzby (%), nedá sa zmazať – iba archivovať.', array_to_string(v_links, ', ')
      USING ERRCODE = 'check_violation';
  END IF;

  IF p_company_id IS NOT NULL THEN
    DELETE FROM company WHERE id = p_company_id;
  ELSE
    DELETE FROM contact WHERE id = p_person_id;
  END IF;
  RETURN v_name;
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS customer_delete(uuid, uuid);
