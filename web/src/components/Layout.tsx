// Ľavé menu (logo, skupiny, stav dát a tmavý režim dole) a obsah stránky.

import { useEffect, useState } from 'react';
import { NavLink, Outlet } from 'react-router-dom';
import { SOURCE_NOTE } from '../lib/labels';

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
  customers: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75',
  oom: 'M13 2 3 14h9l-1 8 10-12h-9l1-8z',
  deals: 'M3 3h18v4H3zM5 7v14h14V7M9 11h6',
  contracts: 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8zM14 2v6h6M8 13h8M8 17h8',
  moon: 'M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z',
  sun: 'M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42',
};

export function Layout() {
  const [theme, setTheme] = useState<Theme>(initialTheme);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    try {
      localStorage.setItem('crm-theme', theme);
    } catch {
      // úložisko nemusí byť dostupné
    }
  }, [theme]);

  const disabled = (label: string, icon: string) => (
    <span className="nav" aria-disabled="true" title="V prototype nie je">
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
            <div className="logo-app">CRM · prototyp</div>
          </span>
        </div>

        <div className="group-label t-group-label">Obchod</div>
        <NavLink to="/zakaznici" className={({ isActive }) => `nav${isActive ? ' active' : ''}`}>
          <Icon d={ICONS.customers} />
          Zákazníci
        </NavLink>
        {disabled('Odberné miesta', ICONS.oom)}
        {disabled('Dealy', ICONS.deals)}
        {disabled('Zmluvy', ICONS.contracts)}

        <div className="sidebar-foot">
          <span className="caption">{SOURCE_NOTE}</span>
          <span className="caption">Iba na čítanie</span>
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
