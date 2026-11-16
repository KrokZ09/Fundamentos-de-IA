"""
Evalúa los dos sistemas con las mismas 20 preguntas.

Uso (desde la raíz del repo, con el entorno virtual activo):
    python evaluar.py

Genera resultados_evaluacion.md con la respuesta y el tiempo de cada sistema.
- Prolog solo: preguntar_a_prolog() de main.py (sin respaldo de Gemini).
- LLM solo:    chat_gemini() de main.py (sin pasar por Prolog).
"""
import time

from fastapi import HTTPException

from main import ChatIn, chat_gemini, preguntar_a_prolog

PREGUNTAS = [
    # A. Consultas directas
    "¿Dónde juega Lionel Messi?",
    "¿En qué equipo juega Erling Haaland?",
    "¿En qué liga juega Bukayo Saka?",
    "¿Cuál es la nacionalidad de Mohamed Salah?",
    "¿En qué estadio juega de local Harry Kane?",
    "¿Dónde juega Cristiano Ronaldo?",
    # B. Relaciones entre jugadores
    "¿Mbappé y Vinícius son compañeros?",
    "¿Qué relación hay entre Haaland y Saka?",
    "¿Qué relación hay entre Messi y Cristiano Ronaldo?",
    "¿Qué relación hay entre Bellingham y Kane?",
    "¿Qué relación hay entre Messi, Lautaro Martínez y Julián Álvarez?",
    # C. Variaciones del lenguaje
    "¿Dónde juega Mesi?",
    "¿Dónde juega Martínez?",
    "¿Dónde juega CR7?",
    # D. Jugadores fuera de la base
    "¿Dónde juega Pedri?",
    "¿Qué relación hay entre Messi y Pedri?",
    # E. Fuera del esquema o del dominio
    "¿Cuántos goles ha marcado Haaland?",
    "¿Qué jugadores juegan en el Real Madrid?",
    "¿Qué jugadores conoces?",
    "¿Cuál es la capital de Francia?",
]


def ejecutar(funcion, pregunta):
    """Devuelve (respuesta, segundos). Reintenta una vez si hay error 429."""
    inicio = time.time()
    for intento in range(2):
        try:
            resultado = funcion(pregunta)
            texto = resultado["answer"] if isinstance(resultado, dict) else resultado.answer
            return " ".join(str(texto).split()), time.time() - inicio
        except HTTPException as e:
            texto = f"[ERROR {e.status_code}] {e.detail}"
            break
        except Exception as e:
            if "429" in str(e) and intento == 0:
                print("  Límite 429 alcanzado, esperando 60 s para reintentar...")
                time.sleep(60)
                inicio = time.time()  # reinicia el cronómetro para medir la respuesta real
                continue
            texto = f"[ERROR {type(e).__name__}] {e}"
            break
    return " ".join(str(texto).split()), time.time() - inicio


def solo_gemini(pregunta):
    return chat_gemini(ChatIn(message=pregunta))


lineas = ["# Resultados de la evaluación", ""]
for i, pregunta in enumerate(PREGUNTAS, 1):
    prolog, t_prolog = ejecutar(preguntar_a_prolog, pregunta)
    llm, t_llm = ejecutar(solo_gemini, pregunta)
    print(f"{i}/{len(PREGUNTAS)} listo ({t_llm:.1f} s)")
    lineas += [
        f"## {i}. {pregunta}",
        f"- **Prolog** ({t_prolog:.1f} s): {prolog}",
        f"- **LLM** ({t_llm:.1f} s): {llm}",
        "",
    ]
    time.sleep(20)  # pausa de 20 s para respetar el límite por minuto del plan gratuito

with open("resultados_evaluacion.md", "w", encoding="utf-8") as f:
    f.write("\n".join(lineas))
print("Guardado en resultados_evaluacion.md")