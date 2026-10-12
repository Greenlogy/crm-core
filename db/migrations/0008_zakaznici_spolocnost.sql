-- 0008_zakaznici_spolocnost.sql – doplnok modulu Zákazníci k Nastaveniam (docs/moduly/00-nastavenia-navrh-db.md v0.1, časti 3 a 4)
--
-- Spoločnosť (org_id) na firme, osobe, OOM, deale, zmluve a ponuke. Firma a osoba dostanú
--   predvolenú spoločnosť; OOM, deal a zmluva ju preberajú od zákazníka, ponuka od dealu.
--   Väzby (osoba vo firme, osoba na deale, deal a pipeline, zmluva a deal) musia byť v jednej spoločnosti.
-- Firma: krajina (predvolene krajina spoločnosti) a identifikátor podľa krajiny:
--   SK, CZ = IČO 8 číslic, HR = OIB 11 číslic; unikátna je krajina + identifikátor.
-- Roly kontaktu vo firme sú kódy z číselníka rola_kontaktu (nahrádza enum company_role);
--   zdroj kontaktu je kód z číselníka zdroj_kontaktu.
-- RLS podľa práv tímu (modul Zákazníci) a prístupu k spoločnostiam; nahrádza politiky z 0005.
--   „Iba svoje“ = firmy a domácnosti, ktorých je používateľ vlastníkom, a osoby na jeho firmách.
-- Kontrola duplicít: IČO v rámci krajiny (firma je v CRM raz), osoba iba v rámci spoločnosti.

-- migrate:up

-- ============================================================================
-- Spoločnosť na záznamoch
-- ============================================================================

ALTER TABLE company ADD COLUMN org_id uuid NOT NULL DEFAULT crm_default_org() REFERENCES org (id);
ALTER TABLE contact ADD COLUMN org_id uuid NOT NULL DEFAULT crm_default_org() REFERENCES org (id);
ALTER TABLE oom      ADD COLUMN org_id uuid REFERENCES org (id);
ALTER TABLE deal     ADD COLUMN org_id uuid REFERENCES org (id);
ALTER TABLE contract ADD COLUMN org_id uuid REFERENCES org (id);
ALTER TABLE offer    ADD COLUMN org_id uuid REFERENCES org (id);

UPDATE oom o SET org_id = coalesce(c.org_id, p.org_id)
  FROM oom x LEFT JOIN company c ON c.id = x.company_id LEFT JOIN contact p ON p.id = x.person_id
 WHERE o.id = x.id;
UPDATE deal o SET org_id = coalesce(c.org_id, p.org_id)
  FROM deal x LEFT JOIN company c ON c.id = x.company_id LEFT JOIN contact p ON p.id = x.person_id
 WHERE o.id = x.id;
UPDATE contract o SET org_id = coalesce(c.org_id, p.org_id)
  FROM contract x LEFT JOIN company c ON c.id = x.company_id LEFT JOIN contact p ON p.id = x.person_id
 WHERE o.id = x.id;
UPDATE offer f SET org_id = d.org_id FROM deal d WHERE d.id = f.deal_id;

ALTER TABLE oom      ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE deal     ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE contract ALTER COLUMN org_id SET NOT NULL;
ALTER TABLE offer    ALTER COLUMN org_id SET NOT NULL;

CREATE INDEX company_org_id_idx ON company (org_id);
CREATE INDEX contact_org_id_idx ON contact (org_id);
CREATE INDEX oom_org_id_idx ON oom (org_id);
CREATE INDEX deal_org_id_idx ON deal (org_id);
CREATE INDEX contract_org_id_idx ON contract (org_id);
CREATE INDEX offer_org_id_idx ON offer (org_id);

COMMENT ON COLUMN company.org_id IS 'spoločnosť skupiny, ktorej firma patrí (zákazník patrí práve jednej)';
COMMENT ON COLUMN contact.org_id IS 'spoločnosť skupiny; osoba vo dvoch spoločnostiach = dva záznamy (Peter 12. 10.)';
COMMENT ON COLUMN oom.org_id IS 'preberá sa od zákazníka';
COMMENT ON COLUMN deal.org_id IS 'preberá sa od zákazníka';
COMMENT ON COLUMN contract.org_id IS 'preberá sa od zákazníka';
COMMENT ON COLUMN offer.org_id IS 'preberá sa od dealu';

-- OOM, deal, zmluva, ponuka: spoločnosť od zákazníka (dealu); iná spoločnosť = chyba.
CREATE FUNCTION record_org_fill() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_org  uuid;
  v_ref  uuid;
BEGIN
  IF TG_TABLE_NAME = 'offer' THEN
    SELECT org_id INTO v_org FROM deal WHERE id = NEW.deal_id;
  ELSIF NEW.company_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM company WHERE id = NEW.company_id;
  ELSIF NEW.person_id IS NOT NULL THEN
    SELECT org_id INTO v_org FROM contact WHERE id = NEW.person_id;
  END IF;

  -- bez zákazníka predvolená spoločnosť, aby zlyhala kontrola zákazníka (CHECK), nie NOT NULL
  NEW.org_id := coalesce(NEW.org_id, v_org, crm_default_org());
  IF v_org IS NOT NULL AND NEW.org_id <> v_org THEN
    RAISE EXCEPTION 'Záznam musí patriť tej istej spoločnosti ako jeho zákazník.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_TABLE_NAME = 'deal' THEN
    SELECT org_id INTO v_ref FROM pipeline WHERE id = NEW.pipeline_id;
    IF v_ref IS NOT NULL AND v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Pipeline patrí inej spoločnosti ako deal.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF TG_TABLE_NAME = 'contract' THEN
    -- (NEW.deal_id iba vo vetve zmluvy: OOM stĺpec deal_id nemá)
    SELECT org_id INTO v_ref FROM deal WHERE id = NEW.deal_id;
    IF v_ref <> NEW.org_id THEN
      RAISE EXCEPTION 'Deal zmluvy patrí inej spoločnosti.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON oom
  FOR EACH ROW EXECUTE FUNCTION record_org_fill();
CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON deal
  FOR EACH ROW EXECUTE FUNCTION record_org_fill();
CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON contract
  FOR EACH ROW EXECUTE FUNCTION record_org_fill();
CREATE TRIGGER trg_record_org BEFORE INSERT OR UPDATE ON offer
  FOR EACH ROW EXECUTE FUNCTION record_org_fill();

-- Firma a osoba nezmenia spoločnosť, kým na ne niečo odkazuje.
CREATE FUNCTION customer_org_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.org_id IS DISTINCT FROM OLD.org_id AND (
       (TG_TABLE_NAME = 'company' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE company_id = OLD.id)))
    OR (TG_TABLE_NAME = 'contact' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE person_id = OLD.id)))) THEN
    RAISE EXCEPTION 'Spoločnosť sa nedá zmeniť, záznam má väzby (osoby, OOM, dealy, zmluvy).'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON company
  FOR EACH ROW EXECUTE FUNCTION customer_org_guard();
CREATE TRIGGER trg_customer_org_guard BEFORE UPDATE OF org_id ON contact
  FOR EACH ROW EXECUTE FUNCTION customer_org_guard();

-- Osoba na deale musí byť z tej istej spoločnosti
CREATE FUNCTION deal_contact_org_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF (SELECT org_id FROM deal WHERE id = NEW.deal_id) <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a deal patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_org_check BEFORE INSERT OR UPDATE ON deal_contact
  FOR EACH ROW EXECUTE FUNCTION deal_contact_org_check();

-- ============================================================================
-- Firma: krajina a identifikátor
-- ============================================================================

ALTER TABLE company ADD COLUMN country country_code;
UPDATE company c SET country = o.country FROM org o WHERE o.id = c.org_id;
ALTER TABLE company ALTER COLUMN country SET NOT NULL;
COMMENT ON COLUMN company.country IS 'krajina firmy (predvolene krajina spoločnosti); určuje identifikátor v stĺpci ico';
COMMENT ON COLUMN company.ico IS 'identifikátor podľa krajiny: SK, CZ = IČO 8 číslic vrátane úvodných núl; HR = OIB 11 číslic';

CREATE FUNCTION company_country_default() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.country IS NULL THEN
    SELECT o.country INTO NEW.country FROM org o WHERE o.id = NEW.org_id;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_country_default BEFORE INSERT ON company
  FOR EACH ROW EXECUTE FUNCTION company_country_default();

ALTER TABLE company DROP CONSTRAINT company_ico_format_check;
ALTER TABLE company ADD CONSTRAINT company_ico_format_check CHECK (
     (country IN ('SK', 'CZ') AND ico ~ '^[0-9]{8}$')
  OR (country = 'HR' AND ico ~ '^[0-9]{11}$'));
DROP INDEX company_ico_key;
CREATE UNIQUE INDEX company_country_ico_key ON company (country, ico);

-- ============================================================================
-- Číselníky na Zákazníkoch: roly kontaktu, zdroj kontaktu
-- ============================================================================

ALTER TABLE company_contact
  ALTER COLUMN roles DROP DEFAULT,
  ALTER COLUMN roles TYPE text[] USING roles::text[],
  ALTER COLUMN roles SET DEFAULT '{}';
DROP TYPE company_role;
COMMENT ON COLUMN company_contact.roles IS 'roly osoby vo firme, kódy z číselníka rola_kontaktu (aj viac naraz)';
COMMENT ON COLUMN contact.source IS 'zdroj kontaktu, kód z číselníka zdroj_kontaktu';

-- Osoba vo firme: rovnaká spoločnosť, roly z číselníka
CREATE FUNCTION company_contact_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_org uuid := (SELECT org_id FROM company WHERE id = NEW.company_id);
BEGIN
  IF v_org <> (SELECT org_id FROM contact WHERE id = NEW.contact_id) THEN
    RAISE EXCEPTION 'Osoba a firma patria rôznym spoločnostiam (osoba v inej spoločnosti = nový záznam).'
      USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_kontaktu', v_org, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON company_contact
  FOR EACH ROW EXECUTE FUNCTION company_contact_check();

CREATE FUNCTION contact_source_check() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.source IS NOT NULL THEN
    PERFORM lookup_codes_check('zdroj_kontaktu', NEW.org_id, ARRAY[NEW.source],
                               CASE WHEN TG_OP = 'UPDATE' THEN ARRAY[OLD.source] END);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_source_check BEFORE INSERT OR UPDATE OF source, org_id ON contact
  FOR EACH ROW EXECUTE FUNCTION contact_source_check();

-- ============================================================================
-- RLS podľa tímu a spoločnosti (nahrádza 0005)
-- ============================================================================

DROP POLICY company_contact_access ON company_contact;
DROP POLICY contact_access ON contact;
DROP POLICY company_access ON company;
DROP VIEW contact_v;
DROP VIEW customer_v;
DROP FUNCTION company_ico_check(text);
DROP FUNCTION contact_duplicate_check(text, text);

-- Prístup k jednej firme / osobe (pre väzby a kontrolu duplicít; v politikách firmy a osoby
-- je to isté rozpísané, aby sa práva vyhodnotili raz na dopyt, nie pre každý riadok).
CREATE FUNCTION crm_company_access(p_company_id uuid, p_action text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM company c
     WHERE c.id = p_company_id
       AND c.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje' AND c.owner_id = crm_active_user_id())))
$$;

-- Osoba je kontaktom firmy, ktorú vlastní prihlásený
CREATE FUNCTION crm_contact_on_own_company(p_contact_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                  WHERE cc.contact_id = p_contact_id
                    AND c.owner_id = crm_active_user_id()
                    AND c.org_id = ANY (crm_user_orgs()))
$$;

CREATE FUNCTION crm_contact_access(p_contact_id uuid, p_action text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (
    SELECT 1 FROM contact p
     WHERE p.id = p_contact_id
       AND p.org_id = ANY (crm_user_orgs())
       AND (crm_scope('zakaznici', p_action) = 'vsetko'
            OR (crm_scope('zakaznici', p_action) = 'iba_svoje'
                AND (p.owner_id = crm_active_user_id() OR crm_contact_on_own_company(p.id)))))
$$;

-- Firma
CREATE POLICY customer_select ON company FOR SELECT USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'view')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'view')) = 'iba_svoje' AND owner_id = (SELECT crm_active_user_id()))));
CREATE POLICY customer_insert ON company FOR INSERT WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje' AND owner_id = (SELECT crm_active_user_id()))));
CREATE POLICY customer_update ON company FOR UPDATE USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje' AND owner_id = (SELECT crm_active_user_id()))))
WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje' AND owner_id = (SELECT crm_active_user_id()))));
-- DELETE: bez politiky = aplikácia firmy nemaže (archivujú sa)

-- Osoba
CREATE POLICY customer_select ON contact FOR SELECT USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'view')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'view')) = 'iba_svoje'
           AND (owner_id = (SELECT crm_active_user_id()) OR crm_contact_on_own_company(id)))));
CREATE POLICY customer_insert ON contact FOR INSERT WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje' AND owner_id = (SELECT crm_active_user_id()))));
CREATE POLICY customer_update ON contact FOR UPDATE USING (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje'
           AND (owner_id = (SELECT crm_active_user_id()) OR crm_contact_on_own_company(id)))))
WITH CHECK (
  org_id = ANY ((SELECT crm_user_orgs())::uuid[])
  AND ((SELECT crm_scope('zakaznici', 'edit')) = 'vsetko'
       OR ((SELECT crm_scope('zakaznici', 'edit')) = 'iba_svoje'
           AND (owner_id = (SELECT crm_active_user_id()) OR crm_contact_on_own_company(id)))));

-- Osoba vo firme: podľa prístupu k firme
CREATE POLICY customer_select ON company_contact FOR SELECT USING (crm_company_access(company_id, 'view'));
CREATE POLICY customer_insert ON company_contact FOR INSERT WITH CHECK (crm_company_access(company_id, 'edit'));
CREATE POLICY customer_update ON company_contact FOR UPDATE
  USING (crm_company_access(company_id, 'edit')) WITH CHECK (crm_company_access(company_id, 'edit'));
CREATE POLICY customer_delete ON company_contact FOR DELETE USING (crm_company_access(company_id, 'edit'));

-- Prechodné funkcie z 0005/0006 už nie sú potrebné
DROP FUNCTION crm_external_sees_contact(uuid);
DROP FUNCTION crm_external_owns_company(uuid);
DROP FUNCTION crm_external_user_id();
DROP FUNCTION crm_sees_all();

-- ============================================================================
-- Pohľady (ako v 0004, navyše org_id a krajina; filter domácností podľa práv tímu)
-- ============================================================================

CREATE VIEW customer_v WITH (security_invoker = true) AS
WITH oom_sum AS (
  SELECT o.company_id, o.person_id,
         count(*) FILTER (WHERE o.status = 'aktivne') AS active_oom_count,
         sum(coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0))
           FILTER (WHERE o.status = 'aktivne') AS annual_mwh
    FROM oom o
   GROUP BY o.company_id, o.person_id
), last_activity AS (
  SELECT a.company_id, a.contact_id, max(a.occurred_at) AS last_activity_at
    FROM activity a
   GROUP BY a.company_id, a.contact_id
)
SELECT c.id,
       'B2B'::text AS customer_type,
       c.id        AS company_id,
       NULL::uuid  AS person_id,
       c.name,
       c.ico,
       NULL::text  AS email,
       c.status,
       c.status_source,
       c.is_former_customer,
       c.is_producer,
       CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
       c.owner_id,
       coalesce(s.active_oom_count, 0) AS active_oom_count,
       coalesce(s.annual_mwh, 0)       AS annual_mwh,
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.company_id = c.id) AS last_activity_at,
       company_is_archived(c) AS archived,
       c.org_id,
       c.country
  FROM company c
  LEFT JOIN oom_sum s ON s.company_id = c.id
 WHERE c.is_customer
UNION ALL
SELECT p.id,
       'B2C'::text,
       NULL::uuid,
       p.id,
       concat_ws(' ', p.first_name, p.last_name),
       NULL::text,
       p.email,
       p.status,
       p.status_source,
       p.is_former_customer,
       p.is_producer,
       CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END,
       p.owner_id,
       coalesce(s.active_oom_count, 0),
       coalesce(s.annual_mwh, 0),
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.contact_id = p.id),
       p.status IS NOT DISTINCT FROM 'zruseny_zakaznik',
       p.org_id,
       NULL::country_code
  FROM contact p
  LEFT JOIN oom_sum s ON s.person_id = p.id
 WHERE p.is_household
   -- „iba svoje“ vidí domácnosť iba ako jej vlastník (nie osobu, ktorá je len kontaktom na jeho firme)
   AND ((SELECT crm_scope('zakaznici', 'view')) = 'vsetko' OR p.owner_id = (SELECT crm_active_user_id()));

COMMENT ON VIEW customer_v IS 'zoznam Zákazníci: firmy s is_customer a osoby s is_household; archived = zrušený zákazník';

CREATE VIEW contact_v WITH (security_invoker = true) AS
SELECT p.*,
       x.archived,
       (NOT x.archived AND p.marketing_opt_out_at IS NULL) AS marketing_allowed
  FROM contact p
  CROSS JOIN LATERAL (
    SELECT NOT (p.is_household AND p.status IS DISTINCT FROM 'zruseny_zakaznik')
           AND NOT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                            WHERE cc.contact_id = p.id AND NOT company_is_archived(c))
           AND (p.is_household OR EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id))
           AS archived
  ) x;

COMMENT ON VIEW contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';

-- ============================================================================
-- Kontrola duplicít (zadanie Zákazníci čl. 7, 12): iba „existuje“, vlastník a spoločnosť
-- ============================================================================

-- Firma je v CRM raz: IČO / OIB sa hľadá v rámci krajiny, vo všetkých spoločnostiach.
-- company_id vráti iba tomu, kto firmu vidí.
-- Príklad: SELECT * FROM company_ico_check('SK', '123456') → nájde IČO 00123456.
CREATE FUNCTION company_ico_check(p_country country_code, p_ico text)
RETURNS TABLE (company_exists boolean, company_id uuid, owner_name text, org_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT true,
         CASE WHEN crm_company_access(c.id, 'view') THEN c.id END,
         u.name,
         o.legal_name
    FROM company c
    JOIN org o ON o.id = c.org_id
    LEFT JOIN app_user u ON u.id = c.owner_id
   WHERE c.country = p_country
     AND c.ico = CASE WHEN p_country = 'HR' THEN regexp_replace(p_ico, '[^0-9]', '', 'g')
                      ELSE lpad(regexp_replace(p_ico, '[^0-9]', '', 'g'), 8, '0') END
$$;

-- Osoba: zhoda podľa e-mailu, potom telefónu, iba v rámci spoločnosti (Peter 12. 10., odpoveď 1).
-- contact_id vráti iba tomu, kto osobu vidí; inak iba „osoba už existuje, vlastník X“.
CREATE FUNCTION contact_duplicate_check(p_email text, p_phone text, p_org_id uuid DEFAULT NULL)
RETURNS TABLE (match_on text, contact_id uuid, owner_name text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT m.match_on,
         CASE WHEN crm_contact_access(p.id, 'view') THEN p.id END,
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
   WHERE p.org_id = coalesce(p_org_id, crm_default_org())
   ORDER BY m.match_on, p.created_at
$$;

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM org o WHERE NOT o.is_default
              AND (EXISTS (SELECT 1 FROM company c WHERE c.org_id = o.id)
                   OR EXISTS (SELECT 1 FROM contact p WHERE p.org_id = o.id)))
     OR EXISTS (SELECT 1 FROM company WHERE country <> 'SK') THEN
    RAISE EXCEPTION 'Návrat 0008: existujú záznamy inej spoločnosti alebo krajiny ako SK.';
  END IF;
END;
$$;

DROP FUNCTION IF EXISTS contact_duplicate_check(text, text, uuid);
DROP FUNCTION IF EXISTS company_ico_check(country_code, text);
DROP VIEW IF EXISTS contact_v;
DROP VIEW IF EXISTS customer_v;

DROP POLICY IF EXISTS customer_delete ON company_contact;
DROP POLICY IF EXISTS customer_update ON company_contact;
DROP POLICY IF EXISTS customer_insert ON company_contact;
DROP POLICY IF EXISTS customer_select ON company_contact;
DROP POLICY IF EXISTS customer_update ON contact;
DROP POLICY IF EXISTS customer_insert ON contact;
DROP POLICY IF EXISTS customer_select ON contact;
DROP POLICY IF EXISTS customer_update ON company;
DROP POLICY IF EXISTS customer_insert ON company;
DROP POLICY IF EXISTS customer_select ON company;
DROP FUNCTION IF EXISTS crm_contact_access(uuid, text);
DROP FUNCTION IF EXISTS crm_contact_on_own_company(uuid);
DROP FUNCTION IF EXISTS crm_company_access(uuid, text);

-- prechodné funkcie a politiky 0005 (stav po 0006)
CREATE FUNCTION crm_sees_all() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT crm_scope('zakaznici', 'view') = 'vsetko'
$$;
CREATE FUNCTION crm_external_user_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT CASE WHEN crm_scope('zakaznici', 'view') = 'iba_svoje' THEN crm_active_user_id() END
$$;
CREATE FUNCTION crm_external_owns_company(p_company_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company c
                  WHERE c.id = p_company_id AND c.owner_id = crm_external_user_id())
$$;
CREATE FUNCTION crm_external_sees_contact(p_contact_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                  WHERE cc.contact_id = p_contact_id AND c.owner_id = crm_external_user_id())
$$;

CREATE POLICY company_access ON company
  USING ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()))
  WITH CHECK ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()));
CREATE POLICY contact_access ON contact
  USING ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()) OR crm_external_sees_contact(id))
  WITH CHECK ((SELECT crm_sees_all()) OR owner_id = (SELECT crm_external_user_id()) OR crm_external_sees_contact(id));
CREATE POLICY company_contact_access ON company_contact
  USING ((SELECT crm_sees_all()) OR crm_external_owns_company(company_id))
  WITH CHECK ((SELECT crm_sees_all()) OR crm_external_owns_company(company_id));

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

-- Číselníky na Zákazníkoch
DROP TRIGGER IF EXISTS trg_source_check ON contact;
DROP FUNCTION IF EXISTS contact_source_check();
DROP TRIGGER IF EXISTS trg_check ON company_contact;
DROP FUNCTION IF EXISTS company_contact_check();
CREATE TYPE company_role AS ENUM ('statutar', 'decision_maker', 'kontaktna_osoba', 'fakturacia', 'technik');
ALTER TABLE company_contact
  ALTER COLUMN roles DROP DEFAULT,
  ALTER COLUMN roles TYPE company_role[] USING roles::company_role[],
  ALTER COLUMN roles SET DEFAULT '{}';
COMMENT ON COLUMN company_contact.roles IS 'roly osoby vo firme, aj viac naraz';
COMMENT ON COLUMN contact.source IS NULL;

-- Krajina a identifikátor
DROP INDEX IF EXISTS company_country_ico_key;
CREATE UNIQUE INDEX company_ico_key ON company (ico);
ALTER TABLE company DROP CONSTRAINT company_ico_format_check;
ALTER TABLE company ADD CONSTRAINT company_ico_format_check CHECK (ico ~ '^[0-9]{8}$');
COMMENT ON COLUMN company.ico IS 'IČO, 8 číslic vrátane úvodných núl';
DROP TRIGGER IF EXISTS trg_country_default ON company;
DROP FUNCTION IF EXISTS company_country_default();
ALTER TABLE company DROP COLUMN country;

-- Spoločnosť na záznamoch
DROP TRIGGER IF EXISTS trg_org_check ON deal_contact;
DROP FUNCTION IF EXISTS deal_contact_org_check();
DROP TRIGGER IF EXISTS trg_customer_org_guard ON contact;
DROP TRIGGER IF EXISTS trg_customer_org_guard ON company;
DROP FUNCTION IF EXISTS customer_org_guard();
DROP TRIGGER IF EXISTS trg_record_org ON offer;
DROP TRIGGER IF EXISTS trg_record_org ON contract;
DROP TRIGGER IF EXISTS trg_record_org ON deal;
DROP TRIGGER IF EXISTS trg_record_org ON oom;
DROP FUNCTION IF EXISTS record_org_fill();
ALTER TABLE offer DROP COLUMN org_id;
ALTER TABLE contract DROP COLUMN org_id;
ALTER TABLE deal DROP COLUMN org_id;
ALTER TABLE oom DROP COLUMN org_id;
ALTER TABLE contact DROP COLUMN org_id;
ALTER TABLE company DROP COLUMN org_id;

-- pohľady z 0004 (stav po 0007: stĺpec custom ostáva v contact.*)
CREATE VIEW customer_v WITH (security_invoker = true) AS
WITH oom_sum AS (
  SELECT o.company_id, o.person_id,
         count(*) FILTER (WHERE o.status = 'aktivne') AS active_oom_count,
         sum(coalesce(o.planned_consumption_vt_mwh, 0) + coalesce(o.planned_consumption_nt_mwh, 0))
           FILTER (WHERE o.status = 'aktivne') AS annual_mwh
    FROM oom o
   GROUP BY o.company_id, o.person_id
), last_activity AS (
  SELECT a.company_id, a.contact_id, max(a.occurred_at) AS last_activity_at
    FROM activity a
   GROUP BY a.company_id, a.contact_id
)
SELECT c.id, 'B2B'::text AS customer_type, c.id AS company_id, NULL::uuid AS person_id, c.name, c.ico,
       NULL::text AS email, c.status, c.status_source, c.is_former_customer, c.is_producer,
       CASE WHEN c.is_producer THEN 'Firma · výrobca' ELSE 'Firma' END AS segment_label,
       c.owner_id, coalesce(s.active_oom_count, 0) AS active_oom_count, coalesce(s.annual_mwh, 0) AS annual_mwh,
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.company_id = c.id) AS last_activity_at,
       company_is_archived(c) AS archived
  FROM company c
  LEFT JOIN oom_sum s ON s.company_id = c.id
 WHERE c.is_customer
UNION ALL
SELECT p.id, 'B2C'::text, NULL::uuid, p.id, concat_ws(' ', p.first_name, p.last_name), NULL::text, p.email,
       p.status, p.status_source, p.is_former_customer, p.is_producer,
       CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END,
       p.owner_id, coalesce(s.active_oom_count, 0), coalesce(s.annual_mwh, 0),
       (SELECT max(la.last_activity_at) FROM last_activity la WHERE la.contact_id = p.id),
       p.status IS NOT DISTINCT FROM 'zruseny_zakaznik'
  FROM contact p
  LEFT JOIN oom_sum s ON s.person_id = p.id
 WHERE p.is_household
   AND ((SELECT crm_sees_all()) OR p.owner_id = (SELECT crm_external_user_id()));
COMMENT ON VIEW customer_v IS 'zoznam Zákazníci: firmy s is_customer a osoby s is_household; archived = zrušený zákazník';

CREATE VIEW contact_v WITH (security_invoker = true) AS
SELECT p.*,
       x.archived,
       (NOT x.archived AND p.marketing_opt_out_at IS NULL) AS marketing_allowed
  FROM contact p
  CROSS JOIN LATERAL (
    SELECT NOT (p.is_household AND p.status IS DISTINCT FROM 'zruseny_zakaznik')
           AND NOT EXISTS (SELECT 1 FROM company_contact cc JOIN company c ON c.id = cc.company_id
                            WHERE cc.contact_id = p.id AND NOT company_is_archived(c))
           AND (p.is_household OR EXISTS (SELECT 1 FROM company_contact cc WHERE cc.contact_id = p.id))
           AS archived
  ) x;
COMMENT ON VIEW contact_v IS 'zoznam Kontakty: archived = skryť z Kontaktov, vyhľadávania a marketingu (čl. 4, 13)';
