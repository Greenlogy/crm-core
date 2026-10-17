// Cenníky (obrazovka 20, modul 3 F1 – iba čítanie): zoznam cenníkov s platnou a budúcou verziou.
// Návrh vidí iba admin (databáza). Stĺpec „Zmluvy s cenou z cenníka“ príde v module 4.

import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { NewPriceListPanel } from '../components/pricelist-edit';
import { GlassBar, PageHero } from '../components/hero';
import { Icon, ICONS } from '../components/Layout';
import { PriceTabs, productsText } from '../components/pricelists';
import { Card, ErrorState, PageSkeleton, Pill } from '../components/ui';
import { useApi, type PriceListRow } from '../lib/api';
import { date, EMPTY } from '../lib/format';
import { label, SEGMENT } from '../lib/labels';
import { useMe } from '../lib/me';

export function PriceListsPage() {
  const navigate = useNavigate();
  const { data, error } = useApi<{ items: PriceListRow[] }>('/api/price-lists');
  const admin = useMe().is_admin;
  const [creating, setCreating] = useState(false);
  if (error) return <ErrorState error={error} />;
  if (!data) return <PageSkeleton />;

  return (
    <>
      <PageHero
        title="Cenníky"
        sub="verzie cien s platnosťou od – do"
        actions={
          admin ? (
            <>
              <button type="button" className="btn primary" onClick={() => setCreating(true)}>
                <Icon d={ICONS.plus} />
                Nový cenník
              </button>
            </>
          ) : undefined
        }
      />
      {creating && <NewPriceListPanel onClose={() => setCreating(false)} onCreated={(id) => navigate(`/cenniky/${id}`)} />}
      <GlassBar label="Cenníky, produkty, programy">
        <PriceTabs />
      </GlassBar>

      <Card flush label="Zoznam cenníkov">
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th scope="col">Cenník</th>
                <th scope="col">Segment</th>
                <th scope="col">Platná verzia</th>
                <th scope="col">Budúca verzia</th>
                <th scope="col">Produkty</th>
              </tr>
            </thead>
            <tbody>
              {data.items.length === 0 && (
                <tr>
                  <td colSpan={5} className="muted">
                    Zatiaľ tu nie je žiadny cenník.
                  </td>
                </tr>
              )}
              {data.items.map((l) => (
                <tr key={l.id} className="clickable" onClick={() => navigate(`/cenniky/${l.id}`)}>
                  <td>
                    <Link className="name-cell" to={`/cenniky/${l.id}`} onClick={(e) => e.stopPropagation()}>
                      {l.name}
                    </Link>
                  </td>
                  <td>{label(SEGMENT, l.segment)}</td>
                  <td>
                    {l.current_version_id ? (
                      <>
                        <Pill tone="positive" live>
                          platná
                        </Pill>{' '}
                        {l.current_version_name} · od {date(l.current_valid_from)}
                      </>
                    ) : (
                      EMPTY
                    )}
                  </td>
                  <td>
                    {l.future_version_id ? (
                      <>
                        {l.future_version_name} · od {date(l.future_valid_from)}
                      </>
                    ) : l.draft_version_id ? (
                      <>
                        {l.draft_version_name} · <Pill tone="warning">návrh</Pill>
                      </>
                    ) : (
                      EMPTY
                    )}
                  </td>
                  <td>{productsText(l.products)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="price-note">
          Ceny sú bez DPH na 4 desatinné miesta. Schválená verzia sa nedá meniť – oprava = nová verzia. Cenníky spravuje admin,
          ostatní ich vidia.
        </div>
      </Card>
    </>
  );
}
