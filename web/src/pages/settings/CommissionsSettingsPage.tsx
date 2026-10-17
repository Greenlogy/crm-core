// Nastavenia → Provízie obchodníkov (modul 5, F7; návrh DB časti 37–40): dátum prechodu provízií zo Sales portálu do CRM
// (prázdny = vypnuté), príjemcovia kópie provízneho listu, obchodníci – percento s históriou, „počítať provízie“ (admin
// a schvaľovateľ cien) a „vidí všetky provízie“ (iba admin). Každá zmena ide do auditu.

import { useEffect, useState } from 'react';
import { Check, Field, Notice, SidePanel, useSave } from '../../components/form';
import { Card, ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { num } from '../../lib/format';
import { SettingsHead } from './SettingsLayout';
import { CommissionSection } from './UsersPage';

type User = {
  id: string;
  name: string;
  email: string;
  team_name: string;
  seller_type: string | null;
  status: string;
  commission_enabled: boolean;
  sees_all_commissions: boolean;
  pct: string;
};
type Data = { crm_from: string | null; cc: string[]; users: User[]; can_edit: boolean; approves: boolean };

export function CommissionsSettingsPage() {
  const { data, error, reload } = useApi<Data>('/api/settings/commissions');
  const [from, setFrom] = useState('');
  const [cc, setCc] = useState<string[]>([]);
  const [rateFor, setRateFor] = useState<User | null>(null);
  const [saved, setSaved] = useState(false);
  const save = useSave();
  useEffect(() => {
    if (data) {
      setFrom(data.crm_from ?? '');
      setCc(data.cc);
    }
  }, [data]);
  if (error) return <ErrorState error={error} />;
  if (!data) return <Skeleton lines={8} />;

  const saveSettings = () =>
    save.run(async () => {
      await send('PUT', '/api/settings/commissions', { crm_from: from || null, cc });
      setSaved(true);
      reload();
    });
  const toggle = (u: User, field: 'commission_enabled' | 'sees_all_commissions', value: boolean) =>
    save.run(async () => {
      await send('PATCH', `/api/settings/commissions/users/${u.id}`, { [field]: value });
      reload();
    });
  const dirty = (from || null) !== data.crm_from || [...cc].sort().join() !== [...data.cc].sort().join();
  const active = data.users.filter((u) => u.status === 'aktivny');

  return (
    <>
      <SettingsHead title="Provízie obchodníkov" sub="provízia = pridaná hodnota obchodu × percento obchodníka platné v deň Vyhraté" />
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {saved && !dirty && <Notice tone="ok">Uložené.</Notice>}

      <Card title="Prechod zo Sales portálu">
        <div className="form-grid">
          <Field label="Provízie z CRM pre obchody vyhraté od">
            <input className="inp" type="date" value={from} disabled={!data.can_edit} onChange={(e) => { setFrom(e.target.value); setSaved(false); }} />
          </Field>
        </div>
        <p className="caption">
          Prázdne = provízie z CRM sú vypnuté (Sales portál ešte počíta). Nastavte deň, keď Sales portál prestane počítať – obchod nikdy nedostane
          províziu z oboch. Vypnutie neskôr nezruší už vzniknuté provízie.
        </p>
      </Card>

      <Card title="Príjemcovia kópie provízneho listu">
        <p className="caption" style={{ marginTop: 0 }}>Provízny list (PDF) dostane e-mailom obchodník a vybraní používatelia.</p>
        <div className="form-grid">
          {active.map((u) => (
            <Check key={u.id} checked={cc.includes(u.id)} disabled={!data.can_edit}
              onChange={(v) => { setCc((c) => (v ? [...c, u.id] : c.filter((x) => x !== u.id))); setSaved(false); }}>
              {u.name} <span className="caption">({u.team_name})</span>
            </Check>
          ))}
        </div>
        {data.can_edit && (
          <div style={{ marginTop: 12 }}>
            <button type="button" className="btn primary" disabled={save.busy || !dirty} onClick={saveSettings}>
              Uložiť nastavenia
            </button>
          </div>
        )}
      </Card>

      <Card flush title="Obchodníci">
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Používateľ</th>
                <th>Tím</th>
                <th className="num">Percento</th>
                <th>Počítať provízie</th>
                <th>Vidí všetky provízie</th>
                <th aria-label="Akcie" />
              </tr>
            </thead>
            <tbody>
              {data.users.map((u) => (
                <tr key={u.id}>
                  <td>
                    {u.name}
                    {u.status !== 'aktivny' && <> <Pill>pozvaný</Pill></>}
                    <div className="sub">{u.email}</div>
                  </td>
                  <td>{u.team_name}</td>
                  <td className="num">{num(u.pct, 2)} %</td>
                  <td>
                    <Check checked={u.commission_enabled} disabled={save.busy} onChange={(v) => toggle(u, 'commission_enabled', v)}>
                      <span className="sr-only">Počítať provízie – {u.name}</span>
                    </Check>
                  </td>
                  <td>
                    <Check checked={u.sees_all_commissions} disabled={save.busy || !data.can_edit} onChange={(v) => toggle(u, 'sees_all_commissions', v)}>
                      <span className="sr-only">Vidí všetky provízie – {u.name}</span>
                    </Check>
                  </td>
                  <td>
                    <button type="button" className="btn btn-sm" onClick={() => setRateFor(u)}>
                      Percento
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="caption" style={{ padding: '10px 24px 16px' }}>
          „Počítať provízie“ mení admin a schvaľovateľ cien; platí pre obchody vyhraté odteraz. „Vidí všetky provízie“ mení iba admin (napr. obchodný
          riaditeľ v tíme so „iba svoje“).
        </div>
      </Card>

      {rateFor && (
        <SidePanel title={`Percento provízie – ${rateFor.name}`} onClose={() => { setRateFor(null); reload(); }}>
          <CommissionSection userId={rateFor.id} />
        </SidePanel>
      )}
    </>
  );
}
