-- migrate:up

-- 0050_kalkulacka_pomoc – modul 5, fáza F6, krok 2 (Peter 16. 10., odpovede po 0049):
-- - Kalkulačka na Domove počíta FIX ako ponuka: manažér voči odhadu portfólia, ostatní voči cene pre obchodníka. Odhad
--   portfólia vráti funkcia iba predajcovi typu manažér s právom vidieť maržu firmy; ostatní dostanú iba cenu pre obchodníka.
-- - Žiadosť o pomoc s ponukou pošle iba ten, kto smie upravovať obchod a nie je v tíme Sales_internal; bez aktívneho
--   príjemcu v Sales_internal sa nezapíše.

-- hranica FIX pre kalkulačku na nasledujúce roky: druh hranice, hodnota a deň ceny
CREATE FUNCTION calculator_fix_basis(p_org uuid, p_on date, p_years integer DEFAULT 3)
RETURNS TABLE (delivery_year smallint, basis text, basis_eur_mwh numeric, price_date date)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_portfolio boolean := coalesce((SELECT u.seller_type = 'manazer' FROM app_user u WHERE u.id = crm_active_user_id()), false)
                         AND crm_can_see_margin();
BEGIN
  IF NOT crm_session_ok() OR crm_active_user_id() IS NULL OR NOT p_org = ANY (crm_user_orgs()) THEN
    RETURN;
  END IF;
  IF v_portfolio THEN
    RETURN QUERY
      SELECT h.delivery_year, 'odhad_portfolia'::text, p.value, p.on_date
        FROM trader_prices_home(p_org, p_on, p_years) h
        LEFT JOIN LATERAL contract_market_value(p_org, h.delivery_year, p_on, 'portfolio') p ON true;
  ELSE
    RETURN QUERY
      SELECT h.delivery_year, 'cena_pre_obchodnika'::text, h.trader_price, h.price_date
        FROM trader_prices_home(p_org, p_on, p_years) h;
  END IF;
END;
$$;

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
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, reason, detail)
  VALUES (d.id, d.org_id, 'pomoc_ziadost', v_user, v_note, jsonb_build_object('prijemcovia', v_n));
  RETURN v_n;
END;
$$;
DROP FUNCTION calculator_fix_basis(uuid, date, integer);
