# Chatbot de fútbol

Backend en FastAPI. Responde dónde juega un jugador (equipo, liga, país, estadio) y qué relación
hay entre jugadores.

**Cómo funciona:** Prolog es el motor principal (carpeta `prolog/`). Si la pregunta no menciona a
ningún jugador de `prolog/hechos.pl`, `main.py` usa la API de Gemini como respaldo.

```
POST /chat → Prolog (api.pl) ── reconoce a un jugador de hechos.pl ──→ respuesta
                            └─ no reconoce a ninguno ──→ Gemini ──→ respuesta
```

## Requisitos

- Python 3.
- [SWI-Prolog](https://www.swi-prolog.org/Download.html) con `swipl` en el PATH (probado con 10.0.2).
  En Windows, marca "Add swipl to PATH" al instalar y comprueba con `swipl --version`.
- Una API key de Gemini (https://aistudio.google.com/apikey).

## Instalación

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env             # Windows: copy .env.example .env
```

Edita `.env`:

```
GEMINI_API_KEY=tu_clave_aqui
GEMINI_MODEL=gemini-3.5-flash-lite
```

> **Modelo de Gemini:** usa `gemini-3.5-flash-lite`. No uses `gemini-flash-latest`: en las
> pruebas se quedó sin responder (timeout) y el endpoint de Gemini se colgaba. Si tu modelo da
> error 404 o timeout, cambia `GEMINI_MODEL` en `.env` por otro disponible en tu cuenta y reinicia
> el servidor (el `.env` solo se lee al arrancar).

## Ejecutar

```bash
uvicorn main:app --reload
```

Documentación interactiva: http://localhost:8000/docs

### Probar en `/docs` → `POST /chat`

| Mensaje | Qué debería pasar |
|---------|-------------------|
| `¿Dónde juega Messi?` | Responde Prolog, con texto fijo (`Lionel Messi juega en Inter Miami...`) |
| `Que relacion hay entre Messi y Lautaro Martinez` | Responde Prolog; en `relations`, `misma_nacionalidad: true` |
| `¿Dónde juega Pedri?` | No está en `hechos.pl`: responde Gemini, con texto libre y campo `confianza` |

## Para quien vaya a ejecutarlo (profesor, compañeros)

El proyecto **no incluye ninguna API key**; cada persona usa la suya:

1. Entra a https://aistudio.google.com/apikey con una cuenta de Google y pulsa **Create API key**.
2. Copia `.env.example` como `.env`.
3. Pega tu clave en `GEMINI_API_KEY=` (sin comillas ni espacios) y deja `GEMINI_MODEL=gemini-3.5-flash-lite`.
4. Instala SWI-Prolog (ver Requisitos), instala las dependencias y ejecuta (ver arriba).

Si falta la clave, el servidor se detiene al arrancar con el mensaje "Falta GEMINI_API_KEY".
NO SUBIR `.env` a Git ni compartir la clave.

## Endpoints

| Método | Ruta | Descripción |
|--------|------|-------------|
| POST | `/chat` | `{"message": "..."}` → respuesta, jugadores y relaciones. Prolog primero, Gemini como respaldo |
| POST | `/chat-gemini` | Igual que `/chat`, pero usando solo Gemini (también es el respaldo de `/chat`) |
| GET | `/jugador/{nombre}` | Datos de un jugador según Gemini |
| GET | `/prolog/hechos` | Hechos de los jugadores consultados a Gemini, en formato Prolog |

## Estructura

```
Fundamentos-de-IA/
├── main.py            # API FastAPI + puente a Prolog + respaldo Gemini
├── requirements.txt
├── .env               # local, no se sube
├── .env.example
├── .gitignore
└── prolog/
    ├── hechos.pl      # base de conocimiento (editar datos aquí)
    ├── reglas.pl      # lógica de primer orden
    ├── chatbot.pl     # intérprete por palabras clave + ciclo de consola
    └── api.pl         # puente con FastAPI (stdin -> JSON)
```

## Prolog

Desde la raíz del repo:

```bash
swipl prolog/chatbot.pl
?- chat.                                   % ciclo interactivo
?- responder('¿Dónde juega Messi?', R).    % una pregunta
?- make.                                   % recargar tras editar un .pl
```

Para probar el puente sin FastAPI (PowerShell):

```powershell
"Donde juega Messi" | swipl -q -s prolog/api.pl -g main_api -t halt
```

Devuelve un JSON con `answer`, `players` y `relations`. Si ves caracteres raros como `├í`, es solo
la consola mostrando UTF-8; desde Python se leen bien. Desde PowerShell, las tildes de la pregunta
pueden perderse al enviarlas con `|`.

## Problemas frecuentes

- **`No se encontró 'swipl'`**: instala SWI-Prolog y agrégalo al PATH; reinicia la terminal.
- **Gemini se queda cargando o da 404**: revisa `GEMINI_MODEL` en `.env` (ver arriba) y reinicia uvicorn.
- **Error 429 de Gemini**: llegaste al límite de uso de tu cuenta; espera un momento o cambia de modelo.

## Limitaciones

- Los datos de `hechos.pl` son de ejemplo y pueden estar desactualizados (fichajes, estadios).
- Los datos que da Gemini (para jugadores fuera de `hechos.pl`) no se verifican y no pasan por las
  reglas de Prolog: una pregunta de relación entre un jugador de `hechos.pl` y otro que no está
  todavía no se cruza.
- `/chat` decide el respaldo buscando el texto "No reconozco" en la respuesta de Prolog (caso final
  de `decidir/4` en `chatbot.pl`). Si cambias ese mensaje, cambia también la condición en `main.py`.
