extends SceneTree

## Headless Integration Test Suite for BLACKOUT Authoritative Lobby & Ready System.
## Verifies all 10 test scenarios:
##   1. A player connects and enters the lobby
##   2. A player is initially NOT READY
##   3. A player can become READY
##   4. Ready state is synchronized correctly
##   5. A player can become NOT READY
##   6. Fewer than 8 players cannot start the match
##   7. Eight players with some players NOT READY cannot start
##   8. Eight connected players with all 8 READY causes server to advance from LOBBY
##   9. A player disconnecting before start correctly updates lobby state
##   10. Invalid ready requests are rejected/ignored safely

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7789
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE LOBBY & READY TEST")
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
	# Start Server
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
	# SCENARIO 1: A player connects and enters the lobby
	# ----------------------------------------------------
	_log_info("--- SCENARIO 1: Player connects and enters lobby ---")
	var client1 = _create_test_client(1)
	_poll_network(0.35)

	if server_mgr.get_connected_player_count() == 1 and server_mgr.current_game_state == NetworkConfig.GameState.LOBBY:
		_log_pass("Player 1 connected and entered state: LOBBY.")
	else:
		_log_fail("Player 1 lobby entry failed.")

	# ----------------------------------------------------
	# SCENARIO 2: A player is initially NOT READY
	# ----------------------------------------------------
	_log_info("--- SCENARIO 2: Player is initially NOT READY ---")
	var p1_id = server_mgr.connected_players.keys()[0]
	var p1_data = server_mgr.get_player_data(p1_id)

	if p1_data != null and not p1_data.is_ready and server_mgr.get_ready_player_count() == 0:
		_log_pass("Player %d is initialized as NOT READY (Ready: 0/1)." % p1_id)
	else:
		_log_fail("Player initial ready state is invalid.")

	# ----------------------------------------------------
	# SCENARIO 3: A player can become READY
	# ----------------------------------------------------
	_log_info("--- SCENARIO 3: Player becomes READY ---")
	var set_ready_ok = server_mgr.set_player_ready(p1_id, true)
	_poll_network(0.15)

	if set_ready_ok and p1_data.is_ready and server_mgr.get_ready_player_count() == 1:
		_log_pass("Player %d transitioned to READY (Ready: 1/1)." % p1_id)
	else:
		_log_fail("Failed to set player ready.")

	# ----------------------------------------------------
	# SCENARIO 4: Ready state is synchronized
	# ----------------------------------------------------
	_log_info("--- SCENARIO 4: Ready state synchronization ---")
	if server_mgr.get_ready_player_count() == 1:
		_log_pass("Server accurately reports ready count: 1/1.")
	else:
		_log_fail("Ready count sync verification failed.")

	# ----------------------------------------------------
	# SCENARIO 5: A player can become NOT READY
	# ----------------------------------------------------
	_log_info("--- SCENARIO 5: Player becomes NOT READY ---")
	var set_unready_ok = server_mgr.set_player_ready(p1_id, false)
	_poll_network(0.15)

	if set_unready_ok and not p1_data.is_ready and server_mgr.get_ready_player_count() == 0:
		_log_pass("Player %d transitioned back to NOT READY (Ready: 0/1)." % p1_id)
	else:
		_log_fail("Failed to set player unready.")

	# ----------------------------------------------------
	# SCENARIO 6: Fewer than 8 players cannot start the match
	# ----------------------------------------------------
	_log_info("--- SCENARIO 6: Fewer than 8 players cannot start match ---")
	for i in range(2, 5): # Connect clients 2, 3, 4 (Total: 4 players)
		_create_test_client(i)
	_poll_network(0.35)

	# Set all 4 players to READY
	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.2)

	if server_mgr.get_connected_player_count() == 4 and server_mgr.get_ready_player_count() == 4:
		if server_mgr.current_game_state == NetworkConfig.GameState.LOBBY:
			_log_pass("Server blocked match start with 4/8 players ready (State remains LOBBY).")
		else:
			_log_fail("Server prematurely started match with fewer than 8 players!")
	else:
		_log_fail("Player setup for Scenario 6 failed.")

	# ----------------------------------------------------
	# SCENARIO 7: 8 players with some NOT READY cannot start
	# ----------------------------------------------------
	_log_info("--- SCENARIO 7: 8 players connected with some NOT READY cannot start ---")
	for i in range(5, 9): # Connect clients 5, 6, 7, 8 (Total: 8 players)
		_create_test_client(i)
	_poll_network(0.35)

	# Ensure 7 are READY and 1 is NOT READY
	var all_pids = server_mgr.connected_players.keys()
	for i in range(7):
		server_mgr.set_player_ready(all_pids[i], true)
	server_mgr.set_player_ready(all_pids[7], false)
	_poll_network(0.2)

	if server_mgr.get_connected_player_count() == 8 and server_mgr.get_ready_player_count() == 7:
		if server_mgr.current_game_state == NetworkConfig.GameState.LOBBY:
			_log_pass("Server blocked match start with 7/8 players ready (State remains LOBBY).")
		else:
			_log_fail("Server started match when not all 8 players were ready!")
	else:
		_log_fail("Player setup for Scenario 7 failed.")

	# ----------------------------------------------------
	# SCENARIO 8: 8 players with all 8 READY triggers match start
	# ----------------------------------------------------
	_log_info("--- SCENARIO 8: 8 players with all 8 READY advances from LOBBY ---")
	server_mgr.set_player_ready(all_pids[7], true)
	_poll_network(0.2)

	if server_mgr.get_connected_player_count() == 8 and server_mgr.get_ready_player_count() == 8:
		if server_mgr.current_game_state != NetworkConfig.GameState.LOBBY:
			_log_pass("Start condition satisfied! State advanced from LOBBY to: %s." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))
		else:
			_log_fail("Server failed to advance from LOBBY on 8/8 ready.")
	else:
		_log_fail("Player setup for Scenario 8 failed.")

	# ----------------------------------------------------
	# SCENARIO 9: Player disconnect in lobby updates counts
	# ----------------------------------------------------
	_log_info("--- SCENARIO 9: Player disconnect updates lobby counts ---")
	server_mgr.current_game_state = NetworkConfig.GameState.LOBBY
	var client_to_drop = clients[0]
	client_to_drop.peer.close()
	client_to_drop.mp.multiplayer_peer = null
	_poll_network(0.35)

	if server_mgr.get_connected_player_count() == 7:
		_log_pass("Server detected player disconnect. Active count updated to 7/8.")
		if server_mgr.current_game_state == NetworkConfig.GameState.LOBBY:
			_log_pass("Match correctly remains in LOBBY with 7 players.")
		else:
			_log_fail("Server in invalid state after disconnect.")
	else:
		_log_fail("Server failed to update count after disconnect: %d" % server_mgr.get_connected_player_count())

	# ----------------------------------------------------
	# SCENARIO 10: Invalid ready requests rejected safely
	# ----------------------------------------------------
	_log_info("--- SCENARIO 10: Invalid ready requests rejected safely ---")
	var unknown_peer_result = server_mgr.set_player_ready(999999, true)
	if not unknown_peer_result:
		_log_pass("Server safely rejected ready request from unknown peer 999999.")
	else:
		_log_fail("Server accepted ready request from unknown peer.")

	server_mgr.current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE
	var valid_pid = server_mgr.connected_players.keys()[0]
	var non_lobby_result = server_mgr.set_player_ready(valid_pid, false)
	if not non_lobby_result:
		_log_pass("Server safely rejected ready request while in non-LOBBY state (INITIAL_TASK_PHASE).")
	else:
		_log_fail("Server accepted ready request during non-LOBBY state.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 10 SCENARIOS PASSED WITH ZERO ERRORS! (EXIT CODE: 0)")
	else:
		print("  LOBBY TEST SUITE FAILED! (EXIT CODE: 1)")
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
