// Karta zmluvy podľa docs/dizajn/obrazovky/26-zmluva-karta.html (modul Zmluvy, F2).
// Údaje z Office portálu sú iba na čítanie (opravujú sa v Office portáli a ďalším importom). V CRM sa mení poznámka,
// dôvod uzatvorenia, predošlá a súvisiaca zmluva, balík VIWA (Servis) a obchodník (vedenie, admin).
// Ročná bilancia (0027): pridaná hodnota obchodníka (iba komodita) a marža firmy (iba s právom) po rokoch.
// Prolongácia (0028): pri príznaku „Sprolongované bez novej ceny“ navrhnutý produkt (cenník nad 30 MWh) a potvrdenie
// s poznámkou (odpoveď 36) – kto smie zmluvu upraviť (Servis všetky, obchodník svoje).

import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from '../components/form';
import { RegulationNotice } from '../components/regulation';
import { PageHero } from '../components/hero';
import { Card, Empty, ErrorState, Item, Kpi, PageSkeleton, Pill, Rows, StatusPill } from '../components/ui';
import { send, useApi, type ContractCard, type ContractYear } from '../lib/api';
import { useMe } from '../lib/me';
import { date, eur, eurMonth, eurMwh, mwh, num, pct, period, text } from '../lib/format';
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
  const [pickYear, setPickYear] = useState<number | null>(null);
  const [confirming, setConfirming] = useState<string | null>(null);
  const [closing, setClosing] = useState<string | null>(null);
  const save = useSave();
  const me = useMe();

  if (error) return <ErrorState error={error} />;
  if (!k || k.id !== id) return <PageSkeleton />;

  const customerPath = k.company_id ? `/firmy/${k.company_id}` : `/osoby/${k.person_id}`;
  const vt = k.ooms.reduce((s, o) => s + Number(o.qty_vt_mwh ?? 0), 0);
  const nt = k.ooms.reduce((s, o) => s + Number(o.qty_nt_mwh ?? 0), 0);
  const openFlags = k.flag_rows.filter((f) => !f.resolved_at);
  const models = [...new Set(k.prices.filter((p) => p.slot === 'komodita').map((p) => PRICE_MODEL[p.price_model] ?? p.price_model))];
  const groups = groupPrices(k.prices);
  const thisYear = new Date().getFullYear();
  const bal: ContractYear | undefined =
    k.balance.find((b) => b.year === pickYear) ?? k.balance.find((b) => b.year === thisYear) ?? k.balance.find((b) => b.year > thisYear) ?? k.balance.at(-1);
  const resolve = (flagId: string, note?: string) =>
    save.run(async () => {
      await send('POST', `/api/contract-flags/${flagId}/resolve`, { note: note ?? '' });
      setConfirming(null);
      reload();
    });
  // Navrhnutý produkt prolongácie: cenníkové ceny komodity po konci účinnosti z Office portálu
  const prolongProducts = [
    ...new Set(
      k.prices
        .filter((p) => p.slot === 'komodita' && p.price_model === 'cennik' && !!k.valid_to && !!p.valid_from && p.valid_from > k.valid_to)
        .map((p) => p.product_name ?? p.product ?? '–'),
    ),
  ];

  return (
    <>
      <PageHero
        size="detail"
        card
        above={
          <>
            <Link to="/zmluvy">Zmluvy</Link> / {k.number}
          </>
        }
        title={<span className="gl-mono hero-mono">{k.number}</span>}
        sub={
          <span className="hero-meta">
            <StatusPill map={CONTRACT_STATUS} value={k.state} />
            <Pill>{CONTRACT_TYPE[k.type] ?? k.type}</Pill>
            {models.map((m) => (
              <Pill key={m} tone="info">
                {m}
              </Pill>
            ))}
            {openFlags.map((f) => (
              <Pill key={f.id} tone={CONTRACT_FLAG[f.code]?.tone ?? 'neutral'} live>
                {CONTRACT_FLAG[f.code]?.label ?? f.code}
              </Pill>
            ))}
            <span>
              <Link to={customerPath}>{k.customer_name || '(bez mena)'}</Link> · {k.owner_name ?? 'bez obchodníka'}
            </span>
          </span>
        }
        actions={
          k.can_edit ? (
            <button type="button" className="btn" onClick={() => setEditing(true)}>
              Upraviť údaje CRM
            </button>
          ) : undefined
        }
      />
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {closing && (
        <CloseThresholdPanel
          busy={save.busy}
          error={save.error}
          onClose={() => setClosing(null)}
          onConfirm={(note) => resolve(closing, note).then(() => setClosing(null))}
        />
      )}
      {confirming && (
        <ConfirmProlongPanel
          products={prolongProducts}
          busy={save.busy}
          onClose={() => setConfirming(null)}
          onConfirm={(note) => resolve(confirming, note)}
        />
      )}
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

      <RegulationNotice check={k.regulation_check} />
      {k.volume_check?.over && (
        <div className="reg-notice warn" role="alert">
          <Pill tone="warning">Objem ≠ XM Trade</Pill>
          <span>{k.volume_check.message}</span>
        </div>
      )}
      <section className="kpis" aria-label="Ukazovatele">
        <Kpi
          label="Účinnosť"
          value={period(k.valid_from, k.effective_to)}
          sub={
            k.crm_valid_to && k.valid_to && k.crm_valid_to > k.valid_to
              ? `sprolongovaná · pôvodne do ${date(k.valid_to)}`
              : k.auto_prolong
                ? 'automatická prolongácia o 12 mesiacov'
                : 'bez automatickej prolongácie'
          }
        />
        <Kpi label="Zmluvné množstvo" value={`${mwh(vt + nt)} / rok`} sub={`${num(k.ooms.length, 0)} OOM · VT ${num(vt, 3)} · NT ${num(nt, 3)}`} />
        <Kpi
          label={`Pridaná hodnota ${bal?.year ?? ''}`}
          value={bal?.added_value_eur === null || bal?.added_value_eur === undefined ? '–' : `${eur(bal.added_value_eur)} €`}
          sub={bal ? addedValueNote(bal) : 'zmluva nemá obdobie'}
        />
        {me.can_see_margin ? (
          <Kpi
            label={`Marža firmy ${bal?.year ?? ''}`}
            value={bal?.margin_eur === null || bal?.margin_eur === undefined ? '–' : `${eur(bal.margin_eur)} €`}
            sub={bal?.portfolio_on ? `odhad ${num(bal.portfolio_eur_mwh, 2)} k ${date(bal.portfolio_on)}${bal.portfolio_stale ? ' · starý odhad' : ''}` : 'komodita + poplatky'}
          />
        ) : (
          <Kpi label="Platnosť od (podpis)" value={date(k.signed_on)} sub={`fáza: ${CONTRACT_PHASE[k.phase] ?? k.phase}`} />
        )}
      </section>

      <DealMatchCard k={k} onChanged={reload} />

      {openFlags.length > 0 && (
        <Card title="Na kontrolu">
          {openFlags.map((f) => (
            <Item
              key={f.id}
              title={<Pill tone={CONTRACT_FLAG[f.code]?.tone ?? 'neutral'}>{CONTRACT_FLAG[f.code]?.label ?? f.code}</Pill>}
              meta={`${f.detail ?? ''} · od ${date(f.raised_at)}`}
              side={
                f.code === 'pod_hranicou_bez_vynimky' || f.code === 'cena_ina_ako_v_ponuke' ? (
                  k.can_resolve_threshold ? (
                    <button type="button" className="btn" disabled={save.busy} onClick={() => setClosing(f.id)}>
                      Uzavrieť s poznámkou
                    </button>
                  ) : (
                    <span className="caption">uzatvára schvaľovateľ cien</span>
                  )
                ) : k.can_edit && f.code === 'sprolongovane_bez_ceny' ? (
                  <button type="button" className="btn" disabled={save.busy} onClick={() => setConfirming(f.id)}>
                    Potvrdiť produkt
                  </button>
                ) : k.can_edit && f.code !== 'chyba_cena' ? (
                  <button type="button" className="btn" disabled={save.busy} onClick={() => resolve(f.id)}>
                    Vyriešené
                  </button>
                ) : undefined
              }
            />
          ))}
          <div className="caption">
            „Chýba cena“ zmizne sama, keď cena pribudne (import, balík VIWA, cenník). „Pod hranicou bez výnimky“ a „Cena iná ako
            v ponuke“ uzatvára iba schvaľovateľ cien s poznámkou; „Pod hranicou“ sa uzavrie aj sama schválenou výnimkou.
          </div>
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

      <div className="columns">
      <div className="col-wide">
      <Card title="Odberné miesta" aside={<span className="caption">{num(k.ooms.length, 0)} OOM</span>} flush>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>EIC</th>
                <th>Adresa</th>
                <th>Sadzba / istič</th>
                <th>Produkt</th>
                <th className="num">VT [MWh]</th>
                <th className="num">NT</th>
                <th className="num" title="Plánovaná spotreba VT + NT z XM Trade; pri zmluve kratšej ako rok za obdobie zmluvy">
                  XM Trade
                </th>
              </tr>
            </thead>
            <tbody>
              {k.ooms.map((o) => (
                <tr key={o.id}>
                  <td>
                    <Link to={`/oom/${o.id}`} className="mono">
                      {o.eic}
                    </Link>
                    <div className="sub">
                      {label(OOM_TYPE, o.type)} · {OOM_STATUS[o.status]?.label ?? o.status}
                      {o.successor_number && (
                        <>
                          {' · do '}
                          {date(o.valid_to)} (nástupca <Link to={`/zmluvy/${o.successor_id}`}>{o.successor_number}</Link>)
                        </>
                      )}
                    </div>
                  </td>
                  <td className="wrap">{text([o.address_street, o.address_number_orientacne, o.address_city].filter(Boolean).join(' ') || o.name)}</td>
                  <td>
                    {text(o.tariff_label)}
                    {o.breaker_a !== null && <div className="sub">{num(o.breaker_a, 0)} A</div>}
                  </td>
                  <td className="wrap">
                    {text([o.product_name, o.program_name].filter(Boolean).join(' + '))}
                    {o.public_lighting && <div className="sub">verejné osvetlenie</div>}
                  </td>
                  <td className="num">{num(o.qty_vt_mwh, 3)}</td>
                  <td className="num">{num(o.qty_nt_mwh, 3)}</td>
                  <td className="num">
                    <XmCell o={o} months={k.volume_check?.months ?? 12} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      </div>
      <div className="col-right">
        <BalanceCard k={k} bal={bal} onYear={setPickYear} margin={me.can_see_margin} />
      </div>
      </div>

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
                ['Tranža pre Cockpit', text(bal?.tranche)],
                ...(k.type === 'vykup'
                  ? [['Minimálny aditív výkupu', k.vykup_min_additive === null ? 'podľa parametra' : `${eurMwh(k.vykup_min_additive)} (Nákup)`] as [string, string]]
                  : []),
                ...(k.exceptions.length
                  ? [['Výnimka z ceny', k.exceptions.map((e) => `${e.requested_value} (${e.years.join(', ')}) – ${e.decided_by_name ?? ''}`).join('; ')] as [string, string]]
                  : []),
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
  const [vykup, setVykup] = useState(k.vykup_min_additive === null ? '' : String(k.vykup_min_additive));
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
      if (k.type === 'vykup' && k.can_edit_vykup && vykup !== (k.vykup_min_additive === null ? '' : String(k.vykup_min_additive))) {
        body.vykup_min_additive = vykup.trim() === '' ? null : vykup;
      }
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
      {k.type === 'vykup' && k.can_edit_vykup && (
        <Field label="Minimálny aditív výkupu [€/MWh]" hint="Prepis parametra pre túto zmluvu (Nákup). Prázdne = podľa Cenových parametrov.">
          <TextInput value={vykup} onChange={setVykup} maxLength={12} />
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

function addedValueNote(b: ContractYear): string {
  if (b.missing && (b.added_value_eur === null || b.added_value_eur === undefined)) return `chýba ${b.missing}`;
  if (b.exception_value !== null && b.exception_value !== undefined) return `hranica z výnimky ${eurMwh(b.exception_value)} · iba komodita`;
  if (b.trader_price !== null && b.trader_price !== undefined && b.model?.includes('fix')) {
    return `cena pre obchodníka ${eurMwh(b.trader_price)}${b.basis_source === 'hubspot' ? ' (HubSpot)' : ''} · iba komodita`;
  }
  return 'iba komodita (základ provízie)';
}

/** Ročná bilancia (návrh 26): výnos, náklad, pridaná hodnota; marža firmy iba s právom. */
function BalanceCard(props: { k: ContractCard; bal: ContractYear | undefined; onYear: (y: number) => void; margin: boolean }) {
  const { k, bal } = props;
  if (!bal) {
    return (
      <Card title="Ročná bilancia">
        <Empty>Zmluva nemá obdobie účinnosti – bilancia sa počíta od začiatku účinnosti.</Empty>
      </Card>
    );
  }
  const cost = bal.volume_mwh && Number(bal.volume_mwh) > 0 && bal.cost_eur !== null ? Number(bal.cost_eur) / Number(bal.volume_mwh) : null;
  const rows: [string, React.ReactNode][] = [
    ['Objem', `${num(bal.volume_mwh, 3)} MWh · ${bal.months} mes.`],
    ['Výnos komodita', bal.revenue_eur === null ? '–' : `${eur(bal.revenue_eur)} €`],
    [`Náklad pridanej hodnoty${cost !== null ? ` (${num(cost, 2)} €/MWh)` : ''}`, bal.cost_eur === null ? `– ${bal.missing ? `(chýba ${bal.missing})` : ''}` : `${eur(bal.cost_eur)} €`],
    ['Pridaná hodnota (provízia)', <strong>{bal.added_value_eur === null ? '–' : `${eur(bal.added_value_eur)} €`}</strong>],
  ];
  if (props.margin) {
    rows.push(
      ['Mesačné platby (OM, ZEM, VBattery, VIWA)', `${eur(bal.fees_eur)} €`],
      ['Náklad marže', bal.margin_cost_eur === null ? '–' : `${eur(bal.margin_cost_eur)} €${bal.portfolio_on ? ` (odhad k ${date(bal.portfolio_on)})` : ''}`],
      ['Marža firmy', <strong>{bal.margin_eur === null ? '–' : `${eur(bal.margin_eur)} €`}{bal.portfolio_stale && <Pill tone="warning">starý odhad</Pill>}</strong>],
    );
  }
  return (
    <Card title={`Ročná bilancia ${bal.year}`}>
      {k.balance.length > 1 && (
        <div className="chips" role="group" aria-label="Rok bilancie" style={{ marginBottom: 8 }}>
          {k.balance.map((b) => (
            <button key={b.year} type="button" className="chip" aria-pressed={b.year === bal.year} onClick={() => props.onYear(b.year)}>
              {b.year}
            </button>
          ))}
        </div>
      )}
      <Rows rows={rows} />
      <div className="caption" style={{ marginTop: 8 }}>
        {bal.basis_stored === false ? 'Zmluva nie je podpísaná – počíta sa s hodnotami k dnešku. ' : 'Náklad pridanej hodnoty ku dňu podpisu. '}
        {props.margin ? 'Marža firmy z dnes platnej nákupnej ceny portfólia.' : 'Maržu firmy vidí iba CEO, Nákup, Marketing a obchodný riaditeľ.'}
      </div>
    </Card>
  );
}

/** Servis potvrdí navrhnutý produkt prolongácie (odpoveď 36): iný produkt = nová zmluva v Office portáli. */
function ConfirmProlongPanel(props: { products: string[]; busy: boolean; onClose: () => void; onConfirm: (note: string) => void }) {
  const [note, setNote] = useState('');
  return (
    <SidePanel
      title="Potvrdiť produkt prolongácie"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={props.busy} onClick={() => props.onConfirm(note)}>
            Potvrdiť
          </button>
        </>
      }
    >
      <Rows
        rows={[
          [
            'Navrhnutý produkt',
            props.products.length > 0 ? props.products.join(', ') : 'bez cenníka – pokračuje posledná cena alebo aditív zo zmluvy',
          ],
        ]}
      />
      <Field label="Poznámka" hint="Nepovinné. Iný produkt sa nemení tu – dojedná sa nová zmluva v Office portáli.">
        <TextInput value={note} onChange={setNote} maxLength={500} />
      </Field>
    </SidePanel>
  );
}

/** „Pod hranicou bez výnimky“ uzatvára iba schvaľovateľ cien s povinnou poznámkou (zadanie časť 7, 0029). */
function CloseThresholdPanel(props: { busy: boolean; error: string | null; onClose: () => void; onConfirm: (note: string) => void }) {
  const [note, setNote] = useState('');
  return (
    <SidePanel
      title="Uzavrieť „Pod hranicou bez výnimky“"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={props.busy || note.trim() === ''} onClick={() => props.onConfirm(note.trim())}>
            Uzavrieť
          </button>
        </>
      }
    >
      {props.error && <Notice tone="error">{props.error}</Notice>}
      <Field label="Poznámka" hint="Povinná – prečo cena pod hranicou ostáva bez výnimky.">
        <TextInput value={note} onChange={setNote} maxLength={500} autoFocus />
      </Field>
    </SidePanel>
  );
}

/** Plánovaná spotreba z XM Trade pri OOM a rozdiel oproti zmluvnému množstvu (0030); nad 5 % zvýraznené. */
function XmCell(props: { o: ContractCard['ooms'][number]; months: number }) {
  const { o } = props;
  if (o.type !== 'spotreba') return <>–</>;
  if (o.xm_mwh === null || Number(o.xm_mwh) <= 0) return <span className="caption">chýba</span>;
  const xm = (Number(o.xm_mwh) * props.months) / 12;
  const qty = Number(o.qty_vt_mwh ?? 0) + Number(o.qty_nt_mwh ?? 0);
  const pctDiff = ((qty - xm) / xm) * 100;
  const over = Math.abs(qty - xm) > 0.05 * xm;
  return (
    <>
      {num(xm, 3)}
      <div className={`sub${over ? ' text-negative' : ''}`}>
        {pctDiff >= 0 ? '+' : '−'}
        {num(Math.abs(pctDiff), 1)} %
      </div>
    </>
  );
}

const MATCH_LABEL: Record<string, string> = { auto: 'automaticky pri importe', rucne: 'ručne' };
const STAGE_LABEL: Record<string, string> = {
  prilezitost: 'Príležitosť', cenova_ponuka: 'Cenová ponuka', vyjednavanie: 'Vyjednávanie', akceptacia: 'Akceptácia', vyhrane: 'Vyhraté', prehrane: 'Prehraté',
};

/** Obchod k zmluve (F5, 0045): spárovaný obchod a ponuka, nespárovaná s kandidátmi, bez obchodu; ručné rozhodnutia. */
function DealMatchCard(props: { k: ContractCard; onChanged: () => void }) {
  const { k } = props;
  const [panel, setPanel] = useState<null | 'unlink' | 'none'>(null);
  const [note, setNote] = useState('');
  const save = useSave();
  if (!k.deal_match && !k.deal_id) return null;
  const act = (fn: () => Promise<unknown>) =>
    save.run(async () => {
      await fn();
      setPanel(null);
      setNote('');
      props.onChanged();
    });
  return (
    <Card title="Obchod">
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {k.deal_id ? (
        <Rows
          rows={[
            ['Obchod', <><Link to={`/obchody/${k.deal_id}`}>{k.deal_name}</Link>{k.deal_stage ? ` · ${STAGE_LABEL[k.deal_stage] ?? k.deal_stage}` : ''}</>],
            ['Ponuka', k.offer_id ? <Link to={`/ponuky/${k.offer_id}`}>{k.offer_number} · variant {k.offer_variant}</Link> : 'spárované bez akceptovanej ponuky'],
            ['Spárované', k.deal_match ? `${MATCH_LABEL[k.deal_match] ?? k.deal_match}${k.deal_matched_at ? ` ${date(k.deal_matched_at)}` : ''}${k.deal_matched_by_name ? ` · ${k.deal_matched_by_name}` : ''}` : 'pred zavedením párovania'],
          ]}
        />
      ) : k.deal_match === 'bez_obchodu' ? (
        <p>
          <Pill>Bez obchodu</Pill> {k.deal_matched_by_name ? `označil ${k.deal_matched_by_name}` : 'automaticky'}
          {k.deal_matched_at ? ` ${date(k.deal_matched_at)}` : ''}{k.deal_match_note ? ` – ${k.deal_match_note}` : ''}
        </p>
      ) : (
        <>
          <p>
            <Pill tone="warning">Nespárovaná</Pill> Import nenašiel jednoznačne obchod toho istého zákazníka, ktorého OOM sa zhodujú so zmluvou.
            {k.deal_match_note ? ` (${k.deal_match_note})` : ''}
          </p>
          {(k.deal_candidates ?? []).length === 0 ? (
            <Empty>Žiadny otvorený obchod zákazníka v Akceptácii ani vo Vyjednávaní.</Empty>
          ) : (
            (k.deal_candidates ?? []).map((d) => (
              <Item
                key={d.deal_id}
                title={<Link to={`/obchody/${d.deal_id}`}>{d.name}</Link>}
                meta={`${STAGE_LABEL[d.stage] ?? d.stage} · zhoda EIC ${d.eic_match} / ${d.eic_total}${d.ok ? '' : ' (nie všetky)'}`}
                side={k.can_decide_deal ? (
                  <button type="button" className="btn" disabled={save.busy} onClick={() => act(() => send('POST', `/api/contracts/${k.id}/deal`, { deal_id: d.deal_id }))}>
                    Vybrať obchod
                  </button>
                ) : undefined}
              />
            ))
          )}
          {k.can_decide_deal && (
            <div className="row-actions">
              <button type="button" className="btn" onClick={() => setPanel('none')}>Bez obchodu</button>
            </div>
          )}
          {!k.can_decide_deal && <div className="caption">O obchode k zmluve rozhoduje vlastník zákazníka alebo admin.</div>}
        </>
      )}
      {k.is_admin && (k.deal_match === 'auto' || k.deal_match === 'rucne' || k.deal_match === 'bez_obchodu') && (
        <div className="row-actions">
          <button type="button" className="btn" onClick={() => setPanel('unlink')}>Zrušiť spárovanie</button>
        </div>
      )}
      {panel && (
        <SidePanel
          title={panel === 'unlink' ? 'Zrušiť spárovanie' : 'Bez obchodu'}
          onClose={() => setPanel(null)}
          footer={
            <button type="button" className="btn primary" disabled={save.busy || (panel === 'unlink' && !note.trim())}
              onClick={() => act(() => panel === 'unlink'
                ? send('POST', `/api/contracts/${k.id}/unlink`, { reason: note })
                : send('POST', `/api/contracts/${k.id}/no-deal`, { note }))}>
              {panel === 'unlink' ? 'Zrušiť spárovanie' : 'Označiť bez obchodu'}
            </button>
          }
        >
          {save.error && <Notice tone="error">{save.error}</Notice>}
          <p>
            {panel === 'unlink'
              ? 'Zmluva sa vráti medzi nespárované. Ak obchod nemá inú spárovanú zmluvu, vráti sa do štádia, z ktorého bol spárovaný (Akceptácia alebo Vyjednávanie). Výnimky z ponuky a príznak „Cena iná ako v ponuke“ pri zmluve sa zrušia.'
              : 'Zmluva nepatrí k žiadnemu obchodu (napr. domácnosť z webu). Je to rozhodnutie, nie problém – v zozname zmlúv bude filter „Bez obchodu“.'}
          </p>
          <Field label={panel === 'unlink' ? 'Dôvod' : 'Poznámka (nepovinné)'}>
            <TextInput value={note} maxLength={500} onChange={setNote} />
          </Field>
        </SidePanel>
      )}
    </Card>
  );
}

