/* ============================================================
   SPCD — REALTIME + NOTIFICATIONS
   ------------------------------------------------------------
   Wrapper sobre Supabase Realtime + API Notification del browser.
   Permite suscribirse a cambios en tablas (INSERT/UPDATE/DELETE) y
   disparar notificaciones nativas del sistema cuando llega un evento.

   Requiere:
     - supabase-js cargado antes (CDN: @supabase/supabase-js@2)
     - spcd-supabase.js (define SUPABASE_URL y SUPABASE_KEY)
     - Que la tabla tenga REALTIME habilitado (publication supabase_realtime)

   API pública:
     await requestNotifPermission()
     showSpcdNotification(title, body, opts)
     subscribeToTable({ channel, table, event, onEvent })
     unsubscribeAll()

   Uso t\u00edpico (en enterApp() del m\u00f3dulo cuando es admin):
     await requestNotifPermissionConOnboarding();
     subscribeToTable({ channel:'pedidos-rt', table:'pedidos', onEvent: payload => { ... } });
   ============================================================ */

let _spcdSbClient      = null;
let _spcdSubscriptions = [];

function initSpcdSupabaseRT() {
  if (_spcdSbClient) return _spcdSbClient;
  if (typeof supabase === 'undefined' || !supabase.createClient) {
    console.warn('[spcd-realtime] supabase-js no est\u00e1 cargado (falta CDN)');
    return null;
  }
  if (typeof SUPABASE_URL === 'undefined' || typeof SUPABASE_KEY === 'undefined') {
    console.warn('[spcd-realtime] SUPABASE_URL/SUPABASE_KEY no disponibles (falta spcd-supabase.js)');
    return null;
  }
  _spcdSbClient = supabase.createClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false }
  });
  return _spcdSbClient;
}

/* ── Permiso de notificaciones ──────────────────────────── */
// Pide permiso directo al usuario (silencioso). Retorna true/false.
async function requestNotifPermission() {
  if (!('Notification' in window)) {
    console.warn('[spcd-realtime] Browser sin soporte de Notification');
    return false;
  }
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied')  return false;
  try {
    const res = await Notification.requestPermission();
    return res === 'granted';
  } catch(e) { return false; }
}

// Versi\u00f3n con modal amigable ANTES de pedir el permiso del navegador.
// \u00datil porque si el user niega el prompt nativo, queda denegado y no
// se puede volver a preguntar. Mejor preguntar primero "\u00bfquer\u00e9s?".
//
// Idempotente: si el usuario ya decidi\u00f3 una vez (aceptado o rechazado),
// no vuelve a mostrar el modal onboarding. Si quiere re-activar tiene
// que ir al bot\u00f3n \u{1F514} del topbar.
const _SPCD_NOTIF_ASKED_KEY = 'spcd_notif_asked';

async function requestNotifPermissionConOnboarding(contexto = '') {
  if (!('Notification' in window)) return false;
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied')  return false;

  // Si ya preguntamos antes y el user dijo no (o cerr\u00f3), no molestar m\u00e1s.
  try {
    if (localStorage.getItem(_SPCD_NOTIF_ASKED_KEY) === '1') return false;
  } catch(e) { /* sin localStorage */ }

  // Usa spcdConfirm si est\u00e1 disponible; si no, confirm nativo
  let quiere = false;
  if (typeof spcdConfirm === 'function') {
    quiere = await spcdConfirm(
      `\u00bfQuer\u00e9s recibir notificaciones cuando alguien cree un nuevo ${contexto || 'evento'}?\n\n` +
      `Van a aparecer como notificaciones del sistema (igual que WhatsApp o Instagram) mientras teng\u00e1s la p\u00e1gina abierta.`,
      { title: 'Activar notificaciones', okText: 'S\u00ed, activar', cancelText: 'No por ahora', type: 'confirm' }
    );
  } else {
    quiere = confirm('\u00bfActivar notificaciones del sistema cuando llegue un ' + (contexto || 'evento') + ' nuevo?');
  }

  // Marcar como ya preguntado (sea cual sea la respuesta) para no volver a mostrarlo.
  try { localStorage.setItem(_SPCD_NOTIF_ASKED_KEY, '1'); } catch(e) {}

  if (!quiere) return false;
  return await requestNotifPermission();
}

/* ── Mostrar notificaci\u00f3n nativa ──────────────────────── */
function showSpcdNotification(title, body, { icon = 'icon-192.png', url = null, tag = null, requireInteraction = false } = {}) {
  if (!('Notification' in window) || Notification.permission !== 'granted') return null;
  try {
    const n = new Notification(title, {
      body,
      icon,
      tag: tag || 'spcd-' + Date.now(),
      requireInteraction
    });
    if (url) {
      n.onclick = () => {
        window.focus();
        if (url !== window.location.href) window.location.href = url;
        n.close();
      };
    }
    return n;
  } catch(e) {
    console.warn('[spcd-realtime] No se pudo mostrar notif:', e);
    return null;
  }
}

/* ── Suscripci\u00f3n a cambios de tabla ───────────────────── */
function subscribeToTable({ channel, table, event = 'INSERT', onEvent }) {
  const client = initSpcdSupabaseRT();
  if (!client) return null;

  const ch = client
    .channel(channel)
    .on('postgres_changes', { event, schema: 'public', table }, payload => {
      try { onEvent(payload); } catch(e) { console.warn('[spcd-realtime] onEvent error:', e); }
    })
    .subscribe(status => {
      // status: 'SUBSCRIBED' | 'CHANNEL_ERROR' | 'TIMED_OUT' | 'CLOSED'
      if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        console.warn(`[spcd-realtime] Channel ${channel} status: ${status}. \u00bfTabla ${table} tiene Realtime habilitado?`);
      }
    });

  _spcdSubscriptions.push(ch);
  return ch;
}

/* ── Cleanup ────────────────────────────────────────────── */
function unsubscribeAll() {
  const client = _spcdSbClient;
  if (!client) return;
  _spcdSubscriptions.forEach(s => { try { client.removeChannel(s); } catch(e) {} });
  _spcdSubscriptions = [];
}
// Limpiar al cerrar la pesta\u00f1a / recargar
window.addEventListener('beforeunload', unsubscribeAll);

/* ── Herramientas de diagnóstico ────────────────────────── */
// Dispara una notificaci\u00f3n de prueba local (sin Realtime) para verificar
// que la API Notification + permiso del browser funcionan.
// Si el permiso est\u00e1 en default, lo pide autom\u00e1ticamente antes.
async function spcdTestNotif() {
  if (!('Notification' in window)) {
    return { ok:false, mensaje:'Este navegador no soporta notificaciones.' };
  }
  if (Notification.permission === 'default') {
    // Pedir permiso nativo primero
    try {
      const res = await Notification.requestPermission();
      if (res !== 'granted') {
        return { ok:false, mensaje:'Permiso no concedido. Si apretaste "Bloquear", tendr\u00e9s que ir al candado de la barra del navegador \u2192 Notificaciones \u2192 Permitir.' };
      }
    } catch(e) {
      return { ok:false, mensaje:'Error al solicitar permiso: ' + e.message };
    }
  }
  if (Notification.permission !== 'granted') {
    return { ok:false, mensaje:'Las notificaciones est\u00e1n bloqueadas. Hac\u00e9 click en el candado de la barra del navegador \u2192 Notificaciones \u2192 Permitir, y recarg\u00e1.' };
  }
  try {
    const n = new Notification('\u{1F514} SPCD \u2014 Prueba', {
      body: 'Si ves esta notificaci\u00f3n, el sistema funciona.\nAhora pod\u00e9s cerrar esta y esperar a que alguien cree un pedido.',
      icon: 'icon-192.png',
      requireInteraction: false
    });
    return { ok:true, mensaje:'Notificaci\u00f3n de prueba enviada. \u00bfLa ves en la esquina de la pantalla?' };
  } catch(e) {
    return { ok:false, mensaje:'Error al crear la notificaci\u00f3n: ' + e.message };
  }
}

// Activa el permiso de notificaciones Y re-suscribe a los canales si los perdimos.
// Pensado para usar desde el bot\u00f3n del diagn\u00f3stico cuando el permiso est\u00e1 en 'default'.
async function spcdActivarNotificaciones() {
  if (!('Notification' in window)) return { ok:false, mensaje:'Navegador sin soporte.' };
  if (Notification.permission === 'granted') return { ok:true, mensaje:'Ya est\u00e1n activadas.' };
  if (Notification.permission === 'denied') {
    return { ok:false, mensaje:'Est\u00e1n BLOQUEADAS por el navegador. Hac\u00e9 click en el candado de la barra de direcci\u00f3n \u2192 "Notificaciones" \u2192 "Permitir" \u2192 recarg\u00e1 la p\u00e1gina.' };
  }
  try {
    const res = await Notification.requestPermission();
    if (res === 'granted') {
      return { ok:true, mensaje:'\u2705 Permiso concedido. A partir de ahora te llegan las notificaciones.' };
    } else {
      return { ok:false, mensaje:'Apretaste "Bloquear" o cerraste. Si quer\u00e9s re-activar: click en candado \u2192 Notificaciones \u2192 Permitir.' };
    }
  } catch(e) {
    return { ok:false, mensaje:'Error: ' + e.message };
  }
}

// Retorna un objeto con el estado de cada pieza del sistema de notificaciones.
function spcdDiagnosticoRealtime() {
  const d = {
    browser: {
      soportaNotificaciones: ('Notification' in window),
      permisoActual: ('Notification' in window) ? Notification.permission : 'no soportado',
      plataforma: navigator.platform || '?',
      userAgent: (navigator.userAgent || '').slice(0, 80)
    },
    scripts: {
      supabaseJsCargado: (typeof supabase !== 'undefined' && !!supabase.createClient),
      spcdSupabaseConstantes: (typeof SUPABASE_URL !== 'undefined' && typeof SUPABASE_KEY !== 'undefined'),
      spcdRealtimeFunciones: (typeof subscribeToTable === 'function')
    },
    realtime: {
      clienteInicializado: !!_spcdSbClient,
      suscripcionesActivas: _spcdSubscriptions.length,
      canales: _spcdSubscriptions.map(s => (s.topic || '(sin topic)'))
    },
    usuario: {
      rol: (typeof currentUser !== 'undefined' && currentUser) ? currentUser.rol : '(sin login)',
      username: (typeof currentUser !== 'undefined' && currentUser) ? currentUser.username : '-'
    }
  };
  console.table(d.browser);
  console.table(d.scripts);
  console.table(d.realtime);
  console.table(d.usuario);
  return d;
}

// Mostrar el diagn\u00f3stico en un modal con sugerencias de arreglo.
async function spcdMostrarDiagnostico() {
  const d = spcdDiagnosticoRealtime();
  const problemas = [];

  if (!d.browser.soportaNotificaciones) problemas.push('\u274C El navegador no soporta notificaciones. Us\u00e1 Chrome/Firefox/Edge actualizado.');
  else if (d.browser.permisoActual === 'denied') problemas.push('\u274C Notificaciones BLOQUEADAS para este sitio. Ve\u00e9 al candado de la barra de direcci\u00f3n \u2192 "Notificaciones" \u2192 "Permitir" \u2192 recarg\u00e1 la p\u00e1gina.');
  else if (d.browser.permisoActual === 'default') problemas.push('\u26A0 Notificaciones sin permiso concedido a\u00fan. Cerr\u00e1 sesi\u00f3n y volv\u00e9 a entrar \u2014 aparece el modal para aceptar.');

  if (!d.scripts.supabaseJsCargado) problemas.push('\u274C supabase-js no est\u00e1 cargado. \u00bfHay red? Refresc\u00e1 con Ctrl+F5.');
  if (!d.scripts.spcdSupabaseConstantes) problemas.push('\u274C spcd-supabase.js no disponible.');
  if (!d.scripts.spcdRealtimeFunciones) problemas.push('\u274C spcd-realtime.js no cargado.');

  if (d.realtime.suscripcionesActivas === 0 && d.usuario.rol === 'admin') {
    problemas.push('\u26A0 Sos admin pero no hay suscripciones activas. Puede ser que (a) no diste permiso o (b) la tabla no tiene Realtime habilitado en Supabase. Correr:\n  ALTER PUBLICATION supabase_realtime ADD TABLE pedidos;\n  ALTER PUBLICATION supabase_realtime ADD TABLE licencias;');
  }

  if (d.usuario.rol !== 'admin') {
    problemas.push('\u2139 Sos rol "' + d.usuario.rol + '". Las notificaciones en tiempo real solo las recibe el admin. Entr\u00e1 como SPITRELLA.');
  }

  const linea = (label, value) => `\u2022 ${label}: ${value}`;
  const reporte = [
    '\u{1F4E1} DIAGN\u00d3STICO DE NOTIFICACIONES',
    '',
    'Navegador:',
    linea('Soporta notificaciones', d.browser.soportaNotificaciones ? 'S\u00ed' : 'NO'),
    linea('Permiso actual', d.browser.permisoActual),
    '',
    'Scripts:',
    linea('supabase-js', d.scripts.supabaseJsCargado ? 'OK' : 'FALTA'),
    linea('spcd-supabase', d.scripts.spcdSupabaseConstantes ? 'OK' : 'FALTA'),
    linea('spcd-realtime', d.scripts.spcdRealtimeFunciones ? 'OK' : 'FALTA'),
    '',
    'Realtime:',
    linea('Cliente', d.realtime.clienteInicializado ? 'Iniciado' : 'NO inicializado'),
    linea('Suscripciones activas', d.realtime.suscripcionesActivas),
    '',
    'Usuario:',
    linea('Rol', d.usuario.rol),
    linea('Username', d.usuario.username)
  ];
  if (problemas.length > 0) {
    reporte.push('', '\u26A0 PROBLEMAS DETECTADOS:', '', ...problemas);
  } else {
    reporte.push('', '\u2705 Todo en orden. Si a\u00fan no llegan notificaciones, verific\u00e1:');
    reporte.push('\u2022 Que la tabla tenga Realtime habilitado en Supabase');
    reporte.push('\u2022 Que el S.O. no tenga "No molestar" o Focus Mode activado');
    reporte.push('\u2022 Prob\u00e1 el bot\u00f3n "Test" para disparar una notif local');
  }

  // Acciones contextuales seg\u00fan el estado del permiso
  const actions = [];
  if (d.browser.permisoActual === 'default') {
    actions.push({ label: '\u2705 Activar notificaciones', value: 'activar', primary: true });
  } else if (d.browser.permisoActual === 'granted') {
    actions.push({ label: '\u{1F514} Test notif local', value: 'test', primary: true });
  }
  actions.push({ label: 'Cerrar', value: 'close' });

  const choice = await _spcdShowDialog({
    type: problemas.length > 0 ? 'alert' : 'success',
    title: 'Diagn\u00f3stico de notificaciones',
    body: reporte.join('\n'),
    actions
  });

  if (choice === 'test') {
    const r = await spcdTestNotif();
    await spcdAlert(r.mensaje, { type: r.ok ? 'success' : 'error', title: r.ok ? 'Prueba enviada' : 'No se pudo' });
  } else if (choice === 'activar') {
    const r = await spcdActivarNotificaciones();
    await spcdAlert(r.mensaje, { type: r.ok ? 'success' : 'error', title: r.ok ? '\u00a1Listo!' : 'Atenci\u00f3n' });
    // Si quedaron activas, disparar una notif de prueba para confirmar visualmente
    if (r.ok) {
      setTimeout(() => {
        try {
          new Notification('\u{1F389} Notificaciones activas', {
            body: 'A partir de ahora te aviso cuando alguien cree un pedido o solicitud.',
            icon: 'icon-192.png'
          });
        } catch(e) {}
      }, 500);
    }
  }
}

