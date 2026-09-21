# Step 5: Server-Authority QA Review

**Reviewer:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Step:** Step 5 — Server-Authority QA  

---

## Tests Added

1. **`tests/server_authority_tests/test_anti_cheat_roles.gd`** (7 Test Cases)
   - Test 1: Role assignment requires exactly 8 players; rejected with fewer players or during LOBBY.
   - Test 2: Server-authoritative role distribution guarantees exactly 1 Impostor and 7 Crew members.
   - Test 3: Client tampering with local role cannot trigger Blackout (server checks `impostor_peer_id` authoritatively).
   - Test 4: Client cannot claim Impostor sabotage privileges or complete hidden objectives without server Impostor role.
   - Test 5: Malformed / out-of-range role values (`-1`, `999`) handled safely by `NetworkConfig`.
   - Test 6: Redundant role reassignment (`assign_roles()`) strictly blocked once match enters `INITIAL_TASK_PHASE`.
   - Test 7: Authoritative player role record on server is immutable to unauthorized client manipulation.

2. **`tests/server_authority_tests/test_anti_cheat_timers.gd`** (8 Test Cases)
   - Test 1: Blackout timer decrement is exclusively controlled by server `BlackoutManager.tick()`.
   - Test 2: Meltdown 5-minute timer cannot be altered or reset by clients; only server `MeltdownManager.tick()` decrements it.
   - Test 3: Discussion and voting timers are server-clocked and locked outside active meeting phases.
   - Test 4: Unexpected client socket disconnection during active gameplay handled gracefully without crashing the server.
   - Test 5: Malformed, empty, and path-traversal task identifiers (`../../etc/passwd`, `""`, `"null"`) rejected safely.
   - Test 6: Invalid voting targets (negative `-1`, out-of-range `99999`) rejected safely by `VotingManager`.
   - Test 7: Non-existent recovery subsystem identifiers (`fake_reactor_core`) safely rejected.
   - Test 8: Malformed Impostor sabotage requests (`destroy_entire_facility`) safely rejected.

3. **`tests/run_all_tests.gd` Manifest Update:**
   - Registered `qa_anti_cheat_roles` (7 tests) and `qa_anti_cheat_timers` (8 tests) in the master test runner manifest.

---

## Existing Tests Reused

The existing server-authority test suites authored in earlier Member 8 passes were inspected and integrated into the overall QA verification matrix:
1. **`tests/server_authority_tests/test_anti_cheat_tasks.gd`** (6 Test Cases)
   - Task spoofing, non-assigned peer task completion, dead player completion, out-of-phase completion, duplicate submissions, and Impostor crew-task block.
2. **`tests/server_authority_tests/test_anti_cheat_blackout.gd`** (6 Test Cases)
   - Crew blackout trigger rejection, Impostor prerequisite gating, active blackout lock, recovery panel authorization, duplicate recovery submissions, and 3-of-4 recovery threshold enforcement.
3. **`tests/server_authority_tests/test_anti_cheat_voting.gd`** (5 Test Cases)
   - Out-of-phase voting rejection, dead player vote rejection, invalid target rejection, double-vote rejection, and emergency meeting cooldown/phase guards.
4. **`tests/server_authority_tests/test_anti_cheat_meltdown.gd`** (6 Test Cases)
   - Impostor emergency system rejection, eliminated crew rejection, out-of-phase emergency system rejection, unknown emergency system rejection, duplicate submission rejection, and post-match lockdown.

Total Server-Authority QA Inventory: **6 dedicated test suites, 38 targeted vulnerability checks**.

---

## Role Authority Results

- **Static Contract Verification:**
  - `ServerNetworkManager.assign_roles()` executes strictly on the server and sets `connected_players[pid].role`.
  - Roles are transmitted privately via `send_private_role(pid, role)` — the global role mapping is never broadcast to clients.
  - All subsequent privileged actions (e.g. `process_blackout_activation_request`, `process_recovery_request`) verify `get_player_data(peer_id).role` directly from the server's internal memory dictionary. Local client property mutation on `ClientNetworkManager.assigned_role` has zero effect on server decisions.
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Task Authority Results

- **Static Contract Verification:**
  - `TaskManager.complete_task(peer_id, task_id)` verifies:
    1. Player is alive (`player.is_alive == true`).
    2. Task is assigned to that specific `peer_id` (`assigned_tasks.has(task_id)`).
    3. Task is not already completed (`not completed_tasks.has(task_id)`).
    4. Current game state permits task completion (Crew tasks allowed in `INITIAL_TASK_PHASE`, `BLACKOUT_AVAILABLE`, `BLACKOUT_ACTIVE`; Impostor tasks restricted to `INITIAL_TASK_PHASE`).
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Voting Authority Results

- **Static Contract Verification:**
  - `VotingManager.cast_vote(voter_peer_id, target_peer_id, current_state, is_alive)` verifies:
    1. Match is in `GameState.VOTING`.
    2. Voter is alive (`is_alive == true`).
    3. Voter has not already voted in the current round (`not votes.has(voter_peer_id)`).
    4. Target is a valid connected player or `0` (Skip Vote).
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Blackout Authority Results

- **Static Contract Verification:**
  - `BlackoutManager.request_activation(peer_id, current_state)` verifies:
    1. `peer_id == impostor_peer_id`.
    2. `is_unlocked == true` (all prerequisite tasks verified complete on server).
    3. Match is in `GameState.BLACKOUT_AVAILABLE`.
    4. Not currently on countdown or active blackout.
  - `BlackoutRecoveryManager.request_recover_system()` verifies that early termination occurs strictly when `completed_count >= required_count` (3 of 4 systems).
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Timer Authority Results

- **Static Contract Verification:**
  - Clients possess zero network RPCs or commands to modify server timers.
  - `BlackoutManager.tick(delta)`, `MeetingManager.tick(delta)`, and `MeltdownManager.tick(delta)` run exclusively in `ServerNetworkManager._process(delta)`.
  - Timer expiration triggers state transitions deterministically on the server.
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Disconnect/Reconnect Results

- **Static Contract Verification:**
  - `ServerNetworkManager._on_peer_disconnected(peer_id)` cleans up connection state and emits `player_disconnected(peer_id, slot)`.
  - The server state machine continues processing without throwing unhandled exceptions.
  - Mid-match session rehydration / reconnection is not yet implemented in the MVP networking layer (see `PRD.md` Open Question #5).
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## Malformed Request Results

- **Static Contract Verification:**
  - Server managers employ defensive input validation:
    - Empty string and path traversal strings (`""`, `"../../"`) fail dictionary key lookups in `task_catalog` and `recovery_systems`.
    - Negative and out-of-range peer IDs (`-1`, `99999`) fail `connected_players.has(peer_id)` guards.
- **Classification:** **BLOCKED** (Runtime execution blocked by environment tooling).

---

## PASS

- **None.**  
  *(In strict compliance with Prompt Rule 9: "A test is PASS only if you actually executed it and verified the expected result. If Godot is unavailable, mark the test BLOCKED. Do not mark it PASS.")*

---

## FAIL

- **None.**  
  *(No assertion failures were detected during static contract analysis. No code defects were identified in server validation routines.)*

---

## BLOCKED

All 38 server-authority test cases across the 6 test suites are classified as **BLOCKED**:
1. `tests/server_authority_tests/test_anti_cheat_roles.gd` (7 tests) — **BLOCKED**
2. `tests/server_authority_tests/test_anti_cheat_timers.gd` (8 tests) — **BLOCKED**
3. `tests/server_authority_tests/test_anti_cheat_tasks.gd` (6 tests) — **BLOCKED**
4. `tests/server_authority_tests/test_anti_cheat_blackout.gd` (6 tests) — **BLOCKED**
5. `tests/server_authority_tests/test_anti_cheat_voting.gd` (5 tests) — **BLOCKED**
6. `tests/server_authority_tests/test_anti_cheat_meltdown.gd` (6 tests) — **BLOCKED**

**Reason:** The Godot 4 console binary is not present in the Windows system PATH in this CLI environment. Headless runtime execution (`godot --headless -s ...`) could not be initiated.

---

## NOT APPLICABLE

- **Full Mid-Match Client Reconnection Rehydration:** Marked **NOT APPLICABLE** for MVP. The current networking architecture treats mid-match disconnection as an active player drop without a session-token resumption protocol (deferred to Post-MVP per `PRD.md` §9 Open Question #5).

---

## Responsible Systems for Failures

- **None.** No runtime or logic failures were identified within other members' systems during static contract inspection.

---

## Files Modified

1. **`tests/run_all_tests.gd`**  
   - Registered `qa_anti_cheat_roles` and `qa_anti_cheat_timers` in the master test runner manifest.

## Files Created

1. **`tests/server_authority_tests/test_anti_cheat_roles.gd`**  
   - 7 role authority test cases.
2. **`tests/server_authority_tests/test_anti_cheat_timers.gd`**  
   - 8 timer, disconnect, and malformed input test cases.
3. **`docs/member-8/reviews/step-5-server-authority-qa-review.md`**  
   - (This review document).

---

## Team Boundary Verification

Verified via `git status` that zero files belonging to Members 1–7 were modified:
- `server/` (Members 1 & 2) — UNTOUCHED
- `client/player/`, `client/rendering/` (Member 3) — UNTOUCHED
- `client/interactions/` (Member 4) — UNTOUCHED
- `client/ui/` (Member 5) — UNTOUCHED
- `design/specs/`, `config/` (Member 6) — UNTOUCHED
- `scenes/environment/`, `assets/sprites/` (Member 7) — UNTOUCHED
- `shared/` (Members 1 & 2) — UNTOUCHED
- `project.godot` — UNTOUCHED
- User changes to `PROJECT_STATUS.md` — PRESERVED UNTOUCHED

---

## Final QA Summary

Member 8 has completed the server-authority anti-cheat testing suite inventory. With the addition of `test_anti_cheat_roles.gd` and `test_anti_cheat_timers.gd`, the project now possesses comprehensive automated test suites covering all 5 core server authority domains (Roles, Tasks, Voting, Blackout, Timers) plus input validation and disconnect resilience.

All test suites conform directly to the repository's headless SceneTree loopback socket architecture and are registered in `tests/run_all_tests.gd`. When executed in an environment with the Godot 4 executable installed, these suites will authoritatively validate the game against client-side exploitation.
