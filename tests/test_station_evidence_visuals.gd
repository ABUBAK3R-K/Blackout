extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 5:
## Station Visual States (Intact, Sabotaged, Repairing, Restored) & Discoverable Evidence Markers.
## Verifies 14 key asset, controller, and spatial requirements:
##   1. All 10 stations have complete 4-state visual texture sets (40 textures total)
##   2. Generator Room station dimensions & visual states (64x64)
##   3. ORION Core station dimensions & visual states (64x64)
##   4. Server Room station dimensions & visual states (32x64 & 64x32)
##   5. Security, MedBay, Door, Coolant, Lab, and Backup station textures
##   6. 5 Post-Blackout discoverable evidence marker sprites verification
##   7. Evidence marker pin icon badge verification (32x32)
##   8. StationProp base physics layers (Layer 1 Obstacle, Layer 3 Station Interactable)
##   9. StationProp 4-state visual state machine switching
##  10. StationProp status LED lighting cues (Green, Red, Amber)
##  11. StationProp repair progress hooks and auto-completion
##  12. EvidenceMarker Physics Layer 5 (Evidence Markers) and Layer 2 Mask
##  13. EvidenceMarker template setup matching EvidenceConfig definitions
##  14. EvidenceMarker discovery state changes and inspection signal hooks

const StationPropClass = preload("res://scenes/environment/station_prop.gd")
const EvidenceMarkerClass = preload("res://scenes/environment/evidence_marker.gd")
const EvidenceConfigClass = preload("res://shared/evidence_config.gd")
const TaskConfigClass = preload("res://shared/task_config.gd")

var test_passed: bool = true
var test_log: Array[String] = []

const STATIONS_DIR: String = "res://assets/sprites/stations/"

const EXPECTED_STATIONS: Dictionary = {
	"repair_power": Vector2i(64, 64),
	"stabilize_orion": Vector2i(64, 64),
	"server_calibration": Vector2i(32, 64),
	"security_repair": Vector2i(64, 32),
	"medical_supply": Vector2i(32, 64),
	"data_transfer": Vector2i(64, 32),
	"door_repair": Vector2i(64, 64),
	"coolant_system": Vector2i(64, 64),
	"laboratory_org": Vector2i(64, 64),
	"backup_power": Vector2i(64, 32)
}

const EXPECTED_EVIDENCE: Dictionary = {
	"evidence_classified_files.png": Vector2i(64, 32),
	"evidence_orion_data.png": Vector2i(64, 64),
	"evidence_containment_disabled.png": Vector2i(64, 64),
	"evidence_generator_scorch.png": Vector2i(64, 64),
	"evidence_security_static.png": Vector2i(64, 32),
	"evidence_marker_pin.png": Vector2i(32, 32)
}

const STATES: Array[String] = ["intact", "sabotaged", "repairing", "restored"]

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 5 STATION & EVIDENCE TEST SUITE")
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
	_log_info("Executing Member 7 Station Visuals & Evidence Markers test assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1-5: 10 Station Sprites Across 4 States (40 Textures)
	# ---------------------------------------------------------
	_log_info("--- TEST 1-5: 10 Station 4-State Texture Verification (40 Total) ---")
	var missing_textures = 0
	var dimension_mismatches = 0
	
	for station_name in EXPECTED_STATIONS.keys():
		var exp_sz: Vector2i = EXPECTED_STATIONS[station_name]
		for st in STATES:
			var filename = "station_%s_%s.png" % [station_name, st]
			var path = STATIONS_DIR + filename
			if ResourceLoader.exists(path):
				var tex = load(path) as Texture2D
				if tex:
					var actual_sz = Vector2i(int(tex.get_size().x), int(tex.get_size().y))
					if actual_sz != exp_sz:
						_log_fail("Size mismatch for %s: expected %s, got %s" % [filename, str(exp_sz), str(actual_sz)])
						dimension_mismatches += 1
				else:
					_log_fail("Failed loading texture: %s" % filename)
					missing_textures += 1
			else:
				_log_fail("Missing station texture: %s" % path)
				missing_textures += 1
				
	if missing_textures == 0 and dimension_mismatches == 0:
		_log_pass("All 40 station state textures (10 stations x 4 states) exist with exact dimensions.")
	else:
		_log_fail("Station texture suite failed with %d missing and %d dimension mismatches." % [missing_textures, dimension_mismatches])
		
	# ---------------------------------------------------------
	# TEST 6 & 7: Evidence Marker Textures & Pin Icon
	# ---------------------------------------------------------
	_log_info("--- TEST 6 & 7: Evidence Marker Sprites & Pin Badge ---")
	var all_evidence_valid = true
	for ev_file in EXPECTED_EVIDENCE.keys():
		var exp_sz: Vector2i = EXPECTED_EVIDENCE[ev_file]
		var path = STATIONS_DIR + ev_file
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				var actual_sz = Vector2i(int(tex.get_size().x), int(tex.get_size().y))
				if actual_sz == exp_sz:
					_log_pass("Evidence sprite '%s' verified (%dx%d)." % [ev_file, actual_sz.x, actual_sz.y])
				else:
					_log_fail("Evidence sprite '%s' size mismatch: expected %s, got %s" % [ev_file, str(exp_sz), str(actual_sz)])
					all_evidence_valid = false
			else:
				_log_fail("Failed loading evidence texture: %s" % ev_file)
				all_evidence_valid = false
		else:
			_log_fail("Missing evidence asset: %s" % path)
			all_evidence_valid = false
			
	if all_evidence_valid:
		_log_pass("All 5 discoverable evidence sprites + investigation pin badge verified.")
		
	# ---------------------------------------------------------
	# TEST 8: StationProp Node Physics & Layer Standard
	# ---------------------------------------------------------
	_log_info("--- TEST 8: StationProp Node Instantiation & Layer Physics ---")
	var station_node = StationPropClass.new()
	station_node.name = "TestPowerStation"
	station_node.prop_name = "Main Power Distribution"
	station_node.station_id = "repair_power"
	station_node.room_id = "generator_room"
	
	var col_shape = CollisionShape2D.new()
	var rect_shape = RectangleShape2D.new()
	rect_shape.size = Vector2(56, 48)
	col_shape.shape = rect_shape
	station_node.add_child(col_shape)
	station_node.collision_shape = col_shape
	
	var spr = Sprite2D.new()
	station_node.add_child(spr)
	station_node.sprite = spr
	
	var light = PointLight2D.new()
	station_node.add_child(light)
	station_node.status_light = light
	
	root_node.add_child(station_node)
	
	# Layer 1 = World Obstacles, Z=1, Y-sort enabled
	if station_node.collision_layer == 1 and station_node.y_sort_enabled and station_node.z_index == 1:
		_log_pass("StationProp conforms to Layer 1 Obstacle physics and Y-sort standards.")
	else:
		_log_fail("StationProp physics layer/Y-sort error: layer=%d, y_sort=%s" % [station_node.collision_layer, station_node.y_sort_enabled])
		
	# Interaction area: Layer 3 (bit 3 = 4), Mask: Layer 2 (bit 2 = 2)
	if station_node.interaction_area and station_node.interaction_area.collision_layer == 4 and station_node.interaction_area.collision_mask == 2:
		_log_pass("StationProp interaction trigger configured to Layer 3 Interactable / Mask Layer 2 Players.")
	else:
		_log_fail("StationProp interaction trigger mismatch.")
		
	# ---------------------------------------------------------
	# TEST 9 & 10: StationProp 4-State Visual Switching & LED Cues
	# ---------------------------------------------------------
	_log_info("--- TEST 9 & 10: Visual State Machine & LED Lighting Cues ---")
	var states_tested = true
	
	# Test INTACT
	station_node.set_visual_state(StationPropClass.VisualState.INTACT)
	if station_node.get_visual_state() == StationPropClass.VisualState.INTACT:
		if station_node.status_light and station_node.status_light.color == StationPropClass.COLOR_LED_GREEN:
			_log_pass("VisualState INTACT (0): Green LED indicator confirmed.")
		else:
			_log_fail("VisualState INTACT: Status light color mismatch.")
			states_tested = false
	else:
		_log_fail("Failed setting visual state INTACT.")
		states_tested = false
		
	# Test SABOTAGED
	station_node.set_visual_state("sabotaged")
	if station_node.get_visual_state() == StationPropClass.VisualState.SABOTAGED:
		if station_node.status_light and station_node.status_light.color == StationPropClass.COLOR_LED_RED:
			_log_pass("VisualState SABOTAGED (1): Red emergency LED indicator confirmed.")
		else:
			_log_fail("VisualState SABOTAGED: Status light color mismatch.")
			states_tested = false
	else:
		_log_fail("Failed setting visual state SABOTAGED.")
		states_tested = false
		
	# Test BEING_REPAIRED
	station_node.set_visual_state(StationPropClass.VisualState.BEING_REPAIRED)
	if station_node.get_visual_state() == StationPropClass.VisualState.BEING_REPAIRED:
		if station_node.status_light and station_node.status_light.color == StationPropClass.COLOR_LED_AMBER:
			_log_pass("VisualState BEING_REPAIRED (2): Amber progress LED indicator confirmed.")
		else:
			_log_fail("VisualState BEING_REPAIRED: Status light color mismatch.")
			states_tested = false
	else:
		_log_fail("Failed setting visual state BEING_REPAIRED.")
		states_tested = false
		
	# Test RESTORED
	station_node.set_visual_state("restored")
	if station_node.get_visual_state() == StationPropClass.VisualState.RESTORED:
		if station_node.status_light and station_node.status_light.color == StationPropClass.COLOR_LED_GREEN:
			_log_pass("VisualState RESTORED (3): Green confirmation LED indicator confirmed.")
		else:
			_log_fail("VisualState RESTORED: Status light color mismatch.")
			states_tested = false
	else:
		_log_fail("Failed setting visual state RESTORED.")
		states_tested = false
		
	# ---------------------------------------------------------
	# TEST 11: StationProp Repair Progress Updates
	# ---------------------------------------------------------
	_log_info("--- TEST 11: StationProp Progress Hooks ---")
	station_node.set_visual_state("sabotaged")
	station_node.apply_repair_progress(0.45)
	if station_node.get_visual_state() == StationPropClass.VisualState.BEING_REPAIRED:
		_log_pass("Partial progress (45%) automatically transitions state to BEING_REPAIRED.")
	else:
		_log_fail("Partial progress failed to transition state.")
		
	station_node.apply_repair_progress(1.0)
	if station_node.get_visual_state() == StationPropClass.VisualState.RESTORED:
		_log_pass("Full progress (100%) automatically transitions state to RESTORED.")
	else:
		_log_fail("Full progress failed to transition state to RESTORED.")
		
	# ---------------------------------------------------------
	# TEST 12: EvidenceMarker Node Physics & Layer 5 Standards
	# ---------------------------------------------------------
	_log_info("--- TEST 12: EvidenceMarker Node Instantiation & Layer 5 Physics ---")
	var ev_node = EvidenceMarkerClass.new()
	ev_node.name = "TestEvidenceClassifiedFiles"
	ev_node.evidence_id = "ev_classified_files"
	ev_node.room_id = "executive_office"
	
	var ev_col = CollisionShape2D.new()
	var ev_shape = CircleShape2D.new()
	ev_shape.radius = 40.0
	ev_col.shape = ev_shape
	ev_node.add_child(ev_col)
	ev_node.collision_shape = ev_col
	
	var ev_spr = Sprite2D.new()
	ev_node.add_child(ev_spr)
	ev_node.sprite = ev_spr
	
	var ev_pin = Sprite2D.new()
	ev_node.add_child(ev_pin)
	ev_node.pin_icon = ev_pin
	
	var ev_glow = PointLight2D.new()
	ev_node.add_child(ev_glow)
	ev_node.glow_light = ev_glow
	
	root_node.add_child(ev_node)
	
	# Layer 5 = Evidence Markers (bit 5 = 16), Mask: Layer 2 = Players (bit 2 = 2)
	if ev_node.collision_layer == 16 and ev_node.collision_mask == 2:
		_log_pass("EvidenceMarker correctly assigned to Physics Layer 5 (Evidence) and Mask Layer 2 (Players).")
	else:
		_log_fail("EvidenceMarker collision layer mismatch: layer=%d, mask=%d" % [ev_node.collision_layer, ev_node.collision_mask])
		
	# ---------------------------------------------------------
	# TEST 13: EvidenceMarker Template Setup & Config Linkage
	# ---------------------------------------------------------
	_log_info("--- TEST 13: EvidenceMarker Template Binding with EvidenceConfig ---")
	ev_node.setup_from_type(EvidenceConfigClass.TYPE_CLASSIFIED_FILES_MISSING, "executive_office")
	if ev_node.evidence_type == EvidenceConfigClass.TYPE_CLASSIFIED_FILES_MISSING:
		_log_pass("EvidenceMarker successfully bound to EvidenceConfig TYPE_CLASSIFIED_FILES_MISSING.")
	else:
		_log_fail("EvidenceMarker type setup mismatch.")
		
	# ---------------------------------------------------------
	# TEST 14: EvidenceMarker Discovery & Inspection Signal Hooks
	# ---------------------------------------------------------
	_log_info("--- TEST 14: EvidenceMarker Discovery & Inspection ---")
	var signal_data = {"emitted": false}
	ev_node.evidence_discovered_by_player.connect(func(pid, type):
		if pid == 42 and type == EvidenceConfigClass.TYPE_CLASSIFIED_FILES_MISSING:
			signal_data["emitted"] = true
	)
	
	ev_node.discover(42)
	if ev_node.is_discovered and signal_data["emitted"]:
		_log_pass("EvidenceMarker discovery mechanism updates state and emits signal.")
	else:
		_log_fail("EvidenceMarker discovery failure.")
		
	ev_node.set_inspected(true)
	if ev_node.glow_light and ev_node.glow_light.energy > 0.5:
		_log_pass("EvidenceMarker proximity inspection highlights clue marker glow.")
	else:
		_log_fail("EvidenceMarker inspection glow update failure.")
		
	# Cleanup test nodes
	station_node.queue_free()
	ev_node.queue_free()
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 5 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
