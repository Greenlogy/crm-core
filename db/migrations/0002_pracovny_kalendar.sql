-- 0002_pracovny_kalendar.sql – pracovný kalendár 2026–2028 a výpočet termínov SLA
--
-- Pracovný čas: Po–Pi 7:30–15:30 (Europe/Bratislava), okrem dní pracovného pokoja
-- podľa zákona 241/1993 Z. z. v znení účinnom od 1. 11. 2025 (novela 261/2025 Z. z.):
--   - 1. 9., 28. 10. a 17. 11. nie sú dňami pracovného pokoja (§ 2 ods. 3),
--   - 8. 5. a 15. 9. nie sú dňami pracovného pokoja v roku 2026 (§ 4b).
-- Zoznam potvrdil Peter 11. 10. 2026. Zmena zákona = nová migrácia.

-- migrate:up

WITH holiday (date, note) AS (
  VALUES
    -- 2026
    (date '2026-01-01', 'Deň vzniku Slovenskej republiky'),
    (date '2026-01-06', 'Zjavenie Pána'),
    (date '2026-04-03', 'Veľký piatok'),
    (date '2026-04-06', 'Veľkonočný pondelok'),
    (date '2026-05-01', 'Sviatok práce'),
    (date '2026-07-05', 'Sviatok svätého Cyrila a Metoda'),
    (date '2026-08-29', 'Výročie SNP'),
    (date '2026-11-01', 'Sviatok všetkých svätých'),
    (date '2026-12-24', 'Štedrý deň'),
    (date '2026-12-25', 'Prvý sviatok vianočný'),
    (date '2026-12-26', 'Druhý sviatok vianočný'),
    -- 2027
    (date '2027-01-01', 'Deň vzniku Slovenskej republiky'),
    (date '2027-01-06', 'Zjavenie Pána'),
    (date '2027-03-26', 'Veľký piatok'),
    (date '2027-03-29', 'Veľkonočný pondelok'),
    (date '2027-05-01', 'Sviatok práce'),
    (date '2027-05-08', 'Deň víťazstva nad fašizmom'),
    (date '2027-07-05', 'Sviatok svätého Cyrila a Metoda'),
    (date '2027-08-29', 'Výročie SNP'),
    (date '2027-09-15', 'Sedembolestná Panna Mária'),
    (date '2027-11-01', 'Sviatok všetkých svätých'),
    (date '2027-12-24', 'Štedrý deň'),
    (date '2027-12-25', 'Prvý sviatok vianočný'),
    (date '2027-12-26', 'Druhý sviatok vianočný'),
    -- 2028
    (date '2028-01-01', 'Deň vzniku Slovenskej republiky'),
    (date '2028-01-06', 'Zjavenie Pána'),
    (date '2028-04-14', 'Veľký piatok'),
    (date '2028-04-17', 'Veľkonočný pondelok'),
    (date '2028-05-01', 'Sviatok práce'),
    (date '2028-05-08', 'Deň víťazstva nad fašizmom'),
    (date '2028-07-05', 'Sviatok svätého Cyrila a Metoda'),
    (date '2028-08-29', 'Výročie SNP'),
    (date '2028-09-15', 'Sedembolestná Panna Mária'),
    (date '2028-11-01', 'Sviatok všetkých svätých'),
    (date '2028-12-24', 'Štedrý deň'),
    (date '2028-12-25', 'Prvý sviatok vianočný'),
    (date '2028-12-26', 'Druhý sviatok vianočný')
),
day AS (
  SELECT d::date AS date
    FROM generate_series(date '2026-01-01', date '2028-12-31', interval '1 day') AS d
)
INSERT INTO business_calendar (date, is_working_day, work_from, work_to, note)
SELECT day.date,
       is_working,
       CASE WHEN is_working THEN time '07:30' END,
       CASE WHEN is_working THEN time '15:30' END,
       holiday.note
  FROM day
  LEFT JOIN holiday USING (date)
 CROSS JOIN LATERAL (
   SELECT extract(isodow FROM day.date) < 6 AND holiday.date IS NULL AS is_working
 ) w;

-- Pripočíta pracovné minúty k času podľa business_calendar (Europe/Bratislava).
-- Čas mimo pracovnej doby sa počíta od najbližšieho začiatku pracovného dňa.
-- Príklad: piatok 15:00 + 480 min (8 pracovných hodín) = pondelok 15:00.
CREATE FUNCTION add_business_minutes(start timestamptz, minutes integer) RETURNS timestamptz
LANGUAGE plpgsql STABLE AS $$
DECLARE
  v_local      timestamp := start AT TIME ZONE 'Europe/Bratislava';
  v_remaining  numeric := minutes;
  v_from       timestamp;
  v_to         timestamp;
  v_available  numeric;
  r            record;
BEGIN
  IF minutes IS NULL OR minutes < 0 THEN
    RAISE EXCEPTION 'add_business_minutes: počet minút musí byť 0 alebo viac (zadané %)', minutes;
  END IF;

  FOR r IN
    SELECT bc.date, bc.work_from, bc.work_to
      FROM business_calendar bc
     WHERE bc.date >= v_local::date
       AND bc.is_working_day
     ORDER BY bc.date
  LOOP
    v_from := greatest(v_local, r.date + r.work_from);
    v_to   := r.date + r.work_to;
    CONTINUE WHEN v_from >= v_to;

    v_available := extract(epoch FROM v_to - v_from) / 60;
    IF v_remaining <= v_available THEN
      RETURN (v_from + make_interval(mins => v_remaining::integer)) AT TIME ZONE 'Europe/Bratislava';
    END IF;
    v_remaining := v_remaining - v_available;
  END LOOP;

  RAISE EXCEPTION 'add_business_minutes: business_calendar nepokrýva termín od % (+% min)', start, minutes;
END;
$$;

-- Kontrola pri nasadení: ak výpočet nesedí, migrácia zlyhá.
DO $$
DECLARE
  tz constant text := 'Europe/Bratislava';
BEGIN
  -- príklad z CLAUDE.md: piatok 15:00 + 8 pracovných hodín = pondelok 15:00
  ASSERT add_business_minutes(timestamp '2026-10-09 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-10-12 15:00' AT TIME ZONE tz, 'SLA: piatok 15:00 + 8 h';
  -- odpoveď: piatok 15:00 + 24 pracovných hodín = streda 15:00
  ASSERT add_business_minutes(timestamp '2026-10-09 15:00' AT TIME ZONE tz, 1440)
       = timestamp '2026-10-14 15:00' AT TIME ZONE tz, 'SLA: piatok 15:00 + 24 h';
  -- cez Vianoce: štvrtok 23. 12. 15:00 + 8 h = pondelok 28. 12. 15:00
  ASSERT add_business_minutes(timestamp '2026-12-23 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-12-28 15:00' AT TIME ZONE tz, 'SLA: cez Vianoce';
  -- mimo pracovného času: sobota 10:00 + 8 h = pondelok 15:30
  ASSERT add_business_minutes(timestamp '2026-10-10 10:00' AT TIME ZONE tz, 480)
       = timestamp '2026-10-12 15:30' AT TIME ZONE tz, 'SLA: víkend';
  -- 8. 5. 2026 je pracovný deň (§ 4b): štvrtok 7. 5. 15:00 + 8 h = piatok 8. 5. 15:00
  ASSERT add_business_minutes(timestamp '2026-05-07 15:00' AT TIME ZONE tz, 480)
       = timestamp '2026-05-08 15:00' AT TIME ZONE tz, 'SLA: 8. 5. 2026 pracovný deň';
END;
$$;

-- migrate:down

DROP FUNCTION IF EXISTS add_business_minutes(timestamptz, integer);
DELETE FROM business_calendar WHERE date BETWEEN date '2026-01-01' AND date '2028-12-31';
