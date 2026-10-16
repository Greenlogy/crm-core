-- migrate:up

-- 0045_zmluvy_k_obchodom – modul 5, fáza F5, krok 1 (návrh DB časti 2.1, 2.2, 2.4, 32; zadanie 9, 10): podklady pre
-- zmluvu a párovanie zmlúv z importu s obchodmi.
-- - Podklady: nové polia firmy (fakturačné e-maily, sociálny podnik, názov pre zmluvu) a OOM (vzťah k nehnuteľnosti,
--   IMS), deal_contract_input, uloženie k firme / kontaktu / OOM naraz, zobrazenie v poradí formulára Office portálu.
-- - Párovanie: obchod : zmluva = 1 : n; párujú sa iba zmluvy prvýkrát importované po zapnutí nastavenia
--   deal_matching (Test aj Ostré zvlášť; počiatočný kmeň zmlúv sa nepáruje – Peter 16. 10.). Kandidát: obchod toho istého
--   zákazníka a druhu v Akceptácii (EIC zmluvy v akceptovanom variante), vo Vyjednávaní (EIC zmluvy na obchode, bez
--   kontroly cien – „spárované bez akceptovanej ponuky“) alebo Vyhraté s ďalšou zmluvou (VN). Jeden kandidát → spárovať;
--   inak Nespárované (upozornenie vlastníkovi zákazníka, inak adminom). Domácnosť bez otvoreného obchodu B2C → Bez obchodu.
-- - Kontrola cien → príznak „Cena iná ako v ponuke“ (obchodník + schvaľovatelia cien; uzatvára schvaľovateľ s poznámkou).
-- - Výnimka z ponuky → zmluva (Použitá, approval_request_id); výnimky modulu 4 sa pre spárované zmluvy nepoužijú.

-- ============================================================================
-- 1. Číselníky a nové polia (podklady pre zmluvu)
-- ============================================================================

INSERT INTO lookup_list (code, name, used_on) VALUES
  ('vztah_k_nehnutelnosti', 'Vzťah k nehnuteľnosti', 'odberné miesto'),
  ('model_vypoctu_vykupu', 'Model výpočtu výkupu', 'zmluva (výkup)');
INSERT INTO lookup_value (list_code, code, label, sort_order) VALUES
  ('vztah_k_nehnutelnosti', 'vlastnik', 'Vlastník nehnuteľnosti', 1),
  ('vztah_k_nehnutelnosti', 'spoluvlastnik', 'Spoluvlastník nehnuteľnosti', 2),
  ('vztah_k_nehnutelnosti', 'najomca', 'Nájomca nehnuteľnosti', 3),
  ('vztah_k_nehnutelnosti', 'rodinny_prislusnik', 'Rodinný príslušník vlastníka', 4),
  ('vztah_k_nehnutelnosti', 'opravneny_uzivatel', 'Oprávnený užívateľ nehnuteľnosti', 5),
  ('vztah_k_nehnutelnosti', 'iny', 'Iný právny vzťah', 6),
  -- text podľa Petra 16. 10. (v exportoch Office portálu sa nevyskytuje – overiť pri prvom výkupe)
  ('model_vypoctu_vykupu', 'isot_sk_zakladny', 'ISOT SK – Základný výpočet (zápor. ceny)', 1);

CREATE FUNCTION email_list_ok(p text[]) RETURNS boolean
LANGUAGE sql IMMUTABLE AS $$
  SELECT cardinality(coalesce(p, '{}')) <= 10
     AND NOT EXISTS (SELECT 1 FROM unnest(coalesce(p, '{}')) e WHERE e !~ '^[^@[:space:]<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' OR length(e) > 254)
$$;

ALTER TABLE company
  ADD COLUMN billing_emails    text[] NOT NULL DEFAULT '{}'
    CHECK (cardinality(billing_emails) <= 10
           AND array_to_string(billing_emails, ',') ~ '^([^@[:space:]<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(,[^@[:space:]<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})*)?$'),
  ADD COLUMN social_enterprise boolean,
  ADD COLUMN contract_name     text CHECK (contract_name IS NULL OR length(contract_name) <= 200);
COMMENT ON COLUMN company.billing_emails IS 'fakturačné e-maily (podklady pre zmluvu, 0045)';
COMMENT ON COLUMN company.contract_name IS 'názov pre zmluvu „v zastúpení“ (podklady pre zmluvu, 0045)';

ALTER TABLE oom
  ADD COLUMN property_relation text,
  ADD COLUMN has_ims           boolean;
COMMENT ON COLUMN oom.property_relation IS 'vzťah k nehnuteľnosti – kód z číselníka vztah_k_nehnutelnosti (0045)';
COMMENT ON COLUMN oom.has_ims IS 'má IMS (inteligentný merací systém) – podklady pre zmluvu (0045)';

CREATE TABLE deal_contract_input (
  id                        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  deal_id                   uuid NOT NULL UNIQUE REFERENCES deal (id) ON DELETE CASCADE,
  close_reason              contract_close_reason NOT NULL DEFAULT 'akvizicia',
  auto_prolong              boolean NOT NULL DEFAULT true,
  product_line              text NOT NULL DEFAULT 'Greenlogy' CHECK (btrim(product_line) <> '' AND length(product_line) <= 80),
  billing_period            text,
  feed_in_contract_type     text,
  feed_in_calc_model        text,
  representative_contact_id uuid REFERENCES contact (id),
  updated_by                uuid REFERENCES app_user (id),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE deal_contract_input IS 'údaje zmluvy, ktoré nie sú pri firme, kontakte ani OOM (podklady pre zmluvu, zadanie 9) – 0045';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON deal_contract_input FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON deal_contract_input FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE POLICY deal_contract_input_select ON deal_contract_input FOR SELECT
  USING (EXISTS (SELECT 1 FROM deal d WHERE d.id = deal_id AND d.org_id = ANY (crm_user_orgs())
                   AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)));
ALTER TABLE deal_contract_input ENABLE ROW LEVEL SECURITY;

-- kto zadáva zmluvu: obchodník obchodu (kto smie obchod upravovať), Servis (domácnosti), Nákup (výkup), admin
CREATE FUNCTION crm_contract_input_editor(d deal) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_active_user_id() IS NOT NULL AND d.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR crm_deal_editable(d.company_id, d.person_id, d.owner_id)
          OR EXISTS (SELECT 1 FROM app_user u JOIN team t ON t.id = u.team_id
                      WHERE u.id = crm_active_user_id() AND t.code IN ('servis', 'nakup')))
$$;

-- Uloženie podkladov naraz k firme, kontaktu (zástupca), OOM obchodu a obchodu. p:
--   company: {bank_account, billing_emails[], vat_payer, social_enterprise, contract_name}
--   representative: {contact_id, title, position, email, phone}
--   contract: {close_reason, auto_prolong, product_line, billing_period, feed_in_contract_type, feed_in_calc_model}
--   ooms: [{oom_id, property_relation, has_ims, previous_supplier (kód číselníka predchadzajuci_dodavatel)}]
-- Kľúč, ktorý v p nie je, sa nemení.
CREATE FUNCTION deal_contract_input_save(p_deal uuid, p jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     deal;
  c     jsonb := p->'company';
  r     jsonb := p->'representative';
  k     jsonb := p->'contract';
  o     jsonb;
  v_rep uuid;
  v_em  text[];
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal FOR UPDATE;
  IF NOT FOUND OR NOT crm_contract_input_editor(d) THEN
    RAISE EXCEPTION 'Podklady pre zmluvu smie upravovať obchodník obchodu, Servis, Nákup alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  -- firma
  IF c IS NOT NULL AND d.company_id IS NOT NULL THEN
    IF c ? 'billing_emails' THEN
      SELECT coalesce(array_agg(lower(btrim(e))) FILTER (WHERE btrim(e) <> ''), '{}') INTO v_em
        FROM jsonb_array_elements_text(coalesce(c->'billing_emails', '[]')) e;
      IF NOT email_list_ok(v_em) THEN
        RAISE EXCEPTION 'Fakturačné e-maily: neplatná adresa (najviac 10).' USING ERRCODE = 'check_violation';
      END IF;
    END IF;
    IF c ? 'bank_account' AND nullif(btrim(c->>'bank_account'), '') IS NOT NULL AND NOT iban_ok(c->>'bank_account') THEN
      RAISE EXCEPTION 'IBAN nemá správny tvar alebo kontrolnú číslicu.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE company SET
      bank_account = CASE WHEN c ? 'bank_account' THEN nullif(upper(replace(btrim(c->>'bank_account'), ' ', '')), '') ELSE bank_account END,
      billing_emails = CASE WHEN c ? 'billing_emails' THEN v_em ELSE billing_emails END,
      vat_payer = CASE WHEN c ? 'vat_payer' THEN (c->>'vat_payer')::boolean ELSE vat_payer END,
      social_enterprise = CASE WHEN c ? 'social_enterprise' THEN (c->>'social_enterprise')::boolean ELSE social_enterprise END,
      contract_name = CASE WHEN c ? 'contract_name' THEN nullif(btrim(c->>'contract_name'), '') ELSE contract_name END
     WHERE id = d.company_id;
  END IF;
  -- zástupca pre zmluvné vzťahy: kontakt obchodu alebo zákazníka
  IF r IS NOT NULL THEN
    v_rep := nullif(r->>'contact_id', '')::uuid;
    IF v_rep IS NOT NULL AND NOT (v_rep = d.person_id
        OR EXISTS (SELECT 1 FROM deal_contact x WHERE x.deal_id = d.id AND x.contact_id = v_rep)
        OR EXISTS (SELECT 1 FROM company_contact x WHERE x.company_id = d.company_id AND x.contact_id = v_rep)) THEN
      RAISE EXCEPTION 'Zástupca musí byť kontakt obchodu alebo zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
    IF v_rep IS NOT NULL THEN
      IF r ? 'email' AND nullif(btrim(r->>'email'), '') IS NOT NULL AND NOT email_list_ok(ARRAY[lower(btrim(r->>'email'))]) THEN
        RAISE EXCEPTION 'E-mail zástupcu nemá správny tvar.' USING ERRCODE = 'check_violation';
      END IF;
      UPDATE contact SET
        title = CASE WHEN r ? 'title' THEN nullif(btrim(r->>'title'), '') ELSE title END,
        position = CASE WHEN r ? 'position' THEN nullif(btrim(r->>'position'), '') ELSE position END,
        email = CASE WHEN r ? 'email' THEN nullif(lower(btrim(r->>'email')), '') ELSE email END,
        phone = CASE WHEN r ? 'phone' THEN nullif(btrim(r->>'phone'), '') ELSE phone END
       WHERE id = v_rep;
    END IF;
  END IF;
  -- obchod (údaje zmluvy)
  IF k IS NOT NULL OR r IS NOT NULL THEN
    IF k ? 'billing_period' AND nullif(k->>'billing_period', '') IS NOT NULL AND NOT lookup_code_ok('fakturacne_obdobie', k->>'billing_period', d.org_id) THEN
      RAISE EXCEPTION 'Neznáme obdobie fakturácie.' USING ERRCODE = 'check_violation';
    END IF;
    IF k ? 'feed_in_contract_type' AND nullif(k->>'feed_in_contract_type', '') IS NOT NULL AND NOT lookup_code_ok('typ_vykupnej_zmluvy', k->>'feed_in_contract_type', d.org_id) THEN
      RAISE EXCEPTION 'Neznámy typ výkupnej zmluvy.' USING ERRCODE = 'check_violation';
    END IF;
    IF k ? 'feed_in_calc_model' AND nullif(k->>'feed_in_calc_model', '') IS NOT NULL AND NOT lookup_code_ok('model_vypoctu_vykupu', k->>'feed_in_calc_model', d.org_id) THEN
      RAISE EXCEPTION 'Neznámy model výpočtu výkupu.' USING ERRCODE = 'check_violation';
    END IF;
    INSERT INTO deal_contract_input (deal_id, updated_by) VALUES (d.id, crm_active_user_id()) ON CONFLICT (deal_id) DO NOTHING;
    UPDATE deal_contract_input SET
      close_reason = CASE WHEN k ? 'close_reason' THEN coalesce(nullif(k->>'close_reason', '')::contract_close_reason, 'akvizicia') ELSE close_reason END,
      auto_prolong = CASE WHEN k ? 'auto_prolong' THEN coalesce((k->>'auto_prolong')::boolean, true) ELSE auto_prolong END,
      product_line = CASE WHEN k ? 'product_line' THEN coalesce(nullif(btrim(k->>'product_line'), ''), 'Greenlogy') ELSE product_line END,
      billing_period = CASE WHEN k ? 'billing_period' THEN nullif(k->>'billing_period', '') ELSE billing_period END,
      feed_in_contract_type = CASE WHEN k ? 'feed_in_contract_type' THEN nullif(k->>'feed_in_contract_type', '') ELSE feed_in_contract_type END,
      feed_in_calc_model = CASE WHEN k ? 'feed_in_calc_model' THEN nullif(k->>'feed_in_calc_model', '') ELSE feed_in_calc_model END,
      representative_contact_id = CASE WHEN r ? 'contact_id' THEN v_rep ELSE representative_contact_id END,
      updated_by = crm_active_user_id()
     WHERE deal_id = d.id;
  END IF;
  -- OOM obchodu
  FOR o IN SELECT * FROM jsonb_array_elements(coalesce(p->'ooms', '[]')) LOOP
    IF NOT EXISTS (SELECT 1 FROM deal_oom x WHERE x.deal_id = d.id AND x.oom_id = (o->>'oom_id')::uuid) THEN
      RAISE EXCEPTION 'OOM nie je na obchode.' USING ERRCODE = 'check_violation';
    END IF;
    IF o ? 'property_relation' AND nullif(o->>'property_relation', '') IS NOT NULL
       AND NOT lookup_code_ok('vztah_k_nehnutelnosti', o->>'property_relation', d.org_id) THEN
      RAISE EXCEPTION 'Neznámy vzťah k nehnuteľnosti.' USING ERRCODE = 'check_violation';
    END IF;
    UPDATE oom SET
      property_relation = CASE WHEN o ? 'property_relation' THEN nullif(o->>'property_relation', '') ELSE property_relation END,
      has_ims = CASE WHEN o ? 'has_ims' THEN (o->>'has_ims')::boolean ELSE has_ims END,
      previous_supplier = CASE WHEN o ? 'previous_supplier' THEN nullif(btrim(o->>'previous_supplier'), '') ELSE previous_supplier END
     WHERE id = (o->>'oom_id')::uuid;
  END LOOP;
END;
$$;

-- IBAN: tvar a kontrolná číslica (mod 97)
CREATE FUNCTION iban_ok(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  s   text := upper(replace(btrim(coalesce(p, '')), ' ', ''));
  t   text;
  rem integer := 0;
  ch  text;
BEGIN
  IF s !~ '^[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}$' THEN
    RETURN false;
  END IF;
  t := substr(s, 5) || substr(s, 1, 4);
  FOREACH ch IN ARRAY regexp_split_to_array(t, '') LOOP
    IF ch ~ '[0-9]' THEN
      rem := (rem * 10 + ch::int) % 97;
    ELSE
      rem := (rem * 100 + (ascii(ch) - 55)) % 97;
    END IF;
  END LOOP;
  RETURN rem = 1;
END;
$$;

-- Chýbajúce polia podkladov (podľa druhu zmluvy): {filled, total, missing: [text]}
CREATE FUNCTION deal_contract_input_missing(p_deal uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d     deal;
  k     pipeline;
  ci    deal_contract_input;
  co    company;
  rep   contact;
  m     text[] := '{}';
  total integer := 0;
  r     record;
  supply boolean;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  SELECT * INTO k FROM pipeline WHERE id = d.pipeline_id;
  SELECT * INTO ci FROM deal_contract_input WHERE deal_id = d.id;
  SELECT * INTO co FROM company WHERE id = d.company_id;
  SELECT * INTO rep FROM contact WHERE id = ci.representative_contact_id;
  supply := k.kind IN ('b2b_dodavka', 'b2c_dodavka');
  -- zmluva
  total := total + 1; IF ci.billing_period IS NULL THEN m := m || 'obdobie fakturácie'::text; END IF;
  IF k.kind = 'b2b_vykup' THEN
    total := total + 2;
    IF ci.feed_in_contract_type IS NULL THEN m := m || 'typ výkupnej zmluvy'::text; END IF;
    IF ci.feed_in_calc_model IS NULL THEN m := m || 'model výpočtu výkupu'::text; END IF;
  END IF;
  -- firma
  IF d.company_id IS NOT NULL THEN
    total := total + 4;
    IF co.bank_account IS NULL THEN m := m || 'IBAN'::text; END IF;
    IF cardinality(co.billing_emails) = 0 THEN m := m || 'fakturačné e-maily'::text; END IF;
    IF co.vat_payer IS NULL THEN m := m || 'platca DPH'::text; END IF;
    IF co.social_enterprise IS NULL THEN m := m || 'sociálny podnik'::text; END IF;
    -- zástupca
    total := total + 3;
    IF rep.id IS NULL THEN
      m := m || 'zástupca pre zmluvné vzťahy'::text || 'e-mail zástupcu'::text || 'telefón zástupcu'::text;
    ELSE
      IF rep.email IS NULL THEN m := m || 'e-mail zástupcu'::text; END IF;
      IF rep.phone IS NULL AND rep.mobile IS NULL THEN m := m || 'telefón zástupcu'::text; END IF;
    END IF;
  END IF;
  -- OOM
  FOR r IN SELECT o.eic, o.property_relation, o.has_ims, o.previous_supplier FROM deal_oom x JOIN oom o ON o.id = x.oom_id
            WHERE x.deal_id = d.id ORDER BY o.eic LOOP
    total := total + CASE WHEN supply THEN 3 ELSE 2 END;
    IF r.property_relation IS NULL THEN m := m || ('vzťah k nehnuteľnosti ' || r.eic); END IF;
    IF r.has_ims IS NULL THEN m := m || ('IMS ' || r.eic); END IF;
    IF supply AND r.previous_supplier IS NULL THEN m := m || ('predchádzajúci dodávateľ ' || r.eic); END IF;
  END LOOP;
  RETURN jsonb_build_object('filled', total - cardinality(m), 'total', total, 'missing', to_jsonb(m));
END;
$$;

-- Podklady pre zmluvu (obrazovka 38): v poradí formulára Office portálu; dodávka firme s NN aj VN = dve zmluvy
CREATE FUNCTION deal_contract_input_view(p_deal uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d    deal;
  k    pipeline;
  ci   deal_contract_input;
  co   company;
  pe   contact;
  rep  contact;
  u    app_user;
  acc  offer_acceptance;
  v    offer_variant;
  o    offer;
  grp  text;
  res  jsonb := '[]';
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  SELECT * INTO k FROM pipeline WHERE id = d.pipeline_id;
  SELECT * INTO ci FROM deal_contract_input WHERE deal_id = d.id;
  SELECT * INTO co FROM company WHERE id = d.company_id;
  SELECT * INTO pe FROM contact WHERE id = d.person_id;
  SELECT * INTO rep FROM contact WHERE id = ci.representative_contact_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  SELECT * INTO v FROM offer_variant WHERE id = d.accepted_variant_id;
  SELECT * INTO o FROM offer WHERE id = v.offer_id;
  SELECT * INTO acc FROM offer_acceptance WHERE offer_id = o.id AND variant_id = v.id AND revoked_at IS NULL ORDER BY accepted_at DESC LIMIT 1;

  FOR grp IN SELECT DISTINCT CASE WHEN k.kind = 'b2b_dodavka' THEN oom_voltage_group(m.voltage_level) ELSE 'vsetko' END
               FROM deal_oom x JOIN oom m ON m.id = x.oom_id WHERE x.deal_id = d.id ORDER BY 1 LOOP
    res := res || jsonb_build_array(jsonb_build_object(
      'group', grp,
      'ooms', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                 'oom_id', m.id, 'eic', m.eic, 'type', m.type,
                 'address', concat_ws(', ', nullif(concat_ws(' ', m.address_street, nullif(concat_ws('/', m.address_number_supisne, m.address_number_orientacne), '')), ''),
                                      nullif(concat_ws(' ', m.address_zip, m.address_city), '')),
                 'name', m.name, 'voltage_level', m.voltage_level, 'pds', m.pds,
                 'planned_vt_mwh', coalesce(x.planned_vt_mwh, m.planned_consumption_vt_mwh),
                 'planned_nt_mwh', coalesce(x.planned_nt_mwh, m.planned_consumption_nt_mwh),
                 'planned_feed_in_mwh', coalesce(x.planned_feed_in_mwh, m.planned_feed_in_mwh),
                 'source_power_kw', coalesce(x.source_power_kw, m.source_power_kw),
                 'property_relation', m.property_relation,
                 'property_relation_label', (SELECT label FROM lookup_value WHERE list_code = 'vztah_k_nehnutelnosti' AND code = m.property_relation LIMIT 1),
                 'has_ims', m.has_ims, 'previous_supplier', m.previous_supplier,
                 'previous_supplier_label', (SELECT label FROM lookup_value WHERE list_code = 'predchadzajuci_dodavatel' AND code = m.previous_supplier LIMIT 1)) ORDER BY m.eic), '[]')
                 FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                WHERE x.deal_id = d.id AND (grp = 'vsetko' OR oom_voltage_group(m.voltage_level) = grp)),
      'prices', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                   'product', pr.name, 'year', i.year, 'price_model', i.price_model,
                   'text', CASE i.price_model
                             WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num(i.additive_eur_mwh, 2, 'sk') || ' €/MWh'
                             WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num(i.additive_eur_mwh, 2, 'sk') || ' €/MWh'
                             WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num(i.additive_pct, 2, 'sk') || ' %'
                             ELSE offer_fmt_num(i.price_vt_eur_mwh, 2, 'sk')
                                  || CASE WHEN i.price_nt_eur_mwh IS NOT NULL THEN ' / ' || offer_fmt_num(i.price_nt_eur_mwh, 2, 'sk') ELSE '' END || ' €/MWh' END)
                   ORDER BY i.year NULLS FIRST, pr.name), '[]')
                   FROM (SELECT DISTINCT i.year, i.product_id, i.price_model, i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct
                           FROM offer_item i JOIN oom m ON m.id = i.oom_id
                          WHERE i.variant_id = v.id AND i.slot = 'komodita'
                            AND (grp = 'vsetko' OR oom_voltage_group(m.voltage_level) = grp)) i
                   JOIN product pr ON pr.id = i.product_id),
      'exceptions', (SELECT coalesce(jsonb_agg(jsonb_build_object(
                       'year', a.year, 'value', coalesce(a.approved_value, a.requested_value), 'threshold', a.threshold_value,
                       'decided_by', du.name, 'decided_at', r.decided_at) ORDER BY a.year), '[]')
                       FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
                       LEFT JOIN app_user du ON du.id = r.decided_by
                      WHERE a.variant_id = v.id AND r.status = 'schvalena' AND r.kind = 'vynimka_ceny'
                        AND (grp = 'vsetko' OR a.voltage_group IN (grp, 'vsetko')))));
  END LOOP;

  RETURN jsonb_build_object(
    'deal', jsonb_build_object('id', d.id, 'name', d.name, 'kind', k.kind, 'supply_start', d.supply_start,
                               'stage', (SELECT code FROM pipeline_stage WHERE id = d.stage_id)),
    'acceptance', CASE WHEN acc.id IS NOT NULL THEN jsonb_build_object(
                    'accepted_at', acc.accepted_at, 'signer_name', acc.signer_name, 'signer_function', acc.signer_function,
                    'method', acc.method, 'channel', acc.channel, 'offer_number', offer_display_number(o),
                    'variant', chr(64 + v.sort_order) || ' – ' || v.name, 'due', (acc.accepted_at + interval '14 days')) END,
    'header', jsonb_build_object('seller', u.name, 'close_reason', coalesce(ci.close_reason, 'akvizicia'),
                                 'product_line', coalesce(ci.product_line, 'Greenlogy'), 'auto_prolong', coalesce(ci.auto_prolong, true),
                                 'billing_period', ci.billing_period,
                                 'billing_period_label', (SELECT label FROM lookup_value WHERE list_code = 'fakturacne_obdobie' AND code = ci.billing_period LIMIT 1),
                                 'feed_in_contract_type', ci.feed_in_contract_type,
                                 'feed_in_contract_type_label', (SELECT label FROM lookup_value WHERE list_code = 'typ_vykupnej_zmluvy' AND code = ci.feed_in_contract_type LIMIT 1),
                                 'feed_in_calc_model', ci.feed_in_calc_model,
                                 'feed_in_calc_model_label', (SELECT label FROM lookup_value WHERE list_code = 'model_vypoctu_vykupu' AND code = ci.feed_in_calc_model LIMIT 1)),
    'customer', CASE WHEN co.id IS NOT NULL THEN jsonb_build_object(
                  'kind', 'company', 'name', co.name, 'ico', co.ico, 'dic', co.dic, 'ic_dph', co.ic_dph, 'address', co.address,
                  'registry_entry', co.registry_entry, 'vat_payer', co.vat_payer, 'social_enterprise', co.social_enterprise,
                  'contract_name', co.contract_name, 'bank_account', co.bank_account, 'billing_emails', to_jsonb(co.billing_emails))
                ELSE jsonb_build_object('kind', 'person', 'name', concat_ws(' ', pe.title, pe.first_name, pe.last_name), 'address', pe.address,
                                        'email', pe.email, 'phone', coalesce(pe.mobile, pe.phone)) END,
    'representative', CASE WHEN rep.id IS NOT NULL THEN jsonb_build_object(
                        'contact_id', rep.id, 'title', rep.title, 'first_name', rep.first_name, 'last_name', rep.last_name,
                        'position', rep.position, 'email', rep.email, 'phone', coalesce(rep.mobile, rep.phone)) END,
    'contacts', (SELECT coalesce(jsonb_agg(jsonb_build_object('id', x.id, 'name', concat_ws(' ', x.title, x.first_name, x.last_name)) ORDER BY x.last_name), '[]')
                   FROM contact x
                  WHERE x.id IN (SELECT dc.contact_id FROM deal_contact dc WHERE dc.deal_id = d.id
                                 UNION SELECT cc.contact_id FROM company_contact cc WHERE cc.company_id = d.company_id)),
    'contracts', res,
    'completeness', deal_contract_input_missing(d.id),
    'can_edit', crm_contract_input_editor(d));
END;
$$;

-- ============================================================================
-- 2. Párovanie zmlúv s obchodmi
-- ============================================================================

ALTER TYPE contract_flag_code ADD VALUE IF NOT EXISTS 'cena_ina_ako_v_ponuke';

ALTER TABLE contract
  DROP CONSTRAINT contract_deal_id_key,
  ADD COLUMN offer_variant_id uuid REFERENCES offer_variant (id),
  ADD COLUMN deal_match text CHECK (deal_match IN ('caka', 'auto', 'rucne', 'bez_obchodu')),
  ADD COLUMN deal_matched_at timestamptz,
  ADD COLUMN deal_matched_by uuid REFERENCES app_user (id),
  ADD COLUMN deal_match_note text,
  ADD COLUMN deal_match_notified_at timestamptz,
  ADD CONSTRAINT contract_deal_link_check CHECK (deal_match IS NULL OR (deal_id IS NOT NULL) = (deal_match IN ('auto', 'rucne')));
CREATE INDEX contract_deal_idx ON contract (deal_id);
CREATE INDEX contract_deal_match_idx ON contract (deal_match) WHERE deal_match = 'caka';
COMMENT ON COLUMN contract.deal_match IS 'párovanie s obchodom (0045): caka = nespárovaná, auto / rucne = spárovaná, bez_obchodu = rozhodnutie; NULL = mimo párovania (zmluva pred zapnutím deal_matching)';
COMMENT ON COLUMN contract.offer_variant_id IS 'akceptovaný variant ponuky spárovaného obchodu (NULL = spárované bez akceptovanej ponuky) – 0045';

ALTER TABLE price_exception ADD COLUMN approval_request_id uuid REFERENCES approval_request (id);
COMMENT ON COLUMN price_exception.approval_request_id IS 'výnimka prevzatá zo schválenej ponuky (0045) – pre spárované zmluvy sa výnimky modulu 4 nepoužijú';

INSERT INTO app_setting (key, value, description) VALUES
  ('deal_matching', 'false', 'Párovanie nových zmlúv z importu s obchodmi (0045). Zapnúť po nasadení F5 – na Ostrom až po prvom importe kmeňa zmlúv; zmluvy importované predtým sa nepárujú.')
ON CONFLICT (key) DO NOTHING;

-- nová zmluva z importu (po zapnutí párovania) čaká na párovanie
CREATE FUNCTION contract_deal_match_mark() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.deal_id IS NULL AND NEW.deal_match IS NULL AND crm_setting_on('deal_matching')
     AND coalesce(current_setting('app.contract_import_id', true), '') <> '' THEN
    NEW.deal_match := 'caka';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_deal_match_mark BEFORE INSERT ON contract FOR EACH ROW EXECUTE FUNCTION contract_deal_match_mark();

-- druh obchodu podľa typu zmluvy
CREATE FUNCTION contract_deal_kind(p contract_type) RETURNS deal_kind
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p WHEN 'dodavka_domacnost' THEN 'b2c_dodavka' WHEN 'vykup' THEN 'b2b_vykup' WHEN 'viwa' THEN 'green_viwa'
                ELSE 'b2b_dodavka' END::deal_kind
$$;

-- nové udalosti a upozornenia
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana',
  'potvrdenie_neodoslane', 'zmluva_sparovana', 'zmluva_odparovana'));
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena',
  'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba',
  'nesparovana_zmluva', 'cena_ina_ako_v_ponuke'));

-- Kandidáti na spárovanie zmluvy (bez ohľadu na práva volajúceho – volá import, zoznam Nespárované cez funkciu nižšie):
-- [{deal_id, name, stage, accepted, eic_total, eic_match, ok}] – ok = všetky EIC zmluvy sedia podľa pravidla štádia
CREATE FUNCTION contract_deal_candidates(p_contract uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  WITH c AS (SELECT * FROM contract WHERE id = p_contract),
  eic AS (SELECT DISTINCT co.oom_id FROM contract_oom co, c WHERE co.contract_id = c.id),
  cand AS (
    SELECT d.id, d.name, s.code AS stage, d.accepted_variant_id,
           -- OOM, s ktorými sa porovnáva: akceptovaný variant (Akceptácia, Vyhraté), inak OOM obchodu (Vyjednávanie)
           CASE WHEN s.code = 'vyjednavanie' THEN ARRAY(SELECT x.oom_id FROM deal_oom x WHERE x.deal_id = d.id)
                ELSE ARRAY(SELECT DISTINCT i.oom_id FROM offer_item i WHERE i.variant_id = d.accepted_variant_id AND i.oom_id IS NOT NULL) END AS ooms
      FROM deal d
      JOIN pipeline p ON p.id = d.pipeline_id
      JOIN pipeline_stage s ON s.id = d.stage_id, c
     WHERE d.org_id = c.org_id AND d.company_id IS NOT DISTINCT FROM c.company_id AND d.person_id IS NOT DISTINCT FROM c.person_id
       AND p.kind = contract_deal_kind(c.type)
       AND (s.code IN ('akceptacia', 'vyjednavanie')
            OR (s.code = 'vyhrane' AND d.accepted_variant_id IS NOT NULL
                AND EXISTS (SELECT 1 FROM contract k WHERE k.deal_id = d.id AND k.deal_match IN ('auto', 'rucne'))))
       AND (s.code <> 'akceptacia' OR d.accepted_variant_id IS NOT NULL)
  )
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'deal_id', x.id, 'name', x.name, 'stage', x.stage, 'accepted', x.accepted_variant_id IS NOT NULL,
           'eic_total', (SELECT count(*) FROM eic), 'eic_match', (SELECT count(*) FROM eic WHERE eic.oom_id = ANY (x.ooms)),
           'ok', (SELECT count(*) FROM eic) > 0 AND NOT EXISTS (SELECT 1 FROM eic WHERE NOT eic.oom_id = ANY (x.ooms))
                 -- Vyhraté: OOM zmluvy ešte nie sú na inej zmluve obchodu
                 AND (x.stage <> 'vyhrane' OR NOT EXISTS (
                       SELECT 1 FROM contract k JOIN contract_oom ko ON ko.contract_id = k.id
                        WHERE k.deal_id = x.id AND k.id <> p_contract AND ko.oom_id IN (SELECT oom_id FROM eic))))
           ORDER BY x.name), '[]')
    FROM cand x
$$;

-- Kontrola cien zmluvy voči akceptovanému variantu: príznak „Cena iná ako v ponuke“ po rokoch (rozdiel nad 0,0001)
CREATE FUNCTION contract_offer_price_check(p_contract uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c     contract;
  r     record;
  v_n   integer := 0;
  v_det text;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract;
  IF c.offer_variant_id IS NULL THEN
    RETURN 0;
  END IF;
  FOR r IN
    SELECT i.year,
           string_agg(DISTINCT format('%s: ponuka %s, zmluva %s', m.eic,
             contract_offer_price_text(i.price_model, i.price_vt_eur_mwh, i.price_nt_eur_mwh, i.additive_eur_mwh, i.additive_pct),
             contract_offer_price_text(p.price_model, p.price_vt_eur_mwh, p.price_nt_eur_mwh, p.additive_eur_mwh, p.additive_pct)), '; ') AS det
      FROM offer_item i
      JOIN oom m ON m.id = i.oom_id
      JOIN contract_oom co ON co.contract_id = c.id AND co.oom_id = i.oom_id
      JOIN LATERAL (SELECT * FROM contract_price p
                     WHERE p.contract_id = c.id AND p.slot = 'komodita' AND (p.oom_id IS NULL OR p.oom_id = i.oom_id)
                       AND p.valid_from <= make_date(i.year, 12, 31) AND (p.valid_to IS NULL OR p.valid_to >= make_date(i.year, 1, 1))
                     ORDER BY (p.oom_id IS NOT NULL) DESC, p.valid_from DESC LIMIT 1) p ON true
     WHERE i.variant_id = c.offer_variant_id AND i.slot = 'komodita' AND i.year IS NOT NULL
       AND (p.price_model IS DISTINCT FROM i.price_model
            OR (i.price_model IN ('fix', 'cennik') AND (abs(coalesce(p.price_vt_eur_mwh, 0) - coalesce(i.price_vt_eur_mwh, 0)) > 0.0001
                                                       OR abs(coalesce(p.price_nt_eur_mwh, p.price_vt_eur_mwh, 0) - coalesce(i.price_nt_eur_mwh, i.price_vt_eur_mwh, 0)) > 0.0001))
            OR (i.price_model IN ('spot_plus_eur', 'spot_minus_eur') AND abs(coalesce(p.additive_eur_mwh, 0) - coalesce(i.additive_eur_mwh, 0)) > 0.0001)
            OR (i.price_model = 'spot_minus_pct' AND abs(coalesce(p.additive_pct, 0) - coalesce(i.additive_pct, 0)) > 0.0001))
     GROUP BY i.year
     ORDER BY i.year
  LOOP
    v_det := left(format('Rok %s – %s', r.year, r.det), 1000);
    IF NOT EXISTS (SELECT 1 FROM contract_flag f WHERE f.contract_id = c.id AND f.code::text = 'cena_ina_ako_v_ponuke'
                     AND f.year = r.year AND f.resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'cena_ina_ako_v_ponuke', r.year, v_det);
      v_n := v_n + 1;
    END IF;
  END LOOP;
  RETURN v_n;
END;
$$;

CREATE FUNCTION contract_offer_price_text(p_model price_model, p_vt numeric, p_nt numeric, p_add numeric, p_pct numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_model
           WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num(p_add, 2, 'sk') || ' €/MWh'
           WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num(p_add, 2, 'sk') || ' €/MWh'
           WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num(p_pct, 2, 'sk') || ' %'
           WHEN 'fix' THEN offer_fmt_num(p_vt, 2, 'sk') || CASE WHEN p_nt IS NOT NULL THEN ' / ' || offer_fmt_num(p_nt, 2, 'sk') ELSE '' END || ' €/MWh'
           ELSE coalesce(p_model::text, '–') END
$$;

-- upozornenie „Cena iná ako v ponuke“: obchodník obchodu + všetci so „schvaľuje ceny“
CREATE FUNCTION contract_flag_price_notify() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k contract;
  d deal;
BEGIN
  SELECT * INTO k FROM contract WHERE id = NEW.contract_id;
  SELECT * INTO d FROM deal WHERE id = k.deal_id;
  INSERT INTO notification (user_id, kind, contract_id, deal_id, ref_date, detail)
  SELECT DISTINCT u, 'cena_ina_ako_v_ponuke', k.id, d.id, NULL::date,
         format('Zmluva %s: cena iná ako v ponuke%s', k.number, CASE WHEN NEW.year IS NOT NULL THEN format(' (rok %s)', NEW.year) ELSE '' END)
    FROM unnest(ARRAY[d.owner_id] || notification_approvers(k.org_id, false)) u
   WHERE u IS NOT NULL AND EXISTS (SELECT 1 FROM app_user a WHERE a.id = u AND a.status <> 'deaktivovany');
  RETURN NULL;
END;
$$;
-- „Cena iná ako v ponuke“ uzatvára schvaľovateľ cien (rovnako ako „Pod hranicou“) – RLS úpravy príznaku
DROP POLICY contract_flag_update ON contract_flag;
CREATE POLICY contract_flag_update ON contract_flag FOR UPDATE USING (
  EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_flag.contract_id AND crm_contract_editable(k.company_id, k.person_id, k.owner_id))
  OR (code::text IN ('pod_hranicou_bez_vynimky', 'cena_ina_ako_v_ponuke') AND crm_approves_prices()
      AND EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_flag.contract_id)));

CREATE TRIGGER trg_notify_price AFTER INSERT ON contract_flag FOR EACH ROW
  WHEN (NEW.code::text = 'cena_ina_ako_v_ponuke' AND NEW.resolved_at IS NULL) EXECUTE FUNCTION contract_flag_price_notify();

-- Výnimky z ponuky → zmluva: schválené položky výnimky akceptovaného variantu (rok, model, napäťová skupina zmluvy) ako
-- Použité; výnimky modulu 4 pri tejto zmluve sa uvoľnia (pre spárovanú zmluvu sa nepoužijú); hranica sa prepočíta
CREATE FUNCTION contract_offer_exceptions(p_contract uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c   contract;
  v_g text;
  v_n integer := 0;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract;
  v_g := CASE c.type WHEN 'dodavka_firma_nn' THEN 'nn' WHEN 'dodavka_firma_vn' THEN 'vn' ELSE NULL END;
  -- výnimky modulu 4 pri tejto zmluve späť na schválené (ak ešte platia) a odpojiť od hranice
  UPDATE contract_year_basis b SET exception_id = NULL, exception_value = NULL
    FROM price_exception x
   WHERE b.contract_id = c.id AND x.id = b.exception_id AND x.approval_request_id IS NULL;
  UPDATE price_exception SET status = 'schvalena', contract_id = NULL
   WHERE contract_id = c.id AND status = 'pouzita' AND approval_request_id IS NULL;
  IF c.offer_variant_id IS NOT NULL THEN
    INSERT INTO price_exception (org_id, company_id, person_id, years, price_model, requested_value, threshold_value, volume_mwh,
                                 reason, requested_by, status, decided_by, decided_at, decision_note, valid_until, contract_id,
                                 approval_request_id)
    SELECT c.org_id, c.company_id, c.person_id, ARRAY[a.year], a.price_model, coalesce(a.approved_value, a.requested_value),
           a.threshold_value, a.volume_mwh, 'Výnimka zo schválenej ponuky ' || offer_display_number(o), r.requested_by, 'pouzita',
           r.decided_by, r.decided_at, r.decision_note, (r.decided_at AT TIME ZONE 'Europe/Bratislava')::date + 30, c.id, r.id
      FROM approval_price_item a
      JOIN approval_request r ON r.id = a.approval_id
      JOIN offer_variant v ON v.id = a.variant_id
      JOIN offer o ON o.id = v.offer_id
     WHERE a.variant_id = c.offer_variant_id AND r.kind = 'vynimka_ceny' AND r.status = 'schvalena'
       AND (v_g IS NULL OR a.voltage_group IN (v_g, 'vsetko'))
       AND NOT EXISTS (SELECT 1 FROM price_exception x WHERE x.contract_id = c.id AND x.approval_request_id = r.id AND a.year = ANY (x.years));
    GET DIAGNOSTICS v_n = ROW_COUNT;
  END IF;
  PERFORM contract_basis_refresh(c.id);
  RETURN v_n;
END;
$$;

-- Spárovanie zmluvy s obchodom (import automaticky alebo ručne): odkaz, variant, obchod Vyhraté pri prvej zmluve,
-- časová os, kontrola cien a výnimky
CREATE FUNCTION contract_deal_link(p_contract uuid, p_deal uuid, p_method text, p_by uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c       contract;
  d       deal;
  v_stage text;
  v_won   uuid;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract FOR UPDATE;
  SELECT * INTO d FROM deal WHERE id = p_deal FOR UPDATE;
  v_stage := (SELECT code FROM pipeline_stage WHERE id = d.stage_id);
  UPDATE contract SET deal_id = d.id, offer_variant_id = CASE WHEN v_stage = 'vyjednavanie' THEN NULL ELSE d.accepted_variant_id END,
                      deal_match = p_method, deal_matched_at = now(), deal_matched_by = p_by
   WHERE id = c.id;
  SELECT * INTO c FROM contract WHERE id = c.id;
  IF d.closed_at IS NULL THEN
    SELECT s2.id INTO v_won FROM pipeline_stage s2 WHERE s2.pipeline_id = d.pipeline_id AND s2.code = 'vyhrane';
    UPDATE deal SET stage_id = v_won WHERE id = d.id;
  END IF;
  INSERT INTO deal_event (deal_id, org_id, kind, user_id, detail)
  VALUES (d.id, d.org_id, 'zmluva_sparovana', p_by,
          jsonb_build_object('contract_id', c.id, 'number', c.number, 'method', p_method,
                             'bez_ponuky', c.offer_variant_id IS NULL,
                             'text', CASE WHEN c.offer_variant_id IS NULL THEN 'spárované bez akceptovanej ponuky' END));
  PERFORM contract_offer_price_check(c.id);
  PERFORM contract_offer_exceptions(c.id);
END;
$$;

-- Párovanie jednej zmluvy (import): jeden kandidát → spárovať; domácnosť bez otvoreného obchodu B2C → Bez obchodu;
-- inak ostane Nespárovaná a raz pošle upozornenie vlastníkovi zákazníka (inak adminom)
CREATE FUNCTION contract_deal_match(p_contract uuid) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c     contract;
  cand  jsonb;
  ok    jsonb;
  v_own uuid;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract FOR UPDATE;
  IF c.deal_match IS DISTINCT FROM 'caka' OR c.phase IN ('odmietnuta', 'neuspesna') THEN
    RETURN c.deal_match;
  END IF;
  cand := contract_deal_candidates(c.id);
  SELECT jsonb_agg(x) INTO ok FROM jsonb_array_elements(cand) x WHERE (x->>'ok')::boolean;
  IF jsonb_array_length(coalesce(ok, '[]')) = 1 THEN
    PERFORM contract_deal_link(c.id, (ok->0->>'deal_id')::uuid, 'auto', NULL);
    RETURN 'auto';
  END IF;
  IF c.type = 'dodavka_domacnost' AND NOT EXISTS (
       SELECT 1 FROM deal d JOIN pipeline p ON p.id = d.pipeline_id
        WHERE d.person_id = c.person_id AND p.kind = 'b2c_dodavka' AND d.closed_at IS NULL) THEN
    UPDATE contract SET deal_match = 'bez_obchodu', deal_matched_at = now(), deal_matched_by = NULL,
                        deal_match_note = 'domácnosť bez otvoreného obchodu B2C'
     WHERE id = c.id;
    RETURN 'bez_obchodu';
  END IF;
  IF c.deal_match_notified_at IS NULL THEN
    v_own := crm_customer_owner(c.company_id, c.person_id);
    INSERT INTO notification (user_id, kind, contract_id, detail)
    SELECT DISTINCT u, 'nesparovana_zmluva', c.id,
           format('Zmluva %s sa nespárovala s obchodom (%s)', c.number,
                  CASE WHEN jsonb_array_length(coalesce(ok, '[]')) > 1 THEN 'viac obchodov' ELSE 'žiadny obchod' END)
      FROM unnest(CASE WHEN v_own IS NOT NULL AND EXISTS (SELECT 1 FROM app_user a WHERE a.id = v_own AND a.status = 'aktivny')
                       THEN ARRAY[v_own]
                       ELSE ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny') END) u;
    UPDATE contract SET deal_match_notified_at = now() WHERE id = c.id;
  END IF;
  RETURN 'caka';
END;
$$;

-- Všetky čakajúce zmluvy (po uložení importu); vráti počty
CREATE FUNCTION contract_deal_match_pending() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r   record;
  res jsonb := jsonb_build_object('auto', 0, 'bez_obchodu', 0, 'caka', 0);
  v   text;
BEGIN
  FOR r IN SELECT id FROM contract WHERE deal_match = 'caka' AND phase NOT IN ('odmietnuta', 'neuspesna') ORDER BY created_at LOOP
    v := contract_deal_match(r.id);
    res := jsonb_set(res, ARRAY[v], to_jsonb((res->>v)::int + 1));
  END LOOP;
  RETURN res;
END;
$$;

-- kto rozhoduje o párovaní zmluvy: vlastník zákazníka alebo admin
CREATE FUNCTION crm_contract_match_editor(c contract) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_active_user_id() IS NOT NULL AND c.org_id = ANY (crm_user_orgs())
     AND (crm_is_admin() OR crm_customer_owner(c.company_id, c.person_id) = crm_active_user_id())
$$;

-- Ručne: vybrať obchod (toho istého zákazníka a druhu; otvorený alebo Vyhraté)
CREATE FUNCTION contract_deal_pick(p_contract uuid, p_deal uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c contract;
  d deal;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract FOR UPDATE;
  IF NOT FOUND OR NOT crm_contract_match_editor(c) THEN
    RAISE EXCEPTION 'Obchod k zmluve vyberá vlastník zákazníka alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF c.deal_match IS DISTINCT FROM 'caka' AND c.deal_match IS DISTINCT FROM 'bez_obchodu' THEN
    RAISE EXCEPTION 'Zmluva už je spárovaná – najprv zrušte spárovanie.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF NOT FOUND OR d.org_id <> c.org_id OR d.company_id IS DISTINCT FROM c.company_id OR d.person_id IS DISTINCT FROM c.person_id
     OR (SELECT kind FROM pipeline WHERE id = d.pipeline_id) <> contract_deal_kind(c.type) THEN
    RAISE EXCEPTION 'Obchod musí patriť tomu istému zákazníkovi a druhu zmluvy.' USING ERRCODE = 'check_violation';
  END IF;
  IF (SELECT code FROM pipeline_stage WHERE id = d.stage_id) = 'prehrane' THEN
    RAISE EXCEPTION 'Prehratý obchod sa so zmluvou nepáruje.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM contract_deal_link(c.id, d.id, 'rucne', crm_active_user_id());
END;
$$;

-- Ručne: Bez obchodu (rozhodnutie, nie problém)
CREATE FUNCTION contract_deal_none(p_contract uuid, p_note text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c contract;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract FOR UPDATE;
  IF NOT FOUND OR NOT crm_contract_match_editor(c) THEN
    RAISE EXCEPTION '„Bez obchodu“ označuje vlastník zákazníka alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF c.deal_match IS DISTINCT FROM 'caka' THEN
    RAISE EXCEPTION '„Bez obchodu“ sa dá označiť iba pri nespárovanej zmluve.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE contract SET deal_match = 'bez_obchodu', deal_matched_at = now(), deal_matched_by = crm_active_user_id(),
                      deal_match_note = nullif(btrim(p_note), '')
   WHERE id = c.id;
END;
$$;

-- Zrušenie spárovania (admin, s dôvodom): zmluva späť medzi nespárované; výnimky z ponuky a príznaky ceny pri zmluve sa
-- zrušia. Obchod s ďalšou spárovanou zmluvou ostáva Vyhraté; pri poslednej zmluve sa vráti do štádia, z ktorého bol
-- spárovaný: Akceptácia (zmluva s akceptovaným variantom) alebo Vyjednávanie (spárované bez akceptovanej ponuky)
CREATE FUNCTION contract_deal_unlink(p_contract uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c       contract;
  d       deal;
  v_stage uuid;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract FOR UPDATE;
  IF NOT FOUND OR crm_active_user_id() IS NULL OR NOT crm_is_admin() OR NOT c.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Spárovanie zmluvy ruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF nullif(btrim(coalesce(p_reason, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Uveďte dôvod zrušenia spárovania.' USING ERRCODE = 'check_violation';
  END IF;
  IF c.deal_match NOT IN ('auto', 'rucne', 'bez_obchodu') THEN
    RAISE EXCEPTION 'Zmluva nie je spárovaná.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO d FROM deal WHERE id = c.deal_id FOR UPDATE;
  UPDATE contract SET deal_id = NULL, offer_variant_id = NULL, deal_match = 'caka', deal_matched_at = now(),
                      deal_matched_by = crm_active_user_id(), deal_match_note = btrim(p_reason)
   WHERE id = c.id;
  UPDATE contract_year_basis SET exception_id = NULL, exception_value = NULL
   WHERE contract_id = c.id AND exception_id IN (SELECT id FROM price_exception WHERE contract_id = c.id AND approval_request_id IS NOT NULL);
  DELETE FROM price_exception WHERE contract_id = c.id AND approval_request_id IS NOT NULL;
  UPDATE contract_flag SET resolved_at = now(), resolved_note = 'zrušené spárovanie zmluvy s obchodom'
   WHERE contract_id = c.id AND code::text = 'cena_ina_ako_v_ponuke' AND resolved_at IS NULL;
  PERFORM contract_basis_refresh(c.id);
  IF d.id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM contract k WHERE k.deal_id = d.id AND k.id <> c.id AND k.deal_match IN ('auto', 'rucne'))
       AND d.closed_at IS NOT NULL THEN
      SELECT s.id INTO v_stage FROM pipeline_stage s
       WHERE s.pipeline_id = d.pipeline_id AND s.code::text = CASE WHEN c.offer_variant_id IS NOT NULL THEN 'akceptacia' ELSE 'vyjednavanie' END;
      PERFORM set_config('app.deal_reopen', d.id::text, true);
      UPDATE deal SET stage_id = v_stage WHERE id = d.id;
      PERFORM set_config('app.deal_reopen', '', true);
    END IF;
    INSERT INTO deal_event (deal_id, org_id, kind, user_id, detail)
    VALUES (d.id, d.org_id, 'zmluva_odparovana', crm_active_user_id(),
            jsonb_build_object('contract_id', c.id, 'number', c.number, 'reason', btrim(p_reason),
                               'stage', (SELECT code FROM pipeline_stage WHERE id = (SELECT stage_id FROM deal WHERE id = d.id))));
  END IF;
END;
$$;

-- Zoznam Nespárované (obrazovka 40): zmluvy, ktoré volajúci vidí alebo o ktorých rozhoduje (vlastník zákazníka, admin),
-- s kandidátmi a dôvodom
CREATE FUNCTION contract_unmatched() RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
           'contract_id', c.id, 'number', c.number, 'type', c.type, 'phase', c.phase, 'created_at', c.created_at,
           'company_id', c.company_id, 'person_id', c.person_id,
           'customer', coalesce((SELECT name FROM company WHERE id = c.company_id),
                                (SELECT concat_ws(' ', first_name, last_name) FROM contact WHERE id = c.person_id)),
           'ooms', (SELECT coalesce(jsonb_agg(jsonb_build_object('eic', m.eic, 'voltage', m.voltage_level) ORDER BY m.eic), '[]')
                      FROM contract_oom co JOIN oom m ON m.id = co.oom_id WHERE co.contract_id = c.id),
           'candidates', contract_deal_candidates(c.id),
           'can_decide', crm_contract_match_editor(c)) ORDER BY c.created_at DESC), '[]')
    FROM contract c
   WHERE c.deal_match = 'caka' AND c.phase NOT IN ('odmietnuta', 'neuspesna')
     AND crm_active_user_id() IS NOT NULL AND c.org_id = ANY (crm_user_orgs())
     AND (crm_contract_visible(c.company_id, c.person_id, c.owner_id) OR crm_contract_match_editor(c))
$$;

REVOKE EXECUTE ON FUNCTION contract_deal_match_mark(), contract_flag_price_notify(), contract_deal_link(uuid, uuid, text, uuid),
  contract_deal_match(uuid), contract_deal_match_pending(), contract_offer_exceptions(uuid), contract_offer_price_check(uuid)
  FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION contract_deal_match_mark(), contract_flag_price_notify(), contract_deal_link(uuid, uuid, text, uuid),
      contract_deal_match(uuid), contract_deal_match_pending(), contract_offer_exceptions(uuid), contract_offer_price_check(uuid)
      FROM crm_app;
  END IF;
END;
$$;

-- ============================================================================
-- 3. Úpravy funkcií modulu 4 (výnimky, príznak, import)
-- ============================================================================

CREATE OR REPLACE FUNCTION contract_basis_refresh(p_contract_id uuid) RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c      contract;
  v_from date;
  v_to   date;
  y      integer;
  v      contract_year_basis;
  s      contract_year_basis;
  e      price_exception;
  r      record;
  v_mod  text;
  v_det  text;
  v_warn text[] := '{}';
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF NOT FOUND THEN
    RETURN v_warn;
  END IF;
  SELECT min(valid_from), max(coalesce(valid_to, make_date(extract(year FROM crm_today())::int + 1, 12, 31)))
    INTO v_from, v_to FROM contract_oom WHERE contract_id = c.id AND valid_from IS NOT NULL;
  DELETE FROM contract_year_basis
   WHERE contract_id = c.id
     AND (c.signed_on IS NULL OR v_from IS NULL
          OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  UPDATE contract_flag SET resolved_at = now()
   WHERE contract_id = c.id AND code IN ('pod_hranicou_bez_vynimky', 'chyba_cena') AND year IS NOT NULL AND resolved_at IS NULL
     AND (v_from IS NULL OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  IF v_from IS NULL THEN
    RETURN v_warn;
  END IF;

  FOR y IN extract(year FROM v_from)::int .. extract(year FROM v_to)::int LOOP
    IF c.signed_on IS NOT NULL THEN
      v := contract_basis_values(c, y, c.signed_on);
      SELECT * INTO s FROM contract_year_basis WHERE contract_id = c.id AND year = y;
      v.exception_id := s.exception_id;
      v.exception_value := s.exception_value;
      IF v.exception_id IS NULL AND c.phase = 'podpisana' THEN
        v_mod := (SELECT p.price_model::text FROM contract_price p
                   WHERE p.contract_id = c.id AND p.slot = 'komodita' AND p.source = 'import' AND p.price_model <> 'cennik'
                     AND p.valid_from <= make_date(y, 12, 31) AND (p.valid_to IS NULL OR p.valid_to >= make_date(y, 1, 1))
                   ORDER BY p.valid_from DESC LIMIT 1);
        e := NULL;
        SELECT * INTO e FROM price_exception x
         WHERE x.org_id = c.org_id AND x.company_id IS NOT DISTINCT FROM c.company_id
           AND x.person_id IS NOT DISTINCT FROM c.person_id AND y = ANY (x.years) AND x.price_model::text = v_mod
           AND ((x.status = 'schvalena' AND c.signed_on <= x.valid_until) OR (x.status = 'pouzita' AND x.contract_id = c.id))
           -- 0045: zmluva spárovaná s obchodom používa iba výnimky zo schválenej ponuky (párovanie modulu 4 nie)
           AND (c.deal_id IS NULL OR x.approval_request_id IS NOT NULL)
         ORDER BY (x.approval_request_id IS NOT NULL) DESC, x.decided_at DESC
         LIMIT 1;
        IF e.id IS NOT NULL THEN
          v.exception_id := e.id;
          v.exception_value := e.requested_value;
          UPDATE price_exception SET status = 'pouzita', contract_id = c.id WHERE id = e.id AND status = 'schvalena';
        END IF;
      END IF;
      INSERT INTO contract_year_basis (contract_id, year, ref_date, seller_type, trader_price, portfolio_eur_mwh, portfolio_on,
                                       min_additive, energopomoc_price, viwa_additive, exception_id, exception_value, source)
      VALUES (c.id, y, v.ref_date, v.seller_type, v.trader_price, v.portfolio_eur_mwh, v.portfolio_on, v.min_additive,
              v.energopomoc_price, v.viwa_additive, v.exception_id, v.exception_value, v.source)
      ON CONFLICT (contract_id, year) DO UPDATE
         SET ref_date = EXCLUDED.ref_date, seller_type = EXCLUDED.seller_type, trader_price = EXCLUDED.trader_price,
             portfolio_eur_mwh = EXCLUDED.portfolio_eur_mwh, portfolio_on = EXCLUDED.portfolio_on,
             min_additive = EXCLUDED.min_additive, energopomoc_price = EXCLUDED.energopomoc_price,
             viwa_additive = EXCLUDED.viwa_additive, exception_id = EXCLUDED.exception_id,
             exception_value = EXCLUDED.exception_value, source = EXCLUDED.source, computed_at = now()
       WHERE (contract_year_basis.ref_date, contract_year_basis.seller_type, contract_year_basis.trader_price,
              contract_year_basis.portfolio_eur_mwh, contract_year_basis.portfolio_on, contract_year_basis.min_additive,
              contract_year_basis.energopomoc_price, contract_year_basis.viwa_additive, contract_year_basis.exception_id,
              contract_year_basis.exception_value, contract_year_basis.source)
             IS DISTINCT FROM
             (EXCLUDED.ref_date, EXCLUDED.seller_type, EXCLUDED.trader_price, EXCLUDED.portfolio_eur_mwh, EXCLUDED.portfolio_on,
              EXCLUDED.min_additive, EXCLUDED.energopomoc_price, EXCLUDED.viwa_additive, EXCLUDED.exception_id,
              EXCLUDED.exception_value, EXCLUDED.source);
    END IF;

    SELECT * INTO r FROM contract_year_calc(c.id, y);
    -- Pod hranicou bez výnimky (individuálna cena)
    IF c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.model ~ '(fix|spot_plus_eur|vykup)' AND r.added_value_eur < 0
       AND r.exception_id IS NULL THEN
      v_det := format('Pridaná hodnota %s: %s € – cena pod hranicou bez schválenej výnimky.', y,
                      replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      v_warn := v_warn || format('Pod hranicou bez výnimky %s: pridaná hodnota %s €', y,
                                 replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      IF NOT EXISTS (SELECT 1 FROM contract_flag f WHERE f.contract_id = c.id AND f.code = 'pod_hranicou_bez_vynimky' AND f.year = y
                        AND (f.resolved_at IS NULL OR f.resolved_by IS NOT NULL)) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'pod_hranicou_bez_vynimky', y, v_det);
      ELSE
        UPDATE contract_flag SET detail = v_det
         WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL
           AND detail IS DISTINCT FROM v_det;
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL;
    END IF;
    -- Chýba cena pre obchodníka (podpis od 1. 1. 2026)
    IF c.signed_on >= '2026-01-01' AND c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.missing = 'cena pre obchodníka' THEN
      v_det := format('chýba cena pre obchodníka %s (ceny BL/PL ku dňu podpisu %s)', y, to_char(c.signed_on, 'FMDD. FMMM. YYYY'));
      v_warn := v_warn || ('Chýba cena: ' || v_det);
      IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'chyba_cena', y, v_det);
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL;
    END IF;
  END LOOP;
  RETURN v_warn;
END;
$$;

CREATE OR REPLACE FUNCTION price_exception_threshold() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_seller seller_type;
  v_year   smallint := (SELECT min(x) FROM unnest(NEW.years) x);
  v        numeric;
BEGIN
  -- bez používateľa, alebo výnimka prevzatá zo schválenej ponuky (0045) – hranica je zo schválenia
  IF crm_active_user_id() IS NULL OR NEW.status <> 'caka' OR NEW.approval_request_id IS NOT NULL THEN
    RETURN NEW;
  END IF;
  v_seller := coalesce((SELECT seller_type FROM app_user WHERE id = crm_active_user_id()), 'obchodnik');
  v := CASE NEW.price_model
         WHEN 'fix' THEN trader_price(NEW.org_id, v_year, crm_today())
         WHEN 'spot_plus_eur' THEN contract_param(NEW.org_id,
                                     CASE v_seller WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, crm_today())
         WHEN 'spot_minus_eur' THEN contract_param(NEW.org_id, 'min_aditiv_vykup', crm_today())
       END;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Hranica pre rok % dnes nie je známa (chýbajú ceny BL/PL alebo parameter v Cenových parametroch).', v_year
      USING ERRCODE = 'check_violation';
  END IF;
  NEW.threshold_value := v;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION contract_flag_resolve_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract_flag'::regclass) THEN
    RETURN NEW;
  END IF;
  IF OLD.resolved_at IS NOT NULL OR NEW.resolved_at IS NULL
     OR (NEW.contract_id, NEW.code, NEW.year, NEW.detail, NEW.raised_at)
        IS DISTINCT FROM (OLD.contract_id, OLD.code, OLD.year, OLD.detail, OLD.raised_at)
     OR NEW.resolved_by IS DISTINCT FROM crm_active_user_id() THEN
    RAISE EXCEPTION 'Príznak sa dá iba uzavrieť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.code = 'chyba_cena' THEN
    RAISE EXCEPTION '„Chýba cena“ zmizne sama, keď cena pribudne.' USING ERRCODE = 'check_violation';
  END IF;
  -- 0045: „Cena iná ako v ponuke“ uzatvára schvaľovateľ cien s poznámkou
  IF OLD.code::text = 'cena_ina_ako_v_ponuke' THEN
    IF NOT crm_approves_prices() THEN
      RAISE EXCEPTION '„Cena iná ako v ponuke“ uzatvára iba schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF nullif(btrim(coalesce(NEW.resolved_note, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Pri uzavretí „Cena iná ako v ponuke“ zadajte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF OLD.code = 'pod_hranicou_bez_vynimky' THEN
    IF NOT crm_approves_prices() THEN
      RAISE EXCEPTION '„Pod hranicou bez výnimky“ uzatvára iba schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF nullif(btrim(coalesce(NEW.resolved_note, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Pri uzavretí „Pod hranicou bez výnimky“ zadajte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION price_exception_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_years text := array_to_string(NEW.years, ', ');
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'caka' THEN   -- 0045: prevzatá výnimka z ponuky nie je nová žiadosť
    PERFORM notification_add(array_remove(notification_approvers(NEW.org_id, false), NEW.requested_by), 'vynimka_nova',
                             NULL, NEW.id, NULL, NULL, format('Nová žiadosť o výnimku z ceny (rok %s)', v_years));
  ELSIF OLD.status = 'caka' AND NEW.status IN ('schvalena', 'zamietnuta') THEN
    PERFORM notification_add(ARRAY[NEW.requested_by], 'vynimka_rozhodnutie', NULL, NEW.id, NULL, NULL,
                             format('Výnimka z ceny (rok %s) je %s', v_years,
                                    CASE NEW.status WHEN 'schvalena' THEN 'schválená' ELSE 'zamietnutá' END));
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}'::jsonb, p_expected jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_res    jsonb;
  v_counts jsonb;
  v_id     uuid;
BEGIN
  IF NOT crm_can_import('zmluvy') THEN
    RAISE EXCEPTION 'Import zmlúv nemáte povolený (Nastavenia → Tímy a práva).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) > 0 AND NOT crm_can_import('odberne_miesta') THEN
    RAISE EXCEPTION 'Import odberných miest z XM Trade nemáte povolený (Nastavenia → Tímy a práva).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT p_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'K tejto spoločnosti nemáte prístup.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_typeof(coalesce(p_xm, '[]')) <> 'array' OR jsonb_typeof(coalesce(p_op, '[]')) <> 'array'
     OR jsonb_array_length(coalesce(p_xm, '[]')) > 5000 OR jsonb_array_length(coalesce(p_op, '[]')) > 5000 THEN
    RAISE EXCEPTION 'Súbor má viac ako 5 000 riadkov – rozdeľte ho.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) + jsonb_array_length(coalesce(p_op, '[]')) = 0 THEN
    RAISE EXCEPTION 'Nahrajte export z Office portálu, z XM Trade alebo oba.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT p_save THEN
    BEGIN
      INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash)
      VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
              p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
              p_meta ->> 'xm_file_hash')
      RETURNING id INTO v_id;
      PERFORM set_config('app.contract_import_id', v_id::text, true);
      v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
      RAISE EXCEPTION 'náhľad' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
    END;
    RETURN v_res || jsonb_build_object('counts', contract_import_counts(v_res));
  END IF;

  IF p_expected IS NULL THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL);
  END IF;
  IF coalesce((p_expected #>> '{zmluvy,nova}')::int, 0) + coalesce((p_expected #>> '{zmluvy,zmena}')::int, 0)
     + coalesce((p_expected #>> '{oom,nove}')::int, 0) + coalesce((p_expected #>> '{oom,zmena}')::int, 0) = 0 THEN
    RETURN jsonb_build_object('nothing', true, 'import_id', NULL, 'counts', p_expected);
  END IF;
  BEGIN
    INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash, counts)
    VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
            p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
            p_meta ->> 'xm_file_hash', p_expected)
    RETURNING id INTO v_id;
    PERFORM set_config('app.contract_import_id', v_id::text, true);
    v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
    v_counts := contract_import_counts(v_res);
    IF v_counts IS DISTINCT FROM p_expected THEN
      RAISE EXCEPTION 'nesedí s náhľadom' USING ERRCODE = 'P0098';
    END IF;
    INSERT INTO contract_import_change (import_id, contract_id, action, summary)
    SELECT v_id, (x ->> 'contract_id')::uuid, min(x ->> 'action'),
           left(string_agg((SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(x -> 'changes') e), '; '), 4000)
      FROM jsonb_array_elements(v_res -> 'contracts') x
     WHERE x ->> 'action' IN ('nova', 'zmena') AND x ->> 'contract_id' IS NOT NULL
     GROUP BY 2;
    PERFORM set_config('app.contract_import_id', '', true);
    -- 0045: párovanie nových zmlúv s obchodmi (iba ak je zapnuté nastavenie deal_matching)
    v_res := v_res || jsonb_build_object('parovanie', contract_deal_match_pending());
  EXCEPTION WHEN SQLSTATE 'P0098' THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL, 'counts', v_counts);
  END;
  RETURN v_res || jsonb_build_object('import_id', v_id, 'counts', v_counts);
END;
$$;

-- migrate:down

DROP FUNCTION contract_unmatched();
DROP FUNCTION contract_deal_unlink(uuid, text);
DROP FUNCTION contract_deal_none(uuid, text);
DROP FUNCTION contract_deal_pick(uuid, uuid);
DROP FUNCTION crm_contract_match_editor(contract);
DROP FUNCTION contract_deal_match_pending();
DROP FUNCTION contract_deal_match(uuid);
DROP FUNCTION contract_deal_link(uuid, uuid, text, uuid);
DROP FUNCTION contract_offer_exceptions(uuid);
DROP TRIGGER trg_notify_price ON contract_flag;
DROP FUNCTION contract_flag_price_notify();
DROP FUNCTION contract_offer_price_check(uuid);
DROP FUNCTION contract_offer_price_text(price_model, numeric, numeric, numeric, numeric);
DROP FUNCTION contract_deal_candidates(uuid);
DROP TRIGGER trg_deal_match_mark ON contract;
DROP FUNCTION contract_deal_match_mark();
DROP FUNCTION contract_deal_kind(contract_type);
CREATE OR REPLACE FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}'::jsonb, p_expected jsonb DEFAULT NULL::jsonb) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_res    jsonb;
  v_counts jsonb;
  v_id     uuid;
BEGIN
  IF NOT crm_can_import('zmluvy') THEN
    RAISE EXCEPTION 'Import zmlúv nemáte povolený (Nastavenia → Tímy a práva).' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) > 0 AND NOT crm_can_import('odberne_miesta') THEN
    RAISE EXCEPTION 'Import odberných miest z XM Trade nemáte povolený (Nastavenia → Tímy a práva).'
      USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NOT p_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'K tejto spoločnosti nemáte prístup.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF jsonb_typeof(coalesce(p_xm, '[]')) <> 'array' OR jsonb_typeof(coalesce(p_op, '[]')) <> 'array'
     OR jsonb_array_length(coalesce(p_xm, '[]')) > 5000 OR jsonb_array_length(coalesce(p_op, '[]')) > 5000 THEN
    RAISE EXCEPTION 'Súbor má viac ako 5 000 riadkov – rozdeľte ho.' USING ERRCODE = 'check_violation';
  END IF;
  IF jsonb_array_length(coalesce(p_xm, '[]')) + jsonb_array_length(coalesce(p_op, '[]')) = 0 THEN
    RAISE EXCEPTION 'Nahrajte export z Office portálu, z XM Trade alebo oba.' USING ERRCODE = 'check_violation';
  END IF;

  IF NOT p_save THEN
    BEGIN
      INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash)
      VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
              p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
              p_meta ->> 'xm_file_hash')
      RETURNING id INTO v_id;
      PERFORM set_config('app.contract_import_id', v_id::text, true);
      v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
      RAISE EXCEPTION 'náhľad' USING ERRCODE = 'P0099';
    EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
    END;
    RETURN v_res || jsonb_build_object('counts', contract_import_counts(v_res));
  END IF;

  IF p_expected IS NULL THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL);
  END IF;
  IF coalesce((p_expected #>> '{zmluvy,nova}')::int, 0) + coalesce((p_expected #>> '{zmluvy,zmena}')::int, 0)
     + coalesce((p_expected #>> '{oom,nove}')::int, 0) + coalesce((p_expected #>> '{oom,zmena}')::int, 0) = 0 THEN
    RETURN jsonb_build_object('nothing', true, 'import_id', NULL, 'counts', p_expected);
  END IF;
  BEGIN
    INSERT INTO contract_import (org_id, user_id, op_file_name, op_file_hash, xm_file_name, xm_file_hash, counts)
    VALUES (p_org, crm_active_user_id(), coalesce(p_meta ->> 'op_file_name', CASE WHEN jsonb_array_length(coalesce(p_op, '[]')) > 0 THEN 'office-portal.xlsx' END),
            p_meta ->> 'op_file_hash', coalesce(p_meta ->> 'xm_file_name', CASE WHEN jsonb_array_length(coalesce(p_xm, '[]')) > 0 THEN 'xm-trade.xlsx' END),
            p_meta ->> 'xm_file_hash', p_expected)
    RETURNING id INTO v_id;
    PERFORM set_config('app.contract_import_id', v_id::text, true);
    v_res := contract_import_small_business(contract_import_rows(p_org, p_xm, p_op));
    v_counts := contract_import_counts(v_res);
    IF v_counts IS DISTINCT FROM p_expected THEN
      RAISE EXCEPTION 'nesedí s náhľadom' USING ERRCODE = 'P0098';
    END IF;
    INSERT INTO contract_import_change (import_id, contract_id, action, summary)
    SELECT v_id, (x ->> 'contract_id')::uuid, min(x ->> 'action'),
           left(string_agg((SELECT string_agg(e, '; ') FROM jsonb_array_elements_text(x -> 'changes') e), '; '), 4000)
      FROM jsonb_array_elements(v_res -> 'contracts') x
     WHERE x ->> 'action' IN ('nova', 'zmena') AND x ->> 'contract_id' IS NOT NULL
     GROUP BY 2;
    PERFORM set_config('app.contract_import_id', '', true);
  EXCEPTION WHEN SQLSTATE 'P0098' THEN
    RETURN jsonb_build_object('mismatch', true, 'import_id', NULL, 'counts', v_counts);
  END;
  RETURN v_res || jsonb_build_object('import_id', v_id, 'counts', v_counts);
END;
$$;

CREATE OR REPLACE FUNCTION price_exception_notify() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_years text := array_to_string(NEW.years, ', ');
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM notification_add(array_remove(notification_approvers(NEW.org_id, false), NEW.requested_by), 'vynimka_nova',
                             NULL, NEW.id, NULL, NULL, format('Nová žiadosť o výnimku z ceny (rok %s)', v_years));
  ELSIF OLD.status = 'caka' AND NEW.status IN ('schvalena', 'zamietnuta') THEN
    PERFORM notification_add(ARRAY[NEW.requested_by], 'vynimka_rozhodnutie', NULL, NEW.id, NULL, NULL,
                             format('Výnimka z ceny (rok %s) je %s', v_years,
                                    CASE NEW.status WHEN 'schvalena' THEN 'schválená' ELSE 'zamietnutá' END));
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION contract_flag_resolve_guard() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public', 'pg_temp'
    AS $$
BEGIN
  IF current_user = (SELECT pg_get_userbyid(relowner) FROM pg_class WHERE oid = 'contract_flag'::regclass) THEN
    RETURN NEW;
  END IF;
  IF OLD.resolved_at IS NOT NULL OR NEW.resolved_at IS NULL
     OR (NEW.contract_id, NEW.code, NEW.year, NEW.detail, NEW.raised_at)
        IS DISTINCT FROM (OLD.contract_id, OLD.code, OLD.year, OLD.detail, OLD.raised_at)
     OR NEW.resolved_by IS DISTINCT FROM crm_active_user_id() THEN
    RAISE EXCEPTION 'Príznak sa dá iba uzavrieť.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF OLD.code = 'chyba_cena' THEN
    RAISE EXCEPTION '„Chýba cena“ zmizne sama, keď cena pribudne.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.code = 'pod_hranicou_bez_vynimky' THEN
    IF NOT crm_approves_prices() THEN
      RAISE EXCEPTION '„Pod hranicou bez výnimky“ uzatvára iba schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
    END IF;
    IF nullif(btrim(coalesce(NEW.resolved_note, '')), '') IS NULL THEN
      RAISE EXCEPTION 'Pri uzavretí „Pod hranicou bez výnimky“ zadajte poznámku.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION price_exception_threshold() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_seller seller_type;
  v_year   smallint := (SELECT min(x) FROM unnest(NEW.years) x);
  v        numeric;
BEGIN
  IF crm_active_user_id() IS NULL THEN
    RETURN NEW;
  END IF;
  v_seller := coalesce((SELECT seller_type FROM app_user WHERE id = crm_active_user_id()), 'obchodnik');
  v := CASE NEW.price_model
         WHEN 'fix' THEN trader_price(NEW.org_id, v_year, crm_today())
         WHEN 'spot_plus_eur' THEN contract_param(NEW.org_id,
                                     CASE v_seller WHEN 'manazer' THEN 'min_aditiv_manazer' ELSE 'min_aditiv_obchodnik' END, crm_today())
         WHEN 'spot_minus_eur' THEN contract_param(NEW.org_id, 'min_aditiv_vykup', crm_today())
       END;
  IF v IS NULL THEN
    RAISE EXCEPTION 'Hranica pre rok % dnes nie je známa (chýbajú ceny BL/PL alebo parameter v Cenových parametroch).', v_year
      USING ERRCODE = 'check_violation';
  END IF;
  NEW.threshold_value := v;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION contract_basis_refresh(p_contract_id uuid) RETURNS text[]
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c      contract;
  v_from date;
  v_to   date;
  y      integer;
  v      contract_year_basis;
  s      contract_year_basis;
  e      price_exception;
  r      record;
  v_mod  text;
  v_det  text;
  v_warn text[] := '{}';
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF NOT FOUND THEN
    RETURN v_warn;
  END IF;
  SELECT min(valid_from), max(coalesce(valid_to, make_date(extract(year FROM crm_today())::int + 1, 12, 31)))
    INTO v_from, v_to FROM contract_oom WHERE contract_id = c.id AND valid_from IS NOT NULL;
  DELETE FROM contract_year_basis
   WHERE contract_id = c.id
     AND (c.signed_on IS NULL OR v_from IS NULL
          OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  UPDATE contract_flag SET resolved_at = now()
   WHERE contract_id = c.id AND code IN ('pod_hranicou_bez_vynimky', 'chyba_cena') AND year IS NOT NULL AND resolved_at IS NULL
     AND (v_from IS NULL OR year NOT BETWEEN extract(year FROM v_from) AND extract(year FROM v_to));
  IF v_from IS NULL THEN
    RETURN v_warn;
  END IF;

  FOR y IN extract(year FROM v_from)::int .. extract(year FROM v_to)::int LOOP
    IF c.signed_on IS NOT NULL THEN
      v := contract_basis_values(c, y, c.signed_on);
      SELECT * INTO s FROM contract_year_basis WHERE contract_id = c.id AND year = y;
      v.exception_id := s.exception_id;
      v.exception_value := s.exception_value;
      IF v.exception_id IS NULL AND c.phase = 'podpisana' THEN
        v_mod := (SELECT p.price_model::text FROM contract_price p
                   WHERE p.contract_id = c.id AND p.slot = 'komodita' AND p.source = 'import' AND p.price_model <> 'cennik'
                     AND p.valid_from <= make_date(y, 12, 31) AND (p.valid_to IS NULL OR p.valid_to >= make_date(y, 1, 1))
                   ORDER BY p.valid_from DESC LIMIT 1);
        e := NULL;
        SELECT * INTO e FROM price_exception x
         WHERE x.org_id = c.org_id AND x.company_id IS NOT DISTINCT FROM c.company_id
           AND x.person_id IS NOT DISTINCT FROM c.person_id AND y = ANY (x.years) AND x.price_model::text = v_mod
           AND ((x.status = 'schvalena' AND c.signed_on <= x.valid_until) OR (x.status = 'pouzita' AND x.contract_id = c.id))
         ORDER BY x.decided_at DESC
         LIMIT 1;
        IF e.id IS NOT NULL THEN
          v.exception_id := e.id;
          v.exception_value := e.requested_value;
          UPDATE price_exception SET status = 'pouzita', contract_id = c.id WHERE id = e.id AND status = 'schvalena';
        END IF;
      END IF;
      INSERT INTO contract_year_basis (contract_id, year, ref_date, seller_type, trader_price, portfolio_eur_mwh, portfolio_on,
                                       min_additive, energopomoc_price, viwa_additive, exception_id, exception_value, source)
      VALUES (c.id, y, v.ref_date, v.seller_type, v.trader_price, v.portfolio_eur_mwh, v.portfolio_on, v.min_additive,
              v.energopomoc_price, v.viwa_additive, v.exception_id, v.exception_value, v.source)
      ON CONFLICT (contract_id, year) DO UPDATE
         SET ref_date = EXCLUDED.ref_date, seller_type = EXCLUDED.seller_type, trader_price = EXCLUDED.trader_price,
             portfolio_eur_mwh = EXCLUDED.portfolio_eur_mwh, portfolio_on = EXCLUDED.portfolio_on,
             min_additive = EXCLUDED.min_additive, energopomoc_price = EXCLUDED.energopomoc_price,
             viwa_additive = EXCLUDED.viwa_additive, exception_id = EXCLUDED.exception_id,
             exception_value = EXCLUDED.exception_value, source = EXCLUDED.source, computed_at = now()
       WHERE (contract_year_basis.ref_date, contract_year_basis.seller_type, contract_year_basis.trader_price,
              contract_year_basis.portfolio_eur_mwh, contract_year_basis.portfolio_on, contract_year_basis.min_additive,
              contract_year_basis.energopomoc_price, contract_year_basis.viwa_additive, contract_year_basis.exception_id,
              contract_year_basis.exception_value, contract_year_basis.source)
             IS DISTINCT FROM
             (EXCLUDED.ref_date, EXCLUDED.seller_type, EXCLUDED.trader_price, EXCLUDED.portfolio_eur_mwh, EXCLUDED.portfolio_on,
              EXCLUDED.min_additive, EXCLUDED.energopomoc_price, EXCLUDED.viwa_additive, EXCLUDED.exception_id,
              EXCLUDED.exception_value, EXCLUDED.source);
    END IF;

    SELECT * INTO r FROM contract_year_calc(c.id, y);
    -- Pod hranicou bez výnimky (individuálna cena)
    IF c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.model ~ '(fix|spot_plus_eur|vykup)' AND r.added_value_eur < 0
       AND r.exception_id IS NULL THEN
      v_det := format('Pridaná hodnota %s: %s € – cena pod hranicou bez schválenej výnimky.', y,
                      replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      v_warn := v_warn || format('Pod hranicou bez výnimky %s: pridaná hodnota %s €', y,
                                 replace(to_char(r.added_value_eur, 'FM999999990.00'), '.', ','));
      IF NOT EXISTS (SELECT 1 FROM contract_flag f WHERE f.contract_id = c.id AND f.code = 'pod_hranicou_bez_vynimky' AND f.year = y
                        AND (f.resolved_at IS NULL OR f.resolved_by IS NOT NULL)) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'pod_hranicou_bez_vynimky', y, v_det);
      ELSE
        UPDATE contract_flag SET detail = v_det
         WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL
           AND detail IS DISTINCT FROM v_det;
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'pod_hranicou_bez_vynimky' AND year = y AND resolved_at IS NULL;
    END IF;
    -- Chýba cena pre obchodníka (podpis od 1. 1. 2026)
    IF c.signed_on >= '2026-01-01' AND c.phase NOT IN ('odmietnuta', 'neuspesna') AND r.missing = 'cena pre obchodníka' THEN
      v_det := format('chýba cena pre obchodníka %s (ceny BL/PL ku dňu podpisu %s)', y, to_char(c.signed_on, 'FMDD. FMMM. YYYY'));
      v_warn := v_warn || ('Chýba cena: ' || v_det);
      IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL) THEN
        INSERT INTO contract_flag (contract_id, code, year, detail) VALUES (c.id, 'chyba_cena', y, v_det);
      END IF;
    ELSE
      UPDATE contract_flag SET resolved_at = now()
       WHERE contract_id = c.id AND code = 'chyba_cena' AND year = y AND resolved_at IS NULL;
    END IF;
  END LOOP;
  RETURN v_warn;
END;
$$;

DELETE FROM notification WHERE kind IN ('nesparovana_zmluva', 'cena_ina_ako_v_ponuke');
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena',
  'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba'));
DELETE FROM deal_event WHERE kind IN ('zmluva_sparovana', 'zmluva_odparovana');
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana',
  'potvrdenie_neodoslane'));
DELETE FROM app_setting WHERE key = 'deal_matching';
DELETE FROM price_exception WHERE approval_request_id IS NOT NULL;
ALTER TABLE price_exception DROP COLUMN approval_request_id;
DELETE FROM contract_flag WHERE code::text = 'cena_ina_ako_v_ponuke';
DROP POLICY contract_flag_update ON contract_flag;
CREATE POLICY contract_flag_update ON contract_flag FOR UPDATE USING (
  EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_flag.contract_id AND crm_contract_editable(k.company_id, k.person_id, k.owner_id))
  OR (code = 'pod_hranicou_bez_vynimky' AND crm_approves_prices() AND EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_flag.contract_id)));
ALTER TABLE contract DROP CONSTRAINT contract_deal_link_check;
DROP INDEX contract_deal_match_idx;
DROP INDEX contract_deal_idx;
ALTER TABLE contract DROP COLUMN offer_variant_id, DROP COLUMN deal_match, DROP COLUMN deal_matched_at, DROP COLUMN deal_matched_by,
  DROP COLUMN deal_match_note, DROP COLUMN deal_match_notified_at;
ALTER TABLE contract ADD CONSTRAINT contract_deal_id_key UNIQUE (deal_id);
-- hodnota cena_ina_ako_v_ponuke ostane v contract_flag_code (PostgreSQL hodnotu enumu neodstráni); nepoužíva sa

DROP FUNCTION deal_contract_input_view(uuid);
DROP FUNCTION deal_contract_input_missing(uuid);
DROP FUNCTION deal_contract_input_save(uuid, jsonb);
DROP FUNCTION iban_ok(text);
DROP FUNCTION crm_contract_input_editor(deal);
DROP TABLE deal_contract_input;
ALTER TABLE oom DROP COLUMN property_relation, DROP COLUMN has_ims;
ALTER TABLE company DROP COLUMN billing_emails, DROP COLUMN social_enterprise, DROP COLUMN contract_name;
DROP FUNCTION email_list_ok(text[]);
ALTER TABLE lookup_value DISABLE TRIGGER trg_guard;
DELETE FROM lookup_value WHERE list_code IN ('vztah_k_nehnutelnosti', 'model_vypoctu_vykupu');
ALTER TABLE lookup_value ENABLE TRIGGER trg_guard;
DELETE FROM lookup_list WHERE code IN ('vztah_k_nehnutelnosti', 'model_vypoctu_vykupu');
