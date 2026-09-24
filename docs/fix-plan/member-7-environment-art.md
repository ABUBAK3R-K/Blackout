# Member 7 — Fatima — 2D Environment & Technical Artist · Fix Guide

**Branch:** `member-7/environment-art` (it has 1 unmerged docs commit, `f5b9dd2`. Merge `origin/main` into it first.)
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** I5, I9, F2/F3 (placement), plus doors, anchors, lighting/VFX binding

Your 9-room map, 8-colour character sheets, lighting controller, station props, evidence markers and VFX are all built, and all tested in isolation. **None of it is used by the game** (I5). The world still runs on M3's placeholder map. Decision D4 makes **your map the canonical world**. Your job:
1. Make it gameplay-ready: collisions, doors, every station/anchor/spawn at the registry positions.
2. Bind your lighting and VFX to real server events.

---

## 1. Your files (you may edit)
- `scenes/environment/*`:
  - `facility_map.tscn/.gd`
  - `facility_lighting_controller.*`
  - `station_prop.*`, `evidence_marker.*`, `room_prop.*`
  - `player_flashlight.*`, `vignette_overlay.*`
  - `blackout_lighting.tscn`, `facility_tileset.tres`
- `scenes/characters/*` (`player_visual.*`)
- `scenes/vfx/*`
- `assets/sprites/**`, `assets/vfx/**`
- `docs/environment_art_spec.md`
- Your tests:
  - `tests/test_facility_map.gd`
  - `test_facility_lighting_controller.gd`
  - `test_environment_tileset_props.gd`
  - `test_station_evidence_visuals.gd`
  - `test_character_animations.gd`
  - `test_vfx_shaders.gd`
- **New (optional):** `tools/build_map_anchors.gd` (an editor script that places nodes from the registry)

## 2. Not yours
- `shared/station_registry.gd` → **M6**. It is the source of truth for positions. If a position doesn't work with the art, ask M6 to change the registry; don't just move the node.
- `client/interactions/interaction_framework/interactable_station.tscn` → **M4**. You instance it; you don't edit it.
- `scenes/objects/door.tscn` + `client/environment/door_controller.gd` → **M3**. You instance and place doors.
- `scenes/main.tscn` → **M3**

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| `shared/station_registry.gd` | M6 Wave 0 | 2 |
| `interactable_station.tscn` | M4 Step 1 | 2 |
| Contract stubs (client signals for lighting/VFX) | M1 Step 1 | 4, 5 |
| `DebugFlags` | M8 | 4 |

| Others need from you | Step | Blocks |
|---|---|---|
| Map with collisions + `get_world_bounds()` | **1** | M3 Step 3 |
| `Stations/`, `Doors/`, `SpawnPoints/`, `EvidenceAnchors/` placed | **2** | M3, M4, M8 placement test |
| EvidenceMarker API | 6 | M4 Step 6 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 1 | Gameplay-ready map: walls/collisions, door gaps, containers per contracts §11, `get_world_bounds()` | I9 |
| 2 | 1 | Place every station/door/spawn/evidence anchor from the registry | F2, F3, I5 |
| 3 | 1–2 | Art for the station types that have none (recovery, objectives, emergency, meeting button) | F2, F3 |
| 4 | 2 | Lighting bound to the server; owns CanvasModulate; no debug keys | I5 |
| 5 | 2 | VFX bound to events (countdown strobe, sparks, steam, meltdown overlay × instability) | I5, F4 |
| 6 | 2 | EvidenceMarker + StationProp public APIs confirmed for M4 | I5 |
| 7 | 2 | PlayerVisual final API for M3 (colours, motion, ghost) | I5 |
| 8 | 3 | Reimport on Godot 4.4.1, asset hygiene, update your tests | R1 |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my agent on the BLACKOUT project (Godot 4.4, GDScript, 2D top-down, server-authoritative multiplayer). The repo root is the current directory.
I am Member 7 (Fatima), 2D Environment & Technical Artist. My branch is member-7/environment-art. My map scenes/environment/facility_map.tscn is now the canonical game world map.

Before doing anything:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md (especially §1, §4, §11, §12), docs/fix-plan/member-7-environment-art.md, docs/environment_art_spec.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline origin/main..HEAD; git log --oneline -1 origin/main.
   If I'm not on member-7/environment-art or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) whether shared/station_registry.gd (M6) and interactable_station.tscn (M4) exist on origin/main yet. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY my files (scenes/environment, scenes/characters, scenes/vfx, assets/sprites, assets/vfx, docs/environment_art_spec.md, my tests). Instance other members' scenes, but never edit them.
- Positions of stations, doors, anchors and spawns come ONLY from shared/station_registry.gd. Never hand-place a gameplay node at a different position. If the art needs a change, write a note to Member 6.
- Node names and container paths must match contracts §11 exactly (Stations/<station_id>, Doors/<door_id>, EvidenceAnchors/<location_id>, SpawnPoints/Spawn1..Spawn8, Lighting).
- Visuals react only to ClientNetworkManager signals (contracts §9.2). Visual code never changes game state.
- Debug keys only behind DebugFlags.hotkeys_enabled().
- Keep physics layers per contracts §11: 1 world, 2 players, 3 interactables, 4 light occluders, 5 evidence.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session.
- After each step: list changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today. Do not commit unless I say so.
```

---

### Step 1 — Gameplay-ready map (Wave 1) — I9
**Do**
- Wall collisions (layer 1) around every room, with **gaps where doors go** (at the registry door positions).
- Light occluders (layer 4) on the walls.
- An outer boundary so players can't leave.
- The containers from contracts §11: `Stations`, `Doors`, `EvidenceAnchors`, `SpawnPoints`, `Lighting`.
- Add `get_world_bounds() -> Rect2` (the union of the room rects + wall thickness) to `facility_map.gd` for M3's camera.

**Agent prompt**
```text
Do Step 1 (audit I9; contracts §11). In scenes/environment/facility_map.tscn/.gd:
- Ensure every room is enclosed by StaticBody2D walls on physics layer 1 (and LightOccluder2D on layer 4), leaving door-sized gaps (48-64px) at the door positions listed in shared/station_registry.gd DOORS (if the registry isn't on main yet, stop and tell me). Add an outer boundary.
- Ensure these direct children exist with exactly these names: Stations, Doors, EvidenceAnchors, SpawnPoints, Lighting (move the existing FacilityLightingController under Lighting if needed, and update your own references).
- Add get_world_bounds() -> Rect2 returning the union of ROOM_DEFINITIONS bounds grown by the wall thickness.
Extend tests/test_facility_map.gd: the containers exist; get_world_bounds contains every room; a CharacterBody2D test body on layer 2 moving from the Cafeteria centre straight up for 3 seconds stops before leaving the map (use a physics step loop). Run test_facility_map and test_environment_tileset_props.
```

---

### Step 2 — Place everything from the registry (Wave 1) — F2, F3, I5
**Do:** for each entry in the registry:
- **Stations:** `Stations/<station_id>` = a Node2D at `position`, with:
  - `StationProp` (visual) — texture per Step 3;
  - an instance of M4's `interactable_station.tscn` named `InteractableStation`.
- **Doors:** `Doors/<door_id>` = an instance of `res://scenes/objects/door.tscn` at the door position, rotated to the wall.
- **Spawns:** `SpawnPoints/Spawn1..Spawn8` = Marker2D at `SPAWN_POINTS[i]`.
- **Evidence:** `EvidenceAnchors/<location_id>` = Marker2D.

Prefer an **EditorScript** (`tools/build_map_anchors.gd`) that regenerates these nodes from the registry, so they can never drift. M8 adds a test asserting positions match within 4px.
Remove M3-era props that duplicate stations, if any exist in your map.

**Agent prompt**
```text
Do Step 2 (audit F2, F3, I5; contracts §4, §11). Write tools/build_map_anchors.gd as an @tool EditorScript that opens scenes/environment/facility_map.tscn, clears and regenerates the children of Stations, Doors, SpawnPoints and EvidenceAnchors from StationRegistry (STATIONS, DOORS, SPAWN_POINTS, EVIDENCE_ANCHORS): Stations/<id> (Node2D at position) containing StationProp (instance scenes/environment/station_prop.tscn, texture per station kind; use a placeholder texture if Step 3 art isn't done) and InteractableStation (instance res://client/interactions/interaction_framework/interactable_station.tscn, M4's; if it doesn't exist, stop and tell me); Doors/<door_id> (instance res://scenes/objects/door.tscn, rotated to match the wall orientation); SpawnPoints/Spawn1..Spawn8; EvidenceAnchors/<location_id> (Marker2D). Set owners so the nodes save into the scene. Explain how I run it in the editor (File > Run). Then update facility_map.gd get_spawn_position() to read SpawnPoints and get_station_prop() to read Stations/<id>/StationProp.
Extend tests/test_facility_map.gd: every registry id has its node at the registry position within 4px. Run test_facility_map and test_station_evidence_visuals.
```

---

### Step 3 — Art for the missing station types (Wave 1–2) — F2, F3
**Do:** 4-state textures (intact / sabotaged / repairing / restored) for:
- 4 recovery panels (generator, power routing, security relay, cooling);
- 3 emergency consoles;
- the meeting button.

**Impostor objective stations must look like ordinary facility props to Crew** (a file cabinet, a core terminal, a containment lever, a cable junction, a security console). They have no "sabotage" signage before blackout. After the objective is done, their `sabotaged` state is the physical evidence (e.g. an empty shelf).
Map every station kind → texture set in `station_prop.gd` or its scene, and document it in `docs/environment_art_spec.md`.

**Agent prompt**
```text
Do Step 3 (audit F2, F3). List every station id in shared/station_registry.gd and which existing texture set in assets/sprites/stations/ it uses; mark those with no texture. For each missing one, propose reusing an existing set or creating a new 4-state set (intact/sabotaged/repairing/restored) at the same pixel dimensions as the existing stations. I will produce or approve the art. Then update station_prop.gd so a StationProp can be configured by station id -> texture set (a const mapping table), and document the mapping in docs/environment_art_spec.md. Impostor objective stations must use textures that look like ordinary props in the intact state. Run test_station_evidence_visuals.
```

---

### Step 4 — Lighting bound to the server (Wave 2) — I5
**Do**
- `FacilityLightingController` owns the **only** `CanvasModulate` (M3 removes theirs).
- Bind it to `client.blackout_countdown_started` (siren flicker), `blackout_started` (emergency ambient + sirens), `blackout_ended` (normal), `meltdown_started` (meltdown ambient + sirens), and `game_state_changed(GAME_OVER / LOBBY)` (reset).
- Apply the current client state on `_ready`.
- Gate any debug key.
- Expose `bind_client_network_manager(client)`; bind automatically to `/root/NetworkManager.client` if present.

**Agent prompt**
```text
Do Step 4 (audit I5; contracts §9.2, §12). In scenes/environment/facility_lighting_controller.gd: ensure it owns the only CanvasModulate in the world; add or confirm bind_client_network_manager(client) and auto-bind to /root/NetworkManager.client in _ready; map signals to states: blackout_countdown_started -> siren flicker, blackout_started -> BLACKOUT ambient + sirens, blackout_ended -> NORMAL, meltdown_started -> MELTDOWN ambient + sirens, game_state_changed(GAME_OVER or LOBBY) -> NORMAL; apply the state already stored on the client when binding (is_blackout_active, is_meltdown_active). Gate every key handler with DebugFlags.hotkeys_enabled(). Update tests/test_facility_lighting_controller.gd with a fake client that emits each signal. Run it.
```

---

### Step 5 — VFX bound to events (Wave 2) — I5, F4
**Do**
- Alarm strobe during the blackout countdown.
- Sparks at `Stations/objective_sabotage_generator` after blackout, and at disrupted emergency consoles (`emergency_system_disrupted`).
- Steam at the cooling stations during Meltdown.
- The meltdown distortion overlay (`VFXMeltdownOverlay`, layer 10) strength = f(remaining Meltdown time from `timer_synced(MELTDOWN)`, `orion_instability`). Instability sets the baseline, time sets the ramp.
- All VFX live inside your map scene (e.g. a `VFX` child) or are spawned under the station nodes. No gameplay effect.

**Agent prompt**
```text
Do Step 5 (audit I5, F4). Add a VFX node (with a small controller script in scenes/vfx/) to the map that binds to the ClientNetworkManager and: plays VFXAlarmStrobe during blackout_countdown_started..blackout_started; spawns VFXElectricalSparks under Stations/objective_sabotage_generator when entering POST_BLACKOUT_INVESTIGATION if that evidence marker exists, and under Stations/emergency_<id> while client.disrupted_systems has it; VFXCoolantSteam at the cooling-related stations during MELTDOWN; shows VFXMeltdownOverlay during MELTDOWN with intensity = clamp(0.3 + 0.5 * (1 - remaining/duration) + 0.2 * instability/100, 0, 1), where duration comes from client.meltdown_started(duration, ...) and remaining from timer_synced(MELTDOWN), plus orion_instability_synced. Clean up everything on LOBBY. Tests with a fake client in tests/test_vfx_shaders.gd. Run it.
```

---

### Step 6 — EvidenceMarker and StationProp APIs for M4 (Wave 2)
**Do**
- Confirm/implement:
  - `EvidenceMarker.setup_from_type(evidence_type, location_id)`
  - a way to store `evidence_id`
  - `set_inspected(bool)`
- The markers' Area2D reacts only to group `local_player`.
- Sprites for every evidence type in M6's matrix (fallback: the pin sprite).
- `StationProp.set_visual_state("intact" | "sabotaged" | "repairing" | "restored")` accepts strings.
- Document both APIs at the top of each script. M4 relies on them.

**Agent prompt**
```text
Do Step 6. In scenes/environment/evidence_marker.gd make the public API exactly: setup_from_type(evidence_type: String, location_id: String), var evidence_id: String, set_inspected(active: bool), signal inspect_requested(evidence_id) emitted when the local player (group "local_player" only) presses E in range. Map every evidence_type from design/specs/evidence_matrix.md to a sprite (fallback: the pin). In station_prop.gd make set_visual_state accept the strings "intact", "sabotaged", "repairing", "restored" as well as the enum. Write a doc comment at the top of each script listing the public API. Update tests/test_station_evidence_visuals.gd. Run it and draft a note to M4 describing the final API.
```

---

### Step 7 — PlayerVisual final API for M3 (Wave 2)
**Do:** confirm that `set_color(color_index 0–7)`, `set_motion(velocity, facing)`, `set_ghost_mode(bool)`, `play_interact()` and `attach_flashlight(node)` all work when PlayerVisual is a child of a CharacterBody2D that moves every frame. Confirm the colour order matches `color_index = slot − 1` and document the order. Remove any debug keys.

**Agent prompt**
```text
Do Step 7. Review scenes/characters/player_visual.gd for use as a child of M3's PlayerController: confirm the public API (set_color(0..7), set_motion(velocity, facing), set_ghost_mode(bool), play_interact(), play_sabotage(), attach_flashlight(node)), that it works when set_motion is called every physics frame, and that the colour order is documented (index -> colour name) in docs/environment_art_spec.md, since contracts §1.3 says color_index = player_slot - 1. Gate or remove any debug input. Update tests/test_character_animations.gd if the API changed. Run it and send M3 the API summary.
```

---

### Step 8 — Reimport + hygiene (Wave 3) — R1
Once M8 has pinned Godot 4.4.1:
- open the project once in 4.4.1 so every `.import` for your assets is regenerated;
- commit only the `.import`/`.uid` files under your folders;
- delete unused textures;
- run all your suites.

**Agent prompt**
```text
Do Step 8 (audit R1). With Godot 4.4.1 (<GODOT>) run <GODOT> --headless --path . --import, then git status. Show me which changed files are under my folders (assets/sprites, assets/vfx, scenes/environment, scenes/characters, scenes/vfx) versus other folders. Only stage mine. List textures in assets/sprites and assets/vfx not referenced by any .tscn/.tres/.gd (grep by res:// path) and ask me before deleting any. Run all 6 of my suites.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main: (1) changed files are all in my folders; (2) every Stations/Doors/SpawnPoints/EvidenceAnchors node matches shared/station_registry.gd within 4px and the names match contracts §11; (3) physics layers follow contracts §11; (4) no visual script changes game state or calls a server request; (5) no ungated debug keys; (6) headless import clean + my 6 suites results pasted; (7) draft the PR description (template in docs/fix-plan/README.md §5) and the PROJECT_STATUS.md §7 entry.
```
