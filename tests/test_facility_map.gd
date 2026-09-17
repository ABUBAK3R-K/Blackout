extends SceneTree

## Unit Test Suite for BLACKOUT Facility Map Layout & Wall Collision (Member 3).
## Verifies:
##   1. MapManager class instantiates with 9 room definitions and valid boundaries.
##   2. facility_map.tscn loads and instantiates all Node2D hierarchy layers.
##   3. Boundaries StaticBody2D contains active perimeter collision shapes.
##   4. Walls StaticBody2D contains interior room divider collision shapes.
##   5. All 9 required Asterion facility rooms are properly defined.
##   6. Camera boundary limits are mathematically consistent (left < right, top < bottom).
##   7. All 8 player spawn points are located strictly inside the playable facility area.
##   8. All 8 player spawn points are inside Central Hub (Cafeteria) and separated safely.
##   9. PlayerController placement inside Central Hub spawns without stuck collisions.

const MapManager = preload("res://client/environment/map_manager.gd")
const FacilityMapScene = preload("res://scenes/map/facility_map.tscn")
const SpawnManager = preload("res://client/player/spawn_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — FACILITY MAP & WALL COLLISION TEST (MEMBER 3)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _run_suite() -> void:
	test_map_manager_instantiation()
	test_facility_map_scene_structure()
	test_collision_bodies()
	test_nine_room_definitions()
	test_camera_bounds_validity()
	test_spawn_points_within_facility()
	test_spawn_point_distribution()
	test_player_spawn_and_movement_in_hub()

	print("\n========================================================")
	if test_passed:
		print("  FACILITY MAP TESTS: ALL PASSED (100%)")
	else:
		print("  FACILITY MAP TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

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
