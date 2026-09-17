class_name InteractableTrigger
extends Area2D

## Reusable 2D Proximity Interaction Trigger for BLACKOUT.
## Uses Area2D body detection to register nearby local players, manage contextual
## interaction prompts, and execute interaction callbacks (Terminals, Doors, Switches, Objectives).
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal player_entered(player: Node2D)
signal player_exited(player: Node2D)
signal interacted(player: Node2D)

@export_group("Interaction Settings")
## Unique identifier for this interactable instance.
@export var interactable_id: String = "generic_interactable"

## Text prompt displayed when the player enters interaction proximity.
@export var prompt_text: String = "Press E to interact"

## Flag indicating whether this trigger is currently enabled for interaction.
@export var is_interactive: bool = true

## Radius of the interaction detection circle in pixels.
@export var interaction_radius: float = 48.0

## Automatically shows/hides the child PromptLabel when a local player is in range.
@export var auto_show_prompt: bool = true

@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")

## Current local player in range (null if none).
var current_player: Node2D = null

func _ready() -> void:
	# Configure Area2D collision layer to detect player bodies (Layer 1)
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false

	_setup_collision_shape()
	_setup_prompt_label()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

## Configures or updates the child CircleShape2D radius.
func _setup_collision_shape() -> void:
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)

	if collision_shape.shape == null or not (collision_shape.shape is CircleShape2D):
		var circle := CircleShape2D.new()
		circle.radius = interaction_radius
		collision_shape.shape = circle
	else:
		(collision_shape.shape as CircleShape2D).radius = interaction_radius

## Configures the floating prompt label above the interactable.
func _setup_prompt_label() -> void:
	if prompt_label == null:
		prompt_label = Label.new()
		prompt_label.name = "PromptLabel"
		prompt_label.anchors_preset = Control.PRESET_CENTER_TOP
		prompt_label.offset_left = -100.0
		prompt_label.offset_top = -45.0
		prompt_label.offset_right = 100.0
		prompt_label.offset_bottom = -25.0
		prompt_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		prompt_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt_label.set("theme_override_font_sizes/font_size", 12)
		prompt_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.4, 1.0))
		prompt_label.set("theme_override_colors/font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
		prompt_label.set("theme_override_constants/outline_size", 3)
		add_child(prompt_label)

	prompt_label.text = prompt_text
	prompt_label.visible = false

## Updates the prompt text dynamically.
func set_prompt(new_prompt: String) -> void:
	prompt_text = new_prompt
	if prompt_label != null:
		prompt_label.text = prompt_text

## Enables or disables interactivity and hides prompt if disabled.
func set_interactive(state: bool) -> void:
	is_interactive = state
	if not is_interactive and prompt_label != null:
		prompt_label.visible = false

## Executes interaction if valid. Returns true if interaction occurred.
func interact(player: Node2D) -> bool:
	if not is_interactive or player == null:
		return false

	print("[InteractableTrigger] Interaction triggered on '%s' by %s." % [
		interactable_id, player.name
	])
	interacted.emit(player)
	return true

## Checks whether a given player node is currently allowed to interact.
func can_player_interact(player: Node2D) -> bool:
	return is_interactive and player != null and player == current_player

func _on_body_entered(body: Node2D) -> void:
	if not is_interactive:
		return

	# Only process local players to prevent remote clients from triggering local prompts
	if body.has_method("register_nearby_interactable"):
		if body.get("is_local_player") == true:
			current_player = body
			body.register_nearby_interactable(self)

			if auto_show_prompt and prompt_label != null:
				prompt_label.text = prompt_text
				prompt_label.visible = true

			player_entered.emit(body)

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		if body.has_method("unregister_nearby_interactable"):
			body.unregister_nearby_interactable(self)

		current_player = null

		if prompt_label != null:
			prompt_label.visible = false

		player_exited.emit(body)
