-- Nuevos usuarios solicitantes (PIN default: 1234, deben cambiarlo)
INSERT INTO usuarios (username, pin, nombre, rol, debe_cambiar_pin) VALUES
  ('JAVILA',  crypt('1234', gen_salt('bf')), 'J. Ávila',   'solicitante', true),
  ('JMONICA', crypt('1234', gen_salt('bf')), 'J. Mónica',  'solicitante', true);
