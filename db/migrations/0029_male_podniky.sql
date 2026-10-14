-- migrate:up

-- 0029_male_podniky – modul 4 (Peter, 14. 10. 2026, k F4):
--   A. „Pod hranicou bez výnimky“ uzatvára iba „schvaľuje ceny“ s poznámkou; „Chýba cena“ iba databáza;
--      aplikácia pri príznaku mení iba uzavretie (kto, kedy, poznámka).
--   B. Malý podnik je v regulácii, ak ročný objem na všetkých OOM a súbežne účinných zmluvách o dodávke je najviac
--      30,000 MWh; nad 30,000 MWh treba zákazníka vyradiť. Objem sa porovnáva dvakrát – zo zmlúv (Office portal) aj
--      z plánovanej spotreby OOM (XM Trade); pri nesúlade upozornenie „overte“. Iba upozornenia, nič sa nemení samo:
--      karta zmluvy a zákazníka, náhľad importu, filter v zozname, denník a upozornenie z nočného behu.
--   Bod 3: vyradenie malého podniku z regulácie je chyba nočného behu iba pri objeme do 30 MWh; nad 30 MWh (alebo pri
--      nesúlade) je to „Chýba cena“ s textom „vyradený z cenovej regulácie – treba novú cenu“.
-- Cockpit (pôvodne 0029) bude 0030.

-- ============================================================================
-- A. Príznaky zmluvy: kto smie čo uzavrieť
-- ============================================================================

-- Databáza (import, nočný beh, párovanie výnimky – funkcie vlastníka) smie všetko. Používateľ smie iba uzavrieť otvorený
-- príznak (resolved_at, resolved_by = on, resolved_note); „Chýba cena“ nie (zmizne sama); „Pod hranicou bez výnimky“
-- iba „schvaľuje ceny“ s poznámkou (zadanie časť 7).
CREATE FUNCTION contract_flag_resolve_guard() RETURNS trigger
LANGUAGE plpgsql SET search_path = public, pg_temp AS $$
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
CREATE TRIGGER trg_resolve_guard BEFORE UPDATE ON contract_flag FOR EACH ROW EXECUTE FUNCTION contract_flag_resolve_guard();

-- Schvaľovateľ cien smie „Pod hranicou“ uzavrieť aj pri zmluve, ktorú inak upravovať nesmie (vidí všetky zmluvy, 0023)
DROP POLICY contract_flag_update ON contract_flag;
CREATE POLICY contract_flag_update ON contract_flag FOR UPDATE
  USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id AND crm_contract_editable(k.company_id, k.person_id, k.owner_id))
         OR (code = 'pod_hranicou_bez_vynimky' AND crm_approves_prices()
             AND EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id)));

-- ============================================================================
-- B. Malý podnik a hranica 30 MWh
-- ============================================================================

-- MWh na text: najviac 3 desatinné miesta, desatinná čiarka (30,001)
CREATE FUNCTION mwh_text(p numeric) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT replace(CASE WHEN p IS NULL THEN NULL
                      WHEN round(p, 3) = trunc(p) THEN trunc(p)::text
                      ELSE rtrim(round(p, 3)::text, '0') END, '.', ',')
$$;

-- Ročný objem regulovaných firemných zákazníkov k dňu p_on (iba agregáty, bez osobných údajov):
--   zmluvy = Σ zmluvného množstva VT + NT OOM spotreby v podpísaných zmluvách o dodávke firmy účinných k p_on;
--   XM Trade = Σ plánovanej spotreby VT + NT tých istých OOM (xm_missing = OOM bez plánovanej spotreby);
--   regulovaný = niektorá z týchto zmlúv je „malý podnik“, má regulovaný produkt (DMP) alebo OOM s reguláciou ANO.
-- Stav: ostava (oba objemy do 30 MWh), vyradit (oba nad 30 MWh, alebo zmluvy nad 30 a XM Trade chýba), nesulad.
CREATE FUNCTION small_business_volume(p_on date, p_company_id uuid DEFAULT NULL)
RETURNS TABLE (company_id uuid, contract_mwh numeric, xm_mwh numeric, xm_missing integer, oom_count integer,
               state text, message text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  WITH r AS (
    SELECT k.company_id, k.small_business, co.oom_id, co.qty_vt_mwh + co.qty_nt_mwh AS qty,
           p.price_regulation AS product_reg, o.price_regulation AS oom_reg,
           o.planned_consumption_vt_mwh AS xm_vt, o.planned_consumption_nt_mwh AS xm_nt
      FROM contract k
      JOIN contract_oom co ON co.contract_id = k.id
      JOIN oom o ON o.id = co.oom_id
      LEFT JOIN product p ON p.id = co.product_id
     WHERE k.company_id IS NOT NULL AND (p_company_id IS NULL OR k.company_id = p_company_id)
       AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%' AND o.type = 'spotreba'
       AND co.valid_from IS NOT NULL AND co.valid_from <= p_on AND (co.valid_to IS NULL OR co.valid_to >= p_on)
  ), c AS (
    SELECT r.company_id, sum(r.qty) AS contract_mwh,
           bool_or(r.small_business OR r.product_reg IS TRUE OR r.oom_reg IS TRUE) AS regulated
      FROM r GROUP BY r.company_id
  ), x AS (
    SELECT d.company_id,
           sum(coalesce(d.xm_vt, 0) + coalesce(d.xm_nt, 0)) FILTER (WHERE d.xm_vt IS NOT NULL OR d.xm_nt IS NOT NULL) AS xm_mwh,
           (count(*) FILTER (WHERE d.xm_vt IS NULL AND d.xm_nt IS NULL))::int AS xm_missing,
           count(*)::int AS oom_count
      FROM (SELECT DISTINCT r.company_id, r.oom_id, r.xm_vt, r.xm_nt FROM r) d
     GROUP BY d.company_id
  ), s AS (
    SELECT c.company_id, c.contract_mwh, x.xm_mwh, x.xm_missing, x.oom_count,
           CASE WHEN c.contract_mwh > 30 AND (x.xm_mwh IS NULL OR x.xm_mwh > 30) THEN 'vyradit'
                WHEN c.contract_mwh > 30 OR x.xm_mwh > 30 THEN 'nesulad'
                ELSE 'ostava' END AS state,
           format('zmluvy %s MWh, XM Trade %s', mwh_text(c.contract_mwh),
                  CASE WHEN x.xm_mwh IS NULL THEN 'bez plánovanej spotreby'
                       ELSE mwh_text(x.xm_mwh) || ' MWh'
                            || CASE WHEN x.xm_missing > 0 THEN format(' (pri %s z %s OOM chýba)', x.xm_missing, x.oom_count) ELSE '' END
                  END) AS volumes
      FROM c JOIN x ON x.company_id = c.company_id
     WHERE c.regulated
  )
  SELECT s.company_id, s.contract_mwh, s.xm_mwh, s.xm_missing, s.oom_count, s.state,
         CASE s.state
           WHEN 'ostava' THEN format('Ročný objem do 30 MWh (%s) – zákazník ostáva v cenovej regulácii.', s.volumes)
           WHEN 'vyradit' THEN format('Pozor: ročný objem nad 30 MWh (%s) – zákazník nemá nárok na regulovaný cenník, treba ho vyradiť z cenovej regulácie.', s.volumes)
           ELSE format('Pozor: objem podľa zmlúv a podľa XM Trade sa líši okolo hranice 30 MWh (%s). Overte, či má zákazník nárok na regulovaný cenník.', s.volumes)
         END
    FROM s
$$;
COMMENT ON FUNCTION small_business_volume(date, uuid) IS
  'malý podnik: ročný objem zo zmlúv a z XM Trade k dňu, stav ostava / vyradit / nesulad (hranica 30 MWh vrátane); iba upozornenie';

-- Zmluva patrí zákazníkovi, ktorý je k dnešku nad hranicou alebo v nesúlade (vyradenie z regulácie môže byť oprávnené)
CREATE FUNCTION contract_small_business_over(p_contract_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM contract k, small_business_volume(crm_today(), k.company_id) s
                  WHERE k.id = p_contract_id AND k.company_id IS NOT NULL AND s.state IN ('vyradit', 'nesulad'))
$$;
REVOKE EXECUTE ON FUNCTION contract_small_business_over(uuid) FROM PUBLIC;

-- Import zmlúv: upozornenie riadku pri zmluve regulovaného zákazníka nad 30 MWh alebo v nesúlade (náhľad aj uloženie;
-- v náhľade sú zmluvy uložené v podtransakcii, ktorá sa vráti)
CREATE FUNCTION contract_import_small_business(p_res jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  x     jsonb;
  v_out jsonb := '[]';
  v_msg text;
BEGIN
  FOR x IN SELECT * FROM jsonb_array_elements(coalesce(p_res -> 'contracts', '[]')) LOOP
    v_msg := NULL;
    IF x ->> 'contract_id' IS NOT NULL THEN
      SELECT s.message INTO v_msg
        FROM contract k, small_business_volume(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.company_id) s
       WHERE k.id = (x ->> 'contract_id')::uuid AND k.company_id IS NOT NULL AND s.state IN ('vyradit', 'nesulad');
    END IF;
    IF v_msg IS NOT NULL THEN
      x := jsonb_set(x, '{warnings}', coalesce(x -> 'warnings', '[]') || to_jsonb(v_msg));
    END IF;
    v_out := v_out || x;
  END LOOP;
  RETURN CASE WHEN p_res ? 'contracts' THEN jsonb_set(p_res, '{contracts}', v_out) ELSE p_res END;
END;
$$;
REVOKE EXECUTE ON FUNCTION contract_import_small_business(jsonb) FROM PUBLIC;

CREATE OR REPLACE FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}',
                                    p_expected jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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

-- Upozornenie obchodníkovi raz za rok (nočný beh)
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN ('konci_4_mesiace', 'sprolongovana',
  'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik'));

-- Bod 3: „Chýba cena“ s textom „vyradený z cenovej regulácie“; chyba behu iba pri malom podniku do 30 MWh
CREATE OR REPLACE FUNCTION contract_price_missing_refresh(p_contract_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
  v_reg    date;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') THEN
    FOR co IN
      SELECT x.*, o.eic
        FROM contract_oom x JOIN oom o ON o.id = x.oom_id
       WHERE x.contract_id = c.id
         AND ((c.type::text LIKE 'dodavka%' AND o.type = 'spotreba') OR c.type = 'vykup')
       ORDER BY o.eic
    LOOP
      IF co.valid_from IS NULL THEN
        v_miss := v_miss || format('OOM %s: chýba účinnosť od', co.eic);
        CONTINUE;
      END IF;
      v_from := greatest(co.valid_from, v_y_from);
      v_to := coalesce(co.valid_to, greatest(v_from, v_y_to));
      CONTINUE WHEN v_to < v_from;
      IF NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
                     - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                                  WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita'),
                                '{}'::datemultirange)) THEN
        -- vyradený z regulácie bez regulovaného páru produktu (malý podnik nad 30 MWh, 0029)
        v_reg := (SELECT min(s.seg_from) FROM contract_regulation_segments(co.oom_id, co.product_id, co.valid_from, co.valid_to) s
                   WHERE co.product_id IS NOT NULL AND s.seg_product IS NULL);
        IF v_reg IS NOT NULL THEN
          v_miss := v_miss || format('OOM %s: vyradený z cenovej regulácie od %s – treba novú cenu (cenník nad 30 MWh alebo individuálnu)',
                                     co.eic, to_char(v_reg, 'FMDD. FMMM. YYYY'));
        ELSE
          v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                     to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
        END IF;
      END IF;
    END LOOP;
    IF c.type = 'viwa' THEN
      IF c.viwa_package IS NULL THEN
        v_miss := v_miss || 'chýba balík VIWA (doplní Servis)'::text;
      ELSIF c.valid_from IS NOT NULL THEN
        v_from := greatest(c.valid_from, v_y_from);
        v_to := coalesce(contract_effective_to(c), greatest(v_from, v_y_to));
        IF v_to >= v_from AND NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
             - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                          WHERE p.contract_id = c.id AND p.slot = 'viwa_ucet'), '{}'::datemultirange)) THEN
          v_miss := v_miss || 'chýba cena balíka VIWA v cenníku'::text;
        END IF;
      END IF;
    END IF;
  END IF;

  v_detail := nullif(array_to_string(v_miss, '; '), '');
  IF v_detail IS NULL THEN
    UPDATE contract_flag SET resolved_at = now()
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;

CREATE OR REPLACE FUNCTION contract_sync_checked(p_contract_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_changed boolean := contract_price_list_sync(p_contract_id);
  v_missing text := contract_regulation_pair_missing(p_contract_id);
BEGIN
  -- malý podnik s objemom nad 30 MWh (alebo nesúladom zmluvy / XM Trade) môže byť z regulácie vyradený oprávnene:
  -- nie chyba, ale „Chýba cena“ s textom „vyradený z regulácie“ (0029, odpoveď 3)
  IF v_missing IS NOT NULL AND NOT contract_small_business_over(p_contract_id) THEN
    RAISE EXCEPTION '%', v_missing USING ERRCODE = 'check_violation';
  END IF;
  RETURN v_changed;
END;
$$;

CREATE OR REPLACE FUNCTION contract_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run     uuid;
  v_err     jsonb := '[]';
  v_touched uuid[] := '{}';
  v_id      uuid;
  r         record;
  v_ok      boolean;
  v_end     date;
  v_last    date;
  v_state   text;
  v_msg     text;
  v_n       jsonb := '{}';
  v_cnt     integer;
  v_result  jsonb;
  v_pr      record;
  v_ended   integer := 0;
  v_before  uuid[];
  v_retro   text[] := '{}';
  v_sb      text[] := '{}';
  v_prev_today  text := coalesce(current_setting('crm.today', true), '');
  v_prev_source text;
BEGIN
  IF p_today IS NULL THEN
    RAISE EXCEPTION 'contract_daily_run_at: chýba dátum' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtext('crm.contract_daily_run')) THEN
    RETURN jsonb_build_object('bezi', true);
  END IF;
  PERFORM set_config('crm.today', p_today::text, true);   -- crm_today() v spojení vlastníka (ručný beh)
  v_prev_source := crm_as_system(true);
  SELECT max(run_date) INTO v_last FROM job_run
   WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL AND run_date < p_today;
  INSERT INTO job_run (job, run_date, test_date)
  VALUES ('zmluvy', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;

  -- 1. Regulácia: ceny zmlúv na OOM, ktorých zmena regulácie nastala a zmluvy ju ešte nemajú
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT ch.id, ch.oom_id, ch.valid_from FROM oom_price_regulation_change ch
              WHERE ch.contract_applied_at IS NULL AND ch.valid_from <= p_today
              ORDER BY ch.valid_from, ch.id LOOP
      v_ok := true;
      FOR v_id IN SELECT DISTINCT co.contract_id FROM contract_oom co JOIN contract k ON k.id = co.contract_id
                   WHERE co.oom_id = r.oom_id AND k.phase NOT IN ('odmietnuta', 'neuspesna')
                     AND (co.valid_to IS NULL OR co.valid_to >= r.valid_from) LOOP
        BEGIN
          IF contract_sync_checked(v_id) THEN
            PERFORM contract_after_price_change(v_id);
            v_cnt := v_cnt + 1;
            v_touched := v_touched || v_id;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_ok := false;
          v_err := v_err || job_error(v_id, 'regulacia', v_state, v_msg);
        END;
      END LOOP;
      IF v_ok THEN
        UPDATE oom_price_regulation_change SET contract_applied_at = now() WHERE id = r.id;
      END IF;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'regulacia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('regulacia', v_cnt);

  -- 2. Cenník: zmluvy s cenníkovou cenou, ktorej verzia medzitým skončila alebo bola nahradená, a zmluvy s „Chýba cena“.
  --    Nová verzia sa uplatní prvú noc po schválení; cena platná od dátumu v minulosti sa zapíše od toho dátumu
  --    a zmluva ide do zoznamu „cennik_spatne“ v denníku behu (pre Nákup).
  v_cnt := 0;
  BEGIN
    FOR v_id IN SELECT cp.contract_id FROM contract_price cp
                  JOIN price_list_item i ON i.id = cp.price_list_item_id
                  JOIN price_list_version v ON v.id = i.version_id
                 WHERE cp.source = 'import'
                   AND (v.status = 'nahradena' OR (v.valid_to IS NOT NULL AND (cp.valid_to IS NULL OR cp.valid_to > v.valid_to)))
                UNION
                SELECT f.contract_id FROM contract_flag f WHERE f.code = 'chyba_cena' AND f.resolved_at IS NULL
                ORDER BY 1 LOOP
      BEGIN
        v_before := ARRAY(SELECT id FROM contract_price WHERE contract_id = v_id);
        IF contract_sync_checked(v_id) THEN
          PERFORM contract_after_price_change(v_id);
          v_cnt := v_cnt + 1;
          v_touched := v_touched || v_id;
          IF EXISTS (SELECT 1 FROM contract_price WHERE contract_id = v_id AND price_model = 'cennik'
                        AND valid_from < p_today AND NOT id = ANY (v_before)) THEN
            v_retro := v_retro || (SELECT number FROM contract WHERE id = v_id);
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(v_id, 'cennik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'cennik', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('cennik', v_cnt,
                                    'cennik_spatne', jsonb_build_object('pocet', cardinality(v_retro), 'zmluvy', to_jsonb(v_retro)));

  -- 3. Prolongácia: skončené zmluvy s automatickou prolongáciou a aspoň jedným OOM bez nástupcu a bez pevného konca;
  --    zmluva bez Aktívneho / Pripravovaného OOM prejde do fázy Ukončená a obchodník dostane upozornenie
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number FROM contract k
              WHERE k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL
                AND contract_effective_to(k) < p_today
                AND EXISTS (SELECT 1 FROM contract_oom x
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
                               AND x.valid_from IS NOT NULL AND x.valid_to = contract_effective_to(k))
              ORDER BY k.id LOOP
      BEGIN
        SELECT * INTO v_pr FROM contract_prolong(r.id, p_today);
        IF v_pr.p_result = 'predlzena' THEN
          v_cnt := v_cnt + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'sprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s bola automaticky predĺžená do %s – Servis potvrdí produkt',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        ELSIF v_pr.p_result = 'ukoncena' THEN
          v_ended := v_ended + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'neprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s skončila %s bez prolongácie – nemá aktívne OOM, fáza Ukončená',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'prolongacia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'prolongacia', v_state, v_msg);
    v_cnt := 0;
    v_ended := 0;
  END;
  v_n := v_n || jsonb_build_object('prolongovane', v_cnt, 'ukoncene', v_ended);

  -- 4. Príznaky: „Chýba cena“ v prvom behu roka pre všetky živé zmluvy (kontrola začína 1. 1. bežného roka)
  v_cnt := 0;
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM job_run WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL
                      AND run_date >= date_trunc('year', p_today)::date AND run_date < p_today) THEN
      FOR v_id IN SELECT k.id FROM contract k
                   WHERE k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena')
                     AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= date_trunc('year', p_today)::date)
                     AND NOT k.id = ANY (v_touched)
                   ORDER BY k.id LOOP
        BEGIN
          PERFORM contract_price_missing_refresh(v_id);
          v_cnt := v_cnt + 1;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(v_id, 'priznaky', v_state, v_msg);
        END;
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'priznaky', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('chyba_cena_kontrola', v_cnt);

  -- 5. Upozornenie 4 mesiace pred koncom (firmy a výkup, odpoveď 34): raz na koniec zmluvy, iba ak niektoré
  --    Aktívne alebo Pripravované OOM ešte nemá nadväzujúcu podpísanú zmluvu
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number, k.auto_prolong, contract_effective_to(k) AS end_on FROM contract k
              WHERE k.phase = 'podpisana' AND k.type IN ('dodavka_firma_nn', 'dodavka_firma_vn', 'vykup')
                AND contract_effective_to(k) BETWEEN p_today AND (p_today + interval '4 months')::date
                AND NOT EXISTS (SELECT 1 FROM notification n
                                 WHERE n.contract_id = k.id AND n.kind = 'konci_4_mesiace' AND n.ref_date = contract_effective_to(k))
                AND EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL
                               AND x.valid_to = contract_effective_to(k)
                               AND o.status IN ('aktivne', 'pripravovane')
                               AND (o.supply_to IS NULL OR o.supply_to >= contract_effective_to(k))
                               AND NOT EXISTS (SELECT 1 FROM contract_oom y
                                                WHERE y.oom_id = x.oom_id AND y.grp = x.grp AND y.is_binding
                                                  AND y.contract_id <> k.id AND y.valid_from > x.valid_to))
              ORDER BY k.id LOOP
      BEGIN
        IF notification_add(notification_contract_users(r.id), 'konci_4_mesiace', r.id, NULL, NULL, r.end_on,
                            format('Zmluva %s končí %s – dojednaj novú zmluvu%s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                                   CASE WHEN r.auto_prolong THEN ' (inak sa automaticky predĺži s cenníkom)' ELSE '' END)) > 0 THEN
          v_cnt := v_cnt + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'upozornenia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'upozornenia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('konci_4_mesiace', v_cnt);

  -- 5b. Malý podnik nad 30 MWh (0029): regulovaní zákazníci s objemom nad 30 MWh alebo nesúladom zmluvy / XM Trade.
  --     Zmluvy do denníka; obchodník dostane upozornenie raz za rok.
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT s.company_id, s.message,
                    (SELECT array_agg(DISTINCT k.number ORDER BY k.number)
                       FROM contract k JOIN contract_oom co ON co.contract_id = k.id
                      WHERE k.company_id = s.company_id AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%'
                        AND co.valid_from <= p_today AND (co.valid_to IS NULL OR co.valid_to >= p_today)) AS numbers,
                    (SELECT k.id FROM contract k
                      WHERE k.company_id = s.company_id AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka_firma%'
                        AND k.valid_from <= p_today
                      ORDER BY k.valid_from DESC, k.number LIMIT 1) AS contract_id
               FROM small_business_volume(p_today) s
              WHERE s.state IN ('vyradit', 'nesulad')
              ORDER BY s.company_id LOOP
      BEGIN
        v_cnt := v_cnt + 1;
        v_sb := v_sb || r.numbers;
        IF r.contract_id IS NOT NULL AND NOT EXISTS (
             SELECT 1 FROM notification n JOIN contract k ON k.id = n.contract_id
              WHERE n.kind = 'maly_podnik' AND k.company_id = r.company_id
                AND n.ref_date = date_trunc('year', p_today)::date) THEN
          PERFORM notification_add(notification_contract_users(r.contract_id), 'maly_podnik', r.contract_id, NULL, NULL,
                                   date_trunc('year', p_today)::date,
                                   format('Zmluva %s: %s', (SELECT number FROM contract WHERE id = r.contract_id), r.message));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.contract_id, 'maly_podnik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'maly_podnik', v_state, v_msg);
    v_cnt := 0;
    v_sb := '{}';
  END;
  v_n := v_n || jsonb_build_object('maly_podnik', jsonb_build_object('pocet', v_cnt, 'zmluvy', to_jsonb(v_sb)));

  -- 6. Stav zákazníka: zmluvy zmenené behom a zmluvy, ktorým od posledného behu začala alebo skončila účinnosť
  v_cnt := 0;
  IF crm_setting_on('customer_status_auto') THEN
    BEGIN
      FOR r IN SELECT DISTINCT k.company_id, k.person_id FROM contract k
                WHERE k.id = ANY (v_touched)
                   OR (k.phase = 'podpisana' AND k.valid_from > coalesce(v_last, p_today - 1) AND k.valid_from <= p_today)
                   OR (k.phase = 'podpisana' AND contract_effective_to(k) >= coalesce(v_last, p_today - 1) - 1
                       AND contract_effective_to(k) < p_today) LOOP
        BEGIN
          IF customer_refresh(r.company_id, r.person_id) THEN
            v_cnt := v_cnt + 1;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
        END;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
      v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
      v_cnt := 0;
    END;
  END IF;
  v_n := v_n || jsonb_build_object('zakaznici', v_cnt);

  v_result := v_n || jsonb_build_object('chyby', jsonb_array_length(v_err));
  UPDATE job_run SET finished_at = clock_timestamp(), result = v_result, errors = v_err WHERE id = v_run;
  IF jsonb_array_length(v_err) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT u.id FROM app_user u WHERE u.is_admin AND u.status <> 'deaktivovany'),
                             'nocny_beh_chyba', NULL, NULL, v_run, p_today,
                             format('Nočný beh zmlúv %s: %s chýb (Nastavenia → Nočný beh)',
                                    to_char(p_today, 'FMDD. FMMM. YYYY'), jsonb_array_length(v_err)));
  END IF;
  PERFORM set_config('crm.today', v_prev_today, true);
  PERFORM set_config('app.change_source', v_prev_source, true);
  RETURN v_result;
END;
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION contract_daily_run_at(p_today date) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_run     uuid;
  v_err     jsonb := '[]';
  v_touched uuid[] := '{}';
  v_id      uuid;
  r         record;
  v_ok      boolean;
  v_end     date;
  v_last    date;
  v_state   text;
  v_msg     text;
  v_n       jsonb := '{}';
  v_cnt     integer;
  v_result  jsonb;
  v_pr      record;
  v_ended   integer := 0;
  v_before  uuid[];
  v_retro   text[] := '{}';
  v_prev_today  text := coalesce(current_setting('crm.today', true), '');
  v_prev_source text;
BEGIN
  IF p_today IS NULL THEN
    RAISE EXCEPTION 'contract_daily_run_at: chýba dátum' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT pg_try_advisory_xact_lock(hashtext('crm.contract_daily_run')) THEN
    RETURN jsonb_build_object('bezi', true);
  END IF;
  PERFORM set_config('crm.today', p_today::text, true);   -- crm_today() v spojení vlastníka (ručný beh)
  v_prev_source := crm_as_system(true);
  SELECT max(run_date) INTO v_last FROM job_run
   WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL AND run_date < p_today;
  INSERT INTO job_run (job, run_date, test_date)
  VALUES ('zmluvy', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;

  -- 1. Regulácia: ceny zmlúv na OOM, ktorých zmena regulácie nastala a zmluvy ju ešte nemajú
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT ch.id, ch.oom_id, ch.valid_from FROM oom_price_regulation_change ch
              WHERE ch.contract_applied_at IS NULL AND ch.valid_from <= p_today
              ORDER BY ch.valid_from, ch.id LOOP
      v_ok := true;
      FOR v_id IN SELECT DISTINCT co.contract_id FROM contract_oom co JOIN contract k ON k.id = co.contract_id
                   WHERE co.oom_id = r.oom_id AND k.phase NOT IN ('odmietnuta', 'neuspesna')
                     AND (co.valid_to IS NULL OR co.valid_to >= r.valid_from) LOOP
        BEGIN
          IF contract_sync_checked(v_id) THEN
            PERFORM contract_after_price_change(v_id);
            v_cnt := v_cnt + 1;
            v_touched := v_touched || v_id;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_ok := false;
          v_err := v_err || job_error(v_id, 'regulacia', v_state, v_msg);
        END;
      END LOOP;
      IF v_ok THEN
        UPDATE oom_price_regulation_change SET contract_applied_at = now() WHERE id = r.id;
      END IF;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'regulacia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('regulacia', v_cnt);

  -- 2. Cenník: zmluvy s cenníkovou cenou, ktorej verzia medzitým skončila alebo bola nahradená, a zmluvy s „Chýba cena“.
  --    Nová verzia sa uplatní prvú noc po schválení; cena platná od dátumu v minulosti sa zapíše od toho dátumu
  --    a zmluva ide do zoznamu „cennik_spatne“ v denníku behu (pre Nákup).
  v_cnt := 0;
  BEGIN
    FOR v_id IN SELECT cp.contract_id FROM contract_price cp
                  JOIN price_list_item i ON i.id = cp.price_list_item_id
                  JOIN price_list_version v ON v.id = i.version_id
                 WHERE cp.source = 'import'
                   AND (v.status = 'nahradena' OR (v.valid_to IS NOT NULL AND (cp.valid_to IS NULL OR cp.valid_to > v.valid_to)))
                UNION
                SELECT f.contract_id FROM contract_flag f WHERE f.code = 'chyba_cena' AND f.resolved_at IS NULL
                ORDER BY 1 LOOP
      BEGIN
        v_before := ARRAY(SELECT id FROM contract_price WHERE contract_id = v_id);
        IF contract_sync_checked(v_id) THEN
          PERFORM contract_after_price_change(v_id);
          v_cnt := v_cnt + 1;
          v_touched := v_touched || v_id;
          IF EXISTS (SELECT 1 FROM contract_price WHERE contract_id = v_id AND price_model = 'cennik'
                        AND valid_from < p_today AND NOT id = ANY (v_before)) THEN
            v_retro := v_retro || (SELECT number FROM contract WHERE id = v_id);
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(v_id, 'cennik', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'cennik', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('cennik', v_cnt,
                                    'cennik_spatne', jsonb_build_object('pocet', cardinality(v_retro), 'zmluvy', to_jsonb(v_retro)));

  -- 3. Prolongácia: skončené zmluvy s automatickou prolongáciou a aspoň jedným OOM bez nástupcu a bez pevného konca;
  --    zmluva bez Aktívneho / Pripravovaného OOM prejde do fázy Ukončená a obchodník dostane upozornenie
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number FROM contract k
              WHERE k.auto_prolong AND k.phase = 'podpisana' AND k.valid_to IS NOT NULL
                AND contract_effective_to(k) < p_today
                AND EXISTS (SELECT 1 FROM contract_oom x
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL AND NOT x.end_fixed
                               AND x.valid_from IS NOT NULL AND x.valid_to = contract_effective_to(k))
              ORDER BY k.id LOOP
      BEGIN
        SELECT * INTO v_pr FROM contract_prolong(r.id, p_today);
        IF v_pr.p_result = 'predlzena' THEN
          v_cnt := v_cnt + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'sprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s bola automaticky predĺžená do %s – Servis potvrdí produkt',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        ELSIF v_pr.p_result = 'ukoncena' THEN
          v_ended := v_ended + 1;
          v_touched := v_touched || r.id;
          PERFORM notification_add(notification_contract_users(r.id), 'neprolongovana', r.id, NULL, NULL, v_pr.p_end,
                                   format('Zmluva %s skončila %s bez prolongácie – nemá aktívne OOM, fáza Ukončená',
                                          r.number, to_char(v_pr.p_end, 'FMDD. FMMM. YYYY')));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'prolongacia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'prolongacia', v_state, v_msg);
    v_cnt := 0;
    v_ended := 0;
  END;
  v_n := v_n || jsonb_build_object('prolongovane', v_cnt, 'ukoncene', v_ended);

  -- 4. Príznaky: „Chýba cena“ v prvom behu roka pre všetky živé zmluvy (kontrola začína 1. 1. bežného roka)
  v_cnt := 0;
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM job_run WHERE job = 'zmluvy' AND NOT test_date AND finished_at IS NOT NULL
                      AND run_date >= date_trunc('year', p_today)::date AND run_date < p_today) THEN
      FOR v_id IN SELECT k.id FROM contract k
                   WHERE k.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena')
                     AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= date_trunc('year', p_today)::date)
                     AND NOT k.id = ANY (v_touched)
                   ORDER BY k.id LOOP
        BEGIN
          PERFORM contract_price_missing_refresh(v_id);
          v_cnt := v_cnt + 1;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(v_id, 'priznaky', v_state, v_msg);
        END;
      END LOOP;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'priznaky', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('chyba_cena_kontrola', v_cnt);

  -- 5. Upozornenie 4 mesiace pred koncom (firmy a výkup, odpoveď 34): raz na koniec zmluvy, iba ak niektoré
  --    Aktívne alebo Pripravované OOM ešte nemá nadväzujúcu podpísanú zmluvu
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number, k.auto_prolong, contract_effective_to(k) AS end_on FROM contract k
              WHERE k.phase = 'podpisana' AND k.type IN ('dodavka_firma_nn', 'dodavka_firma_vn', 'vykup')
                AND contract_effective_to(k) BETWEEN p_today AND (p_today + interval '4 months')::date
                AND NOT EXISTS (SELECT 1 FROM notification n
                                 WHERE n.contract_id = k.id AND n.kind = 'konci_4_mesiace' AND n.ref_date = contract_effective_to(k))
                AND EXISTS (SELECT 1 FROM contract_oom x JOIN oom o ON o.id = x.oom_id
                             WHERE x.contract_id = k.id AND x.is_binding AND x.successor_id IS NULL
                               AND x.valid_to = contract_effective_to(k)
                               AND o.status IN ('aktivne', 'pripravovane')
                               AND (o.supply_to IS NULL OR o.supply_to >= contract_effective_to(k))
                               AND NOT EXISTS (SELECT 1 FROM contract_oom y
                                                WHERE y.oom_id = x.oom_id AND y.grp = x.grp AND y.is_binding
                                                  AND y.contract_id <> k.id AND y.valid_from > x.valid_to))
              ORDER BY k.id LOOP
      BEGIN
        IF notification_add(notification_contract_users(r.id), 'konci_4_mesiace', r.id, NULL, NULL, r.end_on,
                            format('Zmluva %s končí %s – dojednaj novú zmluvu%s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                                   CASE WHEN r.auto_prolong THEN ' (inak sa automaticky predĺži s cenníkom)' ELSE '' END)) > 0 THEN
          v_cnt := v_cnt + 1;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.id, 'upozornenia', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'upozornenia', v_state, v_msg);
    v_cnt := 0;
  END;
  v_n := v_n || jsonb_build_object('konci_4_mesiace', v_cnt);

  -- 6. Stav zákazníka: zmluvy zmenené behom a zmluvy, ktorým od posledného behu začala alebo skončila účinnosť
  v_cnt := 0;
  IF crm_setting_on('customer_status_auto') THEN
    BEGIN
      FOR r IN SELECT DISTINCT k.company_id, k.person_id FROM contract k
                WHERE k.id = ANY (v_touched)
                   OR (k.phase = 'podpisana' AND k.valid_from > coalesce(v_last, p_today - 1) AND k.valid_from <= p_today)
                   OR (k.phase = 'podpisana' AND contract_effective_to(k) >= coalesce(v_last, p_today - 1) - 1
                       AND contract_effective_to(k) < p_today) LOOP
        BEGIN
          IF customer_refresh(r.company_id, r.person_id) THEN
            v_cnt := v_cnt + 1;
          END IF;
        EXCEPTION WHEN OTHERS THEN
          GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
          v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
        END;
      END LOOP;
    EXCEPTION WHEN OTHERS THEN
      GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
      v_err := v_err || job_error(NULL, 'zakaznik', v_state, v_msg);
      v_cnt := 0;
    END;
  END IF;
  v_n := v_n || jsonb_build_object('zakaznici', v_cnt);

  v_result := v_n || jsonb_build_object('chyby', jsonb_array_length(v_err));
  UPDATE job_run SET finished_at = clock_timestamp(), result = v_result, errors = v_err WHERE id = v_run;
  IF jsonb_array_length(v_err) > 0 THEN
    PERFORM notification_add(ARRAY(SELECT u.id FROM app_user u WHERE u.is_admin AND u.status <> 'deaktivovany'),
                             'nocny_beh_chyba', NULL, NULL, v_run, p_today,
                             format('Nočný beh zmlúv %s: %s chýb (Nastavenia → Nočný beh)',
                                    to_char(p_today, 'FMDD. FMMM. YYYY'), jsonb_array_length(v_err)));
  END IF;
  PERFORM set_config('crm.today', v_prev_today, true);
  PERFORM set_config('app.change_source', v_prev_source, true);
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION contract_sync_checked(p_contract_id uuid) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_changed boolean := contract_price_list_sync(p_contract_id);
  v_missing text := contract_regulation_pair_missing(p_contract_id);
BEGIN
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION '%', v_missing USING ERRCODE = 'check_violation';
  END IF;
  RETURN v_changed;
END;
$$;

CREATE OR REPLACE FUNCTION contract_price_missing_refresh(p_contract_id uuid) RETURNS text
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  c        contract;
  co       record;
  v_y_from date := date_trunc('year', crm_today())::date;
  v_y_to   date := (date_trunc('year', crm_today()) + interval '1 year - 1 day')::date;
  v_from   date;
  v_to     date;
  v_miss   text[] := '{}';
  v_detail text;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract_id;
  IF c.phase NOT IN ('odmietnuta', 'neuspesna', 'ukoncena') THEN
    FOR co IN
      SELECT x.*, o.eic
        FROM contract_oom x JOIN oom o ON o.id = x.oom_id
       WHERE x.contract_id = c.id
         AND ((c.type::text LIKE 'dodavka%' AND o.type = 'spotreba') OR c.type = 'vykup')
       ORDER BY o.eic
    LOOP
      IF co.valid_from IS NULL THEN
        v_miss := v_miss || format('OOM %s: chýba účinnosť od', co.eic);
        CONTINUE;
      END IF;
      v_from := greatest(co.valid_from, v_y_from);
      v_to := coalesce(co.valid_to, greatest(v_from, v_y_to));
      CONTINUE WHEN v_to < v_from;
      IF NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
                     - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                                  WHERE p.contract_id = c.id AND p.oom_id = co.oom_id AND p.slot = 'komodita'),
                                '{}'::datemultirange)) THEN
        v_miss := v_miss || format('OOM %s: chýba cena komodity (%s – %s)', co.eic,
                                   to_char(v_from, 'FMDD. FMMM. YYYY'), to_char(v_to, 'FMDD. FMMM. YYYY'));
      END IF;
    END LOOP;
    IF c.type = 'viwa' THEN
      IF c.viwa_package IS NULL THEN
        v_miss := v_miss || 'chýba balík VIWA (doplní Servis)'::text;
      ELSIF c.valid_from IS NOT NULL THEN
        v_from := greatest(c.valid_from, v_y_from);
        v_to := coalesce(contract_effective_to(c), greatest(v_from, v_y_to));
        IF v_to >= v_from AND NOT isempty(datemultirange(daterange(v_from, v_to, '[]'))
             - coalesce((SELECT range_agg(daterange(p.valid_from, p.valid_to, '[]')) FROM contract_price p
                          WHERE p.contract_id = c.id AND p.slot = 'viwa_ucet'), '{}'::datemultirange)) THEN
          v_miss := v_miss || 'chýba cena balíka VIWA v cenníku'::text;
        END IF;
      END IF;
    END IF;
  END IF;

  v_detail := nullif(array_to_string(v_miss, '; '), '');
  IF v_detail IS NULL THEN
    UPDATE contract_flag SET resolved_at = now()
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL;
  ELSE
    UPDATE contract_flag SET detail = v_detail
     WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL AND detail IS DISTINCT FROM v_detail;
    IF NOT EXISTS (SELECT 1 FROM contract_flag WHERE contract_id = c.id AND code = 'chyba_cena' AND year IS NULL AND resolved_at IS NULL) THEN
      INSERT INTO contract_flag (contract_id, code, detail) VALUES (c.id, 'chyba_cena', v_detail);
    END IF;
  END IF;
  RETURN v_detail;
END;
$$;

DELETE FROM notification WHERE kind = 'maly_podnik';
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN ('konci_4_mesiace', 'sprolongovana',
  'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba'));

CREATE OR REPLACE FUNCTION contract_import_run(p_org uuid, p_xm jsonb, p_op jsonb, p_save boolean, p_meta jsonb DEFAULT '{}',
                                    p_expected jsonb DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
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
      v_res := contract_import_rows(p_org, p_xm, p_op);
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
    v_res := contract_import_rows(p_org, p_xm, p_op);
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

DROP FUNCTION contract_import_small_business(jsonb);
DROP FUNCTION contract_small_business_over(uuid);
DROP FUNCTION small_business_volume(date, uuid);
DROP FUNCTION mwh_text(numeric);

DROP POLICY contract_flag_update ON contract_flag;
CREATE POLICY contract_flag_update ON contract_flag FOR UPDATE
  USING (EXISTS (SELECT 1 FROM contract k WHERE k.id = contract_id AND crm_contract_editable(k.company_id, k.person_id, k.owner_id)));
DROP TRIGGER trg_resolve_guard ON contract_flag;
DROP FUNCTION contract_flag_resolve_guard();
