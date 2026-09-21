extends SceneTree

const MAIN_MENU_SCENE = preload("res://client/ui/menu/main_menu.tscn")
const SCREENSHOT_DIR = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.tempmediaStorage"

func _init() -> void:
	print("[TEST] Starting Main Menu UI Validation with Join & Host modals...")
	call_deferred("_run_tests")

func _run_tests() -> void:
	var menu = MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	
	for i in range(10):
		await process_frame
		
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	
	var play_btn = menu.find_child("PlayButton", true, false) as Button
	var settings_btn = menu.find_child("SettingsButton", true, false) as Button
	var credits_btn = menu.find_child("CreditsButton", true, false) as Button
	var exit_btn = menu.find_child("ExitButton", true, false) as Button
	
	assert(play_btn != null, "PlayButton must exist in MainMenu")
	assert(settings_btn != null, "SettingsButton must exist in MainMenu")
	assert(credits_btn != null, "CreditsButton must exist in MainMenu")
	assert(exit_btn != null, "ExitButton must exist in MainMenu")
	
	# TEST 1: Open Play Modal -> Join Game
	print("[TEST] 1. Testing Join Game Modal...")
	play_btn.pressed.emit()
	await _wait_seconds(0.3)
	var join_btn = menu.find_child("JoinBtn", true, false) as Button
	assert(join_btn != null, "JoinBtn must exist in PlayModal")
	join_btn.pressed.emit()
	await _wait_seconds(0.4)
	
	var join_modal = menu.find_child("JoinGameModal", true, false) as PanelContainer
	var join_code_input = menu.find_child("JoinCodeInput", true, false) as LineEdit
	var join_lobby_btn = menu.find_child("JoinLobbyBtn", true, false) as Button
	var back_join_btn = menu.find_child("BackJoinBtn", true, false) as Button
	
	assert(join_modal != null and join_modal.visible == true, "JoinGameModal must be visible")
	assert(join_code_input != null, "JoinCodeInput LineEdit must exist")
	assert(join_lobby_btn != null, "JoinLobbyBtn must exist")
	assert(back_join_btn != null, "BackJoinBtn must exist")
	_capture_screenshot("main_menu_join_game.png")
	
	# Back to Play Modal
	back_join_btn.pressed.emit()
	await _wait_seconds(0.3)
	
	# TEST 2: Open Create Lobby (Host Game)
	print("[TEST] 2. Testing Create Lobby Modal...")
	var host_btn = menu.find_child("HostBtn", true, false) as Button
	assert(host_btn != null, "HostBtn must exist in PlayModal")
	host_btn.pressed.emit()
	await _wait_seconds(0.4)
	
	var create_modal = menu.find_child("CreateLobbyModal", true, false) as PanelContainer
	var host_code_label = menu.find_child("HostCodeLabel", true, false) as Label
	var enter_lobby_btn = menu.find_child("EnterLobbyBtn", true, false) as Button
	var back_host_btn = menu.find_child("BackHostBtn", true, false) as Button
	
	assert(create_modal != null and create_modal.visible == true, "CreateLobbyModal must be visible")
	assert(host_code_label != null and not host_code_label.text.is_empty(), "HostCodeLabel must have generated code")
	assert(enter_lobby_btn != null, "EnterLobbyBtn must exist")
	assert(back_host_btn != null, "BackHostBtn must exist")
	_capture_screenshot("main_menu_create_lobby.png")
	
	# Back to Play Modal and Close
	back_host_btn.pressed.emit()
	await _wait_seconds(0.3)
	var close_play = menu.find_child("ClosePlayModal", true, false) as Button
	close_play.pressed.emit()
	await _wait_seconds(0.3)
	
	print("\n========================================================")
	print("  ALL JOIN & HOST MODAL TESTS PASSED! (EXIT 0)")
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
