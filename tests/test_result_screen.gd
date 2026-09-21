extends SceneTree

const HUD_SCENE = preload("res://client/ui/hud/hud.tscn")
const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const SCREENSHOT_DIR = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.tempmediaStorage"

func _init() -> void:
	print("[TEST] Starting Authoritative Game Over / Result Screen Validation...")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var hud = HUD_SCENE.instantiate()
	root.add_child(hud)
	
	for i in range(10):
		await process_frame
		
	var result_screen = hud.get_result_screen()
	assert(result_screen != null, "ResultScreen must be instanced in InGameHUD")
	
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	
	var test_roster = [
		{"peer_id": 101, "player_slot": 1, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 102, "player_slot": 2, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 103, "player_slot": 3, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 104, "player_slot": 4, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 105, "player_slot": 5, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 106, "player_slot": 6, "role": NetworkConfig.PlayerRole.CREW, "is_alive": false, "is_eliminated": true},
		{"peer_id": 107, "player_slot": 7, "role": NetworkConfig.PlayerRole.IMPOSTOR, "is_alive": true, "is_eliminated": false},
		{"peer_id": 108, "player_slot": 8, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false}
	]
	
	# TEST 1: Crew Victory Presentation
	print("[TEST] 1. Testing CREW VICTORY Presentation...")
	var crew_payload = {
		"winner_role": NetworkConfig.PlayerRole.CREW,
		"reason": MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		"completed_emergency_systems": ["restore_power", "restore_cooling", "stabilize_orion"],
		"remaining_meltdown_time": 218.0,
		"impostor_was_alive": true,
		"player_roster": test_roster
	}
	result_screen.show_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, crew_payload)
	await _wait_seconds(1.0)
	
	var roster_title = result_screen.find_child("RosterTitleLabel", true, false) as Label
	var roster_count = result_screen.find_child("RosterCountLabel", true, false) as Label
	var stats_title = result_screen.find_child("StatsTitleLabel", true, false) as Label
	var grid = result_screen.find_child("PlayersGrid", true, false) as GridContainer
	
	assert(roster_title != null and roster_title.text == "FINAL ROSTER", "Roster title must be FINAL ROSTER")
	assert(roster_count != null and roster_count.text == "8 / 8", "Roster count must be 8 / 8")
	assert(stats_title != null and stats_title.text == "MISSION SUMMARY", "Stats title must be MISSION SUMMARY")
	assert(grid.get_child_count() == 8, "All 8 players must be present in roster")
	assert(result_screen.is_screen_active() == true, "is_screen_active must be true")
	_capture_screenshot("hud_game_over_crew_win.png")
	
	# TEST 2: Impostor Victory Presentation
	print("[TEST] 2. Testing IMPOSTOR VICTORY Presentation...")
	var impostor_payload = {
		"winner_role": NetworkConfig.PlayerRole.IMPOSTOR,
		"reason": MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		"completed_emergency_systems": ["restore_power"],
		"remaining_meltdown_time": 0.0,
		"impostor_was_alive": true,
		"player_roster": test_roster
	}
	result_screen.show_game_over(NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED, impostor_payload)
	await _wait_seconds(1.0)
	
	assert(grid.get_child_count() == 8, "All 8 players must be present in roster")
	_capture_screenshot("hud_game_over_impostor_win.png")
	
	# TEST 3: Robustness against Missing / Empty Fields
	print("[TEST] 3. Testing Missing Payload Robustness...")
	result_screen.show_game_over(0, 0, {})
	await _wait_seconds(0.5)
	assert(result_screen.is_screen_active() == true, "Must not crash with empty result dictionary")
	
	# TEST 4: Return Button and Dismissal
	print("[TEST] 4. Testing Return to Lobby Action...")
	var return_btn = result_screen.find_child("ReturnButton", true, false) as Button
	assert(return_btn != null, "ReturnButton must exist")
	var return_emitted = [false]
	result_screen.return_to_lobby_requested.connect(func(): return_emitted[0] = true)
	return_btn.pressed.emit()
	assert(return_emitted[0] == true, "return_to_lobby_requested signal must emit on button press")
	
	result_screen.hide_screen()
	await _wait_seconds(0.4)
	assert(result_screen.visible == false, "Result screen must be hidden after hide_screen")
	assert(result_screen.is_screen_active() == false, "is_screen_active must be false after hide")
	
	print("\n========================================================")
	print("  ALL RESULT SCREEN TESTS PASSED SUCCESSFULLY! (EXIT 0)")
	print("========================================================\n")
	quit(0)

func _wait_seconds(sec: float) -> void:
	var target = Time.get_ticks_msec() + int(sec * 1000)
	while Time.get_ticks_msec() < target:
		await process_frame

func _capture_screenshot(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img != null:
		var path = SCREENSHOT_DIR + "/" + filename
		img.save_png(path)
		print("[TEST] Saved screenshot: %s" % path)
