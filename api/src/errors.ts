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

// Zrozumiteľnejšia správa pri známych obmedzeniach (názov z migrácií).
const CONSTRAINT_MESSAGES: Record<string, string> = {
  app_user_email_key: 'Používateľ s týmto e-mailom už existuje.',
  team_name_key: 'Tím s týmto názvom už existuje.',
  team_code_key: 'Tím s podobným názvom už existuje.',
  team_permission_edit_le_view_check: 'Upravovať nemožno viac, ako tím vidí.',
  team_external_check: 'Externý tím nemôže vidieť všetky spoločnosti ani meniť vlastníkov.',
  app_user_email_check: 'E-mail nemá správny tvar.',
  org_day_off_org_id_date_key: 'Tento deň už je voľný (sviatok alebo firemné voľno).',
  org_bank_account_org_id_iban_key: 'Tento účet už je zadaný.',
  org_bank_account_iban_check: 'IBAN nemá správny tvar (napr. SK31 1200 0000 1987 4263 7541).',
  org_work_hours_check: 'Koniec pracovného času musí byť po začiatku.',
  org_legal_name_check: 'Chýba obchodné meno.',
  company_country_ico_key: 'Firma s týmto IČO / OIB už v CRM je.',
  company_ico_format_check: 'IČO musí mať 8 číslic (SK, CZ), OIB 11 číslic (HR).',
  company_kind_check: 'Vyberte aspoň jedno označenie: zákazník, partner alebo dodávateľ.',
  company_name_check: 'Chýba názov firmy.',
  contact_name_check: 'Chýba meno alebo priezvisko.',
  contact_reachable_check: 'Zadajte e-mail alebo telefón.',
  contact_email_format_check: 'E-mail nemá správny tvar.',
  company_contact_company_id_contact_id_key: 'Osoba už je v tejto firme.',
  lookup_value_label_key: 'Táto hodnota v číselníku už je.',
  lookup_value_list_code_code_key: 'Hodnota s podobným názvom už v číselníku je.',
  lookup_value_code_check: 'Názov hodnoty musí obsahovať písmeno alebo číslicu.',
  custom_field_entity_key_key: 'Pole s podobným názvom už existuje.',
  custom_field_key_check: 'Názov poľa musí začínať písmenom.',
  custom_field_option_field_id_label_key: 'Táto hodnota výberu už je.',
  custom_field_section_entity_name_key: 'Sekcia s týmto názvom už existuje.',
  pipeline_org_name_key: 'Pipeline s týmto názvom už existuje.',
  pipeline_stage_pipeline_id_name_key: 'Stage s týmto názvom už v pipeline je.',
  pipeline_stage_probability_check: 'Pravdepodobnosť: 0 až 100 %.',
  oom_eic_key: 'Odberné miesto s týmto EIC už v CRM je.',
  oom_eic_check: 'Neplatný formát alebo kontrolná číslica EIC.',
  oom_phases_check: 'Počet fáz: 1 alebo 3.',
  oom_advance_pct_check: 'Záloha v percentách: 0 až 100.',
  oom_supply_period_check: 'Dodávka do nemôže byť pred dodávkou od.',
  oom_switch_steps_check:
    'Kroky prechodu idú po poradí: výpoveď odoslaná → akceptovaná → zmena potvrdená (bez výpovede iba potvrdenie zmeny).',
  oom_customer_check: 'Odberné miesto patrí práve jednému zákazníkovi (firme alebo domácnosti).',
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
        body: {
          error: CONSTRAINT_MESSAGES[e.constraint_name ?? ''] ?? 'Záznam s týmito údajmi už existuje.',
          code: e.code,
          constraint: e.constraint_name,
        },
      };
    case '23514': // check_violation
      return {
        status: 400,
        body: {
          error: ours ? e.message! : (CONSTRAINT_MESSAGES[e.constraint_name ?? ''] ?? 'Údaje nespĺňajú pravidlá CRM.'),
          code: e.code,
          constraint: e.constraint_name,
        },
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
