-- 0013_oom_jadro.sql – modul Odberné miesta: jadro (docs/moduly/02-odberne-miesta-navrh-db.md v0.2, časti 1, 2, 3.1, 4–6)
--
-- Stav OOM „Neaktívne“ sa premenuje na „Pripravované“ (zadanie OOM čl. 4, Zákazníci čl. 14).
-- Typ OOM „veľkoobchod“ sa ruší (Peter 12. 10.): ostáva spotreba, výroba, sharing; veľkoobchod = položky zmluvy bez OOM (moduly 4, 5).
-- Väzba OOM – zákazník v čase (oom_customer): obdobie od – do, stav OOM pre daného zákazníka, dôvod ukončenia.
--   Odchod, zrušenie a prepis väzbu uzavrú; novú väzbu založí prepis alebo návrat (Peter 12. 10., odpoveď 1).
--   oom.company_id / person_id / status zrkadlia poslednú väzbu; menia sa iba cez väzbu (funkcie nižšie).
-- Výpočet stavu zákazníka a príznaku „bývalý“ z väzieb (customer_status_calc, customer_is_former_calc).
-- Prechod k Greenlogy: kroky s dátumami; lehoty „prechod sa zasekol“ nastaví admin pri spoločnosti.
-- Číselníky OOM (PDS s IČO, sadzby podľa PDS, fakturácia, meranie, typ výkupnej zmluvy, roly pri OOM); druh zdroja + biomasa.
-- Kontrola EIC (ENTSO-E, kontrolná číslica), povinné údaje pri prechode do stavu Aktívne.
-- Kontaktné osoby pri OOM (oom_contact).
-- RLS, priebežný prepočet stavu, pohľady a import sú v 0014 a 0015.
--
-- Predpoklad: tabuľka oom je prázdna (Test vyprázdnený 12. 10.; main je prázdny).

-- migrate:up

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM oom) THEN
    RAISE EXCEPTION 'Migrácia 0013 vyžaduje prázdnu tabuľku oom.';
  END IF;
END;
$$;

-- Neprekrývanie období väzby (EXCLUDE s uuid)
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Dnešný dátum v Europe/Bratislava
CREATE FUNCTION crm_today() RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT (now() AT TIME ZONE 'Europe/Bratislava')::date
$$;

-- ============================================================================
-- Stav a enumy
-- ============================================================================

ALTER TYPE oom_status RENAME VALUE 'neaktivne' TO 'pripravovane';

-- Typ veľkoobchod sa ruší (virtuálne OOM z HubSpotu bez skutočného EIC; Peter 12. 10.)
ALTER TYPE oom_type RENAME TO oom_type_old;
CREATE TYPE oom_type AS ENUM ('spotreba', 'vyroba', 'sharing');
ALTER TABLE oom ALTER COLUMN type TYPE oom_type USING type::text::oom_type;
DROP TYPE oom_type_old;

CREATE TYPE oom_link_end_reason AS ENUM ('odchod', 'zrusenie', 'prepis');
CREATE TYPE oom_source_category AS ENUM ('maly_zdroj', 'lokalny_zdroj', 'vyrobny_zdroj');
CREATE TYPE voltage_level AS ENUM ('nn', 'vn', 'vvn');
CREATE TYPE oom_contact_source AS ENUM ('rucne', 'zmluva');
-- Bioplyn a biomasa sú dva rôzne zdroje (Peter 12. 10.)
ALTER TYPE source_kind ADD VALUE 'biomasa' AFTER 'bioplyn';

-- ============================================================================
-- Úprava stĺpcov oom
-- ============================================================================

ALTER TABLE oom
  DROP COLUMN segment,                                  -- segment patrí zákazníkovi
  DROP COLUMN source_type,                              -- nahrádza source_category (VB a VIWA sú produkty)
  DROP COLUMN previous_supplier_notice,                 -- nahrádzajú kroky prechodu
  DROP COLUMN previous_supplier_notice_accepted_at,
  ADD COLUMN source_category            oom_source_category,
  ADD COLUMN advance_payment_eur        numeric(12,2) CHECK (advance_payment_eur >= 0),
  ADD COLUMN previous_supplier          text,
  ADD COLUMN switch_notice_required     boolean NOT NULL DEFAULT true,
  ADD COLUMN switch_notice_sent_on      date,
  ADD COLUMN switch_notice_accepted_on  date,
  ADD COLUMN switch_confirmed_on        date;
DROP TYPE source_type;
DROP TYPE previous_supplier_notice;

ALTER TABLE oom ALTER COLUMN voltage_level TYPE voltage_level USING NULL::voltage_level;

ALTER TABLE oom
  ADD CONSTRAINT oom_phases_check CHECK (phases IN (1, 3)),
  ADD CONSTRAINT oom_advance_pct_check CHECK (advance_payment_pct BETWEEN 0 AND 100),
  -- kroky prechodu po poradí; bez výpovede (nová prípojka) sa výpoveď nezadáva
  ADD CONSTRAINT oom_switch_steps_check CHECK (
        (switch_notice_required OR (switch_notice_sent_on IS NULL AND switch_notice_accepted_on IS NULL))
    AND (switch_notice_accepted_on IS NULL
         OR (switch_notice_sent_on IS NOT NULL AND switch_notice_accepted_on >= switch_notice_sent_on))
    AND (switch_confirmed_on IS NULL OR NOT switch_notice_required
         OR (switch_notice_accepted_on IS NOT NULL AND switch_confirmed_on >= switch_notice_accepted_on)));

COMMENT ON COLUMN oom.company_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';
COMMENT ON COLUMN oom.person_id IS 'zákazník poslednej väzby (oom_customer); mení sa iba cez väzbu';
COMMENT ON COLUMN oom.status IS 'stav poslednej väzby (oom_customer); mení sa iba cez väzbu';
COMMENT ON COLUMN oom.pds IS 'kód z číselníka pds';
COMMENT ON COLUMN oom.pds_tariff IS 'kód z číselníka sadzba_distribucie (sadzba zvoleného PDS)';
COMMENT ON COLUMN oom.metering_type IS 'kód z číselníka typ_merania';
COMMENT ON COLUMN oom.billing_period IS 'kód z číselníka fakturacne_obdobie';
COMMENT ON COLUMN oom.advance_payment_method IS 'kód z číselníka sposob_zaloh';
COMMENT ON COLUMN oom.feed_in_contract_type IS 'kód z číselníka typ_vykupnej_zmluvy';
COMMENT ON COLUMN oom.previous_supplier IS 'kód z číselníka predchadzajuci_dodavatel';
COMMENT ON COLUMN oom.source_category IS 'kategória zdroja podľa zákona (zadanie OOM čl. 7)';
COMMENT ON COLUMN oom.switch_notice_required IS 'false = výpoveď predošlému dodávateľovi sa nezasiela (napr. nová prípojka)';
COMMENT ON COLUMN oom.switch_notice_sent_on IS 'prechod, krok 1: výpoveď predošlému dodávateľovi odoslaná';
COMMENT ON COLUMN oom.switch_notice_accepted_on IS 'prechod, krok 2: výpoveď akceptovaná';
COMMENT ON COLUMN oom.switch_confirmed_on IS 'prechod, krok 3: zmena dodávateľa potvrdená; krok 4 = supply_from';

-- Lehoty „prechod sa zasekol“ podľa spoločnosti (Peter 12. 10., odpoveď 3)
ALTER TABLE org
  ADD COLUMN oom_switch_accept_days  smallint NOT NULL DEFAULT 14 CHECK (oom_switch_accept_days BETWEEN 1 AND 365),
  ADD COLUMN oom_switch_confirm_days smallint NOT NULL DEFAULT 14 CHECK (oom_switch_confirm_days BETWEEN 1 AND 365);
COMMENT ON COLUMN org.oom_switch_accept_days IS 'prechod sa zasekol: dni od odoslania výpovede bez akceptácie';
COMMENT ON COLUMN org.oom_switch_confirm_days IS 'prechod sa zasekol: dni od akceptácie výpovede bez potvrdenia zmeny dodávateľa';

-- ============================================================================
-- EIC
-- ============================================================================

-- Kód EIC (ENTSO-E): 16 znakov [0-9A-Z-], posledný je kontrolná číslica.
-- Hodnoty znakov 0–9 = 0–9, A–Z = 10–35, '-' = 36; váhy 16 až 2; kontrola = 36 − ((súčet − 1) mod 37).
-- Spoločné pre SK (24…), CZ (27…) aj HR (31…).
CREATE FUNCTION eic_is_valid(p text) RETURNS boolean
LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE AS $$
DECLARE
  v_chars constant text := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';
  v_sum   integer := 0;
BEGIN
  IF p IS NULL OR p !~ '^[0-9A-Z-]{15}[0-9A-Z]$' THEN
    RETURN false;
  END IF;
  FOR i IN 1..15 LOOP
    v_sum := v_sum + (strpos(v_chars, substr(p, i, 1)) - 1) * (17 - i);
  END LOOP;
  RETURN substr(v_chars, 36 - (((v_sum - 1) % 37 + 37) % 37) + 1, 1) = substr(p, 16, 1);
END;
$$;
COMMENT ON FUNCTION eic_is_valid(text) IS 'formát a kontrolná číslica EIC podľa ENTSO-E';

-- Normalizácia pred uložením: veľké písmená, bez medzier
CREATE FUNCTION oom_eic_normalize() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.eic := upper(regexp_replace(NEW.eic, '\s', '', 'g'));
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_oom_eic BEFORE INSERT OR UPDATE OF eic ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_eic_normalize();

ALTER TABLE oom ADD CONSTRAINT oom_eic_check CHECK (eic_is_valid(eic));

-- ============================================================================
-- Číselníky OOM
-- ============================================================================

-- Hodnota môže patriť nadradenej hodnote iného zoznamu (sadzba → PDS).
ALTER TABLE lookup_list ADD COLUMN parent_list text REFERENCES lookup_list (code);
ALTER TABLE lookup_value ADD COLUMN parent_code text;
ALTER TABLE lookup_value ADD COLUMN reg_no text CHECK (reg_no ~ '^[0-9]{8}$');
COMMENT ON COLUMN lookup_value.reg_no IS 'IČO (pri PDS – prevádzkovateľ distribučnej sústavy)';
COMMENT ON COLUMN lookup_list.parent_list IS 'zoznam nadradených hodnôt (napr. sadzby distribúcie → pds)';
COMMENT ON COLUMN lookup_value.parent_code IS 'kód nadradenej hodnoty zo zoznamu lookup_list.parent_list; nemení sa';

DROP INDEX lookup_value_label_key;
CREATE UNIQUE INDEX lookup_value_label_key ON lookup_value (list_code, org_id, parent_code, lower(label)) NULLS NOT DISTINCT;

-- Ako v 0007, navyše nadradená hodnota: povinná práve v zozname s parent_list, existuje, nemení sa;
-- kód hodnoty s nadradenou vznikne z oboch (napr. ssd_dd2), aby bol unikátny v zozname.
CREATE OR REPLACE FUNCTION lookup_value_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_parent_list text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Hodnota číselníka sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    SELECT parent_list INTO v_parent_list FROM lookup_list WHERE code = NEW.list_code;
    IF (v_parent_list IS NULL) <> (NEW.parent_code IS NULL) THEN
      RAISE EXCEPTION 'Hodnota zoznamu % % nadradenú hodnotu.', NEW.list_code,
        CASE WHEN v_parent_list IS NULL THEN 'nemá' ELSE 'musí mať' END USING ERRCODE = 'check_violation';
    END IF;
    IF v_parent_list IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM lookup_value WHERE list_code = v_parent_list AND code = NEW.parent_code) THEN
      RAISE EXCEPTION 'Nadradená hodnota „%“ nie je v číselníku %.', NEW.parent_code, v_parent_list
        USING ERRCODE = 'foreign_key_violation';
    END IF;
    NEW.code := coalesce(NEW.code, crm_slug(concat_ws('_', NEW.parent_code, NEW.label)));
    RETURN NEW;
  END IF;
  IF NEW.code <> OLD.code OR NEW.list_code <> OLD.list_code OR NEW.is_system <> OLD.is_system
     OR NEW.parent_code IS DISTINCT FROM OLD.parent_code THEN
    RAISE EXCEPTION 'Kód, zoznam, nadradená hodnota a systémový príznak hodnoty číselníka sa nemenia.'
      USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.is_system AND (NEW.label <> OLD.label OR NEW.hidden_at IS NOT NULL
                        OR NEW.org_id IS DISTINCT FROM OLD.org_id) THEN
    RAISE EXCEPTION 'Systémová hodnota „%“ sa nedá premenovať ani skryť.', OLD.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

INSERT INTO lookup_list (code, name, used_on) VALUES
  ('pds',                 'Prevádzkovateľ distribučnej sústavy (PDS)', 'odberné miesto'),
  ('fakturacne_obdobie',  'Fakturačné obdobie',                        'odberné miesto'),
  ('sposob_zaloh',        'Spôsob záloh',                              'odberné miesto'),
  ('typ_merania',         'Typ merania',                               'odberné miesto'),
  ('typ_vykupnej_zmluvy', 'Typ výkupnej zmluvy',                       'odberné miesto'),
  ('rola_pri_oom',        'Rola kontaktnej osoby pri odbernom mieste', 'odberné miesto – osoba');
INSERT INTO lookup_list (code, name, used_on, parent_list) VALUES
  ('sadzba_distribucie',  'Sadzba distribúcie',                        'odberné miesto', 'pds');

-- Hodnoty podľa použitia v HubSpote, vyčistené Petrom 12. 10. 2026 (exports/modul2-oom: pds-zoznam.md,
-- matica-pds-sadzba.md, prehlad-hodnot.md). hubspot_value = zápis v HubSpote (pri zlúčených PDS najčastejší).
INSERT INTO lookup_value (list_code, code, label, sort_order, hubspot_value) VALUES
  ('fakturacne_obdobie', 'mesacne',            'Mesačne',                                    1, 'Mesiac'),
  ('fakturacne_obdobie', 'rocne',              'Ročne',                                      2, 'Rok'),
  ('fakturacne_obdobie', 'rocne_s_odkladom',   'Ročne s odkladom k termínu odpočtu',         3, 'Ročne (s odkladom k termínu odpočtu)'),
  ('sposob_zaloh', 'bez_zaloh',                        'Bez záloh',                            1, 'Bez záloh'),
  ('sposob_zaloh', 'splatkovy_kalendar_11_mesiacov',   'Splátkový kalendár 11 mesiacov',       2, 'Splátkový kalendár 11 mesiacov cezrok a prvý vysporiadanie'),
  ('sposob_zaloh', 'splatkovy_kalendar_do_konca_roka', 'Splátkový kalendár do konca roka',     3, 'Splátkový kalendár do konca roka'),
  ('sposob_zaloh', 'stvrtrocne_zalohy',                'Štvrťročné zálohy',                    4, 'Kvartálne'),
  ('sposob_zaloh', 'mesacne_zalohy',                   'Mesačné zálohy',                       5, 'Mesačné zálohy'),
  ('typ_merania', 'a', 'A',              1, 'Typ merania A'),
  ('typ_merania', 'b', 'B',              2, 'Typ merania B'),
  ('typ_merania', 'c', 'C',              3, 'Typ merania C'),
  ('typ_merania', 'n', 'N – nemerané',   4, 'N - Nemerané'),
  ('typ_vykupnej_zmluvy', 'lokalny_zdroj_eur',       'Lokálny zdroj [EUR]',               1, 'Lokálny zdroj [EUR]'),
  ('typ_vykupnej_zmluvy', 'lokalny_zdroj_pct',       'Lokálny zdroj [%]',                 2, 'Lokálny zdroj [%]'),
  ('typ_vykupnej_zmluvy', 'vyrobny_zdroj_aditiv_eur', 'Výrobný zdroj – cena Aditív [EUR]', 3, 'Výrobný zdroj - cena Aditív [EUR]'),
  ('typ_vykupnej_zmluvy', 'vyrobny_zdroj_aditiv_pct', 'Výrobný zdroj – cena Aditív [%]',   4, 'Výrobný zdroj - cena Aditív [%]'),
  ('typ_vykupnej_zmluvy', 'vyrobny_zdroj_fix_eur',   'Výrobný zdroj – cena Fix [EUR]',    5, 'Výrobný zdroj - cena Fix [EUR]'),
  ('rola_pri_oom', 'spravca_budovy',    'Správca budovy',    1, NULL),
  ('rola_pri_oom', 'technik_prevadzky', 'Technik prevádzky', 2, NULL),
  ('rola_pri_oom', 'kontaktna_osoba',   'Kontaktná osoba',   3, NULL);

-- PDS: ZSD, SSD, VSD + miestne DS (duplicitné zápisy zlúčené); IČO iba kde je známe (overiť).
-- Sadzby D1–D8, C1–C10, X2, X3, C2-X3 (iba ZSD), X3-C2 (iba VSD) pri PDS, kde sa v HubSpote použili.
INSERT INTO lookup_value (list_code, parent_code, code, label, sort_order, reg_no, hubspot_value) VALUES
  ('pds', NULL, 'zsd', 'ZSD', 1, '36361518', 'Západoslovenská distribučná, a.s.'),
  ('pds', NULL, 'ssd', 'SSD', 2, '36442151', 'Stredoslovenská distribučná, a.s.'),
  ('pds', NULL, 'vsd', 'VSD', 3, '36599361', 'Východoslovenská distribučná a.s.'),
  ('pds', NULL, 'enstra', 'ENSTRA a.s.', 4, NULL, 'ENSTRA a.s.'),
  ('pds', NULL, 'ppa_power_ds', 'PPA Power DS s. r. o.', 5, NULL, 'PPA POWER DS s.r.o.'),
  ('pds', NULL, 'ur_p6', 'UR P6', 6, NULL, 'UR P6 a.s.'),
  ('pds', NULL, 'energy_distribution', 'ENERGY DISTRIBUTION a.s.', 7, NULL, 'ENERGY DISTRIBUTION a.s.'),
  ('pds', NULL, 'komterm', 'KOMTERM Slovensko, a.s.', 8, NULL, 'KOMTERM Slovensko, a.s.'),
  ('pds', NULL, 'hec_services', 'HEC Services, s.r.o.', 9, NULL, 'HEC Services, s.r.o.'),
  ('pds', NULL, 'esco_ds', 'ESCO Distribučné sústavy a.s.', 10, NULL, 'ESCO Distribučné sústavy a.s.'),
  ('pds', NULL, 'chemosvit_energochem', 'CHEMOSVIT ENERGOCHEM, a.s.', 11, NULL, 'CHEMOSVIT ENERGOCHEM, a.s.'),
  ('pds', NULL, 'javys', 'Jadrová a vyraďovacia spoločnosť, a.s.', 12, '35946024', 'Jadrová a vyraďovacia spoločnosť, a.s.'),
  ('pds', NULL, 'bm_energy', 'BM Energy, s.r.o.', 13, NULL, 'BM Energy, s.r.o.'),
  ('pds', NULL, 'abb', 'AB&B, s. r. o.', 14, NULL, 'AB&B, s. r. o.'),
  ('pds', NULL, 'egrid_sk', 'eGrid SK s.r.o.', 15, NULL, 'eGrid SK s.r.o.'),
  ('pds', NULL, 'energy_one', 'ENERGY ONE, s. r. o.', 16, NULL, 'ENERGY ONE, s. r. o.'),
  ('pds', NULL, 'slovnaft', 'SLOVNAFT, a.s.', 17, '31322832', 'SLOVNAFT, a.s.'),
  ('sadzba_distribucie', 'zsd', 'zsd_d1', 'D1', 1, NULL, 'D1'),
  ('sadzba_distribucie', 'zsd', 'zsd_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'zsd', 'zsd_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'zsd', 'zsd_c1', 'C1', 9, NULL, 'C1'),
  ('sadzba_distribucie', 'zsd', 'zsd_c9', 'C9', 17, NULL, 'C9'),
  ('sadzba_distribucie', 'zsd', 'zsd_x2', 'X2', 19, NULL, 'X2'),
  ('sadzba_distribucie', 'zsd', 'zsd_c2_x3', 'C2-X3', 21, NULL, 'C2-X3'),
  ('sadzba_distribucie', 'ssd', 'ssd_d1', 'D1', 1, NULL, 'D1'),
  ('sadzba_distribucie', 'ssd', 'ssd_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'ssd', 'ssd_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'ssd', 'ssd_d4', 'D4', 4, NULL, 'D4'),
  ('sadzba_distribucie', 'ssd', 'ssd_d5', 'D5', 5, NULL, 'D5'),
  ('sadzba_distribucie', 'ssd', 'ssd_d6', 'D6', 6, NULL, 'D6'),
  ('sadzba_distribucie', 'ssd', 'ssd_d8', 'D8', 8, NULL, 'D8'),
  ('sadzba_distribucie', 'ssd', 'ssd_c1', 'C1', 9, NULL, 'C1'),
  ('sadzba_distribucie', 'ssd', 'ssd_c2', 'C2', 10, NULL, 'C2'),
  ('sadzba_distribucie', 'ssd', 'ssd_c3', 'C3', 11, NULL, 'C3'),
  ('sadzba_distribucie', 'ssd', 'ssd_c4', 'C4', 12, NULL, 'C4'),
  ('sadzba_distribucie', 'ssd', 'ssd_c5', 'C5', 13, NULL, 'C5'),
  ('sadzba_distribucie', 'ssd', 'ssd_c6', 'C6', 14, NULL, 'C6'),
  ('sadzba_distribucie', 'ssd', 'ssd_c7', 'C7', 15, NULL, 'C7'),
  ('sadzba_distribucie', 'ssd', 'ssd_c8', 'C8', 16, NULL, 'C8'),
  ('sadzba_distribucie', 'ssd', 'ssd_c9', 'C9', 17, NULL, 'C9'),
  ('sadzba_distribucie', 'ssd', 'ssd_c10', 'C10', 18, NULL, 'C10'),
  ('sadzba_distribucie', 'ssd', 'ssd_x2', 'X2', 19, NULL, 'X2'),
  ('sadzba_distribucie', 'vsd', 'vsd_d1', 'D1', 1, NULL, 'D1'),
  ('sadzba_distribucie', 'vsd', 'vsd_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'vsd', 'vsd_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'vsd', 'vsd_x2', 'X2', 19, NULL, 'X2'),
  ('sadzba_distribucie', 'vsd', 'vsd_x3_c2', 'X3-C2', 22, NULL, 'X3-C2'),
  ('sadzba_distribucie', 'enstra', 'enstra_d1', 'D1', 1, NULL, 'D1'),
  ('sadzba_distribucie', 'enstra', 'enstra_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'enstra', 'enstra_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'enstra', 'enstra_c2', 'C2', 10, NULL, 'C2'),
  ('sadzba_distribucie', 'enstra', 'enstra_x2', 'X2', 19, NULL, 'X2'),
  ('sadzba_distribucie', 'ppa_power_ds', 'ppa_power_ds_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'ppa_power_ds', 'ppa_power_ds_c1', 'C1', 9, NULL, 'C1'),
  ('sadzba_distribucie', 'ppa_power_ds', 'ppa_power_ds_c2', 'C2', 10, NULL, 'C2'),
  ('sadzba_distribucie', 'ppa_power_ds', 'ppa_power_ds_c3', 'C3', 11, NULL, 'C3'),
  ('sadzba_distribucie', 'energy_distribution', 'energy_distribution_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'komterm', 'komterm_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'komterm', 'komterm_c2', 'C2', 10, NULL, 'C2'),
  ('sadzba_distribucie', 'komterm', 'komterm_x2', 'X2', 19, NULL, 'X2'),
  ('sadzba_distribucie', 'esco_ds', 'esco_ds_d2', 'D2', 2, NULL, 'D2'),
  ('sadzba_distribucie', 'chemosvit_energochem', 'chemosvit_energochem_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'bm_energy', 'bm_energy_d3', 'D3', 3, NULL, 'D3'),
  ('sadzba_distribucie', 'energy_one', 'energy_one_d2', 'D2', 2, NULL, 'D2');

-- Kódy číselníkov na OOM; sadzba musí patriť zvolenému PDS.
CREATE FUNCTION oom_lookup_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_old oom;   -- pri INSERT prázdne: každý kód je nový (skrytý sa nedá vybrať)
BEGIN
  IF TG_OP = 'UPDATE' THEN
    v_old := OLD;
  END IF;
  IF NEW.pds IS NOT NULL THEN
    PERFORM lookup_codes_check('pds', NEW.org_id, ARRAY[NEW.pds], array_remove(ARRAY[v_old.pds], NULL));
  END IF;
  IF NEW.pds_tariff IS NOT NULL THEN
    PERFORM lookup_codes_check('sadzba_distribucie', NEW.org_id, ARRAY[NEW.pds_tariff], array_remove(ARRAY[v_old.pds_tariff], NULL));
    IF NOT EXISTS (SELECT 1 FROM lookup_value
                    WHERE list_code = 'sadzba_distribucie' AND code = NEW.pds_tariff
                      AND parent_code = NEW.pds) THEN
      RAISE EXCEPTION 'Sadzba distribúcie nepatrí zvolenému PDS.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  IF NEW.metering_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_merania', NEW.org_id, ARRAY[NEW.metering_type], array_remove(ARRAY[v_old.metering_type], NULL));
  END IF;
  IF NEW.billing_period IS NOT NULL THEN
    PERFORM lookup_codes_check('fakturacne_obdobie', NEW.org_id, ARRAY[NEW.billing_period], array_remove(ARRAY[v_old.billing_period], NULL));
  END IF;
  IF NEW.advance_payment_method IS NOT NULL THEN
    PERFORM lookup_codes_check('sposob_zaloh', NEW.org_id, ARRAY[NEW.advance_payment_method], array_remove(ARRAY[v_old.advance_payment_method], NULL));
  END IF;
  IF NEW.feed_in_contract_type IS NOT NULL THEN
    PERFORM lookup_codes_check('typ_vykupnej_zmluvy', NEW.org_id, ARRAY[NEW.feed_in_contract_type], array_remove(ARRAY[v_old.feed_in_contract_type], NULL));
  END IF;
  IF NEW.previous_supplier IS NOT NULL THEN
    PERFORM lookup_codes_check('predchadzajuci_dodavatel', NEW.org_id, ARRAY[NEW.previous_supplier], array_remove(ARRAY[v_old.previous_supplier], NULL));
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_oom_lookup BEFORE INSERT OR UPDATE ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_lookup_check();

-- ============================================================================
-- Povinné údaje pre stav Aktívne (zadanie OOM čl. 6; Peter 12. 10., otázka 5: sharing ako spotreba)
-- ============================================================================

-- Kontroluje sa iba pri prechode do stavu Aktívne; staršie záznamy sa neblokujú.
-- Výnimka: rola synchronizácie crm_sync (nahrávanie z HubSpotu – chýbajúce údaje rieši kontrolná tabuľka).
CREATE FUNCTION oom_active_required_missing(o oom) RETURNS text[]
LANGUAGE sql STABLE AS $$
  SELECT array_remove(ARRAY[
    CASE WHEN nullif(btrim(o.address_street), '') IS NULL AND nullif(btrim(o.address_city), '') IS NULL
         THEN 'ulica alebo obec' END,
    CASE WHEN nullif(btrim(o.address_zip), '') IS NULL THEN 'PSČ' END,
    CASE WHEN o.pds IS NULL THEN 'PDS' END,
    CASE WHEN o.voltage_level IS NULL THEN 'napäťová úroveň' END,
    CASE WHEN o.pds_tariff IS NULL THEN 'sadzba distribúcie' END,
    CASE WHEN o.supply_from IS NULL THEN 'dodávka od' END,
    CASE WHEN o.type IN ('spotreba', 'sharing')
          AND o.planned_consumption_vt_mwh IS NULL AND o.planned_consumption_nt_mwh IS NULL
         THEN 'plánovaná spotreba' END,
    CASE WHEN o.type = 'vyroba' AND o.planned_feed_in_mwh IS NULL THEN 'plánovaný výkup' END
  ], NULL)
$$;
COMMENT ON FUNCTION oom_active_required_missing(oom) IS 'chýbajúce povinné údaje pre stav Aktívne (prázdne pole = OK)';

CREATE FUNCTION oom_active_required_check() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_missing text[];
BEGIN
  IF NEW.status = 'aktivne' AND (TG_OP = 'INSERT' OR OLD.status <> 'aktivne') AND current_user <> 'crm_sync' THEN
    v_missing := oom_active_required_missing(NEW);
    IF cardinality(v_missing) > 0 THEN
      RAISE EXCEPTION 'Odberné miesto nemôže byť Aktívne, chýba: %.', array_to_string(v_missing, ', ')
        USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_oom_active_required BEFORE INSERT OR UPDATE ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_active_required_check();

-- ============================================================================
-- Väzba OOM – zákazník v čase
-- ============================================================================

CREATE TABLE oom_customer (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id      uuid NOT NULL REFERENCES oom (id),
  company_id  uuid REFERENCES company (id),
  person_id   uuid REFERENCES contact (id),
  org_id      uuid NOT NULL REFERENCES org (id),
  valid_from  date NOT NULL,
  valid_to    date,
  status      oom_status NOT NULL,
  end_reason  oom_link_end_reason,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT oom_customer_customer_check CHECK (num_nonnulls(company_id, person_id) = 1),
  CONSTRAINT oom_customer_period_check CHECK (valid_to IS NULL OR valid_to >= valid_from),
  -- otvorená väzba: Pripravované alebo Aktívne; uzavretá: dôvod určuje stav
  CONSTRAINT oom_customer_status_check CHECK (
    CASE
      WHEN valid_to IS NULL THEN end_reason IS NULL AND status IN ('pripravovane', 'aktivne')
      ELSE end_reason IS NOT NULL
           AND status = CASE end_reason WHEN 'odchod'   THEN 'odidene'::oom_status
                                        WHEN 'zrusenie' THEN 'zrusene'::oom_status
                                        WHEN 'prepis'   THEN 'prepisane'::oom_status END
    END),
  CONSTRAINT oom_customer_no_overlap EXCLUDE USING gist (
    oom_id WITH =, daterange(valid_from, valid_to, '[]') WITH &&)
);
CREATE UNIQUE INDEX oom_customer_one_open_key ON oom_customer (oom_id) WHERE valid_to IS NULL;
CREATE INDEX oom_customer_company_id_idx ON oom_customer (company_id);
CREATE INDEX oom_customer_person_id_idx ON oom_customer (person_id);
CREATE INDEX oom_customer_org_id_idx ON oom_customer (org_id);

COMMENT ON TABLE oom_customer IS 'komu OOM patrilo v ktorom období a v akom stave (zadanie OOM čl. 3–4); odchod, zrušenie a prepis väzbu uzavrú, prepis a návrat založia novú';
COMMENT ON COLUMN oom_customer.valid_to IS 'NULL = väzba trvá (Pripravované alebo Aktívne)';
COMMENT ON COLUMN oom_customer.status IS 'stav OOM pre tohto zákazníka v tomto období';

-- Väzba: spoločnosť = spoločnosť OOM a zákazníka; OOM a zákazník sa nemenia (zmena = nová väzba);
-- uzavretá väzba sa nemení (výnimka crm_sync); Aktívne sa nevracia na Pripravované.
CREATE FUNCTION oom_customer_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_customer_org uuid;
BEGIN
  NEW.org_id := (SELECT org_id FROM oom WHERE id = NEW.oom_id);
  v_customer_org := coalesce((SELECT org_id FROM company WHERE id = NEW.company_id),
                             (SELECT org_id FROM contact WHERE id = NEW.person_id));
  IF v_customer_org IS DISTINCT FROM NEW.org_id THEN
    RAISE EXCEPTION 'Odberné miesto a zákazník patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF NEW.oom_id <> OLD.oom_id OR NEW.company_id IS DISTINCT FROM OLD.company_id
       OR NEW.person_id IS DISTINCT FROM OLD.person_id THEN
      RAISE EXCEPTION 'Odberné miesto ani zákazník väzby sa nemenia (prepis = nová väzba).' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.valid_to IS NOT NULL AND current_user <> 'crm_sync' THEN
      RAISE EXCEPTION 'Uzavretá väzba sa nemení.' USING ERRCODE = 'check_violation';
    END IF;
    IF OLD.status = 'aktivne' AND NEW.status = 'pripravovane' THEN
      RAISE EXCEPTION 'Aktívne odberné miesto sa nevracia do stavu Pripravované.' USING ERRCODE = 'check_violation';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON oom_customer
  FOR EACH ROW EXECUTE FUNCTION oom_customer_check();

-- oom.company_id / person_id / status = posledná väzba (najneskorší valid_from).
CREATE FUNCTION oom_link_sync() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_oom_id uuid := coalesce(NEW.oom_id, OLD.oom_id);
  v_link   oom_customer;
BEGIN
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = v_oom_id ORDER BY valid_from DESC LIMIT 1;
  IF FOUND THEN
    UPDATE oom
       SET company_id = v_link.company_id, person_id = v_link.person_id, status = v_link.status
     WHERE id = v_oom_id
       AND (company_id, person_id, status) IS DISTINCT FROM (v_link.company_id, v_link.person_id, v_link.status);
  END IF;
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_link_sync AFTER INSERT OR UPDATE OR DELETE ON oom_customer
  FOR EACH ROW EXECUTE FUNCTION oom_link_sync();

-- Nové OOM: zákazník a stav (Pripravované alebo Aktívne) sa zadajú pri založení, prvú väzbu
-- založí databáza (od začiatku dodávky, ak už bol, inak od dnes). Neskôr sa zákazník a stav
-- menia iba cez väzbu (funkcie oom_set_status, oom_transfer, oom_reconnect).
CREATE FUNCTION oom_link_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status NOT IN ('pripravovane', 'aktivne') THEN
      RAISE EXCEPTION 'Nové odberné miesto je Pripravované alebo Aktívne.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF pg_trigger_depth() < 2
        AND (NEW.company_id IS DISTINCT FROM OLD.company_id OR NEW.person_id IS DISTINCT FROM OLD.person_id
             OR NEW.status IS DISTINCT FROM OLD.status) THEN
    RAISE EXCEPTION 'Zákazník a stav odberného miesta sa menia iba zmenou stavu alebo prepisom.'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_oom_link_guard BEFORE INSERT OR UPDATE ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_link_guard();

CREATE FUNCTION oom_first_link() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (NEW.id, NEW.company_id, NEW.person_id, NEW.org_id, least(NEW.supply_from, crm_today()), NEW.status);
  RETURN NULL;
END;
$$;
CREATE TRIGGER trg_oom_first_link AFTER INSERT ON oom
  FOR EACH ROW EXECUTE FUNCTION oom_first_link();

-- Zmena stavu (servis ručne; Aktívne aj denná aktivácia v 0014):
--   aktivne  – Pripravované → Aktívne (kontrola povinných údajov),
--   odidene  – odchod k inému dodávateľovi: väzba sa uzavrie k p_date,
--   zrusene  – OOM zaniklo: väzba sa uzavrie k p_date.
-- Prepis je oom_transfer, návrat oom_reconnect.
-- Príklad: SELECT oom_set_status('<id>', 'odidene', '2026-03-31');
CREATE FUNCTION oom_set_status(p_oom_id uuid, p_status oom_status, p_date date DEFAULT crm_today())
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
BEGIN
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odberné miesto nemá otvorenú väzbu (je Odídené, Zrušené alebo Prepísané).'
      USING ERRCODE = 'check_violation';
  END IF;
  CASE p_status
    WHEN 'aktivne' THEN
      UPDATE oom_customer SET status = 'aktivne' WHERE id = v_link.id;
    WHEN 'odidene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'odchod', status = 'odidene' WHERE id = v_link.id;
    WHEN 'zrusene' THEN
      UPDATE oom_customer SET valid_to = p_date, end_reason = 'zrusenie', status = 'zrusene' WHERE id = v_link.id;
    WHEN 'prepisane' THEN
      RAISE EXCEPTION 'Prepis na iného odberateľa: oom_transfer.' USING ERRCODE = 'check_violation';
    ELSE
      RAISE EXCEPTION 'Stav % sa takto nenastavuje.', p_status USING ERRCODE = 'check_violation';
  END CASE;
END;
$$;

-- Prepis na iného odberateľa k p_date: stará väzba končí deň predtým (Prepísané),
-- nová začína p_date so stavom, aký OOM malo. Kontaktné osoby starého zákazníka sa odoberú.
-- Príklad: SELECT oom_transfer('<oom>', NULL, '<Kováčová>', '2026-11-01');
CREATE FUNCTION oom_transfer(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_date date)
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_link oom_customer;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_transfer: zadaj práve jedno z company_id / person_id';
  END IF;
  SELECT * INTO v_link FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Prepísať sa dá iba Pripravované alebo Aktívne odberné miesto.' USING ERRCODE = 'check_violation';
  END IF;
  IF (v_link.company_id, v_link.person_id) IS NOT DISTINCT FROM (p_company_id, p_person_id) THEN
    RAISE EXCEPTION 'Nový odberateľ je ten istý zákazník.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_date <= v_link.valid_from THEN
    RAISE EXCEPTION 'Dátum prepisu musí byť po začiatku väzby (%).', v_link.valid_from USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom_customer SET valid_to = p_date - 1, end_reason = 'prepis', status = 'prepisane' WHERE id = v_link.id;
  DELETE FROM oom_contact WHERE oom_id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, v_link.org_id, p_date, v_link.status)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Návrat OOM k Greenlogy (ten istý alebo iný zákazník) od p_from: nová väzba Pripravované,
-- kroky prechodu a dodávka sa vynulujú (predošlé ostávajú v audite).
-- Príklad: SELECT oom_reconnect('<oom>', '<firma>', NULL, '2027-01-01');
CREATE FUNCTION oom_reconnect(p_oom_id uuid, p_company_id uuid, p_person_id uuid, p_from date DEFAULT crm_today())
RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_last date;
  v_id   uuid;
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'oom_reconnect: zadaj práve jedno z company_id / person_id';
  END IF;
  IF EXISTS (SELECT 1 FROM oom_customer WHERE oom_id = p_oom_id AND valid_to IS NULL) THEN
    RAISE EXCEPTION 'Odberné miesto už je u nás (Pripravované alebo Aktívne).' USING ERRCODE = 'check_violation';
  END IF;
  SELECT max(valid_to) INTO v_last FROM oom_customer WHERE oom_id = p_oom_id;
  IF p_from <= v_last THEN
    RAISE EXCEPTION 'Nové obdobie musí začať po konci predošlého (%).', v_last USING ERRCODE = 'check_violation';
  END IF;

  UPDATE oom
     SET supply_from = NULL, supply_to = NULL, previous_supplier = NULL, switch_notice_required = true,
         switch_notice_sent_on = NULL, switch_notice_accepted_on = NULL, switch_confirmed_on = NULL
   WHERE id = p_oom_id;
  INSERT INTO oom_customer (oom_id, company_id, person_id, org_id, valid_from, status)
  VALUES (p_oom_id, p_company_id, p_person_id, (SELECT org_id FROM oom WHERE id = p_oom_id), p_from, 'pripravovane')
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Komu OOM patrilo k dátumu (obrazovka 18). Príklad: SELECT * FROM oom_customer_at('<oom>', '2026-03-01');
CREATE FUNCTION oom_customer_at(p_oom_id uuid, p_date date)
RETURNS TABLE (company_id uuid, person_id uuid, status oom_status, valid_from date, valid_to date)
LANGUAGE sql STABLE AS $$
  SELECT l.company_id, l.person_id, l.status, l.valid_from, l.valid_to
    FROM oom_customer l
   WHERE l.oom_id = p_oom_id
     AND daterange(l.valid_from, l.valid_to, '[]') @> p_date
$$;

-- ============================================================================
-- Kontaktné osoby pri OOM (zadanie OOM čl. 5)
-- ============================================================================

CREATE TABLE oom_contact (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  oom_id      uuid NOT NULL REFERENCES oom (id) ON DELETE CASCADE,
  contact_id  uuid NOT NULL REFERENCES contact (id),
  roles       text[] NOT NULL DEFAULT '{}',
  source      oom_contact_source NOT NULL DEFAULT 'rucne',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (oom_id, contact_id)
);
CREATE INDEX oom_contact_contact_id_idx ON oom_contact (contact_id);
COMMENT ON TABLE oom_contact IS 'kontaktné osoby pri OOM; rucne = pridal používateľ, zmluva = prenesené zo zmluvy (modul 4), ručné sa pri zmene zmluvy neodoberajú';
COMMENT ON COLUMN oom_contact.roles IS 'kódy z číselníka rola_pri_oom (aj viac naraz)';

-- Osoba: firemný zákazník = osoba tejto firmy; domácnosť = osoba tej istej spoločnosti. Roly z číselníka.
CREATE FUNCTION oom_contact_check() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v_oom oom;
BEGIN
  SELECT * INTO v_oom FROM oom WHERE id = NEW.oom_id;
  IF v_oom.company_id IS NOT NULL THEN
    IF NOT EXISTS (SELECT 1 FROM company_contact WHERE company_id = v_oom.company_id AND contact_id = NEW.contact_id) THEN
      RAISE EXCEPTION 'Kontaktná osoba musí byť osobou vo firme zákazníka.' USING ERRCODE = 'check_violation';
    END IF;
  ELSIF (SELECT org_id FROM contact WHERE id = NEW.contact_id) <> v_oom.org_id THEN
    RAISE EXCEPTION 'Osoba a odberné miesto patria rôznym spoločnostiam.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM lookup_codes_check('rola_pri_oom', v_oom.org_id, NEW.roles,
                             CASE WHEN TG_OP = 'UPDATE' THEN OLD.roles END);
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_check BEFORE INSERT OR UPDATE ON oom_contact
  FOR EACH ROW EXECUTE FUNCTION oom_contact_check();

-- ============================================================================
-- Stav zákazníka z väzieb (zadanie Zákazníci čl. 4 a 14)
-- ============================================================================

-- Ako v 0004, ale OOM sa berú z väzieb (aj uzavretých): po prepise má starý zákazník OOM
-- Prepísané, hoci samo OOM je Aktívne u nového. Neaktívne → Pripravované.
CREATE OR REPLACE FUNCTION customer_status_calc(
  p_company_id uuid,
  p_person_id  uuid,
  p_today      date DEFAULT (now() AT TIME ZONE 'Europe/Bratislava')::date
) RETURNS customer_status
LANGUAGE plpgsql STABLE AS $$
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_status_calc: zadaj práve jedno z company_id / person_id';
  END IF;

  -- 1. aspoň jedno OOM Aktívne
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'aktivne') THEN
    RETURN 'zakaznik';
  END IF;

  -- 2. OOM Pripravované alebo podpísaná zmluva s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'pripravovane')
     OR EXISTS (SELECT 1 FROM contract c
                 WHERE c.company_id IS NOT DISTINCT FROM p_company_id
                   AND c.person_id IS NOT DISTINCT FROM p_person_id
                   AND c.status IN ('podpisana', 'caka_na_zaradenie', 'aktivna')
                   AND c.valid_from > p_today) THEN
    RETURN 'cakajuci_zakaznik';
  END IF;

  -- 3. a 4. otvorený deal s odoslanou ponukou / bez nej
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
               JOIN offer f ON f.deal_id = d.id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed
                AND (f.sent_at IS NOT NULL OR f.status <> 'koncept')) THEN
    RETURN 'ponuka';
  END IF;
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed) THEN
    RETURN 'zaujemca';
  END IF;

  -- 5. aspoň jedno OOM Odídené
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id
                AND l.status = 'odidene') THEN
    RETURN 'byvaly_zakaznik';
  END IF;

  -- 6. má OOM a všetky sú Zrušené alebo Prepísané
  IF EXISTS (SELECT 1 FROM oom_customer l
              WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                AND l.person_id IS NOT DISTINCT FROM p_person_id) THEN
    RETURN 'zruseny_zakaznik';
  END IF;

  -- 7. inak (aj záujemca, ktorému deal prepadol a nikdy nebol zákazník)
  RETURN 'marketingovy_kontakt';
END;
$$;

-- Príznak „bývalý“: má uzavretú väzbu s dôvodom odchod (Peter 12. 10., odpoveď 1).
CREATE OR REPLACE FUNCTION customer_is_former_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM oom_customer l
                  WHERE l.company_id IS NOT DISTINCT FROM p_company_id
                    AND l.person_id IS NOT DISTINCT FROM p_person_id
                    AND l.end_reason = 'odchod')
$$;

-- Spoločnosť zákazníka sa nemení ani pri väzbách z minulosti (ako v 0008, navyše oom_customer a oom_contact).
CREATE OR REPLACE FUNCTION customer_org_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF NEW.org_id IS DISTINCT FROM OLD.org_id AND (
       (TG_TABLE_NAME = 'company' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE company_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE company_id = OLD.id)))
    OR (TG_TABLE_NAME = 'contact' AND (
          EXISTS (SELECT 1 FROM company_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_customer WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM oom_contact WHERE contact_id = OLD.id)
          OR EXISTS (SELECT 1 FROM deal WHERE person_id = OLD.id)
          OR EXISTS (SELECT 1 FROM contract WHERE person_id = OLD.id)))) THEN
    RAISE EXCEPTION 'Spoločnosť sa nedá zmeniť, záznam má väzby (osoby, OOM, dealy, zmluvy).'
      USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;

-- ============================================================================
-- updated_at a audit na nových tabuľkách
-- ============================================================================

CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON oom_customer FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON oom_contact  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON oom_customer FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON oom_contact  FOR EACH ROW EXECUTE FUNCTION audit_row();

-- migrate:down

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM oom) THEN
    RAISE EXCEPTION 'Návrat 0013 vyžaduje prázdnu tabuľku oom (väzby a kontaktné osoby by sa stratili).';
  END IF;
END;
$$;

-- Funkcie z 0004, 0007 a 0008 v pôvodnom znení (customer_status_calc až po premenovaní enumu späť)
CREATE OR REPLACE FUNCTION customer_org_guard() RETURNS trigger
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

CREATE OR REPLACE FUNCTION customer_is_former_calc(p_company_id uuid, p_person_id uuid) RETURNS boolean
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (SELECT 1 FROM oom o
                  WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                    AND o.person_id IS NOT DISTINCT FROM p_person_id
                    AND o.status = 'odidene')
$$;

DROP FUNCTION IF EXISTS oom_customer_at(uuid, date);
DROP FUNCTION IF EXISTS oom_reconnect(uuid, uuid, uuid, date);
DROP FUNCTION IF EXISTS oom_transfer(uuid, uuid, uuid, date);
DROP FUNCTION IF EXISTS oom_set_status(uuid, oom_status, date);

DROP TABLE IF EXISTS oom_contact;
DROP FUNCTION IF EXISTS oom_contact_check();

DROP TRIGGER IF EXISTS trg_oom_first_link ON oom;
DROP FUNCTION IF EXISTS oom_first_link();
DROP TRIGGER IF EXISTS trg_oom_link_guard ON oom;
DROP FUNCTION IF EXISTS oom_link_guard();
DROP TABLE IF EXISTS oom_customer;
DROP FUNCTION IF EXISTS oom_link_sync();
DROP FUNCTION IF EXISTS oom_customer_check();

DROP TRIGGER IF EXISTS trg_oom_active_required ON oom;
DROP FUNCTION IF EXISTS oom_active_required_check();
DROP FUNCTION IF EXISTS oom_active_required_missing(oom);

DROP TRIGGER IF EXISTS trg_oom_lookup ON oom;
DROP FUNCTION IF EXISTS oom_lookup_check();

-- Číselníky OOM (lookup_value sa inak nemaže – spúšťač sa na chvíľu vypne)
ALTER TABLE lookup_value DISABLE TRIGGER trg_guard;
DELETE FROM lookup_value WHERE list_code IN
  ('pds', 'sadzba_distribucie', 'fakturacne_obdobie', 'sposob_zaloh', 'typ_merania', 'typ_vykupnej_zmluvy', 'rola_pri_oom');
ALTER TABLE lookup_value ENABLE TRIGGER trg_guard;
DELETE FROM lookup_list WHERE code IN
  ('sadzba_distribucie', 'pds', 'fakturacne_obdobie', 'sposob_zaloh', 'typ_merania', 'typ_vykupnej_zmluvy', 'rola_pri_oom');

CREATE OR REPLACE FUNCTION lookup_value_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Hodnota číselníka sa nemaže, iba skryje.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.code := coalesce(NEW.code, crm_slug(NEW.label));
    RETURN NEW;
  END IF;
  IF NEW.code <> OLD.code OR NEW.list_code <> OLD.list_code OR NEW.is_system <> OLD.is_system THEN
    RAISE EXCEPTION 'Kód, zoznam a systémový príznak hodnoty číselníka sa nemenia.' USING ERRCODE = 'check_violation';
  END IF;
  IF OLD.is_system AND (NEW.label <> OLD.label OR NEW.hidden_at IS NOT NULL
                        OR NEW.org_id IS DISTINCT FROM OLD.org_id) THEN
    RAISE EXCEPTION 'Systémová hodnota „%“ sa nedá premenovať ani skryť.', OLD.label USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
DROP INDEX IF EXISTS lookup_value_label_key;
CREATE UNIQUE INDEX lookup_value_label_key ON lookup_value (list_code, org_id, lower(label)) NULLS NOT DISTINCT;
ALTER TABLE lookup_value DROP COLUMN IF EXISTS parent_code;
ALTER TABLE lookup_value DROP COLUMN IF EXISTS reg_no;
ALTER TABLE lookup_list DROP COLUMN IF EXISTS parent_list;

-- EIC
ALTER TABLE oom DROP CONSTRAINT IF EXISTS oom_eic_check;
DROP TRIGGER IF EXISTS trg_oom_eic ON oom;
DROP FUNCTION IF EXISTS oom_eic_normalize();
DROP FUNCTION IF EXISTS eic_is_valid(text);

-- Stĺpce
ALTER TABLE org
  DROP COLUMN IF EXISTS oom_switch_confirm_days,
  DROP COLUMN IF EXISTS oom_switch_accept_days;

CREATE TYPE source_type AS ENUM ('virtualna_bateria', 'lokalny_zdroj', 'vyrobny_zdroj', 'green_viwa');
CREATE TYPE previous_supplier_notice AS ENUM (
  'akceptacia', 'bez_akceptacie', 'nezasiela_sa', 'odoslana', 'potvrdena'
);
ALTER TABLE oom
  DROP CONSTRAINT IF EXISTS oom_switch_steps_check,
  DROP CONSTRAINT IF EXISTS oom_advance_pct_check,
  DROP CONSTRAINT IF EXISTS oom_phases_check,
  DROP COLUMN IF EXISTS switch_confirmed_on,
  DROP COLUMN IF EXISTS switch_notice_accepted_on,
  DROP COLUMN IF EXISTS switch_notice_sent_on,
  DROP COLUMN IF EXISTS switch_notice_required,
  DROP COLUMN IF EXISTS previous_supplier,
  DROP COLUMN IF EXISTS advance_payment_eur,
  DROP COLUMN IF EXISTS source_category,
  ADD COLUMN segment                              customer_segment,
  ADD COLUMN source_type                          source_type,
  ADD COLUMN previous_supplier_notice             previous_supplier_notice,
  ADD COLUMN previous_supplier_notice_accepted_at timestamptz;
ALTER TABLE oom ALTER COLUMN voltage_level TYPE text USING voltage_level::text;
COMMENT ON COLUMN oom.company_id IS NULL;
COMMENT ON COLUMN oom.person_id IS NULL;
COMMENT ON COLUMN oom.status IS NULL;
COMMENT ON COLUMN oom.pds IS NULL;
COMMENT ON COLUMN oom.pds_tariff IS NULL;
COMMENT ON COLUMN oom.metering_type IS NULL;
COMMENT ON COLUMN oom.billing_period IS NULL;
COMMENT ON COLUMN oom.advance_payment_method IS NULL;
COMMENT ON COLUMN oom.feed_in_contract_type IS NULL;

DROP TYPE IF EXISTS oom_contact_source;

ALTER TYPE source_kind RENAME TO source_kind_new;
CREATE TYPE source_kind AS ENUM ('fve', 'voda', 'bioplyn', 'plyn', 'vietor', 'ostatne_oze');
ALTER TABLE oom ALTER COLUMN source_kind TYPE source_kind USING source_kind::text::source_kind;
DROP TYPE source_kind_new;
DROP TYPE IF EXISTS voltage_level;
DROP TYPE IF EXISTS oom_source_category;
DROP TYPE IF EXISTS oom_link_end_reason;

ALTER TYPE oom_status RENAME VALUE 'pripravovane' TO 'neaktivne';

ALTER TYPE oom_type RENAME TO oom_type_new;
CREATE TYPE oom_type AS ENUM ('spotreba', 'vyroba', 'sharing', 'velkoobchod');
ALTER TABLE oom ALTER COLUMN type TYPE oom_type USING type::text::oom_type;
DROP TYPE oom_type_new;

CREATE OR REPLACE FUNCTION customer_status_calc(
  p_company_id uuid,
  p_person_id  uuid,
  p_today      date DEFAULT (now() AT TIME ZONE 'Europe/Bratislava')::date
) RETURNS customer_status
LANGUAGE plpgsql STABLE AS $$
BEGIN
  IF num_nonnulls(p_company_id, p_person_id) <> 1 THEN
    RAISE EXCEPTION 'customer_status_calc: zadaj práve jedno z company_id / person_id';
  END IF;

  -- 1. aspoň jedno OOM Aktívne alebo Neaktívne
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id
                AND o.status IN ('aktivne', 'neaktivne')) THEN
    RETURN 'zakaznik';
  END IF;

  -- 2. podpísaná zmluva s budúcou účinnosťou (aj vracajúci sa zákazník)
  IF EXISTS (SELECT 1 FROM contract c
              WHERE c.company_id IS NOT DISTINCT FROM p_company_id
                AND c.person_id IS NOT DISTINCT FROM p_person_id
                AND c.status IN ('podpisana', 'caka_na_zaradenie', 'aktivna')
                AND c.valid_from > p_today) THEN
    RETURN 'cakajuci_zakaznik';
  END IF;

  -- 3. a 4. otvorený deal s odoslanou ponukou / bez nej
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
               JOIN offer f ON f.deal_id = d.id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed
                AND (f.sent_at IS NOT NULL OR f.status <> 'koncept')) THEN
    RETURN 'ponuka';
  END IF;
  IF EXISTS (SELECT 1 FROM deal d
               JOIN pipeline_stage s ON s.id = d.stage_id AND s.pipeline_id = d.pipeline_id
              WHERE d.company_id IS NOT DISTINCT FROM p_company_id
                AND d.person_id IS NOT DISTINCT FROM p_person_id
                AND NOT s.is_closed) THEN
    RETURN 'zaujemca';
  END IF;

  -- 5. aspoň jedno OOM Odídené
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id
                AND o.status = 'odidene') THEN
    RETURN 'byvaly_zakaznik';
  END IF;

  -- 6. má OOM a všetky sú Zrušené alebo Prepísané
  IF EXISTS (SELECT 1 FROM oom o
              WHERE o.company_id IS NOT DISTINCT FROM p_company_id
                AND o.person_id IS NOT DISTINCT FROM p_person_id) THEN
    RETURN 'zruseny_zakaznik';
  END IF;

  -- 7. inak (aj záujemca, ktorému deal prepadol a nikdy nebol zákazník)
  RETURN 'marketingovy_kontakt';
END;
$$;

DROP FUNCTION IF EXISTS crm_today();
-- rozšírenie btree_gist ostáva (môžu ho používať iné objekty)
