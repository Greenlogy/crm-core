// Zoznam Kontakty – všetky osoby okrem archívu (zadanie čl. 9, 13; dizajn 09).
// Hľadanie podľa mena, e-mailu a telefónu (od 6 číslic, začiatok čísla v ľubovoľnom zápise cez normalize_phone).

import type { Sql } from '../db';

export const CONTACT_PAGE_SIZE = 50;
export const ROLE_FILTERS = new Set(['', 'statutar', 'decision_maker', 'kontaktna_osoba', 'fakturacia', 'technik']);

export async function listContacts(sql: Sql, f: { q: string; role: string; page: number }) {
  const like = `%${f.q}%`;
  const rows = await sql`
    SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.title, p.email, p.phone, p.mobile,
           p.is_household, p.status, p.is_producer,
           CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END AS segment_label,
           p.marketing_allowed, p.marketing_opt_out_at,
           coalesce((SELECT jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'roles', to_jsonb(cc.roles),
                                                         'is_main_contact', cc.is_main_contact)
                                      ORDER BY cc.is_main_contact DESC, c.name)
                       FROM company_contact cc JOIN company c ON c.id = cc.company_id
                      WHERE cc.contact_id = p.id), '[]'::jsonb) AS companies,
           count(*) OVER ()::int AS total
      FROM contact_v p
     WHERE NOT p.archived
       AND (${f.q} = ''
            OR concat_ws(' ', p.first_name, p.last_name) ILIKE ${like}
            OR concat_ws(' ', p.last_name, p.first_name) ILIKE ${like}
            OR p.email ILIKE ${like}
            OR (length(regexp_replace(${f.q}, '[^0-9]', '', 'g')) >= 6
                AND (p.phone_norm LIKE normalize_phone(${f.q}) || '%' OR p.mobile_norm LIKE normalize_phone(${f.q}) || '%')))
       AND (${f.role} = '' OR EXISTS (SELECT 1 FROM company_contact cc
                                       WHERE cc.contact_id = p.id AND cc.roles::text[] @> ARRAY[${f.role}]::text[]))
     ORDER BY p.last_name, p.first_name, p.id
     LIMIT ${CONTACT_PAGE_SIZE} OFFSET ${(f.page - 1) * CONTACT_PAGE_SIZE}`;
  return {
    page: f.page,
    pageSize: CONTACT_PAGE_SIZE,
    total: rows[0]?.total ?? 0,
    items: rows.map(({ total: _t, ...r }) => r),
  };
}
