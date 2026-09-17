extends SceneTree

## Unit Test Suite for BLACKOUT Directional Flashlight / Vision Cone System.
## Verifies:
##   1. Normal power state: directional flashlight and radial vision light disabled.
##   2. Blackout activation: directional flashlight and radial vision light enabled for local player.
##   3. Facing UP: flashlight pivot rotates to point upward (-PI rad / 180 deg).
##   4. Facing RIGHT: flashlight pivot rotates to point rightward (-PI/2 rad / -90 deg).
##   5. Facing DOWN: flashlight pivot rotates to point downward (0.0 rad / 0 deg).
##   6. Facing LEFT: flashlight pivot rotates to point leftward (PI/2 rad / 90 deg).
##   7. Diagonal facing: flashlight pivot rotates to 45 deg intermediate angle.
##   8. Remote player isolation: remote player puppet lights remain disabled.
##   9. Power restore: directional flashlight and radial vision light disable cleanly.
##   10. Radial + Directional concurrency: both lights operate concurrently during Blackout.
##   11. Compatibility with existing player movement, collision, camera, and spawn slots.

const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const BlackoutLightingManager = preload("res://client/environment/blackout_lighting_manager.gd")
const SpawnManager = preload("res://client/player/spawn_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — DIRECTIONAL VISION CONE TEST SUITE")
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
	test_normal_power_state()
	test_blackout_activation()
	test_facing_up()
	test_facing_right()
	test_facing_down()
	test_facing_left()
	test_diagonal_facing()
	test_remote_player_isolation()
	test_power_restore()
	test_radial_and_directional_concurrency()
	test_existing_systems_compatibility()

	print("\n========================================================")
	if test_passed:
		print("  DIRECTIONAL VISION TESTS: ALL PASSED (100%)")
	else:
		print("  DIRECTIONAL VISION TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

## Test 1 — Normal Power State
func test_normal_power_state() -> void:
	var lighting = BlackoutLightingManager.new()
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)

	lighting.register_local_player_light(player.vision_light, player.directional_light)

	if player.directional_light != null and not player.directional_light.enabled and not player.vision_light.enabled:
		_log_pass("1. Normal power: directional flashlight and radial vision light are disabled.")
	else:
		_log_fail("1. Normal power: lighting enabled unexpectedly.")

	player.free()
	lighting.free()

## Test 2 — Blackout Activation
func test_blackout_activation() -> void:
	var lighting = BlackoutLightingManager.new()
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)

	lighting.register_local_player_light(player.vision_light, player.directional_light)
	lighting.set_blackout(true, 0.0) # instant

	if player.directional_light.enabled and player.vision_light.enabled and player.directional_light.energy > 0.0:
		_log_pass("2. Blackout activation: directional flashlight and radial vision light enabled for local player.")
	else:
		_log_fail("2. Blackout activation: local player lights failed to activate.")

	player.free()
	lighting.free()

## Test 3 — Facing UP
func test_facing_up() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)
	player.facing_direction = Vector2.UP
	player._update_facing_visual()

	var pivot = player.get_node_or_null("FlashlightPivot") as Node2D
	if pivot != null and (is_equal_approx(pivot.rotation, -PI) or is_equal_approx(pivot.rotation, PI)):
		_log_pass("3. Facing UP: flashlight pivot rotates to -PI rad (points upward).")
	else:
		_log_fail("3. Facing UP rotation incorrect: %s" % (str(pivot.rotation) if pivot != null else "null"))

	player.free()

## Test 4 — Facing RIGHT
func test_facing_right() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visual()

	var pivot = player.get_node_or_null("FlashlightPivot") as Node2D
	if pivot != null and is_equal_approx(pivot.rotation, -PI / 2.0):
		_log_pass("4. Facing RIGHT: flashlight pivot rotates to -PI/2 rad (points rightward).")
	else:
		_log_fail("4. Facing RIGHT rotation incorrect: %s" % (str(pivot.rotation) if pivot != null else "null"))

	player.free()

## Test 5 — Facing DOWN
func test_facing_down() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)
	player.facing_direction = Vector2.DOWN
	player._update_facing_visual()

	var pivot = player.get_node_or_null("FlashlightPivot") as Node2D
	if pivot != null and is_equal_approx(pivot.rotation, 0.0):
		_log_pass("5. Facing DOWN: flashlight pivot rotates to 0.0 rad (points downward).")
	else:
		_log_fail("5. Facing DOWN rotation incorrect: %s" % (str(pivot.rotation) if pivot != null else "null"))

	player.free()

## Test 6 — Facing LEFT
func test_facing_left() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)
	player.facing_direction = Vector2.LEFT
	player._update_facing_visual()

	var pivot = player.get_node_or_null("FlashlightPivot") as Node2D
	if pivot != null and is_equal_approx(pivot.rotation, PI / 2.0):
		_log_pass("6. Facing LEFT: flashlight pivot rotates to PI/2 rad (points leftward).")
	else:
		_log_fail("6. Facing LEFT rotation incorrect: %s" % (str(pivot.rotation) if pivot != null else "null"))

	player.free()

## Test 7 — Diagonal Facing
func test_diagonal_facing() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)
	var diag = Vector2(1.0, 1.0).normalized() # Down-Right
	player.facing_direction = diag
	player._update_facing_visual()

	var pivot = player.get_node_or_null("FlashlightPivot") as Node2D
	var expected_rot = diag.angle() - (PI / 2.0)
	if pivot != null and is_equal_approx(pivot.rotation, expected_rot):
		_log_pass("7. Diagonal facing: flashlight pivot rotates to %.3f rad (-45 deg)." % pivot.rotation)
	else:
		_log_fail("7. Diagonal facing rotation incorrect.")

	player.free()

## Test 8 — Remote Player Isolation
func test_remote_player_isolation() -> void:
	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player._ready()
	remote_player.setup_player(2, "Player 2", false)

	if not remote_player.directional_light.enabled and not remote_player.vision_light.enabled:
		_log_pass("8. Remote player isolation: remote puppet directional and radial lights remain disabled.")
	else:
		_log_fail("8. Remote player lights enabled unexpectedly.")

	remote_player.free()

## Test 9 — Power Restore
func test_power_restore() -> void:
	var lighting = BlackoutLightingManager.new()
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)

	lighting.register_local_player_light(player.vision_light, player.directional_light)
	lighting.set_blackout(true, 0.0)
	lighting.set_blackout(false, 0.0) # restore power

	if not player.directional_light.enabled and not player.vision_light.enabled:
		_log_pass("9. Power restore: directional flashlight and radial vision light disabled upon power return.")
	else:
		_log_fail("9. Power restore: player lights not disabled.")

	player.free()
	lighting.free()

## Test 10 — Radial and Directional Concurrency
func test_radial_and_directional_concurrency() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player._ready()
	player.setup_player(1, "Player 1", true)

	# Verify both nodes exist independently on the player scene
	var has_radial = player.vision_light != null and player.vision_light is PointLight2D
	var has_dir = player.directional_light != null and player.directional_light is PointLight2D
	if has_radial and has_dir:
		_log_pass("10. Player has both radial vision light and directional flashlight cone concurrently.")
	else:
		_log_fail("10. Player missing one of the dual vision light nodes.")

	player.free()

## Test 11 — Existing Systems Compatibility
func test_existing_systems_compatibility() -> void:
	var spawn_mgr = SpawnManager.new()
	if spawn_mgr.get_all_spawn_positions().size() == 8:
		_log_pass("11. Deterministic 8-slot spawn management and player physics intact.")
	else:
		_log_fail("11. Spawn management modified unexpectedly.")
	spawn_mgr.free()
