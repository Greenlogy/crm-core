// Úzke bočné menu 88 px (na mobile spodná lišta) a obsah stránky – DESIGN_SPEC § 5.1, rozhodnutie 16. 10. 2026:
// Leady, Zmluvy k obchodom a Výnimky z ceny sú pod „Viac“; dole Upozornenia, Nastavenia, profil a prostredie.
// Iba svetlý režim.

import { useEffect, useRef, useState, type CSSProperties } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { useApi, type MenuCounts } from '../lib/api';
import { num } from '../lib/format';
import { ENVIRONMENT_LABEL, useMe } from '../lib/me';
import logoMark from '../assets/logo-mark.png';

export const Icon = (props: { d: string; className?: string }) => (
  <svg className={props.className ?? 'gl-icon'} viewBox="0 0 24 24" aria-hidden="true">
    <path d={props.d} />
  </svg>
);

// Ikony podľa referenčných obrazoviek (docs/design-handoff/reference)
export const ICONS = {
  home: 'M3 11l9-7 9 7v9a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z',
  company: 'M3 21h18M5 21V7l7-4 7 4v14M9 9h1m4 0h1M9 13h1m4 0h1M9 17h1m4 0h1',
  contacts: 'M9 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8M2 21c0-4 3-6 7-6s7 2 7 6M16 4a4 4 0 010 8M22 21c0-3-2-5-5-6',
  oom: 'M13 2L4 14h7l-1 8 9-12h-7z',
  deals: 'M4 4h4v16H4zM10 4h4v10h-4zM16 4h4v6h-4z',
  check: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14M21 21l-5-5',
  approve: 'M20 6L9 17l-5-5',
  contracts: 'M6 2h9l5 5v15H6zM14 2v6h6M9 12h6M9 16h6',
  pricelist: 'M20.6 13.4l-7.2 7.2a2 2 0 01-2.8 0L3 13V3h10l7.6 7.6a2 2 0 010 2.8zM7.5 9a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3',
  more: 'M5 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2M19 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0',
  settings: 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1',
  user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8M4 21c0-4 3.6-6 8-6s8 2 8 6',
  leads: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18M12 17a5 5 0 1 0 0-10 5 5 0 0 0 0 10M12 13a1 1 0 1 0 0-2 1 1 0 0 0 0 2',
  search: 'M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14M21 21l-4.3-4.3',
  plus: 'M12 5v14M5 12h14',
  lock: 'M5 11h14v10H5zM8 11V7a4 4 0 0 1 8 0v4',
  eye: 'M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6',
  mail: 'M3 5h18v14H3zM3 6l9 7 9-7',
  note: 'M4 4h16v12l-4 4H4zM16 20v-4h4M8 9h8M8 13h5',
  alert: 'M12 3 2 20h20zM12 10v4M12 17h.01',
  close: 'M6 6l12 12M18 6 6 18',
  // sharing: podanie rúk – symbol prepojenia (Peter 17. 10. 2026)
  sharing: 'M11 17l2 2a1 1 0 1 0 3-3M14 14l2.5 2.5a1 1 0 1 0 3-3l-3.88-3.88a3 3 0 0 0-4.24 0l-.88.88a1 1 0 1 1-3-3l2.81-2.81a5.79 5.79 0 0 1 7.06-.87l.47.28a2 2 0 0 0 1.42.25L21 4M21 3l1 11h-2M3 3L2 14l6.5 6.5a1 1 0 1 0 3-3M3 4h8',
  sun: 'M12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  download: 'M12 3v12M7 10l5 5 5-5M4 21h16',
  upload: 'M12 21V9M7 14l5-5 5 5M4 3h16',
};

// Položky pod „Viac“
const MORE = [
  { to: '/leady', label: 'Leady', icon: ICONS.leads },
  { to: '/zmluvy-k-obchodom', label: 'Zmluvy k obchodom', icon: ICONS.contracts },
  { to: '/vynimky', label: 'Výnimky z ceny', icon: ICONS.pricelist },
  // F7: provízie – iba kto ich smie vidieť (vlastné alebo všetky)
  { to: '/provizie', label: 'Provízie', icon: ICONS.deals, commissions: true },
];

export function Layout() {
  const me = useMe();
  const defaultOrg = me.orgs.find((o) => o.default) ?? me.orgs[0];
  const { data: counts } = useApi<MenuCounts>('/api/counts');
  // Zvonček: počet neprečítaných upozornení – obnoví sa pri zmene stránky a každých 5 minút
  const location = useLocation();
  const { data: bell, reload: reloadBell } = useApi<{ unread: number }>('/api/notifications/count');
  const { data: approvals, reload: reloadApprovals } = useApi<{ pending: number }>('/api/approvals/count');
  const [moreOpen, setMoreOpen] = useState(false);
  const [moreTop, setMoreTop] = useState(0);
  const moreButton = useRef<HTMLButtonElement>(null);
  const moreMenu = useRef<HTMLDivElement>(null);
  useEffect(() => {
    reloadBell();
    reloadApprovals();
    setMoreOpen(false);
  }, [location.pathname, reloadBell, reloadApprovals]);
  useEffect(() => {
    const t = window.setInterval(reloadBell, 5 * 60_000);
    return () => window.clearInterval(t);
  }, [reloadBell]);
  // „Viac“ sa zavrie klikom mimo alebo klávesom Escape
  useEffect(() => {
    if (!moreOpen) return;
    const onDown = (e: MouseEvent) => {
      const t = e.target as Node;
      if (!moreMenu.current?.contains(t) && !moreButton.current?.contains(t)) setMoreOpen(false);
    };
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setMoreOpen(false);
        moreButton.current?.focus();
      }
    };
    document.addEventListener('mousedown', onDown);
    document.addEventListener('keydown', onKey);
    return () => {
      document.removeEventListener('mousedown', onDown);
      document.removeEventListener('keydown', onKey);
    };
  }, [moreOpen]);

  const marketing = me.team_code === 'marketing';
  const settingsPath = me.is_admin
    ? '/nastavenia'
    : me.approves_prices
      ? '/nastavenia/cenove-parametre'
      : marketing
        ? '/nastavenia/sablony-emailov'
        : '/nastavenia/nocny-beh';
  const seesCommissions = me.is_admin || me.sees_all_commissions || (me.permissions.provizie?.view ?? 'nic') !== 'nic';
  const more = MORE.filter((m) => !('commissions' in m) || seesCommissions);
  const moreActive = more.some((m) => location.pathname === m.to);
  const item = 'gl-rail__item';

  return (
    <div className="gl-app">
      <nav className="gl-rail" aria-label="Hlavné menu">
        <img className="rail-logo" src={logoMark} alt="Greenlogy CRM" width={40} height={40} />

        <NavLink to="/domov" className={item}>
          <Icon d={ICONS.home} />
          Domov
        </NavLink>
        <NavLink to="/zakaznici" className={item}>
          <Icon d={ICONS.company} />
          Zákazníci
        </NavLink>
        <NavLink to="/kontakty" className={item}>
          <Icon d={ICONS.contacts} />
          Kontakty
        </NavLink>
        <NavLink to="/oom" end={false} className={item} title="Odberné miesta">
          <Icon d={ICONS.oom} />
          OOM
        </NavLink>
        <NavLink to="/obchody" end={false} className={item}>
          <Icon d={ICONS.deals} />
          Obchody
        </NavLink>
        <NavLink to="/overenie-firmy" className={item}>
          <Icon d={ICONS.check} />
          Overenie firmy
        </NavLink>
        <NavLink to="/schvalovanie" className={item} title="Schvaľovanie">
          <Icon d={ICONS.approve} />
          Schvaľ.
          {approvals && approvals.pending > 0 && (
            <span className="gl-rail__badge" aria-label={`${approvals.pending} na schválenie`}>
              {num(approvals.pending, 0)}
            </span>
          )}
        </NavLink>
        <NavLink to="/zmluvy" end={false} className={item}>
          <Icon d={ICONS.contracts} />
          Zmluvy
        </NavLink>
        <NavLink to="/cenniky" end={false} className={item}>
          <Icon d={ICONS.pricelist} />
          Cenníky
        </NavLink>
        <button
          ref={moreButton}
          type="button"
          className={`${item} rail-more${moreActive ? ' is-active' : ''}`}
          aria-haspopup="true"
          aria-expanded={moreOpen}
          aria-controls="rail-more-menu"
          onClick={(e) => {
            setMoreTop(e.currentTarget.getBoundingClientRect().top);
            setMoreOpen((o) => !o);
          }}
        >
          <Icon d={ICONS.more} />
          Viac
        </button>

        <div className="gl-rail__spacer" />

        <NavLink to="/upozornenia" className={item} title="Upozornenia">
          <Icon d={ICONS.bell} />
          Upozor&shy;nenia
          {bell && bell.unread > 0 && (
            <span className="gl-rail__badge rail-badge-alert" aria-label={`${bell.unread} neprečítaných`}>
              {num(bell.unread, 0)}
            </span>
          )}
        </NavLink>
        {(me.is_admin || me.approves_prices || me.can_see_job_runs || marketing) && (
          <NavLink to={settingsPath} className={item}>
            <Icon d={ICONS.settings} />
            Nastavenia
          </NavLink>
        )}
        <NavLink to="/profil" end className={item} title={`${me.name} · ${me.team_name} (${me.email}) – profil a podpis e-mailu`}>
          <Icon d={ICONS.user} />
          Profil
        </NavLink>
        <div className={`gl-rail__status env-${me.environment}`} title="Prostredie a spoločnosť">
          <span className="env-dot" aria-hidden="true" />
          <span>{ENVIRONMENT_LABEL[me.environment] ?? me.environment}</span>
          {defaultOrg && <span className="rail-status-org">{defaultOrg.name}</span>}
        </div>
      </nav>

      {moreOpen && (
        <div ref={moreMenu} id="rail-more-menu" className="rail-more-menu" role="menu" aria-label="Viac"
          style={{ '--rail-more-top': `${moreTop}px` } as CSSProperties}
        >
          {more.map((m) => (
            <NavLink key={m.to} to={m.to} className="rail-more-link" role="menuitem">
              <Icon d={m.icon} />
              <span>{m.label}</span>
              {m.to === '/leady' && counts && <span className="rail-more-count">{num(counts.leads, 0)}</span>}
            </NavLink>
          ))}
        </div>
      )}

      <main className="gl-main">
        <Outlet />
      </main>
    </div>
  );
}
