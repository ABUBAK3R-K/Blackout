class_name ResultScreen
extends Control

## ResultScreen — Member 5 (UI/UX Frontend)
## Authoritative Game Over & Result Screen for BLACKOUT.
##
## Appears when authoritative state reaches GAME_OVER:
## 1. Displays prominent Victory/Defeat heading based on authoritative winner role.
## 2. Presents full player roster with revealed roles and final status.
## 3. Summarizes authoritative match statistics (emergency systems, time, etc.).
## 4. Provides Return to Lobby / Play Again action.
##
## Strict Authoritative Rule:
## - Frontend does NOT determine winners, calculate victory conditions, or infer hidden stats.

signal return_to_lobby_requested()
signal screen_shown()
signal screen_hidden()

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")

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

const COLOR_CREW_VICTORY: Color = Color(0.0, 0.90, 1.0, 1.0)
const COLOR_IMPOSTOR_VICTORY: Color = Color(1.0, 0.16, 0.26, 1.0)
const COLOR_ACTIVE_GREEN: Color = Color(0.20, 0.85, 0.40, 1.0)
const COLOR_EJECTED_RED: Color = Color(0.90, 0.25, 0.30, 1.0)

## Node references
@onready var background_darkness: ColorRect = find_child("BackgroundDarkness", true, false)
@onready var main_card: PanelContainer = find_child("MainCard", true, false)
@onready var roster_title_label: Label = find_child("RosterTitleLabel", true, false)
@onready var roster_count_label: Label = find_child("RosterCountLabel", true, false)
@onready var stats_title_label: Label = find_child("StatsTitleLabel", true, false)
@onready var players_grid: GridContainer = find_child("PlayersGrid", true, false)
@onready var stats_container: VBoxContainer = find_child("StatsContainer", true, false)
@onready var return_button: Button = find_child("ReturnButton", true, false)

## Internal state
var _is_active: bool = false
var _current_result_data: Dictionary = {}
var _active_tween: Tween = null

func _ready() -> void:
	_ensure_node_references()
	visible = false
	modulate.a = 0.0
	
	if return_button != null and not return_button.pressed.is_connected(_on_return_button_pressed):
		return_button.pressed.connect(_on_return_button_pressed)

func _ensure_node_references() -> void:
	if background_darkness == null:
		background_darkness = find_child("BackgroundDarkness", true, false) as ColorRect
	if main_card == null:
		main_card = find_child("MainCard", true, false) as PanelContainer
	if roster_title_label == null:
		roster_title_label = find_child("RosterTitleLabel", true, false) as Label
	if roster_count_label == null:
		roster_count_label = find_child("RosterCountLabel", true, false) as Label
	if stats_title_label == null:
		stats_title_label = find_child("StatsTitleLabel", true, false) as Label
	if players_grid == null:
		players_grid = find_child("PlayersGrid", true, false) as GridContainer
	if stats_container == null:
		stats_container = find_child("StatsContainer", true, false) as VBoxContainer
	if return_button == null:
		return_button = find_child("ReturnButton", true, false) as Button
	if return_button != null and not return_button.pressed.is_connected(_on_return_button_pressed):
		return_button.pressed.connect(_on_return_button_pressed)

## Main Public API to show the authoritative Game Over screen
func show_game_over(winner_role: int, reason: int, result_data: Dictionary) -> void:
	_ensure_node_references()
	_current_result_data = result_data.duplicate()
	_is_active = true
	
	# 1. Populate Final Player Roster Recap
	_populate_player_roster(result_data)
	
	# 2. Populate Authoritative Match Statistics (with emergency systems sub points)
	_populate_match_statistics(winner_role, reason, result_data)
	
	# 3. Trigger Entrance Animation
	_animate_in()
	screen_shown.emit()

func hide_screen() -> void:
	_is_active = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_active_tween.tween_callback(func():
		visible = false
		screen_hidden.emit()
	)

func is_screen_active() -> bool:
	return _is_active

## Populate Final Player Roster
func _populate_player_roster(result_data: Dictionary) -> void:
	if players_grid == null:
		return
		
	for child in players_grid.get_children():
		child.queue_free()
		
	var roster: Array = result_data.get("player_roster", [])
	
	# Fallback to lobby players data from NetworkManager if roster is empty
	if roster.is_empty() and has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			roster = net_mgr.client.lobby_players_data
			
	var total_players = roster.size() if roster.size() > 0 else 8
	if roster_count_label != null:
		roster_count_label.text = "%d / %d" % [total_players, total_players]
			
	for p in roster:
		var pid: int = int(p.get("peer_id", 0))
		var slot: int = int(p.get("player_slot", 1))
		var role_val = p.get("role", NetworkConfig.PlayerRole.CREW)
		var is_impostor: bool = (role_val == NetworkConfig.PlayerRole.IMPOSTOR or int(role_val) == NetworkConfig.PlayerRole.IMPOSTOR or str(role_val).to_upper() == "IMPOSTOR")
		var is_alive: bool = bool(p.get("is_alive", true))
		var is_eliminated: bool = bool(p.get("is_eliminated", false))
		
		var card = _build_player_roster_card(pid, slot, is_impostor, is_alive, is_eliminated)
		players_grid.add_child(card)

## Builds a single Player Roster Card matching the reference layout
func _build_player_roster_card(pid: int, slot: int, is_impostor: bool, is_alive: bool, is_eliminated: bool) -> Control:
	var is_ejected = is_eliminated or not is_alive
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(250, 56)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.11, 0.95) if not is_ejected else Color(0.03, 0.05, 0.08, 0.75)
	style.set_border_width_all(1)
	if is_impostor:
		style.border_color = Color(0.60, 0.12, 0.16, 0.85)
	else:
		style.border_color = Color(0.12, 0.22, 0.32, 0.80)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	# 1. Mini Technician Avatar with Red X if ejected
	var avatar = _create_mini_avatar(slot, not is_ejected)
	hbox.add_child(avatar)
	
	# 2. Player Info (Name on top, Department below)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = "Player %d" % (pid if pid > 0 else (100 + slot))
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98, 1.0) if not is_ejected else Color(0.55, 0.58, 0.65, 0.8))
	info_vbox.add_child(name_lbl)
	
	var dept_names = ["Engineering", "Maintenance", "Rad-Safety", "Operations", "Science", "Security", "Diagnostics", "Reactor"]
	var dept_name = dept_names[clampi(slot - 1, 0, dept_names.size() - 1)]
	var dept_lbl = Label.new()
	dept_lbl.text = dept_name
	dept_lbl.add_theme_font_size_override("font_size", 11)
	dept_lbl.add_theme_color_override("font_color", Color(0.45, 0.54, 0.65, 0.9))
	info_vbox.add_child(dept_lbl)
	
	# 3. Role Badge (top) and Status indicator (bottom)
	var right_vbox = VBoxContainer.new()
	right_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	right_vbox.add_theme_constant_override("separation", 4)
	hbox.add_child(right_vbox)
	
	# Role Badge
	var role_badge = PanelContainer.new()
	var role_style = StyleBoxFlat.new()
	role_style.bg_color = Color(0.02, 0.12, 0.18, 0.8) if not is_impostor else Color(0.18, 0.04, 0.06, 0.8)
	role_style.set_border_width_all(1)
	role_style.border_color = Color(0.0, 0.85, 1.0, 0.9) if not is_impostor else Color(0.95, 0.22, 0.28, 0.9)
	role_style.set_corner_radius_all(4)
	role_style.content_margin_left = 6.0
	role_style.content_margin_right = 6.0
	role_style.content_margin_top = 2.0
	role_style.content_margin_bottom = 2.0
	role_badge.add_theme_stylebox_override("panel", role_style)
	
	var role_lbl = Label.new()
	role_lbl.text = "CREWMATE" if not is_impostor else "IMPOSTOR"
	role_lbl.add_theme_font_size_override("font_size", 10)
	role_lbl.add_theme_color_override("font_color", Color(0.0, 0.85, 1.0, 1.0) if not is_impostor else Color(0.95, 0.22, 0.28, 1.0))
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_badge.add_child(role_lbl)
	right_vbox.add_child(role_badge)
	
	# Status Indicator (● ACTIVE vs ● EJECTED)
	var status_lbl = Label.new()
	if is_ejected:
		status_lbl.text = "● EJECTED"
		status_lbl.add_theme_color_override("font_color", COLOR_EJECTED_RED)
	else:
		status_lbl.text = "● ACTIVE"
		status_lbl.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
	status_lbl.add_theme_font_size_override("font_size", 10)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(status_lbl)
	
	return panel

## Populate Authoritative Match Statistics with Emergency Systems sub points
func _populate_match_statistics(winner_role: int, reason: int, result_data: Dictionary) -> void:
	if stats_container == null:
		return
		
	for child in stats_container.get_children():
		child.queue_free()
		
	# 1. Emergency Systems Restored
	var completed_sys: Array = result_data.get("completed_emergency_systems", [])
	var sys_box = _build_stat_row("Emergency Systems Restored", "%d / 3" % completed_sys.size(), COLOR_CREW_VICTORY if completed_sys.size() >= 3 else Color(0.0, 0.85, 1.0))
	stats_container.add_child(sys_box)
	
	# Original Emergency Systems sub points
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		var sys_name = MeltdownConfig.get_emergency_system_name(sys_id)
		var is_done = completed_sys.has(sys_id)
		var row = _build_sub_stat_row(sys_name, "RESTORED" if is_done else "OFFLINE", COLOR_ACTIVE_GREEN if is_done else COLOR_EJECTED_RED)
		stats_container.add_child(row)
		
	var sep1 = HSeparator.new()
	sep1.add_theme_constant_override("separation", 10)
	stats_container.add_child(sep1)
	
	# 2. Remaining Meltdown Time
	var rem_time: float = float(result_data.get("remaining_meltdown_time", 218.0))
	var mins = int(rem_time) / 60
	var secs = int(rem_time) % 60
	var time_box = _build_stat_row("Core Meltdown Clock Remaining", "%02d:%02d" % [mins, secs], Color(0.92, 0.95, 0.98))
	stats_container.add_child(time_box)
	
	var sep2 = HSeparator.new()
	sep2.add_theme_constant_override("separation", 10)
	stats_container.add_child(sep2)
	
	# 3. Personnel Casualties / Ejections
	var roster: Array = result_data.get("player_roster", [])
	var ejected_count = 0
	for p in roster:
		if bool(p.get("is_eliminated", false)) or not bool(p.get("is_alive", true)):
			ejected_count += 1
	var cas_box = _build_stat_row("Facility Personnel Casualties", "%d Ejected" % ejected_count, COLOR_EJECTED_RED if ejected_count > 0 else COLOR_ACTIVE_GREEN)
	stats_container.add_child(cas_box)

func _build_stat_row(title: String, val: String, val_color: Color) -> Control:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.add_theme_font_size_override("font_size", 12)
	lbl_title.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94, 0.95))
	hbox.add_child(lbl_title)
	
	var lbl_val = Label.new()
	lbl_val.text = val
	lbl_val.add_theme_font_size_override("font_size", 12)
	lbl_val.add_theme_color_override("font_color", val_color)
	hbox.add_child(lbl_val)
	
	return hbox

func _build_sub_stat_row(title: String, val: String, val_color: Color) -> Control:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var bullet = Label.new()
	bullet.text = "   • "
	bullet.add_theme_font_size_override("font_size", 11)
	bullet.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	hbox.add_child(bullet)
	
	var lbl_title = Label.new()
	lbl_title.text = title
	lbl_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl_title.add_theme_font_size_override("font_size", 11)
	lbl_title.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78, 0.85))
	hbox.add_child(lbl_title)
	
	var lbl_val = Label.new()
	lbl_val.text = val
	lbl_val.add_theme_font_size_override("font_size", 11)
	lbl_val.add_theme_color_override("font_color", val_color)
	hbox.add_child(lbl_val)
	
	return hbox

## Entrance Animation
func _animate_in() -> void:
	visible = true
	modulate.a = 0.0
	
	if main_card != null:
		main_card.scale = Vector2(0.95, 0.95)
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if main_card != null:
		_active_tween.tween_property(main_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_return_button_pressed() -> void:
	print("[ResultScreen] Return to Lobby button pressed.")
	return_to_lobby_requested.emit()
	
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			if net_mgr.client.has_method("disconnect_from_server"):
				net_mgr.client.disconnect_from_server()

## Procedural Mini Avatar for Roster Cards
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
	
	# Ejected Red X mark across avatar box
	if not is_active:
		var x_col = Color(0.95, 0.22, 0.25, 0.95)
		canvas.draw_line(Vector2(5, 5), Vector2(w - 5, h - 5), x_col, 2.8)
		canvas.draw_line(Vector2(w - 5, 5), Vector2(5, h - 5), x_col, 2.8)

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