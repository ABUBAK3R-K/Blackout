class_name EmergencyConsole
extends Node2D

## Dedicated Meltdown Emergency Restoration Console for BLACKOUT (Stage 19).
## Integrates physical facility emergency consoles with InteractableTrigger proximity detection,
## InteractionAudio feedback, role-based repair authorization (Crew-only, alive-only),
## and server-authoritative emergency system completion broadcasts.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const InteractionAudio = preload("res://client/environment/interaction_audio.gd")

signal emergency_repair_requested(system_id: String, player: Node2D)
signal emergency_repair_completed(system_id: String)

@export_group("Emergency System Identity")
## Unique system identifier matching MeltdownConfig (e.g. 'restore_power', 'restore_cooling', 'stabilize_orion').
@export var system_id: String = MeltdownConfig.SYSTEM_RESTORE_POWER

## Human-readable system name.
@export var system_name: String = "Restore Power"

## Room location in the Asterion Facility.
@export var room_location: String = "Generator Room"

## Proximity radius for interaction in pixels.
@export var interaction_radius: float = 48.0

## Flag indicating whether this emergency system has been restored.
var is_completed: bool = false

@onready var trigger: InteractableTrigger = get_node_or_null("InteractableTrigger")
@onready var interaction_audio: InteractionAudio = get_node_or_null("InteractionAudio")
@onready var indicator_light: Polygon2D = get_node_or_null("Visual/IndicatorLight")
@onready var status_label: Label = get_node_or_null("StatusLabel")

func _ready() -> void:
	add_to_group("emergency_console")
	_setup_trigger()
	_update_visuals()
	_auto_connect_network_signals()

## Initializes or configures the child InteractableTrigger.
func _setup_trigger() -> void:
	if trigger == null:
		trigger = InteractableTrigger.new()
		trigger.name = "InteractableTrigger"
		add_child(trigger)

	trigger.interactable_id = system_id
	trigger.interaction_radius = interaction_radius
	trigger.prompt_text = "Press E to %s" % system_name

	if not trigger.interacted.is_connected(_on_interacted):
		trigger.interacted.connect(_on_interacted)

## Flag for unit test override of meltdown active state.
var force_meltdown_active: bool = false

## Executes interaction when an in-range player presses E.
func _on_interacted(player: Node2D) -> void:
	if player == null:
		return
	if player.get("is_local_player") == false:
		return

	# 1. Verify that a Meltdown is actively in progress
	var is_meltdown = _is_meltdown_active()
	if not is_meltdown:
		if trigger != null:
			trigger.set_prompt("Emergency Console (Offline - No Active Meltdown)")
		return

	# 2. Verify system is not already restored
	if is_completed:
		if trigger != null:
			trigger.set_prompt("%s [SYSTEM RESTORED]" % system_name)
		return

	# 3. Verify local player is alive and is Crew
	var is_dead: bool = player.get("is_eliminated") == true
	var is_imp: bool = false
	if player.has_method("is_impostor"):
		is_imp = player.is_impostor()
	elif player.has_method("get_role"):
		is_imp = (player.get_role() == NetworkConfig.PlayerRole.IMPOSTOR)

	if is_dead:
		if trigger != null:
			trigger.set_prompt("Eliminated players cannot repair emergency systems")
		print("[EmergencyConsole] Eliminated player attempted emergency repair on '%s' (Rejected)." % system_id)
		return

	if is_imp:
		if trigger != null:
			trigger.set_prompt("Unauthorized Access (Impostor cannot restore systems)")
		print("[EmergencyConsole] Impostor attempted emergency repair on '%s' (Rejected)." % system_id)
		return

	# 4. Play interaction audio chime
	if interaction_audio != null:
		if interaction_audio.has_method("play_activate"):
			interaction_audio.play_activate()
		elif interaction_audio.has_method("play_sound"):
			interaction_audio.play_sound("activate")

	print("[EmergencyConsole] Crew player '%s' requesting emergency repair for '%s'..." % [
		player.name, system_id
	])

	# 5. Authoritatively send repair request through NetworkManager / ClientNetworkManager
	var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if net_mgr != null and net_mgr.has_method("complete_emergency_system"):
		net_mgr.complete_emergency_system(system_id)
	elif is_inside_tree():
		var client_mgr = get_tree().root.find_child("Client", true, false)
		if client_mgr != null and client_mgr.has_method("request_complete_emergency_system"):
			client_mgr.request_complete_emergency_system(system_id)

	emergency_repair_requested.emit(system_id, player)

## Server-authoritative completion handler.
func mark_completed() -> void:
	if is_completed:
		return

	is_completed = true
	_update_visuals()

	if trigger != null:
		trigger.set_prompt("%s [RESTORED]" % system_name)
		trigger.set_interactive(false)

	if interaction_audio != null:
		if interaction_audio.has_method("play_objective_complete"):
			interaction_audio.play_objective_complete()
		elif interaction_audio.has_method("play_sound"):
			interaction_audio.play_sound("objective_complete")

	emergency_repair_completed.emit(system_id)
	print("[EmergencyConsole] Emergency system '%s' (%s) is now marked COMPLETED." % [
		system_name, system_id
	])

## Automatically connects to NetworkManager client signals.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for authoritative completion events.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("emergency_system_completed") and not client_mgr.emergency_system_completed.is_connected(_on_network_emergency_system_completed):
		client_mgr.emergency_system_completed.connect(_on_network_emergency_system_completed)

	if client_mgr.has_signal("meltdown_started") and not client_mgr.meltdown_started.is_connected(_on_network_meltdown_started):
		client_mgr.meltdown_started.connect(_on_network_meltdown_started)

	if client_mgr.has_signal("game_state_changed") and not client_mgr.game_state_changed.is_connected(_on_network_game_state_changed):
		client_mgr.game_state_changed.connect(_on_network_game_state_changed)

func _on_network_emergency_system_completed(completed_sys_id: String, _completed_systems: Array) -> void:
	if completed_sys_id == system_id:
		mark_completed()

func _on_network_meltdown_started(_duration: float, _impostor_alive: bool) -> void:
	_update_visuals()

func _on_network_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.LOBBY:
		is_completed = false
		if trigger != null:
			trigger.set_prompt("Emergency Console: %s (Standby)" % system_name)
			trigger.set_interactive(false)
	_update_visuals()

func reset() -> void:
	is_completed = false
	if trigger != null:
		trigger.set_prompt("Emergency Console: %s (Standby)" % system_name)
		trigger.set_interactive(false)
	_update_visuals()

func _is_meltdown_active() -> bool:
	if force_meltdown_active:
		return true
	var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		return net_mgr.client.is_meltdown_active or net_mgr.client.current_game_state == NetworkConfig.GameState.MELTDOWN
	return false

func _update_visuals() -> void:
	var is_meltdown = _is_meltdown_active()

	if is_completed:
		if indicator_light != null:
			indicator_light.color = Color(0.2, 0.95, 0.4, 1.0)
		if status_label != null:
			status_label.text = "%s: RESTORED" % system_name
			status_label.set("theme_override_colors/font_color", Color(0.25, 0.9, 0.45, 0.9))
		if trigger != null:
			trigger.set_prompt("%s [RESTORED]" % system_name)
	elif is_meltdown:
		if indicator_light != null:
			indicator_light.color = Color(1.0, 0.25, 0.25, 1.0) # Pulsing red/alert
		if status_label != null:
			status_label.text = "%s: OFFLINE (CRITICAL)" % system_name
			status_label.set("theme_override_colors/font_color", Color(1.0, 0.35, 0.35, 0.9))
		if trigger != null:
			trigger.set_prompt("Press E to %s" % system_name)
			trigger.set_interactive(true)
	else:
		if indicator_light != null:
			indicator_light.color = Color(0.4, 0.45, 0.55, 0.6) # Neutral standby
		if status_label != null:
			status_label.text = "%s: STANDBY" % system_name
			status_label.set("theme_override_colors/font_color", Color(0.6, 0.65, 0.75, 0.7))
		if trigger != null:
			trigger.set_prompt("Emergency Console: %s (Standby)" % system_name)
