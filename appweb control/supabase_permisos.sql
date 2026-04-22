-- ============================================================
-- SP CONTROL DATA — PERMISOS POR USUARIO
-- Agrega columna 'permisos' JSONB a la tabla usuarios
-- para controlar acceso a sedes y módulos
-- ============================================================
-- INSTRUCCIONES:
--   1. Abrí Supabase Dashboard → SQL Editor → Nueva pestaña (+)
--   2. Pegá todo este contenido
--   3. Click en "Run"
-- ============================================================

-- 1. Agregar columna permisos (JSONB)
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS permisos JSONB DEFAULT '{}';

COMMENT ON COLUMN usuarios.permisos IS 'Permisos del usuario: { sedes: ["*"] o ["Sede X"], modulos: { admin: "edit"|"view"|null, tecnico: "edit"|"view"|null, medico: "edit"|"view"|null, operativo: "admin"|"view"|"pedidos"|null } }';

-- 2. Configurar permisos para cada usuario existente

-- SPITRELLA (admin): todo
UPDATE usuarios SET permisos = '{
  "sedes": ["*"],
  "modulos": {
    "admin": "edit",
    "tecnico": "edit",
    "medico": "edit",
    "operativo": "admin"
  }
}'::jsonb WHERE username = 'SPITRELLA';

-- IBORONI (consultor): ve todo pero solo lectura
UPDATE usuarios SET permisos = '{
  "sedes": ["*"],
  "modulos": {
    "admin": "view",
    "tecnico": "view",
    "medico": "view",
    "operativo": "view"
  }
}'::jsonb WHERE username = 'IBORONI';

-- LBASTIAS (mixto): Sede HI, Médico completo + Operativo completo
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "medico": "edit",
    "operativo": "admin"
  }
}'::jsonb WHERE username = 'LBASTIAS';

-- AWALKER (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'AWALKER';

-- ISKAMLEC (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'ISKAMLEC';

-- TRUMBO (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'TRUMBO';

-- VFORNI (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'VFORNI';

-- MWSANCHEZ (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'MWSANCHEZ';

-- JAVILA (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'JAVILA';

-- JMONICA (solicitante): Sede HI, solo Operativo pedidos
UPDATE usuarios SET permisos = '{
  "sedes": ["Sede Hospital Italiano"],
  "modulos": {
    "operativo": "pedidos"
  }
}'::jsonb WHERE username = 'JMONICA';

-- 3. Actualizar función verificar_pin para incluir permisos en el resultado
CREATE OR REPLACE FUNCTION verificar_pin(p_username TEXT, p_pin TEXT)
RETURNS TABLE(
  id UUID,
  username TEXT,
  nombre TEXT,
  rol TEXT,
  debe_cambiar_pin BOOLEAN,
  permisos JSONB
) AS $$
BEGIN
  RETURN QUERY
  SELECT u.id, u.username, u.nombre, u.rol, u.debe_cambiar_pin, u.permisos
  FROM usuarios u
  WHERE u.username = UPPER(TRIM(p_username))
    AND u.pin = crypt(p_pin, u.pin)
    AND u.activo = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Verificación
SELECT username, nombre, rol, permisos FROM usuarios WHERE activo = true ORDER BY username;
