class_name VFXAlarmStrobe
extends Node2D

## VFXAlarmStrobe
## Radial pulsing red light flare and particle burst for emergency siren fixtures during Blackout.
## Member 7 (Fatima - 2D Environment & Technical Artist).

@export var particles: CPUParticles2D
@export var strobe_light: PointLight2D
@export var is_active: bool = true
@export var pulse_rate: float = 1.2

var _timer: float = 0.0

func _ready() -> void:
	z_index = 5
	if not particles:
		particles = get_node_or_null("CPUParticles2D")
	if not strobe_light:
		strobe_light = get_node_or_null("PointLight2D")
		
	if particles:
		var tex_path = "res://assets/vfx/alarm_flare_particle.png"
		if ResourceLoader.exists(tex_path):
			particles.texture = load(tex_path)
		particles.emitting = is_active

func set_strobe_active(active: bool) -> void:
	is_active = active
	if particles:
		particles.emitting = active
	if strobe_light:
		strobe_light.enabled = active

func _process(delta: float) -> void:
	if not is_active:
		return
	_timer += delta * pulse_rate * TAU
	var energy = lerp(0.3, 1.8, (sin(_timer) + 1.0) * 0.5)
	if strobe_light:
		strobe_light.energy = energy
