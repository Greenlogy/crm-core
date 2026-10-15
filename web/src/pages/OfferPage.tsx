// Editor ponuky (dizajn 34; návrh DB časti 1.5–1.8, 19–21): varianty A–E, ceny OOM × rok s hranicou a pridanou
// hodnotou, podmienky, súhrn variantu s odhadom provízie (marža iba s právom), kontrola a schválenie, odoslanie,
// verzie a platnosť. Výpočty, stav a pravidlá robí databáza; web iba zobrazuje a posiela zmeny.
// PDF, stránka ponuky a akceptácia sú F3, e-mail z CRM F4.

import { useEffect, useMemo, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { Card, Empty, ErrorState, PageSkeleton, Pill, Rows, StatusPill } from '../components/ui';
import { send, useApi } from '../lib/api';
import { date, dec, eur, text } from '../lib/format';
import {
  APPROVAL_KIND, dateTime, isDraft, type Offer, OFFER_STATE, PRICE_KIND, type PriceKind, type PriceModel, SEND_CHANNEL,
  THRESHOLD_SOURCE, type Variant, type VariantSummary, type VariantValue, variantLetter,
} from '../lib/offers';

const APPROVAL_STATUS = {
  caka: { label: 'Čaká', tone: 'warning' as const, live: true },
  schvalena: { label: 'Schválená', tone: 'positive' as const, live: true },
  zamietnuta: { label: 'Zamietnutá', tone: 'negative' as const, live: true },
  zrusena: { label: 'Zrušená', tone: 'neutral' as const },
};
const toInput = (v: string | null | undefined) => (v === null || v === undefined ? '' : String(Number(v)).replace('.', ','));
/** Cena do poľa: 118,00 (2–4 desatinné miesta, bez medzier) */
const priceInput = (v: string | null | undefined) =>
  v === null || v === undefined ? '' : Number(v).toLocaleString('sk-SK', { minimumFractionDigits: 2, maximumFractionDigits: 4, useGrouping: false });
const nowLocal = () => {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 16);
};

type Panel = null | 'prepare' | 'sent' | 'reject' | 'shorten' | 'extend' | 'delete';

export function OfferPage() {
  const { id = '' } = useParams();
  const navigate = useNavigate();
  const { data: o, error, reload } = useApi<Offer>(`/api/offers/${id}`);
  const [tab, setTab] = useState<string | null>(null);
  const [panel, setPanel] = useState<Panel>(null);
  const [adding, setAdding] = useState(false);
  const save = useSave();

  useEffect(() => {
    if (o && (!tab || !o.variants.some((v) => v.id === tab))) setTab(o.variants[0]?.id ?? null);
  }, [o]);

  if (error) return <ErrorState error={error} />;
  if (!o) return <PageSkeleton />;
  const variant = o.variants.find((v) => v.id === tab) ?? o.variants[0];
  const calc = o.calc.find((c) => c.variant_id === variant?.id);
  const editable = o.can_edit && isDraft(o.status) && !o.closed_at;
  const sent = o.status === 'odoslana' || o.status === 'otvorena';
  const check = o.check;
  const blocked = check?.errors.some((e) => e.includes('akceptoval')) ?? false;

  const act = (fn: () => Promise<unknown>) =>
    save.run(async () => {
      await fn();
      reload();
    });

  return (
    <>
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <div className="caption">
            <Link to="/obchody">Obchody</Link> / <Link to={`/obchody/${o.deal_id}`}>{o.deal_name}</Link> / Ponuka
          </div>
          <div className="offer-title">
            <h1 className="t-page-title mono">{o.display_number}</h1>
            <StatusPill map={OFFER_STATE} value={o.state} />
            {o.version > 1 && <Pill>verzia {o.version}</Pill>}
            <Link to={`/obchody/${o.deal_id}`}>{o.deal_name}</Link>
            <span className="caption">· {text(o.customer_name)}</span>
          </div>
        </div>
        <div className="head-actions">
          {o.versions.length > 1 && (
            <select className="inp inp-auto" value={o.id} aria-label="Verzia ponuky" onChange={(e) => navigate(`/ponuky/${e.target.value}`)}>
              {o.versions.map((v) => (
                <option key={v.id} value={v.id}>
                  {v.display_number} · {OFFER_STATE[v.state].label}
                </option>
              ))}
            </select>
          )}
          {o.can_edit && sent && !o.closed_at && (
            <button type="button" className="btn" disabled={save.busy} onClick={() => act(async () => {
              const r = await send<{ id: string }>('POST', `/api/offers/${o.id}/new-version`);
              navigate(`/ponuky/${r.id}`);
            })}>
              Nová verzia
            </button>
          )}
          {editable && o.status === 'koncept' && !o.sent_at && (
            <button type="button" className="btn" onClick={() => setPanel('delete')}>
              Zmazať koncept
            </button>
          )}
        </div>
      </header>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {blocked && (
        <div className="ban ban-danger">Zákazník akceptoval inú verziu tejto ponuky – túto verziu nemožno pripraviť ani odoslať. Môžete ju zmazať.</div>
      )}

      <div className="columns">
        <div className="col-wide">
          <div className="tabs" role="tablist" aria-label="Varianty ponuky">
            {o.variants.map((v) => (
              <button key={v.id} type="button" role="tab" className="tab" aria-selected={v.id === variant?.id} onClick={() => setTab(v.id)}>
                {variantLetter(v.sort_order)} · {v.name}
              </button>
            ))}
            {editable && o.variants.length < 5 && (
              <button type="button" className="tab tab-add" onClick={() => setAdding(true)}>
                + Pridať variant
              </button>
            )}
          </div>
          {adding && variant && (
            <AddVariant
              offer={o}
              current={variant}
              onClose={() => setAdding(false)}
              onAdded={(vid) => {
                setAdding(false);
                setTab(vid);
                reload();
              }}
            />
          )}
          {variant && calc && (
            <VariantEditor
              key={`${variant.id}-${o.priced_on}-${o.items.length}`}
              offer={o}
              variant={variant}
              values={calc.values}
              editable={editable}
              onChanged={reload}
            />
          )}
        </div>

        <div className="col-right">
          {variant && calc && <SummaryCard offer={o} variant={variant} summary={calc.summary} values={calc.values} />}
          <Card title="Ponuka" aside={<StatusPill map={OFFER_STATE} value={o.state} />}>
            <Rows
              rows={[
                ['Jazyk', o.language === 'en' ? 'angličtina' : 'slovenčina'],
                ['Ceny k', date(o.priced_on)],
                ['Platnosť', o.valid_until ? `do ${dateTime(o.valid_until)}${o.valid_shortened ? ' (skrátená)' : ''}` : 'určí sa pri odoslaní'],
                ...(o.sent_at
                  ? ([['Odoslaná', `${dateTime(o.sent_at)} · ${SEND_CHANNEL[o.sent_channel ?? ''] ?? '–'}${o.sent_by_name ? ` · ${o.sent_by_name}` : ''}`]] as [string, string][])
                  : []),
                ...(o.rejected_at ? ([['Zamietnutá', `${dateTime(o.rejected_at)}${o.rejected_note ? ` · ${o.rejected_note}` : ''}`]] as [string, string][]) : []),
                ...o.variants
                  .filter((v) => v.id !== variant?.id)
                  .map((v): [string, string] => {
                    const s = o.calc.find((c) => c.variant_id === v.id)?.summary.find((x) => x.year === null);
                    return [`Variant ${variantLetter(v.sort_order)} · ${v.name}`, s?.added_value_eur ? `PH ${eur(s.added_value_eur)} €` : '–'];
                  }),
              ]}
            />
            <p className="caption" style={{ marginTop: 10 }}>
              FIX a FIX + SPOT platia do 16:00 nasledujúceho pracovného dňa, SPOT a VIWA 14 dní – od času odoslania. Skrátiť môže obchodník,
              predĺžiť iba schvaľovateľ cien.
            </p>
            <OfferActions offer={o} busy={save.busy} onPanel={setPanel} onReprice={() => act(() => send('POST', `/api/offers/${o.id}/reprice`))} />
          </Card>
          <CheckCard offer={o} />
          {o.approvals.length > 0 && (
            <Card title="Schvaľovanie">
              <ul className="plain-list">
                {o.approvals.map((a) => (
                  <li key={a.id} className="approval-row">
                    <div>
                      <strong>{APPROVAL_KIND[a.kind] ?? a.kind}</strong> <StatusPill map={APPROVAL_STATUS} value={a.status} />
                    </div>
                    <div className="caption">
                      {dateTime(a.created_at)} · {text(a.requested_by_name)}
                      {a.decided_at ? ` · rozhodol ${text(a.decided_by_name)} ${dateTime(a.decided_at)}` : ''}
                      {a.status === 'schvalena' && a.valid_until ? ` · platí do ${dateTime(a.valid_until)}` : ''}
                    </div>
                    {a.reason && <div className="caption">Dôvod: {a.reason}</div>}
                    {a.decision_note && <div className="caption">Poznámka: {a.decision_note}</div>}
                  </li>
                ))}
              </ul>
            </Card>
          )}
        </div>
      </div>

      {panel === 'prepare' && <PreparePanel offer={o} onClose={() => setPanel(null)} onDone={() => { setPanel(null); reload(); }} />}
      {panel === 'sent' && <SentPanel offer={o} onClose={() => setPanel(null)} onDone={() => { setPanel(null); reload(); }} />}
      {panel === 'reject' && (
        <SimplePanel
          title="Zákazník ponuku odmietol"
          label="Poznámka (nepovinné)"
          button="Zamietnuť"
          onClose={() => setPanel(null)}
          onSubmit={(note) => send('POST', `/api/offers/${o.id}/reject`, { note })}
          onDone={() => { setPanel(null); reload(); }}
        />
      )}
      {(panel === 'shorten' || panel === 'extend') && (
        <ValidityPanel offer={o} extend={panel === 'extend'} onClose={() => setPanel(null)} onDone={() => { setPanel(null); reload(); }} />
      )}
      {panel === 'delete' && (
        <SidePanel
          title="Zmazať koncept"
          onClose={() => setPanel(null)}
          footer={
            <button type="button" className="btn btn-danger-solid" disabled={save.busy} onClick={() => save.run(async () => {
              await send('DELETE', `/api/offers/${o.id}`);
              navigate(`/obchody/${o.deal_id}`);
            })}>
              Zmazať
            </button>
          }
        >
          <p>Koncept {o.display_number} sa zmaže aj s variantmi a cenami. Záznam v časovej osi obchodu ostane.</p>
        </SidePanel>
      )}
    </>
  );
}

function OfferActions(props: { offer: Offer; busy: boolean; onPanel: (p: Panel) => void; onReprice: () => void }) {
  const { offer: o } = props;
  if (!o.can_edit || o.closed_at) return null;
  const sent = o.status === 'odoslana' || o.status === 'otvorena';
  return (
    <div className="offer-actions">
      {o.status === 'koncept' && (
        <button type="button" className="btn primary" disabled={props.busy} onClick={() => props.onPanel('prepare')}>
          Pripraviť na odoslanie
        </button>
      )}
      {o.status === 'caka_na_schvalenie' && <div className="caption">Ponuka čaká na schválenie – odoslať sa dá po rozhodnutí.</div>}
      {o.status === 'pripravena' && (
        <button type="button" className="btn primary" disabled={props.busy} onClick={() => props.onPanel('sent')}>
          Označiť ako odoslanú
        </button>
      )}
      {isDraft(o.status) && (
        <button type="button" className="btn" disabled={props.busy} onClick={props.onReprice}>
          Prepočítať na dnešné ceny
        </button>
      )}
      {sent && (
        <>
          <button type="button" className="btn" onClick={() => props.onPanel('reject')}>
            Zákazník odmietol
          </button>
          <button type="button" className="btn" onClick={() => props.onPanel('shorten')}>
            Skrátiť platnosť
          </button>
          <button type="button" className="btn" onClick={() => props.onPanel('extend')}>
            Požiadať o predĺženie
          </button>
        </>
      )}
      <button type="button" className="btn" disabled title="PDF a stránka ponuky pribudnú vo fáze F3">
        Náhľad PDF
      </button>
    </div>
  );
}

function CheckCard(props: { offer: Offer }) {
  const c = props.offer.check;
  if (!c || !isDraft(props.offer.status)) return null;
  const errors = c.errors.filter((e) => !e.includes('akceptoval'));
  if (errors.length === 0 && c.needs.length === 0 && !c.risk_needs_approval && !c.fix_stale) return null;
  return (
    <div className="ban ban-warn offer-check">
      {c.needs.length > 0 && (
        <p>
          <strong>Bez výnimky sa ponuka nedá odoslať.</strong>{' '}
          {c.needs
            .map((n) => `${n.variant} · ${n.voltage_group.toUpperCase()} ${n.year} ${dec(n.requested_value, 2, 4)}${n.threshold_value !== null ? ` < ${dec(n.threshold_value, 2, 4)}` : ' pod hranicou'}`)
            .join('; ')}{' '}
          → „Pripraviť na odoslanie“ pošle žiadosť na schválenie. Schválená výnimka platí 3 dni na odoslanie.
        </p>
      )}
      {c.risk_needs_approval && <p><strong>Rizikový zákazník</strong> (konkurz, reštrukturalizácia alebo rating E/X) – ponuka potrebuje schválenie.</p>}
      {c.fix_stale && <p>Ceny pre obchodníka sú zo staršieho dňa – FIX ponuku pred odoslaním prepočítajte na dnešné ceny.</p>}
      {errors.length > 0 && (
        <ul>
          {errors.slice(0, 8).map((e) => <li key={e}>{e}</li>)}
          {errors.length > 8 && <li>… a ďalších {errors.length - 8}</li>}
        </ul>
      )}
    </div>
  );
}

function SummaryCard(props: { offer: Offer; variant: Variant; summary: VariantSummary[]; values: VariantValue[] }) {
  const { offer: o, variant: v } = props;
  const years = props.summary.filter((s) => s.year !== null);
  const total = props.summary.find((s) => s.year === null);
  const exception = props.values.some((x) => x.threshold_source === 'vynimka');
  return (
    <Card
      title={`Variant ${variantLetter(v.sort_order)} · súhrn`}
      aside={exception ? <Pill tone="positive" live>Výnimka schválená</Pill> : total?.below ? <Pill tone="warning" live>Pod hranicou</Pill> : undefined}
    >
      <Rows
        rows={[
          ...years.map((s): [string, string] => [`Pridaná hodnota ${s.year}`, `${eur(s.added_value_eur)} €`]),
          ['Pridaná hodnota spolu', <strong key="t">{eur(total?.added_value_eur)} €</strong>],
          [
            `Odhad provízie (${dec(total?.commission_pct ?? o.commission_pct, 0, 2)} %)`,
            <strong key="p" className="tone-positive">{eur(total?.commission_eur)} €</strong>,
          ],
          ...(o.see_margin ? ([['Marža firmy (komodita + poplatky)', `${eur(total?.margin_eur)} €`]] as [string, string][]) : []),
        ]}
      />
      {o.see_margin && <p className="caption" style={{ marginTop: 8 }}>Maržu vidí iba CEO, Nákup, Marketing a schvaľovateľ cien.</p>}
    </Card>
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Variant: nastavenie, ceny OOM × rok, podmienky
// ---------------------------------------------------------------------------------------------------------------

type Cell = { vt: string; nt: string; ad: string; pct: string };
const cellKey = (oom: string, year: number | null) => `${oom}|${year ?? ''}`;

function VariantEditor(props: { offer: Offer; variant: Variant; values: VariantValue[]; editable: boolean; onChanged: () => void }) {
  const { offer: o, variant: v, editable } = props;
  const save = useSave();
  const items = o.items.filter((i) => i.variant_id === v.id && i.slot === 'komodita');
  const perYear = v.price_kind === 'fix' || v.price_kind === 'kombinacia';
  const years: (number | null)[] = perYear ? v.years : [null];
  const listPriced = v.price_kind === 'cennik' || v.price_kind === 'viwa';
  const vykup = o.kind === 'vykup';

  // model pre stĺpec (rok): FIX, SPOT; kombinácia po rokoch; výkup SPOT − € alebo − %
  const initialModels = () => {
    const m: Record<string, PriceModel> = {};
    for (const y of years) {
      const found = items.find((i) => i.year === y);
      m[String(y)] =
        found?.price_model && found.price_model !== 'cennik'
          ? found.price_model
          : v.price_kind === 'fix' ? 'fix' : vykup ? 'spot_minus_eur' : 'spot_plus_eur';
    }
    return m;
  };
  const [models, setModels] = useState<Record<string, PriceModel>>(initialModels);
  const [product, setProduct] = useState<string>(items[0]?.product_id ?? o.products[0]?.id ?? '');
  const [cells, setCells] = useState<Record<string, Cell>>(() => {
    const c: Record<string, Cell> = {};
    for (const i of items) {
      if (!i.oom_id) continue;
      c[cellKey(i.oom_id, i.year)] = { vt: priceInput(i.price_vt_eur_mwh), nt: priceInput(i.price_nt_eur_mwh), ad: priceInput(i.additive_eur_mwh), pct: priceInput(i.additive_pct) };
    }
    return c;
  });
  const [dirty, setDirty] = useState(false);
  const [same, setSame] = useState<Record<string, string>>({});
  const products = o.products.filter((p) => years.every((y) => p.price_models.includes(models[String(y)] ?? 'fix')));

  const setCell = (k: string, f: keyof Cell, val: string) => {
    setCells((c) => ({ ...c, [k]: { ...{ vt: '', nt: '', ad: '', pct: '' }, ...c[k], [f]: val } }));
    setDirty(true);
  };
  const field = (y: number | null): keyof Cell => {
    const m = models[String(y)];
    return m === 'fix' ? 'vt' : m === 'spot_minus_pct' ? 'pct' : 'ad';
  };
  const savePrices = () =>
    save.run(async () => {
      const payload = o.ooms.flatMap((oom) =>
        years.map((y) => {
          const c = cells[cellKey(oom.id, y)] ?? { vt: '', nt: '', ad: '', pct: '' };
          return { oom_id: oom.id, year: y, product_id: product, price_model: models[String(y)], price_vt: c.vt, price_nt: c.nt, additive: c.ad, additive_pct: c.pct };
        }),
      );
      await send('PUT', `/api/offer-variants/${v.id}/prices`, { items: payload });
      setDirty(false);
      props.onChanged();
    });
  const fillNn = (y: number | null) => {
    const val = same[String(y)] ?? '';
    for (const oom of o.ooms.filter((x) => x.voltage_group === 'nn')) setCell(cellKey(oom.id, y), field(y), val);
  };

  const valueOf = (oom: string, y: number | null) =>
    props.values.filter((x) => x.oom_id === oom && (y === null || x.year === y));
  const volume = (oom: string, y: number | null) => valueOf(oom, y).reduce((s, x) => s + Number(x.volume_mwh ?? 0), 0);
  const added = (oom: string, y: number | null) => {
    const xs = valueOf(oom, y);
    return xs.some((x) => x.added_value_eur !== null) ? xs.reduce((s, x) => s + Number(x.added_value_eur ?? 0), 0) : null;
  };
  const totalVolume = o.ooms.reduce((s, oom) => s + volume(oom.id, null) / (perYear ? Math.max(v.years.length, 1) : 1), 0);
  const unit = (y: number | null) => (models[String(y)] === 'spot_minus_pct' ? '%' : '€/MWh');

  return (
    <>
      <VariantSettings offer={o} variant={v} editable={editable} onChanged={props.onChanged} />

      <Card
        flush
        title={vykup ? 'Ceny výkupu pre OOM' : 'Ceny pre OOM a rok'}
        aside={
          editable && !listPriced ? (
            <span style={{ display: 'flex', gap: 8 }}>
              <button type="button" className="btn primary" disabled={!dirty || save.busy} onClick={savePrices}>
                {save.busy ? 'Ukladám…' : 'Uložiť ceny'}
              </button>
            </span>
          ) : undefined
        }
      >
        {save.error && <div style={{ padding: '0 16px' }}><Notice tone="error">{save.error}</Notice></div>}
        {!listPriced && editable && (
          <div className="price-toolbar">
            <Field label="Produkt">
              <Select
                value={product}
                onChange={(x) => { setProduct(x); setDirty(true); }}
                options={(products.length ? products : o.products).map((p) => ({ value: p.id, label: p.name }))}
              />
            </Field>
            {years.map((y) =>
              v.price_kind === 'kombinacia' || (vykup && v.price_kind === 'spot') ? (
                <Field key={String(y)} label={y === null ? 'Model' : `Model ${y}`}>
                  <Select
                    value={models[String(y)]}
                    onChange={(m) => { setModels((x) => ({ ...x, [String(y)]: m })); setDirty(true); }}
                    options={(vykup ? ['spot_minus_eur', 'spot_minus_pct', 'fix'] : ['fix', 'spot_plus_eur']).map((m) => ({
                      value: m as PriceModel,
                      label: m === 'fix' ? 'FIX' : m === 'spot_plus_eur' ? 'SPOT + aditív' : m === 'spot_minus_eur' ? 'SPOT − €/MWh' : 'SPOT − %',
                    }))}
                  />
                </Field>
              ) : null,
            )}
          </div>
        )}
        {o.ooms.length === 0 ? (
          <Empty>Obchod nemá OOM – pridajte ich na karte obchodu.</Empty>
        ) : (
          <div className="table-wrap">
            <table className="tbl price-grid">
              <thead>
                <tr>
                  <th>EIC</th>
                  <th>Napätie</th>
                  <th className="num">Objem [MWh]</th>
                  {years.map((y) => (
                    <PriceHead key={String(y)} year={y} unit={unit(y)} listPriced={listPriced} />
                  ))}
                </tr>
              </thead>
              <tbody>
                {editable && !listPriced && o.ooms.some((x) => x.voltage_group === 'nn') && (
                  <tr className="same-row">
                    <td colSpan={3} className="caption">Rovnaká cena pre všetky NN</td>
                    {years.map((y) => (
                      <td key={String(y)} colSpan={3}>
                        <span className="same-cell">
                          <input
                            className="inp inp-num"
                            value={same[String(y)] ?? ''}
                            onChange={(e) => setSame((s) => ({ ...s, [String(y)]: e.target.value }))}
                            aria-label={`Rovnaká cena NN ${y ?? ''}`}
                          />
                          <button type="button" className="btn btn-sm" onClick={() => fillNn(y)}>
                            Vyplniť NN
                          </button>
                        </span>
                      </td>
                    ))}
                  </tr>
                )}
                {o.ooms.map((oom) => (
                  <tr key={oom.id}>
                    <td className="mono">{oom.eic}</td>
                    <td>{oom.voltage_group.toUpperCase()}</td>
                    <td className="num">{dec(volume(oom.id, null) / (perYear ? Math.max(v.years.length, 1) : 1), 1, 1)}</td>
                    {years.map((y) => {
                      const vals = valueOf(oom.id, y);
                      const first = vals[0];
                      const below = vals.some((x) => x.below);
                      const k = cellKey(oom.id, y);
                      const f = field(y);
                      const a = added(oom.id, y);
                      return (
                        <PriceCells
                          key={String(y)}
                          editable={editable && !listPriced}
                          value={listPriced ? priceInput(first?.price_vt) : cells[k]?.[f] ?? ''}
                          onChange={(val) => setCell(k, f, val)}
                          threshold={first?.threshold ?? null}
                          source={first?.threshold_source ?? null}
                          exception={first?.exception_value ?? null}
                          base={null}
                          added={a}
                          below={below}
                          label={`${oom.eic} ${y ?? ''}`}
                        />
                      );
                    })}
                  </tr>
                ))}
                <tr className="total-row">
                  <td colSpan={2}>Spolu</td>
                  <td className="num">{dec(totalVolume, 1, 1)}</td>
                  {years.map((y) => {
                    const s = o.ooms.reduce((t, oom) => t + (added(oom.id, y) ?? 0), 0);
                    return (
                      <td key={String(y)} colSpan={3} className="num">
                        {eur(s)} €
                      </td>
                    );
                  })}
                </tr>
              </tbody>
            </table>
          </div>
        )}
        <div className="caption" style={{ padding: '8px 16px' }}>
          {listPriced
            ? 'Ceny z cenníka dopĺňa CRM podľa sadzby OOM a obchodník ich nemení.'
            : `Hranica = ${vykup ? 'minimálny aditív výkupu' : o.seller_type === 'manazer' ? 'odhad nákupnej ceny portfólia (manažér)' : 'cena pre obchodníka'} ku dňu verzie (${date(o.priced_on)}). Pri schválenej výnimke platí schválená hranica. PH = pridaná hodnota, iba komodita.`}
          {dirty && ' · Neuložené zmeny cien.'}
        </div>
      </Card>

      <ConditionsCard offer={o} variant={v} editable={editable} onChanged={props.onChanged} />
    </>
  );
}

function PriceHead(props: { year: number | null; unit: string; listPriced: boolean }) {
  const y = props.year === null ? '' : `${props.year} `;
  return (
    <>
      <th className="num">{props.listPriced ? `${y}cena` : `${y}cena [${props.unit}]`}</th>
      <th className="num">Hranica</th>
      <th className="num">PH {props.year ?? ''} [€]</th>
    </>
  );
}

function PriceCells(props: {
  editable: boolean; value: string; onChange: (v: string) => void; threshold: string | null; source: string | null;
  exception: string | null; base: string | null; added: number | null; below: boolean; label: string;
}) {
  const hidden = props.threshold === null && props.source === 'odhad_portfolia';
  return (
    <>
      <td className={`num${props.below ? ' cell-below' : ''}`}>
        {props.editable ? (
          <input className="inp inp-num" value={props.value} onChange={(e) => props.onChange(e.target.value)} aria-label={`Cena ${props.label}`} inputMode="decimal" />
        ) : (
          props.value || '–'
        )}
      </td>
      <td className={`num muted${props.below ? ' cell-below' : ''}`} title={props.source ? THRESHOLD_SOURCE[props.source] ?? props.source : undefined}>
        {hidden ? 'skrytá' : props.threshold === null ? '–' : dec(props.threshold, 2, 4)}
        {props.source === 'vynimka' && <span className="caption"> výnimka</span>}
      </td>
      <td className={`num${props.below ? ' cell-below tone-negative' : ''}`}>{props.added === null ? '–' : eur(props.added)}</td>
    </>
  );
}

function VariantSettings(props: { offer: Offer; variant: Variant; editable: boolean; onChanged: () => void }) {
  const { offer: o, variant: v, editable } = props;
  const save = useSave();
  const [vals, setVals] = useState({ name: v.name, price_kind: v.price_kind, supply_from: v.supply_from, supply_to: v.supply_to ?? '', viwa_package: v.viwa_package ?? 'plus' });
  const changed = vals.name !== v.name || vals.price_kind !== v.price_kind || vals.supply_from !== v.supply_from
    || vals.supply_to !== (v.supply_to ?? '') || (v.price_kind === 'viwa' && vals.viwa_package !== v.viwa_package);
  const kinds: PriceKind[] = o.kind === 'viwa' ? ['viwa'] : o.household ? ['cennik', 'spot'] : o.kind === 'vykup' ? ['spot', 'fix'] : ['fix', 'spot', 'kombinacia', 'cennik'];
  const submit = () =>
    save.run(async () => {
      await send('PATCH', `/api/offer-variants/${v.id}`, {
        name: vals.name,
        price_kind: vals.price_kind,
        supply_from: vals.supply_from,
        supply_to: vals.supply_to || null,
        ...(vals.price_kind === 'viwa' ? { viwa_package: vals.viwa_package } : {}),
      });
      props.onChanged();
    });
  const remove = () =>
    save.run(async () => {
      await send('DELETE', `/api/offer-variants/${v.id}`);
      props.onChanged();
    });
  return (
    <Card>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <div className="form-grid form-grid-4">
        <Field label="Typ ceny">
          <Select value={vals.price_kind} disabled={!editable} onChange={(x) => setVals({ ...vals, price_kind: x })} options={kinds.map((k) => ({ value: k, label: PRICE_KIND[k] }))} />
        </Field>
        <Field label="Dodávka od">
          <input className="inp" type="date" value={vals.supply_from} disabled={!editable} onChange={(e) => setVals({ ...vals, supply_from: e.target.value })} />
        </Field>
        <Field label="Dodávka do" hint={vals.supply_to ? undefined : 'na neurčito'}>
          <input className="inp" type="date" value={vals.supply_to} disabled={!editable} onChange={(e) => setVals({ ...vals, supply_to: e.target.value })} />
        </Field>
        <Field label="Názov variantu">
          <TextInput value={vals.name} disabled={!editable} maxLength={120} onChange={(x) => setVals({ ...vals, name: x })} />
        </Field>
        {vals.price_kind === 'viwa' && (
          <Field label="Balík VIWA">
            <Select value={vals.viwa_package} disabled={!editable} onChange={(x) => setVals({ ...vals, viwa_package: x })} options={['basic', 'plus', 'pro'].map((p) => ({ value: p, label: p.toUpperCase() }))} />
          </Field>
        )}
      </div>
      {editable && (
        <div className="form-actions">
          {o.variants.length > 1 && (
            <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={remove}>
              Zmazať variant
            </button>
          )}
          <button type="button" className="btn" disabled={!changed || save.busy} onClick={submit}>
            Uložiť variant
          </button>
        </div>
      )}
    </Card>
  );
}

function ConditionsCard(props: { offer: Offer; variant: Variant; editable: boolean; onChanged: () => void }) {
  const { offer: o, variant: v, editable } = props;
  const save = useSave();
  const init = useMemo(
    () => ({
      flexibility_pct: toInput(v.flexibility_pct),
      planned_volume_mwh: toInput(v.planned_volume_mwh),
      invoice_due_days: String(v.invoice_due_days),
      advance_kind: v.advance_kind,
      advance_pct: toInput(v.advance_pct),
      advance_due_day: v.advance_due_day === null ? '' : String(v.advance_due_day),
      negative_price_compensation: v.negative_price_compensation,
      contact_id: o.contact_id ?? '',
      language: o.language,
    }),
    [v, o.contact_id, o.language],
  );
  const [vals, setVals] = useState(init);
  const changed = JSON.stringify(vals) !== JSON.stringify(init);
  const set = <K extends keyof typeof vals>(k: K, x: (typeof vals)[K]) => setVals((s) => ({ ...s, [k]: x }));
  const submit = () =>
    save.run(async () => {
      await send('PATCH', `/api/offer-variants/${v.id}`, {
        flexibility_pct: vals.flexibility_pct || null,
        planned_volume_mwh: vals.planned_volume_mwh || null,
        invoice_due_days: vals.invoice_due_days,
        advance_kind: vals.advance_kind,
        advance_pct: vals.advance_pct || null,
        advance_due_day: vals.advance_due_day || null,
        negative_price_compensation: vals.negative_price_compensation,
      });
      if (vals.contact_id !== (o.contact_id ?? '') || vals.language !== o.language) {
        await send('PATCH', `/api/offers/${o.id}`, { contact_id: vals.contact_id || null, language: vals.language });
      }
      props.onChanged();
    });
  return (
    <Card title="Podmienky v ponuke" aside={<span className="caption">šablóna {o.kind === 'vykup' ? 'Výkup' : o.kind === 'viwa' ? 'VIWA' : 'Dodávka'} · {o.language.toUpperCase()}</span>}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <div className="form-grid form-grid-3">
        <Field label="Flexibilita odberu [%]" hint="prázdne = plná flexibilita">
          <TextInput value={vals.flexibility_pct} disabled={!editable} onChange={(x) => set('flexibility_pct', x)} placeholder="plná flexibilita" />
        </Field>
        <Field label="Plánovaný ročný objem [MWh]" hint="prázdne = súčet OOM">
          <TextInput value={vals.planned_volume_mwh} disabled={!editable} onChange={(x) => set('planned_volume_mwh', x)} />
        </Field>
        <Field label="Splatnosť vyúčtovacej faktúry [dni]">
          <TextInput value={vals.invoice_due_days} disabled={!editable} onChange={(x) => set('invoice_due_days', x)} />
        </Field>
        <Field label="Preddavky">
          <Select
            value={vals.advance_kind}
            disabled={!editable}
            onChange={(x) => set('advance_kind', x)}
            options={[
              { value: 'mesacne', label: 'Mesačné preddavky' },
              { value: 'financna_zabezpeka', label: 'Finančná zábezpeka' },
            ]}
          />
        </Field>
        <Field label="Preddavok [% z 1/12 ročného odberu]">
          <TextInput value={vals.advance_pct} disabled={!editable} onChange={(x) => set('advance_pct', x)} />
        </Field>
        <Field label="Splatnosť preddavku [deň v mesiaci]">
          <TextInput value={vals.advance_due_day} disabled={!editable} onChange={(x) => set('advance_due_day', x)} />
        </Field>
        <Field label="Kontaktná osoba">
          <Select
            value={vals.contact_id}
            disabled={!editable}
            onChange={(x) => set('contact_id', x)}
            options={[{ value: '', label: '–' }, ...o.contacts.map((c) => ({ value: c.id, label: `${text(c.name)}${c.position ? ` · ${c.position}` : ''}` }))]}
          />
        </Field>
        <Field label="Jazyk ponuky">
          <Select value={vals.language} disabled={!editable} onChange={(x) => set('language', x)} options={[{ value: 'sk', label: 'slovenčina' }, { value: 'en', label: 'angličtina' }]} />
        </Field>
        {o.kind === 'vykup' && (
          <Field label=" ">
            <Check checked={vals.negative_price_compensation} disabled={!editable} onChange={(x) => set('negative_price_compensation', x)}>
              Kompenzácia záporných cien
            </Check>
          </Field>
        )}
      </div>
      {editable && (
        <div className="form-actions">
          <button type="button" className="btn" disabled={!changed || save.busy} onClick={submit}>
            Uložiť podmienky
          </button>
        </div>
      )}
    </Card>
  );
}

function AddVariant(props: { offer: Offer; current: Variant; onClose: () => void; onAdded: (id: string) => void }) {
  const o = props.offer;
  const kinds: PriceKind[] = o.kind === 'viwa' ? ['viwa'] : o.household ? ['cennik', 'spot'] : o.kind === 'vykup' ? ['spot', 'fix'] : ['fix', 'spot', 'kombinacia', 'cennik'];
  const [kind, setKind] = useState<PriceKind>(kinds[0]);
  const [copy, setCopy] = useState(false);
  const save = useSave();
  return (
    <SidePanel
      title="Pridať variant"
      onClose={props.onClose}
      footer={
        <button type="button" className="btn primary" disabled={save.busy} onClick={() => save.run(async () => {
          const r = await send<{ id: string }>('POST', `/api/offers/${o.id}/variants`, { price_kind: kind, copy_from: copy ? props.current.id : null });
          props.onAdded(r.id);
        })}>
          Pridať
        </button>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Typ ceny">
        <Select value={kind} onChange={setKind} options={kinds.map((k) => ({ value: k, label: PRICE_KIND[k] }))} />
      </Field>
      <Check checked={copy} onChange={setCopy}>
        Skopírovať ceny z variantu {variantLetter(props.current.sort_order)} · {props.current.name}
      </Check>
      <p className="caption">Ponuka má najviac 5 variantov. Obdobie sa prevezme z aktuálneho variantu.</p>
    </SidePanel>
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Panely akcií
// ---------------------------------------------------------------------------------------------------------------

function PreparePanel(props: { offer: Offer; onClose: () => void; onDone: () => void }) {
  const c = props.offer.check;
  const needs = (c?.needs.length ?? 0) > 0 || !!c?.risk_needs_approval;
  const [reason, setReason] = useState('');
  const save = useSave();
  const [result, setResult] = useState<string | null>(null);
  return (
    <SidePanel
      title="Pripraviť na odoslanie"
      onClose={props.onClose}
      footer={
        result ? (
          <button type="button" className="btn primary" onClick={props.onDone}>Zavrieť</button>
        ) : (
          <button type="button" className="btn primary" disabled={save.busy || (needs && !reason.trim())} onClick={() => save.run(async () => {
            const r = await send<{ status: string }>('POST', `/api/offers/${props.offer.id}/prepare`, { reason });
            setResult(r.status);
          })}>
            {needs ? 'Požiadať o schválenie' : 'Pripraviť'}
          </button>
        )
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {result === 'pripravena' && <Notice tone="ok">Ponuka je pripravená – môžete ju poslať zákazníkovi a označiť ako odoslanú.</Notice>}
      {result === 'caka_na_schvalenie' && <Notice tone="ok">Žiadosť odoslaná schvaľovateľom cien. Výsledok uvidíte v zvončeku a na ponuke.</Notice>}
      {!result && (
        needs ? (
          <>
            <p>Ponuka potrebuje schválenie:</p>
            <ul>
              {c?.needs.map((n) => (
                <li key={`${n.variant_id}-${n.year}-${n.voltage_group}-${n.price_model}`}>
                  Variant {n.variant} · {n.voltage_group.toUpperCase()} {n.year}: {dec(n.requested_value, 2, 4)}
                  {n.threshold_value !== null ? ` < ${dec(n.threshold_value, 2, 4)}` : ' pod hranicou'} · {dec(n.volume_mwh, 1, 1)} MWh
                </li>
              ))}
              {c?.risk_needs_approval && <li>Rizikový zákazník (konkurz, reštrukturalizácia alebo rating E/X)</li>}
            </ul>
            <Field label="Dôvod žiadosti">
              <textarea className="inp" rows={3} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} />
            </Field>
            <p className="caption">Schvaľuje CEO alebo obchodný riaditeľ. Schválená výnimka platí 3 dni na odoslanie, schválenie rizika 30 dní.</p>
          </>
        ) : (
          <p>Kontrola prešla – ponuka sa označí ako pripravená na odoslanie.</p>
        )
      )}
    </SidePanel>
  );
}

function SentPanel(props: { offer: Offer; onClose: () => void; onDone: () => void }) {
  const [at, setAt] = useState(nowLocal());
  const [channel, setChannel] = useState<'email_mimo_crm' | 'osobne' | 'ine' | ''>('');
  const [note, setNote] = useState('');
  const save = useSave();
  const fix = props.offer.variants.some((v) => v.price_kind === 'fix' || v.price_kind === 'kombinacia');
  return (
    <SidePanel
      title="Označiť ako odoslanú"
      onClose={props.onClose}
      footer={
        <button type="button" className="btn primary" disabled={save.busy || !channel} onClick={() => save.run(async () => {
          await send('POST', `/api/offers/${props.offer.id}/mark-sent`, { sent_at: new Date(at).toISOString(), channel, note });
          props.onDone();
        })}>
          Označiť ako odoslanú
        </button>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Kedy bola odoslaná">
        <input className="inp" type="datetime-local" value={at} max={nowLocal()} onChange={(e) => setAt(e.target.value)} />
      </Field>
      <Field label="Ako">
        <Select value={channel} placeholder="Vyberte" onChange={setChannel} options={(['email_mimo_crm', 'osobne', 'ine'] as const).map((x) => ({ value: x, label: SEND_CHANNEL[x] }))} />
      </Field>
      <Field label="Poznámka (nepovinné)">
        <TextInput value={note} maxLength={1000} onChange={setNote} />
      </Field>
      <p className="caption">
        Platnosť sa počíta od času odoslania: {fix ? 'FIX do 16:00 nasledujúceho pracovného dňa' : 'SPOT a VIWA 14 dní'}. Staršie odoslané verzie sa
        označia ako Nahradené, obchod sa posunie z Príležitosti do Cenovej ponuky.
        {fix ? ' FIX ponuku s cenami zo staršieho dňa treba najprv prepočítať.' : ''}
      </p>
    </SidePanel>
  );
}

function ValidityPanel(props: { offer: Offer; extend: boolean; onClose: () => void; onDone: () => void }) {
  const cur = props.offer.valid_until ? new Date(props.offer.valid_until) : new Date();
  cur.setMinutes(cur.getMinutes() - cur.getTimezoneOffset());
  const [until, setUntil] = useState(cur.toISOString().slice(0, 16));
  const [reason, setReason] = useState('');
  const save = useSave();
  return (
    <SidePanel
      title={props.extend ? 'Požiadať o predĺženie platnosti' : 'Skrátiť platnosť'}
      onClose={props.onClose}
      footer={
        <button type="button" className="btn primary" disabled={save.busy || (props.extend && !reason.trim())} onClick={() => save.run(async () => {
          const body = { until: new Date(until).toISOString(), reason };
          await send('POST', `/api/offers/${props.offer.id}/${props.extend ? 'extend' : 'shorten'}`, body);
          props.onDone();
        })}>
          {props.extend ? 'Požiadať' : 'Skrátiť'}
        </button>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p>Teraz platí do {dateTime(props.offer.valid_until)}.</p>
      <Field label="Nová platnosť do">
        <input className="inp" type="datetime-local" value={until} onChange={(e) => setUntil(e.target.value)} />
      </Field>
      {props.extend && (
        <Field label="Dôvod">
          <textarea className="inp" rows={3} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} />
        </Field>
      )}
      <p className="caption">{props.extend ? 'Predĺženie schvaľuje schvaľovateľ cien.' : 'Skrátiť sa dá iba na čas v budúcnosti, skôr ako doterajšia platnosť.'}</p>
    </SidePanel>
  );
}

function SimplePanel(props: { title: string; label: string; button: string; onClose: () => void; onSubmit: (note: string) => Promise<unknown>; onDone: () => void }) {
  const [note, setNote] = useState('');
  const save = useSave();
  return (
    <SidePanel
      title={props.title}
      onClose={props.onClose}
      footer={
        <button type="button" className="btn primary" disabled={save.busy} onClick={() => save.run(async () => {
          await props.onSubmit(note);
          props.onDone();
        })}>
          {props.button}
        </button>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label={props.label}>
        <textarea className="inp" rows={3} maxLength={1000} value={note} onChange={(e) => setNote(e.target.value)} />
      </Field>
    </SidePanel>
  );
}
