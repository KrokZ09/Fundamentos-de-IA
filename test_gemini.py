import os
from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()
modelo = os.getenv("GEMINI_MODEL", "gemini-flash-latest")
print("Modelo:", modelo)

client = OpenAI(
    api_key=os.getenv("GEMINI_API_KEY"),
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    timeout=60,
    max_retries=0,
)
try:
    r = client.chat.completions.create(
        model=modelo,
        messages=[{"role": "user", "content": "Responde solo: ok"}],
    )
    print("OK:", r.choices[0].message.content)
except Exception as e:
    print("ERROR:", type(e).__name__, e)