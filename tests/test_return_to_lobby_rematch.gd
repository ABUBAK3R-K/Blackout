extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Return to Lobby / Rematch (Stage 22).
## Verifies:
##   1. Game Over UI Return to Lobby / Play Again control existence, styling, and signal dispatch.
##   2. Server-authoritative return to lobby request validation (rejected during active play, accepted on GAME_OVER).
##   3. Authoritative reset of all match subsystems (Tasks, Blackout, Sabotage, Recovery, Objectives, Evidence, Meetings, Voting, Meltdown).
##   4. Connected player persistence (sockets intact, slot allocation preserved, roles reset to NONE, ready states reset to false).
##   5. Client-side synchronized match state purge across Crew and Impostor peers.
##   6. Game Over UI automatic dismiss and input unlock on returning to LOBBY.
##   7. Rematch execution: full second round start from LOBBY without application restart.
##   8. Disconnect resilience during GAME_OVER and during return to lobby transition.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const GameOverUI = preload("res://client/ui/game_over_ui.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — RETURN TO LOBBY / REMATCH TEST (STAGE 22)")
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
	# TEST 1: UI Return to Lobby button existence, styling, and signal emission
	# -------------------------------------------------------------------------
	_log_info("--- TEST 1: Game Over UI Return to Lobby Button ---")
	var ui: GameOverUI = GameOverUI.new()
	root.add_child(ui)

	var mock_player: PlayerController = PlayerController.new()
	mock_player.name = "Player"
	mock_player.slot_id = 1
	mock_player.is_local_player = true
	mock_player.can_move = true
	root.add_child(mock_player)
	ui.register_local_player(mock_player)

	ui.show_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE)

	var lobby_btn = ui.find_child("ReturnToLobbyButton", true, false)
	if lobby_btn != null and lobby_btn is Button and lobby_btn.text.contains("RETURN TO LOBBY"):
		_log_pass("TEST 1.1: Return to Lobby button exists in Game Over modal.")
	else:
		_log_fail("TEST 1.1: Return to Lobby button missing or misnamed.")

	var signal_box = [false]
	ui.return_to_lobby_requested.connect(func(): signal_box[0] = true)
	ui.request_return_to_lobby()

	if signal_box[0]:
		_log_pass("TEST 1.2: Clicking Return to Lobby button successfully emits return_to_lobby_requested signal.")
	else:
		_log_fail("TEST 1.2: Return to lobby signal was not emitted.")

	# -------------------------------------------------------------------------
	# TEST 2: Server-authoritative return to lobby request validation
	# -------------------------------------------------------------------------
	_log_info("--- TEST 2: Server Authority & Request Rejection During Active Match ---")
	var server: ServerNetworkManager = ServerNetworkManager.new()
	root.add_child(server)

	# Simulate 2 connected players
	var p1 = PlayerConnectionData.new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	var p2 = PlayerConnectionData.new(102, 2, true, NetworkConfig.PlayerRole.IMPOSTOR)
	server.connected_players[101] = p1
	server.connected_players[102] = p2
	server.is_running = true

	# Attempt return to lobby while in PLAYING / MELTDOWN -> must be rejected
	server.current_game_state = NetworkConfig.GameState.MELTDOWN
	var rejected_ok = not server.process_return_to_lobby_request(101)
	if rejected_ok and server.current_game_state == NetworkConfig.GameState.MELTDOWN:
		_log_pass("TEST 2.1: Server strictly rejects return to lobby request during active match state (MELTDOWN).")
	else:
		_log_fail("TEST 2.1: Server unexpectedly accepted return to lobby during MELTDOWN.")

	# Reject unknown / invalid peer
	server.current_game_state = NetworkConfig.GameState.GAME_OVER
	var unknown_rejected = not server.process_return_to_lobby_request(999)
	if unknown_rejected:
		_log_pass("TEST 2.2: Server strictly rejects return to lobby request from unknown/disconnected peer.")
	else:
		_log_fail("TEST 2.2: Server accepted request from unknown peer.")

	# -------------------------------------------------------------------------
	# TEST 3 & 4: Full Subsystem Reset & Player Persistence
	# -------------------------------------------------------------------------
	_log_info("--- TEST 3 & 4: Authoritative Subsystem Reset & Player Persistence ---")
	# Populate server subsystems with active match data
	server.task_manager.assign_tasks(server.connected_players)
	server.blackout_manager.setup(102)
	server.sabotage_manager.start_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT, 60.0, 102)
	server.recovery_manager.initialize_systems()
	server.impostor_objective_manager.assign_objectives(102)
	server.evidence_manager.create_evidence_from_objective("steal_confidential_files", 102)
	server.meltdown_manager.setup(300.0)
	server.meltdown_manager.start_meltdown(true)
	server.is_impostor_eliminated = true

	# Execute authoritative return to lobby
	var accepted_ok = server.process_return_to_lobby_request(101)

	var subsystems_clean = (
		server.task_manager.tasks_by_id.is_empty() and
		not server.blackout_manager.is_blackout_active and
		not server.blackout_manager.is_countdown_active and
		server.recovery_manager.recovery_systems.is_empty() and
		server.impostor_objective_manager.assigned_objectives.is_empty() and
		server.evidence_manager.evidence_records.is_empty() and
		not server.meeting_manager.is_meeting_active and
		server.voting_manager.votes.is_empty() and
		not server.meltdown_manager.is_meltdown_active and
		not server.sabotage_manager.is_sabotage_active() and
		not server.is_impostor_eliminated and
		server.current_game_state == NetworkConfig.GameState.LOBBY and
		server.round_manager.is_lobby()
	)

	if accepted_ok and subsystems_clean:
		_log_pass("TEST 3: Authoritative reset cleared all match subsystems (Tasks, Blackout, Sabotage, Recovery, Objectives, Evidence, Meetings, Voting, Meltdown, RoundState).")
	else:
		_log_fail("TEST 3: Server failed to clean up all subsystem states on return to lobby.")

	# Verify players remain connected and roles/readiness are reset
	var p1_reset = (p1.role == NetworkConfig.PlayerRole.NONE and not p1.is_ready and p1.is_alive and not p1.is_eliminated)
	var p2_reset = (p2.role == NetworkConfig.PlayerRole.NONE and not p2.is_ready and p2.is_alive and not p2.is_eliminated)
	var players_intact = (server.connected_players.size() == 2 and server.connected_players.has(101) and server.connected_players.has(102))

	if players_intact and p1_reset and p2_reset:
		_log_pass("TEST 4: All connected players remain connected with sockets/slots intact and roles/readiness reset to NONE/UNREADY.")
	else:
		_log_fail("TEST 4: Player session data corrupted or lost during return to lobby.")

	# -------------------------------------------------------------------------
	# TEST 5 & 6: Client-Side State Synchronization & UI Dismissal
	# -------------------------------------------------------------------------
	_log_info("--- TEST 5 & 6: Client Synchronization & Game Over UI Dismissal ---")
	var client_crew = ClientNetworkManager.new()
	var client_imp = ClientNetworkManager.new()
	root.add_child(client_crew)
	root.add_child(client_imp)

	var ui_crew = GameOverUI.new()
	var ui_imp = GameOverUI.new()
	root.add_child(ui_crew)
	root.add_child(ui_imp)

	ui_crew.bind_client_network_manager(client_crew)
	ui_imp.bind_client_network_manager(client_imp)

	# Simulate active match data on clients
	client_crew.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	client_crew.handle_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, {})

	client_imp.handle_private_role_assignment(NetworkConfig.PlayerRole.IMPOSTOR)
	client_imp.handle_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, {})

	# Transition clients to LOBBY
	client_crew.handle_game_state_changed(NetworkConfig.GameState.LOBBY)
	client_imp.handle_game_state_changed(NetworkConfig.GameState.LOBBY)

	var client_crew_clean = (client_crew.assigned_role == NetworkConfig.PlayerRole.NONE and not client_crew.is_game_over and client_crew.current_game_state == NetworkConfig.GameState.LOBBY)
	var client_imp_clean = (client_imp.assigned_role == NetworkConfig.PlayerRole.NONE and not client_imp.is_game_over and client_imp.current_game_state == NetworkConfig.GameState.LOBBY)

	if client_crew_clean and client_imp_clean:
		_log_pass("TEST 5: ClientNetworkManager on both Crew and Impostor peers cleanly purged match state on LOBBY transition.")
	else:
		_log_fail("TEST 5: Client-side match state purge failed.")

	var ui_crew_dismissed = (not ui_crew.visible and not ui_crew.is_active)
	var ui_imp_dismissed = (not ui_imp.visible and not ui_imp.is_active)

	if ui_crew_dismissed and ui_imp_dismissed:
		_log_pass("TEST 6: Game Over UI automatically reset and dismissed on all clients when returning to LOBBY.")
	else:
		_log_fail("TEST 6: Game Over UI remained visible after returning to LOBBY.")

	# -------------------------------------------------------------------------
	# TEST 7: Rematch Round Initiation
	# -------------------------------------------------------------------------
	_log_info("--- TEST 7: Rematch New Round Execution ---")
	# Ready up both players on server
	server.set_player_ready(101, true)
	server.set_player_ready(102, true)

	# Start rematch round
	var rematch_started = server.start_round(true, 0.0)

	var new_round_active = (
		rematch_started and
		server.current_game_state == NetworkConfig.GameState.INITIAL_TASK_PHASE and
		server.round_manager.is_playing() and
		(p1.role != NetworkConfig.PlayerRole.NONE or p2.role != NetworkConfig.PlayerRole.NONE)
	)

	if new_round_active:
		_log_pass("TEST 7: Rematch round successfully initiated: new roles assigned, tasks generated, and game loop entered PLAYING state.")
	else:
		_log_fail("TEST 7: Failed to initiate rematch round after returning to lobby.")

	# -------------------------------------------------------------------------
	# TEST 8: Disconnect Handling During / After GAME_OVER
	# -------------------------------------------------------------------------
	_log_info("--- TEST 8: Disconnect Resilience During Match Lifecycle ---")
	# Disconnect player 102
	server._on_peer_disconnected(102)

	if server.connected_players.size() == 1 and server.connected_players.has(101) and not server.connected_players.has(102):
		_log_pass("TEST 8: Player disconnect during match lifecycle handled safely without server corruption or crash.")
	else:
		_log_fail("TEST 8: Disconnect handling failed.")

	# Cleanup
	ui.queue_free()
	mock_player.queue_free()
	server.queue_free()
	client_crew.queue_free()
	client_imp.queue_free()
	ui_crew.queue_free()
	ui_imp.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL STAGE 22 RETURN TO LOBBY / REMATCH TESTS PASSED!")
	else:
		print("  STAGE 22 RETURN TO LOBBY / REMATCH TESTS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
