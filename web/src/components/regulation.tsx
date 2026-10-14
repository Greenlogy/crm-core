// Malý podnik a hranica 30 MWh (0029): hláška na karte zmluvy a zákazníka. Iba upozornenie – reguláciu nič nemení samo.
// Objem sa porovnáva zo zmlúv (Office portal) aj z plánovanej spotreby OOM (XM Trade); text skladá databáza.

import { Pill } from './ui';

export type RegulationCheck = {
  state: 'ostava' | 'vyradit' | 'nesulad';
  message: string;
  contract_mwh: string;
  xm_mwh: string | null;
};

export function RegulationNotice(props: { check: RegulationCheck | null | undefined }) {
  const c = props.check;
  if (!c) return null;
  const warn = c.state !== 'ostava';
  return (
    <div className={`reg-notice ${warn ? 'warn' : 'info'}`} role={warn ? 'alert' : 'status'}>
      <Pill tone={warn ? 'warning' : 'info'}>Malý podnik – regulácia</Pill>
      <span>{c.message}</span>
    </div>
  );
}
