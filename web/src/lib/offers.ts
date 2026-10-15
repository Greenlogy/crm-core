// Ponuky (modul 5, F2): typy odpovedí API a texty stavov. Výpočty robí databáza – web iba zobrazuje.

import type { Risk } from './deals';
import type { Tone } from './labels';

export type OfferState =
  | 'koncept' | 'caka_na_schvalenie' | 'pripravena' | 'odoslana' | 'otvorena' | 'akceptovana' | 'zamietnuta' | 'nahradena' | 'vyprsana';

export const OFFER_STATE: Record<OfferState, { label: string; tone: Tone; live?: boolean }> = {
  koncept: { label: 'Koncept', tone: 'neutral', live: true },
  caka_na_schvalenie: { label: 'Čaká na schválenie', tone: 'warning', live: true },
  pripravena: { label: 'Pripravená', tone: 'info', live: true },
  odoslana: { label: 'Odoslaná', tone: 'info', live: true },
  otvorena: { label: 'Otvorená', tone: 'info', live: true },
  akceptovana: { label: 'Akceptovaná', tone: 'positive', live: true },
  zamietnuta: { label: 'Zamietnutá', tone: 'negative', live: true },
  nahradena: { label: 'Nahradená', tone: 'neutral' },
  vyprsana: { label: 'Vypršaná', tone: 'neutral' },
};

export type PriceKind = 'fix' | 'spot' | 'kombinacia' | 'cennik' | 'viwa';
export const PRICE_KIND: Record<PriceKind, string> = {
  fix: 'FIX',
  spot: 'SPOT + aditív',
  kombinacia: 'FIX + SPOT',
  cennik: 'Cenník',
  viwa: 'VIWA',
};
export type PriceModel = 'fix' | 'spot_plus_eur' | 'spot_minus_eur' | 'spot_minus_pct' | 'cennik';
export const PRICE_MODEL: Record<string, string> = {
  fix: 'FIX',
  spot_plus_eur: 'SPOT + €',
  spot_minus_eur: 'SPOT − €',
  spot_minus_pct: 'SPOT − %',
  cennik: 'Cenník',
};
export const THRESHOLD_SOURCE: Record<string, string> = {
  cena_pre_obchodnika: 'cena pre obchodníka',
  odhad_portfolia: 'odhad portfólia',
  min_aditiv: 'minimálny aditív',
  vynimka: 'schválená výnimka',
  cena_vykupu: 'cena výkupu',
  energopomoc: 'energopomoc',
  viwa: 'VIWA',
};
export const SEND_CHANNEL: Record<string, string> = {
  email_mimo_crm: 'E-mail mimo CRM',
  osobne: 'Osobne',
  ine: 'Iné',
  crm: 'E-mail z CRM',
};
export const APPROVAL_KIND: Record<string, string> = {
  vynimka_ceny: 'Výnimka z ceny',
  rizikovy_zakaznik: 'Konkurz / rating E/X',
  predlzenie_platnosti: 'Predĺženie platnosti',
  pridelenie_firmy: 'Pridelenie firmy',
};

export type Variant = {
  id: string;
  offer_id: string;
  sort_order: number;
  name: string;
  price_kind: PriceKind;
  supply_from: string;
  supply_to: string | null;
  viwa_package: string | null;
  flexibility_pct: string | null;
  planned_volume_mwh: string | null;
  invoice_due_days: number;
  advance_kind: 'mesacne' | 'financna_zabezpeka';
  advance_pct: string | null;
  advance_due_day: number | null;
  negative_price_compensation: boolean;
  years: number[];
};
export type OfferItem = {
  id: string;
  variant_id: string;
  oom_id: string | null;
  year: number | null;
  slot: string;
  product_id: string;
  product_name: string;
  price_model: PriceModel;
  price_vt_eur_mwh: string | null;
  price_nt_eur_mwh: string | null;
  additive_eur_mwh: string | null;
  additive_pct: string | null;
  fee_eur_month: string | null;
};
export type VariantValue = {
  oom_id: string;
  year: number;
  voltage_group: 'nn' | 'vn';
  item_id: string | null;
  price_model: PriceModel | null;
  kind: string | null;
  price_vt: string | null;
  additive: string | null;
  additive_pct: string | null;
  months: number;
  volume_mwh: string;
  revenue_eur: string | null;
  threshold: string | null;
  threshold_source: string | null;
  exception_value: string | null;
  added_value_eur: string | null;
  fees_eur: string | null;
  margin_eur: string | null;
  below: boolean;
  missing: string | null;
};
export type VariantSummary = {
  year: number | null;
  volume_mwh: string;
  added_value_eur: string | null;
  margin_eur: string | null;
  commission_eur: string | null;
  commission_pct: string | null;
  below: boolean;
  missing: number;
};
export type OfferCheck = {
  errors: string[];
  needs: { variant: string; variant_id: string; year: number; price_model: string; voltage_group: string; requested_value: number; threshold_value: number | null; threshold_source: string; volume_mwh: number }[];
  risk_needs_approval: boolean;
  fix_stale: boolean;
  risk: Risk;
} | null;
export type OfferApproval = {
  id: string;
  kind: string;
  status: 'caka' | 'schvalena' | 'zamietnuta' | 'zrusena';
  reason: string | null;
  decision_note: string | null;
  valid_until: string | null;
  requested_valid_until: string | null;
  created_at: string;
  decided_at: string | null;
  decided_by_name: string | null;
  requested_by_name: string | null;
};
export type Offer = {
  id: string;
  deal_id: string;
  number: string;
  version: number;
  display_number: string;
  status: OfferState;
  state: OfferState;
  kind: 'dodavka' | 'vykup' | 'viwa';
  language: 'sk' | 'en';
  household: boolean;
  contact_id: string | null;
  priced_on: string;
  seller_type: 'obchodnik' | 'manazer' | null;
  valid_until: string | null;
  valid_shortened: boolean;
  sent_at: string | null;
  sent_channel: string | null;
  sent_note: string | null;
  sent_by_name: string | null;
  rejected_at: string | null;
  rejected_note: string | null;
  created_at: string;
  created_by_name: string | null;
  deal_name: string;
  owner_name: string | null;
  company_id: string | null;
  person_id: string | null;
  customer_name: string | null;
  stage_code: string;
  closed_at: string | null;
  can_edit: boolean;
  see_margin: boolean;
  see_portfolio: boolean;
  commission_pct: string | null;
  variants: Variant[];
  items: OfferItem[];
  ooms: { id: string; eic: string; voltage_level: string | null; voltage_group: 'nn' | 'vn'; pds_tariff: string | null }[];
  contacts: { id: string; name: string | null; position: string | null }[];
  approvals: OfferApproval[];
  check: OfferCheck;
  calc: { variant_id: string; values: VariantValue[]; summary: VariantSummary[] }[];
  products: { id: string; code: string; name: string; category: string; price_models: string[] }[];
  versions: { id: string; version: number; display_number: string; status: OfferState; state: OfferState }[];
};
export type DealOffers = {
  items: { id: string; number: string; version: number; display_number: string; status: OfferState; state: OfferState; language: string; valid_until: string | null; sent_at: string | null; created_at: string; variants: number }[];
  main: { id: string; name: string; sort_order: number; offer_id: string; display_number: string; accepted: boolean; summary: VariantSummary[] } | null;
};

/** Upraviť sa dá rozpracovaná verzia (koncept, čakajúca, pripravená – úprava ju vráti do konceptu). */
export const isDraft = (s: OfferState) => s === 'koncept' || s === 'caka_na_schvalenie' || s === 'pripravena';
export const variantLetter = (n: number) => String.fromCharCode(64 + n);

/** Čas v Europe/Bratislava: „15. 10. 2026 16:00“ */
export const dateTime = (v: string | null | undefined) =>
  v
    ? new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(v))
    : '–';
