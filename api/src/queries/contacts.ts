// Zoznam Kontakty – všetky osoby okrem archívu (zadanie čl. 9, 13; dizajn 09).
// Hľadanie podľa mena, e-mailu a telefónu (od 6 číslic, začiatok čísla v ľubovoľnom zápise cez normalize_phone).

import { customCondition, parseCustomFilter } from '../custom';
import type { Sql } from '../db';

export const CONTACT_PAGE_SIZE = 50;
// Rola vo firme = kód z číselníka rola_kontaktu (môže pribudnúť v Nastaveniach)
export const ROLE_FILTER = /^([a-z0-9_]{1,63})?$/;

export async function listContacts(
  sql: Sql,
  f: { q: string; role: string; cf?: string; page: number },
  pageSize = CONTACT_PAGE_SIZE,
) {
  const like = `%${f.q}%`;
  const { cond: customCond } = await customCondition(sql, ['osoba'], parseCustomFilter(f.cf), sql`p.custom`);
  const rows = await sql`
    SELECT p.id, concat_ws(' ', p.first_name, p.last_name) AS name, p.title, p.email, p.phone, p.mobile,
           p.is_household, p.status, p.is_producer,
           CASE WHEN p.is_producer THEN 'Domácnosť · výrobca' ELSE 'Domácnosť' END AS segment_label,
           p.marketing_allowed, p.marketing_opt_out_at, p.custom, p.org_id,
           coalesce((SELECT jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'roles', to_jsonb(cc.roles),
                                                         'is_main_contact', cc.is_main_contact,
                                                         'role_labels', coalesce((SELECT jsonb_agg(v.label ORDER BY v.sort_order)
                                                            FROM lookup_value v WHERE v.list_code = 'rola_kontaktu'
                                                             AND v.code = ANY (cc.roles)), '[]'::jsonb))
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
                                       WHERE cc.contact_id = p.id AND ${f.role} = ANY (cc.roles)))
       AND ${customCond}
     ORDER BY p.last_name, p.first_name, p.id
     LIMIT ${pageSize} OFFSET ${(f.page - 1) * pageSize}`;
  return {
    page: f.page,
    pageSize,
    total: rows[0]?.total ?? 0,
    items: rows.map(({ total: _t, ...r }) => r),
  };
}
