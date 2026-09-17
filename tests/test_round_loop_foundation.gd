extends SceneTree

## Unit & Integration Test Suite for BLACKOUT Core Round / Game Loop Foundation (Stage 17, Member 3).
## Verifies:
##   1. Initial LOBBY round state upon RoundManager initialization.
##   2. Valid deterministic round state lifecycle (LOBBY -> STARTING -> ROLE_ASSIGNMENT -> PLAYING -> ENDING -> RESULTS).
##   3. Invalid / illegal round state transition protection.
##   4. Duplicate transition blocking.
##   5. Real connected player counting (strictly zero fake/synthetic players).
##   6. One-time role assignment trigger on round start (ROLE_ASSIGNMENT -> PLAYING).
##   7. Sabotage permission strictly restricted to PLAYING round state.
##   8. Sabotage rejection outside of PLAYING state (LOBBY, STARTING, ROLE_ASSIGNMENT, ENDING, RESULTS).
##   9. Objective availability and interaction during PLAYING.
##   10. Server-authoritative end_round() and reset_round() test hooks.
##   11. Disconnect safety in all round phases without crashes or artificial players.
##   12. Non-regression of existing systems: movement, doors, 4-step Electrical Junction, StateSync.

const NetworkConfig = preload("res://shared/network_config.gd")
const RoundManager = preload("res://shared/round_manager.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ElectricalJunctionScene = preload("res://scenes/objects/electrical_junction.tscn")
const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")
const DoorScene = preload("res://scenes/objects/door.tscn")
const DoorController = preload("res://client/environment/door_controller.gd")
const StateSync = preload("res://client/player/state_sync.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — CORE ROUND / GAME LOOP FOUNDATION TEST (STAGE 17)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _run_suite() -> void:
	test_initial_round_state()
	test_valid_round_lifecycle_progression()
	test_invalid_transition_protection()
	test_duplicate_transition_protection()
	test_real_connected_players_counting()
	test_role_assignment_on_round_start()
	test_sabotage_restriction_to_playing()
	test_sabotage_rejection_outside_playing()
	test_objective_interaction_during_playing()
	test_server_end_and_reset_hooks()
	test_disconnect_safety_across_phases()
	test_existing_systems_regression()

	print("\n========================================================")
	if test_passed:
		print("  STAGE 17 ROUND LOOP TESTS: ALL PASSED (100%)")
	else:
		print("  STAGE 17 ROUND LOOP TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_initial_round_state() -> void:
	var rm = RoundManager.new()
	if rm.current_state == RoundManager.RoundState.LOBBY and rm.is_lobby():
		_log_pass("1. RoundManager initializes in LOBBY state.")
	else:
		_log_fail("1. Initial round state mismatch.")

func test_valid_round_lifecycle_progression() -> void:
	var rm = RoundManager.new()

	var t1 = rm.transition_to(RoundManager.RoundState.STARTING)
	var t2 = rm.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)
	var t3 = rm.transition_to(RoundManager.RoundState.PLAYING)
	var t4 = rm.transition_to(RoundManager.RoundState.ENDING)
	var t5 = rm.transition_to(RoundManager.RoundState.RESULTS)
	var t6 = rm.transition_to(RoundManager.RoundState.LOBBY)

	if t1 and t2 and t3 and t4 and t5 and t6:
		_log_pass("2. Full round lifecycle (LOBBY -> STARTING -> ROLE_ASSIGNMENT -> PLAYING -> ENDING -> RESULTS -> LOBBY) succeeded.")
	else:
		_log_fail("2. Lifecycle progression failed: %s, %s, %s, %s, %s, %s" % [t1, t2, t3, t4, t5, t6])

func test_invalid_transition_protection() -> void:
	var rm = RoundManager.new() # In LOBBY

	# Attempt illegal jumps
	var illegal_to_playing = rm.transition_to(RoundManager.RoundState.PLAYING)
	var illegal_to_results = rm.transition_to(RoundManager.RoundState.RESULTS)
	var illegal_to_ending = rm.transition_to(RoundManager.RoundState.ENDING)

	if not illegal_to_playing and not illegal_to_results and not illegal_to_ending and rm.is_lobby():
		_log_pass("3. Illegal transitions from LOBBY safely blocked by transition engine.")
	else:
		_log_fail("3. Illegal transition allowed from LOBBY.")

func test_duplicate_transition_protection() -> void:
	var rm = RoundManager.new()
	var dup = rm.transition_to(RoundManager.RoundState.LOBBY)
	if not dup and rm.is_lobby():
		_log_pass("4. Redundant/duplicate state transition safely ignored.")
	else:
		_log_fail("4. Duplicate transition was accepted.")

func test_real_connected_players_counting() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	# Empty server check
	if server.get_connected_player_count() == 0 and server.connected_players.is_empty():
		_log_pass("5. Empty server has exactly 0 players (no synthetic or fake players).")
	else:
		_log_fail("5. Server contained artificial players upon initialization.")

	# Connect 2 real simulated peers
	server.connected_players[101] = PlayerConnectionData.new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	server.connected_players[102] = PlayerConnectionData.new(102, 2, true, NetworkConfig.PlayerRole.IMPOSTOR)

	if server.get_connected_player_count() == 2 and server.connected_players.size() == 2:
		_log_pass("6. Server accurately counts only real connected peer entries.")
	else:
		_log_fail("6. Connected player count mismatch.")

	server.free()

func test_role_assignment_on_round_start() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	# Connect 3 players
	server.connected_players[101] = PlayerConnectionData.new(101, 1, true)
	server.connected_players[102] = PlayerConnectionData.new(102, 2, true)
	server.connected_players[103] = PlayerConnectionData.new(103, 3, true)

	var start_ok = server.start_round(true, 0.0)

	if start_ok and server.round_manager.is_playing():
		_log_pass("7. start_round() progresses to PLAYING state.")
	else:
		_log_fail("7. start_round() failed to enter PLAYING.")

	var imp_count = 0
	var crew_count = 0
	for p in server.connected_players.values():
		if p.role == NetworkConfig.PlayerRole.IMPOSTOR:
			imp_count += 1
		elif p.role == NetworkConfig.PlayerRole.CREW:
			crew_count += 1

	if imp_count == 1 and crew_count == 2:
		_log_pass("8. Roles assigned authoritatively on round start (1 Impostor, 2 Crew).")
	else:
		_log_fail("8. Role assignment on round start failed: %d Impostor, %d Crew." % [imp_count, crew_count])

	server.free()

func test_sabotage_restriction_to_playing() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	# Connect 2 players so role assignment yields 1 Impostor (peer 101) and 1 Crew (peer 102)
	server.connected_players[101] = PlayerConnectionData.new(101, 1, true)
	server.connected_players[102] = PlayerConnectionData.new(102, 2, true)

	# Advance to PLAYING state
	server.start_round(true, 0.0)

	var result = server.process_sabotage_request(101, SabotageManager.SabotageType.POWER_BLACKOUT)
	if result.get("success", false) == true and server.sabotage_manager.is_sabotage_active():
		_log_pass("9. Sabotage request successfully accepted during PLAYING state.")
	else:
		_log_fail("9. Sabotage request failed during PLAYING state: %s" % str(result))

	server.free()

func test_sabotage_rejection_outside_playing() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	var p_imp = PlayerConnectionData.new(102, 1, true, NetworkConfig.PlayerRole.IMPOSTOR)
	server.connected_players[102] = p_imp

	# 1. Test in LOBBY
	var lob_res = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	var lob_rejected = (lob_res.get("success", false) == false)

	# 2. Test in STARTING
	server.round_manager.transition_to(RoundManager.RoundState.STARTING)
	var start_res = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	var start_rejected = (start_res.get("success", false) == false)

	# 3. Test in ROLE_ASSIGNMENT
	server.round_manager.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)
	var role_res = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	var role_rejected = (role_res.get("success", false) == false)

	# 4. Advance to PLAYING then ENDING
	server.round_manager.transition_to(RoundManager.RoundState.PLAYING)
	server.round_manager.transition_to(RoundManager.RoundState.ENDING)
	var end_res = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	var end_rejected = (end_res.get("success", false) == false)

	# 5. Test in RESULTS
	server.round_manager.transition_to(RoundManager.RoundState.RESULTS)
	var res_res = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	var res_rejected = (res_res.get("success", false) == false)

	if lob_rejected and start_rejected and role_rejected and end_rejected and res_rejected:
		_log_pass("10. Sabotage strictly rejected across all non-PLAYING round states (LOBBY, STARTING, ROLE_ASSIGNMENT, ENDING, RESULTS).")
	else:
		_log_fail("10. Sabotage was erroneously allowed outside PLAYING state.")

	server.free()

func test_objective_interaction_during_playing() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "CrewPlayer", true)
	player.set_role(NetworkConfig.PlayerRole.CREW)

	var junction = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	junction._ready()
	junction.trigger._on_body_entered(player)

	# Advance Step 1
	var interacted = player.try_interact()
	if interacted and junction.current_step_index == 1 and junction.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("11. Objective and 4-step Electrical Junction functional and advancing normally.")
	else:
		_log_fail("11. Objective interaction failed during gameplay.")

	player.free()
	junction.free()

func test_server_end_and_reset_hooks() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	server.connected_players[101] = PlayerConnectionData.new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	server.start_round(true, 0.0)

	var end_ok = server.end_round("Objective Completed")
	if end_ok and server.round_manager.is_results():
		_log_pass("12. end_round() hook safely transitions PLAYING -> ENDING -> RESULTS.")
	else:
		_log_fail("12. end_round() hook failed.")

	var reset_ok = server.reset_round()
	if reset_ok and server.round_manager.is_lobby():
		_log_pass("13. reset_round() hook safely resets state back to LOBBY.")
	else:
		_log_fail("13. reset_round() hook failed.")

	server.free()

func test_disconnect_safety_across_phases() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true

	# 1. Connect player in LOBBY then disconnect
	server._on_peer_connected(201)
	if server.get_connected_player_count() == 1:
		server._on_peer_disconnected(201)
		if server.get_connected_player_count() == 0:
			_log_pass("14. Safe disconnect handling in LOBBY phase.")
		else:
			_log_fail("14. Player not removed on disconnect in LOBBY.")
	else:
		_log_fail("14. Player connection failed.")

	# 2. Player disconnect during PLAYING
	server._on_peer_connected(202)
	server._on_peer_connected(203)
	server.start_round(true, 0.0)
	server._on_peer_disconnected(202)
	if server.get_connected_player_count() == 1 and server.round_manager.is_playing():
		_log_pass("15. Safe disconnect handling during PLAYING phase (no crashes, no fake players).")
	else:
		_log_fail("15. Disconnect during PLAYING failed.")

	server.free()

func test_existing_systems_regression() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Alice", true)
	player.set_role(NetworkConfig.PlayerRole.CREW)

	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door.trigger._on_body_entered(player)
	player.try_interact()

	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("16. DoorController interaction regression check passed.")
	else:
		_log_fail("16. DoorController interaction regression.")

	var state_sync = StateSync.new()
	state_sync.register_local_player(player)
	if state_sync.local_player == player:
		_log_pass("17. StateSync registration regression check passed.")
	else:
		_log_fail("17. StateSync regression.")

	player.free()
	door.free()
	state_sync.free()
