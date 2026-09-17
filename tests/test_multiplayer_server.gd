extends SceneTree

## Headless Integration Test Suite for BLACKOUT Authoritative Multiplayer Server Foundation.
## Verifies all requirements from Step 2:
##   1. Server startup on configurable port
##   2. Single client connection & handshake
##   3. Multiple clients (up to 8) concurrent connection
##   4. Unique server-assigned slot IDs (1-8)
##   5. Connected-player count synchronization
##   6. Client disconnection & server cleanup
##   7. 9th connection rejection (Server full enforcement)
##   8. Server teardown & clean shutdown

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7788
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE SERVER TEST SUITE (STEP 2)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_tests)

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
		# Process server peer through its MultiplayerAPI
		if server_mgr != null and server_mgr.peer != null:
			var mp = server_mgr._get_mp()
			if mp != null:
				mp.poll()
		
		# Process each client's SceneMultiplayer instance
		for c in clients:
			if c.mp != null and c.peer != null:
				c.mp.poll()
		
		OS.delay_msec(10)

func _run_tests() -> void:
	# ----------------------------------------------------
	# TEST 1: Server Startup on Configurable Port
	# ----------------------------------------------------
	_log_info("--- TEST 1: Server Startup on Port %d ---" % TEST_PORT)
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)
	
	var start_err: Error = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err == OK and server_mgr.is_running and server_mgr.active_port == TEST_PORT:
		_log_pass("Server successfully started on port %d with max %d players." % [TEST_PORT, NetworkConfig.MAX_PLAYERS])
	else:
		_log_fail("Server failed to start on port %d (Error code: %d)." % [TEST_PORT, start_err])
		_finish_suite()
		return

	_poll_network(0.1)

	# ----------------------------------------------------
	# TEST 2: Connect Single Client (Client 1)
	# ----------------------------------------------------
	_log_info("--- TEST 2: Single Client Connection ---")
	var client1 = _create_test_client(1)
	_poll_network(0.35)

	if client1.peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_log_pass("Client 1 connected to server successfully.")
	else:
		_log_fail("Client 1 failed to connect to server.")

	if server_mgr.get_connected_player_count() == 1:
		_log_pass("Server detected 1 connected player.")
	else:
		_log_fail("Server player count mismatch: expected 1, got %d." % server_mgr.get_connected_player_count())

	# ----------------------------------------------------
	# TEST 3 & 4: Connect Multiple Clients up to 8 & Verify Unique IDs
	# ----------------------------------------------------
	_log_info("--- TEST 3 & 4: Connect Clients 2 through 8 & Verify Unique Server-Controlled IDs ---")
	for i in range(2, 9):
		_create_test_client(i)
		_poll_network(0.1)

	_poll_network(0.35)

	var connected_count: int = server_mgr.get_connected_player_count()
	if connected_count == 8:
		_log_pass("All 8 clients connected successfully (Server count: 8/8).")
	else:
		_log_fail("Expected 8 connected clients, server reports: %d." % connected_count)

	# Verify server-assigned slots are unique from 1 to 8
	var assigned_slots: Array = []
	var duplicate_found: bool = false
	for pid in server_mgr.connected_players.keys():
		var p_data = server_mgr.get_player_data(pid)
		if p_data != null:
			if assigned_slots.has(p_data.player_slot):
				duplicate_found = true
			assigned_slots.append(p_data.player_slot)

	assigned_slots.sort()
	if not duplicate_found and assigned_slots == [1, 2, 3, 4, 5, 6, 7, 8]:
		_log_pass("Server assigned strictly unique slots: %s" % str(assigned_slots))
	else:
		_log_fail("Slot assignment validation failed. Slots assigned: %s" % str(assigned_slots))

	# ----------------------------------------------------
	# TEST 5: Connected Player Count Updates
	# ----------------------------------------------------
	_log_info("--- TEST 5: Connected-Player Count Updates ---")
	if server_mgr.get_connected_player_count() == 8:
		_log_pass("Authoritative player count accurately reflects 8 active sessions.")
	else:
		_log_fail("Player count inconsistency detected.")

	# ----------------------------------------------------
	# TEST 6: Disconnect a Client & Verify Detection
	# ----------------------------------------------------
	_log_info("--- TEST 6: Disconnect Client 3 and Verify Server Detection & Slot Reclaim ---")
	var client_to_drop = clients[2] # Client 3
	var dropped_peer_id = client_to_drop.peer.get_unique_id()
	client_to_drop.peer.close()
	client_to_drop.mp.multiplayer_peer = null
	_poll_network(0.35)

	if server_mgr.get_connected_player_count() == 7:
		_log_pass("Server detected disconnection of client %d. Active count updated to 7/8." % dropped_peer_id)
	else:
		_log_fail("Server failed to update count after client disconnect: got %d, expected 7." % server_mgr.get_connected_player_count())

	# Re-connect a replacement client to verify slot recycling
	_log_info("Reconnecting a replacement client to verify slot reuse...")
	var replacement_client = _create_test_client(10)
	_poll_network(0.35)

	if server_mgr.get_connected_player_count() == 8:
		_log_pass("Replacement client connected. Server count restored to 8/8.")
	else:
		_log_fail("Replacement client failed to join: count is %d." % server_mgr.get_connected_player_count())

	# ----------------------------------------------------
	# TEST 7: Attempt 9th Connection and Verify Rejection
	# ----------------------------------------------------
	_log_info("--- TEST 7: Attempt 9th Connection (Server Full Rejection) ---")
	var client9 = _create_test_client(99)
	_poll_network(0.35)

	# Server count MUST remain 8 (9th player rejected)
	if server_mgr.get_connected_player_count() == 8:
		_log_pass("Server maintained strict maximum limit of 8 players (Count remains 8/8).")
	else:
		_log_fail("Server exceeded 8 players limit or replaced existing player: count is %d." % server_mgr.get_connected_player_count())

	# ----------------------------------------------------
	# TEST 8: Server Teardown Cleanup
	# ----------------------------------------------------
	_log_info("--- TEST 8: Server Teardown ---")
	server_mgr.stop_server()
	if not server_mgr.is_running and server_mgr.get_connected_player_count() == 0:
		_log_pass("Server stopped and cleaned up all player sessions cleanly.")
	else:
		_log_fail("Server teardown incomplete.")

	_finish_suite()

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

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 8 TESTS PASSED WITH ZERO ERRORS! (EXIT CODE: 0)")
	else:
		print("  TEST SUITE FAILED WITH ERRORS! (EXIT CODE: 1)")
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
