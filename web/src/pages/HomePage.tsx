// Domov (dizajn 30; modul 5, F6 krok 2; migrácie 0049, 0050). Úvodná stránka obchodníka (interného aj externého)
// a tímu Sales_internal: cena pre obchodníka FIX na 3 roky a jej vývoj (nikdy BL / PL), 12-mesačný SPOT priemer, môj
// minimálny aditív; kalkulačka pridanej hodnoty a provízie (FIX voči cene pre obchodníka, manažér s maržou voči odhadu
// portfólia ako v ponuke; SPOT voči minimálnemu aditívu; záporná PH sa ukáže, provízia je vtedy 0 €); moje ďalšie
// kroky, moje ponuky a PH; pre manažéra rozpad podľa obchodníkov.

import { useMemo, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { NewDealPanel } from '../components/deal-forms';
import { Field, Select, TextInput } from '../components/form';
import { Card, Empty, ErrorState, Kpi, Pill, Skeleton } from '../components/ui';
import { useApi } from '../lib/api';
import { date, dec, eur, num } from '../lib/format';
import { useMe } from '../lib/me';

type Home = {
  today: string;
  prices: { delivery_year: number; trader_price: string | null; price_date: string | null }[];
  basis: { delivery_year: number; basis: 'cena_pre_obchodnika' | 'odhad_portfolia'; basis_eur_mwh: string | null; price_date: string | null }[];
  series: { delivery_year: number; points: { on_date: string; trader_price: string }[] }[];
  spot: { on_date: string; avg_12m_eur_mwh: string } | null;
  terms: { seller_type: 'obchodnik' | 'manazer'; min_additive_eur_mwh: string | null; commission_pct: string | null } | null;
  steps: { id: string; name: string; next_step: string | null; next_step_on: string; customer_name: string | null; state: 'po_termine' | 'dnes' | 'zajtra' }[];
  offers: { waiting_approval: number; sent: number; opened: number; expires_today: number; accepted_waiting_contract: number };
  value: { open_deals: number; value_eur: string; weighted_eur: string; without_step: number };
  team: { owner_id: string; owner_name: string; open_deals: number; value_eur: string; weighted_eur: string; won_month: number; won_month_eur: string; attention: number }[] | null;
};

const BASIS_LABEL = { cena_pre_obchodnika: 'cena pre obchodníka', odhad_portfolia: 'odhad portfólia' } as const;
const STEP_LABEL = { po_termine: 'po termíne', dnes: 'dnes', zajtra: 'zajtra' } as const;
const STEP_TONE = { po_termine: 'negative', dnes: 'warning', zajtra: 'neutral' } as const;
const COLORS = ['var(--chart-1)', 'var(--chart-2)', 'var(--chart-3)'];

/** „1 obchod“, „2 obchody“, „5 obchodov“ */
const dealsWord = (n: number) => `${num(n, 0)} ${n === 1 ? 'obchod' : n >= 2 && n <= 4 ? 'obchody' : 'obchodov'}`;

/** Číslo zo vstupu (čiarka aj bodka, medzery); prázdne alebo neplatné = null. */
function parse(v: string): number | null {
  const s = v.replace(/\s/g, '').replace(',', '.');
  if (!/^-?\d+(\.\d+)?$/.test(s)) return null;
  return Number(s);
}

export function HomePage() {
  const me = useMe();
  const { data, error } = useApi<Home>('/api/home');
  if (error) return <ErrorState error={error} />;
  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Domov</h1>
          <span className="page-sub">{me.name} · ceny, kalkulačka a moje obchody</span>
        </div>
        <div className="head-actions">
          <Link className="btn" to="/overenie-firmy">
            Overiť firmu
          </Link>
          <Link className="btn" to="/obchody?owner=ja">
            Moje obchody
          </Link>
        </div>
      </header>
      {!data ? <Skeleton lines={10} /> : <HomeBody d={data} />}
    </>
  );
}

function HomeBody({ d }: { d: Home }) {
  const weekend = d.prices.some((p) => p.price_date && p.price_date < d.today);
  return (
    <>
      <div className="kpis" style={{ marginBottom: 16 }}>
        {d.prices.map((p) => (
          <Kpi
            key={p.delivery_year}
            label={`Cena pre obchodníka FIX ${p.delivery_year}`}
            value={p.trader_price ? `${dec(p.trader_price, 2, 2)} €/MWh` : ''}
            sub={p.price_date ? `stav k ${date(p.price_date)}` : 'cena dňa chýba'}
          />
        ))}
        <Kpi
          label="Priemerná SPOT za 12 mesiacov"
          value={d.spot ? `${dec(d.spot.avg_12m_eur_mwh, 2, 2)} €/MWh` : ''}
          sub={d.spot ? `OKTE · k ${date(d.spot.on_date)}` : 'zatiaľ nenačítané'}
        />
        <Kpi
          label={`Minimálny aditív – ${d.terms?.seller_type === 'manazer' ? 'manažér' : 'obchodník'}`}
          value={d.terms?.min_additive_eur_mwh ? `${dec(d.terms.min_additive_eur_mwh, 2, 2)} €/MWh` : ''}
          sub={d.terms?.commission_pct ? `moja provízia ${dec(d.terms.commission_pct, 0, 2)} % z PH` : undefined}
        />
      </div>
      {weekend && (
        <p className="caption" style={{ marginTop: -8, marginBottom: 16 }}>
          Dnes ešte nie je cena dňa (víkend, sviatok alebo pred 7:00) – zobrazená je posledná cena najviac 7 dní stará.
        </p>
      )}

      <div className="home-grid">
        <Card title="Vývoj ceny pre obchodníka" aside={<span className="caption">od 1. 1. 2026 · €/MWh</span>}>
          <PriceChart series={d.series} />
        </Card>
        <Calculator d={d} />
      </div>

      <div className="home-grid">
        <Card title="Moje ďalšie kroky" aside={<Link to="/obchody?owner=ja&step=bez_alebo_po">bez kroku alebo po termíne</Link>} flush>
          {d.steps.length === 0 ? (
            <Empty>Na dnes a zajtra nemáte naplánovaný žiadny krok.</Empty>
          ) : (
            <div className="table-wrap">
              <table className="tbl">
                <tbody>
                  {d.steps.map((s) => (
                    <tr key={s.id}>
                      <td>
                        <Link to={`/obchody/${s.id}`}>{s.name}</Link>
                        <div className="sub">{s.customer_name}</div>
                      </td>
                      <td>{s.next_step ?? '–'}</td>
                      <td>
                        <Pill tone={STEP_TONE[s.state]}>{STEP_LABEL[s.state]}</Pill> <span className="caption">{date(s.next_step_on)}</span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
          {d.value.without_step > 0 && (
            <div className="caption" style={{ padding: '8px 16px' }}>
              Bez ďalšieho kroku: <Link to="/obchody?owner=ja&step=bez_kroku">{dealsWord(d.value.without_step)}</Link>
            </div>
          )}
        </Card>

        <Card title="Moje ponuky a obchody">
          <dl className="rows">
            <div className="row"><dt><Link to="/schvalovanie">Čakajú na schválenie</Link></dt><dd>{num(d.offers.waiting_approval, 0)}</dd></div>
            <div className="row"><dt>Odoslané a platné</dt><dd>{num(d.offers.sent, 0)} <span className="caption">(otvorené zákazníkom {num(d.offers.opened, 0)})</span></dd></div>
            <div className="row"><dt>Vyprší dnes</dt><dd>{d.offers.expires_today > 0 ? <Pill tone="warning">{num(d.offers.expires_today, 0)}</Pill> : '0'}</dd></div>
            <div className="row"><dt><Link to="/zmluvy-k-obchodom">Akceptované – čakajú na zmluvu</Link></dt><dd>{num(d.offers.accepted_waiting_contract, 0)}</dd></div>
            <div className="row"><dt>Otvorené obchody</dt><dd>{num(d.value.open_deals, 0)}</dd></div>
            <div className="row"><dt>Pridaná hodnota otvorených</dt><dd className="strong">{eur(d.value.value_eur)} €</dd></div>
            <div className="row"><dt>Vážená pridaná hodnota</dt><dd>{eur(d.value.weighted_eur)} €</dd></div>
          </dl>
          <div className="caption" style={{ marginTop: 8 }}>
            PH obchodu: akceptovaný variant, inak hlavný variant poslednej odoslanej ponuky, inak odhad na obchode.
          </div>
        </Card>
      </div>

      {d.team && <TeamTable team={d.team} />}
    </>
  );
}

/** Jednoduchý čiarový graf (SVG) – iba cena pre obchodníka po rokoch dodávky. */
function PriceChart({ series }: { series: Home['series'] }) {
  const all = series.flatMap((s) => s.points.map((p) => ({ t: Date.parse(p.on_date), v: Number(p.trader_price) })));
  if (all.length < 2) return <Empty>Vývoj sa zobrazí po načítaní cien z Montelu (Nastavenia → Cenové parametre).</Empty>;
  const W = 640;
  const H = 220;
  const P = { l: 44, r: 8, t: 8, b: 22 };
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
  return (
    <>
      <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label="Vývoj ceny pre obchodníka" style={{ width: '100%', height: 'auto', display: 'block' }}>
        {ticks.map((v) => (
          <g key={v}>
            <line x1={P.l} x2={W - P.r} y1={y(v)} y2={y(v)} stroke="var(--border)" strokeWidth="1" />
            <text x={P.l - 6} y={y(v) + 4} textAnchor="end" fontSize="11" fill="var(--ink-subtle)">{Math.round(v)}</text>
          </g>
        ))}
        <text x={P.l} y={H - 4} fontSize="11" fill="var(--ink-subtle)">{date(new Date(t0).toISOString().slice(0, 10))}</text>
        <text x={W - P.r} y={H - 4} fontSize="11" textAnchor="end" fill="var(--ink-subtle)">{date(new Date(t1).toISOString().slice(0, 10))}</text>
        {series.map((s, i) => (
          <polyline
            key={s.delivery_year}
            fill="none"
            stroke={COLORS[i % COLORS.length]}
            strokeWidth="2"
            points={s.points.map((p) => `${x(Date.parse(p.on_date)).toFixed(1)},${y(Number(p.trader_price)).toFixed(1)}`).join(' ')}
          />
        ))}
      </svg>
      <div className="chart-legend">
        {series.map((s, i) => (
          <span key={s.delivery_year}>
            <span className="legend-dot" style={{ background: COLORS[i % COLORS.length] }} /> CAL {s.delivery_year}
          </span>
        ))}
      </div>
    </>
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
    <Card title="Kalkulačka pridanej hodnoty">
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
      <dl className="rows">
        <div className="row">
          <dt>Pridaná hodnota</dt>
          <dd className="strong" style={r && r.ph < 0 ? { color: 'var(--negative)' } : undefined}>{r ? `${eur(r.ph)} €` : '–'}</dd>
        </div>
        <div className="row">
          <dt>Odhad mojej provízie ({dec(String(pct), 0, 2)} %)</dt>
          <dd>{r ? `${eur(r.commission)} €` : '–'}</dd>
        </div>
      </dl>
      {r && r.ph < 0 && <div className="caption" style={{ color: 'var(--negative)' }}>Cena je pod hranicou – pridaná hodnota je záporná, provízia 0 €. Ponuka by potrebovala schválenie.</div>}
      {kind === 'fix' && b?.basis === 'odhad_portfolia' && (
        <div className="caption">Ako manažér máte pri FIX hranicu odhad portfólia – rovnako ako v ponuke.</div>
      )}
      <div style={{ marginTop: 12 }}>
        <button type="button" className="btn" disabled={!r} onClick={() => setCreating(true)}>
          Vytvoriť obchod s touto cenou
        </button>
      </div>
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
                  <td className="num">{eur(t.value_eur)}</td>
                  <td className="num">{eur(t.weighted_eur)}</td>
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
