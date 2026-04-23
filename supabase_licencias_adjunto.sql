-- ============================================================
-- SP CONTROL DATA — MIGRACIÓN: Agregar adjuntos a licencias
-- Ejecutar SI ya corriste antes supabase_licencias.sql
-- (agrega columnas del archivo adjunto + recrea la vista).
-- ============================================================

-- Columnas nuevas para guardar el archivo (imagen JPEG comprimida o PDF)
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_base64 TEXT;
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_nombre TEXT;
ALTER TABLE licencias ADD COLUMN IF NOT EXISTS adjunto_tipo   TEXT;

-- Recrear la vista incluyendo los datos del adjunto
DROP VIEW IF EXISTS v_licencias;
CREATE VIEW v_licencias AS
SELECT
  l.id, l.tipo, l.fecha_desde, l.fecha_hasta, l.hora_desde, l.hora_hasta,
  l.motivo, l.observacion, l.estado, l.motivo_rechazo, l.companero_acepta,
  l.fecha_creacion, l.fecha_aprobacion,
  l.solicitante_id, u1.username AS solicitante, u1.nombre AS solicitante_nombre,
  l.aprobado_por,   u2.username AS aprobado_por_username, u2.nombre AS aprobado_por_nombre,
  l.companero_id,   u3.username AS companero_username,    u3.nombre AS companero_nombre,
  l.adjunto_nombre, l.adjunto_tipo,
  (l.adjunto_base64 IS NOT NULL) AS tiene_adjunto
FROM licencias l
LEFT JOIN usuarios u1 ON u1.id = l.solicitante_id
LEFT JOIN usuarios u2 ON u2.id = l.aprobado_por
LEFT JOIN usuarios u3 ON u3.id = l.companero_id;
