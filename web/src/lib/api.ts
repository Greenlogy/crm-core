// Volania API jadra (čítanie aj zápis) a typy odpovedí. Číselné hodnoty z databázy prichádzajú ako text.

import { useCallback, useEffect, useState } from 'react';

export type Num = string | number | null;

export type CustomerListItem = {
  kind: 'company' | 'person';
  id: string;
  name: string;
  ico: string | null;
  customer_type: 'B2B' | 'B2C';
  status: string | null;
  status_source: string | null;
  is_former_customer: boolean;
  is_producer: boolean;
  segment_label: string;
  owner_id: string | null;
  owner_name: string | null;
  active_oom_count: number;
  annual_mwh: Num;
  last_activity_at: string | null;
  archived: boolean;
  city: string | null;
  company_count: number;
  is_statutory: boolean;
  future_from: string | null;
  org_id: string;
  org_name: string;
  custom: Record<string, unknown>;
};

export type CustomerList = {
  page: number;
  pageSize: number;
  total: number;
  counts: { visible: number; archived: number; all: number; byStatus: Record<string, number> };
  items: CustomerListItem[];
};

export type Owner = { id: string; name: string };
export type MenuCounts = { leads: number; customers: number };

export type ContactListItem = {
  id: string;
  name: string;
  title: string | null;
  email: string | null;
  phone: string | null;
  mobile: string | null;
  is_household: boolean;
  status: string | null;
  is_producer: boolean;
  segment_label: string;
  marketing_allowed: boolean;
  marketing_opt_out_at: string | null;
  custom: Record<string, unknown>;
  companies: { id: string; name: string; roles: string[]; role_labels: string[]; is_main_contact: boolean }[];
};

export type ContactList = { page: number; pageSize: number; total: number; items: ContactListItem[] };

/** OOM zákazníka (väzba): stav podľa obdobia väzby; eic a údaje sú null, ak OOM už patrí inému a používateľ ho nevidí. */
export type OomRow = {
  id: string;
  link_id?: string;
  eic: string | null;
  name?: string | null;
  type: string | null;
  status: string;
  valid_from?: string;
  valid_to?: string | null;
  end_reason?: string | null;
  plan_kind?: string | null;
  plan_date?: string | null;
  visible?: boolean;
  address_street: string | null;
  address_city: string | null;
  address_zip: string | null;
  planned_consumption_vt_mwh: Num;
  planned_consumption_nt_mwh: Num;
  planned_feed_in_mwh: Num;
  source_power_kw: Num;
  supply_from: string | null;
  supply_to: string | null;
};

export type DealRow = {
  id: string;
  name: string;
  pipeline: string;
  stage: string;
  is_closed: boolean;
  is_won: boolean;
  closed_at: string | null;
  created_at?: string;
  hubspot_id?: string | null;
  owner_name?: string | null;
  oom_count?: number;
  contract_id: string | null;
  contract_number?: string | null;
};

export type ContractRow = {
  id: string;
  number: string | null;
  status: string;
  confirmed: boolean;
  valid_from: string | null;
  valid_to: string | null;
  deal_name: string | null;
  oom_count: number;
  price_count: number;
};

export type PriceRow = {
  id: string;
  contract_id?: string;
  contract_number?: string | null;
  oom_id?: string;
  eic?: string;
  product: string | null;
  direction: string;
  price_vt_eur_mwh: Num;
  price_nt_eur_mwh: Num;
  additive_eur_mwh: Num;
  imbalance_price_eur_mwh: Num;
  additive_coefficient_pct: Num;
  fee_oom_eur_month: Num;
  fee_zem_eur_month: Num;
  fee_vbattery_eur_month: Num;
  fee_rk_eur_kw_month: Num;
  vbattery_program: string | null;
  valid_from: string | null;
  valid_to: string | null;
  status: string;
};

export type StatusChange = { status: string; source: string | null; changed_at: string };

type CardBase = {
  id: string;
  name: string;
  hubspot_id: string | null;
  address: string | null;
  city: string | null;
  owner_name: string | null;
  owner_team: string | null;
  status: string | null;
  status_source: string | null;
  status_changed_at: string | null;
  is_former_customer: boolean;
  is_producer: boolean;
  segment_label: string;
  archived: boolean;
  kpi: {
    oom_count: number;
    oom_active: number;
    planned_consumption_mwh: Num;
    consumption_active: number;
    planned_feed_in_mwh: Num;
    source_power_kw: Num;
    production_count: number;
    active_contracts: number;
  };
  ooms: OomRow[];
  deals: DealRow[];
  contracts: (ContractRow & { pipeline: string | null })[];
  history: StatusChange[];
  // úpravy (modul Zákazníci F1)
  owner_id: string | null;
  org_id: string;
  org_name: string;
  can_edit: boolean;
  custom: Record<string, unknown>;
  timeline: import('../components/customer-f2').TimelineItem[];
  custom_refs: import('../components/custom-fields').RefLabel[];
};

export type CompanyCard = CardBase & {
  country: 'SK' | 'CZ' | 'HR';
  legal_form: string | null;
  kind: 'company';
  ico: string | null;
  dic: string | null;
  ic_dph: string | null;
  registry_entry: string | null;
  nace: string | null;
  statutory: string | null;
  bank_account: string | null;
  payment_rating: string | null;
  debts_note: string | null;
  insolvency_note: string | null;
  finstat_url: string | null;
  is_customer: boolean;
  is_partner: boolean;
  is_supplier: boolean;
  contacts: {
    id: string;
    name: string;
    title: string | null;
    email: string | null;
    phone: string | null;
    mobile: string | null;
    position: string | null;
    is_main_contact: boolean;
    roles: string[];
    role_labels: string[];
    is_household: boolean;
    marketing_opt_out_at: string | null;
    other_companies: number;
  }[];
};

export type PersonCard = CardBase & {
  kind: 'person';
  first_name: string;
  last_name: string;
  title: string | null;
  email: string | null;
  phone: string | null;
  mobile: string | null;
  position: string | null;
  source: string | null;
  is_household: boolean;
  marketing_allowed: boolean;
  marketing_opt_out_at: string | null;
  marketing_opt_out_source: string | null;
  companies: {
    id: string;
    name: string;
    ico: string | null;
    is_main_contact: boolean;
    roles: string[];
    role_labels: string[];
    can_edit_company: boolean;
    is_customer: boolean;
    status: string | null;
    segment_label: string;
    archived: boolean;
  }[];
};

export type OomLink = {
  id: string;
  company_id: string | null;
  person_id: string | null;
  customer_kind: 'company' | 'person';
  customer_name: string | null;
  valid_from: string;
  valid_to: string | null;
  status: string;
  end_reason: string | null;
};

export type OomDevice = {
  id: string;
  device_type: string;
  brand: string | null;
  model: string | null;
  power_kw: Num;
  capacity_kwh: Num;
  count: number;
};

export type AuditEvent = {
  id: string;
  table_name: 'oom' | 'oom_customer' | 'oom_device' | 'oom_contact' | 'oom_planned_change';
  record_id: string;
  action: 'insert' | 'update' | 'delete';
  diff: Record<string, unknown>;
  changed_at: string;
  source: string;
  user_name: string | null;
  import_file: string | null;
};

/** Plánovaná zmena OOM (0016): prepis, odchod alebo zrušenie k budúcemu dátumu. */
export type OomPlan = {
  id: string;
  kind: 'prepis' | 'odchod' | 'zrusenie';
  effective_date: string;
  status: 'planovana' | 'vykonana' | 'zrusena' | 'zlyhala';
  error: string | null;
  company_id: string | null;
  person_id: string | null;
  customer_name: string | null;
  created_by_name: string | null;
  created_at: string;
  executed_at: string | null;
  cancelled_at: string | null;
  cancelled_by_name: string | null;
};

/** Karta OOM (api/src/queries/oom.ts): riadok oom + údaje z oom_v + popisy číselníkov + práva. */
export type OomCard = {
  id: string;
  eic: string;
  name: string | null;
  type: string;
  status: string;
  company_id: string | null;
  person_id: string | null;
  customer_kind: 'company' | 'person';
  customer_type: 'B2B' | 'B2C';
  customer_name: string | null;
  owner_id: string | null;
  owner_name: string | null;
  org_id: string;
  org_name: string;
  hubspot_id: string | null;
  address_street: string | null;
  address_number_supisne: string | null;
  address_number_orientacne: string | null;
  address_city: string | null;
  address_zip: string | null;
  pds: string | null;
  pds_label: string | null;
  pds_point_id: string | null;
  pds_tariff: string | null;
  pds_tariff_label: string | null;
  voltage_level: string | null;
  metering_type: string | null;
  metering_type_label: string | null;
  phases: number | null;
  breaker_a: Num;
  reserved_capacity_kw: Num;
  max_reserved_capacity_kw: Num;
  capacity_reservation_method: string | null;
  price_regulation: boolean | null;
  excise_tax: string | null;
  billing_period: string | null;
  billing_period_label: string | null;
  advance_payment_method: string | null;
  advance_payment_method_label: string | null;
  advance_payment_pct: Num;
  advance_payment_eur: Num;
  planned_consumption_vt_mwh: Num;
  planned_consumption_nt_mwh: Num;
  planned_feed_in_mwh: Num;
  planned_mwh: Num;
  source_kind: string | null;
  source_category: string | null;
  source_power_kw: Num;
  inverter_power_kw: Num;
  panels_power_kw: Num;
  feed_in_contract_type: string | null;
  feed_in_contract_type_label: string | null;
  supply_from: string | null;
  supply_to: string | null;
  previous_supplier: string | null;
  previous_supplier_label: string | null;
  switch_notice_required: boolean;
  switch_notice_sent_on: string | null;
  switch_notice_accepted_on: string | null;
  switch_confirmed_on: string | null;
  switch_stuck: boolean;
  oom_switch_accept_days: number;
  oom_switch_confirm_days: number;
  active_missing: string[] | null;
  transferred_from_name: string | null;
  transferred_on: string | null;
  custom: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  can_edit: boolean;
  can_edit_active: boolean;
  plan_kind: OomPlan['kind'] | null;
  plan_date: string | null;
  plan_id: string | null;
  plan_failed: boolean;
  plans: OomPlan[];
  custom_refs: { id: string; label: string | null; entity: string | null }[];
  links: OomLink[];
  devices: OomDevice[];
  contacts: {
    id: string;
    name: string;
    email: string | null;
    phone: string | null;
    mobile: string | null;
    oom_contact_id: string | null;
    sources: string[];
    roles: string[];
    role_labels: string[];
  }[];
  deals: DealRow[];
  prices: PriceRow[];
  timeline: AuditEvent[];
  names: Record<string, string>;
};

export type OomListItem = {
  id: string;
  eic: string;
  name: string | null;
  address_street: string | null;
  address_number_supisne: string | null;
  address_number_orientacne: string | null;
  address_city: string | null;
  address_zip: string | null;
  type: string;
  status: string;
  company_id: string | null;
  person_id: string | null;
  customer_type: 'B2B' | 'B2C';
  customer_name: string | null;
  owner_id: string | null;
  owner_name: string | null;
  org_id: string;
  org_name: string;
  pds: string | null;
  pds_label: string | null;
  pds_tariff_label: string | null;
  planned_mwh: Num;
  supply_from: string | null;
  supply_to: string | null;
  switch_stuck: boolean;
  active_missing: string[] | null;
  transferred_from_name: string | null;
  transferred_on: string | null;
  plan_kind: OomPlan['kind'] | null;
  plan_date: string | null;
  plan_failed: boolean;
  custom: Record<string, unknown>;
  customer_ico: string | null;
  voltage_level: string | null;
};

export type OomList = {
  page: number;
  pageSize: number;
  total: number;
  counts: { all: number; pripravovane: number; aktivne: number; odidene: number; zrusene: number; prepisane: number; zasekol: number; zlyhal: number };
  items: OomListItem[];
};

export type OomFilters = { pds: { code: string; label: string }[]; owners: { id: string; name: string }[] };

export type ContractCard = {
  id: string;
  number: string | null;
  status: string;
  confirmed: boolean;
  auto_prolong: boolean;
  valid_from: string | null;
  valid_to: string | null;
  signed_at: string | null;
  payment_terms_days: number | null;
  consumption_tolerance: Num;
  advance_payment_pct: Num;
  segment: string | null;
  company_id: string | null;
  person_id: string | null;
  customer_kind: 'company' | 'person';
  customer_name: string;
  deal_name: string | null;
  deal_hubspot_id: string | null;
  owner_name: string | null;
  pipeline: string | null;
  stage: string | null;
  ooms: Pick<
    OomRow,
    'id' | 'eic' | 'type' | 'status' | 'address_street' | 'address_city' | 'planned_consumption_vt_mwh' | 'planned_consumption_nt_mwh' | 'planned_feed_in_mwh'
  >[];
  prices: PriceRow[];
  purchases: {
    id: string;
    product_code: string;
    delivery_year: number;
    priced_on: string;
    price_eur_mwh: Num;
    cockpit_ref: string | null;
  }[];
};

export class ApiError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

export async function get<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(path, { signal, headers: { Accept: 'application/json' } });
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok) throw new ApiError(res.status, body.error ?? `Chyba ${res.status}`);
  return body as T;
}

/** Zápis (POST, PATCH, DELETE) ako JSON; chyba nesie slovenskú správu z API. */
export async function send<T = unknown>(method: 'POST' | 'PATCH' | 'DELETE', path: string, data?: unknown): Promise<T> {
  const res = await fetch(path, {
    method,
    headers: { Accept: 'application/json', ...(data === undefined ? {} : { 'Content-Type': 'application/json' }) },
    body: data === undefined ? undefined : JSON.stringify(data),
  });
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok) throw new ApiError(res.status, body.error ?? `Chyba ${res.status}`);
  return body as T;
}

export type Loadable<T> = { data?: T; error?: ApiError; loading: boolean; reload: () => void };

// Načíta dáta z API pri zmene cesty; starú požiadavku zruší. reload() načíta znova (po uložení).
export function useApi<T>(path: string): Loadable<T> {
  const [version, setVersion] = useState(0);
  const reload = useCallback(() => setVersion((v) => v + 1), []);
  const [state, setState] = useState<Omit<Loadable<T>, 'reload'>>({ loading: true });
  useEffect(() => {
    const ctrl = new AbortController();
    setState((s) => ({ data: s.data, loading: true }));
    get<T>(path, ctrl.signal)
      .then((data) => setState({ data, loading: false }))
      .catch((err: unknown) => {
        if (ctrl.signal.aborted) return;
        setState({ error: err instanceof ApiError ? err : new ApiError(0, 'API nie je dostupné.'), loading: false });
      });
    return () => ctrl.abort();
  }, [path, version]);
  return { ...state, reload };
}

// --- Prihlásený používateľ ---

export type Scope = 'nic' | 'iba_svoje' | 'vsetko';
export type ModuleCode = 'zakaznici' | 'odberne_miesta' | 'obchod' | 'zmluvy' | 'provizie' | 'servis' | 'marketing';
/** import a edit_active (upravovať Aktívne OOM) majú zmysel iba pri module odberne_miesta (0015). */
export type Permission = { view: Scope; edit: Scope; archive: boolean; export: boolean; import: boolean; edit_active: boolean };
export type OrgRef = { id: string; name: string; country: string; currency: string; status: string; default: boolean };

export type Me = {
  id: string;
  name: string;
  email: string;
  is_admin: boolean;
  team_code: string;
  team_name: string;
  can_change_owner: boolean;
  environment: string;
  orgs: OrgRef[];
  permissions: Partial<Record<ModuleCode, Permission>>;
};

// Modul 3 Produkty a cenníky (F1, iba čítanie)
export type TariffRef = { scope: string; label: string };

export type PriceListRow = {
  id: string;
  code: string;
  name: string;
  segment: string;
  description: string | null;
  current_version_id: string | null;
  current_version_name: string | null;
  current_valid_from: string | null;
  current_valid_to: string | null;
  future_version_id: string | null;
  future_version_name: string | null;
  future_valid_from: string | null;
  draft_version_id: string | null;
  draft_version_name: string | null;
  draft_valid_from: string | null;
  products: string[];
};

export type PriceListVersion = {
  id: string;
  name: string;
  valid_from: string;
  valid_to: string | null;
  status: 'navrh' | 'schvalena' | 'nahradena';
  state: 'navrh' | 'buduca' | 'platna' | 'ukoncena';
  copied_from_id: string | null;
  note: string | null;
  approved_at: string | null;
  approved_by_name: string | null;
  item_count: number | string;
};

export type PriceListItem = {
  id: string;
  product_id: string;
  product_code: string;
  product_name: string;
  category: string;
  tariff_type: string;
  product_status: string;
  vat_rate: Num;
  price_vt_eur_mwh: Num;
  price_vt_with_vat: Num;
  price_nt_eur_mwh: Num;
  price_nt_with_vat: Num;
  fee_oom_eur_month: Num;
  fee_oom_with_vat: Num;
  fee_program_eur_month: Num;
  fee_program_with_vat: Num;
  fee_kw_eur_month: Num;
  fee_kw_with_vat: Num;
  tariffs: TariffRef[];
};

export type PriceListDetail = {
  id: string;
  code: string;
  name: string;
  segment: string;
  description: string | null;
  versions: PriceListVersion[];
  selected_version_id: string | null;
  items: PriceListItem[];
};

export type ProductRow = {
  id: string;
  code: string;
  name: string;
  category: string;
  segment: string;
  vat_rate: Num;
  tariff_type: string;
  price_models: string[];
  price_regulation: boolean | null;
  status: string;
  tariffs: TariffRef[];
};

export type ProgramRow = {
  product_id: string;
  code: string;
  name: string;
  category: 'vbattery' | 'viwa';
  status: string;
  price_list_name: string | null;
  version_name: string | null;
  valid_from: string | null;
  vat_rate: Num;
  fee_program_eur_month: Num;
  fee_program_with_vat: Num;
  fee_kw_eur_month: Num;
  fee_kw_with_vat: Num;
  greencar: boolean | null;
  greencar_kwh_per_voucher: number | null;
  greencar_voucher_eur: Num;
  greenshare: boolean | null;
  greenshare_fee_pct: Num;
  viwa_conversion_factor: Num;
  viwa_activation_bonus: number | null;
  viwa_credit_expiry_months: number | null;
};
