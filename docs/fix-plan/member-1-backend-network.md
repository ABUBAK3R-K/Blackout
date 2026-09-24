# Member 1 — Mayiz — Lead Backend & Network Engineer · Fix Guide

**Branch:** `member-1/backend-network` · **You are on the critical path.** Everyone else codes against your contract stubs (Step 1), so land that first.
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** C1, C2 (server), C3 (transitions), C4, C5 (wiring), C6, C7 (network API), H1, H2, H3, H4, H5, H6, H7, I4 (server check), F1, F6 (plumbing), F8, F10, F11

---

## 1. Your files (you may edit)
- `shared/network_manager.gd` (the autoload: all RPCs)
- `server/server_network_manager.gd` (the server hub)
- `client/client_network_manager.gd`
- `shared/network_config.gd`
- `shared/player_connection_data.gd`
- `shared/role_manager.gd`
- `shared/round_manager.gd`, `shared/sabotage_manager.gd` (you remove them from the flow and later delete them)
- `project.godot` (autoloads, main scene: edit on request from M5/M8)
- **New:** `scenes/server_console.tscn` + `scenes/server_console.gd`
- Your paired tests:
  - `tests/test_multiplayer_server.gd`
  - `tests/test_lobby_system.gd`
  - `tests/test_role_assignment.gd`
  - `tests/test_return_to_lobby_rematch.gd`
  - `tests/test_kill_and_body_reporting.gd` (tell M3 when you change it)

## 2. Not yours (write a handoff note instead of editing)
- `server/*_manager.gd` except the hub, and `shared/*_config.gd` / `*_definition.gd` / `balance_config.gd` → **M2**
- `shared/station_registry.gd`, `config/*.json` → **M6**
- Everything under `client/` except `client_network_manager.gd` → M3/M4/M5/M8
- `tests/server_authority_tests/`, `tests/run_all_tests.gd` → **M8**

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| `shared/station_registry.gd` (at least IDs + positions + `SPAWN_POINTS`) | M6, Wave 0 | 6, 7 |
| `BalanceConfig` loader with `set_override` | M2, Wave 1 | 5, 6, 7, 8 (use the literal defaults from contracts §5 until it lands) |
| `MeetingManager` investigation API, `resolve_now()`, `MeltdownManager.request_disrupt()`, EvidenceManager marker API, door selection | M2 | 10, 11 |
| M3 has switched Q → `request_activate_blackout` and removed Sabotage/Round refs | M3, Wave 2 | 12 |

| Others need from you | Step |
|---|---|
| Contract stubs (everyone) | **1** |
| Hosting API (M5 menu) | 9 |
| Handshake + `action_rejected` (M4 stations, M5 toasts) | 7, 8 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 0 | Contract stubs: enums, RPC endpoints, client signals/methods, payload fields | enables all |
| 2 | 1 | Truly random Impostor | C1 |
| 3 | 1 | One state machine + transition table; stop the sabotage bypass | C2, C3, C4, H5 |
| 4 | 1 | Public state (hide BLACKOUT_AVAILABLE from Crew) + client task gating | C6 |
| 5 | 1 | Kill/report feature flag + range bypass | H1, H2 |
| 6 | 1 | Server position authority + spawn + `rpc_correct_position` | H2 |
| 7 | 1 | Interaction handshake (begin → complete) | I4, D12 |
| 8 | 1 | Names, chat, timer sync, `action_rejected` everywhere | F1, F8, F10, F11 |
| 9 | 1 | Hosting: `host_game` / `join_game` / `--server` | C7 |
| 10 | 1 | Disconnect policy, full reset on stop, game-over roster, no private calls | H3, H4, H6, H7 |
| 11 | 2 | Plumbing for M2's mechanics: investigation timer, evidence markers/inspect, doors, disruption, instability | C5, H9, F4–F6 |
| 12 | 2 end | Delete deprecated RPCs + RoundManager/SabotageManager | C2, H5 |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my coding agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 1 (Mayiz), Lead Backend & Network Engineer. My branch is member-1/backend-network.

Before writing any code:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md, docs/fix-plan/member-1-backend-network.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-1/backend-network or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) anything in the contracts that looks inconsistent with the current code. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY the files listed under "Your files" in my guide. If a fix needs a change in another member's file, stop and write the exact change as a handoff note. Do not edit it.
- Implement names, signatures, payloads and IDs EXACTLY as in 01-integration-contracts.md. If the contract is wrong or missing something, stop and tell me. Never invent an alternative interface.
- Never call another class's underscore-prefixed (private) method. Never set game state directly in tests.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show me the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session.
- Minimal changes in the existing code style. No speculative features.
- After each step: list the changed files, show test output, and draft a PROJECT_STATUS.md §7 change-log entry dated today that cites the audit IDs. Do not commit unless I say so.
```

---

### Step 1 — Contract stubs (Wave 0) — *land within 2 days*
**Goal:** every new name in the contracts exists and compiles, so M3/M4/M5/M8 can code against it today. Server handlers can still be "not implemented".

**Do**
1. `network_config.gd`: add `TimerId`, `InteractionKind`, `LEGAL_TRANSITIONS`, `is_legal_transition()` and `public_state_for()` (contracts §2, §3).
2. `player_connection_data.gd`: add `display_name` (default `"Player %d" % slot`) and `color_index` (= slot − 1) to the fields and to `to_dict()` / `from_dict()`. Still no `role`.
3. `network_manager.gd`: add every **new** RPC from contracts §7 with the exact signature.
   - C→S endpoints forward to new `server.process_*` methods.
   - S→C endpoints forward to new `client.handle_*` methods.
   - Add the server-side senders (`send_action_rejected(peer, action, code, msg)`, `broadcast_timer(...)`, etc.).
4. `server_network_manager.gd`: add the `process_*` methods. For now each returns `{"success": false, "error": "not implemented"}` **and** sends `rpc_action_rejected(action, "invalid", "not implemented")`.
5. `client_network_manager.gd`: add all §9 methods, signals, state vars and helpers. The `handle_*` functions store the data and emit the signal. Reset everything in `reset_match_state()` / `_cleanup_connection()`.
6. `NetworkManager`: add `host_game`, `join_game`, `leave_game`, `is_dedicated_server` (a simple version is fine now; Step 9 finishes it).

**Done when:** the project imports with no parse errors; all existing suites still pass; a new check in `test_multiplayer_server.gd` sends `begin_interaction("task_repair_power")` from a client and receives `action_rejected`.

**Agent prompt**
```text
Do Step 1 of my guide ("Contract stubs"). Implement ONLY declarations and pass-through plumbing from docs/fix-plan/01-integration-contracts.md sections 2.1-2.3, 3, 7, 9 and 10 (lobby dict fields):
- shared/network_config.gd: TimerId, InteractionKind, LEGAL_TRANSITIONS (exactly the table in §2.1), is_legal_transition(), public_state_for().
- shared/player_connection_data.gd: display_name (default "Player <slot>") and color_index (slot-1), in to_dict/from_dict. Never add role to to_dict.
- shared/network_manager.gd: every RPC marked "new" in §7, with exact names/signatures/annotations (reliable vs unreliable as specified), plus the server-side sender helpers.
- server/server_network_manager.gd: a process_* method per new C->S RPC that returns {"success": false, "error": "not implemented"} and sends rpc_action_rejected(action, "invalid", "not implemented") to the requester.
- client/client_network_manager.gd: all §9.1 methods, §9.2 signals, §9.3 vars and helpers; handle_* functions that store the data and emit; reset in reset_match_state() and _cleanup_connection().
- NetworkManager: host_game/join_game/leave_game/is_dedicated_server declared (a minimal body is fine).
Do NOT remove any existing RPC yet. Do NOT change game logic yet.
Then extend tests/test_multiplayer_server.gd with one check: a connected client calls begin_interaction("task_repair_power") and receives action_rejected with action "begin_interaction".
Run a headless import (<GODOT> --headless --path . --import) and show me any SCRIPT ERROR lines. Then run: test_multiplayer_server, test_lobby_system, test_role_assignment, test_task_system, test_blackout_system, test_meeting_voting_system, test_meltdown_system. Show the results.
```

---

### Step 2 — Random Impostor (Wave 1) — C1
**Do:** in `RoleManager.calculate_role_assignments`, when `deterministic_impostor_index < 0` pick `randi_range(0, count - 1)`, using an RNG that can be seeded. `ServerNetworkManager` calls `randomize()` once in `start_server()`. The deterministic index stays for tests only.
**Done when:** a test assigns roles 200 times over 8 fake peers and every peer is Impostor at least 10 times. The existing role suites still pass.

**Agent prompt**
```text
Do Step 2 (audit C1). In shared/role_manager.gd, when deterministic_impostor_index is negative or out of range, choose the impostor index uniformly at random (use a RandomNumberGenerator; allow an optional seed parameter for tests). Keep the deterministic index path for tests. Make ServerNetworkManager.start_server() randomise its RNG once.
Add a test to tests/test_role_assignment.gd: call RoleManager.calculate_role_assignments on 8 peer ids 200 times and assert every peer was chosen as IMPOSTOR at least 10 times and exactly 1 impostor each time.
Run test_role_assignment.gd and test_role_system_foundation.gd and show the results.
```

---

### Step 3 — One state machine (Wave 1) — C2, C3, C4, H5
**Do**
1. Remove `RoundManager` and `SabotageManager` from the **server flow**:
   - no instances ticked in `_process`;
   - `_check_lobby_start_condition` goes straight to `_transition_game_state(ROLE_ASSIGNMENT)` + `assign_roles()` (exact-8 check kept);
   - delete `_on_round_state_changed`, `start_round`, `end_round`, `reset_round`, `resolve_sabotage` and `process_sabotage_request`.
   - **Don't delete the shared files yet** (M3's `main.gd` still preloads them; Step 12).
2. `rpc_request_sabotage` on the server now only replies `action_rejected("activate_blackout","invalid","use rpc_request_activate_blackout")`.
   - **Compat shim:** `NetworkManager.request_sabotage()` on the client calls `client.request_activate_blackout()`, so M3's Q key keeps working until M3 migrates.
3. `_transition_game_state(new)` → `return false` + `push_error` unless `NetworkConfig.is_legal_transition(current, new)`. Every caller checks the result.
4. Start Meltdown **only** on the VOTING→MELTDOWN transition, and only once per match (keep an `is_meltdown_started` flag, reset on return to lobby).
5. `_on_blackout_ended` does nothing unless the current state is BLACKOUT_ACTIVE.
6. Body-report meetings: only allowed in POST_BLACKOUT_INVESTIGATION (the kill flag is Step 5).

**Done when:** new tests prove all of these (write them in `test_multiplayer_server.gd` or hand them to M8 for `test_design_rules.gd`):
- a sabotage request at INITIAL_TASK_PHASE does not change state;
- `rpc_request_activate_blackout` in INITIAL_TASK_PHASE is rejected;
- blackout can't be activated twice;
- a meeting during MELTDOWN is impossible and the Meltdown timer is never reset;
- ROLE_ASSIGNMENT→INITIAL_TASK_PHASE is broadcast exactly once.

**Agent prompt**
```text
Do Step 3 (audit C2, C3, C4, H5). Read server/server_network_manager.gd fully first.
1) Remove RoundManager and SabotageManager from the server flow: stop ticking them, delete _on_round_state_changed, start_round, end_round, reset_round, resolve_sabotage and process_sabotage_request, and make _check_lobby_start_condition transition LOBBY->ROLE_ASSIGNMENT and call assign_roles() directly (keep the exact-8-players rule). Do NOT delete shared/round_manager.gd or shared/sabotage_manager.gd files yet.
2) The server handler for rpc_request_sabotage must only send rpc_action_rejected("activate_blackout","invalid","use rpc_request_activate_blackout"). In NetworkManager.request_sabotage() (client side) forward to client.request_activate_blackout() as a temporary compat shim.
3) Make _transition_game_state(new_state) return bool: reject + push_error unless NetworkConfig.is_legal_transition(current, new). Update every caller.
4) Meltdown must start only on the VOTING->MELTDOWN transition and at most once per match (flag reset in process_return_to_lobby_request and stop_server).
5) _on_blackout_ended must be a no-op unless current_game_state == BLACKOUT_ACTIVE.
6) Body-report meetings are only allowed in POST_BLACKOUT_INVESTIGATION (pass the state check before calling meeting_manager).
Write tests (real client->server RPCs over loopback, like test_multiplayer_server.gd does) for: sabotage request in INITIAL_TASK_PHASE changes nothing; activate_blackout rejected before unlock; blackout cannot be activated twice; meltdown timer is never reset by any request; ROLE_ASSIGNMENT->INITIAL_TASK_PHASE is broadcast once.
Then run all 10 backend suites listed in CLAUDE.md and show the results. List any suite that now fails because it relied on the removed behaviour (e.g. test_sabotage_system.gd, test_round_loop_foundation.gd) and draft handoff notes to M8/M3 instead of editing their tests.
```

---

### Step 4 — Public state (Wave 1) — C6
**Do:** `broadcast_game_state` and `_broadcast_lobby_sync` send `NetworkConfig.public_state_for(state, recipient_role)` per recipient. Skip sending to Crew entirely when their public state didn't change. In `client_network_manager.gd`, make `request_complete_task` allow INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE and BLACKOUT_ACTIVE, matching the server.
**Done when:** a loopback test shows Crew clients never receive BLACKOUT_AVAILABLE (their `current_game_state` stays INITIAL_TASK_PHASE), the Impostor does receive it, and Crew can still complete tasks after the unlock.

**Agent prompt**
```text
Do Step 4 (audit C6), contracts §2.2. Every game-state broadcast (broadcast_game_state, lobby sync state field) must send NetworkConfig.public_state_for(state, recipient_role) per recipient, and Crew must receive no message for the INITIAL_TASK_PHASE->BLACKOUT_AVAILABLE transition. In client/client_network_manager.gd, request_complete_task must allow INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE and BLACKOUT_ACTIVE (matching server/task_manager.gd).
Add a loopback test with 8 clients (deterministic impostor index): after the impostor finishes the prerequisite tasks, every crew client's current_game_state is still INITIAL_TASK_PHASE, the impostor's is BLACKOUT_AVAILABLE, and a crew client can still complete a task. Run it plus test_blackout_system.gd and test_task_system.gd.
```

---

### Step 5 — Kill flag + range bypass (Wave 1) — H1, H2
**Do**
- `process_kill_request` and `process_report_body_request` return rejected with `disabled` unless `BalanceConfig.get_value("kills.enabled", false)`.
- When enabled: kills only in BLACKOUT_ACTIVE (and MELTDOWN if the Impostor is alive); reports only in POST_BLACKOUT_INVESTIGATION.
- Delete the `!= Vector2.ZERO` skip. An unknown position means reject with `too_far`.
- `_check_crew_elimination_win_condition` only runs when kills are enabled.
- Update `test_kill_and_body_reporting.gd` to call `BalanceConfig.set_override("kills.enabled", true)` in setup and `clear_overrides()` in teardown. Tell M3.

**Agent prompt**
```text
Do Step 5 (audit H1, H2; decision D1). Gate process_kill_request and process_report_body_request behind BalanceConfig.get_value("kills.enabled", false); when disabled, reject with rpc_action_rejected(action, "disabled", ...). When enabled: kills only in BLACKOUT_ACTIVE, or MELTDOWN if the impostor is alive; body reports only in POST_BLACKOUT_INVESTIGATION. Remove every "!= Vector2.ZERO" proximity skip: if either position is unknown, reject with "too_far". Run _check_crew_elimination_win_condition only when kills are enabled.
If shared/balance_config.gd does not exist yet (M2 owns it), stop and tell me. Do not create it yourself.
Update tests/test_kill_and_body_reporting.gd to enable kills with BalanceConfig.set_override("kills.enabled", true) and clear_overrides() at the end, and add one test that kills are rejected by default. Run it and show the results. Draft a note to M3 describing the test change.
```

---

### Step 6 — Position authority (Wave 1) — H2 · needs `StationRegistry.SPAWN_POINTS` (M6)
**Do**
- On ROLE_ASSIGNMENT: set every player's server position to `StationRegistry.get_spawn_point(slot)` and send `rpc_correct_position` to each client.
- `update_player_position`: apply the speed rule from contracts §8.6, using the server clock. Reject = don't store, don't rebroadcast, send `rpc_correct_position(last)`.
- Ejected players: stop broadcasting their position, **or** keep broadcasting but flag them as ghosts. Pick one and note it in the contracts PR.

**Agent prompt**
```text
Do Step 6 (audit H2, contracts §8.6). At the ROLE_ASSIGNMENT transition, set each player's authoritative position to StationRegistry.get_spawn_point(player_slot) and send rpc_correct_position to that client. In update_player_position, accept a new position only if distance(last, new) <= anti_cheat.max_move_speed_px_s * elapsed_sec * 1.25 + anti_cheat.position_tolerance_px (read via BalanceConfig, server clock via Time.get_ticks_msec()). On rejection: do not store, do not rebroadcast, send rpc_correct_position(last) to the sender. Only rebroadcast accepted positions (rpc_send_player_position handler in network_manager.gd).
Tests (loopback): a normal walking update sequence is accepted; a 2000px jump is rejected and the client receives position_corrected; other clients never receive the rejected position. Run the new tests + test_multiplayer_server.gd + test_state_sync.gd.
```

---

### Step 7 — Interaction handshake (Wave 1) — I4, D12 · needs the registry (M6)
**Do:** implement contracts §8.1–§8.3 in the hub: `active_interactions` dict, the begin checks per kind, and the extra completion checks (`too_fast`, `too_far`, `no_active_interaction`) in front of the existing `process_*_completion` methods. Clear everything on every state transition. Disruption calls M2's `MeltdownManager.request_disrupt()`; until it exists, reject with `invalid`.
**Done when:** loopback tests show:
- completing without a begin is rejected;
- completing too fast is rejected;
- completing from too far is rejected;
- Crew can't begin an objective; the Impostor can't begin recovery;
- the correct begin → wait `min_duration` → complete path succeeds.

(Use `BalanceConfig.set_override("anti_cheat.min_duration_factor", 0.05)` to keep tests fast.)

**Agent prompt**
```text
Do Step 7 (audit I4, decision D12, contracts §8.1-8.3). In server/server_network_manager.gd implement process_begin_interaction(peer_id, station_id), process_cancel_interaction(peer_id), and put the §8.2 checks (active interaction matches kind+target, elapsed >= min_duration_sec * anti_cheat.min_duration_factor, still within radius + range_slack_px) in front of process_task_completion_request, process_recovery_request, process_impostor_objective_completion_request and process_emergency_system_completion_request. Use StationRegistry for station data and the authoritative positions from Step 6. Send rpc_interaction_begin_accepted(station_id, mode) on success and rpc_action_rejected with the exact reason codes from contracts §3 on failure. Clear active_interactions on every successful _transition_game_state.
For EMERGENCY + impostor ("disrupt"): call meltdown_manager.request_disrupt(peer_id, system_id) if that method exists; otherwise reject with "invalid" and add a TODO referencing M2.
Write loopback tests for each rejection code and for the happy path of every kind (use BalanceConfig.set_override to shrink min durations and blackout timing). Run them plus all 10 backend suites. Suites that complete tasks without begin_interaction will now fail. List them, then fix the ones I own and draft handoff notes for the rest.
```

---

### Step 8 — Names, chat, timers, rejections (Wave 1) — F1, F8, F10, F11
**Do:** contracts §8.8, §8.9 and §2.3:
- store `display_name`;
- chat validation + broadcast;
- a 1 Hz `rpc_sync_timer` for whichever timer is running (read `remaining` from the managers' public getters, asking M2 for any missing ones);
- send `rpc_action_rejected` from **every** existing `process_*` failure path (ready, blackout activation, meeting, vote, return to lobby…).

**Agent prompt**
```text
Do Step 8 (audit F1, F8, F10, F11). Implement contracts §8.9 (player names), §8.8 (chat) and §2.3 (timer sync at 1 Hz and on timer start, for BLACKOUT_COUNTDOWN, BLACKOUT, INVESTIGATION, DISCUSSION, VOTING, MELTDOWN). Timer values must come from public getters on the managers. If one is missing (e.g. meeting discussion_remaining), list exactly which getter you need from M2 and use the manager's public field meanwhile. Make every failure branch of every existing process_* method also send rpc_action_rejected(action, code, message) to the requester, using the action names and reason codes in contracts §3.
Tests: name sanitising and dedupe; chat rejected outside MEETING/VOTING, rate-limited, over-length rejected, delivered to all 8 clients in VOTING; timer_synced received during blackout; a vote outside VOTING produces action_rejected("cast_vote","wrong_phase",...). Run them and all backend suites.
```

---

### Step 9 — Hosting (Wave 1) — C7
**Do:** contracts §6.
- `host_game` spawns `OS.create_process(OS.get_executable_path(), [...])` using `--headless --path <project> -- --server --port=N` in the editor/debug build, and without `--path` in an export. Then join with retries.
- `leave_game` kills the child PID.
- `--server` handling in `_ready()` + `scenes/server_console.tscn` (a Label with the port and player count is enough).
- Make sure `start_server` / `connect_client` no longer stop each other when called in sequence.

**Done when:** from two terminals, `godot --path . -- --server` plus 8 × `godot --path .` → Join 127.0.0.1 all reach the lobby. The Host button in one instance also works (M5 wires the button; you can test through a tiny debug script).

**Agent prompt**
```text
Do Step 9 (audit C7, contracts §6). Implement NetworkManager.host_game(port, name), join_game(host, port, name), leave_game() and is_dedicated_server:
- --server [--port=N] in OS.get_cmdline_user_args() starts the server in _ready and changes scene to res://scenes/server_console.tscn (create it: a Label showing port, player count and game state, refreshed every second).
- host_game spawns a headless server child with OS.create_process(OS.get_executable_path(), args) (include "--path", ProjectSettings.globalize_path("res://") only when OS.has_feature("editor") or running from source), stores the PID, then join_game("127.0.0.1", port, name) retrying every 0.5s for up to 10s.
- join_game sends set_player_name after rpc_receive_player_assignment arrives.
- leave_game disconnects and OS.kill()s the child if we spawned one.
- Calling host_game must never stop the server it started (the current start_host + connect_client bug).
Write tools/launch_local_match.ps1 and tools/launch_local_match.sh (1 dedicated server + N clients, N default 8, Godot path as first argument). Tell me exactly how to verify it manually, since this can't be fully headless-tested.
```

---

### Step 10 — Disconnects, reset, roster, private calls (Wave 1) — H3, H4, H6, H7
**Do**
- Contracts §2.4 policy in `_on_peer_disconnected` (needs M2's new `GameOverReason` values).
- `stop_server()` and return-to-lobby reset **everything**: all managers, corpses, positions, kill timers, active interactions, the Meltdown-started flag.
- Build `player_roster` in `_on_game_over_triggered` before broadcasting (contracts §10).
- Replace the calls to `meeting_manager._resolve_meeting_and_voting`, `meltdown_manager._trigger_game_over` and `blackout_manager._start_blackout` with the public APIs M2 provides.

**Agent prompt**
```text
Do Step 10 (audit H3, H4, H6, H7).
1) Implement the disconnect policy in contracts §2.4 inside _on_peer_disconnected (Impostor leaves mid-match -> GAME_OVER CREW with GameOverReason.IMPOSTOR_DISCONNECTED; crew leaves -> is_eliminated = true; < 2 connected -> MATCH_ABANDONED then LOBBY). If M2 hasn't added those enum values or a public end_match(winner, reason) API on MeltdownManager yet, stop and tell me what's missing.
2) Make stop_server() and process_return_to_lobby_request() reset every manager and every hub field (corpses, positions, kill timers, active_interactions, meltdown-started flag). Put the reset in one private _reset_match_state() used by both.
3) In _on_game_over_triggered, add "player_roster" (contracts §10, including display_name) and "orion_instability" to result_data before broadcast_game_over.
4) Replace every cross-class private call (_resolve_meeting_and_voting, _trigger_game_over, _start_blackout) with public methods; list any public method you need from M2.
Tests: impostor disconnect ends the match with crew win; crew disconnect mid-vote doesn't resolve voting early; roster has 8 entries with roles after game over; after return to lobby a second full match runs cleanly. Run all backend suites + test_return_to_lobby_rematch.gd.
```

---

### Step 11 — Plumbing for M2's mechanics (Wave 2) — C5, H9, F4, F5, F6
**Do** (after M2 lands the manager APIs):
- **Investigation:** start the investigation window on entering POST_BLACKOUT_INVESTIGATION; on expiry, call the meeting path with caller 0. Validate that meeting-button calls are made within range of `meeting_button`.
- **Evidence:** delete the auto-broadcast. Send `rpc_sync_evidence_markers` on entering investigation. Implement `process_inspect_evidence` (§8.7).
- **Doors:** `rpc_sync_door_states` from M2's door selection at blackout start/end.
- **Disruption:** broadcast `rpc_sync_emergency_disrupted` (start and clear).
- **Instability:** send `rpc_sync_orion_instability` at MELTDOWN start.

**Agent prompt**
```text
Do Step 11 (audit C5, H9, F4, F5, F6). First read M2's latest public APIs in server/meeting_manager.gd, evidence_manager.gd, meltdown_manager.gd, blackout_manager.gd and any new instability manager. If any API in contracts §7/§8 is missing, stop and list it.
Wire: investigation window start + auto-meeting on expiry (caller 0); rpc_request_call_meeting proximity check against StationRegistry "meeting_button"; remove broadcast_investigation_evidence and rpc_sync_investigation_evidence; send rpc_sync_evidence_markers on entering POST_BLACKOUT_INVESTIGATION; process_inspect_evidence per §8.7; rpc_sync_door_states at blackout start/end; rpc_sync_emergency_disrupted on disrupt and on expiry; rpc_sync_orion_instability at MELTDOWN start.
Loopback tests for each (no crew client ever receives evidence details it didn't inspect; the auto-meeting starts after the investigation timer; door states arrive at blackout start and clear at the end). Run all backend suites.
```

---

### Step 12 — Delete deprecated code (end of Wave 2) — C2, H5
Only after M3 confirms Q uses `request_activate_blackout` and M8 has removed/rewritten `test_sabotage_system.gd` / `test_round_loop_foundation.gd`.

**Agent prompt**
```text
Do Step 12. First grep the whole repo for RoundManager, SabotageManager, round_manager.gd, sabotage_manager.gd, request_sabotage, rpc_request_sabotage, rpc_sync_sabotage_state, rpc_sync_round_state, round_state_synced, sabotage_state_synced, sabotage_requested and investigation_evidence_received. If anything outside my files still references them, stop and list the file + owner. Otherwise delete shared/round_manager.gd, shared/sabotage_manager.gd (+ .uid files), the deprecated RPCs, the compat shim and the deprecated client signals. Run a headless import and show SCRIPT ERROR lines (expect none), then the full test runner.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main as a strict reviewer:
1) git diff origin/main...HEAD --stat. Flag every changed file NOT in "Your files" of docs/fix-plan/member-1-backend-network.md.
2) For each new or changed RPC/signal/method, check that name, signature and payload match docs/fix-plan/01-integration-contracts.md exactly. List every mismatch.
3) Search the diff for: calls to other classes' _private methods, direct writes to current_game_state outside _transition_game_state, push_warning-only rejections that don't send rpc_action_rejected, Vector2.ZERO proximity skips, leftover print spam, debug keys.
4) Run a headless import and the full test runner (or all backend suites if the runner isn't ready). Paste the results.
5) Draft the PR description using the template in docs/fix-plan/README.md §5, listing the audit IDs closed, and the PROJECT_STATUS.md §7 entry.
```

## 7. Handoff notes you will likely need to send
- **M2:** public `MeetingManager.resolve_now(...)`, `MeltdownManager.end_match(winner, reason)`, `request_disrupt()`, timer getters, the `GameOverReason` additions.
- **M3:** Q → `request_activate_blackout`; remove the SabotageManager/RoundManager usages in `scenes/main.gd` and `player_controller.gd`; the kill test now needs the override; handle `position_corrected`.
- **M5:** the host/join API is ready; `action_rejected` codes for toasts; timers via `timer_synced`.
- **M8:** `test_sabotage_system.gd` / `test_round_loop_foundation.gd` are obsolete; add the design-rule tests.
