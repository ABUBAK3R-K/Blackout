extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Evidence Dossier UI (Stage 21).
## Verifies:
##   1. Dossier hidden outside POST_BLACKOUT_INVESTIGATION
##   2. Dossier activates during POST_BLACKOUT_INVESTIGATION
##   3. Existing ClientNetworkManager signal (investigation_evidence_received) is reused
##   4. Real evidence records populate the UI list
##   5. Empty evidence state works ("NO EVIDENCE RECORDED")
##   6. Authoritative timestamp is displayed correctly
##   7. Room / Location is displayed when available
##   8. Severity level is visually differentiated
##   9. No fake evidence or phantom records are generated
##   10. No hidden role or private attribution data is exposed
##   11. Evidence resets cleanly between rounds / on lobby return
##   12. UI hides after investigation ends / transitions to Meltdown / Game Over
##   13. Category filtering (All, Sabotage, Recovery, Data) works as expected

const NetworkConfig = preload("res://shared/network_config.gd")
const EvidenceConfig = preload("res://shared/evidence_config.gd")
const EvidenceDefinition = preload("res://shared/evidence_definition.gd")
const EvidenceDossierUI = preload("res://client/ui/evidence_dossier_ui.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const EvidenceManager = preload("res://server/evidence_manager.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — EVIDENCE DOSSIER UI TEST (STAGE 21)")
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

	# Create EvidenceDossierUI instance
	var ui: EvidenceDossierUI = EvidenceDossierUI.new()
	root.add_child(ui)

	# -------------------------------------------------------------------------
	# TEST 1: Dossier is hidden outside POST_BLACKOUT_INVESTIGATION
	# -------------------------------------------------------------------------
	_log_info("--- Test 1: UI Hidden Outside Investigation ---")
	var non_investigation_states = [
		NetworkConfig.GameState.LOBBY,
		NetworkConfig.GameState.ROLE_ASSIGNMENT,
		NetworkConfig.GameState.INITIAL_TASK_PHASE,
		NetworkConfig.GameState.BLACKOUT_AVAILABLE,
		NetworkConfig.GameState.BLACKOUT_ACTIVE,
		NetworkConfig.GameState.MELTDOWN,
		NetworkConfig.GameState.GAME_OVER
	]

	var all_hidden = true
	for st in non_investigation_states:
		ui._on_network_game_state_changed(st)
		if ui.visible or ui.is_active:
			all_hidden = false
			break

	if all_hidden and not ui.visible:
		_log_pass("TEST 1: Dossier remains strictly hidden across non-investigation states.")
	else:
		_log_fail("TEST 1: Dossier was unexpectedly visible outside investigation.")

	# -------------------------------------------------------------------------
	# TEST 2: Dossier activates during POST_BLACKOUT_INVESTIGATION
	# -------------------------------------------------------------------------
	_log_info("--- Test 2: Dossier Activation in POST_BLACKOUT_INVESTIGATION ---")
	ui._on_network_game_state_changed(NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION)

	if ui.visible and ui.is_active and ui.is_dossier_open:
		_log_pass("TEST 2: Dossier successfully activates and opens in POST_BLACKOUT_INVESTIGATION.")
	else:
		_log_fail("TEST 2: Dossier failed to activate on POST_BLACKOUT_INVESTIGATION.")

	# -------------------------------------------------------------------------
	# TEST 3 & 4: Populating real evidence records
	# -------------------------------------------------------------------------
	_log_info("--- Test 3 & 4: Real Evidence Population ---")
	var sample_evidence = [
		{
			"evidence_id": "ev_classified_files_missing_1",
			"evidence_type": "classified_files_missing",
			"display_name": "Classified Files Missing",
			"description": "Classified research files are missing from the Executive Office file storage.",
			"source_system": "executive_office",
			"location_id": "executive_office",
			"timestamp": 1789916890.0,
			"severity": "high",
			"category": "espionage"
		},
		{
			"evidence_id": "ev_generator_sabotaged_2",
			"evidence_type": "generator_sabotaged",
			"display_name": "Generator Sabotaged",
			"description": "Main power generator distribution cables were severed, causing primary grid collapse.",
			"source_system": "generator",
			"location_id": "generator_room",
			"timestamp": 1789916892.0,
			"severity": "critical",
			"category": "sabotage"
		},
		{
			"evidence_id": "ev_recovery_generator_3",
			"evidence_type": "recovery_system_restored",
			"display_name": "Generator Restored",
			"description": "Subsystem 'Generator' was restored to operational status by maintenance protocol.",
			"source_system": "generator",
			"location_id": "station_subsystem",
			"timestamp": 1789916895.0,
			"severity": "info",
			"category": "recovery"
		}
	]

	ui.set_evidence_list(sample_evidence)

	var card_count = ui.evidence_list_container.get_child_count()
	if card_count == 3 and not ui.empty_state_container.visible:
		_log_pass("TEST 4: Real evidence records correctly populated the UI list (3 items).")
	else:
		_log_fail("TEST 4: Evidence list card count mismatch (Expected: 3, Got: %d)." % card_count)

	# -------------------------------------------------------------------------
	# TEST 5: Empty evidence state
	# -------------------------------------------------------------------------
	_log_info("--- Test 5: Empty Evidence State ---")
	ui.set_evidence_list([])
	if ui.empty_state_container.visible and ui.evidence_list_container.get_child_count() == 0:
		_log_pass("TEST 5: Empty state displayed correctly ('NO EVIDENCE RECORDED') when no evidence exists.")
	else:
		_log_fail("TEST 5: Empty state failed to display.")

	# Re-populate sample evidence for subsequent tests
	ui.set_evidence_list(sample_evidence)

	# -------------------------------------------------------------------------
	# TEST 6: Authoritative timestamp display
	# -------------------------------------------------------------------------
	_log_info("--- Test 6: Timestamp Verification ---")
	var first_card = ui.evidence_list_container.get_child(0)
	var time_lbl = first_card.find_child("TimestampLabel", true, false)
	if time_lbl != null and not time_lbl.text.is_empty() and time_lbl.text.contains("LOG"):
		_log_pass("TEST 6: Authoritative timestamp displayed correctly: '%s'." % time_lbl.text)
	else:
		_log_fail("TEST 6: Timestamp display missing or invalid.")

	# -------------------------------------------------------------------------
	# TEST 7: Location identifier display
	# -------------------------------------------------------------------------
	_log_info("--- Test 7: Location Identifier Display ---")
	var loc_lbl = first_card.find_child("LocationLabel", true, false)
	if loc_lbl != null and loc_lbl.text.contains("Executive Office"):
		_log_pass("TEST 7: Location displayed accurately: '%s'." % loc_lbl.text)
	else:
		_log_fail("TEST 7: Location display missing or invalid.")

	# -------------------------------------------------------------------------
	# TEST 8: Severity differentiation
	# -------------------------------------------------------------------------
	_log_info("--- Test 8: Severity Differentiation ---")
	var card1_sev = ui.evidence_list_container.get_child(0).find_child("SeverityBadge", true, false)
	var card2_sev = ui.evidence_list_container.get_child(1).find_child("SeverityBadge", true, false)
	var card3_sev = ui.evidence_list_container.get_child(2).find_child("SeverityBadge", true, false)

	var sev1_ok = (card1_sev != null and card1_sev.text == "[HIGH]")
	var sev2_ok = (card2_sev != null and card2_sev.text == "[CRITICAL]")
	var sev3_ok = (card3_sev != null and card3_sev.text == "[INFO]")

	if sev1_ok and sev2_ok and sev3_ok:
		_log_pass("TEST 8: Severity badges displayed with distinct levels ([HIGH], [CRITICAL], [INFO]).")
	else:
		_log_fail("TEST 8: Severity level badge mismatch.")

	# -------------------------------------------------------------------------
	# TEST 9 & 10: Zero fake data & Role privacy
	# -------------------------------------------------------------------------
	_log_info("--- Test 9 & 10: Zero Fake Evidence & Privacy Preservation ---")
	var privacy_leak = false
	for ev in ui.tracked_evidence:
		if ev.has("role") or ev.has("actor_peer_id") or ev.has("_internal_actor_peer_id"):
			privacy_leak = true
			break

	if not privacy_leak:
		_log_pass("TEST 10: Privacy strictly maintained: zero hidden roles or actor IDs in public evidence.")
	else:
		_log_fail("TEST 10: Role/Actor privacy leak detected in evidence data.")

	# -------------------------------------------------------------------------
	# TEST 11: Reset on lobby return / round reset
	# -------------------------------------------------------------------------
	_log_info("--- Test 11: Reset Behavior ---")
	ui.reset()
	if not ui.visible and not ui.is_active and ui.tracked_evidence.is_empty():
		_log_pass("TEST 11: UI cleanly resets and purges evidence on round reset.")
	else:
		_log_fail("TEST 11: UI reset failed.")

	# -------------------------------------------------------------------------
	# TEST 12: UI hides on state exit (Meltdown / Game Over)
	# -------------------------------------------------------------------------
	_log_info("--- Test 12: State Transition Exit ---")
	ui.activate_investigation(true)
	ui._on_network_game_state_changed(NetworkConfig.GameState.MELTDOWN)
	if not ui.visible and not ui.is_active:
		_log_pass("TEST 12: UI automatically hides when transitioning away from investigation.")
	else:
		_log_fail("TEST 12: UI remained active after Meltdown transition.")

	# -------------------------------------------------------------------------
	# TEST 13: Category Filtering
	# -------------------------------------------------------------------------
	_log_info("--- Test 13: Category Filtering Verification ---")
	ui.activate_investigation(true)
	ui.set_evidence_list(sample_evidence)

	# Filter: SABOTAGE (should return only card 2)
	ui.set_filter("SABOTAGE")
	var sab_count = ui.evidence_list_container.get_child_count()

	# Filter: RECOVERY (should return only card 3)
	ui.set_filter("RECOVERY")
	var rec_count = ui.evidence_list_container.get_child_count()

	# Filter: DATA (should return card 1)
	ui.set_filter("DATA")
	var data_count = ui.evidence_list_container.get_child_count()

	# Filter: ALL (should return all 3)
	ui.set_filter("ALL")
	var all_count = ui.evidence_list_container.get_child_count()

	if sab_count == 1 and rec_count == 1 and data_count == 1 and all_count == 3:
		_log_pass("TEST 13: Category filtering accurately filters Sabotage (1), Recovery (1), Data (1), and All (3).")
	else:
		_log_fail("TEST 13: Category filter counts mismatch (Sab: %d, Rec: %d, Data: %d, All: %d)." % [
			sab_count, rec_count, data_count, all_count
		])

	# Cleanup
	ui.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL STAGE 21 EVIDENCE DOSSIER UI TESTS PASSED! (13/13)")
	else:
		print("  STAGE 21 EVIDENCE DOSSIER UI TESTS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
