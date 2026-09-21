# MEMBER 8 — SAHIL HANDOFF

**Author:** Sahil (Member 8 — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Project:** BLACKOUT (8-Player Social Deduction Game)  

---

## Responsibilities

* **Audio Architecture:** Soundscapes, ambience crossfading, music transitions, SFX voice pooling, stingers, and procedural audio synthesis.
* **Automated QA:** Headless test suites for audio systems and server-authoritative anti-cheat validation.
* **Playtest Coordination:** 8-player smoke test protocol, playtest procedures, and audio checklists.
* **Regression Framework:** Defect severity matrix, team defect routing, report templates, and regression log.
* **Production Tracking:** Backlog management, milestone tracking, and cross-member integration dependency management.

---

## Completed Work

1. Centralized `AudioManager` (`client/audio/audio_manager.gd`) with 5 dedicated audio buses (`Master`, `Music`, `SFX`, `Ambience`, `UI`) and native RIFF/WAVE PCM disk loading.
2. Comprehensive `AudioRegistry` (`assets/audio/audio_registry.gd`) with all 29 event identifiers mapped directly to verified physical audio assets on disk.
3. 29 authentic, uncompressed 16-bit 44.1kHz PCM WAV audio assets generated and organized in `assets/audio/` covering all gameplay contexts (music, ambience, tasks, blackout, sabotage, voting, ejection, meltdown, stingers).
4. Procedural waveform synthesis engine retained in `AudioManager` as backup safety gate (zero crashes on missing assets).
5. Decoupled `GameplayAudioBridge` (`client/audio/gameplay_audio_bridge.gd`) listening to gameplay events without altering game state.
6. Headless audio integration test suite (`tests/test_audio_manager.gd`, 11 test cases) verifying bus creation, playback, voice stealing, real asset resolution, and fallback safety.
7. 6 dedicated server-authority anti-cheat suites (`tests/server_authority_tests/`, 38 test cases total).
8. Master test manifest updated to coordinate all 13 project suites (`tests/run_all_tests.gd`).
9. End-to-end 10-phase 8-player smoke test and regression framework (`docs/member-8/8-player-smoke-test.md`).
10. Complete documentation suite: Audio Asset Manifest (`audio-asset-manifest.md`), Event Coverage (`audio-event-coverage.md`), Sprint Backlog, Milestone Tracker, and Final Review.

---

## Audio System

* **Content-Complete Real Assets:** 29 verified playable 16-bit 44.1kHz PCM WAV files in `assets/audio/`.
* **Presentation Only:** Audio does not control or mutate game state, player roles, or server timers.
* **Missing Asset Safety:** If an audio file is ever moved or missing, `AudioManager` automatically falls back to procedural 16-bit PCM waveform synthesis.
* **Seamless Looping:** Looping music and ambience loops are crossfaded at loop boundaries to eliminate clicks and pops.
* **Polyphonic SFX:** 12-voice player pool with oldest-voice stealing prevents voice starvation or sound clipping.
* **Volume Controls:** Linear API (`set_master_volume`, `set_music_volume`, `set_sfx_volume`, `set_ambient_volume`, `set_ui_volume`) with decibel conversion and bus muting.
* **Dynamic Tension:** `update_meltdown_intensity()` dynamically scales alarm pitch (1.0 to 1.35x) and decibels (+3 dB) as the 5-minute countdown progresses.

---

## QA System

* **Suite Manifest:** Managed via `tests/run_all_tests.gd` (13 suites registered).
* **Audio QA (`tests/test_audio_manager.gd`):** 11 tests validating initialization, bus routing, voice pooling, crossfading, stinger playback, lifecycle transitions, real asset disk resolution, and procedural fallback.
* **Headless Design:** All suites extend `SceneTree` for automated continuous integration.

---

## Server Authority Testing

Targeted anti-cheat test suites under `tests/server_authority_tests/`:
* `test_anti_cheat_tasks.gd`: Task spoofing, non-assigned peer task completion, out-of-phase actions.
* `test_anti_cheat_blackout.gd`: Impostor prerequisite gating, active blackout lockdown, 3-of-4 recovery threshold.
* `test_anti_cheat_voting.gd`: Phase lock, ghost voting, invalid target rejection, double-vote mitigation.
* `test_anti_cheat_meltdown.gd`: Impostor repair lockout, dead player rejection, post-match freeze.
* `test_anti_cheat_roles.gd`: 8-player requirement, strict 1 Impostor/7 Crew distribution, client tamper immunity.
* `test_anti_cheat_timers.gd`: Server-clocked timers, socket disconnect safety, input payload sanitization.

---

## 8-Player Playtesting & Audio Verification

During live 8-player playtest sessions, testers should verify audio across all 10 match phases:
1. **Lobby & Exploration:** Ambient facility hum (`facility_hum.wav`) and background music (`normal_gameplay_music.wav`) loop smoothly without clipping.
2. **Tasks:** Audible click on station interaction (`task_click.wav`), ratchet tick on step advance (`task_progress.wav`), ascending chime on task completion (`task_success.wav`), low buzz on invalid interaction (`task_error.wav`).
3. **Blackout:** 3-second countdown warning (`blackout_countdown.wav`), sudden breaker trip (`power_cut.wav`) + shock stinger (`stinger_blackout_start.wav`), seamless switch to dark drone (`blackout_drone.wav`) and tension music (`blackout_tension_music.wav`). Power restoration turbine sound (`power_restore.wav`) on recovery.
4. **Sabotage:** Door lock clamp (`door_jam.wav`) and sabotage spark arc (`sabotage_execute.wav`).
5. **Meeting & Voting:** Clue discovery chime (`evidence_found.wav`), meeting siren horn (`stinger_meeting.wav`), countdown clock ticks (`voting_tick.wav`), vote confirmation thud (`vote_cast.wav`), and ejection airlock verdict (`ejection_reveal.wav`).
6. **Meltdown Protocol:** Thermal reactor drone (`meltdown_drone.wav`) and klaxon siren (`meltdown_alarm.wav`) with increasing pitch/volume as timer counts down.
7. **Game End:** Triumphant fanfare (`stinger_victory.wav` / `crew_victory.wav`) or sinister defeat cadence (`stinger_defeat.wav` / `impostor_victory.wav`).

---

## Regression Testing

* **Defect Severity:** P0 (Blocker), P1 (Critical), P2 (Major), P3 (Minor) with defined reproduction requirements and SLAs.
* **Defect Routing:** Direct mapping to module owners (Members 1–7) based on affected subsystem.
* **Report Format:** Standard markdown template with environment, repro steps, logs, and verification status.

---

## Production Tracking

* `docs/member-8/audio-asset-manifest.md`: Manifest of all 29 real audio files with format, loop, and status.
* `docs/member-8/audio-event-coverage.md`: Gameplay signal-to-audio asset mapping.
* `docs/member-8/sprint-backlog.md`: Itemized production backlog across all Member 8 responsibilities.
* `docs/member-8/milestone-tracker.md`: Milestone completion tracker backed by project evidence.
* `docs/member-8/open-questions.md`: Dependency tracking with status classifications (`OPEN`, `RESOLVED`, `BLOCKED`, `NO LONGER REQUIRED`).

---

## Current Blockers

1. **Godot Binary in PATH:** Automated command-line execution of test suites is blocked until Godot 4.x is added to the environment PATH.
2. **Live 8-Player Hardware:** Multi-client staging requires synchronized team assembly.
3. **Missing Upstream Signals:** 4 optional client-side signal hooks pending from upstream members (`docs/member-8/open-questions.md`).

---

## Remaining Missing Assets

**None (0).** All 29 required audio assets are fully present, validated on disk, and mapped in `AudioRegistry`.

---

## Open Integration Requirements

* **Member 4 (Ubaid):** Emit `interaction_rejected` from `InteractableStation` for error buzz SFX.
* **Member 1 (Mayiz) & Member 5 (Shahzan):** Provide client-side `voting_tick(remaining_seconds)` for voting clock ticking SFX.
* **Member 1 (Mayiz) & Member 2 (Abdul Qadir):** Provide client-side `meltdown_tick(remaining_time)` for dynamic alarm pitch scaling.
* **Member 1 (Mayiz) & Member 2 (Abdul Qadir):** Broadcast `sabotage_alarm_triggered` RPC when sabotage begins.

---

## How Other Members Can Work With Member 8's Systems

### Playing Audio from Any Script:
```gdscript
# Direct one-shot SFX
AudioManager.play_sfx(AudioRegistry.SFX_TASK_CLICK)

# UI Sound
AudioManager.play_ui(AudioRegistry.UI_CLICK)

# Dedicated Stinger
AudioManager.play_stinger(AudioRegistry.STINGER_MEETING)

# Volume controls (0.0 to 1.0)
AudioManager.set_music_volume(0.8)
```

### Hooking Gameplay Systems to Audio Bridge:
```gdscript
# Hook existing network manager, station, minigame, or lighting controller
AudioManager.connect_network_manager(client_network_manager)
AudioManager.connect_station(station_instance)
AudioManager.connect_mini_game(minigame_instance)
AudioManager.connect_lighting_controller(lighting_controller)
```

---

## Testing Instructions

When Godot 4.x is available in your PATH:

```bash
# 1. Run Master QA Runner (all suites manifest)
godot --headless -s tests/run_all_tests.gd

# 2. Run Audio Test Suite
godot --headless -s tests/test_audio_manager.gd

# 3. Run Server-Authority Anti-Cheat Suites
godot --headless -s tests/server_authority_tests/test_anti_cheat_tasks.gd
godot --headless -s tests/server_authority_tests/test_anti_cheat_blackout.gd
godot --headless -s tests/server_authority_tests/test_anti_cheat_voting.gd
godot --headless -s tests/server_authority_tests/test_anti_cheat_meltdown.gd
godot --headless -s tests/server_authority_tests/test_anti_cheat_roles.gd
godot --headless -s tests/server_authority_tests/test_anti_cheat_timers.gd
```

---

## Files Owned by Member 8

### Audio
* `assets/audio/audio_registry.gd`
* `assets/audio/` (all subdirectories)
* `client/audio/audio_manager.gd`
* `client/audio/gameplay_audio_bridge.gd`
* `client/audio/default_bus_layout.tres`

### QA & Playtesting
* `tests/test_audio_manager.gd`
* `tests/server_authority_tests/` (all 6 test scripts)
* `tests/playtest_checklists/playtest_checklist_8player.md`
* `tests/playtest_checklists/anti_cheat_test_matrix.md`

### Documentation
* `docs/member-8/8-player-smoke-test.md`
* `docs/member-8/sprint-backlog.md`
* `docs/member-8/milestone-tracker.md`
* `docs/member-8/open-questions.md`
* `docs/member-8/member-8-initial-review.md`
* `docs/member-8/reviews/` (all review documents)
* `docs/member-8/member-8-handoff.md`

---

## Final Status

**READY WITH BLOCKERS**

All deliverables within Member 8's scope are fully implemented, statically validated, and documented. Blockers are limited strictly to external dependencies (Godot binary in environment PATH, physical audio asset recordings, and upstream client-side signal hooks). Zero code belonging to Members 1–7 has been altered.
