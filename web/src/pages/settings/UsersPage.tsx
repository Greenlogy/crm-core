// Nastavenia – Používatelia (dizajn 12): zoznam, pozvanie s textom pozvánky, úprava, deaktivácia s odovzdaním.

import { useMemo, useState } from 'react';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { Avatar, ErrorState, Pill, Skeleton, StatusPill } from '../../components/ui';
import { type SellerType, send, useApi } from '../../lib/api';
import { EMPTY, lastSeen } from '../../lib/format';
import { ENVIRONMENT_LABEL, useMe } from '../../lib/me';
import {
  type Handover,
  invitationText,
  isGoogleLogin,
  SELLER_TYPES,
  type SettingsTeam,
  type SettingsUser,
  USER_STATUS,
} from '../../lib/settings';
import { SettingsHead } from './SettingsLayout';

type StatusFilter = 'aktivni' | 'vsetci' | 'deaktivovani';
type Panel = { kind: 'invite' } | { kind: 'edit'; user: SettingsUser } | { kind: 'invited'; name: string; email: string } | null;

export function UsersPage() {
  const users = useApi<{ items: SettingsUser[] }>('/api/settings/users');
  const teams = useApi<{ items: SettingsTeam[] }>('/api/settings/teams');
  const [q, setQ] = useState('');
  const [team, setTeam] = useState('');
  const [status, setStatus] = useState<StatusFilter>('aktivni');
  const [panel, setPanel] = useState<Panel>(null);

  const rows = useMemo(() => {
    const needle = q.trim().toLowerCase();
    return (users.data?.items ?? []).filter(
      (u) =>
        (!needle || u.name.toLowerCase().includes(needle) || u.email.toLowerCase().includes(needle)) &&
        (!team || u.team_id === team) &&
        (status === 'vsetci' || (status === 'deaktivovani') === (u.status === 'deaktivovany')),
    );
  }, [users.data, q, team, status]);

  const all = users.data?.items ?? [];
  const activeCount = all.filter((u) => u.status === 'aktivny').length;
  const invitedCount = all.filter((u) => u.status === 'pozvany').length;
  const activeTeams = (teams.data?.items ?? []).filter((t) => !t.archived_at);

  const closed = () => {
    setPanel(null);
    users.reload();
    teams.reload();
  };

  return (
    <>
      <SettingsHead
        title="Používatelia"
        sub={users.data ? `${activeCount} aktívnych · ${invitedCount} pozvaných` : undefined}
        actions={
          <button type="button" className="btn primary" onClick={() => setPanel({ kind: 'invite' })}>
            Pozvať používateľa
          </button>
        }
      />

      <section className="card">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="Hľadať používateľa"
            aria-label="Hľadať používateľa"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <select className="input" aria-label="Tím" value={team} onChange={(e) => setTeam(e.target.value)}>
            <option value="">Tím: všetky</option>
            {activeTeams.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
          <select className="input" aria-label="Stav" value={status} onChange={(e) => setStatus(e.target.value as StatusFilter)}>
            <option value="aktivni">Stav: aktívni a pozvaní</option>
            <option value="deaktivovani">Stav: deaktivovaní</option>
            <option value="vsetci">Stav: všetci</option>
          </select>
        </div>
        {users.error ? (
          <div className="card-body">
            <ErrorState error={users.error} />
          </div>
        ) : !users.data ? (
          <div className="card-body">
            <Skeleton lines={4} />
          </div>
        ) : (
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Používateľ</th>
                  <th>Tím</th>
                  <th>Spoločnosti</th>
                  <th>Nastavenia</th>
                  <th>Prihlásenie</th>
                  <th>Naposledy</th>
                  <th>Stav</th>
                </tr>
              </thead>
              <tbody>
                {rows.map((u) => (
                  <tr key={u.id} className="clickable" onClick={() => setPanel({ kind: 'edit', user: u })}>
                    <td>
                      <div className="name-cell">
                        <Avatar name={u.name} small />
                        <span>
                          <button type="button" className="name-link link-button" onClick={() => setPanel({ kind: 'edit', user: u })}>
                            {u.name}
                          </button>
                          <div className="caption">{u.email}</div>
                        </span>
                      </div>
                    </td>
                    <td>
                      <Pill tone={u.is_external ? 'warning' : 'neutral'}>{u.team_name}</Pill>
                    </td>
                    <td>{u.all_orgs ? 'Všetky' : u.orgs.map((o) => o.name).join(', ') || EMPTY}</td>
                    <td>
                      {u.is_admin || u.approves_prices || u.approves_assignments ? (
                        <>
                          {u.is_admin && <Pill tone="info">Admin</Pill>} {u.approves_prices && <Pill tone="info">Schvaľuje ceny</Pill>}{' '}
                          {u.approves_assignments && <Pill tone="info">Pridelenie firmy</Pill>}
                        </>
                      ) : (
                        EMPTY
                      )}
                    </td>
                    <td>{isGoogleLogin(u.email) ? 'Google' : 'kód e-mailom'}</td>
                    <td>{lastSeen(u.last_login_at)}</td>
                    <td>
                      <StatusPill map={USER_STATUS} value={u.status} />
                    </td>
                  </tr>
                ))}
                {rows.length === 0 && (
                  <tr>
                    <td colSpan={7} className="muted">
                      Žiadny používateľ nezodpovedá filtru.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
      </section>

      {panel?.kind === 'invite' && (
        <UserForm
          teams={activeTeams}
          onClose={() => setPanel(null)}
          onSaved={(name, email) => {
            users.reload();
            setPanel({ kind: 'invited', name, email });
          }}
        />
      )}
      {panel?.kind === 'edit' && <UserForm user={panel.user} teams={activeTeams} onClose={() => setPanel(null)} onSaved={closed} />}
      {panel?.kind === 'invited' && <InvitationPanel name={panel.name} email={panel.email} onClose={closed} />}
    </>
  );
}

// --- Pozvanie / úprava -------------------------------------------------------

function UserForm(props: {
  user?: SettingsUser;
  teams: SettingsTeam[];
  onClose: () => void;
  onSaved: (name: string, email: string) => void;
}) {
  const me = useMe();
  const u = props.user;
  const [email, setEmail] = useState(u?.email ?? '');
  const [name, setName] = useState(u?.name ?? '');
  const [teamId, setTeamId] = useState(u?.team_id ?? '');
  const [orgIds, setOrgIds] = useState<string[]>(u?.orgs.map((o) => o.id) ?? me.orgs.filter((o) => o.default).map((o) => o.id));
  const [isAdmin, setIsAdmin] = useState(u?.is_admin ?? false);
  const [sellerType, setSellerType] = useState<SellerType | ''>(u?.seller_type ?? '');
  const [approves, setApproves] = useState(u?.approves_prices ?? false);
  const [assigns, setAssigns] = useState(u?.approves_assignments ?? false);
  const [deactivate, setDeactivate] = useState(false);
  const save = useSave();
  const team = props.teams.find((t) => t.id === teamId);
  const readOnly = u?.status === 'deaktivovany';

  if (deactivate && u) {
    return <DeactivatePanel user={u} onClose={props.onClose} onDone={() => props.onSaved(u.name, u.email)} />;
  }

  const submit = async () => {
    const body = {
      name,
      team_id: teamId,
      org_ids: team?.all_orgs ? [] : orgIds,
      is_admin: team?.is_external ? false : isAdmin,
      seller_type: sellerType === '' ? null : sellerType,
      approves_prices: team?.is_external ? false : approves,
      approves_assignments: team?.is_external ? false : assigns,
    };
    const ok = await save.run(() =>
      u ? send('PATCH', `/api/settings/users/${u.id}`, body) : send('POST', '/api/settings/users', { ...body, email }),
    );
    if (ok) props.onSaved(name, email);
  };

  return (
    <SidePanel
      title={u ? u.name : 'Pozvať používateľa'}
      onClose={props.onClose}
      footer={
        readOnly ? undefined : (
          <>
            {u && u.id !== me.id && (
              <button type="button" className="btn btn-danger" onClick={() => setDeactivate(true)}>
                Deaktivovať
              </button>
            )}
            <span className="grow" />
            <button type="button" className="btn" onClick={props.onClose}>
              Zrušiť
            </button>
            <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
              {u ? 'Uložiť' : 'Pozvať'}
            </button>
          </>
        )
      }
    >
      {readOnly && <Notice tone="ok">Používateľ je deaktivovaný. Údaje sa nedajú meniť.</Notice>}
      <div className="form-grid">
        <Field label="E-mail" hint={email && (isGoogleLogin(email) ? 'Prihlási sa Google účtom.' : 'Prihlási sa jednorazovým kódom z e-mailu.')} wide>
          <TextInput type="email" value={email} onChange={setEmail} disabled={!!u} autoFocus={!u} maxLength={200} />
        </Field>
        <Field label="Meno a priezvisko" wide>
          <TextInput value={name} onChange={setName} disabled={readOnly} maxLength={120} />
        </Field>
        <Field label="Tím" wide>
          <Select
            value={teamId}
            onChange={setTeamId}
            placeholder="Vybrať tím"
            disabled={readOnly}
            options={props.teams.map((t) => ({ value: t.id, label: t.is_external ? `${t.name} (externý)` : t.name }))}
          />
        </Field>
        <fieldset className="fieldset fl-wide">
          <legend>Spoločnosti</legend>
          {team?.all_orgs ? (
            <span className="caption">Tím {team.name} vidí všetky spoločnosti skupiny.</span>
          ) : (
            me.orgs.map((o) => (
              <Check
                key={o.id}
                disabled={readOnly}
                checked={orgIds.includes(o.id)}
                onChange={(on) => setOrgIds(on ? [...orgIds, o.id] : orgIds.filter((x) => x !== o.id))}
              >
                {o.name} ({o.country}){o.status === 'pripravuje_sa' ? ' – pripravuje sa' : ''}
              </Check>
            ))
          )}
        </fieldset>
        <div className="fl-wide">
          <Check checked={isAdmin && !team?.is_external} disabled={readOnly || team?.is_external} onChange={setIsAdmin}>
            Admin – smie meniť Nastavenia
          </Check>
        </div>
        <Field label="Typ predajcu" hint="Podľa neho sa volí minimálny aditív a cena pre obchodníka.">
          <Select
            value={sellerType}
            onChange={(v) => setSellerType(v as SellerType | '')}
            disabled={readOnly}
            options={SELLER_TYPES.map((s) => ({ value: s.value, label: s.label }))}
          />
        </Field>
        <div className="fl-wide">
          <Check checked={approves && !team?.is_external} disabled={readOnly || team?.is_external} onChange={setApproves}>
            Schvaľuje ceny – výnimky z ceny a cenové parametre; vidí všetky zmluvy a maržu firmy bez ohľadu na tím
          </Check>
        </div>
        <div className="fl-wide">
          <Check checked={assigns && !team?.is_external} disabled={readOnly || team?.is_external} onChange={setAssigns}>
            Schvaľuje pridelenie firmy – keď obchodník požiada o firmu iného obchodníka; vidí všetky obchody
          </Check>
        </div>
      </div>
      <p className="caption">
        Adresa @greenlogy.com sa prihlasuje Google účtom, iná adresa jednorazovým kódom z e-mailu. Tímy CEO, Marketing a
        Nákup vidia všetky spoločnosti.
      </p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

// --- Text pozvánky -------------------------------------------------------------

function InvitationPanel(props: { name: string; email: string; onClose: () => void }) {
  const me = useMe();
  const text = invitationText(props.name, props.email, window.location.origin, ENVIRONMENT_LABEL[me.environment] ?? '');
  const [copied, setCopied] = useState(false);
  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
    } catch {
      setCopied(false);
    }
  };
  return (
    <SidePanel
      title="Používateľ pozvaný"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={copy}>
            {copied ? 'Skopírované' : 'Kopírovať text'}
          </button>
          <button type="button" className="btn primary" onClick={props.onClose}>
            Hotovo
          </button>
        </>
      }
    >
      <p>
        CRM pozvánky zatiaľ neposiela. Skopírujte text a pošlite ho na <strong>{props.email}</strong>.
      </p>
      <textarea className="inp invitation" readOnly value={text} rows={9} onFocus={(e) => e.target.select()} />
      {!isGoogleLogin(props.email) && (
        <Notice tone="error">
          Externý e-mail: kým ho nepridáte do skupiny Cloudflare Access „CRM externí“, prihlásenie neprejde.
        </Notice>
      )}
    </SidePanel>
  );
}

// --- Deaktivácia s odovzdaním (príklad 6) ----------------------------------------

function DeactivatePanel(props: { user: SettingsUser; onClose: () => void; onDone: () => void }) {
  const handover = useApi<Handover>(`/api/settings/users/${props.user.id}/handover`);
  const [owner, setOwner] = useState('');
  const save = useSave();
  const h = handover.data;
  const owns = h ? h.companies + h.contacts + h.open_deals : 0;

  const submit = async () => {
    const ok = await save.run(() =>
      send('POST', `/api/settings/users/${props.user.id}/deactivate`, owns > 0 ? { new_owner_id: owner } : {}),
    );
    if (ok) props.onDone();
  };

  return (
    <SidePanel
      title={`Deaktivovať ${props.user.name}`}
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button
            type="button"
            className="btn btn-danger-solid"
            disabled={!h || save.busy || (owns > 0 && !owner)}
            onClick={submit}
          >
            {owns > 0 ? 'Odovzdať a deaktivovať' : 'Deaktivovať'}
          </button>
        </>
      }
    >
      {handover.error ? (
        <ErrorState error={handover.error} />
      ) : !h ? (
        <Skeleton lines={2} />
      ) : owns > 0 ? (
        <>
          <p>
            Vlastní <strong>{h.companies} firiem</strong>, <strong>{h.contacts} osôb</strong> a{' '}
            <strong>{h.open_deals} otvorených dealov</strong>. Bez nového vlastníka sa deaktivácia nedokončí.
          </p>
          <Field label="Nový vlastník" wide>
            <Select
              value={owner}
              onChange={setOwner}
              placeholder="Vybrať…"
              options={h.owners.map((o) => ({ value: o.id, label: `${o.name} (${o.team_name})` }))}
            />
          </Field>
        </>
      ) : (
        <p>Nevlastní žiadnych zákazníkov ani otvorené dealy. Po deaktivácii sa už neprihlási.</p>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
