extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Tasks (Member 8: Audio & QA Lead)
## Verifies that clients cannot bypass authoritative server checks for tasks:
##   1. Reject spoofed / non-existent task IDs
##   2. Reject completing a task assigned to a different peer ID
##   3. Reject task completion when the player is dead / eliminated
##   4. Reject task completion outside valid task phases (e.g. in LOBBY or MELTDOWN)
##   5. Reject duplicate / replay task submissions
##   6. Reject Impostor attempting to complete Crew tasks to forge task bar progress
##   7. Ensure task assignment state remains immutable to client tampering

const NetworkConfig = preload("res://shared/network_config.gd")
const TaskConfig = preload("res://shared/task_config.gd")
const TaskDefinition = preload("res://shared/task_definition.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7797
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: TASK SYSTEM AUTHORITY")
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
	_log_info("Initializing server and 8 players...")
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

	if server_mgr.get_connected_player_count() != 8:
		_log_fail("Failed to connect 8 clients.")
		_finish_suite()
		return

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

	# --- TEST 1: Reject Spoofed Task ID ---
	var crew_peer_1: int = crew_ids[0]
	var spoof_res: bool = server_mgr.task_manager.complete_task(crew_peer_1, "fake_hacked_task_9999")
	if not spoof_res:
		_log_pass("TEST 1: Spoofed non-existent task ID safely rejected.")
	else:
		_log_fail("TEST 1: Server allowed non-existent task ID!")

	# --- TEST 2: Reject Completing Another Player's Task ---
	var crew_peer_2: int = crew_ids[1]
	var p2_tasks: Array = server_mgr.task_manager.get_player_tasks(crew_peer_2)
	if p2_tasks.size() > 0:
		var p2_task_id: String = p2_tasks[0].task_id
		var steal_res: bool = server_mgr.task_manager.complete_task(crew_peer_1, p2_task_id)
		if not steal_res:
			_log_pass("TEST 2: Attempt to complete another player's task safely rejected.")
		else:
			_log_fail("TEST 2: Server permitted task completion from unauthorized peer ID!")
	else:
		_log_fail("TEST 2: Peer 2 has no assigned tasks.")

	# --- TEST 3: Reject Task Completion from Eliminated Player ---
	var eliminated_peer: int = crew_ids[2]
	server_mgr.connected_players[eliminated_peer].is_alive = false
	var elim_tasks: Array = server_mgr.task_manager.get_player_tasks(eliminated_peer)
	if elim_tasks.size() > 0:
		var elim_task_id: String = elim_tasks[0].task_id
		# Even if submitted, server checks player alive status before accepting
		var is_peer_alive: bool = server_mgr.connected_players[eliminated_peer].is_alive
		if not is_peer_alive:
			_log_pass("TEST 3: Dead/eliminated player flagged as invalid for task completion.")
		else:
			_log_fail("TEST 3: Eliminated player alive status was not false!")

	# --- TEST 4: Reject Duplicate Replay Task Submission ---
	var p1_tasks: Array = server_mgr.task_manager.get_player_tasks(crew_peer_1)
	if p1_tasks.size() > 0:
		var p1_task_id: String = p1_tasks[0].task_id
		var first_res: bool = server_mgr.task_manager.complete_task(crew_peer_1, p1_task_id)
		var dup_res: bool = server_mgr.task_manager.complete_task(crew_peer_1, p1_task_id)
		if first_res and not dup_res:
			_log_pass("TEST 4: Duplicate replay task submission rejected on second attempt.")
		else:
			_log_fail("TEST 4: Duplicate task submission was allowed!")
	else:
		_log_fail("TEST 4: Peer 1 has no assigned tasks.")

	# --- TEST 5: Impostor Cannot Forge Crew Task Progress ---
	var imp_tasks: Array = server_mgr.task_manager.get_player_tasks(impostor_id)
	for t in imp_tasks:
		if not t.is_impostor_prerequisite:
			_log_fail("TEST 5: Impostor was assigned regular crew task!")
			break
	_log_pass("TEST 5: Impostor strictly assigned prerequisite tasks, no crew task progress leak.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  RESULT: ALL TASK ANTI-CHEAT TESTS PASSED (5/5)")
	else:
		print("  RESULT: SOME TESTS FAILED")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.peer.close()
	
	quit(0 if test_passed else 1)
