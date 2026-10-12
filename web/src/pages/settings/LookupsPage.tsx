// Nastavenia – Číselníky (vzor obrazovky 14: zoznam + úprava). Hodnota sa nikdy nemaže, iba skryje;
// systémové hodnoty (zámok) sa nedajú premenovať ani skryť. Zoznamy zakladá iba migrácia.

import { useState } from 'react';
import { Check, Notice, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { useMe } from '../../lib/me';
import type { LookupList, LookupValue } from '../../lib/settings';
import { SettingsHead } from './SettingsLayout';

export function LookupsPage() {
  const lookups = useApi<{ items: LookupList[] }>('/api/settings/lookups');
  const [code, setCode] = useState<string | null>(null);
  const list = lookups.data?.items ?? [];
  const current = list.find((l) => l.code === code) ?? list[0];

  if (lookups.error) return <ErrorState error={lookups.error} />;
  return (
    <>
      <SettingsHead title="Číselníky" sub="hodnoty výberov; hodnota sa nemaže, iba skryje" />
      {!current ? (
        <Skeleton lines={5} />
      ) : (
        <div className="settings-columns">
          <nav className="card lookup-lists" aria-label="Číselníky">
            {list.map((l) => (
              <button
                key={l.code}
                type="button"
                className={`lookup-list-item${l.code === current.code ? ' active' : ''}`}
                onClick={() => setCode(l.code)}
              >
                <span>{l.name}</span>
                <span className="caption">
                  {l.values.filter((v) => !v.hidden_at).length} hodnôt{l.used_on ? ` · ${l.used_on}` : ''}
                </span>
              </button>
            ))}
          </nav>
          <LookupValues key={current.code} list={current} onChanged={lookups.reload} />
        </div>
      )}
    </>
  );
}

function LookupValues(props: { list: LookupList; onChanged: () => void }) {
  const me = useMe();
  const [label, setLabel] = useState('');
  const [orgId, setOrgId] = useState('');
  const [showHidden, setShowHidden] = useState(false);
  const save = useSave();
  const values = props.list.values.filter((v) => showHidden || !v.hidden_at);
  const hiddenCount = props.list.values.filter((v) => v.hidden_at).length;

  const add = async () => {
    const ok = await save.run(() =>
      send('POST', `/api/settings/lookups/${props.list.code}/values`, { label, org_id: orgId || null }),
    );
    if (ok) {
      setLabel('');
      props.onChanged();
    }
  };
  const patch = async (v: LookupValue, body: object) => {
    const ok = await save.run(() => send('PATCH', `/api/settings/lookup-values/${v.id}`, body));
    if (ok) props.onChanged();
  };

  return (
    <section className="card settings-col-main" aria-label={props.list.name}>
      <div className="card-head">
        <h2 className="t-section-title">{props.list.name}</h2>
        {hiddenCount > 0 && (
          <Check checked={showHidden} onChange={setShowHidden}>
            Aj skryté ({hiddenCount})
          </Check>
        )}
      </div>
      <div className="table-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th>Hodnota</th>
              <th>Kód</th>
              <th>Platí pre</th>
              <th>Stav</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {values.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">
                  Zatiaľ žiadna hodnota. Hodnoty z HubSpotu sa doplnia pri prevzatí dát.
                </td>
              </tr>
            )}
            {values.map((v) => (
              <tr key={v.id} className={v.hidden_at ? 'row-muted' : undefined}>
                <td>
                  {v.is_system ? (
                    <span className="lock-label">
                      {v.label} <span className="lock">🔒 jadro</span>
                    </span>
                  ) : (
                    <InlineLabel value={v.label} onSave={(l) => patch(v, { label: l })} />
                  )}
                </td>
                <td className="mono">{v.code}</td>
                <td>{v.org_name ?? 'Celá skupina'}</td>
                <td>{v.hidden_at ? <Pill>Skrytá</Pill> : <Pill tone="positive">Aktívna</Pill>}</td>
                <td className="num">
                  {!v.is_system && (
                    <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={() => patch(v, { hidden: !v.hidden_at })}>
                      {v.hidden_at ? 'Obnoviť' : 'Skryť'}
                    </button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="card-body">
        <div className="day-new">
          <input
            className="inp"
            placeholder="Nová hodnota"
            aria-label="Nová hodnota"
            value={label}
            maxLength={100}
            onChange={(e) => setLabel(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && label.trim() && void add()}
          />
          <select className="inp" aria-label="Platí pre" value={orgId} onChange={(e) => setOrgId(e.target.value)}>
            <option value="">Celá skupina</option>
            {me.orgs.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
          <button type="button" className="btn" disabled={!label.trim() || save.busy} onClick={add}>
            + Pridať hodnotu
          </button>
        </div>
        {save.error && <Notice tone="error">{save.error}</Notice>}
        <p className="caption">
          Skrytá hodnota sa nedá vybrať pri novom zázname, staré záznamy ju zobrazujú ďalej. Kód vznikne z názvu a už sa nemení.
        </p>
      </div>
    </section>
  );
}

/** Názov upraviteľný kliknutím; uloží sa Enterom alebo opustením poľa. */
export function InlineLabel(props: { value: string; onSave: (v: string) => void }) {
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(props.value);
  if (!editing) {
    return (
      <button type="button" className="link-button inline-edit" title="Premenovať" onClick={() => setEditing(true)}>
        {props.value}
      </button>
    );
  }
  const done = () => {
    setEditing(false);
    if (value.trim() && value.trim() !== props.value) props.onSave(value.trim());
    else setValue(props.value);
  };
  return (
    <input
      className="inp inline-input"
      autoFocus
      value={value}
      maxLength={100}
      onChange={(e) => setValue(e.target.value)}
      onBlur={done}
      onKeyDown={(e) => {
        if (e.key === 'Enter') done();
        if (e.key === 'Escape') {
          setValue(props.value);
          setEditing(false);
        }
      }}
    />
  );
}
