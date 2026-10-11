// Index HubSpotu a pravidlo 1 modelu: vlastník OOM = firma, inak kontakt najnovšieho dealu v stave zmluvy.
// Spoločné pre výber vzorky (select.ts) a nahratie (load.ts).

import type { Edge, StageInfo } from './hubspot.ts';

// Deal v stave zmluvy (pravidlo 2 modelu) a ukončený deal (iba ak OOM nemá zmluvu).
export const CONTRACT_STAGE = /^(Zmluv[ay]?_(\d{4}|neurčito)|EFET_\d{4}|Úspech(_XML)?)$/;
export const ENDED_STAGE = /^Ukončená$/;
const DEAL_TO_COMPANY_PRIMARY = 5;

export type OomType = 'spotreba' | 'vyroba' | 'sharing' | 'velkoobchod' | 'neznamy';

export type Index = {
  builtAt: string;
  dealStages: Record<string, StageInfo>;
  oomStages: Record<string, StageInfo>;
  ooms: Record<string, { stage: string }>;
  deals: Record<string, { stage: string; date: string }>;
  dealCompany: Record<string, Edge[]>;
  dealContact: Record<string, Edge[]>;
  dealOom: Record<string, Edge[]>;
  contactCompany: Record<string, Edge[]>;
};

export function oomType(pipeline: string): OomType {
  const p = pipeline.toLowerCase();
  if (p.includes('sharing')) return 'sharing';
  if (p.includes('veľkoobchod')) return 'velkoobchod';
  if (p.includes('vyroba') || p.includes('výroba')) return 'vyroba';
  if (p.includes('spotreba')) return 'spotreba';
  return 'neznamy';
}

export function dealStageLabel(index: Index, deal: string): string {
  return index.dealStages[index.deals[deal]?.stage]?.stage ?? '';
}

// Zákazník dealu: hlavná (primary) firma, inak prvá firma, inak prvý kontakt. Kľúč `company:ID` / `contact:ID`.
export function dealCustomerKey(index: Index, deal: string): string | undefined {
  const companies = index.dealCompany[deal] ?? [];
  const company = companies.find((e) => e.typeIds.includes(DEAL_TO_COMPANY_PRIMARY)) ?? companies[0];
  if (company) return `company:${company.to}`;
  const contact = index.dealContact[deal]?.[0];
  return contact ? `contact:${contact.to}` : undefined;
}

export type OwnerResult = {
  owners: Record<string, string>; // OOM → kľúč zákazníka
  fromEnded: number;
  unowned: number;
};

export function deriveOomOwners(index: Index): OwnerResult {
  const oomDeals: Record<string, string[]> = {};
  for (const [d, edges] of Object.entries(index.dealOom)) for (const e of edges) (oomDeals[e.to] ??= []).push(d);

  const owners: Record<string, string> = {};
  let fromEnded = 0;
  let unowned = 0;
  for (const o of Object.keys(index.ooms)) {
    const deals = oomDeals[o] ?? [];
    let pool = deals.filter((d) => CONTRACT_STAGE.test(dealStageLabel(index, d)));
    if (!pool.length) {
      pool = deals.filter((d) => ENDED_STAGE.test(dealStageLabel(index, d)));
      if (pool.length) fromEnded++;
    }
    const newest = pool.sort((a, b) => index.deals[b].date.localeCompare(index.deals[a].date))[0];
    const key = newest ? dealCustomerKey(index, newest) : undefined;
    if (key) owners[o] = key;
    else unowned++;
  }
  return { owners, fromEnded, unowned };
}
