-- ============================================================
-- SP CONTROL DATA — MÓDULO OPERATIVO
-- Migración para flujo completo de PEDIDOS (crear → aprobar FEFO → entregar)
-- Fecha: 2026-04-22
-- ============================================================
--
-- INSTRUCCIONES:
-- 1. Abrí Supabase Studio → SQL Editor
--    (https://supabase.com/dashboard/project/erjdncsnomwymjiaslpx/sql)
-- 2. Pegá este archivo completo y ejecutalo.
-- 3. Es idempotente: seguro de correr varias veces.
--
-- Todos los cambios usan IF NOT EXISTS / OR REPLACE para no romper
-- lo que ya exista.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. Columnas nuevas en `pedidos`
-- ────────────────────────────────────────────────────────────
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS entregado_por   BIGINT REFERENCES usuarios(id);
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS fecha_entrega   TIMESTAMPTZ;
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS motivo_rechazo  TEXT;

-- ────────────────────────────────────────────────────────────
-- 2. `movimientos`: asegurar que exista lote_id (para FEFO)
-- ────────────────────────────────────────────────────────────
ALTER TABLE movimientos ADD COLUMN IF NOT EXISTS lote_id BIGINT REFERENCES lotes(id);
CREATE INDEX IF NOT EXISTS idx_movimientos_lote ON movimientos(lote_id);
CREATE INDEX IF NOT EXISTS idx_movimientos_pedido ON movimientos(pedido_id);

-- ────────────────────────────────────────────────────────────
-- 3. Vista v_pedidos — agregar entregado_por_username + motivo_rechazo
-- ────────────────────────────────────────────────────────────
DROP VIEW IF EXISTS v_pedidos;
CREATE VIEW v_pedidos AS
SELECT
  p.id,
  p.solicitante_id,
  u1.username           AS solicitante,
  u1.nombre             AS solicitante_nombre,
  p.servicio,
  p.urgencia,
  p.estado,
  p.observacion,
  p.motivo_rechazo,
  p.fecha,
  p.aprobado_por,
  u2.username           AS aprobado_por_username,
  p.fecha_aprobacion,
  p.entregado_por,
  u3.username           AS entregado_por_username,
  p.fecha_entrega,
  COALESCE((SELECT COUNT(*) FROM pedido_items pi WHERE pi.pedido_id = p.id), 0)                  AS total_items,
  COALESCE((SELECT SUM(pi.cantidad_solicitada) FROM pedido_items pi WHERE pi.pedido_id = p.id), 0) AS total_unidades
FROM pedidos p
LEFT JOIN usuarios u1 ON u1.id = p.solicitante_id
LEFT JOIN usuarios u2 ON u2.id = p.aprobado_por
LEFT JOIN usuarios u3 ON u3.id = p.entregado_por;

-- ────────────────────────────────────────────────────────────
-- 4. Check de constraint para estado válido (opcional; solo si querés
-- que la DB valide los valores permitidos).
-- Si ya tenés un CHECK previo, coméntalo y reejecutalo.
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.check_constraints
    WHERE constraint_name = 'pedidos_estado_check'
  ) THEN
    ALTER TABLE pedidos
      ADD CONSTRAINT pedidos_estado_check
      CHECK (estado IN ('PENDIENTE','APROBADO','ENTREGADO','RECHAZADO'));
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 5. RLS — permitir que los anon (anon key) hagan SELECT/INSERT/UPDATE
-- sobre las tablas de pedidos. Si ya tenés policies, esto es no-op.
-- Ajustá según tu política de seguridad actual.
-- ────────────────────────────────────────────────────────────
-- Nota: Como el módulo usa custom auth (username+PIN) y no supabase.auth,
-- estas policies asumen acceso abierto vía anon key. Si querés reforzar,
-- podés mover la lógica de permisos a funciones SECURITY DEFINER.

-- (Ejecutá solo si NO tenés RLS configurado y querés abrir acceso completo)
-- ALTER TABLE pedidos        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE pedido_items   ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE movimientos    ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE lotes          ENABLE ROW LEVEL SECURITY;
-- CREATE POLICY pedidos_all     ON pedidos      FOR ALL TO anon USING (true) WITH CHECK (true);
-- CREATE POLICY pedido_items_all ON pedido_items FOR ALL TO anon USING (true) WITH CHECK (true);
-- CREATE POLICY movimientos_all ON movimientos  FOR ALL TO anon USING (true) WITH CHECK (true);
-- CREATE POLICY lotes_all       ON lotes         FOR ALL TO anon USING (true) WITH CHECK (true);

-- ────────────────────────────────────────────────────────────
-- ✓ Fin de migración
-- ────────────────────────────────────────────────────────────
