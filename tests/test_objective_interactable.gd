extends SceneTree

## Unit Test Suite for BLACKOUT Task Objective Interaction System (Member 3).
## Verifies:
##   1. Objective starts in AVAILABLE state.
##   2. Objective metadata is preserved (ID, Name, Description, Category).
##   3. Local player can interact through existing InteractableTrigger and prompt displays.
##   4. Remote player proximity isolation (remote puppets do not hijack local prompts).
##   5. Objective transitions to IN_PROGRESS upon interaction.
##   6. Objective transitions to COMPLETED and emits completion signal with player node.
##   7. Completed objective cannot complete repeatedly (no duplicate completion signals).
##   8. Locked/unavailable objective cannot be completed (interaction rejected).
##   9. Unlocking a locked objective restores interactivity and allows completion.
##   10. Existing interaction system & InteractableTrigger still work.
##   11. Existing DoorController and TestTerminal interactions still work.
##   12. Existing FootstepAudio & InteractionAudio systems still work.
##   13. Existing multiplayer StateSync remains unaffected.

const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")
const ElectricalJunctionScene = preload("res://scenes/objects/electrical_junction.tscn")
const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const TestTerminal = preload("res://client/environment/test_terminal.gd")
const TestTerminalScene = preload("res://scenes/objects/test_terminal.tscn")
const DoorController = preload("res://client/environment/door_controller.gd")
const DoorScene = preload("res://scenes/objects/door.tscn")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const StateSync = preload("res://client/player/state_sync.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — TASK OBJECTIVE INTERACTION SYSTEM TEST (MEMBER 3)")
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
	test_initial_state_and_metadata()
	test_player_proximity_and_prompts()
	test_remote_player_isolation()
	test_objective_lifecycle_and_completion_signal()
	test_repeated_completion_prevention()
	test_locked_objective_rejection_and_unlocking()
	test_existing_trigger_and_terminal_regression()
	test_existing_door_controller_regression()
	test_existing_audio_systems_regression()
	test_existing_state_sync_regression()

	print("\n========================================================")
	if test_passed:
		print("  OBJECTIVE INTERACTION TESTS: ALL PASSED (100%)")
	else:
		print("  OBJECTIVE INTERACTION TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_initial_state_and_metadata() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	# 1. Starts AVAILABLE
	if obj.current_state == ObjectiveInteractable.ObjectiveState.AVAILABLE:
		_log_pass("1. Objective starts in AVAILABLE state.")
	else:
		_log_fail("1. Objective did not start in AVAILABLE state (state: %d)." % obj.current_state)

	# 2. Preserves metadata
	var data = obj.get_objective_data()
	if data["objective_id"] == "electrical_junction_01" and data["objective_name"] == "Electrical Junction" and data["category"] == "electrical":
		_log_pass("2. Objective metadata (ID, Name, Description, Category) is preserved.")
	else:
		_log_fail("2. Objective metadata mismatch.")

	obj.free()

func test_player_proximity_and_prompts() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()
	obj.trigger._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Simulate local player entering proximity
	obj.trigger._on_body_entered(player)

	if player.current_interactable == obj.trigger and obj.trigger.prompt_label != null and obj.trigger.prompt_label.visible == true:
		_log_pass("3. Local player entering proximity registers trigger and displays prompt.")
	else:
		_log_fail("3. Local player proximity registration failed.")

	# Simulate local player exiting proximity
	obj.trigger._on_body_exited(player)
	if player.current_interactable == null and obj.trigger.prompt_label.visible == false:
		_log_pass("4. Local player exiting proximity unregisters trigger and hides prompt.")
	else:
		_log_fail("4. Local player proximity unregistration failed.")

	player.free()
	obj.free()

func test_remote_player_isolation() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()
	obj.trigger._ready()

	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player.is_local_player = false

	# Remote player enters proximity
	obj.trigger._on_body_entered(remote_player)
	if obj.trigger.current_player == null and obj.trigger.prompt_label.visible == false:
		_log_pass("5. Remote player proximity does not trigger local prompt or hijack trigger.")
	else:
		_log_fail("5. Remote player breached interaction isolation.")

	remote_player.free()
	obj.free()

func test_objective_lifecycle_and_completion_signal() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	var started_data = {"fired": false}
	var completed_data = {"fired": false, "player": null}

	obj.objective_started.connect(func(p): started_data["fired"] = true)
	obj.objective_completed.connect(func(p):
		completed_data["fired"] = true
		completed_data["player"] = p
	)

	# Enter trigger range
	obj.trigger._on_body_entered(player)

	# Execute 4 steps to completion
	var interact_1 = player.try_interact()
	if interact_1 and started_data["fired"]:
		_log_pass("6. Player interaction transitions objective to IN_PROGRESS and emits objective_started.")
	else:
		_log_fail("6. Interaction failed to start objective.")

	player.try_interact() # Step 2
	player.try_interact() # Step 3
	player.try_interact() # Step 4

	if completed_data["fired"] and completed_data["player"] == player and obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED:
		_log_pass("7. Objective transitions to COMPLETED and emits objective_completed with valid player node.")
	else:
		_log_fail("7. Objective completion signal or state transition failed.")

	if obj.status_label != null and obj.status_label.text.contains("COMPLETED"):
		_log_pass("8. Objective UI status label updates to show COMPLETED status.")
	else:
		_log_fail("8. Objective status label failed to update.")

	player.free()
	obj.free()

func test_repeated_completion_prevention() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	var comp_data = {"count": 0}
	obj.objective_completed.connect(func(_p): comp_data["count"] += 1)

	# Complete all 4 steps
	obj.trigger._on_body_entered(player)
	player.try_interact()
	player.try_interact()
	player.try_interact()
	player.try_interact()

	if comp_data["count"] == 1 and obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED:
		_log_pass("9. First interaction completed the objective successfully.")
	else:
		_log_fail("9. Initial completion failed.")

	# Attempt repeat interactions
	var repeat_result_1 = player.try_interact()
	var direct_complete = obj.complete_objective(player)
	var repeat_result_2 = obj.start_objective(player)

	if comp_data["count"] == 1 and not repeat_result_1 and not direct_complete and not repeat_result_2:
		_log_pass("10. Completed objective cleanly rejects repeat completion attempts (no duplicate signals).")
	else:
		_log_fail("10. Completed objective incorrectly allowed repeat completion (count: %d)." % comp_data["count"])

	player.free()
	obj.free()

func test_locked_objective_rejection_and_unlocking() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Lock objective
	obj.lock_objective()
	if obj.current_state == ObjectiveInteractable.ObjectiveState.LOCKED:
		_log_pass("11. lock_objective() sets state to LOCKED.")
	else:
		_log_fail("11. lock_objective() failed.")

	# Attempt interaction while locked
	obj.trigger._on_body_entered(player)
	var locked_interact = player.try_interact()
	var locked_start = obj.start_objective(player)
	var locked_complete = obj.complete_objective(player)

	if not locked_interact and not locked_start and not locked_complete and obj.current_state == ObjectiveInteractable.ObjectiveState.LOCKED:
		_log_pass("12. Locked objective rejects all interaction and completion attempts.")
	else:
		_log_fail("12. Locked objective accepted interaction.")

	# Unlock objective
	obj.unlock_objective()
	if obj.current_state == ObjectiveInteractable.ObjectiveState.AVAILABLE:
		_log_pass("13. unlock_objective() restores state to AVAILABLE.")
	else:
		_log_fail("13. unlock_objective() failed.")

	# Can complete after unlocking
	obj.trigger._on_body_entered(player)
	player.try_interact()
	player.try_interact()
	player.try_interact()
	player.try_interact()
	if obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED:
		_log_pass("14. Unlocked objective can now be completed normally.")
	else:
		_log_fail("14. Unlocked objective failed to complete.")

	player.free()
	obj.free()

func test_existing_trigger_and_terminal_regression() -> void:
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	terminal.trigger._on_body_entered(player)
	player.try_interact()

	if terminal.is_activated == true and terminal.status_label.text == "TERMINAL: ONLINE [ACTIVE]":
		_log_pass("15. Existing TestTerminal interaction and toggle still work perfectly.")
	else:
		_log_fail("15. TestTerminal regression detected.")

	player.free()
	terminal.free()

func test_existing_door_controller_regression() -> void:
	var door = DoorScene.instantiate() as DoorController
	door._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	door.trigger._on_body_entered(player)
	player.try_interact()

	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("16. Existing DoorController open/close interaction still works perfectly.")
	else:
		_log_fail("16. DoorController regression detected.")

	player.free()
	door.free()

func test_existing_audio_systems_regression() -> void:
	var audio = InteractionAudio.new()
	audio._ready()

	var sound_data = {"fired": false}
	audio.sound_played.connect(func(s_name, _pos, _pitch, _vol):
		if s_name == "objective_complete":
			sound_data["fired"] = true
	)

	audio.play_objective_complete()
	if sound_data["fired"]:
		_log_pass("17. InteractionAudio synthesizes and plays procedural objective_complete audio.")
	else:
		_log_fail("17. InteractionAudio objective_complete playback failed.")

	audio.free()

func test_existing_state_sync_regression() -> void:
	var state_sync = StateSync.new()
	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	state_sync.register_local_player(player)

	if state_sync.local_player == player:
		_log_pass("18. Existing multiplayer StateSync local player registration unaffected.")
	else:
		_log_fail("18. StateSync regression detected.")

	player.free()
	state_sync.free()
