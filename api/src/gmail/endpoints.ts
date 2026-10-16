// Jediné miesto, ktoré skladá adresy Gmail API (kontrola api/scripts/check-gmail.mjs v `npm run typecheck`).
// Čítanie: iba users.threads.get a users.messages.get vo formáte minimal / metadata / full, iba podľa ID vlákna
// alebo správy uloženej v CRM – nikdy list, search (q), history ani attachments.get, nikdy format=raw (0043).
// Odoslanie: users.messages.send.

export const READ_METHODS = ['threads.get', 'messages.get'] as const;
export const READ_FORMATS = ['minimal', 'metadata', 'full'] as const;
export type ReadMethod = (typeof READ_METHODS)[number];
export type ReadFormat = (typeof READ_FORMATS)[number];

const API = 'https://gmail.googleapis.com/gmail/v1/users';
const GMAIL_ID = /^[0-9a-f]{6,32}$/;
const MAILBOX = /^[^@\s/?#]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/;
const HEADER_NAME = /^[A-Za-z-]{1,40}$/;

/** Adresa čítania. Čokoľvek mimo povolených metód, formátov a ID vyhodí chybu (nevolá sa nič). */
export function readUrl(method: string, mailbox: string, id: string, format: string, metadataHeaders: string[] = []): string {
  if (!(READ_METHODS as readonly string[]).includes(method)) throw new Error(`Gmail: nepovolená operácia ${method}.`);
  if (!(READ_FORMATS as readonly string[]).includes(format)) throw new Error(`Gmail: nepovolený formát ${format}.`);
  if (!GMAIL_ID.test(id)) throw new Error('Gmail: neplatné ID.');
  if (!MAILBOX.test(mailbox)) throw new Error('Gmail: neplatná schránka.');
  if (format !== 'metadata' && metadataHeaders.length) throw new Error('Gmail: hlavičky iba pri formáte metadata.');
  const q = new URLSearchParams({ format });
  for (const h of metadataHeaders) {
    if (!HEADER_NAME.test(h)) throw new Error('Gmail: neplatná hlavička.');
    q.append('metadataHeaders', h);
  }
  const kind = method === 'threads.get' ? 'threads' : 'messages';
  return `${API}/${encodeURIComponent(mailbox)}/${kind}/${id}?${q.toString()}`;
}

/** Adresa odoslania (users.messages.send). */
export function sendUrl(mailbox: string): string {
  if (!MAILBOX.test(mailbox)) throw new Error('Gmail: neplatná schránka.');
  return `${API}/${encodeURIComponent(mailbox)}/messages/send`;
}

export const TOKEN_URL = 'https://oauth2.googleapis.com/token';
export const SCOPE_SEND = 'https://www.googleapis.com/auth/gmail.send';
export const SCOPE_READ = 'https://www.googleapis.com/auth/gmail.readonly';
