extends SceneTree

## Headless Integration Test Suite for Member 7 (Fatima) Phase 6:
## 2D Player Character Sprite Sheets (8 Colors, 4 Directions) & PlayerVisual Controller.
## Verifies 14 key asset, animation, and controller requirements:
##   1. All 8 player color sprite sheets exist in assets/sprites/characters/
##   2. All 8 sheets have exact 256x288 px dimensions (8 cols x 6 rows of 32x48 px frames)
##   3. Dedicated char_ghost.png sprite sheet exists (256x288 px)
##   4. PlayerVisual node instantiation, Y-sorting & Z-index validation
##   5. 8-color palette indexing and naming resolution (red, blue, green, yellow, orange, purple, cyan, white)
##   6. 8-color spec hex value validation matching environment_art_spec.md §7.1
##   7. 4-directional motion resolution (Down, Up, Right, Left)
##   8. Idle to Walk animation state transitions based on velocity
##   9. Frame index calculations for Idle (Row 0) and Walk (Rows 1 & 2)
##  10. Interact action trigger and frame assignment (Row 3)
##  11. Sabotage action trigger and frame assignment (Row 4)
##  12. Ghost state activation, texture switching and translucent alpha modulation
##  13. Flashlight anchor 4-directional beam alignment angles
##  14. Dynamic flashlight component attachment hook

const PlayerVisualClass = preload("res://scenes/characters/player_visual.gd")

var test_passed: bool = true
var test_log: Array[String] = []

const CHAR_DIR: String = "res://assets/sprites/characters/"

const EXPECTED_PALETTES: Array[String] = [
	"red", "blue", "green", "yellow", "orange", "purple", "cyan", "white"
]

const EXPECTED_HEX: Dictionary = {
	"red": "#e53935",
	"blue": "#1e88e5",
	"green": "#43a047",
	"yellow": "#fdd835",
	"orange": "#fb8c00",
	"purple": "#8e24aa",
	"cyan": "#00acc1",
	"white": "#eceff1"
}

func _init() -> void:
	print("\n==================================================================")
	print("  BLACKOUT — MEMBER 7 (FATIMA) PHASE 6 CHARACTER ANIMATIONS TEST")
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
	_log_info("Executing Member 7 Character Sprite Sheets & Controller assertions...")
	
	var root_node = root
	
	# ---------------------------------------------------------
	# TEST 1 & 2: 8 Player Suit Sprite Sheets Verification
	# ---------------------------------------------------------
	_log_info("--- TEST 1 & 2: 8 Player Suit Sprite Sheets & Dimensions ---")
	var all_palettes_valid = true
	for cname in EXPECTED_PALETTES:
		var filename = "char_%s.png" % cname
		var path = CHAR_DIR + filename
		if ResourceLoader.exists(path):
			var tex = load(path) as Texture2D
			if tex:
				var sz = Vector2i(int(tex.get_size().x), int(tex.get_size().y))
				if sz == Vector2i(256, 288):
					_log_pass("Suit sprite sheet '%s' verified (256x288 px, 8x6 32x48 grid)." % filename)
				else:
					_log_fail("Dimension mismatch for %s: expected (256, 288), got %s" % [filename, str(sz)])
					all_palettes_valid = false
			else:
				_log_fail("Failed to load texture for: %s" % filename)
				all_palettes_valid = false
		else:
			_log_fail("Missing character sprite sheet: %s" % path)
			all_palettes_valid = false
			
	if all_palettes_valid:
		_log_pass("All 8 player suit color sprite sheets exist with exact 256x288 px dimensions.")
		
	# ---------------------------------------------------------
	# TEST 3: Ghost Sprite Sheet Verification
	# ---------------------------------------------------------
	_log_info("--- TEST 3: Ghost Sprite Sheet Verification ---")
	var ghost_path = CHAR_DIR + "char_ghost.png"
	if ResourceLoader.exists(ghost_path):
		var ghost_tex = load(ghost_path) as Texture2D
		if ghost_tex and int(ghost_tex.get_size().x) == 256 and int(ghost_tex.get_size().y) == 288:
			_log_pass("Ethereal ghost sprite sheet 'char_ghost.png' verified (256x288 px).")
		else:
			_log_fail("Ghost sprite sheet dimension mismatch.")
	else:
		_log_fail("Missing ghost sprite sheet at: %s" % ghost_path)
		
	# ---------------------------------------------------------
	# TEST 4: PlayerVisual Node Instantiation & Layer Sorting
	# ---------------------------------------------------------
	_log_info("--- TEST 4: PlayerVisual Node Instantiation ---")
	var player_node = PlayerVisualClass.new()
	player_node.name = "TestPlayerVisual"
	
	var spr = Sprite2D.new()
	spr.name = "Sprite2D"
	player_node.add_child(spr)
	player_node.sprite = spr
	
	var anchor = Marker2D.new()
	anchor.name = "FlashlightAnchor"
	player_node.add_child(anchor)
	player_node.flashlight_anchor = anchor
	
	root_node.add_child(player_node)
	
	if player_node.y_sort_enabled and player_node.z_index == 1:
		_log_pass("PlayerVisual conforms to Y-Sort and Z-Index = 1 standards.")
	else:
		_log_fail("PlayerVisual sorting error.")
		
	# ---------------------------------------------------------
	# TEST 5 & 6: 8-Color Palette Bindings & Hex Values
	# ---------------------------------------------------------
	_log_info("--- TEST 5 & 6: 8-Color Palette Indexing & Hex Values ---")
	var colors_valid = true
	for i in range(8):
		player_node.set_color(i)
		var expected_name = EXPECTED_PALETTES[i]
		var actual_name = player_node.get_color_name()
		var expected_color = Color(EXPECTED_HEX[expected_name])
		var actual_color = player_node.get_color_hex()
		
		if actual_name == expected_name and actual_color == expected_color:
			_log_pass("Color ID %d: '%s' (%s) bound successfully." % [i, actual_name, actual_color.to_html(false)])
		else:
			_log_fail("Color mismatch for ID %d: expected %s (%s), got %s (%s)" % [i, expected_name, expected_color.to_html(false), actual_name, actual_color.to_html(false)])
			colors_valid = false
			
	if colors_valid:
		_log_pass("All 8 player suit colors and hex bindings verified.")
		
	# ---------------------------------------------------------
	# TEST 7, 8, 9: 4-Directional Motion & Frame Calculations
	# ---------------------------------------------------------
	_log_info("--- TEST 7, 8, 9: 4-Directional Motion & Frame Mapping ---")
	# Down
	player_node.set_motion(Vector2(0, 100))
	if player_node.current_direction == 0 and player_node.current_animation == "walk":
		_log_pass("Motion DOWN: Direction.DOWN & walk animation resolved.")
	else:
		_log_fail("Motion DOWN resolution failed.")
		
	# Up
	player_node.set_motion(Vector2(0, -100))
	if player_node.current_direction == 1 and player_node.current_animation == "walk":
		_log_pass("Motion UP: Direction.UP & walk animation resolved.")
	else:
		_log_fail("Motion UP resolution failed.")
		
	# Right
	player_node.set_motion(Vector2(100, 0))
	if player_node.current_direction == 2 and player_node.current_animation == "walk":
		_log_pass("Motion RIGHT: Direction.RIGHT & walk animation resolved.")
	else:
		_log_fail("Motion RIGHT resolution failed.")
		
	# Left
	player_node.set_motion(Vector2(-100, 0))
	if player_node.current_direction == 3 and player_node.current_animation == "walk":
		_log_pass("Motion LEFT: Direction.LEFT & walk animation resolved.")
	else:
		_log_fail("Motion LEFT resolution failed.")
		
	# Idle Stop
	player_node.set_motion(Vector2.ZERO)
	if player_node.current_animation == "idle":
		_log_pass("Zero velocity automatically returns state to 'idle'.")
	else:
		_log_fail("Zero velocity failed to return to idle.")
		
	# ---------------------------------------------------------
	# TEST 10 & 11: Interact and Sabotage Action Animations
	# ---------------------------------------------------------
	_log_info("--- TEST 10 & 11: Interact and Sabotage Action Triggers ---")
	player_node.play_interact()
	if player_node.current_animation == "interact" and spr.frame >= 24 and spr.frame < 32:
		_log_pass("play_interact() correctly triggers interact state (Row 3 frame %d)." % spr.frame)
	else:
		_log_fail("play_interact() failed: anim=%s, frame=%d" % [player_node.current_animation, spr.frame])
		
	player_node.play_sabotage()
	if player_node.current_animation == "sabotage" and spr.frame >= 32 and spr.frame < 40:
		_log_pass("play_sabotage() correctly triggers sabotage state (Row 4 frame %d)." % spr.frame)
	else:
		_log_fail("play_sabotage() failed: anim=%s, frame=%d" % [player_node.current_animation, spr.frame])
		
	# ---------------------------------------------------------
	# TEST 12: Ghost Mode & Translucent Modulation
	# ---------------------------------------------------------
	_log_info("--- TEST 12: Ghost Mode Activation ---")
	player_node.set_ghost_mode(true)
	if player_node.is_ghost and spr.modulate.a < 0.9 and player_node.current_animation == "ghost":
		_log_pass("Ghost mode enables translucency (alpha=%.2f) and ghost animation." % spr.modulate.a)
	else:
		_log_fail("Ghost mode setup failed.")
		
	player_node.set_ghost_mode(false)
	if not player_node.is_ghost and spr.modulate.a == 1.0:
		_log_pass("Disabling ghost mode restores full opacity (alpha=1.0).")
	else:
		_log_fail("Disabling ghost mode failed.")
		
	# ---------------------------------------------------------
	# TEST 13 & 14: Flashlight Anchor Orientation & Attachment
	# ---------------------------------------------------------
	_log_info("--- TEST 13 & 14: Flashlight Anchor Angles & Attachment ---")
	player_node.set_motion(Vector2(0, 100)) # Down
	var down_deg = anchor.rotation_degrees
	player_node.set_motion(Vector2(100, 0)) # Right
	var right_deg = anchor.rotation_degrees
	player_node.set_motion(Vector2(0, -100)) # Up
	var up_deg = anchor.rotation_degrees
	player_node.set_motion(Vector2(-100, 0)) # Left
	var left_deg = anchor.rotation_degrees
	
	if is_equal_approx(down_deg, 90.0) and is_equal_approx(right_deg, 0.0) and is_equal_approx(up_deg, -90.0) and is_equal_approx(left_deg, 180.0):
		_log_pass("Flashlight anchor angles align with 4 directions (Down: 90°, Right: 0°, Up: -90°, Left: 180°).")
	else:
		_log_fail("Flashlight anchor angles mismatch: D=%.1f, R=%.1f, U=%.1f, L=%.1f" % [down_deg, right_deg, up_deg, left_deg])
		
	var dummy_light = Node2D.new()
	player_node.attach_flashlight(dummy_light)
	if dummy_light.get_parent() == anchor:
		_log_pass("Flashlight component attachment hook verified.")
	else:
		_log_fail("Flashlight attachment failed.")
		
	# Cleanup
	player_node.queue_free()
	
	# ---------------------------------------------------------
	# SUMMARY & CONCLUSION
	# ---------------------------------------------------------
	print("\n==================================================================")
	print("  MEMBER 7 PHASE 6 TEST RESULTS SUMMARY")
	print("==================================================================")
	print("  Total Passed Checks: %d" % test_log.size())
	if test_passed:
		print("  STATUS: [ALL TESTS PASSED SUCCESSFULLY] 🚀")
	else:
		print("  STATUS: [TEST FAILURES DETECTED] ❌")
	print("==================================================================\n")
	
	quit(0 if test_passed else 1)
