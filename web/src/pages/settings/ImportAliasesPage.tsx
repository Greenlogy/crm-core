// Nastavenia – Preklady importov (modul 4, F1a; migrácia 0023). Iba admin.
// Názov z exportu Office portálu alebo XM Trade (sadzba, produkt, PDS, obchodník…) → hodnota CRM.
// Veľké písmená, medzery, diakritika a rok v názve produktu sa neberú do úvahy. Systémové preklady (z migrácie)
// sa nemažú ani nemenia, iba skryjú. Neznámy názov v importe = chyba riadku s ponukou „pridať preklad“ (F2).

import { useMemo, useState } from 'react';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { EMPTY } from '../../lib/format';
import { SettingsHead } from './SettingsLayout';

type Kind = 'produkt_op' | 'produkt_oom' | 'sadzba' | 'pds' | 'obchodnik' | 'typ_merania' | 'fakturacne_obdobie' | 'sposob_zaloh' | 'iny';
type Source = 'office_portal' | 'xm_trade' | 'vsetky';
type Option = { value: string; label: string };
type Alias = {
  id: string;
  source: Source;
  kind: Kind;
  name_sample: string;
  target: string;
  target_extra: Record<string, unknown>;
  is_system: boolean;
  hidden_at: string | null;
  created_by_name: string | null;
};
type Data = { items: Alias[]; targets: Record<Kind, Option[]> };

const KINDS: { value: Kind; label: string }[] = [
  { value: 'produkt_op', label: 'Cenový produkt (Office portal)' },
  { value: 'produkt_oom', label: 'Produkt pri OOM' },
  { value: 'sadzba', label: 'Sadzba distribúcie' },
  { value: 'pds', label: 'PDS' },
  { value: 'obchodnik', label: 'Obchodník' },
  { value: 'typ_merania', label: 'Typ merania' },
  { value: 'fakturacne_obdobie', label: 'Fakturačné obdobie' },
  { value: 'sposob_zaloh', label: 'Spôsob záloh' },
  { value: 'iny', label: 'Iné' },
];
const KIND_LABEL = Object.fromEntries(KINDS.map((k) => [k.value, k.label])) as Record<Kind, string>;
const SOURCES: { value: Source; label: string }[] = [
  { value: 'office_portal', label: 'Office portal' },
  { value: 'xm_trade', label: 'XM Trade' },
  { value: 'vsetky', label: 'Oba importy' },
];
const SOURCE_LABEL = Object.fromEntries(SOURCES.map((s) => [s.value, s.label])) as Record<Source, string>;

export function ImportAliasesPage() {
  const data = useApi<Data>('/api/settings/import-aliases');
  const [kind, setKind] = useState<Kind | ''>('');
  const [showHidden, setShowHidden] = useState(false);
  const [adding, setAdding] = useState(false);
  const save = useSave();

  const targetLabel = useMemo(() => {
    const map = new Map<string, string>();
    for (const [k, opts] of Object.entries(data.data?.targets ?? {})) for (const o of opts) map.set(`${k}:${o.value}`, o.label);
    return (a: Alias) => map.get(`${a.kind}:${a.target}`) ?? a.target;
  }, [data.data]);

  if (data.error) return <ErrorState error={data.error} />;
  const items = (data.data?.items ?? []).filter((a) => (kind === '' || a.kind === kind) && (showHidden || !a.hidden_at));

  const act = async (fn: () => Promise<unknown>) => {
    if (await save.run(fn)) data.reload();
  };

  return (
    <>
      <SettingsHead
        title="Preklady importov"
        sub="názov z Office portálu a XM Trade → hodnota v CRM"
        actions={
          <button type="button" className="btn primary" onClick={() => setAdding(true)}>
            Pridať preklad
          </button>
        }
      />
      <div className="toolbar">
        <Select value={kind} onChange={(v) => setKind(v as Kind | '')} options={[{ value: '', label: 'Všetky druhy' }, ...KINDS]} />
        <Check checked={showHidden} onChange={setShowHidden}>
          aj skryté
        </Check>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {!data.data ? (
        <Skeleton lines={6} />
      ) : (
        <section className="card" aria-label="Preklady">
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Názov z importu</th>
                  <th>Druh</th>
                  <th>Import</th>
                  <th>Hodnota v CRM</th>
                  <th>Pôvod</th>
                  <th />
                </tr>
              </thead>
              <tbody>
                {items.map((a) => (
                  <tr key={a.id} className={a.hidden_at ? 'muted' : undefined}>
                    <td className="strong">{a.name_sample}</td>
                    <td>{KIND_LABEL[a.kind]}</td>
                    <td>{SOURCE_LABEL[a.source]}</td>
                    <td>
                      {targetLabel(a)}
                      {typeof a.target_extra.tariff === 'string' && <span className="caption"> · {String(a.target_extra.tariff).toUpperCase().replace('_', ' ')}</span>}
                      {typeof a.target_extra.kontrola === 'string' && <span className="caption"> · na kontrolu</span>}
                    </td>
                    <td>
                      {a.is_system ? <Pill tone="neutral">systémový</Pill> : (a.created_by_name ?? EMPTY)}
                      {a.hidden_at && <> <Pill tone="warning">skrytý</Pill></>}
                    </td>
                    <td className="actions">
                      <button
                        type="button"
                        className="link-button"
                        disabled={save.busy}
                        onClick={() => act(() => send('PATCH', `/api/settings/import-aliases/${a.id}`, { hidden: !a.hidden_at }))}
                      >
                        {a.hidden_at ? 'Obnoviť' : 'Skryť'}
                      </button>
                      {!a.is_system && (
                        <>
                          {' · '}
                          <button
                            type="button"
                            className="link-button"
                            disabled={save.busy}
                            onClick={() => act(() => send('DELETE', `/api/settings/import-aliases/${a.id}`))}
                          >
                            Zmazať
                          </button>
                        </>
                      )}
                    </td>
                  </tr>
                ))}
                {items.length === 0 && (
                  <tr>
                    <td colSpan={6} className="muted">
                      Žiadny preklad nezodpovedá filtru.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
          <div className="card-foot caption">
            Veľké písmená, medzery, diakritika a rok v názve produktu (GREEN_1T_INDIVIDUAL_2027) sa pri preklade neberú do
            úvahy. Sadzba sa prekladá bez PDS (D2 platí pre PDS odberného miesta). Systémové preklady sa dajú iba skryť.
          </div>
        </section>
      )}
      {adding && data.data && (
        <AddPanel
          targets={data.data.targets}
          onClose={() => setAdding(false)}
          onSaved={() => {
            setAdding(false);
            data.reload();
          }}
        />
      )}
    </>
  );
}

function AddPanel(props: { targets: Record<Kind, Option[]>; onClose: () => void; onSaved: () => void }) {
  const [source, setSource] = useState<Source>('vsetky');
  const [kind, setKind] = useState<Kind | ''>('');
  const [name, setName] = useState('');
  const [target, setTarget] = useState('');
  const save = useSave();
  const options = kind ? props.targets[kind] : [];

  const submit = async () => {
    const ok = await save.run(() => send('POST', '/api/settings/import-aliases', { source, kind, name_sample: name, target }));
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title="Pridať preklad"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !kind || !name || !target} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Import">
          <Select value={source} onChange={(v) => setSource(v as Source)} options={SOURCES} />
        </Field>
        <Field label="Druh">
          <Select
            value={kind}
            onChange={(v) => {
              setKind(v as Kind);
              setTarget('');
            }}
            placeholder="Vybrať druh"
            options={KINDS}
          />
        </Field>
        <Field label="Názov z importu" hint="presne, ako je v exporte" wide>
          <TextInput value={name} onChange={setName} maxLength={200} />
        </Field>
        <Field label="Hodnota v CRM" wide>
          {kind === 'iny' ? (
            <TextInput value={target} onChange={setTarget} maxLength={100} />
          ) : (
            <Select value={target} onChange={setTarget} placeholder="Vybrať hodnotu" disabled={!kind} options={options} />
          )}
        </Field>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
