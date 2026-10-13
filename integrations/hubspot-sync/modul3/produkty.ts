// Modul 3: inventár produktov z HubSpotu – iba čítanie, bez osobných údajov.
// 41 produktov (názov, SKU, cena, popis, počet line items) a kódy produktu v Zmluvných cenách
// (vlastnosť `produkt`) s počtom cien: všetky, dnes platné, podľa typu OOM.
// Výstup: exports/modul3-produkty/ (JSON + prehľad .md). Do konzoly iba počty.
//
// Spustenie: cd ~/projects/greenlogy/crm-core/integrations/hubspot-sync && node modul3/produkty.ts

import { mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { HubSpotClient, HubSpotError, loadToken } from '../inventory/client.ts';

const REPO = resolve(import.meta.dirname, '../../..');
const OUT = join(REPO, 'exports/modul3-produkty');
const ZMLUVNE_CENY = '2-16395301';

type Filter = { propertyName: string; operator: string; value?: string };
type Page<T> = { results: T[]; paging?: { next?: { after: string } } };
type Option = { label: string; value: string; hidden?: boolean; displayOrder?: number };

const client = new HubSpotClient(loadToken(REPO));

async function count(objectType: string, filters: Filter[]): Promise<number | null> {
  try {
    const res = await client.post<{ total: number }>(`/crm/v3/objects/${objectType}/search`, {
      filterGroups: [{ filters }],
      properties: ['hs_object_id'],
      limit: 1,
    });
    return res.total;
  } catch (err) {
    if (err instanceof HubSpotError && err.status === 400) return null;
    throw err;
  }
}

async function main() {
  const today = new Date().toISOString().slice(0, 10);
  const todayMs = String(Date.parse(`${today}T00:00:00Z`));

  // 1. Produkty
  const props = 'name,hs_sku,price,hs_product_type,recurringbillingfrequency,hs_recurring_billing_period,description,createdate,hs_lastmodifieddate';
  const products: { id: string; properties: Record<string, string | null> }[] = [];
  let after: string | undefined;
  do {
    const page = await client.get<Page<(typeof products)[number]>>('/crm/v3/objects/products', {
      limit: 100, after, properties: props, archived: false,
    });
    products.push(...page.results);
    after = page.paging?.next?.after;
  } while (after);

  const productRows = [];
  for (const p of products) {
    productRows.push({
      id: p.id,
      name: p.properties.name ?? '',
      sku: p.properties.hs_sku ?? '',
      price: p.properties.price ?? '',
      productType: p.properties.hs_product_type ?? '',
      billingFrequency: p.properties.recurringbillingfrequency ?? '',
      description: p.properties.description ?? '',
      createdAt: (p.properties.createdate ?? '').slice(0, 10),
      modifiedAt: (p.properties.hs_lastmodifieddate ?? '').slice(0, 10),
      lineItems: await count('line_items', [{ propertyName: 'hs_product_id', operator: 'EQ', value: p.id }]),
    });
  }
  console.log(`Produkty: ${productRows.length}`);

  // 2. Kódy produktu v Zmluvných cenách
  const prop = await client.get<{ options: Option[] }>(`/crm/v3/properties/${ZMLUVNE_CENY}/produkt`);
  const typOom = await client.get<{ options: Option[] }>(`/crm/v3/properties/${ZMLUVNE_CENY}/typ_oom`);
  const codeRows = [];
  for (const o of prop.options) {
    const eq: Filter = { propertyName: 'produkt', operator: 'EQ', value: o.value };
    const validTo = await count(ZMLUVNE_CENY, [eq, { propertyName: 'ucinnost_ceny_do', operator: 'GTE', value: todayMs }]);
    const openEnded = await count(ZMLUVNE_CENY, [eq, { propertyName: 'ucinnost_ceny_do', operator: 'NOT_HAS_PROPERTY' }]);
    const byTyp: Record<string, number | null> = {};
    for (const t of typOom.options) {
      byTyp[t.label] = await count(ZMLUVNE_CENY, [eq, { propertyName: 'typ_oom', operator: 'EQ', value: t.value }]);
    }
    codeRows.push({
      value: o.value,
      label: o.label,
      hidden: o.hidden ?? false,
      total: await count(ZMLUVNE_CENY, [eq]),
      validToday: validTo === null || openEnded === null ? null : validTo + openEnded,
      byTypOom: byTyp,
    });
  }
  const withoutCode = await count(ZMLUVNE_CENY, [{ propertyName: 'produkt', operator: 'NOT_HAS_PROPERTY' }]);
  const pricesTotal = await count(ZMLUVNE_CENY, []).catch(() => null);
  console.log(`Kódy produktu v zmluvných cenách: ${codeRows.length}, ceny bez kódu: ${withoutCode}`);

  mkdirSync(OUT, { recursive: true });
  const data = { readAt: today, products: productRows, contractPriceCodes: codeRows, contractPricesWithoutCode: withoutCode, contractPricesTotal: pricesTotal };
  writeFileSync(join(OUT, 'hubspot-produkty.json'), JSON.stringify(data, null, 2) + '\n');
  writeFileSync(join(OUT, 'prehlad-produktov.md'), render(data, typOom.options.map((t) => t.label)));
  console.log(`Požiadaviek na HubSpot: ${client.requestCount}. Výstup: exports/modul3-produkty/`);
}

const n = (v: number | null) => (v === null ? '?' : v.toLocaleString('sk-SK'));
const cell = (s: string) => s.replace(/\|/g, '\\|').replace(/\s+/g, ' ').trim();

function render(d: any, typLabels: string[]): string {
  const p = [...d.products].sort((a, b) => (b.lineItems ?? 0) - (a.lineItems ?? 0));
  const c = [...d.contractPriceCodes].sort((a, b) => (b.total ?? 0) - (a.total ?? 0));
  return [
    '# Modul 3 – inventár produktov z HubSpotu',
    '',
    `Načítané ${d.readAt} (iba čítanie, bez osobných údajov). Zdroj: \`integrations/hubspot-sync/modul3/produkty.ts\`.`,
    'Stĺpec „Nový produkt“ vyplní Peter (kód z katalógu modulu 3, alebo „zrušiť“).',
    '',
    `## A. HubSpot produkty (${p.length})`,
    '',
    '| Názov | SKU | Cena | Fakturácia | Line items | Založený | Popis | Nový produkt |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',
    ...p.map((r: any) => `| ${cell(r.name)} | ${cell(r.sku)} | ${cell(r.price)} | ${cell(r.billingFrequency)} | ${n(r.lineItems)} | ${r.createdAt} | ${cell(r.description).slice(0, 80)} | |`),
    '',
    `## B. Kódy produktu v Zmluvných cenách (${c.length})`,
    '',
    `Zmluvných cien spolu: ${n(d.contractPricesTotal)}, bez kódu produktu: ${n(d.contractPricesWithoutCode)}. „Platné dnes“ = účinnosť do ≥ dnes alebo prázdna.`,
    '',
    `| Kód | Skrytý | Cien spolu | Platné dnes | ${typLabels.join(' | ')} | Nový produkt |`,
    `| --- | --- | --- | --- | ${typLabels.map(() => '---').join(' | ')} | --- |`,
    ...c.map((r: any) => `| ${cell(r.label)} | ${r.hidden ? 'áno' : ''} | ${n(r.total)} | ${n(r.validToday)} | ${typLabels.map((t) => n(r.byTypOom[t])).join(' | ')} | |`),
    '',
  ].join('\n');
}

await main();
