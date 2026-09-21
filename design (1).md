# BLACKOUT — Design Document

**Version:** 1.0 (MVP)
**Companion docs:** `prd.md` (requirements/scope), `team_split.md` (ownership)

---

## 1. Core Identity

```
COMPLETE TASKS
      ↓
UNLOCK BLACKOUT
      ↓
DARKNESS BECOMES THE IMPOSTOR'S OPPORTUNITY
      ↓
CREW RACES TO RESTORE POWER
      ↓
IMPOSTOR RACES TO COMPLETE SECRET OBJECTIVES
      ↓
INVESTIGATE WHAT HAPPENED
      ↓
DISCUSS → VOTE → SURVIVE THE MELTDOWN
```

One hidden Impostor. One compromised research facility. A limited window in the darkness.
Five final minutes to save ORION.

**Design pillar:** the blackout is not the mystery itself — *"What did the Impostor do while
the facility was in darkness?"* is. Every system should serve that central question.

---

## 2. High-Level State Machine

```
LOBBY
  ↓
ROLE_ASSIGNMENT
  ↓
INITIAL_TASK_PHASE
  ↓
BLACKOUT_AVAILABLE
  ↓
BLACKOUT_ACTIVE
  ↓
POST_BLACKOUT_INVESTIGATION
  ↓
MEETING
  ↓
VOTING
  ↓
MELTDOWN
  ↓
GAME_OVER
```

This state machine is the backbone of server-side game logic. Each state transition should
be server-triggered and broadcast to all clients; clients render the current state but do
not decide transitions.

---

## 3. Phase-by-Phase Design

### 3.1 LOBBY → ROLE_ASSIGNMENT
- 8 players connect and ready up.
- Server randomly selects 1 Impostor, assigns Crew to the rest.
- Role reveal is private per-client (e.g., a role card shown only to that player).

### 3.2 INITIAL_TASK_PHASE
**Goal:** create a believable "everyone is just working" period before anything
dramatic happens; prevent instant blackout.

- Crew: full task list (Repair Power, Server Calibration, Security System Repair, Medical
  Supply Check, Data Transfer, Door Repair, Coolant System, Laboratory Organization, Backup
  Power, ORION maintenance).
- Impostor: smaller/easier "cover" task list (e.g., Terminal Check, Power Verification,
  Equipment Scan) — visually similar to Crew tasks so an observer can't immediately tell
  the Impostor's tasks are different.
- Design intent: Impostor's tasks should route them around the map naturally, not keep
  them isolated (isolation early on is itself suspicious).

**Transition condition:** Impostor completes all required prerequisite tasks →
`BLACKOUT_AVAILABLE`. No time-based fallback in MVP — this is explicitly a hard,
gameplay-driven gate (replaces the earlier "wait 2–3 minutes" idea).

### 3.3 BLACKOUT_AVAILABLE
- Impostor's client shows a `BLACKOUT READY [ACTIVATE ]` prompt.
- No visible change for Crew — from their perspective nothing has happened yet. This
  preserves suspense; only the Impostor knows the window is open.
- Impostor chooses *when* to activate — this is a meaningful strategic decision (e.g., wait
  until players are spread out, or until they've built a stronger alibi).

### 3.4 Activating Blackout
- Impostor can activate from **anywhere on the map** (deliberately not tied to a physical
  Generator/Power Room — the source concept explicitly rejects a location requirement
  because it would let Crew camp that room).
- A short countdown (`3… 2… 1… POWER FAILURE`) plays for all players before effects apply,
  giving a brief, universal "something is about to happen" beat without revealing who
  triggered it.
- Single-use in MVP: once triggered, cannot be re-armed or retriggered.

### 3.5 BLACKOUT_ACTIVE
**Duration:** fixed, server-controlled, **configurable** (do not hardcode to any legacy
value; balance via playtesting — see `prd.md` Open Questions).

**Environmental effects:**
- Main lighting off; emergency lighting only.
- Reduced player visibility radius (design as a literal vision-cone/radius shrink on the
  client, validated server-side for anything vision-gates, e.g., proximity chat).
- Security cameras unavailable.
- Some doors malfunction (random subset lock/jam for the duration, or on sabotage — see
  §3.5.3).
- Communication systems "may be affected" (scope to be finalized — proximity-only chat is
  a natural fit thematically).
- ORION instability begins accumulating (this value carries forward into Meltdown
  severity/flavor, even though Meltdown duration itself is fixed).

#### 3.5.1 Crew during Blackout
Crew must split attention across five competing pulls — this tension **is** the gameplay:
1. Continue normal Phase 1 tasks.
2. Repair damaged systems.
3. Perform blackout-recovery tasks (see §3.5.2).
4. Investigate suspicious activity in real time.
5. Observe/remember player movement (no system-provided tracking — this is manual,
   human memory, which is the point).

Design should surface enough ambient signal (sounds, visible sabotage, a passed player in
a corridor) that attentive players *can* gather real information, without the system ever
telling them who's guilty.

#### 3.5.2 Crew Recovery System (Early Termination)
- Multiple distinct recovery systems distributed around the map (e.g., Generator, Power
  Routing, Security Relay, Cooling System).
- A configurable subset (example: 3-of-4) must be completed to restore power early —
  intentionally **not** a single button/task, so no one player or camped room can trivially
  end the blackout.
- Live progress UI: `SYSTEMS REQUIRED: 3/4` with per-system ✓/✗ status, visible to all Crew
  to encourage coordination (and, by extension, splitting up — which is itself a risk
  decision).
- Design tension: splitting up to hit more systems in parallel restores power faster but
  gives the Impostor more isolated targets/openings — this trade-off should be visible to
  players, not hidden.

#### 3.5.3 Impostor during Blackout
On blackout start, Impostor receives a **new** objective set (distinct from Phase 1 cover
tasks):
- Steal Confidential Files
- Extract ORION Core Data
- Disable ORION Containment
- Sabotage Generator
- Tamper With Security

**Confidential File Theft** (flagship objective):
- Location: Laboratory / Restricted Research Area.
- Interaction: short mini-game at a restricted terminal/storage point.
- On completion: files vanish from their normal location; a `CLASSIFIED DATA ACQUIRED`
  confirmation shown only to the Impostor.
- This generates a discoverable evidence flag (`CLASSIFIED FILES MISSING`) surfaced to
  Crew during Investigation — the theft itself is silent, but its *consequence* is not.

**ORION/Core objectives** — steal research data, extract Core info, disable containment,
damage stabilization systems, manipulate Core controls. These directly feed the
instability value that determines Meltdown flavor/severity.

**Secondary sabotage (optional, supports playstyle variety):**
- Generator sabotage (cooling, power distribution, backup generator).
- Security sabotage (cameras, logs, door controls, emergency comms).
- Evidence manipulation — move objects to misleading locations (actively creates false
  leads for Crew, a strong deduction-game mechanic).
- Fake repair — pretend to fix a system while secretly delaying/worsening it; this is
  the mechanical basis for the "Player 3 said they repaired Security, but Security is
  still damaged" evidence pattern.

Design note from source concept, worth preserving in tuning: the Impostor **should not**
be able to simply run room-to-room destroying everything — sabotage actions should have
cooldowns/costs so the Impostor must prioritize, and so that behaving like "a legitimate
player" (fake tasking, alibi-building) remains a viable, rewarded strategy alongside
active sabotage.

#### 3.5.4 The Blackout Race (Core Tension Diagram)
```
                    BLACKOUT
                       ↓
          ┌────────────┴────────────┐
          ↓                         ↓
        CREW                    IMPOSTOR
          ↓                         ↓
Complete tasks              Steal files
Repair systems               Extract Core data
Investigate                  Damage ORION
Restore power                Disable security
          ↓                         ↓
END BLACKOUT               FINISH OBJECTIVES
EARLY                       BEFORE POWER RETURNS
          └────────────┬────────────┘
                       ↓
                 BLACKOUT ENDS
```

### 3.6 Blackout Ends → POST_BLACKOUT_INVESTIGATION
Ends via natural timer expiry **or** Crew recovery completion — both transition into the
same investigation state.

Evidence surfaced to Crew (examples, not exhaustive):
- Confidential files missing.
- ORION containment damaged.
- Core data stolen.
- Security tampered with.
- Generator components damaged.
- Objects/evidence out of place.
- Restricted areas accessed without authorization.
- A system someone claimed to repair is still damaged (fake-repair tell).

**Critical design rule:** no AI/automated system tells players who is lying or who is
guilty. All of this is presented as raw facts/state changes; players must connect it
themselves via discussion (e.g., *"I saw Player 4 going toward the Laboratory," "Player 6
was with me in Security," "Player 3 said they repaired Security, but it's still
damaged."*).

### 3.7 MEETING
- Any player can call a meeting (exact trigger mechanism is an open question — see
  `prd.md` §9.3; recommend starting with a cooldown-limited "call meeting" action for MVP
  simplicity over a body-report mechanic).
- Open discussion period (chat), during which players share what they saw/did and cross-
  reference against the investigation evidence.

### 3.8 VOTING
- Each player casts one vote (including a "skip/abstain" option).
- Server tallies and resolves per the configured rule (plurality vs. majority — open
  question, see `prd.md`).
- Result announced to all: ejected player's role is revealed, or "no one was ejected."

### 3.9 Post-Vote Branching

#### If Impostor is caught:
- Impostor is removed from play.
- Facility still announces `UNAUTHORIZED SABOTAGE DETECTED / ORION CORE INSTABILITY
  DETECTED / MELTDOWN PROTOCOL ACTIVATED` — catching the Impostor does **not** end the
  match, because the damage already done during blackout persists.
- Only Crew acts during Meltdown.

#### If Impostor escapes the vote:
- Impostor remains active.
- Meltdown still begins (same trigger, same timer).
- Crew now has two simultaneous problems: stop the meltdown *and* deal with a still-active
  Impostor, who can continue sabotaging emergency systems, interrupting repairs,
  interfering with doors, creating distractions, or pretending to help.

This is an important design decision: **the vote is not the win condition.** It only
determines *who* is fighting the Meltdown, not *whether* it happens.

### 3.10 MELTDOWN
- Fixed **5-minute** timer, identical length regardless of vote outcome.
- Three critical emergency tasks, each its own mini-game:
  - **Restore Power** — emergency electrical/power mini-game.
  - **Restore Cooling** — adjust cooling controls/valves to safe operating levels.
  - **Stabilize ORION** — final ORION stabilization mini-game.
- All three must complete before the timer hits zero.

### 3.11 GAME_OVER — Win Conditions

**Crew Victory:** all 3 emergency systems repaired and ORION stabilized before timer
expiry.
```
ORION STABLE
MELTDOWN CANCELLED
FACILITY SECURED
CREW WINS
```

**Impostor Victory:** timer reaches zero before stabilization — applies whether or not the
Impostor was previously ejected.
```
CRITICAL FAILURE
ORION CORE UNSTABLE
MELTDOWN COMPLETE
MISSION FAILED
IMPOSTOR WINS
```

---

## 4. Map Design

2D top-down facility. Suggested areas and their primary systemic role:

| Room | Primary Role(s) |
|---|---|
| Cafeteria | Social hub, early Crew tasks, low sabotage relevance |
| Security Room | Camera monitoring (disabled in blackout), door control sabotage target |
| Laboratory | Confidential file theft objective, restricted-area evidence |
| Server Room | Data Transfer task, Core data extraction objective |
| Storage | Equipment tasks, evidence-manipulation hiding spots |
| Generator Room | Power-related Crew tasks + recovery system, Generator sabotage target |
| Office | General Crew tasks, low sabotage relevance (useful for alibi-building) |
| Medical Bay | Medical Supply Check task, general traffic |
| ORION Core Chamber | ORION objectives, containment sabotage, final Meltdown "Stabilize ORION" task |

Each room should support a distinct, legible mix of: Crew tasks, Impostor objectives,
potential evidence, and (where relevant) emergency/recovery systems — avoid rooms that
exist purely as connective tissue with no gameplay purpose.

---

## 5. Important Gameplay Rules (Design Constraints)

These constraints came directly from the source concept and should be treated as hard
design rules, not suggestions to be revisited casually:

1. **No Immediate Blackout** — Impostor cannot activate blackout right after spawning.
2. **Blackout Must Be Earned** — gated behind completing the Impostor's prerequisite tasks.
3. **Remote Activation** — no physical location requirement to trigger blackout.
4. **Fixed Blackout Duration** — configurable, but fixed once a match starts.
5. **Crew Can Restore Power Early** — via multiple, distributed, non-trivial recovery
   tasks — never a single button.
6. **Blackout Grants New Impostor Objectives** — distinct from the Phase 1 cover tasks.
7. **Limited Opportunity Window** — Impostor must finish key objectives before blackout
   ends, one way or another.
8. **Investigation Is Player-Driven** — no AI/automatic lie detection, ever.
9. **Catching the Impostor Does Not End the Match** — the facility must still be saved.
10. **Final Meltdown Is Always Five Minutes** — only the presence/absence of an active
    Impostor changes during it, not the timer length.

---

## 6. Technical Architecture

### 6.1 Topology
Authoritative multiplayer architecture:

```
PLAYERS
   ↓
2D GAME CLIENT
   ↓
MULTIPLAYER SERVER
   ↓
GAME STATE
   ├── Player Positions
   ├── Roles
   ├── Initial Tasks
   ├── Blackout Unlock
   ├── Blackout Timer
   ├── Blackout Recovery
   ├── Impostor Objectives
   ├── Sabotage
   ├── Evidence
   ├── Meetings
   ├── Voting
   ├── Eliminations
   ├── Meltdown
   └── Win Conditions
```

### 6.2 Division of Responsibility

**Server owns/validates:**
- Player roles
- Task completion
- Blackout unlock state
- Blackout activation
- Recovery task completion
- Impostor objective completion
- Sabotage effects
- All timers
- Meetings
- Votes
- Elimination
- Meltdown state
- Victory/defeat determination

**Client owns:**
- Rendering
- Input handling
- UI
- Animation
- Mini-game interfaces (visual/input layer only — outcome validated server-side)
- Audio/visual feedback

This split is non-negotiable for MVP: any state that determines win/lose, role identity,
or objective completion must never be trusted to a client, since a compromised or modified
client could otherwise self-report false progress or reveal hidden information.

### 6.3 Suggested Module Breakdown

```
game/
├── game_state          — top-level state machine (§2)
├── role_manager         — assignment, reveal-on-elimination
├── player               — position, connection, per-player runtime data
├── task_manager          — shared task infra (assignment, validation)
├── crew_tasks            — Crew-specific task definitions
├── impostor_tasks        — Impostor prerequisite + blackout objective definitions
├── blackout_manager       — unlock gating, activation, countdown, timer, environment fx
├── blackout_recovery      — recovery system tracking, early-termination logic
├── sabotage_manager        — secondary Impostor sabotage actions & effects
├── evidence_manager         — generates/stores discoverable evidence state
├── meeting_manager           — meeting trigger, discussion window
├── voting_manager             — vote collection, tally, resolution rule
├── meltdown_manager            — 5-minute timer, 3 emergency tasks, Impostor interference
├── win_condition_manager        — evaluates Crew/Impostor victory
└── map_manager                   — room definitions, spawn points, task/system placement

ui/
├── role_reveal
├── task_ui
├── blackout_ui
├── timer_ui
├── sabotage_ui
├── meeting_ui
├── voting_ui
├── meltdown_ui
└── result_screen
```

Exact filenames/language structure should be finalized once engine and networking stack
are chosen (see `team_split.md` and `prd.md` Open Questions).

### 6.4 Configuration Values (Design Levers)
These should be externalized as server-side config, not hardcoded, to support balancing:

| Value | Notes |
|---|---|
| Blackout duration | Legacy draft used 15 min; treat as a placeholder, not a spec |
| Recovery systems required (X of Y) | e.g., 3 of 4 |
| Impostor prerequisite task count | Should be "smaller/easier" than Crew's, exact count TBD |
| Meltdown duration | Fixed at 5 minutes per source concept — likely not a balancing lever |
| Vote resolution rule | Plurality vs. majority (open question) |
| Blackout visibility radius | Tune for tension without becoming unplayable |

---

## 7. Design Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Blackout duration too short → Impostor can't complete objectives; too long → Crew has no tension | Make duration and required objective count both configurable; playtest jointly |
| Recovery systems too easy → blackout trivialized; too hard → Crew feels helpless | Start with 3-of-4 as a baseline, adjust after playtests, keep visible partial progress |
| Impostor sabotage snowballing (room-to-room destruction) breaks cover-based play | Cooldowns/costs on sabotage actions; reward alibi-building via evidence design |
| Evidence too obvious → no real deduction; too obscure → players feel it's random | Evidence should always be *discoverable through play* (being in the right place, checking a system), never broadcast automatically |
| Server authority gaps allow client-side cheating on tasks/votes | Strict rule: every state listed in §6.2 "Server owns" must be validated server-side with no client-trusted fallback |
