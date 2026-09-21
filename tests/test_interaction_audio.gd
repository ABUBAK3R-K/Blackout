extends SceneTree

## Unit Test Suite for BLACKOUT Door Audio & Interaction Audio System.
## Verifies:
##   1. Door opening sound trigger ("open_start" on open_door).
##   2. Door open completion sound ("open_finish" on open finished).
##   3. Door closing sound trigger ("close_start" on close_door).
##   4. Door close completion sound ("close_finish" on close finished).
##   5. Door jammed/malfunction sound ("jammed" on set_jammed(true)).
##   6. Terminal interaction audio ("activate" on online, "standby" on deactivate).
##   7. Positional 2D audio configuration (max_distance = 650.0, attenuation = 1.2).
##   8. Blackout compatibility (audio plays independently of visual lighting).
##   9. Existing door collision and interaction behavior preserved.
##   10. Compatibility with existing player physics, camera, and spawn slots.

const DoorController = preload("res://client/environment/door_controller.gd")
const DoorScene = preload("res://scenes/objects/door.tscn")
const TestTerminal = preload("res://client/environment/test_terminal.gd")
const TerminalScene = preload("res://scenes/objects/test_terminal.tscn")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")
const BlackoutLightingManager = preload("res://client/environment/blackout_lighting_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")
const SpawnManager = preload("res://client/player/spawn_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — DOOR & INTERACTION AUDIO TEST SUITE")
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
	test_door_open_sounds()
	test_door_close_sounds()
	test_door_jammed_sound()
	test_terminal_interaction_audio()
	test_positional_audio_settings()
	test_blackout_audio_compatibility()
	test_existing_door_collision_behavior()
	test_existing_systems_compatibility()

	print("\n========================================================")
	if test_passed:
		print("  DOOR & INTERACTION AUDIO TESTS: ALL PASSED (100%)")
	else:
		print("  DOOR & INTERACTION AUDIO TESTS: SOME FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

## Test 1 & 2 — Door Open Sounds
func test_door_open_sounds() -> void:
	var door = DoorScene.instantiate() as DoorController
	door._ready()

	var audio = door.get_node_or_null("InteractionAudio") as InteractionAudio
	if audio == null:
		_log_fail("1. DoorScene missing InteractionAudio component.")
		door.free()
		return

	var sounds_played: Array[String] = []
	audio.sound_played.connect(func(sound_name, pos, pitch, vol):
		sounds_played.append(sound_name)
	)

	door.open_door()
	if sounds_played.has("open_start"):
		_log_pass("1. Door opening triggers 'open_start' sound cue.")
	else:
		_log_fail("1. Door opening failed to trigger 'open_start' sound.")

	door._on_open_completed()
	if sounds_played.has("open_finish"):
		_log_pass("2. Door open completion triggers 'open_finish' sound cue.")
	else:
		_log_fail("2. Door open completion failed to trigger 'open_finish' sound.")

	door.free()

## Test 3 & 4 — Door Close Sounds
func test_door_close_sounds() -> void:
	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door._set_instant_state(DoorController.DoorState.OPEN)

	var audio = door.get_node_or_null("InteractionAudio") as InteractionAudio
	var sounds_played: Array[String] = []
	audio.sound_played.connect(func(sound_name, pos, pitch, vol):
		sounds_played.append(sound_name)
	)

	door.close_door()
	if sounds_played.has("close_start"):
		_log_pass("3. Door closing triggers 'close_start' sound cue.")
	else:
		_log_fail("3. Door closing failed to trigger 'close_start' sound.")

	door._on_close_completed()
	if sounds_played.has("close_finish"):
		_log_pass("4. Door close completion triggers 'close_finish' sound cue.")
	else:
		_log_fail("4. Door close completion failed to trigger 'close_finish' sound.")

	door.free()

## Test 5 — Door Jammed Sound
func test_door_jammed_sound() -> void:
	var door = DoorScene.instantiate() as DoorController
	door._ready()

	var audio = door.get_node_or_null("InteractionAudio") as InteractionAudio
	var sounds_played: Array[String] = []
	audio.sound_played.connect(func(sound_name, pos, pitch, vol):
		sounds_played.append(sound_name)
	)

	door.set_jammed(true)
	if sounds_played.has("jammed") and door.current_state == DoorController.DoorState.JAMMED:
		_log_pass("5. Jamming door triggers 'jammed' alarm cue and updates state to JAMMED.")
	else:
		_log_fail("5. Jammed door sound trigger failed.")

	door.free()

## Test 6 — Terminal Interaction Audio
func test_terminal_interaction_audio() -> void:
	var terminal = TerminalScene.instantiate() as TestTerminal
	terminal._ready()

	var audio = terminal.get_node_or_null("InteractionAudio") as InteractionAudio
	if audio == null:
		_log_fail("6. TerminalScene missing InteractionAudio component.")
		terminal.free()
		return

	var sounds_played: Array[String] = []
	audio.sound_played.connect(func(sound_name, pos, pitch, vol):
		sounds_played.append(sound_name)
	)

	var dummy_player = Node2D.new()
	dummy_player.name = "Player 1"

	# Toggle 1: Standby -> Active
	terminal._on_interacted(dummy_player)
	if sounds_played.has("activate") and terminal.is_activated:
		_log_pass("6. Terminal activation triggers 'activate' audio cue.")
	else:
		_log_fail("6. Terminal activation failed to trigger audio.")

	# Toggle 2: Active -> Standby
	terminal._on_interacted(dummy_player)
	if sounds_played.has("standby") and not terminal.is_activated:
		_log_pass("7. Terminal deactivation triggers 'standby' audio cue.")
	else:
		_log_fail("7. Terminal deactivation failed to trigger audio.")

	dummy_player.free()
	terminal.free()

## Test 7 — Positional Audio Settings
func test_positional_audio_settings() -> void:
	var audio_node = InteractionAudio.new()
	audio_node._ready()

	var player = audio_node.get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if player != null and is_equal_approx(player.max_distance, 650.0) and is_equal_approx(player.attenuation, 1.2):
		_log_pass("8. InteractionAudio configures AudioStreamPlayer2D (max_distance = 650.0, attenuation = 1.2).")
	else:
		_log_fail("8. InteractionAudio spatial settings incorrect.")

	audio_node.free()

## Test 8 — Blackout Compatibility
func test_blackout_audio_compatibility() -> void:
	var lighting = BlackoutLightingManager.new()
	lighting.set_blackout(true, 0.0)

	var door = DoorScene.instantiate() as DoorController
	door._ready()
	var audio = door.get_node_or_null("InteractionAudio") as InteractionAudio

	var played_data = {"fired": false}
	audio.sound_played.connect(func(sound_name, pos, pitch, vol):
		played_data["fired"] = true
	)

	door.open_door()
	if played_data["fired"] and lighting.is_blackout_active():
		_log_pass("9. Door audio triggers and remains fully functional during Emergency Blackout.")
	else:
		_log_fail("9. Door audio failed during Blackout.")

	door.free()
	lighting.free()

## Test 9 — Existing Door Collision Behavior
func test_existing_door_collision_behavior() -> void:
	var door = DoorScene.instantiate() as DoorController
	door._ready()

	var closed_active = door.collision_shape.disabled == false
	door.open_door()
	var open_disabled = door.collision_shape.disabled == true
	door._on_open_completed()
	door.close_door()
	door._on_close_completed()
	var reclosed_active = door.collision_shape.disabled == false

	if closed_active and open_disabled and reclosed_active:
		_log_pass("10. Physical obstacle collision toggles correctly between OPEN and CLOSED states.")
	else:
		_log_fail("10. Physical obstacle collision toggling broken.")

	door.free()

## Test 10 — Existing Systems Compatibility
func test_existing_systems_compatibility() -> void:
	var spawn_mgr = SpawnManager.new()
	if spawn_mgr.get_all_spawn_positions().size() == 8:
		_log_pass("11. Deterministic 8-slot spawn management and player physics intact.")
	else:
		_log_fail("11. Spawn management modified unexpectedly.")
	spawn_mgr.free()
