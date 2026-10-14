// Nastavenia: vnútorné menu (dizajn 11–16, 24, 29) a obsah sekcie. Admin všetko; „schvaľuje ceny“ (obchodný riaditeľ)
// iba Cenové parametre (modul 4, rozhodnutie 7).

import type { ReactNode } from 'react';
import { Navigate, NavLink, Outlet, useLocation } from 'react-router-dom';
import { useMe } from '../../lib/me';

export const SETTINGS_SECTIONS = [
  { path: 'spolocnost', label: 'Spoločnosť' },
  { path: 'pouzivatelia', label: 'Používatelia' },
  { path: 'timy', label: 'Tímy a práva' },
  { path: 'ciselniky', label: 'Číselníky' },
  { path: 'parovanie-sadzieb', label: 'Párovanie sadzieb' },
  { path: 'cenove-parametre', label: 'Cenové parametre', approver: true },
  { path: 'preklady-importov', label: 'Preklady importov' },
  { path: 'vlastne-polia', label: 'Vlastné polia' },
  { path: 'pipelines', label: 'Pipelines a stage' },
  { path: 'audit', label: 'Audit' },
] as const;

export function SettingsLayout() {
  const me = useMe();
  const location = useLocation();
  const section = location.pathname.split('/')[2] ?? '';
  if (!me.is_admin && !me.approves_prices) {
    return <div className="error-box" role="alert">Nastavenia môže otvoriť iba admin.</div>;
  }
  // Obchodný riaditeľ bez admina: iba Cenové parametre
  if (!me.is_admin && section !== 'cenove-parametre') {
    return <Navigate to="/nastavenia/cenove-parametre" replace />;
  }
  const sections = SETTINGS_SECTIONS.filter((s) => me.is_admin || ('approver' in s && s.approver));
  return (
    <div className="settings">
      <nav className="settings-nav" aria-label="Nastavenia">
        <div className="settings-nav-label t-group-label">Nastavenia</div>
        {sections.map((s) => (
          <NavLink key={s.path} to={`/nastavenia/${s.path}`} className={({ isActive }) => `snav${isActive ? ' active' : ''}`}>
            {s.label}
          </NavLink>
        ))}
        <div className="caption settings-nav-note">
          {section === 'cenove-parametre'
            ? 'Mení admin a obchodný riaditeľ. Každá zmena ide do auditu.'
            : 'Mení iba admin. Každá zmena ide do auditu.'}
        </div>
      </nav>
      <div className="settings-body">
        <Outlet />
      </div>
    </div>
  );
}

/** Hlavička sekcie Nastavení: názov, podnadpis, tlačidlá vpravo. */
export function SettingsHead(props: { title: string; sub?: string; actions?: ReactNode }) {
  return (
    <section className="page-head" aria-label="Hlavička">
      <div className="settings-title">
        <h1>{props.title}</h1>
        {props.sub && <span className="page-sub">{props.sub}</span>}
      </div>
      {props.actions && <div className="head-actions">{props.actions}</div>}
    </section>
  );
}
