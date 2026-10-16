// Časy naplánovaných úloh v Europe/Bratislava. Cloudflare Cron beží v UTC, preto Cron cien beží v pracovné dni o 5, 6, 11
// a 12 UTC a kód pustí beh iba vtedy, keď je v Bratislave 7:00 alebo 13:00 (zima UTC+1: 6 a 12 UTC; leto UTC+2: 5 a 11 UTC).

/** Cron cien vo wrangler.toml [triggers] (kontroluje test). */
export const PRICE_CRON = '0 5,6,11,12 * * 1-5';

/** Hodiny behu cien v Bratislave (Peter 16. 10.: 7:00 a 13:00). */
export const PRICE_HOURS = [7, 13];

const PARTS = new Intl.DateTimeFormat('en-GB', {
  timeZone: 'Europe/Bratislava',
  weekday: 'short',
  hour: '2-digit',
  minute: '2-digit',
  hourCycle: 'h23',
});

/** Deň v týždni, hodina a minúta v Bratislave pre čas v ms. */
export function bratislavaTime(ms: number): { weekday: string; hour: number; minute: number } {
  const p = Object.fromEntries(PARTS.formatToParts(new Date(ms)).map((x) => [x.type, x.value]));
  return { weekday: p.weekday, hour: Number(p.hour), minute: Number(p.minute) };
}

/** Má sa v tomto spustení Cronu načítať cena? Iba po – pi o 7:00 alebo 13:00 v Bratislave (prvých 30 minút po štarte). */
export function isPriceSlot(scheduledTime: number): boolean {
  const t = bratislavaTime(scheduledTime);
  return !['Sat', 'Sun'].includes(t.weekday) && PRICE_HOURS.includes(t.hour) && t.minute < 30;
}
