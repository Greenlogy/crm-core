-- migrate:up

-- 0037_schvalovanie_ponuk – modul 5, fáza F2 (návrh DB časti 1.8, 19.2): žiadosti z ponuky – výnimka z ceny
-- (schválená hranica môže byť iná ako žiadaná, platí 3 dni na odoslanie), rizikový zákazník (konkurz /
-- reštrukturalizácia, rating E/X; celý obchod 30 dní alebo do zhoršenia údajov Finstatu), predĺženie platnosti
-- odoslanej ponuky. Schvaľuje „schvaľuje ceny“ (CEO, obchodný riaditeľ), nikdy žiadateľ. Výnimka → zmluva: F5.

ALTER TABLE approval_request
  ADD CONSTRAINT approval_request_offer_check CHECK (
    CASE kind
      WHEN 'vynimka_ceny' THEN offer_id IS NOT NULL AND deal_id IS NOT NULL
      WHEN 'predlzenie_platnosti' THEN offer_id IS NOT NULL AND deal_id IS NOT NULL AND requested_valid_until IS NOT NULL
      WHEN 'rizikovy_zakaznik' THEN deal_id IS NOT NULL AND company_id IS NOT NULL AND risk_snapshot IS NOT NULL
      ELSE true END);
CREATE UNIQUE INDEX approval_request_pending_offer_key ON approval_request (offer_id, kind)
  WHERE status = 'caka' AND kind IN ('vynimka_ceny', 'predlzenie_platnosti');
CREATE UNIQUE INDEX approval_request_pending_risk_key ON approval_request (deal_id)
  WHERE status = 'caka' AND kind = 'rizikovy_zakaznik';

-- Stav ponuky po zmene žiadostí: zamietnutá alebo zrušená žiadosť → koncept; nič nečaká a kontrola prejde → pripravená
CREATE FUNCTION offer_sync_approvals(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer;
  c jsonb;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND OR o.status <> 'caka_na_schvalenie' THEN
    RETURN;
  END IF;
  IF EXISTS (SELECT 1 FROM approval_request a
              WHERE a.status = 'caka' AND (a.offer_id = o.id OR (a.kind = 'rizikovy_zakaznik' AND a.deal_id = o.deal_id))) THEN
    RETURN;   -- ešte niečo čaká
  END IF;
  c := offer_check(o.id);
  UPDATE offer SET status = CASE WHEN jsonb_array_length(c->'errors') = 0 AND jsonb_array_length(c->'needs') = 0
                                      AND NOT (c->>'risk_needs_approval')::boolean
                                 THEN 'pripravena' ELSE 'koncept' END::offer_status
   WHERE id = o.id;
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_sync_approvals(uuid) FROM PUBLIC;

-- Žiadosť o schválenie ponuky: výnimky z ceny (podľa kontroly ponuky) a rizikový zákazník. Bez potreby schválenia
-- ponuku iba pripraví.
CREATE FUNCTION approval_request_offer(p_offer uuid, p_reason text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o      offer := offer_for_edit(p_offer);
  d      deal;
  c      jsonb;
  n      jsonb;
  v_id   uuid;
  v_user uuid := crm_active_user_id();
  v_appr uuid[];
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena') THEN
    RAISE EXCEPTION 'O schválenie sa žiada pri koncepte ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  c := offer_check(o.id);
  IF jsonb_array_length(c->'errors') > 0 THEN
    RAISE EXCEPTION '%', (SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(c->'errors') e) USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(c->'needs') = 0 AND NOT (c->>'risk_needs_approval')::boolean THEN
    RETURN offer_prepare(o.id);
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod žiadosti o schválenie.' USING ERRCODE = 'check_violation';
  END IF;
  v_appr := array_remove(notification_approvers(o.org_id, false), v_user);

  IF jsonb_array_length(c->'needs') > 0 THEN
    UPDATE approval_request SET status = 'zrusena' WHERE offer_id = o.id AND kind = 'vynimka_ceny' AND status = 'caka';
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by)
    VALUES (o.org_id, 'vynimka_ceny', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user)
    RETURNING id INTO v_id;
    FOR n IN SELECT * FROM jsonb_array_elements(c->'needs') LOOP
      INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value, volume_mwh)
      VALUES (v_id, (n->>'variant_id')::uuid, (n->>'year')::smallint, (n->>'price_model')::price_model, n->>'voltage_group',
              (n->>'requested_value')::numeric, coalesce((n->>'threshold_value')::numeric, 0), (n->>'volume_mwh')::numeric);
    END LOOP;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Výnimka z ceny – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'vynimka_ceny', 'approval_id', v_id));
  END IF;

  IF (c->>'risk_needs_approval')::boolean
     AND NOT EXISTS (SELECT 1 FROM approval_request WHERE deal_id = o.deal_id AND kind = 'rizikovy_zakaznik' AND status = 'caka') THEN
    INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, risk_snapshot)
    VALUES (o.org_id, 'rizikovy_zakaznik', o.deal_id, o.id, d.company_id, btrim(p_reason), v_user, company_risk_snapshot(d.company_id))
    RETURNING id INTO v_id;
    PERFORM notification_add_deal(v_appr, 'schvalenie_nove', o.deal_id, v_id, NULL,
                                  'Rizikový zákazník – ponuka ' || offer_display_number(o));
    PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'rizikovy_zakaznik', 'approval_id', v_id));
  END IF;

  UPDATE offer SET status = 'caka_na_schvalenie' WHERE id = o.id;
  RETURN 'caka_na_schvalenie';
END;
$$;

-- Predĺženie platnosti odoslanej ponuky (iba schvaľovateľ cien)
CREATE FUNCTION approval_request_extend(p_offer uuid, p_until timestamptz, p_reason text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer := offer_for_edit(p_offer);
  v_id uuid;
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') OR o.valid_until IS NULL THEN
    RAISE EXCEPTION 'Predĺžiť sa dá platnosť odoslanej ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_until IS NULL OR p_until <= greatest(o.valid_until, now()) THEN
    RAISE EXCEPTION 'Nová platnosť musí byť neskôr ako doterajšia.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod predĺženia.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO approval_request (org_id, kind, deal_id, offer_id, company_id, reason, requested_by, requested_valid_until)
  VALUES (o.org_id, 'predlzenie_platnosti', o.deal_id, o.id, (SELECT company_id FROM deal WHERE id = o.deal_id),
          btrim(p_reason), crm_active_user_id(), p_until)
  RETURNING id INTO v_id;
  PERFORM notification_add_deal(array_remove(notification_approvers(o.org_id, false), crm_active_user_id()),
                                'schvalenie_nove', o.deal_id, v_id, NULL, 'Predĺženie platnosti – ponuka ' || offer_display_number(o));
  PERFORM deal_event_offer(o, 'schvalenie_ziadost', jsonb_build_object('kind', 'predlzenie_platnosti', 'approval_id', v_id));
  RETURN v_id;
END;
$$;

-- Rozhodnutie o žiadosti (všetky druhy). Výnimka: p_items = [{variant_id, year, price_model, voltage_group,
-- approved_value}], chýbajúca hodnota = žiadaná; schválená hranica nesmie byť vyššia ako žiadaná cena.
DROP FUNCTION approval_decide(uuid, boolean, text);
CREATE FUNCTION approval_decide(p_id uuid, p_approve boolean, p_note text, p_items jsonb DEFAULT NULL) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a      approval_request;
  o      offer;
  it     approval_price_item;
  v_val  numeric;
  v_user uuid := crm_active_user_id();
  v_label text;
BEGIN
  SELECT * INTO a FROM approval_request WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT a.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Žiadosť neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF a.status <> 'caka' THEN
    RAISE EXCEPTION 'Žiadosť už je vybavená.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_user IS NULL OR NOT (CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END) THEN
    RAISE EXCEPTION 'Túto žiadosť nemôžete schváliť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF a.requested_by = v_user THEN
    RAISE EXCEPTION 'Vlastnú žiadosť schváliť nemožno.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_approve IS NULL THEN
    RAISE EXCEPTION 'Chýba rozhodnutie.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT p_approve AND (p_note IS NULL OR btrim(p_note) = '') THEN
    RAISE EXCEPTION 'Pri zamietnutí zadajte poznámku.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO o FROM offer WHERE id = a.offer_id;

  IF p_approve THEN
    CASE a.kind
      WHEN 'pridelenie_firmy' THEN
        IF (SELECT owner_id FROM company WHERE id = a.company_id) IS DISTINCT FROM a.from_owner_id THEN
          RAISE EXCEPTION 'Vlastník firmy sa medzitým zmenil – žiadosť zamietnite alebo nech žiadateľ požiada znova.'
            USING ERRCODE = 'check_violation';
        END IF;
        PERFORM set_config('app.owner_assign', 'on', true);
        UPDATE company SET owner_id = a.requested_by WHERE id = a.company_id;
        PERFORM set_config('app.owner_assign', '', true);
      WHEN 'vynimka_ceny' THEN
        FOR it IN SELECT * FROM approval_price_item WHERE approval_id = a.id LOOP
          v_val := coalesce((SELECT (x->>'approved_value')::numeric FROM jsonb_array_elements(coalesce(p_items, '[]')) x
                              WHERE (x->>'variant_id')::uuid = it.variant_id AND (x->>'year')::smallint = it.year
                                AND x->>'price_model' = it.price_model::text AND x->>'voltage_group' = it.voltage_group),
                            it.requested_value);
          IF v_val > it.requested_value THEN
            RAISE EXCEPTION 'Schválená hranica (%) nemôže byť vyššia ako žiadaná cena (%).', v_val, it.requested_value
              USING ERRCODE = 'check_violation';
          END IF;
          UPDATE approval_price_item SET approved_value = v_val
           WHERE approval_id = it.approval_id AND variant_id = it.variant_id AND year = it.year
             AND price_model = it.price_model AND voltage_group = it.voltage_group;
        END LOOP;
        a.valid_until := now() + interval '3 days';
      WHEN 'rizikovy_zakaznik' THEN
        a.valid_until := now() + interval '30 days';
      WHEN 'predlzenie_platnosti' THEN
        IF o.status NOT IN ('odoslana', 'otvorena') THEN
          RAISE EXCEPTION 'Ponuka už nie je odoslaná – predĺženie nemá zmysel.' USING ERRCODE = 'check_violation';
        END IF;
        UPDATE offer SET valid_until = a.requested_valid_until WHERE id = o.id;
        PERFORM deal_event_offer(o, 'ponuka_platnost', jsonb_build_object('valid_until', a.requested_valid_until, 'extended', true));
    END CASE;
  END IF;

  UPDATE approval_request
     SET status = CASE WHEN p_approve THEN 'schvalena' ELSE 'zamietnuta' END::approval_status,
         decided_by = v_user, decided_at = now(), decision_note = nullif(btrim(p_note), ''),
         valid_until = CASE WHEN p_approve THEN a.valid_until END
   WHERE id = a.id;

  v_label := CASE a.kind WHEN 'pridelenie_firmy' THEN 'Pridelenie firmy' WHEN 'vynimka_ceny' THEN 'Výnimka z ceny'
                         WHEN 'rizikovy_zakaznik' THEN 'Rizikový zákazník' ELSE 'Predĺženie platnosti' END
             || CASE WHEN p_approve THEN ' schválené' ELSE ' zamietnuté' END
             || CASE WHEN o.id IS NOT NULL THEN ' – ponuka ' || offer_display_number(o) ELSE '' END;
  PERFORM notification_add_deal(ARRAY[a.requested_by], 'schvalenie_rozhodnutie', a.deal_id, a.id, NULL, v_label);
  IF a.kind = 'pridelenie_firmy' AND p_approve THEN
    PERFORM notification_add_deal(ARRAY[a.from_owner_id], 'pridelenie_firmy', NULL, a.id, NULL, 'Firma bola pridelená inému obchodníkovi');
  END IF;
  IF o.id IS NOT NULL THEN
    PERFORM deal_event_offer(o, 'schvalenie_rozhodnutie',
      jsonb_build_object('kind', a.kind, 'approval_id', a.id, 'approved', p_approve));
  END IF;

  -- ponuka čakajúca na schválenie: zamietnutie → koncept, všetko schválené → pripravená
  IF a.kind IN ('vynimka_ceny', 'rizikovy_zakaznik') THEN
    IF NOT p_approve THEN
      UPDATE offer SET status = 'koncept' WHERE status = 'caka_na_schvalenie'
         AND (id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND deal_id = a.deal_id));
    ELSE
      PERFORM offer_sync_approvals(x.id) FROM offer x
        WHERE x.status = 'caka_na_schvalenie' AND (x.id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND x.deal_id = a.deal_id));
    END IF;
  END IF;
END;
$$;

-- Žiadateľ svoju čakajúcu žiadosť zruší; ponuka čakajúca na schválenie sa vráti do konceptu
CREATE OR REPLACE FUNCTION approval_cancel(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a approval_request;
BEGIN
  UPDATE approval_request SET status = 'zrusena'
   WHERE id = p_id AND status = 'caka' AND requested_by = crm_active_user_id()
  RETURNING * INTO a;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zrušiť môžete iba vlastnú čakajúcu žiadosť.' USING ERRCODE = 'check_violation';
  END IF;
  IF a.kind IN ('vynimka_ceny', 'rizikovy_zakaznik') THEN
    UPDATE offer SET status = 'koncept' WHERE status = 'caka_na_schvalenie'
       AND (id = a.offer_id OR (a.kind = 'rizikovy_zakaznik' AND deal_id = a.deal_id));
  END IF;
END;
$$;

-- Detail výnimky pre schvaľovateľa (obrazovka 39): položky s objemom, PH s výnimkou; marža iba s právom
CREATE FUNCTION approval_price_detail(p_id uuid) RETURNS TABLE (
  variant_id uuid, variant text, year smallint, price_model price_model, voltage_group text,
  requested_value numeric, threshold_value numeric, approved_value numeric, volume_mwh numeric,
  added_value_requested numeric, portfolio_eur_mwh numeric, margin_requested numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT i.variant_id, chr(64 + v.sort_order) || ' · ' || v.name, i.year, i.price_model, i.voltage_group,
         i.requested_value, i.threshold_value, i.approved_value, i.volume_mwh,
         round((i.requested_value - coalesce(i.approved_value, i.requested_value)) * coalesce(i.volume_mwh, 0), 2),
         CASE WHEN crm_can_see_margin() THEN (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')) END,
         CASE WHEN crm_can_see_margin() AND i.price_model = 'fix' THEN
           round((i.requested_value - (SELECT value FROM contract_market_value(a.org_id, i.year, crm_today(), 'portfolio')))
                 * coalesce(i.volume_mwh, 0), 2) END
    FROM approval_request a
    JOIN approval_price_item i ON i.approval_id = a.id
    JOIN offer_variant v ON v.id = i.variant_id
   WHERE a.id = p_id AND a.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR a.requested_by = crm_active_user_id() OR crm_approves_prices())
   ORDER BY v.sort_order, i.year, i.voltage_group
$$;

-- migrate:down

DROP FUNCTION IF EXISTS approval_price_detail(uuid);
CREATE OR REPLACE FUNCTION approval_cancel(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  UPDATE approval_request SET status = 'zrusena'
   WHERE id = p_id AND status = 'caka' AND requested_by = crm_active_user_id();
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Zrušiť môžete iba vlastnú čakajúcu žiadosť.' USING ERRCODE = 'check_violation';
  END IF;
END;
$$;

DROP FUNCTION IF EXISTS approval_decide(uuid, boolean, text, jsonb);
CREATE FUNCTION approval_decide(p_id uuid, p_approve boolean, p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a      approval_request;
  v_user uuid := crm_active_user_id();
BEGIN
  SELECT * INTO a FROM approval_request WHERE id = p_id FOR UPDATE;
  IF NOT FOUND OR NOT a.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Žiadosť neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF a.status <> 'caka' THEN
    RAISE EXCEPTION 'Žiadosť už je vybavená.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_user IS NULL OR NOT (CASE WHEN a.kind = 'pridelenie_firmy' THEN crm_approves_assignments() ELSE crm_approves_prices() END) THEN
    RAISE EXCEPTION 'Túto žiadosť nemôžete schváliť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF a.requested_by = v_user THEN
    RAISE EXCEPTION 'Vlastnú žiadosť schváliť nemožno.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_approve IS NULL THEN
    RAISE EXCEPTION 'Chýba rozhodnutie.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT p_approve AND (p_note IS NULL OR btrim(p_note) = '') THEN
    RAISE EXCEPTION 'Pri zamietnutí zadajte poznámku.' USING ERRCODE = 'check_violation';
  END IF;
  IF a.kind <> 'pridelenie_firmy' THEN
    RAISE EXCEPTION 'Tento druh žiadosti sa schvaľuje až s ponukami (F2).' USING ERRCODE = 'feature_not_supported';
  END IF;

  IF p_approve THEN
    IF (SELECT owner_id FROM company WHERE id = a.company_id) IS DISTINCT FROM a.from_owner_id THEN
      RAISE EXCEPTION 'Vlastník firmy sa medzitým zmenil – žiadosť zamietnite alebo nech žiadateľ požiada znova.'
        USING ERRCODE = 'check_violation';
    END IF;
    PERFORM set_config('app.owner_assign', 'on', true);
    UPDATE company SET owner_id = a.requested_by WHERE id = a.company_id;
    PERFORM set_config('app.owner_assign', '', true);
  END IF;

  UPDATE approval_request
     SET status = CASE WHEN p_approve THEN 'schvalena' ELSE 'zamietnuta' END::approval_status,
         decided_by = v_user, decided_at = now(), decision_note = nullif(btrim(p_note), '')
   WHERE id = a.id;

  PERFORM notification_add_deal(ARRAY[a.requested_by], 'schvalenie_rozhodnutie', NULL, a.id, NULL,
          CASE WHEN p_approve THEN 'Pridelenie firmy schválené' ELSE 'Pridelenie firmy zamietnuté' END);
  IF p_approve THEN
    PERFORM notification_add_deal(ARRAY[a.from_owner_id], 'pridelenie_firmy', NULL, a.id, NULL,
                                  'Firma bola pridelená inému obchodníkovi');
  END IF;
END;
$$;

DROP FUNCTION IF EXISTS approval_request_extend(uuid, timestamptz, text);
DROP FUNCTION IF EXISTS approval_request_offer(uuid, text);
DROP FUNCTION IF EXISTS offer_sync_approvals(uuid);
DROP INDEX IF EXISTS approval_request_pending_risk_key;
DROP INDEX IF EXISTS approval_request_pending_offer_key;
DELETE FROM approval_request WHERE kind <> 'pridelenie_firmy';
ALTER TABLE approval_request DROP CONSTRAINT approval_request_offer_check;
