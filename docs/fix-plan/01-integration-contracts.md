# BLACKOUT — Integration Contracts v1

**Status:** PROPOSED (ratify at kickoff) · **Owners:** Member 1 (network) + Member 6 (content/design) · **Baseline:** `main @ 379ed70`

This file is the **single source of truth** for everything that crosses a member boundary: RPCs, client signals, enums, config keys, station IDs, node paths, groups and payload shapes.

**Rules**
1. If your code calls or is called by another member's code, the interface **must** be in this file.
2. Implement names and signatures **exactly** as written. Don't rename, don't add optional extras "for later".
3. To change the contract: open a PR that edits **only this file**, get approval from M1 + M6 and ping every affected member. Merge that first, then code.
4. When a section is implemented, the implementer ticks it in §14 in their PR.

---

## 1. Canonical IDs

### 1.1 Room IDs (from `scenes/environment/facility_map.gd` `ROOM_DEFINITIONS`, owned by M7)
`cafeteria`, `storage`, `server_room`, `medbay`, `generator_room`, `executive_office`, `security_room`, `laboratory`, `orion_core`

Every `room_id`/`location_id` in any config, catalog, registry or evidence template **must** be one of these, or an evidence-anchor ID declared in `StationRegistry.EVIDENCE_ANCHORS` (§4). The current values `power_room`, `cooling_hub`, `containment_hub` and `station_subsystem` must be migrated. M6 decides the mapping; M2 ports it.

### 1.2 Station IDs (content owned by M6 in `shared/station_registry.gd`)
| Kind | Station IDs | `target_id` sent to the server |
|---|---|---|
| Crew task (10) | `task_repair_power`, `task_stabilize_orion`, `task_server_calibration`, `task_security_repair`, `task_medical_supply_check`, `task_data_transfer`, `task_door_repair`, `task_coolant_system`, `task_laboratory_org`, `task_backup_power` | task **type** ID without the `task_` prefix (`repair_power`, …) |
| Recovery (4) | `recovery_generator`, `recovery_power_routing`, `recovery_security_relay`, `recovery_cooling` | `generator`, `power_routing`, `security_relay`, `cooling` |
| Impostor objective (5) | `objective_steal_confidential_files`, `objective_extract_orion_core_data`, `objective_disable_orion_containment`, `objective_sabotage_generator`, `objective_tamper_security` | the objective ID without the `objective_` prefix |
| Emergency (3) | `emergency_restore_power`, `emergency_restore_cooling`, `emergency_stabilize_orion` | `restore_power`, `restore_cooling`, `stabilize_orion` |
| Meeting button (1) | `meeting_button` (Cafeteria) | `""` |

Door IDs: `door_<roomA>_<roomB>` with the room IDs in alphabetical order, e.g. `door_cafeteria_storage`. M6 lists them in the registry; M7 places them.

### 1.3 Player colour
`color_index = player_slot - 1` (0–7) → `PlayerVisual.set_color(color_index)`. Slot 1 = red, following the order of `PlayerVisual`'s colour table.

---

## 2. Game states and transitions (M1 enforces)

`NetworkConfig.GameState` is the **only** state machine. `RoundManager` and `SabotageManager` are removed from the server flow (audit H5, C2).

### 2.1 Legal transitions
| From | To | Trigger (server only) |
|---|---|---|
| LOBBY | ROLE_ASSIGNMENT | exactly 8 connected and 8 ready |
| ROLE_ASSIGNMENT | INITIAL_TASK_PHASE | roles delivered + tasks assigned |
| INITIAL_TASK_PHASE | BLACKOUT_AVAILABLE | Impostor completed all prerequisite tasks |
| BLACKOUT_AVAILABLE | BLACKOUT_ACTIVE | 3-2-1 countdown finished (started by `rpc_request_activate_blackout`) |
| BLACKOUT_ACTIVE | POST_BLACKOUT_INVESTIGATION | blackout timer expired **or** recovery threshold reached |
| POST_BLACKOUT_INVESTIGATION | MEETING | meeting button pressed **or** `investigation.duration_sec` expired |
| MEETING | VOTING | discussion timer expired |
| VOTING | MELTDOWN | voting timer expired **or** all eligible voted (always, whatever the result) |
| MELTDOWN | GAME_OVER | all 3 systems repaired (Crew) **or** timer expired (Impostor) |
| *any in-match state* | GAME_OVER | disconnect policy (§2.4) |
| GAME_OVER | LOBBY | `rpc_request_return_to_lobby` |
| *any* | LOBBY | server stop / `MATCH_ABANDONED` |

Implement as `NetworkConfig.LEGAL_TRANSITIONS: Dictionary` + `static func is_legal_transition(from: GameState, to: GameState) -> bool`. `ServerNetworkManager._transition_game_state()` returns `false` and `push_error`s on an illegal transition. **Every** state change goes through it.

Consequences, which the tests must assert (M8):
- There are no meetings outside POST_BLACKOUT_INVESTIGATION.
- Meltdown starts exactly once per match.
- Blackout can't end while in MEETING/VOTING.

### 2.2 Public state (audit C6)
`static func public_state_for(state: GameState, role: PlayerRole) -> GameState`: returns `INITIAL_TASK_PHASE` when `state == BLACKOUT_AVAILABLE` and `role != IMPOSTOR`; otherwise returns `state` unchanged.
Every game-state broadcast (`rpc_game_state_changed`, the `state` field of `rpc_sync_lobby_state`) sends the **public** state per recipient. Crew receive no message at all for the INITIAL→AVAILABLE transition.

### 2.3 Timers
```gdscript
enum TimerId { NONE, BLACKOUT_COUNTDOWN, BLACKOUT, INVESTIGATION, DISCUSSION, VOTING, MELTDOWN }
```
The server broadcasts `rpc_sync_timer(timer_id, remaining_sec)` when a timer starts and every 1.0s while it runs. Clients count down locally between syncs and never decide expiry.

### 2.4 Disconnect policy (decision D10)
| State | Who disconnects | Server does |
|---|---|---|
| LOBBY | anyone | remove, re-sync lobby |
| In match | Impostor | GAME_OVER, winner CREW, reason `IMPOSTOR_DISCONNECTED` |
| In match | Crew | mark `is_eliminated = true` (does not vote, can't act); the match continues |
| In match | anyone, leaving < 2 connected | GAME_OVER reason `MATCH_ABANDONED`, then LOBBY |

---

## 3. Enums and constants to add

**`shared/network_config.gd` (M1)**
```gdscript
enum TimerId { NONE, BLACKOUT_COUNTDOWN, BLACKOUT, INVESTIGATION, DISCUSSION, VOTING, MELTDOWN }
enum InteractionKind { NONE, CREW_TASK, RECOVERY, IMPOSTOR_OBJECTIVE, EMERGENCY, MEETING_BUTTON }
const LEGAL_TRANSITIONS: Dictionary = { ... }            # §2.1
static func is_legal_transition(from: GameState, to: GameState) -> bool
static func public_state_for(state: GameState, role: PlayerRole) -> GameState
```

**`shared/meltdown_config.gd` (M2)**: append to `GameOverReason`, **at the end** (int values of existing entries must not change): `IMPOSTOR_DISCONNECTED`, `MATCH_ABANDONED`. `CREW_ELIMINATED` stays in the enum but is only reachable when `kills.enabled == true`.

**Reject reason codes** (strings, used in `rpc_action_rejected`):
`wrong_phase`, `not_allowed_role`, `eliminated`, `too_far`, `too_fast`, `no_active_interaction`, `already_done`, `not_assigned`, `cooldown`, `disrupted`, `rate_limited`, `invalid`, `disabled`

**Action names** (strings): `set_ready`, `set_name`, `begin_interaction`, `cancel_interaction`, `complete_task`, `recover_system`, `complete_objective`, `complete_emergency`, `disrupt_emergency`, `activate_blackout`, `call_meeting`, `cast_vote`, `chat`, `inspect_evidence`, `kill`, `report_body`, `return_to_lobby`

---

## 4. Station registry — `shared/station_registry.gd`

**Owner:** M6 (content, data only) · **Consumers:** M1/M2 (server validation), M4 (station behaviour), M7 (placement), M8 (placement test).

```gdscript
class_name StationRegistry
extends RefCounted

const NetworkConfig = preload("res://shared/network_config.gd")

const STATIONS: Dictionary = {
	"task_repair_power": {
		"kind": NetworkConfig.InteractionKind.CREW_TASK,
		"target_id": "repair_power",
		"room_id": "generator_room",
		"position": Vector2(0, 0),        # world coords in facility_map.tscn space
		"radius": 72.0,                   # px; server allows radius + anti_cheat.range_slack_px
		"min_duration_sec": 8.0,          # server requires elapsed >= min * anti_cheat.min_duration_factor
		"display_name": "Repair Power"
	},
	# ... one entry for every station ID in §1.2
}

const DOORS: Dictionary = {
	"door_cafeteria_storage": {"position": Vector2(0, 0), "rooms": ["cafeteria", "storage"]},
	# ...
}

const EVIDENCE_ANCHORS: Dictionary = {  # location_id -> world position where the marker spawns
	"executive_office": Vector2(0, 0),
	# ... one per location_id used in EvidenceConfig
}

const SPAWN_POINTS: Array[Vector2] = [ ... ]   # exactly 8, index = player_slot - 1

static func get_station(station_id: String) -> Dictionary      # {} if unknown
static func has_station(station_id: String) -> bool
static func find_station_id(kind: int, target_id: String) -> String   # "" if none
static func get_all_station_ids() -> Array
static func get_door_ids() -> Array
static func get_evidence_anchor(location_id: String) -> Vector2  # Vector2.INF if unknown
static func get_spawn_point(player_slot: int) -> Vector2
```
`min_duration_sec` for Crew tasks comes from `design/specs/task_specifications.md` §1 (6–12s).
**Placement invariant (M8 tests it):** every `Stations/<id>`, `Doors/<id>`, `EvidenceAnchors/<id>` and `SpawnPoints/SpawnN` node in the world map is within 4px of its registry position.

---

## 5. Balance config — `shared/balance_config.gd`

**Owner:** M2 (loader code) · Values: M6 in `config/game_balance_config.json`

```gdscript
class_name BalanceConfig
extends RefCounted
static func load_from_file(path: String = "res://config/game_balance_config.json") -> bool
static func get_value(key: String, default_value: Variant) -> Variant   # dotted path, e.g. "blackout.duration_sec"
static func is_loaded() -> bool
static func set_override(key: String, value: Variant) -> void   # tests only: e.g. short timers, kills.enabled
static func clear_overrides() -> void                            # tests call this in teardown
```
Overrides win over the JSON and defaults, but `meltdown.duration_sec` stays forced to 300.0 **unless** the override is set (tests need short meltdowns). Production code must never call `set_override`.
- A leaf can be a raw value or a `{"value": X, "range": [lo, hi]}` object; `get_value` returns `X`. If `range` exists and `X` is outside it → `push_warning`, then clamp.
- A missing file or key returns `default_value` (the existing constant in `shared/*_config.gd`). The game must run with no JSON.
- **`meltdown.duration_sec` is forced to 300.0** whatever the JSON says (design rule #10).
- `ServerNetworkManager.start_server()` calls `BalanceConfig.load_from_file()` before `clear()`-ing managers. Managers read values in `clear()`/`setup()`.

| Key | Default | Used by |
|---|---|---|
| `task_system.crew_task_count` | 4 | TaskManager |
| `task_system.impostor_prerequisite_count` | 2 | TaskManager |
| `blackout.duration_sec` | 60.0 | BlackoutManager |
| `blackout.countdown_duration_sec` | 3.0 | BlackoutManager |
| `blackout.doors_jammed_count` | 2 | BlackoutManager (new) |
| `blackout_recovery.required_systems` | 3 | BlackoutRecoveryManager |
| `impostor_objectives.assigned_count` | 3 | ImpostorObjectiveManager |
| `investigation.duration_sec` | 45.0 | MeetingManager (new) |
| `meeting_voting.discussion_duration_sec` | 30.0 | MeetingManager |
| `meeting_voting.voting_duration_sec` | 30.0 | MeetingManager |
| `chat.max_length` | 200 | server chat + M5 input limit |
| `chat.min_interval_sec` | 1.0 | server chat |
| `meltdown.duration_sec` | 300.0 (forced) | MeltdownManager |
| `meltdown.disrupt_hold_sec` | 3.0 | min duration of the Impostor disrupt interaction |
| `meltdown.disrupt_duration_sec` | 12.0 | MeltdownManager (new) |
| `meltdown.disrupt_cooldown_sec` | 40.0 | MeltdownManager (new) |
| `orion_instability.per_objective_points` | `{"steal_confidential_files":15,"extract_orion_core_data":25,"disable_orion_containment":25,"sabotage_generator":20,"tamper_security":15}` | InstabilityTracker (new) |
| `orion_instability.per_blackout_second` | 0.2 | InstabilityTracker |
| `kills.enabled` | false | ServerNetworkManager (decision D1) |
| `anti_cheat.max_move_speed_px_s` | 250.0 | position validation (= `PlayerController.move_speed`) |
| `anti_cheat.position_tolerance_px` | 48.0 | position validation |
| `anti_cheat.range_slack_px` | 24.0 | station/evidence distance checks |
| `anti_cheat.min_duration_factor` | 0.8 | interaction handshake |
| `evidence.inspect_radius_px` | 80.0 | evidence inspection |
| `visibility.blackout_visibility_radius_normalized` | 0.35 | client vision radius during blackout (M3); clients read the JSON too |

---

## 6. `NetworkManager` autoload public API (M1 → used by M5 menu/lobby)

```gdscript
var is_dedicated_server: bool          # true when launched with --server
func host_game(port: int = NetworkConfig.DEFAULT_PORT, player_name: String = "") -> Error
	# spawns a headless server child process, then join_game("127.0.0.1", port, player_name)
	# retrying connection every 0.5s for up to 10s
func join_game(host: String, port: int = NetworkConfig.DEFAULT_PORT, player_name: String = "") -> Error
	# connects; after rpc_receive_player_assignment arrives, sends rpc_request_set_player_name
func leave_game() -> void               # disconnect; kills the spawned server child if we host
```
CLI: `godot --headless --path <project> -- --server [--port=7777]` → `NetworkManager._ready()` sees `--server` in `OS.get_cmdline_user_args()`, calls `start_server(port)`, sets `is_dedicated_server = true` and switches to `res://scenes/server_console.tscn` (minimal scene, M1).
`start_host()` / `connect_client()` stay for tests only. `host_game()` must **never** call `stop_network()` on the server it just started (audit C7).

---

## 7. RPC table

All RPCs live in `shared/network_manager.gd`. Client→server RPCs are `@rpc("any_peer", "call_remote", "reliable")` unless noted. Server→client RPCs are `@rpc("authority", "call_remote", "reliable")`.

### 7.1 Client → Server
| RPC | Status | Validation summary (full rules in §8) |
|---|---|---|
| `rpc_request_set_ready(is_ready: bool)` | keep | LOBBY only |
| `rpc_request_set_player_name(name: String)` | **new** | LOBBY only; sanitise (§8.9) |
| `rpc_request_begin_interaction(station_id: String)` | **new** | §8.1 |
| `rpc_request_cancel_interaction()` | **new** | clears the active interaction |
| `rpc_request_complete_task(task_id: String)` | keep + stricter | §8.2 (needs an active CREW_TASK interaction) |
| `rpc_request_recover_system(system_id: String)` | keep + stricter | §8.2 |
| `rpc_request_complete_impostor_objective(objective_id: String)` | keep + stricter | §8.2 |
| `rpc_request_complete_emergency_system(system_id: String)` | keep + stricter | §8.2 (Crew, not disrupted) |
| `rpc_request_disrupt_emergency_system(system_id: String)` | **new** | §8.3 |
| `rpc_request_activate_blackout()` | keep | BlackoutManager rules (BLACKOUT_AVAILABLE, Impostor, single use) |
| `rpc_request_call_meeting()` | keep + stricter | POST_BLACKOUT_INVESTIGATION, alive, within `meeting_button` radius |
| `rpc_request_cast_vote(target_peer_id: int)` | keep | VotingManager rules |
| `rpc_request_send_chat(text: String)` | **new** | §8.8 |
| `rpc_request_inspect_evidence(evidence_id: String)` | **new** | §8.7 |
| `rpc_send_player_position(pos, vel, facing)` | keep, `unreliable` + validated | §8.6 |
| `rpc_request_kill(target_peer_id: int)` | keep, **gated** | rejected with `disabled` unless `kills.enabled` |
| `rpc_request_report_body(corpse_id: int)` | keep, **gated** | as above; when enabled, only in POST_BLACKOUT_INVESTIGATION |
| `rpc_request_return_to_lobby()` | keep | GAME_OVER only |
| `rpc_request_sabotage(sabotage_type: int)` | **REMOVE** | M1 deletes it once M3 has switched Q to `request_activate_blackout` |

### 7.2 Server → Client
| RPC | Status | Recipients |
|---|---|---|
| `rpc_receive_player_assignment(id, slot, total)` | keep | the joining peer |
| `rpc_connection_rejected(reason)` | keep | the rejected peer |
| `rpc_sync_lobby_state(state, count, ready, players_info)` | keep; `players_info` dicts gain `display_name`, `color_index`; `state` is public | all |
| `rpc_game_state_changed(new_state)` | keep; **public state per recipient** | all |
| `rpc_receive_private_role(role)` | keep | owner |
| `rpc_receive_task_list(tasks)` / `rpc_receive_task_update(task_id, done)` | keep | owner |
| `rpc_notify_blackout_unlocked()` | keep | Impostor only |
| `rpc_sync_blackout_countdown(duration)` / `_cancelled(reason)` | keep | all |
| `rpc_notify_blackout_started(duration)` / `rpc_notify_blackout_ended()` | keep | all |
| `rpc_sync_recovery_initialization(...)` / `rpc_sync_recovery_update(...)` | keep | all |
| `rpc_receive_private_objective_list(objs)` / `_update(id, done)` | keep | Impostor only |
| `rpc_notify_investigation_started()` | keep | all |
| `rpc_sync_investigation_evidence(list)` | **REMOVE** (audit H9) | — |
| `rpc_sync_evidence_markers(markers: Array)` | **new** | all, on entering POST_BLACKOUT_INVESTIGATION |
| `rpc_receive_evidence_details(evidence: Dictionary)` | **new** | inspector only |
| `rpc_sync_meeting_started(caller, duration)` / `rpc_sync_voting_started(duration)` / `rpc_sync_player_voted(voter)` / `rpc_sync_vote_result(result)` | keep | all |
| `rpc_receive_chat(sender_peer_id: int, sender_name: String, text: String)` | **new** | all connected |
| `rpc_sync_meltdown_started(duration, impostor_alive)` / `rpc_sync_emergency_system_completed(id, list)` | keep | all |
| `rpc_sync_emergency_disrupted(system_id: String, remaining_sec: float)` | **new** (0 = cleared) | all |
| `rpc_sync_orion_instability(value: int)` | **new** | all, at MELTDOWN start |
| `rpc_sync_door_states(jammed_door_ids: Array)` | **new** | all, at blackout start (list) and end (`[]`) |
| `rpc_sync_timer(timer_id: int, remaining_sec: float)` | **new**, `unreliable` | all |
| `rpc_interaction_begin_accepted(station_id: String, mode: String)` | **new** | requester; `mode` ∈ `task`, `recovery`, `objective`, `repair`, `disrupt` |
| `rpc_action_rejected(action: String, reason_code: String, message: String)` | **new** | requester, on **every** rejected request |
| `rpc_correct_position(pos: Vector2)` | **new** | sender of a rejected position update; also at match start (spawn) |
| `rpc_sync_game_over(winner, reason, result)` | keep; `result` gains `player_roster` + `orion_instability` (§10) | all |
| `rpc_notify_player_connected/disconnected`, `rpc_receive_remote_player_position` | keep | all |
| `rpc_sync_player_eliminated`, `rpc_sync_corpse_spawn`, `rpc_sync_corpse_reported` | keep (only fire when kills are enabled, or for vote ejection) | all |
| `rpc_sync_sabotage_state`, `rpc_sync_round_state` | **REMOVE** | — |

---

## 8. Server validation rules (M1 implements the hub checks, M2 the manager rules)

**8.1 Begin interaction** — `station_id` must exist in `StationRegistry`. The requester must be connected, not eliminated, and within `radius + range_slack_px` of the station (using the server's last accepted position). Then, by kind:
- **CREW_TASK:** the requester owns an incomplete task instance whose `task_type_id == target_id`.
  - Crew: the state is INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE or BLACKOUT_ACTIVE.
  - Impostor prerequisite: INITIAL_TASK_PHASE only.
  - Mode `task`.
- **RECOVERY:** BLACKOUT_ACTIVE, Crew, the system isn't completed. Mode `recovery`.
- **IMPOSTOR_OBJECTIVE:** BLACKOUT_ACTIVE, Impostor, the objective is assigned to the requester and not completed. Mode `objective`.
- **EMERGENCY:** MELTDOWN, the system isn't completed.
  - Crew: mode `repair`; rejected with `disrupted` while the system is disrupted.
  - Impostor who is not ejected: mode `disrupt`; rejected with `cooldown` while on cooldown.
- **MEETING_BUTTON:** always rejected with `invalid`. Meetings use `rpc_request_call_meeting`.

On success: store `active_interactions[peer_id] = {station_id, kind, target_id, mode, started_msec}` (one per peer; a new begin replaces the old one) and send `rpc_interaction_begin_accepted`. On failure: `rpc_action_rejected("begin_interaction", code, msg)`. All active interactions are cleared on every game-state change.

**8.2 Complete** — the requester has an active interaction whose kind/target matches the request; the time since begin is at least `min_duration_sec * min_duration_factor` (else `too_fast`); the requester is still within range (else `too_far`). Then delegate to the manager (TaskManager / BlackoutRecoveryManager / ImpostorObjectiveManager / MeltdownManager) exactly as today, and clear the interaction.

**8.3 Disrupt** — active interaction in mode `disrupt` for that system; elapsed ≥ `meltdown.disrupt_hold_sec * factor`; then `MeltdownManager.request_disrupt(peer_id, system_id)` → broadcast `rpc_sync_emergency_disrupted`.

**8.4 Activate blackout** — unchanged BlackoutManager rules. This is the **only** way to start a blackout.

**8.5 Call meeting** — POST_BLACKOUT_INVESTIGATION, alive, within range of `meeting_button`. The investigation timer expiring calls the same code path with caller `0` (system).

**8.6 Position** — accept an update if `distance(last_pos, new_pos) <= max_move_speed_px_s * elapsed_sec * 1.25 + position_tolerance_px`. Otherwise reject: don't update, don't rebroadcast, and send `rpc_correct_position(last_pos)`. Until a player's first accepted position, their position = their spawn point (the server sets it at ROLE_ASSIGNMENT). **No proximity check may be skipped because a position is unknown or `Vector2.ZERO`** (audit H2).

**8.7 Inspect evidence** — POST_BLACKOUT_INVESTIGATION, alive, the evidence exists, the requester is within `evidence.inspect_radius_px + range_slack_px` of `EVIDENCE_ANCHORS[location_id]` → `rpc_receive_evidence_details(evidence.to_public_dict())` to the requester only.

**8.8 Chat** — MEETING or VOTING, sender alive; strip whitespace; length 1..`chat.max_length` (longer is rejected as `invalid`); at least `chat.min_interval_sec` since the sender's last message (else `rate_limited`) → `rpc_receive_chat` to all. Clients **must render chat as plain text** (no BBCode).

**8.9 Player name** — LOBBY only; strip; keep only `[A-Za-z0-9 _-]`; 1–16 chars; if empty use `Player <slot>`; if duplicated, append ` (2)`, ` (3)`… Stored in `PlayerConnectionData.display_name`.

---

## 9. `ClientNetworkManager` contract (M1 → used by M3, M4, M5, M7, M8)

### 9.1 Request methods (the only way client code talks to the server)
Keep: `set_ready`, `request_complete_task`, `request_activate_blackout`, `request_recover_system`, `request_complete_impostor_objective`, `request_call_meeting`, `request_cast_vote`, `request_complete_emergency_system`, `request_return_to_lobby`, `request_kill`, `request_report_body`.
Add:
```gdscript
func set_player_name(player_name: String) -> void
func begin_interaction(station_id: String) -> void
func cancel_interaction() -> void
func request_disrupt_emergency_system(system_id: String) -> void
func request_inspect_evidence(evidence_id: String) -> void
func send_chat(text: String) -> void
```
Remove (after M3 migrates): `request_sabotage`.
Client-side pre-checks must **match the server rules** (§8). Specifically, `request_complete_task` must allow INITIAL_TASK_PHASE, BLACKOUT_AVAILABLE and BLACKOUT_ACTIVE (audit C6).

### 9.2 New signals
```gdscript
signal action_rejected(action: String, reason_code: String, message: String)
signal interaction_begin_accepted(station_id: String, mode: String)
signal timer_synced(timer_id: int, remaining_sec: float)
signal chat_received(sender_peer_id: int, sender_name: String, text: String)
signal door_states_synced(jammed_door_ids: Array)
signal evidence_markers_received(markers: Array)
signal evidence_details_received(evidence: Dictionary)
signal emergency_system_disrupted(system_id: String, remaining_sec: float)
signal orion_instability_synced(value: int)
signal position_corrected(pos: Vector2)
```
Remove: `sabotage_state_synced`, `round_state_synced`, `sabotage_requested`, `investigation_evidence_received`.

### 9.3 New state and helpers
```gdscript
var display_name: String = ""
var timers: Dictionary = {}                 # TimerId -> remaining_sec (last sync)
var jammed_door_ids: Array = []
var evidence_markers: Array = []
var inspected_evidence: Dictionary = {}     # evidence_id -> details dict
var disrupted_systems: Dictionary = {}      # system_id -> remaining_sec
var orion_instability: int = 0
func get_task_instance_for_type(task_type_id: String) -> Dictionary  # {} if none/incomplete-not-found
func get_display_name(peer_id: int) -> String                        # from lobby_players_data
func get_color_index(peer_id: int) -> int
```
All of these reset in `reset_match_state()` and `_cleanup_connection()`.

---

## 10. Payload shapes

**Lobby player dict** (`PlayerConnectionData.to_dict()`; never includes `role`):
```gdscript
{"peer_id": int, "player_slot": int, "display_name": String, "color_index": int,
 "connected_at": float, "is_ready": bool, "is_alive": bool, "is_eliminated": bool}
```
**Evidence marker:** `{"evidence_id": String, "evidence_type": String, "location_id": String}`. No description, and no actor.
**Evidence details:** `EvidenceDefinition.to_public_dict()` (unchanged; it never includes the actor).
**Vote result:** unchanged (`eliminated_peer_id`, `was_impostor`, `is_tie`, `is_skip`, `votes_per_target`, `skip_count`, `total_votes_cast`).
**Game over `result_data`:** existing fields plus:
```gdscript
"player_roster": [{"peer_id": int, "player_slot": int, "display_name": String, "role": int,
                   "role_name": String, "is_alive": bool, "is_eliminated": bool}, ...],
"orion_instability": int
```
M1 fills `player_roster` in `ServerNetworkManager._on_game_over_triggered` before broadcasting (audit H3).

---

## 11. World scene node contract

The world is `res://scenes/main.tscn` (owner M3). It is entered from the lobby when the state becomes ROLE_ASSIGNMENT. The project main scene becomes `res://client/ui/menu/main_menu.tscn` (decision D6).

```
Main (Node2D, scenes/main.gd)                                     [M3]
├── FacilityMap   instance res://scenes/environment/facility_map.tscn   [M7]
│   ├── Stations/<station_id>        Node2D at the StationRegistry position   [M7 places]
│   │   ├── StationProp              visual states (intact/sabotaged/repairing/restored) [M7]
│   │   └── InteractableStation      instance res://client/interactions/interaction_framework/interactable_station.tscn [M4]
│   ├── Doors/<door_id>              instance res://scenes/objects/door.tscn   [M3 script, M7 places]
│   ├── EvidenceAnchors/<location_id> Marker2D                                 [M7]
│   ├── SpawnPoints/Spawn1..Spawn8   Marker2D                                  [M7]
│   └── Lighting                     FacilityLightingController                [M7]
├── Players (Node2D)                 local + remote PlayerController instances [M3]
├── SpawnManager (Node2D)            [M3]
├── StateSync (Node)                 [M3]
├── BlackoutLighting                 local-player vision only, no debug keys   [M3]
├── HUD                              instance res://client/ui/hud/hud.tscn     [M5]
└── InteractionLayer (CanvasLayer, layer = 20)
    └── InteractionController        instance res://client/interactions/interaction_framework/interaction_controller.tscn [M4]
```
- `InteractableStation` reads `radius`, `kind`, `target_id` and `display_name` from `StationRegistry.get_station(station_id)` in `_ready()`, where `station_id` = its parent node's name.
- `PlayerController` has a child `Visual` (instance `res://scenes/characters/player_visual.tscn`) and calls `set_color(color_index)`, `set_motion(velocity, facing)` and `set_ghost_mode(true)` when ejected.

**Groups**
| Group | Members |
|---|---|
| `players` | every PlayerController |
| `local_player` | **exactly one** node: the local PlayerController. Stations/triggers react **only** to this group (audit I3) |
| `stations` | every InteractableStation |
| `doors` | every door |
| `evidence_markers` | spawned EvidenceMarkers |

**Physics layers** (from `docs/environment_art_spec.md`): 1 world obstacles · 2 players · 3 interactables (stations: layer 3, mask 2) · 4 light occluders · 5 evidence markers.

---

## 12. Debug flags — `shared/debug_flags.gd` (M8)

```gdscript
class_name DebugFlags
extends RefCounted
static func hotkeys_enabled() -> bool:
	return OS.is_debug_build() and bool(ProjectSettings.get_setting("blackout/debug/enable_hotkeys", false))
```
**Every** debug key handler, in every module, must return early unless `DebugFlags.hotkeys_enabled()`. The default is **off**. Gameplay keys are reserved and must never be bound to debug actions: **W A S D, arrows, E (interact), F (flashlight), Q (activate blackout, Impostor), Esc (close modal), Enter (chat send)**.

---

## 13. Autoloads (`project.godot`, M1 edits, others request)

| Name | Script | Owner |
|---|---|---|
| `NetworkManager` | `res://shared/network_manager.gd` | M1 |
| `Audio` | `res://client/audio/audio_manager.gd` (the autoload must **not** be named `AudioManager`, because that clashes with its `class_name`) | M8 |

---

## 14. Implementation tracker (tick in your PR)

- [ ] §2.1 transition table + `is_legal_transition` (M1)
- [ ] §2.2 public state (M1)
- [ ] §2.3 timer sync (M1 server, M5 UI)
- [ ] §2.4 disconnect policy (M1, M2)
- [ ] §3 enums (M1, M2)
- [ ] §4 station registry content (M6) · placement (M7) · placement test (M8)
- [ ] §5 BalanceConfig loader (M2) · JSON keys (M6)
- [ ] §6 host/join API + `--server` (M1) · menu wiring (M5)
- [ ] §7/§8 new RPCs + validation (M1, M2)
- [ ] §9 client API/signals (M1)
- [ ] §10 payloads (M1)
- [ ] §11 world scene (M3) · stations (M4) · map anchors (M7) · HUD instance (M5)
- [ ] §12 debug flags (M8) · adopted by M3, M4, M5, M7
- [ ] §13 autoloads (M1, M8)
