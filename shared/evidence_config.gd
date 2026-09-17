class_name EvidenceConfig
extends RefCounted

## Centralized configuration and templates for the BLACKOUT Evidence & Investigation system.

## Evidence Type Keys
const TYPE_CLASSIFIED_FILES_MISSING: String = "classified_files_missing"
const TYPE_ORION_CORE_DATA_EXTRACTED: String = "orion_core_data_extracted"
const TYPE_ORION_CONTAINMENT_DISABLED: String = "orion_containment_disabled"
const TYPE_GENERATOR_SABOTAGED: String = "generator_sabotaged"
const TYPE_SECURITY_TAMPERED: String = "security_tampered"

const TYPE_UNAUTHORIZED_RESTRICTED_ACCESS: String = "unauthorized_restricted_access"
const TYPE_SYSTEM_DAMAGE_DETECTED: String = "system_damage_detected"
const TYPE_RECOVERY_SYSTEM_RESTORED: String = "recovery_system_restored"

## Objective-to-Evidence Template Mapping for Step 7 Impostor Objectives
const OBJECTIVE_EVIDENCE_TEMPLATES: Dictionary = {
	"steal_confidential_files": {
		"evidence_type": TYPE_CLASSIFIED_FILES_MISSING,
		"display_name": "Classified Files Missing",
		"description": "Classified research files are missing from the Executive Office file storage.",
		"source_system": "executive_office",
		"location_id": "executive_office",
		"severity": "high",
		"category": "espionage"
	},
	"extract_orion_core_data": {
		"evidence_type": TYPE_ORION_CORE_DATA_EXTRACTED,
		"display_name": "ORION Core Data Extracted",
		"description": "ORION core terminal logs indicate unauthorized research data was extracted.",
		"source_system": "orion",
		"location_id": "orion_core",
		"severity": "critical",
		"category": "data_theft"
	},
	"disable_orion_containment": {
		"evidence_type": TYPE_ORION_CONTAINMENT_DISABLED,
		"display_name": "ORION Containment Disabled",
		"description": "The ORION core containment field was manually overridden and deactivated.",
		"source_system": "orion",
		"location_id": "containment_hub",
		"severity": "critical",
		"category": "containment"
	},
	"sabotage_generator": {
		"evidence_type": TYPE_GENERATOR_SABOTAGED,
		"display_name": "Generator Sabotaged",
		"description": "Main power generator distribution cables were severed, causing primary grid collapse.",
		"source_system": "generator",
		"location_id": "generator_room",
		"severity": "critical",
		"category": "sabotage"
	},
	"tamper_security": {
		"evidence_type": TYPE_SECURITY_TAMPERED,
		"display_name": "Security Feed Tampered",
		"description": "Security surveillance console audit logs show scrambled camera feeds and altered history.",
		"source_system": "security",
		"location_id": "security_room",
		"severity": "high",
		"category": "security"
	}
}

## Subsystem Recovery Template
const RECOVERY_EVIDENCE_TEMPLATE: Dictionary = {
	"evidence_type": TYPE_RECOVERY_SYSTEM_RESTORED,
	"display_name": "Recovery Subsystem Restored",
	"description_template": "Subsystem '%s' was restored to operational status by maintenance protocol.",
	"severity": "info",
	"category": "recovery"
}
