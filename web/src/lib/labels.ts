// Slovenské popisy hodnôt z databázy a farba štítku (StatusPill). Stav sa vždy povie aj slovom.

export type Tone = 'positive' | 'negative' | 'warning' | 'info' | 'neutral';

export const SOURCE_NOTE = 'Zdroj: HubSpot, vzorka z 11. 10. 2026';
export const HUBSPOT_PORTAL = '5964726';

export const OOM_TYPE: Record<string, string> = {
  spotreba: 'Spotreba',
  vyroba: 'Výroba',
  sharing: 'Sharing',
  velkoobchod: 'Veľkoobchod',
};

export const OOM_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  aktivne: { label: 'Aktívne', tone: 'positive', live: true },
  neaktivne: { label: 'Neaktívne', tone: 'neutral' },
  zrusene: { label: 'Zrušené', tone: 'negative' },
  odidene: { label: 'Odídené', tone: 'negative' },
  prepisane: { label: 'Prepísané', tone: 'neutral' },
};

export const CONTRACT_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  rozpracovana: { label: 'Rozpracovaná', tone: 'neutral' },
  caka_na_podpis: { label: 'Čaká na podpis', tone: 'info' },
  podpisana: { label: 'Podpísaná', tone: 'info' },
  caka_na_zaradenie: { label: 'Čaká na zaradenie', tone: 'info' },
  aktivna: { label: 'Aktívna', tone: 'positive', live: true },
  ukoncena: { label: 'Ukončená', tone: 'neutral' },
  vypoved_neakceptovana: { label: 'Výpoveď neakceptovaná', tone: 'negative' },
  zmena_neuspesna: { label: 'Zmena neúspešná', tone: 'negative' },
};

export const PRICE_STATUS: Record<string, { label: string; tone: Tone }> = {
  platna: { label: 'Platná', tone: 'positive' },
  neplatna: { label: 'Neplatná', tone: 'neutral' },
};

export const PAYMENT_RATING: Record<string, string> = {
  A: 'A – bez meškania',
  B: 'B – občasné meškanie',
  C: 'C – opakované meškania',
  D: 'D – black list',
  E: 'E – ARCA Capital',
  X: 'X – bez histórie',
};

// Polia z FinStatu v HubSpote nesú text „true“/„false“.
export const yesNo = (v: string | null | undefined) => (v === 'true' ? 'Áno' : v === 'false' ? 'Nie' : v ?? null);

// Stav zákazníka (zadanie Zákazníci čl. 4); počíta sa, nevyberá sa ručne.
export const CUSTOMER_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  marketingovy_kontakt: { label: 'Marketingový kontakt', tone: 'neutral' },
  zaujemca: { label: 'Záujemca', tone: 'neutral', live: true },
  ponuka: { label: 'Ponuka', tone: 'warning', live: true },
  cakajuci_zakaznik: { label: 'Čakajúci zákazník', tone: 'info', live: true },
  zakaznik: { label: 'Zákazník', tone: 'positive', live: true },
  byvaly_zakaznik: { label: 'Bývalý zákazník', tone: 'negative' },
  zruseny_zakaznik: { label: 'Zrušený zákazník', tone: 'neutral' },
};
// Príznak „bývalý“ sa ukazuje iba pri stavoch, kde nie je zrejmý zo samotného stavu (čl. 12, 13).
export const showFormer = (status: string | null | undefined, former: boolean) =>
  former && (status === 'zaujemca' || status === 'ponuka' || status === 'cakajuci_zakaznik');

export const STATUS_SOURCE: Record<string, string> = {
  hubspot: 'východisková hodnota z HubSpotu',
  vypocet: 'vypočítané v CRM',
};

export const COMPANY_ROLE: Record<string, string> = {
  statutar: 'štatutár',
  decision_maker: 'decision maker',
  kontaktna_osoba: 'kontaktná osoba',
  fakturacia: 'fakturácia',
  technik: 'technik',
};
export const rolesText = (roles: string[] | null | undefined) =>
  roles && roles.length ? roles.map((r) => COMPANY_ROLE[r] ?? r).join(', ') : null;

export const SEGMENT: Record<string, string> = { domacnost: 'Domácnosť', firma: 'Firma', dodavatel: 'Dodávateľ' };
export const DIRECTION: Record<string, string> = { odber: 'Odber', dodavka: 'Dodávka' };

export const SOURCE_KIND: Record<string, string> = {
  fve: 'Fotovoltická elektráreň',
  voda: 'Vodná elektráreň',
  bioplyn: 'Bioplyn',
  plyn: 'Plyn',
  vietor: 'Veterná elektráreň',
  ostatne_oze: 'Ostatné OZE',
};
export const SOURCE_TYPE: Record<string, string> = {
  virtualna_bateria: 'Virtuálna batéria',
  lokalny_zdroj: 'Lokálny zdroj',
  vyrobny_zdroj: 'Výrobný zdroj',
  green_viwa: 'Green VIWA',
};
export const SUPPLIER_NOTICE: Record<string, string> = {
  akceptacia: 'Akceptácia výpovede',
  bez_akceptacie: 'Bez akceptácie',
  nezasiela_sa: 'Výpoveď sa nezasiela',
  odoslana: 'Výpoveď odoslaná',
  potvrdena: 'Výpoveď potvrdená',
};

export function dealTone(d: { is_closed: boolean; is_won: boolean }): Tone {
  if (d.is_won) return 'positive';
  if (d.is_closed) return 'negative';
  return 'info';
}

export const label = (map: Record<string, string>, v: string | null | undefined) => (v ? (map[v] ?? v) : null);

// Odkaz na záznam v HubSpote na porovnanie s originálom.
const HS_OBJECT = { company: '0-2', contact: '0-1', deal: '0-3', oom: '2-16666415' } as const;
export const hubspotUrl = (object: keyof typeof HS_OBJECT, id: string) =>
  `https://app.hubspot.com/contacts/${HUBSPOT_PORTAL}/record/${HS_OBJECT[object]}/${id}`;
