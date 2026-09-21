# Step 6: 8-Player Playtest & Regression System Review

**Reviewer:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Step:** Step 6 — 8-Player Playtest & Regression System  

---

## 1. Executive Summary

In Step 6, Member 8 established the **8-Player Playtest and Regression Documentation System** for BLACKOUT. Building on the audio foundation (Step 2), gameplay audio integration (Step 3), automated audio QA suite (Step 4), and server-authority QA suite (Step 5), this milestone provides a standardized, end-to-end smoke test checklist and regression management workflow for 8-player production testing.

All deliverables adhere strictly to Member 8's scope. No gameplay logic, networking code, server systems, or client UI belonging to Members 1–7 were modified, and existing project documents (including `PROJECT_STATUS.md`) were preserved without modification.

---

## 2. Existing Playtest Material Inspected

1. **`tests/playtest_checklists/playtest_checklist_8player.md`**:
   - Outlines pre-session setup (T-30 minutes), roster tracking, phase-by-phase checkpoints, qualitative feedback prompts, and post-match telemetry metrics.
2. **`tests/playtest_checklists/anti_cheat_test_matrix.md`**:
   - Details 14 server-authority threat vectors (TV-01 through TV-14) covering task spoofing, blackout gating, ghost voting, and meltdown repairs.
3. **`PRD.md` & `design.md`**:
   - Validated complete match loop: `LOBBY → ROLE_ASSIGNMENT → INITIAL_TASK_PHASE → BLACKOUT_AVAILABLE → BLACKOUT_ACTIVE → POST_BLACKOUT_INVESTIGATION → MEETING → VOTING → MELTDOWN → GAME_OVER`.
   - Verified Meltdown Protocol requirements: 5-minute fixed timer, 3 emergency tasks (*Restore Power*, *Restore Cooling*, *Stabilize ORION*), Impostor interference handling, and win/loss resolution.
4. **`TEAM_SPLIT.md`**:
   - Re-verified module ownership across all 8 team members to establish the authoritative defect routing table.

---

## 3. Deliverables Produced

### Primary Deliverable:
- **`docs/member-8/8-player-smoke-test.md`**:
  - Full 10-phase smoke test checklist covering:
    1. **CONNECTION:** Server launch, P1-P8 connection handshakes, lobby player count, stability/zero unexpected disconnects.
    2. **LOBBY:** Synchronized ready states, match countdown trigger on 8/8 ready, unique peer IDs.
    3. **ROLE ASSIGNMENT:** Strict 1 Impostor / 7 Crew distribution, private delivery, zero role leakage to client state/memory.
    4. **INITIAL TASK PHASE:** Crew tasks vs. Impostor prerequisites, station mini-game interactions, progress sync, rejection of invalid task actions.
    5. **BLACKOUT:** Prerequisite unlock gate, remote trigger, 3s countdown, power cut, emergency lighting & vision restrict shaders, recovery panels (3-of-4 threshold), timer decrement, and audio transitions.
    6. **POST-BLACKOUT:** Recovery/investigation state restoration, physical evidence persistence, duplicate trigger guards, audio return to standard ambience.
    7. **MEETING:** Emergency call/evidence report trigger, player teleport/conference lock, discussion timer, chat availability.
    8. **VOTING:** Single vote per alive player, skip option, rejection of invalid/duplicate/dead votes, synchronized plurality tally.
    9. **EJECTION:** Outcome display, elimination state update (`is_alive = false`), post-ejection pause, ejection stinger audio.
    10. **MELTDOWN & ENDGAME:** 5-minute authoritative timer (`300.0s`), 3 emergency stations, Impostor spectator vs. active sabotage handling, escalating klaxon audio, win/loss determination (Crew win on 3/3 repairs, Impostor win on timeout), victory/defeat fanfares, and match cleanup.

### Regression System Architecture:
- **Severity Classification Matrix:** Defined P0 (Blocker), P1 (Critical), P2 (Major), and P3 (Minor) with explicit impact criteria and resolution SLAs.
- **Responsible Member Routing Directory:** Explicit mapping of subsystems to Members 1 through 8 and their respective git branches.
- **Standard Defect Report Template:** Markdown format specifying environment, reproduction steps, expected vs. actual outcomes, server/client logs, and regression verification status.
- **Live Defect & Regression Log:** Seeded tracker with active defects across phases.

---

## 4. Strict Team Boundary Compliance

| Checkpoint | Status | Notes |
|---|---|---|
| Gameplay Mechanics Unmodified | **PASSED** | No changes to game state, tasks, blackout, voting, or meltdown code. |
| Networking & Server Unmodified | **PASSED** | No modifications to server managers, RPCs, or networking protocol. |
| Client Gameplay & UI Unmodified | **PASSED** | No edits to player controllers, mini-games, or HUD screens. |
| Existing Documents Preserved | **PASSED** | `PROJECT_STATUS.md` and `tests/playtest_checklists/` preserved without modification. |
| Defect Ownership Enforced | **PASSED** | All discovered or theoretical bugs are routed to responsible members in `docs/member-8/8-player-smoke-test.md`. |
| Documentation Scoped to Member 8 | **PASSED** | All artifacts created under `docs/member-8/`. |

---

## 5. Next Steps
- Maintain `docs/member-8/8-player-smoke-test.md` as the living operational gate for weekly 8-player playtest sessions.
- Ingest defect reports from playtesters and route them to Members 1–7.
- Prepare production milestone summaries as project integration advances.
