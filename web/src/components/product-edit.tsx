// Modul 3 F3 – nový produkt a úprava produktu (obrazovka 22, iba admin).
// Produkt sa nemaže, iba ukončí. Pri použitom produkte (je v cenníku) sa nemení kategória, segment, typ tarifu,
// cenová regulácia ani model „cenník“ (databáza, 0022); panel to vysvetlí a polia uzamkne. Súbežná úprava → 409.

import { useState } from 'react';
import { send, type ProductRow } from '../lib/api';
import { PRICE_MODEL, PRODUCT_CATEGORY, PRODUCT_STATUS, TARIFF_TYPE } from '../lib/labels';
import { dec } from '../lib/format';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';

const opts = (m: Record<string, string>) => Object.entries(m).map(([value, label]) => ({ value, label: label || 'netýka sa' }));

export function ProductPanel(props: { product?: ProductRow; onClose: () => void; onDone: () => void }) {
  const p = props.product;
  const used = !!p?.used;
  const [name, setName] = useState(p?.name ?? '');
  const [category, setCategory] = useState(p?.category ?? '');
  const [segment, setSegment] = useState(p?.segment ?? '');
  const [vat, setVat] = useState(p?.vat_rate === null || p?.vat_rate === undefined ? '' : dec(p.vat_rate as string, 0));
  const [tariff, setTariff] = useState(p?.tariff_type ?? 'netyka_sa');
  const [models, setModels] = useState<string[]>(p?.price_models ?? ['cennik']);
  const [regulation, setRegulation] = useState(p?.price_regulation === null || p?.price_regulation === undefined ? '' : p.price_regulation ? 'ano' : 'nie');
  const [status, setStatus] = useState(p?.status ?? 'predava_sa');
  const { busy, error, run } = useSave();
  const fve = category === 'instalacia_fve';

  const save = () =>
    run(async () => {
      const body: Record<string, unknown> = {
        name,
        vat_rate: fve ? null : vat,
        price_models: models,
        status,
      };
      if (!used) Object.assign(body, { category, segment, tariff_type: tariff, price_regulation: regulation === '' ? null : regulation === 'ano' });
      if (p) await send('PATCH', `/api/products/${p.id}`, { ...body, updated_at: p.updated_at });
      else await send('POST', '/api/products', body);
      props.onDone();
    });

  return (
    <SidePanel
      title={p ? `Produkt ${p.name}` : 'Nový produkt'}
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={busy || !name.trim() || !category || !segment || models.length === 0} onClick={save}>
            {busy ? 'Ukladám…' : p ? 'Uložiť' : 'Založiť'}
          </button>
        </>
      }
    >
      {error && <Notice tone="error">{error}</Notice>}
      {used && (
        <p className="caption">
          Produkt je v cenníku: kategória, segment, typ tarifu, cenová regulácia a model „cenník“ sa nemenia. Zmeniť sa dá názov, DPH
          (schválené verzie majú kópiu DPH), ďalšie cenové modely a stav.
        </p>
      )}
      <Field label="Názov" hint={p ? undefined : 'kód sa vytvorí z názvu a nemení sa'}>
        <TextInput value={name} onChange={setName} maxLength={120} autoFocus />
      </Field>
      <Field label="Kategória">
        <Select value={category} onChange={setCategory} placeholder="Vyberte" options={opts(PRODUCT_CATEGORY)} disabled={used} />
      </Field>
      <Field label="Segment">
        <Select value={segment} onChange={setSegment} placeholder="Vyberte" options={[{ value: 'domacnost', label: 'Domácnosť' }, { value: 'firma', label: 'Firma' }]} disabled={used} />
      </Field>
      <Field label="DPH [%]" hint={fve ? 'inštalácia FVE: DPH podľa diela' : 'elektrina a ZEM 19 %, služby 23 %'}>
        <TextInput value={fve ? '' : vat} onChange={setVat} disabled={fve} />
      </Field>
      <Field label="Typ tarifu">
        <Select value={tariff} onChange={setTariff} options={opts(TARIFF_TYPE)} disabled={used} />
      </Field>
      <Field label="Cenové modely">
        <div className="params">
          {Object.entries(PRICE_MODEL).map(([m, label]) => (
            <Check
              key={m}
              checked={models.includes(m)}
              disabled={used && m === 'cennik' && (p?.price_models ?? []).includes('cennik')}
              onChange={(x) => setModels((ms) => (x ? [...ms, m] : ms.filter((y) => y !== m)))}
            >
              {label}
            </Check>
          ))}
        </div>
      </Field>
      <Field label="Cenová regulácia" hint="domácnosť: energopomoc; firma: cenník pre malé podniky">
        <Select
          value={regulation}
          onChange={setRegulation}
          options={[{ value: '', label: 'nezáleží' }, { value: 'ano', label: 'ANO' }, { value: 'nie', label: 'NIE' }]}
          disabled={used}
        />
      </Field>
      <Field label="Stav">
        <Select value={status} onChange={setStatus} options={Object.entries(PRODUCT_STATUS).map(([value, s]) => ({ value, label: s.label }))} />
      </Field>
      {status === 'ukonceny' && p?.status !== 'ukonceny' && (
        <Notice tone="error">Ukončený produkt sa nedá pridať do návrhu cenníka a návrh s ním sa nedá schváliť.</Notice>
      )}
      {status === 'dobieha' && <p className="caption">Dobieha: existujúce zmluvy bežia (produkt môže byť v novej verzii cenníka), nové zmluvy nie.</p>}
    </SidePanel>
  );
}
