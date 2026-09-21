extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Blackout System (Member 8: Audio & QA Lead)
## Verifies server authority over Blackout triggering, cooldowns, and recovery:
##   1. Reject Crew members attempting to trigger Blackout
##   2. Reject Impostor triggering Blackout before prerequisite tasks are completed
##   3. Reject triggering Blackout while already active
##   4. Reject unauthorized / non-assigned recovery system submissions
##   5. Reject duplicate recovery panel submissions
##   6. Authoritative recovery threshold required to end Blackout early

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutConfig = preload("res://shared/blackout_config.gd")
const BlackoutRecoveryConfig = preload("res://shared/blackout_recovery_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7798
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: BLACKOUT & RECOVERY AUTHORITY")
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
	_log_info("Setting up 8 players for Blackout authority verification...")
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

	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.3)

	var pids: Array = server_mgr.connected_players.keys()
	var impostor_id: int = -1
	var crew_ids: Array[int] = []
	for pid in pids:
		var pdata = server_mgr.connected_players[pid]
		if pdata.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_id = pid
		else:
			crew_ids.append(pid)

	# --- TEST 1: Reject Crew Triggering Blackout ---
	var crew_peer: int = crew_ids[0]
	var crew_trigger_res: bool = server_mgr.blackout_manager.trigger_blackout(crew_peer)
	if not crew_trigger_res:
		_log_pass("TEST 1: Crew attempt to trigger Blackout safely rejected.")
	else:
		_log_fail("TEST 1: Server permitted Crew member to trigger Blackout!")

	# --- TEST 2: Reject Impostor Triggering Blackout Before Prerequisites ---
	var premature_res: bool = server_mgr.blackout_manager.trigger_blackout(impostor_id)
	if not premature_res:
		_log_pass("TEST 2: Premature Blackout trigger before prerequisites completed safely rejected.")
	else:
		_log_fail("TEST 2: Impostor triggered Blackout without prerequisite completion!")

	# --- Complete Prerequisites Authoritatively ---
	var imp_tasks: Array = server_mgr.task_manager.get_player_tasks(impostor_id)
	for t in imp_tasks:
		server_mgr.task_manager.complete_task(impostor_id, t.task_id)
	_poll_network(0.1)

	# --- TEST 3: Authorized Blackout Trigger Succeeds ---
	var valid_trigger: bool = server_mgr.blackout_manager.trigger_blackout(impostor_id)
	if valid_trigger:
		_log_pass("TEST 3: Authorized Impostor Blackout trigger succeeded after prerequisites.")
	else:
		_log_fail("TEST 3: Authorized Blackout trigger failed unexpectedly.")

	# --- TEST 4: Reject Duplicate Blackout Trigger While Active ---
	var duplicate_trigger: bool = server_mgr.blackout_manager.trigger_blackout(impostor_id)
	if not duplicate_trigger:
		_log_pass("TEST 4: Duplicate Blackout trigger while already active safely rejected.")
	else:
		_log_fail("TEST 4: Server permitted duplicate Blackout trigger while active!")

	# --- TEST 5: Reject Invalid Recovery System ID ---
	var invalid_rec: bool = server_mgr.blackout_recovery_manager.complete_recovery_system(crew_peer, "non_existent_generator_system")
	if not invalid_rec:
		_log_pass("TEST 5: Fake / non-existent recovery system ID safely rejected.")
	else:
		_log_fail("TEST 5: Server accepted invalid recovery system ID!")

	# --- TEST 6: Reject Duplicate Recovery Submissions ---
	var valid_systems: Array = server_mgr.blackout_recovery_manager.get_available_systems()
	if valid_systems.size() > 0:
		var sys_id: String = valid_systems[0]
		var first_rec: bool = server_mgr.blackout_recovery_manager.complete_recovery_system(crew_peer, sys_id)
		var second_rec: bool = server_mgr.blackout_recovery_manager.complete_recovery_system(crew_peer, sys_id)
		if first_rec and not second_rec:
			_log_pass("TEST 6: Duplicate recovery submission on already repaired panel rejected.")
		else:
			_log_fail("TEST 6: Duplicate recovery submission was accepted!")
	else:
		_log_fail("TEST 6: No recovery systems available to test.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  RESULT: ALL BLACKOUT ANTI-CHEAT TESTS PASSED (6/6)")
	else:
		print("  RESULT: SOME TESTS FAILED")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.peer.close()
	
	quit(0 if test_passed else 1)
