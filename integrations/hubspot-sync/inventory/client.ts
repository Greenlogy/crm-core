// HubSpot API klient pre inventár: iba čítanie, throttling, opakovanie pri 429 a 5xx.
// Token sa nikdy nevypisuje. Do logu idú iba cesty, stavy a počty – nikdy dáta zákazníkov.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const BASE_URL = 'https://api.hubapi.com';
const MIN_INTERVAL_MS = 250; // najviac 4 požiadavky za sekundu (search API má limit 5/s)
const MAX_RETRIES = 6;

// POST je povolený iba na endpointy, ktoré nič nemenia. Všetko ostatné okrem GET sa zablokuje.
const READ_ONLY_POST: RegExp[] = [
  /^\/crm\/v3\/objects\/[\w-]+\/search$/,
  /^\/crm\/v3\/objects\/[\w-]+\/batch\/read$/,
  /^\/crm\/v4\/associations\/[\w-]+\/[\w-]+\/batch\/read$/,
  /^\/oauth\/v2\/private-apps\/get\/access-token-info$/,
];

export type Query = Record<string, string | number | boolean | undefined>;

export type TokenInfo = {
  hubId: number;
  appId?: number;
  scopes: string[];
};

export class HubSpotError extends Error {
  status: number;

  constructor(status: number, path: string, detail: string) {
    super(`HubSpot ${status} ${path}: ${detail}`);
    this.status = status;
  }
}

export function loadToken(repoRoot: string): string {
  const text = readFileSync(join(repoRoot, '.dev.vars'), 'utf8');
  for (const line of text.split(/\r?\n/)) {
    const match = line.match(/^\s*HUBSPOT_TOKEN\s*=\s*(.+?)\s*$/);
    if (match) return match[1].replace(/^["']|["']$/g, '');
  }
  throw new Error('HUBSPOT_TOKEN chýba v .dev.vars');
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

async function errorDetail(res: Response): Promise<string> {
  const text = await res.text();
  try {
    const json = JSON.parse(text) as { message?: string; category?: string };
    return `${json.category ?? ''} ${json.message ?? ''}`.trim().slice(0, 300);
  } catch {
    return text.slice(0, 300);
  }
}

export class HubSpotClient {
  #token: string;
  #lastRequestAt = 0;
  requestCount = 0;

  constructor(token: string) {
    this.#token = token;
  }

  get<T>(path: string, query?: Query): Promise<T> {
    return this.#request<T>('GET', path, query);
  }

  post<T>(path: string, body: unknown): Promise<T> {
    if (!READ_ONLY_POST.some((re) => re.test(path))) {
      throw new Error(`Zablokované: POST ${path} nie je na zozname čítacích endpointov`);
    }
    return this.#request<T>('POST', path, undefined, body);
  }

  tokenInfo(): Promise<TokenInfo> {
    return this.post<TokenInfo>('/oauth/v2/private-apps/get/access-token-info', { tokenKey: this.#token });
  }

  async #request<T>(method: 'GET' | 'POST', path: string, query?: Query, body?: unknown): Promise<T> {
    const url = new URL(path, BASE_URL);
    for (const [key, value] of Object.entries(query ?? {})) {
      if (value !== undefined) url.searchParams.set(key, String(value));
    }

    for (let attempt = 0; ; attempt++) {
      const wait = this.#lastRequestAt + MIN_INTERVAL_MS - Date.now();
      if (wait > 0) await sleep(wait);
      this.#lastRequestAt = Date.now();
      this.requestCount++;

      const res = await fetch(url, {
        method,
        headers: {
          Authorization: `Bearer ${this.#token}`,
          ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
        },
        body: body === undefined ? undefined : JSON.stringify(body),
      });

      if ((res.status === 429 || res.status >= 500) && attempt < MAX_RETRIES) {
        await res.body?.cancel();
        const retryAfter = Number(res.headers.get('retry-after'));
        const delay = retryAfter > 0 ? retryAfter * 1000 : 1000 * 2 ** attempt;
        console.warn(`  ${res.status} ${method} ${path} – opakujem o ${Math.round(delay / 1000)} s`);
        await sleep(delay);
        continue;
      }
      if (!res.ok) throw new HubSpotError(res.status, path, await errorDetail(res));
      if (res.status === 204) return undefined as T;
      return (await res.json()) as T;
    }
  }
}
