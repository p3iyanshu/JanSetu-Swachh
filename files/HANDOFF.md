# Voice-to-Text Feature — Integration Notes

## What this does
Tap mic → record audio → send to a local backend server → get back transcribed text → auto-fill description field.

Since your emulator runs on your laptop, **the backend server needs to run on your laptop too** — that way `10.0.2.2` (the emulator's address for "my host machine") correctly reaches it.

---

## Part A — Backend setup (do this first)

You need Python installed. Then:

**1. Save the attached `main.py` anywhere on your laptop** (e.g. a new folder `voice-backend`).

**2. Install dependencies** — open a terminal in that folder:
```bash
pip install fastapi uvicorn python-multipart openai-whisper --break-system-packages
```
This also pulls in PyTorch, so it can take a few minutes and a few hundred MB.

**3. Install ffmpeg** (Whisper needs it to read audio):
- **Windows**: `winget install ffmpeg`, then **close and reopen your terminal** so it picks up the PATH change. Verify with `ffmpeg -version`.
- **Mac**: `brew install ffmpeg`
- **Linux**: `sudo apt install ffmpeg`

**4. Start the server:**
```bash
uvicorn main:app --reload
```
Wait for `Model loaded. Server ready.` in the terminal — this downloads the Whisper model (~500MB) the first time only. Leave this terminal running whenever you're testing the app.

**5. Quick sanity check** — open `http://127.0.0.1:8000` in a browser. You should see `{"status":"ok",...}`.

---

## Part B — Android integration

- Endpoint: `POST /voice-to-text`
- Expects: multipart form-data with a field named `audio` (any format — m4a, wav, webm, mp3)
- Returns JSON: `{"text": "...", "language": "hi"}`

**Server URL to use in the app (since you're on the emulator, and the server is on the same laptop):**
```
http://10.0.2.2:8000/voice-to-text
```
`10.0.2.2` is the special address Android emulators use to reach `localhost` on the host machine. Don't use `127.0.0.1` — that points to the emulator itself, not your laptop.

## 1. Add permissions — `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

## 2. Add dependency — `build.gradle` (app-level)
```gradle
implementation("com.squareup.okhttp3:okhttp:4.12.0")
```

## 3. Runtime mic permission
Since `RECORD_AUDIO` is a dangerous permission, request it at runtime before first use (standard Android permission request — e.g. `ActivityCompat.requestPermissions(...)` for `Manifest.permission.RECORD_AUDIO`).

## 4. Helper class — new file `VoiceToTextHelper.kt`
```kotlin
import android.content.Context
import android.media.MediaRecorder
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.asRequestBody
import java.io.File
import java.io.IOException

class VoiceToTextHelper(private val context: Context) {

    private var recorder: MediaRecorder? = null
    private var audioFile: File? = null
    private val client = OkHttpClient()

    private val backendUrl = "http://10.0.2.2:8000/voice-to-text"

    fun startRecording() {
        audioFile = File(context.cacheDir, "voice_note.m4a")
        recorder = MediaRecorder().apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setOutputFile(audioFile!!.absolutePath)
            prepare()
            start()
        }
    }

    fun stopRecordingAndTranscribe(onResult: (String) -> Unit, onError: (String) -> Unit) {
        recorder?.apply {
            stop()
            release()
        }
        recorder = null

        val file = audioFile ?: return onError("No audio recorded")

        val requestBody = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart(
                "audio", file.name,
                file.asRequestBody("audio/m4a".toMediaTypeOrNull())
            )
            .build()

        val request = Request.Builder()
            .url(backendUrl)
            .post(requestBody)
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                onError("Could not reach server: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                val body = response.body?.string()
                val text = org.json.JSONObject(body ?: "{}").optString("text", "")
                onResult(text)
            }
        })
    }
}
```

## 5. Wire it up in the Activity/Fragment with the mic button
```kotlin
val voiceHelper = VoiceToTextHelper(this)
var isRecording = false

micButton.setOnClickListener {
    if (!isRecording) {
        voiceHelper.startRecording()
        isRecording = true
        micButton.setImageResource(R.drawable.ic_mic_recording) // optional: red/pulsing icon
    } else {
        voiceHelper.stopRecordingAndTranscribe(
            onResult = { text ->
                runOnUiThread { descriptionEditText.append(" $text") }
            },
            onError = { msg ->
                runOnUiThread { Toast.makeText(this, msg, Toast.LENGTH_SHORT).show() }
            }
        )
        isRecording = false
        micButton.setImageResource(R.drawable.ic_mic)
    }
}
```
Replace `descriptionEditText` and `micButton` with the actual view IDs from the existing layout.

## Testing checklist
1. Your backend running (`uvicorn main:app --reload`) — confirm terminal shows "Model loaded. Server ready."
2. Emulator running, app installed with the code above.
3. Tap mic → grant permission if prompted → speak → tap again to stop.
4. Description field should fill in a few seconds. First request is often slower (model warming up).

## If it doesn't connect
- Double check the URL is exactly `http://10.0.2.2:8000/voice-to-text` (not 127.0.0.1, not localhost).
- Make sure `usesCleartextTraffic` isn't blocked — on newer Android, `http://` (non-https) to a non-localhost-looking address can be blocked by default. If you get a network security error, add this to `AndroidManifest.xml` inside `<application>`:
  ```xml
  android:usesCleartextTraffic="true"
  ```
  (fine for a hackathon demo; wouldn't ship this to production as-is)
