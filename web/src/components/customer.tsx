// Časti spoločné pre kartu firmy a kartu osoby: štítok stavu, vývoj stavu, OOM, dealy, zmluvy.

import { Link } from 'react-router-dom';
import type { ContractRow, DealRow, OomRow, StatusChange } from '../lib/api';
import { date, mwh, num, period, sumNum } from '../lib/format';
import { CONTRACT_STATUS, CUSTOMER_STATUS, dealTone, label, OOM_STATUS, OOM_TYPE, showFormer, STATUS_SOURCE } from '../lib/labels';
import { Card, Empty, Item, Pill, StatusPill } from './ui';
import { planText } from './oom-actions';
import { useState } from 'react';
import { OomCreatePanel, useCanCreateOom } from './oom-forms';

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
export function OomsCard(props: { ooms: OomRow[]; customer?: { kind: 'company' | 'person'; id: string; name: string; org_id: string } }) {
  const open = props.ooms.filter((o) => !o.valid_to).length;
  const canCreate = useCanCreateOom();
  const [creating, setCreating] = useState(false);
  const aside = (
    <span className="pills">
      {props.ooms.length > open && <span className="caption">a {props.ooms.length - open} v histórii</span>}
      {canCreate && props.customer && (
        <button type="button" className="btn btn-ghost" onClick={() => setCreating(true)}>
          + Nové OOM
        </button>
      )}
    </span>
  );
  return (
    <Card title={`Odberné miesta (${open})`} aside={aside}>
      {creating && props.customer && (
        <OomCreatePanel
          customer={{ ...props.customer, ico: null, email: null, archived: false }}
          onClose={() => setCreating(false)}
        />
      )}
      {props.ooms.length === 0 ? (
        <Empty>Zatiaľ žiadne OOM.</Empty>
      ) : (
        props.ooms.map((o) => (
          <Item
            key={o.link_id ?? o.id}
            title={
              o.eic && o.visible !== false ? (
                <Link to={`/oom/${o.id}`} className="mono" style={{ color: 'var(--brand-text)' }}>
                  {o.eic}
                </Link>
              ) : o.eic ? (
                <span className="mono" title="OOM už patrí inému zákazníkovi">
                  {o.eic}
                </span>
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
            side={
              <span className="pills">
                {o.plan_kind && <Pill tone="info">{planText(o.plan_kind, o.plan_date)}</Pill>}
                <StatusPill map={OOM_STATUS} value={o.status} />
              </span>
            }
          />
        ))
      )}
    </Card>
  );
}

export function DealsCard(props: { deals: DealRow[] }) {
  return (
    <Card title={`Obchody (${props.deals.length})`}>
      {props.deals.length === 0 ? (
        <Empty>Zatiaľ žiadne obchody.</Empty>
      ) : (
        props.deals.map((d) => (
          <Item
            key={d.id}
            title={<Link to={`/obchody/${d.id}`}>{d.name}</Link>}
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
  // súčet bilancie bežného roka (0027): pridaná hodnota; marža iba s právom (inak NULL)
  const year = props.contracts[0]?.balance_year;
  const sum = (k: 'added_value_eur' | 'margin_eur') => {
    const v = props.contracts.map((z) => z[k]).filter((x) => x !== null && x !== undefined);
    return v.length ? v.reduce((n: number, x) => n + Number(x), 0) : null;
  };
  const av = sum('added_value_eur');
  const mg = sum('margin_eur');
  return (
    <Card
      title={`Zmluvy (${props.contracts.length})`}
      aside={
        year && av !== null ? (
          <span className="caption">
            {year}: pridaná hodnota {num(av, 2)} €{mg !== null ? ` · marža firmy ${num(mg, 2)} €` : ''}
          </span>
        ) : undefined
      }
    >
      {props.contracts.length === 0 ? (
        <Empty>Zatiaľ žiadne zmluvy.</Empty>
      ) : (
        props.contracts.map((z) => (
          <Item
            key={z.id}
            title={<Link to={`/zmluvy/${z.id}`}>{z.number ?? `(bez čísla) ${z.deal_name ?? ''}`}</Link>}
            meta={`${period(z.valid_from, z.valid_to)} · ${z.oom_count} OOM · ${z.price_count} cien${
              z.added_value_eur !== null && z.added_value_eur !== undefined ? ` · PH ${z.balance_year}: ${num(z.added_value_eur, 2)} €` : ''
            }${z.margin_eur !== null && z.margin_eur !== undefined ? ` · marža ${num(z.margin_eur, 2)} €` : ''}`}
            side={
              <>
                <StatusPill map={CONTRACT_STATUS} value={z.status} />
              </>
            }
          />
        ))
      )}
    </Card>
  );
}
