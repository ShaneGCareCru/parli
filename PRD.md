Shane — you’re right: the first draft treats “Realtime” like a buzzword, not the engine. Below is a **developer‑buildable MVP PRD** that uses the **OpenAI Realtime API** the way it was meant to be used (low‑latency, speech‑in → speech‑out, event‑driven). It keeps your **push‑to‑talk, half‑duplex** philosophy (because physics), adds **China/Korea practicality**, and replaces the custom audio socket with **native Realtime sessions** (WebRTC first; WebSocket fallback).

I’ve verified the API capabilities and exact event names in the official docs/cookbook and baked them into concrete flows and payloads. Refs are inline. ([OpenAI Platform][1], [OpenAI Cookbook][2])

---

# Product Requirements Document (PRD)

**Title**: AI Voice Translator — **MVP (Push‑to‑Talk Interpreter)**
**Owner**: Shane Gleeson
**Date**: 2025‑08‑18
**Version**: **0.6 (Realtime‑first MVP Spec)**

---

## 1) Product Thesis (Hard‑Nosed)

Ship a **reliable, half‑duplex push‑to‑talk interpreter** on **one phone** for two people traveling/meeting abroad. The user **presses and holds** to talk; on release, the app **streams a translation back** in the other language **as audio** (plus text for confidence). No auto‑detect; language directions are explicit. This maps directly to the Realtime API’s **turn‑based** speech workflow and minimizes latency & crosstalk. ([OpenAI Cookbook][2])

---

## 2) MVP Scope (Tight)

**In**

* **Mode**: Push‑to‑Talk (PTT), **consecutive** (half‑duplex).
* **Language Pairs (4)**:
  **EN↔ZH‑CN (Mandarin, Simplified)**, **EN↔KO (Korean)**, **EN↔ES**, **EN↔FR**. (Default = last used pair; no auto‑detect.)
* **UX**: Two large buttons: **“A speak”** and **“B speak.”** Hold to capture; release to translate → speak back.
* **Output**: Streaming **TTS audio** + on‑screen **transcript** per turn with confidence.
* **Privacy**: **No storage by default.** Optional opt‑in “Save transcript for 30 days.”

**Out (Future)**

* Auto turn‑taking/VAD as primary (we’ll ship manual PTT first).
* Call bridging (PSTN/VoIP).
* Offline model.
* Multi‑vendor plug‑in pipeline.

---

## 3) “Won’t Do” (Now)

* No **language auto‑detect** in MVP.
* No **barge‑in** (no speaking over playback).
* No recording without consent.

---

## 4) Latency Targets (Achievable)

**End‑to‑start** (button release → first syllable played):

* **P50 ≤ 1.6 s**, **P95 ≤ 2.3 s** on normal 8–12 word turns.

Why we can hit this: Realtime does **speech‑in → speech‑out** natively, and we avoid our own STT→MT→TTS orchestration; we stream chunks as **`response.audio.delta`** arrives. ([OpenAI Platform][3])

---

## 5) Architecture (Realtime‑First)

**Decision**: Use **OpenAI Realtime API** as the core pipeline. **WebRTC** from the mobile client for low latency and remote audio playback; **WebSocket** fallback when WebRTC is blocked. Clients connect using **ephemeral API keys** minted by our backend. ([OpenAI Platform][1])

### Components

* **Mobile App (Flutter)**

  * **Primary transport**: WebRTC → Realtime session (attach mic track; play remote audio track).
  * **Fallback**: WebSocket → send PCM16 chunks; play Base64 audio chunks as they stream. ([OpenAI Platform][1])
  * Two PTT buttons (A/B). When **A** is held, stream to session **A→B**; when **B** is held, stream to **B→A**.
  * During playback, **mic locked** to prevent echo.

* **Backend “Token Service” (tiny)**

  * Issues **ephemeral Realtime tokens** via REST to the app; tokens **expire \~1 minute after issue**. Connection persists after issuance; reconnects fetch a new token. ([OpenAI Platform][1])

* **Realtime Sessions (OpenAI)**

  * **Two live sessions per app** (pre‑warmed):

    * `sess_AB`: translate **from\_lang → to\_lang**
    * `sess_BA`: translate **to\_lang → from\_lang**
  * Each session configured with: **instructions**, **input audio transcription on**, **modalities: \["audio","text"]**, **voice** (neutral). We disable server VAD in MVP to honor PTT. ([OpenAI Platform][1])

**Why two sessions?** Zero prompt swapping between turns, no context bleed, and no per‑turn reconfiguration cost. (We keep directions stateless and explicit.)

---

## 6) Realtime Session Configuration (Concrete)

On connect (per session), send **`session.update`**:

```json
{
  "type": "session.update",
  "session": {
    "modalities": ["audio", "text"],
    "voice": "coral",
    "input_audio_format": {"type":"pcm16","sample_rate":16000},
    "input_audio_transcription": {"model":"whisper-1"},
    "turn_detection": {"type":"none"}  // PTT rules the day
  },
  "instructions": "You are a professional consecutive interpreter. Translate {FROM_LANG} → {TO_LANG} verbatim with correct politeness/register; preserve names, numbers, addresses. Output translation only. If unclear, say exactly: \"Please repeat.\""
}
```

**Notes**

* **`session.update`** is the right lever for voice/modality/behavior. ([OpenAI Platform][4])
* We’ll switch to **gpt‑4o‑transcribe** once quality/latency meet needs; same events flow. ([OpenAI Platform][5])

---

## 7) PTT Flow (Event‑Level)

**On press (e.g., A speaks)**

1. Start mic capture; **append audio** chunks to input buffer via **`input_audio_buffer.append`** (WS fallback) *or* stream via WebRTC track (primary). ([OpenAI Platform][1])
2. Show live waveform.

**On release**
3\) **Commit** the buffer with **`input_audio_buffer.commit`** → creates a new user input item in the conversation. ([OpenAI Platform][3])
4\) Immediately send **`response.create`** to request a translation response (audio + text). ([OpenAI Platform][6])
5\) Listen for:

* **`conversation.item.input_audio_transcription.delta`** → show partial STT;
* **`.completed`** → show final STT;
* **`response.audio.delta`** → stream decoded audio to speaker;
* **`response.output_text.delta`** (optional UI text);
* **`response.completed`** → turn ends; unlock mic. ([OpenAI Platform][5])

**Echo control**: While any **`response.audio.delta`** is playing, PTT buttons are disabled. (Yes, brutal. Also effective.)

---

## 8) Transports & Audio

* **Client → Realtime (primary)**: WebRTC mic track (mono 16 kHz).
* **Client → Realtime (fallback)**: WS sending PCM16 chunks in **`input_audio_buffer.append`** events; commit on release. ([OpenAI Platform][1])
* **Realtime → Client**:

  * **WebRTC**: remote audio track (just play it).
  * **WS Fallback**: handle **`response.audio.delta`** Base64 chunks; decode & stream. ([OpenAI Platform][3])

---

## 9) UX Spec (Phone, Minimal Friction)

* **Top chips**: `From: EN` ↔ `To: ZH‑CN`. **Swap** flips both chips and button labels. Default = last used.
* **Buttons**: **A Speak** (left), **B Speak** (right). **Hold** to talk; **release** to translate.
* **Live text**:

  * line 1: partial STT (fades to final)
  * line 2: translation text
* **Playback bubble**: **Replay** | **Copy**
* **Status**: “Connected (Realtime/WebRTC)” or “Fallback (WS)”
* **Errors**: Banners with actions (“Network lost—Tap to reconnect”).
* **Consent**: First run + when “Save transcript” toggled.

---

## 10) Conversation Track (Per Turn, App‑Local)

```json
{
  "turn_id": "t-123",
  "direction": "A->B",
  "from_lang": "en",
  "to_lang": "zh-CN",
  "stt_text": "good morning",
  "stt_conf": 0.93,
  "translation": "早上好",
  "t_start_ms": 1723950000,
  "t_end_ms": 1723951600,
  "error_code": null
}
```

No AI speaker field. System events separate.

---

## 11) Prompts (Concrete)

**System / instructions (per session)**: see §6.
**Domain modifiers** (append as sentence):

* `domain=business`: concise, formal phrasing; avoid slang.

Few‑shot examples for formality switches (usted/敬语/존댓말) may be added, but keep short to avoid latency bloat. Cookbook confirms we can steer output behavior for translation sessions. ([OpenAI Cookbook][2])

---

## 12) Settings

* Language pairs (persist last used).
* Voice (list of built‑in voices; default **coral**). ([OpenAI Platform][7])
* Save transcript **off** by default (30‑day retention when on).
* “Preflight network test” button (see §16 Risks).

---

## 13) Compliance & Consent

* **Default**: process only; no storage.
* **Opt‑in save**: encrypted at rest; per‑turn delete.
* **Consent banner**: “Both parties consent to live translation and audio processing.”
* Regional notices (GDPR/CPRA) in UI footer; record consent decisions.

---

## 14) Observability & Cost

* Client: session IDs, transport, latency markers (release→first audio), errors.
* Server (token svc): token issue counts, failures.
* Realtime: rely on client‑side timers + error events.
* **SLO**: 99% session up for 7‑day window; **P95 ≤ 2.3 s** end‑to‑start.
* Cost banner when translation minutes exceed soft cap.

---

## 15) Test Plan (Exit Criteria)

* **China/Korea trip simulation**: noisy café + quiet room.
* 10 guided sessions per language pair, ≥5 min each.
* Pass if:

  * ≥90% turns judged “acceptable” by bilingual reviewer,
  * P50 ≤ 1.6 s, P95 ≤ 2.3 s,
  * ≤1 hard error per 15 minutes.

---

## 16) Risks & Mitigations (Candid)

* **Connectivity in Mainland China**: direct access to OpenAI endpoints may be degraded/blocked depending on carrier/location. **Mitigation**:

  * Ship **WebRTC (UDP) primary, WS (TCP) fallback**;
  * **Preflight test** screen (connect+round‑trip tone) before travel;
  * Encourage traveler to carry **roaming eSIM** with multiple carriers.
  * (Offline mode remains out‑of‑scope for MVP; document this limitation clearly.)
* **Acoustic echo** on single device: avoid by **mic lock** during TTS and UI affordance that shows “Playing—hold to speak after beep.”
* **Token expiry**: ephemeral keys expire \~1 min **at issuance**; design app to fetch token only at connect/reconnect and hold the session open. ([OpenAI Platform][1])

---

## 17) Developer Handoff (What to Build)

### A. Token Service (Backend, tiny)

* `POST /realtime/ephemeral` → `{ token, expires_at }`

  * Uses server API key to mint **ephemeral Realtime token**; return to app. (Required by Realtime for browser/mobile clients.) ([OpenAI Platform][1])

### B. Mobile Client (Flutter)

* **Startup**

  * Call token service twice → connect **two sessions** (`sess_AB`, `sess_BA`) via **WebRTC**; if ICE fails, fall back to **WS**.
  * For each session send **`session.update`** with `modalities:["audio","text"]`, `voice`, `input_audio_transcription`, `turn_detection:none`, and the translation **instructions**. ([OpenAI Platform][4])

* **PTT Loop**

  * On **press**: begin mic capture; stream audio (WebRTC track or **`input_audio_buffer.append`**).
  * On **release**: **`input_audio_buffer.commit`**, then **`response.create`**.
  * Play streaming audio on **`response.audio.delta`**; update text on **transcription.delta** and **output\_text.delta**; unlock mic on **`response.completed`**. ([OpenAI Platform][5])

* **States**: `idle | capturing | translating | playing | error`

* **UI**: A/B buttons, chips (From/To), live text area, status line, consent & settings.

### C. Fallback WS Audio (only if WebRTC fails)

* Encode PCM16 16 kHz mono; send via **`input_audio_buffer.append`**; handle **`response.audio.delta`** Base64 → stream decode to DAC. ([OpenAI Platform][8])

---

## 18) Exact Events & Why

* **`input_audio_buffer.append` / `commit`** — stream + finalize turn (manual PTT). ([OpenAI Platform][5])
* **`response.create`** — ask model to emit translated audio/text. ([OpenAI Platform][6])
* **Server events**:

  * **`conversation.item.input_audio_transcription.delta/completed`** — partial & final STT, user‑visible. ([OpenAI Platform][5])
  * **`response.audio.delta`** — streamed audio chunks for playback. ([OpenAI Platform][3])

(Those are the doc‑blessed names; please don’t “improve” them.)

---

## 19) Prompt Templates (Deliverable)

**Base instructions (per session)**

> You are a professional **consecutive interpreter**. Translate **{FROM\_LANG} → {TO\_LANG}** **verbatim**, preserving meaning, politeness/register (usted/敬语/존댓말), names, numbers, and addresses. **Do not add commentary.** If audio is unclear, say exactly: “Please repeat.” Output **only** the translation.

**Domain = business**: “Use concise, formal phrasing suitable for business meetings.”

Cookbook pattern: steering translation with short, clear instructions; optional few‑shots. ([OpenAI Cookbook][2])

---

## 20) Roadmap After MVP

1. VAD on by default (no PTT), with UI barge‑in/ducking. ([OpenAI Platform][9])
2. Call bridging (PSTN/VoIP).
3. Glossaries & term boost.
4. Offline pack (out‑of‑scope now).
5. On‑device echo cancellation pipeline.

---

### Why this will work for your **China + South Korea** scenario

* **Explicit language directions** (EN↔ZH‑CN, EN↔KO) remove auto‑detect flakiness.
* **Half‑duplex PTT** eliminates crosstalk/echo on one phone.
* **Realtime sessions** stream audio back directly with instructions enforcing “translate only,” matching the **turn‑based** nature of the models today. ([OpenAI Cookbook][2])
* **WebRTC primary + WS fallback** gives us the best chance of getting through variable networks; if neither can reach the Realtime endpoint, we fail fast with a clear message (and, yes, we document that up front). ([OpenAI Platform][1])

---

## Appendix: Dev Notes & Links (for the team)

* **Realtime conversations guide** (WebRTC vs WS, input buffer): OpenAI docs. ([OpenAI Platform][1])
* **Ephemeral tokens** for client connections (expire \~1 min): Realtime guide. ([OpenAI Platform][1])
* **Transcription events & ordering** (`input_audio_buffer.*`, `conversation.item.input_audio_transcription.*`): Realtime transcription doc. ([OpenAI Platform][5])
* **Audio out streaming** (`response.audio.delta`): Realtime conversations doc. ([OpenAI Platform][3])
* **One‑way translation example** (architecture, prompts, WebRTC prod note): Cookbook. ([OpenAI Cookbook][2])

---

### Final bluntness

* If we **don’t** use Realtime natively and try to re‑stitch STT→MT→TTS, we’ll pay a latency tax and re‑implement features the API already gives us.
* If we **do** this spec, a small Flutter team can ship a field‑usable MVP that actually helps a business traveler in **China and South Korea** today — with clear limits, honest UX, and no “AI magic” hand‑waving.

[1]: https://platform.openai.com/docs/guides/realtime?utm_source=chatgpt.com "Realtime API - OpenAI API"
[2]: https://cookbook.openai.com/examples/voice_solutions/one_way_translation_using_realtime_api "Multi-Language One-Way Translation with the Realtime API"
[3]: https://platform.openai.com/docs/guides/realtime-conversations?utm_source=chatgpt.com "Realtime conversations - OpenAI API"
[4]: https://platform.openai.com/docs/api-reference/realtime-client-events/session/update?utm_source=chatgpt.com "OpenAI Platform"
[5]: https://platform.openai.com/docs/guides/realtime-transcription?utm_source=chatgpt.com "Realtime transcription - OpenAI API"
[6]: https://platform.openai.com/docs/api-reference/realtime-client-events/response/create?utm_source=chatgpt.com "OpenAI Platform"
[7]: https://platform.openai.com/docs/guides/text-to-speech/streaming-real-time-audio?utm_source=chatgpt.com "Text to speech - OpenAI API"
[8]: https://platform.openai.com/docs/guides/realtime/input-audio-buffer?utm_source=chatgpt.com "Realtime API - OpenAI API"
[9]: https://platform.openai.com/docs/guides/realtime-vad?utm_source=chatgpt.com "Voice activity detection (VAD) - OpenAI API"

