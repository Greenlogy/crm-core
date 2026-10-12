// Nastavenia – Audit (dizajn 16): kto, čo a kedy zmenil, pôvodná a nová hodnota.
// Audit sa nedá upraviť ani zmazať (databáza). „Systém“ = zmena bez prihláseného používateľa
// (výpočet CRM, migrácia).

import { useState } from 'react';
import { ErrorState, Pill, Skeleton } from '../../components/ui';
import { useApi } from '../../lib/api';
import { date, lastSeen } from '../../lib/format';

const time = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', minute: '2-digit' }).format(new Date(v));
import { type AuditPage as AuditData, type AuditRow, COLUMN_LABEL, TABLE_LABEL } from '../../lib/settings';
import { SettingsHead } from './SettingsLayout';

type Period = '7' | '30' | '365' | '';

const daysAgo = (n: number) => {
  const d = new Date(Date.now() - n * 86_400_000);
  return new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Bratislava' }).format(d);
};

const ISO_TIME = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;

const show = (v: unknown): string => {
  if (v === null || v === undefined || v === '') return '–';
  if (typeof v === 'boolean') return v ? 'áno' : 'nie';
  if (typeof v === 'string' && ISO_TIME.test(v)) return `${date(v)} ${time(v)}`;
  if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)) return date(v);
  if (typeof v === 'object') return JSON.stringify(v);
  return String(v);
};

// Riadky zmeny: insert/delete = celý riadok (vynechajú sa technické stĺpce), update = zmenené stĺpce.
const HIDDEN_COLUMNS = new Set(['id', 'created_at', 'updated_at', 'hubspot_id', 'custom', 'phone_norm', 'mobile_norm']);

function changes(row: AuditRow): { field: string; old: string; new: string }[] {
  if (row.action === 'update') {
    return Object.entries(row.diff)
      .filter(([k]) => !HIDDEN_COLUMNS.has(k))
      .map(([k, v]) => {
      const d = v as { old: unknown; new: unknown };
        return { field: k, old: show(d.old), new: show(d.new) };
      });
  }
  const verb = row.action === 'insert' ? 'vytvorené' : 'zmazané';
  const summary = Object.entries(row.diff)
    .filter(([k, v]) => !HIDDEN_COLUMNS.has(k) && !k.endsWith('_id') && v !== null && v !== '' && v !== false)
    .slice(0, 4)
    .map(([k, v]) => `${COLUMN_LABEL[k] ?? k}: ${show(v)}`)
    .join(', ');
  return [{ field: '–', old: row.action === 'delete' ? summary : '–', new: row.action === 'insert' ? `${verb}${summary ? ` (${summary})` : ''}` : verb }];
}

const fieldLabel = (f: string) =>
  f.startsWith('custom.') ? `Vlastné pole ${f.slice(7)}` : (COLUMN_LABEL[f] ?? f);

export function AuditPage() {
  const [user, setUser] = useState('');
  const [kind, setKind] = useState('');
  const [period, setPeriod] = useState<Period>('7');
  const [q, setQ] = useState('');
  const [page, setPage] = useState(1);
  const params = new URLSearchParams({ user, kind, q, page: String(page), ...(period ? { from: daysAgo(Number(period)) } : {}) });
  const data = useApi<AuditData>(`/api/settings/audit?${params}`);
  const d = data.data;
  const pages = d ? Math.max(1, Math.ceil(d.total / d.pageSize)) : 1;
  const reset = <T,>(set: (v: T) => void) => (v: T) => {
    set(v);
    setPage(1);
  };

  return (
    <>
      <SettingsHead title="Audit" sub="kto, čo a kedy zmenil" />
      <section className="card">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="Hľadať záznam"
            aria-label="Hľadať záznam"
            value={q}
            onChange={(e) => reset(setQ)(e.target.value)}
          />
          <select className="input" aria-label="Kto" value={user} onChange={(e) => reset(setUser)(e.target.value)}>
            <option value="">Kto: všetci</option>
            <option value="system">Systém</option>
            {d?.users.map((u) => (
              <option key={u.id} value={u.id}>
                {u.name}
              </option>
            ))}
          </select>
          <select className="input" aria-label="Typ" value={kind} onChange={(e) => reset(setKind)(e.target.value)}>
            <option value="">Typ: nastavenia aj dáta</option>
            <option value="nastavenia">Iba nastavenia</option>
            <option value="data">Iba dáta</option>
          </select>
          <select className="input" aria-label="Obdobie" value={period} onChange={(e) => reset(setPeriod)(e.target.value as Period)}>
            <option value="7">Obdobie: posledných 7 dní</option>
            <option value="30">Posledných 30 dní</option>
            <option value="365">Posledný rok</option>
            <option value="">Celé obdobie</option>
          </select>
        </div>
        {data.error ? (
          <div className="card-body">
            <ErrorState error={data.error} />
          </div>
        ) : !d ? (
          <div className="card-body">
            <Skeleton lines={6} />
          </div>
        ) : (
          <div className="table-wrap">
            <table className="tbl audit-table">
              <colgroup>
                <col style={{ width: 96 }} />
                <col style={{ width: 130 }} />
                <col style={{ width: '26%' }} />
                <col style={{ width: '14%' }} />
                <col />
                <col />
              </colgroup>
              <thead>
                <tr>
                  <th>Kedy</th>
                  <th>Kto</th>
                  <th>Záznam</th>
                  <th>Pole</th>
                  <th>Pôvodne</th>
                  <th>Nové</th>
                </tr>
              </thead>
              <tbody>
                {d.items.length === 0 && (
                  <tr>
                    <td colSpan={6} className="muted">
                      Žiadna zmena nezodpovedá filtru.
                    </td>
                  </tr>
                )}
                {d.items.flatMap((row) =>
                  changes(row).map((ch, i) => (
                    <tr key={`${row.id}-${i}`} className={i > 0 ? 'audit-cont' : undefined}>
                      <td>{i === 0 ? lastSeen(row.changed_at) : ''}</td>
                      <td>
                        {i === 0 &&
                          (row.user_name ?? (
                            <Pill>{row.source === 'synchronizacia' ? 'Synchronizácia' : 'Systém'}</Pill>
                          ))}
                      </td>
                      <td title={row.record_label ?? undefined}>
                        {i === 0 && (
                          <>
                            {row.record_label ?? '–'}
                            <div className="caption">{TABLE_LABEL[row.table_name] ?? row.table_name}</div>
                          </>
                        )}
                      </td>
                      <td>{fieldLabel(ch.field)}</td>
                      <td title={ch.old}>{ch.old}</td>
                      <td title={ch.new}>{ch.new}</td>
                    </tr>
                  )),
                )}
              </tbody>
            </table>
          </div>
        )}
        <div className="pager">
          <span className="caption">
            {d ? `${d.total} zmien` : ''} · Audit sa nedá upraviť ani zmazať. „Systém“ = zmena vypočítaná CRM alebo migrácia.
          </span>
          <span className="row-actions">
            <button type="button" className="btn" disabled={page <= 1} onClick={() => setPage(page - 1)}>
              Predchádzajúca
            </button>
            <span className="caption">
              {page} / {pages}
            </span>
            <button type="button" className="btn" disabled={page >= pages} onClick={() => setPage(page + 1)}>
              Ďalšia
            </button>
          </span>
        </div>
      </section>
    </>
  );
}
