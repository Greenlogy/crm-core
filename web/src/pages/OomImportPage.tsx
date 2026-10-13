// Import odberných miest z Excelu podľa docs/dizajn/obrazovky/19-oom-import.html (modul OOM, F4).
// Šablóna → nahratie → náhľad s kontrolou (nič sa neuloží) → uloženie platných riadkov.
// Uloženie prijme iba ten istý súbor (odtlačok) a iba ak sa počty nezmenili od náhľadu; inak nový náhľad.
// Súbor sa nikde neukladá; súbor s chybnými riadkami sa vytvorí až pri stiahnutí.

import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Notice } from '../components/form';
import { BackLink, Card, Empty, Pill } from '../components/ui';
import { ApiError } from '../lib/api';
import { num } from '../lib/format';
import { permission, useMe } from '../lib/me';

type Counts = { riadkov: number; nove: number; zmena: number; bez_zmeny: number; chyba: number };
type PreviewRow = {
  row: number;
  eic: string | null;
  action: 'nove' | 'zmena' | 'bez_zmeny' | 'chyba';
  error?: string;
  customer?: string | null;
  oom_id?: string;
  changes?: { field: string; label: string; old: string | null; new: string | null }[];
};
type Preview = {
  hash: string;
  file_name: string;
  sheet: string;
  ignored_columns: string[];
  counts: Counts;
  timing_ms: { citanie: number; kontrola: number };
  rows: PreviewRow[];
};
type Filter = 'vsetky' | PreviewRow['action'];

const ACTION: Record<PreviewRow['action'], { label: string; tone: 'positive' | 'info' | 'neutral' | 'negative' }> = {
  nove: { label: 'Nové', tone: 'positive' },
  zmena: { label: 'Zmena', tone: 'info' },
  bez_zmeny: { label: 'Bez zmeny', tone: 'neutral' },
  chyba: { label: 'Chyba', tone: 'negative' },
};

const MAX_BYTES = 10 * 1024 * 1024;

/** Súbor ako base64 (API prijíma zápis iba ako JSON z vlastnej stránky). */
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

export function OomImportPage() {
  const me = useMe();
  const canImport = permission(me, 'odberne_miesta').import;
  const [orgId, setOrgId] = useState(me.orgs.find((o) => o.default)?.id ?? me.orgs[0]?.id ?? '');
  const [file, setFile] = useState<{ name: string; data: string } | null>(null);
  const [preview, setPreview] = useState<Preview | null>(null);
  const [filter, setFilter] = useState<Filter>('vsetky');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState<Counts | null>(null);

  if (!canImport) {
    return (
      <>
        <BackLink />
        <Empty>Import odberných miest nemáte povolený (Nastavenia → Tímy a práva → Odberné miesta → Importovať).</Empty>
      </>
    );
  }

  const runPreview = async (f: { name: string; data: string }) => {
    setBusy(true);
    setError(null);
    setSaved(null);
    try {
      setPreview(await post<Preview>('/api/oom-import/preview', { file_name: f.name, data_base64: f.data, org: orgId }));
      setFilter('vsetky');
    } catch (e) {
      setPreview(null);
      setError(e instanceof Error ? e.message : 'Náhľad zlyhal.');
    } finally {
      setBusy(false);
    }
  };

  const choose = async (f: File | undefined) => {
    if (!f) return;
    if (f.size > MAX_BYTES) {
      setError('Súbor je väčší ako 10 MB.');
      return;
    }
    const loaded = { name: f.name, data: await toBase64(f) };
    setFile(loaded);
    await runPreview(loaded);
  };

  const save = async () => {
    if (!file || !preview) return;
    setBusy(true);
    setError(null);
    try {
      const r = await post<{ counts: Counts }>('/api/oom-import/save', {
        file_name: file.name, data_base64: file.data, org: orgId, hash: preview.hash, counts: preview.counts,
      });
      setSaved(r.counts);
      setPreview(null);
      setFile(null);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Uloženie zlyhalo.');
    } finally {
      setBusy(false);
    }
  };

  const downloadErrors = async () => {
    if (!file) return;
    setBusy(true);
    try {
      const res = await fetch('/api/oom-import/errors', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ file_name: file.name, data_base64: file.data, org: orgId }),
      });
      if (!res.ok) throw new Error('Súbor s chybami sa nedá vytvoriť.');
      const url = URL.createObjectURL(await res.blob());
      const a = document.createElement('a');
      a.href = url;
      a.download = 'odberne-miesta-chyby.xlsx';
      a.click();
      URL.revokeObjectURL(url);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Stiahnutie zlyhalo.');
    } finally {
      setBusy(false);
    }
  };

  const step = saved ? 4 : preview ? 3 : file ? 2 : 1;
  const c = preview?.counts;
  const rows = preview ? preview.rows.filter((r) => filter === 'vsetky' || r.action === filter) : [];
  const valid = c ? c.nove + c.zmena : 0;

  return (
    <>
      <BackLink />
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Import odberných miest z Excelu</h1>
          <div className="page-sub">
            <span>zakladanie aj hromadná aktualizácia podľa EIC</span>
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
          <a className="btn" href={`/api/oom-import/template?org=${orgId}`}>
            Stiahnuť šablónu
          </a>
        </div>
      </header>

      <ol className="import-steps" aria-label="Kroky importu">
        {['Šablóna', 'Nahratie', 'Náhľad a kontrola', 'Uloženie'].map((s, i) => (
          <li key={s} className={i + 1 < step ? 'done' : i + 1 === step ? 'current' : undefined}>
            <span className="import-step-no">{i + 1 < step ? '✓' : i + 1}</span> {s}
          </li>
        ))}
      </ol>

      {error && <Notice tone="error">{error}</Notice>}
      {saved && (
        <Notice tone="ok">
          Uložené: {num(saved.nove, 0)} nových a {num(saved.zmena, 0)} zmenených OOM
          {saved.chyba ? `, ${num(saved.chyba, 0)} chybných riadkov sa neuložilo` : ''}. Import je v audite. <Link to="/oom">Späť na zoznam</Link>
        </Notice>
      )}

      {!preview && (
        <Card title="Nahratie súboru">
          <p className="caption">
            Súbor .xlsx podľa šablóny (alebo export zoznamu OOM upravený v Exceli), najviac 5 000 riadkov a 10 MB. Prázdna bunka pri
            existujúcom OOM = bez zmeny. Nové OOM vznikne ako Pripravované; stav, zákazníka a kroky prechodu import nemení.
          </p>
          <label className="btn primary" style={{ display: 'inline-block' }}>
            {busy ? 'Kontrolujem…' : 'Vybrať súbor .xlsx'}
            <input
              type="file"
              accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
              style={{ display: 'none' }}
              disabled={busy}
              onChange={(e) => void choose(e.target.files?.[0])}
            />
          </label>
        </Card>
      )}

      {preview && c && (
        <Card
          flush
          title={`${preview.file_name} · ${num(c.riadkov, 0)} riadkov`}
          aside={
            <span className="pills">
              <Pill tone="positive">{num(c.nove, 0)} nových</Pill>
              <Pill tone="info">{num(c.zmena, 0)} zmien</Pill>
              {c.bez_zmeny > 0 && <Pill>{num(c.bez_zmeny, 0)} bez zmeny</Pill>}
              <Pill tone={c.chyba ? 'negative' : 'neutral'}>{num(c.chyba, 0)} chýb</Pill>
            </span>
          }
        >
          {preview.ignored_columns.length > 0 && (
            <div className="card-body caption">Neznáme stĺpce sa vynechajú: {preview.ignored_columns.join(', ')}.</div>
          )}
          <div className="toolbar chips-bar">
            <div className="chips" role="group" aria-label="Filter riadkov">
              {(['vsetky', 'nove', 'zmena', 'chyba', 'bez_zmeny'] as Filter[]).map((f) => (
                <button key={f} type="button" className="chip" aria-pressed={filter === f} onClick={() => setFilter(f)}>
                  {f === 'vsetky' ? 'Všetky' : ACTION[f].label}{' '}
                  <span className="cc">{f === 'vsetky' ? c.riadkov : c[f]}</span>
                </button>
              ))}
            </div>
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
                {rows.map((r) => (
                  <tr key={r.row}>
                    <td className="num">{r.row}</td>
                    <td className="mono">{r.oom_id && r.action !== 'nove' ? <Link to={`/oom/${r.oom_id}`}>{r.eic}</Link> : (r.eic ?? '–')}</td>
                    <td>{r.customer ?? '–'}</td>
                    <td>
                      <Pill tone={ACTION[r.action].tone}>{ACTION[r.action].label}</Pill>
                    </td>
                    <td className="wrap">
                      {r.action === 'chyba'
                        ? r.error
                        : r.action === 'zmena'
                          ? (r.changes ?? []).map((ch) => `${ch.label} ${ch.old ?? '–'} → ${ch.new ?? '–'}`).join(' · ')
                          : r.action === 'nove'
                            ? 'nové odberné miesto (Pripravované)'
                            : 'údaje sú rovnaké'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="card-foot import-foot">
            <span className="caption">
              Hárok „{preview.sheet}“ · párovanie podľa EIC · pri zmene stará → nová hodnota · kontrola {num(preview.timing_ms.citanie + preview.timing_ms.kontrola, 0)} ms
            </span>
            <span className="grow" />
            {c.chyba > 0 && (
              <button type="button" className="btn" disabled={busy} onClick={downloadErrors}>
                Stiahnuť riadky s chybami
              </button>
            )}
            <label className="btn">
              Nahrať opravený súbor
              <input type="file" accept=".xlsx" style={{ display: 'none' }} disabled={busy} onChange={(e) => void choose(e.target.files?.[0])} />
            </label>
            <button type="button" className="btn primary" disabled={busy || valid === 0} onClick={save}>
              {busy ? 'Ukladám…' : `Uložiť ${num(valid, 0)} platných riadkov`}
            </button>
          </div>
        </Card>
      )}
      <p className="caption" style={{ marginTop: 12 }}>
        Import sa zapíše do auditu: kto, kedy, súbor a počty. Importovať smú tímy s právom „importovať“ (Servis, Nákup, CEO).
      </p>
    </>
  );
}
