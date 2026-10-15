// Obrázky do PDF ponuky: aktívny obrázok z Nastavení (offer_asset), inak pribalený z docs/dizajn/obrazovky/assets.

import type { Sql } from '../db';
import energetickyMix from '../assets/energeticky-mix.png';
import titulna from '../assets/ponuka-titulna.png';
import referencie1 from '../assets/referencie-1.png';
import referencie2 from '../assets/referencie-2.png';
import type { OfferAssets } from './offer-html';

const BUNDLED: Required<OfferAssets> = {
  titulna: dataUri(titulna, 'image/png'),
  referencie_zakaznici: dataUri(referencie1, 'image/png'),
  referencie_partneri: dataUri(referencie2, 'image/png'),
  energeticky_mix: dataUri(energetickyMix, 'image/png'),
};

function dataUri(buf: ArrayBuffer | Uint8Array, mime: string): string {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return `data:${mime};base64,${btoa(s)}`;
}

export function bundledAssets(): Required<OfferAssets> {
  return BUNDLED;
}

/** Obrázky pre spoločnosť ponuky (RLS: prihlásený používateľ). */
export async function offerAssets(sql: Sql, orgId: string): Promise<Required<OfferAssets>> {
  const rows = await sql<{ code: keyof OfferAssets; mime: string; data: Uint8Array }[]>`
    SELECT code, mime, data FROM offer_asset WHERE org_id = ${orgId} AND active`;
  const out = { ...BUNDLED };
  for (const r of rows) out[r.code] = dataUri(r.data, r.mime);
  return out;
}
