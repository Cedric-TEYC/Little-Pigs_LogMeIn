let showDetails = false;

// Convertit une date ISO en format français + heure de Paris
function formatDate(dateString) {
    const d = new Date(dateString);
    return d.toLocaleString('fr-FR', { 
        timeZone: 'Europe/Paris', 
        hour12: false 
    }).replace(',', '');
}

async function fetchLogs() {
    const res = await fetch('/api/logs');
    const logs = await res.json();
    const logsDiv = document.getElementById('logs');
    logsDiv.innerHTML = "";

    // Affichage du dernier log (IP / date et heure)
    const lastLogDiv = document.getElementById('last-log');
    if (logs.length > 0) {
        const lastLog = logs[0];
        const dateheure = formatDate(lastLog.created_at);
        lastLogDiv.innerHTML = `<b>${lastLog.ip || "Inconnue"} / ${dateheure}</b>`;
    } else {
        lastLogDiv.innerHTML = "-";
    }

    // Affichage principal
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

        // Détails uniquement si demandé
        if (showDetails) {
            let geo = {city: '', country_name: 'Inconnue'};
            if (
                log.ip &&
                !log.ip.startsWith('172.') && 
                !log.ip.startsWith('192.') &&
                !log.ip.startsWith('10.') &&
                log.ip !== "127.0.0.1"
            ) {
                try {
                    geo = await fetch(`https://ipapi.co/${log.ip}/json/`).then(r => r.json());
                } catch (e) {}
            }
            let geoTxt = (geo.city || geo.country_name !== "Inconnue") ? `${geo.city}${geo.city && geo.country_name ? ', ' : ''}${geo.country_name}` : 'Inconnue';
            line += `<br><span class="log-ip">IP: ${log.ip || "Inconnue"}${geoTxt ? " | " + geoTxt : ""}</span>`;
        }

        // User Agent, toujours présent mais WRAP !
        if (userAgent) {
            line += `<br><span class="log-ua"><b>User Agent :</b> ${userAgent}</span>`;
        }

        line += `</div>`;
        logsDiv.innerHTML += line;
    }

    document.getElementById('log-count').innerHTML = `<b>${logs.length}</b>`;
}

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

document.addEventListener('DOMContentLoaded', () => {
    document.getElementById('testLogBtn').onclick = testLog;
    document.getElementById('clearLogsBtn').onclick = clearLogs;
    document.getElementById('showDetailsBtn').onclick = toggleDetails;
    fetchLogs();
});
