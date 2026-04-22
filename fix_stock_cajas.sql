-- ============================================================
-- SP CONTROL DATA — FIX: Cantidades de stock (cajas → unidades)
-- ============================================================
-- PROBLEMA:
--   Los movimientos se cargaron en cantidad de CAJAS.
--   Ejemplo: Guantes → se cargó "18" (18 cajas de 100).
--   El sistema espera UNIDADES: 18 cajas × 100 = 1800 unidades.
--
-- EXCEPCIÓN:
--   DESODORANTE DESINFECTANTE LYSOFORM AEROSOL X 360 CC
--   → Ya fue cargado correctamente en unidades.
--
-- DESPUÉS DEL FIX:
--   Guantes: 18 → 1800 → display: "18 Caja x100 unidad"
--   Barbijos x50: 17 → 850 → display: "17 Caja x50 unidad"
--   Jeringa x100: 18 → 1800 → display: "18 Caja x100 unidad"
--   Desodorante: 1 → 1 (sin cambio) → display: "1 unidad"
--
-- INSTRUCCIONES:
--   Ejecutá cada PASO por separado en Supabase SQL Editor.
-- ============================================================


-- ============================================================
-- PASO 1: VISTA PREVIA — Ver productos afectados
-- ============================================================

SELECT
  p.nombre AS producto,
  p.factor_caja AS unidades_por_caja,
  p.nombre_caja,
  m.id AS movimiento_id,
  m.cantidad AS cargado_cajas,
  m.cantidad * p.factor_caja AS corregido_unidades,
  m.tipo,
  m.fecha
FROM movimientos m
JOIN productos p ON p.id = m.producto_id
WHERE p.factor_caja > 1
  AND UPPER(p.nombre) NOT LIKE '%DESODORANTE DESINFECTANTE LYSOFORM%'
ORDER BY p.nombre, m.fecha;


-- ============================================================
-- PASO 2: CONVERTIR CAJAS → UNIDADES
-- ============================================================
-- Multiplica cada cantidad por el factor_caja del producto.
-- Ejemplo: 18 (cajas) × 100 (unidades/caja) = 1800 (unidades)

UPDATE movimientos
SET cantidad = movimientos.cantidad * p.factor_caja
FROM productos p
WHERE movimientos.producto_id = p.id
  AND p.factor_caja > 1
  AND UPPER(p.nombre) NOT LIKE '%DESODORANTE DESINFECTANTE LYSOFORM%';


-- ============================================================
-- PASO 3: ACTUALIZAR VISTA v_stock (formato nuevo)
-- ============================================================
-- Display: "18 Caja x100 unidad" en vez de "18 Caja x100 + 0 unidad"

CREATE OR REPLACE VIEW v_stock AS
SELECT
  p.id,
  p.stock_id_almacen,
  p.nombre,
  p.tipo,
  p.subcategoria,
  p.unidad_base,
  p.factor_caja,
  p.nombre_caja,
  p.stock_minimo,
  p.punto_reposicion,
  p.requiere_lote,
  stock_actual(p.id) AS stock_actual,
  CASE
    WHEN stock_actual(p.id) = 0            THEN 'SIN_STOCK'
    WHEN stock_actual(p.id) <= p.stock_minimo     THEN 'CRITICO'
    WHEN stock_actual(p.id) <= p.punto_reposicion THEN 'BAJO'
    ELSE 'OK'
  END AS semaforo,
  CASE
    WHEN p.factor_caja > 1 THEN
      stock_actual(p.id) / p.factor_caja || ' ' || p.nombre_caja || ' x' || p.factor_caja || ' ' || p.unidad_base ||
      CASE WHEN stock_actual(p.id) % p.factor_caja > 0
        THEN ' + ' || (stock_actual(p.id) % p.factor_caja) || ' ' || p.unidad_base || ' sueltas'
        ELSE ''
      END
    ELSE stock_actual(p.id) || ' ' || p.unidad_base
  END AS stock_display
FROM productos p
WHERE p.activo = true
ORDER BY
  CASE
    WHEN stock_actual(p.id) = 0 THEN 0
    WHEN stock_actual(p.id) <= p.stock_minimo THEN 1
    WHEN stock_actual(p.id) <= p.punto_reposicion THEN 2
    ELSE 3
  END,
  p.tipo, p.nombre;


-- ============================================================
-- PASO 4: VERIFICACIÓN
-- ============================================================

SELECT
  p.nombre,
  p.factor_caja AS unid_por_caja,
  stock_actual(p.id) AS total_unidades,
  stock_actual(p.id) / p.factor_caja AS cajas,
  stock_actual(p.id) % p.factor_caja AS sueltas,
  v.stock_display,
  v.semaforo
FROM productos p
JOIN v_stock v ON v.id = p.id
WHERE p.activo = true
ORDER BY p.nombre;
