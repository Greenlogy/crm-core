// Modul 5, F4 – vlastný podpis e-mailu (0044): vyčistenie HTML vloženého cez Ctrl+V alebo ako kód.
// Ostanú iba povolené značky a atribúty (tabuľky, text, odkazy https / mailto / tel, obrázky), štýly bez url(),
// expression a pozícií; obsah skriptov, štýlov, rámcov a formulárov sa zahodí celý. Obrázky sa vyberú na stiahnutie /
// dekódovanie a v HTML sa nahradia cid:sig1–sig5 (v e-maile ako vložené prílohy – nič sa nenačítava zvonka).
// Výsledok musí prejsť aj obmedzením v databáze (user_signature_html_check) – test api/test/gmail.test.ts.
// Čistá funkcia bez siete (stiahnutie obrázkov robí routes/emails.ts).

export const MAX_SIGNATURE_IMAGES = 5;
export const MAX_SIGNATURE_IMAGE_BYTES = 300 * 1024;
export const MAX_SIGNATURE_HTML = 100_000;

const ALLOWED_TAGS = new Set([
  'table', 'thead', 'tbody', 'tfoot', 'tr', 'td', 'th', 'col', 'colgroup', 'caption', 'p', 'div', 'span', 'br', 'hr',
  'b', 'strong', 'i', 'em', 'u', 's', 'small', 'big', 'sub', 'sup', 'font', 'a', 'img', 'ul', 'ol', 'li', 'blockquote',
  'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'center', 'pre', 'code',
]);
const VOID_TAGS = new Set(['br', 'hr', 'img', 'col']);
// značky, ktorých obsah sa zahodí celý
const DROP_CONTENT = new Set(['script', 'style', 'head', 'title', 'iframe', 'frame', 'frameset', 'object', 'embed', 'applet',
  'noscript', 'template', 'svg', 'math', 'form', 'textarea', 'select', 'button', 'video', 'audio', 'canvas', 'xml']);
const ALLOWED_ATTRS = new Set(['style', 'width', 'height', 'align', 'valign', 'colspan', 'rowspan', 'cellpadding', 'cellspacing',
  'border', 'alt', 'title', 'color', 'face', 'size', 'bgcolor', 'href', 'src', 'dir']);
const CSS_PROPS = /^(color|background-color|font|font-family|font-size|font-weight|font-style|line-height|text-align|text-decoration|vertical-align|letter-spacing|white-space|width|height|max-width|min-width|max-height|margin(-(top|right|bottom|left))?|padding(-(top|right|bottom|left))?|border(-(top|right|bottom|left))?(-(width|style|color))?|border-collapse|border-spacing|border-radius|display)$/i;

export type SignatureImageRef = { cid: string; src: string };
export type CleanSignature = { html: string; images: SignatureImageRef[]; dropped: number };

const ENT = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
/** Znaky, ktoré by v texte vyzerali ako nebezpečný zápis (databáza ich odmietne): kódovanie ako entita. */
function neutral(s: string): string {
  return s
    .replace(/(javascript|vbscript|data)(\s*):/gi, '$1$2&#58;')
    .replace(/(url|expression)(\s*)\(/gi, '$1$2&#40;')
    .replace(/=/g, '&#61;');
}
function decodeEntities(s: string): string {
  return s.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos|nbsp);/gi, (_m, e: string) => {
    const l = e.toLowerCase();
    if (l === 'amp') return '&';
    if (l === 'lt') return '<';
    if (l === 'gt') return '>';
    if (l === 'quot') return '"';
    if (l === 'apos') return "'";
    if (l === 'nbsp') return '\u00a0';
    const n = l[1] === 'x' ? parseInt(l.slice(2), 16) : parseInt(l.slice(1), 10);
    return Number.isFinite(n) && n > 0 && n < 0x110000 ? String.fromCodePoint(n) : '';
  });
}

function cleanStyle(style: string): string {
  const out: string[] = [];
  for (const decl of decodeEntities(style).split(';')) {
    const i = decl.indexOf(':');
    if (i < 0) continue;
    const prop = decl.slice(0, i).trim().toLowerCase();
    const val = decl.slice(i + 1).trim();
    if (!CSS_PROPS.test(prop)) continue;
    if (!val || val.length > 200 || /url\s*\(|expression|javascript|vbscript|data\s*:|@import|behavior|[<>"\\]/i.test(val)) continue;
    out.push(`${prop}:${val}`);
  }
  return out.join(';');
}

function cleanHref(v: string): string | null {
  const u = decodeEntities(v).trim();
  if (/^(https?:\/\/|mailto:|tel:)/i.test(u) && !/[\s<>"]/.test(u) && u.length <= 500
      && !/(javascript|vbscript|data)\s*:|url\s*\(|expression\s*\(/i.test(u)) return u;
  return null;
}

function parseAttrs(s: string): [string, string][] {
  const out: [string, string][] = [];
  const re = /([^\s"'<>/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(s))) out.push([m[1].toLowerCase(), m[2] ?? m[3] ?? m[4] ?? '']);
  return out;
}

/** Vyčistí podpis. Obrázky (data: alebo https:) dostanú cid:sigN; iné obrázky sa vynechajú. */
export function cleanSignatureHtml(input: string): CleanSignature {
  const html = input.length > 500_000 ? input.slice(0, 500_000) : input;
  const images: SignatureImageRef[] = [];
  let dropped = 0;
  const out: string[] = [];
  const open: string[] = [];
  let skip: string | null = null;   // vnútri značky, ktorej obsah sa zahadzuje
  const re = /<!--[\s\S]*?-->|<!\[CDATA\[[\s\S]*?\]\]>|<![^>]*>|<\?[\s\S]*?\?>|<\/?([a-zA-Z][a-zA-Z0-9:-]*)((?:[^>"']|"[^"]*"|'[^']*')*)>|[^<]+|</g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html))) {
    const tok = m[0];
    if (tok.startsWith('<!') || tok.startsWith('<?')) continue;
    if (m[1]) {
      const name = m[1].toLowerCase().replace(/^.*:/, '');
      const closing = tok.startsWith('</');
      if (skip) {
        if (closing && name === skip) skip = null;
        continue;
      }
      if (DROP_CONTENT.has(name)) {
        if (!closing && !/\/\s*$/.test(m[2] ?? '')) skip = name;
        dropped++;
        continue;
      }
      if (!ALLOWED_TAGS.has(name)) {
        if (!['html', 'body', 'meta', 'link', 'base', 'o:p', 'p'].includes(name)) dropped++;
        continue;
      }
      if (closing) {
        const idx = open.lastIndexOf(name);
        if (idx >= 0) {
          while (open.length > idx) out.push(`</${open.pop()}>`);
        }
        continue;
      }
      const attrs: string[] = [];
      let keepTag = true;
      for (const [k, v] of parseAttrs(m[2] ?? '')) {
        if (!ALLOWED_ATTRS.has(k)) continue;
        if (k === 'style') {
          const st = cleanStyle(v);
          if (st) attrs.push(`style="${ENT(st)}"`);
        } else if (k === 'href') {
          if (name !== 'a') continue;
          const h = cleanHref(v);
          if (h) attrs.push(`href="${ENT(h)}"`);
        } else if (k === 'src') {
          if (name !== 'img') continue;
          const src = decodeEntities(v).trim();
          if (!/^(https:\/\/|http:\/\/|data:image\/(png|jpeg|jpg|gif);base64,)/i.test(src)) {
            keepTag = false;
            continue;
          }
          let ref = images.find((x) => x.src === src);
          if (!ref) {
            if (images.length >= MAX_SIGNATURE_IMAGES) {
              keepTag = false;
              continue;
            }
            ref = { cid: `sig${images.length + 1}`, src };
            images.push(ref);
          }
          attrs.push(`src="cid:${ref.cid}"`);
        } else if (/^(width|height|colspan|rowspan|cellpadding|cellspacing|border|size)$/.test(k)) {
          if (/^\d{1,4}%?$/.test(v.trim())) attrs.push(`${k}="${v.trim()}"`);
        } else if (/^(align|valign|dir)$/.test(k)) {
          if (/^(left|right|center|top|middle|bottom|baseline|justify|ltr|rtl)$/i.test(v.trim())) attrs.push(`${k}="${v.trim().toLowerCase()}"`);
        } else if (/^(color|bgcolor)$/.test(k)) {
          if (/^(#[0-9a-f]{3,8}|[a-z]{3,20})$/i.test(v.trim())) attrs.push(`${k}="${v.trim()}"`);
        } else {
          attrs.push(`${k}="${neutral(ENT(decodeEntities(v).slice(0, 200)))}"`);
        }
      }
      if (name === 'img' && (!keepTag || !attrs.some((a) => a.startsWith('src=')))) {
        dropped++;
        continue;
      }
      if (name === 'a' && attrs.every((a) => !a.startsWith('href='))) {
        // odkaz bez povolenej adresy: ostane iba text
        out.push('<span>');
        open.push('span');
        continue;
      }
      if (name === 'a') attrs.push('target="_blank"');
      out.push(`<${name}${attrs.length ? ' ' + attrs.join(' ') : ''}>`);
      if (!VOID_TAGS.has(name)) open.push(name);
      continue;
    }
    if (skip) continue;
    out.push(neutral(ENT(decodeEntities(tok))));
  }
  while (open.length) out.push(`</${open.pop()}>`);
  const result = out.join('').replace(/(\s*<br>\s*){3,}/g, '<br><br>').trim();
  return { html: result.length > MAX_SIGNATURE_HTML ? '' : result, images, dropped };
}

/** Rozmery a typ obrázka podpisu z hlavičky (PNG, JPEG, GIF). */
export function signatureImageType(b: Uint8Array): 'image/png' | 'image/jpeg' | 'image/gif' | null {
  if (b.length > 8 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4e && b[3] === 0x47) return 'image/png';
  if (b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  if (b.length > 6 && b[0] === 0x47 && b[1] === 0x49 && b[2] === 0x46) return 'image/gif';
  return null;
}
