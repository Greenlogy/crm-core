// Testy F4 – vlastný podpis (0044): vyčistenie HTML a súlad s obmedzením v databáze (user_signature_html_check).
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { cleanSignatureHtml, signatureImageType } from '../src/gmail/signature.ts';

// rovnaké pravidlá ako CHECK v 0044 (ARE \M = koniec slova)
function dbAccepts(html: string): boolean {
  return html.length <= 100000
    && !/<\s*\/?\s*(script|iframe|frame|object|embed|applet|form|input|button|textarea|select|meta|link|base|style|svg|math|video|audio|source)\b/i.test(html)
    && !/\son[a-z]+\s*=/i.test(html)
    && !/(javascript|vbscript|data)\s*:/i.test(html)
    && !/url\s*\(/i.test(html)
    && !/expression\s*\(/i.test(html)
    && !/\ssrc\s*=\s*["']?(?!["']|cid:)/i.test(html);
}

test('podpis z Gmailu (Ctrl+V): tabuľka, štýly, odkazy a obrázky ostanú, obrázky ako cid:', () => {
  const pasted = `<meta charset="utf-8"><div dir="ltr" class="gmail_signature"><table cellpadding="0" style="font-family:Arial;color:#1b3a2b;background:url(https://x.example/bg.png)">
<tr><td><img src="https://ci3.googleusercontent.com/logo.png" width="96" height="40" alt="Greenlogy" onerror="alert(1)"></td>
<td style="padding-left:12px"><b>Peter Kalman</b><br>CEO | <a href="https://greenlogy.com" style="color:#2f7d4f">greenlogy.com</a><br>
<a href="tel:+421900000000">+421 900 000 000</a> · <a href="mailto:peter@greenlogy.com">peter@greenlogy.com</a><br>
<img src="data:image/png;base64,iVBORw0KGgo=" width="16"><img src="https://ci3.googleusercontent.com/logo.png"></td></tr></table></div>`;
  const r = cleanSignatureHtml(pasted);
  assert.deepEqual(r.images.map((i) => i.cid), ['sig1', 'sig2'], 'rovnaký obrázok raz');
  assert.equal(r.images[0].src, 'https://ci3.googleusercontent.com/logo.png');
  assert.ok(r.images[1].src.startsWith('data:image/png;base64,'));
  assert.ok(r.html.includes('<img src="cid:sig1" width="96" height="40" alt="Greenlogy">'), r.html);
  assert.ok(r.html.includes('<a href="https://greenlogy.com" style="color:#2f7d4f" target="_blank">greenlogy.com</a>'));
  assert.ok(r.html.includes('href="tel:+421900000000"') && r.html.includes('href="mailto:peter@greenlogy.com"'));
  assert.ok(!/onerror|url\(|class=|meta/i.test(r.html), 'bez udalostí, url(), tried a meta');
  assert.ok(r.html.includes('style="font-family:Arial;color:#1b3a2b"'), 'povolené štýly ostanú');
  assert.ok(dbAccepts(r.html), 'databáza prijme: ' + r.html);
});

test('nebezpečný obsah sa odstráni a výsledok vždy prejde databázou', () => {
  const cases = [
    '<script>alert(1)</script>Text', '<style>td{color:red}</style><b>x</b>', '<a href="javascript:alert(1)">klik</a>',
    '<img src="javascript:alert(1)">', '<img src="//cudzi.example/a.png">', '<img src=x onerror=alert(1)>',
    '<iframe src="https://x.example"></iframe>ok', '<svg><script>x</script></svg>', '<div style="width:expression(alert(1))">x</div>',
    '<a href="https://x.example/data:text/html,1">x</a>', 'Text s data: a url(x) a expression(x) a only = 1',
    '<form action="https://x"><input value="a"></form>', '<!-- komentár --><b>x</b>', '<p title="x onmouseover=alert(1)">t</p>',
    '<div style="background-image:url(\'https://x\')">x</div>', '<td onClick = "x">a</td>', '<base href="https://x"><b>y</b>',
    '<a href="https://ok.example" onmouseover="x">a</a>', '<img src="data:image/svg+xml;base64,PHN2Zz4=">',
  ];
  for (const c of cases) {
    const r = cleanSignatureHtml(c);
    assert.ok(dbAccepts(r.html), `databáza by odmietla: ${c} → ${r.html}`);
    assert.ok(!/<script|<iframe|<form|<style|<svg|javascript:|\son[a-z]+\s*=/i.test(r.html), `${c} → ${r.html}`);
  }
  assert.equal(cleanSignatureHtml('<script>alert(1)</script>Text').html, 'Text');
  assert.equal(cleanSignatureHtml('<a href="javascript:alert(1)">klik</a>').html, '<span>klik</span>');
  assert.equal(cleanSignatureHtml('Text s data: a url(x) a only = 1').images.length, 0);
});

test('najviac 5 obrázkov, ďalšie sa vynechajú', () => {
  const html = [1, 2, 3, 4, 5, 6, 7].map((n) => `<img src="https://x.example/${n}.png">`).join('');
  const r = cleanSignatureHtml(html);
  assert.equal(r.images.length, 5);
  assert.equal((r.html.match(/<img/g) ?? []).length, 5);
});

test('typ obrázka z hlavičky súboru', () => {
  assert.equal(signatureImageType(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0])), 'image/png');
  assert.equal(signatureImageType(new Uint8Array([0xff, 0xd8, 0xff, 0xe0])), 'image/jpeg');
  assert.equal(signatureImageType(new Uint8Array([0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0])), 'image/gif');
  assert.equal(signatureImageType(new TextEncoder().encode('<svg></svg>')), null);
});
