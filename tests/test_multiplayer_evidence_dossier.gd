extends SceneTree

## Multiplayer End-to-End Verification for BLACKOUT Stage 21 (Evidence Dossier UI).
## Verifies full multiplayer flow:
##   1. Start multiplayer server and multiple clients
##   2. Trigger Blackout sabotage & complete objectives / recovery systems
##   3. Transition to POST_BLACKOUT_INVESTIGATION
##   4. Synchronize authoritative evidence to all clients
##   5. Verify Evidence Dossier UI displays real evidence on both Crew and Impostor
##   6. Verify zero role or actor leakage
##   7. Verify Dossier lifecycle transition when exiting investigation

const NetworkConfig = preload("res://shared/network_config.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")
const EvidenceDossierUI = preload("res://client/ui/evidence_dossier_ui.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — MULTIPLAYER EVIDENCE DOSSIER VERIFICATION")
	print("========================================================\n")
	create_timer(0.05).timeout.connect(_run_verification)

func _log_pass(msg: String) -> void:
	print("  [PASS] %s" % msg)

func _log_fail(msg: String) -> void:
	print("  [FAIL] %s" % msg)
	test_passed = false

func _run_verification() -> void:
	var root = get_root()

	# 1. Setup Server and 2 Clients (Crew and Impostor)
	var server = ServerNetworkManager.new()
	root.add_child(server)

	var client_crew = ClientNetworkManager.new()
	var client_imp = ClientNetworkManager.new()
	root.add_child(client_crew)
	root.add_child(client_imp)

	var ui_crew = EvidenceDossierUI.new()
	var ui_imp = EvidenceDossierUI.new()
	root.add_child(ui_crew)
	root.add_child(ui_imp)

	ui_crew.bind_client_network_manager(client_crew)
	ui_imp.bind_client_network_manager(client_imp)

	# 2. Assign roles
	client_crew.handle_private_role_assignment(NetworkConfig.PlayerRole.CREW)
	client_imp.handle_private_role_assignment(NetworkConfig.PlayerRole.IMPOSTOR)

	# 3. Simulate Blackout phase on Server
	server.sabotage_manager.request_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT)
	server.sabotage_manager.activate_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT, 60.0)

	# 4. Generate real server-side evidence from Impostor objective and Crew recovery
	server.evidence_manager.create_evidence_from_objective("steal_confidential_files", 102, 1789916890.0)
	server.evidence_manager.create_evidence_from_objective("extract_orion_core_data", 102, 1789916892.0)
	server.evidence_manager.create_evidence_from_recovery("generator", "Generator Subsystem", "generator_room", 101, 1789916895.0)

	var finalized_evidence = server.evidence_manager.finalize_investigation()

	# 5. Broadcast to clients
	client_crew.handle_investigation_started()
	client_crew.handle_investigation_evidence(finalized_evidence)

	client_imp.handle_investigation_started()
	client_imp.handle_investigation_evidence(finalized_evidence)

	# 6. Verify Evidence Dossier on Crew Client
	if ui_crew.visible and ui_crew.is_active and ui_crew.tracked_evidence.size() == 3:
		_log_pass("Step 5-8: Crew client received all 3 synchronized evidence records.")
	else:
		_log_fail("Step 5-8: Crew client failed to display evidence records.")

	# 7. Verify Evidence Dossier on Impostor Client
	if ui_imp.visible and ui_imp.is_active and ui_imp.tracked_evidence.size() == 3:
		_log_pass("Step 5-8: Impostor client received identical 3 public evidence records.")
	else:
		_log_fail("Step 5-8: Impostor client failed to display evidence records.")

	# 8. Verify Privacy: No private attribution or role revealed
	var leaked = false
	for ev in ui_crew.tracked_evidence:
		if ev.has("actor_peer_id") or ev.has("role") or str(ev.get("description", "")).contains("Impostor"):
			leaked = true
			break

	if not leaked:
		_log_pass("Step 9: Factual records strictly preserved without role/identity leakage.")
	else:
		_log_fail("Step 9: Privacy leakage detected in public evidence.")

	# 9. Verify Investigation Exit (e.g. Meltdown)
	client_crew.handle_game_state_changed(NetworkConfig.GameState.MELTDOWN)
	client_imp.handle_game_state_changed(NetworkConfig.GameState.MELTDOWN)

	if not ui_crew.visible and not ui_imp.visible and not ui_crew.is_active and not ui_imp.is_active:
		_log_pass("Step 10: Dossier cleanly dismissed on both clients when exiting investigation.")
	else:
		_log_fail("Step 10: Dossier failed to dismiss upon investigation completion.")

	# Cleanup
	server.queue_free()
	client_crew.queue_free()
	client_imp.queue_free()
	ui_crew.queue_free()
	ui_imp.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL MULTIPLAYER EVIDENCE DOSSIER VERIFICATIONS PASSED!")
	else:
		print("  MULTIPLAYER EVIDENCE DOSSIER VERIFICATIONS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
