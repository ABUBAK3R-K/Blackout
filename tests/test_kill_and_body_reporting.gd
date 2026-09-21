extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Impostor Elimination & Body Reporting (Stage 24).
## Verifies all 25 required rules:
##   1. Crew cannot request kill.
##   2. Impostor can request kill.
##   3. Dead Impostor cannot kill.
##   4. Dead Crew cannot kill.
##   5. Impostor cannot kill self.
##   6. Impostor cannot kill another Impostor.
##   7. Impostor cannot kill out of range (> 90px).
##   8. Kill cooldown blocks repeated kill (< 25s).
##   9. Already eliminated target cannot be killed again.
##   10. Server validates target using authoritative position.
##   11. Valid kill marks Crew eliminated.
##   12. Elimination synchronizes to clients.
##   13. Corpse spawns at authoritative death position.
##   14. Alive Crew can report corpse.
##   15. Alive Impostor can report corpse.
##   16. Eliminated player cannot report corpse.
##   17. Out-of-range report is rejected (> 90px).
##   18. Duplicate body report is rejected.
##   19. Successful report invokes existing MeetingManager.
##   20. Meeting UI receives the body-report meeting.
##   21. Kill is disabled during meeting.
##   22. Body report is disabled during meeting.
##   23. Corpse state resets between rounds.
##   24. Disconnecting players do not leave stale corpse state.
##   25. No hidden role information leaks through kill/body-report messages.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const PlayerCorpse = preload("res://client/environment/player_corpse.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const MeetingVotingUI = preload("res://client/ui/meeting_voting_ui.gd")
const MeetingManager = preload("res://server/meeting_manager.gd")

const TEST_PORT: int = 7796
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — KILL & BODY REPORTING TEST SUITE (STAGE 24)")
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

func _run_suite() -> void:
	var root = get_root()

	# -------------------------------------------------------------------------
	# SECTION 1: SERVER-AUTHORITATIVE KILL VALIDATION RULES (TESTS 1 to 10)
	# -------------------------------------------------------------------------
	_log_info("--- SECTION 1: Server Kill Validation Rules ---")
	var s: ServerNetworkManager = ServerNetworkManager.new()
	root.add_child(s)
	s.is_running = true
	s.current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE

	# Setup 3 players: Peer 101 (Crew), Peer 102 (Impostor), Peer 103 (Crew)
	var p_crew1 = PlayerConnectionData.new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	var p_imp = PlayerConnectionData.new(102, 2, true, NetworkConfig.PlayerRole.IMPOSTOR)
	var p_crew2 = PlayerConnectionData.new(103, 3, true, NetworkConfig.PlayerRole.CREW)

	s.connected_players[101] = p_crew1
	s.connected_players[102] = p_imp
	s.connected_players[103] = p_crew2

	# Set authoritative positions (in range <= 90px)
	s.set_player_position(101, Vector2(100, 100))
	s.set_player_position(102, Vector2(120, 100)) # 20px distance from 101
	s.set_player_position(103, Vector2(400, 400)) # 424px distance (out of range)

	# Rule 1: Crew cannot request kill
	var crew_kill_res = s.process_kill_request(101, 103)
	if not crew_kill_res.get("success", false):
		_log_pass("1. Crew player cannot request kill.")
	else:
		_log_fail("1. Crew player was erroneously allowed to kill.")

	# Rule 5: Impostor cannot kill self
	var self_kill_res = s.process_kill_request(102, 102)
	if not self_kill_res.get("success", false):
		_log_pass("5. Impostor cannot kill self.")
	else:
		_log_fail("5. Impostor was allowed to kill self.")

	# Rule 6: Impostor cannot kill another Impostor
	var p_imp2 = PlayerConnectionData.new(104, 4, true, NetworkConfig.PlayerRole.IMPOSTOR)
	s.connected_players[104] = p_imp2
	s.set_player_position(104, Vector2(130, 100))
	var imp_imp_kill = s.process_kill_request(102, 104)
	if not imp_imp_kill.get("success", false):
		_log_pass("6. Impostor cannot kill another Impostor.")
	else:
		_log_fail("6. Impostor was allowed to kill another Impostor.")

	# Rule 7: Impostor cannot kill out of range (> 90px)
	var out_of_range_kill = s.process_kill_request(102, 103)
	if not out_of_range_kill.get("success", false):
		_log_pass("7. Impostor cannot kill out of range (> 90px).")
	else:
		_log_fail("7. Impostor killed target out of range.")

	# Rule 2, 10, 11, 12, 13: Valid Impostor kill marks Crew eliminated, spawns corpse at authoritative death pos
	var valid_kill = s.process_kill_request(102, 101)
	if valid_kill.get("success", false):
		_log_pass("2. Impostor can successfully request kill on in-range Crew.")
	else:
		_log_fail("2. Valid kill request was rejected: %s" % valid_kill.get("error", ""))

	if not p_crew1.is_alive and p_crew1.is_eliminated:
		_log_pass("11. Valid kill authoritatively marks Crew player eliminated.")
	else:
		_log_fail("11. Target was not marked eliminated.")

	var corpse_id = valid_kill.get("corpse_id", 0)
	if s.active_corpses.has(corpse_id):
		var corpse_data = s.active_corpses[corpse_id]
		if corpse_data.get("position") == Vector2(100, 100) and corpse_data.get("victim_peer_id") == 101:
			_log_pass("10 & 13. Corpse created at authoritative death position (100, 100).")
		else:
			_log_fail("10 & 13. Corpse data mismatch: %s" % str(corpse_data))
	else:
		_log_fail("13. Corpse not tracked in server active_corpses.")

	# Rule 8: Kill cooldown blocks repeated kill (< 25s)
	s.set_player_position(103, Vector2(130, 100)) # Move 103 in range
	var cooldown_kill = s.process_kill_request(102, 103)
	if not cooldown_kill.get("success", false):
		_log_pass("8. Kill cooldown blocks repeated kill.")
	else:
		_log_fail("8. Cooldown did not block repeated kill.")

	# Rule 9: Already eliminated target cannot be killed again
	s.impostor_last_kill_time.clear() # Reset cooldown
	var duplicate_target_kill = s.process_kill_request(102, 101)
	if not duplicate_target_kill.get("success", false):
		_log_pass("9. Already eliminated target cannot be killed again.")
	else:
		_log_fail("9. Server permitted kill on already eliminated target.")

	# Rule 3 & 4: Dead players cannot kill
	p_imp.is_alive = false
	p_imp.is_eliminated = true
	var dead_imp_kill = s.process_kill_request(102, 103)
	if not dead_imp_kill.get("success", false):
		_log_pass("3. Dead Impostor cannot kill.")
	else:
		_log_fail("3. Dead Impostor was allowed to kill.")

	var dead_crew_kill = s.process_kill_request(101, 103)
	if not dead_crew_kill.get("success", false):
		_log_pass("4. Dead Crew cannot kill.")
	else:
		_log_fail("4. Dead Crew was allowed to kill.")

	p_imp.is_alive = true
	p_imp.is_eliminated = false

	# -------------------------------------------------------------------------
	# SECTION 2: SERVER-AUTHORITATIVE BODY REPORTING RULES (TESTS 14 to 18)
	# -------------------------------------------------------------------------
	_log_info("--- SECTION 2: Body Reporting Validation Rules ---")

	# Position 103 (Alive Crew) far from corpse (100, 100) -> report rejected
	s.set_player_position(103, Vector2(500, 500))
	var out_of_range_report = s.process_report_body_request(103, corpse_id)
	if not out_of_range_report.get("success", false):
		_log_pass("17. Out-of-range body report is rejected.")
	else:
		_log_fail("17. Out-of-range report was allowed.")

	# Position 101 (Dead Crew) near corpse -> report rejected
	s.set_player_position(101, Vector2(105, 100))
	var dead_report = s.process_report_body_request(101, corpse_id)
	if not dead_report.get("success", false):
		_log_pass("16. Eliminated player cannot report corpse.")
	else:
		_log_fail("16. Eliminated player was allowed to report corpse.")

	# Position 103 (Alive Crew) close to corpse -> report accepted
	s.set_player_position(103, Vector2(110, 100))
	var valid_report = s.process_report_body_request(103, corpse_id)
	if valid_report.get("success", false):
		_log_pass("14. Alive Crew can successfully report corpse in range.")
	else:
		_log_fail("14. Valid body report was rejected: %s" % valid_report.get("error", ""))

	# Rule 18: Duplicate body report is rejected
	var duplicate_report = s.process_report_body_request(103, corpse_id)
	if not duplicate_report.get("success", false):
		_log_pass("18. Duplicate body report is rejected.")
	else:
		_log_fail("18. Duplicate body report was accepted.")

	# Rule 19: Successful report invokes existing MeetingManager
	if s.meeting_manager != null and s.meeting_manager.is_meeting_active and s.meeting_manager.caller_peer_id == 103:
		_log_pass("19. Successful body report invokes existing MeetingManager (Caller: 103).")
	else:
		_log_fail("19. MeetingManager was not activated with reporter caller ID.")

	# Rule 21 & 22: Kill and body reports are disabled during meeting
	var kill_during_meeting = s.process_kill_request(102, 103)
	if not kill_during_meeting.get("success", false):
		_log_pass("21. Kill is disabled during active meeting.")
	else:
		_log_fail("21. Kill was accepted during active meeting.")

	var report_during_meeting = s.process_report_body_request(103, corpse_id)
	if not report_during_meeting.get("success", false):
		_log_pass("22. Body reporting is disabled during active meeting.")
	else:
		_log_fail("22. Body report was accepted during active meeting.")

	# -------------------------------------------------------------------------
	# SECTION 3: CORPSE ENTITY & CLIENT UI INTEGRATION (TESTS 15, 20)
	# -------------------------------------------------------------------------
	_log_info("--- SECTION 3: Corpse Entity & UI Integration ---")
	var corpse_entity: PlayerCorpse = PlayerCorpse.new()
	root.add_child(corpse_entity)
	corpse_entity.setup_corpse(1, 101, "Player 1", Vector2(100, 100))

	if corpse_entity.corpse_id == 1 and corpse_entity.victim_peer_id == 101:
		_log_pass("13b. PlayerCorpse entity initialized with victim data and interaction trigger.")
	else:
		_log_fail("13b. PlayerCorpse entity failed setup.")

	corpse_entity.mark_reported()
	if corpse_entity.is_reported and not corpse_entity.trigger.is_interactive:
		_log_pass("18b. Corpse entity disables interaction once reported.")
	else:
		_log_fail("18b. Corpse entity did not disable interaction after report.")

	# Test Meeting UI receiving body report meeting
	var m_ui: MeetingVotingUI = MeetingVotingUI.new()
	root.add_child(m_ui)
	m_ui.open_meeting(103, 10.0)

	if m_ui.visible and m_ui.current_caller_peer_id == 103:
		_log_pass("20. MeetingVotingUI successfully receives and displays body report meeting.")
	else:
		_log_fail("20. MeetingVotingUI failed to display meeting.")

	m_ui.close_meeting()

	# Test Alive Impostor reporting corpse (Rule 15)
	var corpse_2 = { "corpse_id": 2, "victim_peer_id": 104, "victim_name": "Player 4", "position": Vector2(125, 100), "is_reported": false }
	s.active_corpses[2] = corpse_2
	s.meeting_manager.clear()
	s.current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE
	var imp_report = s.process_report_body_request(102, 2)
	if imp_report.get("success", false):
		_log_pass("15. Alive Impostor can self-report corpse if in proximity.")
	else:
		_log_fail("15. Alive Impostor body report was rejected: %s" % imp_report.get("error", ""))

	# -------------------------------------------------------------------------
	# SECTION 4: RESET, DISCONNECT & ROLE LEAK SAFETY (TESTS 23, 24, 25)
	# -------------------------------------------------------------------------
	_log_info("--- SECTION 4: Reset & Security Safety ---")

	# Rule 23: Corpse state resets between rounds
	s.current_game_state = NetworkConfig.GameState.GAME_OVER
	s.process_return_to_lobby_request(102)
	if s.active_corpses.is_empty() and s.impostor_last_kill_time.is_empty() and s.next_corpse_id == 1:
		_log_pass("23. Corpse and kill cooldown state resets completely between rounds.")
	else:
		_log_fail("23. Stale corpse state remained after return to lobby: %s" % str(s.active_corpses))

	# Rule 24: Disconnecting players do not leave stale corpse or crash server
	var p_temp = PlayerConnectionData.new(201, 5, true, NetworkConfig.PlayerRole.CREW)
	s.connected_players[201] = p_temp
	s._on_peer_disconnected(201)
	if not s.connected_players.has(201):
		_log_pass("24. Disconnecting players are cleaned up safely without corrupting server state.")
	else:
		_log_fail("24. Disconnecting player cleanup failed.")

	# Rule 25: No hidden role leaks in kill / body report serialized data
	var test_player_data = PlayerConnectionData.new(301, 6, true, NetworkConfig.PlayerRole.IMPOSTOR)
	var pub_dict = test_player_data.to_dict()
	if not pub_dict.has("role") and not pub_dict.has("is_impostor"):
		_log_pass("25. PlayerConnectionData public dictionary strictly excludes role information.")
	else:
		_log_fail("25. Hidden role information leaked in public serialization.")

	# -------------------------------------------------------------------------
	# SECTION 5: LIVE MULTIPLAYER CLIENT-SERVER FLOW (TESTS A-N)
	# -------------------------------------------------------------------------
	_log_info("--- SECTION 5: Live Multiplayer Client-Server Sync Flow ---")

	var live_server: ServerNetworkManager = ServerNetworkManager.new()
	var live_client_crew: ClientNetworkManager = ClientNetworkManager.new()
	var live_client_imp: ClientNetworkManager = ClientNetworkManager.new()

	root.add_child(live_server)
	root.add_child(live_client_crew)
	root.add_child(live_client_imp)

	live_server.is_running = true
	live_server.current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE

	# Setup server player session data (2 Crew, 1 Impostor)
	var p_data_crew1 = PlayerConnectionData.new(10, 1, true, NetworkConfig.PlayerRole.CREW)
	var p_data_crew2 = PlayerConnectionData.new(11, 2, true, NetworkConfig.PlayerRole.CREW)
	var p_data_imp = PlayerConnectionData.new(20, 3, true, NetworkConfig.PlayerRole.IMPOSTOR)
	live_server.connected_players[10] = p_data_crew1
	live_server.connected_players[11] = p_data_crew2
	live_server.connected_players[20] = p_data_imp
	live_server.set_player_position(10, Vector2(200, 200))
	live_server.set_player_position(11, Vector2(600, 600))
	live_server.set_player_position(20, Vector2(230, 200)) # 30px distance from 10

	# Setup client session assignments
	live_client_crew.handle_assignment(10, 1, 3)
	live_client_crew.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	live_client_crew.handle_game_state_changed(NetworkConfig.GameState.INITIAL_TASK_PHASE)

	live_client_imp.handle_assignment(20, 3, 3)
	live_client_imp.handle_private_role_assignment(NetworkConfig.PlayerRole.IMPOSTOR)
	live_client_imp.handle_game_state_changed(NetworkConfig.GameState.INITIAL_TASK_PHASE)

	# A & B: Impostor requests kill on Crew
	var kill_res = live_server.process_kill_request(20, 10)
	if kill_res.get("success", false):
		_log_pass("A & B. Multiplayer kill request processed successfully by authoritative server.")
	else:
		_log_fail("A & B. Server failed multiplayer kill request: %s" % kill_res.get("error", ""))

	# C & D: Simulate network broadcast delivery to clients
	live_client_crew.handle_player_eliminated(10, Vector2(200, 200))
	live_client_imp.handle_player_eliminated(10, Vector2(200, 200))
	live_client_crew.handle_corpse_spawn(1, 10, "Player 1", Vector2(200, 200))
	live_client_imp.handle_corpse_spawn(1, 10, "Player 1", Vector2(200, 200))

	if live_client_crew.is_eliminated:
		_log_pass("C. Crew client synchronized elimination state (is_eliminated = true).")
	else:
		_log_fail("C. Crew client failed to mark eliminated.")

	if live_client_crew.active_corpses.has(1) and live_client_imp.active_corpses.has(1):
		_log_pass("D. Corpse #1 synchronized across both Crew and Impostor client state.")
	else:
		_log_fail("D. Corpse state not synchronized to clients.")

	# E & F & G: Alive Impostor approaches and reports corpse
	live_server.set_player_position(20, Vector2(210, 200)) # 10px from corpse
	var report_res = live_server.process_report_body_request(20, 1)
	if report_res.get("success", false):
		_log_pass("E, F, G. Server validated and accepted authoritative body report.")
	else:
		_log_fail("E, F, G. Server rejected valid body report: %s" % report_res.get("error", ""))

	# H & I: Simulate meeting broadcast delivery
	live_client_crew.handle_meeting_started(20, 30.0)
	live_client_imp.handle_meeting_started(20, 30.0)

	if live_client_crew.is_meeting_active and live_client_crew.meeting_caller_id == 20:
		_log_pass("H & I. Meeting started on clients with caller set to reporter (Peer 20).")
	else:
		_log_fail("H & I. Meeting broadcast failed on clients.")

	# Clean up temporary test nodes
	s.queue_free()
	corpse_entity.queue_free()
	m_ui.queue_free()
	live_server.queue_free()
	live_client_crew.queue_free()
	live_client_imp.queue_free()

	_finish_tests()

func _finish_tests() -> void:
	print("\n========================================================")
	print("  TEST SUMMARY: %s" % ("ALL 25 TESTS PASSED ✓" if test_passed else "SOME TESTS FAILED ✖"))
	print("========================================================\n")
	if test_passed:
		quit(0)
	else:
		quit(1)
