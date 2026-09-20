extends SceneTree

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const InGameHUDScene = preload("res://client/ui/hud/hud.tscn")
const VictoryDefeatScreenUI = preload("res://client/ui/screens/victory_defeat_screen.gd")

var _screenshots_dir: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.tempmediaStorage/"

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n[TEST] Starting Victory / Defeat Splash Screen Validation...")
	
	# Instantiate InGameHUD
	var hud_instance = InGameHUDScene.instantiate()
	root.add_child(hud_instance)
	await _wait_seconds(0.4)
	
	var vic_screen = hud_instance.get_victory_defeat_screen() as Control
	assert(vic_screen != null, "VictoryDefeatScreen must exist in HUD tree")
	
	var title_lbl = vic_screen.find_child("OutcomeTitle", true, false) as Label
	var subtitle_lbl = vic_screen.find_child("SubtitleLabel", true, false) as Label
	var bg_img = vic_screen.find_child("BackgroundImage", true, false) as TextureRect
	var char_container = vic_screen.find_child("CharactersContainer", true, false) as Control
	
	assert(title_lbl != null, "OutcomeTitle label must exist")
	assert(subtitle_lbl != null, "SubtitleLabel must exist")
	assert(bg_img != null, "BackgroundImage must exist")
	assert(char_container != null, "CharactersContainer must exist")
	
	if hud_instance.get_task_checklist() != null:
		hud_instance.get_task_checklist().visible = false
	if hud_instance.get_recovery_tracker() != null:
		hud_instance.get_recovery_tracker().visible = false
	if hud_instance.get_blackout_banner() != null:
		hud_instance.get_blackout_banner().visible = false
	if hud_instance.get_meltdown_hud() != null:
		hud_instance.get_meltdown_hud().visible = false
	if hud_instance.get_impostor_hud() != null:
		hud_instance.get_impostor_hud().visible = false
		
	var test_roster = [
		{"peer_id": 101, "player_slot": 1, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 102, "player_slot": 2, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 103, "player_slot": 3, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 104, "player_slot": 4, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 105, "player_slot": 5, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 106, "player_slot": 6, "role": NetworkConfig.PlayerRole.CREW, "is_alive": false, "is_eliminated": true}, # Ejected
		{"peer_id": 107, "player_slot": 7, "role": NetworkConfig.PlayerRole.IMPOSTOR, "is_alive": true, "is_eliminated": false},
		{"peer_id": 108, "player_slot": 8, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false}
	]
	
	# TEST 1: Crew Victory — Crew Perspective (Local Role: CREW)
	print("[TEST] 1. Testing Crew Victory from Crew Perspective (VICTORY)...")
	var crew_win_payload = {
		"winner_role": NetworkConfig.PlayerRole.CREW,
		"reason": MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
		"completed_emergency_systems": ["restore_power", "restore_cooling", "stabilize_orion"],
		"remaining_meltdown_time": 142.5,
		"impostor_was_alive": true,
		"player_roster": test_roster,
		"local_role": NetworkConfig.PlayerRole.CREW
	}
	vic_screen.play_victory_defeat(NetworkConfig.PlayerRole.CREW, NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, crew_win_payload)
	await _wait_seconds(0.8)
	
	assert(vic_screen.is_screen_active() == true, "Screen must be active")
	assert(title_lbl.text == "VICTORY", "OutcomeTitle must be VICTORY for winning Crew member")
	assert(char_container.get_child_count() == 6, "Must display exactly 6 surviving non-ejected Crew technicians")
	await _capture_screenshot("hud_victory_crew_perspective.png")
	
	# TEST 2: Crew Victory — Impostor Perspective (Local Role: IMPOSTOR)
	print("[TEST] 2. Testing Crew Victory from Impostor Perspective (DEFEAT)...")
	vic_screen.play_victory_defeat(NetworkConfig.PlayerRole.IMPOSTOR, NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, crew_win_payload)
	await _wait_seconds(0.8)
	
	assert(title_lbl.text == "DEFEAT", "OutcomeTitle must be DEFEAT for losing Impostor")
	assert(char_container.get_child_count() == 6, "Must still display surviving Crew lineup")
	await _capture_screenshot("hud_defeat_impostor_perspective.png")
	
	# TEST 3: Impostor Victory — Impostor Perspective (Local Role: IMPOSTOR)
	print("[TEST] 3. Testing Impostor Victory from Impostor Perspective (VICTORY)...")
	var imp_win_payload = {
		"winner_role": NetworkConfig.PlayerRole.IMPOSTOR,
		"reason": MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
		"completed_emergency_systems": ["restore_power"],
		"remaining_meltdown_time": 0.0,
		"impostor_was_alive": true,
		"player_roster": test_roster,
		"local_role": NetworkConfig.PlayerRole.IMPOSTOR
	}
	vic_screen.play_victory_defeat(NetworkConfig.PlayerRole.IMPOSTOR, NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED, imp_win_payload)
	await _wait_seconds(0.8)
	
	assert(title_lbl.text == "VICTORY", "OutcomeTitle must be VICTORY for winning Impostor")
	assert(char_container.get_child_count() == 1, "Must display only the single Impostor technician")
	await _capture_screenshot("hud_victory_impostor_perspective.png")
	
	# TEST 4: Impostor Victory — Crew Perspective (Local Role: CREW)
	print("[TEST] 4. Testing Impostor Victory from Crew Perspective (DEFEAT)...")
	vic_screen.play_victory_defeat(NetworkConfig.PlayerRole.CREW, NetworkConfig.PlayerRole.IMPOSTOR, MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED, imp_win_payload)
	await _wait_seconds(0.8)
	
	assert(title_lbl.text == "DEFEAT", "OutcomeTitle must be DEFEAT for losing Crewmate")
	assert(char_container.get_child_count() == 1, "Must display single Impostor technician on compromised background")
	await _capture_screenshot("hud_defeat_crew_perspective.png")
	
	# TEST 5: Sequence Transition into Result Screen
	print("[TEST] 5. Testing Sequence Completion & Transition...")
	var sequence_done = [false]
	vic_screen.sequence_completed.connect(func(_w, _r, _d): sequence_done[0] = true)
	vic_screen._finish_sequence()
	await _wait_seconds(0.6)
	
	assert(sequence_done[0] == true, "sequence_completed must be emitted")
	assert(vic_screen.visible == false, "VictoryDefeatScreen must fade out")
	
	var res_screen = hud_instance.get_result_screen()
	assert(res_screen.is_screen_active() == true, "ResultScreen must become active following VictoryDefeat completion")
	
	print("\n========================================================")
	print("  ALL VICTORY/DEFEAT SCREEN TESTS PASSED! (EXIT 0)")
	print("========================================================\n")
	quit(0)

func _wait_seconds(sec: float) -> void:
	await create_timer(sec).timeout

func _capture_screenshot(file_name: String) -> void:
	await process_frame
	await process_frame
	var vp = root.get_viewport()
	if vp:
		var img = vp.get_texture().get_image()
		if img and not img.is_empty():
			var full_path = _screenshots_dir + file_name
			img.save_png(full_path)
			print("[TEST] Saved screenshot: %s" % full_path)
