extends SceneTree

## Unit Test Suite for WinConditionManager (Member 2 Deliverable).

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const PlayerConnectionData = preload("res://shared/player_connection_data.gd")
const WinConditionManager = preload("res://server/win_condition_manager.gd")

var test_passed: bool = true

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — WIN CONDITION MANAGER TEST (MEMBER 2)")
	print("========================================================\n")
	_run_tests()
	print("\n========================================================")
	if test_passed:
		print("  ALL WIN CONDITION MANAGER TESTS PASSED!")
	else:
		print("  WIN CONDITION MANAGER TESTS FAILED!")
	print("========================================================\n")
	quit(0 if test_passed else 1)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_passed = false

func _run_tests() -> void:
	var wcm = WinConditionManager.new()

	# Test 1: Incomplete systems do not trigger Crew victory
	var partial_systems = ["restore_power", "restore_cooling"]
	if not wcm.check_crew_victory(partial_systems):
		_log_pass("Test 1: Partial emergency systems (2/3) correctly reject Crew victory.")
	else:
		_log_fail("Test 1: Partial systems incorrectly triggered Crew victory.")

	# Test 2: All 3 mandatory systems trigger Crew victory
	var all_systems = ["restore_power", "restore_cooling", "stabilize_orion"]
	if wcm.check_crew_victory(all_systems):
		_log_pass("Test 2: All 3 mandatory emergency systems correctly trigger Crew victory.")
	else:
		_log_fail("Test 2: Complete systems failed to trigger Crew victory.")

	# Test 3: Meltdown timer > 0 does not trigger Impostor victory
	if not wcm.check_impostor_victory(15.5):
		_log_pass("Test 3: Remaining Meltdown time (15.5s) correctly rejects Impostor victory.")
	else:
		_log_fail("Test 3: Non-zero time incorrectly triggered Impostor victory.")

	# Test 4: Meltdown timer <= 0 triggers Impostor victory
	if wcm.check_impostor_victory(0.0) and wcm.check_impostor_victory(-0.5):
		_log_pass("Test 4: Expired Meltdown timer (<= 0.0s) correctly triggers Impostor victory.")
	else:
		_log_fail("Test 4: Expired timer failed to trigger Impostor victory.")

	# Test 5: Assemble match summary with player roster
	var test_players: Dictionary = {}
	var p1 = PlayerConnectionData.new(1, 1)
	p1.role = NetworkConfig.PlayerRole.CREW
	p1.is_alive = true
	test_players[1] = p1

	var p2 = PlayerConnectionData.new(2, 2)
	p2.role = NetworkConfig.PlayerRole.IMPOSTOR
	p2.is_alive = false
	p2.is_eliminated = true
	test_players[2] = p2

	var summary = wcm.assemble_match_summary(
		NetworkConfig.PlayerRole.CREW,
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		all_systems,
		142.5,
		false,
		test_players
	)

	if summary.winner_role == NetworkConfig.PlayerRole.CREW and summary.player_roster.size() == 2:
		_log_pass("Test 5: Match summary assembled correctly with complete player roster.")
	else:
		_log_fail("Test 5: Match summary assembly failed.")

	# Test 6: Clear resets state
	wcm.clear()
	if not wcm.is_match_concluded and wcm.winner == NetworkConfig.PlayerRole.NONE:
		_log_pass("Test 6: State successfully cleared on reset.")
	else:
		_log_fail("Test 6: State clear failed.")
