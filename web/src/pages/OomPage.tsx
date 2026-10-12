// Karta odberného miesta podľa docs/dizajn/obrazovky/02-karta-oom.html.

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
  Pill,
  Rows,
  Source,
  StatusPill,
} from '../components/ui';
import { useApi, type OomCard } from '../lib/api';
import { date, eurMonth, eurMwh, kw, mwh, num, pct, period, sumNum, text } from '../lib/format';
import {
  dealTone,
  DIRECTION,
  label,
  OOM_STATUS,
  OOM_TYPE,
  PRICE_STATUS,
  SEGMENT,
  SOURCE_KIND,
  SOURCE_TYPE,
  SUPPLIER_NOTICE,
} from '../lib/labels';

export function OomPage() {
  const { id = '' } = useParams();
  const { data: o, error } = useApi<OomCard>(`/api/oom/${id}`);

  if (error) return <ErrorState error={error} />;
  if (!o || o.id !== id) return <PageSkeleton />;

  const customerPath = o.company_id ? `/firmy/${o.company_id}` : `/osoby/${o.person_id}`;
  const producer = o.type !== 'spotreba';
  const street = [o.address_street, o.address_number_supisne, o.address_number_orientacne].filter(Boolean).join(' ');

  return (
    <>
      <BackLink />
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="t-page-title" style={{ fontFamily: 'var(--font-mono)' }}>
            {o.eic}
          </h1>
          <div className="page-sub">
            <span>Odberné miesto · {label(OOM_TYPE, o.type)}</span>
            <StatusPill map={OOM_STATUS} value={o.status} />
            <span>
              Zákazník: <Link to={customerPath}>{o.customer_name || '(bez mena)'}</Link>
            </span>
            <HubSpotLink object="oom" id={o.hubspot_id} />
          </div>
        </div>
      </header>

      <section className="kpis" aria-label="Ukazovatele">
        <Kpi label="Plánovaná spotreba" value={mwh(sumNum(o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh))} sub={`VT ${mwh(o.planned_consumption_vt_mwh)} · NT ${mwh(o.planned_consumption_nt_mwh)}`} />
        <Kpi label="Plánovaný výkup" value={mwh(o.planned_feed_in_mwh)} sub="ročne" />
        <Kpi label="Výkon zdroja" value={kw(o.source_power_kw)} sub={producer ? text(label(SOURCE_KIND, o.source_kind)) : 'bez zdroja'} />
        <Kpi label="Rezervovaná kapacita" value={kw(o.reserved_capacity_kw)} sub={`MRK ${kw(o.max_reserved_capacity_kw)}`} />
        <Kpi label="Dodávka" value={o.supply_to ? date(o.supply_to) : 'neurčito'} sub={`od ${date(o.supply_from)}`} />
      </section>

      <div className="columns">
        <div className="col-left">
          <Card title="Miesto a distribúcia">
            <Rows
              stacked
              rows={[
                ['Adresa', text([street, [o.address_zip, o.address_city].filter(Boolean).join(' ')].filter(Boolean).join(', '))],
                ['Segment', text(label(SEGMENT, o.segment))],
                ['PDS', text(o.pds)],
                ['Číslo OP', <span className="mono">{text(o.pds_point_id)}</span>],
                ['Sadzba PDS', text(o.pds_tariff)],
                ['Napäťová úroveň', text(o.voltage_level)],
                ['Typ merania', text(o.metering_type)],
                ['Počet fáz', text(o.phases)],
                ['Istič', num(o.breaker_a, 2, 'A')],
                ['Spôsob rezervácie', text(o.capacity_reservation_method)],
              ]}
            />
          </Card>
          <Card title="Fakturácia">
            <Rows
              stacked
              rows={[
                ['Cenová regulácia', text(o.price_regulation)],
                ['Spotrebná daň', text(o.excise_tax)],
                ['Fakturačné obdobie', text(o.billing_period)],
                ['Zálohové faktúry', text(o.advance_payment_method)],
                ['Záloha', pct(o.advance_payment_pct)],
              ]}
            />
          </Card>
          {producer && (
            <Card title="Zdroj">
              <Rows
                stacked
                rows={[
                  ['Druh zdroja', text(label(SOURCE_KIND, o.source_kind))],
                  ['Typ zdroja', text(label(SOURCE_TYPE, o.source_type))],
                  ['Výkon zdroja', kw(o.source_power_kw)],
                  ['Výkon striedača', kw(o.inverter_power_kw)],
                  ['Výkon panelov', kw(o.panels_power_kw)],
                  ['Typ výkupnej zmluvy', text(o.feed_in_contract_type)],
                ]}
              />
            </Card>
          )}
          <Card title="Zmena dodávateľa">
            <Rows
              stacked
              rows={[
                ['Dodávka', period(o.supply_from, o.supply_to)],
                ['Výpoveď predošlému', text(label(SUPPLIER_NOTICE, o.previous_supplier_notice))],
                ['Akceptácia výpovede k', date(o.previous_supplier_notice_accepted_at)],
              ]}
            />
          </Card>
        </div>

        <div className="col-wide">
          <Card title={`Zmluvné ceny (${o.prices.length})`} aside={<Source />} flush>
            {o.prices.length === 0 ? (
              <div className="card-body">
                <Empty>Zatiaľ žiadne zmluvné ceny.</Empty>
              </div>
            ) : (
              <div className="table-wrap">
                <table className="tbl">
                  <thead>
                    <tr>
                      <th>Zmluva</th>
                      <th>Produkt</th>
                      <th>Smer</th>
                      <th className="num">VT / 1T</th>
                      <th className="num">NT</th>
                      <th className="num">Odchýlka</th>
                      <th className="num">Poplatok OM</th>
                      <th>Účinnosť</th>
                      <th>Stav</th>
                    </tr>
                  </thead>
                  <tbody>
                    {o.prices.map((p) => (
                      <tr key={p.id}>
                        <td>
                          <Link to={`/zmluvy/${p.contract_id}`}>{p.contract_number ?? '(bez čísla)'}</Link>
                        </td>
                        <td title={p.product ?? undefined}>{text(p.product)}</td>
                        <td>{text(label(DIRECTION, p.direction))}</td>
                        <td className="num">{eurMwh(p.price_vt_eur_mwh)}</td>
                        <td className="num">{eurMwh(p.price_nt_eur_mwh)}</td>
                        <td className="num">{eurMwh(p.imbalance_price_eur_mwh)}</td>
                        <td className="num">{eurMonth(p.fee_oom_eur_month)}</td>
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
              <Card title={`Dealy (${o.deals.length})`}>
                {o.deals.length === 0 ? (
                  <Empty>Zatiaľ žiadne dealy.</Empty>
                ) : (
                  o.deals.map((d) => (
                    <Item
                      key={d.id}
                      title={d.contract_id ? <Link to={`/zmluvy/${d.contract_id}`}>{d.name}</Link> : d.name}
                      meta={[d.pipeline, d.owner_name, d.closed_at ? `uzavretý ${date(d.closed_at)}` : null].filter(Boolean).join(' · ')}
                      side={<Pill tone={dealTone(d)}>{d.stage}</Pill>}
                    />
                  ))
                )}
              </Card>
            </div>
            <div className="col-mid">
              <Card title={`Kontakty (${o.contacts.length})`}>
                {o.contacts.length === 0 ? (
                  <Empty>
                    Žiadne kontakty. Kontakt sa s OOM prepája cez dealy iba pri stave Aktívne alebo Neaktívne.
                  </Empty>
                ) : (
                  o.contacts.map((p) => (
                    <Item key={p.id} title={p.name || '(bez mena)'} meta={[p.email, p.mobile ?? p.phone].filter(Boolean).join(' · ') || undefined} />
                  ))
                )}
              </Card>
            </div>
          </div>
        </div>
      </div>
    </>
  );
}
