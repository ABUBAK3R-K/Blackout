# BLACKOUT — Recovery Plan (Fix Guide Index)

**Created:** 2026-09-25 · **Baseline commit:** `main @ 379ed70` · **Prepared for:** all 8 members
**Status:** PROPOSED. The decision record (§3) and the contracts file must be ratified at the kickoff meeting before Wave 1 starts.

This folder turns the repository audit into per-member work. Everyone reads the same four shared files, then works only from their own guide.

| File | Who reads it | What it is |
|---|---|---|
| `README.md` (this file) | Everyone | Decisions, waves, dependencies, workflow, PR rules |
| `00-audit.md` | Everyone | Every defect found, with an ID (C1, H3, I4…) and the file it lives in |
| `01-integration-contracts.md` | Everyone | **The single source of truth** for every RPC, signal, config key, node path and ID that crosses a member boundary |
| `member-1-backend-network.md` | Mayiz | Step-by-step guide + agent prompts |
| `member-2-gameplay-backend.md` | Abdul Qadir | Step-by-step guide + agent prompts |
| `member-3-client-engine.md` | Aaliya | Step-by-step guide + agent prompts |
| `member-4-mini-games.md` | Ubaid | Step-by-step guide + agent prompts |
| `member-5-ui-frontend.md` | Shahzan | Step-by-step guide + agent prompts |
| `member-6-game-design.md` | Abubaker | Step-by-step guide + agent prompts |
| `member-7-environment-art.md` | Fatima | Step-by-step guide + agent prompts |
| `member-8-audio-qa.md` | Sahil | Step-by-step guide + agent prompts |

---

## 1. Why the project broke (read this first)

Each member built their module against their own idea of the interfaces, tested it in isolation, and marked it "complete". Nobody owned integration. The result:

- **Two front-ends that were never joined.** `scenes/main.tscn` is a single-player world with no menu and no network start. `main_menu → lobby → hud.tscn` is UI only, with no world, and it does not compile.
- **Parallel duplicates of the same thing:**
  - 2 maps
  - 2 UI stacks
  - 2 lighting systems
  - 2 station systems
  - 3 state machines (`GameState`, `RoundManager`, `SabotageManager`)
- **Hard design rules are broken on the server.** The first player to join is always the Impostor, blackout can be triggered on spawn, and Meltdown can be reset.
- **Tests that do not test.** The master runner executes nothing, 5 anti-cheat suites do not compile, and the "end-to-end" test sets state directly.

**The fix is not "everyone fixes their bugs".** The fix is:
1. Agree on one set of interfaces: `01-integration-contracts.md`.
2. Build to it.
3. Prove it with tests that run the real client ↔ server path.

**Rule for the whole recovery:** if your code talks to another member's code, the interface must be in the contracts file. If it isn't, stop and get it added (PR reviewed by Member 1 + Member 6) before writing code against it.

---

## 2. How to use your guide with an AI agent

1. Open your `member-N-*.md` file.
2. Start a fresh agent session in the repo root (Claude Code, Antigravity, Cursor, Copilot — any agent that can read files and run commands).
3. Paste **Prompt 0 (Session kickoff)** from your guide. Wait for the agent to summarise your assignment back to you and check that it is correct.
4. Paste the prompt for the step you are on. **One step per session is ideal**; start a new session and re-paste Prompt 0 when context gets long.
5. Before you open a PR, paste the **Final review prompt** from your guide.
6. Replace `<GODOT>` in every prompt with the full path to your Godot executable, e.g.
   - Windows: `C:\Tools\Godot_v4.4.1-stable_win64_console.exe`
   - macOS/Linux: `/usr/local/bin/godot`

**Never** let an agent:
- edit files outside your ownership list;
- invent an interface that isn't in the contracts file;
- mark something "done" or "passing" without showing real test output.

These three things are how the project got here.

---

## 3. Decision record (PROVISIONAL — ratify at kickoff)

These were open questions in the audit. The plan assumes the **recommended** option. If the team picks differently at kickoff, Member 6 updates this table and the contracts file **before** Wave 1.

| # | Decision | Assumed choice | Why | Owner |
|---|---|---|---|---|
| D1 | Impostor kills + body reports | **Disabled for MVP** via `kills.enabled = false` in the balance config. The code stays behind the flag. | README says "no instant kills". Design §3.7 recommends a meeting button. Kills add a win condition (CREW_ELIMINATED) that PRD FR-41 doesn't have. | M6 + M1 |
| D2 | Hosting model | **Dedicated authoritative server process.** "Host Game" spawns a headless server child process and joins it. `--server` CLI flag for standalone servers. | One process cannot be both server and client with the current network layer. This avoids rewriting every RPC. | M1 |
| D3 | UI stack | **Member 5's** (`client/ui/hud`, `meeting`, `screens`, `menu`). Member 3's duplicates (`client/ui/meeting_voting_ui.gd`, `meltdown_hud.gd`, `game_over_ui.gd`, `objective_tracker.gd`) are deleted after parity. `evidence_dossier_ui.gd` is transferred to M5. | TEAM_SPLIT gives all UI to M5 | M5 + M3 |
| D4 | World map | **Member 7's** `scenes/environment/facility_map.tscn` (9 rooms, art, lighting). `scenes/map/facility_map.tscn` is retired. | Art + lighting are already built into it | M7 + M3 |
| D5 | Engine version | **Godot 4.4.1-stable** for everyone | 55 `.uid` files and the `.import` keys show most members already use 4.4. Running 4.3 rewrites 59 files. | M8 |
| D6 | Scene flow | `main_menu.tscn` becomes the project main scene → `lobby_room.tscn` → on `ROLE_ASSIGNMENT` change scene to `scenes/main.tscn` (the world, which contains the HUD) | One path from launch to game over | M5 + M3 |
| D7 | Evidence discovery | Evidence **markers** appear in the world at investigation start (type + location only). **Details** are sent only to the player who walks up and inspects. Nothing is auto-broadcast. | design.md §7: "discoverable through play, never broadcast automatically" | M6 + M2 |
| D8 | Investigation → meeting | Investigation lasts `investigation.duration_sec` (45s), then the meeting starts automatically. Any living player can start it early at the Cafeteria **meeting button**. | Fixes the dead end in audit C5 | M6 + M2 |
| D9 | Chat scope | Text chat **only during MEETING and VOTING**, living players only, 200 chars, 1 message/sec | Resolves PRD open question 4 simply | M6 + M1 |
| D10 | Disconnect policy | Lobby: normal. In a match: an **Impostor disconnect ends the match — Crew wins** (`IMPOSTOR_DISCONNECTED`). A Crew disconnect = removed from votes; the match continues. Fewer than 2 connected players = `MATCH_ABANDONED`, back to lobby. | NFR-4 requires an explicit policy | M1 + M6 |
| D11 | Missing PRD mechanics | Build **minimal** versions: <br>• ORION instability 0–100 (flavour only, never changes the 5-min timer)<br>• Impostor Meltdown disruption (locks a console for 12s, 40s cooldown)<br>• 2 random doors jam during blackout<br>• Security cameras are **P2** — build if time allows, otherwise M6 descopes FR-13 in the PRD | FR-13/14/16/24/37 are MVP requirements | M6 + M2 |
| D12 | Anti-cheat model | Every interaction is a **begin → complete handshake**. The server checks state, role, distance to the station (from `shared/station_registry.gd`) and a minimum duration. Positions are speed-checked. | Today a client can complete every task/objective from anywhere, instantly | M1 + M2 + M6 |

---

## 4. Waves and dependencies

Work runs in waves. **Do not start a wave-2 item that depends on a wave-1 item until that item is merged to `main`.** Each guide's steps are tagged with their wave.

```
WAVE 0  (Day 1–2)   Kickoff & foundations
  M6  Ratify decisions D1–D12; add new balance keys; draft shared/station_registry.gd
  M8  Pin Godot 4.4.1; real test runner; test harness that fails on 0 assertions
  M1  Land contract STUBS: new RPCs, client signals and NetworkConfig enums (no logic)
      so everyone can code against them
          │
WAVE 1  (Day 3–6)   Server core + unblock the client
  M1  Random Impostor, one state machine, transition table, public state, hosting,
      names, chat, timer sync, handshake, disconnect policy
  M2  Balance loader, investigation window, voting fixes, evidence API,
      Meltdown safe to call twice, public manager APIs
  M8  Fix the 5 anti-cheat suites; design-rule regression suite
  M5  Fix HUD compile; hide debug hotkeys; menu → lobby → world flow
  M7  Map collisions, spawn points, station/door/evidence anchors per registry
  M4  Station fixes (local player only, task-instance lookup, handshake client side)
          │
WAVE 2  (Day 7–11)  One playable client
  M3  World scene on M7 map + PlayerVisual + M5 HUD; delete old map/UI/stations
  M4  All stations on mini-games; meeting button; evidence inspect; disruption
  M5  Wire the HUD to real signals; chat UI; role reveal; dossier; toasts
  M2  Instability, disruption, door jams (server)
  M1  Plumbing for the wave-2 mechanics
  M7  Lighting and VFX bound to server state; StationProp states
          │
WAVE 3  (Day 12–15) Prove it
  M8  Real 1-server + 8-client e2e test (both endings); CI; audio autoload + dedupe
  M3  Security cameras (P2); polish
  All Fix-forward from e2e failures
          │
WAVE 4  (Day 16+)   Playtest & paperwork
  M8  8-player playtest with the checklist
  M6  Balance review; reconcile design.md/PRD.md
  M6+M8  Rewrite PROJECT_STATUS.md truthfully
```

**Critical path:** M1 contract stubs → M1 server core → M3 world scene → M4 stations → M8 e2e. If M1 slips, everyone slips, so M1 gets first review priority on every PR.

---

## 5. Git workflow (everyone)

```bash
git fetch origin
git checkout member-N/<your-branch>
git merge origin/main              # do this every morning
# ... work, one step at a time ...
<GODOT> --headless --path . -s tests/run_all_tests.gd     # once M8's real runner lands
git add <only your files>
git commit -m "fix(<area>): <what> [audit C1]"   # always cite the audit ID(s)
git push origin member-N/<your-branch>
# open a PR into main; fill in the template below
```

- **Small PRs.** One guide step = one PR where possible.
- **Never merge your own PR.** Reviewers:
  - server or win-condition changes → M1 or M2
  - contract changes → M1 + M6
  - UI, shader or map changes → M5 or M7
  - everything → M8 checks CI is green
- Every PR adds a dated entry to `PROJECT_STATUS.md` §7 (template in that file) and lists the audit IDs it closes.

### PR template
```markdown
## What
<one paragraph>

## Audit IDs closed
C1, H3, ...

## Contract impact
None | Implements contracts §X | Changes contracts §X (link to the contracts PR)

## Test evidence
<paste the real headless output: suite name + [PASS]/[FAIL] lines + exit code>

## Files touched (all owned by me?)
- [ ] yes
- [ ] no, coordinated with: <member> (link)
```

---

## 6. Definition of done for the recovery

- [ ] `tests/run_all_tests.gd` executes every suite and exits non-zero on any failure. CI runs it on every PR.
- [ ] A 1-server + 8-client loopback test plays a full match to **both** endings using only client request APIs.
- [ ] Launching the game shows the main menu. Host/Join works across two machines on a LAN.
- [ ] 8 real players complete a match from menu to Game Over and back to lobby, following `tests/playtest_checklists/playtest_checklist_8player.md`.
- [ ] Every audit ID in `00-audit.md` is closed, or explicitly descoped by M6 with a PRD note.
- [ ] `PROJECT_STATUS.md` reflects reality.
