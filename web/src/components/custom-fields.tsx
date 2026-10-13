// Vlastné polia z Nastavení na kartách a v zoznamoch (modul Zákazníci F3).
// Karta: polia po sekciách, úprava v bočnom paneli (iba polia, ktoré smie tím meniť; povinné kontroluje
// formulár). Zoznam: stĺpce „zobraziť v zozname“ a filtre „dá sa filtrovať“. Pravidlá stráži databáza.

import { useEffect, useState, type ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { get, send, useApi } from '../lib/api';
import { date, EMPTY, num } from '../lib/format';
import { useMe } from '../lib/me';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Card, Rows } from './ui';

export type FieldDef = {
  id: string;
  entity: 'firma' | 'osoba' | 'oom' | 'deal' | 'zmluva' | 'ponuka';
  key: string;
  label: string;
  field_type: 'text' | 'dlhy_text' | 'cislo' | 'suma' | 'datum' | 'vyber' | 'vyber_viac' | 'ano_nie' | 'odkaz';
  ref_entity: FieldDef['entity'] | null;
  section_id: string | null;
  section_name: string | null;
  is_required: boolean;
  show_in_list: boolean;
  filterable: boolean;
  org_id: string | null;
  archived_at: string | null;
  can_edit: boolean;
  options: { id: string; label: string; hidden_at: string | null }[];
};
export type RefLabel = { id: string; label: string | null; entity: string | null };

export function useFieldDefs(entities: string): FieldDef[] {
  return useApi<{ items: FieldDef[] }>(`/api/custom-fields?entity=${entities}`).data?.items ?? [];
}

/** Hodnota poľa na zobrazenie (text alebo odkaz). */
export function formatCustom(def: FieldDef, value: unknown, refs: RefLabel[] = [], currency = 'EUR'): ReactNode {
  if (value === null || value === undefined || value === '') return EMPTY;
  const option = (id: unknown) => def.options.find((o) => o.id === id)?.label ?? '?';
  switch (def.field_type) {
    case 'ano_nie':
      return value === true ? 'áno' : 'nie';
    case 'cislo':
      return num(value as number, 4);
    case 'suma':
      return `${num(value as number, 2)} ${currency}`;
    case 'datum':
      return date(String(value));
    case 'vyber':
      return option(value);
    case 'vyber_viac':
      return Array.isArray(value) ? value.map(option).join(', ') : EMPTY;
    case 'odkaz': {
      const r = refs.find((x) => x.id === value);
      if (!r) return '(odkaz)';
      const to = r.entity === 'firma' ? `/firmy/${r.id}` : r.entity === 'osoba' ? `/osoby/${r.id}` : null;
      return to ? <Link to={to}>{r.label}</Link> : (r.label ?? '(odkaz)');
    }
    default:
      return String(value);
  }
}

/** Polia, ktoré patria záznamu: spoločnosť poľa sedí a pole nie je archivované (alebo má hodnotu). */
const applicable = (defs: FieldDef[], entity: string, orgId: string, custom: Record<string, unknown>) =>
  defs.filter(
    (d) => d.entity === entity && (d.org_id === null || d.org_id === orgId) && (!d.archived_at || custom[d.key] !== undefined),
  );

// --- Karta ------------------------------------------------------------------------------------

// Cesta API pre zápis hodnôt podľa záznamu
const CUSTOM_PATH: Record<'firma' | 'osoba' | 'oom', string> = { firma: 'companies', osoba: 'persons', oom: 'oom' };

export function CustomFieldsCard(props: {
  entity: 'firma' | 'osoba' | 'oom';
  recordId: string;
  orgId: string;
  custom: Record<string, unknown>;
  refs: RefLabel[];
  canEditRecord: boolean;
  onSaved: () => void;
}) {
  const me = useMe();
  const defs = applicable(useFieldDefs(props.entity), props.entity, props.orgId, props.custom);
  const [editing, setEditing] = useState(false);
  if (defs.length === 0) return null;
  const currency = me.orgs.find((o) => o.id === props.orgId)?.currency ?? 'EUR';
  const editable = defs.filter((d) => d.can_edit && !d.archived_at);
  const missing = defs.filter((d) => d.is_required && !d.archived_at && props.custom[d.key] === undefined);

  // po sekciách (bez sekcie = „Ďalšie údaje“)
  const sections = new Map<string, FieldDef[]>();
  for (const d of defs) {
    const name = d.section_name ?? 'Ďalšie údaje';
    sections.set(name, [...(sections.get(name) ?? []), d]);
  }

  return (
    <>
      {[...sections.entries()].map(([name, fields], i) => (
        <Card
          key={name}
          title={name}
          aside={
            i === 0 && props.canEditRecord && editable.length > 0 ? (
              <button type="button" className="btn btn-ghost add-link" onClick={() => setEditing(true)}>
                Upraviť
              </button>
            ) : undefined
          }
        >
          <Rows
            stacked
            rows={fields.map((d) => [
              d.label + (d.archived_at ? ' (archivované)' : ''),
              formatCustom(d, props.custom[d.key], props.refs, currency),
            ])}
          />
          {i === 0 && missing.length > 0 && (
            <div className="caption missing-note">Chýba povinné: {missing.map((d) => d.label).join(', ')}</div>
          )}
        </Card>
      ))}
      {editing && (
        <CustomFieldsPanel
          entity={props.entity}
          recordId={props.recordId}
          defs={editable}
          custom={props.custom}
          refs={props.refs}
          currency={currency}
          onClose={() => setEditing(false)}
          onSaved={() => {
            setEditing(false);
            props.onSaved();
          }}
        />
      )}
    </>
  );
}

function CustomFieldsPanel(props: {
  entity: 'firma' | 'osoba' | 'oom';
  recordId: string;
  defs: FieldDef[];
  custom: Record<string, unknown>;
  refs: RefLabel[];
  currency: string;
  onClose: () => void;
  onSaved: () => void;
}) {
  const [values, setValues] = useState<Record<string, unknown>>(() =>
    Object.fromEntries(props.defs.map((d) => [d.key, props.custom[d.key] ?? null])),
  );
  const [local, setLocal] = useState<string | null>(null);
  const save = useSave();
  const set = (key: string, v: unknown) => setValues((x) => ({ ...x, [key]: v }));

  const submit = async () => {
    const empty = (v: unknown) => v === null || v === '' || (Array.isArray(v) && v.length === 0);
    const missing = props.defs.filter((d) => d.is_required && empty(values[d.key]));
    if (missing.length) {
      setLocal(`Vyplňte povinné: ${missing.map((d) => d.label).join(', ')}.`);
      return;
    }
    setLocal(null);
    const changed = Object.fromEntries(
      Object.entries(values).filter(([k, v]) => JSON.stringify(v ?? null) !== JSON.stringify(props.custom[k] ?? null)),
    );
    if (Object.keys(changed).length === 0) return props.onClose();
    const ok = await save.run(() =>
      send('PATCH', `/api/${CUSTOM_PATH[props.entity]}/${props.recordId}/custom`, { values: changed }),
    );
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title="Ďalšie údaje"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" onClick={submit} disabled={save.busy}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        {props.defs.map((d) => (
          <Field key={d.key} label={d.label + (d.is_required ? ' *' : '')} wide>
            <CustomInput def={d} value={values[d.key]} onChange={(v) => set(d.key, v)} refs={props.refs} currency={props.currency} />
          </Field>
        ))}
      </div>
      <p className="caption">* povinné. Polia, ktoré váš tím nesmie meniť, tu nie sú.</p>
      {(local || save.error) && <Notice tone="error">{local ?? save.error}</Notice>}
    </SidePanel>
  );
}

function CustomInput(props: { def: FieldDef; value: unknown; onChange: (v: unknown) => void; refs: RefLabel[]; currency: string }) {
  const d = props.def;
  const v = props.value;
  const visible = d.options.filter((o) => !o.hidden_at || o.id === v || (Array.isArray(v) && v.includes(o.id)));
  switch (d.field_type) {
    case 'dlhy_text':
      return <textarea className="inp" rows={3} value={(v as string) ?? ''} maxLength={5000} onChange={(e) => props.onChange(e.target.value)} />;
    case 'cislo':
    case 'suma':
      return (
        <span className="hours-time">
          <input
            className="inp"
            type="number"
            step="any"
            value={v === null || v === undefined ? '' : String(v)}
            onChange={(e) => props.onChange(e.target.value === '' ? null : Number(e.target.value))}
          />
          {d.field_type === 'suma' && <span className="caption">{props.currency}</span>}
        </span>
      );
    case 'datum':
      return <input className="inp" type="date" value={(v as string) ?? ''} onChange={(e) => props.onChange(e.target.value || null)} />;
    case 'ano_nie':
      return (
        <Select
          value={v === true ? 'ano' : v === false ? 'nie' : ''}
          onChange={(x) => props.onChange(x === 'ano' ? true : x === 'nie' ? false : null)}
          options={[
            { value: '', label: 'Nevyplnené' },
            { value: 'ano', label: 'Áno' },
            { value: 'nie', label: 'Nie' },
          ]}
        />
      );
    case 'vyber':
      return (
        <Select
          value={(v as string) ?? ''}
          onChange={(x) => props.onChange(x || null)}
          options={[{ value: '', label: 'Nevyplnené' }, ...visible.map((o) => ({ value: o.id, label: o.label + (o.hidden_at ? ' (skrytá)' : '') }))]}
        />
      );
    case 'vyber_viac': {
      const list = Array.isArray(v) ? (v as string[]) : [];
      return (
        <div className="check-stack">
          {visible.map((o) => (
            <Check key={o.id} checked={list.includes(o.id)} onChange={(on) => props.onChange(on ? [...list, o.id] : list.filter((x) => x !== o.id))}>
              {o.label}
              {o.hidden_at ? ' (skrytá)' : ''}
            </Check>
          ))}
        </div>
      );
    }
    case 'odkaz':
      return <RefInput def={d} value={(v as string) ?? null} onChange={props.onChange} refs={props.refs} />;
    default:
      return <TextInput value={(v as string) ?? ''} onChange={(x) => props.onChange(x)} maxLength={500} />;
  }
}

type Hit = { id: string; name: string };

function RefInput(props: { def: FieldDef; value: string | null; onChange: (v: unknown) => void; refs: RefLabel[] }) {
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<Hit[]>([]);
  const [picked, setPicked] = useState<string | null>(props.refs.find((r) => r.id === props.value)?.label ?? null);
  const target = props.def.ref_entity;
  const searchable = target === 'firma' || target === 'osoba';
  useEffect(() => {
    if (!searchable || q.trim().length < 2) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<{ items: Hit[] }>(`/api/${target === 'firma' ? 'companies' : 'persons'}/search?q=${encodeURIComponent(q)}`, ctrl.signal)
        .then((r) => setHits(r.items))
        .catch(() => undefined);
    }, 300);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q, target, searchable]);
  if (!searchable) return <span className="caption">Odkaz na tento typ záznamu sa dá vybrať, keď bude hotový jeho modul.</span>;
  if (props.value) {
    return (
      <span className="picked">
        {picked ?? '(odkaz)'}{' '}
        <button type="button" className="btn btn-ghost" onClick={() => { props.onChange(null); setPicked(null); }}>
          Zmeniť
        </button>
      </span>
    );
  }
  return (
    <>
      <TextInput value={q} onChange={setQ} placeholder={target === 'firma' ? 'Hľadať firmu' : 'Hľadať osobu'} />
      {hits.length > 0 && (
        <div className="pick-list">
          {hits.map((h) => (
            <button key={h.id} type="button" className="pick-item" onClick={() => { props.onChange(h.id); setPicked(h.name); }}>
              {h.name}
            </button>
          ))}
        </div>
      )}
    </>
  );
}

// --- Zoznamy: filtre podľa polí „dá sa filtrovať“ ---------------------------------------------

/** Ovládače filtrov; hodnota je objekt { kľúč: text } (posiela sa ako ?cf=JSON). */
export function CustomFilters(props: { defs: FieldDef[]; value: Record<string, string>; onChange: (v: Record<string, string>) => void }) {
  const defs = props.defs.filter((d) => d.filterable && !d.archived_at);
  if (defs.length === 0) return null;
  const set = (key: string, v: string) => {
    const next = { ...props.value };
    if (v) next[key] = v;
    else delete next[key];
    props.onChange(next);
  };
  return (
    <>
      {defs.map((d) => {
        const v = props.value[d.key] ?? '';
        if (d.field_type === 'ano_nie') {
          return (
            <select key={d.key} className="input" aria-label={d.label} value={v} onChange={(e) => set(d.key, e.target.value)}>
              <option value="">{d.label}: všetky</option>
              <option value="true">{d.label}: áno</option>
              <option value="false">{d.label}: nie</option>
            </select>
          );
        }
        if (d.field_type === 'vyber' || d.field_type === 'vyber_viac') {
          return (
            <select key={d.key} className="input" aria-label={d.label} value={v} onChange={(e) => set(d.key, e.target.value)}>
              <option value="">{d.label}: všetky</option>
              {d.options.filter((o) => !o.hidden_at).map((o) => (
                <option key={o.id} value={o.id}>
                  {o.label}
                </option>
              ))}
            </select>
          );
        }
        if (d.field_type === 'odkaz') return null;
        return (
          <input
            key={d.key}
            className="input"
            type={d.field_type === 'datum' ? 'date' : 'text'}
            placeholder={d.label}
            aria-label={d.label}
            defaultValue={v}
            onBlur={(e) => set(d.key, e.target.value.trim())}
            onKeyDown={(e) => e.key === 'Enter' && set(d.key, (e.target as HTMLInputElement).value.trim())}
          />
        );
      })}
    </>
  );
}
