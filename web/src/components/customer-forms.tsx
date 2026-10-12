// Formuláre modulu Zákazníci (F1): nová firma / úprava firmy, nová osoba / úprava osoby, zmazanie.
// Kontrola duplicít počas písania: IČO/OIB (firma je v CRM raz – zakázané), e-mail a telefón osoby
// (iba upozornenie, zadanie čl. 7). Obmedzenia práv (tím, vlastník, Servis) stráži API a databáza;
// formulár iba skryje, čo používateľ meniť nesmie.

import { useEffect, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useApi, send, get, type CompanyCard, type PersonCard } from '../lib/api';
import { permission, useMe } from '../lib/me';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from './form';

type Options = {
  orgs: { id: string; name: string; country: 'SK' | 'CZ' | 'HR'; is_default: boolean }[];
  owners: { id: string; name: string; team_name: string }[];
  sources: { code: string; label: string; org_id: string | null }[];
};

const COUNTRIES = [
  { value: 'SK', label: 'Slovensko' },
  { value: 'CZ', label: 'Česko' },
  { value: 'HR', label: 'Chorvátsko' },
] as const;

/** Smie zakladať firmy a osoby (právo upravovať v module Zákazníci, nie Servis). */
export function useCanCreateCustomers(): boolean {
  const me = useMe();
  return permission(me, 'zakaznici').edit !== 'nic' && me.team_code !== 'servis';
}

/** Hodnota s oneskorením (kontrola duplicít nevolá API pri každom písmene). */
function useDebounced<T>(value: T, ms = 350): T {
  const [v, setV] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setV(value), ms);
    return () => clearTimeout(t);
  }, [value, ms]);
  return v;
}

function OwnerSelect(props: { options?: Options; value: string; onChange: (v: string) => void; disabled?: boolean }) {
  return (
    <Select
      value={props.value}
      onChange={props.onChange}
      disabled={props.disabled}
      options={[{ value: '', label: 'Bez vlastníka' }, ...(props.options?.owners ?? []).map((o) => ({ value: o.id, label: `${o.name} (${o.team_name})` }))]}
    />
  );
}

// --- Firma -----------------------------------------------------------------------------------

type CompanyDup = { company_exists: boolean; company_id: string | null; owner_name: string | null; org_name: string };

export function CompanyFormPanel(props: { company?: CompanyCard; onClose: () => void; onSaved?: () => void }) {
  const me = useMe();
  const navigate = useNavigate();
  const options = useApi<Options>('/api/customers/options').data;
  const c = props.company;
  const [orgId, setOrgId] = useState(c?.org_id ?? '');
  const [country, setCountry] = useState<'SK' | 'CZ' | 'HR'>(c?.country ?? 'SK');
  const [ico, setIco] = useState(c?.ico ?? '');
  const [name, setName] = useState(c?.name ?? '');
  const [isCustomer, setIsCustomer] = useState(c?.is_customer ?? true);
  const [isPartner, setIsPartner] = useState(c?.is_partner ?? false);
  const [isSupplier, setIsSupplier] = useState(c?.is_supplier ?? false);
  const [dic, setDic] = useState(c?.dic ?? '');
  const [icDph, setIcDph] = useState(c?.ic_dph ?? '');
  const [address, setAddress] = useState(c?.address ?? '');
  const [bank, setBank] = useState(c?.bank_account ?? '');
  const [statutory, setStatutory] = useState(c?.statutory ?? '');
  const [registry, setRegistry] = useState(c?.registry_entry ?? '');
  const [owner, setOwner] = useState(c ? (c.owner_id ?? '') : me.id);
  const [dup, setDup] = useState<CompanyDup | null>(null);
  const save = useSave();

  // predvolená spoločnosť a krajina podľa spoločnosti
  useEffect(() => {
    if (!c && options && !orgId) {
      const o = options.orgs.find((x) => x.is_default) ?? options.orgs[0];
      if (o) {
        setOrgId(o.id);
        setCountry(o.country);
      }
    }
  }, [options, c, orgId]);

  const icoDebounced = useDebounced(ico.replace(/\D/g, ''));
  useEffect(() => {
    if (icoDebounced.length < 6 || (c && icoDebounced === c.ico && country === c.country)) {
      setDup(null);
      return;
    }
    const ctrl = new AbortController();
    get<{ items: CompanyDup[] }>(`/api/check/company?country=${country}&ico=${icoDebounced}`, ctrl.signal)
      .then((r) => setDup(r.items.find((x) => x.company_id !== c?.id) ?? null))
      .catch(() => undefined);
    return () => ctrl.abort();
  }, [icoDebounced, country, c]);

  const canChangeOwner = me.can_change_owner;
  const submit = async () => {
    const body: Record<string, unknown> = {
      country,
      ico,
      name,
      is_customer: isCustomer,
      is_partner: isPartner,
      is_supplier: isSupplier,
      dic,
      ic_dph: icDph,
      address,
      bank_account: bank,
      statutory,
      registry_entry: registry,
    };
    if (!c) {
      body.org_id = orgId;
      body.owner_id = owner || null;
    } else if (canChangeOwner && owner !== (c.owner_id ?? '')) {
      body.owner_id = owner || null;
    }
    const r = await save.run(() => (c ? send('PATCH', `/api/companies/${c.id}`, body) : send<{ id: string }>('POST', '/api/companies', body)));
    if (!r) return;
    if (c) props.onSaved?.();
    else navigate(`/firmy/${(r as { id: string }).id}`);
    props.onClose();
  };

  return (
    <SidePanel
      title={c ? `Upraviť ${c.name}` : 'Nová firma'}
      onClose={props.onClose}
      footer={
        <>
          {c && me.is_admin && <DeleteButton kind="company" id={c.id} name={c.name} />}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !name.trim() || !ico.trim() || !!dup} onClick={submit}>
            {c ? 'Uložiť' : 'Založiť firmu'}
          </button>
        </>
      }
    >
      <div className="form-grid">
        {!c && (options?.orgs.length ?? 0) > 1 && (
          <Field label="Spoločnosť" wide>
            <Select
              value={orgId}
              onChange={(v) => {
                setOrgId(v);
                const o = options?.orgs.find((x) => x.id === v);
                if (o) setCountry(o.country);
              }}
              options={(options?.orgs ?? []).map((o) => ({ value: o.id, label: o.name }))}
            />
          </Field>
        )}
        <Field label="Krajina">
          <Select value={country} onChange={setCountry} options={[...COUNTRIES]} />
        </Field>
        <Field label={country === 'HR' ? 'OIB' : 'IČO'} hint={country === 'HR' ? '11 číslic' : '8 číslic, úvodné nuly sa doplnia'}>
          <TextInput value={ico} onChange={setIco} maxLength={20} autoFocus={!c} />
        </Field>
        {dup && (
          <div className="fl-wide">
            <Notice tone="error">
              Firma s týmto {country === 'HR' ? 'OIB' : 'IČO'} už v CRM je
              {dup.owner_name ? ` (vlastník ${dup.owner_name}` : ' (bez vlastníka'}
              {dup.org_name ? `, ${dup.org_name})` : ')'}.{' '}
              {dup.company_id ? <Link to={`/firmy/${dup.company_id}`} onClick={props.onClose}>Otvoriť firmu</Link> : 'Údaje firmy nevidíte.'}
            </Notice>
          </div>
        )}
        <Field label="Názov" wide>
          <TextInput value={name} onChange={setName} maxLength={200} />
        </Field>
        <fieldset className="fieldset fl-wide">
          <legend>Označenie (aj viac naraz)</legend>
          <div className="bank-purposes">
            <Check checked={isCustomer} onChange={setIsCustomer}>
              Zákazník
            </Check>
            <Check checked={isPartner} onChange={setIsPartner}>
              Partner
            </Check>
            <Check checked={isSupplier} onChange={setIsSupplier}>
              Dodávateľ
            </Check>
          </div>
        </fieldset>
        <Field label="DIČ">
          <TextInput value={dic} onChange={setDic} maxLength={20} />
        </Field>
        <Field label="IČ DPH">
          <TextInput value={icDph} onChange={setIcDph} maxLength={20} />
        </Field>
        <Field label="Sídlo" wide>
          <TextInput value={address} onChange={setAddress} maxLength={300} placeholder="ulica, PSČ obec" />
        </Field>
        <Field label="Štatutár" wide>
          <TextInput value={statutory} onChange={setStatutory} maxLength={500} />
        </Field>
        <Field label="Zápis v obchodnom registri" wide>
          <TextInput value={registry} onChange={setRegistry} maxLength={300} />
        </Field>
        <Field label="Bankový účet" wide>
          <TextInput value={bank} onChange={setBank} maxLength={50} />
        </Field>
        <Field label="Vlastník (obchodník)" wide hint={c && !canChangeOwner ? 'Vlastníka mení iba vedenie (tím CEO) alebo admin.' : undefined}>
          <OwnerSelect options={options} value={owner} onChange={setOwner} disabled={!!c && !canChangeOwner} />
        </Field>
      </div>
      <p className="caption">Údaje z FinStatu sa zatiaľ vypĺňajú ručne; napojenie podľa IČO príde samostatne.</p>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

// --- Osoba -----------------------------------------------------------------------------------

type PersonDup = { match_on: 'email' | 'telefon'; contact_id: string | null; owner_name: string | null; name: string | null };
type CompanyHit = { id: string; name: string; ico: string | null };

export function PersonFormPanel(props: {
  person?: PersonCard;
  household?: boolean; // nová osoba: predvolene domácnosť
  company?: CompanyHit; // nová osoba rovno do tejto firmy (karta firmy → Pridať → Nová osoba)
  stay?: boolean; // po založení neotvárať kartu osoby, iba onSaved
  onClose: () => void;
  onSaved?: () => void;
}) {
  const me = useMe();
  const navigate = useNavigate();
  const options = useApi<Options>('/api/customers/options').data;
  const p = props.person;
  const servis = me.team_code === 'servis';
  const [isHousehold, setIsHousehold] = useState(p?.is_household ?? props.household ?? true);
  const [title, setTitle] = useState(p?.title ?? '');
  const [first, setFirst] = useState(p?.first_name ?? '');
  const [last, setLast] = useState(p?.last_name ?? '');
  const [email, setEmail] = useState(p?.email ?? '');
  const [phone, setPhone] = useState(p?.phone ?? '');
  const [mobile, setMobile] = useState(p?.mobile ?? '');
  const [position, setPosition] = useState(p?.position ?? '');
  const [address, setAddress] = useState(p?.address ?? '');
  const [source, setSource] = useState(p?.source ?? '');
  const [owner, setOwner] = useState(p ? (p.owner_id ?? '') : me.id);
  const [company, setCompany] = useState<CompanyHit | null>(props.company ?? null);
  const [companyQ, setCompanyQ] = useState('');
  const [hits, setHits] = useState<CompanyHit[]>([]);
  const [dups, setDups] = useState<PersonDup[]>([]);
  const save = useSave();

  const qDeb = useDebounced(companyQ);
  useEffect(() => {
    if (p || isHousehold || qDeb.trim().length < 2) {
      setHits([]);
      return;
    }
    const ctrl = new AbortController();
    get<{ items: CompanyHit[] }>(`/api/companies/search?q=${encodeURIComponent(qDeb)}`, ctrl.signal)
      .then((r) => setHits(r.items))
      .catch(() => undefined);
    return () => ctrl.abort();
  }, [qDeb, isHousehold, p]);

  const emailDeb = useDebounced(email.trim());
  const phoneDeb = useDebounced((mobile || phone).trim());
  useEffect(() => {
    if (!emailDeb && phoneDeb.replace(/\D/g, '').length < 9) {
      setDups([]);
      return;
    }
    const ctrl = new AbortController();
    const qs = new URLSearchParams({ email: emailDeb, phone: phoneDeb, org: p?.org_id ?? '' });
    get<{ items: PersonDup[] }>(`/api/check/contact?${qs}`, ctrl.signal)
      .then((r) => setDups(r.items.filter((d) => !p || d.contact_id !== p.id)))
      .catch(() => undefined);
    return () => ctrl.abort();
  }, [emailDeb, phoneDeb, p]);

  const canChangeOwner = me.can_change_owner;
  const submit = async () => {
    const body: Record<string, unknown> = servis
      ? { email, phone, mobile, address }
      : { title, first_name: first, last_name: last, email, phone, mobile, position, address, source: source || null };
    if (!p) {
      body.is_household = isHousehold;
      body.owner_id = owner || null;
      if (!isHousehold && company) body.company_id = company.id;
    } else if (!servis) {
      body.is_household = isHousehold;
      if (canChangeOwner && owner !== (p.owner_id ?? '')) body.owner_id = owner || null;
    }
    const r = await save.run(() => (p ? send('PATCH', `/api/persons/${p.id}`, body) : send<{ id: string }>('POST', '/api/persons', body)));
    if (!r) return;
    if (p || props.stay) props.onSaved?.();
    else navigate(`/osoby/${(r as { id: string }).id}`);
    props.onClose();
  };

  const name = p ? [p.first_name, p.last_name].join(' ') : '';
  const missingCompany = !p && !isHousehold && !company;

  return (
    <SidePanel
      title={p ? `Upraviť ${name}` : isHousehold ? 'Nová domácnosť' : 'Nový kontakt vo firme'}
      onClose={props.onClose}
      footer={
        <>
          {p && me.is_admin && <DeleteButton kind="person" id={p.id} name={name} />}
          <span className="grow" />
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button
            type="button"
            className="btn primary"
            disabled={save.busy || !first.trim() || !last.trim() || !(email.trim() || phone.trim() || mobile.trim()) || missingCompany}
            onClick={submit}
          >
            {p ? 'Uložiť' : dups.length ? 'Založiť aj tak' : 'Založiť'}
          </button>
        </>
      }
    >
      {servis && <Notice tone="ok">Servis mení iba e-mail, telefón, mobil a adresu.</Notice>}
      <div className="form-grid">
        {!servis && (
          <fieldset className="fieldset fl-wide">
            <legend>Osoba je</legend>
            <Check checked={isHousehold} onChange={setIsHousehold} disabled={!!p && p.is_household}>
              Domácnosť (zákazník za domácnosť alebo marketingový kontakt bez firmy)
            </Check>
            {p?.is_household && <span className="caption">Domácnosť sa automaticky nezruší (zadanie čl. 3).</span>}
          </fieldset>
        )}
        {!p && !isHousehold && (
          <Field label="Firma" wide hint="Kontakt vo firme patrí spoločnosti firmy. Roly a hlavný kontakt nastavíte na karte firmy.">
            {company ? (
              <span className="picked">
                {company.name} {company.ico && <span className="mono caption">{company.ico}</span>}{' '}
                {!props.company && (
                  <button type="button" className="btn btn-ghost" onClick={() => setCompany(null)}>
                    Zmeniť
                  </button>
                )}
              </span>
            ) : (
              <>
                <TextInput value={companyQ} onChange={setCompanyQ} placeholder="Hľadať názov alebo IČO" />
                {hits.length > 0 && (
                  <div className="pick-list">
                    {hits.map((h) => (
                      <button key={h.id} type="button" className="pick-item" onClick={() => setCompany(h)}>
                        {h.name} <span className="mono caption">{h.ico}</span>
                      </button>
                    ))}
                  </div>
                )}
              </>
            )}
          </Field>
        )}
        <Field label="Titul">
          <TextInput value={title} onChange={setTitle} maxLength={40} disabled={servis} />
        </Field>
        <Field label="Meno">
          <TextInput value={first} onChange={setFirst} maxLength={80} disabled={servis} autoFocus={!p} />
        </Field>
        <Field label="Priezvisko">
          <TextInput value={last} onChange={setLast} maxLength={80} disabled={servis} />
        </Field>
        <Field label="E-mail" wide>
          <TextInput type="email" value={email} onChange={setEmail} maxLength={200} />
        </Field>
        <Field label="Telefón">
          <TextInput value={phone} onChange={setPhone} maxLength={40} />
        </Field>
        <Field label="Mobil">
          <TextInput value={mobile} onChange={setMobile} maxLength={40} />
        </Field>
        {dups.length > 0 && (
          <div className="fl-wide">
            <Notice tone="error">
              {dups.map((d, i) => (
                <div key={i}>
                  Osoba s rovnakým {d.match_on === 'email' ? 'e-mailom' : 'telefónom'} už existuje
                  {d.owner_name ? ` (vlastník ${d.owner_name})` : ''}:{' '}
                  {d.contact_id ? (
                    <Link to={`/osoby/${d.contact_id}`} onClick={props.onClose}>
                      {d.name ?? 'otvoriť'}
                    </Link>
                  ) : (
                    'údaje osoby nevidíte'
                  )}
                </div>
              ))}
              <div className="caption">Ak ide o inú osobu (napr. spoločný e-mail), môžete založiť aj tak.</div>
            </Notice>
          </div>
        )}
        <Field label="Pozícia">
          <TextInput value={position} onChange={setPosition} maxLength={100} disabled={servis} />
        </Field>
        <Field label="Zdroj">
          <Select
            value={source}
            onChange={setSource}
            disabled={servis}
            options={[
              { value: '', label: 'Nezadaný' },
              ...(options?.sources ?? []).map((s) => ({ value: s.code, label: s.label })),
              ...(source && !options?.sources.some((s) => s.code === source) ? [{ value: source, label: source }] : []),
            ]}
          />
        </Field>
        <Field label="Adresa" wide>
          <TextInput value={address} onChange={setAddress} maxLength={300} placeholder="ulica, PSČ obec" />
        </Field>
        {!servis && (
          <Field label="Vlastník (obchodník)" wide hint={p && !canChangeOwner ? 'Vlastníka mení iba vedenie (tím CEO) alebo admin.' : undefined}>
            <OwnerSelect options={options} value={owner} onChange={setOwner} disabled={!!p && !canChangeOwner} />
          </Field>
        )}
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

// --- Zmazanie (iba admin, iba bez väzieb) ------------------------------------------------------

function DeleteButton(props: { kind: 'company' | 'person'; id: string; name: string }) {
  const navigate = useNavigate();
  const save = useSave();
  const [confirm, setConfirm] = useState(false);
  const run = async () => {
    const ok = await save.run(() => send('DELETE', `/api/${props.kind === 'company' ? 'companies' : 'persons'}/${props.id}`));
    if (ok) navigate(props.kind === 'company' ? '/zakaznici' : '/kontakty');
  };
  if (save.error) {
    return (
      <span className="delete-error" role="alert">
        {save.error}
      </span>
    );
  }
  return confirm ? (
    <button type="button" className="btn btn-danger-solid" onClick={run} disabled={save.busy}>
      Naozaj zmazať?
    </button>
  ) : (
    <button type="button" className="btn btn-danger" onClick={() => setConfirm(true)} title={`Zmazať ${props.name} (iba bez väzieb)`}>
      Zmazať
    </button>
  );
}
