# BLACKOUT — Task & Objective Specifications

**Owner:** Member 6 (Abubaker) — Game Systems & Content Designer
**Branch:** `member-6/game-design`
**Companion docs:** [`design.md`](../../design.md) (system design), [`evidence_matrix.md`](./evidence_matrix.md) (evidence rules), [`map_station_layout.md`](./map_station_layout.md) (room placement), [`config/game_balance_config.json`](../../config/game_balance_config.json) (tunable values)

This document is the mechanical content spec for every interactive task/objective in the MVP:
~10 Crew tasks, the Impostor's prerequisite tasks, the 5 Impostor Blackout objectives, the 4
Crew recovery systems, and the 3 Meltdown emergency tasks. It is written to match the data
already implemented in `shared/task_config.gd`, `shared/blackout_objective_config.gd`,
`shared/blackout_recovery_config.gd`, and `shared/meltdown_config.gd` — durations, mini-game
descriptions, and traversal notes here are the design layer that sits on top of those
authoritative IDs/catalogs for Member 4 (mini-games), Member 5 (UI/UX), and Member 7
(environment art) to build against.

---

## 1. Crew Task Catalog (`TaskConfig.TASK_CATALOG`)

Each Crew member is assigned `DEFAULT_CREW_TASK_COUNT = 4` distinct tasks, drawn at random
(without repetition) from the 10-entry catalog below at `INITIAL_TASK_PHASE` start. Tasks may
be completed during `INITIAL_TASK_PHASE`, `BLACKOUT_AVAILABLE`, and `BLACKOUT_ACTIVE`
(`server/task_manager.gd`).

| Task ID | Display Name | Category | Room | Mechanic | Duration |
|---|---|---|---|---|---|
| `repair_power` | Repair Power | electrical | Generator Room | Swap two burnt-out breaker fuses in the correct slots (2-step click sequence). | 8s |
| `stabilize_orion` | Stabilize ORION | orion_core | ORION Core Chamber | Hold 3 sliders inside a moving green band simultaneously for 2s. | 12s |
| `server_calibration` | Server Calibration | tech | Server Room | Match a 4-symbol sequence shown briefly, then re-enter it. | 10s |
| `security_repair` | Security Repair | security | Security Room | Re-align 3 camera feed dials to their labeled target angle. | 8s |
| `medical_supply_check` | Medical Supply Check | medbay | Medical Bay | Count and confirm stock against a checklist (5 clicks). | 6s |
| `data_transfer` | Data Transfer | comms | Server Room | Hold interact to fill a progress bar; interrupting resets progress. | 7s |
| `door_repair` | Door Repair | maintenance | Maintenance Corridor | Timed button-mash / rapid-click to force a stuck door panel shut. | 6s |
| `coolant_system` | Coolant System | engineering | Cooling Hub (Generator Room) | Turn 2 valves to matching pressure gauges without overshooting. | 9s |
| `laboratory_org` | Laboratory Organization | lab | Laboratory | Drag 4 mismatched sample trays back to their labeled shelf slots. | 8s |
| `backup_power` | Backup Power | electrical | Storage | Prime the backup generator via a 3-pull cord mini-game. | 7s |

**Design intent:** each task is short (6–12s), single-player, and non-punishing on failure
(retry, no penalty) — per PRD non-goals, the tension in `INITIAL_TASK_PHASE` comes from *who
is where*, not from mini-game difficulty. Rooms are assigned so that the 10 tasks are spread
across 7 of the 9 facility rooms (Cafeteria and Office intentionally hold no forced Crew task —
see §4 and `map_station_layout.md` §3 for why).

---

## 2. Impostor Prerequisite Tasks

**Implementation note:** the Impostor's prerequisite tasks are **not** a separate catalog —
`server/task_manager.gd` draws `DEFAULT_IMPOSTOR_PREREQUISITE_COUNT = 2` tasks for the
Impostor from the exact same 10-entry catalog above, flagged `is_impostor_prerequisite = true`.
This is a deliberate reuse: the Impostor's cover tasks look, sound, and play identically to a
Crew member's tasks (same UI, same mini-game, same names), so an observer watching an Impostor
"work" cannot distinguish it from genuine Crew work — only the server knows the flag differs.
This supersedes the earlier illustrative names in `design.md` §3.2 ("Terminal Check, Power
Verification, Equipment Scan"), which were a placeholder before implementation and are
superseded by this catalog-reuse approach.

- **Current balance value:** 2 prerequisite tasks (fewer than Crew's 4, satisfying FR-6's
  "smaller/easier" requirement by count alone since mechanics are identical).
- **Recommended tuning range:** 1–3. Below 1 removes the "earn it" gate entirely; above 3
  approaches Crew's own task count and stops feeling like a fast cover phase. See
  `config/game_balance_config.json` → `task_system.impostor_prerequisite_count`.
- Prerequisite tasks are only completable during `INITIAL_TASK_PHASE` (matches Crew task
  completion window for that phase); completing all of them flips the match to
  `BLACKOUT_AVAILABLE`.

---

## 3. Impostor Blackout Objectives (`BlackoutObjectiveConfig.OBJECTIVE_CATALOG`)

On `BLACKOUT_ACTIVE`, the Impostor is assigned `DEFAULT_IMPOSTOR_OBJECTIVE_COUNT = 3`
objectives selected at random from this 5-entry catalog (`server/impostor_objective_manager.gd`
shuffles and takes the first 3 each match) — so which 3 of the 5 are "live" varies match to
match, adding replay variety and preventing Crew from memorizing a fixed objective set.

| Objective ID | Display Name | Category | Room | Evidence Produced | Mechanic | Duration |
|---|---|---|---|---|---|---|
| `steal_confidential_files` | Steal Confidential Files | espionage | Office (Executive Office) | `classified_files_missing` | Pick the file cabinet lock (3-tumbler mini-game), then lift the folder. | 10s |
| `extract_orion_core_data` | Extract ORION Core Data | data_theft | ORION Core Chamber | `orion_core_data_extracted` | Plug into the core terminal and hold a data-siphon bar steady. | 12s |
| `disable_orion_containment` | Disable ORION Containment | containment | ORION Core Chamber (Containment Hub) | `orion_containment_disabled` | Enter an override code shown once, then confirm on a physical lever. | 9s |
| `sabotage_generator` | Sabotage Generator | sabotage | Generator Room | `generator_sabotaged` | Sever two labeled cables in the correct order. | 7s |
| `tamper_security` | Tamper With Security | security | Security Room | `security_tampered` | Loop the camera feed by holding 3 dials at their tamper mark. | 8s |

**Design intent:** all 5 are physically distributed across 4 different rooms (Office, ORION
Core Chamber ×2, Generator Room, Security Room) so the Impostor cannot complete their whole
objective set from one corner of the map — they must move, which is itself a source of
sightings/evidence (see `evidence_matrix.md`). Each objective's mini-game duration (7–12s) is
intentionally close to a Crew task's duration, so an Impostor lingering at a station for an
objective doesn't look mechanically different from a Crew member doing a task, at a glance.

Per `design.md` §3.5.3, secondary sabotage (fake repairs, evidence relocation, generic
generator/security tampering beyond the objective set) is **not yet implemented** in
`ImpostorObjectiveManager` — see `evidence_matrix.md` §3 for the reserved evidence hooks and
a recommended follow-up scope for Member 2/Member 4.

---

## 4. Crew Blackout Recovery Systems (`BlackoutRecoveryConfig.RECOVERY_CATALOG`)

During `BLACKOUT_ACTIVE`, Crew can end the blackout early by completing
`DEFAULT_REQUIRED_RECOVERY_SYSTEMS = 3` of the following 4 distributed systems
(`server/blackout_recovery_manager.gd`). No single system alone restores power.

| System ID | Display Name | Category | Room | Mechanic | Duration |
|---|---|---|---|---|---|
| `generator` | Generator | power | Generator Room | Restart the generator: hold ignition + throttle steady for 3s. | 10s |
| `power_routing` | Power Routing | electrical | Power Routing Alcove (off Generator Room) | Reconnect 3 severed relay lines to matching colored ports. | 9s |
| `security_relay` | Security Relay | security | Security Room | Re-sync the relay clock by nudging a dial into a narrow target window. | 8s |
| `cooling` | Cooling | life_support | Cooling Hub (Generator Room) | Vent pressure via 2 valves without exceeding the redline. | 9s |

**Design intent:** deliberately weighted toward the Generator Room cluster (2 of 4 systems +
the alcove/hub) and Security Room (1 of 4) — this rewards Crew who coordinate a "power team"
splitting between that cluster and Security, while leaving the 4th system's absence from
Cafeteria/Office/MedBay/Lab/Storage as a design choice: those rooms stay purely for tasking and
alibi-building, never for a race to end the blackout. See `map_station_layout.md` §2 for exact
traversal times between these stations.

---

## 5. Meltdown Emergency Tasks (`MeltdownConfig.ALL_EMERGENCY_SYSTEMS`)

All 3 must be completed before the fixed 300-second (5-minute) Meltdown timer expires
(`server/meltdown_manager.gd`). Only active (alive, non-eliminated) Crew may act on them.

| System ID | Display Name | Room | Mechanic | Duration (no interference) |
|---|---|---|---|---|
| `restore_power` | Restore Power | Generator Room | Escalated version of `repair_power`: 4 breakers instead of 2, tighter timing window. | 15s |
| `restore_cooling` | Restore Cooling | Cooling Hub | Escalated `coolant_system`: 3 valves, redline shrinks over time. | 15s |
| `stabilize_orion` | Stabilize ORION | ORION Core Chamber | Escalated `stabilize_orion` Crew task: 4 sliders instead of 3, band narrows over time. | 18s |

**Design intent:** each Meltdown task is a harder variant of an existing Phase 1 Crew task at
the same location, so players already know the interaction pattern and the tension comes from
the stakes/timer, not from learning a brand-new mini-game with 5 minutes on the clock. If the
Impostor was not ejected, they can interrupt an in-progress emergency task (interaction and
interference logic owned by Member 2/Member 4); this spec assumes the "no interference" timings
above as the balance baseline — see `config/game_balance_config.json` →
`meltdown.task_duration_no_interference_sec` for the exact per-system values used for pacing
the 300-second budget (3 tasks × ~15–18s each leaves ample slack even with travel time and one
round of interference, by design).

---

## 6. Balance Cross-Reference

All numeric defaults referenced above (task counts, objective count, recovery threshold,
durations) are centralized as the canonical tuning surface in
[`config/game_balance_config.json`](../../config/game_balance_config.json). Any change to a
task/objective duration, count, or catalog membership must be reflected in both that file and
this document, and requires Member 6 review per `TEAM_SPLIT.md` §6 (Design Integrity Rule).
