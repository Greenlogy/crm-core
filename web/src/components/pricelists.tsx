// Modul 3 Produkty a cenníky, F1: spoločné časti obrazoviek 20–23 (záložky, sadzby, skrátené zoznamy).

import { NavLink } from 'react-router-dom';
import type { TariffRef } from '../lib/api';
import { dec, EMPTY } from '../lib/format';

/** Platné ID záznamu (adresa /cenniky/:id prijme iba UUID). */
export const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Záložky Cenníky / Produkty / Programy (dizajn 20–23). */
export function PriceTabs() {
  return (
    <nav className="tabs" aria-label="Cenníky, produkty, programy">
      <NavLink to="/cenniky" end className="tab">
        Cenníky
      </NavLink>
      <NavLink to="/cenniky/produkty" className="tab">
        Produkty
      </NavLink>
      <NavLink to="/cenniky/programy" className="tab">
        Programy
      </NavLink>
    </nav>
  );
}

/** „D1, D2, …, D8“ → „D1–D8“ (iba súvislé čísla s rovnakou predponou, aspoň tri). */
export function compressCodes(labels: string[]): string[] {
  const out: string[] = [];
  let i = 0;
  while (i < labels.length) {
    const m = /^([A-Z]+)(\d+)$/.exec(labels[i]);
    let j = i;
    if (m) {
      while (j + 1 < labels.length) {
        const n = /^([A-Z]+)(\d+)$/.exec(labels[j + 1]);
        if (!n || n[1] !== m[1] || Number(n[2]) !== Number(m[2]) + (j + 1 - i)) break;
        j++;
      }
    }
    out.push(j - i >= 2 ? `${labels[i]}–${labels[j]}` : labels[i]);
    if (j - i < 2) {
      i++;
    } else {
      i = j + 1;
    }
  }
  return out;
}

/** Sadzby produktu: spoločné (SSD a miestne DS) najprv, potom ZSD a VSD, bez opakovania (DMP4: „C4 · C2-X3 · X3-C2“). */
export function tariffText(tariffs: TariffRef[], tariffType?: string, category?: string): string {
  if (tariffs.length === 0) return category === 'dodavka_firma' ? 'všetky' : EMPTY;
  const order = ['spolocne', 'zsd', 'vsd'];
  const sorted = [...tariffs].sort((a, b) => {
    const sa = order.indexOf(a.scope) === -1 ? 9 : order.indexOf(a.scope);
    const sb = order.indexOf(b.scope) === -1 ? 9 : order.indexOf(b.scope);
    return sa - sb;
  });
  const labels: string[] = [];
  for (const t of sorted) if (!labels.includes(t.label)) labels.push(t.label);
  const text = compressCodes(labels).join(' · ');
  return tariffType === 'nemerany' ? `${text} (nemeraný)` : text;
}

/** Zoznam produktov cenníka skrátene: „Green DD1 – NIE Energopomoc … DD8“ → „Green DD1–DD8 – NIE Energopomoc, ZEM“. */
export function productsText(names: string[]): string {
  if (names.length === 0) return EMPTY;
  const groups: { pre: string; suf: string; nums: number[] }[] = [];
  const other: string[] = [];
  for (const n of names) {
    const m = /^(.*?)(\d+)(\D*)$/.exec(n);
    if (!m) {
      other.push(n);
      continue;
    }
    const g = groups.find((x) => x.pre === m[1] && x.suf === m[3]);
    if (g) g.nums.push(Number(m[2]));
    else groups.push({ pre: m[1], suf: m[3], nums: [Number(m[2])] });
  }
  const parts = groups.map((g) => {
    const sorted = [...g.nums].sort((a, b) => a - b);
    const seq = sorted.every((v, i) => i === 0 || v === sorted[i - 1] + 1);
    if (sorted.length >= 3 && seq) {
      const short = /(\S+)$/.exec(g.pre.trim())?.[1] ?? '';
      return `${g.pre}${sorted[0]}–${short}${sorted[sorted.length - 1]}${g.suf}`;
    }
    return sorted.map((v) => `${g.pre}${v}${g.suf}`).join(', ');
  });
  // „VBattery STANDARD, VBattery PREMIUM“ → „VBattery STANDARD, PREMIUM“ (rovnaký začiatok názvu sa neopakuje)
  const rest: string[] = [];
  for (const n of other) {
    const prev = rest.length ? other[other.indexOf(n) - 1] : '';
    const head = prev.slice(0, prev.lastIndexOf(' ') + 1);
    rest.push(head && n.startsWith(head) ? n.slice(head.length) : n);
  }
  return [...parts, ...rest].join(', ');
}

/** Sadzba DPH „19 %“. */
export const vatText = (v: string | number | null) => (v === null || v === '' ? EMPTY : `${dec(v, 0)} %`);
