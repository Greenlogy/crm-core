// Pomocné čítacie funkcie pre výber vzorky: zoznamy, asociácie, hromadné čítanie, pipelines.
// Všetko ide cez HubSpotClient, ktorý povoľuje iba čítanie. Nič sa nevypisuje.

import type { HubSpotClient } from '../inventory/client.ts';

export const OBJ = {
  companies: 'companies',
  contacts: 'contacts',
  deals: 'deals',
  oom: '2-16666415',
  contractPrice: '2-16395301',
  purchasePrice: '2-22997964',
} as const;

export type Props = Record<string, string | null>;
export type Rec = { id: string; properties: Props };
export type Edge = { to: string; typeIds: number[]; labels: string[] };
export type StageInfo = { pipelineId: string; pipeline: string; stage: string };

type Page<T> = { results: T[]; paging?: { next?: { after: string } } };

type AssocResult = {
  from: { id: string };
  to: { toObjectId: number | string; associationTypes: { typeId: number; label: string | null }[] }[];
  paging?: { next?: { after: string } };
};

export async function listAll(client: HubSpotClient, type: string, properties: string[]): Promise<Rec[]> {
  const out: Rec[] = [];
  let after: string | undefined;
  do {
    const page = await client.get<Page<Rec>>(`/crm/v3/objects/${type}`, {
      limit: 100,
      after,
      properties: properties.join(','),
    });
    for (const r of page.results) out.push({ id: r.id, properties: r.properties });
    after = page.paging?.next?.after;
  } while (after);
  return out;
}

// Všetky asociácie pre zoznam ID (v4 batch read, 1 000 ID na požiadavku, so stránkovaním na záznam).
export async function associations(
  client: HubSpotClient,
  from: string,
  to: string,
  ids: Iterable<string>,
): Promise<Record<string, Edge[]>> {
  const map: Record<string, Edge[]> = {};
  let pending = [...new Set(ids)].map((id) => ({ id, after: undefined as string | undefined }));
  while (pending.length) {
    const next: typeof pending = [];
    for (let i = 0; i < pending.length; i += 1000) {
      const chunk = pending.slice(i, i + 1000);
      const res = await client.post<{ results?: AssocResult[] }>(`/crm/v4/associations/${from}/${to}/batch/read`, {
        inputs: chunk.map(({ id, after }) => (after ? { id, after } : { id })),
      });
      for (const r of res.results ?? []) {
        const list = (map[r.from.id] ??= []);
        for (const t of r.to) {
          list.push({
            to: String(t.toObjectId),
            typeIds: t.associationTypes.map((a) => a.typeId),
            labels: t.associationTypes.map((a) => a.label ?? '').filter(Boolean),
          });
        }
        const after = r.paging?.next?.after;
        if (after) next.push({ id: r.from.id, after });
      }
    }
    pending = next;
  }
  return map;
}

export async function propertyNames(client: HubSpotClient, type: string): Promise<string[]> {
  const res = await client.get<{ results: { name: string }[] }>(`/crm/v3/properties/${type}`);
  return res.results.map((p) => p.name);
}

// Hromadné čítanie záznamov so všetkými vlastnosťami (100 záznamov na požiadavku).
export async function batchRead(
  client: HubSpotClient,
  type: string,
  ids: Iterable<string>,
  properties: string[],
): Promise<Record<string, Props>> {
  const out: Record<string, Props> = {};
  const list = [...new Set(ids)];
  for (let i = 0; i < list.length; i += 100) {
    const res = await client.post<{ results: Rec[] }>(`/crm/v3/objects/${type}/batch/read`, {
      inputs: list.slice(i, i + 100).map((id) => ({ id })),
      properties,
    });
    for (const r of res.results) out[r.id] = r.properties;
  }
  return out;
}

export async function stages(client: HubSpotClient, type: string): Promise<Record<string, StageInfo>> {
  const res = await client.get<{ results: { id: string; label: string; stages: { id: string; label: string }[] }[] }>(
    `/crm/v3/pipelines/${type}`,
  );
  const out: Record<string, StageInfo> = {};
  for (const p of res.results) {
    for (const s of p.stages) out[s.id] = { pipelineId: p.id, pipeline: p.label, stage: s.label };
  }
  return out;
}
