# Sprint 1 - Foundation Sprint

## 🎯 Sprint Goal
**"App connects, PTT skeleton, token service, basic status"**

Establish the foundational infrastructure for the Parli voice translator, including basic Flutter app structure, backend token service, WebRTC connections, and initial push-to-talk interface.

## 📊 Sprint Overview
- **Total Stories**: 15 stories
- **Total Points**: 30 points (assuming 2-week sprint)
- **Sprint Label**: `Sprint 1` (blue) in Linear
- **Status**: All stories moved to `Todo` state

## 📋 Sprint Stories

### EPIC A — Foundations & Repo Hygiene (4 stories, 7 pts)
- **PAR-5** (1pt): Create mono-repo scaffolding
- **PAR-6** (3pts): CI: PR build for Flutter + Backend
- **PAR-7** (2pts): Secret management baseline
- *(PAR-8 not in Sprint 1)*

### EPIC B — Token Service (3 stories, 7 pts)
- **PAR-9** (2pts): Backend scaffold (FastAPI/Express)
- **PAR-10** (3pts): POST /realtime/ephemeral endpoint
- **PAR-11** (2pts): Rate limiting & CORS

### EPIC C — Realtime Sessions (3 stories, 9 pts)
- **PAR-15** (3pts): Flutter: add WebRTC + WS clients
- **PAR-16** (2pts): Fetch ephemeral tokens from backend
- **PAR-17** (4pts): Create two Realtime sessions (AB & BA)

### EPIC D — PTT Loop & Audio Pipeline (3 stories, 6 pts)
- **PAR-20** (2pts): PTT UI skeleton (A/B hold buttons)
- **PAR-21** (2pts): On press: start mic capture
- **PAR-22** (2pts): On release (WS path): commit audio

### EPIC E — Core UX & Settings (2 stories, 3 pts)
- **PAR-30** (2pts): Language chips + swap
- **PAR-31** (1pt): Persist last used language pair
- **PAR-33** (1pt): Status indicator

## 🔗 Key Dependencies
Critical path dependencies to watch:
1. **PAR-5** → Everything else (foundation)
2. **PAR-9** → **PAR-10** → **PAR-16** (backend token flow)
3. **PAR-15** + **PAR-16** → **PAR-17** (realtime sessions)
4. **PAR-5** → **PAR-20** → **PAR-21** (PTT flow)

## 🎯 Sprint Success Criteria
By sprint end, you should have:
- ✅ Working Flutter app that builds locally
- ✅ Backend service issuing ephemeral tokens
- ✅ Two WebRTC Realtime sessions connecting
- ✅ Basic PTT buttons with audio capture
- ✅ Language selection and persistence
- ✅ CI pipeline building both platforms

## 🔄 Linear Best Practices Applied

### Labels Used:
- **Sprint 1**: Identifies all sprint stories
- **1pt/2pts/3pts/4pts**: Story sizing
- **Epic labels**: Will be inherited from projects

### Status Management:
- **Backlog**: Not yet prioritized
- **Todo**: Sprint stories ready to start
- **In Progress**: Active work
- **In Review**: Ready for review
- **Done**: Completed work

### Workflow Tips:
1. **Move stories to "In Progress"** when you start work
2. **Use Linear's git branch integration** (already set up with branch names)
3. **Comment on stories** to track progress and decisions
4. **Link PRs** to stories automatically via branch names
5. **Move to "In Review"** when ready for code review
6. **Move to "Done"** only when fully complete and deployed

## 🚀 Getting Started
1. Start with **PAR-5** (mono-repo scaffolding) - it's the foundation
2. Work dependency order: 5→9→15→6→10→20, etc.
3. Use `git checkout -b shanemgleeson/par-X-description` for branches
4. Linear will auto-link PRs when you use the branch names shown

## 📈 Sprint Tracking
Filter in Linear by:
- Label: `Sprint 1`
- Team: `Parli`
- Status: `Todo`, `In Progress`, etc.

Sprint health can be tracked by story completion rate and dependency flow.