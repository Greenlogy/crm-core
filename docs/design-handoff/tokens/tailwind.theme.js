// Greenlogy CRM – rozšírenie témy pre Tailwind (ak ho appka používa).
// Použitie: v tailwind.config.js -> theme: { extend: require('./tokens/tailwind.theme.js') }
// Hodnoty sú zhodné s tokens/tokens.css.
module.exports = {
  colors: {
    brand: { green: '#05d695', blue: '#13689e' },
    gl: {
      green: { 50: '#e3f8f0', 400: '#2fd09c', 700: '#0b7a57' },
      blue: { 50: '#e6f0f7', 100: '#cfe2ef', 200: '#9cc3dd', 400: '#5a9bc9', 600: '#2f78ab', 700: '#13689e' },
      ink: { DEFAULT: '#1d3a4f', 2: '#3f5868', muted: '#5c7080' },
      neutral: { 400: '#a9b7c2' },
      page: '#f4f8f8',
      card: '#ffffff',
      hover: '#f6fafb',
      shade: '#f3f8fb',
      border: { DEFAULT: '#e4eef0', strong: '#d6e4ea', divider: '#f0f5f6' },
      ok: { bg: '#e3f8f0', fg: '#0b7a57' },
      info: { bg: '#e6f0f7', fg: '#13689e' },
      warn: { bg: '#fff3df', fg: '#94500c' },
      danger: { bg: '#fdebe9', fg: '#b42318' },
      muted: { bg: '#eef2f4', fg: '#55697a' },
    },
  },
  fontFamily: {
    sans: ['Lexend', 'system-ui', '-apple-system', 'sans-serif'],
    mono: ['"Geist Mono"', 'ui-monospace', 'Menlo', 'monospace'],
  },
  fontSize: {
    display: ['48px', { lineHeight: '1', letterSpacing: '-0.03em', fontWeight: '600' }],
    h1: ['44px', { lineHeight: '1', letterSpacing: '-0.03em', fontWeight: '600' }],
    h2: ['19px', { lineHeight: '1.25', fontWeight: '600' }],
    'kpi-xl': ['54px', { lineHeight: '1', letterSpacing: '-0.03em', fontWeight: '600' }],
    'kpi-lg': ['42px', { lineHeight: '1', letterSpacing: '-0.02em', fontWeight: '600' }],
    kpi: ['32px', { lineHeight: '1', letterSpacing: '-0.02em', fontWeight: '600' }],
  },
  borderRadius: { field: '12px', tile: '14px', item: '16px', bar: '20px', card: '22px', hero: '28px' },
  boxShadow: {
    card: '0 1px 2px rgba(29,58,79,.04), 0 12px 32px -20px rgba(29,58,79,.22)',
    glass: '0 10px 30px -14px rgba(19,104,158,.28)',
  },
  backgroundImage: {
    'gl-soft': 'linear-gradient(135deg, #c9f3e3 0%, #cfe3f1 100%)',
    'gl-calc': 'linear-gradient(160deg, #eaf8f2 0%, #e7f1f8 100%)',
    'gl-sky': 'linear-gradient(180deg, #d9efe3 0%, #eef3e6 55%, #f7efdc 100%)',
    'gl-brand': 'linear-gradient(135deg, #05d695 0%, #13689e 100%)',
  },
  spacing: { rail: '88px' },
};
