-- migrate:up

-- 0054_provizie_zamky – modul 5, F7 krok 1b (Peter 17. 10. 2026, body A, B a odpovede 1, 2 k 0053):
-- A. Poradie zámkov pri súbehu (hromadné párovanie z importu, nočný prepočet, zmena štádia, uplatnenie, zrušenie listu):
--    - každý zápis provízie obchodu je pod zámkom obchodu = riadok obchodu (SELECT … FOR NO KEY UPDATE; ten istý zámok berie
--      párovanie zmluvy a zmena štádia) a berie sa VŽDY PRED riadkami provízií; viac obchodov naraz (uplatnenie, zrušenie
--      listu) zamyká v poradí id obchodu; jeden druh zámku – nie advisory, ktorý sa s riadkom obchodu (cudzí kľúč) križoval;
--    - zmeny bilancie zmluvy (import cien a OOM, snímka ku dňu podpisu, fáza, obdobie) províziu neprepočítavajú v tej istej
--      transakcii, iba zaradia obchod do fronty commission_queue (bez zámkov) – import teda provízie nezamyká vôbec;
--    - frontu a nočný prepočet spracúva beh na pozadí v poradí id obchodu so SKIP LOCKED: obchod, ktorý práve
--      drží iná transakcia, preskočí (nikdy nečaká, preto nemôže byť v kruhu čakania);
--    - štrukturálne zmeny (spárovanie / zrušenie spárovania zmluvy, štádium) prepočítajú hneď ako doteraz.
--    Pred uplatnením sa fronta vybraných obchodov dokončí (suma listu je vždy aktuálna).
-- B. Interné funkcie (jadro bilancie, prepočet, fronta, zámky) nespustí crm_app ani crm_public (test P11).
-- 1. Príznak „vidí všetky provízie“ mení iba admin (spúšťač; zmena je v audite používateľa).
-- 2. Neúplný základ: dôvod „chýba cena pre obchodníka k DD.MM.RRRR (zmluva …, rok …)“ a upozornenie adminom.

CREATE TABLE commission_queue (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  deal_id    uuid NOT NULL,              -- bez cudzieho kľúča: vloženie nesmie zamykať riadok obchodu
  created_at timestamptz NOT NULL DEFAULT now()
);
COMMENT ON TABLE commission_queue IS 'obchody na prepočet provízie po zmene bilancie zmluvy (0054); spracuje commission_queue_run na pozadí alebo uplatnenie; bez auditu';
CREATE INDEX commission_queue_deal_idx ON commission_queue (deal_id, id);
ALTER TABLE commission_queue ENABLE ROW LEVEL SECURITY;   -- bez politiky: aplikácia nevidí nič

-- zámok obchodu pre provízie: riadok obchodu FOR NO KEY UPDATE (nekoliduje s kontrolou cudzieho kľúča provízie);
-- p_wait = false: obsadený obchod nečaká (SKIP LOCKED) a vráti false
CREATE FUNCTION commission_lock_deal(p_deal uuid, p_wait boolean) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF p_wait THEN
    PERFORM 1 FROM deal WHERE id = p_deal FOR NO KEY UPDATE;
  ELSE
    PERFORM 1 FROM deal WHERE id = p_deal FOR NO KEY UPDATE SKIP LOCKED;
  END IF;
  RETURN FOUND;
END;
$$;

-- zámky viacerých obchodov v poradí id (uplatnenie, zrušenie listu)
CREATE FUNCTION commission_lock_deals(p_deals uuid[]) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  PERFORM 1 FROM deal WHERE id = ANY (p_deals) ORDER BY id FOR NO KEY UPDATE;
END;
$$;

-- fronta na pozadí: v poradí obchodov, bez čakania (obsadený obchod ostane vo fronte na ďalší beh)
CREATE FUNCTION commission_queue_run() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d      uuid;
  v_max  bigint;
  v_done integer := 0;
  v_skip integer := 0;
BEGIN
  PERFORM crm_background_only();
  FOR d IN SELECT DISTINCT deal_id FROM commission_queue ORDER BY deal_id LOOP
    IF NOT commission_lock_deal(d, false) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;
    SELECT max(id) INTO v_max FROM commission_queue WHERE deal_id = d;
    PERFORM commission_sync(d, false);
    DELETE FROM commission_queue WHERE deal_id = d AND id <= v_max;
    v_done := v_done + 1;
  END LOOP;
  RETURN jsonb_build_object('fronta_spracovane', v_done, 'fronta_preskocene', v_skip);
END;
$$;

CREATE OR REPLACE FUNCTION commission_deal_base(p_deal uuid) RETURNS TABLE (base_eur numeric, volume_mwh numeric, duration_years smallint, contracts integer, missing text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c       contract;
  v_from  date;
  v_until date;
  y       integer;
  r       record;
  v_base  numeric := 0;
  v_vol   numeric := 0;
  v_dur   integer := 0;
  v_open  boolean := false;
  v_n     integer := 0;
  v_miss  text[] := '{}';
BEGIN
  FOR c IN SELECT * FROM contract k
            WHERE k.deal_id = p_deal AND k.deal_match IN ('auto', 'rucne') AND k.signed_on IS NOT NULL
              AND k.phase NOT IN ('odmietnuta', 'neuspesna')
            ORDER BY k.number LOOP
    SELECT coalesce(min(x.valid_from), c.valid_from) INTO v_from FROM contract_oom x WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL;
    IF v_from IS NULL THEN
      v_miss := v_miss || format('zmluva %s bez začiatku dodávky', c.number);
      CONTINUE;
    END IF;
    v_n := v_n + 1;
    IF c.valid_to IS NULL THEN
      v_open := true;
      v_until := (v_from + interval '12 months' - interval '1 day')::date;
    ELSE
      v_until := greatest(c.valid_to, v_from);
      v_dur := greatest(v_dur, ceil(((extract(year FROM v_until) * 12 + extract(month FROM v_until))
                                     - (extract(year FROM v_from) * 12 + extract(month FROM v_from)) + 1) / 12.0)::integer);
    END IF;
    FOR y IN extract(year FROM v_from)::integer .. extract(year FROM v_until)::integer LOOP
      SELECT * INTO r FROM contract_year_calc_core(c.id, y, v_until);
      IF r.months > 0 AND r.added_value_eur IS NULL THEN
        -- 0054: dôvod pre obrazovku 41 a upozornenie adminom („chýba cena pre obchodníka k DD.MM.RRRR“)
        v_miss := v_miss || format('chýba %s k %s (zmluva %s, rok %s)', coalesce(r.missing, 'vstup výpočtu'),
                                   to_char(c.signed_on, 'DD.MM.YYYY'), c.number, y);
      END IF;
      v_base := v_base + coalesce(r.added_value_eur, 0);
      v_vol := v_vol + coalesce(r.volume_mwh, 0);
    END LOOP;
  END LOOP;
  RETURN QUERY SELECT round(v_base, 2), round(v_vol, 3),
                      CASE WHEN v_open OR v_dur = 0 THEN NULL ELSE v_dur END::smallint, v_n,
                      nullif(array_to_string(v_miss, '; '), '');
END;
$$;

CREATE OR REPLACE FUNCTION commission_sync(p_deal uuid, p_structural boolean) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d         deal;
  v_won     boolean;
  v_claimed numeric;
  v_hasclm  boolean;
  p         commission;
  v_ref     commission;
  v_user    uuid;
  v_pct     numeric;
  v_wonon   date;
  v_from    date;
  v_legacy  uuid;
  b         record;
  v_target  numeric;
  v_diff    numeric;
  v_n       integer;
BEGIN
  -- 0054: zámok obchodu = riadok obchodu (FOR NO KEY UPDATE), vždy pred riadkami provízií; súbežné prepočty po sebe
  SELECT * INTO d FROM deal WHERE id = p_deal FOR NO KEY UPDATE;
  IF d.id IS NULL THEN
    RETURN false;
  END IF;
  v_won := (SELECT s.code FROM pipeline_stage s WHERE s.id = d.stage_id) = 'vyhrane';
  SELECT coalesce(sum(amount_eur), 0), count(*) > 0 INTO v_claimed, v_hasclm
    FROM commission WHERE deal_id = p_deal AND status = 'uplatnena';
  IF v_hasclm AND NOT p_structural THEN
    RETURN false;   -- odpoveď 1: po uplatnení iba štrukturálne zmeny
  END IF;
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  -- vlastník a percento: čakajúca položka, inak posledná nezrušená (preradenie platí aj pre budúce vyrovnania)
  IF p.id IS NOT NULL THEN
    v_ref := p;
  ELSE
    SELECT * INTO v_ref FROM commission WHERE deal_id = p_deal AND status <> 'zrusena' ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_ref.id IS NULL THEN
    -- vznik: Vyhraté, od dátumu prechodu, vlastník počíta provízie, bez provízie zo Sales portálu
    IF NOT v_won OR d.closed_at IS NULL THEN
      RETURN false;
    END IF;
    v_wonon := crm_local_date(d.closed_at);
    v_from := (SELECT (value #>> '{}')::date FROM app_setting WHERE key = 'commission_crm_from');
    IF v_from IS NULL OR v_wonon < v_from THEN
      RETURN false;
    END IF;
    IF NOT coalesce((SELECT commission_enabled FROM app_user WHERE id = d.owner_id), false) THEN
      RETURN false;
    END IF;
    v_legacy := commission_legacy_match(p_deal);
    IF v_legacy IS NOT NULL AND NOT EXISTS (SELECT 1 FROM commission_legacy_override WHERE deal_id = p_deal) THEN
      IF NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'provizia_duplicita' AND deal_id = p_deal) THEN
        PERFORM commission_notify_admins(d.org_id, 'provizia_duplicita', p_deal,
          'Obchod má províziu zo Sales portálu – provízia z CRM nevznikla. Ak ide o iný obchod, povoľte ju.');
      END IF;
      RETURN false;
    END IF;
    v_user := d.owner_id;
    v_pct := user_commission_pct(d.owner_id, v_wonon);
  ELSE
    v_user := v_ref.user_id;
    v_pct := v_ref.pct;
    v_wonon := CASE WHEN v_won AND d.closed_at IS NOT NULL THEN crm_local_date(d.closed_at) ELSE v_ref.won_at END;
  END IF;

  SELECT * INTO b FROM commission_deal_base(p_deal);
  -- 0054: neúplný základ blokuje uplatnenie – admini dostanú upozornenie (raz pre ten istý dôvod)
  IF b.missing IS NOT NULL AND v_won
     AND NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'provizia_chyba_cena' AND deal_id = p_deal AND detail = b.missing) THEN
    PERFORM commission_notify_admins(d.org_id, 'provizia_chyba_cena', p_deal, b.missing);
  END IF;
  v_target := CASE WHEN v_won THEN round(greatest(b.base_eur, 0) * v_pct / 100, 2) ELSE 0 END;
  v_diff := v_target - v_claimed;

  IF p.id IS NOT NULL THEN
    IF (NOT v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff = 0) THEN
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE id = p.id;
      RETURN true;
    END IF;
    UPDATE commission
       SET amount_eur = v_diff, target_eur = v_target, base_eur = b.base_eur, base_missing = b.missing,
           volume_mwh = b.volume_mwh, duration_years = b.duration_years, won_at = v_wonon, recalculated_at = now()
     WHERE id = p.id
       AND (amount_eur, target_eur, base_eur, base_missing, volume_mwh, duration_years, won_at)
           IS DISTINCT FROM (v_diff, v_target, b.base_eur, b.missing, b.volume_mwh, b.duration_years, v_wonon);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n > 0;
  END IF;

  IF (v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff <> 0) THEN
    INSERT INTO commission (org_id, deal_id, user_id, kind, status, won_at, duration_years, volume_mwh, base_eur, base_missing,
                            pct, target_eur, amount_eur, recalculated_at)
    VALUES (d.org_id, p_deal, v_user, CASE WHEN v_hasclm THEN 'vyrovnanie' ELSE 'provizia' END, 'caka', v_wonon,
            b.duration_years, b.volume_mwh, b.base_eur, b.missing, v_pct, v_target, v_diff, now());
    IF v_hasclm THEN
      INSERT INTO notification (user_id, kind, deal_id, detail)
      VALUES (v_user, 'provizia_vyrovnanie', p_deal,
              'Vyrovnanie už uplatnenej provízie po zmene obchodu – nová čakajúca položka.');
    END IF;
    RETURN true;
  END IF;
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION commission_on_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r_new jsonb := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END;
  r_old jsonb := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END;
  v_new uuid;
  v_old uuid;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'deal' THEN
      PERFORM commission_sync((r_new->>'id')::uuid, true);
    WHEN 'contract' THEN
      v_new := (r_new->>'deal_id')::uuid;
      v_old := (r_old->>'deal_id')::uuid;
      IF v_old IS DISTINCT FROM v_new THEN
        IF v_old IS NOT NULL THEN
          PERFORM commission_sync(v_old, true);
        END IF;
        IF v_new IS NOT NULL THEN
          PERFORM commission_sync(v_new, true);
        END IF;
      ELSIF v_new IS NOT NULL THEN
        INSERT INTO commission_queue (deal_id) VALUES (v_new);   -- 0054: bilancia → fronta
      END IF;
    ELSE   -- contract_oom, contract_price, contract_year_basis: bilancia zmluvy
      SELECT k.deal_id INTO v_new FROM contract k WHERE k.id = (coalesce(r_new, r_old)->>'contract_id')::uuid;
      IF v_new IS NOT NULL THEN
        INSERT INTO commission_queue (deal_id) VALUES (v_new);   -- 0054: bilancia → fronta
      END IF;
  END CASE;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION commission_daily() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_all  integer := 0;
  v_diff integer := 0;
  v_skip integer := 0;
  r      record;
  v_res  jsonb;
BEGIN
  PERFORM crm_background_only();
  PERFORM commission_queue_run();
  -- 0054: v poradí obchodov a bez čakania – obchod, ktorý práve prepočítava iná transakcia, sa preskočí (prepočíta ho ona)
  FOR r IN SELECT x.id FROM (SELECT d.id FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE s.code = 'vyhrane'
                             UNION
                             SELECT c.deal_id FROM commission c WHERE c.status = 'caka' AND c.deal_id IS NOT NULL) x
            ORDER BY x.id LOOP
    v_all := v_all + 1;
    IF NOT commission_lock_deal(r.id, false) THEN
      v_skip := v_skip + 1;
      CONTINUE;
    END IF;
    IF commission_sync(r.id, false) THEN
      v_diff := v_diff + 1;
    END IF;
  END LOOP;
  v_res := jsonb_build_object('provizie_prepocitane', v_all, 'provizie_zmena', v_diff, 'provizie_preskocene', v_skip);
  UPDATE job_run SET result = result || v_res
   WHERE id = (SELECT id FROM job_run WHERE job = 'obchody' AND run_date = crm_today() ORDER BY started_at DESC LIMIT 1);
  RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION commission_claim_create(p_user uuid, p_ids uuid[]) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me    uuid := crm_active_user_id();
  v_org   uuid;
  v_n     integer;
  v_total numeric;
  v_year  integer := extract(year FROM crm_today())::integer;
  v_no    text;
  v_claim uuid;
  v_cc    uuid[];
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Uplatniť províziu môže iba prihlásený používateľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user IS DISTINCT FROM v_me AND NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu za iného obchodníka uplatní iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user = v_me AND NOT crm_is_admin() AND crm_scope('provizie', 'view') = 'nic' THEN
    RAISE EXCEPTION 'Nemáte právo na provízie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF coalesce(cardinality(p_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Vyberte aspoň jednu províziu.' USING ERRCODE = 'check_violation';
  END IF;
  -- 0054: najprv zámky obchodov (v poradí), dokončenie prepočtov z fronty, až potom riadky provízií
  PERFORM commission_lock_deals(ARRAY(SELECT DISTINCT deal_id FROM commission WHERE id = ANY (p_ids) AND deal_id IS NOT NULL));
  PERFORM commission_sync(x.deal_id, false)
     FROM (SELECT DISTINCT q.deal_id FROM commission_queue q JOIN commission c ON c.deal_id = q.deal_id WHERE c.id = ANY (p_ids)
           ORDER BY q.deal_id) x;
  DELETE FROM commission_queue q USING commission c WHERE c.id = ANY (p_ids) AND q.deal_id = c.deal_id;
  PERFORM 1 FROM commission WHERE id = ANY (p_ids) ORDER BY id FOR UPDATE;
  SELECT count(*), min(org_id::text)::uuid, sum(amount_eur) INTO v_n, v_org, v_total FROM commission WHERE id = ANY (p_ids);
  IF v_n <> (SELECT count(DISTINCT x) FROM unnest(p_ids) x) THEN
    RAISE EXCEPTION 'Niektorá provízia neexistuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND (status <> 'caka' OR user_id <> p_user OR org_id <> v_org)) THEN
    RAISE EXCEPTION 'Uplatniť sa dajú iba čakajúce provízie jedného obchodníka v jednej spoločnosti.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Spoločnosť provízie nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND base_missing IS NOT NULL) THEN
    RAISE EXCEPTION 'Provízia s neúplným základom (chýba cena) sa nedá uplatniť – doplňte ceny.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_total < 0 OR NOT EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND amount_eur > 0) THEN
    RAISE EXCEPTION 'Súčet listu musí byť aspoň 0 € a list musí obsahovať kladnú províziu (záporné vyrovnanie sa samostatne neuplatňuje).'
      USING ERRCODE = 'check_violation';
  END IF;

  v_no := format('CMSN-%s-%s', v_year, lpad(doc_number_next(v_org, 'provizny_list', v_year)::text, 4, '0'));
  INSERT INTO commission_claim (org_id, number, user_id, total_eur, by_duration, created_by)
  SELECT v_org, v_no, p_user, v_total,
         coalesce((SELECT jsonb_object_agg(k, s) FROM (SELECT coalesce(duration_years::text, 'neurcito') AS k, sum(amount_eur) AS s
                                                        FROM commission WHERE id = ANY (p_ids) GROUP BY 1) z), '{}'),
         v_me
  RETURNING id INTO v_claim;
  UPDATE commission SET status = 'uplatnena', claim_id = v_claim WHERE id = ANY (p_ids);

  -- upozornenia: obchodníkovi, ak uplatnil admin; príjemcom kópie (bez súm – nemusia vidieť všetky provízie)
  IF p_user <> v_me THEN
    INSERT INTO notification (user_id, kind, commission_claim_id, detail)
    VALUES (p_user, 'provizny_list', v_claim, format('Provízny list %s uplatnil za vás %s.', v_no, crm_user_name(v_me)));
  END IF;
  SELECT coalesce(array_agg(x::uuid), '{}') INTO v_cc
    FROM jsonb_array_elements_text(coalesce((SELECT value FROM app_setting WHERE key = 'commission_claim_cc'), '[]')) x;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  SELECT u.id, 'provizny_list', v_claim, format('Nový provízny list %s – %s.', v_no, crm_user_name(p_user))
    FROM app_user u
   WHERE u.id = ANY (v_cc) AND u.id <> p_user AND u.status = 'aktivny' AND crm_user_sees_org(u.id, v_org);
  RETURN v_claim;
END;
$$;

CREATE OR REPLACE FUNCTION commission_claim_void(p_claim uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k commission_claim;
  r record;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Provízny list zruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod zrušenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  -- 0054: najprv zámky obchodov listu (v poradí), potom list a provízie
  PERFORM commission_lock_deals(ARRAY(SELECT DISTINCT deal_id FROM commission WHERE claim_id = p_claim AND deal_id IS NOT NULL));
  SELECT * INTO k FROM commission_claim WHERE id = p_claim FOR UPDATE;
  IF k.id IS NULL OR NOT k.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Provízny list neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF k.voided_at IS NOT NULL THEN
    RAISE EXCEPTION 'Provízny list je už zrušený.' USING ERRCODE = 'check_violation';
  END IF;
  IF k.source = 'sales_portal' THEN
    RAISE EXCEPTION 'Provízny list zo Sales portálu je iba na čítanie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE commission_claim SET voided_at = now(), voided_by = crm_active_user_id(), void_reason = btrim(p_reason) WHERE id = k.id;
  FOR r IN SELECT id, deal_id FROM commission WHERE claim_id = k.id ORDER BY id LOOP
    IF r.deal_id IS NOT NULL THEN
      -- najviac jedna čakajúca na obchod: nová čakajúca položka (vyrovnanie) sa zruší a prepočet ju zahrnie
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE deal_id = r.deal_id AND status = 'caka';
    END IF;
    UPDATE commission SET status = 'caka', claim_id = NULL WHERE id = r.id;
    IF r.deal_id IS NOT NULL THEN
      PERFORM commission_sync(r.deal_id, true);
    END IF;
  END LOOP;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  VALUES (k.user_id, 'provizny_list_zruseny', k.id, format('Provízny list %s bol zrušený, provízie sa vrátili na Čaká.', k.number));
END;
$$;

CREATE OR REPLACE FUNCTION commission_reassign(p_deal uuid, p_user uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  p commission;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu preradí iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod preradenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM commission_lock_deal(p_deal, true);   -- 0054: zámok obchodu pred riadkom provízie
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  IF p.id IS NULL OR NOT p.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Obchod nemá čakajúcu províziu.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p.user_id = p_user THEN
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = p_user AND u.status = 'aktivny') OR NOT crm_user_sees_org(p_user, p.org_id) THEN
    RAISE EXCEPTION 'Nový obchodník musí byť aktívny a v spoločnosti provízie.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE commission
     SET user_id = p_user, reassigned_from = p.user_id, reassigned_by = crm_active_user_id(), reassigned_at = now(),
         reassign_reason = btrim(p_reason)
   WHERE id = p.id;
  INSERT INTO notification (user_id, kind, deal_id, detail)
  VALUES (p_user, 'provizia_preradena', p_deal, format('%s vám preradil čakajúcu províziu.', crm_user_name(crm_active_user_id()))),
         (p.user_id, 'provizia_preradena', p_deal, format('%s preradil vašu čakajúcu províziu – %s.', crm_user_name(crm_active_user_id()), crm_user_name(p_user)));
END;
$$;

-- 1. „vidí všetky provízie“ iba admin; „počítať provízie“ admin alebo schvaľovateľ cien (audit: trg_audit na app_user)
CREATE FUNCTION app_user_commission_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.sees_all_commissions IS DISTINCT FROM (CASE WHEN TG_OP = 'UPDATE' THEN OLD.sees_all_commissions ELSE false END)
     AND NOT (crm_is_service() OR crm_is_admin()) THEN
    RAISE EXCEPTION '„Vidí všetky provízie“ mení iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF NEW.commission_enabled IS DISTINCT FROM (CASE WHEN TG_OP = 'UPDATE' THEN OLD.commission_enabled ELSE false END)
     AND NOT (crm_is_service() OR crm_is_admin() OR crm_approves_prices()) THEN
    RAISE EXCEPTION '„Počítať provízie“ mení admin alebo schvaľovateľ cien.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_commission_guard BEFORE INSERT OR UPDATE OF sees_all_commissions, commission_enabled ON app_user
  FOR EACH ROW EXECUTE FUNCTION app_user_commission_guard();

-- 2. upozornenie adminom pri neúplnom základe
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve', 'pomoc_s_ponukou',
  'provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena', 'provizia_chyba_cena']::text[]));

-- existujúce neúplné základy dostanú nový text dôvodu (prepočet bez uplatnených – tie sa nemenia)
SELECT commission_sync(deal_id, false) FROM commission WHERE status = 'caka' AND base_missing IS NOT NULL AND deal_id IS NOT NULL;

-- B. interné funkcie: nie PUBLIC, nie crm_app (crm_public nemá ani schému public – public-role.sql)
REVOKE EXECUTE ON FUNCTION commission_lock_deals(uuid[]), commission_queue_run(), commission_lock_deal(uuid, boolean) FROM PUBLIC;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_app') THEN
    REVOKE EXECUTE ON FUNCTION commission_lock_deals(uuid[]), commission_queue_run(), commission_lock_deal(uuid, boolean) FROM crm_app;
  END IF;
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'crm_public') THEN
    REVOKE EXECUTE ON FUNCTION contract_year_calc_core(uuid, integer, date), commission_deal_base(uuid), commission_sync(uuid, boolean),
      commission_legacy_match(uuid), commission_notify_admins(uuid, text, uuid, text), commission_lock_deals(uuid[]),
      commission_queue_run(), commission_lock_deal(uuid, boolean) FROM crm_public;
  END IF;
END;
$$;

-- migrate:down

DROP TRIGGER trg_commission_guard ON app_user;
DROP FUNCTION app_user_commission_guard();
CREATE OR REPLACE FUNCTION commission_deal_base(p_deal uuid) RETURNS TABLE (base_eur numeric, volume_mwh numeric, duration_years smallint, contracts integer, missing text)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  c       contract;
  v_from  date;
  v_until date;
  y       integer;
  r       record;
  v_base  numeric := 0;
  v_vol   numeric := 0;
  v_dur   integer := 0;
  v_open  boolean := false;
  v_n     integer := 0;
  v_miss  text[] := '{}';
BEGIN
  FOR c IN SELECT * FROM contract k
            WHERE k.deal_id = p_deal AND k.deal_match IN ('auto', 'rucne') AND k.signed_on IS NOT NULL
              AND k.phase NOT IN ('odmietnuta', 'neuspesna')
            ORDER BY k.number LOOP
    SELECT coalesce(min(x.valid_from), c.valid_from) INTO v_from FROM contract_oom x WHERE x.contract_id = c.id AND x.valid_from IS NOT NULL;
    IF v_from IS NULL THEN
      v_miss := v_miss || format('zmluva %s bez začiatku dodávky', c.number);
      CONTINUE;
    END IF;
    v_n := v_n + 1;
    IF c.valid_to IS NULL THEN
      v_open := true;
      v_until := (v_from + interval '12 months' - interval '1 day')::date;
    ELSE
      v_until := greatest(c.valid_to, v_from);
      v_dur := greatest(v_dur, ceil(((extract(year FROM v_until) * 12 + extract(month FROM v_until))
                                     - (extract(year FROM v_from) * 12 + extract(month FROM v_from)) + 1) / 12.0)::integer);
    END IF;
    FOR y IN extract(year FROM v_from)::integer .. extract(year FROM v_until)::integer LOOP
      SELECT * INTO r FROM contract_year_calc_core(c.id, y, v_until);
      IF r.months > 0 AND r.added_value_eur IS NULL THEN
        v_miss := v_miss || format('zmluva %s, rok %s: %s', c.number, y, coalesce(r.missing, 'chýba vstup'));
      END IF;
      v_base := v_base + coalesce(r.added_value_eur, 0);
      v_vol := v_vol + coalesce(r.volume_mwh, 0);
    END LOOP;
  END LOOP;
  RETURN QUERY SELECT round(v_base, 2), round(v_vol, 3),
                      CASE WHEN v_open OR v_dur = 0 THEN NULL ELSE v_dur END::smallint, v_n,
                      nullif(array_to_string(v_miss, '; '), '');
END;
$$;

CREATE OR REPLACE FUNCTION commission_sync(p_deal uuid, p_structural boolean) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  d         deal;
  v_won     boolean;
  v_claimed numeric;
  v_hasclm  boolean;
  p         commission;
  v_ref     commission;
  v_user    uuid;
  v_pct     numeric;
  v_wonon   date;
  v_from    date;
  v_legacy  uuid;
  b         record;
  v_target  numeric;
  v_diff    numeric;
  v_n       integer;
BEGIN
  SELECT * INTO d FROM deal WHERE id = p_deal;
  IF d.id IS NULL THEN
    RETURN false;
  END IF;
  -- súbežné prepočty toho istého obchodu po sebe
  PERFORM pg_advisory_xact_lock(hashtextextended('commission:' || p_deal::text, 0));
  v_won := (SELECT s.code FROM pipeline_stage s WHERE s.id = d.stage_id) = 'vyhrane';
  SELECT coalesce(sum(amount_eur), 0), count(*) > 0 INTO v_claimed, v_hasclm
    FROM commission WHERE deal_id = p_deal AND status = 'uplatnena';
  IF v_hasclm AND NOT p_structural THEN
    RETURN false;   -- odpoveď 1: po uplatnení iba štrukturálne zmeny
  END IF;
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  -- vlastník a percento: čakajúca položka, inak posledná nezrušená (preradenie platí aj pre budúce vyrovnania)
  IF p.id IS NOT NULL THEN
    v_ref := p;
  ELSE
    SELECT * INTO v_ref FROM commission WHERE deal_id = p_deal AND status <> 'zrusena' ORDER BY created_at DESC LIMIT 1;
  END IF;

  IF v_ref.id IS NULL THEN
    -- vznik: Vyhraté, od dátumu prechodu, vlastník počíta provízie, bez provízie zo Sales portálu
    IF NOT v_won OR d.closed_at IS NULL THEN
      RETURN false;
    END IF;
    v_wonon := crm_local_date(d.closed_at);
    v_from := (SELECT (value #>> '{}')::date FROM app_setting WHERE key = 'commission_crm_from');
    IF v_from IS NULL OR v_wonon < v_from THEN
      RETURN false;
    END IF;
    IF NOT coalesce((SELECT commission_enabled FROM app_user WHERE id = d.owner_id), false) THEN
      RETURN false;
    END IF;
    v_legacy := commission_legacy_match(p_deal);
    IF v_legacy IS NOT NULL AND NOT EXISTS (SELECT 1 FROM commission_legacy_override WHERE deal_id = p_deal) THEN
      IF NOT EXISTS (SELECT 1 FROM notification WHERE kind = 'provizia_duplicita' AND deal_id = p_deal) THEN
        PERFORM commission_notify_admins(d.org_id, 'provizia_duplicita', p_deal,
          'Obchod má províziu zo Sales portálu – provízia z CRM nevznikla. Ak ide o iný obchod, povoľte ju.');
      END IF;
      RETURN false;
    END IF;
    v_user := d.owner_id;
    v_pct := user_commission_pct(d.owner_id, v_wonon);
  ELSE
    v_user := v_ref.user_id;
    v_pct := v_ref.pct;
    v_wonon := CASE WHEN v_won AND d.closed_at IS NOT NULL THEN crm_local_date(d.closed_at) ELSE v_ref.won_at END;
  END IF;

  SELECT * INTO b FROM commission_deal_base(p_deal);
  v_target := CASE WHEN v_won THEN round(greatest(b.base_eur, 0) * v_pct / 100, 2) ELSE 0 END;
  v_diff := v_target - v_claimed;

  IF p.id IS NOT NULL THEN
    IF (NOT v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff = 0) THEN
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE id = p.id;
      RETURN true;
    END IF;
    UPDATE commission
       SET amount_eur = v_diff, target_eur = v_target, base_eur = b.base_eur, base_missing = b.missing,
           volume_mwh = b.volume_mwh, duration_years = b.duration_years, won_at = v_wonon, recalculated_at = now()
     WHERE id = p.id
       AND (amount_eur, target_eur, base_eur, base_missing, volume_mwh, duration_years, won_at)
           IS DISTINCT FROM (v_diff, v_target, b.base_eur, b.missing, b.volume_mwh, b.duration_years, v_wonon);
    GET DIAGNOSTICS v_n = ROW_COUNT;
    RETURN v_n > 0;
  END IF;

  IF (v_won AND NOT v_hasclm) OR (v_hasclm AND v_diff <> 0) THEN
    INSERT INTO commission (org_id, deal_id, user_id, kind, status, won_at, duration_years, volume_mwh, base_eur, base_missing,
                            pct, target_eur, amount_eur, recalculated_at)
    VALUES (d.org_id, p_deal, v_user, CASE WHEN v_hasclm THEN 'vyrovnanie' ELSE 'provizia' END, 'caka', v_wonon,
            b.duration_years, b.volume_mwh, b.base_eur, b.missing, v_pct, v_target, v_diff, now());
    IF v_hasclm THEN
      INSERT INTO notification (user_id, kind, deal_id, detail)
      VALUES (v_user, 'provizia_vyrovnanie', p_deal,
              'Vyrovnanie už uplatnenej provízie po zmene obchodu – nová čakajúca položka.');
    END IF;
    RETURN true;
  END IF;
  RETURN false;
END;
$$;

CREATE OR REPLACE FUNCTION commission_on_change() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  r_new jsonb := CASE WHEN TG_OP <> 'DELETE' THEN to_jsonb(NEW) END;
  r_old jsonb := CASE WHEN TG_OP <> 'INSERT' THEN to_jsonb(OLD) END;
  v_new uuid;
  v_old uuid;
BEGIN
  CASE TG_TABLE_NAME
    WHEN 'deal' THEN
      PERFORM commission_sync((r_new->>'id')::uuid, true);
    WHEN 'contract' THEN
      v_new := (r_new->>'deal_id')::uuid;
      v_old := (r_old->>'deal_id')::uuid;
      IF v_old IS DISTINCT FROM v_new THEN
        IF v_old IS NOT NULL THEN
          PERFORM commission_sync(v_old, true);
        END IF;
        IF v_new IS NOT NULL THEN
          PERFORM commission_sync(v_new, true);
        END IF;
      ELSIF v_new IS NOT NULL THEN
        PERFORM commission_sync(v_new, false);
      END IF;
    ELSE   -- contract_oom, contract_price, contract_year_basis: bilancia zmluvy
      SELECT k.deal_id INTO v_new FROM contract k WHERE k.id = (coalesce(r_new, r_old)->>'contract_id')::uuid;
      IF v_new IS NOT NULL THEN
        PERFORM commission_sync(v_new, false);
      END IF;
  END CASE;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION commission_daily() RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_all  integer := 0;
  v_diff integer := 0;
  r      record;
  v_res  jsonb;
BEGIN
  PERFORM crm_background_only();
  FOR r IN SELECT d.id FROM deal d JOIN pipeline_stage s ON s.id = d.stage_id WHERE s.code = 'vyhrane'
           UNION
           SELECT c.deal_id FROM commission c WHERE c.status = 'caka' AND c.deal_id IS NOT NULL LOOP
    v_all := v_all + 1;
    IF commission_sync(r.id, false) THEN
      v_diff := v_diff + 1;
    END IF;
  END LOOP;
  v_res := jsonb_build_object('provizie_prepocitane', v_all, 'provizie_zmena', v_diff);
  UPDATE job_run SET result = result || v_res
   WHERE id = (SELECT id FROM job_run WHERE job = 'obchody' AND run_date = crm_today() ORDER BY started_at DESC LIMIT 1);
  RETURN v_res;
END;
$$;

CREATE OR REPLACE FUNCTION commission_claim_create(p_user uuid, p_ids uuid[]) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_me    uuid := crm_active_user_id();
  v_org   uuid;
  v_n     integer;
  v_total numeric;
  v_year  integer := extract(year FROM crm_today())::integer;
  v_no    text;
  v_claim uuid;
  v_cc    uuid[];
BEGIN
  IF v_me IS NULL THEN
    RAISE EXCEPTION 'Uplatniť províziu môže iba prihlásený používateľ.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user IS DISTINCT FROM v_me AND NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu za iného obchodníka uplatní iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF p_user = v_me AND NOT crm_is_admin() AND crm_scope('provizie', 'view') = 'nic' THEN
    RAISE EXCEPTION 'Nemáte právo na provízie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF coalesce(cardinality(p_ids), 0) = 0 THEN
    RAISE EXCEPTION 'Vyberte aspoň jednu províziu.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM 1 FROM commission WHERE id = ANY (p_ids) ORDER BY id FOR UPDATE;
  SELECT count(*), min(org_id::text)::uuid, sum(amount_eur) INTO v_n, v_org, v_total FROM commission WHERE id = ANY (p_ids);
  IF v_n <> (SELECT count(DISTINCT x) FROM unnest(p_ids) x) THEN
    RAISE EXCEPTION 'Niektorá provízia neexistuje.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND (status <> 'caka' OR user_id <> p_user OR org_id <> v_org)) THEN
    RAISE EXCEPTION 'Uplatniť sa dajú iba čakajúce provízie jedného obchodníka v jednej spoločnosti.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT v_org = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Spoločnosť provízie nevidíte.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND base_missing IS NOT NULL) THEN
    RAISE EXCEPTION 'Provízia s neúplným základom (chýba cena) sa nedá uplatniť – doplňte ceny.' USING ERRCODE = 'check_violation';
  END IF;
  IF v_total < 0 OR NOT EXISTS (SELECT 1 FROM commission WHERE id = ANY (p_ids) AND amount_eur > 0) THEN
    RAISE EXCEPTION 'Súčet listu musí byť aspoň 0 € a list musí obsahovať kladnú províziu (záporné vyrovnanie sa samostatne neuplatňuje).'
      USING ERRCODE = 'check_violation';
  END IF;

  v_no := format('CMSN-%s-%s', v_year, lpad(doc_number_next(v_org, 'provizny_list', v_year)::text, 4, '0'));
  INSERT INTO commission_claim (org_id, number, user_id, total_eur, by_duration, created_by)
  SELECT v_org, v_no, p_user, v_total,
         coalesce((SELECT jsonb_object_agg(k, s) FROM (SELECT coalesce(duration_years::text, 'neurcito') AS k, sum(amount_eur) AS s
                                                        FROM commission WHERE id = ANY (p_ids) GROUP BY 1) z), '{}'),
         v_me
  RETURNING id INTO v_claim;
  UPDATE commission SET status = 'uplatnena', claim_id = v_claim WHERE id = ANY (p_ids);

  -- upozornenia: obchodníkovi, ak uplatnil admin; príjemcom kópie (bez súm – nemusia vidieť všetky provízie)
  IF p_user <> v_me THEN
    INSERT INTO notification (user_id, kind, commission_claim_id, detail)
    VALUES (p_user, 'provizny_list', v_claim, format('Provízny list %s uplatnil za vás %s.', v_no, crm_user_name(v_me)));
  END IF;
  SELECT coalesce(array_agg(x::uuid), '{}') INTO v_cc
    FROM jsonb_array_elements_text(coalesce((SELECT value FROM app_setting WHERE key = 'commission_claim_cc'), '[]')) x;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  SELECT u.id, 'provizny_list', v_claim, format('Nový provízny list %s – %s.', v_no, crm_user_name(p_user))
    FROM app_user u
   WHERE u.id = ANY (v_cc) AND u.id <> p_user AND u.status = 'aktivny' AND crm_user_sees_org(u.id, v_org);
  RETURN v_claim;
END;
$$;

CREATE OR REPLACE FUNCTION commission_claim_void(p_claim uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  k commission_claim;
  r record;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Provízny list zruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod zrušenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO k FROM commission_claim WHERE id = p_claim FOR UPDATE;
  IF k.id IS NULL OR NOT k.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Provízny list neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF k.voided_at IS NOT NULL THEN
    RAISE EXCEPTION 'Provízny list je už zrušený.' USING ERRCODE = 'check_violation';
  END IF;
  IF k.source = 'sales_portal' THEN
    RAISE EXCEPTION 'Provízny list zo Sales portálu je iba na čítanie.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE commission_claim SET voided_at = now(), voided_by = crm_active_user_id(), void_reason = btrim(p_reason) WHERE id = k.id;
  FOR r IN SELECT id, deal_id FROM commission WHERE claim_id = k.id ORDER BY id LOOP
    IF r.deal_id IS NOT NULL THEN
      -- najviac jedna čakajúca na obchod: nová čakajúca položka (vyrovnanie) sa zruší a prepočet ju zahrnie
      UPDATE commission SET status = 'zrusena', recalculated_at = now() WHERE deal_id = r.deal_id AND status = 'caka';
    END IF;
    UPDATE commission SET status = 'caka', claim_id = NULL WHERE id = r.id;
    IF r.deal_id IS NOT NULL THEN
      PERFORM commission_sync(r.deal_id, true);
    END IF;
  END LOOP;
  INSERT INTO notification (user_id, kind, commission_claim_id, detail)
  VALUES (k.user_id, 'provizny_list_zruseny', k.id, format('Provízny list %s bol zrušený, provízie sa vrátili na Čaká.', k.number));
END;
$$;

CREATE OR REPLACE FUNCTION commission_reassign(p_deal uuid, p_user uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  p commission;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Províziu preradí iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) < 3 THEN
    RAISE EXCEPTION 'Zadajte dôvod preradenia (aspoň 3 znaky).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO p FROM commission WHERE deal_id = p_deal AND status = 'caka' FOR UPDATE;
  IF p.id IS NULL OR NOT p.org_id = ANY (crm_user_orgs()) THEN
    RAISE EXCEPTION 'Obchod nemá čakajúcu províziu.' USING ERRCODE = 'no_data_found';
  END IF;
  IF p.user_id = p_user THEN
    RETURN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM app_user u WHERE u.id = p_user AND u.status = 'aktivny') OR NOT crm_user_sees_org(p_user, p.org_id) THEN
    RAISE EXCEPTION 'Nový obchodník musí byť aktívny a v spoločnosti provízie.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE commission
     SET user_id = p_user, reassigned_from = p.user_id, reassigned_by = crm_active_user_id(), reassigned_at = now(),
         reassign_reason = btrim(p_reason)
   WHERE id = p.id;
  INSERT INTO notification (user_id, kind, deal_id, detail)
  VALUES (p_user, 'provizia_preradena', p_deal, format('%s vám preradil čakajúcu províziu.', crm_user_name(crm_active_user_id()))),
         (p.user_id, 'provizia_preradena', p_deal, format('%s preradil vašu čakajúcu províziu – %s.', crm_user_name(crm_active_user_id()), crm_user_name(p_user)));
END;
$$;
DROP FUNCTION commission_queue_run();
DROP FUNCTION commission_lock_deals(uuid[]);
DROP FUNCTION commission_lock_deal(uuid, boolean);
DROP TABLE commission_queue;
DELETE FROM notification WHERE kind = 'provizia_chyba_cena';
ALTER TABLE notification DROP CONSTRAINT notification_kind_check;
ALTER TABLE notification ADD CONSTRAINT notification_kind_check CHECK (kind = ANY (ARRAY['konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie', 'nocny_beh_chyba', 'maly_podnik', 'objem_xm', 'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy', 'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena', 'ponuka_odpoved', 'ponuka_pripomienka', 'gmail_chyba', 'email_chyba', 'nesparovana_zmluva', 'cena_ina_ako_v_ponuke', 'obnova', 'chyba_oom_na_zmluve', 'pomoc_s_ponukou',
  'provizny_list', 'provizny_list_zruseny', 'provizia_vyrovnanie', 'provizia_duplicita', 'provizia_preradena']::text[]));
