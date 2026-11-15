"""
Chatbot de fútbol - Backend
Flujo: pregunta -> Prolog (api.pl) responde con hechos.pl y reglas.pl
       -> si Prolog no reconoce a ningún jugador, se usa Gemini como respaldo:
          Gemini extrae jugadores/intención -> Gemini da datos del jugador
          -> reglas de relación en Python -> Gemini redacta la respuesta.

Ejecutar:  uvicorn main:app --reload
Docs:      http://localhost:8000/docs
"""
import json
import os
import re
import subprocess
from itertools import combinations
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from openai import APIError, OpenAI, RateLimitError
from pydantic import BaseModel

load_dotenv()

# Gemini se usa a través de su endpoint compatible con el SDK de OpenAI
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    raise RuntimeError("Falta GEMINI_API_KEY. Créala en .env (mira .env.example).")

client = OpenAI(
    api_key=GEMINI_API_KEY,
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    timeout=20,
    max_retries=0,
)
MODEL = os.getenv("GEMINI_MODEL", "gemini-flash-latest")

app = FastAPI(title="Chatbot de fútbol")
app.add_middleware(  # en producción limita allow_origins a tu dominio
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


# ---------- Manejo de errores del proveedor ----------
@app.exception_handler(RateLimitError)
async def rate_limit_handler(request, exc):
    return JSONResponse(
        status_code=429,
        content={"detail": "Límite del plan gratuito de Gemini alcanzado. Espera un momento."},
    )


@app.exception_handler(APIError)
async def api_error_handler(request, exc):
    print("ERROR GEMINI:", type(exc).__name__, exc)
    return JSONResponse(
        status_code=502,
        content={"detail": "Error al consultar Gemini. Revisa tu API key y el modelo."},
    )


# ---------- Modelos ----------
class ChatIn(BaseModel):
    message: str


class ChatOut(BaseModel):
    answer: str
    players: list[dict] = []
    relations: list[dict] = []


# ---------- Capa Gemini ----------
def llm_json(system: str, user: str) -> dict:
    """Llama a Gemini y obliga a devolver JSON válido."""
    r = client.chat.completions.create(
        model=MODEL,
        temperature=0,
        response_format={"type": "json_object"},
        messages=[
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    )
    text = (r.choices[0].message.content or "").strip()
    text = re.sub(r"^```(?:json)?|```$", "", text, flags=re.MULTILINE).strip()  # quita ```json
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        raise HTTPException(502, "El modelo no devolvió un JSON válido. Intenta de nuevo.")


EXTRACT_PROMPT = """Analiza la pregunta de fútbol y devuelve JSON:
{"tipo": "info" | "relacion" | "otro", "jugadores": ["Nombre Apellido", ...]}
- "info": pregunta dónde juega / país / estadio de un jugador.
- "relacion": compara dos o más jugadores (mismo equipo, país, liga).
- "otro": no trata de jugadores de fútbol.
Usa nombres completos y conocidos."""

FACTS_PROMPT = """Eres una base de datos de fútbol. Para el jugador pedido devuelve JSON:
{"nombre": str, "equipo": str|null, "liga": str|null, "pais_club": str|null,
 "estadio": str|null, "nacionalidad": str|null, "confianza": "alta"|"media"|"baja"}
Si no estás seguro de un dato, pon null y baja la confianza. No inventes.
Tus datos pueden estar desactualizados (fichajes recientes)."""

ANSWER_PROMPT = """Eres un asistente de fútbol amable. Responde en el idioma del usuario
usando SOLO los datos JSON entregados. Si algún dato es null o la confianza es
"baja", dilo y avisa que puede estar desactualizado. Sé breve."""

_cache: dict[str, dict] = {}  # evita repetir llamadas por el mismo jugador


def get_player_facts(nombre: str) -> dict:
    key = nombre.strip().lower()
    if key not in _cache:
        _cache[key] = llm_json(FACTS_PROMPT, f"Jugador: {nombre}")
    return _cache[key]


# ---------- Puente con Prolog ----------
API_PL = Path(__file__).parent / "prolog" / "api.pl"


def preguntar_a_prolog(pregunta: str) -> dict:
    """Ejecuta api.pl con la pregunta por stdin y devuelve su JSON."""
    try:
        r = subprocess.run(
            ["swipl", "-q", "-s", str(API_PL), "-g", "main_api", "-t", "halt"],
            input=pregunta, capture_output=True, text=True,
            encoding="utf-8", timeout=10,
        )
    except FileNotFoundError:
        raise HTTPException(500, "No se encontró 'swipl'. Instala SWI-Prolog y agrégalo al PATH.")
    except subprocess.TimeoutExpired:
        raise HTTPException(504, "Prolog tardó demasiado en responder.")
    if r.returncode != 0:
        raise HTTPException(502, f"Error en Prolog: {r.stderr.strip()}")
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        raise HTTPException(502, f"Prolog devolvió una salida no válida: {r.stdout[:200]}")


# ---------- Reglas de relación en Python (solo las usa el respaldo con Gemini) ----------
def _same(a, b) -> bool:
    return a is not None and b is not None and a.lower() == b.lower()


def relacion(a: dict, b: dict) -> dict:
    return {
        "jugadores": [a["nombre"], b["nombre"]],
        "mismo_equipo": _same(a.get("equipo"), b.get("equipo")),
        "misma_liga": _same(a.get("liga"), b.get("liga")),
        "mismo_pais_club": _same(a.get("pais_club"), b.get("pais_club")),
        "misma_nacionalidad": _same(a.get("nacionalidad"), b.get("nacionalidad")),
    }


def to_prolog(facts: list[dict]) -> str:
    """Exporta hechos listos para cargar en Prolog."""
    q = lambda v: "'" + str(v).replace("'", "\\'").lower() + "'" if v else "none"
    return "\n".join(
        f"jugador({q(f['nombre'])}, {q(f.get('equipo'))}, {q(f.get('liga'))}, "
        f"{q(f.get('pais_club'))}, {q(f.get('estadio'))}, {q(f.get('nacionalidad'))})."
        for f in facts
    )


# ---------- Endpoints ----------
@app.post("/chat-gemini", response_model=ChatOut)
def chat_gemini(body: ChatIn):
    """Flujo solo con Gemini (también es el respaldo de /chat)."""
    if not body.message.strip():
        raise HTTPException(400, "Mensaje vacío")

    intent = llm_json(EXTRACT_PROMPT, body.message)
    nombres = intent.get("jugadores", [])

    if intent.get("tipo") == "otro" or not nombres:
        return ChatOut(
            answer="Soy un bot de fútbol. Pregúntame dónde juega un jugador "
            "o qué relación tienen dos jugadores."
        )

    players = [get_player_facts(n) for n in nombres]
    relations = (
        [relacion(a, b) for a, b in combinations(players, 2)]
        if intent["tipo"] == "relacion" and len(players) > 1
        else []
    )

    r = client.chat.completions.create(
        model=MODEL,
        messages=[
            {"role": "system", "content": ANSWER_PROMPT},
            {
                "role": "user",
                "content": f"Pregunta: {body.message}\n"
                f"Datos: {json.dumps({'jugadores': players, 'relaciones': relations}, ensure_ascii=False)}",
            },
        ],
    )
    return ChatOut(answer=r.choices[0].message.content, players=players, relations=relations)


@app.post("/chat", response_model=ChatOut)
def chat(body: ChatIn):
    """Prolog responde primero; si no reconoce a ningún jugador, usa Gemini."""
    if not body.message.strip():
        raise HTTPException(400, "Mensaje vacío")

    resultado = preguntar_a_prolog(body.message)
    # Depende del mensaje del caso (f) de chatbot.pl: si lo cambias allá, cámbialo aquí.
    if "No reconozco" in resultado.get("answer", ""):
        return chat_gemini(body)
    return ChatOut(**resultado)


@app.get("/jugador/{nombre}")
def jugador(nombre: str):
    return get_player_facts(nombre)


@app.get("/prolog/hechos")
def prolog_hechos():
    """Hechos de todo lo consultado hasta ahora, para alimentar Prolog."""
    return {"hechos": to_prolog(list(_cache.values()))}
