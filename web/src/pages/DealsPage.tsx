// Obchody – pipeline (dizajn 32; zadanie časti 3, 4 a 13). Kanban podľa štádií a zoznam s filtrami, súčty
// pridanej hodnoty a vážená PH podľa pravdepodobnosti. Do ponúk (F2) je PH odhad zadaný na obchode.
// Interní aj externí obchodníci majú tú istú obrazovku; koho obchody vidia, rozhoduje databáza.

import { useMemo, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { NewDealPanel, RiskPills } from '../components/deal-forms';
import { Select, TextInput } from '../components/form';
import { Card, ErrorState, Kpi, Pill, Skeleton } from '../components/ui';
import { useApi, type Owner } from '../lib/api';
import { type DealOptions, type DealRow, OUTCOME_TONE, STEP_STATE } from '../lib/deals';
import { date, eur, num, text } from '../lib/format';

type View = 'kanban' | 'zoznam';
const STEP_FILTER: [string, string][] = [
  ['', 'Všetky kroky'],
  ['bez_alebo_po', 'Bez kroku alebo po termíne'],
  ['dnes', 'Krok dnes'],
  ['bez_kroku', 'Bez ďalšieho kroku'],
  ['po_termine', 'Po termíne'],
];

const money = (v: string | number | null | undefined) => (v === null || v === undefined ? '–' : `${eur(v)} €`);

export function DealsPage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const { data: opts } = useApi<DealOptions>('/api/deals/options');
  const { data: owners } = useApi<Owner[]>('/api/deals/owners');
  const pipeline = params.get('pipeline') ?? '';
  const owner = params.get('owner') ?? '';
  const step = params.get('step') ?? '';
  const view = (params.get('view') as View) || 'kanban';
  const [q, setQ] = useState('');
  const [creating, setCreating] = useState(false);
  const activePipeline = opts?.pipelines.find((p) => p.id === pipeline) ?? opts?.pipelines[0];
  const query = new URLSearchParams({
    ...(activePipeline ? { pipeline: activePipeline.id } : {}),
    ...(owner ? { owner } : {}),
    ...(step ? { step } : {}),
    ...(q.trim().length >= 2 ? { q: q.trim() } : {}),
    closed: 'mesiac',
  });
  const { data, error } = useApi<{ items: DealRow[] }>(activePipeline ? `/api/deals?${query}` : '/api/deals?closed=mesiac&pipeline=');
  const set = (k: string, v: string) => {
    const p = new URLSearchParams(params);
    if (v) p.set(k, v);
    else p.delete(k);
    setParams(p, { replace: true });
  };

  const items = data?.items ?? [];
  const open = items.filter((d) => !d.closed_at);
  const kpi = useMemo(() => {
    const sum = open.reduce((s, d) => s + Number(d.value_eur ?? 0), 0);
    const weighted = open.reduce((s, d) => s + Number(d.weighted_eur ?? 0), 0);
    const attention = open.filter((d) => d.step_state === 'bez_kroku' || d.step_state === 'po_termine').length;
    return { count: open.length, sum, weighted, attention };
  }, [items]);

  if (error) return <ErrorState error={error} />;

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Obchody</h1>
          <div className="page-sub">
            <span>pipeline od príležitosti po vyhratý obchod</span>
          </div>
        </div>
        <div className="head-actions">
          <Link className="btn" to="/overenie-firmy">
            Overiť firmu
          </Link>
          <button type="button" className="btn primary" onClick={() => setCreating(true)}>
            Nový obchod
          </button>
        </div>
      </header>
      {creating && (
        <NewDealPanel
          onClose={() => setCreating(false)}
          onSaved={(id) => navigate(`/obchody/${id}`)}
        />
      )}

      <div className="tabs" role="tablist" aria-label="Pipelines">
        {(opts?.pipelines ?? []).map((p) => (
          <button key={p.id} type="button" role="tab" className="tab" aria-selected={p.id === activePipeline?.id} onClick={() => set('pipeline', p.id)}>
            {p.name}
          </button>
        ))}
      </div>

      <div className="kpis" style={{ marginBottom: 16 }}>
        <Kpi label="Otvorené obchody" value={data ? num(kpi.count, 0) : ''} />
        <Kpi label="Pridaná hodnota otvorených" value={data ? `${eur(kpi.sum)} €` : ''} sub="do ponúk odhad na obchode" />
        <Kpi label="Vážená PH" value={data ? `${eur(kpi.weighted)} €` : ''} sub="PH × pravdepodobnosť štádia" />
        <Kpi label="Bez kroku / po termíne" value={data ? num(kpi.attention, 0) : ''} />
      </div>

      <Card flush label="Obchody">
        <div className="toolbar chips-bar" style={{ gap: 8, flexWrap: 'wrap' }}>
          <div className="chips" role="group" aria-label="Zobrazenie">
            <button type="button" className="chip" aria-pressed={view === 'kanban'} onClick={() => set('view', '')}>
              Kanban
            </button>
            <button type="button" className="chip" aria-pressed={view === 'zoznam'} onClick={() => set('view', 'zoznam')}>
              Zoznam
            </button>
          </div>
          <div style={{ minWidth: 180 }}>
            <Select
              value={owner}
              onChange={(v) => set('owner', v === 'vsetci' ? '' : v)}
              placeholder="Vlastník: všetci"
              options={[{ value: 'vsetci', label: 'Všetci' }, { value: 'ja', label: 'Ja' }, ...(owners ?? []).map((o) => ({ value: o.id, label: o.name }))]}
            />
          </div>
          <div style={{ minWidth: 200 }}>
            <Select value={step} onChange={(v) => set('step', v)} options={STEP_FILTER.map(([value, label]) => ({ value, label }))} />
          </div>
          <div style={{ minWidth: 220 }}>
            <TextInput value={q} onChange={setQ} placeholder="Hľadať obchod, firmu, IČO…" />
          </div>
        </div>
        {!data || !activePipeline ? (
          <div style={{ padding: 16 }}>
            <Skeleton lines={6} />
          </div>
        ) : view === 'kanban' ? (
          <Kanban items={items} stages={activePipeline.stages} />
        ) : (
          <DealTable items={items} />
        )}
      </Card>
    </>
  );
}

function Kanban(props: { items: DealRow[]; stages: DealOptions['pipelines'][number]['stages'] }) {
  return (
    <div className="kanban">
      {props.stages.map((s) => {
        const col = props.items.filter((d) => d.stage_id === s.id);
        const sum = col.reduce((t, d) => t + Number(d.value_eur ?? 0), 0);
        return (
          <section key={s.id} className="kanban-col" aria-label={s.name}>
            <div className="kanban-head">
              <strong>{s.name}</strong>
              <span className="caption">
                {num(col.length, 0)} · {eur(sum)} €{s.probability !== null ? ` · ${Math.round(Number(s.probability) * 100)} %` : ''}
              </span>
            </div>
            {s.outcome !== 'otvoreny' && <div className="caption" style={{ padding: '0 8px 6px' }}>uzavreté tento mesiac</div>}
            {col.map((d) => (
              <Link key={d.id} to={`/obchody/${d.id}`} className="kanban-card">
                <div className="kanban-title">{d.name}</div>
                <div className="caption">{text(d.customer_name)}</div>
                <div className="kanban-meta">
                  <span>{d.value_eur === null ? '–' : `≈ ${eur(d.value_eur)} €`}</span>
                  {d.step_state && d.step_state !== 'planovany' ? (
                    <Pill tone={STEP_STATE[d.step_state].tone}>{d.step_state === 'dnes' ? 'krok dnes' : STEP_STATE[d.step_state].label}</Pill>
                  ) : d.next_step_on ? (
                    <span className="caption">{date(d.next_step_on)}</span>
                  ) : null}
                </div>
                <div className="kanban-meta">
                  <span className="caption">{text(d.owner_name)}</span>
                  {d.source_code === 'obnova' && <Pill tone="info">Obnova</Pill>}
                  {d.lost_reason_label && <Pill tone="negative">{d.lost_reason_label}</Pill>}
                </div>
                <RiskPills risk={d.risk} compact />
              </Link>
            ))}
          </section>
        );
      })}
    </div>
  );
}

function DealTable(props: { items: DealRow[] }) {
  return (
    <div className="table-wrap">
      <table className="tbl">
        <thead>
          <tr>
            <th>Obchod</th>
            <th>Štádium</th>
            <th>Vlastník</th>
            <th>Zdroj</th>
            <th>Ďalší krok</th>
            <th>Očakávané uzavretie</th>
            <th className="num">PH [€]</th>
            <th className="num">Vážená PH [€]</th>
          </tr>
        </thead>
        <tbody>
          {props.items.length === 0 && (
            <tr>
              <td colSpan={8} className="muted">
                Žiadny obchod.
              </td>
            </tr>
          )}
          {props.items.map((d) => (
            <tr key={d.id} className={d.step_state === 'po_termine' || d.step_state === 'bez_kroku' ? 'row-attention' : undefined}>
              <td>
                <Link to={`/obchody/${d.id}`}>{d.name}</Link>
                <div className="sub">
                  {text(d.customer_name)} <RiskPills risk={d.risk} compact />
                </div>
              </td>
              <td>
                <Pill tone={OUTCOME_TONE[d.stage_outcome]}>{d.stage_name}</Pill>
              </td>
              <td>{text(d.owner_name)}</td>
              <td>{text(d.source_label)}</td>
              <td>
                {d.next_step ? (
                  <>
                    {d.next_step}
                    <div className="sub">{date(d.next_step_on)}</div>
                  </>
                ) : (
                  '–'
                )}
                {d.step_state && d.step_state !== 'planovany' && d.step_state !== 'dnes' && (
                  <div>
                    <Pill tone={STEP_STATE[d.step_state].tone}>{STEP_STATE[d.step_state].label}</Pill>
                  </div>
                )}
              </td>
              <td>{date(d.expected_close)}</td>
              <td className="num">{money(d.value_eur)}</td>
              <td className="num">{money(d.weighted_eur)}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
