// Karta odberného miesta podľa docs/dizajn/obrazovky/18-oom-karta.html (modul Odberné miesta, F1 – čítanie).
// Záložky Prehľad, Zmluvy a ceny, Kontaktné osoby; Dokumenty zatiaľ nie (úložisko súborov príde neskôr).
// História väzieb a časová os idú z väzieb (oom_customer) a auditu; „Systém“ = automatická zmena (aktivácia, prepočet).

import { useState, type ReactNode } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ContactsCard, DevicesCard } from '../components/oom-children';
import { OomActions, PLAN_DATE_LABEL, PLAN_KIND, PlanBanner } from '../components/oom-actions';
import { BackLink, Card, Empty, ErrorState, HubSpotLink, Item, Kpi, PageSkeleton, Pill, Rows, StatusPill } from '../components/ui';
import { useApi, type AuditEvent, type OomCard, type OomLink } from '../lib/api';
import { date, eurMonth, eurMwh, kw, mwh, num, pct, period, sumNum, text } from '../lib/format';
import {
  dealTone,
  DEVICE_TYPE,
  DIRECTION,
  label,
  LINK_END_REASON,
  OOM_STATUS,
  OOM_TYPE,
  PRICE_STATUS,
  SOURCE_CATEGORY,
  SOURCE_KIND,
  VOLTAGE_LEVEL,
} from '../lib/labels';

type Tab = 'prehlad' | 'zmluvy' | 'osoby';

const today = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Bratislava' });

export const customerPathOf = (l: { customer_kind: 'company' | 'person'; company_id: string | null; person_id: string | null }) =>
  l.customer_kind === 'company' ? `/firmy/${l.company_id}` : `/osoby/${l.person_id}`;

export const oomAddress = (o: {
  address_street: string | null;
  address_number_supisne: string | null;
  address_number_orientacne: string | null;
  address_zip: string | null;
  address_city: string | null;
}) => {
  const number = [o.address_number_supisne, o.address_number_orientacne].filter(Boolean).join('/');
  const street = [o.address_street, number].filter(Boolean).join(' ');
  // PSČ po slovensky „014 01“
  const zip = o.address_zip?.replace(/^(\d{3})(\d{2})$/, '$1 $2');
  return [street, [zip, o.address_city].filter(Boolean).join(' ')].filter(Boolean).join(', ');
};

export function OomPage() {
  const { id = '' } = useParams();
  const { data: o, error, reload } = useApi<OomCard>(`/api/oom/${id}`);
  const [tab, setTab] = useState<Tab>('prehlad');

  if (error) return <ErrorState error={error} />;
  if (!o || o.id !== id) return <PageSkeleton />;

  const address = oomAddress(o);
  const consumption = sumNum(o.planned_consumption_vt_mwh, o.planned_consumption_nt_mwh);
  const tabs: [Tab, string][] = [
    ['prehlad', 'Prehľad'],
    ['zmluvy', `Zmluvy a ceny (${o.prices.length})`],
    ['osoby', `Kontaktné osoby (${o.contacts.length})`],
  ];

  return (
    <>
      <BackLink />
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="t-page-title">{o.name || address || o.eic}</h1>
          <div className="page-sub">
            <StatusPill map={OOM_STATUS} value={o.status} />
            <Pill>{label(OOM_TYPE, o.type)}</Pill>
            <span className="mono">{o.eic}</span>
            {o.customer_name ? (
              <Link to={customerPathOf(o)}>{o.customer_name}</Link>
            ) : (
              <span className="muted">zákazník skrytý</span>
            )}
            {o.owner_name && <span>{o.owner_name}</span>}
            <HubSpotLink object="oom" id={o.hubspot_id} />
          </div>
          {o.transferred_from_name && (
            <div className="caption">
              Prepis od {o.transferred_from_name}
              {o.transferred_on ? ` k ${date(o.transferred_on)}` : ''}
            </div>
          )}
        </div>
        <OomActions o={o} onChanged={reload} />
      </header>

      <PlanBanner o={o} onChanged={reload} />

      <section className="kpis" aria-label="Ukazovatele">
        {o.type === 'vyroba' ? (
          <Kpi label="Plánovaný výkup" value={mwh(o.planned_feed_in_mwh)} sub={o.source_power_kw ? `zdroj ${kw(o.source_power_kw)}` : undefined} />
        ) : (
          <Kpi
            label="Plánovaná spotreba"
            value={mwh(consumption)}
            sub={`VT ${num(o.planned_consumption_vt_mwh, 1)} · NT ${num(o.planned_consumption_nt_mwh, 1)}`}
          />
        )}
        <Kpi
          label="Distribúcia"
          value={[o.pds_label, o.pds_tariff_label].filter(Boolean).join(' · ')}
          sub={[label(VOLTAGE_LEVEL, o.voltage_level), o.phases && `${o.phases} ${o.phases === 1 ? 'fáza' : 'fázy'}`, o.breaker_a && `istič ${num(o.breaker_a, 0)} A`]
            .filter(Boolean)
            .join(' · ')}
        />
        <Kpi label="Dodávka" value={o.supply_from ? `od ${date(o.supply_from)}` : ''} sub={o.supply_to ? `do ${date(o.supply_to)}` : o.supply_from ? 'na neurčito' : undefined} />
        <Kpi label="Prechod k Greenlogy" value={switchSummary(o).label} sub={switchSummary(o).sub} />
      </section>

      {o.active_missing && o.active_missing.length > 0 && (
        <div className="card-body missing-note" role="note">
          Na stav Aktívne chýba: {o.active_missing.join(', ')}.
        </div>
      )}

      <div className="tabs" role="tablist" aria-label="Sekcie odberného miesta">
        {tabs.map(([key, name]) => (
          <button key={key} type="button" role="tab" className="tab" aria-selected={tab === key} onClick={() => setTab(key)}>
            {name}
          </button>
        ))}
      </div>

      {tab === 'prehlad' && <Overview o={o} onChanged={reload} />}
      {tab === 'zmluvy' && <ContractsTab o={o} />}
      {tab === 'osoby' && <ContactsCard o={o} onChanged={reload} />}
    </>
  );
}

function switchSummary(o: OomCard): { label: string; sub?: string } {
  if (o.status === 'aktivne') return { label: 'dokončený', sub: o.supply_from ? `od ${date(o.supply_from)}` : undefined };
  if (o.status !== 'pripravovane') return { label: '—' };
  if (o.switch_stuck) return { label: 'zasekol sa', sub: nextStep(o) };
  return { label: 'prebieha', sub: nextStep(o) };
}

function nextStep(o: OomCard) {
  if (o.switch_notice_required && !o.switch_notice_sent_on) return 'čaká sa na odoslanie výpovede';
  if (o.switch_notice_required && !o.switch_notice_accepted_on) return 'čaká sa na akceptáciu výpovede';
  if (!o.switch_confirmed_on) return 'čaká sa na potvrdenie zmeny';
  return o.supply_from ? `začiatok dodávky ${date(o.supply_from)}` : 'chýba začiatok dodávky';
}

function Overview(props: { o: OomCard; onChanged: () => void }) {
  const o = props.o;
  return (
    <div className="columns">
      <div className="col-left">
        <Card title="Distribúcia">
          <Rows
            stacked
            rows={[
              ['Adresa', text(oomAddress(o))],
              ['PDS', text(o.pds_label)],
              ['Číslo OP', <span className="mono">{text(o.pds_point_id)}</span>],
              ['Sadzba', text(o.pds_tariff_label)],
              ['Napäťová úroveň', text(label(VOLTAGE_LEVEL, o.voltage_level))],
              ['Typ merania', text(o.metering_type_label)],
              ['Fázy', text(o.phases)],
              ['Istič', num(o.breaker_a, 2, 'A')],
              ['Rezervovaná kapacita', kw(o.reserved_capacity_kw)],
              ['Max. rezerv. kapacita', kw(o.max_reserved_capacity_kw)],
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
              ['Fakturačné obdobie', text(o.billing_period_label)],
              ['Zálohy', text(o.advance_payment_method_label)],
              ['Výška zálohy', o.advance_payment_eur ? eurMonth(o.advance_payment_eur) : pct(o.advance_payment_pct)],
            ]}
          />
        </Card>
        {(o.type === 'vyroba' || o.source_kind) && (
          <Card title="Výroba">
            <Rows
              stacked
              rows={[
                ['Druh zdroja', text(label(SOURCE_KIND, o.source_kind))],
                ['Kategória zdroja', text(label(SOURCE_CATEGORY, o.source_category))],
                ['Výkon zdroja', kw(o.source_power_kw)],
                ['Výkon striedača', kw(o.inverter_power_kw)],
                ['Výkon panelov', kw(o.panels_power_kw)],
                ['Typ výkupnej zmluvy', text(o.feed_in_contract_type_label)],
              ]}
            />
          </Card>
        )}
        <Card title="Spoločnosť">
          <Rows stacked rows={[['Spoločnosť skupiny', o.org_name]]} />
        </Card>
      </div>
      <div className="col-wide">
        <div className="columns">
          <div className="col-mid">
            <TimelineCard o={o} />
          </div>
          <div className="col-mid">
            <LinksCard links={o.links} />
            <SwitchCard o={o} />
            <DevicesCard o={o} onChanged={props.onChanged} />
          </div>
        </div>
      </div>
    </div>
  );
}

function LinksCard(props: { links: OomLink[] }) {
  const [at, setAt] = useState(today());
  const owner = props.links.find((l) => l.valid_from <= at && (!l.valid_to || l.valid_to >= at));
  return (
    <Card title="Komu patrí" aside={<span className="caption">história väzieb</span>}>
      {props.links.length === 0 ? (
        <Empty>Bez väzby na zákazníka.</Empty>
      ) : (
        props.links.map((l) => (
          <Item
            key={l.id}
            title={l.customer_name ? <Link to={customerPathOf(l)}>{l.customer_name}</Link> : <span className="muted">iný zákazník</span>}
            meta={[l.valid_to ? period(l.valid_from, l.valid_to) : `od ${date(l.valid_from)}`, l.end_reason && label(LINK_END_REASON, l.end_reason)]
              .filter(Boolean)
              .join(' · ')}
            side={<StatusPill map={OOM_STATUS} value={l.status} />}
          />
        ))
      )}
      <div className="at-date">
        <label className="caption" htmlFor="oom-at">
          Komu patrilo k dátumu
        </label>
        <input id="oom-at" className="input" type="date" value={at} onChange={(e) => setAt(e.target.value)} />
        <span>
          →{' '}
          <b>
            {owner ? (owner.customer_name ?? 'iný zákazník') : 'nikomu (nebolo u nás)'}
          </b>
        </span>
      </div>
    </Card>
  );
}

function SwitchCard(props: { o: OomCard }) {
  const o = props.o;
  const now = today();
  const steps: { label: string; date: string | null; skip?: boolean }[] = [
    { label: 'Výpoveď predošlému dodávateľovi odoslaná', date: o.switch_notice_sent_on, skip: !o.switch_notice_required },
    { label: 'Výpoveď akceptovaná', date: o.switch_notice_accepted_on, skip: !o.switch_notice_required },
    { label: 'Zmena dodávateľa potvrdená', date: o.switch_confirmed_on },
    { label: 'Začiatok dodávky', date: o.supply_from && o.supply_from <= now && o.status === 'aktivne' ? o.supply_from : null },
  ];
  const state = switchSummary(o);
  const tone = o.status === 'aktivne' ? 'positive' : o.switch_stuck ? 'warning' : 'info';
  return (
    <Card title="Prechod k Greenlogy" aside={o.status === 'aktivne' || o.status === 'pripravovane' ? <Pill tone={tone}>{state.label}</Pill> : undefined}>
      {o.previous_supplier_label && <div className="caption">Predošlý dodávateľ: {o.previous_supplier_label}</div>}
      <ol className="status-steps">
        {steps.map((s) => (
          <li key={s.label} className={s.date ? 'current' : undefined}>
            <span className="step-dot" aria-hidden="true" />
            <span className="step-main">
              <span>
                {s.date ? '✓ ' : ''}
                {s.label}
              </span>
              {s.skip && <span className="sub">nezasiela sa (napr. nová prípojka)</span>}
            </span>
            <span className="sub">{s.date ? date(s.date) : s.skip ? '' : '—'}</span>
          </li>
        ))}
      </ol>
      {o.switch_stuck && (
        <div className="missing-note">
          Prechod sa zasekol: lehota {o.switch_notice_accepted_on ? o.oom_switch_confirm_days : o.oom_switch_accept_days} dní uplynula
          bez ďalšieho kroku.
        </div>
      )}
    </Card>
  );
}

// --- Časová os z auditu ---

const FIELD_LABEL: Record<string, string> = {
  name: 'Názov',
  eic: 'EIC',
  type: 'Typ',
  address_street: 'Ulica',
  address_number_supisne: 'Súpisné číslo',
  address_number_orientacne: 'Orientačné číslo',
  address_city: 'Obec',
  address_zip: 'PSČ',
  pds: 'PDS',
  pds_point_id: 'Číslo OP',
  pds_tariff: 'Sadzba',
  voltage_level: 'Napäťová úroveň',
  metering_type: 'Typ merania',
  phases: 'Fázy',
  breaker_a: 'Istič',
  reserved_capacity_kw: 'Rezervovaná kapacita',
  max_reserved_capacity_kw: 'Max. rezerv. kapacita',
  capacity_reservation_method: 'Spôsob rezervácie',
  price_regulation: 'Cenová regulácia',
  excise_tax: 'Spotrebná daň',
  billing_period: 'Fakturačné obdobie',
  advance_payment_method: 'Zálohy',
  advance_payment_pct: 'Záloha [%]',
  advance_payment_eur: 'Záloha [€]',
  planned_consumption_vt_mwh: 'Plánovaná spotreba VT',
  planned_consumption_nt_mwh: 'Plánovaná spotreba NT',
  planned_feed_in_mwh: 'Plánovaný výkup',
  source_power_kw: 'Výkon zdroja',
  source_kind: 'Druh zdroja',
  source_category: 'Kategória zdroja',
  feed_in_contract_type: 'Typ výkupnej zmluvy',
  inverter_power_kw: 'Výkon striedača',
  panels_power_kw: 'Výkon panelov',
  supply_from: 'Dodávka od',
  supply_to: 'Dodávka do',
  previous_supplier: 'Predošlý dodávateľ',
  switch_notice_required: 'Výpoveď sa zasiela',
  switch_notice_sent_on: 'Výpoveď odoslaná',
  switch_notice_accepted_on: 'Výpoveď akceptovaná',
  switch_confirmed_on: 'Zmena dodávateľa potvrdená',
};
// Zákazník, stav a spoločnosť OOM sa menia cez väzby – ukazujú sa ako udalosti väzby, nie ako zmena údajov.
const LINK_FIELDS = new Set(['company_id', 'person_id', 'status', 'org_id', 'id', 'created_at']);

// Hodnoty enumov po slovensky (kódy číselníkov ostávajú kódom)
const VALUE_LABEL: Record<string, Record<string, string>> = {
  source_kind: SOURCE_KIND,
  source_category: SOURCE_CATEGORY,
  voltage_level: VOLTAGE_LEVEL,
  type: Object.fromEntries(Object.entries(OOM_TYPE)),
};

const val = (v: unknown, field?: string) => {
  if (v === null || v === undefined || v === '') return '–';
  if (field && typeof v === 'string' && VALUE_LABEL[field]?.[v]) return VALUE_LABEL[field][v];
  if (typeof v === 'boolean') return v ? 'áno' : 'nie';
  if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)) return date(v);
  return String(v);
};

type Event = { key: string; icon: string; title: ReactNode; at: string; meta: string };

function describe(o: OomCard): Event[] {
  const ev = o.timeline;
  const names = o.names;
  const customer = (d: Record<string, unknown>) => {
    const id = (d.company_id ?? d.person_id) as string | undefined;
    return (id && names[id]) || 'iný zákazník';
  };
  const meta = (e: AuditEvent) =>
    e.source === 'import'
      ? ['import z Excelu', e.import_file, e.user_name].filter(Boolean).join(' · ')
      : e.source === 'system' || !e.user_name
        ? 'Systém'
        : e.user_name;
  const oomInsertAt = ev.find((e) => e.table_name === 'oom' && e.action === 'insert')?.changed_at;
  const prepisAt = new Set(
    ev.filter((e) => e.table_name === 'oom_customer' && e.action === 'update' && (e.diff.end_reason as { new?: string })?.new === 'prepis').map((e) => e.changed_at),
  );
  const out: Event[] = [];
  for (const e of ev) {
    const d = e.diff;
    const change = (k: string) => d[k] as { old: unknown; new: unknown } | undefined;
    if (e.table_name === 'oom' && e.action === 'insert') {
      out.push({ key: e.id, icon: '+', title: <><b>OOM založené</b> · {label(OOM_STATUS_TEXT, d.status as string)}</>, at: e.changed_at, meta: meta(e) });
    } else if (e.table_name === 'oom' && e.action === 'update') {
      const keys = Object.keys(d).filter((k) => !LINK_FIELDS.has(k));
      if (keys.length === 0) continue;
      const parts = keys.slice(0, 3).map((k) => {
        const c = change(k);
        const name = k.startsWith('custom.') ? `vlastné pole ${k.slice(7)}` : (FIELD_LABEL[k] ?? k);
        return `${name} ${val(c?.old, k)} → ${val(c?.new, k)}`;
      });
      out.push({
        key: e.id,
        icon: '✎',
        title: <><b>Zmena údajov</b> · {parts.join(' · ')}{keys.length > 3 ? ` a ${keys.length - 3} ďalšie` : ''}</>,
        at: e.changed_at,
        meta: meta(e),
      });
    } else if (e.table_name === 'oom_customer' && e.action === 'update') {
      const reason = change('end_reason')?.new as string | undefined;
      const status = change('status');
      if (reason === 'prepis') {
        const next = ev.find((x) => x.table_name === 'oom_customer' && x.action === 'insert' && x.changed_at === e.changed_at);
        const from = o.links.find((l) => l.id === e.record_id);
        out.push({
          key: e.id,
          icon: '⇄',
          title: <><b>Prepis</b> · {from?.customer_name ?? 'pôvodný zákazník'} → {next ? customer(next.diff) : 'nový zákazník'}</>,
          at: e.changed_at,
          meta: [meta(e), next ? `od ${val(next.diff.valid_from)}` : null].filter(Boolean).join(' · '),
        });
      } else if (reason) {
        out.push({
          key: e.id,
          icon: '⏹',
          title: <><b>{reason === 'odchod' ? 'Odchod k inému dodávateľovi' : 'Zrušenie'}</b> · k {val(change('valid_to')?.new)}</>,
          at: e.changed_at,
          meta: meta(e),
        });
      } else if (status) {
        out.push({
          key: e.id,
          icon: '✓',
          title: <><b>Stav</b> {label(OOM_STATUS_TEXT, status.old as string)} → {label(OOM_STATUS_TEXT, status.new as string)}</>,
          at: e.changed_at,
          meta: meta(e),
        });
      }
    } else if (e.table_name === 'oom_customer' && e.action === 'insert') {
      if (e.changed_at === oomInsertAt || prepisAt.has(e.changed_at)) continue; // založenie a prepis sú už vyššie
      out.push({
        key: e.id,
        icon: '↺',
        title: <><b>Návrat</b> · {customer(d)} od {val(d.valid_from)}</>,
        at: e.changed_at,
        meta: meta(e),
      });
    } else if (e.table_name === 'oom_device') {
      const t = (d.device_type as string) ?? ((d.device_type as unknown as { new?: string })?.new);
      const what = e.action === 'insert' ? 'pridané' : e.action === 'delete' ? 'odobraté' : 'upravené';
      out.push({ key: e.id, icon: '⚙', title: <><b>Zariadenie {what}</b>{t ? ` · ${label(DEVICE_TYPE, t)}` : ''}</>, at: e.changed_at, meta: meta(e) });
    } else if (e.table_name === 'oom_planned_change') {
      const kind = (d.kind as string) ?? undefined;
      const k = kind ?? o.plans.find((p) => p.id === e.record_id)?.kind ?? '';
      const what = PLAN_KIND[k] ?? 'zmena';
      if (e.action === 'insert') {
        const who = typeof d.person_id === 'string' ? names[d.person_id] : typeof d.company_id === 'string' ? names[d.company_id] : null;
        out.push({
          key: e.id,
          icon: '🗓',
          title: <><b>Plánovaný {what}</b>{who ? ` na ${who}` : ''} · {PLAN_DATE_LABEL[k]?.toLowerCase()} {val(d.effective_date)}</>,
          at: e.changed_at,
          meta: meta(e),
        });
      } else {
        const status = change('status')?.new as string | undefined;
        const moved = change('effective_date');
        if (moved) out.push({ key: e.id, icon: '🗓', title: <><b>Zmena dátumu plánu</b> ({what}) · {val(moved.old)} → {val(moved.new)}</>, at: e.changed_at, meta: meta(e) });
        else if (status === 'zrusena') out.push({ key: e.id, icon: '🗓', title: <><b>Plán zrušený</b> ({what})</>, at: e.changed_at, meta: meta(e) });
        else if (status === 'zlyhala') out.push({ key: e.id, icon: '⚠', title: <><b>Plán zlyhal</b> ({what}) · {String(change('error')?.new ?? '')}</>, at: e.changed_at, meta: meta(e) });
        // vykonanie: udalosť väzby (prepis, odchod, zrušenie) je už na osi
      }
    } else if (e.table_name === 'oom_contact') {
      const what = e.action === 'insert' ? 'pridaná' : e.action === 'delete' ? 'odobratá' : 'upravená';
      const who = typeof d.contact_id === 'string' ? names[d.contact_id] : undefined;
      out.push({ key: e.id, icon: '👤', title: <><b>Kontaktná osoba {what}</b>{who ? ` · ${who}` : ''}</>, at: e.changed_at, meta: meta(e) });
    }
  }
  return out;
}

const OOM_STATUS_TEXT: Record<string, string> = Object.fromEntries(Object.entries(OOM_STATUS).map(([k, v]) => [k, v.label]));

function TimelineCard(props: { o: OomCard }) {
  const events = describe(props.o);
  return (
    <Card title="Časová os">
      {events.length === 0 ? (
        <Empty>Zatiaľ bez udalostí.</Empty>
      ) : (
        <ol className="timeline">
          {events.map((e) => (
            <li key={e.key} className="timeline-item">
              <div className="timeline-head">
                <span aria-hidden="true">{e.icon}</span>
                <span style={{ flex: 1, minWidth: 0 }}>{e.title}</span>
                <span className="sub">{date(e.at)}</span>
              </div>
              <div className="sub">{e.meta}</div>
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

// --- Záložky ---

function ContractsTab(props: { o: OomCard }) {
  const o = props.o;
  return (
    <div className="columns">
      <div className="col-wide">
        <Card title={`Zmluvné ceny (${o.prices.length})`} flush>
          {o.prices.length === 0 ? (
            <div className="card-body">
              <Empty>Zatiaľ žiadne zmluvné ceny (modul Zmluvy).</Empty>
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
      </div>
      <div className="col-right">
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
    </div>
  );
}
