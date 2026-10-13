// Nastavenia: vnútorné menu (dizajn 11–16) a obsah sekcie. Iba pre admina.

import type { ReactNode } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { useMe } from '../../lib/me';

export const SETTINGS_SECTIONS = [
  { path: 'spolocnost', label: 'Spoločnosť' },
  { path: 'pouzivatelia', label: 'Používatelia' },
  { path: 'timy', label: 'Tímy a práva' },
  { path: 'ciselniky', label: 'Číselníky' },
  { path: 'parovanie-sadzieb', label: 'Párovanie sadzieb' },
  { path: 'vlastne-polia', label: 'Vlastné polia' },
  { path: 'pipelines', label: 'Pipelines a stage' },
  { path: 'audit', label: 'Audit' },
] as const;

export function SettingsLayout() {
  const me = useMe();
  if (!me.is_admin) {
    return <div className="error-box" role="alert">Nastavenia môže otvoriť iba admin.</div>;
  }
  return (
    <div className="settings">
      <nav className="settings-nav" aria-label="Nastavenia">
        <div className="settings-nav-label t-group-label">Nastavenia</div>
        {SETTINGS_SECTIONS.map((s) => (
          <NavLink key={s.path} to={`/nastavenia/${s.path}`} className={({ isActive }) => `snav${isActive ? ' active' : ''}`}>
            {s.label}
          </NavLink>
        ))}
        <div className="caption settings-nav-note">Mení iba admin. Každá zmena ide do auditu.</div>
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
