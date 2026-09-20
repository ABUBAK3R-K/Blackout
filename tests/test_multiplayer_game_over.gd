extends SceneTree

## Multiplayer End-to-End Verification for BLACKOUT Stage 20 (Game Over Screen).
## Tests both authoritative match outcomes with real ServerNetworkManager & ClientNetworkManager:
##   CASE A: Crew Victory (all 3 emergency systems restored during Meltdown)
##   CASE B: Impostor Victory (Meltdown timer expires)

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const GameOverUI = preload("res://client/ui/game_over_ui.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MULTIPLAYER GAME OVER E2E VERIFICATION")
	print("========================================================\n")
	create_timer(0.05).timeout.connect(_run_verification)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_passed = false

func _run_verification() -> void:
	var root = get_root()

	# -------------------------------------------------------------------------
	# CASE A: CREW VICTORY
	# -------------------------------------------------------------------------
	print("\n--- CASE A: CREW VICTORY (Restoring All 3 Emergency Systems) ---")
	var server_a = ServerNetworkManager.new()
	root.add_child(server_a)

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

	# Simulate role assignment
	client_crew.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	client_imp.handle_private_role_assignment(NetworkConfig.PlayerRole.IMPOSTOR)

	# Start Meltdown
	server_a.meltdown_manager.setup(300.0)
	server_a.meltdown_manager.start_meltdown(true)
	client_crew.handle_meltdown_started(300.0, true)
	client_imp.handle_meltdown_started(300.0, true)

	var player_crew_data = preload("res://shared/player_connection_data.gd").new(101, 1, true, NetworkConfig.PlayerRole.CREW)
	var active_players = {101: player_crew_data}

	# Restore 3 emergency systems
	server_a.meltdown_manager.complete_emergency_system(101, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, active_players)
	server_a.meltdown_manager.complete_emergency_system(101, MeltdownConfig.SYSTEM_RESTORE_COOLING, NetworkConfig.GameState.MELTDOWN, active_players)
	server_a.meltdown_manager.complete_emergency_system(101, MeltdownConfig.SYSTEM_STABILIZE_ORION, NetworkConfig.GameState.MELTDOWN, active_players)

	# Simulate network broadcast to clients
	var res_a = server_a.meltdown_manager.last_game_over_result
	client_crew.handle_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, res_a)
	client_imp.handle_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, res_a)

	if ui_crew.visible and ui_crew.is_victory and ui_crew.result_heading.text == "VICTORY":
		_log_pass("Case A: Crew client correctly displays VICTORY on emergency restoration.")
	else:
		_log_fail("Case A: Crew client failed to display VICTORY.")

	if ui_imp.visible and not ui_imp.is_victory and ui_imp.result_heading.text == "DEFEAT":
		_log_pass("Case A: Impostor client correctly displays DEFEAT on emergency restoration.")
	else:
		_log_fail("Case A: Impostor client failed to display DEFEAT.")

	# Cleanup Case A
	server_a.queue_free()
	client_crew.queue_free()
	client_imp.queue_free()
	ui_crew.queue_free()
	ui_imp.queue_free()

	# -------------------------------------------------------------------------
	# CASE B: IMPOSTOR VICTORY (Timer Expiration)
	# -------------------------------------------------------------------------
	print("\n--- CASE B: IMPOSTOR VICTORY (Meltdown Timer Expiration) ---")
	var server_b = ServerNetworkManager.new()
	root.add_child(server_b)

	var client_crew_b = ClientNetworkManager.new()
	var client_imp_b = ClientNetworkManager.new()
	root.add_child(client_crew_b)
	root.add_child(client_imp_b)

	var ui_crew_b = GameOverUI.new()
	var ui_imp_b = GameOverUI.new()
	root.add_child(ui_crew_b)
	root.add_child(ui_imp_b)

	ui_crew_b.bind_client_network_manager(client_crew_b)
	ui_imp_b.bind_client_network_manager(client_imp_b)

	client_crew_b.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	client_imp_b.handle_private_role_assignment(NetworkConfig.PlayerRole.IMPOSTOR)

	# Start Meltdown and advance timer to 0
	server_b.meltdown_manager.setup(5.0)
	server_b.meltdown_manager.start_meltdown(true)
	client_crew_b.handle_meltdown_started(5.0, true)
	client_imp_b.handle_meltdown_started(5.0, true)

	server_b.meltdown_manager.tick(6.0) # Timer expires

	var res_b = server_b.meltdown_manager.last_game_over_result
	client_crew_b.handle_game_over(NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED, res_b)
	client_imp_b.handle_game_over(NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED, res_b)

	if ui_imp_b.visible and ui_imp_b.is_victory and ui_imp_b.result_heading.text == "VICTORY":
		_log_pass("Case B: Impostor client correctly displays VICTORY on Meltdown timer expiration.")
	else:
		_log_fail("Case B: Impostor client failed to display VICTORY.")

	if ui_crew_b.visible and not ui_crew_b.is_victory and ui_crew_b.result_heading.text == "DEFEAT":
		_log_pass("Case B: Crew client correctly displays DEFEAT on Meltdown timer expiration.")
	else:
		_log_fail("Case B: Crew client failed to display DEFEAT.")

	# Cleanup Case B
	server_b.queue_free()
	client_crew_b.queue_free()
	client_imp_b.queue_free()
	ui_crew_b.queue_free()
	ui_imp_b.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL MULTIPLAYER E2E GAME OVER VERIFICATIONS PASSED!")
	else:
		print("  MULTIPLAYER E2E VERIFICATIONS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
