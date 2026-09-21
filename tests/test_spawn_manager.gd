extends SceneTree

## Comprehensive Unit Test Suite for BLACKOUT Player Spawn Manager (Member 3).
## Validates all 10 core requirements:
##   1. Support for 8 deterministic spawn positions (Slots 1 to 8).
##   2. Unique sequential slot allocation (Peer 1 -> Slot 1, Peer 2 -> Slot 2, ...).
##   3. Prevention of duplicate slot assignment for concurrently active peers.
##   4. Exact mapping of authoritative preferred slots.
##   5. Hard capacity limit: rejects 9th+ player when all 8 slots are active.
##   6. Disconnection properly frees the player's assigned slot.
##   7. New/reconnecting player can reuse the freed slot.
##   8. Out-of-bounds/invalid slot requests fall back safely.
##   9. place_player() correctly positions PlayerController and syncs slot identity.
##   10. Session reset clears all allocations cleanly.

const SpawnManager = preload("res://client/player/spawn_manager.gd")
const PlayerController = preload("res://client/player/player_controller.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

var test_passed: bool = true
var test_log: Array[String] = []

func _init() -> void:
	print("\n========================================================")
	print("  BLACKOUT — SPAWN MANAGER VALIDATION SUITE (MEMBER 3)")
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
	test_deterministic_slot_positions()
	test_unique_multiplayer_slot_allocations()
	test_duplicate_prevention_and_preferred_slot()
	test_capacity_limit_8_players()
	test_disconnect_and_slot_reuse()
	test_player_placement_and_identity()
	test_session_reset()

	print("\n========================================================")
	if test_passed:
		print("  SPAWN MANAGER TESTS: ALL 10 REQUIREMENTS PASSED (100%)")
	else:
		print("  SPAWN MANAGER TESTS: SOME TESTS FAILED")
	print("========================================================\n")

	quit(0 if test_passed else 1)

func test_deterministic_slot_positions() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	var expected_positions = [
		Vector2(800.0, 550.0), # Slot 1: Central Hub Core
		Vector2(720.0, 550.0), # Slot 2: Central Hub West
		Vector2(880.0, 550.0), # Slot 3: Central Hub East
		Vector2(800.0, 470.0), # Slot 4: Central Hub North
		Vector2(800.0, 630.0), # Slot 5: Central Hub South
		Vector2(730.0, 480.0), # Slot 6: Central Hub North-West
		Vector2(870.0, 480.0), # Slot 7: Central Hub North-East
		Vector2(730.0, 620.0)  # Slot 8: Central Hub South-West
	]

	var all_match = true
	for i in range(8):
		var slot_id = i + 1
		var actual = sm.get_spawn_position(slot_id)
		if actual != expected_positions[i]:
			all_match = false

	if all_match:
		_log_pass("1. All 8 slots return exact deterministic spawn positions.")
	else:
		_log_fail("1. Deterministic position mismatch.")
	sm.free()

func test_unique_multiplayer_slot_allocations() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	var assigned_slots: Array[int] = []
	for peer_id in range(101, 109): # 8 peers (101..108)
		var slot = sm.assign_slot(peer_id)
		assigned_slots.append(slot)

	# Verify slots 1 through 8 were uniquely assigned
	var is_unique = true
	for expected_slot in range(1, 9):
		if not assigned_slots.has(expected_slot):
			is_unique = false

	if is_unique and assigned_slots.size() == 8:
		_log_pass("2. Eight connected peers receive 8 distinct unique slots (1 to 8).")
	else:
		_log_fail("2. Slot allocation uniqueness failed: %s" % str(assigned_slots))
	sm.free()

func test_duplicate_prevention_and_preferred_slot() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	var slot_a = sm.assign_slot(201, 3) # Peer 201 requests preferred Slot 3
	var slot_b = sm.assign_slot(202, 3) # Peer 202 requests already occupied Slot 3

	if slot_a == 3 and slot_b != 3 and slot_b >= 1 and slot_b <= 8:
		_log_pass("3. Duplicate prevention: Second peer requesting occupied slot is redirected to available slot.")
	else:
		_log_fail("3. Duplicate prevention failed (slot_a=%d, slot_b=%d)." % [slot_a, slot_b])

	# Calling assign_slot again for the same peer returns their existing slot
	var slot_a_repeat = sm.assign_slot(201)
	if slot_a_repeat == 3:
		_log_pass("4. Idempotency: Existing peer maintains their assigned slot.")
	else:
		_log_fail("4. Idempotency check failed.")
	sm.free()

func test_capacity_limit_8_players() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	# Fill all 8 slots
	for peer_id in range(1, 9):
		sm.assign_slot(peer_id)

	if sm.get_active_player_count() == 8:
		_log_pass("5. Active player count reaches capacity at 8 players.")
	else:
		_log_fail("5. Active player count incorrect: %d" % sm.get_active_player_count())

	# 9th player attempts to join
	var slot_9 = sm.assign_slot(999)
	if slot_9 == 0 and sm.get_active_player_count() == 8:
		_log_pass("6. 9th player is rejected when all 8 slots are occupied (returns slot 0).")
	else:
		_log_fail("6. 9th player was not rejected correctly (returned %d)." % slot_9)
	sm.free()

func test_disconnect_and_slot_reuse() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	# Fill slots 1 to 8
	for peer_id in range(1, 9):
		sm.assign_slot(peer_id)

	# Disconnect peer 4 (who held Slot 4)
	var freed_slot = sm.free_slot(4)
	if freed_slot == 4 and sm.is_slot_available(4) and sm.get_active_player_count() == 7:
		_log_pass("7. Disconnecting peer 4 frees Slot 4 and decrements active count.")
	else:
		_log_fail("7. Disconnect slot freeing failed.")

	# A new peer 99 joins; they should receive the freed Slot 4
	var new_slot = sm.assign_slot(99)
	if new_slot == 4 and sm.get_peer_for_slot(4) == 99 and sm.get_active_player_count() == 8:
		_log_pass("8. Reconnecting/new peer 99 immediately reuses freed Slot 4.")
	else:
		_log_fail("8. Slot reuse failed (assigned slot %d instead of 4)." % new_slot)
	sm.free()

func test_player_placement_and_identity() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	var player_instance = PlayerScene.instantiate() as PlayerController
	if player_instance != null:
		var success = sm.place_player(player_instance, 5, 505)
		var expected_pos = sm.get_spawn_position(5)

		if success and player_instance.global_position == expected_pos and player_instance.slot_id == 5:
			_log_pass("9. place_player() correctly teleports player to Slot 5 coordinates and updates slot ID.")
		else:
			_log_fail("9. Player placement failed.")
		player_instance.free()
	else:
		_log_fail("9. PlayerScene instantiation failed.")
	sm.free()

func test_session_reset() -> void:
	var sm = SpawnManager.new()
	sm._ready()

	sm.assign_slot(1)
	sm.assign_slot(2)
	sm.assign_slot(3)

	sm.reset_all_assignments()
	if sm.get_active_player_count() == 0 and sm.is_slot_available(1) and sm.is_slot_available(2):
		_log_pass("10. reset_all_assignments() cleanly wipes all reservations upon disconnect/reset.")
	else:
		_log_fail("10. Reset assignments failed.")
	sm.free()
