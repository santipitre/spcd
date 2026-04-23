-- ============================================================
-- SP CONTROL DATA — Usuarios con acceso SOLO al módulo Personal
-- ------------------------------------------------------------
-- Rol 'licencias': acceso exclusivo a solicitudes de licencia.
-- No pueden hacer pedidos de insumos ni ver stock.
--
-- Si un username ya existe, NO se sobreescribe (ON CONFLICT DO NOTHING).
-- PIN inicial: 1234 (el sistema obliga a cambiarlo en el primer login).
--
-- Los usuarios existentes con rol 'solicitante' (TRUMBO, VFORNI,
-- ISKAMLEC, AWALKER, JAVILA) ya tienen acceso a Personal por el
-- default de rol solicitante, no necesitan cambio.
-- ============================================================

INSERT INTO usuarios (username, pin, nombre, rol, debe_cambiar_pin) VALUES
  ('CMUSRI',       crypt('1234', gen_salt('bf')), 'C. Musri',        'licencias', true),
  ('EGRANADO',     crypt('1234', gen_salt('bf')), 'E. Granado',      'licencias', true),
  ('FBATTISTELLA', crypt('1234', gen_salt('bf')), 'F. Battistella',  'licencias', true),
  ('FCORNEJO',     crypt('1234', gen_salt('bf')), 'F. Cornejo',      'licencias', true),
  ('MBENITEZ',     crypt('1234', gen_salt('bf')), 'M. Benítez',      'licencias', true),
  ('MOROZCO',      crypt('1234', gen_salt('bf')), 'M. Orozco',       'licencias', true),
  ('MCANEVA',      crypt('1234', gen_salt('bf')), 'M. Caneva',       'licencias', true),
  ('NRIOS',        crypt('1234', gen_salt('bf')), 'N. Ríos',         'licencias', true),
  ('YJOFRE',       crypt('1234', gen_salt('bf')), 'Y. Jofré',        'licencias', true),
  ('ROROMERO',     crypt('1234', gen_salt('bf')), 'R.O. Romero',     'licencias', true),
  ('ZABRAHAM',     crypt('1234', gen_salt('bf')), 'Z. Abraham',      'licencias', true),
  ('ITORRES',      crypt('1234', gen_salt('bf')), 'I. Torres',       'licencias', true),
  ('JMONICA',      crypt('1234', gen_salt('bf')), 'J. Mónica',       'licencias', true)
ON CONFLICT (username) DO NOTHING;

-- Refrescar cache de PostgREST (para que API vea los nuevos users de inmediato)
NOTIFY pgrst, 'reload schema';

-- Verificar resultado
SELECT username, nombre, rol, activo, debe_cambiar_pin
FROM usuarios
WHERE rol = 'licencias'
ORDER BY username;
