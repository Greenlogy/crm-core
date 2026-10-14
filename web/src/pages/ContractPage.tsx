// Karta zmluvy podľa docs/dizajn/obrazovky/26-zmluva-karta.html (modul Zmluvy, F2).
// Údaje z Office portálu sú iba na čítanie (opravujú sa v Office portáli a ďalším importom). V CRM sa mení poznámka,
// dôvod uzatvorenia, predošlá a súvisiaca zmluva, balík VIWA (Servis) a obchodník (vedenie, admin).
// Ročná bilancia (pridaná hodnota, marža firmy) príde v F3 (0027).

import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { Card, Empty, ErrorState, Item, Kpi, PageSkeleton, Pill, Rows, StatusPill } from '../components/ui';
import { send, useApi, type ContractCard } from '../lib/api';
import { date, eurMonth, eurMwh, mwh, num, pct, period, text } from '../lib/format';
import {
  CLOSE_REASON,
  CONTRACT_FLAG,
  CONTRACT_PHASE,
  CONTRACT_STATUS,
  CONTRACT_TYPE,
  label,
  OOM_STATUS,
  OOM_TYPE,
  PRICE_MODEL,
  PRICE_SLOT,
  VIWA_PACKAGE,
} from '../lib/labels';
import { contractPeriod } from './ContractsPage';

const yes = (v: boolean) => (v ? 'áno' : 'nie');

type Price = ContractCard['prices'][number];
/** Ceny zlúčené naprieč OOM: rovnaká zložka, produkt, model, obdobie a hodnoty = jeden riadok (návrh 26). */
function groupPrices(prices: Price[]) {
  const map = new Map<string, { p: Price; eics: string[] }>();
  for (const p of prices) {
    const key = [p.slot, p.product, p.op_product_name, p.price_model, p.valid_from, p.valid_to, p.price_vt_eur_mwh, p.price_nt_eur_mwh,
      p.additive_eur_mwh, p.additive_pct, p.fee_eur_month, p.fee_kw_eur_month].join('|');
    const g = map.get(key);
    if (g) g.eics.push(p.eic ?? '');
    else map.set(key, { p, eics: p.eic ? [p.eic] : [] });
  }
  return [...map.values()];
}

export function ContractPage() {
  const { id = '' } = useParams();
  const { data: k, error, reload } = useApi<ContractCard>(`/api/contracts/${id}`);
  const [editing, setEditing] = useState(false);
  const save = useSave();

  if (error) return <ErrorState error={error} />;
  if (!k || k.id !== id) return <PageSkeleton />;

  const customerPath = k.company_id ? `/firmy/${k.company_id}` : `/osoby/${k.person_id}`;
  const vt = k.ooms.reduce((s, o) => s + Number(o.qty_vt_mwh ?? 0), 0);
  const nt = k.ooms.reduce((s, o) => s + Number(o.qty_nt_mwh ?? 0), 0);
  const openFlags = k.flag_rows.filter((f) => !f.resolved_at);
  const models = [...new Set(k.prices.filter((p) => p.slot === 'komodita').map((p) => PRICE_MODEL[p.price_model] ?? p.price_model))];
  const groups = groupPrices(k.prices);
  const resolve = (flagId: string) =>
    save.run(async () => {
      await send('POST', `/api/contract-flags/${flagId}/resolve`);
      reload();
    });

  return (
    <>
      <div className="caption" style={{ marginBottom: 4 }}>
        <Link to="/zmluvy">Zmluvy</Link> / {k.number}
      </div>
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="t-page-title">{k.number}</h1>
          <div className="page-sub">
            <StatusPill map={CONTRACT_STATUS} value={k.state} />
            <Pill>{CONTRACT_TYPE[k.type] ?? k.type}</Pill>
            {models.map((m) => (
              <Pill key={m} tone="info">
                {m}
              </Pill>
            ))}
            {openFlags.map((f) => (
              <Pill key={f.id} tone={CONTRACT_FLAG[f.code]?.tone ?? 'neutral'}>
                {CONTRACT_FLAG[f.code]?.label ?? f.code}
              </Pill>
            ))}
            <span>
              <Link to={customerPath}>{k.customer_name || '(bez mena)'}</Link> · {k.owner_name ?? 'bez obchodníka'}
            </span>
          </div>
        </div>
        <div className="head-actions">
          {k.can_edit && (
            <button type="button" className="btn" onClick={() => setEditing(true)}>
              Upraviť údaje CRM
            </button>
          )}
        </div>
      </header>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {editing && (
        <EditPanel
          k={k}
          onClose={() => setEditing(false)}
          onSaved={() => {
            setEditing(false);
            reload();
          }}
        />
      )}

      <section className="kpis" aria-label="Ukazovatele">
        <Kpi label="Účinnosť" value={contractPeriod(k)} sub={k.auto_prolong ? 'automatická prolongácia o 12 mesiacov' : 'bez automatickej prolongácie'} />
        <Kpi label="Zmluvné množstvo" value={`${mwh(vt + nt)} / rok`} sub={`${num(k.ooms.length, 0)} OOM · VT ${num(vt, 3)} · NT ${num(nt, 3)}`} />
        <Kpi label="Platnosť od (podpis)" value={date(k.signed_on)} sub={`fáza: ${CONTRACT_PHASE[k.phase] ?? k.phase}`} />
        <Kpi label="Príznaky" value={num(openFlags.length, 0)} sub={openFlags.length ? openFlags.map((f) => CONTRACT_FLAG[f.code]?.label ?? f.code).join(', ') : 'nič na kontrolu'} />
      </section>

      {openFlags.length > 0 && (
        <Card title="Na kontrolu">
          {openFlags.map((f) => (
            <Item
              key={f.id}
              title={<Pill tone={CONTRACT_FLAG[f.code]?.tone ?? 'neutral'}>{CONTRACT_FLAG[f.code]?.label ?? f.code}</Pill>}
              meta={`${f.detail ?? ''} · od ${date(f.raised_at)}`}
              side={
                k.can_edit && f.code !== 'chyba_cena' ? (
                  <button type="button" className="btn" disabled={save.busy} onClick={() => resolve(f.id)}>
                    Vyriešené
                  </button>
                ) : undefined
              }
            />
          ))}
          <div className="caption">„Chýba cena“ zmizne sama, keď cena pribudne (import, balík VIWA, cenník).</div>
        </Card>
      )}

      <Card title="Ceny po obdobiach" aside={<span className="caption">{groups.length < k.prices.length ? 'rovnaké ceny OOM zlúčené' : ''}</span>} flush>
        {k.prices.length === 0 ? (
          <div className="card-body">
            <Empty>Zmluva nemá ceny.</Empty>
          </div>
        ) : (
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Obdobie</th>
                  <th>Zložka</th>
                  <th>Produkt</th>
                  <th>Model</th>
                  <th className="num">VT / 1T [€/MWh]</th>
                  <th className="num">NT</th>
                  <th className="num">Aditív</th>
                  <th className="num">Mesačne</th>
                  <th>OOM</th>
                </tr>
              </thead>
              <tbody>
                {groups.map(({ p, eics }) => (
                  <tr key={p.id}>
                    <td>
                      {period(p.valid_from, p.valid_to)}
                      {p.status === 'platna' && <div className="sub">platí dnes</div>}
                    </td>
                    <td>{PRICE_SLOT[p.slot] ?? p.slot}</td>
                    <td className={p.op_product_name ? 'mono' : undefined} title={p.price_list_name ? `${p.price_list_name} ${p.price_list_version ?? ''}` : undefined}>
                      {text(p.op_product_name ?? p.product_name)}
                      {p.price_list_name && <div className="sub">{p.price_list_name}</div>}
                    </td>
                    <td>{PRICE_MODEL[p.price_model] ?? p.price_model}</td>
                    <td className="num">{eurMwh(p.price_vt_eur_mwh)}</td>
                    <td className="num">{eurMwh(p.price_nt_eur_mwh)}</td>
                    <td className="num">{p.additive_pct !== null && p.additive_pct !== undefined ? pct(p.additive_pct) : eurMwh(p.additive_eur_mwh)}</td>
                    <td className="num">
                      {p.fee_kw_eur_month !== null && p.fee_kw_eur_month !== undefined ? `${eurMonth(p.fee_kw_eur_month)} / kW` : eurMonth(p.fee_eur_month)}
                    </td>
                    <td className={eics.length === 1 ? 'mono' : undefined}>
                      {eics.length === 0 ? 'účet' : eics.length === 1 ? eics[0] : eics.length === k.ooms.length ? `všetky (${eics.length})` : `${eics.length} OOM`}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>

      <Card title="Odberné miesta" aside={<span className="caption">{num(k.ooms.length, 0)} OOM</span>} flush>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>EIC</th>
                <th>Adresa</th>
                <th>Typ / stav</th>
                <th>Sadzba</th>
                <th className="num">Istič</th>
                <th>Produkt</th>
                <th className="num">VT [MWh]</th>
                <th className="num">NT</th>
                <th>V zmluve</th>
              </tr>
            </thead>
            <tbody>
              {k.ooms.map((o) => (
                <tr key={o.id}>
                  <td>
                    <Link to={`/oom/${o.id}`} className="mono">
                      {o.eic}
                    </Link>
                  </td>
                  <td>{text([o.address_street, o.address_number_orientacne, o.address_city].filter(Boolean).join(' ') || o.name)}</td>
                  <td>
                    <span className="pills">
                      {label(OOM_TYPE, o.type)} <StatusPill map={OOM_STATUS} value={o.status} />
                    </span>
                  </td>
                  <td>{text(o.tariff_label)}</td>
                  <td className="num">{o.breaker_a === null ? '–' : `${num(o.breaker_a, 0)} A`}</td>
                  <td>
                    {text([o.product_name, o.program_name].filter(Boolean).join(' + '))}
                    {o.public_lighting && <div className="sub">verejné osvetlenie</div>}
                  </td>
                  <td className="num">{num(o.qty_vt_mwh, 3)}</td>
                  <td className="num">{num(o.qty_nt_mwh, 3)}</td>
                  <td>
                    {period(o.valid_from, o.valid_to)}
                    {o.successor_number && (
                      <div className="sub">
                        nástupca <Link to={`/zmluvy/${o.successor_id}`}>{o.successor_number}</Link>
                      </div>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <div className="columns">
        <div className="col-mid">
          <Card title="Údaje zmluvy">
            <Rows
              rows={[
                ['Fáza v Office portáli', text(CONTRACT_PHASE[k.phase] ?? k.phase)],
                ['Účinnosť (Office portal)', period(k.valid_from, k.valid_to)],
                ['Platnosť od (podpis)', date(k.signed_on)],
                ['Dôvod uzatvorenia', text(label(CLOSE_REASON, k.close_reason))],
                ['Uzatvoril', text(k.owner_name)],
                ['Vytvoril v Office portáli', text(k.created_by_name)],
                ['Malý podnik / cenníková cena', `${yes(k.small_business)} / ${yes(k.list_price)}`],
                ...(k.type === 'viwa' ? [['Balík VIWA', text(label(VIWA_PACKAGE, k.viwa_package))] as [string, string]] : []),
                ['Predošlá zmluva', k.previous_contract_id ? <Link to={`/zmluvy/${k.previous_contract_id}`}>{k.previous_number}</Link> : text(null)],
                [
                  'Súvisiaca zmluva',
                  k.related_contract_id ? (
                    <Link to={`/zmluvy/${k.related_contract_id}`}>
                      {k.related_number} · {CONTRACT_TYPE[k.related_type ?? ''] ?? ''}
                    </Link>
                  ) : (
                    text(null)
                  ),
                ],
                ...(k.predecessors.length
                  ? [['Skrátila zmluvy', <>{k.predecessors.map((p, i) => <span key={p.id}>{i > 0 && ', '}<Link to={`/zmluvy/${p.id}`}>{p.number}</Link></span>)}</>] as [string, React.ReactNode]]
                  : []),
                ['Poznámka', text(k.note)],
              ]}
            />
            <div className="caption">Údaje z Office portálu sú iba na čítanie – opravujú sa v Office portáli a ďalším importom.</div>
          </Card>
        </div>
        <div className="col-mid">
          <Card title="Časová os">
            {k.imports.length === 0 ? (
              <Empty>Zmluva zatiaľ neprišla importom.</Empty>
            ) : (
              k.imports.map((i) => (
                <Item
                  key={i.import_id}
                  title={i.action === 'nova' ? 'Zmluva založená' : 'Zmena z importu'}
                  meta={
                    <>
                      <div>{i.summary}</div>
                      <div className="sub">
                        {date(i.created_at)} · import z {i.xm_file_name && !i.op_file_name ? 'XM Trade' : 'Office portálu'}
                        {i.user_name ? ` · ${i.user_name}` : ''}
                      </div>
                    </>
                  }
                />
              ))
            )}
          </Card>
        </div>
      </div>
    </>
  );
}

function EditPanel(props: { k: ContractCard; onClose: () => void; onSaved: () => void }) {
  const { k } = props;
  const { data: filters } = useApi<{ users: { id: string; name: string }[] }>('/api/contract-filters');
  const [note, setNote] = useState(k.note ?? '');
  const [reason, setReason] = useState(k.close_reason ?? '');
  const [prev, setPrev] = useState(k.previous_number ?? '');
  const [rel, setRel] = useState(k.related_number ?? '');
  const [pkg, setPkg] = useState(k.viwa_package ?? '');
  const [owner, setOwner] = useState(k.owner_id ?? '');
  const save = useSave();
  const ownerOptions = (filters?.users ?? []).map((u) => ({ value: u.id, label: u.name }));

  const submit = () =>
    save.run(async () => {
      const body: Record<string, unknown> = {};
      if (note !== (k.note ?? '')) body.note = note;
      if (reason !== (k.close_reason ?? '')) body.close_reason = reason || null;
      if (prev !== (k.previous_number ?? '')) body.previous_number = prev;
      if (rel !== (k.related_number ?? '')) body.related_number = rel;
      if (k.type === 'viwa' && pkg !== (k.viwa_package ?? '')) body.viwa_package = pkg || null;
      if (k.can_change_owner && owner !== (k.owner_id ?? '')) body.owner_id = owner || null;
      await send('PATCH', `/api/contracts/${k.id}`, body);
      props.onSaved();
    });

  return (
    <SidePanel
      title={`Údaje CRM – ${k.number}`}
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={save.busy} onClick={submit}>
            {save.busy ? 'Ukladám…' : 'Uložiť'}
          </button>
        </>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {k.type === 'viwa' && (
        <Field label="Balík VIWA" hint="Kým ho Office portal neposiela, zadá ho Servis; ceny z cenníka Green VIWA sa doplnia samy.">
          <Select value={pkg} onChange={setPkg} options={[{ value: '', label: '– bez balíka –' }, ...Object.entries(VIWA_PACKAGE).map(([value, l]) => ({ value, label: l }))]} />
        </Field>
      )}
      <Field label="Dôvod uzatvorenia">
        <Select value={reason} onChange={setReason} options={[{ value: '', label: '–' }, ...Object.entries(CLOSE_REASON).map(([value, l]) => ({ value, label: l }))]} />
      </Field>
      <Field label="Predošlá zmluva" hint="Číslo zmluvy (retencia, prepis, obnova); prázdne = bez väzby.">
        <TextInput value={prev} onChange={setPrev} maxLength={30} />
      </Field>
      <Field label="Súvisiaca zmluva" hint="VIWA ↔ zmluva o dodávke toho istého zákazníka.">
        <TextInput value={rel} onChange={setRel} maxLength={30} />
      </Field>
      {k.can_change_owner && (
        <Field label="Obchodník (Uzatvoril)" hint="Mení iba vedenie a admin. Ďalší import s vyplneným obchodníkom ho prepíše.">
          <Select value={owner} onChange={setOwner} options={[{ value: '', label: '– bez obchodníka –' }, ...ownerOptions]} />
        </Field>
      )}
      <Field label="Poznámka">
        <textarea className="inp" rows={4} value={note} maxLength={2000} onChange={(e) => setNote(e.target.value)} />
      </Field>
    </SidePanel>
  );
}
