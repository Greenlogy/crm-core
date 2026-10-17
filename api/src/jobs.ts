// Naplánované úlohy Workera (Cloudflare Cron Triggers, wrangler.toml [triggers]).
// Bežia bez prihláseného používateľa ako rola crm_app: nevidia žiadne dáta, volajú iba funkcie
// databázy s právami vlastníka, ktoré si dátum určia samy (aplikácia ho nevie podstrčiť).
// Do logu ide iba počet, nikdy údaje záznamov.

import { connect, type Env } from './db';
import { extractQuotes, extractSpotAvg, MontelError, montelGet, type MontelPath } from './montel';
import { isPriceSlot } from './schedule';

// Denný beh OOM (oom_daily_run, 0016): najprv plánované zmeny splatné k dnešku (prepis, odchod, zrušenie),
// potom aktivácia Pripravovaných OOM (zmena dodávateľa potvrdená, začiatok dodávky nastal, povinné údaje).
// Cron beží 22:05 aj 23:05 UTC (= 0:05 v Bratislave v zime aj v lete); druhé spustenie nič nezmení.
// Audit zapíše zmeny so zdrojom „Systém“.
export async function dailyOomActivation(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const [row] = await sql<{ r: { plany_vykonane: number; plany_zlyhali: number; aktivovane: number } }[]>`
      SELECT oom_daily_run() AS r`;
    const r = row?.r;
    console.log(`Denný beh OOM: plány vykonané ${r?.plany_vykonane ?? 0}, zlyhali ${r?.plany_zlyhali ?? 0}, aktivované ${r?.aktivovane ?? 0}`);
  } catch (err) {
    const code = (err as { code?: string }).code ?? 'unknown';
    console.error(`Denný beh OOM zlyhal: ${(err as Error).name} ${code}`);
    throw err;
  } finally {
    await sql.end();
  }
}

type ContractRun = {
  bezi?: boolean;
  regulacia?: number;
  cennik?: number;
  cennik_spatne?: { pocet: number };
  prolongovane?: number;
  ukoncene?: number;
  konci_4_mesiace?: number;
  obnova?: number;
  zakaznici?: number;
  chyby?: number;
};

// Nočný beh zmlúv (contract_daily_run, 0028): regulácia, cenník, prolongácia, príznaky, upozornenia, stav zákazníka.
// Chyby jednotlivých zmlúv zapíše databáza do denníka (job_run) a upozorní admina; beh pokračuje.
// Iba tento beh dostane dlhší časový limit (rola crm_app má 30 s pre bežné API) – SET LOCAL platí iba v jeho transakcii.
export async function dailyContractRun(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const r = await sql.begin(async (tx) => {
      await tx`SET LOCAL statement_timeout = '600s'`;
      const [row] = await tx<{ r: ContractRun }[]>`SELECT contract_daily_run() AS r`;
      return row?.r;
    });
    if (r?.bezi) {
      console.log('Nočný beh zmlúv: už beží iný beh, preskočené');
      return;
    }
    console.log(
      `Nočný beh zmlúv: regulácia ${r?.regulacia ?? 0}, cenník ${r?.cennik ?? 0} (spätne ${r?.cennik_spatne?.pocet ?? 0}), ` +
        `prolongované ${r?.prolongovane ?? 0}, ukončené ${r?.ukoncene ?? 0}, upozornenia 4 mesiace ${r?.konci_4_mesiace ?? 0}, obnovy ${r?.obnova ?? 0}, ` +
        `zákazníci ${r?.zakaznici ?? 0}, chyby ${r?.chyby ?? 0}`,
    );
  } catch (err) {
    const code = (err as { code?: string }).code ?? 'unknown';
    console.error(`Nočný beh zmlúv zlyhal: ${(err as Error).name} ${code}`);
    throw err;
  } finally {
    await sql.end();
  }
}

// Nočný beh obchodov (deal_daily_run, 0032): upozornenie v deň ďalšieho kroku (raz pre každý dátum kroku); potom poistka PH (0052).
export async function dailyDealRun(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const [row] = await sql<{ r: { dalsi_krok?: number; pripomienky?: number; chyba_oom_na_zmluve?: number } }[]>`SELECT deal_daily_run() AS r`;
    console.log(`Nočný beh obchodov: ďalší krok ${row?.r?.dalsi_krok ?? 0}, pripomienky ${row?.r?.pripomienky ?? 0}, OOM bez zmluvy ${row?.r?.chyba_oom_na_zmluve ?? 0}`);
    // PH obchodov (0052): poistka – prepočet všetkých (aj PH závislá od cien dňa), rozdiely do denníka behu obchodov
    const [ph] = await sql.begin(async (tx) => {
      await tx`SET LOCAL statement_timeout = '300s'`;
      return tx<{ r: { ph_prepocitane: number; ph_rozdiel: number } }[]>`SELECT deal_value_daily() AS r`;
    });
    console.log(`PH obchodov: prepočítané ${ph?.r?.ph_prepocitane ?? 0}, rozdiel ${ph?.r?.ph_rozdiel ?? 0}`);
    // F7: nočný prepočet provízií (v poradí obchodov, obsadený obchod preskočí); počty do denníka behu obchodov
    const [pv] = await sql.begin(async (tx) => {
      await tx`SET LOCAL statement_timeout = '300s'`;
      return tx<{ r: { provizie_prepocitane: number; provizie_zmena: number; provizie_preskocene: number } }[]>`SELECT commission_daily() AS r`;
    });
    console.log(`Provízie: prepočítané ${pv?.r?.provizie_prepocitane ?? 0}, zmena ${pv?.r?.provizie_zmena ?? 0}, preskočené ${pv?.r?.provizie_preskocene ?? 0}`);
  } catch (err) {
    const code = (err as { code?: string }).code ?? 'unknown';
    console.error(`Nočný beh obchodov zlyhal: ${(err as Error).name} ${code}`);
    throw err;
  } finally {
    await sql.end();
  }
}

// Celý nočný beh: najprv OOM (plány, regulácia na OOM, aktivácia), potom zmluvy a obchody. Zlyhanie OOM nezastaví zmluvy;
// ak niektorá časť zlyhá celá, handler skončí chybou (viditeľné vo Workers Observability).
export async function nightlyRun(env: Env): Promise<void> {
  let failed = false;
  try {
    await dailyOomActivation(env);
  } catch {
    failed = true;
  }
  try {
    await dailyContractRun(env);
  } catch {
    failed = true;
  }
  try {
    await dailyDealRun(env);
  } catch {
    failed = true;
  }
  if (failed) throw new Error('Nočný beh skončil s chybou (podrobnosti v logu vyššie).');
}

// Ceny z Montelu (market_price_daily_run, 0047): po – pi 7:00 a 13:00 v Bratislave (Cron v UTC, čas stráži isPriceSlot).
// Načíta BL / PL rokov dodávky a 12-mesačný priemer SPOT; chyby Montelu (iba kód a adresa) zapíše databáza do denníka
// behov a upozorní adminov. Do logu iba počty.
export async function pricesRun(env: Env, scheduledTime: number): Promise<void> {
  if (!isPriceSlot(scheduledTime)) return;
  await pricesFetchStore(env);
}

/**
 * Beh cien z Montelu (rovnaký o 7:00, o 13:00 aj z tlačidla „Načítať dnešné ceny z Montelu“ adminom): dnešné BL / PL rokov
 * dodávky a priemer SPOT od 1. 1.; zapisuje databáza ako beh na pozadí (vlastné pripojenie bez používateľa) s denníkom behov.
 */
export async function pricesFetchStore(env: Env): Promise<{ ceny: number; spot: number; chyby: number }> {
  const errors: { krok: string; kod: string; text: string }[] = [];
  const get = async (path: MontelPath): Promise<unknown> => {
    try {
      return await montelGet(env, path);
    } catch (err) {
      errors.push({ krok: 'montel', kod: err instanceof MontelError ? err.kod : 'chyba', text: path });
      return null;
    }
  };
  const [quotes, spot] = await Promise.all([get('/forwards/quotes'), get('/spot/aggregates')]);
  const rows = quotes === null ? [] : extractQuotes(quotes);
  const spotAvg = spot === null ? null : extractSpotAvg(spot);
  if (quotes !== null && rows.length === 0) errors.push({ krok: 'montel', kod: 'bez cien', text: '/forwards/quotes' });
  if (spot !== null && spotAvg === null) errors.push({ krok: 'montel', kod: 'bez priemeru', text: '/spot/aggregates' });
  const sql = connect(env);
  try {
    const [row] = await sql<{ r: { ceny: number; spot: number } }[]>`
      SELECT market_price_daily_run(${sql.json(rows)}, ${spotAvg}, ${sql.json(errors)}) AS r`;
    console.log(`Ceny z Montelu: zapísané ${row?.r?.ceny ?? 0}, SPOT ${row?.r?.spot ?? 0}, chyby ${errors.length}`);
    return { ceny: row?.r?.ceny ?? 0, spot: row?.r?.spot ?? 0, chyby: errors.length };
  } catch (err) {
    const code = (err as { code?: string }).code ?? 'unknown';
    console.error(`Ceny z Montelu zlyhali: ${(err as Error).name} ${code}`);
    throw err;
  } finally {
    await sql.end();
  }
}
