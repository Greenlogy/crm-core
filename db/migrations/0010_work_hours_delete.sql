-- 0010_work_hours_delete.sql – admin smie odobrať pracovný deň (deň bez riadku = voľno)
--
-- 0006 povolila v Nastaveniach mazať iba prístup k spoločnosti, voľný deň a logo. Pracovný čas
-- sa upravuje po dňoch: keď sa deň zmení na voľný, jeho riadok v org_work_hours sa zmaže.
-- Právo DELETE pre rolu crm_app pridáva api/db/app-role.sql (spustiť znova: create-app-role.sh --prava).

-- migrate:up

CREATE POLICY settings_delete ON org_work_hours FOR DELETE USING ((SELECT crm_settings_writer()));

-- migrate:down

DROP POLICY IF EXISTS settings_delete ON org_work_hours;
