class_name TestTerminal
extends Node2D

const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")

## Interactive Test Terminal for BLACKOUT.
## Demonstrates proximity detection, contextual prompt UI, and E-key state toggling.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

@export var terminal_name: String = "Central Hub Terminal"
@export var is_activated: bool = false

@onready var trigger: InteractableTrigger = $InteractableTrigger
@onready var status_label: Label = $StatusLabel
@onready var screen_visual: Polygon2D = $Visual/Screen
@onready var interaction_audio: InteractionAudio = get_node_or_null("InteractionAudio")

func _ready() -> void:
	if trigger != null:
		trigger.interactable_id = "test_terminal_hub"
		trigger.prompt_text = "Press E to interact with Terminal"
		trigger.interacted.connect(_on_interacted)

	_update_terminal_visuals()

func _on_interacted(player: Node2D) -> void:
	is_activated = not is_activated
	print("[TestTerminal] '%s' toggled to state: %s by %s." % [
		terminal_name, "ACTIVATED" if is_activated else "STANDBY", player.name
	])

	if interaction_audio != null:
		if is_activated:
			interaction_audio.play_activate()
		else:
			interaction_audio.play_standby()

	_update_terminal_visuals()

func _update_terminal_visuals() -> void:
	if status_label != null:
		status_label.text = "TERMINAL: %s" % ("ONLINE [ACTIVE]" if is_activated else "STANDBY")
		status_label.set("theme_override_colors/font_color", Color(0.2, 0.9, 0.4, 1.0) if is_activated else Color(0.9, 0.7, 0.2, 1.0))

	if screen_visual != null:
		screen_visual.color = Color(0.2, 0.85, 0.4, 1.0) if is_activated else Color(0.85, 0.65, 0.15, 1.0)
