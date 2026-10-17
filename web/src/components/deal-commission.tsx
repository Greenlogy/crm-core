// Provízia na karte obchodu (modul 5, F7; úprava C): vidí ju iba vlastník provízie a kto vidí všetky provízie – ostatným
// (aj Back office a Nákup, hoci obchod vidia) API vráti prázdny zoznam a karta sa neukáže. Admin preradí čakajúcu
// províziu inému obchodníkovi s dôvodom a povolí províziu napriek zhode so Sales portálom.

import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Field, Notice, Select, SidePanel, TextInput, useSave } from './form';
import { Card, Rows, StatusPill } from './ui';
import { send, useApi, type Owner } from '../lib/api';
import { date, eur, num, text } from '../lib/format';
import { COMMISSION_STATE } from '../lib/labels';

type Row = {
  id: string;
  user_id: string;
  user_name: string;
  kind: 'provizia' | 'vyrovnanie';
  status: 'caka' | 'uplatnena' | 'zrusena';
  won_at: string | null;
  base_eur: string;
  base_missing: string | null;
  pct: string;
  target_eur: string;
  amount_eur: string;
  claim_id: string | null;
  claim_number: string | null;
  claimed_at: string | null;
  reassigned_at: string | null;
  reassigned_from_name: string | null;
  reassign_reason: string | null;
};
type Data = { items: Row[]; is_admin: boolean; legacy_blocked: boolean };

export function DealCommission(props: { dealId: string }) {
  const { data, reload } = useApi<Data>(`/api/deals/${props.dealId}/commission`);
  const [panel, setPanel] = useState<'reassign' | 'allow' | null>(null);
  if (!data) return null;
  const rows = data.items.filter((r) => r.status !== 'zrusena');
  if (rows.length === 0 && !data.legacy_blocked) return null;
  const pending = rows.find((r) => r.status === 'caka');
  const claimed = rows.filter((r) => r.status === 'uplatnena').reduce((s, r) => s + Number(r.amount_eur), 0);
  const last = rows[rows.length - 1];
  return (
    <Card
      title="Provízia"
      aside={
        data.is_admin && pending ? (
          <button type="button" className="btn btn-sm" onClick={() => setPanel('reassign')}>
            Preradiť
          </button>
        ) : undefined
      }
    >
      {data.legacy_blocked && rows.length === 0 && (
        <>
          <p className="caption" style={{ marginTop: 0 }}>
            Obchod sa zhoduje s províziou zo Sales portálu (ten istý deal z HubSpotu alebo EIC a obdobie zmluvy) – provízia z CRM nevznikla.
          </p>
          <button type="button" className="btn" onClick={() => setPanel('allow')}>
            Povoliť províziu (iný obchod)
          </button>
        </>
      )}
      {last && (
        <Rows
          rows={[
            ['Obchodník', last.user_name],
            ['Cieľová provízia', `${eur(last.target_eur)} € · ${num(last.pct, 2)} % z ${eur(last.base_eur)} €`],
            ...(claimed !== 0 ? ([['Uplatnené', `${eur(claimed)} €`]] as [string, string][]) : []),
            ...(pending
              ? ([[pending.kind === 'vyrovnanie' ? 'Čaká – vyrovnanie' : 'Čaká na uplatnenie', `${eur(pending.amount_eur)} €`]] as [string, string][])
              : []),
            ['Vyhraté', date(last.won_at)],
          ]}
        />
      )}
      {pending?.base_missing && <Notice tone="error">{pending.base_missing} – províziu nemožno uplatniť, kým sa cena nedoplní.</Notice>}
      {rows.length > 0 && (
        <ul className="plain-list" style={{ marginTop: 8 }}>
          {rows.map((r) => (
            <li key={r.id} className="approval-row" style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
              <span>
                {r.kind === 'vyrovnanie' ? 'Vyrovnanie' : 'Provízia'} {eur(r.amount_eur)} €
                {r.claim_number && (
                  <>
                    {' · '}
                    <a href={`/api/commissions/claims/${r.claim_id}/pdf`} target="_blank" rel="noreferrer" className="gl-mono">
                      {r.claim_number}
                    </a>
                  </>
                )}
                {r.reassigned_at && <span className="caption"> · preradená od {text(r.reassigned_from_name)}</span>}
              </span>
              <StatusPill map={COMMISSION_STATE} value={r.status} />
            </li>
          ))}
        </ul>
      )}
      <div className="caption" style={{ marginTop: 8 }}>
        <Link to="/provizie">Všetky provízie</Link>
      </div>
      {panel === 'reassign' && <ReassignPanel dealId={props.dealId} current={pending!.user_id} onClose={() => setPanel(null)} onDone={() => { setPanel(null); reload(); }} />}
      {panel === 'allow' && <AllowPanel dealId={props.dealId} onClose={() => setPanel(null)} onDone={() => { setPanel(null); reload(); }} />}
    </Card>
  );
}

function ReassignPanel(props: { dealId: string; current: string; onClose: () => void; onDone: () => void }) {
  const { data: owners } = useApi<Owner[]>('/api/deals/owners');
  const [user, setUser] = useState('');
  const [reason, setReason] = useState('');
  const save = useSave();
  const run = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.dealId}/commission/reassign`, { user_id: user, reason });
      props.onDone();
    });
  return (
    <SidePanel title="Preradiť províziu" onClose={props.onClose}
      footer={<button type="button" className="btn primary" disabled={save.busy || !user || reason.trim().length < 3} onClick={run}>Preradiť</button>}>
      <p>Čakajúca provízia (a budúce vyrovnania) prejde na iného obchodníka; percento ostáva z dňa Vyhraté. Uplatnené provízie sa nemenia.</p>
      <Field label="Nový obchodník" wide>
        <Select value={user} onChange={setUser} placeholder="Vybrať…" options={(owners ?? []).filter((o) => o.id !== props.current).map((o) => ({ value: o.id, label: o.name }))} />
      </Field>
      <Field label="Dôvod" wide>
        <TextInput value={reason} onChange={setReason} maxLength={500} />
      </Field>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}

function AllowPanel(props: { dealId: string; onClose: () => void; onDone: () => void }) {
  const [reason, setReason] = useState('');
  const save = useSave();
  const run = () =>
    save.run(async () => {
      await send('POST', `/api/deals/${props.dealId}/commission/allow`, { reason });
      props.onDone();
    });
  return (
    <SidePanel title="Povoliť províziu z CRM" onClose={props.onClose}
      footer={<button type="button" className="btn primary" disabled={save.busy || reason.trim().length < 3} onClick={run}>Povoliť</button>}>
      <p>Povoľte iba vtedy, ak ide o iný obchod ako provízia zo Sales portálu – inak by obchodník dostal províziu dvakrát.</p>
      <Field label="Dôvod" wide>
        <TextInput value={reason} onChange={setReason} maxLength={500} />
      </Field>
      {save.error && <Notice tone="error">{save.error}</Notice>}
    </SidePanel>
  );
}
