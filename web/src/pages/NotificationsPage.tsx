// Upozornenia (zvonček, modul Zmluvy F4, 0028): 4 mesiace pred koncom zmluvy, prolongácia, zmluva bez prolongácie,
// Pod hranicou bez výnimky, žiadosti a rozhodnutia o výnimkách, chyby nočného behu. Zakladá ich databáza;
// používateľ vidí iba vlastné a označí ich ako prečítané (kliknutím na odkaz alebo tlačidlom).

import { Link } from 'react-router-dom';
import { Notice, useSave } from '../components/form';
import { Card, Empty, ErrorState, Item, Pill, Skeleton } from '../components/ui';
import { send, useApi, type NotificationRow } from '../lib/api';
import { date } from '../lib/format';
import { NOTIFICATION_KIND } from '../lib/labels';

const time = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', minute: '2-digit' }).format(new Date(v));

function target(n: NotificationRow): { to: string; label: string } | null {
  if (n.contract_id) return { to: `/zmluvy/${n.contract_id}`, label: `Zmluva ${n.contract_number ?? ''}`.trim() };
  if (n.price_exception_id) return { to: '/vynimky', label: 'Výnimky z ceny' };
  if (n.job_run_id) return { to: '/nastavenia/nocny-beh', label: 'Denník nočného behu' };
  return null;
}

export function NotificationsPage() {
  const { data, error, reload } = useApi<{ unread: number; items: NotificationRow[] }>('/api/notifications');
  const save = useSave();

  const markRead = (n: NotificationRow) => {
    if (n.read_at) return;
    void send('POST', `/api/notifications/${n.id}/read`, {}).then(reload, () => undefined);
  };
  const markAll = () =>
    save.run(async () => {
      await send('POST', '/api/notifications/read-all', {});
      reload();
    });

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Upozornenia</h1>
          <div className="page-sub">{data ? `${data.unread} neprečítaných` : ''}</div>
        </div>
        <div className="head-actions">
          <button type="button" className="btn" disabled={save.busy || !data?.unread} onClick={markAll}>
            Označiť všetko ako prečítané
          </button>
        </div>
      </header>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {error ? (
        <ErrorState error={error} />
      ) : !data ? (
        <Skeleton lines={6} />
      ) : (
        <Card label="Zoznam upozornení">
          {data.items.length === 0 ? (
            <Empty>Nemáte žiadne upozornenia.</Empty>
          ) : (
            data.items.map((n) => {
              const t = target(n);
              const kind = NOTIFICATION_KIND[n.kind] ?? { label: n.kind, tone: 'neutral' as const };
              return (
                <div key={n.id} className={n.read_at ? undefined : 'notif-unread'}>
                  <Item
                    title={
                      <>
                        <Pill tone={kind.tone}>{kind.label}</Pill> {n.detail}
                      </>
                    }
                    meta={
                      <>
                        {date(n.created_at)} {time(n.created_at)}
                        {t && (
                          <>
                            {' · '}
                            <Link to={t.to} onClick={() => markRead(n)}>
                              {t.label}
                            </Link>
                          </>
                        )}
                      </>
                    }
                    side={
                      n.read_at ? (
                        <span className="caption">prečítané</span>
                      ) : (
                        <button type="button" className="btn" onClick={() => markRead(n)}>
                          Prečítané
                        </button>
                      )
                    }
                  />
                </div>
              );
            })
          )}
        </Card>
      )}
    </>
  );
}
