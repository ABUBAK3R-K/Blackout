# Member 4 — Ubaid — Client Interaction & Mini-Game Programmer · Fix Guide

**Branch:** `member-4/mini-games`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** C5 (meeting button), I1, I2, I3, F2, F3, F5 (client), plus the evidence-inspect interaction

Your framework is well designed: `MiniGameFactory`, `InteractionController` and the 22 mini-games dispatch to the right request methods. **None of it is used in the game.** The world still uses M3's "press E three times" stations. Your job:
1. Make `InteractableStation` the only station type in the world.
2. Make it follow the server handshake (begin → mini-game → complete).
3. Make it show the right thing to the right role in the right phase.

---

## 1. Your files (you may edit)
- `client/interactions/**`:
  - `interaction_framework/*`
  - `mini_game_factory.gd`
  - `mini_games/**`
  - `sabotage_interactions/**`
  - `mini_game_showcase.*`
- **New:**
  - `client/interactions/interaction_framework/interactable_station.tscn`
  - `client/interactions/interaction_framework/interaction_controller.tscn`
  - `client/interactions/evidence_spawner.gd`
  - `client/interactions/mini_games/meltdown/mg_disrupt_emergency.gd`
- Tests: `tests/test_member_4_interactions.gd`, plus any new `tests/test_interaction_*.gd`

## 2. Not yours
- `scenes/environment/*` (StationProp, EvidenceMarker, the map) → **M7**. You call their public methods and instance their scenes.
- `scenes/main.tscn` → **M3**. M3 mounts your `interaction_controller.tscn`.
- `client/client_network_manager.gd` → **M1**. You only call contracts §9.1 methods.
- `shared/station_registry.gd` → **M6**
- HUD toasts / dossier → **M5**

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| Contract stubs: `begin_interaction`, `interaction_begin_accepted`, `action_rejected`, `get_task_instance_for_type` | M1 Step 1 | 2 |
| `StationRegistry` with every station ID | M6 Wave 0 | 1 |
| Server handshake live (for real testing) | M1 Step 7 | 2, 3 |
| Map `Stations/<id>` nodes with a StationProp | M7 Wave 1 | 1, 7 |
| `EvidenceMarker` scene API | M7 | 6 |
| Disruption server side | M2 Step 9 + M1 Step 11 | 4 |

| Others need from you | Step |
|---|---|
| `interactable_station.tscn` (M7 places it in every station node) | **1** |
| `interaction_controller.tscn` (M3 mounts it) | **1** |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 1 | Station + controller scenes; registry-driven config; local player only | I3 |
| 2 | 1 | Handshake (begin → accepted → mini-game → complete / cancel); correct task-instance IDs | I2, I4 |
| 3 | 1 | Visibility rules by role and phase + Impostor "cover" mode | F2, F3 |
| 4 | 2 | Emergency stations: Crew repair / Impostor disrupt; locked state | F5 |
| 5 | 2 | Meeting button station | C5 |
| 6 | 2 | Evidence markers: spawn + inspect | H9 (client) |
| 7 | 2 | Drive M7 StationProp visual states from server events | I5 |
| 8 | 2 | Mini-game hygiene: durations ≥ server minimum, debug keys gated, audio hooks | D12 |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my coding agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 4 (Ubaid), Client Interaction & Mini-Game Programmer. My branch is member-4/mini-games. I own client/interactions/.

Before writing any code:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md (especially §1.2, §4, §8.1-8.3, §9, §11), docs/fix-plan/member-4-mini-games.md.
2. Read my framework: client/interactions/interaction_framework/*.gd and client/interactions/mini_game_factory.gd.
3. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-4/mini-games or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
4. Reply with: (a) my audit IDs, (b) my step list with waves, (c) which dependencies (M1 contract stubs, M6 station_registry.gd, M7 map Stations/ nodes) exist on origin/main. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY files under client/interactions/ and my tests. Never edit M7's scenes, M3's world scene or M1's network code. Write handoff notes instead.
- The client NEVER decides success. A mini-game finishing only means "ask the server". Use only the ClientNetworkManager methods in contracts §9.1 and react to §9.2 signals.
- Station IDs, kinds, target IDs and radii come from StationRegistry (contracts §4). Never hardcode station positions or IDs in scripts.
- Stations react ONLY to bodies in group "local_player" (contracts §11).
- Debug keys must be gated by DebugFlags.hotkeys_enabled(); never bind W A S D, arrows, E, F, Q, Esc, Enter to debug.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session.
- After each step: list the changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today citing the audit IDs. Do not commit unless I say so.
```

---

### Step 1 — Station + controller scenes, registry-driven, local player only (Wave 1) — I3
**Do**
- Create `interactable_station.tscn`: an `InteractableStation` (Area2D, collision layer 3, mask 2) with a `CollisionShape2D` circle.
- In `_ready()`: `station_id = get_parent().name` unless set. Read `kind`, `target_id`, `display_name` and `radius` from `StationRegistry.get_station(station_id)` and set the circle radius. `push_error` if the ID is unknown.
- `_on_body_entered/_exited`: react only if `body.is_in_group("local_player")` (fixes I3).
- Map `NetworkConfig.InteractionKind` onto the existing `StationType` (or replace `StationType` with `InteractionKind`).
- Create `interaction_controller.tscn`: `InteractionController`, full-rect, mouse filter ignore. It binds itself to `/root/NetworkManager.client` in `_ready()`.
- Join group `stations`.

**Agent prompt**
```text
Do Step 1 (audit I3; contracts §4, §11).
1) Create client/interactions/interaction_framework/interactable_station.tscn: root InteractableStation (Area2D, collision_layer = layer 3 only, collision_mask = layer 2 only) with a CollisionShape2D using a CircleShape2D.
2) In interactable_station.gd: if station_id is empty use get_parent().name; load kind/target_id/display_name/radius from StationRegistry.get_station(station_id) (push_error and disable if unknown); set the circle radius; add to group "stations". Replace StationType with NetworkConfig.InteractionKind (keep a compatibility mapping only if existing tests need it). React in _on_body_entered/_on_body_exited ONLY when body.is_in_group("local_player"). Remove the name-contains-"player" check.
3) Create client/interactions/interaction_framework/interaction_controller.tscn: InteractionController (Control, full rect anchors, mouse_filter IGNORE). In _ready, if client_network_manager is null, bind to get_node_or_null("/root/NetworkManager").client.
4) Remove _find_interaction_controller's full-tree recursive search: find the controller via the group "interaction_controller" (add the controller to that group).
Update tests/test_member_4_interactions.gd for these behaviours (a body not in local_player must not trigger; radius comes from the registry). Run it and show the results. If shared/station_registry.gd doesn't exist yet, stop and tell me.
```

---

### Step 2 — Handshake + correct IDs (Wave 1) — I2, I4, D12
**Do:** the new interaction flow is:
1. E pressed → local availability check (Step 3) → `client.begin_interaction(station_id)` → show "Connecting…" on the prompt.
2. On `client.interaction_begin_accepted(station_id, mode)`: mount the mini-game for `mode`:
   - `task` → `MiniGameFactory.create_task_mini_game(target_id)`
   - `recovery` / `objective` / `repair` → the matching factory method
   - `disrupt` → Step 4
3. On `client.action_rejected("begin_interaction", code, msg)` → show the reason on the prompt for 2s. Don't mount.
4. On mini-game completed, send the completion request:
   - **task:** `client.request_complete_task(instance_id)` where `instance_id = client.get_task_instance_for_type(target_id)["task_id"]` (**fixes I2**);
   - recovery: `request_recover_system(target_id)`;
   - objective: `request_complete_impostor_objective(target_id)`;
   - repair: `request_complete_emergency_system(target_id)`.
5. On cancel, interrupt, fail or walking out of range → `client.cancel_interaction()`.
6. The station UI shows success only when the server confirms (`task_completed_locally`, `recovery_system_updated`, `impostor_objective_updated`, `emergency_system_completed`), not when the mini-game ends.

**Agent prompt**
```text
Do Step 2 (audit I2, I4; decision D12; contracts §8.1-8.2, §9). Change the flow in interactable_station.gd + interaction_controller.gd to:
E -> availability check (stub it to true for now, Step 3 fills it) -> client.begin_interaction(station_id) -> wait. On client.interaction_begin_accepted(station_id, mode) mount the mini-game for that mode via MiniGameFactory (task/recovery/objective/repair; disrupt is Step 4). On client.action_rejected with action "begin_interaction" show the reason on the prompt for 2 seconds and don't mount.
On mini-game completion send exactly one request: task -> request_complete_task(client.get_task_instance_for_type(target_id)["task_id"]) (never the station id); recovery -> request_recover_system(target_id); objective -> request_complete_impostor_objective(target_id); repair -> request_complete_emergency_system(target_id). On cancel/interrupt/fail/leaving range -> client.cancel_interaction().
Only show "completed" on the station after the matching server confirmation signal. Ignore begin_accepted for a station that isn't the one currently waiting.
Write tests with a fake ClientNetworkManager (a Node exposing the same signals/methods) asserting: the begin is sent first; the task instance id (not the station id) is sent on completion; a rejection shows the message and mounts nothing; cancel is sent on interrupt. Run the suite.
```

---

### Step 3 — Who sees what, when (Wave 1) — F2, F3
**Do:** the availability rules below mirror server contracts §8.1, so players don't spam requests the server will reject.

| Kind | Prompt visible to | When |
|---|---|---|
| CREW_TASK | anyone who has an incomplete task of that type | Crew: INITIAL / AVAILABLE / ACTIVE. Impostor: INITIAL only |
| RECOVERY | Crew | BLACKOUT_ACTIVE, not completed |
| IMPOSTOR_OBJECTIVE | **Impostor only**, and only for assigned objectives | BLACKOUT_ACTIVE, not completed |
| EMERGENCY | Crew (repair) / non-ejected Impostor (disrupt) | MELTDOWN, not completed |
| MEETING_BUTTON | alive players | POST_BLACKOUT_INVESTIGATION |

- **Crew never see an objective prompt.** To them an objective station must look like an ordinary terminal.
- **Impostor "cover" mode:** at a Crew task station where the Impostor has no valid task (e.g. after unlocking), E opens the mini-game **locally** with no server call and sends nothing on completion. This lets them fake-task in front of witnesses (design §3.2).

**Agent prompt**
```text
Do Step 3 (audit F2, F3; contracts §8.1). Implement InteractableStation.is_available_for_local_player() -> bool using only ClientNetworkManager state (assigned_role, current_game_state, is_eliminated, assigned_tasks via get_task_instance_for_type, assigned_blackout_objectives, active_recovery_systems, completed_emergency_systems), following the table in my guide Step 3. Show the prompt only when available. Crew must never see a prompt, label or highlight on IMPOSTOR_OBJECTIVE stations.
Add Impostor cover mode: when the local player is the Impostor at a CREW_TASK station with no valid server task, E opens the same mini-game locally without calling begin_interaction, and on completion sends nothing. Make sure cover mode is indistinguishable on screen from a real task.
Re-evaluate availability on game_state_changed, task/objective/recovery/emergency updates and role assignment. Tests for every row of the table + cover mode. Run them.
```

---

### Step 4 — Emergency repair / disrupt (Wave 2) — F5
**Do**
- `mode == "disrupt"` → new `mg_disrupt_emergency.gd`: hold E for `meltdown.disrupt_hold_sec`, then call `client.request_disrupt_emergency_system(target_id)`.
- Crew prompt while disrupted: "SYSTEM LOCKED — Ns", driven by `client.emergency_system_disrupted`.
- Register the new mini-game in `MiniGameFactory` as `create_disrupt_mini_game(system_id)`.

**Agent prompt**
```text
Do Step 4 (audit F5; decision D11; contracts §8.3). Create client/interactions/mini_games/meltdown/mg_disrupt_emergency.gd extending MiniGameBase: hold the interact key for BalanceConfig "meltdown.disrupt_hold_sec" (default 3.0); releasing early cancels. On completion call client.request_disrupt_emergency_system(target_id). Add MiniGameFactory.create_disrupt_mini_game(system_id). Mount it when begin is accepted with mode "disrupt". For Crew, show "SYSTEM LOCKED — Ns" on the emergency station while client.disrupted_systems has that system (update from client.emergency_system_disrupted). Tests for the hold/cancel logic and the locked prompt. Run them.
```

---

### Step 5 — Meeting button (Wave 2) — C5
**Do:** at the `meeting_button` station (MEETING_BUTTON kind, no mini-game), E → `client.request_call_meeting()`. The prompt reads "CALL EMERGENCY MEETING" in POST_BLACKOUT_INVESTIGATION and is hidden otherwise.

**Agent prompt**
```text
Do Step 5 (audit C5; contracts §8.5). For stations of kind MEETING_BUTTON: no mini-game and no begin_interaction; E calls client.request_call_meeting() directly. The prompt "CALL EMERGENCY MEETING" is visible only to alive players in POST_BLACKOUT_INVESTIGATION. Show action_rejected("call_meeting", ...) messages on the prompt. Test it. Run the suite.
```

---

### Step 6 — Evidence markers (Wave 2) — H9 client side · decision D7
**Do:** new `client/interactions/evidence_spawner.gd`.
- On `client.evidence_markers_received(markers)`: for each marker, instance M7's `res://scenes/environment/evidence_marker.tscn` under `FacilityMap/EvidenceAnchors/<location_id>`, call `setup_from_type(evidence_type, location_id)`, and add it to group `evidence_markers`.
- Inspecting: local player in range + E → `client.request_inspect_evidence(evidence_id)`. The details arrive via `evidence_details_received` and M5's dossier shows them.
- Markers stay visible until the match returns to LOBBY, but inspection only works in POST_BLACKOUT_INVESTIGATION.
- **M3 adds the spawner node to the world**; tell M3.

**Agent prompt**
```text
Do Step 6 (audit H9 client side; decision D7; contracts §7.2, §8.7, §10). Create client/interactions/evidence_spawner.gd (Node). It binds to the ClientNetworkManager; on evidence_markers_received(markers) it instances res://scenes/environment/evidence_marker.tscn (Member 7's scene: read evidence_marker.gd and use only its public API) under the node at FacilityMap/EvidenceAnchors/<location_id>, calls setup_from_type(evidence_type, location_id), stores evidence_id on it, and adds it to group "evidence_markers". When the local player (group local_player) is in range and presses E during POST_BLACKOUT_INVESTIGATION, call client.request_inspect_evidence(evidence_id) and mark it inspected on evidence_details_received. Free all markers on game_state LOBBY. If EvidenceMarker lacks a signal or method you need, write the handoff note to M7. Tests with a fake client. Draft a handoff note to M3: "add an EvidenceSpawner node to scenes/main.tscn".
```

---

### Step 7 — StationProp visual states (Wave 2) — I5
**Do:** each station's sibling `StationProp` (M7) shows state. The mapping:

| Situation | StationProp state |
|---|---|
| default | `intact` |
| local mini-game open at this station | `repairing` |
| recovery system not yet restored during BLACKOUT_ACTIVE | `sabotaged` |
| recovery or emergency completed (server confirmed) | `restored` |
| emergency disrupted | `sabotaged` |
| objective station after its evidence marker appears | `sabotaged` (visible to all; it's physical evidence) |

**Agent prompt**
```text
Do Step 7 (audit I5). Read scenes/environment/station_prop.gd (Member 7's, don't edit). From InteractableStation, find the sibling StationProp (get_parent().get_node_or_null("StationProp")) and call set_visual_state() using the mapping table in my guide Step 7, driven only by ClientNetworkManager signals and the local mini-game lifecycle. If StationProp is missing, do nothing (no errors). Tests with a fake client + a StationProp instance. Run them.
```

---

### Step 8 — Mini-game hygiene (Wave 2) — D12
**Do**
- **Every mini-game's fastest possible completion must be ≥ its station's `min_duration_sec × anti_cheat.min_duration_factor`.** Otherwise the server rejects with `too_fast`. Measure each; pad with a short "syncing…" bar where needed.
- Gate every debug key in mini-games and the showcase with `DebugFlags`.
- Connect stations and mini-games to audio: `Audio.connect_station(station)` / `Audio.connect_mini_game(mg)` once M8 lands the `Audio` autoload.

**Agent prompt**
```text
Do Step 8 (decision D12). For each of the 22 mini-games + mg_disrupt_emergency, determine the fastest possible completion time with perfect input (read the code; if needed simulate inputs in a headless test) and compare it to StationRegistry min_duration_sec * BalanceConfig "anti_cheat.min_duration_factor" for the station that uses it. Produce a table. For any mini-game that can finish faster, add a final non-skippable "syncing" progress segment to cover the gap. Gate every debug key in client/interactions/** with DebugFlags.hotkeys_enabled(). If /root/Audio exists, call Audio.connect_station(self) in InteractableStation._ready and Audio.connect_mini_game(mini_game) when mounting. Run test_member_4_interactions and show the table + results.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main as a strict reviewer:
1) git diff origin/main...HEAD --stat. Flag any file outside client/interactions/ and my tests.
2) Check every request call against contracts §9.1 and every ID against §1.2/§4. Flag any station id sent where a task instance id is expected, any hardcoded station id/position, and any completion sent without a prior accepted begin (except cover mode, which must send nothing).
3) Confirm that Crew can never see objective prompts and that stations react only to group local_player.
4) Run a headless import and test_member_4_interactions + any new interaction tests. Paste the results.
5) Draft the PR description (template in docs/fix-plan/README.md §5) with audit IDs, handoff notes (M3, M7, M5) and the PROJECT_STATUS.md §7 entry.
```
