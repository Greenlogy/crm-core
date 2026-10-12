-- 0012_activity_note.sql – poznámka na časovej osi firmy a osoby (zadanie Zákazníci čl. 14, F2)
--
-- Aktivita mala iba náhľad textu (body_preview, z HubSpotu). Poznámka z CRM potrebuje celý text.
-- Poznámka = aktivita typu 'poznamka' so zdrojom 'crm', autor v user_id, čas v occurred_at.
-- Poznámka sa nemení ani nemaže (audit); oprava = nová poznámka.

-- migrate:up

ALTER TABLE activity ADD COLUMN body text;
COMMENT ON COLUMN activity.body IS 'celý text (poznámka z CRM); body_preview je náhľad z HubSpotu';
ALTER TABLE activity ADD CONSTRAINT activity_note_check
  CHECK (type <> 'poznamka' OR source IS DISTINCT FROM 'crm'
         OR (btrim(body) <> '' AND user_id IS NOT NULL AND num_nonnulls(company_id, contact_id) >= 1));

-- migrate:down

ALTER TABLE activity DROP CONSTRAINT IF EXISTS activity_note_check;
ALTER TABLE activity DROP COLUMN IF EXISTS body;
