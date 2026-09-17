class_name BlackoutManager
extends RefCounted

## Server-side manager for authoritative Blackout lifecycle, activation validation,
## countdown execution, and duration timing.

const NetworkConfig = preload("res://shared/network_config.gd")
const BlackoutConfig = preload("res://shared/blackout_config.gd")

signal countdown_started(duration: float)
signal countdown_tick(remaining_sec: float)
signal countdown_cancelled(reason: String)
signal blackout_started(duration: float)
signal blackout_tick(remaining_sec: float)
signal blackout_ended()

var blackout_duration: float = BlackoutConfig.DEFAULT_BLACKOUT_DURATION_SEC
var countdown_duration: float = BlackoutConfig.DEFAULT_COUNTDOWN_DURATION_SEC

var activation_count: int = 0
var is_countdown_active: bool = false
var is_blackout_active: bool = false

var countdown_remaining: float = 0.0
var blackout_start_time: float = 0.0
var blackout_end_time: float = 0.0

var impostor_peer_id: int = 0

func clear() -> void:
	activation_count = 0
	is_countdown_active = false
	is_blackout_active = false
	countdown_remaining = 0.0
	blackout_start_time = 0.0
	blackout_end_time = 0.0
	impostor_peer_id = 0
	blackout_duration = BlackoutConfig.DEFAULT_BLACKOUT_DURATION_SEC
	countdown_duration = BlackoutConfig.DEFAULT_COUNTDOWN_DURATION_SEC

func setup(
	p_impostor_peer: int,
	p_duration: float = BlackoutConfig.DEFAULT_BLACKOUT_DURATION_SEC,
	p_countdown: float = BlackoutConfig.DEFAULT_COUNTDOWN_DURATION_SEC
) -> void:
	clear()
	impostor_peer_id = p_impostor_peer
	blackout_duration = p_duration
	countdown_duration = p_countdown

func can_activate_blackout(peer_id: int, current_state: NetworkConfig.GameState) -> Dictionary:
	if current_state != NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		var msg = "Blackout activation rejected: current game state is %s (Expected: BLACKOUT_AVAILABLE)." % NetworkConfig.get_game_state_name(current_state)
		return {"allowed": false, "reason": msg}

	if activation_count >= BlackoutConfig.MAX_BLACKOUT_ACTIVATIONS:
		var msg = "Blackout activation rejected: maximum activations reached (%d/%d)." % [
			activation_count, BlackoutConfig.MAX_BLACKOUT_ACTIVATIONS
		]
		return {"allowed": false, "reason": msg}

	if is_countdown_active or is_blackout_active:
		var msg = "Blackout activation rejected: countdown or Blackout is already active."
		return {"allowed": false, "reason": msg}

	if peer_id != impostor_peer_id:
		var msg = "Blackout activation rejected: player %d is not the authorized Impostor." % peer_id
		return {"allowed": false, "reason": msg}

	return {"allowed": true, "reason": ""}

func request_activation(peer_id: int, current_state: NetworkConfig.GameState) -> Dictionary:
	var check = can_activate_blackout(peer_id, current_state)
	if not check.allowed:
		push_warning("[BlackoutManager] %s" % check.reason)
		return {"success": false, "error": check.reason}

	is_countdown_active = true
	countdown_remaining = countdown_duration

	print("[BlackoutManager] Valid activation request received from Impostor (Peer %d). Starting %.1f-second countdown..." % [
		peer_id, countdown_duration
	])

	countdown_started.emit(countdown_duration)
	return {"success": true, "countdown": countdown_duration}

## Authoritative timer tick processing for both countdown and active Blackout.
func tick(delta: float) -> void:
	if is_countdown_active:
		countdown_remaining -= delta
		countdown_tick.emit(max(0.0, countdown_remaining))

		if countdown_remaining <= 0.0:
			is_countdown_active = false
			countdown_remaining = 0.0
			_start_blackout()

	elif is_blackout_active:
		var current_time = Time.get_unix_time_from_system()
		var remaining = max(0.0, blackout_end_time - current_time)
		blackout_tick.emit(remaining)

		if current_time >= blackout_end_time:
			_end_blackout()

func _start_blackout() -> void:
	is_blackout_active = true
	activation_count += 1
	blackout_start_time = Time.get_unix_time_from_system()
	blackout_end_time = blackout_start_time + blackout_duration

	print("[BlackoutManager] BLACKOUT STARTED! Duration: %.1f seconds. End time: %.1f." % [
		blackout_duration, blackout_end_time
	])

	blackout_started.emit(blackout_duration)

func _end_blackout() -> void:
	is_blackout_active = false
	print("[BlackoutManager] BLACKOUT ENDED. Authoritative duration expired.")
	blackout_ended.emit()

func end_blackout_early(reason: String = "") -> void:
	if not is_blackout_active:
		return
	is_blackout_active = false
	if reason.is_empty():
		print("[BlackoutManager] BLACKOUT ENDED EARLY.")
	else:
		print("[BlackoutManager] BLACKOUT ENDED EARLY: %s" % reason)
	blackout_ended.emit()

func cancel_countdown(reason: String) -> void:
	if is_countdown_active:
		is_countdown_active = false
		countdown_remaining = 0.0
		print("[BlackoutManager] Blackout countdown cancelled: %s" % reason)
		countdown_cancelled.emit(reason)

func handle_impostor_disconnect(peer_id: int) -> void:
	if peer_id == impostor_peer_id:
		if is_countdown_active:
			cancel_countdown("Impostor disconnected during countdown.")
		elif is_blackout_active:
			print("[BlackoutManager] Impostor disconnected during active Blackout. Blackout timer continues.")

func get_remaining_blackout_time() -> float:
	if not is_blackout_active:
		return 0.0
	var current_time = Time.get_unix_time_from_system()
	return max(0.0, blackout_end_time - current_time)
