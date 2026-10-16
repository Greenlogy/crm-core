// Prihlásený používateľ (/api/me) pre celú aplikáciu: meno, tím, admin, spoločnosti, práva.
// Frontend podľa práv iba skrýva, čo používateľ nesmie; skutočné obmedzenie je v databáze.

import { createContext, useContext, type ReactNode } from 'react';
import { useApi, type Me, type ModuleCode, type Permission } from './api';

const MeContext = createContext<Me | null>(null);

export function useMe(): Me {
  const me = useContext(MeContext);
  if (!me) throw new Error('useMe mimo MeProvider');
  return me;
}

export function permission(me: Me, module: ModuleCode): Permission {
  return me.permissions[module] ?? { view: 'nic', edit: 'nic', archive: false, export: false, import: false, edit_active: false };
}

/** Úvodná stránka podľa roly (F6, Peter 16. 10.): obchodník (interný aj externý) a tím Sales_internal Domov, ostatní Zákazníci. */
export function startPath(me: Me): string {
  return me.seller_type || me.team_code === 'sales_internal' ? '/domov' : '/zakaznici';
}

export const ENVIRONMENT_LABEL: Record<string, string> = { test: 'Test', ostre: 'Ostré' };

export function MeProvider(props: { children: ReactNode }) {
  const { data, error, loading } = useApi<Me>('/api/me');
  if (loading && !data) return <div className="gate" aria-busy="true" />;
  if (error?.status === 401 || error?.status === 403) {
    return (
      <div className="gate">
        <div className="card gate-card" role="alert">
          <h1>Nemáte prístup do CRM</h1>
          <p className="muted">
            {error.status === 401
              ? 'Prihlásenie vypršalo alebo neprebehlo. Obnovte stránku a prihláste sa znova.'
              : 'Váš účet nie je v Greenlogy CRM aktívny. Obráťte sa na administrátora.'}
          </p>
        </div>
      </div>
    );
  }
  if (error || !data) {
    return (
      <div className="gate">
        <div className="error-box" role="alert">
          {error?.status === 0 ? 'API nie je dostupné. Beží api/dev.sh?' : (error?.message ?? 'Chyba načítania.')}
        </div>
      </div>
    );
  }
  return <MeContext.Provider value={data}>{props.children}</MeContext.Provider>;
}
