-- ============================================================
-- SP CONTROL DATA — MÓDULO OPERATIVO
-- Base de datos Supabase (PostgreSQL)
-- Fase 0: Tablas + Funciones + Vistas + Usuarios iniciales
-- ============================================================
-- INSTRUCCIONES:
--   1. Abrí Supabase Dashboard → SQL Editor (ícono de terminal)
--   2. Pegá todo este contenido
--   3. Click en "Run" (o Ctrl+Enter)
--   4. Debería decir "Success. No rows returned" o similar
-- ============================================================

-- Habilitar extensión para hash de PIN (bcrypt)
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- 1. USUARIOS (autenticación por username + PIN)
-- ============================================================
CREATE TABLE usuarios (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  username    TEXT UNIQUE NOT NULL,
  pin         TEXT NOT NULL,
  nombre      TEXT NOT NULL,
  rol         TEXT NOT NULL CHECK (rol IN ('admin','consultor','mixto','solicitante')),
  activo      BOOLEAN DEFAULT true,
  debe_cambiar_pin BOOLEAN DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE usuarios IS 'Usuarios de la app con rol y PIN hasheado (bcrypt)';
COMMENT ON COLUMN usuarios.rol IS 'admin=todo, consultor=solo lectura, mixto=medico+pedidos, solicitante=solo pedidos';

-- ============================================================
-- 2. PRODUCTOS (catálogo de insumos y medicación)
-- ============================================================
CREATE TABLE productos (
  id                  SERIAL PRIMARY KEY,
  stock_id_almacen    INTEGER,
  nombre              TEXT NOT NULL,
  tipo                TEXT NOT NULL CHECK (tipo IN ('MED','INS')),
  subcategoria        TEXT,
  unidad_base         TEXT NOT NULL DEFAULT 'unidad',
  factor_caja         INTEGER DEFAULT 1,
  nombre_caja         TEXT DEFAULT 'Unidad',
  stock_minimo        INTEGER DEFAULT 0,
  punto_reposicion    INTEGER DEFAULT 0,
  requiere_lote       BOOLEAN DEFAULT false,
  activo              BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE productos IS 'Catálogo maestro — cada producto con su clasificación MED/INS y unidades';
COMMENT ON COLUMN productos.stock_id_almacen IS 'Código del sistema de Almacén Central (ej: 7410)';
COMMENT ON COLUMN productos.factor_caja IS 'Cuántas unidades_base tiene 1 caja (ej: 100)';
COMMENT ON COLUMN productos.punto_reposicion IS 'Umbral ámbar: por debajo de esto hay que pedir';
COMMENT ON COLUMN productos.stock_minimo IS 'Umbral rojo: stock crítico';

-- ============================================================
-- 3. LOTES (medicación con vencimiento — FEFO)
-- ============================================================
CREATE TABLE lotes (
  id                  SERIAL PRIMARY KEY,
  producto_id         INTEGER NOT NULL REFERENCES productos(id) ON DELETE CASCADE,
  nro_lote            TEXT NOT NULL,
  fecha_vencimiento   DATE NOT NULL,
  cantidad_actual     INTEGER DEFAULT 0,
  activo              BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE lotes IS 'Lotes de medicación — para FEFO (First Expires First Out) y alertas de vencimiento';

-- ============================================================
-- 4. PEDIDOS (encabezado)
-- ============================================================
CREATE TABLE pedidos (
  id                SERIAL PRIMARY KEY,
  fecha             TIMESTAMPTZ DEFAULT now(),
  solicitante_id    UUID NOT NULL REFERENCES usuarios(id),
  servicio          TEXT NOT NULL,
  estado            TEXT NOT NULL DEFAULT 'PENDIENTE'
                      CHECK (estado IN ('PENDIENTE','APROBADO','ENTREGADO','RECHAZADO')),
  urgencia          TEXT DEFAULT 'NORMAL'
                      CHECK (urgencia IN ('NORMAL','URGENTE','EMERGENCIA')),
  aprobado_por      UUID REFERENCES usuarios(id),
  fecha_aprobacion  TIMESTAMPTZ,
  fecha_entrega     TIMESTAMPTZ,
  observacion       TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE pedidos IS 'Pedidos del personal — workflow: PENDIENTE → APROBADO → ENTREGADO';

-- ============================================================
-- 5. ITEMS DE PEDIDO (detalle)
-- ============================================================
CREATE TABLE pedido_items (
  id                    SERIAL PRIMARY KEY,
  pedido_id             INTEGER NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
  producto_id           INTEGER NOT NULL REFERENCES productos(id),
  cantidad_solicitada   INTEGER NOT NULL CHECK (cantidad_solicitada > 0),
  cantidad_entregada    INTEGER DEFAULT 0,
  observacion           TEXT
);

COMMENT ON TABLE pedido_items IS 'Líneas de cada pedido — cantidad solicitada puede diferir de entregada';

-- ============================================================
-- 6. MOVIMIENTOS (append-only — el corazón del sistema)
-- ============================================================
CREATE TABLE movimientos (
  id                SERIAL PRIMARY KEY,
  fecha             TIMESTAMPTZ DEFAULT now(),
  tipo              TEXT NOT NULL CHECK (tipo IN ('ENTRADA','SALIDA','AJUSTE','BAJA_VENCIDO')),
  producto_id       INTEGER NOT NULL REFERENCES productos(id),
  lote_id           INTEGER REFERENCES lotes(id),
  cantidad          INTEGER NOT NULL,
  remito_nro        TEXT,
  pedido_id         INTEGER REFERENCES pedidos(id),
  servicio_destino  TEXT,
  usuario_id        UUID NOT NULL REFERENCES usuarios(id),
  observacion       TEXT,
  created_at        TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE movimientos IS 'Registro inmutable de entradas/salidas/ajustes — stock se calcula desde acá';
COMMENT ON COLUMN movimientos.cantidad IS 'Positivo para ENTRADA/AJUSTE+, negativo para SALIDA/BAJA';

-- ============================================================
-- 7. LOG DE AUDITORÍA (quién hizo qué y cuándo)
-- ============================================================
CREATE TABLE audit_log (
  id          SERIAL PRIMARY KEY,
  fecha       TIMESTAMPTZ DEFAULT now(),
  usuario_id  UUID REFERENCES usuarios(id),
  accion      TEXT NOT NULL,
  tabla       TEXT,
  registro_id TEXT,
  detalle     JSONB,
  ip          TEXT
);

COMMENT ON TABLE audit_log IS 'Log de auditoría: cada acción relevante queda registrada';

-- ============================================================
-- ÍNDICES para performance
-- ============================================================
CREATE INDEX idx_productos_tipo ON productos(tipo);
CREATE INDEX idx_productos_stockid ON productos(stock_id_almacen);
CREATE INDEX idx_lotes_producto ON lotes(producto_id);
CREATE INDEX idx_lotes_vencimiento ON lotes(fecha_vencimiento);
CREATE INDEX idx_movimientos_producto ON movimientos(producto_id);
CREATE INDEX idx_movimientos_fecha ON movimientos(fecha);
CREATE INDEX idx_movimientos_tipo ON movimientos(tipo);
CREATE INDEX idx_pedidos_estado ON pedidos(estado);
CREATE INDEX idx_pedidos_solicitante ON pedidos(solicitante_id);
CREATE INDEX idx_pedido_items_pedido ON pedido_items(pedido_id);
CREATE INDEX idx_audit_usuario ON audit_log(usuario_id);
CREATE INDEX idx_audit_fecha ON audit_log(fecha);

-- ============================================================
-- ROW LEVEL SECURITY
-- Habilitamos RLS en todas las tablas.
-- Usamos políticas permisivas para el rol anon porque los
-- permisos se controlan en el frontend según el rol del usuario.
-- El PIN está hasheado con bcrypt, no es accesible en texto plano.
-- ============================================================
ALTER TABLE usuarios      ENABLE ROW LEVEL SECURITY;
ALTER TABLE productos     ENABLE ROW LEVEL SECURITY;
ALTER TABLE lotes         ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos       ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_items  ENABLE ROW LEVEL SECURITY;
ALTER TABLE movimientos   ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log     ENABLE ROW LEVEL SECURITY;

CREATE POLICY "allow_anon" ON usuarios      FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON productos     FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON lotes         FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON pedidos       FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON pedido_items  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON movimientos   FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY "allow_anon" ON audit_log     FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- FUNCIONES
-- ============================================================

-- Verificar login: recibe username + PIN en texto plano,
-- retorna datos del usuario si es válido, o vacío si no.
CREATE OR REPLACE FUNCTION verificar_pin(p_username TEXT, p_pin TEXT)
RETURNS TABLE(
  id UUID,
  username TEXT,
  nombre TEXT,
  rol TEXT,
  debe_cambiar_pin BOOLEAN
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.username, u.nombre, u.rol, u.debe_cambiar_pin
  FROM usuarios u
  WHERE u.username = UPPER(TRIM(p_username))
    AND u.pin = crypt(p_pin, u.pin)
    AND u.activo = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION verificar_pin IS 'Login: verifica username+PIN, retorna usuario o vacío';

-- Cambiar PIN: verifica el actual, hashea el nuevo
CREATE OR REPLACE FUNCTION cambiar_pin(
  p_usuario_id UUID,
  p_pin_actual TEXT,
  p_pin_nuevo TEXT
) RETURNS BOOLEAN AS $$
DECLARE
  v_valid BOOLEAN;
BEGIN
  -- Verificar PIN actual
  SELECT EXISTS(
    SELECT 1 FROM usuarios u
    WHERE u.id = p_usuario_id
      AND u.pin = crypt(p_pin_actual, u.pin)
      AND u.activo = true
  ) INTO v_valid;

  IF NOT v_valid THEN RETURN false; END IF;

  -- Actualizar al nuevo PIN
  UPDATE usuarios
  SET pin = crypt(p_pin_nuevo, gen_salt('bf')),
      debe_cambiar_pin = false,
      updated_at = now()
  WHERE id = p_usuario_id;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION cambiar_pin IS 'Cambia PIN del usuario (verifica actual primero)';

-- Stock actual de un producto (suma de movimientos)
CREATE OR REPLACE FUNCTION stock_actual(p_producto_id INTEGER)
RETURNS INTEGER AS $$
  SELECT COALESCE(SUM(cantidad), 0)::INTEGER
  FROM movimientos
  WHERE producto_id = p_producto_id;
$$ LANGUAGE sql STABLE;

COMMENT ON FUNCTION stock_actual IS 'Calcula stock actual sumando todos los movimientos del producto';

-- ============================================================
-- VISTAS
-- ============================================================

-- Vista de stock completo con semáforo
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
      stock_actual(p.id) / p.factor_caja || ' ' || p.nombre_caja ||
      CASE WHEN stock_actual(p.id) % p.factor_caja > 0
        THEN ' + ' || (stock_actual(p.id) % p.factor_caja) || ' ' || p.unidad_base
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

COMMENT ON VIEW v_stock IS 'Stock con semáforo: SIN_STOCK > CRITICO > BAJO > OK — ordenado por criticidad';

-- Vista de lotes próximos a vencer
CREATE OR REPLACE VIEW v_lotes_vencimiento AS
SELECT
  l.id AS lote_id,
  l.producto_id,
  p.nombre AS producto,
  p.tipo,
  l.nro_lote,
  l.fecha_vencimiento,
  l.cantidad_actual,
  (l.fecha_vencimiento - CURRENT_DATE) AS dias_restantes,
  CASE
    WHEN l.fecha_vencimiento <= CURRENT_DATE              THEN 'VENCIDO'
    WHEN (l.fecha_vencimiento - CURRENT_DATE) <= 15       THEN 'CRITICO'
    WHEN (l.fecha_vencimiento - CURRENT_DATE) <= 30       THEN 'ALERTA'
    WHEN (l.fecha_vencimiento - CURRENT_DATE) <= 60       THEN 'ATENCION'
    WHEN (l.fecha_vencimiento - CURRENT_DATE) <= 90       THEN 'PROXIMO'
    ELSE 'OK'
  END AS estado_vencimiento
FROM lotes l
JOIN productos p ON p.id = l.producto_id
WHERE l.activo = true
  AND l.cantidad_actual > 0
ORDER BY l.fecha_vencimiento ASC;

COMMENT ON VIEW v_lotes_vencimiento IS 'Lotes activos ordenados por vencimiento — incluye semáforo escalonado';

-- Vista de pedidos con datos del solicitante
CREATE OR REPLACE VIEW v_pedidos AS
SELECT
  p.id,
  p.fecha,
  s.username AS solicitante,
  s.nombre AS solicitante_nombre,
  p.servicio,
  p.estado,
  p.urgencia,
  a.username AS aprobado_por_username,
  p.fecha_aprobacion,
  p.fecha_entrega,
  p.observacion,
  (SELECT COUNT(*) FROM pedido_items pi WHERE pi.pedido_id = p.id) AS total_items,
  (SELECT SUM(pi.cantidad_solicitada) FROM pedido_items pi WHERE pi.pedido_id = p.id) AS total_unidades
FROM pedidos p
JOIN usuarios s ON s.id = p.solicitante_id
LEFT JOIN usuarios a ON a.id = p.aprobado_por
ORDER BY
  CASE p.estado
    WHEN 'PENDIENTE' THEN 0
    WHEN 'APROBADO'  THEN 1
    WHEN 'ENTREGADO' THEN 2
    WHEN 'RECHAZADO' THEN 3
  END,
  CASE p.urgencia
    WHEN 'EMERGENCIA' THEN 0
    WHEN 'URGENTE'    THEN 1
    ELSE 2
  END,
  p.fecha DESC;

COMMENT ON VIEW v_pedidos IS 'Pedidos con nombre del solicitante — ordenados: pendientes primero, urgentes arriba';

-- ============================================================
-- USUARIOS INICIALES
-- PIN default: 1234 (deben cambiarlo en el primer login)
-- ============================================================
INSERT INTO usuarios (username, pin, nombre, rol, debe_cambiar_pin) VALUES
  ('SPITRELLA', crypt('1234', gen_salt('bf')), 'Santiago Pitrella',  'admin',       true),
  ('IBORONI',   crypt('1234', gen_salt('bf')), 'I. Boroni',          'consultor',   true),
  ('LBASTIAS',  crypt('1234', gen_salt('bf')), 'L. Bastías',         'mixto',       true),
  ('AWALKER',   crypt('1234', gen_salt('bf')), 'A. Walker',          'solicitante', true),
  ('ISKAMLEC',  crypt('1234', gen_salt('bf')), 'I. Skamlec',         'solicitante', true),
  ('TRUMBO',    crypt('1234', gen_salt('bf')), 'T. Rumbo',           'solicitante', true),
  ('VFORNI',    crypt('1234', gen_salt('bf')), 'V. Forni',           'solicitante', true),
  ('MWSANCHEZ', crypt('1234', gen_salt('bf')), 'M.W. Sánchez',      'solicitante', true);

-- ============================================================
-- VERIFICACIÓN: contar tablas creadas
-- ============================================================
SELECT
  'TABLAS CREADAS' AS resultado,
  COUNT(*) AS total
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'BASE TABLE'
  AND table_name IN ('usuarios','productos','lotes','pedidos','pedido_items','movimientos','audit_log');
