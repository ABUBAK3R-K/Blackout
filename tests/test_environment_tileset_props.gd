extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 3:
## Modular 32x32 Tileset Resources, Room Prop Sprites & RoomProp Base Class.
## Verifies all 12 asset and engine integration requirements:
##   1. Tileset atlas texture exists (tileset_floor_walls.png)
##   2. Tileset atlas dimension verification (256x256 px, 32x32 tile unit)
##   3. Cafeteria props validation (table 64x64, meeting console 64x64)
##   4. Security Room props validation (security desk 64x32)
##   5. Laboratory props validation (fume hood 64x64)
##   6. Server Room props validation (server rack 32x64)
##   7. Storage props validation (storage crates 64x32)
##   8. Generator Room props validation (generator unit 64x64)
##   9. Executive Office & MedBay props validation (desk 64x32, bed 32x64)
##   10. ORION Core reactor prop validation (reactor core 128x128)
##   11. RoomProp node instantiation, Layer 1 collision & Y-sort verification
##   12. RoomProp Layer 3 station interaction zone & hover highlight verification

const RoomPropClass = preload("res://scenes/environment/room_prop.gd")

var test_passed: bool = true
var test_log: Array[String] = []

const ASSET_DIR: String = "res://assets/sprites/environment/"

const REQUIRED_PROPS: Dictionary = {
	"prop_cafeteria_table.png": Vector2i(64, 64),
	"prop_cafeteria_meeting_console.png": Vector2i(64, 64),
	"prop_security_desk.png": Vector2i(64, 32),
	"prop_lab_fume_hood.png": Vector2i(64, 64),
	"prop_server_rack.png": Vector2i(32, 64),
	"prop_storage_crates.png": Vector2i(64, 32),
	"prop_generator_unit.png": Vector2i(64, 64),
	"prop_executive_desk.png": Vector2i(64, 32),
	"prop_medbay_bed.png": Vector2i(32, 64),
	"prop_orion_core_reactor.png": Vector2i(128, 128)
}

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 3 TILESET & PROPS TEST SUITE")
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
	_log_info("Executing Member 7 Tileset & Room Props test assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1 & 2: Tileset Atlas Texture & Dimensions
	# ---------------------------------------------------------
	_log_info("--- TEST 1 & 2: Modular Tileset Atlas Verification ---")
	var tileset_path = ASSET_DIR + "tileset_floor_walls.png"
	if ResourceLoader.exists(tileset_path):
		var tileset_tex = load(tileset_path) as Texture2D
		if tileset_tex:
			var sz = tileset_tex.get_size()
			if int(sz.x) == 256 and int(sz.y) == 256:
				_log_pass("Tileset atlas exists with exact 256x256 dimensions (8x8 32x32 grid).")
			else:
				_log_fail("Tileset atlas dimension mismatch: %s" % str(sz))
		else:
			_log_fail("Failed to load tileset atlas texture resource.")
	else:
		_log_fail("Tileset atlas file not found at: %s" % tileset_path)
		
	# ---------------------------------------------------------
	# TEST 3 to 10: 9-Room Specific Prop Sprite Validations
	# ---------------------------------------------------------
	_log_info("--- TEST 3-10: 9-Room Prop Sprite Dimensions & Completeness ---")
	var all_props_valid = true
	for prop_file in REQUIRED_PROPS.keys():
		var expected_size: Vector2i = REQUIRED_PROPS[prop_file]
		var full_path = ASSET_DIR + prop_file
		if ResourceLoader.exists(full_path):
			var prop_tex = load(full_path) as Texture2D
			if prop_tex:
				var actual_size = Vector2i(int(prop_tex.get_size().x), int(prop_tex.get_size().y))
				if actual_size == expected_size:
					_log_pass("Prop '%s' verified (Dimensions: %dx%d)." % [prop_file, actual_size.x, actual_size.y])
				else:
					_log_fail("Prop '%s' size mismatch: expected %s, got %s" % [prop_file, str(expected_size), str(actual_size)])
					all_props_valid = false
			else:
				_log_fail("Failed to load prop texture: %s" % prop_file)
				all_props_valid = false
		else:
			_log_fail("Missing prop asset: %s" % full_path)
			all_props_valid = false
			
	if all_props_valid:
		_log_pass("All 10 required room prop sprites across 9 facility rooms verified.")
		
	# ---------------------------------------------------------
	# TEST 11: RoomProp Base Class & Obstacle Physics
	# ---------------------------------------------------------
	_log_info("--- TEST 11: RoomProp Node Instantiation & Layer 1 Physics ---")
	var prop_node = RoomPropClass.new()
	prop_node.name = "TestCafeteriaTable"
	prop_node.prop_name = "Cafeteria Dining Table"
	prop_node.room_id = "cafeteria"
	
	var col_shape = CollisionShape2D.new()
	col_shape.name = "CollisionShape2D"
	var shape_res = RectangleShape2D.new()
	shape_res.size = Vector2(60, 24)
	col_shape.shape = shape_res
	prop_node.add_child(col_shape)
	prop_node.collision_shape = col_shape
	
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	prop_node.add_child(spr)
	prop_node.sprite = spr
	
	root_node.add_child(prop_node)
	
	# Layer 1 = World/Obstacles (1)
	if prop_node.collision_layer == 1 and prop_node.collision_mask == 0:
		_log_pass("RoomProp correctly assigned to Physics Layer 1 (World / Obstacles).")
	else:
		_log_fail("RoomProp collision layer mismatch: layer=%d, mask=%d" % [prop_node.collision_layer, prop_node.collision_mask])
		
	if prop_node.y_sort_enabled and prop_node.z_index == 1:
		_log_pass("RoomProp has Y-sort enabled and Z-Index = 1.")
	else:
		_log_fail("RoomProp Y-Sort/Z-Index mismatch: y_sort=%s, z_index=%d" % [prop_node.y_sort_enabled, prop_node.z_index])
		
	# ---------------------------------------------------------
	# TEST 12: RoomProp Interactable Zone & Hover Highlight
	# ---------------------------------------------------------
	_log_info("--- TEST 12: RoomProp Layer 3 Interactable Zone & Proximity ---")
	var station_prop = RoomPropClass.new()
	station_prop.name = "TestMeetingConsole"
	station_prop.prop_name = "Emergency Meeting Button"
	station_prop.room_id = "cafeteria"
	station_prop.station_id = "emergency_meeting_console"
	station_prop.is_interactable = true
	
	var station_spr = Sprite2D.new()
	station_spr.name = "Sprite2D"
	station_prop.add_child(station_spr)
	station_prop.sprite = station_spr
	
	root_node.add_child(station_prop)
	
	# Area2D should be automatically created with Layer 3 (bit 3 = 4) and Mask Layer 2 (bit 2 = 2)
	if station_prop.interaction_area:
		if station_prop.interaction_area.collision_layer == 4 and station_prop.interaction_area.collision_mask == 2:
			_log_pass("Station interaction area properly configured (Layer 3: Stations, Mask: Players).")
		else:
			_log_fail("Station interaction area layer mismatch: layer=%d, mask=%d" % [station_prop.interaction_area.collision_layer, station_prop.interaction_area.collision_mask])
	else:
		_log_fail("Station interaction area failed to initialize.")
		
	# Test Highlight
	station_prop.set_highlight(true)
	if station_spr.modulate == RoomPropClass.COLOR_HIGHLIGHT_MODULATE:
		_log_pass("Station highlight successfully applies visual modulate.")
	else:
		_log_fail("Station highlight modulate mismatch: %s" % str(station_spr.modulate))
		
	station_prop.set_highlight(false)
	if station_spr.modulate == RoomPropClass.COLOR_NORMAL_MODULATE:
		_log_pass("Station highlight successfully resets to normal modulate.")
	else:
		_log_fail("Station normal modulate mismatch.")
		
	# Cleanup test nodes
	prop_node.queue_free()
	station_prop.queue_free()
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 3 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
