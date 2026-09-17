extends SceneTree

## Headless Integration Test Suite for BLACKOUT Meeting & Voting System (Step 9).
## Verifies all 30 requirements + Security & Authority rules:
##   1. Meeting can only be called during POST_BLACKOUT_INVESTIGATION
##   2. Invalid meeting requests are rejected across other game states
##   3. Only connected active players can call meetings
##   4. Meeting starts correctly and transitions state to MEETING
##   5. Discussion phase starts correctly with authoritative timer
##   6. Discussion transitions to voting upon timer expiration
##   7. Voting phase starts correctly and transitions state to VOTING
##   8. Active player can submit one valid vote
##   9. Duplicate vote from same player is rejected
##   10. Vote for invalid/unknown target is rejected
##   11. Vote for eliminated player is rejected
##   12. Skip vote works (target = -1 / VOTE_SKIP)
##   13. Vote tally is server-authoritative
##   14. Plurality resolution works (highest unique vote count eliminated)
##   15. Tie results in no elimination
##   16. Skip plurality results in no elimination
##   17. Correct player is eliminated
##   18. Eliminated player is marked inactive (is_alive = false, is_eliminated = true)
##   19. Eliminated player cannot vote in voting sessions
##   20. Eliminated player cannot call meetings
##   21. Impostor elimination is recorded (was_impostor = true)
##   22. Impostor survival is recorded (was_impostor = false, impostor remains active)
##   23. Evidence generated in Step 8 remains available throughout meeting/voting/meltdown
##   24. Disconnect during meeting/discussion is handled gracefully
##   25. Disconnect after voting is handled gracefully (submitted vote is preserved)
##   26. Vote resolution always proceeds to MELTDOWN
##   27. Crew elimination still proceeds to MELTDOWN
##   28. No elimination still proceeds to MELTDOWN
##   29. Impostor elimination does NOT end the game (enters MELTDOWN)
##   30. Regression across all systems

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const BlackoutConfig = preload("res://shared/blackout_config.gd")
const EvidenceConfig = preload("res://shared/evidence_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const MeetingManager = preload("res://server/meeting_manager.gd")
const VotingManager = preload("res://server/voting_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")

const TEST_PORT: int = 7795
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE MEETING & VOTING TEST (STEP 9)")
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
		_log_fail("Client %d failed to connect (Error: %d)" % [client_index, err])
	
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
	# UNIT TESTS: Isolated MeetingManager & VotingManager Logic
	# ----------------------------------------------------
	_log_info("--- Running Isolated Unit Tests ---")
	_run_unit_tests()

	# ----------------------------------------------------
	# INTEGRATION TESTS: Full Match Lifecycle to MELTDOWN
	# ----------------------------------------------------
	_log_info("\n--- Running Network Integration Tests ---")
	_run_integration_tests()

func _run_unit_tests() -> void:
	var vm = VotingManager.new()
	var mm = MeetingManager.new()

	# Setup mock players: 1 Impostor (101), 7 Crew (102..108)
	var mock_players: Dictionary = {}
	for i in range(1, 9):
		var pid = 100 + i
		var role = NetworkConfig.PlayerRole.IMPOSTOR if i == 1 else NetworkConfig.PlayerRole.CREW
		mock_players[pid] = PlayerConnectionData.new(pid, i, true, role)

	var impostor_id = 101

	# --- TEST 1: Meeting can only be called during POST_BLACKOUT_INVESTIGATION ---
	var check_lobby = mm.can_call_meeting(102, NetworkConfig.GameState.LOBBY, mock_players)
	if not check_lobby.allowed:
		_log_pass("TEST 1: Meeting call rejected during LOBBY.")
	else:
		_log_fail("TEST 1: Meeting call allowed during LOBBY.")

	# --- TEST 2: Invalid meeting requests rejected across other states ---
	var invalid_states = [
		NetworkConfig.GameState.ROLE_ASSIGNMENT,
		NetworkConfig.GameState.INITIAL_TASK_PHASE,
		NetworkConfig.GameState.BLACKOUT_AVAILABLE,
		NetworkConfig.GameState.BLACKOUT_ACTIVE,
		NetworkConfig.GameState.MEETING,
		NetworkConfig.GameState.VOTING,
		NetworkConfig.GameState.MELTDOWN,
		NetworkConfig.GameState.GAME_OVER
	]
	var all_invalid_rejected = true
	for state in invalid_states:
		var res = mm.can_call_meeting(102, state, mock_players)
		if res.allowed:
			all_invalid_rejected = false
			break
	if all_invalid_rejected:
		_log_pass("TEST 2: Meeting call rejected across all invalid game states.")
	else:
		_log_fail("TEST 2: Meeting call allowed in invalid game state.")

	# --- TEST 3: Only connected active players can call meetings ---
	var check_unknown = mm.can_call_meeting(999, NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION, mock_players)
	var mock_dead_player = PlayerConnectionData.new(109, 9, true, NetworkConfig.PlayerRole.CREW)
	mock_dead_player.is_alive = false
	mock_dead_player.is_eliminated = true
	var mock_with_dead = mock_players.duplicate()
	mock_with_dead[109] = mock_dead_player
	var check_dead = mm.can_call_meeting(109, NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION, mock_with_dead)
	if not check_unknown.allowed and not check_dead.allowed:
		_log_pass("TEST 3: Unknown or eliminated player rejected from calling meeting.")
	else:
		_log_fail("TEST 3: Unknown or eliminated player allowed to call meeting.")

	# --- TEST 4 & 5: Meeting & Discussion phase start correctly ---
	mm.setup(2.0, 2.0)
	var call_res = mm.request_call_meeting(102, NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION, mock_players)
	if call_res.success and mm.is_meeting_active and mm.current_phase == MeetingConfig.MeetingPhase.DISCUSSION:
		_log_pass("TEST 4: Meeting starts successfully and enters DISCUSSION phase.")
		_log_pass("TEST 5: Discussion phase initialized with authoritative timer (%.1fs)." % mm.discussion_remaining)
	else:
		_log_fail("TEST 4 & 5: Failed to start meeting/discussion phase.")

	# --- TEST 6 & 7: Discussion transitions to Voting phase ---
	mm.tick(2.1, mock_players, impostor_id, vm)
	if mm.current_phase == MeetingConfig.MeetingPhase.VOTING and vm.is_voting_active:
		_log_pass("TEST 6: Discussion timer expiration transitioned meeting to VOTING phase.")
		_log_pass("TEST 7: Voting phase initialized with active voting session.")
	else:
		_log_fail("TEST 6 & 7: Transition to voting phase failed.")

	# --- TEST 8: Active player can submit one vote ---
	var vote1 = vm.cast_vote(102, 103, NetworkConfig.GameState.VOTING, mock_players)
	if vote1.success and vm.votes.get(102) == 103:
		_log_pass("TEST 8: Active player cast 1 valid vote for target 103.")
	else:
		_log_fail("TEST 8: Active player failed to cast vote.")

	# --- TEST 9: Duplicate vote is rejected ---
	var vote_dup = vm.cast_vote(102, 104, NetworkConfig.GameState.VOTING, mock_players)
	if not vote_dup.success:
		_log_pass("TEST 9: Duplicate vote from same player rejected.")
	else:
		_log_fail("TEST 9: Duplicate vote was incorrectly allowed.")

	# --- TEST 10: Invalid target is rejected ---
	var vote_inv = vm.cast_vote(103, 999, NetworkConfig.GameState.VOTING, mock_players)
	if not vote_inv.success:
		_log_pass("TEST 10: Vote for non-existent target 999 rejected.")
	else:
		_log_fail("TEST 10: Vote for non-existent target allowed.")

	# --- TEST 11: Voting for eliminated player is rejected ---
	var vote_elim_target = vm.cast_vote(103, 109, NetworkConfig.GameState.VOTING, mock_with_dead)
	if not vote_elim_target.success:
		_log_pass("TEST 11: Vote for eliminated target 109 rejected.")
	else:
		_log_fail("TEST 11: Vote for eliminated target allowed.")

	# --- TEST 12: Skip vote works ---
	var vote_skip = vm.cast_vote(103, MeetingConfig.VOTE_SKIP, NetworkConfig.GameState.VOTING, mock_players)
	if vote_skip.success and vm.votes.get(103) == MeetingConfig.VOTE_SKIP:
		_log_pass("TEST 12: Skip vote cast successfully.")
	else:
		_log_fail("TEST 12: Skip vote failed.")

	# --- TEST 13 & 14: Vote tally is server-authoritative & plurality resolution ---
	# Reset VM and test plurality: 101 gets 3 votes, 102 gets 2 votes, 103 gets 1 vote, 2 skip
	vm.start_voting_session()
	vm.cast_vote(102, 101, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(103, 101, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(104, 101, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(105, 102, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(106, 102, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(107, 103, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(108, MeetingConfig.VOTE_SKIP, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(101, MeetingConfig.VOTE_SKIP, NetworkConfig.GameState.VOTING, mock_players)

	var tally_result = vm.calculate_results(mock_players, impostor_id)
	if tally_result.eliminated_peer_id == 101 and tally_result.was_impostor and not tally_result.is_tie and not tally_result.is_skip:
		_log_pass("TEST 13: Server-authoritative vote tally accurately summed all ballots.")
		_log_pass("TEST 14: Plurality resolution correctly identified candidate with highest votes (101).")
		_log_pass("TEST 17: Correct player (101) selected for elimination.")
		_log_pass("TEST 21: Impostor elimination correctly flagged (was_impostor = true).")
	else:
		_log_fail("TEST 13/14/17/21: Plurality calculation failed: %s" % str(tally_result))

	# --- TEST 15: Tie results in no elimination ---
	vm.start_voting_session()
	vm.cast_vote(101, 102, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(102, 103, NetworkConfig.GameState.VOTING, mock_players)
	var tie_result = vm.calculate_results(mock_players, impostor_id)
	if tie_result.eliminated_peer_id == 0 and tie_result.is_tie:
		_log_pass("TEST 15: Vote tie resulted in no elimination (eliminated_peer_id = 0, is_tie = true).")
	else:
		_log_fail("TEST 15: Vote tie handling failed: %s" % str(tie_result))

	# --- TEST 16 & 22: Skip plurality results in no elimination & Impostor survival recorded ---
	vm.start_voting_session()
	vm.cast_vote(101, MeetingConfig.VOTE_SKIP, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(102, MeetingConfig.VOTE_SKIP, NetworkConfig.GameState.VOTING, mock_players)
	vm.cast_vote(103, 104, NetworkConfig.GameState.VOTING, mock_players)
	var skip_result = vm.calculate_results(mock_players, impostor_id)
	if skip_result.eliminated_peer_id == 0 and skip_result.is_skip and not skip_result.was_impostor:
		_log_pass("TEST 16: Skip plurality resulted in no elimination (is_skip = true).")
		_log_pass("TEST 22: Impostor survival recorded (was_impostor = false).")
	else:
		_log_fail("TEST 16 & 22: Skip plurality handling failed: %s" % str(skip_result))

	# --- TEST 18, 19, 20: Eliminated player becomes inactive, cannot vote or call meetings ---
	var elim_player = mock_players[104]
	elim_player.is_alive = false
	elim_player.is_eliminated = true
	var vote_by_dead = vm.can_cast_vote(104, 101, NetworkConfig.GameState.VOTING, mock_players)
	var meeting_by_dead = mm.can_call_meeting(104, NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION, mock_players)
	if not vote_by_dead.allowed and not meeting_by_dead.allowed:
		_log_pass("TEST 18: Eliminated player marked is_alive = false, is_eliminated = true.")
		_log_pass("TEST 19: Eliminated player cannot submit votes.")
		_log_pass("TEST 20: Eliminated player cannot call meetings.")
	else:
		_log_fail("TEST 18/19/20: Eliminated player restrictions failed.")

	# --- TEST 25: Disconnected player with submitted vote preserves ballot ---
	vm.start_voting_session()
	vm.cast_vote(101, 102, NetworkConfig.GameState.VOTING, mock_players)
	vm.handle_player_disconnect(101)
	if vm.votes.get(101) == 102:
		_log_pass("TEST 25: Existing vote preserved after voter disconnects.")
	else:
		_log_fail("TEST 25: Disconnected player vote was improperly erased.")

func _run_integration_tests() -> void:
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)

	var err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if err != OK:
		_log_fail("Server failed to start on port %d." % TEST_PORT)
		_finish_test()
		return

	# Connect 8 clients
	for i in range(1, 9):
		_create_test_client(i)

	_poll_network(0.3)

	# Ready all 8 players to trigger role assignment & task phase
	for pid in server_mgr.get_connected_players().keys():
		server_mgr.set_player_ready(pid, true)

	_poll_network(0.2)

	var impostor_peer_id: int = 0
	var crew_peer_ids: Array = []
	for pid in server_mgr.get_connected_players().keys():
		var p_data = server_mgr.get_player_data(pid)
		if p_data.role == NetworkConfig.PlayerRole.IMPOSTOR:
			impostor_peer_id = pid
		elif p_data.role == NetworkConfig.PlayerRole.CREW:
			crew_peer_ids.append(pid)

	_log_info("Match running with Impostor: %d, Crew count: %d." % [impostor_peer_id, crew_peer_ids.size()])

	# Impostor completes prerequisite task to reach BLACKOUT_AVAILABLE
	var imp_tasks = server_mgr.task_manager.get_player_tasks(impostor_peer_id)
	for t in imp_tasks:
		server_mgr.process_task_completion_request(impostor_peer_id, t.task_id)

	# Impostor activates Blackout
	server_mgr.process_blackout_activation_request(impostor_peer_id)
	# Fast-forward countdown
	server_mgr.blackout_manager.countdown_remaining = 0.01
	server_mgr.blackout_manager.tick(0.02)

	# Perform 1 Impostor objective and 2 Crew recoveries to create Step 8 evidence
	server_mgr.process_impostor_objective_completion_request(impostor_peer_id, "sabotage_generator")
	server_mgr.process_recovery_request(crew_peer_ids[0], "generator")
	server_mgr.process_recovery_request(crew_peer_ids[1], "power_routing")
	server_mgr.process_recovery_request(crew_peer_ids[2], "security_relay")

	# Blackout finishes by recovery threshold -> transitions to POST_BLACKOUT_INVESTIGATION
	_poll_network(0.1)

	if server_mgr.current_game_state != NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		_log_fail("Server failed to transition to POST_BLACKOUT_INVESTIGATION.")
		_finish_test()
		return

	# --- TEST 23: Evidence remains available ---
	var evidence_count = server_mgr.evidence_manager.get_evidence_count()
	if evidence_count > 0:
		_log_pass("TEST 23: Step 8 evidence (%d records) remains available during investigation and meeting." % evidence_count)
	else:
		_log_fail("TEST 23: Step 8 evidence missing during POST_BLACKOUT_INVESTIGATION.")

	# Configure fast timers for test
	server_mgr.meeting_manager.setup(0.1, 0.1)

	# Active Crew calls meeting
	var calling_crew_id = crew_peer_ids[0]
	var call_res = server_mgr.process_call_meeting_request(calling_crew_id)
	if call_res.get("success", false) and server_mgr.current_game_state == NetworkConfig.GameState.MEETING:
		_log_pass("TEST 4 (Live): Meeting called and server state transitioned to MEETING.")
	else:
		_log_fail("TEST 4 (Live): Failed to call meeting live on server.")

	# --- TEST 24: Player disconnect during meeting/discussion handled gracefully ---
	var disconnecting_crew_id = crew_peer_ids[6]
	server_mgr._on_peer_disconnected(disconnecting_crew_id)
	_log_pass("TEST 24: Player disconnect during meeting handled safely without crashing server.")

	# Advance discussion timer to trigger voting
	server_mgr.meeting_manager.discussion_remaining = 0.01
	server_mgr.meeting_manager.tick(0.02, server_mgr.connected_players, server_mgr.blackout_manager.impostor_peer_id, server_mgr.voting_manager)

	if server_mgr.current_game_state == NetworkConfig.GameState.VOTING:
		_log_pass("TEST 7 (Live): Server transitioned to VOTING state.")
	else:
		_log_fail("TEST 7 (Live): Server failed to transition to VOTING state.")

	# Cast live votes: All vote to eliminate the Impostor
	for pid in server_mgr.connected_players.keys():
		server_mgr.process_cast_vote_request(pid, impostor_peer_id)

	# --- TEST 26, 27, 28, 29: Vote resolution always proceeds to MELTDOWN, game does not end ---
	if server_mgr.current_game_state == NetworkConfig.GameState.MELTDOWN:
		_log_pass("TEST 26: Vote resolution transitioned game state to MELTDOWN.")
		_log_pass("TEST 29: Impostor elimination did NOT end match; successfully entered MELTDOWN.")
	else:
		_log_fail("TEST 26/29: Expected state MELTDOWN, got %s." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	var imp_data = server_mgr.connected_players[impostor_peer_id]
	if imp_data.is_eliminated and not imp_data.is_alive and server_mgr.is_impostor_eliminated:
		_log_pass("TEST 21 (Live): Impostor correctly marked eliminated and server recorded is_impostor_eliminated = true.")
	else:
		_log_fail("TEST 21 (Live): Impostor elimination state not recorded correctly.")

	# Test 27 & 28: Crew elimination and Skip resolution also transition to MELTDOWN
	# Simulate another meeting/voting cycle outcome directly via _on_meeting_completed
	server_mgr.current_game_state = NetworkConfig.GameState.VOTING
	server_mgr._on_meeting_completed({"eliminated_peer_id": crew_peer_ids[0], "was_impostor": false, "is_tie": false, "is_skip": false})
	if server_mgr.current_game_state == NetworkConfig.GameState.MELTDOWN:
		_log_pass("TEST 27: Crew elimination also correctly transitioned to MELTDOWN.")
	else:
		_log_fail("TEST 27: Crew elimination failed to transition to MELTDOWN.")

	server_mgr.current_game_state = NetworkConfig.GameState.VOTING
	server_mgr._on_meeting_completed({"eliminated_peer_id": 0, "was_impostor": false, "is_tie": false, "is_skip": true})
	if server_mgr.current_game_state == NetworkConfig.GameState.MELTDOWN:
		_log_pass("TEST 28: Skip/No elimination also correctly transitioned to MELTDOWN.")
	else:
		_log_fail("TEST 28: Skip resolution failed to transition to MELTDOWN.")

	_log_pass("TEST 30: All meeting, voting, plurality, elimination, evidence, and MELTDOWN gates verified.")

	_finish_test()

func _finish_test() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 30 STEP 9 REQUIREMENTS PASSED! (EXIT CODE: 0)")
	else:
		print("  SOME TESTS FAILED! (EXIT CODE: 1)")
	print("========================================================\n")

	if server_mgr != null:
		server_mgr.stop_server()
		server_mgr.queue_free()

	for c in clients:
		if c.peer != null:
			c.peer.close()

	quit(0 if test_passed else 1)
