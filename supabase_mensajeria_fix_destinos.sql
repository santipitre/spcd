-- ============================================================
-- SPCD MENSAJERÍA — FIX destinos (2026-04-27)
-- ------------------------------------------------------------
-- Desactiva el destino "Informática" porque ahora el catch-all
-- queda en "Otros" con observaciones obligatorias.
-- ============================================================

-- Soft-delete (no rompe FKs si ya hay retiros apuntando a él)
UPDATE mensajeria_destinos
SET activo = false
WHERE LOWER(nombre) IN ('informática', 'informatica');

-- Verificar
SELECT id, nombre, activo, orden FROM mensajeria_destinos ORDER BY orden;
