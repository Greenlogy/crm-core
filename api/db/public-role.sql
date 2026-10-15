-- Práva roly crm_public (Worker crm-ponuka: verejná stránka ponuky mimo Cloudflare Access). Iba Neon vetva dev, neskôr main.
-- Rolu s heslom vytvorí api/db/create-public-role.sh, ktorý potom spustí tento súbor. Nie je to dbmate migrácia.
--
-- Zásady (návrh DB časť 5.1, 0039):
--   - žiadna tabuľka ani schéma public (od 0039 ju nemá PUBLIC), iba schéma verejne a jej tri funkcie;
--   - databáza vráti iba jednu ponuku podľa platného odkazu; app.user_id sa pre túto rolu ignoruje;
--   - nikdy neobchádza RLS.

\set ON_ERROR_STOP on
BEGIN;

DO $$
BEGIN
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO crm_public', current_database());
END;
$$;

REVOKE ALL ON SCHEMA public FROM crm_public;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM crm_public;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM crm_public;
GRANT USAGE ON SCHEMA verejne TO crm_public;
GRANT EXECUTE ON FUNCTION verejne.ponuka_zobrazit(text), verejne.ponuka_pdf(text),
  verejne.ponuka_akceptovat(text, uuid, text, text, inet, text, text) TO crm_public;
-- 0041: potvrdenie akceptácie – uloženie hneď po akceptácii a stiahnutie uloženého súboru
GRANT EXECUTE ON FUNCTION verejne.ponuka_potvrdenie_ulozit(text, uuid, text, text), verejne.ponuka_potvrdenie_pdf(text) TO crm_public;

ALTER ROLE crm_public NOBYPASSRLS;
ALTER ROLE crm_public SET statement_timeout = '10s';
ALTER ROLE crm_public SET search_path = verejne;

COMMIT;
