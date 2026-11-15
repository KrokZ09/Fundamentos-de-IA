import os, time
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()
client = OpenAI(
    api_key=os.getenv("GEMINI_API_KEY"),
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    timeout=60,
    max_retries=0,
)
candidatos = [
    "gemini-flash-latest",
    "gemini-flash-lite-latest",
    "gemini-2.5-flash-lite",
    "gemini-3.1-flash-lite",
    "gemini-3.5-flash-lite",
    "gemini-3.5-flash",
]
for modelo in candidatos:
    t = time.time()
    try:
        r = client.chat.completions.create(
            model=modelo,
            messages=[{"role": "user", "content": "Responde solo: ok"}],
        )
        print(f"OK     {modelo}  {time.time() - t:.1f}s  -> {r.choices[0].message.content!r}")
    except Exception as e:
        detalle = getattr(getattr(e, "response", None), "text", "")[:200]
        print(f"ERROR  {modelo}  {time.time() - t:.1f}s  {type(e).__name__} {detalle}")