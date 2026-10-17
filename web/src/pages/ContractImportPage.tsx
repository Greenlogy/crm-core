// Import zmlúv z Office portálu a OOM z XM Trade podľa docs/dizajn/obrazovky/27-zmluvy-import.html (modul Zmluvy, F2).
// Jeden alebo oba exporty naraz → náhľad po zmluvách (nič sa neuloží) → uloženie. Neznámy názov (fáza, produkt,
// obchodník, číselník XM) = chyba s „Pridať preklad“ (admin); po pridaní sa náhľad prepočíta. Uloženie prijme iba tie
// isté súbory a rovnaké počty ako náhľad. Súbory sa nikde neukladajú; dátum narodenia a rodné číslo sa nečítajú.

import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Field, Notice, Select, SidePanel } from '../components/form';
import { BackLink, Card, Empty, Item, Pill, Rows } from '../components/ui';
import { ApiError, send, useApi } from '../lib/api';
import { date, num } from '../lib/format';
import { permission, useMe } from '../lib/me';

type Source = 'office_portal' | 'xm_trade';
type Missing = { source: string; kind: string; name: string };
type ContractRow = {
  number: string | null;
  source: Source;
  rows: number[];
  customer: string | null;
  action: 'nova' | 'zmena' | 'bez_zmeny' | 'chyba' | 'preskocene';
  contract_id?: string;
  changes: string[];
  warnings: string[];
  errors: string[];
  missing?: Missing[];
  customer_new?: boolean;
};
type OomRow = { row: number; eic: string | null; action: 'nove' | 'zmena' | 'bez_zmeny' | 'chyba'; error?: string; warnings?: string[]; missing?: Missing[]; customer?: string | null; oom_id?: string };
type Counts = {
  zmluvy: { spolu: number; nova: number; zmena: number; bez_zmeny: number; chyba: number; preskocene: number; upozornenie: number };
  oom: { spolu: number; nove: number; zmena: number; bez_zmeny: number; chyba: number; upozornenie: number };
};
type Preview = {
  files: { source: Source; file_name: string; sheet: string; hash: string; rows: number }[];
  counts: Counts;
  contracts: ContractRow[];
  oom: OomRow[];
  timing_ms: { citanie: number; kontrola: number };
};
type FileIn = { name: string; data: string };
type Filter = 'vsetky' | 'upozornenie' | ContractRow['action'];
type History = { items: { id: string; created_at: string; op_file_name: string | null; xm_file_name: string | null; counts: Counts; user_name: string | null }[] };

const ACTION: Record<ContractRow['action'], { label: string; tone: 'positive' | 'info' | 'neutral' | 'negative' | 'warning' }> = {
  nova: { label: 'Nová', tone: 'positive' },
  zmena: { label: 'Zmena', tone: 'info' },
  bez_zmeny: { label: 'Bez zmeny', tone: 'neutral' },
  chyba: { label: 'Chyba', tone: 'negative' },
  preskocene: { label: 'Preskočené (test)', tone: 'neutral' },
};
const OOM_ACTION: Record<OomRow['action'], { label: string; tone: 'positive' | 'info' | 'neutral' | 'negative' }> = {
  nove: { label: 'Nové', tone: 'positive' },
  zmena: { label: 'Zmena', tone: 'info' },
  bez_zmeny: { label: 'Bez zmeny', tone: 'neutral' },
  chyba: { label: 'Chyba', tone: 'negative' },
};
const KIND: Record<string, string> = {
  faza: 'fáza',
  obchodnik: 'obchodník',
  produkt_op: 'cenový produkt',
  produkt_oom: 'produkt pri OOM',
  sadzba: 'sadzba',
  pds: 'PDS',
  typ_merania: 'typ merania',
  fakturacne_obdobie: 'fakturačné obdobie',
  sposob_zaloh: 'spôsob záloh',
};
const MAX_BYTES = 10 * 1024 * 1024;

function toBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const r = new FileReader();
    r.onload = () => resolve(String(r.result).split(',')[1] ?? '');
    r.onerror = () => reject(new Error('Súbor sa nedá prečítať.'));
    r.readAsDataURL(file);
  });
}

async function post<T>(path: string, body: unknown): Promise<T> {
  const res = await fetch(path, { method: 'POST', headers: { Accept: 'application/json', 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const data = (await res.json().catch(() => ({}))) as T & { error?: string };
  if (!res.ok) throw new ApiError(res.status, data.error ?? `Chyba ${res.status}`);
  return data;
}

export function ContractImportPage() {
  const me = useMe();
  const canImport = permission(me, 'zmluvy').import;
  const [orgId, setOrgId] = useState(me.orgs.find((o) => o.default)?.id ?? me.orgs[0]?.id ?? '');
  const [slots, setSlots] = useState<{ op: FileIn | null; xm: FileIn | null }>({ op: null, xm: null });
  const files = [slots.op, slots.xm].filter((f): f is FileIn => f !== null);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [filter, setFilter] = useState<Filter>('vsetky');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<Counts | null>(null);
  const [adding, setAdding] = useState<Missing | null>(null);
  const history = useApi<History>('/api/contract-import/history');
  const [showHistory, setShowHistory] = useState(false);
  const [tab, setTab] = useState<Source>('office_portal');

  if (!canImport) {
    return (
      <>
        <BackLink />
        <Empty>Import zmlúv nemáte povolený (Nastavenia → Tímy a práva → Zmluvy → Importovať).</Empty>
      </>
    );
  }

  const body = (list: FileIn[]) => ({ org: orgId, files: list.map((f) => ({ file_name: f.name, data_base64: f.data })) });

  const runPreview = async (list: FileIn[]) => {
    setBusy(true);
    setError(null);
    setSaved(null);
    try {
      setPreview(await post<Preview>('/api/contract-import/preview', body(list)));
    } catch (e) {
      setPreview(null);
      setError(e instanceof Error ? e.message : 'Náhľad zlyhal.');
    } finally {
      setBusy(false);
    }
  };

  /** Súbor do políčka Office portál alebo XM Trade (zostavu aj tak rozpozná API podľa hlavičiek). */
  const pick = async (slot: 'op' | 'xm', f: File | undefined) => {
    if (!f) return;
    if (f.size > MAX_BYTES) {
      setError(`${f.name}: súbor je väčší ako 10 MB.`);
      return;
    }
    setError(null);
    const loaded = { name: f.name, data: await toBase64(f) };
    setSlots((s) => ({ ...s, [slot]: loaded }));
  };

  const check = async () => {
    setFilter('vsetky');
    await runPreview(files);
  };

  const save = async () => {
    if (!preview) return;
    setBusy(true);
    setError(null);
    try {
      const r = await post<{ counts: Counts }>('/api/contract-import/save', {
        ...body(files),
        hashes: Object.fromEntries(preview.files.map((f) => [f.source, f.hash])),
        counts: preview.counts,
      });
      setSaved(r.counts);
      setPreview(null);
      setSlots({ op: null, xm: null });
      history.reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Uloženie zlyhalo.');
    } finally {
      setBusy(false);
    }
  };

  const downloadErrors = async () => {
    setBusy(true);
    try {
      const res = await fetch('/api/contract-import/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body(files)),
      });
      if (!res.ok) throw new Error('Súbor s chybami sa nedá vytvoriť.');
      const url = URL.createObjectURL(await res.blob());
      const a = document.createElement('a');
      a.href = url;
      a.download = 'zmluvy-import-chyby.xlsx';
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Stiahnutie zlyhalo.');
    } finally {
      setBusy(false);
    }
  };

  const step = saved ? 3 : preview ? 2 : 1;
  const c = preview?.counts;
  const rows = preview
    ? preview.contracts.filter((r) =>
        filter === 'vsetky' ? true : filter === 'upozornenie' ? r.warnings.length > 0 && r.action !== 'chyba' && r.action !== 'preskocene' : r.action === filter,
      )
    : [];
  const missing = preview
    ? [...new Map([...preview.contracts.flatMap((r) => r.missing ?? []), ...preview.oom.flatMap((r) => r.missing ?? [])].map((m) => [`${m.source}|${m.kind}|${m.name}`, m])).values()]
    : [];
  const valid = c ? c.zmluvy.nova + c.zmluvy.zmena + c.oom.nove + c.oom.zmena : 0;
  const errorsCount = c ? c.zmluvy.chyba + c.oom.chyba : 0;
  const opFile = preview?.files.find((f) => f.source === 'office_portal');
  const xmFile = preview?.files.find((f) => f.source === 'xm_trade');
  const shownTab: Source = tab === 'xm_trade' && xmFile ? 'xm_trade' : opFile ? 'office_portal' : 'xm_trade';

  const steps = (
    <ol className="import-steps" aria-label="Kroky importu" style={{ margin: 0 }}>
      {['Nahratie', 'Náhľad a kontrola', 'Uloženie'].map((s, i) => (
        <li key={s} className={i + 1 < step ? 'done' : i + 1 === step ? 'current' : undefined}>
          <span className="import-step-no">{i + 1 < step ? '✓' : i + 1}</span> {s}
        </li>
      ))}
    </ol>
  );

  return (
    <>
      <Link to="/zmluvy" className="back">
        ← Zmluvy
      </Link>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Import zmlúv</h1>
          <div className="page-sub">
            <span>zmluvy a ceny z Office portálu, odberné miesta z XM Trade</span>
          </div>
        </div>
        <div className="head-actions">
          {me.orgs.length > 1 && (
            <select className="input select" aria-label="Spoločnosť" value={orgId} disabled={!!preview} onChange={(e) => setOrgId(e.target.value)}>
              {me.orgs.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          )}
          <button type="button" className="btn" aria-pressed={showHistory} onClick={() => setShowHistory((v) => !v)}>
            História importov
          </button>
        </div>
      </header>

      {error && <Notice tone="error">{error}</Notice>}
      {saved && (
        <Notice tone="ok">
          Uložené: {count(saved.zmluvy.nova, ['nová zmluva', 'nové zmluvy', 'nových zmlúv'])}, {count(saved.zmluvy.zmena, ['zmena', 'zmeny', 'zmien'])},{' '}
          {count(saved.oom.nove + saved.oom.zmena, ['OOM', 'OOM', 'OOM'])} nových alebo zmenených
          {saved.zmluvy.chyba + saved.oom.chyba ? `; s chybou sa neuložilo ${saved.zmluvy.chyba + saved.oom.chyba}` : ''}. Import je v audite.{' '}
          <Link to="/zmluvy">Späť na zoznam</Link>
        </Notice>
      )}

      {showHistory && (
        <Card title="História importov">
          {!history.data || history.data.items.length === 0 ? (
            <Empty>Zatiaľ žiadny uložený import.</Empty>
          ) : (
            history.data.items.map((h) => (
              <Item
                key={h.id}
                title={[h.op_file_name, h.xm_file_name].filter(Boolean).join(' + ')}
                meta={`${date(h.created_at)}${h.user_name ? ` · ${h.user_name}` : ''}`}
                side={`zmluvy: ${num(h.counts.zmluvy?.nova ?? 0, 0)} nové, ${num(h.counts.zmluvy?.zmena ?? 0, 0)} zmenené · OOM: ${num(h.counts.oom?.nove ?? 0, 0)} nové`}
              />
            ))
          )}
        </Card>
      )}

      {!preview && (
        <Card>
          <div className="toolbar" style={{ justifyContent: 'flex-end' }}>{steps}</div>
          <div className="card-body">
            <p className="caption">
              Prvý import (a vždy, keď prichádzajú nové odberné miesta): <strong>oba súbory naraz</strong> – najprv sa založia OOM z XM Trade,
              potom zmluvy. Neskôr stačí aj iba jeden z nich. Najviac 5 000 riadkov a 10 MB na súbor. Dátum narodenia a rodné číslo sa nečítajú,
              súbory sa neuchovávajú.
            </p>
            <div className="columns">
              {(
                [
                  ['op', 'Export z Office portálu', '„HEO – Web Zmluvy – prehľad EE“ – zmluvy a ceny'],
                  ['xm', 'Export z XM Trade', '„Prehľad“ odberných miest – OOM, účinnosť domácností, VBattery'],
                ] as const
              ).map(([slot, title, hint]) => (
                <div key={slot} className="col-mid">
                  <div className="kl">{title}</div>
                  <div className="caption" style={{ margin: '4px 0 8px' }}>
                    {hint}
                  </div>
                  <label className="btn" style={{ display: 'inline-flex' }}>
                    {slots[slot] ? `✓ ${slots[slot]!.name}` : 'Vybrať súbor .xlsx'}
                    <input
                      type="file"
                      accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                      style={{ display: 'none' }}
                      disabled={busy}
                      onChange={(e) => {
                        void pick(slot, e.target.files?.[0]);
                        e.target.value = '';
                      }}
                    />
                  </label>
                  {slots[slot] && (
                    <button type="button" className="btn btn-ghost" disabled={busy} onClick={() => setSlots((s) => ({ ...s, [slot]: null }))}>
                      Odobrať
                    </button>
                  )}
                </div>
              ))}
            </div>
            <div style={{ marginTop: 16, display: 'flex', gap: 12, alignItems: 'center' }}>
              <button type="button" className="btn primary" disabled={busy || files.length === 0} onClick={check}>
                {busy ? 'Kontrolujem…' : 'Skontrolovať (nič sa neuloží)'}
              </button>
              {slots.op && !slots.xm && (
                <span className="caption">Bez exportu z XM Trade prejdú iba zmluvy, ktorých OOM už v CRM sú.</span>
              )}
            </div>
          </div>
        </Card>
      )}

      {preview && c && (
        <>
          <div className="card" style={{ padding: '0 24px', marginBottom: 16 }}>
            <div className="toolbar" style={{ padding: 0 }}>
              <div className="tabs" role="tablist" aria-label="Súbory importu" style={{ borderBottom: 0 }}>
                {opFile && (
                  <button type="button" role="tab" className="tab" aria-selected={shownTab === 'office_portal'} onClick={() => setTab('office_portal')}>
                    Office portal – zmluvy a ceny
                  </button>
                )}
                {xmFile && (
                  <button type="button" role="tab" className="tab" aria-selected={shownTab === 'xm_trade'} onClick={() => setTab('xm_trade')}>
                    XM Trade – odberné miesta
                  </button>
                )}
              </div>
              <span className="grow" />
              {steps}
            </div>
          </div>

          {!xmFile && preview.contracts.some((r) => r.errors.some((e) => e.includes('nie je v CRM'))) && (
            <Notice tone="error">
              Niektoré odberné miesta zmlúv ešte nie sú v CRM. Pridajte export z XM Trade (tlačidlo „Zmeniť súbory“) a skontrolujte znova –
              OOM sa založia v tom istom importe.
            </Notice>
          )}
          {missing.length > 0 && (
            <Notice tone="error">
              Chýbajú preklady ({missing.length}):{' '}
              {missing.map((m, i) => (
                <span key={`${m.kind}|${m.name}`}>
                  {i > 0 && ' · '}
                  {KIND[m.kind] ?? m.kind} „{m.name}“{' '}
                  {me.is_admin && (
                    <button type="button" className="btn btn-small" onClick={() => setAdding(m)}>
                      Pridať preklad
                    </button>
                  )}
                </span>
              ))}
              {!me.is_admin && ' – preklad pridá admin (Nastavenia → Preklady importov), potom nahrajte súbory znova.'}
            </Notice>
          )}

          <div className="columns">
            <div className="col-wide">
              {shownTab === 'office_portal' && opFile && (
                <Card flush title={`${opFile.file_name}`} aside={<span className="caption">{num(opFile.rows, 0)} riadkov · {count(c.zmluvy.spolu, ['zmluva', 'zmluvy', 'zmlúv'])}</span>}>
                  <div className="card-body" style={{ paddingTop: 0 }}>
                    <span className="pills">
                      <Pill tone="positive">{count(c.zmluvy.nova, ['nová zmluva', 'nové zmluvy', 'nových zmlúv'])}</Pill>
                      <Pill tone="info">{count(c.zmluvy.zmena, ['zmena', 'zmeny', 'zmien'])}</Pill>
                      {c.zmluvy.upozornenie > 0 && <Pill tone="warning">{count(c.zmluvy.upozornenie, ['upozornenie', 'upozornenia', 'upozornení'])}</Pill>}
                      <Pill tone={c.zmluvy.chyba ? 'negative' : 'neutral'}>{count(c.zmluvy.chyba, ['chyba', 'chyby', 'chýb'])}</Pill>
                      {c.zmluvy.bez_zmeny > 0 && <Pill>{num(c.zmluvy.bez_zmeny, 0)} bez zmeny</Pill>}
                      {c.zmluvy.preskocene > 0 && <Pill>{count(c.zmluvy.preskocene, ['testovacia preskočená', 'testovacie preskočené', 'testovacích preskočených'])}</Pill>}
                    </span>
                  </div>
                  <div className="toolbar chips-bar">
                    <div className="chips" role="group" aria-label="Filter zmlúv">
                      {(['vsetky', 'nova', 'zmena', 'upozornenie', 'chyba', 'bez_zmeny', 'preskocene'] as Filter[]).map((f) => (
                        <button key={f} type="button" className="chip" aria-pressed={filter === f} onClick={() => setFilter(f)}>
                          {f === 'vsetky' ? 'Všetky' : f === 'upozornenie' ? 'Upozornenie' : ACTION[f].label}{' '}
                          <span className="cc">{f === 'vsetky' ? c.zmluvy.spolu : c.zmluvy[f]}</span>
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="table-wrap">
                    <table className="tbl">
                      <thead>
                        <tr>
                          <th>Zmluva</th>
                          <th>Zákazník</th>
                          <th>Akcia</th>
                          <th>Detail</th>
                          <th className="num">Riadky</th>
                        </tr>
                      </thead>
                      <tbody>
                        {rows.length === 0 && (
                          <tr>
                            <td colSpan={5} className="muted">
                              Žiadna zmluva nezodpovedá filtru.
                            </td>
                          </tr>
                        )}
                        {rows.map((r, i) => (
                          <tr key={`${r.number}-${i}`}>
                            <td className="mono">{r.contract_id && r.action !== 'nova' ? <Link to={`/zmluvy/${r.contract_id}`}>{r.number}</Link> : (r.number ?? '–')}</td>
                            <td>
                              {r.customer ?? '–'}
                              {r.customer_new && <div className="sub">nový zákazník (založený importom)</div>}
                            </td>
                            <td>
                              <span className="pills">
                                <Pill tone={ACTION[r.action].tone}>{ACTION[r.action].label}</Pill>
                                {r.warnings.length > 0 && r.action !== 'chyba' && <Pill tone="warning">upozornenie</Pill>}
                              </span>
                            </td>
                            <td className="wrap">
                              {r.errors.map((e) => (
                                <div key={e} className="text-negative">
                                  {e}
                                </div>
                              ))}
                              {r.changes.length > 0 && <div>{r.changes.join(' · ')}</div>}
                              {r.warnings.map((w) => (
                                <div key={w} className="sub">
                                  ⚠ {w}
                                </div>
                              ))}
                              {r.action === 'bez_zmeny' && r.changes.length === 0 && <span className="sub">údaje sú rovnaké</span>}
                              {r.source === 'xm_trade' && <div className="sub">zmena z XM Trade</div>}
                            </td>
                            <td className="num">{r.rows.join(', ') || '–'}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                  <div className="caption" style={{ padding: '10px 24px 16px' }}>
                    Párovanie: zmluva podľa ID a čísla, OOM podľa EIC, zákazník podľa IČO alebo Osoba_ID. Cenový model podľa prekladu názvu produktu
                    (INDIVIDUAL = FIX, ISOTSK_PLUS = SPOT + aditív, GREENVYR = výkup).
                  </div>
                </Card>
              )}

              {shownTab === 'xm_trade' && xmFile && (
                <Card flush title={xmFile.file_name} aside={<span className="caption">{num(xmFile.rows, 0)} riadkov</span>}>
                  <div className="card-body" style={{ paddingTop: 0 }}>
                    <span className="pills">
                      <Pill tone="positive">{count(c.oom.nove, ['nové OOM', 'nové OOM', 'nových OOM'])}</Pill>
                      <Pill tone="info">{count(c.oom.zmena, ['zmena', 'zmeny', 'zmien'])}</Pill>
                      {c.oom.bez_zmeny > 0 && <Pill>{num(c.oom.bez_zmeny, 0)} bez zmeny</Pill>}
                      <Pill tone={c.oom.chyba ? 'negative' : 'neutral'}>{count(c.oom.chyba, ['chyba', 'chyby', 'chýb'])}</Pill>
                    </span>
                  </div>
                  <div className="table-wrap">
                    <table className="tbl">
                      <thead>
                        <tr>
                          <th className="num">Riadok</th>
                          <th>EIC</th>
                          <th>Zákazník</th>
                          <th>Akcia</th>
                          <th>Detail</th>
                        </tr>
                      </thead>
                      <tbody>
                        {preview.oom.map((o) => (
                          <tr key={o.row}>
                            <td className="num">{o.row}</td>
                            <td className="mono">{o.oom_id && o.action !== 'nove' ? <Link to={`/oom/${o.oom_id}`}>{o.eic}</Link> : (o.eic ?? '–')}</td>
                            <td>{o.customer ?? '–'}</td>
                            <td>
                              <Pill tone={OOM_ACTION[o.action].tone}>{OOM_ACTION[o.action].label}</Pill>
                            </td>
                            <td className="wrap">
                              {o.error && <div className="text-negative">{o.error}</div>}
                              {o.action === 'nove' && <div>nové odberné miesto (Pripravované)</div>}
                              {o.action === 'bez_zmeny' && <span className="sub">údaje sú rovnaké</span>}
                              {(o.warnings ?? []).map((w) => (
                                <div key={w} className="sub">
                                  ⚠ {w}
                                </div>
                              ))}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                </Card>
              )}
            </div>

            <div className="col-right">
              <Card title="Čo sa stane">
                <Rows
                  rows={[
                    ['Založí sa', `${count(c.zmluvy.nova, ['zmluva', 'zmluvy', 'zmlúv'])} · ${num(c.oom.nove, 0)} OOM`],
                    ['Aktualizuje sa', `${count(c.zmluvy.zmena, ['zmluva', 'zmluvy', 'zmlúv'])} · ${num(c.oom.zmena, 0)} OOM`],
                    ['S upozornením', count(c.zmluvy.upozornenie, ['zmluva', 'zmluvy', 'zmlúv'])],
                    ['Neuloží sa (chyby)', <span className={errorsCount ? 'text-negative' : undefined}>{`${count(c.zmluvy.chyba, ['zmluva', 'zmluvy', 'zmlúv'])} · ${num(c.oom.chyba, 0)} OOM`}</span>],
                  ]}
                />
                <div className="caption" style={{ margin: '8px 0' }}>
                  Chyba v zmluve = celá zmluva sa neuloží, ostatné áno. Dátum narodenia a ďalšie osobné údaje, ktoré CRM nepotrebuje, sa neimportujú.
                  Súbor sa neuchováva. Kontrola {num(preview.timing_ms.citanie + preview.timing_ms.kontrola, 0)} ms.
                </div>
                <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
                  {errorsCount > 0 && (
                    <button type="button" className="btn" disabled={busy} onClick={downloadErrors}>
                      Stiahnuť riadky s chybami
                    </button>
                  )}
                  <button type="button" className="btn" style={{ justifyContent: 'center' }} disabled={busy} onClick={() => setPreview(null)}>
                    Zmeniť súbory
                  </button>
                  <button type="button" className="btn primary" style={{ justifyContent: 'center' }} disabled={busy || valid === 0} onClick={save}>
                    {busy ? 'Ukladám…' : 'Uložiť platné zmluvy a OOM'}
                  </button>
                </div>
                <div className="caption" style={{ marginTop: 8 }}>
                  Import sa zapíše do auditu. Importovať smú tímy s právom „importovať“ v module Zmluvy (pri XM Trade aj v module Odberné miesta).
                </div>
              </Card>
            </div>
          </div>
        </>
      )}

      {adding && (
        <AliasPanel
          missing={adding}
          onClose={() => setAdding(null)}
          onSaved={() => {
            setAdding(null);
            void runPreview(files);
          }}
        />
      )}
    </>
  );
}

/** „1 zmluva“, „3 zmluvy“, „5 zmlúv“ */
function count(n: number, forms: [string, string, string]) {
  return `${num(n, 0)} ${n === 1 ? forms[0] : n >= 2 && n <= 4 ? forms[1] : forms[2]}`;
}

/** Preklad chýbajúceho názvu (iba admin): vyberie hodnotu CRM a náhľad sa prepočíta. */
function AliasPanel(props: { missing: Missing; onClose: () => void; onSaved: () => void }) {
  const { data } = useApi<{ targets: Record<string, { value: string; label: string }[]> }>('/api/settings/import-aliases');
  const [target, setTarget] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const options = data?.targets[props.missing.kind] ?? [];
  const submit = async () => {
    setBusy(true);
    setError(null);
    try {
      await send('POST', '/api/settings/import-aliases', {
        source: props.missing.source, kind: props.missing.kind, name_sample: props.missing.name, target,
      });
      props.onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Uloženie zlyhalo.');
    } finally {
      setBusy(false);
    }
  };
  return (
    <SidePanel
      title="Pridať preklad"
      onClose={props.onClose}
      footer={
        <>
          <button type="button" className="btn" onClick={props.onClose}>
            Zrušiť
          </button>
          <button type="button" className="btn primary" disabled={busy || !target} onClick={submit}>
            {busy ? 'Ukladám…' : 'Uložiť a prepočítať náhľad'}
          </button>
        </>
      }
    >
      {error && <Notice tone="error">{error}</Notice>}
      <p className="caption">
        {props.missing.source === 'xm_trade' ? 'XM Trade' : 'Office portal'} · {KIND[props.missing.kind] ?? props.missing.kind}: „{props.missing.name}“
      </p>
      <Field label="Hodnota v CRM" hint="Preklad platí pre všetky ďalšie importy; spravuje sa v Nastavenia → Preklady importov.">
        <Select value={target} onChange={setTarget} placeholder="Vyberte…" options={options} />
      </Field>
    </SidePanel>
  );
}
