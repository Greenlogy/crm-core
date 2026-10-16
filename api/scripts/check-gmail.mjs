// Kontrola obmedzení Gmailu v kóde (F4, Peter 15. a 16. 10.): spúšťa sa v `npm run typecheck`.
// 1. Adresu Gmail API skladá iba src/gmail/endpoints.ts; fetch na Gmail volá iba src/gmail/gmail.ts.
// 2. Nikde v src/ nie je list, search (q=), history, attachments, watch ani format=raw.
// 3. endpoints.ts povoľuje iba threads.get a messages.get vo formátoch minimal / metadata / full.
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
  // bez komentárov (v nich sa zakázané operácie spomínajú)
  const code = readFileSync(f, 'utf8').replace(/\/\*[\s\S]*?\*\//g, '').replace(/(^|[^:])\/\/.*$/gm, '$1');
  if (code.includes('gmail.googleapis.com') && rel !== 'src/gmail/endpoints.ts') errors.push(`${rel}: adresa Gmail API mimo endpoints.ts`);
  if (/googleapis\.com\/gmail|\/gmail\/v1\//.test(code.replace('https://gmail.googleapis.com/gmail/v1/users', '')) ) errors.push(`${rel}: iná adresa Gmail API`);
  for (const [re, what] of [
    [/\/(threads|messages)\?/, 'list (threads? / messages?)'],
    [/[?&]q=|['"]q['"]\s*:/, 'search (q=)'],
    [/\/history\b|history\.list/, 'history'],
    [/\/attachments\b|attachments\.get['"]?\s*[,)]/, 'attachments'],
    [/format=raw|format:\s*['"]raw['"]|['"]raw['"]\s*\)/, 'format=raw'],
    [/\/watch\b/, 'watch'],
    [/users\.(threads|messages)\.list|\.list\(/, 'list'],
  ]) {
    if (rel.startsWith('src/gmail/') && re.test(code)) errors.push(`${rel}: zakázané ${what}`);
  }
}
const ep = readFileSync(join(src, 'gmail/endpoints.ts'), 'utf8');
if (!/READ_METHODS = \['threads\.get', 'messages\.get'\] as const/.test(ep)) errors.push('endpoints.ts: povolené metódy sa zmenili');
if (!/READ_FORMATS = \['minimal', 'metadata', 'full'\] as const/.test(ep)) errors.push('endpoints.ts: povolené formáty sa zmenili');
const fetchers = files.filter((f) => /fetch\(\s*(readUrl|sendUrl|url)\b/.test(readFileSync(f, 'utf8'))).map((f) => relative(root, f));
if (fetchers.some((f) => f !== 'src/gmail/gmail.ts')) errors.push(`volanie Gmailu mimo gmail.ts: ${fetchers.join(', ')}`);

if (errors.length) {
  console.error('Kontrola Gmailu zlyhala:\n' + errors.map((e) => '  - ' + e).join('\n'));
  process.exit(1);
}
console.log(`Kontrola Gmailu: OK (${files.length} súborov)`);
