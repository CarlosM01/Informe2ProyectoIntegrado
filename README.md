# SGP-Kotoduo — Informe N.º 2: Diseño de la Solución de Software

Repositorio del **Informe N.º 2** del Proyecto Integrado (Unidad 2, INACAP). Contiene el informe y todos los artefactos que lo respaldan: diagramas, scripts de base de datos y el prototipo navegable.

**Proyecto:** SGP-Kotoduo, Sistema de Gestión y Seguimiento Productivo
**Contraparte:** Kotoduo, agencia publicitaria y taller de confección (Temuco, La Araucanía)
**Metodología:** Scrum (Sprint 0 de diseño y 4 sprints de construcción)
**Integrantes:** Integrante 1 y Integrante 2

## Estructura del repositorio

```
.
├── Informe2_Kotoduo_SGP.md      # Documento principal del informe
├── docker-compose.yml           # Levanta PostgreSQL y MongoDB con los anexos B y C
├── diagramas/                   # Anexo A: fuentes PlantUML, una carpeta por vista
│   ├── _comun/estilo.iuml       #   Estilo compartido por todas las figuras
│   ├── render.sh                #   Regenera todas las imágenes en figuras/
│   ├── 4.1-vista-general/       #   Fig. 4.1
│   ├── 4.2-vista-logica/        #   Fig. 4.2–4.7 (4+1: lógica)
│   ├── 4.3-vista-desarrollo/    #   Fig. 4.8–4.12 (4+1: desarrollo)
│   ├── 4.4-vista-procesos/      #   Fig. 4.13–4.17 (4+1: procesos)
│   ├── 4.5-vista-fisica/        #   Fig. 4.18–4.19 (4+1: física)
│   ├── 4.6-vista-escenarios/    #   Fig. 4.20–4.22 (4+1: escenarios)
│   ├── 5.2-navegacion/          #   Fig. 5.1–5.3
│   └── 6.1-modelo-datos/        #   Fig. 6.1–6.5
├── figuras/                     # Imágenes PNG renderizadas (mismas carpetas y nombres)
├── bd/                          # Anexos B y C: base de datos
│   ├── ddl_postgresql.sql       #   Esquema relacional (PostgreSQL 16+)
│   ├── consultas_ejemplo.sql    #   Datos y consultas de ejemplo
│   ├── mongo_esquemas.json      #   Validadores e índices (MongoDB 8)
│   ├── mongo_init.js            #   Script de inicialización de MongoDB
│   └── docker/mongo-init.sh     #   Ejecuta mongo_init.js al iniciar el contenedor
└── anexos/
    ├── prototipo/               # Anexo D: prototipo HTML/CSS (abrir index.html)
    └── seguridad/               # Anexo G: fragmentos de código seguro de referencia
```

## Cómo está organizado el informe

El informe se evalúa con una rúbrica. La tabla "Matriz de trazabilidad" al inicio de `Informe2_Kotoduo_SGP.md` relaciona cada criterio con su sección.

| Cap. | Contenido |
|---|---|
| 1–2 | Introducción y síntesis de la solución (línea base del Informe 1) |
| 3 | Planificación: actividades, plazos, responsables y dependencias |
| 4 | Arquitectura con el modelo 4+1 y tecnologías |
| 5 | Diseño de interfaces y prototipo |
| 6 | Modelo de datos (PostgreSQL y MongoDB) |
| 7 | Seguridad: roles, autenticación, amenazas y codificación segura |
| 8 | Plan de pruebas |
| 9–11 | Conclusiones, referencias y anexos |
| 12 | Balotario para la defensa oral |

## Cómo usar los artefactos

### Diagramas (PlantUML)

Cada archivo `diagramas/<carpeta>/fig-X.YY-*.puml` es la fuente de la Figura X.YY del informe, y su imagen está en `figuras/<carpeta>/` con el mismo nombre. Las carpetas siguen la sección del informe donde se usa la figura y, en el capítulo 4, las vistas del modelo 4+1.

- **Regenerar todas las imágenes:** `diagramas/render.sh`. Usa `plantuml` si está instalado; si no, la imagen Docker `plantuml/plantuml:1.2026.9`.
- **Vista previa en VS Code:** instalar la extensión PlantUML y pulsar `Alt+D` sobre el archivo.

Si modificas un diagrama, vuelve a ejecutar `render.sh` y revisa que el texto del informe que lo describe siga siendo correcto. Para mantenerlos legibles, cada diagrama muestra un solo tema; si crece demasiado, divídelo en una visión general y acercamientos.

### Bases de datos con Docker Compose (recomendado)

Requiere Docker con el plugin Compose. Desde la raíz del repositorio:

```bash
docker compose up -d --wait
```

En el primer arranque, con los volúmenes vacíos:

- PostgreSQL 16 crea la base `sgp_kotoduo` y ejecuta `bd/ddl_postgresql.sql`.
- MongoDB crea la base `sgp_docs` y ejecuta `bd/mongo_init.js`. Su salida queda en `docker compose logs mongo`.

Las consultas de ejemplo son opcionales:

```bash
docker compose exec postgres psql -U sgp -d sgp_kotoduo -f /bd/consultas_ejemplo.sql
```

Para abrir una consola:

- PostgreSQL: `docker compose exec postgres psql -U sgp -d sgp_kotoduo`
- MongoDB: `docker compose exec mongo mongosh sgp_docs`

Para volver al estado inicial (borra los datos y reejecuta los scripts en el próximo arranque):

```bash
docker compose down -v
```

| Variable | Valor por defecto | Uso |
|---|---|---|
| `POSTGRES_PORT` / `MONGO_PORT` | `5432` / `27017` | Puerto local, si ya hay otra base usando el puerto |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` | `sgp` / `sgp_local` | Credenciales locales de demostración |
| `MONGO_IMAGE` | `mongo:9.0` | MongoDB 8.0 no arranca en kernels Linux 6.19 o superiores ([SERVER-121912](https://jira.mongodb.org/browse/SERVER-121912)). La 9.0 tiene la misma API; en otros equipos se puede usar `MONGO_IMAGE=mongo:8` |

Los puertos se publican solo en `127.0.0.1` y las credenciales son de demostración: este compose no está pensado para un servidor.

### Base de datos estructurada (PostgreSQL 16+), sin Docker

```bash
createdb sgp_kotoduo
psql -d sgp_kotoduo -f bd/ddl_postgresql.sql
psql -d sgp_kotoduo -f bd/consultas_ejemplo.sql   # opcional: datos y consultas de ejemplo
```

El DDL crea el esquema `sgp`. Debe ejecutarse sobre una base vacía.

### Base de datos no estructurada (MongoDB 8), sin Docker

Ejecutar desde la carpeta `bd/`, porque el script lee `mongo_esquemas.json` con una ruta relativa:

```bash
cd bd
mongosh "mongodb://localhost:27017/sgp_docs" --file mongo_init.js
```

El script elimina y vuelve a crear las colecciones definidas, por lo que no debe ejecutarse sobre datos que se quieran conservar.

### Prototipo navegable

Abrir `anexos/prototipo/index.html` en el navegador. No requiere servidor ni credenciales: el login simula el acceso con un selector de rol, y todos los datos son ficticios. Para abrir una pantalla directamente como un rol, agrega `?rol=` a la URL (`OPERARIO`, `DISENADOR`, `VENDEDOR`, `ENCARGADA_PRODUCCION` o `ADMINISTRADOR`), por ejemplo `detalle-orden.html?rol=ENCARGADA_PRODUCCION`. Es solo una maqueta visual: no tiene back-end ni lógica de negocio. El informe (sección 5.3) lista las pantallas y las interacciones que debe demostrar.

## Seguridad y privacidad

**Este repositorio contiene información sensible sobre Kotoduo (empresa real).** Recomendaciones:

- **Mantener privado.** Configurar el repositorio como privado en GitHub / plataforma de hosting.
- **Acceso limitado.** Solo autores del proyecto e integrantes autorizados.
- **Publicar solo el prototipo, nunca este repositorio.** `anexos/prototipo/` no menciona a la empresa y usa datos ficticios, así que puede publicarse en GitHub Pages copiándolo a un repositorio público aparte (por ejemplo `sgp-prototipo`). Antes de publicar, confirma que siga sin nombres reales: `grep -ri kotoduo anexos/prototipo` no debe devolver resultados.
- **No subir datos reales de la contraparte:** nombres de clientes, datos productivos, cifras económicas, etc. Los ejemplos en `bd/` deben ser ficticios.
- **No subir credenciales:** claves de API, contraseñas de BD, tokens. Usar variables de entorno o `.env` (no rastreado en Git).

## Convenciones de trabajo

- **Mantener la coherencia entre artefactos.** Un cambio en el modelo de datos afecta al diagrama ER (`diagramas/6.1-modelo-datos/`), a `ddl_postgresql.sql`, al diccionario de datos del cap. 6 y, si corresponde, a los casos de prueba del cap. 8.
- **Respetar los identificadores.** El informe referencia requisitos y casos por ID (RF, HU, CU, CP, IK, P-xx). No los renumeres sin actualizar todas las referencias cruzadas.
- **No romper las rutas.** El informe cita archivos como `diagramas/…`, `bd/…` y `anexos/prototipo/…`. Si mueves o renombras alguno, actualiza la sección 11 (Anexos) y las menciones en el texto.
- **Un cambio por rama.** Trabaja en una rama propia (por ejemplo `feat/cap7-amenazas` o `fix/ddl-indices`) y abre un Pull Request para que la otra persona revise antes de fusionar a `main`.
- **Commits pequeños y descriptivos**, en español, en imperativo o en pasado de forma consistente.

## Pendientes conocidos

Campos marcados como `[Completar]` o `[Adjuntar…]` en el informe:

- Carrera, sección, sede, docente y fecha de entrega (tabla inicial).
- Enlace público del prototipo, si se publica en GitHub Pages (sección 5.3).
- Anexo F: reportes de ejecución de pruebas (Vitest, k6, ZAP, Lighthouse, Playwright).

Antes de la entrega, busca estos marcadores con `grep -n "Completar\|Adjuntar" Informe2_Kotoduo_SGP.md`.
