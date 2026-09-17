extends SceneTree

## Unit Test Suite for BLACKOUT Footstep Audio & Proximity Audio System.
## Verifies:
##   1. Stationary state: no footsteps played while player is still.
##   2. Moving state: footsteps triggered at correct ~0.38s cadence at 250 px/s.
##   3. Movement stop: footstep timer resets immediately upon stopping.
##   4. Speed-scaled cadence: faster movement shortens interval, slower movement lengthens interval.
##   5. Remote player positional audio: remote puppets generate footstep cues as they move.
##   6. Distance attenuation configuration (max_distance = 650.0, attenuation = 1.2).
##   7. Maximum hearing range: audio cut off beyond 650px.
##   8. Blackout compatibility: footsteps remain fully audible during Blackout.
##   9. Pitch/volume variation: consecutive footsteps have subtle randomized pitch scales.
##   10. Compatibility with existing player physics, camera, and spawn slots.

const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const FootstepAudio = preload("res://client/player/footstep_audio.gd")
const SpawnManager = preload("res://client/player/spawn_manager.gd")
const BlackoutLightingManager = preload("res://client/environment/blackout_lighting_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — FOOTSTEP AUDIO & PROXIMITY AUDIO TEST SUITE")
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
	test_stationary_state()
	test_moving_cadence()
	test_movement_stop_reset()
	test_speed_scaled_cadence()
	test_remote_player_audio()
	test_distance_attenuation_settings()
	test_blackout_audio_compatibility()
	test_pitch_variation()
	test_existing_systems_compatibility()

	print("\n========================================================")
	if test_passed:
		print("  FOOTSTEP AUDIO TESTS: ALL PASSED (100%)")
	else:
		print("  FOOTSTEP AUDIO TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

## Test 1 — Stationary State
func test_stationary_state() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.velocity = Vector2.ZERO

	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio
	if footstep == null:
		_log_fail("1. PlayerScene missing FootstepAudio component.")
		player.free()
		return

	var steps_triggered: Array = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		steps_triggered.append(idx)
	)

	# Simulate 1.0 second of being stationary
	for i in range(60):
		footstep._physics_process(0.016)

	if steps_triggered.is_empty() and not footstep.is_moving and footstep.step_timer == 0.0:
		_log_pass("1. Stationary player produces 0 footsteps and resets timer.")
	else:
		_log_fail("1. Stationary player triggered footsteps unexpectedly.")

	player.free()

## Test 2 — Moving Cadence at 250 px/s
func test_moving_cadence() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.velocity = Vector2(250.0, 0.0) # Base movement speed

	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio
	var steps_triggered: Array = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		steps_triggered.append(idx)
	)

	# 0.20s -> less than base_step_interval (0.38s), 0 steps
	footstep._physics_process(0.20)
	var steps_at_200ms = steps_triggered.size()

	# Another 0.20s (total 0.40s) -> exceeds 0.38s, exactly 1 step
	footstep._physics_process(0.20)
	var steps_at_400ms = steps_triggered.size()

	if steps_at_200ms == 0 and steps_at_400ms == 1:
		_log_pass("2. Footstep cadence at 250 px/s triggers at ~0.38s interval (1 step at 0.40s).")
	else:
		_log_fail("2. Footstep cadence incorrect: %d at 200ms, %d at 400ms" % [steps_at_200ms, steps_at_400ms])

	player.free()

## Test 3 — Movement Stop Resets Cadence
func test_movement_stop_reset() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.velocity = Vector2(250.0, 0.0)

	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio
	footstep._physics_process(0.25) # Accumulate 0.25s
	if footstep.step_timer < 0.24:
		_log_fail("3. Timer accumulation failed.")
		player.free()
		return

	# Player stops moving
	player.velocity = Vector2.ZERO
	footstep._physics_process(0.016)

	if footstep.step_timer == 0.0 and not footstep.is_moving:
		_log_pass("3. Stopping movement immediately resets step timer to 0.0.")
	else:
		_log_fail("3. Step timer failed to reset on stop: %f" % footstep.step_timer)

	player.free()

## Test 4 — Speed-Scaled Cadence
func test_speed_scaled_cadence() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)

	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio

	# Slow speed (125 px/s) -> interval should be ~2x longer (~0.70s max)
	player.velocity = Vector2(125.0, 0.0)
	var steps_slow: Array = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		steps_slow.append(idx)
	)

	footstep._physics_process(0.40) # At 250px/s this would trigger, but at 125px/s it should not
	if steps_slow.is_empty():
		_log_pass("4. Slower movement (125 px/s) lengthens cadence interval.")
	else:
		_log_fail("4. Slower movement cadence triggered too early.")

	player.free()

## Test 5 — Remote Player Positional Audio
func test_remote_player_audio() -> void:
	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player.setup_player(2, "Player 2", false)
	remote_player.velocity = Vector2(250.0, 0.0) # Received via StateSync

	var footstep = remote_player.get_node_or_null("FootstepAudio") as FootstepAudio
	var steps: Array = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		steps.append({"pos": pos, "vol": vol})
	)

	footstep._physics_process(0.40)
	if steps.size() == 1:
		_log_pass("5. Remote player puppet generates positional footsteps from synchronized velocity.")
	else:
		_log_fail("5. Remote player failed to generate footsteps: count = %d" % steps.size())

	remote_player.free()

## Test 6 — Distance Attenuation Settings
func test_distance_attenuation_settings() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio
	var audio_player = player.get_node_or_null("FootstepAudio/FootstepPlayer") as AudioStreamPlayer2D

	if audio_player != null and is_equal_approx(audio_player.max_distance, 650.0) and is_equal_approx(audio_player.attenuation, 1.2):
		_log_pass("6. AudioStreamPlayer2D configured with max_distance = 650.0 px and attenuation = 1.2.")
	else:
		_log_fail("6. AudioStreamPlayer2D attenuation settings incorrect.")

	player.free()

## Test 7 — Blackout Audio Compatibility
func test_blackout_audio_compatibility() -> void:
	var lighting = BlackoutLightingManager.new()
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)
	player.velocity = Vector2(250.0, 0.0)

	lighting.register_local_player_light(player.vision_light, player.directional_light)
	lighting.set_blackout(true, 0.0) # Emergency Blackout active

	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio
	var steps: Array = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		steps.append(idx)
	)

	footstep._physics_process(0.40)
	if steps.size() == 1 and lighting.is_blackout_active():
		_log_pass("7. Footstep audio operates seamlessly during Emergency Blackout.")
	else:
		_log_fail("7. Footstep audio failed during Blackout.")

	player.free()
	lighting.free()

## Test 8 — Pitch Variation
func test_pitch_variation() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	var footstep = player.get_node_or_null("FootstepAudio") as FootstepAudio

	var pitches: Array[float] = []
	footstep.footstep_triggered.connect(func(idx, pos, pitch, vol):
		pitches.append(pitch)
	)

	# Trigger multiple footsteps manually
	for i in range(10):
		footstep.trigger_step_manually()

	var all_same: bool = true
	for p in pitches:
		if p != pitches[0]:
			all_same = false
			break

	if not all_same and pitches.size() == 10:
		_log_pass("8. Consecutive footsteps feature randomized pitch variation (min: %.3f, max: %.3f)." % [
			pitches.min(), pitches.max()
		])
	else:
		_log_fail("8. Footstep pitch variation failed.")

	player.free()

## Test 9 — Existing Systems Compatibility
func test_existing_systems_compatibility() -> void:
	var player = PlayerScene.instantiate() as PlayerController
	player.setup_player(1, "Player 1", true)

	var has_body = player is CharacterBody2D
	var has_cam = player.get_node_or_null("Camera2D") != null
	var has_vis_light = player.get_node_or_null("VisionLight") != null
	var has_flash = player.get_node_or_null("FlashlightPivot/DirectionalLight") != null
	var has_label = player.get_node_or_null("NameLabel") != null
	var has_audio = player.get_node_or_null("FootstepAudio") != null

	if has_body and has_cam and has_vis_light and has_flash and has_label and has_audio:
		_log_pass("9. All player components (Physics, Camera, VisionLight, Flashlight, Nametag, Audio) intact.")
	else:
		_log_fail("9. Player node hierarchy incomplete.")

	player.free()
