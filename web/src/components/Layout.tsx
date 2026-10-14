// Ľavé menu (logo, skupiny; dole Nastavenia pre admina, prostredie, používateľ, tmavý režim) a obsah stránky.

import { useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useApi, type MenuCounts } from '../lib/api';
import { num } from '../lib/format';
import { ENVIRONMENT_LABEL, useMe } from '../lib/me';

type Theme = 'light' | 'dark';

function initialTheme(): Theme {
  try {
    const saved = localStorage.getItem('crm-theme');
    if (saved === 'light' || saved === 'dark') return saved;
  } catch {
    // úložisko nemusí byť dostupné
  }
  return window.matchMedia?.('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

const Icon = (props: { d: string }) => (
  <svg className="ic" viewBox="0 0 24 24" aria-hidden="true">
    <path d={props.d} />
  </svg>
);

const ICONS = {
  company: 'M3 21h18M5 21V7l7-4 7 4v14M9 9h1m4 0h1M9 13h1m4 0h1M9 17h1m4 0h1',
  leads: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2',
  customers: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  oom: 'M13 2 3 14h9l-1 8 10-12h-9l1-8z',
  deals: 'M3 3h18v4H3zM5 7v14h14V7M9 11h6',
  contracts: 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M8 13h8M8 17h8',
  moon: 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0',
  pricelist: 'M20.59 13.41 13.42 20.58a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82M7 7h.01',
  sun: 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42',
};

export function Layout() {
  const me = useMe();
  const defaultOrg = me.orgs.find((o) => o.default) ?? me.orgs[0];
  const [theme, setTheme] = useState<Theme>(initialTheme);
  const { data: counts } = useApi<MenuCounts>('/api/counts');
  // Zvonček: počet neprečítaných upozornení – obnoví sa pri zmene stránky a každých 5 minút
  const location = useLocation();
  const { data: bell, reload: reloadBell } = useApi<{ unread: number }>('/api/notifications/count');
  useEffect(() => {
    reloadBell();
  }, [location.pathname, reloadBell]);
  useEffect(() => {
    const t = window.setInterval(reloadBell, 5 * 60_000);
    return () => window.clearInterval(t);
  }, [reloadBell]);
  const settingsPath = me.is_admin
    ? '/nastavenia'
    : me.approves_prices
      ? '/nastavenia/cenove-parametre'
      : '/nastavenia/nocny-beh';
  const navClass = ({ isActive }: { isActive: boolean }) => `nav${isActive ? ' active' : ''}`;

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem('crm-theme', theme);
    } catch {
      // úložisko nemusí byť dostupné
    }
  }, [theme]);

  const disabled = (label: string, icon: string) => (
    <span className="nav" aria-disabled="true" title="Pripravuje sa">
      <Icon d={icon} />
      {label}
    </span>
  );

  return (
    <div className="app">
      <nav className="sidebar" aria-label="Hlavné menu">
        <div className="logo">
          <span className="logo-mark" aria-hidden="true">
            <svg className="ic" viewBox="0 0 24 24" style={{ fill: 'currentColor', stroke: 'none' }}>
              <path d={ICONS.oom} />
            </svg>
          </span>
          <span>
            <div className="logo-name">Greenlogy</div>
            <div className="logo-app">CRM</div>
          </span>
        </div>

        <div className="group-label t-group-label">Obchod</div>
        <NavLink to="/zakaznici" className={navClass}>
          <Icon d={ICONS.company} />
          Zákazníci
        </NavLink>
        <NavLink to="/leady" className={navClass}>
          <Icon d={ICONS.leads} />
          Leady
          {counts && <span className="nav-count">{num(counts.leads, 0)}</span>}
        </NavLink>
        <NavLink to="/kontakty" className={navClass}>
          <Icon d={ICONS.customers} />
          Kontakty
        </NavLink>
        <NavLink to="/oom" end={false} className={navClass}>
          <Icon d={ICONS.oom} />
          Odberné miesta
        </NavLink>
        {disabled('Dealy', ICONS.deals)}
        <NavLink to="/zmluvy" end={false} className={navClass}>
          <Icon d={ICONS.contracts} />
          Zmluvy
        </NavLink>
        <NavLink to="/vynimky" className={navClass}>
          <Icon d={ICONS.pricelist} />
          Výnimky z ceny
        </NavLink>
        <NavLink to="/cenniky" end={false} className={navClass}>
          <Icon d={ICONS.pricelist} />
          Cenníky
        </NavLink>

        <div className="sidebar-foot">
          <NavLink to="/upozornenia" className={navClass}>
            <Icon d={ICONS.bell} />
            Upozornenia
            {bell && bell.unread > 0 && (
              <span className="nav-count nav-count-alert" aria-label={`${bell.unread} neprečítaných`}>
                {num(bell.unread, 0)}
              </span>
            )}
          </NavLink>
          {(me.is_admin || me.approves_prices || me.can_see_job_runs) && (
            <NavLink to={settingsPath} className={navClass}>
              <Icon d={ICONS.settings} />
              Nastavenia
            </NavLink>
          )}
          <div className={`env-badge env-${me.environment}`} title="Prostredie a spoločnosť">
            <span className="env-dot" aria-hidden="true" />
            {ENVIRONMENT_LABEL[me.environment] ?? me.environment}
            {defaultOrg ? ` · ${defaultOrg.name}` : ''}
          </div>
          <span className="caption" title={me.email}>
            {me.name} · {me.team_name}
          </span>
          <button type="button" className="nav" onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
            <Icon d={theme === 'dark' ? ICONS.sun : ICONS.moon} />
            {theme === 'dark' ? 'Svetlý režim' : 'Tmavý režim'}
          </button>
        </div>
      </nav>
      <main className="main">
        <Outlet />
      </main>
    </div>
  );
}
