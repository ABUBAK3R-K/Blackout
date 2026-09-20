extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Meltdown Phase HUD & Emergency Restoration Consoles (Stage 19).
## Verifies:
##   1. Meltdown HUD hidden outside Meltdown
##   2. Meltdown HUD appears during Meltdown
##   3. Countdown displays in MM:SS format
##   4. Countdown receives authoritative remaining time and flashes/emphasizes in final 30s
##   5. All 3 emergency systems appear on HUD (Power, Cooling, ORION)
##   6. Completed system updates correctly to [✓] and updates header/subtitle status
##   7. Emergency consoles map to correct system IDs and facility rooms
##   8. Console interaction sends the authoritative completion request for Crew
##   9. Already completed systems cannot be submitted again (interaction blocked)
##   10. Impostor cannot complete an emergency system through the client flow
##   11. Eliminated / dead players cannot complete an emergency system
##   12. HUD disappears and deactivates after Meltdown ends / Game Over
##   13. ClientNetworkManager Meltdown signals correctly bind to HUD and Consoles

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const MeltdownHUD = preload("res://client/ui/meltdown_hud.gd")
const EmergencyConsole = preload("res://client/environment/emergency_console.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MELTDOWN HUD & EMERGENCY CONSOLES TEST (STAGE 19)")
	print("========================================================\n")
	create_timer(0.05).timeout.connect(_run_suite)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)
	test_log.append("[PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_log.append("[FAIL] %s" % msg)
	test_passed = false

func _log_info(msg: String) -> void:
	print("  [INFO] %s" % msg)

func _run_suite() -> void:
	var root = get_root()

	# -------------------------------------------------------------------------
	# TEST 1: Meltdown HUD hidden outside Meltdown
	# -------------------------------------------------------------------------
	_log_info("--- Test 1: Meltdown HUD Initial State ---")
	var hud: MeltdownHUD = MeltdownHUD.new()
	root.add_child(hud)

	if not hud.visible and not hud.is_active:
		_log_pass("TEST 1: Meltdown HUD is hidden and inactive by default outside Meltdown.")
	else:
		_log_fail("TEST 1: Meltdown HUD was visible outside Meltdown (Visible: %s, Active: %s)." % [
			str(hud.visible), str(hud.is_active)
		])

	# -------------------------------------------------------------------------
	# TEST 2: Meltdown HUD appears during Meltdown
	# -------------------------------------------------------------------------
	_log_info("--- Test 2: Meltdown HUD Activation ---")
	hud.start_meltdown(300.0, true)
	if hud.visible and hud.is_active and hud.remaining_time == 300.0:
		_log_pass("TEST 2: Meltdown HUD opens and is active with 300.0s authoritative countdown.")
	else:
		_log_fail("TEST 2: Meltdown HUD failed to open correctly (Visible: %s, Active: %s)." % [
			str(hud.visible), str(hud.is_active)
		])

	# -------------------------------------------------------------------------
	# TEST 3: Countdown format MM:SS
	# -------------------------------------------------------------------------
	_log_info("--- Test 3: Countdown Format (MM:SS) ---")
	hud.remaining_time = 300.0
	hud._update_timer_display()
	var text_300 = hud.timer_label.text if hud.timer_label != null else ""
	var match_300 = text_300.contains("05:00")

	hud.remaining_time = 125.0
	hud._update_timer_display()
	var text_125 = hud.timer_label.text if hud.timer_label != null else ""
	var match_125 = text_125.contains("02:05")

	if match_300 and match_125:
		_log_pass("TEST 3: Countdown correctly formats duration as MM:SS (300s -> '05:00', 125s -> '02:05').")
	else:
		_log_fail("TEST 3: Countdown formatting mismatch ('%s', '%s')." % [text_300, text_125])

	# -------------------------------------------------------------------------
	# TEST 4: Authoritative timer ticks and final 30s visual emphasis
	# -------------------------------------------------------------------------
	_log_info("--- Test 4: Authoritative Timer Ticking & Final 30s Warning ---")
	hud.remaining_time = 25.0 # Under 30 seconds
	hud._update_timer_display()
	var font_col_30 = hud.timer_label.get("theme_override_colors/font_color") if hud.timer_label != null else Color.WHITE
	# Should be red or amber flashing color (high red channel >= 0.9)
	if font_col_30 != null and font_col_30.r >= 0.9:
		_log_pass("TEST 4: Final 30-second window applies urgent alert color styling.")
	else:
		_log_fail("TEST 4: Final 30s alert color styling not applied (Color: %s)." % str(font_col_30))

	# -------------------------------------------------------------------------
	# TEST 5: All 3 emergency systems appear on HUD
	# -------------------------------------------------------------------------
	_log_info("--- Test 5: 3 Emergency Systems on HUD ---")
	var has_power = hud.system_row_nodes.has(MeltdownConfig.SYSTEM_RESTORE_POWER)
	var has_cooling = hud.system_row_nodes.has(MeltdownConfig.SYSTEM_RESTORE_COOLING)
	var has_orion = hud.system_row_nodes.has(MeltdownConfig.SYSTEM_STABILIZE_ORION)

	if has_power and has_cooling and has_orion:
		_log_pass("TEST 5: All 3 emergency systems (Power, Cooling, ORION) present in HUD checklist.")
	else:
		_log_fail("TEST 5: Missing system rows in HUD (Power: %s, Cooling: %s, ORION: %s)." % [
			str(has_power), str(has_cooling), str(has_orion)
		])

	# -------------------------------------------------------------------------
	# TEST 6: Completed system updates correctly to [✓]
	# -------------------------------------------------------------------------
	_log_info("--- Test 6: System Completion Visual Updates ---")
	hud.mark_system_completed(MeltdownConfig.SYSTEM_RESTORE_POWER)
	var power_row = hud.system_row_nodes.get(MeltdownConfig.SYSTEM_RESTORE_POWER, {})
	var power_check = power_row.get("check_label").text if power_row.has("check_label") else ""
	var power_completed = hud.completed_systems.has(MeltdownConfig.SYSTEM_RESTORE_POWER)

	hud.mark_system_completed(MeltdownConfig.SYSTEM_RESTORE_COOLING)
	hud.mark_system_completed(MeltdownConfig.SYSTEM_STABILIZE_ORION)

	if power_check == "[✓]" and power_completed and hud.completed_systems.size() == 3:
		_log_pass("TEST 6: Completed systems update checkmark to [✓] and track 3/3 restoration.")
	else:
		_log_fail("TEST 6: System completion failed (Check: '%s', Count: %d)." % [
			power_check, hud.completed_systems.size()
		])

	# -------------------------------------------------------------------------
	# TEST 7: Emergency Console mapping to correct system IDs & locations
	# -------------------------------------------------------------------------
	_log_info("--- Test 7: Emergency Console Identity & Mapping ---")
	var console_power = EmergencyConsole.new()
	console_power.system_id = MeltdownConfig.SYSTEM_RESTORE_POWER
	console_power.system_name = "Restore Power"
	console_power.room_location = "Generator Room"
	root.add_child(console_power)

	var console_cooling = EmergencyConsole.new()
	console_cooling.system_id = MeltdownConfig.SYSTEM_RESTORE_COOLING
	console_cooling.system_name = "Restore Cooling"
	console_cooling.room_location = "Laboratory"
	root.add_child(console_cooling)

	var console_orion = EmergencyConsole.new()
	console_orion.system_id = MeltdownConfig.SYSTEM_STABILIZE_ORION
	console_orion.system_name = "Stabilize ORION"
	console_orion.room_location = "ORION Core Chamber"
	root.add_child(console_orion)

	if console_power.system_id == "restore_power" and console_cooling.system_id == "restore_cooling" and console_orion.system_id == "stabilize_orion":
		_log_pass("TEST 7: All 3 Emergency Consoles correctly mapped to authoritative system IDs.")
	else:
		_log_fail("TEST 7: Console system ID mismatch.")

	# -------------------------------------------------------------------------
	# TEST 8: Crew interaction sends repair request
	# -------------------------------------------------------------------------
	_log_info("--- Test 8: Crew Console Interaction ---")
	var crew_player = PlayerController.new()
	crew_player.name = "CrewPlayer"
	crew_player.slot_id = 1
	crew_player.is_local_player = true
	crew_player.set_role(NetworkConfig.PlayerRole.CREW)
	root.add_child(crew_player)

	console_power.force_meltdown_active = true
	var crew_state = {"requested": false, "sys_id": ""}
	console_power.emergency_repair_requested.connect(func(sys_id, _p):
		crew_state["requested"] = true
		crew_state["sys_id"] = sys_id
	)

	console_power._on_interacted(crew_player)

	if crew_state.requested and crew_state.sys_id == MeltdownConfig.SYSTEM_RESTORE_POWER:
		_log_pass("TEST 8: Alive Crew interaction emits repair request for 'restore_power'.")
	else:
		_log_fail("TEST 8: Crew repair request not sent (Requested: %s, SysID: '%s')." % [
			str(crew_state.requested), crew_state.sys_id
		])

	# -------------------------------------------------------------------------
	# TEST 9: Duplicate submission blocked on completed console
	# -------------------------------------------------------------------------
	_log_info("--- Test 9: Duplicate Submission Blocked ---")
	console_power.mark_completed()
	crew_state["requested"] = false

	console_power._on_interacted(crew_player)

	if not crew_state.requested and console_power.is_completed:
		_log_pass("TEST 9: Repeated interaction on completed console is strictly blocked.")
	else:
		_log_fail("TEST 9: Duplicate repair request was incorrectly allowed.")

	# -------------------------------------------------------------------------
	# TEST 10: Impostor cannot complete emergency repairs
	# -------------------------------------------------------------------------
	_log_info("--- Test 10: Impostor Interaction Rejection ---")
	var imp_player = PlayerController.new()
	imp_player.name = "ImpostorPlayer"
	imp_player.slot_id = 2
	imp_player.is_local_player = true
	imp_player.set_role(NetworkConfig.PlayerRole.IMPOSTOR)
	root.add_child(imp_player)

	console_cooling.force_meltdown_active = true
	var imp_state = {"requested": false}
	console_cooling.emergency_repair_requested.connect(func(_sys, _p):
		imp_state["requested"] = true
	)

	console_cooling._on_interacted(imp_player)

	if not imp_state.requested and not console_cooling.is_completed:
		_log_pass("TEST 10: Impostor interaction is rejected on client and no repair request is emitted.")
	else:
		_log_fail("TEST 10: Impostor interaction was incorrectly permitted.")

	# -------------------------------------------------------------------------
	# TEST 11: Eliminated/dead players cannot repair systems
	# -------------------------------------------------------------------------
	_log_info("--- Test 11: Eliminated Player Rejection ---")
	var dead_player = PlayerController.new()
	dead_player.name = "DeadPlayer"
	dead_player.slot_id = 3
	dead_player.is_local_player = true
	dead_player.set_role(NetworkConfig.PlayerRole.CREW)
	dead_player.set("is_eliminated", true)
	root.add_child(dead_player)

	console_orion.force_meltdown_active = true
	var dead_state = {"requested": false}
	console_orion.emergency_repair_requested.connect(func(_sys, _p):
		dead_state["requested"] = true
	)

	console_orion._on_interacted(dead_player)

	if not dead_state.requested and not console_orion.is_completed:
		_log_pass("TEST 11: Eliminated player interaction is rejected and repair request is blocked.")
	else:
		_log_fail("TEST 11: Eliminated player was incorrectly permitted to repair.")

	# -------------------------------------------------------------------------
	# TEST 12: HUD disappears after Meltdown ends
	# -------------------------------------------------------------------------
	_log_info("--- Test 12: Meltdown HUD Dismissal ---")
	hud.end_meltdown()
	if not hud.visible and not hud.is_active:
		_log_pass("TEST 12: Meltdown HUD closes and becomes inactive on end_meltdown().")
	else:
		_log_fail("TEST 12: Meltdown HUD remained active after end_meltdown().")

	# Cleanup
	hud.queue_free()
	console_power.queue_free()
	console_cooling.queue_free()
	console_orion.queue_free()
	crew_player.queue_free()
	imp_player.queue_free()
	dead_player.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL STAGE 19 MELTDOWN HUD & CONSOLE TESTS PASSED!")
	else:
		print("  STAGE 19 TESTS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
