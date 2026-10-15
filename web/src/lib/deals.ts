// Obchody (modul 5, F1): typy odpovedí API a popisy. Rovnaké obrazovky majú interní aj externí obchodníci –
// čo kto vidí a mení, rozhoduje databáza (RLS), nie skrývanie častí stránky.

import type { Tone } from './labels';

export type Risk = {
  warnings: string[];
  needs_approval: boolean;
  z_band: 'riziko' | 'seda_zona' | 'stabilna' | null;
  finstat_updated_at: string | null;
} | null;

export type StageRef = { id: string; name: string; code: StageCode | null; outcome: 'otvoreny' | 'vyhrany' | 'prehrany'; probability: string | number | null };
export type StageCode = 'prilezitost' | 'cenova_ponuka' | 'vyjednavanie' | 'akceptacia' | 'vyhrane' | 'prehrane';
export type PipelineRef = { id: string; name: string; kind: string; org_id: string | null; stages: StageRef[] };
export type LookupRef = { code: string; label: string; system: boolean };
export type DealOptions = { pipelines: PipelineRef[]; lists: Record<string, LookupRef[]>; manager: boolean };

export type StepState = 'bez_kroku' | 'po_termine' | 'dnes' | 'planovany' | null;

export type DealRow = {
  id: string;
  name: string;
  org_id: string;
  company_id: string | null;
  person_id: string | null;
  customer_name: string | null;
  customer_ico: string | null;
  pipeline_id: string;
  pipeline_name: string;
  pipeline_kind: string;
  stage_id: string;
  stage_name: string;
  stage_code: StageCode | null;
  stage_outcome: 'otvoreny' | 'vyhrany' | 'prehrany';
  probability: string | null;
  owner_id: string;
  owner_name: string | null;
  source_code: string;
  source_label: string | null;
  expected_close: string | null;
  supply_start: string | null;
  next_step: string | null;
  next_step_on: string | null;
  step_state: StepState;
  estimated_value_eur: string | null;
  value_eur: string | null;
  weighted_eur: string | null;
  lost_reason_code: string | null;
  lost_reason_label: string | null;
  lost_note: string | null;
  previous_contract_id: string | null;
  previous_contract_number: string | null;
  stage_changed_at: string;
  closed_at: string | null;
  created_at: string;
  note: string | null;
  oom_count: number;
  risk: Risk;
};

export type DealOom = {
  id: string;
  eic: string | null;
  name: string | null;
  type: string | null;
  status: string | null;
  voltage_level: string | null;
  pds: string | null;
  pds_tariff: string | null;
  address: string | null;
  planned_vt_mwh: string | null;
  planned_nt_mwh: string | null;
  planned_feed_in_mwh: string | null;
  source_power_kw: string | null;
  created_here: boolean;
};

export type DealContact = {
  id: string;
  name: string | null;
  position: string | null;
  email: string | null;
  phone: string | null;
  mobile: string | null;
  roles: string[];
  is_primary: boolean;
};

export type DealCard = DealRow & {
  can_edit: boolean;
  can_change_owner: boolean;
  can_reopen: boolean;
  customer_owner_id: string | null;
  customer_owner_name: string | null;
  stages: StageRef[];
  ooms: DealOom[];
  contacts: DealContact[];
};

export type TimelineItem = {
  id: string;
  type: 'udalost' | 'poznamka';
  kind: string | null;
  occurred_at: string;
  reason: string | null;
  detail: Record<string, unknown> | null;
  user_name: string | null;
  from_stage: string | null;
  to_stage: string | null;
  oom_eic: string | null;
  contact_name: string | null;
  from_owner: string | null;
  to_owner: string | null;
  lost_reason_label: string | null;
  body: string | null;
};

export const STEP_STATE: Record<Exclude<StepState, null>, { label: string; tone: Tone }> = {
  bez_kroku: { label: 'bez ďalšieho kroku', tone: 'warning' },
  po_termine: { label: 'po termíne', tone: 'negative' },
  dnes: { label: 'dnes', tone: 'info' },
  planovany: { label: 'naplánovaný', tone: 'neutral' },
};

export const RISK_LABEL: Record<string, { label: string; tone: Tone }> = {
  dlhy: { label: 'dlhy / nedoplatky', tone: 'warning' },
  konkurz: { label: 'konkurz', tone: 'negative' },
  restrukturalizacia: { label: 'reštrukturalizácia', tone: 'negative' },
  rating_e: { label: 'rating E', tone: 'negative' },
  rating_x: { label: 'rating X', tone: 'negative' },
  z_skore: { label: 'Z-skóre pod 1,23', tone: 'warning' },
  zrusena: { label: 'zrušená firma', tone: 'negative' },
};

export const Z_BAND: Record<string, { label: string; tone: Tone }> = {
  riziko: { label: 'riziko úpadku (pod 1,23)', tone: 'negative' },
  seda_zona: { label: 'šedá zóna (1,23–2,90)', tone: 'warning' },
  stabilna: { label: 'stabilná (nad 2,90)', tone: 'positive' },
};

export const OUTCOME_TONE: Record<string, Tone> = { otvoreny: 'info', vyhrany: 'positive', prehrany: 'negative' };

export const VOLTAGE: Record<string, string> = { nn: 'NN', vn: 'VN', vvn: 'VVN' };

/** Druh obchodu podľa pipeline: dodávka (spotreba VT/NT) alebo výkup a VIWA (výroba, výkon). */
export const isSupply = (kind: string) => kind !== 'b2b_vykup' && kind !== 'green_viwa';
