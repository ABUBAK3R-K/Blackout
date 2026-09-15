# WHO'S THE IMPOSTOR?

## 8-Member Team Split & Branch Ownership

This document is the team's implementation contract.

------------------------------------------------------------------------

# Team Structure

The project is divided into 8 independently owned feature areas.

  ----------------------------------------------------------------------------
  Member                             Branch                       Ownership
  ---------------------------------- ---------------------------- -----------------------
  Mayiz (Member 1)                   `feature/game-engine`        Core game engine

  Abdul Qadir (Member 2)             `feature/realtime-backend`   Multiplayer +
                                                                  WebSockets

  Aaliya (Member 3)                  `feature/frontend-game`      UI + game client

  Ubaid (Member 4)                   `feature/tasks-incidents`    Tasks + incidents +
                                                                  voting

  Shahzan (Member 5)                 `feature/nlp`                Chat NLP + behavioral
                                                                  text features

  Abubaker (Member 6)                `feature/ml-suspicion`       ML suspicion engine

  Fatima (Member 7)                  `feature/ai-gamemaster`      AI Game Master

  Sahil (Member 8)                   `feature/analytics-replay`   Analytics + replay +
                                                                  dashboards
  ----------------------------------------------------------------------------

------------------------------------------------------------------------

# MEMBER 1 (MAYIZ) --- GAME ENGINE

## Branch

`feature/game-engine`

## Mission

Build the authoritative core game-state machine.

## Responsibilities

-   Match lifecycle
-   Round lifecycle
-   Role assignment
-   Player states
-   Win conditions
-   Game timers
-   Game configuration
-   Server-side game state
-   State transitions

## Core States

``` text
WAITING
↓
STARTING
↓
ROLE_ASSIGNMENT
↓
TASK_PHASE
↓
INCIDENT
↓
DISCUSSION
↓
VOTING
↓
ROUND_RESULT
↓
NEXT_ROUND / GAME_OVER
```

## Data Owned

``` text
GameState
Match
Round
PlayerState
Role
GameConfig
```

## APIs / Interfaces

Example:

``` text
createMatch()
startMatch()
startRound()
endRound()
eliminatePlayer()
checkWinCondition()
getGameState()
```

## Must Provide

-   Game-state interface
-   Role-assignment interface
-   Win-condition interface
-   Events consumed/emitted by other modules

## Do NOT Own

-   Frontend
-   NLP
-   ML
-   AI-generated events

## Done When

A game can start, run through rounds, eliminate players, and end
correctly without UI dependency.

------------------------------------------------------------------------

# MEMBER 2 (ABDUL QADIR) --- REAL-TIME BACKEND

## Branch

`feature/realtime-backend`

## Mission

Build multiplayer synchronization infrastructure.

## Responsibilities

-   WebSocket server
-   Room management
-   Join/leave
-   Reconnection
-   State broadcasting
-   Server/client event protocol
-   Authentication for sockets

## WebSocket Events

``` text
room:join
room:leave
player:move
game:start
task:update
incident:created
meeting:start
vote:cast
game:state
game:error
```

## Important Rule

The server is authoritative.

Never trust:

``` text
client → "I completed task"
```

without validation by the server/game engine.

## Done When

8 players can connect to one room and receive synchronized game events.

------------------------------------------------------------------------

# MEMBER 3 (AALIYA) --- FRONTEND / GAME CLIENT

## Branch

`feature/frontend-game`

## Mission

Build the complete player-facing game interface.

## Responsibilities

-   Landing page
-   Create/join room
-   Lobby
-   Game HUD
-   Map
-   Player representation
-   Task UI
-   Chat UI
-   Meeting UI
-   Voting UI
-   Results UI

## Suggested Stack

``` text
React
Tailwind
Phaser or Three.js
Socket.IO client
```

## Component Ownership

``` text
GameMap
Player
PlayerList
TaskPanel
ChatPanel
MeetingPanel
VotingPanel
Timer
EventFeed
ResultScreen
```

## Important

Do not implement game rules in the frontend.

Frontend sends actions; backend validates them.

## Done When

A player can complete a full match through the UI.

------------------------------------------------------------------------

# MEMBER 4 (UBAID) --- TASKS, INCIDENTS & VOTING

## Branch

`feature/tasks-incidents`

## Mission

Build the actual game mechanics that create evidence for the AI.

## Responsibilities

### Tasks

-   Task assignment
-   Task validation
-   Task completion
-   Task timers
-   Task difficulty
-   Task events

### Incidents

-   Sabotage
-   Power failure
-   Missing object
-   Emergency
-   Player elimination
-   Incident timestamps/location

### Voting

-   Start vote
-   Submit vote
-   Validate vote
-   Count votes
-   Handle ties
-   Record vote history

## Example Tasks

``` text
Decode Signal
Repair Generator
Find Missing File
Restore Network
Match Symbols
```

## Data

``` text
Task
TaskAssignment
Incident
Vote
```

## Done When

Gameplay produces enough structured events for analytics and ML.

------------------------------------------------------------------------

# MEMBER 5 (SHAHZAN) --- NLP & COMMUNICATION INTELLIGENCE

## Branch

`feature/nlp`

## Mission

Analyze player communication without claiming to detect lies.

## Responsibilities

-   Chat ingestion
-   Text preprocessing
-   Sentiment analysis
-   Accusation detection
-   Defense detection
-   Claim extraction
-   Question detection
-   Potential contradiction detection
-   Communication features

## Example

Input:

``` text
"I was in the lab."
```

Output:

``` json
{
  "type": "claim",
  "subject": "player",
  "location": "lab",
  "confidence": 0.91
}
```

Later:

``` text
"I was near storage."
```

System may produce:

``` text
Potential statement inconsistency.
```

## Feature Output

``` text
accusation_count
defense_count
claim_count
question_count
sentiment_score
contradiction_count
message_frequency
```

## API

``` text
POST /nlp/analyze-message
POST /nlp/analyze-batch
```

## Done When

Messages can be converted into structured behavioral features consumed
by the ML service.

------------------------------------------------------------------------

# MEMBER 6 (ABUBAKER) --- ML SUSPICION ENGINE

## Branch

`feature/ml-suspicion`

## Mission

Build the project's main machine-learning component.

## Responsibilities

-   Dataset creation
-   Feature engineering
-   Baseline models
-   Model training
-   Model evaluation
-   Prediction API
-   Suspicion score
-   Explainability

## Input Features

``` text
task_completion_rate
task_duration
task_failure_rate
incident_proximity
vote_switch_rate
vote_consistency
accusation_count
defense_count
communication_frequency
contradiction_count
meeting_participation
social_interaction_count
```

## Model Pipeline

``` text
Game Events
    ↓
Feature Builder
    ↓
Feature Vector
    ↓
ML Model
    ↓
Impostor Probability
    ↓
Suspicion Score
```

## Models

Start with:

``` text
Logistic Regression
Random Forest
```

Then experiment with:

``` text
XGBoost
Neural Network
GNN
```

## Evaluation

Record:

``` text
Accuracy
Precision
Recall
F1
ROC-AUC
Confusion Matrix
```

## Important

The model predicts probability.

It must NOT output:

``` text
"Player 3 is definitely lying."
```

Prefer:

``` text
"Player 3 has an 82% model-based suspicion score based on current gameplay evidence."
```

## Done When

A match can send structured player features to the model and receive a
prediction.

------------------------------------------------------------------------

# MEMBER 7 (FATIMA) --- AI GAME MASTER

## Branch

`feature/ai-gamemaster`

## Mission

Build the AI system that dynamically creates contextual events and
narrative.

## Responsibilities

-   Event generation
-   Clue generation
-   Narrative generation
-   Difficulty suggestions
-   Prompt engineering
-   Structured LLM output
-   Validation layer

## Input

``` text
round_number
remaining_players
recent_incidents
completed_tasks
game_time
difficulty
```

## Output

Example:

``` json
{
  "event_type": "POWER_FAILURE",
  "title": "Grid Failure",
  "duration": 90,
  "location": "main_block",
  "description": "The main grid has failed."
}
```

## Critical Architecture

``` text
LLM
 ↓
Structured Output
 ↓
Validator
 ↓
Game Rules
 ↓
Game Engine
```

The LLM must never directly control the game.

## Future Features

-   AI-generated clues
-   Adaptive difficulty
-   Narrative mode
-   Dynamic tasks
-   Game-master commentary

## Done When

AI can generate valid contextual events that pass the game's rule
validator.

------------------------------------------------------------------------

# MEMBER 8 (SAHIL) --- ANALYTICS & REPLAY

## Branch

`feature/analytics-replay`

## Mission

Turn raw game events into useful visual intelligence.

## Responsibilities

### Match Dashboard

-   Match duration
-   Winner
-   Incidents
-   Votes
-   Tasks
-   Eliminations

### Player Analytics

-   Task performance
-   Suspicion trend
-   Voting behavior
-   Communication volume
-   Movement patterns

### Social Graph

Display:

``` text
Player A → Player B
Player B → Player C
Player A ↔ Player D
```

Based on communication/voting/interactions.

### Replay

Create chronological timeline:

``` text
00:12 P3 enters Lab
00:24 Power failure
00:31 P7 eliminated
00:43 P3 leaves Lab
01:02 P3 accuses P5
01:40 P3 changes vote
```

### Model Dashboard

Show:

``` text
Accuracy
Precision
Recall
F1
ROC-AUC
```

## Done When

A completed match can be replayed and analyzed visually.

------------------------------------------------------------------------

# SHARED CONTRACTS

These must be agreed upon BEFORE parallel development.

## Player

``` json
{
  "id": "p1",
  "displayName": "Player 1",
  "alive": true
}
```

Never expose hidden role to unauthorized clients.

------------------------------------------------------------------------

## Game Event

``` json
{
  "event_id": "evt_001",
  "match_id": "match_01",
  "player_id": "p3",
  "event_type": "TASK_COMPLETED",
  "timestamp": "ISO-8601",
  "location": "lab",
  "metadata": {}
}
```

------------------------------------------------------------------------

## Suspicion Response

``` json
{
  "player_id": "p3",
  "score": 0.82,
  "confidence": 0.74,
  "evidence": [
    {
      "type": "incident_proximity",
      "strength": "high"
    }
  ]
}
```

------------------------------------------------------------------------

# BRANCH DEPENDENCIES

``` text
                    GAME ENGINE
                         │
               ┌─────────┴─────────┐
               │                   │
        REALTIME BACKEND      TASKS/INCIDENTS
               │                   │
               └─────────┬─────────┘
                         │
                   FRONTEND GAME
                         │
                         ▼
                    EVENT LOG
                         │
             ┌───────────┼───────────┐
             ▼           ▼           ▼
            NLP         ML       ANALYTICS
                         │
                         ▼
                    AI GAME MASTER
```

------------------------------------------------------------------------

# RECOMMENDED WORK ORDER

## Sprint 0 --- Foundation

Everyone agrees on: - Repo structure - Coding standards - API
contracts - Event schema - Database schema - Environment variables

Mayiz (Member 1), Abdul Qadir (Member 2), and Aaliya (Member 3) establish the base architecture.

------------------------------------------------------------------------

## Sprint 1 --- Playable Prototype

Goal:

> Two or more players can join a room and play a minimal game.

Priority: 1. Game Engine 2. WebSocket 3. Frontend 4. Basic tasks/voting

------------------------------------------------------------------------

## Sprint 2 --- Complete Game Loop

Add: - 6--10 players - Tasks - Incidents - Meetings - Voting - Win
conditions

------------------------------------------------------------------------

## Sprint 3 --- Data Collection

Add event logging for:

``` text
Movement
Tasks
Chat
Votes
Incidents
Meetings
Eliminations
```

------------------------------------------------------------------------

## Sprint 4 --- AI

NLP → ML → Suspicion engine.

------------------------------------------------------------------------

## Sprint 5 --- Advanced AI

AI Game Master.

------------------------------------------------------------------------

## Sprint 6 --- Analytics

Replay + dashboards + social graph.

------------------------------------------------------------------------

## Sprint 7 --- Integration

Full end-to-end testing.

------------------------------------------------------------------------

# GIT RULES

## Main branches

``` text
main
develop
```

## Feature branches

``` text
feature/game-engine
feature/realtime-backend
feature/frontend-game
feature/tasks-incidents
feature/nlp
feature/ml-suspicion
feature/ai-gamemaster
feature/analytics-replay
```

### Rules

-   No direct pushes to `main`.
-   Pull requests target `develop`.
-   PRs require review.
-   Rebase/merge from `develop` regularly.
-   Do not modify another person's module without discussion.
-   Shared contracts require team approval.
-   Never commit `.env`.
-   Never commit API keys.
-   Every feature should have tests where practical.

------------------------------------------------------------------------

# PULL REQUEST TEMPLATE

## What changed?

Describe the feature.

## Why?

Explain the purpose.

## Testing

-   [ ] Unit tests
-   [ ] Integration test
-   [ ] Manual test

## API Changes

List changed endpoints/events.

## Database Changes

List schema changes.

## Screenshots

Add screenshots for UI changes.

## Breaking Changes

Mention any breaking change.

------------------------------------------------------------------------

# FINAL INTEGRATION CHECKLIST

### Core Game

-   [ ] Lobby works
-   [ ] Roles are secure
-   [ ] Game state synchronizes
-   [ ] Tasks work
-   [ ] Incidents work
-   [ ] Voting works
-   [ ] Win conditions work

### AI

-   [ ] Events are logged
-   [ ] NLP works
-   [ ] Features are generated
-   [ ] ML model predicts
-   [ ] Suspicion is explainable
-   [ ] AI Game Master outputs are validated

### Analytics

-   [ ] Match dashboard
-   [ ] Player analytics
-   [ ] Social graph
-   [ ] Replay
-   [ ] Model metrics

### Engineering

-   [ ] Authentication
-   [ ] Error handling
-   [ ] Security checks
-   [ ] Database migrations
-   [ ] Docker setup
-   [ ] Deployment
-   [ ] Documentation

------------------------------------------------------------------------

# TEAM PRINCIPLE

Each member owns a feature.

But the team owns the product.

Do not optimize for:

> "My branch works."

Optimize for:

> "My branch integrates cleanly with the other seven branches."

The final demonstration should feel like **one coherent product**, not
eight separate college projects.
