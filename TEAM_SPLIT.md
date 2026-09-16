# BLACKOUT — Team Split & Ownership (8-Member Team)

**Companion docs:** [prd.md](file:///e:/projects/blackout/prd.md) (requirements/scope), [design.md](file:///e:/projects/blackout/design.md) (systems/architecture)

This document establishes the official ownership breakdown, module mapping, cross-functional pairings, and production workflow for an **8-member development team** building the MVP of **BLACKOUT**.

---

## 1. 8-Member Team Roster & Ownership Matrix

| Member | Role / Title | Primary Area | Key Modules Owned (`design.md` §6.3) | Primary Collaborators |
|---|---|---|---|---|
| **Member 1** | **Lead Backend & Network Engineer** | Core State Machine, Networking & Anti-Cheat | `game_state`, `role_manager`, `player` (server), networking | M2, M3, M8 |
| **Member 2** | **Gameplay Backend Engineer** | Game Phases, Objectives, Sabotage & Meltdown | `task_manager`, `blackout_manager`, `blackout_recovery`, `sabotage_manager`, `evidence_manager`, `meeting_manager`, `voting_manager`, `meltdown_manager`, `win_condition_manager` | M1, M4, M6 |
| **Member 3** | **Lead Client & Gameplay Programmer** | Controller, Traversal, Dynamic Vision & Engine | `player` (client), `map_manager` (client/rendering), camera, vision system | M1, M4, M7 |
| **Member 4** | **Client Interaction & Mini-Game Programmer** | Task Systems, Mini-Games & Objective Inputs | `crew_tasks` (client), `impostor_tasks` (client), mini-game layer | M2, M5, M6 |
| **Member 5** | **UI/UX Designer & Frontend Programmer** | All HUDs, Meeting/Voting Screens & Menus | `ui/` (`role_reveal`, `task_ui`, `blackout_ui`, `timer_ui`, `sabotage_ui`, `meeting_ui`, `voting_ui`, `meltdown_ui`, `result_screen`) | M3, M4, M6, M7 |
| **Member 6** | **Game Systems & Content Designer** | Task Specs, Balance, Evidence Rules & Map Flow | Content definitions, evidence rules, balance configs (§6.4) | M2, M4, M5, M7, M8 |
| **Member 7** | **2D Environment & Technical Artist** | Map Layouts, Dual Lighting, Sprites & VFX | Environment assets, sprite sheets, lighting states, VFX | M3, M5, M6 |
| **Member 8** | **Audio Designer & QA / Production Lead** | Soundscapes, SFX, Playtests & Scope Tracking | Audio engine/assets, playtest operations, QA & anti-cheat test suites | All Members |

---

## 2. Detailed Member Responsibilities & Deliverables

### Member 1 — Lead Backend & Network Engineer
**Focus:** Authoritative server architecture, real-time networking, state machine backbone, and anti-cheat validation.

- **Core Responsibilities:**
  - Implement the authoritative top-level state machine (`LOBBY → ROLE_ASSIGNMENT → INITIAL_TASK_PHASE → BLACKOUT_AVAILABLE → BLACKOUT_ACTIVE → POST_BLACKOUT_INVESTIGATION → MEETING → VOTING → MELTDOWN → GAME_OVER`).
  - Build room lifecycle and 8-player session lobby management (FR-1, FR-4).
  - Server-side role assignment and secure private role delivery (FR-2, FR-3).
  - Establish the client-server networking protocol, event architecture, and RPC contracts.
  - Implement player connection/disconnection handling and anti-cheat server validation (NFR-2, NFR-4, FR-43).
  - Ensure zero win-relevant state or role information is leaked to client instances.
- **Key Deliverables:**
  - `server/core/game_state`
  - `server/core/role_manager`
  - `server/network/` (room management, RPC dispatcher, heartbeat & disconnect handler)
  - Network API contract documentation for client engineers.

---

### Member 2 — Gameplay Backend Engineer
**Focus:** Server-authoritative phase logic, task validation, blackout mechanics, sabotage/evidence rules, meeting/voting, and meltdown.

- **Core Responsibilities:**
  - Task completion validation for Crew tasks and Impostor prerequisite tasks (FR-7, FR-8).
  - Blackout unlock logic, remote activation trigger, countdown, and configurable timer (FR-9, FR-10, FR-11, FR-17).
  - Distributed recovery system tracking (X-of-Y threshold logic, early blackout termination) (FR-19, FR-20, FR-21).
  - Impostor objective backend: Confidential File Theft validation, ORION Core extraction, instability calculation, and secondary sabotage actions (FR-22 to FR-26).
  - Evidence generation system: create server-tracked discoverable state flags upon sabotage (FR-27, FR-28).
  - Meeting management and voting resolution (plurality/majority rule, tie-breaker, ejection handling) (FR-30 to FR-33).
  - Meltdown Protocol logic: fixed 5-minute timer, 3 emergency task verifications, and active Impostor interference handling (FR-34 to FR-39).
  - Win/Loss condition evaluation and match finalization (FR-40 to FR-42).
- **Key Deliverables:**
  - `server/gameplay/task_manager`
  - `server/gameplay/blackout_manager` & `blackout_recovery`
  - `server/gameplay/sabotage_manager` & `evidence_manager`
  - `server/gameplay/meeting_manager` & `voting_manager`
  - `server/gameplay/meltdown_manager` & `win_condition_manager`

---

### Member 3 — Lead Client & Gameplay Programmer
**Focus:** 2D player movement, collision, camera systems, dynamic blackout lighting/vision, and room traversal.

- **Core Responsibilities:**
  - Responsive 2D top-down player movement, collision boundaries, and spawn point management.
  - Client-side prediction and smooth state reconciliation against authoritative server updates.
  - Dynamic blackout vision engine: vision cone / reduced radius occlusion, emergency lighting shader, and fog-of-war (FR-12).
  - Door state handling (open, closed, malfunctioning/jammed during blackout) and camera disablement (FR-13, FR-14).
  - Proximity detection and interactable trigger zones for task stations, recovery panels, and meeting areas.
  - Camera tracking, screen shake on alarms/countdown, and room-to-room transitions.
- **Key Deliverables:**
  - `client/player/` (controller, movement, state sync)
  - `client/rendering/vision_system` (lighting shaders, blackout vision cone)
  - `client/environment/interactable_trigger` & `door_controller`
  - Client networking bridge connecting to Member 1's server endpoints.

---

### Member 4 — Client Interaction & Mini-Game Programmer
**Focus:** Mini-game mechanics, interactive stations, input systems, and client-side gameplay feedback.

- **Core Responsibilities:**
  - Build interactive mini-game interfaces for all Crew Phase 1 tasks (Power Repair, Server Calibration, Coolant System, Medical Check, Data Transfer, etc.).
  - Build Impostor prerequisite task interactions (Terminal Check, Power Verification, Equipment Scan) matching Crew visual cues.
  - Build Impostor blackout objective interactions (Confidential File Theft at restricted terminal, ORION Core data extraction).
  - Build the 3 Meltdown emergency task mini-games (Restore Power, Restore Cooling, Stabilize ORION).
  - Manage interaction input controls (mouse/keyboard/gamepad), progress bars, completion callbacks, and interruption states.
  - Send validated action payloads to Member 2's backend endpoints.
- **Key Deliverables:**
  - `client/interactions/mini_games/` (crew tasks, prerequisite tasks, meltdown emergency tasks)
  - `client/interactions/sabotage_interactions/` (file theft terminal, core extraction station)
  - `client/interactions/interaction_framework` (input capture, progress timing, cancellation handling)

---

### Member 5 — UI/UX Designer & Frontend Programmer
**Focus:** User interface design, HUD elements, screen navigation, meeting/voting flows, and visual UX polish.

- **Core Responsibilities:**
  - In-game HUD: task checklist, blackout countdown banner, meltdown 5-minute emergency timer, recovery `X/Y` progress tracker.
  - Role reveal screen: dramatic private reveal card for Impostor and Crew.
  - Impostor-exclusive HUD overlays: `BLACKOUT READY [ACTIVATE]` remote trigger, hidden objective checklist, and sabotage action wheel.
  - Meeting & Voting UI: emergency meeting call alert, text chat interface, interactive voting grid with skip button, live vote tally animations, and ejection reveal screen.
  - Meltdown emergency HUD: flashing warning states, 3-task status indicators, and alarm styling.
  - Game Over & Result Screen: victory/defeat banners, role uncover recap, and match statistics.
  - Main menu, lobby room UI, player list, and settings/keybinding menus.
- **Key Deliverables:**
  - `client/ui/hud/` (task list, timers, recovery counters, sabotage prompt)
  - `client/ui/meeting/` & `client/ui/voting/` (chat, vote grid, tally, ejection)
  - `client/ui/screens/` (role reveal, lobby, meltdown alert, game over summary)

---

### Member 6 — Game Systems & Content Designer
**Focus:** Task specifications, gameplay balancing, evidence design, config tuning, and facility floorplan flow.

- **Core Responsibilities:**
  - Author detailed mechanical specifications for all ~10 Crew tasks, 3 Impostor prerequisite tasks, 5 Impostor blackout objectives, and 3 Meltdown emergency tasks.
  - Design the Evidence System: define exact rules for what evidence is generated per sabotage action (missing files flag, fake repair tells, damaged relays, tampered doors) and how Crew discovers them.
  - Own and tune all configuration values (`design.md` §6.4): blackout duration, recovery threshold (`3 of 4`), prerequisite task counts, visibility radius, vote rules (plurality vs. majority), and sabotage cooldowns.
  - Map & Level flow design: define room connectivity, traversal times, task station placement, recovery panel distribution, and alibi routing across all 9 facility rooms.
  - Formulate balance benchmarks (target 45–55% win rate between Crew and Impostor) and analyze playtest telemetry.
- **Key Deliverables:**
  - `design/specs/task_specifications.md`
  - `design/specs/evidence_matrix.md`
  - `config/game_balance_config.json` (server balance levers)
  - `design/specs/map_station_layout.md`

---

### Member 7 — 2D Environment & Technical Artist
**Focus:** Tilemaps, room art, dual-state lighting assets, character sprites, animations, and visual effects.

- **Core Responsibilities:**
  - Create 2D top-down environmental tilemaps and prop assets for all 9 facility rooms (Cafeteria, Security, Lab, Server Room, Storage, Generator, Office, MedBay, ORION Core) and corridors.
  - Produce dual lighting/visual states: Normal facility appearance vs. Emergency Blackout appearance (dim emergency lamps, flashing red sirens, heavy shadows).
  - Create visual states for interactive stations and props (intact, damaged/sabotaged, being repaired, repaired, evidence markers like empty file shelves).
  - Design 2D player character sprites, color variants, 4-directional walk cycles, idle animations, and interact/sabotage gestures.
  - Create visual FX: countdown overlays, electrical sparks, smoke, alarm flashes, vision-cone vignettes, and meltdown core distortion.
  - Integrate assets into the client rendering engine with proper sorting layers and collision boundaries.
- **Key Deliverables:**
  - `assets/sprites/environment/` (9 room tilemaps, furniture, interactive stations)
  - `assets/sprites/lighting/` (normal vs. emergency blackout asset variants)
  - `assets/sprites/characters/` (crew/impostor animations, directional sprites)
  - `assets/vfx/` (particles, alarms, UI animations)

---

### Member 8 — Audio Designer & QA / Production Lead
**Focus:** Soundscapes, audio implementation, 8-player playtest operations, test automation, and milestone tracking.

- **Core Responsibilities:**
  - Design, source, and integrate all game audio and soundscapes:
    - Ambient background loops: normal research facility hum vs. tense blackout atmospheric drone.
    - Blackout countdown stinger, power cutoff sound, and emergency siren loop.
    - Interaction SFX: mini-game clicks, slider feedback, sabotage sounds, and error/success cues.
    - UI & Event audio: meeting call stinger, voting clock ticking, ejection reveal chord, and victory/defeat stingers.
    - Escalating Meltdown tension audio track (intensifying as the 5-minute timer counts down).
  - Organize and run weekly 8-player playtest sessions, logging player feedback and balance data.
  - Author automated test suites and manual regression checklists for server-authority validation (preventing client cheating on tasks, votes, or roles).
  - Track sprint scope against `prd.md` MVP requirements and drive resolution of open project questions (§5).
- **Key Deliverables:**
  - `assets/audio/` (music loops, ambient tracks, SFX libraries)
  - `client/audio/audio_manager`
  - `tests/server_authority_tests/` & `tests/playtest_checklists/`
  - Sprint backlog, milestone tracking, and playtest balance reports.

---

## 3. Cross-Functional Pairings & Collaboration Matrix

To avoid communication silos and integration bottlenecks, the 8 members operate in designated cross-functional pairings:

```
[ BACKEND STREAM ]             [ CLIENT / FRONTEND STREAM ]           [ DESIGN & ART STREAM ]
  Member 1 (Core/Network)  <---->  Member 3 (Client Engine/Player)  <---->  Member 7 (2D Art & VFX)
       ↕                                  ↕                                       ↕
  Member 2 (Gameplay Logic) <---->  Member 4 (Mini-Games/Tasks)    <---->  Member 6 (Game Design)
                                          ↕
                                   Member 5 (UI/UX Frontend)
                                          ↕
                       [ Member 8: Audio & QA / Production (Cross-Cutting) ]
```

| Pair | Members | Primary Focus & Touchpoints |
|---|---|---|
| **Core Architecture Pair** | M1 (Lead Backend) + M3 (Lead Client) | Network protocol, RPC schemas, state machine synchronization, movement prediction, and server authority. |
| **Gameplay & Mechanics Pair** | M2 (Gameplay Backend) + M4 (Client Mini-Games) | Task validation protocols, mini-game completion handshakes, blackout unlock triggers, and sabotage execution. |
| **Interface & Content Pair** | M5 (UI/UX) + M6 (Game Designer) | HUD layout, meeting/voting UX flow, task copy, evidence presentation, and configuration UI bindings. |
| **World & Immersion Pair** | M7 (Environment Art) + M3 (Lead Client) + M8 (Audio) | Tilemap integration, collision layers, normal vs. blackout lighting shaders, dynamic audio triggers, and VFX. |
| **Balance & Playtest Pair** | M6 (Game Designer) + M8 (QA/Production) + M2 (Gameplay Backend) | Playtest telemetry, tuning config adjustments, edge-case validation, and anti-cheat regression tests. |

---

## 4. Sequencing & Sprint Roadmap for 8 Members

```
Sprint 1: Core Foundation & Map Layout
  M1: Server state machine skeleton & networking protocol
  M2: Task manager & role assignment backend
  M3: Player movement, collision, camera & spawn handling
  M4: Mini-game interaction framework & input handler
  M5: Main menu, lobby screen & role reveal UI
  M6: Task specs & 9-room facility layout design
  M7: 9-room tilemap layout & character base sprites
  M8: Core ambient audio & automated test harnesses

Sprint 2: Normal Phase & Blackout System
  M1: Authoritative phase transitions & player sync
  M2: Blackout unlock gate, remote trigger, timer & recovery tracking (X-of-Y)
  M3: Dynamic vision engine (blackout lighting & vision-cone shader)
  M4: Phase 1 Crew tasks & Impostor prerequisite task mini-games
  M5: In-game HUD, task checklist & blackout countdown UI
  M6: Blackout balance config & evidence generation rules
  M7: Normal vs. Emergency lighting tilemap variants & station props
  M8: Blackout countdown sound, power cut SFX & Phase 1 playtest pass

Sprint 3: Sabotage, Evidence & Meeting/Voting
  M1: Vote network events & anti-cheat validation
  M2: Sabotage backend, evidence flag generation & voting resolution
  M3: Door jamming mechanics & interactive evidence inspection triggers
  M4: Impostor file theft mini-game & Core extraction station
  M5: Emergency meeting call screen, live chat UI & voting interface
  M6: Evidence discoverability matrix & voting rule specs
  M7: Sabotaged prop states, evidence visual markers & UI icons
  M8: Meeting/voting audio cues & 8-player investigation playtest pass

Sprint 4: Meltdown Protocol & Game Over Loop
  M1: Game Over state resolution & match cleanup
  M2: Meltdown 5-minute timer, 3 emergency tasks & Impostor interference logic
  M3: Meltdown visual/audio alarm triggers & collision states
  M4: 3 Meltdown emergency mini-games (Power, Cooling, ORION stabilization)
  M5: Meltdown emergency HUD & final Result/Victory screen
  M6: Meltdown difficulty balance & tuning calibration
  M7: Meltdown core visual distortion VFX & end-screen victory art
  M8: Escalating meltdown tension music & full loop playtests

Sprint 5: Balance Tuning, Hardening & MVP Polish
  All Members: Full 8-player playtesting cadence, server authority regression hardening, audio/visual polish, and bug triage.
```

---

## 5. Ownership of Open Questions (`prd.md` §9)

| Open Question | Primary Owner | Supporting Members | Target Resolution Milestone |
|---|---|---|---|
| **1. Platform target (PC, Web, or Mobile)** | Member 1 & Member 3 | Member 5, Member 8 | Sprint 1 Kickoff |
| **2. Vote resolution rule (Plurality vs. Majority & Ties)** | Member 6 (Design) | Member 2 (Backend) | Sprint 2 |
| **3. Meeting trigger mechanism (Button vs. Body/Evidence)** | Member 6 (Design) | Member 2, Member 5 | Sprint 2 |
| **4. Communication scope during blackout (Proximity vs. Muted)** | Member 6 & Member 1 | Member 3, Member 8 | Sprint 2 |
| **5. Disconnect/reconnect handling policy** | Member 1 (Backend) | Member 8 (QA/Production) | Sprint 1 |
| **6. Blackout duration default value** | Member 6 (Design) | Member 8 (Playtesting) | Sprint 3 (Playtest data) |
| **7. Required recovery systems threshold (e.g., 3-of-4)** | Member 6 (Design) | Member 2, Member 8 | Sprint 3 (Playtest data) |
| **8. Anti-griefing measures (Meeting spam, AFK in Meltdown)** | Member 1 & Member 6 | Member 2, Member 8 | Sprint 4 |
| **9. Engine / Networking stack selection** | Member 1 & Member 3 | Member 4, Member 7 | Sprint 1 Kickoff |

---

## 6. Code Ownership & Review Guidelines

To maintain code quality and prevent regressions across the 8-person team:

1. **Server Authority Rule:** Any PR touching win conditions, timers, task completion, or role reveals **must be reviewed and approved by Member 1 or Member 2**.
2. **Design Integrity Rule:** Any PR modifying task durations, balance configs, or evidence logic **must be reviewed and approved by Member 6**.
3. **Asset & UI Rule:** Any PR modifying shaders, UI components, or tilemaps **must be reviewed by Member 5 or Member 7**.
4. **Build & Test Verification:** No branch may be merged without passing automated server authority and regression tests maintained by Member 8.
