// Nastavenia – Cenové parametre (dizajn 29; modul 4, F1a; migrácie 0023, 0024; modul 5 F6: 0047, 0048).
// Otvorí admin, „schvaľuje ceny“ (obchodný riaditeľ) a Nákup (0056). Nová hodnota platí od zvoleného dňa (dnes a neskôr),
// staré ostávajú v histórii. Ceny dňa (BL, PL) načítava Montel po – pi o 7:00 a 13:00; ručné zadanie (BL, PL a cena FVE)
// ostáva ako záloha. Nákupnú cenu portfólia pre rok dodávky zadáva admin a Nákup „platí od“ dňa, aj spätne od 1. 1. 2026 (0056). Chybná cena sa opraví novým záznamom – pôvodný ostane v histórii ako „opravené“ (kto a kedy).
// Pri každom dni zdroj (Montel / ručne, kto a kedy). Admin zmaže ručnú cenu dňa s dôvodom (ďalší beh ju načíta z Montelu)
// a jednorazovo načíta históriu z Montelu od 1. 1. 2026.

import { Fragment, useMemo, useState } from 'react';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { date, dec, EMPTY } from '../../lib/format';
import { useMe } from '../../lib/me';
import { SettingsHead } from './SettingsLayout';

type ParamCode =
  | 'pomer_bl_pct' | 'rizikova_prirazka' | 'nasa_marza' | 'min_aditiv_obchodnik' | 'min_aditiv_manazer'
  | 'min_aditiv_vykup' | 'min_aditiv_vykup_lz' | 'nakup_energopomoc' | 'viwa_aditiv_basic' | 'viwa_aditiv_plus' | 'viwa_aditiv_pro';

type ParamRow = {
  id: string;
  code: ParamCode;
  delivery_year: number | null;
  valid_from: string;
  value: string;
  note: string | null;
  created_at: string;
  changed_by_name: string | null;
  is_future: boolean;
  can_edit: boolean;
};
type TodayRow = {
  id: string;
  delivery_year: number;
  on_date: string;
  bl_eur_mwh: string | null;
  pl_eur_mwh: string | null;
  bl_ratio_pct: string | null;
  mix_eur_mwh: string | null;
  risk_eur_mwh: string | null;
  margin_eur_mwh: string | null;
  trader_price_eur_mwh: string | null;
  portfolio_eur_mwh: string | null;
  spot_fve_eur_mwh: string | null;
  source: string;
  created_at: string;
  changed_by_name: string | null;
};
type HistoryRow = {
  id: string;
  on_date: string;
  delivery_year: number;
  bl_eur_mwh: string | null;
  pl_eur_mwh: string | null;
  portfolio_eur_mwh: string | null;
  spot_fve_eur_mwh: string | null;
  source: string;
  created_at: string;
  changed_by_name: string | null;
  corrected_at: string | null;
  corrected_by_name: string | null;
  is_corrected: boolean;
  removed_reason: string | null;
};
type PortfolioRow = {
  delivery_year: number;
  on_date: string;
  value: string;
  source: string;
  changed_by_name: string | null;
  created_at: string;
  is_current: boolean;
};
type Pricing = {
  org_id: string;
  today: TodayRow[];
  history: HistoryRow[];
  parameters: ParamRow[];
  is_admin: boolean;
  approves_prices: boolean;
  /** Nákup (0056): zadáva nákupnú cenu portfólia */
  purchase: boolean;
  portfolio: PortfolioRow[];
  montel: { started_at: string; result: { ceny?: number; spot?: number }; errors: number } | null;
  spot: { on_date: string; avg_ytd_eur_mwh: string } | null;
};

/** Parametre v poradí obrazovky 29; adminOnly = mení iba admin (zadanie modulu 4, časť 6). */
const PARAMS: { code: ParamCode; label: string; adminOnly?: boolean; perYear?: boolean }[] = [
  { code: 'pomer_bl_pct', label: 'Pomer BL / PL' },
  { code: 'rizikova_prirazka', label: 'Riziková prirážka (odchýlka)' },
  { code: 'nasa_marza', label: 'Naša marža v cene pre obchodníka' },
  { code: 'min_aditiv_obchodnik', label: 'Minimálny aditív – obchodník' },
  { code: 'min_aditiv_manazer', label: 'Minimálny aditív – manažér' },
  { code: 'min_aditiv_vykup', label: 'Minimálny aditív – výkup', adminOnly: true },
  { code: 'min_aditiv_vykup_lz', label: 'Minimálny aditív – výkup lokálny zdroj', adminOnly: true },
  { code: 'nakup_energopomoc', label: 'Nákupná cena domácností s energopomocou', adminOnly: true, perYear: true },
  { code: 'viwa_aditiv_basic', label: 'Odhad aditívu VIWA Basic' },
  { code: 'viwa_aditiv_plus', label: 'Odhad aditívu VIWA Plus' },
  { code: 'viwa_aditiv_pro', label: 'Odhad aditívu VIWA Pro' },
];
const LABEL = Object.fromEntries(PARAMS.map((p) => [p.code, p.label])) as Record<ParamCode, string>;

const todayIso = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Bratislava' });

function valueText(code: ParamCode, v: string): string {
  if (code === 'pomer_bl_pct') return `${dec(v, 0, 2)} / ${dec(String(100 - Number(v)), 0, 2)}`;
  return `${dec(v, 2, 4)} €/MWh`;
}

function dateTime(v: string | null): string {
  if (!v) return EMPTY;
  const dt = new Date(v);
  return `${date(v)} ${dt.toLocaleTimeString('sk-SK', { timeZone: 'Europe/Bratislava', hour: '2-digit', minute: '2-digit' })}`;
}

/** Zdroj ceny dňa: Montel (denný beh / história) alebo ručne s menom a časom zadania. */
function sourceText(r: { source: string; changed_by_name: string | null; created_at: string }): string {
  if (r.source === 'cockpit') return `Montel · ${dateTime(r.created_at)}`;
  if (r.source === 'historia') return 'Montel (história)';
  return `Ručne · ${r.changed_by_name ?? EMPTY} · ${dateTime(r.created_at)}`;
}

type Panel =
  | { kind: 'param'; code?: ParamCode; year?: number }
  | { kind: 'edit'; row: ParamRow }
  | { kind: 'price'; correct?: TodayRow }
  | { kind: 'remove'; row: { id: string; on_date: string; delivery_year: number } }
  | { kind: 'history' }
  | { kind: 'portfolio'; year?: number }
  | null;

export function PricingPage() {
  const data = useApi<Pricing>('/api/pricing');
  const me = useMe();
  const [panel, setPanel] = useState<Panel>(null);
  const [open, setOpen] = useState<string | null>(null);
  const montelSave = useSave();
  const [montelResult, setMontelResult] = useState<{ ceny: number; spot: number; chyby: number } | null>(null);
  const montelToday = () =>
    montelSave.run(async () => {
      setMontelResult(await send<{ ceny: number; spot: number; chyby: number }>('POST', '/api/pricing/montel-today', {}));
      data.reload();
    });

  // Riadky tabuľky: parameter (energopomoc po rokoch dodávky) – platná hodnota, naplánovaná zmena, história
  const rows = useMemo(() => {
    const list = data.data?.parameters ?? [];
    const out: { key: string; code: ParamCode; year: number | null; current?: ParamRow; planned: ParamRow[]; all: ParamRow[] }[] = [];
    for (const p of PARAMS) {
      const years = p.perYear
        ? [...new Set(list.filter((r) => r.code === p.code).map((r) => r.delivery_year as number))].sort()
        : [null];
      for (const y of years.length ? years : [null]) {
        const all = list.filter((r) => r.code === p.code && r.delivery_year === y);
        out.push({
          key: `${p.code}:${y ?? ''}`,
          code: p.code,
          year: y,
          current: all.find((r) => !r.is_future),
          planned: all.filter((r) => r.is_future).sort((a, b) => a.valid_from.localeCompare(b.valid_from)),
          all,
        });
      }
    }
    return out;
  }, [data.data]);

  if (data.error) return <ErrorState error={data.error} />;
  const d = data.data;
  const isAdmin = !!d?.is_admin;

  return (
    <>
      <SettingsHead
        title="Cenové parametre"
        sub="hranice a vzorec ceny pre obchodníka"
        actions={
          d && (d.is_admin || d.approves_prices) ? (
            <button type="button" className="btn primary" onClick={() => setPanel({ kind: 'param' })}>
              Zmeniť parameter
            </button>
          ) : undefined
        }
      />
      {!d ? (
        <Skeleton lines={6} />
      ) : (
        <>
          <section className="card" aria-label="Parametre">
            <div className="table-wrap">
              <table className="tbl">
                <thead>
                  <tr>
                    <th>Parameter</th>
                    <th className="num">Hodnota</th>
                    <th>Platí od</th>
                    <th>Zmenil</th>
                    <th>Naplánované</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {rows.map((r) => (
                    <Fragment key={r.key}>
                      <tr>
                        <td className="strong">
                          {LABEL[r.code]}
                          {r.year !== null && ` – ${r.year}`}
                        </td>
                        <td className="num">{r.current ? valueText(r.code, r.current.value) : EMPTY}</td>
                        <td className="muted">{r.current ? date(r.current.valid_from) : EMPTY}</td>
                        <td>{r.current?.changed_by_name ?? (r.current ? 'východisková hodnota' : EMPTY)}</td>
                        <td>
                          {r.planned.map((p) => (
                            <div key={p.id}>
                              <Pill tone="info">
                                od {date(p.valid_from)}: {valueText(r.code, p.value)}
                              </Pill>{' '}
                              {p.can_edit && (
                                <button type="button" className="link-button" onClick={() => setPanel({ kind: 'edit', row: p })}>
                                  Upraviť
                                </button>
                              )}
                            </div>
                          ))}
                        </td>
                        <td>
                          <button type="button" className="link-button" onClick={() => setOpen(open === r.key ? null : r.key)}>
                            {open === r.key ? 'Skryť históriu' : 'História'}
                          </button>
                        </td>
                      </tr>
                      {open === r.key &&
                        r.all.map((h) => (
                          <tr key={h.id} className="sub-row">
                            <td className="caption">{h.note ?? ''}</td>
                            <td className="num caption">{valueText(r.code, h.value)}</td>
                            <td className="caption">{date(h.valid_from)}</td>
                            <td className="caption">{h.changed_by_name ?? 'východisková hodnota'}</td>
                            <td className="caption">zadané {dateTime(h.created_at)}</td>
                            <td />
                          </tr>
                        ))}
                    </Fragment>
                  ))}
                </tbody>
              </table>
            </div>
            <div className="card-foot caption">
              Mení admin a obchodný riaditeľ (minimálne aditívy výkupu a nákupnú cenu energopomoci iba admin; minimálny aditív pri konkrétnej výkupnej zmluve prepíše Nákup na karte zmluvy).
              Nová hodnota platí od zvoleného dňa (dnes a neskôr), staré ostávajú v histórii a zmluvy si pamätajú hodnotu ku
              dňu podpisu. Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor.
            </div>
          </section>

          <section className="card" aria-label="Cena pre obchodníka">
            <div className="card-head">
              <h2 className="t-section-title">Cena pre obchodníka dnes</h2>
              <span className="caption">
                ceny dňa z Montelu po – pi o 7:00 a 13:00
                {d.montel && (
                  <>
                    {' · '}posledné načítanie {dateTime(d.montel.started_at)}{' '}
                    {d.montel.errors > 0 ? <Pill tone="negative">chyba</Pill> : <Pill tone="positive">v poriadku</Pill>}
                  </>
                )}
              </span>
              <span className="grow" />
              {isAdmin && (
                <button type="button" className="btn" disabled={montelSave.busy} onClick={montelToday}>
                  {montelSave.busy ? 'Načítavam…' : 'Načítať dnešné ceny z Montelu'}
                </button>
              )}
              {isAdmin && (
                <button type="button" className="btn" onClick={() => setPanel({ kind: 'history' })}>
                  Načítať históriu z Montelu
                </button>
              )}
              {(d.is_admin || d.approves_prices) && (
                <button type="button" className="btn" onClick={() => setPanel({ kind: 'price' })}>
                  Zadať ceny dňa ručne
                </button>
              )}
            </div>
            {montelSave.error && <Notice tone="error">{montelSave.error}</Notice>}
            {montelResult && (
              <Notice tone={montelResult.chyby > 0 ? 'error' : 'ok'}>
                Načítané z Montelu: ceny rokov dodávky {montelResult.ceny}, priemer SPOT {montelResult.spot ? 'áno' : 'nie (bez zmeny alebo chýba)'}
                {montelResult.chyby > 0 ? `, chyby ${montelResult.chyby} – podrobnosti v Nastaveniach → Nočný beh` : ''}.
              </Notice>
            )}
            <div className="table-wrap">
              <table className="tbl">
                <thead>
                  <tr>
                    <th>Rok dodávky</th>
                    <th>Ceny z dňa</th>
                    <th className="num">BL</th>
                    <th className="num">PL</th>
                    <th className="num">Mix</th>
                    <th className="num">+ riziko + marža</th>
                    <th className="num">Cena pre obchodníka</th>
                    <th className="num">Nákupná cena portfólia</th>
                    <th className="num">SPOT FVE</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {d.today.map((t) => (
                    <tr key={t.id}>
                      <td>{t.delivery_year}</td>
                      <td>
                        <span className="muted">{date(t.on_date)}</span>
                        <div className="sub">{sourceText(t)}</div>
                      </td>
                      <td className="num">{dec(t.bl_eur_mwh, 2, 4)}</td>
                      <td className="num">{dec(t.pl_eur_mwh, 2, 4)}</td>
                      <td className="num">
                        {dec(t.mix_eur_mwh, 2, 4)}
                        {t.bl_ratio_pct && <span className="caption"> ({dec(t.bl_ratio_pct, 0, 2)}/{dec(String(100 - Number(t.bl_ratio_pct)), 0, 2)})</span>}
                      </td>
                      <td className="num">
                        {t.risk_eur_mwh && t.margin_eur_mwh ? `+ ${dec(String(Number(t.risk_eur_mwh) + Number(t.margin_eur_mwh)), 2, 4)}` : EMPTY}
                      </td>
                      <td className="num strong">{t.trader_price_eur_mwh ? `${dec(t.trader_price_eur_mwh, 2, 4)} €/MWh` : EMPTY}</td>
                      <td className="num">{dec(t.portfolio_eur_mwh, 2, 4)}</td>
                      <td className="num">{dec(t.spot_fve_eur_mwh, 2, 4)}</td>
                      <td>
                        {t.on_date === todayIso() && (
                          <button type="button" className="link-button" onClick={() => setPanel({ kind: 'price', correct: t })}>
                            Opraviť
                          </button>
                        )}
                        {isAdmin && t.source === 'rucne' && (
                          <button type="button" className="link-button" style={{ marginLeft: 8 }} onClick={() => setPanel({ kind: 'remove', row: t })}>
                            Zmazať
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                  {d.today.length === 0 && (
                    <tr>
                      <td colSpan={10} className="muted">
                        Zatiaľ nie sú ceny dňa. Cena pre obchodníka sa vypočíta po načítaní BL a PL z Montelu alebo po ručnom zadaní.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            <div className="card-foot caption">
              Cena pre obchodníka = (BL × pomer + PL × zvyšok) / 100 + riziková prirážka + naša marža. Ak ceny z dnešného dňa
              chýbajú, použijú sa posledné najviac 7 dní staré. Opravená cena platí od opravy; pôvodný záznam ostane v histórii.
              Ručne zadaná cena dňa sa načítaním z Montelu neprepíše; ak ju admin zmaže, ďalší beh deň načíta z Montelu.
              {d.spot && (
                <>
                  {' '}Priemerná SPOT cena od 1. 1. {d.spot.on_date.slice(0, 4)} do {date(d.spot.on_date)}: <strong>{dec(d.spot.avg_ytd_eur_mwh, 2, 2)} €/MWh</strong>.
                </>
              )}
            </div>
          </section>

          <PortfolioSection d={d} onAdd={(year) => setPanel({ kind: 'portfolio', year })} />

          <section className="card" aria-label="Ceny dňa za 60 dní">
            <div className="card-head">
              <h2 className="t-section-title">Ceny dňa – história</h2>
              <span className="caption">posledných 60 dní: zdroj, opravy a zmazania</span>
            </div>
            <div className="table-wrap" style={{ maxHeight: 480, overflowY: 'auto' }}>
              <table className="tbl">
                <thead>
                  <tr>
                    <th>Deň</th>
                    <th>Rok dodávky</th>
                    <th className="num">BL</th>
                    <th className="num">PL</th>
                    <th className="num">Nákupná cena portfólia</th>
                    <th>Zdroj</th>
                    <th>Stav</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {d.history.map((h) => (
                    <tr key={h.id} className={h.is_corrected ? 'muted' : undefined}>
                      <td>{date(h.on_date)}</td>
                      <td>{h.delivery_year}</td>
                      <td className="num">{dec(h.bl_eur_mwh, 2, 4)}</td>
                      <td className="num">{dec(h.pl_eur_mwh, 2, 4)}</td>
                      <td className="num">{dec(h.portfolio_eur_mwh, 2, 4)}</td>
                      <td className="caption">{sourceText(h)}</td>
                      <td className="caption">
                        {h.removed_reason ? (
                          <>
                            <Pill tone="negative">zmazané</Pill>
                            <div className="sub">{h.corrected_by_name ?? EMPTY} · {dateTime(h.corrected_at)}</div>
                            <div className="sub">{h.removed_reason}</div>
                          </>
                        ) : h.is_corrected ? (
                          <>
                            <Pill tone="warning">opravené</Pill>
                            <div className="sub">{h.corrected_by_name ?? 'Montel'} · {dateTime(h.corrected_at)}</div>
                          </>
                        ) : (
                          <Pill tone="positive">platná</Pill>
                        )}
                      </td>
                      <td>
                        {isAdmin && !h.is_corrected && h.source === 'rucne' && (
                          <button type="button" className="link-button" onClick={() => setPanel({ kind: 'remove', row: h })}>
                            Zmazať
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                  {d.history.length === 0 && (
                    <tr>
                      <td colSpan={8} className="muted">Za posledných 60 dní nie sú žiadne ceny dňa.</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        </>
      )}

      {panel?.kind === 'param' && d && (
        <ParamPanel
          orgId={d.org_id}
          isAdmin={me.is_admin}
          onClose={() => setPanel(null)}
          onSaved={() => {
            setPanel(null);
            data.reload();
          }}
        />
      )}
      {panel?.kind === 'edit' && (
        <EditPanel
          row={panel.row}
          onClose={() => setPanel(null)}
          onSaved={() => {
            setPanel(null);
            data.reload();
          }}
        />
      )}
      {panel?.kind === 'remove' && (
        <RemovePanel
          row={panel.row}
          onClose={() => setPanel(null)}
          onSaved={() => {
            setPanel(null);
            data.reload();
          }}
        />
      )}
      {panel?.kind === 'history' && (
        <HistoryPanel
          onClose={() => setPanel(null)}
          onSaved={() => data.reload()}
        />
      )}
      {panel?.kind === 'portfolio' && d && (
        <PortfolioPanel orgId={d.org_id} year={panel.year} onClose={() => setPanel(null)} onSaved={() => data.reload()} />
      )}
      {panel?.kind === 'price' && d && (
        <PricePanel
          orgId={d.org_id}
          correct={panel.correct}
          onClose={() => setPanel(null)}
          onSaved={() => {
            setPanel(null);
            data.reload();
          }}
        />
      )}
    </>
  );
}

function ParamPanel(props: { orgId: string; isAdmin: boolean; onClose: () => void; onSaved: () => void }) {
  const [code, setCode] = useState<ParamCode | ''>('');
  const [year, setYear] = useState(String(new Date().getFullYear() + 1));
  const [value, setValue] = useState('');
  const [validFrom, setValidFrom] = useState(todayIso());
  const [note, setNote] = useState('');
  const save = useSave();
  const meta = PARAMS.find((p) => p.code === code);

  const submit = async () => {
    const ok = await save.run(() =>
      send('POST', '/api/pricing/parameters', {
        org_id: props.orgId,
        code,
        delivery_year: meta?.perYear ? year : undefined,
        valid_from: validFrom,
        value,
        note,
      }),
    );
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title="Zmeniť parameter"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !code} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Parameter" wide>
          <Select
            value={code}
            onChange={(v) => setCode(v as ParamCode)}
            placeholder="Vybrať parameter"
            options={PARAMS.filter((p) => props.isAdmin || !p.adminOnly).map((p) => ({ value: p.code, label: p.label }))}
          />
        </Field>
        {meta?.perYear && (
          <Field label="Rok dodávky">
            <TextInput value={year} onChange={setYear} maxLength={4} />
          </Field>
        )}
        <Field label={code === 'pomer_bl_pct' ? 'Podiel BL [%]' : 'Hodnota [€/MWh]'} hint={code === 'pomer_bl_pct' ? 'PL = 100 − BL' : undefined}>
          <TextInput value={value} onChange={setValue} maxLength={20} />
        </Field>
        <Field label="Platí od" hint="dnes alebo neskôr">
          <TextInput type="date" value={validFrom} onChange={setValidFrom} />
        </Field>
        <Field label="Poznámka" wide>
          <TextInput value={note} onChange={setNote} maxLength={300} />
        </Field>
      </div>
      {!props.isAdmin && (
        <p className="caption">Minimálny aditív výkupu lokálneho zdroja a nákupnú cenu energopomoci mení iba admin.</p>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function EditPanel(props: { row: ParamRow; onClose: () => void; onSaved: () => void }) {
  const r = props.row;
  const [value, setValue] = useState(dec(r.value, 0, 4).replace(/ /g, ''));
  const [validFrom, setValidFrom] = useState(r.valid_from);
  const [note, setNote] = useState(r.note ?? '');
  const save = useSave();

  const submit = async () => {
    const ok = await save.run(() => send('PATCH', `/api/pricing/parameters/${r.id}`, { value, valid_from: validFrom, note }));
    if (ok) props.onSaved();
  };
  const cancel = async () => {
    const ok = await save.run(() => send('DELETE', `/api/pricing/parameters/${r.id}`));
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title={`Naplánovaná zmena – ${LABEL[r.code]}`}
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn btn-danger" disabled={save.busy} onClick={cancel}>
            Zrušiť zmenu
          </button>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zavrieť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label={r.code === 'pomer_bl_pct' ? 'Podiel BL [%]' : 'Hodnota [€/MWh]'}>
          <TextInput value={value} onChange={setValue} maxLength={20} />
        </Field>
        <Field label="Platí od" hint="dnes alebo neskôr">
          <TextInput type="date" value={validFrom} onChange={setValidFrom} />
        </Field>
        <Field label="Poznámka" wide>
          <TextInput value={note} onChange={setNote} maxLength={300} />
        </Field>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function PricePanel(props: { orgId: string; correct?: TodayRow; onClose: () => void; onSaved: () => void }) {
  const c = props.correct;
  const plain = (v: string | null | undefined) => (v ? dec(v, 0, 4).replace(/ /g, '') : '');
  const [year, setYear] = useState(String(c?.delivery_year ?? new Date().getFullYear() + 1));
  const [bl, setBl] = useState(plain(c?.bl_eur_mwh));
  const [pl, setPl] = useState(plain(c?.pl_eur_mwh));
  const [spotFve, setSpotFve] = useState(plain(c?.spot_fve_eur_mwh));
  const save = useSave();

  const submit = async () => {
    const ok = await save.run(() =>
      send('POST', '/api/pricing/market-prices', {
        org_id: props.orgId,
        delivery_year: year,
        bl_eur_mwh: bl,
        pl_eur_mwh: pl,
        spot_fve_eur_mwh: spotFve,
      }),
    );
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title={c ? `Opraviť ceny dňa – ${c.delivery_year}` : 'Zadať ceny dňa'}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            {c ? 'Uložiť opravu' : 'Uložiť'}
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Rok dodávky (CAL)">
          <TextInput value={year} onChange={setYear} maxLength={4} disabled={!!c} />
        </Field>
        <Field label="Deň">
          <TextInput value={date(todayIso())} onChange={() => undefined} disabled />
        </Field>
        <Field label="BL [€/MWh]">
          <TextInput value={bl} onChange={setBl} maxLength={20} />
        </Field>
        <Field label="PL [€/MWh]">
          <TextInput value={pl} onChange={setPl} maxLength={20} />
        </Field>
        <Field label="Očakávaná cena SPOT pre FVE [€/MWh]">
          <TextInput value={spotFve} onChange={setSpotFve} maxLength={20} />
        </Field>
      </div>
      {c && (
        <Notice tone="ok">
          Oprava sa uloží ako nový záznam a platí hneď. Pôvodné ceny ostanú v histórii označené „opravené“ s vaším menom a časom.
        </Notice>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

/** Zmazanie ručne zadanej ceny dňa (admin, s dôvodom; 0048). */
function RemovePanel(props: { row: { id: string; on_date: string; delivery_year: number }; onClose: () => void; onSaved: () => void }) {
  const [reason, setReason] = useState('');
  const save = useSave();
  const submit = async () => {
    const ok = await save.run(() => send('POST', `/api/pricing/market-prices/${props.row.id}/remove`, { reason }));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Zmazať ručnú cenu – ${date(props.row.on_date)} · ${props.row.delivery_year}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || reason.trim().length < 3} onClick={submit}>
            Zmazať
          </button>
        </>
      }
    >
      <p>
        Ručne zadaná cena dňa sa zmaže a ostane v histórii ako „zmazané“ s vaším menom, časom a dôvodom (aj v audite). Deň
        potom nemá platnú cenu tohto roka – ďalší beh (po – pi o 7:00 a 13:00) ju načíta z Montelu. Dovtedy sa pre cenu pre
        obchodníka použije posledná cena najviac 7 dní stará.
      </p>
      <Field label="Dôvod zmazania">
        <TextInput value={reason} onChange={setReason} maxLength={500} />
      </Field>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

/** Jednorazové načítanie histórie cien z Montelu od 1. 1. 2026 (admin; dni s cenou sa nemenia). */
function HistoryPanel(props: { onClose: () => void; onSaved: () => void }) {
  const save = useSave();
  const [result, setResult] = useState<{ dni: number; riadky: number } | null>(null);
  const submit = () =>
    save.run(async () => {
      const r = await send<{ dni: number; riadky: number }>('POST', '/api/pricing/market-history', {});
      setResult(r);
      props.onSaved();
    });
  return (
    <SidePanel
      title="Načítať históriu z Montelu"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            {result ? 'Zavrieť' : 'Zrušiť'}
          </button>
          {!result && (
            <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
              {save.busy ? 'Načítavam…' : 'Načítať'}
            </button>
          )}
        </>
      }
    >
      <p>
        Načíta BL a PL ročných produktov (settlement) po dňoch od 1. 1. 2026 do dnes. Settlement obchodného dňa je cenou
        nasledujúceho dňa – rovnako ako pri dennom načítaní ráno. Dni, ktoré už cenu majú (z Montelu aj ručne zadané), sa
        nemenia, takže načítanie môžete bezpečne zopakovať. Do CRM sa ukladajú iba ceny, nie odpovede Montelu.
      </p>
      {result && (
        <Notice tone="ok">
          Hotovo: {result.dni} dní, doplnených {result.riadky} cien (rok dodávky × deň).
        </Notice>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

/** Nákupná cena portfólia po rokoch dodávky (0056): platná dnes a dni zmien; zadáva admin a Nákup. */
function PortfolioSection(props: { d: Pricing; onAdd: (year?: number) => void }) {
  const { d } = props;
  const canEdit = d.is_admin || d.purchase;
  const years = [...new Set(d.portfolio.map((r) => r.delivery_year))].sort();
  const [open, setOpen] = useState<number | null>(null);
  return (
    <section className="card" aria-label="Nákupná cena portfólia">
      <div className="card-head">
        <h2 className="t-section-title">Nákupná cena portfólia</h2>
        <span className="caption">pre rok dodávky, platí od dňa po ďalšiu zmenu</span>
        <span className="grow" />
        {canEdit && (
          <button type="button" className="btn" onClick={() => props.onAdd()}>
            Nákupná cena portfólia – zadať pre obdobie
          </button>
        )}
      </div>
      <div className="table-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th>Rok dodávky</th>
              <th className="num">Platná cena [€/MWh]</th>
              <th>Platí od</th>
              <th>Zadal</th>
              <th aria-label="Akcie" />
            </tr>
          </thead>
          <tbody>
            {years.length === 0 && (
              <tr>
                <td colSpan={5} className="muted">Nákupná cena portfólia ešte nie je zadaná.</td>
              </tr>
            )}
            {years.map((y) => {
              const rows = d.portfolio.filter((r) => r.delivery_year === y);
              const cur = rows.find((r) => r.is_current) ?? rows[0];
              return (
                <Fragment key={y}>
                  <tr>
                    <td>{y}</td>
                    <td className="num">{dec(cur.value, 2, 4)}</td>
                    <td>{date(cur.on_date)}</td>
                    <td>{cur.changed_by_name ?? (cur.source === 'rucne' ? EMPTY : 'prenesené z predošlého dňa')}</td>
                    <td>
                      {rows.length > 1 && (
                        <button type="button" className="link-button" onClick={() => setOpen(open === y ? null : y)}>
                          {open === y ? 'skryť zmeny' : `zmeny (${rows.length})`}
                        </button>
                      )}
                      {canEdit && (
                        <button type="button" className="link-button" style={{ marginLeft: 8 }} onClick={() => props.onAdd(y)}>
                          Zadať
                        </button>
                      )}
                    </td>
                  </tr>
                  {open === y &&
                    rows.map((r) => (
                      <tr key={`${y}-${r.on_date}`} className="muted">
                        <td />
                        <td className="num">{dec(r.value, 2, 4)}</td>
                        <td>od {date(r.on_date)}</td>
                        <td>{r.changed_by_name ?? EMPTY}</td>
                        <td>{r.on_date > todayIso() ? 'budúca' : r.is_current ? 'platí dnes' : ''}</td>
                      </tr>
                    ))}
                </Fragment>
              );
            })}
          </tbody>
        </table>
      </div>
      <div className="card-foot caption">
        Marža firmy sa na všetkých zmluvách a obchodoch počíta s poslednou platnou cenou pre rok dodávky. Pridaná hodnota, uplatnené
        provízie a ponuky spárované so zmluvou sa nemenia. Pri zadaní spätného dňa sa zmluvám podpísaným od tohto dňa doplní chýbajúca
        cena v snímke ku dňu podpisu. Zadáva admin a Nákup.
      </div>
    </section>
  );
}

function PortfolioPanel(props: { orgId: string; year?: number; onClose: () => void; onSaved: () => void }) {
  const [onDate, setOnDate] = useState(todayIso());
  const [year, setYear] = useState(String(props.year ?? new Date().getFullYear()));
  const [value, setValue] = useState('');
  const [result, setResult] = useState<{ zmena: boolean; zmluvy_doplnene?: number; plati_do?: string | null } | null>(null);
  const save = useSave();
  const submit = async () => {
    await save.run(async () => {
      const r = await send<{ zmena: boolean; zmluvy_doplnene?: number; plati_do?: string | null }>('POST', '/api/pricing/portfolio', {
        org_id: props.orgId, on_date: onDate, delivery_year: year, value,
      });
      setResult(r);
      props.onSaved();
    });
  };
  return (
    <SidePanel
      title="Nákupná cena portfólia – zadať pre obdobie"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            {result ? 'Zavrieť' : 'Zrušiť'}
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !value.trim() || !onDate} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Platí od (deň)">
          <input className="inp" type="date" min="2026-01-01" max={todayIso()} value={onDate} onChange={(e) => { setOnDate(e.target.value); setResult(null); }} />
        </Field>
        <Field label="Rok dodávky (CAL)">
          <TextInput value={year} onChange={(v) => { setYear(v); setResult(null); }} maxLength={4} />
        </Field>
        <Field label="Nákupná cena portfólia [€/MWh]">
          <TextInput value={value} onChange={(v) => { setValue(v); setResult(null); }} maxLength={20} />
        </Field>
      </div>
      <p className="caption">
        Cena platí od zvoleného dňa po ďalší deň s vlastnou cenou (dnes alebo spätne od 1. 1. 2026). BL a PL toho dňa ostanú, pôvodný záznam
        ostane v histórii ako opravený. Marža sa prepočíta na všetkých zmluvách a obchodoch; zmluvám podpísaným od tohto dňa bez ceny sa
        doplní snímka ku dňu podpisu.
      </p>
      {result && (
        <Notice tone="ok">
          {result.zmena
            ? `Uložené. Platí ${result.plati_do ? `do ${date(result.plati_do)}` : 'do ďalšej zmeny'}; doplnené snímky zmlúv: ${result.zmluvy_doplnene ?? 0}.`
            : 'Cena v tento deň je už rovnaká – nič sa nezmenilo.'}
        </Notice>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
