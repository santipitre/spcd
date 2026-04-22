-- Fix BARBIJO KN 95: viene por caja de 20 unidades

UPDATE productos
SET factor_caja = 20,
    nombre_caja = 'Caja x20'
WHERE UPPER(nombre) LIKE '%BARBIJO KN 95%';

-- Verificación
SELECT nombre, factor_caja, nombre_caja, unidad_base
FROM productos
WHERE UPPER(nombre) LIKE '%BARBIJO KN 95%';
