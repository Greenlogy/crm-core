// Z exports/inventar/raw/ vyrobí markdown do docs/inventar/.
// Do markdownu ide iba štruktúra a počty; e-maily a telefónne čísla sa nahradia „[skryté]“.

import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import {
  ASSOC_BUCKETS,
  ASSOC_LIMIT,
  ASSOC_OVER_LIMIT,
  type AssociationStats,
  type AssociationTypes,
  type Counts,
  type Failed,
  type FormulaInfo,
  isFailed,
  loadRaw,
  OBJECTS,
  type ObjectDef,
  type PipelineInfo,
  PRODUCT_OBJECTS,
  type ProductsRaw,
  type PropertyInfo,
  type UsersRaw,
} from './collect.ts';

const MAX_OPTIONS = 50;

// ---------- formátovanie ----------

const EMAIL_RE = /[\w.+-]+@[\w-]+(?:\.[\w-]+)+/g;
const PHONE_RE = /(?:\+|\b00)\d{3}[\d ]{8,12}\d|\b09\d{2} ?\d{3} ?\d{3}\b/g;

export const redact = (text: string) => text.replace(EMAIL_RE, '[skryté]').replace(PHONE_RE, '[skryté]');

const cell = (value: unknown) =>
  redact(String(value ?? ''))
    .replace(/\|/g, '\\|')
    .replace(/\s*\r?\n\s*/g, ' ')
    .trim();

function table(headers: string[], rows: unknown[][]): string {
  if (!rows.length) return '_žiadne_\n';
  return [
    `| ${headers.join(' | ')} |`,
    `| ${headers.map(() => '---').join(' | ')} |`,
    ...rows.map((r) => `| ${r.map(cell).join(' | ')} |`),
  ].join('\n') + '\n';
}

const num = (n: number | null | undefined) => (n == null ? '–' : n.toLocaleString('sk-SK'));
const pct = (n: number | null | undefined, total: number | null | undefined) =>
  n == null || !total ? '–' : `${(Math.round((n / total) * 1000) / 10).toLocaleString('sk-SK')} %`;
const yesNo = (v: unknown) => (v ? 'áno' : 'nie');
const failedNote = (f: Failed) => `> Nepodarilo sa načítať: ${redact(f.error)}\n`;

const objectLabel = (keyOrType: string) =>
  OBJECTS.find((o) => o.key === keyOrType || o.type === keyOrType)?.label ?? keyOrType;

const STANDARD_TYPE_IDS: Record<string, string> = {
  '0-1': 'Kontakty',
  '0-2': 'Firmy',
  '0-3': 'Dealy',
  '0-5': 'Tickety',
  '0-14': 'Ponuky',
};
const typeIdLabel = (id: unknown) => (typeof id === 'string' ? STANDARD_TYPE_IDS[id] ?? objectLabel(id) : '–');

function header(title: string): string {
  const today = new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', dateStyle: 'long' }).format(new Date());
  return [
    `# ${title}`,
    '',
    `Vygenerované skriptom \`integrations/hubspot-sync/inventory\` (${today}) z HubSpot portálu 5964726.`,
    'Ručne needitovať – pri ďalšom behu sa súbor prepíše. Komentáre a závery patria do `suhrn.md`.',
    '',
  ].join('\n');
}

// ---------- objekty a vlastnosti ----------

function renderFormulas(formulas: FormulaInfo[] | Failed | undefined, objectKey: string): string {
  if (!formulas) return '';
  if (isFailed(formulas)) return `#### Vypočítané vlastnosti\n\n${failedNote(formulas)}`;
  const own = formulas.filter((f) => f.object === objectKey && !f.hubspotDefined).sort((a, b) => a.name.localeCompare(b.name));
  if (!own.length) return '';
  const definition = (f: FormulaInfo) =>
    f.formula
      ? `\`${f.formula}\``
      : Object.keys(f.extra).length
        ? `\`${JSON.stringify(f.extra)}\``
        : '– (API definíciu nevracia)';
  return `#### Vypočítané vlastnosti (vlastné)\n\n${table(
    ['Interný názov', 'Label', 'Typ', 'Vzorec / definícia'],
    own.map((f) => [`\`${f.name}\``, f.label, f.fieldType, definition(f)]),
  )}`;
}

function renderProperties(root: string, objects: ObjectDef[], totals: Record<string, number | null | undefined>): string {
  const out: string[] = [];
  const formulas = loadRaw<FormulaInfo[] | Failed>(root, 'formulas');
  for (const obj of objects) {
    const props = loadRaw<PropertyInfo[] | Failed>(root, `properties-${obj.key}`);
    out.push(`### ${obj.label} (\`${obj.type}\`)\n`);
    if (!props) {
      out.push('_nezozbierané_\n');
      continue;
    }
    if (isFailed(props)) {
      out.push(failedNote(props));
      continue;
    }
    const total = totals[obj.key];
    const byName = (a: PropertyInfo, b: PropertyInfo) => a.groupName.localeCompare(b.groupName) || a.name.localeCompare(b.name);
    const custom = props.filter((p) => !p.hubspotDefined).sort(byName);
    const standardUsed = props.filter((p) => p.hubspotDefined && p.filled !== 0).sort(byName);
    const standardEmpty = props.filter((p) => p.hubspotDefined && p.filled === 0).sort(byName);

    const row = (p: PropertyInfo) => [
      `\`${p.name}\``,
      p.label,
      `${p.type} / ${p.fieldType}`,
      p.groupName,
      num(p.filled),
      pct(p.filled, total),
      [p.calculated && 'výpočet', p.hasUniqueValue && 'jedinečná', p.options.length && `${p.options.length} možností`]
        .filter(Boolean)
        .join(', '),
    ];
    const headers = ['Interný názov', 'Label', 'Typ', 'Skupina', 'Vyplnené', '%', 'Poznámka'];

    out.push(`Vlastností spolu: ${props.length} (vlastné ${custom.length}, HubSpot ${props.length - custom.length}). Záznamov: ${num(total)}.\n`);
    out.push(`#### Vlastné vlastnosti\n\n${table(headers, custom.map(row))}`);
    out.push(`#### HubSpot vlastnosti s dátami\n\n${table(headers, standardUsed.map(row))}`);
    out.push(
      `#### HubSpot vlastnosti bez dát (${standardEmpty.length})\n\n${standardEmpty.map((p) => `\`${p.name}\``).join(', ') || '_žiadne_'}\n`,
    );
    out.push(renderFormulas(formulas, obj.key));

    const withOptions = [...custom, ...standardUsed].filter((p) => p.options.length);
    if (withOptions.length) {
      out.push('#### Možnosti výberových polí\n');
      for (const p of withOptions) {
        const shown = p.options.slice(0, MAX_OPTIONS).map((o) => `\`${cell(o.value)}\` = ${cell(o.label)}${o.hidden ? ' (skrytá)' : ''}`);
        const more = p.options.length > MAX_OPTIONS ? ` … a ďalších ${p.options.length - MAX_OPTIONS}` : '';
        out.push(`- **\`${p.name}\`** (${cell(p.label)}): ${shown.join('; ')}${more}`);
      }
      out.push('');
    }
  }
  return out.join('\n');
}

function renderAssociations(root: string): string {
  const types = loadRaw<AssociationTypes | Failed>(root, 'associationTypes');
  if (!types) return '_nezozbierané_\n';
  if (isFailed(types)) return failedNote(types);

  const out: string[] = ['### Typy asociácií\n'];
  out.push(
    table(
      ['Z', 'Do', 'Kategória', 'typeId', 'Label'],
      types.flatMap((p) => p.types.map((t) => [objectLabel(p.from), objectLabel(p.to), t.category, t.typeId, t.label ?? '(bez labelu)'])),
    ),
  );

  out.push(`### Počty asociácií na záznam\n`);
  out.push(`Na jeden záznam sa počíta najviac ${ASSOC_LIMIT} asociácií; viac je v stĺpci „${ASSOC_OVER_LIMIT}“.\n`);
  const bucketLabels = [...ASSOC_BUCKETS.map((b) => b.label), ASSOC_OVER_LIMIT];
  const rows: unknown[][] = [];
  const labelRows: unknown[][] = [];
  for (const pair of types.filter((p) => p.types.length > 0)) {
    const stats = loadRaw<AssociationStats | Failed>(root, `associations-${pair.from}-${pair.to}`);
    if (!stats) continue;
    if (isFailed(stats)) {
      rows.push([objectLabel(pair.from), objectLabel(pair.to), `chyba: ${stats.error}`]);
      continue;
    }
    rows.push([
      objectLabel(stats.from),
      objectLabel(stats.to),
      num(stats.records),
      ...bucketLabels.map((l) => num(stats.buckets[l])),
      `${num(stats.max)}${stats.maxIsCapped ? '+' : ''}`,
      stats.average.toLocaleString('sk-SK'),
    ]);
    for (const [label, n] of Object.entries(stats.byLabel)) {
      labelRows.push([objectLabel(stats.from), objectLabel(stats.to), label, num(n)]);
    }
  }
  out.push(table(['Z', 'Do', 'Záznamov', ...bucketLabels, 'Max', 'Priemer'], rows));
  out.push(`### Asociácie podľa labelu\n\n${table(['Z', 'Do', 'Label', 'Počet asociácií'], labelRows)}`);
  return out.join('\n');
}

function renderObjects(root: string): string {
  const counts = loadRaw<Counts | Failed>(root, 'counts');
  const okCounts = counts && !isFailed(counts) ? counts : undefined;
  const schemas = loadRaw<Record<string, any>[] | Failed>(root, 'schemas');

  const out: string[] = [header('Inventár HubSpotu – objekty a vlastnosti')];

  out.push('## Počty záznamov\n');
  if (counts && isFailed(counts)) out.push(failedNote(counts));
  else if (okCounts) {
    out.push(
      table(
        ['Objekt', 'HubSpot typ', 'Záznamov'],
        OBJECTS.map((o) => [o.label, `\`${o.type}\``, num(okCounts[o.key])]),
      ),
    );
    out.push(
      table(
        ['Kontakty', 'Počet', '%'],
        [
          ['s firmou (B2B)', num(okCounts.contactsWithCompany), pct(okCounts.contactsWithCompany, okCounts.contacts)],
          ['bez firmy (B2C)', num(okCounts.contactsWithoutCompany), pct(okCounts.contactsWithoutCompany, okCounts.contacts)],
        ],
      ),
    );
    out.push('B2B/B2C sa určuje podľa primárnej firmy kontaktu (`associatedcompanyid`).\n');
  } else out.push('_nezozbierané_\n');

  out.push('## Custom objekty\n');
  if (schemas && isFailed(schemas)) out.push(failedNote(schemas));
  else if (schemas) {
    out.push(
      table(
        ['objectTypeId', 'Názov', 'Label', 'Zobrazovaná vlastnosť', 'Povinné vlastnosti', 'Vytvorené'],
        schemas.map((s) => [
          `\`${s.objectTypeId}\``,
          s.name,
          s.labels?.plural ?? s.labels?.singular,
          s.primaryDisplayProperty,
          (s.requiredProperties ?? []).join(', '),
          String(s.createdAt ?? '').slice(0, 10),
        ]),
      ),
    );
  } else out.push('_nezozbierané_\n');

  out.push('## Asociácie\n');
  out.push(renderAssociations(root));
  out.push('## Vlastnosti\n');
  out.push(renderProperties(root, OBJECTS, okCounts ?? {}));
  out.push(renderProducts(root));
  return out.join('\n');
}

function renderProducts(root: string): string {
  const data = loadRaw<ProductsRaw | Failed>(root, 'products');
  const out: string[] = ['## Produkty a line items\n'];
  if (!data) return `${out[0]}_nezozbierané_\n`;
  if (isFailed(data)) return `${out[0]}${failedNote(data)}`;

  out.push(`Produktov: ${num(data.productsTotal)}, line items: ${num(data.lineItemsTotal)}.\n`);
  out.push(
    table(
      ['Produkt', 'SKU', 'Cena', 'Typ', 'Fakturácia', 'Line items', 'Vytvorený'],
      [...data.products]
        .sort((a, b) => (b.lineItems ?? 0) - (a.lineItems ?? 0) || a.name.localeCompare(b.name))
        .map((p) => [
          p.name,
          p.sku,
          p.price,
          p.productType,
          [p.billingFrequency, p.billingPeriod].filter(Boolean).join(', '),
          num(p.lineItems),
          p.createdAt,
        ]),
    ),
  );
  out.push(
    renderProperties(root, PRODUCT_OBJECTS, { products: data.productsTotal, line_items: data.lineItemsTotal }),
  );
  return out.join('\n');
}

// ---------- pipelines ----------

function renderPipelines(root: string): string {
  const out: string[] = [header('Inventár HubSpotu – pipelines a štádiá')];
  const pipelines = loadRaw<PipelineInfo[] | Failed>(root, 'pipelines');
  if (!pipelines) return out.join('\n') + '_nezozbierané_\n';
  if (isFailed(pipelines)) return out.join('\n') + failedNote(pipelines);

  for (const obj of OBJECTS) {
    const own = pipelines.filter((p) => p.object === obj.key).sort((a, b) => a.displayOrder - b.displayOrder);
    if (!own.length) continue;
    out.push(`## ${obj.label}\n`);
    for (const p of own) {
      out.push(`### ${cell(p.label)} (\`${p.id}\`) – ${num(p.total)} záznamov\n`);
      out.push(
        table(
          ['Poradie', 'Štádium', 'ID', 'Záznamov', 'Metadáta'],
          p.stages.map((s) => [
            s.displayOrder,
            s.label,
            `\`${s.id}\``,
            num(s.count),
            Object.entries(s.metadata)
              .map(([k, v]) => `${k}=${v}`)
              .join(', '),
          ]),
        ),
      );
    }
  }
  return out.join('\n');
}

// ---------- workflowy, šablóny, formuláre, používatelia, súhlasy ----------

function section<T>(root: string, name: string, title: string, body: (data: T) => string): string {
  const data = loadRaw<T | Failed>(root, name);
  if (data === undefined) return `## ${title}\n\n_nezozbierané_\n`;
  if (isFailed(data)) return `## ${title}\n\n${failedNote(data)}`;
  return `## ${title}\n\n${body(data)}`;
}

function renderWorkflows(flows: Record<string, any>[]): string {
  const active = flows.filter((f) => f.isEnabled).length;
  const actionSummary = (actions: Record<string, any>[] = []) => {
    const counts = new Map<string, number>();
    for (const a of actions) counts.set(a.actionTypeId ?? a.type, (counts.get(a.actionTypeId ?? a.type) ?? 0) + 1);
    return [...counts].map(([id, n]) => `${id}×${n}`).join(', ');
  };
  const rows = [...flows]
    .sort((a, b) => Number(b.isEnabled) - Number(a.isEnabled) || String(a.name).localeCompare(String(b.name)))
    .map((f) => [
      f.name,
      typeIdLabel(f.objectTypeId),
      yesNo(f.isEnabled),
      f.enrollmentCriteria?.type ?? f.flowType,
      f.enrollmentCriteria?.shouldReEnroll ? 'áno' : 'nie',
      (f.actions ?? []).length,
      actionSummary(f.actions),
      String(f.updatedAt ?? '').slice(0, 10),
    ]);
  return [
    `Spolu ${flows.length}, aktívnych ${active}, neaktívnych ${flows.length - active}.`,
    'Typy akcií sú HubSpot `actionTypeId` (napr. `0-5`). Čo workflow robí slovne, dopíšem do `suhrn.md` po prečítaní definícií.\n',
    table(['Názov', 'Objekt', 'Aktívny', 'Spúšťač', 'Opak. zápis', 'Akcií', 'Typy akcií', 'Upravené'], rows),
  ].join('\n');
}

function renderUsers(data: UsersRaw): string {
  const roles = new Map(data.roles.map((r) => [r.id, r.name]));
  const users = new Map(data.users.map((u) => [String(u.id), u]));
  const teams = new Map(data.teams.map((t) => [t.id, t.name]));
  const rows = data.owners
    .sort((a, b) => Number(a.archived) - Number(b.archived) || `${a.lastName}`.localeCompare(`${b.lastName}`))
    .map((o) => {
      const user = o.userId ? users.get(String(o.userId)) : undefined;
      const roleIds = user?.roleIds ?? (user?.roleId ? [user.roleId] : []);
      const role = [user?.superAdmin && 'Super Admin', ...roleIds.map((id) => roles.get(id) ?? id)].filter(Boolean).join(', ');
      return [
        `${o.firstName ?? ''} ${o.lastName ?? ''}`.trim() || '(bez mena)',
        role || '–',
        (o.teams ?? []).map((t) => teams.get(t.id) ?? t.name).join(', ') || '–',
        o.archived ? 'archivovaný' : user ? 'aktívny' : 'iba vlastník',
      ];
    });
  return [
    table(['Meno', 'Rola', 'Tímy', 'Stav'], rows),
    `### Tímy\n\n${data.teamsError ? '> Tímy prevzaté z vlastníkov; počty členov chýbajú (scope `settings.users.teams.read`).\n\n' : ''}` +
      table(['Tím', 'Členov'], data.teams.map((t) => [t.name, t.userIds?.length ?? '–'])),
  ].join('\n');
}

function renderWorkflowsAndTemplates(root: string): string {
  const out: string[] = [header('Inventár HubSpotu – workflowy, šablóny, formuláre, používatelia')];

  out.push(section<Record<string, any>[]>(root, 'workflows', 'Workflowy', renderWorkflows));

  out.push(
    section<Record<string, any>[]>(root, 'marketingEmails', 'Marketingové e-maily', (emails) =>
      table(
        ['Názov', 'Predmet', 'Typ', 'Stav', 'Upravené'],
        emails.filter((e) => !e.archived).map((e) => [e.name, e.subject, e.type, e.state, String(e.updatedAt ?? '').slice(0, 10)]),
      ),
    ),
  );

  out.push(
    '## Šablóny predajných e-mailov\n\nVynechané z inventára – HubSpot pre ne nemá verejné API. ' +
      'Rozhodnutie (2026-10-10): funkcia šablón bude v CRM, texty sa prenesú ručne.\n',
  );

  out.push(
    section<Record<string, any>[]>(root, 'sequences', 'Sekvencie', (seqs) =>
      table(['Názov', 'Vytvorené', 'Upravené'], seqs.map((s) => [s.name, String(s.createdAt ?? '').slice(0, 10), String(s.updatedAt ?? '').slice(0, 10)])),
    ),
  );

  out.push(
    section<{ total: number | null; templates: Record<string, any>[] | Failed }>(root, 'quotes', 'Ponuky (quotes)', (q) =>
      [
        `Ponúk spolu: ${num(q.total)}.\n`,
        '### Šablóny ponúk\n',
        isFailed(q.templates)
          ? failedNote(q.templates)
          : table(['Názov', 'Aktívna'], q.templates.map((t) => [t.properties?.hs_name, t.properties?.hs_active])),
      ].join('\n'),
    ),
  );

  out.push(
    section<Record<string, any>[]>(root, 'forms', 'Formuláre', (forms) => {
      const active = forms.filter((f) => !f.archived);
      return [
        `Aktívnych formulárov: ${active.length} (archivovaných ${forms.length - active.length}).\n`,
        ...active.map(
          (f) =>
            `### ${cell(f.name)}\n\nTyp: ${f.formType}, vytvorený ${String(f.createdAt ?? '').slice(0, 10)}.\n\n` +
            table(
              ['Pole', 'Label', 'Typ', 'Objekt', 'Povinné', 'Skryté'],
              f.fields.map((x: any) => [`\`${x.name}\``, x.label, x.fieldType, typeIdLabel(x.objectTypeId), yesNo(x.required), yesNo(x.hidden)]),
            ),
        ),
      ].join('\n');
    }),
  );

  out.push(section<UsersRaw>(root, 'users', 'Používatelia a tímy', renderUsers));

  out.push(
    section<Record<string, any>>(root, 'subscriptions', 'Typy odberu (marketingové súhlasy)', (s) =>
      [
        table(
          ['Ukazovateľ', 'Kontaktov', '%'],
          [
            ['Kontaktov spolu', num(s.contactsTotal), ''],
            ['Marketingové kontakty (`hs_marketable_status`)', num(s.marketable), pct(s.marketable, s.contactsTotal)],
            ['Odhlásení zo všetkého (`hs_email_optout`)', num(s.globalOptOut), pct(s.globalOptOut, s.contactsTotal)],
          ],
        ),
        table(
          ['Typ odberu', 'ID', 'Aktívny', 'Predvolený', 'Interný', 'Odhlásených'],
          s.definitions.map((d: any) => [d.name, d.id, yesNo(d.isActive), yesNo(d.isDefault), yesNo(d.isInternal), num(d.optedOut)]),
        ),
        'Počet prihlásených sa nezisťuje (vyžadoval by čítanie súhlasov každého kontaktu).\n',
      ].join('\n'),
    ),
  );

  return out.join('\n');
}

// ---------- hlavný beh ----------

export function render(root: string) {
  const dir = join(root, 'docs', 'inventar');
  mkdirSync(dir, { recursive: true });
  const files: [string, string][] = [
    ['objekty-a-vlastnosti.md', renderObjects(root)],
    ['pipelines.md', renderPipelines(root)],
    ['workflowy-a-sablony.md', renderWorkflowsAndTemplates(root)],
  ];
  for (const [name, content] of files) {
    writeFileSync(join(dir, name), content.replace(/\n{3,}/g, '\n\n'));
    console.log(`  docs/inventar/${name}`);
  }
}
