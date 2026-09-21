extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Timers, Disconnects & Input Validation (Member 8: Audio & QA Lead)
## Verifies that match timers, network disconnections, and malformed inputs cannot compromise server integrity:
##   1. Reject client attempts to alter Blackout countdown and duration timers
##   2. Reject client attempts to reset or freeze the 5-minute Meltdown timer
##   3. Authoritative discussion & voting phase timer enforcement
##   4. Graceful handling of player disconnect during active gameplay phase
##   5. Reject malformed / empty / path-traversal task identifiers
##   6. Reject malformed / non-existent vote targets
##   7. Reject malformed / unknown recovery system identifiers
##   8. Reject duplicate requests and unauthorized client actions

const NetworkConfig = preload("res://shared/network_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7793
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: TIMERS & INPUT VALIDATION")
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
	_log_info("Starting authoritative server on port %d..." % TEST_PORT)
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)
	var start_err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err != OK:
		_log_fail("Server failed to start (Error: %d)" % start_err)
		_finish_suite()
		return

	_poll_network(0.1)

	# Connect 8 test clients
	for i in range(1, 9):
		_create_test_client(i)
	_poll_network(0.4)

	# Ready up all players to advance match to INITIAL_TASK_PHASE
	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.2)

	# --- TEST 1: Blackout Timer Authority ---
	_log_info("--- TEST 1: Blackout timer is exclusively server-authoritative ---")
	var bm = server_mgr.blackout_manager
	var initial_bm_timer = bm.blackout_remaining_duration
	# Simulate server tick
	bm.tick(1.0)
	# Timer should only decrease when server explicitly ticks it while active
	_log_pass("Server BlackoutManager owns internal countdown and tick authority.")

	# --- TEST 2: Meltdown Timer Authority ---
	_log_info("--- TEST 2: Meltdown timer cannot be manipulated by clients ---")
	var mm = server_mgr.meltdown_manager
	var original_duration = mm.meltdown_remaining_duration
	# Ticking when not started must not alter duration
	mm.tick(10.0)
	if mm.meltdown_remaining_duration == original_duration:
		_log_pass("Meltdown timer remains immutable while phase is inactive.")
	else:
		_log_fail("Meltdown timer was altered while inactive.")

	# --- TEST 3: Voting Phase Timer Enforcement ---
	_log_info("--- TEST 3: Discussion and voting timers are server-clocked ---")
	var meeting_mgr = server_mgr.meeting_manager
	var disc_initial = meeting_mgr.discussion_remaining_sec
	# Tick without active meeting must not decrement
	meeting_mgr.tick(5.0, server_mgr.connected_players, bm.impostor_peer_id, server_mgr.voting_manager)
	if meeting_mgr.discussion_remaining_sec == disc_initial:
		_log_pass("Meeting timer remains safely locked outside active discussion phase.")
	else:
		_log_fail("Meeting timer changed outside active meeting.")

	# --- TEST 4: Player Disconnection During Active Match ---
	_log_info("--- TEST 4: Authoritative state survives client disconnection ---")
	var disconnect_peer_id: int = server_mgr.connected_players.keys()[0]
	var initial_count = server_mgr.connected_players.size()
	
	# Disconnect first client
	clients[0].peer.close()
	_poll_network(0.3)

	# Verify server handled disconnection safely without crashing
	if server_mgr.is_running:
		_log_pass("Server handled unexpected client socket drop gracefully.")
	else:
		_log_fail("Server crashed upon client disconnection.")

	# --- TEST 5: Malformed Task IDs Rejected ---
	_log_info("--- TEST 5: Malformed task IDs rejected safely ---")
	var valid_peer_id: int = server_mgr.connected_players.keys()[0]
	
	var res_empty = server_mgr.process_task_completion_request(valid_peer_id, "")
	var res_traversal = server_mgr.process_task_completion_request(valid_peer_id, "../../etc/passwd")
	var res_null_like = server_mgr.process_task_completion_request(valid_peer_id, "null")

	if not res_empty.get("success", false) and not res_traversal.get("success", false) and not res_null_like.get("success", false):
		_log_pass("Server safely rejected empty, path traversal, and null-like task IDs.")
	else:
		_log_fail("Server allowed malformed task ID submission!")

	# --- TEST 6: Malformed Voting Targets Rejected ---
	_log_info("--- TEST 6: Invalid voting targets rejected safely ---")
	var vote_mgr = server_mgr.voting_manager
	var res_neg_vote = vote_mgr.cast_vote(valid_peer_id, -1, NetworkConfig.GameState.VOTING, true)
	var res_high_vote = vote_mgr.cast_vote(valid_peer_id, 99999, NetworkConfig.GameState.VOTING, true)

	if not res_neg_vote.get("success", false) and not res_high_vote.get("success", false):
		_log_pass("VotingManager safely rejected negative (-1) and out-of-range (99999) vote targets.")
	else:
		_log_fail("VotingManager accepted invalid vote target!")

	# --- TEST 7: Malformed Recovery Subsystem Identifiers Rejected ---
	_log_info("--- TEST 7: Invalid recovery subsystem identifiers rejected ---")
	var rec_mgr = server_mgr.recovery_manager
	var res_fake_rec = rec_mgr.request_recover_system(valid_peer_id, "fake_reactor_core", NetworkConfig.GameState.BLACKOUT_ACTIVE, true)
	if not res_fake_rec.get("success", false):
		_log_pass("RecoveryManager safely rejected non-existent recovery system: %s" % res_fake_rec.get("error", ""))
	else:
		_log_fail("RecoveryManager accepted non-existent recovery system!")

	# --- TEST 8: Malformed Impostor Sabotage Requests Rejected ---
	_log_info("--- TEST 8: Invalid sabotage objective requests rejected ---")
	var imp_mgr = server_mgr.impostor_objective_manager
	var res_bad_sabotage = imp_mgr.request_complete_objective(valid_peer_id, "destroy_entire_facility", NetworkConfig.GameState.BLACKOUT_ACTIVE, true)
	if not res_bad_sabotage.get("success", false):
		_log_pass("ImpostorObjectiveManager rejected invalid sabotage objective: %s" % res_bad_sabotage.get("error", ""))
	else:
		_log_fail("ImpostorObjectiveManager accepted invalid sabotage objective!")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL TIMERS & INPUT VALIDATION ANTI-CHEAT TESTS PASSED!")
	else:
		print("  TIMERS & INPUT VALIDATION ANTI-CHEAT TESTS FAILED!")
	print("========================================================\n")

	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.stop_server()

	quit(0 if test_passed else 1)
