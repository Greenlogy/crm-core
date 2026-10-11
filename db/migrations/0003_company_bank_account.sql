-- 0003_company_bank_account.sql – bankový účet firmy
--
-- HubSpot: bank_account (Firemné informácie). Text, napr. IBAN; formát sa nekontroluje,
-- lebo HubSpot ho nevynucoval. Doplnené na základe kontroly prototypu (11. 10. 2026).

-- migrate:up

ALTER TABLE company ADD COLUMN bank_account text;
COMMENT ON COLUMN company.bank_account IS 'bankový účet firmy (zvyčajne IBAN), HubSpot bank_account';

-- migrate:down

ALTER TABLE company DROP COLUMN IF EXISTS bank_account;
