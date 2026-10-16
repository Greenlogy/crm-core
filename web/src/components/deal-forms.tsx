// Obchody (modul 5, F1): nový obchod, prehra s dôvodom, znovuotvorenie, výstrahy Finstatu.
// Rovnaké pre interných aj externých obchodníkov; obmedzenia stráži databáza.

import { useEffect, useState } from 'react';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Card, Pill, Rows } from './ui';
import { get, send, useApi, type Owner } from '../lib/api';
import { type DealOptions, type Risk, RISK_LABEL } from '../lib/deals';
import { useMe } from '../lib/me';

export function RiskPills(props: { risk: Risk; compact?: boolean }) {
  if (!props.risk || props.risk.warnings.length === 0) return null;
  return (
    <span style={{ display: 'inline-flex', gap: 4, flexWrap: 'wrap' }}>
      {props.risk.warnings.map((w) => {
        const r = RISK_LABEL[w] ?? { label: w, tone: 'warning' as const };
        return (
          <Pill key={w} tone={r.tone}>
            {r.label}
          </Pill>
        );
      })}
      {props.risk.needs_approval && !props.compact && <Pill tone="negative">ponuka vyžaduje schválenie</Pill>}
    </span>
  );
}

type CustomerHit = { id: string; kind: 'company' | 'person'; name: string; ico: string | null };

/** Nový obchod: zákazník (predvolený z overenia firmy, alebo hľadanie), pipeline, názov, zdroj, termíny. */
export function NewDealPanel(props: {
  customer?: { id: string; kind: 'company' | 'person'; name: string };
  estimate?: string; // predvyplnená PH (kalkulačka na Domove, F6)
  step?: string; // predvyplnený ďalší krok (kalkulačka na Domove, F6)
  onClose: () => void;
  onSaved: (id: string) => void;
}) {
  const me = useMe();
  const { data: opts } = useApi<DealOptions>('/api/deals/options');
  const { data: owners } = useApi<Owner[]>('/api/deals/owners');
  const [customer, setCustomer] = useState<CustomerHit | null>(
    props.customer ? { ...props.customer, ico: null } : null,
  );
  const [q, setQ] = useState('');
  const [hits, setHits] = useState<CustomerHit[]>([]);
  const [pipeline, setPipeline] = useState('');
  const [name, setName] = useState('');
  const [source, setSource] = useState('');
  const [owner, setOwner] = useState(me.id);
  const [expected, setExpected] = useState('');
  const [supply, setSupply] = useState('');
  const [estimate, setEstimate] = useState(props.estimate ?? '');
  const [step, setStep] = useState(props.step ?? '');
  const [stepOn, setStepOn] = useState('');
  const save = useSave();

  const pipelines = (opts?.pipelines ?? []).filter((p) =>
    !customer ? true : customer.kind === 'person' ? p.kind === 'b2c_dodavka' : p.kind !== 'b2c_dodavka',
  );
  useEffect(() => {
    if (pipelines.length && !pipelines.some((p) => p.id === pipeline)) setPipeline(pipelines[0].id);
  }, [pipelines.map((p) => p.id).join(), pipeline]);
  useEffect(() => {
    if (customer && !name) setName(`${customer.name} ${new Date().getFullYear() + 1}`);
  }, [customer]);

  useEffect(() => {
    if (customer || q.trim().length < 2) {
      setHits([]);
      return;
    }
    const t = setTimeout(() => {
      get<{ items: CustomerHit[] }>(`/api/customers?status=vsetky&q=${encodeURIComponent(q.trim())}`)
        .then((r) => setHits(r.items.slice(0, 8)))
        .catch(() => setHits([]));
    }, 250);
    return () => clearTimeout(t);
  }, [q, customer]);

  const submit = () =>
    save.run(async () => {
      if (!customer) throw new Error('Vyberte zákazníka.');
      const r = await send<{ id: string }>('POST', '/api/deals', {
        pipeline_id: pipeline,
        company_id: customer.kind === 'company' ? customer.id : null,
        person_id: customer.kind === 'person' ? customer.id : null,
        name,
        source_code: source,
        owner_id: owner,
        expected_close: expected || null,
        supply_start: supply || null,
        estimated_value_eur: estimate || null,
        next_step: step || null,
        next_step_on: stepOn || null,
      });
      props.onSaved(r.id);
    });

  return (
    <SidePanel
      title="Nový obchod"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !customer || !pipeline || !name.trim() || !source} onClick={submit}>
            {save.busy ? 'Zakladám…' : 'Založiť obchod'}
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Zákazník" hint="Firmu overte cez Overenie firmy (Finstat, vlastník). Domácnosť iba pri ponuke od obchodníka (B2C).">
        {customer ? (
          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <strong>{customer.name}</strong>
            {!props.customer && (
              <button type="button" className="btn btn-ghost" onClick={() => setCustomer(null)}>
                Zmeniť
              </button>
            )}
          </div>
        ) : (
          <>
            <TextInput value={q} onChange={setQ} placeholder="Názov firmy, IČO alebo meno domácnosti…" autoFocus />
            {hits.map((h) => (
              <button key={h.id} type="button" className="btn btn-ghost" style={{ justifyContent: 'flex-start' }} onClick={() => setCustomer(h)}>
                {h.name} {h.ico ? `· ${h.ico}` : h.kind === 'person' ? '· domácnosť' : ''}
              </button>
            ))}
          </>
        )}
      </Field>
      <Field label="Pipeline">
        <Select value={pipeline} onChange={setPipeline} options={pipelines.map((p) => ({ value: p.id, label: p.name }))} />
      </Field>
      <Field label="Názov obchodu">
        <TextInput value={name} onChange={setName} maxLength={200} />
      </Field>
      <Field label="Zdroj">
        <Select
          value={source}
          onChange={setSource}
          placeholder="Vyberte zdroj"
          options={(opts?.lists.zdroj_obchodu ?? []).filter((s) => s.code !== 'obnova').map((s) => ({ value: s.code, label: s.label }))}
        />
      </Field>
      {opts?.manager && (
        <Field label="Vlastník (obchodník)">
          <Select value={owner} onChange={setOwner} options={(owners ?? []).map((o) => ({ value: o.id, label: o.name }))} />
        </Field>
      )}
      <div className="form-grid">
        <Field label="Očakávané uzavretie">
          <TextInput type="date" value={expected} onChange={setExpected} />
        </Field>
        <Field label="Začiatok dodávky">
          <TextInput type="date" value={supply} onChange={setSupply} />
        </Field>
      </div>
      <Field label="Odhad pridanej hodnoty [€]" hint="Pred prvou ponukou; potom sa počíta z ponuky.">
        <TextInput value={estimate} onChange={setEstimate} maxLength={14} />
      </Field>
      <div className="form-grid">
        <Field label="Ďalší krok">
          <TextInput value={step} onChange={setStep} maxLength={300} placeholder="napr. Zavolať a dohodnúť stretnutie" />
        </Field>
        <Field label="Dátum kroku">
          <TextInput type="date" value={stepOn} onChange={setStepOn} />
        </Field>
      </div>
    </SidePanel>
  );
}

/** Prehra: dôvod z číselníka, pri „Iné“ povinná poznámka. */
export function LostPanel(props: { dealId: string; stageId: string; options: DealOptions | undefined; onClose: () => void; onSaved: () => void }) {
  const [reason, setReason] = useState('');
  const [note, setNote] = useState('');
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.dealId}/stage`, { stage_id: props.stageId, lost_reason_code: reason, lost_note: note || null });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Prehratý obchod"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !reason || (reason === 'ine' && !note.trim())} onClick={submit}>
            Označiť ako prehratý
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Dôvod prehry">
        <Select
          value={reason}
          onChange={setReason}
          placeholder="Vyberte dôvod"
          options={(props.options?.lists.dovod_prehry ?? []).map((r) => ({ value: r.code, label: r.label }))}
        />
      </Field>
      <Field label={reason === 'ine' ? 'Poznámka (povinná)' : 'Poznámka'}>
        <textarea className="inp" rows={3} maxLength={2000} value={note} onChange={(e) => setNote(e.target.value)} />
      </Field>
      <div className="caption">
        Nové OOM založené pri tomto obchode, ktoré nie je na zmluve ani v inom otvorenom obchode, sa označí ako Zrušené.
      </div>
    </SidePanel>
  );
}

/** Znovuotvorenie s povinným dôvodom (Prehraté vlastník, Vyhraté iba admin). */
export function ReopenPanel(props: { dealId: string; onClose: () => void; onSaved: () => void }) {
  const [reason, setReason] = useState('');
  const save = useSave();
  const submit = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.dealId}/reopen`, { reason });
      props.onSaved();
    });
  return (
    <SidePanel
      title="Znova otvoriť obchod"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy || !reason.trim()} onClick={submit}>
            Znova otvoriť
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Field label="Dôvod" hint="Zapíše sa do časovej osi a auditu. Obchod sa vráti do Príležitosti.">
        <textarea className="inp" rows={3} maxLength={2000} value={reason} onChange={(e) => setReason(e.target.value)} autoFocus />
      </Field>
    </SidePanel>
  );
}

type CompanyRisk = {
  risk: Risk;
  data: {
    revenue_eur: string | null;
    profit_eur: string | null;
    finance_year: number | null;
    employees_range: string | null;
    founded_on: string | null;
    z_score: string | null;
    payment_rating: string | null;
    has_debts: boolean | null;
    debts: { veritel: string; suma_eur: number | null }[];
    insolvency_kind: string | null;
    insolvency_since: string | null;
    cancelled_on: string | null;
    finstat_url: string | null;
    finstat_updated_at: string | null;
  };
};

/** Údaje Finstatu a výstrahy na karte firmy; „Načítať z Finstatu“ (cache 24 h, denný limit). */
export function FinstatCompanyCard(props: { companyId: string; canRefresh: boolean }) {
  const { data, reload } = useApi<CompanyRisk>(`/api/companies/${props.companyId}/risk`);
  const save = useSave();
  const refresh = () =>
    save.run(async () => {
      await send('POST', `/api/companies/${props.companyId}/finstat-refresh`, {});
      reload();
    });
  const d = data?.data;
  const money = (v: string | null) => (v === null ? '–' : `${Number(v).toLocaleString('sk-SK', { maximumFractionDigits: 0 })} €`);
  return (
    <Card
      title="FinStat"
      aside={
        <span style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {d?.finstat_url && (
            <a href={d.finstat_url} target="_blank" rel="noreferrer noopener">
              Otvoriť ↗
            </a>
          )}
          {props.canRefresh && (
            <button type="button" className="btn btn-ghost" disabled={save.busy} onClick={refresh}>
              {save.busy ? 'Načítavam…' : 'Načítať z Finstatu'}
            </button>
          )}
        </span>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {!d ? null : !d.finstat_updated_at ? (
        <p className="caption">Údaje z Finstatu ešte neboli načítané.</p>
      ) : (
        <>
          <RiskPills risk={data?.risk ?? null} />
          <Rows
            stacked
            rows={[
              [`Tržby${d.finance_year ? ` ${d.finance_year}` : ''}`, money(d.revenue_eur)],
              [`Zisk${d.finance_year ? ` ${d.finance_year}` : ''}`, money(d.profit_eur)],
              ['Zamestnanci', d.employees_range ?? '–'],
              ['Platobný rating', d.payment_rating ?? '–'],
              ['Altmanovo Z-skóre', d.z_score === null ? '–' : String(Number(d.z_score)).replace('.', ',')],
              ['Konkurz / reštrukturalizácia', d.insolvency_kind ? `${d.insolvency_kind === 'konkurz' ? 'konkurz' : 'reštrukturalizácia'}${d.insolvency_since ? ` od ${d.insolvency_since.split('-').reverse().join('. ')}` : ''}` : 'nie'],
              ['Dlhy a nedoplatky', d.debts.length ? d.debts.map((x) => x.veritel).join(', ') : d.has_debts ? 'áno' : 'nie'],
            ]}
          />
          <p className="caption">
            Údaje k {new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric', hour: 'numeric', minute: '2-digit' }).format(new Date(d.finstat_updated_at))}
          </p>
        </>
      )}
    </Card>
  );
}
