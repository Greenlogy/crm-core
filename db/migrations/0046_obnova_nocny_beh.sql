-- migrate:up

-- 0046_obnova_nocny_beh – modul 5, fáza F5, krok 2 (návrh DB časti 2.3, 32.2; zadanie 10 bod 4):
-- - nočný beh zmlúv 4 mesiace pred koncom zmluvy firmy založí obchod Obnova (pipeline podľa typu zmluvy, štádium
--   Príležitosť, zdroj Obnova, predošlá zmluva, OOM zmluvy Aktívne / Pripravované s objemami zo zmluvy, kontakty
--   z predošlého obchodu alebo hlavný kontakt firmy). Ak už existuje bežný otvorený obchod rovnakého druhu s niektorým OOM
--   zmluvy, Obnova sa nezaloží – obchodu sa iba doplní predošlá zmluva. Obchodník dostane namiesto „Končí do 4 mesiacov“
--   jedno upozornenie „Obnova“; bez aktívneho obchodníka a vlastníka zákazníka upozornenie adminom.
-- - nočný beh obchodov: 14 dní po akceptácii OOM akceptovaného variantu, ktoré nie je na žiadnej zmluve obchodu →
--   upozornenie obchodníkovi raz (iba pri zapnutom párovaní).

ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana',
  'potvrdenie_neodoslane', 'zmluva_sparovana', 'zmluva_odparovana', 'predosla_zmluva'));
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena',
  'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba',
  'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve'));

-- Obnova k zmluve (volá nočný beh zmlúv): {deal_id, action} – action zalozena / doplnena / existuje / bez_vlastnika /
-- domacnost / bez_oom
CREATE FUNCTION contract_renewal(p_contract uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c        contract;
  d        deal;
  v_kind   deal_kind;
  v_owner  uuid;
  v_end    date;
  v_pipe   uuid;
  v_stage  uuid;
  v_deal   uuid;
  r        record;
  v_n      integer := 0;
BEGIN
  SELECT * INTO c FROM contract WHERE id = p_contract;
  IF c.company_id IS NULL THEN
    RETURN jsonb_build_object('action', 'domacnost');
  END IF;
  v_kind := contract_deal_kind(c.type);
  -- už otvorená Obnova k tejto zmluve
  SELECT * INTO d FROM deal WHERE previous_contract_id = c.id AND closed_at IS NULL AND source_code = 'obnova';
  IF FOUND THEN
    RETURN jsonb_build_object('deal_id', d.id, 'action', 'existuje');
  END IF;
  -- bežný otvorený obchod rovnakého druhu s niektorým OOM zmluvy: iba doplniť predošlú zmluvu
  SELECT dd.* INTO d FROM deal dd JOIN pipeline p ON p.id = dd.pipeline_id
   WHERE dd.company_id = c.company_id AND dd.closed_at IS NULL AND p.kind = v_kind
     AND EXISTS (SELECT 1 FROM deal_oom x JOIN contract_oom co ON co.oom_id = x.oom_id WHERE x.deal_id = dd.id AND co.contract_id = c.id)
   ORDER BY dd.created_at
   LIMIT 1;
  IF FOUND THEN
    IF d.previous_contract_id IS NULL THEN
      UPDATE deal SET previous_contract_id = c.id WHERE id = d.id;
      INSERT INTO deal_event (deal_id, org_id, kind, user_id, detail)
      VALUES (d.id, d.org_id, 'predosla_zmluva', NULL,
              jsonb_build_object('contract_id', c.id, 'number', c.number, 'text', 'predošlá zmluva doplnená nočným behom'));
    END IF;
    RETURN jsonb_build_object('deal_id', d.id, 'action', 'doplnena');
  END IF;
  -- vlastník: obchodník zmluvy, inak vlastník zákazníka (aktívny, v nearchivovanom tíme)
  SELECT u.id INTO v_owner FROM app_user u JOIN team t ON t.id = u.team_id
   WHERE u.id IN (c.owner_id, (SELECT owner_id FROM company WHERE id = c.company_id)) AND u.status = 'aktivny' AND t.archived_at IS NULL
   ORDER BY (u.id = c.owner_id) DESC NULLS LAST
   LIMIT 1;
  IF v_owner IS NULL THEN
    RETURN jsonb_build_object('action', 'bez_vlastnika');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM contract_oom co JOIN oom o ON o.id = co.oom_id
                  WHERE co.contract_id = c.id AND o.status IN ('aktivne', 'pripravovane')) THEN
    RETURN jsonb_build_object('action', 'bez_oom');
  END IF;
  v_end := contract_effective_to(c);
  SELECT p.id INTO v_pipe FROM pipeline p
   WHERE p.kind = v_kind AND p.archived_at IS NULL AND (p.org_id IS NULL OR p.org_id = c.org_id)
   ORDER BY (p.org_id IS NOT DISTINCT FROM c.org_id) DESC, p.sort_order
   LIMIT 1;
  SELECT s.id INTO v_stage FROM pipeline_stage s WHERE s.pipeline_id = v_pipe AND s.code = 'prilezitost';
  INSERT INTO deal (company_id, pipeline_id, stage_id, name, owner_id, source_code, previous_contract_id, expected_close,
                    supply_start, org_id)
  VALUES (c.company_id, v_pipe, v_stage, 'Obnova – ' || c.number, v_owner, 'obnova', c.id,
          (v_end - interval '1 month')::date, v_end + 1, c.org_id)
  RETURNING id INTO v_deal;
  -- OOM zmluvy (Aktívne / Pripravované) s objemami zo zmluvy; OOM v inom otvorenom obchode rovnakého druhu sa preskočí
  FOR r IN
    SELECT co.oom_id, sum(co.qty_vt_mwh) AS vt, sum(co.qty_nt_mwh) AS nt, max(co.source_power_kw) AS kw, max(o.planned_feed_in_mwh) AS feed
      FROM contract_oom co JOIN oom o ON o.id = co.oom_id
     WHERE co.contract_id = c.id AND o.status IN ('aktivne', 'pripravovane')
     GROUP BY co.oom_id
     ORDER BY co.oom_id
  LOOP
    BEGIN
      INSERT INTO deal_oom (deal_id, oom_id, planned_vt_mwh, planned_nt_mwh, planned_feed_in_mwh, source_power_kw)
      VALUES (v_deal, r.oom_id,
              CASE WHEN v_kind IN ('b2b_vykup', 'green_viwa') THEN NULL ELSE nullif(r.vt, 0) END,
              CASE WHEN v_kind IN ('b2b_vykup', 'green_viwa') THEN NULL ELSE nullif(r.nt, 0) END,
              CASE WHEN v_kind IN ('b2b_vykup', 'green_viwa') THEN r.feed END,
              CASE WHEN v_kind IN ('b2b_vykup', 'green_viwa') THEN r.kw END);
      v_n := v_n + 1;
    EXCEPTION WHEN check_violation OR unique_violation THEN
      NULL;
    END;
  END LOOP;
  -- kontakty: z predošlého obchodu zmluvy, inak hlavný kontakt firmy
  INSERT INTO deal_contact (deal_id, contact_id, roles, is_primary)
  SELECT v_deal, x.contact_id, x.roles, x.is_primary FROM deal_contact x WHERE x.deal_id = c.deal_id;
  IF NOT FOUND THEN
    INSERT INTO deal_contact (deal_id, contact_id, is_primary)
    SELECT v_deal, cc.contact_id, true FROM company_contact cc WHERE cc.company_id = c.company_id AND cc.is_main_contact;
  END IF;
  RETURN jsonb_build_object('deal_id', v_deal, 'action', 'zalozena', 'ooms', v_n);
END;
$$;

REVOKE EXECUTE ON FUNCTION contract_renewal(uuid) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION contract_renewal(uuid) FROM crm_app;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION contract_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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
  v_renew   jsonb;
  v_renewed integer := 0;
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
  --    Aktívne alebo Pripravované OOM ešte nemá nadväzujúcu podpísanú zmluvu.
  --    0046 (F5): pri zmluve firmy nočný beh založí obchod Obnova (alebo bežnému otvorenému obchodu s OOM zmluvy doplní
  --    predošlú zmluvu); obchodník dostane namiesto „Končí do 4 mesiacov“ jedno upozornenie „Obnova“ s odkazom na obchod
  v_cnt := 0;
  BEGIN
    FOR r IN SELECT k.id, k.number, k.auto_prolong, contract_effective_to(k) AS end_on FROM contract k
              WHERE k.phase = 'podpisana' AND k.type IN ('dodavka_firma_nn', 'dodavka_firma_vn', 'vykup')
                AND contract_effective_to(k) BETWEEN p_today AND (p_today + interval '4 months')::date
                AND NOT EXISTS (SELECT 1 FROM notification n
                                 WHERE n.contract_id = k.id AND n.kind IN ('konci_4_mesiace', 'obnova') AND n.ref_date = contract_effective_to(k))
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
        v_renew := contract_renewal(r.id);
        IF v_renew->>'deal_id' IS NOT NULL THEN
          -- obchodník obchodu Obnova (alebo doplneného obchodu): jedno upozornenie „Obnova“ s odkazom na obchod
          INSERT INTO notification (user_id, kind, contract_id, deal_id, ref_date, detail)
          SELECT d.owner_id, 'obnova', r.id, d.id, r.end_on,
                 format('Zmluva %s končí %s – %s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                        CASE v_renew->>'action' WHEN 'zalozena' THEN 'založený obchod Obnova' ELSE 'predošlá zmluva doplnená k otvorenému obchodu' END)
            FROM deal d WHERE d.id = (v_renew->>'deal_id')::uuid;
          IF v_renew->>'action' = 'zalozena' THEN
            v_renewed := v_renewed + 1;
          END IF;
          v_cnt := v_cnt + 1;
        ELSE
          IF v_renew->>'action' = 'bez_vlastnika' THEN
            PERFORM notification_add(ARRAY(SELECT id FROM app_user WHERE is_admin AND status = 'aktivny'), 'obnova', r.id, NULL, NULL, r.end_on,
                                     format('Zmluva %s končí %s – obchod Obnova sa nezaložil: zmluva nemá aktívneho obchodníka ani vlastníka zákazníka',
                                            r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY')));
          END IF;
          IF notification_add(notification_contract_users(r.id), 'konci_4_mesiace', r.id, NULL, NULL, r.end_on,
                              format('Zmluva %s končí %s – dojednaj novú zmluvu%s', r.number, to_char(r.end_on, 'FMDD. FMMM. YYYY'),
                                     CASE WHEN r.auto_prolong THEN ' (inak sa automaticky predĺži s cenníkom)' ELSE '' END)) > 0 THEN
            v_cnt := v_cnt + 1;
          END IF;
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
  v_n := v_n || jsonb_build_object('konci_4_mesiace', v_cnt, 'obnova', v_renewed);

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

CREATE OR REPLACE FUNCTION deal_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_rem  integer := 0;
  v_miss integer := 0;
  v_prev text := crm_as_system(true);
  r      record;
BEGIN
  INSERT INTO job_run (job, run_date, test_date) VALUES ('obchody', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;
  -- deň kroku (dobieha 7 dní, keby beh vypadol); raz pre každý dátum kroku
  FOR r IN
    SELECT d.id, d.owner_id, d.next_step_on FROM deal d
     WHERE d.closed_at IS NULL AND d.next_step_on BETWEEN p_today - 7 AND p_today
       AND d.next_step_notified_on IS DISTINCT FROM d.next_step_on
     ORDER BY d.id
  LOOP
    PERFORM notification_add_deal(ARRAY[r.owner_id], 'dalsi_krok', r.id, NULL, r.next_step_on, 'Ďalší krok obchodu');
    UPDATE deal SET next_step_notified_on = r.next_step_on WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  -- pripomienka platnosti: odoslaná / otvorená ponuka bez FIX (SPOT, VIWA), od 2. pracovného dňa pred koncom platnosti
  FOR r IN
    SELECT o.id FROM offer o
     WHERE o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL
       AND (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date > p_today
       AND p_today >= working_days_before(o.org_id, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date, 2)
       AND NOT EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia', 'cennik'))
       AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('spot', 'viwa'))
       AND NOT EXISTS (SELECT 1 FROM email_message m WHERE m.offer_id = o.id AND m.kind = 'pripomienka_platnosti')
     ORDER BY o.id
  LOOP
    IF email_reminder_draft(r.id) IS NOT NULL THEN
      v_rem := v_rem + 1;
    END IF;
  END LOOP;
  -- 0046 (F5): 14 dní po akceptácii niektoré OOM akceptovaného variantu nie je na žiadnej zmluve obchodu – upozornenie
  -- obchodníkovi raz (iba pri zapnutom párovaní zmlúv s obchodmi)
  IF crm_setting_on('deal_matching') THEN
    FOR r IN
      SELECT d.id, d.owner_id, d.name,
             (SELECT count(DISTINCT i.oom_id) FROM offer_item i
               WHERE i.variant_id = d.accepted_variant_id AND i.oom_id IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM contract_oom ko JOIN contract k ON k.id = ko.contract_id
                                  WHERE k.deal_id = d.id AND ko.oom_id = i.oom_id)) AS missing
        FROM deal d
        JOIN pipeline_stage s ON s.id = d.stage_id
        JOIN LATERAL (SELECT max(a.accepted_at) AS accepted_at FROM offer_acceptance a JOIN offer o ON o.id = a.offer_id
                       WHERE o.deal_id = d.id AND a.variant_id = d.accepted_variant_id AND a.revoked_at IS NULL) a ON true
       WHERE d.accepted_variant_id IS NOT NULL AND s.code IN ('akceptacia', 'vyhrane')
         AND a.accepted_at IS NOT NULL AND (a.accepted_at AT TIME ZONE 'Europe/Bratislava')::date + 14 <= p_today
         AND NOT EXISTS (SELECT 1 FROM notification n WHERE n.deal_id = d.id AND n.kind = 'chyba_oom_na_zmluve')
       ORDER BY d.id
    LOOP
      IF r.missing > 0 THEN
        PERFORM notification_add_deal(ARRAY[r.owner_id], 'chyba_oom_na_zmluve', r.id, NULL, p_today,
          format('Obchod %s: %s OOM z akceptovanej ponuky nie je ani 14 dní po akceptácii na zmluve', r.name, r.missing));
        v_miss := v_miss + 1;
      END IF;
    END LOOP;
  END IF;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem, 'chyba_oom_na_zmluve', v_miss) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem, 'chyba_oom_na_zmluve', v_miss);
END;
$$;

-- migrate:down

CREATE OR REPLACE FUNCTION contract_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
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

CREATE OR REPLACE FUNCTION deal_daily_run_at(p_today date) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_temp'
    AS $$
DECLARE
  v_run  uuid;
  v_n    integer := 0;
  v_rem  integer := 0;
  v_prev text := crm_as_system(true);
  r      record;
BEGIN
  INSERT INTO job_run (job, run_date, test_date) VALUES ('obchody', p_today, p_today <> (now() AT TIME ZONE 'Europe/Bratislava')::date)
  RETURNING id INTO v_run;
  -- deň kroku (dobieha 7 dní, keby beh vypadol); raz pre každý dátum kroku
  FOR r IN
    SELECT d.id, d.owner_id, d.next_step_on FROM deal d
     WHERE d.closed_at IS NULL AND d.next_step_on BETWEEN p_today - 7 AND p_today
       AND d.next_step_notified_on IS DISTINCT FROM d.next_step_on
     ORDER BY d.id
  LOOP
    PERFORM notification_add_deal(ARRAY[r.owner_id], 'dalsi_krok', r.id, NULL, r.next_step_on, 'Ďalší krok obchodu');
    UPDATE deal SET next_step_notified_on = r.next_step_on WHERE id = r.id;
    v_n := v_n + 1;
  END LOOP;
  -- pripomienka platnosti: odoslaná / otvorená ponuka bez FIX (SPOT, VIWA), od 2. pracovného dňa pred koncom platnosti
  FOR r IN
    SELECT o.id FROM offer o
     WHERE o.status IN ('odoslana', 'otvorena') AND o.valid_until IS NOT NULL
       AND (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date > p_today
       AND p_today >= working_days_before(o.org_id, (o.valid_until AT TIME ZONE 'Europe/Bratislava')::date, 2)
       AND NOT EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia', 'cennik'))
       AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('spot', 'viwa'))
       AND NOT EXISTS (SELECT 1 FROM email_message m WHERE m.offer_id = o.id AND m.kind = 'pripomienka_platnosti')
     ORDER BY o.id
  LOOP
    IF email_reminder_draft(r.id) IS NOT NULL THEN
      v_rem := v_rem + 1;
    END IF;
  END LOOP;
  UPDATE job_run SET finished_at = now(), result = jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem) WHERE id = v_run;
  PERFORM set_config('app.change_source', v_prev, true);
  RETURN jsonb_build_object('dalsi_krok', v_n, 'pripomienky', v_rem);
END;
$$;

DROP FUNCTION contract_renewal(uuid);
DELETE FROM notification WHERE kind IN ('obnova', 'chyba_oom_na_zmluve');
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind IN (
  'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
  'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie',
  'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena',
  'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba',
  'nesparovana_zmluva', 'cena_ina_ako_v_ponuke'));
DELETE FROM deal_event WHERE kind = 'predosla_zmluva';
ALTER TABLE deal_event DROP CONSTRAINT deal_event_kind_check;
ALTER TABLE deal_event ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
  'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane', 'oom_zrusene', 'oom_nezrusene',
  'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik', 'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana',
  'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost', 'schvalenie_ziadost', 'schvalenie_rozhodnutie',
  'ponuka_akceptovana', 'ponuka_zablokovana', 'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana',
  'potvrdenie_neodoslane', 'zmluva_sparovana', 'zmluva_odparovana'));
