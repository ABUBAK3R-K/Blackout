# Member 8 — Open Questions & Missing Integration Points

**Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Last Updated:** September 20, 2026  
**Project:** BLACKOUT (8-Player Social Deduction Game in Godot 4.x)  

---

## Executive Summary

This document tracks all cross-functional integration requirements, missing events, network RPC synchronization gaps, and environment dependencies identified by Member 8 during audio engineering and QA test suite integration.

Per strict team boundaries, Member 8 does NOT modify the codebases of Members 1–7. These integration requirements are tracked here for resolution by the respective module owners.

---

## Dependency & Integration Tracking

### Item 1: Invalid / Denied Interaction Feedback Event
- **Issue:** Station interaction trigger does not emit rejection feedback when an invalid, cooling-down, unauthorized, or out-of-phase interaction attempt occurs.
- **Affected system:** `client/interactions/interaction_framework/interactable_station.gd` (`InteractableStation`)
- **Why Member 8 needs it:** The audio design requires an immediate auditory negative feedback cue (error buzz / locked beep `SFX_TASK_ERROR`) when a player presses `E` on an interactable station that is disabled, on cooldown, not assigned to their role, or invalid during the current phase.
- **Expected integration:** In `InteractableStation.trigger_interaction()`, emit a signal such as `signal interaction_rejected(station: InteractableStation, reason: String)` or `signal interaction_failed(station: InteractableStation)` when the interaction controller cannot open or rejects the interaction.
- **Responsible area:** Member 4 (Ubaid — Client Interaction & Mini-Game Programmer)
- **Current status:** **BLOCKED** (Awaiting implementation by Member 4; no modifying changes made by Member 8).

---

### Item 2: Client-Side Voting Timer Countdown Tick
- **Issue:** No client-side periodic signal or RPC exists to notify audio and UI of remaining voting seconds during the active voting window.
- **Affected system:** `client/client_network_manager.gd` (`ClientNetworkManager`) / `server/meeting_manager.gd`
- **Why Member 8 needs it:** To trigger the urgent clock-ticking SFX (`UI_VOTING_TICK`) as the voting window counts down, particularly during the critical final 5 seconds before vote lock.
- **Expected integration:** Expose `signal voting_tick(remaining_seconds: float)` on `ClientNetworkManager` driven by a synchronized client-side timer or periodic RPC from the server's authoritative `MeetingManager.voting_tick`.
- **Responsible area:** Member 1 (Mayiz — Lead Backend & Network Engineer) / Member 5 (Shahzan — UI/UX Designer & Frontend)
- **Current status:** **OPEN** (Server maintains authoritative timer; network RPC broadcast to clients not yet implemented).

---

### Item 3: Client-Side Meltdown Countdown Tick / Tension Update
- **Issue:** Client only receives the initial `meltdown_started(duration, impostor_alive)` signal, with no subsequent periodic timer tick or remaining duration updates sent over the network.
- **Affected system:** `client/client_network_manager.gd` (`ClientNetworkManager`) / `server/meltdown_manager.gd`
- **Why Member 8 needs it:** `AudioManager.update_meltdown_intensity(remaining_time, total_duration)` dynamically modulates the Meltdown alarm pitch (scaling smoothly from 1.0 up to 1.35x) and boosts decibels (+3 dB) as the 5-minute countdown elapses. Without periodic ticks, the audio manager cannot smoothly scale alarm tension in real time.
- **Expected integration:** Add a client-side timer or synchronized RPC in `ClientNetworkManager` emitting `signal meltdown_tick(remaining_time: float)` on each elapsed second during the Meltdown phase.
- **Responsible area:** Member 1 (Mayiz — Lead Backend & Network Engineer) / Member 2 (Abdul Qadir — Gameplay Backend Engineer)
- **Current status:** **OPEN** (API hook `update_meltdown_intensity` is ready in `AudioManager`; client event hook pending from Members 1 and 2).

---

### Item 4: Global Sabotage Alarm Trigger Broadcast
- **Issue:** When the Impostor initiates a sabotage (generator tampering, relay sabotage, door jam), no non-identifying broadcast is sent to notify facility occupants.
- **Affected system:** `client/client_network_manager.gd` (`ClientNetworkManager`) / `server/server_network_manager.gd`
- **Why Member 8 needs it:** An emergency facility audio warning cue (`SFX_DOOR_JAM` or localized klaxon) must play to warn nearby players or the entire facility without leaking the Impostor's identity.
- **Expected integration:** When the server's `SabotageManager` / `ImpostorObjectiveManager` activates a sabotage event, broadcast an authoritative RPC to clients emitting `signal sabotage_alarm_triggered(sabotage_type: String, room_id: String)`.
- **Responsible area:** Member 1 (Mayiz — Lead Backend) & Member 2 (Abdul Qadir — Gameplay Backend)
- **Current status:** **OPEN** (Awaiting network broadcast hook; audio asset definition and playback methods are prepared).

---

### Item 5: Headless Godot Engine CLI in Execution Environment
- **Issue:** The execution environment does not have `godot` or `godot4` installed in system PATH or available via command-line invocation.
- **Affected system:** Test execution environment / CI runner
- **Why Member 8 needs it:** To run the master automated test manifest `tests/run_all_tests.gd`, the 10-test audio suite `tests/test_audio_manager.gd`, and the 6 server-authority anti-cheat test suites (`tests/server_authority_tests/`).
- **Expected integration:** Install Godot 4.x headless binary or add Godot executable path to system environment `PATH` for CI/CD and local terminal test execution.
- **Responsible area:** DevOps / Environment / System Configuration
- **Current status:** **BLOCKED** (Test files are 100% written, statically analyzed, and registered in `run_all_tests.gd`; execution is blocked strictly by environment tooling).

---

### Item 6: Physical Audio Assets Ingestion
- **Issue:** Physical sound files (`.ogg`, `.wav`, `.mp3`) are not yet checked into `assets/audio/`.
- **Affected system:** `assets/audio/` directory hierarchy
- **Why Member 8 needs it:** To replace procedural synthesizer waveform fallbacks with final studio-quality music, ambient loops, and foley sound effects.
- **Expected integration:** Import finished audio assets into the designated subfolders:
  - `assets/audio/music/` (`normal/`, `blackout/`, `meltdown/`)
  - `assets/audio/ambience/` (`facility/`, `blackout/`)
  - `assets/audio/sfx/` (`tasks/`, `sabotage/`, `meeting/`, `voting/`, `ejection/`, `ui/`)
  - `assets/audio/stingers/` (`blackout_start/`, `meeting/`, `victory/`, `defeat/`)
- **Responsible area:** Audio Production / Member 8
- **Current status:** **BLOCKED** (Awaiting finalized external sound files; directory structure created with `.gitkeep` and runtime procedural synthesis operational).

---

## Status Classification Legend

- **OPEN:** The item is documented, design requirements are clear, and implementation is pending by the responsible team member.
- **RESOLVED:** The item has been implemented, integrated, and verified against Member 8's systems.
- **BLOCKED:** Progress on testing or functional verification of this item cannot proceed due to external tooling, missing upstream code, or missing physical assets.
- **NO LONGER REQUIRED:** Architectural changes or alternative implementations have made this requirement obsolete.
