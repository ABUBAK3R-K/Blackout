class_name EvidenceMarker
extends Area2D

## EvidenceMarker
## Discoverable Physical Crime Scene Clue Node for Post-Blackout Investigation.
## Physics Layer 5 (Evidence Markers) with player proximity triggers and inspection glow.
## Member 7 (Fatima - 2D Environment & Technical Artist).

const COLOR_INSPECTION_AMBER: Color = Color(1.0, 0.75, 0.1, 1.0)
const COLOR_DISCOVERED_CYAN: Color = Color(0.2, 0.8, 1.0, 0.8)

@export var evidence_id: String = ""
@export var evidence_type: String = ""
@export var room_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var severity: String = "high"
@export var is_discovered: bool = false
@export var is_active: bool = true

## Visual Components
@export var sprite: Sprite2D
@export var pin_icon: Sprite2D
@export var glow_light: PointLight2D
@export var collision_shape: CollisionShape2D

## Signals
signal evidence_inspected(player_node: Node2D, marker: EvidenceMarker)
signal evidence_uninspected(player_node: Node2D, marker: EvidenceMarker)
signal evidence_discovered_by_player(player_id: int, evidence_type: String)

func _ready() -> void:
	# Layer 5 = Evidence Markers (bit 5 = 16)
	# Mask Layer 2 = Players (bit 2 = 2)
	collision_layer = 16
	collision_mask = 2
	z_index = 1
	
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not pin_icon:
		pin_icon = get_node_or_null("PinIcon")
	if not glow_light:
		glow_light = get_node_or_null("GlowLight")
	if not collision_shape:
		collision_shape = get_node_or_null("CollisionShape2D")
		
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
		
	_load_default_sprite()
	_update_visuals()

func setup_from_type(type_key: String, target_room_id: String = "") -> void:
	evidence_type = type_key
	if not target_room_id.is_empty():
		room_id = target_room_id
	_load_default_sprite()
	_update_visuals()

func _load_default_sprite() -> void:
	if evidence_type.is_empty():
		return
		
	var path_map = {
		"classified_files_missing": "res://assets/sprites/stations/evidence_classified_files.png",
		"orion_core_data_extracted": "res://assets/sprites/stations/evidence_orion_data.png",
		"orion_containment_disabled": "res://assets/sprites/stations/evidence_containment_disabled.png",
		"generator_sabotaged": "res://assets/sprites/stations/evidence_generator_scorch.png",
		"security_tampered": "res://assets/sprites/stations/evidence_security_static.png"
	}
	
	var texture_path = path_map.get(evidence_type, "")
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		if sprite:
			sprite.texture = load(texture_path)
			
	var pin_path = "res://assets/sprites/stations/evidence_marker_pin.png"
	if pin_icon and ResourceLoader.exists(pin_path):
		pin_icon.texture = load(pin_path)

func discover(investigator_player_id: int) -> void:
	if not is_discovered:
		is_discovered = true
		_update_visuals()
		evidence_discovered_by_player.emit(investigator_player_id, evidence_type)

func set_inspected(active: bool) -> void:
	if pin_icon:
		pin_icon.visible = active or not is_discovered
		pin_icon.scale = Vector2(1.2, 1.2) if active else Vector2(1.0, 1.0)
	if glow_light:
		glow_light.energy = 0.9 if active else 0.4

func _update_visuals() -> void:
	if glow_light:
		glow_light.color = COLOR_DISCOVERED_CYAN if is_discovered else COLOR_INSPECTION_AMBER
		glow_light.energy = 0.4
	if pin_icon:
		pin_icon.visible = not is_discovered

func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("players") or body.name.begins_with("Player"):
		set_inspected(true)
		evidence_inspected.emit(body, self)

func _on_body_exited(body: Node2D) -> void:
	if not is_active:
		return
	if body.is_in_group("players") or body.name.begins_with("Player"):
		set_inspected(false)
		evidence_uninspected.emit(body, self)
