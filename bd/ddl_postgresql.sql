-- =====================================================================
-- SGP-Kotoduo — Sistema de Gestión y Seguimiento Productivo
-- Script DDL de la base de datos estructurada (PostgreSQL 16+)
-- Anexo B del Informe N.º 2 — Secciones 6.1 a 6.3 (criterios 2.1.4.8 / 2.1.4.9)
-- Ejecutar sobre una base vacía:  psql -d sgp_kotoduo -f ddl_postgresql.sql
-- =====================================================================

BEGIN;

CREATE SCHEMA IF NOT EXISTS sgp;
SET search_path TO sgp;

-- ---------------------------------------------------------------------
-- 1. Seguridad: roles, usuarios, sesiones (Módulo M1)
-- ---------------------------------------------------------------------
CREATE TABLE rol (
    id           SMALLSERIAL  PRIMARY KEY,
    codigo       VARCHAR(30)  NOT NULL UNIQUE
                 CHECK (codigo IN ('ADMINISTRADOR','ENCARGADA_PRODUCCION',
                                   'VENDEDOR','DISENADOR','OPERARIO')),
    nombre       VARCHAR(60)  NOT NULL,
    descripcion  VARCHAR(255)
);

CREATE TABLE area (
    id           SMALLSERIAL  PRIMARY KEY,
    nombre       VARCHAR(60)  NOT NULL UNIQUE,
    descripcion  VARCHAR(255),
    activa       BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE usuario (
    id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre_usuario       VARCHAR(40)  NOT NULL,
    nombre_completo      VARCHAR(100) NOT NULL,
    correo               VARCHAR(120),
    password_hash        TEXT         NOT NULL,           -- Argon2id (formato PHC)
    debe_cambiar_clave   BOOLEAN      NOT NULL DEFAULT TRUE,
    mfa_habilitado       BOOLEAN      NOT NULL DEFAULT FALSE,
    mfa_secreto_cifrado  BYTEA,                           -- AES-256-GCM, clave fuera de la BD
    area_id              SMALLINT     REFERENCES area(id) ON UPDATE CASCADE ON DELETE SET NULL,
    activo               BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos    SMALLINT     NOT NULL DEFAULT 0 CHECK (intentos_fallidos >= 0),
    bloqueado_hasta      TIMESTAMPTZ,
    ultimo_acceso        TIMESTAMPTZ,
    creado_en            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en       TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT ck_usuario_nombre_usuario CHECK (nombre_usuario ~ '^[a-z0-9._-]{3,40}$'),
    CONSTRAINT ck_usuario_correo CHECK (correo IS NULL OR correo ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT ck_usuario_mfa CHECK (mfa_habilitado = FALSE OR mfa_secreto_cifrado IS NOT NULL)
);
CREATE UNIQUE INDEX ux_usuario_nombre_usuario ON usuario (lower(nombre_usuario));
CREATE UNIQUE INDEX ux_usuario_correo ON usuario (lower(correo)) WHERE correo IS NOT NULL;

CREATE TABLE usuario_rol (
    usuario_id    UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    rol_id        SMALLINT    NOT NULL REFERENCES rol(id)     ON DELETE RESTRICT,
    asignado_por  UUID        REFERENCES usuario(id) ON DELETE SET NULL,
    asignado_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (usuario_id, rol_id)
);

CREATE TABLE sesion_refresh (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id    UUID        NOT NULL REFERENCES usuario(id) ON DELETE CASCADE,
    familia_id    UUID        NOT NULL,                -- detección de reutilización de tokens rotados
    token_hash    CHAR(64)    NOT NULL UNIQUE,         -- SHA-256 del token opaco; nunca el token en claro
    emitido_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    expira_en     TIMESTAMPTZ NOT NULL,
    revocado_en   TIMESTAMPTZ,
    ip            INET,
    user_agent    VARCHAR(255),
    CONSTRAINT ck_sesion_expira CHECK (expira_en > emitido_en)
);
CREATE INDEX ix_sesion_usuario_activa ON sesion_refresh (usuario_id) WHERE revocado_en IS NULL;

-- ---------------------------------------------------------------------
-- 2. Plantillas de proceso (Módulo M2)
-- ---------------------------------------------------------------------
CREATE TABLE tipo_trabajo (
    id           SMALLSERIAL  PRIMARY KEY,
    nombre       VARCHAR(80)  NOT NULL UNIQUE,
    descripcion  VARCHAR(255),
    requiere_diseno BOOLEAN   NOT NULL DEFAULT TRUE,
    activo       BOOLEAN      NOT NULL DEFAULT TRUE,
    version      INTEGER      NOT NULL DEFAULT 1 CHECK (version > 0)
);

CREATE TABLE plantilla_etapa (
    id                      SERIAL       PRIMARY KEY,
    tipo_trabajo_id         SMALLINT     NOT NULL REFERENCES tipo_trabajo(id) ON DELETE CASCADE,
    secuencia               SMALLINT     NOT NULL CHECK (secuencia > 0),
    nombre                  VARCHAR(80)  NOT NULL,
    area_id                 SMALLINT     NOT NULL REFERENCES area(id) ON DELETE RESTRICT,
    instrucciones           TEXT         NOT NULL,
    duracion_estimada_horas NUMERIC(5,1) NOT NULL CHECK (duracion_estimada_horas > 0),
    es_etapa_diseno         BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_plantilla_secuencia UNIQUE (tipo_trabajo_id, secuencia)
);

CREATE TABLE insumo (
    id             SERIAL        PRIMARY KEY,
    codigo         VARCHAR(20)   NOT NULL UNIQUE,
    nombre         VARCHAR(80)   NOT NULL,
    unidad_medida  VARCHAR(10)   NOT NULL
                   CHECK (unidad_medida IN ('UNIDAD','METRO','M2','LITRO','ML','KG','PLIEGO','ROLLO')),
    stock_actual   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo   NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (stock_minimo >= 0),
    activo         BOOLEAN       NOT NULL DEFAULT TRUE,
    actualizado_en TIMESTAMPTZ   NOT NULL DEFAULT now()
);

CREATE TABLE plantilla_insumo (
    plantilla_etapa_id   INTEGER       NOT NULL REFERENCES plantilla_etapa(id) ON DELETE CASCADE,
    insumo_id            INTEGER       NOT NULL REFERENCES insumo(id)          ON DELETE RESTRICT,
    cantidad_por_unidad  NUMERIC(10,3) NOT NULL CHECK (cantidad_por_unidad > 0),
    PRIMARY KEY (plantilla_etapa_id, insumo_id)
);

-- ---------------------------------------------------------------------
-- 3. Órdenes de trabajo y etapas (Módulos M3 y M4)
-- ---------------------------------------------------------------------
CREATE TABLE orden_trabajo (
    id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo                 VARCHAR(20)  NOT NULL UNIQUE,         -- p. ej. OT-2026-0042
    tipo_trabajo_id        SMALLINT     NOT NULL REFERENCES tipo_trabajo(id) ON DELETE RESTRICT,
    titulo                 VARCHAR(120) NOT NULL,
    referencia_cliente     VARCHAR(80)  NOT NULL,                -- solo nombre de institución; sin datos de contacto (alcance)
    descripcion            TEXT,
    cantidad               INTEGER      NOT NULL CHECK (cantidad > 0),
    especificaciones       JSONB        NOT NULL DEFAULT '{}'::jsonb,  -- medidas, tallas, colores
    prioridad              VARCHAR(10)  NOT NULL DEFAULT 'NORMAL'
                           CHECK (prioridad IN ('BAJA','NORMAL','ALTA','URGENTE')),
    estado                 VARCHAR(20)  NOT NULL DEFAULT 'REGISTRADA'
                           CHECK (estado IN ('REGISTRADA','EN_DISENO','EN_PRODUCCION','DETENIDA',
                                             'TERMINADA','ENTREGADA','ANULADA')),
    fecha_compromiso       DATE         NOT NULL,
    fecha_estimada_termino DATE,
    creado_por             UUID         NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT,
    creado_en              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    actualizado_en         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    terminada_en           TIMESTAMPTZ,
    CONSTRAINT ck_ot_codigo CHECK (codigo ~ '^OT-[0-9]{4}-[0-9]{4,6}$'),
    CONSTRAINT ck_ot_especificaciones CHECK (jsonb_typeof(especificaciones) = 'object'),
    CONSTRAINT ck_ot_terminada CHECK ((estado IN ('TERMINADA','ENTREGADA')) = (terminada_en IS NOT NULL))
);
CREATE INDEX ix_ot_estado_compromiso ON orden_trabajo (estado, fecha_compromiso);

CREATE TABLE etapa_orden (
    id                      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    orden_id                UUID         NOT NULL REFERENCES orden_trabajo(id) ON DELETE CASCADE,
    plantilla_etapa_id      INTEGER      REFERENCES plantilla_etapa(id) ON DELETE SET NULL,
    secuencia               SMALLINT     NOT NULL CHECK (secuencia > 0),
    nombre                  VARCHAR(80)  NOT NULL,
    area_id                 SMALLINT     NOT NULL REFERENCES area(id) ON DELETE RESTRICT,
    instrucciones           TEXT         NOT NULL,
    responsable_id          UUID         REFERENCES usuario(id) ON DELETE SET NULL,
    estado                  VARCHAR(12)  NOT NULL DEFAULT 'PENDIENTE'
                            CHECK (estado IN ('PENDIENTE','DISPONIBLE','EN_CURSO','BLOQUEADA','TERMINADA','OMITIDA')),
    duracion_estimada_horas NUMERIC(5,1) NOT NULL CHECK (duracion_estimada_horas > 0),
    es_etapa_diseno         BOOLEAN      NOT NULL DEFAULT FALSE,
    motivo_bloqueo          VARCHAR(255),
    iniciada_en             TIMESTAMPTZ,
    terminada_en            TIMESTAMPTZ,
    version                 INTEGER      NOT NULL DEFAULT 1,      -- control de concurrencia optimista
    CONSTRAINT uq_etapa_secuencia UNIQUE (orden_id, secuencia),
    CONSTRAINT ck_etapa_bloqueo  CHECK ((estado = 'BLOQUEADA') = (motivo_bloqueo IS NOT NULL)),
    CONSTRAINT ck_etapa_fechas   CHECK (terminada_en IS NULL OR (iniciada_en IS NOT NULL AND terminada_en >= iniciada_en)),
    CONSTRAINT ck_etapa_terminada CHECK ((estado = 'TERMINADA') = (terminada_en IS NOT NULL))
);
CREATE INDEX ix_etapa_responsable_estado ON etapa_orden (responsable_id, estado);
CREATE INDEX ix_etapa_area_estado        ON etapa_orden (area_id, estado);

-- Insumos requeridos por cada etapa de una orden (derivado de plantilla_insumo × cantidad)
CREATE TABLE requerimiento_insumo (
    id                  SERIAL        PRIMARY KEY,
    etapa_orden_id      UUID          NOT NULL REFERENCES etapa_orden(id) ON DELETE CASCADE,
    insumo_id           INTEGER       NOT NULL REFERENCES insumo(id)      ON DELETE RESTRICT,
    cantidad_requerida  NUMERIC(12,2) NOT NULL CHECK (cantidad_requerida > 0),
    cantidad_consumida  NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (cantidad_consumida >= 0),
    CONSTRAINT uq_requerimiento UNIQUE (etapa_orden_id, insumo_id)
);

-- ---------------------------------------------------------------------
-- 4. Insumos: movimientos y alertas (Módulo M5)
-- ---------------------------------------------------------------------
CREATE TABLE movimiento_insumo (
    id              BIGSERIAL     PRIMARY KEY,
    insumo_id       INTEGER       NOT NULL REFERENCES insumo(id) ON DELETE RESTRICT,
    tipo            VARCHAR(10)   NOT NULL CHECK (tipo IN ('INGRESO','CONSUMO','AJUSTE')),
    cantidad        NUMERIC(12,2) NOT NULL CHECK (cantidad <> 0),
    etapa_orden_id  UUID          REFERENCES etapa_orden(id) ON DELETE SET NULL,
    usuario_id      UUID          NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT,
    comentario      VARCHAR(255),
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now(),
    CONSTRAINT ck_mov_signo CHECK (
        (tipo = 'INGRESO' AND cantidad > 0) OR
        (tipo = 'CONSUMO' AND cantidad < 0) OR
        (tipo = 'AJUSTE')),
    CONSTRAINT ck_mov_consumo_etapa CHECK (tipo <> 'CONSUMO' OR etapa_orden_id IS NOT NULL)
);
CREATE INDEX ix_mov_insumo_fecha ON movimiento_insumo (insumo_id, creado_en DESC);

CREATE TABLE alerta_insumo (
    id                SERIAL        PRIMARY KEY,
    insumo_id         INTEGER       NOT NULL REFERENCES insumo(id) ON DELETE RESTRICT,
    etapa_orden_id    UUID          REFERENCES etapa_orden(id) ON DELETE SET NULL,
    origen            VARCHAR(10)   NOT NULL CHECK (origen IN ('AUTOMATICA','MANUAL')),
    estado            VARCHAR(12)   NOT NULL DEFAULT 'ABIERTA'
                      CHECK (estado IN ('ABIERTA','EN_GESTION','CERRADA')),
    cantidad_faltante NUMERIC(12,2) CHECK (cantidad_faltante IS NULL OR cantidad_faltante > 0),
    comentario        VARCHAR(255),
    reportada_por     UUID          REFERENCES usuario(id) ON DELETE SET NULL,
    creada_en         TIMESTAMPTZ   NOT NULL DEFAULT now(),
    cerrada_por       UUID          REFERENCES usuario(id) ON DELETE SET NULL,
    cerrada_en        TIMESTAMPTZ,
    CONSTRAINT ck_alerta_manual  CHECK (origen <> 'MANUAL' OR reportada_por IS NOT NULL),
    CONSTRAINT ck_alerta_cierre  CHECK ((estado = 'CERRADA') = (cerrada_en IS NOT NULL))
);
-- Evita alertas automáticas duplicadas: a lo más una abierta por insumo
CREATE UNIQUE INDEX ux_alerta_auto_abierta ON alerta_insumo (insumo_id)
    WHERE origen = 'AUTOMATICA' AND estado <> 'CERRADA';
CREATE INDEX ix_alerta_estado ON alerta_insumo (estado, creada_en DESC);

-- ---------------------------------------------------------------------
-- 5. Aprobación de diseño (Módulo M6)
-- ---------------------------------------------------------------------
CREATE TABLE aprobacion_diseno (
    id             SERIAL       PRIMARY KEY,
    orden_id       UUID         NOT NULL REFERENCES orden_trabajo(id) ON DELETE CASCADE,
    version        SMALLINT     NOT NULL CHECK (version > 0),
    evidencia_ref  CHAR(24)     NOT NULL,          -- _id del documento en MongoDB evidencias_etapa
    estado         VARCHAR(10)  NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE','APROBADO','RECHAZADO')),
    subido_por     UUID         NOT NULL REFERENCES usuario(id) ON DELETE RESTRICT,
    subido_en      TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resuelto_por   UUID         REFERENCES usuario(id) ON DELETE RESTRICT,
    resuelto_en    TIMESTAMPTZ,
    comentario     VARCHAR(500),
    CONSTRAINT uq_aprobacion_version UNIQUE (orden_id, version),
    CONSTRAINT ck_aprobacion_resolucion CHECK (
        (estado = 'PENDIENTE') = (resuelto_por IS NULL AND resuelto_en IS NULL)),
    CONSTRAINT ck_aprobacion_segregacion CHECK (resuelto_por IS NULL OR resuelto_por <> subido_por),
    CONSTRAINT ck_aprobacion_rechazo CHECK (estado <> 'RECHAZADO' OR comentario IS NOT NULL)
);
-- A lo más una versión pendiente por orden
CREATE UNIQUE INDEX ux_aprobacion_pendiente ON aprobacion_diseno (orden_id) WHERE estado = 'PENDIENTE';

-- ---------------------------------------------------------------------
-- 6. Outbox transaccional (integración PostgreSQL -> MongoDB, Módulo M8)
-- ---------------------------------------------------------------------
CREATE TABLE outbox_evento (
    id            BIGSERIAL    PRIMARY KEY,
    tipo          VARCHAR(40)  NOT NULL,           -- p. ej. ETAPA_TERMINADA, ALERTA_INSUMO_CREADA
    agregado      VARCHAR(30)  NOT NULL,           -- entidad origen: orden_trabajo, etapa_orden, insumo...
    agregado_id   VARCHAR(40)  NOT NULL,
    actor_id      UUID         REFERENCES usuario(id) ON DELETE SET NULL,
    payload       JSONB        NOT NULL,
    creado_en     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    procesado_en  TIMESTAMPTZ,
    intentos      SMALLINT     NOT NULL DEFAULT 0 CHECK (intentos >= 0)
);
CREATE INDEX ix_outbox_pendiente ON outbox_evento (id) WHERE procesado_en IS NULL;

-- =====================================================================
-- Reglas de integridad implementadas en la base de datos
-- =====================================================================

-- R1. Mantener actualizado_en
CREATE FUNCTION fn_set_actualizado_en() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.actualizado_en := now();
    RETURN NEW;
END $$;

CREATE TRIGGER trg_usuario_actualizado  BEFORE UPDATE ON usuario
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER trg_ot_actualizado       BEFORE UPDATE ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();
CREATE TRIGGER trg_insumo_actualizado   BEFORE UPDATE ON insumo
    FOR EACH ROW EXECUTE FUNCTION fn_set_actualizado_en();

-- R2. Máquina de estados de etapa_orden (Fig. 4.7): solo transiciones permitidas.
-- EN_CURSO y BLOQUEADA solo pasan a OMITIDA cuando la OT fue anulada.
CREATE FUNCTION fn_validar_transicion_etapa() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_estado_ot VARCHAR(20);
BEGIN
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;
    SELECT estado INTO v_estado_ot FROM orden_trabajo WHERE id = NEW.orden_id;
    IF NOT (
        (OLD.estado = 'PENDIENTE'  AND NEW.estado IN ('DISPONIBLE','OMITIDA')) OR
        (OLD.estado = 'DISPONIBLE' AND NEW.estado IN ('EN_CURSO','OMITIDA'))   OR
        (OLD.estado = 'EN_CURSO'   AND NEW.estado IN ('TERMINADA','BLOQUEADA')) OR
        (OLD.estado = 'BLOQUEADA'  AND NEW.estado = 'EN_CURSO')               OR
        (OLD.estado IN ('EN_CURSO','BLOQUEADA') AND NEW.estado = 'OMITIDA'
             AND v_estado_ot = 'ANULADA')
    ) THEN
        RAISE EXCEPTION 'Transición de etapa no permitida: % -> %', OLD.estado, NEW.estado
            USING ERRCODE = 'check_violation';
    END IF;
    NEW.version := OLD.version + 1;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_etapa_transicion BEFORE UPDATE OF estado ON etapa_orden
    FOR EACH ROW EXECUTE FUNCTION fn_validar_transicion_etapa();

-- R2. Máquina de estados de orden_trabajo (Fig. 4.8). DETENIDA vuelve al subestado
-- previo (EN_DISENO o EN_PRODUCCION); la aplicación elige el destino.
CREATE FUNCTION fn_validar_transicion_orden() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.estado = OLD.estado THEN
        RETURN NEW;
    END IF;
    IF NOT (
        (OLD.estado = 'REGISTRADA'    AND NEW.estado IN ('EN_PRODUCCION','ANULADA'))               OR
        (OLD.estado = 'EN_DISENO'     AND NEW.estado IN ('EN_PRODUCCION','DETENIDA','ANULADA'))    OR
        (OLD.estado = 'EN_PRODUCCION' AND NEW.estado IN ('DETENIDA','TERMINADA','ANULADA'))        OR
        (OLD.estado = 'DETENIDA'      AND NEW.estado IN ('EN_DISENO','EN_PRODUCCION','ANULADA'))   OR
        (OLD.estado = 'TERMINADA'     AND NEW.estado = 'ENTREGADA')
    ) THEN
        RAISE EXCEPTION 'Transición de orden no permitida: % -> %', OLD.estado, NEW.estado
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_orden_transicion BEFORE UPDATE OF estado ON orden_trabajo
    FOR EACH ROW EXECUTE FUNCTION fn_validar_transicion_orden();

-- R3. Kardex: cada movimiento actualiza el stock y genera alerta automática bajo mínimo
CREATE FUNCTION fn_aplicar_movimiento_insumo() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    v_stock  NUMERIC(12,2);
    v_minimo NUMERIC(12,2);
BEGIN
    UPDATE insumo
       SET stock_actual = stock_actual + NEW.cantidad
     WHERE id = NEW.insumo_id
    RETURNING stock_actual, stock_minimo INTO v_stock, v_minimo;
    -- Si el stock queda negativo, el CHECK ck de insumo.stock_actual aborta la transacción.

    IF v_stock <= v_minimo THEN
        INSERT INTO alerta_insumo (insumo_id, etapa_orden_id, origen, cantidad_faltante)
        VALUES (NEW.insumo_id, NEW.etapa_orden_id, 'AUTOMATICA', GREATEST(v_minimo - v_stock, 0.01))
        ON CONFLICT (insumo_id) WHERE origen = 'AUTOMATICA' AND estado <> 'CERRADA'
        DO NOTHING;
    END IF;
    RETURN NEW;
END $$;

CREATE TRIGGER trg_movimiento_insumo AFTER INSERT ON movimiento_insumo
    FOR EACH ROW EXECUTE FUNCTION fn_aplicar_movimiento_insumo();

-- R4. La bitácora local (outbox) es de solo inserción para el usuario de aplicación
--     (ver GRANT al final); procesado_en lo actualiza el rol del relay.

-- =====================================================================
-- Vista para el Panel de Supervisión (Módulo M7)
-- =====================================================================
CREATE VIEW v_panel_ordenes AS
SELECT o.id,
       o.codigo,
       o.titulo,
       tt.nombre                         AS tipo_trabajo,
       o.estado,
       o.prioridad,
       o.fecha_compromiso,
       o.fecha_estimada_termino,
       ea.nombre                         AS etapa_actual,
       ar.nombre                         AS area_actual,
       u.nombre_completo                 AS responsable_actual,
       ROUND(100.0 * COUNT(*) FILTER (WHERE e.estado IN ('TERMINADA','OMITIDA'))
             / NULLIF(COUNT(e.id), 0), 0) AS porcentaje_avance,
       (o.estado NOT IN ('TERMINADA','ENTREGADA','ANULADA')
        AND COALESCE(o.fecha_estimada_termino, o.fecha_compromiso) > o.fecha_compromiso) AS en_riesgo,
       (o.estado NOT IN ('TERMINADA','ENTREGADA','ANULADA')
        AND o.fecha_compromiso < CURRENT_DATE)                   AS atrasada
  FROM orden_trabajo o
  JOIN tipo_trabajo tt ON tt.id = o.tipo_trabajo_id
  LEFT JOIN etapa_orden e ON e.orden_id = o.id
  LEFT JOIN LATERAL (
        SELECT x.nombre, x.area_id, x.responsable_id
          FROM etapa_orden x
         WHERE x.orden_id = o.id AND x.estado IN ('DISPONIBLE','EN_CURSO','BLOQUEADA')
         ORDER BY x.secuencia
         LIMIT 1) ea ON TRUE
  LEFT JOIN area ar   ON ar.id = ea.area_id
  LEFT JOIN usuario u ON u.id  = ea.responsable_id
 GROUP BY o.id, tt.nombre, ea.nombre, ar.nombre, u.nombre_completo;

-- =====================================================================
-- Privilegios mínimos (principio de menor privilegio)
-- =====================================================================
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sgp_app') THEN
        CREATE ROLE sgp_app NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'sgp_relay') THEN
        CREATE ROLE sgp_relay NOLOGIN;
    END IF;
END $$;

GRANT USAGE ON SCHEMA sgp TO sgp_app, sgp_relay;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sgp TO sgp_app;
REVOKE UPDATE, DELETE ON outbox_evento, movimiento_insumo FROM sgp_app;   -- registros inmutables
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sgp TO sgp_app;
GRANT SELECT, UPDATE (procesado_en, intentos) ON outbox_evento TO sgp_relay;

-- =====================================================================
-- Datos semilla (catálogos)
-- =====================================================================
INSERT INTO rol (codigo, nombre, descripcion) VALUES
 ('ADMINISTRADOR',        'Administrador',          'Gestiona usuarios, roles, catálogos y auditoría'),
 ('ENCARGADA_PRODUCCION', 'Encargada de Producción','Planifica, asigna y supervisa la producción'),
 ('VENDEDOR',             'Vendedor',               'Registra órdenes de trabajo y la aceptación del diseño por el cliente'),
 ('DISENADOR',            'Diseñador',              'Elabora y versiona propuestas de diseño'),
 ('OPERARIO',             'Operario',               'Ejecuta y registra el avance de sus etapas');

INSERT INTO area (nombre, descripcion) VALUES
 ('Ventas',                 'Recepción de la solicitud de trabajo'),
 ('Diseño',                 'Diseño gráfico y aprobación'),
 ('Corte',                  'Corte de telas y soportes'),
 ('Confección',             'Costura y armado de prendas'),
 ('Bordado',                'Bordado industrial'),
 ('Sublimación',            'Sublimación y estampado'),
 ('Impresión gran formato', 'Plotter, impresión UV y gran formato'),
 ('Grabado',                'Grabado láser y corte láser'),
 ('Instalación',            'Instalación de letreros en terreno'),
 ('Control y despacho',     'Control de calidad y entrega');

INSERT INTO tipo_trabajo (nombre, descripcion, requiere_diseno) VALUES
 ('Uniforme deportivo sublimado', 'Camisetas/shorts sublimados para clubes y colegios', TRUE),
 ('Letrero publicitario',         'Letrero impreso en gran formato con estructura e instalación', TRUE),
 ('Polerón de generación',        'Polerón bordado/estampado para cursos de egreso', TRUE);

INSERT INTO plantilla_etapa (tipo_trabajo_id, secuencia, nombre, area_id, instrucciones, duracion_estimada_horas, es_etapa_diseno) VALUES
 (1, 1, 'Diseño y aprobación',  2, 'Elaborar diseño según medidas y registrar aceptación del cliente.', 4.0, TRUE),
 (1, 2, 'Impresión de transfer',7, 'Imprimir diseño en papel de sublimación con perfil de color validado.', 3.0, FALSE),
 (1, 3, 'Sublimado',            6, 'Planchar a 200 °C por 45 s; revisar fijación del color.', 4.0, FALSE),
 (1, 4, 'Corte',                3, 'Cortar piezas según molde y talla.', 3.0, FALSE),
 (1, 5, 'Confección',           4, 'Unir piezas, terminaciones y etiquetado.', 8.0, FALSE),
 (1, 6, 'Control y despacho',  10, 'Revisar cantidades/tallas contra la orden y embalar.', 1.0, FALSE),
 (2, 1, 'Diseño y aprobación',  2, 'Diseñar letrero a escala; registrar aceptación del cliente.', 4.0, TRUE),
 (2, 2, 'Impresión',            7, 'Imprimir en lona/vinilo en plotter; secado mínimo 2 h.', 4.0, FALSE),
 (2, 3, 'Armado de estructura', 3, 'Cortar y armar bastidor según medidas.', 6.0, FALSE),
 (2, 4, 'Instalación',          9, 'Instalar en terreno con EPP y registrar foto final.', 4.0, FALSE);

INSERT INTO insumo (codigo, nombre, unidad_medida, stock_actual, stock_minimo) VALUES
 ('TIN-SUB-CY', 'Tinta sublimación cian',          'LITRO', 3.00, 1.00),
 ('TIN-PLT-K',  'Tinta plotter negro',             'LITRO', 2.00, 1.00),
 ('PAP-SUB-RL', 'Papel sublimación rollo 1,6 m',   'ROLLO', 4.00, 2.00),
 ('TEL-DRY-BL', 'Tela dry-fit blanca',             'METRO', 120.00, 40.00),
 ('LON-13OZ',   'Lona front 13 oz',                'M2',    60.00, 20.00);

INSERT INTO plantilla_insumo (plantilla_etapa_id, insumo_id, cantidad_por_unidad) VALUES
 (2, 1, 0.010), (2, 3, 0.020), (4, 4, 1.200), (8, 2, 0.050), (8, 5, 1.000);

COMMIT;
