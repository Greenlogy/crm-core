// HTML ponuky (dizajn 35) z dokumentu, ktorý skladá databáza (offer_document, 0039): titulná strana, ponuka
// (sekcie šablóny s tabuľkou cien), referencie s energetickým mixom, príbehom a víziou, záväzná objednávka
// (VIWA: prijatie ponuky). Texty, premenné aj ceny sú už vyplnené v databáze – tu sa iba skladá vzhľad.
// Obrázky sa vkladajú ako data: URI, takže prehliadač nič nesťahuje z CRM ani z internetu.
// Zdieľa ho Worker crm-core (náhľad, PDF pri odoslaní) aj crm-ponuka (potvrdenie akceptácie).

export type DocPrice = { year: number | null; text: string; text_vat: string | null };
export type DocRow = {
  product: string;
  voltage_group: 'nn' | 'vn';
  oom_count: number;
  volume_mwh: number | string;
  price_model: string;
  vat_rate: number | string | null;
  prices: DocPrice[];
};
export type DocVariant = {
  id: string;
  letter: string;
  name: string;
  label: string;
  price_kind: string;
  period: string;
  flexibility: string;
  volume_text: string;
  spot: boolean;
  rows: DocRow[];
  viwa: { package: string; monthly_fee: number | string | null; fee_kw: number | string | null; coefficient: number | string | null; power_kw: number | string | null } | null;
  household: { fees_month: number | string; cost_year: number | string | null; cost_year_total: number | string | null; vat_rate: number | string | null } | null;
  terms?: string;
  terms_sha256?: string;
};
export type OfferDocument = {
  offer: { id: string; display_number: string; kind: 'dodavka' | 'vykup' | 'viwa'; language: 'sk' | 'en'; household: boolean; sent_at: string | null; valid_until: string };
  template: { id: string; version: number; status: string; order_title: string; order_text: string } | null;
  vars: Record<string, string | null>;
  sections: { key: string; nadpis: string; text: string }[];
  variants: DocVariant[];
  acceptance: { variant: string; method: string; channel: string | null; accepted_at: string; signer_name: string; signer_function: string } | null;
};
export type OfferAssets = Partial<Record<'titulna' | 'referencie_zakaznici' | 'referencie_partneri' | 'energeticky_mix', string>>; // data: URI
export type AcceptanceProof = { accepted_at: string; signer_name: string; signer_function: string; ip?: string | null; terms_sha256?: string | null; method: string; channel?: string | null };

const L = {
  sk: {
    title: 'Cenová ponuka', for: 'pre spoločnosť', forPerson: 'pre', variant: 'Variant', product: 'Produkt', price: 'Cena',
    nn: 'NN', vn: 'VN', om: 'OM', vat: 's DPH', fees: 'Mesačné poplatky', costYear: 'Odhad ročných nákladov na komoditu a poplatky',
    package: 'Balík', monthlyFee: 'Mesačný poplatok za účet', feeKw: 'Poplatok za odchýlku', coefficient: 'Koeficient výmeny',
    references: 'Prehľad referencií', page: 'strana', of: 'z', place: 'Miesto a dátum', signature: 'Meno, funkcia a podpis oprávnenej osoby',
    electronic: 'Elektronicky potvrdené', manual: 'Zaznačené v CRM',
    channels: { telefon: 'telefonicky', email: 'e-mailom', osobne: 'osobne', podpisane_pdf: 'podpísaná ponuka' } as Record<string, string>, ip: 'IP', hash: 'odtlačok znenia', chooseVariant: 'zvolený variant (označte)',
    draft: 'NÁVRH ŠABLÓNY – NEODOSIELAŤ', preview: 'NÁHĽAD',
  },
  en: {
    title: 'Price offer', for: 'for', forPerson: 'for', variant: 'Variant', product: 'Product', price: 'Price',
    nn: 'LV', vn: 'MV', om: 'MP', vat: 'incl. VAT', fees: 'Monthly fees', costYear: 'Estimated annual cost of energy and fees',
    package: 'Package', monthlyFee: 'Monthly account fee', feeKw: 'Imbalance fee', coefficient: 'Exchange coefficient',
    references: 'References', page: 'page', of: 'of', place: 'Place and date', signature: 'Name, position and signature of the authorised person',
    electronic: 'Confirmed electronically', manual: 'Recorded in CRM',
    channels: { telefon: 'by phone', email: 'by e-mail', osobne: 'in person', podpisane_pdf: 'signed offer' } as Record<string, string>, ip: 'IP', hash: 'text fingerprint', chooseVariant: 'chosen variant (tick)',
    draft: 'TEMPLATE DRAFT – DO NOT SEND', preview: 'PREVIEW',
  },
} as const;

export const esc = (v: unknown) =>
  String(v ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
const paras = (text: string) =>
  text.split('\n').map((l) => l.trim()).filter(Boolean).map((l) => `<p>${esc(l)}</p>`).join('');
const num = (v: number | string | null | undefined, lang: 'sk' | 'en', dec = 2) =>
  v === null || v === undefined || v === '' ? '–'
    : new Intl.NumberFormat(lang === 'sk' ? 'sk-SK' : 'en-GB', { minimumFractionDigits: dec, maximumFractionDigits: dec }).format(Number(v));
export const stamp = (iso: string, lang: 'sk' | 'en', seconds = false) =>
  new Intl.DateTimeFormat(lang === 'sk' ? 'sk-SK' : 'en-GB', {
    timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit',
    ...(seconds ? { second: '2-digit' } : {}),
  }).format(new Date(iso));

/** Tabuľka cien jedného variantu: riadky zlúčené podľa produktu, napätia a cien (bez EIC). */
function variantTable(v: DocVariant, doc: OfferDocument): string {
  const lang = doc.offer.language;
  const t = L[lang];
  const head = `<div class="vt-head">${esc(t.variant)} ${esc(v.letter)} – ${esc(v.name)}, ${esc(v.period)}</div>`;
  if (v.viwa) {
    return `${head}<table class="prices"><tbody>
      <tr><td>${esc(t.package)}</td><td class="r">${esc(v.viwa.package)}</td></tr>
      <tr><td>${esc(t.monthlyFee)}</td><td class="r">${num(v.viwa.monthly_fee, lang)} €</td></tr>
      <tr><td>${esc(t.feeKw)}</td><td class="r">${num(v.viwa.fee_kw, lang)} €/kW</td></tr>
      <tr><td>${esc(t.coefficient)}</td><td class="r">${num(v.viwa.coefficient, lang)}</td></tr>
    </tbody></table>`;
  }
  const years = [...new Set(v.rows.flatMap((r) => r.prices.map((p) => p.year)))].sort((a, b) => (a ?? 0) - (b ?? 0));
  const vat = doc.offer.household && v.rows.some((r) => r.prices.some((p) => p.text_vat));
  const cols = years.map((y) => `<th class="r">${y === null ? esc(t.price) : y}</th>`).join('');
  const body = v.rows
    .map((r) => {
      const label = `${esc(r.product)} – ${esc(t[r.voltage_group])}${r.oom_count > 1 ? ` (${r.oom_count} ${esc(t.om)})` : ''}`;
      const cells = years
        .map((y) => {
          const p = r.prices.find((x) => x.year === y);
          return `<td class="r">${p ? esc(p.text) : '–'}${vat && p?.text_vat ? `<div class="vat">${esc(p.text_vat)} ${esc(t.vat)}</div>` : ''}</td>`;
        })
        .join('');
      return `<tr><td>${label}</td>${cells}</tr>`;
    })
    .join('');
  const hh = v.household
    ? `<div class="hh">${esc(t.fees)}: ${num(v.household.fees_month, lang)} € · ${esc(t.costYear)}: ${num(v.household.cost_year_total, lang)} €${
        v.household.vat_rate ? ` (${num(Number(v.household.cost_year_total) * (1 + Number(v.household.vat_rate) / 100), lang)} € ${esc(t.vat)})` : ''
      }</div>`
    : '';
  return `${head}<table class="prices"><thead><tr><th>${esc(t.product)}</th>${cols}</tr></thead><tbody>${body}</tbody></table>${hh}`;
}

function section(doc: OfferDocument, key: string): string {
  const s = doc.sections.find((x) => x.key === key);
  if (!s || (!s.text && !s.nadpis)) return '';
  if (key === 'cenova_ponuka') {
    const [before, after = ''] = s.text.split('«tabuľka variantov»');
    return `<h2>${esc(s.nadpis)}</h2>${paras(before)}${doc.variants.map((v) => variantTable(v, doc)).join('')}${paras(after)}`;
  }
  return `${s.nadpis ? `<h2>${esc(s.nadpis)}</h2>` : ''}${paras(s.text)}`;
}

const CSS = `
@page { size: A4; margin: 16mm 18mm 18mm; }
@page :first { margin: 0; }
* { box-sizing: border-box; }
body { margin: 0; font-family: "Helvetica Neue", Arial, "Liberation Sans", "DejaVu Sans", sans-serif; font-size: 8.8pt; line-height: 1.4; color: #0f172a; }
p { margin: 0 0 3pt; }
h1 { font-size: 20pt; color: #1b4f8a; margin: 0 0 4pt; }
h2 { font-size: 10pt; color: #1b4f8a; margin: 12pt 0 4pt; text-transform: none; }
.page { page-break-after: always; }
.page:last-child { page-break-after: auto; }
.cover { position: relative; width: 210mm; height: 297mm; overflow: hidden; background: #dff3fb; }
.cover img { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; }
.cover .t { position: absolute; top: 24mm; left: 20mm; right: 20mm; color: #0d3b66; }
.cover .t h1 { font-size: 26pt; color: #0d3b66; }
.cover .t .for { font-size: 12pt; }
.cover .t .name { font-size: 16pt; font-weight: 700; margin-top: 2pt; }
.head { display: flex; justify-content: space-between; gap: 12pt; margin-bottom: 8pt; }
.head .sup { text-align: right; font-size: 8pt; color: #334155; white-space: pre; }
.head .no { font-size: 9pt; color: #334155; }
.vt-head { font-weight: 700; margin: 8pt 0 2pt; }
table.prices { width: 100%; border-collapse: collapse; margin-bottom: 4pt; }
table.prices th { background: #eef2f7; text-align: left; font-weight: 600; padding: 3pt 5pt; font-size: 8.5pt; }
table.prices td { padding: 3pt 5pt; border-bottom: 0.5pt solid #e2e8f0; font-variant-numeric: tabular-nums; }
.r { text-align: right; white-space: nowrap; }
.vat { font-size: 7.5pt; color: #64748b; }
.hh { font-size: 8.5pt; color: #334155; margin: 2pt 0 6pt; }
.prepared { margin-top: 16pt; padding-top: 6pt; border-top: 0.5pt solid #cbd5e1; font-size: 8.5pt; color: #334155; }
.refs img { width: 100%; margin: 6pt 0; }
.story { display: flex; gap: 14pt; align-items: center; margin-top: 10pt; }
.story img { width: 62mm; }
.footer-note { margin-top: 18pt; color: #1b4f8a; font-weight: 600; font-size: 8.5pt; }
.order h1 { text-align: center; font-size: 12pt; }
.order .vars { margin: 8pt 0; }
.order .choice { margin: 6pt 0; }
.order .box { margin-top: 12pt; background: #eef2f7; border-radius: 4pt; padding: 8pt 10pt; font-size: 8.5pt; }
.sign { display: flex; gap: 20pt; margin-top: 28pt; }
.sign div { flex: 1; border-top: 0.5pt solid #64748b; padding-top: 3pt; font-size: 8pt; color: #475569; }
.watermark { position: fixed; top: 45%; left: 0; right: 0; text-align: center; font-size: 34pt; color: rgba(180, 35, 24, 0.12); transform: rotate(-24deg); }
`;

/** Strana záväznej objednávky: pri ponuke voľba variantu a miesto na podpis; pri potvrdení zvolený variant a údaje akceptácie. */
export function orderPage(doc: OfferDocument, proof: AcceptanceProof | null, acceptedVariantLabel: string | null, termsText: string | null): string {
  if (!doc.template) return '';
  const lang = doc.offer.language;
  const t = L[lang];
  let body: string;
  if (termsText) {
    // uložené znenie (prvý riadok je nadpis)
    body = paras(termsText.split('\n').slice(1).join('\n'));
  } else {
    const label = acceptedVariantLabel ?? `____ (${t.chooseVariant}: ${doc.variants.map((v) => `☐ ${v.label}`).join('  ')})`;
    body = paras(doc.template.order_text.split('«variant»').join(label));
  }
  const block = proof
    ? `<div class="box"><strong>${esc(proof.method === 'klik' ? t.electronic : t.manual)}${proof.channel ? ` (${esc(t.channels[proof.channel] ?? proof.channel)})` : ''}</strong> ${esc(stamp(proof.accepted_at, lang, true))} · ${esc(proof.signer_name)}, ${esc(proof.signer_function)}${
        proof.ip ? ` · ${t.ip} ${esc(proof.ip)}` : ''}${proof.terms_sha256 ? ` · ${t.hash} ${esc(proof.terms_sha256)}` : ''}</div>`
    : `<div class="sign"><div>${esc(t.place)}</div><div>${esc(t.signature)}</div></div>`;
  return `<section class="page order"><h1>${esc(doc.template.order_title)}</h1>${body}${block}</section>`;
}

/** Celé PDF ponuky (4 časti). Pri návrhu šablóny alebo neodoslanej ponuke vodotlač. */
export function offerHtml(doc: OfferDocument, assets: OfferAssets, opts: { watermark?: 'preview' | 'draft' | null } = {}): string {
  const lang = doc.offer.language;
  const t = L[lang];
  const name = doc.vars['názov'] ?? '';
  const head = doc.sections.find((s) => s.key === 'hlavicka');
  const [subtitle = '', supplier = ''] = (head?.text ?? '').split('\n');
  const cover = `<section class="page cover">${assets.titulna ? `<img src="${assets.titulna}" alt="">` : ''}
    <div class="t"><h1>${esc(t.title)}</h1><div class="for">${esc(doc.offer.household ? t.forPerson : t.for)}</div><div class="name">${esc(name)}</div></div></section>`;
  const offerPage = `<section class="page">
    <div class="head"><div><h1>${esc(t.title.toUpperCase())}</h1><div class="no">${esc(head?.nadpis.replace(/^[^·]*·\s*/, '') ?? doc.offer.display_number)}</div>
      <div class="no">${esc(subtitle)}</div></div><div class="sup">${esc(supplier.replace(/, (?=\d{3} \d{2}|Slovensk|Slovak|0\d|\+)/g, '\n').replace(/^([^,]+), /, '$1\n'))}</div></div>
    ${['udaje', 'predmet', 'cenova_ponuka', 'podmienky', 'platnost', 'vseobecne'].map((k) => section(doc, k)).join('')}
    ${(() => { const s = doc.sections.find((x) => x.key === 'spracoval'); return s ? `<div class="prepared">${esc(s.text)}</div>` : ''; })()}
  </section>`;
  const story = doc.sections.find((s) => s.key === 'pribeh');
  const vision = doc.sections.find((s) => s.key === 'vizia');
  const foot = doc.sections.find((s) => s.key === 'paticka');
  const refs = `<section class="page refs"><h2>${esc(t.references.toUpperCase())}</h2>
    ${assets.referencie_zakaznici ? `<img src="${assets.referencie_zakaznici}" alt="">` : ''}
    ${assets.referencie_partneri ? `<img src="${assets.referencie_partneri}" alt="">` : ''}
    <div class="story">${assets.energeticky_mix ? `<img src="${assets.energeticky_mix}" alt="">` : ''}<div>
      ${story ? `<h2>${esc(story.nadpis.toUpperCase())}</h2>${paras(story.text)}` : ''}
      ${vision ? `<h2>${esc(vision.nadpis.toUpperCase())}</h2>${paras(vision.text)}` : ''}</div></div>
    ${foot ? `<div class="footer-note">${esc(foot.text)}</div>` : ''}</section>`;
  const wm = opts.watermark ? `<div class="watermark">${esc(opts.watermark === 'draft' ? t.draft : t.preview)}</div>` : '';
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><title>${esc(doc.offer.display_number)}</title><style>${CSS}</style></head>
    <body>${wm}${cover}${offerPage}${refs}${orderPage(doc, null, null, null)}</body></html>`;
}

/** Potvrdenie akceptácie: strana záväznej objednávky so zvoleným variantom a údajmi akceptácie. */
export function confirmationHtml(doc: OfferDocument, proof: AcceptanceProof, variantLabel: string, termsText: string | null): string {
  return `<!doctype html><html lang="${doc.offer.language}"><head><meta charset="utf-8"><title>${esc(doc.offer.display_number)}</title><style>${CSS}
    @page :first { margin: 16mm 18mm 18mm; }</style></head><body>${orderPage(doc, proof, variantLabel, termsText)}</body></html>`;
}

/** Päta PDF: číslo ponuky a strana (Chromium vyplní pageNumber / totalPages). */
export function pdfFooter(doc: OfferDocument): string {
  const t = L[doc.offer.language];
  return `<div style="width:100%;font-size:7pt;color:#64748b;padding:0 18mm;display:flex;justify-content:space-between;font-family:Arial,sans-serif">
    <span>${esc(doc.offer.display_number)}</span><span>${t.page} <span class="pageNumber"></span> ${t.of} <span class="totalPages"></span></span></div>`;
}
