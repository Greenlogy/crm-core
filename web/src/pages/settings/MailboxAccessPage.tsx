// Nastavenia – Čítanie schránok (modul 5, F4; 0042, 0043): denník každého čítania schránky cez Gmail API – kto
// (alebo beh na pozadí), ktorá schránka, vlákno, metóda a formát, kedy. Iba pridávanie: nedá sa zmeniť ani zmazať.
// CRM číta iba vlákna e-mailov odoslaných z CRM (threads.get / messages.get, nikdy prílohy ani celé správy MIME).

import { Link } from 'react-router-dom';
import { Card, Empty, ErrorState, Skeleton } from '../../components/ui';
import { useApi } from '../../lib/api';
import { dateTime } from '../../lib/offers';
import { SettingsHead } from './SettingsLayout';

type Row = {
  id: number; at: string; method: string; format: string; gmail_thread_id: string; gmail_message_id: string | null;
  user_name: string | null; mailbox_name: string; mailbox: string; deal_id: string | null;
};

export function MailboxAccessPage() {
  const { data, error } = useApi<{ items: Row[] }>('/api/settings/mailbox-access');
  if (error) return <ErrorState error={error} />;
  if (!data) return <Skeleton lines={8} />;
  return (
    <>
      <SettingsHead title="Čítanie schránok" sub="Posledných 500 čítaní schránok cez Gmail – denník sa nedá zmeniť ani zmazať." />
      <Card flush>
        {data.items.length === 0 ? (
          <Empty>Zatiaľ žiadne čítanie schránok.</Empty>
        ) : (
          <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th>Kedy</th>
                <th>Kto</th>
                <th>Schránka</th>
                <th>Operácia</th>
                <th>Vlákno / správa</th>
                <th>Obchod</th>
              </tr>
            </thead>
            <tbody>
              {data.items.map((r) => (
                <tr key={r.id}>
                  <td>{dateTime(r.at)}</td>
                  <td>{r.user_name ?? 'Beh na pozadí'}</td>
                  <td title={r.mailbox}>{r.mailbox_name}</td>
                  <td className="mono">{r.method} · {r.format}</td>
                  <td className="mono">{r.gmail_thread_id}{r.gmail_message_id ? ` / ${r.gmail_message_id}` : ''}</td>
                  <td>{r.deal_id ? <Link to={`/obchody/${r.deal_id}`}>otvoriť</Link> : '–'}</td>
                </tr>
              ))}
            </tbody>
          </table>
          </div>
        )}
      </Card>
    </>
  );
}
