// Modul 3 F2 – úpravy cenníkov adminom (obrazovky 20, 21): panely a úprava cien návrhu.
// Pravidlá stráži databáza; web ich vysvetľuje vopred. Ceny s DPH web nepočíta – pri zmenenom riadku ukáže
// „po uložení“ a po uložení ich dostane z databázy. Súbežná úprava: posiela updated_at návrhu (409 → obnoviť).

import { useState } from 'react';
import { ApiError, send, useApi, type ApprovePreview, type PriceListDetail, type PriceListItem, type PriceListVersion } from '../lib/api';
import { date, dec, EMPTY } from '../lib/format';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';

const todayIso = () => new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Bratislava' }).format(new Date());
/** Predvolená účinnosť novej verzie: 1. 1. nasledujúceho roka (Peter, F2 odpoveď 3). */
export const nextYear = () => `${Number(todayIso().slice(0, 4)) + 1}-01-01`;

function Footer(props: { busy: boolean; onClose: () => void; onSave: () => void; label: string; danger?: boolean; disabled?: boolean }) {
  return (
    <>
      <button type="button" className="btn" onClick={props.onClose}>
        Zrušiť
      </button>
      <button
        type="button"
        className={props.danger ? 'btn btn-danger' : 'btn primary'}
        disabled={props.busy || props.disabled}
        onClick={props.onSave}
      >
        {props.busy ? 'Ukladám…' : props.label}
      </button>
    </>
  );
}

export function NewPriceListPanel(props: { onClose: () => void; onCreated: (id: string) => void }) {
  const [name, setName] = useState('');
  const [segment, setSegment] = useState<'domacnost' | 'firma' | ''>('');
  const [description, setDescription] = useState('');
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      const r = await send<{ id: string }>('POST', '/api/price-lists', { name, segment, description });
      props.onCreated(r.id);
    });
  return (
    <SidePanel title="Nový cenník" onClose={props.onClose} footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Založiť" disabled={!name.trim() || !segment} />}>
      {error && <Notice tone="error">{error}</Notice>}
      <Field label="Názov" hint="bez roka – rok patrí verzii (napr. Domácnosti – NIE Energopomoc)">
        <TextInput value={name} onChange={setName} maxLength={120} autoFocus />
      </Field>
      <Field label="Segment">
        <Select value={segment} onChange={setSegment} placeholder="Vyberte" options={[{ value: 'domacnost', label: 'Domácnosť' }, { value: 'firma', label: 'Firma' }]} />
      </Field>
      <Field label="Popis">
        <TextInput value={description} onChange={setDescription} maxLength={300} />
      </Field>
    </SidePanel>
  );
}

/** Prvá (prázdna) verzia alebo kópia vybranej verzie. */
export function NewVersionPanel(props: { listId: string; from?: PriceListVersion; onClose: () => void; onDone: (id: string, skipped: string[]) => void }) {
  const [name, setName] = useState(nextYear().slice(0, 4));
  const [validFrom, setValidFrom] = useState(nextYear());
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      const r = props.from
        ? await send<{ id: string; skipped?: string[] }>('POST', `/api/price-list-versions/${props.from.id}/copy`, { name, valid_from: validFrom })
        : await send<{ id: string; skipped?: string[] }>('POST', `/api/price-lists/${props.listId}/versions`, { name, valid_from: validFrom });
      props.onDone(r.id, r.skipped ?? []);
    });
  return (
    <SidePanel
      title={props.from ? `Nová verzia – kópia verzie ${props.from.name}` : 'Prvá verzia cenníka'}
      onClose={props.onClose}
      footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Vytvoriť návrh" disabled={!name.trim() || !validFrom} />}
    >
      {error && <Notice tone="error">{error}</Notice>}
      <Field label="Názov verzie" hint="napr. 2027">
        <TextInput value={name} onChange={setName} maxLength={40} autoFocus />
      </Field>
      <Field label="Platná od" hint="dnes alebo neskôr (dá sa zmeniť do schválenia)">
        <TextInput type="date" value={validFrom} onChange={setValidFrom} />
      </Field>
      <p className="caption">
        {props.from
          ? 'Vznikne návrh s položkami a parametrami programov kopírovanej verzie. Ukončené produkty sa neskopírujú.'
          : 'Vznikne prázdny návrh, produkty a ceny doplníte v úprave cien.'}
      </p>
    </SidePanel>
  );
}

export function DraftDataPanel(props: { version: PriceListVersion; onClose: () => void; onDone: () => void }) {
  const [name, setName] = useState(props.version.name);
  const [validFrom, setValidFrom] = useState(props.version.valid_from);
  const [note, setNote] = useState(props.version.note ?? '');
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      await send('PATCH', `/api/price-list-versions/${props.version.id}`, { updated_at: props.version.updated_at, name, valid_from: validFrom, note });
      props.onDone();
    });
  return (
    <SidePanel title={`Údaje návrhu ${props.version.name}`} onClose={props.onClose} footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Uložiť" />}>
      {error && <Notice tone="error">{error}</Notice>}
      <Field label="Názov verzie">
        <TextInput value={name} onChange={setName} maxLength={40} autoFocus />
      </Field>
      <Field label="Platná od">
        <TextInput type="date" value={validFrom} onChange={setValidFrom} />
      </Field>
      <Field label="Poznámka">
        <TextInput value={note} onChange={setNote} maxLength={500} />
      </Field>
    </SidePanel>
  );
}

export function ApprovePanel(props: { version: PriceListVersion; onClose: () => void; onDone: () => void }) {
  const { data: p, error: loadError } = useApi<ApprovePreview>(`/api/price-list-versions/${props.version.id}/approve-preview`);
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      await send('POST', `/api/price-list-versions/${props.version.id}/approve`, { updated_at: props.version.updated_at });
      props.onDone();
    });
  return (
    <SidePanel
      title={`Schváliť verziu ${props.version.name}`}
      onClose={props.onClose}
      footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Schváliť" disabled={!p?.can_approve} />}
    >
      {loadError && <Notice tone="error">{loadError.message}</Notice>}
      {error && <Notice tone="error">{error}</Notice>}
      {!p ? (
        <p className="caption">Načítavam náhľad…</p>
      ) : (
        <>
          <p>
            Verzia <strong>{p.name}</strong> bude platiť {p.valid_to ? `od ${date(p.valid_from)} do ${date(p.valid_to)}` : `od ${date(p.valid_from)}`}{' '}
            ({p.item_count} položiek).
          </p>
          {p.errors.length > 0 && (
            <Notice tone="error">
              {p.errors.map((e) => (
                <div key={e}>{e}</div>
              ))}
            </Notice>
          )}
          {p.closes && (
            <p>
              Predošlá verzia <strong>{p.closes.name}</strong> bude platiť do {date(p.closes.valid_to)}.
            </p>
          )}
          {p.supersedes && (
            <p>
              Budúca verzia <strong>{p.supersedes.name}</strong> s rovnakým dátumom sa nahradí (nebude platiť).
            </p>
          )}
          {p.missing_products.length > 0 && (
            <Notice tone="error">
              V návrhu chýbajú produkty platnej verzie: {p.missing_products.join(', ')}. Zmluvy s týmito produktmi na novú verziu
              neprejdú (modul 4).
            </Notice>
          )}
          <p className="caption">Po schválení sa verzia už nedá zmeniť, oprava = nová verzia.</p>
        </>
      )}
    </SidePanel>
  );
}

export function ClosePanel(props: { version: PriceListVersion; listName: string; onClose: () => void; onDone: () => void }) {
  const [validTo, setValidTo] = useState(`${todayIso().slice(0, 4)}-12-31`);
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      await send('POST', `/api/price-list-versions/${props.version.id}/close`, { valid_to: validTo });
      props.onDone();
    });
  return (
    <SidePanel title={`Ukončiť cenník ${props.listName}`} onClose={props.onClose} footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Ukončiť" danger disabled={!validTo} />}>
      {error && <Notice tone="error">{error}</Notice>}
      <Field label="Verzia platí do" hint="dnes alebo neskôr">
        <TextInput type="date" value={validTo} onChange={setValidTo} />
      </Field>
      <Notice tone="error">
        Cenník nebude mať nástupcu: zmluvy s cenou z tohto cenníka (modul 4) nebudú mať od nasledujúceho dňa cenu z cenníka.
      </Notice>
    </SidePanel>
  );
}

export function DeleteDraftPanel(props: { version: PriceListVersion; onClose: () => void; onDone: () => void }) {
  const { busy, error, run } = useSave();
  const save = () =>
    run(async () => {
      await send('DELETE', `/api/price-list-versions/${props.version.id}`);
      props.onDone();
    });
  return (
    <SidePanel title={`Zmazať návrh ${props.version.name}`} onClose={props.onClose} footer={<Footer busy={busy} onClose={props.onClose} onSave={save} label="Zmazať" danger />}>
      {error && <Notice tone="error">{error}</Notice>}
      <p>Návrh sa zmaže aj s položkami. Schválené verzie ostávajú.</p>
    </SidePanel>
  );
}

// ---------------------------------------------------------------------------
// Úprava cien návrhu
// ---------------------------------------------------------------------------

type Field5 = 'vt' | 'nt' | 'oom' | 'program' | 'kw';
const FIELDS: Record<Field5, { title: string; db: keyof PriceListItem; gross: keyof PriceListItem; decimals: [number, number] }> = {
  oom: { title: 'Mesačná platba za OM [€]', db: 'fee_oom_eur_month', gross: 'fee_oom_with_vat', decimals: [2, 4] },
  program: { title: 'Mesačný poplatok [€]', db: 'fee_program_eur_month', gross: 'fee_program_with_vat', decimals: [2, 4] },
  kw: { title: 'Poplatok za odchýlku [€/kW mes.]', db: 'fee_kw_eur_month', gross: 'fee_kw_with_vat', decimals: [2, 4] },
  vt: { title: 'VT [€/MWh]', db: 'price_vt_eur_mwh', gross: 'price_vt_with_vat', decimals: [4, 4] },
  nt: { title: 'NT [€/MWh]', db: 'price_nt_eur_mwh', gross: 'price_nt_with_vat', decimals: [4, 4] },
};
/** Ktoré ceny má produkt podľa kategórie (zadanie čl. 4, 9). */
const FIELDS_OF: Record<string, Field5[]> = {
  dodavka_domacnost: ['oom', 'vt', 'nt'],
  dodavka_maly_podnik: ['oom', 'vt', 'nt'],
  dodavka_firma: ['oom', 'vt', 'nt'],
  velkoobchod: ['vt', 'nt'],
  vykup_firma: ['vt', 'nt'],
  zem: ['oom'],
  poplatok: ['oom'],
  vbattery: ['program'],
  viwa: ['program', 'kw'],
};
const ORDER: Field5[] = ['oom', 'program', 'kw', 'vt', 'nt'];

type Params = {
  greencar: boolean;
  greencar_kwh_per_voucher: string;
  greencar_voucher_eur: string;
  greenshare: boolean;
  greenshare_fee_pct: string;
  viwa_conversion_factor: string;
  viwa_activation_bonus: string;
  viwa_credit_expiry_months: string;
};
type Row = {
  key: string;
  id: string | null;
  product_id: string;
  product_name: string;
  category: string;
  values: Record<Field5, string>;
  item: PriceListItem | null;
  dirty: boolean;
  params: Params | null;
};

const s = (v: unknown) => (v === null || v === undefined ? '' : String(v));
const input = (v: unknown, decimals: [number, number]) => (v === null || v === undefined ? '' : dec(v as string, ...decimals).replace(/ /g, ''));

function rowOf(i: PriceListItem): Row {
  const values = {} as Record<Field5, string>;
  for (const f of ORDER) values[f] = input(i[FIELDS[f].db], FIELDS[f].decimals);
  const prog = i.category === 'vbattery' || i.category === 'viwa';
  return {
    key: i.id,
    id: i.id,
    product_id: i.product_id,
    product_name: i.product_name,
    category: i.category,
    values,
    item: i,
    dirty: false,
    params: prog
      ? {
          greencar: !!i.greencar,
          greencar_kwh_per_voucher: s(i.greencar_kwh_per_voucher),
          greencar_voucher_eur: input(i.greencar_voucher_eur, [0, 2]),
          greenshare: !!i.greenshare,
          greenshare_fee_pct: input(i.greenshare_fee_pct, [0, 2]),
          viwa_conversion_factor: input(i.viwa_conversion_factor, [2, 4]),
          viwa_activation_bonus: s(i.viwa_activation_bonus),
          viwa_credit_expiry_months: s(i.viwa_credit_expiry_months),
        }
      : null,
  };
}

const emptyParams = (): Params => ({
  greencar: false,
  greencar_kwh_per_voucher: '',
  greencar_voucher_eur: '',
  greenshare: false,
  greenshare_fee_pct: '',
  viwa_conversion_factor: '',
  viwa_activation_bonus: '',
  viwa_credit_expiry_months: '',
});

export function EditItems(props: { detail: PriceListDetail; version: PriceListVersion; onCancel: () => void; onSaved: (d: PriceListDetail) => void }) {
  const [rows, setRows] = useState<Row[]>(() => props.detail.items.map(rowOf));
  const [adding, setAdding] = useState('');
  const { busy, error, run } = useSave();
  const [stale, setStale] = useState(false);
  const { data: addable } = useApi<{ items: { id: string; name: string; category: string }[] }>(
    `/api/price-list-versions/${props.version.id}/addable-products`,
  );
  const options = (addable?.items ?? []).filter((p) => !rows.some((r) => r.product_id === p.id));
  const cols = ORDER.filter((f) => rows.some((r) => (FIELDS_OF[r.category] ?? ORDER).includes(f)));

  const update = (key: string, fn: (r: Row) => Row) => setRows((rs) => rs.map((r) => (r.key === key ? { ...fn(r), dirty: true } : r)));
  const add = () => {
    const p = addable?.items.find((x) => x.id === adding);
    if (!p) return;
    const values = { vt: '', nt: '', oom: '', program: '', kw: '' };
    setRows((rs) => [
      ...rs,
      { key: `new-${p.id}`, id: null, product_id: p.id, product_name: p.name, category: p.category, values, item: null, dirty: true, params: p.category === 'vbattery' || p.category === 'viwa' ? emptyParams() : null },
    ]);
    setAdding('');
  };
  const save = () =>
    run(async () => {
      setStale(false);
      try {
        const d = await send<PriceListDetail>('PUT', `/api/price-list-versions/${props.version.id}/items`, {
          updated_at: props.version.updated_at,
          items: rows.map((r) => ({
            id: r.id,
            product_id: r.product_id,
            product_name: r.product_name,
            price_vt_eur_mwh: r.values.vt,
            price_nt_eur_mwh: r.values.nt,
            fee_oom_eur_month: r.values.oom,
            fee_program_eur_month: r.values.program,
            fee_kw_eur_month: r.values.kw,
            program: r.params && {
              ...r.params,
              greencar_kwh_per_voucher: r.params.greencar ? r.params.greencar_kwh_per_voucher : null,
              greencar_voucher_eur: r.params.greencar ? r.params.greencar_voucher_eur : null,
              greenshare_fee_pct: r.params.greenshare ? r.params.greenshare_fee_pct : null,
            },
          })),
        });
        props.onSaved(d);
      } catch (err) {
        if (err instanceof ApiError && err.status === 409) setStale(true);
        throw err;
      }
    });

  return (
    <>
      {error && (
        <Notice tone="error">
          {error}{' '}
          {stale && (
            <button type="button" className="btn" onClick={() => window.location.reload()}>
              Obnoviť stránku
            </button>
          )}
        </Notice>
      )}
      <div className="table-wrap">
        <table className="tbl">
          <thead>
            <tr>
              <th scope="col" rowSpan={2}>
                Produkt
              </th>
              {cols.map((f) => (
                <th key={f} scope="colgroup" colSpan={2} className="num">
                  {f === 'program' && rows.some((r) => r.category === 'viwa') ? 'Mesačne za OOM [€]' : FIELDS[f].title}
                </th>
              ))}
              <th scope="col" rowSpan={2}>
                <span className="sr-only">Odobrať</span>
              </th>
            </tr>
            <tr>
              {cols.flatMap((f) => [
                <th key={`${f}-n`} scope="col" className="num sub-head">
                  bez DPH
                </th>,
                <th key={`${f}-g`} scope="col" className="num sub-head">
                  s DPH
                </th>,
              ])}
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => {
              const own = FIELDS_OF[r.category] ?? ORDER;
              return [
                <tr key={r.key}>
                  <td>{r.product_name}</td>
                  {cols.flatMap((f) => [
                    <td key={`${f}-n`} className="num">
                      {own.includes(f) ? (
                        <input
                          className="inp num-input"
                          inputMode="decimal"
                          aria-label={`${r.product_name} – ${FIELDS[f].title} bez DPH`}
                          value={r.values[f]}
                          onChange={(e) => update(r.key, (x) => ({ ...x, values: { ...x.values, [f]: e.target.value } }))}
                        />
                      ) : (
                        EMPTY
                      )}
                    </td>,
                    <td key={`${f}-g`} className="num with-vat">
                      {!own.includes(f) ? EMPTY : r.dirty ? <span className="caption">po uložení</span> : dec(r.item?.[FIELDS[f].gross] as string, ...FIELDS[f].decimals)}
                    </td>,
                  ])}
                  <td>
                    <button type="button" className="btn btn-ghost" aria-label={`Odobrať ${r.product_name}`} onClick={() => setRows((rs) => rs.filter((x) => x.key !== r.key))}>
                      ✕
                    </button>
                  </td>
                </tr>,
                r.params && (
                  <tr key={`${r.key}-p`} className="params-row">
                    <td colSpan={2 + cols.length * 2}>
                      <ProgramParams category={r.category} value={r.params} onChange={(p) => update(r.key, (x) => ({ ...x, params: p }))} />
                    </td>
                  </tr>
                ),
              ];
            })}
          </tbody>
        </table>
      </div>
      <div className="toolbar">
        {options.length > 0 && (
          <>
            <Select value={adding} onChange={setAdding} placeholder="Pridať produkt…" options={options.map((p) => ({ value: p.id, label: p.name }))} />
            <button type="button" className="btn" disabled={!adding} onClick={add}>
              Pridať
            </button>
          </>
        )}
        <span className="grow" />
        <button type="button" className="btn" onClick={props.onCancel} disabled={busy}>
          Zrušiť úpravy
        </button>
        <button type="button" className="btn primary" onClick={save} disabled={busy}>
          {busy ? 'Ukladám…' : 'Uložiť'}
        </button>
      </div>
      <div className="price-note">Ceny bez DPH, najviac 4 desatinné miesta (desatinná čiarka). Ceny s DPH dopočíta databáza po uložení.</div>
    </>
  );
}

function ProgramParams(props: { category: string; value: Params; onChange: (p: Params) => void }) {
  const v = props.value;
  const set = (k: keyof Params, x: string | boolean) => props.onChange({ ...v, [k]: x });
  const small = (k: keyof Params, label: string) => (
    <label className="param">
      <span className="caption">{label}</span>
      <input className="inp num-input" inputMode="decimal" value={String(v[k])} onChange={(e) => set(k, e.target.value)} />
    </label>
  );
  return (
    <div className="params">
      <Check checked={v.greencar} onChange={(x) => set('greencar', x)}>
        GreenCar
      </Check>
      {props.category === 'vbattery' && v.greencar && (
        <>
          {small('greencar_kwh_per_voucher', 'kWh za voucher')}
          {small('greencar_voucher_eur', 'voucher [€]')}
        </>
      )}
      <Check checked={v.greenshare} onChange={(x) => set('greenshare', x)}>
        GreenShare
      </Check>
      {props.category === 'vbattery' && v.greenshare && small('greenshare_fee_pct', 'poplatok [% z kWh]')}
      {props.category === 'viwa' && (
        <>
          {small('viwa_conversion_factor', 'konverzný kurz (× SPOT)')}
          {small('viwa_activation_bonus', 'aktivačný bonus [GreenCredit]')}
          {small('viwa_credit_expiry_months', 'expirácia [mes.]')}
        </>
      )}
    </div>
  );
}
