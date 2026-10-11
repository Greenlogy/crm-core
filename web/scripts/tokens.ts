// Generuje src/styles/tokens.css z docs/dizajn/system/tokens.json (jediný zdroj hodnôt vzhľadu).
// Spúšťa sa pred dev, build a typecheck. Hodnoty sa do CSS ručne nevpisujú.

import { readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

type Themed = string | { light: string; dark: string };
type Token = { name: string; value: Themed };
type TypeStyle = { name: string; fontSize: string; fontWeight: number; lineHeight: number; letterSpacing?: string };
type Tokens = {
  version: string;
  color: { tokens: Token[] };
  spacing: { tokens: Token[] };
  radius: { tokens: Token[] };
  shadow: { tokens: Token[] };
  type: { families: Record<string, string>; groups: { styles: TypeStyle[] }[] };
};

const web = resolve(import.meta.dirname, '..');
const src = join(web, '../docs/dizajn/system/tokens.json');
const t = JSON.parse(readFileSync(src, 'utf8')) as Tokens;

const light: string[] = [];
const dark: string[] = [];
for (const tok of [...t.color.tokens, ...t.shadow.tokens, ...t.spacing.tokens, ...t.radius.tokens]) {
  if (typeof tok.value === 'string') light.push(`  --${tok.name}: ${tok.value};`);
  else {
    light.push(`  --${tok.name}: ${tok.value.light};`);
    dark.push(`  --${tok.name}: ${tok.value.dark};`);
  }
}
for (const [name, family] of Object.entries(t.type.families)) light.push(`  --font-${name}: ${family};`);

const styles = t.type.groups.flatMap((g) => g.styles);
const typeCss = styles.map((s) =>
  [
    `.t-${s.name} {`,
    s.name === 'code' ? '  font-family: var(--font-mono);' : null,
    `  font-size: ${s.fontSize};`,
    `  font-weight: ${s.fontWeight};`,
    `  line-height: ${s.lineHeight};`,
    s.letterSpacing ? `  letter-spacing: ${s.letterSpacing};` : null,
    '}',
  ]
    .filter(Boolean)
    .join('\n'),
);

const css = [
  `/* Vygenerované z docs/dizajn/system/tokens.json (verzia ${t.version}) skriptom web/scripts/tokens.ts. Neupravovať ručne. */`,
  '',
  ':root {',
  '  color-scheme: light;',
  ...light,
  '}',
  '',
  ':root[data-theme="dark"] {',
  '  color-scheme: dark;',
  ...dark,
  '}',
  '',
  '@media (prefers-color-scheme: dark) {',
  '  :root:not([data-theme="light"]) {',
  '    color-scheme: dark;',
  ...dark.map((l) => `  ${l}`),
  '  }',
  '}',
  '',
  ...typeCss,
  '',
].join('\n');

writeFileSync(join(web, 'src/styles/tokens.css'), css);
console.log(`tokens.css: ${t.color.tokens.length} farieb, ${styles.length} štýlov písma`);
