// Inventár HubSpotu (modul 0). Iba čítanie.
//
//   cd ~/projects/greenlogy/crm-core
//   node integrations/hubspot-sync/inventory/inventory.ts --check
//   node integrations/hubspot-sync/inventory/inventory.ts --collect [--refresh] [--only=counts,pipelines]
//   node integrations/hubspot-sync/inventory/inventory.ts --render

import { resolve } from 'node:path';
import { HubSpotClient, loadToken } from './client.ts';
import { collect, PORTAL_ID, SECTIONS, type Section } from './collect.ts';
import { render } from './render.ts';

const REQUIRED_SCOPES = [
  'crm.objects.contacts.read',
  'crm.objects.companies.read',
  'crm.objects.deals.read',
  'crm.objects.custom.read',
  'crm.objects.owners.read',
  'crm.objects.quotes.read',
  'crm.objects.products.read',
  'crm.objects.line_items.read',
  'crm.schemas.contacts.read',
  'crm.schemas.companies.read',
  'crm.schemas.deals.read',
  'crm.schemas.custom.read',
  'crm.objects.tickets.read',
  'crm.schemas.tickets.read',
  'automation',
  'automation.sequences.read',
  'content',
  'forms',
  'settings.users.read',
  'settings.users.teams.read',
  'communication_preferences.read',
];

const root = resolve(import.meta.dirname, '../../..');
const args = process.argv.slice(2);
const has = (flag: string) => args.includes(flag);

async function check(client: HubSpotClient): Promise<boolean> {
  const info = await client.tokenInfo();
  console.log(`Portál: ${info.hubId}${info.hubId === PORTAL_ID ? ' (správny)' : ` – OČAKÁVANÝ ${PORTAL_ID}!`}`);
  const missing = REQUIRED_SCOPES.filter((s) => !info.scopes.includes(s));
  const write = info.scopes.filter((s) => /\.write$/.test(s));
  console.log(`Scopes: ${info.scopes.length}, chýba ${missing.length}${missing.length ? `: ${missing.join(', ')}` : ''}`);
  if (write.length) console.warn(`Pozor, token má aj zapisovacie scopes: ${write.join(', ')}`);
  return info.hubId === PORTAL_ID;
}

async function main() {
  if (!has('--check') && !has('--collect') && !has('--render')) {
    console.log('Použitie: inventory.ts --check | --collect [--refresh] [--only=sekcia,…] | --render');
    console.log(`Sekcie: ${SECTIONS.join(', ')}`);
    return;
  }

  if (has('--check') || has('--collect')) {
    const client = new HubSpotClient(loadToken(root));
    const portalOk = await check(client);

    if (has('--collect')) {
      if (!portalOk) throw new Error('Token nepatrí do portálu Greenlogy, zber zastavený.');
      const onlyArg = args.find((a) => a.startsWith('--only='))?.slice('--only='.length);
      const only = onlyArg?.split(',') as Section[] | undefined;
      const unknown = only?.filter((s) => !SECTIONS.includes(s));
      if (unknown?.length) throw new Error(`Neznáme sekcie: ${unknown.join(', ')}`);

      const started = Date.now();
      await collect(client, root, { refresh: has('--refresh'), only });
      console.log(`Zber hotový: ${client.requestCount} požiadaviek, ${Math.round((Date.now() - started) / 1000)} s.`);
    }
  }

  if (has('--render')) {
    console.log('Generujem markdown:');
    render(root);
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : err);
  process.exit(1);
});
