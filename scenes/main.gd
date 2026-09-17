extends Node2D

## Main entry scene for BLACKOUT.
## Coordinates Asterion facility map initialization, camera bounds clamping,
## dynamic blackout lighting registration (FR-12), and initial player spawn placement.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const RoundManager = preload("res://shared/round_manager.gd")
const MapManager = preload("res://client/environment/map_manager.gd")
const SpawnManager = preload("res://client/player/spawn_manager.gd")
const BlackoutLightingManager = preload("res://client/environment/blackout_lighting_manager.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const StateSync = preload("res://client/player/state_sync.gd")

@onready var facility_map: MapManager = $FacilityMap
@onready var spawn_manager: SpawnManager = $SpawnManager
@onready var blackout_lighting: BlackoutLightingManager = $BlackoutLighting
@onready var player: PlayerController = $Player
@onready var state_sync: StateSync = $StateSync
@onready var status_label: Label = $CanvasLayer/CenterContainer/VBoxContainer/StatusLabel
@onready var role_label: Label = get_node_or_null("CanvasLayer/RoleContainer/RolePanel/RoleLabel")
@onready var round_label: Label = get_node_or_null("CanvasLayer/RoundContainer/RoundPanel/RoundLabel")

func _ready() -> void:
	print("[BLACKOUT] Asterion Research Facility client initialized.")

	# 1. Configure camera boundaries to match the facility outer limits
	if facility_map != null and player != null and player.camera != null:
		var limits = facility_map.get_camera_limits()
		player.camera.set_camera_limits(limits.left, limits.top, limits.right, limits.bottom)

	# 2. Position the initial local player at their assigned spawn position
	if spawn_manager != null and player != null:
		spawn_manager.place_player(player, player.slot_id)

	# 3. Register local player's vision lights with BlackoutLightingManager (FR-12)
	if blackout_lighting != null and player != null:
		if player.vision_light != null:
			blackout_lighting.register_local_player_light(player.vision_light, player.directional_light)
		blackout_lighting.blackout_state_changed.connect(_on_blackout_state_changed)

	# 4. Register local player with StateSync for 20 Hz movement transmission
	if state_sync != null and player != null:
		state_sync.register_local_player(player)

	# 5. Initialize Role System listener and HUD
	if player != null:
		if not player.role_changed.is_connected(_on_player_role_changed):
			player.role_changed.connect(_on_player_role_changed)
		_update_role_ui()

	_update_round_ui(RoundManager.RoundState.LOBBY)
	_connect_network_listeners()

## Connects to NetworkManager autoload to receive authoritative server role, sabotage, and round updates.
func _connect_network_listeners() -> void:
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		var client = net_mgr.client
		if not client.role_assigned.is_connected(_on_network_role_assigned):
			client.role_assigned.connect(_on_network_role_assigned)
		if not client.sabotage_state_synced.is_connected(_on_network_sabotage_state_synced):
			client.sabotage_state_synced.connect(_on_network_sabotage_state_synced)
		if not client.round_state_synced.is_connected(_on_network_round_state_synced):
			client.round_state_synced.connect(_on_network_round_state_synced)

		if client.assigned_role != NetworkConfig.PlayerRole.NONE:
			_on_network_role_assigned(client.assigned_role)
		_update_round_ui(client.current_round_state)

func _on_network_role_assigned(new_role: NetworkConfig.PlayerRole) -> void:
	if player != null:
		player.set_role(new_role)
	_update_role_ui()

func _on_player_role_changed(_new_role: NetworkConfig.PlayerRole) -> void:
	_update_role_ui()

func _on_network_round_state_synced(new_round_state: int) -> void:
	_update_round_ui(new_round_state)

func _update_round_ui(state: int) -> void:
	if round_label == null:
		return

	var state_enum = state as RoundManager.RoundState
	round_label.text = "ROUND: %s" % RoundManager.get_state_name(state_enum)

	match state_enum:
		RoundManager.RoundState.LOBBY:
			round_label.set("theme_override_colors/font_color", Color(0.8, 0.85, 0.95, 1.0))
		RoundManager.RoundState.STARTING:
			round_label.set("theme_override_colors/font_color", Color(0.95, 0.75, 0.2, 1.0))
		RoundManager.RoundState.ROLE_ASSIGNMENT:
			round_label.set("theme_override_colors/font_color", Color(0.3, 0.8, 1.0, 1.0))
		RoundManager.RoundState.PLAYING:
			round_label.set("theme_override_colors/font_color", Color(0.2, 0.9, 0.4, 1.0))
		RoundManager.RoundState.ENDING:
			round_label.set("theme_override_colors/font_color", Color(0.9, 0.3, 0.3, 1.0))
		RoundManager.RoundState.RESULTS:
			round_label.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.2, 1.0))
		_:
			round_label.set("theme_override_colors/font_color", Color(0.8, 0.85, 0.95, 1.0))

func _update_role_ui() -> void:
	if role_label != null:
		var current_role: NetworkConfig.PlayerRole = player.get_role() if player != null else NetworkConfig.PlayerRole.NONE
		match current_role:
			NetworkConfig.PlayerRole.IMPOSTOR:
				role_label.text = "ROLE: IMPOSTOR"
				role_label.set("theme_override_colors/font_color", Color(0.9, 0.25, 0.25, 1.0))
			NetworkConfig.PlayerRole.CREW:
				role_label.text = "ROLE: CREW"
				role_label.set("theme_override_colors/font_color", Color(0.2, 0.9, 0.4, 1.0))
			_:
				role_label.text = "ROLE: CREW"
				role_label.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))

	# Update status label with role-specific hint
	_update_default_status_text()

func _update_default_status_text() -> void:
	if status_label == null:
		return
	if blackout_lighting != null and blackout_lighting.is_blackout_active():
		return # Let blackout handler control status text during blackout

	var is_imp: bool = player != null and player.is_impostor()
	if is_imp:
		status_label.text = "Asterion Facility — WASD Move | E Interact | [Q] Sabotage Power | [F] Flashlight"
	else:
		status_label.text = "Asterion Facility — WASD Move | E Interact | [B] Toggle Power | [F] Flashlight"
	status_label.set("theme_override_colors/font_color", Color(1.0, 1.0, 1.0, 1.0))

func _on_network_sabotage_state_synced(sabotage_type: int, state: int, _duration: float) -> void:
	if sabotage_type == SabotageManager.SabotageType.POWER_BLACKOUT:
		if state == SabotageManager.SabotageState.ACTIVE:
			if blackout_lighting != null and not blackout_lighting.is_blackout_active():
				blackout_lighting.set_blackout(true)
			_update_sabotage_hud(true)
		elif state == SabotageManager.SabotageState.RESOLVED or state == SabotageManager.SabotageState.INACTIVE:
			if blackout_lighting != null and blackout_lighting.is_blackout_active():
				blackout_lighting.set_blackout(false)
			_update_sabotage_hud(false)

func _update_sabotage_hud(is_active: bool) -> void:
	if status_label == null:
		return

	if is_active:
		var is_imp: bool = player != null and player.is_impostor()
		if is_imp:
			status_label.text = "⚠ POWER SABOTAGE ACTIVE — Radial Vision + Flashlight Active | [F] Flashlight"
			status_label.set("theme_override_colors/font_color", Color(1.0, 0.25, 0.25, 1.0))
		else:
			status_label.text = "⚠ POWER FAILURE — Emergency Power Engaged | [F] Flashlight | [E] Interact"
			status_label.set("theme_override_colors/font_color", Color(1.0, 0.45, 0.2, 1.0))
	else:
		_update_default_status_text()

func _on_blackout_state_changed(is_blackout: bool) -> void:
	_update_sabotage_hud(is_blackout)



