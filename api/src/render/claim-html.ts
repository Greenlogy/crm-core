// HTML provízneho listu (modul 5, F7) pre PDF cez Browser Run – v štýle PDF ponuky, bez obrázkov, iba logo spoločnosti
// (Nastavenia → Spoločnosť; bez loga textový logotyp). Farby podľa dizajn manuálu Greenlogy 2021: zelená #05D695,
// modrá #13689E; písmo Campton nie je v prehliadači – ako v ponuke Helvetica / Arial.
// Dokument skladá databáza (commission_claim_document, 0055); zrušený list = rovnaký obsah s pečiatkou ZRUŠENÉ.

export type ClaimItem = {
  deal_name: string | null;
  customer_name: string | null;
  kind: 'provizia' | 'vyrovnanie';
  won_at: string | null;
  duration_years: number | null;
  volume_mwh: string | number | null;
  base_eur: string | number;
  pct: string | number;
  amount_eur: string | number;
  source: 'crm' | 'sales_portal';
};
export type ClaimDocument = {
  claim: {
    id: string;
    number: string;
    created_at: string;
    total_eur: string | number;
    by_duration: Record<string, string | number>;
    source: string;
    created_by: string | null;
    voided_at: string | null;
    voided_by: string | null;
    void_reason: string | null;
  };
  seller: { name: string; email: string; position: string | null } | null;
  org: {
    legal_name: string;
    address: string | null;
    reg_no: string | null;
    tax_no: string | null;
    vat_no: string | null;
    email: string | null;
    web: string | null;
    logo: { mime: string; data: string } | null;
  } | null;
  items: ClaimItem[];
};

const GREEN = '#05D695';
const BLUE = '#13689E';
const INK = '#0f172a';

const esc = (s: string | null | undefined) =>
  (s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
const nf = (n: string | number | null | undefined, d: number) =>
  n === null || n === undefined || n === '' ? '–'
    : new Intl.NumberFormat('sk-SK', { minimumFractionDigits: d, maximumFractionDigits: d }).format(Number(n)).replace(/ /g, ' ');
const day = (iso: string | null) => {
  if (!iso) return '–';
  const d = new Date(iso.length === 10 ? `${iso}T12:00:00Z` : iso);
  return new Intl.DateTimeFormat('sk-SK', { day: 'numeric', month: 'numeric', year: 'numeric', timeZone: 'Europe/Bratislava' }).format(d).replace(/\s/g, ' ');
};
export const durationLabel = (key: string) =>
  key === 'neurcito' ? 'na neurčito (prvých 12 mesiacov)' : key === '1' ? '1 rok' : Number(key) < 5 ? `${key} roky` : `${key} rokov`;

function logo(doc: ClaimDocument): string {
  const l = doc.org?.logo;
  if (l && (l.mime === 'image/png' || l.mime === 'image/svg+xml')) {
    return `<img class="logo" src="data:${l.mime};base64,${l.data}" alt="${esc(doc.org?.legal_name)}">`;
  }
  // textový logotyp: „greenlo“ a „y“ zelené, „g“ modré
  return `<span class="wordmark">greenlo<span style="color:${BLUE}">g</span>y</span>`;
}

const CSS = `
@page { size: A4; margin: 16mm 18mm 20mm; }
* { box-sizing: border-box; }
body { margin: 0; font-family: "Helvetica Neue", Arial, "Liberation Sans", "DejaVu Sans", sans-serif; font-size: 9pt; line-height: 1.4; color: ${INK}; }
.top { display: flex; justify-content: space-between; align-items: flex-start; padding-bottom: 10pt; border-bottom: 2pt solid ${GREEN}; }
.logo { height: 26pt; }
.wordmark { font-size: 24pt; font-weight: 700; letter-spacing: -0.5pt; color: ${GREEN}; }
.title { text-align: right; }
.title h1 { margin: 0; font-size: 17pt; color: ${BLUE}; }
.title .no { font-size: 11pt; font-weight: 700; margin-top: 2pt; }
.title .dt { color: #475569; margin-top: 1pt; }
.parties { display: flex; gap: 24pt; margin: 12pt 0 10pt; }
.parties div { flex: 1; }
.lbl { font-size: 7.5pt; text-transform: uppercase; letter-spacing: 0.4pt; color: #64748b; margin-bottom: 2pt; }
.parties .name { font-weight: 700; font-size: 10pt; }
h2 { font-size: 10pt; color: ${BLUE}; margin: 12pt 0 4pt; display: flex; justify-content: space-between; }
h2 span { color: ${INK}; font-weight: 600; }
table { width: 100%; border-collapse: collapse; }
th { background: #eef6f3; text-align: left; font-weight: 600; padding: 3pt 5pt; font-size: 8pt; }
td { padding: 3pt 5pt; border-bottom: 0.5pt solid #e2e8f0; vertical-align: top; }
.r { text-align: right; white-space: nowrap; font-variant-numeric: tabular-nums; }
.sub { font-size: 7.5pt; color: #64748b; }
.total { margin-top: 12pt; display: flex; justify-content: flex-end; }
.total div { border-top: 1.5pt solid ${GREEN}; padding-top: 4pt; font-size: 12pt; font-weight: 700; }
.note { margin-top: 14pt; font-size: 8pt; color: #475569; }
.sign { display: flex; gap: 28pt; margin-top: 34pt; }
.sign div { flex: 1; border-top: 0.5pt solid #64748b; padding-top: 3pt; font-size: 8pt; color: #475569; }
.void { position: fixed; top: 95mm; left: 0; right: 0; text-align: center; transform: rotate(-24deg); font-size: 64pt; font-weight: 800;
        color: rgba(180, 35, 24, 0.22); border: 5pt solid rgba(180, 35, 24, 0.22); width: 120mm; margin: 0 auto; letter-spacing: 6pt; }
.voidbox { margin-top: 10pt; padding: 6pt 8pt; border: 1pt solid #b42318; color: #b42318; font-size: 8.5pt; border-radius: 3pt; }
`;

/** HTML listu; zrušený list (voided) dostane pečiatku ZRUŠENÉ a dôvod. */
export function claimHtml(doc: ClaimDocument, voided: boolean): string {
  const k = doc.claim;
  const groups = new Map<string, ClaimItem[]>();
  for (const i of doc.items) {
    const key = i.duration_years === null ? 'neurcito' : String(i.duration_years);
    groups.set(key, [...(groups.get(key) ?? []), i]);
  }
  const order = [...groups.keys()].sort((a, b) => (a === 'neurcito' ? 1 : b === 'neurcito' ? -1 : Number(a) - Number(b)));
  const o = doc.org;
  const orgLines = [o?.address, [o?.reg_no && `IČO ${o.reg_no}`, o?.tax_no && `DIČ ${o.tax_no}`, o?.vat_no && `IČ DPH ${o.vat_no}`].filter(Boolean).join(' · ')]
    .filter(Boolean).map((l) => `<div>${esc(l as string)}</div>`).join('');
  const tables = order.map((key) => {
    const rows = groups.get(key)!;
    const sum = rows.reduce((s, r) => s + Number(r.amount_eur), 0);
    return `<h2>Trvanie zmluvy: ${esc(durationLabel(key))}<span>medzisúčet ${nf(sum, 2)} €</span></h2>
      <table><thead><tr><th>Obchod · zákazník</th><th>Vyhraté</th><th class="r">Objem [MWh]</th><th class="r">Prid. hodnota [€]</th>
      <th class="r">%</th><th class="r">Provízia [€]</th></tr></thead><tbody>
      ${rows.map((r) => `<tr><td>${esc(r.deal_name ?? '–')}${r.kind === 'vyrovnanie' ? ' <span class="sub">(vyrovnanie)</span>' : ''}
        ${r.source === 'sales_portal' ? ' <span class="sub">(Sales portál)</span>' : ''}<div class="sub">${esc(r.customer_name ?? '')}</div></td>
        <td>${day(r.won_at)}</td><td class="r">${nf(r.volume_mwh, 1)}</td><td class="r">${nf(r.base_eur, 2)}</td>
        <td class="r">${nf(r.pct, 0)}</td><td class="r">${nf(r.amount_eur, 2)}</td></tr>`).join('')}
      </tbody></table>`;
  }).join('');
  return `<!doctype html><html lang="sk"><head><meta charset="utf-8"><title>${esc(k.number)}</title><style>${CSS}</style></head><body>
  ${voided ? '<div class="void">ZRUŠENÉ</div>' : ''}
  <div class="top">${logo(doc)}<div class="title"><h1>Provízny list</h1><div class="no">${esc(k.number)}</div>
    <div class="dt">${day(k.created_at)}</div></div></div>
  <div class="parties">
    <div><div class="lbl">Spoločnosť</div><div class="name">${esc(o?.legal_name ?? '')}</div>${orgLines}</div>
    <div><div class="lbl">Obchodník</div><div class="name">${esc(doc.seller?.name ?? '')}</div>
      ${doc.seller?.position ? `<div>${esc(doc.seller.position)}</div>` : ''}<div>${esc(doc.seller?.email ?? '')}</div></div>
  </div>
  ${voided ? `<div class="voidbox"><strong>List zrušil ${esc(k.voided_by ?? '')} ${day(k.voided_at)}.</strong> Dôvod: ${esc(k.void_reason ?? '')}.
    Provízie sa vrátili na „Čaká na uplatnenie“; číslo ${esc(k.number)} sa znova nepoužije.</div>` : ''}
  ${tables}
  <div class="total"><div>Spolu provízia: ${nf(k.total_eur, 2)} €</div></div>
  <div class="note">Provízia = pridaná hodnota obchodu (zmluvy obchodu) × percento obchodníka platné v deň Vyhraté; pri zmluve na neurčito
    prvých 12 mesiacov dodávky. Vyrovnanie = rozdiel po zmene obchodu po predchádzajúcom uplatnení.
    Uplatnil: ${esc(k.created_by ?? '')}, ${day(k.created_at)}.</div>
  <div class="sign"><div>Obchodník</div><div>Za ${esc(o?.legal_name ?? 'spoločnosť')}</div></div>
  </body></html>`;
}

export function claimFooter(number: string): string {
  return `<div style="width:100%;font-size:7pt;color:#64748b;padding:0 18mm;display:flex;justify-content:space-between;font-family:Arial,sans-serif">
    <span>${esc(number)}</span><span>Strana <span class="pageNumber"></span> z <span class="totalPages"></span></span></div>`;
}
