# BLACKOUT — Project Status & Change Log

> **Project:** BLACKOUT (2D Top-Down Multiplayer Social Deduction & Meltdown Survival MVP)  
> **Repository:** `ABUBAK3R-K/Blackout`  
> **Engine / Framework:** Godot 4.x (GDScript)  
> **Target Version:** 1.0 (MVP)  
> **Last Updated:** 2026-09-17  
> **Active Branch:** `member-7/environment-art`  
> **Status:** Active Development (Step 10 Complete — Core Authoritative Backend Merged; Member 7 Environment Art Initialized)

---

## 1. Project Health & Milestone Dashboard

| Metric | Current Status | Notes / Next Actions |
|---|---|---|
| **Current Phase** | **Backend Infrastructure & Gameplay Mechanics (Steps 1–10 Complete)** | Core authoritative network managers, task systems, blackout, recovery, evidence, meeting/voting, and meltdown logic implemented and verified via unit test suites |
| **Overall Health** | 🟢 **Green** | Core authoritative loop passes 10 headless test suites |
| **Engine Confirmed** | **Godot 4.x (GDScript)** | `project.godot` configured, headless GDScript test runner validated |
| **Next Major Milestone** | **Client Gameplay Integration (Steps 11+)** | Client player movement (M3), mini-game UI/interaction framework (M4), HUD/UI screens (M5), environment tilemaps & lighting (M7) |
| **Target MVP Completion** | End of Sprint 5 | Full 8-player end-to-end playable match loop |

---

## 2. 8-Member Ownership & Module Status Matrix

| Member | Assignee | Dedicated Branch | Subsystem / Modules Owned | Current Status |
|---|---|---|---|---|
| **Member 1** | **Mayiz** | `member-1/backend-network` | `server_network_manager.gd`, `client_network_manager.gd`, `network_manager.gd`, room lifecycle, RPC dispatch, role assignment | 🟢 Merged to `main` (Steps 1–10) |
| **Member 2** | **Abdul Qadir** | `member-2/gameplay-backend` | `task_manager.gd`, `blackout_manager.gd`, `blackout_recovery_manager.gd`, `impostor_objective_manager.gd`, `evidence_manager.gd`, `meeting_manager.gd`, `voting_manager.gd`, `meltdown_manager.gd` | 🟢 Core Backend Merged; 🟡 Gameplay Tuning & Edge-Case Hardening Active |
| **Member 3** | **Aaliya** | `member-3/client-engine` | `client/player/` (controller, movement, prediction, state reconciliation), `map_manager`, dynamic vision-cone/lighting shader | 🟡 In Progress |
| **Member 4** | **Ubaid** | `member-4/mini-games` | `client/interactions/mini_games/` (Crew tasks, prerequisite tasks, Meltdown emergency mini-games), input handling | 🟡 In Progress |
| **Member 5** | **Shahzan** | `member-5/ui-frontend` | In-game HUD (`task_ui`, `blackout_ui`, `timer_ui`, `sabotage_ui`), meeting & voting screens, role reveal, game over | 🟡 In Progress |
| **Member 6** | **Abubaker** | `member-6/game-design` | Balance configs (`shared/*_config.gd`), task specs, evidence rules, 9-room layout flow | 🟡 In Progress |
| **Member 7** | **Fatima** | `member-7/environment-art` | 9-room tilemaps, normal vs. emergency lighting assets, 2D player sprites, VFX | 🟡 In Progress (Assets Initialized & Art Spec Published) |
| **Member 8** | **Sahil** | `member-8/audio-qa` | SFX & tension soundscapes, `tests/` automated test suites, 8-player playtest operations | 🟢 Automated Test Suites Implemented (Tests 1–10) |

*Status Legend:* ⚪ *Not Started* | 🟡 *In Progress* | 🔵 *Under Review (PR Open)* | 🟢 *Merged to `main`* | 🔴 *Blocked*

---

## 3. Member 2 (Abdul Qadir) — Gameplay Backend Status & Ownership

Member 2 is the primary owner and maintainer of the authoritative server gameplay logic in `server/` and its shared configuration definitions in `shared/`.

### Subsystem Breakdown:

| Module | Source File | Shared Config / Defs | Test Suite | Status |
|---|---|---|---|---|
| **Task Management** | `server/task_manager.gd` | `shared/task_config.gd`, `shared/task_definition.gd` | `tests/test_task_system.gd` | 🟢 Implemented & Tested |
| **Blackout System** | `server/blackout_manager.gd` | `shared/blackout_config.gd` | `tests/test_blackout_system.gd` | 🟢 Implemented & Tested |
| **Blackout Recovery** | `server/blackout_recovery_manager.gd` | `shared/blackout_recovery_config.gd`, `shared/blackout_recovery_definition.gd` | `tests/test_blackout_recovery_objectives.gd` | 🟢 Implemented & Tested |
| **Impostor Objectives & Sabotage** | `server/impostor_objective_manager.gd` | `shared/blackout_objective_config.gd`, `shared/blackout_objective_definition.gd` | `tests/test_blackout_recovery_objectives.gd` | 🟢 Implemented & Tested |
| **Evidence System** | `server/evidence_manager.gd` | `shared/evidence_config.gd`, `shared/evidence_definition.gd` | `tests/test_evidence_system.gd` | 🟢 Implemented & Tested |
| **Meeting Management** | `server/meeting_manager.gd` | `shared/meeting_config.gd` | `tests/test_meeting_voting_system.gd` | 🟢 Implemented & Tested |
| **Voting Management** | `server/voting_manager.gd` | `shared/meeting_config.gd` | `tests/test_meeting_voting_system.gd` | 🟢 Implemented & Tested |
| **Meltdown Protocol** | `server/meltdown_manager.gd` | `shared/meltdown_config.gd` | `tests/test_meltdown_system.gd` | 🟢 Implemented & Tested |
| **Network & RPC Handlers** | `server/server_network_manager.gd` | `shared/network_config.gd`, `shared/network_manager.gd` | `tests/test_multiplayer_server.gd` | 🟢 Implemented & Tested |

---

## 4. Member 7 (Fatima) — 2D Environment & Technical Art Status & Ownership

Member 7 is the primary owner of all environmental art, tilemaps, lighting assets, character sprites, and visual effects in `assets/sprites/`, `assets/vfx/`, and `scenes/environment/`.

### Subsystem Breakdown:

| Module / Asset Group | Target Directory | Specifications / Controller | Status |
|---|---|---|---|
| **Technical Art Specification** | `docs/` | `docs/environment_art_spec.md` | 🟢 Complete & Approved |
| **Dual-State Lighting System** | `assets/sprites/lighting/` | `facility_lighting_controller.gd`, `flashlight_mask.png`, `radial_light_cookie.png`, `vignette_mask.png` | 🟢 Initialized & Active |
| **9-Room Facility Tilemaps** | `assets/sprites/environment/` | 32×32 grid tilemaps for all 9 rooms (Cafeteria, Security, Lab, Server Room, Storage, Generator, Office, MedBay, ORION Core) | 🟡 Pipeline Initialized |
| **Station & Evidence Visuals** | `assets/sprites/stations/` | Visual states (Intact, Sabotaged, Repairing, Repaired, Evidence markers) | 🟡 In Progress |
| **2D Character Sprite Sheets** | `assets/sprites/characters/` | 8-player color variants, 4-directional walk/idle/task/ghost animations | 🟡 In Progress |
| **Visual Effects (VFX)** | `assets/vfx/` | Particle presets (sparks, steam) & Meltdown heat distortion shader | 🟡 In Progress |

---

## 5. Sprint Milestones Roadmap

### Sprint 1: Core Foundation & Map Layout
- [x] Engine selection confirmed: **Godot 4.x**.
- [x] Authoritative server-client network architecture (`ENetMultiplayerPeer`).
- [x] 8-player lobby lifecycle and ready-up synchronization (`tests/test_lobby_system.gd`).
- [x] Server-authoritative role assignment (1 Impostor, 7 Crew) with private client reveal (`tests/test_role_assignment.gd`).
- [x] Initial task assignment and anti-cheat validation (`server/task_manager.gd`, `tests/test_task_system.gd`).
- [ ] Client movement, 2D player controller, collision layers, camera system (M3).
- [ ] 9-room tilemap layout and base character animations (M7).

### Sprint 2: Normal Phase & Blackout System
- [x] Blackout prerequisite gating: unlocked strictly by Impostor prerequisite tasks (`tests/test_blackout_system.gd`).
- [x] Remote blackout activation, 3-second countdown broadcast, fixed authoritative countdown timer (`server/blackout_manager.gd`).
- [x] Distributed recovery system: 3-of-4 recovery systems with live `X/Y` progress updates (`tests/test_blackout_recovery_objectives.gd`).
- [ ] Client dynamic vision cone and blackout emergency lighting shader (M3).
- [ ] Client mini-game interaction framework and station inputs (M4).
- [ ] In-game HUD, task checklist, and countdown banners (M5).

### Sprint 3: Sabotage, Evidence & Meeting/Voting
- [x] Impostor confidential file theft, core data extraction, and sabotage actions (`server/impostor_objective_manager.gd`).
- [x] Server-tracked discoverable evidence generation system (`server/evidence_manager.gd`, `tests/test_evidence_system.gd`).
- [x] Emergency meeting trigger validation and discussion timer (`server/meeting_manager.gd`).
- [x] Plurality/majority voting resolution, tie handling, and ejection announcement (`server/voting_manager.gd`, `tests/test_meeting_voting_system.gd`).
- [ ] Meeting UI, discussion chat box, and interactive voting grid (M5).
- [ ] Sabotaged station visuals, evidence inspection markers, and icons (M7).

### Sprint 4: Meltdown Protocol & Endgame
- [x] 5-minute fixed Meltdown countdown timer (`server/meltdown_manager.gd`, `tests/test_meltdown_system.gd`).
- [x] 3 mandatory emergency systems: *Restore Power*, *Restore Cooling*, *Stabilize ORION*.
- [x] Active Impostor interference handling vs. Crew-only repair branching.
- [x] Crew victory and Impostor victory evaluation with Game Over lockdown guards.
- [ ] Meltdown emergency sirens, screen shake, Core distortion VFX (M3, M7).
- [ ] Meltdown mini-games (Power, Cooling, ORION stabilization) client UI (M4).
- [ ] Victory/Defeat recap screen (M5).

### Sprint 5: Full Integration, Balance Tuning & Polish
- [ ] Full 8-player client-server playtest sessions (M8 lead).
- [ ] Balance calibration via `shared/*_config.gd` (M6 & M2).
- [ ] Audio soundscape integration, SFX layering (M8).
- [ ] Bug triage and server authority edge-case hardening.

---

## 6. Open Questions Resolution Log (`prd.md` §9)

| # | Question | Owner | Status | Decision / Current Implementation |
|---|---|---|---|---|
| **1** | Platform target & Engine | M1, M3 | Resolved | **Godot 4.x (GDScript)** targeting PC (Windows/Linux/Mac), with high headless testability. |
| **2** | Vote resolution rule (Plurality vs. Majority) | M6, M2 | Resolved | Implemented in `server/voting_manager.gd`: Plurality resolution; ties or skip-majority result in no ejection. |
| **3** | Meeting trigger mechanism | M6, M2 | Resolved | Authoritative `request_call_meeting()` with per-player cooldowns and state guards. |
| **4** | Comms scope during blackout | M6, M1 | In Progress | Baseline: Text chat active during meetings; suppressed during blackout. |
| **5** | Disconnect / Reconnect handling | M1, M8 | Resolved | `PlayerConnectionData` tracks peer state; graceful peer cleanup in `server_network_manager.gd`. |
| **6** | Blackout duration default value | M6, M8 | Resolved | Baseline: `DEFAULT_BLACKOUT_DURATION_SEC = 90.0` in `shared/blackout_config.gd`. |
| **7** | Recovery systems threshold | M6, M2 | Resolved | Configurable `DEFAULT_REQUIRED_RECOVERY_COUNT = 3` of 4 in `shared/blackout_recovery_config.gd`. |
| **8** | Anti-griefing & AFK guards | M1, M6 | In Progress | Meeting limits and server-side RPC validation guards active across all managers. |
| **9** | Networking architecture | M1, M3 | Resolved | Server-authoritative RPC architecture over `ENetMultiplayerPeer` with headless testing capability. |

---

## 7. Change Log Protocol (Instructions for All Team Members)

Whenever ANY change is made to the codebase or documentation, the modifying team member MUST append an entry to this file:

### Rules for Logging Changes:
1. **Append-Only:** Never delete or alter previous entries.
2. **Log on Feature Branch:** Add your entry before creating a pull request or merging into `main`.
3. **Format Strictly:** Use the standard markdown template below.
4. **Notify Cross-Functional Pairs:** If your change modifies shared RPC schemas, config constants, or interfaces, notify your paired partner immediately.

### Standard Change Log Template:
```markdown
### [YYYY-MM-DD] — [Brief Title of Change]
- **Author:** [Name and Member #]
- **Branch / PR:** `[branch-name]` or `#PR-Number`
- **Modules Affected:** `[file/module path(s)]`
- **Type of Change:** `[Feature | Bugfix | Refactor | Design/Config | Documentation]`
- **Description:**
  - Key bullet point 1
  - Key bullet point 2
- **Breaking Changes / Contract Impacts:** `[None | Specific details on modified contracts]`
- **Verification / Testing:** `[Unit tests run, test suite command, verification method]`
```

---

## 8. Change Log

### [2026-09-17] — Initialized Member 7 (Fatima) Environment Art Architecture & Asset Pipeline
- **Author:** Fatima (Member 7 — 2D Environment & Technical Artist)
- **Branch / PR:** `member-7/environment-art`
- **Modules Affected:**
  - `docs/` (`environment_art_spec.md`)
  - `assets/sprites/` (`environment/`, `stations/`, `lighting/`, `characters/`)
  - `assets/vfx/`
  - `scenes/environment/` (`facility_lighting_controller.gd`)
  - `PROJECT_STATUS.md`
- **Type of Change:** `Feature / Process Setup / Art Pipeline`
- **Description:**
  - Initialized asset directory structure across environment, stations, lighting, characters, and VFX.
  - Published comprehensive 2D Environment & Technical Art Specification (`docs/environment_art_spec.md`) detailing grid standards, 9-room layout geometry, collision masks, dual-state lighting, station visual states, evidence markers, character color palettes, and shaders.
  - Created foundational lighting textures: `radial_light_cookie.png`, `flashlight_mask.png`, and `vignette_mask.png`.
  - Implemented `FacilityLightingController` GDScript node to manage seamless state transitions between Normal, Blackout Warning, Blackout Active, and Meltdown with animated emergency sirens and network signal hooks.
- **Breaking Changes / Contract Impacts:** None. Seamlessly hooks into `ClientNetworkManager` signals and aligns with `TaskConfig`, `EvidenceConfig`, `BlackoutRecoveryConfig`, and `MeltdownConfig`.
- **Verification / Testing:** Asset dimensions and texture import profiles verified; lighting state machine tested against network event contracts.

---

### [2026-09-17] — Synced `main` into `member-2/gameplay-backend` (Backend Ready Merge)
- **Author:** Abdul Qadir (Member 2 — Gameplay Backend Engineer)
- **Branch / PR:** `member-2/gameplay-backend` (merged from `main` @ `d900c09`)
- **Modules Affected:**
  - `server/` (`task_manager.gd`, `blackout_manager.gd`, `blackout_recovery_manager.gd`, `impostor_objective_manager.gd`, `evidence_manager.gd`, `meeting_manager.gd`, `voting_manager.gd`, `meltdown_manager.gd`, `server_network_manager.gd`)
  - `shared/` (`network_manager.gd`, `network_config.gd`, `task_config.gd`, `blackout_config.gd`, `blackout_recovery_config.gd`, `blackout_objective_config.gd`, `evidence_config.gd`, `meeting_config.gd`, `meltdown_config.gd`, and definitions)
  - `client/` (`client_network_manager.gd`)
  - `tests/` (`test_task_system.gd`, `test_blackout_system.gd`, `test_blackout_recovery_objectives.gd`, `test_evidence_system.gd`, `test_meeting_voting_system.gd`, `test_meltdown_system.gd`, `test_lobby_system.gd`, `test_role_assignment.gd`, `test_multiplayer_server.gd`)
  - `docs/reviews/` (`step_8_review.md`, `step_9_review.md`, `step_10_review.md`)
  - `project.godot`, `scenes/main.tscn`, `scenes/main.gd`
- **Type of Change:** `Feature / Integration`
- **Description:**
  - Fast-forward merged commit `d900c09` ("backend ready") from `main` into `member-2/gameplay-backend`.
  - Integrated full server-authoritative gameplay infrastructure (Steps 1 through 10) built in Godot 4.x GDScript.
  - Enabled all 8 gameplay backend modules owned by Member 2 with comprehensive unit and integration test coverage under `tests/`.
- **Breaking Changes / Contract Impacts:** None. All server managers adhere to authoritative state contracts and emit synchronized network RPCs.
- **Verification / Testing:** All 10 test suites in `tests/` define automated headless test routines covering task validation, blackout timers, recovery thresholds, evidence logging, vote tallying, and meltdown resolution.

---

### [2026-09-17] — Project Status Dashboard & Change Log Initialization
- **Author:** Abdul Qadir & Antigravity (Pair Programming / M2 Lead)
- **Branch / PR:** `member-2/gameplay-backend`
- **Modules Affected:** `PROJECT_STATUS.md`, `README.md`, `TEAM_SPLIT.md`
- **Type of Change:** `Documentation / Process Setup`
- **Description:**
  - Created centralized `PROJECT_STATUS.md` dashboard for tracking project health, module completion, sprint roadmaps, and open questions.
  - Established formal Change Log Protocol and standardized entry template for all 8 team members.
  - Formulated comprehensive development workflow and module breakdown for Member 2 (Abdul Qadir, Gameplay Backend Engineer).
- **Breaking Changes / Contract Impacts:** None.
- **Verification / Testing:** Cross-referenced against `PRD.md`, `design.md`, and `TEAM_SPLIT.md` for 100% requirements coverage.

---

