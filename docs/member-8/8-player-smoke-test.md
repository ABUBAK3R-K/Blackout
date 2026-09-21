# BLACKOUT — 8-Player Playtest Smoke Test & Regression Protocol

> **Document Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
> **Target Scope:** 8-Player Multiplayer Smoke Test & End-to-End Regression System  
> **Status:** Active QA Operational Standard  
> **Reference Docs:** [`PRD.md`](../../PRD.md), [`design.md`](../../design.md), [`TEAM_SPLIT.md`](../../TEAM_SPLIT.md), [`PROJECT_STATUS.md`](../../PROJECT_STATUS.md), [`tests/playtest_checklists/playtest_checklist_8player.md`](../../tests/playtest_checklists/playtest_checklist_8player.md)

---

## 1. Overview & Objective

This document defines the **formal 8-player smoke test checklist and regression tracking system** for BLACKOUT. It covers the full playable match lifecycle from authoritative server launch to match endgame screen, verifying client-server synchronization, state progression, role isolation, task mechanics, blackout triggers, meeting/voting flows, meltdown protocols, and audio cues.

### Core Testing Principles
1. **Zero Client Trust:** All match-critical state (roles, tasks, timer countdowns, votes, ejections, win conditions) is authoritative on the server.
2. **Deterministic Progression:** Matches advance strictly through defined state transitions without skipped phases or orphan state locks.
3. **Audio-State Fidelity:** Audio playback, transitions, crossfades, and stingers must accurately track their respective game states without pops, stalls, or orphaned loops.
4. **Strict Defect Routing:** In accordance with team boundaries, Member 8 does **not** fix foreign gameplay or backend defects. Defects are logged with reproduction steps and routed directly to the responsible module owner.

---

## 2. Test Environment Setup & Roster

### 2.1 Pre-Test Environment Verification
- [ ] Dedicated authoritative server build launched on host (default UDP/ENet port `7777`).
- [ ] 8 physical or virtual client instances deployed with identical build hash.
- [ ] Network latency verified across local subnet or tunnel (target: < 60ms ping, 0% packet loss).
- [ ] Master audio bus enabled on all clients with test headphones/speakers active.

### 2.2 8-Player Session Roster
| Seat | Client ID | Player Handle | Assigned Role (Post-Reveal) | Status / Notes |
|---|---|---|---|---|
| **P1** | Peer 1 (Host) | Lead_Tester | | |
| **P2** | Peer 2 | Tester_Bravo | | |
| **P3** | Peer 3 | Tester_Charlie | | |
| **P4** | Peer 4 | Tester_Delta | | |
| **P5** | Peer 5 | Tester_Echo | | |
| **P6** | Peer 6 | Tester_Foxtrot | | |
| **P7** | Peer 7 | Tester_Golf | | |
| **P8** | Peer 8 | Tester_Hotel | | |

---

## 3. End-to-End 8-Player Smoke Test Checklist

### 3.1 CONNECTION
```text
[ ] Server starts
[ ] Player 1 connects
[ ] Players 2–8 connect
[ ] All 8 players appear in the lobby
[ ] No unexpected disconnects
```
**Verification Notes:**
- Confirm server output logs `Server started on port 7777`.
- Verify clients register unique peer IDs upon handshake.
- Confirm lobby player count indicator reads exactly `8 / 8`.
- Ensure heartbeat loop maintains connection without timeout disconnects during idle wait.

---

### 3.2 LOBBY
```text
[ ] All players can ready
[ ] Match starts correctly
[ ] No duplicate player IDs
[ ] Player states are synchronized
```
**Verification Notes:**
- Each player clicks `READY`; verify checkmark / status updates across all 8 clients.
- Verify match start countdown initiates only when 8 of 8 players are marked `READY`.
- Check server roster dictionary to confirm exactly 8 distinct peer IDs with zero key collision.
- Audio check: UI button click sounds trigger cleanly; lobby ambient music remains smooth.

---

### 3.3 ROLE ASSIGNMENT
```text
[ ] Exactly 1 Impostor
[ ] Exactly 7 Crew
[ ] Each player receives only their own role
[ ] No role leakage through client state
```
**Verification Notes:**
- Server executes private role delivery via direct RPCs to individual peer IDs.
- Confirm post-match roster verification reveals strictly 1 Impostor and 7 Crew members.
- Inspect client memory / debug inspectors across all 7 Crew clients to verify Impostor peer ID is completely absent from local memory.
- Audio check: Role reveal card displays with role-specific musical sting (dissonant ominous chord for Impostor, steady resolute tone for Crew).

---

### 3.4 INITIAL TASK PHASE
```text
[ ] Crew tasks appear correctly
[ ] Impostor prerequisites appear correctly
[ ] Task interactions work
[ ] Task completion is synchronized
[ ] Invalid task actions are rejected
```
**Verification Notes:**
- Crew task list displays normal facility tasks (Power routing, calibration, coolant scan).
- Impostor displays distinct, faster prerequisite task list (Terminal check, scan, subsystem probe).
- Players interact with assigned `InteractableStation` nodes; mini-game dialogues pop up reliably.
- Task completion broadcasts progress updates to the server; global Crew progress bar increments.
- Injected client packets for unassigned tasks or spoofed completions are rejected by the server.
- Audio check: Facility ambient drone hums consistently; station interaction clicks and mini-game completion chimes play on trigger.

---

### 3.5 BLACKOUT
```text
[ ] Blackout prerequisite is respected
[ ] Blackout starts correctly
[ ] Blackout audio starts
[ ] Normal ambience transitions correctly
[ ] Emergency audio works
[ ] Blackout timer behaves correctly
[ ] Players see correct blackout state
[ ] Blackout ends correctly
```
**Verification Notes:**
- Server blocks `request_trigger_blackout` until all Impostor prerequisite tasks are confirmed complete.
- When triggered, a 3-second countdown warning broadcast displays on all client screens.
- Power cuts simultaneously: facility lighting drops to emergency levels; player vision radius restricts.
- Camera and non-essential facility stations disable as designed.
- Server countdown timer ticks downward reliably.
- Distributed recovery panels (4 stations) become active; early recovery threshold (3 of 4 repaired) terminates blackout ahead of timer.
- Blackout terminates normally if timer reaches zero.
- Audio check:
  - 3-second warning beeps fire.
  - Heavy power breaker cutoff thump triggers at `t = 0`.
  - Normal room ambience crossfades cleanly into high-tension blackout drone without audio pops or clipping.
  - Emergency alarm sirens/strobe audio audible near key junctions.

---

### 3.6 POST-BLACKOUT
```text
[ ] Recovery/investigation state works
[ ] Players can continue gameplay
[ ] No duplicated blackout events
[ ] Audio returns to correct state
```
**Verification Notes:**
- Full facility lighting and standard vision radius restore immediately upon blackout end.
- Impostor sabotage markers / evidence flags (missing files, damaged relays) remain in the environment for Crew investigation.
- Server verifies blackout state transitions to `POST_BLACKOUT_INVESTIGATION`; duplicate trigger requests are ignored and logged.
- Audio check: Tension drone fades out; standard facility hum smoothly fades back in.

---

### 3.7 MEETING
```text
[ ] Meeting starts
[ ] Meeting audio plays
[ ] Discussion phase works
[ ] Voting phase starts
```
**Verification Notes:**
- Emergency meeting called via central table button or evidence report.
- All 8 players are locked into the meeting conference UI.
- Discussion countdown clock displays identically across all clients.
- In-game text chat allows communication between all alive players; dead players (if any) are muted or restricted to spectator chat.
- Discussion timer transition cleanly unlocks the voting interface.
- Audio check: Emergency klaxon meeting stinger fires on transition; discussion background tension loop begins.

---

### 3.8 VOTING
```text
[ ] All eligible players can vote
[ ] Invalid votes are rejected
[ ] Duplicate votes are rejected
[ ] Voting closes correctly
[ ] Result is synchronized
```
**Verification Notes:**
- Each living player can cast exactly one vote for a candidate or select `SKIP`.
- Server rejects votes cast for non-existent peer IDs, eliminated players, or votes sent outside the voting window.
- Duplicate vote RPCs from the same client within the same round are dropped.
- Voting concludes either when all alive players have submitted votes OR when the voting timer reaches zero.
- Vote tallies and plurality/majority determination are computed authoritatively by the server and broadcast simultaneously.
- Audio check: Clock ticking rhythm intensifies in the final 10 seconds of voting; vote submission click confirms player action.

---

### 3.9 EJECTION
```text
[ ] Ejection result is displayed
[ ] Ejection audio plays
[ ] Correct player state is maintained
```
**Verification Notes:**
- Meeting screen displays ejection cinematic / message:
  - If a player received plurality: `[Player Name] was ejected.`
  - If tie or majority skipped: `No one was ejected. (Tie / Skipped)`.
- If a player was ejected:
  - Server sets `player.is_alive = false`.
  - Ejected player is disqualified from voting or performing physical blocking actions.
- Post-ejection state holds for 5 seconds before advancing to Meltdown.
- Audio check: Ejection outcome stinger fires (dramatic reveal chord; separate sting for tie/skip).

---

### 3.10 MELTDOWN & ENDGAME
```text
[ ] Meltdown starts when appropriate
[ ] 5-minute timer starts
[ ] Emergency repair stations activate
[ ] Impostor behavior respects ejection status
[ ] Meltdown audio escalates correctly
[ ] Win condition evaluates accurately
[ ] Victory/Defeat stinger audio plays
[ ] Match cleanup completes cleanly
```
**Verification Notes:**
- Meltdown initiates immediately following meeting/ejection resolution (ORION core instability reaches critical threshold).
- Server-authoritative 5-minute countdown (`300.0s`) begins and syncs to all client HUDs.
- Exactly 3 critical emergency stations activate:
  1. *Restore Power*
  2. *Restore Cooling*
  3. *Stabilize ORION Core*
- Impostor behavior validation:
  - If Impostor was **ejected**: Client is locked in spectator/ghost mode; cannot sabotage or repair stations.
  - If Impostor was **spared/not ejected**: Client can physically move, jam doors, and attempt secondary sabotage to delay Crew repairs.
- Server validates that only living Crew members can complete emergency repair interactions.
- Win/Loss condition evaluation:
  - **Crew Victory:** Triggered if all 3 emergency stations are restored before timer reaches 0.0s.
  - **Impostor Victory:** Triggered if meltdown timer expires before 3/3 stations are restored.
- End-of-match victory/defeat screen displays with complete role reveal.
- Audio check:
  - Meltdown warning siren engages.
  - Klaxon audio increases in tempo and pitch as the timer drops below 60s and 30s.
  - Victory fanfare triggers on Crew win; ominous defeat stinger triggers on Impostor win.
  - All looping audio stops cleanly upon match finalization.

---

## 4. Defect & Regression Management System

When a smoke test or automated test exposes an unexpected failure, performance bottleneck, or desync, the QA tester must document the issue without modifying the affected system.

### 4.1 Severity Classification Matrix
| Severity Level | Definition | Match Impact | SLA / Priority |
|---|---|---|---|
| **P0 — Blocker** | Game crash, server freeze, client deadlock, or fatal desync preventing match continuation. | Match cannot complete; all testing halted. | Immediate fix required. |
| **P1 — Critical** | Authoritative security breach, role leak, broken win condition, or non-functional major phase (e.g. Blackout fails to end). | Match completes with illegitimate results. | Fix before next playtest session. |
| **P2 — Major** | Station mini-game glitch, timer drift > 2s, audio looping bug, camera clipping, or voting UI desync. | Workaround possible; degraded player experience. | Scheduled in active sprint. |
| **P3 — Minor** | Typo, minor asset misalignment, cosmetic HUD jitter, or slight audio volume imbalance. | Cosmetic or trivial; zero gameplay impact. | Backlog polish. |

---

### 4.2 Responsible Member Routing Directory
Direct all defect tickets to the designated subsystem owner in accordance with [`TEAM_SPLIT.md`](../../TEAM_SPLIT.md):

| Subsystem Domain | Modules Owned | Responsible Member | Branch Target |
|---|---|---|---|
| **Server Core & Network Protocol** | Server lifecycle, peer connections, room roster, role manager, network RPC dispatch, anti-cheat validation | **Member 1 (Mayiz)** | `member-1/backend-network` |
| **Gameplay Backend Logic** | Task manager, blackout manager & recovery thresholds, sabotage/evidence logic, meeting & voting resolution, meltdown timer & win conditions | **Member 2 (Abdul Qadir)** | `member-2/gameplay-backend` |
| **Client Engine & Vision** | Client player controller, camera tracking, blackout vision restriction shader, map manager & tilemap rendering | **Member 3 (Aaliya)** | `member-3/client-engine` |
| **Mini-Games & Interactions** | Crew station mini-games, Impostor prerequisite tasks, station interactable prompts, completion handshakes | **Member 4 (Ubaid)** | `member-4/mini-games` |
| **UI / UX & Frontend HUD** | Role reveal UI, task list HUD, blackout timer overlay, meeting conference UI, voting screen, meltdown alerts, endgame screen | **Member 5 (Shahzan)** | `member-5/ui-frontend` |
| **Game Design & Balance** | Timer durations (blackout, meltdown, meeting), task distribution, recovery thresholds, balance JSON configs | **Member 6 (Abubaker)** | `member-6/game-design` |
| **2D Environment & Lighting** | Station sprites, room art, normal/emergency lighting states, blackout visual effects | **Member 7 (Fatima)** | `member-7/environment-art` |
| **Audio & QA Automation** | Audio manager, bus mixing, sound FX / ambience loops, automated test suites, playtest coordination | **Member 8 (Sahil)** | `member-8/audio-qa` |

---

### 4.3 Standard Defect Report Template
```markdown
### [DEFECT-ID] <Concise Title Describing Problem>
- **Date Reported:** YYYY-MM-DD
- **Reporter:** <Name / Member ID>
- **Severity:** [P0 - Blocker | P1 - Critical | P2 - Major | P3 - Minor]
- **Phase / Subsystem:** [Connection | Lobby | Roles | Tasks | Blackout | Meeting | Voting | Meltdown | Audio]
- **Assigned Module Owner:** <Member Name & Branch>
- **Environment:** Dedicated Server (Port 7777), 8 Clients, Commit Hash: `<hash>`

#### 1. Description
<Clear explanation of what happened versus what was expected.>

#### 2. Steps to Reproduce
1. Launch authoritative server on port 7777.
2. Connect 8 clients and ready up.
3. Advance to <Phase>.
4. Execute action: <action details>.
5. Observe failure: <failure details>.

#### 3. Expected Behavior
<Description of correct gameplay, network state, or audio playback.>

#### 4. Actual Behavior
<Description of actual failure, console log warning, or visual defect.>

#### 5. Logs & Artifacts
```text
<Paste server/client console output, error stacks, or packet inspection logs here>
```

#### 6. Regression Verification
- **Fixed In Commit:** `<commit-hash>`
- **Verified By:** Member 8 (Sahil)
- **Resolution Status:** [Open | In Progress | Resolved | Verified Closed]
```

---

## 5. Live Defect & Regression Log

| Defect ID | Severity | Phase | Brief Description | Assigned To | Status |
|---|---|---|---|---|---|
| **DEF-01** | P2 - Major | Blackout | Ambient tension loop pops during loop restart on low-spec client | Member 8 (Sahil) | Resolved |
| **DEF-02** | P2 - Major | Voting | Vote tally summary UI renders 0.5s prior to voting countdown reaching zero | Member 5 (Shahzan) | Open |
| **DEF-03** | P1 - Critical | Meltdown | Impostor client able to send interaction RPCs while in ejected state | Member 2 (Abdul Qadir) | Open |
| **DEF-04** | P3 - Minor | Meeting | Meeting chat input box does not automatically capture focus on transition | Member 5 (Shahzan) | Open |
| **DEF-05** | P2 - Major | Initial Tasks | Subsystem calibration task station prompt remains visible after task completion | Member 4 (Ubaid) | Open |

---

## 6. Playtest Sign-Off Criteria (Milestone Gate)

Before an MVP release build is certified for release or stakeholder demonstration:
1. **100% Smoke Test Pass:** All 10 phases of Section 3 must pass in a live 8-player session with zero P0 or P1 defects.
2. **Anti-Cheat Validation:** The 14 threat vectors in [`anti_cheat_test_matrix.md`](../../tests/playtest_checklists/anti_cheat_test_matrix.md) must maintain passing status in automated test suites.
3. **Audio Integrity:** Audio bus levels must remain within safe headroom (-6dB master limit) without clipping, dropped channels, or stutter.
4. **Sign-Off Recorded:** Member 8 logs final session duration, telemetry metrics, and approval in `PROJECT_STATUS.md`.
