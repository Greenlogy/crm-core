// Vymyslené exporty Office portálu a XM Trade na skúšku párovania zmlúv s obchodmi (modul 5, F5) na Teste.
// Bez skutočných mien, IČO a EIC. Formát a hárky ako vytvor.cjs (export „HEO - Web Zmluvy - prehlad EE +“ a XM Trade „Prehľad“).
// Spustenie (z koreňa repozitára): node db/test-data/zmluvy-f5-vytvor.cjs
// Vytvorí: db/test-data/zmluvy-f5-office-portal.xlsx, zmluvy-f5-xm-trade.xlsx, zmluvy-f5.sql (obchody a ponuky na Teste
// s rovnakými EIC a cenami; ./db/test-data/zmluvy-f5.sh dev vytvor) a zmluvy-f5-delete.sql.
const fs = require('node:fs');
const path = require('node:path');
const XLSX = require(path.join(__dirname, '../../api/node_modules/xlsx'));

// EIC s platnou kontrolnou číslicou (ENTSO-E, rovnako ako eic_is_valid v 0013)
const CH = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ-';
function eic(prefix15) {
  let sum = 0;
  for (let i = 0; i < 15; i++) sum += CH.indexOf(prefix15[i]) * (16 - i);
  const c = CH[36 - (((sum - 1) % 37) + 37) % 37];
  return c === '-' ? null : prefix15 + c;
}
function makeEic(n) {
  for (const l of 'ABCDEFGHJKLMNPQRSTUVW') {
    const e = eic(`24ZZS99TESTF${l}${String(n).padStart(2, '0')}`);
    if (e) return e;
  }
}
const E = {};
for (let n = 1; n <= 8; n++) E[n] = makeEic(n);
for (const [k, v] of Object.entries(E)) if (!v || v.length !== 16) throw new Error('EIC ' + k);

const uuid = (n) => `00000000-0000-4000-9000-${String(n).padStart(12, '0')}`;
const OP_HEAD = ['ID', 'MJ', 'ano_test', 'DomSpolNazov', 'ZmluvaStatus', 'Komodita', 'TypOsoby', 'meno', 'priezvisko', 'datum_narodenia',
  'PONazov', 'ICO', 'DIC', 'IC_DPH', 'ZmluvaHlavicka_cislo', 'spotreba_sum', 'spotreba_1t_vt', 'spotreba_nt', 'ZOM_eic',
  'ZOM_spotreba_1t_vt', 'ZOM_spotreba_nt', 'ZOM_zdroj_vykon', 'ZOM_zdroj_vykon_mj', 'ZOM_nazov_tarifa_pds', 'ZOM_nazov_tarifa_glg',
  'ZmluvaZmluvneCeny_nazov', 'ZmluvaZmluvneCeny_Datum_Od', 'ZmluvaZmluvneCeny_Datum_Do', 'pocet_tarif', 'cena_1t_vt_bez_dph',
  'cena_2t_nt_bez_dph', 'cena_3t_bez_dph', 'ZZC_datum_od', 'ZZC_datum_do', 'Zdroj_nazov', 'ano_maly_podnik', 'cennikova_cena',
  'ano_autoprolongacia', 'ucinnost_od', 'ucinnost_do', 'platnost_od', 'OsobaNazov', 'VytvorilNazov', 'ObchodnikNazov', 'STATUS_zhe',
  'Osoba_ID', 'Greatest_updated_at'];
const D = (s) => (s ? new Date(s + 'T00:00:00Z') : new Date('1900-01-01T00:00:00Z'));
function op(c, rows) {
  return rows.map((r) => {
    const x = { ...c, ...r };
    return {
      ID: x.id, MJ: x.mj ?? 'MWh', ano_test: 'N', DomSpolNazov: 'Greenlogy a.s.', ZmluvaStatus: 'Finálne podpísaná',
      Komodita: 'Elektrina', TypOsoby: x.dom ? 'Domacnost' : 'Mimo Domacnost', meno: x.meno ?? '', priezvisko: x.priezvisko ?? '',
      datum_narodenia: x.dom ? D('1980-01-01') : D(null), PONazov: x.firma ?? '', ICO: x.ico ?? '', DIC: x.ico ? '20' + x.ico : '', IC_DPH: x.ico ? 'SK20' + x.ico : '',
      ZmluvaHlavicka_cislo: x.cislo, spotreba_sum: x.vt, spotreba_1t_vt: x.vt, spotreba_nt: 0, ZOM_eic: x.eic,
      ZOM_spotreba_1t_vt: x.vt, ZOM_spotreba_nt: 0, ZOM_zdroj_vykon: 0, ZOM_zdroj_vykon_mj: '',
      ZOM_nazov_tarifa_pds: x.sadzba, ZOM_nazov_tarifa_glg: x.produkt, ZmluvaZmluvneCeny_nazov: x.cena ?? '',
      ZmluvaZmluvneCeny_Datum_Od: D(x.cena ? '2027-01-01' : null), ZmluvaZmluvneCeny_Datum_Do: D(x.cena ? '2027-01-01' : null),
      pocet_tarif: x.cena ? '1' : '0', cena_1t_vt_bez_dph: x.vt_cena ?? 0, cena_2t_nt_bez_dph: 0, cena_3t_bez_dph: 0,
      ZZC_datum_od: D(x.cena ? '2027-01-01' : null), ZZC_datum_do: D(x.cena ? '2027-12-31' : null),
      Zdroj_nazov: 'Web', ano_maly_podnik: 'N', cennikova_cena: x.dom ? 'A' : 'N', ano_autoprolongacia: 'A',
      ucinnost_od: D('2027-01-01'), ucinnost_do: D(x.dom ? null : '2027-12-31'), platnost_od: D('2026-10-16'),
      OsobaNazov: x.firma ?? `${x.meno} ${x.priezvisko}`, VytvorilNazov: 'Tvorca Testovací', ObchodnikNazov: 'Testovací Obchodník A',
      STATUS_zhe: '', Osoba_ID: x.osoba, Greatest_updated_at: new Date('2026-10-16T08:00:00Z'),
    };
  });
}
const FIX = (vt) => ({ cena: 'GREEN_1T_INDIVIDUAL_2027', vt_cena: vt });
const NN = { sadzba: 'C2-X3', produkt: 'IN GREEN 1T' };
const VN = { sadzba: 'X2 /VN/', produkt: 'IN GREEN 1T' };

// Zákazníci (firmy založí skript na Teste pred importom; IČO 999999 05–07 – iné ako v office-portal-test-*.xlsx)
const C = {
  epsilon: { firma: 'Testovacia Epsilon s.r.o.', ico: '99999905', osoba: uuid(105), id: uuid(5101) },
  zeta: { firma: 'Testovacia Zeta s.r.o.', ico: '99999906', osoba: uuid(106), id: uuid(5102) },
  theta: { firma: 'Testovacia Théta s.r.o.', ico: '99999907', osoba: uuid(107), id: uuid(5103) },
  // Obnova (krok 2, 0046): zmluvy založí skript priamo – neprídu importom, nepárujú sa
  iota: { firma: 'Testovacia Ióta s.r.o.', ico: '99999908', osoba: uuid(108), id: uuid(5104) },
};
// OOM: 1 NN a 2 VN (Epsilon, obchod v Akceptácii), 3 NN (Zeta, Akceptácia, iná cena), 4 NN (Epsilon, bez obchodu),
// 5 NN (Théta, obchod vo Vyjednávaní), 6 domácnosť (bez obchodu)
const O = [
  { n: 1, eic: E[1], c: 'epsilon', vn: false, mwh: 30, offer: 120 },
  { n: 2, eic: E[2], c: 'epsilon', vn: true, mwh: 200, offer: 110 },
  { n: 3, eic: E[3], c: 'zeta', vn: false, mwh: 25, offer: 125 },
  { n: 4, eic: E[4], c: 'epsilon', vn: false, mwh: 15, offer: null },
  { n: 5, eic: E[5], c: 'theta', vn: false, mwh: 20, offer: null },
  { n: 7, eic: E[7], c: 'iota', vn: false, mwh: 35, offer: null },
  { n: 8, eic: E[8], c: 'iota', vn: false, mwh: 18, offer: null },
];

const opRows = [
  // a) NN k obchodu v Akceptácii – rovnaké EIC a cena → spárované, obchod Vyhraté
  ...op({ ...C.epsilon, id: uuid(5001), cislo: '1129995001' }, [{ eic: E[1], vt: 30, ...NN, ...FIX(120) }]),
  // b) VN k tomu istému obchodu → pripojí sa k Vyhratému
  ...op({ ...C.epsilon, id: uuid(5002), cislo: '1129995002' }, [{ eic: E[2], vt: 200, ...VN, ...FIX(110) }]),
  // c) iná cena (ponuka 125, zmluva 119) → príznak „Cena iná ako v ponuke“
  ...op({ ...C.zeta, id: uuid(5003), cislo: '1129995003' }, [{ eic: E[3], vt: 25, ...NN, ...FIX(119) }]),
  // d) OOM nie je na žiadnom obchode → Nespárované
  ...op({ ...C.epsilon, id: uuid(5004), cislo: '1129995004' }, [{ eic: E[4], vt: 15, ...NN, ...FIX(121) }]),
  // e) domácnosť bez obchodu B2C → Bez obchodu
  ...op({ dom: true, mj: 'kWh', meno: 'Eva', priezvisko: 'Pokusná', osoba: uuid(205), id: uuid(5005), cislo: '1129995005' },
    [{ eic: E[6], vt: 2500, sadzba: 'D2', produkt: 'DD2' }]),
  // f) obchod vo Vyjednávaní (bez akceptovanej ponuky) → spárované bez akceptovanej ponuky, ceny sa nekontrolujú
  ...op({ ...C.theta, id: uuid(5006), cislo: '1129995006' }, [{ eic: E[5], vt: 20, ...NN, ...FIX(125) }]),
];

const XM_HEAD = ['Názov', 'EAN / EIC OM', 'Odber/Dodávka', 'Platné od', 'Platné do', 'Dátum začiatku dodávky', 'Napäťová úroveň', 'Sústava', 'PDS',
  'Veľkosť ističa [A]', 'Spôsob rezervovania kapacity', 'Rezervovaná kapacita', 'Rezervovaná kapacita - jednotka', 'Maximálna rezervovaná kapacita [kW]',
  'Sadzba', 'Produkt', 'Typ odberu', 'Typ merania', 'Trieda TDO', 'Počet fáz', 'Evidované v zmluve', 'Stav', 'Spotrebná daň', 'Fakturačné obdobie',
  'Percento zálohy 1', 'Predpokladaná spotreba 2026 (JT/VT) [kWh]', 'Predpokladaná spotreba 2026 (NT) [kWh]', 'Stav zmluvy', 'Sprostredkovateľ',
  'Číslo zmluvy', 'Identifikátor PDS (číslo OP)', 'Spôsob zálohových faktúr', 'Cenová regulácia', 'Odberateľ', 'Sídlo firmy / bydlisko',
  'Ulica', 'PSČ', 'Obec', 'IČO / Rodné číslo'];
const ZSD = 'Západoslovenská distribučná (24X-ZSE-PDS----5)';
function xm(o) {
  return {
    'Názov': `TST ${o.eic}`, 'EAN / EIC OM': o.eic, 'Odber/Dodávka': 'Odber (-)', 'Platné od': '01.01.2027', 'Platné do': '-',
    'Dátum začiatku dodávky': '01.01.2027', 'Napäťová úroveň': o.vn ? 'vn' : 'nn', 'Sústava': ZSD, 'PDS': 'Západoslovenská distribučná, a.s.',
    'Veľkosť ističa [A]': 25, 'Spôsob rezervovania kapacity': '-', 'Rezervovaná kapacita': o.vn ? 400 : '-', 'Rezervovaná kapacita - jednotka': o.vn ? 'kW' : '-',
    'Maximálna rezervovaná kapacita [kW]': o.vn ? 400 : 17, 'Sadzba': o.sadzba, 'Produkt': o.produkt, 'Typ odberu': o.dom ? 'Domácnosti' : 'Firmy a organizácie',
    'Typ merania': o.vn ? 'Typ merania A' : 'Typ merania C', 'Trieda TDO': o.vn ? '-' : 'TDO 4 ', 'Počet fáz': 3, 'Evidované v zmluve': o.cislo, 'Stav': 'Aktívne',
    'Spotrebná daň': 'Áno', 'Fakturačné obdobie': o.dom ? 'Ročne (s odkladom k termínu odpočtu)' : 'Mesiac', 'Percento zálohy 1': o.dom ? 0 : 80,
    'Predpokladaná spotreba 2026 (JT/VT) [kWh]': o.kwh, 'Predpokladaná spotreba 2026 (NT) [kWh]': '-', 'Stav zmluvy': 'Potvrdený',
    'Sprostredkovateľ': 'Testovací Sprostredkovateľ', 'Číslo zmluvy': o.cislo, 'Identifikátor PDS (číslo OP)': '9995000' + o.eic.slice(-3),
    'Spôsob zálohových faktúr': o.dom ? 'Bez záloh' : 'Splátkový kalendár do konca roka', 'Cenová regulácia': o.dom ? 'Regulované' : 'Neregulované',
    'Odberateľ': o.odberatel, 'Sídlo firmy / bydlisko': 'Testovacia 5, Skúšobná Ves', 'Ulica': 'Testovacia 5', 'PSČ': '99901', 'Obec': 'Skúšobná Ves',
    'IČO / Rodné číslo': o.dom ? '800101/0000' : o.ico,
  };
}
const xmRows = [
  xm({ eic: E[1], cislo: '1129995001', sadzba: 'C2-X3', produkt: 'ISOT +08,00 nereg.', ico: C.epsilon.ico, odberatel: C.epsilon.firma, kwh: 30000 }),
  xm({ eic: E[2], cislo: '1129995002', vn: true, sadzba: 'X2', produkt: 'ISOT +08,00 nereg.', ico: C.epsilon.ico, odberatel: C.epsilon.firma, kwh: 200000 }),
  xm({ eic: E[3], cislo: '1129995003', sadzba: 'C2-X3', produkt: 'ISOT +08,00 nereg.', ico: C.zeta.ico, odberatel: C.zeta.firma, kwh: 25000 }),
  xm({ eic: E[4], cislo: '1129995004', sadzba: 'C2-X3', produkt: 'ISOT +08,00 nereg.', ico: C.epsilon.ico, odberatel: C.epsilon.firma, kwh: 15000 }),
  xm({ eic: E[6], cislo: '1129995005', dom: true, sadzba: 'D2', produkt: 'Green DD2 - ANO Energopomoc', odberatel: 'Eva Pokusná', kwh: 2500 }),
  xm({ eic: E[5], cislo: '1129995006', sadzba: 'C2-X3', produkt: 'ISOT +08,00 nereg.', ico: C.theta.ico, odberatel: C.theta.firma, kwh: 20000 }),
];

function write(file, sheet, head, rows) {
  const ws = XLSX.utils.json_to_sheet(rows, { header: head, cellDates: true });
  if (sheet.startsWith('HEO')) head.forEach((h, i) => { ws[XLSX.utils.encode_cell({ r: 0, c: i })] = { t: 's', v: `[${h}]` }; });
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, sheet);
  XLSX.writeFile(wb, path.join(__dirname, file));
}
write('zmluvy-f5-office-portal.xlsx', 'HEO - Web Zmluvy - prehlad EE +', OP_HEAD, opRows);
write('zmluvy-f5-xm-trade.xlsx', 'Prehľad', XM_HEAD, xmRows);

// SQL pre Test: firmy, OOM, obchody a ponuky so zhodnými EIC a cenami (vlastník = prihlasovací e-mail z premennej)
const q = (s) => `'${String(s).replace(/'/g, "''")}'`;
const sql = `-- Vygenerované z db/test-data/zmluvy-f5-vytvor.cjs – NEUPRAVOVAŤ RUČNE. Spúšťa ./db/test-data/zmluvy-f5.sh dev vytvor.
-- Testovacie obchody a ponuky pre skúšku párovania zmlúv (F5) so zhodnými EIC a cenami ako zmluvy-f5-office-portal.xlsx.
-- Vymyslené firmy (IČO 99999905–08) a OOM (EIC 24ZZS99TESTF…). Obchodník = e-mail v premennej psql owner.
\\set ON_ERROR_STOP on
BEGIN;
SELECT set_config('f5.owner', :'owner', true) \\gset
DO $f5$
DECLARE
  v_user  uuid := (SELECT id FROM app_user WHERE lower(email) = lower(current_setting('f5.owner')) AND status = 'aktivny');
  v_org   uuid := crm_default_org();
  v_offer uuid;
  v_var   uuid;
  r       record;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Chýba aktívny používateľ – zadajte e-mail obchodníka.';
  END IF;
  IF EXISTS (SELECT 1 FROM company WHERE id IN (${Object.values(C).map((c) => q(c.id)).join(', ')}) OR ico IN (${Object.values(C).map((c) => q(c.ico)).join(', ')})) THEN
    RAISE EXCEPTION 'Testovacie dáta F5 už existujú – najprv ./db/test-data/zmluvy-f5.sh dev zmaz';
  END IF;
  INSERT INTO company (id, name, ico, dic, ic_dph, address, is_customer, owner_id, country) VALUES
${Object.values(C).map((c) => `    (${q(c.id)}, ${q(c.firma)}, ${q(c.ico)}, ${q('20' + c.ico)}, ${q('SK20' + c.ico)}, 'Testovacia 5, 999 01 Skúšobná Ves', true, v_user, 'SK')`).join(',\n')};
  INSERT INTO oom (id, company_id, eic, type, status, voltage_level, planned_consumption_vt_mwh) VALUES
${O.map((o) => `    (${q(uuid(5200 + o.n))}, ${q(C[o.c].id)}, ${q(o.eic)}, 'spotreba', 'pripravovane', ${q(o.vn ? 'vn' : 'nn')}, ${o.mwh})`).join(',\n')};

  -- obchody: 1 Epsilon (Akceptácia, NN + VN), 2 Zeta (Akceptácia, cena 125), 3 Théta (Vyjednávanie, bez ponuky)
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start, org_id)
  SELECT x.id::uuid, x.company::uuid, p.id, s.id, x.name, v_user, 'vlastny_kontakt', '2027-01-01', v_org
    FROM (VALUES (${q(uuid(5301))}, ${q(C.epsilon.id)}, 'TEST F5 Epsilon 2027 (NN + VN)'),
                 (${q(uuid(5302))}, ${q(C.zeta.id)}, 'TEST F5 Zeta 2027 (iná cena)'),
                 (${q(uuid(5303))}, ${q(C.theta.id)}, 'TEST F5 Théta 2027 (Vyjednávanie)')) x(id, company, name)
    JOIN pipeline p ON p.kind = 'b2b_dodavka' AND p.archived_at IS NULL AND (p.org_id IS NULL OR p.org_id = v_org)
    JOIN pipeline_stage s ON s.pipeline_id = p.id AND s.code = 'prilezitost';
  INSERT INTO deal_oom (deal_id, oom_id) VALUES
    (${q(uuid(5301))}, ${q(uuid(5201))}), (${q(uuid(5301))}, ${q(uuid(5202))}), (${q(uuid(5302))}, ${q(uuid(5203))}), (${q(uuid(5303))}, ${q(uuid(5205))});
  UPDATE deal d SET stage_id = s.id FROM pipeline_stage s
   WHERE d.id = ${q(uuid(5303))} AND s.pipeline_id = d.pipeline_id AND s.code = 'vyjednavanie';

  -- ponuky s FIX 2027 podľa OOM, odoslané a ručne akceptované (obchod prejde do Akceptácie)
  FOR r IN SELECT * FROM (VALUES (${q(uuid(5301))}::uuid), (${q(uuid(5302))}::uuid)) x(deal_id) LOOP
    PERFORM set_config('app.user_id', v_user::text, true);
    v_offer := offer_create(r.deal_id);
    PERFORM set_config('app.user_id', '', true);
    v_var := (SELECT id FROM offer_variant WHERE offer_id = v_offer ORDER BY sort_order LIMIT 1);
    DELETE FROM offer_item WHERE variant_id = v_var;
    INSERT INTO offer_item (variant_id, oom_id, year, slot, product_id, price_model, price_vt_eur_mwh)
    SELECT v_var, x.oom_id, 2027, 'komodita', (SELECT id FROM product WHERE code = 'green_1t'), 'fix', o.price
      FROM deal_oom x JOIN (VALUES ${O.filter((o) => o.offer).map((o) => `(${q(uuid(5200 + o.n))}::uuid, ${o.offer})`).join(', ')}) o(oom_id, price) ON o.oom_id = x.oom_id
     WHERE x.deal_id = r.deal_id;
    UPDATE offer SET status = 'odoslana', sent_at = now(), sent_by = v_user, sent_channel = 'osobne',
                     valid_until = now() + interval '14 days', sent_note = 'test F5'
     WHERE id = v_offer;
    PERFORM set_config('app.user_id', v_user::text, true);
    PERFORM offer_accept_manual(v_offer, v_var, 'Ján Skúšobný', 'konateľ', now(), 'telefon', 'test F5', NULL);
    PERFORM set_config('app.user_id', '', true);
  END LOOP;

  -- Obnova (krok 2): zmluvy 1129995007 (OOM 7 → nočný beh založí obchod Obnova) a 1129995008 (OOM 8 je v bežnom otvorenom
  -- obchode „TEST F5 Ióta – bežný obchod“ → nočný beh mu iba doplní predošlú zmluvu); koniec o 60 dní (okno 4 mesiacov)
  INSERT INTO deal (id, company_id, pipeline_id, stage_id, name, owner_id, source_code, supply_start, org_id)
  SELECT ${q(uuid(5304))}::uuid, ${q(C.iota.id)}::uuid, p.id, s.id, 'TEST F5 Ióta – bežný obchod', v_user, 'vlastny_kontakt', crm_today() + 61, v_org
    FROM pipeline p JOIN pipeline_stage s ON s.pipeline_id = p.id AND s.code = 'prilezitost'
   WHERE p.kind = 'b2b_dodavka' AND p.archived_at IS NULL AND (p.org_id IS NULL OR p.org_id = v_org)
   LIMIT 1;
  INSERT INTO deal_oom (deal_id, oom_id) VALUES (${q(uuid(5304))}, ${q(uuid(5208))});
  PERFORM set_config('app.contract_import_id', '', true);
  INSERT INTO contract (id, number, company_id, type, phase, valid_from, valid_to, signed_on, owner_id, auto_prolong, org_id) VALUES
    (${q(uuid(5007))}, '1129995007', ${q(C.iota.id)}, 'dodavka_firma_nn', 'podpisana', '2026-01-01', crm_today() + 60, '2025-12-01', v_user, false, v_org),
    (${q(uuid(5008))}, '1129995008', ${q(C.iota.id)}, 'dodavka_firma_nn', 'podpisana', '2026-01-01', crm_today() + 60, '2025-12-01', v_user, false, v_org);
  INSERT INTO contract_oom (contract_id, oom_id, qty_vt_mwh, qty_nt_mwh, product_id) VALUES
    (${q(uuid(5007))}, ${q(uuid(5207))}, 35, 0, (SELECT id FROM product WHERE code = 'green_1t')),
    (${q(uuid(5008))}, ${q(uuid(5208))}, 18, 0, (SELECT id FROM product WHERE code = 'green_1t'));
  INSERT INTO contract_price (contract_id, oom_id, slot, product_id, price_model, valid_from, valid_to, price_vt_eur_mwh)
  SELECT co.contract_id, co.oom_id, 'komodita', co.product_id, 'fix', '2026-01-01', crm_today() + 60, 118
    FROM contract_oom co WHERE co.contract_id IN (${q(uuid(5007))}, ${q(uuid(5008))});
  RAISE NOTICE 'Založené: 4 firmy, 7 OOM, 4 obchody (2 v Akceptácii s ponukou, 1 vo Vyjednávaní, 1 bežný) a 2 zmluvy na Obnovu (koniec %).',
    to_char(crm_today() + 60, 'DD. MM. YYYY');
END;
$f5$;
COMMIT;
`;
fs.writeFileSync(path.join(__dirname, 'zmluvy-f5.sql'), sql);

const del = `-- Vygenerované z db/test-data/zmluvy-f5-vytvor.cjs – NEUPRAVOVAŤ RUČNE. Spúšťa ./db/test-data/zmluvy-f5.sh dev zmaz.
-- Zmaže iba testovacie dáta F5: zmluvy 1129995001–08, obchody (aj Obnova k zmluvám 07, 08), ponuky, OOM, firmy a domácnosť „Eva Pokusná“.
\\set ON_ERROR_STOP on
BEGIN;
DO $f5$
DECLARE
  v_k uuid[] := ARRAY(SELECT id FROM contract WHERE number IN (${[1, 2, 3, 4, 5, 6, 7, 8].map((n) => q('112999500' + n)).join(', ')}));
  v_d uuid[] := ARRAY[${[5301, 5302, 5303, 5304].map((n) => q(uuid(n)) + '::uuid').join(', ')}]
                || ARRAY(SELECT d.id FROM deal d JOIN contract k ON k.id = d.previous_contract_id
                          WHERE k.number IN (${[7, 8].map((n) => q('112999500' + n)).join(', ')}) AND d.source_code = 'obnova');
  v_o uuid[] := ARRAY(SELECT id FROM oom WHERE eic IN (${Object.values(E).map(q).join(', ')}));
  v_c uuid[] := ARRAY[${Object.values(C).map((c) => q(c.id) + '::uuid').join(', ')}];
  v_p uuid[] := ARRAY(SELECT o.person_id FROM oom o WHERE o.eic = ${q(E[6])} AND o.person_id IS NOT NULL);
  v_f uuid[];
BEGIN
  v_f := ARRAY(SELECT id FROM offer WHERE deal_id = ANY (v_d));
  DELETE FROM notification WHERE contract_id = ANY (v_k) OR deal_id = ANY (v_d);
  UPDATE deal SET previous_contract_id = NULL WHERE previous_contract_id = ANY (v_k);
  DELETE FROM contract_flag WHERE contract_id = ANY (v_k);
  DELETE FROM contract_year_basis WHERE contract_id = ANY (v_k);
  DELETE FROM price_exception WHERE contract_id = ANY (v_k);
  DELETE FROM contract_price WHERE contract_id = ANY (v_k);
  DELETE FROM contract_oom WHERE contract_id = ANY (v_k);
  DELETE FROM contract_import_change WHERE contract_id = ANY (v_k);
  DELETE FROM contract WHERE id = ANY (v_k);
  DELETE FROM email_outbox WHERE deal_id = ANY (v_d);
  DELETE FROM offer_acceptance WHERE offer_id = ANY (v_f);
  DELETE FROM offer_page_stat WHERE offer_id = ANY (v_f);
  DELETE FROM approval_price_item WHERE approval_id IN (SELECT id FROM approval_request WHERE deal_id = ANY (v_d));
  DELETE FROM approval_request WHERE deal_id = ANY (v_d);
  DELETE FROM email_message WHERE thread_id IN (SELECT id FROM email_thread WHERE deal_id = ANY (v_d));
  DELETE FROM email_thread WHERE deal_id = ANY (v_d);
  DELETE FROM offer_item WHERE variant_id IN (SELECT id FROM offer_variant WHERE offer_id = ANY (v_f));
  UPDATE deal SET accepted_variant_id = NULL WHERE id = ANY (v_d);
  DELETE FROM offer_variant WHERE offer_id = ANY (v_f);
  DELETE FROM offer WHERE id = ANY (v_f);
  DELETE FROM deal_contract_input WHERE deal_id = ANY (v_d);
  DELETE FROM deal_event WHERE deal_id = ANY (v_d);
  -- kontrola „obchod v štádiu ponuky musí mať OOM“ by zastavila mazanie OOM otvoreného obchodu – obchod sa maže celý
  ALTER TABLE deal_oom DISABLE TRIGGER trg_deal_oom_ready;
  DELETE FROM deal_oom WHERE deal_id = ANY (v_d);
  ALTER TABLE deal_oom ENABLE TRIGGER trg_deal_oom_ready;
  DELETE FROM deal_contact WHERE deal_id = ANY (v_d);
  DELETE FROM deal WHERE id = ANY (v_d);
  DELETE FROM oom_customer WHERE oom_id = ANY (v_o);
  DELETE FROM oom_contact WHERE oom_id = ANY (v_o);
  DELETE FROM oom_device WHERE oom_id = ANY (v_o);
  DELETE FROM oom_planned_change WHERE oom_id = ANY (v_o);
  DELETE FROM oom_price_regulation_change WHERE oom_id = ANY (v_o);
  DELETE FROM oom WHERE id = ANY (v_o);
  DELETE FROM company_contact WHERE company_id = ANY (v_c) OR contact_id = ANY (v_p);
  DELETE FROM company WHERE id = ANY (v_c);
  DELETE FROM contact WHERE id = ANY (v_p);
  RAISE NOTICE 'Zmazané testovacie dáta F5 (zmluvy %, obchody %, OOM %).', cardinality(v_k), cardinality(v_d), cardinality(v_o);
END;
$f5$;
COMMIT;
`;
fs.writeFileSync(path.join(__dirname, 'zmluvy-f5-delete.sql'), del);
console.log('EIC:', Object.values(E).join(' '));
