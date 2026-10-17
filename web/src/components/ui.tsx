// Stavebné prvky (vzhľad podľa docs/design-handoff): karta, štítok stavu, KPI karta, údaje, dátumová dlaždica, stavy načítania.

import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import type { ApiError } from '../lib/api';
import { EMPTY, initials } from '../lib/format';
import { hubspotUrl, SOURCE_NOTE, type Tone } from '../lib/labels';

export function Card(props: {
  title?: string;
  aside?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
  flush?: boolean;
  label?: string;
  className?: string;
}) {
  return (
    <section className={props.className ? `card ${props.className}` : 'card'} aria-label={props.label ?? props.title}>
      {props.title && (
        <div className="card-head">
          <h2 className="t-section-title">{props.title}</h2>
          {props.aside}
        </div>
      )}
      {props.flush ? props.children : <div className="card-body">{props.children}</div>}
      {props.footer && <div className="card-foot">{props.footer}</div>}
    </section>
  );
}

export function Pill(props: { tone?: Tone; live?: boolean; children: ReactNode }) {
  return (
    <span className={`pill ${props.tone ?? 'neutral'}`}>
      {props.live && <span className="dot" aria-hidden="true" />}
      {props.children}
    </span>
  );
}

export function StatusPill(props: { map: Record<string, { label: string; tone: Tone; live?: boolean }>; value: string | null | undefined }) {
  if (!props.value) return null;
  const s = props.map[props.value] ?? { label: props.value, tone: 'neutral' as Tone };
  return (
    <Pill tone={s.tone} live={s.live}>
      {s.label}
    </Pill>
  );
}

export function Kpi(props: {
  label: string;
  value: ReactNode;
  sub?: ReactNode;
  /** soft: jedna hlavná KPI na obrazovke (jemný prechod), danger: červená karta (napr. krok po termíne) */
  variant?: 'soft' | 'danger';
  /** zvýraznené číslo v --gl-brand-blue (odhad provízie) */
  accent?: boolean;
  /** záporná hodnota (napr. pridaná hodnota) v červenej */
  negative?: boolean;
}) {
  // Bez dát sa zobrazí „—“, nikdy 0 (komponent KpiCard).
  const cls = ['card', 'kpi', props.variant && `kpi-${props.variant}`, props.accent && 'kpi-accent', props.negative && 'kpi-negative'].filter(Boolean).join(' ');
  return (
    <div className={cls}>
      <div className="kpi-label t-label">{props.label}</div>
      <div className="kpi-value t-kpi-lg">{props.value || EMPTY}</div>
      {props.sub && <div className="kpi-sub t-caption">{props.sub}</div>}
    </div>
  );
}

// Údaje kľúč – hodnota. `stacked`: popis nad hodnotou, dlhý text sa zalomí (karty s údajmi v ľavom stĺpci).
export function Rows(props: { rows: [string, ReactNode][]; stacked?: boolean }) {
  return (
    <dl className={props.stacked ? 'rows stacked' : 'rows'}>
      {props.rows.map(([k, v]) => (
        <div className="row" key={k}>
          <dt>{k}</dt>
          <dd title={typeof v === 'string' ? v : undefined}>{v ?? EMPTY}</dd>
        </div>
      ))}
    </dl>
  );
}

export function Item(props: { title: ReactNode; meta?: ReactNode; side?: ReactNode }) {
  return (
    <div className="item">
      <div className="item-main">
        <div className="item-title">{props.title}</div>
        {props.meta && <div className="item-meta">{props.meta}</div>}
      </div>
      {props.side && <div className="item-side">{props.side}</div>}
    </div>
  );
}

const MONTHS = ['jan', 'feb', 'mar', 'apr', 'máj', 'jún', 'júl', 'aug', 'sep', 'okt', 'nov', 'dec'];

/** Dátumová dlaždica 46 × 46 (deň a mesiac), podfarbená podľa naliehavosti; celý dátum je v popise. */
export function DateTile(props: { date: string; tone: Tone }) {
  const [y, m, d] = props.date.slice(0, 10).split('-').map(Number);
  return (
    <span className={`gl-datetile date-tile ${props.tone}`} aria-label={`${d}. ${m}. ${y}`} role="img">
      <b aria-hidden="true">{d}</b>
      <small aria-hidden="true">{MONTHS[m - 1]}</small>
    </span>
  );
}

/** „2 268,8 MWh“ → číslo a jednotka v tlmenej farbe (tabuľky, DESIGN_SPEC § 1.5). */
export function WithUnit(props: { value: string; suffix?: string }) {
  const i = props.value.lastIndexOf(' ');
  if (i < 0 || /\d/.test(props.value.slice(i + 1))) return <>{props.value}</>;
  return (
    <>
      {props.value.slice(0, i)} <span className="unit">{props.value.slice(i + 1)}{props.suffix ? ` ${props.suffix}` : ''}</span>
    </>
  );
}

export const Empty = (props: { children: ReactNode }) => <div className="empty">{props.children}</div>;

export const NotInPrototype = (props: { what: string }) => <Empty>V prototype nie je – {props.what}</Empty>;

// Firma sivá, domácnosť zelená (dizajn 08); veľký avatar v hlavičke karty ostáva zelený.
export function Avatar(props: { name: string; small?: boolean; household?: boolean }) {
  return (
    <span className={`avatar${props.small ? ' sm' : ''}${props.small && !props.household ? ' neutral' : ''}`} aria-hidden="true">
      {initials(props.name)}
    </span>
  );
}

export function HubSpotLink(props: { object: Parameters<typeof hubspotUrl>[0]; id: string | null | undefined }) {
  if (!props.id) return null;
  return (
    <a href={hubspotUrl(props.object, props.id)} target="_blank" rel="noreferrer" className="mono" title="Otvoriť v HubSpote">
      HubSpot {props.id} ↗
    </a>
  );
}

export const Source = () => <span className="caption">{SOURCE_NOTE}</span>;

export function Skeleton(props: { lines?: number }) {
  return (
    <div aria-busy="true" aria-label="Načítavam">
      {Array.from({ length: props.lines ?? 6 }, (_, i) => (
        <div className="skeleton" key={i} style={{ width: `${90 - ((i * 17) % 40)}%` }} />
      ))}
    </div>
  );
}

export function PageSkeleton() {
  return (
    <>
      <div className="card" style={{ padding: '20px 24px' }}>
        <Skeleton lines={2} />
      </div>
      <div className="kpis">
        {Array.from({ length: 4 }, (_, i) => (
          <div className="card kpi" key={i}>
            <Skeleton lines={2} />
          </div>
        ))}
      </div>
      <div className="card" style={{ padding: '20px 24px' }}>
        <Skeleton lines={8} />
      </div>
    </>
  );
}

export function ErrorState(props: { error: ApiError }) {
  const message =
    props.error.status === 404
      ? 'Záznam neexistuje.'
      : props.error.status === 0
        ? 'API nie je dostupné. Beží api/dev.sh?'
        : props.error.message;
  return (
    <div className="error-box" role="alert">
      {message} <Link to="/zakaznici">Späť na zákazníkov</Link>
    </div>
  );
}

export function BackLink() {
  return (
    <Link to="/zakaznici" className="back">
      ← Zákazníci
    </Link>
  );
}
