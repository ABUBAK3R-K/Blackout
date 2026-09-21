class_name PlayerCorpse
extends Node2D

## Player Corpse / Body Entity for BLACKOUT (Stage 24).
## Spawns at the authoritative death position when a player is eliminated.
## Provides InteractableTrigger for proximity body reporting ([E] key) to initiate an emergency meeting.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")

signal body_report_requested(corpse_id: int, player: Node2D)
signal body_reported(corpse_id: int)

@export_group("Corpse Identity")
## Unique ID assigned by the server for this corpse.
@export var corpse_id: int = 0
## Peer ID of the eliminated victim.
@export var victim_peer_id: int = 0
## Display name of the victim.
@export var victim_name: String = "Fallen Crew"
## Radius in pixels for body report interaction.
@export var interaction_radius: float = 80.0

## Flag indicating whether this corpse has already been reported.
var is_reported: bool = false

@onready var trigger: InteractableTrigger = get_node_or_null("InteractableTrigger")
@onready var visual: Node2D = get_node_or_null("Visual")
@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var body_polygon: Polygon2D = get_node_or_null("Visual/BodyPolygon")
@onready var visor_polygon: Polygon2D = get_node_or_null("Visual/VisorPolygon")
@onready var marker_polygon: Polygon2D = get_node_or_null("Visual/MarkerPolygon")

func _ready() -> void:
	add_to_group("player_corpses")
	_setup_trigger()
	_update_visuals()

## Initializes and configures the InteractableTrigger child.
func _setup_trigger() -> void:
	if trigger == null:
		trigger = InteractableTrigger.new()
		trigger.name = "InteractableTrigger"
		add_child(trigger)

	trigger.interactable_id = "corpse_%d" % corpse_id
	trigger.interaction_radius = interaction_radius
	trigger.prompt_text = "REPORT BODY [E]"

	if not trigger.interacted.is_connected(_on_interacted):
		trigger.interacted.connect(_on_interacted)

## Configures the corpse identity and authoritative death position.
func setup_corpse(p_corpse_id: int, p_victim_peer_id: int, p_victim_name: String, p_pos: Vector2) -> void:
	corpse_id = p_corpse_id
	victim_peer_id = p_victim_peer_id
	victim_name = p_victim_name
	global_position = p_pos
	is_reported = false

	if trigger != null:
		trigger.interactable_id = "corpse_%d" % corpse_id
		trigger.prompt_text = "REPORT BODY [E]"
		trigger.set_interactive(true)

	_update_visuals()

## Handles interaction when an in-range player presses E.
func _on_interacted(player: Node2D) -> void:
	if player == null:
		return
	if player.get("is_local_player") == false:
		return

	# 1. Verify corpse is not already reported
	if is_reported:
		if trigger != null:
			trigger.set_prompt("[BODY ALREADY REPORTED]")
		return

	# 2. Verify player is alive and not eliminated
	var is_dead: bool = player.get("is_eliminated") == true
	if is_dead:
		if trigger != null:
			trigger.set_prompt("Eliminated players cannot report bodies")
		print("[PlayerCorpse] Eliminated player attempted to report body %d (Rejected)." % corpse_id)
		return

	print("[PlayerCorpse] Player '%s' reporting body #%d (%s)..." % [
		player.name, corpse_id, victim_name
	])

	# 3. Dispatch authoritative report request through NetworkManager / ClientNetworkManager
	var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	if net_mgr != null and net_mgr.has_method("request_report_body"):
		net_mgr.request_report_body(corpse_id)
	elif is_inside_tree():
		var client_mgr = get_tree().root.find_child("Client", true, false)
		if client_mgr != null and client_mgr.has_method("request_report_body"):
			client_mgr.request_report_body(corpse_id)

	body_report_requested.emit(corpse_id, player)

## Server-authoritative report completion handler.
func mark_reported() -> void:
	if is_reported:
		return

	is_reported = true
	if trigger != null:
		trigger.set_prompt("[BODY REPORTED]")
		trigger.set_interactive(false)

	_update_visuals()
	body_reported.emit(corpse_id)
	print("[PlayerCorpse] Corpse #%d marked as REPORTED." % corpse_id)

func reset() -> void:
	is_reported = false
	if trigger != null:
		trigger.prompt_text = "REPORT BODY [E]"
		trigger.set_interactive(true)
	_update_visuals()

func _update_visuals() -> void:
	if name_label != null:
		name_label.text = victim_name
		if is_reported:
			name_label.set("theme_override_colors/font_color", Color(0.6, 0.65, 0.7, 0.6))
		else:
			name_label.set("theme_override_colors/font_color", Color(0.95, 0.35, 0.35, 0.95))

	if body_polygon != null:
		if is_reported:
			body_polygon.color = Color(0.35, 0.38, 0.42, 0.6) # Dimmed / processed corpse
		else:
			body_polygon.color = Color(0.7, 0.2, 0.22, 0.95) # Red hazard / fallen crew

	if visor_polygon != null:
		if is_reported:
			visor_polygon.color = Color(0.2, 0.25, 0.3, 0.5)
		else:
			visor_polygon.color = Color(0.15, 0.35, 0.5, 0.85)

	if marker_polygon != null:
		marker_polygon.visible = not is_reported
