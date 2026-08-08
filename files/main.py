"""
JanSetu - Voice to Text Backend
--------------------------------
Run with:  uvicorn main:app --reload

This loads the Whisper model ONCE at startup, then exposes a
/voice-to-text endpoint. Send it an audio file (from the browser mic
recording, or any audio file) and it returns the transcribed text.
"""

from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
import whisper
import shutil
import tempfile
import os

app = FastAPI()

# Allow the frontend (running on a different port/origin) to call this API.
# For a hackathon, "*" (allow everyone) is fine. Tighten this later if needed.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the model once, when the server starts — NOT inside the endpoint.
# "small" is a good balance of speed/accuracy for Indian languages on CPU.
print("Loading Whisper model... (this happens once, may take a moment)")
model = whisper.load_model("small")
print("Model loaded. Server ready.")


@app.get("/")
def health_check():
    """Simple check to confirm the server is running."""
    return {"status": "ok", "message": "JanSetu voice-to-text server is running"}


@app.post("/voice-to-text")
async def voice_to_text(audio: UploadFile = File(...)):
    """
    Receives an audio file, transcribes it with Whisper, and returns the text.
    Works with whatever audio format the browser sends (webm, mp3, wav, m4a...).
    """
    # Save the uploaded audio to a temporary file, since Whisper needs a file path.
    suffix = os.path.splitext(audio.filename)[1] or ".webm"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        shutil.copyfileobj(audio.file, tmp)
        tmp_path = tmp.name

    try:
        # Omit `language=` to let Whisper auto-detect (Hindi, Kannada, English, etc.)
        result = model.transcribe(tmp_path)
        return {"text": result["text"].strip(), "language": result["language"]}
    finally:
        # Always clean up the temp file, even if transcription fails.
        os.remove(tmp_path)
