// Kontakty podľa docs/dizajn/obrazovky/09-kontakty.html (modul Zákazníci, čl. 9, 13):
// všetky osoby okrem archívu – zákazníci za domácnosť aj kontakty vo firmách; jedna osoba = jeden záznam.
// Formulár Nová osoba s kontrolou duplicity príde so zápisovým API.

import { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { PersonFormPanel, useCanCreateCustomers } from '../components/customer-forms';
import { CustomFilters, formatCustom, useFieldDefs } from '../components/custom-fields';
import { permission, useMe } from '../lib/me';
import { Avatar, Card, ErrorState, Pill, Skeleton, Source } from '../components/ui';
import { useApi, type ContactList } from '../lib/api';
import { date, num } from '../lib/format';
import { COMPANY_ROLE, CUSTOMER_STATUS, rolesText } from '../lib/labels';

export function ContactsPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const q = params.get('q') ?? '';
  const role = params.get('rola') ?? '';
  const cfRaw = params.get('cf') ?? '';
  const cf: Record<string, string> = (() => {
    try {
      return cfRaw ? JSON.parse(cfRaw) : {};
    } catch {
      return {};
    }
  })();
  const defs = useFieldDefs('osoba');
  const canExport = permission(useMe(), 'zakaznici').export;
  const listDefs = defs.filter((d) => d.show_in_list && !d.archived_at);
  const roleOptions = useApi<{ roles: { code: string; label: string; hidden_at: string | null }[] }>('/api/customers/options').data?.roles ?? [];
  const page = Math.max(1, Number(params.get('page') ?? '1') || 1);
  const [input, setInput] = useState(q);
  const canCreate = useCanCreateCustomers();
  const [creating, setCreating] = useState(false);

  const update = (next: Record<string, string>) => {
    const merged = { q, rola: role, cf: cfRaw, page: String(page), ...next };
    const clean = Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1')));
    setParams(clean, { replace: true });
  };

  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, role, cf: cfRaw, page: String(page) });
  const { data, error, loading } = useApi<ContactList>(`/api/contacts?${query}`);
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Kontakty</h1>
          <div className="page-sub">
            <span>všetky osoby · zákazníci za domácnosť aj kontakty vo firmách</span>
            <Source />
          </div>
        </div>
        <div className="head-actions">
          {canExport && (
            <a className="btn" href={`/api/contacts/export?${query}`} title="Stiahnuť zoznam podľa filtra (.xlsx)">
              Export
            </a>
          )}
          {canCreate && (
            <button className="btn primary" type="button" onClick={() => setCreating(true)}>
              Nová osoba
            </button>
          )}
        </div>
      </header>

      <Card flush label="Zoznam osôb">
        <div className="toolbar">
          <input
            className="input grow"
            type="search"
            placeholder="Meno, e-mail alebo telefón…"
            aria-label="Hľadať osobu"
            value={input}
            onChange={(e) => setInput(e.target.value)}
          />
          <select className="input select" aria-label="Rola" value={role} onChange={(e) => update({ rola: e.target.value, page: '1' })}>
            <option value="">Rola: všetky</option>
            {roleOptions.map((r) => (
              <option key={r.code} value={r.code}>
                {r.label.toLowerCase()}
              </option>
            ))}
          </select>
          <CustomFilters defs={defs} value={cf} onChange={(v) => update({ cf: Object.keys(v).length ? JSON.stringify(v) : '', page: '1' })} />
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
                  <th scope="col">Meno</th>
                  <th scope="col">Kontakt</th>
                  <th scope="col">Firmy a role</th>
                  <th scope="col">Ako zákazník</th>
                  <th scope="col">Marketing</th>
                  {listDefs.map((d) => (
                    <th key={d.id} scope="col">
                      {d.label}
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={5 + listDefs.length} className="muted">
                      Žiadna osoba nezodpovedá hľadaniu.
                    </td>
                  </tr>
                )}
                {data.items.map((p) => {
                  const phone = p.mobile ?? p.phone;
                  const status = p.status ? CUSTOMER_STATUS[p.status] : undefined;
                  return (
                    <tr key={p.id} className="clickable" onClick={() => navigate(`/osoby/${p.id}`)}>
                      <td>
                        <Link className="name-cell" to={`/osoby/${p.id}`} onClick={(e) => e.stopPropagation()}>
                          <Avatar name={p.name} small />
                          <span className="name-link" title={p.name}>
                            {[p.title, p.name].filter(Boolean).join(' ')}
                          </span>
                        </Link>
                      </td>
                      <td>
                        <div>{p.email ?? <span className="muted">e-mail nevyplnený</span>}</div>
                        <div className="sub">{phone ?? 'telefón nevyplnený'}</div>
                      </td>
                      <td>
                        {p.companies.length === 0 ? (
                          <span className="muted">–</span>
                        ) : (
                          p.companies.map((f, i) => (
                            <div key={f.id} className={i ? 'sub' : undefined}>
                              <Link to={`/firmy/${f.id}`} onClick={(e) => e.stopPropagation()}>
                                {f.name}
                              </Link>
                              {f.role_labels.length > 0 && ` · ${f.role_labels.join(', ').toLowerCase()}`}{' '}
                              {f.is_main_contact && <Pill>Hlavný</Pill>}
                            </div>
                          ))
                        )}
                      </td>
                      <td>
                        {p.is_household && status ? (
                          <Pill tone={status.tone}>
                            {p.segment_label} · {status.label}
                          </Pill>
                        ) : (
                          <span className="muted">–</span>
                        )}
                      </td>
                      <td>
                        {p.marketing_opt_out_at ? (
                          <>
                            <Pill tone="negative">Nechce marketing</Pill> <span className="sub">od {date(p.marketing_opt_out_at)}</span>
                          </>
                        ) : (
                          <span className="muted">áno</span>
                        )}
                      </td>
                      {listDefs.map((d) => (
                        <td key={d.id}>{formatCustom(d, p.custom[d.key])}</td>
                      ))}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}

        {data && (
          <div className="pager">
            <span className="caption">
              {data.total === 0
                ? '0'
                : `${num((page - 1) * data.pageSize + 1, 0)}–${num(Math.min(page * data.pageSize, data.total), 0)} z ${num(data.total, 0)}`}{' '}
              · jedna osoba = jeden záznam, aj keď pôsobí vo viacerých firmách
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
      {creating && <PersonFormPanel household={false} onClose={() => setCreating(false)} />}
    </>
  );
}
