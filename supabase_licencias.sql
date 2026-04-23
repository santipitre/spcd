-- ============================================================
-- SP CONTROL DATA — MÓDULO PERSONAL (Licencias)
-- Tabla para solicitudes de licencia, cambios de turno y horarios.
-- Fecha: 2026-04-22
-- ============================================================
-- Ejecutar en: Supabase Dashboard → SQL Editor
--   https://supabase.com/dashboard/project/erjdncsnomwymjiaslpx/sql
-- Es idempotente: seguro de correr varias veces.
-- ============================================================

-- ── Tabla principal ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS licencias (
  id               SERIAL PRIMARY KEY,
  solicitante_id   UUID NOT NULL REFERENCES usuarios(id),
  tipo             TEXT NOT NULL CHECK (tipo IN ('DIA_LIBRE','CAMBIO_TURNO','TARDE','TEMPRANO')),

  -- Fechas (fecha_desde siempre, fecha_hasta solo si son varios días)
  fecha_desde      DATE NOT NULL,
  fecha_hasta      DATE,

  -- Horas (solo para TARDE/TEMPRANO: desde/hasta qué hora)
  hora_desde       TIME,
  hora_hasta       TIME,

  motivo           TEXT,
  observacion      TEXT,

  -- Si es CAMBIO_TURNO, referencia al compañero
  companero_id     UUID REFERENCES usuarios(id),
  companero_acepta BOOLEAN DEFAULT FALSE,

  -- Workflow
  estado           TEXT NOT NULL DEFAULT 'PENDIENTE'
                     CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO','CANCELADO')),
  aprobado_por     UUID REFERENCES usuarios(id),
  fecha_aprobacion TIMESTAMPTZ,
  motivo_rechazo   TEXT,

  fecha_creacion   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Adjunto opcional (certificado, foto, PDF corto) guardado como base64
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_base64 TEXT;
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_nombre TEXT;
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_tipo   TEXT;

-- Índices
CREATE INDEX IF NOT EXISTS idx_licencias_solicitante ON licencias(solicitante_id);
CREATE INDEX IF NOT EXISTS idx_licencias_estado      ON licencias(estado);
CREATE INDEX IF NOT EXISTS idx_licencias_fecha       ON licencias(fecha_desde);
CREATE INDEX IF NOT EXISTS idx_licencias_tipo        ON licencias(tipo);

-- ── Vista con joins a usuarios (para el frontend) ─────────
DROP VIEW IF EXISTS v_licencias;
CREATE VIEW v_licencias AS
SELECT
  l.id,
  l.tipo,
  l.fecha_desde,
  l.fecha_hasta,
  l.hora_desde,
  l.hora_hasta,
  l.motivo,
  l.observacion,
  l.estado,
  l.motivo_rechazo,
  l.companero_acepta,
  l.fecha_creacion,
  l.fecha_aprobacion,
  l.solicitante_id,
  u1.username AS solicitante,
  u1.nombre   AS solicitante_nombre,
  l.aprobado_por,
  u2.username AS aprobado_por_username,
  u2.nombre   AS aprobado_por_nombre,
  l.companero_id,
  u3.username AS companero_username,
  u3.nombre   AS companero_nombre,
  -- Adjunto
  l.adjunto_nombre,
  l.adjunto_tipo,
  (l.adjunto_base64 IS NOT NULL) AS tiene_adjunto
FROM licencias l
LEFT JOIN usuarios u1 ON u1.id = l.solicitante_id
LEFT JOIN usuarios u2 ON u2.id = l.aprobado_por
LEFT JOIN usuarios u3 ON u3.id = l.companero_id;

-- ── RLS ────────────────────────────────────────────────
-- Como el sistema usa custom auth (username+PIN), y la anon key
-- es pública, desactivamos RLS para que anon pueda leer/escribir.
-- La seguridad real se valida en el frontend por rol.
-- (Si preferís mantener RLS activo, reemplazá esto con policies permisivas.)
ALTER TABLE licencias DISABLE ROW LEVEL SECURITY;

-- ── Fin ─────────────────────────────────────────────────────
