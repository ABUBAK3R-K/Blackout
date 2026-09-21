extends SceneTree

## Unified Test Suite for BLACKOUT Facility Map (Member 3 & Member 7).
## Covers:
##   Part 1 (Member 3): MapManager, Wall/Perimeter Collisions, Spawn Points, Camera Limits.
##   Part 2 (Member 7): Master Map Scene, Spatial Queries, Station Props, Lighting Controller.

const MapManager = preload("res://client/environment/map_manager.gd")
const FacilityMapScene = preload("res://scenes/map/facility_map.tscn")
const SpawnManager = preload("res://client/player/spawn_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")

const FacilityMapClass = preload("res://scenes/environment/facility_map.gd")

const EXPECTED_ROOMS: Array[String] = [
	"cafeteria", "storage", "server_room", "medbay",
	"generator_room", "executive_office", "security_room",
	"laboratory", "orion_core"
]

const EXPECTED_STATIONS: Array[String] = [
	"emergency_meeting_console",
	"repair_power",
	"stabilize_orion",
	"server_calibration",
	"data_transfer",
	"security_repair",
	"medical_supply_check",
	"backup_power",
	"classified_files",
	"laboratory_org"
]

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — FACILITY MAP & MASTER SPATIAL TEST SUITE")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _run_suite() -> void:
	_log_info("--- PART 1: Member 3 Map & Collision Verification ---")
	test_map_manager_instantiation()
	test_facility_map_scene_structure()
	test_collision_bodies()
	test_nine_room_definitions()
	test_camera_bounds_validity()
	test_spawn_points_within_facility()
	test_spawn_point_distribution()
	test_player_spawn_and_movement_in_hub()

	_log_info("\n--- PART 2: Member 7 Master Facility Map & Spatial Logic ---")
	test_member7_master_map()

	print("\n========================================================")
	if test_passed:
		print("  FACILITY MAP TESTS: ALL PASSED (100%)")
	else:
		print("  FACILITY MAP TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

# -------------------------------------------------------------
# Part 1: Member 3 Tests
# -------------------------------------------------------------

func test_map_manager_instantiation() -> void:
	var mm = MapManager.new()
	if mm != null and mm.ROOM_DEFINITIONS.size() == 9:
		_log_pass("1. MapManager instantiates with all 9 Asterion facility rooms.")
	else:
		_log_fail("1. MapManager instantiation failed.")
	mm.free()

func test_facility_map_scene_structure() -> void:
	var map_instance = FacilityMapScene.instantiate()
	if map_instance != null:
		var floor_node = map_instance.get_node_or_null("Floor")
		var walls_node = map_instance.get_node_or_null("Walls")
		var bounds_node = map_instance.get_node_or_null("Boundaries")
		var labels_node = map_instance.get_node_or_null("RoomLabels")

		if floor_node != null and walls_node != null and bounds_node != null and labels_node != null:
			_log_pass("2. facility_map.tscn contains all required layers (Floor, Walls, Boundaries, RoomLabels).")
		else:
			_log_fail("2. facility_map.tscn missing one or more required sub-nodes.")
		map_instance.free()
	else:
		_log_fail("2. Failed to instantiate facility_map.tscn.")

func test_collision_bodies() -> void:
	var map_instance = FacilityMapScene.instantiate()
	if map_instance != null:
		var boundaries = map_instance.get_node_or_null("Boundaries") as StaticBody2D
		var walls = map_instance.get_node_or_null("Walls") as StaticBody2D

		var bound_shapes_count = 0
		var wall_shapes_count = 0

		if boundaries != null:
			for child in boundaries.get_children():
				if child is CollisionShape2D:
					bound_shapes_count += 1

		if walls != null:
			for child in walls.get_children():
				if child is CollisionShape2D:
					wall_shapes_count += 1

		if bound_shapes_count >= 4 and wall_shapes_count >= 10:
			_log_pass("3. Active StaticBody2D collision shapes verified (Boundaries: %d, Interior Walls: %d)." % [
				bound_shapes_count, wall_shapes_count
			])
		else:
			_log_fail("3. Insufficient collision shapes (Boundaries: %d, Walls: %d)." % [bound_shapes_count, wall_shapes_count])
		map_instance.free()

func test_nine_room_definitions() -> void:
	var required_rooms = ["cafeteria", "security", "lab", "storage", "server_room", "office", "medbay", "generator", "orion_core"]
	var mm = MapManager.new()
	var all_present = true

	for r in required_rooms:
		if not mm.ROOM_DEFINITIONS.has(r):
			all_present = false

	if all_present:
		_log_pass("4. All 9 required PRD rooms verified in metadata (Cafeteria, Security, Lab, Storage, Server, Office, MedBay, Generator, ORION Core).")
	else:
		_log_fail("4. Missing required room definitions in metadata.")
	mm.free()

func test_camera_bounds_validity() -> void:
	var mm = MapManager.new()
	var limits = mm.get_camera_limits()

	if limits.left < limits.right and limits.top < limits.bottom:
		_log_pass("5. Camera boundary limits are valid (Left: %d, Top: %d, Right: %d, Bottom: %d)." % [
			limits.left, limits.top, limits.right, limits.bottom
		])
	else:
		_log_fail("5. Camera boundary limits invalid.")
	mm.free()

func test_spawn_points_within_facility() -> void:
	var mm = MapManager.new()
	var spawn_points = mm.get_facility_spawn_points()
	var all_inside = true

	for pos in spawn_points:
		if not mm.is_point_within_facility(pos):
			all_inside = false

	if all_inside and spawn_points.size() == 8:
		_log_pass("6. All 8 spawn points are strictly inside playable facility bounds.")
	else:
		_log_fail("6. Some spawn points outside facility boundaries.")
	mm.free()

func test_spawn_point_distribution() -> void:
	var sm = SpawnManager.new()
	sm._ready()
	var points = sm.get_all_spawn_positions()
	var min_distance = 1000000.0

	for i in range(points.size()):
		for j in range(i + 1, points.size()):
			var dist = points[i].distance_to(points[j])
			if dist < min_distance:
				min_distance = dist

	# Minimum distance between any two spawn points should be at least 40px (player radius is 16px)
	if min_distance >= 40.0:
		_log_pass("7. Spawn point separation verified (Min inter-spawn distance: %.1f px >= 40.0px)." % min_distance)
	else:
		_log_fail("7. Spawn points too close to each other (Min dist: %.1f px)." % min_distance)
	sm.free()

func test_player_spawn_and_movement_in_hub() -> void:
	var sm = SpawnManager.new()
	sm._ready()
	var player_instance = PlayerScene.instantiate() as PlayerController

	if player_instance != null:
		sm.place_player(player_instance, 1)
		if player_instance.global_position == Vector2(800.0, 550.0):
			_log_pass("8. Player correctly spawns at Central Hub Core (800, 550).")
		else:
			_log_fail("8. Player spawn position incorrect: %s" % str(player_instance.global_position))
		player_instance.free()
	sm.free()

# -------------------------------------------------------------
# Part 2: Member 7 Tests
# -------------------------------------------------------------

func test_member7_master_map() -> void:
	var map_scene = load("res://scenes/environment/facility_map.tscn") as PackedScene
	if not map_scene:
		_log_fail("Failed to load scenes/environment/facility_map.tscn scene.")
		return
		
	var map_instance = map_scene.instantiate()
	root.add_child(map_instance)
	_log_pass("Member 7 FacilityMap scene instantiated successfully.")
	
	var room_ids = map_instance.get_all_room_ids()
	var missing_rooms = []
	for r in EXPECTED_ROOMS:
		if not room_ids.has(r):
			missing_rooms.append(r)
			
	if missing_rooms.is_empty():
		_log_pass("All 9 required facility rooms registered in Member 7 ROOM_DEFINITIONS.")
	else:
		_log_fail("Missing rooms in definitions: %s" % str(missing_rooms))
		
	# Spatial queries
	var sample_points = {
		Vector2(0, 0): "cafeteria",
		Vector2(-700, -600): "storage",
		Vector2(0, -600): "server_room",
		Vector2(700, -600): "medbay",
		Vector2(-750, 0): "generator_room",
		Vector2(650, 0): "executive_office",
		Vector2(-650, 600): "security_room",
		Vector2(0, 600): "laboratory",
		Vector2(750, 650): "orion_core",
		Vector2(5000, 5000): "corridor"
	}
	
	var spatial_all_pass = true
	for pt in sample_points.keys():
		var expected_room = sample_points[pt]
		var detected_room = map_instance.get_room_at_position(pt)
		if detected_room == expected_room:
			_log_pass("Point %s correctly detected as '%s'." % [str(pt), detected_room])
		else:
			_log_fail("Point %s detection mismatch: expected '%s', got '%s'" % [str(pt), expected_room, detected_room])
			spatial_all_pass = false
			
	if spatial_all_pass:
		_log_pass("Spatial query system 100% accurate across all 9 rooms and corridors.")
		
	# 8 Player Spawns
	var spawns_valid = true
	var cafeteria_bounds: Rect2 = FacilityMapClass.ROOM_DEFINITIONS["cafeteria"]["bounds"]
	for slot in range(8):
		var spawn_pos = map_instance.get_spawn_position(slot)
		if cafeteria_bounds.has_point(spawn_pos):
			_log_pass("Spawn point slot %d at %s is inside Cafeteria spawn hub." % [slot, str(spawn_pos)])
		else:
			_log_fail("Spawn point slot %d at %s is OUTSIDE Cafeteria bounds %s" % [slot, str(spawn_pos), str(cafeteria_bounds)])
			spawns_valid = false
			
	if spawns_valid:
		_log_pass("All 8 player spawn points properly established in Cafeteria.")
		
	# Station Props
	var stations_valid = true
	for st_id in EXPECTED_STATIONS:
		var prop_node = map_instance.get_station_prop(st_id)
		if prop_node:
			_log_pass("Station prop '%s' found (Prop Name: '%s', Room: '%s')." % [st_id, prop_node.prop_name, prop_node.room_id])
		else:
			_log_fail("Station prop '%s' NOT found in map props hierarchy." % st_id)
			stations_valid = false
			
	if stations_valid:
		_log_pass("All 10 interactive stations discovered and mapped accurately.")
		
	# Lighting Controller
	if map_instance.lighting_controller:
		var normal_count = map_instance.lighting_controller.normal_lights_parent.get_child_count() if map_instance.lighting_controller.normal_lights_parent else 0
		var siren_count = map_instance.lighting_controller.emergency_sirens_parent.get_child_count() if map_instance.lighting_controller.emergency_sirens_parent else 0
		if normal_count >= 9 and siren_count >= 9:
			_log_pass("Facility lighting active with %d normal fixtures and %d emergency sirens covering all 9 rooms." % [normal_count, siren_count])
		else:
			_log_fail("Insufficient lighting fixtures: normal=%d, sirens=%d" % [normal_count, siren_count])
	else:
		_log_fail("FacilityLightingController is missing from map instance.")
		
	map_instance.queue_free()
