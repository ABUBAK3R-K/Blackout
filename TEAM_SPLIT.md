# BLACKOUT — Team Split & Ownership

**Companion docs:** `prd.md` (requirements/scope), `design.md` (systems/architecture)

This document proposes how to divide the MVP scope across a small team, mapped directly to
the module breakdown in `design.md` §6.3. Team size and exact headcount will vary — the
roles below are functional areas, and one person may own more than one area on a small
team, or areas may be merged/split further on a larger one.

---

## 1. Functional Areas Overview

| Area | Primary Responsibility | Maps to (design.md) |
|---|---|---|
| Game Systems / Backend | Authoritative server logic, state machine, anti-cheat validation | `game_state`, `role_manager`, `task_manager`, `blackout_manager`, `blackout_recovery`, `sabotage_manager`, `meeting_manager`, `voting_manager`, `meltdown_manager`, `win_condition_manager` |
| Gameplay / Content Design | Task definitions, objective balance, evidence design, pacing | `crew_tasks`, `impostor_tasks`, `evidence_manager`, config values |
| Client / Gameplay Programming | Player movement, task/mini-game interactions, client-side prediction | `player` (client half), mini-game input layer |
| UI/UX | All screens, HUD, timers, meeting/voting flow, result screens | `ui/` module tree entirely |
| Map & Environment Art | Facility layout, room art, lighting states (normal vs. blackout) | `map_manager`, environment assets |
| Audio | SFX for sabotage, ambient blackout tension, meeting/voting stingers, alarms | Cross-cutting |
| Production / QA | Scope tracking, playtesting cadence, balance tuning coordination | Cross-cutting |

---

## 2. Suggested Role Split

### 2.1 Backend / Game Systems Engineer(s)
**Owns the server-authoritative core.** This is the highest-risk, most central area —
should be staffed first and protected from scope creep.

Responsibilities:
- Implement the top-level state machine (`LOBBY → … → GAME_OVER`).
- Role assignment and secure per-client role reveal.
- Task completion validation (Crew and Impostor).
- Blackout unlock gating, remote activation, countdown, fixed/configurable timer.
- Blackout recovery system tracking and early-termination logic (X-of-Y systems).
- Impostor blackout objective tracking (file theft, ORION objectives, sabotage) —
  validated server-side, hidden from other clients.
- Evidence generation (server decides what becomes discoverable and when).
- Meeting trigger handling, vote collection/tally/resolution.
- Meltdown timer, 3 emergency task validation, Impostor interference during Meltdown.
- Win/lose determination.

Key interfaces to other areas:
- Exposes network events/RPCs for every client-facing state change (task progress,
  blackout state, evidence flags, vote results, meltdown progress).
- Defines the config schema (blackout duration, recovery threshold, etc.) that Design will
  tune.

### 2.2 Gameplay / Content Designer(s)
**Owns balance and "does this feel fair and fun."**

Responsibilities:
- Author the specific task list content for Crew and Impostor (names, locations,
  interaction type/mini-game per task).
- Design the Impostor's blackout objective set and how each maps to a mini-game.
- Design evidence rules: what evidence each Impostor action generates, and how
  discoverable/subtle it should be.
- Own the tunable config values from `design.md` §6.4 (blackout duration, recovery
  threshold, prerequisite task count, vote rule, visibility radius) and drive playtesting
  to converge on values.
- Define meeting-trigger mechanics (final decision on the open question in `prd.md` §9.3).
- Track the "Important Gameplay Rules" list in `design.md` §5 as non-negotiable
  constraints during design reviews.

Key interfaces to other areas:
- Hands off task/objective specs to Client Programming and UI for implementation.
- Works directly with Backend on config schema and with QA on balance test results.

### 2.3 Client / Gameplay Programmer(s)
**Owns what the player directly touches, moment to moment.**

Responsibilities:
- Player movement/controller, room-to-room traversal, spawn handling.
- Task and mini-game interaction implementation (input layer; correctness is
  server-validated per `design.md` §6.2).
- Client-side rendering of visibility changes during blackout (vision radius, emergency
  lighting look).
- Client-side handling of door malfunction states, camera unavailability, etc.
- Reconciliation with server-authoritative state (client never assumes an action
  succeeded until server confirms).

Key interfaces to other areas:
- Consumes Backend's network events; renders through UI's screens/HUD.
- Consumes Map & Environment Art's room layouts and interactable placements.

### 2.4 UI/UX Designer/Programmer(s)
**Owns every screen listed in `design.md` §6.3 `ui/` tree.**

Responsibilities:
- Role reveal screen.
- Task UI (list, progress, per-task interaction framing).
- Blackout UI (activation prompt for Impostor, countdown, ambient state indicators for
  Crew).
- Timer UI (blackout countdown, meltdown countdown — should feel tense but readable).
- Sabotage UI (Impostor-only objective tracker).
- Meeting UI (discussion/chat surface, call-meeting affordance).
- Voting UI (vote casting, tally reveal, result/ejection reveal).
- Meltdown UI (3-task tracker, Impostor interference feedback if relevant).
- Result screen (win/lose, role reveal, summary).

Key interfaces to other areas:
- Needs early API/event contracts from Backend to build against real state rather than
  mocked data.
- Coordinates with Content Design on exact task/evidence text and iconography.

### 2.5 Map & Environment Artist(s)
Responsibilities:
- Facility layout for the 9 suggested rooms (Cafeteria, Security Room, Laboratory, Server
  Room, Storage, Generator Room, Office, Medical Bay, ORION Core Chamber).
- Two lighting/visual states per relevant space: normal and blackout (emergency
  lighting), matching the reduced-visibility design intent.
- Visual treatment for sabotaged/damaged systems vs. functioning ones (so "still damaged
  despite claimed repair" evidence is visually legible on inspection).
- Interactable/prop placement in collaboration with Content Design (task stations,
  recovery system panels, restricted terminal for file theft, etc.).

Key interfaces to other areas:
- Delivers room layouts to `map_manager` (Backend) and to Client Programming for
  traversal/collision.

### 2.6 Audio
Responsibilities:
- Ambient loops: normal facility hum vs. blackout tension.
- Blackout activation stinger/countdown sound.
- Task completion, sabotage, and alarm/warning cues (e.g., classified files missing,
  meltdown alarm).
- Meeting call and voting result stingers.
- Meltdown countdown tension audio (escalating as timer approaches zero).

### 2.7 Production / QA
Responsibilities:
- Track MVP scope against `prd.md` §7 — flag anything trending toward the explicitly
  out-of-scope list (multiple maps, extra roles, cosmetics, etc.).
- Own the playtesting cadence needed to resolve config values (blackout duration, recovery
  threshold) — this is a joint effort with Content Design but needs a driver.
- Track resolution of the Open Questions list in `prd.md` §9 and make sure each has an
  owner and a decision date.
- Server-authority regression testing: verify no win-relevant state can be manipulated
  client-side (ties to NFR-2 in `prd.md`).

---

## 3. Minimum Viable Team (Small Team Guidance)

If the team is small (e.g., 3–5 people), a workable consolidation:

| Person/Pair | Combined Ownership |
|---|---|
| Engineer A | Backend / Game Systems (2.1) — full-time, do not split this role early |
| Engineer B | Client Programming (2.3) + basic UI implementation (2.4) |
| Designer | Content Design (2.2) + meeting/UI copy + QA/balance driving (2.7, design half) |
| Artist | Map & Environment Art (2.5) + Audio sourcing/integration (2.6), or bring in a contractor for audio |
| (Optional) Producer | Production/QA (2.7) full scope, or absorbed by Designer on very small teams |

**Do not split Backend/Game Systems across multiple people early in MVP** — the state
machine and server-authority model in `design.md` §2 and §6 is the connective tissue for
every other system, and fragmenting ownership here early tends to create integration
bugs across the state transitions (blackout unlock, recovery, meeting/vote, meltdown).

---

## 4. Sequencing Recommendation

Given the MVP scope in `prd.md` §7, a rough build order that lets areas unblock each other
as early as possible:

1. **Backend:** state machine skeleton + role assignment + task completion validation
   (unblocks everyone).
2. **Client + UI (parallel):** basic movement, task UI, role reveal — build against
   Backend's early event contracts.
3. **Backend:** blackout unlock/activation/timer + recovery system tracking.
4. **Content Design + UI (parallel):** author real task/objective content, blackout UI,
   sabotage UI.
5. **Backend:** evidence generation + meeting/voting.
6. **UI:** meeting/voting screens.
7. **Backend:** meltdown manager + win condition manager.
8. **UI:** meltdown UI + result screen.
9. **Art + Audio:** integrate throughout in parallel with above, prioritizing rooms/cues
   tied to whichever system is currently being built.
10. **QA/Production:** playtesting passes begin as soon as the full loop (step 1–8) is
    minimally connected end-to-end, even with placeholder art/audio — validating the loop
    matters more early than polish.

---

## 5. Open Ownership Questions

Carried over from `prd.md` §9 — these need an owner assigned during kickoff, not just a
decision:

- Platform target (affects Client Programming + Backend networking choice).
- Meeting trigger mechanism (Content Design decision, implemented by Backend + UI).
- Vote resolution rule (Content Design decision, implemented by Backend).
- Communication scope during blackout (Content Design + Backend joint decision).
- Disconnect/reconnect handling (Backend, with Production sign-off on acceptable MVP
  behavior).
- Engine/networking stack selection (Backend + Client Programming joint decision — this
  determines the final concrete file/module structure referenced in `design.md` §6.3).
