class_name GameOverUI
extends Control

## Client-side In-Game Victory / Defeat Game Over Screen / Overlay for BLACKOUT (Stage 20).
## Displays authoritative match resolution (VICTORY / DEFEAT), local player role,
## authoritative game-over reason, and verified match summary details.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

signal game_over_shown(winner_role: NetworkConfig.PlayerRole, reason: int, is_victory: bool)
signal game_over_dismissed()
signal return_to_lobby_requested()

## State flags
var is_active: bool = false
var is_victory: bool = false
var local_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var winner_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var game_over_reason: int = 0
var result_data: Dictionary = {}

## Local player reference for movement/interaction locking
var local_player: PlayerController = null

## UI Node references
var backdrop: ColorRect = null
var center_container: CenterContainer = null
var main_panel: PanelContainer = null
var badge_label: Label = null
var result_heading: Label = null
var subtitle_label: Label = null
var details_panel: PanelContainer = null
var role_value_label: Label = null
var winner_value_label: Label = null
var reason_value_label: Label = null
var systems_value_label: Label = null
var state_value_label: Label = null
var notice_label: Label = null
var return_to_lobby_button: Button = null

var bound_client_mgr: Node = null

func _ready() -> void:
	visible = false
	is_active = false
	_ensure_ui_structure()
	_auto_discover_player()
	_auto_connect_network_signals()

## Registers the local player controller instance for input management.
func register_local_player(p_player: PlayerController) -> void:
	local_player = p_player
	if p_player != null and local_role == NetworkConfig.PlayerRole.NONE:
		local_role = p_player.get_role()

## Automatically discovers the local PlayerController in the scene tree.
func _auto_discover_player() -> void:
	if local_player != null:
		return
	var root = get_tree().current_scene if (is_inside_tree() and get_tree().current_scene != null) else get_parent()
	if root != null:
		var p = root.get_node_or_null("Player")
		if p is PlayerController:
			register_local_player(p)

## Connects to NetworkManager client signals if present in the scene tree.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for game over and state change events.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	bound_client_mgr = client_mgr

	if client_mgr.has_signal("game_over_received") and not client_mgr.game_over_received.is_connected(_on_network_game_over_received):
		client_mgr.game_over_received.connect(_on_network_game_over_received)

	if client_mgr.has_signal("game_state_changed") and not client_mgr.game_state_changed.is_connected(_on_network_game_state_changed):
		client_mgr.game_state_changed.connect(_on_network_game_state_changed)

	if client_mgr.has_signal("role_assigned") and not client_mgr.role_assigned.is_connected(_on_network_role_assigned):
		client_mgr.role_assigned.connect(_on_network_role_assigned)

	if "assigned_role" in client_mgr and client_mgr.assigned_role != NetworkConfig.PlayerRole.NONE:
		local_role = client_mgr.assigned_role

# --- Public API & Display Logic ---

## Shows the Game Over overlay with authoritative data from the server.
func show_game_over(
	p_winner_role: NetworkConfig.PlayerRole,
	p_reason: int,
	p_result_data: Dictionary = {},
	p_local_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
) -> void:
	_ensure_ui_structure()

	winner_role = p_winner_role
	game_over_reason = p_reason
	result_data = p_result_data

	# Determine local role: explicit parameter > cached local_role > PlayerController role > default CREW
	if p_local_role != NetworkConfig.PlayerRole.NONE:
		local_role = p_local_role
	elif local_role == NetworkConfig.PlayerRole.NONE:
		_auto_discover_player()
		if local_player != null and local_player.get_role() != NetworkConfig.PlayerRole.NONE:
			local_role = local_player.get_role()

	# Determine victory/defeat:
	# Local player wins if their assigned role matches the authoritative winning faction
	if local_role == NetworkConfig.PlayerRole.NONE:
		# Spectator / Unassigned: display winning faction
		is_victory = (winner_role == NetworkConfig.PlayerRole.CREW)
	else:
		is_victory = (local_role == winner_role)

	is_active = true
	visible = true

	# Lock player movement and interactions
	_lock_player_movement(true)

	# Update all visual elements
	_populate_ui()

	# Play subtle entrance animation
	_play_entrance_animation()

	game_over_shown.emit(winner_role, game_over_reason, is_victory)
	print("[GameOverUI] Game Over Screen displayed: Result=%s | LocalRole=%s | WinnerRole=%s | Reason=%s" % [
		"VICTORY" if is_victory else "DEFEAT",
		RoleManager.get_role_display_name(local_role),
		NetworkConfig.get_role_name(winner_role),
		_get_reason_display_text(game_over_reason)
	])

## Hides the Game Over UI and restores controls if appropriate.
func hide_game_over() -> void:
	if not is_active and not visible:
		return

	is_active = false
	visible = false

	# Restore local player movement
	_lock_player_movement(false)

	game_over_dismissed.emit()
	print("[GameOverUI] Game Over Screen dismissed.")

## Cleans up all match data and resets UI to initial hidden state.
func reset() -> void:
	is_active = false
	is_victory = false
	local_role = NetworkConfig.PlayerRole.NONE
	winner_role = NetworkConfig.PlayerRole.NONE
	game_over_reason = 0
	result_data.clear()
	visible = false

	if main_panel != null:
		main_panel.modulate = Color(1, 1, 1, 1)
		main_panel.scale = Vector2(1, 1)

	_clear_ui_text()
	_lock_player_movement(false)
	print("[GameOverUI] Game Over Screen reset.")

# --- Internal Helper & UI Population ---

func _populate_ui() -> void:
	if main_panel == null:
		return

	var victory_color = Color(0.2, 0.95, 0.5, 1.0)
	var victory_border = Color(0.25, 0.9, 0.55, 0.9)
	var defeat_color = Color(1.0, 0.25, 0.25, 1.0)
	var defeat_border = Color(0.95, 0.25, 0.25, 0.9)

	# 1. Panel Glassmorphic Styling
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	panel_style.border_color = victory_border if is_victory else defeat_border
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 12
	main_panel.add_theme_stylebox_override("panel", panel_style)

	# 2. Main Result Heading
	if result_heading != null:
		if is_victory:
			result_heading.text = "VICTORY"
			result_heading.set("theme_override_colors/font_color", victory_color)
		else:
			result_heading.text = "DEFEAT"
			result_heading.set("theme_override_colors/font_color", defeat_color)

	# 3. Subtitle
	if subtitle_label != null:
		if is_victory:
			if local_role == NetworkConfig.PlayerRole.CREW:
				subtitle_label.text = "Asterion Research Facility Preserved"
			else:
				subtitle_label.text = "Station Sabotage Successful"
			subtitle_label.set("theme_override_colors/font_color", Color(0.7, 0.95, 0.8, 0.9))
		else:
			if local_role == NetworkConfig.PlayerRole.CREW:
				subtitle_label.text = "Station Core Overwhelmed"
			else:
				subtitle_label.text = "Crew Restored Emergency Systems"
			subtitle_label.set("theme_override_colors/font_color", Color(0.95, 0.7, 0.7, 0.9))

	# 4. Details: Your Role
	if role_value_label != null:
		var role_str = RoleManager.get_role_display_name(local_role)
		role_value_label.text = role_str
		if local_role == NetworkConfig.PlayerRole.IMPOSTOR:
			role_value_label.set("theme_override_colors/font_color", Color(0.95, 0.3, 0.3, 1.0))
		elif local_role == NetworkConfig.PlayerRole.CREW:
			role_value_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 1.0))
		else:
			role_value_label.set("theme_override_colors/font_color", Color(0.7, 0.8, 0.9, 1.0))

	# 5. Details: Winning Faction
	if winner_value_label != null:
		var winner_str = NetworkConfig.get_role_name(winner_role)
		winner_value_label.text = winner_str
		if winner_role == NetworkConfig.PlayerRole.CREW:
			winner_value_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 1.0))
		elif winner_role == NetworkConfig.PlayerRole.IMPOSTOR:
			winner_value_label.set("theme_override_colors/font_color", Color(0.95, 0.3, 0.3, 1.0))
		else:
			winner_value_label.set("theme_override_colors/font_color", Color(0.8, 0.85, 0.95, 1.0))

	# 6. Details: Authoritative Reason
	if reason_value_label != null:
		var reason_text = _get_reason_display_text(game_over_reason)
		reason_value_label.text = reason_text
		reason_value_label.set("theme_override_colors/font_color", Color(0.9, 0.92, 0.96, 1.0))

	# 7. Details: Emergency Systems Restored Count
	if systems_value_label != null:
		var completed_count: int = 0
		if result_data.has("completed_systems") and result_data["completed_systems"] is Array:
			completed_count = (result_data["completed_systems"] as Array).size()
		elif game_over_reason == MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE:
			completed_count = 3

		var total_systems = MeltdownConfig.ALL_EMERGENCY_SYSTEMS.size()
		systems_value_label.text = "%d / %d Online" % [completed_count, total_systems]
		if completed_count >= total_systems:
			systems_value_label.set("theme_override_colors/font_color", Color(0.3, 0.95, 0.5, 1.0))
		else:
			systems_value_label.set("theme_override_colors/font_color", Color(0.95, 0.6, 0.3, 1.0))

	# 8. Details: Round State
	if state_value_label != null:
		state_value_label.text = "GAME_OVER"
		state_value_label.set("theme_override_colors/font_color", Color(0.8, 0.85, 0.95, 1.0))

func _clear_ui_text() -> void:
	if result_heading != null:
		result_heading.text = ""
	if subtitle_label != null:
		subtitle_label.text = ""
	if role_value_label != null:
		role_value_label.text = ""
	if winner_value_label != null:
		winner_value_label.text = ""
	if reason_value_label != null:
		reason_value_label.text = ""
	if systems_value_label != null:
		systems_value_label.text = ""
	if state_value_label != null:
		state_value_label.text = ""

func _get_reason_display_text(p_reason: int) -> String:
	match p_reason as MeltdownConfig.GameOverReason:
		MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE:
			return "Crew successfully restored all emergency systems"
		MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED:
			return "Meltdown timer expired — Core destroyed"
		_:
			if result_data.has("reason_name") and not str(result_data["reason_name"]).is_empty():
				return str(result_data["reason_name"])
			return "Match Concluded"

func _play_entrance_animation() -> void:
	if main_panel == null:
		return

	# Smooth subtle entrance animation using Tween
	main_panel.modulate = Color(1, 1, 1, 0.0)
	main_panel.scale = Vector2(0.96, 0.96)
	main_panel.pivot_offset = main_panel.size * 0.5

	var tween = create_tween()
	if tween != null:
		tween.set_parallel(true)
		tween.tween_property(main_panel, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(main_panel, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _lock_player_movement(lock: bool) -> void:
	_auto_discover_player()
	if local_player != null:
		local_player.can_move = not lock

# --- Network Event Callbacks ---

func _on_network_game_over_received(p_winner_role: NetworkConfig.PlayerRole, p_reason: int, p_result_data: Dictionary) -> void:
	show_game_over(p_winner_role, p_reason, p_result_data, local_role)

func _on_network_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.GAME_OVER:
		if not is_active:
			show_game_over(winner_role, game_over_reason, result_data, local_role)
	elif new_state == NetworkConfig.GameState.LOBBY:
		reset()
	else:
		# During all active gameplay states (STARTING, ROLE_ASSIGNMENT, PLAYING, MELTDOWN, etc.), UI must remain hidden
		if is_active:
			hide_game_over()

func _on_network_role_assigned(p_role: NetworkConfig.PlayerRole) -> void:
	local_role = p_role

# --- Programmatic UI Layout Hierarchy ---

func _ensure_ui_structure() -> void:
	if main_panel != null:
		return

	# Anchor to fill entire parent viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Translucent Backdrop
	backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# 2. Centered Container
	center_container = CenterContainer.new()
	center_container.name = "CenterContainer"
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center_container)

	# 3. Main Glassmorphic Modal Panel
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(620, 440)
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.11, 0.96)
	panel_style.border_color = Color(0.25, 0.9, 0.55, 0.9)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
	panel_style.shadow_size = 12
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center_container.add_child(main_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	main_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(main_vbox)

	# --- HEADER SECTION ---
	var header_vbox = VBoxContainer.new()
	header_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	header_vbox.add_theme_constant_override("separation", 4)
	main_vbox.add_child(header_vbox)

	badge_label = Label.new()
	badge_label.name = "BadgeLabel"
	badge_label.text = "AUTHORITATIVE MATCH RESOLUTION"
	badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_label.add_theme_font_size_override("font_size", 11)
	badge_label.set("theme_override_colors/font_color", Color(0.65, 0.75, 0.88, 0.85))
	header_vbox.add_child(badge_label)

	result_heading = Label.new()
	result_heading.name = "ResultHeading"
	result_heading.text = "VICTORY"
	result_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_heading.add_theme_font_size_override("font_size", 38)
	result_heading.set("theme_override_colors/font_color", Color(0.2, 0.95, 0.5, 1.0))
	header_vbox.add_child(result_heading)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "Asterion Research Facility Preserved"
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.add_theme_font_size_override("font_size", 13)
	subtitle_label.set("theme_override_colors/font_color", Color(0.7, 0.85, 0.95, 0.9))
	header_vbox.add_child(subtitle_label)

	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)

	# --- MATCH SUMMARY DETAILS CARD ---
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"

	var details_style = StyleBoxFlat.new()
	details_style.bg_color = Color(0.03, 0.04, 0.07, 0.8)
	details_style.border_color = Color(0.18, 0.25, 0.36, 0.75)
	details_style.set_border_width_all(1)
	details_style.set_corner_radius_all(6)
	details_panel.add_theme_stylebox_override("panel", details_style)
	main_vbox.add_child(details_panel)

	var det_margin = MarginContainer.new()
	det_margin.add_theme_constant_override("margin_left", 18)
	det_margin.add_theme_constant_override("margin_top", 14)
	det_margin.add_theme_constant_override("margin_right", 18)
	det_margin.add_theme_constant_override("margin_bottom", 14)
	details_panel.add_child(det_margin)

	var details_grid = GridContainer.new()
	details_grid.name = "DetailsGrid"
	details_grid.columns = 2
	details_grid.add_theme_constant_override("h_separation", 24)
	details_grid.add_theme_constant_override("v_separation", 10)
	details_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	det_margin.add_child(details_grid)

	# Row 1: Your Role
	var role_title = _create_detail_title("YOUR ROLE")
	details_grid.add_child(role_title)
	role_value_label = _create_detail_value("CREW", Color(0.3, 0.9, 0.5, 1.0))
	details_grid.add_child(role_value_label)

	# Row 2: Winning Faction
	var winner_title = _create_detail_title("WINNING FACTION")
	details_grid.add_child(winner_title)
	winner_value_label = _create_detail_value("CREW", Color(0.3, 0.9, 0.5, 1.0))
	details_grid.add_child(winner_value_label)

	# Row 3: Game Over Reason
	var reason_title = _create_detail_title("REASON")
	details_grid.add_child(reason_title)
	reason_value_label = _create_detail_value("Crew successfully restored all emergency systems", Color(0.9, 0.92, 0.96, 1.0))
	details_grid.add_child(reason_value_label)

	# Row 4: Emergency Systems
	var systems_title = _create_detail_title("EMERGENCY RESTORATION")
	details_grid.add_child(systems_title)
	systems_value_label = _create_detail_value("3 / 3 Online", Color(0.3, 0.95, 0.5, 1.0))
	details_grid.add_child(systems_value_label)

	# Row 5: Match State
	var state_title = _create_detail_title("ROUND STATUS")
	details_grid.add_child(state_title)
	state_value_label = _create_detail_value("GAME_OVER", Color(0.8, 0.85, 0.95, 1.0))
	details_grid.add_child(state_value_label)

	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)

	# --- FOOTER / NOTICE SECTION ---
	notice_label = Label.new()
	notice_label.name = "NoticeLabel"
	notice_label.text = "Authoritative Game Over — Round Finalized."
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_size_override("font_size", 11)
	notice_label.set("theme_override_colors/font_color", Color(0.6, 0.65, 0.75, 0.8))
	main_vbox.add_child(notice_label)

	# --- RETURN TO LOBBY / PLAY AGAIN BUTTON ---
	return_to_lobby_button = Button.new()
	return_to_lobby_button.name = "ReturnToLobbyButton"
	return_to_lobby_button.text = "RETURN TO LOBBY"
	return_to_lobby_button.custom_minimum_size = Vector2(240, 42)
	return_to_lobby_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_to_lobby_button.focus_mode = Control.FOCUS_ALL
	return_to_lobby_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return_to_lobby_button.add_theme_font_size_override("font_size", 14)

	var btn_normal = StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.08, 0.16, 0.24, 0.9)
	btn_normal.border_color = Color(0.25, 0.75, 0.85, 0.8)
	btn_normal.set_border_width_all(2)
	btn_normal.set_corner_radius_all(6)
	return_to_lobby_button.add_theme_stylebox_override("normal", btn_normal)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.12, 0.24, 0.36, 0.95)
	btn_hover.border_color = Color(0.35, 0.95, 1.0, 1.0)
	btn_hover.set_border_width_all(2)
	btn_hover.set_corner_radius_all(6)
	btn_hover.shadow_color = Color(0.2, 0.8, 1.0, 0.3)
	btn_hover.shadow_size = 6
	return_to_lobby_button.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed = StyleBoxFlat.new()
	btn_pressed.bg_color = Color(0.05, 0.12, 0.18, 1.0)
	btn_pressed.border_color = Color(0.2, 0.65, 0.75, 0.9)
	btn_pressed.set_border_width_all(2)
	btn_pressed.set_corner_radius_all(6)
	return_to_lobby_button.add_theme_stylebox_override("pressed", btn_pressed)

	return_to_lobby_button.set("theme_override_colors/font_color", Color(0.9, 0.96, 1.0, 1.0))
	return_to_lobby_button.set("theme_override_colors/font_hover_color", Color(1.0, 1.0, 1.0, 1.0))

	return_to_lobby_button.pressed.connect(_on_return_to_lobby_pressed)
	main_vbox.add_child(return_to_lobby_button)

func _on_return_to_lobby_pressed() -> void:
	print("[GameOverUI] Return to Lobby button pressed.")
	return_to_lobby_requested.emit()
	if bound_client_mgr != null and bound_client_mgr.has_method("request_return_to_lobby"):
		bound_client_mgr.request_return_to_lobby()
	else:
		var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
		if net_mgr != null and net_mgr.has_method("request_return_to_lobby"):
			net_mgr.request_return_to_lobby()

func request_return_to_lobby() -> void:
	_on_return_to_lobby_pressed()

func _create_detail_title(p_text: String) -> Label:
	var lbl = Label.new()
	lbl.text = p_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.set("theme_override_colors/font_color", Color(0.6, 0.7, 0.82, 0.85))
	return lbl

func _create_detail_value(p_text: String, p_color: Color) -> Label:
	var lbl = Label.new()
	lbl.text = p_text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.set("theme_override_colors/font_color", p_color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl
