// Hlavička s krajinou a sklenená lišta, ktorá prekrýva jej spodok (DESIGN_SPEC § 5.2, 5.3).
// Krajina je docs/design-handoff/assets/landscape-hero.svg bez zmeny (kópiu robí npm run tokens), vložená inline;
// lopatky turbín sa otáčajú cez .gl-spin, pri prefers-reduced-motion stoja.
// Krajina iba na Domove, zoznamoch a detailoch (rozhodnutie 16. 10. 2026), ostatné obrazovky majú .page-head.

import type { ReactNode } from 'react';
import landscape from '../assets/landscape-hero.svg?raw';

export function PageHero(props: {
  title: ReactNode;
  sub?: ReactNode;
  actions?: ReactNode;
  /** nad nadpisom (drobčeková navigácia) */
  above?: ReactNode;
  /** home 320 px, detail 290 px, inak 270 px */
  size?: 'home' | 'detail';
  /** karty (firma, osoba, OOM, zmluva): menší nadpis 36 px, aby dlhé názvy nezakryli turbíny (Peter 17. 10. 2026) */
  card?: boolean;
  label?: string;
}) {
  const cls = ['gl-hero', props.size && `gl-hero--${props.size}`, props.card && 'hero-card'].filter(Boolean).join(' ');
  return (
    <section className={cls} aria-label={props.label ?? 'Hlavička'}>
      <div className="gl-hero__art" aria-hidden="true" dangerouslySetInnerHTML={{ __html: landscape }} />
      <div className="gl-hero__content">
        <div className="hero-text">
          {props.above && <div className="hero-above">{props.above}</div>}
          <h1 className="gl-hero__title">{props.title}</h1>
          {props.sub && <div className="gl-hero__sub">{props.sub}</div>}
        </div>
        {props.actions && <div className="hero-actions">{props.actions}</div>}
      </div>
    </section>
  );
}

/** Sklenená lišta prekrývajúca krajinu – na obrazovke vždy jedna (filtre stavov, štádiá obchodu). */
export function GlassBar(props: { label: string; children: ReactNode; aside?: ReactNode }) {
  return (
    <section className="gl-overlap gl-glass gl-glassbar" aria-label={props.label}>
      {props.children}
      {props.aside && <div className="glassbar-aside">{props.aside}</div>}
    </section>
  );
}
