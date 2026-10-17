// Programy (obrazovka 23, modul 3 F1 – iba čítanie): VBattery a Green VIWA s parametrami balíkov z platnej verzie cenníka.
// Ceny s DPH z databázy. Stĺpec „Zmluvy“ príde v module 4.

import { GlassBar, PageHero } from '../components/hero';
import { PriceTabs } from '../components/pricelists';
import { Card, ErrorState, PageSkeleton, StatusPill } from '../components/ui';
import { useApi, type ProgramRow } from '../lib/api';
import { date, dec, EMPTY } from '../lib/format';
import { PRODUCT_STATUS } from '../lib/labels';

const yesNo = (v: boolean | null) => (v === null ? EMPTY : v ? 'áno' : 'nie');

function source(rows: ProgramRow[]): string {
  const r = rows.find((x) => x.version_name);
  return r ? `cenník ${r.price_list_name}, verzia ${r.version_name} platná od ${date(r.valid_from)}` : 'bez platnej verzie cenníka';
}

export function ProgramsPage() {
  const { data, error } = useApi<{ vbattery: ProgramRow[]; viwa: ProgramRow[] }>('/api/programs');
  if (error) return <ErrorState error={error} />;
  if (!data) return <PageSkeleton />;
  const pending = 'pôvodná cena';

  return (
    <>
      <PageHero
        title="Programy"
        sub="VBattery a Green VIWA – parametre balíkov"
      />
      <GlassBar label="Cenníky, produkty, programy">
        <PriceTabs />
      </GlassBar>

      <Card flush title="Virtuálna batéria (VBattery)" label="VBattery">
        <div className="price-note">
          doplnková služba na zmluve o dodávke · iba domácnosti · na výrobnom OOM · jeden program na zmluvu · {source(data.vbattery)}
        </div>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th scope="col">Program</th>
                <th scope="col" className="num">
                  Mesačne bez DPH [€]
                </th>
                <th scope="col" className="num">
                  s DPH [€]
                </th>
                <th scope="col">GreenCar</th>
                <th scope="col">GreenShare</th>
                <th scope="col">Stav</th>
              </tr>
            </thead>
            <tbody>
              {data.vbattery.map((r) => (
                <tr key={r.product_id}>
                  <td>{r.name}</td>
                  <td className="num">{r.fee_program_eur_month === null ? pending : dec(r.fee_program_eur_month, 2, 4)}</td>
                  <td className="num with-vat">{dec(r.fee_program_with_vat, 2)}</td>
                  <td>
                    {r.greencar
                      ? `${dec(r.greencar_kwh_per_voucher, 0)} kWh → voucher ${dec(r.greencar_voucher_eur, 0)} €`
                      : EMPTY}
                  </td>
                  <td>{r.greenshare ? `${dec(r.greenshare_fee_pct, 0)} % z prevedených kWh` : EMPTY}</td>
                  <td>
                    <StatusPill map={PRODUCT_STATUS} value={r.status} />
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      <Card flush title="Green VIWA – virtuálna peňaženka" label="Green VIWA">
        <div className="price-note">
          samostatná zmluva namiesto výkupu · mesačná platba za účet + odchýlka za kW každého výrobného OOM · {source(data.viwa)}
        </div>
        <div className="table-wrap">
          <table className="tbl">
            <thead>
              <tr>
                <th scope="col">Balík</th>
                <th scope="col" className="num">
                  Za účet bez DPH [€]
                </th>
                <th scope="col" className="num">
                  s DPH [€]
                </th>
                <th scope="col">Konverzný kurz</th>
                <th scope="col" className="num">
                  Odchýlka bez DPH [€/kW mes.]
                </th>
                <th scope="col" className="num">
                  Aktivačný bonus
                </th>
                <th scope="col">Expirácia</th>
                <th scope="col">GreenCar</th>
                <th scope="col">GreenShare</th>
              </tr>
            </thead>
            <tbody>
              {data.viwa.map((r) => (
                <tr key={r.product_id}>
                  <td>{r.name.replace(/^Green VIWA /, '')}</td>
                  <td className="num">{dec(r.fee_program_eur_month, 2, 4)}</td>
                  <td className="num with-vat">{dec(r.fee_program_with_vat, 2)}</td>
                  <td>{r.viwa_conversion_factor === null ? EMPTY : `SPOT × ${dec(r.viwa_conversion_factor, 2)}`}</td>
                  <td className="num">{dec(r.fee_kw_eur_month, 2, 4)}</td>
                  <td className="num">{r.viwa_activation_bonus === null ? EMPTY : `${dec(r.viwa_activation_bonus, 0)} GreenCredit`}</td>
                  <td>{r.viwa_credit_expiry_months === null ? EMPTY : `${r.viwa_credit_expiry_months} mes.`}</td>
                  <td>{yesNo(r.greencar)}</td>
                  <td>{yesNo(r.greenshare)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
        <div className="price-note">
          Všetky parametre sú pevné pre balík, nič nie je individuálne. Inštalovaný výkon sa berie z OOM (výkon zdroja). CRM parametre
          eviduje, kredity, vouchery a poplatky v kWh počíta fakturácia. Mesačná platba je za jeden VIWA účet bez ohľadu na počet
          odovzdávacích miest. Príklad: VIWA Plus, 1 účet, 2 výrobné OOM 50 + 30 kW → 6,90 € + 80 kW × 0,20 € = 22,90 € mesačne
          bez DPH.
        </div>
      </Card>
    </>
  );
}
