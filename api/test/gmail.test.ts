// Testy F4 – Gmail (čisté funkcie, bez siete a databázy). Spustenie: cd api && npm test
// Peter 16. 10.: pri formáte full sa obsah všetkých častí s prílohami (aj malé vložené obrázky) hneď zahodí;
// ukladá sa iba vyčistený text správy a hlavičky potrebné pre vlákno.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readUrl, sendUrl } from '../src/gmail/endpoints.ts';
import { buildMime, cleanText, type GmailMessage, htmlToText, parseGmailMessage, recipientsAllowed, renderBody } from '../src/gmail/mime.ts';

const b64 = (s: string) => Buffer.from(s, 'utf8').toString('base64url');
const H = (name: string, value: string) => ({ name, value });
// neplatné base64 – ak by sa príloha dekódovala, atob vyhodí chybu (test tak overí, že sa obsah ani nečíta)
const POISON = '!!!toto-nie-je-base64!!!';

function message(parts: GmailMessage['payload']): GmailMessage {
  return { id: '18c2f0a1b2c3d4e5', threadId: '18c2f0a1b2c3d4e0', internalDate: '1792137600000', payload: parts };
}

const withAttachments = message({
  mimeType: 'multipart/mixed',
  headers: [
    H('From', '"Eva Testovacia" <Eva.T@Example.test>'),
    H('To', 'obchodnik@greenlogy.com, "Kolega, Ján" <jan@greenlogy.com>'),
    H('Cc', 'zla adresa, ina@example.test'),
    H('Subject', 'Re: Cenová ponuka P26-000123'),
    H('Message-ID', '<odpoved-1@mail.example.test>'),
  ],
  parts: [
    {
      mimeType: 'multipart/related',
      parts: [
        {
          mimeType: 'multipart/alternative',
          parts: [
            { mimeType: 'text/plain', headers: [H('Content-Type', 'text/plain; charset="UTF-8"')], body: { data: b64('Dobrý deň,\r\nponuku prijímame.\r\n\r\n\r\n\r\nS pozdravom Eva') } },
            { mimeType: 'text/html', body: { data: b64('<p>Dobrý deň, <b>HTML</b></p>') } },
          ],
        },
        // malý vložený obrázok (logo v podpise) – údaje priamo v správe
        { partId: '0.1', mimeType: 'image/png', filename: '', headers: [H('Content-ID', '<logo@x>'), H('Content-Disposition', 'inline')], body: { size: 120, data: POISON } },
      ],
    },
    { partId: '1', mimeType: 'application/pdf', filename: 'faktura.pdf', body: { size: 50_000, attachmentId: 'ANGjdJ8abc' } },
    // textová príloha s údajmi priamo v správe
    { partId: '2', mimeType: 'text/plain', filename: 'heslo.txt', headers: [H('Content-Disposition', 'attachment; filename="heslo.txt"')], body: { size: 20, data: POISON } },
    // vložená textová časť s Content-ID a vložený súbor s názvom
    { partId: '3', mimeType: 'text/plain', headers: [H('Content-ID', '<vlozene@x>')], body: { data: POISON } },
    { partId: '4', mimeType: 'text/plain', headers: [H('Content-Disposition', 'inline; filename="poznamky.txt"')], body: { data: POISON } },
  ],
});

test('format full: obsah príloh a vložených obrázkov sa zahodí bez dekódovania, ostane text a hlavičky vlákna', () => {
  const p = parseGmailMessage(withAttachments, 'obchodnik@greenlogy.com');
  assert.deepEqual(Object.keys(p).sort(), ['at', 'body_text', 'cc', 'direction', 'from', 'from_name', 'gmail_message_id', 'rfc_message_id', 'subject', 'to'].sort(),
    'iba text a hlavičky vlákna – žiadne prílohy, HTML ani zoznam súborov');
  assert.equal(p.body_text, 'Dobrý deň,\nponuku prijímame.\n\nS pozdravom Eva');
  const all = JSON.stringify(p);
  for (const s of ['faktura', 'heslo', 'poznamky', 'ANGjdJ8abc', 'vlozene', 'logo@x', POISON, 'HTML']) assert.ok(!all.includes(s), `výsledok neobsahuje „${s}“`);
  assert.equal(p.from, 'eva.t@example.test');
  assert.equal(p.from_name, 'Eva Testovacia');
  assert.deepEqual(p.to, ['obchodnik@greenlogy.com', 'jan@greenlogy.com']);
  assert.deepEqual(p.cc, ['ina@example.test'], 'neplatná adresa vypadne');
  assert.equal(p.subject, 'Re: Cenová ponuka P26-000123');
  assert.equal(p.rfc_message_id, '<odpoved-1@mail.example.test>');
  assert.equal(p.direction, 'prichadzajuca');
  assert.equal(p.at, new Date(1792137600000).toISOString());
});

test('správa iba s HTML: text bez skriptov, štýlov, obrázkov a značiek', () => {
  const m = message({
    mimeType: 'text/html',
    headers: [H('From', 'obchodnik@greenlogy.com'), H('Subject', '=?UTF-8?B?' + Buffer.from('Ďakujem').toString('base64') + '?=')],
    body: { data: b64('<style>p{}</style><script>alert(1)</script><p>Riadok&nbsp;1</p><img src="https://sledovanie.example/px.gif"><div>Riadok 2 &amp; <a href="https://greenlogy.com">web</a></div>') },
  });
  const p = parseGmailMessage(m, 'obchodnik@greenlogy.com');
  assert.equal(p.body_text, 'Riadok 1\nRiadok 2 & web (https://greenlogy.com)');
  assert.equal(p.subject, 'Ďakujem');
  assert.equal(p.direction, 'odchadzajuca', 'správa zo schránky obchodníka');
  assert.ok(!htmlToText('<img src=x onerror=alert(1)>ok').includes('img'));
});

test('textové prílohy pred telom správy (iba názov súboru, Content-ID, attachmentId) sa nečítajú', () => {
  const m = message({
    mimeType: 'multipart/mixed',
    headers: [H('From', 'a@example.test')],
    parts: [
      { mimeType: 'text/plain', filename: 'subor.txt', body: { data: POISON } },
      { mimeType: 'text/plain', headers: [H('Content-ID', '<c@x>')], body: { data: POISON } },
      { mimeType: 'text/html', body: { attachmentId: 'ANGjdJ8x', data: POISON } },
      { mimeType: 'text/csv', body: { data: POISON } },
      { mimeType: 'text/plain', body: { data: b64('Skutočný text') } },
    ],
  });
  assert.equal(parseGmailMessage(m, 'b@greenlogy.com').body_text, 'Skutočný text');
});

test('text/plain s attachmentId, „attachment“ alebo „inline“ s názvom sa nečíta – použije sa HTML telo', () => {
  for (const bad of [
    { mimeType: 'text/plain', body: { attachmentId: 'ANGjdJ8y', data: POISON } },
    { mimeType: 'text/plain', headers: [H('Content-Disposition', 'attachment')], body: { data: POISON } },
    { mimeType: 'text/plain', headers: [H('Content-Disposition', 'inline; filename="x.txt"')], body: { data: POISON } },
  ]) {
    const m = message({
      mimeType: 'multipart/mixed',
      headers: [H('From', 'a@example.test')],
      parts: [bad, { mimeType: 'text/html', body: { data: b64('<p>Telo HTML</p>') } }],
    });
    assert.equal(parseGmailMessage(m, 'b@greenlogy.com').body_text, 'Telo HTML');
  }
});

test('telo správy označené „inline“ bez názvu súboru (Apple Mail) sa zachová', () => {
  const m = message({
    mimeType: 'multipart/mixed',
    headers: [H('From', 'a@example.test')],
    parts: [
      { mimeType: 'text/plain', headers: [H('Content-Disposition', 'inline'), H('Content-Type', 'text/plain; charset=us-ascii')], body: { data: b64('Text tela') } },
      { mimeType: 'image/jpeg', headers: [H('Content-Disposition', 'inline; filename="IMG_1.jpg"')], body: { data: POISON } },
    ],
  });
  assert.equal(parseGmailMessage(m, 'b@greenlogy.com').body_text, 'Text tela');
});

test('správa iba s prílohou: prázdny text, nič z prílohy', () => {
  const m = message({
    mimeType: 'multipart/mixed',
    headers: [H('From', 'a@example.test')],
    parts: [{ mimeType: 'image/jpeg', filename: 'foto.jpg', body: { data: POISON } }],
  });
  const p = parseGmailMessage(m, 'b@greenlogy.com');
  assert.equal(p.body_text, '');
});

test('odkaz na stránku ponuky s tokenom sa z citovaného textu odstráni', () => {
  const token = 'A'.repeat(43);
  const t = cleanText(`Pozri > https://crm-ponuka.example.workers.dev/p/${token} a https://ponuka.greenlogy.com/p/${'b'.repeat(43)}`, 'https://crm-ponuka.example.workers.dev');
  assert.equal(t, 'Pozri > [odkaz na ponuku] a [odkaz na ponuku]');
});

test('adresy Gmail API: iba threads.get a messages.get, nikdy raw, attachments, list ani search', () => {
  assert.equal(readUrl('threads.get', 'obchodnik@greenlogy.com', '18c2f0a1b2c3d4e0', 'full'),
    'https://gmail.googleapis.com/gmail/v1/users/obchodnik%40greenlogy.com/threads/18c2f0a1b2c3d4e0?format=full');
  assert.match(readUrl('messages.get', 'o@greenlogy.com', 'abcdef12', 'metadata', ['Message-ID']), /messages\/abcdef12\?format=metadata&metadataHeaders=Message-ID$/);
  assert.throws(() => readUrl('attachments.get', 'o@greenlogy.com', 'abcdef12', 'full'), /nepovolená operácia/);
  assert.throws(() => readUrl('messages.list', 'o@greenlogy.com', 'abcdef12', 'full'), /nepovolená operácia/);
  assert.throws(() => readUrl('threads.get', 'o@greenlogy.com', 'abcdef12', 'raw'), /nepovolený formát/);
  assert.throws(() => readUrl('threads.get', 'o@greenlogy.com', 'abc?q=in:inbox', 'full'), /neplatné ID/);
  assert.throws(() => readUrl('threads.get', 'o@greenlogy.com/../x', 'abcdef12', 'full'), /neplatná schránka/);
  assert.equal(sendUrl('crm@greenlogy.com'), 'https://gmail.googleapis.com/gmail/v1/users/crm%40greenlogy.com/messages/send');
});

test('odosielaná správa: hlavičky bez vloženia ďalšej hlavičky, diakritika v predmete, prílohy', () => {
  const mime = buildMime({
    from: 'obchodnik@greenlogy.com', fromName: 'Ján Obchodník', to: ['eva@example.test'], replyTo: null,
    subject: 'Cenová ponuka\r\nBcc: zly@example.test', text: 'Text', html: '<p>Text</p>', messageId: '<crm-1@greenlogy.com>',
    references: ['<a@x>'], inReplyTo: '<a@x>',
    attachments: [{ filename: 'Cenova-ponuka-P26-000001.pdf', mime: 'application/pdf', data: new Uint8Array([37, 80, 68, 70]) }],
  });
  const head = mime.split('\r\n\r\n')[0];
  assert.ok(!/^Bcc:/m.test(head), 'zlom riadku v predmete nevytvorí hlavičku Bcc');
  assert.match(head, /^Subject: =\?UTF-8\?B\?/m);
  assert.match(head, /^In-Reply-To: <a@x>$/m);
  assert.match(mime, /Content-Disposition: attachment; filename="Cenova-ponuka-P26-000001.pdf"/);
  assert.throws(() => buildMime({ from: 'x@greenlogy.com', to: ['zla adresa'], subject: '', text: '', html: '', messageId: '<m@x>' }));
});

test('text e-mailu: odkaz a podpis až pri odoslaní, HTML escapované', () => {
  const sig = { name: 'Ján <b>', job_title: null, email: 'jan@greenlogy.com', phone: null, mobile: '+421 900', linkedin: null, company: 'Greenlogy a.s.', address: null, web: 'www.greenlogy.com', has_photo: false };
  const r = renderBody('Dobrý deň <script>,\n«odkaz na ponuku»\n«podpis»', 'https://p.example/p/TOKEN', sig, null);
  assert.ok(r.text.includes('https://p.example/p/TOKEN') && r.text.includes('Ján <b>'));
  assert.ok(!r.html.includes('<script>') && r.html.includes('&lt;script&gt;') && r.html.includes('Ján &lt;b&gt;'));
  assert.ok(!/<img/.test(r.html), 'bez sledovacích obrázkov');
});

test('Test posiela iba na @greenlogy.com a MAIL_ALLOWLIST; Ostré bez obmedzenia', () => {
  assert.deepEqual(recipientsAllowed(['a@greenlogy.com', 'povolena@example.test', 'x@example.test'], 'test', 'povolena@example.test'), ['x@example.test']);
  assert.deepEqual(recipientsAllowed(['x@example.test'], 'test', undefined), ['x@example.test'], 'bez zoznamu iba @greenlogy.com');
  assert.deepEqual(recipientsAllowed(['x@example.test'], 'ostre', undefined), []);
});
