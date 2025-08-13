let showDetails = false;

// ================== UTIL ==================
function formatDate(dateString) {
    const d = new Date(dateString);
    return d.toLocaleString('fr-FR', { timeZone: 'Europe/Paris', hour12: false }).replace(',', '');
}
function isPrivateIP(ip) {
    if (!ip || ip === '127.0.0.1') return true;
    if (ip.startsWith('10.') || ip.startsWith('192.168.')) return true;
    if (ip.startsWith('172.')) {
        const s = parseInt(ip.split('.')[1], 10);
        if (!isNaN(s) && s >= 16 && s <= 31) return true;
    }
    return false;
}
async function reverseGeocode(lat, lon) {
    try {
        const url = `https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=${encodeURIComponent(lat)}&lon=${encodeURIComponent(lon)}&zoom=10&addressdetails=1`;
        const r = await fetch(url, { headers: { 'Accept-Language': 'fr' }, cache: 'no-store' });
        const j = await r.json();
        const a = j.address || {};
        const city = a.city || a.town || a.village || a.municipality || a.county || '';
        const country = a.country || '';
        if (city || country) return `${city}${city && country ? ', ' : ''}${country}`;
    } catch (_) {}
    return 'Inconnue';
}
async function ipGeoLabel(ip) {
    const endpoint = (!ip || isPrivateIP(ip)) ? 'https://ipapi.co/json/' : `https://ipapi.co/${ip}/json/`;
    try {
        const r = await fetch(endpoint, { cache: 'no-store' });
        const j = await r.json();
        const city = j?.city || '';
        const country = j?.country_name || '';
        if (city || country) return `${city}${city && country ? ', ' : ''}${country}`;
    } catch (_) {}
    return 'Inconnue';
}

// ================== GEO ETAT ==================
let preciseGeoLabel = null;     // "Ville, Pays" si GPS ok
let preciseGeoTried = false;    // évite de redemander côté code

async function acquirePreciseLocation() {
    if (preciseGeoTried) return preciseGeoLabel;
    preciseGeoTried = true;

    const isLocalhost = location.hostname === 'localhost' || location.hostname === '127.0.0.1';
    const isHttps = location.protocol === 'https:';
    if (!('geolocation' in navigator)) return null;
    if (!isHttps && !isLocalhost) {
        // GPS bloqué par le navigateur hors HTTPS
        return null;
    }

    try {
        const pos = await new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, {
                enableHighAccuracy: true,
                timeout: 10000,
                maximumAge: 0
            });
        });
        preciseGeoLabel = await reverseGeocode(pos.coords.latitude, pos.coords.longitude);
        return preciseGeoLabel;
    } catch (_) {
        return null; // refus / timeout → fallback IP
    }
}

async function getBestGeoLabel(ipFromLog) {
    if (preciseGeoLabel) return preciseGeoLabel;
    const gps = await acquirePreciseLocation();
    if (gps && gps !== 'Inconnue') {
        preciseGeoLabel = gps;
        return preciseGeoLabel;
    }
    return await ipGeoLabel(ipFromLog);
}

// ================== MODAL CONSENTEMENT ==================
function injectGeoModal() {
    // style
    const css = `
    .lp-modal-backdrop{position:fixed;inset:0;background:rgba(0,0,0,.45);display:flex;align-items:center;justify-content:center;z-index:9999}
    .lp-modal{background:#111827;color:#f9fafb;border-radius:16px;box-shadow:0 10px 30px rgba(0,0,0,.35);max-width:520px;width:92%;padding:22px}
    .lp-h{font-size:18px;margin:0 0 8px;font-weight:700;letter-spacing:.2px}
    .lp-p{font-size:14px;opacity:.9;margin:0 0 16px;line-height:1.45}
    .lp-row{display:flex;gap:10px;justify-content:flex-end}
    .lp-btn{border:0;border-radius:10px;padding:10px 14px;font-weight:600;cursor:pointer}
    .lp-btn.secondary{background:#374151;color:#e5e7eb}
    .lp-btn.primary{background:#10b981;color:#052e2b}
    .lp-note{font-size:12px;opacity:.7;margin-top:8px}
    `;
    const style = document.createElement('style');
    style.textContent = css;
    document.head.appendChild(style);

    // html
    const backdrop = document.createElement('div');
    backdrop.className = 'lp-modal-backdrop';
    backdrop.innerHTML = `
      <div class="lp-modal">
        <div class="lp-h">Little Pigs souhaite accéder à ta localisation</div>
        <p class="lp-p">
          On l’utilise pour afficher <b>Ville, Pays</b> dans les logs (meilleure précision).
          Tu peux refuser — dans ce cas on utilisera une estimation via ton adresse IP.
        </p>
        <div class="lp-row">
          <button class="lp-btn secondary" id="lpLater">Plus tard</button>
          <button class="lp-btn primary" id="lpAllow">Autoriser la localisation</button>
        </div>
        <div class="lp-note">Astuce : le GPS nécessite HTTPS (sauf en local).</div>
      </div>
    `;
    document.body.appendChild(backdrop);

    // actions
    const close = () => backdrop.remove();
    document.getElementById('lpLater').onclick = () => {
        // ne mémorise pas → on reproposera au prochain chargement
        close();
        fetchLogs(); // on affiche quand même avec IP
    };
    document.getElementById('lpAllow').onclick = async () => {
        localStorage.setItem('lp_geo_prompt_seen', '1'); // on a bien proposé
        const label = await acquirePreciseLocation();
        close();
        // relance l’affichage avec la position précise si dispo
        fetchLogs();
    };
}

// ================== LOGS ==================
async function fetchLogs() {
    const res = await fetch('/api/logs', { cache: 'no-store' });
    const logs = await res.json();
    const logsDiv = document.getElementById('logs');
    logsDiv.innerHTML = "";

    const lastLogDiv = document.getElementById('last-log');
    if (logs.length > 0) {
        const lastLog = logs[0];
        const dateheure = formatDate(lastLog.created_at);
        const ipTxt = lastLog.ip || "Inconnue";
        const geoTxt = await getBestGeoLabel(lastLog.ip);
        lastLogDiv.innerHTML = `<b>${ipTxt} | ${dateheure}${geoTxt && geoTxt !== 'Inconnue' ? ' | ' + geoTxt : ''}</b>`;
    } else {
        lastLogDiv.innerHTML = "-";
    }

    if (logs.length === 0) {
        logsDiv.innerHTML = "Aucun log.";
        document.getElementById('log-count').innerHTML = `<b>0</b>`;
        return;
    }

    for (let log of logs) {
        let logMsg = log.message;
        let userAgent = "";
        if (log.message.includes("| UA:")) {
            const parts = log.message.split("| UA:");
            logMsg = parts[0].trim();
            userAgent = parts[1].trim();
        }

        let line = `<div class="log-line">[${formatDate(log.created_at)}] <span class="log-level">(${log.level})</span><br>`;
        line += `<b>${logMsg}</b>`;

        if (showDetails) {
            const ipTxt = log.ip || "Inconnue";
            const geoTxt = await getBestGeoLabel(log.ip);
            line += `<br><span class="log-ip">IP: ${ipTxt}${geoTxt && geoTxt !== 'Inconnue' ? " | " + geoTxt : ""}</span>`;
        }

        if (userAgent) {
            line += `<br><span class="log-ua"><b>User Agent :</b> ${userAgent}</span>`;
        }

        line += `</div>`;
        logsDiv.innerHTML += line;
    }

    document.getElementById('log-count').innerHTML = `<b>${logs.length}</b>`;
}

// ================== ACTIONS UI ==================
async function testLog() {
    const userAgent = navigator.userAgent;
    const msg = `Test log depuis frontend | UA: ${userAgent}`;
    await fetch('/api/logs', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({message: msg, level: "INFO"})
    });
    fetchLogs();
}
async function clearLogs() {
    await fetch('/api/logs/clear', {method: 'DELETE'});
    fetchLogs();
}
function toggleDetails() {
    showDetails = !showDetails;
    fetchLogs();
}

// ================== BOOT ==================
document.addEventListener('DOMContentLoaded', async () => {
    document.getElementById('testLogBtn').onclick = testLog;
    document.getElementById('clearLogsBtn').onclick = clearLogs;
    document.getElementById('showDetailsBtn').onclick = toggleDetails;

    // Si on n’a jamais proposé (ou si l’utilisateur a cliqué “Plus tard”), on affiche le modal
    const alreadyPrompted = localStorage.getItem('lp_geo_prompt_seen') === '1';
    if (!alreadyPrompted && ('geolocation' in navigator)) {
        injectGeoModal(); // proposera le GPS, puis on actualisera l’affichage
    } else {
        // On tente quand même le GPS en silence si déjà autorisé
        acquirePreciseLocation().finally(fetchLogs);
    }
});