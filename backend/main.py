import base64
from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
import shutil
import os
import wave
import whisper
import tempfile
import time

app = FastAPI()

# Function to load model with retry and fallback

WHISPER_MODEL = whisper.load_model("medium")

def transcribe_audio_with_whisper(audio_path: str, language: str = "ur") -> str:
    """
    Transcribe audio file using Whisper model
    """
    try:
        # Simpler transcription without preprocessing (for now)
        result = WHISPER_MODEL.transcribe(
            audio_path,
            language=language,
            task="transcribe",
            fp16=False  # CPU mode
        )
        
        return result["text"]
        
    except Exception as e:
        print(f"Error in transcription: {e}")
        raise

@app.post("/audio")
async def transcribe_and_speak(file: UploadFile = File(...), language: str = "ur"):
    """
    Endpoint to receive audio and transcribe it
    """
    print(f"Received audio: {file.filename}")
    
    temp_file = None
    try:
        # Save uploaded file
        file_extension = os.path.splitext(file.filename)[1] or '.wav'
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as tmp:
            shutil.copyfileobj(file.file, tmp)
            temp_file = tmp.name
        
        # Transcribe
        transcription = transcribe_audio_with_whisper(temp_file, language)
        print(f"Transcription result: {transcription}")
        
        return JSONResponse(
            content={
                "status": "success",
                "transcription": transcription,
                "language": language,
                "model_size": "small",  # یا جو ماڈل لوڈ ہوا ہو
            },
            status_code=200
        )
        
    except Exception as e:
        print(f"Error: {e}")
       