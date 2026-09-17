class_name EvidenceManager
extends RefCounted

## Server-authoritative Evidence & Investigation Manager for BLACKOUT.
## Converts factual gameplay events that occurred during Blackout into objective, discoverable evidence.

const NetworkConfig = preload("res://shared/network_config.gd")
const EvidenceConfig = preload("res://shared/evidence_config.gd")
const EvidenceDefinition = preload("res://shared/evidence_definition.gd")

signal evidence_created(evidence: EvidenceDefinition)
signal investigation_finalized(public_evidence_list: Array)

## Internal storage: evidence_id (String) -> EvidenceDefinition
var evidence_records: Dictionary = {}

## Tracking sets for deduplication
var recorded_objective_ids: Dictionary = {} # objective_id (String) -> evidence_id (String)
var recorded_recovery_ids: Dictionary = {}  # system_id (String) -> evidence_id (String)

var evidence_counter: int = 0
var is_investigation_active: bool = false

func clear() -> void:
	evidence_records.clear()
	recorded_objective_ids.clear()
	recorded_recovery_ids.clear()
	evidence_counter = 0
	is_investigation_active = false

func _generate_evidence_id(prefix: String) -> String:
	evidence_counter += 1
	return "ev_%s_%d" % [prefix, evidence_counter]

## Generates factual evidence from a completed Impostor secret objective.
func create_evidence_from_objective(
	objective_id: String,
	actor_peer_id: int = 0,
	custom_timestamp: float = 0.0
) -> EvidenceDefinition:
	if recorded_objective_ids.has(objective_id):
		push_warning("[EvidenceManager] Deduplication: Evidence for objective '%s' already exists." % objective_id)
		return evidence_records[recorded_objective_ids[objective_id]]

	if not EvidenceConfig.OBJECTIVE_EVIDENCE_TEMPLATES.has(objective_id):
		push_warning("[EvidenceManager] No evidence template defined for objective ID '%s'." % objective_id)
		return null

	var template: Dictionary = EvidenceConfig.OBJECTIVE_EVIDENCE_TEMPLATES[objective_id]
	var ev_id = _generate_evidence_id(template.evidence_type)
	var timestamp = custom_timestamp if custom_timestamp > 0.0 else Time.get_unix_time_from_system()

	var ev = EvidenceDefinition.new(
		ev_id,
		template.evidence_type,
		template.display_name,
		template.description,
		template.source_system,
		template.location_id,
		timestamp,
		template.severity,
		template.category,
		objective_id,
		"",
		actor_peer_id
	)

	evidence_records[ev_id] = ev
	recorded_objective_ids[objective_id] = ev_id

	print("[EvidenceManager] Factual evidence generated: '%s' (ID: %s | Location: %s)." % [
		ev.display_name, ev_id, ev.location_id
	])

	evidence_created.emit(ev)
	return ev

## Generates factual evidence from a completed Crew recovery subsystem.
func create_evidence_from_recovery(
	system_id: String,
	system_display_name: String,
	location_id: String = "station_subsystem",
	actor_peer_id: int = 0,
	custom_timestamp: float = 0.0
) -> EvidenceDefinition:
	if recorded_recovery_ids.has(system_id):
		push_warning("[EvidenceManager] Deduplication: Evidence for recovery subsystem '%s' already exists." % system_id)
		return evidence_records[recorded_recovery_ids[system_id]]

	var template: Dictionary = EvidenceConfig.RECOVERY_EVIDENCE_TEMPLATE
	var ev_id = _generate_evidence_id("recovery_%s" % system_id)
	var timestamp = custom_timestamp if custom_timestamp > 0.0 else Time.get_unix_time_from_system()
	var desc = template.description_template % system_display_name

	var ev = EvidenceDefinition.new(
		ev_id,
		template.evidence_type,
		"%s Restored" % system_display_name,
		desc,
		system_id,
		location_id,
		timestamp,
		template.severity,
		template.category,
		"",
		system_id,
		actor_peer_id
	)

	evidence_records[ev_id] = ev
	recorded_recovery_ids[system_id] = ev_id

	print("[EvidenceManager] Factual recovery evidence generated: '%s' (ID: %s)." % [
		ev.display_name, ev_id
	])

	evidence_created.emit(ev)
	return ev

## Creates generic environmental / facility evidence.
func create_environmental_evidence(
	evidence_type: String,
	display_name: String,
	description: String,
	source_system: String,
	location_id: String,
	severity: String = "info",
	category: String = "environmental",
	custom_timestamp: float = 0.0
) -> EvidenceDefinition:
	var ev_id = _generate_evidence_id(evidence_type)
	var timestamp = custom_timestamp if custom_timestamp > 0.0 else Time.get_unix_time_from_system()

	var ev = EvidenceDefinition.new(
		ev_id,
		evidence_type,
		display_name,
		description,
		source_system,
		location_id,
		timestamp,
		severity,
		category
	)

	evidence_records[ev_id] = ev
	print("[EvidenceManager] Environmental evidence created: '%s' (ID: %s)." % [display_name, ev_id])
	evidence_created.emit(ev)
	return ev

## Finalizes the evidence collection when entering POST_BLACKOUT_INVESTIGATION.
func finalize_investigation() -> Array:
	is_investigation_active = true
	var public_list = get_public_evidence_list()
	print("[EvidenceManager] Investigation phase finalized. %d factual evidence records available for public inspection." % [
		public_list.size()
	])
	investigation_finalized.emit(public_list)
	return public_list

## Returns the public serialized evidence array.
## Guaranteed to be sanitized of all hidden attribution, Impostor IDs, and private roles.
func get_public_evidence_list() -> Array:
	var list: Array = []
	for ev: EvidenceDefinition in evidence_records.values():
		list.append(ev.to_public_dict())
	return list

func get_evidence_count() -> int:
	return evidence_records.size()

func get_evidence(evidence_id: String) -> EvidenceDefinition:
	return evidence_records.get(evidence_id, null)

func handle_player_disconnect(peer_id: int) -> void:
	# All collected evidence survives player disconnection completely intact.
	pass
