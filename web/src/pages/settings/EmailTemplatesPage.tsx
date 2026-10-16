// Nastavenia – Šablóny e-mailov (modul 5, F4; 0042): predmet a text e-mailov zákazníkom podľa druhu × jazyka.
// Platná verzia sa nemení: zmena = nový návrh (kópia), úprava, zverejnenie (doterajšia platná sa nahradí).
// Premenné «…» iba zo zoznamu povolených, «podpis» povinný – inak databáza uloženie odmietne. Mení admin a Marketing.

import { useState } from 'react';
import { Field, Notice, TextInput, useSave } from '../../components/form';
import { Card, ErrorState, Pill, Skeleton } from '../../components/ui';
import { send, useApi } from '../../lib/api';
import { date } from '../../lib/format';
import { SettingsHead } from './SettingsLayout';

type Tpl = {
  id: string; code: string; language: 'sk' | 'en'; version: number; status: 'navrh' | 'platna' | 'nahradena'; name: string;
  subject: string; body: string; note: string | null; created_at: string; published_at: string | null;
  created_by_name: string | null; published_by_name: string | null;
};

const CODE: Record<string, string> = {
  ponuka_dodavka: 'Ponuka – dodávka', ponuka_vykup: 'Ponuka – výkup', ponuka_viwa: 'Ponuka – Green VIWA',
  potvrdenie_akceptacie: 'Potvrdenie akceptácie', pripomienka_platnosti: 'Pripomienka platnosti', volny: 'Voľný e-mail',
};
const STATUS = {
  platna: { label: 'Platná', tone: 'positive' as const },
  navrh: { label: 'Návrh', tone: 'warning' as const },
  nahradena: { label: 'Nahradená', tone: 'neutral' as const },
};

export function EmailTemplatesPage() {
  const { data, error, reload } = useApi<{ items: Tpl[]; variables: string[]; can_edit: boolean }>('/api/settings/email-templates');
  const [sel, setSel] = useState<string | null>(null);
  const [showOld, setShowOld] = useState(false);
  if (error) return <ErrorState error={error} />;
  if (!data) return <Skeleton lines={8} />;
  const groups = Object.keys(CODE).flatMap((code) => (['sk', 'en'] as const).map((lang) => ({
    code, lang, items: data.items.filter((t) => t.code === code && t.language === lang),
  })));
  const current = data.items.find((t) => t.id === sel) ?? null;
  return (
    <>
      <SettingsHead title="Šablóny e-mailov" sub="Predmet a text e-mailov zákazníkom. «odkaz na ponuku» a «podpis» doplní CRM pri odoslaní." />
      <div className="columns">
        <div className="col-left">
          <Card title="Druhy a jazyky" aside={
            <label className="caption"><input type="checkbox" checked={showOld} onChange={(e) => setShowOld(e.target.checked)} /> aj nahradené</label>
          }>
            {groups.map((g) => (
              <div key={`${g.code}-${g.lang}`} className="tpl-group">
                <div className="tpl-head">{CODE[g.code]} · {g.lang.toUpperCase()}</div>
                {g.items.filter((t) => showOld || t.status !== 'nahradena').map((t) => (
                  <button key={t.id} type="button" className="chip" aria-pressed={sel === t.id} onClick={() => setSel(t.id)}>
                    v{t.version} <Pill tone={STATUS[t.status].tone}>{STATUS[t.status].label}</Pill>
                  </button>
                ))}
              </div>
            ))}
          </Card>
        </div>
        <div className="col-right">
          {current ? (
            <TemplateEditor key={current.id} tpl={current} variables={data.variables} canEdit={data.can_edit}
              hasDraft={data.items.some((t) => t.code === current.code && t.language === current.language && t.status === 'navrh')}
              onChanged={(id) => { if (id) setSel(id); reload(); }} />
          ) : (
            <Card title="Šablóna"><p className="caption">Vyberte šablónu vľavo.</p></Card>
          )}
          <Card title="Povolené premenné">
            <div className="mail-chips">{data.variables.map((v) => <span key={v} className="mail-chip">«{v}»</span>)}</div>
            <p className="caption">«oslovenie» je pole pri kontakte (prázdne = „Dobrý deň“); «zhrnutie variantov» predvyplní CRM z variantov ponuky a obchodník ho môže upraviť; «platnosť» doplní CRM podľa času odoslania.</p>
          </Card>
        </div>
      </div>
    </>
  );
}

function TemplateEditor(props: { tpl: Tpl; variables: string[]; canEdit: boolean; hasDraft: boolean; onChanged: (id?: string) => void }) {
  const t = props.tpl;
  const [name, setName] = useState(t.name);
  const [subject, setSubject] = useState(t.subject);
  const [body, setBody] = useState(t.body);
  const [note, setNote] = useState(t.note ?? '');
  const [ok, setOk] = useState<string | null>(null);
  const save = useSave();
  const draft = t.status === 'navrh' && props.canEdit;
  return (
    <Card title={`${CODE[t.code]} · ${t.language.toUpperCase()} · v${t.version}`} aside={<Pill tone={STATUS[t.status].tone}>{STATUS[t.status].label}</Pill>}>
      {save.error && <Notice tone="error">{save.error}</Notice>}
      {ok && <Notice tone="ok">{ok}</Notice>}
      <div className="caption">
        Vytvoril {t.created_by_name ?? 'CRM'} {date(t.created_at)}
        {t.published_at ? ` · zverejnil ${t.published_by_name ?? 'CRM'} ${date(t.published_at)}` : ''}
      </div>
      <Field label="Názov"><TextInput value={name} maxLength={120} disabled={!draft} onChange={setName} /></Field>
      <Field label="Predmet"><TextInput value={subject} maxLength={998} disabled={!draft} onChange={setSubject} /></Field>
      <Field label="Text">
        <textarea className="inp mail-body" value={body} rows={16} disabled={!draft} onChange={(e) => setBody(e.target.value)} />
      </Field>
      <Field label="Poznámka (nepovinné)"><TextInput value={note} maxLength={500} disabled={!draft} onChange={setNote} /></Field>
      {props.canEdit && (
        <div className="row-actions">
          {draft ? (
            <>
              <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
                await send('PATCH', `/api/settings/email-templates/${t.id}`, { name, subject, body, note });
                setOk('Návrh uložený.');
                props.onChanged();
              })}>Uložiť návrh</button>
              <button type="button" className="btn primary" disabled={save.busy} onClick={() => save.run(async () => {
                await send('PATCH', `/api/settings/email-templates/${t.id}`, { name, subject, body, note });
                await send('POST', `/api/settings/email-templates/${t.id}/publish`);
                setOk('Šablóna zverejnená – platí pre nové e-maily.');
                props.onChanged();
              })}>Zverejniť</button>
              <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
                await send('DELETE', `/api/settings/email-templates/${t.id}`);
                props.onChanged();
              })}>Zmazať návrh</button>
            </>
          ) : (
            !props.hasDraft && (
              <button type="button" className="btn" disabled={save.busy} onClick={() => save.run(async () => {
                const r = await send<{ id: string }>('POST', '/api/settings/email-templates', {
                  code: t.code, language: t.language, name: t.name, subject: t.subject, body: t.body, note: null,
                });
                props.onChanged(r.id);
              })}>Nová verzia (kópia)</button>
            )
          )}
        </div>
      )}
      {!draft && props.hasDraft && t.status !== 'navrh' && <p className="caption">Pre túto šablónu už je rozpracovaný návrh.</p>}
    </Card>
  );
}
