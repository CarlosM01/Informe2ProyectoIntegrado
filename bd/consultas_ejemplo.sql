-- =====================================================================
-- SGP-Kotoduo — Operaciones y consultas de ejemplo (Anexo B, sección 6.3)
-- Requiere haber ejecutado ddl_postgresql.sql
-- =====================================================================
SET search_path TO sgp;

-- 1) Usuarios de ejemplo (hash ficticio; en producción lo genera Argon2id en la API)
INSERT INTO usuario (id, nombre_usuario, nombre_completo, password_hash, debe_cambiar_clave) VALUES
 ('00000000-0000-0000-0000-000000000001', 'encargada.prod', 'Encargada de Producción (demo)', '$argon2id$v=19$m=19456,t=2,p=1$demo$demo', FALSE),
 ('00000000-0000-0000-0000-000000000002', 'operario.sub',   'Operario Sublimación (demo)',    '$argon2id$v=19$m=19456,t=2,p=1$demo$demo', FALSE),
 ('00000000-0000-0000-0000-000000000003', 'vendedor.demo',  'Vendedor (demo)',                '$argon2id$v=19$m=19456,t=2,p=1$demo$demo', FALSE);

INSERT INTO usuario_rol (usuario_id, rol_id)
SELECT '00000000-0000-0000-0000-000000000001'::uuid, id FROM rol WHERE codigo = 'ENCARGADA_PRODUCCION' UNION ALL
SELECT '00000000-0000-0000-0000-000000000002'::uuid, id FROM rol WHERE codigo = 'OPERARIO' UNION ALL
SELECT '00000000-0000-0000-0000-000000000003'::uuid, id FROM rol WHERE codigo = 'VENDEDOR';

-- 2) Registro de una orden de trabajo y generación de etapas desde la plantilla (CU-04)
BEGIN;
INSERT INTO orden_trabajo (id, codigo, tipo_trabajo_id, titulo, referencia_cliente, cantidad,
                           especificaciones, fecha_compromiso, creado_por)
VALUES ('10000000-0000-0000-0000-000000000001', 'OT-2026-0001', 1,
        'Camisetas sublimadas Club Deportivo', 'Club Deportivo Temuco', 30,
        '{"tallas": {"S": 5, "M": 15, "L": 10}, "colores": ["azul", "blanco"]}',
        CURRENT_DATE + 10, '00000000-0000-0000-0000-000000000003');

INSERT INTO etapa_orden (orden_id, plantilla_etapa_id, secuencia, nombre, area_id, instrucciones,
                         duracion_estimada_horas, es_etapa_diseno, estado)
SELECT '10000000-0000-0000-0000-000000000001', pe.id, pe.secuencia, pe.nombre, pe.area_id,
       pe.instrucciones, pe.duracion_estimada_horas, pe.es_etapa_diseno,
       CASE WHEN pe.secuencia = 1 THEN 'DISPONIBLE' ELSE 'PENDIENTE' END
  FROM plantilla_etapa pe
 WHERE pe.tipo_trabajo_id = 1;

INSERT INTO requerimiento_insumo (etapa_orden_id, insumo_id, cantidad_requerida)
SELECT e.id, pi.insumo_id, pi.cantidad_por_unidad * o.cantidad
  FROM etapa_orden e
  JOIN orden_trabajo o     ON o.id = e.orden_id
  JOIN plantilla_insumo pi ON pi.plantilla_etapa_id = e.plantilla_etapa_id
 WHERE e.orden_id = '10000000-0000-0000-0000-000000000001';

INSERT INTO outbox_evento (tipo, agregado, agregado_id, actor_id, payload)
VALUES ('ORDEN_REGISTRADA', 'orden_trabajo', '10000000-0000-0000-0000-000000000001',
        '00000000-0000-0000-0000-000000000003', '{"codigo": "OT-2026-0001"}');
COMMIT;

-- 3) Consulta "Mi Trabajo" del operario (CU-05) — parametrizada en la API con $1 = usuario_id
UPDATE etapa_orden SET responsable_id = '00000000-0000-0000-0000-000000000002'
 WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia IN (2, 3);

SELECT o.codigo, e.secuencia, e.nombre, e.estado, a.nombre AS area, e.instrucciones
  FROM etapa_orden e
  JOIN orden_trabajo o ON o.id = e.orden_id
  JOIN area a          ON a.id = e.area_id
 WHERE e.responsable_id = '00000000-0000-0000-0000-000000000002'
   AND e.estado IN ('PENDIENTE','DISPONIBLE','EN_CURSO','BLOQUEADA')
 ORDER BY o.fecha_compromiso, e.secuencia;

-- 4) Avance de etapa con bloqueo de fila (CU-06): terminar etapa 1 y habilitar la siguiente
BEGIN;
SELECT id, estado, version FROM etapa_orden
 WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia = 1
   FOR UPDATE;
UPDATE etapa_orden SET estado = 'EN_CURSO', iniciada_en = now()
 WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia = 1;
UPDATE etapa_orden SET estado = 'TERMINADA', terminada_en = now()
 WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia = 1;
UPDATE etapa_orden SET estado = 'DISPONIBLE'
 WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia = 2;
UPDATE orden_trabajo SET estado = 'EN_PRODUCCION'
 WHERE id = '10000000-0000-0000-0000-000000000001';
COMMIT;

-- 5) Regla R2: una transición inválida es rechazada por la base de datos
DO $$
BEGIN
    UPDATE sgp.etapa_orden SET estado = 'TERMINADA', iniciada_en = now(), terminada_en = now()
     WHERE orden_id = '10000000-0000-0000-0000-000000000001' AND secuencia = 4;  -- PENDIENTE -> TERMINADA
    RAISE NOTICE 'ERROR: la transición inválida fue aceptada';
EXCEPTION WHEN check_violation THEN
    RAISE NOTICE 'OK: transición inválida rechazada (%)', SQLERRM;
END $$;

-- 6) Regla R3: consumo de insumo que deja el stock bajo el mínimo genera UNA alerta automática
INSERT INTO movimiento_insumo (insumo_id, tipo, cantidad, etapa_orden_id, usuario_id)
SELECT 3, 'CONSUMO', -2.50, e.id, '00000000-0000-0000-0000-000000000002'
  FROM etapa_orden e WHERE e.orden_id = '10000000-0000-0000-0000-000000000001' AND e.secuencia = 2;
INSERT INTO movimiento_insumo (insumo_id, tipo, cantidad, etapa_orden_id, usuario_id)
SELECT 3, 'CONSUMO', -0.50, e.id, '00000000-0000-0000-0000-000000000002'
  FROM etapa_orden e WHERE e.orden_id = '10000000-0000-0000-0000-000000000001' AND e.secuencia = 2;

SELECT i.codigo, i.stock_actual, i.stock_minimo,
       (SELECT count(*) FROM alerta_insumo a
         WHERE a.insumo_id = i.id AND a.origen = 'AUTOMATICA' AND a.estado <> 'CERRADA') AS alertas_abiertas
  FROM insumo i WHERE i.id = 3;

-- 7) Integridad referencial: no se puede eliminar un insumo con movimientos (ON DELETE RESTRICT)
DO $$
BEGIN
    DELETE FROM sgp.insumo WHERE id = 3;
    RAISE NOTICE 'ERROR: se eliminó un insumo referenciado';
EXCEPTION WHEN foreign_key_violation THEN
    RAISE NOTICE 'OK: eliminación bloqueada por integridad referencial';
END $$;

-- 8) Panel de supervisión (CU-10)
SELECT codigo, tipo_trabajo, estado, etapa_actual, area_actual, responsable_actual,
       porcentaje_avance, atrasada
  FROM v_panel_ordenes;

-- 9) Faltantes previstos: requerimiento pendiente de órdenes activas vs. stock disponible
SELECT i.codigo, i.nombre, i.stock_actual,
       SUM(r.cantidad_requerida - r.cantidad_consumida) AS requerido_pendiente,
       i.stock_actual - SUM(r.cantidad_requerida - r.cantidad_consumida) AS saldo_proyectado
  FROM requerimiento_insumo r
  JOIN etapa_orden e   ON e.id = r.etapa_orden_id
  JOIN orden_trabajo o ON o.id = e.orden_id
  JOIN insumo i        ON i.id = r.insumo_id
 WHERE o.estado NOT IN ('TERMINADA','ENTREGADA','ANULADA')
   AND e.estado <> 'TERMINADA'
 GROUP BY i.id
HAVING i.stock_actual - SUM(r.cantidad_requerida - r.cantidad_consumida) < i.stock_minimo
 ORDER BY saldo_proyectado;
