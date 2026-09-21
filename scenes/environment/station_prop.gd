class_name StationProp
extends RoomProp

## StationProp
## Interactive Station Prop Node with 4-State Visual State Machine,
## status LED lighting cues, and server event synchronization.
## Member 7 (Fatima - 2D Environment & Technical Artist).

enum VisualState {
	INTACT = 0,
	SABOTAGED = 1,
	BEING_REPAIRED = 2,
	RESTORED = 3
}

const STATE_NAMES: Dictionary = {
	VisualState.INTACT: "intact",
	VisualState.SABOTAGED: "sabotaged",
	VisualState.BEING_REPAIRED: "repairing",
	VisualState.RESTORED: "restored"
}

## Spec Color Constants for Status Lights
const COLOR_LED_GREEN: Color = Color(0.0, 0.902, 0.463, 1.0)     # #00e676
const COLOR_LED_RED: Color = Color(1.0, 0.090, 0.267, 1.0)       # #ff1744
const COLOR_LED_AMBER: Color = Color(1.0, 0.839, 0.0, 1.0)       # #ffd600
const COLOR_GLOW_INTACT: Color = Color(0.0, 0.9, 0.46, 0.3)
const COLOR_GLOW_SABOTAGED: Color = Color(1.0, 0.1, 0.2, 0.6)
const COLOR_GLOW_REPAIRING: Color = Color(1.0, 0.84, 0.0, 0.5)

@export var current_state: VisualState = VisualState.INTACT

## Texture Overrides per state (auto-loaded from station_id if not assigned)
@export var texture_intact: Texture2D
@export var texture_sabotaged: Texture2D
@export var texture_repairing: Texture2D
@export var texture_restored: Texture2D

## Visual Components
@export var status_light: PointLight2D
@export var status_indicator: Sprite2D

## Signals
signal visual_state_changed(old_state: int, new_state: int)
signal repair_progress_updated(progress: float)

func _init() -> void:
	is_interactable = true

func _ready() -> void:
	super._ready()
	_load_default_textures()
	_update_visual_state(current_state, true)

func _load_default_textures() -> void:
	if station_id.is_empty():
		return
		
	var base_path = "res://assets/sprites/stations/station_" + station_id + "_"
	if not texture_intact and ResourceLoader.exists(base_path + "intact.png"):
		texture_intact = load(base_path + "intact.png")
	if not texture_sabotaged and ResourceLoader.exists(base_path + "sabotaged.png"):
		texture_sabotaged = load(base_path + "sabotaged.png")
	if not texture_repairing and ResourceLoader.exists(base_path + "repairing.png"):
		texture_repairing = load(base_path + "repairing.png")
	if not texture_restored and ResourceLoader.exists(base_path + "restored.png"):
		texture_restored = load(base_path + "restored.png")

func set_visual_state(new_state: Variant) -> void:
	var target_enum: VisualState = VisualState.INTACT
	if typeof(new_state) == TYPE_INT:
		target_enum = new_state as VisualState
	elif typeof(new_state) == TYPE_STRING:
		match String(new_state).to_lower():
			"intact", "0":
				target_enum = VisualState.INTACT
			"sabotaged", "damaged", "1":
				target_enum = VisualState.SABOTAGED
			"repairing", "being_repaired", "active", "2":
				target_enum = VisualState.BEING_REPAIRED
			"restored", "completed", "3":
				target_enum = VisualState.RESTORED
	
	if target_enum != current_state:
		var old = current_state
		current_state = target_enum
		_update_visual_state(current_state)
		visual_state_changed.emit(int(old), int(current_state))

func get_visual_state() -> VisualState:
	return current_state

func get_visual_state_string() -> String:
	return STATE_NAMES.get(current_state, "intact")

func _update_visual_state(state: VisualState, force: bool = false) -> void:
	var target_tex: Texture2D = null
	match state:
		VisualState.INTACT:
			target_tex = texture_intact
			_apply_status_light(COLOR_LED_GREEN, 0.3)
		VisualState.SABOTAGED:
			target_tex = texture_sabotaged
			_apply_status_light(COLOR_LED_RED, 0.8)
		VisualState.BEING_REPAIRED:
			target_tex = texture_repairing
			_apply_status_light(COLOR_LED_AMBER, 0.6)
		VisualState.RESTORED:
			target_tex = texture_restored
			_apply_status_light(COLOR_LED_GREEN, 0.5)

	if sprite and target_tex:
		sprite.texture = target_tex

func _apply_status_light(color: Color, energy: float) -> void:
	if status_light:
		status_light.color = color
		status_light.energy = energy
	if status_indicator:
		status_indicator.modulate = color

func apply_repair_progress(progress: float) -> void:
	progress = clamp(progress, 0.0, 1.0)
	repair_progress_updated.emit(progress)
	if progress >= 1.0:
		set_visual_state(VisualState.RESTORED)
	elif progress > 0.0 and current_state == VisualState.SABOTAGED:
		set_visual_state(VisualState.BEING_REPAIRED)
