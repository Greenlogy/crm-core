// Naplánované úlohy Workera (Cloudflare Cron Triggers, wrangler.toml [triggers]).
// Bežia bez prihláseného používateľa ako rola crm_app: nevidia žiadne dáta, volajú iba funkcie
// databázy s právami vlastníka, ktoré si dátum určia samy (aplikácia ho nevie podstrčiť).
// Do logu ide iba počet, nikdy údaje záznamov.

import { connect, type Env } from './db';

// Denná aktivácia Pripravovaných OOM (návrh DB modulu 2, časť 4.4): zmena dodávateľa potvrdená,
// začiatok dodávky nastal, povinné údaje vyplnené. Cron beží 22:05 aj 23:05 UTC (= 0:05 v Bratislave
// v zime aj v lete); druhé spustenie nič nezmení. Audit zapíše zmenu so zdrojom „Systém“.
export async function dailyOomActivation(env: Env): Promise<void> {
  const sql = connect(env);
  try {
    const [row] = await sql<{ n: number }[]>`SELECT oom_activate_due() AS n`;
    console.log(`Aktivácia OOM: ${row?.n ?? 0}`);
  } catch (err) {
    const code = (err as { code?: string }).code ?? 'unknown';
    console.error(`Aktivácia OOM zlyhala: ${(err as Error).name} ${code}`);
    throw err;
  } finally {
    await sql.end();
  }
}
