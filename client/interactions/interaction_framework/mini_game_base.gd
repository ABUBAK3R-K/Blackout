class_name MiniGameBase
extends Control

## Reusable base class for all mini-game interactions in BLACKOUT (Member 4).
##
## Provides interaction lifecycle management, input cancellation handling,
## progress tracking, and event signals for client-side task stations,
## blackout recovery panels, sabotage objectives, and meltdown emergency puzzles.

## 1. Interaction lifecycle states
enum InteractionState {
	IDLE,
	ACTIVE,
	COMPLETED,
	CANCELLED,
	INTERRUPTED,
	FAILED
}

## 2. Signals
signal interaction_started()
signal interaction_completed()
signal interaction_cancelled()
signal interaction_interrupted()
signal interaction_failed()
signal progress_changed(new_progress: float)

## 3. Basic properties
@export var task_id: String = ""
var progress: float = 0.0
var interaction_state: InteractionState = InteractionState.IDLE

## Optional metadata/reason for tracking why an interaction ended
var last_cancellation_reason: String = ""
var last_interruption_reason: String = ""
var last_failure_reason: String = ""

func _ready() -> void:
	# By default, mini-game overlays should block mouse clicks from hitting the world behind them
	mouse_filter = Control.MOUSE_FILTER_STOP

	# If the mini-game starts in IDLE, ensure it is initially hidden
	if interaction_state == InteractionState.IDLE:
		visible = false

## 10. Normal Godot input handling for Escape / ui_cancel
func _unhandled_input(event: InputEvent) -> void:
	if not is_active():
		return

	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel_interaction("cancelled_by_ui_cancel")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			cancel_interaction("cancelled_by_escape")

## 4. Basic Functions

## Starts the interaction session.
## Transitions state to ACTIVE, resets progress, makes the UI visible, and emits interaction_started.
func start_interaction(p_task_id: String = "") -> bool:
	# Completion must only happen once and cannot be restarted if already completed
	if interaction_state == InteractionState.COMPLETED:
		push_warning("[MiniGameBase] Cannot start: interaction is already COMPLETED.")
		return false

	if interaction_state == InteractionState.ACTIVE:
		push_warning("[MiniGameBase] Cannot start: interaction is already ACTIVE.")
		return false

	if not p_task_id.is_empty():
		task_id = p_task_id

	reset_state()
	interaction_state = InteractionState.ACTIVE
	visible = true

	interaction_started.emit()
	_on_interaction_started()
	return true

## Marks the interaction as successfully completed.
## 6. Completion must only happen once.
func complete_interaction() -> bool:
	if interaction_state != InteractionState.ACTIVE:
		push_warning("[MiniGameBase] Cannot complete: interaction is not ACTIVE (Current: %s)." % get_state_name())
		return false

	# Safely lock progress to 100%
	_apply_progress(1.0)

	interaction_state = InteractionState.COMPLETED
	interaction_completed.emit()
	_on_interaction_completed()

	# Cleanly close the mini-game UI
	visible = false
	return true

## Cancels the interaction (e.g. player closed the window or pressed Escape).
## 7. Cancellation must not trigger completion.
func cancel_interaction(reason: String = "cancelled") -> bool:
	if interaction_state != InteractionState.ACTIVE:
		return false

	last_cancellation_reason = reason
	interaction_state = InteractionState.CANCELLED
	progress = 0.0
	_reset_mini_game()
	visible = false

	interaction_cancelled.emit()
	_on_interaction_cancelled()
	return true

## Interrupts the interaction (e.g. player walked away, took damage, or blackout occurred).
## 7. Interruption must not trigger completion.
func interrupt_interaction(reason: String = "interrupted") -> bool:
	if interaction_state != InteractionState.ACTIVE:
		return false

	last_interruption_reason = reason
	interaction_state = InteractionState.INTERRUPTED
	progress = 0.0
	_reset_mini_game()
	visible = false

	interaction_interrupted.emit()
	_on_interaction_interrupted()
	return true

## Fails the interaction (e.g. puzzle error, wrong wire, timer expired).
func fail_interaction(reason: String = "failed") -> bool:
	if interaction_state != InteractionState.ACTIVE:
		return false

	last_failure_reason = reason
	interaction_state = InteractionState.FAILED
	progress = 0.0
	_reset_mini_game()
	visible = false

	interaction_failed.emit()
	_on_interaction_failed()
	return true

## 5. Safely updates progress clamped between 0.0 and 1.0.
func set_progress(new_progress: float) -> void:
	if interaction_state != InteractionState.ACTIVE:
		return

	var clamped_progress: float = clampf(new_progress, 0.0, 1.0)
	if not is_equal_approx(progress, clamped_progress):
		_apply_progress(clamped_progress)

func _apply_progress(new_progress: float) -> void:
	progress = new_progress
	progress_changed.emit(progress)
	_on_progress_changed(progress)

## 8. Cleanly resets/clears state when closed or re-initialized.
func reset_state() -> void:
	progress = 0.0
	interaction_state = InteractionState.IDLE
	_reset_mini_game()

## Helper Queries
func is_active() -> bool:
	return interaction_state == InteractionState.ACTIVE

func is_completed() -> bool:
	return interaction_state == InteractionState.COMPLETED

func is_idle() -> bool:
	return interaction_state == InteractionState.IDLE

func get_progress() -> float:
	return progress

func get_progress_percentage() -> float:
	return progress * 100.0

func get_state_name() -> String:
	match interaction_state:
		InteractionState.IDLE: return "IDLE"
		InteractionState.ACTIVE: return "ACTIVE"
		InteractionState.COMPLETED: return "COMPLETED"
		InteractionState.CANCELLED: return "CANCELLED"
		InteractionState.INTERRUPTED: return "INTERRUPTED"
		InteractionState.FAILED: return "FAILED"
		_: return "UNKNOWN"

## 9. Virtual Hooks for Inheriting Mini-Games to Override

func _on_interaction_started() -> void:
	pass

func _on_interaction_completed() -> void:
	pass

func _on_interaction_cancelled() -> void:
	pass

func _on_interaction_interrupted() -> void:
	pass

func _on_interaction_failed() -> void:
	pass

func _on_progress_changed(_new_progress: float) -> void:
	pass

func _reset_mini_game() -> void:
	pass
