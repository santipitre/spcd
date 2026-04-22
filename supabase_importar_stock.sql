-- ============================================================
-- SP CONTROL DATA — IMPORTACIÓN DE STOCK INICIAL
-- Datos desde: Remitos HI 2026.xlsx
-- 79 productos clasificados como MED (medicación) o INS (insumo)
-- ============================================================
-- INSTRUCCIONES:
--   1. Abrí Supabase → SQL Editor → pestaña nueva (+)
--   2. Pegá TODO este contenido
--   3. Click en "Run" (Ctrl+Enter)
-- ============================================================

-- ============================================================
-- 1. CATÁLOGO DE PRODUCTOS (79 productos)
-- ============================================================
-- Clasificación:
--   MED = Medicación (ampollas, contrastes, soluciones)
--   INS = Insumo (descartables, protección, limpieza, oficina, etc.)
--
-- Productos con cantidad "-" en el Excel = stock 0 (están en el
-- catálogo pero sin stock actual). Se cargan igual para que el
-- personal los pueda pedir y vos sepas que tenés que reponer.
-- ============================================================

INSERT INTO productos (stock_id_almacen, nombre, tipo, subcategoria, unidad_base, factor_caja, nombre_caja, stock_minimo, punto_reposicion, requiere_lote) VALUES
-- ── MEDICACIÓN (14 productos) ──
(433,   'AMPOLLA ADENOSINA 3 MG/ML X 2 ML',                     'MED', 'ampolla',   'unidad', 1,  'Unidad',   2,   5,  true),
(434,   'AMPOLLA ADRENALINA 1 MG X 1 ML',                       'MED', 'ampolla',   'unidad', 1,  'Unidad',   2,   5,  true),
(437,   'AMPOLLA AMIODARONA 150 MG X 3 ML',                     'MED', 'ampolla',   'unidad', 1,  'Unidad',   1,   3,  true),
(1534,  'AMPOLLA BUSCAPINA (HIOSCINA BUTILBROMURO 20 MG 1 ML)', 'MED', 'ampolla',   'unidad', 1,  'Unidad',   5,  20,  true),
(10741, 'AMPOLLA DEXAMETASONA 4 MG/1 ML',                       'MED', 'ampolla',   'unidad', 1,  'Unidad',   2,   5,  true),
(6877,  'AMPOLLA ETILEFRINA 10 MG / 1 ML',                      'MED', 'ampolla',   'unidad', 1,  'Unidad',   1,   3,  true),
(451,   'AMPOLLA LIDOCAINA 2% S/E X 5ML',                       'MED', 'ampolla',   'unidad', 1,  'Unidad',   1,   3,  true),
(452,   'AMPOLLA METOCLOPRAMIDA 10 MG X 2 ML',                  'MED', 'ampolla',   'unidad', 1,  'Unidad',   2,   5,  true),
(458,   'AMPOLLA SOLUCION FISIOLOGICA X 5 ML',                  'MED', 'ampolla',   'unidad', 1,  'Unidad',   5,  10,  true),
(772,   'E-Z-CAT SUSPENSION CONCENTRADA DE BARIO X 225 ML',     'MED', 'contraste', 'unidad', 1,  'Unidad',   5,  12,  true),
(781,   'SOLUCION FISIOLOGICA 0.9% X 500 ML',                   'MED', 'solucion',  'unidad', 1,  'Unidad',   3,  10,  true),
(6725,  'ULTRAVIST 300 IOPROMIDA BT 500 ML AR',                  'MED', 'contraste', 'unidad', 1,  'Unidad',   5,  10,  true),
(10059, 'XENETIX 300 IOBITRIDOL X 500 ML',                      'MED', 'contraste', 'unidad', 1,  'Unidad',   3,   8,  true),
(1529,  'DOTAREM X 15 ML',                                      'MED', 'contraste', 'unidad', 1,  'Unidad',   3,   8,  true),

-- ── INSUMOS MÉDICOS — Agujas y punzantes (7) ──
(17,    'AGUJA 18 G 1 1/2 (40 X 12)',              'INS', 'aguja',       'unidad', 100, 'Caja x100', 50,  100, false),
(18,    'AGUJA 21 G 1/2 (40 X 8)',                 'INS', 'aguja',       'unidad', 100, 'Caja x100', 50,  100, false),
(839,   'AGUJA 25 G X 5/8 (16 X 5)',               'INS', 'aguja',       'unidad', 100, 'Caja x100', 50,  100, false),
(12,    'AGUJA 27 G (13X4)',                        'INS', 'aguja',       'unidad', 100, 'Caja x100', 50,  100, false),
(283,   'BUTTERFLY N° 21',                          'INS', 'aguja',       'unidad', 1,   'Unidad',    20,   50, false),
(284,   'BUTTERFLY N° 23',                          'INS', 'aguja',       'unidad', 1,   'Unidad',    20,   50, false),
(285,   'BUTTERFLY N° 25',                          'INS', 'aguja',       'unidad', 1,   'Unidad',    20,   50, false),

-- ── INSUMOS MÉDICOS — Jeringas (7) ──
(425,   'JERINGA 10 ML S/ AGUJA',                              'INS', 'jeringa',   'unidad', 100, 'Caja x100', 50, 100, false),
(423,   'JERINGA 1 ML INSULINA',                               'INS', 'jeringa',   'unidad', 100, 'Caja x100', 20,  50, false),
(426,   'JERINGA 20 ML S/AGUJA',                               'INS', 'jeringa',   'unidad', 100, 'Caja x100', 20,  50, false),
(427,   'JERINGA 3 ML S/AGUJA (PET NEOJET UNICAMENTE)',        'INS', 'jeringa',   'unidad', 100, 'Caja x100', 20,  50, false),
(428,   'JERINGA 5 ML S/AGUJA',                                'INS', 'jeringa',   'unidad', 100, 'Caja x100', 20,  50, false),
(430,   'JERINGA 60 ML THOMEY PICO P/ CATETER - DARLING',      'INS', 'jeringa',   'unidad', 1,   'Unidad',    10,  25, false),
(5055,  'JERINGA INYECTORA 2 X 200 ML MEDRAD STELLANT',        'INS', 'jeringa',   'unidad', 1,   'Unidad',    5,  10, false),

-- ── INSUMOS MÉDICOS — Accesos vasculares (3) ──
(556,   'CATETER ABBOCATT TEFLON N° 20 G',                     'INS', 'cateter',   'unidad', 1,  'Unidad',   30,  80, false),
(403,   'LLAVE 3 VIAS',                                        'INS', 'cateter',   'unidad', 50, 'Caja x50', 30,  80, false),
(9075,  'CONECTOR SIMPLE MULTIPACIENTE SDP 250',                'INS', 'cateter',   'unidad', 1,  'Unidad',    5,  10, false),

-- ── INSUMOS — Protección personal (10) ──
(7410,  'BARBIJO KN 95',                                       'INS', 'proteccion', 'unidad', 1,   'Unidad',     10,  30, false),
(23,    'BARBIJO TRIPLE PLISADO C/ELASTICO',                   'INS', 'proteccion', 'unidad', 50,  'Caja x50',   50, 100, false),
(6880,  'BATA CORTA SP 40 (1.00 MTS)',                         'INS', 'proteccion', 'unidad', 1,   'Unidad',     50, 100, false),
(6879,  'BATA LARGA SP 40 (1.25 MTS)',                         'INS', 'proteccion', 'unidad', 1,   'Unidad',     10,  30, false),
(596,   'CAMISOLIN CON PUÑO DESCARTABLE CRUZADO ESPECIAL',     'INS', 'proteccion', 'unidad', 1,   'Unidad',     20,  50, false),
(207,   'GUANTES LATEX S/ESTERILIZAR CHICO',                   'INS', 'proteccion', 'unidad', 100, 'Caja x100',  50, 200, false),
(392,   'GUANTES LATEX S/ESTERILIZAR GRANDE',                  'INS', 'proteccion', 'unidad', 100, 'Caja x100',  50, 200, false),
(509,   'GUANTES LATEX S/ESTERILIZAR MEDIANO',                 'INS', 'proteccion', 'unidad', 100, 'Caja x100',  50, 200, false),
(9178,  'PROTECTOR AUDITIVO 3M DE ESPUMA PREMOLDEADO',         'INS', 'proteccion', 'unidad', 1,   'Unidad',     20,  50, false),
(368,   'CAMILLERO COMUN C/ELASTICO Y/O TIRAS M',              'INS', 'proteccion', 'unidad', 1,   'Unidad',     10,  30, false),

-- ── INSUMOS — Descartables médicos (10) ──
(369,   'CAMILLERO S/ELASTICO S',                              'INS', 'descartable', 'unidad', 1,   'Unidad',    10,  30, false),
(363,   'ALGODON X 500 GRS',                                   'INS', 'descartable', 'unidad', 1,   'Unidad',     2,   5, false),
(378,   'CINTA HIPOALERGENICA TRANSPORE 3M 2.5 X 9.1 MTS',    'INS', 'descartable', 'unidad', 1,   'Unidad',     5,  15, false),
(389,   'GASA ESTERILIZADA N° 5 20X20X3 BOLSA X 25 SOBRES',   'INS', 'descartable', 'unidad', 25,  'Bolsa x25',  5,  15, false),
(390,   'GASA ESTERILIZADA N° 5 30X30X3 BOLSA X 25 SOBRES',   'INS', 'descartable', 'unidad', 25,  'Bolsa x25',  5,  15, false),
(805,   'ELECTRODOS P/ ADULTO 3M X 50 UNIDADES',              'INS', 'descartable', 'unidad', 50,  'Bolsa x50',  50, 100, false),
(387,   'ELECTRODOS P/ADULTO',                                 'INS', 'descartable', 'unidad', 1,   'Unidad',     20,  50, false),
(386,   'DESCARTADOR DE BUTTERFLY X 4.8 LTS E4MR',            'INS', 'descartable', 'unidad', 1,   'Unidad',      3,   7, false),
(1141,  'DESCARTADOR DE BUTTERFLY X 1.4 LTS E1 MR',           'INS', 'descartable', 'unidad', 1,   'Unidad',      2,   5, false),
(408,   'PRESERVATIVOS GENTLEMAN USO MED X 144 UNIDADES',     'INS', 'descartable', 'unidad', 144, 'Caja x144',  50, 150, false),

-- ── INSUMOS — Diagnóstico (4) ──
(7937,  'GLUCOMETRO CON TIRAS ACCU CHEK',                     'INS', 'diagnostico', 'unidad', 1,  'Unidad',   1,   2, false),
(804,   'LANCETAS P/ SANGRE ESTERILIZADA DESCARTABLES',        'INS', 'diagnostico', 'unidad', 1,  'Unidad',  20,  50, false),
(803,   'TIRAS REACTIVAS P/ GLUCOSA EN SANGRE X 50',          'INS', 'diagnostico', 'unidad', 50, 'Caja x50', 1,   2, false),
(402,   'LIGADURA TUBO LATEX 06 X 09 MM X 9 MTS',            'INS', 'diagnostico', 'unidad', 1,  'Unidad',    1,   3, false),

-- ── INSUMOS — Ecografía / Imagen (1) ──
(671,   'GEL ULTRASONIDO BOCA FINA X 4/5 KGS',               'INS', 'imagen',     'unidad', 1,  'Unidad',   2,   4, false),

-- ── INSUMOS — Limpieza y ambiente (8) ──
(578,   'AGUA OXIGENADA 10 VOL X LTS',                        'INS', 'limpieza',   'unidad', 1,  'Unidad',   2,   5, false),
(672,   'ALCOHOL ETILICO 96 % X LTS',                         'INS', 'limpieza',   'unidad', 1,  'Unidad',   5,  15, false),
(7429,  'ALCOHOL ETILICO 70 % X LTS',                         'INS', 'limpieza',   'unidad', 1,  'Unidad',   2,   5, false),
(730,   'DESODORANTE DE AMBIENTE REPUESTO AERO',              'INS', 'limpieza',   'unidad', 1,  'Unidad',   3,  10, false),
(52,    'DESODORANTE DESINFECTANTE LYSOFORM AEROSOL X 360 CC','INS', 'limpieza',   'unidad', 1,  'Unidad',   1,   3, false),
(54,    'DETERGENTE CREMOSO CIF 700 CC',                      'INS', 'limpieza',   'unidad', 1,  'Unidad',   1,   3, false),
(50,    'CLORO X 5 LTS',                                      'INS', 'limpieza',   'unidad', 1,  'Unidad',   1,   3, false),
(63,    'PAÑO TIPO BALERINA',                                 'INS', 'limpieza',   'unidad', 1,  'Unidad',   5,  15, false),

-- ── INSUMOS — Higiene y papelería sanitaria (2) ──
(2468,  'ROLLO BOBINA PAPEL BLANCO ECO 25 X 400 MTS',         'INS', 'higiene',   'unidad', 1,  'Unidad',   3,   8, false),
(2516,  'ROLLO PAPEL HIGIENICO RACIONAL 300 MTS',             'INS', 'higiene',   'unidad', 1,  'Unidad',   10,  30, false),

-- ── INSUMOS — Oficina (7) ──
(521,   'RESMA A4 75 GRS',                                    'INS', 'oficina',   'unidad', 1,  'Unidad',   5,  10, false),
(4274,  'LAPICERAS / BOLIGRAFOS NEGRO / AZUL',                'INS', 'oficina',   'unidad', 1,  'Unidad',   5,  10, false),
(794,   'TARJETA INSTITUCIONAL',                               'INS', 'oficina',   'unidad', 1,  'Unidad',   10,  50, false),
(242,   'MARCADOR EDDING 360 AZUL/NEGRO PIZARRA',             'INS', 'oficina',   'unidad', 1,  'Unidad',   1,   3, false),
(171,   'CORRECTOR LAPIZ',                                     'INS', 'oficina',   'unidad', 1,  'Unidad',   1,   3, false),
(758,   'RESALTADOR',                                          'INS', 'oficina',   'unidad', 1,  'Unidad',   1,   3, false),
(417,   'VASOS DESCARTABLES PLASTICO X 180 CC',               'INS', 'oficina',   'unidad', 50, 'Pack x50', 50, 100, false),

-- ── INSUMOS — Cintas (3) ──
(157,   'CINTA ENMASCARAR 36X50',                             'INS', 'varios',    'unidad', 1,  'Unidad',   1,   3, false),
(158,   'CINTA ENMASCARAR 48X50',                             'INS', 'varios',    'unidad', 1,  'Unidad',   1,   3, false),
(465,   'BOLSA CONSORCIO SUPER 80X100/40 MIC',                'INS', 'varios',    'unidad', 1,  'Unidad',   5,  15, false),

-- ── INSUMOS — Varios (3) ──
(5214,  'BOLSA RESIDUOS CHICA',                               'INS', 'varios',    'unidad', 1,  'Unidad',   10,  30, false),
(880,   'BIOMBO PLEGABLE 3 CUERPOS CON/SIN RUEDA METALICO',   'INS', 'equipamiento','unidad',1, 'Unidad',   0,   1, false),
(1087,  'KIT DE REPUESTO PARA EQUIPO DE TECHNEGAS',           'INS', 'equipamiento','unidad',1, 'Unidad',   0,   1, false);


-- ============================================================
-- 2. LOTES DE MEDICACIÓN (productos con vencimiento)
-- ============================================================
-- Solo los que tienen LOTE y Vencimiento en el Excel.
-- Las fechas de vencimiento se interpretan como último día del mes.

-- Necesitamos los IDs de productos recién creados
-- Usamos CTEs para buscarlos por stock_id_almacen

INSERT INTO lotes (producto_id, nro_lote, fecha_vencimiento, cantidad_actual)
SELECT p.id, v.nro_lote, v.fecha_venc, v.cantidad
FROM (VALUES
  (434,   '8094',   '2026-10-31'::DATE,  5),
  (437,   '16047',  '2026-12-31'::DATE,  2),
  (1534,  '16296',  '2027-08-31'::DATE,  100),
  (10741, '50304',  '2027-06-30'::DATE,  8),
  (6877,  '15626',  '2026-09-30'::DATE,  3),
  (451,   '150055', '2027-10-31'::DATE,  3),
  (452,   '13888',  '2027-07-31'::DATE,  6)
) AS v(stock_id, nro_lote, fecha_venc, cantidad)
JOIN productos p ON p.stock_id_almacen = v.stock_id;


-- ============================================================
-- 3. MOVIMIENTOS DE ENTRADA (stock inicial)
-- ============================================================
-- Cada producto con cantidad > 0 en el Excel recibe un movimiento
-- tipo ENTRADA con la cantidad actual como stock inicial.
-- Se usa el usuario SPITRELLA como operador.
-- Productos con "-" no reciben movimiento (stock = 0).

INSERT INTO movimientos (tipo, producto_id, lote_id, cantidad, remito_nro, usuario_id, observacion)
SELECT
  'ENTRADA',
  p.id,
  l.id,  -- NULL si no tiene lote
  v.cantidad,
  v.remito,
  (SELECT id FROM usuarios WHERE username = 'SPITRELLA'),
  'Carga inicial desde Excel Remitos HI 2026'
FROM (VALUES
  -- stock_id, cantidad, remito_nro, tiene_lote (para match)
  (578,   6,    'X-221341',  false),
  (17,    100,  'X-219002',  false),
  (18,    200,  'X-212028',  false),
  (839,   100,  'X-219002',  false),
  (672,   19,   'X-221451',  false),
  (363,   5,    'X-219002',  false),
  (434,   5,    'X-219006',  true),
  (437,   2,    'X-219006',  true),
  (1534,  100,  'X-221341',  true),
  (10741, 8,    'X-219006',  true),
  (6877,  3,    'X-219006',  true),
  (451,   3,    'X-217493',  true),
  (452,   6,    'X-219006',  true),
  (7410,  10,   'X-221451',  false),
  (23,    17,   'X-221326',  false),
  (6880,  310,  'X-221451',  false),
  (880,   4,    'X-212028',  false),
  (284,   100,  'X-219003',  false),
  (368,   50,   'X-221342',  false),
  (369,   40,   'X-219003',  false),
  (596,   60,   'X-221451',  false),
  (556,   200,  'X-221451',  false),
  (378,   16,   'X-221330',  false),
  (390,   25,   'X-217493',  false),
  (671,   4,    'X-221341',  false),
  (509,   18,   'X-221451',  false),
  (425,   300,  'X-221451',  false),
  (423,   90,   'X-212020',  false),
  (426,   100,  'X-219002',  false),
  (428,   18,   'X-219002',  false),
  (430,   50,   'X-219002',  false),
  (5055,  23,   'X-216523',  false),
  (403,   150,  'X-216523',  false),
  (63,    37,   'X-221452',  false),
  (408,   288,  'X-221326',  false),
  (9178,  300,  'X-219003',  false),
  (521,   18,   'X-221340',  false),
  (2468,  11,   'X-221452',  false),
  (2516,  96,   'X-221452',  false),
  (781,   11,   'X-216523',  false),
  (772,   36,   'X-221451',  false),
  (805,   200,  'X-219003',  false),
  (386,   7,    'X-219003',  false),
  (730,   22,   'X-221451',  false),
  (52,    1,    'X-221326',  false),
  (6725,  16,   'X-221451',  false),
  (417,   250,  'X-221340',  false)
) AS v(stock_id, cantidad, remito, tiene_lote)
JOIN productos p ON p.stock_id_almacen = v.stock_id
LEFT JOIN lotes l ON l.producto_id = p.id AND v.tiene_lote = true;


-- ============================================================
-- 4. VERIFICACIÓN FINAL
-- ============================================================
SELECT 'PRODUCTOS' AS entidad, COUNT(*) AS total FROM productos
UNION ALL
SELECT 'CON STOCK > 0', COUNT(*) FROM v_stock WHERE stock_actual > 0
UNION ALL
SELECT 'SIN STOCK', COUNT(*) FROM v_stock WHERE stock_actual = 0
UNION ALL
SELECT 'MEDICACION', COUNT(*) FROM productos WHERE tipo = 'MED'
UNION ALL
SELECT 'INSUMOS', COUNT(*) FROM productos WHERE tipo = 'INS'
UNION ALL
SELECT 'LOTES', COUNT(*) FROM lotes
UNION ALL
SELECT 'MOVIMIENTOS', COUNT(*) FROM movimientos
ORDER BY entidad;
