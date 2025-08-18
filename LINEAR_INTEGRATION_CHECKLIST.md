# Linear Integration Checklist

This checklist tracks the migration of all items from TASKLIST.md to Linear.
Each item includes: Story Number, Epic, Title, Points, Dependencies, and Linear Issue ID (to be filled).

## Setup Tasks
- [x] Create Linear Team (Parli - ID: 524d3aed-203c-4a74-8872-fb552a688583)
- [x] Create story point labels: 1pt (28544448-f6c5-4e1b-ae22-6e1dc9aefe16), 2pts (7307f211-a814-45a5-bb54-d77194fa33b6), 3pts (0ce32380-769c-4273-a55e-d856d6924069), 4pts (532057fe-86bc-48bc-836a-e1391e30a9db)
- [x] Create 11 Linear projects for each epic

## Epic Projects Created
- [x] EPIC A — Foundations & Repo Hygiene (02fbff20-b8a3-4a61-88ea-34bb43102f95)
- [x] EPIC B — Token Service (6c1368a6-7eaf-4fa0-8770-e4b19f799590)
- [x] EPIC C — Realtime Sessions (c4abf207-9187-4219-a6e7-85178dc87aae)
- [x] EPIC D — PTT Loop & Audio Pipeline (3a9526ae-2709-4e8f-b5fc-eb7e52cf7211)
- [x] EPIC E — Core UX & Settings (1b020318-2d09-4143-96b6-f795933fc9bf)
- [x] EPIC F — Conversation Track & Storage (53a969f9-954b-4870-913d-758c0e1f5bc3)
- [x] EPIC G — Resilience & Limits (ed6cee55-1cd7-417d-bcba-1cf9f4580052)
- [x] EPIC H — Consent & Compliance (c751766a-267e-4456-92d6-3ae6183d34c1)
- [x] EPIC I — Observability & Diagnostics (5b926589-51e0-4056-86c7-87dbb0b12a0b)
- [x] EPIC J — Travel Mode & Preflight (06b197d0-c0c8-4092-b4c4-1578019295c6)
- [x] EPIC K — QA Harness & Release (818ace6b-bf4c-46fd-ba8e-be36f217756a)

## Stories to Create (55 total)

### EPIC A — Foundations & Repo Hygiene
- [x] Story 1: Create mono‑repo scaffolding [1pt] | Deps: none | Linear ID: PAR-5 (a009153f-bbf6-47af-983c-e56c3d2b847d)
- [x] Story 2: CI: PR build for Flutter (Android+iOS) + Backend lint/test [3pts] | Deps: (1) | Linear ID: PAR-6 (dda13354-ed8c-40d2-9bb5-64fc52be40aa)
- [x] Story 3: Secret management baseline [2pts] | Deps: (1) | Linear ID: PAR-7 (08b59eea-dee0-4e50-a391-09335821e4b5)
- [x] Story 4: Issue templates & conventions [1pt] | Deps: none | Linear ID: PAR-8 (b6070eb2-5f41-4d24-a56b-9f5696c1761e)

### EPIC B — Token Service (Ephemeral Realtime Auth)
- [x] Story 5: Backend scaffold (FastAPI/Express) [2pts] | Deps: (1) | Linear ID: PAR-9 (bde738ee-6392-4311-aa69-d1cd27d1adbe)
- [x] Story 6: POST /realtime/ephemeral endpoint [3pts] | Deps: (5), (3) | Linear ID: PAR-10 (d3d2156a-d4c7-4b53-af65-defb52c1eb93)
- [x] Story 7: Rate limiting (IP + user) & CORS [2pts] | Deps: (6) | Linear ID: PAR-11 (aaf2d697-41ac-4a4e-b2e5-16fb5bcf0e22)
- [x] Story 8: Minimal auth [3pts] | Deps: (6) | Linear ID: PAR-12 (2c33856f-bbc9-4874-a706-92f904f9dcfc)
- [x] Story 9: Structured logging + request IDs [1pt] | Deps: (5) | Linear ID: PAR-13 (7be3215c-c37b-4251-a9e8-cb40d94d75d8)
- [x] Story 10: Unit tests for token issuance [2pts] | Deps: (6) | Linear ID: PAR-14 (6a3c7e72-d332-46f8-ac61-8aa6fc21a65d)

### EPIC C — Realtime Sessions (Connect & Configure)
- [x] Story 11: Flutter: add WebRTC + WS clients [3pts] | Deps: (1) | Linear ID: PAR-15 (4689c7e0-11d8-4a92-96f1-10dbeed33da1)
- [x] Story 12: Fetch ephemeral token(s) from backend [2pts] | Deps: (6), (11) | Linear ID: PAR-16 (8d3ab318-20f0-4ae2-86a2-9f111a27caf9)
- [x] Story 13: Create two Realtime sessions (AB & BA) via WebRTC [4pts] | Deps: (12) | Linear ID: PAR-17 (a3191d9d-afc4-4a58-a0fc-3d697dfa2afa)
- [x] Story 14: Session config: session.update with instructions & modalities [2pts] | Deps: (13) | Linear ID: PAR-18 (5518186c-5842-43f8-96cb-5b7e93859921)
- [x] Story 15: WS fallback path [3pts] | Deps: (11), (12) | Linear ID: PAR-19 (f931dd09-9571-4376-98c2-2896f840e220)

### EPIC D — PTT Loop & Audio Pipeline
- [x] Story 16: PTT UI skeleton (A/B hold buttons) [2pts] | Deps: (1) | Linear ID: PAR-20 (1135245e-7f68-4616-8dce-97e3f97de8c3)
- [x] Story 17: On press: start mic capture [2pts] | Deps: (16), (13) | Linear ID: PAR-21 (28ce87a9-0553-4f03-a26e-3c002d1c0640)
- [x] Story 18: On release (WS path): input_audio_buffer.commit [2pts] | Deps: (15), (17) | Linear ID: PAR-22 (7c4aeaeb-967a-4495-864a-acf6af7edb28)
- [x] Story 19: On release (WebRTC path): mark turn boundary [2pts] | Deps: (13), (17) | Linear ID: PAR-23 (526fa4a0-4024-44e8-a384-b786ce5f94a4)
- [x] Story 20: response.create per committed turn [2pts] | Deps: (18)/(19) | Linear ID: PAR-24 (329def65-d597-4ea0-ad57-677b2eaeb0da)
- [x] Story 21: Handle STT partials/finals [2pts] | Deps: (20) | Linear ID: PAR-25 (3a8ba4fd-4b37-45f7-b474-08e70dea7951)
- [x] Story 22: Stream audio out (response.audio.delta) with jitter buffer [3pts] | Deps: (20) | Linear ID: PAR-26 (ce49a363-8f39-4387-bbb4-14f4ea1b2618)
- [x] Story 23: Mic lock during playback + end‑beep [2pts] | Deps: (22) | Linear ID: PAR-27 (bf6f83b1-3836-47ac-adfc-17c391515ea4)
- [x] Story 24: Direction routing (A→B session vs B→A session) [2pts] | Deps: (13), (16) | Linear ID: PAR-28 (41669b2a-83ec-4ad1-9cb4-0198dc4975cb)
- [x] Story 25: Latency timers (release→first audio byte) [2pts] | Deps: (22) | Linear ID: PAR-29 (0b6c78a5-5269-4b5b-8699-38dd22d492b1)

### EPIC E — Core UX & Settings
- [x] Story 26: Language chips + swap [2pts] | Deps: (24) | Linear ID: PAR-30 (a0eff1d0-cee3-4845-8e1e-9403cd7d652f)
- [x] Story 27: Persist last used language pair [1pt] | Deps: (26) | Linear ID: PAR-31 (f28ee6eb-55aa-4b6d-859f-e03eb93b6420)
- [x] Story 28: Voice picker (list voices, default coral) [2pts] | Deps: (14) | Linear ID: PAR-32 (f38ef4c3-b07c-4a4c-b322-d6bc6af73f47)
- [x] Story 29: Status indicator [1pt] | Deps: (13), (15) | Linear ID: PAR-33 (42b034d3-6587-45e4-a8df-1ba4b7ddd9a3)
- [x] Story 30: Error banners [2pts] | Deps: (12), (13), (15) | Linear ID: PAR-34 (6dd769cd-6e22-4cb4-be12-2452e012ce71)
- [x] Story 31: Playback bubble (Replay/Copy) [2pts] | Deps: (22), (21) | Linear ID: PAR-35 (3d181613-3e49-4fcc-bf14-be0d43eecdb2)

### EPIC F — Conversation Track & Storage
- [x] Story 32: Define conversation_track schema (app‑local) [1pt] | Deps: (21), (22) | Linear ID: PAR-36 (5c9145a3-0119-4d30-ae9c-67dd4a88e52c)
- [x] Story 33: Track builder (assemble per‑turn record) [2pts] | Deps: (32), (21), (22), (25) | Linear ID: PAR-37 (3a6c9c62-5f37-43ad-9ac2-cc14e7147e1c)
- [x] Story 34: Export transcript (txt/json) [2pts] | Deps: (33) | Linear ID: PAR-38 (61e05d55-d459-42e1-984d-bf58ffb43a78)
- [x] Story 35: Opt‑in "Save transcript 30 days" toggle [3pts] | Deps: (33) | Linear ID: PAR-39 (63f2aa4b-0238-49f9-bdc8-be29416e939a)

### EPIC G — Resilience, Limits & UX Honesty
- [x] Story 36: Reconnect & resume [2pts] | Deps: (13), (15) | Linear ID: PAR-40 (8b9a50cf-b82f-483b-8486-962bf056c07a)
- [x] Story 37: Transport failover (WebRTC→WS, WS→WebRTC) [3pts] | Deps: (13), (15), (36) | Linear ID: PAR-41 (79be51c9-fa3c-40a0-8ebf-0961c9e6f630)
- [x] Story 38: Provider error mapping → user text [2pts] | Deps: (30) | Linear ID: PAR-42 (16bf8261-b2f4-496f-a76a-df2bfc5565ba)
- [x] Story 39: Soft/Hard cost caps UI [2pts] | Deps: (25) | Linear ID: PAR-43 (cec7821a-3095-442f-8715-9f924c1481e1)
- [x] Story 40: Rate limit simulation toggle (dev) [1pt] | Deps: (30), (38) | Linear ID: PAR-44 (442565d8-dbf3-4202-9e56-3511f0a4e833)

### EPIC H — Consent, Compliance & Copy
- [x] Story 41: Consent banner (first run & when saving enabled) [2pts] | Deps: (35) | Linear ID: PAR-45 (ce405c34-8689-4912-8c53-f6389c4ccebd)
- [x] Story 42: Regional notices (GDPR/CPRA simple footers) [1pt] | Deps: none | Linear ID: PAR-46 (2e404858-ef99-4e39-af63-5da9c37dacaa)
- [x] Story 43: Privacy policy link & "no storage by default" copy [1pt] | Deps: none | Linear ID: PAR-47 (085c09ed-c788-4bdd-aa59-c2329bfa7918)

### EPIC I — Observability & Diagnostics
- [x] Story 44: Client analytics events [2pts] | Deps: (25), (36) | Linear ID: PAR-48 (21d64515-7f8c-4da5-8862-2db46717fe3a)
- [x] Story 45: Crash reporting (Firebase Crashlytics or Sentry) [1pt] | Deps: (1) | Linear ID: PAR-49 (ea3fb6cf-0266-4827-bec6-b0427cc39ab9)
- [x] Story 46: Debug overlay [2pts] | Deps: (25), (29) | Linear ID: PAR-50 (222f830b-7d38-4f3a-861a-a05aaea1be19)

### EPIC J — "Travel Mode" & Preflight (China/Korea realism)
- [x] Story 47: Preflight connectivity test [3pts] | Deps: (6), (13), (15), (22) | Linear ID: PAR-51 (3d287b33-cdf9-4f02-9a7a-406fa782224f)
- [x] Story 48: Travel Mode toggle [2pts] | Deps: (37) | Linear ID: PAR-52 (67e04bfb-0127-4a7f-86bb-f7a16e0c84b8)
- [x] Story 49: Plain‑English limitation sheet [1pt] | Deps: none | Linear ID: PAR-53 (fe25a105-0165-45fe-97f7-f67200392f3e)

### EPIC K — QA Harness & Release Prep
- [x] Story 50: Audio fixtures & golden tests [3pts] | Deps: (22), (25) | Linear ID: PAR-54 (55262ef3-b0be-4b05-99ec-674ef61f6d40)
- [x] Story 51: Manual test script (noisy café + quiet room) [1pt] | Deps: (50) | Linear ID: PAR-55 (775dbae4-5818-4e5f-baaa-5864b2db52d4)
- [x] Story 52: Accessibility pass [2pts] | Deps: (16), (31) | Linear ID: PAR-56 (e6fabf63-1590-40be-9fb9-65e8046e6b0b)
- [x] Story 53: Beta build & internal distribution [2pts] | Deps: (45) | Linear ID: PAR-57 (17367ab2-91a2-4660-ae43-121fc3a86000)
- [x] Story 54: Performance tuning pass [2pts] | Deps: (22), (25), (46) | Linear ID: PAR-58 (d083e853-2194-4fb7-9713-da785e54fe5c)
- [x] Story 55: Release checklist [1pt] | Deps: (53) | Linear ID: PAR-59 (1b8c204e-2cdf-4f6e-9087-20bfd06a4981)

## Sprint Assignments (from TASKLIST.md)
- Sprint 1: Stories 1-3, 5-7, 11-13, 16-18, 26-27, 29
- Sprint 2: Stories 14-15, 19-25, 31-33, 36-38, 44-46
- Sprint 3: Stories 28, 30, 34-35, 39-43, 47-49
- Sprint 4: Stories 40, 50-55

## Verification
- [x] All 55 stories created in Linear
- [x] All dependencies correctly documented in Linear descriptions
- [x] All story points labeled
- [x] All stories assigned to correct epic projects
- [x] Sprint assignments match suggested flow