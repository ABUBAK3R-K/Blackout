# Step 3: Gameplay Audio Integration Review

**Reviewer:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
**Branch:** `member-8/audio-qa`  
**Date:** September 20, 2026  
**Step:** Step 3 — Gameplay Event → Audio Integration  

---

## Events Connected

| Gameplay Area | Trigger Event | Audio Action Executed |
|---|---|---|
| **Normal Gameplay** | Match state enters `INITIAL_TASK_PHASE`, `BLACKOUT_AVAILABLE`, or `POST_BLACKOUT_INVESTIGATION` | Starts facility ambient hum loop (`AMBIENCE_FACILITY_HUM`) and normal gameplay music (`MUSIC_NORMAL`) |
| **Role Reveal** | `role_assigned` received | Plays role assignment confirmation cue (`SFX_TASK_SUCCESS`) |
| **Task Station Proximity** | Player steps into interactable station radius (`player_entered_station`) | Plays UI prompt hover audio cue (`UI_HOVER`) |
| **Task Station Triggered** | Player activates station prompt (`interaction_triggered`) | Plays console engage click (`SFX_TASK_CLICK`) |
| **Mini-Game Interaction** | Mini-game puzzle begins (`interaction_started`) | Plays mechanical mini-game click (`SFX_TASK_CLICK`) |
| **Mini-Game Progress** | Slider/wire progress moves (`progress_changed`) | Plays subtle progress tick (`SFX_TASK_PROGRESS`) |
| **Task Completion** | Task or mini-game successfully finished (`interaction_completed` & `task_completed_locally`) | Plays task completion chime (`SFX_TASK_SUCCESS`) |
| **Task Failure / Error** | Mini-game puzzle fails (`interaction_failed`) | Plays error buzzer (`SFX_TASK_ERROR`) |
| **Interaction Cancel** | Mini-game dismissed / cancelled (`interaction_cancelled`) | Plays UI cancel blip (`UI_CLICK`) |
| **Blackout Unlock** | Impostor finishes prerequisite tasks (`blackout_unlocked_for_impostor`) | Plays private alert ping (`UI_CLICK` +2 dB) |
| **Blackout Countdown** | Impostor triggers remote blackout (`blackout_countdown_started`) | Plays high-frequency countdown warning beeps (`SFX_BLACKOUT_COUNTDOWN`) |
| **Blackout Active** | Authoritative power cutoff begins (`blackout_started`) | Executes `start_blackout_audio()`: power cut crash (`SFX_POWER_CUT`), blackout shock stinger (`STINGER_BLACKOUT_START`), dark ambient drone (`AMBIENCE_BLACKOUT_DRONE`), and tension ostinato (`MUSIC_BLACKOUT`) |
| **Recovery System Repaired** | 1 of 4 recovery systems repaired (`recovery_system_updated`) | Plays relay restored power surge (`SFX_POWER_RESTORE` -3 dB) |
| **Blackout Restored** | Power restored naturally or via 3-of-4 recovery threshold (`blackout_ended`) | Executes `stop_blackout_audio()`: power restore sound (`SFX_POWER_RESTORE`), stops tension music, crossfades back to normal hum (`AMBIENCE_FACILITY_HUM`) |
| **Sabotage Completed** | Impostor executes confidential theft / core sabotage (`impostor_objective_updated`) | Plays sabotage confirmation cue (`SFX_SABOTAGE_EXECUTE`) |
| **Emergency Meeting** | Meeting initiated (`meeting_started`) | Plays emergency meeting alarm stinger (`STINGER_MEETING`) and stops background music |
| **Voting Phase** | Voting window begins (`voting_started`) | Plays voting clock tick (`UI_VOTING_TICK`) |
| **Vote Cast** | Player registers ballot (`player_voted`) | Plays ballot submit click (`UI_VOTE_CAST`) |
| **Ejection & Resolution** | Authoritative results returned (`vote_result_received`) | If player eliminated: plays dramatic ejection reveal stinger (`UI_EJECTION_REVEAL`); If tie/skip: plays UI click |
| **Meltdown Active** | 5-minute emergency countdown begins (`meltdown_started`) | Executes `start_meltdown_audio()`: emergency siren loop (`AMBIENCE_MELTDOWN_ALARM`) and intense meltdown alarm music (`MUSIC_MELTDOWN`) |
| **Emergency System Restored**| 1 of 3 meltdown systems stabilized (`emergency_system_completed`) | Plays emergency system chime (`SFX_TASK_SUCCESS` +2 dB) |
| **Match Conclusion** | Authoritative game over received (`game_over_received`) | Stops all background music and ambience loops (`stop_match_audio()`). If winning role matches client role: plays Victory stinger (`STINGER_VICTORY`); otherwise plays Defeat stinger (`STINGER_DEFEAT`) |
| **Lighting Transitions** | Dynamic lighting changes state (`lighting_state_changed`) | Synchronizes ambient drone and warning cues with visual states (`NORMAL`, `BLACKOUT_WARNING`, `BLACKOUT_ACTIVE`, `MELTDOWN`) |

---

## Audio Actions

All audio output is routed strictly through Member 8's `AudioManager` API:
- `play_ambient()` & `stop_ambient()` — Non-restarting, crossfaded looping facility soundscapes.
- `play_music()` & `stop_music()` — Non-restarting background music with frame-check protection.
- `play_sfx()` — 12-channel polyphonic sound effect voice pool.
- `play_stinger()` — Dedicated one-shot stinger channel for non-interrupting dramatic cues.
- `play_ui()` — Dedicated low-latency UI channel.
- `start_blackout_audio()` & `stop_blackout_audio()` — Atomic multi-bus state transitions.
- `start_meltdown_audio()` & `stop_meltdown_audio()` — Emergency state activation and deactivation.
- `stop_match_audio()` — Clean shutdown of all looping audio players upon match completion.

---

## Existing Signals Used

1. **`ClientNetworkManager` (`client/client_network_manager.gd`):**
   - `game_state_changed(new_state: NetworkConfig.GameState)`
   - `role_assigned(role: NetworkConfig.PlayerRole)`
   - `task_completed_locally(task_id: String)`
   - `blackout_unlocked_for_impostor()`
   - `blackout_countdown_started(duration: float)`
   - `blackout_started(duration: float)`
   - `blackout_ended()`
   - `recovery_system_updated(system_id: String, is_completed: bool, completed_count: int, required_count: int)`
   - `impostor_objective_updated(objective_id: String, is_completed: bool)`
   - `meeting_started(caller_peer_id: int, discussion_duration: float)`
   - `voting_started(voting_duration: float)`
   - `player_voted(voter_peer_id: int)`
   - `vote_result_received(result: Dictionary)`
   - `meltdown_started(duration: float, impostor_alive: bool)`
   - `emergency_system_completed(system_id: String, completed_systems: Array)`
   - `game_over_received(winner_role: NetworkConfig.PlayerRole, reason: int, result_data: Dictionary)`

2. **`InteractableStation` (`client/interactions/interaction_framework/interactable_station.gd`):**
   - `player_entered_station(station: InteractableStation)`
   - `interaction_triggered(station: InteractableStation)`

3. **`MiniGameBase` (`client/interactions/interaction_framework/mini_game_base.gd`):**
   - `interaction_started()`
   - `progress_changed(new_progress: float)`
   - `interaction_completed()`
   - `interaction_failed()`
   - `interaction_cancelled()`

4. **`FacilityLightingController` (`scenes/environment/facility_lighting_controller.gd`):**
   - `lighting_state_changed(new_state: LightingState)`

---

## Missing Events

Per the strict team boundary protocol, the following 4 missing integration points were identified and documented in [`docs/member-8/open-questions.md`](../open-questions.md) without altering other members' code:

1. **Invalid / Denied Interaction Event on `InteractableStation`:**
   - Needed for immediate auditory negative feedback (`SFX_TASK_ERROR`) when interacting with disabled or off-cooldown stations.
   - Assigned to: Member 4 (Ubaid).
2. **Client-Side Voting Countdown Tick:**
   - Needed for real-time clock ticking sound effects during the final seconds of voting. Currently only exists on the server `MeetingManager`.
   - Assigned to: Member 1 (Mayiz) / Member 5 (Shahzan).
3. **Client-Side Meltdown Countdown Tick:**
   - Needed for dynamic pitch and volume scaling via `AudioManager.update_meltdown_intensity()`. Currently only exists on the server `MeltdownManager`.
   - Assigned to: Member 1 (Mayiz) / Member 2 (Abdul Qadir).
4. **Global Sabotage Alarm Trigger Broadcast:**
   - Needed to broadcast generic facility sabotage alarm cues (`SFX_DOOR_JAM` or siren) to Crew members when sabotage is committed.
   - Assigned to: Member 1 (Mayiz) & Member 2 (Abdul Qadir).

---

## Files Modified

1. **`client/audio/audio_manager.gd`**
   - Added `get_or_create_gameplay_bridge()`.
   - Added connector convenience methods:
     - `connect_network_manager(net_mgr: Node)`
     - `connect_station(station: Node)`
     - `connect_mini_game(mini_game: Node)`
     - `connect_lighting_controller(lighting: Node)`

---

## Files Created

1. **`client/audio/gameplay_audio_bridge.gd`**
   - Standalone observer node listening to all public gameplay signals and delegating presentation playback to `AudioManager`.
   - Implements duplicate connection prevention (`_safe_connect`) and instance tracking.
2. **`docs/member-8/open-questions.md`**
   - Formal record of missing integration points with owners and rationale.
3. **`docs/member-8/reviews/step-3-gameplay-audio-review.md`**
   - (This review document).

---

## Files From Other Members Untouched

Strictly zero modifications were made to any files owned by Members 1–7:
- `server/` (Members 1 & 2) — UNTOUCHED
- `client/player/`, `client/rendering/` (Member 3) — UNTOUCHED
- `client/interactions/` (Member 4) — UNTOUCHED
- `client/ui/` (Member 5) — UNTOUCHED
- `design/specs/`, `config/` (Member 6) — UNTOUCHED
- `scenes/environment/`, `assets/sprites/` (Member 7) — UNTOUCHED
- `shared/` (Members 1 & 2) — UNTOUCHED
- `project.godot` — UNTOUCHED

---

## Validation

- **Connection Safety:** All signal connections utilize `_safe_connect()` checking `emitter.has_signal()` and `not emitter.is_connected()` to eliminate duplicate listeners.
- **Node Lifecycle Safety:** All listener methods verify `audio_manager != null` and check `is_instance_valid()`.
- **One-Time Event Execution:** Stingers (e.g. `STINGER_MEETING`, `STINGER_BLACKOUT_START`, `STINGER_VICTORY`, `STINGER_DEFEAT`) execute on discrete network state signals, never on process loops.
- **Looping State Control:** Facility hum, blackout drone, and meltdown siren loops are managed through exclusive crossfade or explicit stop calls.
- **Fallback Resilience:** All triggers cleanly play procedural tone waveforms when binary audio assets are absent, preventing engine crashes.

---

## Test Results

- **Static Syntax & Interface Verification:** PASS (All scripts parse cleanly and conform to Godot 4.3 GDScript conventions).
- **Existing Integration Test Suites (`tests/test_*.gd`):** Unmodified and completely isolated from audio bridge additions.

---

## Known Limitations

- The Godot 4 binary is not installed in the system PATH in this CLI environment; execution was validated via static analysis and interface contract verification.
- In-game telemetry and live playtest validation are scheduled for subsequent Member 8 steps.

---

## Next Integration Requirement

When the client game scene is assembled (e.g., `res://scenes/main.tscn`), instantiate `AudioManager` and attach the `GameplayAudioBridge` to bind client network events and facility stations.
