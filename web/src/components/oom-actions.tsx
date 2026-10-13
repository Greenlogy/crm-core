// Karta OOM, F2a: zmena stavu, prepis, návrat a plánované zmeny (zadanie OOM čl. 15, migrácia 0016).
// Ak deň zmeny už nastal, zmena sa urobí hneď; inak sa uloží plán, ktorý vykoná nočný beh.
// Pravidlá (práva, blokovanie plánom, dátumy) stráži databáza; obrazovka ich vysvetľuje vopred.

import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMe } from '../lib/me';
import { get, send, type OomCard, type OomPlan } from '../lib/api';
import { date } from '../lib/format';
import { Field, Notice, Segmented, SidePanel, TextInput, useSave } from './form';
import { Pill } from './ui';
import { OomEditPanel } from './oom-forms';

export const PLAN_KIND: Record<string, string> = { prepis: 'prepis', odchod: 'odchod', zrusenie: 'zrušenie' };
const PLAN_KIND_TITLE: Record<string, string> = { prepis: 'Plánovaný prepis', odchod: 'Plánovaný odchod', zrusenie: 'Plánované zrušenie' };
export const PLAN_DATE_LABEL: Record<string, string> = {
  prepis: 'Prvý deň nového odberateľa',
  odchod: 'Posledný deň dodávky',
  zrusenie: 'Posledný deň dodávky',
};

const today = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Bratislava' });
const addDays = (d: string, n: number) => {
  const x = new Date(`${d}T12:00:00Z`);
  x.setUTCDate(x.getUTCDate() + n);
  return x.toISOString().slice(0, 10);
};
/** Deň vykonania: prepis v deň zmeny, odchod a zrušenie deň po poslednom dni dodávky. */
const dueOn = (kind: string, d: string) => (kind === 'prepis' ? d : addDays(d, 1));

/** Text plánu do zoznamu a karty zákazníka: „plánovaný odchod k 31. 12. 2026“. */
export const planText = (kind: string | null | undefined, d: string | null | undefined) =>
  kind && d ? `${PLAN_KIND_TITLE[kind].toLowerCase()} k ${date(d)}` : null;

type Action = 'stav' | 'prepis' | 'navrat' | 'udaje' | null;

/** Tlačidlá v hlavičke karty OOM podľa stavu a práv. */
export function OomActions(props: { o: OomCard; onChanged: () => void }) {
  const o = props.o;
  const me = useMe();
  const navigate = useNavigate();
  const [open, setOpen] = useState<Action>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const save = useSave();
  if (!o.can_edit && !me.is_admin) return null;
  const remove = async () => {
    const ok = await save.run(() => send('DELETE', `/api/oom/${o.id}`));
    if (ok) navigate('/oom');
  };
  if (!o.can_edit) {
    return (
      <div className="head-actions">
        <DeleteButton confirm={confirmDelete} setConfirm={setConfirmDelete} busy={save.busy} onDelete={remove} />
        {save.error && <Notice tone="error">{save.error}</Notice>}
      </div>
    );
  }
  const linkOpen = o.status === 'pripravovane' || o.status === 'aktivne';
  const blocked = !!o.plan_id;
  const missing = o.active_missing ?? [];

  const activate = async () => {
    const ok = await save.run(() => send('POST', `/api/oom/${o.id}/status`, { status: 'aktivne' }));
    if (ok) props.onChanged();
  };

  const canEditData = o.status !== 'aktivne' || o.can_edit_active;
  return (
    <div className="head-actions">
      {o.status === 'pripravovane' && (
        <button
          type="button"
          className="btn"
          disabled={missing.length > 0 || save.busy}
          title={missing.length > 0 ? `Chýba: ${missing.join(', ')}` : 'Aktivovať hneď (inak automaticky v deň začiatku dodávky po potvrdení zmeny)'}
          onClick={activate}
        >
          Aktivovať
        </button>
      )}
      {linkOpen && (
        <>
          <button type="button" className="btn" disabled={blocked} title={blocked ? 'Najprv zrušte alebo zmeňte plánovanú zmenu.' : undefined} onClick={() => setOpen('stav')}>
            Zmeniť stav
          </button>
          <button type="button" className="btn" disabled={blocked} title={blocked ? 'Najprv zrušte alebo zmeňte plánovanú zmenu.' : undefined} onClick={() => setOpen('prepis')}>
            Prepis na iného odberateľa
          </button>
        </>
      )}
      {!linkOpen && (
        <button type="button" className="btn" onClick={() => setOpen('navrat')}>
          Návrat k Greenlogy
        </button>
      )}
      <button
        type="button"
        className="btn primary"
        disabled={!canEditData}
        title={canEditData ? undefined : 'Aktívne OOM upravuje iba tím s právom „upravovať Aktívne OOM“ (Servis, Nákup, CEO).'}
        onClick={() => setOpen('udaje')}
      >
        Upraviť údaje
      </button>
      {me.is_admin && <DeleteButton confirm={confirmDelete} setConfirm={setConfirmDelete} busy={save.busy} onDelete={remove} />}
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {open === 'udaje' && <OomEditPanel o={o} onClose={() => setOpen(null)} onSaved={() => { setOpen(null); props.onChanged(); }} />}
      {open === 'stav' && <StatusPanel o={o} onClose={() => setOpen(null)} onSaved={() => { setOpen(null); props.onChanged(); }} />}
      {open === 'prepis' && <TransferPanel o={o} onClose={() => setOpen(null)} onSaved={() => { setOpen(null); props.onChanged(); }} />}
      {open === 'navrat' && <ReconnectPanel o={o} onClose={() => setOpen(null)} onSaved={() => { setOpen(null); props.onChanged(); }} />}
    </div>
  );
}

/** Zmazanie OOM (iba admin; databáza dovolí iba OOM bez dealov, cien, ponúk, aktivít a správ OKTE). */
function DeleteButton(props: { confirm: boolean; setConfirm: (v: boolean) => void; busy: boolean; onDelete: () => void }) {
  return props.confirm ? (
    <>
      <button type="button" className="btn btn-danger-solid" disabled={props.busy} onClick={props.onDelete}>
        Naozaj zmazať OOM?
      </button>
      <button type="button" className="btn" onClick={() => props.setConfirm(false)}>
        Nie
      </button>
    </>
  ) : (
    <button
      type="button"
      className="btn btn-danger"
      title="Iba OOM bez väzieb (deal, zmluva, ponuka, aktivita); inak použite stav Zrušené."
      onClick={() => props.setConfirm(true)}
    >
      Zmazať
    </button>
  );
}

function DueNote(props: { kind: string; date: string }) {
  if (!props.date) return null;
  const due = dueOn(props.kind, props.date);
  return due <= today() ? (
    <Notice tone="ok">Deň zmeny už nastal – zmena sa urobí hneď po uložení.</Notice>
  ) : (
    <Notice tone="ok">
      Uloží sa ako plánovaná zmena; vykoná ju nočný beh {date(due)}. Dovtedy sa stav nemení a plán možno zrušiť alebo mu zmeniť dátum.
    </Notice>
  );
}

function StatusPanel(props: { o: OomCard; onClose: () => void; onSaved: () => void }) {
  const [kind, setKind] = useState<'odchod' | 'zrusenie'>('odchod');
  const [d, setD] = useState('');
  const save = useSave();
  const submit = async () => {
    const ok = await save.run(() => send('POST', `/api/oom/${props.o.id}/status`, { status: kind === 'odchod' ? 'odidene' : 'zrusene', date: d }));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Zmeniť stav – ${props.o.name ?? props.o.eic}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!d || save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <Field label="Zmena" wide>
        <Segmented
          label="Zmena stavu"
          value={kind}
          onChange={setKind}
          options={[
            { value: 'odchod', label: 'Odchod k inému dodávateľovi' },
            { value: 'zrusenie', label: 'Zrušenie OOM' },
          ]}
        />
      </Field>
      <Field label={PLAN_DATE_LABEL[kind]} wide hint="Posledný deň, keď Greenlogy dodáva. Stav sa zmení nasledujúci deň.">
        <TextInput type="date" value={d} onChange={setD} />
      </Field>
      <DueNote kind={kind} date={d} />
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

export type CustomerHit = { kind: 'company' | 'person'; id: string; name: string; ico: string | null; email: string | null; archived: boolean };

export function CustomerPicker(props: { orgId: string; value: CustomerHit | null; onChange: (v: CustomerHit | null) => void; exclude?: string }) {
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<CustomerHit[]>([]);
  useEffect(() => {
    if (q.trim().length < 2) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<{ items: CustomerHit[] }>(`/api/oom-customers?q=${encodeURIComponent(q)}&org=${props.orgId}`, ctrl.signal)
        .then((r) => setHits(r.items.filter((h) => h.id !== props.exclude)))
        .catch(() => undefined);
    }, 300);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q]); // eslint-disable-line react-hooks/exhaustive-deps
  if (props.value) {
    return (
      <span className="picked">
        {props.value.name} <span className="caption">{props.value.kind === 'company' ? `firma${props.value.ico ? ` · IČO ${props.value.ico}` : ''}` : 'domácnosť'}</span>{' '}
        <button type="button" className="btn btn-ghost" onClick={() => props.onChange(null)}>
          Zmeniť
        </button>
      </span>
    );
  }
  return (
    <>
      <TextInput value={q} onChange={setQ} placeholder="Názov firmy, IČO, meno alebo e-mail" autoFocus />
      {hits.length > 0 && (
        <div className="pick-list">
          {hits.map((h) => (
            <button key={h.id} type="button" className="pick-item" onClick={() => props.onChange(h)}>
              {h.name}{' '}
              <span className="caption">
                {h.kind === 'company' ? `firma${h.ico ? ` · IČO ${h.ico}` : ''}` : `domácnosť${h.email ? ` · ${h.email}` : ''}`}
                {h.archived ? ' · archív' : ''}
              </span>
            </button>
          ))}
        </div>
      )}
    </>
  );
}

const customerBody = (c: CustomerHit) => (c.kind === 'company' ? { company_id: c.id } : { person_id: c.id });

function TransferPanel(props: { o: OomCard; onClose: () => void; onSaved: () => void }) {
  const [target, setTarget] = useState<CustomerHit | null>(null);
  const [d, setD] = useState('');
  const save = useSave();
  const current = props.o.company_id ?? props.o.person_id ?? undefined;
  const submit = async () => {
    if (!target) return;
    const ok = await save.run(() => send('POST', `/api/oom/${props.o.id}/transfer`, { ...customerBody(target), date: d }));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Prepis na iného odberateľa – ${props.o.name ?? props.o.eic}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!target || !d || save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <p className="caption">
        EIC ostáva jeden záznam. Väzba so zákazníkom {props.o.customer_name ?? ''} sa ukončí deň pred prepisom (stav Prepísané) a nový
        odberateľ preberie OOM v tom istom stave. Kontaktné osoby pôvodného zákazníka sa odoberú.
      </p>
      <Field label="Nový odberateľ" wide hint="Firma alebo domácnosť v tej istej spoločnosti skupiny.">
        <CustomerPicker orgId={props.o.org_id} value={target} onChange={setTarget} exclude={current} />
      </Field>
      <Field label={PLAN_DATE_LABEL.prepis} wide>
        <TextInput type="date" value={d} onChange={setD} />
      </Field>
      <DueNote kind="prepis" date={d} />
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function ReconnectPanel(props: { o: OomCard; onClose: () => void; onSaved: () => void }) {
  const last = props.o.links[0];
  const lastCustomer: CustomerHit | null =
    last && last.customer_name
      ? { kind: last.customer_kind, id: (last.company_id ?? last.person_id)!, name: last.customer_name, ico: null, email: null, archived: false }
      : null;
  const [target, setTarget] = useState<CustomerHit | null>(lastCustomer);
  const [d, setD] = useState('');
  const save = useSave();
  const submit = async () => {
    if (!target) return;
    const ok = await save.run(() => send('POST', `/api/oom/${props.o.id}/reconnect`, { ...customerBody(target), date: d }));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`Návrat k Greenlogy – ${props.o.name ?? props.o.eic}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={!target || !d || save.busy} onClick={submit}>
            Uložiť
          </button>
        </>
      }
    >
      <p className="caption">
        Vznikne nové obdobie v stave Pripravované. Kroky prechodu a dodávka sa vynulujú (predošlé ostávajú v histórii).
      </p>
      <Field label="Zákazník" wide hint="Ten istý alebo iný zákazník v tej istej spoločnosti skupiny.">
        <CustomerPicker orgId={props.o.org_id} value={target} onChange={setTarget} />
      </Field>
      <Field label="Začiatok nového obdobia" wide hint={last?.valid_to ? `Musí byť po ${date(last.valid_to)} (koniec predošlého obdobia).` : undefined}>
        <TextInput type="date" value={d} onChange={setD} />
      </Field>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

/** Pás s plánovanou alebo zlyhanou zmenou na karte OOM: zmeniť dátum, zrušiť. */
export function PlanBanner(props: { o: OomCard; onChanged: () => void }) {
  const active = props.o.plans.find((p) => p.status === 'planovana');
  const failed = props.o.plans.filter((p) => p.status === 'zlyhala');
  if (!active && failed.length === 0) return null;
  return (
    <div className="plan-banners">
      {active && <PlanRow plan={active} canEdit={props.o.can_edit} onChanged={props.onChanged} />}
      {failed.map((p) => (
        <PlanRow key={p.id} plan={p} canEdit={props.o.can_edit} onChanged={props.onChanged} />
      ))}
    </div>
  );
}

function PlanRow(props: { plan: OomPlan; canEdit: boolean; onChanged: () => void }) {
  const p = props.plan;
  const [editing, setEditing] = useState(false);
  const [d, setD] = useState(p.effective_date);
  const save = useSave();
  const failed = p.status === 'zlyhala';
  const reschedule = async () => {
    const ok = await save.run(() => send('PATCH', `/api/oom-plans/${p.id}`, { date: d }));
    if (ok) {
      setEditing(false);
      props.onChanged();
    }
  };
  const cancel = async () => {
    const ok = await save.run(() => send('DELETE', `/api/oom-plans/${p.id}`));
    if (ok) props.onChanged();
  };
  return (
    <div className={`plan-banner${failed ? ' failed' : ''}`} role={failed ? 'alert' : 'status'}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div>
          <Pill tone={failed ? 'negative' : 'info'}>{failed ? 'Plán zlyhal' : PLAN_KIND_TITLE[p.kind]}</Pill>{' '}
          <b>
            {failed ? `${PLAN_KIND_TITLE[p.kind]} ` : ''}
            {p.kind === 'prepis' ? `na ${p.customer_name ?? 'iného zákazníka'} ` : ''}k {date(p.effective_date)}
          </b>{' '}
          <span className="caption">({PLAN_DATE_LABEL[p.kind].toLowerCase()})</span>
        </div>
        <div className="caption">
          {failed ? `Dôvod: ${p.error}` : `vykoná sa ${date(dueOn(p.kind, p.effective_date))} nočným behom`}
          {p.created_by_name ? ` · zadal(a) ${p.created_by_name} ${date(p.created_at)}` : ''}
        </div>
        {editing && (
          <div className="plan-edit">
            <TextInput type="date" value={d} onChange={setD} />
            <button type="button" className="btn primary" disabled={!d || save.busy} onClick={reschedule}>
              Uložiť dátum
            </button>
            <button type="button" className="btn" onClick={() => setEditing(false)}>
              Späť
            </button>
          </div>
        )}
        {save.error && <Notice tone="error">{save.error}</Notice>}
      </div>
      {props.canEdit && !editing && (
        <div className="head-actions">
          {!failed && (
            <button type="button" className="btn" onClick={() => setEditing(true)}>
              Zmeniť dátum
            </button>
          )}
          <button type="button" className="btn" disabled={save.busy} onClick={cancel}>
            {failed ? 'Zrušiť (vyriešené)' : 'Zrušiť plán'}
          </button>
        </div>
      )}
    </div>
  );
}
