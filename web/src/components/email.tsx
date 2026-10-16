// Modul 5, F4 – e-maily z CRM (dizajn 37; návrh DB časti 28, 29): dialóg Nový e-mail (ponuka s odkazom a PDF,
// voľný e-mail z karty obchodu / firmy / kontaktu, koncept pripomienky), zoznam e-mailov a odpovedí v časovej osi.
// Odoslanie: jednorazový kľúč vznikne pri otvorení dialógu – dvojklik ani opakovaná požiadavka e-mail znova neodošle.
// «odkaz na ponuku» a «podpis» doplní CRM až pri odoslaní (odkaz s tokenom sa neukladá).

import { useEffect, useMemo, useState } from 'react';
import { ApiError, get, send, useApi } from '../lib/api';
import { dateTime } from '../lib/offers';
import { Notice, useSave } from './form';
import { Empty, Pill } from './ui';

export type EmailItem = {
  id: string; thread_id: string; thread_subject: string; direction: 'odchadzajuca' | 'prichadzajuca'; status: string; kind: string;
  offer_id: string | null; offer_number: string | null; from: string | null; from_name: string | null; to: string[]; cc: string[];
  subject: string; body: string; error: string | null; sent_at: string | null; received_at: string | null; at: string;
  author: string | null; mailbox: string | null; mine: boolean;
};

type Signature = {
  name: string; job_title: string | null; email: string; phone: string | null; mobile: string | null; linkedin: string | null;
  company: string; address: string | null; web: string | null; has_photo: boolean;
};
type Profile = { id: string; signature: Signature; custom: { mode: 'profil' | 'vlastny'; html: string | null; images: string[] } };

export const EMAIL_STATUS: Record<string, { label: string; tone: 'neutral' | 'positive' | 'warning' | 'negative' | 'info' }> = {
  koncept: { label: 'Koncept', tone: 'neutral' },
  v_rade: { label: 'Vo fronte', tone: 'info' },
  odosiela_sa: { label: 'Odosiela sa', tone: 'info' },
  odoslany: { label: 'Odoslaný', tone: 'positive' },
  chyba: { label: 'Chyba', tone: 'negative' },
  prijaty: { label: 'Prijatý', tone: 'positive' },
};
const KIND_LABEL: Record<string, string> = {
  ponuka: 'Ponuka', potvrdenie_akceptacie: 'Potvrdenie akceptácie', pripomienka_platnosti: 'Pripomienka platnosti', volny: 'E-mail', odpoved: 'Odpoveď',
};

const splitAddresses = (v: string) => v.split(/[\s,;]+/).map((x) => x.trim().toLowerCase()).filter(Boolean);
const initials = (n: string) => n.split(/\s+/).filter(Boolean).slice(0, 2).map((x) => x[0]!.toUpperCase()).join('');

/** Vlastný podpis (vyčistené HTML) v izolovanom rámci bez skriptov; obrázky cid: z úložiska podpisu. */
export function CustomSignatureFrame(props: { userId: string; html: string }) {
  const doc = props.html.replace(/src="cid:(sig[1-5])"/g, (_m, cid: string) => `src="/api/profiles/${props.userId}/signature-images/${cid}"`);
  return (
    <iframe className="mail-sig-frame" title="Náhľad podpisu" sandbox="allow-same-origin"
      srcDoc={`<!doctype html><meta charset="utf-8"><body style="margin:8px;font-family:Arial,sans-serif;font-size:13px;color:#222;background:#fff">${doc}</body>`} />
  );
}

/** Podpis z profilu alebo vlastný (náhľad ako v e-maile). */
export function SignaturePreview(props: { userId?: string }) {
  const { data } = useApi<Profile>(`/api/profiles/${props.userId ?? 'me'}`);
  if (!data) return null;
  if (data.custom.mode === 'vlastny' && data.custom.html) {
    return (
      <div className="mail-sig mail-sig-custom">
        <CustomSignatureFrame userId={data.id} html={data.custom.html} />
        <span className="caption">vlastný podpis</span>
      </div>
    );
  }
  const s = data.signature;
  return (
    <div className="mail-sig">
      {s.has_photo ? (
        <img className="mail-sig-photo" src={`/api/profiles/${data.id}/photo`} alt="" />
      ) : (
        <span className="mail-sig-photo mail-sig-initials">{initials(s.name)}</span>
      )}
      <div className="mail-sig-text">
        <div className="mail-sig-name">{s.name}</div>
        <div>
          {s.job_title ? `${s.job_title} | ` : ''}
          <strong>{s.company}</strong>
        </div>
        <div className="caption">
          {[s.address, s.phone && `T: ${s.phone}`, s.mobile && `M: ${s.mobile}`].filter(Boolean).join(' · ')}
        </div>
        <div className="caption">{[s.email, s.web].filter(Boolean).join(' · ')}</div>
      </div>
      <span className="caption">podpis z profilu</span>
    </div>
  );
}

type Source =
  | { offerId: string }
  | { dealId?: string; companyId?: string; personId?: string }
  | { draft: EmailItem };

type ComposeState = {
  draftId: string | null; kind: 'ponuka' | 'volny' | 'pripomienka_platnosti'; templateId: string | null;
  to: string; cc: string; subject: string; body: string; gmailEnabled: boolean; gmailConfigured: boolean; mailbox: string; environment: string;
};

/**
 * Dialóg Nový e-mail (37). Z ponuky: predvyplnená šablóna podľa druhu ponuky, odkaz a PDF; z karty: voľný e-mail;
 * koncept (napr. pripomienka platnosti): otvorí sa na úpravu a odoslanie jedným klikom.
 */
export function EmailComposer(props: { title: string; source: Source; onClose: () => void; onDone: () => void }) {
  const [st, setSt] = useState<ComposeState | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [result, setResult] = useState<{ tone: 'ok' | 'error'; text: string } | null>(null);
  const sendKey = useMemo(() => crypto.randomUUID(), []);
  const save = useSave();
  const src = props.source;
  const isOffer = 'offerId' in src;

  useEffect(() => {
    const load = async () => {
      if ('draft' in src) {
        const me = await get<{ gmail_enabled: boolean; mailbox: string; gmail_configured: boolean; environment: string }>('/api/emails/me');
        setSt({
          draftId: src.draft.id, kind: src.draft.kind === 'ponuka' ? 'ponuka' : src.draft.kind === 'pripomienka_platnosti' ? 'pripomienka_platnosti' : 'volny',
          templateId: null, to: src.draft.to.join(', '), cc: src.draft.cc.join(', '), subject: src.draft.subject, body: src.draft.body,
          gmailEnabled: me.gmail_enabled, gmailConfigured: me.gmail_configured, mailbox: me.mailbox, environment: me.environment,
        });
        return;
      }
      if ('offerId' in src) {
        const r = await get<{
          compose: { template_version_id: string; subject: string; body: string; to: string[] };
          draft: { id: string; to: string[]; cc: string[]; subject: string; body: string; error: string | null; status: string } | null;
          gmail_enabled: boolean; gmail_configured: boolean; mailbox: string; environment: string;
        }>(`/api/offers/${src.offerId}/email`);
        const d = r.draft;
        if (d?.error) setResult({ tone: 'error', text: d.error });
        setSt({
          draftId: d?.id ?? null, kind: 'ponuka', templateId: r.compose.template_version_id,
          to: (d?.to ?? r.compose.to).join(', '), cc: (d?.cc ?? []).join(', '), subject: d?.subject ?? r.compose.subject,
          body: d?.body ?? r.compose.body, gmailEnabled: r.gmail_enabled, gmailConfigured: r.gmail_configured, mailbox: r.mailbox, environment: r.environment,
        });
        return;
      }
      const q = new URLSearchParams();
      if (src.dealId) q.set('deal_id', src.dealId);
      if (src.companyId) q.set('company_id', src.companyId);
      if (src.personId) q.set('person_id', src.personId);
      const r = await get<{ template_version_id: string | null; subject: string; body: string; to: string[]; gmail_enabled: boolean; gmail_configured: boolean; mailbox: string; environment: string }>(`/api/emails/new?${q}`);
      setSt({
        draftId: null, kind: 'volny', templateId: r.template_version_id, to: r.to.join(', '), cc: '', subject: r.subject, body: r.body,
        gmailEnabled: r.gmail_enabled, gmailConfigured: r.gmail_configured, mailbox: r.mailbox, environment: r.environment,
      });
    };
    load().catch((e: unknown) => setLoadError(e instanceof ApiError ? e.message : 'E-mail sa nepodarilo pripraviť.'));
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && props.onClose();
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [props.onClose]);

  const saveDraft = async (s: ComposeState): Promise<string> => {
    const body: Record<string, unknown> = {
      id: s.draftId, kind: s.kind, template_version_id: s.templateId, to: splitAddresses(s.to), cc: splitAddresses(s.cc), subject: s.subject, body: s.body,
    };
    if (!s.draftId) {
      if ('offerId' in src) body.offer_id = src.offerId;
      else if (!('draft' in src)) Object.assign(body, { deal_id: src.dealId, company_id: src.companyId, person_id: src.personId });
    }
    const r = await send<{ id: string }>('POST', '/api/emails/drafts', body);
    setSt({ ...s, draftId: r.id });
    return r.id;
  };

  const onSend = () =>
    save.run(async () => {
      if (!st) return;
      const id = await saveDraft(st);
      try {
        const r = await send<{ state: string; offer_error?: string | null; repeated?: boolean }>('POST', `/api/emails/${id}/send`, { send_key: sendKey });
        if (r.state === 'odoslany' && r.offer_error) setResult({ tone: 'error', text: `E-mail odišiel, ale ponuka sa neoznačila ako odoslaná: ${r.offer_error}` });
        else if (r.state === 'odoslany') setResult({ tone: 'ok', text: isOffer ? 'E-mail s ponukou odišiel. Ponuka je Odoslaná.' : 'E-mail odišiel.' });
        else setResult({ tone: 'ok', text: 'E-mail odišiel, záznam sa dokončí o chvíľu.' });
      } catch (e) {
        setResult({ tone: 'error', text: e instanceof ApiError ? e.message : 'E-mail sa nepodarilo odoslať.' });
        throw e;
      }
    });

  const sent = result?.tone === 'ok';
  const testNote = st && st.environment !== 'ostre';
  return (
    <div className="modal-backdrop" onMouseDown={(e) => e.target === e.currentTarget && props.onClose()}>
      <div className="modal card" role="dialog" aria-modal="true" aria-label={props.title}>
        <div className="modal-head">
          <h2>{props.title}</h2>
          <button type="button" className="btn btn-ghost" onClick={sent ? props.onDone : props.onClose} aria-label="Zavrieť">✕</button>
        </div>
        <div className="modal-body">
          {loadError && <Notice tone="error">{loadError}</Notice>}
          {result && <Notice tone={result.tone}>{result.text}</Notice>}
          {!st && !loadError && <div className="caption">Pripravujem e-mail…</div>}
          {st && !sent && (
            <>
              {!st.gmailConfigured && <div className="ban ban-warn">Gmail ešte nie je v CRM nastavený – koncept sa dá uložiť, odoslať zatiaľ nie.</div>}
              {st.gmailConfigured && !st.gmailEnabled && (
                <div className="ban ban-warn">Odosielanie z Gmailu ešte nemáte zapnuté (pilot). Koncept si uložte; zapne ho admin v Nastaveniach → Používatelia.</div>
              )}
              <div className="mail-grid">
                <span className="mail-label">Od</span>
                <span>
                  {st.mailbox} <span className="caption">· odošle sa z vašej schránky Google Workspace</span>
                </span>
                <label className="mail-label" htmlFor="mail-to">Komu</label>
                <input id="mail-to" className="inp" value={st.to} onChange={(e) => setSt({ ...st, to: e.target.value })} />
                <label className="mail-label" htmlFor="mail-cc">Kópia</label>
                <input id="mail-cc" className="inp" value={st.cc} onChange={(e) => setSt({ ...st, cc: e.target.value })} />
                <label className="mail-label" htmlFor="mail-subject">Predmet</label>
                <input id="mail-subject" className="inp" value={st.subject} maxLength={998} onChange={(e) => setSt({ ...st, subject: e.target.value })} />
              </div>
              <textarea className="inp mail-body" aria-label="Text e-mailu" value={st.body} rows={14} onChange={(e) => setSt({ ...st, body: e.target.value })} />
              <div className="mail-chips">
                {st.body.includes('«odkaz na ponuku»') && <span className="mail-chip mail-chip-link">Odkaz na stránku ponuky</span>}
                {isOffer && <span className="mail-chip">PDF ponuky (vytvorí sa pri odoslaní)</span>}
                {st.body.includes('«platnosť»') && <span className="mail-chip">«platnosť» doplní CRM podľa času odoslania</span>}
              </div>
              {st.body.includes('«podpis»') ? <SignaturePreview /> : <div className="caption">Text neobsahuje «podpis» – podpis sa nepridá.</div>}
              {testNote && <p className="caption">Test: CRM pošle e-mail iba na adresy @greenlogy.com a povolené testovacie adresy.</p>}
            </>
          )}
        </div>
        <div className="modal-foot">
          <span className="caption">E-mail a odpovede v tomto vlákne sa uložia do časovej osi obchodu a zákazníka. Ostatnú poštu CRM nečíta.</span>
          {sent ? (
            <button type="button" className="btn primary" onClick={props.onDone}>Hotovo</button>
          ) : (
            <>
              <button type="button" className="btn" disabled={!st || save.busy} onClick={() => st && save.run(async () => {
                await saveDraft(st);
                setResult({ tone: 'ok', text: 'Koncept uložený.' });
                props.onDone();
              })}>
                Uložiť koncept
              </button>
              <button type="button" className="btn primary" disabled={!st || save.busy || !st.gmailEnabled || !st.gmailConfigured || !splitAddresses(st.to).length} onClick={onSend}>
                {save.busy ? (isOffer ? 'Vytváram PDF a odosielam…' : 'Odosielam…') : 'Odoslať'}
              </button>
            </>
          )}
        </div>
      </div>
    </div>
  );
}

/** E-maily a odpovede (obchod, firma, kontakt) – najnovšie hore; koncept otvorí dialóg, Chyba sa dá vrátiť do konceptu. */
export function EmailList(props: { query: string; source: { dealId?: string; companyId?: string; personId?: string }; title?: string }) {
  const { data, reload } = useApi<{ items: EmailItem[] }>(`/api/emails?${props.query}`);
  const [open, setOpen] = useState<string | null>(null);
  const [compose, setCompose] = useState<{ draft?: EmailItem } | null>(null);
  const save = useSave();
  const items = data?.items ?? [];
  return (
    <div className="mail-list">
      <div className="mail-list-head">
        {props.title ? <strong>{props.title}</strong> : <span className="caption">E-maily z CRM a odpovede zákazníkov v ich vláknach</span>}
        <button type="button" className="btn btn-sm" onClick={() => setCompose({})}>Nový e-mail</button>
      </div>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {items.length === 0 && <Empty>Zatiaľ žiadne e-maily z CRM.</Empty>}
      {items.map((m) => (
        <div key={m.id} className={`mail-item${m.direction === 'prichadzajuca' ? ' mail-in' : ''}`}>
          <button type="button" className="mail-item-head" onClick={() => setOpen(open === m.id ? null : m.id)} aria-expanded={open === m.id}>
            <span className="mail-item-title">
              {m.direction === 'prichadzajuca' ? '↩ ' : ''}
              {m.subject || '(bez predmetu)'}
            </span>
            <Pill tone={EMAIL_STATUS[m.status]?.tone ?? 'neutral'}>{EMAIL_STATUS[m.status]?.label ?? m.status}</Pill>
            <span className="caption">
              {KIND_LABEL[m.kind] ?? m.kind}
              {m.offer_number ? ` · ${m.offer_number}` : ''} · {m.direction === 'prichadzajuca' ? (m.from_name ?? m.from) : m.to.join(', ')} · {dateTime(m.at)}
            </span>
          </button>
          {open === m.id && (
            <div className="mail-item-body">
              <div className="caption">
                Od: {m.direction === 'prichadzajuca' ? `${m.from_name ? `${m.from_name} ` : ''}<${m.from}>` : (m.mailbox ?? m.from ?? 'crm@greenlogy.com')}
                {' · '}Komu: {m.to.join(', ')}{m.cc.length ? ` · Kópia: ${m.cc.join(', ')}` : ''}
                {m.author ? ` · ${m.author}` : ''}
              </div>
              {m.error && <Notice tone="error">{m.error}</Notice>}
              <pre className="mail-text">{m.body}</pre>
              <div className="row-actions">
                {m.status === 'koncept' && m.mine && (
                  <>
                    <button type="button" className="btn btn-sm primary" onClick={() => setCompose({ draft: m })}>Upraviť a odoslať</button>
                    <button type="button" className="btn btn-sm" disabled={save.busy} onClick={() => save.run(async () => {
                      await send('DELETE', `/api/emails/drafts/${m.id}`);
                      reload();
                    })}>
                      Zahodiť
                    </button>
                  </>
                )}
                {m.status === 'chyba' && m.mine && m.kind !== 'pripomienka_platnosti' && (
                  <button type="button" className="btn btn-sm" disabled={save.busy} onClick={() => save.run(async () => {
                    await send('POST', `/api/emails/${m.id}/retry`);
                    reload();
                  })}>
                    Skontroloval som Odoslané v Gmaile – späť do konceptu
                  </button>
                )}
              </div>
            </div>
          )}
        </div>
      ))}
      {compose && (
        <EmailComposer
          title={compose.draft ? (compose.draft.kind === 'pripomienka_platnosti' ? 'Pripomienka platnosti' : 'E-mail') : 'Nový e-mail'}
          source={compose.draft ? { draft: compose.draft } : props.source}
          onClose={() => setCompose(null)}
          onDone={() => {
            setCompose(null);
            reload();
          }}
        />
      )}
    </div>
  );
}
