# BLACKOUT — Product Requirements Document (PRD)

**Version:** 1.0 (MVP)
**Status:** Draft — derived from "BLACKOUT Updated Game Concept"
**Owner:** TBD (Product/Design Lead)

---

## 1. Summary

BLACKOUT is a 2D top-down, 8-player multiplayer social-deduction game set in the fictional
**Asterion Research Facility**. Seven Crew Members and one hidden Impostor perform facility
tasks; the Impostor unlocks a remote **Blackout** ability by finishing a small prerequisite
task set, then uses a fixed-duration blackout window to steal data and sabotage the facility
while the Crew tries to restore power, investigate, and ultimately vote out the Impostor
before a final 5-minute **Meltdown Protocol** decides the outcome.

There is **no AI/automatic lie-detection system**. All deduction is player-driven, based on
observation, memory, and discussion — in the spirit of social-deduction games like *Among Us*,
but with a task-gated sabotage window and a two-stage win condition (vote + meltdown repair).

---

## 2. Goals & Non-Goals

### 2.1 Goals (MVP)
- Ship one fully playable 8-player match loop end-to-end (lobby → win/lose).
- Make the Impostor's blackout ability feel **earned**, not automatic or timer-only.
- Make blackout early-termination possible but meaningfully difficult for the Crew.
- Give the Impostor a believable "normal worker" cover during Phase 1.
- Deliver a satisfying two-stage climax: social vote, then cooperative meltdown repair.
- Keep the architecture server-authoritative to prevent client-side cheating on roles,
  tasks, votes, and timers.

### 2.2 Non-Goals (MVP)
- Multiple maps.
- Cosmetics, progression, ranking, or meta-game systems.
- More than 1 Impostor or alternate role types (e.g., multiple impostors, neutral roles).
- Spectator/replay tooling beyond what's needed for debugging.
- Mobile-native builds (unless platform is decided otherwise — see Open Questions).
- Voice chat (assume text chat and/or proximity is out of scope unless prioritized later).

---

## 3. Players & Roles

| Role | Count | Summary |
|---|---|---|
| Crew Member | 7 | Complete facility tasks, investigate, vote, survive meltdown |
| Impostor | 1 | Poses as Crew, completes small prerequisite tasks, unlocks & triggers Blackout, executes hidden sabotage objectives, tries to avoid detection and/or survive the vote |

Role assignment is server-authoritative and hidden from other clients (only the Impostor
knows their own role at game start).

---

## 4. Core Game Loop

```
LOBBY → ROLE_ASSIGNMENT → INITIAL_TASK_PHASE → BLACKOUT_AVAILABLE →
BLACKOUT_ACTIVE → POST_BLACKOUT_INVESTIGATION → MEETING → VOTING →
MELTDOWN → GAME_OVER
```

See `design.md` for full state machine detail and phase-by-phase mechanics.

### 4.1 Phase Summary

1. **Initial Normal Phase** — All 8 players spawn and receive tasks. Crew gets a full task
   list; Impostor gets a smaller, faster, "cover" task list.
2. **Blackout Unlock** — Impostor completes their required initial tasks →
   `BLACKOUT AVAILABLE`.
3. **Blackout Activation** — Impostor triggers blackout remotely, from anywhere on the map,
   after a short countdown.
4. **Blackout Active (fixed duration, configurable)** — Impostor pursues hidden objectives
   (file theft, ORION data extraction, sabotage). Crew balances normal tasks, blackout
   recovery tasks, and investigation. Crew can end the blackout early by completing multiple
   distributed recovery systems (not a single button).
5. **Post-Blackout Investigation & Meeting** — Power returns (naturally or early). Crew
   discovers evidence (missing files, damaged systems, tampered logs) and discusses.
6. **Voting** — Crew votes to eject a suspected Impostor. Vote may succeed or fail.
7. **Meltdown Protocol (fixed 5 minutes, always runs)** — Triggered regardless of vote
   outcome, because ORION was already destabilized. Crew must complete 3 critical
   emergency systems before the timer expires. If the Impostor was not caught, they can
   continue interfering during this phase.
8. **Game Over** — Crew wins if ORION is stabilized in time; Impostor wins if the timer
   expires first.

---

## 5. Functional Requirements

### 5.1 Lobby & Role Assignment
- FR-1: System supports exactly 8 players per match for MVP.
- FR-2: Server randomly assigns 1 Impostor and 7 Crew roles at match start.
- FR-3: Role is revealed only to the owning client.
- FR-4: Match cannot start with fewer than 8 connected players (MVP constraint).

### 5.2 Task System
- FR-5: Crew receive a full task list (e.g., Repair Power, Server Calibration, Security
  System Repair, Medical Supply Check, Data Transfer, Door Repair, Coolant System,
  Laboratory Organization, Backup Power, ORION maintenance).
- FR-6: Impostor receives a distinct, smaller, faster "prerequisite" task list (e.g.,
  Terminal Check, Power Verification, Equipment Scan) that visually/functionally resembles
  normal tasks to preserve cover.
- FR-7: Task completion is validated server-side.
- FR-8: Completing all Impostor prerequisite tasks unlocks the Blackout ability
  (`BLACKOUT_AVAILABLE` state) — this is a hard gate; there is no time-based fallback unlock
  in MVP (the old "wait 2–3 minutes" idea is explicitly replaced).

### 5.3 Blackout Activation
- FR-9: Once unlocked, Impostor can activate Blackout remotely from any location on the map.
- FR-10: Activation triggers a short countdown (e.g., 3–2–1) visible to all players before
  blackout effects apply.
- FR-11: Blackout cannot be activated before unlock, and cannot be re-armed once used
  (single activation per match in MVP).

### 5.4 Blackout Environment
- FR-12: During blackout: main lighting disabled, emergency lighting only, reduced player
  visibility radius.
- FR-13: Security cameras become unavailable during blackout.
- FR-14: Some doors may malfunction (lock/jam) during blackout.
- FR-15: Communication systems may be degraded/limited during blackout (scope TBD —
  see Open Questions).
- FR-16: ORION instability begins accumulating once blackout starts.

### 5.5 Blackout Timer & Duration
- FR-17: Blackout runs on a fixed, server-controlled countdown timer; duration is a
  configurable design value (not hardcoded to the legacy 15-minute figure).
- FR-18: Blackout ends when either (a) the timer reaches zero, or (b) the Crew completes
  the required recovery systems.

### 5.6 Crew Recovery System
- FR-19: The map contains multiple distinct recovery systems (e.g., Generator, Power
  Routing, Security Relay, Cooling System).
- FR-20: A configurable subset (e.g., 3 of 4) must be repaired to trigger early power
  restoration — no single task can restore power alone.
- FR-21: Recovery task completion and progress (`X/Y systems restored`) is tracked and
  broadcast to all players.

### 5.7 Impostor Blackout Objectives
- FR-22: On blackout start, Impostor receives a new objective set distinct from their
  Phase 1 tasks (e.g., Steal Confidential Files, Extract ORION Core Data, Disable ORION
  Containment, Sabotage Generator, Tamper With Security).
- FR-23: Confidential File Theft is a location-gated interaction (Laboratory/Restricted
  Research Area) requiring a short mini-game; on completion the files are marked
  "missing" and this becomes discoverable evidence.
- FR-24: ORION/Core objectives (steal research data, extract Core info, disable
  containment, damage stabilization systems) contribute to accumulating instability that
  feeds directly into the Meltdown Protocol.
- FR-25: Additional sabotage actions (Generator sabotage, Security sabotage, evidence
  relocation, fake repairs) are available to the Impostor during blackout as
  secondary/optional actions.
- FR-26: Impostor objective completion is validated and logged server-side (for evidence
  generation), but not revealed directly to Crew clients.

### 5.8 Evidence & Investigation
- FR-27: The system must generate discoverable evidence tied to Impostor actions (e.g.,
  "Classified Files Missing" warning, systems still damaged despite a false repair claim,
  moved objects).
- FR-28: There is no automated deduction/AI system — the game must not tell players who
  the Impostor is. All investigation is player-observation and discussion-based.
- FR-29: Player position history / "who was near which room" is not automatically
  surfaced by the system in MVP; players must rely on their own memory (system may log
  this server-side for anti-cheat/anti-grief purposes only, not shown in UI).

### 5.9 Meeting & Voting
- FR-30: Players can trigger an emergency meeting (mechanism TBD — button, body report,
  etc.; see Open Questions).
- FR-31: During a meeting, players can discuss (chat) and then cast one vote each
  (including a "skip" option).
- FR-32: Server tallies votes and ejects the top-voted player if it meets the resolution
  rule (e.g., plurality or majority — see Open Questions).
- FR-33: Vote outcome (correct/incorrect ejection, or no ejection) is revealed to all
  players, but the game continues regardless of outcome.

### 5.10 Meltdown Protocol
- FR-34: Meltdown Protocol always triggers after the meeting/voting phase resolves,
  regardless of whether the Impostor was caught, because ORION was already destabilized
  during the blackout.
- FR-35: Meltdown Protocol runs on a fixed 5-minute server-controlled timer, identical in
  length whether or not the Impostor was caught.
- FR-36: If the Impostor was ejected, only Crew acts during this phase.
- FR-37: If the Impostor was not ejected, they remain able to act (sabotage emergency
  systems, interfere with doors, create distractions, fake assistance) during Meltdown.
- FR-38: Crew must complete 3 critical emergency tasks: Restore Power, Restore Cooling,
  Stabilize ORION (each its own mini-game/interaction).
- FR-39: All 3 emergency tasks must be completed before the timer expires for Crew to win.

### 5.11 Win/Lose Conditions
- FR-40: **Crew wins** if all required Meltdown emergency systems are completed and ORION
  is stabilized before the 5-minute timer expires.
- FR-41: **Impostor wins** if the Meltdown timer reaches zero before ORION is stabilized —
  this applies whether or not the Impostor was previously ejected from the vote.
- FR-42: End-of-match screen communicates outcome and role reveal to all players.

### 5.12 Server Authority (Cross-Cutting)
- FR-43: Server is authoritative for: roles, task completion, blackout unlock/activation,
  recovery task completion, Impostor objective completion, sabotage effects, all timers,
  meetings, votes, ejections, meltdown state, and win/lose determination.
- FR-44: Client is responsible only for rendering, input, UI, animation, mini-game
  interfaces, and audio/visual feedback — it must not make authoritative gameplay
  decisions.

---

## 6. Non-Functional Requirements

- NFR-1: **Latency** — Core interactions (task completion, activation, voting) should feel
  responsive; target server round-trip well under 300ms on typical broadband for an
  8-player session.
- NFR-2: **Anti-cheat** — All win-relevant state transitions must be server-validated;
  clients must never be trusted to self-report task/objective completion.
- NFR-3: **Scalability** — MVP only needs to support one 8-player match per server
  instance/room, but the architecture should not preclude running many concurrent rooms.
- NFR-4: **Resilience** — Player disconnect/reconnect handling must not silently break the
  match state machine (see Open Questions — MVP behavior can be "match ends" as a
  simplification, but this should be an explicit decision, not an oversight).
- NFR-5: **Configurability** — Blackout duration, number of required recovery systems,
  Impostor prerequisite task count, and vote resolution rule should be server-side
  configurable values, not hardcoded constants, to support balancing.

---

## 7. MVP Scope (Definition of Done)

Per the source concept, the MVP must include:

- 1 map, 8-player multiplayer, 1 Impostor / 7 Crew
- Role assignment
- Initial Crew tasks + smaller/easier Impostor prerequisite tasks
- Blackout unlock system (task-gated)
- Remote blackout activation with countdown
- Fixed, configurable blackout timer
- Reduced visibility during blackout
- Special Impostor blackout objectives
- Confidential file theft mini-game/interaction
- ORION sabotage objective(s)
- Multiple Crew blackout-recovery tasks with early-termination logic
- Post-blackout investigation (evidence discovery)
- Emergency meeting + voting
- Impostor elimination handling
- 5-minute Meltdown phase with 3 critical emergency tasks
- Win/lose conditions
- Simple 2D graphics

**Explicitly out of scope for MVP:** multiple maps, additional roles, cosmetics,
progression systems, matchmaking/ranking, voice chat (unless re-prioritized).

---

## 8. Suggested Map Areas (Reference)

1. Cafeteria
2. Security Room
3. Laboratory
4. Server Room
5. Storage
6. Generator Room
7. Office
8. Medical Bay
9. ORION Core Chamber

Each room should support a distinct mix of Crew tasks, Impostor objectives, evidence, or
emergency systems (detailed in `design.md`).

---

## 9. Open Questions

These are gaps in the source concept doc that need explicit decisions before/during
implementation:

1. **Platform target** — PC, web, mobile, or cross-platform? Affects engine/networking
   choice and input scheme for mini-games.
2. **Vote resolution rule** — plurality vs. strict majority; tie-breaking behavior.
3. **Meeting trigger mechanism** — manual "report body" style trigger, cooldown-based
   button, or scheduled meetings only.
4. **Communication scope during blackout** — is text/voice chat disabled, range-limited
   (proximity), or unaffected? Source doc says "may be affected" but doesn't specify.
5. **Disconnect/reconnect handling** — what happens if a player (especially the Impostor)
   disconnects mid-match?
6. **Blackout duration default value** — needs a concrete starting number for playtesting
   (source doc explicitly leaves this open, previous draft used 15 minutes).
7. **Required recovery systems threshold** — e.g., 3-of-4 vs. other ratios; needs
   playtesting to balance against blackout duration.
8. **Anti-griefing measures** — e.g., false-report spam on meetings, AFK players during
   Meltdown.
9. **Engine/networking stack** — determines final module structure (see `team_split.md`
   and `design.md` §Technical Architecture).

---

## 10. Success Metrics (Post-MVP Playtesting)

- Average match length falls within a target range (TBD, likely 15–25 min including
  Meltdown) to validate pacing.
- Win rate between Crew and Impostor trends toward roughly balanced (e.g., 45–55%) across
  playtests, adjustable via the configurable balance values in §6/NFR-5.
- Players report (via post-match survey) that they had enough information to make an
  informed vote — validates that evidence generation (FR-27/FR-29) is sufficient
  without being either trivial or opaque.
- Qualitative signal that "did the Impostor use the blackout window well" is a
  recognizable, fun tension point (validates core identity: *Complete Tasks → Unlock
  Blackout → Darkness Becomes Opportunity → Race → Investigate → Vote → Survive Meltdown*).
