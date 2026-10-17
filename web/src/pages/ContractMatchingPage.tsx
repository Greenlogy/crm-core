// Zmluvy k obchodom (dizajn 40; modul 5, F5; zadanie 10; migrácia 0045): obchody v Akceptácii, ktoré čakajú na zmluvu
// (očakávané a spárované zmluvy, chýbajúce EIC, lehota 14 dní, stav podkladov), nespárované zmluvy z importu s kandidátmi
// (vybrať obchod, bez obchodu – vlastník zákazníka alebo admin) a zmluvy s cenou inou ako v ponuke.

import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Field, Notice, SidePanel, TextInput, useSave } from '../components/form';
import { PageHero } from '../components/hero';
import { Card, Empty, ErrorState, Pill, Skeleton } from '../components/ui';
import { type DealCandidate, send, useApi } from '../lib/api';
import { date } from '../lib/format';
import { CONTRACT_TYPE } from '../lib/labels';

type Waiting = {
  id: string; name: string; customer: string | null; accepted_at: string | null; due: string | null; kind: string;
  expected: number; groups: string[]; matched: number; missing_eic: string[]; completeness: { filled: number; total: number }; owner_name: string;
};
type Unmatched = {
  contract_id: string; number: string; type: string; customer: string | null; company_id: string | null; person_id: string | null;
  ooms: { eic: string; voltage: string | null }[]; candidates: DealCandidate[]; can_decide: boolean;
};
type PriceFlag = { id: string; year: number | null; detail: string | null; contract_id: string; number: string; deal_id: string | null; deal_name: string | null; offer_number: string | null; variant: string | null };

const STAGE: Record<string, string> = { akceptacia: 'Akceptácia', vyjednavanie: 'Vyjednávanie', vyhrane: 'Vyhraté' };

function daysLeft(due: string | null): number | null {
  if (!due) return null;
  return Math.ceil((new Date(due).getTime() - Date.now()) / 86_400_000);
}

export function ContractMatchingPage() {
  const { data, error, reload } = useApi<{ waiting: Waiting[]; unmatched: Unmatched[]; prices: PriceFlag[] }>('/api/contract-matching');
  const [none, setNone] = useState<Unmatched | null>(null);
  const [note, setNote] = useState('');
  const save = useSave();
  if (error) return <ErrorState error={error} />;
  if (!data) return <Skeleton lines={10} />;
  const pick = (u: Unmatched, dealId: string) => save.run(async () => {
    await send('POST', `/api/contracts/${u.contract_id}/deal`, { deal_id: dealId });
    reload();
  });
  return (
    <>
      <PageHero title="Zmluvy k obchodom" sub="akceptované obchody a párovanie importu" />
      {save.error && <Notice tone="error">{save.error}</Notice>}

      <Card title="Čaká na zmluvu (Akceptácia)" aside={<span className="caption">zadáva obchodník (firmy), back office (domácnosti), Nákup (výkup)</span>} flush>
        {data.waiting.length === 0 ? <Empty>Žiadny obchod v Akceptácii.</Empty> : (
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>Obchod</th><th>Akceptované</th><th>Očakávané zmluvy</th><th>Spárované</th><th>Lehota 14 dní</th><th>Podklady</th></tr></thead>
              <tbody>
                {data.waiting.map((w) => {
                  const left = daysLeft(w.due);
                  const late = left !== null && left < 0;
                  return (
                    <tr key={w.id}>
                      <td><Link to={`/obchody/${w.id}`}>{w.name}</Link><div className="sub">{w.customer} · {w.owner_name}</div></td>
                      <td>{w.accepted_at ? date(w.accepted_at) : '–'}</td>
                      <td>{w.expected === 1 ? '1 zmluva' : `${w.expected} zmluvy`}{w.groups.length > 1 ? ` (${w.groups.join(', ')})` : ''}</td>
                      <td>{w.matched} / {w.expected}{w.matched > 0 ? ' spárované' : ''}</td>
                      <td>
                        {left === null ? '–' : (
                          <Pill tone={late ? 'negative' : 'warning'}>
                            {w.missing_eic.length > 0 && w.matched > 0 ? `chýba ${w.missing_eic.length} EIC · ` : ''}
                            {late ? 'po 14 dňoch' : `${left} dní zostáva`}
                          </Pill>
                        )}
                      </td>
                      <td>
                        <Link to={`/obchody/${w.id}/podklady`}>
                          podklady {w.completeness.filled}/{w.completeness.total}
                        </Link>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card title="Nespárované zmluvy z importu" aside={data.unmatched.length ? <Pill tone="warning">{data.unmatched.length}</Pill> : undefined} flush>
        {data.unmatched.length === 0 ? <Empty>Všetky nové zmluvy sú spárované alebo označené „Bez obchodu“.</Empty> : (
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>Zmluva</th><th>Zákazník</th><th>OOM</th><th>Kandidáti</th><th /></tr></thead>
              <tbody>
                {data.unmatched.map((u) => {
                  const ok = u.candidates.filter((x) => x.ok);
                  return (
                    <tr key={u.contract_id}>
                      <td><Link className="mono" to={`/zmluvy/${u.contract_id}`}>{u.number}</Link><div className="sub">{CONTRACT_TYPE[u.type] ?? u.type}</div></td>
                      <td><Link to={u.company_id ? `/firmy/${u.company_id}` : `/osoby/${u.person_id}`}>{u.customer}</Link></td>
                      <td className="mono">{u.ooms.map((o) => o.eic).join(', ')}</td>
                      <td>
                        {u.candidates.length === 0 ? 'žiadny obchod v Akceptácii ani Vyjednávaní' : u.candidates.map((x) => (
                          <div key={x.deal_id}>
                            <Link to={`/obchody/${x.deal_id}`}>{x.name}</Link> · {STAGE[x.stage] ?? x.stage} · EIC {x.eic_match}/{x.eic_total}
                            {u.can_decide && (
                              <button type="button" className="btn btn-sm" disabled={save.busy} onClick={() => pick(u, x.deal_id)} style={{ marginLeft: 8 }}>
                                Vybrať
                              </button>
                            )}
                          </div>
                        ))}
                        {ok.length > 1 && <div className="caption">viac obchodov vyhovuje – vyberte správny</div>}
                      </td>
                      <td>
                        {u.can_decide && <button type="button" className="btn" onClick={() => { setNone(u); setNote(''); }}>Bez obchodu</button>}
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
        <div className="caption" style={{ padding: '10px 24px 16px' }}>
          Import páruje zmluvu s otvoreným obchodom toho istého zákazníka podľa EIC (Akceptácia: akceptovaný variant; Vyjednávanie: OOM obchodu).
          Jednoznačná zhoda sa spáruje sama; ostatné vyberie vlastník zákazníka alebo admin, alebo označí „Bez obchodu“.
        </div>
      </Card>

      <Card title="Cena iná ako v ponuke" aside={data.prices.length ? <Pill tone="negative">{data.prices.length}</Pill> : undefined} flush>
        {data.prices.length === 0 ? <Empty>Žiadna zmluva s cenou inou ako v akceptovanej ponuke.</Empty> : (
          <div className="table-wrap">
            <table className="tbl">
              <thead><tr><th>Zmluva</th><th>Obchod</th><th>Ponuka (variant)</th><th>Rozdiel</th></tr></thead>
              <tbody>
                {data.prices.map((p) => (
                  <tr key={p.id}>
                    <td><Link className="mono" to={`/zmluvy/${p.contract_id}`}>{p.number}</Link></td>
                    <td>{p.deal_id ? <Link to={`/obchody/${p.deal_id}`}>{p.deal_name}</Link> : '–'}</td>
                    <td className="mono">{p.offer_number ? `${p.offer_number} · ${p.variant}` : '–'}</td>
                    <td>{p.detail}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
        <div className="caption" style={{ padding: '10px 24px 16px' }}>
          Upozornenie dostane obchodník a schvaľovatelia cien. Príznak uzatvára schvaľovateľ cien s poznámkou na karte zmluvy.
        </div>
      </Card>

      {none && (
        <SidePanel
          title={`Bez obchodu · ${none.number}`}
          onClose={() => setNone(null)}
          footer={<button type="button" className="btn primary" disabled={save.busy} onClick={() => save.run(async () => {
            await send('POST', `/api/contracts/${none.contract_id}/no-deal`, { note });
            setNone(null);
            reload();
          })}>Označiť bez obchodu</button>}
        >
          <p>Zmluva nepatrí k žiadnemu obchodu (napr. domácnosť z webu). V zozname zmlúv bude pod filtrom „Bez obchodu“.</p>
          <Field label="Poznámka (nepovinné)"><TextInput value={note} maxLength={500} onChange={setNote} /></Field>
        </SidePanel>
      )}
    </>
  );
}
