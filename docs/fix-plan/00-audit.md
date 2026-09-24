# BLACKOUT — Repository Audit

**Baseline:** `main @ 379ed70` (2026-09-25) · **Method:** read every server/shared/client module against `design.md` + `PRD.md`; ran a headless Godot 4.3 import and all 55 test suites.
Line numbers are **as of `379ed70`** and will drift once fixes start. Search by function name if a line has moved.

Every finding has an ID. Cite IDs in commits and PRs (`fix(roles): randomise impostor [audit C1]`).

---

## 0. Test reality check

| Result | Suites |
|---|---|
| Pass with real assertions | 45 / 55 (including all 10 core backend suites listed in `CLAUDE.md`) |
| Fail | `test_audio_manager` (11 failures, 190 runtime errors); `test_anti_cheat_roles` (1 failure) |
| **Do not compile — have never run** | `test_anti_cheat_blackout`, `_meltdown`, `_tasks`, `_timers`, `_voting`. They call manager functions with outdated arguments, e.g. `complete_task(peer, id)` and `cast_vote(v, t)`. |
| Print "ALL PASSED" with **0 checks** | `test_main_menu`, `test_result_screen`, `test_victory_defeat_screen` (the last two also hit a compile error) |
| `tests/run_all_tests.gd` | **Runs nothing.** It prints a manifest, adds up hardcoded `target_tests` counts to get "241", and exits 0. |
| `tests/test_master_e2e_match_loop.gd` | **Not end-to-end.** No clients and no network. It injects fake players into `connected_players`, sets `current_game_state` directly, calls private `_start_voting_phase` / `_resolve_meeting_and_voting`, and starts blackout through the bypass in C2. |

---

## 1. Critical — the game is broken or a hard design rule is violated

| ID | Finding | Location | Owner |
|---|---|---|---|
| **C1** | **The first player to connect is always the Impostor.** `chosen_index` defaults to 0 when no index is passed. Breaks FR-2. The tests only count roles, so they miss it. | `shared/role_manager.gd:34` | M1 |
| **C2** | **Blackout gate bypass.** `rpc_request_sabotage(POWER_BLACKOUT)` only checks the role and that the round is PLAYING, then calls `blackout_manager._start_blackout()` directly.<br>• The Impostor can black out at spawn: breaks design rules #1, #2 and FR-8.<br>• Repeatable: breaks FR-11. `cooldown_duration` is never checked.<br>• Works during MEETING/VOTING/MELTDOWN, because the round stays PLAYING.<br>The client binds this to the **Q** key. The correct path (`process_blackout_activation_request`, 3-2-1 countdown) is only reachable from the Impostor HUD, which does not compile (C8). | `server/server_network_manager.gd:446-492` (`:483`), `shared/sabotage_manager.gd:37,203-221`, `client/player/player_controller.gd:126` | M1 (server), M3 (client) |
| **C3** | **Meltdown can be reset.** A body report is allowed during MELTDOWN. It starts a meeting, `_on_meeting_completed` always transitions to MELTDOWN again, and `start_meltdown()` resets the 300s timer and clears completed systems. Meltdown and blackout timers also keep ticking during meetings. | `server/meeting_manager.gd:59`, `server/server_network_manager.gd:1003,1057`, `server/meltdown_manager.gd:229-241` | M1 (transitions), M2 (safe to call twice) |
| **C4** | **Blackout can be skipped.** A body report during INITIAL_TASK_PHASE leads to a meeting and then straight to MELTDOWN. If blackout ends during a meeting, `_on_blackout_ended` flips the state to POST_BLACKOUT_INVESTIGATION mid-vote (no guard). | `server/server_network_manager.gd:1026-1033`, `server/meeting_manager.gd:230-240` | M1 |
| **C5** | **The match dead-ends after blackout.** Nothing in the game world calls `call_meeting` (only body reports trigger meetings), and investigation has no timeout. | `scenes/main.gd`, `server/meeting_manager.gd` | M2 (timer), M1 (wiring), M4 (button) |
| **C6** | **BLACKOUT_AVAILABLE is broadcast to all clients.** Design §3.3 says Crew must see no change. Also, the client refuses Crew task completion outside INITIAL_TASK_PHASE even though the server allows it, so Crew are silently blocked once the Impostor unlocks blackout. | `server/server_network_manager.gd:425,1059-1061`, `client/client_network_manager.gd:225` | M1 |
| **C7** | **There is no playable path.**<br>• `run/main_scene` is a single-player sandbox that never starts or joins a server.<br>• The menu's Host button calls `start_host()` then `connect_client()`, and `connect_client()` calls `stop_network()`, which kills the server it just started.<br>• Lobby codes are fake and Join is hardcoded to `127.0.0.1`.<br>• The lobby opens `hud.tscn` (UI only), never the world. | `project.godot:16`, `client/ui/menu/main_menu.gd:158-178`, `shared/network_manager.gd:45-47`, `client/ui/screens/lobby_room.gd:478-491` | M1 (network API), M5 (menu/lobby), M3 (world) |
| **C8** | **Member 5's whole HUD fails to compile.** Two scripts declare `class_name MeltdownHUD`, so `hud.gd` cannot load. That takes down the task checklist, blackout banner, recovery tracker, Impostor HUD (BLACKOUT READY button), meeting screen, vote tally, ejection reveal and result screens. | `client/ui/meltdown_hud.gd:1`, `client/ui/hud/meltdown_hud.gd:1` | M5 |
| **C9** | **Any player can turn their own blackout off.** `enable_debug_key = true` by default, so pressing **B** toggles local lighting. | `client/environment/blackout_lighting_manager.gd:28,44-51` | M3 |

## 2. High — server logic and authority

| ID | Finding | Location | Owner |
|---|---|---|---|
| **H1** | **The kill system contradicts the spec.** README says "no instant kills". Kills are allowed in INITIAL_TASK_PHASE. It adds the `CREW_ELIMINATED` win (not in FR-41). See decision D1. | `server/server_network_manager.gd:774-960` | M1 |
| **H2** | **Kill/report range can be bypassed.** The distance check is skipped when either position is `Vector2.ZERO`. Positions are client-reported with no speed check, so a player can teleport. | `server/server_network_manager.gd:837,922`, `shared/network_manager.gd:511-515` | M1 |
| **H3** | **The end-of-match roster is always empty.** `assemble_match_summary()` is called without `connected_players`, so the final role reveal (FR-42) never happens. | `server/meltdown_manager.gd:195` | M1 (build roster in hub) |
| **H4** | **`stop_server()` leaves state behind.** It doesn't clear `meltdown_manager`, `active_corpses`, `player_positions` or `impostor_last_kill_time`. | `server/server_network_manager.gd:205-246` | M1 |
| **H5** | **Two competing state machines.** `RoundManager` and `GameState` both drive transitions. ROLE_ASSIGNMENT→INITIAL_TASK_PHASE is broadcast twice (`:380` and `:536`). The round path calls `assign_roles(true)`, which skips the 8-player check. | `server/server_network_manager.gd:301-320,522-550`, `shared/round_manager.gd` | M1 |
| **H6** | **No disconnect policy (NFR-4).** An Impostor disconnect leaves the match running with no Impostor. Disconnected voters' votes still count, so `have_all_active_voted` can resolve early. | `server/server_network_manager.gd:1107-1154`, `server/voting_manager.gd:88-94,171` | M1 + M2 |
| **H7** | **Managers call each other's private methods.** `_resolve_meeting_and_voting`, `_trigger_game_over` and `_start_blackout` are called from outside their class. | `server/server_network_manager.gd:483,749,959` | M1 + M2 |
| **H8** | **`config/game_balance_config.json` is never loaded (NFR-5).** Values are hardcoded constants. `PROJECT_STATUS.md` says blackout is 90s; the code uses 60s. | `shared/*_config.gd`, `config/game_balance_config.json` | M2 (loader), M6 (values) |
| **H9** | **Evidence is auto-broadcast to everyone when blackout ends.** Design §7 requires discovery through play. | `server/server_network_manager.gd:1040-1046` | M2 + M1 |
| **H10** | **The meeting cooldowns / anti-spam in `PROJECT_STATUS.md` don't exist.** | `server/meeting_manager.gd` | M2 |

## 3. Integration — modules exist but aren't connected (or are connected wrongly)

| ID | Finding | Location | Owner |
|---|---|---|---|
| **I1** | **Member 4's 22 mini-games are not used in the world.** World stations are "press E three times", and their completion state is **local to each client**. | `client/objectives/objective_interactable.gd:224-260`, `scenes/objects/*_station.tscn` | M4 + M3 |
| **I2** | **Crew-task stations send the wrong ID.** `InteractableStation` passes `station_id` as the task ID, but the server expects the instance ID `task_<type>_p<peer>_<n>`, so every completion would be rejected. | `client/interactions/interaction_framework/interactable_station.gd:82` | M4 |
| **I3** | **Remote players trigger your station prompts.** `InteractableStation` reacts to any body whose name contains "player", including remote puppets. | `interactable_station.gd:92,100` | M4 |
| **I4** | **The Impostor HUD's sabotage wheel completes objectives from anywhere.** It calls `request_complete_impostor_objective` with no station or mini-game, and the server has no location check. Breaks FR-23. | `client/ui/hud/impostor_hud.gd:388-393` | M5 (UI), M1/M2 (server check) |
| **I5** | **Member 7's work isn't used anywhere:** the 9-room art map, `PlayerVisual` 8-colour sprites, `FacilityLightingController`, `StationProp`, `EvidenceMarker` and the meltdown VFX overlay. | `scenes/environment/*`, `scenes/characters/*`, `scenes/vfx/*` | M7 + M3 |
| **I6** | **Audio isn't in the game.** `AudioManager` is not an autoload and not in any game scene (only `audio_test_lab`). Its `class_name AudioManager` would clash with an autoload of the same name. | `client/audio/audio_manager.gd:1`, `project.godot` | M8 |
| **I7** | **The role reveal screen is unused, and it plus the victory screen load images from a teammate's machine** (`C:/Users/shahz/.gemini/antigravity-ide/...`). | `client/ui/screens/role_reveal.gd:26-27`, `victory_defeat_screen.gd:25-26`, 4 test files | M5 (+M8 for tests) |
| **I8** | **Duplicate UI stacks.** M3's `client/ui/{meeting_voting_ui,meltdown_hud,game_over_ui,evidence_dossier_ui}.gd` + `client/objectives/objective_tracker.gd` duplicate M5's `client/ui/{hud,meeting,screens}/`. | `client/ui/*.gd` | M5 + M3 |
| **I9** | **Duplicate maps.** `scenes/map/facility_map.tscn` (M3, functional, placeholder shapes) vs `scenes/environment/facility_map.tscn` (M7, art). | `scenes/map/`, `scenes/environment/` | M7 + M3 |
| **I10** | **Debug hotkeys ship in the production HUD** and clash with gameplay keys (E interact, B, K, Q, M…). | `client/ui/hud/hud.gd:230-280`, `blackout_banner.gd:67-69`, `hud/meltdown_hud.gd:88`, `impostor_hud.gd:101-109` | M5 |
| **I11** | **`main.gd` compares a peer ID with a slot ID** to decide whether the local player was eliminated. | `scenes/main.gd:191,199` | M3 |

## 4. Missing MVP features (vs PRD)

| ID | Missing | PRD | Owner |
|---|---|---|---|
| **F1** | Meeting chat: no chat RPC exists; `meeting_screen.gd` chat is local only | FR-31 | M1 (RPC), M5 (UI) |
| **F2** | The 4 recovery stations are not in the world, so blackout can only end by timer | FR-19–21 | M7 (placement), M4 (behaviour) |
| **F3** | The 5 Impostor objective stations are not in the world, so there's no file theft and no evidence | FR-22–23 | M7, M4 |
| **F4** | ORION instability value | FR-16, FR-24 | M2 |
| **F5** | Impostor interference during Meltdown | FR-37 | M2, M4 |
| **F6** | Doors jam during blackout (server-driven) | FR-14 | M2, M1, M3 |
| **F7** | Security cameras (unavailable in blackout) | FR-13 | M3 (P2) or M6 descopes |
| **F8** | Player names: everyone shows as "Player N" | — | M1, M5 |
| **F9** | Fake repair / evidence manipulation (optional in the PRD) | FR-25 | M6 decides; M2 |
| **F10** | Server timer sync: clients only receive a start duration | — | M1, M5 |
| **F11** | Rejection feedback: the server silently drops invalid requests, so the UI can't explain "too far" or "wrong phase" | — | M1, M5 |

## 5. QA integrity

| ID | Finding | Owner |
|---|---|---|
| **Q1** | `tests/run_all_tests.gd` runs nothing (see §0) | M8 |
| **Q2** | 5 anti-cheat suites don't compile, and they call managers directly instead of going through the server/RPC boundary | M8 |
| **Q3** | `test_master_e2e_match_loop.gd` is not end-to-end (see §0) | M8 |
| **Q4** | Suites print "ALL PASSED" with zero assertions | M8 (harness), suite owners |
| **Q5** | Nothing tests randomness, the blackout gate, Meltdown reset, info leaks, or proximity/duration checks | M8 |
| **Q6** | `test_audio_manager` calls `AudioManager` before `_ready()` has run: 11 failures, 190 runtime errors | M8 |
| **Q7** | Tests write screenshots to a teammate's absolute path | M8 + M5 |
| **Q8** | `test_anti_cheat_roles` TEST 5 expects `"Unknown"`, but `get_role_name()` returns `"NONE"` | M8 |

## 6. Repository hygiene

| ID | Finding | Owner |
|---|---|---|
| **R1** | Mixed engine versions: `project.godot` says 4.3, but 55 `.uid` files and the `.import` keys come from 4.4+. Opening in 4.3 rewrites 59 files. | M8 (+ all) |
| **R2** | 26 of 56 audio files are duplicated (flat copies in `assets/audio/*/` next to the subfolder copies that `audio_registry.gd` actually references) | M8 |
| **R3** | `design (1).md` and `PRD (1).md` are identical copies. README links point to `ABUBAK3R-K/Blackout` (the repo is `Suspect`). README's module layout doesn't exist. `documentation/README.md` links to lowercase `prd.md`. | M6 |
| **R4** | `PROJECT_STATUS.md` claims are unverified or false: "241 tests passed", "90s blackout", "per-player meeting cooldowns", and files that don't exist (`client/rendering/directional_vision.gd`, `player_identity_visuals.gd`, `multi_step_objective.gd`). It also has two §5 headings. | M6 + M8 |
| **R5** | 9 stale branches (`develop`, `feature/ai-gamemaster`, `feature/ml-suspicion`, `feature/nlp`, …), all fully merged | M8 (with team OK) |
| **R6** | `scenes/objects/test_terminal.tscn` is placed in the production map | M3 |
| **R7** | No `.gitattributes`, so every checkout shows LF/CRLF warnings | M8 |

---

## 7. Findings by owner (quick lookup)

| Member | IDs |
|---|---|
| **M1 Mayiz** | C1, C2 (server), C3 (transitions), C4, C5 (wiring), C6, C7 (network API), H1, H2, H3, H4, H5, H6, H7, I4 (server check), F1, F6 (plumbing), F8, F10, F11 |
| **M2 Abdul Qadir** | C3 (Meltdown safe to call twice), C5 (investigation timer), H6 (voting), H7, H8, H9, H10, F4, F5, F6, F9 |
| **M3 Aaliya** | C2 (client), C7 (world), C9, I1 (retire old stations), I5, I8, I9, I11, F6 (client), F7, R6 |
| **M4 Ubaid** | C5 (meeting button), I1, I2, I3, F2, F3, F5 (client) |
| **M5 Shahzan** | C7 (menu/lobby), C8, I4 (UI), I7, I8, I10, F1 (UI), F8 (UI), F10 (UI), F11 (UI) |
| **M6 Abubaker** | D1–D12 ratification, H8 (values), F7/F9 scope, R3, R4 + station registry content, spec reconciliation |
| **M7 Fatima** | I5, I9, F2/F3 (placement) + doors, anchors, lighting/VFX binding |
| **M8 Sahil** | Q1–Q8, I6, R1, R2, R4 (with M6), R5, R7 |
