// Naplánované úlohy Workera (Cloudflare Cron Triggers, wrangler.toml [triggers]).
// Bežia bez prihláseného používateľa ako rola crm_app: nevidia žiadne dáta, volajú iba funkcie
// databázy s právami vlastníka, ktoré si dátum určia samy (aplikácia ho nevie podstrčiť).
// Do logu ide iba počet, nikdy údaje záznamov.

import { connect, type Env } from './db';

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
        `prolongované ${r?.prolongovane ?? 0}, ukončené ${r?.ukoncene ?? 0}, upozornenia 4 mesiace ${r?.konci_4_mesiace ?? 0}, ` +
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

// Nočný beh obchodov (deal_daily_run, 0032): upozornenie v deň ďalšieho kroku (raz pre každý dátum kroku).
export async function dailyDealRun(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const [row] = await sql<{ r: { dalsi_krok?: number } }[]>`SELECT deal_daily_run() AS r`;
    console.log(`Nočný beh obchodov: ďalší krok ${row?.r?.dalsi_krok ?? 0}`);
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
