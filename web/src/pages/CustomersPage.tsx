// Zoznam zákazníkov: hľadanie podľa názvu a IČO, filter segmentu, stránkovanie po 50.

import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { Avatar, Card, ErrorState, Skeleton, Source } from '../components/ui';
import { useApi, type CustomerList, type CustomerListItem } from '../lib/api';
import { mwh, num, text } from '../lib/format';
import { label, SEGMENT } from '../lib/labels';

const SEGMENTS: [string, string][] = [
  ['', 'Všetci'],
  ['firma', 'Firmy'],
  ['domacnost', 'Domácnosti'],
  ['dodavatel', 'Dodávatelia'],
];

export const customerPath = (c: Pick<CustomerListItem, 'kind' | 'id'>) =>
  c.kind === 'company' ? `/firmy/${c.id}` : `/domacnosti/${c.id}`;

export function CustomersPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const q = params.get('q') ?? '';
  const segment = params.get('segment') ?? '';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const [input, setInput] = useState(q);

  const update = (next: Record<string, string>) => {
    const merged = { q, segment, page: String(page), ...next };
    const clean = Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1')));
    setParams(clean, { replace: true });
  };

  // Hľadanie s oneskorením, aby sa API nevolalo pri každom písmene.
  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, segment, page: String(page) });
  const { data, error, loading } = useApi<CustomerList>(`/api/customers?${query}`);
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Zákazníci</h1>
          <div className="page-sub">
            <span>Firmy a domácnosti, ktoré vlastnia OOM, deal alebo zmluvu</span>
            <Source />
          </div>
        </div>
      </header>

      <Card flush label="Zoznam zákazníkov">
        <div className="toolbar">
          <input
            className="input"
            type="search"
            placeholder="Hľadať podľa názvu alebo IČO"
            aria-label="Hľadať podľa názvu alebo IČO"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <div className="segmented" role="group" aria-label="Segment">
            {SEGMENTS.map(([value, name]) => (
              <button key={value} type="button" aria-pressed={segment === value} onClick={() => update({ segment: value, page: '1' })}>
                {name}
              </button>
            ))}
          </div>
          {data && <span className="caption">{num(data.total, 0)} zákazníkov</span>}
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
                  <th>Zákazník</th>
                  <th>Typ</th>
                  <th>IČO</th>
                  <th>Segment</th>
                  <th>Obchodník</th>
                  <th className="num">OOM</th>
                  <th className="num">Aktívne OOM</th>
                  <th className="num">Aktívne zmluvy</th>
                  <th className="num">Spotreba MWh/rok</th>
                  <th className="num">Výkup MWh/rok</th>
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={10} className="muted">
                      Žiadny zákazník nezodpovedá hľadaniu.
                    </td>
                  </tr>
                )}
                {data.items.map((c) => (
                  <tr key={c.id} className="clickable" onClick={() => navigate(customerPath(c))}>
                    <td>
                      <a
                        className="name-cell"
                        href={customerPath(c)}
                        onClick={(e) => {
                          e.preventDefault();
                          navigate(customerPath(c));
                        }}
                        style={{ color: 'inherit' }}
                      >
                        <Avatar name={c.name} small />
                        <span title={c.name}>{c.name}</span>
                      </a>
                    </td>
                    <td>{c.kind === 'company' ? 'Firma' : 'Domácnosť'}</td>
                    <td className="mono">{text(c.ico)}</td>
                    <td>{text(label(SEGMENT, c.segment))}</td>
                    <td>{text(c.owner_name)}</td>
                    <td className="num">{num(c.oom_count, 0)}</td>
                    <td className="num">{num(c.oom_active, 0)}</td>
                    <td className="num">{num(c.active_contracts, 0)}</td>
                    <td className="num">{mwh(c.planned_consumption_mwh).replace(' MWh', '')}</td>
                    <td className="num">{mwh(c.planned_feed_in_mwh).replace(' MWh', '')}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        {data && pages > 1 && (
          <div className="pager">
            <button type="button" className="btn" disabled={page <= 1} onClick={() => update({ page: String(page - 1) })}>
              ← Predchádzajúca
            </button>
            <span className="caption">
              Strana {page} z {pages}
            </span>
            <button type="button" className="btn" disabled={page >= pages} onClick={() => update({ page: String(page + 1) })}>
              Ďalšia →
            </button>
          </div>
        )}
      </Card>
    </>
  );
}
