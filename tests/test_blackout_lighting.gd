extends SceneTree

## Unit Test Suite for BLACKOUT Dynamic Blackout Vision & Lighting Engine (FR-12).
## Verifies:
##   1. BlackoutLightingManager instantiates with CanvasModulate node.
##   2. Normal power state maintains 100% ambient brightness (Color(1,1,1,1)).
##   3. Local player vision light registration (PointLight2D).
##   4. set_blackout(true) dims CanvasModulate to dark ambient and enables vision light.
##   5. set_blackout(false) restores normal bright ambient and disables vision light.
##   6. toggle_blackout() operates idempotently and toggles state smoothly.
##   7. Remote puppet players (is_local_player = false) do not emit local vision light.
##   8. ClientNetworkManager signal bindings (blackout_started, blackout_ended) trigger state transitions.

const BlackoutLightingManager = preload("res://client/environment/blackout_lighting_manager.gd")
const BlackoutLightingScene = preload("res://scenes/environment/blackout_lighting.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — DYNAMIC VISION & LIGHTING TEST (FR-12)")
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
	test_manager_instantiation()
	test_normal_power_state()
	test_blackout_state_transition()
	test_power_restore_transition()
	test_toggle_blackout()
	test_multiplayer_remote_light_isolation()
	test_network_signal_integration()

	print("\n========================================================")
	if test_passed:
		print("  BLACKOUT VISION & LIGHTING TESTS: ALL PASSED (100%)")
	else:
		print("  BLACKOUT VISION & LIGHTING TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_manager_instantiation() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	if lm != null and lm.canvas_modulate != null:
		_log_pass("1. BlackoutLightingManager instantiates with active CanvasModulate node.")
	else:
		_log_fail("1. Lighting manager instantiation failed.")
	lm.free()

func test_normal_power_state() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	if lm.is_blackout_active() == false and lm.canvas_modulate.color == Color(1.0, 1.0, 1.0, 1.0):
		_log_pass("2. Initial POWER_ON state maintains 100% ambient brightness (Color(1,1,1,1)).")
	else:
		_log_fail("2. Normal ambient color unexpected: %s" % str(lm.canvas_modulate.color))
	lm.free()

func test_blackout_state_transition() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.is_local_player = true
	lm.register_local_player_light(player.vision_light)

	var signal_received = false
	lm.blackout_state_changed.connect(func(active): signal_received = active)

	lm._apply_instant_state(true)
	if lm.is_blackout_active() == true and lm.canvas_modulate.color == BlackoutLightingManager.BLACKOUT_AMBIENT:
		_log_pass("3. Blackout activation dims CanvasModulate to emergency ambient darkness (0.06, 0.08, 0.12).")
	else:
		_log_fail("3. Blackout ambient color mismatch.")

	if player.vision_light != null and player.vision_light.enabled == true and player.vision_light.energy > 1.0:
		_log_pass("4. Local player vision light activates with target energy (1.25).")
	else:
		_log_fail("4. Local player vision light not activated during blackout.")

	player.free()
	lm.free()

func test_power_restore_transition() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.is_local_player = true
	lm.register_local_player_light(player.vision_light)

	lm._apply_instant_state(true)
	lm._apply_instant_state(false)

	if lm.is_blackout_active() == false and lm.canvas_modulate.color == BlackoutLightingManager.NORMAL_AMBIENT:
		_log_pass("5. Restoring power returns CanvasModulate to normal brightness.")
	else:
		_log_fail("5. Power restore ambient mismatch.")

	if player.vision_light != null and (player.vision_light.enabled == false or player.vision_light.energy == 0.0):
		_log_pass("6. Power restore cleanly deactivates player vision light.")
	else:
		_log_fail("6. Vision light still active after power restore.")

	player.free()
	lm.free()

func test_toggle_blackout() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	var state1 = lm.toggle_blackout()
	if state1 == true and lm.is_blackout_active() == true:
		_log_pass("7. toggle_blackout() switches from POWER_ON to BLACKOUT.")
	else:
		_log_fail("7. First toggle failed.")

	var state2 = lm.toggle_blackout()
	if state2 == false and lm.is_blackout_active() == false:
		_log_pass("8. toggle_blackout() switches back from BLACKOUT to POWER_ON.")
	else:
		_log_fail("8. Second toggle failed.")
	lm.free()

func test_multiplayer_remote_light_isolation() -> void:
	var player_remote = PlayerScene.instantiate() as PlayerController
	player_remote._ready()
	player_remote.setup_player(2, "Remote Player", false) # Remote puppet

	if player_remote.vision_light != null and player_remote.vision_light.enabled == false:
		_log_pass("9. Remote puppet player vision light is disabled by default.")
	else:
		_log_fail("9. Remote player vision light active.")
	player_remote.free()

func test_network_signal_integration() -> void:
	var lm = BlackoutLightingScene.instantiate() as BlackoutLightingManager
	lm._ready()

	lm._on_server_blackout_started(15.0)
	if lm.is_blackout_active() == true:
		_log_pass("10. Authoritative server blackout_started signal triggers Blackout mode.")
	else:
		_log_fail("10. Server blackout trigger failed.")

	lm._on_server_blackout_ended()
	if lm.is_blackout_active() == false:
		_log_pass("11. Authoritative server blackout_ended signal restores power.")
	else:
		_log_fail("11. Server power restore failed.")
	lm.free()
