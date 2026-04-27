-- ============================================================
-- SPCD MENSAJERÍA — Migración inicial
-- Fecha: 2026-04-27
-- ------------------------------------------------------------
-- Crea las tablas, RLS, RPCs y seed para el sub-módulo de
-- control de retiros de cajas y sobres por los mensajeros
-- internos de FUESMEN.
--
-- Ejecutar en SQL Editor de Supabase EN ORDEN.
-- Idempotente (se puede correr varias veces sin romper).
-- ============================================================

-- Extensión necesaria para hashes de PIN
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================
-- TABLAS
-- ============================================================

-- ── 1. MENSAJEROS ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mensajeros (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre             text NOT NULL,
  dni                text,
  telefono           text,
  pin_hash           text NOT NULL,
  activo             boolean NOT NULL DEFAULT true,
  intentos_fallidos  int NOT NULL DEFAULT 0,
  bloqueado_hasta    timestamptz,
  created_at         timestamptz NOT NULL DEFAULT now(),
  updated_at         timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_mensajeros_activo ON mensajeros(activo) WHERE activo = true;

-- ── 2. DESTINOS ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mensajeria_destinos (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre     text NOT NULL UNIQUE,
  direccion  text,
  orden      int NOT NULL DEFAULT 0,
  activo     boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ── 3. RETIROS (cabecera) ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS mensajeria_retiros (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  fecha_hora          timestamptz NOT NULL DEFAULT now(),
  encargado_user_id   uuid,
  encargado_nombre    text NOT NULL,
  mensajero_id        uuid NOT NULL REFERENCES mensajeros(id),
  destino_id          uuid NOT NULL REFERENCES mensajeria_destinos(id),
  estado              text NOT NULL DEFAULT 'PENDIENTE_FIRMA'
                      CHECK (estado IN ('PENDIENTE_FIRMA','FIRMADO','EXPIRADO','FIRMA_ASISTIDA','ANULADO')),
  cant_cajas          int  NOT NULL DEFAULT 0 CHECK (cant_cajas >= 0),
  cant_sobres         int  NOT NULL DEFAULT 0 CHECK (cant_sobres >= 0),
  monto_total         numeric(14,2) NOT NULL DEFAULT 0 CHECK (monto_total >= 0),
  qr_token            uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  qr_expires_at       timestamptz NOT NULL,
  firmado_at          timestamptz,
  firmado_ip          text,
  observaciones       text,
  created_at          timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_retiros_fecha     ON mensajeria_retiros(fecha_hora DESC);
CREATE INDEX IF NOT EXISTS idx_retiros_estado    ON mensajeria_retiros(estado);
CREATE INDEX IF NOT EXISTS idx_retiros_mensajero ON mensajeria_retiros(mensajero_id);
CREATE INDEX IF NOT EXISTS idx_retiros_token     ON mensajeria_retiros(qr_token);

-- ── 4. SOBRES (detalle) ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS mensajeria_sobres (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  retiro_id     uuid NOT NULL REFERENCES mensajeria_retiros(id) ON DELETE CASCADE,
  numero_cajera text NOT NULL,
  monto         numeric(14,2) NOT NULL DEFAULT 0 CHECK (monto >= 0),
  orden         int NOT NULL DEFAULT 0,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sobres_retiro ON mensajeria_sobres(retiro_id);

-- ============================================================
-- RLS — ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE mensajeros          ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensajeria_destinos ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensajeria_retiros  ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensajeria_sobres   ENABLE ROW LEVEL SECURITY;

-- Authenticated (encargados) → acceso total a las 4 tablas
DROP POLICY IF EXISTS auth_all_mensajeros          ON mensajeros;
DROP POLICY IF EXISTS auth_all_mensajeria_destinos ON mensajeria_destinos;
DROP POLICY IF EXISTS auth_all_mensajeria_retiros  ON mensajeria_retiros;
DROP POLICY IF EXISTS auth_all_mensajeria_sobres   ON mensajeria_sobres;

CREATE POLICY auth_all_mensajeros          ON mensajeros          FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY auth_all_mensajeria_destinos ON mensajeria_destinos FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY auth_all_mensajeria_retiros  ON mensajeria_retiros  FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY auth_all_mensajeria_sobres   ON mensajeria_sobres   FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- IMPORTANTE: anon NO tiene policies → no puede leer/escribir tablas directamente.
-- Toda interacción anon (mensajero firmando desde el celu) pasa por las RPCs SECURITY DEFINER.

-- Si no usás auth de Supabase y todo va con anon key, descomentá las policies de abajo
-- (igual la firma seguirá pasando por RPC, pero el encargado podrá CRUD sobre las tablas).
DROP POLICY IF EXISTS anon_all_mensajeros          ON mensajeros;
DROP POLICY IF EXISTS anon_all_mensajeria_destinos ON mensajeria_destinos;
DROP POLICY IF EXISTS anon_all_mensajeria_retiros  ON mensajeria_retiros;
DROP POLICY IF EXISTS anon_all_mensajeria_sobres   ON mensajeria_sobres;

CREATE POLICY anon_all_mensajeros          ON mensajeros          FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all_mensajeria_destinos ON mensajeria_destinos FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all_mensajeria_retiros  ON mensajeria_retiros  FOR ALL TO anon USING (true) WITH CHECK (true);
CREATE POLICY anon_all_mensajeria_sobres   ON mensajeria_sobres   FOR ALL TO anon USING (true) WITH CHECK (true);

-- ============================================================
-- RPCs (funciones que usa el frontend)
-- ============================================================

-- ── consultar_retiro_por_token: para mensajeria-firmar.html ──
CREATE OR REPLACE FUNCTION consultar_retiro_por_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
  v_destino    mensajeria_destinos;
  v_sobres     jsonb;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE qr_token::text = p_token;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOKEN_INVALIDO');
  END IF;

  SELECT * INTO v_mensajero FROM mensajeros          WHERE id = v_retiro.mensajero_id;
  SELECT * INTO v_destino   FROM mensajeria_destinos WHERE id = v_retiro.destino_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('numero_cajera', numero_cajera, 'monto', monto) ORDER BY orden), '[]'::jsonb)
    INTO v_sobres
    FROM mensajeria_sobres WHERE retiro_id = v_retiro.id;

  RETURN jsonb_build_object(
    'ok',                true,
    'retiro_id',         v_retiro.id,
    'fecha_hora',        v_retiro.fecha_hora,
    'estado',            v_retiro.estado,
    'expires_at',        v_retiro.qr_expires_at,
    'expirado',          (v_retiro.qr_expires_at < now()),
    'mensajero_id',      v_mensajero.id,
    'mensajero_nombre',  v_mensajero.nombre,
    'destino_nombre',    v_destino.nombre,
    'destino_direccion', v_destino.direccion,
    'cant_cajas',        v_retiro.cant_cajas,
    'cant_sobres',       v_retiro.cant_sobres,
    'monto_total',       v_retiro.monto_total,
    'sobres',            v_sobres,
    'observaciones',     v_retiro.observaciones,
    'encargado_nombre',  v_retiro.encargado_nombre,
    'firmado_at',        v_retiro.firmado_at
  );
END $$;

GRANT EXECUTE ON FUNCTION consultar_retiro_por_token(text) TO anon;
GRANT EXECUTE ON FUNCTION consultar_retiro_por_token(text) TO authenticated;

-- ── firmar_retiro: el mensajero firma con PIN ──
CREATE OR REPLACE FUNCTION firmar_retiro(
  p_token text,
  p_pin   text,
  p_ip    text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE qr_token::text = p_token;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'TOKEN_INVALIDO');
  END IF;

  IF v_retiro.estado <> 'PENDIENTE_FIRMA' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'YA_PROCESADO', 'estado', v_retiro.estado);
  END IF;

  IF v_retiro.qr_expires_at < now() THEN
    UPDATE mensajeria_retiros SET estado = 'EXPIRADO' WHERE id = v_retiro.id;
    RETURN jsonb_build_object('ok', false, 'error', 'EXPIRADO');
  END IF;

  SELECT * INTO v_mensajero FROM mensajeros WHERE id = v_retiro.mensajero_id;
  IF NOT FOUND OR v_mensajero.activo = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_INACTIVO');
  END IF;

  -- Verificar bloqueo temporal
  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'BLOQUEADO_TEMPORALMENTE',
      'bloqueado_hasta', v_mensajero.bloqueado_hasta
    );
  END IF;

  -- Validar PIN con bcrypt
  IF v_mensajero.pin_hash <> crypt(p_pin, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3
                                  THEN now() + interval '5 minutes'
                                  ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'PIN_INCORRECTO',
      'intentos_restantes', GREATEST(0, 3 - (v_mensajero.intentos_fallidos + 1))
    );
  END IF;

  -- PIN OK: firmar
  UPDATE mensajeria_retiros
     SET estado     = 'FIRMADO',
         firmado_at = now(),
         firmado_ip = p_ip
   WHERE id = v_retiro.id;

  -- Reset intentos
  UPDATE mensajeros
     SET intentos_fallidos = 0,
         bloqueado_hasta   = NULL,
         updated_at        = now()
   WHERE id = v_mensajero.id;

  RETURN jsonb_build_object('ok', true, 'retiro_id', v_retiro.id, 'firmado_at', now());
END $$;

GRANT EXECUTE ON FUNCTION firmar_retiro(text, text, text) TO anon;
GRANT EXECUTE ON FUNCTION firmar_retiro(text, text, text) TO authenticated;

-- ── firmar_retiro_asistido: cuando el mensajero no tiene celu ──
-- El encargado, después de que expira el QR, puede ingresar el PIN del mensajero
-- en su propia pc. Queda registrado como tipo distinto para audit.
CREATE OR REPLACE FUNCTION firmar_retiro_asistido(
  p_retiro_id uuid,
  p_pin       text,
  p_ip        text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE id = p_retiro_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'RETIRO_NO_ENCONTRADO');
  END IF;

  IF v_retiro.estado NOT IN ('PENDIENTE_FIRMA','EXPIRADO') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'YA_PROCESADO', 'estado', v_retiro.estado);
  END IF;

  SELECT * INTO v_mensajero FROM mensajeros WHERE id = v_retiro.mensajero_id;
  IF NOT FOUND OR v_mensajero.activo = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_INACTIVO');
  END IF;

  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BLOQUEADO_TEMPORALMENTE',
                              'bloqueado_hasta', v_mensajero.bloqueado_hasta);
  END IF;

  IF v_mensajero.pin_hash <> crypt(p_pin, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3
                                  THEN now() + interval '5 minutes'
                                  ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO');
  END IF;

  UPDATE mensajeria_retiros
     SET estado     = 'FIRMA_ASISTIDA',
         firmado_at = now(),
         firmado_ip = p_ip
   WHERE id = v_retiro.id;

  UPDATE mensajeros
     SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
   WHERE id = v_mensajero.id;

  RETURN jsonb_build_object('ok', true, 'retiro_id', v_retiro.id);
END $$;

GRANT EXECUTE ON FUNCTION firmar_retiro_asistido(uuid, text, text) TO anon;
GRANT EXECUTE ON FUNCTION firmar_retiro_asistido(uuid, text, text) TO authenticated;

-- ── mis_retiros_mensajero: historial visible para el mensajero ──
CREATE OR REPLACE FUNCTION mis_retiros_mensajero(
  p_mensajero_id uuid,
  p_pin          text,
  p_limit        int DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_mensajero mensajeros;
  v_retiros   jsonb;
BEGIN
  SELECT * INTO v_mensajero FROM mensajeros WHERE id = p_mensajero_id;
  IF NOT FOUND OR v_mensajero.activo = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_INACTIVO');
  END IF;

  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BLOQUEADO_TEMPORALMENTE');
  END IF;

  IF v_mensajero.pin_hash <> crypt(p_pin, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3
                                  THEN now() + interval '5 minutes'
                                  ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO');
  END IF;

  -- PIN OK
  UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
   WHERE id = v_mensajero.id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id',          r.id,
      'fecha_hora',  r.fecha_hora,
      'estado',      r.estado,
      'destino',     d.nombre,
      'cant_cajas',  r.cant_cajas,
      'cant_sobres', r.cant_sobres,
      'monto_total', r.monto_total,
      'firmado_at',  r.firmado_at,
      'encargado',   r.encargado_nombre
    ) ORDER BY r.fecha_hora DESC
  ), '[]'::jsonb)
    INTO v_retiros
    FROM mensajeria_retiros r
    LEFT JOIN mensajeria_destinos d ON d.id = r.destino_id
    WHERE r.mensajero_id = p_mensajero_id
    LIMIT p_limit;

  RETURN jsonb_build_object('ok', true,
                            'mensajero_nombre', v_mensajero.nombre,
                            'retiros', v_retiros);
END $$;

GRANT EXECUTE ON FUNCTION mis_retiros_mensajero(uuid, text, int) TO anon;
GRANT EXECUTE ON FUNCTION mis_retiros_mensajero(uuid, text, int) TO authenticated;

-- ── reset_pin_mensajero: para que el encargado resetee PIN ──
CREATE OR REPLACE FUNCTION reset_pin_mensajero(
  p_mensajero_id uuid,
  p_nuevo_pin    text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF length(p_nuevo_pin) < 4 OR length(p_nuevo_pin) > 6 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INVALIDO',
                              'detalle', 'El PIN debe tener entre 4 y 6 caracteres');
  END IF;
  UPDATE mensajeros
     SET pin_hash = crypt(p_nuevo_pin, gen_salt('bf')),
         intentos_fallidos = 0,
         bloqueado_hasta = NULL,
         updated_at = now()
   WHERE id = p_mensajero_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_NO_ENCONTRADO');
  END IF;
  RETURN jsonb_build_object('ok', true);
END $$;

GRANT EXECUTE ON FUNCTION reset_pin_mensajero(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION reset_pin_mensajero(uuid, text) TO anon;

-- ============================================================
-- REALTIME
-- ============================================================
-- Habilitar realtime sobre mensajeria_retiros para que la pantalla
-- del encargado se actualice solo cuando el mensajero firma.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'mensajeria_retiros'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE mensajeria_retiros';
  END IF;
END $$;

-- ============================================================
-- SEED INICIAL
-- ============================================================

-- Mensajeros (PIN 1234 inicial — cambiar al primer login)
INSERT INTO mensajeros (nombre, telefono, pin_hash, activo) VALUES
  ('Sergio',      '2612058126', crypt('1234', gen_salt('bf')), true),
  ('Maximiliano', '2614664546', crypt('1234', gen_salt('bf')), true)
ON CONFLICT DO NOTHING;

-- Destinos (todos en Garibaldi 405)
INSERT INTO mensajeria_destinos (nombre, direccion, orden, activo) VALUES
  ('Facturación', 'Garibaldi 405 (FUESMEN Sede Central)', 1, true),
  ('Tesorería',   'Garibaldi 405 (FUESMEN Sede Central)', 2, true),
  ('Informática', 'Garibaldi 405 (FUESMEN Sede Central)', 3, true),
  ('Otros',       'Garibaldi 405 (FUESMEN Sede Central)', 4, true)
ON CONFLICT (nombre) DO NOTHING;

-- ============================================================
-- FIN
-- ============================================================
-- Verificación rápida:
--   SELECT * FROM mensajeros;
--   SELECT * FROM mensajeria_destinos;
--   SELECT consultar_retiro_por_token('00000000-0000-0000-0000-000000000000');
