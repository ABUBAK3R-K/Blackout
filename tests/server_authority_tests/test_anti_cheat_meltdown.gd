extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Meltdown & Endgame (Member 8: Audio & QA Lead)
## Verifies that emergency repairs and Endgame transitions cannot be exploited by clients:
##   1. Reject Impostor attempting to complete Meltdown emergency systems
##   2. Reject eliminated Crew attempting to restore emergency systems
##   3. Reject emergency system requests outside GameState.MELTDOWN
##   4. Reject non-existent emergency system identifiers
##   5. Reject duplicate / replay completion submissions
##   6. Verify absolute game-over lockdown against post-match interactions

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7795
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: MELTDOWN & ENDGAME AUTHORITY")
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
	_log_info("Setting up 8 players for Meltdown authority verification...")
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

	# --- TEST 1: Reject Emergency System Completion Outside Meltdown ---
	var premature_res: bool = server_mgr.meltdown_manager.complete_emergency_system(crew_ids[0], MeltdownConfig.SYSTEM_RESTORE_POWER)
	if not premature_res:
		_log_pass("TEST 1: Emergency system completion outside MELTDOWN safely rejected.")
	else:
		_log_fail("TEST 1: Server permitted emergency repair before Meltdown phase!")

	# Start Meltdown
	server_mgr.meltdown_manager.start_meltdown(true)

	# --- TEST 2: Reject Impostor Attempting Emergency Repairs ---
	var imp_res: bool = server_mgr.meltdown_manager.complete_emergency_system(impostor_id, MeltdownConfig.SYSTEM_RESTORE_POWER)
	if not imp_res:
		_log_pass("TEST 2: Impostor attempt to restore emergency systems safely rejected.")
	else:
		_log_fail("TEST 2: Impostor was allowed to restore emergency system!")

	# --- TEST 3: Reject Eliminated Crew Member Attempting Repairs ---
	var dead_crew: int = crew_ids[1]
	server_mgr.connected_players[dead_crew].is_alive = false
	var dead_res: bool = server_mgr.meltdown_manager.complete_emergency_system(dead_crew, MeltdownConfig.SYSTEM_RESTORE_COOLING)
	if not dead_res:
		_log_pass("TEST 3: Dead/eliminated Crew attempt to restore emergency systems safely rejected.")
	else:
		_log_fail("TEST 3: Dead player was allowed to restore emergency system!")

	# --- TEST 4: Reject Invalid / Non-Existent Emergency System ID ---
	var fake_sys_res: bool = server_mgr.meltdown_manager.complete_emergency_system(crew_ids[0], "hack_bypass_core_overload")
	if not fake_sys_res:
		_log_pass("TEST 4: Non-existent emergency system ID safely rejected.")
	else:
		_log_fail("TEST 4: Server accepted non-existent emergency system ID!")

	# --- TEST 5: Reject Duplicate Emergency System Restoration ---
	var valid_crew: int = crew_ids[0]
	var res1: bool = server_mgr.meltdown_manager.complete_emergency_system(valid_crew, MeltdownConfig.SYSTEM_RESTORE_POWER)
	var res2: bool = server_mgr.meltdown_manager.complete_emergency_system(valid_crew, MeltdownConfig.SYSTEM_RESTORE_POWER)
	if res1 and not res2:
		_log_pass("TEST 5: Duplicate restoration of already repaired emergency system rejected.")
	else:
		_log_fail("TEST 5: Duplicate emergency restoration succeeded!")

	# Complete all 3 to trigger Game Over
	server_mgr.meltdown_manager.complete_emergency_system(valid_crew, MeltdownConfig.SYSTEM_RESTORE_COOLING)
	server_mgr.meltdown_manager.complete_emergency_system(valid_crew, MeltdownConfig.SYSTEM_STABILIZE_ORION)

	# --- TEST 6: Absolute Lockdown After GAME_OVER ---
	var post_game_res: bool = server_mgr.meltdown_manager.complete_emergency_system(valid_crew, MeltdownConfig.SYSTEM_RESTORE_POWER)
	if not post_game_res and server_mgr.meltdown_manager.is_game_over:
		_log_pass("TEST 6: Complete match lockdown enforced after GAME_OVER.")
	else:
		_log_fail("TEST 6: Interaction allowed after game over!")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  RESULT: ALL MELTDOWN ANTI-CHEAT TESTS PASSED (6/6)")
	else:
		print("  RESULT: SOME TESTS FAILED")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.peer.close()
	
	quit(0 if test_passed else 1)
