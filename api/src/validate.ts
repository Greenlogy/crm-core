// Jednoduchá kontrola tela požiadavky (JSON). Pravidlá CRM stráži databáza; tu iba typy a tvar,
// aby chyba prišla hneď a po slovensky.

import { UUID } from './types';

export class BadRequest extends Error {}

export type Body = Record<string, unknown>;

export async function readBody(req: { json: () => Promise<unknown> }): Promise<Body> {
  const body = await req.json().catch(() => null);
  if (!body || typeof body !== 'object' || Array.isArray(body)) throw new BadRequest('Očakávaný objekt JSON.');
  return body as Body;
}

export function str(b: Body, key: string, label: string, opts: { max?: number; optional?: boolean } = {}): string | undefined {
  const v = b[key];
  if (v === undefined || v === null || v === '') {
    if (opts.optional) return v === undefined ? undefined : '';
    throw new BadRequest(`Chýba: ${label}.`);
  }
  if (typeof v !== 'string') throw new BadRequest(`${label}: očakávaný text.`);
  const t = v.trim();
  if (!opts.optional && t === '') throw new BadRequest(`Chýba: ${label}.`);
  if (t.length > (opts.max ?? 200)) throw new BadRequest(`${label}: najviac ${opts.max ?? 200} znakov.`);
  return t;
}

export function bool(b: Body, key: string, label: string): boolean | undefined {
  const v = b[key];
  if (v === undefined) return undefined;
  if (typeof v !== 'boolean') throw new BadRequest(`${label}: očakávané áno/nie.`);
  return v;
}

export function uuid(b: Body, key: string, label: string, optional = false): string | undefined {
  const v = b[key];
  if (v === undefined || v === null) {
    if (optional) return undefined;
    throw new BadRequest(`Chýba: ${label}.`);
  }
  if (typeof v !== 'string' || !UUID.test(v)) throw new BadRequest(`${label}: neplatný identifikátor.`);
  return v;
}

export function uuids(b: Body, key: string, label: string): string[] | undefined {
  const v = b[key];
  if (v === undefined) return undefined;
  if (!Array.isArray(v) || v.some((x) => typeof x !== 'string' || !UUID.test(x))) {
    throw new BadRequest(`${label}: neplatný zoznam.`);
  }
  return [...new Set(v as string[])];
}

export function oneOf<T extends string>(b: Body, key: string, label: string, values: readonly T[]): T | undefined {
  const v = b[key];
  if (v === undefined) return undefined;
  if (typeof v !== 'string' || !values.includes(v as T)) throw new BadRequest(`${label}: neplatná hodnota.`);
  return v as T;
}

export const EMAIL = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
