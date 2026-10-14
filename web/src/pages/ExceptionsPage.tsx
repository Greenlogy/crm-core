// Výnimky z ceny podľa docs/dizajn/obrazovky/28-vynimky.html (modul Zmluvy, F3; zadanie časť 7).
// Obchodník požiada o cenu pod hranicou pri svojom zákazníkovi (hranicu doplní databáza – cena pre obchodníka dnes alebo
// minimálny aditív). Schvaľuje CEO alebo obchodný riaditeľ („schvaľuje ceny“), nikdy autor. Schválená platí 30 dní
// na podpis a pri importe sa spáruje so zmluvou (zákazník + rok + model) – stane sa hranicou pre pridanú hodnotu.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { Card, Empty, ErrorState, Pill, Rows, Skeleton, StatusPill } from '../components/ui';
import { get, send, useApi } from '../lib/api';
import { date, dec, eur, eurMwh, mwh, num, text } from '../lib/format';
import { useMe } from '../lib/me';
import { EXCEPTION_STATE } from '../lib/labels';

type Exception = {
  id: string;
  company_id: string | null;
  person_id: string | null;
  customer_name: string | null;
  years: number[];
  price_model: 'fix' | 'spot_plus_eur' | 'spot_minus_eur';
  requested_value: string;
  threshold_value: string;
  volume_mwh: string | null;
  reason: string;
  state: string;
  requested_by_name: string | null;
  decided_by_name: string | null;
  decided_at: string | null;
  decision_note: string | null;
  valid_until: string | null;
  created_at: string;
  contract_id: string | null;
  contract_number: string | null;
  trader_price_today: string | null;
  portfolio_today: string | null;
  can_decide: boolean;
  can_delete: boolean;
};
type Data = { items: Exception[]; counts: Record<string, number>; approves: boolean; margin: boolean };

const CHIPS: [string, string][] = [
  ['', 'Všetky'],
  ['caka', 'Čakajú na schválenie'],
  ['schvalena', 'Schválené'],
  ['zamietnuta', 'Zamietnuté'],
  ['pouzita', 'Použité'],
  ['expirovana', 'Expirované'],
];
const MODEL: Record<string, string> = { fix: 'FIX', spot_plus_eur: 'SPOT +', spot_minus_eur: 'Výkup SPOT −' };

const value = (e: Pick<Exception, 'price_model' | 'requested_value'>) => `${MODEL[e.price_model]} ${dec(e.requested_value, 2, 2)}`;
const yearsText = (y: number[]) => (y.length > 1 && y[y.length - 1] - y[0] === y.length - 1 ? `${y[0]}–${y[y.length - 1]}` : y.join(', '));

export function ExceptionsPage() {
  const me = useMe();
  const [state, setState] = useState('');
  const { data, error, reload } = useApi<Data>(`/api/price-exceptions${state ? `?stav=${state}` : ''}`);
  const [selected, setSelected] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  useEffect(() => {
    if (data && (!selected || !data.items.some((e) => e.id === selected))) {
      setSelected(data.items.find((e) => e.state === 'caka')?.id ?? data.items[0]?.id ?? null);
    }
  }, [data]);

  if (error) return <ErrorState error={error} />;
  const sel = data?.items.find((e) => e.id === selected) ?? null;

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Výnimky z ceny</h1>
          <div className="page-sub">
            <span>žiadosti obchodníkov o cenu pod hranicou</span>
          </div>
        </div>
        <div className="head-actions">
          {me.seller_type !== null || me.is_admin ? (
            <button type="button" className="btn primary" onClick={() => setCreating(true)}>
              Nová žiadosť
            </button>
          ) : null}
        </div>
      </header>
      {creating && (
        <NewException
          onClose={() => setCreating(false)}
          onSaved={(id) => {
            setCreating(false);
            setSelected(id);
            reload();
          }}
        />
      )}

      <div className="columns">
        <div className="col-wide">
          <Card flush label="Žiadosti o výnimku">
            <div className="toolbar chips-bar">
              <div className="chips" role="group" aria-label="Filter podľa stavu">
                {CHIPS.map(([v, n]) => (
                  <button key={v || 'all'} type="button" className="chip" aria-pressed={state === v} onClick={() => setState(v)}>
                    {n} <span className="cc">{data ? num(data.counts[v || 'all'] ?? 0, 0) : ''}</span>
                  </button>
                ))}
              </div>
            </div>
            {!data ? (
              <div style={{ padding: 16 }}>
                <Skeleton lines={6} />
              </div>
            ) : (
              <div className="table-wrap">
                <table className="tbl">
                  <thead>
                    <tr>
                      <th>Zákazník</th>
                      <th>Roky</th>
                      <th className="num">Žiadaná cena</th>
                      <th className="num">Hranica</th>
                      <th className="num">Objem [MWh]</th>
                      <th>Stav</th>
                      <th>Platná do</th>
                    </tr>
                  </thead>
                  <tbody>
                    {data.items.length === 0 && (
                      <tr>
                        <td colSpan={7} className="muted">
                          Žiadna žiadosť.
                        </td>
                      </tr>
                    )}
                    {data.items.map((e) => (
                      <tr key={e.id} className={`clickable${e.id === selected ? ' selected' : ''}`} onClick={() => setSelected(e.id)}>
                        <td>
                          <Link
                            to={e.company_id ? `/firmy/${e.company_id}` : `/osoby/${e.person_id}`}
                            onClick={(x) => x.stopPropagation()}
                          >
                            {text(e.customer_name)}
                          </Link>
                          <div className="sub">{text(e.requested_by_name)}</div>
                        </td>
                        <td>{yearsText(e.years)}</td>
                        <td className="num">{value(e)}</td>
                        <td className="num">{dec(e.threshold_value, 2, 2)}</td>
                        <td className="num">{e.volume_mwh === null ? '–' : dec(e.volume_mwh, 1, 1)}</td>
                        <td>
                          <StatusPill map={EXCEPTION_STATE} value={e.state} />
                        </td>
                        <td>{e.state === 'schvalena' || e.state === 'expirovana' ? `do ${date(e.valid_until)}` : '–'}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="caption" style={{ padding: '8px 16px' }}>
              Schválená výnimka sa pri importe spáruje so zmluvou (zákazník + rok + model) a stane sa hranicou pre pridanú hodnotu. Platí 30 dní
              na podpis.
            </div>
          </Card>
        </div>
        <div className="col-right">
          {sel ? <Detail e={sel} margin={!!data?.margin} onChanged={reload} /> : <Card title="Detail"><Empty>Vyberte žiadosť.</Empty></Card>}
        </div>
      </div>
    </>
  );
}

function Detail(props: { e: Exception; margin: boolean; onChanged: () => void }) {
  const { e } = props;
  const [note, setNote] = useState('');
  const save = useSave();
  useEffect(() => setNote(''), [e.id]);
  const vol = e.volume_mwh === null ? null : Number(e.volume_mwh);
  const req = Number(e.requested_value);
  const margin =
    vol === null ? null : e.price_model === 'fix' ? (e.portfolio_today === null ? null : (req - Number(e.portfolio_today)) * vol) : req * vol;
  const decide = (status: 'schvalena' | 'zamietnuta') =>
    save.run(async () => {
      await send('PATCH', `/api/price-exceptions/${e.id}`, { status, decision_note: note });
      props.onChanged();
    });
  const remove = () =>
    save.run(async () => {
      await send('DELETE', `/api/price-exceptions/${e.id}`);
      props.onChanged();
    });
  return (
    <Card title={text(e.customer_name)} aside={<StatusPill map={EXCEPTION_STATE} value={e.state} />}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Rows
        rows={[
          ['Roky dodávky', e.years.join(', ')],
          ['Typ', MODEL[e.price_model]],
          ['Žiadaná cena', e.price_model === 'fix' ? eurMwh(e.requested_value) : `aditív ${eurMwh(e.requested_value)}`],
          ['Hranica v deň žiadosti', eurMwh(e.threshold_value)],
          ...(e.price_model === 'fix' ? [['Cena pre obchodníka dnes', eurMwh(e.trader_price_today)] as [string, string]] : []),
          ['Objem', vol === null ? '–' : `${mwh(vol)} / rok`],
          ['Rozdiel oproti hranici', vol === null ? '–' : `${eur((req - Number(e.threshold_value)) * vol)} € / rok`],
          ...(props.margin && e.price_model !== 'spot_minus_eur'
            ? [[`Marža firmy${e.price_model === 'fix' ? ` (odhad ${dec(e.portfolio_today, 2, 2)})` : ''}`, margin === null ? '–' : `${eur(margin)} € / rok (bez poplatkov)`] as [string, string]]
            : []),
          ['Obchodník', `${text(e.requested_by_name)} · ${date(e.created_at)}`],
          ...(e.decided_at ? [['Rozhodol', `${text(e.decided_by_name)} · ${date(e.decided_at)}`] as [string, string]] : []),
          ...(e.contract_id ? [['Zmluva', <Link to={`/zmluvy/${e.contract_id}`}>{e.contract_number}</Link>] as [string, React.ReactNode]] : []),
        ]}
      />
      <div className="kl" style={{ marginTop: 12 }}>
        Dôvod
      </div>
      <p style={{ margin: '4px 0 12px', whiteSpace: 'pre-wrap' }}>{e.reason}</p>
      {e.decision_note && (
        <>
          <div className="kl">Komentár schvaľovateľa</div>
          <p style={{ margin: '4px 0 12px', whiteSpace: 'pre-wrap' }}>{e.decision_note}</p>
        </>
      )}
      {e.can_decide && (
        <>
          <Field label="Komentár schvaľovateľa">
            <textarea className="inp" rows={3} value={note} maxLength={2000} onChange={(x) => setNote(x.target.value)} />
          </Field>
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 }}>
            <button type="button" className="btn" disabled={save.busy} onClick={() => decide('zamietnuta')}>
              Zamietnuť
            </button>
            <button type="button" className="btn primary" disabled={save.busy} onClick={() => decide('schvalena')}>
              Schváliť
            </button>
          </div>
        </>
      )}
      {e.can_delete && (
        <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 8 }}>
          <button type="button" className="btn" disabled={save.busy} onClick={remove}>
            Zmazať žiadosť
          </button>
        </div>
      )}
      <div className="caption" style={{ marginTop: 8 }}>
        Schvaľuje CEO alebo obchodný riaditeľ (príznak „schvaľuje ceny“), nikdy autor žiadosti.
      </div>
    </Card>
  );
}

type CustomerHit = { id: string; kind: 'company' | 'person'; name: string; ico: string | null };

function NewException(props: { onClose: () => void; onSaved: (id: string) => void }) {
  const thisYear = new Date().getFullYear();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<CustomerHit[]>([]);
  const [customer, setCustomer] = useState<CustomerHit | null>(null);
  const [years, setYears] = useState<number[]>([thisYear + 1]);
  const [model, setModel] = useState<'fix' | 'spot_plus_eur' | 'spot_minus_eur'>('fix');
  const [val, setVal] = useState('');
  const [volume, setVolume] = useState('');
  const [reason, setReason] = useState('');
  const save = useSave();

  useEffect(() => {
    if (customer || q.trim().length < 2) {
      setHits([]);
      return;
    }
    const t = setTimeout(() => {
      get<{ items: CustomerHit[] }>(`/api/customers?status=vsetky&q=${encodeURIComponent(q.trim())}`)
        .then((r) => setHits(r.items.slice(0, 8)))
        .catch(() => setHits([]));
    }, 250);
    return () => clearTimeout(t);
  }, [q, customer]);

  const submit = () =>
    save.run(async () => {
      if (!customer) throw new Error('Vyberte zákazníka.');
      const r = await send<{ id: string }>('POST', '/api/price-exceptions', {
        customer_id: customer.id, years, price_model: model, requested_value: val, volume_mwh: volume || null, reason,
      });
      props.onSaved(r.id);
    });

  return (
    <SidePanel
      title="Nová žiadosť o výnimku"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !customer || !val || !reason.trim() || years.length === 0} onClick={submit}>
            {save.busy ? 'Odosielam…' : 'Odoslať na schválenie'}
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Zákazník" hint="Iba vaši zákazníci (pri tíme „iba svoje“).">
        {customer ? (
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <strong>{customer.name}</strong>
            <button type="button" className="btn btn-ghost" onClick={() => setCustomer(null)}>
              Zmeniť
            </button>
          </div>
        ) : (
          <>
            <TextInput value={q} onChange={setQ} placeholder="Názov, IČO alebo meno…" autoFocus />
            {hits.map((h) => (
              <button key={h.id} type="button" className="btn btn-ghost" style={{ justifyContent: 'flex-start' }} onClick={() => setCustomer(h)}>
                {h.name} {h.ico ? `· ${h.ico}` : ''}
              </button>
            ))}
          </>
        )}
      </Field>
      <Field label="Roky dodávky">
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {[thisYear, thisYear + 1, thisYear + 2, thisYear + 3].map((y) => (
            <Check key={y} checked={years.includes(y)} onChange={(c) => setYears((v) => (c ? [...v, y].sort() : v.filter((x) => x !== y)))}>
              {y}
            </Check>
          ))}
        </div>
      </Field>
      <Field label="Model ceny">
        <Select
          value={model}
          onChange={setModel}
          options={[
            { value: 'fix', label: 'FIX – cena €/MWh' },
            { value: 'spot_plus_eur', label: 'SPOT + aditív €/MWh' },
            { value: 'spot_minus_eur', label: 'Výkup SPOT − aditív €/MWh' },
          ]}
        />
      </Field>
      <Field label={model === 'fix' ? 'Žiadaná cena [€/MWh]' : 'Žiadaný aditív [€/MWh]'} hint="Hranicu (cena pre obchodníka dnes alebo minimálny aditív) doplní CRM.">
        <TextInput value={val} onChange={setVal} maxLength={12} />
      </Field>
      <Field label="Objem [MWh / rok]">
        <TextInput value={volume} onChange={setVolume} maxLength={12} />
      </Field>
      <Field label="Dôvod">
        <textarea className="inp" rows={4} value={reason} maxLength={2000} onChange={(e) => setReason(e.target.value)} />
      </Field>
    </SidePanel>
  );
}
