// Volania API jadra (iba GET) a typy odpovedí. Číselné hodnoty z databázy prichádzajú ako text.

import { useEffect, useState } from 'react';

export type Num = string | number | null;

export type CustomerListItem = {
  kind: 'company' | 'person';
  id: string;
  name: string;
  ico: string | null;
  segment: string | null;
  hubspot_id: string | null;
  owner_name: string | null;
  oom_count: number;
  oom_active: number;
  planned_consumption_mwh: Num;
  planned_feed_in_mwh: Num;
  active_contracts: number;
};

export type CustomerList = { page: number; pageSize: number; total: number; items: CustomerListItem[] };

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

export type CustomerCard = {
  kind: 'company' | 'person';
  id: string;
  name: string;
  hubspot_id: string | null;
  segment: string | null;
  lifecycle_stage: string | null;
  address: string | null;
  owner_name: string | null;
  owner_team: string | null;
  // firma
  ico?: string | null;
  dic?: string | null;
  ic_dph?: string | null;
  registry_entry?: string | null;
  nace?: string | null;
  statutory?: string | null;
  bank_account?: string | null;
  payment_rating?: string | null;
  debts_note?: string | null;
  insolvency_note?: string | null;
  finstat_url?: string | null;
  // domácnosť
  title?: string | null;
  email?: string | null;
  phone?: string | null;
  mobile?: string | null;
  position?: string | null;
  source?: string | null;
  kpi: {
    oom_count: number;
    oom_active: number;
    planned_consumption_mwh: Num;
    planned_feed_in_mwh: Num;
    source_power_kw: Num;
    active_contracts: number;
  };
  contacts: {
    id: string;
    name: string;
    title: string | null;
    email: string | null;
    phone: string | null;
    mobile: string | null;
    position: string | null;
    is_primary: boolean;
  }[];
  companies: { id: string; name: string; ico: string | null; is_primary: boolean }[];
  ooms: OomRow[];
  deals: DealRow[];
  contracts: ContractRow[];
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

async function get<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(path, { signal, headers: { Accept: 'application/json' } });
  const body = (await res.json().catch(() => ({}))) as { error?: string };
  if (!res.ok) throw new ApiError(res.status, body.error ?? `Chyba ${res.status}`);
  return body as T;
}

export type Loadable<T> = { data?: T; error?: ApiError; loading: boolean };

// Načíta dáta z API pri zmene cesty; starú požiadavku zruší.
export function useApi<T>(path: string): Loadable<T> {
  const [state, setState] = useState<Loadable<T>>({ loading: true });
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
  }, [path]);
  return state;
}
