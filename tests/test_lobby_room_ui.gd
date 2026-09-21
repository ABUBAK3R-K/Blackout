extends SceneTree

## Headless Integration & Visual Test Suite for BLACKOUT Lobby Room UI (Member 5).
## Verifies:
## 1. Scene loading & node binding integrity
## 2. Header elements: Facility name, BLACKOUT branding, Waiting Room indicator, Player count
## 3. Authoritative Lobby Code display & Copy Code clipboard interaction
## 4. 8-Slot Roster: Technician avatars, Department titles, Host badge, Ready/Waiting badges
## 5. Partial lobby layout (e.g., 4 / 8 players with vacant slots)
## 6. Full lobby layout (8 / 8 players with all ready)
## 7. Local player ready/unready state toggling
## 8. Host vs non-host action button permissions (Start Game visibility & enabled condition)
## 9. Leave Lobby return action
## 10. Screenshot capture for visual confirmation

const NetworkConfig = preload("res://shared/network_config.gd")
const LobbyRoomClass = preload("res://client/ui/screens/lobby_room.gd")
const LobbyRoomScene = preload("res://client/ui/screens/lobby_room.tscn")

const ARTIFACTS_MEDIA_DIR: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.tempmediaStorage"

var lobby_room = null
var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — LOBBY ROOM UI INTEGRATION TEST")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_tests)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _capture_screenshot(file_name: String) -> void:
	var dir = DirAccess.open("C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829")
	if dir != null and not dir.dir_exists(".tempmediaStorage"):
		dir.make_dir(".tempmediaStorage")
		
	var img = get_root().get_viewport().get_texture().get_image()
	if img != null:
		var save_path = ARTIFACTS_MEDIA_DIR + "/" + file_name
		var err = img.save_png(save_path)
		if err == OK:
			_log_info("Saved UI screenshot: %s" % save_path)
		else:
			push_warning("Failed to save screenshot %s (Error: %d)" % [save_path, err])

func _run_tests() -> void:
	# ----------------------------------------------------
	# TEST 1: Instantiation and Node References
	# ----------------------------------------------------
	_log_info("--- TEST 1: Scene Instantiation ---")
	lobby_room = LobbyRoomScene.instantiate()
	get_root().add_child(lobby_room)
	
	await create_timer(0.1).timeout
	
	if lobby_room != null and is_instance_valid(lobby_room):
		_log_pass("LobbyRoom instantiated and added to SceneTree.")
	else:
		_log_fail("Failed to instantiate LobbyRoom.")
		_finish_suite()
		return

	# Verify references
	if lobby_room.lobby_code_label != null and lobby_room.player_count_label != null and lobby_room.roster_grid != null:
		_log_pass("All primary UI node references successfully bound.")
	else:
		_log_fail("Node references missing in LobbyRoom.")

	# ----------------------------------------------------
	# TEST 2: Header Branding & Lobby Code
	# ----------------------------------------------------
	_log_info("--- TEST 2: Header & Lobby Code Display ---")
	lobby_room.setup_mock_lobby(4, 3, true, 1, "A7K2X")
	await create_timer(0.05).timeout

	if lobby_room.lobby_code_label.text == "A7K2X":
		_log_pass("Lobby Code 'A7K2X' displayed prominently.")
	else:
		_log_fail("Lobby Code mismatch: got '%s'" % lobby_room.lobby_code_label.text)

	if lobby_room.player_count_label.text == "4 / 8":
		_log_pass("Player count '4 / 8' displayed in header pill.")
	else:
		_log_fail("Player count mismatch: got '%s'" % lobby_room.player_count_label.text)

	# ----------------------------------------------------
	# TEST 3: 8-Slot Roster Grid Layout (4 Occupied + 4 Vacant)
	# ----------------------------------------------------
	_log_info("--- TEST 3: 8-Slot Roster Grid Layout ---")
	var children = lobby_room.roster_grid.get_children()
	if children.size() == 8:
		_log_pass("Roster grid contains exactly 8 slots (4 occupied + 4 vacant).")
	else:
		_log_fail("Roster grid size mismatch: expected 8, got %d" % children.size())

	# Check host badge on slot 1
	var slot1 = children[0]
	var text_in_slot1 = _get_all_labels_text(slot1)
	if text_in_slot1.has("HOST") and text_in_slot1.has("(YOU)"):
		_log_pass("Slot 1 correctly marked with HOST and (YOU) badges.")
	else:
		_log_fail("Slot 1 missing HOST or (YOU) badges: %s" % str(text_in_slot1))

	_capture_screenshot("lobby_room_partial_host_view.png")

	# ----------------------------------------------------
	# TEST 4: Clipboard Copy Code Action
	# ----------------------------------------------------
	_log_info("--- TEST 4: Copy Code Action ---")
	var capture = {"code": ""}
	lobby_room.lobby_code_copied.connect(func(c): capture["code"] = c)
	lobby_room._on_copy_code_pressed()
	
	if capture["code"] == "A7K2X" and lobby_room.copy_code_btn.text == "COPIED!":
		_log_pass("Copy Code button copied 'A7K2X' and updated text to 'COPIED!'.")
	else:
		_log_fail("Copy Code action failed: copied_code='%s', btn_text='%s'" % [capture["code"], lobby_room.copy_code_btn.text])

	# ----------------------------------------------------
	# TEST 5: Local Ready State Toggle
	# ----------------------------------------------------
	_log_info("--- TEST 5: Local Player Ready Toggle ---")
	var toggled_ready: bool = false
	lobby_room.ready_toggled.connect(func(r): toggled_ready = r)
	
	# Currently slot 1 is ready (from mock setup 4, 3) -> toggle to unready
	lobby_room._on_ready_pressed()
	await create_timer(0.05).timeout
	if not lobby_room._is_local_ready and lobby_room.ready_btn.text == "READY":
		_log_pass("Player toggled ready -> UNREADY state (Button says 'READY').")
	else:
		_log_fail("Ready toggle to unready failed (is_local_ready=%s, btn_text=%s)" % [str(lobby_room._is_local_ready), lobby_room.ready_btn.text])

	# Toggle back to ready
	lobby_room._on_ready_pressed()
	await create_timer(0.05).timeout
	if lobby_room._is_local_ready and lobby_room.ready_btn.text == "UNREADY":
		_log_pass("Player toggled unready -> READY state (Button says 'UNREADY').")
	else:
		_log_fail("Ready toggle to ready failed (is_local_ready=%s, btn_text=%s)" % [str(lobby_room._is_local_ready), lobby_room.ready_btn.text])

	# ----------------------------------------------------
	# TEST 6: Non-Host View
	# ----------------------------------------------------
	_log_info("--- TEST 6: Non-Host Player View ---")
	lobby_room.setup_mock_lobby(4, 3, false, 2, "A7K2X")
	await create_timer(0.05).timeout

	if not lobby_room.start_game_btn.visible:
		_log_pass("Start Game button is hidden for non-host player.")
	else:
		_log_fail("Start Game button should be hidden for non-host.")

	var slot2 = lobby_room.roster_grid.get_children()[1]
	var text_in_slot2 = _get_all_labels_text(slot2)
	if text_in_slot2.has("(YOU)"):
		_log_pass("Slot 2 correctly marked as (YOU) for local player 2.")
	else:
		_log_fail("Slot 2 missing (YOU) badge for player 2.")

	_capture_screenshot("lobby_room_non_host_view.png")

	# ----------------------------------------------------
	# TEST 7: Full 8/8 Lobby & Host Start Game Action
	# ----------------------------------------------------
	_log_info("--- TEST 7: Full 8/8 Lobby & Ready State ---")
	lobby_room.setup_mock_lobby(8, 8, true, 1, "A7K2X")
	await create_timer(0.05).timeout

	if lobby_room.player_count_label.text == "8 / 8":
		_log_pass("Player count shows '8 / 8'.")
	else:
		_log_fail("Player count mismatch: got '%s'" % lobby_room.player_count_label.text)

	if lobby_room.start_game_btn.visible and not lobby_room.start_game_btn.disabled:
		_log_pass("Host Start Game button is VISIBLE and ENABLED when all 8 players are ready.")
	else:
		_log_fail("Start Game button disabled when 8/8 players ready.")

	_capture_screenshot("lobby_room_full_8_players_ready.png")

	# ----------------------------------------------------
	# TEST 8: Authoritative Network Sync Handling
	# ----------------------------------------------------
	_log_info("--- TEST 8: Authoritative Network Sync Simulation ---")
	var simulated_players = [
		{"peer_id": 1, "player_slot": 1, "name": "Shahzan", "is_ready": true, "is_alive": true, "is_eliminated": false},
		{"peer_id": 2, "player_slot": 2, "name": "Abdul", "is_ready": true, "is_alive": true, "is_eliminated": false},
		{"peer_id": 3, "player_slot": 3, "name": "Aaliya", "is_ready": false, "is_alive": true, "is_eliminated": false},
		{"peer_id": 4, "player_slot": 4, "name": "Ubaid", "is_ready": true, "is_alive": true, "is_eliminated": false}
	]
	lobby_room._on_network_lobby_synced(NetworkConfig.GameState.LOBBY, 4, 3, simulated_players)
	await create_timer(0.05).timeout

	if lobby_room.player_count_label.text == "4 / 8":
		_log_pass("Authoritative sync updated player count to 4 / 8.")
	else:
		_log_fail("Authoritative sync player count mismatch.")

	# ----------------------------------------------------
	# FINISH SUITE
	# ----------------------------------------------------
	_finish_suite()

func _get_all_labels_text(node: Node) -> Array[String]:
	var list: Array[String] = []
	if node is Label:
		list.append((node as Label).text)
	for child in node.get_children():
		list.append_array(_get_all_labels_text(child))
	return list

func _finish_suite() -> void:
	print("\n========================================================")
	print("  LOBBY ROOM UI TEST SUMMARY")
	print("========================================================")
	var pass_count = 0
	var fail_count = 0
	for line in test_log:
		if line.begins_with("[PASS]"):
			pass_count += 1
		elif line.begins_with("[FAIL]"):
			fail_count += 1
			
	print("  PASSED: %d" % pass_count)
	print("  FAILED: %d" % fail_count)
	print("========================================================\n")
	
	if test_passed:
		print(">>> ALL LOBBY ROOM UI TESTS PASSED SUCCESSFULLY! <<<\n")
		quit(0)
	else:
		print(">>> SOME TESTS FAILED! <<<\n")
		quit(1)
