// Schvaľovanie (dizajn 39; zadanie časti 4.1 a 6): výnimka z ceny ponuky, rizikový zákazník (konkurz / rating E/X),
// predĺženie platnosti ponuky (F2) a pridelenie firmy (F1). Kto žiadosť vidí a kto ju smie schváliť, stráži databáza:
// ceny, riziko a platnosť schvaľuje „schvaľuje ceny“, pridelenie firmy „schvaľuje pridelenie firmy“, nikdy žiadateľ.
// Pri výnimke smie schvaľovateľ schváliť inú hranicu, nie vyššiu ako žiadaná cena; platí 3 dni na odoslanie.
// Hranicu z odhadu portfólia a maržu firmy vráti databáza iba s právom.

import { type ReactNode, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { RiskPills } from '../components/deal-forms';
import { Field, Notice, useSave } from '../components/form';
import { Card, Empty, ErrorState, Rows, Skeleton, StatusPill } from '../components/ui';
import { send, useApi } from '../lib/api';
import type { Risk } from '../lib/deals';
import { date, dec, eur, num, text } from '../lib/format';
import type { Tone } from '../lib/labels';
import { APPROVAL_KIND, dateTime, PRICE_MODEL } from '../lib/offers';

type PriceItem = {
  variant_id?: string;
  variant: string;
  year: number;
  price_model: string;
  voltage_group: string;
  requested_value: string | number;
  threshold_value: string | number | null;
  approved_value: string | number | null;
  volume_mwh: string | number | null;
  added_value_requested?: string | null;
  portfolio_eur_mwh?: string | null;
  margin_requested?: string | null;
};
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
  deal_id: string | null;
  deal_name: string | null;
  offer_id: string | null;
  offer_number: string | null;
  valid_until: string | null;
  requested_valid_until: string | null;
  offer_valid_until: string | null;
  risk_snapshot: { insolvency_kind: string | null; payment_rating: string | null; debts_count: number; debts_sum: number } | null;
  items: PriceItem[] | null;
  penalty_eur_mwh: string | null;
  can_decide: boolean;
  can_cancel: boolean;
};
type Data = { items: Approval[]; counts: Record<string, number> };
type DetailData = { id: string; risk: Risk; other_pending: { id: string; kind: string }[]; see_margin: boolean; items: (PriceItem & { variant_id: string })[] };

const STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  caka: { label: 'Čaká', tone: 'warning', live: true },
  schvalena: { label: 'Schválená', tone: 'positive', live: true },
  zamietnuta: { label: 'Zamietnutá', tone: 'negative', live: true },
  zrusena: { label: 'Zrušená', tone: 'neutral' },
};
const TABS: [string, string][] = [
  ['caka', 'Čakajú'],
  ['vynimka_ceny', 'Výnimky z ceny'],
  ['rizikovy_zakaznik', 'Konkurz / rating'],
  ['predlzenie_platnosti', 'Predĺženie platnosti'],
  ['pridelenie_firmy', 'Pridelenie firmy'],
  ['vybavene', 'Vybavené'],
];
const price = (v: string | number | null | undefined) => (v === null || v === undefined ? '–' : dec(v, 2, 4));
const itemLine = (x: PriceItem) =>
  `${x.voltage_group === 'vsetko' ? '' : `${x.voltage_group.toUpperCase()} `}${x.year} ${PRICE_MODEL[x.price_model] ?? x.price_model} ${price(x.requested_value)}${
    x.threshold_value === null ? ' pod hranicou' : ` < ${price(x.threshold_value)}`
  }${x.approved_value !== null && Number(x.approved_value) !== Number(x.requested_value) ? ` → ${price(x.approved_value)}` : ''}`;

function summary(a: Approval): string {
  switch (a.kind) {
    case 'pridelenie_firmy':
      return `od ${text(a.from_owner_name)} k ${text(a.requested_by_name)}`;
    case 'vynimka_ceny':
      return [...(a.items ?? []).map(itemLine), ...(a.penalty_eur_mwh !== null ? [`zmluvná pokuta ${price(a.penalty_eur_mwh)} €/MWh`] : [])].join(' · ') || '–';
    case 'rizikovy_zakaznik': {
      const r = a.risk_snapshot;
      if (!r) return '–';
      return [r.insolvency_kind === 'konkurz' ? 'konkurz' : r.insolvency_kind ? 'reštrukturalizácia' : null,
        r.payment_rating ? `rating ${r.payment_rating}` : null,
        r.debts_count ? `dlhy ${r.debts_count}× · ${eur(r.debts_sum)} €` : null].filter(Boolean).join(' · ') || '–';
    }
    case 'predlzenie_platnosti':
      return `do ${dateTime(a.requested_valid_until)}`;
  }
}

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
        <div className="page-head-main check-title">
          <h1 className="t-page-title">Schvaľovanie</h1>
          <span className="check-title-sub">výnimky, konkurz a rating, platnosť, pridelenie firmy</span>
        </div>
      </header>
      <div className="columns">
        <div className="col-wide">
          <Card flush label="Žiadosti">
            <div className="toolbar chips-bar">
              <div className="chips" role="group" aria-label="Filter">
                {TABS.map(([v, n]) => (
                  <button key={v} type="button" className="chip" aria-pressed={tab === v} onClick={() => setTab(v)}>
                    {n} {v === 'caka' && <span className="cc">{data ? num(data.counts.caka ?? 0, 0) : ''}</span>}
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
                      <th>Obchod / firma</th>
                      <th>Žiadosť</th>
                      <th>Žiada</th>
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
                        <td>{APPROVAL_KIND[a.kind]}</td>
                        <td>
                          {a.deal_id ? (
                            <Link to={`/obchody/${a.deal_id}`} onClick={(e) => e.stopPropagation()}>{text(a.deal_name)}</Link>
                          ) : a.company_id ? (
                            <Link to={`/firmy/${a.company_id}`} onClick={(e) => e.stopPropagation()}>{text(a.company_name)}</Link>
                          ) : (
                            text(a.company_name)
                          )}
                        </td>
                        <td className="approval-summary">{summary(a)}</td>
                        <td>{text(a.requested_by_name)}</td>
                        <td>
                          <StatusPill map={STATUS} value={a.status} />
                        </td>
                        <td className="muted">
                          {a.status === 'schvalena' && a.valid_until ? `platí do ${date(a.valid_until)}` : dateTime(a.decided_at ?? a.created_at)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
            <div className="caption" style={{ padding: '8px 16px' }}>
              Výnimky, konkurz / rating E/X a predĺženie platnosti schvaľuje CEO alebo obchodný riaditeľ (príznak „schvaľuje ceny“). Pridelenie
              firmy schvaľuje manažér alebo obchodný riaditeľ. Schválená výnimka platí 3 dni na odoslanie ponuky, schválenie rizika 30 dní.
            </div>
          </Card>
        </div>
        <div className="col-right">{sel ? <Detail key={sel.id} a={sel} onChanged={reload} /> : <Card title="Detail"><Empty>Vyberte žiadosť.</Empty></Card>}</div>
      </div>
    </>
  );
}

function Detail(props: { a: Approval; onChanged: () => void }) {
  const { a } = props;
  const detail = useApi<DetailData>(`/api/approvals/${a.id}`);
  const [note, setNote] = useState('');
  const [values, setValues] = useState<Record<string, string>>({});
  const save = useSave();
  const items = detail.data?.items ?? [];
  const itemKey = (x: PriceItem & { variant_id: string }) => `${x.variant_id}|${x.year}|${x.price_model}|${x.voltage_group}`;
  useEffect(() => {
    setValues(Object.fromEntries(items.map((x) => [itemKey(x), Number(x.requested_value).toLocaleString('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 4, useGrouping: false })])));
  }, [detail.data]);

  const decide = (approve: boolean) =>
    save.run(async () => {
      await send('POST', `/api/approvals/${a.id}/decide`, {
        approve,
        note: note || null,
        ...(a.kind === 'vynimka_ceny' && approve
          ? { items: items.map((x) => ({ variant_id: x.variant_id, year: x.year, price_model: x.price_model, voltage_group: x.voltage_group, approved_value: values[itemKey(x)] })) }
          : {}),
      });
      props.onChanged();
    });
  const cancel = () =>
    save.run(async () => {
      await send('POST', `/api/approvals/${a.id}/cancel`, {});
      props.onChanged();
    });
  const title = `${APPROVAL_KIND[a.kind]}${a.deal_name ? ` · ${a.deal_name}` : a.company_name ? ` · ${a.company_name}` : ''}`;
  const others = (detail.data?.other_pending ?? []).filter((x) => x.kind === 'rizikovy_zakaznik' && a.kind !== 'rizikovy_zakaznik');

  return (
    <Card title={title} aside={<StatusPill map={STATUS} value={a.status} />}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {others.length > 0 && <div className="ban ban-danger">Zákazník je rizikový (konkurz, reštrukturalizácia alebo rating E/X) – samostatná žiadosť čaká tiež.</div>}
      {detail.data?.risk && detail.data.risk.warnings.length > 0 && (
        <div style={{ marginBottom: 8 }}>
          <RiskPills risk={detail.data.risk} />
        </div>
      )}
      <Rows
        rows={[
          ...(a.offer_id ? ([['Ponuka', <Link key="o" className="mono" to={`/ponuky/${a.offer_id}`}>{a.offer_number}</Link>]] as [string, ReactNode][]) : []),
          ...(a.deal_id
            ? ([['Obchod', <Link key="d" to={`/obchody/${a.deal_id}`}>{text(a.deal_name)}</Link>]] as [string, ReactNode][])
            : ([['Firma', a.company_id ? <Link key="f" to={`/firmy/${a.company_id}`}>{a.company_name}</Link> : text(a.company_name)], ['IČO', text(a.company_ico)]] as [string, ReactNode][])),
          ...(a.kind === 'pridelenie_firmy' ? ([['Pôvodný vlastník', text(a.from_owner_name)]] as [string, string][]) : []),
          ...(a.kind === 'predlzenie_platnosti'
            ? ([['Platí do', dateTime(a.offer_valid_until)], ['Žiada predĺžiť do', dateTime(a.requested_valid_until)]] as [string, string][])
            : []),
          ...(a.kind === 'rizikovy_zakaznik' ? ([['Finstat pri žiadosti', summary(a)]] as [string, string][]) : []),
          ...(a.penalty_eur_mwh !== null ? ([['Zmluvná pokuta', `${price(a.penalty_eur_mwh)} €/MWh (nižšia ako v šablóne)`]] as [string, string][]) : []),
          ['Žiada', `${text(a.requested_by_name)} · ${dateTime(a.created_at)}`],
          ...(a.decided_at ? ([['Rozhodol', `${text(a.decided_by_name)} · ${dateTime(a.decided_at)}`]] as [string, string][]) : []),
          ...(a.status === 'schvalena' && a.valid_until ? ([['Platí do', dateTime(a.valid_until)]] as [string, string][]) : []),
        ]}
      />

      {a.kind === 'vynimka_ceny' && items.length > 0 && (
        <div className="approval-items">
          {items.map((x) => (
            <div key={itemKey(x)} className="approval-item">
              <div className="approval-item-head">
                <strong>{x.variant}</strong> · {x.voltage_group === 'vsetko' ? '' : `${x.voltage_group.toUpperCase()} `}
                {x.year} · {PRICE_MODEL[x.price_model] ?? x.price_model}
              </div>
              <Rows
                rows={[
                  ['Žiadaná cena', `${price(x.requested_value)} €/MWh`],
                  ['Hranica', x.threshold_value === null ? 'skrytá (odhad portfólia)' : `${price(x.threshold_value)} €/MWh`],
                  ['Objem', `${dec(x.volume_mwh ?? 0, 1, 1)} MWh`],
                  ['Pridaná hodnota s výnimkou', `${eur(x.added_value_requested ?? 0)} €`],
                  ...(detail.data?.see_margin && x.margin_requested !== null
                    ? ([[`Marža firmy (odhad ${price(x.portfolio_eur_mwh ?? null)})`, `${eur(x.margin_requested)} €`]] as [string, string][])
                    : []),
                  ...(x.approved_value !== null ? ([['Schválená hranica', `${price(x.approved_value)} €/MWh`]] as [string, string][]) : []),
                ]}
              />
              {a.can_decide && (
                <Field label="Schválená hranica [€/MWh]" hint="nie vyššia ako žiadaná cena">
                  <input
                    className="inp"
                    inputMode="decimal"
                    value={values[itemKey(x)] ?? ''}
                    onChange={(e) => setValues((v) => ({ ...v, [itemKey(x)]: e.target.value }))}
                  />
                </Field>
              )}
            </div>
          ))}
        </div>
      )}

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
          <Field label="Komentár (pri zamietnutí povinný)">
            <textarea className="inp" rows={3} maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} />
          </Field>
          <div className="decide-actions">
            <button type="button" className="btn" disabled={save.busy || !note.trim()} onClick={() => decide(false)}>
              Zamietnuť
            </button>
            <button type="button" className="btn primary" disabled={save.busy} onClick={() => decide(true)}>
              {a.kind === 'vynimka_ceny' ? 'Schváliť na 3 dni' : a.kind === 'rizikovy_zakaznik' ? 'Schváliť na 30 dní' : 'Schváliť'}
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
