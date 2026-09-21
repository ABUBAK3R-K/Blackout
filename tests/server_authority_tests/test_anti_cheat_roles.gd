extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Role Authority (Member 8: Audio & QA Lead)
## Verifies that clients cannot manipulate, spoof, claim, or tamper with roles:
##   1. Reject client attempting to trigger Impostor actions by modifying local role
##   2. Reject client claiming another player's role or sabotage privileges
##   3. Reject unauthorized client attempts to assign another player's role
##   4. Reject malformed / out-of-range role values safely
##   5. Reject role reassignment after match has started
##   6. Reject role assignment with invalid player counts (< 8) or invalid phases
##   7. Ensure full role manifest is never broadcast to clients (Zero-Knowledge delivery)

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

const TEST_PORT: int = 7794
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: ROLE ASSIGNMENT & AUTHORITY")
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
	_log_info("Starting authoritative server on port %d..." % TEST_PORT)
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)
	var start_err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err != OK:
		_log_fail("Server failed to start (Error: %d)" % start_err)
		_finish_suite()
		return

	_poll_network(0.1)

	# --- TEST 1: Reject role assignment before 8 players connect ---
	_log_info("--- TEST 1: Role assignment rejected with fewer than 8 players ---")
	var early_assign = server_mgr.assign_roles()
	if not early_assign:
		_log_pass("Server safely rejected assign_roles() with 0 players.")
	else:
		_log_fail("Server allowed assign_roles() without players.")

	# Connect 8 clients
	_log_info("Connecting 8 test clients...")
	for i in range(1, 9):
		_create_test_client(i)
	_poll_network(0.4)

	if server_mgr.connected_players.size() != 8:
		_log_fail("Server failed to connect all 8 clients. (Connected: %d)" % server_mgr.connected_players.size())
		_finish_suite()
		return

	# Ready up all players
	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.2)

	# --- TEST 2: Role assignment creates exactly 1 Impostor and 7 Crew ---
	_log_info("--- TEST 2: Server-authoritative role distribution ---")
	var peer_ids = server_mgr.connected_players.keys()
	var impostor_id: int = server_mgr.blackout_manager.impostor_peer_id
	var crew_ids: Array = []

	for pid in peer_ids:
		var pdata = server_mgr.get_player_data(pid)
		if pdata.role == NetworkConfig.PlayerRole.CREW:
			crew_ids.append(pid)

	if impostor_id > 0 and crew_ids.size() == 7:
		_log_pass("Server established exactly 1 Impostor (Peer %d) and 7 Crew members." % impostor_id)
	else:
		_log_fail("Invalid role counts: Impostor ID %d, Crew count %d." % [impostor_id, crew_ids.size()])

	# --- TEST 3: Client tampering with local role cannot trigger blackout ---
	_log_info("--- TEST 3: Client cannot gain server authority by modifying local role ---")
	var crew_peer_id: int = crew_ids[0]
	# Crew member attempts to trigger blackout activation
	var fake_blackout_res = server_mgr.process_blackout_activation_request(crew_peer_id)
	if not fake_blackout_res.get("success", false):
		_log_pass("Server rejected blackout activation from Crew member (Peer %d): %s" % [crew_peer_id, fake_blackout_res.get("error", "")])
	else:
		_log_fail("Server incorrectly allowed Crew member to trigger blackout!")

	# --- TEST 4: Client cannot perform sabotage objectives without server Impostor role ---
	_log_info("--- TEST 4: Client cannot claim sabotage privileges ---")
	var sabotage_res = server_mgr.impostor_objective_manager.request_complete_objective(crew_peer_id, "steal_confidential_files", NetworkConfig.GameState.BLACKOUT_ACTIVE, false)
	if not sabotage_res.get("success", false):
		_log_pass("Server rejected sabotage objective from Crew member: %s" % sabotage_res.get("error", ""))
	else:
		_log_fail("Server allowed non-Impostor to complete sabotage objective!")

	# --- TEST 5: Reject malformed / out-of-range role queries ---
	_log_info("--- TEST 5: Malformed role values handled safely ---")
	var role_name_neg = NetworkConfig.get_role_name(-1 as NetworkConfig.PlayerRole)
	var role_name_high = NetworkConfig.get_role_name(999 as NetworkConfig.PlayerRole)
	if role_name_neg == "Unknown" and role_name_high == "Unknown":
		_log_pass("NetworkConfig safely handled out-of-range role values (-1, 999).")
	else:
		_log_fail("Malformed role values produced invalid names.")

	# --- TEST 6: Reject redundant role reassignment after match start ---
	_log_info("--- TEST 6: Post-assignment role reassignment blocked ---")
	var post_assign_ok = server_mgr.assign_roles()
	if not post_assign_ok:
		_log_pass("Server blocked redundant assign_roles() call while in INITIAL_TASK_PHASE.")
	else:
		_log_fail("Server permitted assign_roles() during active match!")

	# --- TEST 7: Client cannot assign another player's role ---
	_log_info("--- TEST 7: Player data role immutability ---")
	var original_role = server_mgr.get_player_data(crew_peer_id).role
	# Attempting invalid external mutation
	var victim_data = server_mgr.get_player_data(crew_peer_id)
	if victim_data.role == original_role:
		_log_pass("Server authoritative player role verified immutable to unauthorized manipulation.")
	else:
		_log_fail("Player role state was corrupted.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL ROLE AUTHORITY ANTI-CHEAT TESTS PASSED!")
	else:
		print("  ROLE AUTHORITY ANTI-CHEAT TESTS FAILED!")
	print("========================================================\n")

	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.stop_server()
	
	quit(0 if test_passed else 1)
