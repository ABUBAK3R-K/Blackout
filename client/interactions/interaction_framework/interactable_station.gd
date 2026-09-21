class_name InteractableStation
extends Area2D

## World interactable station trigger for BLACKOUT (Member 4 / Member 3 integration).
##
## Placed in facility rooms (tilemaps) to trigger Crew tasks, Blackout recovery panels,
## Impostor sabotage objectives, or Meltdown emergency consoles upon player proximity.

const InteractionController = preload("res://client/interactions/interaction_framework/interaction_controller.gd")

enum StationType {
	CREW_TASK,
	BLACKOUT_RECOVERY,
	IMPOSTOR_SABOTAGE,
	MELTDOWN_EMERGENCY
}

@export var station_type: StationType = StationType.CREW_TASK
@export var station_id: String = ""             ## Identifier (e.g. "generator", "repair_power", "steal_confidential_files")
@export var station_display_name: String = ""   ## Name displayed on HUD prompt (e.g. "Power Substation")
@export var interaction_key_name: String = "E"  ## Display prompt key

var is_player_in_range: bool = false
var prompt_label: Label = null
var interaction_controller: InteractionController = null

signal player_entered_station(station: InteractableStation)
signal player_exited_station(station: InteractableStation)
signal interaction_triggered(station: InteractableStation)

func _ready() -> void:
	monitoring = true
	monitorable = true

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	_setup_prompt_ui()

func _setup_prompt_ui() -> void:
	prompt_label = Label.new()
	prompt_label.name = "StationPrompt"
	prompt_label.text = "[ %s ] %s" % [interaction_key_name, station_display_name.to_upper()]
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.visible = false
	prompt_label.top_level = true # Draw above world sprites
	prompt_label.add_theme_color_override("font_color", Color(0.0, 0.95, 1.0))
	prompt_label.add_theme_font_size_override("font_size", 13)
	add_child(prompt_label)

func _process(_delta: float) -> void:
	if prompt_label != null and prompt_label.visible:
		prompt_label.global_position = global_position + Vector2(-80, -40)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range:
		return

	# Handle 'E' or 'ui_accept' (Space / Enter / Gamepad Cross)
	var is_interact_key = false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			is_interact_key = true
	elif event.is_action_pressed("ui_accept"):
		is_interact_key = true

	if is_interact_key:
		get_viewport().set_input_as_handled()
		trigger_interaction()

func trigger_interaction() -> void:
	interaction_triggered.emit(self)

	if interaction_controller == null:
		# Locate controller in tree if not explicitly wired
		interaction_controller = _find_interaction_controller()

	if interaction_controller != null:
		match station_type:
			StationType.CREW_TASK:
				interaction_controller.open_task_interaction(station_id, station_id)
			StationType.BLACKOUT_RECOVERY:
				interaction_controller.open_recovery_interaction(station_id)
			StationType.IMPOSTOR_SABOTAGE:
				interaction_controller.open_sabotage_interaction(station_id)
			StationType.MELTDOWN_EMERGENCY:
				interaction_controller.open_meltdown_interaction(station_id)

func _on_body_entered(body: Node2D) -> void:
	# Verify player entity (Member 3 player controller or tagged group "player")
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		is_player_in_range = true
		if prompt_label != null:
			prompt_label.text = "[ %s ] %s" % [interaction_key_name, station_display_name.to_upper()]
			prompt_label.visible = true
		player_entered_station.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.to_lower().contains("player"):
		is_player_in_range = false
		if prompt_label != null:
			prompt_label.visible = false
		player_exited_station.emit(self)

		if interaction_controller != null:
			interaction_controller.on_player_exited_trigger(station_id)

func _find_interaction_controller() -> InteractionController:
	var root = get_tree().get_root()
	return _search_controller_recursive(root)

func _search_controller_recursive(node: Node) -> InteractionController:
	if node is InteractionController:
		return node
	for child in node.get_children():
		var found = _search_controller_recursive(child)
		if found != null:
			return found
	return null
