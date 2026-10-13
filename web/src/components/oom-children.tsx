// Karta OOM, F2c: zariadenia a kontaktné osoby pri OOM (zadanie OOM čl. 5, 7).
// Úpravy pri Aktívnom OOM iba s právom „upravovať Aktívne OOM“ – stráži databáza, obrazovka tlačidlá skryje.
// Kontaktná osoba pri firme je osoba z firmy zákazníka; pri domácnosti osoba z tej istej spoločnosti.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { get, send, useApi, type OomCard, type OomDevice } from '../lib/api';
import { kw, num } from '../lib/format';
import { DEVICE_TYPE, label } from '../lib/labels';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Card, Empty, Item, Pill } from './ui';

/** Smie meniť údaje, zariadenia a osoby OOM (pri Aktívnom iba s právom upravovať Aktívne OOM). */
export const canEditOomData = (o: OomCard) => o.can_edit && (o.status !== 'aktivne' || o.can_edit_active);

// --- Zariadenia ---

export function DevicesCard(props: { o: OomCard; onChanged: () => void }) {
  const [editing, setEditing] = useState<OomDevice | 'new' | null>(null);
  const can = canEditOomData(props.o);
  return (
    <Card
      title={`Zariadenia (${props.o.devices.length})`}
      aside={
        can ? (
          <button type="button" className="btn btn-ghost" onClick={() => setEditing('new')}>
            + Pridať
          </button>
        ) : undefined
      }
    >
      {props.o.devices.length === 0 ? (
        <Empty>Bez zariadení.</Empty>
      ) : (
        props.o.devices.map((d) => (
          <Item
            key={d.id}
            title={
              can ? (
                <button type="button" className="link-button" onClick={() => setEditing(d)}>
                  {label(DEVICE_TYPE, d.device_type)}
                  {d.count > 1 ? ` × ${d.count}` : ''}
                </button>
              ) : (
                <>
                  {label(DEVICE_TYPE, d.device_type)}
                  {d.count > 1 ? ` × ${d.count}` : ''}
                </>
              )
            }
            meta={[d.brand, d.model].filter(Boolean).join(' · ') || undefined}
            side={<span>{d.capacity_kwh ? num(d.capacity_kwh, 1, 'kWh') : kw(d.power_kw)}</span>}
          />
        ))
      )}
      {editing && (
        <DevicePanel
          oomId={props.o.id}
          device={editing === 'new' ? undefined : editing}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            props.onChanged();
          }}
        />
      )}
    </Card>
  );
}

const numText = (v: unknown) => (v === null || v === undefined || v === '' ? '' : String(Number(v)).replace('.', ','));

function DevicePanel(props: { oomId: string; device?: OomDevice; onClose: () => void; onSaved: () => void }) {
  const d = props.device;
  const [type, setType] = useState<string>(d?.device_type ?? 'striedac');
  const [brand, setBrand] = useState(d?.brand ?? '');
  const [model, setModel] = useState(d?.model ?? '');
  const [power, setPower] = useState(numText(d?.power_kw));
  const [capacity, setCapacity] = useState(numText(d?.capacity_kwh));
  const [count, setCount] = useState(String(d?.count ?? 1));
  const [confirm, setConfirm] = useState(false);
  const save = useSave();
  const body = { device_type: type, brand, model, power_kw: power, capacity_kwh: capacity, count: Number(count) };
  const submit = async () => {
    const ok = await save.run(() => (d ? send('PATCH', `/api/oom-devices/${d.id}`, body) : send('POST', `/api/oom/${props.oomId}/devices`, body)));
    if (ok) props.onSaved();
  };
  const remove = async () => {
    const ok = await save.run(() => send('DELETE', `/api/oom-devices/${d!.id}`));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={d ? 'Upraviť zariadenie' : 'Pridať zariadenie'}
      onClose={props.onClose}
      footer={
        <>
          {d &&
            (confirm ? (
              <button type="button" className="btn btn-danger-solid" disabled={save.busy} onClick={remove}>
                Naozaj odobrať?
              </button>
            ) : (
              <button type="button" className="btn btn-danger" onClick={() => setConfirm(true)}>
                Odobrať
              </button>
            ))}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Druh">
          <Select value={type} onChange={setType} options={Object.entries(DEVICE_TYPE).map(([value, l]) => ({ value, label: l }))} />
        </Field>
        <Field label="Počet">
          <TextInput type="number" value={count} onChange={setCount} />
        </Field>
        <Field label="Značka">
          <TextInput value={brand} onChange={setBrand} maxLength={80} />
        </Field>
        <Field label="Model">
          <TextInput value={model} onChange={setModel} maxLength={80} />
        </Field>
        <Field label="Výkon [kW]" hint="pri paneloch výkon jedného panelu">
          <TextInput value={power} onChange={setPower} />
        </Field>
        <Field label="Kapacita [kWh]" hint="pri batérii">
          <TextInput value={capacity} onChange={setCapacity} />
        </Field>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

// --- Kontaktné osoby ---

type RoleOpt = { code: string; label: string; hidden: boolean };
type Person = { id: string; name: string; email: string | null; phone: string | null };

const SOURCE_LABEL: Record<string, string> = { rucne: 'pri OOM', zmluva: 'zo zmluvy', deal: 'z dealu' };

function RolesPicker(props: { options: RoleOpt[]; value: string[]; onChange: (v: string[]) => void }) {
  return (
    <div className="check-stack">
      {props.options
        .filter((r) => !r.hidden || props.value.includes(r.code))
        .map((r) => (
          <Check
            key={r.code}
            checked={props.value.includes(r.code)}
            onChange={(on) => props.onChange(on ? [...props.value, r.code] : props.value.filter((x) => x !== r.code))}
          >
            {r.label}
          </Check>
        ))}
    </div>
  );
}

export function ContactsCard(props: { o: OomCard; onChanged: () => void }) {
  const o = props.o;
  const can = canEditOomData(o);
  const roleOptions = useApi<{ rola_pri_oom?: RoleOpt[] }>(`/api/oom-options?org=${o.org_id}`).data?.rola_pri_oom ?? [];
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<OomCard['contacts'][number] | null>(null);
  const linkOpen = o.status === 'aktivne' || o.status === 'pripravovane';
  return (
    <Card
      title={`Kontaktné osoby (${o.contacts.length})`}
      aside={
        can && linkOpen ? (
          <button type="button" className="btn btn-ghost" onClick={() => setAdding(true)}>
            + Pridať osobu
          </button>
        ) : undefined
      }
    >
      {o.contacts.length === 0 ? (
        <Empty>
          Žiadne kontaktné osoby. Osoba sa k OOM priradí priamo, zo zmluvy alebo cez deal (iba pri stave Aktívne alebo Pripravované).
        </Empty>
      ) : (
        o.contacts.map((p) => (
          <Item
            key={p.id}
            title={<Link to={`/osoby/${p.id}`}>{p.name || '(bez mena)'}</Link>}
            meta={[p.role_labels.join(', '), p.email, p.mobile ?? p.phone].filter(Boolean).join(' · ') || undefined}
            side={
              <span className="pills">
                {p.sources.map((s) => (
                  <Pill key={s}>{SOURCE_LABEL[s] ?? s}</Pill>
                ))}
                {can && p.oom_contact_id && (
                  <button type="button" className="btn btn-ghost" onClick={() => setEditing(p)}>
                    Upraviť
                  </button>
                )}
              </span>
            }
          />
        ))
      )}
      {adding && <AddContactPanel o={o} roleOptions={roleOptions} onClose={() => setAdding(false)} onSaved={() => { setAdding(false); props.onChanged(); }} />}
      {editing && (
        <ContactRolesPanel
          contact={editing}
          roleOptions={roleOptions}
          onClose={() => setEditing(null)}
          onSaved={() => {
            setEditing(null);
            props.onChanged();
          }}
        />
      )}
    </Card>
  );
}

function AddContactPanel(props: { o: OomCard; roleOptions: RoleOpt[]; onClose: () => void; onSaved: () => void }) {
  const o = props.o;
  const isCompany = !!o.company_id;
  const candidates = useApi<{ items: Person[] }>(`/api/oom/${o.id}/contact-candidates`).data?.items ?? [];
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<Person[]>([]);
  const [person, setPerson] = useState<Person | null>(null);
  const [roles, setRoles] = useState<string[]>([]);
  const save = useSave();
  const exclude = new Set(o.contacts.map((p) => p.id));

  // domácnosť: hľadanie osoby v spoločnosti OOM
  useEffect(() => {
    if (isCompany || q.trim().length < 2) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<{ items: Person[] }>(`/api/persons/search?q=${encodeURIComponent(q)}&org=${o.org_id}`, ctrl.signal)
        .then((r) => setHits(r.items.filter((h) => !exclude.has(h.id))))
        .catch(() => undefined);
    }, 300);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q]); // eslint-disable-line react-hooks/exhaustive-deps

  const submit = async () => {
    if (!person) return;
    const ok = await save.run(() => send('POST', `/api/oom/${o.id}/contacts`, { contact_id: person.id, roles }));
    if (ok) props.onSaved();
  };
  const list = isCompany ? candidates.filter((h) => !exclude.has(h.id)) : hits;
  return (
    <SidePanel
      title={`Kontaktná osoba – ${o.name ?? o.eic}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!person || save.busy} onClick={submit}>
            Pridať
          </button>
        </>
      }
    >
      <Field
        label="Osoba"
        wide
        hint={isCompany ? 'Osoby vo firme zákazníka. Novú osobu pridáte na karte firmy.' : 'Hľadá meno, e-mail alebo telefón v spoločnosti OOM.'}
      >
        {person ? (
          <span className="picked">
            {person.name} <span className="caption">{person.email ?? person.phone}</span>{' '}
            <button type="button" className="btn btn-ghost" onClick={() => setPerson(null)}>
              Zmeniť
            </button>
          </span>
        ) : (
          <>
            {!isCompany && <TextInput value={q} onChange={setQ} placeholder="Hľadať osobu" autoFocus />}
            {list.length > 0 ? (
              <div className="pick-list">
                {list.map((h) => (
                  <button key={h.id} type="button" className="pick-item" onClick={() => setPerson(h)}>
                    {h.name} <span className="caption">{h.email ?? h.phone}</span>
                  </button>
                ))}
              </div>
            ) : (
              isCompany && <span className="caption">Vo firme nie je ďalšia osoba.</span>
            )}
          </>
        )}
      </Field>
      {person && (
        <Field label="Rola pri odbernom mieste" wide>
          <RolesPicker options={props.roleOptions} value={roles} onChange={setRoles} />
        </Field>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function ContactRolesPanel(props: { contact: OomCard['contacts'][number]; roleOptions: RoleOpt[]; onClose: () => void; onSaved: () => void }) {
  const c = props.contact;
  const [roles, setRoles] = useState<string[]>(c.roles);
  const [confirm, setConfirm] = useState(false);
  const save = useSave();
  const submit = async () => {
    const ok = await save.run(() => send('PATCH', `/api/oom-contacts/${c.oom_contact_id}`, { roles }));
    if (ok) props.onSaved();
  };
  const remove = async () => {
    const ok = await save.run(() => send('DELETE', `/api/oom-contacts/${c.oom_contact_id}`));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={c.name}
      onClose={props.onClose}
      footer={
        <>
          {confirm ? (
            <button type="button" className="btn btn-danger-solid" disabled={save.busy} onClick={remove}>
              Naozaj odobrať od OOM?
            </button>
          ) : (
            <button type="button" className="btn btn-danger" onClick={() => setConfirm(true)}>
              Odobrať od OOM
            </button>
          )}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <Field label="Rola pri odbernom mieste" wide>
        <RolesPicker options={props.roleOptions} value={roles} onChange={setRoles} />
      </Field>
      {c.sources.includes('deal') && <p className="caption">Osoba je pri OOM aj cez deal; po odobratí ostane v zozname so zdrojom „z dealu“.</p>}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
