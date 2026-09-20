class_name FacilityMap
extends Node2D

## FacilityMap
## Master 9-Room Research Facility Map controller for BLACKOUT.
## Manages room boundaries, player spawn anchors, Y-sorted interactive props, and dynamic lighting.
## Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

const RoomPropClass = preload("res://scenes/environment/room_prop.gd")

## Node References
@export var lighting_controller: FacilityLightingController
@export var spawn_points_parent: Node2D
@export var props_parent: Node2D
@export var tilemap_floors: Node2D
@export var tilemap_walls: Node2D

## Room definitions with exact bounding rectangles (in world space)
const ROOM_DEFINITIONS: Dictionary = {
	"cafeteria": {
		"name": "Cafeteria (Spawn Hub)",
		"bounds": Rect2(-448, -320, 896, 640),
		"center": Vector2(0, 0),
		"is_spawn_hub": true
	},
	"storage": {
		"name": "Storage",
		"bounds": Rect2(-1020, -856, 640, 512),
		"center": Vector2(-700, -600),
		"is_spawn_hub": false
	},
	"server_room": {
		"name": "Server Room",
		"bounds": Rect2(-288, -856, 576, 512),
		"center": Vector2(0, -600),
		"is_spawn_hub": false
	},
	"medbay": {
		"name": "Medical Bay",
		"bounds": Rect2(412, -856, 576, 512),
		"center": Vector2(700, -600),
		"is_spawn_hub": false
	},
	"generator_room": {
		"name": "Generator Room",
		"bounds": Rect2(-1102, -288, 704, 576),
		"center": Vector2(-750, 0),
		"is_spawn_hub": false
	},
	"executive_office": {
		"name": "Executive Office",
		"bounds": Rect2(394, -224, 512, 448),
		"center": Vector2(650, 0),
		"is_spawn_hub": false
	},
	"security_room": {
		"name": "Security Room",
		"bounds": Rect2(-906, 376, 512, 448),
		"center": Vector2(-650, 600),
		"is_spawn_hub": false
	},
	"laboratory": {
		"name": "Laboratory",
		"bounds": Rect2(-320, 344, 640, 512),
		"center": Vector2(0, 600),
		"is_spawn_hub": false
	},
	"orion_core": {
		"name": "ORION Core",
		"bounds": Rect2(334, 234, 832, 832),
		"center": Vector2(750, 650),
		"is_spawn_hub": false
	}
}

## Spawn offsets in Cafeteria for 8 players
const SPAWN_OFFSETS: Array[Vector2] = [
	Vector2(0, -160),
	Vector2(120, -120),
	Vector2(160, 0),
	Vector2(120, 120),
	Vector2(0, 160),
	Vector2(-120, 120),
	Vector2(-160, 0),
	Vector2(-120, -120)
]

## Cached station prop dictionary
var _station_props: Dictionary = {}

func _ready() -> void:
	if not lighting_controller:
		lighting_controller = get_node_or_null("FacilityLightingController")
	if not spawn_points_parent:
		spawn_points_parent = get_node_or_null("SpawnPoints")
	if not props_parent:
		props_parent = get_node_or_null("Props")
		
	_cache_station_props()

## Returns the room ID containing the given global coordinate, or "corridor" if outside room bounds
func get_room_at_position(global_pos: Vector2) -> String:
	for room_id in ROOM_DEFINITIONS:
		var room_data = ROOM_DEFINITIONS[room_id]
		var bounds: Rect2 = room_data["bounds"]
		if bounds.has_point(global_pos):
			return room_id
	return "corridor"

## Get the global spawn position for a player slot (0 to 7)
func get_spawn_position(slot_index: int) -> Vector2:
	var clamped_slot = posmod(slot_index, 8)
	if spawn_points_parent and spawn_points_parent.get_child_count() > clamped_slot:
		var marker = spawn_points_parent.get_child(clamped_slot) as Node2D
		if marker:
			return marker.global_position
	return SPAWN_OFFSETS[clamped_slot]

## Retrieve an interactive RoomProp node by its station ID
func get_station_prop(station_id: String) -> RoomProp:
	return _station_props.get(station_id, null)

## Get center coordinate of a given room
func get_room_center(room_id: String) -> Vector2:
	if ROOM_DEFINITIONS.has(room_id):
		return ROOM_DEFINITIONS[room_id]["center"]
	return Vector2.ZERO

## Get list of all 9 valid room IDs
func get_all_room_ids() -> Array:
	return ROOM_DEFINITIONS.keys()

func _cache_station_props() -> void:
	_station_props.clear()
	if not props_parent:
		return
	for child in props_parent.get_children():
		if child is RoomProp and child.station_id != "":
			_station_props[child.station_id] = child
