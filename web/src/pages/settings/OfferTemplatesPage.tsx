// Nastavenia – Šablóny ponúk (dizajn 42; modul 5, F3; migrácie 0039, 0040). Pevné texty PDF a záväznej objednávky
// pre druh ponuky × jazyk. Platná verzia sa nemení: zmena = nový návrh (kópia), úprava sekcií, náhľad PDF so vzorovými
// údajmi, zverejnenie (doterajšia platná sa nahradí; odoslané ponuky si pamätajú svoju verziu). Premenné «…» iba zo
// zoznamu povolených – inak databáza uloženie odmietne. Obrázky do PDF sú spoločné pre všetky šablóny.

import { useEffect, useState } from 'react';
import { Field, Notice, TextInput, useSave } from '../../components/form';
import { Card, Empty, ErrorState, Pill, Skeleton } from '../../components/ui';
import { ApiError, send, useApi } from '../../lib/api';
import { date, text } from '../../lib/format';
import { SettingsHead } from './SettingsLayout';

type Version = {
  id: string;
  kind: 'dodavka' | 'vykup' | 'viwa';
  language: 'sk' | 'en';
  version: number;
  status: 'navrh' | 'platna' | 'nahradena';
  note: string | null;
  updated_at: string;
  published_at: string | null;
  created_by_name: string | null;
  published_by_name: string | null;
};
type Detail = Version & {
  sections: Record<string, { nadpis: string; text: string }>;
  defaults: { zmluvna_pokuta?: number };
  variables: string[];
  keys: string[];
};
type Asset = { code: string; mime?: string; sha256?: string; created_at?: string; created_by_name?: string | null; source?: string };

const KIND: Record<Version['kind'], string> = { dodavka: 'Dodávka', vykup: 'Výkup', viwa: 'Green VIWA' };
const STATUS: Record<Version['status'], { label: string; tone: 'positive' | 'warning' | 'neutral' }> = {
  platna: { label: 'Platná', tone: 'positive' },
  navrh: { label: 'Návrh', tone: 'warning' },
  nahradena: { label: 'Nahradená', tone: 'neutral' },
};
const SECTION_LABEL: Record<string, string> = {
  hlavicka: 'Hlavička (nadpis, podnadpis, adresa)', udaje: '1. Údaje o zákazníkovi', predmet: '2. Predmet ponuky',
  cenova_ponuka: '3. Cenová ponuka – pevné body', podmienky: '4. Platobné / ostatné podmienky', platnost: '5. Platnosť ponuky',
  vseobecne: '6. Všeobecné ustanovenia', objednavka: 'Záväzná objednávka / prijatie ponuky', spracoval: 'Cenovú ponuku spracoval',
  pribeh: 'Príbeh Greenlogy', vizia: 'Vízia Greenlogy', paticka: 'Pätička',
};
const ASSET_LABEL: Record<string, string> = {
  titulna: 'Titulná strana', referencie_zakaznici: 'Referencie – zákazníci', referencie_partneri: 'Referencie – partneri',
  energeticky_mix: 'Energetický mix',
};

export function OfferTemplatesPage() {
  const { data, error, reload } = useApi<{ items: Version[]; can_edit: boolean }>('/api/offer-templates');
  const [selected, setSelected] = useState<string | null>(null);
  useEffect(() => {
    if (data && (!selected || !data.items.some((v) => v.id === selected))) {
      setSelected(data.items.find((v) => v.status === 'platna')?.id ?? data.items[0]?.id ?? null);
    }
  }, [data]);
  if (error) return <ErrorState error={error} />;
  const sel = data?.items.find((v) => v.id === selected) ?? null;
  return (
    <>
      <SettingsHead
        title="Šablóny ponúk"
        sub="pevné texty PDF a záväznej objednávky · SK a EN"
        actions={
          sel ? (
            <a className="btn" href={`/api/offer-templates/${sel.id}/preview.pdf`} target="_blank" rel="noreferrer">
              Náhľad PDF
            </a>
          ) : undefined
        }
      />
      <Card flush>
        {!data ? (
          <div style={{ padding: 16 }}>
            <Skeleton lines={6} />
          </div>
        ) : (
          <div className="table-wrap">
            <table className="tbl">
              <thead>
                <tr>
                  <th>Druh ponuky</th>
                  <th>Jazyk</th>
                  <th>Verzia</th>
                  <th>Stav</th>
                  <th>Zmenil</th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((v) => (
                  <tr key={v.id} className={`clickable${v.id === selected ? ' selected' : ''}`} onClick={() => setSelected(v.id)}>
                    <td>
                      <strong>{KIND[v.kind]}</strong>
                    </td>
                    <td>{v.language.toUpperCase()}</td>
                    <td className="muted">
                      v{v.version}
                      {v.published_at ? ` · ${date(v.published_at)}` : ''}
                    </td>
                    <td>
                      <Pill tone={STATUS[v.status].tone}>{STATUS[v.status].label}</Pill>
                    </td>
                    <td>{text(v.published_by_name ?? v.created_by_name ?? (v.version === 1 ? 'prvá verzia (texty Petra)' : null))}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
      {sel && <TemplateDetail key={sel.id} id={sel.id} canEdit={!!data?.can_edit} onChanged={reload} onSelect={setSelected} />}
      <AssetsCard canEdit={!!data?.can_edit} />
    </>
  );
}

function TemplateDetail(props: { id: string; canEdit: boolean; onChanged: () => void; onSelect: (id: string) => void }) {
  const { data, reload } = useApi<Detail>(`/api/offer-templates/${props.id}`);
  const [edit, setEdit] = useState<Record<string, { nadpis: string; text: string }> | null>(null);
  const [penalty, setPenalty] = useState('');
  const save = useSave();
  useEffect(() => {
    if (data) {
      setEdit(null);
      setPenalty(data.defaults.zmluvna_pokuta === undefined ? '' : String(data.defaults.zmluvna_pokuta));
    }
  }, [data]);
  if (!data) return null;
  const draft = data.status === 'navrh' && props.canEdit;
  const sections = edit ?? data.sections;
  const keys = data.keys.filter((k) => k in data.sections);
  const changed = edit !== null || penalty !== (data.defaults.zmluvna_pokuta === undefined ? '' : String(data.defaults.zmluvna_pokuta));
  const done = () => {
    reload();
    props.onChanged();
  };
  return (
    <Card
      title={`${KIND[data.kind]} · ${data.language.toUpperCase()} · v${data.version}`}
      aside={
        <span className="head-actions">
          {props.canEdit && data.status !== 'navrh' && (
            <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
              const r = await send<{ id: string }>('POST', '/api/offer-templates', { from_id: data.id });
              props.onChanged();
              props.onSelect(r.id);
            })}>
              Nová verzia (návrh)
            </button>
          )}
          {draft && (
            <>
              <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
                await send('DELETE', `/api/offer-templates/${data.id}`);
                props.onChanged();
              })}>
                Zmazať návrh
              </button>
              <button type="button" className="btn" disabled={save.busy || !changed} onClick={() => save.run(async () => {
                const defaults = { ...data.defaults };
                if (penalty.trim() === '') delete defaults.zmluvna_pokuta;
                else defaults.zmluvna_pokuta = Number(penalty.replace(',', '.'));
                await send('PATCH', `/api/offer-templates/${data.id}`, { sections, defaults });
                done();
              })}>
                Uložiť návrh
              </button>
              <button type="button" className="btn primary" disabled={save.busy || changed} title={changed ? 'Najprv uložte zmeny' : undefined}
                onClick={() => save.run(async () => {
                  await send('POST', `/api/offer-templates/${data.id}/publish`);
                  done();
                })}>
                Zverejniť
              </button>
            </>
          )}
        </span>
      }
    >
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {data.status === 'platna' && <p className="caption">Platná verzia sa nemení. Pre zmenu textov vytvorte novú verziu (návrh), upravte ju a zverejnite.</p>}
      {data.status === 'navrh' && data.language === 'en' && (
        <Notice tone="ok">Anglický preklad čaká na kontrolu. Kým ho admin nezverejní, ponuku v angličtine nemožno odoslať.</Notice>
      )}
      <div className="tpl-sections">
        {keys.map((k) => (
          <div key={k} className="tpl-section">
            <div className="tpl-head">{SECTION_LABEL[k] ?? k}</div>
            {draft ? (
              <>
                <TextInput value={sections[k]?.nadpis ?? ''} onChange={(x) => setEdit({ ...sections, [k]: { ...sections[k], nadpis: x } })} placeholder="Nadpis" />
                <textarea
                  className="inp tpl-text"
                  rows={Math.min(14, Math.max(3, (sections[k]?.text ?? '').split('\n').length + 1))}
                  value={sections[k]?.text ?? ''}
                  onChange={(e) => setEdit({ ...sections, [k]: { ...sections[k], text: e.target.value } })}
                />
              </>
            ) : (
              <>
                {sections[k]?.nadpis && <div className="tpl-title">{sections[k].nadpis}</div>}
                <div className="tpl-preview">{sections[k]?.text}</div>
              </>
            )}
          </div>
        ))}
      </div>
      {data.kind !== 'viwa' && (
        <div className="form-grid" style={{ marginTop: 12 }}>
          <Field label="Zmluvná pokuta [€/MWh]" hint="predvolená v ponuke; nižšiu v ponuke schvaľuje schvaľovateľ cien">
            <TextInput value={penalty} disabled={!draft} onChange={setPenalty} />
          </Field>
        </div>
      )}
      <p className="caption" style={{ marginTop: 12 }}>
        Premenné «…» doplní CRM z ponuky: {data.variables.map((v) => `«${v}»`).join(', ')}. Bloky [[spot]]…[[/spot]] (body o SPOT) a
        [[kompenzacia]]…[[/kompenzacia]] (výkup) sa zobrazia iba pri splnení podmienky. Obchodník mení iba premenné polia ponuky.
      </p>
    </Card>
  );
}

function AssetsCard(props: { canEdit: boolean }) {
  const { data, reload } = useApi<{ items: Asset[] }>('/api/offer-assets');
  const [ver, setVer] = useState(0);
  const save = useSave();
  const upload = (code: string, file: File) =>
    save.run(async () => {
      if (file.size > 1024 * 1024) throw new ApiError(400, 'Obrázok môže mať najviac 1 MB.');
      const buf = new Uint8Array(await file.arrayBuffer());
      let bin = '';
      for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode(...buf.subarray(i, i + 0x8000));
      await send('POST', '/api/offer-assets', { code, mime: file.type, data_base64: btoa(bin) });
      setVer((v) => v + 1);
      reload();
    });
  return (
    <Card title="Obrázky v PDF" aside={<span className="caption">spoločné pre všetky šablóny</span>}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {!data ? (
        <Empty>Načítavam…</Empty>
      ) : (
        <div className="tpl-assets">
          {data.items.map((a) => (
            <figure key={a.code} className="tpl-asset">
              <img src={`/api/offer-assets/${a.code}?v=${ver}`} alt={ASSET_LABEL[a.code]} />
              <figcaption>
                {ASSET_LABEL[a.code]}
                <div className="caption">{a.sha256 ? `nahral ${text(a.created_by_name)} ${date(a.created_at ?? null)}` : 'pribalený z návrhu'}</div>
                {props.canEdit && (
                  <label className="btn btn-sm">
                    Nahrať nový
                    <input type="file" accept="image/png,image/jpeg" hidden onChange={(e) => e.target.files?.[0] && upload(a.code, e.target.files[0])} />
                  </label>
                )}
              </figcaption>
            </figure>
          ))}
        </div>
      )}
      <p className="caption">PNG alebo JPEG do 1 MB. Nový obrázok sa použije v ďalších PDF; už odoslané PDF sa nemenia.</p>
    </Card>
  );
}
