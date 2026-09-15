# WHO'S THE IMPOSTOR?

## Design & Technical Architecture

------------------------------------------------------------------------

## 1. Design Philosophy

The product should feel like a modern mystery game rather than an
academic dashboard.

Visual direction: - Dark futuristic interface - High contrast - Minimal
HUD during gameplay - Strong red/amber/green signals for game state -
Neon-like accents used sparingly - Smooth transitions - Clear
typography - Mobile-friendly lobby and dashboard

The game interface should prioritize gameplay. AI analytics should
become prominent during meetings and after the match.

------------------------------------------------------------------------

## 2. Main Screens

### 2.1 Landing Page

``` text
WHO'S THE IMPOSTOR?

Read the room.
Trust nobody.

[ CREATE GAME ]
[ JOIN GAME ]

Recent Games | Leaderboard
```

------------------------------------------------------------------------

### 2.2 Lobby

``` text
ROOM: X7K29

Players
● Player 01   READY
● Player 02   READY
● Player 03   READY
● Player 04   READY
● Player 05   READY
● Player 06   READY

[ COPY CODE ]
[ START GAME ]
```

------------------------------------------------------------------------

### 2.3 Game HUD

``` text
+------------------------------------------------+
| OBJECTIVES              TIME                   |
| 3 / 5 completed          04:21                 |
|                                                |
|                GAME WORLD                      |
|                                                |
|       P1                  P4                   |
|                                                |
|                         P3                     |
|                                                |
| Chat                              EVENTS       |
| P2: Where are you?                ⚠ Incident   |
| P5: Lab                           ⚡ Power out  |
+------------------------------------------------+
```

Do not display the hidden role or raw suspicion score during normal
gameplay unless the game rules explicitly permit it.

------------------------------------------------------------------------

## 3. Meeting Screen

The meeting screen is the main social-deduction interface.

``` text
MEETING

Why did the incident happen?

P1  ███████
P2  █████
P3  ██████████
P4  ███
P5  ██████

[ DISCUSS ]

[ VOTE ]
```

Optional AI panel:

``` text
AI OBSERVATION

P3 has the highest behavioral
suspicion based on current evidence.

Evidence:
• Near incident
• Vote switched
• Task timing anomaly
```

The wording should communicate uncertainty.

------------------------------------------------------------------------

## 4. Voting Screen

``` text
WHO DO YOU SUSPECT?

○ Player 01
○ Player 02
○ Player 03
○ Player 04
○ Player 05

[ CONFIRM VOTE ]
```

After voting:

``` text
VOTING RESULTS

P3  ██████████  4
P5  █████       2
P1  ██          1
```

------------------------------------------------------------------------

## 5. AI Investigation Screen

``` text
AI INVESTIGATION

Player 03
Suspicion: 82%

Evidence

Incident proximity       HIGH
Vote switching           MEDIUM
Task behavior            LOW
Communication            HIGH

Confidence: 74%

[ VIEW TIMELINE ]
```

Every AI conclusion should be linked to observable game events.

------------------------------------------------------------------------

## 6. Post-Game Replay

Timeline UI:

``` text
00:12  P3 enters Laboratory
00:24  Power failure
00:31  P7 eliminated
00:43  P3 leaves Laboratory
01:02  P3 accuses P5
01:40  P3 changes vote
```

Users can select an event to see:

-   Actor
-   Time
-   Location
-   Event type
-   Related players

------------------------------------------------------------------------

## 7. Analytics Dashboard

Dashboard sections:

### Match Overview

-   Winner
-   Duration
-   Number of rounds
-   Incidents
-   Votes

### Behavioral Analysis

-   Suspicion over time
-   Player movement
-   Task performance

### Social Graph

``` text
        P1
       /  \
     P2---P4
      \    |
       P3--P5
```

Edges can represent communication, voting, or interactions.

### ML Metrics

-   Accuracy
-   Precision
-   Recall
-   F1
-   ROC-AUC
-   Confusion matrix

------------------------------------------------------------------------

## 8. Frontend Component Structure

``` text
src/
├── app/
├── pages/
│   ├── Landing
│   ├── Lobby
│   ├── Game
│   ├── Meeting
│   ├── Results
│   └── Analytics
├── components/
│   ├── PlayerCard
│   ├── GameMap
│   ├── TaskPanel
│   ├── Chat
│   ├── VotePanel
│   ├── SuspicionPanel
│   └── Timeline
├── hooks/
├── services/
└── store/
```

------------------------------------------------------------------------

## 9. Backend Architecture

``` text
server/
├── src/
│   ├── game/
│   ├── lobby/
│   ├── players/
│   ├── tasks/
│   ├── incidents/
│   ├── voting/
│   ├── chat/
│   ├── analytics/
│   └── websocket/
```

The backend must be authoritative.

Client requests:

``` text
CLIENT → "I completed task"
```

Server validates:

``` text
Is player alive?
Is task assigned?
Is player near task?
Is task already completed?
```

Then:

``` text
SERVER → task_completed event
```

------------------------------------------------------------------------

## 10. AI Service

``` text
ai-service/
├── api/
├── nlp/
├── features/
├── models/
├── inference/
├── game_master/
└── evaluation/
```

API examples:

``` text
POST /nlp/analyze-message
POST /features/build
POST /suspicion/predict
POST /game-master/event
GET  /model/metrics
```

------------------------------------------------------------------------

## 11. Event Schema

Every important gameplay action should generate an event.

Example:

``` json
{
  "event_id": "evt_1024",
  "match_id": "match_12",
  "player_id": "p3",
  "event_type": "TASK_COMPLETED",
  "timestamp": "2026-09-15T10:22:31Z",
  "location": "laboratory",
  "metadata": {
    "task_id": "task_07",
    "duration_seconds": 32
  }
}
```

Recommended event types:

``` text
PLAYER_JOINED
PLAYER_MOVED
TASK_STARTED
TASK_COMPLETED
TASK_FAILED
INCIDENT_CREATED
SABOTAGE
CHAT_MESSAGE
MEETING_STARTED
VOTE_CAST
VOTE_CHANGED
PLAYER_ELIMINATED
GAME_ENDED
```

------------------------------------------------------------------------

## 12. Database Concept

Main entities:

``` text
User
  |
Player
  |
Match
  |
Round
  |
GameEvent
  |
Task
  |
Vote
  |
Message
  |
Prediction
```

Keep raw gameplay events immutable where possible. Derived analytics
should be generated from the event history.

------------------------------------------------------------------------

## 13. API Contract Principle

Before parallel development begins, freeze:

-   Authentication contract
-   Player object
-   Match object
-   Game event format
-   WebSocket event names
-   AI prediction response
-   Error format

Do not allow every branch to invent its own API structure.

------------------------------------------------------------------------

## 14. Git Strategy

Use:

``` text
main
develop

feature/game-engine
feature/realtime-backend
feature/frontend-game
feature/tasks-incidents
feature/nlp
feature/ml-suspicion
feature/ai-gamemaster
feature/analytics-replay
```

Rules:

1.  Never push directly to `main`.
2.  Each member works primarily on one feature branch.
3.  Pull requests target `develop`.
4.  At least one other member reviews each PR.
5.  Resolve integration conflicts before merging.
6.  Shared contracts are changed only after team agreement.
7.  Commit messages should be meaningful.

Example:

``` text
feat: add task completion websocket event
fix: prevent duplicate vote submission
feat: add suspicion prediction endpoint
```

------------------------------------------------------------------------

## 15. Integration Order

Do NOT merge everything at the end.

Recommended sequence:

``` text
Phase 1
Database + API contracts
        ↓
Phase 2
Game engine + WebSocket
        ↓
Phase 3
Frontend + basic game
        ↓
Phase 4
Tasks + incidents + voting
        ↓
Phase 5
Event logging
        ↓
Phase 6
NLP + ML
        ↓
Phase 7
AI Game Master
        ↓
Phase 8
Analytics + replay
        ↓
Full-system testing
```

------------------------------------------------------------------------

## 16. Security Design

Critical rule:

### Never send the hidden role to the client.

Bad:

``` json
{
  "player": "p3",
  "role": "IMPOSTOR"
}
```

Instead, the server stores role information and only sends permitted
information.

Other controls: - Server-side validation - Authentication - Rate
limiting - Input sanitization - WebSocket authorization - API keys
stored server-side - No secrets in Git

------------------------------------------------------------------------

## 17. AI Safety/Integrity

The AI should not: - Claim certainty about deception. - Diagnose
personality or mental health. - Use sensitive personal information. -
Override authoritative game rules. - Directly modify hidden roles.

The AI should: - Explain evidence. - Express uncertainty. - Use
structured gameplay data. - Remain reproducible where possible.

------------------------------------------------------------------------

## 18. Definition of a Good UX

A player should understand:

1.  What do I need to do?
2.  What happened?
3.  Who can I trust?
4.  When can I vote?
5.  Why did the AI flag someone?

within seconds.

The game should never require reading long AI explanations during active
gameplay.
