-- migrate:up

-- 0051_pomoc_admini – modul 5, fáza F6, krok 2 (Peter 16. 10., pred nasadením na Test): žiadosť o pomoc s ponukou sa
-- neblokuje, keď v tíme Sales_internal nie je nikto aktívny – dostanú ju aktívni admini (zvonček aj e-mail z crm@);
-- v časovej osi obchodu je, komu išla (detail.komu: sales_internal / admini). Príjemcovia podľa prístupu k spoločnosti
-- obchodu (crm_user_sees_org – aj tímy so všetkými spoločnosťami).

CREATE OR REPLACE FUNCTION deal_help_request(p_deal uuid, p_note text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d      deal;
  v_user uuid := crm_active_user_id();
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_n    integer;
  v_to   text := 'sales_internal';
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF v_user IS NULL OR d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Obchod neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- 0050 (Peter 16. 10.): žiada, kto smie upravovať obchod a nie je v Sales_internal (tím, ktorý pomáha)
  IF NOT crm_deal_editable(d.company_id, d.person_id, d.owner_id)
     OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id WHERE u.id = v_user AND t.code = 'sales_internal') THEN
    RAISE EXCEPTION 'O pomoc s ponukou žiada obchodník, ktorý upravuje obchod (mimo tímu Sales_internal).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;
  IF length(v_note) > 500 THEN
    RAISE EXCEPTION 'Poznámka najviac 500 znakov.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM deal_event e WHERE e.deal_id = d.id AND e.kind = 'pomoc_ziadost' AND e.user_id = v_user
                AND e.occurred_at > now() - interval '10 minutes') THEN
    RAISE EXCEPTION 'Žiadosť o pomoc ste už poslali – tím ju dostal.' USING ERRCODE = 'check_violation';
  END IF;
  v_n := notification_add_deal(
    ARRAY(SELECT u.id FROM app_user u JOIN team t ON t.id = u.team_id
           WHERE t.code = 'sales_internal' AND u.status = 'aktivny' AND u.id <> v_user AND crm_user_sees_org(u.id, d.org_id)),
    'pomoc_s_ponukou', d.id, NULL, crm_today(),
    (SELECT name FROM app_user WHERE id = v_user) || ' žiada o pomoc s ponukou' || coalesce(': ' || v_note, ''));
  -- 0051 (Peter 16. 10.): bez aktívneho člena Sales_internal dostanú žiadosť aktívni admini (zvonček aj e-mail z crm@)
  IF v_n = 0 THEN
    v_to := 'admini';
    v_n := notification_add_deal(
      ARRAY(SELECT u.id FROM app_user u
             WHERE u.is_admin AND u.status = 'aktivny' AND u.id <> v_user AND crm_user_sees_org(u.id, d.org_id)),
      'pomoc_s_ponukou', d.id, NULL, crm_today(),
      (SELECT name FROM app_user WHERE id = v_user) || ' žiada o pomoc s ponukou (v tíme Sales_internal nie je nikto aktívny)'
        || coalesce(': ' || v_note, ''));
  END IF;
  IF v_n = 0 THEN
    RAISE EXCEPTION 'Žiadosť nemá komu prísť (v Sales_internal ani medzi adminmi nie je nikto aktívny).' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, reason, detail)
  VALUES (d.id, d.org_id, 'pomoc_ziadost', v_user, v_note, jsonb_build_object('prijemcovia', v_n, 'komu', v_to));
  RETURN v_n;
END;
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION deal_help_request(p_deal uuid, p_note text) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d      deal;
  v_user uuid := crm_active_user_id();
  v_note text := nullif(btrim(coalesce(p_note, '')), '');
  v_n    integer;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF v_user IS NULL OR d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Obchod neexistuje alebo ho nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- 0050 (Peter 16. 10.): žiada, kto smie upravovať obchod a nie je v Sales_internal (tím, ktorý pomáha)
  IF NOT crm_deal_editable(d.company_id, d.person_id, d.owner_id)
     OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id WHERE u.id = v_user AND t.code = 'sales_internal') THEN
    RAISE EXCEPTION 'O pomoc s ponukou žiada obchodník, ktorý upravuje obchod (mimo tímu Sales_internal).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;
  IF length(v_note) > 500 THEN
    RAISE EXCEPTION 'Poznámka najviac 500 znakov.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM deal_event e WHERE e.deal_id = d.id AND e.kind = 'pomoc_ziadost' AND e.user_id = v_user
                AND e.occurred_at > now() - interval '10 minutes') THEN
    RAISE EXCEPTION 'Žiadosť o pomoc ste už poslali – tím ju dostal.' USING ERRCODE = 'check_violation';
  END IF;
  v_n := notification_add_deal(
    ARRAY(SELECT u.id FROM app_user u JOIN team t ON t.id = u.team_id
           WHERE t.code = 'sales_internal' AND u.status = 'aktivny' AND u.id <> v_user
             AND EXISTS (SELECT 1 FROM app_user_org x WHERE x.user_id = u.id AND x.org_id = d.org_id)),
    'pomoc_s_ponukou', d.id, NULL, crm_today(),
    (SELECT name FROM app_user WHERE id = v_user) || ' žiada o pomoc s ponukou' || coalesce(': ' || v_note, ''));
  IF v_n = 0 THEN
    RAISE EXCEPTION 'V tíme Sales_internal nie je nikto, kto by žiadosť prijal – obráťte sa na obchodného riaditeľa.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, reason, detail)
  VALUES (d.id, d.org_id, 'pomoc_ziadost', v_user, v_note, jsonb_build_object('prijemcovia', v_n));
  RETURN v_n;
END;
$$;
