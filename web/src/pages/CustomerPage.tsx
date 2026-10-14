// Karta firmy podľa docs/dizajn/obrazovky/01-karta-firmy.html (variant B, modul Zákazníci):
// KPI v jednom rade; vľavo údaje, FinStat a vývoj stavu, v strede časová os, vpravo kontakty, OOM, dealy, zmluvy.

import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { CompanyContactsCard, TimelineCard } from '../components/customer-f2';
import { RegulationNotice } from '../components/regulation';
import { CompanyFormPanel } from '../components/customer-forms';
import { CustomFieldsCard } from '../components/custom-fields';
import { ContractsCard, CustomerStatus, DealsCard, OomsCard, StatusHistoryCard } from '../components/customer';
import {
  Avatar,
  Card,
  Empty,
  ErrorState,
  HubSpotLink,
  Item,
  Kpi,
  NotInPrototype,
  PageSkeleton,
  Pill,
  Rows,
  Source,
} from '../components/ui';
import { useApi, type CompanyCard } from '../lib/api';
import { useMe } from '../lib/me';
import { kw, mwh, num, text } from '../lib/format';
import { label, PAYMENT_RATING, rolesText, yesNo } from '../lib/labels';

export function CustomerPage() {
  const { id = '' } = useParams();
  const { data: c, error, reload } = useApi<CompanyCard>(`/api/companies/${id}`);
  const me = useMe();
  const [editing, setEditing] = useState(false);

  if (error) return <ErrorState error={error} />;
  if (!c || c.id !== id) return <PageSkeleton />;

  const k = c.kpi;
  const owner = c.owner_name ? [c.owner_name, c.owner_team].filter(Boolean).join(' · ') : text(null);
  const marks = [c.is_customer && 'zákazník', c.is_partner && 'partner', c.is_supplier && 'dodávateľ'].filter(Boolean).join(', ');

  return (
    <>
      <header className="page-head">
        <div className="page-head-main">
          <Avatar name={c.name} />
          <div style={{ minWidth: 0 }}>
            <div className="crumbs">
              <Link to="/zakaznici">Zákazníci</Link> / {c.name}
            </div>
            <div className="title-line">
              <h1 className="t-page-title" title={c.name}>
                {c.name}
              </h1>
              <CustomerStatus status={c.is_customer ? c.status : null} former={c.is_former_customer} archived={c.archived} />
              {c.is_customer && <Pill>{c.segment_label}</Pill>}
              {c.is_partner && <Pill tone="info">Partner</Pill>}
              {c.is_supplier && <Pill tone="info">Dodávateľ</Pill>}
            </div>
            <div className="page-sub">
              {c.ico && <span className="mono">{c.country === 'HR' ? 'OIB' : 'IČO'} {c.ico}</span>}
              {me.orgs.length > 1 && <span>{c.org_name}</span>}
              {c.city && <span>{c.city}</span>}
              {c.owner_name && <span>{c.owner_name}</span>}
              <HubSpotLink object="company" id={c.hubspot_id} />
            </div>
          </div>
        </div>
        {c.can_edit && me.team_code !== 'servis' && (
          <div className="head-actions">
            <button type="button" className="btn" onClick={() => setEditing(true)}>
              Upraviť
            </button>
          </div>
        )}
      </header>
      {editing && <CompanyFormPanel company={c} onClose={() => setEditing(false)} onSaved={reload} />}

      <RegulationNotice check={c.regulation_check} />
      <section className="kpis" aria-label="Ukazovatele">
        <Kpi label="Odberné miesta" value={num(k.oom_count, 0)} sub={`aktívne ${num(k.oom_active, 0)}`} />
        <Kpi label="Aktívne zmluvy" value={num(k.active_contracts, 0)} sub={`zmlúv spolu ${num(c.contracts.length, 0)}`} />
        <Kpi label="Plánovaná spotreba" value={mwh(k.planned_consumption_mwh)} sub="ročne, VT + NT zo všetkých OOM" />
        <Kpi label="Plánovaný výkup" value={mwh(k.planned_feed_in_mwh)} sub="ročne zo všetkých OOM" />
        <Kpi label="Výkon zdrojov" value={kw(k.source_power_kw)} sub="súčet výkonov zdrojov OOM" />
      </section>

      <div className="columns">
        <div className="col-left">
          <Card title="Firemné informácie">
            <Rows
              stacked
              rows={[
                ['Obchodník', owner],
                ['Označenie', text(marks)],
                [c.country === 'HR' ? 'OIB' : 'IČO', <span className="mono">{text(c.ico)}</span>],
                ['DIČ', text(c.dic)],
                ['IČ DPH', text(c.ic_dph)],
                ['Bankový účet', <span className="mono">{text(c.bank_account)}</span>],
                ['Platobný rating', text(label(PAYMENT_RATING, c.payment_rating))],
                ['Zastúpený', text(c.statutory)],
                ['Zapísaný v Obchodnom registri', text(c.registry_entry)],
                ['SK NACE', text(c.nace)],
                ['Adresa', text(c.address)],
              ]}
            />
          </Card>

          <Card title="FinStat" aside={c.finstat_url ? <a href={c.finstat_url} target="_blank" rel="noreferrer">Otvoriť ↗</a> : undefined}>
            <Rows
              stacked
              rows={[
                ['Dlhy a nedoplatky', text(yesNo(c.debts_note))],
                ['Konkurzy a reštrukturalizácie', text(yesNo(c.insolvency_note))],
              ]}
            />
            <NotInPrototype what="platobné hodnotenie a dáta z FinStatu sa nenačítavajú." />
          </Card>

          <CustomFieldsCard
            entity="firma"
            recordId={c.id}
            orgId={c.org_id}
            custom={c.custom}
            refs={c.custom_refs}
            canEditRecord={c.can_edit && me.team_code !== 'servis'}
            onSaved={reload}
          />

          {c.is_customer && <StatusHistoryCard history={c.history} />}
        </div>

        <div className="col-mid">
          <TimelineCard kind="company" id={c.id} items={c.timeline} canAdd={c.can_edit} onAdded={reload} />
        </div>

        <div className="col-right">
          <CompanyContactsCard company={c} onChanged={reload} />

          <OomsCard ooms={c.ooms} customer={{ kind: 'company', id: c.id, name: c.name, org_id: c.org_id }} />
          <DealsCard deals={c.deals} />
          <ContractsCard contracts={c.contracts} />
        </div>
      </div>
    </>
  );
}
