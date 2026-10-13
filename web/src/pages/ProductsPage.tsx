// Produkty (obrazovka 22, modul 3 F1 – iba čítanie): katalóg s kategóriou, sadzbami, DPH, cenovými modelmi a stavom.
// Filter skupín a „Zobraziť ukončené“ je v adrese (?skupina=, ?ukoncene=1). Úpravy produktov prídu v F3.

import { useSearchParams } from 'react-router-dom';
import { Check } from '../components/form';
import { PriceTabs, tariffText, vatText } from '../components/pricelists';
import { Card, ErrorState, PageSkeleton, Source, StatusPill } from '../components/ui';
import { useApi, type ProductRow } from '../lib/api';
import { EMPTY, num } from '../lib/format';
import { label, PRICE_MODEL, PRODUCT_CATEGORY, PRODUCT_GROUPS, PRODUCT_STATUS } from '../lib/labels';

type Products = { items: ProductRow[]; counts: Record<string, number>; ended_count: number };

export function ProductsPage() {
  const [params, setParams] = useSearchParams();
  const group = params.get('skupina') ?? '';
  const ended = params.get('ukoncene') === '1';
  const query = new URLSearchParams({ ...(group ? { skupina: group } : {}), ...(ended ? { ukoncene: '1' } : {}) }).toString();
  const { data, error, loading } = useApi<Products>(`/api/products${query ? `?${query}` : ''}`);
  if (error) return <ErrorState error={error} />;
  if (!data) return <PageSkeleton />;

  const update = (next: { skupina?: string; ukoncene?: boolean }) => {
    const p = new URLSearchParams(params);
    if (next.skupina !== undefined) {
      if (next.skupina) p.set('skupina', next.skupina);
      else p.delete('skupina');
    }
    if (next.ukoncene !== undefined) {
      if (next.ukoncene) p.set('ukoncene', '1');
      else p.delete('ukoncene');
    }
    setParams(p, { replace: true });
  };

  return (
    <>
      <header className="page-head">
        <div>
          <h1 className="t-page-title">Produkty</h1>
          <div className="page-sub">
            <span>katalóg – čo predávame</span>
            <Source />
          </div>
        </div>
      </header>
      <PriceTabs />

      <Card flush label="Katalóg produktov">
        <div className="toolbar chips-bar">
          <div className="chips" role="group" aria-label="Filter podľa skupiny">
            {PRODUCT_GROUPS.map(([value, name]) => (
              <button key={value || 'all'} className="chip" type="button" aria-pressed={group === value} onClick={() => update({ skupina: value })}>
                {name} <span className="cc">{num(data.counts[value || 'vsetky'], 0)}</span>
              </button>
            ))}
          </div>
          {data.ended_count > 0 && (
            <Check checked={ended} onChange={(v) => update({ ukoncene: v })}>
              Zobraziť ukončené ({num(data.ended_count, 0)})
            </Check>
          )}
        </div>
        <div className="table-wrap" style={{ opacity: loading ? 0.6 : 1 }}>
          <table className="tbl">
            <thead>
              <tr>
                <th scope="col">Produkt</th>
                <th scope="col">Kategória</th>
                <th scope="col">Sadzby distribúcie</th>
                <th scope="col" className="num">
                  DPH
                </th>
                <th scope="col">Cenové modely</th>
                <th scope="col">Stav</th>
              </tr>
            </thead>
            <tbody>
              {data.items.length === 0 && (
                <tr>
                  <td colSpan={6} className="muted">
                    V tejto skupine nie je žiadny produkt.
                  </td>
                </tr>
              )}
              {data.items.map((p) => (
                <tr key={p.id}>
                  <td>{p.name}</td>
                  <td>{label(PRODUCT_CATEGORY, p.category)}</td>
                  <td>{tariffText(p.tariffs, p.tariff_type, p.category)}</td>
                  <td className="num">{p.vat_rate === null ? 'podľa diela' : vatText(p.vat_rate as string | number)}</td>
                  <td>{p.price_models.map((m) => label(PRICE_MODEL, m)).join(' · ') || EMPTY}</td>
                  <td>
                    <StatusPill map={PRODUCT_STATUS} value={p.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="price-note">
          Produkt sa nikdy nemaže, iba ukončí. „Dobieha“ = existujúce zmluvy bežia, nové sa nepredávajú. Firmy s individuálnou cenou
          platia mesačne 5 € bez DPH za OM (cenník Poplatky B2B).
        </div>
      </Card>
    </>
  );
}
