/* ============================================================
   SPCD — DIÁLOGOS (Fase 4 del refactor)
   ------------------------------------------------------------
   Reemplazo estilizado de confirm/alert/prompt del navegador.
   API pública:
     await spcdConfirm(msg, opts)  → true / false
     await spcdAlert(msg, opts)    → true
     await spcdPrompt(msg, defVal, opts) → string / null

   Opts: { title, okText, cancelText, type, placeholder }
   Tipos: 'confirm' (default), 'alert', 'error', 'prompt', 'success'

   Requiere: spcd-dialog.css
   Cómo incluir en un HTML:
       <link rel="stylesheet" href="spcd-dialog.css">
       <script src="spcd-dialog.js"></script>
   El HTML del overlay se inyecta automáticamente al cargar.
   ============================================================ */

const SPCD_DIALOG_ICONS = {
  confirm: '?', alert: '!', error: '\u2716', prompt: '\u270E', success: '\u2713'
};

/* ── Auto-inyector del HTML del overlay ─────────────────── */
(function _spcdInjectDialogHTML() {
  if (document.getElementById('spcd-dialog-overlay')) return;

  const inject = () => {
    if (document.getElementById('spcd-dialog-overlay')) return;
    const wrap = document.createElement('div');
    wrap.className = 'spcd-dialog-overlay';
    wrap.id = 'spcd-dialog-overlay';
    wrap.innerHTML = `
      <div class="spcd-dialog" id="spcd-dialog">
        <div class="spcd-dialog-header">
          <div class="spcd-dialog-icon" id="spcd-dialog-icon">?</div>
          <div class="spcd-dialog-title" id="spcd-dialog-title">Confirmar</div>
        </div>
        <div class="spcd-dialog-body" id="spcd-dialog-body"></div>
        <div class="spcd-dialog-footer" id="spcd-dialog-footer"></div>
      </div>
    `;
    document.body.appendChild(wrap);
  };

  if (document.body) inject();
  else document.addEventListener('DOMContentLoaded', inject);
})();

/* ── Core: muestra un diálogo y resuelve la promesa ───────── */
function _spcdShowDialog({ type='confirm', title='', body='', okText='Aceptar', cancelText='Cancelar', showCancel=true, input=null, actions=null }) {
  return new Promise(resolve => {
    const overlay = document.getElementById('spcd-dialog-overlay');
    const box     = document.getElementById('spcd-dialog');
    const icon    = document.getElementById('spcd-dialog-icon');
    const titleEl = document.getElementById('spcd-dialog-title');
    const bodyEl  = document.getElementById('spcd-dialog-body');
    const footer  = document.getElementById('spcd-dialog-footer');

    if (!overlay) {
      console.error('[spcd-dialog] overlay no encontrado; ¿cargaste spcd-dialog.js?');
      resolve(null);
      return;
    }

    box.className = 'spcd-dialog type-' + type;
    icon.textContent = SPCD_DIALOG_ICONS[type] || '?';
    titleEl.textContent = title || (
      type === 'confirm' ? 'Confirmar' :
      type === 'alert'   ? 'Atenci\u00f3n' :
      type === 'error'   ? 'Error' :
      type === 'prompt'  ? 'Ingres\u00e1 un valor' : 'Listo'
    );

    // Body + input opcional
    bodyEl.innerHTML = '';
    const msg = document.createElement('div');
    msg.textContent = body;
    bodyEl.appendChild(msg);

    let inputEl = null;
    if (input) {
      inputEl = document.createElement('input');
      inputEl.type = input.type || 'text';
      inputEl.className = 'spcd-dialog-input';
      inputEl.placeholder = input.placeholder || '';
      inputEl.value = input.defaultValue || '';
      bodyEl.appendChild(inputEl);
    }

    // Footer (botones)
    footer.innerHTML = '';
    const makeBtn = (txt, cls, handler) => {
      const b = document.createElement('button');
      b.className = 'spcd-dialog-btn ' + cls;
      b.innerHTML = txt;
      b.addEventListener('click', handler);
      return b;
    };

    const close = (value) => {
      overlay.classList.remove('active');
      document.removeEventListener('keydown', onKey);
      resolve(value);
    };

    // Modo ACCIONES CUSTOM: [{label, value, primary:true/false}]
    if (Array.isArray(actions) && actions.length > 0) {
      actions.forEach(a => {
        const cls = a.primary ? 'spcd-dialog-btn-primary' : 'spcd-dialog-btn-secondary';
        footer.appendChild(makeBtn(a.label, cls, () => close(a.value)));
      });
      var onKey = (e) => { if (e.key === 'Escape') { e.preventDefault(); close(null); } };
      document.addEventListener('keydown', onKey);
      overlay.classList.add('active');
      setTimeout(() => { const p = footer.querySelector('.spcd-dialog-btn-primary'); if (p) p.focus(); }, 50);
      return;
    }

    const onOk     = () => { if (input) close(inputEl.value); else close(true); };
    const onCancel = () => close(input ? null : false);

    if (showCancel) footer.appendChild(makeBtn(cancelText, 'spcd-dialog-btn-secondary', onCancel));
    footer.appendChild(makeBtn(okText, 'spcd-dialog-btn-primary', onOk));

    var onKey = (e) => {
      if (e.key === 'Escape') { e.preventDefault(); if (showCancel) onCancel(); else onOk(); }
      else if (e.key === 'Enter' && !e.shiftKey) {
        if (input && e.target !== inputEl) return;
        e.preventDefault();
        onOk();
      }
    };
    document.addEventListener('keydown', onKey);

    overlay.classList.add('active');
    setTimeout(() => { if (inputEl) inputEl.focus(); else footer.querySelector('.spcd-dialog-btn-primary').focus(); }, 50);
  });
}

/* ── API pública ──────────────────────────────────────────── */
function spcdConfirm(message, { title='Confirmar', okText='Aceptar', cancelText='Cancelar', type='confirm' } = {}) {
  return _spcdShowDialog({ type, title, body: message, okText, cancelText, showCancel: true });
}

function spcdAlert(message, { title, type='alert', okText='Entendido' } = {}) {
  return _spcdShowDialog({ type, title, body: message, okText, showCancel: false });
}

function spcdPrompt(message, defaultValue='', { title='Ingres\u00e1 un valor', okText='Confirmar', cancelText='Cancelar', placeholder='' } = {}) {
  return _spcdShowDialog({
    type: 'prompt', title, body: message,
    okText, cancelText, showCancel: true,
    input: { type: 'text', defaultValue, placeholder }
  });
}
