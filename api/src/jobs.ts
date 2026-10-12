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
