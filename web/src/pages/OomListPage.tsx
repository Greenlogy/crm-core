// Zoznam odberných miest podľa docs/dizajn/obrazovky/17-oom-zoznam.html (modul Odberné miesta, F1).
// Tlačidlá stavov s počtami, „Prepísané“ (OOM s prepisom) a „Prechod sa zasekol“; filtre typ, PDS, vlastník,
// spoločnosť (iba pri viacerých spoločnostiach); hľadanie podľa EIC (aj s medzerami), názvu, adresy a zákazníka.
// Vzhľad podľa docs/design-handoff/reference/03-odberne-miesta.html: stavy v sklenenej lište, varovné filtre vpravo,
// ikona typu (blesk spotreba, slnko výroba) a štítok typu („Výroba“ zelená) – doplnky schválené 16. 10. 2026.

import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { GlassBar, PageHero } from '../components/hero';
import { Icon, ICONS } from '../components/Layout';
import { Card, ErrorState, Pill, Skeleton, StatusPill, WithUnit } from '../components/ui';
import { useApi, type OomFilters, type OomList, type OomListItem } from '../lib/api';
import { date, mwh, num, text } from '../lib/format';
import { permission, useMe } from '../lib/me';
import { CustomFilters, formatCustom, useFieldDefs } from '../components/custom-fields';
import { label, OOM_STATUS, OOM_TYPE } from '../lib/labels';
import { oomAddress } from './OomPage';
import { planText } from '../components/oom-actions';
import { OomCreatePanel, useCanCreateOom } from '../components/oom-forms';

const CHIPS: [string, string, keyof OomList['counts']][] = [
  ['', 'Všetky', 'all'],
  ['pripravovane', 'Pripravované', 'pripravovane'],
  ['aktivne', 'Aktívne', 'aktivne'],
  ['odidene', 'Odídené', 'odidene'],
  ['zrusene', 'Zrušené', 'zrusene'],
  ['prepisane', 'Prepísané', 'prepisane'],
];
// Varovné filtre vpravo v lište, podfarbené podľa stavu
const WARN_CHIPS: [string, string, keyof OomList['counts'], 'warn' | 'danger'][] = [
  ['zasekol', 'Prechod sa zasekol', 'zasekol', 'warn'],
  ['zlyhal', 'Plán zlyhal', 'zlyhal', 'danger'],
];

const TYPES: [string, string][] = [
  ['', 'Typ: všetky'],
  ['spotreba', 'Spotreba'],
  ['vyroba', 'Výroba'],
  ['sharing', 'Sharing'],
];

/** Ikona typu v riadku: blesk spotreba, slnko výroba, prepojené body sharing; odídené a zrušené sivé. */
function TypeIcon({ o }: { o: OomListItem }) {
  const tone = o.status === 'odidene' || o.status === 'zrusene' ? 'neutral' : o.type === 'vyroba' ? 'positive' : 'info';
  return (
    <span className={`gl-typeicon type-icon ${tone}`} title={OOM_TYPE[o.type] ?? o.type}>
      <Icon d={o.type === 'vyroba' ? ICONS.sun : o.type === 'sharing' ? ICONS.sharing : ICONS.oom} />
    </span>
  );
}

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
  const cfRaw = params.get('cf') ?? '';
  const cf: Record<string, string> = (() => {
    try {
      return cfRaw ? JSON.parse(cfRaw) : {};
    } catch {
      return {};
    }
  })();
  const defs = useFieldDefs('oom');
  const listDefs = defs.filter((d) => d.show_in_list && !d.archived_at);
  const canExport = permission(me, 'odberne_miesta').export;
  const canImport = permission(me, 'odberne_miesta').import;
  const [input, setInput] = useState(q);
  const canCreate = useCanCreateOom();
  const [creating, setCreating] = useState(false);

  const update = (next: Record<string, string>) => {
    const merged = { q, stav: chip, typ: type, pds, vlastnik: owner, spolocnost: org, cf: cfRaw, page: String(page), ...next };
    setParams(Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1'))), { replace: true });
  };

  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, stav: chip, typ: type, pds, owner, org, cf: cfRaw, page: String(page) });
  const { data, error, loading } = useApi<OomList>(`/api/oom?${query}`);
  const { data: filters } = useApi<OomFilters>('/api/oom-filters');
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const open = (o: OomListItem) => navigate(`/oom/${o.id}`);

  return (
    <>
      <PageHero
        title="Odberné miesta"
        sub="spotreba, výroba, sharing"
        actions={
          <>
            {canImport && (
              <button type="button" className="btn" onClick={() => navigate('/oom/import')}>
                <Icon d={ICONS.upload} />
                Import z Excelu
              </button>
            )}
            {canExport && (
              <a className="btn" href={`/api/oom/export?${query}`} title="Stiahnuť zoznam podľa filtra (.xlsx)">
                <Icon d={ICONS.download} />
                Export
              </a>
            )}
            {canCreate && (
              <button type="button" className="btn primary" onClick={() => setCreating(true)}>
                <Icon d={ICONS.plus} />
                Nové odberné miesto
              </button>
            )}
          </>
        }
      />
      <GlassBar
        label="Filter podľa stavu"
        aside={
          <div className="chips" role="group" aria-label="Upozornenia">
            {WARN_CHIPS.map(([value, name, key, tone]) => (
              <button
                key={value}
                // „Plán zlyhal“ pri nule bez farby (Peter 16. 10. 2026)
                className={tone === 'danger' && data?.counts[key] === 0 ? 'chip' : `chip chip-${tone}`}
                type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
                {tone === 'warn' ? <span className="dot" aria-hidden="true" /> : null}
                {name} <span className="cc">{data ? num(data.counts[key], 0) : ''}</span>
              </button>
            ))}
          </div>
        }
      >
        <div className="chips" role="group" aria-label="Stav">
          {CHIPS.map(([value, name, key]) => (
            <button key={value || 'all'} className="chip" type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
              {name} <span className="cc">{data ? num(data.counts[key], 0) : ''}</span>
            </button>
          ))}
        </div>
      </GlassBar>
      {creating && <OomCreatePanel onClose={() => setCreating(false)} />}

      <Card flush label="Zoznam odberných miest">
        <div className="toolbar">
          <div className="gl-search list-search">
            <Icon d={ICONS.search} />
            <input
              className="input"
              type="search"
              placeholder="EIC, názov, adresa alebo zákazník…"
              aria-label="Hľadať odberné miesto"
              value={input}
              onChange={(e) => setInput(e.target.value)}
            />
          </div>
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
          <CustomFilters defs={defs} value={cf} onChange={(v) => update({ cf: Object.keys(v).length ? JSON.stringify(v) : '', page: '1' })} />
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
                    <td colSpan={(multiOrg ? 9 : 8) + listDefs.length} className="muted">
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
                        <TypeIcon o={o} />
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
                    <td>
                      <Pill tone={o.type === 'vyroba' ? 'positive' : 'neutral'}>{label(OOM_TYPE, o.type)}</Pill>
                    </td>
                    <td>
                      <span className="pills">
                        <StatusPill map={OOM_STATUS} value={o.status} />
                        {o.transferred_from_name && <span className="sub">prepis od {o.transferred_from_name}</span>}
                        {o.switch_stuck && <Pill tone="warning">prechod sa zasekol</Pill>}
                        {o.plan_kind && <Pill tone="info">{planText(o.plan_kind, o.plan_date)}</Pill>}
                        {o.plan_failed && <Pill tone="negative">plán zlyhal</Pill>}
                        {o.active_missing && o.active_missing.length > 0 && (
                          <Pill tone="warning">
                            <span title={`Chýba: ${o.active_missing.join(', ')}`}>chýbajú údaje</span>
                          </Pill>
                        )}
                      </span>
                    </td>
                    <td>{text(o.pds_label)}</td>
                    <td className={`num${o.planned_mwh === null ? ' muted' : ''}`}>
                      {o.planned_mwh === null ? '–' : <WithUnit value={mwh(o.planned_mwh)} suffix={o.type === 'vyroba' ? 'výkup' : undefined} />}
                    </td>
                    <td>{supply(o)}</td>
                    <td>{text(o.owner_name)}</td>
                    {multiOrg && <td>{o.org_name}</td>}
                    {listDefs.map((d) => (
                      <td key={d.id}>{formatCustom(d, o.custom?.[d.key])}</td>
                    ))}
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
              <div className="pager-actions">
                <button type="button" className="btn" disabled={page <= 1} onClick={() => update({ page: String(page - 1) })}>
                  ← Predchádzajúca
                </button>
                <button type="button" className="btn" disabled={page >= pages} onClick={() => update({ page: String(page + 1) })}>
                  Ďalšia →
                </button>
              </div>
            )}
          </div>
        )}
      </Card>
    </>
  );
}
