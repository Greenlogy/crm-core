-- 0005_rls_zakaznici.sql – prístup externého obchodníka (zadanie čl. 6, 12, 13)
--
-- Row Level Security na company, contact, company_contact:
--   interní používatelia (admin, vedenie, obchodnik, servis, marketing) vidia všetko,
--   externý obchodník iba firmy a domácnosti, ktorých je vlastníkom, a osoby na svojich firmách.
-- Používateľa nastaví API v každej transakcii: SET LOCAL app.user_id = '<uuid>' (to isté používa audit).
-- Rola, ktorá musí mať používateľa vždy (aplikácia), dostane: ALTER ROLE … SET app.require_user = 'on'.
-- Bez app.user_id potom nevidí nič. Ostatné roly bez používateľa (vlastník, crm_sync, Cockpit,
-- crm_prototype_ro) vidia všetko; vlastník tabuliek RLS obchádza vždy.
-- Kontrola duplicity pre externého: funkcie company_ico_check a contact_duplicate_check
-- vrátia iba „existuje“ a meno vlastníka, žiadne údaje záznamu.
-- Stĺpcové práva (servis mení iba kontaktné údaje) kontroluje API; vlastníka chráni spúšťač z 0004.
-- Ďalšie tabuľky (oom, deal, contract, offer, activity…) pridajú politiky ich moduly.
-- Rolu externy_obchodnik nepriraďovať nikomu, kým tieto politiky nebudú hotové.

-- migrate:up

-- ============================================================================
-- Kto je prihlásený
-- ============================================================================

-- crm_current_user_id(), crm_sees_all(), crm_external_user_id() sú v 0004.

-- Firma patrí externému obchodníkovi (bez ohľadu na RLS)
CREATE FUNCTION crm_external_owns_company(p_company_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company c
                  WHERE c.id = p_company_id AND c.owner_id = crm_external_user_id())
$$;

-- Osoba je kontaktom na firme externého obchodníka (bez ohľadu na RLS)
CREATE FUNCTION crm_external_sees_contact(p_contact_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                  WHERE cc.contact_id = p_contact_id AND c.owner_id = crm_external_user_id())
$$;

-- ============================================================================
-- Politiky
-- ============================================================================

ALTER TABLE company ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_contact ENABLE ROW LEVEL SECURITY;

CREATE POLICY company_access ON company
  USING ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()))
  WITH CHECK ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()));

CREATE POLICY contact_access ON contact
  USING ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()) OR crm_external_sees_contact(id))
  WITH CHECK ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()) OR crm_external_sees_contact(id));

CREATE POLICY company_contact_access ON company_contact
  USING ((SELECT crm_sees_all()) OR crm_external_owns_company(company_id))
  WITH CHECK ((SELECT crm_sees_all()) OR crm_external_owns_company(company_id));

-- Pohľady bežia s právami toho, kto sa pýta (inak by ako vlastníkove RLS obišli).
ALTER VIEW customer_v SET (security_invoker = true);
ALTER VIEW contact_v SET (security_invoker = true);

-- ============================================================================
-- Kontrola duplicít (čl. 7, 12): iba „existuje“ a vlastník
-- ============================================================================

-- Príklad: SELECT * FROM company_ico_check('12345678') → company_exists = true, owner_name = 'Jana Malá'.
-- company_id vráti iba tomu, kto firmu vidí (interný alebo jej vlastník).
CREATE FUNCTION company_ico_check(p_ico text)
RETURNS TABLE (company_exists boolean, company_id uuid, owner_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT true,
         CASE WHEN crm_sees_all() OR c.owner_id = crm_external_user_id() THEN c.id END,
         u.name
    FROM company c
    LEFT JOIN app_user u ON u.id = c.owner_id
   WHERE c.ico = lpad(regexp_replace(p_ico, '[^0-9]', '', 'g'), 8, '0')
$$;

-- Zhoda podľa e-mailu, potom telefónu (phone aj mobile, v ľubovoľnom zápise).
-- contact_id vráti iba tomu, kto osobu vidí; inak iba „osoba už existuje, vlastník X“.
CREATE FUNCTION contact_duplicate_check(p_email text, p_phone text)
RETURNS TABLE (match_on text, contact_id uuid, owner_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT m.match_on,
         CASE WHEN crm_sees_all() OR p.owner_id = crm_external_user_id() OR crm_external_sees_contact(p.id)
              THEN p.id END,
         u.name
    FROM (
      SELECT 'email'::text AS match_on, p.id
        FROM contact p
       WHERE nullif(btrim(p_email), '') IS NOT NULL
         AND lower(btrim(p.email)) = lower(btrim(p_email))
      UNION
      SELECT 'telefon', p.id
        FROM contact p
       WHERE normalize_phone(p_phone) IS NOT NULL
         AND normalize_phone(p_phone) IN (p.phone_norm, p.mobile_norm)
    ) m
    JOIN contact p ON p.id = m.id
    LEFT JOIN app_user u ON u.id = p.owner_id
   ORDER BY m.match_on, p.created_at
$$;

-- migrate:down

DROP FUNCTION IF EXISTS contact_duplicate_check(text, text);
DROP FUNCTION IF EXISTS company_ico_check(text);

ALTER VIEW contact_v RESET (security_invoker);
ALTER VIEW customer_v RESET (security_invoker);

DROP POLICY IF EXISTS company_contact_access ON company_contact;
DROP POLICY IF EXISTS contact_access ON contact;
DROP POLICY IF EXISTS company_access ON company;

ALTER TABLE company_contact DISABLE ROW LEVEL SECURITY;
ALTER TABLE contact DISABLE ROW LEVEL SECURITY;
ALTER TABLE company DISABLE ROW LEVEL SECURITY;

DROP FUNCTION IF EXISTS crm_external_sees_contact(uuid);
DROP FUNCTION IF EXISTS crm_external_owns_company(uuid);
