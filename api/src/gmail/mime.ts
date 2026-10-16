// Modul 5, F4 – e-maily: skladanie odosielanej správy (MIME) a spracovanie správy z Gmailu (formát full).
// Čisté funkcie bez prístupu k sieti a databáze (testy: api/test/gmail.test.ts, `npm test`).
//
// Prijatá správa (Peter 16. 10.): obsah všetkých častí s prílohami – aj malé vložené obrázky – sa hneď zahodí,
// nedekóduje ani neuloží. Ostáva iba vyčistený text správy a hlavičky potrebné pre vlákno (odosielateľ, adresáti,
// predmet, Message-ID, čas). Odkaz na stránku ponuky s tokenom sa z citovaného textu odstráni.

/** Časť správy z Gmail API (users.threads.get / users.messages.get, format=full). */
export type GmailPart = {
  partId?: string;
  mimeType?: string;
  filename?: string;
  headers?: { name: string; value: string }[];
  body?: { size?: number; data?: string; attachmentId?: string };
  parts?: GmailPart[];
};
export type GmailMessage = {
  id: string;
  threadId: string;
  internalDate?: string;
  payload?: GmailPart;
};

/** Správa pripravená pre email_message_received (iba text a hlavičky vlákna – nič z príloh). */
export type ParsedMessage = {
  gmail_message_id: string;
  rfc_message_id: string | null;
  direction: 'prichadzajuca' | 'odchadzajuca';
  from: string | null;
  from_name: string | null;
  to: string[];
  cc: string[];
  subject: string;
  body_text: string;
  at: string;
};

const MAX_TEXT = 200_000;
const ADDR = /^[^@\s<>(),;:"]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const GMAIL_ID = /^[0-9a-f]{6,32}$/;

// ---------------------------------------------------------------------------------------------------------------
// Spoločné
// ---------------------------------------------------------------------------------------------------------------

const enc = new TextEncoder();

export function base64(bytes: Uint8Array): string {
  let s = '';
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
}
export function base64url(bytes: Uint8Array): string {
  return base64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function fromBase64url(s: string): Uint8Array {
  const b = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
  const out = new Uint8Array(b.length);
  for (let i = 0; i < b.length; i++) out[i] = b.charCodeAt(i);
  return out;
}

/** Hodnota hlavičky bez riadkových zlomov (ochrana proti vloženiu ďalšej hlavičky). */
export function headerSafe(v: string): string {
  return v.replace(/[\r\n]+/g, ' ').trim();
}

export function isAddress(v: string): boolean {
  return v.length <= 254 && ADDR.test(v);
}

/** Zoznam adries z hlavičky (To, Cc): iba adresy, malými písmenami, bez neplatných; najviac 100. */
export function parseAddressList(v: string | undefined): string[] {
  if (!v) return [];
  const out: string[] = [];
  let cur = '';
  let quoted = false;
  let angle = 0;
  for (const ch of v) {
    if (ch === '"') quoted = !quoted;
    if (!quoted && ch === '<') angle++;
    if (!quoted && ch === '>') angle = Math.max(0, angle - 1);
    if (ch === ',' && !quoted && angle === 0) {
      out.push(cur);
      cur = '';
    } else cur += ch;
  }
  out.push(cur);
  const res: string[] = [];
  for (const one of out) {
    const a = parseAddress(one).address;
    if (a && !res.includes(a)) res.push(a);
    if (res.length >= 100) break;
  }
  return res;
}

/** Jedna adresa „Meno <adresa>“ alebo „adresa“. */
export function parseAddress(v: string | undefined): { address: string | null; name: string | null } {
  if (!v) return { address: null, name: null };
  const m = v.match(/<([^<>]+)>/);
  const address = (m ? m[1] : v).trim().toLowerCase();
  let name = m ? v.slice(0, m.index).trim().replace(/^"|"$/g, '').trim() : '';
  name = decodeEncodedWords(name);
  return { address: isAddress(address) ? address : null, name: name ? name.slice(0, 200) : null };
}

/** RFC 2047 („=?UTF-8?B?…?=“, „=?UTF-8?Q?…?=“) – hlavičky z Gmailu bývajú už dekódované, ale nie vždy. */
export function decodeEncodedWords(v: string): string {
  return v.replace(/=\?([^?]+)\?([BbQq])\?([^?]*)\?=/g, (_all, charset: string, kind: string, text: string) => {
    try {
      const bytes = kind.toUpperCase() === 'B'
        ? Uint8Array.from(atob(text), (c) => c.charCodeAt(0))
        : Uint8Array.from(text.replace(/_/g, ' ').replace(/=([0-9A-Fa-f]{2})/g, (_m, h: string) => String.fromCharCode(parseInt(h, 16))), (c) => c.charCodeAt(0));
      return new TextDecoder(charset.toLowerCase(), { fatal: false, ignoreBOM: false }).decode(bytes);
    } catch {
      return text;
    }
  });
}

// ---------------------------------------------------------------------------------------------------------------
// Prijatá správa
// ---------------------------------------------------------------------------------------------------------------

function header(p: GmailPart | undefined, name: string): string | undefined {
  const h = p?.headers?.find((x) => x.name.toLowerCase() === name.toLowerCase());
  return h?.value;
}

/**
 * Časť s prílohou: názov súboru, odkaz na prílohu (attachmentId), Content-Disposition attachment alebo inline
 * s názvom súboru, Content-ID (vložený obrázok) alebo iný typ než text a multipart. Z takej časti sa nečíta nič.
 */
export function isAttachmentPart(p: GmailPart): boolean {
  const type = (p.mimeType ?? '').toLowerCase();
  if (type.startsWith('multipart/')) return false;
  if (p.filename) return true;
  if (p.body?.attachmentId) return true;
  const disp = (header(p, 'Content-Disposition') ?? '').toLowerCase();
  if (disp.startsWith('attachment')) return true;
  // „inline“ s názvom súboru je vložená príloha; text tela správy býva „inline“ bez názvu (napr. Apple Mail)
  if (disp.startsWith('inline') && /filename/.test(disp)) return true;
  if (header(p, 'Content-ID')) return true;
  return type !== 'text/plain' && type !== 'text/html';
}

/** Textové časti (bez príloh) v poradí; obsah príloh sa nikdy nedekóduje. */
function textParts(p: GmailPart | undefined, out: { type: string; part: GmailPart }[] = []) {
  if (!p) return out;
  if ((p.mimeType ?? '').toLowerCase().startsWith('multipart/')) {
    for (const c of p.parts ?? []) textParts(c, out);
    return out;
  }
  if (isAttachmentPart(p)) return out;
  out.push({ type: (p.mimeType ?? '').toLowerCase(), part: p });
  return out;
}

function decodePart(p: GmailPart): string {
  if (!p.body?.data) return '';
  const charset = (header(p, 'Content-Type') ?? '').match(/charset="?([^";\s]+)"?/i)?.[1] ?? 'utf-8';
  const bytes = fromBase64url(p.body.data);
  try {
    return new TextDecoder(charset.toLowerCase(), { fatal: false, ignoreBOM: false }).decode(bytes);
  } catch {
    return new TextDecoder('utf-8').decode(bytes);
  }
}

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };

/** HTML → čistý text: bez skriptov, štýlov, obrázkov a značiek; odkazy ostanú ako text adresy. */
export function htmlToText(html: string): string {
  return html
    .replace(/<(script|style|head|title|template|iframe|object|svg)[\s\S]*?<\/\1\s*>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<img[^>]*>/gi, '')
    .replace(/<a\s[^>]*href\s*=\s*["']([^"']*)["'][^>]*>([\s\S]*?)<\/a>/gi, (_m, href: string, text: string) => {
      const t = text.replace(/<[^>]+>/g, '').trim();
      return /^https?:/i.test(href) && t !== href ? `${t} (${href})` : t;
    })
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|tr|li|h[1-6]|blockquote)>/gi, '\n')
    .replace(/<li[^>]*>/gi, '• ')
    .replace(/<[^>]+>/g, '')
    .replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, (m, e: string) => {
      if (e[0] === '#') {
        const n = e[1] === 'x' || e[1] === 'X' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : '';
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    });
}

/** Normalizácia textu: konce riadkov, bez riadiacich znakov, najviac 2 prázdne riadky, odkaz na ponuku bez tokenu. */
export function cleanText(text: string, publicOfferUrl?: string): string {
  let t = text.replace(/\r\n?/g, '\n').replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '');
  t = t.replace(/[ \t]+\n/g, '\n').replace(/\n{3,}/g, '\n\n').trim();
  if (publicOfferUrl) {
    const base = publicOfferUrl.replace(/\/+$/, '').replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    t = t.replace(new RegExp(`${base}/p/[A-Za-z0-9_-]+`, 'g'), '[odkaz na ponuku]');
  }
  // tokeny odkazu aj na inej adrese stránky ponuky (napr. citovaný e-mail z Testu)
  t = t.replace(/(https?:\/\/[^\s/]+)\/p\/[A-Za-z0-9_-]{40,}/g, '[odkaz na ponuku]');
  return t.length > MAX_TEXT ? t.slice(0, MAX_TEXT) : t;
}

/**
 * Správa z Gmailu (format=full) → údaje na uloženie. Ukladá sa iba text (text/plain, inak text z text/html)
 * a hlavičky vlákna; časti s prílohami sa preskočia bez dekódovania.
 */
export function parseGmailMessage(m: GmailMessage, mailbox: string, publicOfferUrl?: string): ParsedMessage {
  if (!GMAIL_ID.test(m.id)) throw new Error('Neplatné ID správy z Gmailu.');
  const p = m.payload;
  const parts = textParts(p);
  const plain = parts.find((x) => x.type === 'text/plain');
  const html = parts.find((x) => x.type === 'text/html');
  const raw = plain ? decodePart(plain.part) : html ? htmlToText(decodePart(html.part)) : '';
  const from = parseAddress(header(p, 'From'));
  const at = m.internalDate && /^\d+$/.test(m.internalDate) ? new Date(Number(m.internalDate)).toISOString() : new Date().toISOString();
  const rfc = header(p, 'Message-ID') ?? header(p, 'Message-Id');
  return {
    gmail_message_id: m.id,
    rfc_message_id: rfc ? headerSafe(rfc).slice(0, 998) : null,
    direction: from.address && from.address === mailbox.toLowerCase() ? 'odchadzajuca' : 'prichadzajuca',
    from: from.address,
    from_name: from.name,
    to: parseAddressList(header(p, 'To')),
    cc: parseAddressList(header(p, 'Cc')),
    subject: headerSafe(decodeEncodedWords(header(p, 'Subject') ?? '')).slice(0, 998),
    body_text: cleanText(raw, publicOfferUrl),
    at,
  };
}

// ---------------------------------------------------------------------------------------------------------------
// Odosielaná správa
// ---------------------------------------------------------------------------------------------------------------

export type MimeAttachment = { filename: string; mime: string; data: Uint8Array; cid?: string };
export type MimeInput = {
  from: string;
  fromName?: string | null;
  to: string[];
  cc?: string[];
  replyTo?: string | null;
  subject: string;
  text: string;
  html: string;
  messageId: string;
  inReplyTo?: string | null;
  references?: string[];
  inline?: MimeAttachment[];       // obrázky v podpise (cid:)
  attachments?: MimeAttachment[];  // PDF ponuky / potvrdenia
};

/** Kódovanie hlavičky (RFC 2047, UTF-8 base64), iba ak obsahuje znaky mimo ASCII. */
export function encodeHeader(v: string): string {
  const s = headerSafe(v);
  // eslint-disable-next-line no-control-regex
  if (/^[\x20-\x7e]*$/.test(s)) return s;
  const out: string[] = [];
  let chunk = '';
  for (const ch of s) {
    if (enc.encode(chunk + ch).length > 45) {
      out.push(chunk);
      chunk = '';
    }
    chunk += ch;
  }
  if (chunk) out.push(chunk);
  return out.map((c) => `=?UTF-8?B?${base64(enc.encode(c))}?=`).join('\r\n ');
}

function mailbox(address: string, name?: string | null): string {
  const a = headerSafe(address);
  if (!name) return a;
  const n = headerSafe(name);
  // eslint-disable-next-line no-control-regex
  return /^[\x20-\x7e]*$/.test(n) ? `"${n.replace(/["\\]/g, '')}" <${a}>` : `${encodeHeader(n)} <${a}>`;
}

function wrap76(b64: string): string {
  return b64.replace(/.{1,76}/g, '$&\r\n').trimEnd();
}
function fileHeader(name: string): string {
  // eslint-disable-next-line no-control-regex
  const ascii = /^[\x20-\x7e]*$/.test(name) ? name.replace(/["\\]/g, '') : '';
  return ascii ? `"${ascii}"` : `"${encodeHeader(name)}"`;
}

/** Celá správa MIME (text + HTML, obrázky podpisu cez cid:, prílohy PDF). Gmail ju dostane ako `raw` pri odoslaní. */
export function buildMime(m: MimeInput): string {
  for (const a of [...m.to, ...(m.cc ?? []), m.from, ...(m.replyTo ? [m.replyTo] : [])]) {
    if (!isAddress(a)) throw new Error('Neplatná e-mailová adresa.');
  }
  if (!m.to.length) throw new Error('Chýba príjemca.');
  const rnd = () => base64url(crypto.getRandomValues(new Uint8Array(12)));
  const bMixed = `mix_${rnd()}`;
  const bRel = `rel_${rnd()}`;
  const bAlt = `alt_${rnd()}`;
  const h: string[] = [
    `From: ${mailbox(m.from, m.fromName)}`,
    `To: ${m.to.map((a) => headerSafe(a)).join(', ')}`,
  ];
  if (m.cc?.length) h.push(`Cc: ${m.cc.map((a) => headerSafe(a)).join(', ')}`);
  if (m.replyTo) h.push(`Reply-To: ${headerSafe(m.replyTo)}`);
  h.push(`Subject: ${encodeHeader(m.subject)}`, `Message-ID: ${headerSafe(m.messageId)}`, `Date: ${new Date().toUTCString()}`);
  if (m.inReplyTo) h.push(`In-Reply-To: ${headerSafe(m.inReplyTo)}`);
  if (m.references?.length) h.push(`References: ${m.references.map(headerSafe).join(' ')}`);
  h.push('MIME-Version: 1.0', `Content-Type: multipart/mixed; boundary="${bMixed}"`);

  const textPart = (type: string, body: string) =>
    [`Content-Type: ${type}; charset="UTF-8"`, 'Content-Transfer-Encoding: base64', '', wrap76(base64(enc.encode(body)))].join('\r\n');
  const filePart = (a: MimeAttachment, inline: boolean) =>
    [
      `Content-Type: ${headerSafe(a.mime)}; name=${fileHeader(a.filename)}`,
      'Content-Transfer-Encoding: base64',
      `Content-Disposition: ${inline ? 'inline' : 'attachment'}; filename=${fileHeader(a.filename)}`,
      ...(a.cid ? [`Content-ID: <${headerSafe(a.cid)}>`] : []),
      '',
      wrap76(base64(a.data)),
    ].join('\r\n');

  const alt = [`--${bAlt}`, textPart('text/plain', m.text), `--${bAlt}`, textPart('text/html', m.html), `--${bAlt}--`].join('\r\n');
  const rel = [
    `--${bRel}`, `Content-Type: multipart/alternative; boundary="${bAlt}"`, '', alt,
    ...(m.inline ?? []).flatMap((a) => [`--${bRel}`, filePart(a, true)]),
    `--${bRel}--`,
  ].join('\r\n');
  const mixed = [
    `--${bMixed}`, `Content-Type: multipart/related; boundary="${bRel}"`, '', rel,
    ...(m.attachments ?? []).flatMap((a) => [`--${bMixed}`, filePart(a, false)]),
    `--${bMixed}--`, '',
  ].join('\r\n');
  return `${h.join('\r\n')}\r\n\r\n${mixed}`;
}

// ---------------------------------------------------------------------------------------------------------------
// Text e-mailu: «odkaz na ponuku» a «podpis» doplní odoslanie (token odkazu sa neukladá)
// ---------------------------------------------------------------------------------------------------------------

export type Signature = {
  name: string; job_title: string | null; email: string; phone: string | null; mobile: string | null;
  linkedin: string | null; company: string; address: string | null; web: string | null; has_photo: boolean;
};

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

export function signatureText(s: Signature): string {
  return [
    s.name, s.job_title, s.company, s.address,
    s.mobile ? `M: ${s.mobile}` : null, s.phone ? `T: ${s.phone}` : null, `E: ${s.email}`, s.web,
  ].filter(Boolean).join('\n');
}

export function signatureHtml(s: Signature, photoCid: string | null): string {
  const web = s.web ? (/^https?:/i.test(s.web) ? s.web : `https://${s.web}`) : null;
  const lines = [
    `<strong style="font-size:15px;color:#1b3a2b">${esc(s.name)}</strong>`,
    s.job_title ? esc(s.job_title) : null,
    `<span style="color:#1b3a2b">${esc(s.company)}</span>`,
    s.address ? esc(s.address) : null,
    s.mobile ? `M: <a href="tel:${esc(s.mobile.replace(/\s+/g, ''))}" style="color:#333;text-decoration:none">${esc(s.mobile)}</a>` : null,
    s.phone ? `T: <a href="tel:${esc(s.phone.replace(/\s+/g, ''))}" style="color:#333;text-decoration:none">${esc(s.phone)}</a>` : null,
    `E: <a href="mailto:${esc(s.email)}" style="color:#333">${esc(s.email)}</a>`,
    web ? `<a href="${esc(web)}" style="color:#2f7d4f">${esc(s.web!)}</a>` : null,
    s.linkedin ? `<a href="${esc(s.linkedin)}" style="color:#2f7d4f">LinkedIn</a>` : null,
  ].filter(Boolean).join('<br>');
  const photo = photoCid
    ? `<td style="padding-right:14px;vertical-align:top"><img src="cid:${esc(photoCid)}" width="72" height="72" alt="" style="border-radius:50%;display:block"></td>`
    : '';
  return `<table cellpadding="0" cellspacing="0" style="font-family:Arial,sans-serif;font-size:13px;line-height:1.45;color:#333"><tr>${photo}<td style="vertical-align:top">${lines}</td></tr></table>`;
}

/** Text a HTML e-mailu z uloženého textu: doplní odkaz a podpis, HTML bez sledovacích prvkov. */
export function renderBody(body: string, link: string | null, sig: Signature | null, photoCid: string | null): { text: string; html: string } {
  const linkText = link ?? '';
  const text = body.replace(/«odkaz na ponuku»/g, linkText).replace(/«podpis»/g, sig ? signatureText(sig) : '');
  const parts = body.split(/(«odkaz na ponuku»|«podpis»)/);
  const html = parts.map((p) => {
    if (p === '«odkaz na ponuku»') {
      return link ? `<a href="${esc(link)}" style="display:inline-block;padding:10px 18px;background:#2f7d4f;color:#fff;border-radius:6px;text-decoration:none;font-weight:bold">Zobraziť ponuku</a>` : '';
    }
    if (p === '«podpis»') return sig ? signatureHtml(sig, photoCid) : '';
    return esc(p).replace(/\n/g, '<br>');
  }).join('');
  return { text, html: `<div style="font-family:Arial,sans-serif;font-size:14px;line-height:1.5;color:#222">${html}</div>` };
}

/** Na Teste smie CRM posielať iba na @greenlogy.com a adresy zo zoznamu MAIL_ALLOWLIST (secret). */
export function recipientsAllowed(addresses: string[], environment: string | undefined, allowlist: string | undefined): string[] {
  if (environment === 'ostre') return [];
  const allowed = new Set((allowlist ?? '').split(/[\s,;]+/).map((a) => a.trim().toLowerCase()).filter(Boolean));
  return addresses.filter((a) => !a.toLowerCase().endsWith('@greenlogy.com') && !allowed.has(a.toLowerCase()));
}
