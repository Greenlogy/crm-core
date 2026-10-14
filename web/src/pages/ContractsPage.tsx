// Zoznam zmlúv podľa docs/dizajn/obrazovky/25-zmluvy-zoznam.html (modul Zmluvy, F2).
// Tlačidlá stavov (vypočítané z fázy v Office portáli a dátumov) a príznakov s počtami; filtre typ, obchodník,
// spoločnosť; hľadanie podľa čísla zmluvy, zákazníka a EIC. Bilancia (pridaná hodnota, marža) príde v F3 (0027).

import { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { Card, ErrorState, Pill, Skeleton, Source, StatusPill } from '../components/ui';
import { useApi, type ContractList, type ContractListItem } from '../lib/api';
import { mwh, num, period, text } from '../lib/format';
import { permission, useMe } from '../lib/me';
import { CONTRACT_FLAG, CONTRACT_STATUS, CONTRACT_TYPE } from '../lib/labels';

const STATE_CHIPS: [string, string][] = [
  ['', 'Všetky'],
  ['v_priprave', 'V príprave'],
  ['podpisana', 'Podpísané'],
  ['ucinna', 'Účinné'],
  ['skoncena', 'Skončené'],
  ['odmietnuta', 'Odmietnuté'],
  ['neuspesna', 'Neúspešné'],
];
const FLAG_CHIPS = Object.keys(CONTRACT_FLAG);

/** Účinnosť v zozname: pri prolongácii alebo skrátení nástupcom koniec podľa CRM. */
export const contractPeriod = (k: Pick<ContractListItem, 'valid_from' | 'valid_to' | 'effective_to' | 'crm_valid_to'>) =>
  !k.valid_from && !k.effective_to
    ? '–'
    : k.crm_valid_to && k.crm_valid_to !== k.valid_to && (!k.valid_to || k.crm_valid_to > k.valid_to)
      ? `${period(k.valid_from, k.effective_to)} (prolong.)`
      : period(k.valid_from, k.effective_to);

export function ContractsPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const me = useMe();
  const multiOrg = me.orgs.length > 1;
  const q = params.get('q') ?? '';
  const chip = params.get('stav') ?? '';
  const type = params.get('typ') ?? '';
  const owner = params.get('obchodnik') ?? '';
  const org = params.get('spolocnost') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const canImport = permission(me, 'zmluvy').import;
  const [input, setInput] = useState(q);

  const update = (next: Record<string, string>) => {
    const merged = { q, stav: chip, typ: type, obchodnik: owner, spolocnost: org, page: String(page), ...next };
    setParams(Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1'))), { replace: true });
  };

  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, stav: chip, typ: type, obchodnik: owner, org, page: String(page) });
  const { data, error, loading } = useApi<ContractList>(`/api/contracts?${query}`);
  const { data: filters } = useApi<{ owners: { id: string; name: string }[] }>('/api/contract-filters');
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const open = (k: ContractListItem) => navigate(`/zmluvy/${k.id}`);

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Zmluvy</h1>
          <div className="page-sub">
            <span>dodávka, výkup a VIWA · údaje z Office portálu</span>
            <Source />
          </div>
        </div>
        <div className="head-actions">
          {canImport && (
            <button type="button" className="btn primary" onClick={() => navigate('/zmluvy/import')}>
              Import z Office portálu
            </button>
          )}
        </div>
      </header>

      <Card flush label="Zoznam zmlúv">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="Číslo zmluvy, zákazník alebo EIC…"
            aria-label="Hľadať zmluvu"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <select className="input select" aria-label="Typ" value={type} onChange={(e) => update({ typ: e.target.value, page: '1' })}>
            <option value="">Typ: všetky</option>
            {Object.entries(CONTRACT_TYPE).map(([v, n]) => (
              <option key={v} value={v}>
                {n}
              </option>
            ))}
          </select>
          <select className="input select" aria-label="Obchodník" value={owner} onChange={(e) => update({ obchodnik: e.target.value, page: '1' })}>
            <option value="">Obchodník: všetci</option>
            <option value="bez">Bez obchodníka</option>
            {filters?.owners.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
          {multiOrg && (
            <select className="input select" aria-label="Spoločnosť" value={org} onChange={(e) => update({ spolocnost: e.target.value, page: '1' })}>
              <option value="">Spoločnosť: všetky</option>
              {me.orgs.map((o) => (
                <option key={o.id} value={o.id}>
                  {o.name}
                </option>
              ))}
            </select>
          )}
        </div>

        <div className="toolbar chips-bar">
          <div className="chips" role="group" aria-label="Filter podľa stavu a príznaku">
            {STATE_CHIPS.map(([value, name]) => (
              <button key={value || 'all'} className="chip" type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
                {name} <span className="cc">{data ? num(data.counts[value || 'all'], 0) : ''}</span>
              </button>
            ))}
            {FLAG_CHIPS.filter((f) => chip === f || (data?.counts[f] ?? 0) > 0).map((f) => (
              <button key={f} className="chip" type="button" aria-pressed={chip === f} onClick={() => update({ stav: f, page: '1' })}>
                {CONTRACT_FLAG[f].label} <span className="cc">{data ? num(data.counts[f], 0) : ''}</span>
              </button>
            ))}
          </div>
        </div>

        {error ? (
          <div style={{ padding: '0 16px 16px' }}>
            <ErrorState error={error} />
          </div>
        ) : !data ? (
          <div style={{ padding: '0 16px 16px' }}>
            <Skeleton lines={10} />
          </div>
        ) : (
          <div className="table-wrap" style={{ opacity: loading ? 0.6 : 1 }}>
            <table className="tbl">
              <thead>
                <tr>
                  <th scope="col">Zmluva</th>
                  <th scope="col">Zákazník · obchodník</th>
                  <th scope="col">Stav</th>
                  <th scope="col">Účinnosť</th>
                  <th scope="col" className="num">
                    OOM
                  </th>
                  <th scope="col" className="num">
                    Objem [MWh]
                  </th>
                  {multiOrg && <th scope="col">Spoločnosť</th>}
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={multiOrg ? 7 : 6} className="muted">
                      Žiadna zmluva nezodpovedá filtru.
                    </td>
                  </tr>
                )}
                {data.items.map((k) => (
                  <tr key={k.id} className="clickable" onClick={() => open(k)}>
                    <td>
                      <a
                        className="name-cell"
                        href={`/zmluvy/${k.id}`}
                        onClick={(e) => {
                          e.preventDefault();
                          open(k);
                        }}
                      >
                        <span style={{ minWidth: 0 }}>
                          <span className="name-link mono">{k.number}</span>
                          <div className="sub">{CONTRACT_TYPE[k.type] ?? k.type}</div>
                        </span>
                      </a>
                    </td>
                    <td>
                      <Link to={k.company_id ? `/firmy/${k.company_id}` : `/osoby/${k.person_id}`} onClick={(e) => e.stopPropagation()}>
                        {text(k.customer_name)}
                      </Link>
                      <div className="sub">{k.owner_name ?? 'bez obchodníka'}</div>
                    </td>
                    <td>
                      <span className="pills">
                        <StatusPill map={CONTRACT_STATUS} value={k.state} />
                        {k.flags.map((f) => (
                          <Pill key={f} tone={CONTRACT_FLAG[f]?.tone ?? 'neutral'}>
                            {CONTRACT_FLAG[f]?.label ?? f}
                          </Pill>
                        ))}
                      </span>
                    </td>
                    <td>{contractPeriod(k)}</td>
                    <td className="num">{num(k.oom_count, 0)}</td>
                    <td className="num">{k.qty_mwh === null || Number(k.qty_mwh) === 0 ? '–' : mwh(k.qty_mwh).replace(' MWh', '')}</td>
                    {multiOrg && <td>{k.org_name}</td>}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {data && (
          <div className="pager">
            <span className="caption">
              {data.total === 0
                ? '0'
                : `${num((page - 1) * data.pageSize + 1, 0)}–${num(Math.min(page * data.pageSize, data.total), 0)} z ${num(data.total, 0)}`}
              {' · zmluvy prichádzajú importom z Office portálu · objem = zmluvné množstvo za rok (výkup a VIWA podľa plánu OOM v F3)'}
            </span>
            {pages > 1 && (
              <>
                <button type="button" className="btn" disabled={page <= 1} onClick={() => update({ page: String(page - 1) })}>
                  ← Predchádzajúca
                </button>
                <button type="button" className="btn" disabled={page >= pages} onClick={() => update({ page: String(page + 1) })}>
                  Ďalšia →
                </button>
              </>
            )}
          </div>
        )}
      </Card>
    </>
  );
}
