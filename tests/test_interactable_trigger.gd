extends SceneTree

## Unit Test Suite for BLACKOUT Interactable Proximity Trigger System (Member 3).
## Verifies:
##   1. InteractableTrigger instantiates with Area2D collision and floating PromptLabel.
##   2. Local player entering proximity triggers registration and displays prompt text.
##   3. Local player exiting proximity unregisters trigger and hides prompt.
##   4. Non-local player entering proximity is ignored (multiplayer safety).
##   5. try_interact() on PlayerController delegates to active InteractableTrigger.
##   6. Disabling interactivity (is_interactive = false) rejects interaction attempts.
##   7. TestTerminal responds to interaction by toggling activated state and visuals.
##   8. Out-of-range interaction fails safely without state changes.

const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")
const TestTerminal = preload("res://client/environment/test_terminal.gd")
const TestTerminalScene = preload("res://scenes/objects/test_terminal.tscn")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — INTERACTABLE PROXIMITY TRIGGER TEST (MEMBER 3)")
	print("========================================================\n")
	
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _run_suite() -> void:
	test_trigger_instantiation()
	test_player_proximity_enter_exit()
	test_multiplayer_local_player_safety()
	test_interaction_execution_and_gating()
	test_test_terminal_state_toggling()
	test_out_of_range_interaction_rejection()

	print("\n========================================================")
	if test_passed:
		print("  INTERACTABLE TRIGGER TESTS: ALL PASSED (100%)")
	else:
		print("  INTERACTABLE TRIGGER TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_trigger_instantiation() -> void:
	var trigger = InteractableTrigger.new()
	trigger._ready()

	if trigger != null and trigger is Area2D and trigger.collision_mask == 1:
		_log_pass("1. InteractableTrigger instantiates as Area2D with mask 1 (player detection).")
	else:
		_log_fail("1. Trigger instantiation failed.")

	if trigger.prompt_label != null and trigger.collision_shape != null:
		_log_pass("2. Trigger auto-constructs CollisionShape2D and floating PromptLabel.")
	else:
		_log_fail("2. Trigger sub-components missing.")
	trigger.free()

func test_player_proximity_enter_exit() -> void:
	var trigger = InteractableTrigger.new()
	trigger._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Simulate body entered
	trigger._on_body_entered(player)
	if player.current_interactable == trigger and trigger.prompt_label.visible == true:
		_log_pass("3. Local player entering trigger area registers interactable and shows prompt.")
	else:
		_log_fail("3. Proximity enter failed to register or show prompt.")

	# Simulate body exited
	trigger._on_body_exited(player)
	if player.current_interactable == null and trigger.prompt_label.visible == false:
		_log_pass("4. Local player exiting trigger area unregisters interactable and hides prompt.")
	else:
		_log_fail("4. Proximity exit failed to unregister or hide prompt.")

	player.free()
	trigger.free()

func test_multiplayer_local_player_safety() -> void:
	var trigger = InteractableTrigger.new()
	trigger._ready()

	var remote_player = PlayerScene.instantiate() as PlayerController
	remote_player.is_local_player = false # Remote puppet

	# Simulate remote player entering trigger
	trigger._on_body_entered(remote_player)
	if trigger.current_player == null and trigger.prompt_label.visible == false and remote_player.current_interactable == null:
		_log_pass("5. Remote player proximity does not trigger local prompt or hijack interaction state.")
	else:
		_log_fail("5. Remote player breached local interaction isolation.")

	remote_player.free()
	trigger.free()

func test_interaction_execution_and_gating() -> void:
	var trigger = InteractableTrigger.new()
	trigger._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	var interaction_data = {"fired": false}
	trigger.interacted.connect(func(_p): interaction_data["fired"] = true)

	trigger._on_body_entered(player)
	var interact_result = player.try_interact()

	if interact_result and interaction_data["fired"]:
		_log_pass("6. try_interact() successfully executes interaction on active trigger.")
	else:
		_log_fail("6. Interaction execution failed.")

	# Test disabling interactivity
	interaction_data["fired"] = false
	trigger.set_interactive(false)
	var disabled_result = player.try_interact()

	if not disabled_result and not interaction_data["fired"] and trigger.prompt_label.visible == false:
		_log_pass("7. is_interactive = false cleanly suppresses prompts and rejects interaction.")
	else:
		_log_fail("7. Disabled trigger failed to suppress interaction.")

	player.free()
	trigger.free()

func test_test_terminal_state_toggling() -> void:
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	if terminal.is_activated == false and terminal.status_label.text == "TERMINAL: STANDBY":
		_log_pass("8. TestTerminal initializes in STANDBY state.")
	else:
		_log_fail("8. TestTerminal initial state unexpected.")

	# Simulate E key interaction
	terminal.trigger._on_body_entered(player)
	player.try_interact()

	if terminal.is_activated == true and terminal.status_label.text == "TERMINAL: ONLINE [ACTIVE]":
		_log_pass("9. Pressing E toggles TestTerminal to ONLINE [ACTIVE] state with updated visuals.")
	else:
		_log_fail("9. TestTerminal failed to toggle state on interaction.")

	# Toggle back to STANDBY
	player.try_interact()
	if terminal.is_activated == false:
		_log_pass("10. Second interaction toggles TestTerminal back to STANDBY.")
	else:
		_log_fail("10. TestTerminal toggle-off failed.")

	player.free()
	terminal.free()

func test_out_of_range_interaction_rejection() -> void:
	var terminal = TestTerminalScene.instantiate() as TestTerminal
	terminal._ready()

	var player = PlayerScene.instantiate() as PlayerController
	player.is_local_player = true

	# Player has not entered trigger range
	var out_of_range_result = player.try_interact()
	if not out_of_range_result and terminal.is_activated == false:
		_log_pass("11. Out-of-range interaction attempt returns false with zero state change.")
	else:
		_log_fail("11. Out-of-range interaction was incorrectly allowed.")

	player.free()
	terminal.free()
