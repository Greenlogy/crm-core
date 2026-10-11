// Výber vzorky 40 zákazníkov pre prototyp (modul 2, krok 1). Iba čítanie z HubSpotu.
//
//   cd ~/projects/greenlogy/crm-core/integrations/hubspot-sync
//   npm run sample:select                 # použije uložený index, ak existuje
//   npm run sample:select -- --refresh    # index znova z HubSpotu
//   npm run sample:select -- --seed=7     # iný náhodný výber
//
// Výstup (mimo gitu): exports/prototyp/vzorka-navrh.md, vzorka-data.json, cache/index.json.
// Do terminálu idú iba počty, nikdy mená ani dáta zákazníkov.

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { HubSpotClient, loadToken } from '../inventory/client.ts';
import { PORTAL_ID } from '../inventory/collect.ts';
import {
  associations,
  batchRead,
  listAll,
  OBJ,
  propertyNames,
  stages,
  type Edge,
  type Props,
} from './hubspot.ts';
import {
  CONTRACT_STAGE,
  dealStageLabel as stageLabel,
  deriveOomOwners,
  ENDED_STAGE,
  oomType,
  type Index,
  type OomType,
} from './owners.ts';

const root = resolve(import.meta.dirname, '../../..');
const outDir = join(root, 'exports/prototyp');
const indexFile = join(outDir, 'cache/index.json');
const args = process.argv.slice(2);
const seed = Number(args.find((a) => a.startsWith('--seed='))?.slice(7) ?? 20261011);

type Customer = {
  key: string;
  kind: 'company' | 'contact';
  id: string;
  ooms: Set<string>; // OOM, ktorých je zákazník vlastníkom (pravidlo 1)
  deals: Set<string>;
};

type Group = 'vyrobcovia' | 'ukoncena' | 'viac_firiem' | 'viac_oom' | 'domacnosti' | 'b2b';

const GROUP_LABEL: Record<Group, string> = {
  b2b: 'B2B firmy',
  domacnosti: 'Domácnosti',
  vyrobcovia: 'Výrobcovia',
  viac_oom: 'Firmy s viacerými OOM',
  viac_firiem: 'Kontakty s viacerými firmami',
  ukoncena: 'Ukončená zmluva',
};

type Pick = { key: string; group: Group; complete: boolean; viaContact?: string };

// Deterministický generátor (mulberry32), aby sa výber dal zopakovať.
function rng(s: number) {
  return () => {
    s = (s + 0x6d2b79f5) | 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const random = rng(seed);
function shuffle<T>(list: T[]): T[] {
  const a = [...list].sort();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

async function buildIndex(client: HubSpotClient): Promise<Index> {
  const step = (s: string) => console.log(`  ${s} (požiadaviek doteraz: ${client.requestCount})`);
  const dealStages = await stages(client, OBJ.deals);
  const oomStages = await stages(client, OBJ.oom);
  step('pipelines');

  const oomList = await listAll(client, OBJ.oom, ['hs_pipeline_stage']);
  step(`OOM: ${oomList.length}`);
  const dealList = await listAll(client, OBJ.deals, ['dealstage', 'closedate', 'createdate']);
  step(`dealy: ${dealList.length}`);
  const contactList = await listAll(client, OBJ.contacts, ['hs_object_id']);
  step(`kontakty: ${contactList.length}`);

  const dealIds = dealList.map((d) => d.id);
  const dealCompany = await associations(client, OBJ.deals, OBJ.companies, dealIds);
  const dealContact = await associations(client, OBJ.deals, OBJ.contacts, dealIds);
  const dealOom = await associations(client, OBJ.deals, OBJ.oom, dealIds);
  const contactCompany = await associations(client, OBJ.contacts, OBJ.companies, contactList.map((c) => c.id));
  step('asociácie');

  return {
    builtAt: new Date().toISOString(),
    dealStages,
    oomStages,
    ooms: Object.fromEntries(oomList.map((o) => [o.id, { stage: o.properties.hs_pipeline_stage ?? '' }])),
    deals: Object.fromEntries(
      dealList.map((d) => [
        d.id,
        { stage: d.properties.dealstage ?? '', date: d.properties.closedate ?? d.properties.createdate ?? '' },
      ]),
    ),
    dealCompany,
    dealContact,
    dealOom,
    contactCompany,
  };
}

async function main() {
  const client = new HubSpotClient(loadToken(root));
  const info = await client.tokenInfo();
  if (info.hubId !== PORTAL_ID) throw new Error(`Token nepatrí do portálu ${PORTAL_ID}, výber zastavený.`);
  mkdirSync(join(outDir, 'cache'), { recursive: true });

  let index: Index;
  if (existsSync(indexFile) && !args.includes('--refresh')) {
    index = JSON.parse(readFileSync(indexFile, 'utf8')) as Index;
    console.log(`Index z ${index.builtAt} (pre nové dáta: --refresh)`);
  } else {
    console.log('Načítavam index z HubSpotu:');
    index = await buildIndex(client);
    writeFileSync(indexFile, JSON.stringify(index));
  }

  // --- Odvodenie vlastníka OOM (pravidlo 1 modelu) ---
  const dealStageLabel = (d: string) => stageLabel(index, d);
  const oomInfo = (o: string) => {
    const s = index.oomStages[index.ooms[o]?.stage];
    return { type: oomType(s?.pipeline ?? ''), status: s?.stage ?? '' };
  };

  const customers = new Map<string, Customer>();
  const customer = (key: string): Customer => {
    let c = customers.get(key);
    if (!c) {
      const [kind, id] = key.split(':') as ['company' | 'contact', string];
      c = { key, kind, id, ooms: new Set(), deals: new Set() };
      customers.set(key, c);
    }
    return c;
  };

  const { owners, fromEnded: ownerFromEnded, unowned } = deriveOomOwners(index);
  for (const [o, key] of Object.entries(owners)) customer(key).ooms.add(o);

  // Dealy zákazníka: firma = všetky dealy firmy; domácnosť = dealy kontaktu bez firmy.
  for (const d of Object.keys(index.deals)) {
    const companies = index.dealCompany[d] ?? [];
    if (companies.length) {
      for (const e of companies) customers.get(`company:${e.to}`)?.deals.add(d);
    } else {
      for (const e of index.dealContact[d] ?? []) customers.get(`contact:${e.to}`)?.deals.add(d);
    }
  }

  const ownedTypes = (c: Customer) => [...c.ooms].map(oomInfo);
  const dealOoms = (c: Customer) => new Set([...c.deals].flatMap((d) => (index.dealOom[d] ?? []).map((e) => e.to)));
  const all = [...customers.values()];
  const companiesOnly = all.filter((c) => c.kind === 'company');

  const candidates: Record<string, string[]> = {
    sharing: all.filter((c) => ownedTypes(c).some((o) => o.type === 'sharing')).map((c) => c.key),
    velkoobchod: all.filter((c) => ownedTypes(c).some((o) => o.type === 'velkoobchod')).map((c) => c.key),
    vyrobcovia: all.filter((c) => ownedTypes(c).some((o) => o.type !== 'spotreba' && o.type !== 'neznamy')).map((c) => c.key),
    ukoncena: all
      .filter((c) => c.ooms.size && ownedTypes(c).every((o) => o.status === 'Odídené' || o.status === 'Zrušené'))
      .map((c) => c.key),
    viac_oom: companiesOnly.filter((c) => dealOoms(c).size >= 3).map((c) => c.key),
    domacnosti: all
      .filter((c) => c.kind === 'contact' && ownedTypes(c).some((o) => o.status === 'Aktívne'))
      .map((c) => c.key),
    b2b: companiesOnly
      .filter((c) => ownedTypes(c).some((o) => o.status === 'Aktívne' && o.type === 'spotreba'))
      .map((c) => c.key),
  };
  const multiCompanyContacts = Object.entries(index.contactCompany)
    .filter(([, edges]) => edges.filter((e) => customers.has(`company:${e.to}`)).length >= 2)
    .map(([contact]) => contact);

  // --- Úplnosť: zákazník má OOM, deal v stave zmluvy alebo ukončený a aspoň jednu zmluvnú cenu ---
  const dealPrices: Record<string, Edge[]> = {};
  const pricesChecked = new Set<string>();
  async function ensurePrices(dealIds: Iterable<string>) {
    const missing = [...dealIds].filter((d) => !pricesChecked.has(d));
    if (!missing.length) return;
    Object.assign(dealPrices, await associations(client, OBJ.deals, OBJ.contractPrice, missing));
    for (const d of missing) pricesChecked.add(d);
  }
  const isComplete = (key: string) => {
    const c = customers.get(key)!;
    const deals = [...c.deals];
    return (
      c.ooms.size > 0 &&
      deals.some((d) => CONTRACT_STAGE.test(dealStageLabel(d)) || ENDED_STAGE.test(dealStageLabel(d))) &&
      deals.some((d) => (dealPrices[d] ?? []).length > 0)
    );
  };

  const used = new Set<string>();
  const picks: Pick[] = [];
  async function pick(group: Group, keys: string[], n: number) {
    const pool = shuffle(keys.filter((k) => !used.has(k)));
    const chosen: string[] = [];
    const incomplete: string[] = [];
    for (let i = 0; i < pool.length && i < 400 && chosen.length < n; i += 40) {
      const chunk = pool.slice(i, i + 40);
      await ensurePrices(chunk.flatMap((k) => [...customers.get(k)!.deals]));
      for (const k of chunk) {
        if (chosen.length >= n) break;
        (isComplete(k) ? chosen : incomplete).push(k);
      }
    }
    while (chosen.length < n && incomplete.length) chosen.push(incomplete.shift()!);
    for (const k of chosen) {
      used.add(k);
      picks.push({ key: k, group, complete: isComplete(k) });
    }
    return chosen.length;
  }

  // Najprv najvzácnejšie skupiny, aby sa jeden zákazník neocitol v dvoch skupinách.
  await pick('vyrobcovia', candidates.sharing, 1);
  await pick('vyrobcovia', candidates.velkoobchod, 1);
  await pick('vyrobcovia', candidates.vyrobcovia, 4);
  await pick('ukoncena', candidates.ukoncena, 4);

  let viaContacts = 0;
  for (const contact of shuffle(multiCompanyContacts)) {
    if (viaContacts >= 4) break;
    const firms = index.contactCompany[contact]
      .map((e) => `company:${e.to}`)
      .filter((k) => customers.has(k) && !used.has(k))
      .slice(0, 2);
    if (firms.length < 2) continue;
    await ensurePrices(firms.flatMap((k) => [...customers.get(k)!.deals]));
    for (const k of firms) {
      used.add(k);
      picks.push({ key: k, group: 'viac_firiem', complete: isComplete(k), viaContact: contact });
    }
    viaContacts++;
  }

  await pick('viac_oom', candidates.viac_oom, 4);
  await pick('domacnosti', candidates.domacnosti, 10);
  await pick('b2b', candidates.b2b, 12);

  // --- Detail vybraných zákazníkov (všetky vlastnosti) ---
  console.log(`Vybraných ${picks.length} zákazníkov, načítavam detail…`);
  const chosen = picks.map((p) => customers.get(p.key)!);
  const companyIds = chosen.filter((c) => c.kind === 'company').map((c) => c.id);
  const contactCustomerIds = chosen.filter((c) => c.kind === 'contact').map((c) => c.id);

  const companyContacts = await associations(client, OBJ.companies, OBJ.contacts, companyIds);
  const dealIds = new Set(chosen.flatMap((c) => [...c.deals]));
  const oomIds = new Set(chosen.flatMap((c) => [...c.ooms]));
  for (const d of dealIds) for (const e of index.dealOom[d] ?? []) oomIds.add(e.to);
  const contactIds = new Set([
    ...contactCustomerIds,
    ...Object.values(companyContacts).flatMap((edges) => edges.map((e) => e.to)),
    ...picks.flatMap((p) => (p.viaContact ? [p.viaContact] : [])),
  ]);
  for (const d of dealIds) for (const e of index.dealContact[d] ?? []) contactIds.add(e.to);

  await ensurePrices(dealIds);
  const oomPrices = await associations(client, OBJ.oom, OBJ.contractPrice, oomIds);
  const dealPurchases = await associations(client, OBJ.deals, OBJ.purchasePrice, dealIds);
  const priceIds = new Set<string>();
  for (const d of dealIds) for (const e of dealPrices[d] ?? []) priceIds.add(e.to);
  for (const edges of Object.values(oomPrices)) for (const e of edges) priceIds.add(e.to);
  const purchaseIds = new Set(Object.values(dealPurchases).flatMap((edges) => edges.map((e) => e.to)));

  const read = async (type: string, ids: Iterable<string>) => batchRead(client, type, ids, await propertyNames(client, type));
  const objects: Record<string, Record<string, Props>> = {
    companies: await read(OBJ.companies, companyIds),
    contacts: await read(OBJ.contacts, contactIds),
    deals: await read(OBJ.deals, dealIds),
    oom: await read(OBJ.oom, oomIds),
    contractPrices: await read(OBJ.contractPrice, priceIds),
    purchasePrices: await read(OBJ.purchasePrice, purchaseIds),
  };

  const pickEdges = (map: Record<string, Edge[]>, ids: Iterable<string>) =>
    Object.fromEntries([...ids].filter((id) => map[id]).map((id) => [id, map[id]]));

  const summary = picks.map((p) => {
    const c = customers.get(p.key)!;
    const props = c.kind === 'company' ? objects.companies[c.id] : objects.contacts[c.id];
    const name =
      c.kind === 'company'
        ? (props?.name ?? '')
        : `${props?.firstname ?? ''} ${props?.lastname ?? ''}`.trim();
    const types = ownedTypes(c);
    const prices = new Set([
      ...[...c.deals].flatMap((d) => (dealPrices[d] ?? []).map((e) => e.to)),
      ...[...c.ooms].flatMap((o) => (oomPrices[o] ?? []).map((e) => e.to)),
    ]);
    const purchases = new Set([...c.deals].flatMap((d) => (dealPurchases[d] ?? []).map((e) => e.to)));
    const via = p.viaContact ? objects.contacts[p.viaContact] : undefined;
    return {
      group: p.group,
      kind: c.kind,
      hubspotId: c.id,
      name,
      oomByType: Object.fromEntries(
        (['spotreba', 'vyroba', 'sharing', 'velkoobchod', 'neznamy'] as OomType[]).map((t) => [
          t,
          types.filter((o) => o.type === t).length,
        ]),
      ),
      oomByStatus: types.reduce<Record<string, number>>((acc, o) => ((acc[o.status] = (acc[o.status] ?? 0) + 1), acc), {}),
      deals: c.deals.size,
      contractPrices: prices.size,
      purchasePrices: purchases.size,
      complete: p.complete,
      viaContact: p.viaContact
        ? { hubspotId: p.viaContact, name: `${via?.firstname ?? ''} ${via?.lastname ?? ''}`.trim() }
        : undefined,
    };
  });

  const data = {
    generatedAt: new Date().toISOString(),
    seed,
    portal: PORTAL_ID,
    indexBuiltAt: index.builtAt,
    customers: summary,
    stages: { deals: index.dealStages, oom: index.oomStages },
    objects,
    associations: {
      dealCompany: pickEdges(index.dealCompany, dealIds),
      dealContact: pickEdges(index.dealContact, dealIds),
      dealOom: pickEdges(index.dealOom, dealIds),
      dealContractPrice: pickEdges(dealPrices, dealIds),
      dealPurchasePrice: pickEdges(dealPurchases, dealIds),
      oomContractPrice: oomPrices,
      companyContact: companyContacts,
      contactCompany: pickEdges(index.contactCompany, contactIds),
    },
  };
  writeFileSync(join(outDir, 'vzorka-data.json'), JSON.stringify(data, null, 1));

  // --- Návrh na schválenie (markdown) ---
  const order: Group[] = ['b2b', 'domacnosti', 'vyrobcovia', 'viac_oom', 'viac_firiem', 'ukoncena'];
  const oomCell = (s: (typeof summary)[number]) =>
    [
      ['S', s.oomByType.spotreba],
      ['V', s.oomByType.vyroba],
      ['Sh', s.oomByType.sharing],
      ['VO', s.oomByType.velkoobchod],
      ['?', s.oomByType.neznamy],
    ]
      .filter(([, n]) => n)
      .map(([t, n]) => `${t} ${n}`)
      .join(', ') || '–';
  const statusCell = (s: (typeof summary)[number]) =>
    Object.entries(s.oomByStatus).map(([k, n]) => `${k} ${n}`).join(', ') || '–';

  const lines: string[] = [
    '# Návrh vzorky pre prototyp',
    '',
    `Vygenerované ${new Date().toLocaleString('sk-SK', { timeZone: 'Europe/Bratislava' })}, semienko ${seed}, index z ${index.builtAt}.`,
    'Obsahuje osobné údaje – iba v `exports/` (mimo gitu).',
    '',
    'OOM podľa typu: S = spotreba, V = výroba, Sh = sharing, VO = veľkoobchod. „Úplný“ = má OOM, deal v stave zmluvy (alebo ukončený) a zmluvnú cenu.',
    '',
  ];
  for (const g of order) {
    const rows = summary.filter((s) => s.group === g);
    lines.push(`## ${GROUP_LABEL[g]} (${rows.length})`, '');
    lines.push('| # | Zákazník | Typ | HubSpot ID | OOM | Stavy OOM | Dealy | Zmluvné ceny | Nákupné ceny | Úplný | Poznámka |');
    lines.push('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |');
    rows.forEach((s, i) => {
      const note = s.viaContact ? `cez kontakt ${s.viaContact.name} (${s.viaContact.hubspotId})` : '';
      lines.push(
        `| ${i + 1} | ${s.name.replace(/\|/g, '/')} | ${s.kind === 'company' ? 'firma' : 'domácnosť'} | ${s.hubspotId} | ${oomCell(s)} | ${statusCell(s)} | ${s.deals} | ${s.contractPrices} | ${s.purchasePrices} | ${s.complete ? 'áno' : 'nie'} | ${note} |`,
      );
    });
    lines.push('');
  }
  lines.push(
    '## Štatistika výberu',
    '',
    '| Ukazovateľ | Počet |',
    '| --- | --- |',
    `| Zákazníci s aspoň jedným OOM | ${all.filter((c) => c.ooms.size).length} |`,
    `| OOM bez odvoditeľného vlastníka (bez dealu v stave zmluvy alebo ukončeného) | ${unowned} |`,
    `| OOM, ktorých vlastník je odvodený z ukončeného dealu | ${ownerFromEnded} |`,
    ...Object.entries(candidates).map(([k, v]) => `| Kandidáti: ${k} | ${v.length} |`),
    `| Kandidáti: kontakty s ≥ 2 firmami-zákazníkmi | ${multiCompanyContacts.length} |`,
    '',
    '## Záznamy v `vzorka-data.json`',
    '',
    '| Objekt | Počet |',
    '| --- | --- |',
    ...Object.entries(objects).map(([k, v]) => `| ${k} | ${Object.keys(v).length} |`),
    '',
  );
  writeFileSync(join(outDir, 'vzorka-navrh.md'), lines.join('\n'));

  // --- Krátky súhrn do terminálu (iba počty) ---
  const target: Record<Group, number> = { b2b: 12, domacnosti: 10, vyrobcovia: 6, viac_oom: 4, viac_firiem: 8, ukoncena: 4 };
  console.log('Skupiny (vybrané/cieľ, z toho neúplné):');
  for (const g of order) {
    const rows = summary.filter((s) => s.group === g);
    console.log(`  ${GROUP_LABEL[g]}: ${rows.length}/${target[g]}, neúplné ${rows.filter((s) => !s.complete).length}`);
  }
  console.log(`Záznamy: ${Object.entries(objects).map(([k, v]) => `${k} ${Object.keys(v).length}`).join(', ')}`);
  console.log(`OOM bez vlastníka: ${unowned}. Požiadaviek: ${client.requestCount}.`);
  console.log('Výstup: exports/prototyp/vzorka-navrh.md, exports/prototyp/vzorka-data.json');
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
