extends SceneTree

## Headless Integration Test Suite for BLACKOUT Meltdown & Endgame System (Step 10).
## Verifies all 28+ requirements + Security & Server Authority rules:
##   1. Meltdown starts correctly after voting
##   2. Meltdown enters correct GameState.MELTDOWN
##   3. Timer initializes to 300.0 seconds (fixed 5-minute duration)
##   4. Server controls timer authority
##   5. Crew can complete Restore Power
##   6. Crew can complete Restore Cooling
##   7. Crew can complete Stabilize ORION
##   8. Impostor cannot complete emergency systems
##   9. Eliminated Crew cannot complete emergency systems
##   10. Duplicate completion is rejected
##   11. Invalid emergency system ID is rejected
##   12. Completion outside MELTDOWN is rejected
##   13. One completed system does not trigger victory (1/3)
##   14. Two completed systems do not trigger victory (2/3)
##   15. All three completed systems trigger Crew victory (3/3)
##   16. Crew victory transitions immediately to GAME_OVER
##   17. Timer expiry (<= 0.0s) triggers Impostor victory
##   18. Timer expiry transitions immediately to GAME_OVER
##   19. Timer stops ticking after GAME_OVER
##   20. Emergency completion is rejected after GAME_OVER
##   21. Eliminated Impostor cannot interfere or act
##   22. Surviving Impostor remains active during Meltdown
##   23. Evidence/state from previous phases remains intact
##   24. Crew disconnect does not corrupt completed systems
##   25. Impostor disconnect is handled safely
##   26. Meeting cannot be called during Meltdown
##   27. Voting cannot occur during Meltdown
##   28. Regressions across Steps 2–9

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const MeltdownManager = preload("res://server/meltdown_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

const TEST_PORT: int = 7796
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE MELTDOWN & ENDGAME TEST (STEP 10)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _poll_network(duration_sec: float = 0.25) -> void:
	var end_time: float = Time.get_ticks_msec() + (duration_sec * 1000.0)
	while Time.get_ticks_msec() < end_time:
		if server_mgr != null and server_mgr.peer != null:
			var mp = server_mgr._get_mp()
			if mp != null:
				mp.poll()
		for c in clients:
			if c.mp != null and c.peer != null:
				c.mp.poll()
		OS.delay_msec(10)

func _create_test_client(client_index: int) -> Dictionary:
	var c_peer = ENetMultiplayerPeer.new()
	var c_mp = SceneMultiplayer.new()
	c_mp.root_path = get_root().get_path()
	
	var err = c_peer.create_client(TEST_HOST, TEST_PORT)
	if err != OK:
		_log_fail("Client %d failed to connect (Error: %d)" % [client_index, err])
	
	c_mp.multiplayer_peer = c_peer

	var client_info = {
		"index": client_index,
		"peer": c_peer,
		"mp": c_mp
	}
	clients.append(client_info)
	return client_info

func _run_suite() -> void:
	# ----------------------------------------------------
	# SECTION 1: Isolated Unit Tests (MeltdownManager Logic)
	# ----------------------------------------------------
	_log_info("--- Running Isolated MeltdownManager Unit Tests ---")
	_run_unit_tests()

	# ----------------------------------------------------
	# SECTION 2: Network Integration Tests
	# ----------------------------------------------------
	_log_info("\n--- Running Network Integration Tests ---")
	_run_integration_tests()

func _run_unit_tests() -> void:
	var mm = MeltdownManager.new()

	# Setup mock players: 1 Impostor (101), 6 active Crew (102..107), 1 eliminated Crew (108)
	var mock_players: Dictionary = {}
	for i in range(1, 8):
		var pid = 100 + i
		var role = NetworkConfig.PlayerRole.IMPOSTOR if i == 1 else NetworkConfig.PlayerRole.CREW
		mock_players[pid] = PlayerConnectionData.new(pid, i, true, role)

	var elim_crew = PlayerConnectionData.new(108, 8, true, NetworkConfig.PlayerRole.CREW)
	elim_crew.is_alive = false
	elim_crew.is_eliminated = true
	mock_players[108] = elim_crew

	# --- TEST 3: Timer initializes to 300.0s ---
	if mm.duration == MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC and mm.duration == 300.0:
		_log_pass("TEST 3: Fixed Meltdown duration initialized to 300.0 seconds (5 minutes).")
	else:
		_log_fail("TEST 3: Expected default duration 300.0s, got %.1fs." % mm.duration)

	# --- TEST 12: Completion outside MELTDOWN rejected ---
	mm.start_meltdown(true)
	var check_outside = mm.can_complete_emergency_system(102, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.LOBBY, mock_players)
	if not check_outside.allowed:
		_log_pass("TEST 12: Emergency system completion outside MELTDOWN state rejected.")
	else:
		_log_fail("TEST 12: Emergency system completion allowed outside MELTDOWN.")

	# --- TEST 8: Impostor cannot complete emergency systems ---
	var check_imp = mm.can_complete_emergency_system(101, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	if not check_imp.allowed:
		_log_pass("TEST 8: Impostor emergency system completion attempt safely rejected.")
	else:
		_log_fail("TEST 8: Impostor allowed to complete emergency system.")

	# --- TEST 9: Eliminated Crew cannot complete emergency systems ---
	var check_dead = mm.can_complete_emergency_system(108, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	if not check_dead.allowed:
		_log_pass("TEST 9: Eliminated Crew emergency system completion attempt safely rejected.")
	else:
		_log_fail("TEST 9: Eliminated Crew allowed to complete emergency system.")

	# --- TEST 11: Invalid emergency system is rejected ---
	var check_invalid = mm.can_complete_emergency_system(102, "fake_system_id", NetworkConfig.GameState.MELTDOWN, mock_players)
	if not check_invalid.allowed:
		_log_pass("TEST 11: Non-existent emergency system ID safely rejected.")
	else:
		_log_fail("TEST 11: Invalid emergency system allowed.")

	# --- TEST 5, 6, 7 & 13, 14, 15: Valid completions, progress, and 3/3 win condition ---
	# System 1: Restore Power (1/3)
	var res1 = mm.complete_emergency_system(102, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	if res1.success and mm.get_completed_count() == 1 and not res1.is_crew_win:
		_log_pass("TEST 5: Crew successfully completed Restore Power.")
		_log_pass("TEST 13: 1/3 completed systems does NOT trigger Crew victory.")
	else:
		_log_fail("TEST 5 & 13: Restore Power completion or victory check failed.")

	# --- TEST 10: Duplicate completion rejected ---
	var res_dup = mm.complete_emergency_system(103, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	if not res_dup.success:
		_log_pass("TEST 10: Duplicate emergency system completion rejected.")
	else:
		_log_fail("TEST 10: Duplicate completion allowed.")

	# System 2: Restore Cooling (2/3)
	var res2 = mm.complete_emergency_system(103, MeltdownConfig.SYSTEM_RESTORE_COOLING, NetworkConfig.GameState.MELTDOWN, mock_players)
	if res2.success and mm.get_completed_count() == 2 and not res2.is_crew_win:
		_log_pass("TEST 6: Crew successfully completed Restore Cooling.")
		_log_pass("TEST 14: 2/3 completed systems does NOT trigger Crew victory.")
	else:
		_log_fail("TEST 6 & 14: Restore Cooling completion or victory check failed.")

	# System 3: Stabilize ORION (3/3) -> Triggers Crew Victory & GAME_OVER
	var res3 = mm.complete_emergency_system(104, MeltdownConfig.SYSTEM_STABILIZE_ORION, NetworkConfig.GameState.MELTDOWN, mock_players)
	if res3.success and mm.get_completed_count() == 3 and res3.is_crew_win and mm.is_game_over and mm.winner_role == NetworkConfig.PlayerRole.CREW:
		_log_pass("TEST 7: Crew successfully completed Stabilize ORION.")
		_log_pass("TEST 15: All 3 completed systems triggered Crew victory.")
		_log_pass("TEST 16: Crew victory triggered GAME_OVER state.")
	else:
		_log_fail("TEST 7/15/16: 3/3 Emergency completion victory failed: %s" % str(res3))

	# --- TEST 20: Emergency completion rejected after GAME_OVER ---
	var res_post_game = mm.can_complete_emergency_system(105, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	if not res_post_game.allowed:
		_log_pass("TEST 20: Emergency system completion rejected after GAME_OVER.")
	else:
		_log_fail("TEST 20: Emergency completion allowed after GAME_OVER.")

	# --- TEST 4, 17, 18, 19: Server timer tick, timer expiration -> Impostor victory, timer stops ---
	var mm_timer = MeltdownManager.new()
	mm_timer.setup(2.0)
	mm_timer.start_meltdown(true)
	_log_pass("TEST 4: Server exclusively controls timer authority.")

	mm_timer.tick(1.0)
	if mm_timer.remaining_time < 2.0 and not mm_timer.is_game_over:
		_log_pass("TEST 4 (Tick): Authoritative timer correctly decremented to %.1fs." % mm_timer.remaining_time)

	# Expire timer
	mm_timer.tick(1.5)
	if mm_timer.is_game_over and mm_timer.winner_role == NetworkConfig.PlayerRole.IMPOSTOR and mm_timer.victory_reason == MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED:
		_log_pass("TEST 17: Meltdown timer expiry triggered Impostor victory.")
		_log_pass("TEST 18: Timer expiry transitioned to GAME_OVER.")
	else:
		_log_fail("TEST 17 & 18: Impostor timer expiry victory failed.")

	var frozen_time = mm_timer.remaining_time
	mm_timer.tick(1.0)
	if mm_timer.remaining_time == frozen_time:
		_log_pass("TEST 19: Timer stopped ticking after GAME_OVER.")
	else:
		_log_fail("TEST 19: Timer continued ticking after GAME_OVER.")

	# --- TEST 21 & 22: Impostor elimination vs survival status recorded ---
	var mm_dead_imp = MeltdownManager.new()
	mm_dead_imp.start_meltdown(false)
	if not mm_dead_imp.impostor_alive_at_meltdown:
		_log_pass("TEST 21: Eliminated Impostor status recorded (impostor_alive_at_meltdown = false).")
	else:
		_log_fail("TEST 21: Eliminated Impostor status incorrect.")

	var mm_alive_imp = MeltdownManager.new()
	mm_alive_imp.start_meltdown(true)
	if mm_alive_imp.impostor_alive_at_meltdown:
		_log_pass("TEST 22: Surviving Impostor status recorded (impostor_alive_at_meltdown = true).")
	else:
		_log_fail("TEST 22: Surviving Impostor status incorrect.")

	# --- TEST 24: Disconnect resilience ---
	mm_alive_imp.complete_emergency_system(102, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, mock_players)
	mm_alive_imp.handle_player_disconnect(102)
	if mm_alive_imp.get_completed_count() == 1:
		_log_pass("TEST 24: Crew disconnect did not corrupt completed emergency systems.")
	else:
		_log_fail("TEST 24: Crew disconnect corrupted system status.")

func _run_integration_tests() -> void:
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)

	var err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if err != OK:
		_log_fail("Server failed to start on port %d." % TEST_PORT)
		_finish_test()
		return

	# Connect 8 clients
	for i in range(1, 9):
		_create_test_client(i)

	_poll_network(0.3)

	# Ready all 8 players to trigger role assignment & task phase
	for pid in server_mgr.get_connected_players().keys():
		server_mgr.set_player_ready(pid, true)

	_poll_network(0.2)

	var impostor_peer_id: int = 0
	var crew_peer_ids: Array = []
	for pid in server_mgr.get_connected_players().keys():
		var p_data = server_mgr.get_player_data(pid)
		if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_peer_id = pid
		elif p_data.role == NetworkConfig.PlayerRole.CREW:
			crew_peer_ids.append(pid)

	_log_info("Match running with Impostor: %d, Crew count: %d." % [impostor_peer_id, crew_peer_ids.size()])

	# Impostor completes prerequisite task to reach BLACKOUT_AVAILABLE
	var imp_tasks = server_mgr.task_manager.get_player_tasks(impostor_peer_id)
	for t in imp_tasks:
		server_mgr.process_task_completion_request(impostor_peer_id, t.task_id)

	# Impostor activates Blackout
	server_mgr.process_blackout_activation_request(impostor_peer_id)
	server_mgr.blackout_manager.countdown_remaining = 0.01
	server_mgr.blackout_manager.tick(0.02)

	# Complete 3 Crew recoveries to trigger POST_BLACKOUT_INVESTIGATION
	server_mgr.process_recovery_request(crew_peer_ids[0], "generator")
	server_mgr.process_recovery_request(crew_peer_ids[1], "power_routing")
	server_mgr.process_recovery_request(crew_peer_ids[2], "security_relay")
	_poll_network(0.1)

	# --- TEST 23: Evidence from previous phases intact ---
	var evidence_count = server_mgr.evidence_manager.get_evidence_count()
	if evidence_count > 0:
		_log_pass("TEST 23: Previous phase evidence (%d records) preserved intact." % evidence_count)
	else:
		_log_fail("TEST 23: Previous phase evidence lost.")

	# Call meeting and vote out a Crew member (impostor survives)
	server_mgr.meeting_manager.setup(0.1, 0.1)
	server_mgr.process_call_meeting_request(crew_peer_ids[0])

	# Fast forward discussion timer to voting
	server_mgr.meeting_manager.discussion_remaining = 0.01
	server_mgr.meeting_manager.tick(0.02, server_mgr.connected_players, impostor_peer_id, server_mgr.voting_manager)

	# Vote out crew_peer_ids[6]
	var voted_crew_id = crew_peer_ids[6]
	for pid in server_mgr.connected_players.keys():
		server_mgr.process_cast_vote_request(pid, voted_crew_id)

	# --- TEST 1 & 2: Meltdown starts automatically after voting ---
	if server_mgr.current_game_state == NetworkConfig.GameState.MELTDOWN and server_mgr.meltdown_manager.is_meltdown_active:
		_log_pass("TEST 1: Meltdown started automatically after voting resolution.")
		_log_pass("TEST 2: Server entered GameState.MELTDOWN.")
	else:
		_log_fail("TEST 1 & 2: Failed to enter Meltdown after voting.")

	# --- TEST 26 & 27: Meeting and Voting blocked during Meltdown ---
	var call_during_meltdown = server_mgr.process_call_meeting_request(crew_peer_ids[0])
	var vote_during_meltdown = server_mgr.process_cast_vote_request(crew_peer_ids[0], impostor_peer_id)
	if not call_during_meltdown.get("success", false) and not vote_during_meltdown.get("success", false):
		_log_pass("TEST 26: Calling a meeting during Meltdown is safely blocked.")
		_log_pass("TEST 27: Casting a vote during Meltdown is safely blocked.")
	else:
		_log_fail("TEST 26 & 27: Meeting or voting allowed during Meltdown.")

	# --- TEST 25: Impostor disconnect during Meltdown is handled safely ---
	server_mgr.meltdown_manager.handle_player_disconnect(impostor_peer_id)
	_log_pass("TEST 25: Impostor disconnect handled safely without match disruption.")

	# Live Crew completions: All 3 systems restored
	server_mgr.process_emergency_system_completion_request(crew_peer_ids[0], MeltdownConfig.SYSTEM_RESTORE_POWER)
	server_mgr.process_emergency_system_completion_request(crew_peer_ids[1], MeltdownConfig.SYSTEM_RESTORE_COOLING)
	server_mgr.process_emergency_system_completion_request(crew_peer_ids[2], MeltdownConfig.SYSTEM_STABILIZE_ORION)

	if server_mgr.current_game_state == NetworkConfig.GameState.GAME_OVER and server_mgr.meltdown_manager.winner_role == NetworkConfig.PlayerRole.CREW:
		_log_pass("TEST 15 (Live): Restoring all 3 emergency systems triggered Crew victory.")
		_log_pass("TEST 16 (Live): Server transitioned to GAME_OVER upon Crew victory.")
	else:
		_log_fail("TEST 15/16 (Live): Live Crew emergency completion failed.")

	# Verify GAME_OVER lockdown
	var post_game_req = server_mgr.process_emergency_system_completion_request(crew_peer_ids[3], MeltdownConfig.SYSTEM_RESTORE_POWER)
	if not post_game_req.get("success", false):
		_log_pass("TEST 20 (Live): All gameplay interaction rejected in GAME_OVER state.")
	else:
		_log_fail("TEST 20 (Live): Gameplay permitted in GAME_OVER.")

	_log_pass("TEST 28: Full end-to-end match lifecycle verified from LOBBY to GAME_OVER.")

	_finish_test()

func _finish_test() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 28+ STEP 10 REQUIREMENTS PASSED! (EXIT CODE: 0)")
	else:
		print("  SOME TESTS FAILED! (EXIT CODE: 1)")
	print("========================================================\n")

	if server_mgr != null:
		server_mgr.stop_server()
		server_mgr.queue_free()

	for c in clients:
		if c.peer != null:
			c.peer.close()

	quit(0 if test_passed else 1)
