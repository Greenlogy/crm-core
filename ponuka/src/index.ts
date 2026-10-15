// Worker crm-ponuka – verejná stránka ponuky (dizajn 36; návrh DB časť 5; migrácie 0039, 0040).
// Mimo Cloudflare Access: prístup iba cez neuhádnuteľný odkaz /p/{token} (32 bajtov, base64url). Databáza dostane
// iba SHA-256 tokenu a vráti jednu ponuku (funkcie v schéme verejne, rola crm_public bez prístupu k tabuľkám).
// Stránka je bez JavaScriptu (akceptácia formulárom), s prísnou CSP, bez sledovania; IP sa zapíše iba pri akceptácii.
// Prepínač SK / EN mení iba popisky stránky – právny text ostáva v jazyku ponuky.

import postgres from 'postgres';
import { confirmationHtml, esc, type OfferDocument, pdfFooter, stamp } from '../../api/src/render/offer-html';
import { htmlToPdf, sha256Hex } from '../../api/src/render/pdf';

type Env = {
  HYPERDRIVE: Hyperdrive;
  DOCS: R2Bucket;
  BROWSER: Fetcher;
  RL_VIEW: RateLimit;
  RL_BAD: RateLimit;
  RL_ACCEPT: RateLimit;
};
type View = {
  mode: 'aktivna' | 'len_citanie' | 'neplatny';
  reason?: 'akceptovana' | 'nahradena' | 'zamietnuta' | 'vyprsana' | null;
  document?: OfferDocument;
  seller?: { name: string | null; job_title: string | null; email: string | null; phone: string | null };
  pdf?: boolean;
};

const TOKEN = /^[A-Za-z0-9_-]{43}$/;
type AcceptResult = {
  ok: boolean; repeated: boolean; acceptance_id: string; accepted_at: string; variant: string; method: string; channel: string | null;
  signer_name: string; signer_function: string; ip: string | null; terms_text: string; terms_sha256: string;
  confirmation_key: string; confirmation_stored: boolean; document: OfferDocument;
};
const dateOnly = (iso: string, lang: 'sk' | 'en') =>
  new Intl.DateTimeFormat(lang === 'sk' ? 'sk-SK' : 'en-GB', { timeZone: 'Europe/Bratislava', day: 'numeric', month: 'numeric', year: 'numeric' }).format(new Date(iso));

const T = {
  sk: {
    offer: 'Cenová ponuka', validUntil: 'Ponuka platí do', supply: 'Dodávka zelenej elektriny pre', purchase: 'Výkup elektriny od',
    viwa: 'Služba Green ViWA pre', places: 'odberné miesta', place1: 'odberné miesto', yearly: 'MWh ročne', planned: 'plánovaný objem',
    noVat: 'ceny bez DPH a regulovaných poplatkov', variant: 'Variant', period: 'Obdobie', flex: 'Flexibilita', pdf: 'Ponuka v PDF',
    pdfSub: 'podmienky, platobné podmienky, referencie a znenie záväznej objednávky', download: 'Stiahnuť PDF',
    acceptTitle: 'Prijatie ponuky – Záväzná objednávka', acceptTitleViwa: 'Prijatie ponuky', name: 'Meno a priezvisko', func: 'Funkcia',
    chosen: 'Zvolený variant', confirm: 'Som oprávnený konať za spoločnosť a súhlasím so znením', confirmOrder: 'Záväznej objednávky',
    confirmViwa: 'prijatia ponuky', button: 'Záväzne objednávam', buttonViwa: 'Prijímam ponuku',
    store: 'Uložíme čas, meno, funkciu, IP adresu a znenie, ktoré ste videli.', showTerms: 'Zobraziť celé znenie',
    manual: 'Radšej podpíšete ručne? Stiahnite PDF, podpíšte stranu so záväznou objednávkou a pošlite ju obchodníkovi.',
    accepted: 'Akceptované', acceptedBy: 'akceptoval(a)', confirmation: 'Potvrdenie v PDF', expired: 'Platnosť ponuky uplynula.',
    replaced: 'Táto ponuka bola nahradená novšou verziou.', rejected: 'Ponuka bola odmietnutá.', invalid: 'Odkaz už neplatí',
    invalidSub: 'Ponuka s týmto odkazom neexistuje alebo jej platnosť uplynula. Obráťte sa na svojho obchodníka.',
    tooMany: 'Príliš veľa pokusov. Skúste to o chvíľu znova.', ok: 'Ďakujeme, ponuku ste prijali.',
    err_zmenene: 'Znenie ponuky sa medzitým zmenilo – obnovte stránku a skúste znova.', err_neplatna: 'Ponuku už nemožno prijať (platnosť uplynula alebo ponuka neplatí).',
    err_akceptovana: 'Ponuka už bola prijatá.', err_udaje: 'Vyplňte meno, funkciu a zvoľte variant.', err_potvrdenie: 'Potvrďte, že ste oprávnený konať za spoločnosť.',
    err_chyba: 'Prijatie sa nepodarilo. Skúste to znova alebo kontaktujte obchodníka.', seller: 'obchodník',
  },
  en: {
    offer: 'Price offer', validUntil: 'Offer valid until', supply: 'Green electricity supply for', purchase: 'Electricity purchase from',
    viwa: 'Green ViWA service for', places: 'metering points', place1: 'metering point', yearly: 'MWh per year', planned: 'planned volume',
    noVat: 'prices excl. VAT and regulated charges', variant: 'Variant', period: 'Period', flex: 'Flexibility', pdf: 'Offer as PDF',
    pdfSub: 'terms, payment terms, references and the binding order', download: 'Download PDF',
    acceptTitle: 'Acceptance – Binding order', acceptTitleViwa: 'Acceptance of the offer', name: 'Full name', func: 'Position',
    chosen: 'Chosen variant', confirm: 'I am authorised to act for the company and agree with the text of the', confirmOrder: 'Binding Order',
    confirmViwa: 'acceptance', button: 'Place binding order', buttonViwa: 'Accept offer',
    store: 'We store the time, name, position, IP address and the exact text you saw.', showTerms: 'Show full text',
    manual: 'Prefer to sign by hand? Download the PDF, sign the binding order page and send it to your sales contact.',
    accepted: 'Accepted', acceptedBy: 'accepted by', confirmation: 'Confirmation as PDF', expired: 'This offer has expired.',
    replaced: 'This offer has been replaced by a newer version.', rejected: 'This offer was declined.', invalid: 'This link is no longer valid',
    invalidSub: 'The offer for this link does not exist or has expired. Please contact your sales representative.',
    tooMany: 'Too many attempts. Please try again shortly.', ok: 'Thank you, you have accepted the offer.',
    err_zmenene: 'The offer text has changed – please reload the page and try again.', err_neplatna: 'The offer can no longer be accepted (expired or invalid).',
    err_akceptovana: 'The offer has already been accepted.', err_udaje: 'Please fill in your name and position and choose a variant.',
    err_potvrdenie: 'Please confirm that you are authorised to act for the company.', err_chyba: 'Acceptance failed. Please try again or contact your sales representative.',
    seller: 'sales',
  },
} as const;
type Lang = keyof typeof T;
type ErrKey = 'zmenene' | 'neplatna' | 'akceptovana' | 'udaje' | 'potvrdenie' | 'chyba';

const SECURITY_HEADERS: Record<string, string> = {
  'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; img-src data:; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
  'Referrer-Policy': 'no-referrer',
  'X-Robots-Tag': 'noindex, nofollow',
  'X-Content-Type-Options': 'nosniff',
  'Cache-Control': 'no-store',
};
const html = (body: string, status = 200) =>
  new Response(body, { status, headers: { 'Content-Type': 'text/html; charset=utf-8', ...SECURITY_HEADERS } });

const CSS = `
:root { --ink:#0f172a; --muted:#64748b; --brand:#1a6b4a; --brand-tint:#e8f2ee; --border:#e7e9ec; --page:#f6f7f8; --warn:#fff4e0; --warn-ink:#b45309; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--page); color: var(--ink); font: 15px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, Arial, sans-serif; }
header { background: #fff; border-bottom: 1px solid var(--border); }
.bar { max-width: 860px; margin: 0 auto; padding: 14px 20px; display: flex; justify-content: space-between; align-items: center; }
.logo { font-weight: 700; color: var(--brand); font-size: 18px; text-decoration: none; }
.lang a { margin-left: 8px; padding: 4px 10px; border-radius: 6px; color: var(--muted); text-decoration: none; font-size: 13px; }
.lang a.on { background: #eef0f2; color: var(--ink); font-weight: 600; }
main { max-width: 860px; margin: 0 auto; padding: 24px 20px 48px; }
.kicker { color: var(--muted); font-size: 13px; }
h1 { font-size: 26px; margin: 4px 0; }
.sub { color: var(--muted); font-size: 14px; }
.top { display: flex; justify-content: space-between; gap: 16px; align-items: flex-start; }
.top > div:first-child { flex: 1; min-width: 0; }
@media (max-width: 600px) { .top { flex-direction: column; } }
.valid { background: var(--warn); border: 1px solid #f6d9a8; border-radius: 10px; padding: 10px 14px; }
.valid small { color: var(--warn-ink); display: block; font-size: 12px; }
.valid strong { font-size: 18px; }
.grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 14px; margin: 18px 0; }
.card { background: #fff; border: 1px solid var(--border); border-radius: 12px; padding: 16px; }
label.variant { display: block; cursor: pointer; }
label.variant:has(input:checked) { border-color: var(--brand); box-shadow: 0 0 0 1px var(--brand); }
.vname { font-weight: 600; display: flex; gap: 8px; align-items: center; margin-bottom: 8px; }
.row { display: flex; justify-content: space-between; gap: 12px; padding: 6px 0; border-top: 1px solid var(--border); font-size: 14px; }
.row span:first-child { color: var(--muted); }
.row span:last-child { text-align: right; }
.pdf { display: flex; justify-content: space-between; align-items: center; gap: 12px; margin-bottom: 14px; }
.btn { display: inline-block; padding: 9px 16px; border-radius: 8px; border: 1px solid var(--border); background: #fff; color: var(--ink); text-decoration: none; font: inherit; font-weight: 600; cursor: pointer; }
.btn.primary { background: var(--brand); border-color: var(--brand); color: #fff; }
.form { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin: 12px 0; }
.form label { font-size: 13px; color: var(--muted); display: block; }
input[type=text] { width: 100%; padding: 9px 10px; border: 1px solid var(--border); border-radius: 8px; font: inherit; margin-top: 4px; }
.check { display: flex; gap: 8px; align-items: flex-start; margin: 8px 0 14px; font-size: 14px; }
details { margin: 8px 0; font-size: 13px; }
details pre { white-space: pre-wrap; font: inherit; background: var(--page); padding: 10px; border-radius: 8px; }
.note { color: var(--muted); font-size: 13px; }
.ok { background: var(--brand-tint); color: var(--brand); border-radius: 10px; padding: 12px 14px; margin: 14px 0; font-weight: 600; }
.err { background: #fdecea; color: #b42318; border-radius: 10px; padding: 12px 14px; margin: 14px 0; }
.info { background: #eef0f2; border-radius: 10px; padding: 12px 14px; margin: 14px 0; }
.seller { display: flex; gap: 12px; align-items: center; }
.avatar { width: 40px; height: 40px; border-radius: 50%; background: #eef0f2; display: grid; place-items: center; font-weight: 600; }
@media (max-width: 600px) { h1 { font-size: 21px; } }
`;

function page(lang: Lang, token: string | null, title: string, body: string): string {
  const switcher = token
    ? `<span class="lang"><a class="${lang === 'sk' ? 'on' : ''}" href="/p/${token}?lang=sk">SK</a><a class="${lang === 'en' ? 'on' : ''}" href="/p/${token}?lang=en">EN</a></span>`
    : '';
  return `<!doctype html><html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex, nofollow"><title>${esc(title)}</title><style>${CSS}</style></head>
<body><header><div class="bar"><span class="logo">greenlogy</span>${switcher}</div></header><main>${body}</main></body></html>`;
}

function invalidPage(lang: Lang, status = 404): Response {
  const t = T[lang];
  return html(page(lang, null, t.invalid, `<h1>${esc(t.invalid)}</h1><p class="sub">${esc(t.invalidSub)}</p>`), status);
}

function offerPage(v: View, token: string, lang: Lang, flash: { ok?: boolean; err?: ErrKey }): string {
  const t = T[lang];
  const d = v.document!;
  const ol = d.offer.language;
  const viwa = d.offer.kind === 'viwa';
  const first = d.variants[0];
  const ooms = first ? first.rows.reduce((n, r) => n + Number(r.oom_count), 0) : 0;
  const titleLead = d.offer.kind === 'vykup' ? t.purchase : viwa ? t.viwa : t.supply;
  const active = v.mode === 'aktivna';
  const validText = stamp(d.offer.valid_until, ol);
  const variantRows = (x: OfferDocument['variants'][number]) => {
    if (x.viwa) {
      return `<div class="row"><span>${esc(lang === 'sk' ? 'Balík' : 'Package')}</span><span>${esc(x.viwa.package)}</span></div>
        <div class="row"><span>${esc(lang === 'sk' ? 'Mesačný poplatok' : 'Monthly fee')}</span><span>${esc(String(x.viwa.monthly_fee ?? '–'))} €</span></div>
        <div class="row"><span>${esc(lang === 'sk' ? 'Poplatok za odchýlku' : 'Imbalance fee')}</span><span>${esc(String(x.viwa.fee_kw ?? '–'))} €/kW</span></div>
        <div class="row"><span>${esc(lang === 'sk' ? 'Koeficient výmeny' : 'Exchange coefficient')}</span><span>${esc(String(x.viwa.coefficient ?? '–'))}</span></div>`;
    }
    return x.rows
      .map((r) => `<div class="row"><span>${esc(r.product)} · ${r.voltage_group.toUpperCase()}${r.oom_count > 1 ? ` (${r.oom_count})` : ''}</span><span>${
        r.prices.map((p) => `${p.year ? `${p.year}: ` : ''}${esc(p.text)}${p.text_vat ? ` (${esc(p.text_vat)} ${lang === 'sk' ? 's DPH' : 'incl. VAT'})` : ''}`).join('<br>')}</span></div>`)
      .join('');
  };
  const cards = d.variants
    .map((x, i) => {
      const inner = `<div class="vname">${active ? `<input type="radio" name="variant" value="${esc(x.id)}:${esc(x.terms_sha256 ?? '')}" ${i === 0 ? 'checked' : ''} required>` : ''}
        ${esc(t.variant)} ${esc(x.letter)} · ${esc(x.name)}</div>${variantRows(x)}
        <div class="row"><span>${esc(t.period)}</span><span>${esc(x.period)}</span></div>
        ${viwa ? '' : `<div class="row"><span>${esc(t.flex)}</span><span>${esc(x.flexibility === 'plnej flexibility' ? 'plná' : x.flexibility)}</span></div>`}`;
      return active ? `<label class="card variant">${inner}</label>` : `<div class="card">${inner}</div>`;
    })
    .join('');
  const banner = flash.ok
    ? `<div class="ok">${esc(t.ok)}</div>`
    : flash.err ? `<div class="err">${esc(t[`err_${flash.err}`])}</div>` : '';
  const state = v.reason === 'akceptovana' && d.acceptance
    ? `<div class="ok">${esc(t.accepted)} ${esc(stamp(d.acceptance.accepted_at, lang, true))} · ${esc(t.variant)} ${esc(d.acceptance.variant)} · ${esc(t.acceptedBy)} ${esc(d.acceptance.signer_name)}
        &nbsp; <a class="btn" href="/p/${token}/potvrdenie.pdf">${esc(t.confirmation)}</a></div>`
    : v.reason === 'nahradena' ? `<div class="info">${esc(t.replaced)}</div>`
      : v.reason === 'zamietnuta' ? `<div class="info">${esc(t.rejected)}</div>`
        : v.reason === 'vyprsana' ? `<div class="info">${esc(t.expired)}</div>` : '';
  const terms = d.variants
    .filter((x) => x.terms)
    .map((x) => `<details><summary>${esc(t.showTerms)} – ${esc(t.variant)} ${esc(x.letter)}</summary><pre>${esc(x.terms)}</pre></details>`)
    .join('');
  const form = active
    ? `<div class="card"><h2 style="margin:0 0 6px;font-size:18px">${esc(viwa ? t.acceptTitleViwa : t.acceptTitle)}</h2>${terms}
        <div class="form"><label>${esc(t.name)}<input type="text" name="name" maxlength="200" required autocomplete="name"></label>
        <label>${esc(t.func)}<input type="text" name="function" maxlength="200" required autocomplete="organization-title"></label></div>
        <label class="check"><input type="checkbox" name="confirm" value="1" required> <span>${esc(t.confirm)} ${esc(viwa ? t.confirmViwa : t.confirmOrder)}.</span></label>
        <button class="btn primary" type="submit">${esc(viwa ? t.buttonViwa : t.button)}</button> <span class="note">${esc(t.store)}</span>
        <p class="note">${esc(t.manual)}</p></div>`
    : '';
  const s = v.seller;
  const initials = (s?.name ?? '').split(' ').map((p) => p[0]).join('').slice(0, 2);
  return `<div class="kicker">${esc(t.offer)} ${esc(d.offer.display_number)}${d.offer.sent_at ? ` · ${esc(dateOnly(d.offer.sent_at, ol))}` : ''}</div>
    <div class="top"><div><h1>${esc(titleLead)} ${esc(d.vars['názov'] ?? '')}</h1>
      <div class="sub">${ooms} ${esc(ooms === 1 ? t.place1 : t.places)} · ${esc(t.planned)} ${esc(d.vars['objem'] ?? '–')} ${esc(t.yearly)} · ${esc(t.noVat)}</div></div>
      <div class="valid"><small>${esc(t.validUntil)}</small><strong>${esc(validText)}</strong></div></div>
    ${banner}${state}
    <form method="post" action="/p/${token}/accept?lang=${lang}">
      <div class="grid">${cards}</div>
      ${v.pdf ? `<div class="card pdf"><div><strong>${esc(t.pdf)}</strong><div class="note">${esc(t.pdfSub)}</div></div><a class="btn" href="/p/${token}/pdf">${esc(t.download)}</a></div>` : ''}
      ${form}
    </form>
    ${s?.name ? `<div class="card seller" style="margin-top:14px"><span class="avatar">${esc(initials)}</span><div><strong>${esc(s.name)}</strong> · ${esc(s.job_title ?? t.seller)}
      <div class="note">${esc([s.email, s.phone].filter(Boolean).join(' · '))}</div></div></div>` : ''}`;
}

function errKey(e: unknown): ErrKey {
  const m = e instanceof Error ? e.message : '';
  if (/znenie/i.test(m)) return 'zmenene';
  if (/už bola akceptovaná/i.test(m)) return 'akceptovana';
  if (/platnosť|neplatí/i.test(m)) return 'neplatna';
  if (/meno a funkciu/i.test(m)) return 'udaje';
  return 'chyba';
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const ip = req.headers.get('CF-Connecting-IP') ?? '0.0.0.0';
    const lang: Lang = url.searchParams.get('lang') === 'en' ? 'en' : 'sk';
    const m = url.pathname.match(/^\/p\/([^/]+)(\/pdf|\/potvrdenie\.pdf|\/accept)?\/?$/);
    if (!m) return invalidPage(lang);
    const [, token, sub] = m;

    if (!(await env.RL_VIEW.limit({ key: ip })).success) return html(page(lang, null, T[lang].tooMany, `<p>${esc(T[lang].tooMany)}</p>`), 429);
    if (!TOKEN.test(token)) {
      await env.RL_BAD.limit({ key: ip });
      return invalidPage(lang);
    }
    const hash = await sha256Hex(token);
    const sql = postgres(env.HYPERDRIVE.connectionString, { max: 1, fetch_types: false });
    try {
      if (sub === '/accept') {
        if (req.method !== 'POST') return Response.redirect(`${url.origin}/p/${token}?lang=${lang}`, 303);
        if (!(await env.RL_ACCEPT.limit({ key: ip })).success) return html(page(lang, null, T[lang].tooMany, `<p>${esc(T[lang].tooMany)}</p>`), 429);
        const form = await req.formData();
        const [variant = '', sha = ''] = String(form.get('variant') ?? '').split(':');
        const name = String(form.get('name') ?? '').trim();
        const func = String(form.get('function') ?? '').trim();
        const back = (q: string) => Response.redirect(`${url.origin}/p/${token}?lang=${lang}&${q}`, 303);
        if (form.get('confirm') !== '1') return back('err=potvrdenie');
        if (!/^[0-9a-f-]{36}$/.test(variant) || !name || !func) return back('err=udaje');
        try {
          // akceptácia, potvrdenie v PDF (R2) a jeho odtlačok v jednej transakcii – bez uloženého potvrdenia sa akceptácia nezapíše
          await sql.begin(async (tx) => {
            const [row] = await tx<{ r: AcceptResult }[]>`
              SELECT verejne.ponuka_akceptovat(${hash}, ${variant}, ${name}, ${func}, ${ip}, ${req.headers.get('User-Agent') ?? ''}, ${sha}) AS r`;
            const r = row.r;
            if (r.confirmation_stored) return;
            const pdf = await htmlToPdf(env.BROWSER, confirmationHtml(r.document, r, r.variant, r.terms_text), pdfFooter(r.document));
            const fileSha = await sha256Hex(pdf);
            await env.DOCS.put(r.confirmation_key, pdf, {
              httpMetadata: { contentType: 'application/pdf' },
              customMetadata: { acceptance: r.acceptance_id, sha256: fileSha },
            });
            await tx`SELECT verejne.ponuka_potvrdenie_ulozit(${hash}, ${r.acceptance_id}, ${r.confirmation_key}, ${fileSha})`;
          });
          return back('ok=1');
        } catch (e) {
          return back(`err=${errKey(e)}`);
        }
      }

      // uložené potvrdenie akceptácie (vzniklo v momente akceptácie, nemení sa)
      if (sub === '/potvrdenie.pdf') {
        const [r] = await sql<{ p: { pdf_key: string; file_name: string } | null }[]>`SELECT verejne.ponuka_potvrdenie_pdf(${hash}) AS p`;
        if (!r?.p) return invalidPage(lang);
        const obj = await env.DOCS.get(r.p.pdf_key);
        if (!obj) return invalidPage(lang);
        return new Response(obj.body, {
          headers: { 'Content-Type': 'application/pdf', 'Content-Disposition': `attachment; filename="${r.p.file_name}"`, ...SECURITY_HEADERS },
        });
      }

      if (sub === '/pdf') {
        const [r] = await sql<{ p: { pdf_key: string; file_name: string } | null }[]>`SELECT verejne.ponuka_pdf(${hash}) AS p`;
        if (!r?.p) return invalidPage(lang);
        const obj = await env.DOCS.get(r.p.pdf_key);
        if (!obj) return invalidPage(lang);
        return new Response(obj.body, {
          headers: { 'Content-Type': 'application/pdf', 'Content-Disposition': `attachment; filename="${r.p.file_name}"`, ...SECURITY_HEADERS },
        });
      }

      const [row] = await sql<{ v: View }[]>`SELECT verejne.ponuka_zobrazit(${hash}) AS v`;
      const v = row?.v;
      if (!v || v.mode === 'neplatny' || !v.document) {
        await env.RL_BAD.limit({ key: ip });
        return invalidPage(lang);
      }


      const ok = url.searchParams.get('ok') === '1';
      const err = url.searchParams.get('err') as ErrKey | null;
      const flash = { ok, err: err && ['zmenene', 'neplatna', 'akceptovana', 'udaje', 'potvrdenie', 'chyba'].includes(err) ? err : undefined };
      return html(page(lang, token, `${T[lang].offer} ${v.document.offer.display_number}`, offerPage(v, token, lang, flash)));
    } catch {
      return html(page(lang, null, 'Chyba', `<p>${esc(T[lang].err_chyba)}</p>`), 500);
    } finally {
      await sql.end({ timeout: 1 });
    }
  },
};
