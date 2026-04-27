-- ============================================================
-- SPCD MENSAJERÍA — FIX v2 (2026-04-27)
-- ------------------------------------------------------------
-- 1) Apellidos: Sergio Arsani / Maximiliano Ruffo
-- 2) Columna debe_cambiar_pin para forzar cambio en primera firma
-- 3) Recrea las RPCs con search_path = public, extensions, pg_catalog
--    para arreglar el error: "function crypt(text, text) does not exist"
--    (pgcrypto vive en el schema 'extensions' en Supabase)
-- 4) Nueva RPC: cambiar_pin_y_firmar (combina cambio + firma en una llamada)
-- ============================================================

-- Asegurar pgcrypto
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ── 1. Nombres con apellido ──
UPDATE mensajeros SET nombre = 'Sergio Arsani'     WHERE LOWER(nombre) = 'sergio';
UPDATE mensajeros SET nombre = 'Maximiliano Ruffo' WHERE LOWER(nombre) = 'maximiliano';

-- ── 2. Columna debe_cambiar_pin ──
ALTER TABLE mensajeros ADD COLUMN IF NOT EXISTS debe_cambiar_pin boolean NOT NULL DEFAULT true;

-- Marcar a los existentes para que cambien el PIN en su primera firma
UPDATE mensajeros
   SET debe_cambiar_pin = true
 WHERE LOWER(nombre) IN ('sergio arsani','maximiliano ruffo','sergio','maximiliano');

-- ── 3. Recrear RPCs con search_path correcto ──

-- consultar_retiro_por_token (no usa crypt, igual lo recreamos por consistencia)
CREATE OR REPLACE FUNCTION consultar_retiro_por_token(p_token text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
  v_destino    mensajeria_destinos;
  v_sobres     jsonb;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE qr_token::text = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'TOKEN_INVALIDO'); END IF;

  SELECT * INTO v_mensajero FROM mensajeros          WHERE id = v_retiro.mensajero_id;
  SELECT * INTO v_destino   FROM mensajeria_destinos WHERE id = v_retiro.destino_id;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('numero_cajera', numero_cajera, 'monto', monto) ORDER BY orden), '[]'::jsonb)
    INTO v_sobres FROM mensajeria_sobres WHERE retiro_id = v_retiro.id;

  RETURN jsonb_build_object(
    'ok', true,
    'retiro_id', v_retiro.id,
    'fecha_hora', v_retiro.fecha_hora,
    'estado', v_retiro.estado,
    'expires_at', v_retiro.qr_expires_at,
    'expirado', (v_retiro.qr_expires_at < now()),
    'mensajero_id', v_mensajero.id,
    'mensajero_nombre', v_mensajero.nombre,
    'debe_cambiar_pin', v_mensajero.debe_cambiar_pin,
    'destino_nombre', v_destino.nombre,
    'destino_direccion', v_destino.direccion,
    'cant_cajas', v_retiro.cant_cajas,
    'cant_sobres', v_retiro.cant_sobres,
    'monto_total', v_retiro.monto_total,
    'sobres', v_sobres,
    'observaciones', v_retiro.observaciones,
    'encargado_nombre', v_retiro.encargado_nombre,
    'firmado_at', v_retiro.firmado_at
  );
END $$;
GRANT EXECUTE ON FUNCTION consultar_retiro_por_token(text) TO anon, authenticated;

-- firmar_retiro: ahora también valida debe_cambiar_pin
CREATE OR REPLACE FUNCTION firmar_retiro(
  p_token text,
  p_pin   text,
  p_ip    text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE qr_token::text = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'TOKEN_INVALIDO'); END IF;
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

  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BLOQUEADO_TEMPORALMENTE',
                              'bloqueado_hasta', v_mensajero.bloqueado_hasta);
  END IF;

  IF v_mensajero.pin_hash <> crypt(p_pin, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3
                                  THEN now() + interval '5 minutes' ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO',
                              'intentos_restantes', GREATEST(0, 3 - (v_mensajero.intentos_fallidos + 1)));
  END IF;

  -- PIN OK pero todavía es el inicial: forzar cambio antes de poder firmar
  IF v_mensajero.debe_cambiar_pin THEN
    UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'DEBE_CAMBIAR_PIN', 'mensajero_id', v_mensajero.id);
  END IF;

  -- Firmar
  UPDATE mensajeria_retiros SET estado = 'FIRMADO', firmado_at = now(), firmado_ip = p_ip
   WHERE id = v_retiro.id;
  UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
   WHERE id = v_mensajero.id;

  RETURN jsonb_build_object('ok', true, 'retiro_id', v_retiro.id, 'firmado_at', now());
END $$;
GRANT EXECUTE ON FUNCTION firmar_retiro(text, text, text) TO anon, authenticated;

-- firmar_retiro_asistido (igual que antes pero con search_path correcto)
CREATE OR REPLACE FUNCTION firmar_retiro_asistido(
  p_retiro_id uuid,
  p_pin       text,
  p_ip        text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_retiro    mensajeria_retiros;
  v_mensajero mensajeros;
BEGIN
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE id = p_retiro_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'RETIRO_NO_ENCONTRADO'); END IF;
  IF v_retiro.estado NOT IN ('PENDIENTE_FIRMA','EXPIRADO') THEN
    RETURN jsonb_build_object('ok', false, 'error', 'YA_PROCESADO', 'estado', v_retiro.estado);
  END IF;
  SELECT * INTO v_mensajero FROM mensajeros WHERE id = v_retiro.mensajero_id;
  IF NOT FOUND OR v_mensajero.activo = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_INACTIVO');
  END IF;
  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BLOQUEADO_TEMPORALMENTE');
  END IF;
  IF v_mensajero.pin_hash <> crypt(p_pin, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3 THEN now() + interval '5 minutes' ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO');
  END IF;
  IF v_mensajero.debe_cambiar_pin THEN
    UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'DEBE_CAMBIAR_PIN');
  END IF;
  UPDATE mensajeria_retiros SET estado = 'FIRMA_ASISTIDA', firmado_at = now(), firmado_ip = p_ip
   WHERE id = v_retiro.id;
  UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
   WHERE id = v_mensajero.id;
  RETURN jsonb_build_object('ok', true, 'retiro_id', v_retiro.id);
END $$;
GRANT EXECUTE ON FUNCTION firmar_retiro_asistido(uuid, text, text) TO anon, authenticated;

-- mis_retiros_mensajero (mismo, search_path correcto)
CREATE OR REPLACE FUNCTION mis_retiros_mensajero(
  p_mensajero_id uuid,
  p_pin          text,
  p_limit        int DEFAULT 50
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
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
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3 THEN now() + interval '5 minutes' ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO');
  END IF;
  UPDATE mensajeros SET intentos_fallidos = 0, bloqueado_hasta = NULL, updated_at = now()
   WHERE id = v_mensajero.id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object('id', r.id, 'fecha_hora', r.fecha_hora, 'estado', r.estado,
                       'destino', d.nombre, 'cant_cajas', r.cant_cajas,
                       'cant_sobres', r.cant_sobres, 'monto_total', r.monto_total,
                       'firmado_at', r.firmado_at, 'encargado', r.encargado_nombre)
    ORDER BY r.fecha_hora DESC
  ), '[]'::jsonb)
    INTO v_retiros
    FROM mensajeria_retiros r
    LEFT JOIN mensajeria_destinos d ON d.id = r.destino_id
   WHERE r.mensajero_id = p_mensajero_id
   LIMIT p_limit;

  RETURN jsonb_build_object('ok', true, 'mensajero_nombre', v_mensajero.nombre, 'retiros', v_retiros);
END $$;
GRANT EXECUTE ON FUNCTION mis_retiros_mensajero(uuid, text, int) TO anon, authenticated;

-- reset_pin_mensajero (admin)
CREATE OR REPLACE FUNCTION reset_pin_mensajero(
  p_mensajero_id uuid,
  p_nuevo_pin    text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
BEGIN
  IF length(p_nuevo_pin) < 4 OR length(p_nuevo_pin) > 6 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INVALIDO');
  END IF;
  UPDATE mensajeros
     SET pin_hash = crypt(p_nuevo_pin, gen_salt('bf')),
         debe_cambiar_pin = true,           -- al resetear, vuelve a forzar cambio
         intentos_fallidos = 0,
         bloqueado_hasta = NULL,
         updated_at = now()
   WHERE id = p_mensajero_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_NO_ENCONTRADO'); END IF;
  RETURN jsonb_build_object('ok', true);
END $$;
GRANT EXECUTE ON FUNCTION reset_pin_mensajero(uuid, text) TO anon, authenticated;

-- ── 4. NUEVA RPC: cambiar_pin_y_firmar (cambio + firma en un solo paso) ──
CREATE OR REPLACE FUNCTION cambiar_pin_y_firmar(
  p_token       text,
  p_pin_actual  text,
  p_pin_nuevo   text,
  p_ip          text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_retiro     mensajeria_retiros;
  v_mensajero  mensajeros;
BEGIN
  -- Validar formato del nuevo PIN
  IF length(p_pin_nuevo) < 4 OR length(p_pin_nuevo) > 6 THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_NUEVO_INVALIDO',
                              'detalle', 'El PIN debe tener entre 4 y 6 dígitos');
  END IF;
  IF p_pin_nuevo !~ '^[0-9]+$' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_NUEVO_INVALIDO',
                              'detalle', 'El PIN solo puede contener números');
  END IF;
  IF p_pin_nuevo = p_pin_actual THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_NUEVO_IGUAL_AL_ACTUAL');
  END IF;
  IF p_pin_nuevo = '1234' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_NUEVO_NO_PERMITIDO',
                              'detalle', 'No podés usar 1234. Elegí un PIN distinto.');
  END IF;

  -- Buscar retiro
  SELECT * INTO v_retiro FROM mensajeria_retiros WHERE qr_token::text = p_token;
  IF NOT FOUND THEN RETURN jsonb_build_object('ok', false, 'error', 'TOKEN_INVALIDO'); END IF;
  IF v_retiro.estado <> 'PENDIENTE_FIRMA' THEN
    RETURN jsonb_build_object('ok', false, 'error', 'YA_PROCESADO', 'estado', v_retiro.estado);
  END IF;
  IF v_retiro.qr_expires_at < now() THEN
    UPDATE mensajeria_retiros SET estado = 'EXPIRADO' WHERE id = v_retiro.id;
    RETURN jsonb_build_object('ok', false, 'error', 'EXPIRADO');
  END IF;

  -- Buscar mensajero
  SELECT * INTO v_mensajero FROM mensajeros WHERE id = v_retiro.mensajero_id;
  IF NOT FOUND OR v_mensajero.activo = false THEN
    RETURN jsonb_build_object('ok', false, 'error', 'MENSAJERO_INACTIVO');
  END IF;
  IF v_mensajero.bloqueado_hasta IS NOT NULL AND v_mensajero.bloqueado_hasta > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'BLOQUEADO_TEMPORALMENTE');
  END IF;

  -- Validar PIN actual
  IF v_mensajero.pin_hash <> crypt(p_pin_actual, v_mensajero.pin_hash) THEN
    UPDATE mensajeros
       SET intentos_fallidos = intentos_fallidos + 1,
           bloqueado_hasta = CASE WHEN intentos_fallidos + 1 >= 3 THEN now() + interval '5 minutes' ELSE NULL END,
           updated_at = now()
     WHERE id = v_mensajero.id;
    RETURN jsonb_build_object('ok', false, 'error', 'PIN_INCORRECTO');
  END IF;

  -- Cambiar PIN
  UPDATE mensajeros
     SET pin_hash = crypt(p_pin_nuevo, gen_salt('bf')),
         debe_cambiar_pin = false,
         intentos_fallidos = 0,
         bloqueado_hasta = NULL,
         updated_at = now()
   WHERE id = v_mensajero.id;

  -- Firmar el retiro
  UPDATE mensajeria_retiros
     SET estado = 'FIRMADO', firmado_at = now(), firmado_ip = p_ip
   WHERE id = v_retiro.id;

  RETURN jsonb_build_object('ok', true, 'retiro_id', v_retiro.id, 'pin_actualizado', true);
END $$;
GRANT EXECUTE ON FUNCTION cambiar_pin_y_firmar(text, text, text, text) TO anon, authenticated;

-- ── Verificar ──
SELECT id, nombre, activo, debe_cambiar_pin FROM mensajeros ORDER BY nombre;
