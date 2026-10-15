// Schvaľovanie (dizajn 39; zadanie časti 4.1 a 6). V F1 iba pridelenie firmy; výnimky z ceny, rizikový zákazník
// a predĺženie platnosti pribudnú s ponukami (F2). Kto žiadosť vidí a kto ju smie schváliť, stráži databáza:
// pridelenie firmy schvaľuje príznak „schvaľuje pridelenie firmy“, nikdy žiadateľ.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Field, Notice, useSave } from '../components/form';
import { Card, Empty, ErrorState, Rows, Skeleton, StatusPill } from '../components/ui';
import { send, useApi } from '../lib/api';
import { date, num, text } from '../lib/format';
import type { Tone } from '../lib/labels';

type Approval = {
  id: string;
  kind: 'vynimka_ceny' | 'rizikovy_zakaznik' | 'predlzenie_platnosti' | 'pridelenie_firmy';
  status: 'caka' | 'schvalena' | 'zamietnuta' | 'zrusena';
  reason: string;
  decision_note: string | null;
  created_at: string;
  decided_at: string | null;
  company_id: string | null;
  company_name: string | null;
  company_ico: string | null;
  requested_by_name: string | null;
  from_owner_name: string | null;
  decided_by_name: string | null;
  can_decide: boolean;
  can_cancel: boolean;
};
type Data = { items: Approval[]; counts: Record<string, number> };

const KIND: Record<Approval['kind'], string> = {
  vynimka_ceny: 'Výnimka z ceny',
  rizikovy_zakaznik: 'Konkurz / rating E/X',
  predlzenie_platnosti: 'Predĺženie platnosti',
  pridelenie_firmy: 'Pridelenie firmy',
};
const STATUS: Record<string, { label: string; tone: Tone }> = {
  caka: { label: 'Čaká', tone: 'warning' },
  schvalena: { label: 'Schválená', tone: 'positive' },
  zamietnuta: { label: 'Zamietnutá', tone: 'negative' },
  zrusena: { label: 'Zrušená', tone: 'neutral' },
};
const TABS: [string, string][] = [
  ['caka', 'Čakajú'],
  ['pridelenie_firmy', 'Pridelenie firmy'],
  ['vybavene', 'Vybavené'],
];

export function ApprovalsPage() {
  const [tab, setTab] = useState('caka');
  const { data, error, reload } = useApi<Data>(`/api/approvals?tab=${tab}`);
  const [selected, setSelected] = useState<string | null>(null);
  useEffect(() => {
    if (data && (!selected || !data.items.some((a) => a.id === selected))) setSelected(data.items[0]?.id ?? null);
  }, [data]);
  if (error) return <ErrorState error={error} />;
  const sel = data?.items.find((a) => a.id === selected) ?? null;

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Schvaľovanie</h1>
          <div className="page-sub">
            <span>pridelenie firmy; výnimky z ceny, rizikoví zákazníci a predĺženie platnosti ponuky prídu s ponukami</span>
          </div>
        </div>
      </header>
      <div className="columns">
        <div className="col-wide">
          <Card flush label="Žiadosti">
            <div className="toolbar chips-bar">
              <div className="chips" role="group" aria-label="Filter">
                {TABS.map(([v, n]) => (
                  <button key={v} type="button" className="chip" aria-pressed={tab === v} onClick={() => setTab(v)}>
                    {n} <span className="cc">{data ? num(data.counts[v] ?? 0, 0) : ''}</span>
                  </button>
                ))}
              </div>
            </div>
            {!data ? (
              <div style={{ padding: 16 }}>
                <Skeleton lines={5} />
              </div>
            ) : (
              <div className="table-wrap">
                <table className="tbl">
                  <thead>
                    <tr>
                      <th>Typ</th>
                      <th>Firma</th>
                      <th>Žiadosť</th>
                      <th>Žiadateľ</th>
                      <th>Stav</th>
                      <th>Kedy</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.length === 0 && (
                      <tr>
                        <td colSpan={6} className="muted">
                          Žiadna žiadosť.
                        </td>
                      </tr>
                    )}
                    {data.items.map((a) => (
                      <tr key={a.id} className={`clickable${a.id === selected ? ' selected' : ''}`} onClick={() => setSelected(a.id)}>
                        <td>{KIND[a.kind]}</td>
                        <td>
                          {text(a.company_name)}
                          <div className="sub">{text(a.company_ico)}</div>
                        </td>
                        <td>{a.kind === 'pridelenie_firmy' ? `od ${text(a.from_owner_name)} k ${text(a.requested_by_name)}` : '–'}</td>
                        <td>{text(a.requested_by_name)}</td>
                        <td>
                          <StatusPill map={STATUS} value={a.status} />
                        </td>
                        <td>{date(a.decided_at ?? a.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>
        </div>
        <div className="col-right">
          {sel ? <Detail a={sel} onChanged={reload} /> : <Card title="Detail"><Empty>Vyberte žiadosť.</Empty></Card>}
        </div>
      </div>
    </>
  );
}

function Detail(props: { a: Approval; onChanged: () => void }) {
  const { a } = props;
  const [note, setNote] = useState('');
  const save = useSave();
  useEffect(() => setNote(''), [a.id]);
  const decide = (approve: boolean) =>
    save.run(async () => {
      await send('POST', `/api/approvals/${a.id}/decide`, { approve, note: note || null });
      props.onChanged();
    });
  const cancel = () =>
    save.run(async () => {
      await send('POST', `/api/approvals/${a.id}/cancel`, {});
      props.onChanged();
    });
  return (
    <Card title={KIND[a.kind]} aside={<StatusPill map={STATUS} value={a.status} />}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Rows
        rows={[
          ['Firma', a.company_id ? <Link to={`/firmy/${a.company_id}`}>{a.company_name}</Link> : text(a.company_name)],
          ['IČO', text(a.company_ico)],
          ...(a.kind === 'pridelenie_firmy'
            ? ([['Pôvodný vlastník', text(a.from_owner_name)], ['Žiada', text(a.requested_by_name)]] as [string, string][])
            : []),
          ['Podané', date(a.created_at)],
          ...(a.decided_at ? ([['Rozhodol', `${text(a.decided_by_name)} · ${date(a.decided_at)}`]] as [string, string][]) : []),
        ]}
      />
      <div className="kl" style={{ marginTop: 12 }}>
        Dôvod
      </div>
      <p style={{ margin: '4px 0 12px', whiteSpace: 'pre-wrap' }}>{a.reason}</p>
      {a.decision_note && (
        <>
          <div className="kl">Poznámka schvaľovateľa</div>
          <p style={{ margin: '4px 0 12px', whiteSpace: 'pre-wrap' }}>{a.decision_note}</p>
        </>
      )}
      {a.can_decide && (
        <>
          <Field label="Poznámka (pri zamietnutí povinná)">
            <textarea className="inp" rows={3} maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} />
          </Field>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 }}>
            <button type="button" className="btn" disabled={save.busy || !note.trim()} onClick={() => decide(false)}>
              Zamietnuť
            </button>
            <button type="button" className="btn primary" disabled={save.busy} onClick={() => decide(true)}>
              Schváliť
            </button>
          </div>
          {a.kind === 'pridelenie_firmy' && (
            <div className="caption" style={{ marginTop: 8 }}>
              Po schválení sa vlastníkom firmy stane žiadateľ; otvorené obchody pôvodného vlastníka ostanú jemu. Pôvodný vlastník dostane
              upozornenie.
            </div>
          )}
        </>
      )}
      {a.can_cancel && (
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 8 }}>
          <button type="button" className="btn" disabled={save.busy} onClick={cancel}>
            Zrušiť žiadosť
          </button>
        </div>
      )}
    </Card>
  );
}
