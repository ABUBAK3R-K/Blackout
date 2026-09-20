class_name VFXCoolantSteam
extends Node2D

## VFXCoolantSteam
## Rising coolant vapor and expanding steam cloud particle preset for damaged manifolds and reactor cooling units.
## Member 7 (Fatima - 2D Environment & Technical Artist).

@export var particles: CPUParticles2D
@export var is_emitting: bool = true

func _ready() -> void:
	z_index = 5
	if not particles:
		particles = get_node_or_null("CPUParticles2D")
		
	if particles:
		var tex_path = "res://assets/vfx/smoke_puff_particle.png"
		if ResourceLoader.exists(tex_path):
			particles.texture = load(tex_path)
		particles.emitting = is_emitting

func start_steam() -> void:
	is_emitting = true
	if particles:
		particles.emitting = true

func stop_steam() -> void:
	is_emitting = false
	if particles:
		particles.emitting = false

func set_intensity(ratio: float) -> void:
	ratio = clamp(ratio, 0.1, 2.0)
	if particles:
		particles.amount = int(12 * ratio)
		particles.initial_velocity_min = 20.0 * ratio
		particles.initial_velocity_max = 45.0 * ratio
