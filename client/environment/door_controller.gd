class_name DoorController
extends Node2D

const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")

## 2D Sci-Fi Door Controller for BLACKOUT (Asterion Research Facility).
## Manages physical wall blocking collision, smooth sliding opening/closing transitions,
## visual status indicators, and integration with InteractableTrigger.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal door_opened()
signal door_closed()
signal door_state_changed(new_state: DoorState)

enum DoorState {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
	JAMMED
}

enum DoorOrientation {
	VERTICAL,
	HORIZONTAL
}

@export_group("Door Configuration")
## Unique identifier for this door instance (e.g. "door_hub_west").
@export var door_id: String = "door_facility"
## Descriptive name for UI and logs.
@export var door_name: String = "Facility Bulkhead Door"
## Door sliding orientation.
@export var orientation: DoorOrientation = DoorOrientation.VERTICAL
## Transition duration in seconds for full open/close cycle.
@export var transition_duration: float = 0.35
## Maximum slide travel distance in pixels for door panels.
@export var slide_distance: float = 40.0
## Initial state at level start.
@export var is_initially_open: bool = false

@export_group("Visual Dimensions")
## Total doorway width/span in pixels.
@export var doorway_span: float = 96.0
## Wall/door thickness in pixels.
@export var door_thickness: float = 16.0

@onready var obstacle_collider: StaticBody2D = $ObstacleCollider
@onready var collision_shape: CollisionShape2D = $ObstacleCollider/CollisionShape2D
@onready var trigger: InteractableTrigger = $InteractableTrigger
@onready var panel_a: Polygon2D = $Visual/PanelA
@onready var panel_b: Polygon2D = $Visual/PanelB
@onready var status_light: Polygon2D = $Visual/StatusLight
@onready var interaction_audio: InteractionAudio = get_node_or_null("InteractionAudio")

var current_state: DoorState = DoorState.CLOSED
var open_progress: float = 0.0 # 0.0 = Fully Closed, 1.0 = Fully Open
var active_tween: Tween = null

func _ready() -> void:
	_setup_door_components()
	if is_initially_open:
		_set_instant_state(DoorState.OPEN)
	else:
		_set_instant_state(DoorState.CLOSED)

	if trigger != null:
		trigger.interactable_id = door_id
		trigger.interacted.connect(_on_trigger_interacted)
		_update_prompt_text()

## Configures collision shape and trigger parameters to match orientation and span.
func _setup_door_components() -> void:
	if collision_shape != null:
		var rect := RectangleShape2D.new()
		if orientation == DoorOrientation.VERTICAL:
			rect.size = Vector2(door_thickness, doorway_span)
		else:
			rect.size = Vector2(doorway_span, door_thickness)
		collision_shape.shape = rect

	if trigger != null:
		trigger.interaction_radius = doorway_span * 0.75

## Called by InteractableTrigger when the local player presses E.
func _on_trigger_interacted(player: Node2D) -> void:
	toggle_door(player)

## Toggles between Open and Closed states. Safely ignores requests during active transitions or when jammed.
func toggle_door(player: Node2D = null) -> bool:
	if current_state == DoorState.CLOSED:
		return open_door(player)
	elif current_state == DoorState.OPEN:
		return close_door(player)
	elif current_state == DoorState.JAMMED:
		print("[DoorController] '%s' is jammed/malfunctioning. Cannot toggle." % door_name)
		return false
	return false

## Initiates the opening transition and immediately disables blocking collision.
func open_door(_player: Node2D = null) -> bool:
	if current_state != DoorState.CLOSED and current_state != DoorState.CLOSING:
		return false

	_set_state(DoorState.OPENING)
	_set_collision_enabled(false) # Disable physical obstacle immediately on opening

	if interaction_audio != null:
		interaction_audio.play_open_start()

	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_tween.tween_method(_apply_slide_progress, open_progress, 1.0, transition_duration * (1.0 - open_progress))
	active_tween.finished.connect(_on_open_completed)
	return true

## Initiates the closing transition and re-enables blocking collision upon finish.
func close_door(_player: Node2D = null) -> bool:
	if current_state != DoorState.OPEN and current_state != DoorState.OPENING:
		return false

	_set_state(DoorState.CLOSING)

	if interaction_audio != null:
		interaction_audio.play_close_start()

	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	active_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_tween.tween_method(_apply_slide_progress, open_progress, 0.0, transition_duration * open_progress)
	active_tween.finished.connect(_on_close_completed)
	return true

## Sets door into a jammed/malfunctioning state (used for Blackout sabotage / emergency locks).
func set_jammed(jammed: bool) -> void:
	if jammed:
		if current_state == DoorState.OPEN or current_state == DoorState.OPENING:
			_set_instant_state(DoorState.CLOSED)
		_set_state(DoorState.JAMMED)
		_set_collision_enabled(true)
		if interaction_audio != null:
			interaction_audio.play_jammed()
		if trigger != null:
			trigger.set_prompt("DOOR MALFUNCTION (LOCKED)")
			trigger.set_interactive(false)
	else:
		if current_state == DoorState.JAMMED:
			_set_instant_state(DoorState.CLOSED)
			if trigger != null:
				trigger.set_interactive(true)

func _on_open_completed() -> void:
	_set_state(DoorState.OPEN)
	if interaction_audio != null:
		interaction_audio.play_open_finish()
	door_opened.emit()
	_update_prompt_text()

func _on_close_completed() -> void:
	_set_state(DoorState.CLOSED)
	_set_collision_enabled(true) # Re-enable physical obstacle once fully closed
	if interaction_audio != null:
		interaction_audio.play_close_finish()
	door_closed.emit()
	_update_prompt_text()

## Applies sliding offset to visual door panels based on progress ratio (0.0 to 1.0).
func _apply_slide_progress(progress: float) -> void:
	open_progress = clamp(progress, 0.0, 1.0)
	var offset_px: float = open_progress * slide_distance

	if panel_a != null and panel_b != null:
		if orientation == DoorOrientation.VERTICAL:
			panel_a.position.y = -offset_px
			panel_b.position.y = offset_px
		else:
			panel_a.position.x = -offset_px
			panel_b.position.x = offset_px

	_update_status_light()

## Directly sets the door state without animation (for scene init and test harnesses).
func _set_instant_state(target_state: DoorState) -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

	match target_state:
		DoorState.OPEN:
			_apply_slide_progress(1.0)
			_set_collision_enabled(false)
			_set_state(DoorState.OPEN)
		DoorState.CLOSED:
			_apply_slide_progress(0.0)
			_set_collision_enabled(true)
			_set_state(DoorState.CLOSED)
		DoorState.JAMMED:
			set_jammed(true)
	_update_prompt_text()

func _set_state(new_state: DoorState) -> void:
	current_state = new_state
	_update_status_light()
	door_state_changed.emit(new_state)

func _set_collision_enabled(enabled: bool) -> void:
	if collision_shape != null:
		collision_shape.disabled = not enabled

func _update_prompt_text() -> void:
	if trigger == null:
		return

	match current_state:
		DoorState.CLOSED:
			trigger.set_prompt("Press E to Open Door")
		DoorState.OPEN:
			trigger.set_prompt("Press E to Close Door")
		DoorState.JAMMED:
			trigger.set_prompt("DOOR MALFUNCTION (LOCKED)")
		_:
			trigger.set_prompt("Door Moving...")

func _update_status_light() -> void:
	if status_light == null:
		return

	match current_state:
		DoorState.CLOSED:
			status_light.color = Color(0.9, 0.2, 0.2, 1.0) # Solid Red
		DoorState.OPEN:
			status_light.color = Color(0.2, 0.9, 0.4, 1.0) # Solid Green
		DoorState.OPENING, DoorState.CLOSING:
			status_light.color = Color(0.95, 0.75, 0.2, 1.0) # Amber / Yellow
		DoorState.JAMMED:
			status_light.color = Color(0.95, 0.1, 0.8, 1.0) # Magenta Alarm
