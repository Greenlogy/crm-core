// PDF z HTML cez Cloudflare Browser Run (binding BROWSER, @cloudflare/puppeteer). Jedno vykreslenie na požiadavku;
// prehliadač sa vždy zavrie. HTML má obrázky vložené (data:), takže stránka nič nesťahuje.

import puppeteer from '@cloudflare/puppeteer';

export async function htmlToPdf(browser: Fetcher, html: string, footerHtml: string): Promise<Uint8Array> {
  const b = await puppeteer.launch(browser);
  try {
    const page = await b.newPage();
    await page.setContent(html, { waitUntil: 'load' });
    const pdf = await page.pdf({
      format: 'A4',
      printBackground: true,
      preferCSSPageSize: true,
      displayHeaderFooter: true,
      headerTemplate: '<span></span>',
      footerTemplate: footerHtml,
    });
    return new Uint8Array(pdf);
  } finally {
    await b.close();
  }
}

export async function sha256Hex(data: Uint8Array | string): Promise<string> {
  const bytes = typeof data === 'string' ? new TextEncoder().encode(data) : data;
  const d = await crypto.subtle.digest('SHA-256', bytes);
  return [...new Uint8Array(d)].map((x) => x.toString(16).padStart(2, '0')).join('');
}
