class_name MapManager
extends Node2D

## 2D Facility Map Manager for BLACKOUT (Asterion Research Facility).
## Manages room spatial definitions, boundary limits, and collision structures.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

## Outer facility world boundaries for Camera2D viewport clamping.
const MAP_BOUNDS_LEFT: int = 120
const MAP_BOUNDS_TOP: int = 40
const MAP_BOUNDS_RIGHT: int = 1480
const MAP_BOUNDS_BOTTOM: int = 1080

## Master 8-player spawn coordinates distributed inside Central Hub (Cafeteria).
const FACILITY_SPAWN_POINTS: Array[Vector2] = [
	Vector2(800.0, 550.0), # Slot 1: Central Hub Core
	Vector2(720.0, 550.0), # Slot 2: Central Hub West
	Vector2(880.0, 550.0), # Slot 3: Central Hub East
	Vector2(800.0, 470.0), # Slot 4: Central Hub North
	Vector2(800.0, 630.0), # Slot 5: Central Hub South
	Vector2(730.0, 480.0), # Slot 6: Central Hub North-West
	Vector2(870.0, 480.0), # Slot 7: Central Hub North-East
	Vector2(730.0, 620.0)  # Slot 8: Central Hub South-West
]

## Facility 9-room metadata dictionary for navigation and future interactables.
const ROOM_DEFINITIONS: Dictionary = {
	"cafeteria": { "name": "Cafeteria / Central Hub", "center": Vector2(800.0, 550.0), "size": Vector2(400.0, 300.0) },
	"security": { "name": "Security Room", "center": Vector2(365.0, 265.0), "size": Vector2(350.0, 230.0) },
	"lab": { "name": "Laboratory", "center": Vector2(315.0, 600.0), "size": Vector2(270.0, 300.0) },
	"storage": { "name": "Storage", "center": Vector2(375.0, 920.0), "size": Vector2(350.0, 200.0) },
	"server_room": { "name": "Server Room", "center": Vector2(1225.0, 265.0), "size": Vector2(350.0, 230.0) },
	"office": { "name": "Office", "center": Vector2(1285.0, 600.0), "size": Vector2(270.0, 300.0) },
	"medbay": { "name": "Medical Bay", "center": Vector2(1225.0, 920.0), "size": Vector2(350.0, 200.0) },
	"generator": { "name": "Generator Room", "center": Vector2(800.0, 150.0), "size": Vector2(300.0, 140.0) },
	"orion_core": { "name": "ORION Core Chamber", "center": Vector2(800.0, 965.0), "size": Vector2(360.0, 170.0) }
}

@onready var walls_container: StaticBody2D = get_node_or_null("Walls")
@onready var boundaries_container: StaticBody2D = get_node_or_null("Boundaries")

func _ready() -> void:
	print("[MapManager] Asterion Research Facility map initialized (9 rooms + corridors).")

## Returns camera boundary limits dictionary.
func get_camera_limits() -> Dictionary:
	return {
		"left": MAP_BOUNDS_LEFT,
		"top": MAP_BOUNDS_TOP,
		"right": MAP_BOUNDS_RIGHT,
		"bottom": MAP_BOUNDS_BOTTOM
	}

## Returns full Rect2 bounds of the playable facility.
func get_map_bounds() -> Rect2:
	return Rect2(
		Vector2(MAP_BOUNDS_LEFT, MAP_BOUNDS_TOP),
		Vector2(MAP_BOUNDS_RIGHT - MAP_BOUNDS_LEFT, MAP_BOUNDS_BOTTOM - MAP_BOUNDS_TOP)
	)

## Returns the verified 8-player facility spawn points.
func get_facility_spawn_points() -> Array[Vector2]:
	return FACILITY_SPAWN_POINTS.duplicate()

## Checks if a coordinate is within the valid facility outer boundaries.
func is_point_within_facility(point: Vector2) -> bool:
	return point.x >= MAP_BOUNDS_LEFT and point.x <= MAP_BOUNDS_RIGHT and point.y >= MAP_BOUNDS_TOP and point.y <= MAP_BOUNDS_BOTTOM

## Returns metadata for a specified facility room.
func get_room_info(room_id: String) -> Dictionary:
	return ROOM_DEFINITIONS.get(room_id, {})
