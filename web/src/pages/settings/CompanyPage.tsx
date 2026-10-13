// Nastavenia – Spoločnosť (dizajn 11): údaje do dokumentov, logo, bankové účty, pracovný čas a voľné dni.
// Krajina, mena a stav spoločnosti sú jadro (menia sa v kóde), štátne sviatky dopĺňa migrácia.

import { useEffect, useState } from 'react';
import { Check, Field, Notice, TextInput, useSave } from '../../components/form';
import { Card, ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { date, EMPTY } from '../../lib/format';
import {
  type BankPurpose,
  COUNTRY_LABEL,
  formatIban,
  type OrgDetail,
  PURPOSE_LABEL,
  REG_NO_LABEL,
  REGULATOR,
  type SettingsOrg,
  WEEKDAYS,
} from '../../lib/settings';
import { SettingsHead } from './SettingsLayout';

type OrgForm = Record<
  | 'legal_name'
  | 'reg_no'
  | 'tax_no'
  | 'vat_no'
  | 'address'
  | 'registry_entry'
  | 'statutory'
  | 'support_phone'
  | 'email'
  | 'web'
  | 'regulator_license',
  string
>;

const toForm = (o: SettingsOrg): OrgForm => ({
  legal_name: o.legal_name,
  reg_no: o.reg_no ?? '',
  tax_no: o.tax_no ?? '',
  vat_no: o.vat_no ?? '',
  address: o.address ?? '',
  registry_entry: o.registry_entry ?? '',
  statutory: o.statutory ?? '',
  support_phone: o.support_phone ?? '',
  email: o.email ?? '',
  web: o.web ?? '',
  regulator_license: o.regulator_license ?? '',
});

export function CompanyPage() {
  const orgs = useApi<{ items: SettingsOrg[] }>('/api/settings/orgs');
  const [orgId, setOrgId] = useState<string | null>(null);
  const list = orgs.data?.items ?? [];
  const org = list.find((o) => o.id === orgId) ?? list[0];

  if (orgs.error) return <ErrorState error={orgs.error} />;
  return (
    <>
      <SettingsHead title="Spoločnosť" sub="údaje firmy, mena a pracovný čas" />
      {!org ? (
        <Skeleton lines={6} />
      ) : (
        <>
          <div className="org-tabs" role="tablist" aria-label="Spoločnosti">
            {list.map((o) => (
              <button
                key={o.id}
                type="button"
                role="tab"
                aria-selected={o.id === org.id}
                className={`btn org-tab${o.id === org.id ? ' active' : ''}`}
                onClick={() => setOrgId(o.id)}
              >
                {o.legal_name}{' '}
                <Pill tone={o.status === 'aktivna' ? 'positive' : 'neutral'}>
                  {o.country} · {o.currency}
                  {o.status === 'pripravuje_sa' ? ' · pripravuje sa' : ''}
                </Pill>
              </button>
            ))}
          </div>
          <OrgEditor key={org.id} org={org} onSaved={orgs.reload} />
        </>
      )}
    </>
  );
}

function OrgEditor(props: { org: SettingsOrg; onSaved: () => void }) {
  const o = props.org;
  const detail = useApi<OrgDetail>(`/api/settings/orgs/${o.id}/detail`);
  const [form, setForm] = useState<OrgForm>(() => toForm(o));
  const save = useSave();
  const [saved, setSaved] = useState(false);
  const dirty = JSON.stringify(form) !== JSON.stringify(toForm(o));
  useEffect(() => setSaved(false), [form]);

  const field = (key: keyof OrgForm, label: string, placeholder?: string) => (
    <Field label={label}>
      <TextInput value={form[key]} placeholder={placeholder} onChange={(v) => setForm({ ...form, [key]: v })} />
    </Field>
  );

  const submit = async () => {
    const ok = await save.run(() => send('PATCH', `/api/settings/orgs/${o.id}`, form));
    if (ok) {
      setSaved(true);
      props.onSaved();
    }
  };

  return (
    <div className="settings-columns">
      <div className="settings-col-main">
        <Card
          title="Údaje do dokumentov"
          aside={
            <button type="button" className="btn primary" disabled={!dirty || save.busy} onClick={submit}>
              Uložiť zmeny
            </button>
          }
        >
          <p className="caption card-lead">Hlavička ponúk, zmlúv a e-mailov.</p>
          <div className="form-grid">
            {field('legal_name', 'Obchodné meno')}
            <Field label="Krajina">
              <TextInput value={`${COUNTRY_LABEL[o.country]} · ${o.currency}`} onChange={() => undefined} disabled />
            </Field>
            {field('reg_no', REG_NO_LABEL[o.country], o.country === 'HR' ? '11 číslic' : '8 číslic')}
            {field('tax_no', 'DIČ')}
            {field('vat_no', 'IČ DPH')}
            {field('address', 'Sídlo', 'ulica, PSČ, obec')}
            {field('registry_entry', 'Zápis v obchodnom registri', 'súd, oddiel, vložka')}
            {field('statutory', 'Štatutári', 'meno, funkcia; meno, funkcia')}
            {field('support_phone', 'Zákaznícka linka')}
            {field('email', 'E-mail')}
            {field('web', 'Web')}
            {field('regulator_license', `Povolenie regulátora (${REGULATOR[o.country]})`)}
          </div>
          {save.error && <Notice tone="error">{save.error}</Notice>}
          {saved && !save.error && <Notice tone="ok">Uložené.</Notice>}
        </Card>
        {detail.error ? <ErrorState error={detail.error} /> : <BankAccounts org={o} detail={detail.data} onChanged={detail.reload} />}
      </div>
      <div className="settings-col-side">
        <Logo org={o} onChanged={props.onSaved} />
        {detail.data ? <WorkTime org={o} detail={detail.data} onChanged={detail.reload} /> : <Skeleton lines={5} />}
        <SwitchDays org={o} onSaved={props.onSaved} />
      </div>
    </div>
  );
}

// --- Bankové účty ------------------------------------------------------------

function BankAccounts(props: { org: SettingsOrg; detail?: OrgDetail; onChanged: () => void }) {
  const [adding, setAdding] = useState(false);
  const [showArchived, setShowArchived] = useState(false);
  const [iban, setIban] = useState('');
  const [bankName, setBankName] = useState('');
  const [bic, setBic] = useState('');
  const [purposes, setPurposes] = useState<BankPurpose[]>([]);
  const save = useSave();
  const accounts = (props.detail?.accounts ?? []).filter((a) => showArchived || !a.archived_at);
  const archivedCount = (props.detail?.accounts ?? []).filter((a) => a.archived_at).length;

  const toggle = (list: BankPurpose[], p: BankPurpose) => (list.includes(p) ? list.filter((x) => x !== p) : [...list, p]);

  const add = async () => {
    const ok = await save.run(() =>
      send('POST', `/api/settings/orgs/${props.org.id}/bank-accounts`, {
        iban,
        bank_name: bankName,
        bic,
        purposes,
        is_primary: (props.detail?.accounts ?? []).every((a) => a.archived_at || !a.is_primary),
      }),
    );
    if (ok) {
      setAdding(false);
      setIban('');
      setBankName('');
      setBic('');
      setPurposes([]);
      props.onChanged();
    }
  };

  const patch = async (id: string, body: object) => {
    const ok = await save.run(() => send('PATCH', `/api/settings/bank-accounts/${id}`, body));
    if (ok) props.onChanged();
  };

  return (
    <Card
      title="Bankové účty"
      aside={
        archivedCount > 0 ? (
          <Check checked={showArchived} onChange={setShowArchived}>
            Aj archivované ({archivedCount})
          </Check>
        ) : undefined
      }
    >
      {!props.detail ? (
        <Skeleton lines={2} />
      ) : (
        <div className="bank-list">
          {accounts.length === 0 && <div className="caption">Zatiaľ žiadny účet.</div>}
          {accounts.map((a) => (
            <div key={a.id} className={`bank-row${a.archived_at ? ' archived' : ''}`}>
              <div className="bank-main">
                <span className="mono">{formatIban(a.iban)}</span>
                <span className="caption">{[a.bank_name, a.bic].filter(Boolean).join(' · ') || EMPTY}</span>
              </div>
              <div className="bank-purposes">
                {(['faktury', 'zalohy', 'vykup'] as BankPurpose[]).map((p) => (
                  <Check
                    key={p}
                    checked={a.purposes.includes(p)}
                    disabled={!!a.archived_at || save.busy}
                    onChange={() => patch(a.id, { purposes: toggle(a.purposes, p) })}
                  >
                    {PURPOSE_LABEL[p]}
                  </Check>
                ))}
              </div>
              <div className="bank-actions">
                {a.archived_at ? (
                  <button type="button" className="btn" onClick={() => patch(a.id, { archived: false })}>
                    Obnoviť
                  </button>
                ) : (
                  <>
                    {a.is_primary ? (
                      <Pill tone="positive">Hlavný</Pill>
                    ) : (
                      <button type="button" className="btn btn-ghost" onClick={() => patch(a.id, { is_primary: true })}>
                        Nastaviť ako hlavný
                      </button>
                    )}
                    <button type="button" className="btn btn-ghost" onClick={() => patch(a.id, { archived: true })}>
                      Archivovať
                    </button>
                  </>
                )}
              </div>
            </div>
          ))}
          {adding ? (
            <div className="bank-new">
              <div className="form-grid">
                <Field label="IBAN">
                  <TextInput value={iban} onChange={setIban} placeholder="SK.." autoFocus maxLength={50} />
                </Field>
                <Field label="Banka">
                  <TextInput value={bankName} onChange={setBankName} maxLength={100} />
                </Field>
                <Field label="BIC">
                  <TextInput value={bic} onChange={setBic} maxLength={20} />
                </Field>
              </div>
              <div className="bank-purposes">
                {(['faktury', 'zalohy', 'vykup'] as BankPurpose[]).map((p) => (
                  <Check key={p} checked={purposes.includes(p)} onChange={() => setPurposes(toggle(purposes, p))}>
                    {PURPOSE_LABEL[p]}
                  </Check>
                ))}
              </div>
              <div className="row-actions">
                <button type="button" className="btn" onClick={() => setAdding(false)}>
                  Zrušiť
                </button>
                <button type="button" className="btn primary" disabled={!iban.trim() || save.busy} onClick={add}>
                  Pridať účet
                </button>
              </div>
            </div>
          ) : (
            <button type="button" className="btn btn-ghost add-link" onClick={() => setAdding(true)}>
              + Pridať účet
            </button>
          )}
        </div>
      )}
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p className="caption">Účet sa nemaže, iba archivuje – staré dokumenty ho zobrazujú ďalej.</p>
    </Card>
  );
}

// --- Logo ----------------------------------------------------------------------

function Logo(props: { org: SettingsOrg; onChanged: () => void }) {
  const save = useSave();
  const version = props.org.logo_updated_at ?? '';
  const upload = async (file: File) => {
    if (!['image/svg+xml', 'image/png'].includes(file.type)) {
      save.setError('Logo musí byť SVG alebo PNG.');
      return;
    }
    if (file.size > 524_288) {
      save.setError('Logo môže mať najviac 512 kB.');
      return;
    }
    const buf = new Uint8Array(await file.arrayBuffer());
    let bin = '';
    for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode(...buf.subarray(i, i + 0x8000));
    const ok = await save.run(() => send('POST', `/api/settings/orgs/${props.org.id}/logo`, { mime: file.type, data: btoa(bin) }));
    if (ok) props.onChanged();
  };
  const remove = async () => {
    const ok = await save.run(() => send('DELETE', `/api/settings/orgs/${props.org.id}/logo`));
    if (ok) props.onChanged();
  };
  return (
    <Card title="Logo">
      <div
        className="logo-drop"
        onDragOver={(e) => e.preventDefault()}
        onDrop={(e) => {
          e.preventDefault();
          const f = e.dataTransfer.files[0];
          if (f) void upload(f);
        }}
      >
        {props.org.logo_updated_at ? (
          <img src={`/api/settings/orgs/${props.org.id}/logo?v=${encodeURIComponent(version)}`} alt={`Logo ${props.org.legal_name}`} />
        ) : (
          <span className="caption">Pretiahni sem logo (SVG alebo PNG, do 512 kB)</span>
        )}
      </div>
      <div className="row-actions">
        <label className="btn">
          Vybrať súbor
          <input
            type="file"
            accept="image/svg+xml,image/png"
            hidden
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) void upload(f);
              e.target.value = '';
            }}
          />
        </label>
        {props.org.logo_updated_at && (
          <button type="button" className="btn btn-ghost" onClick={remove} disabled={save.busy}>
            Odstrániť
          </button>
        )}
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </Card>
  );
}

// --- Pracovný čas a voľné dni ----------------------------------------------------

type Day = { on: boolean; from: string; to: string };

function WorkTime(props: { org: SettingsOrg; detail: OrgDetail; onChanged: () => void }) {
  const initial = (): Day[] =>
    WEEKDAYS.map((_, i) => {
      const h = props.detail.hours.find((x) => x.weekday === i + 1);
      return h ? { on: true, from: h.work_from, to: h.work_to } : { on: false, from: '07:30', to: '15:30' };
    });
  const [days, setDays] = useState<Day[]>(initial);
  const [newDate, setNewDate] = useState('');
  const [newName, setNewName] = useState('Firemné voľno');
  const [showHolidays, setShowHolidays] = useState(false);
  const save = useSave();
  const dirty = JSON.stringify(days) !== JSON.stringify(initial());
  const set = (i: number, patch: Partial<Day>) => setDays(days.map((d, j) => (i === j ? { ...d, ...patch } : d)));

  const saveHours = async () => {
    const body = { days: days.flatMap((d, i) => (d.on ? [{ weekday: i + 1, from: d.from, to: d.to }] : [])) };
    const ok = await save.run(() => send('PATCH', `/api/settings/orgs/${props.org.id}/work-hours`, body));
    if (ok) props.onChanged();
  };
  const addDay = async () => {
    const ok = await save.run(() => send('POST', `/api/settings/orgs/${props.org.id}/days-off`, { date: newDate, name: newName }));
    if (ok) {
      setNewDate('');
      props.onChanged();
    }
  };
  const removeDay = async (id: string) => {
    const ok = await save.run(() => send('DELETE', `/api/settings/days-off/${id}`));
    if (ok) props.onChanged();
  };

  const holidays = props.detail.days_off.filter((d) => d.kind === 'statny_sviatok');
  const companyDays = props.detail.days_off.filter((d) => d.kind === 'firemne_volno');

  return (
    <Card
      title="Pracovný čas"
      aside={
        <button type="button" className="btn primary" disabled={!dirty || save.busy} onClick={saveHours}>
          Uložiť
        </button>
      }
    >
      <p className="caption card-lead">Pre výpočet SLA (8 a 24 pracovných hodín).</p>
      <div className="hours">
        {WEEKDAYS.map((name, i) => (
          <div key={name} className="hours-row">
            <Check checked={days[i].on} onChange={(on) => set(i, { on })}>
              {name}
            </Check>
            {days[i].on ? (
              <span className="hours-time">
                <input className="inp" type="time" value={days[i].from} onChange={(e) => set(i, { from: e.target.value })} aria-label={`${name} od`} />
                –
                <input className="inp" type="time" value={days[i].to} onChange={(e) => set(i, { to: e.target.value })} aria-label={`${name} do`} />
              </span>
            ) : (
              <span className="caption">voľno</span>
            )}
          </div>
        ))}
      </div>

      <div className="days-off">
        <div className="days-off-head">
          <strong>Štátne sviatky {COUNTRY_LABEL[props.org.country]}</strong>
          <span className="caption">
            automaticky
            {props.detail.calendar_to ? `, kalendár do ${date(props.detail.calendar_to)}` : ' – zatiaľ nie sú zadané, SLA sa nepočíta'}
          </span>
        </div>
        {holidays.length > 0 && (
          <button type="button" className="btn btn-ghost add-link" onClick={() => setShowHolidays(!showHolidays)}>
            {showHolidays ? 'Skryť' : `Zobraziť (${holidays.length})`}
          </button>
        )}
        {showHolidays && (
          <ul className="day-list">
            {holidays.map((d) => (
              <li key={d.id}>
                <span>{date(d.date)}</span>
                <span className="caption">{d.name}</span>
              </li>
            ))}
          </ul>
        )}

        <div className="days-off-head">
          <strong>Firemné voľno</strong>
        </div>
        <ul className="day-list">
          {companyDays.length === 0 && <li className="caption">Žiadne.</li>}
          {companyDays.map((d) => (
            <li key={d.id}>
              <span>{date(d.date)}</span>
              <span className="caption">{d.name}</span>
              <button type="button" className="btn btn-ghost" onClick={() => removeDay(d.id)} disabled={save.busy}>
                Odstrániť
              </button>
            </li>
          ))}
        </ul>
        <div className="day-new">
          <input className="inp" type="date" value={newDate} onChange={(e) => setNewDate(e.target.value)} aria-label="Dátum voľna" />
          <input className="inp" value={newName} onChange={(e) => setNewName(e.target.value)} aria-label="Názov voľna" maxLength={100} />
          <button type="button" className="btn" disabled={!newDate || !newName.trim() || save.busy} onClick={addDay}>
            + Pridať voľný deň
          </button>
        </div>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </Card>
  );
}

// --- Odberné miesta: lehoty „prechod sa zasekol“ (modul OOM, Peter 12. 10.) ---

function SwitchDays(props: { org: SettingsOrg; onSaved: () => void }) {
  const [accept, setAccept] = useState(String(props.org.oom_switch_accept_days));
  const [confirm, setConfirm] = useState(String(props.org.oom_switch_confirm_days));
  const save = useSave();
  const [saved, setSaved] = useState(false);
  const dirty = accept !== String(props.org.oom_switch_accept_days) || confirm !== String(props.org.oom_switch_confirm_days);
  const submit = async () => {
    const ok = await save.run(() =>
      send('PATCH', `/api/settings/orgs/${props.org.id}`, { oom_switch_accept_days: Number(accept), oom_switch_confirm_days: Number(confirm) }),
    );
    if (ok) {
      setSaved(true);
      props.onSaved();
    }
  };
  return (
    <Card
      title="Odberné miesta"
      aside={
        <button type="button" className="btn primary" disabled={!dirty || save.busy} onClick={submit}>
          Uložiť
        </button>
      }
    >
      <p className="caption card-lead">„Prechod sa zasekol“: koľko dní môže prechod k Greenlogy čakať na ďalší krok.</p>
      <div className="form-grid">
        <Field label="Výpoveď odoslaná, bez akceptácie [dni]">
          <TextInput type="number" value={accept} onChange={(v) => { setAccept(v); setSaved(false); }} />
        </Field>
        <Field label="Výpoveď akceptovaná, bez potvrdenia zmeny [dni]">
          <TextInput type="number" value={confirm} onChange={(v) => { setConfirm(v); setSaved(false); }} />
        </Field>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {saved && !save.error && <Notice tone="ok">Uložené.</Notice>}
    </Card>
  );
}
