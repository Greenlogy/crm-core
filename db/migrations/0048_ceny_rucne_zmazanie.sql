-- migrate:up

-- 0048_ceny_rucne_zmazanie – modul 5, fáza F6, krok 1 (Peter 16. 10.): admin môže ručne zadanú cenu dňa zmazať s dôvodom.
-- Riadok sa nemaže fyzicky: označí sa ako opravený (kto, kedy) s dôvodom zmazania a ostane v histórii aj v audite.
-- Deň potom nemá platnú cenu daného roka a ďalší beh cien ju načíta z Montelu (market_price_daily_run, 0047).

ALTER TABLE market_price_daily ADD COLUMN removed_reason text;
ALTER TABLE market_price_daily ADD CONSTRAINT market_price_removed_check
  CHECK (removed_reason IS NULL OR (corrected_at IS NOT NULL AND length(btrim(removed_reason)) BETWEEN 3 AND 500));
COMMENT ON COLUMN market_price_daily.removed_reason IS 'dôvod zmazania ručne zadanej ceny dňa adminom (0048); riadok ostane v histórii';

CREATE FUNCTION market_price_manual_remove(p_id uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  m      market_price_daily;
  v_user uuid := crm_active_user_id();
BEGIN
  IF v_user IS NULL OR NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Ručne zadanú cenu dňa maže iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF length(btrim(coalesce(p_reason, ''))) NOT BETWEEN 3 AND 500 THEN
    RAISE EXCEPTION 'Zadajte dôvod zmazania.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO m FROM market_price_daily WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF m.id IS NULL THEN
    RAISE EXCEPTION 'Cena dňa neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  IF m.corrected_at IS NOT NULL OR m.source <> 'rucne' THEN
    RAISE EXCEPTION 'Zmazať sa dá iba platná ručne zadaná cena dňa.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM set_config('crm.market_price_correction', 'on', true);
  UPDATE market_price_daily SET corrected_at = now(), corrected_by = v_user, removed_reason = btrim(p_reason) WHERE id = m.id;
  PERFORM set_config('crm.market_price_correction', '', true);
END;
$$;

-- migrate:down

DROP FUNCTION market_price_manual_remove(uuid, text);
ALTER TABLE market_price_daily DROP COLUMN removed_reason;
