class_name MiniGameFactory
extends RefCounted

## Centralized factory resolving task identifiers, recovery systems,
## sabotage objectives, and meltdown systems into their dedicated mini-game instances (Member 4).

# Base class
const MiniGameBase = preload("res://client/interactions/interaction_framework/mini_game_base.gd")

# Phase 1 Crew & Impostor Prerequisite Mini-Games
const MGRepairPower = preload("res://client/interactions/mini_games/crew/mg_repair_power.gd")
const MGStabilizeOrion = preload("res://client/interactions/mini_games/crew/mg_stabilize_orion.gd")
const MGServerCalibration = preload("res://client/interactions/mini_games/crew/mg_server_calibration.gd")
const MGSecurityRepair = preload("res://client/interactions/mini_games/crew/mg_security_repair.gd")
const MGMedicalSupplyCheck = preload("res://client/interactions/mini_games/crew/mg_medical_supply_check.gd")
const MGDataTransfer = preload("res://client/interactions/mini_games/crew/mg_data_transfer.gd")
const MGDoorRepair = preload("res://client/interactions/mini_games/crew/mg_door_repair.gd")
const MGCoolantSystem = preload("res://client/interactions/mini_games/crew/mg_coolant_system.gd")
const MGLaboratoryOrg = preload("res://client/interactions/mini_games/crew/mg_laboratory_org.gd")
const MGBackupPower = preload("res://client/interactions/mini_games/crew/mg_backup_power.gd")

# Phase 2 Blackout Recovery Mini-Games
const MGRecoveryGenerator = preload("res://client/interactions/mini_games/recovery/mg_recovery_generator.gd")
const MGRecoveryPowerRouting = preload("res://client/interactions/mini_games/recovery/mg_recovery_power_routing.gd")
const MGRecoverySecurityRelay = preload("res://client/interactions/mini_games/recovery/mg_recovery_security_relay.gd")
const MGRecoveryCooling = preload("res://client/interactions/mini_games/recovery/mg_recovery_cooling.gd")

# Phase 2 Impostor Sabotage Interactions
const MGStealConfidentialFiles = preload("res://client/interactions/sabotage_interactions/mg_steal_confidential_files.gd")
const MGExtractOrionCoreData = preload("res://client/interactions/sabotage_interactions/mg_extract_orion_core_data.gd")
const MGDisableOrionContainment = preload("res://client/interactions/sabotage_interactions/mg_disable_orion_containment.gd")
const MGSabotageGenerator = preload("res://client/interactions/sabotage_interactions/mg_sabotage_generator.gd")
const MGTamperSecurity = preload("res://client/interactions/sabotage_interactions/mg_tamper_security.gd")

# Phase 4 Meltdown Emergency Mini-Games
const MGMeltdownRestorePower = preload("res://client/interactions/mini_games/meltdown/mg_meltdown_restore_power.gd")
const MGMeltdownRestoreCooling = preload("res://client/interactions/mini_games/meltdown/mg_meltdown_restore_cooling.gd")
const MGMeltdownStabilizeOrion = preload("res://client/interactions/mini_games/meltdown/mg_meltdown_stabilize_orion.gd")

## Instantiates a Phase 1 Crew task or Impostor prerequisite mini-game
static func create_task_mini_game(task_type_id: String) -> MiniGameBase:
	match task_type_id:
		"repair_power":
			return MGRepairPower.new()
		"stabilize_orion":
			return MGStabilizeOrion.new()
		"server_calibration":
			return MGServerCalibration.new()
		"security_repair":
			return MGSecurityRepair.new()
		"medical_supply_check":
			return MGMedicalSupplyCheck.new()
		"data_transfer":
			return MGDataTransfer.new()
		"door_repair":
			return MGDoorRepair.new()
		"coolant_system":
			return MGCoolantSystem.new()
		"laboratory_org":
			return MGLaboratoryOrg.new()
		"backup_power":
			return MGBackupPower.new()
		_:
			push_warning("[MiniGameFactory] Unknown task type: '%s'. Falling back to repair_power." % task_type_id)
			return MGRepairPower.new()

## Instantiates a Phase 2 Blackout recovery mini-game
static func create_recovery_mini_game(system_id: String) -> MiniGameBase:
	match system_id:
		"generator":
			return MGRecoveryGenerator.new()
		"power_routing":
			return MGRecoveryPowerRouting.new()
		"security_relay":
			return MGRecoverySecurityRelay.new()
		"cooling":
			return MGRecoveryCooling.new()
		_:
			push_warning("[MiniGameFactory] Unknown recovery system: '%s'." % system_id)
			return null

## Instantiates a Phase 2 Impostor sabotage objective mini-game
static func create_sabotage_mini_game(objective_id: String) -> MiniGameBase:
	match objective_id:
		"steal_confidential_files":
			return MGStealConfidentialFiles.new()
		"extract_orion_core_data":
			return MGExtractOrionCoreData.new()
		"disable_orion_containment":
			return MGDisableOrionContainment.new()
		"sabotage_generator":
			return MGSabotageGenerator.new()
		"tamper_security":
			return MGTamperSecurity.new()
		_:
			push_warning("[MiniGameFactory] Unknown sabotage objective: '%s'." % objective_id)
			return null

## Instantiates a Phase 4 Meltdown emergency mini-game
static func create_meltdown_mini_game(emergency_system_id: String) -> MiniGameBase:
	match emergency_system_id:
		"restore_power":
			return MGMeltdownRestorePower.new()
		"restore_cooling":
			return MGMeltdownRestoreCooling.new()
		"stabilize_orion":
			return MGMeltdownStabilizeOrion.new()
		_:
			push_warning("[MiniGameFactory] Unknown meltdown emergency system: '%s'." % emergency_system_id)
			return null
