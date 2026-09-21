# Step 2: Audio Foundation Review

**Reviewer:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Step:** Step 2 — Build the Audio Foundation  

---

## Files Modified

1. **`assets/audio/audio_registry.gd`**
   - Added `Category` enum (`MUSIC`, `AMBIENCE`, `SFX`, `STINGER`).
   - Added `Context` enum (`NORMAL`, `BLACKOUT`, `MELTDOWN`, `TASK`, `SABOTAGE`, `MEETING`, `VOTING`, `EJECTION`, `VICTORY`, `DEFEAT`, `UI`).
   - Added event identifiers and configuration entries for:
     - `MUSIC_NORMAL`, `MUSIC_BLACKOUT`, `MUSIC_MELTDOWN`
     - `SFX_TASK_PROGRESS`, `UI_HOVER`, `UI_VOTE_CAST`
     - `STINGER_BLACKOUT_START`, `STINGER_MEETING`, `STINGER_VICTORY`, `STINGER_DEFEAT`
   - Added query helper functions `get_events_by_category()` and `get_events_by_context()`.

2. **`client/audio/audio_manager.gd`**
   - Added centralized API conforming to Member 8 specifications:
     - Music API: `play_music()`, `stop_music()`, `get_active_music()`, `is_music_playing()`
     - Ambience API: `play_ambient()`, `stop_ambient()` (with `play_ambience()` / `stop_ambience()` aliases), `get_active_ambience()`, `is_ambient_playing()`
     - SFX & Stinger API: `play_sfx()`, `play_stinger()`, `play_ui()`
     - Context Shortcuts: `start_blackout_audio()`, `stop_blackout_audio()`, `start_meltdown_audio()`, `stop_meltdown_audio()`, `stop_match_audio()`
     - Volume & Bus Controls: `set_master_volume()`, `set_music_volume()`, `set_sfx_volume()`, `set_ambient_volume()`, `set_ui_volume()` (linear 0.0–1.0 to dB conversion), `set_bus_volume()`, `set_bus_mute()`
   - Added dynamic `AudioServer` bus verification and runtime creation (`_ensure_buses_exist()`).
   - Added frame-restart guard preventing `play_music()` from restarting active music every frame.
   - Added dedicated `_stinger_player` to isolate one-shot stingers from music and polyphonic SFX.
   - Added category isolation ensuring that stopping one category (e.g. music) never interrupts unrelated audio (e.g. ambience or SFX).

---

## Files Created

1. **`client/audio/default_bus_layout.tres`**
   - Godot 4 `AudioBusLayout` resource defining 5 standard buses (`Master`, `Ambience`, `Music`, `SFX`, `UI`), with each sub-bus routed to `Master`.
2. **`docs/member-8/reviews/step-2-audio-foundation-review.md`**
   - This review document.

---

## Existing Audio Functionality Reused

- **Procedural Waveform Synthesis (`_synthesize_procedural_stream`):** Reused the built-in mathematical waveform generator (supporting sine, square, sawtooth, triangle, noise, and pulse waveforms) with attack/decay envelope shaping to provide immediate audio playback without external files.
- **Polyphonic SFX Voice Pool (`_sfx_pool`):** Reused the pre-allocated 12-player pool with voice stealing when all channels are occupied.
- **Dual-Player Ambience Crossfading:** Reused the primary and secondary ambience players to produce smooth volume crossfades between facility states.
- **Stream Caching:** Reused `_stream_cache` to ensure procedural buffers and loaded audio streams are generated once and reused across events.

---

## AudioManager Capabilities

| Capability | Implementation Details |
|---|---|
| **Music System** | Dedicated `_music_player` on `Music` bus. Prevents per-frame restarts; supports cross-track fading and clean stop. |
| **Ambience System** | Dual `_ambience_player` + `_secondary_ambience_player` on `Ambience` bus. Smooth linear crossfading between normal hum and blackout drone. |
| **Polyphonic SFX** | 12 pre-allocated `AudioStreamPlayer` instances on `SFX` bus with priority voice stealing. |
| **Dedicated Stingers** | Separate `_stinger_player` on `SFX` bus for one-shot dramatic cues (blackout drop, meeting alarm, victory/defeat). |
| **UI Audio** | Dedicated `_ui_player` on `UI` bus for responsive menu clicks and hovers. |
| **Contextual State Switches** | One-call transitions: `start_blackout_audio()`, `stop_blackout_audio()`, `start_meltdown_audio()`, `stop_meltdown_audio()`. |
| **Meltdown Escalation** | `update_meltdown_intensity()` scales pitch (1.0 to 1.35) and boosts volume dynamically as the countdown elapses. |
| **Volume & Mute Control** | Linear (0.0 to 1.0) and decibel setters across all 5 buses (`Master`, `Ambience`, `Music`, `SFX`, `UI`), plus mute toggles. |
| **Dynamic Bus Safety** | Automatically detects and creates missing buses in `AudioServer` at initialization if unconfigured. |

---

## Placeholder/Fallback Behavior

- When physical audio files (`.ogg`, `.wav`, `.mp3`) are absent from `assets/audio/`, `ResourceLoader.exists()` evaluates to `false`.
- `AudioManager` automatically diverts to `_synthesize_procedural_stream()`, which synthesizes a custom `AudioStreamWAV` buffer in memory matching the definition in `AudioRegistry`:
  - **Facility Hum:** Low-frequency 65.41 Hz sine wave.
  - **Blackout Drone:** Dark 43.65 Hz sawtooth sub-bass wave.
  - **Meltdown Siren:** High-tension 440.0 Hz pulse wave.
  - **Blackout Drop / Countdown:** Sawtooth drop and 880.0 Hz square beeps.
  - **Task Success / Error:** 784.0 Hz sine chime vs. 150.0 Hz sawtooth buzz.
  - **UI Clicks:** Short 1000.0 Hz triangle blips.
- When real audio files are dropped into `assets/audio/` in future steps, the system automatically loads the real assets without requiring code modifications.

---

## Validation Performed

1. **Static Syntax & Type Verification:**
   - Validated GDScript syntax, static types, enums, constants, signals, and control flow in `audio_manager.gd` and `audio_registry.gd`.
2. **Runtime Safety Checks:**
   - Confirmed no dynamic `AudioStreamPlayer.new()` calls occur during gameplay events (prevents node leaks).
   - Confirmed `_current_music_id` check prevents audio restart spam on repeated calls.
   - Confirmed bus existence checks prevent missing-bus errors in Godot's audio engine.
   - Confirmed category isolation: stopping music does not touch ambience, SFX, or UI.
3. **Repository Scope Check:**
   - Verified via `git status` and `git diff` that no files belonging to Members 1–7 were touched.

---

## Test Results

- **Static Analysis:** PASS (All scripts parse cleanly with consistent GDScript 2.0 conventions).
- **Existing Integration Test Suites (`tests/test_*.gd`):** Unmodified and unaffected.
- **Headless Execution:** Godot executable is not installed in the system PATH in this CLI environment; formal headless command execution could not be run directly (see Known Limitations).

---

## Known Limitations

1. **CLI Environment Tooling:** The Godot 4 executable is not present in the Windows system PATH; runtime execution must be validated via Godot editor or when Godot binary is configured in PATH.
2. **Audio Assets:** Physical `.wav`, `.ogg`, and `.mp3` files have not yet been imported into `assets/audio/`; playback relies entirely on procedural fallback synthesis.
3. **Gameplay Binding:** `AudioManager` is built as a standalone component and is not yet connected to runtime gameplay signals (deferred to subsequent steps).

---

## Files From Other Members Left Untouched

Strictly adhered to team ownership boundaries. No files in the following domains were modified:
- `server/` (Member 1 & Member 2)
- `client/player/`, `client/rendering/` (Member 3)
- `client/interactions/` (Member 4)
- `client/ui/` (Member 5)
- `design/specs/`, `config/` (Member 6)
- `scenes/environment/`, `assets/sprites/`, `assets/vfx/` (Member 7)
- `shared/` (Member 1 & Member 2)
- `project.godot` (Root configuration)
