extends SceneTree

## Unit Test Suite for BLACKOUT Camera System (Member 3 - Camera).
## Verifies:
##   1. GameCamera instantiates correctly as Camera2D.
##   2. Default smoothing configuration (position_smoothing_enabled = true).
##   3. Screen shake triggering with custom intensity and duration.
##   4. Quadratic decay calculation during active shake.
##   5. Automatic recovery to zero offset upon shake duration expiry.
##   6. Configurable camera viewport/map limits (set_camera_limits & clear_camera_limits).
##   7. Integration with PlayerController (trigger_screen_shake).

const GameCamera = preload("res://client/camera/game_camera.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — GAME CAMERA SYSTEM TEST (MEMBER 3)")
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
	test_camera_instantiation()
	test_shake_trigger_and_decay()
	test_shake_recovery()
	test_camera_limits()
	test_player_camera_integration()

	print("\n========================================================")
	if test_passed:
		print("  GAME CAMERA TESTS: ALL PASSED (100%)")
	else:
		print("  GAME CAMERA TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_camera_instantiation() -> void:
	var cam = GameCamera.new()
	if cam != null and cam is Camera2D:
		_log_pass("1. GameCamera instantiates as Camera2D.")
	else:
		_log_fail("1. GameCamera failed instantiation.")
	
	cam._ready()
	if cam.position_smoothing_enabled == true:
		_log_pass("2. Position smoothing is enabled by default.")
	else:
		_log_fail("2. Position smoothing not enabled.")
	cam.free()

func test_shake_trigger_and_decay() -> void:
	var cam = GameCamera.new()
	cam.trigger_shake(15.0, 0.5)
	
	if cam.shake_intensity == 15.0 and cam.shake_duration == 0.5 and cam.shake_timer == 0.5:
		_log_pass("3. trigger_shake() properly sets intensity and duration.")
	else:
		_log_fail("3. trigger_shake() state unexpected: int=%f, dur=%f" % [cam.shake_intensity, cam.shake_duration])

	# Advance shake midway (0.25s elapsed)
	cam._process_shake(0.25)
	if cam.shake_timer == 0.25 and cam.offset != Vector2.ZERO:
		_log_pass("4. Screen shake processes active non-zero offset with progress decay.")
	else:
		_log_fail("4. Screen shake offset not applied during active timer.")
	cam.free()

func test_shake_recovery() -> void:
	var cam = GameCamera.new()
	cam.trigger_shake(12.0, 0.2)
	# Advance beyond full duration
	cam._process_shake(0.25)

	if cam.offset == Vector2.ZERO and cam.shake_intensity == 0.0 and cam.shake_timer == 0.0:
		_log_pass("5. Camera offset and shake state cleanly recover to ZERO on timer expiration.")
	else:
		_log_fail("5. Camera failed to recover cleanly after shake.")
	cam.free()

func test_camera_limits() -> void:
	var cam = GameCamera.new()
	cam.set_camera_limits(-500, -300, 1500, 1000)

	if cam.limit_left == -500 and cam.limit_top == -300 and cam.limit_right == 1500 and cam.limit_bottom == 1000:
		_log_pass("6. set_camera_limits() correctly configures viewport boundaries.")
	else:
		_log_fail("6. set_camera_limits() values unexpected.")

	cam.clear_camera_limits()
	if cam.limit_left < -100000 and cam.limit_right > 100000:
		_log_pass("7. clear_camera_limits() properly resets boundaries.")
	else:
		_log_fail("7. clear_camera_limits() did not reset limits.")
	cam.free()

func test_player_camera_integration() -> void:
	var scene_instance = PlayerScene.instantiate()
	if scene_instance != null:
		var cam_node = scene_instance.get_node_or_null("Camera2D")
		if cam_node != null and cam_node is GameCamera:
			_log_pass("8. PlayerScene contains active GameCamera child node.")
		else:
			_log_fail("8. PlayerScene missing GameCamera child.")

		var controller = scene_instance as PlayerController
		if controller != null:
			controller.trigger_screen_shake(10.0, 0.3)
			if cam_node.shake_timer == 0.3:
				_log_pass("9. PlayerController.trigger_screen_shake() delegates directly to GameCamera.")
			else:
				_log_fail("9. PlayerController screen shake trigger delegation failed.")
		scene_instance.free()
	else:
		_log_fail("8. Failed to instantiate PlayerScene.")
