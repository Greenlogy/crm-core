// Karta osoby podľa docs/dizajn/obrazovky/10-karta-osoby.html (modul Zákazníci):
// domácnosť aj kontakt vo firme. Vľavo údaje, firmy a vývoj stavu, v strede časová os, vpravo OOM, dealy, zmluvy.

import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { MarketingPanel, OPT_OUT_SOURCE_LABEL, TimelineCard } from '../components/customer-f2';
import { PersonFormPanel } from '../components/customer-forms';
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
  StatusPill,
} from '../components/ui';
import { useApi, type PersonCard } from '../lib/api';
import { date, kw, mwh, num, text } from '../lib/format';
import { CUSTOMER_STATUS, rolesText } from '../lib/labels';

export function PersonPage() {
  const { id = '' } = useParams();
  const { data: p, error, reload } = useApi<PersonCard>(`/api/persons/${id}`);
  const [editing, setEditing] = useState(false);
  const [marketing, setMarketing] = useState(false);

  if (error) return <ErrorState error={error} />;
  if (!p || p.id !== id) return <PageSkeleton />;

  const k = p.kpi;
  const owner = p.owner_name ? [p.owner_name, p.owner_team].filter(Boolean).join(' · ') : text(null);
  const contract = p.contracts.find((z) => z.status === 'aktivna') ?? p.contracts[0];
  const fullName = [p.title, p.name].filter(Boolean).join(' ');

  return (
    <>
      <header className="page-head">
        <div className="page-head-main">
          <Avatar name={p.name} />
          <div style={{ minWidth: 0 }}>
            <div className="crumbs">
              <Link to={p.is_household ? '/zakaznici' : '/kontakty'}>{p.is_household ? 'Zákazníci' : 'Kontakty'}</Link> / {p.name}
            </div>
            <div className="title-line">
              <h1 className="t-page-title" title={fullName}>
                {fullName}
              </h1>
              {p.is_household ? (
                <>
                  <CustomerStatus status={p.status} former={p.is_former_customer} archived={p.archived} />
                  <Pill>{p.segment_label}</Pill>
                </>
              ) : (
                <>
                  <Pill>Kontakt vo firme</Pill>
                  {p.archived && <Pill tone="negative">Archív</Pill>}
                </>
              )}
            </div>
            <div className="page-sub">
              {p.city && <span>{p.city}</span>}
              {p.owner_name && <span>{p.owner_name}</span>}
              <HubSpotLink object="contact" id={p.hubspot_id} />
            </div>
          </div>
        </div>
        {p.can_edit && (
          <div className="head-actions">
            <button type="button" className="btn" onClick={() => setEditing(true)}>
              Upraviť
            </button>
          </div>
        )}
      </header>
      {editing && <PersonFormPanel person={p} onClose={() => setEditing(false)} onSaved={reload} />}
      {marketing && (
        <MarketingPanel
          person={p}
          onClose={() => setMarketing(false)}
          onSaved={() => {
            setMarketing(false);
            reload();
          }}
        />
      )}

      {p.is_household && (
        <section className="kpis" aria-label="Kľúčové čísla">
          <Kpi label="Ročná spotreba" value={mwh(k.planned_consumption_mwh)} sub={`${num(k.consumption_active, 0)} OOM spotreba aktívne`} />
          <Kpi
            label="Výroba"
            value={k.production_count ? kw(k.source_power_kw) : ''}
            sub={k.production_count ? `výkup ${mwh(k.planned_feed_in_mwh)} ročne` : 'bez OOM výroba'}
          />
          <Kpi
            label="Zmluva"
            value={contract ? (contract.pipeline ?? contract.number ?? 'zmluva') : ''}
            sub={contract ? (contract.valid_to ? `do ${date(contract.valid_to)}` : 'na neurčito') : 'bez zmluvy'}
          />
          <Kpi label="Aktívne zmluvy" value={num(k.active_contracts, 0)} sub={`zmlúv spolu ${num(p.contracts.length, 0)}`} />
        </section>
      )}

      <div className="columns">
        <div className="col-left">
          <Card title="Údaje">
            <Rows
              stacked
              rows={[
                ['E-mail', p.email ? <a href={`mailto:${p.email}`}>{p.email}</a> : text(null)],
                ['Telefón', text(p.phone)],
                ['Mobil', text(p.mobile)],
                ['Adresa', text(p.address)],
                ['Pozícia', text(p.position)],
                ['Vlastník', owner],
                ['Zdroj', text(p.source)],
                [
                  'Marketing',
                  <>
                    {p.marketing_opt_out_at ? (
                      <>
                        <Pill tone="negative">Nechce marketing</Pill>{' '}
                        <span className="caption">
                          od {date(p.marketing_opt_out_at)} ·{' '}
                          {OPT_OUT_SOURCE_LABEL[p.marketing_opt_out_source ?? ''] ?? p.marketing_opt_out_source}
                        </span>
                      </>
                    ) : p.marketing_allowed ? (
                      <Pill tone="positive">Áno</Pill>
                    ) : (
                      <Pill>Nie – archív</Pill>
                    )}{' '}
                    {p.can_edit && (
                      <button type="button" className="link-button name-link" onClick={() => setMarketing(true)}>
                        Zmeniť
                      </button>
                    )}
                  </>,
                ],
              ]}
            />
          </Card>

          <Card title={`Pôsobí vo firmách (${p.companies.length})`}>
            {p.companies.length === 0 ? (
              <Empty>Osoba nepôsobí v žiadnej firme.</Empty>
            ) : (
              p.companies.map((f) => (
                <Item
                  key={f.id}
                  title={<Link to={`/firmy/${f.id}`}>{f.name}</Link>}
                  meta={[f.role_labels.join(', ').toLowerCase() || null, f.is_main_contact ? 'hlavný kontakt' : null, f.is_customer ? f.segment_label : null]
                    .filter(Boolean)
                    .join(' · ') || undefined}
                  side={
                    <>
                      {f.is_customer && <StatusPill map={CUSTOMER_STATUS} value={f.status} />}
                      {f.archived && <Pill tone="negative">Archív</Pill>}
                    </>
                  }
                />
              ))
            )}
          </Card>

          <CustomFieldsCard
            entity="osoba"
            recordId={p.id}
            orgId={p.org_id}
            custom={p.custom}
            refs={p.custom_refs}
            canEditRecord={p.can_edit}
            onSaved={reload}
          />

          {p.is_household && <StatusHistoryCard history={p.history} />}
        </div>

        <div className="col-mid">
          <TimelineCard kind="person" id={p.id} items={p.timeline} canAdd={p.can_edit} onAdded={reload} />
        </div>

        <div className="col-right">
          {p.is_household || p.ooms.length > 0 ? <OomsCard ooms={p.ooms} /> : null}
          {p.is_household || p.deals.length > 0 ? <DealsCard deals={p.deals} /> : null}
          {p.is_household || p.contracts.length > 0 ? <ContractsCard contracts={p.contracts} /> : null}
          {!p.is_household && p.ooms.length === 0 && p.deals.length === 0 && (
            <Card title="Zákazník">
              <Empty>Kontakt vo firme nie je sám zákazníkom. Ak podpíše zmluvu za domácnosť, stane sa domácnosťou automaticky.</Empty>
            </Card>
          )}
        </div>
      </div>
    </>
  );
}
