class_name PlayerFlashlight2D
extends Node2D

## PlayerFlashlight2D
## Attachable 2D flashlight component providing a forward 70° spotlight beam and subtle personal radial glow.
## Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

## Light references
@export var beam_light: PointLight2D
@export var halo_light: PointLight2D

## Settings per Technical Art Spec
const COLOR_FLASHLIGHT_BEAM: Color = Color(0.94, 0.96, 1.0, 1.0) # #f0f4ff
const COLOR_HALO: Color = Color(0.85, 0.9, 1.0, 0.6) # Soft proximity illumination

@export var is_flashlight_on: bool = true:
	set(value):
		is_flashlight_on = value
		_update_visibility()

@export var beam_energy: float = 1.2
@export var halo_energy: float = 0.4
@export var rotation_smooth_speed: float = 12.0

var _target_rotation: float = 0.0

func _ready() -> void:
	if not beam_light:
		beam_light = get_node_or_null("BeamLight")
	if not halo_light:
		halo_light = get_node_or_null("HaloLight")
		
	_apply_initial_parameters()
	_update_visibility()

func _process(delta: float) -> void:
	if is_flashlight_on:
		# Smoothly rotate towards target angle
		rotation = lerp_angle(rotation, _target_rotation, delta * rotation_smooth_speed)

## Aim the flashlight in a specific 2D direction vector
func aim_at_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		_target_rotation = direction.angle()

## Aim the flashlight at a global world coordinate (e.g. mouse cursor)
func aim_at_position(target_global_pos: Vector2) -> void:
	var dir = (target_global_pos - global_position).normalized()
	aim_at_direction(dir)

## Instantly snap rotation without smoothing
func snap_to_direction(direction: Vector2) -> void:
	if direction.length_squared() > 0.01:
		_target_rotation = direction.angle()
		rotation = _target_rotation

func set_flashlight_active(active: bool) -> void:
	is_flashlight_on = active

func _apply_initial_parameters() -> void:
	if beam_light:
		beam_light.color = COLOR_FLASHLIGHT_BEAM
		beam_light.energy = beam_energy
		beam_light.shadow_enabled = true
	if halo_light:
		halo_light.color = COLOR_HALO
		halo_light.energy = halo_energy
		halo_light.shadow_enabled = false

func _update_visibility() -> void:
	if beam_light:
		beam_light.enabled = is_flashlight_on
	if halo_light:
		halo_light.enabled = is_flashlight_on
