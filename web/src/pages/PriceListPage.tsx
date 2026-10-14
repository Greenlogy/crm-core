// Detail cenníka (obrazovka 21, modul 3 F1 – iba čítanie): položky zvolenej verzie bez DPH a s DPH, zoznam verzií.
// Ceny s DPH počíta databáza (price_list_item_v); web ich iba zobrazí. Stĺpce podľa obsahu verzie:
// VBattery, VIWA a Poplatky B2B nemajú VT/NT; VIWA ukáže poplatok za účet a €/kW, VBattery mesačný poplatok.
// F2 (iba admin): nová verzia (kópia), údaje a ceny návrhu, schválenie s náhľadom, ukončenie, zmazanie návrhu.
// Export: schválenú verziu každý, kto ju vidí; návrh iba admin. „Prejde X zmlúv“ príde v module 4.

import { useState, type ReactNode } from 'react';
import { Link, useNavigate, useParams, useSearchParams } from 'react-router-dom';
import { ApprovePanel, ClosePanel, DeleteDraftPanel, DraftDataPanel, EditItems, NewVersionPanel } from '../components/pricelist-edit';
import { Notice } from '../components/form';
import { tariffText, UUID_RE, vatText } from '../components/pricelists';
import { Card, Empty, ErrorState, PageSkeleton, Source, StatusPill } from '../components/ui';
import { useApi, type Num, type PriceListDetail, type PriceListItem } from '../lib/api';
import { date, dec } from '../lib/format';
import { label, SEGMENT, VERSION_STATE } from '../lib/labels';
import { useMe } from '../lib/me';

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
      title: viwa ? 'Mesačne za účet [€]' : 'Mesačný poplatok [€]',
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

type Panel = 'copy' | 'first' | 'data' | 'approve' | 'close' | 'delete' | null;

function PriceListView(props: { path: string; id: string }) {
  const { data: loaded, error, reload } = useApi<PriceListDetail>(props.path);
  const [saved, setSaved] = useState<PriceListDetail | null>(null);
  const [panel, setPanel] = useState<Panel>(null);
  const [editing, setEditing] = useState(false);
  const [skipped, setSkipped] = useState<string[]>([]);
  const navigate = useNavigate();
  const admin = useMe().is_admin;
  if (error) return <ErrorState error={error} />;
  const l = saved && saved.selected_version_id === loaded?.selected_version_id ? saved : loaded;
  if (!l || l.id !== props.id) return <PageSkeleton />;

  const v = l.versions.find((x) => x.id === l.selected_version_id) ?? null;
  const cols = columns(l.items);
  const withTariff = l.items.some((i) => i.tariffs.length > 0);
  const vats = [...new Set(l.items.map((i) => vatText(i.vat_rate as string | number | null)))];
  const nameOf = (vid: string | null) => l.versions.find((x) => x.id === vid)?.name;
  const hasDraft = l.versions.some((x) => x.status === 'navrh');
  const lastOpen = v && v.status === 'schvalena' && !v.valid_to && v.state !== 'ukoncena' &&
    !l.versions.some((x) => x.status === 'schvalena' && x.valid_from > v.valid_from);
  const done = (to?: string) => {
    setPanel(null);
    setEditing(false);
    setSaved(null);
    if (to && to !== v?.id) navigate(`/cenniky/${l.id}?verzia=${to}`);
    else reload();
  };

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
        <div className="head-actions">
          {v && (v.status !== 'navrh' || admin) && (
            <a className="btn" href={`/api/price-list-versions/${v.id}/export`} title="Stiahnuť verziu (.xlsx)">
              Export
            </a>
          )}
          {admin && !v && (
            <button type="button" className="btn primary" onClick={() => setPanel('first')}>
              Vytvoriť prvú verziu
            </button>
          )}
          {admin && v && v.status !== 'navrh' && !hasDraft && (
            <button type="button" className="btn primary" onClick={() => setPanel('copy')}>
              Nová verzia (kópia)
            </button>
          )}
          {admin && lastOpen && (
            <button type="button" className="btn" onClick={() => setPanel('close')}>
              Ukončiť cenník
            </button>
          )}
        </div>
      </header>
      {skipped.length > 0 && <Notice tone="error">Do návrhu sa neskopírovali ukončené produkty: {skipped.join(', ')}.</Notice>}
      {panel === 'first' && <NewVersionPanel listId={l.id} onClose={() => setPanel(null)} onDone={(nid) => done(nid)} />}
      {panel === 'copy' && v && (
        <NewVersionPanel
          listId={l.id}
          from={v}
          onClose={() => setPanel(null)}
          onDone={(nid, sk) => {
            setSkipped(sk);
            done(nid);
          }}
        />
      )}
      {panel === 'data' && v && <DraftDataPanel version={v} onClose={() => setPanel(null)} onDone={() => done()} />}
      {panel === 'approve' && v && <ApprovePanel version={v} onClose={() => setPanel(null)} onDone={() => done()} />}
      {panel === 'close' && v && <ClosePanel version={v} listName={l.name} onClose={() => setPanel(null)} onDone={() => done()} />}
      {panel === 'delete' && v && (
        <DeleteDraftPanel
          version={v}
          onClose={() => setPanel(null)}
          onDone={() => {
            setPanel(null);
            navigate(`/cenniky/${l.id}`);
          }}
        />
      )}

      {!v ? (
        <Empty>Cenník zatiaľ nemá žiadnu verziu.</Empty>
      ) : (
        <Card
          flush
          title={`Verzia ${v.name} · ${v.state === 'navrh' ? 'návrh' : period(v.valid_from, v.valid_to)}`}
          aside={
            <span className="card-actions">
              {admin && v.status === 'navrh' && !editing && (
                <>
                  <button type="button" className="btn" onClick={() => setEditing(true)}>
                    Upraviť ceny
                  </button>
                  <button type="button" className="btn" onClick={() => setPanel('data')}>
                    Údaje návrhu
                  </button>
                  <button type="button" className="btn btn-danger" onClick={() => setPanel('delete')}>
                    Zmazať návrh
                  </button>
                  <button type="button" className="btn primary" onClick={() => setPanel('approve')}>
                    Schváliť
                  </button>
                </>
              )}
              <StatusPill map={VERSION_STATE} value={v.state} />
            </span>
          }
        >
          {editing ? (
            <EditItems
              detail={l}
              version={v}
              onCancel={() => setEditing(false)}
              onSaved={(d) => {
                setSaved(d);
                setEditing(false);
              }}
            />
          ) : (
            <>
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
            </>
          )}
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
