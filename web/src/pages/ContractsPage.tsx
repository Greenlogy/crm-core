// Zoznam zmlúv podľa docs/dizajn/obrazovky/25-zmluvy-zoznam.html (modul Zmluvy, F2).
// Tlačidlá stavov (vypočítané z fázy v Office portáli a dátumov) a príznakov s počtami; filtre typ, obchodník,
// spoločnosť, rok bilancie (predvolene bežný); hľadanie podľa čísla zmluvy, zákazníka a EIC. Pridaná hodnota a marža firmy
// (iba s právom) za zvolený rok (0027); export podľa filtra.
// Vzhľad podľa docs/design-handoff/reference/05-zmluvy.html: stavy a príznaky v sklenenej lište (príznaky v podfarbení
// podľa závažnosti), číslo zmluvy v mono písme, stĺpec Marža firmy zvýraznený.

import { useEffect, useState } from 'react';
import { Link, useNavigate, useSearchParams } from 'react-router-dom';
import { GlassBar, PageHero } from '../components/hero';
import { Icon, ICONS } from '../components/Layout';
import { Card, ErrorState, Pill, Skeleton, StatusPill } from '../components/ui';
import { useApi, type ContractList, type ContractListItem } from '../lib/api';
import { eur, mwh, num, period, text } from '../lib/format';
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
// Podfarbenie čipu príznaku podľa tónu štítku
const FLAG_CHIP_CLASS: Record<string, string> = { negative: 'chip chip-danger', warning: 'chip chip-warn', info: 'chip chip-info' };

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
  const thisYear = new Date().getFullYear();
  const year = Number(params.get('rok') ?? '') || thisYear;
  const canImport = permission(me, 'zmluvy').import;
  const canExport = permission(me, 'zmluvy').export;
  const showMargin = me.can_see_margin;
  const [input, setInput] = useState(q);

  const update = (next: Record<string, string>) => {
    const merged = { q, stav: chip, typ: type, obchodnik: owner, spolocnost: org, rok: year === thisYear ? '' : String(year), page: String(page), ...next };
    setParams(Object.fromEntries(Object.entries(merged).filter(([k, v]) => v && !(k === 'page' && v === '1'))), { replace: true });
  };

  useEffect(() => {
    if (input === q) return;
    const t = setTimeout(() => update({ q: input.trim(), page: '1' }), 300);
    return () => clearTimeout(t);
  }, [input]);

  const query = new URLSearchParams({ q, stav: chip, typ: type, obchodnik: owner, org, rok: String(year), page: String(page) });
  const { data, error, loading } = useApi<ContractList>(`/api/contracts?${query}`);
  const { data: filters } = useApi<{ owners: { id: string; name: string }[] }>('/api/contract-filters');
  const pages = data ? Math.max(1, Math.ceil(data.total / data.pageSize)) : 1;
  const open = (k: ContractListItem) => navigate(`/zmluvy/${k.id}`);

  return (
    <>
      <PageHero
        title="Zmluvy"
        sub={
          <>
            dodávka, výkup a VIWA · údaje z Office portálu
          </>
        }
        actions={
          <>
            {canExport && (
              <a className="btn" href={`/api/contracts/export?${query}`} title="Stiahnuť zoznam podľa filtra s bilanciou roka (.xlsx)">
                <Icon d={ICONS.download} />
                Export
              </a>
            )}
            {canImport && (
              <button type="button" className="btn primary" onClick={() => navigate('/zmluvy/import')}>
                <Icon d={ICONS.upload} />
                Import z Office portálu
              </button>
            )}
          </>
        }
      />

      <GlassBar label="Filter podľa stavu a príznaku">
        <div className="chips" role="group" aria-label="Stav">
          {STATE_CHIPS.map(([value, name]) => (
            <button key={value || 'all'} className="chip" type="button" aria-pressed={chip === value} onClick={() => update({ stav: value, page: '1' })}>
              {name} <span className="cc">{data ? num(data.counts[value || 'all'], 0) : ''}</span>
            </button>
          ))}
        </div>
        {FLAG_CHIPS.some((f) => chip === f || (data?.counts[f] ?? 0) > 0) && (
          <div className="chips glassbar-row" role="group" aria-label="Príznaky">
            {FLAG_CHIPS.filter((f) => chip === f || (data?.counts[f] ?? 0) > 0).map((f) => (
              <button key={f} className={FLAG_CHIP_CLASS[CONTRACT_FLAG[f].tone] ?? 'chip'} type="button" aria-pressed={chip === f} onClick={() => update({ stav: f, page: '1' })}>
                {CONTRACT_FLAG[f].label} <span className="cc">{data ? num(data.counts[f], 0) : ''}</span>
              </button>
            ))}
          </div>
        )}
      </GlassBar>

      <Card flush label="Zoznam zmlúv">
        <div className="toolbar">
          <div className="gl-search list-search">
            <Icon d={ICONS.search} />
            <input
              className="input"
              type="search"
              placeholder="Číslo zmluvy, zákazník alebo EIC…"
              aria-label="Hľadať zmluvu"
              value={input}
              onChange={(e) => setInput(e.target.value)}
            />
          </div>
          <select className="input select" aria-label="Typ" value={type} onChange={(e) => update({ typ: e.target.value, page: '1' })}>
            <option value="">Typ: všetky</option>
            {Object.entries(CONTRACT_TYPE).map(([v, n]) => (
              <option key={v} value={v}>
                {n}
              </option>
            ))}
          </select>
          <select className="input select" aria-label="Rok bilancie" value={year} onChange={(e) => update({ rok: e.target.value === String(thisYear) ? '' : e.target.value, page: '1' })}>
            {[thisYear - 1, thisYear, thisYear + 1, thisYear + 2].map((y) => (
              <option key={y} value={y}>
                Rok bilancie: {y}
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

        {error ? (
          <div style={{ padding: '0 24px 20px' }}>
            <ErrorState error={error} />
          </div>
        ) : !data ? (
          <div style={{ padding: '0 24px 20px' }}>
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
                    Objem {year} [MWh]
                  </th>
                  <th scope="col" className="num">
                    Prid. hodnota [€]
                  </th>
                  {showMargin && (
                    <th scope="col" className="num margin-col">
                      Marža firmy [€]
                    </th>
                  )}
                  {multiOrg && <th scope="col">Spoločnosť</th>}
                </tr>
              </thead>
              <tbody>
                {data.items.length === 0 && (
                  <tr>
                    <td colSpan={7 + (multiOrg ? 1 : 0) + (showMargin ? 1 : 0)} className="muted">
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
                          <span className="name-link gl-mono contract-no">{k.number}</span>
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
                          <Pill key={f} tone={CONTRACT_FLAG[f]?.tone ?? 'neutral'} live>
                            {CONTRACT_FLAG[f]?.label ?? f}
                          </Pill>
                        ))}
                        {k.ending && <Pill tone="warning" live>Končí do 4 mesiacov</Pill>}
                        {k.deal_match === 'caka' && <Pill tone="warning">Nespárovaná</Pill>}
                        {k.deal_match === 'bez_obchodu' && <Pill>Bez obchodu</Pill>}
                      </span>
                      {k.deal_id && (
                        <div className="sub">
                          obchod{' '}
                          <Link to={`/obchody/${k.deal_id}`} onClick={(e) => e.stopPropagation()}>
                            {k.deal_name}
                          </Link>
                        </div>
                      )}
                    </td>
                    <td>{contractPeriod(k)}</td>
                    <td className="num">{num(k.oom_count, 0)}</td>
                    <td className="num">{!k.year_volume_mwh || Number(k.year_volume_mwh) === 0 ? '–' : mwh(k.year_volume_mwh).replace(' MWh', '')}</td>
                    <td className={`num${k.added_value_eur !== null && Number(k.added_value_eur) < 0 ? ' text-negative' : ''}`} title={k.balance_missing ? `Chýba: ${k.balance_missing}` : undefined}>
                      {k.added_value_eur === null || k.added_value_eur === undefined ? '–' : eur(k.added_value_eur)}
                    </td>
                    {showMargin && (
                      <td className="num margin-col" title={k.portfolio_stale ? 'starý odhad portfólia (viac ako 30 dní)' : undefined}>
                        {k.margin_eur === null || k.margin_eur === undefined ? '–' : eur(k.margin_eur)}
                        {k.portfolio_stale && <div className="sub">starý odhad</div>}
                      </td>
                    )}
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
              {` · bilancia za rok ${year}: pridaná hodnota = iba komodita (základ provízie)${showMargin ? ', marža firmy = komodita + poplatky' : ''} · výkup a VIWA podľa plánu výkupu OOM`}
            </span>
            {showMargin && (
              <span className="caption margin-note">
                <Icon d={ICONS.lock} />
                Marža firmy: iba CEO, Nákup, Marketing, obch. riaditeľ
              </span>
            )}
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
