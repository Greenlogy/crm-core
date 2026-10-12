// Modul Zákazníci F2: časová os s poznámkami, osoby vo firme (roly, hlavný kontakt, pridanie, odobratie),
// „nechce marketing“ na osobe. Kto čo smie, stráži API a databáza; tu sa iba skrývajú tlačidlá.

import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { get, send, useApi, type CompanyCard, type PersonCard } from '../lib/api';
import { lastSeen } from '../lib/format';
import { useMe } from '../lib/me';
import { PersonFormPanel } from './customer-forms';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Card, Empty, Item, Pill } from './ui';

type RoleOption = { code: string; label: string; org_id: string | null; is_system: boolean; hidden_at: string | null };
type Options = { roles: RoleOption[]; opt_out_sources: string[] };

export const OPT_OUT_SOURCE_LABEL: Record<string, string> = {
  telefon: 'telefonicky',
  email: 'e-mailom',
  osobne: 'osobne',
  web: 'web',
  brevo: 'Brevo (odhlásenie z e-mailov)',
  hubspot: 'HubSpot',
  ine: 'iné',
};

export type TimelineItem = {
  id: string;
  type: string;
  subject: string | null;
  body: string | null;
  occurred_at: string;
  source: string | null;
  user_name: string | null;
  person_name: string | null;
};

const ACTIVITY_LABEL: Record<string, string> = {
  poznamka: 'Poznámka',
  email: 'E-mail',
  hovor: 'Hovor',
  chat: 'Chat',
  fb: 'Facebook',
  uloha: 'Úloha',
  web: 'Web',
  kampan: 'Kampaň',
};

// --- Časová os ---------------------------------------------------------------------------------

export function TimelineCard(props: { kind: 'company' | 'person'; id: string; items: TimelineItem[]; canAdd: boolean; onAdded: () => void }) {
  const [text, setText] = useState('');
  const save = useSave();
  const add = async () => {
    const ok = await save.run(() => send('POST', `/api/${props.kind === 'company' ? 'companies' : 'persons'}/${props.id}/notes`, { text }));
    if (ok) {
      setText('');
      props.onAdded();
    }
  };
  return (
    <Card title="Časová os" aside={<span className="caption">{props.items.length} záznamov</span>}>
      {props.canAdd && (
        <div className="note-new">
          <textarea
            className="inp"
            rows={3}
            placeholder="Poznámka (napr. čo sa dohodlo na stretnutí)"
            aria-label="Nová poznámka"
            maxLength={5000}
            value={text}
            onChange={(e) => setText(e.target.value)}
          />
          <div className="row-actions">
            <button type="button" className="btn primary" disabled={!text.trim() || save.busy} onClick={add}>
              Pridať poznámku
            </button>
          </div>
          {save.error && <Notice tone="error">{save.error}</Notice>}
        </div>
      )}
      {props.items.length === 0 ? (
        <Empty>Zatiaľ žiadna aktivita. E-maily, hovory a tickety pribudnú s modulmi Servis a Marketing.</Empty>
      ) : (
        <ol className="timeline">
          {props.items.map((a) => (
            <li key={a.id} className="timeline-item">
              <div className="timeline-head">
                <Pill tone={a.type === 'poznamka' ? 'info' : 'neutral'}>{ACTIVITY_LABEL[a.type] ?? a.type}</Pill>
                <span className="caption">
                  {lastSeen(a.occurred_at)} · {a.user_name ?? 'Systém'}
                  {a.person_name ? ` · ${a.person_name}` : ''}
                </span>
              </div>
              {a.subject && <div className="timeline-subject">{a.subject}</div>}
              {a.body && <div className="timeline-body">{a.body}</div>}
            </li>
          ))}
        </ol>
      )}
    </Card>
  );
}

// --- Osoby vo firme ----------------------------------------------------------------------------

type Contact = CompanyCard['contacts'][number] & { role_labels: string[] };

export function CompanyContactsCard(props: { company: CompanyCard; onChanged: () => void }) {
  const me = useMe();
  const c = props.company;
  const contacts = c.contacts as Contact[];
  const [adding, setAdding] = useState(false);
  const [editing, setEditing] = useState<Contact | null>(null);
  const canEdit = c.can_edit;

  return (
    <Card
      title={`Kontakty (${contacts.length})`}
      aside={
        canEdit ? (
          <button type="button" className="btn btn-ghost add-link" onClick={() => setAdding(true)}>
            + Pridať
          </button>
        ) : undefined
      }
    >
      {contacts.length === 0 ? (
        <Empty>Zatiaľ žiadne kontakty.</Empty>
      ) : (
        contacts.map((p) => (
          <Item
            key={p.id}
            title={
              <>
                <Link to={`/osoby/${p.id}`}>{[p.title, p.name].filter(Boolean).join(' ')}</Link>
                {p.role_labels.length > 0 && <span className="muted"> {p.role_labels.join(', ').toLowerCase()}</span>}
              </>
            }
            meta={[p.position, p.email, p.mobile ?? p.phone].filter(Boolean).join(' · ') || undefined}
            side={
              <>
                {p.is_main_contact && <Pill>Hlavný</Pill>}
                {p.marketing_opt_out_at && <Pill tone="negative">Nechce marketing</Pill>}
                {canEdit && (
                  <button type="button" className="btn btn-ghost" onClick={() => setEditing(p)}>
                    Roly
                  </button>
                )}
              </>
            }
          />
        ))
      )}
      {contacts.length > 1 && !contacts.some((p) => p.is_main_contact) && (
        <div className="caption" style={{ padding: '8px 0 0' }}>
          Firma nemá hlavný kontakt.
        </div>
      )}
      {adding && <AddContactPanel company={c} onClose={() => setAdding(false)} onSaved={() => { setAdding(false); props.onChanged(); }} />}
      {editing && (
        <ContactRolesPanel
          company={c}
          contact={editing}
          canMain={me.team_code !== 'servis'}
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

function RolesPicker(props: { orgId: string; value: string[]; onChange: (v: string[]) => void }) {
  const options = useApi<Options>('/api/customers/options').data;
  const roles = (options?.roles ?? []).filter(
    (r) => (r.org_id === null || r.org_id === props.orgId) && (!r.hidden_at || props.value.includes(r.code)),
  );
  return (
    <fieldset className="fieldset">
      <legend>Roly vo firme (aj viac naraz)</legend>
      {roles.map((r) => (
        <Check
          key={r.code}
          checked={props.value.includes(r.code)}
          onChange={(on) => props.onChange(on ? [...props.value, r.code] : props.value.filter((x) => x !== r.code))}
        >
          {r.label}
          {r.hidden_at ? ' (skrytá)' : ''}
        </Check>
      ))}
    </fieldset>
  );
}

function ContactRolesPanel(props: { company: CompanyCard; contact: Contact; canMain: boolean; onClose: () => void; onSaved: () => void }) {
  const [roles, setRoles] = useState<string[]>(props.contact.roles);
  const [main, setMain] = useState(props.contact.is_main_contact);
  const [confirmRemove, setConfirmRemove] = useState(false);
  const save = useSave();
  const base = `/api/companies/${props.company.id}/contacts/${props.contact.id}`;
  const submit = async () => {
    const body: Record<string, unknown> = { roles };
    if (props.canMain && main !== props.contact.is_main_contact) body.is_main_contact = main;
    const ok = await save.run(() => send('PATCH', base, body));
    if (ok) props.onSaved();
  };
  const remove = async () => {
    const ok = await save.run(() => send('DELETE', base));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title={`${props.contact.name} vo firme ${props.company.name}`}
      onClose={props.onClose}
      footer={
        <>
          {confirmRemove ? (
            <button type="button" className="btn btn-danger-solid" onClick={remove} disabled={save.busy}>
              Naozaj odobrať z firmy?
            </button>
          ) : (
            <button type="button" className="btn btn-danger" onClick={() => setConfirmRemove(true)}>
              Odobrať z firmy
            </button>
          )}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" onClick={submit} disabled={save.busy}>
            Uložiť
          </button>
        </>
      }
    >
      <RolesPicker orgId={props.company.org_id} value={roles} onChange={setRoles} />
      <div className="check-stack" style={{ marginTop: 12 }}>
        <Check checked={main} onChange={setMain} disabled={!props.canMain}>
          Hlavný kontakt firmy (najviac jeden; nový nahradí doterajšieho)
        </Check>
        {!props.canMain && <span className="caption">Hlavný kontakt Servis nemení.</span>}
      </div>
      <p className="caption">Odobratím z firmy sa osoba nezmaže – ostáva v Kontaktoch.</p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

type PersonHit = { id: string; name: string; email: string | null; phone: string | null };

function AddContactPanel(props: { company: CompanyCard; onClose: () => void; onSaved: () => void }) {
  const me = useMe();
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<PersonHit[]>([]);
  const [person, setPerson] = useState<PersonHit | null>(null);
  const [roles, setRoles] = useState<string[]>([]);
  const [main, setMain] = useState(false);
  const [creating, setCreating] = useState(false);
  const save = useSave();
  const exclude = new Set(props.company.contacts.map((p) => p.id));

  useEffect(() => {
    if (q.trim().length < 2) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    const t = setTimeout(() => {
      get<{ items: PersonHit[] }>(`/api/persons/search?q=${encodeURIComponent(q)}&org=${props.company.org_id}`, ctrl.signal)
        .then((r) => setHits(r.items.filter((h) => !exclude.has(h.id))))
        .catch(() => undefined);
    }, 300);
    return () => {
      clearTimeout(t);
      ctrl.abort();
    };
  }, [q]); // eslint-disable-line react-hooks/exhaustive-deps

  if (creating) {
    return (
      <PersonFormPanel
        household={false}
        company={{ id: props.company.id, name: props.company.name, ico: props.company.ico }}
        stay
        onClose={props.onClose}
        onSaved={props.onSaved}
      />
    );
  }

  const submit = async () => {
    if (!person) return;
    const body: Record<string, unknown> = { contact_id: person.id, roles };
    if (main && me.team_code !== 'servis') body.is_main_contact = true;
    const ok = await save.run(() => send('POST', `/api/companies/${props.company.id}/contacts`, body));
    if (ok) props.onSaved();
  };

  return (
    <SidePanel
      title={`Pridať osobu do ${props.company.name}`}
      onClose={props.onClose}
      footer={
        <>
          {me.team_code !== 'servis' && (
            <button type="button" className="btn" onClick={() => setCreating(true)}>
              Nová osoba
            </button>
          )}
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
      <Field label="Existujúca osoba" wide hint="Hľadá meno, e-mail alebo telefón v spoločnosti firmy.">
        {person ? (
          <span className="picked">
            {person.name} <span className="caption">{person.email ?? person.phone}</span>{' '}
            <button type="button" className="btn btn-ghost" onClick={() => setPerson(null)}>
              Zmeniť
            </button>
          </span>
        ) : (
          <>
            <TextInput value={q} onChange={setQ} placeholder="Hľadať osobu" autoFocus />
            {hits.length > 0 && (
              <div className="pick-list">
                {hits.map((h) => (
                  <button key={h.id} type="button" className="pick-item" onClick={() => setPerson(h)}>
                    {h.name} <span className="caption">{h.email ?? h.phone}</span>
                  </button>
                ))}
              </div>
            )}
          </>
        )}
      </Field>
      {person && (
        <>
          <RolesPicker orgId={props.company.org_id} value={roles} onChange={setRoles} />
          {me.team_code !== 'servis' && (
            <div className="check-stack" style={{ marginTop: 12 }}>
              <Check checked={main} onChange={setMain}>
                Hlavný kontakt firmy
              </Check>
            </div>
          )}
        </>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

// --- Nechce marketing ----------------------------------------------------------------------------

export function MarketingPanel(props: { person: PersonCard; onClose: () => void; onSaved: () => void }) {
  const options = useApi<Options>('/api/customers/options').data;
  const p = props.person;
  const [source, setSource] = useState('');
  const save = useSave();
  const set = async (optOut: boolean) => {
    const ok = await save.run(() => send('PATCH', `/api/persons/${p.id}/marketing`, optOut ? { opt_out: true, source } : { opt_out: false }));
    if (ok) props.onSaved();
  };
  return (
    <SidePanel
      title="Marketing"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          {p.marketing_opt_out_at ? (
            <button type="button" className="btn primary" onClick={() => set(false)} disabled={save.busy}>
              Zrušiť „nechce marketing“
            </button>
          ) : (
            <button type="button" className="btn btn-danger-solid" onClick={() => set(true)} disabled={!source || save.busy}>
              Nechce marketing
            </button>
          )}
        </>
      }
    >
      {p.marketing_opt_out_at ? (
        <p>
          Osoba nechce marketing od {lastSeen(p.marketing_opt_out_at)} ({OPT_OUT_SOURCE_LABEL[p.marketing_opt_out_source ?? ''] ?? p.marketing_opt_out_source}).
          Zrušte iba vtedy, ak marketing znova výslovne povolila.
        </p>
      ) : (
        <>
          <p>Osoba nebude dostávať marketingové e-maily ani kampane. Plná evidencia súhlasov príde v module Marketing.</p>
          <Field label="Ako to oznámila" wide>
            <Select
              value={source}
              onChange={setSource}
              placeholder="Vybrať…"
              options={(options?.opt_out_sources ?? []).map((s) => ({ value: s, label: OPT_OUT_SOURCE_LABEL[s] ?? s }))}
            />
          </Field>
        </>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
