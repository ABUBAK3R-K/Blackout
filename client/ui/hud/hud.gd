class_name InGameHUD
extends CanvasLayer

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")
const TaskChecklistUI = preload("res://client/ui/hud/task_checklist.gd")
const RecoveryTrackerUI = preload("res://client/ui/hud/recovery_tracker.gd")
const BlackoutBannerUI = preload("res://client/ui/hud/blackout_banner.gd")
const MeltdownHUDUI = preload("res://client/ui/hud/meltdown_hud.gd")
const ImpostorHUDUI = preload("res://client/ui/hud/impostor_hud.gd")
const MeetingScreenUI = preload("res://client/ui/meeting/meeting_screen.gd")
const EjectionRevealScreenUI = preload("res://client/ui/meeting/ejection_reveal.gd")
const VictoryDefeatScreenUI = preload("res://client/ui/screens/victory_defeat_screen.gd")
const ResultScreenUI = preload("res://client/ui/screens/result_screen.gd")

@onready var task_checklist: Control = $TaskChecklist
@onready var recovery_tracker: Control = $RecoveryTracker
@onready var blackout_banner: Control = $BlackoutBanner
@onready var meltdown_hud: Control = $MeltdownHUD
@onready var impostor_hud: Control = $ImpostorHUD
@onready var meeting_screen: Control = $MeetingScreen
@onready var ejection_reveal: Control = $EjectionReveal
@onready var victory_defeat_screen: Control = $VictoryDefeatScreen
@onready var result_screen: Control = $ResultScreen

var _saved_hud_state_before_meeting: Dictionary = {}

func _ready() -> void:
	layer = 10 # Place above game world and environment tiles
	_ensure_node_references()
	_connect_to_network_events()
	
	print("\n========================================================")
	print("  [BLACKOUT HUD] In-Game HUD Active")
	print("  Hotkeys for Offline Testing:")
	print("    [1] or [Space] : Cycle Task Checklist (mark next task done)")
	print("    [2] or [T]     : Cycle Recovery Progress (0/4 -> 1/4 -> 2/4 -> 3/4 -> 4/4)")
	print("    [3]           : Toggle Recovery Tracker Visibility (Show / Hide)")
	print("    [4] or [B]     : Toggle Blackout Countdown Banner (Start / End 40s)")
	print("    [5] or [M]     : Cycle Meltdown Systems (0/3 -> 1/3 -> 2/3 -> 3/3)")
	print("    [6] or [I]     : Toggle Impostor HUD (Crew vs Impostor role view)")
	print("    [7] or [N]     : Trigger / Toggle Emergency Meeting Alert & Screen")
	print("    [8] or [V]     : Trigger / Toggle Voting Phase UI (Player selection)")
	print("    [9] or [E]     : Cycle Ejection Reveal Outcomes (Impostor -> Crew -> Tie -> Skip)")
	print("    [0] or [G]     : Cycle Game Over / Result Screen Outcomes (Crew -> Impostor)")
	print("    [Tab]          : Toggle Sabotage Action Wheel (Impostor only)")
	print("    [R]           : Reset HUD to Initial Preview State")
	print("========================================================\n")

func _ensure_node_references() -> void:
	if task_checklist == null and has_node("TaskChecklist"):
		task_checklist = get_node("TaskChecklist")
	if recovery_tracker == null and has_node("RecoveryTracker"):
		recovery_tracker = get_node("RecoveryTracker")
	if blackout_banner == null and has_node("BlackoutBanner"):
		blackout_banner = get_node("BlackoutBanner")
	if meltdown_hud == null and has_node("MeltdownHUD"):
		meltdown_hud = get_node("MeltdownHUD")
	if impostor_hud == null and has_node("ImpostorHUD"):
		impostor_hud = get_node("ImpostorHUD")
	if meeting_screen == null and has_node("MeetingScreen"):
		meeting_screen = get_node("MeetingScreen")
	if ejection_reveal == null and has_node("EjectionReveal"):
		ejection_reveal = get_node("EjectionReveal")
	if victory_defeat_screen == null and has_node("VictoryDefeatScreen"):
		victory_defeat_screen = get_node("VictoryDefeatScreen")
	if victory_defeat_screen != null and not victory_defeat_screen.sequence_completed.is_connected(_on_victory_defeat_sequence_completed):
		victory_defeat_screen.sequence_completed.connect(_on_victory_defeat_sequence_completed)
	if result_screen == null and has_node("ResultScreen"):
		result_screen = get_node("ResultScreen")

func _connect_to_network_events() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("meeting_started") and not client.meeting_started.is_connected(_on_meeting_started):
				client.meeting_started.connect(_on_meeting_started)
			if client.has_signal("voting_started") and not client.voting_started.is_connected(_on_voting_started):
				client.voting_started.connect(_on_voting_started)
			if client.has_signal("vote_result_received") and not client.vote_result_received.is_connected(_on_vote_result_received):
				client.vote_result_received.connect(_on_vote_result_received)
			if client.has_signal("game_over_received") and not client.game_over_received.is_connected(_on_game_over_received):
				client.game_over_received.connect(_on_game_over_received)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)

func _on_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	_transition_into_meeting(caller_peer_id, discussion_duration)

func _on_voting_started(voting_duration: float) -> void:
	_transition_into_voting(voting_duration)

func _on_vote_result_received(result_data: Dictionary) -> void:
	_transition_into_ejection_reveal(result_data)

func _on_game_over_received(winner_role: int, reason: int, result_data: Dictionary) -> void:
	_transition_into_game_over(winner_role, reason, result_data)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.MEETING:
		if meeting_screen != null and not meeting_screen.is_meeting_open():
			_transition_into_meeting(0, 30.0)
	elif new_state == NetworkConfig.GameState.VOTING:
		if meeting_screen != null:
			_transition_into_voting(30.0)
	elif new_state == NetworkConfig.GameState.GAME_OVER:
		if result_screen != null and not result_screen.is_screen_active():
			# Fallback if game_over_received payload not yet delivered
			_transition_into_game_over(NetworkConfig.PlayerRole.CREW, MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE, {})
	else:
		if meeting_screen != null and meeting_screen.is_meeting_open():
			_transition_out_of_meeting()

func _transition_into_meeting(caller_id: int, duration: float) -> void:
	_ensure_node_references()
	# Save current HUD element visibility to restore upon meeting conclusion
	_saved_hud_state_before_meeting = {
		"task_checklist": task_checklist.visible if task_checklist != null else false,
		"recovery_tracker": recovery_tracker.visible if recovery_tracker != null else false,
		"blackout_banner": blackout_banner.visible if blackout_banner != null else false,
		"impostor_hud": impostor_hud.visible if impostor_hud != null else false,
		"meltdown_hud": meltdown_hud.visible if meltdown_hud != null else false
	}
	
	# Hide normal gameplay HUD elements during meeting assembly
	if task_checklist != null:
		task_checklist.visible = false
	if recovery_tracker != null:
		recovery_tracker.visible = false
	if blackout_banner != null:
		blackout_banner.visible = false
	if impostor_hud != null:
		impostor_hud.visible = false
	if meltdown_hud != null:
		meltdown_hud.visible = false
		
	if meeting_screen != null:
		meeting_screen.start_meeting(caller_id, duration)

func _transition_into_voting(duration: float) -> void:
	_ensure_node_references()
	if task_checklist != null:
		task_checklist.visible = false
	if recovery_tracker != null:
		recovery_tracker.visible = false
	if blackout_banner != null:
		blackout_banner.visible = false
	if impostor_hud != null:
		impostor_hud.visible = false
	if meltdown_hud != null:
		meltdown_hud.visible = false
		
	if meeting_screen != null:
		meeting_screen.start_voting_phase(duration)

func _transition_out_of_meeting() -> void:
	_ensure_node_references()
	if meeting_screen != null:
		meeting_screen.end_meeting(true)
	if ejection_reveal != null and ejection_reveal.has_method("dismiss_reveal"):
		ejection_reveal.dismiss_reveal(true)
		
	# Restore saved gameplay HUD visibility
	if task_checklist != null:
		task_checklist.visible = _saved_hud_state_before_meeting.get("task_checklist", true)
	if recovery_tracker != null:
		recovery_tracker.visible = _saved_hud_state_before_meeting.get("recovery_tracker", false)
	if blackout_banner != null:
		blackout_banner.visible = _saved_hud_state_before_meeting.get("blackout_banner", false)
	if impostor_hud != null:
		impostor_hud.visible = _saved_hud_state_before_meeting.get("impostor_hud", false)
	if meltdown_hud != null:
		meltdown_hud.visible = _saved_hud_state_before_meeting.get("meltdown_hud", false)

func _transition_into_ejection_reveal(result_data: Dictionary) -> void:
	_ensure_node_references()
	if meeting_screen != null:
		meeting_screen.end_meeting(false)
	if ejection_reveal != null and ejection_reveal.has_method("play_ejection_reveal"):
		var players_data = []
		if has_node("/root/NetworkManager"):
			var net_mgr = get_node("/root/NetworkManager")
			if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
				players_data = net_mgr.client.lobby_players_data
		ejection_reveal.play_ejection_reveal(result_data, players_data)

func _transition_into_game_over(winner_role: int, reason: int, result_data: Dictionary) -> void:
	_ensure_node_references()
	# Hide all active gameplay and meeting overlays
	if task_checklist != null:
		task_checklist.visible = false
	if recovery_tracker != null:
		recovery_tracker.visible = false
	if blackout_banner != null:
		blackout_banner.visible = false
	if meltdown_hud != null:
		meltdown_hud.visible = false
	if impostor_hud != null:
		impostor_hud.visible = false
	if meeting_screen != null:
		meeting_screen.end_meeting(false)
	if ejection_reveal != null and ejection_reveal.has_method("dismiss_reveal"):
		ejection_reveal.dismiss_reveal(false)
		
	var local_role = NetworkConfig.PlayerRole.CREW
	if result_data.has("local_role"):
		local_role = result_data.get("local_role")
	elif has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null:
			if net_mgr.has_method("get_player_role"):
				var r = net_mgr.get_player_role()
				if r != NetworkConfig.PlayerRole.NONE:
					local_role = r
			elif "client" in net_mgr and net_mgr.client != null and "assigned_role" in net_mgr.client:
				if net_mgr.client.assigned_role != NetworkConfig.PlayerRole.NONE:
					local_role = net_mgr.client.assigned_role
			
	if victory_defeat_screen != null and victory_defeat_screen.has_method("play_victory_defeat"):
		victory_defeat_screen.play_victory_defeat(local_role, winner_role, reason, result_data)
	elif result_screen != null and result_screen.has_method("show_game_over"):
		result_screen.show_game_over(winner_role, reason, result_data)

func _on_victory_defeat_sequence_completed(winner_role: int, reason: int, result_data: Dictionary) -> void:
	if result_screen != null and result_screen.has_method("show_game_over"):
		result_screen.show_game_over(winner_role, reason, result_data)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_1:
			if task_checklist != null and task_checklist.has_method("_toggle_next_offline_task"):
				task_checklist._toggle_next_offline_task()
				print("[HUD TEST] Toggled Task Checklist item")
		elif event.keycode == KEY_2 or event.keycode == KEY_T:
			if recovery_tracker != null and recovery_tracker.has_method("_cycle_offline_progress"):
				recovery_tracker._cycle_offline_progress()
				var comp = recovery_tracker.get_completed_count()
				var tot = recovery_tracker.get_total_count()
				print("[HUD TEST] Cycled Recovery Tracker -> %d / %d" % [comp, tot])
		elif event.keycode == KEY_3:
			if recovery_tracker != null:
				recovery_tracker.visible = not recovery_tracker.visible
				print("[HUD TEST] Recovery Tracker visibility toggled: %s" % str(recovery_tracker.visible))
		elif event.keycode == KEY_4 or event.keycode == KEY_B:
			if blackout_banner != null and blackout_banner.has_method("_toggle_offline_blackout"):
				blackout_banner._toggle_offline_blackout()
				print("[HUD TEST] Toggled Blackout Countdown Banner (Active: %s)" % str(blackout_banner.is_blackout_active()))
		elif event.keycode == KEY_5 or event.keycode == KEY_M:
			if meltdown_hud != null and meltdown_hud.has_method("_cycle_offline_systems"):
				meltdown_hud._cycle_offline_systems()
				print("[HUD TEST] Cycled Meltdown Emergency Systems")
		elif event.keycode == KEY_6 or event.keycode == KEY_I:
			if impostor_hud != null:
				impostor_hud.visible = not impostor_hud.visible
				print("[HUD TEST] Impostor HUD visibility toggled: %s" % str(impostor_hud.visible))
		elif event.keycode == KEY_7 or event.keycode == KEY_N:
			if meeting_screen != null:
				if meeting_screen.is_meeting_open() and meeting_screen.get_current_phase() == MeetingConfig.MeetingPhase.DISCUSSION:
					_transition_out_of_meeting()
					print("[HUD TEST] Exited Emergency Meeting")
				else:
					_transition_into_meeting(2, 30.0)
					print("[HUD TEST] Triggered Emergency Meeting Alert & Screen")
		elif event.keycode == KEY_8 or event.keycode == KEY_V:
			if meeting_screen != null:
				if meeting_screen.is_meeting_open() and meeting_screen.get_current_phase() == MeetingConfig.MeetingPhase.VOTING:
					_transition_out_of_meeting()
					print("[HUD TEST] Exited Voting Phase")
				else:
					_transition_into_voting(30.0)
					print("[HUD TEST] Triggered Voting Phase Screen")
		elif event.keycode == KEY_9 or event.keycode == KEY_E:
			_cycle_offline_ejection_outcome()
		elif event.keycode == KEY_0 or event.keycode == KEY_G:
			_cycle_offline_game_over_outcome()
		elif event.keycode == KEY_R:
			if task_checklist != null and task_checklist.has_method("_populate_offline_preview"):
				task_checklist.visible = true
				task_checklist._populate_offline_preview()
			if recovery_tracker != null and recovery_tracker.has_method("_populate_offline_preview"):
				recovery_tracker.visible = true
				recovery_tracker._populate_offline_preview()
			if blackout_banner != null and blackout_banner.has_method("_populate_offline_preview"):
				blackout_banner._populate_offline_preview()
			if meltdown_hud != null and meltdown_hud.has_method("_populate_offline_preview"):
				meltdown_hud._populate_offline_preview()
			if impostor_hud != null and impostor_hud.has_method("_populate_offline_preview"):
				impostor_hud._populate_offline_preview()
			if meeting_screen != null:
				meeting_screen.end_meeting(false)
			if ejection_reveal != null and ejection_reveal.has_method("dismiss_reveal"):
				ejection_reveal.dismiss_reveal(false)
			if victory_defeat_screen != null:
				victory_defeat_screen.visible = false
				victory_defeat_screen.modulate.a = 0.0
			if result_screen != null and result_screen.has_method("hide_screen"):
				result_screen.hide_screen()
			print("[HUD TEST] Reset HUD to default preview state")

var _test_ejection_cycle: int = 0
func _cycle_offline_ejection_outcome() -> void:
	_ensure_node_references()
	if ejection_reveal == null:
		return
		
	var test_players = [
		{"peer_id": 101, "player_slot": 1, "is_alive": true, "is_eliminated": false},
		{"peer_id": 102, "player_slot": 2, "is_alive": true, "is_eliminated": false},
		{"peer_id": 103, "player_slot": 3, "is_alive": true, "is_eliminated": false},
		{"peer_id": 104, "player_slot": 4, "is_alive": true, "is_eliminated": false}
	]
	
	_test_ejection_cycle = (_test_ejection_cycle + 1) % 4
	match _test_ejection_cycle:
		0:
			print("[HUD TEST] Ejection Outcome 1: Player 102 Ejected (Was Impostor: true)")
			_transition_into_ejection_reveal({
				"eliminated_peer_id": 102,
				"was_impostor": true,
				"is_tie": false,
				"is_skip": false
			})
		1:
			print("[HUD TEST] Ejection Outcome 2: Player 103 Ejected (Was Impostor: false)")
			_transition_into_ejection_reveal({
				"eliminated_peer_id": 103,
				"was_impostor": false,
				"is_tie": false,
				"is_skip": false
			})
		2:
			print("[HUD TEST] Ejection Outcome 3: Vote Tied (No one ejected)")
			_transition_into_ejection_reveal({
				"eliminated_peer_id": 0,
				"was_impostor": false,
				"is_tie": true,
				"is_skip": false
			})
		3:
			print("[HUD TEST] Ejection Outcome 4: Vote Skipped (No one ejected)")
			_transition_into_ejection_reveal({
				"eliminated_peer_id": 0,
				"was_impostor": false,
				"is_tie": false,
				"is_skip": true
			})

var _test_game_over_cycle: int = 0
func _cycle_offline_game_over_outcome() -> void:
	_ensure_node_references()
	if result_screen == null:
		return
		
	var test_roster = [
		{"peer_id": 101, "player_slot": 1, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 102, "player_slot": 2, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 103, "player_slot": 3, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 104, "player_slot": 4, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 105, "player_slot": 5, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false},
		{"peer_id": 106, "player_slot": 6, "role": NetworkConfig.PlayerRole.CREW, "is_alive": false, "is_eliminated": true},
		{"peer_id": 107, "player_slot": 7, "role": NetworkConfig.PlayerRole.IMPOSTOR, "is_alive": true, "is_eliminated": false},
		{"peer_id": 108, "player_slot": 8, "role": NetworkConfig.PlayerRole.CREW, "is_alive": true, "is_eliminated": false}
	]
	
	_test_game_over_cycle = (_test_game_over_cycle + 1) % 3
	match _test_game_over_cycle:
		0:
			print("[HUD TEST] Game Over Outcome 1: CREW VICTORY (All 3 Emergency Systems Restored)")
			_transition_into_game_over(
				NetworkConfig.PlayerRole.CREW,
				MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
				{
					"winner_role": NetworkConfig.PlayerRole.CREW,
					"reason": MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
					"completed_emergency_systems": ["restore_power", "restore_cooling", "stabilize_orion"],
					"remaining_meltdown_time": 142.5,
					"impostor_was_alive": true,
					"player_roster": test_roster
				}
			)
		1:
			print("[HUD TEST] Game Over Outcome 2: IMPOSTOR VICTORY (Meltdown Countdown Expired)")
			_transition_into_game_over(
				NetworkConfig.PlayerRole.IMPOSTOR,
				MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
				{
					"winner_role": NetworkConfig.PlayerRole.IMPOSTOR,
					"reason": MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED,
					"completed_emergency_systems": ["restore_power"],
					"remaining_meltdown_time": 0.0,
					"impostor_was_alive": true,
					"player_roster": test_roster
				}
			)
		2:
			print("[HUD TEST] Game Over Outcome 3: CREW VICTORY (Impostor Eliminated Prior to Meltdown)")
			var impostor_ejected_roster = test_roster.duplicate(true)
			impostor_ejected_roster[6]["is_alive"] = false
			impostor_ejected_roster[6]["is_eliminated"] = true
			_transition_into_game_over(
				NetworkConfig.PlayerRole.CREW,
				MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
				{
					"winner_role": NetworkConfig.PlayerRole.CREW,
					"reason": MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE,
					"completed_emergency_systems": ["restore_power", "restore_cooling", "stabilize_orion"],
					"remaining_meltdown_time": 218.0,
					"impostor_was_alive": false,
					"player_roster": impostor_ejected_roster
				}
			)

## Returns the TaskChecklistUI instance
func get_task_checklist() -> Control:
	return task_checklist

## Returns the RecoveryTrackerUI instance
func get_recovery_tracker() -> Control:
	return recovery_tracker

## Returns the BlackoutBannerUI instance
func get_blackout_banner() -> Control:
	return blackout_banner

## Returns the MeltdownHUD instance
func get_meltdown_hud() -> Control:
	return meltdown_hud

## Returns the ImpostorHUD instance
func get_impostor_hud() -> Control:
	return impostor_hud

## Returns the MeetingScreen instance
func get_meeting_screen() -> Control:
	return meeting_screen

## Returns the EjectionReveal instance
func get_ejection_reveal() -> Control:
	return ejection_reveal

## Returns the VictoryDefeatScreen instance
func get_victory_defeat_screen() -> Control:
	return victory_defeat_screen

## Returns the ResultScreen instance
func get_result_screen() -> Control:
	return result_screen
