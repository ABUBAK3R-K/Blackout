# BLACKOUT

> **2D Top-Down Multiplayer Social Deduction & Meltdown Survival Game**  
> Set in the compromised Asterion Research Facility. 7 Crew Members vs. 1 Impostor.

---

## 💡 What is the Game About? (Quick Summary)

> **"Among Us" meets high-stakes survival.**  
> 8 players are working in a compromised research facility: **7 loyal Crew Members** and **1 hidden Impostor**.

- 🛠️ **Crew Members:** Complete daily maintenance tasks to keep the facility running, spot physical clues when things go wrong, discuss and vote out the traitor in emergency meetings, and cooperate to stop a facility meltdown.
- 🕵️ **The Impostor:** Pretends to work normally, unlocks and triggers a facility-wide **Blackout** (killing the lights!), sneaks through the dark to steal classified research files and sabotage the core, and deceives everyone during meetings.
- ⚡ **What makes it unique?**
  - **Pure Social Deduction:** No instant kills and no automated AI lie detectors — catching the traitor depends entirely on player memory, observation, and physical evidence (e.g., missing files, damaged relays).
  - **Two-Stage Climax:** Finding the Impostor is only half the battle; the match ends in a tense 5-minute **Meltdown** where the crew must fix critical systems before the facility is lost!

---

## 📖 Match Flow & Phases

**BLACKOUT** is an 8-player social deduction match structured across 4 distinct phases:

- **Phase 1: Normal Operations** — Crew completes facility tasks; the Impostor completes disguise prerequisite tasks to unlock the remote **Blackout** ability.
- **Phase 2: Blackout Window** — Impostor remotely cuts power and races to complete secret objectives (Classified File Theft, ORION Core sabotage); Crew races to complete distributed recovery systems (`3 of 4`) to restore power early.
- **Phase 3: Investigation & Voting** — Discover physical evidence (missing files, damaged relays, fake repair anomalies), discuss in meetings, and vote to eject suspected players.
- **Phase 4: Meltdown Climax** — A fixed 5-minute emergency countdown begins. If the Impostor escaped ejection, they actively interfere while Crew races to complete 3 emergency systems (Power, Cooling, ORION Stabilization) before the facility is lost.

---

## 👥 8-Member Team Ownership & Dedicated Branches

Each team member has strict, exclusive ownership over their domain. All development must be done on the member's dedicated branch before merging into `main`.

| Member | Assignee | Dedicated Branch | Role / Domain | Key Modules Owned (`design.md` §6.3) |
|---|---|---|---|---|
| **Member 1** | **Mayiz** | [`member-1/backend-network`](https://github.com/ABUBAK3R-K/Blackout/tree/member-1/backend-network) | **Lead Backend & Network Engineer** | `game_state`, `role_manager`, `player` (server), room lifecycle, real-time networking & anti-cheat |
| **Member 2** | **Abdul Qadir** | [`member-2/gameplay-backend`](https://github.com/ABUBAK3R-K/Blackout/tree/member-2/gameplay-backend) | **Gameplay Backend Engineer** | `task_manager`, `blackout_manager`, `blackout_recovery`, `sabotage_manager`, `evidence_manager`, `meeting_manager`, `voting_manager`, `meltdown_manager`, `win_condition_manager` |
| **Member 3** | **Aaliya** | [`member-3/client-engine`](https://github.com/ABUBAK3R-K/Blackout/tree/member-3/client-engine) | **Lead Client & Gameplay Programmer** | `player` (client), `map_manager` (client/rendering), camera, dynamic blackout vision/lighting shader |
| **Member 4** | **Ubaid** | [`member-4/mini-games`](https://github.com/ABUBAK3R-K/Blackout/tree/member-4/mini-games) | **Client Interaction & Mini-Game Programmer** | `crew_tasks` (client), `impostor_tasks` (client), mini-game layer, interactive station inputs |
| **Member 5** | **Shahzan** | [`member-5/ui-frontend`](https://github.com/ABUBAK3R-K/Blackout/tree/member-5/ui-frontend) | **UI/UX Designer & Frontend Programmer** | All `ui/` screens (`role_reveal`, `task_ui`, `blackout_ui`, `timer_ui`, `sabotage_ui`, `meeting_ui`, `voting_ui`, `meltdown_ui`, `result_screen`) |
| **Member 6** | **Abubaker** | [`member-6/game-design`](https://github.com/ABUBAK3R-K/Blackout/tree/member-6/game-design) | **Game Systems & Content Designer** | Task specs, evidence matrices, balance configurations (`config/game_balance_config.json`), facility map flow |
| **Member 7** | **Fatima** | [`member-7/environment-art`](https://github.com/ABUBAK3R-K/Blackout/tree/member-7/environment-art) | **2D Environment & Technical Artist** | 9-room tilemaps, normal vs. emergency lighting assets, character sprite animations, visual FX |
| **Member 8** | **Sahil** | [`member-8/audio-qa`](https://github.com/ABUBAK3R-K/Blackout/tree/member-8/audio-qa) | **Audio Designer & QA / Production Lead** | Ambient audio, blackout tension music, SFX libraries, automated server-authority tests, playtest telemetry |

---

## 🔒 Strict Domain Ownership & Collaboration Rules

1. **Strict Part Isolation:** Each component must be built and maintained **only by its respective assigned member**. Do not make edits to modules owned by another member without direct coordination.
2. **Dedicated Branch Development:** All work should be committed and pushed to your respective `member-*/*` branch first.
3. **Merging to `main`:**
   - Members can push and merge their completed, tested features into `main`.
   - Ensure your code does not break other modules before merging.
   - For backend/win-condition changes, coordinate with **Mayiz (M1)** or **Abdul Qadir (M2)**.
   - For design balance updates, coordinate with **Abubaker (M6)**.

---

## 🛠️ Developer Workflow

### 1. Checkout Your Branch
```bash
# Example for Member 1 (Mayiz):
git checkout member-1/backend-network
git pull origin member-1/backend-network
```

### 2. Work & Commit to Your Branch
```bash
git add .
git commit -m "feat(backend): implement authoritative state machine transitions"
git push origin member-1/backend-network
```

### 3. Sync with `main` and Merge
When your milestone is verified and ready for integration:
```bash
# 1. Update local main
git checkout main
git pull origin main

# 2. Merge your branch into main
git merge member-1/backend-network

# 3. Push to main
git push origin main
```

---

## 📂 Architecture & Module Ownership

```
blackout/
├── server/
│   ├── core/                        # [Member 1 - Mayiz]
│   │   ├── game_state               # Top-level authoritative state machine
│   │   └── role_manager             # Private role assignment & reveals
│   ├── network/                     # [Member 1 - Mayiz]
│   │   ├── room_manager             # 8-player lobby lifecycle
│   │   └── rpc_dispatcher           # Network events & anti-cheat validator
│   └── gameplay/                    # [Member 2 - Abdul Qadir]
│       ├── task_manager             # Task validation backend
│       ├── blackout_manager         # Unlock gate, countdown, timer
│       ├── blackout_recovery        # 3-of-4 recovery system tracking
│       ├── sabotage_manager         # Impostor objective backend & fake repairs
│       ├── evidence_manager         # Discoverable state flags & anomalies
│       ├── meeting_manager          # Discussion trigger & timer
│       ├── voting_manager           # Vote tally & ejection resolution
│       ├── meltdown_manager         # 5-minute emergency timer & tasks
│       └── win_condition_manager    # Victory/Defeat evaluation
│
├── client/
│   ├── player/                      # [Member 3 - Aaliya]
│   │   ├── controller               # 2D top-down movement & collisions
│   │   └── state_sync               # Client prediction & server reconciliation
│   ├── rendering/                   # [Member 3 - Aaliya]
│   │   └── vision_system            # Blackout vision-cone shader & lighting
│   ├── interactions/                # [Member 4 - Ubaid]
│   │   ├── mini_games/              # Crew & Meltdown mini-game inputs
│   │   └── sabotage_interactions/   # File theft & Core terminal mini-games
│   ├── ui/                          # [Member 5 - Shahzan]
│   │   ├── hud/                     # In-game HUD, task lists, timers
│   │   ├── meeting/                 # Discussion chat & voting grid
│   │   └── screens/                 # Role reveal, lobby, meltdown, results
│   └── audio/                       # [Member 8 - Sahil]
│       └── audio_manager            # Sound triggers & ambient cross-fading
│
├── design/                          # [Member 6 - Abubaker]
│   ├── specs/                       # Task, evidence & layout specs
│   └── config/                      # game_balance_config.json
│
├── assets/
│   ├── sprites/                     # [Member 7 - Fatima]
│   │   ├── environment/             # 9-room tilemaps & interactable props
│   │   ├── lighting/                # Normal vs. Emergency blackout variants
│   │   └── characters/              # 2D character sheets & animations
│   ├── vfx/                         # [Member 7 - Fatima]
│   └── audio/                       # [Member 8 - Sahil]
│       ├── music/                   # Facility hum & Meltdown tension loops
│       └── sfx/                     # Sabotage, alarms, task & UI cues
│
└── tests/                           # [Member 8 - Sahil]
    ├── server_authority_tests/      # Anti-cheat & state verification
    └── playtest_checklists/         # 8-player playtest rubrics
```

---

## 📚 Companion Documents

- 📄 **[PRD (Product Requirements Document)](./PRD.md)** — Requirements, functional specifications, and MVP definition of done.
- 📐 **[Design Document](./design.md)** — Technical architecture, state machine, phase mechanics, and design constraints.
- 📋 **[Team Split & Ownership](./TEAM_SPLIT.md)** — Detailed role deliverables, collaboration pairings, and sprint roadmap.
- 📊 **[Project Status & Change Log](./PROJECT_STATUS.md)** — Live tracking of sprint milestones, module status, and team change history.

