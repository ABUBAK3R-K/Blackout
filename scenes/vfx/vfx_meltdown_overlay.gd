class_name VFXMeltdownOverlay
extends CanvasLayer

## VFXMeltdownOverlay
## Full-screen heat distortion and thermal haze overlay controller for Meltdown sequence.
## Member 7 (Fatima - 2D Environment & Technical Artist).

@export var color_rect: ColorRect
@export var is_active: bool = false
@export var distortion_intensity: float = 0.0

var _shader_mat: ShaderMaterial

func _ready() -> void:
	layer = 10
	if not color_rect:
		color_rect = get_node_or_null("ColorRect")
		
	if color_rect:
		if color_rect.material is ShaderMaterial:
			_shader_mat = color_rect.material as ShaderMaterial
		else:
			var shader_res = load("res://assets/vfx/meltdown_distortion.gdshader")
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader_res
			color_rect.material = _shader_mat
			
	set_active(is_active)
	set_distortion_intensity(distortion_intensity)

func set_active(active: bool) -> void:
	is_active = active
	visible = active
	if _shader_mat:
		_shader_mat.set_shader_parameter("is_active", active)

func set_distortion_intensity(intensity: float) -> void:
	distortion_intensity = clamp(intensity, 0.0, 1.0)
	if _shader_mat:
		_shader_mat.set_shader_parameter("distortion_intensity", distortion_intensity)

func set_meltdown_time_remaining(time_sec: float, max_time_sec: float = 300.0) -> void:
	# Scales from 0.1 at 300s remaining to 1.0 at 0s remaining
	var progress = 1.0 - clamp(time_sec / max_time_sec, 0.0, 1.0)
	var intensity = lerp(0.1, 1.0, progress)
	set_active(true)
	set_distortion_intensity(intensity)
