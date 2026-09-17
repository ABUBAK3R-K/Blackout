extends SceneTree

## Unit Test Suite for BLACKOUT Multi-Step Task / Mini-Game Foundation (Member 3).
## Verifies:
##   1. Electrical Junction instantiates with 4 configured sequential TaskSteps.
##   2. Objective starts in AVAILABLE state with current_step_index = 0.
##   3. ObjectiveTracker displays Step 1/4 and initial counter 'Completed: 0/1'.
##   4. First interaction completes Step 1 ('Open Junction Panel') and advances to Step 2.
##   5. State remains IN_PROGRESS and counter remains 'Completed: 0/1' during Step 2.
##   6. Second interaction completes Step 2 ('Inspect Electrical Circuit') and advances to Step 3.
##   7. Third interaction completes Step 3 ('Restore Power') and advances to Step 4.
##   8. Fourth interaction completes Step 4 ('Close Junction Panel') and transitions objective to COMPLETED.
##   9. ObjectiveTracker updates to '☑' and counter advances to 'Completed: 1/1'.
##   10. Repeated interactions after completion are rejected without duplicate signals.
##   11. Locked state rejects interactions; unlocking restores progression.
##   12. Reset clears step completion states and resets index to 0.
##   13. Backward compatibility: single-step objectives without task_steps complete in 1 step.
##   14. Non-regression: TestTerminal, DoorController, and multiplayer StateSync remain functional.

const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")
const TaskStep = preload("res://client/objectives/task_step.gd")
const ElectricalJunctionScene = preload("res://scenes/objects/electrical_junction.tscn")
const ObjectiveTracker = preload("res://client/objectives/objective_tracker.gd")
const ObjectiveTrackerScene = preload("res://scenes/ui/objective_tracker.tscn")
const TestTerminalScene = preload("res://scenes/objects/test_terminal.tscn")
const TestTerminal = preload("res://client/environment/test_terminal.gd")
const DoorScene = preload("res://scenes/objects/door.tscn")
const DoorController = preload("res://client/environment/door_controller.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const StateSync = preload("res://client/player/state_sync.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MULTI-STEP TASK / MINI-GAME TEST (MEMBER 3)")
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
	test_electrical_junction_step_configuration()
	test_multi_step_sequential_execution_and_tracker()
	test_repeat_interaction_protection()
	test_locked_and_unlock_behavior()
	test_reset_objective()
	test_backwards_compatibility_single_step()
	test_existing_systems_regression()

	print("\n========================================================")
	if test_passed:
		print("  MULTI-STEP TASK TESTS: ALL PASSED (100%)")
	else:
		print("  MULTI-STEP TASK TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_electrical_junction_step_configuration() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	if obj.has_steps() and obj.get_total_steps() == 4:
		_log_pass("1. Electrical Junction has 4 configured sequential TaskSteps.")
	else:
		_log_fail("1. Electrical Junction step count mismatch (total: %d)." % obj.get_total_steps())

	var s1 = obj.task_steps[0]
	var s2 = obj.task_steps[1]
	var s3 = obj.task_steps[2]
	var s4 = obj.task_steps[3]

	if s1.step_name == "Open Junction Panel" and s2.step_name == "Inspect Electrical Circuit" and s3.step_name == "Restore Power" and s4.step_name == "Close Junction Panel":
		_log_pass("2. All 4 step names match specification exactly.")
	else:
		_log_fail("2. Step names mismatch: [%s, %s, %s, %s]" % [s1.step_name, s2.step_name, s3.step_name, s4.step_name])

	if obj.current_state == ObjectiveInteractable.ObjectiveState.AVAILABLE and obj.current_step_index == 0:
		_log_pass("3. Initial state is AVAILABLE with current_step_index = 0.")
	else:
		_log_fail("3. Initial state unexpected.")

	obj.free()

func test_multi_step_sequential_execution_and_tracker() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()
	tracker.register_objective(obj)

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Step 0 initial check
	if tracker.progress_label.text == "Completed: 0/1":
		_log_pass("4. Initial HUD counter displays 'Completed: 0/1'.")
	else:
		_log_fail("4. Initial counter incorrect: %s" % tracker.progress_label.text)

	# --- INTERACTION 1: Complete Step 1 (Open Junction Panel) -> Advance to Step 2 ---
	obj.trigger._on_body_entered(player)
	player.try_interact()

	var s1 = obj.task_steps[0]
	if s1.is_completed and obj.current_step_index == 1 and obj.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("5. Interaction 1 completes Step 1 and advances to Step 2 (State: IN_PROGRESS).")
	else:
		_log_fail("5. Interaction 1 failed to advance to Step 2.")

	var row_data = tracker.task_row_nodes.get(obj.objective_id, {})
	var icon_label: Label = row_data.get("icon_label")
	var loc_label: Label = row_data.get("loc_label")

	if icon_label.text == "◐" and loc_label.text.contains("Step 2/4") and tracker.progress_label.text == "Completed: 0/1":
		_log_pass("6. HUD displays '◐', Step 2/4 description, and counter remains 'Completed: 0/1'.")
	else:
		_log_fail("6. HUD display mismatch after Step 1: icon=%s, loc=%s, prog=%s" % [icon_label.text, loc_label.text, tracker.progress_label.text])

	# --- INTERACTION 2: Complete Step 2 (Inspect Electrical Circuit) -> Advance to Step 3 ---
	player.try_interact()

	var s2 = obj.task_steps[1]
	if s2.is_completed and obj.current_step_index == 2 and obj.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("7. Interaction 2 completes Step 2 and advances to Step 3.")
	else:
		_log_fail("7. Interaction 2 failed to advance to Step 3.")

	if tracker.progress_label.text == "Completed: 0/1" and loc_label.text.contains("Step 3/4"):
		_log_pass("8. HUD displays Step 3/4 and counter remains 'Completed: 0/1'.")
	else:
		_log_fail("8. HUD display mismatch after Step 2.")

	# --- INTERACTION 3: Complete Step 3 (Restore Power) -> Advance to Step 4 ---
	player.try_interact()

	var s3 = obj.task_steps[2]
	if s3.is_completed and obj.current_step_index == 3 and obj.current_state == ObjectiveInteractable.ObjectiveState.IN_PROGRESS:
		_log_pass("9. Interaction 3 completes Step 3 and advances to Step 4.")
	else:
		_log_fail("9. Interaction 3 failed to advance to Step 4.")

	if tracker.progress_label.text == "Completed: 0/1" and loc_label.text.contains("Step 4/4"):
		_log_pass("10. HUD displays Step 4/4 and counter remains 'Completed: 0/1'.")
	else:
		_log_fail("10. HUD display mismatch after Step 3.")

	# --- INTERACTION 4: Complete Step 4 (Close Junction Panel) -> Final Completion ---
	var obj_completed_data = {"fired": false}
	obj.objective_completed.connect(func(_p): obj_completed_data["fired"] = true)

	player.try_interact()

	var s4 = obj.task_steps[3]
	if s4.is_completed and obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED and obj_completed_data["fired"]:
		_log_pass("11. Interaction 4 completes Step 4, transitions objective to COMPLETED, and emits objective_completed.")
	else:
		_log_fail("11. Final completion failed after Step 4.")

	if icon_label.text == "☑" and tracker.progress_label.text == "Completed: 1/1":
		_log_pass("12. HUD updates icon to '☑' and advances counter to 'Completed: 1/1'.")
	else:
		_log_fail("12. HUD failed to update to 1/1 on completion: icon=%s, prog=%s" % [icon_label.text, tracker.progress_label.text])

	player.free()
	tracker.free()
	obj.free()

func test_repeat_interaction_protection() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	obj.trigger._on_body_entered(player)

	# Execute all 4 steps to completion
	player.try_interact() # Step 1
	player.try_interact() # Step 2
	player.try_interact() # Step 3
	player.try_interact() # Step 4 (Complete)

	var extra_data = {"fired": false}
	obj.objective_completed.connect(func(_p): extra_data["fired"] = true)

	# 5th interaction attempt
	var repeat_result = player.try_interact()
	var direct_advance = obj.advance_task_step(player)

	if not repeat_result and not direct_advance and not extra_data["fired"]:
		_log_pass("13. Repeat interactions after final completion are cleanly rejected.")
	else:
		_log_fail("13. Repeat interaction incorrectly allowed.")

	player.free()
	obj.free()

func test_locked_and_unlock_behavior() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	obj.lock_objective()
	obj.trigger._on_body_entered(player)

	var locked_interact = player.try_interact()
	if not locked_interact and obj.current_state == ObjectiveInteractable.ObjectiveState.LOCKED and obj.current_step_index == 0:
		_log_pass("14. Locked objective rejects interaction and does not advance steps.")
	else:
		_log_fail("14. Locked objective allowed interaction.")

	obj.unlock_objective()
	obj.trigger._on_body_entered(player)
	var unlock_interact = player.try_interact()
	if unlock_interact and obj.current_step_index == 1:
		_log_pass("15. Unlocked objective allows interaction and advances Step 1.")
	else:
		_log_fail("15. Unlocked objective failed to advance Step 1.")

	player.free()
	obj.free()

func test_reset_objective() -> void:
	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	obj.trigger._on_body_entered(player)
	player.try_interact() # Complete Step 1
	player.try_interact() # Complete Step 2

	obj.reset_objective()

	var s1 = obj.task_steps[0]
	var s2 = obj.task_steps[1]

	if obj.current_state == ObjectiveInteractable.ObjectiveState.AVAILABLE and obj.current_step_index == 0 and not s1.is_completed and not s2.is_completed:
		_log_pass("16. reset_objective() resets state to AVAILABLE, index to 0, and step completions to false.")
	else:
		_log_fail("16. reset_objective() failed.")

	player.free()
	obj.free()

func test_backwards_compatibility_single_step() -> void:
	var obj = ObjectiveInteractable.new()
	obj.objective_id = "single_step_test"
	obj.objective_name = "Single Step Objective"
	obj.auto_complete_on_interact = true
	obj._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	var completed_data = {"fired": false}
	obj.objective_completed.connect(func(_p): completed_data["fired"] = true)

	obj.start_objective(player)

	if obj.current_state == ObjectiveInteractable.ObjectiveState.COMPLETED and completed_data["fired"]:
		_log_pass("17. Single-step objective without task_steps completes in 1 step (Backward Compatibility).")
	else:
		_log_fail("17. Single-step backwards compatibility broken.")

	player.free()
	obj.free()

func test_existing_systems_regression() -> void:
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()
	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	terminal.trigger._on_body_entered(player)
	player.try_interact()
	if terminal.is_activated == true:
		_log_pass("18. TestTerminal interaction remains functional.")
	else:
		_log_fail("18. TestTerminal regression.")

	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door.trigger._on_body_entered(player)
	player.try_interact()
	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("19. DoorController interaction remains functional.")
	else:
		_log_fail("19. DoorController regression.")

	var state_sync = StateSync.new()
	state_sync.register_local_player(player)
	if state_sync.local_player == player:
		_log_pass("20. StateSync registration remains functional.")
	else:
		_log_fail("20. StateSync regression.")

	player.free()
	terminal.free()
	door.free()
	state_sync.free()
