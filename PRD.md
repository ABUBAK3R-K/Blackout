# WHO'S THE IMPOSTOR?

## Product Requirements Document (PRD)

**Project Type:** B.Tech Main / Final-Year Project\
**Team Size:** 8 members\
**Category:** Multiplayer Game + AI/ML + Behavioral Analytics\
**Status:** Proposed MVP + Advanced Research Features

------------------------------------------------------------------------

## 1. Product Vision

WHO'S THE IMPOSTOR? is a multiplayer social-deduction game in which
players complete objectives, communicate, investigate incidents, and
vote to identify a hidden Impostor.

The distinguishing feature is an AI/ML behavioral intelligence layer
that analyzes structured gameplay data and communication patterns to
generate dynamic suspicion scores and post-game explanations.

The system should feel like a fun multiplayer game while also
functioning as a research-oriented platform for studying behavioral
patterns under uncertainty.

### Core principle

The AI provides **evidence and suspicion**, not a definitive lie
detector.

------------------------------------------------------------------------

## 2. Problem Statement

Traditional social-deduction games depend entirely on human observation.
They rarely provide meaningful analysis of why a player appeared
suspicious or how voting and communication patterns influenced the
outcome.

This project aims to build a platform that:

-   Supports real-time multiplayer social deduction.
-   Collects structured gameplay events.
-   Analyzes communication and behavioral features.
-   Produces dynamic suspicion scores.
-   Provides explainable post-game analysis.
-   Allows future experimentation with ML and graph-based models.

------------------------------------------------------------------------

## 3. Objectives

1.  Build a stable real-time multiplayer game.
2.  Implement hidden-role game mechanics.
3.  Build multiple interactive tasks and investigation events.
4.  Collect gameplay telemetry.
5.  Extract behavioral features from gameplay.
6.  Analyze text communication using NLP.
7.  Train/evaluate an ML-based suspicion model.
8.  Build an AI Game Master for dynamic events.
9.  Provide an analytics and replay system.
10. Demonstrate measurable AI performance using real or simulated game
    data.

------------------------------------------------------------------------

## 4. Target Users

### Players

College students and casual gamers who want short multiplayer
social-deduction games.

### Game Hosts/Admins

Users who create rooms, configure game settings, and view match
analytics.

### Researchers/Project Evaluators

Users interested in behavioral modeling, explainable AI, and game
analytics.

------------------------------------------------------------------------

## 5. Core Gameplay

### Lobby

-   Create room
-   Join room using room code
-   Configure player count
-   Configure round duration
-   Start game

### Role Assignment

Possible roles for MVP: - Citizen - Impostor

Future roles: - Investigator - Medic - Hacker - Mimic

### Game Loop

``` text
Lobby
  ↓
Role Assignment
  ↓
Task Phase
  ↓
Incident / Sabotage
  ↓
Discussion
  ↓
Investigation
  ↓
Voting
  ↓
Continue / End
  ↓
AI Post-Game Analysis
```

### Win Conditions

Citizens win when: - The Impostor is correctly eliminated, or - All
required citizen objectives are completed.

Impostor wins when: - The Impostor survives until the configured end
condition, or - Citizen objectives fail due to sabotage.

------------------------------------------------------------------------

## 6. Functional Requirements

### FR-01 Authentication

-   Register/login
-   Guest mode for quick games
-   Unique player ID

### FR-02 Lobby

-   Create/join room
-   Room code
-   Ready state
-   Player list
-   Host controls

### FR-03 Real-Time Gameplay

-   Synchronize player states
-   Handle movement/actions
-   Broadcast events
-   Maintain authoritative server state

### FR-04 Tasks

-   Task assignment
-   Task completion
-   Task timers
-   Success/failure tracking

### FR-05 Incidents

-   Server-generated incidents
-   Impostor sabotage
-   Incident timestamps
-   Incident location

### FR-06 Communication

-   In-game text chat
-   Meeting discussion
-   Message timestamps
-   Player association

### FR-07 Voting

-   Start voting
-   Anonymous/public configuration
-   Vote submission
-   Vote results
-   Vote history

### FR-08 Behavioral Analytics

Track: - Movement - Task completion - Task duration - Incident
proximity - Votes - Vote changes - Accusations - Defenses -
Communication volume - Contradiction candidates

### FR-09 Suspicion Engine

Generate: - Player suspicion score - Feature-level evidence -
Confidence/uncertainty - Historical suspicion trend

### FR-10 AI Game Master

-   Generate contextual events
-   Generate optional clues
-   Adjust event difficulty
-   Produce narrative text

### FR-11 Replay

-   Timeline of important events
-   Player actions
-   Votes
-   Incidents
-   AI explanations

### FR-12 Analytics Dashboard

-   Match statistics
-   Player statistics
-   Model metrics
-   Suspicion trends
-   Voting graph
-   Game outcome analysis

------------------------------------------------------------------------

## 7. AI/ML Requirements

### Behavioral Feature Engineering

Example features:

-   task_completion_rate
-   average_task_duration
-   task_failure_rate
-   movement_entropy
-   incident_proximity_score
-   accusation_count
-   defense_count
-   vote_switch_rate
-   vote_consistency
-   communication_frequency
-   contradiction_count
-   meeting_participation
-   social_interaction_count

### ML Pipeline

``` text
Gameplay Events
      ↓
Data Collection
      ↓
Feature Engineering
      ↓
Training Dataset
      ↓
ML Model
      ↓
Player Suspicion Probability
      ↓
Explainable Evidence
```

### Candidate Models

Baseline: - Logistic Regression - Random Forest

Advanced: - XGBoost - Gradient Boosting - Neural Network

Research extension: - Graph Neural Network over player
interaction/voting graphs.

### Evaluation

Measure: - Accuracy - Precision - Recall - F1-score - ROC-AUC -
Confusion matrix

Compare: 1. Behavioral features only. 2. Behavioral + NLP features. 3.
Behavioral + NLP + social graph features.

------------------------------------------------------------------------

## 8. NLP Requirements

The NLP service should identify signals such as:

-   Accusations
-   Defenses
-   Questions
-   Claims
-   Topic changes
-   Potentially conflicting statements
-   Sentiment/emotional tone

The system must NOT claim to reliably detect lies.

Example:

> Player 3 first claims they were in the lab and later claims they were
> in storage.

System output:

``` text
Potential statement inconsistency detected.
Evidence strength: Medium.
```

------------------------------------------------------------------------

## 9. AI Game Master

The AI Game Master receives structured game state rather than
unrestricted control.

Inputs: - Current round - Active players - Completed tasks - Recent
incidents - Game difficulty - Remaining time

Outputs: - Event narrative - Optional clue - Task/event description

A deterministic rule layer must validate AI-generated actions before
applying them to the game.

------------------------------------------------------------------------

## 10. Non-Functional Requirements

### Performance

-   Real-time events should feel responsive.
-   Server should remain authoritative.
-   AI requests should not block the main game loop.

### Security

-   Never expose hidden roles to clients.
-   Validate all client actions server-side.
-   Prevent clients from modifying game state directly.
-   Rate-limit chat and API requests.

### Reliability

-   Reconnect support
-   Match state recovery
-   Error logging
-   Graceful game termination

### Scalability

MVP target: - 8--12 players per room. - Multiple simultaneous rooms.

------------------------------------------------------------------------

## 11. Recommended Architecture

``` text
React / Game Client
        |
        | WebSocket
        v
Node.js Game Server
        |
   +----+----+
   |         |
Game       Event
Engine     Logger
   |         |
   +----+----+
        |
   PostgreSQL
        |
   +----+------------------+
   |                       |
Python AI Service      Analytics
   |                       |
   +-----------+-----------+
               |
        ML / NLP / LLM
```

Recommended technologies:

-   Frontend: React + Tailwind
-   Game layer: Phaser or Three.js
-   Backend: Node.js + Express
-   Real-time: Socket.IO
-   AI: Python + FastAPI
-   ML: scikit-learn / XGBoost / PyTorch
-   Database: PostgreSQL
-   Cache/queues: Redis
-   LLM: OpenRouter or another approved provider
-   Deployment: Vercel + Railway/Render
-   DevOps: Docker + GitHub Actions

------------------------------------------------------------------------

## 12. MVP Scope

The first complete version must include:

-   Login/guest entry
-   Lobby
-   6--10 player rooms
-   Citizen/Impostor roles
-   Basic map
-   3--5 tasks
-   Sabotage/incident
-   Text chat
-   Discussion
-   Voting
-   Match result
-   Event logging
-   Basic suspicion engine
-   Post-game report

Advanced features should be added only after the MVP is stable.

------------------------------------------------------------------------

## 13. Future Scope

-   Voice communication analysis
-   Additional roles
-   Graph neural networks
-   Adaptive difficulty
-   AI-generated maps
-   Tournament mode
-   Ranked matchmaking
-   Mobile client
-   Spectator mode
-   Advanced replay
-   Research dataset generation

------------------------------------------------------------------------

## 14. Success Criteria

The project is successful if:

-   8 players can complete a match without desynchronization.
-   Hidden roles remain secure.
-   Gameplay events are stored correctly.
-   Suspicion scores can be generated from real gameplay.
-   ML models can be evaluated objectively.
-   Post-game reports explain important evidence.
-   Every team member owns an independently testable subsystem.

------------------------------------------------------------------------

## 15. Out of Scope

For the initial version: - Real-money gaming - Gambling - Biometric
identification - Claims of actual lie detection - Psychological
diagnosis - Unmoderated public voice recording - Fully autonomous AI
control of game rules

------------------------------------------------------------------------

## 16. Definition of Done

A feature is complete when: - Code is implemented on its assigned
branch. - Unit/integration tests exist where applicable. - API contracts
are documented. - Error handling is implemented. - Feature works against
the shared development environment. - Pull request is reviewed. -
Integration test passes on the main/develop branch.
