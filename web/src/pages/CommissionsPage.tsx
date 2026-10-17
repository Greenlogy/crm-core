// Provízie podľa docs/dizajn/obrazovky/41-provizie.html (modul 5, F7; zadanie časť 12, návrh DB časti 37–40).
// Obchodník vidí svoje provízie, admin a „vidí všetky provízie“ všetky (RLS). Provízie zoskupené podľa trvania zmluvy;
// výber čakajúcich provízií jedného obchodníka → provízny list CMSN-RRRR-NNNN (PDF a e-mail pripraví CRM).
// Súčty počíta databáza (uplatnené podľa dátumu uplatnenia, nie výhry). Neúplný základ (chýba cena) sa nedá uplatniť.

import { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { Field, Notice, SidePanel, TextInput, useSave } from '../components/form';
import { GlassBar, PageHero } from '../components/hero';
import { Icon, ICONS } from '../components/Layout';
import { Card, Empty, ErrorState, Kpi, Pill, Skeleton, StatusPill } from '../components/ui';
import { send, useApi } from '../lib/api';
import { date, dec, eur, num, text } from '../lib/format';
import { useMe } from '../lib/me';
import { COMMISSION_STATE } from '../lib/labels';

type Item = {
  id: string;
  deal_id: string | null;
  deal_name: string | null;
  customer_name: string | null;
  user_id: string;
  user_name: string;
  kind: 'provizia' | 'vyrovnanie';
  status: 'caka' | 'uplatnena' | 'zrusena';
  won_at: string | null;
  duration_years: number | null;
  volume_mwh: string | null;
  base_eur: string;
  base_missing: string | null;
  pct: string;
  target_eur: string;
  amount_eur: string;
  claim_id: string | null;
  claim_number: string | null;
  claimed_at: string | null;
  source: 'crm' | 'sales_portal';
  reassigned_at: string | null;
};
type Claim = {
  id: string;
  number: string;
  user_id: string;
  user_name: string;
  total_eur: string;
  created_at: string;
  created_by_name: string | null;
  voided_at: string | null;
  voided_by_name: string | null;
  void_reason: string | null;
  source: 'crm' | 'sales_portal';
  has_pdf: boolean;
  has_void_pdf: boolean;
  legacy_pdf_url: string | null;
  items: number;
};
type Summary = {
  unpaid_eur: string;
  unpaid_deals: number;
  month_eur: string;
  month_last_claim: string | null;
  quarter_eur: string;
  year_eur: string;
  deals_year: number;
};
type Data = {
  items: Item[];
  summary: Summary;
  claims: Claim[];
  sellers: { id: string; name: string }[];
  me: { id: string; sees_all: boolean; is_admin: boolean; scope: string };
};

const CHIPS: [string, string][] = [
  ['', 'Platné'],
  ['caka', 'Čaká'],
  ['uplatnena', 'Uplatnená'],
  ['zrusena', 'Zrušená'],
];
const durationKey = (d: number | null) => (d === null ? 'neurcito' : String(d));
const durationLabel = (k: string) => (k === 'neurcito' ? 'na neurčito (prvých 12 mesiacov)' : k === '1' ? '1 rok' : Number(k) < 5 ? `${k} roky` : `${k} rokov`);
const money = (v: string | number) => `${eur(v)} €`;

export function CommissionsPage() {
  const me = useMe();
  const [status, setStatus] = useState('');
  const [seller, setSeller] = useState('');
  const [input, setInput] = useState('');
  const [q, setQ] = useState('');
  const [period, setPeriod] = useState<'quarter' | 'year'>('quarter');
  const [selected, setSelected] = useState<string[]>([]);
  const [done, setDone] = useState<{ id: string; number: string; total_eur: string } | null>(null);
  const [voiding, setVoiding] = useState<Claim | null>(null);
  const save = useSave();
  useEffect(() => {
    const t = window.setTimeout(() => setQ(input.trim()), 300);
    return () => window.clearTimeout(t);
  }, [input]);
  const params = new URLSearchParams({ ...(status && { status }), ...(seller && { user: seller }), ...(q && { q }) });
  const { data, error, reload } = useApi<Data>(`/api/commissions${params.size ? `?${params}` : ''}`);
  useEffect(() => setSelected([]), [status, seller, q]);

  const groups = useMemo(() => {
    const m = new Map<string, Item[]>();
    for (const i of data?.items ?? []) m.set(durationKey(i.duration_years), [...(m.get(durationKey(i.duration_years)) ?? []), i]);
    return [...m.entries()].sort(([a], [b]) => (a === 'neurcito' ? 1 : b === 'neurcito' ? -1 : Number(a) - Number(b)));
  }, [data]);

  if (error) return <ErrorState error={error} />;
  const items = data?.items ?? [];
  const chosen = items.filter((i) => selected.includes(i.id));
  const chosenSeller = chosen[0]?.user_id ?? null;
  const chosenTotal = chosen.reduce((s, i) => s + Number(i.amount_eur), 0);
  const canClaimFor = (userId: string) => userId === me.id || !!data?.me.is_admin;
  const selectable = (i: Item) => i.status === 'caka' && !i.base_missing && canClaimFor(i.user_id) && (!chosenSeller || chosenSeller === i.user_id);
  const toggle = (i: Item) => setSelected((s) => (s.includes(i.id) ? s.filter((x) => x !== i.id) : [...s, i.id]));
  const claimProblem =
    chosen.length === 0 ? null
      : chosenTotal < 0 ? 'Súčet listu musí byť aspoň 0 €.'
        : !chosen.some((i) => Number(i.amount_eur) > 0) ? 'List musí obsahovať kladnú províziu (záporné vyrovnanie sa samostatne neuplatňuje).'
          : null;

  const claim = () =>
    save.run(async () => {
      const r = await send<{ id: string; number: string; total_eur: string }>('POST', '/api/commissions/claims', { user_id: chosenSeller, ids: selected });
      setDone(r);
      setSelected([]);
      reload();
    });
  const s = data?.summary;
  const year = new Date().getFullYear();

  return (
    <>
      <PageHero
        title="Provízie"
        sub="z vyhratých obchodov"
        actions={
          me.is_admin || me.approves_prices ? (
            <Link to="/nastavenia/provizie" className="btn">
              Nastavenia provízií
            </Link>
          ) : undefined
        }
      />

      <GlassBar label="Filter provízií">
        <div className="chips" role="group" aria-label="Stav">
          {CHIPS.map(([v, n]) => (
            <button key={v || 'all'} type="button" className="chip" aria-pressed={status === v} onClick={() => setStatus(v)}>
              {n}
            </button>
          ))}
        </div>
      </GlassBar>

      <div className="kpis">
        <Kpi label="Nevyplatené provízie" variant="soft" value={s ? money(s.unpaid_eur) : ''}
          sub={s ? `${num(s.unpaid_deals, 0)} ${s.unpaid_deals === 1 ? 'obchod' : s.unpaid_deals < 5 && s.unpaid_deals > 0 ? 'obchody' : 'obchodov'} · čaká na uplatnenie` : undefined} />
        <Kpi label="Uplatnené tento mesiac" value={s ? money(s.month_eur) : ''} sub={s?.month_last_claim ?? 'bez listu'} />
        <Kpi
          label={period === 'quarter' ? 'Tento kvartál' : 'Tento rok'}
          value={s ? money(period === 'quarter' ? s.quarter_eur : s.year_eur) : ''}
          sub={
            <button type="button" className="link-button" onClick={() => setPeriod((p) => (p === 'quarter' ? 'year' : 'quarter'))}>
              {period === 'quarter' ? `Q${Math.floor(new Date().getMonth() / 3) + 1} ${year} · prepnúť na rok` : `${year} · prepnúť na kvartál`}
            </button>
          }
        />
        <Kpi label="Počet obchodov" value={s ? num(s.deals_year, 0) : ''} sub={`od 1. 1. ${year}`} />
      </div>

      {done && (
        <Notice tone="ok">
          Provízny list <strong>{done.number}</strong> ({money(done.total_eur)}) je vytvorený. PDF a e-mail obchodníkovi a príjemcom kópie pripraví CRM
          do minúty – <a href={`/api/commissions/claims/${done.id}/pdf`} target="_blank" rel="noreferrer">otvoriť PDF</a>.
        </Notice>
      )}

      <Card flush label="Provízie">
        <div className="toolbar">
          <div className="gl-search list-search">
            <Icon d={ICONS.search} />
            <input className="input" type="search" placeholder="Obchod, zákazník alebo číslo listu…" aria-label="Hľadať províziu"
              value={input} onChange={(e) => setInput(e.target.value)} />
          </div>
          {data?.me.sees_all && (
            <select className="input select" aria-label="Obchodník" value={seller} onChange={(e) => setSeller(e.target.value)}>
              <option value="">Obchodník: všetci</option>
              {data.sellers.map((u) => (
                <option key={u.id} value={u.id}>
                  {u.name}
                </option>
              ))}
            </select>
          )}
        </div>
        <div className="caption" style={{ padding: '0 24px 12px' }}>
          Provízia = pridaná hodnota obchodu (zmluvy obchodu) × % obchodníka platné v deň Vyhraté. Neurčito = prvých 12 mesiacov. Nárok pri Vyhraté.
        </div>
        {chosen.length > 0 && (
          <div className="selection-bar">
            <span>
              Vybrané {num(chosen.length, 0)} · {chosen[0].user_name} · spolu <strong>{money(chosenTotal)}</strong>
            </span>
            {claimProblem && <span className="negative-text">{claimProblem}</span>}
            <button type="button" className="btn primary" disabled={save.busy || !!claimProblem} onClick={claim}>
              Uplatniť províziu – vytvoriť provízny list
            </button>
          </div>
        )}
        {save.error && <Notice tone="error">{save.error}</Notice>}
      </Card>

      {!data ? (
        <Card>
          <Skeleton lines={6} />
        </Card>
      ) : items.length === 0 ? (
        <Card>
          <Empty>{status || q || seller ? 'Žiadna provízia pre zvolený filter.' : 'Zatiaľ žiadna provízia. Vzniká, keď obchod prejde do Vyhraté.'}</Empty>
        </Card>
      ) : (
        groups.map(([key, rows]) => (
          <Card key={key} flush title={`Trvanie zmluvy: ${durationLabel(key)}`}
            aside={<span className="page-sub">medzisúčet {money(rows.filter((r) => r.status !== 'zrusena').reduce((t, r) => t + Number(r.amount_eur), 0))}</span>}>
            <div className="table-wrap">
              <table className="tbl">
                <thead>
                  <tr>
                    <th aria-label="Výber" />
                    <th>Obchod · zákazník</th>
                    {data.me.sees_all && <th>Obchodník</th>}
                    <th>Vyhraté</th>
                    <th className="num">Objem [MWh]</th>
                    <th className="num">Prid. hodnota [€]</th>
                    <th className="num">Provízia [€]</th>
                    <th>Stav</th>
                    <th>Provízny list</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((i) => (
                    <tr key={i.id} className={selected.includes(i.id) ? 'selected' : undefined}>
                      <td>
                        {i.status === 'caka' && (
                          <input type="checkbox" aria-label={`Vybrať ${i.deal_name ?? ''}`} checked={selected.includes(i.id)}
                            disabled={!selected.includes(i.id) && !selectable(i)} onChange={() => toggle(i)} />
                        )}
                      </td>
                      <td>
                        {i.deal_id ? <Link to={`/obchody/${i.deal_id}`}>{text(i.deal_name)}</Link> : text(i.deal_name)}
                        {i.kind === 'vyrovnanie' && <> <Pill tone="info">vyrovnanie</Pill></>}
                        {i.source === 'sales_portal' && <> <Pill>Sales portál</Pill></>}
                        {i.reassigned_at && <> <Pill>preradená</Pill></>}
                        <div className="sub">{text(i.customer_name)}</div>
                        {i.base_missing && i.status === 'caka' && <div className="sub negative-text">{i.base_missing} – nedá sa uplatniť</div>}
                      </td>
                      {data.me.sees_all && <td>{i.user_name}</td>}
                      <td>{date(i.won_at)}</td>
                      <td className="num">{i.volume_mwh === null ? '–' : dec(i.volume_mwh, 1, 1)}</td>
                      <td className={`num${Number(i.base_eur) < 0 ? ' negative-text' : ''}`}>{eur(i.base_eur)}</td>
                      <td className={`num${Number(i.amount_eur) < 0 ? ' negative-text' : ''}`}>
                        {eur(i.amount_eur)}
                        <div className="sub">{num(i.pct, 2)} %</div>
                      </td>
                      <td>
                        <StatusPill map={COMMISSION_STATE} value={i.status} />
                      </td>
                      <td>
                        {i.claim_id ? (
                          <a href={`/api/commissions/claims/${i.claim_id}/pdf`} target="_blank" rel="noreferrer" className="gl-mono">
                            {i.claim_number}
                          </a>
                        ) : (
                          '–'
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>
        ))
      )}

      <Card flush title="Provízne listy">
        {!data ? null : data.claims.length === 0 ? (
          <Empty>Zatiaľ žiadny provízny list.</Empty>
        ) : (
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Číslo</th>
                  <th>Obchodník</th>
                  <th>Uplatnené</th>
                  <th className="num">Spolu [€]</th>
                  <th>Stav</th>
                  <th>PDF</th>
                  <th aria-label="Akcie" />
                </tr>
              </thead>
              <tbody>
                {data.claims.map((k) => (
                  <tr key={k.id}>
                    <td className="gl-mono">{k.number}</td>
                    <td>
                      {k.user_name}
                      {k.created_by_name && k.created_by_name !== k.user_name && <div className="sub">uplatnil {k.created_by_name}</div>}
                    </td>
                    <td>{date(k.created_at)}</td>
                    <td className="num">{eur(k.total_eur)}</td>
                    <td>
                      {k.voided_at ? (
                        <span title={`${k.voided_by_name ?? ''}: ${k.void_reason ?? ''}`}>
                          <Pill tone="negative">Zrušený {date(k.voided_at)}</Pill>
                        </span>
                      ) : (
                        <Pill tone="positive">Platný</Pill>
                      )}
                      {k.source === 'sales_portal' && <> <Pill>Sales portál</Pill></>}
                    </td>
                    <td>
                      {k.source === 'sales_portal' ? (
                        k.legacy_pdf_url ? <a href={k.legacy_pdf_url} target="_blank" rel="noreferrer">Google Drive</a> : '–'
                      ) : (
                        <>
                          {k.has_pdf ? <a href={`/api/commissions/claims/${k.id}/pdf`} target="_blank" rel="noreferrer">list</a> : <span className="sub">pripravuje sa</span>}
                          {k.voided_at && (k.has_void_pdf
                            ? <> · <a href={`/api/commissions/claims/${k.id}/pdf?kind=zrusenie`} target="_blank" rel="noreferrer">zrušenie</a></>
                            : <span className="sub"> · zrušenie sa pripravuje</span>)}
                        </>
                      )}
                    </td>
                    <td>
                      {data.me.is_admin && !k.voided_at && k.source === 'crm' && (
                        <button type="button" className="btn btn-sm" onClick={() => setVoiding(k)}>
                          Zrušiť list
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="caption" style={{ padding: '10px 24px 16px' }}>
          Provízny list CMSN-RRRR-NNNN sa pošle e-mailom obchodníkovi a príjemcom kópie. Zrušiť ho môže iba admin s dôvodom – provízie sa vrátia na
          „Čaká“ a číslo sa znova nepoužije. História zo Sales portálu je prenesená iba na čítanie.
        </div>
      </Card>

      {voiding && <VoidPanel claim={voiding} onClose={() => setVoiding(null)} onDone={() => { setVoiding(null); reload(); }} />}
    </>
  );
}

function VoidPanel(props: { claim: Claim; onClose: () => void; onDone: () => void }) {
  const [reason, setReason] = useState('');
  const save = useSave();
  const run = () =>
    save.run(async () => {
      await send('POST', `/api/commissions/claims/${props.claim.id}/void`, { reason });
      props.onDone();
    });
  return (
    <SidePanel
      title={`Zrušiť provízny list ${props.claim.number}`}
      onClose={props.onClose}
      footer={
        <button type="button" className="btn primary" disabled={save.busy || reason.trim().length < 3} onClick={run}>
          Zrušiť list
        </button>
      }
    >
      <p>
        Provízie listu ({props.claim.user_name}, {money(props.claim.total_eur)}) sa vrátia na „Čaká na uplatnenie“ a prepočítajú sa. PDF dostane pečiatku
        ZRUŠENÉ (nový súbor, pôvodný ostáva) a obchodník aj príjemcovia kópie dostanú e-mail. Číslo {props.claim.number} sa znova nepoužije.
      </p>
      <Field label="Dôvod zrušenia" wide>
        <TextInput value={reason} onChange={setReason} maxLength={500} />
      </Field>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
