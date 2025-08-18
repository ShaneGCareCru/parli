Perfect—here’s a tight, dev‑ready backlog split into **small stories (1–4 pts)** that map exactly to the MVP spec you just approved (Realtime, PTT, two sessions, no magic). I’ve grouped them by epic, added dependencies, and wrote crisp **acceptance criteria (AC)** so no one bikesheds scope. Sprinkle of sarcasm included, because we’re adults.

**Point scale (for sanity):**
1 = tiny (≤½ day) • 2 = small (≈½–1 day) • 3 = medium (≈1–2 days) • 4 = chunky but sprintable (≈2–3 days)

---

## EPIC A — Foundations & Repo Hygiene

1. **Create mono‑repo scaffolding** (`/app` Flutter, `/token-service` backend) **\[1]**
   **AC:** Repo builds locally; README with run commands.
   **Deps:** none.

2. **CI: PR build for Flutter (Android+iOS) + Backend lint/test** **\[3]**
   **AC:** GH Actions (or GitLab) builds on PR; artifacts posted.
   **Deps:** (1)

3. **Secret management baseline** (local `.env`, CI secrets, no API keys in app) **\[2]**
   **AC:** App compiles with *no* server key embedded; docs say “keys only on server.”
   **Deps:** (1)

4. **Issue templates & conventions** (commit style, branching, codeowners) **\[1]**
   **AC:** Templates exist; CODEOWNERS gates protected branches.
   **Deps:** none.

---

## EPIC B — Token Service (Ephemeral Realtime Auth)

5. **Backend scaffold (FastAPI/Express)** **\[2]**
   **AC:** Health endpoint `/healthz` returns 200; containerized.
   **Deps:** (1)

6. **`POST /realtime/ephemeral` endpoint** **\[3]**
   **AC:** Returns `{token, expires_at}`; token usable from mobile for Realtime connect.
   **Deps:** (5), (3)

7. **Rate limiting (IP + user) & CORS** **\[2]**
   **AC:** 429 on abuse; only app origins allowed.
   **Deps:** (6)

8. **Minimal auth** (signed app session or Firebase token check) **\[3]**
   **AC:** Only authenticated app clients can mint ephemeral tokens.
   **Deps:** (6)

9. **Structured logging + request IDs** **\[1]**
   **AC:** Each token mint logs request\_id, user\_id (no tokens in logs).
   **Deps:** (5)

10. **Unit tests for token issuance** **\[2]**
    **AC:** Tests cover success/expiry/error paths; >80% file coverage.
    **Deps:** (6)

---

## EPIC C — Realtime Sessions (Connect & Configure)

11. **Flutter: add WebRTC + WS clients** **\[3]**
    **AC:** App links `flutter_webrtc`; WS fallback client compiles.
    **Deps:** (1)

12. **Fetch ephemeral token(s) from backend** **\[2]**
    **AC:** Refresh before connect; handles 401/429 with banner.
    **Deps:** (6), (11)

13. **Create two Realtime sessions (AB & BA) via WebRTC** **\[4]**
    **AC:** Both sessions connect; remote audio tracks plumbed to player.
    **Deps:** (12)

14. **Session config: `session.update` with instructions & modalities** **\[2]**
    **AC:** `modalities:["audio","text"]`, `voice:"coral"`, `input_audio_transcription.model:"whisper-1"`, `turn_detection:"none"`.
    **Deps:** (13)

15. **WS fallback path** **\[3]**
    **AC:** If ICE fails, app connects via WS and still receives audio deltas.
    **Deps:** (11), (12)

---

## EPIC D — PTT Loop & Audio Pipeline

16. **PTT UI skeleton (A/B hold buttons)** **\[2]**
    **AC:** Buttons report `press`, `hold`, `release` events; disabled state supported.
    **Deps:** (1)

17. **On press: start mic capture** **\[2]**
    **AC:** Mic permission prompt; waveform anim; capture starts only while held.
    **Deps:** (16), (13)

18. **On release (WS path): `input_audio_buffer.commit`** **\[2]**
    **AC:** Buffered PCM16 frames append during hold; commit on release with new item id.
    **Deps:** (15), (17)

19. **On release (WebRTC path): mark turn boundary** **\[2]**
    **AC:** Stop sending on release; internal “turn committed” state toggled.
    **Deps:** (13), (17)

20. **`response.create` per committed turn** **\[2]**
    **AC:** App sends `response.create` to session immediately after commit.
    **Deps:** (18)/(19)

21. **Handle STT partials/finals** **\[2]**
    **AC:** Render `conversation.item.input_audio_transcription.delta` live; final replaces partial.
    **Deps:** (20)

22. **Stream audio out** (`response.audio.delta`) with jitter buffer **\[3]**
    **AC:** Smooth playback; no clicks; chunks decoded as they arrive.
    **Deps:** (20)

23. **Mic lock during playback + end‑beep** **\[2]**
    **AC:** PTT disabled while audio plays; short beep when ready. (Yes, the sacred “talk now” beep.)
    **Deps:** (22)

24. **Direction routing (A→B session vs B→A session)** **\[2]**
    **AC:** A button uses AB session; B button uses BA; swap flips them.
    **Deps:** (13), (16)

25. **Latency timers** (release→first audio byte) **\[2]**
    **AC:** p50/p95 recorded per turn; exposed via debug overlay.
    **Deps:** (22)

---

## EPIC E — Core UX & Settings

26. **Language chips + swap** **\[2]**
    **AC:** From/To chips reflect selected pair; swap toggles labels and routing.
    **Deps:** (24)

27. **Persist last used language pair** **\[1]**
    **AC:** Relaunch uses previous pair; defaults to EN↔ZH‑CN on first run.
    **Deps:** (26)

28. **Voice picker (list voices, default coral)** **\[2]**
    **AC:** Picker updates session via `session.update`; persists choice.
    **Deps:** (14)

29. **Status indicator** (“Connected: Realtime/WebRTC” vs “Fallback: WS”) **\[1]**
    **AC:** Accurate transport label, auto‑updates on switch.
    **Deps:** (13), (15)

30. **Error banners** (token fail, network lost, throttled) **\[2]**
    **AC:** Contextual message + action (“Retry”, “Reconnect”).
    **Deps:** (12), (13), (15)

31. **Playback bubble (Replay/Copy)** **\[2]**
    **AC:** Replay last TTS; copy translation text to clipboard.
    **Deps:** (22), (21)

---

## EPIC F — Conversation Track & Storage

32. **Define `conversation_track` schema (app‑local)** **\[1]**
    **AC:** Matches PRD fields; list view renders turns.
    **Deps:** (21), (22)

33. **Track builder** (assemble per‑turn record) **\[2]**
    **AC:** Saves `stt_text`, `stt_conf`, `translation`, timings, direction, error\_code.
    **Deps:** (32), (21), (22), (25)

34. **Export transcript (txt/json)** **\[2]**
    **AC:** Share sheet exports current session as TXT and JSON.
    **Deps:** (33)

35. **Opt‑in “Save transcript 30 days” toggle** **\[3]**
    **AC:** Off by default; when on, local encrypted store with rolling TTL purge.
    **Deps:** (33)

---

## EPIC G — Resilience, Limits & UX Honesty

36. **Reconnect & resume** (backoff 200ms→2s, max 5) **\[2]**
    **AC:** Auto‑reconnect on drop; shows banner; resumes ready state.
    **Deps:** (13), (15)

37. **Transport failover** (WebRTC→WS, WS→WebRTC) **\[3]**
    **AC:** Automatic switch if connect or media fails; user sees status change.
    **Deps:** (13), (15), (36)

38. **Provider error mapping** → user text **\[2]**
    **AC:** 2001/2002/300x map to actionable banners per PRD.
    **Deps:** (30)

39. **Soft/Hard cost caps UI** **\[2]**
    **AC:** Soft warn at est. \$0.50/10min; hard pause at \$1.50 with “Resume (new session)”.
    **Deps:** (25)

40. **Rate limit simulation toggle (dev)** **\[1]**
    **AC:** Dev menu can force 429/`provider_down` to test banners.
    **Deps:** (30), (38)

---

## EPIC H — Consent, Compliance & Copy

41. **Consent banner (first run & when saving enabled)** **\[2]**
    **AC:** Explicit consent UI; stores timestamp & decision.
    **Deps:** (35)

42. **Regional notices** (GDPR/CPRA simple footers) **\[1]**
    **AC:** Static copy surfaces in settings; tracked in analytics.
    **Deps:** none.

43. **Privacy policy link & “no storage by default” copy** **\[1]**
    **AC:** Settings text matches product stance (lawyer‑friendly).
    **Deps:** none.

---

## EPIC I — Observability & Diagnostics

44. **Client analytics events** (session\_id, direction, latencies) **\[2]**
    **AC:** Events for connect, press, release, first‑audio, errors, transport.
    **Deps:** (25), (36)

45. **Crash reporting** (Firebase Crashlytics or Sentry) **\[1]**
    **AC:** Crashes symbolicated; breadcrumbs include last 5 events.
    **Deps:** (1)

46. **Debug overlay** (live latency, transport, seq) **\[2]**
    **AC:** Toggle via 5‑tap; shows p50/p95, transport mode, last error.
    **Deps:** (25), (29)

---

## EPIC J — “Travel Mode” & Preflight (China/Korea realism)

47. **Preflight connectivity test** **\[3]**
    **AC:** Connects to token svc + Realtime; plays test tone round‑trip; shows pass/fail per transport.
    **Deps:** (6), (13), (15), (22)

48. **Travel Mode toggle** (start on fallback WS if WebRTC fails thrice) **\[2]**
    **AC:** When enabled, WS is preferred; can switch back manually.
    **Deps:** (37)

49. **Plain‑English limitation sheet** **\[1]**
    **AC:** Settings page explains connectivity caveats and suggests multi‑carrier eSIM.
    **Deps:** none.

---

## EPIC K — QA Harness & Release Prep

50. **Audio fixtures & golden tests** **\[3]**
    **AC:** Small set of Mandarin/Korean audio clips; automated test asserts decoded audio starts ≤2.3s p95 locally.
    **Deps:** (22), (25)

51. **Manual test script** (noisy café + quiet room) **\[1]**
    **AC:** Checklist mirrors PRD exit criteria; stored in repo.
    **Deps:** (50)

52. **Accessibility pass** (button size, labels, haptics) **\[2]**
    **AC:** Buttons ≥48dp; TalkBack/VoiceOver labels; haptic on state change.
    **Deps:** (16), (31)

53. **Beta build & internal distribution** **\[2]**
    **AC:** TestFlight/Internal App Sharing live; versioned notes; crash capture enabled.
    **Deps:** (45)

54. **Performance tuning pass** (buffer sizes, audio decode) **\[2]**
    **AC:** Measured win (p50/p95 tail shaved); configs documented.
    **Deps:** (22), (25), (46)

55. **Release checklist** (what’s in/out, known issues) **\[1]**
    **AC:** One page; signed off by PM/Eng; no surprises.
    **Deps:** (53)

---

## Suggested Sprint Flow (if you want it)

* **Sprint 1:** (1–3,5–7,11–13,16–18,26–27,29) — App connects, PTT skeleton, token svc, basic status.
* **Sprint 2:** (14–15,19–25,31–33,36–38,44–46) — Full turn flow, text+audio streaming, resilience, metrics.
* **Sprint 3:** (28,30,34–35,39–43,47–49) — Settings, consent, export, cost caps, preflight/travel mode.
* **Sprint 4:** (40,50–55) — Simulations, perf polish, a11y, beta + release docs.

---

## Definition of Done (for *every* story)

* Meets listed **AC** on **Android + iOS** (sim + at least one real device).
* No crashes; error states handled with user‑visible copy.
* Telemetry events emitted where relevant.
* Unit or integration test where feasible.
* Updated README or in‑app help if user‑visible.

---

### Final nudge

This is the smallest set of stories that yields a **real, usable** interpreter for a traveler in China/Korea with honest limits. If anyone tries to add “auto‑detect everything” or “also do calls,” point them to the backlog… or the door.

