// Zber štruktúry a počtov z HubSpotu do exports/inventar/raw/ (mimo gitu).
// Záznamy zákazníkov sa nesťahujú: počty idú cez search s limitom 1 (berie sa iba `total`),
// asociácie cez dávkové čítanie, z ktorého sa ukladajú iba štatistiky, nie ID.
// Každá sekcia sa ukladá zvlášť; pri opakovanom behu sa hotové sekcie preskočia (okrem --refresh).

import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { HubSpotClient, HubSpotError } from './client.ts';

export const PORTAL_ID = 5964726;

export type ObjectDef = { key: string; type: string; label: string };

export const OBJECTS: ObjectDef[] = [
  { key: 'companies', type: 'companies', label: 'Firmy' },
  { key: 'contacts', type: 'contacts', label: 'Kontakty' },
  { key: 'deals', type: 'deals', label: 'Dealy' },
  { key: 'tickets', type: 'tickets', label: 'Tickety' },
  { key: 'oom', type: '2-16666415', label: 'OOM' },
  { key: 'zmluvne_ceny', type: '2-16395301', label: 'Zmluvné ceny' },
  { key: 'nakupne_ceny', type: '2-22997964', label: 'Nákupné ceny' },
];

// Produkty a line items sa inventarizujú zvlášť (sekcia products), bez počtov asociácií.
export const PRODUCT_OBJECTS: ObjectDef[] = [
  { key: 'products', type: 'products', label: 'Produkty' },
  { key: 'line_items', type: 'line_items', label: 'Line items' },
];

// Najviac toľko asociácií sa počíta na jeden záznam; nad tým sa záznam označí ako „500+“.
export const ASSOC_LIMIT = 500;
const ASSOC_BATCH_SIZE = 1000;

export const ASSOC_BUCKETS = [
  { label: '0', max: 0 },
  { label: '1', max: 1 },
  { label: '2–5', max: 5 },
  { label: '6–10', max: 10 },
  { label: '11–50', max: 50 },
  { label: '51–100', max: 100 },
  { label: '101–500', max: ASSOC_LIMIT },
] as const;
export const ASSOC_OVER_LIMIT = `${ASSOC_LIMIT}+`;

const PIPELINE_PROPS: Record<string, { pipeline: string; stage: string }> = {
  deals: { pipeline: 'pipeline', stage: 'dealstage' },
};
const DEFAULT_PIPELINE_PROPS = { pipeline: 'hs_pipeline', stage: 'hs_pipeline_stage' };

export const SECTIONS = [
  'schemas',
  'counts',
  'properties',
  'associationTypes',
  'associationCounts',
  'pipelines',
  'workflows',
  'marketingEmails',
  'users',
  'sequences',
  'quotes',
  'forms',
  'subscriptions',
  'products',
  'formulas',
] as const;

export type Section = (typeof SECTIONS)[number];

export type Failed = { error: string; status: number };

type Ctx = { client: HubSpotClient; root: string; refresh: boolean };

type Filter = { propertyName: string; operator: string; value?: string };

type Page<T> = { results: T[]; paging?: { next?: { after: string } } };

// ---------- úložisko surových dát ----------

const rawDir = (root: string) => join(root, 'exports', 'inventar', 'raw');

export function loadRaw<T>(root: string, name: string): T | undefined {
  const file = join(rawDir(root), `${name}.json`);
  return existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as T) : undefined;
}

function saveRaw(root: string, name: string, data: unknown) {
  mkdirSync(rawDir(root), { recursive: true });
  writeFileSync(join(rawDir(root), `${name}.json`), `${JSON.stringify(data, null, 2)}\n`);
}

export const isFailed = (value: unknown): value is Failed =>
  typeof value === 'object' && value !== null && 'error' in value && 'status' in value;

// Spustí krok, ak ešte nie je uložený. Chyba HubSpotu (napr. chýbajúci scope) sa uloží ako Failed
// a pri ďalšom behu sa krok skúsi znova; iné chyby zastavia beh.
async function cached<T>(ctx: Ctx, name: string, fn: () => Promise<T>): Promise<T | Failed> {
  if (!ctx.refresh) {
    const hit = loadRaw<T | Failed>(ctx.root, name);
    if (hit !== undefined && !isFailed(hit)) {
      console.log(`  ${name}: už uložené, preskakujem`);
      return hit;
    }
  }
  console.log(`  ${name}: zbieram…`);
  try {
    const data = await fn();
    saveRaw(ctx.root, name, data);
    return data;
  } catch (err) {
    if (!(err instanceof HubSpotError)) throw err;
    console.warn(`  ${name}: CHYBA ${err.message}`);
    const failed: Failed = { error: err.message, status: err.status };
    saveRaw(ctx.root, name, failed);
    return failed;
  }
}

// ---------- pomocné volania ----------

async function getAll<T>(client: HubSpotClient, path: string, query: Record<string, string> = {}, limit = 100) {
  const out: T[] = [];
  let after: string | undefined;
  do {
    const page = await client.get<Page<T>>(path, { ...query, limit, after });
    out.push(...page.results);
    after = page.paging?.next?.after;
  } while (after);
  return out;
}

async function countRecords(client: HubSpotClient, objectType: string, filters: Filter[] = []) {
  const res = await client.post<{ total: number }>(`/crm/v3/objects/${objectType}/search`, {
    filterGroups: filters.length ? [{ filters }] : [],
    properties: ['hs_object_id'],
    limit: 1,
  });
  return res.total;
}

// Počet pre vlastnosť, ktorá nemusí byť vyhľadávateľná: pri chybe 400 vráti null.
async function countOrNull(client: HubSpotClient, objectType: string, filters: Filter[]) {
  try {
    return await countRecords(client, objectType, filters);
  } catch (err) {
    if (err instanceof HubSpotError && err.status === 400) return null;
    throw err;
  }
}

// ---------- sekcie ----------

async function collectSchemas(ctx: Ctx) {
  await cached(ctx, 'schemas', async () => {
    const res = await ctx.client.get<{ results: Record<string, unknown>[] }>('/crm/v3/schemas');
    return res.results.map((s) => ({
      objectTypeId: s.objectTypeId,
      name: s.name,
      labels: s.labels,
      primaryDisplayProperty: s.primaryDisplayProperty,
      secondaryDisplayProperties: s.secondaryDisplayProperties,
      requiredProperties: s.requiredProperties,
      searchableProperties: s.searchableProperties,
      createdAt: s.createdAt,
    }));
  });
}

export type Counts = Record<string, number | null> & { contactsWithCompany: number; contactsWithoutCompany: number };

async function collectCounts(ctx: Ctx) {
  await cached(ctx, 'counts', async () => {
    const counts: Record<string, number | null> = {};
    for (const obj of OBJECTS) counts[obj.key] = await countOrNull(ctx.client, obj.type, []);
    counts.contactsWithCompany = await countRecords(ctx.client, 'contacts', [
      { propertyName: 'associatedcompanyid', operator: 'HAS_PROPERTY' },
    ]);
    counts.contactsWithoutCompany = await countRecords(ctx.client, 'contacts', [
      { propertyName: 'associatedcompanyid', operator: 'NOT_HAS_PROPERTY' },
    ]);
    return counts as Counts;
  });
}

export type PropertyInfo = {
  name: string;
  label: string;
  type: string;
  fieldType: string;
  groupName: string;
  description: string;
  hubspotDefined: boolean;
  calculated: boolean;
  hasUniqueValue: boolean;
  options: { label: string; value: string; hidden: boolean }[];
  filled: number | null;
};

async function collectProperties(ctx: Ctx, objects: ObjectDef[]) {
  for (const obj of objects) {
    await cached(ctx, `properties-${obj.key}`, async () => {
      const res = await ctx.client.get<{ results: Record<string, any>[] }>(`/crm/v3/properties/${obj.type}`);
      const props: PropertyInfo[] = [];
      for (const [i, p] of res.results.entries()) {
        if (i > 0 && i % 50 === 0) console.log(`    ${obj.label}: ${i}/${res.results.length} vlastností`);
        props.push({
          name: p.name,
          label: p.label,
          type: p.type,
          fieldType: p.fieldType,
          groupName: p.groupName,
          description: p.description ?? '',
          hubspotDefined: Boolean(p.hubspotDefined),
          calculated: Boolean(p.calculated),
          hasUniqueValue: Boolean(p.hasUniqueValue),
          options: (p.options ?? []).map((o: any) => ({ label: o.label, value: o.value, hidden: Boolean(o.hidden) })),
          filled: await countOrNull(ctx.client, obj.type, [{ propertyName: p.name, operator: 'HAS_PROPERTY' }]),
        });
      }
      return props;
    });
  }
}

export type ProductsRaw = {
  productsTotal: number | null;
  lineItemsTotal: number | null;
  products: {
    id: string;
    name: string;
    sku: string;
    price: string;
    productType: string;
    billingFrequency: string;
    billingPeriod: string;
    description: string;
    createdAt: string;
    lineItems: number | null;
  }[];
};

// Katalóg produktov (nie sú to osobné údaje) + koľko line items odkazuje na každý produkt.
async function collectProducts(ctx: Ctx) {
  await collectProperties(ctx, PRODUCT_OBJECTS);
  await cached(ctx, 'products', async (): Promise<ProductsRaw> => {
    const props = 'name,hs_sku,price,hs_product_type,recurringbillingfrequency,hs_recurring_billing_period,description,createdate';
    const products = await getAll<{ id: string; properties: Record<string, string | null> }>(
      ctx.client,
      '/crm/v3/objects/products',
      { properties: props, archived: 'false' },
    );
    const out: ProductsRaw['products'] = [];
    for (const p of products) {
      out.push({
        id: p.id,
        name: p.properties.name ?? '',
        sku: p.properties.hs_sku ?? '',
        price: p.properties.price ?? '',
        productType: p.properties.hs_product_type ?? '',
        billingFrequency: p.properties.recurringbillingfrequency ?? '',
        billingPeriod: p.properties.hs_recurring_billing_period ?? '',
        description: (p.properties.description ?? '').slice(0, 200),
        createdAt: (p.properties.createdate ?? '').slice(0, 10),
        lineItems: await countOrNull(ctx.client, 'line_items', [
          { propertyName: 'hs_product_id', operator: 'EQ', value: p.id },
        ]),
      });
    }
    return {
      productsTotal: await countOrNull(ctx.client, 'products', []),
      lineItemsTotal: await countOrNull(ctx.client, 'line_items', []),
      products: out,
    };
  });
}

export type FormulaInfo = {
  object: string;
  name: string;
  label: string;
  type: string;
  fieldType: string;
  hubspotDefined: boolean;
  formula: string | null;
  extra: Record<string, unknown>;
};

// Vlastnosti, ktoré HubSpot počíta (calculation_*, rollupy, skóre). Vzorec vracia API v `calculationFormula`;
// ostatné neštandardné kľúče sa uložia do `extra`, aby sme videli aj definíciu rollupov, ak ju API vráti.
const STANDARD_PROPERTY_KEYS = new Set([
  'name', 'label', 'type', 'fieldType', 'groupName', 'description', 'hubspotDefined', 'calculated',
  'hasUniqueValue', 'options', 'calculationFormula', 'createdAt', 'updatedAt', 'archived', 'displayOrder',
  'formField', 'hidden', 'modificationMetadata', 'externalOptions', 'dataSensitivity', 'showCurrencySymbol',
  'createdUserId', 'updatedUserId', 'referencedObjectType', 'sensitiveDataCategories',
]);

async function collectFormulas(ctx: Ctx) {
  await cached(ctx, 'formulas', async () => {
    const out: FormulaInfo[] = [];
    for (const obj of [...OBJECTS, ...PRODUCT_OBJECTS]) {
      const res = await ctx.client.get<{ results: Record<string, any>[] }>(`/crm/v3/properties/${obj.type}`);
      for (const p of res.results) {
        const isCalculated = p.calculated || String(p.fieldType).startsWith('calculation_') || p.calculationFormula;
        if (!isCalculated) continue;
        out.push({
          object: obj.key,
          name: p.name,
          label: p.label,
          type: p.type,
          fieldType: p.fieldType,
          hubspotDefined: Boolean(p.hubspotDefined),
          formula: p.calculationFormula ?? null,
          extra: Object.fromEntries(Object.entries(p).filter(([k]) => !STANDARD_PROPERTY_KEYS.has(k))),
        });
      }
    }
    return out;
  });
}

export type AssociationTypes = { from: string; to: string; types: { category: string; typeId: number; label: string | null }[] }[];

async function collectAssociationTypes(ctx: Ctx) {
  return cached(ctx, 'associationTypes', async () => {
    const out: AssociationTypes = [];
    for (const from of OBJECTS) {
      for (const to of OBJECTS) {
        if (from.key === to.key) continue;
        try {
          const res = await ctx.client.get<{ results: AssociationTypes[number]['types'] }>(
            `/crm/v4/associations/${from.type}/${to.type}/labels`,
          );
          out.push({ from: from.key, to: to.key, types: res.results });
        } catch (err) {
          if (!(err instanceof HubSpotError)) throw err;
          out.push({ from: from.key, to: to.key, types: [] });
        }
      }
    }
    return out;
  });
}

async function listIds(ctx: Ctx, obj: ObjectDef): Promise<string[]> {
  // ID sa držia iba v pamäti, na disk sa neukladajú.
  const records = await getAll<{ id: string }>(ctx.client, `/crm/v3/objects/${obj.type}`, {
    properties: 'hs_object_id',
    archived: 'false',
  });
  return records.map((r) => r.id);
}

export type AssociationStats = {
  from: string;
  to: string;
  records: number;
  buckets: Record<string, number>;
  max: number;
  maxIsCapped: boolean;
  average: number;
  totalAssociations: number;
  byLabel: Record<string, number>;
};

type BatchReadResult = {
  results: {
    from: { id: string };
    to: { toObjectId: string; associationTypes: { category: string; typeId: number; label: string | null }[] }[];
    paging?: { next?: { after: string } };
  }[];
};

async function associationStats(ctx: Ctx, from: ObjectDef, to: ObjectDef, ids: string[]): Promise<AssociationStats> {
  const perRecord = new Map<string, number>();
  const capped = new Set<string>();
  const byLabel: Record<string, number> = {};

  let pending = ids.map((id) => ({ id, after: undefined as string | undefined }));
  while (pending.length) {
    const next: typeof pending = [];
    for (let i = 0; i < pending.length; i += ASSOC_BATCH_SIZE) {
      const chunk = pending.slice(i, i + ASSOC_BATCH_SIZE);
      const res = await ctx.client.post<BatchReadResult>(`/crm/v4/associations/${from.type}/${to.type}/batch/read`, {
        inputs: chunk.map(({ id, after }) => (after ? { id, after } : { id })),
      });
      for (const r of res.results) {
        const count = (perRecord.get(r.from.id) ?? 0) + r.to.length;
        perRecord.set(r.from.id, count);
        for (const t of r.to) {
          for (const at of t.associationTypes) {
            const key = at.label ?? `(bez labelu, typ ${at.typeId})`;
            byLabel[key] = (byLabel[key] ?? 0) + 1;
          }
        }
        const after = r.paging?.next?.after;
        if (after && count < ASSOC_LIMIT) next.push({ id: r.from.id, after });
        else if (after) capped.add(r.from.id);
      }
    }
    pending = next;
  }

  const buckets: Record<string, number> = Object.fromEntries(
    [...ASSOC_BUCKETS.map((b) => b.label), ASSOC_OVER_LIMIT].map((l) => [l, 0]),
  );
  let max = 0;
  let total = 0;
  for (const id of ids) {
    const n = Math.min(perRecord.get(id) ?? 0, ASSOC_LIMIT);
    total += n;
    max = Math.max(max, n);
    const bucket = capped.has(id) ? ASSOC_OVER_LIMIT : ASSOC_BUCKETS.find((b) => n <= b.max)!.label;
    buckets[bucket]++;
  }

  return {
    from: from.key,
    to: to.key,
    records: ids.length,
    buckets,
    max,
    maxIsCapped: capped.size > 0,
    average: ids.length ? Math.round((total / ids.length) * 100) / 100 : 0,
    totalAssociations: total,
    byLabel,
  };
}

async function collectAssociationCounts(ctx: Ctx, types: AssociationTypes | Failed) {
  if (isFailed(types)) {
    console.warn('  associationCounts: preskakujem, chýbajú typy asociácií');
    return;
  }
  const byKey = new Map(OBJECTS.map((o) => [o.key, o]));
  const idCache = new Map<string, string[]>();
  for (const pair of types.filter((p) => p.types.length > 0)) {
    const from = byKey.get(pair.from)!;
    const to = byKey.get(pair.to)!;
    await cached(ctx, `associations-${from.key}-${to.key}`, async () => {
      if (!idCache.has(from.key)) idCache.set(from.key, await listIds(ctx, from));
      return associationStats(ctx, from, to, idCache.get(from.key)!);
    });
  }
}

export type PipelineInfo = {
  object: string;
  id: string;
  label: string;
  displayOrder: number;
  total: number | null;
  stages: { id: string; label: string; displayOrder: number; metadata: Record<string, string>; count: number | null }[];
};

async function collectPipelines(ctx: Ctx) {
  await cached(ctx, 'pipelines', async () => {
    const out: PipelineInfo[] = [];
    for (const obj of OBJECTS) {
      let pipelines: Record<string, any>[];
      try {
        pipelines = (await ctx.client.get<{ results: Record<string, any>[] }>(`/crm/v3/pipelines/${obj.type}`)).results;
      } catch (err) {
        if (!(err instanceof HubSpotError) || err.status >= 500) throw err;
        continue; // objekt nemá pipelines
      }
      const props = PIPELINE_PROPS[obj.key] ?? DEFAULT_PIPELINE_PROPS;
      for (const p of pipelines) {
        const inPipeline = { propertyName: props.pipeline, operator: 'EQ', value: p.id };
        const stages = [];
        for (const s of p.stages ?? []) {
          stages.push({
            id: s.id,
            label: s.label,
            displayOrder: s.displayOrder,
            metadata: s.metadata ?? {},
            count: await countOrNull(ctx.client, obj.type, [
              inPipeline,
              { propertyName: props.stage, operator: 'EQ', value: s.id },
            ]),
          });
        }
        out.push({
          object: obj.key,
          id: p.id,
          label: p.label,
          displayOrder: p.displayOrder,
          total: await countOrNull(ctx.client, obj.type, [inPipeline]),
          stages: stages.sort((a, b) => a.displayOrder - b.displayOrder),
        });
      }
    }
    return out;
  });
}

async function collectWorkflows(ctx: Ctx) {
  // Plné definície (môžu obsahovať e-maily a texty) ostávajú iba v exports/.
  await cached(ctx, 'workflows', async () => {
    const list = await getAll<{ id: string }>(ctx.client, '/automation/v4/flows');
    const details = [];
    for (const flow of list) details.push(await ctx.client.get<Record<string, unknown>>(`/automation/v4/flows/${flow.id}`));
    return details;
  });
}

async function collectMarketingEmails(ctx: Ctx) {
  await cached(ctx, 'marketingEmails', async () => {
    const emails = await getAll<Record<string, any>>(ctx.client, '/marketing/v3/emails');
    return emails.map((e) => ({
      id: e.id,
      name: e.name,
      subject: e.subject,
      type: e.type,
      state: e.state,
      archived: e.archived,
      updatedAt: e.updatedAt,
    }));
  });
}

export type UsersRaw = {
  owners: { id: string; userId?: number; firstName?: string; lastName?: string; archived: boolean; teams?: { id: string; name: string; primary: boolean }[] }[];
  users: { id: string; roleIds?: string[]; roleId?: string; primaryTeamId?: string; superAdmin?: boolean }[];
  roles: { id: string; name: string }[];
  teams: { id: string; name: string; userIds?: string[] }[];
  teamsError?: string;
};

// Tímy vyžadujú scope settings.users.teams.read. Bez neho sa názvy tímov vezmú z vlastníkov (bez počtu členov).
async function getTeams(ctx: Ctx, owners: UsersRaw['owners']): Promise<Pick<UsersRaw, 'teams' | 'teamsError'>> {
  try {
    return { teams: (await ctx.client.get<{ results: UsersRaw['teams'] }>('/settings/v3/users/teams')).results };
  } catch (err) {
    if (!(err instanceof HubSpotError) || err.status >= 500) throw err;
    console.warn(`  users: tímy sa nenačítali (${err.status}), beriem ich z vlastníkov`);
    const teams = new Map(owners.flatMap((o) => o.teams ?? []).map((t) => [t.id, { id: t.id, name: t.name }]));
    return { teams: [...teams.values()], teamsError: err.message };
  }
}

async function collectUsers(ctx: Ctx) {
  return cached(ctx, 'users', async (): Promise<UsersRaw> => {
    const owners = [
      ...(await getAll<UsersRaw['owners'][number]>(ctx.client, '/crm/v3/owners', { archived: 'false' })),
      ...(await getAll<UsersRaw['owners'][number]>(ctx.client, '/crm/v3/owners', { archived: 'true' })),
    ];
    return {
      owners,
      users: await getAll(ctx.client, '/settings/v3/users'),
      roles: (await ctx.client.get<{ results: UsersRaw['roles'] }>('/settings/v3/users/roles')).results,
      ...(await getTeams(ctx, owners)),
    };
  });
}

async function collectSequences(ctx: Ctx, users: UsersRaw | Failed | undefined) {
  await cached(ctx, 'sequences', async () => {
    if (!users || isFailed(users)) throw new HubSpotError(0, '/automation/v4/sequences', 'chýbajú používatelia (sekcia users)');
    const byId = new Map<string, Record<string, unknown>>();
    for (const owner of users.owners.filter((o) => o.userId && !o.archived)) {
      const list = await getAll<Record<string, any>>(ctx.client, '/automation/v4/sequences', { userId: String(owner.userId) });
      for (const s of list) byId.set(s.id, { id: s.id, name: s.name, createdAt: s.createdAt, updatedAt: s.updatedAt, userId: owner.userId });
    }
    return [...byId.values()];
  });
}

async function collectQuotes(ctx: Ctx) {
  await cached(ctx, 'quotes', async () => {
    const total = await countOrNull(ctx.client, 'quotes', []);
    let templates: unknown;
    try {
      templates = await getAll(ctx.client, '/crm/v3/objects/quote_template', { properties: 'hs_name,hs_active' });
    } catch (err) {
      if (!(err instanceof HubSpotError)) throw err;
      templates = { error: err.message, status: err.status } satisfies Failed;
    }
    return { total, templates };
  });
}

async function collectForms(ctx: Ctx) {
  await cached(ctx, 'forms', async () => {
    const forms = await getAll<Record<string, any>>(ctx.client, '/marketing/v3/forms', {}, 50);
    return forms.map((f) => ({
      id: f.id,
      name: f.name,
      formType: f.formType,
      archived: f.archived,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
      fields: (f.fieldGroups ?? []).flatMap((g: any) =>
        (g.fields ?? []).map((field: any) => ({
          name: field.name,
          label: field.label,
          fieldType: field.fieldType,
          objectTypeId: field.objectTypeId,
          required: Boolean(field.required),
          hidden: Boolean(field.hidden),
        })),
      ),
    }));
  });
}

async function collectSubscriptions(ctx: Ctx) {
  await cached(ctx, 'subscriptions', async () => {
    const res = await ctx.client.get<{ subscriptionDefinitions: Record<string, any>[] }>(
      '/communication-preferences/v3/definitions',
    );
    const definitions = [];
    for (const d of res.subscriptionDefinitions) {
      definitions.push({
        id: d.id,
        name: d.name,
        description: d.description,
        isActive: d.isActive,
        isDefault: d.isDefault,
        isInternal: d.isInternal,
        optedOut: await countOrNull(ctx.client, 'contacts', [
          { propertyName: `hs_email_optout_${d.id}`, operator: 'EQ', value: 'true' },
        ]),
      });
    }
    return {
      contactsTotal: await countRecords(ctx.client, 'contacts'),
      marketable: await countOrNull(ctx.client, 'contacts', [
        { propertyName: 'hs_marketable_status', operator: 'EQ', value: 'true' },
      ]),
      globalOptOut: await countOrNull(ctx.client, 'contacts', [
        { propertyName: 'hs_email_optout', operator: 'EQ', value: 'true' },
      ]),
      definitions,
    };
  });
}

// ---------- hlavný beh ----------

export async function collect(client: HubSpotClient, root: string, opts: { refresh: boolean; only?: Section[] }) {
  const ctx: Ctx = { client, root, refresh: opts.refresh };
  const run = (s: Section) => !opts.only || opts.only.includes(s);

  if (run('schemas')) await collectSchemas(ctx);
  if (run('counts')) await collectCounts(ctx);
  if (run('properties')) await collectProperties(ctx, OBJECTS);
  const types = run('associationTypes') || run('associationCounts') ? await collectAssociationTypes(ctx) : undefined;
  if (run('associationCounts') && types) await collectAssociationCounts(ctx, types);
  if (run('pipelines')) await collectPipelines(ctx);
  if (run('workflows')) await collectWorkflows(ctx);
  if (run('marketingEmails')) await collectMarketingEmails(ctx);
  const users = run('users') || run('sequences') ? await collectUsers(ctx) : undefined;
  if (run('sequences')) await collectSequences(ctx, users);
  if (run('quotes')) await collectQuotes(ctx);
  if (run('forms')) await collectForms(ctx);
  if (run('subscriptions')) await collectSubscriptions(ctx);
  if (run('products')) await collectProducts(ctx);
  if (run('formulas')) await collectFormulas(ctx);
}
