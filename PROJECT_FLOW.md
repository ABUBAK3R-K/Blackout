# WHO'S THE IMPOSTOR? — Seamless Project Execution & Flow Guide

## Document Overview
This document outlines the **exact chronological execution order, inter-member handoffs, dependency chains, and parallel workflows** for the 8-member team to build, integrate, and ship *Who's the Impostor?* without merge conflicts or blocking bottlenecks.

---

## 1. Team & Branch Ownership Matrix

| Member | Branch Name | Core Role / Ownership | Tech Stack | Primary Directory |
| :--- | :--- | :--- | :--- | :--- |
| **Member 1** | `feature/game-engine` | Core Game State Machine & Rules | Node.js / TypeScript | `server/src/game/` |
| **Member 2** | `feature/realtime-backend` | WebSocket Server & Room Management | Socket.IO / Express | `server/src/websocket/`, `server/src/lobby/` |
| **Member 3** | `feature/frontend-game` | Player UI, Lobby & Interactive Game HUD | React / Tailwind / Phaser or Canvas | `client/src/` |
| **Member 4** | `feature/tasks-incidents` | Tasks, Sabotage Incidents & Voting Rules | Node.js / TypeScript | `server/src/tasks/`, `server/src/incidents/`, `server/src/voting/` |
| **Member 5** | `feature/nlp` | Chat Communication Intelligence & NLP | Python / FastAPI / NLTK / Transformers | `ai-service/nlp/` |
| **Member 6** | `feature/ml-suspicion` | ML Suspicion Engine & Feature Engineering | Python / scikit-learn / XGBoost / FastAPI | `ai-service/models/`, `ai-service/features/` |
| **Member 7** | `feature/ai-gamemaster` | AI Game Master & Dynamic Narrative/Events | Python / LLM API (OpenRouter) / Pydantic | `ai-service/game_master/` |
| **Member 8** | `feature/analytics-replay` | Analytics Dashboard, Replay & Social Graph | React / Recharts / D3 / PostgreSQL / Node | `client/src/analytics/`, `server/src/analytics/` |

---

## 2. Master Dependency Graph & Critical Path

```text
========================================================================================
[ PHASE 0: FOUNDATION & CONTRACT FREEZE ] (All Members — Freeze Schemas, Repo Structure)
========================================================================================
                                     │
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
    [ MEMBER 1: Game Engine ]               [ MEMBER 2: Real-time Backend ]
    (State Machine & Game Rules)            (Socket.IO & Room Management)
                 │                                       │
                 └───────────────────┬───────────────────┘
                                     │ (Core Server Synchronized)
                 ┌───────────────────┴───────────────────┐
                 ▼                                       ▼
    [ MEMBER 4: Tasks, Incidents & Voting ]  [ MEMBER 3: Frontend Client ]
    (Mechanics, Sabotage, Vote Logic)        (UI, HUD, Canvas Map, Chat UI)
                 │                                       │
                 └───────────────────┬───────────────────┘
                                     │ (Full Playable Prototype & Telemetry)
                                     ▼
                      [ SHARED TELEMETRY & EVENT LOG ]
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          ▼                          ▼                          ▼
[ MEMBER 5: NLP Chat ]    [ MEMBER 6: ML Suspicion ]   [ MEMBER 8: Analytics & Replay ]
(Text Feature Extraction) (Model Training & Inference) (Dashboards, Timeline, Graph)
          │                          ▲
          └──────────────────────────┘ (NLP Features feed into ML)
                                     │
                                     ▼
                       [ MEMBER 7: AI Game Master ]
                       (Contextual LLM Events & Validation)
                                     │
========================================================================================
[ PHASE 8: FINAL INTEGRATION & DEMO POLISH ] (All Members — End-to-End Match Validation)
========================================================================================
```

---

## 3. Step-by-Step Execution Sequence

### Phase 0: Project Setup & Contract Agreement (Day 1)
**Goal:** Establish repository directory structure, package managers, and freeze data contracts so everyone can develop in parallel using mocks.

1. **Lead Action (Member 1 & 2):** Initialize project structure:
   ```text
   Suspect/
   ├── client/          (React + Tailwind frontend)
   ├── server/          (Node.js + Express + Socket.IO)
   ├── ai-service/      (Python FastAPI + ML/NLP)
   ├── shared/          (Shared JSON schemas / TypeScript types)
   ```
2. **Team Action:** Review and lock the core JSON contracts in [TEAM_SPLIT.md](file:///e:/projects/Suspect/TEAM_SPLIT.md#L641-L690):
   - `Player` schema (IDs, display names, alive status).
   - `GameEvent` schema (event_id, timestamp, location, event_type, metadata).
   - WebSocket event names list (`room:join`, `game:start`, `task:update`, `vote:cast`, etc.).
   - REST endpoints for AI Service (`/nlp/analyze-message`, `/suspicion/predict`, `/game-master/event`).

---

### Phase 1: Core Engine & Multiplayer Backbone (Sprint 1)
**Primary Members:** **Member 1** & **Member 2** (In close sync)  
*Members 3, 4, 5, 6, 7, 8 build their sub-modules using mocked interfaces.*

* **Member 1 (`feature/game-engine`):**
  - Implement the authoritative state machine: `WAITING -> STARTING -> ROLE_ASSIGNMENT -> TASK_PHASE -> INCIDENT -> DISCUSSION -> VOTING -> ROUND_RESULT -> GAME_OVER`.
  - Implement role assignment (Citizen vs Impostor) ensuring **roles are strictly server-side secret**.
  - Provide pure functions: `createMatch()`, `startRound()`, `eliminatePlayer()`, `checkWinCondition()`, `getGameState()`.
* **Member 2 (`feature/realtime-backend`):**
  - Implement Express server + Socket.IO server.
  - Implement room creation with 6-character room codes, join/leave, disconnect/reconnect logic.
  - Plug Member 1's game engine into socket event handlers.
  - Ensure state broadcasting emits sanitized state (never leak hidden roles!).
* **Integration Milestone 1:** Run automated headless test: 4 socket clients join a room, game starts, state transitions from `STARTING` to `TASK_PHASE`.

---

### Phase 2: Gameplay Mechanics & Player UI (Sprint 2)
**Primary Members:** **Member 4** & **Member 3**  
*Dependencies: Phase 1 backend engine.*

* **Member 4 (`feature/tasks-incidents`):**
  - Implement task assignment (e.g. "Repair Generator", "Decode Signal", "Restore Network").
  - Implement task verification & timer mechanics on the server.
  - Implement sabotage incidents (e.g. "Power Failure", "Oxygen Depletion") triggered by impostor.
  - Implement voting engine: vote collection, tie resolution, vote history recording.
  - Expose task and incident events to Member 1's engine and Member 2's socket broadcaster.
* **Member 3 (`feature/frontend-game`):**
  - Build Landing page, Lobby UI (room code, player list, Ready button).
  - Build Game HUD: interactive 2D map/canvas, player movement controls, objective tracker.
  - Build Meeting UI & Voting screen (display active players, vote buttons, results display).
  - Connect client to Socket.IO backend events from Member 2.
* **Integration Milestone 2 (First Playable Game Loop):** 4 to 8 players can open browsers, join a lobby, walk around map, complete tasks, trigger sabotage, hold emergency meeting, vote out a player, and trigger win/loss screen.

---

### Phase 3: Telemetry & Event Logging Infrastructure (Sprint 3)
**Primary Members:** **Member 1**, **Member 2**, **Member 8**  
*Goal: Provide structured data pipeline for AI and Analytics.*

* **Member 2 & 1:**
  - Build the centralized `EventLogger` module in the server.
  - Every game action (`PLAYER_MOVED`, `TASK_COMPLETED`, `INCIDENT_CREATED`, `CHAT_MESSAGE`, `VOTE_CAST`, `PLAYER_ELIMINATED`) writes an immutable `GameEvent` to database (PostgreSQL/SQLite) or JSON match log.
* **Member 8 (`feature/analytics-replay`):**
  - Design the database schema and read queries for match logs.
  - Ensure telemetry captures timestamps, player IDs, and spatial locations.
* **Integration Milestone 3:** A completed match produces an exportable `match_<id>_events.json` log with 100% structured events.

---

### Phase 4: AI & ML Behavioral Intelligence Layer (Sprint 4)
**Primary Members:** **Member 5** & **Member 6** (Parallel Execution)  
*Input: Gameplay telemetry from Phase 3.*

* **Member 5 (`feature/nlp`):**
  - Set up Python FastAPI microservice (`ai-service/`).
  - Implement chat ingestion endpoints (`POST /nlp/analyze-message`, `POST /nlp/analyze-batch`).
  - Extract NLP features: accusation detection, defense detection, claim extraction (location/activity), question count, sentiment score, and contradiction flags.
  - Return structured communication vector per player.
* **Member 6 (`feature/ml-suspicion`):**
  - Build feature engineering pipeline aggregating:
    - In-game telemetry (task completion rate, task duration, incident proximity score, vote changes).
    - NLP communication features from Member 5.
  - Train baseline models (Random Forest, Logistic Regression) & advanced model (XGBoost / GNN).
  - Expose inference API (`POST /suspicion/predict`) returning suspicion probability score (0.00 – 1.00), confidence level, and explainable feature contributions.
* **Integration Milestone 4:** The game server sends match data to `ai-service`, receiving real-time suspicion scores and post-round evidence for each player.

---

### Phase 5: Narrative & Dynamic Events — AI Game Master (Sprint 5)
**Primary Member:** **Member 7** (`feature/ai-gamemaster`)  
*Dependencies: Game telemetry (Phase 3) + Game rules (Phase 1 & 4).*

* **Member 7:**
  - Connect LLM API (OpenRouter / Gemini / Claude) with strictly typed Pydantic output schemas.
  - Ingest match context: round number, remaining players, recent incidents, completed tasks, pacing.
  - Implement **Rule Validation Layer**: sanitize and validate all LLM suggestions against game rules before returning.
  - Expose API (`POST /game-master/event`) returning dynamic clues, flavor narrative, and contextual sabotage events.
* **Integration Milestone 5:** During a match, the AI Game Master dynamically broadcasts a narrative event (e.g. "Main grid malfunction in Lab") that passes server validation and triggers in the game.

---

### Phase 6: Visual Analytics & Match Replay (Sprint 6)
**Primary Member:** **Member 8** (`feature/analytics-replay`)  
*Dependencies: Event logs (Phase 3), ML metrics (Phase 4), Frontend theme (Phase 2).*

* **Member 8:**
  - Build post-game **Match Dashboard**: win/loss summary, timeline duration, tasks completed, incident breakdown.
  - Build **Interactive Replay**: scrubber timeline allowing users to step through match events minute-by-minute with player locations on map.
  - Build **Social Graph Visualization**: interactive graph showing interaction frequency, accusations, and voting patterns between players.
  - Build **ML Model Evaluation Dashboard**: display model accuracy, precision, recall, F1, ROC-AUC curves, and confusion matrix.
* **Integration Milestone 6:** At match conclusion, players can click "View Match Analytics" and inspect the interactive replay timeline, social graph, and suspicion analysis.

---

### Phase 7: Full System Integration, Hardening & Polishing (Sprint 7)
**All Team Members (Led by Members 1, 2, 3)**

* **Integration Step 1:** Merge all feature branches into `develop` in sequential order (see Section 4).
* **Integration Step 2:** Conduct live 8-player stress tests:
  - Check for desync / reconnection handling.
  - Validate that hidden roles are never leaked in network tabs.
  - Verify AI microservice response latency does not freeze the game loop.
* **Integration Step 3:** Final merge of `develop` into `main` for release and final project demonstration.

---

## 4. Step-by-Step Merge Order into `develop`

To prevent merge conflicts, PRs should be merged into `develop` in the following strict order:

```text
1. Phase 0: Shared boilerplate & contracts  ──► develop
2. Member 1: feature/game-engine             ──► develop
3. Member 2: feature/realtime-backend        ──► develop (rebase on Member 1)
4. Member 4: feature/tasks-incidents         ──► develop (rebase on 1 & 2)
5. Member 3: feature/frontend-game           ──► develop (connects to 1, 2, 4)
6. Member 5: feature/nlp                     ──► develop (independent ai-service/)
7. Member 6: feature/ml-suspicion            ──► develop (integrates with NLP)
8. Member 7: feature/ai-gamemaster           ──► develop (integrates with backend/AI)
9. Member 8: feature/analytics-replay        ──► develop (visualizes full stack)
10. Final Release: develop                   ──► main
```

---

## 5. Parallel Development: The "Mock First" Strategy

To ensure no member is blocked waiting for another member:

1. **Member 3 (Frontend)** does not wait for Member 2 (Sockets):
   - Member 3 uses a local mock event dispatcher emitting simulated socket events (`game:state`, `task:update`).
2. **Member 6 (ML)** does not wait for Member 5 (NLP) or live games:
   - Member 6 generates synthetic feature CSVs/JSON logs to train models and build the inference pipeline immediately.
3. **Member 7 (Game Master)** does not wait for the live server:
   - Member 7 tests LLM prompts and validation logic against static mock match states (`mock_match_state.json`).
4. **Member 8 (Analytics)** does not wait for real matches:
   - Member 8 writes mock match event logs (`events_sample.json`) to develop the replay UI and charts.

---

## 6. Golden Rules for Seamless Execution

1. **The Server is Authoritative:** Never calculate win conditions, validate tasks, or process votes on the client. The client is a view and input emitter only.
2. **Never Commit Secrets:** Use `.env.example`. Never commit actual API keys or credentials.
3. **Keep Shared Contracts Immutable:** If an event name, payload, or API schema must change, discuss with the affected members and update the shared contract before changing code.
4. **Pull `develop` Daily:** Run `git checkout <your-branch> && git pull origin develop` regularly to prevent huge merge conflicts later.
5. **No Direct Pushes to `main`:** All work happens on feature branches, is reviewed via PR to `develop`, and only tagged releases are merged into `main`.
