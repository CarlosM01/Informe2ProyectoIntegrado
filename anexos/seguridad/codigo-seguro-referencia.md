# Anexo G — Fragmentos de código de referencia para codificación segura

**Informe N.º 2 — SGP-Kotoduo.** Borrador referencial. Este anexo complementa la sección 7.6 (Tabla 7.3).

Estos fragmentos en TypeScript muestran una forma posible de implementar los ocho patrones de codificación segura de la Tabla 7.3. Son un **borrador de diseño**: no se han compilado ni ejecutado y se ajustarán al construir los Sprints 1–2 (A12, A16, A18). La norma que se debe cumplir es el patrón descrito en 7.6 y su documentación de referencia. Si un fragmento difiere de ella, prevalece la documentación.

**(1) Consulta parametrizada con bloqueo de fila: prevención de SQLi y de condiciones de carrera** (`apps/api/src/modules/etapas/etapa.repository.ts`)

```typescript
export async function bloquearEtapaParaActualizar(tx: PoolClient, etapaId: string) {
  // $1 se envía separado del texto SQL: el valor nunca se interpreta como código.
  const { rows } = await tx.query<EtapaFila>(
    `SELECT id, orden_id, secuencia, estado, responsable_id, version
       FROM sgp.etapa_orden
      WHERE id = $1
      FOR UPDATE`,
    [etapaId],
  );
  return rows[0] ?? null;
}

export async function listarMiTrabajo(db: Pool, usuarioId: string, limite = 50) {
  // El filtro por responsable va en SQL: el operario nunca recibe filas ajenas (anti-IDOR).
  const { rows } = await db.query(
    `SELECT o.codigo, e.id, e.secuencia, e.nombre, e.estado, a.nombre AS area, e.instrucciones
       FROM sgp.etapa_orden e
       JOIN sgp.orden_trabajo o ON o.id = e.orden_id
       JOIN sgp.area a          ON a.id = e.area_id
      WHERE e.responsable_id = $1
        AND e.estado IN ('DISPONIBLE','EN_CURSO','BLOQUEADA','PENDIENTE')
      ORDER BY o.fecha_compromiso, e.secuencia
      LIMIT $2`,
    [usuarioId, Math.min(limite, 50)],
  );
  return rows;
}
```

**(2) Validación estricta de entradas con esquemas compartidos** (`packages/shared/schemas/etapas.ts` y `apps/api/src/middleware/validar.ts`)

```typescript
export const TerminarEtapaSchema = z.object({
  params: z.object({ id: z.string().uuid() }),
  body: z.object({
    version: z.number().int().positive(),
    consumos: z.array(z.object({
      insumoId: z.number().int().positive(),
      cantidad: z.number().positive().max(10_000),
    }).strict()).max(20),
  }).strict(),                                   // rechaza campos no declarados (mass assignment)
});

export const validar = (schema: z.ZodTypeAny): RequestHandler => (req, _res, next) => {
  const r = schema.safeParse({ params: req.params, body: req.body, query: req.query });
  if (!r.success) return next(new ErrorValidacion(r.error.flatten()));
  req.datos = r.data;                            // los controladores solo usan datos validados
  next();
};
```

**(3) Autorización: permiso por rol + propiedad + estado** (`apps/api/src/middleware/autorizar.ts` y `etapa.service.ts`)

```typescript
// packages/shared/permisos.ts — fuente única para la API y la PWA
export const PERMISOS_POR_ROL: Record<CodigoRol, ReadonlySet<Permiso>> = {
  OPERARIO: new Set(['ordenes.ver_asignadas', 'etapas.avanzar_propias', 'evidencias.adjuntar',
                     'insumos.ver', 'insumos.reportar_faltante']),
  // ... resto de roles según la Tabla 7.1
};

export const requierePermiso = (permiso: Permiso): RequestHandler => (req, _res, next) => {
  const ok = req.actor?.roles.some((rol) => PERMISOS_POR_ROL[rol]?.has(permiso));
  return ok ? next() : next(new ErrorProhibido());          // denegación por defecto
};

// etapa.service.ts
async terminar(etapaId: string, version: number, consumos: Consumo[], actor: Actor) {
  return this.uow.transaccion(async (tx) => {
    const etapa = await repo.bloquearEtapaParaActualizar(tx, etapaId);
    if (!etapa || etapa.responsable_id !== actor.id) throw new ErrorNoEncontrado();  // 404: no revela existencia
    if (etapa.version !== version) throw new ErrorConflicto('La etapa fue actualizada por otro usuario');
    if (!puedeTransicionar(etapa.estado, 'TERMINADA')) throw new ErrorEstadoInvalido(etapa.estado);
    // ... actualizar etapa, registrar consumos, habilitar siguiente, escribir outbox (misma tx)
  });
}
```

**(4) Hash de contraseñas y login resistente a la enumeración** (`apps/api/src/modules/auth/auth.service.ts`)

```typescript
const ARGON2_OPC = { type: argon2.argon2id, memoryCost: 19_456, timeCost: 2, parallelism: 1 };
const HASH_FICTICIO = await argon2.hash(crypto.randomUUID(), ARGON2_OPC);

export async function login(nombreUsuario: string, clave: string, ctx: Contexto) {
  const u = await usuarios.buscarPorNombre(nombreUsuario.toLowerCase());
  // Se verifica siempre un hash (real o ficticio) para igualar tiempos de respuesta.
  const valida = await argon2.verify(u?.password_hash ?? HASH_FICTICIO, clave);
  if (!u || !u.activo || !valida || u.estaBloqueado(new Date())) {
    if (u) await usuarios.registrarIntentoFallido(u.id);   // bloqueo progresivo tras 5 intentos
    await auditoria.evento('LOGIN_FALLIDO', { nombreUsuario }, ctx);
    throw new ErrorCredenciales('Usuario o contraseña incorrectos');   // mensaje genérico
  }
  await usuarios.reiniciarIntentos(u.id);
  return u.requiereMfa() ? emitirDesafioMfa(u) : emitirSesion(u, ctx);
}
```

**(5) Cookie de refresco, rotación y detección de reutilización** (`apps/api/src/modules/auth/sesion.service.ts`)

```typescript
export async function refrescar(tokenPlano: string, res: Response) {
  const hash = sha256(tokenPlano);
  const sesion = await sesiones.buscarPorHash(hash);
  if (!sesion || sesion.expira_en < new Date()) throw new ErrorNoAutenticado();
  if (sesion.revocado_en) {                       // token ya rotado reutilizado => posible robo
    await sesiones.revocarFamilia(sesion.familia_id);
    throw new ErrorNoAutenticado();
  }
  const nuevo = crypto.randomBytes(32).toString('base64url');
  await sesiones.rotar(sesion.id, sha256(nuevo));  // revoca la anterior y crea la nueva (misma familia)
  res.cookie('__Host-sgp_rt', nuevo, {
    httpOnly: true, secure: true, sameSite: 'strict', path: '/', maxAge: 12 * 3600 * 1000,
  });
  return emitirAccessToken(sesion.usuario_id);    // JWT EdDSA, 10 minutos
}
```

**(6) Cabeceras, CORS, CSRF y límites de tasa** (`apps/api/src/app.ts`)

```typescript
app.disable('x-powered-by');
app.use(helmet({
  contentSecurityPolicy: { directives: {
    defaultSrc: ["'none'"], frameAncestors: ["'none'"], baseUri: ["'none'"] } },
  hsts: { maxAge: 31_536_000, includeSubDomains: true, preload: true },
  referrerPolicy: { policy: 'no-referrer' },
}));
app.use(cors({ origin: ['https://sgp.kotoduo.cl'], credentials: true }));
app.use(express.json({ limit: '100kb' }));                        // evita cuerpos gigantes
app.use('/api/v1/auth', rateLimit({ windowMs: 60_000, limit: 10, standardHeaders: 'draft-7' }));
app.use('/api/v1', rateLimit({ windowMs: 60_000, limit: 300 }));

// CSRF: el único endpoint con cookie exige origen válido y encabezado personalizado
app.post('/api/v1/auth/refresh', verificarOrigen(['https://sgp.kotoduo.cl']),
         exigirEncabezado('X-Requested-With', 'sgp-pwa'), refrescarHandler);
```

**(7) Manejo seguro de errores** (`apps/api/src/errors/errorHandler.ts`)

```typescript
export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const requestId = req.id;                                        // también en el header X-Request-Id
  if (err instanceof ErrorAplicacion) {                            // errores esperados y tipados
    return res.status(err.status).json({ error: err.codigo, mensaje: err.mensajePublico, requestId });
  }
  if (err?.code === '23514' || err?.code === '23503') {            // CHECK / FK violados en PostgreSQL
    logger.warn({ requestId, pgCode: err.code }, 'violación de integridad');
    return res.status(409).json({ error: 'CONFLICTO', mensaje: 'La operación no es válida en el estado actual', requestId });
  }
  logger.error({ requestId, err }, 'error no controlado');         // stack solo en el log (con redacción)
  return res.status(500).json({ error: 'ERROR_INTERNO', mensaje: 'Ocurrió un error. Código: ' + requestId, requestId });
};
```

**(8) Subida segura de archivos con URL prefirmada** (`apps/api/src/modules/evidencias/evidencias.service.ts`)

```typescript
const TIPOS = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'application/pdf': 'pdf' } as const;
const MAX_BYTES = 10 * 1024 * 1024;

export async function solicitarSubida(etapaId: string, mime: string, bytes: number, actor: Actor) {
  const etapa = await etapas.verificarPropiedad(etapaId, actor);       // anti-IDOR: 404 si no es suya
  if (!(mime in TIPOS) || bytes <= 0 || bytes > MAX_BYTES) throw new ErrorValidacion('Archivo no permitido');
  const key = `evidencias/${etapa.orden_id}/${crypto.randomUUID()}.${TIPOS[mime]}`;  // nombre generado por el servidor
  const url = await getSignedUrl(r2, new PutObjectCommand({
    Bucket: 'sgp-evidencias', Key: key, ContentType: mime, ContentLength: bytes,  // firmados: no se pueden cambiar
  }), { expiresIn: 300 });
  return { url, key };
}
```
