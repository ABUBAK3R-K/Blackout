class_name BlackoutLightingManager
extends Node2D

## 2D Dynamic Blackout Vision & Lighting Engine for BLACKOUT (FR-12).
## Manages facility ambient darkness via CanvasModulate, soft local player vision lighting,
## smooth power loss/restore transitions, and ClientNetworkManager signal synchronization.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal blackout_state_changed(is_active: bool)
signal blackout_transition_completed(is_active: bool)

## Normal daylight facility ambient lighting.
const NORMAL_AMBIENT: Color = Color(1.0, 1.0, 1.0, 1.0)
## Emergency blackout ambient lighting (dark sci-fi blue/gray tone allowing navigation).
const BLACKOUT_AMBIENT: Color = Color(0.06, 0.08, 0.12, 1.0)

## Default duration for power loss / restoration lighting transitions.
const DEFAULT_TRANSITION_SEC: float = 0.8
## Target light energy of local player vision cone during blackout.
const BLACKOUT_LIGHT_ENERGY: float = 1.25
## Target light energy of directional flashlight beam during blackout.
const BLACKOUT_FLASHLIGHT_ENERGY: float = 1.4

@export_group("Lighting Settings")
## Initial power state at level launch.
@export var is_blackout: bool = false
## Enable 'B' key debug toggle for development testing.
@export var enable_debug_key: bool = true

@onready var canvas_modulate: CanvasModulate = $CanvasModulate

## Reference to the local player's radial vision light node (PointLight2D).
var local_player_light: PointLight2D = null
## Reference to the local player's directional flashlight light node (PointLight2D).
var local_directional_light: PointLight2D = null
## Reference to active tween for smooth light transitions.
var transition_tween: Tween = null

func _ready() -> void:
	_setup_canvas_modulate()
	_apply_instant_state(is_blackout)
	_auto_connect_network_signals()

func _unhandled_input(event: InputEvent) -> void:
	if not enable_debug_key:
		return

	# Debug testing toggle: Press 'B' to toggle Blackout mode
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_B:
			toggle_blackout()

## Configures or ensures the CanvasModulate node exists.
func _setup_canvas_modulate() -> void:
	if canvas_modulate == null:
		canvas_modulate = CanvasModulate.new()
		canvas_modulate.name = "CanvasModulate"
		add_child(canvas_modulate)

## Automatically connects to the global NetworkManager autoload if available.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for authoritative server Blackout transitions.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("blackout_started") and not client_mgr.blackout_started.is_connected(_on_server_blackout_started):
		client_mgr.blackout_started.connect(_on_server_blackout_started)

	if client_mgr.has_signal("blackout_ended") and not client_mgr.blackout_ended.is_connected(_on_server_blackout_ended):
		client_mgr.blackout_ended.connect(_on_server_blackout_ended)

## Registers the local player's lighting components (radial vision + directional flashlight).
func register_local_player_light(light_node: PointLight2D, dir_light_node: PointLight2D = null) -> void:
	local_player_light = light_node
	local_directional_light = dir_light_node
	if local_player_light != null:
		local_player_light.enabled = is_blackout
		local_player_light.energy = BLACKOUT_LIGHT_ENERGY if is_blackout else 0.0
	if local_directional_light != null:
		local_directional_light.enabled = is_blackout
		local_directional_light.energy = BLACKOUT_FLASHLIGHT_ENERGY if is_blackout else 0.0

## Enables or disables Blackout mode with a smooth cinematic transition.
func set_blackout(active: bool, duration: float = DEFAULT_TRANSITION_SEC) -> void:
	if is_blackout == active and transition_tween == null:
		return

	is_blackout = active
	blackout_state_changed.emit(is_blackout)
	print("[BlackoutLightingManager] Transitioning lighting to: %s (Duration: %.2fs)." % [
		"BLACKOUT" if is_blackout else "POWER_ON", duration
	])

	if transition_tween != null and transition_tween.is_valid():
		transition_tween.kill()
		transition_tween = null

	if duration <= 0.0:
		_apply_instant_state(active)
		blackout_transition_completed.emit(is_blackout)
		return

	var target_ambient: Color = BLACKOUT_AMBIENT if is_blackout else NORMAL_AMBIENT
	var target_energy: float = BLACKOUT_LIGHT_ENERGY if is_blackout else 0.0
	var target_flash_energy: float = BLACKOUT_FLASHLIGHT_ENERGY if is_blackout else 0.0

	# Enable player lights before fade-in if going into blackout
	if is_blackout:
		if local_player_light != null:
			local_player_light.enabled = true
		if local_directional_light != null:
			local_directional_light.enabled = true

	transition_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if canvas_modulate != null:
		transition_tween.tween_property(canvas_modulate, "color", target_ambient, duration)

	if local_player_light != null:
		transition_tween.tween_property(local_player_light, "energy", target_energy, duration)

	if local_directional_light != null:
		transition_tween.tween_property(local_directional_light, "energy", target_flash_energy, duration)

	transition_tween.chain().tween_callback(_on_transition_finished)

## Toggles the current blackout state. Returns the new state.
func toggle_blackout(duration: float = DEFAULT_TRANSITION_SEC) -> bool:
	set_blackout(not is_blackout, duration)
	return is_blackout

## Returns true if Blackout mode is currently active.
func is_blackout_active() -> bool:
	return is_blackout

func _apply_instant_state(active: bool) -> void:
	is_blackout = active
	if canvas_modulate != null:
		canvas_modulate.color = BLACKOUT_AMBIENT if is_blackout else NORMAL_AMBIENT

	if local_player_light != null:
		local_player_light.enabled = is_blackout
		local_player_light.energy = BLACKOUT_LIGHT_ENERGY if is_blackout else 0.0

	if local_directional_light != null:
		local_directional_light.enabled = is_blackout
		local_directional_light.energy = BLACKOUT_FLASHLIGHT_ENERGY if is_blackout else 0.0

func _on_transition_finished() -> void:
	if not is_blackout:
		if local_player_light != null:
			local_player_light.enabled = false
		if local_directional_light != null:
			local_directional_light.enabled = false

	transition_tween = null
	blackout_transition_completed.emit(is_blackout)

# --- Network Callbacks ---

func _on_server_blackout_started(_duration: float) -> void:
	set_blackout(true)

func _on_server_blackout_ended() -> void:
	set_blackout(false)
