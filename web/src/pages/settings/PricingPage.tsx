// Nastavenia – Cenové parametre (dizajn 29; modul 4, F1a; migrácie 0023, 0024).
// Otvorí admin alebo „schvaľuje ceny“ (obchodný riaditeľ). Nová hodnota platí od zvoleného dňa (dnes a neskôr),
// staré ostávajú v histórii. Ceny dňa (BL, PL, odhad portfólia, cena FVE) sa zadávajú ručne, kým nebude API Cockpitu;
// chybná cena sa opraví novým záznamom – pôvodný ostane v histórii ako „opravené“ (kto a kedy).

import { Fragment, useMemo, useState } from 'react';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { date, dec, EMPTY } from '../../lib/format';
import { useMe } from '../../lib/me';
import { SettingsHead } from './SettingsLayout';

type ParamCode =
  | 'pomer_bl_pct' | 'rizikova_prirazka' | 'nasa_marza' | 'min_aditiv_obchodnik' | 'min_aditiv_manazer'
  | 'min_aditiv_vykup_lz' | 'nakup_energopomoc' | 'viwa_aditiv_basic' | 'viwa_aditiv_plus' | 'viwa_aditiv_pro';

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
};
type Pricing = {
  org_id: string;
  today: TodayRow[];
  history: HistoryRow[];
  parameters: ParamRow[];
  is_admin: boolean;
  approves_prices: boolean;
};

/** Parametre v poradí obrazovky 29; adminOnly = mení iba admin (zadanie modulu 4, časť 6). */
const PARAMS: { code: ParamCode; label: string; adminOnly?: boolean; perYear?: boolean }[] = [
  { code: 'pomer_bl_pct', label: 'Pomer BL / PL' },
  { code: 'rizikova_prirazka', label: 'Riziková prirážka (odchýlka)' },
  { code: 'nasa_marza', label: 'Naša marža v cene pre obchodníka' },
  { code: 'min_aditiv_obchodnik', label: 'Minimálny aditív – obchodník' },
  { code: 'min_aditiv_manazer', label: 'Minimálny aditív – manažér' },
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

type Panel =
  | { kind: 'param'; code?: ParamCode; year?: number }
  | { kind: 'edit'; row: ParamRow }
  | { kind: 'price'; correct?: TodayRow }
  | null;

export function PricingPage() {
  const data = useApi<Pricing>('/api/pricing');
  const me = useMe();
  const [panel, setPanel] = useState<Panel>(null);
  const [open, setOpen] = useState<string | null>(null);

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
  const corrected = d?.history.filter((h) => h.is_corrected) ?? [];

  return (
    <>
      <SettingsHead
        title="Cenové parametre"
        sub="hranice a vzorec ceny pre obchodníka"
        actions={
          <button type="button" className="btn primary" onClick={() => setPanel({ kind: 'param' })}>
            Zmeniť parameter
          </button>
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
              Mení admin a obchodný riaditeľ (minimálny aditív výkupu lokálneho zdroja a nákupnú cenu energopomoci iba admin).
              Nová hodnota platí od zvoleného dňa (dnes a neskôr), staré ostávajú v histórii a zmluvy si pamätajú hodnotu ku
              dňu podpisu. Naplánovanú zmenu môže opraviť alebo zrušiť iba jej autor.
            </div>
          </section>

          <section className="card" aria-label="Cena pre obchodníka">
            <div className="card-head">
              <h2 className="t-section-title">Cena pre obchodníka dnes</h2>
              <span className="caption">ceny dňa zadané ručne, kým nebude napojenie na Cockpit</span>
              <span className="grow" />
              <button type="button" className="btn" onClick={() => setPanel({ kind: 'price' })}>
                Zadať ceny dňa
              </button>
            </div>
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
                    <th className="num">Odhad portfólia</th>
                    <th className="num">SPOT FVE</th>
                    <th />
                  </tr>
                </thead>
                <tbody>
                  {d.today.map((t) => (
                    <tr key={t.id}>
                      <td>{t.delivery_year}</td>
                      <td className="muted">{date(t.on_date)}</td>
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
                      </td>
                    </tr>
                  ))}
                  {d.today.length === 0 && (
                    <tr>
                      <td colSpan={10} className="muted">
                        Zatiaľ nie sú zadané ceny dňa. Cena pre obchodníka sa vypočíta po zadaní BL a PL.
                      </td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
            <div className="card-foot caption">
              Cena pre obchodníka = (BL × pomer + PL × zvyšok) / 100 + riziková prirážka + naša marža. Ak ceny z dnešného dňa
              chýbajú, použijú sa posledné najviac 7 dní staré. Opravená cena platí od opravy; pôvodný záznam ostane v histórii.
            </div>
          </section>

          {corrected.length > 0 && (
            <section className="card" aria-label="Opravené ceny dňa">
              <div className="card-head">
                <h2 className="t-section-title">Opravené ceny dňa</h2>
                <span className="caption">posledných 60 dní</span>
              </div>
              <div className="table-wrap">
                <table className="tbl">
                  <thead>
                    <tr>
                      <th>Deň</th>
                      <th>Rok dodávky</th>
                      <th className="num">BL</th>
                      <th className="num">PL</th>
                      <th className="num">Odhad portfólia</th>
                      <th>Zadal</th>
                      <th>Opravil</th>
                    </tr>
                  </thead>
                  <tbody>
                    {corrected.map((h) => (
                      <tr key={h.id}>
                        <td>{date(h.on_date)}</td>
                        <td>{h.delivery_year}</td>
                        <td className="num">{dec(h.bl_eur_mwh, 2, 4)}</td>
                        <td className="num">{dec(h.pl_eur_mwh, 2, 4)}</td>
                        <td className="num">{dec(h.portfolio_eur_mwh, 2, 4)}</td>
                        <td>
                          {h.changed_by_name ?? (h.source === 'historia' ? 'história' : EMPTY)} · {dateTime(h.created_at)}
                        </td>
                        <td>
                          <Pill tone="warning">opravené</Pill> {h.corrected_by_name ?? EMPTY} · {dateTime(h.corrected_at)}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </section>
          )}
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
  const [portfolio, setPortfolio] = useState(plain(c?.portfolio_eur_mwh));
  const [spotFve, setSpotFve] = useState(plain(c?.spot_fve_eur_mwh));
  const save = useSave();

  const submit = async () => {
    const ok = await save.run(() =>
      send('POST', '/api/pricing/market-prices', {
        org_id: props.orgId,
        delivery_year: year,
        bl_eur_mwh: bl,
        pl_eur_mwh: pl,
        portfolio_eur_mwh: portfolio,
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
        <Field label="Odhad nákupnej ceny portfólia [€/MWh]">
          <TextInput value={portfolio} onChange={setPortfolio} maxLength={20} />
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
