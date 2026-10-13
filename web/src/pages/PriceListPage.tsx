// Detail cenníka (obrazovka 21, modul 3 F1 – iba čítanie): položky zvolenej verzie bez DPH a s DPH, zoznam verzií.
// Ceny s DPH počíta databáza (price_list_item_v); web ich iba zobrazí. Stĺpce podľa obsahu verzie:
// VBattery, VIWA a Poplatky B2B nemajú VT/NT; VIWA ukáže poplatok za OOM a €/kW, VBattery mesačný poplatok.
// Tlačidlá Nová verzia, Schváliť, Export prídu v F2; „prejde X zmlúv“ v module 4.

import type { ReactNode } from 'react';
import { Link, useParams, useSearchParams } from 'react-router-dom';
import { tariffText, UUID_RE, vatText } from '../components/pricelists';
import { Card, Empty, ErrorState, PageSkeleton, Source, StatusPill } from '../components/ui';
import { useApi, type Num, type PriceListDetail, type PriceListItem } from '../lib/api';
import { date, dec } from '../lib/format';
import { label, SEGMENT, VERSION_STATE } from '../lib/labels';

type Col = { key: string; title: string; net: (i: PriceListItem) => Num; gross: (i: PriceListItem) => Num; decimals: [number, number] };

function columns(items: PriceListItem[]): Col[] {
  const any = (f: (i: PriceListItem) => Num) => items.some((i) => f(i) !== null);
  const viwa = items.some((i) => i.category === 'viwa');
  const cols: Col[] = [];
  if (any((i) => i.fee_oom_eur_month))
    cols.push({ key: 'oom', title: 'Mesačná platba za OM [€]', net: (i) => i.fee_oom_eur_month, gross: (i) => i.fee_oom_with_vat, decimals: [2, 4] });
  if (any((i) => i.fee_program_eur_month))
    cols.push({
      key: 'program',
      title: viwa ? 'Mesačne za OOM [€]' : 'Mesačný poplatok [€]',
      net: (i) => i.fee_program_eur_month,
      gross: (i) => i.fee_program_with_vat,
      decimals: [2, 4],
    });
  if (any((i) => i.fee_kw_eur_month))
    cols.push({
      key: 'kw',
      title: 'Poplatok za odchýlku [€/kW mesačne]',
      net: (i) => i.fee_kw_eur_month,
      gross: (i) => i.fee_kw_with_vat,
      decimals: [2, 4],
    });
  if (any((i) => i.price_vt_eur_mwh))
    cols.push({ key: 'vt', title: 'VT [€/MWh]', net: (i) => i.price_vt_eur_mwh, gross: (i) => i.price_vt_with_vat, decimals: [4, 4] });
  if (any((i) => i.price_nt_eur_mwh))
    cols.push({ key: 'nt', title: 'NT [€/MWh]', net: (i) => i.price_nt_eur_mwh, gross: (i) => i.price_nt_with_vat, decimals: [4, 4] });
  return cols;
}

function period(from: string, to: string | null): string {
  return to ? `${date(from)} – ${date(to)}` : `od ${date(from)}`;
}

export function PriceListPage() {
  const { id = '' } = useParams();
  const [params] = useSearchParams();
  const version = params.get('verzia') ?? '';
  const validId = UUID_RE.test(id) && (version === '' || UUID_RE.test(version));
  const path = validId ? `/api/price-lists/${id}${version ? `?version=${version}` : ''}` : '';

  if (!validId) {
    return (
      <>
        <Link to="/cenniky" className="back">
          ← Cenníky
        </Link>
        <Empty>Cenník neexistuje.</Empty>
      </>
    );
  }
  return <PriceListView path={path} id={id} />;
}

function PriceListView(props: { path: string; id: string }) {
  const { data: l, error } = useApi<PriceListDetail>(props.path);
  if (error) return <ErrorState error={error} />;
  if (!l || l.id !== props.id) return <PageSkeleton />;

  const v = l.versions.find((x) => x.id === l.selected_version_id) ?? null;
  const cols = columns(l.items);
  const withTariff = l.items.some((i) => i.tariffs.length > 0);
  const vats = [...new Set(l.items.map((i) => vatText(i.vat_rate as string | number | null)))];
  const nameOf = (vid: string | null) => l.versions.find((x) => x.id === vid)?.name;

  return (
    <>
      <Link to="/cenniky" className="back">
        ← Cenníky
      </Link>
      <header className="page-head">
        <div style={{ minWidth: 0 }}>
          <h1 className="t-page-title">{l.name}</h1>
          <div className="page-sub">
            <span>{label(SEGMENT, l.segment)}</span>
            {l.description && <span>{l.description}</span>}
            <Source />
          </div>
        </div>
      </header>

      {!v ? (
        <Empty>Cenník zatiaľ nemá žiadnu verziu.</Empty>
      ) : (
        <Card
          flush
          title={`Verzia ${v.name} · ${v.state === 'navrh' ? 'návrh' : period(v.valid_from, v.valid_to)}`}
          aside={<StatusPill map={VERSION_STATE} value={v.state} />}
        >
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th scope="col" rowSpan={2}>
                    Produkt
                  </th>
                  {withTariff && (
                    <th scope="col" rowSpan={2}>
                      Sadzba
                    </th>
                  )}
                  {cols.map((c) => (
                    <th key={c.key} scope="colgroup" colSpan={2} className="num">
                      {c.title}
                    </th>
                  ))}
                </tr>
                <tr>
                  {cols.flatMap((c) => [
                    <th key={`${c.key}-n`} scope="col" className="num sub-head">
                      bez DPH
                    </th>,
                    <th key={`${c.key}-g`} scope="col" className="num sub-head">
                      s DPH
                    </th>,
                  ])}
                </tr>
              </thead>
              <tbody>
                {l.items.length === 0 && (
                  <tr>
                    <td colSpan={1 + (withTariff ? 1 : 0) + cols.length * 2} className="muted">
                      Verzia nemá žiadnu položku.
                    </td>
                  </tr>
                )}
                {l.items.map((i) => (
                  <tr key={i.id}>
                    <td>{i.product_name}</td>
                    {withTariff && <td>{tariffText(i.tariffs, i.tariff_type, i.category)}</td>}
                    {cols.flatMap((c): ReactNode[] => [
                      <td key={`${c.key}-n`} className="num">
                        {dec(c.net(i), ...c.decimals)}
                      </td>,
                      <td key={`${c.key}-g`} className="num with-vat">
                        {dec(c.gross(i), ...c.decimals)}
                      </td>,
                    ])}
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
          <div className="price-note">
            DPH {vats.join(', ')} – sadzba DPH je vlastnosť produktu
            {v.status !== 'navrh' ? ' (pri schválení sa uložila do položky)' : ''}. Ceny s DPH sa dopočítajú, ukladajú sa iba ceny
            bez DPH.
          </div>
        </Card>
      )}

      <Card flush title="Verzie" label="Verzie cenníka">
        <div className="version-list">
          {l.versions.map((x) => (
            <Link
              key={x.id}
              className="version-row"
              to={`/cenniky/${l.id}?verzia=${x.id}`}
              aria-current={x.id === l.selected_version_id ? 'true' : undefined}
            >
              <strong>{x.name}</strong>
              <span>{x.state === 'navrh' ? `od ${date(x.valid_from)} · návrh` : period(x.valid_from, x.valid_to)}</span>
              <StatusPill map={VERSION_STATE} value={x.state} />
              {x.status === 'nahradena' && <span className="caption">nahradená opravenou verziou</span>}
              {x.copied_from_id && nameOf(x.copied_from_id) && <span className="caption">kópia verzie {nameOf(x.copied_from_id)}</span>}
              {x.approved_at && (
                <span className="caption">
                  schválil {x.approved_by_name ?? 'skript naplnenia'} {date(x.approved_at)}
                </span>
              )}
            </Link>
          ))}
        </div>
      </Card>
    </>
  );
}
