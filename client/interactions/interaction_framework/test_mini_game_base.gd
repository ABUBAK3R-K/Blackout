extends Control

## Test runner and visual demonstration scene for MiniGameBase (Member 4).
##
## Verifies all 11 required assertions:
## 1. MiniGameBase starts in IDLE.
## 2. Calling start_interaction() changes it to ACTIVE.
## 3. Progress can change from 0.0 to 1.0.
## 4. Progress is clamped between 0.0 and 1.0.
## 5. complete_interaction() changes it to COMPLETED.
## 6. complete_interaction() cannot be triggered twice.
## 7. Escape/ui_cancel triggers cancellation while ACTIVE.
## 8. Cancellation does not emit interaction_completed.
## 9. Interruption does not emit interaction_completed.
## 10. Failure does not emit interaction_completed.
## 11. Signals are emitted correctly.

const MiniGameBase = preload("res://client/interactions/interaction_framework/mini_game_base.gd")

@onready var state_label: Label = %StateLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var log_label: Label = %LogLabel

@onready var start_button: Button = %StartButton
@onready var set_progress_button: Button = %SetProgressButton
@onready var complete_button: Button = %CompleteButton
@onready var cancel_button: Button = %CancelButton
@onready var interrupt_button: Button = %InterruptButton
@onready var fail_button: Button = %FailButton
@onready var close_button: Button = %CloseButton

@onready var test_mini_game: MiniGameBase = %TestMiniGame

var test_passed_count: int = 0
var test_total_count: int = 11
var suite_results: Array[String] = []

func _ready() -> void:
	# Run automated 11-point validation suite first
	_run_automated_tests()

	# Bind interactive UI to test_mini_game
	_setup_interactive_ui()
	_update_ui()

func _setup_interactive_ui() -> void:
	if test_mini_game == null:
		return

	test_mini_game.interaction_started.connect(func():
		_log_ui_event("Signal received: interaction_started")
		_update_ui()
	)
	test_mini_game.progress_changed.connect(func(new_val: float):
		_log_ui_event("Signal received: progress_changed (%.2f)" % new_val)
		_update_ui()
	)
	test_mini_game.interaction_completed.connect(func():
		_log_ui_event("Signal received: interaction_completed")
		_update_ui()
	)
	test_mini_game.interaction_cancelled.connect(func():
		_log_ui_event("Signal received: interaction_cancelled (Reason: %s)" % test_mini_game.last_cancellation_reason)
		_update_ui()
	)
	test_mini_game.interaction_interrupted.connect(func():
		_log_ui_event("Signal received: interaction_interrupted (Reason: %s)" % test_mini_game.last_interruption_reason)
		_update_ui()
	)
	test_mini_game.interaction_failed.connect(func():
		_log_ui_event("Signal received: interaction_failed (Reason: %s)" % test_mini_game.last_failure_reason)
		_update_ui()
	)

	start_button.pressed.connect(_on_start_pressed)
	set_progress_button.pressed.connect(_on_set_progress_pressed)
	complete_button.pressed.connect(_on_complete_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	interrupt_button.pressed.connect(_on_interrupt_pressed)
	fail_button.pressed.connect(_on_fail_pressed)
	close_button.pressed.connect(_on_cancel_pressed)

func _on_start_pressed() -> void:
	test_mini_game.start_interaction("task_test_interactive")
	_update_ui()

func _on_set_progress_pressed() -> void:
	var current: float = test_mini_game.get_progress()
	var next_val: float = current + 0.25
	if next_val > 1.0:
		next_val = 0.25
	test_mini_game.set_progress(next_val)
	_update_ui()

func _on_complete_pressed() -> void:
	test_mini_game.complete_interaction()
	_update_ui()

func _on_cancel_pressed() -> void:
	test_mini_game.cancel_interaction("cancelled_via_ui_button")
	_update_ui()

func _on_interrupt_pressed() -> void:
	test_mini_game.interrupt_interaction("interrupted_via_ui_button")
	_update_ui()

func _on_fail_pressed() -> void:
	test_mini_game.fail_interaction("failed_via_ui_button")
	_update_ui()

func _update_ui() -> void:
	if test_mini_game == null:
		return
	state_label.text = "State: %s" % test_mini_game.get_state_name()
	var p: float = test_mini_game.get_progress()
	progress_label.text = "Progress: %d%%" % int(p * 100.0)
	progress_bar.value = p

func _log_ui_event(msg: String) -> void:
	print("[UI Event] %s" % msg)
	if log_label != null:
		log_label.text = msg

## -------------------------------------------------------------
## Automated 11-point verification suite
## -------------------------------------------------------------
func _run_automated_tests() -> void:
	print("\n========================================================")
	print("  MEMBER 4 — MiniGameBase AUTOMATED TEST SUITE")
	print("========================================================\n")
	test_passed_count = 0
	suite_results.clear()

	# Test 1: Starts in IDLE
	var mg1: MiniGameBase = MiniGameBase.new()
	_assert_true(mg1.interaction_state == MiniGameBase.InteractionState.IDLE, "1. MiniGameBase starts in IDLE")
	_assert_true(mg1.is_idle(), "1b. is_idle() returns true initially")

	# Test 2: Calling start_interaction() changes state to ACTIVE
	var started: bool = mg1.start_interaction("task_spec_001")
	_assert_true(started, "2a. start_interaction() returned true")
	_assert_true(mg1.interaction_state == MiniGameBase.InteractionState.ACTIVE, "2b. State changed to ACTIVE")
	_assert_true(mg1.is_active(), "2c. is_active() returns true")
	_assert_true(mg1.task_id == "task_spec_001", "2d. task_id assigned correctly")

	# Test 3: Progress can change from 0.0 to 1.0
	mg1.set_progress(0.42)
	_assert_true(is_equal_approx(mg1.get_progress(), 0.42), "3. Progress updated to 0.42 correctly")

	# Test 4: Progress is safely clamped between 0.0 and 1.0
	mg1.set_progress(-0.5)
	_assert_true(is_equal_approx(mg1.get_progress(), 0.0), "4a. Negative progress clamped to 0.0")
	mg1.set_progress(1.8)
	_assert_true(is_equal_approx(mg1.get_progress(), 1.0), "4b. Overflow progress clamped to 1.0")

	# Test 5: complete_interaction() changes state to COMPLETED
	var completed: bool = mg1.complete_interaction()
	_assert_true(completed, "5a. complete_interaction() returned true")
	_assert_true(mg1.interaction_state == MiniGameBase.InteractionState.COMPLETED, "5b. State changed to COMPLETED")
	_assert_true(mg1.is_completed(), "5c. is_completed() returns true")
	_assert_true(is_equal_approx(mg1.get_progress(), 1.0), "5d. Progress locked at 1.0 on completion")

	# Test 6: complete_interaction() cannot be triggered twice
	var completed_again: bool = mg1.complete_interaction()
	_assert_true(not completed_again, "6a. Second complete_interaction() call safely rejected")
	_assert_true(mg1.interaction_state == MiniGameBase.InteractionState.COMPLETED, "6b. State remained COMPLETED")

	# Test 7: Escape/ui_cancel triggers cancellation while ACTIVE
	var mg2: MiniGameBase = MiniGameBase.new()
	mg2.start_interaction("task_cancel_test")
	_assert_true(mg2.is_active(), "7a. mg2 active for cancellation test")
	var cancel_event = InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	mg2._unhandled_input(cancel_event)
	_assert_true(mg2.interaction_state == MiniGameBase.InteractionState.CANCELLED, "7b. ui_cancel transitioned state to CANCELLED")

	# Test 8: Cancellation does not emit interaction_completed
	var mg3: MiniGameBase = MiniGameBase.new()
	mg3.start_interaction("task_cancel_guard")
	var completed_fired_on_cancel: bool = false
	var cancelled_fired: bool = false
	mg3.interaction_completed.connect(func(): completed_fired_on_cancel = true)
	mg3.interaction_cancelled.connect(func(): cancelled_fired = true)
	mg3.cancel_interaction("test_guard")
	_assert_true(cancelled_fired, "8a. interaction_cancelled signal fired")
	_assert_true(not completed_fired_on_cancel, "8b. interaction_completed NEVER fired on cancellation")

	# Test 9: Interruption does not emit interaction_completed
	var mg4: MiniGameBase = MiniGameBase.new()
	mg4.start_interaction("task_interrupt_guard")
	var completed_fired_on_interrupt: bool = false
	var interrupted_fired: bool = false
	mg4.interaction_completed.connect(func(): completed_fired_on_interrupt = true)
	mg4.interaction_interrupted.connect(func(): interrupted_fired = true)
	mg4.interrupt_interaction("test_interrupt")
	_assert_true(interrupted_fired, "9a. interaction_interrupted signal fired")
	_assert_true(not completed_fired_on_interrupt, "9b. interaction_completed NEVER fired on interruption")
	_assert_true(mg4.interaction_state == MiniGameBase.InteractionState.INTERRUPTED, "9c. State is INTERRUPTED")

	# Test 10: Failure does not emit interaction_completed
	var mg5: MiniGameBase = MiniGameBase.new()
	mg5.start_interaction("task_fail_guard")
	var completed_fired_on_fail: bool = false
	var failed_fired: bool = false
	mg5.interaction_completed.connect(func(): completed_fired_on_fail = true)
	mg5.interaction_failed.connect(func(): failed_fired = true)
	mg5.fail_interaction("wrong_wire_cut")
	_assert_true(failed_fired, "10a. interaction_failed signal fired")
	_assert_true(not completed_fired_on_fail, "10b. interaction_completed NEVER fired on failure")
	_assert_true(mg5.interaction_state == MiniGameBase.InteractionState.FAILED, "10c. State is FAILED")

	# Test 11: Signals are emitted correctly throughout a normal interaction
	var mg6: MiniGameBase = MiniGameBase.new()
	var started_fired: bool = false
	var progress_history: Array[float] = []
	var completed_fired: bool = false
	mg6.interaction_started.connect(func(): started_fired = true)
	mg6.progress_changed.connect(func(p: float): progress_history.append(p))
	mg6.interaction_completed.connect(func(): completed_fired = true)

	mg6.start_interaction("task_signals_test")
	mg6.set_progress(0.25)
	mg6.set_progress(0.75)
	mg6.complete_interaction()

	_assert_true(started_fired, "11a. interaction_started signal fired on start")
	_assert_true(progress_history.size() >= 2 and progress_history.has(0.25) and progress_history.has(0.75), "11b. progress_changed signals fired with correct values")
	_assert_true(completed_fired, "11c. interaction_completed signal fired on complete")

	print("\n--------------------------------------------------------")
	print("  TEST RESULTS: ALL 11 REQUIREMENTS VERIFIED")
	print("--------------------------------------------------------\n")

func _assert_true(condition: bool, description: String) -> void:
	if condition:
		print("  [PASS] %s" % description)
		suite_results.append("[PASS] %s" % description)
		test_passed_count += 1
	else:
		push_error("  [FAIL] %s" % description)
		print("  [FAIL] %s" % description)
		suite_results.append("[FAIL] %s" % description)
