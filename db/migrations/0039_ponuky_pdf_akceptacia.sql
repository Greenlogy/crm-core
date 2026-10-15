-- migrate:up

-- 0039_ponuky_pdf_akceptacia – modul 5, fáza F3 (návrh DB časti 1.7, 1.10, 4, 5, 23; zadanie 7.1–7.3):
-- šablóny ponúk s verziami (texty z docs/moduly/05-sablony-ponuk-texty.md), obrázky PDF, údaje dokumentu ponuky
-- pre PDF aj stránku (jedno miesto), PDF a odkaz pri ponuke (v databáze iba odtlačok odkazu), štatistika otvorení,
-- akceptácia (klik zákazníka, ručne s kanálom, podpísané PDF), zrušenie akceptácie adminom, verejné funkcie pre
-- rolu crm_public (Worker crm-ponuka), ceny VIWA z cenníka, telefón a funkcia obchodníka.
-- Rola crm_public a jej práva sú v api/db/public-role.sql (prostredie, nie schéma) – rovnako ako crm_app.

-- ============================================================================
-- 1. Obchodník v ponuke: telefón a funkcia (do profilu v F4; zatiaľ ich zadá admin)
-- ============================================================================

ALTER TABLE app_user
  ADD COLUMN phone     text CHECK (phone IS NULL OR length(phone) <= 40),
  ADD COLUMN job_title text CHECK (job_title IS NULL OR length(job_title) <= 80);
COMMENT ON COLUMN app_user.phone IS 'telefón obchodníka do ponuky („Cenovú ponuku spracoval“) – 0039';

-- ============================================================================
-- 2. Šablóny ponúk (časť 1.10): druh × jazyk, verzie Návrh / Platná / Nahradená
-- ============================================================================

CREATE TABLE offer_template_version (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id       uuid NOT NULL REFERENCES org (id),
  kind         offer_kind NOT NULL,
  language     offer_language NOT NULL,
  version      smallint NOT NULL,
  status       text NOT NULL DEFAULT 'navrh' CHECK (status IN ('navrh', 'platna', 'nahradena')),
  sections     jsonb NOT NULL,   -- {kľúč: {nadpis, text}} – poradie a kľúče: offer_template_keys()
  defaults     jsonb NOT NULL DEFAULT '{}',   -- zmluvna_pokuta (€/MWh)
  note         text,
  created_by   uuid REFERENCES app_user (id),
  published_at timestamptz,
  published_by uuid REFERENCES app_user (id),
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (org_id, kind, language, version),
  CHECK ((status = 'navrh') = (published_at IS NULL))
);
CREATE UNIQUE INDEX offer_template_platna_key ON offer_template_version (org_id, kind, language) WHERE status = 'platna';
CREATE UNIQUE INDEX offer_template_navrh_key ON offer_template_version (org_id, kind, language) WHERE status = 'navrh';
COMMENT ON TABLE offer_template_version IS 'pevné texty ponuky (PDF a stránka) – platná verzia sa nemení, zmena = nová verzia (0039)';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON offer_template_version FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_template_version FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Kľúče sekcií v poradí dokumentu
CREATE FUNCTION offer_template_keys() RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['hlavicka', 'udaje', 'predmet', 'cenova_ponuka', 'podmienky', 'platnost', 'vseobecne', 'objednavka',
               'spracoval', 'pribeh', 'vizia', 'paticka']
$$;

-- Povolené premenné «…» a podmienené bloky [[spot]]…[[/spot]], [[kompenzacia]]…[[/kompenzacia]]
CREATE FUNCTION offer_template_variables() RETURNS text[]
LANGUAGE sql IMMUTABLE AS $$
  SELECT ARRAY['číslo ponuky', 'dátum ponuky', 'názov', 'sídlo', 'IČO', 'IČ DPH', 'kontakt meno', 'kontakt e-mail',
               'kontakt telefón', 'obchodník meno', 'obchodník funkcia', 'obchodník telefón', 'obchodník e-mail',
               'tabuľka variantov', 'flexibilita', 'objem', 'výška preddavkov', 'splatnosť preddavku', 'splatnosť faktúr',
               'platnosť čas', 'platnosť dátum', 'variant', 'dátum platnosti', 'zmluvná pokuta', 'obdobie', 'koeficient',
               'poplatok za kW']
$$;

-- Kontrola šablóny: známe sekcie, text, iba povolené premenné, párové bloky
CREATE FUNCTION offer_template_check(p_sections jsonb) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  k   text;
  t   text;
  v   text;
  b   text;
BEGIN
  IF jsonb_typeof(p_sections) <> 'object' THEN
    RETURN 'Šablóna nemá sekcie.';
  END IF;
  FOR k IN SELECT jsonb_object_keys(p_sections) LOOP
    IF NOT k = ANY (offer_template_keys()) THEN
      RETURN format('Neznáma sekcia „%s“.', k);
    END IF;
    t := coalesce(p_sections->k->>'nadpis', '') || E'\n' || coalesce(p_sections->k->>'text', '');
    FOR v IN SELECT m[1] FROM regexp_matches(t, '«([^«»]*)»', 'g') m LOOP
      IF NOT v = ANY (offer_template_variables()) THEN
        RETURN format('Neznáma premenná «%s» v sekcii „%s“.', v, k);
      END IF;
    END LOOP;
    IF t ~ '[«»]' AND (length(t) - length(replace(t, '«', ''))) <> (length(t) - length(replace(t, '»', ''))) THEN
      RETURN format('Neuzavretá premenná v sekcii „%s“.', k);
    END IF;
    FOREACH b IN ARRAY ARRAY['spot', 'kompenzacia'] LOOP
      IF (length(t) - length(replace(t, '[[' || b || ']]', ''))) / length('[[' || b || ']]')
         <> (length(t) - length(replace(t, '[[/' || b || ']]', ''))) / length('[[/' || b || ']]') THEN
        RETURN format('Blok [[%s]] v sekcii „%s“ nie je uzavretý.', b, k);
      END IF;
    END LOOP;
  END LOOP;
  FOREACH k IN ARRAY ARRAY['hlavicka', 'udaje', 'predmet', 'cenova_ponuka', 'platnost', 'objednavka'] LOOP
    IF coalesce(btrim(p_sections->k->>'text'), '') = '' THEN
      RETURN format('Chýba text sekcie „%s“.', k);
    END IF;
  END LOOP;
  IF position('«tabuľka variantov»' IN coalesce(p_sections->'cenova_ponuka'->>'text', '')) = 0 THEN
    RETURN 'Sekcia „cenova_ponuka“ musí obsahovať «tabuľka variantov».';
  END IF;
  RETURN NULL;
END;
$$;

-- Stráženie: platná a nahradená verzia sa nemení ani nemaže; nová verzia = Návrh s číslom max + 1;
-- stav mení iba offer_template_publish (kód databázy)
CREATE FUNCTION offer_template_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_err text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.status <> 'navrh' AND NOT (crm_owner_session() OR crm_internal_call()) THEN
      RAISE EXCEPTION 'Zmazať sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
    END IF;
    RETURN OLD;
  END IF;
  IF NOT (crm_owner_session() OR crm_internal_call()) THEN
    IF TG_OP = 'INSERT' THEN
      NEW.status := 'navrh';
      NEW.published_at := NULL;
      NEW.published_by := NULL;
      NEW.created_by := crm_active_user_id();
    ELSE
      IF OLD.status <> 'navrh' THEN
        RAISE EXCEPTION 'Platná šablóna sa nemení – uložte novú verziu.' USING ERRCODE = 'check_violation';
      END IF;
      IF (NEW.status, NEW.kind, NEW.language, NEW.version, NEW.org_id, NEW.published_at)
         IS DISTINCT FROM (OLD.status, OLD.kind, OLD.language, OLD.version, OLD.org_id, OLD.published_at) THEN
        RAISE EXCEPTION 'Druh, jazyk, verziu a stav šablóny mení iba CRM (zverejnenie).' USING ERRCODE = 'insufficient_privilege';
      END IF;
    END IF;
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.version := coalesce((SELECT max(version) FROM offer_template_version
                              WHERE org_id = NEW.org_id AND kind = NEW.kind AND language = NEW.language), 0) + 1;
  END IF;
  v_err := offer_template_check(NEW.sections);
  IF v_err IS NOT NULL THEN
    RAISE EXCEPTION '%', v_err USING ERRCODE = 'check_violation';
  END IF;
  IF NEW.defaults ? 'zmluvna_pokuta' AND NOT (jsonb_typeof(NEW.defaults->'zmluvna_pokuta') = 'number'
                                               AND (NEW.defaults->>'zmluvna_pokuta')::numeric BETWEEN 0 AND 10000) THEN
    RAISE EXCEPTION 'Zmluvná pokuta musí byť číslo 0 až 10 000 €/MWh.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON offer_template_version
  FOR EACH ROW EXECUTE FUNCTION offer_template_guard();

-- Zverejnenie návrhu (admin): doterajšia platná → nahradená; odoslané ponuky si pamätajú svoju verziu
CREATE FUNCTION offer_template_publish(p_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t offer_template_version;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Šablóny ponúk zverejňuje admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  SELECT * INTO t FROM offer_template_version WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR t.status <> 'navrh' THEN
    RAISE EXCEPTION 'Zverejniť sa dá iba návrh šablóny.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_template_version SET status = 'nahradena'
   WHERE org_id = t.org_id AND kind = t.kind AND language = t.language AND status = 'platna';
  UPDATE offer_template_version SET status = 'platna', published_at = now(), published_by = crm_active_user_id()
   WHERE id = t.id;
END;
$$;

-- Obrázky PDF (titulná strana, referencie, energetický mix): bez záznamu sa použijú pribalené z aplikácie.
-- Obrázok sa nemení ani nemaže – nový obrázok, starý sa iba vypne (odoslané PDF už sú v R2).
CREATE TABLE offer_asset (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  org_id     uuid NOT NULL REFERENCES org (id),
  code       text NOT NULL CHECK (code IN ('titulna', 'referencie_zakaznici', 'referencie_partneri', 'energeticky_mix')),
  mime       text NOT NULL CHECK (mime IN ('image/png', 'image/jpeg')),
  data       bytea NOT NULL CHECK (octet_length(data) <= 1048576),
  sha256     text NOT NULL CHECK (sha256 ~ '^[0-9a-f]{64}$'),
  active     boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES app_user (id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX offer_asset_active_key ON offer_asset (org_id, code) WHERE active;
COMMENT ON TABLE offer_asset IS 'obrázky do PDF ponuky; bez auditu (obsahuje binárne dáta) – kto a kedy je v created_by / created_at (0039)';

CREATE FUNCTION offer_asset_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF crm_owner_session() OR crm_internal_call() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Obrázok sa nemaže – nahrajte nový.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'UPDATE' AND ((NEW.data, NEW.code, NEW.mime, NEW.sha256, NEW.org_id) IS DISTINCT FROM (OLD.data, OLD.code, OLD.mime, OLD.sha256, OLD.org_id)
                           OR (NEW.active AND NOT OLD.active)) THEN
    RAISE EXCEPTION 'Obrázok sa nemení – nahrajte nový.' USING ERRCODE = 'check_violation';
  END IF;
  IF TG_OP = 'INSERT' THEN
    NEW.sha256 := encode(sha256(NEW.data), 'hex');
    NEW.created_by := crm_active_user_id();
    UPDATE offer_asset SET active = false WHERE org_id = NEW.org_id AND code = NEW.code AND active;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON offer_asset FOR EACH ROW EXECUTE FUNCTION offer_asset_guard();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_asset FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================================
-- 3. Ponuka: šablóna, PDF, odkaz, zmluvná pokuta, zablokovanie; štatistika otvorení
-- ============================================================================

ALTER TABLE offer
  ADD COLUMN penalty_eur_mwh     numeric(12,2) CHECK (penalty_eur_mwh IS NULL OR penalty_eur_mwh BETWEEN 0 AND 10000),
  ADD COLUMN template_version_id uuid REFERENCES offer_template_version (id),
  ADD COLUMN pdf_key             text CHECK (pdf_key IS NULL OR pdf_key ~ '^ponuky/[0-9a-f-]{36}/[0-9]{4}/P[0-9]{2}-[0-9]{6}(-[0-9]+)?\.pdf$'),
  ADD COLUMN pdf_sha256          text CHECK (pdf_sha256 IS NULL OR pdf_sha256 ~ '^[0-9a-f]{64}$'),
  ADD COLUMN pdf_generated_at    timestamptz,
  ADD COLUMN link_hash           text CHECK (link_hash IS NULL OR link_hash ~ '^[0-9a-f]{64}$'),
  ADD COLUMN link_created_at     timestamptz,
  ADD COLUMN link_created_by     uuid REFERENCES app_user (id),
  ADD COLUMN blocked_by_offer_id uuid REFERENCES offer (id),
  ADD CONSTRAINT offer_pdf_check CHECK ((pdf_key IS NULL) = (pdf_sha256 IS NULL));
CREATE UNIQUE INDEX offer_link_hash_key ON offer (link_hash) WHERE link_hash IS NOT NULL;
COMMENT ON COLUMN offer.penalty_eur_mwh IS 'zmluvná pokuta €/MWh v záväznej objednávke; NULL = zo šablóny (dodávka 50, výkup 30)';
COMMENT ON COLUMN offer.link_hash IS 'SHA-256 tokenu odkazu na stránku ponuky – samotný odkaz sa v databáze neuchováva';
COMMENT ON COLUMN offer.blocked_by_offer_id IS 'rozpracovaná verzia zablokovaná akceptáciou inej verzie; odblokuje iba vlastník obchodu alebo admin';

CREATE TABLE offer_page_stat (
  offer_id        uuid PRIMARY KEY REFERENCES offer (id) ON DELETE CASCADE,
  first_opened_at timestamptz NOT NULL,
  last_opened_at  timestamptz NOT NULL,
  open_count      integer NOT NULL DEFAULT 1
);
COMMENT ON TABLE offer_page_stat IS 'otvorenia stránky ponuky zákazníkom – bez IP adries (zadanie 7.3)';

-- ============================================================================
-- 4. Akceptácia (časť 1.7, odpovede F3 5–7)
-- ============================================================================

CREATE TABLE offer_acceptance (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  offer_id         uuid NOT NULL REFERENCES offer (id),
  variant_id       uuid NOT NULL REFERENCES offer_variant (id),
  org_id           uuid NOT NULL REFERENCES org (id),
  method           text NOT NULL CHECK (method IN ('klik', 'rucne')),
  channel          text CHECK (channel IN ('telefon', 'email', 'osobne', 'podpisane_pdf')),
  accepted_at      timestamptz NOT NULL,
  signer_name      text NOT NULL CHECK (btrim(signer_name) <> '' AND length(signer_name) <= 200),
  signer_function  text NOT NULL CHECK (btrim(signer_function) <> '' AND length(signer_function) <= 200),
  ip               inet,                 -- iba pri kliku
  user_agent       text CHECK (user_agent IS NULL OR length(user_agent) <= 500),
  terms_text       text NOT NULL,        -- znenie záväznej objednávky (VIWA: prijatia ponuky) zjednotené
  terms_sha256     text NOT NULL CHECK (terms_sha256 ~ '^[0-9a-f]{64}$'),
  offer_pdf_sha256 text,                 -- ktoré PDF zákazník prijímal (pri ponukách bez PDF prázdne)
  signed_file_key  text,                 -- R2: nahraté podpísané PDF
  note             text CHECK (note IS NULL OR length(note) <= 2000),
  recorded_by      uuid REFERENCES app_user (id),   -- kto akceptáciu zaznačil (ručne)
  revoked_at       timestamptz,
  revoked_by       uuid REFERENCES app_user (id),
  revoke_reason    text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CHECK ((method = 'klik') = (ip IS NOT NULL)),
  CHECK ((method = 'rucne') = (channel IS NOT NULL AND recorded_by IS NOT NULL)),
  CHECK (signed_file_key IS NULL OR method = 'rucne'),
  CHECK ((revoked_at IS NULL) = (revoked_by IS NULL) AND (revoked_at IS NULL) = (revoke_reason IS NULL))
);
CREATE UNIQUE INDEX offer_acceptance_active_key ON offer_acceptance (offer_id) WHERE revoked_at IS NULL;
CREATE INDEX offer_acceptance_offer_idx ON offer_acceptance (offer_id);
COMMENT ON TABLE offer_acceptance IS 'akceptácia ponuky – nemení sa; jedinou zmenou je zrušenie adminom s dôvodom (0039)';
CREATE TRIGGER trg_audit AFTER INSERT OR UPDATE OR DELETE ON offer_acceptance FOR EACH ROW EXECUTE FUNCTION audit_row();
CREATE TRIGGER trg_set_updated_at BEFORE UPDATE ON offer_acceptance FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE FUNCTION offer_acceptance_guard() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF crm_internal_call() THEN
    RETURN coalesce(NEW, OLD);
  END IF;
  RAISE EXCEPTION 'Akceptáciu zapisuje a ruší iba CRM.' USING ERRCODE = 'insufficient_privilege';
END;
$$;
CREATE TRIGGER trg_guard BEFORE INSERT OR UPDATE OR DELETE ON offer_acceptance FOR EACH ROW EXECUTE FUNCTION offer_acceptance_guard();

-- Časová os a upozornenia: nové druhy
ALTER TABLE deal_event
  DROP CONSTRAINT deal_event_kind_check,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik',
    'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana', 'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost',
    'schvalenie_ziadost', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'ponuka_zablokovana',
    'ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana'));
ALTER TABLE notification
  DROP CONSTRAINT notification_kind_check,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm',
    'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy',
    'ponuka_akceptovana', 'ponuka_zablokovana', 'akceptacia_zrusena'));

-- ============================================================================
-- 5. Prvé verzie šablón (docs/moduly/05-sablony-ponuk-texty.md v0.1): SK platné, EN návrh na kontrolu
-- Premenné sú jednoznačné («kontakt …», «obchodník …», «platnosť čas / dátum»); bloky [[spot]], [[kompenzacia]].
-- ============================================================================

CREATE FUNCTION pg_temp.tpl_sec(p_title text, p_text text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object('nadpis', p_title, 'text', p_text)
$$;

-- spoločné texty
CREATE FUNCTION pg_temp.tpl_common(p_lang text) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_lang WHEN 'sk' THEN jsonb_build_object(
    'spracoval', pg_temp.tpl_sec('', 'Cenovú ponuku spracoval: «obchodník meno» / «obchodník telefón» / «obchodník e-mail»'),
    'pribeh', pg_temp.tpl_sec('Príbeh Greenlogy', $t$Spoločnosť Greenlogy začala svoju činnosť v energetike v roku 2021, keďže na trhu s dodávkou elektriny chýbala ponuka založená výhradne na dodávke elektriny z obnoviteľných zdrojov, ktorá sa zároveň nekompromisne vymedzí voči elektrine vyrobenej z fosílnych palív a bude prednostne podporovať slovenských výrobcov zelenej elektriny.
Zelená značka Greenlogy v sebe spája zákazníka, ktorý chce žiť svoj život udržateľne a zodpovedne, slovenských výrobcov energií z obnoviteľných zdrojov a moderného zeleného dodávateľa. Greenlogy svojim zákazníkom denne dokazuje, že aj obyčajná dodávka elektriny sa dá robiť inak – udržateľne a zodpovedne a pritom poctivo, jednoducho a transparentne.$t$),
    'vizia', pg_temp.tpl_sec('Vízia Greenlogy', $t$V Greenlogy pracujeme na tom, aby aj naše deti poznali modrú oblohu a zelenú krajinu. Sme presvedčení, že budúcnosťou Slovenska je čistá energia vyrobená v nízkoemisných výrobných zdrojoch za použitia obnoviteľných surovín. Na energetickom trhu budeme vždy mostom, ktorý spája spotrebiteľov s výrobcami zelenej elektriny. Náš 100 % zelený energetický mix je dostupný pre všetkých.
Sme lídrom v inováciách, prinášame pravidelne na trh nové inovatívne produkty a služby pre maximálne využitie zelenej elektriny. Modernými produktmi, poctivými službami a made-to-measure prístupom uľahčujeme svojim zákazníkom život, podporujeme udržateľnosť a zodpovednosť v prístupe k životnému prostrediu, čím dávame existencii obnoviteľných zdrojov vyšší zmysel. Všetkým sa snažíme poskytovať pozitívny zákaznícky zážitok, definujeme trendy a benchmark v kvalite služieb.$t$),
    'paticka', pg_temp.tpl_sec('', 'www.greenlogy.com · The future is renewable.'))
  ELSE jsonb_build_object(
    'spracoval', pg_temp.tpl_sec('', 'Offer prepared by: «obchodník meno» / «obchodník telefón» / «obchodník e-mail»'),
    'pribeh', pg_temp.tpl_sec('The Greenlogy story', $t$Greenlogy entered the energy sector in 2021 because the electricity market lacked an offer based exclusively on electricity from renewable sources – one that would firmly distance itself from electricity generated from fossil fuels and give priority to Slovak producers of green electricity.
The Greenlogy brand brings together customers who want to live sustainably and responsibly, Slovak producers of renewable energy and a modern green supplier. Every day, Greenlogy shows its customers that even an ordinary electricity supply can be done differently – sustainably and responsibly, while staying honest, simple and transparent.$t$),
    'vizia', pg_temp.tpl_sec('The Greenlogy vision', $t$At Greenlogy we work to make sure our children will also know blue skies and green landscapes. We believe Slovakia's future lies in clean energy generated in low-emission plants from renewable resources. In the energy market we will always be the bridge connecting consumers with producers of green electricity. Our 100% green energy mix is available to everyone.
We lead in innovation and regularly bring new products and services to market that make the most of green electricity. With modern products, honest service and a made-to-measure approach, we make our customers' lives easier and support a sustainable and responsible approach to the environment, giving renewable sources a greater purpose. We strive to give everyone a positive customer experience and set trends and benchmarks in service quality.$t$),
    'paticka', pg_temp.tpl_sec('', 'www.greenlogy.com · The future is renewable.'))
  END
$$;

INSERT INTO offer_template_version (org_id, kind, language, version, status, sections, defaults, note, published_at)
SELECT o.id, x.kind::offer_kind, x.lang::offer_language, 1, x.status, pg_temp.tpl_common(x.lang) || x.sections, x.defaults,
       'prvá verzia z 05-sablony-ponuk-texty.md v0.1' || CASE WHEN x.lang = 'en' THEN ' – preklad na kontrolu' ELSE '' END,
       CASE WHEN x.status = 'platna' THEN now() END
  FROM org o
 CROSS JOIN (VALUES
  -- ---------------------------------------------------------------- dodávka SK
  ('dodavka', 'sk', 'platna', '{"zmluvna_pokuta": 50}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('CENOVÁ PONUKA · č.: «číslo ponuky»', $t$združenej dodávky zelenej elektriny vyrobenej na Slovensku s prevzatím zodpovednosti za odchýlku
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovenská republika, 02/3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. ÚDAJE O ODBERATEĽOVI', $t$Názov odberateľa: «názov»
Sídlo: «sídlo»
IČO: «IČO»
IČ DPH: «IČ DPH»
Kontaktná osoba: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. PREDMET PONUKY', $t$2.1 Predmetom cenovej ponuky pre Odberateľa je združená dodávka zelenej elektriny s prevzatím zodpovednosti za odchýlku, vrátane zabezpečenia distribučných a prenosových služieb, v súlade s bodom 3 a platnými Obchodnými podmienkami dodávky elektriny pre podnikateľov, ktoré sú zverejnené na www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. CENOVÁ PONUKA DODÁVKY ELEKTRINY', $t$3.1 Greenlogy ponúka nasledovné ceny dodávky elektriny:
«tabuľka variantov»
3.2 Ceny uvedené v ponuke sú výhradne za služby Dodávateľa elektriny Greenlogy a.s., bez DPH, spotrebnej dane, distribučných a prenosových poplatkov.
3.3 K cenám podľa bodu 3.1 sa v rámci faktúry pripočítavajú ceny za distribučné služby, platba za systémové služby, platba za prevádzkovanie systému, odvod do Národného jadrového fondu, spotrebná daň a DPH podľa platnej legislatívy a cenových rozhodnutí vydaných pre prevádzkovateľov distribučných sústav a OKTE, a.s.
[[spot]]3.4 Objem dodanej elektriny v štvrťhodine sa ocení podľa vzorca: cena = ISOT OKTE zvýšená o aditív v EUR/MWh.
3.5 Jednotková cena za dodávku elektriny v danom mesiaci sa určí ako vážený priemer štvrťhodinových cien a skutočných dodávok podľa bodu 3.4.
3.6 Informácie o cenách na dennom (spotovom) trhu s elektrinou sú zverejnené na https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
[[/spot]]3.7 Cenová ponuka obsahuje flexibilitu odberu na úrovni «flexibilita» bez dodatočných poplatkov.
3.8 Plánovaný ročný objem odberu, ktorý je predmetom ponuky: «objem» MWh.$t$),
    'podmienky', pg_temp.tpl_sec('4. PLATOBNÉ PODMIENKY', $t$4.1 Odberateľ uhrádza 1× mesačne preddavkovú platbu vo výške «výška preddavkov», resp. 100 % z 1/12 plánovaného ročného odberu pri odberných miestach s meraním typu C.
4.2 Splatnosť preddavkovej platby je «splatnosť preddavku».
4.3 Splatnosť vyúčtovacej faktúry je «splatnosť faktúr» odo dňa jej vystavenia.
4.4 Mesačnú preddavkovú platbu je na základe osobitnej dohody možné nahradiť finančnou zábezpekou, ktorá sa vysporiada v poslednej vyúčtovacej faktúre podľa zmluvného obdobia.$t$),
    'platnost', pg_temp.tpl_sec('5. PLATNOSŤ CENOVEJ PONUKY', $t$5.1 Cenová ponuka platí do «platnosť čas» hod. «platnosť dátum».
5.2 Cenová ponuka je záväzná až po potvrdení Záväznej objednávky osobou/osobami konajúcou/konajúcimi za Odberateľa, a to tlačidlom „Záväzne objednávam“ na stránke ponuky alebo zaslaním podpísanej Záväznej objednávky na trading@greenlogy.com.
5.3 Ak v lehote platnosti ponuky Odberateľ nepotvrdí Záväznú objednávku, má sa za to, že ponuku odmietol, a Odberateľovi ani Dodávateľovi z nej nevyplývajú žiadne záväzky.$t$),
    'vseobecne', pg_temp.tpl_sec('6. VŠEOBECNÉ USTANOVENIA', $t$6.1 Obchodné podmienky združenej dodávky zelenej elektriny sú dostupné na www.greenlogy.com v sekcii Pomoc a podpora.
6.2 Osobné údaje spracúvame na základe oprávneného záujmu a Odberateľ má právo namietať. Ďalšie informácie o spracúvaní osobných údajov sú uvedené na www.greenlogy.com v sekcii Pomoc a podpora.$t$),
    'objednavka', pg_temp.tpl_sec('POTVRDENIE O PRIJATÍ PONUKY – ZÁVÄZNÁ OBJEDNÁVKA', $t$DODÁVATEĽ: Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, IČO: 53223713, IČ DPH: SK2121307474
ODBERATEĽ: «názov», «sídlo», IČO: «IČO», IČ DPH: «IČ DPH»
Odberateľ potvrdzuje, že úplne prijíma od Dodávateľa Cenovú ponuku č. «číslo ponuky» zo dňa «dátum ponuky», variant «variant», ktorá je platná do «dátum platnosti».
Potvrdenie tejto Záväznej objednávky Odberateľom sa považuje za záväznú objednávku na združenú dodávku zelenej elektriny vyrobenej na Slovensku s prevzatím zodpovednosti za odchýlku, za podmienok obsiahnutých v Cenovej ponuke č. «číslo ponuky» a platných Všeobecných obchodných podmienok Greenlogy a.s. zverejnených na www.greenlogy.com.
Akceptáciou tejto Záväznej objednávky sa Odberateľ zaväzuje uzatvoriť s Dodávateľom najneskôr do 14 kalendárnych dní odo dňa akceptácie Zmluvu o združenej dodávke zelenej elektriny s prevzatím zodpovednosti za odchýlku a splnomocňuje Dodávateľa vykonať všetky potrebné kroky na obstaranie objednaného množstva elektriny a zrealizovať zmenový proces, ktorého výsledkom bude zaradenie odberných miest Odberateľa do bilančnej skupiny Dodávateľa.
Odberateľ sa zaväzuje poskytnúť Dodávateľovi do 7 dní od akceptácie Záväznej objednávky všetky podklady potrebné na uzavretie Zmluvy, ktorých špecifikáciu stanoví Dodávateľ. Zmluvu na autorizáciu elektronickou formou predloží Dodávateľ Odberateľovi najneskôr do 10 dní od akceptácie Záväznej objednávky.
Odberateľ berie na vedomie a súhlasí s tým, že Dodávateľ je po obdržaní tohto Potvrdenia o prijatí ponuky oprávnený vykonať nevyhnutné kroky na zabezpečenie dodávky elektriny pre Odberateľa.
Odberateľ sa zároveň zaväzuje uhradiť Dodávateľovi zmluvnú pokutu vo výške «zmluvná pokuta» € za každú objednanú MWh podľa bodu 3.8 Cenovej ponuky č. «číslo ponuky» v prípade, že s Dodávateľom neuzatvorí Zmluvu o dodávke elektriny, zmarí zmenový proces alebo od tejto Záväznej objednávky odstúpi.$t$))),
  -- ---------------------------------------------------------------- dodávka EN
  ('dodavka', 'en', 'navrh', '{"zmluvna_pokuta": 50}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('PRICE OFFER · No.: «číslo ponuky»', $t$combined supply of green electricity generated in Slovakia, including balancing responsibility
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovak Republic, +421 2 3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. CUSTOMER DETAILS', $t$Customer name: «názov»
Registered office: «sídlo»
Company ID: «IČO»
VAT ID: «IČ DPH»
Contact person: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. SUBJECT OF THE OFFER', $t$2.1 The subject of this price offer is the combined supply of green electricity including balancing responsibility and the provision of distribution and transmission services, in accordance with section 3 and the applicable Terms and Conditions of electricity supply for businesses published at www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. ELECTRICITY SUPPLY PRICE OFFER', $t$3.1 Greenlogy offers the following electricity supply prices:
«tabuľka variantov»
3.2 The prices in this offer cover only the services of the electricity supplier Greenlogy a.s. and exclude VAT, excise duty and distribution and transmission charges.
3.3 Charges for distribution services, system services, system operation, the contribution to the National Nuclear Fund, excise duty and VAT are added to the prices under 3.1 on the invoice, in accordance with applicable legislation and the price decisions issued for distribution system operators and OKTE, a.s.
[[spot]]3.4 The electricity supplied in each quarter-hour is priced as: price = OKTE ISOT price plus the adder in EUR/MWh.
3.5 The unit supply price for a given month is the weighted average of the quarter-hour prices and actual supplies under 3.4.
3.6 Day-ahead (spot) market prices are published at https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
[[/spot]]3.7 The offer includes «flexibilita» consumption flexibility at no additional charge.
3.8 Planned annual consumption covered by this offer: «objem» MWh.$t$),
    'podmienky', pg_temp.tpl_sec('4. PAYMENT TERMS', $t$4.1 The Customer pays a monthly advance of «výška preddavkov», or 100% of 1/12 of the planned annual consumption for metering points with type C metering.
4.2 The advance payment is due on «splatnosť preddavku».
4.3 The final settlement invoice is payable within «splatnosť faktúr» of its issue date.
4.4 By separate agreement, the monthly advance may be replaced by a financial guarantee settled in the last settlement invoice of the contract period.$t$),
    'platnost', pg_temp.tpl_sec('5. VALIDITY OF THE OFFER', $t$5.1 This offer is valid until «platnosť čas» on «platnosť dátum».
5.2 The offer becomes binding only once the Binding Order is confirmed by the person(s) authorised to act for the Customer, either by clicking „Place binding order“ on the offer page or by sending the signed Binding Order to trading@greenlogy.com.
5.3 If the Customer does not confirm the Binding Order within the validity period, the offer is deemed rejected and neither party has any obligations arising from it.$t$),
    'vseobecne', pg_temp.tpl_sec('6. GENERAL PROVISIONS', $t$6.1 The Terms and Conditions for the combined supply of green electricity are available at www.greenlogy.com under Help & Support.
6.2 We process personal data on the basis of legitimate interest and the Customer has the right to object. More information on personal data processing is available at www.greenlogy.com under Help & Support.$t$),
    'objednavka', pg_temp.tpl_sec('CONFIRMATION OF ACCEPTANCE – BINDING ORDER', $t$SUPPLIER: Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Company ID: 53223713, VAT ID: SK2121307474
CUSTOMER: «názov», «sídlo», Company ID: «IČO», VAT ID: «IČ DPH»
The Customer confirms that it fully accepts the Supplier's Price Offer No. «číslo ponuky» dated «dátum ponuky», variant «variant», valid until «dátum platnosti».
Confirmation of this Binding Order by the Customer constitutes a binding order for the combined supply of green electricity generated in Slovakia including balancing responsibility, under the conditions of Price Offer No. «číslo ponuky» and the applicable General Terms and Conditions of Greenlogy a.s. published at www.greenlogy.com.
By accepting this Binding Order, the Customer undertakes to conclude with the Supplier, within 14 calendar days of acceptance, a Contract for the combined supply of green electricity including balancing responsibility, and authorises the Supplier to take all steps necessary to procure the ordered volume of electricity and to carry out the supplier switching process, resulting in the Customer's metering points being included in the Supplier's balancing group.
The Customer undertakes to provide the Supplier, within 7 days of acceptance, with all documents required to conclude the Contract as specified by the Supplier. The Supplier will submit the Contract for electronic authorisation within 10 days of acceptance.
The Customer acknowledges and agrees that, upon receipt of this Confirmation, the Supplier is entitled to take the steps necessary to secure the electricity supply for the Customer.
The Customer further undertakes to pay the Supplier a contractual penalty of «zmluvná pokuta» € per ordered MWh under section 3.8 of Price Offer No. «číslo ponuky» if it fails to conclude the electricity supply Contract with the Supplier, frustrates the switching process or withdraws from this Binding Order.$t$))),
  -- ---------------------------------------------------------------- výkup SK
  ('vykup', 'sk', 'platna', '{"zmluvna_pokuta": 30}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('CENOVÁ PONUKA · č.: «číslo ponuky»', $t$výkupu elektriny vyrobenej z obnoviteľných zdrojov energie
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovenská republika, 02/3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. ÚDAJE O VÝROBCOVI', $t$Názov výrobcu: «názov»
Sídlo: «sídlo»
IČO: «IČO»
IČ DPH: «IČ DPH»
Kontaktná osoba: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. PREDMET PONUKY', $t$2.1 Predmetom cenovej ponuky pre Výrobcu je služba výkupu zelenej elektriny s prevzatím zodpovednosti za odchýlku v súlade s bodom 3 a platnými Obchodnými podmienkami služby výkup elektriny, ktoré sú zverejnené na www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. CENOVÁ PONUKA VÝKUPU ELEKTRINY', $t$3.1 Greenlogy ponúka nasledovné ceny výkupu elektriny:
«tabuľka variantov»
3.2 Ceny uvedené v ponuke sú výhradne za služby Výkupcu elektriny Greenlogy a.s., bez DPH.
[[spot]]3.3 Objem vykúpenej elektriny v hodine sa ocení podľa vzorca: výkupná cena = ISOT OKTE znížená o aditív v EUR/MWh.
3.4 Jednotková výkupná cena v danom mesiaci sa určí ako vážený priemer hodinových cien a dodávok podľa bodu 3.3.
3.5 Informácie o cenách elektriny na dennom (spotovom) trhu sú zverejnené na https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
[[/spot]]3.6 Cenová ponuka obsahuje flexibilitu dodávky na úrovni «flexibilita» bez dodatočných poplatkov.
3.7 Plánovaný ročný objem výkupu, ktorý je predmetom ponuky: «objem» MWh.
3.8 Počas záporných cien na dennom trhu vo viac ako dvoch bezprostredne po sebe idúcich hodinách si Výkupca vyhradzuje právo žiadať od Výrobcu obmedzenie dodávky elektriny do distribučnej siete[[kompenzacia]], pričom Výrobca má nárok na kompenzáciu za nedodanú elektrinu[[/kompenzacia]].$t$),
    'podmienky', pg_temp.tpl_sec('4. OSTATNÉ PODMIENKY', $t$4.1 Splatnosť vyúčtovacej faktúry za výkup elektriny je «splatnosť faktúr».
4.2 Fakturačný podklad pripravuje a odosiela Výkupca do 10. dňa v mesiaci.
4.3 Údaje o elektrine dodanej do distribučnej siete nájdete v mobilnej aplikácii alebo vo webovom portáli po aktivácii prístupu.
4.4 Odpovede na najčastejšie otázky k téme výkupu elektriny nájdete na www.greenlogy.com/vykup-elektriny-firmy-faq.$t$),
    'platnost', pg_temp.tpl_sec('5. PLATNOSŤ CENOVEJ PONUKY', $t$5.1 Cenová ponuka platí do «platnosť čas» hod. «platnosť dátum».
5.2 Cenová ponuka je záväzná až po potvrdení Záväznej objednávky osobou/osobami konajúcou/konajúcimi za Výrobcu, a to tlačidlom „Záväzne objednávam“ na stránke ponuky alebo zaslaním podpísanej Záväznej objednávky na trading@greenlogy.com.
5.3 Ak v lehote platnosti ponuky Výrobca nepotvrdí Záväznú objednávku, má sa za to, že ponuku odmietol, a Výrobcovi ani Výkupcovi z nej nevyplývajú žiadne záväzky.$t$),
    'vseobecne', pg_temp.tpl_sec('6. VŠEOBECNÉ USTANOVENIA', $t$6.1 Obchodné podmienky služby výkup elektriny sú dostupné na www.greenlogy.com v sekcii Pomoc a podpora.
6.2 Osobné údaje spracúvame na základe oprávneného záujmu a Výrobca má právo namietať. Ďalšie informácie o spracúvaní osobných údajov sú uvedené na www.greenlogy.com v sekcii Pomoc a podpora.$t$),
    'objednavka', pg_temp.tpl_sec('POTVRDENIE O PRIJATÍ PONUKY – ZÁVÄZNÁ OBJEDNÁVKA', $t$VÝKUPCA: Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, IČO: 53223713, IČ DPH: SK2121307474
VÝROBCA: «názov», «sídlo», IČO: «IČO», IČ DPH: «IČ DPH»
Výrobca potvrdzuje, že úplne prijíma od Výkupcu Cenovú ponuku č. «číslo ponuky» zo dňa «dátum ponuky», variant «variant», ktorá je platná do «dátum platnosti».
Potvrdenie tejto Záväznej objednávky Výrobcom sa považuje za záväznú objednávku na službu výkupu zelenej elektriny s prevzatím zodpovednosti za odchýlku, za podmienok obsiahnutých v Cenovej ponuke č. «číslo ponuky» a platných Všeobecných obchodných podmienok Greenlogy a.s. zverejnených na www.greenlogy.com.
Akceptáciou tejto Záväznej objednávky sa Výrobca zaväzuje uzatvoriť s Výkupcom najneskôr do 14 kalendárnych dní odo dňa akceptácie Zmluvu o výkupe zelenej elektriny s prevzatím zodpovednosti za odchýlku a splnomocňuje Výkupcu vykonať všetky potrebné kroky na zabezpečenie výkupu elektriny a zrealizovať zmenový proces, ktorého výsledkom bude zaradenie odberných miest Výrobcu do bilančnej skupiny Výkupcu.
Výrobca sa zaväzuje poskytnúť Výkupcovi do 7 dní od akceptácie Záväznej objednávky všetky podklady potrebné na uzavretie Zmluvy, ktorých špecifikáciu stanoví Výkupca. Zmluvu na autorizáciu elektronickou formou predloží Výkupca Výrobcovi najneskôr do 10 dní od akceptácie Záväznej objednávky.
Výrobca berie na vedomie a súhlasí s tým, že Výkupca je po obdržaní tohto Potvrdenia o prijatí ponuky oprávnený vykonať nevyhnutné kroky na zabezpečenie výkupu elektriny od Výrobcu.
Výrobca sa zároveň zaväzuje uhradiť Výkupcovi zmluvnú pokutu vo výške «zmluvná pokuta» € za každú MWh plánovaného ročného objemu výkupu podľa bodu 3.7 Cenovej ponuky č. «číslo ponuky» v prípade, že s Výkupcom neuzatvorí Zmluvu o výkupe elektriny, zmarí zmenový proces alebo od tejto Záväznej objednávky odstúpi.$t$))),
  -- ---------------------------------------------------------------- výkup EN
  ('vykup', 'en', 'navrh', '{"zmluvna_pokuta": 30}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('PRICE OFFER · No.: «číslo ponuky»', $t$purchase of electricity generated from renewable energy sources
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovak Republic, +421 2 3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. PRODUCER DETAILS', $t$Producer name: «názov»
Registered office: «sídlo»
Company ID: «IČO»
VAT ID: «IČ DPH»
Contact person: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. SUBJECT OF THE OFFER', $t$2.1 The subject of this price offer is the purchase of green electricity including balancing responsibility, in accordance with section 3 and the applicable Terms and Conditions of the electricity purchase service published at www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. ELECTRICITY PURCHASE PRICE OFFER', $t$3.1 Greenlogy offers the following electricity purchase prices:
«tabuľka variantov»
3.2 The prices cover only the services of the electricity purchaser Greenlogy a.s. and exclude VAT.
[[spot]]3.3 The electricity purchased in each hour is priced as: purchase price = OKTE ISOT price minus the adder in EUR/MWh.
3.4 The unit purchase price for a given month is the weighted average of the hourly prices and supplies under 3.3.
3.5 Day-ahead (spot) market prices are published at https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
[[/spot]]3.6 The offer includes «flexibilita» supply flexibility at no additional charge.
3.7 Planned annual purchase volume covered by this offer: «objem» MWh.
3.8 During negative day-ahead prices lasting more than two consecutive hours, the Purchaser reserves the right to ask the Producer to curtail supply to the distribution grid[[kompenzacia]], in which case the Producer is entitled to compensation for the electricity not supplied[[/kompenzacia]].$t$),
    'podmienky', pg_temp.tpl_sec('4. OTHER TERMS', $t$4.1 The settlement invoice for purchased electricity is payable within «splatnosť faktúr».
4.2 The Purchaser prepares and sends the billing statement by the 10th day of each month.
4.3 Data on electricity supplied to the grid is available in the mobile app or web portal once access is activated.
4.4 Answers to frequently asked questions about electricity purchase: www.greenlogy.com/vykup-elektriny-firmy-faq.$t$),
    'platnost', pg_temp.tpl_sec('5. VALIDITY OF THE OFFER', $t$5.1 This offer is valid until «platnosť čas» on «platnosť dátum».
5.2 The offer becomes binding only once the Binding Order is confirmed by the person(s) authorised to act for the Producer, either by clicking „Place binding order“ on the offer page or by sending the signed Binding Order to trading@greenlogy.com.
5.3 If the Producer does not confirm the Binding Order within the validity period, the offer is deemed rejected and neither party has any obligations arising from it.$t$),
    'vseobecne', pg_temp.tpl_sec('6. GENERAL PROVISIONS', $t$6.1 The Terms and Conditions of the electricity purchase service are available at www.greenlogy.com under Help & Support.
6.2 We process personal data on the basis of legitimate interest and the Producer has the right to object. More information on personal data processing is available at www.greenlogy.com under Help & Support.$t$),
    'objednavka', pg_temp.tpl_sec('CONFIRMATION OF ACCEPTANCE – BINDING ORDER', $t$PURCHASER: Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Company ID: 53223713, VAT ID: SK2121307474
PRODUCER: «názov», «sídlo», Company ID: «IČO», VAT ID: «IČ DPH»
The Producer confirms that it fully accepts the Purchaser's Price Offer No. «číslo ponuky» dated «dátum ponuky», variant «variant», valid until «dátum platnosti».
Confirmation of this Binding Order by the Producer constitutes a binding order for the green electricity purchase service including balancing responsibility, under the conditions of Price Offer No. «číslo ponuky» and the applicable General Terms and Conditions of Greenlogy a.s. published at www.greenlogy.com.
By accepting this Binding Order, the Producer undertakes to conclude with the Purchaser, within 14 calendar days of acceptance, a Contract for the purchase of green electricity including balancing responsibility, and authorises the Purchaser to take all steps necessary to secure the electricity purchase and to carry out the switching process, resulting in the Producer's metering points being included in the Purchaser's balancing group.
The Producer undertakes to provide the Purchaser, within 7 days of acceptance, with all documents required to conclude the Contract as specified by the Purchaser. The Purchaser will submit the Contract for electronic authorisation within 10 days of acceptance.
The Producer acknowledges and agrees that, upon receipt of this Confirmation, the Purchaser is entitled to take the steps necessary to secure the electricity purchase from the Producer.
The Producer further undertakes to pay the Purchaser a contractual penalty of «zmluvná pokuta» € per MWh of the planned annual purchase volume under section 3.7 of Price Offer No. «číslo ponuky» if it fails to conclude the electricity purchase Contract with the Purchaser, frustrates the switching process or withdraws from this Binding Order.$t$))),
  -- ---------------------------------------------------------------- VIWA SK (bez záväznej objednávky a pokuty)
  ('viwa', 'sk', 'platna', '{}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('CENOVÁ PONUKA · č.: «číslo ponuky»', $t$Služba Green ViWA – Virtuálna peňaženka
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovenská republika, 02/3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. ÚDAJE O VÝROBCOVI', $t$Názov výrobcu: «názov»
Sídlo: «sídlo»
IČO: «IČO»
IČ DPH: «IČ DPH»
Kontaktná osoba: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. PREDMET PONUKY', $t$2.1 Predmetom cenovej ponuky pre Výrobcu je služba Green ViWA – virtuálna peňaženka s prevzatím zodpovednosti za odchýlku v súlade s podmienkami v bode 3 a platnými Obchodnými podmienkami služby Green ViWA, ktoré sú zverejnené na www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. CENOVÁ PONUKA SLUŽBY GREEN VIWA – VIRTUÁLNA PEŇAŽENKA', $t$3.1 Greenlogy ponúka nasledovnú cenovú ponuku pre službu Green ViWA s viazanosťou na obdobie «obdobie»:
«tabuľka variantov»
3.2 Koeficient výmeny prebytkov elektriny z lokálneho zdroja = spotová hodinová cena × «koeficient».
3.3 Poplatok za odchýlku = «poplatok za kW» €/kW/mesiac.
3.4 Informácie o cenách na dennom (spotovom) trhu s elektrinou sú zverejnené na https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
3.5 Ceny uvedené v ponuke sú bez DPH.$t$),
    'podmienky', pg_temp.tpl_sec('4. OSTATNÉ PODMIENKY', $t$4.1 Splatnosť vyúčtovacej faktúry za poskytnutie služby je «splatnosť faktúr».
4.2 Mesačný poplatok za službu Green ViWA bude vyúčtovaný samostatnou faktúrou, ak ho nebude možné vyúčtovať na faktúre za odber elektriny, prípadne odpočítaním z kreditov v rámci služby Green ViWA.
4.3 Údaje o transakciách v rámci služby Green ViWA nájdete v mobilnej aplikácii alebo vo webovom portáli po aktivácii prístupu.
4.4 Odpovede na najčastejšie otázky k téme služby Green ViWA nájdete na https://www.greenlogy.com/green-viwa-virtualna-penazenka-firmy.$t$),
    'platnost', pg_temp.tpl_sec('5. PLATNOSŤ CENOVEJ PONUKY', $t$5.1 Cenová ponuka platí do «platnosť čas» hod. «platnosť dátum», po uplynutí tohto termínu sa stáva neplatnou.
5.2 Cenová ponuka je záväzná až po jej prijatí osobou/osobami konajúcou/konajúcimi za Výrobcu, a to tlačidlom „Prijímam ponuku“ na stránke ponuky alebo zaslaním podpísanej ponuky na trading@greenlogy.com.$t$),
    'objednavka', pg_temp.tpl_sec('PRIJATIE PONUKY', $t$Štatutárny zástupca Výrobcu svojím potvrdením vyjadruje súhlas s obsahom predloženej Cenovej ponuky č. «číslo ponuky» zo dňa «dátum ponuky», variant «variant», platnej do «dátum platnosti».$t$))),
  -- ---------------------------------------------------------------- VIWA EN
  ('viwa', 'en', 'navrh', '{}'::jsonb, jsonb_build_object(
    'hlavicka', pg_temp.tpl_sec('PRICE OFFER · No.: «číslo ponuky»', $t$Green ViWA service – Virtual Wallet
Greenlogy a.s., Závodská cesta 2945/38, 010 01 Žilina, Slovak Republic, +421 2 3305 6444$t$),
    'udaje', pg_temp.tpl_sec('1. PRODUCER DETAILS', $t$Producer name: «názov»
Registered office: «sídlo»
Company ID: «IČO»
VAT ID: «IČ DPH»
Contact person: «kontakt meno», «kontakt e-mail», «kontakt telefón»$t$),
    'predmet', pg_temp.tpl_sec('2. SUBJECT OF THE OFFER', $t$2.1 The subject of this price offer is the Green ViWA – Virtual Wallet service including balancing responsibility, in accordance with section 3 and the applicable Green ViWA Terms and Conditions published at www.greenlogy.com.$t$),
    'cenova_ponuka', pg_temp.tpl_sec('3. GREEN VIWA – VIRTUAL WALLET PRICE OFFER', $t$3.1 Greenlogy offers the following price for the Green ViWA service with a commitment period of «obdobie»:
«tabuľka variantov»
3.2 Exchange coefficient for surplus electricity from the local source = hourly spot price × «koeficient».
3.3 Imbalance fee = «poplatok za kW» €/kW/month.
3.4 Day-ahead (spot) market prices are published at https://www.okte.sk/sk/kratkodoby-trh/zverejnenie-udajov-dt/celkove-vysledky-dt/.
3.5 Prices are exclusive of VAT.$t$),
    'podmienky', pg_temp.tpl_sec('4. OTHER TERMS', $t$4.1 The settlement invoice for the service is payable within «splatnosť faktúr».
4.2 The monthly Green ViWA fee will be invoiced separately if it cannot be included in the electricity consumption invoice, or deducted from credits within the Green ViWA service.
4.3 Transaction data for the Green ViWA service is available in the mobile app or web portal once access is activated.
4.4 Answers to frequently asked questions about Green ViWA: https://www.greenlogy.com/green-viwa-virtualna-penazenka-firmy.$t$),
    'platnost', pg_temp.tpl_sec('5. VALIDITY OF THE OFFER', $t$5.1 This offer is valid until «platnosť čas» on «platnosť dátum»; after that date it becomes void.
5.2 The offer becomes binding only once accepted by the person(s) authorised to act for the Producer, by clicking „Accept offer“ on the offer page or by sending the signed offer to trading@greenlogy.com.$t$),
    'objednavka', pg_temp.tpl_sec('ACCEPTANCE OF THE OFFER', $t$By confirming, the Producer's statutory representative agrees with the content of Price Offer No. «číslo ponuky» dated «dátum ponuky», variant «variant», valid until «dátum platnosti».$t$)))
 ) AS x(kind, lang, status, defaults, sections);
DROP FUNCTION pg_temp.tpl_common(text);
DROP FUNCTION pg_temp.tpl_sec(text, text);

-- ============================================================================
-- 6. Ceny VIWA z cenníka (balík: mesačný poplatok účtu, €/kW za odchýlku) a zablokovaná verzia (náhrady 0036/0038)
-- ============================================================================

-- Položky VIWA podľa balíka variantu, z cenníka platného k začiatku dodávky: komodita (balík, model cenník) a €/kW
-- pre každé OOM, mesačný poplatok účtu raz za variant
CREATE FUNCTION offer_fill_viwa(p_variant uuid) RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  v    offer_variant;
  o    offer;
  p    product;
  it   price_list_item;
  n    integer := 0;
BEGIN
  SELECT * INTO v FROM offer_variant WHERE id = p_variant;
  IF NOT FOUND OR v.price_kind <> 'viwa' OR v.viwa_package IS NULL THEN
    RETURN 0;
  END IF;
  SELECT * INTO o FROM offer WHERE id = v.offer_id;
  DELETE FROM offer_item WHERE variant_id = v.id AND price_model = 'cennik';
  SELECT * INTO p FROM product WHERE code = 'viwa_' || v.viwa_package;
  IF NOT FOUND THEN
    RETURN 0;
  END IF;
  SELECT i.* INTO it FROM price_list_item i JOIN price_list_version pv ON pv.id = i.version_id
    JOIN price_list pl ON pl.id = pv.price_list_id
   WHERE i.product_id = p.id AND pv.status = 'schvalena' AND pl.org_id = o.org_id
     AND pv.valid_from <= v.supply_from AND (pv.valid_to IS NULL OR pv.valid_to >= v.supply_from)
   ORDER BY pv.valid_from DESC LIMIT 1;
  IF NOT FOUND THEN
    RETURN 0;   -- bez cenníka: výpočet hlási „chýba cena“
  END IF;
  INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id, fee_eur_month)
  VALUES (v.id, NULL, v.org_id, NULL, 'viwa_ucet', p.id, 'cennik', it.id, it.fee_program_eur_month);
  INSERT INTO offer_item (variant_id, oom_id, org_id, year, slot, product_id, price_model, price_list_item_id, fee_kw_eur_month)
  SELECT v.id, x.oom_id, v.org_id, NULL, s.slot, p.id, 'cennik', it.id, CASE WHEN s.slot = 'viwa_kw' THEN it.fee_kw_eur_month END
    FROM deal_oom x CROSS JOIN (VALUES ('komodita'), ('viwa_kw')) s(slot)
   WHERE x.deal_id = o.deal_id
  ON CONFLICT ON CONSTRAINT offer_item_key DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n + 1;
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_fill_viwa(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION offer_variant_after() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (NEW.supply_from, NEW.supply_to, NEW.viwa_package) IS DISTINCT FROM (OLD.supply_from, OLD.supply_to, OLD.viwa_package) THEN
    PERFORM offer_basis_fill(NEW.id);
    -- položky rokov mimo nového obdobia sa odstránia
    DELETE FROM offer_item i WHERE i.variant_id = NEW.id AND i.year IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM offer_variant_months(NEW) m WHERE m.year = i.year);
    IF NEW.price_kind = 'cennik' THEN
      PERFORM offer_fill_price_list(NEW.id);
    ELSIF NEW.price_kind = 'viwa' THEN
      PERFORM offer_fill_viwa(NEW.id);   -- 0039
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION offer_reprice(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  -- vlastné schválené výnimky verzie sa zrušia; prevzaté zo starej verzie sa iba odpoja (stará verzia si ich ponechá)
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny' AND offer_id = o.id;
  DELETE FROM approval_price_item a
   USING offer_variant x, approval_request r
   WHERE x.id = a.variant_id AND x.offer_id = o.id AND r.id = a.approval_id AND r.offer_id IS DISTINCT FROM o.id;
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    ELSIF (SELECT price_kind FROM offer_variant WHERE id = v) = 'viwa' THEN
      PERFORM offer_fill_viwa(v);   -- 0039
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;

CREATE OR REPLACE FUNCTION offer_accept_apply(p_offer uuid, p_variant uuid, p_accepted_at timestamptz DEFAULT now()) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  x       offer;
  v_stage uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ponuka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id FOR UPDATE;
  IF o.status NOT IN ('odoslana', 'otvorena') THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_accepted_at IS NULL OR p_accepted_at < o.sent_at OR p_accepted_at > now() + interval '5 minutes'
     OR o.valid_until IS NULL OR p_accepted_at >= o.valid_until THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba v platnosti ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE id = p_variant AND offer_id = o.id) THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke.' USING ERRCODE = 'check_violation';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;

  UPDATE offer SET status = 'akceptovana' WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- rozpracovaná nová verzia: späť do konceptu, čakajúce žiadosti zrušené, odoslať sa nedá (offer_check_internal)
  FOR x IN SELECT * FROM offer WHERE org_id = o.org_id AND number = o.number
                                 AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena') LOOP
    UPDATE approval_request SET status = 'zrusena' WHERE status = 'caka' AND offer_id = x.id;
    -- zablokovanie trvá aj po zrušení akceptácie – odblokuje vlastník obchodu alebo admin (0039, odpoveď F3 6)
    UPDATE offer SET status = 'koncept', blocked_by_offer_id = o.id WHERE id = x.id;
    PERFORM notification_add_deal(ARRAY[d.owner_id, x.created_by], 'ponuka_zablokovana', d.id, NULL, NULL,
      format('Zákazník akceptoval ponuku %s – rozpracovanú verziu %s nemožno odoslať.', offer_display_number(o), offer_display_number(x)));
    PERFORM deal_event_offer(x, 'ponuka_zablokovana', jsonb_build_object('accepted_offer_id', o.id, 'accepted_version', o.version));
  END LOOP;

  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'akceptacia'
   WHERE s.id = d.stage_id AND s.code IN ('prilezitost', 'cenova_ponuka', 'vyjednavanie');
  UPDATE deal SET accepted_variant_id = p_variant, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_akceptovana', d.id, NULL, NULL,
                                'Zákazník akceptoval ponuku ' || offer_display_number(o));
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_akceptovana', jsonb_build_object('variant_id', p_variant, 'accepted_at', p_accepted_at));
END;
$$;

CREATE OR REPLACE FUNCTION offer_check_internal(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
  v_acc   offer;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  -- zákazník akceptoval inú verziu: rozpracovaná verzia sa nedá pripraviť ani odoslať (0038)
  SELECT * INTO v_acc FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.id <> o.id AND x.status = 'akceptovana';
  IF FOUND THEN
    errors := errors || to_jsonb(format('Zákazník akceptoval ponuku %s – túto verziu nemožno odoslať.', offer_display_number(v_acc)));
  ELSIF o.blocked_by_offer_id IS NOT NULL THEN
    errors := errors || to_jsonb('Verzia je zablokovaná po akceptácii inej verzie – zákazník akceptoval inú verziu. Odblokuje ju vlastník obchodu alebo admin.'::text);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE offer_id = o.id) THEN
    errors := errors || to_jsonb('Ponuka nemá variant.'::text);
  END IF;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    FOR r IN SELECT x.year, x.missing, m.eic FROM offer_variant_values(v.id) x LEFT JOIN oom m ON m.id = x.oom_id
              WHERE x.missing IS NOT NULL ORDER BY x.year, m.eic LOOP
      errors := errors || to_jsonb(format('Variant %s (%s): %s – OOM %s, rok %s', chr(64 + v.sort_order), v.name, r.missing, r.eic, r.year));
    END LOOP;
    FOR r IN SELECT x.year, x.price_model, x.voltage_group,
                    min(CASE WHEN x.price_model = 'spot_minus_pct' THEN x.additive_pct
                             WHEN x.price_model IN ('spot_plus_eur', 'spot_minus_eur') THEN x.additive
                             ELSE least(x.price_vt, coalesce(x.price_nt, x.price_vt)) END) AS requested,
                    min(b.th) AS threshold, min(b.src) AS source, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th,
                                         CASE WHEN x.price_model <> 'fix' THEN 'min_aditiv'
                                              WHEN ob.seller_type = 'manazer' THEN 'odhad_portfolia'
                                              ELSE 'cena_pre_obchodnika' END AS src
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold,
                                           'threshold_source', coalesce(r.source, 'cena_pre_obchodnika'), 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
  v_risk := CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END;
  -- schválenie rizika platí pre celý obchod 30 dní, kým sa údaje Finstatu nezhoršia (odpoveď 9)
  v_risk_ok := EXISTS (SELECT 1 FROM approval_request a
                        WHERE a.deal_id = d.id AND a.kind = 'rizikovy_zakaznik' AND a.status = 'schvalena'
                          AND (a.valid_until IS NULL OR a.valid_until > now())
                          AND NOT company_risk_worse(a.risk_snapshot, company_risk_snapshot(d.company_id)));
  RETURN jsonb_build_object('errors', errors, 'needs', needs,
                            'risk_needs_approval', coalesce((v_risk->>'needs_approval')::boolean, false) AND NOT v_risk_ok,
                            'risk', v_risk,
                            'fix_stale', o.priced_on < crm_today()
                                         AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
END;
$$;

-- ============================================================================
-- 7. Dokument ponuky: jedno miesto pre PDF, náhľad aj stránku (premenné, sekcie šablóny, varianty, ceny)
-- ============================================================================

-- Číslo podľa jazyka: SK 1 412,50 · EN 1,412.50
CREATE FUNCTION offer_fmt_num(p numeric, p_dec integer, p_lang offer_language) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p IS NULL THEN '–'
              ELSE CASE p_lang WHEN 'sk' THEN translate(s, ',.', ' ,') ELSE s END END
    FROM (SELECT btrim(to_char(round(p, p_dec), 'FM999,999,999,990' || CASE WHEN p_dec > 0 THEN '.' || repeat('0', p_dec) ELSE '' END)) AS s) x
$$;
CREATE FUNCTION offer_fmt_date(p date, p_lang offer_language) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN p IS NULL THEN '–' WHEN p_lang = 'sk' THEN to_char(p, 'FMDD. FMMM. YYYY') ELSE to_char(p, 'DD/MM/YYYY') END
$$;

-- Vyplnenie textu šablóny: podmienené bloky a premenné (chýbajúca hodnota = „–“)
CREATE FUNCTION offer_template_fill(p_text text, p_vars jsonb, p_spot boolean, p_komp boolean) RETURNS text
LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  t text := coalesce(p_text, '');
  k text;
BEGIN
  t := regexp_replace(t, '\[\[spot\]\](.*?)\[\[/spot\]\]', CASE WHEN p_spot THEN '\1' ELSE '' END, 'g');
  t := regexp_replace(t, '\[\[kompenzacia\]\](.*?)\[\[/kompenzacia\]\]', CASE WHEN p_komp THEN '\1' ELSE '' END, 'g');
  FOR k IN SELECT jsonb_object_keys(p_vars) LOOP
    IF k <> 'tabuľka variantov' THEN
      t := replace(t, '«' || k || '»', coalesce(nullif(p_vars->>k, ''), '–'));
    END IF;
  END LOOP;
  RETURN t;
END;
$$;

-- Zjednotenie znenia pred odtlačkom: Unicode NFC, konce riadkov \n, bez nadbytočných medzier a prázdnych riadkov
CREATE FUNCTION offer_terms_normalize(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT string_agg(l, E'\n' ORDER BY n)
    FROM (SELECT n, btrim(regexp_replace(l, '[ \t ]+', ' ', 'g')) AS l
            FROM regexp_split_to_table(normalize(replace(coalesce(p, ''), E'\r\n', E'\n'), NFC), E'\n') WITH ORDINALITY AS s(l, n)) x
   WHERE l <> ''
$$;

-- Šablóna ponuky: uložená pri odoslaní, inak platná pre druh a jazyk, inak návrh (iba náhľad)
CREATE FUNCTION offer_template_for(p_offer uuid) RETURNS offer_template_version
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT t.* FROM offer o
    JOIN offer_template_version t ON t.org_id = o.org_id AND t.kind = o.kind AND t.language = o.language
   WHERE o.id = p_offer
     AND (t.id = o.template_version_id OR (o.template_version_id IS NULL AND t.status IN ('platna', 'navrh')))
   ORDER BY (t.id = o.template_version_id) DESC, (t.status = 'platna') DESC
   LIMIT 1
$$;
REVOKE EXECUTE ON FUNCTION offer_template_for(uuid) FROM PUBLIC;

-- Platnosť pre dokument: uložená, inak predvolená od teraz (náhľad pred odoslaním)
CREATE FUNCTION offer_doc_valid_until(o offer) RETURNS timestamptz
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT coalesce(o.valid_until,
                  offer_default_valid_until(o.org_id, now(),
                    EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia'))))
$$;
REVOKE EXECUTE ON FUNCTION offer_doc_valid_until(offer) FROM PUBLIC;

-- Údaje variantov pre dokument (bez EIC a bez interných hodnôt): obdobie, podmienky, riadky cien zlúčené podľa
-- produktu, napätia a cien, VIWA a pri domácnosti ceny s DPH, mesačné poplatky a odhad ročných nákladov
CREATE FUNCTION offer_doc_variants(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  v     offer_variant;
  lang  offer_language;
  res   jsonb := '[]';
  rows  jsonb;
  vol   numeric;
  viwa  jsonb;
  hh    jsonb;
  coef  numeric;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  lang := o.language;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    -- ročný objem: plánovaný, inak súčet OOM (spotreba alebo výroba)
    SELECT coalesce(v.planned_volume_mwh,
                    sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                             THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                             ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END))
      INTO vol FROM deal_oom x WHERE x.deal_id = o.deal_id;

    -- riadky: OOM s rovnakým produktom, napätím a cenami po rokoch sa zlúčia (počet OOM, súčet objemu)
    WITH it AS (
      SELECT i.oom_id, i.product_id, i.price_model, i.year, i.price_vt_eur_mwh AS vt, i.price_nt_eur_mwh AS nt,
             i.additive_eur_mwh AS ad, i.additive_pct AS pct,
             coalesce(li.vat_rate, p.vat_rate) AS vat
        FROM offer_item i JOIN product p ON p.id = i.product_id
        LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id AND i.slot = 'komodita' AND i.oom_id IS NOT NULL
    ),
    per_oom AS (
      SELECT it.oom_id, it.product_id, it.price_model, max(it.vat) AS vat,
             jsonb_agg(jsonb_build_object('year', it.year, 'vt', it.vt, 'nt', it.nt, 'ad', it.ad, 'pct', it.pct)
                       ORDER BY it.year NULLS FIRST) AS prices
        FROM it GROUP BY 1, 2, 3
    ),
    grp AS (
      SELECT po.product_id, oom_voltage_group(m.voltage_level) AS vg, po.price_model, po.prices, max(po.vat) AS vat,
             count(*)::int AS ooms,
             sum(CASE WHEN o.kind IN ('vykup', 'viwa')
                      THEN coalesce(x.planned_feed_in_mwh, x.source_power_kw * 4 * 365 * 0.1 / 1000, 0)
                      ELSE coalesce(x.planned_vt_mwh, 0) + coalesce(x.planned_nt_mwh, 0) END) AS vol
        FROM per_oom po
        JOIN oom m ON m.id = po.oom_id
        JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = po.oom_id
       GROUP BY 1, 2, 3, 4
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
             'product', p.name, 'voltage_group', g.vg, 'oom_count', g.ooms, 'volume_mwh', round(g.vol, 3),
             'price_model', g.price_model, 'vat_rate', g.vat,
             'prices', (SELECT jsonb_agg(jsonb_build_object(
                           'year', (e->>'year')::int,
                           'text', CASE g.price_model
                                     WHEN 'spot_plus_eur' THEN 'SPOT + ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_eur' THEN 'SPOT − ' || offer_fmt_num((e->>'ad')::numeric, 2, lang) || ' €/MWh'
                                     WHEN 'spot_minus_pct' THEN 'SPOT − ' || offer_fmt_num((e->>'pct')::numeric, 2, lang) || ' %'
                                     ELSE offer_fmt_num((e->>'vt')::numeric, 2, lang)
                                          || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric, 2, lang) ELSE '' END
                                          || ' €/MWh' END,
                           'text_vat', CASE WHEN o.household AND g.price_model IN ('fix', 'cennik') AND g.vat IS NOT NULL THEN
                                         offer_fmt_num((e->>'vt')::numeric * (1 + g.vat / 100), 2, lang)
                                         || CASE WHEN e->>'nt' IS NOT NULL THEN ' / ' || offer_fmt_num((e->>'nt')::numeric * (1 + g.vat / 100), 2, lang) ELSE '' END
                                         || ' €/MWh' END)
                         ORDER BY (e->>'year')::int NULLS FIRST)
                          FROM jsonb_array_elements(g.prices) e))
             ORDER BY g.vg, p.name), '[]')
      INTO rows
      FROM grp g JOIN product p ON p.id = g.product_id;

    -- VIWA: balík, mesačný poplatok účtu, €/kW za odchýlku, koeficient výmeny (1 − aditív balíka / 100)
    viwa := NULL;
    IF v.price_kind = 'viwa' THEN
      coef := 1 - contract_param(o.org_id, 'viwa_aditiv_' || v.viwa_package, o.priced_on) / 100;
      SELECT jsonb_build_object(
               'package', upper(v.viwa_package),
               'monthly_fee', (SELECT fee_eur_month FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_ucet'),
               'fee_kw', (SELECT max(fee_kw_eur_month) FROM offer_item WHERE variant_id = v.id AND slot = 'viwa_kw'),
               'coefficient', coef,
               'power_kw', (SELECT sum(coalesce(x.source_power_kw, m.source_power_kw, 0)) FROM deal_oom x JOIN oom m ON m.id = x.oom_id
                             WHERE x.deal_id = o.deal_id))
        INTO viwa;
    END IF;

    -- domácnosť: mesačné poplatky (OM, ZEM, VBattery) a odhad ročných nákladov na komoditu bez DPH a s DPH
    hh := NULL;
    IF o.household THEN
      SELECT jsonb_build_object(
               'fees_month', sum(coalesce(i.fee_eur_month, 0)),
               'cost_year', (SELECT sum(coalesce(c.price_vt_eur_mwh, 0) * coalesce(x.planned_vt_mwh, 0)
                                        + coalesce(c.price_nt_eur_mwh, c.price_vt_eur_mwh, 0) * coalesce(x.planned_nt_mwh, 0))
                               FROM offer_item c JOIN deal_oom x ON x.deal_id = o.deal_id AND x.oom_id = c.oom_id
                              WHERE c.variant_id = v.id AND c.slot = 'komodita' AND c.price_model IN ('fix', 'cennik')),
               'vat_rate', max(coalesce(li.vat_rate, p.vat_rate)))
        INTO hh
        FROM offer_item i JOIN product p ON p.id = i.product_id LEFT JOIN price_list_item li ON li.id = i.price_list_item_id
       WHERE i.variant_id = v.id;
      hh := hh || jsonb_build_object('cost_year_total', round((hh->>'cost_year')::numeric + (hh->>'fees_month')::numeric * 12, 2));
    END IF;

    res := res || jsonb_build_object(
      'id', v.id, 'letter', chr(64 + v.sort_order), 'name', v.name, 'label', chr(64 + v.sort_order) || ' · ' || v.name,
      'price_kind', v.price_kind,
      'period', CASE WHEN v.supply_to IS NULL
                     THEN CASE lang WHEN 'sk' THEN 'od ' || offer_fmt_date(v.supply_from, lang) || ' na neurčito'
                                    ELSE 'from ' || offer_fmt_date(v.supply_from, lang) || ', indefinite' END
                     ELSE offer_fmt_date(v.supply_from, lang) || ' – ' || offer_fmt_date(v.supply_to, lang) END,
      'flexibility', CASE WHEN v.flexibility_pct IS NULL THEN CASE lang WHEN 'sk' THEN 'plnej flexibility' ELSE 'full' END
                          ELSE '± ' || offer_fmt_num(v.flexibility_pct, 0, lang) || ' %' END,
      'volume_mwh', round(vol, 3),
      'volume_text', offer_fmt_num(vol, 1, lang),
      'advance', CASE v.advance_kind
                   WHEN 'financna_zabezpeka' THEN CASE lang WHEN 'sk' THEN 'finančnej zábezpeky' ELSE 'a financial guarantee' END
                   ELSE CASE lang WHEN 'sk' THEN offer_fmt_num(v.advance_pct, 0, lang) || ' % z 1/12 plánovaného ročného odberu'
                                  ELSE offer_fmt_num(v.advance_pct, 0, lang) || '% of 1/12 of the planned annual consumption' END END,
      'advance_due', CASE WHEN v.advance_due_day IS NULL THEN NULL
                          WHEN lang = 'sk' THEN v.advance_due_day || '. deň v mesiaci'
                          ELSE 'day ' || v.advance_due_day || ' of the month' END,
      'invoice_due', v.invoice_due_days || CASE lang WHEN 'sk' THEN ' dní' ELSE ' days' END,
      'spot', EXISTS (SELECT 1 FROM offer_item i WHERE i.variant_id = v.id AND i.slot = 'komodita'
                        AND i.price_model IN ('spot_plus_eur', 'spot_minus_eur', 'spot_minus_pct'))
              OR v.price_kind = 'spot',
      'negative_price_compensation', v.negative_price_compensation,
      'rows', rows, 'viwa', viwa, 'household', hh);
  END LOOP;
  RETURN res;
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_doc_variants(uuid) FROM PUBLIC;

-- Premenné ponuky (bez «variant» – ten dopĺňa znenie objednávky). Hodnota rovnaká vo všetkých variantoch
-- sa vypíše raz, inak po variantoch („A: …; B: …“).
CREATE FUNCTION offer_doc_vars(p_offer uuid, p_variants jsonb) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  d     deal;
  c     company;
  pe    contact;
  k     contact;
  u     app_user;
  t     offer_template_version;
  lang  offer_language;
  vu    timestamptz;
  pen   numeric;
  f     text;
  per   jsonb := '{}';
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO c FROM company WHERE id = d.company_id;
  SELECT * INTO pe FROM contact WHERE id = d.person_id;
  SELECT * INTO k FROM contact WHERE id = o.contact_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  t := offer_template_for(o.id);
  lang := o.language;
  vu := offer_doc_valid_until(o);
  pen := coalesce(o.penalty_eur_mwh, (t.defaults->>'zmluvna_pokuta')::numeric);
  FOREACH f IN ARRAY ARRAY['flexibility', 'volume_text', 'advance', 'advance_due', 'invoice_due', 'period'] LOOP
    per := per || jsonb_build_object(f,
      CASE WHEN (SELECT count(DISTINCT coalesce(x->>f, '')) FROM jsonb_array_elements(p_variants) x) <= 1
           THEN (SELECT x->>f FROM jsonb_array_elements(p_variants) x LIMIT 1)
           ELSE (SELECT string_agg((x->>'letter') || ': ' || coalesce(x->>f, '–'), '; ') FROM jsonb_array_elements(p_variants) x) END);
  END LOOP;
  RETURN jsonb_build_object(
    'číslo ponuky', offer_display_number(o),
    'dátum ponuky', offer_fmt_date((coalesce(o.sent_at, now()) AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'názov', coalesce(c.name, nullif(btrim(concat_ws(' ', pe.title, pe.first_name, pe.last_name)), '')),
    'sídlo', coalesce(c.address, pe.address),
    'IČO', c.ico,
    'IČ DPH', c.ic_dph,
    'kontakt meno', nullif(btrim(concat_ws(' ', k.title, k.first_name, k.last_name)), ''),
    'kontakt e-mail', k.email,
    'kontakt telefón', coalesce(k.mobile, k.phone),
    'obchodník meno', u.name,
    'obchodník funkcia', u.job_title,
    'obchodník telefón', u.phone,
    'obchodník e-mail', u.email,
    'flexibilita', per->>'flexibility',
    'objem', per->>'volume_text',
    'výška preddavkov', per->>'advance',
    'splatnosť preddavku', per->>'advance_due',
    'splatnosť faktúr', per->>'invoice_due',
    'obdobie', per->>'period',
    'platnosť čas', to_char(vu AT TIME ZONE 'Europe/Bratislava', 'HH24:MI'),
    'platnosť dátum', offer_fmt_date((vu AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'dátum platnosti', to_char(vu AT TIME ZONE 'Europe/Bratislava', 'HH24:MI') || CASE lang WHEN 'sk' THEN ' hod. ' ELSE ' on ' END
                       || offer_fmt_date((vu AT TIME ZONE 'Europe/Bratislava')::date, lang),
    'zmluvná pokuta', offer_fmt_num(pen, 2, lang),
    'koeficient', (SELECT CASE WHEN count(DISTINCT x->'viwa'->>'coefficient') <= 1
                               THEN offer_fmt_num(max((x->'viwa'->>'coefficient')::numeric), 2, lang)
                               ELSE string_agg((x->>'letter') || ': ' || offer_fmt_num((x->'viwa'->>'coefficient')::numeric, 2, lang), '; ') END
                     FROM jsonb_array_elements(p_variants) x WHERE x->'viwa' IS NOT NULL AND x->>'viwa' <> 'null'),
    'poplatok za kW', (SELECT CASE WHEN count(DISTINCT x->'viwa'->>'fee_kw') <= 1
                                   THEN offer_fmt_num(max((x->'viwa'->>'fee_kw')::numeric), 2, lang)
                                   ELSE string_agg((x->>'letter') || ': ' || offer_fmt_num((x->'viwa'->>'fee_kw')::numeric, 2, lang), '; ') END
                         FROM jsonb_array_elements(p_variants) x WHERE x->'viwa' IS NOT NULL AND x->>'viwa' <> 'null'));
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_doc_vars(uuid, jsonb) FROM PUBLIC;

-- Znenie záväznej objednávky (VIWA: prijatia ponuky) pre variant – zjednotené; z neho odtlačok
CREATE FUNCTION offer_terms_text(p_offer uuid, p_variant uuid) RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  t    offer_template_version := offer_template_for(p_offer);
  vs   jsonb := offer_doc_variants(p_offer);
  vars jsonb := offer_doc_vars(p_offer, vs);
  v    jsonb;
BEGIN
  SELECT x INTO v FROM jsonb_array_elements(vs) x WHERE x->>'id' = p_variant::text;
  IF v IS NULL OR t.id IS NULL THEN
    RETURN NULL;
  END IF;
  vars := vars || jsonb_build_object('variant', v->>'label');
  RETURN offer_terms_normalize(
    offer_template_fill(coalesce(t.sections->'objednavka'->>'nadpis', '') || E'\n' || coalesce(t.sections->'objednavka'->>'text', ''),
                        vars, (v->>'spot')::boolean, (v->>'negative_price_compensation')::boolean));
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_terms_text(uuid, uuid) FROM PUBLIC;

CREATE FUNCTION offer_terms_sha(p_text text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT encode(sha256(convert_to(p_text, 'UTF8')), 'hex')
$$;

-- Celý dokument ponuky (bez kontroly práv – iba kód databázy a verejné funkcie)
CREATE FUNCTION offer_document_internal(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  t    offer_template_version;
  vs   jsonb;
  vars jsonb;
  sec  jsonb := '[]';
  key  text;
  spot boolean;
  komp boolean;
  vu   timestamptz;
  acc  offer_acceptance;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  IF NOT FOUND THEN
    RETURN NULL;
  END IF;
  t := offer_template_for(o.id);
  vs := offer_doc_variants(o.id);
  vars := offer_doc_vars(o.id, vs);
  vu := offer_doc_valid_until(o);
  spot := EXISTS (SELECT 1 FROM jsonb_array_elements(vs) x WHERE (x->>'spot')::boolean);
  komp := EXISTS (SELECT 1 FROM jsonb_array_elements(vs) x WHERE (x->>'negative_price_compensation')::boolean);
  IF t.id IS NOT NULL THEN
    FOREACH key IN ARRAY offer_template_keys() LOOP
      CONTINUE WHEN NOT t.sections ? key OR key = 'objednavka';
      sec := sec || jsonb_build_object('key', key,
                                       'nadpis', offer_template_fill(t.sections->key->>'nadpis', vars, spot, komp),
                                       'text', offer_template_fill(t.sections->key->>'text', vars, spot, komp));
    END LOOP;
  END IF;
  SELECT * INTO acc FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  RETURN jsonb_build_object(
    'offer', jsonb_build_object('id', o.id, 'number', o.number, 'version', o.version, 'display_number', offer_display_number(o),
                                'kind', o.kind, 'language', o.language, 'household', o.household, 'status', o.status,
                                'state', offer_state(o), 'sent_at', o.sent_at, 'valid_until', vu, 'stored_valid_until', o.valid_until,
                                'pdf', o.pdf_key IS NOT NULL),
    'template', CASE WHEN t.id IS NOT NULL THEN jsonb_build_object('id', t.id, 'version', t.version, 'status', t.status,
                                                                    'order_title', offer_template_fill(t.sections->'objednavka'->>'nadpis', vars, spot, komp),
                                                                    -- znenie pre PDF: «variant» ostáva, PDF ho nahradí voľbou variantov
                                                                    'order_text', offer_template_fill(t.sections->'objednavka'->>'text', vars, spot, komp)) END,
    'vars', vars,
    'sections', sec,
    'variants', (SELECT coalesce(jsonb_agg(x || jsonb_build_object(
                    'terms', offer_terms_text(o.id, (x->>'id')::uuid),
                    'terms_sha256', offer_terms_sha(offer_terms_text(o.id, (x->>'id')::uuid)))), '[]')
                   FROM jsonb_array_elements(vs) x),
    'acceptance', CASE WHEN acc.id IS NOT NULL THEN jsonb_build_object(
                    'variant_id', acc.variant_id, 'variant', (SELECT chr(64 + sort_order) || ' · ' || name FROM offer_variant WHERE id = acc.variant_id),
                    'method', acc.method, 'channel', acc.channel, 'accepted_at', acc.accepted_at,
                    'signer_name', acc.signer_name, 'signer_function', acc.signer_function) END);
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_document_internal(uuid) FROM PUBLIC;

-- Dokument pre aplikáciu (náhľad PDF): iba kto vidí obchod
CREATE FUNCTION offer_document(p_offer uuid) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT offer_document_internal(o.id)
    FROM offer o JOIN deal d ON d.id = o.deal_id
   WHERE o.id = p_offer AND d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)
$$;

-- ============================================================================
-- 8. PDF a odkaz pri odoslaní (odpoveď F3 4)
-- ============================================================================

-- PDF uložené v R2 pri odoslaní: kľúč a odtlačok sa zapíšu raz; šablóna sa zafixuje (musí byť platná)
CREATE FUNCTION offer_attach_pdf(p_offer uuid, p_key text, p_sha256 text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  t offer_template_version := offer_template_for(p_offer);
BEGIN
  IF o.status NOT IN ('odoslana', 'otvorena') OR o.pdf_key IS NOT NULL THEN
    RAISE EXCEPTION 'PDF sa ukladá iba pri odoslaní ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF t.id IS NULL OR t.status = 'navrh' THEN
    RAISE EXCEPTION 'Šablóna ponuky (%, %) ešte nie je schválená – admin ju zverejní v Nastaveniach → Šablóny ponúk.',
      o.kind, upper(o.language::text) USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET pdf_key = p_key, pdf_sha256 = p_sha256, pdf_generated_at = now(), template_version_id = t.id
   WHERE id = o.id;
END;
$$;

-- Odkaz na stránku ponuky: v databáze iba SHA-256 tokenu. Prvý odkaz vznikne pri odoslaní (kto odosiela);
-- nový odkaz (starý prestane platiť) iba vlastník obchodu alebo admin; platnosť ponuky sa nemení.
CREATE FUNCTION offer_link_set(p_offer uuid, p_hash text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  d deal;
BEGIN
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Neplatný odtlačok odkazu.' USING ERRCODE = 'check_violation';
  END IF;
  IF o.status NOT IN ('odoslana', 'otvorena', 'akceptovana', 'zamietnuta') THEN
    RAISE EXCEPTION 'Odkaz má iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF o.link_hash IS NOT NULL AND NOT (d.owner_id = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Nový odkaz smie vytvoriť iba vlastník obchodu alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  UPDATE offer SET link_hash = p_hash, link_created_at = now(), link_created_by = crm_active_user_id() WHERE id = o.id;
  IF o.link_hash IS NOT NULL THEN
    PERFORM deal_event_offer(o, 'ponuka_odkaz', jsonb_build_object('replaced', true));
  END IF;
END;
$$;

-- ============================================================================
-- 9. Akceptácia: zápis (klik aj ručne), ručná akceptácia, zrušenie adminom, odblokovanie verzie
-- ============================================================================

CREATE FUNCTION offer_accept_record(p_offer uuid, p_variant uuid, p_method text, p_channel text, p_at timestamptz,
                                    p_name text, p_function text, p_ip inet, p_ua text, p_note text, p_signed_key text,
                                    p_recorded_by uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o     offer;
  terms text;
  v_id  uuid;
BEGIN
  IF coalesce(btrim(p_name), '') = '' OR coalesce(btrim(p_function), '') = '' THEN
    RAISE EXCEPTION 'Zadajte meno a funkciu osoby, ktorá ponuku prijala.' USING ERRCODE = 'check_violation';
  END IF;
  terms := offer_terms_text(p_offer, p_variant);
  IF terms IS NULL THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke alebo chýba šablóna.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_accept_apply(p_offer, p_variant, p_at);
  SELECT * INTO o FROM offer WHERE id = p_offer;
  INSERT INTO offer_acceptance (offer_id, variant_id, org_id, method, channel, accepted_at, signer_name, signer_function, ip,
                                user_agent, terms_text, terms_sha256, offer_pdf_sha256, signed_file_key, note, recorded_by)
  VALUES (o.id, p_variant, o.org_id, p_method, p_channel, p_at, btrim(p_name), btrim(p_function), p_ip,
          left(p_ua, 500), terms, offer_terms_sha(terms), o.pdf_sha256, p_signed_key, nullif(btrim(p_note), ''), p_recorded_by)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_accept_record(uuid, uuid, text, text, timestamptz, text, text, inet, text, text, text, uuid) FROM PUBLIC;

-- Ručná akceptácia obchodníkom (odpoveď F3 5): variant, meno, funkcia, čas a kanál povinné; podpísané PDF voliteľné
CREATE FUNCTION offer_accept_manual(p_offer uuid, p_variant uuid, p_name text, p_function text, p_at timestamptz,
                                    p_channel text, p_note text, p_signed_key text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
BEGIN
  IF p_channel IS NULL OR p_channel NOT IN ('telefon', 'email', 'osobne', 'podpisane_pdf') THEN
    RAISE EXCEPTION 'Vyberte, ako zákazník ponuku prijal.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_at IS NULL OR p_at > now() + interval '5 minutes' THEN
    RAISE EXCEPTION 'Zadajte čas akceptácie (nie v budúcnosti).' USING ERRCODE = 'check_violation';
  END IF;
  IF p_signed_key IS NOT NULL AND p_signed_key !~ ('^podpisane/' || o.org_id || '/[0-9]{4}/P[0-9]{2}-[0-9]{6}(-[0-9]+)?-[0-9a-f]{8}\.pdf$') THEN
    RAISE EXCEPTION 'Neplatný súbor podpísanej ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  RETURN offer_accept_record(o.id, p_variant, 'rucne', p_channel, p_at, p_name, p_function, NULL, NULL, p_note, p_signed_key,
                             crm_active_user_id());
END;
$$;

-- Zrušenie akceptácie (odpoveď F3 6): iba admin, s dôvodom, iba bez spárovanej zmluvy (obchod nie je Vyhraté);
-- obchod späť do Vyjednávania, ponuka späť Odoslaná (po platnosti sa zobrazí ako Vypršaná); zablokovaná rozpracovaná
-- verzia ostáva zablokovaná
CREATE FUNCTION offer_acceptance_revoke(p_id uuid, p_reason text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  a       offer_acceptance;
  o       offer;
  d       deal;
  v_stage uuid;
BEGIN
  IF NOT crm_is_admin() THEN
    RAISE EXCEPTION 'Akceptáciu ruší iba admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF coalesce(btrim(p_reason), '') = '' THEN
    RAISE EXCEPTION 'Zadajte dôvod zrušenia akceptácie.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE id = p_id AND org_id = ANY (crm_user_orgs()) FOR UPDATE;
  IF NOT FOUND OR a.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Akceptácia neexistuje alebo už je zrušená.' USING ERRCODE = 'check_violation';
  END IF;
  SELECT * INTO o FROM offer WHERE id = a.offer_id FOR UPDATE;
  SELECT * INTO d FROM deal d2 WHERE d2.id = o.deal_id FOR UPDATE;
  IF d.closed_at IS NOT NULL OR (SELECT code FROM pipeline_stage WHERE id = d.stage_id) = 'vyhrane' THEN
    RAISE EXCEPTION 'K obchodu už je spárovaná zmluva (Vyhraté) – akceptáciu nemožno zrušiť.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer_acceptance SET revoked_at = now(), revoked_by = crm_active_user_id(), revoke_reason = btrim(p_reason) WHERE id = a.id;
  UPDATE offer SET status = 'odoslana' WHERE id = o.id;
  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'vyjednavanie'
   WHERE s.id = d.stage_id AND s.code = 'akceptacia';
  UPDATE deal SET accepted_variant_id = NULL, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'akceptacia_zrusena', jsonb_build_object('reason', btrim(p_reason)));
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'akceptacia_zrusena', d.id, NULL, NULL,
                                'Akceptácia ponuky ' || offer_display_number(o) || ' bola zrušená');
END;
$$;

-- Odblokovanie rozpracovanej verzie (vlastník obchodu alebo admin), ak žiadna verzia nie je akceptovaná
CREATE FUNCTION offer_unblock(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  d deal;
BEGIN
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT (d.owner_id = crm_active_user_id() OR crm_is_admin()) THEN
    RAISE EXCEPTION 'Verziu odblokuje vlastník obchodu alebo admin.' USING ERRCODE = 'insufficient_privilege';
  END IF;
  IF o.blocked_by_offer_id IS NULL THEN
    RAISE EXCEPTION 'Verzia nie je zablokovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF EXISTS (SELECT 1 FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.status = 'akceptovana') THEN
    RAISE EXCEPTION 'Iná verzia je akceptovaná – najprv musí admin akceptáciu zrušiť.' USING ERRCODE = 'check_violation';
  END IF;
  UPDATE offer SET blocked_by_offer_id = NULL WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_odblokovana');
END;
$$;

-- ============================================================================
-- 10. Verejné funkcie pre rolu crm_public (Worker crm-ponuka) – iba jedna ponuka podľa platného odkazu
-- ============================================================================

-- Režim odkazu: aktívna (akceptovať sa dá), len čítanie (do platnosti + 30 dní, aj po akceptácii), neplatný
CREATE FUNCTION offer_public_mode(o offer) RETURNS text
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN o.id IS NULL OR o.link_hash IS NULL OR o.valid_until IS NULL THEN 'neplatny'
              WHEN o.status IN ('odoslana', 'otvorena') AND now() < o.valid_until THEN 'aktivna'
              WHEN o.status IN ('odoslana', 'otvorena', 'akceptovana', 'zamietnuta', 'nahradena')
                   AND now() <= greatest(o.valid_until,
                                         (SELECT max(a.accepted_at) FROM offer_acceptance a WHERE a.offer_id = o.id AND a.revoked_at IS NULL))
                                + interval '30 days' THEN 'len_citanie'
              ELSE 'neplatny' END
$$;

CREATE FUNCTION offer_public_view(p_hash text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  mode text;
  doc  jsonb;
  d    deal;
  u    app_user;
  first boolean := false;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN jsonb_build_object('mode', 'neplatny');
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  mode := offer_public_mode(o);
  IF mode = 'neplatny' THEN
    RETURN jsonb_build_object('mode', 'neplatny');
  END IF;
  -- otvorenie: bez IP; prvé otvorenie odoslanej ponuky → Otvorená a udalosť v časovej osi
  INSERT INTO offer_page_stat (offer_id, first_opened_at, last_opened_at, open_count) VALUES (o.id, now(), now(), 1)
  ON CONFLICT (offer_id) DO UPDATE SET last_opened_at = now(), open_count = offer_page_stat.open_count + 1
  RETURNING (xmax = 0) INTO first;
  IF o.status = 'odoslana' THEN
    UPDATE offer SET status = 'otvorena' WHERE id = o.id;
  END IF;
  IF first THEN
    PERFORM deal_event_offer(o, 'ponuka_otvorena');
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  SELECT * INTO u FROM app_user WHERE id = d.owner_id;
  doc := offer_document_internal(o.id);
  RETURN jsonb_build_object(
    'mode', mode,
    'reason', CASE WHEN mode = 'aktivna' THEN NULL
                   WHEN o.status = 'akceptovana' THEN 'akceptovana'
                   WHEN o.status = 'nahradena' THEN 'nahradena'
                   WHEN o.status = 'zamietnuta' THEN 'zamietnuta'
                   ELSE 'vyprsana' END,
    'document', CASE WHEN mode = 'aktivna' THEN doc
                     ELSE doc || jsonb_build_object('variants', (SELECT jsonb_agg(x - 'terms' - 'terms_sha256') FROM jsonb_array_elements(doc->'variants') x)) END,
    'seller', jsonb_build_object('name', u.name, 'job_title', u.job_title, 'email', u.email, 'phone', u.phone),
    'pdf', o.pdf_key IS NOT NULL);
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_public_view(text) FROM PUBLIC;

CREATE FUNCTION offer_public_pdf(p_hash text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN NULL;
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash;
  IF offer_public_mode(o) = 'neplatny' OR o.pdf_key IS NULL THEN
    RETURN NULL;
  END IF;
  RETURN jsonb_build_object('pdf_key', o.pdf_key, 'file_name', 'Cenova-ponuka-' || replace(offer_display_number(o), '/', '-') || '.pdf');
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_public_pdf(text) FROM PUBLIC;

-- Akceptácia klikom: overí stav a platnosť (čas databázy) a odtlačok znenia, ktoré zákazník videl; dvojklik vráti
-- ten istý výsledok
CREATE FUNCTION offer_public_accept(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text,
                                    p_terms_sha256 text) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o    offer;
  a    offer_acceptance;
  v_id uuid;
BEGIN
  IF p_hash IS NULL OR p_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO o FROM offer WHERE link_hash = p_hash FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Odkaz už neplatí.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO a FROM offer_acceptance WHERE offer_id = o.id AND revoked_at IS NULL;
  IF FOUND THEN
    IF a.variant_id = p_variant AND a.method = 'klik' THEN
      RETURN jsonb_build_object('ok', true, 'repeated', true, 'accepted_at', a.accepted_at);
    END IF;
    RAISE EXCEPTION 'Ponuka už bola akceptovaná.' USING ERRCODE = 'check_violation';
  END IF;
  IF offer_public_mode(o) <> 'aktivna' THEN
    RAISE EXCEPTION 'Platnosť ponuky uplynula alebo ponuka už neplatí.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_ip IS NULL THEN
    RAISE EXCEPTION 'Chýba IP adresa.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_terms_sha256 IS DISTINCT FROM offer_terms_sha(offer_terms_text(o.id, p_variant)) THEN
    RAISE EXCEPTION 'Znenie ponuky sa medzitým zmenilo – obnovte stránku.' USING ERRCODE = 'check_violation';
  END IF;
  v_id := offer_accept_record(o.id, p_variant, 'klik', NULL, now(), p_name, p_function, p_ip, p_ua, NULL, NULL, NULL);
  RETURN jsonb_build_object('ok', true, 'repeated', false, 'accepted_at', now());
END;
$$;
REVOKE EXECUTE ON FUNCTION offer_public_accept(text, uuid, text, text, inet, text, text) FROM PUBLIC;

-- ============================================================================
-- 11. RLS a audit
-- ============================================================================

ALTER TABLE offer_template_version ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_asset ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_acceptance ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_page_stat ENABLE ROW LEVEL SECURITY;

-- šablóny a obrázky: čítajú všetci prihlásení (náhľad ponuky), menia iba admini
CREATE POLICY offer_template_select ON offer_template_version FOR SELECT
  USING (crm_active_user_id() IS NOT NULL AND org_id = ANY (crm_user_orgs()));
CREATE POLICY offer_template_write ON offer_template_version FOR ALL
  USING (crm_is_admin() AND org_id = ANY (crm_user_orgs())) WITH CHECK (crm_is_admin() AND org_id = ANY (crm_user_orgs()));
CREATE POLICY offer_asset_select ON offer_asset FOR SELECT
  USING (crm_active_user_id() IS NOT NULL AND org_id = ANY (crm_user_orgs()));
CREATE POLICY offer_asset_write ON offer_asset FOR ALL
  USING (crm_is_admin() AND org_id = ANY (crm_user_orgs())) WITH CHECK (crm_is_admin() AND org_id = ANY (crm_user_orgs()));
-- akceptácia a otvorenia: podľa ponuky (obchodu); zapisuje iba databáza
CREATE POLICY offer_acceptance_select ON offer_acceptance FOR SELECT USING (EXISTS (SELECT 1 FROM offer o WHERE o.id = offer_id));
CREATE POLICY offer_page_stat_select ON offer_page_stat FOR SELECT USING (EXISTS (SELECT 1 FROM offer o WHERE o.id = offer_id));

-- ============================================================================
-- 12. Izolácia verejnej roly: schéma verejne, bez prístupu do schémy public, bez cudzej identity
-- ============================================================================
-- Rola crm_public (Worker crm-ponuka) smie iba tri funkcie v schéme verejne. Štandardné USAGE na schéme public
-- pre všetkých (PUBLIC) sa odoberá a dostanú ho výslovne roly, ktoré ho potrebujú – inak by verejná rola mohla volať
-- funkcie s právami vlastníka (napr. odhad portfólia) a nastaviť si cudzie app.user_id.

CREATE SCHEMA verejne;
COMMENT ON SCHEMA verejne IS 'iba funkcie pre verejnú stránku ponuky (rola crm_public) – 0039';

CREATE FUNCTION verejne.ponuka_zobrazit(p_hash text) RETURNS jsonb
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT public.offer_public_view(p_hash)
$$;
CREATE FUNCTION verejne.ponuka_pdf(p_hash text) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT public.offer_public_pdf(p_hash)
$$;
CREATE FUNCTION verejne.ponuka_akceptovat(p_hash text, p_variant uuid, p_name text, p_function text, p_ip inet, p_ua text,
                                          p_terms_sha256 text) RETURNS jsonb
LANGUAGE sql VOLATILE SECURITY DEFINER SET search_path = public, pg_temp AS $$
  SELECT public.offer_public_accept(p_hash, p_variant, p_name, p_function, p_ip, p_ua, p_terms_sha256)
$$;
REVOKE ALL ON SCHEMA verejne FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA verejne FROM PUBLIC;

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
DO $$
DECLARE
  r text;
BEGIN
  FOREACH r IN ARRAY ARRAY['crm_app', 'crm_sync', 'neon_superuser'] LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
      EXECUTE format('GRANT USAGE ON SCHEMA public TO %I', r);
    END IF;
  END LOOP;
END;
$$;

-- Poistka: pri prihlásení ako crm_public sa app.user_id ignoruje (nikdy nie je prihlásený používateľ CRM)
CREATE OR REPLACE FUNCTION crm_current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT CASE WHEN session_user::text = 'crm_public' THEN NULL
              ELSE nullif(current_setting('app.user_id', true), '')::uuid END
$$;

-- migrate:down
CREATE OR REPLACE FUNCTION crm_current_user_id() RETURNS uuid
LANGUAGE sql STABLE AS $$
  SELECT nullif(current_setting('app.user_id', true), '')::uuid
$$;
GRANT USAGE ON SCHEMA public TO PUBLIC;
DROP SCHEMA IF EXISTS verejne CASCADE;


DROP FUNCTION IF EXISTS offer_public_accept(text, uuid, text, text, inet, text, text);
DROP FUNCTION IF EXISTS offer_public_pdf(text);
DROP FUNCTION IF EXISTS offer_public_view(text);
DROP FUNCTION IF EXISTS offer_public_mode(offer);
DROP FUNCTION IF EXISTS offer_unblock(uuid);
DROP FUNCTION IF EXISTS offer_acceptance_revoke(uuid, text);
DROP FUNCTION IF EXISTS offer_accept_manual(uuid, uuid, text, text, timestamptz, text, text, text);
DROP FUNCTION IF EXISTS offer_accept_record(uuid, uuid, text, text, timestamptz, text, text, inet, text, text, text, uuid);
DROP FUNCTION IF EXISTS offer_link_set(uuid, text);
DROP FUNCTION IF EXISTS offer_attach_pdf(uuid, text, text);
DROP FUNCTION IF EXISTS offer_document(uuid);
DROP FUNCTION IF EXISTS offer_document_internal(uuid);
DROP FUNCTION IF EXISTS offer_terms_sha(text);
DROP FUNCTION IF EXISTS offer_terms_text(uuid, uuid);
DROP FUNCTION IF EXISTS offer_doc_vars(uuid, jsonb);
DROP FUNCTION IF EXISTS offer_doc_variants(uuid);
DROP FUNCTION IF EXISTS offer_doc_valid_until(offer);
DROP FUNCTION IF EXISTS offer_terms_normalize(text);
DROP FUNCTION IF EXISTS offer_template_fill(text, jsonb, boolean, boolean);
DROP FUNCTION IF EXISTS offer_fmt_date(date, offer_language);
DROP FUNCTION IF EXISTS offer_fmt_num(numeric, integer, offer_language);

-- funkcie z 0036 / 0038 v pôvodnom znení
CREATE OR REPLACE FUNCTION offer_variant_after() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
BEGIN
  IF TG_OP = 'INSERT' OR (NEW.supply_from, NEW.supply_to, NEW.viwa_package) IS DISTINCT FROM (OLD.supply_from, OLD.supply_to, OLD.viwa_package) THEN
    PERFORM offer_basis_fill(NEW.id);
    -- položky rokov mimo nového obdobia sa odstránia
    DELETE FROM offer_item i WHERE i.variant_id = NEW.id AND i.year IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM offer_variant_months(NEW) m WHERE m.year = i.year);
    IF NEW.price_kind = 'cennik' THEN
      PERFORM offer_fill_price_list(NEW.id);
    END IF;
  END IF;
  RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION offer_reprice(p_offer uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o offer := offer_for_edit(p_offer);
  v uuid;
BEGIN
  IF o.status NOT IN ('koncept', 'pripravena', 'caka_na_schvalenie') THEN
    RAISE EXCEPTION 'Odoslanú ponuku prepočíta nová verzia.' USING ERRCODE = 'check_violation';
  END IF;
  PERFORM offer_back_to_draft(o.id);
  -- vlastné schválené výnimky verzie sa zrušia; prevzaté zo starej verzie sa iba odpoja (stará verzia si ich ponechá)
  UPDATE approval_request SET status = 'zrusena'
   WHERE status = 'schvalena' AND kind = 'vynimka_ceny' AND offer_id = o.id;
  DELETE FROM approval_price_item a
   USING offer_variant x, approval_request r
   WHERE x.id = a.variant_id AND x.offer_id = o.id AND r.id = a.approval_id AND r.offer_id IS DISTINCT FROM o.id;
  UPDATE offer SET priced_on = crm_today(),
                   seller_type = coalesce((SELECT u.seller_type FROM deal d JOIN app_user u ON u.id = d.owner_id WHERE d.id = o.deal_id), 'obchodnik')
   WHERE id = o.id;
  FOR v IN SELECT id FROM offer_variant WHERE offer_id = o.id LOOP
    PERFORM offer_basis_fill(v);
    IF (SELECT price_kind FROM offer_variant WHERE id = v) = 'cennik' THEN
      PERFORM offer_fill_price_list(v);
    END IF;
  END LOOP;
  PERFORM deal_event_offer(o, 'ponuka_prepocitana', jsonb_build_object('priced_on', crm_today()));
END;
$$;

CREATE OR REPLACE FUNCTION offer_accept_apply(p_offer uuid, p_variant uuid, p_accepted_at timestamptz DEFAULT now()) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  x       offer;
  v_stage uuid;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ponuka neexistuje.' USING ERRCODE = 'no_data_found';
  END IF;
  SELECT * INTO d FROM deal WHERE id = o.deal_id FOR UPDATE;
  IF o.status NOT IN ('odoslana', 'otvorena') THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba odoslaná ponuka.' USING ERRCODE = 'check_violation';
  END IF;
  IF p_accepted_at IS NULL OR p_accepted_at < o.sent_at OR p_accepted_at > now() + interval '5 minutes'
     OR o.valid_until IS NULL OR p_accepted_at >= o.valid_until THEN
    RAISE EXCEPTION 'Akceptovať sa dá iba v platnosti ponuky.' USING ERRCODE = 'check_violation';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE id = p_variant AND offer_id = o.id) THEN
    RAISE EXCEPTION 'Variant nepatrí ponuke.' USING ERRCODE = 'check_violation';
  END IF;
  IF d.closed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Obchod je uzavretý.' USING ERRCODE = 'check_violation';
  END IF;

  UPDATE offer SET status = 'akceptovana' WHERE id = o.id;
  UPDATE offer SET status = 'nahradena', replaced_by_id = o.id
   WHERE org_id = o.org_id AND number = o.number AND id <> o.id AND status IN ('odoslana', 'otvorena', 'zamietnuta');
  -- rozpracovaná nová verzia: späť do konceptu, čakajúce žiadosti zrušené, odoslať sa nedá (offer_check_internal)
  FOR x IN SELECT * FROM offer WHERE org_id = o.org_id AND number = o.number
                                 AND status IN ('koncept', 'caka_na_schvalenie', 'pripravena') LOOP
    UPDATE approval_request SET status = 'zrusena' WHERE status = 'caka' AND offer_id = x.id;
    UPDATE offer SET status = 'koncept' WHERE id = x.id AND status <> 'koncept';
    PERFORM notification_add_deal(ARRAY[d.owner_id, x.created_by], 'ponuka_zablokovana', d.id, NULL, NULL,
      format('Zákazník akceptoval ponuku %s – rozpracovanú verziu %s nemožno odoslať.', offer_display_number(o), offer_display_number(x)));
    PERFORM deal_event_offer(x, 'ponuka_zablokovana', jsonb_build_object('accepted_offer_id', o.id, 'accepted_version', o.version));
  END LOOP;

  SELECT s2.id INTO v_stage
    FROM pipeline_stage s JOIN pipeline_stage s2 ON s2.pipeline_id = d.pipeline_id AND s2.code = 'akceptacia'
   WHERE s.id = d.stage_id AND s.code IN ('prilezitost', 'cenova_ponuka', 'vyjednavanie');
  UPDATE deal SET accepted_variant_id = p_variant, stage_id = coalesce(v_stage, stage_id) WHERE id = d.id;
  PERFORM notification_add_deal(ARRAY[d.owner_id], 'ponuka_akceptovana', d.id, NULL, NULL,
                                'Zákazník akceptoval ponuku ' || offer_display_number(o));
  SELECT * INTO o FROM offer WHERE id = o.id;
  PERFORM deal_event_offer(o, 'ponuka_akceptovana', jsonb_build_object('variant_id', p_variant, 'accepted_at', p_accepted_at));
END;
$$;

CREATE OR REPLACE FUNCTION offer_check_internal(p_offer uuid) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public, pg_temp AS $$
DECLARE
  o       offer;
  d       deal;
  v       offer_variant;
  errors  jsonb := '[]';
  needs   jsonb := '[]';
  r       record;
  v_risk  jsonb;
  v_risk_ok boolean;
  v_acc   offer;
BEGIN
  SELECT * INTO o FROM offer WHERE id = p_offer;
  SELECT * INTO d FROM deal WHERE id = o.deal_id;
  IF NOT FOUND OR NOT (d.org_id = ANY (crm_user_orgs()) AND crm_deal_visible(d.company_id, d.person_id, d.owner_id)) THEN
    RETURN NULL;
  END IF;
  -- zákazník akceptoval inú verziu: rozpracovaná verzia sa nedá pripraviť ani odoslať (0038)
  SELECT * INTO v_acc FROM offer x WHERE x.org_id = o.org_id AND x.number = o.number AND x.id <> o.id AND x.status = 'akceptovana';
  IF FOUND THEN
    errors := errors || to_jsonb(format('Zákazník akceptoval ponuku %s – túto verziu nemožno odoslať.', offer_display_number(v_acc)));
  END IF;
  IF NOT EXISTS (SELECT 1 FROM offer_variant WHERE offer_id = o.id) THEN
    errors := errors || to_jsonb('Ponuka nemá variant.'::text);
  END IF;
  FOR v IN SELECT * FROM offer_variant WHERE offer_id = o.id ORDER BY sort_order LOOP
    FOR r IN SELECT x.year, x.missing, m.eic FROM offer_variant_values(v.id) x LEFT JOIN oom m ON m.id = x.oom_id
              WHERE x.missing IS NOT NULL ORDER BY x.year, m.eic LOOP
      errors := errors || to_jsonb(format('Variant %s (%s): %s – OOM %s, rok %s', chr(64 + v.sort_order), v.name, r.missing, r.eic, r.year));
    END LOOP;
    FOR r IN SELECT x.year, x.price_model, x.voltage_group,
                    min(CASE WHEN x.price_model = 'spot_minus_pct' THEN x.additive_pct
                             WHEN x.price_model IN ('spot_plus_eur', 'spot_minus_eur') THEN x.additive
                             ELSE least(x.price_vt, coalesce(x.price_nt, x.price_vt)) END) AS requested,
                    min(b.th) AS threshold, min(b.src) AS source, sum(x.volume_mwh) AS volume
               FROM offer_variant_values(v.id) x
               LEFT JOIN LATERAL (SELECT pv_unit_cost(x.kind, x.price_model, x.price_vt, ob.seller_type, ob.trader_price,
                                                      ob.portfolio_eur_mwh, ob.energopomoc_price, ob.min_additive, NULL) AS th,
                                         CASE WHEN x.price_model <> 'fix' THEN 'min_aditiv'
                                              WHEN ob.seller_type = 'manazer' THEN 'odhad_portfolia'
                                              ELSE 'cena_pre_obchodnika' END AS src
                                    FROM offer_year_basis ob WHERE ob.variant_id = v.id AND ob.year = x.year) b ON true
              WHERE x.below
              GROUP BY 1, 2, 3 ORDER BY 1, 3 LOOP
      needs := needs || jsonb_build_object('variant_id', v.id, 'variant', chr(64 + v.sort_order), 'year', r.year,
                                           'price_model', r.price_model, 'voltage_group', r.voltage_group,
                                           'requested_value', r.requested, 'threshold_value', r.threshold,
                                           'threshold_source', coalesce(r.source, 'cena_pre_obchodnika'), 'volume_mwh', r.volume);
    END LOOP;
  END LOOP;
  v_risk := CASE WHEN d.company_id IS NOT NULL THEN company_risk(d.company_id) END;
  -- schválenie rizika platí pre celý obchod 30 dní, kým sa údaje Finstatu nezhoršia (odpoveď 9)
  v_risk_ok := EXISTS (SELECT 1 FROM approval_request a
                        WHERE a.deal_id = d.id AND a.kind = 'rizikovy_zakaznik' AND a.status = 'schvalena'
                          AND (a.valid_until IS NULL OR a.valid_until > now())
                          AND NOT company_risk_worse(a.risk_snapshot, company_risk_snapshot(d.company_id)));
  RETURN jsonb_build_object('errors', errors, 'needs', needs,
                            'risk_needs_approval', coalesce((v_risk->>'needs_approval')::boolean, false) AND NOT v_risk_ok,
                            'risk', v_risk,
                            'fix_stale', o.priced_on < crm_today()
                                         AND EXISTS (SELECT 1 FROM offer_variant x WHERE x.offer_id = o.id AND x.price_kind IN ('fix', 'kombinacia')));
END;
$$;

DROP FUNCTION IF EXISTS offer_fill_viwa(uuid);
DELETE FROM offer_item WHERE slot IN ('viwa_ucet', 'viwa_kw')
   OR (price_model = 'cennik' AND variant_id IN (SELECT id FROM offer_variant WHERE price_kind = 'viwa'));

DELETE FROM notification WHERE kind = 'akceptacia_zrusena';
ALTER TABLE notification
  DROP CONSTRAINT notification_kind_check,
  ADD CONSTRAINT notification_kind_check CHECK (kind IN (
    'konci_4_mesiace', 'sprolongovana', 'neprolongovana', 'pod_hranicou', 'vynimka_nova', 'vynimka_rozhodnutie',
    'nocny_beh_chyba', 'maly_podnik', 'objem_xm',
    'dalsi_krok', 'schvalenie_nove', 'schvalenie_rozhodnutie', 'pridelenie_firmy',
    'ponuka_akceptovana', 'ponuka_zablokovana'));
ALTER TABLE deal_event DISABLE TRIGGER trg_guard;
DELETE FROM deal_event WHERE kind IN ('ponuka_otvorena', 'ponuka_odkaz', 'akceptacia_zrusena', 'ponuka_odblokovana');
ALTER TABLE deal_event ENABLE TRIGGER trg_guard;
ALTER TABLE deal_event
  DROP CONSTRAINT deal_event_kind_check,
  ADD CONSTRAINT deal_event_kind_check CHECK (kind IN (
    'zalozenie', 'stadium', 'vlastnik', 'znovuotvorenie', 'oom_pridane', 'oom_odobrane',
    'oom_zrusene', 'oom_nezrusene', 'kontakt_pridany', 'kontakt_odobrany', 'zakaznik_vlastnik',
    'ponuka_nova', 'ponuka_verzia', 'ponuka_prepocitana', 'ponuka_odoslana', 'ponuka_zamietnuta', 'ponuka_platnost',
    'schvalenie_ziadost', 'schvalenie_rozhodnutie', 'ponuka_akceptovana', 'ponuka_zablokovana'));

DROP TABLE IF EXISTS offer_acceptance;
DROP FUNCTION IF EXISTS offer_acceptance_guard();
DROP TABLE IF EXISTS offer_page_stat;
DROP INDEX IF EXISTS offer_link_hash_key;
ALTER TABLE offer
  DROP CONSTRAINT offer_pdf_check,
  DROP COLUMN blocked_by_offer_id,
  DROP COLUMN link_created_by,
  DROP COLUMN link_created_at,
  DROP COLUMN link_hash,
  DROP COLUMN pdf_generated_at,
  DROP COLUMN pdf_sha256,
  DROP COLUMN pdf_key,
  DROP COLUMN template_version_id,
  DROP COLUMN penalty_eur_mwh;
DROP TABLE IF EXISTS offer_asset;
DROP FUNCTION IF EXISTS offer_asset_guard();
DROP FUNCTION IF EXISTS offer_template_publish(uuid);
DROP FUNCTION IF EXISTS offer_template_for(uuid);
DROP TABLE IF EXISTS offer_template_version;
DROP FUNCTION IF EXISTS offer_template_guard();
DROP FUNCTION IF EXISTS offer_template_check(jsonb);
DROP FUNCTION IF EXISTS offer_template_variables();
DROP FUNCTION IF EXISTS offer_template_keys();
ALTER TABLE app_user DROP COLUMN job_title, DROP COLUMN phone;
