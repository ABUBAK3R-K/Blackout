# BLACKOUT — Member 8 Audio Asset Manifest

**Owner:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Status:** Content-Complete (Real Uncompressed 16-bit 44.1kHz PCM Audio Assets)

---

## Audio Asset Registry & Validation Manifest

| Identifier | Context | File | Type | Loop | Status |
|---|---|---|---|---|---|
| `music_normal` | `NORMAL` | `assets/audio/music/normal/normal_gameplay_music.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `music_blackout` | `BLACKOUT` | `assets/audio/music/blackout/blackout_tension_music.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `music_meltdown` | `MELTDOWN` | `assets/audio/music/meltdown/meltdown_alarm.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `ambience_facility_hum` | `NORMAL` | `assets/audio/ambience/facility/facility_hum.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `ambience_blackout_drone` | `BLACKOUT` | `assets/audio/ambience/blackout/blackout_drone.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `ambience_meltdown_alarm` | `MELTDOWN` | `assets/audio/ambience/meltdown/meltdown_drone.wav` | WAV (PCM 16-bit) | Yes | **READY** |
| `sfx_blackout_trigger` | `BLACKOUT` | `assets/audio/sfx/blackout/blackout_trigger.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_blackout_countdown` | `BLACKOUT` | `assets/audio/sfx/blackout/blackout_countdown.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_power_cut` | `BLACKOUT` | `assets/audio/sfx/blackout/power_cut.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_power_restore` | `BLACKOUT` | `assets/audio/sfx/blackout/power_restore.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_task_click` | `TASK` | `assets/audio/sfx/tasks/task_click.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_task_success` | `TASK` | `assets/audio/sfx/tasks/task_success.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_task_error` | `TASK` | `assets/audio/sfx/tasks/task_error.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_task_progress` | `TASK` | `assets/audio/sfx/tasks/task_progress.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_door_jam` | `SABOTAGE` | `assets/audio/sfx/sabotage/door_jam.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_sabotage_execute` | `SABOTAGE` | `assets/audio/sfx/sabotage/sabotage_execute.wav` | WAV (PCM 16-bit) | No | **READY** |
| `sfx_evidence_found` | `MEETING` | `assets/audio/sfx/meeting/evidence_found.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_click` | `UI` | `assets/audio/sfx/ui/ui_click.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_hover` | `UI` | `assets/audio/sfx/ui/ui_hover.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_meeting_called` | `MEETING` | `assets/audio/ui/meeting_called.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_voting_tick` | `VOTING` | `assets/audio/sfx/voting/voting_tick.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_vote_cast` | `VOTING` | `assets/audio/sfx/voting/vote_cast.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_ejection_reveal` | `EJECTION` | `assets/audio/sfx/ejection/ejection_reveal.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_crew_victory` | `VICTORY` | `assets/audio/ui/crew_victory.wav` | WAV (PCM 16-bit) | No | **READY** |
| `ui_impostor_victory` | `DEFEAT` | `assets/audio/ui/impostor_victory.wav` | WAV (PCM 16-bit) | No | **READY** |
| `stinger_blackout_start` | `BLACKOUT` | `assets/audio/stingers/blackout_start/stinger_blackout_start.wav` | WAV (PCM 16-bit) | No | **READY** |
| `stinger_meeting` | `MEETING` | `assets/audio/stingers/meeting/stinger_meeting.wav` | WAV (PCM 16-bit) | No | **READY** |
| `stinger_victory` | `VICTORY` | `assets/audio/stingers/victory/stinger_victory.wav` | WAV (PCM 16-bit) | No | **READY** |
| `stinger_defeat` | `DEFEAT` | `assets/audio/stingers/defeat/stinger_defeat.wav` | WAV (PCM 16-bit) | No | **READY** |

---

## Summary Metrics

- **Total Audio Identifiers:** 29
- **Verified Real Audio Assets on Disk:** 29
- **Missing Assets:** 0
- **Format Standard:** 16-bit Signed PCM WAV, 44,100 Hz, zero clipping, normalized headroom.
- **Fallback Safety:** Centralized procedural waveform synthesis retained in `AudioManager` as backup safety gate.
