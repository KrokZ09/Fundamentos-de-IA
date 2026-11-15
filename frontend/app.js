const API_URL = "http://localhost:8000";
let currentMode = "both"; // 'both' | 'prolog' | 'gemini'

const messagesEl = document.getElementById("messages");
const chatForm = document.getElementById("chat-form");
const chatInput = document.getElementById("chat-input");
const btnSend = document.getElementById("btn-send");

// Cambio de modo (Comparar Ambos / Solo Prolog / Solo Gemini)
document.querySelectorAll(".mode-btn").forEach(btn => {
    btn.addEventListener("click", () => {
        document.querySelectorAll(".mode-btn").forEach(b => b.classList.remove("active"));
        btn.classList.add("active");
        currentMode = btn.dataset.mode;
    });
});

// Clic en preguntas de prueba rápidas
document.querySelectorAll(".prompt-btn").forEach(btn => {
    btn.addEventListener("click", () => handleQuestion(btn.textContent));
});

// Envío del formulario principal
chatForm.addEventListener("submit", (e) => {
    e.preventDefault();
    const text = chatInput.value.trim();
    if (!text) return;
    handleQuestion(text);
});

async function handleQuestion(question) {
    appendUserMessage(question);
    chatInput.value = "";
    setLoading(true);

    // Crear contenedor de respuesta (1 o 2 columnas según el modo)
    const groupEl = document.createElement("div");
    groupEl.className = `response-group ${currentMode === "both" ? "dual" : ""}`;

    const enginesToRun = currentMode === "both" ? ["prolog", "gemini"] : [currentMode];

    enginesToRun.forEach(engine => {
        const card = document.createElement("div");
        card.className = `engine-card ${engine}`;
        card.dataset.engine = engine;
        card.innerHTML = `
            <div class="engine-title">
                <span>${engine === "prolog" ? "🧠 Prolog (Lógica 1er Orden)" : "🤖 Gemini (LLM)"}</span>
            </div>
            <div class="engine-body">Consultando...</div>
        `;
        groupEl.appendChild(card);
    });

    messagesEl.appendChild(groupEl);
    scrollToBottom();

    // Ejecutar peticiones en paralelo
    await Promise.allSettled(
        enginesToRun.map(async (engine) => {
            const card = groupEl.querySelector(`.engine-card.${engine}`);
            const endpoint = engine === "prolog" ? "/chat/prolog" : "/chat";
            const start = performance.now();

            try {
                const res = await fetch(`${API_URL}${endpoint}`, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ message: question })
                });

                if (!res.ok) throw new Error(`HTTP ${res.status}`);
                const data = await res.json();
                const ms = Math.round(performance.now() - start);

                renderEngineResult(card, engine, data, ms);
            } catch (err) {
                card.querySelector(".engine-body").innerHTML =
                    `<span style="color:#dc2626;">Error en <code>${endpoint}</code>: ${escapeHTML(err.message)}</span>`;
            }
        })
    );

    setLoading(false);
    scrollToBottom();
}

function renderEngineResult(card, engine, data, ms) {
    const label = engine === "prolog" ? "🧠 Prolog (Lógica 1er Orden)" : "🤖 Gemini (LLM)";
    const text = data.respuesta || data.response || data.message || JSON.stringify(data);
    const jugadores = Array.isArray(data.jugadores) ? data.jugadores : [];
    const relaciones = Array.isArray(data.relaciones) ? data.relaciones : [];

    let chipsHTML = "";
    if (jugadores.length > 0 || relaciones.length > 0) {
        chipsHTML += `<div class="chips-row">`;
        jugadores.forEach(j => {
            const nombre = typeof j === "string" ? j : (j.nombre || "");
            if (nombre) {
                chipsHTML += `<button type="button" class="chip player-link" data-player="${escapeHTML(nombre)}" title="Ver ficha de ${escapeHTML(nombre)}">🏃 ${escapeHTML(nombre)}</button>`;
            }
        });
        relaciones.forEach(r => {
            const relText = typeof r === "string" ? r : JSON.stringify(r);
            chipsHTML += `<span class="chip rel">🔗 ${escapeHTML(relText)}</span>`;
        });
        chipsHTML += `</div>`;
    }

    card.innerHTML = `
        <div class="engine-title">
            <span>${label}</span>
            <span style="font-weight:400; color:#94a3b8;">${ms} ms</span>
        </div>
        <div class="engine-body">${escapeHTML(text)}</div>
        ${chipsHTML}
    `;
}

// Delegación de eventos para consultar GET /jugador/{nombre} al hacer clic en un chip
messagesEl.addEventListener("click", (e) => {
    const playerBtn = e.target.closest(".player-link");
    if (playerBtn) {
        const name = playerBtn.dataset.player;
        document.getElementById("player-input").value = name;
        fetchPlayerInfo(name);
    }
});

// Formulario lateral de búsqueda de jugador (GET /jugador/{nombre})
document.getElementById("player-form").addEventListener("submit", (e) => {
    e.preventDefault();
    const name = document.getElementById("player-input").value.trim();
    if (name) fetchPlayerInfo(name);
});

async function fetchPlayerInfo(name) {
    const cardEl = document.getElementById("player-card");
    cardEl.classList.remove("empty");
    cardEl.innerHTML = `Buscando a <em>${escapeHTML(name)}</em>...`;

    try {
        const res = await fetch(`${API_URL}/jugador/${encodeURIComponent(name)}`);
        if (!res.ok) throw new Error("Jugador no encontrado en la base");
        const data = await res.json();

        cardEl.innerHTML = `
            <strong>${escapeHTML(data.nombre || name)}</strong>
            <div>🏟️ <b>Equipo:</b> ${escapeHTML(data.equipo || "—")}</div>
            <div>🏆 <b>Liga:</b> ${escapeHTML(data.liga || "—")}</div>
            <div>🌍 <b>País:</b> ${escapeHTML(data.pais || "—")}</div>
            <div>📍 <b>Estadio:</b> ${escapeHTML(data.estadio || "—")}</div>
        `;
    } catch (err) {
        cardEl.innerHTML = `<span style="color:#f87171;">${escapeHTML(err.message)}</span>`;
    }
}

// Modal para GET /prolog/hechos
const modalHechos = document.getElementById("modal-hechos");
const hechosOutput = document.getElementById("hechos-output");

async function loadHechos() {
    hechosOutput.textContent = "Consultando /prolog/hechos...";
    try {
        const res = await fetch(`${API_URL}/prolog/hechos`);
        const isJson = (res.headers.get("content-type") || "").includes("application/json");
        if (isJson) {
            const json = await res.json();
            hechosOutput.textContent = typeof json === "string" ? json : JSON.stringify(json, null, 2);
        } else {
            hechosOutput.textContent = await res.text();
        }
    } catch (err) {
        hechosOutput.textContent = `Error al obtener hechos: ${err.message}`;
    }
}

document.getElementById("btn-open-hechos").addEventListener("click", () => {
    modalHechos.classList.remove("hidden");
    loadHechos();
});
document.getElementById("btn-refresh-hechos").addEventListener("click", loadHechos);
document.getElementById("btn-close-hechos").addEventListener("click", () => modalHechos.classList.add("hidden"));
modalHechos.addEventListener("click", (e) => {
    if (e.target === modalHechos) modalHechos.classList.add("hidden");
});

// Utilidades
function appendUserMessage(text) {
    const div = document.createElement("div");
    div.className = "msg user";
    div.textContent = text;
    messagesEl.appendChild(div);
    scrollToBottom();
}

function setLoading(state) {
    chatInput.disabled = state;
    btnSend.disabled = state;
    if (!state) chatInput.focus();
}

function scrollToBottom() {
    messagesEl.scrollTop = messagesEl.scrollHeight;
}

function escapeHTML(str) {
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}