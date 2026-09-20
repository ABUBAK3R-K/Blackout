class_name VFXElectricalSparks
extends Node2D

## VFXElectricalSparks
## High-speed gravity-affected electrical spark burst particle system for damaged stations and sabotaged conduits.
## Member 7 (Fatima - 2D Environment & Technical Artist).

@export var particles: CPUParticles2D
@export var auto_burst_interval: float = 2.5
@export var is_looping: bool = true

var _timer: float = 0.0

func _ready() -> void:
	if not particles:
		particles = get_node_or_null("CPUParticles2D")
		
	if particles:
		particles.emitting = false
		var tex_path = "res://assets/vfx/spark_particle.png"
		if ResourceLoader.exists(tex_path):
			particles.texture = load(tex_path)

func trigger_spark_burst(count: int = 8) -> void:
	if particles:
		particles.amount = count
		particles.restart()
		particles.emitting = true

func set_emitting_continuous(active: bool) -> void:
	is_looping = active
	if particles:
		particles.emitting = active

func _process(delta: float) -> void:
	if not is_looping:
		return
	_timer += delta
	if _timer >= auto_burst_interval:
		_timer = 0.0
		trigger_spark_burst()
