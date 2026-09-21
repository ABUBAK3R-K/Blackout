class_name VignetteOverlay
extends CanvasLayer

## VignetteOverlay
## Renders a radial vignette over the camera view to create claustrophobic atmospheric tension.
## Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

@export var texture_rect: TextureRect
@export var fade_speed: float = 3.0

## Target alpha levels for different states
const ALPHA_NORMAL: float = 0.15
const ALPHA_WARNING: float = 0.4
const ALPHA_BLACKOUT: float = 0.95
const ALPHA_MELTDOWN: float = 0.85

var _target_alpha: float = ALPHA_NORMAL

func _ready() -> void:
	if not texture_rect:
		texture_rect = get_node_or_null("TextureRect")
	if texture_rect:
		texture_rect.modulate.a = _target_alpha

func _process(delta: float) -> void:
	if texture_rect and not is_equal_approx(texture_rect.modulate.a, _target_alpha):
		texture_rect.modulate.a = move_toward(texture_rect.modulate.a, _target_alpha, delta * fade_speed)

func set_intensity(target_alpha: float, immediate: bool = false) -> void:
	_target_alpha = clampf(target_alpha, 0.0, 1.0)
	if immediate and texture_rect:
		texture_rect.modulate.a = _target_alpha

func on_lighting_state_changed(state: int) -> void:
	match state:
		0: # NORMAL
			set_intensity(ALPHA_NORMAL)
		1: # BLACKOUT_WARNING
			set_intensity(ALPHA_WARNING)
		2: # BLACKOUT_ACTIVE
			set_intensity(ALPHA_BLACKOUT)
		3: # MELTDOWN
			set_intensity(ALPHA_MELTDOWN)

func get_current_alpha() -> float:
	return texture_rect.modulate.a if texture_rect else 0.0
