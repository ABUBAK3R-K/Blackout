# BLACKOUT — Map & Station Layout

**Owner:** Member 6 (Abubaker) — Game Systems & Content Designer
**Branch:** `member-6/game-design`
**Companion docs:** [`design.md`](../../design.md) §4 (map design intent),
[`task_specifications.md`](./task_specifications.md) (station mechanics),
[`evidence_matrix.md`](./evidence_matrix.md) (location-tagged evidence)

This document is the canonical facility floorplan: the 9 rooms from `design.md`/`PRD.md`,
their connectivity, traversal times, and exactly which task/objective/recovery-system
`location_id` (as used by `shared/*_config.gd`) lives in each room. It exists so Member 3
(client/rendering), Member 4 (station placement), and Member 7 (tilemap art) build against one
shared reference instead of each inferring room layout independently.

---

## 1. Reconciliation Note (Read First)

`design.md` §4's original room-role table predates the Step 5–7 backend implementation and
does not line up 1:1 with the `location_id` strings actually used in
`shared/evidence_config.gd` and `shared/blackout_objective_config.gd`
(e.g. `executive_office`, `containment_hub`, `power_room`, `cooling_hub` — none of which are
named rooms in the original 9-room list). This document is the authoritative reconciliation:
it keeps the original 9 primary rooms but places those `location_id`s as clearly-labeled
sub-areas within/adjacent to a primary room, and formally moves the **Confidential File Theft**
objective from "Laboratory" (design.md's original placement) to **Office**, matching what
`evidence_config.gd` actually implements (`executive_office` → "Executive Office", a restricted
sub-area of the Office room). Office's role therefore upgrades from "low sabotage relevance" to
the flagship espionage objective's location — being seen in the Office during a blackout is now
a meaningful tell, which is a stronger read on the source concept's "Executive Office" framing
than the design.md draft's Laboratory placement.

---

## 2. Room Table

| # | Room | Primary Role | Crew Tasks | Recovery Systems | Impostor Objectives |
|---|---|---|---|---|---|
| 1 | Cafeteria | Social hub / spawn area, no forced task or system — pure alibi/traffic room | — | — | — |
| 2 | Security Room | Camera monitoring (disabled in blackout), security sabotage target | `security_repair` | `security_relay` | `tamper_security` |
| 3 | Laboratory | Restricted research work, sample handling | `laboratory_org` | — | — |
| 4 | Server Room | Data/comms infrastructure | `server_calibration`, `data_transfer` | — | — |
| 5 | Storage | Equipment & backup gear, evidence-hiding flavor | `backup_power` | — | — |
| 6 | Generator Room | Primary power cluster (incl. Power Routing Alcove, Cooling Hub sub-areas) | `repair_power`, `coolant_system` | `generator`, `power_routing`, `cooling` | `sabotage_generator` |
| 7 | Office | General work; Executive Office sub-area is restricted-access, espionage target | — | — | `steal_confidential_files` (at `executive_office`) |
| 8 | Medical Bay | Medical supply checks, general traffic | `medical_supply_check` | — | — |
| 9 | ORION Core Chamber | Core stabilization, data extraction, containment (incl. Containment Hub sub-area) | `stabilize_orion` | — | `extract_orion_core_data`, `disable_orion_containment` (at `containment_hub`) |
| — | Maintenance Corridor | Connective corridor, not a room proper — hosts the one "in-transit" task | `door_repair` | — | — |

Cafeneteria and Laboratory/Server Room/Storage/Medical Bay intentionally hold **no** recovery
system or objective — they exist purely for Phase-1 tasking and alibi-building, so that not
every room is a hotspot (`design.md` §4's "avoid rooms that exist purely as connective tissue"
is satisfied by giving every room at least one task, while still keeping the recovery/objective
"hotspots" concentrated in Generator Room, Security Room, ORION Core Chamber, and Office).

---

## 3. Connectivity & Traversal Times

Facility layout as a single ring corridor with three cross-links, matching a compact 9-room
research facility footprint. Traversal times are design targets for Member 3's movement speed
tuning (walking, uninterrupted, adjacent-room door-to-door):

```
        Cafeteria ──── Security Room ──── Office
            │                                │
     Medical Bay                    ORION Core Chamber
            │                                │
        Storage ──── Server Room ──── Laboratory
            │
     Generator Room ──(cross-link)── Security Room
            │
  Maintenance Corridor (connects Cafeteria ring ↔ Storage ring)
```

| From → To | Time | Notes |
|---|---|---|
| Cafeteria ↔ Security Room | 5s | Adjacent |
| Security Room ↔ Office | 6s | Adjacent |
| Cafeteria ↔ Medical Bay | 5s | Adjacent |
| Office ↔ ORION Core Chamber | 6s | Adjacent |
| Medical Bay ↔ Storage | 5s | Adjacent |
| ORION Core Chamber ↔ Laboratory | 7s | Adjacent |
| Storage ↔ Server Room | 4s | Adjacent |
| Server Room ↔ Laboratory | 5s | Adjacent |
| Generator Room ↔ Security Room | 6s | Cross-link (shortcut between power cluster and security) |
| Generator Room ↔ Storage | 5s | Cross-link |
| Cafeteria ↔ Storage (via Maintenance Corridor) | 8s | Houses `door_repair`; only route directly linking the two rings without crossing through Medical Bay |
| Opposite corners (e.g. Cafeteria ↔ ORION Core Chamber) | ~16–20s | Full traversal, 3+ rooms |

**Design intent:** the two cross-links (Generator Room ↔ Security Room, Generator Room ↔
Storage) exist specifically so a Crew "power team" splitting between the Generator Room cluster
(2 of 4 recovery systems) and Security Room (1 of 4) isn't punished with a long walk — this
supports the §3.5.2 design tension in `design.md` (splitting up restores power faster but opens
more isolated targets) by making the split *viable*, not just theoretically possible. The
farthest objective pair — Office (`steal_confidential_files`) and ORION Core Chamber
(`extract_orion_core_data` / `disable_orion_containment`) — are adjacent by design, since the
Impostor is assigned 3 of the 5 objectives per match and needs to realistically reach all of
them inside the blackout window (see `config/game_balance_config.json` →
`blackout.duration_sec`).

---

## 4. Alibi Routing Notes

- **Cafeteria and Medical Bay are "safe" rooms** — no recovery system or objective ever places
  the Impostor there, so being seen in either during a blackout is not inherently suspicious;
  these double as natural rendezvous/alibi points if two Crew want to corroborate each other's
  location.
- **Office and ORION Core Chamber are "hot" rooms** — presence there during `BLACKOUT_ACTIVE`
  is not proof of guilt (Crew has no task in either during blackout — the `stabilize_orion`
  Crew task only runs in `INITIAL_TASK_PHASE`/`BLACKOUT_AVAILABLE`, not `BLACKOUT_ACTIVE`, per
  `server/task_manager.gd`), which is precisely what makes a sighting there meaningful
  discussion fodder.
- **Generator Room and Security Room are "mixed" rooms** — both a legitimate Crew recovery
  destination and an Impostor objective location, so presence there is ambiguous by design and
  should provoke "what were you doing there, specifically" discussion rather than an instant
  read.
- **Maintenance Corridor is a deliberate bottleneck** — the only direct link between the two
  room-rings, making it a natural place for players to cross paths and clock each other's
  movement direction, reinforcing the "manual memory, not system-tracked" observation design
  rule (`design.md` §3.5.1).
