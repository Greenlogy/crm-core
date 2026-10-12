// Nastavenia – Pipelines a stage (dizajn 15). Konkrétne pipelines a stage navrhne modul Obchod;
// tu sa dajú pridať, premenovať, zoradiť a archivovať. Druh obchodu je jadro (nemení sa).

import { useState } from 'react';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { useMe } from '../../lib/me';
import {
  DEAL_CORE_FIELD_LABEL,
  DEAL_KINDS,
  type DealKind,
  type Outcome,
  OUTCOMES,
  type Pipeline,
  type Stage,
} from '../../lib/settings';
import { InlineLabel } from './LookupsPage';
import { SettingsHead } from './SettingsLayout';

type PipelinesData = { items: Pipeline[]; core_fields: string[]; deal_custom_fields: { id: string; label: string }[] };

const OUTCOME_TONE: Record<Outcome, 'neutral' | 'positive' | 'negative'> = { otvoreny: 'neutral', vyhrany: 'positive', prehrany: 'negative' };

export function PipelinesPage() {
  const data = useApi<PipelinesData>('/api/settings/pipelines');
  const [selected, setSelected] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const list = data.data?.items ?? [];
  const pipeline = list.find((p) => p.id === selected) ?? list.find((p) => !p.archived_at) ?? list[0];

  if (data.error) return <ErrorState error={data.error} />;
  return (
    <>
      <SettingsHead title="Pipelines a stage" sub="pre modul Obchod" />
      <Notice tone="ok">Konkrétne pipelines a stage sa navrhnú v module Obchod. Tu sa dajú pripraviť a upraviť.</Notice>
      {!data.data ? (
        <Skeleton lines={5} />
      ) : (
        <>
          <div className="team-tiles" role="tablist" aria-label="Pipelines">
            {list.map((p) => (
              <button
                key={p.id}
                type="button"
                role="tab"
                aria-selected={p.id === pipeline?.id}
                className={`team-tile${p.id === pipeline?.id ? ' active' : ''}${p.archived_at ? ' archived' : ''}`}
                onClick={() => setSelected(p.id)}
              >
                <span className="team-tile-name">{p.name}</span>
                <span className="caption">
                  {p.archived_at ? 'archivovaná' : (p.org_name ?? 'celá skupina')} · {p.deals} dealov
                </span>
              </button>
            ))}
            <button type="button" className="team-tile team-tile-new" onClick={() => setCreating(true)}>
              + Nová pipeline
            </button>
          </div>
          {pipeline ? (
            <PipelineDetail key={pipeline.id} pipeline={pipeline} data={data.data} onChanged={data.reload} />
          ) : (
            <div className="card">
              <div className="empty">Zatiaľ žiadna pipeline.</div>
            </div>
          )}
        </>
      )}
      {creating && (
        <NewPipelinePanel
          onClose={() => setCreating(false)}
          onCreated={(id) => {
            setCreating(false);
            setSelected(id);
            data.reload();
          }}
        />
      )}
    </>
  );
}

function PipelineDetail(props: { pipeline: Pipeline; data: PipelinesData; onChanged: () => void }) {
  const p = props.pipeline;
  const save = useSave();
  const [stageName, setStageName] = useState('');
  const [requiredFor, setRequiredFor] = useState<Stage | null>(null);
  const stages = p.stages.filter((s) => !s.archived_at);
  const archivedStages = p.stages.filter((s) => s.archived_at);

  const run = async (fn: () => Promise<unknown>) => {
    const ok = await save.run(async () => {
      await fn();
      return true;
    });
    if (ok) props.onChanged();
  };
  const move = (i: number, dir: -1 | 1) => {
    const ids = stages.map((s) => s.id);
    const j = i + dir;
    if (j < 0 || j >= ids.length) return;
    [ids[i], ids[j]] = [ids[j], ids[i]];
    void run(() => send('PATCH', `/api/settings/pipelines/${p.id}/stage-order`, { ids: [...ids, ...archivedStages.map((s) => s.id)] }));
  };

  return (
    <section className="card" aria-label={p.name}>
      <div className="card-head team-head">
        <div>
          <h2 className="t-section-title">
            <InlineLabel value={p.name} onSave={(name) => void run(() => send('PATCH', `/api/settings/pipelines/${p.id}`, { name }))} />
          </h2>
          <div className="caption">
            {DEAL_KINDS.find((k) => k.value === p.kind)?.label} · {p.org_name ?? 'celá skupina'} · poradie meníš šípkami
          </div>
        </div>
        <button
          type="button"
          className="btn"
          disabled={save.busy}
          onClick={() => void run(() => send('PATCH', `/api/settings/pipelines/${p.id}`, { archived: !p.archived_at }))}
        >
          {p.archived_at ? 'Obnoviť pipeline' : 'Archivovať pipeline'}
        </button>
      </div>
      <div className="table-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th>Poradie</th>
              <th>Stage</th>
              <th>Pravdepodobnosť</th>
              <th>Typ</th>
              <th>Povinné pri prechode</th>
              <th />
            </tr>
          </thead>
          <tbody>
            {stages.map((s, i) => (
              <tr key={s.id}>
                <td>
                  <span className="order-buttons">
                    <button type="button" className="btn btn-ghost" aria-label="Vyššie" disabled={i === 0 || save.busy} onClick={() => move(i, -1)}>
                      ↑
                    </button>
                    <button type="button" className="btn btn-ghost" aria-label="Nižšie" disabled={i === stages.length - 1 || save.busy} onClick={() => move(i, 1)}>
                      ↓
                    </button>
                  </span>
                </td>
                <td>
                  <InlineLabel value={s.name} onSave={(name) => void run(() => send('PATCH', `/api/settings/stages/${s.id}`, { name }))} />
                </td>
                <td>
                  <input
                    key={`${s.id}-${s.probability}`}
                    className="inp prob-input"
                    type="number"
                    min={0}
                    max={100}
                    aria-label={`${s.name} – pravdepodobnosť %`}
                    defaultValue={s.probability === null ? '' : Math.round(Number(s.probability) * 100)}
                    onBlur={(e) => {
                      const v = e.target.value === '' ? null : Number(e.target.value);
                      const cur = s.probability === null ? null : Math.round(Number(s.probability) * 100);
                      if (v !== cur) void run(() => send('PATCH', `/api/settings/stages/${s.id}`, { probability: v }));
                    }}
                  />{' '}
                  %
                </td>
                <td>
                  <select
                    className="inp outcome-select"
                    aria-label={`${s.name} – typ`}
                    value={s.outcome}
                    onChange={(e) => void run(() => send('PATCH', `/api/settings/stages/${s.id}`, { outcome: e.target.value }))}
                  >
                    {OUTCOMES.map((o) => (
                      <option key={o.value} value={o.value}>
                        {o.label}
                      </option>
                    ))}
                  </select>{' '}
                  <Pill tone={OUTCOME_TONE[s.outcome]}>{OUTCOMES.find((o) => o.value === s.outcome)?.label}</Pill>
                </td>
                <td>
                  <button type="button" className="link-button name-link" onClick={() => setRequiredFor(s)}>
                    {s.required.length
                      ? s.required.map((r) => (r.core_field ? DEAL_CORE_FIELD_LABEL[r.core_field] ?? r.core_field : r.label)).join(', ')
                      : '–'}
                  </button>
                </td>
                <td className="num">
                  <button
                    type="button"
                    className="btn btn-ghost"
                    disabled={save.busy}
                    title={s.deals ? `Na stage je ${s.deals} dealov; archivovaná stage sa pri nových dealoch neponúkne.` : undefined}
                    onClick={() => void run(() => send('PATCH', `/api/settings/stages/${s.id}`, { archived: true }))}
                  >
                    Archivovať
                  </button>
                </td>
              </tr>
            ))}
            {archivedStages.map((s) => (
              <tr key={s.id} className="row-muted">
                <td />
                <td>{s.name}</td>
                <td colSpan={3} className="caption">
                  archivovaná
                </td>
                <td className="num">
                  <button type="button" className="btn btn-ghost" onClick={() => void run(() => send('PATCH', `/api/settings/stages/${s.id}`, { archived: false }))}>
                    Obnoviť
                  </button>
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
            placeholder="Nová stage"
            aria-label="Nová stage"
            value={stageName}
            maxLength={80}
            onChange={(e) => setStageName(e.target.value)}
          />
          <button
            type="button"
            className="btn"
            disabled={!stageName.trim() || save.busy}
            onClick={() =>
              void run(async () => {
                await send('POST', `/api/settings/pipelines/${p.id}/stages`, { name: stageName });
                setStageName('');
              })
            }
          >
            + Pridať stage
          </button>
        </div>
        {save.error && <Notice tone="error">{save.error}</Notice>}
        <p className="caption">Stage ani pipeline sa nemažú, iba archivujú – dealy na nich ostávajú.</p>
      </div>
      {requiredFor && (
        <RequiredPanel stage={requiredFor} data={props.data} onClose={() => setRequiredFor(null)} onSaved={() => { setRequiredFor(null); props.onChanged(); }} />
      )}
    </section>
  );
}

function RequiredPanel(props: { stage: Stage; data: PipelinesData; onClose: () => void; onSaved: () => void }) {
  const [core, setCore] = useState<string[]>(props.stage.required.flatMap((r) => (r.core_field ? [r.core_field] : [])));
  const [custom, setCustom] = useState<string[]>(props.stage.required.flatMap((r) => (r.custom_field_id ? [r.custom_field_id] : [])));
  const save = useSave();
  const toggle = (list: string[], v: string, on: boolean) => (on ? [...list, v] : list.filter((x) => x !== v));
  const submit = async () => {
    const ok = await save.run(() =>
      send('PATCH', `/api/settings/stages/${props.stage.id}/required`, { core_fields: core, custom_field_ids: custom }),
    );
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Povinné pri prechode do „${props.stage.name}“`}
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
      <fieldset className="fieldset">
        <legend>Polia dealu</legend>
        {props.data.core_fields.map((f) => (
          <Check key={f} checked={core.includes(f)} onChange={(on) => setCore(toggle(core, f, on))}>
            {DEAL_CORE_FIELD_LABEL[f] ?? f}
          </Check>
        ))}
      </fieldset>
      <fieldset className="fieldset">
        <legend>Vlastné polia dealu</legend>
        {props.data.deal_custom_fields.length === 0 && <span className="caption">Deal zatiaľ nemá vlastné polia.</span>}
        {props.data.deal_custom_fields.map((f) => (
          <Check key={f.id} checked={custom.includes(f.id)} onChange={(on) => setCustom(toggle(custom, f.id, on))}>
            {f.label}
          </Check>
        ))}
      </fieldset>
      <p className="caption">Kontroluje sa pri presune dealu do tejto stage (modul Obchod).</p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function NewPipelinePanel(props: { onClose: () => void; onCreated: (id: string) => void }) {
  const me = useMe();
  const [name, setName] = useState('');
  const [kind, setKind] = useState<DealKind | ''>('');
  const [orgId, setOrgId] = useState('');
  const save = useSave();
  const submit = async () => {
    const r = await save.run(() => send<{ id: string }>('POST', '/api/settings/pipelines', { name, kind, org_id: orgId || null }));
    if (r) props.onCreated(r.id);
  };
  return (
    <SidePanel
      title="Nová pipeline"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!name.trim() || !kind || save.busy} onClick={submit}>
            Založiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Názov" wide>
          <TextInput value={name} onChange={setName} autoFocus maxLength={80} />
        </Field>
        <Field label="Druh obchodu" wide hint="Jadro CRM: určuje napr. príznak výrobca; po založení sa nemení.">
          <Select value={kind} onChange={setKind} options={DEAL_KINDS} placeholder="Vybrať…" />
        </Field>
        <Field label="Spoločnosť" wide>
          <Select value={orgId} onChange={setOrgId} options={[{ value: '', label: 'Celá skupina' }, ...me.orgs.map((o) => ({ value: o.id, label: o.name }))]} />
        </Field>
      </div>
      <p className="caption">Nová pipeline dostane stage Nový, Vyhraný a Prehraný; ďalšie pridáte potom.</p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
