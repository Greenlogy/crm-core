// Prvky formulárov Nastavení (dizajn 11–16): pole s popisom, výber, zaškrtávacie pole,
// prepínač hodnôt, bočný panel a hlásenie chyby/úspechu.

import { useEffect, useRef, useState, type ReactNode } from 'react';
import { ApiError } from '../lib/api';

export function Field(props: { label: string; hint?: ReactNode; children: ReactNode; wide?: boolean }) {
  return (
    <label className={`fl${props.wide ? ' fl-wide' : ''}`}>
      {props.label}
      {props.children}
      {props.hint && <span className="fl-hint">{props.hint}</span>}
    </label>
  );
}

export function TextInput(props: {
  value: string;
  onChange: (v: string) => void;
  type?: string;
  placeholder?: string;
  maxLength?: number;
  autoFocus?: boolean;
  disabled?: boolean;
}) {
  return (
    <input
      className="inp"
      type={props.type ?? 'text'}
      value={props.value}
      placeholder={props.placeholder}
      maxLength={props.maxLength}
      autoFocus={props.autoFocus}
      disabled={props.disabled}
      onChange={(e) => props.onChange(e.target.value)}
    />
  );
}

export function Select<T extends string>(props: {
  value: T | '';
  onChange: (v: T) => void;
  options: { value: T; label: string }[];
  placeholder?: string;
  disabled?: boolean;
}) {
  return (
    <select
      className="inp"
      value={props.value}
      disabled={props.disabled}
      onChange={(e) => props.onChange(e.target.value as T)}
    >
      {props.placeholder !== undefined && (
        <option value="" disabled>
          {props.placeholder}
        </option>
      )}
      {props.options.map((o) => (
        <option key={o.value} value={o.value}>
          {o.label}
        </option>
      ))}
    </select>
  );
}

export function Check(props: { checked: boolean; onChange: (v: boolean) => void; children: ReactNode; disabled?: boolean }) {
  return (
    <label className={`ck${props.disabled ? ' ck-disabled' : ''}`}>
      <input
        type="checkbox"
        checked={props.checked}
        disabled={props.disabled}
        onChange={(e) => props.onChange(e.target.checked)}
      />
      {props.children}
    </label>
  );
}

export function Segmented<T extends string>(props: {
  value: T;
  onChange: (v: T) => void;
  options: { value: T; label: string; disabled?: boolean }[];
  label: string;
  small?: boolean;
}) {
  return (
    <div className={`segmented${props.small ? ' segmented-sm' : ''}`} role="group" aria-label={props.label}>
      {props.options.map((o) => (
        <button
          key={o.value}
          type="button"
          aria-pressed={props.value === o.value}
          disabled={o.disabled}
          onClick={() => props.onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

/** Bočný panel vpravo (úprava záznamu). Zatvorí sa klávesom Esc alebo klikom vedľa. */
export function SidePanel(props: { title: string; onClose: () => void; children: ReactNode; footer?: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && props.onClose();
    window.addEventListener('keydown', onKey);
    ref.current?.focus();
    return () => window.removeEventListener('keydown', onKey);
  }, [props.onClose]);
  return (
    <div className="panel-backdrop" onMouseDown={(e) => e.target === e.currentTarget && props.onClose()}>
      <div className="panel card" role="dialog" aria-modal="true" aria-label={props.title} tabIndex={-1} ref={ref}>
        <div className="panel-head">
          <h2>{props.title}</h2>
          <button type="button" className="btn btn-ghost" onClick={props.onClose} aria-label="Zavrieť">
            ✕
          </button>
        </div>
        <div className="panel-body">{props.children}</div>
        {props.footer && <div className="panel-foot">{props.footer}</div>}
      </div>
    </div>
  );
}

export function Notice(props: { tone: 'error' | 'ok'; children: ReactNode }) {
  return (
    <div className={props.tone === 'error' ? 'notice notice-error' : 'notice notice-ok'} role={props.tone === 'error' ? 'alert' : 'status'}>
      {props.children}
    </div>
  );
}

/** Uloženie s hlásením: busy počas požiadavky, error so správou z API. */
export function useSave() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  async function run<T>(fn: () => Promise<T>): Promise<T | undefined> {
    setBusy(true);
    setError(null);
    try {
      return await fn();
    } catch (err) {
      setError(err instanceof ApiError ? err.message : 'Uloženie zlyhalo.');
      return undefined;
    } finally {
      setBusy(false);
    }
  }
  return { busy, error, setError, run };
}
