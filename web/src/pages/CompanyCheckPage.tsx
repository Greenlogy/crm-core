// Overenie firmy pred založením obchodu (dizajn 31; zadanie časť 4.1). Hľadanie podľa IČO alebo názvu
// (našepkávanie z Finstatu a z CRM). Ukáže, či firma je v CRM, kto je vlastník, zmluvy, otvorené obchody a údaje
// z Finstatu s výstrahami. Firmu iného obchodníka nejde zobrať – iba požiadať o pridelenie (schvaľuje
// „schvaľuje pridelenie firmy“). Obrazovka je rovnaká pre interných aj externých obchodníkov.

import { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { NewDealPanel, RiskPills } from '../components/deal-forms';
import { Field, Notice, SidePanel, TextInput, useSave } from '../components/form';
import { Card, Empty, Pill, Rows } from '../components/ui';
import { get, send } from '../lib/api';
import { type Risk, Z_BAND } from '../lib/deals';
import { date, eur, text } from '../lib/format';
import { CUSTOMER_STATUS } from '../lib/labels';

type Finstat = {
  ico: string;
  name: string | null;
  dic: string | null;
  ic_dph: string | null;
  address: string | null;
  legal_form: string | null;
  founded_on: string | null;
  cancelled: boolean;
  revenue_eur: number | null;
  profit_eur: number | null;
  finance_year: number | null;
  employees_range: string | null;
  z_score: number | null;
  payment_rating: string | null;
  has_debts: boolean | null;
  debts: { veritel: string; suma_eur: number | null; k_datumu: string | null }[];
  insolvency_kind: 'konkurz' | 'restrukturalizacia' | null;
  insolvency_since: string | null;
  finstat_url: string | null;
  fetched_at: string;
  from_cache: boolean;
};
type CrmCheck = {
  exists: boolean;
  ico: string;
  company_id?: string;
  visible?: boolean;
  name?: string;
  is_customer?: boolean;
  status?: string;
  owner_id?: string;
  owner_name?: string;
  owner_is_me?: boolean;
  contacts?: number;
  contracts?: { number: string; state: string; effective_to: string | null }[];
  open_deals?: { deal_id?: string; name?: string; owner_name: string | null }[];
  risk?: Risk;
};
type CheckResult = { crm: CrmCheck; finstat: Finstat | null; finstat_error: string | null };
type Suggest = { ico: string; name: string; city: string | null; cancelled: boolean; in_crm?: boolean; owner_name?: string | null };
type SearchResult = { crm: { id: string; name: string; ico: string; owner_name: string | null }[]; finstat: Suggest[]; finstat_error: string | null };

const stamp = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(v));

export function CompanyCheckPage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [q, setQ] = useState(params.get('ico') ?? '');
  const [suggest, setSuggest] = useState<SearchResult | null>(null);
  const [result, setResult] = useState<CheckResult | null>(null);
  const [panel, setPanel] = useState<null | 'deal' | 'assign'>(null);
  const save = useSave();

  const check = (ico: string) =>
    save.run(async () => {
      setSuggest(null);
      setResult(await get<CheckResult>(`/api/company-check?ico=${encodeURIComponent(ico)}`));
      setParams({ ico }, { replace: true });
    });

  useEffect(() => {
    const ico = params.get('ico');
    if (ico && /^\d{6,8}$/.test(ico)) void check(ico);
  }, []);

  // Našepkávanie podľa názvu (od 3 znakov); číslo = IČO, overí sa tlačidlom
  useEffect(() => {
    const v = q.trim();
    if (v.length < 3 || /^\d+$/.test(v.replace(/\s/g, ''))) {
      setSuggest(null);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<SearchResult>(`/api/company-search?q=${encodeURIComponent(v)}`, ctrl.signal).then(setSuggest).catch(() => undefined);
    }, 350);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q]);

  const isIco = /^\d{6,8}$/.test(q.replace(/\s/g, ''));
  const crm = result?.crm;
  const f = result?.finstat;
  const createCompany = () =>
    save.run(async () => {
      const r = await send<{ id: string }>('POST', '/api/companies/from-finstat', { ico: f?.ico ?? crm?.ico });
      const again = await get<CheckResult>(`/api/company-check?ico=${encodeURIComponent(f?.ico ?? crm?.ico ?? '')}`);
      setResult(again);
      return r;
    });

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Overenie firmy</h1>
          <div className="page-sub">
            <span>pred založením obchodu: je v CRM, komu patrí, údaje a výstrahy z Finstatu</span>
          </div>
        </div>
      </header>

      <Card>
        <div style={{ display: 'flex', gap: 8, alignItems: 'flex-end', flexWrap: 'wrap' }}>
          <div style={{ flex: '1 1 320px' }}>
            <Field label="IČO alebo názov firmy">
              <TextInput value={q} onChange={setQ} placeholder="napr. 53223713 alebo Greenlogy" autoFocus />
            </Field>
          </div>
          <button type="button" className="btn primary" disabled={!isIco || save.busy} onClick={() => check(q.replace(/\s/g, ''))}>
            {save.busy ? 'Overujem…' : 'Overiť'}
          </button>
        </div>
        {save.error && <Notice tone="error">{save.error}</Notice>}
        {suggest && (
          <div className="suggest">
            {suggest.crm.map((c) => (
              <button key={c.id} type="button" className="btn btn-ghost suggest-row" onClick={() => check(c.ico)}>
                <strong>{c.name}</strong> · {c.ico} <Pill tone="info">v CRM</Pill> {c.owner_name ? <span className="caption">vlastník {c.owner_name}</span> : null}
              </button>
            ))}
            {suggest.finstat
              .filter((s) => !suggest.crm.some((c) => c.ico === s.ico))
              .map((s) => (
                <button key={s.ico} type="button" className="btn btn-ghost suggest-row" onClick={() => check(s.ico)}>
                  <strong>{s.name}</strong> · {s.ico} {s.city ? `· ${s.city}` : ''}
                  {s.cancelled && <Pill tone="negative">zrušená</Pill>}
                  {s.in_crm && <Pill tone="info">v CRM{s.owner_name ? ` · ${s.owner_name}` : ''}</Pill>}
                </button>
              ))}
            {suggest.finstat_error && <div className="caption">Finstat: {suggest.finstat_error}</div>}
            {suggest.crm.length === 0 && suggest.finstat.length === 0 && !suggest.finstat_error && <Empty>Nič sa nenašlo.</Empty>}
          </div>
        )}
      </Card>

      {result && crm && (
        <div className="columns" style={{ marginTop: 16 }}>
          <div className="col-wide">
            <Card title="V CRM">
              {!crm.exists ? (
                <>
                  <p>
                    Firma s IČO {crm.ico} v CRM nie je. {f ? 'Založte ju z Finstatu – vlastníkom budete vy.' : ''}
                  </p>
                  {f && (
                    <button type="button" className="btn primary" disabled={save.busy} onClick={createCompany}>
                      Založiť firmu z Finstatu
                    </button>
                  )}
                </>
              ) : (
                <>
                  <Rows
                    rows={[
                      ['Firma', crm.visible && crm.company_id ? <Link to={`/firmy/${crm.company_id}`}>{crm.name}</Link> : text(crm.name)],
                      ['Stav', crm.status ? CUSTOMER_STATUS[crm.status]?.label ?? crm.status : '–'],
                      ['Vlastník', crm.owner_name ? `${crm.owner_name}${crm.owner_is_me ? ' (vy)' : ''}` : 'bez vlastníka'],
                      ...(crm.visible ? ([['Kontakty', String(crm.contacts ?? 0)]] as [string, string][]) : []),
                    ]}
                  />
                  {crm.visible && (crm.contracts?.length ?? 0) > 0 && (
                    <>
                      <div className="kl" style={{ marginTop: 12 }}>
                        Zmluvy
                      </div>
                      {crm.contracts!.map((k) => (
                        <div key={k.number} className="caption">
                          {k.number} · {k.state}
                          {k.effective_to ? ` · do ${date(k.effective_to)}` : ''}
                        </div>
                      ))}
                    </>
                  )}
                  <div className="kl" style={{ marginTop: 12 }}>
                    Otvorené obchody
                  </div>
                  {(crm.open_deals ?? []).length === 0 ? (
                    <div className="caption">žiadne</div>
                  ) : (
                    crm.open_deals!.map((d, i) => (
                      <div key={d.deal_id ?? i} className="caption">
                        {d.deal_id ? <Link to={`/obchody/${d.deal_id}`}>{d.name}</Link> : 'obchod'} · {text(d.owner_name)}
                      </div>
                    ))
                  )}
                  <div style={{ display: 'flex', gap: 8, marginTop: 16, flexWrap: 'wrap' }}>
                    {crm.owner_is_me || !crm.owner_id ? (
                      crm.visible || !crm.owner_id ? (
                        <button type="button" className="btn primary" onClick={() => setPanel('deal')}>
                          Založiť obchod
                        </button>
                      ) : null
                    ) : (
                      <>
                        <Notice tone="error">
                          Firmu vlastní {crm.owner_name}. Nový obchod nejde založiť – môžete požiadať o pridelenie (schvaľuje manažér alebo
                          obchodný riaditeľ, pôvodný vlastník dostane upozornenie).
                        </Notice>
                        <button type="button" className="btn" onClick={() => setPanel('assign')}>
                          Požiadať o pridelenie
                        </button>
                      </>
                    )}
                  </div>
                </>
              )}
            </Card>
          </div>
          <div className="col-right">
            <FinstatCard f={f ?? null} error={result.finstat_error} risk={crm.risk ?? null} />
          </div>
        </div>
      )}

      {panel === 'deal' && crm?.company_id && (
        <NewDealPanel
          customer={{ id: crm.company_id, kind: 'company', name: crm.name ?? '' }}
          onClose={() => setPanel(null)}
          onSaved={(id) => navigate(`/obchody/${id}`)}
        />
      )}
      {panel === 'deal' && crm && !crm.company_id && <Notice tone="error">Firmu nevidíte – založte obchod cez vedenie.</Notice>}
      {panel === 'assign' && crm && <AssignPanel crm={crm} onClose={() => setPanel(null)} />}
    </>
  );
}

function FinstatCard(props: { f: Finstat | null; error: string | null; risk: Risk }) {
  const { f } = props;
  if (!f)
    return (
      <Card title="Finstat">
        <Empty>{props.error ?? 'Finstat firmu s týmto IČO nepozná.'}</Empty>
      </Card>
    );
  const z = f.z_score === null ? null : f.z_score < 1.23 ? 'riziko' : f.z_score <= 2.9 ? 'seda_zona' : 'stabilna';
  return (
    <Card title="Finstat" aside={<span className="caption">údaje k {stamp(f.fetched_at)}</span>}>
      {props.risk && <RiskPills risk={props.risk} />}
      <Rows
        rows={[
          ['Názov', text(f.name)],
          ['IČO / DIČ / IČ DPH', [f.ico, f.dic, f.ic_dph].map((x) => x ?? '–').join(' / ')],
          ['Sídlo', text(f.address)],
          ['Vznik', date(f.founded_on)],
          ['Stav', f.cancelled ? <Pill tone="negative">zrušená</Pill> : 'aktívna'],
          [`Tržby${f.finance_year ? ` ${f.finance_year}` : ''}`, f.revenue_eur === null ? '–' : `${eur(f.revenue_eur)} €`],
          [`Zisk${f.finance_year ? ` ${f.finance_year}` : ''}`, f.profit_eur === null ? '–' : `${eur(f.profit_eur)} €`],
          ['Zamestnanci', text(f.employees_range)],
          ['Platobný rating', f.payment_rating ?? '–'],
          [
            'Altmanovo Z-skóre',
            f.z_score === null ? '–' : (
              <>
                {String(f.z_score).replace('.', ',')} {z && <Pill tone={Z_BAND[z].tone}>{Z_BAND[z].label}</Pill>}
              </>
            ),
          ],
          [
            'Konkurz / reštrukturalizácia',
            f.insolvency_kind ? `${f.insolvency_kind === 'konkurz' ? 'konkurz' : 'reštrukturalizácia'}${f.insolvency_since ? ` od ${date(f.insolvency_since)}` : ''}` : 'nie',
          ],
          ['Dlhy a nedoplatky', f.debts.length ? f.debts.map((d) => `${d.veritel}${d.suma_eur !== null ? ` ${eur(d.suma_eur)} €` : ''}`).join(', ') : f.has_debts ? 'áno' : 'bez dlhov'],
        ]}
      />
      {f.finstat_url && (
        <a className="caption" href={f.finstat_url} target="_blank" rel="noreferrer noopener">
          Otvoriť vo Finstate
        </a>
      )}
    </Card>
  );
}

function AssignPanel(props: { crm: CrmCheck; onClose: () => void }) {
  const [reason, setReason] = useState('');
  const [done, setDone] = useState(false);
  const save = useSave();
  // Firmu iného obchodníka používateľ nevidí – žiadosť ide podľa IČO (databáza ju nájde)
  const submit = () =>
    save.run(async () => {
      await send('POST', '/api/approvals', {
        kind: 'pridelenie_firmy',
        ...(props.crm.company_id ? { company_id: props.crm.company_id } : { ico: props.crm.ico }),
        reason,
      });
      setDone(true);
    });
  return (
    <SidePanel
      title={`Požiadať o pridelenie – ${props.crm.name ?? ''}`}
      onClose={props.onClose}
      footer={
        done ? (
          <button type="button" className="btn primary" onClick={props.onClose}>
            Zavrieť
          </button>
        ) : (
          <>
            <button type="button" className="btn" onClick={props.onClose}>
              Zrušiť
            </button>
            <button type="button" className="btn primary" disabled={save.busy || !reason.trim()} onClick={submit}>
              Odoslať žiadosť
            </button>
          </>
        )
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {done ? (
        <Notice tone="ok">Žiadosť odoslaná. Schvaľovatelia dostali upozornenie; výsledok uvidíte v Schvaľovaní a v zvončeku.</Notice>
      ) : (
        <>
          <p className="caption">Firmu vlastní {props.crm.owner_name}. Po schválení sa vlastníkom stanete vy; jeho otvorené obchody ostanú jemu.</p>
          <Field label="Dôvod">
            <textarea className="inp" rows={4} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} autoFocus />
          </Field>
        </>
      )}
    </SidePanel>
  );
}
