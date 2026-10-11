// Karta zákazníka (firma alebo domácnosť) podľa docs/dizajn/obrazovky/01-karta-firmy.html (variant B):
// KPI v jednom rade; vľavo údaje a FinStat, v strede časová os, vpravo kontakty, OOM, dealy, zmluvy.

import { Link, useParams } from 'react-router-dom';
import {
  Avatar,
  BackLink,
  Card,
  Empty,
  ErrorState,
  HubSpotLink,
  Item,
  Kpi,
  NotInPrototype,
  PageSkeleton,
  Pill,
  Rows,
  Source,
  StatusPill,
} from '../components/ui';
import { useApi, type CustomerCard } from '../lib/api';
import { date, kw, mwh, num, period, sumNum, text } from '../lib/format';
import { CONTRACT_STATUS, dealTone, label, OOM_STATUS, OOM_TYPE, PAYMENT_RATING, SEGMENT, yesNo } from '../lib/labels';

export function CustomerPage(props: { kind: 'company' | 'person' }) {
  const { id = '' } = useParams();
  const path = props.kind === 'company' ? `/api/companies/${id}` : `/api/persons/${id}`;
  const { data: c, error } = useApi<CustomerCard>(path);

  if (error) return <ErrorState error={error} />;
  if (!c || c.id !== id) return <PageSkeleton />;

  const isCompany = c.kind === 'company';
  const k = c.kpi;
  const owner = c.owner_name ? [c.owner_name, c.owner_team].filter(Boolean).join(' · ') : text(null);

  return (
    <>
      <BackLink />
      <header className="page-head">
        <div className="page-head-main">
          <Avatar name={c.name} />
          <div style={{ minWidth: 0 }}>
            <h1 className="t-page-title" title={c.name}>
              {c.name || '(bez mena)'}
            </h1>
            <div className="page-sub">
              <span>{isCompany ? 'Firma' : 'Domácnosť'}</span>
              {isCompany && c.ico && <span className="mono">IČO {c.ico}</span>}
              {c.segment && <Pill>{label(SEGMENT, c.segment)}</Pill>}
              {c.owner_name && <span>Obchodník: {c.owner_name}</span>}
              <HubSpotLink object={isCompany ? 'company' : 'contact'} id={c.hubspot_id} />
            </div>
          </div>
        </div>
      </header>

      <section className="kpis" aria-label="Ukazovatele">
        <Kpi label="Odberné miesta" value={num(k.oom_count, 0)} sub={`aktívne ${num(k.oom_active, 0)}`} />
        <Kpi label="Aktívne zmluvy" value={num(k.active_contracts, 0)} sub={`zmlúv spolu ${num(c.contracts.length, 0)}`} />
        <Kpi label="Plánovaná spotreba" value={mwh(k.planned_consumption_mwh)} sub="ročne, VT + NT zo všetkých OOM" />
        <Kpi label="Plánovaný výkup" value={mwh(k.planned_feed_in_mwh)} sub="ročne zo všetkých OOM" />
        <Kpi label="Výkon zdrojov" value={kw(k.source_power_kw)} sub="súčet výkonov zdrojov OOM" />
      </section>

      <div className="columns">
        <div className="col-left">
          <Card title={isCompany ? 'Firemné informácie' : 'Údaje'}>
            <Rows
              stacked
              rows={
                isCompany
                  ? [
                      ['Obchodník', owner],
                      ['IČO', <span className="mono">{text(c.ico)}</span>],
                      ['DIČ', text(c.dic)],
                      ['IČ DPH', text(c.ic_dph)],
                      ['Bankový účet', <span className="mono">{text(c.bank_account)}</span>],
                      ['Platobný rating', text(label(PAYMENT_RATING, c.payment_rating))],
                      ['Zastúpený', text(c.statutory)],
                      ['Zapísaný v Obchodnom registri', text(c.registry_entry)],
                      ['SK NACE', text(c.nace)],
                      ['Adresa', text(c.address)],
                      ['Segment', text(label(SEGMENT, c.segment))],
                      ['Fáza (HubSpot)', text(c.lifecycle_stage)],
                    ]
                  : [
                      ['Obchodník', owner],
                      ['E-mail', c.email ? <a href={`mailto:${c.email}`}>{c.email}</a> : text(null)],
                      ['Telefón', text(c.phone)],
                      ['Mobil', text(c.mobile)],
                      ['Adresa', text(c.address)],
                      ['Segment', text(label(SEGMENT, c.segment))],
                      ['Zdroj kontaktu', text(c.source)],
                      ['Fáza (HubSpot)', text(c.lifecycle_stage)],
                    ]
              }
            />
          </Card>

          {isCompany ? (
            <Card title="FinStat" aside={c.finstat_url ? <a href={c.finstat_url} target="_blank" rel="noreferrer">Otvoriť ↗</a> : undefined}>
              <Rows
                stacked
                rows={[
                  ['Dlhy a nedoplatky', text(yesNo(c.debts_note))],
                  ['Konkurzy a reštrukturalizácie', text(yesNo(c.insolvency_note))],
                ]}
              />
              <NotInPrototype what="platobné hodnotenie a dáta z FinStatu sa nenačítavajú." />
            </Card>
          ) : (
            <Card title="Firmy">
              {c.companies.length === 0 ? (
                <Empty>Kontakt nie je priradený k žiadnej firme.</Empty>
              ) : (
                c.companies.map((f) => (
                  <Item
                    key={f.id}
                    title={<Link to={`/firmy/${f.id}`}>{f.name}</Link>}
                    meta={f.ico ? `IČO ${f.ico}` : undefined}
                    side={f.is_primary ? <Pill tone="info">Hlavná</Pill> : undefined}
                  />
                ))
              )}
            </Card>
          )}
        </div>

        <div className="col-mid">
          <Card title="Časová os" aside={<Source />}>
            <NotInPrototype what="aktivity, e-maily, hovory a tickety sa do vzorky nenahrávali." />
          </Card>
        </div>

        <div className="col-right">
          {isCompany && (
            <Card title={`Kontakty (${c.contacts.length})`}>
              {c.contacts.length === 0 ? (
                <Empty>Zatiaľ žiadne kontakty.</Empty>
              ) : (
                c.contacts.map((p) => (
                  <Item
                    key={p.id}
                    title={[p.title, p.name].filter(Boolean).join(' ') || '(bez mena)'}
                    meta={[p.position, p.email, p.mobile ?? p.phone].filter(Boolean).join(' · ') || undefined}
                    side={p.is_primary ? <Pill tone="info">Hlavná firma</Pill> : undefined}
                  />
                ))
              )}
            </Card>
          )}

          <Card title={`Odberné miesta (${c.ooms.length})`}>
            {c.ooms.length === 0 ? (
              <Empty>Zatiaľ žiadne OOM.</Empty>
            ) : (
              c.ooms.map((o) => (
                <Item
                  key={o.id}
                  title={
                    <Link to={`/oom/${o.id}`} className="mono" style={{ color: 'var(--brand-text)' }}>
                      {o.eic}
                    </Link>
                  }
                  meta={[
                    label(OOM_TYPE, o.type),
                    [o.address_street, o.address_city].filter(Boolean).join(', '),
                    o.type === 'spotreba'
                      ? mwh(sumNum(o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh))
                      : `výkup ${mwh(o.planned_feed_in_mwh)}`,
                  ]
                    .filter(Boolean)
                    .join(' · ')}
                  side={<StatusPill map={OOM_STATUS} value={o.status} />}
                />
              ))
            )}
          </Card>

          <Card title={`Dealy (${c.deals.length})`}>
            {c.deals.length === 0 ? (
              <Empty>Zatiaľ žiadne dealy.</Empty>
            ) : (
              c.deals.map((d) => (
                <Item
                  key={d.id}
                  title={d.contract_id ? <Link to={`/zmluvy/${d.contract_id}`}>{d.name}</Link> : d.name}
                  meta={[d.pipeline, d.owner_name, d.closed_at ? `uzavretý ${date(d.closed_at)}` : null, `${d.oom_count ?? 0} OOM`]
                    .filter(Boolean)
                    .join(' · ')}
                  side={<Pill tone={dealTone(d)}>{d.stage}</Pill>}
                />
              ))
            )}
          </Card>

          <Card title={`Zmluvy (${c.contracts.length})`}>
            {c.contracts.length === 0 ? (
              <Empty>Zatiaľ žiadne zmluvy.</Empty>
            ) : (
              c.contracts.map((z) => (
                <Item
                  key={z.id}
                  title={<Link to={`/zmluvy/${z.id}`}>{z.number ?? `(bez čísla) ${z.deal_name ?? ''}`}</Link>}
                  meta={`${period(z.valid_from, z.valid_to)} · ${z.oom_count} OOM · ${z.price_count} cien`}
                  side={
                    <>
                      {!z.confirmed && <Pill tone="warning">Nepotvrdená</Pill>}
                      <StatusPill map={CONTRACT_STATUS} value={z.status} />
                    </>
                  }
                />
              ))
            )}
          </Card>
        </div>
      </div>
    </>
  );
}
