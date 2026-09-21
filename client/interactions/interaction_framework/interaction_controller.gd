class_name InteractionController
extends Control

## Central client-side interaction orchestrator for BLACKOUT (Member 4).
##
## Manages modal lifecycle, input isolation, player movement locking hooks,
## cancellation/interruption signals, and dispatches validated completion
## payloads to ClientNetworkManager.

const MiniGameBase = preload("res://client/interactions/interaction_framework/mini_game_base.gd")
const MiniGameFactory = preload("res://client/interactions/mini_game_factory.gd")
const NetworkConfig = preload("res://shared/network_config.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

enum InteractionCategory {
	NONE,
	CREW_TASK,
	IMPOSTOR_PREREQUISITE,
	BLACKOUT_RECOVERY,
	IMPOSTOR_SABOTAGE,
	MELTDOWN_EMERGENCY
}

signal interaction_opened(category: InteractionCategory, id: String)
signal interaction_closed(category: InteractionCategory, id: String, was_completed: bool)
signal player_lock_requested(should_lock: bool)

@export var client_network_manager: ClientNetworkManager = null

var current_category: InteractionCategory = InteractionCategory.NONE
var current_target_id: String = ""
var current_task_id: String = "" # Specific instance ID for crew tasks
var current_mini_game: MiniGameBase = null
var modal_container: Control = self

func _init() -> void:
	modal_container = self

func _ready() -> void:
	if modal_container == null:
		modal_container = self
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bind_network_manager()

func set_network_manager(p_mgr: ClientNetworkManager) -> void:
	client_network_manager = p_mgr
	_bind_network_manager()

func _bind_network_manager() -> void:
	if client_network_manager == null:
		return

	# Automatically interrupt ongoing interactions if game state drastically changes
	if not client_network_manager.blackout_started.is_connected(_on_blackout_started):
		client_network_manager.blackout_started.connect(_on_blackout_started)

	if not client_network_manager.meeting_started.is_connected(_on_meeting_started):
		client_network_manager.meeting_started.connect(_on_meeting_started)

	if not client_network_manager.game_over_received.is_connected(_on_game_over):
		client_network_manager.game_over_received.connect(_on_game_over)

## ---------------------------------------------------------
## Interaction Starters
## ---------------------------------------------------------

## Starts a Phase 1 Crew task or Impostor prerequisite task
func open_task_interaction(p_task_id: String, task_type_id: String) -> bool:
	if is_interacting():
		push_warning("[InteractionController] Already in interaction: %s" % current_target_id)
		return false

	var mini_game: MiniGameBase = MiniGameFactory.create_task_mini_game(task_type_id)
	if mini_game == null:
		push_error("[InteractionController] Failed to create mini-game for task type: %s" % task_type_id)
		return false

	current_category = InteractionCategory.CREW_TASK
	current_task_id = p_task_id
	current_target_id = task_type_id
	return _mount_and_start(mini_game, p_task_id)

## Starts a Phase 2 Blackout recovery mini-game
func open_recovery_interaction(system_id: String) -> bool:
	if is_interacting():
		push_warning("[InteractionController] Already in interaction: %s" % current_target_id)
		return false

	var mini_game: MiniGameBase = MiniGameFactory.create_recovery_mini_game(system_id)
	if mini_game == null:
		push_error("[InteractionController] Failed to create recovery mini-game for system: %s" % system_id)
		return false

	current_category = InteractionCategory.BLACKOUT_RECOVERY
	current_task_id = ""
	current_target_id = system_id
	return _mount_and_start(mini_game, system_id)

## Starts a Phase 2 Impostor sabotage objective mini-game
func open_sabotage_interaction(objective_id: String) -> bool:
	if is_interacting():
		push_warning("[InteractionController] Already in interaction: %s" % current_target_id)
		return false

	var mini_game: MiniGameBase = MiniGameFactory.create_sabotage_mini_game(objective_id)
	if mini_game == null:
		push_error("[InteractionController] Failed to create sabotage mini-game for objective: %s" % objective_id)
		return false

	current_category = InteractionCategory.IMPOSTOR_SABOTAGE
	current_task_id = ""
	current_target_id = objective_id
	return _mount_and_start(mini_game, objective_id)

## Starts a Phase 4 Meltdown emergency stabilization mini-game
func open_meltdown_interaction(emergency_system_id: String) -> bool:
	if is_interacting():
		push_warning("[InteractionController] Already in interaction: %s" % current_target_id)
		return false

	var mini_game: MiniGameBase = MiniGameFactory.create_meltdown_mini_game(emergency_system_id)
	if mini_game == null:
		push_error("[InteractionController] Failed to create meltdown mini-game for system: %s" % emergency_system_id)
		return false

	current_category = InteractionCategory.MELTDOWN_EMERGENCY
	current_task_id = ""
	current_target_id = emergency_system_id
	return _mount_and_start(mini_game, emergency_system_id)

## ---------------------------------------------------------
## Internal Mounting & Lifecycle Hooks
## ---------------------------------------------------------

func _mount_and_start(mini_game: MiniGameBase, interaction_id: String) -> bool:
	current_mini_game = mini_game
	modal_container.add_child(mini_game)

	# Position to fill container
	mini_game.set_anchors_preset(Control.PRESET_FULL_RECT)

	# Connect completion and exit signals
	mini_game.interaction_completed.connect(_on_mini_game_completed)
	mini_game.interaction_cancelled.connect(_on_mini_game_cancelled)
	mini_game.interaction_interrupted.connect(_on_mini_game_interrupted)
	mini_game.interaction_failed.connect(_on_mini_game_failed)

	# Lock player movement input
	player_lock_requested.emit(true)

	interaction_opened.emit(current_category, interaction_id)
	return mini_game.start_interaction(interaction_id)

func _on_mini_game_completed() -> void:
	_dispatch_network_completion()
	_close_current_interaction(true)

func _on_mini_game_cancelled() -> void:
	_close_current_interaction(false)

func _on_mini_game_interrupted() -> void:
	_close_current_interaction(false)

func _on_mini_game_failed() -> void:
	_close_current_interaction(false)

func _dispatch_network_completion() -> void:
	if client_network_manager == null:
		print("[InteractionController] Completion simulated locally (NetworkManager not attached).")
		return

	match current_category:
		InteractionCategory.CREW_TASK:
			var id_to_send = current_task_id if not current_task_id.is_empty() else current_target_id
			client_network_manager.request_complete_task(id_to_send)
		InteractionCategory.BLACKOUT_RECOVERY:
			client_network_manager.request_recover_system(current_target_id)
		InteractionCategory.IMPOSTOR_SABOTAGE:
			client_network_manager.request_complete_impostor_objective(current_target_id)
		InteractionCategory.MELTDOWN_EMERGENCY:
			client_network_manager.request_complete_emergency_system(current_target_id)

func _close_current_interaction(was_completed: bool) -> void:
	var category = current_category
	var id = current_target_id

	if current_mini_game != null:
		if is_instance_valid(current_mini_game):
			current_mini_game.queue_free()
		current_mini_game = null

	current_category = InteractionCategory.NONE
	current_target_id = ""
	current_task_id = ""

	# Unlock player movement input
	player_lock_requested.emit(false)

	interaction_closed.emit(category, id, was_completed)

## ---------------------------------------------------------
## Interruption & Cancellation API
## ---------------------------------------------------------

func cancel_interaction(reason: String = "cancelled") -> void:
	if current_mini_game != null and current_mini_game.is_active():
		current_mini_game.cancel_interaction(reason)

func interrupt_interaction(reason: String = "interrupted") -> void:
	if current_mini_game != null and current_mini_game.is_active():
		current_mini_game.interrupt_interaction(reason)

func is_interacting() -> bool:
	return current_mini_game != null and current_mini_game.is_active()

## Triggered when player steps out of interactable range
func on_player_exited_trigger(trigger_id: String) -> void:
	if is_interacting() and (current_target_id == trigger_id or current_task_id == trigger_id):
		interrupt_interaction("player_moved_away")

## ---------------------------------------------------------
## Network Manager Event Handlers
## ---------------------------------------------------------

func _on_blackout_started(_duration: float) -> void:
	# If player was in normal Phase 1 task when blackout cuts power, interrupt it
	if is_interacting() and current_category == InteractionCategory.CREW_TASK:
		interrupt_interaction("blackout_power_loss")

func _on_meeting_started(_caller_id: int, _duration: float) -> void:
	# All interactions must be immediately interrupted when an emergency meeting begins
	if is_interacting():
		interrupt_interaction("emergency_meeting_called")

func _on_game_over(_winner: int, _reason: int, _data: Dictionary) -> void:
	if is_interacting():
		interrupt_interaction("game_over")
