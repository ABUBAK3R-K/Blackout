extends SceneTree

## Unit & Integration Test Suite for BLACKOUT Sabotage System Foundation (Member 3).
## Verifies:
##   1. Sabotage data model & states (SabotageType: NONE, POWER_BLACKOUT; SabotageState: INACTIVE, ACTIVE, RESOLVED).
##   2. SabotageManager query & validation API.
##   3. Authoritative role security: IMPOSTOR allowed, CREW rejected.
##   4. Duplicate activation protection: multiple simultaneous POWER_BLACKOUT activations blocked.
##   5. Server-authoritative execution: Impostor request activates blackout & state sync.
##   6. Server rejection: Crew request does NOT trigger blackout or state change.
##   7. Sabotage resolution hook: resolve_sabotage() restores power and transitions state.
##   8. ClientNetworkManager state synchronization & signal emissions.
##   9. PlayerController Impostor 'Q' input isolation (Crew 'Q' does nothing).
##   10. HUD role concealment (Crew sees "POWER FAILURE", no role leaks).
##   11. Non-regression of existing systems: movement, doors, 4-step junction, StateSync.

const NetworkConfig = preload("res://shared/network_config.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")
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
	print("  BLACKOUT — IMPOSTOR SABOTAGE SYSTEM FOUNDATION TEST")
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
	test_sabotage_data_model()
	test_sabotage_validation_rules()
	test_duplicate_activation_protection()
	test_server_authoritative_execution_and_rejection()
	test_sabotage_resolution_hook()
	test_client_network_synchronization()
	test_player_controller_sabotage_input_isolation()
	test_hud_role_concealment()
	test_existing_systems_regression()

	print("\n========================================================")
	if test_passed:
		print("  SABOTAGE SYSTEM FOUNDATION TESTS: ALL PASSED (100%)")
	else:
		print("  SABOTAGE SYSTEM FOUNDATION TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_sabotage_data_model() -> void:
	if SabotageManager.SabotageType.NONE == 0 and SabotageManager.SabotageType.POWER_BLACKOUT == 1:
		_log_pass("1. SabotageType enum correctly defined (NONE, POWER_BLACKOUT).")
	else:
		_log_fail("1. SabotageType enum mismatch.")

	if SabotageManager.SabotageState.INACTIVE == 0 and SabotageManager.SabotageState.ACTIVE == 1 and SabotageManager.SabotageState.RESOLVED == 2:
		_log_pass("2. SabotageState enum correctly defined (INACTIVE, ACTIVE, RESOLVED).")
	else:
		_log_fail("2. SabotageState enum mismatch.")

	if SabotageManager.get_sabotage_name(SabotageManager.SabotageType.POWER_BLACKOUT) == "POWER_BLACKOUT" and SabotageManager.get_state_name(SabotageManager.SabotageState.ACTIVE) == "ACTIVE":
		_log_pass("3. SabotageManager helper formatters produce valid strings.")
	else:
		_log_fail("3. SabotageManager formatter mismatch.")

func test_sabotage_validation_rules() -> void:
	var mgr = SabotageManager.new()

	# Impostor should be allowed to trigger POWER_BLACKOUT
	var imp_check = mgr.can_trigger_sabotage(101, NetworkConfig.PlayerRole.IMPOSTOR, SabotageManager.SabotageType.POWER_BLACKOUT)
	if imp_check.allowed == true:
		_log_pass("4. Impostor role authorized to trigger POWER_BLACKOUT sabotage.")
	else:
		_log_fail("4. Impostor role validation failed: %s" % imp_check.reason)

	# Crew must NOT be allowed to trigger sabotage
	var crew_check = mgr.can_trigger_sabotage(102, NetworkConfig.PlayerRole.CREW, SabotageManager.SabotageType.POWER_BLACKOUT)
	if crew_check.allowed == false:
		_log_pass("5. Crew role strictly rejected from triggering sabotage.")
	else:
		_log_fail("5. Security failure: Crew role was allowed to trigger sabotage!")

	# Invalid sabotage type check
	var invalid_check = mgr.can_trigger_sabotage(101, NetworkConfig.PlayerRole.IMPOSTOR, SabotageManager.SabotageType.NONE)
	if invalid_check.allowed == false:
		_log_pass("6. Invalid sabotage type correctly rejected.")
	else:
		_log_fail("6. Invalid sabotage type was allowed.")

func test_duplicate_activation_protection() -> void:
	var mgr = SabotageManager.new()
	mgr.start_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT, 25.0, 101)

	if mgr.is_sabotage_active():
		_log_pass("7. SabotageManager is_sabotage_active() returns true after start.")
	else:
		_log_fail("7. Sabotage state active check failed.")

	# Attempting second sabotage while active must be rejected
	var dup_check = mgr.can_trigger_sabotage(101, NetworkConfig.PlayerRole.IMPOSTOR, SabotageManager.SabotageType.POWER_BLACKOUT)
	if dup_check.allowed == false and dup_check.reason.contains("already ACTIVE"):
		_log_pass("8. Duplicate sabotage request while ACTIVE is properly rejected.")
	else:
		_log_fail("8. Duplicate activation protection failed.")

func test_server_authoritative_execution_and_rejection() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true
	server.round_manager.transition_to(RoundManager.RoundState.STARTING)
	server.round_manager.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)
	server.round_manager.transition_to(RoundManager.RoundState.PLAYING)
	server.current_game_state = NetworkConfig.GameState.INITIAL_TASK_PHASE

	# Connect 2 players: 1 Crew, 1 Impostor
	var p_crew = PlayerConnectionData.new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	var p_imp = PlayerConnectionData.new(102, 2, true, NetworkConfig.PlayerRole.IMPOSTOR)
	server.connected_players[101] = p_crew
	server.connected_players[102] = p_imp

	var activated_data = {"fired": false}
	server.sabotage_activated_on_server.connect(func(_type, _peer): activated_data["fired"] = true)

	# 1. Crew attempts sabotage -> Server must reject
	var crew_result = server.process_sabotage_request(101, SabotageManager.SabotageType.POWER_BLACKOUT)
	if crew_result.get("success", false) == false and not activated_data["fired"]:
		_log_pass("9. Server authoritatively rejected Crew peer sabotage request.")
	else:
		_log_fail("9. Server accepted Crew sabotage request.")

	if server.current_game_state != NetworkConfig.GameState.BLACKOUT_ACTIVE and not server.blackout_manager.is_blackout_active:
		_log_pass("10. Global blackout did NOT activate on Crew request.")
	else:
		_log_fail("10. Global blackout activated on unauthorized Crew request.")

	# 2. Impostor attempts sabotage -> Server must accept & trigger blackout
	var imp_result = server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	if imp_result.get("success", false) == true and activated_data["fired"]:
		_log_pass("11. Server authoritatively accepted Impostor peer sabotage request.")
	else:
		_log_fail("11. Server rejected valid Impostor sabotage request.")

	if server.sabotage_manager.is_sabotage_active() and server.blackout_manager.is_blackout_active:
		_log_pass("12. Server activated both SabotageManager and BlackoutManager states.")
	else:
		_log_fail("12. Blackout state transition failed.")

	server.free()

func test_sabotage_resolution_hook() -> void:
	var server = ServerNetworkManager.new()
	server.is_running = true
	server.round_manager.transition_to(RoundManager.RoundState.STARTING)
	server.round_manager.transition_to(RoundManager.RoundState.ROLE_ASSIGNMENT)
	server.round_manager.transition_to(RoundManager.RoundState.PLAYING)

	var p_imp = PlayerConnectionData.new(102, 1, true, NetworkConfig.PlayerRole.IMPOSTOR)
	server.connected_players[102] = p_imp

	server.process_sabotage_request(102, SabotageManager.SabotageType.POWER_BLACKOUT)
	if server.sabotage_manager.is_sabotage_active():
		var resolve_result = server.resolve_sabotage("Electrical Junction Restored")
		if resolve_result.get("success", false) == true and not server.sabotage_manager.is_sabotage_active():
			_log_pass("13. resolve_sabotage() cleans up active sabotage and resets state.")
		else:
			_log_fail("13. resolve_sabotage() failed.")
	else:
		_log_fail("13. Sabotage was not active before resolution.")

	server.free()

func test_client_network_synchronization() -> void:
	var client = ClientNetworkManager.new()
	var client_sync_data = {"received": false, "type": 0, "state": 0}

	client.sabotage_state_synced.connect(func(t, s, _d):
		client_sync_data["received"] = true
		client_sync_data["type"] = t
		client_sync_data["state"] = s
	)

	# Simulate server broadcasting sabotage state sync to client
	client.handle_sabotage_state_sync(SabotageManager.SabotageType.POWER_BLACKOUT, SabotageManager.SabotageState.ACTIVE, 25.0)

	if client_sync_data["received"] and client.is_sabotage_active and client_sync_data["type"] == SabotageManager.SabotageType.POWER_BLACKOUT and client_sync_data["state"] == SabotageManager.SabotageState.ACTIVE:
		_log_pass("14. ClientNetworkManager receives and handles authoritative sabotage state sync.")
	else:
		_log_fail("14. Client sabotage synchronization failed.")

	client.free()

func test_player_controller_sabotage_input_isolation() -> void:
	var player_imp = PlayerScene.instantiate() as PlayerController
	player_imp.setup_player(1, "ImpostorPlayer", true)
	player_imp.set_role(NetworkConfig.PlayerRole.IMPOSTOR)

	var player_crew = PlayerScene.instantiate() as PlayerController
	player_crew.setup_player(2, "CrewPlayer", true)
	player_crew.set_role(NetworkConfig.PlayerRole.CREW)

	var imp_data = {"fired": false}
	player_imp.sabotage_triggered.connect(func(_t): imp_data["fired"] = true)

	var imp_triggered = player_imp.try_trigger_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT)
	if imp_triggered and imp_data["fired"]:
		_log_pass("15. Local Impostor PlayerController initiates sabotage request successfully.")
	else:
		_log_fail("15. Impostor sabotage trigger failed.")

	var crew_triggered = player_crew.try_trigger_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT)
	if not crew_triggered:
		_log_pass("16. Local Crew PlayerController rejects sabotage trigger locally.")
	else:
		_log_fail("16. Crew was able to call try_trigger_sabotage().")

	player_imp.free()
	player_crew.free()

func test_hud_role_concealment() -> void:
	var main_scene = load("res://scenes/main.tscn").instantiate()
	main_scene._ready()

	# Crew perspective: should see "POWER FAILURE" when blackout is active, never mentioning Impostor
	main_scene.player.set_role(NetworkConfig.PlayerRole.CREW)
	main_scene._update_sabotage_hud(true)

	var crew_hud_text = main_scene.status_label.text
	if crew_hud_text.contains("POWER FAILURE") and not crew_hud_text.contains("IMPOSTOR") and not crew_hud_text.contains("SABOTAGE"):
		_log_pass("17. Crew HUD displays neutral 'POWER FAILURE' with zero Impostor identity leaks.")
	else:
		_log_fail("17. Crew HUD leaked sabotage/impostor text: '%s'" % crew_hud_text)

	# Impostor perspective: should see "POWER SABOTAGE ACTIVE"
	main_scene.player.set_role(NetworkConfig.PlayerRole.IMPOSTOR)
	main_scene._update_sabotage_hud(true)

	var imp_hud_text = main_scene.status_label.text
	if imp_hud_text.contains("POWER SABOTAGE ACTIVE"):
		_log_pass("18. Impostor HUD displays 'POWER SABOTAGE ACTIVE' confirmation.")
	else:
		_log_fail("18. Impostor HUD mismatch: '%s'" % imp_hud_text)

	main_scene.free()

func test_existing_systems_regression() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.set_role(NetworkConfig.PlayerRole.CREW)

	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door.trigger._on_body_entered(player)
	player.try_interact()
	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("19. DoorController interaction functional.")
	else:
		_log_fail("19. DoorController regression.")

	var junction = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	junction._ready()
	junction.trigger._on_body_entered(player)
	player.try_interact() # Step 1
	if junction.current_step_index == 1 and junction.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("20. 4-step Electrical Junction advances steps normally.")
	else:
		_log_fail("20. Electrical Junction regression.")

	var state_sync = StateSync.new()
	state_sync.register_local_player(player)
	if state_sync.local_player == player:
		_log_pass("21. StateSync registration functional.")
	else:
		_log_fail("21. StateSync regression.")

	player.free()
	door.free()
	junction.free()
	state_sync.free()
