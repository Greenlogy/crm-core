// Karta zmluvy podľa docs/dizajn/obrazovky/03-karta-zmluvy.html.

import { Link, useParams } from 'react-router-dom';
import {
  BackLink,
  Card,
  Empty,
  ErrorState,
  HubSpotLink,
  Item,
  Kpi,
  PageSkeleton,
  Rows,
  Source,
  StatusPill,
} from '../components/ui';
import { useApi, type ContractCard } from '../lib/api';
import { date, eurMonth, eurMwh, mwh, num, pct, period, sumNum, text } from '../lib/format';
import { CONTRACT_STATUS, label, OOM_STATUS, OOM_TYPE, PRICE_SLOT, PRICE_STATUS, SEGMENT } from '../lib/labels';

export function ContractPage() {
  const { id = '' } = useParams();
  const { data: k, error } = useApi<ContractCard>(`/api/contracts/${id}`);

  if (error) return <ErrorState error={error} />;
  if (!k || k.id !== id) return <PageSkeleton />;

  const customerPath = k.company_id ? `/firmy/${k.company_id}` : `/osoby/${k.person_id}`;
  const consumption = sumNum(...k.ooms.flatMap((o) => [o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh]));
  const feedIn = sumNum(...k.ooms.map((o) => o.planned_feed_in_mwh));
  const validPrices = k.prices.filter((p) => p.status === 'platna').length;

  return (
    <>
      <BackLink />
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="t-page-title">Zmluva {k.number ?? '(bez čísla)'}</h1>
          <div className="page-sub">
            <StatusPill map={CONTRACT_STATUS} value={k.status} />
            <span>
              Zákazník: <Link to={customerPath}>{k.customer_name || '(bez mena)'}</Link>
            </span>
            <HubSpotLink object="deal" id={k.deal_hubspot_id} />
          </div>
        </div>
      </header>

      <section className="kpis" aria-label="Ukazovatele">
        <Kpi label="Účinnosť" value={k.effective_to ? date(k.effective_to) : 'neurčito'} sub={`od ${date(k.valid_from)}`} />
        <Kpi label="Odberné miesta" value={num(k.ooms.length, 0)} sub={`platných cien ${validPrices}`} />
        <Kpi label="Plánovaná spotreba" value={mwh(consumption)} sub="ročne, VT + NT z OOM zmluvy" />
        <Kpi label="Plánovaný výkup" value={mwh(feedIn)} sub="ročne z OOM zmluvy" />
      </section>

      <div className="columns">
        <div className="col-left">
          <Card title="Údaje">
            <Rows
              stacked
              rows={[
                ['Číslo zmluvy', text(k.number)],
                ['Stav', <StatusPill map={CONTRACT_STATUS} value={k.status} />],
                ['Účinnosť', period(k.valid_from, k.effective_to)],
                ['Podpísaná', date(k.signed_on)],
                ['Segment', text(label(SEGMENT, k.segment))],
                ['Splatnosť faktúr', k.payment_terms_days === null ? text(null) : `${k.payment_terms_days} dní`],
                ['Tolerancia odberu', k.consumption_tolerance === null ? text(null) : `± ${num(k.consumption_tolerance, 2)} %`],
                ['Preddavok', pct(k.advance_payment_pct)],
              ]}
            />
          </Card>
          <Card title="Deal">
            <Rows
              stacked
              rows={[
                ['Názov', text(k.deal_name)],
                ['Obchodník', text(k.owner_name)],
                ['Pipeline', text(k.pipeline)],
                ['Štádium', text(k.stage)],
              ]}
            />
          </Card>
        </div>

        <div className="col-wide">
          <Card title={`Zmluvné ceny (${k.prices.length})`} aside={<Source />} flush>
            {k.prices.length === 0 ? (
              <div className="card-body">
                <Empty>Zmluva nemá zmluvné ceny.</Empty>
              </div>
            ) : (
              <div className="table-wrap">
                <table className="tbl">
                  <thead>
                    <tr>
                      <th>EIC</th>
                      <th>Produkt</th>
                      <th>Zložka</th>
                      <th className="num">VT / 1T</th>
                      <th className="num">NT</th>
                      <th className="num">Aditív</th>
                      <th className="num">Mesačne</th>
                      <th>Účinnosť</th>
                      <th>Stav</th>
                    </tr>
                  </thead>
                  <tbody>
                    {k.prices.map((p) => (
                      <tr key={p.id}>
                        <td>
                          <Link to={`/oom/${p.oom_id}`} className="mono" style={{ color: 'var(--brand-text)' }}>
                            {p.eic}
                          </Link>
                        </td>
                        <td title={p.product ?? undefined}>{text(p.product)}</td>
                        <td>{text(PRICE_SLOT[p.slot] ?? p.slot)}</td>
                        <td className="num">{eurMwh(p.price_vt_eur_mwh)}</td>
                        <td className="num">{eurMwh(p.price_nt_eur_mwh)}</td>
                        <td className="num">{p.additive_pct !== null && p.additive_pct !== undefined ? pct(p.additive_pct) : eurMwh(p.additive_eur_mwh)}</td>
                        <td className="num">{eurMonth(p.fee_eur_month)}</td>
                        <td>{period(p.valid_from, p.valid_to)}</td>
                        <td>
                          <StatusPill map={PRICE_STATUS} value={p.status} />
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </Card>

          <div className="columns">
            <div className="col-mid">
              <Card title={`Odberné miesta (${k.ooms.length})`}>
                {k.ooms.length === 0 ? (
                  <Empty>Zmluva nemá odberné miesta.</Empty>
                ) : (
                  k.ooms.map((o) => (
                    <Item
                      key={o.id}
                      title={
                        <Link to={`/oom/${o.id}`} className="mono" style={{ color: 'var(--brand-text)' }}>
                          {o.eic}
                        </Link>
                      }
                      meta={[label(OOM_TYPE, o.type), [o.address_street, o.address_city].filter(Boolean).join(', ')].filter(Boolean).join(' · ')}
                      side={<StatusPill map={OOM_STATUS} value={o.status} />}
                    />
                  ))
                )}
              </Card>
            </div>
            <div className="col-mid">
              <Card title={`Nákupné ceny (${k.purchases.length})`}>
                {k.purchases.length === 0 ? (
                  <Empty>Zmluva nemá nákupné ceny.</Empty>
                ) : (
                  k.purchases.map((p) => (
                    <Item
                      key={p.id}
                      title={`${p.product_code} · ${p.delivery_year}`}
                      meta={`nákup ${date(p.priced_on)}`}
                      side={<span style={{ fontVariantNumeric: 'tabular-nums' }}>{eurMwh(p.price_eur_mwh)}</span>}
                    />
                  ))
                )}
                <div className="caption">Cena obchod = vážený priemer PXE BL/PL + 4 €/MWh odchýlka + 4 €/MWh marža.</div>
              </Card>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
