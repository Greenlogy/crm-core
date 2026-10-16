// Nastavenia – Nočný beh (modul Zmluvy F4, 0028): denník nočných behov zmlúv. Počty po krokoch, zmluvy so spätne
// zapísaným cenníkom (pre Nákup) a chyby jednotlivých zmlúv (krok, kód, text so skráteným EIC). Zmluva s chybou
// sa skúsi znova ďalšiu noc. Iba čítanie – vidí admin a Nákup. Beh s iným ako dnešným dátumom = ručný beh na Teste.
// F6 (0047): beh cien z Montelu (po – pi 7:00 a 13:00) – zapísané ceny dňa, 12-mesačný priemer SPOT, chyby Montelu.

import { Link } from 'react-router-dom';
import { Card, Empty, ErrorState, Pill, Rows, Skeleton } from '../../components/ui';
import { useApi, type JobRun } from '../../lib/api';
import { date, num } from '../../lib/format';
import { JOB_STEP } from '../../lib/labels';
import { SettingsHead } from './SettingsLayout';

const time = (v: string) =>
  new Intl.DateTimeFormat('sk-SK', { timeZone: 'Europe/Bratislava', hour: 'numeric', minute: '2-digit' }).format(new Date(v));

const COUNTS: [string, string][] = [
  ['regulacia', 'Regulácia – prepočítané zmluvy'],
  ['cennik', 'Nový cenník – prepočítané zmluvy'],
  ['prolongovane', 'Automaticky predĺžené'],
  ['ukoncene', 'Ukončené bez prolongácie'],
  ['konci_4_mesiace', 'Upozornenia 4 mesiace pred koncom'],
  ['chyba_cena_kontrola', 'Kontrola „Chýba cena“ (prvý beh roka)'],
  ['zakaznici', 'Prepočítaný stav zákazníka'],
];

const DEAL_COUNTS: [string, string][] = [
  ['dalsi_krok', 'Upozornenia na ďalší krok'],
  ['pripomienky', 'Pripomienky platnosti ponúk'],
  ['chyba_oom_na_zmluve', 'OOM bez zmluvy 14 dní po akceptácii'],
  ['ph_prepocitane', 'Pridaná hodnota obchodov – prepočítané'],
  ['ph_rozdiel', 'Pridaná hodnota obchodov – opravený rozdiel'],
];

const PRICE_COUNTS: [string, string][] = [
  ['ceny', 'Zapísané ceny dňa (BL / PL po rokoch dodávky)'],
  ['spot', '12-mesačný priemer SPOT'],
];

export function JobRunsPage() {
  const { data, error } = useApi<{ items: JobRun[] }>('/api/job-runs');
  return (
    <>
      <SettingsHead title="Nočný beh" sub="denník nočných behov zmlúv (každú noc o 0:05) a načítania cien z Montelu (po – pi 7:00 a 13:00)" />
      {error ? (
        <ErrorState error={error} />
      ) : !data ? (
        <Skeleton lines={6} />
      ) : data.items.length === 0 ? (
        <Card>
          <Empty>Nočný beh zmlúv ešte neprebehol.</Empty>
        </Card>
      ) : (
        data.items.map((j) => <Run key={j.id} j={j} />)
      )}
    </>
  );
}

function Run({ j }: { j: JobRun }) {
  const retro = j.result.cennik_spatne;
  const small = j.result.maly_podnik;
  const volume = j.result.objem_xm;
  const errors = j.errors.length;
  return (
    <Card
      title={j.job === 'ceny' ? `Ceny z Montelu k ${date(j.run_date)}` : j.job === 'obchody' ? `Obchody k ${date(j.run_date)}` : `Beh k ${date(j.run_date)}`}
      aside={
        <span className="page-sub">
          {j.test_date && <Pill tone="info">ručný beh (Test)</Pill>}
          {!j.finished_at ? (
            <Pill tone="warning">nedokončený</Pill>
          ) : errors > 0 ? (
            <Pill tone="negative">{errors} chýb</Pill>
          ) : (
            <Pill tone="positive">bez chýb</Pill>
          )}
          <span className="caption">
            {date(j.started_at)} {time(j.started_at)}
          </span>
        </span>
      }
    >
      <Rows rows={(j.job === 'ceny' ? PRICE_COUNTS : j.job === 'obchody' ? DEAL_COUNTS : COUNTS).map(([k, l]) => [l, num(Number(j.result[k] ?? 0), 0)])} />
      {retro && retro.pocet > 0 && (
        <div style={{ marginTop: 12 }}>
          <div className="t-section-title">Cenník zapísaný spätne ({num(retro.pocet, 0)})</div>
          <div className="caption">Nová verzia cenníka platí od dátumu v minulosti – cena sa zapísala od dátumu platnosti.</div>
          <div>{retro.zmluvy.join(', ')}</div>
        </div>
      )}
      {small && small.pocet > 0 && (
        <div style={{ marginTop: 12 }}>
          <div className="t-section-title">Malý podnik nad 30 MWh alebo nesúlad objemu ({num(small.pocet, 0)} zákazníkov)</div>
          <div className="caption">Zákazník v regulácii, ktorého objem podľa zmlúv alebo XM Trade je nad 30 MWh – overte nárok na regulovaný cenník.</div>
          <div>{small.zmluvy.join(', ')}</div>
        </div>
      )}
      {volume && volume.pocet > 0 && (
        <div style={{ marginTop: 12 }}>
          <div className="t-section-title">Objem zmluvy ≠ XM Trade o viac ako 5 % ({num(volume.pocet, 0)})</div>
          <div className="caption">Zmluvné množstvo ovplyvňuje pridanú hodnotu a províziu – overte ho s plánovanou spotrebou z XM Trade.</div>
          <div>{volume.zmluvy.join(', ')}</div>
        </div>
      )}
      {errors > 0 && (
        <div className="table-wrap" style={{ marginTop: 12 }}>
          <table className="tbl">
            <thead>
              <tr>
                <th>Krok</th>
                <th>Zmluva</th>
                <th>Kód</th>
                <th>Chyba</th>
              </tr>
            </thead>
            <tbody>
              {j.errors.map((e, i) => (
                <tr key={i}>
                  <td>{JOB_STEP[e.krok] ?? e.krok}</td>
                  <td>{e.zmluva && e.cislo ? <Link to={`/zmluvy/${e.zmluva}`}>{e.cislo}</Link> : '–'}</td>
                  <td>{e.kod}</td>
                  <td>{e.text}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="caption">
            {j.job === 'ceny' ? 'Ceny sa skúsia načítať znova pri ďalšom behu; dovtedy platí posledná cena najviac 7 dní stará.' : 'Zmluva s chybou sa ďalšiu noc skúsi znova.'}
          </div>
        </div>
      )}
    </Card>
  );
}
