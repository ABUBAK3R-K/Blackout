# Member 5 — Shahzan — UI/UX Designer & Frontend Programmer · Fix Guide

**Branch:** `member-5/ui-frontend`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** C7 (menu/lobby), C8, I4 (UI), I7, I8, I10, F1 (UI), F8 (UI), F10 (UI), F11 (UI), Q7 (your tests)

Your UI stack is the **canonical** one (decision D3). It's also currently the most broken piece:
- the HUD doesn't compile (C8);
- the menu's Host button kills its own server (C7);
- the HUD is full of debug hotkeys that steal gameplay keys (I10);
- the Impostor wheel completes objectives from anywhere (I4);
- two screens load images from your local `.gemini` folder (I7).

Fix those first. Then wire every panel to real `ClientNetworkManager` signals, and take over the pieces of M3's UI that you don't have yet.

---

## 1. Your files (you may edit)
- `client/ui/menu/*`
- `client/ui/screens/*` (lobby, role reveal, victory/defeat, result)
- `client/ui/hud/*` (hud, task checklist, blackout banner, recovery tracker, meltdown HUD, impostor HUD)
- `client/ui/meeting/*`, `client/ui/voting/*`
- **Taken over from M3:** `client/ui/evidence_dossier_ui.gd` (+ `scenes/ui/evidence_dossier_ui.tscn` if you keep it), `client/objectives/objective_tracker.gd` (only if you keep it; your task checklist should replace it)
- **New:** `assets/ui/*` (the background images currently loaded from `.gemini`)
- Your tests: `tests/test_main_menu.gd`, `test_lobby_room_ui.gd`, `test_result_screen.gd`, `test_victory_defeat_screen.gd`, `test_evidence_dossier_ui.gd`, `tests/capture_lobby_screenshots.gd`

## 2. Not yours
- `shared/network_manager.gd`, `client/client_network_manager.gd`, `project.godot` → **M1**. Ask M1 to switch `run/main_scene` to `res://client/ui/menu/main_menu.tscn` once your menu works.
- `scenes/main.tscn` → **M3**. M3 mounts your `hud.tscn` at `Main/HUD`.
- `client/interactions/*` → **M4**. Station prompts are M4's; you do the HUD-level toasts.
- `client/audio/*` → **M8**

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| `DebugFlags` | M8 Wave 0 | 2 |
| `host_game` / `join_game` / `leave_game`, names in lobby dicts | M1 Steps 1, 9 | 3, 4 |
| New client signals (`timer_synced`, `chat_received`, `action_rejected`, `orion_instability_synced`, `emergency_system_disrupted`, `evidence_details_received`) | M1 Step 1 | 5–9 |
| Real chat/timer/rejection behaviour on the server | M1 Step 8 | 6, 9 |
| `player_roster` in the game-over result | M1 Step 10 | 7 |
| `Audio` autoload | M8 | 10 |

| Others need from you | Step |
|---|---|
| **A compiling `hud.tscn`** (M3 mounts it) | **1** |
| The parity checklist so M3 can delete their UI | 8 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 1 | 1 (today) | Fix the HUD compile error | C8 |
| 2 | 1 | Gate all debug hotkeys; free the gameplay keys | I10 |
| 3 | 1 | Main menu: real Host / Join with name, IP, port | C7, F8 |
| 4 | 1 | Lobby: names, ready, auto-start → change scene to the world | C7 |
| 5 | 2 | Wire the HUD panels to real signals; server timers; Impostor wheel read-only | I4, F10 |
| 6 | 2 | Meeting: networked chat, names/colours in vote grid | F1 |
| 7 | 2 | Role reveal, victory/result with roster; fix `.gemini` paths | I7, H3 (UI) |
| 8 | 2 | Evidence dossier (inspected evidence only) + parity checklist for M3 | I8, D7 |
| 9 | 2 | Rejection toasts | F11 |
| 10 | 3 | Settings: audio volumes, persisted | — |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my coding agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 5 (Shahzan), UI/UX Designer & Frontend Programmer. My branch is member-5/ui-frontend. My UI stack (client/ui/menu, screens, hud, meeting) is the canonical one for the game.

Before writing any code:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md (especially §6, §9, §10, §12), docs/fix-plan/member-5-ui-frontend.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-5/ui-frontend or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) which dependencies (M1 contract stubs + host/join API, M8 DebugFlags) exist on origin/main. Then stop and wait for me.

Rules for this whole session:
- Edit ONLY my files (see "Your files" in my guide). project.godot, network code, the world scene and station prompts belong to others. Write handoff notes instead.
- UI never decides game outcomes and never talks to the server object. It calls ClientNetworkManager request methods (contracts §9.1), and reacts to its signals (§9.2) and stored state (§9.3).
- Timers shown to players come from client.timer_synced / client.timers, never from local hardcoded durations.
- Every debug/preview hotkey must be gated by DebugFlags.hotkeys_enabled(). Never bind W A S D, arrows, E, F, Q, Esc, Enter to debug actions.
- No absolute file paths anywhere. Everything is res:// (assets) or user:// (runtime files).
- Chat and player names render as plain text: no BBCode parsing of user input.
- Run tests with: <GODOT> --headless --path . -s <suite.gd>
  Show the real [PASS]/[FAIL] lines and the exit code. Never claim a test passes unless you ran it in this session. A test with zero assertions is a failure.
- After each step: list the changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today citing the audit IDs. Do not commit unless I say so.
```

---

### Step 1 — Fix the HUD compile error (Wave 1, today) — C8
**Do:** two scripts declare `class_name MeltdownHUD`. Rename **yours** (`client/ui/hud/meltdown_hud.gd`) to `class_name MeltdownStatusPanel` and update any typed references in your files. M3's copy gets deleted later.
**Done when:** a headless import shows **no** `SCRIPT ERROR` lines, and `hud.tscn` loads in a test.

**Agent prompt**
```text
Do Step 1 (audit C8). client/ui/hud/meltdown_hud.gd and client/ui/meltdown_hud.gd (Member 3's, don't edit) both declare class_name MeltdownHUD, which makes client/ui/hud/hud.gd fail to compile. Rename the class_name in MY file client/ui/hud/meltdown_hud.gd to MeltdownStatusPanel and update every typed reference to it in my files (grep for MeltdownHUD under client/ui/hud, client/ui/meeting, client/ui/screens, client/ui/menu). Then run <GODOT> --headless --path . --import and show all SCRIPT ERROR lines (expect none from my files). Add a check to tests/test_victory_defeat_screen.gd or a new small test that load("res://client/ui/hud/hud.tscn").instantiate() succeeds and the HUD enters the tree. Run it.
```

---

### Step 2 — Gate every debug hotkey (Wave 1) — I10
**Do:** `hud.gd` (keys 1–0, B, E, G, I, M, N, R, T, V), `blackout_banner.gd` (B, R), `meltdown_hud.gd` (M), `impostor_hud.gd` (Tab/E/O/K) and any other key handler in your files:
- offline preview/cycling keys only when `DebugFlags.hotkeys_enabled()`;
- gameplay keys (E, Q, F…) are never consumed by the HUD;
- the Impostor wheel toggle moves to **Tab only**, and only for the Impostor;
- `_populate_offline_preview()` runs only in debug-hotkey mode;
- remove the big hotkey banner `print` from `hud.gd` `_ready()`.

**Agent prompt**
```text
Do Step 2 (audit I10; contracts §12). In every script under client/ui/ that I own, find all _input/_unhandled_input key handlers. Gate every preview/cycling/test hotkey with DebugFlags.hotkeys_enabled() (if shared/debug_flags.gd doesn't exist yet, stop and tell me). The HUD must never handle E, Q, F, W, A, S, D, arrows or Enter outside chat input. The impostor sabotage wheel opens with Tab only, only for the Impostor. Offline preview population (_populate_offline_preview and similar) runs only when DebugFlags.hotkeys_enabled(). Remove the hotkey banner print in hud.gd _ready. Show me a table of every key handler before/after. Run my UI suites.
```

---

### Step 3 — Main menu: real Host / Join (Wave 1) — C7, F8
**Do**
- Replace the fake lobby-code modals with:
  - **Host:** name + port (default 7777) → `NetworkManager.host_game(port, name)`.
  - **Join:** name + IP + port → `NetworkManager.join_game(ip, port, name)`.
- Show the host's LAN address(es) from `IP.get_local_addresses()` so friends know what to type.
- Show connection errors from `client.connection_failed`. Only change scene to the lobby after `client.player_assigned`.
- Remember the last name/IP in `user://settings.cfg`.
- Ask M1 to set `run/main_scene` to the menu.

**Agent prompt**
```text
Do Step 3 (audit C7, F8; contracts §6). Rework client/ui/menu/main_menu.gd (+ .tscn):
- Remove the fake lobby code flow (_generate_lobby_code, A7K2X defaults, "code" inputs).
- Host modal: Name (1-16 chars) + Port (default NetworkConfig.DEFAULT_PORT) -> NetworkManager.host_game(port, name); show "Players join at: <IPv4 LAN addresses from IP.get_local_addresses()>:<port>".
- Join modal: Name + Host IP + Port -> NetworkManager.join_game(ip, port, name).
- Show a "Connecting..." state; on ClientNetworkManager.connection_failed(reason) show the reason and stay on the menu; change scene to res://client/ui/screens/lobby_room.tscn only after client.player_assigned.
- Never call start_host()+connect_client() directly.
- Persist last name/ip/port in user://settings.cfg via ConfigFile.
If NetworkManager.host_game/join_game don't exist yet on origin/main, stop and tell me (Member 1 Step 9). Update tests/test_main_menu.gd so it has real assertions (modal visibility, validation of empty/too-long names, no call when invalid) and NO absolute paths (screenshots, if any, go to user://). Run it. Draft a handoff note to M1: set run/main_scene to res://client/ui/menu/main_menu.tscn.
```

---

### Step 4 — Lobby (Wave 1) — C7
**Do**
- Show 8 slots with `display_name`, colour (from `color_index`) and ready state, from `client.lobby_players_data`.
- The Ready toggle calls `set_ready`.
- **Remove** the Start button's `server.assign_roles()` call. The server auto-starts at 8/8 ready; show "Waiting for players (n/8 ready)".
- On `client.game_state_changed(ROLE_ASSIGNMENT)` or any later state → `change_scene_to_file("res://scenes/main.tscn")`.
- Leave → `NetworkManager.leave_game()` → menu.
- On return from a match (state LOBBY) the lobby must render correctly again.

**Agent prompt**
```text
Do Step 4 (audit C7; decision D6). In client/ui/screens/lobby_room.gd (+ .tscn): render up to 8 player rows from client.lobby_players_data using display_name, color_index (use Member 7's PlayerVisual colour table via a small colour lookup; don't instance sprites here) and is_ready; the Ready button calls NetworkManager.set_ready(!is_ready). Delete the Start Game button's call into net_mgr.server.assign_roles(): the server starts automatically at 8/8 ready, so show "Waiting for players (n/8 ready)". On client.game_state_changed to ROLE_ASSIGNMENT or later, change scene (deferred) to res://scenes/main.tscn. Leave -> NetworkManager.leave_game() then the main menu. Handle disconnected_from_server -> menu with the reason. Update tests/test_lobby_room_ui.gd (real assertions, no absolute paths, no .gemini). Run it.
```

---

### Step 5 — Wire the HUD to real signals (Wave 2) — I4, F10
**Do**
| Panel | Source |
|---|---|
| Task checklist | `client.assigned_tasks`, `task_list_received`, `task_completed_locally`. Impostor: prerequisite tasks shown exactly like Crew tasks |
| Impostor HUD | shown only if `assigned_role == IMPOSTOR`. BLACKOUT READY button ← `blackout_unlocked_for_impostor`, calls `request_activate_blackout()`. Objectives list ← `impostor_objective_list_received`/`_updated`, with the **room name** for each `location_id` |
| **Sabotage wheel** | **Read-only.** Delete `_on_sabotage_selected()` calling `request_complete_impostor_objective` (I4). Objectives are completed at stations (M4) |
| Blackout banner | `blackout_countdown_started`, `blackout_started`, `blackout_ended`, remaining time from `timer_synced(BLACKOUT…)` |
| Recovery tracker | `recovery_systems_initialized`, `recovery_system_updated` ("SYSTEMS REQUIRED: X/Y" + per-system ✓/✗) |
| Meltdown panel | `meltdown_started`, `emergency_system_completed`, `emergency_system_disrupted`, `orion_instability_synced`, `timer_synced(MELTDOWN)` |
| Investigation | a banner "INVESTIGATION — meeting in Ns" ← `timer_synced(INVESTIGATION)` |

**Agent prompt**
```text
Do Step 5 (audit I4, F10; contracts §2.3, §9). Wire every HUD panel under client/ui/hud to real ClientNetworkManager signals and state per the table in my guide Step 5. All countdowns must display client.timers / timer_synced values (interpolate locally between 1 Hz syncs); remove hardcoded durations like "40s". In impostor_hud.gd delete the code path that calls request_complete_impostor_objective from the wheel. The wheel becomes a read-only list of assigned objectives with room names (map location_id -> room display name via scenes/environment/facility_map.gd ROOM_DEFINITIONS, read-only) and completion ticks. The Impostor HUD must not exist/show for Crew. Apply state that arrived before the HUD loaded (read client vars in _ready). Tests with a fake ClientNetworkManager emitting each signal, asserting the panel text/visibility. Run them.
```

---

### Step 6 — Meeting screen: chat and votes (Wave 2) — F1
**Do**
- Chat input → `client.send_chat(text)` (max `chat.max_length`, Enter sends).
- Messages come **only** from `chat_received`: no local echo. Render them as plain text (`Label` or `RichTextLabel` with `bbcode_enabled = false`).
- Vote cards use display names and colours; eliminated players are greyed out and can't vote.
- `action_rejected` for `chat`/`cast_vote` shows inline.
- Discussion/voting timers come from `timer_synced`.

**Agent prompt**
```text
Do Step 6 (audit F1; contracts §8.8, §9). In client/ui/meeting/meeting_screen.gd: the chat input calls client.send_chat(text) (limit input to BalanceConfig "chat.max_length", Enter sends, input disabled when the local player is eliminated or outside MEETING/VOTING). Chat messages are added ONLY from client.chat_received(sender_peer_id, sender_name, text): no local echo. Render as plain text (no BBCode). Vote cards show get_display_name/get_color_index; eliminated players can't vote and are greyed. Show action_rejected messages for "chat" and "cast_vote" inline. Timers from timer_synced (DISCUSSION, VOTING). Tests with a fake client: no local echo; BBCode like [color=red]x[/color] displays literally; a rejected vote shows the message. Run them.
```

---

### Step 7 — Role reveal, end screens, asset paths (Wave 2) — I7, H3
**Do**
- Copy the two background images from your machine into `assets/ui/` (e.g. `role_bg_crew.png`, `role_bg_impostor.png`, `victory_bg_crew.png`, `victory_bg_impostor.jpg`). Replace every `C:/Users/shahz/...` path with `res://assets/ui/...`, including in your tests.
- Add `role_reveal.tscn` into the HUD. Show it once on `role_assigned`, private to the local player.
- Victory/result screens read `result_data.player_roster` (names + roles + who was ejected) and `orion_instability`.
- A "Return to Lobby" button → `client.request_return_to_lobby()`.

**Agent prompt**
```text
Do Step 7 (audit I7, H3 UI). 1) grep my files and my tests for "C:/Users" and ".gemini" and list them. I will copy the original images into assets/ui/; ask me for the filenames before editing. Then replace every absolute path with res://assets/ui/<file> (tests write any screenshots to user:// only). 2) Instance role_reveal.tscn inside hud.tscn; show it once when client.role_assigned fires (and if the role was already assigned when the HUD loaded), then hide. 3) victory_defeat_screen and result_screen must build the role recap from result_data["player_roster"] (display_name, role_name, is_eliminated) and show result_data["orion_instability"]. 4) The Return to Lobby button calls client.request_return_to_lobby(). Update test_victory_defeat_screen.gd and test_result_screen.gd so they have real assertions with a sample roster. Run them and a headless import (expect zero SCRIPT ERROR).
```

---

### Step 8 — Evidence dossier + parity checklist (Wave 2) — I8, D7
**Do**
- Take over M3's evidence dossier. It shows **only evidence the local player inspected** (`client.inspected_evidence`, `evidence_details_received`) and opens with **J**.
- Then fill in the parity checklist below. When every box is ticked, tell M3 to delete their UI (M3 Step 8).

**Parity checklist (M3 UI → your stack)**
- [ ] Meeting/voting: caller shown, discussion timer, vote grid, skip, has-voted markers, result (M3 `meeting_voting_ui.gd`)
- [ ] Meltdown: 3 system states, timer, alarm styling (M3 `meltdown_hud.gd`)
- [ ] Game over: winner, reason, role recap, return-to-lobby (M3 `game_over_ui.gd`)
- [ ] Evidence dossier (M3 `evidence_dossier_ui.gd`), now inspection-based
- [ ] Task list (M3 `objective_tracker.gd`) → your task checklist

**Agent prompt**
```text
Do Step 8 (audit I8; decision D7). Move ownership of client/ui/evidence_dossier_ui.gd into my stack (keep the path unless I tell you otherwise; add it to hud.tscn). Rework it to show ONLY entries in client.inspected_evidence, adding entries live on client.evidence_details_received; toggle with the J key (not Tab/E/Q). It must never read an evidence list broadcast (that RPC is being removed). Then compare, feature by feature, M3's client/ui/meeting_voting_ui.gd, client/ui/meltdown_hud.gd, client/ui/game_over_ui.gd and client/objectives/objective_tracker.gd against my HUD, and fill in the parity checklist in my guide Step 8 with evidence (file + function) for each item. Implement anything missing. Run test_evidence_dossier_ui.gd (update it for inspection-based behaviour) and my other suites.
```

---

### Step 9 — Rejection toasts (Wave 2) — F11
**Do:** one toast component on the HUD. It listens to `client.action_rejected(action, code, message)` and shows friendly text per code:

| Code | Message |
|---|---|
| `too_far` | "Move closer" |
| `too_fast` | "Hold on…" |
| `wrong_phase` | "Not available right now" |
| `cooldown` | "Recharging" |
| `disrupted` | "System locked" |
| `rate_limited` | "Slow down" |
| `disabled` | "Unavailable" |
| anything else | the server message |

At most 1 toast per action per second.

**Agent prompt**
```text
Do Step 9 (audit F11; contracts §3 reason codes). Add a toast component to hud.tscn that listens to client.action_rejected(action, reason_code, message) and shows the friendly text from the table in my guide Step 9 (fallback: the server message) for 2.5s, deduplicating the same action within 1s. Tests with a fake client for each code. Run them.
```

---

### Step 10 — Settings (Wave 3)
```text
Do Step 10. In the main menu Settings modal add Master/Music/SFX/Ambience/UI volume sliders that call /root/Audio set_master_volume/set_music_volume/set_sfx_volume/set_ambient_volume/set_ui_volume (only if /root/Audio exists) and persist to user://settings.cfg; apply saved values on startup. Add a checkbox "Fullscreen". Test that values persist across a reload of the ConfigFile. Run it.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main as a strict reviewer:
1) git diff origin/main...HEAD --stat. Flag any file outside my ownership list in docs/fix-plan/member-5-ui-frontend.md.
2) Search the diff and my files for: absolute paths ("C:/", ".gemini"), ungated hotkeys, handling of E/Q/F/WASD in UI, access to NetworkManager.server, request_complete_impostor_objective from UI, hardcoded countdown durations, BBCode enabled on chat/name labels, local chat echo.
3) Run a headless import (expect zero SCRIPT ERROR) and all my UI suites. Confirm none passes with zero assertions. Paste the results.
4) Draft the PR description (template in docs/fix-plan/README.md §5) with audit IDs, handoff notes (M1 main scene, M3 parity) and the PROJECT_STATUS.md §7 entry.
```
