# Member 3 — Aaliya — Lead Client & Gameplay Programmer · Fix Guide

**Branch:** `member-3/client-engine`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** C2 (client), C7 (world), C9, I1 (retire old stations), I5, I8 (retire your UI), I9, I11, F6 (client), F7 (P2), R6

You own **the world scene**, the one place where everyone's work finally meets. Today `scenes/main.tscn` is a single-player sandbox with its own map, its own UI and its own stations. Your job:
1. Turn it into the real game world, built from M7's map, M4's stations and M5's HUD, as specified in contracts §11.
2. Remove the duplicates you built.

---

## 1. Your files (you may edit)
- **Player:** `client/player/*` (`player_controller.gd`, `state_sync.gd`, `spawn_manager.gd`, `footstep_audio.gd` with M8), `scenes/player/player.tscn`
- **Environment:**
  - `client/environment/blackout_lighting_manager.gd`
  - `door_controller.gd`
  - `interactable_trigger.gd`
  - `player_corpse.gd`
  - `map_manager.gd`
  - `emergency_console.gd`
  - `test_terminal.gd`
- **Camera:** `client/camera/game_camera.gd`
- **World scene:** `scenes/main.tscn`, `scenes/main.gd`
- **Objects:** `scenes/objects/*` (`door.tscn` stays; the station scenes get retired)
- **Old map and stations (retire):** `scenes/map/facility_map.tscn`, `client/objectives/*`, `scenes/ui/*`
- **Your old UI (retire after M5 parity):** `client/ui/meeting_voting_ui.gd`, `client/ui/meltdown_hud.gd`, `client/ui/game_over_ui.gd`
- **Hand over to M5 (don't delete):** `client/ui/evidence_dossier_ui.gd`, `client/objectives/objective_tracker.gd`
- **Your tests:**
  - `test_player_controller`, `test_state_sync`, `test_spawn_manager`, `test_game_camera`
  - `test_door_controller`, `test_interactable_trigger`, `test_directional_vision`, `test_blackout_lighting`
  - `test_player_identity_visuals`, `test_multiplayer_game_over`, `test_multiplayer_evidence_dossier`

## 2. Not yours
- `scenes/environment/*`, `scenes/characters/*`, `scenes/vfx/*`, `assets/sprites/*` → **M7** (you instance them; you don't edit them)
- `client/interactions/*` → **M4**
- `client/ui/hud|meeting|screens|menu/*` → **M5**
- `client/client_network_manager.gd`, `shared/network_manager.gd` → **M1**
- `shared/station_registry.gd` → **M6**

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| Contract stubs (new client signals) | M1 Step 1 | 1, 5, 6 |
| Compat shim `request_sabotage → activate_blackout` or the final API | M1 Step 3 | 1 |
| Canonical map with collisions, `Stations/`, `Doors/`, `SpawnPoints/`, `EvidenceAnchors/`, `get_world_bounds()` | M7 Wave 1 | 3 |
| `interactable_station.tscn` + `interaction_controller.tscn` | M4 Wave 1–2 | 4 |
| `hud.tscn` compiling | M5 Wave 1 | 4 |
| `DebugFlags` | M8 Wave 0 | 1 |

| Others need from you | Step |
|---|---|
| Q key uses the real activation (lets M1 delete the sabotage path) | 1 |
| The world scene that M4/M5/M7 can test inside | 3, 4 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 1 | Remove the client-side bypasses: Q, B, K, Sabotage/Round refs, slot/peer bug, position correction | C2, C9, H1 (client), I11 |
| 2 | 1 | Player: `local_player` group, `PlayerVisual`, names, colours, ghost mode | I5 |
| 3 | 2 | Rebuild `scenes/main.tscn` on M7's map per contracts §11 | C7, I5, I9 |
| 4 | 2 | Mount M5's HUD + M4's InteractionLayer; delete your UI nodes | I8 |
| 5 | 2 | Scene flow: lobby → world → lobby/menu; no offline sandbox in release | C7 |
| 6 | 2 | Lighting split: M7 owns the room ambience, you own local vision only | C9, I5 |
| 7 | 2 | Doors react to `door_states_synced` | F6 |
| 8 | 2 end | Retire the old map, stations, consoles, test terminal and UI (with M8 for tests) | I1, I8, I9, R6 |
| 9 | 3 (P2) | Security camera console (only if M6 keeps FR-13) | F7 |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my coding agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 3 (Aaliya), Lead Client & Gameplay Programmer. My branch is member-3/client-engine. I own the world scene scenes/main.tscn.

Before writing any code:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md (especially §9 and §11), docs/fix-plan/member-3-client-engine.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-3/client-engine or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) which of my dependencies (M1 stubs, M7 map anchors, M4 station scenes, M5 HUD compile fix, M8 DebugFlags) already exist on origin/main. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY the files listed under "Your files" in my guide. Instance other members' scenes, but never edit them. If one needs a change, write a handoff note with the exact change.
- Client code never decides game outcomes. It only calls ClientNetworkManager request methods (contracts §9.1) and reacts to its signals (§9.2). Never read or write server objects from client code.
- Use node paths, groups, IDs and signal names EXACTLY as in 01-integration-contracts.md §11. If the contract is wrong or missing something, stop and tell me.
- Every debug key must be gated by DebugFlags.hotkeys_enabled() (contracts §12). Never bind debug actions to W A S D, arrows, E, F, Q, Esc, Enter.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session.
- After each step: list the changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today citing the audit IDs. Do not commit unless I say so.
```

---

### Step 1 — Remove the client-side bypasses (Wave 1) — C2, C9, H1, I11
**Do**
- **Q (Impostor only):** calls `client.request_activate_blackout()` only when `client.is_blackout_unlocked` and the state is BLACKOUT_AVAILABLE. Remove `try_trigger_sabotage` and every `SabotageManager` / `RoundManager` preload and use from `player_controller.gd` and `scenes/main.gd` (including the "ROUND:" label).
- **B:** delete the debug toggle in `blackout_lighting_manager.gd`, or gate it with `DebugFlags.hotkeys_enabled()`, and set `enable_debug_key = false`.
- **K:** only active when `BalanceConfig.get_value("kills.enabled", false)`. Hide it from the status text otherwise.
- **I11:** fix the peer/slot comparisons in `main.gd` `_on_network_player_eliminated`. Compare peer IDs with peer IDs.
- **Position correction:** on `client.position_corrected(pos)`, snap the local player to `pos`.

**Done when:** grepping your files for `SabotageManager`, `RoundManager`, `request_sabotage` and `KEY_B` finds nothing outside `DebugFlags`-gated code. Your suites pass. Tell M1 that Step 12 can proceed once M8 has handled the tests.

**Agent prompt**
```text
Do Step 1 of my guide (audit C2, C9, H1 client side, I11).
- client/player/player_controller.gd: the Q key (Impostor only) must call the ClientNetworkManager's request_activate_blackout() only when client.is_blackout_unlocked is true and client.current_game_state is BLACKOUT_AVAILABLE. Remove try_trigger_sabotage, the sabotage_triggered signal and the SabotageManager preload. The K key must do nothing unless BalanceConfig.get_value("kills.enabled", false) is true.
- scenes/main.gd: remove all SabotageManager/RoundManager usage (constants, round label updates, sabotage handlers); drive blackout visuals from client.blackout_started / blackout_ended instead. Fix _on_network_player_eliminated so it compares peer ids to peer ids (use client.assigned_peer_id and each player's assigned_peer_id), never slot ids. Update the status hint text so it only mentions keys that actually work.
- client/environment/blackout_lighting_manager.gd: remove the B debug toggle, or gate it with DebugFlags.hotkeys_enabled() (if shared/debug_flags.gd doesn't exist yet, remove it). Default enable_debug_key = false.
- Connect client.position_corrected to snap the local player to the corrected position.
Then grep my files for SabotageManager, RoundManager, request_sabotage, KEY_B and show the results. Run test_player_controller, test_blackout_lighting, test_directional_vision, test_state_sync and show the results. Some tests may assert the old sabotage behaviour: update the ones I own and list any that belong to others.
```

---

### Step 2 — Player identity and visuals (Wave 1) — I5
**Do**
- The local player joins group `local_player`; remote puppets never do.
- `player.tscn` gets a `Visual` child (instance of `res://scenes/characters/player_visual.tscn`, M7).
- `PlayerController` calls `Visual.set_color(color_index)`, `Visual.set_motion(velocity, facing)` every frame, and `Visual.set_ghost_mode(true)` when eliminated/ejected.
- The name label uses `client.get_display_name(peer_id)`.
- `SpawnManager` sets `assigned_peer_id`, `slot_id`, colour and name on remote players from lobby data.
- Remove the old polygon body visuals if PlayerVisual replaces them.

**Agent prompt**
```text
Do Step 2 (audit I5; contracts §1.3, §11 groups). In client/player/player_controller.gd and scenes/player/player.tscn:
- Add a child "Visual" instancing res://scenes/characters/player_visual.tscn. Call set_color(color_index) in setup, set_motion(velocity, facing_direction) every physics frame (use the interpolated velocity for remote players) and set_ghost_mode(true) in set_eliminated(true).
- The local player adds itself to group "local_player" (and "players"); remote puppets only "players".
- The name label shows ClientNetworkManager.get_display_name(assigned_peer_id); colour = get_color_index(peer_id).
- client/player/spawn_manager.gd: when spawning remote players, set assigned_peer_id, slot_id, color and name from lobby_players_data; place the local player at the spawn point for its slot.
Read scenes/characters/player_visual.gd first (Member 7's file, don't edit it) and use only its public methods. Run test_player_controller, test_spawn_manager, test_player_identity_visuals, test_character_animations and show the results.
```

---

### Step 3 — Rebuild the world scene on M7's map (Wave 2) — C7, I5, I9
**Do:** make `scenes/main.tscn` match contracts §11 exactly:
- `FacilityMap` = instance of `res://scenes/environment/facility_map.tscn`;
- `Players`, `SpawnManager`, `StateSync`, `BlackoutLighting`;
- camera limits from M7's `get_world_bounds()` (ask M7 if it's missing);
- `SpawnManager` uses `FacilityMap/SpawnPoints` (which M7 places from `StationRegistry.SPAWN_POINTS`).
- The old `scenes/map/facility_map.tscn` is no longer instanced; delete it in Step 8.

**Agent prompt**
```text
Do Step 3 (audit C7, I5, I9; contracts §11). Rebuild scenes/main.tscn to match the node tree in contracts §11 exactly: FacilityMap (instance res://scenes/environment/facility_map.tscn), Players (Node2D), SpawnManager, StateSync, BlackoutLighting. Leave the HUD and InteractionLayer slots for Step 4. Stop instancing res://scenes/map/facility_map.tscn.
Camera limits must come from FacilityMap.get_world_bounds(). If that method doesn't exist in scenes/environment/facility_map.gd (Member 7's file), stop and write the handoff note. Do not add it yourself.
SpawnManager must use the Marker2D children of FacilityMap/SpawnPoints (fallback: StationRegistry.get_spawn_point(slot)). Update scenes/main.gd for the new paths. Run a headless import and show SCRIPT ERROR lines, then run test_spawn_manager, test_game_camera, test_facility_map and show the results. Tell me which old tests reference scenes/map/facility_map.tscn so I can coordinate with M8.
```

---

### Step 4 — Mount the HUD + InteractionLayer; delete your UI nodes (Wave 2) — I8
**Do**
- Remove every node under `CanvasLayer` in `main.tscn`: StatusLabel, ObjectiveTracker, RolePanel, RoundPanel, MeetingVotingUI, MeltdownHUD, GameOverUI, EvidenceDossierUI.
- Add `HUD` (instance of M5's `res://client/ui/hud/hud.tscn`).
- Add `InteractionLayer` (a CanvasLayer at layer 20) with M4's `interaction_controller.tscn`.
- Connect `InteractionController.player_lock_requested(lock)` → `local_player.can_move = !lock`. Also lock movement while a meeting is active.
- Strip `main.gd` down to world orchestration only.

**Agent prompt**
```text
Do Step 4 (audit I8; contracts §11). In scenes/main.tscn delete every child of the old CanvasLayer (status/role/round labels, ObjectiveTracker, MeetingVotingUI, MeltdownHUD, GameOverUI, EvidenceDossierUI) and the CanvasLayer itself. Add HUD = instance of res://client/ui/hud/hud.tscn and InteractionLayer = CanvasLayer (layer 20) containing an instance of res://client/interactions/interaction_framework/interaction_controller.tscn. If either scene is missing or doesn't compile, stop and tell me who to ask (M5 / M4).
In scenes/main.gd: remove all UI code; connect InteractionController.player_lock_requested(lock) to the local player's can_move; also set can_move = false between client.meeting_started and client.vote_result_received. Keep only world orchestration: corpses (only if kills enabled), elimination visuals, lighting/door binding.
Run a headless import, then run the game world directly once (<GODOT> --path . scenes/main.tscn in debug) and tell me what errors print. Run my suites.
```

---

### Step 5 — Scene flow (Wave 2) — C7 · decision D6
**Do:** the world is entered from the lobby (M5 changes scene on ROLE_ASSIGNMENT).
- In `main.gd _ready()`: if not connected, show a message and go back to `res://client/ui/menu/main_menu.tscn`. The offline sandbox is only allowed when `DebugFlags.hotkeys_enabled()`.
- Apply state that arrived before the scene loaded: role, tasks, current state. Read these from the client's stored vars.
- On `game_state_changed(LOBBY)` → change scene to `res://client/ui/screens/lobby_room.tscn`.
- On `disconnected_from_server` → main menu.

**Agent prompt**
```text
Do Step 5 (audit C7; decision D6). In scenes/main.gd:
- In _ready(): if NetworkManager.is_client() is false, go back to res://client/ui/menu/main_menu.tscn with change_scene_to_file (deferred); allow an offline sandbox only when DebugFlags.hotkeys_enabled().
- Apply the state already received before the scene loaded (client.assigned_role, assigned_tasks, current_game_state, is_blackout_active, jammed_door_ids) instead of waiting for signals.
- On client.game_state_changed(LOBBY) change scene to res://client/ui/screens/lobby_room.tscn; on client.disconnected_from_server go to the main menu.
Make scene changes deferred and make sure no signal connection outlives the scene (disconnect in _exit_tree or use CONNECT_ONE_SHOT where appropriate). Run a headless import and my suites, then describe the manual check: host from the menu, join with 7 more instances via tools/launch_local_match, reach the world, finish, return to lobby.
```

---

### Step 6 — Lighting split (Wave 2) — C9, I5
**Do:** there are two lighting systems. Split them like this:
- **M7's `FacilityLightingController`** (inside the map) owns the `CanvasModulate`, room lights and sirens.
- **Your `BlackoutLightingManager`** owns **only** the local player's vision light and flashlight radius. During blackout it shrinks to `visibility.blackout_visibility_radius_normalized`.
- Remove your manager's `CanvasModulate`.
- Both react only to `client.blackout_started/ended` and `meltdown_started`. No keys.

**Agent prompt**
```text
Do Step 6. Read scenes/environment/facility_lighting_controller.gd (Member 7, don't edit) and client/environment/blackout_lighting_manager.gd. Make BlackoutLightingManager responsible ONLY for the local player's vision/flashlight lights: remove its CanvasModulate creation, and shrink the vision radius to BalanceConfig "visibility.blackout_visibility_radius_normalized" (default 0.35) of normal during blackout, restoring on blackout_ended. Bind only to ClientNetworkManager signals. Make sure the map's FacilityLightingController is bound too; if it needs a bind call, do it from scenes/main.gd. If the controller lacks a method you need, write the handoff note to M7. Run test_blackout_lighting, test_directional_vision, test_facility_lighting_controller.
```

---

### Step 7 — Doors (Wave 2) — F6
**Do:** each `Doors/<door_id>` node (placed by M7) jams or unjams on `client.door_states_synced(jammed_ids)`. A jammed door is closed + jammed; an unjammed door returns to closed and usable. Apply `client.jammed_door_ids` on scene load too.

**Agent prompt**
```text
Do Step 7 (audit F6; contracts §7.2 rpc_sync_door_states, §11 Doors/<door_id>). In client/environment/door_controller.gd add a door_id (default: the node name) and join group "doors". In scenes/main.gd connect client.door_states_synced(jammed_ids) so every door in group "doors" calls set_jammed(door_id in jammed_ids) (closing it first if jamming). Also apply client.jammed_door_ids once in _ready. Tests in tests/test_door_controller.gd for jam/unjam by id. Run it.
```

---

### Step 8 — Retire duplicates (end of Wave 2) — I1, I8, I9, R6
Only after M4 has all stations on `InteractableStation` in the M7 map, and M5 confirms UI parity (tick the list in M5's guide Step 7).
**Delete:**
- `scenes/map/facility_map.tscn`
- `client/environment/map_manager.gd`, `emergency_console.gd`, `test_terminal.gd`
- `scenes/objects/*_station.tscn`, `electrical_junction.tscn`, `emergency_console.tscn`, `test_terminal.tscn`
- `client/objectives/objective_interactable.gd`, `task_step.gd`
- `scenes/ui/*`
- `client/ui/meeting_voting_ui.gd`, `meltdown_hud.gd`, `game_over_ui.gd`

**Hand to M5:** `evidence_dossier_ui.gd`, `objective_tracker.gd`, if M5 still wants them.
Agree test deletions with M8 **in the same PR**.

**Agent prompt**
```text
Do Step 8 (audit I1, I8, I9, R6). First grep the whole repo (scripts, .tscn, tests) for references to each file on the delete list in my guide. Show me the reference table (file -> referenced by). Do not delete anything that is still referenced from a scene/script outside tests. For references inside tests, list the test files so I can agree with M8 whether to delete or rewrite them. After I confirm, delete the files (and their .uid files), run a headless import and show SCRIPT ERROR lines (expect none), then run the full test runner.
```

---

### Step 9 — Security cameras (Wave 3, P2) — F7
Only if M6's decision record keeps FR-13. This first needs a contracts PR from M6 adding a `camera_console` station and its kind. It is a client-only feature: a console in `security_room` opens a panel of SubViewports that follow each room. It is unavailable while the client's state is BLACKOUT_ACTIVE.
```text
Do Step 9 (audit F7). Confirm contracts now define the camera_console station; if not, stop. Implement a client-only camera panel: when the local player interacts with camera_console (via M4's station scene) open a panel showing 4 SubViewport feeds of rooms chosen by M6 in the registry; refuse to open, and show "CAMERAS OFFLINE", while current_game_state is BLACKOUT_ACTIVE; close automatically when blackout starts. No server changes. Add a test for the offline rule.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main as a strict reviewer:
1) git diff origin/main...HEAD --stat. Flag any file not in "Your files" of docs/fix-plan/member-3-client-engine.md.
2) Check scenes/main.tscn against contracts §11 (node names, instanced scene paths, groups). List differences.
3) Search the diff for: direct access to NetworkManager.server from client code, SabotageManager/RoundManager, ungated debug keys, reserved keys bound to debug actions, signal connections never disconnected on scene exit, slot-vs-peer comparisons.
4) Run a headless import and all my suites (or the full runner). Paste the results.
5) Draft the PR description (template in docs/fix-plan/README.md §5) with audit IDs, handoff notes and the PROJECT_STATUS.md §7 entry.
```

## 7. Handoff notes you will likely need to send
- **M7:** `get_world_bounds()` on `facility_map.gd`; all anchors named per registry; a bind method on `FacilityLightingController` if one is missing.
- **M4:** `interaction_controller.tscn` + `interactable_station.tscn` paths; stations must react only to group `local_player`.
- **M5:** "your HUD is mounted at `Main/HUD`"; parity checklist for the UI you're deleting.
- **M8:** test files to delete/rewrite (`test_task_stations`, `test_multi_step_objective`, `test_objective_interactable`, `test_objective_tracker`, `test_meeting_voting_ui`, `test_meltdown_hud_and_consoles`, `test_game_over_ui`, `test_evidence_dossier_ui`, `test_sabotage_system`, `test_round_loop_foundation`).
