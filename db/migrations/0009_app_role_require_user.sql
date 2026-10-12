-- 0009_app_role_require_user.sql – rola aplikácie crm_app vždy potrebuje prihláseného používateľa
--
-- Doteraz (0005, 0006): „bez používateľa nič“ platilo, ak mala rola nastavené app.require_user = on
-- (ALTER ROLE … SET). Na Neone to nejde – vlastnícka rola nie je superuser a vlastný parameter
-- roli nastaviť nesmie. Navyše by si ho aplikácia vedela sama vypnúť (SET app.require_user = '').
-- Teraz: rola crm_app (aj keď sa prihlási priamo) je vždy „aplikácia“; nastavenie app.require_user
-- ostáva iba pre testy (dočasné roly v db/test).

-- migrate:up

CREATE OR REPLACE FUNCTION crm_require_user() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT current_user = 'crm_app' OR session_user = 'crm_app'
      OR coalesce(current_setting('app.require_user', true), '') = 'on'
$$;
COMMENT ON FUNCTION crm_require_user() IS 'true = spojenie aplikácie: bez prihláseného používateľa nevidí nič (rola crm_app vždy, testy cez app.require_user)';

-- migrate:down

CREATE OR REPLACE FUNCTION crm_require_user() RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT coalesce(current_setting('app.require_user', true), '') = 'on'
$$;
COMMENT ON FUNCTION crm_require_user() IS NULL;
