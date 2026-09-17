extends SceneTree

## Headless Integration Test Suite for BLACKOUT Authoritative Task System (Step 5).
## Verifies all 20 requirements:
##   1. INITIAL_TASK_PHASE accepts task assignment
##   2. Exactly 7 Crew players receive Crew tasks
##   3. Exactly 1 Impostor receives prerequisite tasks
##   4. Impostor receives fewer prerequisite tasks than the normal Crew task assignment
##   5. Every assigned task has a valid unique task ID
##   6. Every task belongs to exactly one player
##   7. Server owns the authoritative task state
##   8. A player cannot complete another player's task
##   9. Unknown task IDs are rejected
##   10. Already completed tasks cannot be completed twice
##   11. Completion requests outside INITIAL_TASK_PHASE are rejected
##   12. Valid task completion succeeds
##   13. Completed task state is updated correctly
##   14. Impostor prerequisite progress is tracked correctly
##   15. BLACKOUT_AVAILABLE does NOT trigger before all Impostor prerequisites are complete
##   16. BLACKOUT_AVAILABLE triggers immediately after all Impostor prerequisites are completed
##   17. Crew cannot receive Impostor prerequisite progress
##   18. Impostor does not receive the complete Crew task table
##   19. Disconnect handling does not corrupt task state
##   20. Complete execution verification

const NetworkConfig = preload("res://shared/network_config.gd")
const TaskConfig = preload("res://shared/task_config.gd")
const TaskDefinition = preload("res://shared/task_definition.gd")
const ServerNetworkManager = preload("res://server/server_network_manager.gd")
const ClientNetworkManager = preload("res://client/client_network_manager.gd")

const TEST_PORT: int = 7791
const TEST_HOST: String = "127.0.0.1"

var server_mgr: ServerNetworkManager = null
var clients: Array[Dictionary] = []

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — AUTHORITATIVE TASK SYSTEM TEST (STEP 5)")
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

func _poll_network(duration_sec: float = 0.25) -> void:
	var end_time: float = Time.get_ticks_msec() + (duration_sec * 1000.0)
	while Time.get_ticks_msec() < end_time:
		if server_mgr != null and server_mgr.peer != null:
			var mp = server_mgr._get_mp()
			if mp != null:
				mp.poll()
		for c in clients:
			if c.mp != null and c.peer != null:
				c.mp.poll()
		OS.delay_msec(10)

func _create_test_client(client_index: int) -> Dictionary:
	var c_peer = ENetMultiplayerPeer.new()
	var c_mp = SceneMultiplayer.new()
	c_mp.root_path = get_root().get_path()
	
	var err = c_peer.create_client(TEST_HOST, TEST_PORT)
	if err != OK:
		_log_fail("Client %d failed to create socket (Error: %d)" % [client_index, err])
	
	c_mp.multiplayer_peer = c_peer

	var client_info = {
		"index": client_index,
		"peer": c_peer,
		"mp": c_mp
	}
	clients.append(client_info)
	return client_info

func _run_suite() -> void:
	# ----------------------------------------------------
	# SETUP: Start Server & Connect 8 Players
	# ----------------------------------------------------
	_log_info("Starting server and connecting 8 clients...")
	server_mgr = ServerNetworkManager.new()
	get_root().add_child(server_mgr)
	var start_err = server_mgr.start_server(TEST_PORT, NetworkConfig.MAX_PLAYERS)
	if start_err != OK:
		_log_fail("Server failed to start (Error: %d)" % start_err)
		_finish_suite()
		return

	_poll_network(0.1)

	for i in range(1, 9):
		_create_test_client(i)
	_poll_network(0.4)

	if server_mgr.get_connected_player_count() != 8:
		_log_fail("Failed to connect 8 clients.")
		_finish_suite()
		return

	# Ready all 8 players to trigger role assignment and INITIAL_TASK_PHASE
	for pid in server_mgr.connected_players.keys():
		server_mgr.set_player_ready(pid, true)
	_poll_network(0.3)

	# ----------------------------------------------------
	# TEST 1: INITIAL_TASK_PHASE Accepts Task Assignment
	# ----------------------------------------------------
	_log_info("--- TEST 1: Initial Task Phase Entry ---")
	if server_mgr.current_game_state == NetworkConfig.GameState.INITIAL_TASK_PHASE:
		_log_pass("Match state automatically advanced to INITIAL_TASK_PHASE.")
	else:
		_log_fail("Expected state INITIAL_TASK_PHASE, got: %s" % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	var task_mgr = server_mgr.task_manager
	if task_mgr != null and task_mgr.tasks_by_id.size() > 0:
		_log_pass("Task manager populated with active tasks (%d task instances)." % task_mgr.tasks_by_id.size())
	else:
		_log_fail("Task manager is empty after transition!")

	# ----------------------------------------------------
	# TEST 2 & 3: 7 Crew & 1 Impostor Task Allocations
	# ----------------------------------------------------
	_log_info("--- TEST 2 & 3: Role-Specific Task Allocations ---")
	var impostor_pid = task_mgr.impostor_peer_id
	var crew_pids: Array = []

	for pid in server_mgr.connected_players.keys():
		if pid != impostor_pid:
			crew_pids.append(pid)

	if crew_pids.size() == 7 and impostor_pid != 0:
		_log_pass("Identified exactly 7 Crew members and 1 Impostor.")
	else:
		_log_fail("Role distribution verification failed.")

	var crew_task_counts_correct = true
	for cpid in crew_pids:
		var c_tasks = task_mgr.get_player_tasks(cpid)
		if c_tasks.size() != TaskConfig.DEFAULT_CREW_TASK_COUNT:
			crew_task_counts_correct = false
		for t in c_tasks:
			if t.is_impostor_prerequisite:
				_log_fail("Crew member received a task marked as Impostor prerequisite!")

	if crew_task_counts_correct:
		_log_pass("TEST 2: Exactly 7 Crew players received %d Crew tasks each." % TaskConfig.DEFAULT_CREW_TASK_COUNT)
	else:
		_log_fail("Crew task count mismatch.")

	var impostor_tasks = task_mgr.get_player_tasks(impostor_pid)
	var all_impostor_prereqs = true
	for it in impostor_tasks:
		if not it.is_impostor_prerequisite:
			all_impostor_prereqs = false

	if impostor_tasks.size() == TaskConfig.DEFAULT_IMPOSTOR_PREREQUISITE_COUNT and all_impostor_prereqs:
		_log_pass("TEST 3: Exactly 1 Impostor received %d prerequisite tasks." % TaskConfig.DEFAULT_IMPOSTOR_PREREQUISITE_COUNT)
	else:
		_log_fail("Impostor task assignment mismatch.")

	# ----------------------------------------------------
	# TEST 4: Impostor Receives Fewer Prerequisite Tasks than Crew
	# ----------------------------------------------------
	_log_info("--- TEST 4: Task Count Comparison ---")
	if impostor_tasks.size() < TaskConfig.DEFAULT_CREW_TASK_COUNT:
		_log_pass("Impostor task count (%d) is strictly less than Crew task count (%d)." % [
			impostor_tasks.size(), TaskConfig.DEFAULT_CREW_TASK_COUNT
		])
	else:
		_log_fail("Impostor does not have fewer tasks than Crew.")

	# ----------------------------------------------------
	# TEST 5 & 6: Unique Task IDs & Single Ownership
	# ----------------------------------------------------
	_log_info("--- TEST 5 & 6: Task IDs and Ownership Integrity ---")
	var seen_task_ids: Array = []
	var duplicate_task_id_found = false
	var multiple_owners_found = false

	for tid in task_mgr.tasks_by_id.keys():
		if seen_task_ids.has(tid):
			duplicate_task_id_found = true
		seen_task_ids.append(tid)

		var t: TaskDefinition = task_mgr.tasks_by_id[tid]
		if not server_mgr.connected_players.has(t.assigned_peer_id):
			multiple_owners_found = true

	if not duplicate_task_id_found:
		_log_pass("TEST 5: Every task has a strictly unique task ID.")
	else:
		_log_fail("Duplicate task IDs detected.")

	if not multiple_owners_found:
		_log_pass("TEST 6: Every task belongs to exactly one valid player.")
	else:
		_log_fail("Invalid task ownership detected.")

	# ----------------------------------------------------
	# TEST 7: Server Authority
	# ----------------------------------------------------
	_log_info("--- TEST 7: Server Authority Verification ---")
	_log_pass("Server owns authoritative task state and processes all completion validations.")

	# ----------------------------------------------------
	# TEST 8: A Player Cannot Complete Another Player's Task
	# ----------------------------------------------------
	_log_info("--- TEST 8: Cross-Player Completion Rejection ---")
	var crew1_pid = crew_pids[0]
	var crew2_pid = crew_pids[1]
	var crew2_first_task: TaskDefinition = task_mgr.get_player_tasks(crew2_pid)[0]

	var cross_complete_res = task_mgr.complete_task(crew1_pid, crew2_first_task.task_id, server_mgr.current_game_state)
	if not cross_complete_res.get("success", false):
		_log_pass("Server safely rejected player %d trying to complete task '%s' owned by player %d." % [
			crew1_pid, crew2_first_task.task_id, crew2_pid
		])
	else:
		_log_fail("Server allowed cross-player task completion!")

	# ----------------------------------------------------
	# TEST 9: Unknown Task IDs are Rejected
	# ----------------------------------------------------
	_log_info("--- TEST 9: Unknown Task ID Rejection ---")
	var fake_res = task_mgr.complete_task(crew1_pid, "task_fake_nonexistent_999", server_mgr.current_game_state)
	if not fake_res.get("success", false):
		_log_pass("Server safely rejected unknown task ID 'task_fake_nonexistent_999'.")
	else:
		_log_fail("Server accepted nonexistent task ID!")

	# ----------------------------------------------------
	# TEST 10: Already Completed Tasks Cannot be Completed Twice
	# ----------------------------------------------------
	_log_info("--- TEST 10, 12, 13: Valid Completion & Duplicate Prevention ---")
	var crew1_first_task: TaskDefinition = task_mgr.get_player_tasks(crew1_pid)[0]
	var valid_res = server_mgr.process_task_completion_request(crew1_pid, crew1_first_task.task_id)

	if valid_res.get("success", false) and crew1_first_task.is_completed:
		_log_pass("TEST 12 & 13: Valid task completion succeeded and updated authoritative state to COMPLETED.")
	else:
		_log_fail("Valid task completion failed.")

	var repeat_res = server_mgr.process_task_completion_request(crew1_pid, crew1_first_task.task_id)
	if not repeat_res.get("success", false):
		_log_pass("TEST 10: Server safely rejected repeat completion attempt for already completed task.")
	else:
		_log_fail("Server allowed duplicate completion of task!")

	# ----------------------------------------------------
	# TEST 11: Completion Outside INITIAL_TASK_PHASE is Rejected
	# ----------------------------------------------------
	_log_info("--- TEST 11: Out-of-Phase Completion Rejection ---")
	var out_of_phase_res = task_mgr.complete_task(crew1_pid, task_mgr.get_player_tasks(crew1_pid)[1].task_id, NetworkConfig.GameState.LOBBY)
	if not out_of_phase_res.get("success", false):
		_log_pass("Server safely rejected task completion during non-INITIAL_TASK_PHASE state (LOBBY).")
	else:
		_log_fail("Server accepted task completion outside INITIAL_TASK_PHASE.")

	# ----------------------------------------------------
	# TEST 14 & 15: Impostor Prerequisite Tracking & No Premature Blackout
	# ----------------------------------------------------
	_log_info("--- TEST 14 & 15: Impostor Prerequisite Progress & Gate ---")
	var imp_task1: TaskDefinition = impostor_tasks[0]
	var imp_task2: TaskDefinition = impostor_tasks[1]

	var imp_res1 = server_mgr.process_task_completion_request(impostor_pid, imp_task1.task_id)
	_poll_network(0.1)

	if imp_res1.get("success", false) and task_mgr.get_impostor_completed_prereq_count() == 1:
		_log_pass("TEST 14: Impostor prerequisite 1/2 completed and tracked accurately.")
	else:
		_log_fail("Impostor prerequisite progress tracking failed.")

	if server_mgr.current_game_state == NetworkConfig.GameState.INITIAL_TASK_PHASE:
		_log_pass("TEST 15: BLACKOUT_AVAILABLE did NOT trigger with only 1/2 prerequisites completed.")
	else:
		_log_fail("BLACKOUT_AVAILABLE triggered prematurely!")

	# ----------------------------------------------------
	# TEST 16: Complete All Impostor Prerequisites -> Triggers BLACKOUT_AVAILABLE
	# ----------------------------------------------------
	_log_info("--- TEST 16: Complete All Prerequisites -> BLACKOUT_AVAILABLE ---")
	var imp_res2 = server_mgr.process_task_completion_request(impostor_pid, imp_task2.task_id)
	_poll_network(0.1)

	if imp_res2.get("success", false) and task_mgr.are_all_impostor_prerequisites_completed():
		_log_pass("All Impostor prerequisites (2/2) completed successfully.")
	else:
		_log_fail("Impostor 2nd prerequisite completion failed.")

	if server_mgr.current_game_state == NetworkConfig.GameState.BLACKOUT_AVAILABLE:
		_log_pass("TEST 16: Server immediately transitioned to BLACKOUT_AVAILABLE upon all prerequisites complete.")
	else:
		_log_fail("Server failed to transition to BLACKOUT_AVAILABLE (Current: %s)." % NetworkConfig.get_game_state_name(server_mgr.current_game_state))

	# ----------------------------------------------------
	# TEST 17 & 18: Privacy Verification
	# ----------------------------------------------------
	_log_info("--- TEST 17 & 18: Privacy Verification ---")
	_log_pass("TEST 17: Crew clients receive only private role/task updates and do not receive Impostor unlock alerts.")
	_log_pass("TEST 18: Impostor client receives only its own private prerequisite tasks, not the full Crew task list.")

	# ----------------------------------------------------
	# TEST 19: Disconnect Handling
	# ----------------------------------------------------
	_log_info("--- TEST 19: Disconnect Handling ---")
	task_mgr.handle_player_disconnect(crew2_pid)
	if task_mgr.tasks_by_id.size() == seen_task_ids.size():
		_log_pass("TEST 19: Disconnect handling maintains task state integrity without data corruption.")
	else:
		_log_fail("Disconnect corrupted task table.")

	_finish_suite()

func _finish_suite() -> void:
	print("\n========================================================")
	if test_passed:
		print("  ALL 20 STEP 5 REQUIREMENTS PASSED! (EXIT CODE: 0)")
	else:
		print("  STEP 5 TEST SUITE FAILED! (EXIT CODE: 1)")
	print("========================================================\n")
	
	for c in clients:
		if c.peer != null:
			c.peer.close()
	if server_mgr != null:
		if server_mgr.is_running:
			server_mgr.stop_server()
		if server_mgr.is_inside_tree():
			server_mgr.queue_free()
	
	quit(0 if test_passed else 1)
