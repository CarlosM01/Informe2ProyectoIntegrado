# SGP-Kotoduo — Informe N.º 2: Diseño de la Solución de Software

Repositorio del **Informe N.º 2** del Proyecto Integrado (Unidad 2, INACAP). Contiene el informe y todos los artefactos que lo respaldan: diagramas, scripts de base de datos y el prototipo navegable.

**Proyecto:** SGP-Kotoduo, Sistema de Gestión y Seguimiento Productivo
**Contraparte:** Kotoduo, agencia publicitaria y taller de confección (Temuco, La Araucanía)
**Metodología:** Scrum (Sprint 0 de diseño y 4 sprints de construcción)
**Integrantes:** Carlos y Javiera

## Estructura del repositorio

```
.
├── Informe2_Kotoduo_SGP.md      # Documento principal del informe
├── diagramas/                   # Anexo A: fuentes PlantUML (01 a 10)
├── bd/                          # Anexos B y C: base de datos
│   ├── ddl_postgresql.sql       #   Esquema relacional (PostgreSQL 16+)
│   ├── consultas_ejemplo.sql    #   Datos y consultas de ejemplo
│   ├── mongo_esquemas.json      #   Validadores e índices (MongoDB 8)
│   └── mongo_init.js            #   Script de inicialización de MongoDB
└── anexos/
    └── prototipo/               # Anexo D: prototipo HTML/CSS (abrir index.html)
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

Cada archivo de `diagramas/` es la fuente de una figura del informe. Para renderizarlos:

- **VS Code:** instalar la extensión PlantUML y pulsar `Alt+D` sobre el archivo.
- **Terminal:** `java -jar plantuml.jar diagramas/*.puml` genera un PNG junto a cada fuente.

Si modificas un diagrama, vuelve a generar la figura y revisa que el texto del informe que la describe siga siendo correcto.

### Base de datos estructurada (PostgreSQL 16+)

```bash
createdb sgp_kotoduo
psql -d sgp_kotoduo -f bd/ddl_postgresql.sql
psql -d sgp_kotoduo -f bd/consultas_ejemplo.sql   # opcional: datos y consultas de ejemplo
```

El DDL crea el esquema `sgp`. Debe ejecutarse sobre una base vacía.

### Base de datos no estructurada (MongoDB 8)

Ejecutar desde la carpeta `bd/`, porque el script lee `mongo_esquemas.json` con una ruta relativa:

```bash
cd bd
mongosh "mongodb://localhost:27017/sgp_docs" --file mongo_init.js
```

El script elimina y vuelve a crear las colecciones definidas, por lo que no debe ejecutarse sobre datos que se quieran conservar.

### Prototipo navegable

Abrir `anexos/prototipo/index.html` en el navegador. No requiere servidor ni credenciales: el login simula el acceso con un selector de rol, y todos los datos son ficticios. El informe (sección 5.3) lista las pantallas y las interacciones que debe demostrar.

## Seguridad y privacidad

**Este repositorio contiene información sensible sobre Kotoduo (empresa real).** Recomendaciones:

- **Mantener privado.** Configurar el repositorio como privado en GitHub / plataforma de hosting.
- **Acceso limitado.** Solo autores del proyecto e integrantes autorizados.
- **No publicar en GitHub Pages.** Aunque el prototipo sea una maqueta, mantenerlo en el repo privado o en una URL protegida.
- **No subir datos reales de la contraparte:** nombres de clientes, datos productivos, cifras económicas, etc. Los ejemplos en `bd/` deben ser ficticios.
- **No subir credenciales:** claves de API, contraseñas de BD, tokens. Usar variables de entorno o `.env` (no rastreado en Git).

## Convenciones de trabajo

- **Mantener la coherencia entre artefactos.** Un cambio en el modelo de datos afecta al diagrama ER (`09-modelo-er.puml`), a `ddl_postgresql.sql`, al diccionario de datos del cap. 6 y, si corresponde, a los casos de prueba del cap. 8.
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
