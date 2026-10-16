// Kontrola obmedzení Montelu v kóde (F6, Peter 16. 10.): spúšťa sa v `npm run typecheck`.
// 1. Worker Montel volá iba src/montel.ts (service binding MONTEL, kľúč MONTEL_API_KEY); nikde inde.
// 2. montel.ts povoľuje presne tri GET adresy: /forwards/quotes, /forwards/ohlc/history, /spot/aggregates.
// 3. Cron cien vo wrangler.toml zodpovedá PRICE_CRON v src/schedule.ts.
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const root = new URL('..', import.meta.url).pathname;
const src = join(root, 'src');
const files = [];
(function walk(d) {
  for (const f of readdirSync(d)) {
    const p = join(d, f);
    if (statSync(p).isDirectory()) walk(p);
    else if (/\.(ts|js|mjs)$/.test(f)) files.push(p);
  }
})(src);

const errors = [];
for (const f of files) {
  const rel = relative(root, f);
  const code = readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
  if (rel === 'src/montel.ts') continue;
  if (/MONTEL\s*[?!]?\.\s*fetch|\.MONTEL\b/.test(code)) errors.push(`${rel}: volanie Montelu mimo montel.ts`);
  if (/MONTEL_API_KEY/.test(code.replace(/MONTEL_API_KEY\?: string;/, ''))) errors.push(`${rel}: kľúč Montelu mimo montel.ts`);
  if (/X-API-Key/i.test(code)) errors.push(`${rel}: hlavička X-API-Key mimo montel.ts`);
  if (/montelnews\.com|montel-auth/.test(code)) errors.push(`${rel}: priama adresa Montelu`);
}
const m = readFileSync(join(src, 'montel.ts'), 'utf8');
if (!m.includes("export const MONTEL_PATHS = ['/forwards/quotes', '/forwards/ohlc/history', '/spot/aggregates'] as const;")) {
  errors.push('montel.ts: povolené adresy sa zmenili');
}
const calls = m.match(/\.fetch\(/g) ?? [];
if (calls.length !== 1 || !/MONTEL\.fetch\(address, \{ method: 'GET'/.test(m)) errors.push('montel.ts: povolené je jediné volanie GET');
if (/console\.(log|error|warn)/.test(m)) errors.push('montel.ts: do logu nič (odpovede ani kľúč)');
const cron = /PRICE_CRON = '([^']+)'/.exec(readFileSync(join(src, 'schedule.ts'), 'utf8'))?.[1];
if (!cron || !readFileSync(join(root, 'wrangler.toml'), 'utf8').includes(`"${cron}"`)) errors.push('wrangler.toml: chýba Cron cien (PRICE_CRON)');

if (errors.length) {
  console.error('Kontrola Montelu zlyhala:\n' + errors.map((e) => '  - ' + e).join('\n'));
  process.exit(1);
}
console.log(`Kontrola Montelu: OK (${files.length} súborov)`);
