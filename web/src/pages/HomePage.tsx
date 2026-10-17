// Domov (dizajn 30; modul 5, F6 krok 2; migrácie 0049, 0050). Úvodná stránka obchodníka (interného aj externého)
// a tímu Sales_internal: cena pre obchodníka FIX na 3 roky a jej vývoj (nikdy BL / PL), priemer SPOT od 1. 1., môj
// minimálny aditív; kalkulačka pridanej hodnoty a provízie (FIX voči cene pre obchodníka, manažér s maržou voči odhadu
// portfólia ako v ponuke; SPOT voči minimálnemu aditívu; záporná PH sa ukáže, provízia je vtedy 0 €); moje ďalšie
// kroky, moje ponuky a PH; pre manažéra rozpad podľa obchodníkov.

import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { NewDealPanel } from '../components/deal-forms';
import { Field, Select, TextInput } from '../components/form';
import { PageHero } from '../components/hero';
import { Icon, ICONS } from '../components/Layout';
import { Card, DateTile, Empty, ErrorState, Pill, Skeleton } from '../components/ui';
import { useApi } from '../lib/api';
import { date, dec, decRound, EMPTY, eur, num } from '../lib/format';
import { useMe } from '../lib/me';

type Home = {
  today: string;
  prices: { delivery_year: number; trader_price: string | null; price_date: string | null; settlement_date: string | null }[];
  basis: { delivery_year: number; basis: 'cena_pre_obchodnika' | 'odhad_portfolia'; basis_eur_mwh: string | null; price_date: string | null }[];
  series: { delivery_year: number; points: { on_date: string; trader_price: string }[] }[];
  spot: { on_date: string; avg_ytd_eur_mwh: string } | null;
  terms: { seller_type: 'obchodnik' | 'manazer'; min_additive_eur_mwh: string | null; commission_pct: string | null } | null;
  steps: { id: string; name: string; next_step: string | null; next_step_on: string; customer_name: string | null; state: 'po_termine' | 'dnes' | 'zajtra' }[];
  offers: { waiting_approval: number; sent: number; opened: number; expires_today: number; expired: number; accepted_waiting_contract: number };
  value: { open_deals: number; value_eur: string; weighted_eur: string; without_step: number };
  team: { owner_id: string; owner_name: string; open_deals: number; value_eur: string; weighted_eur: string; won_month: number; won_month_eur: string; attention: number }[] | null;
};

const BASIS_LABEL = { cena_pre_obchodnika: 'cena pre obchodníka', odhad_portfolia: 'nákupná cena portfólia' } as const;
const STEP_LABEL = { po_termine: 'po termíne', dnes: 'dnes', zajtra: 'zajtra' } as const;
const STEP_TONE = { po_termine: 'negative', dnes: 'warning', zajtra: 'neutral' } as const;
// Dátumová dlaždica: neskorší termín je modrý (DESIGN_SPEC § 6)
const TILE_TONE = { po_termine: 'negative', dnes: 'warning', zajtra: 'info' } as const;
const COLORS = ['var(--gl-chart-1)', 'var(--gl-chart-2)', 'var(--gl-chart-3)'];

/** „1 obchod“, „2 obchody“, „5 obchodov“ */
const dealsWord = (n: number) => `${num(n, 0)} ${n === 1 ? 'obchod' : n >= 2 && n <= 4 ? 'obchody' : 'obchodov'}`;

/** Číslo zo vstupu (čiarka aj bodka, medzery); prázdne alebo neplatné = null. */
function parse(v: string): number | null {
  const s = v.replace(/\s/g, '').replace(',', '.');
  if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
  return Number(s);
}

/** Pozdrav podľa času v Bratislave (Peter 16. 10. 2026: pozdrav ako v návrhu): do 10:00 ráno, do 18:00 deň, potom večer. */
function greeting(now: Date): string {
  const h = Number(new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', hourCycle: 'h23' }).format(now));
  return h < 10 ? 'Dobré ráno' : h < 18 ? 'Dobrý deň' : 'Dobrý večer';
}

/** „piatok 16. 10. 2026“ */
const todayLabel = (now: Date) =>
  `${new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', weekday: 'long' }).format(now)} ${date(now.toISOString())}`;

export function HomePage() {
  const me = useMe();
  const navigate = useNavigate();
  const { data, error } = useApi<Home>('/api/home');
  const [q, setQ] = useState('');
  const [newDeal, setNewDeal] = useState(false);
  if (error) return <ErrorState error={error} />;
  const now = new Date();
  const firstName = me.name.split(' ')[0];
  return (
    <>
      <PageHero
        size="home"
        above={todayLabel(now)}
        title={
          <>
            {greeting(now)}, <span className="hero-name">{firstName}</span>
          </>
        }
        actions={
          <div className="home-hero-actions">
            <form
              className="home-check"
              role="search"
              onSubmit={(e) => {
                e.preventDefault();
                navigate(q.trim() ? `/overenie-firmy?q=${encodeURIComponent(q.trim())}` : '/overenie-firmy');
              }}
            >
              <div className="gl-search home-check-input">
                <Icon d={ICONS.search} />
                <input type="search" placeholder="IČO alebo názov firmy…" aria-label="IČO alebo názov firmy" value={q} onChange={(e) => setQ(e.target.value)} />
              </div>
              <button type="submit" className="btn">
                Overiť firmu
              </button>
            </form>
            <Link className="btn" to="/obchody?owner=ja">
              <Icon d={ICONS.deals} />
              Moje obchody
            </Link>
            <button type="button" className="btn primary" onClick={() => setNewDeal(true)}>
              <Icon d={ICONS.plus} />
              Nový obchod
            </button>
            <div className="home-check-hint">Finstat + CRM: vlastník, otvorené obchody, dlhy, rating, Z-skóre</div>
          </div>
        }
      />
      {newDeal && <NewDealPanel onClose={() => setNewDeal(false)} onSaved={(id) => navigate(`/obchody/${id}`)} />}
      {!data ? (
        <div className="gl-overlap card card-body" style={{ paddingTop: 20 }}>
          <Skeleton lines={10} />
        </div>
      ) : (
        <HomeBody d={data} />
      )}
    </>
  );
}

function HomeBody({ d }: { d: Home }) {
  const weekend = d.prices.some((p) => p.price_date && p.price_date < d.today);
  return (
    <>
      <section className="gl-overlap home-tiles" aria-label="Ceny">
        {d.prices.map((p, i) => (
          <PriceTile
            key={p.delivery_year}
            main={i === 0}
            color={i > 0 ? COLORS[i % COLORS.length] : undefined}
            label={`Cena pre obchodníka FIX ${p.delivery_year}`}
            value={p.trader_price ? decRound(p.trader_price, 2) : ''}
            meta={p.price_date ? `€/MWh · stav k ${date(p.price_date)}${p.settlement_date ? ` · settlement ${date(p.settlement_date)}` : ''}` : 'cena dňa chýba'}
          />
        ))}
        <PriceTile
          label={`Priemerná SPOT od 1. 1. ${(d.spot?.on_date ?? '').slice(0, 4) || new Date().getFullYear()}`}
          value={d.spot ? dec(d.spot.avg_ytd_eur_mwh, 2, 2) : ''}
          meta={d.spot ? `€/MWh · OKTE · k ${date(d.spot.on_date)}` : 'zatiaľ nenačítané'}
        />
        <PriceTile
          label={`Minimálny aditív – ${d.terms?.seller_type === 'manazer' ? 'manažér' : 'obchodník'}`}
          value={d.terms?.min_additive_eur_mwh ? dec(d.terms.min_additive_eur_mwh, 2, 2) : ''}
          meta={`€/MWh${d.terms?.commission_pct ? ` · moja provízia ${dec(d.terms.commission_pct, 0, 2)} % z PH` : ''}`}
        />
      </section>
      {weekend && (
        <p className="caption home-note">
          Dnes ešte nie je cena dňa (víkend, sviatok alebo pred 7:00) – zobrazená je posledná cena najviac 7 dní stará.
        </p>
      )}

      <div className="home-grid">
        <div className="home-col">
          <Card title="Vývoj ceny pre obchodníka" aside={<ChartLegend series={d.series} />}>
            <PriceChart series={d.series} />
            <div className="caption chart-note">od 1. 1. 2026 · €/MWh</div>
          </Card>

          <Card title="Moje ďalšie kroky" aside={<Link to="/obchody?owner=ja&step=bez_alebo_po">bez kroku alebo po termíne</Link>}>
            {d.steps.length === 0 ? (
              <Empty>Na dnes a zajtra nemáte naplánovaný žiadny krok.</Empty>
            ) : (
              <div>
                {d.steps.map((s) => (
                  <div className="gl-step" key={s.id}>
                    <DateTile date={s.next_step_on} tone={TILE_TONE[s.state]} />
                    <div className="step-main">
                      <Link className="step-link" to={`/obchody/${s.id}`}>{s.name}</Link>
                      <div className="gl-sub">
                        {s.next_step ?? '–'}
                        {s.customer_name ? ` · ${s.customer_name}` : ''}
                      </div>
                    </div>
                    <Pill tone={STEP_TONE[s.state]}>{STEP_LABEL[s.state]}</Pill>
                  </div>
                ))}
              </div>
            )}
            {d.value.without_step > 0 && (
              <div className="caption" style={{ paddingTop: 8 }}>
                Bez ďalšieho kroku: <Link to="/obchody?owner=ja&step=bez_kroku">{dealsWord(d.value.without_step)}</Link>
              </div>
            )}
          </Card>
        </div>

        <div className="home-col">
          <Calculator d={d} />

          <Card title="Moje ponuky a obchody">
            <dl className="rows">
              <div className="row"><dt><Link to="/schvalovanie">Čakajú na schválenie</Link></dt><dd><Count n={d.offers.waiting_approval} tone="warning" /></dd></div>
              <div className="row"><dt>Odoslané a platné</dt><dd><span className="caption">(otvorené zákazníkom {num(d.offers.opened, 0)})</span> <Count n={d.offers.sent} tone="info" /></dd></div>
              <div className="row"><dt className={d.offers.expires_today > 0 ? 'negative-text' : undefined}>Vyprší dnes</dt><dd><Count n={d.offers.expires_today} tone="negative" /></dd></div>
              <div className="row"><dt title="odoslané alebo otvorené ponuky po platnosti, bez akceptácie">Vypršané (30 dní)</dt><dd><Count n={d.offers.expired} tone="warning" /></dd></div>
              <div className="row"><dt><Link to="/zmluvy-k-obchodom">Akceptované – čakajú na zmluvu</Link></dt><dd><Count n={d.offers.accepted_waiting_contract} tone="positive" /></dd></div>
              <div className="row"><dt>Otvorené obchody</dt><dd>{num(d.value.open_deals, 0)}</dd></div>
            </dl>
            <div className="home-value">
              <div className="gl-kpi__label">Pridaná hodnota otvorených</div>
              <div className={`gl-kpi__value${Number(d.value.value_eur) < 0 ? ' negative-text' : ''}`}>
                {eur(d.value.value_eur)} € <span className="home-value-weighted">· vážená pridaná hodnota {eur(d.value.weighted_eur)} €</span>
              </div>
            </div>
            <div className="caption" style={{ marginTop: 12 }}>
              PH obchodu: akceptovaný variant, inak hlavný variant poslednej odoslanej ponuky, inak odhad na obchode.
            </div>
          </Card>
        </div>
      </div>

      {d.team && <TeamTable team={d.team} />}
    </>
  );
}

/** Cenová dlaždica nad krajinou: hlavná (rok 2027) má jemný prechod, ostatné sú zo skla. */
function PriceTile(props: { label: string; value: string; meta: string; main?: boolean; color?: string }) {
  return (
    <div className={`home-tile gl-kpi ${props.main ? 'gl-card gl-card--soft' : 'gl-glass'}`}>
      <div className="gl-kpi__label">
        {props.color && <span className="legend-dot" style={{ background: props.color }} aria-hidden="true" />}
        {props.label}
      </div>
      <div className={`gl-kpi__value${props.main ? ' gl-kpi__value--lg' : ''}`}>{props.value || EMPTY}</div>
      <div className="gl-kpi__meta">{props.meta}</div>
    </div>
  );
}

/** Počet ako štítok; nula ostáva obyčajným číslom. */
const Count = (props: { n: number; tone: 'warning' | 'info' | 'negative' | 'positive' }) =>
  props.n > 0 ? <Pill tone={props.tone}>{num(props.n, 0)}</Pill> : <>0</>;

function ChartLegend({ series }: { series: Home['series'] }) {
  if (series.length === 0) return null;
  return (
    <div className="chart-legend">
      {series.map((s, i) => (
        <span key={s.delivery_year}>
          <span className="legend-line" style={{ background: COLORS[i % COLORS.length] }} aria-hidden="true" /> CAL {s.delivery_year}
        </span>
      ))}
    </div>
  );
}

/** Čiarový graf (SVG) – iba cena pre obchodníka po rokoch dodávky; každá séria má na konci popisok s hodnotou. */
function PriceChart({ series }: { series: Home['series'] }) {
  const all = series.flatMap((s) => s.points.map((p) => ({ t: Date.parse(p.on_date), v: Number(p.trader_price) })));
  if (all.length < 2) return <Empty>Vývoj sa zobrazí po načítaní cien z Montelu (Nastavenia → Cenové parametre).</Empty>;
  const W = 640;
  const H = 230;
  const P = { l: 36, r: 58, t: 10, b: 24 };
  const t0 = Math.min(...all.map((p) => p.t));
  const t1 = Math.max(...all.map((p) => p.t));
  let v0 = Math.min(...all.map((p) => p.v));
  let v1 = Math.max(...all.map((p) => p.v));
  const pad = Math.max(1, (v1 - v0) * 0.08);
  v0 -= pad;
  v1 += pad;
  const x = (t: number) => P.l + ((t - t0) / Math.max(1, t1 - t0)) * (W - P.l - P.r);
  const y = (v: number) => P.t + (1 - (v - v0) / (v1 - v0)) * (H - P.t - P.b);
  const ticks = [v0 + pad, (v0 + v1) / 2, v1 - pad];
  const pts = (s: Home['series'][number]) => s.points.map((p) => [x(Date.parse(p.on_date)), y(Number(p.trader_price))] as const);
  // Popisky na konci sérií: zhora nadol, aspoň 14 px od seba
  const ends = series
    .map((s, i) => {
      const last = s.points[s.points.length - 1];
      return last ? { i, year: s.delivery_year, value: last.trader_price, py: y(Number(last.trader_price)), ly: y(Number(last.trader_price)) } : null;
    })
    .filter((e) => e !== null)
    .sort((a, b) => a.py - b.py);
  ends.forEach((e, k) => {
    if (k > 0) e.ly = Math.max(e.ly, ends[k - 1].ly + 14);
  });
  const summary = ends
    .slice()
    .sort((a, b) => a.year - b.year)
    .map((e) => `CAL ${e.year} ${decRound(e.value, 2)} €/MWh`)
    .join(', ');
  const main = series[0] ? pts(series[0]) : [];
  return (
    <svg
      viewBox={`0 0 ${W} ${H}`}
      role="img"
      aria-label={`Vývoj ceny pre obchodníka od ${date(new Date(t0).toISOString().slice(0, 10))} do ${date(new Date(t1).toISOString().slice(0, 10))}, posledné hodnoty: ${summary}`}
      style={{ width: '100%', height: 'auto', display: 'block' }}
    >
      <defs>
        <linearGradient id="home-chart-area" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" style={{ stopColor: 'var(--gl-chart-1)', stopOpacity: 0.22 }} />
          <stop offset="1" style={{ stopColor: 'var(--gl-chart-1)', stopOpacity: 0 }} />
        </linearGradient>
      </defs>
      {ticks.map((v, k) => (
        <g key={v}>
          <line x1={P.l} x2={W - P.r} y1={y(v)} y2={y(v)} stroke={k === 0 ? 'var(--gl-chart-axis)' : 'var(--gl-chart-grid)'} strokeWidth="1" />
          <text x={P.l - 8} y={y(v) + 4} textAnchor="end" fontSize="11" fill="var(--gl-ink-muted)">{Math.round(v)}</text>
        </g>
      ))}
      <text x={P.l} y={H - 4} fontSize="11" fill="var(--gl-ink-muted)">{date(new Date(t0).toISOString().slice(0, 10))}</text>
      <text x={W - P.r} y={H - 4} fontSize="11" textAnchor="end" fill="var(--gl-ink-muted)">{date(new Date(t1).toISOString().slice(0, 10))}</text>
      {main.length > 1 && (
        <polygon
          fill="url(#home-chart-area)"
          points={[...main.map(([px, py]) => `${px.toFixed(1)},${py.toFixed(1)}`), `${main[main.length - 1][0].toFixed(1)},${H - P.b}`, `${main[0][0].toFixed(1)},${H - P.b}`].join(' ')}
        />
      )}
      {series
        .map((s, i) => (
          <polyline
            key={s.delivery_year}
            fill="none"
            stroke={COLORS[i % COLORS.length]}
            strokeWidth={i === 0 ? 3.5 : 2.5}
            strokeLinejoin="round"
            strokeLinecap="round"
            points={pts(s).map(([px, py]) => `${px.toFixed(1)},${py.toFixed(1)}`).join(' ')}
          />
        ))
        .reverse()}
      {main.length > 0 && (
        <circle cx={main[main.length - 1][0]} cy={main[main.length - 1][1]} r="5" fill="var(--gl-surface-card)" stroke="var(--gl-chart-1)" strokeWidth="2.5" />
      )}
      {ends.map((e) => (
        <text
          key={e.year}
          x={W - P.r + 10}
          y={e.ly + 4}
          fontSize="12"
          fontWeight={e.i === 0 ? 600 : 400}
          fill={e.i === 0 ? 'var(--gl-ink)' : 'var(--gl-ink-muted)'}
        >
          {decRound(e.value, 2)}
        </text>
      ))}
    </svg>
  );
}

/** Kalkulačka PH a provízie (iba orientačná; skutočnú PH počíta ponuka). */
function Calculator({ d }: { d: Home }) {
  const navigate = useNavigate();
  const [kind, setKind] = useState<'fix' | 'spot'>('fix');
  const [year, setYear] = useState(String(d.basis[0]?.delivery_year ?? ''));
  const [volume, setVolume] = useState('');
  const [price, setPrice] = useState('');
  const [creating, setCreating] = useState(false);
  const b = d.basis.find((x) => String(x.delivery_year) === year);
  const pct = Number(d.terms?.commission_pct ?? 0);
  const minAdd = d.terms?.min_additive_eur_mwh ? Number(d.terms.min_additive_eur_mwh) : null;

  const r = useMemo(() => {
    const vol = parse(volume);
    const p = parse(price);
    const base = kind === 'fix' ? (b?.basis_eur_mwh ? Number(b.basis_eur_mwh) : null) : minAdd;
    if (vol === null || p === null || base === null || vol < 0) return null;
    const ph = Math.round((p - base) * vol * 100) / 100;
    return { ph, commission: Math.round(Math.max(ph, 0) * pct) / 100 };
  }, [kind, volume, price, b, minAdd, pct]);

  const basisText = kind === 'fix'
    ? b ? `hranica: ${BASIS_LABEL[b.basis]}${b.basis_eur_mwh ? ` ${dec(b.basis_eur_mwh, 2, 2)} €/MWh` : ' – chýba'}` : 'hranica: –'
    : `hranica: minimálny aditív ${minAdd !== null ? `${dec(String(minAdd), 2, 2)} €/MWh` : '–'}`;

  return (
    <Card title="Kalkulačka pridanej hodnoty" className="calc-card">
      <div className="chips" role="group" aria-label="Typ ceny" style={{ marginBottom: 12 }}>
        <button type="button" className="chip" aria-pressed={kind === 'fix'} onClick={() => setKind('fix')}>FIX</button>
        <button type="button" className="chip" aria-pressed={kind === 'spot'} onClick={() => setKind('spot')}>SPOT</button>
      </div>
      <div className="form-grid">
        {kind === 'fix' && (
          <Field label="Rok dodávky">
            <Select value={year} onChange={setYear} options={d.basis.map((x) => ({ value: String(x.delivery_year), label: `CAL ${x.delivery_year}` }))} />
          </Field>
        )}
        <Field label="Objem [MWh / rok]">
          <TextInput value={volume} onChange={setVolume} maxLength={12} />
        </Field>
        <Field label={kind === 'fix' ? 'Moja cena [€/MWh]' : 'Môj aditív [€/MWh]'}>
          <TextInput value={price} onChange={setPrice} maxLength={12} />
        </Field>
      </div>
      <div className="caption" style={{ margin: '8px 0' }}>{basisText}</div>
      <div className="calc-result">
        <dl className="rows">
          <div className="row">
            <dt>Pridaná hodnota</dt>
            <dd className={r && r.ph < 0 ? 'strong negative-text' : 'strong'}>{r ? `${eur(r.ph)} €` : '–'}</dd>
          </div>
        </dl>
        <div className="gl-kpi__label" style={{ marginTop: 12 }}>Odhad mojej provízie ({dec(String(pct), 0, 2)} %)</div>
        <div className="gl-big-number" aria-live="polite">{r ? `${eur(r.commission)} €` : '–'}</div>
        <div className="gl-accent-line" aria-hidden="true" />
      </div>
      {r && r.ph < 0 && <div className="caption negative-text" style={{ marginBottom: 8 }}>Cena je pod hranicou – pridaná hodnota je záporná, provízia 0 €. Ponuka by potrebovala schválenie.</div>}
      {kind === 'fix' && b?.basis === 'odhad_portfolia' && (
        <div className="caption" style={{ marginBottom: 8 }}>Ako manažér máte pri FIX hranicu nákupnú cenu portfólia – rovnako ako v ponuke.</div>
      )}
      <button type="button" className="btn calc-cta" disabled={!r} onClick={() => setCreating(true)}>
        <Icon d={ICONS.plus} />
        Vytvoriť obchod s touto cenou
      </button>
      {creating && r && (
        <NewDealPanel
          estimate={r.ph > 0 ? r.ph.toFixed(2) : undefined}
          step={kind === 'fix' ? `Ponuka FIX ${year}: ${price} €/MWh, ${volume} MWh` : `Ponuka SPOT: aditív ${price} €/MWh, ${volume} MWh`}
          onClose={() => setCreating(false)}
          onSaved={(id) => navigate(`/obchody/${id}`)}
        />
      )}
    </Card>
  );
}

function TeamTable({ team }: { team: NonNullable<Home['team']> }) {
  return (
    <Card title="Obchodníci" aside={<span className="caption">otvorené obchody a vyhraté v tomto mesiaci</span>} flush>
      {team.length === 0 ? (
        <Empty>Žiadne obchody.</Empty>
      ) : (
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Obchodník</th>
                <th className="num">Otvorené</th>
                <th className="num">PH [€]</th>
                <th className="num">Vážená PH [€]</th>
                <th className="num">Vyhraté v mesiaci</th>
                <th className="num">Bez kroku / po termíne</th>
              </tr>
            </thead>
            <tbody>
              {team.map((t) => (
                <tr key={t.owner_id}>
                  <td><Link to={`/obchody?owner=${t.owner_id}`}>{t.owner_name}</Link></td>
                  <td className="num">{num(t.open_deals, 0)}</td>
                  <td className={`num${Number(t.value_eur) < 0 ? ' negative-text' : ''}`}>{eur(t.value_eur)}</td>
                  <td className={`num${Number(t.weighted_eur) < 0 ? ' negative-text' : ''}`}>{eur(t.weighted_eur)}</td>
                  <td className="num">{num(t.won_month, 0)} <span className="caption">({eur(t.won_month_eur)} €)</span></td>
                  <td className="num">{t.attention > 0 ? <Pill tone="warning">{num(t.attention, 0)}</Pill> : '0'}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  );
}
