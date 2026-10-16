-- migrate:up

-- 0049_domov_prehlady – modul 5, fáza F6, krok 2 (návrh DB časť 36.2; Peter 16. 10.): Domov obchodníka a prehľady.
-- - Hlavný variant ponuky (offer_variant.is_main; predvolene prvý, obchodník ho môže označiť; nová verzia ho preberie).
-- - Pridaná hodnota obchodu pre prehľady (deal_value): akceptovaný variant → hlavný variant poslednej odoslanej ponuky → odhad.
-- - Žiadosť o pomoc s ponukou: tímu Sales_internal zvonček a e-mail z crm@ (pomoc_s_ponukou), časová os obchodu.
-- - Domov: cena pre obchodníka na nasledujúce roky a jej vývoj (iba cena pre obchodníka, nikdy BL / PL), môj minimálny
--   aditív a moje percento provízie.

-- ============================================================================
-- 1. Hlavný variant ponuky
-- ============================================================================
ALTER TABLE offer_variant ADD COLUMN is_main boolean NOT NULL DEFAULT false;
COMMENT ON COLUMN offer_variant.is_main IS 'hlavný variant ponuky pre prehľady (0049); ak nie je označený, platí prvý variant';
CREATE UNIQUE INDEX offer_variant_main_key ON offer_variant (offer_id) WHERE is_main;

-- hlavný variant ponuky: označený, inak prvý
CREATE FUNCTION offer_main_variant(p_offer uuid) RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT v.id FROM offer_variant v WHERE v.offer_id = p_offer ORDER BY v.is_main DESC, v.sort_order LIMIT 1
$$;

-- Obchodník (kto smie upravovať obchod) označí hlavný variant; ponuka sa tým nevracia do konceptu (údaj iba pre prehľady)
CREATE FUNCTION offer_variant_set_main(p_variant uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v offer_variant;
  o offer;
  d deal;
BEGIN
  SELECT * INTO v FROM offer_variant WHERE id = p_variant;
  SELECT * INTO o FROM offer WHERE id = v.offer_id FOR UPDATE;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF v.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_editable(d.company_id, d.person_id, d.owner_id)) THEN
    RAISE EXCEPTION 'Ponuka neexistuje alebo ju nemôžete upravovať.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF o.status = 'nahradena' THEN
    RAISE EXCEPTION 'Nahradená verzia ponuky sa nemení.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_variant SET is_main = false WHERE offer_id = o.id AND is_main AND id <> v.id;
  UPDATE offer_variant SET is_main = true WHERE id = v.id AND NOT is_main;
END;
$$;

CREATE OR REPLACE FUNCTION offer_new_version(p_offer uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
  v_exc integer := 0;
  v_cnt integer;
BEGIN
  IF o.status IN ('koncept', 'caka_na_schvalenie', 'pripravena') THEN
    RAISE EXCEPTION 'Rozpracovanú ponuku upravte priamo (alebo prepočítajte na dnešné ceny).' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status IN ('akceptovana', 'nahradena') THEN
    RAISE EXCEPTION 'Z akceptovanej alebo nahradenej verzie sa nová verzia nerobí.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE org_id = o.org_id AND number = o.number
                                   AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) THEN
    RAISE EXCEPTION 'Rozpracovaná verzia už existuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT closed_at FROM deal WHERE id = o.deal_id) IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať novú verziu ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, language, contact_id, priced_on, seller_type,
                     custom, created_by)
  SELECT o.deal_id, o.org_id, o.number, (SELECT max(version) + 1 FROM offer WHERE org_id = o.org_id AND number = o.number),
         o.kind, o.household, 'koncept', o.language, o.contact_id, crm_today(),
         coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik'),
         o.custom, crm_current_user_id()
  RETURNING * INTO n;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                               flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                               negative_price_compensation, is_main)
    VALUES (n.id, n.org_id, v.sort_order, v.name, v.price_kind, v.supply_from, v.supply_to, v.viwa_package,
            v.flexibility_pct, v.planned_volume_mwh, v.invoice_due_days, v.advance_kind, v.advance_pct, v.advance_due_day,
            v.negative_price_compensation, v.is_main)
    RETURNING id INTO v_new;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_new, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i
     WHERE i.variant_id = v.id AND i.price_model <> 'cennik'
       AND (i.oom_id IS NULL OR EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = n.deal_id AND x.oom_id = i.oom_id))
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
    -- schválená výnimka v 3-dňovej lehote prejde s rozsahom zo žiadosti (0038): platí, kým sa OOM, roky a objemy
    -- nezmenia; cena pod schválenou hranicou → výpočet „pod hranicou“ → nové schválenie
    INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                     approved_value, volume_mwh, threshold_source, scope)
    SELECT a.approval_id, v_new, a.year, a.price_model, a.voltage_group, a.requested_value, a.threshold_value,
           a.approved_value, a.volume_mwh, a.threshold_source, a.scope
      FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
     WHERE a.variant_id = v.id AND r.kind = 'vynimka_ceny' AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
       AND r.valid_until > now();
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_exc := v_exc + v_cnt;
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia', CASE WHEN v_exc > 0 THEN jsonb_build_object('exceptions_carried', v_exc) END);
  RETURN n.id;
END;
$$;

-- ============================================================================
-- 2. Pridaná hodnota obchodu v prehľadoch (Peter 16. 10.): akceptovaný variant; inak hlavný variant poslednej odoslanej
--    ponuky; inak odhad na obchode. Iba obchod, ktorý používateľ vidí. PH variantu môže byť záporná.
-- ============================================================================
CREATE FUNCTION deal_value(p_deal uuid) RETURNS TABLE (added_value_eur numeric, source text, variant_id uuid)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     deal;
  v_var uuid;
  v_src text;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN;
  END IF;
  IF d.accepted_variant_id IS NOT NULL THEN
    v_var := d.accepted_variant_id;
    v_src := 'akceptovany';
  ELSE
    SELECT offer_main_variant(o.id) INTO v_var FROM offer o
     WHERE o.deal_id = d.id AND o.sent_at IS NOT NULL AND o.status <> 'nahradena'
     ORDER BY o.sent_at DESC LIMIT 1;
    v_src := 'ponuka';
  END IF;
  IF v_var IS NOT NULL THEN
    RETURN QUERY SELECT s.added_value_eur, v_src, v_var FROM offer_variant_summary(v_var) s WHERE s.year IS NULL;
    IF FOUND THEN
      RETURN;
    END IF;
  END IF;
  RETURN QUERY SELECT d.estimated_value_eur, 'odhad'::text, NULL::uuid;
END;
$$;

-- ============================================================================
-- 3. Žiadosť o pomoc s ponukou (Peter 16. 10.): tímu Sales_internal zvonček a e-mail z crm@; časová os obchodu
-- ============================================================================
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved',
  'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova',
  'chyba_oom_na_zmluve', 'pomoc_s_ponukou'
));
ALTER TABLE email_outbox DROP CONSTRAINT email_outbox_kind_check;
ALTER TABLE email_outbox ADD CONSTRAINT email_outbox_kind_check CHECK (kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'pomoc_s_ponukou'));
DROP TRIGGER trg_email_outbox ON notification;
CREATE TRIGGER trg_email_outbox AFTER INSERT ON notification FOR EACH ROW WHEN (NEW.kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'pomoc_s_ponukou'))
  EXECUTE FUNCTION notification_email_outbox();
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena',
  'ponuka_odblokovana', 'potvrdenie_neodoslane', 'zmluva_sparovana', 'zmluva_odparovana', 'predosla_zmluva',
  'pomoc_ziadost'
));

CREATE FUNCTION deal_help_request(p_deal uuid, p_note text) RETURNS integer
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

-- ============================================================================
-- 4. Domov: iba cena pre obchodníka (nikdy BL / PL – zo vzorca by sa dala dopočítať prirážka a marža), môj minimálny aditív
--    a moje percento provízie
-- ============================================================================
-- cena pre obchodníka na nasledujúce p_years roky k dňu (z ceny dňa najviac 7 dní starej) a deň ceny, z ktorej vychádza
CREATE FUNCTION trader_prices_home(p_org uuid, p_on date, p_years integer DEFAULT 3)
RETURNS TABLE (delivery_year smallint, trader_price numeric, price_date date)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT y.y::smallint, trader_price(p_org, y.y::smallint, p_on),
         (SELECT max(m.on_date) FROM market_price_daily m
           WHERE m.org_id = p_org AND m.delivery_year = y.y AND m.bl_eur_mwh IS NOT NULL AND m.corrected_at IS NULL
             AND m.on_date BETWEEN p_on - 7 AND p_on)
    FROM generate_series(extract(year FROM p_on)::integer + 1, extract(year FROM p_on)::integer + least(greatest(p_years, 1), 5)) y(y)
   WHERE crm_session_ok() AND p_org = ANY (crm_user_orgs())
$$;

-- vývoj ceny pre obchodníka roka dodávky po dňoch s cenou (od 1. 1. 2026, najviac 400 dní)
CREATE FUNCTION trader_price_series(p_org uuid, p_year smallint, p_from date, p_to date)
RETURNS TABLE (on_date date, trader_price numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT m.on_date, trader_price(p_org, p_year, m.on_date)
    FROM market_price_daily m
   WHERE crm_session_ok() AND p_org = ANY (crm_user_orgs())
     AND m.org_id = p_org AND m.delivery_year = p_year AND m.bl_eur_mwh IS NOT NULL AND m.corrected_at IS NULL
     AND m.on_date BETWEEN greatest(p_from, p_to - 400, '2026-01-01') AND least(p_to, crm_today())
   ORDER BY m.on_date
$$;

-- môj minimálny aditív (SPOT) podľa môjho typu predajcu a moje percento provízie k dňu
CREATE FUNCTION my_sales_terms(p_org uuid) RETURNS TABLE (seller_type seller_type, min_additive_eur_mwh numeric, commission_pct numeric)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(u.seller_type, 'obchodnik'),
         contract_param(p_org, CASE WHEN u.seller_type = 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, crm_today()),
         user_commission_pct(u.id)
    FROM app_user u
   WHERE u.id = crm_active_user_id() AND crm_session_ok() AND p_org = ANY (crm_user_orgs())
$$;

-- migrate:down

DROP FUNCTION my_sales_terms(uuid);
DROP FUNCTION trader_price_series(uuid, smallint, date, date);
DROP FUNCTION trader_prices_home(uuid, date, integer);
DROP FUNCTION deal_help_request(uuid, text);
DELETE FROM deal_event WHERE kind = 'pomoc_ziadost';
DELETE FROM email_outbox WHERE kind = 'pomoc_s_ponukou';
DELETE FROM notification WHERE kind = 'pomoc_s_ponukou';
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena',
  'ponuka_odblokovana', 'potvrdenie_neodoslane', 'zmluva_sparovana', 'zmluva_odparovana', 'predosla_zmluva'
));
DROP TRIGGER trg_email_outbox ON notification;
CREATE TRIGGER trg_email_outbox AFTER INSERT ON notification FOR EACH ROW WHEN (NEW.kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana'))
  EXECUTE FUNCTION notification_email_outbox();
ALTER TABLE email_outbox DROP CONSTRAINT email_outbox_kind_check;
ALTER TABLE email_outbox ADD CONSTRAINT email_outbox_kind_check CHECK (kind IN ('schvalenie_nove', 'schvalenie_rozhodnutie', 'ponuka_akceptovana'));
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved',
  'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova',
  'chyba_oom_na_zmluve'
));
DROP FUNCTION deal_value(uuid);
CREATE OR REPLACE FUNCTION offer_new_version(p_offer uuid) RETURNS uuid
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  o     offer := offer_for_edit(p_offer);
  n     offer;
  v     offer_variant;
  v_new uuid;
  v_exc integer := 0;
  v_cnt integer;
BEGIN
  IF o.status IN ('koncept', 'caka_na_schvalenie', 'pripravena') THEN
    RAISE EXCEPTION 'Rozpracovanú ponuku upravte priamo (alebo prepočítajte na dnešné ceny).' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status IN ('akceptovana', 'nahradena') THEN
    RAISE EXCEPTION 'Z akceptovanej alebo nahradenej verzie sa nová verzia nerobí.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer WHERE org_id = o.org_id AND number = o.number
                                   AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena')) THEN
    RAISE EXCEPTION 'Rozpracovaná verzia už existuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT closed_at FROM deal WHERE id = o.deal_id) IS NOT NULL THEN
    RAISE EXCEPTION 'Uzavretý obchod nemôže dostať novú verziu ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  INSERT INTO offer (deal_id, org_id, number, version, kind, household, status, language, contact_id, priced_on, seller_type,
                     custom, created_by)
  SELECT o.deal_id, o.org_id, o.number, (SELECT max(version) + 1 FROM offer WHERE org_id = o.org_id AND number = o.number),
         o.kind, o.household, 'koncept', o.language, o.contact_id, crm_today(),
         coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik'),
         o.custom, crm_current_user_id()
  RETURNING * INTO n;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    INSERT INTO offer_variant (offer_id, org_id, sort_order, name, price_kind, supply_from, supply_to, viwa_package,
                               flexibility_pct, planned_volume_mwh, invoice_due_days, advance_kind, advance_pct, advance_due_day,
                               negative_price_compensation)
    VALUES (n.id, n.org_id, v.sort_order, v.name, v.price_kind, v.supply_from, v.supply_to, v.viwa_package,
            v.flexibility_pct, v.planned_volume_mwh, v.invoice_due_days, v.advance_kind, v.advance_pct, v.advance_due_day,
            v.negative_price_compensation)
    RETURNING id INTO v_new;
    INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id,
                            price_vt_eur_mwh, price_nt_eur_mwh, additive_eur_mwh, additive_pct, fee_eur_month, fee_kw_eur_month)
    SELECT v_new, i.oom_id, i.org_id, i.year, i.slot, i.product_id, i.price_model, i.price_list_item_id,
           i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct, i.fee_eur_month, i.fee_kw_eur_month
      FROM offer_item i
     WHERE i.variant_id = v.id AND i.price_model <> 'cennik'
       AND (i.oom_id IS NULL OR EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = n.deal_id AND x.oom_id = i.oom_id))
    ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
    -- schválená výnimka v 3-dňovej lehote prejde s rozsahom zo žiadosti (0038): platí, kým sa OOM, roky a objemy
    -- nezmenia; cena pod schválenou hranicou → výpočet „pod hranicou“ → nové schválenie
    INSERT INTO approval_price_item (approval_id, variant_id, year, price_model, voltage_group, requested_value, threshold_value,
                                     approved_value, volume_mwh, threshold_source, scope)
    SELECT a.approval_id, v_new, a.year, a.price_model, a.voltage_group, a.requested_value, a.threshold_value,
           a.approved_value, a.volume_mwh, a.threshold_source, a.scope
      FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
     WHERE a.variant_id = v.id AND r.kind = 'vynimka_ceny' AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
       AND r.valid_until > now();
    GET DIAGNOSTICS v_cnt = ROW_COUNT;
    v_exc := v_exc + v_cnt;
  END LOOP;
  PERFORM deal_event_offer(n, 'ponuka_verzia', CASE WHEN v_exc > 0 THEN jsonb_build_object('exceptions_carried', v_exc) END);
  RETURN n.id;
END;
$$;
DROP FUNCTION offer_variant_set_main(uuid);
DROP FUNCTION offer_main_variant(uuid);
DROP INDEX offer_variant_main_key;
ALTER TABLE offer_variant DROP COLUMN is_main;
