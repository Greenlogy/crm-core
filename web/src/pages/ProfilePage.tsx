// Profil používateľa (modul 5, F4; 0042): údaje do podpisu e-mailu – funkcia, telefón, mobil, LinkedIn, fotka.
// Fotku prehliadač oreže na štvorec (stred), zmenší na 256 × 256 px a uloží ako JPEG do 300 kB; databáza overí typ,
// rozmer a veľkosť. Mení ju používateľ sám (admin aj v Nastaveniach → Používatelia). Náhľad podpisu ako v e-maile.

import { useEffect, useRef, useState } from 'react';
import { useParams } from 'react-router-dom';
import { CustomSignatureFrame, SignaturePreview } from '../components/email';
import { Field, Notice, Segmented, TextInput, useSave } from '../components/form';
import { Card, ErrorState, PageSkeleton, Pill } from '../components/ui';
import { send, useApi } from '../lib/api';

type Profile = {
  id: string; name: string; email: string; phone: string | null; mobile: string | null; job_title: string | null;
  linkedin_url: string | null; gmail_enabled: boolean; signature: { has_photo: boolean };
  custom: { mode: 'profil' | 'vlastny'; html: string | null; images: string[] };
};

const SIZE = 256;
const MAX = 300 * 1024;

/** Obrázok → štvorec zo stredu, 256 × 256 px, JPEG do 300 kB (base64). */
export async function squarePhoto(file: File): Promise<string> {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise<HTMLImageElement>((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = () => rej(new Error('Obrázok sa nedá načítať.'));
      i.src = url;
    });
    const side = Math.min(img.naturalWidth, img.naturalHeight);
    const canvas = document.createElement('canvas');
    canvas.width = SIZE;
    canvas.height = SIZE;
    const ctx = canvas.getContext('2d')!;
    ctx.fillStyle = '#ffffff';
    ctx.fillRect(0, 0, SIZE, SIZE);
    ctx.drawImage(img, (img.naturalWidth - side) / 2, (img.naturalHeight - side) / 2, side, side, 0, 0, SIZE, SIZE);
    for (const q of [0.9, 0.8, 0.7, 0.6, 0.5]) {
      const blob = await new Promise<Blob | null>((res) => canvas.toBlob(res, 'image/jpeg', q));
      if (blob && blob.size <= MAX) {
        const buf = new Uint8Array(await blob.arrayBuffer());
        let bin = '';
        for (let i = 0; i < buf.length; i += 0x8000) bin += String.fromCharCode(...buf.subarray(i, i + 0x8000));
        return btoa(bin);
      }
    }
    throw new Error('Fotka je po zmenšení stále väčšia ako 300 kB.');
  } finally {
    URL.revokeObjectURL(url);
  }
}

export function ProfileForm(props: { userId: string; onSaved?: () => void }) {
  const { data: p, error, reload } = useApi<Profile>(`/api/profiles/${props.userId}`);
  const [form, setForm] = useState({ phone: '', mobile: '', job_title: '', linkedin_url: '' });
  const [sigKey, setSigKey] = useState(0);
  const [msg, setMsg] = useState<string | null>(null);
  const save = useSave();
  useEffect(() => {
    if (p) setForm({ phone: p.phone ?? '', mobile: p.mobile ?? '', job_title: p.job_title ?? '', linkedin_url: p.linkedin_url ?? '' });
  }, [p]);
  if (error) return <ErrorState error={error} />;
  if (!p) return <PageSkeleton />;
  const done = (text: string) => {
    setMsg(text);
    reload();
    setSigKey((k) => k + 1);
    props.onSaved?.();
  };
  return (
    <>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {msg && <Notice tone="ok">{msg}</Notice>}
      <Card title="Údaje do podpisu e-mailu" aside={p.gmail_enabled ? <Pill tone="positive">Gmail zapnutý</Pill> : <Pill>Gmail vypnutý (pilot)</Pill>}>
        <div className="form-grid">
          <Field label="Funkcia">
            <TextInput value={form.job_title} maxLength={80} onChange={(v) => setForm({ ...form, job_title: v })} />
          </Field>
          <Field label="Mobil">
            <TextInput value={form.mobile} maxLength={40} onChange={(v) => setForm({ ...form, mobile: v })} />
          </Field>
          <Field label="Telefón">
            <TextInput value={form.phone} maxLength={40} onChange={(v) => setForm({ ...form, phone: v })} />
          </Field>
          <Field label="LinkedIn" hint="https://www.linkedin.com/in/…">
            <TextInput value={form.linkedin_url} maxLength={250} onChange={(v) => setForm({ ...form, linkedin_url: v })} />
          </Field>
        </div>
        <div className="row-actions">
          <button type="button" className="btn primary" disabled={save.busy} onClick={() => save.run(async () => {
            await send('PATCH', `/api/profiles/${props.userId}`, form);
            done('Profil uložený.');
          })}>
            Uložiť
          </button>
        </div>
      </Card>
      <Card title="Fotka do podpisu">
        <p className="caption">Orežeme ju na štvorec zo stredu a zmenšíme (do 300 kB). Fotka sa vloží do podpisu e-mailov z CRM.</p>
        <div className="row-actions">
          <label className="btn">
            {p.signature.has_photo ? 'Zmeniť fotku' : 'Nahrať fotku'}
            <input type="file" accept="image/jpeg,image/png" hidden onChange={(e) => {
              const f = e.target.files?.[0];
              e.target.value = '';
              if (f) void save.run(async () => {
                await send('PUT', `/api/profiles/${props.userId}/photo`, { data_base64: await squarePhoto(f) });
                done('Fotka uložená.');
              });
            }} />
          </label>
          {p.signature.has_photo && (
            <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
              await send('DELETE', `/api/profiles/${props.userId}/photo`);
              done('Fotka odstránená.');
            })}>
              Odstrániť fotku
            </button>
          )}
        </div>
      </Card>
      <CustomSignatureCard profile={p} userId={p.id} onSaved={(t) => done(t)} />
      <Card title="Náhľad podpisu">
        <SignaturePreview key={sigKey} userId={props.userId} />
        <p className="caption">Meno, e-mail, spoločnosť, adresa a web sa berú z CRM (meno a e-mail mení admin, údaje spoločnosti v Nastaveniach → Spoločnosť).</p>
      </Card>
    </>
  );
}

/**
 * Vlastný podpis (0044): vloženie cez Ctrl+V (napr. podpis skopírovaný z Gmailu) alebo HTML kód. CRM ho pri uložení
 * vyčistí, obrázky stiahne a uloží k podpisu; náhľad ukazuje uložený (vyčistený) podpis.
 */
function CustomSignatureCard(props: { profile: Profile; userId: string; onSaved: (text: string) => void }) {
  const p = props.profile;
  const [mode, setMode] = useState<'profil' | 'vlastny'>(p.custom.mode);
  const [tab, setTab] = useState<'vlozit' | 'kod'>('vlozit');
  const [code, setCode] = useState('');
  const pasteRef = useRef<HTMLDivElement>(null);
  const save = useSave();
  const submit = () => save.run(async () => {
    const html = mode === 'vlastny' ? (tab === 'kod' ? code : pasteRef.current?.innerHTML ?? '') : null;
    const r = await send<{ removed?: number; images?: number; images_failed?: number }>('PUT', `/api/profiles/${props.userId}/signature`, { mode, html });
    if (pasteRef.current) pasteRef.current.innerHTML = '';
    setCode('');
    props.onSaved(mode === 'profil'
      ? 'Používa sa podpis z profilu.'
      : `Vlastný podpis uložený${r.images ? ` · obrázky: ${r.images}` : ''}${r.images_failed ? ` · nepodarilo sa stiahnuť: ${r.images_failed}` : ''}${r.removed ? ` · odstránené nepovolené prvky: ${r.removed}` : ''}.`);
  });
  return (
    <Card title="Podpis e-mailu">
      {save.error && <Notice tone="error">{save.error}</Notice>}
      <Segmented label="Druh podpisu" value={mode} onChange={setMode} options={[{ value: 'profil', label: 'Z profilu' }, { value: 'vlastny', label: 'Vlastný (firemná norma)' }]} />
      {mode === 'vlastny' && (
        <>
          <p className="caption">
            Skopírujte firemný podpis (napr. z Gmailu → Nastavenia → Podpis) a vložte ho sem cez Ctrl+V, alebo vložte HTML kód. CRM odstráni
            skripty a sledovacie prvky, obrázky (najviac 5) stiahne a pošle ich ako súčasť e-mailu.
            {p.custom.mode === 'vlastny' ? ' Uložený podpis je v náhľade nižšie; nové vloženie ho nahradí.' : ''}
          </p>
          <Segmented label="Spôsob vloženia" small value={tab} onChange={setTab} options={[{ value: 'vlozit', label: 'Vložiť (Ctrl+V)' }, { value: 'kod', label: 'HTML kód' }]} />
          {tab === 'vlozit' ? (
            <div ref={pasteRef} className="inp sig-paste" contentEditable suppressContentEditableWarning aria-label="Sem vložte podpis (Ctrl+V)" />
          ) : (
            <textarea className="inp mail-body mono" rows={10} value={code} onChange={(e) => setCode(e.target.value)} aria-label="HTML kód podpisu" />
          )}
        </>
      )}
      <div className="row-actions">
        <button type="button" className="btn" disabled={save.busy} onClick={submit}>
          {save.busy ? 'Ukladám…' : mode === 'profil' ? 'Používať podpis z profilu' : 'Uložiť vlastný podpis'}
        </button>
      </div>
      {p.custom.mode === 'vlastny' && p.custom.html && <CustomSignatureFrame userId={props.userId} html={p.custom.html} />}
    </Card>
  );
}

/** /profil – vlastný profil; /profil/:id – profil iného používateľa (iba admin; stráži API a databáza). */
export function ProfilePage() {
  const { id } = useParams();
  return (
    <>
      <header className="page-head">
        <h1 className="t-page-title">{id ? 'Profil používateľa' : 'Môj profil'}</h1>
      </header>
      <ProfileForm key={id ?? 'me'} userId={id ?? 'me'} />
    </>
  );
}
