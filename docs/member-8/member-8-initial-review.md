# Member 8 Initial Review

**Reviewer:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Scope:** Repository inspection covering project structure, audio infrastructure, gameplay audio hooks, QA/test suites, playtest tooling, and production tracking.

---

## 1. Existing Project Structure

The project is built using **Godot 4.3 (GL Compatibility renderer)** in GDScript for 2D top-down multiplayer gameplay (`res://project.godot`). The codebase follows a flat, modular directory structure aligned with team ownership:

```text
Blackout/
├── .gitignore
├── CLAUDE.md                        # Developer workflow & test execution guide
├── design.md                        # Master game mechanics & architecture spec
├── PRD.md                           # Product Requirements Document (MVP scope)
├── project.godot                    # Godot 4.3 project definition & autoloads
├── PROJECT_STATUS.md                # 8-member status matrix & append-only changelog
├── README.md                        # Project overview & ownership rules
├── TEAM_SPLIT.md                    # 8-member ownership boundaries & pairing matrix
├── assets/
│   ├── audio/                       # Member 8 audio assets & registry
│   │   ├── ambience/                # Ambient sound directories (.gitkeep)
│   │   ├── music/                   # Music directories (.gitkeep)
│   │   ├── sfx/                     # SFX directories (.gitkeep)
│   │   ├── ui/                      # UI audio directories (.gitkeep)
│   │   └── audio_registry.gd        # Audio ID definitions & path registry
│   └── sprites/                     # Member 7 2D art assets & tilemaps
│       ├── characters/              # Player sprite directory (.gitkeep)
│       ├── environment/             # 10 room props + tileset_floor_walls.png
│       ├── lighting/                # Flashlight, radial, and vignette masks
│       └── stations/                # Station prop directory (.gitkeep)
├── client/
│   ├── audio/                       # Member 8 audio manager
│   │   └── audio_manager.gd         # Audio engine & player pooling controller
│   ├── client_network_manager.gd    # Member 1 client networking & state mirror
│   └── interactions/                # Member 4 mini-game framework & mini-games
│       ├── interaction_framework/   # Base classes (MiniGameBase, InteractableStation)
│       ├── mini_games/              # 10 crew tasks, 4 recovery, 3 meltdown mini-games
│       ├── sabotage_interactions/   # 5 impostor sabotage mini-games
│       ├── mini_game_factory.gd     # Mini-game factory loader
│       └── mini_game_showcase.gd/.tscn # Interactive mini-game gallery
├── config/
│   └── game_balance_config.json     # Member 6 canonical game balance constants
├── design/
│   └── specs/                       # Member 6 game design specifications
│       ├── evidence_matrix.md       # Objective-to-evidence mappings
│       ├── map_station_layout.md    # 9-room layout and station placements
│       └── task_specifications.md   # Mechanics for all 22 mini-games/tasks
├── docs/
│   ├── environment_art_spec.md      # Member 7 art & lighting specifications
│   ├── member-8/                    # Member 8 reviews and QA documentation
│   └── reviews/                     # Historical review logs (Steps 8–10)
├── documentation/
│   └── README.md                    # Root link reference
├── scenes/
│   └── environment/                 # Member 7 master facility scene & controllers
│       ├── facility_lighting_controller.gd/.tscn # Dual-state lighting controller
│       ├── facility_map.gd/.tscn    # Master 9-room facility map scene
│       ├── facility_tileset.tres    # 32x32 collision tilemap resource
│       ├── player_flashlight.gd/.tscn # 2D directional flashlight component
│       ├── room_prop.gd/.tscn       # Obstacle & station prop component
│       └── vignette_overlay.gd/.tscn # Fullscreen atmospheric darkness vignette
├── server/                          # Member 1 & Member 2 authoritative backend
│   ├── blackout_manager.gd          # Blackout countdown & timer logic (M2)
│   ├── blackout_recovery_manager.gd # 3-of-4 recovery systems tracking (M2)
│   ├── evidence_manager.gd          # Facts-only evidence generation (M2)
│   ├── impostor_objective_manager.gd # Impostor objectives backend (M2)
│   ├── meeting_manager.gd           # Discussion timers & flow (M2)
│   ├── meltdown_manager.gd          # 5-minute emergency meltdown timer (M2)
│   ├── server_network_manager.gd    # Authoritative network hub & manager wiring (M1)
│   ├── task_manager.gd              # Task completion validation & unlock gating (M2)
│   ├── voting_manager.gd            # Plurality voting resolution (M2)
│   └── win_condition_manager.gd     # Win/loss evaluation (M2)
├── shared/                          # Shared configurations, data definitions, and network
│   ├── blackout_config.gd           # Blackout timing constants
│   ├── blackout_objective_config.gd # Impostor objective catalogs
│   ├── blackout_objective_definition.gd
│   ├── blackout_recovery_config.gd  # Recovery system definitions
│   ├── blackout_recovery_definition.gd
│   ├── evidence_config.gd           # Evidence identifiers & descriptions
│   ├── evidence_definition.gd
│   ├── meeting_config.gd            # Discussion & voting durations
│   ├── meltdown_config.gd           # Meltdown duration & emergency systems
│   ├── network_config.gd            # Game states, player roles, connection states
│   ├── network_manager.gd           # NetworkManager autoload switching SERVER/CLIENT
│   ├── player_connection_data.gd    # Player peer slot & role container
│   ├── task_config.gd               # Crew & prerequisite task catalogs
│   └── task_definition.gd
└── tests/                           # QA test suites & verification tools
    ├── playtest_checklists/         # Member 8 playtest protocols & threat matrices
    │   ├── anti_cheat_test_matrix.md # 14-point anti-cheat validation matrix
    │   └── playtest_checklist_8player.md # Operational 8-player playtest protocol
    ├── server_authority_tests/      # Member 8 automated anti-cheat suites
    │   ├── test_anti_cheat_blackout.gd
    │   ├── test_anti_cheat_meltdown.gd
    │   ├── test_anti_cheat_tasks.gd
    │   └── test_anti_cheat_voting.gd
    ├── run_all_tests.gd             # Master test suite runner
    └── test_*.gd                    # 14 headless integration & unit test suites
```

---

## 2. Existing Audio Infrastructure

- **Project Configuration (`project.godot`):**
  - No `AudioManager` is registered under `[autoload]`. The only registered autoload is `NetworkManager="*res://shared/network_manager.gd"`.
  - No custom audio bus layout (`default_bus_layout.tres`) is defined in `project.godot`. The project currently runs on Godot's default single `Master` bus.
- **Client Audio Engine (`client/audio/audio_manager.gd`):**
  - Contains a standalone script inheriting `Node`.
  - Defines bus name constants (`Master`, `Ambience`, `Music`, `SFX`, `UI`).
  - Implements dynamic `AudioStreamPlayer` generation for ambient crossfading, music looping, UI feedback, and an 8-channel SFX voice pool with voice stealing.
  - Implements a programmatic tone synthesis engine (`AudioStreamWAV` procedural buffer generation) providing fallback tones (sine/square) when audio files are absent.
  - **Current State:** The script exists on disk but is **not active at runtime**. It is not attached to any scene, not registered as an autoload, and not called by any existing scene or script.
- **Audio Registry (`assets/audio/audio_registry.gd`):**
  - Contains path constants for 19 audio events across ambience, music, SFX, and UI.
  - Contains fallback procedural synthesizer parameters for each audio cue.

---

## 3. Existing Audio Assets

- **Physical Audio Files (`.wav`, `.ogg`, `.mp3`):**
  - **Zero** audio asset files exist in the repository.
  - Sourced audio files for the facility ambient hum, blackout atmospheric drone, siren loops, mini-game clicks, and stingers have not yet been imported.
- **Audio Asset Folders (`assets/audio/`):**
  - `assets/audio/ambience/` — Exists, contains only `.gitkeep`.
  - `assets/audio/music/` — Exists, contains only `.gitkeep`.
  - `assets/audio/sfx/` — Exists, contains only `.gitkeep`.
  - `assets/audio/ui/` — Exists, contains only `.gitkeep`.

---

## 4. Available Gameplay Audio Integration Points

Member 8 can hook into existing public signals without modifying any code written by Members 1–7. The key public integration points are:

### A. Client Network Signals (`client/client_network_manager.gd` — Member 1)
| Gameplay Event | Public Signal / Method | Audio Cue Required |
|---|---|---|
| **Lobby & Connections** | `other_player_connected`, `ready_state_updated`, `lobby_synced` | UI click / player join chime |
| **Game Start** | `game_state_changed(new_state)` (`INITIAL_TASK_PHASE`) | Ambient facility hum starts |
| **Role Reveal** | `role_assigned(role)` | Role reveal chord / sting (Crew vs. Impostor) |
| **Task Completed** | `task_completed_locally(task_id)` | Task completion success chime |
| **Blackout Unlock** | `blackout_unlocked_for_impostor()` | Impostor UI alert ping |
| **Blackout Countdown** | `blackout_countdown_started(duration)` | High-tension 3-second countdown stinger |
| **Blackout Start** | `blackout_started(duration)` | Heavy power cutoff "thud", emergency sirens, blackout drone |
| **Recovery Progress** | `recovery_system_updated(id, is_comp, comp_count, req_count)` | Power relay repair click / progress cue |
| **Blackout End** | `blackout_ended()` | Power surge restoration, sirens cutoff, return to normal hum |
| **Sabotage Completed** | `impostor_objective_updated(id, is_completed)` | Sabotage success feedback cue (Impostor private) |
| **Meeting Initiated** | `meeting_started(caller_id, duration)` | Emergency siren stinger / meeting alarm |
| **Voting Phase** | `voting_started(duration)`, `player_voted(voter_id)` | Clock ticking loop, ballot submit click |
| **Ejection & Results** | `vote_result_received(result)` | Dramatic ejection reveal sting (ejected vs. skipped/tie) |
| **Meltdown Protocol** | `meltdown_started(duration, impostor_alive)` | Facility meltdown siren loop, escalating tempo tension music |
| **Emergency System** | `emergency_system_completed(system_id, completed_systems)` | Emergency station stabilized chime |
| **Match Conclusion** | `game_over_received(winner_role, reason, result_data)` | Victory fanfare (Crew/Impostor) or Facility Destroyed blast |

### B. Mini-Game & Interaction Signals (`client/interactions/` — Member 4)
- `InteractableStation` (`client/interactions/interaction_framework/interactable_station.gd`):
  - `player_entered_station(station)` — Proximity prompt audio cue.
  - `player_exited_station(station)` — Proximity release cue.
  - `interaction_triggered(station)` — Station console open / boot sound.
- `MiniGameBase` (`client/interactions/interaction_framework/mini_game_base.gd`):
  - `interaction_started()` — Mini-game engage click.
  - `interaction_completed()` — Mini-game puzzle solve chime.
  - `interaction_cancelled()` / `interaction_interrupted()` — Cancel whoosh.
  - `interaction_failed()` — Error buzz / alarm blip.
  - `progress_changed(new_progress)` — Dial tick / wire connect / progress beep.

### C. Environment Lighting Signals (`scenes/environment/facility_lighting_controller.gd` — Member 7)
- `FacilityLightingController`:
  - `lighting_state_changed(new_state)` — Synchronizes audio ambient loops with visual states (`NORMAL`, `BLACKOUT_WARNING`, `BLACKOUT_ACTIVE`, `MELTDOWN`).

---

## 5. Existing QA/Test Infrastructure

- **Test Architecture:**
  - Headless GDScript integration suites run directly via the Godot executable:
    ```bash
    godot --headless -s tests/<test_script>.gd
    ```
  - No external test framework (such as GUT) is installed or required.
  - Each test suite extends `SceneTree`, connects local loopback ENet sockets (`127.0.0.1`), instantiates `ServerNetworkManager` and multiple `ClientNetworkManager` nodes, processes network ticks, and prints `[PASS]` / `[FAIL]` assertions before quitting with exit code `0` or `1`.
- **Existing Integration Test Suites (14 Suites):**
  1. `tests/test_multiplayer_server.gd` — ENet socket lifecycle, 8-player capacity, and disconnects.
  2. `tests/test_lobby_system.gd` — Player ready-up state synchronization and 8-player match start gating.
  3. `tests/test_role_assignment.gd` — 1 Impostor / 7 Crew server-authoritative assignment and private delivery.
  4. `tests/test_task_system.gd` — Task completion RPC validation and phase access rules.
  5. `tests/test_blackout_system.gd` — Prerequisite unlock gating, remote trigger, timer ticks, and recovery.
  6. `tests/test_blackout_recovery_objectives.gd` — 3-of-4 recovery threshold and Impostor sabotage objectives.
  7. `tests/test_evidence_system.gd` — Facts-only evidence generation and discovery list.
  8. `tests/test_meeting_voting_system.gd` — Meeting initiation, discussion/voting timers, and plurality ejection.
  9. `tests/test_meltdown_system.gd` — 5-minute meltdown timer, 3 emergency systems, and game over triggers.
  10. `tests/test_win_condition_manager.gd` — Authoritative victory/defeat evaluation.
  11. `tests/test_facility_lighting_controller.gd` — Dual-state lighting controller, flashlights, and vignette.
  12. `tests/test_environment_tileset_props.gd` — Modular 32x32 tileset, 10 room props, and physics collision masks.
  13. `tests/test_facility_map.gd` — Master 9-room facility map bounds, 8-player spawn anchors, and stations.
  14. `tests/test_member_4_interactions.gd` — Mini-game base classes, factory, and all 22 mini-game puzzles.
- **Master Test Runner:**
  - `tests/run_all_tests.gd` — Coordinates automated regression execution across all test suites.
- **Server Authority / Anti-Cheat Suites (`tests/server_authority_tests/`):**
  1. `test_anti_cheat_tasks.gd` — Validates server rejection of spoofed tasks, unauthorized prerequisite claims, and non-assigned completions.
  2. `test_anti_cheat_blackout.gd` — Validates server rejection of premature blackout triggers, unauthorized client calls, and invalid recovery attempts.
  3. `test_anti_cheat_voting.gd` — Validates server rejection of double votes, out-of-phase voting, dead player votes, and vote tally manipulation.
  4. `test_anti_cheat_meltdown.gd` — Validates server rejection of invalid emergency system completions and tampering with the 5-minute countdown.

---

## 6. Existing Multiplayer/Playtest Infrastructure

- **Simulated Multiplayer Testing:**
  - `tests/test_lobby_system.gd` and `tests/test_role_assignment.gd` simulate real 8-player network sessions by spinning up 1 server peer and 8 client peers on loopback ENet sockets (`TEST_PORT = 7789 / 7790`).
- **Playtest Documentation & Checklists (`tests/playtest_checklists/`):**
  - `playtest_checklist_8player.md` — Complete operational playbook for running live 8-player playtest matches:
    - Pre-session setup (host server port 7777, packet loss limits, roster assignment for 8 seats).
    - Phase-by-phase testing protocol (Lobby, Role Assignment, Tasks, Blackout, Meetings, Meltdown).
    - Telemetry tracking table (match duration, blackout duration, evidence count, ejection accuracy, meltdown survival, player feedback).
  - `anti_cheat_test_matrix.md` — 14-point vulnerability matrix covering client spoofing, role sniffing, countdown manipulation, and premature phase skips.
- **Playtest Tooling Gaps:**
  - No automated multi-instance batch launcher (e.g., launching 1 server and 8 client windows locally for manual multi-client playtesting).
  - No automated telemetry logging export tool to persist match results to JSON/CSV during playtest sessions.

---

## 7. Existing Production/Milestone Tracking

- **`PRD.md` (Product Requirements Document):**
  - Defines the core MVP requirements (FR-1 to FR-44, NFR-1 to NFR-5).
  - Outlines the 9 open design questions (e.g., plurality voting, blackout duration default, 3-of-4 recovery threshold, meeting cooldowns).
  - Establishes success metrics for post-MVP playtests (15–25 min match pacing, 45–55% win rate balance).
- **`PROJECT_STATUS.md`:**
  - Central production dashboard with 8-member ownership matrix and current status badges:
    - Member 1 (Lead Backend): 🟢 Merged to `main` (Steps 1–10)
    - Member 2 (Gameplay Backend): 🟢 Complete & Hardened (Phases 1–5)
    - Member 3 (Client Engine): 🟡 In Progress
    - Member 4 (Mini-Games): 🟡 In Progress (Interaction Framework & 22 Mini-Games Complete)
    - Member 5 (UI Frontend): 🟡 In Progress
    - Member 6 (Game Design): 🟢 Design Specs & Balance Config Delivered
    - Member 7 (Environment Art): 🟡 In Progress (Phase 4 Master Map Complete)
    - Member 8 (Audio & QA / Production): 🟢 Audio Architecture & Anti-Cheat Suites Complete
  - Append-only Change Log (§9) recording merged deliverables.
- **`TEAM_SPLIT.md`:**
  - Formalizes individual subsystem boundaries, key deliverables, and cross-functional pairings.
- **`design.md`:**
  - Full technical architecture reference, authoritative state machine definitions, and room connectivity graphs.
- **`config/game_balance_config.json`:**
  - Central balance sheet authored by Member 6 specifying all timing and threshold values.

---

## 8. Member 8 Files We Can Safely Create

The following directories and files can be created, updated, and maintained by Member 8 without any risk of collision with other members:

```text
assets/audio/
├── ambience/                        # Sourced ambient audio loops (.ogg/.wav)
├── music/                           # Sourced music & tension tracks (.ogg/.wav)
├── sfx/                             # Sourced sound effects (.wav)
├── ui/                              # Sourced UI clicks and stingers (.wav)
└── audio_registry.gd                # Audio metadata, paths, and volume offsets

client/audio/
├── audio_manager.gd                 # Authoritative client audio playback controller
├── audio_observer.gd                # Non-invasive listener subscribing to network signals
└── default_bus_layout.tres          # 5-bus audio layout (Master, Ambience, Music, SFX, UI)

tests/
├── run_all_tests.gd                 # Master test coordinator
├── test_audio_manager.gd            # Unit & playback test suite for audio system
├── server_authority_tests/          # Anti-cheat automated security test suites
│   ├── test_anti_cheat_blackout.gd
│   ├── test_anti_cheat_meltdown.gd
│   ├── test_anti_cheat_tasks.gd
│   └── test_anti_cheat_voting.gd
└── playtest_checklists/             # QA playtest protocols and balance telemetry
    ├── anti_cheat_test_matrix.md
    ├── playtest_checklist_8player.md
    └── playtest_telemetry_template.csv

docs/member-8/                       # Member 8 documentation, reviews, and QA reports
├── member-8-initial-review.md       # (This review)
└── ...
```

---

## 9. Files Owned by Other Members — DO NOT MODIFY

To maintain strict domain boundaries, Member 8 must **never** modify the following files:

| Member | Domain | Owned Files & Directories (Strictly Read-Only for M8) |
|---|---|---|
| **Member 1** (Mayiz) | Backend & Networking | `server/server_network_manager.gd`, `client/client_network_manager.gd`, `shared/network_manager.gd`, `shared/network_config.gd`, `shared/player_connection_data.gd` |
| **Member 2** (Abdul Qadir) | Authoritative Gameplay Backend | `server/task_manager.gd`, `server/blackout_manager.gd`, `server/blackout_recovery_manager.gd`, `server/impostor_objective_manager.gd`, `server/evidence_manager.gd`, `server/meeting_manager.gd`, `server/voting_manager.gd`, `server/meltdown_manager.gd`, `server/win_condition_manager.gd`, and all `shared/*_config.gd` / `shared/*_definition.gd` |
| **Member 3** (Aaliya) | Client Engine & Movement | `client/player/` (controller, movement, prediction, state reconciliation), `client/rendering/` (vision cone shaders, camera) |
| **Member 4** (Ubaid) | Mini-Games & Interactions | `client/interactions/` (`mini_game_factory.gd`, `mini_game_showcase.*`, `interaction_framework/`, `mini_games/`, `sabotage_interactions/`) |
| **Member 5** (Shahzan) | UI/UX Frontend | `client/ui/` (HUD screens, role reveal cards, task UI, blackout UI, meeting UI, voting screen, meltdown screen, game over screen) |
| **Member 6** (Abubaker) | Game Design & Balance | `design/specs/` (`task_specifications.md`, `evidence_matrix.md`, `map_station_layout.md`), `config/game_balance_config.json` |
| **Member 7** (Fatima) | 2D Environment Art & VFX | `assets/sprites/` (`environment/`, `lighting/`, `characters/`, `stations/`), `assets/vfx/`, `scenes/environment/` (`facility_map.*`, `facility_lighting_controller.*`, `player_flashlight.*`, `room_prop.*`, `vignette_overlay.*`, `facility_tileset.tres`), `docs/environment_art_spec.md` |
| **Global Project Config** | Shared Engine Settings | `project.godot`, `PRD.md`, `design.md`, `TEAM_SPLIT.md` (read-only; propose changes via PRD/docs if needed) |

---

## 10. Integration Dependencies

To integrate audio and QA seamlessly without violating boundaries, Member 8 relies on:

1. **Non-Invasive Observer Architecture:**
   - Instead of modifying `client_network_manager.gd` or mini-game scripts to call `AudioManager` directly, Member 8 will use an **AudioObserver** component.
   - The AudioObserver connects to public signals exposed by `ClientNetworkManager`, `MiniGameBase`, `InteractableStation`, and `FacilityLightingController`.
2. **Audio Bus Layout Compatibility:**
   - Member 8 must configure an audio bus layout with distinct buses (`Master`, `Ambience`, `Music`, `SFX`, `UI`).
   - This provides independent decibel attenuation hooks so Member 5's settings menu can adjust volumes via `AudioServer.set_bus_volume_db()` without touching audio playback code.
3. **Loopback Server-Client Test Harness:**
   - Anti-cheat test suites depend on `ServerNetworkManager` and `ClientNetworkManager` instantiating over local loopback ENet sockets (`127.0.0.1`) without requiring a headless dedicated server binary.

---

## 11. Missing Member 8 Components

1. **Audio Assets:** Sourced `.ogg` and `.wav` audio files for facility ambience, blackout drone, siren loops, countdown stingers, UI clicks, task chimes, and meltdown tension music (currently using procedural tone synthesis).
2. **Godot Audio Bus Resource:** A dedicated `res://client/audio/default_bus_layout.tres` configuring the 5 audio buses with proper routing to `Master`.
3. **Audio Observer Scene/Node:** A lightweight listener node (`res://client/audio/audio_observer.gd`) that automatically binds `AudioManager` to `ClientNetworkManager` and world station signals upon entering the match scene.
4. **AudioManager Unit Test Suite:** A dedicated test suite (`tests/test_audio_manager.gd`) verifying bus initialization, volume adjustments, fallback tone generation, and event trigger handling.
5. **Local Multi-Client Playtest Launcher:** A Windows batch script or utility to launch 1 server instance and 8 client instances for local manual playtesting.

---

## 12. Recommended Next Step

**Step 2 Recommendation:**
1. Create the dedicated 5-bus Godot audio layout resource (`client/audio/default_bus_layout.tres`) defining `Master`, `Ambience`, `Music`, `SFX`, and `UI` buses.
2. Implement the automated unit test suite `tests/test_audio_manager.gd` to rigorously test bus creation, volume routing, procedural fallback tone playback, and signal handling.
3. Verify test pass status headlessly to ensure robust audio engine readiness before introducing binary audio assets or scene observers.
