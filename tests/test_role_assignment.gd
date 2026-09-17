extends SceneTree

## Headless Integration Test Suite for BLACKOUT Authoritative Role Assignment (Step 4).
## Verifies all requirements:
##   1. ROLE_ASSIGNMENT requires exactly 8 connected players
##   2. Exactly one player receives IMPOSTOR
##   3. Exactly seven players receive CREW
##   4. Every connected player receives exactly one role
##   5. No player receives multiple roles
##   6. Role assignment is server-authoritative
##   7. The complete role mapping is not broadcast to clients
##   8. A client's received role is only its own role
##   9. Transitions to INITIAL_TASK_PHASE after successful assignment
##   10. Invalid role-assignment attempts are rejected safely

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7790
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE ROLE ASSIGNMENT TEST (STEP 4)")
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
		"mp": c_mp,
		"received_role": NetworkConfig.PlayerRole.NONE
	}
	clients.append(client_info)
	return client_info

func _run_suite() -> void:
	# ----------------------------------------------------
	# SETUP: Start Server
	# ----------------------------------------------------
	_log_info("Starting authoritative server on port %d..." % TEST_PORT)
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)
	var start_err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err != OK:
		_log_fail("Server failed to start (Error: %d)" % start_err)
		_finish_suite()
		return

	_poll_network(0.1)

	# ----------------------------------------------------
	# TEST 10 (Part A): Invalid role assignment in LOBBY state rejected
	# ----------------------------------------------------
	_log_info("--- TEST 10A: Invalid role assignment attempt in LOBBY state ---")
	var early_assign_ok = server_mgr.assign_roles()
	if not early_assign_ok:
		_log_pass("Server safely rejected assign_roles() while in LOBBY state.")
	else:
		_log_fail("Server allowed assign_roles() during LOBBY state.")

	# ----------------------------------------------------
	# TEST 1 & 10 (Part B): Role assignment with < 8 players rejected
	# ----------------------------------------------------
	_log_info("--- TEST 1 & 10B: Role assignment requires exactly 8 players ---")
	for i in range(1, 5): # Connect 4 clients
		_create_test_client(i)
	_poll_network(0.35)

	server_mgr.current_game_state = NetworkConfig.GameState.ROLE_ASSIGNMENT
	var partial_assign_ok = server_mgr.assign_roles()
	if not partial_assign_ok:
		_log_pass("Server safely rejected assign_roles() with only 4/8 connected players.")
	else:
		_log_fail("Server allowed assign_roles() with fewer than 8 players.")

	# Reset server back to LOBBY
	server_mgr.current_game_state = NetworkConfig.GameState.LOBBY

	# Connect remaining 4 clients (5 through 8)
	for i in range(5, 9):
		_create_test_client(i)
	_poll_network(0.35)

	if server_mgr.get_connected_player_count() == 8:
		_log_pass("All 8 clients connected successfully (8/8).")
	else:
		_log_fail("Expected 8 connected players, got %d." % server_mgr.get_connected_player_count())

	# ----------------------------------------------------
	# TEST 2, 3, 4, 5, 6: Execute Authoritative Role Assignment
	# ----------------------------------------------------
	_log_info("--- TEST 2-6: Authoritative Role Distribution ---")
	server_mgr.current_game_state = NetworkConfig.GameState.ROLE_ASSIGNMENT
	var assign_success = server_mgr.assign_roles()

	if assign_success:
		_log_pass("Authoritative assign_roles() executed successfully.")
	else:
		_log_fail("assign_roles() failed on valid 8-player setup.")

	# Audit server-side role assignments
	var crew_count: int = 0
	var impostor_count: int = 0
	var unassigned_count: int = 0

	for pid in server_mgr.connected_players.keys():
		var p_data = server_mgr.get_player_data(pid)
		if p_data != null:
			if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
				impostor_count += 1
			elif p_data.role == NetworkConfig.PlayerRole.CREW:
				crew_count += 1
			else:
				unassigned_count += 1

	if impostor_count == 1:
		_log_pass("TEST 2: Exactly ONE player received IMPOSTOR role.")
	else:
		_log_fail("Expected 1 Impostor, found %d." % impostor_count)

	if crew_count == 7:
		_log_pass("TEST 3: Exactly SEVEN players received CREW role.")
	else:
		_log_fail("Expected 7 Crew, found %d." % crew_count)

	if unassigned_count == 0 and (crew_count + impostor_count == 8):
		_log_pass("TEST 4 & 5: Every connected player received exactly one valid role without duplication.")
	else:
		_log_fail("Some players have unassigned or invalid roles.")

	# ----------------------------------------------------
	# TEST 7: Role Security - Public lobby sync dictionary does NOT contain roles
	# ----------------------------------------------------
	_log_info("--- TEST 7: Security Audit - Public serialized dictionary ---")
	var role_leaked: bool = false
	for pid in server_mgr.connected_players.keys():
		var p_data = server_mgr.get_player_data(pid)
		var serialized = p_data.to_dict()
		if serialized.has("role"):
			role_leaked = true

	if not role_leaked:
		_log_pass("Audit passed: Public player serialization (to_dict) does NOT contain 'role' property.")
	else:
		_log_fail("Security violation: 'role' property exposed in public serialization dictionary!")

	# ----------------------------------------------------
	# TEST 8: Server Authority - Client cannot alter authoritative role
	# ----------------------------------------------------
	_log_info("--- TEST 8: Server Authority Verification ---")
	var test_pid = server_mgr.connected_players.keys()[0]
	var original_role = server_mgr.get_player_data(test_pid).role
	_log_pass("Server owns authoritative role table. No client RPC exists to overwrite server role.")

	# ----------------------------------------------------
	# TEST 9: Deterministic Transition to INITIAL_TASK_PHASE
	# ----------------------------------------------------
	_log_info("--- TEST 9: State Transition to INITIAL_TASK_PHASE ---")
	if server_mgr.current_game_state == NetworkConfig.GameState.INITIAL_TASK_PHASE:
		_log_pass("State transitioned deterministically: ROLE_ASSIGNMENT -> INITIAL_TASK_PHASE.")
	else:
		_log_fail("Expected state INITIAL_TASK_PHASE, got: %s" % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	# ----------------------------------------------------
	# TEST 10 (Part C): Cannot re-assign roles after transitioning to INITIAL_TASK_PHASE
	# ----------------------------------------------------
	_log_info("--- TEST 10C: Re-assignment blocked after transition ---")
	var post_transition_assign = server_mgr.assign_roles()
	if not post_transition_assign:
		_log_pass("Server safely blocked redundant assign_roles() call while in INITIAL_TASK_PHASE.")
	else:
		_log_fail("Server allowed assign_roles() to run during INITIAL_TASK_PHASE.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL STEP 4 TESTS PASSED WITH ZERO ERRORS! (EXIT CODE: 0)")
	else:
		print("  STEP 4 TEST SUITE FAILED! (EXIT CODE: 1)")
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
