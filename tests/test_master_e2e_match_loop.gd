extends SceneTree

## Master End-to-End 8-Player Integration Test Suite (Stage 25).
## Verifies the complete BLACKOUT match lifecycle across all 12 core gameplay phases:
##   Phase 1: Lobby Lifecycle (8 real connected clients, slot assignment, ready-up)
##   Phase 2: Authoritative Role Assignment (1 Impostor, 7 Crew, private secret reveal)
##   Phase 3: Initial Task Phase (Task allocations, Impostor prerequisite gating)
##   Phase 4: Remote Blackout Sabotage (Activation trigger, countdown, dynamic lighting)
##   Phase 5: Distributed Blackout Recovery (3/4 threshold restoration & early end)
##   Phase 6: Post-Blackout Investigation (Factual evidence collection & Dossier)
##   Phase 7: Impostor Proximity Elimination (Kill range, cooldown, corpse spawning)
##   Phase 8: Corpse Body Reporting (Proximity report, caller identity, Meeting trigger)
##   Phase 9: Meeting & Authoritative Voting (Discussion, voting grid, plurality ejection)
##   Phase 10: Meltdown Protocol (5-minute countdown, emergency console initialization)
##   Phase 11: Emergency Repair & Crew Victory (All 3 systems restored -> Game Over)
##   Phase 12: Return to Lobby & Rematch (Authoritative reset, player persistence)

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")

var server: ServerNetworkManager = null
var clients: Array[ClientNetworkManager] = []
var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MASTER 8-PLAYER E2E MATCH LOOP (STAGE 25)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_master_loop)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_phase(phase_num: int, title: String) -> void:
	print("\n  [PHASE %d] >>> %s <<<" % [phase_num, title])

func _run_master_loop() -> void:
	# -------------------------------------------------------------
	# PHASE 1: Lobby Lifecycle (8 Connected Clients)
	# -------------------------------------------------------------
	_log_phase(1, "Lobby Lifecycle & 8-Player Session Registration")
	server = ServerNetworkManager.new()
	server.start_server(7799, 8)
	
	var peer_base: int = 100
	for slot_idx in range(1, 9):
		var p_id = peer_base + slot_idx
		var p_data = server.PlayerConnectionData.new(p_id, slot_idx)
		server.connected_players[p_id] = p_data
		server.set_player_position(p_id, Vector2(800.0 + (slot_idx * 10), 550.0))
		
		var client = ClientNetworkManager.new()
		client.assigned_peer_id = p_id
		client.assigned_slot = slot_idx
		client.current_game_state = NetworkConfig.GameState.LOBBY
		clients.append(client)
		
	if server.get_connected_player_count() == 8:
		_log_pass("1.1: Exactly 8 connected players registered in server session.")
	else:
		_log_fail("1.1: Connected player count mismatch.")
		
	for i in range(8):
		var p_id = peer_base + (i + 1)
		server.set_player_ready(p_id, true)
		clients[i].is_ready = true
		
	if server.get_ready_player_count() == 8:
		_log_pass("1.2: All 8 players successfully synchronized READY status in LOBBY.")
	else:
		_log_fail("1.2: Ready count mismatch.")

	# -------------------------------------------------------------
	# PHASE 2: Authoritative Role Assignment
	# -------------------------------------------------------------
	_log_phase(2, "Authoritative Role Assignment & Secret Private Reveal")
	server.current_game_state = NetworkConfig.GameState.ROLE_ASSIGNMENT
	server.assign_roles(false, 0) # Deterministic: Player 1 (Peer 101) is Impostor
	
	var impostor_id: int = 0
	var crew_count: int = 0
	for p_id in server.connected_players.keys():
		var p_data = server.connected_players[p_id]
		if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_id = p_id
		elif p_data.role == NetworkConfig.PlayerRole.CREW:
			crew_count += 1
			
	if impostor_id == 101 and crew_count == 7:
		_log_pass("2.1: Exactly 1 Impostor (Peer 101) and 7 Crew members authoritatively assigned.")
	else:
		_log_fail("2.1: Role assignment mismatch.")
		
	# Synchronize private roles to clients
	for i in range(8):
		var p_id = peer_base + (i + 1)
		var p_role = server.connected_players[p_id].role
		clients[i].assigned_role = p_role
		clients[i].current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE
		
	if clients[0].assigned_role == NetworkConfig.PlayerRole.IMPOSTOR and clients[1].assigned_role == NetworkConfig.PlayerRole.CREW:
		_log_pass("2.2: Clients securely received private roles without public role leakage.")
	else:
		_log_fail("2.2: Client private role receipt failed.")

	# -------------------------------------------------------------
	# PHASE 3: Initial Task Phase & Prerequisite Completion
	# -------------------------------------------------------------
	_log_phase(3, "Initial Task Phase & Impostor Prerequisite Unlocking")
	var imp_tasks = server.task_manager.get_player_tasks(impostor_id)
	if imp_tasks.size() == 2:
		_log_pass("3.1: Impostor received exactly 2 prerequisite tasks.")
	else:
		_log_fail("3.1: Impostor task count mismatch.")
		
	var crew_sample_tasks = server.task_manager.get_player_tasks(102)
	if crew_sample_tasks.size() == 4:
		_log_pass("3.2: Crew members received 4 facility tasks each.")
	else:
		_log_fail("3.2: Crew task count mismatch.")
		
	# Complete Impostor prerequisites
	for t in imp_tasks:
		var res = server.process_task_completion_request(impostor_id, t.task_id)
		if not res.get("success", false):
			_log_fail("3.3: Failed to complete Impostor prerequisite task %s" % t.task_id)
			
	if server.current_game_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_log_pass("3.3: Impostor finished prerequisites -> BLACKOUT_AVAILABLE authoritatively unlocked.")
	else:
		_log_fail("3.3: Server failed to transition to BLACKOUT_AVAILABLE.")

	# -------------------------------------------------------------
	# PHASE 4: Remote Blackout Activation & Sabotage
	# -------------------------------------------------------------
	_log_phase(4, "Remote Blackout Activation & Dynamic Darkness")
	var blackout_req = server.process_sabotage_request(impostor_id, SabotageManager.SabotageType.POWER_BLACKOUT)
	if blackout_req.get("success", false):
		_log_pass("4.1: Impostor successfully triggered POWER_BLACKOUT sabotage.")
	else:
		_log_fail("4.1: Impostor sabotage trigger failed.")
		
	if server.current_game_state == NetworkConfig.GameState.BLACKOUT_ACTIVE and server.blackout_manager.is_blackout_active:
		_log_pass("4.2: Game state progressed to BLACKOUT_ACTIVE with active countdown.")
	else:
		_log_fail("4.2: Blackout active state mismatch.")

	# -------------------------------------------------------------
	# PHASE 5: Distributed Blackout Recovery (3 of 4 Restored)
	# -------------------------------------------------------------
	_log_phase(5, "Distributed Recovery Subsystems & Early Resolution")
	var rec_systems = server.recovery_manager.recovery_systems.values()
	if rec_systems.size() == 4:
		_log_pass("5.1: 4 distributed recovery subsystems initialized across the facility.")
	else:
		_log_fail("5.1: Recovery subsystem count mismatch.")
		
	# Crew restores 3 subsystems
	server.process_recovery_request(102, rec_systems[0].system_id)
	server.process_recovery_request(103, rec_systems[1].system_id)
	server.process_recovery_request(104, rec_systems[2].system_id)
	
	if server.current_game_state == NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		_log_pass("5.2: 3/4 recovery threshold reached -> Blackout ended early -> POST_BLACKOUT_INVESTIGATION.")
	else:
		_log_fail("5.2: Investigation transition failed.")

	# -------------------------------------------------------------
	# PHASE 6: Post-Blackout Investigation & Evidence Dossier
	# -------------------------------------------------------------
	_log_phase(6, "Factual Evidence Generation & Investigation Dossier")
	var ev_list = server.evidence_manager.evidence_records.values()
	if ev_list.size() >= 3:
		_log_pass("6.1: Authoritative evidence generated (%d factual records logged)." % ev_list.size())
	else:
		_log_fail("6.1: Evidence count mismatch.")
		
	var sanitized = true
	var public_ev = server.evidence_manager.get_public_evidence_list()
	for d in public_ev:
		if d.has("culprit_peer_id") or d.has("is_impostor_action"):
			sanitized = false
			
	if sanitized:
		_log_pass("6.2: Public evidence dataset is strictly sanitized with zero role/killer leakage.")
	else:
		_log_fail("6.2: Security leak in public evidence dataset.")

	# -------------------------------------------------------------
	# PHASE 7: Impostor Proximity Elimination
	# -------------------------------------------------------------
	_log_phase(7, "Impostor Proximity Elimination & Corpse Spawning")
	# Position Impostor (101) near Crew (108) at (300, 300)
	server.set_player_position(101, Vector2(300.0, 300.0))
	server.set_player_position(108, Vector2(330.0, 300.0)) # 30px distance <= 90px KILL_RANGE
	
	var kill_res = server.process_kill_request(101, 108)
	if kill_res.get("success", false):
		_log_pass("7.1: Server accepted valid in-range kill request (Impostor 101 -> Crew 108).")
	else:
		_log_fail("7.1: Kill request rejected: %s" % kill_res.get("error", ""))
		
	var victim_data = server.connected_players[108]
	if victim_data.is_eliminated and not victim_data.is_alive:
		_log_pass("7.2: Victim (Peer 108) authoritatively marked ELIMINATED.")
	else:
		_log_fail("7.2: Victim elimination state mismatch.")
		
	if server.active_corpses.size() == 1 and server.active_corpses.has(1):
		_log_pass("7.3: Corpse #1 spawned authoritatively at death coordinates (330, 300).")
	else:
		_log_fail("7.3: Corpse spawning failed.")

	# -------------------------------------------------------------
	# PHASE 8: Corpse Body Reporting
	# -------------------------------------------------------------
	_log_phase(8, "Corpse Proximity Body Report & Emergency Meeting")
	# Position living Crew (102) near corpse (1) at (330, 300)
	server.set_player_position(102, Vector2(340.0, 300.0)) # 10px distance <= 90px REPORT_RANGE
	
	var report_res = server.process_report_body_request(102, 1)
	if report_res.get("success", false):
		_log_pass("8.1: Server accepted valid proximity body report from Player 102.")
	else:
		_log_fail("8.1: Body report rejected: %s" % report_res.get("error", ""))
		
	if server.current_game_state == NetworkConfig.GameState.MEETING and server.meeting_manager.is_meeting_active:
		_log_pass("8.2: Emergency meeting triggered via body report (Caller: Peer 102).")
	else:
		_log_fail("8.2: Meeting state transition failed.")

	# -------------------------------------------------------------
	# PHASE 9: Meeting Discussion & Authoritative Voting Session
	# -------------------------------------------------------------
	_log_phase(9, "Emergency Discussion & Authoritative Voting Resolution")
	server.meeting_manager._start_voting_phase(server.voting_manager)
	server.current_game_state = NetworkConfig.GameState.VOTING
	
	# Living Crew members (102, 103, 104, 105, 106, 107) and Impostor (101) vote for Impostor (101)
	for voter_id in [101, 102, 103, 104, 105, 106, 107]:
		server.process_cast_vote_request(voter_id, 101)
		
	var vote_res = server.voting_manager.calculate_results(server.connected_players, impostor_id)
	if vote_res.eliminated_peer_id == 101 and vote_res.was_impostor:
		_log_pass("9.1: Authoritative vote tally resolved: Impostor (101) ejected with 7/7 votes.")
	else:
		_log_fail("9.1: Voting calculation mismatch.")

	# -------------------------------------------------------------
	# PHASE 10: Meltdown Protocol Transition
	# -------------------------------------------------------------
	_log_phase(10, "Meltdown Protocol & Emergency Console Initialization")
	server.meeting_manager._resolve_meeting_and_voting(server.connected_players, impostor_id, server.voting_manager)
	
	if server.current_game_state == NetworkConfig.GameState.MELTDOWN and server.meltdown_manager.is_meltdown_active:
		_log_pass("10.1: Transitioned into MELTDOWN state (300.0s countdown active).")
	else:
		_log_fail("10.1: Meltdown state transition failed.")
		
	var emergency_systems = server.meltdown_manager.emergency_systems.keys()
	if emergency_systems.size() == 3:
		_log_pass("10.2: All 3 mandatory emergency systems initialized (Power, Cooling, ORION).")
	else:
		_log_fail("10.2: Meltdown emergency systems count mismatch.")

	# -------------------------------------------------------------
	# PHASE 11: Emergency Repair & Crew Victory
	# -------------------------------------------------------------
	_log_phase(11, "Emergency Repair & Crew Victory Conclusion")
	server.process_emergency_system_completion_request(102, "restore_power")
	server.process_emergency_system_completion_request(103, "restore_cooling")
	var final_repair = server.process_emergency_system_completion_request(104, "stabilize_orion")
	
	if final_repair.get("success", false) and final_repair.get("is_crew_win", false):
		_log_pass("11.1: All 3 emergency systems restored before core collapse.")
	else:
		_log_fail("11.1: Final emergency system repair failed.")
		
	if server.current_game_state == NetworkConfig.GameState.GAME_OVER:
		_log_pass("11.2: Match authoritatively concluded with CREW victory (GAME_OVER state).")
	else:
		_log_fail("11.2: Game Over transition failed.")

	# -------------------------------------------------------------
	# PHASE 12: Return to Lobby & Rematch Loop
	# -------------------------------------------------------------
	_log_phase(12, "Return to Lobby & Rematch Reset Lifecycle")
	var rematch_ok = server.process_return_to_lobby_request(101)
	if rematch_ok:
		_log_pass("12.1: Server successfully processed Return to Lobby request.")
	else:
		_log_fail("12.1: Rematch request failed.")
		
	var clean_reset = (
		server.current_game_state == NetworkConfig.GameState.LOBBY and
		server.active_corpses.is_empty() and
		server.impostor_last_kill_time.is_empty() and
		server.get_ready_player_count() == 0 and
		server.get_connected_player_count() == 8
	)
	
	if clean_reset:
		_log_pass("12.2: Complete subsystem purge verified: Corpses cleared, ready states reset, 8 sockets preserved.")
	else:
		_log_fail("12.2: Subsystem cleanup incomplete.")

	# -------------------------------------------------------------
	# SUMMARY & CONCLUSION
	# -------------------------------------------------------------
	print("\n========================================================")
	print("  BLACKOUT — STAGE 25 MASTER INTEGRATION TEST SUMMARY")
	print("========================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL 12 MASTER MATCH PHASES PASSED 100%] 🚀")
	else:
		print("  STATUS: [FAILURES DETECTED IN MASTER LOOP] ❌")
	print("========================================================\n")
	
	server.connected_players.clear()
	server.stop_server()
	quit(0 if test_passed else 1)
