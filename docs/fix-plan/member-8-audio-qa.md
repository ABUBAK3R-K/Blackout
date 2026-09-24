# Member 8 — Sahil — Audio Designer & QA / Production Lead · Fix Guide

**Branch:** `member-8/audio-qa`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** Q1–Q8, I6, R1, R2, R4 (with M6), R5, R7

This recovery depends on tests that tell the truth. Right now:
- the master runner executes nothing (Q1);
- 5 anti-cheat suites don't compile (Q2);
- the "e2e" test fakes its state (Q3);
- three suites pass with zero checks (Q4).

In Wave 0 you build the test infrastructure everyone else relies on. Then you encode the design rules as tests, build the real end-to-end match test, and get audio into the actual game.

---

## 1. Your files (you may edit)
- **Test infrastructure:**
  - `tests/run_all_tests.gd`
  - **new** `tests/test_harness.gd`
  - `tests/server_authority_tests/*`
  - `tests/playtest_checklists/*`
- **New tests:** `tests/test_e2e_full_match.gd`, `tests/test_map_registry_placement.gd`, `tests/server_authority_tests/test_design_rules.gd`
- **Audio:**
  - `client/audio/*`, `assets/audio/**`
  - `client/environment/interaction_audio.gd`, `client/player/footstep_audio.gd` (with M3)
  - `tests/test_audio_manager.gd`, `test_footstep_audio.gd`, `test_interaction_audio.gd`
  - `scenes/audio_test_lab.*`, `audio_test_lab.html` (move it to `tools/` or delete it)
- **Tooling and repo:**
  - `tools/*.py`, **new** `tools/run_tests.ps1` / `tools/run_tests.sh`
  - **new** `shared/debug_flags.gd`
  - **new** `.gitattributes`
  - **new** `.github/workflows/tests.yml`
- **Docs:** `docs/member-8/*`; the "Commands" section of `CLAUDE.md` (announce the change in chat)
- **Obsolete tests** you may delete, after the owner OKs it in the PR: `test_master_e2e_match_loop.gd`, `test_sabotage_system.gd`, `test_round_loop_foundation.gd`, plus the ones M3 lists in their Step 8

## 2. Not yours
- **Other members' paired suites.** They fix those themselves; you provide the harness and tell them what's broken.
- `project.godot` → **M1**. Ask M1 to add the `Audio` autoload.

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| Contract stubs | M1 Step 1 | 5, 10 |
| Registry | M6 Wave 0 | 9 |
| Map anchors | M7 Step 2 | 9 |
| The server features, for the e2e test to go green | M1/M2 Waves 1–2 | 10 |

| Others need from you | Step |
|---|---|
| **Pinned engine + real runner + harness + DebugFlags** (everyone) | **0–3** |
| Design-rule tests (M1/M2 use them as acceptance) | 5 |

## 4. Step overview
| Step | Wave | What | Audit IDs |
|---|---|---|---|
| 0 | 0 | Pin Godot 4.4.1, one reimport commit, `.gitattributes`, update the CLAUDE.md commands | R1, R7 |
| 1 | 0 | `shared/debug_flags.gd` | I10 (enabler) |
| 2 | 0 | `tests/test_harness.gd`: zero assertions = fail | Q4 |
| 3 | 0 | A real `run_all_tests.gd` (+ `KNOWN_FAILURES` list) | Q1 |
| 4 | 1 | Fix the 5 anti-cheat suites + the roles TEST 5, going through the RPC boundary | Q2, Q8 |
| 5 | 1 | Design-rule regression suite | Q5 |
| 6 | 1 | A runner lint: no absolute paths, no `.gemini` | Q7 |
| 7 | 1 | Audio into the game: `Audio` autoload, lazy init, fix its test | I6, Q6 |
| 8 | 1 | Remove the duplicate audio files | R2 |
| 9 | 2 | Registry ↔ map placement test | contracts §4 |
| 10 | 3 | Real 1-server + 8-client end-to-end test (both endings), replacing the fake one | Q3 |
| 11 | 3 | CI on every PR | Q1 |
| 12 | 3 | Stale branch cleanup (team OK required) | R5 |
| 13 | 4 | 8-player playtest operations + match logs for M6 | — |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative multiplayer). The repo root is the current directory.
I am Member 8 (Sahil), Audio Designer & QA / Production Lead. My branch is member-8/audio-qa. I own the test infrastructure (tests/run_all_tests.gd, tests/test_harness.gd, tests/server_authority_tests/), CI, and audio (client/audio, assets/audio).

Before doing anything:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md (especially §0 and §5), docs/fix-plan/01-integration-contracts.md, docs/fix-plan/member-8-audio-qa.md.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-8/audio-qa or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) my audit IDs, (b) my step list with waves, (c) the current real status of the test suites if you can run them (<GODOT> --headless --path . -s <suite>). Then stop and wait for me.

Rules for this whole session:
- A test that makes zero assertions is a FAILURE. A test that sets game state directly or calls private (_underscore) methods of the code under test is not an integration test. Say so explicitly.
- Integration and anti-cheat tests must drive the server through the same path a real client uses: ClientNetworkManager request methods -> RPC -> ServerNetworkManager. Never call manager methods directly in those suites.
- Never report a result you didn't produce in this session. Always paste the real output lines and exit codes.
- Edit ONLY my files. Other members' suites: report what's wrong and draft a handoff note; don't fix them for them.
- No absolute paths in any test. Temporary output goes to user://.
- After each step: list changed files, show test output, and draft a PROJECT_STATUS.md §7 entry dated today citing the audit IDs. Do not commit unless I say so.
```

---

### Step 0 — Pin the engine + line endings (Wave 0) — R1, R7
**Do**
- Agree on **Godot 4.4.1-stable** (decision D5) and announce it: everyone installs it.
- Run the import once and commit all `.import`/`.uid` changes in a **single** PR, so nobody else commits that churn. Ask everyone to avoid committing `.import` files the same day.
- Add a `.gitattributes`: `* text=auto eol=lf`, and binary for png/jpg/wav/ogg/ttf/otf/res/scn.
- Update the Commands section of `CLAUDE.md` (4.4.1, the new runner command).

**Agent prompt**
```text
Do Step 0 (audit R1, R7). With Godot 4.4.1 (<GODOT>, verify with --version) run <GODOT> --headless --path . --import and show git status --short | head plus counts of changed .import, .uid and other files. Show me any non-.import/.uid file that changed (it must be reviewed separately). Create .gitattributes with "* text=auto eol=lf" and binary rules for *.png *.jpg *.jpeg *.wav *.ogg *.mp3 *.ttf *.otf *.res *.scn *.exe. Update the Commands section of CLAUDE.md: engine Godot 4.4.1-stable, full regression = <godot> --headless --path . -s tests/run_all_tests.gd, single suite command unchanged. Don't commit. Summarise what I should announce to the team.
```

---

### Step 1 — `shared/debug_flags.gd` (Wave 0)
**Agent prompt**
```text
Do Step 1 (contracts §12). Create shared/debug_flags.gd exactly as in contracts §12 (class_name DebugFlags, static hotkeys_enabled() returning OS.is_debug_build() and ProjectSettings.get_setting("blackout/debug/enable_hotkeys", false)). Add a tiny test asserting it returns false by default. Then grep the whole repo for _input/_unhandled_input handlers that check keycodes and produce a table: file | keys | owner (per docs/fix-plan/00-audit.md §7) | gated? This table goes to each owner as a handoff note.
```

---

### Step 2 — Test harness (Wave 0) — Q4
**Do:** `tests/test_harness.gd` (`extends SceneTree`) that every suite can extend:
- `check(cond, msg)`, `check_eq(a, b, msg)` → print `[PASS]`/`[FAIL]` and count;
- `finish()` → prints totals and calls `quit(1)` if `failures > 0 or assertions == 0`, else `quit(0)`;
- a global timeout (default 60s) → `[FAIL] timeout` + `quit(1)`;
- `BalanceConfig.clear_overrides()` in `finish()` if `BalanceConfig` exists;
- helpers to spin a loopback server + N clients and `poll(seconds)`. Copy the pattern the existing multiplayer suites use.

**Agent prompt**
```text
Do Step 2 (audit Q4). Read tests/test_multiplayer_server.gd and tests/test_meeting_voting_system.gd to learn how they create a real ServerNetworkManager and multiple ClientNetworkManagers over loopback ENet and poll. Create tests/test_harness.gd (extends SceneTree) with: check(cond, msg), check_eq(actual, expected, msg), assertion/failure counters, finish() that prints a summary and quits 1 if failures > 0 OR assertions == 0 (else 0), a watchdog timeout (default 60s, overridable) that fails the suite, helpers start_loopback_match(port, client_count) -> {server, clients} and poll(seconds), and teardown that stops the network and calls BalanceConfig.clear_overrides() if that class exists. Convert ONE existing suite of mine (tests/test_audio_manager.gd) to use it as the reference example. Write a short "How to write a suite" section at the top of test_harness.gd. Run the converted suite.
```

---

### Step 3 — A real master runner (Wave 0) — Q1
**Do:** rewrite `tests/run_all_tests.gd`:
- discover every `tests/**/test_*.gd` (skip `test_harness.gd` and non-suites such as `capture_lobby_screenshots.gd`);
- run each with `OS.execute(OS.get_executable_path(), ["--headless", "--path", <project>, "-s", <suite>], output, true)`;
- record the exit code, the `[PASS]`/`[FAIL]` counts and the duration;
- print a table;
- `quit(1)` on any failure.

`KNOWN_FAILURES: Dictionary = {"res://tests/...": "audit C2"}` reports those suites as **XFAIL** (not failing the run), and as **XPASS = failure** when they unexpectedly pass, so the list shrinks as fixes land. Add `tools/run_tests.ps1` / `.sh` wrappers.

**Agent prompt**
```text
Do Step 3 (audit Q1). Rewrite tests/run_all_tests.gd: discover all tests/**/test_*.gd except test_harness.gd and non-suite scripts; for each run OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", suite_path], output, true); parse exit code + count [PASS]/[FAIL] lines; print a table (suite | exit | pass | fail | seconds | status) and totals; quit(1) if any suite failed. Add const KNOWN_FAILURES: Dictionary (suite path -> audit id) where a failing suite is reported XFAIL (doesn't fail the run) and a passing one is reported XPASS and DOES fail the run (so the list gets cleaned up). Also add a suite with 0 [PASS] and 0 [FAIL] lines = FAIL. Add tools/run_tests.ps1 and tools/run_tests.sh that take the Godot path as the first argument. Run the new runner now and paste the full table. That table is the new truthful baseline. Put currently failing suites into KNOWN_FAILURES with their audit IDs.
```

---

### Step 4 — Fix the anti-cheat suites (Wave 1) — Q2, Q8
**Do:** all 6 suites in `tests/server_authority_tests/`:
- rewrite on the harness;
- drive everything through clients → RPC → server (e.g. `client.request_complete_task(fake_id)`, then assert server state unchanged + `action_rejected` received);
- keep the original intent of every test case;
- fix roles TEST 5 (the expected string must match `NetworkConfig.get_role_name`'s documented behaviour, or ask M1 to define "UNKNOWN").

Cases that can't pass until M1/M2 fixes land go into `KNOWN_FAILURES` **with the audit ID**, not deleted.

**Agent prompt**
```text
Do Step 4 (audit Q2, Q8). For each suite in tests/server_authority_tests/: list every test case and its intent. Then rewrite the suite on tests/test_harness.gd so every case goes through a real client (ClientNetworkManager request methods over loopback) and asserts BOTH that server state didn't change AND (once M1's contract stubs are on main) that the client received action_rejected with the expected action. No direct manager calls. For test_anti_cheat_roles TEST 5: check what NetworkConfig.get_role_name returns for out-of-range values and assert that, or draft a note to M1 if you think it should be "UNKNOWN". Run each suite and the runner. Cases that fail because of known audit bugs stay in, and the suite goes into KNOWN_FAILURES with the audit id.
```

---

### Step 5 — Design-rule regression suite (Wave 1) — Q5
**Do:** `tests/server_authority_tests/test_design_rules.gd`, one case per rule, all through the RPC boundary:
1. The Impostor is random: over 50 lobbies, ≥ 4 different slots were Impostor.
2. `activate_blackout` before unlock is rejected; a sabotage request never changes state.
3. Blackout activates at most once per match.
4. Crew clients never receive BLACKOUT_AVAILABLE.
5. No meeting outside POST_BLACKOUT_INVESTIGATION; exactly one meeting per match.
6. Meltdown starts once, its timer never increases, and completed systems never un-complete.
7. MELTDOWN always follows VOTING, whatever the vote result.
8. No client ever receives evidence details it didn't inspect, and no evidence payload contains a peer ID.
9. Completion without begin → rejected; too fast → rejected; too far → rejected.
10. Objective completion by Crew → rejected; recovery by the Impostor → rejected.
11. Kills are rejected when `kills.enabled` is false.
12. No lobby/state payload ever contains a `role` key before GAME_OVER.
13. The game-over roster contains all 8 roles.
14. Chat outside MEETING/VOTING is rejected; chat text is delivered verbatim.

**Agent prompt**
```text
Do Step 5 (audit Q5). Create tests/server_authority_tests/test_design_rules.gd on the harness implementing the 14 rules listed in my guide Step 5, each as a separate named case, using only loopback clients and BalanceConfig.set_override for short timers (if BalanceConfig isn't on main yet, write the cases and skip them with a clear [FAIL] "blocked: BalanceConfig missing"). Intercept every RPC payload received by each client (wrap or connect to the ClientNetworkManager signals) to check rules 4, 8 and 12. Run it and list which rules pass today and which fail with which audit id. Add the suite to KNOWN_FAILURES with the list of expected-failing audit ids.
```

---

### Step 6 — Runner lint (Wave 1) — Q7
**Agent prompt**
```text
Do Step 6 (audit Q7). Add a lint phase to tests/run_all_tests.gd that scans every .gd and .tscn in the repo (excluding .godot/) for absolute paths ("C:/", "C:\\", "/Users/", "/home/", ".gemini") and fails the run listing file:line. Run it and produce a handoff list per owner (the current hits are in M5's files and tests).
```

---

### Step 7 — Audio into the game (Wave 1) — I6, Q6
**Do**
- Make `AudioManager` safe to call before `_ready()`: lazily create its players in an `_ensure_nodes()` called by every public method.
- Ask M1 to add the autoload **`Audio`** → `res://client/audio/audio_manager.gd` (contracts §13; never named `AudioManager`).
- On `_ready`, the gameplay bridge connects to `/root/NetworkManager.client`.
- Meltdown intensity comes from `timer_synced(MELTDOWN)`.
- Fix `test_audio_manager.gd` (await a frame or rely on the lazy init).
- Volume setters for M5's settings.

**Agent prompt**
```text
Do Step 7 (audit I6, Q6; contracts §13). In client/audio/audio_manager.gd add _ensure_nodes() (idempotent creation of all players/buses) and call it at the top of every public method so calls before _ready work. Make the gameplay bridge auto-connect to /root/NetworkManager.client when it exists, and drive update_meltdown_intensity from client.timer_synced(MELTDOWN). Make sure nothing plays in headless/dedicated-server mode (NetworkManager.is_dedicated_server). Fix tests/test_audio_manager.gd on the harness. The 11 failures and 190 runtime errors must be gone. Draft a handoff note to M1: add autoload "Audio" -> res://client/audio/audio_manager.gd in project.godot (not "AudioManager", which clashes with the class_name). Run test_audio_manager, test_footstep_audio, test_interaction_audio.
```

---

### Step 8 — Remove the duplicate audio (Wave 1) — R2
**Agent prompt**
```text
Do Step 8 (audit R2). List every .wav under assets/audio and whether it is referenced (grep all .gd/.tscn/.tres/.py for its res:// path, and assets/audio/audio_registry.gd). The registry uses the subfolder copies; 26 flat copies look unreferenced. Show the table, then after my OK git rm the unreferenced duplicates with their .import files, run tools/verify_audio_paths.py (fix it if it assumes the old layout), update docs/member-8/audio-asset-manifest.md, and run the audio suites.
```

---

### Step 9 — Registry ↔ map placement test (Wave 2)
**Agent prompt**
```text
Do Step 9 (contracts §4 placement invariant). Create tests/test_map_registry_placement.gd on the harness: instance res://scenes/environment/facility_map.tscn and assert that every StationRegistry.STATIONS id has a node Stations/<id> within 4px of its position, containing an InteractableStation; every DOORS id has Doors/<id> within 4px; SpawnPoints/Spawn1..8 match SPAWN_POINTS within 4px; every EVIDENCE_ANCHORS key has EvidenceAnchors/<key>; every station room_id is a canonical room id and its position lies inside that room's rect; and no extra station nodes exist that aren't in the registry. Run it; if it fails because M7's anchors aren't placed yet, add it to KNOWN_FAILURES.
```

---

### Step 10 — The real end-to-end match test (Wave 3) — Q3
**Do:** `tests/test_e2e_full_match.gd`: 1 server + 8 clients over loopback. Everything goes through client request APIs. `BalanceConfig` overrides keep it under ~60s. Two scenarios in one suite:
- **A — Crew win:**
  1. names, ready, roles (seed);
  2. tasks via begin → complete;
  3. Impostor unlock → activate → countdown;
  4. Impostor completes 1 objective at its station;
  5. Crew recovers 3 of 4 → investigation;
  6. one Crew inspects evidence;
  7. the meeting button;
  8. chat;
  9. all vote the Impostor → ejected;
  10. MELTDOWN;
  11. 3 repairs → GAME_OVER Crew with an 8-role roster;
  12. return to lobby;
  13. a second match reaches INITIAL_TASK_PHASE.
- **B — Impostor win:** same until the vote → skip wins → MELTDOWN with the Impostor alive → one disruption → timer expiry (override 5s) → GAME_OVER Impostor.

Delete `test_master_e2e_match_loop.gd` once this passes (it's the fake).

**Agent prompt**
```text
Do Step 10 (audit Q3). Create tests/test_e2e_full_match.gd on the harness implementing scenarios A and B exactly as listed in my guide Step 10. Rules: only ClientNetworkManager request methods and signals; never touch server internals except read-only assertions at the end (state, roster); positions sent via the real position RPC, walking in small steps to each station's registry position (write a helper walk_to(client, target) that sends plausible positions at 20 Hz); BalanceConfig.set_override for short durations (blackout 8s, investigation 3s, discussion 2s, voting 3s, meltdown 20s for A / 5s for B, anti_cheat.min_duration_factor 0.05). Assert every expected signal on every client (e.g. all 8 receive game over with 8 roster entries). Run it and report exactly which step fails first, with the server log lines around it, and which audit id / member owns the fix. When it passes twice in a row, delete tests/test_master_e2e_match_loop.gd.
```

---

### Step 11 — CI (Wave 3)
**Agent prompt**
```text
Do Step 11. Create .github/workflows/tests.yml: on pull_request and push to main; ubuntu-latest; download Godot 4.4.1-stable linux x86_64 from the official GitHub release, unzip, cache it; run godot --headless --path . --import (ignore its exit code, it's only priming the import cache); then godot --headless --path . -s tests/run_all_tests.gd and fail the job on a non-zero exit. Upload the runner output as an artifact. Show me the file. I will push it, since it runs on GitHub.
```

---

### Step 12 — Stale branch cleanup (Wave 3) — R5
This deletes remote branches, so get the team's OK in writing first.
```text
Do Step 12 (audit R5). List every remote branch with: last commit date, author, and whether it is fully merged into origin/main (git branch -r --merged origin/main). Produce a proposal table (delete / keep + reason). Do NOT delete anything; give me the exact git push origin --delete commands to run after the team approves.
```

---

### Step 13 — Playtest operations (Wave 4)
**Do**
- Update `tests/playtest_checklists/playtest_checklist_8player.md` to the real flow (menu → host/join → lobby → … → rematch).
- Run sessions with `tools/launch_local_match` (local) and then a real LAN session.
- File every bug as a GitHub issue named `[PT-n]`, with the owner from the audit's owner map.
- Collect `user://match_logs/*.json` for M6.

**Agent prompt**
```text
Do Step 13. Rewrite tests/playtest_checklists/playtest_checklist_8player.md for the recovered flow: launch -> main menu -> host/join by IP -> lobby names/ready -> role reveal -> tasks at stations with mini-games -> impostor unlock + activate (Q or HUD button) -> blackout visuals/doors/audio -> recovery 3/4 -> evidence markers + inspection -> meeting button / auto meeting -> chat -> vote -> ejection reveal -> meltdown repairs/disruption -> game over roster -> return to lobby -> rematch. Each item: expected result, the audit ID it verifies, pass/fail box. Add a bug report template (steps, expected, actual, logs, owner per docs/fix-plan/00-audit.md §7).
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main: (1) changed files are all mine per docs/fix-plan/member-8-audio-qa.md §1 (or have the owner's OK noted); (2) no test calls private methods or writes server state directly (except read-only asserts); (3) no suite can pass with zero assertions; (4) no absolute paths; (5) run the full runner and paste the table; KNOWN_FAILURES entries each cite an audit id and none is XPASS; (6) draft the PR description (template in docs/fix-plan/README.md §5) and the PROJECT_STATUS.md §7 entry.
```
