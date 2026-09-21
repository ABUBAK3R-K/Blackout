class_name GameCamera
extends Camera2D

## Reusable 2D Game Camera for BLACKOUT.
## Handles smooth local player tracking, configurable viewport/map limits,
## and a trauma/decay-based screen-shake system for alarms and emergency events.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

@export_group("Follow Target Settings")
## Target node to follow if camera is not a direct child of the player.
@export var target: Node2D = null
## Speed at which camera lerps towards target (used when tracking external target).
@export var smooth_speed: float = 8.0

@export_group("Screen Shake Settings")
## Maximum pixel offset during maximum shake trauma.
@export var max_shake_offset: Vector2 = Vector2(25.0, 25.0)

## Current shake intensity (trauma magnitude).
var shake_intensity: float = 0.0
## Total duration for the active shake event.
var shake_duration: float = 0.0
## Remaining time for active shake.
var shake_timer: float = 0.0

func _ready() -> void:
	# Enable Godot's built-in position smoothing for buttery-smooth follow
	position_smoothing_enabled = true
	position_smoothing_speed = smooth_speed

func _process(delta: float) -> void:
	# 1. Follow external target if camera is a standalone node
	if target != null and get_parent() != target:
		global_position = global_position.lerp(target.global_position, delta * smooth_speed)

	# 2. Process screen shake decay and offset
	_process_shake(delta)

## Triggers a screen shake with configurable intensity and duration.
## intensity: Shake strength in pixels (default 10.0).
## duration: Duration of shake in seconds (default 0.4s).
func trigger_shake(intensity: float = 10.0, duration: float = 0.4) -> void:
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = max(0.01, duration)
	shake_timer = shake_duration

## Updates shake offset with quadratic decay over time.
func _process_shake(delta: float) -> void:
	if shake_timer > 0.0:
		shake_timer -= delta
		if shake_timer <= 0.0:
			offset = Vector2.ZERO
			shake_intensity = 0.0
			shake_duration = 0.0
			shake_timer = 0.0
			return

		var progress: float = clamp(shake_timer / shake_duration, 0.0, 1.0)
		var current_strength: float = shake_intensity * (progress * progress)

		offset = Vector2(
			randf_range(-1.0, 1.0) * current_strength,
			randf_range(-1.0, 1.0) * current_strength
		)
	else:
		offset = Vector2.ZERO
		shake_intensity = 0.0
		shake_duration = 0.0
		shake_timer = 0.0

## Sets map boundary limits for the camera viewport (left, top, right, bottom).
func set_camera_limits(p_left: int, p_top: int, p_right: int, p_bottom: int) -> void:
	limit_left = p_left
	limit_top = p_top
	limit_right = p_right
	limit_bottom = p_bottom

## Resets camera boundary limits to unbounded default.
func clear_camera_limits() -> void:
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
