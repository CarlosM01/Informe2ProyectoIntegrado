/* SGP — Prototipo navegable (Anexo D).
   Maqueta visual: solo arma la navegación del rol simulado e inyecta los íconos.
   No hay lógica de negocio ni back-end; la autorización real es de la API (sección 7.3). */
(function () {
  'use strict';

  // Íconos SVG de trazo único (24×24, trazo 2 px)
  var ICONOS = {
    trabajo: '<rect x="3" y="7" width="18" height="13" rx="2"/><path d="M8 7V5a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2M3 13h18"/>',
    caja: '<path d="M21 8 12 3 3 8v8l9 5 9-5z"/><path d="m3 8 9 5 9-5M12 13v8"/>',
    campana: '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/>',
    lista: '<path d="M9 6h12M9 12h12M9 18h12M4 6h.01M4 12h.01M4 18h.01"/>',
    mas: '<path d="M12 5v14M5 12h14"/>',
    panel: '<rect x="3" y="3" width="7" height="9" rx="1"/><rect x="14" y="3" width="7" height="5" rx="1"/><rect x="14" y="12" width="7" height="9" rx="1"/><rect x="3" y="16" width="7" height="5" rx="1"/>',
    capas: '<path d="m12 2 9 5-9 5-9-5z"/><path d="m3 12 9 5 9-5M3 17l9 5 9-5"/>',
    usuarios: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
    bitacora: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8"/><path d="M3 3v5h5M12 7v5l4 2"/>',
    volver: '<path d="M19 12H5M12 19l-7-7 7-7"/>',
    play: '<path d="M7 4v16l13-8z"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    alerta: '<path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4M12 17h.01"/>',
    camara: '<path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3z"/><circle cx="12" cy="13" r="3"/>',
    x: '<path d="M18 6 6 18M6 6l12 12"/>',
    subir: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4M17 8l-5-5-5 5M12 3v12"/>',
    salir: '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9"/>',
    escudo: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>',
    buscar: '<circle cx="11" cy="11" r="8"/><path d="m21 21-4.3-4.3"/>',
    omitir: '<path d="m5 4 10 8-10 8zM19 5v14"/>',
    candado: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>',
    abierto: '<rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0 1 9.9-1"/>',
    arriba: '<path d="m18 15-6-6-6 6"/>',
    abajo: '<path d="m6 9 6 6 6-6"/>',
    lapiz: '<path d="M17 3a2.85 2.85 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5z"/>',
    llave: '<circle cx="7.5" cy="15.5" r="5.5"/><path d="m21 2-9.6 9.6M15.5 7.5l3 3L22 7l-3-3"/>',
    camion: '<path d="M14 18V6a2 2 0 0 0-2-2H4a2 2 0 0 0-2 2v11a1 1 0 0 0 1 1h2M15 18H9M19 18h2a1 1 0 0 0 1-1v-3.65a1 1 0 0 0-.22-.62L18.3 9.38a1 1 0 0 0-.78-.38H14"/><circle cx="17" cy="18" r="2"/><circle cx="7" cy="18" r="2"/>',
    sinred: '<path d="m2 2 20 20M8.5 16.5a5 5 0 0 1 7 0M2 8.82a15 15 0 0 1 4.17-2.65M10.66 5c4.01-.36 8.14.9 11.34 3.76M16.85 11.25a10 10 0 0 1 2.22 1.68M5 13a10 10 0 0 1 5.24-2.76M12 20h.01"/>',
    bandeja: '<path d="M22 12h-6l-2 3h-4l-2-3H2"/><path d="M5.45 5.11 2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/>',
    reintentar: '<path d="M21 12a9 9 0 1 1-3-6.7L21 8"/><path d="M21 3v5h-5"/>',
    reloj: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    circulo: '<circle cx="12" cy="12" r="9" stroke-dasharray="3 3"/>',
    disponible: '<circle cx="12" cy="12" r="9"/><path d="m10 8 6 4-6 4z"/>',
    flecha: '<path d="M5 12h14M12 5l7 7-7 7"/>',
    sube: '<path d="M12 19V5M5 12l7-7 7 7"/>'
  };

  // Rol simulado (lo fija el login del prototipo) y mapa de navegación (Fig. 5.1 a 5.3)
  var ROLES = {
    OPERARIO: { nombre: 'Pedro Soto', cargo: 'Operario', inicio: 'mi-trabajo.html' },
    DISENADOR: { nombre: 'Camila Rojas', cargo: 'Diseñadora', inicio: 'mi-trabajo.html' },
    VENDEDOR: { nombre: 'Jorge Muñoz', cargo: 'Vendedor', inicio: 'ordenes.html' },
    ENCARGADA_PRODUCCION: { nombre: 'Marcela Vidal', cargo: 'Encargada de Producción', inicio: 'panel.html' },
    ADMINISTRADOR: { nombre: 'Andrés Fuentes', cargo: 'Administrador', inicio: 'panel.html' }
  };
  var DESTINOS = {
    'mi-trabajo': ['mi-trabajo.html', 'Mi Trabajo', 'trabajo'],
    avisos: ['notificaciones.html', 'Avisos', 'campana'],
    insumos: ['insumos.html', 'Insumos', 'caja'],
    ordenes: ['ordenes.html', 'Órdenes', 'lista'],
    nueva: ['ordenes-nueva.html', 'Nueva orden', 'mas'],
    panel: ['panel.html', 'Panel', 'panel'],
    plantillas: ['plantillas.html', 'Plantillas', 'capas'],
    usuarios: ['usuarios.html', 'Usuarios', 'usuarios'],
    bitacora: ['bitacora.html', 'Bitácora', 'bitacora']
  };
  // Barra inferior con 3–4 destinos por rol; "+" = solo en la barra lateral de escritorio
  var NAV = {
    OPERARIO: ['mi-trabajo', 'avisos', 'insumos'],
    DISENADOR: ['mi-trabajo', 'avisos', 'insumos'],
    VENDEDOR: ['ordenes', 'nueva', 'avisos'],
    ENCARGADA_PRODUCCION: ['panel', 'ordenes', 'plantillas', 'insumos'],
    ADMINISTRADOR: ['panel', 'ordenes', 'usuarios', 'bitacora', '+plantillas', '+insumos']
  };

  function icono(nombre, clase) {
    return '<svg class="i ' + (clase || '') + '" aria-hidden="true"><use href="#i-' + nombre + '"/></svg>';
  }

  // 1. Sprite de íconos
  var sprite = '<svg xmlns="http://www.w3.org/2000/svg" style="display:none">';
  Object.keys(ICONOS).forEach(function (k) { sprite += '<symbol id="i-' + k + '" viewBox="0 0 24 24">' + ICONOS[k] + '</symbol>'; });
  document.body.insertAdjacentHTML('afterbegin', sprite + '</svg>');

  // ?rol=VENDEDOR permite abrir una pantalla directamente como un rol (enlaces para el docente)
  var rol = new URLSearchParams(location.search).get('rol');
  try {
    if (rol) sessionStorage.setItem('rol', rol); else rol = sessionStorage.getItem('rol');
  } catch (e) { /* sin almacenamiento: usa el rol por defecto */ }
  var d = document.body.dataset;
  var permitidos = (d.roles || '').split(' ').filter(Boolean);
  if (!ROLES[rol]) rol = permitidos[0] || 'OPERARIO';
  var persona = ROLES[rol];

  // 2. Contenido según rol: se oculta lo que el rol no ve (la API decide de verdad)
  document.querySelectorAll('[data-rol]').forEach(function (el) {
    if (el.dataset.rol.split(' ').indexOf(rol) === -1) el.hidden = true;
  });

  // 3. Íconos declarativos: <span data-i="check"></span>
  document.querySelectorAll('[data-i]').forEach(function (el) {
    el.outerHTML = icono(el.dataset.i, el.className);
  });

  if (!document.body.classList.contains('app')) return;

  // 4. Barra superior: "Volver" en niveles 2 y 3, título y acceso a /perfil
  var iniciales = persona.nombre.split(' ').map(function (p) { return p[0]; }).join('');
  var volver = d.volver === 'inicio' ? persona.inicio : d.volver;
  var izquierda = volver
    ? '<a class="volver" href="' + volver + '">' + icono('volver') + 'Volver</a>'
    : '';
  document.body.insertAdjacentHTML('afterbegin',
    '<header class="topbar"><a class="marca" href="' + persona.inicio + '">' + icono('capas') + 'SGP</a>' + izquierda +
    '<span class="titulo">' + (d.titulo || 'SGP') + '</span>' +
    '<a class="usuario" href="perfil.html" aria-label="Mi perfil: ' + persona.nombre + '">' +
    '<span class="nombre">' + persona.nombre + '<small>' + persona.cargo + '</small></span>' +
    '<span class="avatar" aria-hidden="true">' + iniciales + '</span></a></header>');

  // 5. Navegación principal del rol (barra inferior en móvil, lateral en escritorio)
  var nav = '<nav class="nav" aria-label="Principal">';
  NAV[rol].forEach(function (clave) {
    var soloEscritorio = clave.charAt(0) === '+';
    var destino = DESTINOS[clave.replace('+', '')];
    var actual = d.nav === clave.replace('+', '') ? ' aria-current="page"' : '';
    var contador = clave === 'avisos' ? '<span class="contador" aria-label="2 sin leer">2</span>' : '';
    nav += '<a href="' + destino[0] + '"' + actual + (soloEscritorio ? ' class="solo-escritorio"' : '') + '>' +
      icono(destino[2]) + destino[1] + contador + '</a>';
  });
  document.querySelector('main').insertAdjacentHTML('beforebegin', nav + '</nav>');

  // 6. Guarda de ruta simulada: el rol no tiene esta pantalla → "No tienes acceso"
  if (permitidos.length && permitidos.indexOf(rol) === -1) {
    document.querySelector('main').innerHTML =
      '<div class="estado-vacio">' + icono('candado', 'grande') +
      '<strong>No tienes acceso a esta pantalla</strong>' +
      '<p>Tu rol (' + persona.cargo + ') no incluye esta sección.</p>' +
      '<a class="btn" href="' + persona.inicio + '">Ir a mi inicio</a></div>';
  }
})();
