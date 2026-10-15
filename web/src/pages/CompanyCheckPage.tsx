// Overenie firmy pred založením obchodu (dizajn 31; zadanie časť 4.1). Hľadanie podľa IČO alebo názvu
// (našepkávanie z Finstatu a z CRM). Ukáže, či firma je v CRM, kto je vlastník, zmluvy, otvorené obchody a údaje
// z Finstatu s výstrahami. Firmu iného obchodníka nejde zobrať – iba požiadať o pridelenie (schvaľuje
// „schvaľuje pridelenie firmy“). Obrazovka je rovnaká pre interných aj externých obchodníkov.

import { type ReactNode, useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { NewDealPanel, RiskPills } from '../components/deal-forms';
import { Field, Notice, Segmented, TextInput, useSave } from '../components/form';
import { Card, Empty, Pill, Rows } from '../components/ui';
import { ApiError, get, send } from '../lib/api';
import { type Risk, Z_BAND } from '../lib/deals';
import { date, text } from '../lib/format';
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

// Tržby a zisk v celých eurách (dlaždice ako v návrhu)
const eur0 = (v: number) => new Intl.NumberFormat('sk-SK', { maximumFractionDigits: 0 }).format(v);

const stamp = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(v));

export function CompanyCheckPage() {
  const navigate = useNavigate();
  const [params, setParams] = useSearchParams();
  const [mode, setMode] = useState<'ico' | 'nazov'>(params.get('ico') ? 'ico' : 'ico');
  const [q, setQ] = useState(params.get('ico') ?? '');
  const [suggest, setSuggest] = useState<SearchResult | null>(null);
  const [result, setResult] = useState<CheckResult | null>(null);
  const [dealPanel, setDealPanel] = useState(false);
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

  // Názov: našepkávanie od 3 znakov (Finstat + CRM); IČO: overí sa tlačidlom
  useEffect(() => {
    const v = q.trim();
    if (mode !== 'nazov' || v.length < 3) {
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
  }, [q, mode]);

  const isIco = /^\d{6,8}$/.test(q.replace(/\s/g, ''));
  // Názov: tlačidlo overí prvú zhodu (najprv firma v CRM, potom Finstat); IČO zadané aj v režime Názov sa overí priamo
  const checkByName = () =>
    save.run(async () => {
      const v = q.trim();
      if (isIco) return check(v.replace(/\s/g, ''));
      const r = suggest ?? (await get<SearchResult>(`/api/company-search?q=${encodeURIComponent(v)}`));
      const ico = r.crm[0]?.ico ?? r.finstat[0]?.ico;
      if (!ico) throw new ApiError(404, r.finstat_error ? `Finstat: ${r.finstat_error}` : 'Nič sa nenašlo.');
      return check(ico);
    });
  const crm = result?.crm;
  const f = result?.finstat;
  const createCompany = () =>
    save.run(async () => {
      await send<{ id: string }>('POST', '/api/companies/from-finstat', { ico: f?.ico ?? crm?.ico });
      setResult(await get<CheckResult>(`/api/company-check?ico=${encodeURIComponent(f?.ico ?? crm?.ico ?? '')}`));
    });

  return (
    <>
      <header className="page-head">
        <div className="page-head-main check-title">
          <h1 className="t-page-title">Overenie firmy</h1>
          <span className="check-title-sub">pred založením obchodu</span>
        </div>
      </header>

      <Card>
        <div className="check-search">
          <Segmented
            label="Hľadať podľa"
            value={mode}
            onChange={(m) => {
              setMode(m);
              setSuggest(null);
            }}
            options={[
              { value: 'ico', label: 'IČO' },
              { value: 'nazov', label: 'Názov' },
            ]}
          />
          <div className="check-search-input">
            <TextInput
              value={q}
              onChange={setQ}
              placeholder={mode === 'ico' ? 'IČO, napr. 53223713' : 'Názov firmy (od 3 znakov)'}
              autoFocus
            />
          </div>
          <button
            type="button"
            className="btn primary check-search-btn"
            disabled={(mode === 'ico' ? !isIco : q.trim().length < 3) || save.busy}
            onClick={() => (mode === 'ico' ? check(q.replace(/\s/g, '')) : checkByName())}
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" aria-hidden="true">
              <circle cx="11" cy="11" r="7" />
              <path d="m20 20-3.5-3.5" />
            </svg>
            {save.busy ? 'Overujem…' : 'Overiť firmu'}
          </button>
        </div>
        {save.error && <Notice tone="error">{save.error}</Notice>}
        {suggest && mode === 'nazov' && (
          <div className="suggest">
            {suggest.crm.map((c) => (
              <button key={c.id} type="button" className="btn btn-ghost suggest-row" onClick={() => check(c.ico)}>
                <strong>{c.name}</strong> · {c.ico} <Pill tone="info">v CRM</Pill> {c.owner_name ? <span className="caption">vlastník {c.owner_name}</span> : null}
              </button>
            ))}
            {suggest.finstat
              .filter((x) => !suggest.crm.some((c) => c.ico === x.ico))
              .map((x) => (
                <button key={x.ico} type="button" className="btn btn-ghost suggest-row" onClick={() => check(x.ico)}>
                  <strong>{x.name}</strong> · {x.ico} {x.city ? `· ${x.city}` : ''}
                  {x.cancelled && <Pill tone="negative">zrušená</Pill>}
                  {x.in_crm && <Pill tone="info">v CRM{x.owner_name ? ` · ${x.owner_name}` : ''}</Pill>}
                </button>
              ))}
            {suggest.finstat_error && <div className="caption">Finstat: {suggest.finstat_error}</div>}
            {suggest.crm.length === 0 && suggest.finstat.length === 0 && !suggest.finstat_error && <Empty>Nič sa nenašlo.</Empty>}
          </div>
        )}
      </Card>

      {result && crm && (
        <div className="columns check-columns">
          <div className="col-wide">
            <FinstatCard f={f ?? null} error={result.finstat_error} risk={crm.risk ?? null} crmName={crm.name} ico={crm.ico} />
          </div>
          <div className="col-right">
            <CrmCard
              crm={crm}
              hasFinstat={!!f}
              busy={save.busy}
              onCreateCompany={createCompany}
              onNewDeal={() => setDealPanel(true)}
            />
          </div>
        </div>
      )}

      {dealPanel && crm?.company_id && (
        <NewDealPanel
          customer={{ id: crm.company_id, kind: 'company', name: crm.name ?? '' }}
          onClose={() => setDealPanel(false)}
          onSaved={(id) => navigate(`/obchody/${id}`)}
        />
      )}
    </>
  );
}

/** Stupnica Altmanovho Z-skóre 0 – 1,23 – 2,90 – 5+ s pásmami a značkou hodnoty. */
function ZScoreScale(props: { value: number }) {
  const pos = Math.max(0, Math.min(5, props.value)) / 5 * 100;
  const band = props.value < 1.23 ? 'riziko' : props.value <= 2.9 ? 'seda_zona' : 'stabilna';
  const value = new Intl.NumberFormat('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(props.value);
  return (
    <div className="zscale">
      <div className="zscale-head">
        <span className="zscale-title">Altmanovo Z-skóre · kreditné riziko</span>
        <span className={`zscale-value tone-${Z_BAND[band].tone}`}>
          {value} · {Z_BAND[band].label.split(' (')[0]}
        </span>
      </div>
      <div className="zscale-bar" aria-hidden="true">
        <span className="zscale-band zscale-red" style={{ width: `${(1.23 / 5) * 100}%` }} />
        <span className="zscale-band zscale-amber" style={{ width: `${((2.9 - 1.23) / 5) * 100}%` }} />
        <span className="zscale-band zscale-green" style={{ width: `${((5 - 2.9) / 5) * 100}%` }} />
        <span className="zscale-mark" style={{ left: `${pos}%` }} />
      </div>
      <div className="zscale-ticks caption">
        <span>0 · riziko úpadku</span>
        <span style={{ left: `${(1.23 / 5) * 100}%` }}>1,23</span>
        <span style={{ left: `${(2.9 / 5) * 100}%` }}>2,90</span>
        <span>5+ · stabilná</span>
      </div>
    </div>
  );
}

function CrmCard(props: { crm: CrmCheck; hasFinstat: boolean; busy: boolean; onCreateCompany: () => void; onNewDeal: () => void }) {
  const { crm } = props;
  const [reason, setReason] = useState('');
  const [sent, setSent] = useState(false);
  const save = useSave();
  const request = () =>
    save.run(async () => {
      await send('POST', '/api/approvals', {
        kind: 'pridelenie_firmy',
        ...(crm.company_id ? { company_id: crm.company_id } : { ico: crm.ico }),
        reason,
      });
      setSent(true);
    });
  const otherOwner = crm.exists && crm.owner_id && !crm.owner_is_me;
  return (
    <Card
      title="V CRM"
      aside={
        crm.exists ? (
          <Pill tone="info" live>
            {crm.status ? CUSTOMER_STATUS[crm.status]?.label ?? crm.status : 'v CRM'}
          </Pill>
        ) : (
          <Pill live>nie je v CRM</Pill>
        )
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {!crm.exists ? (
        <>
          <p>Firma s IČO {crm.ico} v CRM nie je.{props.hasFinstat ? ' Založte ju z Finstatu – vlastníkom budete vy.' : ''}</p>
          {props.hasFinstat && (
            <button type="button" className="btn primary check-cta" disabled={props.busy} onClick={props.onCreateCompany}>
              Založiť firmu z Finstatu
            </button>
          )}
        </>
      ) : (
        <>
          <Rows
            rows={[
              ['Vlastník', crm.owner_name ? <strong>{`${crm.owner_name}${crm.owner_is_me ? ' (vy)' : ''}`}</strong> : 'bez vlastníka'],
              ...(crm.visible
                ? ([
                    [
                      'Zmluvy',
                      (crm.contracts ?? []).length ? (
                        <span>
                          {crm.contracts!.map((k, i) => (
                            <span key={k.number}>
                              {i > 0 && ', '}
                              <span className="mono">{k.number}</span> · {k.state}
                            </span>
                          ))}
                        </span>
                      ) : (
                        '–'
                      ),
                    ],
                  ] as [string, ReactNode][])
                : []),
              [
                'Otvorené obchody',
                (crm.open_deals ?? []).length === 0 ? (
                  '–'
                ) : (
                  <span>
                    {crm.open_deals!.map((d, i) => (
                      <span key={d.deal_id ?? i}>
                        {i > 0 && ', '}
                        {d.deal_id ? <Link to={`/obchody/${d.deal_id}`}>{d.name}</Link> : 'obchod'} · {text(d.owner_name)}
                      </span>
                    ))}
                  </span>
                ),
              ],
              ...(crm.visible ? ([['Kontakty', String(crm.contacts ?? 0)]] as [string, string][]) : []),
            ]}
          />
          {otherOwner ? (
            sent ? (
              <Notice tone="ok">Žiadosť odoslaná. Výsledok uvidíte v Schvaľovaní a v zvončeku.</Notice>
            ) : (
              <div className="check-request">
                <div className="ban ban-warn check-warn">
                  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" aria-hidden="true">
                    <path d="M12 3 2 20h20L12 3Z" />
                    <path d="M12 10v4M12 17h.01" />
                  </svg>
                  <span>
                    <strong>Firmu vlastní iný obchodník.</strong> Nový obchod nemôžete založiť. Požiadajte o pridelenie – schvaľuje manažér
                    alebo obchodný riaditeľ, vlastník dostane upozornenie.
                  </span>
                </div>
                <Field label="Dôvod žiadosti">
                  <textarea className="inp" rows={2} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} />
                </Field>
                <button type="button" className="btn primary check-cta" disabled={save.busy || !reason.trim()} onClick={request}>
                  Požiadať o pridelenie
                </button>
              </div>
            )
          ) : crm.company_id ? (
            <button type="button" className="btn primary check-cta" onClick={props.onNewDeal}>
              Založiť obchod
            </button>
          ) : null}
        </>
      )}
    </Card>
  );
}

function FinstatCard(props: { f: Finstat | null; error: string | null; risk: Risk; crmName?: string; ico: string }) {
  const { f } = props;
  if (!f)
    return (
      <Card title={props.crmName ?? `IČO ${props.ico}`}>
        <Empty>{props.error ?? 'Finstat firmu s týmto IČO nepozná.'}</Empty>
      </Card>
    );
  const debts = f.debts.length
    ? f.debts.map((d) => `${d.veritel}${d.suma_eur !== null ? ` ${eur0(d.suma_eur)} €` : ''}`).join(', ')
    : f.has_debts ? 'áno' : 'Bez dlhov';
  return (
    <Card>
      <div className="company-head">
        <div>
          <h2 className="t-section-title" style={{ margin: 0 }}>{text(f.name)}</h2>
          <div className="caption">
            IČO {f.ico} · DIČ {f.dic ?? '–'} · IČ DPH {f.ic_dph ?? '–'} · {text(f.address)}
          </div>
        </div>
        {f.cancelled ? (
          <Pill tone="negative" live>
            Zrušená
          </Pill>
        ) : (
          <Pill tone="positive" live>
            Aktívna
          </Pill>
        )}
      </div>
      {props.risk && props.risk.warnings.length > 0 && (
        <div style={{ margin: '8px 0' }}>
          <RiskPills risk={props.risk} />
        </div>
      )}
      <div className="tiles">
        <Tile label={`Tržby${f.finance_year ? ` ${f.finance_year}` : ''}`} value={f.revenue_eur === null ? '–' : `${eur0(f.revenue_eur)} €`} />
        <Tile
          label={`Zisk${f.finance_year ? ` ${f.finance_year}` : ''}`}
          value={f.profit_eur === null ? '–' : `${eur0(f.profit_eur)} €`}
          tone={f.profit_eur === null ? undefined : f.profit_eur < 0 ? 'negative' : 'positive'}
        />
        <Tile label="Zamestnanci" value={employees(f.employees_range)} />
        <Tile label="Dlhy a nedoplatky" value={debts} tone={f.debts.length || f.has_debts ? 'negative' : 'positive'} />
        <Tile label="Platobný rating" value={f.payment_rating ?? '–'} tone={f.payment_rating === 'E' || f.payment_rating === 'X' ? 'negative' : undefined} />
        <Tile
          label="Konkurz / reštrukturalizácia"
          value={f.insolvency_kind ? `${f.insolvency_kind === 'konkurz' ? 'konkurz' : 'reštrukturalizácia'}${f.insolvency_since ? ` od ${date(f.insolvency_since)}` : ''}` : 'nie'}
          tone={f.insolvency_kind ? 'negative' : undefined}
        />
      </div>
      {f.z_score !== null && <ZScoreScale value={f.z_score} />}
      <p className="caption check-foot">
        Údaje z Finstatu k {stamp(f.fetched_at)}. Pri dlhoch, nedoplatkoch, konkurze, ratingu E/X alebo Z-skóre pod 1,23 sa výstraha
        ukáže na firme, obchode aj pri ponuke.{' '}
        {f.finstat_url && (
          <a href={f.finstat_url} target="_blank" rel="noreferrer noopener">
            Otvoriť vo Finstate ↗
          </a>
        )}
      </p>
    </Card>
  );
}

/** „10-19 zamestnancov“ z Finstatu → „10–19“ ako v návrhu */
function employees(v: string | null) {
  if (!v) return '–';
  return v.replace(/\s*zamestnanc\w*/i, '').replace(/(\d)\s*-\s*(\d)/, '$1–$2').trim() || v;
}

function Tile(props: { label: string; value: string; tone?: 'negative' | 'positive' }) {
  return (
    <div className="tile">
      <div className="kl">{props.label}</div>
      <div className={`tile-value${props.tone ? ` tone-${props.tone}` : ''}`}>{props.value}</div>
    </div>
  );
}
