// Karta a zoznam OOM, F2b: nové odberné miesto a úprava údajov po skupinách (zadanie OOM čl. 6, 7, 8, 15).
// Kontrola EIC počas písania (formát, kontrolná číslica, „už existuje“), sadzby podľa zvoleného PDS.
// Pravidlá stráži databáza (povinné údaje pre Aktívne, číselníky, poradie krokov prechodu, právo upravovať
// Aktívne OOM); formulár ich vysvetľuje vopred a pošle iba zmenené polia.

import { useEffect, useState, type ReactNode } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { get, send, useApi, type OomCard } from '../lib/api';
import { permission, useMe } from '../lib/me';
import { SOURCE_CATEGORY, SOURCE_KIND } from '../lib/labels';
import { CustomerPicker, type CustomerHit } from './oom-actions';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';

type Opt = { code: string; label: string; parent: string | null; hidden: boolean };
export type OomOptions = Partial<Record<'pds' | 'sadzba_distribucie' | 'typ_merania' | 'fakturacne_obdobie' | 'sposob_zaloh' | 'typ_vykupnej_zmluvy' | 'predchadzajuci_dodavatel', Opt[]>>;
export type OomFormValues = Record<string, string | boolean>;
type Values = OomFormValues;

/** Smie zakladať OOM (právo upravovať v module Odberné miesta). */
export function useCanCreateOom(): boolean {
  return permission(useMe(), 'odberne_miesta').edit !== 'nic';
}

const NUM_FIELDS = [
  'breaker_a', 'reserved_capacity_kw', 'max_reserved_capacity_kw', 'advance_payment_pct', 'advance_payment_eur',
  'planned_consumption_vt_mwh', 'planned_consumption_nt_mwh', 'planned_feed_in_mwh',
  'source_power_kw', 'inverter_power_kw', 'panels_power_kw',
];
const TEXT_FIELDS = [
  'eic', 'type', 'name', 'address_street', 'address_number_supisne', 'address_number_orientacne', 'address_zip', 'address_city',
  'pds', 'pds_point_id', 'pds_tariff', 'voltage_level', 'metering_type', 'phases', 'capacity_reservation_method',
  'price_regulation', 'excise_tax', 'billing_period', 'advance_payment_method',
  'source_kind', 'source_category', 'feed_in_contract_type',
  'supply_from', 'supply_to', 'previous_supplier', 'switch_notice_sent_on', 'switch_notice_accepted_on', 'switch_confirmed_on',
];

// Číslo do poľa po slovensky (desatinná čiarka), bez zbytočných núl
const numText = (v: unknown) => (v === null || v === undefined || v === '' ? '' : String(Number(v)).replace('.', ','));

export function initialValues(o?: OomCard): Values {
  const v: Values = { switch_notice_required: o ? o.switch_notice_required : true };
  for (const k of TEXT_FIELDS) v[k] = o ? String((o as unknown as Record<string, unknown>)[k] ?? '') : '';
  for (const k of NUM_FIELDS) v[k] = o ? numText((o as unknown as Record<string, unknown>)[k]) : '';
  if (!o) v.type = 'spotreba';
  v.public_lighting = o ? !!o.public_lighting : false;
  return v;
}

/** Iba zmenené polia; prázdne pole = vymazať (null). Čísla s čiarkou prevedie API. */
export function changed(initial: Values, now: Values): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(now)) {
    if (v === initial[k]) continue;
    if (k === 'phases') out[k] = v === '' ? null : Number(v);
    else if (k === 'price_regulation') out[k] = v === '' ? null : v === 'true';
    else out[k] = v === '' ? null : v;
  }
  return out;
}

const opts = (list: Opt[] | undefined, current: string, filter?: (o: Opt) => boolean) => [
  { value: '', label: '–' },
  ...(list ?? []).filter((o) => (!o.hidden || o.code === current) && (!filter || filter(o) || o.code === current)).map((o) => ({ value: o.code, label: o.hidden ? `${o.label} (skryté)` : o.label })),
];

function Section(props: { title: string; children: ReactNode }) {
  return (
    <fieldset className="form-section">
      <legend>{props.title}</legend>
      <div className="form-grid">{props.children}</div>
    </fieldset>
  );
}

type EicCheck = { eic: string; valid: boolean; complete: boolean; existing: { oom_exists: boolean; oom_id: string | null; owner_name: string | null; org_name: string }[] };

function EicField(props: { value: string; onChange: (v: string) => void; selfId?: string }) {
  const [check, setCheck] = useState<EicCheck | null>(null);
  useEffect(() => {
    const eic = props.value.toUpperCase().replace(/\s/g, '');
    if (eic.length < 16) {
      setCheck(null);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<EicCheck>(`/api/oom-check-eic?eic=${encodeURIComponent(eic)}`, ctrl.signal).then(setCheck).catch(() => undefined);
    }, 350);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [props.value]);
  const others = (check?.existing ?? []).filter((e) => e.oom_id !== props.selfId);
  return (
    <Field label="EIC" wide hint="16 znakov, napr. 24ZZS4100078132P; medzery a malé písmená sa upravia.">
      <TextInput value={props.value} onChange={props.onChange} maxLength={24} />
      {props.value.replace(/\s/g, '').length > 16 && <span className="fl-error">EIC má 16 znakov.</span>}
      {check && !check.valid && <span className="fl-error">Neplatný formát alebo kontrolná číslica EIC.</span>}
      {others.map((e, i) => (
        <span key={i} className="fl-error">
          OOM s týmto EIC už v CRM je{e.owner_name ? ` (vlastník ${e.owner_name})` : ''}.{' '}
          {e.oom_id && <Link to={`/oom/${e.oom_id}`}>Otvoriť</Link>}
        </span>
      ))}
      {check && check.valid && others.length === 0 && <span className="fl-hint">EIC je platné.</span>}
    </Field>
  );
}

/** Všetky skupiny údajov OOM (rovnaké pri založení aj úprave). */
export function OomFields(props: {
  v: Values;
  set: (k: string, val: string | boolean) => void;
  options?: OomOptions;
  selfId?: string;
  withSwitch: boolean;
  /** úprava existujúceho OOM: plán výkupu lokálneho zdroja zadaný ručne (0023) */
  feedInManual?: boolean;
}) {
  const { v, set, options } = props;
  const text = (k: string, label: string, opts2: { wide?: boolean; type?: string; hint?: string; max?: number } = {}) => (
    <Field label={label} wide={opts2.wide} hint={opts2.hint}>
      <TextInput value={String(v[k] ?? '')} onChange={(x) => set(k, x)} type={opts2.type} maxLength={opts2.max} />
    </Field>
  );
  const select = (k: string, label: string, list: { value: string; label: string }[], hint?: string) => (
    <Field label={label} hint={hint}>
      <Select value={String(v[k] ?? '')} onChange={(x) => set(k, x)} options={list} />
    </Field>
  );
  const producer = v.type === 'vyroba' || v.source_kind !== '';
  return (
    <>
      <Section title="Základ">
        <EicField value={String(v.eic)} onChange={(x) => set('eic', x)} selfId={props.selfId} />
        {select('type', 'Typ', [
          { value: 'spotreba', label: 'Spotreba' },
          { value: 'vyroba', label: 'Výroba' },
          { value: 'sharing', label: 'Sharing' },
        ])}
        {text('name', 'Názov', { hint: 'napr. Hala A, Rodinný dom', max: 120 })}
        <Field label="Verejné osvetlenie">
          <Check checked={!!v.public_lighting} onChange={(x) => set('public_lighting', x)}>
            áno (prolongácia navrhne Green 1T VO)
          </Check>
        </Field>
      </Section>
      <Section title="Adresa">
        {text('address_street', 'Ulica', { max: 120 })}
        {text('address_number_supisne', 'Súpisné číslo', { max: 20 })}
        {text('address_number_orientacne', 'Orientačné číslo', { max: 20 })}
        {text('address_zip', 'PSČ', { max: 10 })}
        {text('address_city', 'Obec', { max: 80 })}
      </Section>
      <Section title="Distribúcia">
        <Field label="PDS">
          <Select
            value={String(v.pds)}
            onChange={(x) => {
              set('pds', x);
              // sadzba patrí PDS: pri zmene PDS sa vymaže, ak nesedí
              const t = options?.sadzba_distribucie?.find((o) => o.code === v.pds_tariff);
              if (t && t.parent !== x) set('pds_tariff', '');
            }}
            options={opts(options?.pds, String(v.pds))}
          />
        </Field>
        {select('pds_tariff', 'Sadzba', opts(options?.sadzba_distribucie, String(v.pds_tariff), (o) => o.parent === v.pds), v.pds ? undefined : 'Najprv vyberte PDS.')}
        {text('pds_point_id', 'Číslo OP', { max: 40 })}
        {select('voltage_level', 'Napäťová úroveň', [
          { value: '', label: '–' },
          { value: 'nn', label: 'NN' },
          { value: 'vn', label: 'VN' },
          { value: 'vvn', label: 'VVN' },
        ])}
        {select('metering_type', 'Typ merania', opts(options?.typ_merania, String(v.metering_type)))}
        {select('phases', 'Fázy', [
          { value: '', label: '–' },
          { value: '1', label: '1' },
          { value: '3', label: '3' },
        ])}
        {text('breaker_a', 'Istič [A]')}
        {text('reserved_capacity_kw', 'Rezervovaná kapacita [kW]')}
        {text('max_reserved_capacity_kw', 'Max. rezervovaná kapacita [kW]')}
        {text('capacity_reservation_method', 'Spôsob rezervácie kapacity', { max: 80 })}
      </Section>
      <Section title="Objemy">
        {v.type !== 'vyroba' && text('planned_consumption_vt_mwh', 'Plánovaná spotreba VT [MWh]')}
        {v.type !== 'vyroba' && text('planned_consumption_nt_mwh', 'Plánovaná spotreba NT [MWh]')}
        {(v.type !== 'spotreba' || v.planned_feed_in_mwh !== '') &&
          text('planned_feed_in_mwh', 'Plánovaný výkup [MWh]', {
            hint:
              v.source_category === 'lokalny_zdroj'
                ? props.feedInManual
                  ? 'Zadané ručne. Výpočet z výkonu sa dá vrátiť na karte OOM.'
                  : 'Lokálny zdroj: počíta sa sám (výkon × 4 × 365 × 0,1 / 1000). Iná hodnota sa uloží ako ručná.'
                : undefined,
          })}
      </Section>
      {producer && (
        <Section title="Výroba">
          {select('source_kind', 'Druh zdroja', [{ value: '', label: '–' }, ...Object.entries(SOURCE_KIND).map(([value, label]) => ({ value, label }))])}
          {select('source_category', 'Kategória zdroja', [{ value: '', label: '–' }, ...Object.entries(SOURCE_CATEGORY).map(([value, label]) => ({ value, label }))])}
          {text('source_power_kw', 'Výkon zdroja [kW]')}
          {text('inverter_power_kw', 'Výkon striedača [kW]')}
          {text('panels_power_kw', 'Výkon panelov [kW]')}
          {select('feed_in_contract_type', 'Typ výkupnej zmluvy', opts(options?.typ_vykupnej_zmluvy, String(v.feed_in_contract_type)))}
        </Section>
      )}
      <Section title="Fakturácia">
        {props.selfId ? (
          <Field label="Cenová regulácia" hint="mení sa s dátumom „platí od“ – tlačidlo Zmeniť reguláciu na karte OOM">
            <TextInput
              value={v.price_regulation === 'true' ? 'ANO' : v.price_regulation === 'false' ? 'NIE' : 'nevyplnené'}
              onChange={() => undefined}
              disabled
            />
          </Field>
        ) : (
          select('price_regulation', 'Cenová regulácia', [
            { value: '', label: '– nevyplnené' },
            { value: 'true', label: 'ANO' },
            { value: 'false', label: 'NIE' },
          ], 'domácnosť: nárok na energopomoc; firma: cenník pre malé podniky')
        )}
        {text('excise_tax', 'Spotrebná daň', { max: 80 })}
        {select('billing_period', 'Fakturačné obdobie', opts(options?.fakturacne_obdobie, String(v.billing_period)))}
        {select('advance_payment_method', 'Zálohy', opts(options?.sposob_zaloh, String(v.advance_payment_method)))}
        {text('advance_payment_pct', 'Záloha [%]')}
        {text('advance_payment_eur', 'Záloha [€]')}
      </Section>
      <Section title="Dodávka a prechod k Greenlogy">
        {text('supply_from', 'Dodávka od', { type: 'date', hint: 'Začiatok dodávky (4. krok prechodu).' })}
        {text('supply_to', 'Dodávka do', { type: 'date', hint: 'Prázdne = na neurčito.' })}
        {props.withSwitch && (
          <>
            {select('previous_supplier', 'Predošlý dodávateľ', opts(options?.predchadzajuci_dodavatel, String(v.previous_supplier)))}
            <Field label="Výpoveď predošlému dodávateľovi">
              <Check
                checked={!!v.switch_notice_required}
                onChange={(x) => {
                  set('switch_notice_required', x);
                  if (!x) {
                    set('switch_notice_sent_on', '');
                    set('switch_notice_accepted_on', '');
                  }
                }}
              >
                zasiela sa (vypnúť napr. pri novej prípojke)
              </Check>
            </Field>
            {v.switch_notice_required && text('switch_notice_sent_on', '1. Výpoveď odoslaná', { type: 'date' })}
            {v.switch_notice_required && text('switch_notice_accepted_on', '2. Výpoveď akceptovaná', { type: 'date' })}
            {text('switch_confirmed_on', '3. Zmena dodávateľa potvrdená', {
              type: 'date',
              hint: 'Keď je potvrdená a dodávka už začala, Pripravované OOM sa samo aktivuje.',
            })}
          </>
        )}
      </Section>
    </>
  );
}

/** Nové odberné miesto. Zákazník je predvyplnený z karty zákazníka, inak sa vyhľadá. */
export function OomCreatePanel(props: { customer?: CustomerHit & { org_id: string }; onClose: () => void }) {
  const me = useMe();
  const navigate = useNavigate();
  const [target, setTarget] = useState<CustomerHit | null>(props.customer ?? null);
  const [orgId, setOrgId] = useState(props.customer?.org_id ?? me.orgs.find((o) => o.default)?.id ?? me.orgs[0]?.id ?? '');
  const options = useApi<OomOptions>(`/api/oom-options?org=${orgId}`).data;
  const [initial] = useState(() => initialValues());
  const [v, setV] = useState<Values>(initial);
  const save = useSave();
  const set = (k: string, val: string | boolean) => setV((x) => ({ ...x, [k]: val }));

  const submit = async () => {
    if (!target) return;
    const body = { ...changed({}, v), type: v.type, ...(target.kind === 'company' ? { company_id: target.id } : { person_id: target.id }) };
    const r = await save.run(() => send<{ id: string }>('POST', '/api/oom', body));
    if (r) navigate(`/oom/${r.id}`);
  };

  return (
    <SidePanel
      title="Nové odberné miesto"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!target || !String(v.eic).trim() || save.busy} onClick={submit}>
            Založiť
          </button>
        </>
      }
    >
      <p className="caption">
        Nové OOM je v stave Pripravované. Aktívne bude po potvrdení zmeny dodávateľa v deň začiatku dodávky (alebo tlačidlom Aktivovať),
        keď má povinné údaje: adresa, PSČ, PDS, napäťová úroveň, sadzba, dodávka od a plánovaná spotreba (pri výrobe výkup).
      </p>
      {!props.customer && me.orgs.length > 1 && (
        <Field label="Spoločnosť skupiny" wide>
          <Select
            value={orgId}
            onChange={(x) => {
              setOrgId(x);
              setTarget(null);
            }}
            options={me.orgs.map((o) => ({ value: o.id, label: o.name }))}
          />
        </Field>
      )}
      <Field label="Zákazník" wide hint={props.customer ? undefined : 'Firma alebo domácnosť; zákazník musí v CRM už byť.'}>
        {props.customer ? <span className="picked">{props.customer.name}</span> : <CustomerPicker orgId={orgId} value={target} onChange={setTarget} />}
      </Field>
      <OomFields v={v} set={set} options={options} withSwitch />
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

/** Úprava údajov OOM (všetky skupiny). Pri Aktívnom OOM iba s právom „upravovať Aktívne OOM“. */
export function OomEditPanel(props: { o: OomCard; onClose: () => void; onSaved: () => void }) {
  const options = useApi<OomOptions>(`/api/oom-options?org=${props.o.org_id}`).data;
  const [initial] = useState(() => initialValues(props.o));
  const [v, setV] = useState<Values>(initial);
  const save = useSave();
  const set = (k: string, val: string | boolean) => setV((x) => ({ ...x, [k]: val }));
  const diff = changed(initial, v);
  const submit = async () => {
    const ok = await save.run(() => send('PATCH', `/api/oom/${props.o.id}`, diff));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Upraviť údaje – ${props.o.name ?? props.o.eic}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="caption">{Object.keys(diff).length ? `zmenené: ${Object.keys(diff).length}` : 'bez zmien'}</span>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={Object.keys(diff).length === 0 || save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <OomFields v={v} set={set} options={options} selfId={props.o.id} withSwitch feedInManual={props.o.planned_feed_in_manual} />
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
