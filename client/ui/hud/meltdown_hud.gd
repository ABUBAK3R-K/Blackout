class_name MeltdownHUD
extends Control

## MeltdownHUD — Member 5 (UI/UX Frontend)
## Meltdown Emergency Warning & 5-minute Countdown HUD for BLACKOUT.
##
## Displays authoritative 5-minute emergency countdown, flashing warning states,
## and 3 emergency subsystem restoration indicators. Consumes NetworkManager.client events.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")

## Styling constants
const COLOR_ALARM_RED: Color = Color(1.0, 0.28, 0.30, 1.0)          # Emergency Red (#FF474D)
const COLOR_SUBTITLE: Color = Color(0.75, 0.78, 0.85, 0.85)         # Muted subtitle slate
const COLOR_PROGRESS_NORMAL: Color = Color(0.65, 0.68, 0.75, 0.85)   # Muted progress slate
const COLOR_SYSTEM_DONE: Color = Color(0.20, 0.85, 0.40, 1.0)       # Completed Green (#33D966)
const COLOR_SYSTEM_PENDING: Color = Color(0.92, 0.94, 0.96, 0.95)    # Incomplete Text White
const COLOR_BULLET_PENDING: Color = Color(0.45, 0.48, 0.55, 0.75)    # Incomplete Circle
const COLOR_TIMER_NORMAL: Color = Color(1.0, 0.32, 0.32, 1.0)       # Warning Timer Red
const COLOR_TIMER_CRITICAL: Color = Color(1.0, 0.20, 0.20, 1.0)      # Critical flashing red (<= 30s)

## Node references
@onready var panel_container: PanelContainer = $PanelContainer
@onready var alarm_icon: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/AlarmIcon
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var clock_icon: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ClockIcon
@onready var timer_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TimerLabel
@onready var subtitle_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel
@onready var systems_progress_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SystemsHeader/SystemsProgressLabel
@onready var systems_list_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/SystemsListContainer

## Internal state
var _is_active: bool = false
var _remaining_time: float = 0.0
var _completed_systems: Array = []
var _is_connected_to_network: bool = false
var _pulse_timer: float = 0.0
var _fade_tween: Tween = null

func _ready() -> void:
	_ensure_node_references()
	_connect_to_network_events()
	
	if not _is_connected_to_server():
		# Standalone preview: start with preview data
		visible = true
		_populate_offline_preview()
	else:
		visible = false

func _ensure_node_references() -> void:
	if panel_container == null and has_node("PanelContainer"):
		panel_container = get_node("PanelContainer")
	if alarm_icon == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/AlarmIcon"):
		alarm_icon = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/AlarmIcon")
	if title_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel"):
		title_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel")
	if clock_icon == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ClockIcon"):
		clock_icon = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/ClockIcon")
	if timer_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TimerLabel"):
		timer_label = get_node("PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/TimerLabel")
	if subtitle_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel"):
		subtitle_label = get_node("PanelContainer/MarginContainer/VBoxContainer/SubtitleLabel")
	if systems_progress_label == null and has_node("PanelContainer/MarginContainer/VBoxContainer/SystemsHeader/SystemsProgressLabel"):
		systems_progress_label = get_node("PanelContainer/MarginContainer/VBoxContainer/SystemsHeader/SystemsProgressLabel")
	if systems_list_container == null and has_node("PanelContainer/MarginContainer/VBoxContainer/SystemsListContainer"):
		systems_list_container = get_node("PanelContainer/MarginContainer/VBoxContainer/SystemsListContainer")

func _process(delta: float) -> void:
	if not _is_active:
		return
		
	# Countdown timer
	if _remaining_time > 0.0:
		_remaining_time = max(0.0, _remaining_time - delta)
		_update_timer_display()
	elif _remaining_time <= 0.0:
		_remaining_time = 0.0
		_update_timer_display()
		
	# Alarm pulsing animation
	_pulse_timer += delta
	_update_alarm_pulse()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_connected_to_server() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_M:
			_cycle_offline_systems()
		elif event.keycode == KEY_R:
			_populate_offline_preview()

func _is_connected_to_server() -> bool:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			return net_mgr.client.is_connected_to_server()
	return false

func _connect_to_network_events() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("meltdown_started") and not client.meltdown_started.is_connected(_on_meltdown_started):
				client.meltdown_started.connect(_on_meltdown_started)
			if client.has_signal("emergency_system_completed") and not client.emergency_system_completed.is_connected(_on_emergency_system_completed):
				client.emergency_system_completed.connect(_on_emergency_system_completed)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			if client.has_signal("game_over_received") and not client.game_over_received.is_connected(_on_game_over_received):
				client.game_over_received.connect(_on_game_over_received)
			_is_connected_to_network = true
			
			if _is_connected_to_server():
				if client.is_meltdown_active:
					start_meltdown(client.meltdown_remaining_duration, client.completed_emergency_systems)
				else:
					end_meltdown(false)

func _on_meltdown_started(duration: float, _impostor_alive: bool) -> void:
	start_meltdown(duration, [])

func _on_emergency_system_completed(system_id: String, completed_systems: Array) -> void:
	update_emergency_system(system_id, true, completed_systems)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.MELTDOWN:
		if not _is_active:
			start_meltdown(MeltdownConfig.DEFAULT_MELTDOWN_DURATION_SEC, [])
	else:
		if _is_active and new_state != NetworkConfig.GameState.GAME_OVER:
			end_meltdown(true)

func _on_game_over_received(_winner_role: int, _reason: int, _result_data: Dictionary) -> void:
	if _is_active:
		# Freeze at current state before fading out
		_is_active = false

## Public API to activate Meltdown HUD
func start_meltdown(duration: float, completed_systems: Array = []) -> void:
	_ensure_node_references()
	_is_active = true
	_remaining_time = max(0.0, duration)
	_completed_systems = completed_systems.duplicate()
	_pulse_timer = 0.0
	_update_timer_display()
	_rebuild_systems_ui()
	_show_hud_animated()

## Public API to update emergency system status
func update_emergency_system(system_id: String, is_completed: bool, completed_systems: Array = []) -> void:
	if not completed_systems.is_empty():
		_completed_systems = completed_systems.duplicate()
	else:
		if is_completed and not _completed_systems.has(system_id):
			_completed_systems.append(system_id)
		elif not is_completed and _completed_systems.has(system_id):
			_completed_systems.erase(system_id)
			
	_rebuild_systems_ui()

## Public API to update remaining countdown duration
func set_remaining_time(seconds: float) -> void:
	_remaining_time = max(0.0, seconds)
	_update_timer_display()

## Public API to dismiss/hide Meltdown HUD
func end_meltdown(animated: bool = true) -> void:
	_is_active = false
	_remaining_time = 0.0
	_completed_systems.clear()
	if animated:
		_hide_hud_animated()
	else:
		visible = false
		modulate.a = 0.0

## Returns whether Meltdown is currently active
func is_meltdown_active() -> bool:
	return _is_active

## Returns remaining time in seconds
func get_remaining_time() -> float:
	return _remaining_time

## Formats float seconds into 'MM:SS' string format
static func format_time(seconds: float) -> String:
	if is_nan(seconds) or seconds < 0.0:
		return "00:00"
	var total_sec: int = int(ceil(max(0.0, seconds)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]

## Updates timer text and warning styling
func _update_timer_display() -> void:
	_ensure_node_references()
	if timer_label == null:
		return
		
	timer_label.text = format_time(_remaining_time)
	
	# Critical threshold: final 30 seconds
	if _remaining_time <= 30.0:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_CRITICAL)
	else:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)

## Rebuilds the 3 emergency system checklist rows
func _rebuild_systems_ui() -> void:
	_ensure_node_references()
	if systems_list_container == null:
		return
		
	# Clear existing children immediately
	for child in systems_list_container.get_children():
		systems_list_container.remove_child(child)
		child.queue_free()
		
	var total_systems = MeltdownConfig.ALL_EMERGENCY_SYSTEMS.size()
	var completed_count = _completed_systems.size()
	var all_stabilized = (completed_count >= total_systems)
	
	# Update Header & Branding Colors (Green on success, Warning Red on active)
	if all_stabilized:
		if alarm_icon != null:
			alarm_icon.text = "✓"
			alarm_icon.add_theme_color_override("font_color", COLOR_SYSTEM_DONE)
			alarm_icon.modulate.a = 1.0
		if title_label != null:
			title_label.text = "MELTDOWN AVERTED"
			title_label.add_theme_color_override("font_color", COLOR_SYSTEM_DONE)
		if subtitle_label != null:
			subtitle_label.text = "ALL SYSTEMS STABILIZED"
			subtitle_label.add_theme_color_override("font_color", COLOR_SYSTEM_DONE)
		if timer_label != null:
			timer_label.add_theme_color_override("font_color", COLOR_SYSTEM_DONE)
			timer_label.modulate.a = 1.0
	else:
		if alarm_icon != null:
			alarm_icon.text = "⚠"
			alarm_icon.add_theme_color_override("font_color", COLOR_ALARM_RED)
		if title_label != null:
			title_label.text = "MELTDOWN"
			title_label.add_theme_color_override("font_color", COLOR_ALARM_RED)
		if subtitle_label != null:
			subtitle_label.text = "EMERGENCY SYSTEM FAILURE"
			subtitle_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	
	# Update Header Progress "X / 3"
	if systems_progress_label != null:
		if all_stabilized:
			systems_progress_label.text = "%d / %d (STABILIZED)" % [completed_count, total_systems]
			systems_progress_label.add_theme_color_override("font_color", COLOR_SYSTEM_DONE)
		else:
			systems_progress_label.text = "%d / %d" % [completed_count, total_systems]
			systems_progress_label.add_theme_color_override("font_color", COLOR_PROGRESS_NORMAL)
			
	# Render rows
	for system_id in MeltdownConfig.ALL_EMERGENCY_SYSTEMS:
		var is_done = _completed_systems.has(system_id)
		var display_name = MeltdownConfig.get_emergency_system_name(system_id)
		var row = _create_system_row(display_name, is_done)
		systems_list_container.add_child(row)
		
	# If successfully stabilized, hold green success state then smoothly disappear
	if all_stabilized:
		_is_active = false
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_interval(1.8)
		_fade_tween.tween_property(self, "modulate:a", 0.0, 0.4)
		_fade_tween.tween_callback(func(): visible = false)

## Creates a single system status row
func _create_system_row(system_name: String, is_completed: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	
	var bullet_label = Label.new()
	bullet_label.text = "✓" if is_completed else "○"
	bullet_label.custom_minimum_size = Vector2(14, 0)
	bullet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bullet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bullet_label.add_theme_font_size_override("font_size", 12)
	bullet_label.add_theme_color_override("font_color", COLOR_SYSTEM_DONE if is_completed else COLOR_BULLET_PENDING)
	bullet_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	bullet_label.add_theme_constant_override("shadow_offset_x", 1)
	bullet_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(bullet_label)
	
	var name_label = Label.new()
	name_label.text = system_name
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_PROGRESS_NORMAL if is_completed else COLOR_SYSTEM_PENDING)
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	name_label.add_theme_constant_override("shadow_offset_x", 1)
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	row.add_child(name_label)
	
	return row

## Subtle breathing/pulsing alarm animation
func _update_alarm_pulse() -> void:
	if not _is_active:
		return
	if alarm_icon == null or title_label == null:
		return
		
	var speed = 6.0 if _remaining_time <= 30.0 else 2.5
	var alpha = 0.70 + 0.30 * sin(_pulse_timer * speed)
	alarm_icon.modulate.a = alpha
	
	if _remaining_time <= 30.0 and timer_label != null:
		timer_label.modulate.a = alpha

func _show_hud_animated() -> void:
	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0)

func _hide_hud_animated() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.3)
	_fade_tween.tween_callback(func(): visible = false)

## Standalone preview helpers
func _populate_offline_preview() -> void:
	_is_active = true
	_remaining_time = 299.0
	_completed_systems = [MeltdownConfig.SYSTEM_RESTORE_POWER]
	modulate.a = 1.0
	visible = true
	_update_timer_display()
	_rebuild_systems_ui()

func _cycle_offline_systems() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 1.0
	visible = true
	_is_active = true
	
	if _completed_systems.is_empty():
		_completed_systems = [MeltdownConfig.SYSTEM_RESTORE_POWER]
	elif _completed_systems.size() == 1:
		_completed_systems = [MeltdownConfig.SYSTEM_RESTORE_POWER, MeltdownConfig.SYSTEM_RESTORE_COOLING]
	elif _completed_systems.size() == 2:
		_completed_systems = [MeltdownConfig.SYSTEM_RESTORE_POWER, MeltdownConfig.SYSTEM_RESTORE_COOLING, MeltdownConfig.SYSTEM_STABILIZE_ORION]
	else:
		_completed_systems.clear()
	_rebuild_systems_ui()

