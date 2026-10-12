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
  companies: { id: string; name: string; roles: string[]; is_main_contact: boolean }[];
};

export type ContactList = { page: number; pageSize: number; total: number; items: ContactListItem[] };

export type OomRow = {
  id: string;
  eic: string;
  type: string;
  status: string;
  segment: string | null;
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
    is_customer: boolean;
    status: string | null;
    segment_label: string;
    archived: boolean;
  }[];
};

export type OomCard = OomRow & {
  company_id: string | null;
  person_id: string | null;
  customer_kind: 'company' | 'person';
  customer_name: string;
  hubspot_id: string | null;
  address_number_supisne: string | null;
  address_number_orientacne: string | null;
  pds: string | null;
  pds_point_id: string | null;
  pds_tariff: string | null;
  voltage_level: string | null;
  metering_type: string | null;
  phases: number | null;
  breaker_a: Num;
  reserved_capacity_kw: Num;
  max_reserved_capacity_kw: Num;
  capacity_reservation_method: string | null;
  price_regulation: string | null;
  excise_tax: string | null;
  billing_period: string | null;
  advance_payment_method: string | null;
  advance_payment_pct: Num;
  source_kind: string | null;
  source_type: string | null;
  feed_in_contract_type: string | null;
  inverter_power_kw: Num;
  panels_power_kw: Num;
  previous_supplier_notice: string | null;
  previous_supplier_notice_accepted_at: string | null;
  deals: DealRow[];
  prices: PriceRow[];
  contacts: { id: string; name: string; email: string | null; phone: string | null; mobile: string | null }[];
};

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
export type Permission = { view: Scope; edit: Scope; archive: boolean; export: boolean };
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
