class_name MainMenu
extends Control

## MainMenu — Member 5 (UI/UX Frontend)
## Authoritative & Standalone Main Menu for BLACKOUT.
##
## Features:
## - Clean background integration with Asterion Research Facility visual aesthetic.
## - Pixel-accurate button hierarchy with active glowing PLAY selection.
## - Interactive Play / Lobby Connection modal.
## - Settings modal (Audio, Video, Controls).
## - Credits modal (Facility lore and team credits).
## - Seamless transition to in-game HUD / lobby.

signal play_pressed()
signal settings_pressed()
signal credits_pressed()
signal exit_pressed()

@onready var background_texture: TextureRect = find_child("BackgroundTexture", true, false)
@onready var play_btn: Button = find_child("PlayButton", true, false)
@onready var settings_btn: Button = find_child("SettingsButton", true, false)
@onready var credits_btn: Button = find_child("CreditsButton", true, false)
@onready var exit_btn: Button = find_child("ExitButton", true, false)

@onready var play_modal: PanelContainer = find_child("PlayModal", true, false)
@onready var join_game_modal: PanelContainer = find_child("JoinGameModal", true, false)
@onready var create_lobby_modal: PanelContainer = find_child("CreateLobbyModal", true, false)
@onready var settings_modal: PanelContainer = find_child("SettingsModal", true, false)
@onready var credits_modal: PanelContainer = find_child("CreditsModal", true, false)
@onready var modal_overlay: ColorRect = find_child("ModalOverlay", true, false)

@onready var host_code_label: Label = find_child("HostCodeLabel", true, false)
@onready var join_code_input: LineEdit = find_child("JoinCodeInput", true, false)

var _generated_lobby_code: String = "A7K2X"

func _ready() -> void:
	_ensure_references()
	_connect_signals()
	_close_all_modals()
	_setup_button_focus_effects()

func _ensure_references() -> void:
	if background_texture == null:
		background_texture = find_child("BackgroundTexture", true, false) as TextureRect
	if play_btn == null:
		play_btn = find_child("PlayButton", true, false) as Button
	if settings_btn == null:
		settings_btn = find_child("SettingsButton", true, false) as Button
	if credits_btn == null:
		credits_btn = find_child("CreditsButton", true, false) as Button
	if exit_btn == null:
		exit_btn = find_child("ExitButton", true, false) as Button
	if play_modal == null:
		play_modal = find_child("PlayModal", true, false) as PanelContainer
	if join_game_modal == null:
		join_game_modal = find_child("JoinGameModal", true, false) as PanelContainer
	if create_lobby_modal == null:
		create_lobby_modal = find_child("CreateLobbyModal", true, false) as PanelContainer
	if settings_modal == null:
		settings_modal = find_child("SettingsModal", true, false) as PanelContainer
	if credits_modal == null:
		credits_modal = find_child("CreditsModal", true, false) as PanelContainer
	if modal_overlay == null:
		modal_overlay = find_child("ModalOverlay", true, false) as ColorRect
	if host_code_label == null:
		host_code_label = find_child("HostCodeLabel", true, false) as Label
	if join_code_input == null:
		join_code_input = find_child("JoinCodeInput", true, false) as LineEdit

func _connect_signals() -> void:
	if play_btn != null and not play_btn.pressed.is_connected(_on_play_pressed):
		play_btn.pressed.connect(_on_play_pressed)
	if settings_btn != null and not settings_btn.pressed.is_connected(_on_settings_pressed):
		settings_btn.pressed.connect(_on_settings_pressed)
	if credits_btn != null and not credits_btn.pressed.is_connected(_on_credits_pressed):
		credits_btn.pressed.connect(_on_credits_pressed)
	if exit_btn != null and not exit_btn.pressed.is_connected(_on_exit_pressed):
		exit_btn.pressed.connect(_on_exit_pressed)

func _setup_button_focus_effects() -> void:
	pass

func _on_play_pressed() -> void:
	print("[MainMenu] Play pressed.")
	play_pressed.emit()
	_show_modal(play_modal)

func _on_settings_pressed() -> void:
	print("[MainMenu] Settings pressed.")
	settings_pressed.emit()
	_show_modal(settings_modal)

func _on_credits_pressed() -> void:
	print("[MainMenu] Credits pressed.")
	credits_pressed.emit()
	_show_modal(credits_modal)

func _on_exit_pressed() -> void:
	print("[MainMenu] Exit pressed.")
	exit_pressed.emit()
	get_tree().quit()

func _generate_lobby_code() -> String:
	var chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code = ""
	for i in range(5):
		code += chars[randi() % chars.length()]
	return code

func _show_modal(modal: PanelContainer) -> void:
	_close_all_modals()
	if modal_overlay != null:
		modal_overlay.visible = true
	if modal != null:
		modal.visible = true
		modal.scale = Vector2(0.95, 0.95)
		var tween = create_tween()
		tween.tween_property(modal, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _close_all_modals() -> void:
	if modal_overlay != null:
		modal_overlay.visible = false
	if play_modal != null:
		play_modal.visible = false
	if join_game_modal != null:
		join_game_modal.visible = false
	if create_lobby_modal != null:
		create_lobby_modal.visible = false
	if settings_modal != null:
		settings_modal.visible = false
	if credits_modal != null:
		credits_modal.visible = false

func _on_close_modal_pressed() -> void:
	_close_all_modals()
	if play_btn != null:
		play_btn.grab_focus()

func _on_open_play_modal_pressed() -> void:
	_show_modal(play_modal)

func _on_open_create_lobby_pressed() -> void:
	_ensure_references()
	_generated_lobby_code = _generate_lobby_code()
	if host_code_label != null:
		host_code_label.text = _generated_lobby_code
	_show_modal(create_lobby_modal)

func _on_open_join_game_pressed() -> void:
	_ensure_references()
	if join_code_input != null:
		join_code_input.text = "A7K2X"
		join_code_input.grab_focus()
	_show_modal(join_game_modal)

func _on_enter_lobby_pressed() -> void:
	print("[MainMenu] Entering created lobby with code: %s" % _generated_lobby_code)
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null:
			if net_mgr.has_method("start_host"):
				net_mgr.start_host(7777, 8)
			if net_mgr.has_method("connect_client"):
				net_mgr.connect_client("127.0.0.1", 7777)
	get_tree().change_scene_to_file("res://client/ui/screens/lobby_room.tscn")

func _on_join_lobby_pressed() -> void:
	var code = "A7K2X"
	if join_code_input != null and not join_code_input.text.is_empty():
		code = join_code_input.text.strip_edges().to_upper()
	print("[MainMenu] Joining lobby with code: %s" % code)
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and net_mgr.has_method("start_client"):
			net_mgr.start_client("127.0.0.1", 7777)
	get_tree().change_scene_to_file("res://client/ui/screens/lobby_room.tscn")

func _on_launch_hud_test_pressed() -> void:
	print("[MainMenu] Launching HUD Sandbox / Test Scene...")
	get_tree().change_scene_to_file("res://client/ui/hud/hud.tscn")
