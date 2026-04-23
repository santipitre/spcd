-- ============================================================
-- SP CONTROL DATA — Habilitar Realtime en tablas
-- ------------------------------------------------------------
-- Supabase Realtime solo emite eventos de las tablas que están
-- en la "publication" supabase_realtime. Este SQL las agrega.
-- Correr UNA sola vez.
-- ============================================================

-- Pedidos de insumos
ALTER PUBLICATION supabase_realtime ADD TABLE pedidos;

-- Solicitudes de licencia
ALTER PUBLICATION supabase_realtime ADD TABLE licencias;

-- Verificación (debería listar ambas tablas)
SELECT tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
