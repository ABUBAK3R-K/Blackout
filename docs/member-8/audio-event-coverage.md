# BLACKOUT — Member 8 Audio Event Coverage Audit

**Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Status:** Content-Complete (Real Uncompressed 16-bit 44.1kHz PCM Audio Assets)  

---

## 1. Executive Summary

This document maps all high-level gameplay events, network signals, and interaction triggers in BLACKOUT directly to Member 8's `AudioRegistry` identifiers, their resolved physical audio assets, and their operational readiness.

Every registered audio event now resolves to a verified physical audio asset on disk (`assets/audio/...`), backed by procedural waveform fallback synthesis in `AudioManager` for defense-in-depth safety.

---

## 2. Gameplay Event to Audio Mapping Matrix

### Normal Facility & Exploration Phase
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Match Initialized / Task Phase | `ClientNetworkManager.game_state_changed(INITIAL_TASK_PHASE)` | `ambience_facility_hum` | `assets/audio/ambience/facility/facility_hum.wav` | **READY** |
| Background Exploration Music | `ClientNetworkManager.game_state_changed(INITIAL_TASK_PHASE)` | `music_normal` | `assets/audio/music/normal/normal_gameplay_music.wav` | **READY** |
| Station Focus / Proximity | `InteractableStation.player_entered_station` | `ui_hover` | `assets/audio/sfx/ui/ui_hover.wav` | **READY** |
| Station Trigger / Open | `InteractableStation.interaction_triggered` | `sfx_task_click` | `assets/audio/sfx/tasks/task_click.wav` | **READY** |

### Task System & Mini-Games
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Mini-Game Started | `MiniGameBase.interaction_started` | `sfx_task_click` | `assets/audio/sfx/tasks/task_click.wav` | **READY** |
| Mini-Game Step Advance | `MiniGameBase.progress_changed` | `sfx_task_progress` | `assets/audio/sfx/tasks/task_progress.wav` | **READY** |
| Mini-Game Completed | `MiniGameBase.interaction_completed` | `sfx_task_success` | `assets/audio/sfx/tasks/task_success.wav` | **READY** |
| Mini-Game Failed / Rejected | `MiniGameBase.interaction_failed` | `sfx_task_error` | `assets/audio/sfx/tasks/task_error.wav` | **READY** |
| Mini-Game Cancelled / Exited | `MiniGameBase.interaction_cancelled` | `ui_click` | `assets/audio/sfx/ui/ui_click.wav` | **READY** |
| Local Task Confirmed Complete | `ClientNetworkManager.task_completed_locally` | `sfx_task_success` | `assets/audio/sfx/tasks/task_success.wav` | **READY** |

### Blackout Lifecycle
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Blackout Unlocked (Impostor) | `ClientNetworkManager.blackout_unlocked_for_impostor` | `ui_click` | `assets/audio/sfx/ui/ui_click.wav` | **READY** |
| Blackout Remote Trigger | `BlackoutManager.request_activation` / Trigger SFX | `sfx_blackout_trigger` | `assets/audio/sfx/blackout/blackout_trigger.wav` | **READY** |
| Blackout Warning Countdown (3s) | `ClientNetworkManager.blackout_countdown_started` | `sfx_blackout_countdown` | `assets/audio/sfx/blackout/blackout_countdown.wav` | **READY** |
| Blackout Stinger Hit | `ClientNetworkManager.blackout_started` | `stinger_blackout_start` | `assets/audio/stingers/blackout_start/stinger_blackout_start.wav` | **READY** |
| Power Cutoff Breaker Trip | `ClientNetworkManager.blackout_started` | `sfx_power_cut` | `assets/audio/sfx/blackout/power_cut.wav` | **READY** |
| Blackout Atmospheric Drone | `ClientNetworkManager.blackout_started` | `ambience_blackout_drone` | `assets/audio/ambience/blackout/blackout_drone.wav` | **READY** |
| Blackout Tension Music | `ClientNetworkManager.blackout_started` | `music_blackout` | `assets/audio/music/blackout/blackout_tension_music.wav` | **READY** |
| Recovery Panel Repaired | `ClientNetworkManager.recovery_system_updated` | `sfx_power_restore` | `assets/audio/sfx/blackout/power_restore.wav` | **READY** |
| Blackout Ended / Power Restored | `ClientNetworkManager.blackout_ended` | `sfx_power_restore` | `assets/audio/sfx/blackout/power_restore.wav` | **READY** |

### Sabotage & Evidence
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Door Sabotage / Door Jam | `SabotageManager` / Door lock event | `sfx_door_jam` | `assets/audio/sfx/sabotage/door_jam.wav` | **READY** |
| Impostor Objective Completed | `ClientNetworkManager.impostor_objective_updated` | `sfx_sabotage_execute` | `assets/audio/sfx/sabotage/sabotage_execute.wav` | **READY** |
| Clue / Physical Evidence Found | Evidence interaction / inspection | `sfx_evidence_found` | `assets/audio/sfx/meeting/evidence_found.wav` | **READY** |

### Emergency Meetings & Voting
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Emergency Meeting Called | `ClientNetworkManager.meeting_started` | `stinger_meeting` / `ui_meeting_called` | `assets/audio/stingers/meeting/stinger_meeting.wav` | **READY** |
| Voting Phase Started | `ClientNetworkManager.voting_started` | `ui_voting_tick` | `assets/audio/sfx/voting/voting_tick.wav` | **READY** |
| Player Vote Cast | `ClientNetworkManager.player_voted` | `ui_vote_cast` | `assets/audio/sfx/voting/vote_cast.wav` | **READY** |
| Vote Result: Ejection Stinger | `ClientNetworkManager.vote_result_received` (elimination) | `ui_ejection_reveal` | `assets/audio/sfx/ejection/ejection_reveal.wav` | **READY** |
| Vote Result: Tie / No Ejection | `ClientNetworkManager.vote_result_received` (no ejection) | `ui_click` | `assets/audio/sfx/ui/ui_click.wav` | **READY** |

### Meltdown Protocol & Endgame
| Gameplay Event | Originating Signal / Hook | Audio Identifier | Real Physical Asset Path | Status |
|---|---|---|---|---|
| Meltdown Started | `ClientNetworkManager.meltdown_started` | `ambience_meltdown_alarm` | `assets/audio/ambience/meltdown/meltdown_drone.wav` | **READY** |
| Meltdown Siren Alarm Music | `ClientNetworkManager.meltdown_started` | `music_meltdown` | `assets/audio/music/meltdown/meltdown_alarm.wav` | **READY** |
| Emergency System Repaired | `ClientNetworkManager.emergency_system_completed` | `sfx_task_success` | `assets/audio/sfx/tasks/task_success.wav` | **READY** |
| Match Ended: Crew Victory | `ClientNetworkManager.game_over_received` (CREW) | `stinger_victory` / `ui_crew_victory` | `assets/audio/stingers/victory/stinger_victory.wav` | **READY** |
| Match Ended: Impostor Victory | `ClientNetworkManager.game_over_received` (IMPOSTOR) | `stinger_defeat` / `ui_impostor_victory` | `assets/audio/stingers/defeat/stinger_defeat.wav` | **READY** |

---

## 3. Summary & Coverage Verdict

- **Total Registered Events:** 29
- **Events Covered with Verified Real Audio Files:** 29 (100%)
- **Missing Audio Assets:** 0
- **Fallback Redundancy:** 100% active in `AudioManager`
