"""
JanSetu - Voice to Text Backend (Sarvam AI)
--------------------------------------------
Run with:  uvicorn main:app --reload --host 0.0.0.0 --port 8001

Uses Sarvam AI's speech-to-text-translate API instead of local Whisper:
  - No model download, no ffmpeg needed, no local crashes.
  - Handles 23 languages (22 Indian + English) automatically.
  - Always returns ENGLISH text, no matter what language was spoken.
  - Needs an internet connection to work (it's calling Sarvam's servers).

SETUP:
Set SARVAM_API_KEY in voice-backend/.env (see .env.example).
"""

from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import os
import requests
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()

# Allow the app (or anything else) to call this API freely.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

SARVAM_API_KEY = os.environ.get("SARVAM_API_KEY", "")
SARVAM_URL = "https://api.sarvam.ai/speech-to-text"


@app.get("/")
def health_check():
    """Simple check to confirm the server is running."""
    key_status = "set" if SARVAM_API_KEY else "MISSING"
    return {"status": "ok", "message": "JanSetu voice-to-text server (Sarvam) is running", "api_key": key_status}


@app.post("/voice-to-text")
async def voice_to_text(audio: UploadFile = File(...)):
    """
    Receives an audio file (any common format - m4a, wav, webm, mp3, etc.),
    sends it to Sarvam AI, and returns the ENGLISH translation of the speech,
    regardless of which Indian language was spoken.
    """
    if not SARVAM_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="Sarvam API key not set. Add SARVAM_API_KEY to voice-backend/.env.",
        )

    audio_bytes = await audio.read()

    files = {
        "file": (audio.filename or "audio.wav", audio_bytes, audio.content_type or "audio/wav"),
    }
    data = {
        "model": "saaras:v3",
        "mode": "translate",  # this is what gives us English output directly
    }
    headers = {
        "api-subscription-key": SARVAM_API_KEY,
    }

    try:
        response = requests.post(SARVAM_URL, headers=headers, files=files, data=data, timeout=30)
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=502, detail=f"Could not reach Sarvam API: {e}")

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"Sarvam API error ({response.status_code}): {response.text}",
        )

    result = response.json()

    return {
        "text": result.get("transcript", "").strip(),
        "language": result.get("language_code", "auto"),
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="0.0.0.0", port=8001, reload=True)
