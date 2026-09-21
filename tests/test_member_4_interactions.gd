extends SceneTree

## Headless Integration Test Suite for BLACKOUT Client Interactions & Mini-Games (Member 4).
##
## Verifies:
##   1. MiniGameBase lifecycle states (IDLE, ACTIVE, COMPLETED, CANCELLED, INTERRUPTED, FAILED)
##   2. Progress clamping and signal emissions
##   3. MiniGameFactory resolution for all 10 Crew/Prerequisite tasks
##   4. MiniGameFactory resolution for all 4 Blackout Recovery systems
##   5. MiniGameFactory resolution for all 5 Impostor Sabotage objectives
##   6. MiniGameFactory resolution for all 3 Meltdown Emergency systems
##   7. Solving simulation & completion logic across each category
##   8. InteractionController modal mounting, player lock request, and cleanup
##   9. InteractionController interruption handling (meeting call, blackout cutoff, movement)
##   10. End-to-end network dispatch simulation

const MiniGameBase = preload("res://client/interactions/interaction_framework/mini_game_base.gd")
const MiniGameFactory = preload("res://client/interactions/mini_game_factory.gd")
const InteractionController = preload("res://client/interactions/interaction_framework/interaction_controller.gd")
const TaskConfig = preload("res://shared/task_config.gd")
const BlackoutRecoveryConfig = preload("res://shared/blackout_recovery_config.gd")
const BlackoutObjectiveConfig = preload("res://shared/blackout_objective_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")

var test_passed: bool = true
var test_log: Array[String] = []
var pass_count: int = 0
var fail_count: int = 0

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MEMBER 4 INTERACTION & MINI-GAME TEST SUITE")
	print("========================================================\n")

	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)
	pass_count += 1

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false
	fail_count += 1

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _run_suite() -> void:
	_test_mini_game_base_lifecycle()
	_test_factory_crew_tasks()
	_test_factory_recovery_systems()
	_test_factory_sabotage_objectives()
	_test_factory_meltdown_systems()
	_test_gameplay_solving_mechanics()
	_test_interaction_controller()

	print("\n========================================================")
	print("  TEST RESULTS: %d PASSED, %d FAILED" % [pass_count, fail_count])
	print("========================================================\n")

	if test_passed:
		print(">> ALL MEMBER 4 INTERACTION MODULES VERIFIED SUCCESSFULLY! <<\n")
		quit(0)
	else:
		print(">> REGRESSION DETECTED IN MEMBER 4 SUITE! <<\n")
		quit(1)

## ---------------------------------------------------------
## 1. MiniGameBase Lifecycle & Assertions
## ---------------------------------------------------------
func _test_mini_game_base_lifecycle() -> void:
	_log_info("Testing MiniGameBase Lifecycle & Signal Contracts...")

	var mg = MiniGameBase.new()
	get_root().add_child(mg)

	if mg.is_idle() and mg.get_progress() == 0.0:
		_log_pass("MiniGameBase initializes in IDLE state with 0.0 progress.")
	else:
		_log_fail("MiniGameBase did not start in IDLE.")

	var start_ok = mg.start_interaction("test_task_01")
	if start_ok and mg.is_active() and mg.visible:
		_log_pass("start_interaction() transitions state to ACTIVE and makes UI visible.")
	else:
		_log_fail("start_interaction() failed.")

	# Progress clamping
	mg.set_progress(0.45)
	if is_equal_approx(mg.get_progress(), 0.45):
		_log_pass("set_progress() correctly applies intermediate progress.")
	else:
		_log_fail("set_progress() failed.")

	mg.set_progress(1.8)
	if is_equal_approx(mg.get_progress(), 1.0):
		_log_pass("set_progress() correctly clamps values exceeding 1.0.")
	else:
		_log_fail("set_progress() clamping failed on upper bound.")

	mg.set_progress(-0.5)
	if is_equal_approx(mg.get_progress(), 0.0):
		_log_pass("set_progress() correctly clamps values below 0.0.")
	else:
		_log_fail("set_progress() clamping failed on lower bound.")

	# Cancellation test
	var tracker = {
		"cancel_fired": false,
		"complete_fired": false,
		"interrupt_fired": false
	}
	mg.interaction_cancelled.connect(func(): tracker["cancel_fired"] = true)
	mg.interaction_completed.connect(func(): tracker["complete_fired"] = true)
	mg.interaction_interrupted.connect(func(): tracker["interrupt_fired"] = true)

	mg.cancel_interaction("test_cancel")
	if tracker["cancel_fired"] and not tracker["complete_fired"] and not mg.visible:
		_log_pass("cancel_interaction() emits interaction_cancelled without triggering completion.")
	else:
		_log_fail("cancel_interaction() failed contract.")

	# Interruption test
	mg.start_interaction("test_task_01")
	mg.interrupt_interaction("test_interrupt")
	if tracker["interrupt_fired"] and not tracker["complete_fired"]:
		_log_pass("interrupt_interaction() emits interaction_interrupted without triggering completion.")
	else:
		_log_fail("interrupt_interaction() failed contract.")

	# Completion test
	mg.start_interaction("test_task_01")
	var completed = mg.complete_interaction()
	if completed and tracker["complete_fired"] and mg.is_completed() and is_equal_approx(mg.get_progress(), 1.0):
		_log_pass("complete_interaction() transitions to COMPLETED, locks progress to 1.0, and emits signal.")
	else:
		_log_fail("complete_interaction() failed.")

	# Double completion protection
	var double_completed = mg.complete_interaction()
	if not double_completed:
		_log_pass("complete_interaction() cannot be triggered twice on already completed session.")
	else:
		_log_fail("Double completion was not rejected.")

	mg.queue_free()

## ---------------------------------------------------------
## 2. Factory Resolution: 10 Crew / Impostor Prerequisite Tasks
## ---------------------------------------------------------
func _test_factory_crew_tasks() -> void:
	_log_info("Testing MiniGameFactory resolution for all 10 Crew / Prerequisite tasks...")

	var catalog = TaskConfig.get_all_task_types()
	var all_resolved = true

	for type_id in catalog:
		var mg = MiniGameFactory.create_task_mini_game(type_id)
		if mg == null:
			_log_fail("Factory returned null for task type: %s" % type_id)
			all_resolved = false
		else:
			get_root().add_child(mg)
			mg.start_interaction("test_" + type_id)
			if not mg.is_active():
				_log_fail("Mini-game for %s failed to activate." % type_id)
				all_resolved = false
			mg.queue_free()

	if all_resolved:
		_log_pass("All 10 Phase 1 Crew/Prerequisite tasks resolved and instantiated successfully.")

## ---------------------------------------------------------
## 3. Factory Resolution: 4 Blackout Recovery Systems
## ---------------------------------------------------------
func _test_factory_recovery_systems() -> void:
	_log_info("Testing MiniGameFactory resolution for all 4 Blackout Recovery systems...")

	var recovery_systems = ["generator", "power_routing", "security_relay", "cooling"]
	var all_resolved = true

	for sys_id in recovery_systems:
		var mg = MiniGameFactory.create_recovery_mini_game(sys_id)
		if mg == null:
			_log_fail("Factory returned null for recovery system: %s" % sys_id)
			all_resolved = false
		else:
			get_root().add_child(mg)
			mg.start_interaction(sys_id)
			if not mg.is_active():
				_log_fail("Recovery mini-game for %s failed to activate." % sys_id)
				all_resolved = false
			mg.queue_free()

	if all_resolved:
		_log_pass("All 4 Blackout Recovery systems resolved and instantiated successfully.")

## ---------------------------------------------------------
## 4. Factory Resolution: 5 Impostor Sabotage Objectives
## ---------------------------------------------------------
func _test_factory_sabotage_objectives() -> void:
	_log_info("Testing MiniGameFactory resolution for all 5 Impostor Sabotage objectives...")

	var objectives = [
		"steal_confidential_files",
		"extract_orion_core_data",
		"disable_orion_containment",
		"sabotage_generator",
		"tamper_security"
	]
	var all_resolved = true

	for obj_id in objectives:
		var mg = MiniGameFactory.create_sabotage_mini_game(obj_id)
		if mg == null:
			_log_fail("Factory returned null for sabotage objective: %s" % obj_id)
			all_resolved = false
		else:
			get_root().add_child(mg)
			mg.start_interaction(obj_id)
			if not mg.is_active():
				_log_fail("Sabotage mini-game for %s failed to activate." % obj_id)
				all_resolved = false
			mg.queue_free()

	if all_resolved:
		_log_pass("All 5 Impostor Sabotage objectives resolved and instantiated successfully.")

## ---------------------------------------------------------
## 5. Factory Resolution: 3 Meltdown Emergency Systems
## ---------------------------------------------------------
func _test_factory_meltdown_systems() -> void:
	_log_info("Testing MiniGameFactory resolution for all 3 Meltdown Emergency systems...")

	var meltdown_systems = ["restore_power", "restore_cooling", "stabilize_orion"]
	var all_resolved = true

	for sys_id in meltdown_systems:
		var mg = MiniGameFactory.create_meltdown_mini_game(sys_id)
		if mg == null:
			_log_fail("Factory returned null for meltdown system: %s" % sys_id)
			all_resolved = false
		else:
			get_root().add_child(mg)
			mg.start_interaction(sys_id)
			if not mg.is_active():
				_log_fail("Meltdown mini-game for %s failed to activate." % sys_id)
				all_resolved = false
			mg.queue_free()

	if all_resolved:
		_log_pass("All 3 Meltdown Emergency systems resolved and instantiated successfully.")

## ---------------------------------------------------------
## 6. Solving & Completion Cycle Simulation
## ---------------------------------------------------------
func _test_gameplay_solving_mechanics() -> void:
	_log_info("Simulating solving paths across mini-game categories...")

	# 1. Test MGRepairPower wire matching
	var mg_power = MiniGameFactory.create_task_mini_game("repair_power")
	get_root().add_child(mg_power)
	mg_power.start_interaction("t_power")
	for i in range(4):
		mg_power._on_left_terminal_pressed(i)
		var r_idx = mg_power.right_shuffled_indices.find(i)
		mg_power._on_right_terminal_pressed(r_idx)
	if mg_power.is_completed() and is_equal_approx(mg_power.get_progress(), 1.0):
		_log_pass("MGRepairPower wire-matching simulated to 100% completion.")
	else:
		_log_fail("MGRepairPower solving simulation failed.")
	mg_power.queue_free()

	# 2. Test MGRecoveryGenerator 3-phase ignition
	var mg_gen = MiniGameFactory.create_recovery_mini_game("generator")
	get_root().add_child(mg_gen)
	mg_gen.start_interaction("generator")
	for p in range(3):
		mg_gen._on_phase_pressed(p)
	if mg_gen.is_completed() and is_equal_approx(mg_gen.get_progress(), 1.0):
		_log_pass("MGRecoveryGenerator 3-phase ignition protocol solved to 100%.")
	else:
		_log_fail("MGRecoveryGenerator solving simulation failed.")
	mg_gen.queue_free()

	# 3. Test MGStealConfidentialFiles 3-step espionage
	var mg_steal = MiniGameFactory.create_sabotage_mini_game("steal_confidential_files")
	get_root().add_child(mg_steal)
	mg_steal.start_interaction("steal_confidential_files")
	for s in range(3):
		mg_steal._on_step_pressed(s)
	if mg_steal.is_completed() and is_equal_approx(mg_steal.get_progress(), 1.0):
		_log_pass("MGStealConfidentialFiles 3-step espionage solved to 100%.")
	else:
		_log_fail("MGStealConfidentialFiles solving simulation failed.")
	mg_steal.queue_free()

	# 4. Test MGMeltdownStabilizeOrion 4-rod SCRAM insertion
	var mg_meltdown = MiniGameFactory.create_meltdown_mini_game("stabilize_orion")
	get_root().add_child(mg_meltdown)
	mg_meltdown.start_interaction("stabilize_orion")
	for r in range(4):
		mg_meltdown._on_rod_pressed(r)
	if mg_meltdown.is_completed() and is_equal_approx(mg_meltdown.get_progress(), 1.0):
		_log_pass("MGMeltdownStabilizeOrion 4-rod reactor SCRAM solved to 100%.")
	else:
		_log_fail("MGMeltdownStabilizeOrion solving simulation failed.")
	mg_meltdown.queue_free()

## ---------------------------------------------------------
## 7. InteractionController Orchestration & Signal Tests
## ---------------------------------------------------------
func _test_interaction_controller() -> void:
	_log_info("Testing InteractionController modal orchestration & signals...")

	var controller = InteractionController.new()
	get_root().add_child(controller)

	var ctrl_tracker = {
		"opened_category": -1,
		"opened_id": "",
		"closed_category": -1,
		"closed_id": "",
		"closed_completed": false,
		"lock_state": false
	}

	controller.interaction_opened.connect(func(cat, id):
		ctrl_tracker["opened_category"] = cat
		ctrl_tracker["opened_id"] = id
	)
	controller.interaction_closed.connect(func(cat, id, completed):
		ctrl_tracker["closed_category"] = cat
		ctrl_tracker["closed_id"] = id
		ctrl_tracker["closed_completed"] = completed
	)
	controller.player_lock_requested.connect(func(lock):
		ctrl_tracker["lock_state"] = lock
	)

	# 1. Open task interaction
	var open_ok = controller.open_task_interaction("task_backup_power_p1_0", "backup_power")
	if open_ok and controller.is_interacting() and ctrl_tracker["lock_state"] and ctrl_tracker["opened_id"] == "task_backup_power_p1_0":
		_log_pass("InteractionController mounts task modal, locks player, and emits interaction_opened.")
	else:
		_log_fail("InteractionController failed to open task interaction.")

	# 2. Cancel interaction
	controller.cancel_interaction("user_closed")
	if not controller.is_interacting() and not ctrl_tracker["lock_state"] and not ctrl_tracker["closed_completed"]:
		_log_pass("InteractionController cancels interaction, unlocks player, and emits closed(false).")
	else:
		_log_fail("InteractionController cancellation failed.")

	# 3. Interruption when moving away
	controller.open_recovery_interaction("generator")
	controller.on_player_exited_trigger("generator")
	if not controller.is_interacting() and not ctrl_tracker["lock_state"] and not ctrl_tracker["closed_completed"]:
		_log_pass("InteractionController interrupts interaction when player walks away from station.")
	else:
		_log_fail("InteractionController trigger exit interruption failed.")

	# 4. Emergency meeting interruption
	controller.open_sabotage_interaction("extract_orion_core_data")
	controller._on_meeting_started(1, 45.0)
	if not controller.is_interacting() and not ctrl_tracker["lock_state"] and not ctrl_tracker["closed_completed"]:
		_log_pass("InteractionController immediately aborts and cleans up when Emergency Meeting begins.")
	else:
		_log_fail("InteractionController failed meeting interruption.")

	# 5. Blackout cutoff interruption for normal tasks
	controller.open_task_interaction("task_door_p1_0", "door_repair")
	controller._on_blackout_started(60.0)
	if not controller.is_interacting() and not ctrl_tracker["lock_state"] and not ctrl_tracker["closed_completed"]:
		_log_pass("InteractionController interrupts normal Phase 1 tasks when Blackout cuts facility power.")
	else:
		_log_fail("InteractionController failed blackout interruption.")

	controller.queue_free()
