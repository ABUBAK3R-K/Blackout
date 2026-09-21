extends SceneTree

## Unit Test Suite for BLACKOUT 2D Player Controller (Member 3 - Step 1).
## Verifies:
##   1. PlayerController instantiates correctly.
##   2. Configurable move_speed export.
##   3. Directional movement calculation (Up, Down, Left, Right).
##   4. Diagonal normalization (diagonal length equals 1.0).
##   5. Input state gating (can_move = false zeroes out velocity).
##   6. Non-local player gating (is_local_player = false zeroes out velocity).
##   7. Player slot & name setup.
##   8. Scene structure and CollisionShape2D configuration.

const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — PLAYER CONTROLLER TEST (MEMBER 3 - STEP 1)")
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
	test_controller_instantiation()
	test_movement_calculation()
	test_diagonal_normalization()
	test_movement_gating()
	test_player_setup()
	test_scene_structure()

	print("\n========================================================")
	if test_passed:
		print("  PLAYER CONTROLLER TESTS: ALL PASSED (100%)")
	else:
		print("  PLAYER CONTROLLER TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_controller_instantiation() -> void:
	var player = PlayerController.new()
	if player != null and player is CharacterBody2D:
		_log_pass("1. PlayerController instantiates as CharacterBody2D.")
	else:
		_log_fail("1. PlayerController failed instantiation.")
	
	if player.move_speed == 250.0:
		_log_pass("2. Default move_speed is configured to 250.0.")
	else:
		_log_fail("2. Default move_speed unexpected: %f" % player.move_speed)
	player.free()

func test_movement_calculation() -> void:
	var player = PlayerController.new()
	var right_vel = player.calculate_movement_velocity(Vector2.RIGHT)
	if right_vel == Vector2(250.0, 0.0):
		_log_pass("3. Horizontal velocity calculation matches move_speed.")
	else:
		_log_fail("3. Horizontal velocity unexpected: %s" % str(right_vel))

	var up_vel = player.calculate_movement_velocity(Vector2.UP)
	if up_vel == Vector2(0.0, -250.0):
		_log_pass("4. Vertical velocity calculation matches move_speed.")
	else:
		_log_fail("4. Vertical velocity unexpected: %s" % str(up_vel))
	player.free()

func test_diagonal_normalization() -> void:
	var player = PlayerController.new()
	var raw_diagonal = Vector2(1.0, 1.0)
	var normalized_diag = raw_diagonal.normalized()
	var diag_vel = player.calculate_movement_velocity(normalized_diag)

	# Diagonal speed magnitude must equal base move_speed (250.0), not 250 * sqrt(2) (~353.5)
	if is_equal_approx(diag_vel.length(), player.move_speed):
		_log_pass("5. Diagonal movement is normalized (length = %.1f, not boosted)." % diag_vel.length())
	else:
		_log_fail("5. Diagonal movement length incorrect: %f" % diag_vel.length())
	player.free()

func test_movement_gating() -> void:
	var player = PlayerController.new()
	player.can_move = false
	player.velocity = Vector2(100.0, 100.0)
	player._physics_process(0.016)
	if player.velocity == Vector2.ZERO:
		_log_pass("6. Movement gating: can_move = false zeroes velocity.")
	else:
		_log_fail("6. Movement gating failed for can_move = false.")

	player.can_move = true
	player.is_local_player = false
	player.velocity = Vector2(100.0, 100.0)
	player._physics_process(0.016)
	if player.velocity == Vector2.ZERO:
		_log_pass("7. Movement gating: is_local_player = false zeroes velocity.")
	else:
		_log_fail("7. Movement gating failed for non-local player.")
	player.free()

func test_player_setup() -> void:
	var player = PlayerController.new()
	player.setup_player(3, "Aaliya (M3)", true)
	if player.slot_id == 3 and player.player_name == "Aaliya (M3)" and player.is_local_player == true:
		_log_pass("8. setup_player() correctly updates slot, name, and local flag.")
	else:
		_log_fail("8. setup_player() failed to update identity.")
	player.free()

func test_scene_structure() -> void:
	var scene_instance = PlayerScene.instantiate()
	if scene_instance != null:
		_log_pass("9. PlayerScene instantiates successfully from player.tscn.")
		var col_shape = scene_instance.get_node_or_null("CollisionShape2D")
		if col_shape != null and col_shape is CollisionShape2D and col_shape.shape != null:
			_log_pass("10. PlayerScene contains active CollisionShape2D with valid shape.")
		else:
			_log_fail("10. PlayerScene missing valid CollisionShape2D.")
		scene_instance.free()
	else:
		_log_fail("9. Failed to instantiate PlayerScene.")
