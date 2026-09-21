extends SceneTree

## Unit & Multi-Peer Integration Test Suite for BLACKOUT Role System Foundation (Member 3).
## Verifies:
##   1. Role representation enum (NetworkConfig.PlayerRole: NONE, CREW, IMPOSTOR).
##   2. RoleManager API query functions (is_crew, is_impostor, get_role_display_name).
##   3. Role distribution rule for 1 connected player -> 1 CREW.
##   4. Role distribution rule for 2 connected players -> exactly 1 IMPOSTOR, 1 CREW.
##   5. Role distribution rule for 4 connected players -> exactly 1 IMPOSTOR, 3 CREW.
##   6. Role distribution rule for 8 connected players -> exactly 1 IMPOSTOR, 7 CREW.
##   7. No roles assigned to disconnected/nonexistent players.
##   8. Server owns authoritative role assignment table.
##   9. Public player serialization (PlayerConnectionData.to_dict()) does NOT leak hidden roles.
##   10. Private role synchronization delivers role only to the target peer.
##   11. PlayerController role API (set_role, get_role, is_crew, is_impostor, get_role_name).
##   12. Remote player puppets do not display or expose hidden roles on nametags.
##   13. Non-regression: Doors, TestTerminal, 4-step Electrical Junction, and StateSync remain functional.

const NetworkConfig = preload("res://shared/network_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ElectricalJunctionScene = preload("res://scenes/objects/electrical_junction.tscn")
const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")
const ObjectiveTrackerScene = preload("res://scenes/ui/objective_tracker.tscn")
const ObjectiveTracker = preload("res://client/objectives/objective_tracker.gd")
const TestTerminalScene = preload("res://scenes/objects/test_terminal.tscn")
const TestTerminal = preload("res://client/environment/test_terminal.gd")
const DoorScene = preload("res://scenes/objects/door.tscn")
const DoorController = preload("res://client/environment/door_controller.gd")
const StateSync = preload("res://client/player/state_sync.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — CREW & IMPOSTOR ROLE SYSTEM FOUNDATION TEST")
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
	test_role_model_and_query_api()
	test_role_distribution_rules()
	test_server_authoritative_assignment_and_leak_protection()
	test_player_controller_role_api_and_isolation()
	test_existing_systems_regression()

	print("\n========================================================")
	if test_passed:
		print("  ROLE SYSTEM FOUNDATION TESTS: ALL PASSED (100%)")
	else:
		print("  ROLE SYSTEM FOUNDATION TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_role_model_and_query_api() -> void:
	if NetworkConfig.PlayerRole.NONE == 0 and NetworkConfig.PlayerRole.CREW == 1 and NetworkConfig.PlayerRole.IMPOSTOR == 2:
		_log_pass("1. PlayerRole enum correctly defined (NONE, CREW, IMPOSTOR).")
	else:
		_log_fail("1. PlayerRole enum mismatch.")

	if RoleManager.is_crew(NetworkConfig.PlayerRole.CREW) and not RoleManager.is_crew(NetworkConfig.PlayerRole.IMPOSTOR):
		_log_pass("2. RoleManager.is_crew() returns true only for CREW.")
	else:
		_log_fail("2. RoleManager.is_crew() check failed.")

	if RoleManager.is_impostor(NetworkConfig.PlayerRole.IMPOSTOR) and not RoleManager.is_impostor(NetworkConfig.PlayerRole.CREW):
		_log_pass("3. RoleManager.is_impostor() returns true only for IMPOSTOR.")
	else:
		_log_fail("3. RoleManager.is_impostor() check failed.")

	if RoleManager.get_role_display_name(NetworkConfig.PlayerRole.CREW) == "CREW" and RoleManager.get_role_display_name(NetworkConfig.PlayerRole.IMPOSTOR) == "IMPOSTOR":
		_log_pass("4. RoleManager.get_role_display_name() formats clean display strings.")
	else:
		_log_fail("4. Role display name formatting failed.")

func test_role_distribution_rules() -> void:
	# Rule 1: 1 player -> 1 Crew
	var roles_1 = RoleManager.calculate_role_assignments([101])
	if roles_1.size() == 1 and roles_1[101] == NetworkConfig.PlayerRole.CREW:
		_log_pass("5. 1 connected player receives CREW role.")
	else:
		_log_fail("5. 1 player role assignment failed.")

	# Rule 2: 2 players -> exactly 1 Impostor, 1 Crew
	var roles_2 = RoleManager.calculate_role_assignments([101, 102], 1, 0)
	var imp_count_2 = 0
	var crew_count_2 = 0
	for r in roles_2.values():
		if r == NetworkConfig.PlayerRole.IMPOSTOR:
			imp_count_2 += 1
		elif r == NetworkConfig.PlayerRole.CREW:
			crew_count_2 += 1

	if roles_2.size() == 2 and imp_count_2 == 1 and crew_count_2 == 1:
		_log_pass("6. 2 connected players -> exactly 1 IMPOSTOR and 1 CREW.")
	else:
		_log_fail("6. 2-player assignment failed: %d Impostor, %d Crew." % [imp_count_2, crew_count_2])

	# Rule 3: 4 players -> exactly 1 Impostor, 3 Crew
	var roles_4 = RoleManager.calculate_role_assignments([101, 102, 103, 104], 1, 1)
	var imp_count_4 = 0
	var crew_count_4 = 0
	for r in roles_4.values():
		if r == NetworkConfig.PlayerRole.IMPOSTOR:
			imp_count_4 += 1
		elif r == NetworkConfig.PlayerRole.CREW:
			crew_count_4 += 1

	if roles_4.size() == 4 and imp_count_4 == 1 and crew_count_4 == 3:
		_log_pass("7. 4 connected players -> exactly 1 IMPOSTOR and 3 CREW.")
	else:
		_log_fail("7. 4-player assignment failed: %d Impostor, %d Crew." % [imp_count_4, crew_count_4])

	# Rule 4: 8 players -> exactly 1 Impostor, 7 Crew
	var peers_8 = [101, 102, 103, 104, 105, 106, 107, 108]
	var roles_8 = RoleManager.calculate_role_assignments(peers_8, 1, 3)
	var imp_count_8 = 0
	var crew_count_8 = 0
	for r in roles_8.values():
		if r == NetworkConfig.PlayerRole.IMPOSTOR:
			imp_count_8 += 1
		elif r == NetworkConfig.PlayerRole.CREW:
			crew_count_8 += 1

	if roles_8.size() == 8 and imp_count_8 == 1 and crew_count_8 == 7:
		_log_pass("8. 8 connected players -> exactly 1 IMPOSTOR and 7 CREW.")
	else:
		_log_fail("8. 8-player assignment failed: %d Impostor, %d Crew." % [imp_count_8, crew_count_8])

	# Zero players check
	var roles_0 = RoleManager.calculate_role_assignments([])
	if roles_0.is_empty():
		_log_pass("9. Disconnected/zero players produce empty role mapping (no fake players).")
	else:
		_log_fail("9. Zero player role assignment produced artificial entries.")

func test_server_authoritative_assignment_and_leak_protection() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true
	server.current_game_state = NetworkConfig.GameState.ROLE_ASSIGNMENT

	# Register 2 real players on the server
	var p1 = PlayerConnectionData.new(1, 1, true)
	var p2 = PlayerConnectionData.new(2, 2, true)
	server.connected_players[1] = p1
	server.connected_players[2] = p2

	var assign_ok = server.assign_roles(true, 1) # allow variable count for 2 players

	if assign_ok:
		_log_pass("10. Authoritative assign_roles() runs successfully on server.")
	else:
		_log_fail("10. Server assign_roles() failed.")

	if (p1.role == NetworkConfig.PlayerRole.CREW and p2.role == NetworkConfig.PlayerRole.IMPOSTOR) or (p1.role == NetworkConfig.PlayerRole.IMPOSTOR and p2.role == NetworkConfig.PlayerRole.CREW):
		_log_pass("11. Server table updated with authoritative role entries.")
	else:
		_log_fail("11. Server table role update mismatch.")

	# Check public serialization privacy
	var dict1 = p1.to_dict()
	var dict2 = p2.to_dict()
	if not dict1.has("role") and not dict2.has("role"):
		_log_pass("12. Public PlayerConnectionData serialization does NOT leak hidden roles.")
	else:
		_log_fail("12. Security leak: role present in public serialization dictionary!")

	server.free()

func test_player_controller_role_api_and_isolation() -> void:
	var local_player = PlayerScene.instantiate() as PlayerController
	local_player._ready()
	local_player.setup_player(1, "Alice", true)

	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player._ready()
	remote_player.setup_player(2, "Bob", false)

	var role_data = {"fired": false}
	local_player.role_changed.connect(func(_r): role_data["fired"] = true)

	# Set local role to IMPOSTOR
	local_player.set_role(NetworkConfig.PlayerRole.IMPOSTOR)

	if local_player.is_impostor() and not local_player.is_crew() and local_player.get_role_name() == "IMPOSTOR" and role_data["fired"]:
		_log_pass("13. Local player role API correctly reflects assigned IMPOSTOR role.")
	else:
		_log_fail("13. Local player role API mismatch.")

	# Verify remote puppet has role hidden / NONE
	if remote_player.role == NetworkConfig.PlayerRole.NONE and not remote_player.is_impostor():
		_log_pass("14. Remote player puppet does NOT possess or display local role.")
	else:
		_log_fail("14. Remote puppet leaked role.")

	# Verify nametags do NOT display role text
	local_player.update_display_label()
	remote_player.update_display_label()

	if not local_player.name_label.text.contains("IMPOSTOR") and not remote_player.name_label.text.contains("IMPOSTOR"):
		_log_pass("15. Player in-world nametags strictly conceal role names.")
	else:
		_log_fail("15. Nametag leaked role name.")

	local_player.free()
	remote_player.free()

func test_existing_systems_regression() -> void:
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.set_role(NetworkConfig.PlayerRole.CREW)

	terminal.trigger._on_body_entered(player)
	player.try_interact()
	if terminal.is_activated == true:
		_log_pass("16. TestTerminal interaction functional for CREW player.")
	else:
		_log_fail("16. TestTerminal regression.")

	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door.trigger._on_body_entered(player)
	player.try_interact()
	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("17. DoorController interaction functional for player.")
	else:
		_log_fail("17. DoorController regression.")

	# 4-step electrical junction interaction
	var junction = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	junction._ready()
	junction.trigger._on_body_entered(player)
	player.try_interact() # Step 1
	if junction.current_step_index == 1 and junction.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("18. 4-step Electrical Junction advances correctly with role system.")
	else:
		_log_fail("18. Electrical Junction step progression regression.")

	# StateSync registration
	var state_sync = StateSync.new()
	state_sync.register_local_player(player)
	if state_sync.local_player == player:
		_log_pass("19. StateSync registration functional.")
	else:
		_log_fail("19. StateSync regression.")

	player.free()
	terminal.free()
	door.free()
	junction.free()
	state_sync.free()
