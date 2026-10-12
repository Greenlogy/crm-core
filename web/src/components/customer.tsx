// Časti spoločné pre kartu firmy a kartu osoby: štítok stavu, vývoj stavu, OOM, dealy, zmluvy.

import { Link } from 'react-router-dom';
import type { ContractRow, DealRow, OomRow, StatusChange } from '../lib/api';
import { date, mwh, period, sumNum } from '../lib/format';
import { CONTRACT_STATUS, CUSTOMER_STATUS, dealTone, label, OOM_STATUS, OOM_TYPE, showFormer, STATUS_SOURCE } from '../lib/labels';
import { Card, Empty, Item, Pill, StatusPill } from './ui';

// Stav zákazníka + „bývalý“ (napr. „Ponuka · bývalý“) + archív.
export function CustomerStatus(props: { status: string | null; former: boolean; archived?: boolean }) {
  return (
    <>
      <StatusPill map={CUSTOMER_STATUS} value={props.status} />
      {showFormer(props.status, props.former) && <Pill>bývalý</Pill>}
      {props.archived && <Pill tone="negative">Archív</Pill>}
    </>
  );
}

const statusLabel = (s: string) => CUSTOMER_STATUS[s]?.label ?? s;

export function StatusHistoryCard(props: { history: StatusChange[] }) {
  return (
    <Card title="Vývoj stavu" aside={<span className="caption">počíta sa automaticky</span>}>
      {props.history.length === 0 ? (
        <Empty>Bez stavu – osoba je iba kontaktom vo firme.</Empty>
      ) : (
        <ol className="status-steps">
          {props.history.map((h, i) => (
            <li key={`${h.changed_at}-${i}`} className={i === 0 ? 'current' : undefined}>
              <span className="step-dot" aria-hidden="true" />
              <span className="step-main">
                {i === 0 ? <b>{statusLabel(h.status)}</b> : statusLabel(h.status)}
                {h.source && <span className="caption">{STATUS_SOURCE[h.source] ?? h.source}</span>}
              </span>
              <span className="caption">{date(h.changed_at)}</span>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

// OOM zákazníka zo všetkých väzieb: stav platí pre obdobie väzby (po prepise u starého zákazníka „Prepísané“).
export function OomsCard(props: { ooms: OomRow[] }) {
  const open = props.ooms.filter((o) => !o.valid_to).length;
  return (
    <Card title={`Odberné miesta (${open})`} aside={props.ooms.length > open ? <span className="caption">a {props.ooms.length - open} v histórii</span> : undefined}>
      {props.ooms.length === 0 ? (
        <Empty>Zatiaľ žiadne OOM.</Empty>
      ) : (
        props.ooms.map((o) => (
          <Item
            key={o.link_id ?? o.id}
            title={
              o.eic ? (
                <Link to={`/oom/${o.id}`} className="mono" style={{ color: 'var(--brand-text)' }}>
                  {o.eic}
                </Link>
              ) : (
                <span className="muted">OOM patrí inému zákazníkovi</span>
              )
            }
            meta={[
              o.name,
              o.type && label(OOM_TYPE, o.type),
              [o.address_street, o.address_city].filter(Boolean).join(', '),
              o.valid_to
                ? period(o.valid_from ?? null, o.valid_to)
                : o.type === 'vyroba'
                  ? `výkup ${mwh(o.planned_feed_in_mwh)}`
                  : o.type
                    ? mwh(sumNum(o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh))
                    : null,
            ]
              .filter(Boolean)
              .join(' · ')}
            side={<StatusPill map={OOM_STATUS} value={o.status} />}
          />
        ))
      )}
    </Card>
  );
}

export function DealsCard(props: { deals: DealRow[] }) {
  return (
    <Card title={`Dealy (${props.deals.length})`}>
      {props.deals.length === 0 ? (
        <Empty>Zatiaľ žiadne dealy.</Empty>
      ) : (
        props.deals.map((d) => (
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
  );
}

export function ContractsCard(props: { contracts: ContractRow[] }) {
  return (
    <Card title={`Zmluvy (${props.contracts.length})`}>
      {props.contracts.length === 0 ? (
        <Empty>Zatiaľ žiadne zmluvy.</Empty>
      ) : (
        props.contracts.map((z) => (
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
  );
}
