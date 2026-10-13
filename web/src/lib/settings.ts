// Typy a texty Nastavení (odpovede /api/settings/*).

import type { ModuleCode, Permission, Scope } from './api';

export type UserStatus = 'pozvany' | 'aktivny' | 'deaktivovany';

export type SettingsUser = {
  id: string;
  name: string;
  email: string;
  is_admin: boolean;
  status: UserStatus;
  last_login_at: string | null;
  invited_at: string;
  deactivated_at: string | null;
  team_id: string;
  team_code: string;
  team_name: string;
  all_orgs: boolean;
  is_external: boolean;
  orgs: { id: string; name: string }[];
};

export type SettingsTeam = {
  id: string;
  code: string;
  name: string;
  description: string | null;
  all_orgs: boolean;
  can_change_owner: boolean;
  is_external: boolean;
  archived_at: string | null;
  members: number;
  member_names: string | null;
  permissions: Partial<Record<ModuleCode, Permission>>;
};

export type Handover = {
  companies: number;
  contacts: number;
  open_deals: number;
  owners: { id: string; name: string; team_name: string }[];
};

export const USER_STATUS: Record<UserStatus, { label: string; tone: 'positive' | 'info' | 'neutral' }> = {
  aktivny: { label: 'Aktívny', tone: 'positive' },
  pozvany: { label: 'Pozvaný', tone: 'info' },
  deaktivovany: { label: 'Deaktivovaný', tone: 'neutral' },
};

export const MODULES: { code: ModuleCode; label: string }[] = [
  { code: 'zakaznici', label: 'Zákazníci' },
  { code: 'odberne_miesta', label: 'Odberné miesta' },
  { code: 'obchod', label: 'Obchod (dealy, ponuky)' },
  { code: 'zmluvy', label: 'Zmluvy a ceny' },
  { code: 'provizie', label: 'Provízie' },
  { code: 'servis', label: 'Servis' },
  { code: 'marketing', label: 'Marketing' },
];

export const SCOPES: { value: Scope; label: string }[] = [
  { value: 'vsetko', label: 'Všetko' },
  { value: 'iba_svoje', label: 'Iba svoje' },
  { value: 'nic', label: 'Nič' },
];

/** Prihlásenie vyplýva z e-mailu (návrh Nastavení, časť 5). */
export const isGoogleLogin = (email: string) => email.toLowerCase().endsWith('@greenlogy.com');

/** Text pozvánky na skopírovanie (Peter 12. 10.: pozvánky zatiaľ ručne). */
export function invitationText(name: string, email: string, url: string, environmentLabel: string): string {
  const env = environmentLabel === 'Test' ? ' (testovacie prostredie)' : '';
  const login = isGoogleLogin(email)
    ? `Prihláste sa svojím Google účtom ${email}.`
    : `Pri prihlásení zadajte e-mail ${email} – príde vám jednorazový kód.`;
  return `Dobrý deň, ${name},\n\nmáte prístup do Greenlogy CRM${env}:\n${url}\n\n${login}\n\nGreenlogy a.s.`;
}

// --- Spoločnosť (dizajn 11) ---

export type SettingsOrg = {
  id: string;
  code: string;
  country: 'SK' | 'CZ' | 'HR';
  currency: string;
  status: 'aktivna' | 'pripravuje_sa';
  is_default: boolean;
  timezone: string;
  legal_name: string;
  reg_no: string | null;
  tax_no: string | null;
  vat_no: string | null;
  address: string | null;
  registry_entry: string | null;
  statutory: string | null;
  support_phone: string | null;
  email: string | null;
  web: string | null;
  regulator_license: string | null;
  logo_updated_at: string | null;
  oom_switch_accept_days: number;
  oom_switch_confirm_days: number;
};

export type BankPurpose = 'faktury' | 'zalohy' | 'vykup';

export type OrgDetail = {
  accounts: {
    id: string;
    iban: string;
    bic: string | null;
    bank_name: string | null;
    purposes: BankPurpose[];
    is_primary: boolean;
    archived_at: string | null;
  }[];
  hours: { weekday: number; work_from: string; work_to: string }[];
  days_off: { id: string; date: string; kind: 'statny_sviatok' | 'firemne_volno'; name: string }[];
  calendar_from: string | null;
  calendar_to: string | null;
};

export const COUNTRY_LABEL = { SK: 'Slovensko', CZ: 'Česko', HR: 'Chorvátsko' } as const;
export const REG_NO_LABEL = { SK: 'IČO', CZ: 'IČO', HR: 'OIB' } as const;
export const REGULATOR = { SK: 'ÚRSO', CZ: 'ERÚ', HR: 'HERA' } as const;
export const PURPOSE_LABEL: Record<BankPurpose, string> = { faktury: 'Faktúry', zalohy: 'Zálohy', vykup: 'Výkup' };
export const WEEKDAYS = ['Pondelok', 'Utorok', 'Streda', 'Štvrtok', 'Piatok', 'Sobota', 'Nedeľa'];

/** IBAN po štvoriciach: SK3112000000198742637541 → SK31 1200 0000 1987 4263 7541 */
export const formatIban = (iban: string) => iban.replace(/(.{4})/g, '$1 ').trim();

// --- Číselníky a vlastné polia (dizajn 14) ---

export type LookupValue = {
  id: string;
  code: string;
  label: string;
  org_id: string | null;
  org_name: string | null;
  sort_order: number;
  is_system: boolean;
  hidden_at: string | null;
  hubspot_value: string | null;
  parent_code: string | null;
  reg_no: string | null;
};
export type LookupList = { code: string; name: string; used_on: string | null; parent_list: string | null; values: LookupValue[] };

export type Entity = 'firma' | 'osoba' | 'oom' | 'deal' | 'zmluva' | 'ponuka';
export type FieldType = 'text' | 'dlhy_text' | 'cislo' | 'suma' | 'datum' | 'vyber' | 'vyber_viac' | 'ano_nie' | 'odkaz';
export type EditAccess = 'vsetky_timy' | 'vybrane_timy' | 'iba_admin';

export type CustomField = {
  id: string;
  entity: Entity;
  key: string;
  label: string;
  field_type: FieldType;
  ref_entity: Entity | null;
  section_id: string | null;
  section_name: string | null;
  sort_order: number;
  is_required: boolean;
  show_in_list: boolean;
  filterable: boolean;
  edit_access: EditAccess;
  org_id: string | null;
  org_name: string | null;
  archived_at: string | null;
  teams: { id: string; name: string }[];
  options: { id: string; label: string; hidden_at: string | null }[];
};
export type FieldSection = { id: string; name: string; sort_order: number };

export const ENTITIES: { value: Entity; label: string }[] = [
  { value: 'firma', label: 'Firma' },
  { value: 'osoba', label: 'Osoba' },
  { value: 'oom', label: 'Odberné miesto' },
  { value: 'deal', label: 'Deal' },
  { value: 'zmluva', label: 'Zmluva' },
  { value: 'ponuka', label: 'Ponuka' },
];

export const FIELD_TYPES: { value: FieldType; label: string }[] = [
  { value: 'text', label: 'Text' },
  { value: 'dlhy_text', label: 'Dlhý text' },
  { value: 'cislo', label: 'Číslo' },
  { value: 'suma', label: 'Suma' },
  { value: 'datum', label: 'Dátum' },
  { value: 'vyber', label: 'Výber jednej hodnoty' },
  { value: 'vyber_viac', label: 'Výber viacerých hodnôt' },
  { value: 'ano_nie', label: 'Áno/nie' },
  { value: 'odkaz', label: 'Odkaz na záznam' },
];

/** Polia jadra (zámok): nesie ich logika CRM, menia sa iba v kóde. */
export const CORE_FIELDS: Record<Entity, string[]> = {
  firma: ['Názov', 'IČO / OIB', 'Krajina', 'DIČ', 'IČ DPH', 'Sídlo', 'Označenie (zákazník, partner, dodávateľ)', 'Vlastník', 'Stav'],
  osoba: ['Meno', 'Priezvisko', 'E-mail', 'Telefón', 'Mobil', 'Domácnosť', 'Vlastník', 'Stav', 'Nechce marketing'],
  oom: ['EIC', 'Typ', 'Stav', 'Adresa', 'Distribúcia', 'Plánovaná spotreba'],
  deal: ['Názov', 'Pipeline', 'Stage', 'Vlastník', 'Očakávané uzavretie'],
  zmluva: ['Číslo', 'Stav', 'Platnosť od – do', 'Podpísaná'],
  ponuka: ['Verzia', 'Stav', 'Platná do', 'Suma'],
};

export const EDIT_ACCESS_LABEL: Record<EditAccess, string> = {
  vsetky_timy: 'Všetky tímy',
  vybrane_timy: 'Vybrané tímy',
  iba_admin: 'Iba admin',
};

// --- Pipelines a stage (dizajn 15) ---

export type DealKind = 'b2c_dodavka' | 'b2b_dodavka' | 'b2b_vykup' | 'green_solar' | 'green_viwa' | 'efet';
export type Outcome = 'otvoreny' | 'vyhrany' | 'prehrany';

export type Stage = {
  id: string;
  name: string;
  sort_order: number;
  probability: string | number | null;
  outcome: Outcome;
  archived_at: string | null;
  deals: number;
  required: { core_field: string | null; custom_field_id: string | null; label: string | null }[];
};
export type Pipeline = {
  id: string;
  name: string;
  kind: DealKind;
  org_id: string | null;
  org_name: string | null;
  sort_order: number;
  archived_at: string | null;
  deals: number;
  stages: Stage[];
};

export const DEAL_KINDS: { value: DealKind; label: string }[] = [
  { value: 'b2c_dodavka', label: 'B2C dodávka' },
  { value: 'b2b_dodavka', label: 'B2B dodávka' },
  { value: 'b2b_vykup', label: 'B2B výkup' },
  { value: 'green_solar', label: 'Green Solar' },
  { value: 'green_viwa', label: 'Green VIWA' },
  { value: 'efet', label: 'EFET' },
];
export const OUTCOMES: { value: Outcome; label: string }[] = [
  { value: 'otvoreny', label: 'Otvorený' },
  { value: 'vyhrany', label: 'Vyhraný' },
  { value: 'prehrany', label: 'Prehraný' },
];
export const DEAL_CORE_FIELD_LABEL: Record<string, string> = {
  expected_close: 'Očakávané uzavretie',
  lost_reason: 'Dôvod prehry',
  source: 'Zdroj',
  campaign: 'Kampaň',
  closed_at: 'Dátum uzavretia',
};

// --- Audit (dizajn 16) ---

export type AuditRow = {
  id: number;
  changed_at: string;
  table_name: string;
  record_id: string;
  action: 'insert' | 'update' | 'delete';
  source: 'aplikacia' | 'system' | 'synchronizacia';
  diff: Record<string, unknown>;
  record_label: string | null;
  user_name: string | null;
};
export type AuditPage = { page: number; pageSize: number; total: number; items: AuditRow[]; users: { id: string; name: string }[] };

export const TABLE_LABEL: Record<string, string> = {
  company: 'Firma',
  contact: 'Osoba',
  company_contact: 'Osoba vo firme',
  oom: 'Odberné miesto',
  deal: 'Deal',
  contract: 'Zmluva',
  offer: 'Ponuka',
  org: 'Nastavenia · spoločnosť',
  org_bank_account: 'Nastavenia · bankový účet',
  team: 'Nastavenia · tím',
  team_permission: 'Nastavenia · práva tímu',
  app_user: 'Nastavenia · používateľ',
  app_user_org: 'Nastavenia · prístup k spoločnosti',
  org_work_hours: 'Nastavenia · pracovný čas',
  org_day_off: 'Nastavenia · voľný deň',
  lookup_value: 'Nastavenia · číselník',
  custom_field: 'Nastavenia · vlastné pole',
  custom_field_option: 'Nastavenia · hodnota výberu',
  custom_field_team: 'Nastavenia · tím poľa',
  custom_field_section: 'Nastavenia · sekcia',
  pipeline: 'Nastavenia · pipeline',
  pipeline_stage: 'Nastavenia · stage',
  pipeline_stage_required_field: 'Nastavenia · povinné pole',
};

/** Slovenské názvy stĺpcov v audite; ostatné sa zobrazia technickým názvom. */
export const COLUMN_LABEL: Record<string, string> = {
  name: 'Názov',
  legal_name: 'Obchodné meno',
  label: 'Názov',
  email: 'E-mail',
  phone: 'Telefón',
  mobile: 'Mobil',
  first_name: 'Meno',
  last_name: 'Priezvisko',
  owner_id: 'Vlastník',
  status: 'Stav',
  is_admin: 'Admin',
  team_id: 'Tím',
  view_scope: 'Vidieť',
  edit_scope: 'Upravovať',
  can_archive: 'Archivovať',
  can_export: 'Exportovať',
  can_import: 'Importovať',
  can_edit_active_oom: 'Upravovať Aktívne OOM',
  all_orgs: 'Všetky spoločnosti',
  hidden_at: 'Skryté',
  archived_at: 'Archivované',
  work_from: 'Od',
  work_to: 'Do',
  purposes: 'Účel',
  is_primary: 'Hlavný',
  probability: 'Pravdepodobnosť',
  outcome: 'Typ',
  sort_order: 'Poradie',
  marketing_opt_out_at: 'Nechce marketing',
  ico: 'IČO',
  address: 'Adresa',
};
