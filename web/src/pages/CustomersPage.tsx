// Zoznam zákazníkov podľa docs/dizajn/obrazovky/08-zoznam-zakaznikov.html (modul Zákazníci, čl. 9):
// firmy a domácnosti, filter stavu s počtami, segment, vlastník; predvolene bez marketingových kontaktov a archívu.
// Položka menu „Leady“ = tento zoznam s filtrom Záujemca + Ponuka.

import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { CustomerStatus } from '../components/customer';
import { CompanyFormPanel, PersonFormPanel, useCanCreateCustomers } from '../components/customer-forms';
import { Avatar, Card, ErrorState, Skeleton, Source } from '../components/ui';
import { useApi, type CustomerList, type CustomerListItem, type Owner } from '../lib/api';
import { date, mwh, num, text } from '../lib/format';
import { CUSTOMER_STATUS } from '../lib/labels';

const STATUS_CHIPS = ['zaujemca', 'ponuka', 'cakajuci_zakaznik', 'zakaznik', 'byvaly_zakaznik'];
const HIDDEN_CHIPS = ['marketingovy_kontakt', 'zruseny_zakaznik'];

const SEGMENTS: [string, string][] = [
  ['', 'Segment: všetky'],
  ['firma', 'Firma'],
  ['domacnost', 'Domácnosť'],
  ['vyrobca', 'Výrobca'],
];

export const customerPath = (c: Pick<CustomerListItem, 'kind' | 'id'>) =>
  c.kind === 'company' ? `/firmy/${c.id}` : `/osoby/${c.id}`;

// IČO po trojiciach ako v dizajne: 36 412 578
const icoText = (ico: string) => ico.replace(/^(\d{2})(\d{3})(\d{3})$/, '$1 $2 $3');

function subLine(c: CustomerListItem) {
  if (c.kind === 'company') return [c.ico && `IČO ${icoText(c.ico)}`, c.city].filter(Boolean).join(' · ');
  const extra = c.is_statutory
    ? 'aj štatutár firmy'
    : c.company_count > 0
      ? `aj kontakt v ${c.company_count} ${c.company_count === 1 ? 'firme' : 'firmách'}`
      : null;
  return ['domácnosť', c.city, extra].filter(Boolean).join(' · ');
}

export function CustomersPage(props: { leads?: boolean }) {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const q = params.get('q') ?? '';
  const chip = props.leads ? 'leady' : (params.get('stav') ?? '');
  const segment = params.get('segment') ?? '';
  const owner = params.get('obchodnik') ?? '';
  const showAll = params.get('vsetko') === '1';
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const [input, setInput] = useState(q);
  const canCreate = useCanCreateCustomers();
  const [creating, setCreating] = useState<'company' | 'person' | null>(null);

  const update = (next: Record<string, string>) => {
    const merged = { q, stav: props.leads ? '' : chip, segment, obchodnik: owner, vsetko: showAll ? '1' : '', page: String(page), ...next };
    const clean = Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1')));
    setParams(clean, { replace: true });
  };

  // Hľadanie s oneskorením, aby sa API nevolalo pri každom písmene.
  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const status = chip === '' ? (showAll ? 'vsetky' : '') : chip;
  const query = new URLSearchParams({ q, status, segment, owner, page: String(page) });
  const { data, error, loading } = useApi<CustomerList>(`/api/customers?${query}`);
  const { data: owners } = useApi<Owner[]>('/api/owners');
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const counts = data?.counts;

  const chipButton = (value: string, name: string, count: number | undefined) => (
    <button key={value || 'all'} className="chip" type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
      {name} <span className="cc">{count === undefined ? '' : num(count, 0)}</span>
    </button>
  );

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">{props.leads ? 'Leady' : 'Zákazníci'}</h1>
          <div className="page-sub">
            <span>
              {props.leads
                ? 'záujemcovia a firmy či domácnosti s odoslanou ponukou'
                : `${counts ? num(counts.visible, 0) : '…'} · firmy a domácnosti`}
            </span>
            <Source />
          </div>
        </div>
        <div className="head-actions">
          <button className="btn" type="button" disabled title="Pripravuje sa (F4)">
            Export
          </button>
          {canCreate && (
            <>
              <button className="btn" type="button" onClick={() => setCreating('person')}>
                Nová domácnosť
              </button>
              <button className="btn primary" type="button" onClick={() => setCreating('company')}>
                Nová firma
              </button>
            </>
          )}
        </div>
      </header>

      <Card flush label="Zoznam zákazníkov">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="Názov, IČO alebo e-mail…"
            aria-label="Hľadať zákazníka"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <select className="input select" aria-label="Segment" value={segment} onChange={(e) => update({ segment: e.target.value, page: '1' })}>
            {SEGMENTS.map(([value, name]) => (
              <option key={value} value={value}>
                {name}
              </option>
            ))}
          </select>
          <select className="input select" aria-label="Vlastník" value={owner} onChange={(e) => update({ obchodnik: e.target.value, page: '1' })}>
            <option value="">Vlastník: všetci</option>
            {owners?.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
        </div>

        {!props.leads && (
          <div className="toolbar chips-bar">
            <div className="chips" role="group" aria-label="Filter podľa stavu">
              {chipButton('', 'Všetci', counts ? (showAll ? counts.all : counts.visible) : undefined)}
              {STATUS_CHIPS.map((s) => chipButton(s, CUSTOMER_STATUS[s].label, counts?.byStatus[s]))}
              {showAll &&
                HIDDEN_CHIPS.map((s) =>
                  chipButton(s, s === 'zruseny_zakaznik' ? 'Archív' : CUSTOMER_STATUS[s].label, s === 'zruseny_zakaznik' ? counts?.archived : counts?.byStatus[s]),
                )}
            </div>
            <label className="check">
              <input
                type="checkbox"
                checked={showAll}
                onChange={(e) =>
                  update({ vsetko: e.target.checked ? '1' : '', stav: !e.target.checked && HIDDEN_CHIPS.includes(chip) ? '' : chip, page: '1' })
                }
              />
              Zobraziť aj marketingové kontakty{counts ? ` (${num(counts.byStatus.marketingovy_kontakt, 0)})` : ''} a archív
              {counts ? ` (${num(counts.archived, 0)})` : ''}
            </label>
          </div>
        )}

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
                  <th scope="col">Názov</th>
                  <th scope="col">Typ</th>
                  <th scope="col">Segment</th>
                  <th scope="col">Stav</th>
                  <th scope="col" className="num">
                    Aktívne OOM
                  </th>
                  <th scope="col" className="num">
                    Ročný objem
                  </th>
                  <th scope="col">Vlastník</th>
                  <th scope="col">Posledná aktivita</th>
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={8} className="muted">
                      Žiadny zákazník nezodpovedá filtru.
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
                      >
                        <Avatar name={c.name} small household={c.kind === 'person'} />
                        <span style={{ minWidth: 0 }}>
                          <span className="name-link" title={c.name}>
                            {c.name}
                          </span>
                          <div className="sub">{subLine(c)}</div>
                        </span>
                      </a>
                    </td>
                    <td className="muted">{c.customer_type}</td>
                    <td>{c.segment_label}</td>
                    <td>
                      <span className="pills">
                        <CustomerStatus status={c.status} former={c.is_former_customer} archived={c.archived} />
                        {c.status === 'cakajuci_zakaznik' && c.future_from && <span className="sub">od {date(c.future_from)}</span>}
                      </span>
                    </td>
                    <td className="num">{num(c.active_oom_count, 0)}</td>
                    <td className={`num${Number(c.annual_mwh) ? '' : ' muted'}`}>{Number(c.annual_mwh) ? mwh(c.annual_mwh) : '–'}</td>
                    <td>{text(c.owner_name)}</td>
                    <td className="muted">{c.last_activity_at ? date(c.last_activity_at) : '–'}</td>
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
      {creating === 'company' && <CompanyFormPanel onClose={() => setCreating(null)} />}
      {creating === 'person' && <PersonFormPanel household onClose={() => setCreating(null)} />}
    </>
  );
}
