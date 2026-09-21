# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**BLACKOUT** — a 2D top-down multiplayer social deduction game (Among Us-style: 7 Crew vs. 1 Impostor) built in **Godot 4.3 (GDScript)**, using an authoritative server-client architecture over `ENetMultiplayerPeer`. See `README.md` for gameplay overview, `design.md` for the full technical design (state machine, phase mechanics, config levers), and `PRD.md` for requirements.

## Commands

There is no build step (Godot project). Tests are headless GDScript integration suites run directly with the Godot executable — no test framework (e.g. GUT) is used; each test file is a `SceneTree` script that prints `[PASS]`/`[FAIL]` and exits.

Run a single test suite:
```bash
godot --headless -s tests/test_task_system.gd
```
(On Windows, invoke the full path to the Godot executable, e.g. `& "path\to\Godot_v4.3-stable_win64_console.exe" --headless -s tests/test_task_system.gd`.)

Run the full regression suite (all suites under `tests/`, one invocation each):
```bash
godot --headless -s tests/test_multiplayer_server.gd
godot --headless -s tests/test_lobby_system.gd
godot --headless -s tests/test_role_assignment.gd
godot --headless -s tests/test_task_system.gd
godot --headless -s tests/test_blackout_system.gd
godot --headless -s tests/test_blackout_recovery_objectives.gd
godot --headless -s tests/test_evidence_system.gd
godot --headless -s tests/test_meeting_voting_system.gd
godot --headless -s tests/test_meltdown_system.gd
godot --headless -s tests/test_win_condition_manager.gd
```
Each test suite spins up a real `ServerNetworkManager` + one or more `ClientNetworkManager` clients over a loopback ENet socket (`127.0.0.1`, test-specific port) and polls the network manually — there is no mocking of the network layer. A suite exits non-zero (and prints `[FAIL]` lines) on any assertion failure.

Open the project in the editor / run it directly:
```bash
godot --path .            # editor
godot --path . --headless # run main scene headlessly
```

## Architecture

### Server-authoritative split
All state that determines win/lose, role identity, or objective completion is owned exclusively by the server; clients only render, take input, and display UI/audio feedback (`design.md` §6.2). Concretely:

- `shared/network_manager.gd` — the `NetworkManager` autoload (registered in `project.godot`), the single entry point that owns a `ServerNetworkManager` and a `ClientNetworkManager` child and switches between `OFFLINE` / `SERVER` / `CLIENT` mode.
- `server/server_network_manager.gd` — the authoritative hub. Owns `connected_players`, `current_game_state`, and instantiates/wires every gameplay manager (task, blackout, recovery, impostor objectives, evidence, meeting, voting, meltdown, win condition) via signals. This is the file to read first to understand how a full match flows.
- `client/client_network_manager.gd` — thin client-side counterpart: sends RPC requests, receives server broadcasts, mirrors state for rendering.

### Match state machine
The match progresses through `NetworkConfig.GameState` (`shared/network_config.gd`):
`LOBBY → ROLE_ASSIGNMENT → INITIAL_TASK_PHASE → BLACKOUT_AVAILABLE → BLACKOUT_ACTIVE → POST_BLACKOUT_INVESTIGATION → MEETING → VOTING → MELTDOWN → GAME_OVER`

Each gameplay system in `server/` is scoped to specific states and rejects requests made outside them (e.g. emergency system completion is only valid during `MELTDOWN`). See `design.md` §2–3 for the full phase-by-phase design and §6.4 for tunable config values (blackout duration, recovery threshold, meltdown duration, etc).

### Module pairing convention
Each gameplay system follows a consistent 3-file pattern:
- `server/<system>_manager.gd` — authoritative logic, validation, signals (e.g. `blackout_manager.gd`, `evidence_manager.gd`, `meltdown_manager.gd`).
- `shared/<system>_config.gd` (+ sometimes `_definition.gd`) — constants, tunable values, and data-only definitions shared by server and client, preloaded by the manager.
- `tests/test_<system>.gd` — the headless suite that exercises that manager end-to-end over real network sockets.

When modifying a manager's behavior, check whether its paired `_config.gd`/`_definition.gd` needs a matching update, and run its paired test suite (plus the full regression list above, since managers are wired together through `ServerNetworkManager` signals and state transitions cascade).

### Directory layout
Note: `README.md`'s "Architecture & Module Ownership" section describes an aspirational nested layout (`blackout/server/core/`, `blackout/server/gameplay/`, etc.) that does not match the actual flat structure — the real layout is `server/*.gd`, `client/*.gd`, `shared/*.gd`, `scenes/`, `assets/`, `tests/` as listed above.

### Team ownership model
Development is split across 8 members, each with strict, exclusive ownership of a subsystem and a dedicated `member-N/*` branch (see `README.md` for the full table and `TEAM_SPLIT.md` for detailed deliverables). Notably:
- Member 2 owns all of `server/` gameplay logic and `shared/*_config.gd` / `*_definition.gd`.
- Member 7 owns `assets/sprites/`, `assets/vfx/`, and `scenes/environment/` (see `docs/environment_art_spec.md`).
- `PROJECT_STATUS.md` is an append-only change log — every change to code or docs should get a dated entry there following the template in its §7, and the module status matrix in §2 should stay current.

Do not edit another member's owned modules without direct coordination; cross-cutting changes to shared RPC schemas or config constants require notifying the paired partner (`PROJECT_STATUS.md` §7.4).
