// Nahratie vzorky do Neon vetvy dev (modul 2, krok 2) – generátor SQL. Do databázy sa nepripája.
//
//   cd ~/projects/greenlogy/crm-core/integrations/hubspot-sync
//   npm run sample:load
//
// Vstup:  exports/prototyp/vzorka-data.json, exports/prototyp/cache/index.json (z select.ts)
// Výstup: exports/prototyp/vzorka-load.sql      – jedna transakcia s INSERT (ID generuje skript)
//         exports/prototyp/vzorka-manifest.json – všetky vložené ID po tabuľkách
//         exports/prototyp/vzorka-delete.sql    – presné zmazanie podľa manifestu vrátane audit_log
//         exports/prototyp/nahratie-zistenia.md – čo sa nenahralo a prečo (iba HubSpot ID, bez mien)
// SQL sa spúšťa samostatne cez sample/psql-dev.sh, iba s Petrovým súhlasom.
// Z HubSpotu sa číta iba definícia pipelines dealov (poradie, pravdepodobnosť, uzavretie).

import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { HubSpotClient, loadToken } from '../inventory/client.ts';
import type { Edge, Props, StageInfo } from './hubspot.ts';
import { CONTRACT_STAGE, deriveOomOwners, ENDED_STAGE, oomType, type Index, type OomType } from './owners.ts';

const root = resolve(import.meta.dirname, '../../..');
const outDir = join(root, 'exports/prototyp');
const SOURCE = 'prototyp_vzorka';
const TODAY = new Date().toISOString().slice(0, 10);
const CONTRACT_PRICE_INVALID_STAGE = '89395222'; // Zmluvné ceny: Neplatné
const DEAL_TO_COMPANY_PRIMARY = 5;

type SampleData = {
  customers: { kind: 'company' | 'contact'; hubspotId: string }[];
  stages: { deals: Record<string, StageInfo>; oom: Record<string, StageInfo> };
  objects: Record<'companies' | 'contacts' | 'deals' | 'oom' | 'contractPrices' | 'purchasePrices', Record<string, Props>>;
  associations: Record<
    | 'dealCompany'
    | 'dealContact'
    | 'dealOom'
    | 'dealContractPrice'
    | 'dealPurchasePrice'
    | 'oomContractPrice'
    | 'companyContact'
    | 'contactCompany',
    Record<string, Edge[]>
  >;
};

type HubSpotPipeline = {
  id: string;
  label: string;
  displayOrder: number;
  stages: { id: string; label: string; displayOrder: number; metadata: { isClosed?: string; probability?: string } }[];
};

// --- Prevody hodnôt ---

const txt = (v: string | null | undefined) => {
  const t = (v ?? '').trim();
  return t === '' ? null : t;
};
const num = (v: string | null | undefined) => {
  const t = (v ?? '').trim().replace(/\s/g, '').replace(',', '.');
  return /^-?\d+(\.\d+)?$/.test(t) ? Number(t) : null;
};
const firstInt = (v: string | null | undefined) => {
  const m = (v ?? '').match(/\d+/);
  return m ? Number(m[0]) : null;
};
const toDate = (v: string | null | undefined, farIsNull = false) => {
  const t = (v ?? '').trim();
  let d: string | null = null;
  if (/^\d{4}-\d{2}-\d{2}/.test(t)) d = t.slice(0, 10);
  else if (/^\d{11,13}$/.test(t)) d = new Date(Number(t)).toISOString().slice(0, 10);
  if (d && farIsNull && d >= '2090-01-01') return null;
  return d;
};
const toTs = (v: string | null | undefined) => {
  const t = (v ?? '').trim();
  if (/^\d{4}-\d{2}-\d{2}/.test(t)) return new Date(t).toISOString();
  if (/^\d{11,13}$/.test(t)) return new Date(Number(t)).toISOString();
  return null;
};
const joinParts = (...parts: (string | null)[]) => parts.filter(Boolean).join(', ') || null;

const OOM_STATUS: Record<string, string> = {
  Aktívne: 'aktivne',
  Neaktívne: 'neaktivne',
  Zrušené: 'zrusene',
  Odídené: 'odidene',
  Prepísané: 'prepisane',
};
const SOURCE_KIND: Record<string, string> = {
  'Fotovoltická elektráreň': 'fve',
  'Vodná elektráreň': 'voda',
  'Bioplynová stanica': 'bioplyn',
  'Veterná elektráreň': 'vietor',
};
const SOURCE_TYPE: Record<string, string> = {
  'Virtuálna batéria': 'virtualna_bateria',
  'Lokálny zdroj': 'lokalny_zdroj',
  'Výrobný zdroj': 'vyrobny_zdroj',
  'Green VIWA': 'green_viwa',
};
const SUPPLIER_NOTICE: Record<string, string> = {
  'Akceptácia výpovede': 'akceptacia',
  'Bez akceptácie': 'bez_akceptacie',
  'Výpoveď sa nezasiela': 'nezasiela_sa',
  'Výpoveď odoslaná': 'odoslana',
  'Výpoveď potvrdená': 'potvrdena',
};
const OOM_SEGMENT: Record<string, string> = { Domácnosti: 'domacnost', 'Firmy a organizácie': 'firma' };

// --- Zápis SQL a manifest ---

type SqlValue = string | number | boolean | null;
const lit = (v: SqlValue) =>
  v === null ? 'NULL' : typeof v === 'number' ? String(v) : typeof v === 'boolean' ? (v ? 'TRUE' : 'FALSE') : `'${v.replace(/'/g, "''")}'`;

const ORDER = [
  'company',
  'contact',
  'company_contact',
  'pipeline',
  'pipeline_stage',
  'oom',
  'deal',
  'deal_oom',
  'deal_contact',
  'contract',
  'product',
  'contract_price',
  'contract_purchase',
] as const;
type Table = (typeof ORDER)[number];

const manifest: Record<Table, string[]> = Object.fromEntries(ORDER.map((t) => [t, []])) as unknown as Record<Table, string[]>;
const statements: Record<Table, string[]> = Object.fromEntries(ORDER.map((t) => [t, []])) as unknown as Record<Table, string[]>;

function insert(table: Table, row: Record<string, SqlValue>): string {
  const id = randomUUID();
  const full = { id, ...row };
  statements[table].push(
    `INSERT INTO ${table} (${Object.keys(full).join(', ')}) VALUES (${Object.values(full).map(lit).join(', ')});`,
  );
  manifest[table].push(id);
  return id;
}

type Finding = { table: string; hubspotId: string; reason: string };
const findings: Finding[] = [];
const note = (table: string, hubspotId: string, reason: string) => findings.push({ table, hubspotId, reason });

async function main() {
  const data = JSON.parse(readFileSync(join(outDir, 'vzorka-data.json'), 'utf8')) as SampleData;
  const index = JSON.parse(readFileSync(join(outDir, 'cache/index.json'), 'utf8')) as Index;
  const { owners } = deriveOomOwners(index);
  const A = data.associations;
  const O = data.objects;

  // --- Firmy ---
  const companyIds: Record<string, string> = {};
  const icoSeen = new Set<string>();
  for (const [hs, p] of Object.entries(O.companies)) {
    let ico: string | null = null;
    const raw = (p.ico_new ?? '').replace(/\D/g, '');
    if (raw) {
      if (raw.length <= 8) ico = raw.padStart(8, '0');
      else note('company', hs, `IČO má ${raw.length} číslic, ostáva prázdne`);
    }
    if (ico && icoSeen.has(ico)) {
      note('company', hs, 'duplicitné IČO vo vzorke, ostáva prázdne');
      ico = null;
    }
    if (ico) icoSeen.add(ico);
    const seg = p.segment_zakaznika ?? '';
    const segment = /Firma|Komunal/.test(seg) ? 'firma' : /Dodávateľ/.test(seg) ? 'dodavatel' : null;
    companyIds[hs] = insert('company', {
      name: txt(p.name) ?? `(bez názvu ${hs})`,
      ico,
      dic: txt(p.dic),
      ic_dph: txt(p.i_dph),
      registry_entry: txt(p.z_pis_v_or),
      nace: txt(p.sk_nace_group),
      statutory: txt(p.zast_pen_),
      address: joinParts(txt(p.address), txt(p.address2), txt(`${p.zip ?? ''} ${p.city ?? ''}`)),
      segment,
      debts_note: txt(p.dlhy_a_nedoplatky),
      insolvency_note: txt(p.konkurzy_a_re_trukturaliz_cie),
      finstat_url: txt(p.finstat_url),
      lifecycle_stage: txt(p.lifecyclestage),
      hubspot_id: hs,
    });
  }

  // --- Kontakty ---
  const b2c = new Set(data.customers.filter((c) => c.kind === 'contact').map((c) => c.hubspotId));
  const contactIds: Record<string, string> = {};
  for (const [hs, p] of Object.entries(O.contacts)) {
    contactIds[hs] = insert('contact', {
      first_name: txt(p.firstname),
      last_name: txt(p.lastname),
      title: txt(p.titul),
      email: txt(p.email),
      phone: txt(p.phone),
      mobile: txt(p.mobilephone),
      position: txt(p.jobtitle),
      address: joinParts(txt(p.address), txt(`${p.zip ?? ''} ${p.city ?? ''}`)),
      segment: b2c.has(hs) ? 'domacnost' : null,
      lifecycle_stage: txt(p.lifecyclestage),
      source: txt(p.zdroj_kontaktu_ako_vznikol_),
      hubspot_id: hs,
    });
  }

  // --- Kontakt – firma ---
  const pairs = new Set<string>();
  for (const [co, edges] of Object.entries(A.companyContact)) for (const e of edges) pairs.add(`${co}|${e.to}`);
  for (const [ct, edges] of Object.entries(A.contactCompany)) for (const e of edges) pairs.add(`${e.to}|${ct}`);
  for (const pair of [...pairs].sort()) {
    const [co, ct] = pair.split('|');
    if (!companyIds[co] || !contactIds[ct]) continue;
    insert('company_contact', {
      company_id: companyIds[co],
      contact_id: contactIds[ct],
      is_primary: O.contacts[ct]?.associatedcompanyid === co,
    });
  }

  // --- Pipelines dealov (iba použité) ---
  const client = new HubSpotClient(loadToken(root));
  const res = await client.get<{ results: HubSpotPipeline[] }>('/crm/v3/pipelines/deals');
  const usedPipelines = new Set(Object.values(O.deals).map((d) => d.pipeline ?? ''));
  const pipelineIds: Record<string, string> = {};
  const stageIds: Record<string, string> = {};
  const stageClosed: Record<string, boolean> = {};
  for (const pl of res.results.filter((p) => usedPipelines.has(p.id))) {
    pipelineIds[pl.id] = insert('pipeline', { name: pl.label, sort_order: pl.displayOrder, hubspot_id: pl.id });
    for (const st of pl.stages) {
      const isClosed = st.metadata.isClosed === 'true';
      const probability = num(st.metadata.probability ?? null);
      stageClosed[st.id] = isClosed;
      stageIds[st.id] = insert('pipeline_stage', {
        pipeline_id: pipelineIds[pl.id],
        name: st.label,
        sort_order: st.displayOrder,
        probability,
        is_closed: isClosed,
        is_won: isClosed && probability === 1,
        hubspot_id: st.id,
      });
    }
  }

  // --- OOM ---
  const customerUuid = (key: string) => {
    const [kind, id] = key.split(':');
    return kind === 'company' ? { company_id: companyIds[id] ?? null, person_id: null } : { company_id: null, person_id: contactIds[id] ?? null };
  };
  const oomIds: Record<string, string> = {};
  const oomTypes: Record<string, OomType> = {};
  const oomByEic: Record<string, string> = {};
  for (const [hs, p] of Object.entries(O.oom)) {
    const eic = txt(p.eic);
    if (!eic) {
      note('oom', hs, 'chýba EIC');
      continue;
    }
    if (oomByEic[eic]) {
      note('oom', hs, `duplicitné EIC vo vzorke (už nahraté OOM ${oomByEic[eic]})`);
      continue;
    }
    const ownerKey = owners[hs];
    const owner = ownerKey ? customerUuid(ownerKey) : undefined;
    if (!owner || (!owner.company_id && !owner.person_id)) {
      note('oom', hs, ownerKey ? `vlastník ${ownerKey} nie je vo vzorke` : 'vlastníka nemožno odvodiť');
      continue;
    }
    const stage = data.stages.oom[p.hs_pipeline_stage ?? ''];
    const type = oomType(stage?.pipeline ?? '');
    const status = OOM_STATUS[stage?.stage ?? ''];
    if (type === 'neznamy' || !status) {
      note('oom', hs, `neznámy typ alebo stav (${stage?.pipeline ?? '?'} / ${stage?.stage ?? '?'})`);
      continue;
    }
    const mapped = (map: Record<string, string>, value: string | null | undefined, field: string) => {
      const t = txt(value);
      if (!t) return null;
      if (map[t]) return map[t];
      note('oom', hs, `${field}: hodnota „${t}“ sa nedá preložiť, ostáva prázdna`);
      return null;
    };
    const supplyFrom = toDate(p.ucinnost_oom_od);
    let supplyTo = toDate(p.ucinnost_oom_do, true);
    if (supplyFrom && supplyTo && supplyTo < supplyFrom) {
      note('oom', hs, 'účinnosť do je pred účinnosťou od, „do“ ostáva prázdne');
      supplyTo = null;
    }
    const id = insert('oom', {
      ...owner,
      eic,
      type,
      status,
      segment: mapped(OOM_SEGMENT, p.typ_odberu, 'typ odberu'),
      address_street: txt(p.adresa_ulica),
      address_number_supisne: txt(p.adresa_supisne_c_),
      address_city: txt(p.adresa_obec),
      address_zip: txt(p.adresa_psc),
      pds: txt(p.pds),
      pds_point_id: txt(p.identifikator_pds__cislo_op_),
      pds_tariff: txt(p.sadzba_pds),
      voltage_level: txt(p.napatova_uroven),
      metering_type: txt(p.typ_merania),
      phases: firstInt(p.pocet_faz),
      breaker_a: num(p.velkost_istica__a_),
      reserved_capacity_kw: num(p.rezervovana_kapacita__kw_),
      max_reserved_capacity_kw: num(p.maximalna_rezervovana_kapacita__kw_),
      capacity_reservation_method: txt(p.sposob_rezervovania_kapacity),
      price_regulation: txt(p.cenova_regulacia),
      excise_tax: txt(p.spotrebna_dan),
      billing_period: txt(p.fakturacne_obdobie),
      advance_payment_method: txt(p.sposob_zalohovych_faktur),
      advance_payment_pct: num(p.zalohova_platba____),
      planned_consumption_vt_mwh: num(p.planovana_spotreba_1t_vt__mwh_),
      planned_consumption_nt_mwh: num(p.planovana_spotreba_nt__mwh_),
      planned_feed_in_mwh: num(p.planovany_objem_vykupu__mwh_),
      source_power_kw: num(p.vykon_zdroja__kw_),
      source_kind: mapped(SOURCE_KIND, p.druh_vyrobneho_zdroja, 'druh výrobného zdroja'),
      source_type: mapped(SOURCE_TYPE, p.typ_zdroja, 'typ zdroja'),
      feed_in_contract_type: txt(p.typ_vykupnej_zmluvy),
      inverter_power_kw: num(p.st__vykon_kw),
      panels_power_kw: num(p.fv__vykon_panelov),
      supply_from: supplyFrom,
      supply_to: supplyTo,
      previous_supplier_notice: mapped(SUPPLIER_NOTICE, p.vypoved_predoslemu_dodavatelovi, 'výpoveď predošlému dodávateľovi'),
      previous_supplier_notice_accepted_at: toTs(p.akceptacia_vypovede_ineho_dodavatela_k_datumu),
      hubspot_id: hs,
    });
    oomIds[hs] = id;
    oomTypes[hs] = type;
    oomByEic[eic] = hs;
  }

  // --- Dealy ---
  const dealIds: Record<string, string> = {};
  const dealCustomer: Record<string, { company_id: string | null; person_id: string | null }> = {};
  const dealStage: Record<string, string> = {};
  for (const [hs, p] of Object.entries(O.deals)) {
    const companies = A.dealCompany[hs] ?? [];
    let customer: { company_id: string | null; person_id: string | null } | undefined;
    if (companies.length) {
      const loaded = companies.filter((e) => companyIds[e.to]);
      const primary = loaded.find((e) => e.typeIds.includes(DEAL_TO_COMPANY_PRIMARY)) ?? loaded[0];
      if (primary) customer = { company_id: companyIds[primary.to], person_id: null };
    } else {
      const contact = (A.dealContact[hs] ?? []).find((e) => contactIds[e.to]);
      if (contact) customer = { company_id: null, person_id: contactIds[contact.to] };
    }
    if (!customer) {
      note('deal', hs, 'zákazník dealu nie je vo vzorke');
      continue;
    }
    const pipelineId = pipelineIds[p.pipeline ?? ''];
    const stageId = stageIds[p.dealstage ?? ''];
    if (!pipelineId || !stageId) {
      note('deal', hs, 'neznáma pipeline alebo štádium');
      continue;
    }
    dealIds[hs] = insert('deal', {
      ...customer,
      pipeline_id: pipelineId,
      stage_id: stageId,
      name: txt(p.dealname) ?? `(bez názvu ${hs})`,
      campaign: txt(p.kampan),
      closed_at: stageClosed[p.dealstage ?? ''] ? toTs(p[`hs_v2_date_entered_${p.dealstage}`]) : null,
      lost_reason: txt(p.closed_lost_reason),
      hubspot_id: hs,
    });
    dealCustomer[hs] = customer;
    dealStage[hs] = data.stages.deals[p.dealstage ?? '']?.stage ?? '';
  }

  for (const [d, edges] of Object.entries(A.dealOom)) {
    if (!dealIds[d]) continue;
    for (const e of edges) if (oomIds[e.to]) insert('deal_oom', { deal_id: dealIds[d], oom_id: oomIds[e.to] });
  }
  for (const [d, edges] of Object.entries(A.dealContact)) {
    if (!dealIds[d]) continue;
    for (const e of new Set(edges.map((x) => x.to))) {
      if (contactIds[e]) insert('deal_contact', { deal_id: dealIds[d], contact_id: contactIds[e] });
    }
  }

  // --- Zmluvy (deal v stave zmluvy alebo ukončený) ---
  const contractIds: Record<string, string> = {};
  const numberSeen = new Set<string>();
  for (const [hs, p] of Object.entries(O.deals)) {
    if (!dealIds[hs]) continue;
    const stage = dealStage[hs];
    const ended = ENDED_STAGE.test(stage);
    if (!CONTRACT_STAGE.test(stage) && !ended) continue;

    const validFrom = toDate(p.innos_zmluvy_od);
    let validTo = toDate(p.innos_zmluvy_do, true);
    if (!validTo && !toDate(p.innos_zmluvy_do)) {
      const year = stage.match(/_(\d{4})$/)?.[1];
      if (year) validTo = `${year}-12-31`;
    }
    if (validFrom && validTo && validTo < validFrom) {
      note('contract', hs, 'platnosť do je pred platnosťou od, „do“ ostáva prázdne');
      validTo = null;
    }
    let number = txt(p.cislo_zmluvy);
    if (number && numberSeen.has(number)) {
      note('contract', hs, `číslo zmluvy ${number} sa opakuje, ostáva prázdne`);
      number = null;
    }
    if (number) numberSeen.add(number);

    contractIds[hs] = insert('contract', {
      deal_id: dealIds[hs],
      ...dealCustomer[hs],
      number,
      status: ended || (validTo !== null && validTo < TODAY) ? 'ukoncena' : 'aktivna',
      confirmed: p.stav_zmluvy === 'Potvrdený',
      valid_from: validFrom,
      valid_to: validTo,
      payment_terms_days: firstInt(p.splatnost_faktur),
      consumption_tolerance: firstInt(p.tolerancia_odberu_bez_obmedzeni_a_pokut),
      advance_payment_pct: firstInt(p.vyska_preddavkovej_platby),
      hubspot_deal_id: hs,
    });
  }
  const dealDate = (d: string) => O.deals[d]?.closedate ?? O.deals[d]?.createdate ?? '';

  // --- Zmluvné ceny a produkty ---
  const priceDeals: Record<string, string[]> = {};
  for (const [d, edges] of Object.entries(A.dealContractPrice)) for (const e of edges) (priceDeals[e.to] ??= []).push(d);
  const priceOoms: Record<string, string[]> = {};
  for (const [o, edges] of Object.entries(A.oomContractPrice)) for (const e of edges) (priceOoms[e.to] ??= []).push(o);

  const productIds: Record<string, string> = {};
  const validSeen = new Set<string>();
  for (const [hs, p] of Object.entries(O.contractPrices)) {
    const deal = (priceDeals[hs] ?? []).filter((d) => contractIds[d]).sort((a, b) => dealDate(b).localeCompare(dealDate(a)))[0];
    if (!deal) {
      note('contract_price', hs, 'žiadny jej deal nemá zmluvu vo vzorke');
      continue;
    }
    const oom = (priceOoms[hs] ?? []).find((o) => oomIds[o]) ?? oomByEic[txt(p.eic) ?? ''];
    if (!oom || !oomIds[oom]) {
      note('contract_price', hs, 'jej OOM nie je nahraté');
      continue;
    }
    let direction: 'odber' | 'dodavka';
    if (p.typ_oom === 'Odber') direction = 'odber';
    else if (p.typ_oom === 'Dodávka') direction = 'dodavka';
    else if (oomTypes[oom] === 'spotreba') direction = 'odber';
    else if (oomTypes[oom] === 'vyroba' || oomTypes[oom] === 'sharing') direction = 'dodavka';
    else {
      direction = 'odber';
      note('contract_price', hs, `smer sa nedá určiť (typ OOM ${oomTypes[oom]}), nastavené „odber“`);
    }
    const status = p.hs_pipeline_stage === CONTRACT_PRICE_INVALID_STAGE ? 'neplatna' : 'platna';
    const key = `${deal}|${oom}`;
    if (status === 'platna' && validSeen.has(key)) {
      note('contract_price', hs, `druhá platná cena pre rovnaké OOM ${oom} a zmluvu ${deal}, nenahraná`);
      continue;
    }
    if (status === 'platna') validSeen.add(key);

    const code = txt(p.produkt);
    if (code && !productIds[code]) {
      productIds[code] = insert('product', {
        code,
        name: code,
        kind: direction === 'odber' ? 'dodavka' : 'vykup',
        unit: 'eur_mwh',
      });
    }
    const validFrom = toDate(p.ucinnost_ceny_od);
    let validTo = toDate(p.ucinnost_ceny_do, true);
    if (validFrom && validTo && validTo < validFrom) {
      note('contract_price', hs, 'účinnosť do je pred účinnosťou od, „do“ ostáva prázdne');
      validTo = null;
    }
    insert('contract_price', {
      contract_id: contractIds[deal],
      oom_id: oomIds[oom],
      product_id: code ? productIds[code] : null,
      direction,
      price_vt_eur_mwh: num(p.cena_1t_2t_vt__eur_mwh_),
      price_nt_eur_mwh: num(p.cena_2t_nt__eur_mwh_),
      imbalance_price_eur_mwh: num(p.cena_odchylky__eur_mwh_),
      additive_coefficient_pct: num(p.aditivny_koeficient____),
      fee_oom_eur_month: num(p.platba_za_odberne_miesto__eur_mesiac_),
      fee_zem_eur_month: num(p.platba_za_zem__eur_mesiac_),
      fee_vbattery_eur_month: num(p.platba_za_vbattery__eur_mesiac_),
      fee_rk_eur_kw_month: num(O.deals[deal]?.green_viwa_poplatok_za_rk__pomocny_),
      vbattery_program: txt(p.program_vbattery),
      valid_from: validFrom,
      valid_to: validTo,
      status,
      hubspot_id: hs,
    });
  }

  // --- Nákupné ceny (jeden záznam HubSpotu môže patriť viacerým zmluvám) ---
  const purchaseDeals: Record<string, string[]> = {};
  for (const [d, edges] of Object.entries(A.dealPurchasePrice)) for (const e of edges) (purchaseDeals[e.to] ??= []).push(d);
  for (const [hs, p] of Object.entries(O.purchasePrices)) {
    const productCode = txt(p.produkt_nakupu);
    const year = firstInt(p.obdobie_produktu);
    const pricedOn = toDate(p.datum_nakupnej_ceny);
    const price = num(p.cena_obchod);
    if (!productCode || !year || !pricedOn || price === null) {
      note('contract_purchase', hs, 'chýba produkt, obdobie, dátum nákupu alebo cena obchod');
      continue;
    }
    const deals = (purchaseDeals[hs] ?? []).filter((d) => contractIds[d]);
    if (!deals.length) note('contract_purchase', hs, 'žiadny jej deal nemá zmluvu vo vzorke');
    for (const d of deals) {
      insert('contract_purchase', {
        contract_id: contractIds[d],
        product_code: productCode,
        delivery_year: year,
        priced_on: pricedOn,
        price_eur_mwh: price,
        hubspot_id: hs,
      });
    }
  }

  // --- Výstupy ---
  const total = ORDER.reduce((n, t) => n + manifest[t].length, 0);
  const reasons = findings.reduce<Record<string, number>>((acc, f) => {
    const k = `${f.table}: ${f.reason.replace(/\d{3,}/g, '…').replace(/„.*“/, '„…“')}`;
    acc[k] = (acc[k] ?? 0) + 1;
    return acc;
  }, {});
  const syncRunId = randomUUID();
  const fullManifest = { generatedAt: new Date().toISOString(), source: SOURCE, syncRunId, tables: manifest };

  const load = [
    '-- Vzorka pre prototyp (modul 2, krok 2). Iba Neon vetva dev. Obsahuje osobné údaje – nepatrí do gitu.',
    `-- Vygenerované ${fullManifest.generatedAt}, ${total} riadkov. Zmazanie: vzorka-delete.sql`,
    '\\set ON_ERROR_STOP on',
    'BEGIN;',
    `DO $$ BEGIN IF EXISTS (SELECT 1 FROM sync_run WHERE source = '${SOURCE}') THEN RAISE EXCEPTION 'Vzorka už je nahratá (sync_run ${SOURCE}).'; END IF; END $$;`,
    `INSERT INTO sync_run (id, source) VALUES ('${syncRunId}', '${SOURCE}');`,
    ...ORDER.flatMap((t) => [`-- ${t}: ${manifest[t].length}`, ...statements[t]]),
    `UPDATE sync_run SET finished_at = now(), records_in = ${total}, errors = ${lit(JSON.stringify(reasons))}::jsonb WHERE id = '${syncRunId}';`,
    'COMMIT;',
    '',
  ];
  writeFileSync(join(outDir, 'vzorka-load.sql'), load.join('\n'));
  writeFileSync(join(outDir, 'vzorka-manifest.json'), JSON.stringify(fullManifest, null, 1));

  const uuidArray = (ids: string[]) => `'{${ids.join(',')}}'::uuid[]`;
  const allIds = ORDER.flatMap((t) => manifest[t]);
  const del = [
    '-- Zmazanie vzorky prototypu podľa manifestu. Iba Neon vetva dev.',
    `-- Manifest z ${fullManifest.generatedAt}, ${total} riadkov.`,
    '\\set ON_ERROR_STOP on',
    'BEGIN;',
    ...[...ORDER].reverse().map((t) => `DELETE FROM ${t} WHERE id = ANY(${uuidArray(manifest[t])});`),
    `DELETE FROM audit_log WHERE record_id = ANY(${uuidArray(allIds)});`,
    `DELETE FROM sync_run WHERE id = '${syncRunId}';`,
    'COMMIT;',
    '',
  ];
  writeFileSync(join(outDir, 'vzorka-delete.sql'), del.join('\n'));

  const md = [
    '# Nahratie vzorky – zistenia',
    '',
    `Vygenerované ${new Date().toLocaleString('sk-SK', { timeZone: 'Europe/Bratislava' })}. Iba HubSpot ID, bez mien.`,
    '',
    '## Riadky po tabuľkách',
    '',
    '| Tabuľka | Riadkov |',
    '| --- | --- |',
    ...ORDER.map((t) => `| ${t} | ${manifest[t].length} |`),
    `| **spolu** | **${total}** |`,
    '',
    '## Zistenia podľa dôvodu',
    '',
    '| Dôvod | Počet |',
    '| --- | --- |',
    ...Object.entries(reasons).sort((a, b) => b[1] - a[1]).map(([k, n]) => `| ${k} | ${n} |`),
    '',
    '## Všetky zistenia',
    '',
    '| Tabuľka | HubSpot ID | Dôvod |',
    '| --- | --- | --- |',
    ...findings.map((f) => `| ${f.table} | ${f.hubspotId} | ${f.reason} |`),
    '',
  ];
  writeFileSync(join(outDir, 'nahratie-zistenia.md'), md.join('\n'));

  console.log(`Riadky: ${ORDER.map((t) => `${t} ${manifest[t].length}`).join(', ')}`);
  console.log(`Spolu ${total} riadkov, zistení ${findings.length}.`);
  console.log('Výstup: exports/prototyp/vzorka-load.sql, vzorka-manifest.json, vzorka-delete.sql, nahratie-zistenia.md');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
