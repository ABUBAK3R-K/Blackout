extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 4:
## Full 9-Room Master Facility Map Scene & Spatial Logic.
## Verifies all 12 master map and engine integration requirements:
##   1. FacilityMap script & scene instantiation
##   2. 9 distinct facility rooms presence in ROOM_DEFINITIONS
##   3. Cafeteria bounds & center spatial location detection
##   4. Storage room spatial location detection
##   5. Server Room & Data terminal spatial location detection
##   6. Medical Bay spatial location detection
##   7. Generator Room & Power station spatial location detection
##   8. Executive Office & Security Room spatial detection
##   9. Laboratory & ORION Core spatial detection
##   10. Exactly 8 player spawn anchors inside Cafeteria
##   11. All 10 interactive station props linked and discoverable via get_station_prop()
##   12. Integrated FacilityLightingController with normal and emergency fixture arrays

const FacilityMapClass = preload("res://scenes/environment/facility_map.gd")

var test_passed: bool = true
var test_log: Array[String] = []

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

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 4 MASTER MAP TEST SUITE")
	print("==================================================================\n")
	
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
	_log_info("Executing Master Facility Map test assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1 & 2: Scene Instantiation & 9 Rooms Presence
	# ---------------------------------------------------------
	_log_info("--- TEST 1 & 2: Master Facility Map Instantiation & Rooms ---")
	var map_scene = load("res://scenes/environment/facility_map.tscn") as PackedScene
	if not map_scene:
		_log_fail("Failed to load facility_map.tscn scene.")
		quit(1)
		return
		
	var map_instance = map_scene.instantiate() as FacilityMap
	root_node.add_child(map_instance)
	_log_pass("FacilityMap scene instantiated successfully.")
	
	var room_ids = map_instance.get_all_room_ids()
	var missing_rooms = []
	for r in EXPECTED_ROOMS:
		if not room_ids.has(r):
			missing_rooms.append(r)
			
	if missing_rooms.is_empty():
		_log_pass("All 9 required facility rooms registered in ROOM_DEFINITIONS.")
	else:
		_log_fail("Missing rooms in definitions: %s" % str(missing_rooms))
		
	# ---------------------------------------------------------
	# TEST 3 to 9: Spatial Room Query Validation
	# ---------------------------------------------------------
	_log_info("--- TEST 3-9: Spatial Location Queries (get_room_at_position) ---")
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
		
	# ---------------------------------------------------------
	# TEST 10: 8 Player Spawn Points inside Cafeteria
	# ---------------------------------------------------------
	_log_info("--- TEST 10: 8 Player Spawn Anchors ---")
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
		
	# ---------------------------------------------------------
	# TEST 11: Interactive Station Props Linkage
	# ---------------------------------------------------------
	_log_info("--- TEST 11: Station Props Linkage & Discovery ---")
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
		
	# ---------------------------------------------------------
	# TEST 12: Integrated Facility Lighting Controller
	# ---------------------------------------------------------
	_log_info("--- TEST 12: Integrated Dual-State Lighting Verification ---")
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
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 4 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
