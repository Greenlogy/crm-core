// Chyby z databázy → odpoveď API so slovenskou správou.
// Správy z našich kontrol (RAISE EXCEPTION v migráciách) sú po slovensky a bez údajov záznamov,
// preto sa posielajú ďalej. Systémové správy PostgreSQL (anglicky, môžu obsahovať hodnoty)
// sa nahradia všeobecnou správou; do odpovede ide nanajvýš názov stĺpca alebo obmedzenia.

type PgError = {
  code?: string;
  routine?: string;
  message?: string;
  column_name?: string;
  constraint_name?: string;
};

export type ApiErrorBody = { error: string; code?: string; field?: string; constraint?: string };

/** null = nie je to chyba databázy, ktorú vieme vysvetliť (→ 500). */
export function dbErrorResponse(err: unknown): { status: 400 | 403 | 409; body: ApiErrorBody } | null {
  const e = err as PgError;
  if (!e || typeof e.code !== 'string') return null;
  // RAISE EXCEPTION z našich funkcií a spúšťačov
  const ours = e.routine === 'exec_stmt_raise' && typeof e.message === 'string';

  switch (e.code) {
    case '42501': // insufficient_privilege (aj RLS)
      return { status: 403, body: { error: ours ? e.message! : 'Na túto zmenu nemáte právo.', code: e.code } };
    case '23505': // unique_violation
      return {
        status: 409,
        body: { error: 'Záznam s týmito údajmi už existuje.', code: e.code, constraint: e.constraint_name },
      };
    case '23514': // check_violation
      return {
        status: 400,
        body: { error: ours ? e.message! : 'Údaje nespĺňajú pravidlá CRM.', code: e.code, constraint: e.constraint_name },
      };
    case '23503': // foreign_key_violation
      return {
        status: 400,
        body: {
          error: ours ? e.message! : 'Odkazovaný záznam neexistuje alebo sa ešte používa.',
          code: e.code,
          constraint: e.constraint_name,
        },
      };
    case '23502': // not_null_violation
      return { status: 400, body: { error: 'Chýba povinný údaj.', code: e.code, field: e.column_name } };
    case '22P02': // invalid_text_representation (neplatná hodnota výberu, uuid…)
    case '22007': // invalid_datetime_format
    case '22008': // datetime_field_overflow
    case '22001': // string_data_right_truncation
    case '22003': // numeric_value_out_of_range
      return { status: 400, body: { error: 'Neplatná hodnota.', code: e.code } };
    case 'P0001': // raise_exception
    case 'P0002': // no_data_found
      return { status: 400, body: { error: ours ? e.message! : 'Zmena sa nedá uložiť.', code: e.code } };
    default:
      return null;
  }
}
