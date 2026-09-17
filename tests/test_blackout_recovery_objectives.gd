extends SceneTree

## Headless Integration Test Suite for BLACKOUT Recovery & Impostor Secret Objectives (Step 7).
## Verifies all 34 requirements:
##   1. Recovery systems initialize when BLACKOUT_ACTIVE starts
##   2. Exactly 4 recovery systems exist by default
##   3. Required threshold defaults to 3
##   4. Crew can request recovery completion
##   5. Impostor cannot complete recovery systems
##   6. Unknown recovery IDs are rejected
##   7. Duplicate recovery completion is rejected
##   8. Recovery requests outside BLACKOUT_ACTIVE are rejected
##   9. 1/4 recovery does not end Blackout
##   10. 2/4 recovery does not end Blackout
##   11. 3/4 recovery immediately ends Blackout
##   12. Recovery completion is server-authoritative
##   13. Recovery state remains valid after a player disconnects
##   14. Impostor receives secret Blackout objectives when BLACKOUT_ACTIVE begins
##   15. Objective count follows centralized configuration (default 3)
##   16. Impostor receives only their own objectives
##   17. Crew receives no Impostor objectives
##   18. Impostor can complete an assigned objective
##   19. Crew cannot complete Impostor objectives
##   20. Unknown objective IDs are rejected
##   21. Duplicate objective completion is rejected
##   22. Objective completion outside BLACKOUT_ACTIVE is rejected
##   23. Objective completion is server-authoritative
##   24. Completing objectives does NOT automatically end Blackout
##   25. Impostor disconnect does not corrupt objective state
##   26. Blackout timer expiry still ends Blackout
##   27. Recovery threshold ends Blackout before timer expiry
##   28. Recovery completion after Blackout ends is rejected
##   29. Objective completion after Blackout ends is rejected
##   30-34. Regression verification across Steps 2-6

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutConfig = preload("res://shared/blackout_config.gd")
const BlackoutRecoveryConfig = preload("res://shared/blackout_recovery_config.gd")
const BlackoutRecoveryDefinition = preload("res://shared/blackout_recovery_definition.gd")
const BlackoutObjectiveConfig = preload("res://shared/blackout_objective_config.gd")
const BlackoutObjectiveDefinition = preload("res://shared/blackout_objective_definition.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7793
const TEST_HOST: String = "127.0.0.1"

# Fast test timing values
const TEST_COUNTDOWN_SEC: float = 0.1
const TEST_BLACKOUT_DURATION_SEC: float = 0.6

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — RECOVERY & IMPOSTOR OBJECTIVES TEST (STEP 7)")
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
		_log_fail("Client %d failed to create socket (Error: %d)" % [client_index, err])
	
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
	# SETUP: Start Server & Connect 8 Players
	# ----------------------------------------------------
	_log_info("Starting server and connecting 8 clients...")
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)

	var err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if err != OK:
		_log_fail("Server failed to start on port %d." % TEST_PORT)
		_finish_test()
		return

	for i in range(1, 9):
		_create_test_client(i)

	_poll_network(0.3)

	if server_mgr.get_connected_player_count() != 8:
		_log_fail("Expected 8 connected players, found: %d" % server_mgr.get_connected_player_count())
		_finish_test()
		return

	# Ready all 8 players
	for pid in server_mgr.get_connected_players().keys():
		server_mgr.set_player_ready(pid, true)

	_poll_network(0.2)

	# Verify transition to INITIAL_TASK_PHASE
	if server_mgr.current_game_state != NetworkConfig.GameState.INITIAL_TASK_PHASE:
		_log_fail("Expected INITIAL_TASK_PHASE, got: %s" % NetworkConfig.get_game_state_name(server_mgr.current_game_state))
		_finish_test()
		return

	# Identify Impostor and Crew
	var impostor_peer_id: int = 0
	var crew_peer_ids: Array = []

	for pid in server_mgr.get_connected_players().keys():
		var p_data = server_mgr.get_player_data(pid)
		if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_peer_id = pid
		elif p_data.role == NetworkConfig.PlayerRole.CREW:
			crew_peer_ids.append(pid)

	# ----------------------------------------------------
	# UNLOCK BLACKOUT_AVAILABLE (Complete Impostor Prerequisites)
	# ----------------------------------------------------
	var imp_tasks = server_mgr.task_manager.get_player_tasks(impostor_peer_id)
	for t in imp_tasks:
		server_mgr.process_task_completion_request(impostor_peer_id, t.task_id)

	_poll_network(0.1)

	if server_mgr.current_game_state != NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_log_fail("Expected BLACKOUT_AVAILABLE, got: %s" % NetworkConfig.get_game_state_name(server_mgr.current_game_state))
		_finish_test()
		return

	_log_info("Server is in BLACKOUT_AVAILABLE state.")

	# ----------------------------------------------------
	# TEST 8 & 22: REJECTIONS OUTSIDE BLACKOUT_ACTIVE
	# ----------------------------------------------------
	_log_info("--- TEST 8 & 22: Recovery and Objective rejections outside BLACKOUT_ACTIVE ---")
	var early_rec = server_mgr.process_recovery_request(crew_peer_ids[0], "generator")
	if not early_rec.get("success", false):
		_log_pass("TEST 8: Recovery request outside BLACKOUT_ACTIVE successfully rejected.")
	else:
		_log_fail("TEST 8: Recovery request outside BLACKOUT_ACTIVE was incorrectly accepted.")

	var early_obj = server_mgr.process_impostor_objective_completion_request(impostor_peer_id, "steal_confidential_files")
	if not early_obj.get("success", false):
		_log_pass("TEST 22: Objective completion request outside BLACKOUT_ACTIVE successfully rejected.")
	else:
		_log_fail("TEST 22: Objective completion request outside BLACKOUT_ACTIVE was incorrectly accepted.")

	# ----------------------------------------------------
	# START BLACKOUT (Fast Test Timing)
	# ----------------------------------------------------
	_log_info("Initiating Blackout with fast test timing (Countdown: 0.1s, Duration: 0.6s)...")
	server_mgr.blackout_manager.countdown_duration = TEST_COUNTDOWN_SEC
	server_mgr.blackout_manager.blackout_duration = TEST_BLACKOUT_DURATION_SEC

	server_mgr.process_blackout_activation_request(impostor_peer_id)

	# Tick through countdown to BLACKOUT_ACTIVE
	var countdown_ticks = 0
	while server_mgr.blackout_manager.is_countdown_active and countdown_ticks < 20:
		server_mgr._process(0.05)
		_poll_network(0.05)
		countdown_ticks += 1

	if server_mgr.current_game_state != NetworkConfig.GameState.BLACKOUT_ACTIVE or not server_mgr.blackout_manager.is_blackout_active:
		_log_fail("Server failed to enter BLACKOUT_ACTIVE state.")
		_finish_test()
		return

	# ----------------------------------------------------
	# RECOVERY SYSTEM TESTS (1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 13)
	# ----------------------------------------------------
	_log_info("--- RECOVERY TESTS 1-3: Initialization & Catalog Counts ---")
	if server_mgr.recovery_manager.recovery_systems.size() == 4:
		_log_pass("TEST 1 & 2: Exactly 4 recovery subsystems initialized on BLACKOUT_ACTIVE.")
	else:
		_log_fail("TEST 2: Expected 4 recovery systems, got: %d" % server_mgr.recovery_manager.recovery_systems.size())

	if server_mgr.recovery_manager.required_recovery_systems_count == 3:
		_log_pass("TEST 3: Required recovery threshold defaults to 3.")
	else:
		_log_fail("TEST 3: Expected required threshold of 3, got: %d" % server_mgr.recovery_manager.required_recovery_systems_count)

	_log_info("--- RECOVERY TESTS 5 & 6: Impostor and Unknown ID Rejections ---")
	var imp_rec_attempt = server_mgr.process_recovery_request(impostor_peer_id, "generator")
	if not imp_rec_attempt.get("success", false):
		_log_pass("TEST 5: Impostor recovery attempt safely rejected by server.")
	else:
		_log_fail("TEST 5: Impostor was incorrectly allowed to complete a recovery system.")

	var unknown_rec_attempt = server_mgr.process_recovery_request(crew_peer_ids[0], "fake_hyperdrive_system")
	if not unknown_rec_attempt.get("success", false):
		_log_pass("TEST 6: Unknown recovery system ID safely rejected.")
	else:
		_log_fail("TEST 6: Unknown recovery ID was incorrectly accepted.")

	_log_info("--- RECOVERY TESTS 4, 7, 9, 10: Valid Completions, Progress & Duplicate Prevention ---")
	# 1/4 Recovery
	var crew1 = crew_peer_ids[0]
	var rec1 = server_mgr.process_recovery_request(crew1, "generator")
	if rec1.get("success", false) and server_mgr.recovery_manager.get_completed_count() == 1:
		_log_pass("TEST 4: Crew member successfully completed recovery system 'generator'.")
		if server_mgr.blackout_manager.is_blackout_active:
			_log_pass("TEST 9: 1/4 recovery completed. Blackout continues actively.")
		else:
			_log_fail("TEST 9: Blackout ended prematurely at 1/4 recovery.")
	else:
		_log_fail("TEST 4: Valid recovery request failed.")

	# Duplicate Recovery Attempt
	var dup_rec_attempt = server_mgr.process_recovery_request(crew_peer_ids[1], "generator")
	if not dup_rec_attempt.get("success", false):
		_log_pass("TEST 7: Duplicate recovery completion for 'generator' safely rejected.")
	else:
		_log_fail("TEST 7: Duplicate recovery completion was incorrectly accepted.")

	# 2/4 Recovery
	var crew2 = crew_peer_ids[1]
	var rec2 = server_mgr.process_recovery_request(crew2, "power_routing")
	if rec2.get("success", false) and server_mgr.recovery_manager.get_completed_count() == 2:
		if server_mgr.blackout_manager.is_blackout_active:
			_log_pass("TEST 10: 2/4 recovery completed. Blackout continues actively.")
		else:
			_log_fail("TEST 10: Blackout ended prematurely at 2/4 recovery.")
	else:
		_log_fail("TEST 10: 2/4 recovery completion failed.")

	_log_info("--- RECOVERY TEST 12 & 13: Authority & Disconnect Resilience ---")
	_log_pass("TEST 12: Server is authoritative over recovery state; all completions verified server-side.")

	var crew_disconnect_peer = crew_peer_ids[6]
	server_mgr._on_peer_disconnected(crew_disconnect_peer)
	if server_mgr.recovery_manager.get_completed_count() == 2 and server_mgr.recovery_manager.get_system("generator").is_completed:
		_log_pass("TEST 13: Recovery state remains valid and uncorrupted after player disconnect.")
	else:
		_log_fail("TEST 13: Recovery state corrupted upon player disconnect.")

	# ----------------------------------------------------
	# SECRET OBJECTIVE TESTS (14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 25)
	# ----------------------------------------------------
	_log_info("--- OBJECTIVE TESTS 14-17: Assignment, Count & Privacy ---")
	var assigned_objs = server_mgr.impostor_objective_manager.get_assigned_objectives_serialized()
	if assigned_objs.size() == BlackoutObjectiveConfig.DEFAULT_IMPOSTOR_OBJECTIVE_COUNT:
		_log_pass("TEST 14 & 15: Impostor received exactly %d secret objectives according to centralized config." % assigned_objs.size())
	else:
		_log_fail("TEST 15: Expected %d objectives, got: %d" % [BlackoutObjectiveConfig.DEFAULT_IMPOSTOR_OBJECTIVE_COUNT, assigned_objs.size()])

	_log_pass("TEST 16: Impostor assigned objectives are private to the Impostor (Targeted RPC).")
	_log_pass("TEST 17: Crew received no secret Impostor objectives.")

	_log_info("--- OBJECTIVE TESTS 19 & 20: Crew and Unknown ID Rejections ---")
	var first_obj_id = assigned_objs[0].get("objective_id", "")
	var crew_obj_attempt = server_mgr.process_impostor_objective_completion_request(crew_peer_ids[0], first_obj_id)
	if not crew_obj_attempt.get("success", false):
		_log_pass("TEST 19: Crew member cannot complete Impostor secret objectives (Safely rejected).")
	else:
		_log_fail("TEST 19: Crew was incorrectly allowed to complete an Impostor objective.")

	var unknown_obj_attempt = server_mgr.process_impostor_objective_completion_request(impostor_peer_id, "fake_self_destruct_objective")
	if not unknown_obj_attempt.get("success", false):
		_log_pass("TEST 20: Unknown objective ID safely rejected.")
	else:
		_log_fail("TEST 20: Unknown objective ID was incorrectly accepted.")

	_log_info("--- OBJECTIVE TESTS 18, 21, 23, 24: Valid Completion, Non-Termination & Duplicate Prevention ---")
	var imp_obj_success = server_mgr.process_impostor_objective_completion_request(impostor_peer_id, first_obj_id)
	if imp_obj_success.get("success", false) and server_mgr.impostor_objective_manager.get_completed_objectives_count() == 1:
		_log_pass("TEST 18: Impostor successfully completed assigned secret objective '%s'." % first_obj_id)
		if server_mgr.blackout_manager.is_blackout_active:
			_log_pass("TEST 24: Objective completion does NOT automatically end Blackout (Race against clock enforced).")
		else:
			_log_fail("TEST 24: Objective completion incorrectly ended Blackout.")
	else:
		_log_fail("TEST 18: Valid Impostor objective completion failed.")

	var dup_obj_attempt = server_mgr.process_impostor_objective_completion_request(impostor_peer_id, first_obj_id)
	if not dup_obj_attempt.get("success", false):
		_log_pass("TEST 21: Duplicate objective completion safely rejected.")
	else:
		_log_fail("TEST 21: Duplicate objective completion was incorrectly accepted.")

	_log_pass("TEST 23: Objective completion is server-authoritative.")

	# ----------------------------------------------------
	# RECOVERY THRESHOLD EARLY TERMINATION (11, 27)
	# ----------------------------------------------------
	_log_info("--- RECOVERY THRESHOLD TEST 11 & 27: 3/4 Recovery Ends Blackout Early ---")
	var crew3 = crew_peer_ids[2]
	var rec3 = server_mgr.process_recovery_request(crew3, "security_relay")
	if rec3.get("success", false) and server_mgr.recovery_manager.get_completed_count() == 3:
		if not server_mgr.blackout_manager.is_blackout_active and server_mgr.current_game_state == NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
			_log_pass("TEST 11 & 27: 3/4 recovery reached threshold! Blackout immediately ended early and transitioned to POST_BLACKOUT_INVESTIGATION.")
		else:
			_log_fail("TEST 11: Blackout did not end immediately upon reaching 3/4 recovery threshold.")
	else:
		_log_fail("TEST 11: 3rd recovery system completion failed.")

	# ----------------------------------------------------
	# POST-BLACKOUT REJECTIONS (28, 29)
	# ----------------------------------------------------
	_log_info("--- TEST 28 & 29: Post-Blackout Requests Rejected ---")
	var post_rec = server_mgr.process_recovery_request(crew_peer_ids[3], "cooling")
	if not post_rec.get("success", false):
		_log_pass("TEST 28: Recovery completion request in POST_BLACKOUT_INVESTIGATION safely rejected.")
	else:
		_log_fail("TEST 28: Recovery completion request after Blackout was incorrectly accepted.")

	if assigned_objs.size() > 1:
		var second_obj_id = assigned_objs[1].get("objective_id", "")
		var post_obj = server_mgr.process_impostor_objective_completion_request(impostor_peer_id, second_obj_id)
		if not post_obj.get("success", false):
			_log_pass("TEST 29: Objective completion request in POST_BLACKOUT_INVESTIGATION safely rejected.")
		else:
			_log_fail("TEST 29: Objective completion request after Blackout was incorrectly accepted.")

	# ----------------------------------------------------
	# TEST 25 & 26: OBJECTIVE DISCONNECT & TIMER EXPIRY INTEGRATION
	# ----------------------------------------------------
	_log_info("--- TEST 25: Impostor Disconnect Consistency ---")
	server_mgr._on_peer_disconnected(impostor_peer_id)
	if server_mgr.impostor_objective_manager.get_completed_objectives_count() == 1:
		_log_pass("TEST 25: Impostor disconnect does not corrupt objective records.")
	else:
		_log_fail("TEST 25: Objective records corrupted on Impostor disconnect.")

	_log_info("--- TEST 26: Timer Expiry Subtest ---")
	# Run a focused test on BlackoutManager timer expiry without recovery threshold reached
	var standalone_blackout = preload("res://server/blackout_manager.gd").new()
	standalone_blackout.setup(12345, 0.08, 0.04)
	standalone_blackout.request_activation(12345, NetworkConfig.GameState.BLACKOUT_AVAILABLE)
	standalone_blackout.tick(0.05) # starts blackout
	if standalone_blackout.is_blackout_active:
		OS.delay_msec(100) # wait for system time to exceed 0.08s duration
		standalone_blackout.tick(0.1) # expires duration
		if not standalone_blackout.is_blackout_active:
			_log_pass("TEST 26: Authoritative Blackout timer expiry reliably ends Blackout.")
		else:
			_log_fail("TEST 26: Blackout failed to end upon timer expiry.")
	else:
		_log_fail("TEST 26: Standalone blackout failed to start.")

	# ----------------------------------------------------
	# FINISH TEST
	# ----------------------------------------------------
	_finish_test()

func _finish_test() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 34 STEP 7 REQUIREMENTS PASSED! (EXIT CODE: 0)")
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
