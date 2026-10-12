// Nastavenia – Tímy a práva (dizajn 13): tímy hore, matica modul × vidieť / upravovať / archivovať / exportovať.
// Poistky (externý tím bez „všetko“, upravovať najviac toľko ako vidieť) stráži databáza; obrazovka ich
// navyše ukazuje vopred.

import { useEffect, useState } from 'react';
import { Check, Field, Notice, Segmented, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { type ModuleCode, type Permission, type Scope, send, useApi } from '../../lib/api';
import { MODULES, SCOPES, type SettingsTeam } from '../../lib/settings';
import { SettingsHead } from './SettingsLayout';

const RANK: Record<Scope, number> = { nic: 0, iba_svoje: 1, vsetko: 2 };
const NONE: Permission = { view: 'nic', edit: 'nic', archive: false, export: false };

export function TeamsPage() {
  const teams = useApi<{ items: SettingsTeam[] }>('/api/settings/teams');
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const list = teams.data?.items ?? [];
  const selected = list.find((t) => t.id === selectedId) ?? list.find((t) => !t.archived_at);

  if (teams.error) return <ErrorState error={teams.error} />;

  return (
    <>
      <SettingsHead title="Tímy a práva" sub="práva sa nastavujú tímu, nie jednotlivým ľuďom" />
      {!teams.data ? (
        <Skeleton lines={4} />
      ) : (
        <>
          <div className="team-tiles" role="tablist" aria-label="Tímy">
            {list.map((t) => (
              <button
                key={t.id}
                type="button"
                role="tab"
                aria-selected={t.id === selected?.id}
                className={`team-tile${t.id === selected?.id ? ' active' : ''}${t.archived_at ? ' archived' : ''}`}
                onClick={() => setSelectedId(t.id)}
              >
                <span className="team-tile-name">{t.name}</span>
                <span className="caption">
                  {t.archived_at ? 'archivovaný' : t.all_orgs ? 'všetky spoločnosti' : 'pridelené'} · {t.members}{' '}
                  {t.members === 1 ? 'človek' : t.members >= 2 && t.members <= 4 ? 'ľudia' : 'ľudí'}
                </span>
              </button>
            ))}
            <button type="button" className="team-tile team-tile-new" onClick={() => setCreating(true)}>
              + Nový tím
            </button>
          </div>
          {selected && <TeamDetail key={selected.id} team={selected} onSaved={teams.reload} />}
        </>
      )}
      {creating && (
        <NewTeamPanel
          onClose={() => setCreating(false)}
          onCreated={(id) => {
            setCreating(false);
            setSelectedId(id);
            teams.reload();
          }}
        />
      )}
    </>
  );
}

function TeamDetail(props: { team: SettingsTeam; onSaved: () => void }) {
  const t = props.team;
  const initial = () => Object.fromEntries(MODULES.map((m) => [m.code, t.permissions[m.code] ?? NONE])) as Record<ModuleCode, Permission>;
  const [perms, setPerms] = useState<Record<ModuleCode, Permission>>(initial);
  const [allOrgs, setAllOrgs] = useState(t.all_orgs);
  const [name, setName] = useState(t.name);
  const [description, setDescription] = useState(t.description ?? '');
  const [saved, setSaved] = useState(false);
  const save = useSave();
  useEffect(() => setSaved(false), [perms, allOrgs, name, description]);

  const dirty =
    JSON.stringify(perms) !== JSON.stringify(initial()) ||
    allOrgs !== t.all_orgs ||
    name !== t.name ||
    description !== (t.description ?? '');

  const set = (code: ModuleCode, patch: Partial<Permission>) =>
    setPerms((p) => {
      const next = { ...p[code], ...patch };
      // upravovať najviac toľko, ako tím vidí
      if (patch.view && RANK[next.edit] > RANK[patch.view]) next.edit = patch.view;
      if (patch.edit && RANK[patch.edit] > RANK[next.view]) next.view = patch.edit;
      return { ...p, [code]: next };
    });

  const submit = async () => {
    const ok = await save.run(async () => {
      if (name !== t.name || description !== (t.description ?? '') || allOrgs !== t.all_orgs) {
        await send('PATCH', `/api/settings/teams/${t.id}`, { name, description, all_orgs: allOrgs });
      }
      await send('PATCH', `/api/settings/teams/${t.id}/permissions`, { permissions: perms });
      return true;
    });
    if (ok) {
      setSaved(true);
      props.onSaved();
    }
  };

  const archive = async (archived: boolean) => {
    const ok = await save.run(() => send('PATCH', `/api/settings/teams/${t.id}`, { archived }));
    if (ok) props.onSaved();
  };

  const scopeOptions = SCOPES.map((s) => ({ ...s, disabled: t.is_external && s.value === 'vsetko' }));

  return (
    <section className="card" aria-label={`Tím ${t.name}`}>
      <div className="card-head team-head">
        <div>
          <h2 className="t-section-title">
            {t.name}
            {t.is_external && <span className="muted"> · externý obchodník</span>}
          </h2>
          <div className="caption">
            {t.members} {t.members === 1 ? 'človek' : 'ľudí'}
            {t.member_names ? ` · ${t.member_names}${t.members > 3 ? ' a ďalší' : ''}` : ''}
          </div>
        </div>
        <div className="head-actions">
          <Segmented
            label="Spoločnosti"
            value={allOrgs ? 'vsetky' : 'pridelene'}
            onChange={(v) => setAllOrgs(v === 'vsetky')}
            options={[
              { value: 'pridelene', label: 'Iba pridelené' },
              { value: 'vsetky', label: 'Všetky', disabled: t.is_external },
            ]}
          />
          <button type="button" className="btn primary" disabled={!dirty || save.busy || !!t.archived_at} onClick={submit}>
            Uložiť zmeny
          </button>
        </div>
      </div>
      <div className="card-body form-grid">
        <Field label="Názov tímu">
          <TextInput value={name} onChange={setName} maxLength={60} disabled={!!t.archived_at} />
        </Field>
        <Field label="Popis">
          <TextInput value={description} onChange={setDescription} maxLength={200} disabled={!!t.archived_at} />
        </Field>
      </div>
      {t.is_external && (
        <div className="card-body">
          <Pill tone="warning">„Iba svoje“ platí aj priamo v databáze</Pill>{' '}
          <span className="caption">Externý tím nemôže dostať „Všetko“ ani všetky spoločnosti.</span>
        </div>
      )}
      <div className="table-wrap">
        <table className="tbl perm-table">
          <thead>
            <tr>
              <th>Modul</th>
              <th>Vidieť</th>
              <th>Upravovať</th>
              <th>Archivovať</th>
              <th>Exportovať</th>
            </tr>
          </thead>
          <tbody>
            {MODULES.map((m) => (
              <tr key={m.code}>
                <td>{m.label}</td>
                <td>
                  <Segmented small label={`${m.label} – vidieť`} value={perms[m.code].view} onChange={(v) => set(m.code, { view: v })} options={scopeOptions} />
                </td>
                <td>
                  <Segmented small label={`${m.label} – upravovať`} value={perms[m.code].edit} onChange={(v) => set(m.code, { edit: v })} options={scopeOptions} />
                </td>
                <td>
                  <Check checked={perms[m.code].archive} onChange={(v) => set(m.code, { archive: v })}>
                    <span className="sr-only">{m.label} – archivovať</span>
                  </Check>
                </td>
                <td>
                  <Check checked={perms[m.code].export} onChange={(v) => set(m.code, { export: v })}>
                    <span className="sr-only">{m.label} – exportovať</span>
                  </Check>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
      <div className="card-foot team-foot">
        <span className="caption">„Iba svoje“ = záznamy, kde je používateľ vlastníkom. Zmena platí pre všetkých členov tímu naraz.</span>
        {t.archived_at ? (
          <button type="button" className="btn" onClick={() => archive(false)} disabled={save.busy}>
            Obnoviť tím
          </button>
        ) : (
          !['ceo', 'sales_internal', 'sales_external', 'servis', 'nakup', 'marketing'].includes(t.code) && (
            <button type="button" className="btn" onClick={() => archive(true)} disabled={save.busy}>
              Archivovať tím
            </button>
          )
        )}
      </div>
      {save.error && (
        <div className="card-body">
          <Notice tone="error">{save.error}</Notice>
        </div>
      )}
      {saved && !save.error && (
        <div className="card-body">
          <Notice tone="ok">Uložené. Platí pre všetkých členov tímu.</Notice>
        </div>
      )}
    </section>
  );
}

function NewTeamPanel(props: { onClose: () => void; onCreated: (id: string) => void }) {
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [allOrgs, setAllOrgs] = useState(false);
  const [external, setExternal] = useState(false);
  const save = useSave();
  const submit = async () => {
    const r = await save.run(() =>
      send<{ id: string }>('POST', '/api/settings/teams', {
        name,
        description,
        all_orgs: external ? false : allOrgs,
        is_external: external,
      }),
    );
    if (r) props.onCreated(r.id);
  };
  return (
    <SidePanel
      title="Nový tím"
      onClose={props.onClose}
      footer={
        <>
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !name.trim()} onClick={submit}>
            Založiť tím
          </button>
        </>
      }
    >
      <div className="form-grid">
        <Field label="Názov tímu" wide>
          <TextInput value={name} onChange={setName} autoFocus maxLength={60} />
        </Field>
        <Field label="Popis" wide>
          <TextInput value={description} onChange={setDescription} maxLength={200} />
        </Field>
        <div className="fl-wide">
          <Check checked={external} onChange={setExternal}>
            Externý tím (partneri mimo Greenlogy) – nikdy nedostane „Všetko“
          </Check>
        </div>
        <div className="fl-wide">
          <Check checked={allOrgs && !external} disabled={external} onChange={setAllOrgs}>
            Vidí všetky spoločnosti skupiny
          </Check>
        </div>
      </div>
      <p className="caption">Nový tím má vo všetkých moduloch právo „Nič“. Práva nastavíte po založení.</p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
