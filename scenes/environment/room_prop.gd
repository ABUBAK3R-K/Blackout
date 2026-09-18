class_name RoomProp
extends StaticBody2D

## RoomProp
## Standardized 2D environmental fixture and interactive prop node with Y-sort sorting,
## solid obstacle collision (Layer 1), and optional station interaction triggers (Layer 3).
## Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

@export var prop_name: String = "RoomProp"
@export var room_id: String = ""
@export var station_id: String = ""
@export var is_interactable: bool = false

## Visuals & Collision
@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D
@export var interaction_area: Area2D
@export var interaction_shape: CollisionShape2D

## Proximity highlight
var _is_highlighted: bool = false
const COLOR_NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)
const COLOR_HIGHLIGHT_MODULATE: Color = Color(1.2, 1.15, 0.9, 1.0)

signal player_entered_interaction_zone(player_node: Node2D, station_id: String)
signal player_exited_interaction_zone(player_node: Node2D, station_id: String)

func _ready() -> void:
	# Layer 1 = World / Obstacles (Physics Mask bit 1 = 1)
	collision_layer = 1
	collision_mask = 0
	y_sort_enabled = true
	z_index = 1
	
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
	if not interaction_area:
		interaction_area = get_node_or_null("InteractionArea")
		
	_setup_interaction_area()

func set_highlight(active: bool) -> void:
	_is_highlighted = active
	if sprite:
		sprite.modulate = COLOR_HIGHLIGHT_MODULATE if active else COLOR_NORMAL_MODULATE

func _setup_interaction_area() -> void:
	if is_interactable:
		if not interaction_area:
			interaction_area = Area2D.new()
			interaction_area.name = "InteractionArea"
			add_child(interaction_area)
			
		# Layer 3 = Stations / Interactables (Physics bit 3 = 4)
		# Mask Layer 2 = Players (Physics bit 2 = 2)
		interaction_area.collision_layer = 4
		interaction_area.collision_mask = 2
		
		if not interaction_area.body_entered.is_connected(_on_body_entered):
			interaction_area.body_entered.connect(_on_body_entered)
		if not interaction_area.body_exited.is_connected(_on_body_exited):
			interaction_area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("players") or body.name.begins_with("Player"):
		set_highlight(true)
		player_entered_interaction_zone.emit(body, station_id)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("players") or body.name.begins_with("Player"):
		set_highlight(false)
		player_exited_interaction_zone.emit(body, station_id)
