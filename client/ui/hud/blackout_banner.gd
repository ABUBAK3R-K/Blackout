class_name BlackoutBannerUI
extends Control

## BlackoutBannerUI — Member 5 (UI/UX Frontend)
## Compact warning countdown banner for the BLACKOUT in-game HUD.
##
## Appears during the active Blackout phase, displaying a continuous countdown
## in 'MM:SS' format. Consumes authoritative blackout events from NetworkManager.client.

const NetworkConfig = preload("res://shared/network_config.gd")

## Styling constants
const COLOR_WARNING_ICON: Color = Color(1.0, 0.28, 0.30, 1.0)       # Warning crimson (#FF474D)
const COLOR_TITLE: Color = Color(0.95, 0.95, 0.98, 1.0)              # Header white
const COLOR_TIMER_NORMAL: Color = Color(1.0, 0.32, 0.32, 1.0)       # Warning Red clock timer
const COLOR_TIMER_CRITICAL: Color = Color(1.0, 0.20, 0.20, 1.0)      # High-urgency pulse red (<= 10s)

## Node references
@onready var panel_container: PanelContainer = $PanelContainer
@onready var icon_label: Label = $PanelContainer/MarginContainer/HBoxContainer/IconLabel
@onready var title_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TitleLabel
@onready var clock_icon: Label = $PanelContainer/MarginContainer/HBoxContainer/ClockIcon
@onready var timer_label: Label = $PanelContainer/MarginContainer/HBoxContainer/TimerLabel

## Internal state
var _is_active: bool = false
var _remaining_time: float = 0.0
var _is_connected_to_network: bool = false
var _fade_tween: Tween = null

func _ready() -> void:
	_ensure_node_references()
	_connect_to_network_events()
	
	# Hidden by default during normal gameplay
	if not _is_connected_to_server():
		# Standalone preview: start with banner visible in preview mode
		visible = true
		_populate_offline_preview()
	else:
		visible = false

func _ensure_node_references() -> void:
	if panel_container == null and has_node("PanelContainer"):
		panel_container = get_node("PanelContainer")
	if icon_label == null and has_node("PanelContainer/MarginContainer/HBoxContainer/IconLabel"):
		icon_label = get_node("PanelContainer/MarginContainer/HBoxContainer/IconLabel")
	if title_label == null and has_node("PanelContainer/MarginContainer/HBoxContainer/TitleLabel"):
		title_label = get_node("PanelContainer/MarginContainer/HBoxContainer/TitleLabel")
	if clock_icon == null and has_node("PanelContainer/MarginContainer/HBoxContainer/ClockIcon"):
		clock_icon = get_node("PanelContainer/MarginContainer/HBoxContainer/ClockIcon")
	if timer_label == null and has_node("PanelContainer/MarginContainer/HBoxContainer/TimerLabel"):
		timer_label = get_node("PanelContainer/MarginContainer/HBoxContainer/TimerLabel")

func _process(delta: float) -> void:
	if _is_active:
		if _remaining_time > 0.0:
			_remaining_time = max(0.0, _remaining_time - delta)
			_update_timer_display()
		elif _remaining_time <= 0.0:
			_remaining_time = 0.0
			_update_timer_display()

func _unhandled_input(event: InputEvent) -> void:
	# Offline preview hotkeys
	if not _is_connected_to_server() and event is InputEventKey and event.pressed:
		if event.keycode == KEY_B:
			_toggle_offline_blackout()
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
			if client.has_signal("blackout_started") and not client.blackout_started.is_connected(_on_blackout_started):
				client.blackout_started.connect(_on_blackout_started)
			if client.has_signal("blackout_ended") and not client.blackout_ended.is_connected(_on_blackout_ended):
				client.blackout_ended.connect(_on_blackout_ended)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			_is_connected_to_network = true
			
			if _is_connected_to_server():
				if client.is_blackout_active:
					start_blackout(client.blackout_remaining_duration)
				else:
					end_blackout(false)

func _on_blackout_started(duration: float) -> void:
	start_blackout(duration)

func _on_blackout_ended() -> void:
	end_blackout(true)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.BLACKOUT_ACTIVE:
		if not _is_active:
			start_blackout(40.0)
	else:
		if _is_active:
			end_blackout(true)

## Public API to activate the Blackout countdown banner
func start_blackout(duration: float) -> void:
	_ensure_node_references()
	_is_active = true
	_remaining_time = max(0.0, duration)
	_update_timer_display()
	_show_banner_animated()

## Public API to update the remaining duration
func set_remaining_time(seconds: float) -> void:
	_remaining_time = max(0.0, seconds)
	_update_timer_display()

## Public API to dismiss/hide the Blackout banner
func end_blackout(animated: bool = true) -> void:
	_is_active = false
	_remaining_time = 0.0
	_update_timer_display()
	if animated:
		_hide_banner_animated()
	else:
		visible = false
		modulate.a = 0.0

## Returns whether Blackout banner is currently active
func is_blackout_active() -> bool:
	return _is_active

## Formats float seconds into 'MM:SS' string format
static func format_time(seconds: float) -> String:
	if is_nan(seconds) or seconds < 0.0:
		return "00:00"
	var total_sec: int = int(ceil(max(0.0, seconds)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]

## Updates timer text and warning urgency coloring
func _update_timer_display() -> void:
	_ensure_node_references()
	if timer_label == null:
		return
		
	timer_label.text = format_time(_remaining_time)
	
	# Critical threshold: under 10 seconds turns warning red
	if _remaining_time <= 10.0 and _remaining_time > 0.0:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_CRITICAL)
	elif _remaining_time <= 0.0:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_CRITICAL)
	else:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)

## Smooth fade-in transition
func _show_banner_animated() -> void:
	visible = true
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, 0.25).from(0.0)

## Smooth fade-out transition
func _hide_banner_animated() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
	_fade_tween.tween_callback(func(): visible = false)

## Standalone preview helpers
func _populate_offline_preview() -> void:
	_is_active = true
	_remaining_time = 37.0
	modulate.a = 1.0
	visible = true
	_update_timer_display()

func _toggle_offline_blackout() -> void:
	if _is_active:
		end_blackout(true)
	else:
		start_blackout(40.0)
