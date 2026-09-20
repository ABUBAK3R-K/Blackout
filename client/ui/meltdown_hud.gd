class_name MeltdownHUD
extends Control

## Dedicated Meltdown Phase HUD Overlay for BLACKOUT (Stage 19).
## Displays authoritative emergency countdown timer in MM:SS format,
## 3-system restoration checklist, real-time completion state updates,
## and urgent final 30-second audio-visual warning states.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")

signal meltdown_hud_opened(duration: float, impostor_alive: bool)
signal meltdown_hud_closed()

## Current remaining time in seconds (authoritatively driven).
var remaining_time: float = 0.0

## Flag indicating whether Meltdown is currently active on the client.
var is_active: bool = false

## Flag indicating whether the Impostor was alive at Meltdown start.
var is_impostor_alive: bool = true

## Completed emergency systems array: Array of String IDs
var completed_systems: Array[String] = []

## UI Node references
var main_panel: PanelContainer = null
var header_label: Label = null
var timer_label: Label = null
var status_subtitle: Label = null
var system_row_nodes: Dictionary = {} # system_id (String) -> Dictionary

func _ready() -> void:
	visible = false
	_ensure_ui_structure()
	_auto_connect_network_signals()

func _process(delta: float) -> void:
	if not visible or not is_active:
		return

	if remaining_time > 0.0:
		remaining_time = max(0.0, remaining_time - delta)
		_update_timer_display()

## Starts the Meltdown HUD with the authoritative duration.
func start_meltdown(duration: float = MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC, impostor_alive: bool = true) -> void:
	_ensure_ui_structure()
	is_active = true
	remaining_time = duration
	is_impostor_alive = impostor_alive
	completed_systems.clear()

	# Reset checklist rows
	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		_update_system_row_visual(sys_id, false)

	visible = true
	_update_timer_display()
	meltdown_hud_opened.emit(duration, impostor_alive)
	print("[MeltdownHUD] Meltdown HUD activated (Duration: %.1fs, Impostor Alive: %s)." % [duration, str(impostor_alive)])

## Marks an emergency system as completed and updates the checklist.
func mark_system_completed(system_id: String) -> void:
	if not completed_systems.has(system_id):
		completed_systems.append(system_id)

	_update_system_row_visual(system_id, true)
	_update_subtitle_status()

	print("[MeltdownHUD] Emergency system '%s' updated on HUD (%d/3 completed)." % [
		system_id, completed_systems.size()
	])

## Updates the HUD with the full list of completed systems from server sync.
func sync_completed_systems(p_completed_systems: Array) -> void:
	completed_systems.clear()
	for sys_id in p_completed_systems:
		completed_systems.append(str(sys_id))

	for sys_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		var is_comp = completed_systems.has(sys_id)
		_update_system_row_visual(sys_id, is_comp)

	_update_subtitle_status()

## Ends and hides the Meltdown HUD.
func end_meltdown() -> void:
	is_active = false
	visible = false
	meltdown_hud_closed.emit()
	print("[MeltdownHUD] Meltdown HUD dismissed.")

## Automatically connects to NetworkManager client signals if in tree.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for Meltdown lifecycle events.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("meltdown_started") and not client_mgr.meltdown_started.is_connected(_on_network_meltdown_started):
		client_mgr.meltdown_started.connect(_on_network_meltdown_started)

	if client_mgr.has_signal("emergency_system_completed") and not client_mgr.emergency_system_completed.is_connected(_on_network_emergency_system_completed):
		client_mgr.emergency_system_completed.connect(_on_network_emergency_system_completed)

	if client_mgr.has_signal("game_over_received") and not client_mgr.game_over_received.is_connected(_on_network_game_over_received):
		client_mgr.game_over_received.connect(_on_network_game_over_received)

	if client_mgr.has_signal("game_state_changed") and not client_mgr.game_state_changed.is_connected(_on_network_game_state_changed):
		client_mgr.game_state_changed.connect(_on_network_game_state_changed)

# --- UI Formatting & Helper Methods ---

func _update_timer_display() -> void:
	if timer_label == null:
		return

	var total_sec = int(ceil(remaining_time))
	var minutes = total_sec / 60
	var seconds = total_sec % 60
	var time_str = "%02d:%02d" % [minutes, seconds]

	timer_label.text = "TIME REMAINING: %s" % time_str

	# Final 30-second emphasis: Bright flashing red
	if remaining_time <= 30.0:
		var flash_phase = int(Time.get_ticks_msec() / 250) % 2
		if flash_phase == 0:
			timer_label.set("theme_override_colors/font_color", Color(1.0, 0.15, 0.15, 1.0))
		else:
			timer_label.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2, 1.0))
	elif remaining_time <= 60.0:
		timer_label.set("theme_override_colors/font_color", Color(1.0, 0.45, 0.2, 1.0))
	else:
		timer_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.35, 1.0))

func _update_subtitle_status() -> void:
	if status_subtitle == null:
		return

	var count = completed_systems.size()
	if count >= 3:
		status_subtitle.text = "ALL CRITICAL SYSTEMS RESTORED — STATION STABILIZED!"
		status_subtitle.set("theme_override_colors/font_color", Color(0.3, 0.95, 0.5, 1.0))
	else:
		status_subtitle.text = "RESTORE ALL 3 SYSTEMS TO PREVENT CORE COLLAPSE (%d/3)" % count
		status_subtitle.set("theme_override_colors/font_color", Color(0.85, 0.8, 0.9, 0.9))

func _update_system_row_visual(system_id: String, is_completed: bool) -> void:
	if not system_row_nodes.has(system_id):
		return

	var row_data: Dictionary = system_row_nodes[system_id]
	var check_label: Label = row_data.get("check_label")
	var name_label: Label = row_data.get("name_label")
	var loc_label: Label = row_data.get("loc_label")

	var sys_name: String = MeltdownConfig.get_emergency_system_name(system_id).to_upper()

	if is_completed:
		if check_label != null:
			check_label.text = "[✓]"
			check_label.set("theme_override_colors/font_color", Color(0.25, 0.95, 0.45, 1.0))
		if name_label != null:
			name_label.text = sys_name
			name_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 1.0))
		if loc_label != null:
			loc_label.set("theme_override_colors/font_color", Color(0.4, 0.7, 0.5, 0.8))
	else:
		if check_label != null:
			check_label.text = "[ ]"
			check_label.set("theme_override_colors/font_color", Color(0.9, 0.4, 0.4, 1.0))
		if name_label != null:
			name_label.text = sys_name
			name_label.set("theme_override_colors/font_color", Color(0.95, 0.9, 0.9, 1.0))
		if loc_label != null:
			loc_label.set("theme_override_colors/font_color", Color(0.7, 0.75, 0.85, 0.75))

# --- Network Event Callbacks ---

func _on_network_meltdown_started(duration: float, impostor_alive: bool) -> void:
	start_meltdown(duration, impostor_alive)

func _on_network_emergency_system_completed(system_id: String, p_completed_systems: Array) -> void:
	sync_completed_systems(p_completed_systems)

func _on_network_game_over_received(_winner_role: NetworkConfig.PlayerRole, _reason: int, _result_data: Dictionary) -> void:
	end_meltdown()

func _on_network_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.MELTDOWN:
		if not is_active:
			start_meltdown()
	elif new_state != NetworkConfig.GameState.MELTDOWN and is_active:
		end_meltdown()

# --- Programmatic UI Construction ---

func _ensure_ui_structure() -> void:
	if main_panel != null:
		return

	# Anchored Top-Center HUD Panel
	anchors_preset = Control.PRESET_TOP_WIDE
	offset_left = 280.0
	offset_top = 16.0
	offset_right = -280.0
	offset_bottom = 145.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	main_panel = PanelContainer.new()
	main_panel.name = "MeltdownPanel"
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.04, 0.05, 0.92)
	panel_style.border_color = Color(0.9, 0.25, 0.25, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(main_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	main_panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# 1. Header Line: [Alert Icon] [Title] [Countdown Timer]
	var top_hbox = HBoxContainer.new()
	top_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(top_hbox)

	header_label = Label.new()
	header_label.name = "HeaderLabel"
	header_label.text = "⚠ EMERGENCY MELTDOWN PROTOCOL"
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_label.add_theme_font_size_override("font_size", 14)
	header_label.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3, 1.0))
	top_hbox.add_child(header_label)

	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "TIME REMAINING: 05:00"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 14)
	timer_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.35, 1.0))
	top_hbox.add_child(timer_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 2. Systems Checklist Container
	var systems_hbox = HBoxContainer.new()
	systems_hbox.name = "SystemsContainer"
	systems_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	systems_hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(systems_hbox)

	# Create 3 System Columns: Power, Cooling, ORION
	var sys_configs = [
		{"id": MeltdownConfig.SYSTEM_RESTORE_POWER, "name": "RESTORE POWER", "room": "Generator"},
		{"id": MeltdownConfig.SYSTEM_RESTORE_COOLING, "name": "RESTORE COOLING", "room": "Lab"},
		{"id": MeltdownConfig.SYSTEM_STABILIZE_ORION, "name": "STABILIZE ORION", "room": "Core Chamber"}
	]

	for cfg in sys_configs:
		var sys_id: String = cfg.id
		var col_hbox = HBoxContainer.new()
		col_hbox.name = "System_%s" % sys_id
		col_hbox.add_theme_constant_override("separation", 6)
		systems_hbox.add_child(col_hbox)

		var check_lbl = Label.new()
		check_lbl.name = "CheckLabel"
		check_lbl.text = "[ ]"
		check_lbl.add_theme_font_size_override("font_size", 12)
		check_lbl.set("theme_override_colors/font_color", Color(0.9, 0.4, 0.4, 1.0))
		col_hbox.add_child(check_lbl)

		var text_vbox = VBoxContainer.new()
		text_vbox.add_theme_constant_override("separation", 0)
		col_hbox.add_child(text_vbox)

		var name_lbl = Label.new()
		name_lbl.name = "NameLabel"
		name_lbl.text = cfg.name
		name_lbl.add_theme_font_size_override("font_size", 11)
		text_vbox.add_child(name_lbl)

		var loc_lbl = Label.new()
		loc_lbl.name = "LocLabel"
		loc_lbl.text = "(%s)" % cfg.room
		loc_lbl.add_theme_font_size_override("font_size", 9)
		loc_lbl.set("theme_override_colors/font_color", Color(0.7, 0.75, 0.85, 0.75))
		text_vbox.add_child(loc_lbl)

		system_row_nodes[sys_id] = {
			"root": col_hbox,
			"check_label": check_lbl,
			"name_label": name_lbl,
			"loc_label": loc_lbl
		}

	# 3. Subtitle / Guidance
	status_subtitle = Label.new()
	status_subtitle.name = "StatusSubtitle"
	status_subtitle.text = "RESTORE ALL 3 SYSTEMS TO PREVENT CORE COLLAPSE (0/3)"
	status_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_subtitle.add_theme_font_size_override("font_size", 10)
	status_subtitle.set("theme_override_colors/font_color", Color(0.85, 0.8, 0.9, 0.85))
	vbox.add_child(status_subtitle)
