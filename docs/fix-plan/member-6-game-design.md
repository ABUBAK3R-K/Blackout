# Member 6 — Abubaker — Game Systems & Content Designer · Fix Guide

**Branch:** `member-6/game-design`
**Read first:** `README.md`, `00-audit.md`, `01-integration-contracts.md` (all in `docs/fix-plan/`)
**Your audit IDs:** decisions D1–D12, H8 (values), F7 / F9 (scope calls), R3, R4 (with M8), plus the **station registry** content and spec reconciliation

In this recovery you are the **source of truth for content**. Three things only you can produce block other members in Wave 0:
1. **Ratified decisions (D1–D12).** Everyone codes against them.
2. **`shared/station_registry.gd`.** M1 validates against it, M4 reads it, M7 places the map from it, M8 tests the placement.
3. **The new balance keys in `config/game_balance_config.json`.** M2's loader reads them.

After Wave 0 you move into review mode (TEAM_SPLIT rule 2: PRs touching balance, evidence or task content need your approval), then documentation and balance work.

---

## 1. Your files (you may edit)
- `config/game_balance_config.json`
- **New:** `shared/station_registry.gd` (data-only content: IDs, rooms, positions, radii, minimum durations, doors, anchors, spawns)
- `design/specs/task_specifications.md`, `evidence_matrix.md`, `map_station_layout.md`
- `design.md`, `PRD.md`, `README.md` (content and links), `documentation/README.md`
- `TEAM_SPLIT.md` (only to record the new ownership moves from decision D3)
- `docs/fix-plan/*`: the decision record, and the contracts file together with M1
- `PROJECT_STATUS.md` §1–§5 dashboard, together with M8. **§7 stays append-only for everyone.**
- **Delete:** `design (1).md`, `PRD (1).md`

## 2. Not yours
- Any `.gd` logic → M1/M2/M3/M4/M5/M7/M8. Your registry file is pure data (constants + tiny lookup functions).
- `shared/*_config.gd` constants → M2 ports your catalog decisions into them.

## 3. Dependencies
| You need | From | For step |
|---|---|---|
| The room rectangles of M7's map (copied below from `scenes/environment/facility_map.gd` @ 379ed70) | M7 | 3 |
| Door opening positions (M7 confirms after you draft) | M7 | 3 |

| Others need from you | Step | Blocks |
|---|---|---|
| Ratified decisions | **1** | everyone |
| New JSON keys | **2** | M2 Step 1 |
| `station_registry.gd` | **3** | M1 Steps 6–7, M4 Step 1, M7 Step 2, M8 placement test |
| Location-ID mapping | **4** | M2 Step 7 |

### M7 room rectangles (world coordinates, `Rect2(x, y, width, height)`)
| Room ID | Rect | Centre |
|---|---|---|
| `cafeteria` (spawn hub) | (-448, -320, 896, 640) | (0, 0) |
| `storage` | (-1020, -856, 640, 512) | (-700, -600) |
| `server_room` | (-288, -856, 576, 512) | (0, -600) |
| `medbay` | (412, -856, 576, 512) | (700, -600) |
| `generator_room` | (-1102, -288, 704, 576) | (-750, 0) |
| `executive_office` | (394, -224, 512, 448) | (650, 0) |
| `security_room` | (-906, 376, 512, 448) | (-650, 600) |
| `laboratory` | (-320, 344, 640, 512) | (0, 600) |
| `orion_core` | (334, 234, 832, 832) | (750, 650) |

The layout is a **3×3 grid with the Cafeteria in the centre**: top row storage / server_room / medbay; middle row generator_room / cafeteria / executive_office; bottom row security_room / laboratory / orion_core. This does **not** match the ring connectivity in your current `map_station_layout.md` §3. Update the spec to the built map (Step 4); that's cheaper than rebuilding art.
Current spawn offsets (from the Cafeteria centre): (0,-160), (120,-120), (160,0), (120,120), (0,160), (-120,120), (-160,0), (-120,-120).

## 4. Step overview
| Step | Wave | What | Blocks / IDs |
|---|---|---|---|
| 1 | 0 (day 1) | Run kickoff, ratify D1–D12, record scope calls F7/F9, PRD open questions | everyone |
| 2 | 0 | Balance JSON: add the new keys from contracts §5 | M2 · H8 |
| 3 | 0 | Author `shared/station_registry.gd` | M1, M4, M7, M8 |
| 4 | 0–1 | Location-ID mapping + `map_station_layout.md` rewritten for the built 3×3 map | M2, M7 |
| 5 | 1 | Evidence matrix for inspection-based discovery (D7) | M2, M4, M5, M7 |
| 6 | 1 | Specs for the new mechanics: instability, disruption, door jams, cameras decision | M2, M4, M5, M7 |
| 7 | 1 | Reconcile `design.md` / `PRD.md` / `README.md`; delete duplicates | R3 |
| 8 | 1–4 | Review duty on content PRs | — |
| 9 | 4 | Rewrite the `PROJECT_STATUS.md` dashboard truthfully (with M8) | R4 |
| 10 | 4 | Playtest balance review against the targets (45–55% win rate, 15–25 min) | — |

---

## 5. Steps

### Prompt 0 — Session kickoff (paste at the start of EVERY new agent session)
```text
You are my agent on the BLACKOUT project (Godot 4.4, GDScript, server-authoritative 8-player social deduction game). The repo root is the current directory.
I am Member 6 (Abubaker), Game Systems & Content Designer. My branch is member-6/game-design. I own design content: config/game_balance_config.json, shared/station_registry.gd (data only), design/specs/*, design.md, PRD.md, README.md content, and the decision record in docs/fix-plan/README.md.

Before doing anything:
1. Read completely: CLAUDE.md, docs/fix-plan/README.md, docs/fix-plan/00-audit.md, docs/fix-plan/01-integration-contracts.md, docs/fix-plan/member-6-game-design.md, design.md, PRD.md, design/specs/*.md, config/game_balance_config.json.
2. Run: git status; git branch --show-current; git fetch origin; git log --oneline -1 origin/main.
   If I'm not on member-6/game-design or it is behind origin/main, tell me and propose the exact commands. Do not merge, reset or rebase yourself.
3. Reply with: (a) the decisions and content I must deliver in Wave 0, (b) my step list, (c) any contradiction you see between design.md, PRD.md, my specs and the contracts file. Then stop and wait for me.

Rules for this whole session:
- I make design decisions. You draft options and consequences, but never finalise a decision without asking me.
- Edit only my files. shared/station_registry.gd must stay DATA ONLY (consts + the tiny lookup functions listed in contracts §4). No gameplay logic.
- Every room_id/location_id must be one of the canonical room ids in contracts §1.1 or an EVIDENCE_ANCHORS key. Every station id must match contracts §1.2 exactly.
- Every position must lie inside its room's rectangle (table in my guide §3), at least 48px from the room edge.
- Design rules in design.md §5 are hard constraints (e.g. Meltdown is always 5 minutes, no automatic lie detection, blackout must be earned).
- If a step changes an interface in 01-integration-contracts.md, the change goes in its own PR reviewed by Member 1.
- After each step: list the changed files and draft a PROJECT_STATUS.md §7 entry dated today. Do not commit unless I say so.
```

---

### Step 1 — Kickoff: ratify decisions (Wave 0, day 1)
**Do**
1. Run a 45-minute kickoff with all 8 members. Walk through `docs/fix-plan/README.md` §1 and §3. For each of D1–D12, record: **Ratified** / **Changed to …**.
2. Make the two scope calls:
   - **F7 security cameras:** keep as P2, or descope FR-13 with a PRD note.
   - **F9 fake repair / evidence manipulation:** keep, or descope FR-25 (it is "optional" in the PRD).
3. Decide the Impostor-AFK question (PRD open question 8): what happens if the Impostor never finishes their prerequisites? Options:
   - (a) no fallback, per design rule #2, and accept the risk in MVP;
   - (b) a long fallback such as unlock at 6 min.

   Design §3.2 explicitly says **no** time-based fallback. Record the choice.
4. Update the decision table in `docs/fix-plan/README.md` (mark it RATIFIED) and PRD §9 with the resolutions.

**Agent prompt**
```text
Do Step 1 of my guide. Prepare a kickoff agenda (max 1 page) from docs/fix-plan/README.md §1 and §3: for each decision D1-D12, one line on what changes if we pick the alternative and which members are affected. Add the three open scope calls (F7 cameras, F9 fake repair, Impostor AFK / PRD open question 8) with pros and cons. Show me the agenda and wait.
After I give you the outcomes, update the decision table in docs/fix-plan/README.md (add a "Ratified 2026-MM-DD" status per row), update PRD.md §9 open questions with the resolutions, and if any decision changed, list the exact sections of 01-integration-contracts.md and the member guides that must change. Don't edit those yet.
```

---

### Step 2 — Balance JSON: new keys (Wave 0) — H8
**Do:** add every key from contracts §5 that isn't in the JSON yet, using the same `{"value", "range", "notes"}` style:
- `investigation.duration_sec`
- `chat.max_length`, `chat.min_interval_sec`
- `blackout.doors_jammed_count`
- `meltdown.disrupt_hold_sec`, `disrupt_duration_sec`, `disrupt_cooldown_sec`
- `orion_instability.per_objective_points`, `per_blackout_second`
- `kills.enabled`
- `anti_cheat.max_move_speed_px_s`, `position_tolerance_px`, `range_slack_px`, `min_duration_factor`
- `evidence.inspect_radius_px`

Also:
- update `_meta.status` ("loaded at runtime by `shared/balance_config.gd`; values here override code defaults") and bump `version` to `1.1.0-recovery`;
- update the `meeting_trigger` / `comms_scope_during_blackout` notes to the ratified D8/D9;
- remove notes that say something "is not implemented" once M2/M1 have landed it.

**Agent prompt**
```text
Do Step 2 (audit H8; contracts §5). Edit config/game_balance_config.json: add every key from the contracts §5 table that's missing, with {"value", "range", "notes"} in the file's existing style (ranges I'll confirm: propose sensible ones and explain each in one line). kills.enabled = false (decision D1). meltdown.duration_sec stays 300 with a note that it's forced by code. Update _meta.status and _meta.version ("1.1.0-recovery"), and rewrite the notes for meeting_trigger and comms_scope_during_blackout to match decisions D8 and D9. Keep the existing values unchanged unless I say otherwise. Validate: the file must parse as JSON (run a quick parse check with any available tool, e.g. python -m json.tool) and every key in contracts §5 must resolve by dotted path. Show me the diff.
```

---

### Step 3 — Author `shared/station_registry.gd` (Wave 0)
**Do:** fill in every entry from contracts §1.2 and §4:
- **23 stations:** 10 crew tasks + 4 recovery + 5 objectives + 3 emergency + the meeting button.
- the doors;
- the evidence anchors;
- the 8 spawn points.

Rules:
- `room_id` per your specs (after the Step 4 mapping).
- `position` inside the room rect, ≥ 48px from the edges, ≥ 96px from other stations, and away from the Cafeteria spawn circle.
- `radius` 72 (the meeting button 96).
- `min_duration_sec` = the spec duration: crew tasks per §1, objectives per §3, recovery per §4, emergency per §5.
- Spawns = Cafeteria centre + the current offsets.
- Doors = one per opening between adjacent grid rooms that M7 draws. Draft the positions on the shared edge midpoints and let M7 adjust.
- **Balance note:** your spec puts 8 stations in `generator_room`. Consider spreading `power_routing`, `cooling` or `restore_cooling` into adjacent rooms so the room isn't a single camping spot (design §3.5.2's "not a single camped room"). Your call.

**Agent prompt**
```text
Do Step 3 (contracts §1.2, §4). Create shared/station_registry.gd EXACTLY following the API in contracts §4 (class_name StationRegistry, consts STATIONS, DOORS, EVIDENCE_ANCHORS, SPAWN_POINTS and the listed static lookup functions, nothing else).
- STATIONS: one entry per station id in contracts §1.2 (23 total) with kind (NetworkConfig.InteractionKind), target_id, room_id, position, radius (72; meeting_button 96), min_duration_sec (from design/specs/task_specifications.md §1, §3, §4, §5), display_name.
- Positions: inside the room rectangle from my guide §3, >= 48px from edges, >= 96px from each other, and the Cafeteria stations >= 250px from the Cafeteria centre (spawn circle).
- SPAWN_POINTS: Cafeteria centre (0,0) + the 8 offsets in my guide §3, in slot order.
- DOORS: one per opening between grid-adjacent rooms (3x3 grid in my guide §3), id door_<roomA>_<roomB> alphabetical, position at the midpoint of the shared edge.
- EVIDENCE_ANCHORS: one per location_id used by evidence templates after my Step 4 mapping; place each near (but not on top of) the related objective station.
Before writing, show me a table: station id | room | position | radius | min duration, plus a note on any room with more than 4 stations. Wait for my OK. After writing, write a throwaway check (don't commit it) that loads the script and asserts: 23 stations, all ids from §1.2 present, every position inside its room rect with the 48px margin, no two stations closer than 96px. Run it with <GODOT> --headless --path . -s <check.gd> and show the output.
```

---

### Step 4 — Location mapping + map layout spec for the built map (Wave 0–1)
**Do**
- Decide the mapping for every non-canonical location ID. Suggestion:
  - `power_room` → `generator_room`
  - `cooling_hub` → `generator_room`, or move it
  - `containment_hub` → `orion_core`
  - `station_subsystem` → the recovery station's room
  - "Maintenance Corridor" `door_repair` → pick a real room
- Record the mapping in `map_station_layout.md` §1.
- Rewrite §2 (room table), §3 (connectivity + traversal times for the 3×3 grid; at 250 px/s, times ≈ centre-to-centre distance ÷ 250) and §4 (alibi routing) so they describe **the built map**.

**Agent prompt**
```text
Do Step 4. 1) List every location_id / source_system / room name used in shared/blackout_recovery_config.gd, shared/blackout_objective_config.gd, shared/evidence_config.gd, server/evidence_manager.gd and design/specs/*.md that is not a canonical room id (contracts §1.1). Propose a mapping for each, then wait for my decisions. 2) Rewrite design/specs/map_station_layout.md for the built 3x3 map in my guide §3: §1 reconciliation note including the ratified mapping table, §2 room table (rooms -> tasks/recovery/objectives/emergency/meeting button, consistent with shared/station_registry.gd), §3 adjacency + traversal seconds computed as centre-to-centre distance / 250 px/s (show the calculation), §4 alibi routing notes updated. Keep my original design intent where the geometry allows and call out what changed. Draft handoff notes to M2 (catalog ids) and M7 (anchors).
```

---

### Step 5 — Evidence matrix for inspection-based discovery (Wave 1) — decision D7
**Do:** update `evidence_matrix.md` to define:
- which evidence types spawn a world **marker**, at which anchor, and with which M7 sprite;
- what the **inspector** sees (title/description);
- whether recovery "restored" records get markers at all (they carry no attribution; your call);
- the rule "details go only to the inspector; players share them by chat".

Also:
- move the "Reserved evidence types" section to "Post-MVP" unless F9 was kept;
- align the evidence description texts in `EvidenceConfig` (M2 ports them), e.g. "Executive Office" wording.

**Agent prompt**
```text
Do Step 5 (decision D7). Update design/specs/evidence_matrix.md: add a "Discovery model (v1.1)" section: markers appear at POST_BLACKOUT_INVESTIGATION start at StationRegistry.EVIDENCE_ANCHORS[location_id]; markers reveal only evidence_type + location; inspecting (within evidence.inspect_radius_px) reveals display_name + description to the inspector only; nothing is ever auto-broadcast; players share by chat. Add a table: evidence_type -> anchor/location_id -> M7 sprite (from assets/sprites/stations/evidence_*.png; list which exist) -> inspector text. Decide with me whether recovery-restored records get markers. Mark reserved types post-MVP unless decision F9 kept them. List every text change M2 must port into shared/evidence_config.gd.
```

---

### Step 6 — Specs for the new mechanics (Wave 1) — F4, F5, F6, F7
**Do:** add a "Recovery additions (v1.1)" section to `task_specifications.md`:
- **ORION instability:** 0–100. Which objectives add how much, plus blackout seconds. What it changes: meltdown VFX intensity (M7), alarm intensity (M8), a result-screen line (M5). **Never the timer.**
- **Meltdown disruption:** the Impostor holds for 3s at an emergency console → the console is locked for 12s, then a 40s cooldown. What Crew see ("SYSTEM LOCKED"). Is disruption allowed on the last remaining system? (Balance question: probably yes.)
- **Door jams:** 2 random doors jam for the whole blackout; they are closed and can't be opened.
- **Cameras:** the P2 spec, or a descope note.

**Agent prompt**
```text
Do Step 6 (audit F4, F5, F6, F7; decision D11). Add a "Recovery additions (v1.1)" section to design/specs/task_specifications.md specifying, with player-facing wording and numbers matching config/game_balance_config.json: ORION instability (inputs, 0-100 scale, what it affects: VFX/audio/result screen only, never Meltdown duration), Impostor Meltdown disruption (hold time, lock time, cooldown, what Crew see, edge cases: last remaining system, disrupting during a Crew repair in progress, which should be cancelled server-side), door jams (count, duration, visual), and security cameras (P2 spec or a descope note per my Step 1 decision). Update §6 Balance Cross-Reference so the Meltdown budget math includes disruption time: with 3 systems and 12s locks every 40s, show the worst case still leaves Crew a winnable window.
```

---

### Step 7 — Reconcile docs; delete duplicates (Wave 1) — R3
**Do**
- **`design.md`:**
  - §3.2 Impostor cover tasks reuse the Crew catalog;
  - §3.5.3 file theft is in the Executive Office;
  - §3.6/§7 evidence discovery by inspection;
  - §3.7 the meeting button + investigation timer;
  - §3.10 disruption;
  - §6.3 module list → the real flat layout.
- **`PRD.md`:** the FR notes for FR-13/25/30/31/37 per the ratified decisions; §9 resolutions.
- **`README.md`:**
  - repo links `ABUBAK3R-K/Blackout` → `ABUBAK3R-K/Suspect`;
  - replace the aspirational architecture tree with the real layout (or link `CLAUDE.md`);
  - "no instant kills" stays true if D1 holds.
- `documentation/README.md` links (`prd.md` → `PRD.md`, etc.).
- Delete `design (1).md` and `PRD (1).md` (identical copies).

**Agent prompt**
```text
Do Step 7 (audit R3). Reconcile design.md, PRD.md and README.md with the ratified decisions and my updated specs, as listed in my guide Step 7. Keep the original design voice. Mark each changed paragraph with "(v1.1, 2026-MM-DD)" so reviewers can find them. Fix README repo links to https://github.com/ABUBAK3R-K/Suspect and replace the aspirational architecture tree with the real directory layout (server/, shared/, client/, scenes/, assets/, tests/, docs/, design/, config/). Fix documentation/README.md links (case-sensitive file names). Verify design (1).md and PRD (1).md are byte-identical to design.md and PRD.md before deleting them (git rm). Show me the full diff summary.
```

---

### Step 8 — Review duty (Waves 1–4)
You must approve PRs that touch:
- `config/game_balance_config.json`
- `shared/station_registry.gd`
- `shared/*_config.gd` catalog content
- evidence text or logic
- task/objective/recovery durations
- mini-game durations (M4 Step 8)

Use this prompt on each such PR:
```text
Review PR #<n> (git fetch origin pull/<n>/head:pr-<n>; git diff origin/main...pr-<n>) strictly for design integrity: (1) any balance value, duration, id, room or evidence text that differs from config/game_balance_config.json, shared/station_registry.gd or design/specs/*; (2) any violation of design.md §5 hard rules (earned blackout, single activation, 5-minute Meltdown, no automatic deduction/attribution, the vote doesn't end the match); (3) anything that reveals role or actor identity to clients. List findings with file:line and a suggested fix. Don't post anything; give me the text.
```

---

### Step 9 — Truthful `PROJECT_STATUS.md` (Wave 4, with M8) — R4
**Do**
- Rewrite §1 dashboard and §2 module matrix from **verified** facts: the merged PRs and the real test runner output.
- Fix the duplicate §5 numbering.
- Correct the open-question table (e.g. blackout is 60s, not 90s).
- **Don't edit old §7 entries** (append-only). Instead add a §7 entry "Audit corrections" listing which earlier claims were wrong: the 241 tests, "100% tested", cooldowns, non-existent files.

**Agent prompt**
```text
Do Step 9 (audit R4). Using only verifiable facts (git log origin/main, the real output of tests/run_all_tests.gd that I'll paste, and the current files), rewrite PROJECT_STATUS.md §1 (dashboard) and §2 (module status matrix), renumber the duplicate §5 headings, and correct the §5 open-questions table to match the ratified decisions and the actual config values. Do NOT edit or delete any existing §7 change-log entry; append a new dated §7 entry "Audit corrections" that lists each earlier claim found false in docs/fix-plan/00-audit.md (R4) and what is true now. Show me the diff.
```

---

### Step 10 — Balance review after the playtests (Wave 4)
**Do:** ask M1 (handoff) for a server-side match summary at GAME_OVER, written to `user://match_logs/<timestamp>.json`, with:
- winner and reason
- match length
- blackout duration and how it ended
- recovery count
- objectives completed
- instability
- the vote result
- the disruptions used

After each playtest block, compare against PRD §10 (45–55% Crew win rate, 15–25 min matches) and propose JSON changes, one lever at a time.

**Agent prompt**
```text
Do Step 10. Read the match logs I'll provide (JSON files from user://match_logs/). Produce a table per match and aggregate: Crew win rate, average/median match length, blackout end reason split (timer vs recovery), average objectives completed, average instability, how often the Impostor was ejected, disruptions per Meltdown. Compare to PRD §10 targets (45-55% win rate, 15-25 min). Recommend at most 2 config/game_balance_config.json changes for the next playtest, each with the expected effect and the risk. Don't edit files until I approve.
```

---

## 6. Final review prompt (before every PR)
```text
Review my branch against origin/main: (1) list changed files and confirm all are mine per docs/fix-plan/member-6-game-design.md §1; (2) config/game_balance_config.json parses and every contracts §5 key resolves; (3) shared/station_registry.gd has exactly the §4 API, 23 stations with the §1.2 ids, valid room ids, positions inside room rects with margins, and no logic beyond lookups; (4) design.md/PRD.md/specs don't contradict each other or the contracts (list any contradiction); (5) draft the PR description (template in docs/fix-plan/README.md §5) and the PROJECT_STATUS.md §7 entry.
```
