class_name RoundManager
extends RefCounted

## Central Round Lifecycle Manager for BLACKOUT.
## Coordinates server-authoritative round states (LOBBY, STARTING, ROLE_ASSIGNMENT, PLAYING, ENDING, RESULTS),
## validated deterministic state transitions, countdown execution, and clean round reset foundation.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

enum RoundState {
	LOBBY = 0,
	STARTING = 1,
	ROLE_ASSIGNMENT = 2,
	PLAYING = 3,
	ENDING = 4,
	RESULTS = 5
}

signal round_state_changed(previous_state: RoundState, new_state: RoundState)
signal starting_countdown_tick(remaining_time: float)
signal round_started()
signal round_ended(reason: String)
signal round_reset()

var current_state: RoundState = RoundState.LOBBY
var starting_duration: float = 3.0
var starting_time_remaining: float = 0.0
var round_end_reason: String = ""

func clear() -> void:
	current_state = RoundState.LOBBY
	starting_time_remaining = 0.0
	round_end_reason = ""

func is_lobby() -> bool:
	return current_state == RoundState.LOBBY

func is_starting() -> bool:
	return current_state == RoundState.STARTING

func is_role_assignment() -> bool:
	return current_state == RoundState.ROLE_ASSIGNMENT

func is_playing() -> bool:
	return current_state == RoundState.PLAYING

func is_ending() -> bool:
	return current_state == RoundState.ENDING

func is_results() -> bool:
	return current_state == RoundState.RESULTS

## Validates whether a state transition from `current_state` to `target_state` is legal.
func can_transition_to(target_state: RoundState) -> bool:
	if current_state == target_state:
		return false # Block duplicate / redundant transitions

	match current_state:
		RoundState.LOBBY:
			return target_state == RoundState.STARTING or target_state == RoundState.ROLE_ASSIGNMENT
		RoundState.STARTING:
			return target_state == RoundState.ROLE_ASSIGNMENT or target_state == RoundState.LOBBY
		RoundState.ROLE_ASSIGNMENT:
			return target_state == RoundState.PLAYING or target_state == RoundState.LOBBY
		RoundState.PLAYING:
			return target_state == RoundState.ENDING or target_state == RoundState.RESULTS or target_state == RoundState.LOBBY
		RoundState.ENDING:
			return target_state == RoundState.RESULTS or target_state == RoundState.LOBBY
		RoundState.RESULTS:
			return target_state == RoundState.LOBBY
		_:
			return false

## Attempts to transition to the target state with validation.
func transition_to(target_state: RoundState, reason: String = "") -> bool:
	if not can_transition_to(target_state):
		push_warning("[RoundManager] Invalid round state transition rejected: %s -> %s." % [
			get_state_name(current_state), get_state_name(target_state)
		])
		return false

	var prev = current_state
	current_state = target_state
	if not reason.is_empty():
		round_end_reason = reason

	print("[RoundManager] Round state transitioned: %s -> %s%s." % [
		get_state_name(prev), get_state_name(current_state),
		(" (Reason: %s)" % reason) if not reason.is_empty() else ""
	])

	if target_state == RoundState.STARTING:
		starting_time_remaining = starting_duration
	elif target_state == RoundState.PLAYING:
		round_started.emit()
	elif target_state == RoundState.ENDING:
		round_ended.emit(reason)
	elif target_state == RoundState.LOBBY:
		round_reset.emit()

	round_state_changed.emit(prev, current_state)
	return true

## Starts the round countdown from LOBBY.
func start_round_countdown(duration: float = 3.0) -> bool:
	starting_duration = duration
	return transition_to(RoundState.STARTING)

## Cancels starting countdown and returns to LOBBY (e.g. if player leaves).
func cancel_start(reason: String = "Countdown cancelled") -> bool:
	if current_state != RoundState.STARTING:
		return false
	starting_time_remaining = 0.0
	return transition_to(RoundState.LOBBY, reason)

## Triggers the end of the round.
func end_round(reason: String = "Round Concluded") -> bool:
	if current_state != RoundState.PLAYING:
		push_warning("[RoundManager] Cannot end round: not currently in PLAYING state (Current: %s)." % get_state_name(current_state))
		return false
	return transition_to(RoundState.ENDING, reason)

## Resets the round state back to LOBBY.
func reset_round() -> bool:
	if current_state == RoundState.LOBBY:
		return true
	return transition_to(RoundState.LOBBY, "Round Reset")

## Per-frame timer processing for STARTING countdown.
func tick(delta: float) -> void:
	if current_state == RoundState.STARTING:
		starting_time_remaining -= delta
		starting_countdown_tick.emit(max(0.0, starting_time_remaining))
		if starting_time_remaining <= 0.0:
			starting_time_remaining = 0.0
			transition_to(RoundState.ROLE_ASSIGNMENT)

## Returns readable uppercase string representation of a round state.
static func get_state_name(state: RoundState) -> String:
	match state:
		RoundState.LOBBY:
			return "LOBBY"
		RoundState.STARTING:
			return "STARTING"
		RoundState.ROLE_ASSIGNMENT:
			return "ROLE_ASSIGNMENT"
		RoundState.PLAYING:
			return "PLAYING"
		RoundState.ENDING:
			return "ENDING"
		RoundState.RESULTS:
			return "RESULTS"
		_:
			return "UNKNOWN"
