// Podklady pre zmluvu (dizajn 38; modul 5, F5; zadanie 9; migrácia 0045): údaje v poradí formulára zmluvy v Office
// portáli, pri každom poli „Kopírovať“, „Kopírovať všetko“. Dodávka firme s OOM na NN aj VN = dve zmluvy (záložky).
// Chýbajúce údaje sa doplnia v paneli a uložia k firme, zástupcovi, OOM a obchodu naraz (databáza stráži práva).

import { useMemo, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Check, Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { Card, ErrorState, PageSkeleton, Pill } from '../components/ui';
import { send, useApi } from '../lib/api';
import { date, num } from '../lib/format';
import { CLOSE_REASON } from '../lib/labels';
import { dateTime } from '../lib/offers';

type Opt = { code: string; label: string };
type InputOom = {
  oom_id: string; eic: string; type: string; address: string | null; name: string | null; voltage_level: string | null; pds: string | null;
  planned_vt_mwh: string | null; planned_nt_mwh: string | null; planned_feed_in_mwh: string | null; source_power_kw: string | null;
  property_relation: string | null; property_relation_label: string | null; has_ims: boolean | null;
  previous_supplier: string | null; previous_supplier_label: string | null;
};
type InputContract = {
  group: 'nn' | 'vn' | 'vsetko';
  ooms: InputOom[];
  prices: { product: string; year: number | null; price_model: string; text: string }[];
  exceptions: { year: number; value: string; threshold: string; decided_by: string | null; decided_at: string | null }[];
};
type ContractInput = {
  deal: { id: string; name: string; kind: string; supply_start: string | null; stage: string };
  acceptance: { accepted_at: string; signer_name: string; signer_function: string; method: string; channel: string | null; offer_number: string; variant: string; due: string } | null;
  header: {
    seller: string; close_reason: string; product_line: string; auto_prolong: boolean; billing_period: string | null; billing_period_label: string | null;
    feed_in_contract_type: string | null; feed_in_contract_type_label: string | null; feed_in_calc_model: string | null; feed_in_calc_model_label: string | null;
  };
  customer: {
    kind: 'company' | 'person'; name: string; ico?: string; dic?: string | null; ic_dph?: string | null; address: string | null; registry_entry?: string | null;
    vat_payer?: boolean | null; social_enterprise?: boolean | null; contract_name?: string | null; bank_account?: string | null; billing_emails?: string[];
    email?: string | null; phone?: string | null;
  };
  representative: { contact_id: string; title: string | null; first_name: string; last_name: string; position: string | null; email: string | null; phone: string | null } | null;
  contacts: { id: string; name: string }[];
  contracts: InputContract[];
  completeness: { filled: number; total: number; missing: string[] };
  can_edit: boolean;
  options: Record<string, Opt[]>;
};

type Row = { label: string; value: string | null; missing?: boolean };
const yes = (v: boolean | null | undefined) => (v === null || v === undefined ? null : v ? 'áno' : 'nie');
const GROUP_LABEL: Record<string, string> = { nn: 'NN', vn: 'VN', vsetko: '' };
const MANAGERS: Record<string, string> = { b2b_dodavka: 'obchodník (firma)', b2c_dodavka: 'back office (domácnosť)', b2b_vykup: 'Nákup (výkup)', green_viwa: 'obchodník (VIWA)' };

function CopyButton(props: { value: string | null }) {
  const [done, setDone] = useState(false);
  if (!props.value) return null;
  return (
    <button type="button" className="btn btn-sm" onClick={() => void navigator.clipboard.writeText(props.value!).then(() => {
      setDone(true);
      window.setTimeout(() => setDone(false), 1500);
    })}>
      {done ? 'Skopírované' : 'Kopírovať'}
    </button>
  );
}

function Section(props: { title: string; rows: Row[] }) {
  return (
    <Card title={props.title} flush>
      <table className="tbl input-tbl">
        <tbody>
          {props.rows.map((r) => (
            <tr key={r.label} className={r.missing ? 'input-missing' : undefined}>
              <td className="input-label">{r.label}</td>
              <td>{r.value ?? (r.missing ? <span className="caption">doplniť</span> : '–')}</td>
              <td className="input-act">{r.missing && !r.value ? <Pill tone="warning">chýba</Pill> : <CopyButton value={r.value} />}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}

export function ContractInputPage() {
  const { id = '' } = useParams();
  const { data: d, error, reload } = useApi<ContractInput>(`/api/deals/${id}/contract-input`);
  const [tab, setTab] = useState(0);
  const [editing, setEditing] = useState(false);
  const [copiedAll, setCopiedAll] = useState(false);

  const sections = useMemo(() => (d ? buildSections(d, d.contracts[tab] ?? d.contracts[0]) : []), [d, tab]);
  if (error) return <ErrorState error={error} />;
  if (!d) return <PageSkeleton />;
  const k = d.contracts[tab] ?? d.contracts[0];
  const copyAll = () => {
    const text = sections.map((s) => [`## ${s.title}`, ...s.rows.map((r) => `${r.label}: ${r.value ?? ''}`)].join('\n')).join('\n\n');
    void navigator.clipboard.writeText(text).then(() => {
      setCopiedAll(true);
      window.setTimeout(() => setCopiedAll(false), 1500);
    });
  };
  const c = d.completeness;

  return (
    <>
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <div className="caption">
            <Link to="/obchody">Obchody</Link> / <Link to={`/obchody/${d.deal.id}`}>{d.deal.name}</Link> / Podklady
          </div>
          <div className="offer-title">
            <h1 className="t-page-title">Podklady pre zmluvu</h1>
            <Pill tone={d.deal.stage === 'akceptacia' ? 'positive' : 'neutral'} live={d.deal.stage === 'akceptacia'}>
              {d.deal.stage === 'akceptacia' ? 'Akceptácia' : d.deal.stage === 'vyhrane' ? 'Vyhraté' : d.deal.stage}
            </Pill>
            <span className="caption">{d.deal.name}</span>
          </div>
        </div>
        <div className="head-actions">
          {d.can_edit && <button type="button" className="btn" onClick={() => setEditing(true)}>Doplniť údaje</button>}
          <button type="button" className="btn" onClick={copyAll}>{copiedAll ? 'Skopírované' : 'Kopírovať všetko'}</button>
        </div>
      </header>
      {d.acceptance && (
        <div className="ban ban-ok">
          <strong>Akceptované {dateTime(d.acceptance.accepted_at)}</strong> · {d.acceptance.signer_name}, {d.acceptance.signer_function} · variant{' '}
          {d.acceptance.variant} · ponuka {d.acceptance.offer_number}. Zmluvu treba uzavrieť do {date(d.acceptance.due)}.
        </div>
      )}
      <div className="input-layout">
        <div className="input-main">
          {d.contracts.length > 1 && (
            <div className="tabs" role="tablist">
              {d.contracts.map((x, i) => {
                const mwh = x.ooms.reduce((s, o) => s + Number(o.planned_vt_mwh ?? 0) + Number(o.planned_nt_mwh ?? 0), 0);
                return (
                  <button key={x.group} type="button" role="tab" aria-selected={i === tab} className={`tab${i === tab ? ' active' : ''}`} onClick={() => setTab(i)}>
                    Zmluva {GROUP_LABEL[x.group]} · {x.ooms.length} OOM · {num(mwh, 1)} MWh
                  </button>
                );
              })}
            </div>
          )}
          {sections.map((s) => <Section key={s.title} title={s.title} rows={s.rows} />)}
          {k && k.prices.length === 0 && <p className="caption">Obchod nemá akceptovaný variant ponuky – ceny doplňte podľa dohody.</p>}
        </div>
        <div className="input-side">
          <Card title="Stav podkladov" aside={<Pill tone={c.filled === c.total ? 'positive' : 'warning'}>{c.filled} / {c.total}</Pill>}>
            <table className="tbl input-tbl">
              <tbody>
                <tr><td className="caption">Chýba</td><td>{c.missing.length ? c.missing.join(', ') : 'nič'}</td></tr>
                <tr><td className="caption">Zadáva</td><td>{MANAGERS[d.deal.kind] ?? 'obchodník'}</td></tr>
                <tr><td className="caption">Doplnené údaje sa uložia</td><td>k firme, kontaktu, OOM</td></tr>
              </tbody>
            </table>
            <p className="caption">Poradie polí zodpovedá formuláru zmluvy v Office portáli. Keď Office portál bude vedieť načítať súbor, pribudne tlačidlo „Stiahnuť súbor pre Office portál“.</p>
          </Card>
          <Card title="Po zadaní do Office portálu">
            <p>
              Import zmluvu spáruje s obchodom podľa EIC. Prvá spárovaná zmluva presunie obchod do <strong>Vyhraté</strong>, ďalšia (napr. VN) sa k nemu
              pripojí. Ak niektoré OOM nebude na zmluve do 14 dní od akceptácie, príde upozornenie.
            </p>
          </Card>
        </div>
      </div>
      {editing && <EditPanel d={d} onClose={() => setEditing(false)} onSaved={() => { setEditing(false); reload(); }} />}
    </>
  );
}

function buildSections(d: ContractInput, k: InputContract | undefined): { title: string; rows: Row[] }[] {
  const h = d.header;
  const cu = d.customer;
  const company = cu.kind === 'company';
  const out: { title: string; rows: Row[] }[] = [
    {
      title: 'Hlavička zmluvy',
      rows: [
        { label: 'Meno obchodníka', value: h.seller },
        { label: 'Typ', value: CLOSE_REASON[h.close_reason] ?? h.close_reason },
        { label: 'Produktová rada', value: h.product_line },
        { label: 'Autoprolongácia', value: yes(h.auto_prolong) },
        { label: 'Obdobie fakturácie', value: h.billing_period_label, missing: true },
        ...(d.deal.kind === 'b2b_vykup'
          ? [{ label: 'Typ výkupnej zmluvy', value: h.feed_in_contract_type_label, missing: true }, { label: 'Model výpočtu výkupu', value: h.feed_in_calc_model_label, missing: true }]
          : []),
      ],
    },
    {
      title: 'Základné údaje',
      rows: company
        ? [
            { label: 'Názov', value: cu.name },
            { label: 'Názov pre zmluvu (v zastúpení)', value: cu.contract_name ?? null },
            { label: 'IČO / DIČ / IČ DPH', value: [cu.ico, cu.dic, cu.ic_dph].filter(Boolean).join(' · ') || null },
            { label: 'Ulica, číslo, PSČ, obec', value: cu.address },
            { label: 'Údaj o zápise do OR', value: cu.registry_entry ?? null },
            { label: 'Účinnosť od', value: d.deal.supply_start ? date(d.deal.supply_start) : null },
            { label: 'Platca DPH', value: yes(cu.vat_payer), missing: true },
            { label: 'Sociálny podnik', value: yes(cu.social_enterprise), missing: true },
          ]
        : [
            { label: 'Meno a priezvisko', value: cu.name },
            { label: 'Adresa', value: cu.address },
            { label: 'E-mail / telefón', value: [cu.email, cu.phone].filter(Boolean).join(' · ') || null },
            { label: 'Účinnosť od', value: d.deal.supply_start ? date(d.deal.supply_start) : null },
          ],
    },
  ];
  (k?.ooms ?? []).forEach((o, i) => {
    const supply = o.type !== 'vyroba';
    out.push({
      title: `${supply ? 'Odberné' : 'Výrobné'} miesto ${GROUP_LABEL[k!.group]} ${i + 1}`.replace(/\s+/g, ' '),
      rows: [
        { label: 'EIC', value: o.eic },
        { label: 'Adresa', value: o.address ?? o.name },
        { label: 'Napäťová úroveň', value: o.voltage_level ? o.voltage_level.toUpperCase() : null },
        ...(supply
          ? [{ label: 'Plánovaná spotreba VT / NT', value: `${num(o.planned_vt_mwh, 3)} / ${num(o.planned_nt_mwh, 3)} MWh` }]
          : [{ label: 'Plánovaná výroba / výkon', value: `${num(o.planned_feed_in_mwh, 3)} MWh / ${num(o.source_power_kw, 1)} kW` }]),
        { label: 'Vzťah k OOM (nehnuteľnosti)', value: o.property_relation_label, missing: true },
        ...(supply ? [{ label: 'Predchádzajúci dodávateľ', value: o.previous_supplier_label ?? o.previous_supplier, missing: true }] : []),
        { label: 'Mám IMS', value: yes(o.has_ims), missing: true },
      ],
    });
  });
  if (company) {
    const r = d.representative;
    out.push({
      title: 'Fakturácia a zástupca',
      rows: [
        { label: 'IBAN', value: cu.bank_account ?? null, missing: true },
        { label: 'Fakturačné e-maily', value: (cu.billing_emails ?? []).join(', ') || null, missing: true },
        { label: 'Zástupca – meno, funkcia', value: r ? [[r.title, r.first_name, r.last_name].filter(Boolean).join(' '), r.position].filter(Boolean).join(', ') : null, missing: true },
        { label: 'E-mail / telefón', value: r ? [r.email, r.phone].filter(Boolean).join(' · ') || null : null, missing: true },
      ],
    });
  }
  out.push({
    title: 'Individuálne ceny',
    rows: [
      ...(k?.prices ?? []).map((p) => ({ label: `${p.product}${p.year ? ` ${p.year}` : ''}`, value: p.text })),
      ...(k?.exceptions ?? []).map((e) => ({
        label: `Výnimka ${e.year}`,
        value: `${num(e.value, 2)} €/MWh (hranica ${num(e.threshold, 2)})${e.decided_by ? ` – schválil ${e.decided_by}` : ''}${e.decided_at ? ` ${date(e.decided_at)}` : ''}`,
      })),
    ],
  });
  return out;
}

/** Doplnenie podkladov (firma, zástupca, zmluva, OOM) – uloží sa naraz. */
function EditPanel(props: { d: ContractInput; onClose: () => void; onSaved: () => void }) {
  const { d } = props;
  const cu = d.customer;
  const company = cu.kind === 'company';
  const [iban, setIban] = useState(cu.bank_account ?? '');
  const [emails, setEmails] = useState((cu.billing_emails ?? []).join(', '));
  const [vat, setVat] = useState(cu.vat_payer ?? false);
  const [social, setSocial] = useState(cu.social_enterprise ?? false);
  const [contractName, setContractName] = useState(cu.contract_name ?? '');
  const [rep, setRep] = useState(d.representative?.contact_id ?? '');
  const [repPos, setRepPos] = useState(d.representative?.position ?? '');
  const [repEmail, setRepEmail] = useState(d.representative?.email ?? '');
  const [repPhone, setRepPhone] = useState(d.representative?.phone ?? '');
  const [billing, setBilling] = useState(d.header.billing_period ?? '');
  const [closeReason, setCloseReason] = useState(d.header.close_reason);
  const [autoProlong, setAutoProlong] = useState(d.header.auto_prolong);
  const [productLine, setProductLine] = useState(d.header.product_line);
  const [feedType, setFeedType] = useState(d.header.feed_in_contract_type ?? '');
  const [feedModel, setFeedModel] = useState(d.header.feed_in_calc_model ?? '');
  const allOoms = d.contracts.flatMap((k) => k.ooms);
  const [ooms, setOoms] = useState(() => Object.fromEntries(allOoms.map((o) => [o.oom_id, {
    property_relation: o.property_relation ?? '', has_ims: o.has_ims, previous_supplier: o.previous_supplier ?? '',
  }])));
  const save = useSave();
  const opts = (list: string) => (d.options[list] ?? []).map((o) => ({ value: o.code, label: o.label }));
  const submit = () => save.run(async () => {
    await send('PUT', `/api/deals/${d.deal.id}/contract-input`, {
      ...(company ? {
        company: {
          bank_account: iban, billing_emails: emails.split(/[\s,;]+/).filter(Boolean), vat_payer: vat, social_enterprise: social, contract_name: contractName,
        },
        representative: rep ? { contact_id: rep, position: repPos, email: repEmail, phone: repPhone } : { contact_id: null },
      } : {}),
      contract: {
        billing_period: billing, close_reason: closeReason, auto_prolong: autoProlong, product_line: productLine,
        ...(d.deal.kind === 'b2b_vykup' ? { feed_in_contract_type: feedType, feed_in_calc_model: feedModel } : {}),
      },
      ooms: allOoms.map((o) => ({ oom_id: o.oom_id, ...ooms[o.oom_id] })),
    });
    props.onSaved();
  });
  return (
    <SidePanel
      title="Doplniť podklady pre zmluvu"
      onClose={props.onClose}
      footer={<button type="button" className="btn primary" disabled={save.busy} onClick={submit}>Uložiť</button>}
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <p className="caption">Údaje sa uložia k firme, zástupcovi, odberným miestam a obchodu – použijú sa aj pri ďalších zmluvách.</p>
      <h3 className="t-group-label">Zmluva</h3>
      <Field label="Obdobie fakturácie">
        <Select value={billing} placeholder="Vyberte" onChange={setBilling} options={opts('fakturacne_obdobie')} />
      </Field>
      <Field label="Typ">
        <Select value={closeReason} onChange={setCloseReason} options={Object.entries(CLOSE_REASON).map(([value, label]) => ({ value, label }))} />
      </Field>
      <Field label="Produktová rada"><TextInput value={productLine} maxLength={80} onChange={setProductLine} /></Field>
      <Check checked={autoProlong} onChange={setAutoProlong}>Autoprolongácia</Check>
      {d.deal.kind === 'b2b_vykup' && (
        <>
          <Field label="Typ výkupnej zmluvy"><Select value={feedType} placeholder="Vyberte" onChange={setFeedType} options={opts('typ_vykupnej_zmluvy')} /></Field>
          <Field label="Model výpočtu výkupu"><Select value={feedModel} placeholder="Vyberte" onChange={setFeedModel} options={opts('model_vypoctu_vykupu')} /></Field>
        </>
      )}
      {company && (
        <>
          <h3 className="t-group-label">Firma a fakturácia</h3>
          <Field label="IBAN"><TextInput value={iban} maxLength={42} onChange={setIban} /></Field>
          <Field label="Fakturačné e-maily" hint="Oddeľte čiarkou."><TextInput value={emails} maxLength={1000} onChange={setEmails} /></Field>
          <Field label="Názov pre zmluvu (v zastúpení)"><TextInput value={contractName} maxLength={200} onChange={setContractName} /></Field>
          <Check checked={vat} onChange={setVat}>Platca DPH</Check>
          <Check checked={social} onChange={setSocial}>Sociálny podnik</Check>
          <h3 className="t-group-label">Zástupca pre zmluvné vzťahy</h3>
          <Field label="Kontakt">
            <Select value={rep} placeholder="Vyberte kontakt" onChange={setRep} options={d.contacts.map((x) => ({ value: x.id, label: x.name }))} />
          </Field>
          {rep && (
            <>
              <Field label="Funkcia"><TextInput value={repPos} maxLength={100} onChange={setRepPos} /></Field>
              <Field label="E-mail"><TextInput value={repEmail} maxLength={200} onChange={setRepEmail} /></Field>
              <Field label="Telefón"><TextInput value={repPhone} maxLength={40} onChange={setRepPhone} /></Field>
            </>
          )}
        </>
      )}
      <h3 className="t-group-label">Odberné miesta</h3>
      {allOoms.map((o) => (
        <fieldset key={o.oom_id} className="fieldset">
          <legend className="mono">{o.eic}</legend>
          <Field label="Vzťah k nehnuteľnosti">
            <Select value={ooms[o.oom_id].property_relation} placeholder="Vyberte" onChange={(v) => setOoms({ ...ooms, [o.oom_id]: { ...ooms[o.oom_id], property_relation: v } })}
              options={opts('vztah_k_nehnutelnosti')} />
          </Field>
          {o.type !== 'vyroba' && (
            <Field label="Predchádzajúci dodávateľ">
              <Select value={ooms[o.oom_id].previous_supplier} placeholder="Vyberte" onChange={(v) => setOoms({ ...ooms, [o.oom_id]: { ...ooms[o.oom_id], previous_supplier: v } })}
                options={opts('predchadzajuci_dodavatel')} />
            </Field>
          )}
          <Field label="IMS">
            <Select value={ooms[o.oom_id].has_ims === null ? '' : ooms[o.oom_id].has_ims ? 'ano' : 'nie'} placeholder="Vyberte"
              onChange={(v: string) => setOoms({ ...ooms, [o.oom_id]: { ...ooms[o.oom_id], has_ims: v === 'ano' ? true : v === 'nie' ? false : null } })}
              options={[{ value: 'ano', label: 'áno' }, { value: 'nie', label: 'nie' }]} />
          </Field>
        </fieldset>
      ))}
    </SidePanel>
  );
}
