// Nastavenia – Párovanie sadzieb (obrazovka 24, modul 3 F3; iba admin). Produkt ↔ sadzba distribúcie podľa rozsahu PDS.
// Rozsahy PDS (ZSD, VSD, SSD a miestne DS) sa iba zobrazujú – nový rozsah = migrácia. Skupiny produktov (napr. Green DD1–DD8)
// sa zobrazia zlúčene, upravuje sa po produktoch (každá zmena v audite). PDS s vlastným rozsahom nikdy nepoužije
// spoločné riadky. Ukážka „čo CRM ponúkne“ volá product_candidates_by (0022) – to isté pravidlo ako pri OOM.

import { useState } from 'react';
import { Check, Field, Notice, Select, useSave } from '../../components/form';
import { compressCodes, productsText } from '../../components/pricelists';
import { Card, ErrorState, Skeleton, StatusPill } from '../../components/ui';
import { ApiError, get, send, useApi } from '../../lib/api';
import { PRODUCT_STATUS } from '../../lib/labels';
import { useMe } from '../../lib/me';
import { SettingsHead } from './SettingsLayout';

type Scope = { code: string; name: string; pds_code: string | null };
type Option = { scope: string; code: string; label: string };
type MappedProduct = {
  id: string;
  code: string;
  name: string;
  category: string;
  status: string;
  tariff_type: string;
  price_regulation: boolean | null;
  updated_at: string;
  tariffs: { scope: string; code: string }[];
};
type Mapping = { scopes: Scope[]; options: Option[]; products: MappedProduct[] };

export function TariffMappingPage() {
  const { data, error, reload } = useApi<Mapping>('/api/tariff-mapping');
  const [open, setOpen] = useState<string | null>(null);
  if (error) return <ErrorState error={error} />;

  return (
    <>
      <SettingsHead title="Párovanie sadzieb" sub="produkt ↔ sadzba distribúcie podľa PDS" />
      {!data ? (
        <Skeleton lines={6} />
      ) : (
        <>
          <Card flush label="Párovanie sadzieb">
            <MappingTable data={data} open={open} setOpen={setOpen} reload={reload} />
            <div className="price-note">
              ZSD a VSD majú pre 9 taríf (DMP1–DMP8, DMP10) jedinú sadzbu – produkt zo sadzby neurčíme, vyberá ho obchodník. Pri SSD
              a miestnych DS určí sadzba produkt jednoznačne. Produkty domácností sa vyberajú aj podľa cenovej regulácie (ANO / NIE
              Energopomoc). PDS s vlastným stĺpcom (ZSD, VSD) nikdy nepoužije stĺpec „SSD a miestne DS“. Nový stĺpec (PDS s vlastným
              párovaním) pridáva migrácia.
            </div>
          </Card>
          <Preview />
        </>
      )}
    </>
  );
}

type Group = { key: string; label: string; products: MappedProduct[] };

function groups(products: MappedProduct[]): Group[] {
  const out: Group[] = [];
  for (const p of products) {
    const key = `${p.name.replace(/\d+/g, '#')}|${p.category}|${p.price_regulation}`;
    const g = out.find((x) => x.key === key);
    if (g) g.products.push(p);
    else out.push({ key, label: '', products: [p] });
  }
  for (const g of out) g.label = productsText(g.products.map((p) => p.name));
  return out;
}

function MappingTable(props: { data: Mapping; open: string | null; setOpen: (k: string | null) => void; reload: () => void }) {
  const { scopes, options, products } = props.data;
  const labelOf = (scope: string, code: string) => options.find((o) => o.scope === scope && o.code === code)?.label ?? code;
  const sortOf = (scope: string, code: string) => options.findIndex((o) => o.scope === scope && o.code === code);
  const cell = (g: Group, scope: string) => {
    const codes = [...new Set(g.products.flatMap((p) => p.tariffs.filter((t) => t.scope === scope).map((t) => t.code)))];
    if (codes.length === 0) return '—';
    codes.sort((a, b) => sortOf(scope, a) - sortOf(scope, b));
    // sadzba, na ktorú pasuje viac produktov skupiny (ZSD C2-X3, VSD X3-C2) – produkt vyberá obchodník
    const shared = (c: string) => g.products.filter((p) => p.tariffs.some((t) => t.scope === scope && t.code === c)).length > 1;
    const many = codes.filter(shared).map((c) => `${labelOf(scope, c)} (vyberá obchodník)`);
    return [...many, ...compressCodes(codes.filter((c) => !shared(c)).map((c) => labelOf(scope, c)))].join(' · ');
  };
  return (
    <div className="table-wrap">
      <table className="tbl">
        <thead>
          <tr>
            <th scope="col">Produkt</th>
            {scopes.map((s) => (
              <th key={s.code} scope="col">
                {s.name}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {groups(products).map((g) => [
            <tr key={g.key}>
              <td>
                <div className="mapping-name">
                  <span>{g.label}</span>
                  <button type="button" className="btn btn-small" onClick={() => props.setOpen(props.open === g.key ? null : g.key)} aria-expanded={props.open === g.key}>
                    {props.open === g.key ? 'Zavrieť' : 'Upraviť'}
                  </button>
                </div>
              </td>
              {scopes.map((s) => (
                <td key={s.code}>{cell(g, s.code)}</td>
              ))}
            </tr>,
            props.open === g.key &&
              g.products.map((p) => (
                <tr key={p.id} className="params-row">
                  <td colSpan={scopes.length + 1}>
                    <ProductEditor product={p} scopes={scopes} options={options} onSaved={props.reload} />
                  </td>
                </tr>
              )),
          ])}
        </tbody>
      </table>
    </div>
  );
}

function ProductEditor(props: { product: MappedProduct; scopes: Scope[]; options: Option[]; onSaved: () => void }) {
  const p = props.product;
  const initial = () => Object.fromEntries(props.scopes.map((s) => [s.code, p.tariffs.filter((t) => t.scope === s.code).map((t) => t.code)]));
  const [sel, setSel] = useState<Record<string, string[]>>(initial);
  const [saved, setSaved] = useState(false);
  const { busy, error, run } = useSave();
  const toggle = (scope: string, code: string, on: boolean) => {
    setSaved(false);
    setSel((x) => ({ ...x, [scope]: on ? [...(x[scope] ?? []), code] : (x[scope] ?? []).filter((c) => c !== code) }));
  };
  const save = () =>
    run(async () => {
      await send('PUT', `/api/products/${p.id}/tariffs`, { updated_at: p.updated_at, tariffs: sel });
      setSaved(true);
      props.onSaved();
    });
  return (
    <div className="mapping-editor">
      <div className="mapping-editor-head">
        <strong>{p.name}</strong> <StatusPill map={PRODUCT_STATUS} value={p.status} />
        <span className="grow" />
        {saved && <span className="caption">Uložené.</span>}
        <button type="button" className="btn primary" onClick={save} disabled={busy}>
          {busy ? 'Ukladám…' : 'Uložiť párovanie'}
        </button>
      </div>
      {error && <Notice tone="error">{error}</Notice>}
      <div className="mapping-scopes">
        {props.scopes.map((s) => (
          <fieldset key={s.code} className="mapping-scope">
            <legend>{s.name}</legend>
            {props.options
              .filter((o) => o.scope === s.code)
              .map((o) => (
                <Check key={o.code} checked={(sel[s.code] ?? []).includes(o.code)} onChange={(on) => toggle(s.code, o.code, on)}>
                  {o.label}
                </Check>
              ))}
          </fieldset>
        ))}
      </div>
    </div>
  );
}

type Lookup = { code: string; label: string; parent: string | null; hidden: boolean };
type Candidate = { product_id: string; name: string; rank: number; is_only: boolean; is_addon: boolean };

function Preview() {
  const me = useMe();
  const org = me.orgs.find((o) => o.default)?.id ?? me.orgs[0]?.id ?? '';
  const { data: lookups } = useApi<Record<string, Lookup[]>>(`/api/oom-options?org=${org}`);
  const [pds, setPds] = useState('');
  const [tariff, setTariff] = useState('');
  const [segment, setSegment] = useState<'domacnost' | 'firma'>('firma');
  const [regulation, setRegulation] = useState('ano');
  const [nt, setNt] = useState(false);
  const [result, setResult] = useState<Candidate[] | null>(null);
  const [err, setErr] = useState<string | null>(null);
  const pdsList = (lookups?.pds ?? []).filter((x) => !x.hidden);
  const tariffs = (lookups?.sadzba_distribucie ?? []).filter((x) => !x.hidden && x.parent === pds);
  const show = async () => {
    setErr(null);
    try {
      const q = new URLSearchParams({ pds, sadzba: tariff, segment, regulacia: regulation, ...(nt ? { nt: '1' } : {}) });
      setResult((await get<{ items: Candidate[] }>(`/api/tariff-mapping/preview?${q}`)).items);
    } catch (e) {
      setErr(e instanceof ApiError ? e.message : 'Ukážka zlyhala.');
    }
  };
  return (
    <Card title="Ukážka: čo CRM ponúkne">
      <div className="params">
        <Field label="PDS">
          <Select value={pds} onChange={(v) => { setPds(v); setTariff(''); setResult(null); }} placeholder="Vyberte" options={pdsList.map((x) => ({ value: x.code, label: x.label }))} />
        </Field>
        <Field label="Sadzba">
          <Select value={tariff} onChange={(v) => { setTariff(v); setResult(null); }} placeholder="Vyberte" options={tariffs.map((x) => ({ value: x.code, label: x.label }))} />
        </Field>
        <Field label="Zákazník">
          <Select value={segment} onChange={setSegment} options={[{ value: 'domacnost', label: 'Domácnosť' }, { value: 'firma', label: 'Firma' }]} />
        </Field>
        <Field label="Cenová regulácia">
          <Select value={regulation} onChange={setRegulation} options={[{ value: 'ano', label: 'ANO' }, { value: 'nie', label: 'NIE' }, { value: '', label: 'nevyplnené' }]} />
        </Field>
        <Check checked={nt} onChange={setNt}>
          plánovaná spotreba NT
        </Check>
        <button type="button" className="btn" disabled={!pds || !tariff} onClick={show}>
          Ukázať
        </button>
      </div>
      {err && <Notice tone="error">{err}</Notice>}
      {result && (
        <div className="preview-result">
          {result.length === 0 ? (
            <p>Žiadny produkt z cenníka – individuálna ponuka.</p>
          ) : (
            <>
              {result.some((r) => !r.is_addon && r.rank === 1) && (
                <p>
                  <strong>Navrchu:</strong> {result.filter((r) => !r.is_addon && r.rank === 1).map((r) => r.name).join(', ')}
                  {result.some((r) => r.is_only) && ' – CRM vyplní samo'}
                </p>
              )}
              {result.some((r) => !r.is_addon && r.rank > 1) && (
                <p>
                  <strong>Ďalej:</strong> {result.filter((r) => !r.is_addon && r.rank > 1).map((r) => r.name).join(', ')}
                </p>
              )}
              {result.some((r) => r.is_addon) && (
                <p>
                  <strong>Doplnkovo:</strong> {result.filter((r) => r.is_addon).map((r) => r.name).join(', ')}
                </p>
              )}
            </>
          )}
        </div>
      )}
    </Card>
  );
}
