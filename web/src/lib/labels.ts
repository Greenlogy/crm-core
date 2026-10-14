// Slovenské popisy hodnôt z databázy a farba štítku (StatusPill). Stav sa vždy povie aj slovom.

export type Tone = 'positive' | 'negative' | 'warning' | 'info' | 'neutral';

export const SOURCE_NOTE = 'Údaje z Greenlogy CRM';
export const HUBSPOT_PORTAL = '5964726';

export const OOM_TYPE: Record<string, string> = {
  spotreba: 'Spotreba',
  vyroba: 'Výroba',
  sharing: 'Sharing',
};

export const OOM_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  aktivne: { label: 'Aktívne', tone: 'positive', live: true },
  pripravovane: { label: 'Pripravované', tone: 'info' },
  zrusene: { label: 'Zrušené', tone: 'negative' },
  odidene: { label: 'Odídené', tone: 'negative' },
  prepisane: { label: 'Prepísané', tone: 'neutral' },
};

/** Stav zmluvy vypočítaný z fázy v Office portáli a dátumov (0025, contract_state). */
export const CONTRACT_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  v_priprave: { label: 'V príprave', tone: 'neutral' },
  podpisana: { label: 'Podpísaná', tone: 'info' },
  ucinna: { label: 'Účinná', tone: 'positive', live: true },
  skoncena: { label: 'Skončená', tone: 'neutral' },
  odmietnuta: { label: 'Odmietnutá', tone: 'negative' },
  neuspesna: { label: 'Neúspešná', tone: 'negative' },
};

/** Stav výnimky z ceny (0025; Expirovaná sa počíta). */
export const EXCEPTION_STATE: Record<string, { label: string; tone: Tone }> = {
  caka: { label: 'Čaká', tone: 'warning' },
  schvalena: { label: 'Schválená', tone: 'positive' },
  zamietnuta: { label: 'Zamietnutá', tone: 'negative' },
  pouzita: { label: 'Použitá', tone: 'info' },
  expirovana: { label: 'Expirovaná', tone: 'neutral' },
};

/** Typ zmluvy (0025). */
export const CONTRACT_TYPE: Record<string, string> = {
  dodavka_domacnost: 'Dodávka – domácnosť',
  dodavka_firma_nn: 'Dodávka – firma NN',
  dodavka_firma_vn: 'Dodávka – firma VN',
  vykup: 'Výkup',
  viwa: 'VIWA',
};

/** Fáza v Office portáli (0025). */
export const CONTRACT_PHASE: Record<string, string> = {
  rozpracovana: 'Rozpracovaná',
  caka_na_podpis: 'Čaká na podpis',
  fyzicke_podpisovanie: 'Fyzické podpisovanie',
  elektronicke_podpisovanie: 'Elektronické podpisovanie',
  podpisana: 'Finálne podpísaná',
  odmietnuta: 'Odmietnutá',
  ukoncena: 'Ukončená',
  neuspesna: 'Neúspešná',
};

/** Príznaky zmluvy na kontrolu (0025, 0026). */
export const CONTRACT_FLAG: Record<string, { label: string; tone: Tone }> = {
  chyba_cena: { label: 'Chýba cena', tone: 'negative' },
  kontrola_importu: { label: 'Na kontrolu', tone: 'warning' },
  sprolongovane_bez_ceny: { label: 'Sprolongované bez novej ceny', tone: 'warning' },
  konci_do_4_mesiacov: { label: 'Končí do 4 mesiacov', tone: 'info' },
  pod_hranicou_bez_vynimky: { label: 'Pod hranicou bez výnimky', tone: 'negative' },
};

export const CLOSE_REASON: Record<string, string> = {
  akvizicia: 'Akvizícia',
  retencia: 'Retencia',
  autoprolong: 'Autoprolong',
  prepis: 'Prepis',
  nove_oom: 'Nové OOM',
};

export const VIWA_PACKAGE: Record<string, string> = { basic: 'Basic', plus: 'Plus', pro: 'Pro' };

/** Zložka ceny zmluvy (0025). */
export const PRICE_SLOT: Record<string, string> = {
  komodita: 'Komodita',
  poplatok_om: 'Mesačná platba za OM',
  zem: 'ZEM',
  program: 'Program (VBattery)',
  viwa_ucet: 'VIWA – za účet',
  viwa_kw: 'VIWA – za kW',
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
  biomasa: 'Biomasa',
  plyn: 'Plyn',
  vietor: 'Veterná elektráreň',
  ostatne_oze: 'Ostatné OZE',
};
// Kategória zdroja podľa zákona (zadanie OOM čl. 7; 0013)
export const SOURCE_CATEGORY: Record<string, string> = {
  maly_zdroj: 'Malý zdroj',
  lokalny_zdroj: 'Lokálny zdroj',
  vyrobny_zdroj: 'Výrobný zdroj',
};
export const VOLTAGE_LEVEL: Record<string, string> = { nn: 'NN', vn: 'VN', vvn: 'VVN' };
export const DEVICE_TYPE: Record<string, string> = {
  striedac: 'Striedač',
  panely: 'Panely',
  bateria: 'Batéria',
  tepelne_cerpadlo: 'Tepelné čerpadlo',
  wallbox: 'Wallbox',
};
// Stav väzby OOM – zákazník a dôvod jej ukončenia
export const LINK_END_REASON: Record<string, string> = { odchod: 'odchod k inému dodávateľovi', zrusenie: 'zrušenie', prepis: 'prepis' };

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

// Modul 3 Produkty a cenníky
export const PRODUCT_CATEGORY: Record<string, string> = {
  dodavka_domacnost: 'Dodávka – domácnosti',
  dodavka_maly_podnik: 'Dodávka – malé podniky',
  dodavka_firma: 'Dodávka – firmy',
  vykup_firma: 'Výkup – firmy',
  velkoobchod: 'Veľkoobchod',
  zem: 'Služba – domácnosti',
  vbattery: 'Virtuálna batéria',
  viwa: 'Virtuálna peňaženka',
  instalacia_fve: 'Inštalácia FVE',
  poplatok: 'Poplatok – firmy',
};

export const PRICE_MODEL: Record<string, string> = {
  cennik: 'Cenník',
  fix: 'FIX',
  spot_plus_eur: 'SPOT + aditív €',
  spot_minus_eur: 'SPOT − aditív €',
  spot_minus_pct: 'SPOT − aditív %',
  cena_diela: 'Pevná cena za dielo',
};

export const TARIFF_TYPE: Record<string, string> = {
  jednotarif: 'jednotarif',
  dvojtarif: 'dvojtarif',
  nemerany: 'nemeraný',
  netyka_sa: '',
};

export const PRODUCT_STATUS: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  predava_sa: { label: 'Predáva sa', tone: 'positive', live: true },
  dobieha: { label: 'Dobieha', tone: 'warning' },
  ukonceny: { label: 'Ukončený', tone: 'neutral' },
};

// Stav verzie cenníka: uložený Návrh / Schválená / Nahradená, zobrazený podľa dátumu (Europe/Bratislava, databáza).
export const VERSION_STATE: Record<string, { label: string; tone: Tone; live?: boolean }> = {
  navrh: { label: 'Návrh', tone: 'warning' },
  buduca: { label: 'Budúca', tone: 'info' },
  platna: { label: 'Platná', tone: 'positive', live: true },
  ukoncena: { label: 'Ukončená', tone: 'neutral' },
};

/** Skupiny katalógu (obrazovka 22) – rovnaké kódy ako ?skupina= v API. */
export const PRODUCT_GROUPS: [string, string][] = [
  ['', 'Všetky'],
  ['dodavka', 'Dodávka'],
  ['vykup', 'Výkup'],
  ['sluzby', 'Služby a programy'],
  ['instalacia', 'Inštalácia'],
];
