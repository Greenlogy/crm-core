// Karta OOM – cenová regulácia s dátumom „platí od“ (modul 4, F1b; migrácie 0023, 0024).
// Dátum môže byť v minulosti, dnes aj v budúcnosti; budúcu zmenu uplatní nočný beh v deň platnosti a dovtedy je
// „naplánovaná“ (dá sa zrušiť). Na OOM platí najneskoršia zmena s dátumom do dneška.

import { useState } from 'react';
import { send, type OomCard, type OomRegulationChange } from '../lib/api';
import { date } from '../lib/format';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Pill } from './ui';

export const regulationText = (v: boolean | null | undefined) => (v === true ? 'ANO' : v === false ? 'NIE' : 'nevyplnené');

const todayIso = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Bratislava' });

/** Hodnota na karte: platná regulácia a naplánované zmeny. */
export function RegulationValue(props: { o: OomCard }) {
  const planned = props.o.regulation.filter((r) => r.is_planned).sort((a, b) => a.valid_from.localeCompare(b.valid_from));
  return (
    <span>
      {regulationText(props.o.price_regulation)}
      {planned.map((r) => (
        <span key={r.id}>
          {' '}
          <Pill tone="info">
            naplánované od {date(r.valid_from)}: {regulationText(r.value)}
          </Pill>
        </span>
      ))}
    </span>
  );
}

export function RegulationPanel(props: { o: OomCard; onClose: () => void; onChanged: () => void }) {
  const o = props.o;
  const [value, setValue] = useState<'' | 'true' | 'false'>(o.price_regulation === true ? 'false' : 'true');
  const [validFrom, setValidFrom] = useState(todayIso());
  const save = useSave();

  const submit = async () => {
    const ok = await save.run(() =>
      send('POST', `/api/oom/${o.id}/price-regulation`, { value: value === '' ? null : value === 'true', valid_from: validFrom }),
    );
    if (ok) props.onChanged();
  };
  const cancel = async (r: OomRegulationChange) => {
    const ok = await save.run(() => send('DELETE', `/api/oom-regulation/${r.id}`));
    if (ok) props.onChanged();
  };
  const future = validFrom > todayIso();

  return (
    <SidePanel
      title="Zmeniť cenovú reguláciu"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zavrieť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !validFrom} onClick={submit}>
            {future ? 'Naplánovať' : 'Uložiť'}
          </button>
        </>
      }
    >
      <p className="caption">
        Domácnosť: nárok na energopomoc; firma: cenník pre malé podniky. Teraz: <b>{regulationText(o.price_regulation)}</b>.
      </p>
      <div className="form-grid">
        <Field label="Nová hodnota">
          <Select
            value={value}
            onChange={(v) => setValue(v as '' | 'true' | 'false')}
            options={[
              { value: 'true', label: 'ANO' },
              { value: 'false', label: 'NIE' },
              { value: '', label: 'nevyplnené' },
            ]}
          />
        </Field>
        <Field label="Platí od" hint="minulý, dnešný aj budúci dátum">
          <TextInput type="date" value={validFrom} onChange={setValidFrom} />
        </Field>
      </div>
      {future && (
        <Notice tone="ok">Zmena sa prejaví {date(validFrom)} (nočný beh). Dovtedy je na karte „naplánovaná“ a dá sa zrušiť.</Notice>
      )}
      {o.regulation.length > 0 && (
        <>
          <h3 className="t-group-label">História</h3>
          <table className="tbl">
            <thead>
              <tr>
                <th>Platí od</th>
                <th>Hodnota</th>
                <th>Zadal</th>
                <th>Stav</th>
              </tr>
            </thead>
            <tbody>
              {o.regulation.map((r) => (
                <tr key={r.id}>
                  <td>{date(r.valid_from)}</td>
                  <td>{regulationText(r.value)}</td>
                  <td>{r.created_by_name ?? '—'}</td>
                  <td>
                    {r.is_planned ? (
                      <>
                        <Pill tone="info">naplánované</Pill>{' '}
                        <button type="button" className="link-button" disabled={save.busy} onClick={() => cancel(r)}>
                          Zrušiť
                        </button>
                      </>
                    ) : r.applied_at ? (
                      'platí'
                    ) : (
                      'čaká na nočný beh'
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
