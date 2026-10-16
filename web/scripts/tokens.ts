// Generuje src/styles/tokens.css z docs/design-handoff/tokens/tokens.css (jediný zdroj hodnôt vzhľadu, smer
// „Krajina moderná A“, 16. 10. 2026). Súbor podkladov sa prevezme bez zmeny a doplnia sa:
//  - doplnkové tokeny: hodnoty, ktoré sú v podkladoch iba v styles/components.css (aby komponenty nemali hex),
//  - aliasy starých názvov (--brand, --ink…) podľa DESIGN_SPEC.md § 9, kým sa všetky štýly neprepíšu na --gl-*.
// Spúšťa sa pred dev, build a typecheck. Hodnoty sa do CSS ručne nevpisujú.

import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

const web = resolve(import.meta.dirname, '..');
const src = join(web, '../docs/design-handoff/tokens/tokens.css');
const handoff = readFileSync(src, 'utf8');

// Hodnoty z docs/design-handoff/styles/components.css a DESIGN_SPEC.md, ktoré nemajú vlastný token.
const extra: [string, string][] = [
  ['gl-on-primary', '#ffffff'], // text na primárnom tlačidle a zvolenom čipe
  ['gl-chip-count-on', '#dcebf5'], // počet na zvolenom čipe
  ['gl-chip-ink', '#3d5566'], // text nezvoleného čipu
  ['gl-rail-hover', '#eef5f8'], // hover položky menu
  ['gl-btn-hover-bg', '#f7fbfd'], // hover sekundárneho tlačidla
  ['gl-input-border', '#cfe2ea'], // okraj poľa formulára
  ['gl-calc-border', '#d9ebe6'], // okraj karty kalkulačky
  ['gl-soft-border', 'rgba(255, 255, 255, .9)'], // okraj hlavnej KPI dlaždice
  ['gl-step-divider', '#edf3f5'], // oddeľovač v zozname ďalších krokov
  ['gl-stepper-line', '#c9d9e3'], // spojnica budúcich štádií
  ['gl-offer-current-bg', '#eaf3f9'], // aktuálna ponuka v karte Ponuky (§ 5.5)
  ['gl-chip-hover', 'rgba(255, 255, 255, .8)'], // hover čipu na skle
  ['gl-mobile-bar-bg', 'rgba(255, 255, 255, .94)'], // spodná lišta na mobile
  ['gl-backdrop', 'rgba(29, 58, 79, .28)'], // podklad bočného panelu a okna
  ['gl-shadow-pop', '0 8px 24px rgba(29, 58, 79, .14)'], // rozbaľovacie menu, našepkávač
];

// Staré názvy → nové tokeny (DESIGN_SPEC.md § 9). Rozostupy a malé zaoblenia nemajú v podkladoch náhradu.
const alias: [string, string][] = [
  ['surface-page', 'var(--gl-surface-page)'],
  ['surface-card', 'var(--gl-surface-card)'],
  ['surface-sidebar', 'var(--gl-surface-page)'],
  ['surface-muted', 'var(--gl-neutral-bg)'],
  ['border', 'var(--gl-border)'],
  ['border-strong', 'var(--gl-border-strong)'],
  ['ink', 'var(--gl-ink)'],
  ['ink-muted', 'var(--gl-ink-muted)'],
  ['ink-subtle', 'var(--gl-ink-muted)'], // pôvodná #94a3b8 nemala kontrast 4,5:1
  ['brand', 'var(--gl-blue-600)'],
  ['brand-hover', 'var(--gl-blue-700)'],
  ['on-brand', 'var(--gl-on-primary)'],
  ['brand-text', 'var(--gl-brand-blue)'],
  ['brand-tint', 'var(--gl-green-50)'],
  ['positive', 'var(--gl-ok-fg)'],
  ['positive-tint', 'var(--gl-ok-bg)'],
  ['negative', 'var(--gl-danger-fg)'],
  ['negative-tint', 'var(--gl-danger-bg)'],
  ['warning', 'var(--gl-warn-fg)'],
  ['warning-tint', 'var(--gl-warn-bg)'],
  ['info', 'var(--gl-info-fg)'],
  ['info-tint', 'var(--gl-info-bg)'],
  ['chart-1', 'var(--gl-chart-1)'],
  ['chart-2', 'var(--gl-chart-2)'],
  ['chart-3', 'var(--gl-chart-3)'],
  ['focus-ring', 'var(--gl-blue-600)'],
  ['shadow-card', 'var(--gl-shadow-card)'],
  ['shadow-pop', 'var(--gl-shadow-pop)'],
  ['font-sans', 'var(--gl-font-sans)'],
  ['font-mono', 'var(--gl-font-mono)'],
  ['radius-xs', '4px'],
  ['radius-sm', '6px'],
  ['radius-md', 'var(--gl-radius-field)'],
  ['radius-lg', 'var(--gl-radius-card)'],
  ['radius-pill', 'var(--gl-radius-pill)'],
  ['space-1', '4px'],
  ['space-2', '8px'],
  ['space-3', '12px'],
  ['space-4', '16px'],
  ['space-5', '20px'],
  ['space-6', '32px'],
  ['space-page', '36px'],
];

const css = [
  '/* Vygenerované z docs/design-handoff/tokens/tokens.css skriptom web/scripts/tokens.ts. Neupravovať ručne. */',
  '',
  handoff.trim(),
  '',
  '/* --- Doplnkové tokeny (hodnoty z styles/components.css podkladov) --- */',
  ':root {',
  '  color-scheme: light;',
  ...extra.map(([n, v]) => `  --${n}: ${v};`),
  '}',
  '',
  '/* --- Aliasy starých názvov (DESIGN_SPEC.md § 9); postupne sa nahradia priamo --gl-* --- */',
  ':root {',
  ...alias.map(([n, v]) => `  --${n}: ${v};`),
  '}',
  '',
].join('\n');

writeFileSync(join(web, 'src/styles/tokens.css'), css);
console.log(`tokens.css: podklady + ${extra.length} doplnkových tokenov + ${alias.length} aliasov`);
