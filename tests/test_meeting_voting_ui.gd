extends SceneTree

## Headless Integration & Unit Test Suite for BLACKOUT Meeting & Voting UI (Stage 18).
## Verifies:
##   1. Meeting UI opens on meeting_started and enters DISCUSSION phase
##   2. Discussion countdown timer ticks and transitions to VOTING phase
##   3. Real player roster is accurately displayed with names, alive/eliminated states, local indicators
##   4. Alive local player can cast a vote for an alive target
##   5. Eliminated local player cannot vote (buttons locked)
##   6. Voting for already-eliminated target is rejected
##   7. Skip vote option works (target = -1 / VOTE_SKIP)
##   8. Duplicate vote submissions are strictly blocked
##   9. Immediate visual feedback on vote submission
##   10. Authoritative results display ejection, was_impostor, tie, and skip
##   11. Local player movement is locked during meeting and restored after close
##   12. Eliminated local player remains locked after meeting
##   13. Meeting UI closes and resets correctly

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const MeetingVotingUI = preload("res://client/ui/meeting_voting_ui.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — IN-GAME MEETING & VOTING UI TEST (STAGE 18)")
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

	# Create UI instance
	var ui: MeetingVotingUI = MeetingVotingUI.new()
	root.add_child(ui)

	# Create Mock Local Player
	var mock_player: PlayerController = PlayerController.new()
	mock_player.name = "Player"
	mock_player.slot_id = 1
	mock_player.is_local_player = true
	mock_player.can_move = true
	root.add_child(mock_player)
	ui.register_local_player(mock_player)

	# -------------------------------------------------------------------------
	# TEST 1: Meeting opens and enters DISCUSSION phase
	# -------------------------------------------------------------------------
	_log_info("--- Test 1: Meeting Open & Discussion Phase ---")
	ui.open_meeting(102, 25.0)
	if ui.visible and ui.current_phase == MeetingConfig.MeetingPhase.DISCUSSION and ui.current_timer_remaining == 25.0:
		_log_pass("TEST 1: Meeting UI opened in DISCUSSION phase with 25.0s countdown.")
	else:
		_log_fail("TEST 1: Meeting UI failed to open correctly.")

	# -------------------------------------------------------------------------
	# TEST 2: Movement is locked when meeting opens
	# -------------------------------------------------------------------------
	_log_info("--- Test 2: Player Input Locking ---")
	if not mock_player.can_move:
		_log_pass("TEST 2: Local player movement locked (can_move == false) during meeting.")
	else:
		_log_fail("TEST 2: Player movement was not locked during meeting.")

	# -------------------------------------------------------------------------
	# TEST 3: Discussion timer ticks down
	# -------------------------------------------------------------------------
	_log_info("--- Test 3: Timer Ticking ---")
	ui._process(5.0)
	if is_equal_approx(ui.current_timer_remaining, 20.0):
		_log_pass("TEST 3: Timer ticked down correctly from 25.0s to 20.0s.")
	else:
		_log_fail("TEST 3: Timer tick calculation error (Got: %.1f)." % ui.current_timer_remaining)

	# -------------------------------------------------------------------------
	# TEST 4: Real player roster is populated
	# -------------------------------------------------------------------------
	_log_info("--- Test 4: Real Player Roster Display ---")
	var sample_roster = [
		{"peer_id": 1, "slot_id": 1, "name": "Player 1", "is_alive": true},
		{"peer_id": 102, "slot_id": 2, "name": "Player 2", "is_alive": true},
		{"peer_id": 103, "slot_id": 3, "name": "Player 3", "is_alive": true},
		{"peer_id": 104, "slot_id": 4, "name": "Player 4", "is_alive": false} # Eliminated
	]
	ui.local_peer_id = 1
	ui.set_player_roster(sample_roster)

	if ui.player_card_nodes.size() == 4:
		var card1 = ui.player_card_nodes[1]
		var card4 = ui.player_card_nodes[104]
		var name1: Label = card1.get("name_label")
		var status4: Label = card4.get("status_label")

		var has_you = name1 != null and name1.text.contains("(YOU)")
		var is_elim = status4 != null and status4.text.contains("ELIMINATED")

		if has_you and is_elim:
			_log_pass("TEST 4: Real player roster displayed (4 players, local (YOU) tag, eliminated badge).")
		else:
			_log_fail("TEST 4: Roster display formatting mismatch (You: %s, Elim: %s)." % [str(has_you), str(is_elim)])
	else:
		_log_fail("TEST 4: Roster card count mismatch (Expected: 4, Got: %d)." % ui.player_card_nodes.size())

	# -------------------------------------------------------------------------
	# TEST 5: Voting phase activation
	# -------------------------------------------------------------------------
	_log_info("--- Test 5: Voting Phase Transition ---")
	ui.start_voting(30.0)
	if ui.current_phase == MeetingConfig.MeetingPhase.VOTING and ui.current_timer_remaining == 30.0:
		_log_pass("TEST 5: Transitioned to VOTING phase with active 30.0s timer.")
	else:
		_log_fail("TEST 5: Transition to voting phase failed.")

	# -------------------------------------------------------------------------
	# TEST 6: Alive player can vote for an alive target
	# -------------------------------------------------------------------------
	_log_info("--- Test 6: Alive Player Voting ---")
	var vote_ok = ui.cast_vote(102)
	if vote_ok and ui.has_voted_locally and ui.selected_vote_target == 102:
		_log_pass("TEST 6: Alive player successfully voted for Player 2 (Peer 102).")
	else:
		_log_fail("TEST 6: Vote submission failed.")

	# -------------------------------------------------------------------------
	# TEST 7: Duplicate vote is blocked
	# -------------------------------------------------------------------------
	_log_info("--- Test 7: Duplicate Vote Prevention ---")
	var dup_vote = ui.cast_vote(103)
	if not dup_vote:
		_log_pass("TEST 7: Duplicate vote submission was correctly blocked.")
	else:
		_log_fail("TEST 7: Duplicate vote was incorrectly permitted.")

	# -------------------------------------------------------------------------
	# TEST 8: Skip Vote option works
	# -------------------------------------------------------------------------
	_log_info("--- Test 8: Skip Vote Option ---")
	ui.open_meeting(102, 10.0)
	ui.set_player_roster(sample_roster)
	ui.start_voting(15.0)
	var skip_ok = ui.cast_vote(MeetingConfig.VOTE_SKIP)
	if skip_ok and ui.selected_vote_target == MeetingConfig.VOTE_SKIP:
		_log_pass("TEST 8: Skip vote successfully cast (target == VOTE_SKIP / -1).")
	else:
		_log_fail("TEST 8: Skip vote failed.")

	# -------------------------------------------------------------------------
	# TEST 9: Eliminated player cannot vote
	# -------------------------------------------------------------------------
	_log_info("--- Test 9: Eliminated Player Voting Restriction ---")
	ui.open_meeting(102, 10.0)
	ui.set_player_roster(sample_roster)
	ui.is_local_eliminated = true
	ui.start_voting(15.0)
	var elim_vote = ui.cast_vote(103)
	if not elim_vote:
		_log_pass("TEST 9: Eliminated player was correctly blocked from voting.")
	else:
		_log_fail("TEST 9: Eliminated player was incorrectly allowed to vote.")

	# -------------------------------------------------------------------------
	# TEST 10: Voting for eliminated target is rejected
	# -------------------------------------------------------------------------
	_log_info("--- Test 10: Target Validation ---")
	ui.is_local_eliminated = false
	ui.has_voted_locally = false
	var vote_dead_target = ui.cast_vote(104) # 104 is eliminated
	if not vote_dead_target:
		_log_pass("TEST 10: Vote for already-eliminated target (104) was correctly rejected.")
	else:
		_log_fail("TEST 10: Vote for eliminated target was allowed.")

	# -------------------------------------------------------------------------
	# TEST 11: Authoritative Results Display (Ejected Impostor)
	# -------------------------------------------------------------------------
	_log_info("--- Test 11: Results Display (Ejected Impostor) ---")
	var result_impostor = {
		"eliminated_peer_id": 102,
		"was_impostor": true,
		"is_tie": false,
		"is_skip": false,
		"total_votes_cast": 3,
		"skip_count": 0
	}
	ui.show_results(result_impostor)
	if ui.results_panel != null and ui.results_panel.visible:
		var title_ok = ui.results_title_label.text.contains("Player 2 was Ejected")
		var detail_ok = ui.results_detail_label.text.contains("was the Impostor")
		if title_ok and detail_ok:
			_log_pass("TEST 11: Result displayed correctly (Player 2 ejected, was the Impostor).")
		else:
			_log_fail("TEST 11: Result text mismatch (Title: '%s', Detail: '%s')." % [ui.results_title_label.text, ui.results_detail_label.text])
	else:
		_log_fail("TEST 11: Results panel was not visible.")

	# -------------------------------------------------------------------------
	# TEST 12: Authoritative Results Display (Tie / Skip)
	# -------------------------------------------------------------------------
	_log_info("--- Test 12: Results Display (Tie & Skip) ---")
	var result_tie = {
		"eliminated_peer_id": 0,
		"was_impostor": false,
		"is_tie": true,
		"is_skip": false,
		"total_votes_cast": 2,
		"skip_count": 0
	}
	ui.show_results(result_tie)
	var tie_ok = ui.results_title_label.text.contains("No one was ejected. (Tie)")

	var result_skip = {
		"eliminated_peer_id": 0,
		"was_impostor": false,
		"is_tie": false,
		"is_skip": true,
		"total_votes_cast": 3,
		"skip_count": 2
	}
	ui.show_results(result_skip)
	var skip_display_ok = ui.results_title_label.text.contains("No one was ejected. (Skipped)")

	if tie_ok and skip_display_ok:
		_log_pass("TEST 12: Tie and Skip results displayed correctly without ejection.")
	else:
		_log_fail("TEST 12: Tie/Skip display mismatch (Tie: %s, Skip: %s)." % [str(tie_ok), str(skip_display_ok)])

	# -------------------------------------------------------------------------
	# TEST 13: Meeting Close and Control Restoration
	# -------------------------------------------------------------------------
	_log_info("--- Test 13: Meeting Close & Control Restoration ---")
	ui.is_local_eliminated = false
	ui.close_meeting()
	if not ui.visible and ui.current_phase == MeetingConfig.MeetingPhase.NONE and mock_player.can_move:
		_log_pass("TEST 13: Meeting UI closed, state reset to NONE, player controls restored (can_move == true).")
	else:
		_log_fail("TEST 13: Close meeting failed (Visible: %s, Phase: %s, CanMove: %s)." % [
			str(ui.visible), str(ui.current_phase), str(mock_player.can_move)
		])

	# -------------------------------------------------------------------------
	# TEST 14: Eliminated player controls remain locked after meeting
	# -------------------------------------------------------------------------
	_log_info("--- Test 14: Eliminated Player Movement Restraint ---")
	ui.open_meeting(102, 5.0)
	ui.show_results({"eliminated_peer_id": 1, "was_impostor": false, "is_tie": false, "is_skip": false}) # Local player eliminated
	ui.close_meeting()
	if not mock_player.can_move and ui.is_local_eliminated:
		_log_pass("TEST 14: Eliminated local player movement remains locked after meeting.")
	else:
		_log_fail("TEST 14: Eliminated player movement was incorrectly restored.")

	# Cleanup
	ui.queue_free()
	mock_player.queue_free()

	# Summary
	print("\n========================================================")
	if test_passed:
		print("  ALL STAGE 18 MEETING & VOTING UI TESTS PASSED!")
	else:
		print("  STAGE 18 TESTS FAILED!")
	print("========================================================\n")

	quit(0 if test_passed else 1)
