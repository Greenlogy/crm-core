// Nastavenia: vnútorné menu (dizajn 11–16, 24, 29) a obsah sekcie. Admin všetko; „schvaľuje ceny“ (obchodný riaditeľ)
// iba Cenové parametre (modul 4, rozhodnutie 7); Nákup iba Nočný beh (denník, 0028).

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
  { path: 'sablony-ponuk', label: 'Šablóny ponúk' },
  { path: 'sablony-emailov', label: 'Šablóny e-mailov', marketing: true },
  { path: 'preklady-importov', label: 'Preklady importov' },
  { path: 'vlastne-polia', label: 'Vlastné polia' },
  { path: 'pipelines', label: 'Pipelines a stage' },
  { path: 'audit', label: 'Audit' },
  { path: 'citanie-schranok', label: 'Čítanie schránok' },
  { path: 'nocny-beh', label: 'Nočný beh', jobs: true },
] as const;

export function SettingsLayout() {
  const me = useMe();
  const location = useLocation();
  const section = location.pathname.split('/')[2] ?? '';
  const marketing = me.team_code === 'marketing';
  if (!me.is_admin && !me.approves_prices && !me.can_see_job_runs && !marketing) {
    return <div className="error-box" role="alert">Nastavenia môže otvoriť iba admin.</div>;
  }
  // Bez admina iba povolené sekcie: Cenové parametre („schvaľuje ceny“), Nočný beh (Nákup)
  const allowed = (s: (typeof SETTINGS_SECTIONS)[number]) =>
    me.is_admin || ('approver' in s && s.approver && me.approves_prices) || ('jobs' in s && s.jobs && me.can_see_job_runs) ||
    ('marketing' in s && s.marketing && marketing);
  const sections = SETTINGS_SECTIONS.filter(allowed);
  if (!me.is_admin && !sections.some((s) => s.path === section)) {
    return <Navigate to={`/nastavenia/${sections[0].path}`} replace />;
  }
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
            : section === 'nocny-beh'
              ? 'Iba čítanie – vidí admin a Nákup.'
              : section === 'sablony-emailov'
                ? 'Mení admin a Marketing. Každá zmena ide do auditu.'
                : section === 'citanie-schranok'
                  ? 'Každé čítanie schránky cez Gmail – iba čítanie, nedá sa zmeniť ani zmazať.'
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
