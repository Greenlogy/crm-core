// Volania API jadra (čítanie aj zápis) a typy odpovedí. Číselné hodnoty z databázy prichádzajú ako text.

import { useCallback, useEffect, useState } from 'react';
import type { RegulationCheck } from '../components/regulation';

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
  /** vypočítaný stav (CONTRACT_STATUS) */
  status: string;
  type: string;
  valid_from: string | null;
  valid_to: string | null;
  deal_name: string | null;
  oom_count: number;
  price_count: number;
  /** bilancia bežného roka (0027); marža iba s právom */
  balance_year: number;
  added_value_eur: Num;
  margin_eur: Num;
  year_volume_mwh: Num;
};

export type PriceRow = {
  id: string;
  contract_id?: string;
  contract_number?: string | null;
  oom_id?: string;
  eic?: string;
  product: string | null;
  /** zložka ceny (PRICE_SLOT) a cenový model (0025) */
  slot: string;
  price_model: string;
  price_vt_eur_mwh: Num;
  price_nt_eur_mwh: Num;
  additive_eur_mwh: Num;
  additive_pct: Num;
  fee_eur_month: Num;
  fee_kw_eur_month: Num;
  valid_from: string | null;
  valid_to: string | null;
  /** platna = obdobie obsahuje dnešok */
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
  /** malý podnik a hranica 30 MWh k dnešku (0029) */
  regulation_check: RegulationCheck | null;
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
export type OomRegulationChange = {
  id: string;
  valid_from: string;
  value: boolean | null;
  applied_at: string | null;
  created_at: string;
  created_by_name: string | null;
  is_planned: boolean;
};

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
  /** plán výkupu lokálneho zdroja zadaný ručne (0023); computed = počíta sa z výkonu */
  planned_feed_in_manual: boolean;
  planned_feed_in_computed: boolean;
  public_lighting: boolean;
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
  /** zmeny cenovej regulácie s dátumom (0023, 0024); is_planned = budúca, ešte neuplatnená */
  regulation: OomRegulationChange[];
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

export type ContractListItem = {
  id: string;
  number: string;
  type: string;
  phase: string;
  /** vypočítaný stav (CONTRACT_STATUS) */
  state: string;
  valid_from: string | null;
  valid_to: string | null;
  effective_to: string | null;
  crm_valid_to: string | null;
  auto_prolong: boolean;
  customer_kind: 'company' | 'person';
  customer_name: string | null;
  company_id: string | null;
  person_id: string | null;
  owner_id: string | null;
  owner_name: string | null;
  oom_count: number;
  qty_mwh: Num;
  flags: string[];
  org_id: string;
  org_name: string;
  ending?: boolean;
  /** bilancia roka zoznamu (0027) */
  year_volume_mwh?: Num;
  added_value_eur?: Num;
  margin_eur?: Num;
  portfolio_stale?: boolean | null;
  balance_missing?: string | null;
};
export type ContractList = {
  page: number;
  pageSize: number;
  year: number;
  total: number;
  counts: Record<string, number>;
  items: ContractListItem[];
};

export type ContractCard = ContractListItem & {
  op_id: string | null;
  signed_on: string | null;
  small_business: boolean;
  list_price: boolean;
  viwa_package: string | null;
  close_reason: string | null;
  created_by_name: string | null;
  note: string | null;
  op_updated_at: string | null;
  previous_contract_id: string | null;
  previous_number: string | null;
  related_contract_id: string | null;
  related_number: string | null;
  related_type: string | null;
  can_edit: boolean;
  can_change_owner: boolean;
  can_edit_vykup: boolean;
  /** „Pod hranicou bez výnimky“ uzatvára iba „schvaľuje ceny“ (0029) */
  can_resolve_threshold: boolean;
  /** malý podnik a hranica 30 MWh (0029); null = zákazník nie je regulovaný malý podnik */
  regulation_check: RegulationCheck | null;
  /** objem zmluvy vs. XM Trade (0030); null = nehodnotí sa (výkup, VIWA, skončená, bez OOM spotreby) */
  volume_check: VolumeCheck | null;
  vykup_min_additive: Num;
  balance: ContractYear[];
  exceptions: { id: string; years: number[]; price_model: string; requested_value: Num; threshold_value: Num; state: string;
                decided_at: string | null; decided_by_name: string | null; requested_by_name: string | null; reason: string }[];
  ooms: {
    id: string;
    eic: string;
    type: string;
    status: string;
    name: string | null;
    address_street: string | null;
    address_number_orientacne: string | null;
    address_city: string | null;
    voltage_level: string | null;
    breaker_a: Num;
    public_lighting: boolean;
    price_regulation: boolean | null;
    tariff_label: string | null;
    product_name: string | null;
    program_name: string | null;
    qty_vt_mwh: Num;
    qty_nt_mwh: Num;
    source_power_kw: Num;
    /** plánovaná spotreba VT + NT z XM Trade (0030) */
    xm_mwh: Num;
    valid_from: string | null;
    valid_to: string | null;
    op_valid_to: string | null;
    is_binding: boolean;
    successor_id: string | null;
    successor_number: string | null;
  }[];
  prices: (PriceRow & { product_name: string | null; op_product_name: string | null; source: string; price_list_name: string | null; price_list_version: string | null })[];
  flag_rows: ContractFlagRow[];
  imports: { import_id: string; action: 'nova' | 'zmena'; summary: string; created_at: string; op_file_name: string | null; xm_file_name: string | null; user_name: string | null }[];
  predecessors: { id: string; number: string }[];
};
/** Ročná bilancia zmluvy (contract_year_calc, 0027) */
export type ContractYear = {
  year: number;
  months: number;
  volume_mwh: Num;
  revenue_eur: Num;
  fees_eur: Num;
  cost_eur: Num;
  added_value_eur: Num;
  margin_cost_eur: Num;
  margin_eur: Num;
  model: string | null;
  tranche: string | null;
  basis_stored: boolean | null;
  basis_source: string | null;
  trader_price: Num;
  exception_id: string | null;
  exception_value: Num;
  portfolio_eur_mwh: Num;
  portfolio_on: string | null;
  portfolio_stale: boolean | null;
  missing: string | null;
};
export type ContractFlagRow = {
  id: string;
  code: string;
  year: number | null;
  detail: string | null;
  raised_at: string;
  resolved_at: string | null;
  resolved_note: string | null;
  resolved_by_name: string | null;
};

// Objem zmluvy vs. plánovaná spotreba z XM Trade (0030)
export type VolumeCheck = {
  contract_mwh: string;
  xm_mwh: string | null;
  diff_pct: string | null;
  months: number;
  oom_over: number;
  xm_missing: number;
  over: boolean;
  message: string;
};

// Upozornenia (zvonček, 0028) a denník nočných behov (admin, Nákup)
export type NotificationRow = {
  id: string;
  kind: string;
  detail: string | null;
  created_at: string;
  read_at: string | null;
  ref_date: string | null;
  contract_id: string | null;
  contract_number: string | null;
  price_exception_id: string | null;
  job_run_id: string | null;
  deal_id: string | null;
  deal_name: string | null;
  approval_id: string | null;
};
export type JobRunError = { zmluva: string | null; cislo: string | null; krok: string; kod: string; text: string };
export type JobRun = {
  id: string;
  job: string;
  run_date: string;
  test_date: boolean;
  started_at: string;
  finished_at: string | null;
  result: Record<string, unknown> & {
    cennik_spatne?: { pocet: number; zmluvy: string[] };
    maly_podnik?: { pocet: number; zmluvy: string[] };
    objem_xm?: { pocet: number; zmluvy: string[] };
    chyby?: number;
  };
  errors: JobRunError[];
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
export async function send<T = unknown>(method: 'POST' | 'PUT' | 'PATCH' | 'DELETE', path: string, data?: unknown): Promise<T> {
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
export type Permission = {
  view: Scope;
  edit: Scope;
  archive: boolean;
  export: boolean;
  import: boolean;
  edit_active: boolean;
  /** vidieť maržu firmy (iba modul zmluvy, 0023) */
  margin?: boolean;
};
export type SellerType = 'obchodnik' | 'manazer';
export type OrgRef = { id: string; name: string; country: string; currency: string; status: string; default: boolean };

export type Me = {
  id: string;
  name: string;
  email: string;
  is_admin: boolean;
  team_code: string;
  team_name: string;
  can_change_owner: boolean;
  /** typ predajcu (0023): obchodník / manažér, null = nepredáva */
  seller_type: SellerType | null;
  /** „schvaľuje ceny“ – cenové parametre, výnimky; vidí všetky zmluvy a maržu firmy */
  approves_prices: boolean;
  /** „schvaľuje pridelenie firmy“ (0032) */
  approves_assignments: boolean;
  /** mení vlastníka obchodu a zakladá obchody pre iných (CEO, admin, „všetko“ v module Obchod, schvaľovatelia) */
  deal_manager: boolean;
  can_see_margin: boolean;
  /** denník nočných behov (admin, Nákup – 0028) */
  can_see_job_runs: boolean;
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
  updated_at: string;
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
  sort_order: number;
  greencar: boolean | null;
  greencar_kwh_per_voucher: number | null;
  greencar_voucher_eur: Num;
  greenshare: boolean | null;
  greenshare_fee_pct: Num;
  viwa_conversion_factor: Num;
  viwa_activation_bonus: number | null;
  viwa_credit_expiry_months: number | null;
  tariffs: TariffRef[];
};

export type ApprovePreview = {
  version_id: string;
  name: string;
  valid_from: string;
  valid_to: string | null;
  item_count: number;
  can_approve: boolean;
  errors: string[];
  supersedes: { id: string; name: string } | null;
  closes: { id: string; name: string; valid_to: string } | null;
  missing_products: string[];
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
  /** variant tarifu (0023): vykurovanie, verejne_osvetlenie */
  tariff_variant: 'vykurovanie' | 'verejne_osvetlenie' | null;
  price_models: string[];
  price_regulation: boolean | null;
  status: string;
  sort_order: number;
  updated_at: string;
  used: boolean;
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
