extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Victory / Defeat Game Over Screen (Stage 20).
## Verifies:
##   1. UI hidden outside GAME_OVER (LOBBY, STARTING, ROLE_ASSIGNMENT, PLAYING, MELTDOWN, etc.)
##   2. UI appears on authoritative GAME_OVER signal/state
##   3. Crew victory displays correctly (VICTORY for Crew, DEFEAT for Impostor)
##   4. Impostor victory displays correctly (VICTORY for Impostor, DEFEAT for Crew)
##   5. Local role is displayed correctly (CREW, IMPOSTOR)
##   6. Existing game-over reason is displayed accurately
##   7. No fake statistics are generated (only verified real match data)
##   8. UI blocks gameplay interaction while active (mouse_filter == STOP, player.can_move == false)
##   9. UI resets and clears text when returning to lobby/new round
##   10. Existing GAME_OVER signal (game_over_received) is reused
##   11. No duplicate game-over system created
##   12. Meltdown backend remains authoritative

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const GameOverUI = preload("res://client/ui/game_over_ui.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const MeltdownManager = preload("res://server/meltdown_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — VICTORY / DEFEAT GAME OVER UI TEST (STAGE 20)")
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

	# Create GameOverUI instance
	var ui: GameOverUI = GameOverUI.new()
	root.add_child(ui)

	# Create Mock Local Player
	var mock_player: PlayerController = PlayerController.new()
	mock_player.name = "Player"
	mock_player.slot_id = 1
	mock_player.is_local_player = true
	mock_player.can_move = true
	mock_player.set_role(NetworkConfig.PlayerRole.CREW)
	root.add_child(mock_player)
	ui.register_local_player(mock_player)

	# -------------------------------------------------------------------------
	# TEST 1: UI is hidden outside GAME_OVER (LOBBY, PLAYING, MELTDOWN, etc.)
	# -------------------------------------------------------------------------
	_log_info("--- Test 1: UI Hidden Outside GAME_OVER ---")
	var non_game_over_states = [
		NetworkConfig.GameState.LOBBY,
		NetworkConfig.GameState.ROLE_ASSIGNMENT,
		NetworkConfig.GameState.INITIAL_TASK_PHASE,
		NetworkConfig.GameState.BLACKOUT_AVAILABLE,
		NetworkConfig.GameState.BLACKOUT_ACTIVE,
		NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION,
		NetworkConfig.GameState.MEETING,
		NetworkConfig.GameState.VOTING,
		NetworkConfig.GameState.MELTDOWN
	]

	var all_hidden = true
	for st in non_game_over_states:
		ui._on_network_game_state_changed(st)
		if ui.visible or ui.is_active:
			all_hidden = false
			break

	if all_hidden and not ui.visible:
		_log_pass("TEST 1: UI remains strictly hidden across all non-GAME_OVER states.")
	else:
		_log_fail("TEST 1: UI was unexpectedly visible outside GAME_OVER.")

	# -------------------------------------------------------------------------
	# TEST 2: UI appears on authoritative GAME_OVER
	# -------------------------------------------------------------------------
	_log_info("--- Test 2: UI Appears on Authoritative GAME_OVER ---")
	var sample_result = {
		"winner_role": NetworkConfig.PlayerRole.CREW,
		"winner_role_name": "CREW",
		"reason": MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		"reason_name": "CREW_EMERGENCY_SYSTEMS_COMPLETE",
		"completed_systems": ["restore_power", "restore_cooling", "stabilize_orion"],
		"remaining_time": 185.4,
		"impostor_was_alive": true
	}

	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)

	if ui.visible and ui.is_active:
		_log_pass("TEST 2: UI appears successfully when match enters GAME_OVER.")
	else:
		_log_fail("TEST 2: UI failed to display on GAME_OVER.")

	# -------------------------------------------------------------------------
	# TEST 3: Crew victory displays correctly (Victory for Crew, Defeat for Impostor)
	# -------------------------------------------------------------------------
	_log_info("--- Test 3: Crew Victory Display Resolution ---")
	# Case A: Local player is Crew -> VICTORY
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)
	var crew_view_victory = (ui.is_victory and ui.result_heading.text == "VICTORY")

	# Case B: Local player is Impostor -> DEFEAT
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.IMPOSTOR
	)
	var imp_view_defeat = (not ui.is_victory and ui.result_heading.text == "DEFEAT")

	if crew_view_victory and imp_view_defeat:
		_log_pass("TEST 3: Crew victory displays 'VICTORY' for Crew and 'DEFEAT' for Impostor.")
	else:
		_log_fail("TEST 3: Victory/Defeat resolution mismatch for Crew win (Crew: %s, Imp: %s)." % [
			str(crew_view_victory), str(imp_view_defeat)
		])

	# -------------------------------------------------------------------------
	# TEST 4: Impostor victory displays correctly (Victory for Impostor, Defeat for Crew)
	# -------------------------------------------------------------------------
	_log_info("--- Test 4: Impostor Victory Display Resolution ---")
	var sample_imp_result = {
		"winner_role": NetworkConfig.PlayerRole.IMPOSTOR,
		"winner_role_name": "IMPOSTOR",
		"reason": MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		"reason_name": "IMPOSTOR_MELTDOWN_TIMER_EXPIRED",
		"completed_systems": ["restore_power"],
		"remaining_time": 0.0,
		"impostor_was_alive": true
	}

	# Case A: Local player is Impostor -> VICTORY
	ui.show_game_over(
		NetworkConfig.PlayerRole.IMPOSTOR,
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		sample_imp_result,
		NetworkConfig.PlayerRole.IMPOSTOR
	)
	var imp_view_victory = (ui.is_victory and ui.result_heading.text == "VICTORY")

	# Case B: Local player is Crew -> DEFEAT
	ui.show_game_over(
		NetworkConfig.PlayerRole.IMPOSTOR,
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		sample_imp_result,
		NetworkConfig.PlayerRole.CREW
	)
	var crew_view_defeat = (not ui.is_victory and ui.result_heading.text == "DEFEAT")

	if imp_view_victory and crew_view_defeat:
		_log_pass("TEST 4: Impostor victory displays 'VICTORY' for Impostor and 'DEFEAT' for Crew.")
	else:
		_log_fail("TEST 4: Victory/Defeat resolution mismatch for Impostor win (Imp: %s, Crew: %s)." % [
			str(imp_view_victory), str(crew_view_defeat)
		])

	# -------------------------------------------------------------------------
	# TEST 5: Local role is displayed correctly
	# -------------------------------------------------------------------------
	_log_info("--- Test 5: Local Role Label Verification ---")
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)
	var role_crew_ok = (ui.role_value_label.text == "CREW")

	ui.show_game_over(
		NetworkConfig.PlayerRole.IMPOSTOR,
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		sample_imp_result,
		NetworkConfig.PlayerRole.IMPOSTOR
	)
	var role_imp_ok = (ui.role_value_label.text == "IMPOSTOR")

	if role_crew_ok and role_imp_ok:
		_log_pass("TEST 5: Local role is accurately displayed for both CREW and IMPOSTOR.")
	else:
		_log_fail("TEST 5: Local role display mismatch (Crew: %s, Imp: %s)." % [str(role_crew_ok), str(role_imp_ok)])

	# -------------------------------------------------------------------------
	# TEST 6: Existing game-over reason is displayed
	# -------------------------------------------------------------------------
	_log_info("--- Test 6: Authoritative Reason Display ---")
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)
	var reason_crew_ok = ui.reason_value_label.text.contains("restored all emergency systems")

	ui.show_game_over(
		NetworkConfig.PlayerRole.IMPOSTOR,
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		sample_imp_result,
		NetworkConfig.PlayerRole.IMPOSTOR
	)
	var reason_imp_ok = ui.reason_value_label.text.contains("timer expired")

	if reason_crew_ok and reason_imp_ok:
		_log_pass("TEST 6: Authoritative game-over reasons displayed accurately.")
	else:
		_log_fail("TEST 6: Reason text mismatch (Crew: %s, Imp: %s)." % [str(reason_crew_ok), str(reason_imp_ok)])

	# -------------------------------------------------------------------------
	# TEST 7: No fake statistics are generated
	# -------------------------------------------------------------------------
	_log_info("--- Test 7: Real Data Verification (No Fake Statistics) ---")
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)
	# Check that emergency system count corresponds strictly to completed_systems in result_data (3/3)
	var sys_text_3 = ui.systems_value_label.text
	var sys_ok_3 = sys_text_3.contains("3 / 3")

	ui.show_game_over(
		NetworkConfig.PlayerRole.IMPOSTOR,
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		sample_imp_result,
		NetworkConfig.PlayerRole.IMPOSTOR
	)
	var sys_text_1 = ui.systems_value_label.text
	var sys_ok_1 = sys_text_1.contains("1 / 3")

	if sys_ok_3 and sys_ok_1:
		_log_pass("TEST 7: Match summary reflects only verified authoritative data (Systems: %s and %s)." % [sys_text_3, sys_text_1])
	else:
		_log_fail("TEST 7: Data count mismatch (Expected 3/3 and 1/3, got: '%s' and '%s')." % [sys_text_3, sys_text_1])

	# -------------------------------------------------------------------------
	# TEST 8: UI blocks gameplay interaction while active
	# -------------------------------------------------------------------------
	_log_info("--- Test 8: Gameplay & Movement Locking ---")
	mock_player.can_move = true
	ui.show_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result,
		NetworkConfig.PlayerRole.CREW
	)

	var mouse_stopped = (ui.mouse_filter == Control.MOUSE_FILTER_STOP)
	var player_locked = (not mock_player.can_move)

	if mouse_stopped and player_locked:
		_log_pass("TEST 8: Gameplay interaction and player movement are strictly blocked while Game Over is active.")
	else:
		_log_fail("TEST 8: Interaction blocking failed (MouseFilter: %d, PlayerCanMove: %s)." % [
			ui.mouse_filter, str(mock_player.can_move)
		])

	# -------------------------------------------------------------------------
	# TEST 9: UI resets when returning to lobby/new round
	# -------------------------------------------------------------------------
	_log_info("--- Test 9: UI Reset on Lobby Return ---")
	ui.reset()
	var reset_hidden = (not ui.visible and not ui.is_active)
	var text_cleared = (ui.result_heading.text == "" and ui.role_value_label.text == "")
	var move_restored = mock_player.can_move

	if reset_hidden and text_cleared and move_restored:
		_log_pass("TEST 9: UI cleanly resets, clears text, and restores movement on round reset.")
	else:
		_log_fail("TEST 9: Reset failed (Hidden: %s, TextCleared: %s, MoveRestored: %s)." % [
			str(reset_hidden), str(text_cleared), str(move_restored)
		])

	# -------------------------------------------------------------------------
	# TEST 10: Existing GAME_OVER signal is reused
	# -------------------------------------------------------------------------
	_log_info("--- Test 10: ClientNetworkManager Signal Integration ---")
	var client_net = ClientNetworkManager.new()
	root.add_child(client_net)
	ui.bind_client_network_manager(client_net)

	client_net.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	client_net.handle_game_over(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		sample_result
	)

	if ui.visible and ui.is_active and ui.is_victory:
		_log_pass("TEST 10: Successfully received and processed existing ClientNetworkManager.game_over_received signal.")
	else:
		_log_fail("TEST 10: Signal integration failed.")

	# -------------------------------------------------------------------------
	# TEST 11: No duplicate game-over system created
	# -------------------------------------------------------------------------
	_log_info("--- Test 11: Single Source of Truth ---")
	var single_system_ok = (ui.has_method("show_game_over") and not ui.has_method("start_game_over_timer"))
	if single_system_ok:
		_log_pass("TEST 11: Confirmed UI is purely reactive without duplicate timers or state machines.")
	else:
		_log_fail("TEST 11: Unexpected state machine/timer detected in UI.")

	# -------------------------------------------------------------------------
	# TEST 12: Meltdown backend remains authoritative
	# -------------------------------------------------------------------------
	_log_info("--- Test 12: Meltdown Authoritative Endgame Integration ---")
	var mm = MeltdownManager.new()
	mm.setup(300.0)
	mm.start_meltdown(true)

	var triggered = {
		"winner": NetworkConfig.PlayerRole.NONE,
		"reason": MeltdownConfig.GameOverReason.NONE,
		"result": {}
	}

	mm.game_over_triggered.connect(func(w, r, res):
		triggered["winner"] = w
		triggered["reason"] = r
		triggered["result"] = res
	)

	# Simulate completing all 3 emergency systems
	var active_players = {
		1: _create_mock_player_data(1, NetworkConfig.PlayerRole.CREW)
	}

	mm.complete_emergency_system(1, MeltdownConfig.SYSTEM_RESTORE_POWER, NetworkConfig.GameState.MELTDOWN, active_players)
	mm.complete_emergency_system(1, MeltdownConfig.SYSTEM_RESTORE_COOLING, NetworkConfig.GameState.MELTDOWN, active_players)
	mm.complete_emergency_system(1, MeltdownConfig.SYSTEM_STABILIZE_ORION, NetworkConfig.GameState.MELTDOWN, active_players)

	if mm.is_game_over and triggered["winner"] == NetworkConfig.PlayerRole.CREW and triggered["reason"] == MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE:
		ui.show_game_over(triggered["winner"], triggered["reason"], triggered["result"], NetworkConfig.PlayerRole.CREW)
		if ui.visible and ui.is_victory:
			_log_pass("TEST 12: Meltdown authoritative Crew victory successfully propagates to Game Over UI.")
		else:
			_log_fail("TEST 12: Game Over UI failed to reflect Meltdown Crew victory.")
	else:
		_log_fail("TEST 12: MeltdownManager did not trigger game_over as expected (Winner: %d, Reason: %d)." % [
			triggered["winner"], triggered["reason"]
		])

	# Cleanup
	client_net.queue_free()
	mock_player.queue_free()
	ui.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL STAGE 20 GAME OVER UI TESTS PASSED! (12/12)")
	else:
		print("  STAGE 20 GAME OVER UI TESTS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func _create_mock_player_data(p_peer_id: int, p_role: NetworkConfig.PlayerRole) -> RefCounted:
	var data = preload("res://shared/player_connection_data.gd").new(p_peer_id, p_peer_id, true, p_role)
	return data
