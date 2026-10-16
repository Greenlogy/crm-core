// Karta obchodu (dizajn 33; zadanie časť 4, F1–F2): štádiá, údaje obchodu, OOM s plánovanými objemami (aj nové OOM
// v stave Pripravované), kontaktné osoby s rolami, ďalší krok, časová os s poznámkami, výstrahy Finstatu, ponuky
// s verziami a pridaná hodnota / odhad provízie z ponuky (F2). E-maily a podklady pre zmluvu pribudnú vo fázach F4–F5.
// Pravidlá štádií a vlastníka stráži databáza.

import { EmailList } from '../components/email';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { LostPanel, ReopenPanel, RiskPills } from '../components/deal-forms';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { changed, initialValues, OomFields, type OomFormValues, type OomOptions } from '../components/oom-forms';
import { Card, Empty, ErrorState, Kpi, PageSkeleton, Pill, Rows, StatusPill } from '../components/ui';
import { send, useApi, type Owner } from '../lib/api';
import { type DealCard, type DealContact, type DealOom, type DealOptions, isSupply, OUTCOME_TONE, type StageRef, STEP_STATE, type TimelineItem, VOLTAGE } from '../lib/deals';
import { date, eur, mwh, num, text } from '../lib/format';
import { OOM_STATUS, OOM_TYPE } from '../lib/labels';
import { APPROVAL_KIND, dateTime, type DealOffers, OFFER_STATE, SEND_CHANNEL } from '../lib/offers';

const time = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', minute: '2-digit' }).format(new Date(v));
const numText = (v: string | null) => (v === null ? '' : String(Number(v)).replace('.', ','));

export function DealPage() {
  const { id = '' } = useParams();
  const { data: d, error, reload } = useApi<DealCard>(`/api/deals/${id}`);
  const { data: opts } = useApi<DealOptions>('/api/deals/options');
  const timeline = useApi<{ items: TimelineItem[] }>(`/api/deals/${id}/timeline`);
  const offers = useApi<DealOffers>(`/api/deals/${id}/offers`);
  const navigate = useNavigate();
  const [panel, setPanel] = useState<null | 'edit' | 'lost' | 'reopen' | 'step' | 'oom-add' | 'oom-new' | 'contact-add'>(null);
  const [editOom, setEditOom] = useState<DealOom | null>(null);
  const [tlFilter, setTlFilter] = useState<'vsetko' | 'poznamka' | 'udalost'>('vsetko');
  const save = useSave();
  const refresh = () => {
    reload();
    timeline.reload();
    offers.reload();
  };

  if (error) return <ErrorState error={error} />;
  if (!d) return <PageSkeleton />;
  const supply = isSupply(d.pipeline_kind);
  const closed = d.closed_at !== null;
  const editable = d.can_edit && !closed;
  const lostStage = d.stages.find((s) => s.code === 'prehrane');
  const mainTotal = offers.data?.main?.summary.find((x) => x.year === null) ?? null;
  const mainYears = offers.data?.main?.summary.filter((x) => x.year !== null).map((x) => x.year).join(' + ');
  const latest = offers.data?.items[0] ?? null;
  const newOffer = () =>
    save.run(async () => {
      const r = latest
        ? await send<{ id: string }>('POST', `/api/offers/${latest.id}/new-version`)
        : await send<{ id: string }>('POST', `/api/deals/${d.id}/offers`);
      navigate(`/ponuky/${r.id}`);
    });
  const primary = d.contacts.find((c) => c.is_primary) ?? null;

  const totals = d.ooms.reduce(
    (t, o) => {
      const v = Number(o.planned_vt_mwh ?? 0) + Number(o.planned_nt_mwh ?? 0);
      const key = o.voltage_level === 'vn' || o.voltage_level === 'vvn' ? 'vn' : 'nn';
      return { ...t, all: t.all + v, [key]: t[key as 'nn' | 'vn'] + v, feed: t.feed + Number(o.planned_feed_in_mwh ?? 0), kw: t.kw + Number(o.source_power_kw ?? 0) };
    },
    { all: 0, nn: 0, vn: 0, feed: 0, kw: 0 },
  );

  const moveTo = (s: StageRef) => {
    if (s.code === 'prehrane') return setPanel('lost');
    void save.run(async () => {
      await send('POST', `/api/deals/${d.id}/stage`, { stage_id: s.id });
      refresh();
    });
  };
  const stageTitle = (s: StageRef): string | undefined =>
    s.code === 'akceptacia' ? 'Nastaví sa sám pri akceptácii ponuky (klik zákazníka alebo ručný záznam – fáza F3).'
      : s.code === 'vyhrane' ? 'Nastaví sa sám pri spárovaní zmluvy z importu (fáza F5).'
        : undefined;

  return (
    <>
      <header className="page-head">
        <div>
          <div className="caption">
            <Link to="/obchody">Obchody</Link> · {d.pipeline_name}
          </div>
          <h1 className="t-page-title">{d.name}</h1>
          <div className="page-sub" style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center' }}>
            <Pill tone={OUTCOME_TONE[d.stage_outcome]}>{d.stage_name}</Pill>
            <Link to={d.company_id ? `/firmy/${d.company_id}` : `/osoby/${d.person_id}`}>{text(d.customer_name)}</Link>
            <span>· {text(d.owner_name)}</span>
            {d.source_code === 'obnova' && <Pill tone="info">Obnova</Pill>}
            <RiskPills risk={d.risk} />
          </div>
        </div>
        <div className="head-actions">
          {editable && (
            <button type="button" className="btn" onClick={() => setPanel('step')}>
              Ďalší krok
            </button>
          )}
          {editable && (
            <button type="button" className="btn" onClick={() => setPanel('edit')}>
              Upraviť
            </button>
          )}
          {closed && d.can_reopen && (
            <button type="button" className="btn" onClick={() => setPanel('reopen')}>
              Znova otvoriť
            </button>
          )}
        </div>
      </header>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {d.risk?.needs_approval && (
        <Notice tone="error">Zákazník je v konkurze, reštrukturalizácii alebo má rating E/X – ponuku bude možné odoslať až po schválení.</Notice>
      )}

      <nav className="stepper" aria-label="Štádiá obchodu">
        {d.stages.map((s, i) => {
          const current = s.id === d.stage_id;
          const currentIdx = d.stages.findIndex((x) => x.id === d.stage_id);
          const done = s.outcome === 'otvoreny' && (i < currentIdx || d.stage_outcome === 'vyhrany');
          const locked = !editable || current || s.code === 'akceptacia' || s.code === 'vyhrane' || (s.code === 'prehrane' && !lostStage);
          return (
            <button
              key={s.id}
              type="button"
              className={`step${current ? ' step-current' : ''}${done ? ' step-done' : ''} step-${s.outcome}`}
              disabled={locked || save.busy}
              title={stageTitle(s)}
              aria-current={current ? 'step' : undefined}
              onClick={() => moveTo(s)}
            >
              {s.name}
              {s.code === 'prehrane' && !current ? '…' : ''}
            </button>
          );
        })}
      </nav>
      {closed && (
        <p className="caption" style={{ marginTop: -8 }}>
          Uzavretý {date(d.closed_at)}
          {d.lost_reason_label ? ` · dôvod: ${d.lost_reason_label}` : ''}
          {d.lost_note ? ` · ${d.lost_note}` : ''}
        </p>
      )}

      <div className="kpis" style={{ margin: '12px 0 16px' }}>
        {supply ? (
          <Kpi
            label="Objem MWh / rok"
            value={mwh(totals.all)}
            sub={`${num(d.ooms.length, 0)} OOM${totals.vn > 0 ? ` · NN ${num(totals.nn, 1)} · VN ${num(totals.vn, 1)}` : ''}`}
          />
        ) : (
          <Kpi label="Výroba MWh / rok" value={mwh(totals.feed)} sub={`${num(d.ooms.length, 0)} OOM · ${num(totals.kw, 1)} kW`} />
        )}
        {mainTotal ? (
          <>
            <Kpi
              label={`Pridaná hodnota – variant ${offers.data?.main ? String.fromCharCode(64 + offers.data.main.sort_order) : ''}${offers.data?.main?.accepted ? ' (akceptovaný)' : ''}`}
              value={`${eur(mainTotal.added_value_eur)} €`}
              sub={`${offers.data?.main?.display_number ?? ''}${mainYears ? ` · ${mainYears}` : ''}`}
            />
            <Kpi
              label={`Odhad provízie (${num(mainTotal.commission_pct, 2)} %)`}
              value={`${eur(mainTotal.commission_eur)} €`}
              sub="z pridanej hodnoty variantu"
            />
          </>
        ) : (
          <Kpi label="Pridaná hodnota" value={d.value_eur === null ? '' : `≈ ${eur(d.value_eur)} €`} sub="odhad obchodníka – kým nie je ponuka" />
        )}
        <Kpi
          label="Ďalší krok"
          value={d.next_step ? date(d.next_step_on) : '–'}
          sub={d.next_step ?? (d.step_state ? STEP_STATE[d.step_state].label : undefined)}
        />
        <Kpi label="Očakávané uzavretie" value={date(d.expected_close)} sub={d.supply_start ? `dodávka od ${date(d.supply_start)}` : undefined} />
      </div>

      <div className="columns">
        <div className="col-wide">
          <Card
            flush
            title="Odberné miesta"
            aside={
              editable ? (
                <span style={{ display: 'flex', gap: 8 }}>
                  <button type="button" className="btn" onClick={() => setPanel('oom-add')}>
                    Pridať OOM zákazníka
                  </button>
                  <button type="button" className="btn" onClick={() => setPanel('oom-new')}>
                    Nové OOM
                  </button>
                </span>
              ) : undefined
            }
          >
            <OomTable deal={d} editable={editable} onEdit={setEditOom} onChanged={refresh} />
            <div className="caption" style={{ padding: '8px 16px' }}>
              NN a VN sú v jednom obchode a jednej ponuke; na dve zmluvy sa rozdelia až v podkladoch pre zmluvu. Objemy na obchode sú odhad pre
              ponuku – plánovanú spotrebu z XM Trade neprepisujú.
            </div>
          </Card>

          <Card title="E-maily a odpovede">
            <EmailList query={`deal_id=${d.id}`} source={{ dealId: d.id }} />
          </Card>

          <Card
            title="Časová os"
            aside={
              <div className="chips" role="group" aria-label="Filter časovej osi">
                {(['vsetko', 'poznamka', 'udalost'] as const).map((f) => (
                  <button key={f} type="button" className="chip" aria-pressed={tlFilter === f} onClick={() => setTlFilter(f)}>
                    {f === 'vsetko' ? 'Všetko' : f === 'poznamka' ? 'Poznámky' : 'Udalosti'}
                  </button>
                ))}
              </div>
            }
          >
            {editable || d.can_edit ? <NoteBox dealId={d.id} onSaved={timeline.reload} /> : null}
            {!timeline.data ? null : timeline.data.items.length === 0 ? (
              <Empty>Zatiaľ bez udalostí.</Empty>
            ) : (
              <ul className="timeline">
                {timeline.data.items.filter((t) => tlFilter === 'vsetko' || t.type === tlFilter).map((t) => (
                  <li key={t.id} className="timeline-item">
                    <div className="timeline-head">
                      <span className="caption">
                        {date(t.occurred_at)} {time(t.occurred_at)}
                      </span>
                      <span className="caption">· {t.user_name ?? 'Systém'}</span>
                    </div>
                    <div className="timeline-subject">{eventText(t)}</div>
                    {(t.body || t.reason) && <div className="timeline-body">{t.body ?? t.reason}</div>}
                  </li>
                ))}
              </ul>
            )}
          </Card>
        </div>

        <div className="col-right">
          <Card
            flush
            title="Ponuky"
            aside={
              editable && (!latest || latest.state === 'odoslana' || latest.state === 'otvorena' || latest.state === 'zamietnuta' || latest.state === 'vyprsana') ? (
                <button type="button" className="btn" disabled={save.busy} onClick={newOffer}>
                  {latest ? '+ Nová verzia' : '+ Nová ponuka'}
                </button>
              ) : undefined
            }
          >
            {!offers.data ? null : offers.data.items.length === 0 ? (
              <Empty>{d.ooms.length === 0 ? 'Pred ponukou pridajte do obchodu aspoň jedno OOM.' : 'Zatiaľ bez ponuky.'}</Empty>
            ) : (
              <table className="tbl">
                <thead>
                  <tr>
                    <th>Číslo</th>
                    <th>Stav</th>
                    <th>Platí do</th>
                  </tr>
                </thead>
                <tbody>
                  {offers.data.items.map((x) => (
                    <tr key={x.id} className="clickable" onClick={() => navigate(`/ponuky/${x.id}`)}>
                      <td>
                        <Link className="mono" to={`/ponuky/${x.id}`} onClick={(e) => e.stopPropagation()}>
                          {x.display_number}
                        </Link>
                        <div className="sub">
                          {x.variants} {x.variants === 1 ? 'variant' : x.variants < 5 ? 'varianty' : 'variantov'} · {x.language.toUpperCase()}
                        </div>
                      </td>
                      <td>
                        <StatusPill map={OFFER_STATE} value={x.state} />
                      </td>
                      <td className={x.state === 'nahradena' || x.state === 'vyprsana' ? 'muted' : undefined}>{x.valid_until ? dateTime(x.valid_until) : '–'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </Card>
          <Card title="Údaje obchodu">
            <Rows
              rows={[
                ['Pipeline', d.pipeline_name],
                ['Vlastník', text(d.owner_name)],
                ['Zdroj', text(d.source_label)],
                ['Očakávané uzavretie', date(d.expected_close)],
                ['Začiatok dodávky', date(d.supply_start)],
                ['Odhad PH', d.estimated_value_eur === null ? '–' : `${eur(d.estimated_value_eur)} €`],
                ['Predošlá zmluva', d.previous_contract_id ? <Link to={`/zmluvy/${d.previous_contract_id}`}>{d.previous_contract_number}</Link> : '–'],
                ['Kontaktná osoba', primary ? `${text(primary.name)}${primary.position ? ` · ${primary.position}` : ''}` : '–'],
                ['Finstat', d.company_id ? (d.risk && d.risk.warnings.length ? <RiskPills risk={d.risk} /> : d.risk?.finstat_updated_at ? 'bez výstrah' : 'nenačítané') : '–'],
                ['Vlastník zákazníka', text(d.customer_owner_name)],
                ['Založený', date(d.created_at)],
              ]}
            />
            {d.note && <p style={{ whiteSpace: 'pre-wrap', marginTop: 12 }}>{d.note}</p>}
          </Card>
          <ContactsCard deal={d} editable={editable} onAdd={() => setPanel('contact-add')} onChanged={refresh} />
        </div>
      </div>

      {panel === 'edit' && <EditPanel deal={d} options={opts} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />}
      {panel === 'step' && <StepPanel deal={d} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />}
      {panel === 'lost' && lostStage && (
        <LostPanel dealId={d.id} stageId={lostStage.id} options={opts} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />
      )}
      {panel === 'reopen' && <ReopenPanel dealId={d.id} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />}
      {panel === 'oom-add' && <OomAddPanel deal={d} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />}
      {panel === 'oom-new' && <OomNewPanel deal={d} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />}
      {panel === 'contact-add' && (
        <ContactAddPanel deal={d} options={opts} onClose={() => setPanel(null)} onSaved={() => { setPanel(null); refresh(); }} />
      )}
      {editOom && <OomVolumePanel deal={d} oom={editOom} onClose={() => setEditOom(null)} onSaved={() => { setEditOom(null); refresh(); }} />}
    </>
  );
}

const offerNo = (t: TimelineItem) =>
  t.detail?.number ? `${String(t.detail.number)}${Number(t.detail.version) > 1 ? `/${String(t.detail.version)}` : ''}` : '';

function eventText(t: TimelineItem): string {
  if (t.type === 'poznamka') return 'Poznámka';
  switch (t.kind) {
    case 'zalozenie': return `Obchod založený${t.to_owner ? ` · vlastník ${t.to_owner}` : ''}`;
    case 'stadium': return `Štádium: ${t.from_stage ?? '–'} → ${t.to_stage ?? '–'}${t.lost_reason_label ? ` (${t.lost_reason_label})` : ''}`;
    case 'znovuotvorenie': return `Znova otvorený: ${t.from_stage ?? '–'} → ${t.to_stage ?? '–'}`;
    case 'vlastnik': return `Vlastník obchodu: ${t.from_owner ?? '–'} → ${t.to_owner ?? '–'}`;
    case 'oom_pridane': return `OOM pridané ${t.oom_eic ?? ''}`;
    case 'oom_odobrane': return `OOM odobraté ${t.oom_eic ?? ''}`;
    case 'oom_zrusene': return `OOM ${t.oom_eic ?? ''} zrušené – obchod prehraný`;
    case 'oom_nezrusene': return `OOM ${t.oom_eic ?? ''} ostalo (nedalo sa zrušiť)`;
    case 'kontakt_pridany': return `Kontakt pridaný: ${t.contact_name ?? '–'}`;
    case 'kontakt_odobrany': return `Kontakt odobratý: ${t.contact_name ?? '–'}`;
    case 'zakaznik_vlastnik': return `Zákazník bez vlastníka pridelený: ${t.to_owner ?? '–'}`;
    case 'ponuka_nova': return `Nová ponuka ${offerNo(t)}`;
    case 'ponuka_verzia': return `Nová verzia ponuky ${offerNo(t)}${t.detail?.exceptions_carried ? ` · prevzaté výnimky: ${String(t.detail.exceptions_carried)}` : ''}`;
    case 'ponuka_prepocitana': return `Ponuka ${offerNo(t)} prepočítaná na ceny k ${date(String(t.detail?.priced_on ?? ''))}`;
    case 'ponuka_odoslana': return `Ponuka ${offerNo(t)} odoslaná · ${SEND_CHANNEL[String(t.detail?.channel ?? '')] ?? ''} · platí do ${dateTime(String(t.detail?.valid_until ?? ''))}`;
    case 'ponuka_zamietnuta': return `Zákazník ponuku ${offerNo(t)} odmietol`;
    case 'ponuka_platnost': return `Platnosť ponuky ${offerNo(t)} ${t.detail?.extended ? 'predĺžená' : 'skrátená'} do ${dateTime(String(t.detail?.valid_until ?? ''))}`;
    case 'ponuka_akceptovana': return `Zákazník akceptoval ponuku ${offerNo(t)}`;
    case 'ponuka_zablokovana': return `Verzia ${offerNo(t)} zablokovaná – zákazník akceptoval inú verziu`;
    case 'ponuka_otvorena': return `Zákazník otvoril ponuku ${offerNo(t)}`;
    case 'ponuka_odkaz': return `Nový odkaz na stránku ponuky ${offerNo(t)} (starý neplatí)`;
    case 'akceptacia_zrusena': return `Akceptácia ponuky ${offerNo(t)} zrušená${t.detail?.reason ? ` – ${String(t.detail.reason)}` : ''}`;
    case 'ponuka_odblokovana': return `Verzia ${offerNo(t)} odblokovaná`;
    case 'potvrdenie_neodoslane': return `Potvrdenie akceptácie ponuky ${offerNo(t)} sa zákazníkovi neposlalo (vypnuté pri zázname)`;
    case 'schvalenie_ziadost': return `Žiadosť o schválenie (${APPROVAL_KIND[String(t.detail?.kind ?? '')] ?? ''}) – ponuka ${offerNo(t)}`;
    case 'schvalenie_rozhodnutie': return `${APPROVAL_KIND[String(t.detail?.kind ?? '')] ?? 'Žiadosť'} ${t.detail?.approved ? 'schválená' : 'zamietnutá'} – ponuka ${offerNo(t)}`;
    default: return t.kind ?? '';
  }
}

function OomTable(props: { deal: DealCard; editable: boolean; onEdit: (o: DealOom) => void; onChanged: () => void }) {
  const { deal } = props;
  const supply = isSupply(deal.pipeline_kind);
  const save = useSave();
  const remove = (o: DealOom) =>
    save.run(async () => {
      await send('DELETE', `/api/deals/${deal.id}/oom/${o.id}`);
      props.onChanged();
    });
  if (deal.ooms.length === 0) return <Empty>Obchod zatiaľ nemá OOM. Pre štádium Cenová ponuka treba aspoň jedno s plánovanou spotrebou.</Empty>;
  return (
    <div className="table-wrap">
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <table className="tbl">
        <thead>
          <tr>
            <th>EIC</th>
            <th>Adresa</th>
            <th>Napätie</th>
            <th>Sadzba</th>
            {supply ? (
              <>
                <th className="num">VT [MWh]</th>
                <th className="num">NT [MWh]</th>
              </>
            ) : (
              <>
                <th className="num">Výroba [MWh]</th>
                <th className="num">Výkon [kW]</th>
              </>
            )}
            <th>Stav v CRM</th>
            {props.editable && <th />}
          </tr>
        </thead>
        <tbody>
          {deal.ooms.map((o) => (
            <tr key={o.id}>
              <td>
                {o.eic ? <Link to={`/oom/${o.id}`}>{o.eic}</Link> : <span className="muted">OOM nevidíte</span>}
                <div className="sub">
                  {o.type ? OOM_TYPE[o.type] ?? o.type : ''}
                  {o.created_here ? ' · nové z obchodu' : ''}
                </div>
              </td>
              <td>{text(o.address)}</td>
              <td>{o.voltage_level ? VOLTAGE[o.voltage_level] : '–'}</td>
              <td>{text(o.pds_tariff)}</td>
              {supply ? (
                <>
                  <td className="num">{o.planned_vt_mwh === null ? '–' : num(o.planned_vt_mwh, 3)}</td>
                  <td className="num">{o.planned_nt_mwh === null ? '–' : num(o.planned_nt_mwh, 3)}</td>
                </>
              ) : (
                <>
                  <td className="num">{o.planned_feed_in_mwh === null ? '–' : num(o.planned_feed_in_mwh, 3)}</td>
                  <td className="num">{o.source_power_kw === null ? '–' : num(o.source_power_kw, 1)}</td>
                </>
              )}
              <td>{o.status ? <StatusPill map={OOM_STATUS} value={o.status} /> : '–'}</td>
              {props.editable && (
                <td className="num" style={{ whiteSpace: 'nowrap' }}>
                  <button type="button" className="btn btn-ghost" onClick={() => props.onEdit(o)}>
                    Objemy
                  </button>
                  <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={() => remove(o)}>
                    Odobrať
                  </button>
                </td>
              )}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function ContactsCard(props: { deal: DealCard; editable: boolean; onAdd: () => void; onChanged: () => void }) {
  const { deal } = props;
  const { data: opts } = useApi<DealOptions>('/api/deals/options');
  const roleLabel = (c: string) => opts?.lists.rola_kontaktu?.find((r) => r.code === c)?.label ?? c;
  const save = useSave();
  const act = (c: DealContact, method: 'PATCH' | 'DELETE', body?: unknown) =>
    save.run(async () => {
      await send(method, `/api/deals/${deal.id}/contacts/${c.id}`, body);
      props.onChanged();
    });
  return (
    <Card
      title="Kontaktné osoby"
      aside={
        props.editable ? (
          <button type="button" className="btn" onClick={props.onAdd}>
            Pridať
          </button>
        ) : undefined
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {deal.contacts.length === 0 ? (
        <Empty>Bez kontaktných osôb. Primárny kontakt bude predvolenou kontaktnou osobou ponuky.</Empty>
      ) : (
        deal.contacts.map((c) => (
          <div key={c.id} className="contact-row" style={{ padding: '8px 0', borderTop: '1px solid var(--surface-muted)' }}>
            <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap' }}>
              <Link to={`/osoby/${c.id}`}>{text(c.name)}</Link>
              {c.is_primary && <Pill tone="info">primárny</Pill>}
              {c.roles.map((r) => (
                <Pill key={r}>{roleLabel(r)}</Pill>
              ))}
            </div>
            <div className="caption">{[c.position, c.email, c.mobile ?? c.phone].filter(Boolean).join(' · ') || '–'}</div>
            {props.editable && (
              <div style={{ display: 'flex', gap: 6, marginTop: 4 }}>
                {!c.is_primary && (
                  <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={() => act(c, 'PATCH', { is_primary: true })}>
                    Nastaviť ako primárny
                  </button>
                )}
                <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={() => act(c, 'DELETE')}>
                  Odobrať
                </button>
              </div>
            )}
          </div>
        ))
      )}
    </Card>
  );
}

function NoteBox(props: { dealId: string; onSaved: () => void }) {
  const [textValue, setText] = useState('');
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.dealId}/notes`, { text: textValue });
      setText('');
      props.onSaved();
    });
  return (
    <div className="note-new" style={{ marginBottom: 12 }}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <textarea className="inp" rows={2} maxLength={5000} placeholder="Nová poznámka…" value={textValue} onChange={(e) => setText(e.target.value)} />
      <div className="row-actions" style={{ display: 'flex', justifyContent: 'flex-end' }}>
        <button type="button" className="btn" disabled={save.busy || !textValue.trim()} onClick={submit}>
          Pridať poznámku
        </button>
      </div>
    </div>
  );
}

function EditPanel(props: { deal: DealCard; options: DealOptions | undefined; onClose: () => void; onSaved: () => void }) {
  const { deal } = props;
  const { data: owners } = useApi<Owner[]>('/api/deals/owners');
  const [v, setV] = useState({
    name: deal.name,
    source_code: deal.source_code,
    owner_id: deal.owner_id,
    expected_close: deal.expected_close ?? '',
    supply_start: deal.supply_start ?? '',
    estimated_value_eur: deal.estimated_value_eur === null ? '' : numText(deal.estimated_value_eur),
    note: deal.note ?? '',
  });
  const set = (k: keyof typeof v, x: string) => setV((s) => ({ ...s, [k]: x }));
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      const body: Record<string, unknown> = {
        name: v.name,
        expected_close: v.expected_close || null,
        supply_start: v.supply_start || null,
        estimated_value_eur: v.estimated_value_eur || null,
        note: v.note,
      };
      if (v.source_code !== deal.source_code) body.source_code = v.source_code;
      if (v.owner_id !== deal.owner_id) body.owner_id = v.owner_id;
      await send('PATCH', `/api/deals/${deal.id}`, body);
      props.onSaved();
    });
  const sources = (props.options?.lists.zdroj_obchodu ?? []).filter((s) => s.code !== 'obnova' || deal.source_code === 'obnova');
  return (
    <SidePanel
      title="Upraviť obchod"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !v.name.trim()} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Názov obchodu">
        <TextInput value={v.name} onChange={(x) => set('name', x)} maxLength={200} />
      </Field>
      <Field label="Zdroj">
        <Select value={v.source_code} onChange={(x) => set('source_code', x)} options={sources.map((s) => ({ value: s.code, label: s.label }))} disabled={deal.source_code === 'obnova'} />
      </Field>
      {deal.can_change_owner && (
        <Field label="Vlastník (obchodník)" hint="Mení vedenie, obchodný riaditeľ a schvaľovatelia.">
          <Select value={v.owner_id} onChange={(x) => set('owner_id', x)} options={(owners ?? []).map((o) => ({ value: o.id, label: o.name }))} />
        </Field>
      )}
      <div className="form-grid">
        <Field label="Očakávané uzavretie">
          <TextInput type="date" value={v.expected_close} onChange={(x) => set('expected_close', x)} />
        </Field>
        <Field label="Začiatok dodávky">
          <TextInput type="date" value={v.supply_start} onChange={(x) => set('supply_start', x)} />
        </Field>
      </div>
      <Field label="Odhad pridanej hodnoty [€]">
        <TextInput value={v.estimated_value_eur} onChange={(x) => set('estimated_value_eur', x)} maxLength={14} />
      </Field>
      <Field label="Poznámka">
        <textarea className="inp" rows={4} maxLength={5000} value={v.note} onChange={(e) => set('note', e.target.value)} />
      </Field>
    </SidePanel>
  );
}

function StepPanel(props: { deal: DealCard; onClose: () => void; onSaved: () => void }) {
  const [step, setStep] = useState(props.deal.next_step ?? '');
  const [on, setOn] = useState(props.deal.next_step_on ?? '');
  const save = useSave();
  const submit = (clear = false) =>
    save.run(async () => {
      await send('PATCH', `/api/deals/${props.deal.id}`, clear ? { next_step: null, next_step_on: null } : { next_step: step || null, next_step_on: on || null });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Ďalší krok"
      onClose={props.onClose}
      footer={
        <>
          {props.deal.next_step && (
            <button type="button" className="btn" disabled={save.busy} onClick={() => submit(true)}>
              Hotovo (vymazať)
            </button>
          )}
          <span className="grow" />
          <button type="button" className="btn primary" disabled={save.busy || !step.trim() || !on} onClick={() => submit()}>
            Uložiť
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Čo treba urobiť">
        <TextInput value={step} onChange={setStep} maxLength={300} autoFocus />
      </Field>
      <Field label="Dátum" hint="V deň kroku príde upozornenie do zvončeka. Obchod bez kroku alebo po termíne sa v zozname zvýrazní.">
        <TextInput type="date" value={on} onChange={setOn} />
      </Field>
    </SidePanel>
  );
}

function OomVolumePanel(props: { deal: DealCard; oom: DealOom; onClose: () => void; onSaved: () => void }) {
  const supply = isSupply(props.deal.pipeline_kind);
  const [v, setV] = useState({
    planned_vt_mwh: numText(props.oom.planned_vt_mwh),
    planned_nt_mwh: numText(props.oom.planned_nt_mwh),
    planned_feed_in_mwh: numText(props.oom.planned_feed_in_mwh),
    source_power_kw: numText(props.oom.source_power_kw),
  });
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      const body = Object.fromEntries(Object.entries(v).map(([k, x]) => [k, x === '' ? null : x]));
      await send('PATCH', `/api/deals/${props.deal.id}/oom/${props.oom.id}`, body);
      props.onSaved();
    });
  const f = (k: keyof typeof v, label: string) => (
    <Field label={label}>
      <TextInput value={v[k]} onChange={(x) => setV((s) => ({ ...s, [k]: x }))} maxLength={14} />
    </Field>
  );
  return (
    <SidePanel
      title={`Objemy – ${props.oom.eic ?? 'OOM'}`}
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p className="caption">Odhad pre ponuku na tomto obchode (za rok). Plánovanú spotrebu OOM z XM Trade nemení.</p>
      {supply ? (
        <>
          {f('planned_vt_mwh', 'Plánovaná spotreba VT / 1T [MWh]')}
          {f('planned_nt_mwh', 'Plánovaná spotreba NT [MWh]')}
        </>
      ) : (
        <>
          {f('planned_feed_in_mwh', 'Plánovaná výroba / výkup [MWh]')}
          {f('source_power_kw', 'Výkon zdroja [kW]')}
        </>
      )}
    </SidePanel>
  );
}

type Candidate = { id: string; eic: string; name: string | null; type: string; status: string; voltage_level: string | null; address_city: string | null };

function OomAddPanel(props: { deal: DealCard; onClose: () => void; onSaved: () => void }) {
  const { data } = useApi<{ items: Candidate[] }>(`/api/deals/${props.deal.id}/oom-candidates`);
  const [selected, setSelected] = useState<string[]>([]);
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      for (const oom of selected) await send('POST', `/api/deals/${props.deal.id}/oom`, { oom_id: oom });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Pridať OOM zákazníka"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || selected.length === 0} onClick={submit}>
            Pridať ({selected.length})
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p className="caption">Pripravované a Aktívne OOM zákazníka. Plánovaná spotreba sa predvyplní z OOM; upraviť ju môžete tlačidlom Objemy.</p>
      {!data ? null : data.items.length === 0 ? (
        <Empty>Zákazník nemá ďalšie OOM. Nové založte tlačidlom Nové OOM.</Empty>
      ) : (
        data.items.map((o) => (
          <Check key={o.id} checked={selected.includes(o.id)} onChange={(c) => setSelected((s) => (c ? [...s, o.id] : s.filter((x) => x !== o.id)))}>
            {o.eic} · {OOM_TYPE[o.type] ?? o.type}
            {o.voltage_level ? ` · ${VOLTAGE[o.voltage_level]}` : ''}
            {o.address_city ? ` · ${o.address_city}` : ''}
          </Check>
        ))
      )}
    </SidePanel>
  );
}

function OomNewPanel(props: { deal: DealCard; onClose: () => void; onSaved: () => void }) {
  const options = useApi<OomOptions>(`/api/oom-options?org=${props.deal.org_id}`).data;
  const [v, setV] = useState<OomFormValues>(() => ({
    ...initialValues(),
    type: isSupply(props.deal.pipeline_kind) ? 'spotreba' : 'vyroba',
  }));
  const set = (k: string, val: string | boolean) => setV((x) => ({ ...x, [k]: val }));
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.deal.id}/oom/new`, { ...changed({}, v), type: v.type });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Nové OOM pre obchod"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !String(v.eic).trim()} onClick={submit}>
            Založiť a pridať
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p className="caption">
        OOM vznikne pre zákazníka {props.deal.customer_name} v stave Pripravované, zatiaľ bez zmluvy. Stačí EIC, sadzba, napäťová úroveň a
        plánovaná spotreba (pri výrobe výkup alebo výkon). Ak obchod prehráte a OOM nebude na zmluve ani v inom obchode, označí sa ako Zrušené.
      </p>
      <OomFields v={v} set={set} options={options} withSwitch={false} />
    </SidePanel>
  );
}

function ContactAddPanel(props: { deal: DealCard; options: DealOptions | undefined; onClose: () => void; onSaved: () => void }) {
  type Cand = { id: string; name: string | null; position: string | null; email: string | null; is_main_contact: boolean | null };
  const { data } = useApi<{ items: Cand[] }>(`/api/deals/${props.deal.id}/contact-candidates`);
  const [contact, setContact] = useState('');
  const [roles, setRoles] = useState<string[]>([]);
  const [primary, setPrimary] = useState(props.deal.contacts.length === 0);
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.deal.id}/contacts`, { contact_id: contact, roles, is_primary: primary });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Pridať kontaktnú osobu"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !contact} onClick={submit}>
            Pridať
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Osoba" hint="Osoby firmy (novú osobu pridajte na karte firmy).">
        <Select
          value={contact}
          onChange={setContact}
          placeholder="Vyberte osobu"
          options={(data?.items ?? []).map((c) => ({ value: c.id, label: [c.name, c.position].filter(Boolean).join(' · ') || '–' }))}
        />
      </Field>
      <Field label="Rola v obchode">
        <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
          {(props.options?.lists.rola_kontaktu ?? []).map((r) => (
            <Check key={r.code} checked={roles.includes(r.code)} onChange={(c) => setRoles((s) => (c ? [...s, r.code] : s.filter((x) => x !== r.code)))}>
              {r.label}
            </Check>
          ))}
        </div>
      </Field>
      <Check checked={primary} onChange={setPrimary}>
        Primárny kontakt (predvolená kontaktná osoba ponuky)
      </Check>
    </SidePanel>
  );
}
