-- migrate:up

-- 0041_potvrdenie_akceptacie – modul 5, fáza F3 (Peter 15. 10.): potvrdenie akceptácie (záväzná objednávka s údajmi
-- akceptácie) sa uloží ako PDF v momente akceptácie do R2 a jeho odtlačok do databázy; pri stiahnutí sa vracia uložený
-- súbor, nie nový (dôkaz pri zmluvnej pokute – nemení sa ani pri zmene kódu či vzhľadu). Uložené znenie a jeho odtlačok
-- ostávajú. Akceptácia klikom (Worker crm-ponuka) zapíše akceptáciu, PDF a odtlačok v jednej transakcii; ručná
-- akceptácia (crm-core) rovnako. Kľúč súboru určuje databáza: potvrdenia/{org}/{rok}/{číslo}[-verzia]-{id8}.pdf.
-- Navyše: zrozumiteľné hlásenie chýbajúcej hranice pri manažérovi (odhad portfólia).

ALTER TABLE offer_acceptance
  ADD COLUMN confirmation_pdf_key    text,
  ADD COLUMN confirmation_pdf_sha256 text CHECK (confirmation_pdf_sha256 IS NULL OR confirmation_pdf_sha256 ~ '^[0-9a-f]{64}$'),
  ADD CONSTRAINT offer_acceptance_confirmation_check CHECK ((confirmation_pdf_key IS NULL) = (confirmation_pdf_sha256 IS NULL));
COMMENT ON COLUMN offer_acceptance.confirmation_pdf_key IS 'R2: potvrdenie akceptácie v PDF uložené v momente akceptácie (nemení sa) – 0041';

-- Kľúč potvrdenia pre akceptáciu (jediné miesto, kde vzniká)
CREATE FUNCTION offer_acceptance_confirmation_key(p_id uuid) RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT 'potvrdenia/' || o.org_id || '/20' || substr(o.number, 2, 2) || '/' || o.number
         || CASE WHEN o.version > 1 THEN '-' || o.version ELSE '' END || '-' || left(a.id::text, 8) || '.pdf'
    FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id
   WHERE a.id = p_id
$$;
REVOKE EXECUTE ON FUNCTION offer_acceptance_confirmation_key(uuid) FROM PUBLIC;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
  REVOKE EXECUTE ON FUNCTION offer_acceptance_confirmation_key(uuid) FROM crm_app; END IF; END $$;

-- Údaje akceptácie pre vykreslenie potvrdenia (uložené znenie, IP, odtlačok, dokument ponuky) a kľúč súboru
CREATE FUNCTION offer_acceptance_result(p_id uuid, p_repeated boolean) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT jsonb_build_object(
           'ok', true, 'repeated', p_repeated, 'acceptance_id', a.id, 'accepted_at', a.accepted_at,
           'variant', chr(64 + v.sort_order) || ' · ' || v.name, 'method', a.method, 'channel', a.channel,
           'signer_name', a.signer_name, 'signer_function', a.signer_function, 'ip', host(a.ip),
           'terms_text', a.terms_text, 'terms_sha256', a.terms_sha256,
           'confirmation_key', offer_acceptance_confirmation_key(a.id),
           'confirmation_stored', a.confirmation_pdf_key IS NOT NULL,
           'document', offer_document_internal(a.offer_id))
    FROM offer_acceptance a JOIN offer_variant v ON v.id = a.variant_id
   WHERE a.id = p_id
$$;
REVOKE EXECUTE ON FUNCTION offer_acceptance_result(uuid, boolean) FROM PUBLIC;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
  REVOKE EXECUTE ON FUNCTION offer_acceptance_result(uuid, boolean) FROM crm_app; END IF; END $$;

-- Uloženie potvrdenia: raz, s kľúčom z databázy (kód databázy)
CREATE FUNCTION offer_acceptance_confirmation_attach(p_id uuid, p_key text, p_sha256 text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_sha256 IS NULL OR p_sha256 !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Neplatný odtlačok potvrdenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_key IS DISTINCT FROM offer_acceptance_confirmation_key(p_id) THEN
    RAISE EXCEPTION 'Neplatný súbor potvrdenia.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_acceptance SET confirmation_pdf_key = p_key, confirmation_pdf_sha256 = p_sha256
   WHERE id = p_id AND confirmation_pdf_key IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Potvrdenie už je uložené – nemení sa.' USING ERRCODE = 'check_violation';
  END IF;
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_acceptance_confirmation_attach(uuid, text, text) FROM PUBLIC;
DO $$ BEGIN IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
  REVOKE EXECUTE ON FUNCTION offer_acceptance_confirmation_attach(uuid, text, text) FROM crm_app; END IF; END $$;

-- Aplikácia (ručná akceptácia): kto smie ponuku upravovať, v čase zápisu akceptácie (do 10 minút)
CREATE FUNCTION offer_acceptance_confirmation_set(p_id uuid, p_key text, p_sha256 text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a offer_acceptance;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Akceptácia neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  PERFORM offer_for_edit(a.offer_id);
  IF a.method <> 'rucne' OR a.created_at < now() - interval '10 minutes' THEN
    RAISE EXCEPTION 'Potvrdenie sa ukladá iba pri zápise akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_acceptance_confirmation_attach(p_id, p_key, p_sha256);
END;
$$;

-- Ručná akceptácia vráti údaje pre potvrdenie (aplikácia ho vykreslí a uloží v tej istej transakcii)
CREATE FUNCTION offer_acceptance_for_confirmation(p_id uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a offer_acceptance;
BEGIN
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  PERFORM offer_for_edit(a.offer_id);
  RETURN offer_acceptance_result(p_id, false);
END;
$$;

-- Verejná akceptácia vráti údaje pre potvrdenie (náhrada 0039)
CREATE OR REPLACE FUNCTION offer_public_accept(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text,
                                    p_terms_sha256 text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  a    offer_acceptance;
  v_id uuid;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  IF FOUND THEN
    IF a.variant_id = p_variant AND a.method = 'klik' THEN
      RETURN offer_acceptance_result(a.id, true);
    END IF;
    RAISE EXCEPTION 'Ponuka už bola akceptovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF offer_public_mode(o) <> 'aktivna' THEN
    RAISE EXCEPTION 'Platnosť ponuky uplynula alebo ponuka už neplatí.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_ip IS NULL THEN
    RAISE EXCEPTION 'Chýba IP adresa.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_terms_sha256 IS DISTINCT FROM offer_terms_sha(offer_terms_text(o.id, p_variant)) THEN
    RAISE EXCEPTION 'Znenie ponuky sa medzitým zmenilo – obnovte stránku.' USING ERRCODE = 'check_violation';
  END IF;
  v_id := offer_accept_record(o.id, p_variant, 'klik', NULL, now(), p_name, p_function, p_ip, p_ua, NULL, NULL, NULL);
  RETURN offer_acceptance_result(v_id, false);
END;
$$;


-- Worker crm-ponuka: uloží potvrdenie ku klik-akceptácii tejto ponuky, iba hneď po nej (do 10 minút)
CREATE FUNCTION verejne.ponuka_potvrdenie_ulozit(p_hash text, p_acceptance uuid, p_key text, p_sha256 text) RETURNS void
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' OR NOT EXISTS (
       SELECT 1 FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id
        WHERE a.id = p_acceptance AND o.link_hash = p_hash AND a.method = 'klik' AND a.revoked_at IS NULL
          AND a.created_at >= now() - interval '10 minutes') THEN
    RAISE EXCEPTION 'Potvrdenie nemožno uložiť.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM public.offer_acceptance_confirmation_attach(p_acceptance, p_key, p_sha256);
END;
$$;

-- Worker crm-ponuka: uložené potvrdenie platnej akceptácie (kým odkaz platí)
CREATE FUNCTION verejne.ponuka_potvrdenie_pdf(p_hash text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer;
  a offer_acceptance;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash;
  IF offer_public_mode(o) = 'neplatny' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL AND confirmation_pdf_key IS NOT NULL;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('pdf_key', a.confirmation_pdf_key,
                            'file_name', 'Potvrdenie-' || replace(offer_display_number(o), '/', '-') || '.pdf');
END;
$$;
REVOKE EXECUTE ON FUNCTION verejne.ponuka_potvrdenie_ulozit(text, uuid, text, text), verejne.ponuka_potvrdenie_pdf(text) FROM PUBLIC;

-- Hlásenie chýbajúcej hranice: pri manažérovi chýba odhad portfólia, nie cena pre obchodníka (Peter 15. 10.; náhrada 0038)
CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE (
  oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model price_model, kind text,
  price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric,
  months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text,
  exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
sc AS (SELECT offer_variant_scope(p_variant) AS scope WHERE EXISTS (SELECT 1 FROM v)),
mo AS (SELECT m.m_start, m.year FROM offer_variant ov, offer_variant_months(ov) m
        WHERE ov.id = p_variant AND EXISTS (SELECT 1 FROM v)),
dm AS (
  SELECT x.oom_id, oom_voltage_group(o.voltage_level) AS vg, o.price_regulation AS reg,
         coalesce(x.planned_vt_mwh, 0) AS vt_y, coalesce(x.planned_nt_mwh, 0) AS nt_y,
         coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0) AS feed_y,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS kw
    FROM v JOIN deal_oom x ON x.deal_id = v.deal_id JOIN oom o ON o.id = x.oom_id
),
oy AS (   -- OOM × rok: mesiace a objemy
  SELECT dm.oom_id, dm.vg, dm.reg, dm.kw, mo.year, count(*)::int AS months,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN dm.feed_y ELSE dm.vt_y END * count(*) / 12 AS v_vt,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN 0 ELSE dm.nt_y END * count(*) / 12 AS v_nt
    FROM dm CROSS JOIN mo
   GROUP BY dm.oom_id, dm.vg, dm.reg, dm.kw, dm.feed_y, dm.vt_y, dm.nt_y, mo.year
),
it AS (
  SELECT oy.*, i.id AS item_id, i.price_model, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
         i.additive_eur_mwh AS ad, i.additive_pct AS pct,
         CASE WHEN (SELECT okind FROM v) = 'viwa' THEN 'viwa'
              WHEN (SELECT okind FROM v) = 'vykup' THEN CASE WHEN i.price_model IS NOT NULL THEN 'vykup' END
              WHEN i.price_model = 'cennik' AND (SELECT household FROM v) AND oy.reg THEN 'energo'
              WHEN i.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN i.price_model::text END AS kind
    FROM oy
    LEFT JOIN LATERAL (SELECT * FROM offer_item i
                        WHERE i.variant_id = p_variant AND i.oom_id = oy.oom_id AND i.slot = 'komodita'
                          AND (i.year = oy.year OR i.year IS NULL)
                        ORDER BY i.year NULLS LAST LIMIT 1) i ON true
),
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037), pri nezmenenom rozsahu variantu (0038)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
     -- neodoslaná verzia: rozsah variantu (OOM, roky, objemy) ako pri žiadosti; odoslaná si výnimku ponechá
     AND ((SELECT osent FROM v) IS NOT NULL OR a.scope = (SELECT scope FROM sc))
     -- výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá
     AND CASE WHEN (SELECT osent FROM v) IS NULL THEN r.valid_until IS NULL OR r.valid_until > now()
              ELSE r.valid_until IS NULL OR (SELECT osent FROM v) <= r.valid_until END
   GROUP BY 1, 2, 3
),
calc AS (
  SELECT it.*, b.seller_type, b.trader_price, b.portfolio_eur_mwh AS portfolio_b, b.min_additive, b.energopomoc_price,
         b.viwa_additive,
         (SELECT e.value FROM ex e WHERE e.year = it.year AND e.price_model = it.price_model
                                    AND e.voltage_group IN (it.vg, 'vsetko') ORDER BY e.value LIMIT 1) AS exc,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'portfolio')) AS portfolio_today,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'spot_fve')) AS spot_fve,
         (SELECT coalesce(sum((coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * it.kw) * it.months), 0)
            FROM offer_item f
           WHERE f.variant_id = p_variant AND f.oom_id = it.oom_id AND f.slot <> 'komodita'
             AND (f.year = it.year OR f.year IS NULL)) AS fees
    FROM it
    LEFT JOIN offer_year_basis b ON b.variant_id = p_variant AND b.year = it.year
),
val AS (
  SELECT calc.*,
         pv_revenue(kind, price_model, vt, nt, ad, pct, v_vt, v_nt, spot_fve, viwa_additive) AS rev,
         pv_unit_cost(kind, price_model, vt, seller_type, trader_price, portfolio_b, energopomoc_price, min_additive, exc) AS ucost,
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost,
         CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
              WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
              WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
              WHEN kind = 'cennik' THEN 'odhad_portfolia'
              WHEN kind = 'energo' THEN 'energopomoc'
              WHEN kind = 'viwa' THEN 'viwa' END AS src
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       CASE WHEN src = 'odhad_portfolia' AND NOT (SELECT see_portfolio FROM v) THEN NULL ELSE ucost END,
       src,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            -- 0041: pri manažérovi je hranicou odhad portfólia (hlásenie hovorí, čo chýba a čo urobiť)
            WHEN kind = 'fix' AND ucost IS NULL THEN
              CASE WHEN seller_type = 'manazer'
                   THEN 'chýba odhad portfólia (hranica manažéra) – doplňte ho v cenách dňa a ponuku prepočítajte'
                   ELSE 'chýba cena pre obchodníka – doplňte ceny dňa a ponuku prepočítajte' END
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;

-- migrate:down

-- funkcia z 0038 v pôvodnom znení
CREATE OR REPLACE FUNCTION offer_variant_values(p_variant uuid) RETURNS TABLE (
  oom_id uuid, year smallint, voltage_group text, item_id uuid, price_model price_model, kind text,
  price_vt numeric, price_nt numeric, additive numeric, additive_pct numeric,
  months integer, volume_mwh numeric, revenue_eur numeric, threshold numeric, threshold_source text,
  exception_value numeric, added_value_eur numeric, fees_eur numeric, margin_eur numeric, below boolean, missing text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
WITH v AS (
  SELECT v.*, o.kind AS okind, o.household, o.org_id AS oorg, o.sent_at AS osent, d.id AS deal_id, crm_can_see_margin() AS see_margin,
         crm_sees_portfolio() AS see_portfolio
    FROM offer_variant v JOIN offer o ON o.id = v.offer_id JOIN deal d ON d.id = o.deal_id
   WHERE v.id = p_variant
     AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
),
sc AS (SELECT offer_variant_scope(p_variant) AS scope WHERE EXISTS (SELECT 1 FROM v)),
mo AS (SELECT m.m_start, m.year FROM offer_variant ov, offer_variant_months(ov) m
        WHERE ov.id = p_variant AND EXISTS (SELECT 1 FROM v)),
dm AS (
  SELECT x.oom_id, oom_voltage_group(o.voltage_level) AS vg, o.price_regulation AS reg,
         coalesce(x.planned_vt_mwh, 0) AS vt_y, coalesce(x.planned_nt_mwh, 0) AS nt_y,
         coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0) AS feed_y,
         coalesce(x.source_power_kw, o.source_power_kw, 0) AS kw
    FROM v JOIN deal_oom x ON x.deal_id = v.deal_id JOIN oom o ON o.id = x.oom_id
),
oy AS (   -- OOM × rok: mesiace a objemy
  SELECT dm.oom_id, dm.vg, dm.reg, dm.kw, mo.year, count(*)::int AS months,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN dm.feed_y ELSE dm.vt_y END * count(*) / 12 AS v_vt,
         CASE WHEN (SELECT okind FROM v) IN ('vykup', 'viwa') THEN 0 ELSE dm.nt_y END * count(*) / 12 AS v_nt
    FROM dm CROSS JOIN mo
   GROUP BY dm.oom_id, dm.vg, dm.reg, dm.kw, dm.feed_y, dm.vt_y, dm.nt_y, mo.year
),
it AS (
  SELECT oy.*, i.id AS item_id, i.price_model, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
         i.additive_eur_mwh AS ad, i.additive_pct AS pct,
         CASE WHEN (SELECT okind FROM v) = 'viwa' THEN 'viwa'
              WHEN (SELECT okind FROM v) = 'vykup' THEN CASE WHEN i.price_model IS NOT NULL THEN 'vykup' END
              WHEN i.price_model = 'cennik' AND (SELECT household FROM v) AND oy.reg THEN 'energo'
              WHEN i.price_model IN ('fix', 'cennik', 'spot_plus_eur') THEN i.price_model::text END AS kind
    FROM oy
    LEFT JOIN LATERAL (SELECT * FROM offer_item i
                        WHERE i.variant_id = p_variant AND i.oom_id = oy.oom_id AND i.slot = 'komodita'
                          AND (i.year = oy.year OR i.year IS NULL)
                        ORDER BY i.year NULLS LAST LIMIT 1) i ON true
),
ex AS (   -- schválená výnimka pre rok, model a napäťovú skupinu (0037), pri nezmenenom rozsahu variantu (0038)
  SELECT a.year, a.price_model, a.voltage_group, min(a.approved_value) AS value
    FROM approval_price_item a JOIN approval_request r ON r.id = a.approval_id
   WHERE a.variant_id = p_variant AND r.status = 'schvalena' AND a.approved_value IS NOT NULL
     -- neodoslaná verzia: rozsah variantu (OOM, roky, objemy) ako pri žiadosti; odoslaná si výnimku ponechá
     AND ((SELECT osent FROM v) IS NOT NULL OR a.scope = (SELECT scope FROM sc))
     -- výnimka platí 3 dni na odoslanie; odoslaná ponuka si ju ponechá
     AND CASE WHEN (SELECT osent FROM v) IS NULL THEN r.valid_until IS NULL OR r.valid_until > now()
              ELSE r.valid_until IS NULL OR (SELECT osent FROM v) <= r.valid_until END
   GROUP BY 1, 2, 3
),
calc AS (
  SELECT it.*, b.seller_type, b.trader_price, b.portfolio_eur_mwh AS portfolio_b, b.min_additive, b.energopomoc_price,
         b.viwa_additive,
         (SELECT e.value FROM ex e WHERE e.year = it.year AND e.price_model = it.price_model
                                    AND e.voltage_group IN (it.vg, 'vsetko') ORDER BY e.value LIMIT 1) AS exc,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'portfolio')) AS portfolio_today,
         (SELECT value FROM contract_market_value((SELECT oorg FROM v), it.year, crm_today(), 'spot_fve')) AS spot_fve,
         (SELECT coalesce(sum((coalesce(f.fee_eur_month, 0) + coalesce(f.fee_kw_eur_month, 0) * it.kw) * it.months), 0)
            FROM offer_item f
           WHERE f.variant_id = p_variant AND f.oom_id = it.oom_id AND f.slot <> 'komodita'
             AND (f.year = it.year OR f.year IS NULL)) AS fees
    FROM it
    LEFT JOIN offer_year_basis b ON b.variant_id = p_variant AND b.year = it.year
),
val AS (
  SELECT calc.*,
         pv_revenue(kind, price_model, vt, nt, ad, pct, v_vt, v_nt, spot_fve, viwa_additive) AS rev,
         pv_unit_cost(kind, price_model, vt, seller_type, trader_price, portfolio_b, energopomoc_price, min_additive, exc) AS ucost,
         pv_unit_margin_cost(kind, price_model, vt, portfolio_today, energopomoc_price, min_additive, exc) AS mcost,
         CASE WHEN exc IS NOT NULL AND kind IN ('fix', 'spot_plus_eur', 'vykup') THEN 'vynimka'
              WHEN kind = 'fix' THEN CASE WHEN seller_type = 'manazer' THEN 'odhad_portfolia' ELSE 'cena_pre_obchodnika' END
              WHEN kind IN ('spot_plus_eur', 'vykup') THEN CASE WHEN price_model = 'fix' THEN 'cena_vykupu' ELSE 'min_aditiv' END
              WHEN kind = 'cennik' THEN 'odhad_portfolia'
              WHEN kind = 'energo' THEN 'energopomoc'
              WHEN kind = 'viwa' THEN 'viwa' END AS src
    FROM calc
)
SELECT oom_id, year, vg, item_id, price_model, kind, vt, nt, ad, pct, months,
       round(v_vt + v_nt, 3),
       round(rev, 2),
       CASE WHEN src = 'odhad_portfolia' AND NOT (SELECT see_portfolio FROM v) THEN NULL ELSE ucost END,
       src,
       exc,
       round(rev - ucost * (v_vt + v_nt), 2),
       round(fees, 2),
       CASE WHEN (SELECT see_margin FROM v) THEN round(rev + fees - mcost * (v_vt + v_nt), 2) END,
       coalesce(kind IN ('fix', 'spot_plus_eur', 'vykup') AND price_model <> 'cennik'
                AND rev - ucost * (v_vt + v_nt) < 0, false),
       CASE WHEN item_id IS NULL THEN 'chýba cena'
            WHEN kind = 'fix' AND ucost IS NULL THEN 'chýba cena pre obchodníka'
            WHEN kind IN ('spot_plus_eur', 'vykup') AND ucost IS NULL THEN 'chýba minimálny aditív'
            WHEN kind = 'viwa' AND viwa_additive IS NULL THEN 'chýba balík VIWA'
            WHEN kind = 'vykup' AND price_model = 'spot_minus_pct' AND spot_fve IS NULL THEN 'chýba očakávaná cena SPOT pre FVE' END
  FROM val
 ORDER BY year, vg, oom_id
$$;


DROP FUNCTION IF EXISTS verejne.ponuka_potvrdenie_pdf(text);
DROP FUNCTION IF EXISTS verejne.ponuka_potvrdenie_ulozit(text, uuid, text, text);
CREATE OR REPLACE FUNCTION offer_public_accept(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text,
                                    p_terms_sha256 text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  a    offer_acceptance;
  v_id uuid;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  IF FOUND THEN
    IF a.variant_id = p_variant AND a.method = 'klik' THEN
      RETURN jsonb_build_object('ok', true, 'repeated', true, 'accepted_at', a.accepted_at);
    END IF;
    RAISE EXCEPTION 'Ponuka už bola akceptovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF offer_public_mode(o) <> 'aktivna' THEN
    RAISE EXCEPTION 'Platnosť ponuky uplynula alebo ponuka už neplatí.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_ip IS NULL THEN
    RAISE EXCEPTION 'Chýba IP adresa.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_terms_sha256 IS DISTINCT FROM offer_terms_sha(offer_terms_text(o.id, p_variant)) THEN
    RAISE EXCEPTION 'Znenie ponuky sa medzitým zmenilo – obnovte stránku.' USING ERRCODE = 'check_violation';
  END IF;
  v_id := offer_accept_record(o.id, p_variant, 'klik', NULL, now(), p_name, p_function, p_ip, p_ua, NULL, NULL, NULL);
  RETURN jsonb_build_object('ok', true, 'repeated', false, 'accepted_at', now());
END;
$$;

DROP FUNCTION IF EXISTS offer_acceptance_for_confirmation(uuid);
DROP FUNCTION IF EXISTS offer_acceptance_confirmation_set(uuid, text, text);
DROP FUNCTION IF EXISTS offer_acceptance_confirmation_attach(uuid, text, text);
DROP FUNCTION IF EXISTS offer_acceptance_result(uuid, boolean);
DROP FUNCTION IF EXISTS offer_acceptance_confirmation_key(uuid);
ALTER TABLE offer_acceptance
  DROP CONSTRAINT offer_acceptance_confirmation_check,
  DROP COLUMN confirmation_pdf_sha256,
  DROP COLUMN confirmation_pdf_key;
