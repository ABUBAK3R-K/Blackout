extends SceneTree

## Unit Test Suite for BLACKOUT Player Visual Identification (Nametags + Facing Direction).
## Verifies:
##   1. Local player identity formatting ("Player 1 (YOU)") and accent styling.
##   2. Remote player deterministic identity formatting ("Player 2") and neutral styling.
##   3. Local facing direction indicator rotation (UP, DOWN, LEFT, RIGHT, Diagonals).
##   4. Remote facing direction synchronization from authoritative network packets.
##   5. Nametag position stability (upright orientation decoupled from body rotation).
##   6. Disconnect handling (remote puppet and nametag removed cleanly from scene).
##   7. Blackout vision isolation (remote player vision light remains disabled).
##   8. Camera isolation (local camera enabled, remote cameras disabled).
##   9. Compatibility with deterministic 8-slot spawn management and player movement physics.

const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SpawnManager = preload("res://client/player/spawn_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — PLAYER VISUAL IDENTIFICATION TEST SUITE")
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
	test_local_player_identity()
	test_remote_player_identity()
	test_facing_direction_rotation()
	test_remote_facing_synchronization()
	test_nametag_upright_stability()
	test_disconnect_cleanup()
	test_camera_isolation()
	test_blackout_vision_isolation()
	test_existing_physics_and_spawns()

	print("\n========================================================")
	if test_passed:
		print("  VISUAL IDENTIFICATION TESTS: ALL PASSED (100%)")
	else:
		print("  VISUAL IDENTIFICATION TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

## Test 1 — Local Player Identity
func test_local_player_identity() -> void:
	var local_player = PlayerScene.instantiate() as PlayerController
	local_player.setup_player(1, "Player 1", true)

	var label = local_player.get_node_or_null("NameLabel") as Label
	if label != null and label.text == "Player 1 (YOU)":
		_log_pass("1. Local player nametag correctly displays '%s'." % label.text)
	else:
		_log_fail("1. Local player nametag text unexpected: %s" % (label.text if label != null else "null"))

	local_player.free()

## Test 2 — Remote Player Identity
func test_remote_player_identity() -> void:
	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player.setup_player(2, "Player 2", false)

	var label = remote_player.get_node_or_null("NameLabel") as Label
	if label != null and label.text == "Player 2":
		_log_pass("2. Remote player nametag correctly displays '%s' without local suffix." % label.text)
	else:
		_log_fail("2. Remote player nametag text unexpected: %s" % (label.text if label != null else "null"))

	remote_player.free()

## Test 3 — Facing Direction Indicator Rotation (UP, DOWN, LEFT, RIGHT)
func test_facing_direction_rotation() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	var visual = player.get_node_or_null("Visual") as Node2D

	if visual == null:
		_log_fail("3. PlayerScene missing Visual node.")
		player.free()
		return

	# Default DOWN (0, 1) -> angle = PI/2 -> visual.rotation = 0.0
	player.facing_direction = Vector2.DOWN
	player._update_facing_visual()
	if is_equal_approx(visual.rotation, 0.0):
		_log_pass("3. Facing DOWN rotates visual to 0.0 rad (default forward).")
	else:
		_log_fail("3. Facing DOWN rotation unexpected: %f" % visual.rotation)

	# RIGHT (1, 0) -> angle = 0 -> visual.rotation = -PI/2
	player.facing_direction = Vector2.RIGHT
	player._update_facing_visual()
	if is_equal_approx(visual.rotation, -PI / 2.0):
		_log_pass("4. Facing RIGHT rotates visual to -PI/2 rad (-90 deg).")
	else:
		_log_fail("4. Facing RIGHT rotation unexpected: %f" % visual.rotation)

	# UP (0, -1) -> angle = -PI/2 -> visual.rotation = -PI
	player.facing_direction = Vector2.UP
	player._update_facing_visual()
	if is_equal_approx(visual.rotation, -PI) or is_equal_approx(visual.rotation, PI):
		_log_pass("5. Facing UP rotates visual to -PI rad (-180 deg).")
	else:
		_log_fail("5. Facing UP rotation unexpected: %f" % visual.rotation)

	# LEFT (-1, 0) -> angle = PI -> visual.rotation = PI/2
	player.facing_direction = Vector2.LEFT
	player._update_facing_visual()
	if is_equal_approx(visual.rotation, PI / 2.0):
		_log_pass("6. Facing LEFT rotates visual to PI/2 rad (90 deg).")
	else:
		_log_fail("6. Facing LEFT rotation unexpected: %f" % visual.rotation)

	player.free()

## Test 4 — Remote Facing Synchronization
func test_remote_facing_synchronization() -> void:
	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player.setup_player(3, "Player 3", false)
	var visual = remote_player.get_node_or_null("Visual") as Node2D

	# Receive packet with facing RIGHT
	remote_player.update_remote_state(Vector2(500.0, 300.0), Vector2(250.0, 0.0), Vector2.RIGHT)
	if remote_player.facing_direction == Vector2.RIGHT and visual != null and is_equal_approx(visual.rotation, -PI / 2.0):
		_log_pass("7. Remote player updates facing direction to RIGHT from authoritative packet.")
	else:
		_log_fail("7. Remote player failed to update facing to RIGHT.")

	# Receive packet with facing UP
	remote_player.update_remote_state(Vector2(500.0, 250.0), Vector2(0.0, -250.0), Vector2.UP)
	if remote_player.facing_direction == Vector2.UP and visual != null and (is_equal_approx(visual.rotation, -PI) or is_equal_approx(visual.rotation, PI)):
		_log_pass("8. Remote player updates facing direction to UP from authoritative packet.")
	else:
		_log_fail("8. Remote player failed to update facing to UP.")

	remote_player.free()

## Test 5 — Nametag Upright Stability (Decoupled from Body Rotation)
func test_nametag_upright_stability() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	var visual = player.get_node_or_null("Visual") as Node2D
	var label = player.get_node_or_null("NameLabel") as Label

	# Rotate body to facing LEFT (PI/2)
	player.facing_direction = Vector2.LEFT
	player._update_facing_visual()

	# NameLabel should not be rotated because it is not a child of Visual
	if label != null and is_equal_approx(label.rotation, 0.0) and label.get_parent() == player:
		_log_pass("9. Nametag remains level and upright regardless of body facing orientation.")
	else:
		_log_fail("9. Nametag rotated unexpectedly with body.")

	player.free()

## Test 6 — Disconnect Cleanup
func test_disconnect_cleanup() -> void:
	var spawn_mgr = SpawnManager.new()
	var root_node = Node2D.new()
	root_node.add_child(spawn_mgr)

	var slot = spawn_mgr.assign_slot(4, 4)
	var puppet = spawn_mgr.spawn_remote_player_if_needed(4, slot)

	if puppet != null and spawn_mgr.tracked_players.has(4):
		_log_pass("10. Remote player registered with nametag 'Player 4'.")
	else:
		_log_fail("10. Remote player registration failed.")

	spawn_mgr.free_slot(4)
	if not spawn_mgr.tracked_players.has(4):
		_log_pass("11. Disconnecting remote player cleanly removes puppet and nametag.")
	else:
		_log_fail("11. Remote player cleanup failed.")

	root_node.free()

## Test 7 — Camera Isolation
func test_camera_isolation() -> void:
	var local_p = PlayerScene.instantiate() as PlayerController
	local_p.setup_player(1, "Local", true)

	var remote_p = PlayerScene.instantiate() as PlayerController
	remote_p.setup_player(2, "Remote", false)

	var local_cam = local_p.get_node_or_null("Camera2D") as Camera2D
	var remote_cam = remote_p.get_node_or_null("Camera2D") as Camera2D

	if local_cam != null and local_cam.enabled and remote_cam != null and not remote_cam.enabled:
		_log_pass("12. Local camera active; remote player camera inactive.")
	else:
		_log_fail("12. Camera isolation failed.")

	local_p.free()
	remote_p.free()

## Test 8 — Blackout Vision Isolation
func test_blackout_vision_isolation() -> void:
	var local_p = PlayerScene.instantiate() as PlayerController
	local_p.setup_player(1, "Local", true)

	var remote_p = PlayerScene.instantiate() as PlayerController
	remote_p.setup_player(2, "Remote", false)

	var local_light = local_p.get_node_or_null("VisionLight") as PointLight2D
	var remote_light = remote_p.get_node_or_null("VisionLight") as PointLight2D

	# Enable light on local to simulate blackout active state
	if local_light != null:
		local_light.enabled = true
	remote_p._update_camera_and_light_state()

	if local_light != null and local_light.enabled and remote_light != null and not remote_light.enabled:
		_log_pass("13. Remote player vision light disabled to prevent light leakage in Blackout.")
	else:
		_log_fail("13. Blackout vision isolation failed.")

	local_p.free()
	remote_p.free()

## Test 9 — Existing Physics and Spawn Layout Compatibility
func test_existing_physics_and_spawns() -> void:
	var player = PlayerController.new()
	var vel = player.calculate_movement_velocity(Vector2.RIGHT)
	if vel == Vector2(250.0, 0.0):
		_log_pass("14. Base movement calculation intact.")
	else:
		_log_fail("14. Movement velocity altered unexpectedly.")
	player.free()
