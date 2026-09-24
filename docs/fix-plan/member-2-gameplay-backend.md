# Member 2 — Abdul Qadir — Gameplay Backend Engineer · Fix Guide

**Branch:** `member-2/gameplay-backend`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** C3 (Meltdown safe to call twice), C5 (investigation timer), H6 (voting), H7, H8, H9, H10, F4, F5, F6, F9 (only if M6 keeps it in scope)

Your managers are the best-tested part of the repo; all 10 backend suites pass. The work is: load real config, expose **public** APIs for everything the hub (M1) needs, stop leaking evidence, and add the three missing mechanics.

---

## 1. Your files (you may edit)
- Managers:
  - `server/task_manager.gd`
  - `server/blackout_manager.gd`
  - `server/blackout_recovery_manager.gd`
  - `server/impostor_objective_manager.gd`
  - `server/evidence_manager.gd`
  - `server/meeting_manager.gd`
  - `server/voting_manager.gd`
  - `server/meltdown_manager.gd`
  - `server/win_condition_manager.gd`
- **New:** `server/instability_manager.gd`
- Shared configs and definitions:
  - `shared/task_config.gd`, `task_definition.gd`
  - `blackout_config.gd`
  - `blackout_recovery_config.gd`, `blackout_recovery_definition.gd`
  - `blackout_objective_config.gd`, `blackout_objective_definition.gd`
  - `evidence_config.gd`, `evidence_definition.gd`
  - `meeting_config.gd`
  - `meltdown_config.gd`
- **New:** `shared/balance_config.gd`
- Your paired tests:
  - `tests/test_task_system.gd`
  - `test_blackout_system.gd`
  - `test_blackout_recovery_objectives.gd`
  - `test_evidence_system.gd`
  - `test_meeting_voting_system.gd`
  - `test_meltdown_system.gd`
  - `test_win_condition_manager.gd`
  - new `tests/test_instability.gd`, `tests/test_balance_config.gd`

## 2. Not yours
- `server/server_network_manager.gd`, `shared/network_manager.gd`, `shared/network_config.gd`, `client/client_network_manager.gd` → **M1**. You expose public methods and signals; M1 wires them.
- `config/game_balance_config.json`, `shared/station_registry.gd`, `design/specs/*` → **M6**. M6 decides values and IDs; you port catalog content into your configs.

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| The new JSON keys (you can start with contracts §5 defaults) | M6, Wave 0 | 1 |
| The location-ID mapping (old `power_room`/`cooling_hub`/`containment_hub` → new) | M6, Wave 0 | 7 |
| `StationRegistry.get_door_ids()` | M6, Wave 0 | 10 |

| Others need from you | Step |
|---|---|
| `BalanceConfig` (M1 uses it in almost every step; tests use `set_override`) | **1** |
| Public APIs + timer getters (M1 Steps 3, 8, 10) | 2, 3 |
| Investigation / evidence / disruption / doors / instability APIs (M1 Step 11) | 4, 6, 8, 9, 10 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 1 (first!) | `BalanceConfig` loader + managers read it | H8 |
| 2 | 1 | Meltdown safe to call twice + `GameOverReason` additions + public `end_match()` | C3, H7 |
| 3 | 1 | Public APIs replacing private calls + remaining-time getters | H7, F10 |
| 4 | 1 | Investigation window (auto-meeting) | C5, H10 |
| 5 | 1 | Voting ignores disconnected voters | H6 |
| 6 | 1 | Evidence: markers + per-player details (no broadcast) | H9 |
| 7 | 1 | Location-ID migration in catalogs/templates | — (contracts §1.1) |
| 8 | 2 | ORION instability | F4 |
| 9 | 2 | Impostor Meltdown disruption | F5 |
| 10 | 2 | Door-jam selection during blackout | F6 |
| 11 | 2 (optional) | Fake repair tell (only if M6 keeps FR-25) | F9 |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my coding agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 2 (Abdul Qadir), Gameplay Backend Engineer. My branch is member-2/gameplay-backend.

Before writing any code:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md, docs/fix-plan/member-2-gameplay-backend.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-2/gameplay-backend or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) anything in the contracts that conflicts with the current manager code. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY the files listed under "Your files" in my guide. server/server_network_manager.gd and shared/network_manager.gd belong to Member 1: if the hub must call something new, write a handoff note describing the exact call.
- Implement names, signatures, config keys and IDs EXACTLY as in 01-integration-contracts.md. If the contract is wrong or missing something, stop and tell me.
- Managers stay RefCounted, deterministic and network-free: they validate, change state, emit signals, and return {"success": bool, "error": String, ...} dictionaries. They never send RPCs.
- Never call another class's underscore-prefixed method. Tests must not set manager internals directly unless they're testing that manager in isolation.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session.
- After each step: list the changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today citing the audit IDs. Do not commit unless I say so.
```

---

### Step 1 — `BalanceConfig` loader (Wave 1, do first) — H8
**Do:** create `shared/balance_config.gd` exactly per contracts §5:
- `load_from_file`, `get_value` (dotted keys, `{"value":…}` leaves, range clamp + warning), `is_loaded`, `set_override`, `clear_overrides`;
- Meltdown forced to 300 unless overridden.

Then make every manager read its values from `BalanceConfig.get_value(key, <existing constant>)` inside `clear()`/`setup()`, so the constants stay as fallbacks. Tell M1 to call `load_from_file()` in `start_server()`.

**Done when:** `tests/test_balance_config.gd` covers:
- a missing file gives defaults;
- a `{"value"}` leaf is read;
- an out-of-range value is clamped;
- an override wins over the file;
- the Meltdown 300 lock holds.

All 7 of your suites still pass.

**Agent prompt**
```text
Do Step 1 (audit H8, contracts §5). Create shared/balance_config.gd with exactly: load_from_file(path = "res://config/game_balance_config.json") -> bool, get_value(key: String, default_value) (dotted path; a leaf that is a Dictionary with "value" returns that value; if it has "range" [lo, hi] and the value is outside, push_warning and clamp), is_loaded() -> bool, set_override(key, value), clear_overrides(). Store state in static vars. meltdown.duration_sec must always return 300.0 unless an override is set. A missing file or key must never crash: return default_value.
Then change every manager in server/ (except server_network_manager.gd) to read its tunables via BalanceConfig.get_value("<key from contracts §5 table>", <existing constant>) inside clear()/setup(). Keep the constants as fallbacks.
Write tests/test_balance_config.gd (SceneTree script printing [PASS]/[FAIL], non-zero exit on failure, like the other suites) covering: defaults with no file, reading the real JSON, a {"value"} leaf, clamping, override precedence, clear_overrides, the meltdown 300 lock.
Run it plus test_task_system, test_blackout_system, test_blackout_recovery_objectives, test_evidence_system, test_meeting_voting_system, test_meltdown_system, test_win_condition_manager. Draft a handoff note to M1: "call BalanceConfig.load_from_file() at the top of start_server()".
```

---

### Step 2 — Meltdown safe to call twice + end-match API (Wave 1) — C3, H7
**Do**
- `start_meltdown(is_impostor_alive) -> bool`: returns `false` (no reset) if Meltdown is already active or the game is over.
- Append `IMPOSTOR_DISCONNECTED` and `MATCH_ABANDONED` to the **end** of `GameOverReason`, plus names in `get_game_over_reason_name`.
- Add a public `end_match(winner_role, reason) -> Dictionary` that wraps the current `_trigger_game_over`. It must be safe to call twice (only the first call wins).

**Agent prompt**
```text
Do Step 2 (audit C3, H7). In server/meltdown_manager.gd: make start_meltdown() return bool and refuse (return false, no state change) when is_meltdown_active or is_game_over. Add public end_match(winner_role, reason) -> Dictionary that performs the current _trigger_game_over logic once (a second call returns the first result and emits nothing). In shared/meltdown_config.gd append IMPOSTOR_DISCONNECTED and MATCH_ABANDONED to the END of GameOverReason (don't renumber existing values) and extend get_game_over_reason_name().
Add tests to tests/test_meltdown_system.gd: start_meltdown twice doesn't reset remaining_time or completed systems; end_match is idempotent; new reason names. Run test_meltdown_system and test_win_condition_manager. Draft a handoff note to M1 listing the new public methods to use instead of _trigger_game_over.
```

---

### Step 3 — Public APIs + timer getters (Wave 1) — H7, F10
**Do:** add public methods so the hub never touches your privates:
- `MeetingManager.resolve_now(active_players, impostor_peer_id, voting_manager)`
- `MeetingManager.get_discussion_remaining()`, `get_voting_remaining()`
- `BlackoutManager.get_countdown_remaining()` (the blackout remaining getter already exists)
- `MeltdownManager.get_remaining_time()`

The old private names can call the new public ones.

**Agent prompt**
```text
Do Step 3 (audit H7, F10). Add public methods: MeetingManager.resolve_now(active_players, impostor_peer_id, voting_manager) (same behaviour as _resolve_meeting_and_voting, safe if no meeting is active), MeetingManager.get_discussion_remaining() / get_voting_remaining(), BlackoutManager.get_countdown_remaining(), MeltdownManager.get_remaining_time(). Keep the private versions delegating to the public ones so current callers still work. Add small unit checks for each in the paired suites and run them. Draft a handoff note to M1 listing every private call in server_network_manager.gd and its public replacement.
```

---

### Step 4 — Investigation window (Wave 1) — C5, H10 · decision D8
**Do** in `MeetingManager`:
- `start_investigation(duration := BalanceConfig "investigation.duration_sec")`
- `stop_investigation()`
- `get_investigation_remaining()`
- `tick()` emits `investigation_expired()` once when the timer hits 0.
- Starting a meeting stops the investigation timer.
- `can_call_meeting` also rejects a caller who is `is_eliminated`, and rejects a second meeting in the same match. Document in a code comment that the state table allows exactly one meeting per match, so no per-player cooldown is needed (closes H10).

**Agent prompt**
```text
Do Step 4 (audit C5, H10; decision D8). In server/meeting_manager.gd add start_investigation(duration: float = <BalanceConfig "investigation.duration_sec", 45.0>), stop_investigation(), get_investigation_remaining(), a signal investigation_expired(), and tick() handling that emits investigation_expired exactly once when it reaches 0. request_call_meeting must stop the investigation timer. can_call_meeting must reject a second meeting in the same match (track meetings_held; reset in clear()). Add a comment explaining why no per-player cooldown exists (one meeting per match by the state table).
Tests in tests/test_meeting_voting_system.gd: investigation_expired fires once after the duration with manual tick(); calling a meeting stops the timer; a second meeting is rejected. Run the suite. Draft a handoff note to M1: call start_investigation() on entering POST_BLACKOUT_INVESTIGATION and treat investigation_expired as "system calls the meeting (caller 0)".
```

---

### Step 5 — Voting ignores disconnected voters (Wave 1) — H6
**Do:** `VotingManager.handle_player_disconnect(peer)` removes that peer's vote. `have_all_active_voted(active_players)` counts only votes from peers who are in `active_players`, alive and not eliminated.

**Agent prompt**
```text
Do Step 5 (audit H6). In server/voting_manager.gd: handle_player_disconnect(peer_id) removes that peer's vote if present; have_all_active_voted(active_players) must count only votes whose voter is in active_players and alive/not eliminated, compared against the number of eligible players. Add tests: 8 players, 7 vote, the 8th disconnects -> all voted; a player votes then disconnects -> their vote no longer counts in calculate_results. Run test_meeting_voting_system.gd.
```

---

### Step 6 — Evidence discovery API (Wave 1) — H9 · decision D7
**Do** in `EvidenceManager`:
- `get_marker_list() -> Array` of `{"evidence_id","evidence_type","location_id"}` (contracts §10);
- `get_public_details(evidence_id) -> Dictionary` (`to_public_dict()` or `{}`);
- `finalize_investigation()` still marks the investigation active but **callers must not broadcast its return value**. Rename or re-document it so nobody does.
- No change to attribution: the actor stays internal.

**Agent prompt**
```text
Do Step 6 (audit H9; decision D7; contracts §10). In server/evidence_manager.gd add get_marker_list() -> Array of {"evidence_id","evidence_type","location_id"} (nothing else, no description, no actor) and get_public_details(evidence_id) -> Dictionary (to_public_dict() or {} if unknown). Keep finalize_investigation() but make its doc comment say its return value must never be broadcast, and make it return get_marker_list() instead of full details.
Tests in tests/test_evidence_system.gd: markers contain exactly the 3 keys; details never include _internal_actor_peer_id or any peer id; unknown id returns {}. Run the suite. Draft a handoff note to M1: remove broadcast_investigation_evidence; send markers via rpc_sync_evidence_markers; implement inspect via get_public_details.
```

---

### Step 7 — Location-ID migration (Wave 1) — contracts §1.1 · needs M6's mapping
**Do:** replace every `location_id` / `source_system` location in:
- `blackout_recovery_config.gd`
- `blackout_objective_config.gd`
- `evidence_config.gd` (including the "Executive Office" wording)
- the `create_evidence_from_recovery` default `station_subsystem`

Each must become a canonical room ID or an `EVIDENCE_ANCHORS` ID, following M6's mapping in `design/specs/map_station_layout.md`.

**Agent prompt**
```text
Do Step 7 (contracts §1.1). Open design/specs/map_station_layout.md and shared/station_registry.gd (Member 6) to get the canonical location mapping. Replace every location_id in shared/blackout_recovery_config.gd, shared/blackout_objective_config.gd, shared/evidence_config.gd and the "station_subsystem" default in server/evidence_manager.gd so each is either a room id from contracts §1.1 or a key of StationRegistry.EVIDENCE_ANCHORS. If M6's mapping doesn't cover an id, stop and list it. Add a test that asserts every location_id in those catalogs is valid (room id or anchor). Run all your paired suites.
```

---

### Step 8 — ORION instability (Wave 2) — F4
**Do:** new `server/instability_manager.gd` (RefCounted):
- `clear()`;
- `add_objective(objective_id)` (points from `orion_instability.per_objective_points`);
- `tick_blackout(delta)` (`per_blackout_second`);
- `get_value() -> int` (clamped 0–100);
- signal `instability_changed(value)`.

It **never** affects the Meltdown duration (design rule #10). It is flavour for the HUD, VFX and audio.

**Agent prompt**
```text
Do Step 8 (audit F4). Create server/instability_manager.gd (RefCounted, no networking): clear(), add_objective(objective_id) using BalanceConfig "orion_instability.per_objective_points" (a Dictionary objective_id -> points), tick_blackout(delta) using "orion_instability.per_blackout_second", get_value() -> int clamped 0..100, signal instability_changed(value: int). It must not reference MeltdownManager or change any duration. Write tests/test_instability.gd (points per objective, blackout ticking, clamp at 100, clear). Run it. Draft a handoff note to M1: instantiate it in the hub, call add_objective on impostor objective completion and tick_blackout while BLACKOUT_ACTIVE, and send rpc_sync_orion_instability at MELTDOWN start + include it in game-over result_data.
```

---

### Step 9 — Meltdown disruption (Wave 2) — F5 · decision D11
**Do** in `MeltdownManager`:
- `request_disrupt(peer_id, system_id, active_players) -> Dictionary`. Allowed only for an alive, non-eliminated Impostor, during Meltdown, on a system that isn't completed, and off cooldown (`meltdown.disrupt_cooldown_sec`).
- `is_disrupted(system_id)` and `get_disrupt_remaining(system_id)`.
- `tick()` clears disruptions after `meltdown.disrupt_duration_sec` and emits `emergency_system_disruption_changed(system_id, remaining_sec)` (0 when cleared).
- `can_complete_emergency_system` rejects with the reason text containing `disrupted` while the system is disrupted.

**Agent prompt**
```text
Do Step 9 (audit F5; decision D11). In server/meltdown_manager.gd add request_disrupt(peer_id, system_id, active_players) -> Dictionary (success/error), is_disrupted(system_id), get_disrupt_remaining(system_id), signal emergency_system_disruption_changed(system_id: String, remaining_sec: float). Rules: MELTDOWN active, the requester is the IMPOSTOR, alive and not eliminated, the system is valid and not completed, the per-impostor cooldown (meltdown.disrupt_cooldown_sec) has elapsed. A disruption lasts meltdown.disrupt_duration_sec; tick() clears it and emits remaining 0. While disrupted, can_complete_emergency_system must fail with an error containing "disrupted". Tests in tests/test_meltdown_system.gd for every rule. Run the suite and draft the M1 handoff note (process_disrupt_emergency + rpc_sync_emergency_disrupted).
```

---

### Step 10 — Door jams (Wave 2) — F6
**Do:** in `BlackoutManager`, when blackout starts, pick `blackout.doors_jammed_count` random IDs from `StationRegistry.get_door_ids()` and emit `doors_jam_changed(jammed_ids: Array)`. Emit `doors_jam_changed([])` when blackout ends (either way). Expose `get_jammed_door_ids()`.

**Agent prompt**
```text
Do Step 10 (audit F6). In server/blackout_manager.gd: on blackout start pick BalanceConfig "blackout.doors_jammed_count" distinct random ids from StationRegistry.get_door_ids() (fewer if not enough doors), store them, emit doors_jam_changed(jammed_ids: Array); on any blackout end (timer or early) clear them and emit doors_jam_changed([]). Add get_jammed_door_ids(). Tests in tests/test_blackout_system.gd (count, distinct, cleared on early end). Run it and draft the M1 handoff note (rpc_sync_door_states).
```

---

### Step 11 — Fake repair tell (optional, Wave 2) — F9
Only if M6's decision record keeps FR-25. Otherwise skip and M6 descopes it in the PRD. If kept, M6 writes the exact rule in `design/specs/evidence_matrix.md` first; implement only what is written there.

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main as a strict reviewer:
1) git diff origin/main...HEAD --stat. Flag any file not in "Your files" of docs/fix-plan/member-2-gameplay-backend.md.
2) Check every new public method/signal/config key against docs/fix-plan/01-integration-contracts.md (§5 keys, §8 rules, §10 payloads). List mismatches.
3) Search the diff for: networking inside managers, private cross-class calls, hardcoded tunables that should come from BalanceConfig, evidence payloads that include peer ids, meltdown duration changes.
4) Run a headless import and all 7 paired suites + test_balance_config + test_instability. Paste the results.
5) Draft the PR description (template in docs/fix-plan/README.md §5) with the audit IDs, plus the handoff notes to M1 and the PROJECT_STATUS.md §7 entry.
```
