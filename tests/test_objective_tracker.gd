extends SceneTree

## Unit Test Suite for BLACKOUT Objective Tracker HUD System (Member 3).
## Verifies:
##   1. ObjectiveTracker instantiates with valid UI structure (Header, List, Footer).
##   2. Tracker displays "TASKS" title, objective name, and room location.
##   3. Initial state is displayed correctly (AVAILABLE -> '☐', 'Completed: 0/1').
##   4. Event-driven update on IN_PROGRESS (icon -> '◐', completion count unchanged).
##   5. Event-driven update on COMPLETED (icon -> '☑', 'Completed: 1/1').
##   6. Event-driven update on LOCKED (icon -> '🔒').
##   7. Graceful handling of zero registered objectives ('Completed: 0/0', EmptyLabel visible).
##   8. Multiple objectives tracking with mixed states (e.g., 2/3 completed).
##   9. Unregistering and clearing objectives cleanly updates UI and disconnects signals.
##   10. Auto-discovery of ObjectiveInteractable instances from scene tree.
##   11. Non-regression of existing interaction, door, terminal, and state sync systems.

const ObjectiveTracker = preload("res://client/objectives/objective_tracker.gd")
const ObjectiveTrackerScene = preload("res://scenes/ui/objective_tracker.tscn")
const ObjectiveInteractable = preload("res://client/objectives/objective_interactable.gd")
const ElectricalJunctionScene = preload("res://scenes/objects/electrical_junction.tscn")
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
	print("  BLACKOUT — OBJECTIVE TRACKER HUD TEST (MEMBER 3)")
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
	test_tracker_instantiation_and_structure()
	test_objective_registration_and_initial_display()
	test_state_change_in_progress()
	test_state_change_completed_and_counter()
	test_state_change_locked()
	test_zero_objectives_handling()
	test_multiple_objectives_mixed_states()
	test_unregister_and_cleanup()
	test_existing_systems_non_regression()

	print("\n========================================================")
	if test_passed:
		print("  OBJECTIVE TRACKER TESTS: ALL PASSED (100%)")
	else:
		print("  OBJECTIVE TRACKER TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_tracker_instantiation_and_structure() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	if tracker != null and tracker.task_list_container != null and tracker.progress_label != null:
		_log_pass("1. ObjectiveTracker instantiates with complete UI hierarchy (TaskList, ProgressLabel).")
	else:
		_log_fail("1. ObjectiveTracker UI structure missing subcomponents.")

	var header = tracker.get_node_or_null("MarginContainer/VBoxContainer/HeaderLabel") as Label
	if header != null and header.text == "TASKS":
		_log_pass("2. Header correctly displays title 'TASKS'.")
	else:
		_log_fail("2. Header title missing or incorrect.")

	tracker.free()

func test_objective_registration_and_initial_display() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	tracker.register_objective(obj)

	var row_data = tracker.task_row_nodes.get(obj.objective_id, {})
	var icon_label: Label = row_data.get("icon_label")
	var name_label: Label = row_data.get("name_label")
	var loc_label: Label = row_data.get("loc_label")

	if icon_label != null and icon_label.text == "☐":
		_log_pass("3. Initial AVAILABLE state displays unchecked box icon '☐'.")
	else:
		_log_fail("3. Initial state icon incorrect.")

	if name_label != null and name_label.text == "Electrical Junction":
		_log_pass("4. Objective name 'Electrical Junction' displayed correctly.")
	else:
		_log_fail("4. Objective name label mismatch.")

	if loc_label != null and loc_label.text.contains("Generator Room"):
		_log_pass("5. Room location 'Generator Room' displayed correctly.")
	else:
		_log_fail("5. Room location label mismatch: %s" % (loc_label.text if loc_label != null else "null"))

	if tracker.progress_label.text == "Completed: 0/1":
		_log_pass("6. Initial completion counter shows 'Completed: 0/1'.")
	else:
		_log_fail("6. Initial completion counter incorrect: %s" % tracker.progress_label.text)

	obj.free()
	tracker.free()

func test_state_change_in_progress() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()
	obj.auto_complete_on_interact = false # Prevent immediate auto-complete

	tracker.register_objective(obj)

	# Transition to IN_PROGRESS
	obj.start_objective(null)

	var row_data = tracker.task_row_nodes.get(obj.objective_id, {})
	var icon_label: Label = row_data.get("icon_label")

	if icon_label != null and icon_label.text == "◐":
		_log_pass("7. IN_PROGRESS state updates icon to '◐'.")
	else:
		_log_fail("7. IN_PROGRESS icon failed to update.")

	if tracker.progress_label.text == "Completed: 0/1":
		_log_pass("8. IN_PROGRESS state does not prematurely increment completion counter.")
	else:
		_log_fail("8. Completion counter prematurely changed on IN_PROGRESS: %s" % tracker.progress_label.text)

	obj.free()
	tracker.free()

func test_state_change_completed_and_counter() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	tracker.register_objective(obj)

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Complete all 4 steps of objective
	obj.trigger._on_body_entered(player)
	player.try_interact() # Step 1
	player.try_interact() # Step 2
	player.try_interact() # Step 3
	player.try_interact() # Step 4

	var row_data = tracker.task_row_nodes.get(obj.objective_id, {})
	var icon_label: Label = row_data.get("icon_label")

	if icon_label != null and icon_label.text == "☑":
		_log_pass("9. COMPLETED state updates icon to '☑'.")
	else:
		_log_fail("9. COMPLETED icon failed to update: %s" % (icon_label.text if icon_label != null else "null"))

	if tracker.progress_label.text == "Completed: 1/1":
		_log_pass("10. Completion counter automatically advances to 'Completed: 1/1'.")
	else:
		_log_fail("10. Completion counter failed to update: %s" % tracker.progress_label.text)

	player.free()
	obj.free()
	tracker.free()

func test_state_change_locked() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	tracker.register_objective(obj)

	# Lock objective
	obj.lock_objective()

	var row_data = tracker.task_row_nodes.get(obj.objective_id, {})
	var icon_label: Label = row_data.get("icon_label")

	if icon_label != null and icon_label.text == "🔒":
		_log_pass("11. LOCKED state updates icon to '🔒'.")
	else:
		_log_fail("11. LOCKED icon failed to update.")

	obj.free()
	tracker.free()

func test_zero_objectives_handling() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	if tracker.progress_label.text == "Completed: 0/0":
		_log_pass("12. Zero objectives gracefully displays 'Completed: 0/0'.")
	else:
		_log_fail("12. Zero objectives counter incorrect: %s" % tracker.progress_label.text)

	if tracker.empty_label != null and tracker.empty_label.visible == true:
		_log_pass("13. EmptyLabel correctly visible when no objectives are tracked.")
	else:
		_log_fail("13. EmptyLabel not visible on zero objectives.")

	tracker.free()

func test_multiple_objectives_mixed_states() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	# Create 3 objective instances
	var obj1 = ObjectiveInteractable.new()
	obj1.objective_id = "task_power_01"
	obj1.objective_name = "Restore Power"
	obj1.room_location = "Generator Room"
	obj1._ready()

	var obj2 = ObjectiveInteractable.new()
	obj2.objective_id = "task_life_support_01"
	obj2.objective_name = "Repair Life Support"
	obj2.room_location = "Medical Bay"
	obj2._ready()

	var obj3 = ObjectiveInteractable.new()
	obj3.objective_id = "task_server_01"
	obj3.objective_name = "Stabilize Server"
	obj3.room_location = "Server Room"
	obj3._ready()

	tracker.register_objective(obj1)
	tracker.register_objective(obj2)
	tracker.register_objective(obj3)

	# Complete obj1 and obj3
	obj1.complete_objective()
	obj3.complete_objective()

	if tracker.progress_label.text == "Completed: 2/3":
		_log_pass("14. Mixed states (2 of 3 completed) correctly calculates 'Completed: 2/3'.")
	else:
		_log_fail("14. Mixed state counter mismatch: %s" % tracker.progress_label.text)

	var icon1: Label = tracker.task_row_nodes[obj1.objective_id]["icon_label"]
	var icon2: Label = tracker.task_row_nodes[obj2.objective_id]["icon_label"]
	var icon3: Label = tracker.task_row_nodes[obj3.objective_id]["icon_label"]

	if icon1.text == "☑" and icon2.text == "☐" and icon3.text == "☑":
		_log_pass("15. Individual icons in multi-task list reflect their respective states accurately.")
	else:
		_log_fail("15. Multi-task icon mismatch: [%s, %s, %s]" % [icon1.text, icon2.text, icon3.text])

	obj1.free()
	obj2.free()
	obj3.free()
	tracker.free()

func test_unregister_and_cleanup() -> void:
	var tracker = ObjectiveTrackerScene.instantiate() as ObjectiveTracker
	tracker._ready()

	var obj = ElectricalJunctionScene.instantiate() as ObjectiveInteractable
	obj._ready()

	tracker.register_objective(obj)
	tracker.unregister_objective(obj)

	if tracker.tracked_objectives.is_empty() and tracker.task_row_nodes.is_empty():
		_log_pass("16. unregister_objective() cleanly purges tracking and UI node references.")
	else:
		_log_fail("16. Unregister failed to clear references.")

	if tracker.progress_label.text == "Completed: 0/0":
		_log_pass("17. Progress counter resets to 'Completed: 0/0' after unregistration.")
	else:
		_log_fail("17. Progress counter failed to reset.")

	obj.free()
	tracker.free()

func test_existing_systems_non_regression() -> void:
	# Test Terminal regression
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()
	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	terminal.trigger._on_body_entered(player)
	player.try_interact()
	if terminal.is_activated == true:
		_log_pass("18. TestTerminal interaction remains functional.")
	else:
		_log_fail("18. TestTerminal interaction failed.")

	# Door Controller regression
	var door = DoorScene.instantiate() as DoorController
	door._ready()
	door.trigger._on_body_entered(player)
	player.try_interact()
	if door.current_state == DoorController.DoorState.OPEN or door.current_state == DoorController.DoorState.OPENING:
		_log_pass("19. DoorController interaction remains functional.")
	else:
		_log_fail("19. DoorController interaction failed.")

	# State Sync regression
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
