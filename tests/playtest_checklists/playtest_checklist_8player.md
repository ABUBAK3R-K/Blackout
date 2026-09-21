# BLACKOUT — 8-Player Playtest Operational Checklist & Protocol

> **Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
> **Target Target Cadence:** Weekly 8-Player Production Sessions  
> **Companion Docs:** [`TEAM_SPLIT.md`](../../TEAM_SPLIT.md), [`PROJECT_STATUS.md`](../../PROJECT_STATUS.md), [`PRD.md`](../../PRD.md)

---

## 1. Pre-Session Checklist (T-30 Minutes)

### Environment & Server Readiness
- [ ] Dedicated authoritative server instance launched on host machine (`port 7777` default).
- [ ] Host ping & packet loss verified across local network or VPN tunnel (< 60ms latency, 0% packet loss).
- [ ] Verify `game_balance_config.json` or shared config constants are aligned with current milestone values:
  - Blackout duration: `30.0s` (or milestone configured duration)
  - Recovery threshold: `3 of 4` systems
  - Meltdown duration: `300.0s` (5 minutes)
- [ ] All 8 client instances running identical client build versions.
- [ ] Master audio bus and output levels verified (headphones recommended for spatial/ambient testing).

### Player Roster Verification (8 Players)
| Seat | Player Name | Assigned Client ID | Discord / Audio Handle | Role Observed (Post-Match) |
|---|---|---|---|---|
| 1 | Host / Lead | Peer 1 | | |
| 2 | Tester 2 | Peer 2 | | |
| 3 | Tester 3 | Peer 3 | | |
| 4 | Tester 4 | Peer 4 | | |
| 5 | Tester 5 | Peer 5 | | |
| 6 | Tester 6 | Peer 6 | | |
| 7 | Tester 7 | Peer 7 | | |
| 8 | Tester 8 | Peer 8 | | |

---

## 2. In-Match Protocol by Phase

### Phase 1: Lobby & Ready-Up
- [ ] All 8 players connect to the lobby room.
- [ ] Verify player list displays all 8 connected usernames without desync.
- [ ] Each player presses `READY`.
- [ ] Verify match countdown initiates strictly when all 8 players are ready.
- [ ] **Audio Check:** Lobby UI click SFX audible; lobby background ambience playing.

### Phase 2: Role Assignment & Secret Reveal
- [ ] Role reveal card displays privately on each client screen.
- [ ] Verify exactly **1 Impostor** and **7 Crew** assigned (confirm during post-game debrief).
- [ ] Verify zero visual or audio leakage of Impostor identity to other players.
- [ ] **Audio Check:** Role reveal musical chord fires with proper role-specific tone.

### Phase 3: Initial Task Phase & Prerequisite Completion
- [ ] Crew members receive assigned task checklist; Impostor receives prerequisite tasks.
- [ ] Players navigate to task stations across the 9 facility rooms.
- [ ] Verify interaction prompts and mini-game completion handshakes.
- [ ] Observe Impostor completing prerequisite tasks without detection.
- [ ] **Audio Check:** Facility hum ambient loop active; task interaction clicks and success chimes trigger on completion.

### Phase 4: Blackout Initiation & Distributed Recovery
- [ ] Impostor receives `BLACKOUT READY` prompt and activates remote blackout.
- [ ] Verify 3-second blackout countdown warning displays and power cuts.
- [ ] Vision radius restricts immediately; emergency lighting shaders engage.
- [ ] Recovery panels activate; verify live `X/Y` progress updates as Crew repairs panels.
- [ ] Verify blackout terminates immediately upon reaching 3-of-4 recovery threshold OR upon timer expiration.
- [ ] **Audio Check:** Blackout countdown beeps, heavy power cutoff thump, and tense atmospheric drone engage smoothly.

### Phase 5: Sabotage, Evidence & Investigation
- [ ] Impostor executes secondary sabotage actions (file theft, core extraction, door jamming).
- [ ] Verify physical evidence markers spawn at sabotage sites.
- [ ] Crew inspects markers; verify evidence discovery logs.
- [ ] **Audio Check:** Sabotage execution audio audible only to proximity/performer; evidence inspection chime fires.

### Phase 6: Emergency Meeting & Voting
- [ ] Emergency button pressed or body/evidence reported.
- [ ] All players teleported/locked to meeting conference screen.
- [ ] Voting timer begins; verify vote selection and skip button.
- [ ] Verify vote tallies, tie handling, and ejection sequence.
- [ ] **Audio Check:** Meeting emergency siren alarm stinger; voting countdown clock ticking; ejection reveal sting.

### Phase 7: Meltdown Protocol & Endgame
- [ ] Match transitions to 5-minute Meltdown state.
- [ ] 3 emergency stations active: *Restore Power*, *Restore Cooling*, *Stabilize ORION*.
- [ ] Verify Impostor interference attempts and Crew repair coordination.
- [ ] Verify win condition triggers correctly:
  - 3/3 Emergency Systems Restored -> **Crew Victory**
  - Timer expires <= 0.0s -> **Impostor Victory**
- [ ] Match locks down into `GAME_OVER`.
- [ ] **Audio Check:** Escalating Meltdown klaxon increases pitch and intensity as timer decreases; victory/defeat fanfare fires.

---

## 3. Post-Match Balance & Quality Debrief

### Session Metrics
- **Match Winner:** `[ Crew / Impostor ]`
- **Win Reason:** 
- **Total Match Duration:** `___ min ___ sec`
- **Meltdown Time Remaining at Victory:** `___ sec`
- **Tasks Completed by Crew:** `___ / ___`
- **Evidence Markers Discovered:** `___ / ___`

### Qualitative Feedback Prompts
1. *Did the Blackout feel terrifying yet survivable for Crew?*
2. *Were evidence clues clear enough to spark meaningful debate during the meeting?*
3. *Did any audio cue feel too loud, missing, or mistimed?*
4. *Did any player experience lag, rubberbanding, or desynced task state?*

---

## 4. Defect & Regression Log
| Issue ID | Severity | Phase | Description | Suspected Owner | Status |
|---|---|---|---|---|---|
| REG-01 | Minor | Blackout | Ambient crossfade had a slight audible pop on loop reset | Member 8 | Resolved |
| REG-02 | Medium | Meeting | Vote tally displayed 0.5s before clock zero | Member 5 | Open |
