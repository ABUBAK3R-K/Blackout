class_name LobbyRoom
extends Control

## LobbyRoom — Member 5 (UI/UX Frontend)
## Authoritative Multiplayer Lobby & Waiting Room for BLACKOUT.
##
## Features:
## - Industrial nuclear facility aesthetic (dark blue-gray, cyan accents, restrained red emergency alerts).
## - Consumes authoritative lobby state, player list, ready statuses, and host permissions from NetworkManager.
## - 8-slot roster with Asterion departmental technician avatars and ready badges.
## - Prominent authoritative Lobby Code display with clipboard copy action.
## - Local player Ready / Unready toggle.
## - Host-only Start Game action following authoritative permission.
## - Leave Lobby action returning cleanly to the Main Menu.
## - Offline preview & test harness support.

signal ready_toggled(is_ready: bool)
signal start_game_pressed()
signal leave_lobby_pressed()
signal lobby_code_copied(code: String)

const NetworkConfig = preload("res://shared/network_config.gd")

## Official 8-Player Department Colors (Asterion Nuclear Research Facility)
const PLAYER_PALETTE: Array[Color] = [
	Color(0.12, 0.35, 0.75), # 1. Navy Blue   (Engineering)
	Color(0.92, 0.40, 0.08), # 2. Safety Orange(Maintenance)
	Color(0.92, 0.72, 0.05), # 3. Hazard Yellow(Radiation Safety)
	Color(0.38, 0.44, 0.52), # 4. Steel Gray   (Technical Operations)
	Color(0.12, 0.65, 0.32), # 5. Lab Green    (Scientific Personnel)
	Color(0.85, 0.18, 0.22), # 6. Emergency Red(Security / Response)
	Color(0.04, 0.62, 0.72), # 7. Electric Cyan(Diagnostics)
	Color(0.88, 0.90, 0.94)  # 8. Cleanroom White(Reactor Physics)
]

const DEPARTMENT_NAMES: Array[String] = [
	"Engineering",
	"Maintenance",
	"Rad-Safety",
	"Operations",
	"Science",
	"Security",
	"Diagnostics",
	"Reactor"
]

const COLOR_CYAN_ACCENT: Color = Color(0.0, 0.90, 1.0, 1.0)
const COLOR_READY_GREEN: Color = Color(0.20, 0.85, 0.40, 1.0)
const COLOR_WAITING_MUTED: Color = Color(0.45, 0.55, 0.68, 0.9)
const COLOR_HOST_GOLD: Color = Color(0.95, 0.78, 0.20, 1.0)
const COLOR_ALERT_RED: Color = Color(0.90, 0.25, 0.30, 1.0)

## Node references
@onready var lobby_code_label: Label = find_child("LobbyCodeLabel", true, false)
@onready var copy_code_btn: Button = find_child("CopyCodeButton", true, false)
@onready var player_count_label: Label = find_child("PlayerCountLabel", true, false)
@onready var status_message_label: Label = find_child("StatusMessageLabel", true, false)
@onready var status_pulse_dot: Control = find_child("StatusPulseDot", true, false)
@onready var roster_grid: GridContainer = find_child("RosterGrid", true, false)
@onready var ready_btn: Button = find_child("ReadyButton", true, false)
@onready var start_game_btn: Button = find_child("StartGameButton", true, false)
@onready var leave_btn: Button = find_child("LeaveButton", true, false)
@onready var host_badge_pill: PanelContainer = find_child("HostBadgePill", true, false)

## Internal state
var _lobby_code: String = "A7K2X"
var _is_local_ready: bool = false
var _is_local_host: bool = false
var _local_peer_id: int = 1
var _local_slot: int = 1
var _connected_players: Array = [] # Array of player dicts
var _copy_reset_timer: SceneTreeTimer = null
var _pulse_time: float = 0.0

func _ready() -> void:
	_ensure_references()
	_connect_ui_signals()
	_connect_network_signals()
	
	# Initial rendering pass
	_refresh_network_state()
	_update_ui_presentation()

func _process(delta: float) -> void:
	_pulse_time += delta * 3.0
	if status_pulse_dot != null and is_instance_valid(status_pulse_dot):
		var alpha = (sin(_pulse_time) * 0.35) + 0.65
		status_pulse_dot.modulate.a = alpha

func _ensure_references() -> void:
	if lobby_code_label == null:
		lobby_code_label = find_child("LobbyCodeLabel", true, false) as Label
	if copy_code_btn == null:
		copy_code_btn = find_child("CopyCodeButton", true, false) as Button
	if player_count_label == null:
		player_count_label = find_child("PlayerCountLabel", true, false) as Label
	if status_message_label == null:
		status_message_label = find_child("StatusMessageLabel", true, false) as Label
	if status_pulse_dot == null:
		status_pulse_dot = find_child("StatusPulseDot", true, false) as Control
	if roster_grid == null:
		roster_grid = find_child("RosterGrid", true, false) as GridContainer
	if ready_btn == null:
		ready_btn = find_child("ReadyButton", true, false) as Button
	if start_game_btn == null:
		start_game_btn = find_child("StartGameButton", true, false) as Button
	if leave_btn == null:
		leave_btn = find_child("LeaveButton", true, false) as Button
	if host_badge_pill == null:
		host_badge_pill = find_child("HostBadgePill", true, false) as PanelContainer

func _connect_ui_signals() -> void:
	if copy_code_btn != null and not copy_code_btn.pressed.is_connected(_on_copy_code_pressed):
		copy_code_btn.pressed.connect(_on_copy_code_pressed)
	if ready_btn != null and not ready_btn.pressed.is_connected(_on_ready_pressed):
		ready_btn.pressed.connect(_on_ready_pressed)
	if start_game_btn != null and not start_game_btn.pressed.is_connected(_on_start_game_pressed):
		start_game_btn.pressed.connect(_on_start_game_pressed)
	if leave_btn != null and not leave_btn.pressed.is_connected(_on_leave_pressed):
		leave_btn.pressed.connect(_on_leave_pressed)

func _connect_network_signals() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("lobby_synced") and not client.lobby_synced.is_connected(_on_network_lobby_synced):
				client.lobby_synced.connect(_on_network_lobby_synced)
			if client.has_signal("ready_state_updated") and not client.ready_state_updated.is_connected(_on_network_ready_state_updated):
				client.ready_state_updated.connect(_on_network_ready_state_updated)
			if client.has_signal("player_assigned") and not client.player_assigned.is_connected(_on_network_player_assigned):
				client.player_assigned.connect(_on_network_player_assigned)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_network_game_state_changed):
				client.game_state_changed.connect(_on_network_game_state_changed)
			if client.has_signal("disconnected_from_server") and not client.disconnected_from_server.is_connected(_on_network_disconnected):
				client.disconnected_from_server.connect(_on_network_disconnected)

## Read current authoritative data from NetworkManager if available
func _refresh_network_state() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			_local_peer_id = client.assigned_peer_id if client.assigned_peer_id > 0 else 1
			_local_slot = client.assigned_slot if client.assigned_slot > 0 else 1
			_is_local_ready = client.is_ready
			
			# Host determination: slot 1, peer_id 1, or is_server
			_is_local_host = (client.assigned_slot == 1 or client.assigned_peer_id == 1 or net_mgr.is_server())
			
			if not client.lobby_players_data.is_empty():
				_connected_players = client.lobby_players_data.duplicate()
			elif _connected_players.is_empty():
				# Single local entry while connecting
				_connected_players = [{
					"peer_id": _local_peer_id,
					"player_slot": _local_slot,
					"is_ready": _is_local_ready,
					"is_alive": true,
					"is_eliminated": false
				}]
	else:
		# Standalone preview fallback
		if _connected_players.is_empty():
			setup_mock_lobby(4, 3, true, 1, "A7K2X")

## Public Mock / Test API for offline testing and verification
func setup_mock_lobby(player_count: int = 4, ready_count: int = 3, is_host: bool = true, local_slot: int = 1, code: String = "A7K2X") -> void:
	_lobby_code = code
	_is_local_host = is_host
	_local_slot = local_slot
	_local_peer_id = local_slot
	
	_connected_players.clear()
	var mock_names = ["Shahzan", "Abdul", "Aaliya", "Ubaid", "Tariq", "Zainab", "Hamza", "Fatima"]
	
	for i in range(clampi(player_count, 1, 8)):
		var slot_num = i + 1
		var is_ready = (i < ready_count)
		if slot_num == local_slot:
			_is_local_ready = is_ready
		_connected_players.append({
			"peer_id": 100 + slot_num,
			"player_slot": slot_num,
			"name": mock_names[i % mock_names.size()],
			"is_ready": is_ready,
			"is_alive": true,
			"is_eliminated": false
		})
	
	_update_ui_presentation()

## Update the full UI presentation based on current state
func _update_ui_presentation() -> void:
	_ensure_references()
	
	# 1. Update Lobby Code
	if lobby_code_label != null:
		lobby_code_label.text = _lobby_code
	
	# 2. Update Header Player Count
	var current_count: int = _connected_players.size()
	var max_count: int = NetworkConfig.MAX_PLAYERS
	if player_count_label != null:
		player_count_label.text = "%d / %d" % [current_count, max_count]
	
	# 3. Calculate Ready Summary
	var ready_count: int = 0
	for p in _connected_players:
		if bool(p.get("is_ready", false)):
			ready_count += 1
	
	# 4. Update Status Banner Message
	if status_message_label != null:
		if current_count < max_count:
			status_message_label.text = "WAITING FOR PLAYERS (%d / %d) • %d READY" % [current_count, max_count, ready_count]
			status_message_label.add_theme_color_override("font_color", Color(0.80, 0.88, 0.95, 0.9))
		elif ready_count < max_count:
			status_message_label.text = "ALL PLAYERS CONNECTED • AWAITING READY PROTOCOL (%d / %d)" % [ready_count, max_count]
			status_message_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.20, 0.95))
		else:
			status_message_label.text = "ALL PERSONNEL READY • READY TO COMMENCE OPERATION"
			status_message_label.add_theme_color_override("font_color", COLOR_CYAN_ACCENT)
	
	# 5. Populate 8-Slot Player Roster Grid
	_populate_roster_grid()
	
	# 6. Update Local Action Buttons
	_update_action_buttons(ready_count, current_count)

## Build 8 Roster Cards (Occupied + Vacant Slots)
func _populate_roster_grid() -> void:
	if roster_grid == null:
		return
	
	for child in roster_grid.get_children():
		child.queue_free()
	
	# Build map of occupied slots: slot -> player_dict
	var slot_map: Dictionary = {}
	for p in _connected_players:
		var s = int(p.get("player_slot", 1))
		slot_map[s] = p
	
	# Render 8 slots in ordered fashion
	for slot_idx in range(1, NetworkConfig.MAX_PLAYERS + 1):
		if slot_map.has(slot_idx):
			var player_data: Dictionary = slot_map[slot_idx]
			var card = _build_occupied_player_card(slot_idx, player_data)
			roster_grid.add_child(card)
		else:
			var vacant_card = _build_vacant_slot_card(slot_idx)
			roster_grid.add_child(vacant_card)

## Build an Occupied Player Card
func _build_occupied_player_card(slot: int, player_data: Dictionary) -> Control:
	var pid = int(player_data.get("peer_id", slot))
	var is_ready = bool(player_data.get("is_ready", false))
	var is_host_player = (slot == 1)
	var is_local = (slot == _local_slot or pid == _local_peer_id)
	var custom_name = player_data.get("name", "")
	
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(275, 62)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.14, 0.95) if not is_local else Color(0.06, 0.12, 0.19, 0.98)
	style.set_border_width_all(1)
	if is_local:
		style.border_color = Color(0.0, 0.85, 1.0, 0.90)
	elif is_host_player:
		style.border_color = Color(0.85, 0.70, 0.20, 0.70)
	elif is_ready:
		style.border_color = Color(0.18, 0.65, 0.35, 0.65)
	else:
		style.border_color = Color(0.14, 0.22, 0.32, 0.75)
		
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	
	# 1. Mini Technician Avatar
	var avatar = _create_mini_avatar(slot, true)
	hbox.add_child(avatar)
	
	# 2. Player Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	var name_hbox = HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 6)
	info_vbox.add_child(name_hbox)
	
	var name_lbl = Label.new()
	if not custom_name.is_empty():
		name_lbl.text = custom_name
	else:
		name_lbl.text = "Player %d" % (pid if pid > 0 and pid < 1000 else slot)
		
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 1.0))
	name_hbox.add_child(name_lbl)
	
	if is_local:
		var you_badge = Label.new()
		you_badge.text = "(YOU)"
		you_badge.add_theme_font_size_override("font_size", 10)
		you_badge.add_theme_color_override("font_color", COLOR_CYAN_ACCENT)
		name_hbox.add_child(you_badge)
	
	var dept_name = DEPARTMENT_NAMES[clampi(slot - 1, 0, DEPARTMENT_NAMES.size() - 1)]
	var dept_lbl = Label.new()
	dept_lbl.text = dept_name
	dept_lbl.add_theme_font_size_override("font_size", 11)
	dept_lbl.add_theme_color_override("font_color", Color(0.48, 0.58, 0.70, 0.9))
	info_vbox.add_child(dept_lbl)
	
	# 3. Status Badges Column (Host Badge + Ready Badge)
	var badge_vbox = VBoxContainer.new()
	badge_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(badge_vbox)
	
	if is_host_player:
		var host_badge = _build_pill_badge("HOST", Color(0.95, 0.78, 0.20), Color(0.18, 0.14, 0.04, 0.85))
		badge_vbox.add_child(host_badge)
	
	var ready_badge = _build_pill_badge(
		"READY" if is_ready else "WAITING",
		COLOR_READY_GREEN if is_ready else COLOR_WAITING_MUTED,
		Color(0.03, 0.15, 0.08, 0.85) if is_ready else Color(0.06, 0.09, 0.14, 0.75)
	)
	badge_vbox.add_child(ready_badge)
	
	return card

## Build a Vacant / Standby Slot Card
func _build_vacant_slot_card(slot: int) -> Control:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(275, 62)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.08, 0.55)
	style.set_border_width_all(1)
	style.border_color = Color(0.10, 0.15, 0.22, 0.45)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	card.add_child(hbox)
	
	# Dimmed slot indicator
	var avatar = _create_mini_avatar(slot, false)
	avatar.modulate = Color(1, 1, 1, 0.3)
	hbox.add_child(avatar)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	var vacant_lbl = Label.new()
	vacant_lbl.text = "[ VACANT SLOT %d ]" % slot
	vacant_lbl.add_theme_font_size_override("font_size", 12)
	vacant_lbl.add_theme_color_override("font_color", Color(0.35, 0.42, 0.52, 0.6))
	info_vbox.add_child(vacant_lbl)
	
	var wait_lbl = Label.new()
	wait_lbl.text = "Awaiting Personnel Connection..."
	wait_lbl.add_theme_font_size_override("font_size", 10)
	wait_lbl.add_theme_color_override("font_color", Color(0.28, 0.34, 0.42, 0.5))
	info_vbox.add_child(wait_lbl)
	
	return card

func _build_pill_badge(text: String, accent_color: Color, bg_color: Color) -> Control:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_border_width_all(1)
	style.border_color = accent_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	panel.add_theme_stylebox_override("panel", style)
	
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", accent_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(lbl)
	return panel

## Update Action Buttons (Ready / Start Game / Leave)
func _update_action_buttons(ready_count: int, total_count: int) -> void:
	# 1. Ready Button
	if ready_btn != null:
		if _is_local_ready:
			ready_btn.text = "UNREADY"
			var style_unready = StyleBoxFlat.new()
			style_unready.bg_color = Color(0.18, 0.12, 0.04, 0.9)
			style_unready.border_color = Color(0.95, 0.70, 0.20, 0.95)
			style_unready.set_border_width_all(1)
			style_unready.set_corner_radius_all(6)
			ready_btn.add_theme_stylebox_override("normal", style_unready)
			ready_btn.add_theme_color_override("font_color", Color(0.95, 0.75, 0.20))
		else:
			ready_btn.text = "READY"
			var style_ready = StyleBoxFlat.new()
			style_ready.bg_color = Color(0.04, 0.18, 0.22, 0.9)
			style_ready.border_color = COLOR_CYAN_ACCENT
			style_ready.set_border_width_all(1)
			style_ready.set_corner_radius_all(6)
			ready_btn.add_theme_stylebox_override("normal", style_ready)
			ready_btn.add_theme_color_override("font_color", COLOR_CYAN_ACCENT)
	
	# 2. Start Game Button (Host Only)
	if start_game_btn != null:
		if _is_local_host:
			start_game_btn.visible = true
			# Can start if exactly 8 players are connected and all 8 are ready (or in dev testing if server allows)
			var can_start = (total_count == NetworkConfig.MAX_PLAYERS and ready_count == NetworkConfig.MAX_PLAYERS)
			start_game_btn.disabled = not can_start
			if can_start:
				start_game_btn.text = "START GAME"
				start_game_btn.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				start_game_btn.text = "START GAME (%d/%d READY)" % [ready_count, total_count]
				start_game_btn.modulate = Color(0.7, 0.7, 0.7, 0.8)
		else:
			start_game_btn.visible = false

# --- User Action Event Handlers ---

func _on_ready_pressed() -> void:
	var next_ready_state = not _is_local_ready
	print("[LobbyRoom] Local player requesting ready state: %s" % ("READY" if next_ready_state else "UNREADY"))
	
	var is_network_active: bool = false
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and (net_mgr.is_client() or net_mgr.is_server()):
			is_network_active = true
			if net_mgr.has_method("set_ready"):
				net_mgr.set_ready(next_ready_state)
	
	if not is_network_active:
		# Offline / preview toggle
		_is_local_ready = next_ready_state
		for p in _connected_players:
			if int(p.get("player_slot", 1)) == _local_slot or int(p.get("peer_id", 0)) == _local_peer_id:
				p["is_ready"] = _is_local_ready
		_update_ui_presentation()
	
	ready_toggled.emit(_is_local_ready)

func _on_start_game_pressed() -> void:
	if not _is_local_host:
		return
	print("[LobbyRoom] Host pressed Start Game.")
	start_game_pressed.emit()
	
	# If running server locally, trigger state advance or role assignment
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and net_mgr.is_server() and net_mgr.server != null:
			if net_mgr.server.has_method("assign_roles"):
				net_mgr.server.assign_roles()
	else:
		get_tree().change_scene_to_file("res://client/ui/hud/hud.tscn")

func _on_leave_pressed() -> void:
	print("[LobbyRoom] Leaving lobby room. Returning to Main Menu.")
	leave_lobby_pressed.emit()
	
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and net_mgr.has_method("stop_network"):
			net_mgr.stop_network()
			
	get_tree().change_scene_to_file("res://client/ui/menu/main_menu.tscn")

func _on_copy_code_pressed() -> void:
	DisplayServer.clipboard_set(_lobby_code)
	print("[LobbyRoom] Lobby code '%s' copied to clipboard." % _lobby_code)
	lobby_code_copied.emit(_lobby_code)
	
	if copy_code_btn != null:
		copy_code_btn.text = "COPIED!"
		if _copy_reset_timer != null:
			_copy_reset_timer.timeout.disconnect(_reset_copy_btn_text)
		_copy_reset_timer = get_tree().create_timer(1.8)
		_copy_reset_timer.timeout.connect(_reset_copy_btn_text)

func _reset_copy_btn_text() -> void:
	if copy_code_btn != null and is_instance_valid(copy_code_btn):
		copy_code_btn.text = "COPY CODE"

# --- Network Event Handlers ---

func _on_network_lobby_synced(state: int, player_count: int, ready_count: int, players: Array) -> void:
	print("[LobbyRoom] Received authoritative lobby sync: %d players, %d ready." % [player_count, ready_count])
	_connected_players = players.duplicate()
	_refresh_network_state()
	_update_ui_presentation()

func _on_network_ready_state_updated(is_ready: bool) -> void:
	_is_local_ready = is_ready
	_update_ui_presentation()

func _on_network_player_assigned(peer_id: int, slot: int, total_players: int) -> void:
	_local_peer_id = peer_id
	_local_slot = slot
	_is_local_host = (slot == 1 or peer_id == 1)
	_update_ui_presentation()

func _on_network_game_state_changed(new_state: int) -> void:
	if new_state == NetworkConfig.GameState.ROLE_ASSIGNMENT or new_state == NetworkConfig.GameState.INITIAL_TASK_PHASE:
		print("[LobbyRoom] Game state advanced to %s! Transitioning to In-Game HUD..." % NetworkConfig.get_game_state_name(new_state))
		get_tree().change_scene_to_file("res://client/ui/hud/hud.tscn")

func _on_network_disconnected(reason: String) -> void:
	print("[LobbyRoom] Disconnected from server: %s" % reason)
	get_tree().change_scene_to_file("res://client/ui/menu/main_menu.tscn")

# --- Procedural Mini Avatar Renderer (Official Asterion Tech Helmet) ---

func _create_mini_avatar(slot: int, is_active: bool) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(42, 42)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var color_index = clampi(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	var suit_color = PLAYER_PALETTE[color_index]
	if not is_active:
		suit_color = suit_color.darkened(0.4)
		
	var canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func(): _draw_mini_avatar_canvas(canvas, suit_color, is_active))
	root.add_child(canvas)
	return root

func _draw_mini_avatar_canvas(canvas: Control, base_color: Color, is_active: bool) -> void:
	var w = canvas.size.x
	var h = canvas.size.y
	var cx = w * 0.5
	var cy = h * 0.52
	
	# Background containment box
	var bg_rect = Rect2(1, 1, w - 2, h - 2)
	_draw_rounded_box(canvas, bg_rect, 4.0, Color(0.03, 0.05, 0.08, 0.95), true)
	_draw_rounded_box(canvas, bg_rect, 4.0, Color(0.14, 0.20, 0.28, 0.7), false, 1.0)
	
	# Mini Collar
	var collar_rect = Rect2(cx - 12, cy + 4, 24, 11)
	_draw_rounded_box(canvas, collar_rect, 3.0, Color(0.12, 0.15, 0.20, 1.0), true)
	if is_active:
		canvas.draw_rect(Rect2(cx + 4, cy + 6, 6, 2.5), Color(0.95, 0.75, 0.10, 1.0), true)
		canvas.draw_circle(Vector2(cx - 7, cy + 7.5), 1.2, Color(0.2, 0.95, 0.4, 1.0))
	
	# Helmet
	var helmet_rect = Rect2(cx - 11, cy - 14, 22, 19)
	var helmet_col = base_color if is_active else base_color.darkened(0.3)
	_draw_rounded_box(canvas, helmet_rect, 9.0, helmet_col, true)
	
	# Crown Ridge
	var ridge_rect = Rect2(cx - 3, cy - 15, 6, 8)
	_draw_rounded_box(canvas, ridge_rect, 2.0, helmet_col.lightened(0.2), true)
	_draw_rounded_box(canvas, helmet_rect, 9.0, Color(0.02, 0.03, 0.05, 0.95), false, 1.2)
	
	# Comm side tabs
	canvas.draw_rect(Rect2(cx - 13, cy - 8, 3, 8), Color(0.08, 0.10, 0.14, 1.0), true)
	canvas.draw_rect(Rect2(cx + 10, cy - 8, 3, 8), Color(0.08, 0.10, 0.14, 1.0), true)
	
	# Visor
	var visor_center = Vector2(cx, cy - 4.5)
	var visor_rx = 8.5
	var visor_ry = 4.5
	var visor_col = Color(0.15, 0.65, 0.85, 0.95) if is_active else Color(0.20, 0.35, 0.45, 0.65)
	_draw_ellipse(canvas, visor_center, visor_rx + 1.0, visor_ry + 1.0, Color(0.02, 0.03, 0.05, 0.95))
	_draw_ellipse(canvas, visor_center, visor_rx, visor_ry, Color(0.08, 0.12, 0.18, 1.0))
	_draw_ellipse(canvas, Vector2(visor_center.x, visor_center.y + 0.5), visor_rx - 1.0, visor_ry - 1.0, visor_col)
	
	if is_active:
		_draw_ellipse(canvas, Vector2(visor_center.x + 2.5, visor_center.y - 1.0), 2.5, 1.2, Color(1, 1, 1, 0.85))
		
	# Respirator
	var resp_rect = Rect2(cx - 8, cy - 1, 16, 8)
	_draw_rounded_box(canvas, resp_rect, 3.0, Color(0.16, 0.20, 0.26, 1.0), true)
	_draw_rounded_box(canvas, resp_rect, 3.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.0)
	canvas.draw_circle(Vector2(cx - 4.5, cy + 3.0), 1.8, Color(0.25, 0.30, 0.38, 1.0))
	canvas.draw_circle(Vector2(cx + 4.5, cy + 3.0), 1.8, Color(0.25, 0.30, 0.38, 1.0))

func _draw_rounded_box(canvas: Control, rect: Rect2, radius: float, color: Color, filled: bool = true, line_width: float = 2.0) -> void:
	var pts = PackedVector2Array()
	var r = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var corners = [
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r)
	]
	for i in range(4):
		var center = corners[i]
		var start_angle = float(i) * (PI * 0.5) + PI
		for j in range(6):
			var a = start_angle + (float(j) / 5.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	pts.append(pts[0])
	if filled:
		canvas.draw_colored_polygon(pts, color)
	else:
		canvas.draw_polyline(pts, color, line_width)

func _draw_ellipse(canvas: Control, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts = PackedVector2Array()
	var segments = 20
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(pts, color)
