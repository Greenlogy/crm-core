// Prihlásenie cez Cloudflare Access (rozhodnutie 2026-10-12).
// Access pustí k Workeru iba prihláseného; Worker aj tak overí podpis tokenu Cf-Access-Jwt-Assertion
// (kľúče tímu Access, AUD aplikácie), lebo ctx.access za statickými súbormi nedostane.
// Z tokenu sa berie iba e-mail; či smie do CRM, rozhodne zoznam používateľov (app_user_login).
// E-mail ani token nejdú do logu.

import { createRemoteJWKSet, jwtVerify } from 'jose';

export type AuthEnv = {
  ACCESS_TEAM_DOMAIN: string; // https://greenlogy.cloudflareaccess.com
  ACCESS_AUD: string;
  DEV_USER_EMAIL?: string; // iba lokálne (dev.sh: wrangler dev --var); na Cloudflare sa nenastavuje
};

// Kľúče Access sa načítajú raz na inštanciu Workera a jose ich obnovuje sám.
let jwks: ReturnType<typeof createRemoteJWKSet> | undefined;
let jwksDomain = '';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1']);

/** E-mail prihláseného z overeného tokenu Access; null = neprihlásený alebo neplatný token. */
export async function accessEmail(req: Request, env: AuthEnv): Promise<string | null> {
  const token = req.headers.get('cf-access-jwt-assertion');

  // Lokálny vývoj bez Access: iba na localhost a iba ak dev.sh nastavil DEV_USER_EMAIL.
  if (!token) {
    const host = new URL(req.url).hostname;
    return env.DEV_USER_EMAIL && LOCAL_HOSTS.has(host) ? env.DEV_USER_EMAIL : null;
  }

  if (!env.ACCESS_TEAM_DOMAIN || !env.ACCESS_AUD) return null;
  if (!jwks || jwksDomain !== env.ACCESS_TEAM_DOMAIN) {
    jwks = createRemoteJWKSet(new URL(`${env.ACCESS_TEAM_DOMAIN}/cdn-cgi/access/certs`));
    jwksDomain = env.ACCESS_TEAM_DOMAIN;
  }
  try {
    const { payload } = await jwtVerify(token, jwks, {
      issuer: env.ACCESS_TEAM_DOMAIN,
      audience: env.ACCESS_AUD,
    });
    return typeof payload.email === 'string' && payload.email !== '' ? payload.email : null;
  } catch {
    return null;
  }
}
