# Member 8 — Sprint Backlog & Production Tracking

**Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Last Updated:** September 20, 2026  
**Project:** BLACKOUT (8-Player Social Deduction Game in Godot 4.x)  

---

## Overview

This sprint backlog tracks all deliverables, quality assurance milestones, playtest assets, and cross-member integration touchpoints exclusively owned by **Member 8 (Sahil)**.

Per project team boundaries, Member 8 does not implement or alter gameplay mechanics, networking, or UI belonging to Members 1–7. Testing and defect reporting are conducted against external interfaces.

---

## Audio

| Task ID | Task Description | Scope | Status | Notes |
|---|---|---|---|---|
| AUD-01 | Design centralized `AudioRegistry` with event IDs, bus assignments, and fallback waveforms | `assets/audio/audio_registry.gd` | **DONE** | Defines buses (`Master`, `Music`, `SFX`, `Ambience`, `UI`), category enums, sound definitions, and synthetic wave defaults. |
| AUD-02 | Implement centralized `AudioManager` singleton / service | `client/audio/audio_manager.gd` | **DONE** | Dynamic soundscape management, dual-player ambience crossfading, music fading, SFX polyphonic pool (12 voices), stinger player, and bus volume controls. |
| AUD-03 | Implement runtime procedural fallback synthesis | `client/audio/audio_manager.gd` | **DONE** | Generates real-time 16-bit PCM waveforms (`AudioStreamWAV`) for missing audio assets to guarantee zero crashes during headless or early development. |
| AUD-04 | Implement non-invasive `GameplayAudioBridge` observer | `client/audio/gameplay_audio_bridge.gd` | **DONE** | Connects to `ClientNetworkManager`, `InteractableStation`, `MiniGameBase`, and `FacilityLightingController` signals without mutating gameplay logic. |
| AUD-05 | Create Godot 4 default bus layout resource | `client/audio/default_bus_layout.tres` | **DONE** | Defines hierarchy routing `Music`, `SFX`, `Ambience`, and `UI` buses into `Master`. |
| AUD-06 | Implement Blackout audio transitions | `client/audio/audio_manager.gd` | **DONE** | `start_blackout_audio()` and `stop_blackout_audio()` trigger power cut SFX, blackout stinger, drone ambience, and tension music. |
| AUD-07 | Implement Meltdown audio scaling | `client/audio/audio_manager.gd` | **DONE** | `start_meltdown_audio()`, `update_meltdown_intensity()` scaling pitch (1.0 to 1.35) and volume (+3 dB), and `stop_meltdown_audio()`. |
| AUD-08 | Prepare production audio asset folder hierarchy | `assets/audio/` | **DONE** | Standardized folder structure established across music, ambience, sfx, and stingers with `.gitkeep` placeholders. |
| AUD-09 | Import and configure physical `.ogg`/`.wav` sound assets | `assets/audio/` | **DONE** | 29 authentic, uncompressed 16-bit 44.1kHz PCM WAV audio assets generated, verified on disk, and mapped in `AudioRegistry`. |

---

## QA

| Task ID | Task Description | Scope | Status | Notes |
|---|---|---|---|---|
| QA-01 | Author automated unit/integration test suite for audio layer | `tests/test_audio_manager.gd` | **READY FOR TEST** | 11 headless test cases verifying initialization, music, crossfade ambience, SFX pool, blackout/meltdown lifecycles, bridge signals, fallback, and real asset resolution. |
| QA-02 | Author server-authority anti-cheat suite: Task Spoofing | `tests/server_authority_tests/test_anti_cheat_tasks.gd` | **READY FOR TEST** | 5 tests validating role, assignment, alive state, and phase validation on server `TaskManager`. |
| QA-03 | Author server-authority anti-cheat suite: Blackout Authority | `tests/server_authority_tests/test_anti_cheat_blackout.gd` | **READY FOR TEST** | 6 tests validating Impostor-only activation, prerequisite lock, active state guards, and 3-of-4 recovery threshold. |
| QA-04 | Author server-authority anti-cheat suite: Meeting & Voting | `tests/server_authority_tests/test_anti_cheat_voting.gd` | **READY FOR TEST** | 5 tests validating voting phases, dead player vote rejection, invalid target guards, double-vote mitigation, and cooldowns. |
| QA-05 | Author server-authority anti-cheat suite: Meltdown Sabotage | `tests/server_authority_tests/test_anti_cheat_meltdown.gd` | **READY FOR TEST** | 6 tests validating Impostor block on repairs, dead crew rejection, phase lock, and post-match freeze. |
| QA-06 | Author server-authority anti-cheat suite: Role Authority | `tests/server_authority_tests/test_anti_cheat_roles.gd` | **READY FOR TEST** | 7 tests validating 8-player requirement, strict 1 Impostor/7 Crew distribution, private role delivery, and client tampering immunity. |
| QA-07 | Author server-authority anti-cheat suite: Timers & Disconnects | `tests/server_authority_tests/test_anti_cheat_timers.gd` | **READY FOR TEST** | 8 tests validating server-clocked Blackout/Meltdown/Meeting timers, socket disconnection safety, and input sanitization. |
| QA-08 | Register Member 8 QA suites into master test runner | `tests/run_all_tests.gd` | **DONE** | Master manifest updated to coordinate all 13 project suites (7 core + 6 dedicated Member 8 anti-cheat/audio suites). |
| QA-09 | Headless runtime execution of all test suites via Godot CLI | Command line | **BLOCKED** | Godot binary (`godot` / `godot4`) not available in execution environment PATH. |

---

## Playtesting

| Task ID | Task Description | Scope | Status | Notes |
|---|---|---|---|---|
| PLY-01 | Review existing playtest checklist materials | `tests/playtest_checklists/` | **DONE** | Inspected `playtest_checklist_8player.md` and `anti_cheat_test_matrix.md` for test coverage. |
| PLY-02 | Author comprehensive 8-Player Smoke Test document | `docs/member-8/8-player-smoke-test.md` | **DONE** | End-to-end 10-phase operational protocol: Connection, Lobby, Role Assignment, Tasks, Blackout, Investigation, Meeting, Voting, Ejection, Meltdown/Endgame. |
| PLY-03 | Define qualitative audio and UX evaluation checkpoints | `docs/member-8/8-player-smoke-test.md` | **DONE** | Embedded audio clarity, stinger timing, spatial ambience, and HUD audio balance criteria. |
| PLY-04 | Conduct live 8-player synchronized playtest session | Multiplayer session | **BLOCKED** | Requires full team assembly, network deployment, and physical runtime clients. |

---

## Regression

| Task ID | Task Description | Scope | Status | Notes |
|---|---|---|---|---|
| REG-01 | Establish defect severity classification matrix (P0–P3) | `docs/member-8/8-player-smoke-test.md` | **DONE** | Outlines Blocker, Critical, Major, and Minor tiers with reproduction requirements and SLAs. |
| REG-02 | Create subsystem defect routing directory for Members 1–7 | `docs/member-8/8-player-smoke-test.md` | **DONE** | Strict routing table mapping subsystems, branches, and responsible team members without boundary breaches. |
| REG-03 | Standardize defect report template | `docs/member-8/8-player-smoke-test.md` | **DONE** | Structured template for playtester/QA reporting (environment, repro steps, expected vs. actual, logs). |
| REG-04 | Establish active regression and defect log | `docs/member-8/8-player-smoke-test.md` | **DONE** | Tracks known issues, affected subsystems, and verification status across sprint milestones. |

---

## Production Tracking

| Task ID | Task Description | Scope | Status | Notes |
|---|---|---|---|---|
| PRD-01 | Initial repository architecture review and scope audit | `docs/member-8/member-8-initial-review.md` | **DONE** | Full baseline audit of existing systems and boundary definitions. |
| PRD-02 | Step-by-step milestone review documentation | `docs/member-8/reviews/` | **DONE** | Reviews created for Step 2 (Audio Foundation), Step 3 (Gameplay Audio), Step 4 (Audio QA), Step 5 (Server QA), and Step 6 (Playtest/Regression). |
| PRD-03 | Maintain Sprint Backlog | `docs/member-8/sprint-backlog.md` | **DONE** | Complete production backlog for Member 8 deliverables. |
| PRD-04 | Maintain Milestone Tracker | `docs/member-8/milestone-tracker.md` | **DONE** | Status and evidence tracking across all Member 8 responsibilities. |
| PRD-05 | Document open integration questions and external dependencies | `docs/member-8/open-questions.md` | **DONE** | Tracks missing client signals and backend broadcasts needed for full audio fidelity. |
| PRD-06 | Final Member 8 Review document | `docs/member-8/reviews/member-8-final-review.md` | **DONE** | Comprehensive 12-section milestone review. |
| PRD-07 | Final Member 8 Handoff document | `docs/member-8/member-8-handoff.md` | **DONE** | Practical team-facing guide for integrating with Member 8 systems. |
| PRD-08 | Audio Asset Manifest & Event Coverage | `docs/member-8/` | **DONE** | `audio-asset-manifest.md` (29 assets verified) and `audio-event-coverage.md`. |

---

## Blocked / Waiting for Other Members

| Item | Responsible Member | Impact on Member 8 | Status | Current Mitigation |
|---|---|---|---|---|
| Station interaction rejection signal | Member 4 (Ubaid) | Cannot trigger error buzz SFX on invalid interaction | **BLOCKED** | Documented in `docs/member-8/open-questions.md` Item 1. |
| Client-side voting countdown tick RPC | Member 1 (Mayiz) / Member 5 (Shahzan) | Cannot play ticking clock SFX during final 5s of voting | **BLOCKED** | Documented in `docs/member-8/open-questions.md` Item 2. |
| Client-side meltdown countdown tick RPC | Member 1 (Mayiz) / Member 2 (Abdul Qadir) | Cannot dynamically modulate Meltdown pitch/volume in real time | **BLOCKED** | Documented in `docs/member-8/open-questions.md` Item 3. API ready in `AudioManager`. |
| Global sabotage alarm trigger RPC | Member 1 (Mayiz) / Member 2 (Abdul Qadir) | Cannot trigger facility-wide klaxon upon sabotage activation | **BLOCKED** | Documented in `docs/member-8/open-questions.md` Item 4. |
| Godot CLI binary in runtime environment | Infrastructure / CI | Cannot execute headless test suite commands directly | **BLOCKED** | Tests fully authored, statically verified, and registered in test manifest. |

---

## Completed

- [x] AUD-01: Centralized `AudioRegistry` (`assets/audio/audio_registry.gd`)
- [x] AUD-02: Centralized `AudioManager` (`client/audio/audio_manager.gd`)
- [x] AUD-03: Procedural waveform synthesis fallback (`client/audio/audio_manager.gd`)
- [x] AUD-04: Non-invasive `GameplayAudioBridge` (`client/audio/gameplay_audio_bridge.gd`)
- [x] AUD-05: Default bus layout configuration (`client/audio/default_bus_layout.tres`)
- [x] AUD-06: Blackout audio lifecycle transitions (`client/audio/audio_manager.gd`)
- [x] AUD-07: Meltdown audio lifecycle and dynamic pitch/volume scaling (`client/audio/audio_manager.gd`)
- [x] AUD-08: Production audio asset directory hierarchy (`assets/audio/`)
- [x] AUD-09: Real physical audio asset synthesis & integration (29 assets verified in `assets/audio/`)
- [x] QA-01: Audio integration test suite (`tests/test_audio_manager.gd`)
- [x] QA-02: Anti-Cheat Task Spoofing test suite (`tests/server_authority_tests/test_anti_cheat_tasks.gd`)
- [x] QA-03: Anti-Cheat Blackout Authority test suite (`tests/server_authority_tests/test_anti_cheat_blackout.gd`)
- [x] QA-04: Anti-Cheat Meeting & Voting test suite (`tests/server_authority_tests/test_anti_cheat_voting.gd`)
- [x] QA-05: Anti-Cheat Meltdown Sabotage test suite (`tests/server_authority_tests/test_anti_cheat_meltdown.gd`)
- [x] QA-06: Anti-Cheat Role Authority test suite (`tests/server_authority_tests/test_anti_cheat_roles.gd`)
- [x] QA-07: Anti-Cheat Timers & Disconnects test suite (`tests/server_authority_tests/test_anti_cheat_timers.gd`)
- [x] QA-08: Registration of all suites into master runner (`tests/run_all_tests.gd`)
- [x] PLY-01: Playtest checklist review (`tests/playtest_checklists/`)
- [x] PLY-02: Comprehensive 8-Player Smoke Test protocol (`docs/member-8/8-player-smoke-test.md`)
- [x] PLY-03: Qualitative audio evaluation checkpoints (`docs/member-8/8-player-smoke-test.md`)
- [x] REG-01: Defect severity classification matrix (`docs/member-8/8-player-smoke-test.md`)
- [x] REG-02: Subsystem defect routing directory (`docs/member-8/8-player-smoke-test.md`)
- [x] REG-03: Standardized defect report template (`docs/member-8/8-player-smoke-test.md`)
- [x] REG-04: Live defect and regression log (`docs/member-8/8-player-smoke-test.md`)
- [x] PRD-01: Initial repository review (`docs/member-8/member-8-initial-review.md`)
- [x] PRD-02: Step-by-step milestone reviews (`docs/member-8/reviews/`)
- [x] PRD-03: Sprint backlog (`docs/member-8/sprint-backlog.md`)
- [x] PRD-04: Milestone tracker (`docs/member-8/milestone-tracker.md`)
- [x] PRD-05: Open questions and integration dependencies (`docs/member-8/open-questions.md`)
- [x] PRD-06: Final Member 8 Review (`docs/member-8/reviews/member-8-final-review.md`)
- [x] PRD-07: Final Member 8 Handoff (`docs/member-8/member-8-handoff.md`)
