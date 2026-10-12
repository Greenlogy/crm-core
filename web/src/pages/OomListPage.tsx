// Zoznam odberných miest podľa docs/dizajn/obrazovky/17-oom-zoznam.html (modul Odberné miesta, F1).
// Tlačidlá stavov s počtami, „Prepísané“ (OOM s prepisom) a „Prechod sa zasekol“; filtre typ, PDS, vlastník,
// spoločnosť (iba pri viacerých spoločnostiach); hľadanie podľa EIC (aj s medzerami), názvu, adresy a zákazníka.

import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Card, ErrorState, Pill, Skeleton, Source, StatusPill } from '../components/ui';
import { useApi, type OomFilters, type OomList, type OomListItem } from '../lib/api';
import { date, mwh, num, text } from '../lib/format';
import { useMe } from '../lib/me';
import { label, OOM_STATUS, OOM_TYPE } from '../lib/labels';
import { oomAddress } from './OomPage';

const CHIPS: [string, string, keyof OomList['counts']][] = [
  ['', 'Všetky', 'all'],
  ['pripravovane', 'Pripravované', 'pripravovane'],
  ['aktivne', 'Aktívne', 'aktivne'],
  ['odidene', 'Odídené', 'odidene'],
  ['zrusene', 'Zrušené', 'zrusene'],
  ['prepisane', 'Prepísané', 'prepisane'],
  ['zasekol', 'Prechod sa zasekol', 'zasekol'],
];

const TYPES: [string, string][] = [
  ['', 'Typ: všetky'],
  ['spotreba', 'Spotreba'],
  ['vyroba', 'Výroba'],
  ['sharing', 'Sharing'],
];

const supply = (o: OomListItem) =>
  !o.supply_from ? '–' : o.supply_to ? `${date(o.supply_from)} – ${date(o.supply_to)}` : o.status === 'pripravovane' ? `od ${date(o.supply_from)}` : `${date(o.supply_from)} – neurčito`;

export function OomListPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const me = useMe();
  const multiOrg = me.orgs.length > 1;
  const q = params.get('q') ?? '';
  const chip = params.get('stav') ?? '';
  const type = params.get('typ') ?? '';
  const pds = params.get('pds') ?? '';
  const owner = params.get('vlastnik') ?? '';
  const org = params.get('spolocnost') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const [input, setInput] = useState(q);

  const update = (next: Record<string, string>) => {
    const merged = { q, stav: chip, typ: type, pds, vlastnik: owner, spolocnost: org, page: String(page), ...next };
    setParams(Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1'))), { replace: true });
  };

  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, stav: chip, typ: type, pds, owner, org, page: String(page) });
  const { data, error, loading } = useApi<OomList>(`/api/oom?${query}`);
  const { data: filters } = useApi<OomFilters>('/api/oom-filters');
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const open = (o: OomListItem) => navigate(`/oom/${o.id}`);

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Odberné miesta</h1>
          <div className="page-sub">
            <span>spotreba, výroba, sharing</span>
            <Source />
          </div>
        </div>
      </header>

      <Card flush label="Zoznam odberných miest">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="EIC, názov, adresa alebo zákazník…"
            aria-label="Hľadať odberné miesto"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <select className="input select" aria-label="Typ" value={type} onChange={(e) => update({ typ: e.target.value, page: '1' })}>
            {TYPES.map(([v, n]) => (
              <option key={v} value={v}>
                {n}
              </option>
            ))}
          </select>
          <select className="input select" aria-label="PDS" value={pds} onChange={(e) => update({ pds: e.target.value, page: '1' })}>
            <option value="">PDS: všetky</option>
            {filters?.pds.map((p) => (
              <option key={p.code} value={p.code}>
                {p.label}
              </option>
            ))}
          </select>
          <select className="input select" aria-label="Vlastník" value={owner} onChange={(e) => update({ vlastnik: e.target.value, page: '1' })}>
            <option value="">Vlastník: všetci</option>
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
          <div className="chips" role="group" aria-label="Filter podľa stavu">
            {CHIPS.map(([value, name, key]) => (
              <button key={value || 'all'} className="chip" type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
                {name} <span className="cc">{data ? num(data.counts[key], 0) : ''}</span>
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
                  <th scope="col">Odberné miesto</th>
                  <th scope="col">Zákazník</th>
                  <th scope="col">Typ</th>
                  <th scope="col">Stav</th>
                  <th scope="col">PDS</th>
                  <th scope="col" className="num">
                    Plánovaný objem
                  </th>
                  <th scope="col">Dodávka</th>
                  <th scope="col">Vlastník</th>
                  {multiOrg && <th scope="col">Spoločnosť</th>}
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={multiOrg ? 9 : 8} className="muted">
                      Žiadne odberné miesto nezodpovedá filtru.
                    </td>
                  </tr>
                )}
                {data.items.map((o) => (
                  <tr key={o.id} className="clickable" onClick={() => open(o)}>
                    <td>
                      <a
                        className="name-cell"
                        href={`/oom/${o.id}`}
                        onClick={(e) => {
                          e.preventDefault();
                          open(o);
                        }}
                      >
                        <span style={{ minWidth: 0 }}>
                          <span className="name-link" title={o.name || oomAddress(o)}>
                            {o.name || oomAddress(o) || o.eic}
                          </span>
                          <div className="sub mono">{o.eic}</div>
                        </span>
                      </a>
                    </td>
                    <td>
                      {text(o.customer_name)}
                      <div className="sub">{o.customer_type === 'B2B' ? 'firma' : 'domácnosť'}</div>
                    </td>
                    <td>{label(OOM_TYPE, o.type)}</td>
                    <td>
                      <span className="pills">
                        <StatusPill map={OOM_STATUS} value={o.status} />
                        {o.transferred_from_name && <span className="sub">prepis od {o.transferred_from_name}</span>}
                        {o.switch_stuck && <Pill tone="warning">prechod sa zasekol</Pill>}
                        {o.active_missing && o.active_missing.length > 0 && (
                          <Pill tone="warning">
                            <span title={`Chýba: ${o.active_missing.join(', ')}`}>chýbajú údaje</span>
                          </Pill>
                        )}
                      </span>
                    </td>
                    <td>{text(o.pds_label)}</td>
                    <td className={`num${o.planned_mwh === null ? ' muted' : ''}`}>
                      {o.planned_mwh === null ? '–' : `${mwh(o.planned_mwh)}${o.type === 'vyroba' ? ' výkup' : ''}`}
                    </td>
                    <td>{supply(o)}</td>
                    <td>{text(o.owner_name)}</td>
                    {multiOrg && <td>{o.org_name}</td>}
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
              {' · jedno EIC = jeden záznam · stav sa viaže na obdobie väzby so zákazníkom'}
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
