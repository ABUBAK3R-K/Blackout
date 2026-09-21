# BLACKOUT — Server-Authority & Anti-Cheat Validation Matrix

> **Author:** Member 8 (Sahil — Audio Designer & QA / Production Lead)  
> **Target Scope:** 100% Server Authoritative Integrity (Zero Client Trust)  
> **Companion Docs:** [`TEAM_SPLIT.md`](../../TEAM_SPLIT.md), [`tests/server_authority_tests/`](../server_authority_tests/)

---

## 1. Threat Model & Security Objectives

BLACKOUT is a competitive, multiplayer social deduction game. Trusting the client for any game-critical outcome (role identity, task progress, blackout triggers, votes, or meltdown timers) compromises match legitimacy.

### Security Guarantees:
1. **Zero Secret Leakage:** The authoritative server NEVER broadcasts the full role table or the Impostor identity to client instances until match finalization.
2. **Server-Validated Actions:** Clients may only send intention requests (`request_complete_task`, `request_trigger_blackout`, `request_cast_vote`, `request_complete_emergency_system`). The server verifies all parameters before mutating match state.
3. **Dead / Eliminated Player Neutralization:** Disconnected or eliminated players are immediately disqualified from voting, repairing stations, or calling meetings.
4. **State Machine Exclusivity:** Actions are valid ONLY within their respective game states.

---

## 2. Threat Vector & Mitigation Matrix

| Threat Vector ID | Threat Description | Attack Method | Server Mitigation Mechanism | Dedicated Automated Test |
|---|---|---|---|---|
| **TV-01** | **Task Spoofing** | Client sends arbitrary task IDs to finish fake tasks | Server looks up task ID in player's assigned task registry; rejects unassigned or non-existent IDs. | `tests/server_authority_tests/test_anti_cheat_tasks.gd` (Test 1 & 2) |
| **TV-02** | **Eliminated Player Action** | Dead player attempts to perform tasks or sabotage | Server verifies `player.is_alive == true` before processing any task or station completion. | `tests/server_authority_tests/test_anti_cheat_tasks.gd` (Test 3) |
| **TV-03** | **Replay / Duplicate Completion** | Client spams completion packets for the same station | Completed tasks/systems are marked `is_completed = true`; subsequent packets are discarded with a warning. | `tests/server_authority_tests/test_anti_cheat_tasks.gd` (Test 4) |
| **TV-04** | **Impostor Task Bar Tampering** | Impostor attempts to complete Crew tasks to alter progress | Impostor receives strictly `is_impostor_prerequisite = true` tasks; Crew task bar tracks only Crew tasks. | `tests/server_authority_tests/test_anti_cheat_tasks.gd` (Test 5) |
| **TV-05** | **Crew Blackout Trigger** | Crew member sends RPC to initiate Blackout | Server verifies caller role is strictly `PlayerRole.IMPOSTOR`; rejects Crew callers. | `tests/server_authority_tests/test_anti_cheat_blackout.gd` (Test 1) |
| **TV-06** | **Premature Blackout** | Impostor triggers Blackout before completing prerequisites | Server checks `completed_prerequisites == required_prerequisites`; rejects premature triggers. | `tests/server_authority_tests/test_anti_cheat_blackout.gd` (Test 2) |
| **TV-07** | **Blackout Spam** | Impostor triggers multiple blackouts simultaneously | Server enforces `is_blackout_active == false` and verifies cooldown expiration before activation. | `tests/server_authority_tests/test_anti_cheat_blackout.gd` (Test 4) |
| **TV-08** | **Fake Recovery Panels** | Client submits fake recovery station IDs | Server checks station ID against active recovery objective table; rejects invalid IDs. | `tests/server_authority_tests/test_anti_cheat_blackout.gd` (Test 5) |
| **TV-09** | **Premature / Late Voting** | Client casts votes before meeting starts or after it ends | Server verifies `current_game_state == GameState.VOTING`; rejects outside votes. | `tests/server_authority_tests/test_anti_cheat_voting.gd` (Test 1) |
| **TV-10** | **Ghost Voting** | Eliminated player casts vote to influence outcome | Server checks voter `is_alive == true`; dead votes are rejected. | `tests/server_authority_tests/test_anti_cheat_voting.gd` (Test 5) |
| **TV-11** | **Vote Hijacking / Double Vote** | Client submits multiple votes in the same round | Server tracks `has_voted` per peer; duplicate submissions in same round are rejected. | `tests/server_authority_tests/test_anti_cheat_voting.gd` (Test 4) |
| **TV-12** | **Phantom Target Vote** | Client votes for non-existent player or self when prohibited | Server verifies target peer ID exists in active player roster. | `tests/server_authority_tests/test_anti_cheat_voting.gd` (Test 2) |
| **TV-13** | **Impostor Meltdown Repair** | Impostor completes emergency systems to force win | Server validates caller role is strictly `PlayerRole.CREW`; Impostor repair attempts are rejected. | `tests/server_authority_tests/test_anti_cheat_meltdown.gd` (Test 2) |
| **TV-14** | **Post-Game Over Exploits** | Client submits interactions after match ends | Server enters `GameState.GAME_OVER` lockdown; all subsequent RPC endpoints reject packets. | `tests/server_authority_tests/test_anti_cheat_meltdown.gd` (Test 6) |

---

## 3. Execution & Regression Cadence

1. **Pre-Commit Gate:** Any PR altering server logic must execute the 4 server-authority test suites with zero failures.
2. **Weekly Playtest Gate:** The 8-player playtest checklist must be completed with server logs inspected for unexpected authority warning spikes.
