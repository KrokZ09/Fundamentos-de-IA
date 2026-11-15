# Chatbot de fútbol

Backend en FastAPI + API de Gemini (plan gratuito de Google AI Studio). Responde dónde juega un jugador
(equipo, liga, país, estadio) y qué relación hay entre jugadores.

## Instalación

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env             # Windows: copy .env.example .env
```

Edita `.env` y pon tu `GEMINI_API_KEY`
(se obtiene gratis en https://aistudio.google.com/apikey).

## Ejecutar

```bash
uvicorn main:app --reload
```

Documentación interactiva: http://localhost:8000/docs

## Para quien vaya a ejecutarlo (profesor, compañeros)

El proyecto **no incluye ninguna API key**; cada persona usa la suya (gratis):

1. Entra a https://aistudio.google.com/apikey con una cuenta de Google y pulsa **Create API key**.
2. Copia `.env.example` como `.env`.
3. Pega tu clave en `GEMINI_API_KEY=` (sin comillas ni espacios).
4. Instala y ejecuta (ver arriba).

Si falta la clave, el servidor se detiene al arrancar con el mensaje
"Falta GEMINI_API_KEY". NO SUBIR `.env` a Git ni compartir la clave.

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/chat` | `{"message": "..."}` → respuesta, jugadores y relaciones |
| GET | `/jugador/{nombre}` | Datos de un jugador |
| GET | `/prolog/hechos` | Hechos exportados para Prolog |

## Estructura prevista

```
futbol-chatbot/
├── main.py
├── requirements.txt
├── .env            # local, no se sube
├── .env.example
├── frontend/       # pendiente
└── prolog/
    ├── hechos.pl   # base de conocimiento (editar datos aquí)
    ├── reglas.pl   # lógica de primer orden
    ├── chatbot.pl  # intérprete por palabras clave + ciclo de consola
    └── api.pl      # puente con FastAPI (stdin -> JSON)
```

## Prolog

Requiere [SWI-Prolog](https://www.swi-prolog.org/Download.html) 9.x (en Windows, marcar "Add swipl to PATH"
o definir `SWIPL_PATH` en `.env`).

```bash
swipl prolog/chatbot.pl
?- chat.                                   % ciclo interactivo
?- responder('¿Dónde juega Messi?', R).    % una pregunta
?- make.                                   % recargar tras editar un .pl
```

