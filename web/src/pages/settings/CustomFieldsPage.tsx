// Nastavenia – Vlastné polia (dizajn 14): polia jadra so zámkom, vlastné polia podľa záznamu,
// panel úpravy (typ, hodnoty výberu, sekcia, povinné, v zozname, filter, tímy, platí pre, archivácia).

import { useState } from 'react';
import { Check, Field, Notice, Segmented, Select, SidePanel, TextInput, useSave } from '../../components/form';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { EMPTY } from '../../lib/format';
import { useMe } from '../../lib/me';
import {
  CORE_FIELDS,
  type CustomField,
  EDIT_ACCESS_LABEL,
  type EditAccess,
  ENTITIES,
  type Entity,
  FIELD_TYPES,
  type FieldSection,
  type FieldType,
  type SettingsTeam,
} from '../../lib/settings';
import { InlineLabel } from './LookupsPage';
import { SettingsHead } from './SettingsLayout';

const typeLabel = (t: FieldType) => FIELD_TYPES.find((x) => x.value === t)?.label ?? t;
const isChoice = (t: FieldType) => t === 'vyber' || t === 'vyber_viac';

export function CustomFieldsPage() {
  const [entity, setEntity] = useState<Entity>('firma');
  const data = useApi<{ fields: CustomField[]; sections: FieldSection[] }>(`/api/settings/custom-fields?entity=${entity}`);
  const teams = useApi<{ items: SettingsTeam[] }>('/api/settings/teams');
  // panel: id poľa alebo 'new'; pole sa berie z čerstvo načítaných dát (po zmene hodnôt výberu)
  const [panel, setPanel] = useState<string | null>(null);
  const panelField = (data.data?.fields ?? []).find((f) => f.id === panel);
  const [showArchived, setShowArchived] = useState(false);
  const fields = (data.data?.fields ?? []).filter((f) => showArchived || !f.archived_at);
  const archivedCount = (data.data?.fields ?? []).filter((f) => f.archived_at).length;

  return (
    <>
      <SettingsHead
        title="Vlastné polia"
        sub="pridávanie polí bez programátora"
        actions={
          <button type="button" className="btn primary" onClick={() => setPanel('new')}>
            Nové pole
          </button>
        }
      />
      <Segmented label="Záznam" value={entity} onChange={(e) => setEntity(e)} options={ENTITIES} />
      <section className="card">
        {data.error ? (
          <div className="card-body">
            <ErrorState error={data.error} />
          </div>
        ) : !data.data ? (
          <div className="card-body">
            <Skeleton lines={4} />
          </div>
        ) : (
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Pole</th>
                  <th>Typ</th>
                  <th>Sekcia na karte</th>
                  <th>Povinné</th>
                  <th>V zozname</th>
                  <th>Filter</th>
                  <th>Upravujú</th>
                  <th>Stav</th>
                </tr>
              </thead>
              <tbody>
                {CORE_FIELDS[entity].map((name) => (
                  <tr key={name} className="row-muted">
                    <td>
                      {name} <span className="lock">🔒 jadro</span>
                    </td>
                    <td colSpan={6} className="caption">
                      nesie ho logika CRM
                    </td>
                    <td className="caption">mení sa v kóde</td>
                  </tr>
                ))}
                {fields.map((f) => (
                  <tr key={f.id} className="clickable" onClick={() => setPanel(f.id)}>
                    <td>
                      <button type="button" className="name-link link-button" onClick={() => setPanel(f.id)}>
                        {f.label}
                      </button>
                      {f.org_name && <div className="caption">iba {f.org_name}</div>}
                    </td>
                    <td>{typeLabel(f.field_type)}</td>
                    <td>{f.section_name ?? EMPTY}</td>
                    <td>{f.is_required ? 'áno' : EMPTY}</td>
                    <td>{f.show_in_list ? 'áno' : 'nie'}</td>
                    <td>{f.filterable ? 'áno' : 'nie'}</td>
                    <td>{f.edit_access === 'vybrane_timy' ? f.teams.map((t) => t.name).join(', ') : EDIT_ACCESS_LABEL[f.edit_access]}</td>
                    <td>{f.archived_at ? <Pill>Archivované</Pill> : <Pill tone="positive">Aktívne</Pill>}</td>
                  </tr>
                ))}
                {fields.length === 0 && (
                  <tr>
                    <td colSpan={8} className="muted">
                      Zatiaľ žiadne vlastné pole.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        )}
        <div className="card-foot team-foot">
          <span className="caption">
            Polia jadra (zámok) sa v Nastaveniach nemenia, nesie ich logika CRM. Archivované pole sa dá obnoviť, údaje ostávajú.
          </span>
          {archivedCount > 0 && (
            <Check checked={showArchived} onChange={setShowArchived}>
              Aj archivované ({archivedCount})
            </Check>
          )}
        </div>
      </section>
      {(panel === 'new' || panelField) && (
        <FieldPanel
          key={panel === 'new' ? `new-${entity}` : panel ?? ''}
          entity={entity}
          field={panelField}
          sections={data.data?.sections ?? []}
          teams={(teams.data?.items ?? []).filter((t) => !t.archived_at)}
          onClose={() => setPanel(null)}
          onSaved={() => {
            setPanel(null);
            data.reload();
          }}
          onSectionAdded={data.reload}
        />
      )}
    </>
  );
}

function FieldPanel(props: {
  entity: Entity;
  field?: CustomField;
  sections: FieldSection[];
  teams: SettingsTeam[];
  onClose: () => void;
  onSaved: () => void;
  onSectionAdded: () => void;
}) {
  const me = useMe();
  const f = props.field;
  const [label, setLabel] = useState(f?.label ?? '');
  const [type, setType] = useState<FieldType>(f?.field_type ?? 'text');
  const [refEntity, setRefEntity] = useState<Entity | ''>(f?.ref_entity ?? '');
  const [newOptions, setNewOptions] = useState<string[]>([]);
  const [optionDraft, setOptionDraft] = useState('');
  const [sectionId, setSectionId] = useState(f?.section_id ?? '');
  const [sectionDraft, setSectionDraft] = useState('');
  const [required, setRequired] = useState(f?.is_required ?? false);
  const [inList, setInList] = useState(f?.show_in_list ?? false);
  const [filterable, setFilterable] = useState(f?.filterable ?? false);
  const [access, setAccess] = useState<EditAccess>(f?.edit_access ?? 'vsetky_timy');
  const [teamIds, setTeamIds] = useState<string[]>(f?.teams.map((t) => t.id) ?? []);
  const [orgId, setOrgId] = useState(f?.org_id ?? '');
  const save = useSave();
  const archived = !!f?.archived_at;

  const addOption = () => {
    const v = optionDraft.trim();
    if (v && !newOptions.includes(v)) setNewOptions([...newOptions, v]);
    setOptionDraft('');
  };
  const addSection = async () => {
    const r = await save.run(() =>
      send<{ id: string }>('POST', '/api/settings/custom-field-sections', { entity: props.entity, name: sectionDraft }),
    );
    if (r) {
      setSectionId(r.id);
      setSectionDraft('');
      props.onSectionAdded();
    }
  };

  const body = {
    label,
    field_type: type,
    ref_entity: type === 'odkaz' ? refEntity || undefined : undefined,
    section_id: sectionId || null,
    is_required: required,
    show_in_list: inList,
    filterable,
    edit_access: access,
    team_ids: access === 'vybrane_timy' ? teamIds : [],
    org_id: orgId || null,
    options: newOptions,
  };
  const submit = async () => {
    const ok = await save.run(() =>
      f ? send('PATCH', `/api/settings/custom-fields/${f.id}`, body) : send('POST', '/api/settings/custom-fields', { ...body, entity: props.entity }),
    );
    if (ok) props.onSaved();
  };
  const setArchived = async (value: boolean) => {
    const ok = await save.run(() => send('PATCH', `/api/settings/custom-fields/${f!.id}`, { archived: value }));
    if (ok) props.onSaved();
  };
  const patchOption = async (id: string, b: object) => {
    const ok = await save.run(() => send('PATCH', `/api/settings/custom-field-options/${id}`, b));
    if (ok) props.onSectionAdded();
  };

  return (
    <SidePanel
      title={f ? `Pole „${f.label}“` : 'Nové pole'}
      onClose={props.onClose}
      footer={
        <>
          {f &&
            (archived ? (
              <button type="button" className="btn" onClick={() => setArchived(false)} disabled={save.busy}>
                Obnoviť
              </button>
            ) : (
              <button type="button" className="btn btn-danger" onClick={() => setArchived(true)} disabled={save.busy}>
                Archivovať
              </button>
            ))}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" onClick={submit} disabled={save.busy || archived || !label.trim()}>
            Uložiť pole
          </button>
        </>
      }
    >
      {archived && <Notice tone="ok">Pole je archivované: údaje ostávajú, meniť sa nedajú. Obnovením ho vrátite späť.</Notice>}
      <div className="form-grid">
        <Field label="Názov" wide hint={f ? <>Kľúč v dátach: <span className="mono">{f.key}</span> (nemení sa)</> : 'Kľúč v dátach vznikne z názvu.'}>
          <TextInput value={label} onChange={setLabel} maxLength={80} autoFocus={!f} disabled={archived} />
        </Field>
        <Field label="Typ" wide hint={f ? 'Typ sa dá zmeniť, iba kým pole nemá uložené hodnoty.' : undefined}>
          <Select value={type} onChange={setType} options={FIELD_TYPES} disabled={archived} />
        </Field>
        {type === 'odkaz' && (
          <Field label="Odkaz na záznam" wide hint="Odkazovaný záznam musí patriť tej istej spoločnosti.">
            <Select value={refEntity} onChange={setRefEntity} options={ENTITIES} placeholder="Vybrať…" disabled={archived} />
          </Field>
        )}
        {isChoice(type) && (
          <fieldset className="fieldset fl-wide">
            <legend>Hodnoty výberu</legend>
            <div className="chips">
              {f?.options.map((o) => (
                <span key={o.id} className={`chip${o.hidden_at ? ' chip-muted' : ''}`}>
                  <InlineLabel value={o.label} onSave={(l) => patchOption(o.id, { label: l })} />
                  <button type="button" className="chip-x" title={o.hidden_at ? 'Obnoviť' : 'Skryť'} onClick={() => patchOption(o.id, { hidden: !o.hidden_at })}>
                    {o.hidden_at ? '↺' : '×'}
                  </button>
                </span>
              ))}
              {newOptions.map((o) => (
                <span key={o} className="chip chip-new">
                  {o}
                  <button type="button" className="chip-x" onClick={() => setNewOptions(newOptions.filter((x) => x !== o))}>
                    ×
                  </button>
                </span>
              ))}
            </div>
            <div className="day-new">
              <input
                className="inp"
                placeholder="+ hodnota"
                aria-label="Nová hodnota výberu"
                value={optionDraft}
                maxLength={100}
                onChange={(e) => setOptionDraft(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && (e.preventDefault(), addOption())}
              />
              <button type="button" className="btn" onClick={addOption} disabled={!optionDraft.trim()}>
                Pridať
              </button>
            </div>
            <span className="caption">Hodnota sa nemaže, iba skryje (×). Kliknutím ju premenujete.</span>
          </fieldset>
        )}
        <Field label="Sekcia na karte" wide>
          <Select
            value={sectionId}
            onChange={setSectionId}
            options={[{ value: '', label: 'Bez sekcie' }, ...props.sections.map((s) => ({ value: s.id, label: s.name }))]}
            disabled={archived}
          />
        </Field>
        <div className="day-new fl-wide">
          <input className="inp" placeholder="Nová sekcia" aria-label="Nová sekcia" value={sectionDraft} maxLength={60} onChange={(e) => setSectionDraft(e.target.value)} />
          <button type="button" className="btn" onClick={addSection} disabled={!sectionDraft.trim() || save.busy}>
            + Nová sekcia
          </button>
        </div>
        <div className="fl-wide check-stack">
          <Check checked={required} onChange={setRequired} disabled={archived}>
            Povinné (kontroluje sa pri uložení formulára)
          </Check>
          <Check checked={inList} onChange={setInList} disabled={archived}>
            Zobraziť ako stĺpec v zozname
          </Check>
          <Check checked={filterable} onChange={setFilterable} disabled={archived}>
            Dá sa podľa neho filtrovať
          </Check>
        </div>
        <Field label="Upravujú" wide>
          <Select
            value={access}
            onChange={setAccess}
            options={(Object.keys(EDIT_ACCESS_LABEL) as EditAccess[]).map((v) => ({ value: v, label: EDIT_ACCESS_LABEL[v] }))}
            disabled={archived}
          />
        </Field>
        {access === 'vybrane_timy' && (
          <fieldset className="fieldset fl-wide">
            <legend>Tímy, ktoré pole upravujú</legend>
            {props.teams.map((t) => (
              <Check
                key={t.id}
                checked={teamIds.includes(t.id)}
                disabled={archived}
                onChange={(on) => setTeamIds(on ? [...teamIds, t.id] : teamIds.filter((x) => x !== t.id))}
              >
                {t.name}
              </Check>
            ))}
          </fieldset>
        )}
        <Field label="Platí pre" wide>
          <Select
            value={orgId}
            onChange={setOrgId}
            options={[{ value: '', label: 'Celú skupinu' }, ...me.orgs.map((o) => ({ value: o.id, label: o.name }))]}
            disabled={archived}
          />
        </Field>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
