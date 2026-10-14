-- migrate:up

-- 0030_objem_xm – modul 4 (Peter, 14. 10. 2026): upozornenie, ak sa objem zmluvy (zmluvné množstvo z Office portálu)
-- líši od plánovanej spotreby OOM z XM Trade o viac ako 5 %. Bilancia a pridaná hodnota (základ provízie) ostávajú
-- na zmluvnom množstve; CRM iba upozorní obchodníka a schvaľovateľov cien (aj CEO) – nočný beh, import, karta, filter.
-- Cockpit (pôvodne 0030) bude 0031.

-- Porovnanie po zmluve k dňu p_on: podpísané zmluvy o dodávke, ktoré k dňu neskončili; OOM spotreby, ktorých obdobie
-- v zmluve k dňu neskončilo. Zmluva = Σ zmluvného množstva VT + NT, XM Trade = Σ plánovanej spotreby VT + NT tých istých
-- OOM; pri zmluve kratšej ako 12 mesiacov (množstvo za obdobie) XM Trade × mesiace / 12. Rozdiel = |zmluva − XM| / XM;
-- nad 5 % = over. Ak pri niektorom OOM plánovaná spotreba chýba (alebo je 0), zmluva sa neporovnáva (xm_missing).
CREATE FUNCTION contract_volume_diff(p_on date, p_contract_id uuid DEFAULT NULL)
RETURNS TABLE (contract_id uuid, contract_mwh numeric, xm_mwh numeric, diff_pct numeric, months integer,
               oom_count integer, oom_over integer, xm_missing integer, over boolean, message text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  WITH k AS (
    SELECT k.id, least(12, CASE WHEN contract_effective_to(k) IS NULL OR k.valid_from IS NULL THEN 12
                                ELSE ((extract(year FROM contract_effective_to(k)) - extract(year FROM k.valid_from)) * 12
                                      + extract(month FROM contract_effective_to(k)) - extract(month FROM k.valid_from) + 1)::int END) AS months
      FROM contract k
     WHERE (p_contract_id IS NULL OR k.id = p_contract_id)
       AND k.phase = 'podpisana' AND k.type::text LIKE 'dodavka%'
       AND (contract_effective_to(k) IS NULL OR contract_effective_to(k) >= p_on)
  ), r AS (
    SELECT k.id, k.months, co.qty_vt_mwh + co.qty_nt_mwh AS qty,
           CASE WHEN coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0) > 0
                THEN (coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0)) * k.months / 12 END AS xm
      FROM k
      JOIN contract_oom co ON co.contract_id = k.id
      JOIN oom o ON o.id = co.oom_id
     WHERE o.type = 'spotreba' AND co.valid_from IS NOT NULL AND (co.valid_to IS NULL OR co.valid_to >= p_on)
  ), s AS (
    SELECT r.id, max(r.months) AS months, sum(r.qty) AS contract_mwh,
           CASE WHEN bool_and(r.xm IS NOT NULL) THEN sum(r.xm) END AS xm_mwh,
           count(*)::int AS oom_count,
           (count(*) FILTER (WHERE r.xm IS NOT NULL AND abs(r.qty - r.xm) > 0.05 * r.xm))::int AS oom_over,
           (count(*) FILTER (WHERE r.xm IS NULL))::int AS xm_missing
      FROM r GROUP BY r.id
  )
  SELECT s.id, s.contract_mwh, round(s.xm_mwh, 3),
         CASE WHEN s.xm_mwh > 0 THEN round((s.contract_mwh - s.xm_mwh) / s.xm_mwh * 100, 1) END,
         s.months, s.oom_count, s.oom_over, s.xm_missing,
         coalesce(s.xm_mwh > 0 AND abs(s.contract_mwh - s.xm_mwh) > 0.05 * s.xm_mwh, false),
         CASE WHEN s.xm_mwh IS NULL THEN format('XM Trade bez plánovanej spotreby pri %s z %s OOM – objem sa neporovnáva.', s.xm_missing, s.oom_count)
              ELSE format('Objem podľa zmluvy %s MWh, podľa XM Trade %s MWh%s (%s%s %%)%s – %s',
                          mwh_text(s.contract_mwh), mwh_text(s.xm_mwh),
                          CASE WHEN s.months < 12 THEN format(' za %s mesiacov', s.months) ELSE '' END,
                          CASE WHEN s.contract_mwh >= s.xm_mwh THEN '+' ELSE '−' END,
                          replace(abs(round((s.contract_mwh - s.xm_mwh) / s.xm_mwh * 100, 1))::text, '.', ','),
                          CASE WHEN s.oom_count > 1 AND s.oom_over > 0 THEN format(', rozdiel pri %s z %s OOM', s.oom_over, s.oom_count) ELSE '' END,
                          CASE WHEN abs(s.contract_mwh - s.xm_mwh) > 0.05 * s.xm_mwh
                               THEN 'rozdiel nad 5 %, overte zmluvné množstvo (ovplyvňuje pridanú hodnotu a províziu).'
                               ELSE 'v tolerancii 5 %.' END)
         END
    FROM s
$$;
COMMENT ON FUNCTION contract_volume_diff(date, uuid) IS
  'objem zmluvy (Office portal) vs. plánovaná spotreba OOM (XM Trade) k dňu; over = rozdiel nad 5 %; iba upozornenie';

ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN ('konci_4_mesiace', 'sprolongovana',
  'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm'));

-- Import zmlúv: upozornenie riadku aj pri rozdiele objemu zmluvy a XM Trade nad 5 %
CREATE OR REPLACE FUNCTION contract_import_small_business(p_res jsonb) RETURNS jsonb
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
    -- objem zmluvy vs. XM Trade nad 5 % (0030)
    v_msg := NULL;
    IF x ->> 'contract_id' IS NOT NULL THEN
      SELECT d.message INTO v_msg
        FROM contract k, contract_volume_diff(greatest(crm_today(), coalesce(k.valid_from, crm_today())), k.id) d
       WHERE k.id = (x ->> 'contract_id')::uuid AND d.over;
    END IF;
    IF v_msg IS NOT NULL THEN
      x := jsonb_set(x, '{warnings}', coalesce(x -> 'warnings', '[]') || to_jsonb(v_msg));
    END IF;
    v_out := v_out || x;
  END LOOP;
  RETURN CASE WHEN p_res ? 'contracts' THEN jsonb_set(p_res, '{contracts}', v_out) ELSE p_res END;
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
  v_vol     text[] := '{}';
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

  -- 5c. Objem zmluvy vs. XM Trade (0030): rozdiel nad 5 % – zmluvy do denníka; upozornenie obchodníkovi a schvaľovateľom
  --     cien (aj CEO) raz, znova iba pri zmene niektorého z objemov (iný text)
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT d.contract_id, d.message, k.number, k.org_id
               FROM contract_volume_diff(p_today) d JOIN contract k ON k.id = d.contract_id
              WHERE d.over
              ORDER BY k.number LOOP
      BEGIN
        v_cnt := v_cnt + 1;
        v_vol := v_vol || r.number;
        IF NOT EXISTS (SELECT 1 FROM notification n
                        WHERE n.contract_id = r.contract_id AND n.kind = 'objem_xm' AND n.detail = format('Zmluva %s: %s', r.number, r.message)) THEN
          PERFORM notification_add(notification_contract_users(r.contract_id) || notification_approvers(r.org_id, true), 'objem_xm',
                                   r.contract_id, NULL, NULL, p_today, format('Zmluva %s: %s', r.number, r.message));
        END IF;
      EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
        v_err := v_err || job_error(r.contract_id, 'objem_xm', v_state, v_msg);
      END;
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    GET STACKED DIAGNOSTICS v_state = RETURNED_SQLSTATE, v_msg = MESSAGE_TEXT;
    v_err := v_err || job_error(NULL, 'objem_xm', v_state, v_msg);
    v_cnt := 0;
    v_vol := '{}';
  END;
  v_n := v_n || jsonb_build_object('objem_xm', jsonb_build_object('pocet', v_cnt, 'zmluvy', to_jsonb(v_vol)));

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

CREATE OR REPLACE FUNCTION contract_import_small_business(p_res jsonb) RETURNS jsonb
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

DELETE FROM notification WHERE kind = 'objem_xm';
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN ('konci_4_mesiace', 'sprolongovana',
  'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik'));

DROP FUNCTION contract_volume_diff(date, uuid);
