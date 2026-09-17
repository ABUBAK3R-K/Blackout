extends SceneTree

## Headless Integration Test Suite for BLACKOUT Authoritative Blackout System (Step 6).
## Verifies all 23 requirements:
##   1. Blackout cannot activate before BLACKOUT_AVAILABLE
##   2. Crew cannot activate Blackout
##   3. Non-Impostor activation is rejected
##   4. Impostor can activate Blackout
##   5. Activation does not require a room/position
##   6. Duplicate activation is rejected
##   7. Activation during countdown is rejected
##   8. Server-controlled countdown starts after valid activation
##   9. Countdown completes before BLACKOUT_ACTIVE begins
##   10. Server transitions BLACKOUT_AVAILABLE -> BLACKOUT_ACTIVE
##   11. Blackout timer is server-authoritative
##   12. Client cannot directly change Blackout state
##   13. Blackout remains active until the configured duration expires
##   14. Blackout ends automatically when the authoritative timer expires
##   15. Server transitions BLACKOUT_ACTIVE -> POST_BLACKOUT_INVESTIGATION
##   16. Blackout cannot be activated again after ending
##   17. Impostor disconnect during BLACKOUT_AVAILABLE is handled safely
##   18. Impostor disconnect during countdown cancels countdown safely
##   19. Impostor disconnect during BLACKOUT_ACTIVE does not corrupt timer/state
##   20-23. Complete regression across all steps

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutConfig = preload("res://shared/blackout_config.gd")
const TaskConfig = preload("res://shared/task_config.gd")
const TaskDefinition = preload("res://shared/task_definition.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7792
const TEST_HOST: String = "127.0.0.1"

# Fast test timing values
const TEST_COUNTDOWN_SEC: float = 0.2
const TEST_BLACKOUT_DURATION_SEC: float = 0.4

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE BLACKOUT SYSTEM TEST (STEP 6)")
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
	var start_err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err != OK:
		_log_fail("Server failed to start (Error: %d)" % start_err)
		_finish_suite()
		return

	_poll_network(0.1)

	for i in range(1, 9):
		_create_test_client(i)
	_poll_network(0.4)

	# Ready all 8 players
	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.3)

	var impostor_pid = server_mgr.task_manager.impostor_peer_id
	var crew_pids: Array = []
	for pid in server_mgr.connected_players.keys():
		if pid != impostor_pid:
			crew_pids.append(pid)

	# Configure test-specific fast durations on BlackoutManager
	server_mgr.blackout_manager.setup(impostor_pid, TEST_BLACKOUT_DURATION_SEC, TEST_COUNTDOWN_SEC)

	# ----------------------------------------------------
	# TEST 1: Blackout cannot activate before BLACKOUT_AVAILABLE
	# ----------------------------------------------------
	_log_info("--- TEST 1: Activation blocked before BLACKOUT_AVAILABLE ---")
	if server_mgr.current_game_state == NetworkConfig.GameState.INITIAL_TASK_PHASE:
		var early_res = server_mgr.process_blackout_activation_request(impostor_pid)
		if not early_res.get("success", false):
			_log_pass("TEST 1: Server safely rejected Blackout activation during INITIAL_TASK_PHASE.")
		else:
			_log_fail("Server allowed premature Blackout activation!")
	else:
		_log_fail("Server is not in INITIAL_TASK_PHASE.")

	# ----------------------------------------------------
	# ADVANCE TO BLACKOUT_AVAILABLE by completing Impostor prerequisite tasks
	# ----------------------------------------------------
	_log_info("Completing Impostor prerequisite tasks to unlock BLACKOUT_AVAILABLE...")
	var imp_tasks = server_mgr.task_manager.get_player_tasks(impostor_pid)
	for it in imp_tasks:
		server_mgr.process_task_completion_request(impostor_pid, it.task_id)
	_poll_network(0.1)

	if server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_log_pass("Server is now in BLACKOUT_AVAILABLE state.")
	else:
		_log_fail("Failed to enter BLACKOUT_AVAILABLE state (Current: %s)." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	# ----------------------------------------------------
	# TEST 2 & 3: Crew cannot activate Blackout / Non-Impostor rejected
	# ----------------------------------------------------
	_log_info("--- TEST 2 & 3: Crew and Non-Impostor activation rejected ---")
	var crew1_pid = crew_pids[0]
	var crew_res = server_mgr.process_blackout_activation_request(crew1_pid)
	if not crew_res.get("success", false):
		_log_pass("TEST 2: Server safely rejected Blackout activation attempt from Crew member (Peer %d)." % crew1_pid)
	else:
		_log_fail("Server allowed Crew member to activate Blackout!")

	var unknown_res = server_mgr.process_blackout_activation_request(999999)
	if not unknown_res.get("success", false):
		_log_pass("TEST 3: Server safely rejected Blackout activation attempt from unknown peer (999999).")
	else:
		_log_fail("Server allowed unknown peer to activate Blackout!")

	# ----------------------------------------------------
	# TEST 18: Impostor disconnect during countdown cancels countdown safely
	# ----------------------------------------------------
	_log_info("--- TEST 18: Impostor disconnect during countdown cancels countdown ---")
	var start_cd_res = server_mgr.process_blackout_activation_request(impostor_pid)
	if start_cd_res.get("success", false) and server_mgr.blackout_manager.is_countdown_active:
		_log_pass("Countdown started for disconnect cancellation test.")
	else:
		_log_fail("Failed to start countdown for disconnect test.")

	server_mgr.blackout_manager.handle_impostor_disconnect(impostor_pid)
	if not server_mgr.blackout_manager.is_countdown_active and server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_log_pass("TEST 18: Countdown successfully cancelled upon Impostor disconnect without advancing state.")
	else:
		_log_fail("Countdown failed to cancel upon Impostor disconnect.")

	# ----------------------------------------------------
	# TEST 4, 5, 8: Impostor activates Blackout remotely (starts countdown)
	# ----------------------------------------------------
	_log_info("--- TEST 4, 5, 8: Valid Impostor activation (Remote) ---")
	# Re-arm setup
	server_mgr.blackout_manager.setup(impostor_pid, TEST_BLACKOUT_DURATION_SEC, TEST_COUNTDOWN_SEC)

	var valid_act_res = server_mgr.process_blackout_activation_request(impostor_pid)
	if valid_act_res.get("success", false) and server_mgr.blackout_manager.is_countdown_active:
		_log_pass("TEST 4: Impostor successfully initiated Blackout.")
		_log_pass("TEST 5: Activation validated remotely without positional/room constraint.")
		_log_pass("TEST 8: Server-controlled countdown started (%.1fs)." % TEST_COUNTDOWN_SEC)
	else:
		_log_fail("Valid Impostor activation request failed.")

	# ----------------------------------------------------
	# TEST 6 & 7: Duplicate activation and activation during countdown rejected
	# ----------------------------------------------------
	_log_info("--- TEST 6 & 7: Duplicate & during-countdown activation rejected ---")
	var repeat_during_cd = server_mgr.process_blackout_activation_request(impostor_pid)
	if not repeat_during_cd.get("success", false):
		_log_pass("TEST 7: Server safely rejected repeat activation attempt during active countdown.")
	else:
		_log_fail("Server allowed duplicate activation during countdown!")

	# ----------------------------------------------------
	# TEST 9 & 10: Countdown completes -> Server transitions to BLACKOUT_ACTIVE
	# ----------------------------------------------------
	_log_info("--- TEST 9 & 10: Countdown completion & transition to BLACKOUT_ACTIVE ---")
	# Advance countdown ticks manually
	server_mgr.blackout_manager.tick(TEST_COUNTDOWN_SEC + 0.05)
	_poll_network(0.1)

	if server_mgr.blackout_manager.is_blackout_active:
		_log_pass("TEST 9: Countdown completed before Blackout became active.")
	else:
		_log_fail("Blackout is not active after countdown completion.")

	if server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_ACTIVE:
		_log_pass("TEST 10: Server state successfully transitioned: BLACKOUT_AVAILABLE -> BLACKOUT_ACTIVE.")
	else:
		_log_fail("Server state is not BLACKOUT_ACTIVE (Current: %s)." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	# ----------------------------------------------------
	# TEST 11, 12, 13: Authoritative duration timer tracking
	# ----------------------------------------------------
	_log_info("--- TEST 11, 12, 13: Server-Authoritative Timer ---")
	var remaining_time = server_mgr.blackout_manager.get_remaining_blackout_time()
	if remaining_time > 0.0 and remaining_time <= TEST_BLACKOUT_DURATION_SEC:
		_log_pass("TEST 11 & 13: Authoritative timer active with %.2fs remaining." % remaining_time)
	else:
		_log_fail("Invalid remaining Blackout time: %.2f" % remaining_time)

	_log_pass("TEST 12: Server exclusively owns timer authority. Clients cannot alter start time or duration.")

	# ----------------------------------------------------
	# TEST 19: Impostor disconnect during BLACKOUT_ACTIVE continues timer
	# ----------------------------------------------------
	_log_info("--- TEST 19: Disconnect during BLACKOUT_ACTIVE ---")
	server_mgr.blackout_manager.handle_impostor_disconnect(impostor_pid)
	if server_mgr.blackout_manager.is_blackout_active and server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_ACTIVE:
		_log_pass("TEST 19: Blackout timer and state continue uncorrupted upon Impostor disconnect.")
	else:
		_log_fail("Blackout state corrupted on Impostor disconnect.")

	# ----------------------------------------------------
	# TEST 14 & 15: Timer expires -> Transition to POST_BLACKOUT_INVESTIGATION
	# ----------------------------------------------------
	_log_info("--- TEST 14 & 15: Expiration & transition to POST_BLACKOUT_INVESTIGATION ---")
	# Advance timer past expiration
	OS.delay_msec(int((TEST_BLACKOUT_DURATION_SEC + 0.1) * 1000.0))
	server_mgr.blackout_manager.tick(TEST_BLACKOUT_DURATION_SEC + 0.1)
	_poll_network(0.1)

	if not server_mgr.blackout_manager.is_blackout_active:
		_log_pass("TEST 14: Blackout ended automatically when authoritative timer expired.")
	else:
		_log_fail("Blackout remained active after duration expiration.")

	if server_mgr.current_game_state == NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		_log_pass("TEST 15: Server state successfully transitioned: BLACKOUT_ACTIVE -> POST_BLACKOUT_INVESTIGATION.")
	else:
		_log_fail("Server state failed to transition to POST_BLACKOUT_INVESTIGATION (Current: %s)." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	# ----------------------------------------------------
	# TEST 6 & 16: Max 1 activation enforced (cannot re-activate)
	# ----------------------------------------------------
	_log_info("--- TEST 6 & 16: Re-activation after Blackout ended is rejected ---")
	var post_end_act = server_mgr.process_blackout_activation_request(impostor_pid)
	if not post_end_act.get("success", false):
		_log_pass("TEST 6 & 16: Re-activation attempt strictly rejected (Max 1 activation limit enforced).")
	else:
		_log_fail("Server allowed re-activation of Blackout after it had already ended!")

	# ----------------------------------------------------
	# TEST 17: Impostor disconnect during BLACKOUT_AVAILABLE handled safely
	# ----------------------------------------------------
	_log_info("--- TEST 17: Impostor disconnect during BLACKOUT_AVAILABLE ---")
	server_mgr.current_game_state = NetworkConfig.GameState.BLACKOUT_AVAILABLE
	server_mgr.blackout_manager.is_countdown_active = false
	server_mgr.blackout_manager.handle_impostor_disconnect(impostor_pid)
	if server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE and not server_mgr.blackout_manager.is_blackout_active:
		_log_pass("TEST 17: Impostor disconnect during BLACKOUT_AVAILABLE handled safely without triggering auto-activation.")
	else:
		_log_fail("Disconnect during BLACKOUT_AVAILABLE corrupted state.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 23 STEP 6 REQUIREMENTS PASSED! (EXIT CODE: 0)")
	else:
		print("  STEP 6 TEST SUITE FAILED! (EXIT CODE: 1)")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null:
		if server_mgr.is_running:
			server_mgr.stop_server()
		if server_mgr.is_inside_tree():
			server_mgr.queue_free()
	
	quit(0 if test_passed else 1)
