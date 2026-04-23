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
async function requestNotifPermissionConOnboarding(contexto = '') {
  if (!('Notification' in window)) return false;
  if (Notification.permission === 'granted') return true;
  if (Notification.permission === 'denied')  return false;

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
