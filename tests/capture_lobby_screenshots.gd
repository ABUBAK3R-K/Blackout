extends SceneTree

const LobbyRoomScene = preload("res://client/ui/screens/lobby_room.tscn")
const SCREENSHOT_DIR: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.tempmediaStorage"

var lobby_room = null

func _init() -> void:
	print("[SCREENSHOT] Capturing Lobby Room UI Screenshots...")
	call_deferred("_run_captures")

func _run_captures() -> void:
	DirAccess.make_dir_recursive_absolute(SCREENSHOT_DIR)
	
	lobby_room = LobbyRoomScene.instantiate()
	root.add_child(lobby_room)
	
	# State 1: Partial Lobby (4 / 8 players, Host view)
	lobby_room.setup_mock_lobby(4, 3, true, 1, "A7K2X")
	for i in range(12):
		await process_frame
		
	_save_viewport_png("lobby_room_partial_host.png")
	
	# State 2: Full Lobby (8 / 8 players all READY, Host view)
	lobby_room.setup_mock_lobby(8, 8, true, 1, "A7K2X")
	for i in range(12):
		await process_frame
		
	_save_viewport_png("lobby_room_full_ready_host.png")
	
	# State 3: Non-Host view (4 / 8 players, local is Player 2)
	lobby_room.setup_mock_lobby(4, 3, false, 2, "A7K2X")
	for i in range(12):
		await process_frame
		
	_save_viewport_png("lobby_room_non_host_view.png")
	
	print("[SCREENSHOT] All Lobby Room UI screenshots saved successfully.")
	quit(0)

func _save_viewport_png(filename: String) -> void:
	var img = root.get_viewport().get_texture().get_image()
	if img != null:
		var path = SCREENSHOT_DIR + "/" + filename
		var err = img.save_png(path)
		if err == OK:
			print("[SCREENSHOT] Saved: %s" % path)
		else:
			print("[SCREENSHOT] Error saving: %d" % err)
