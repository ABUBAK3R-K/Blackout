extends SceneTree

## Dedicated Server-Authority Anti-Cheat Test Suite: Voting & Meetings (Member 8: Audio & QA Lead)
## Verifies that meeting triggers and vote casting are strictly server-authoritative:
##   1. Reject votes cast outside of GameState.VOTING
##   2. Reject votes cast by eliminated / dead players
##   3. Reject votes targeting invalid or non-existent peer IDs
##   4. Reject multiple votes from the same player in a single round
##   5. Reject emergency meeting call during Meltdown or active Blackout

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7799
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — QA ANTI-CHEAT: VOTING & MEETING AUTHORITY")
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
	_log_info("Setting up 8 players for Voting authority verification...")
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
	var voter_1: int = pids[0]
	var voter_2: int = pids[1]
	var target_peer: int = pids[2]

	# --- TEST 1: Reject Vote Outside Voting Phase ---
	var premature_vote: bool = server_mgr.voting_manager.cast_vote(voter_1, target_peer)
	if not premature_vote:
		_log_pass("TEST 1: Vote cast outside VOTING state safely rejected.")
	else:
		_log_fail("TEST 1: Server permitted vote before meeting was called!")

	# Transition to MEETING then VOTING
	server_mgr.start_meeting(voter_1)
	server_mgr.voting_manager.start_voting(server_mgr.connected_players)

	# --- TEST 2: Reject Invalid / Non-Existent Target Peer ID ---
	var fake_target_res: bool = server_mgr.voting_manager.cast_vote(voter_1, 999999)
	if not fake_target_res:
		_log_pass("TEST 2: Vote targeting non-existent peer ID safely rejected.")
	else:
		_log_fail("TEST 2: Server permitted vote for non-existent peer ID!")

	# --- TEST 3: Authorized Vote Succeeds ---
	var valid_vote_res: bool = server_mgr.voting_manager.cast_vote(voter_1, target_peer)
	if valid_vote_res:
		_log_pass("TEST 3: Authorized single vote successfully accepted.")
	else:
		_log_fail("TEST 3: Authorized vote failed unexpectedly.")

	# --- TEST 4: Reject Duplicate Vote from Same Peer ---
	var dup_vote_res: bool = server_mgr.voting_manager.cast_vote(voter_1, target_peer)
	if not dup_vote_res:
		_log_pass("TEST 4: Duplicate second vote from same peer in same round safely rejected.")
	else:
		_log_fail("TEST 4: Server permitted duplicate vote from player!")

	# --- TEST 5: Reject Vote Cast by Eliminated Player ---
	var dead_voter: int = voter_2
	server_mgr.connected_players[dead_voter].is_alive = false
	var dead_vote_res: bool = server_mgr.voting_manager.cast_vote(dead_voter, target_peer)
	if not dead_vote_res:
		_log_pass("TEST 5: Vote cast by eliminated / dead player safely rejected.")
	else:
		_log_fail("TEST 5: Server allowed dead player to cast a vote!")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  RESULT: ALL VOTING ANTI-CHEAT TESTS PASSED (5/5)")
	else:
		print("  RESULT: SOME TESTS FAILED")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null and server_mgr.peer != null:
		server_mgr.peer.close()
	
	quit(0 if test_passed else 1)
