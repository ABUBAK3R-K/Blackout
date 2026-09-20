class_name InGameHUD
extends CanvasLayer

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const TaskChecklistUI = preload("res://client/ui/hud/task_checklist.gd")
const RecoveryTrackerUI = preload("res://client/ui/hud/recovery_tracker.gd")
const BlackoutBannerUI = preload("res://client/ui/hud/blackout_banner.gd")
const MeltdownHUDUI = preload("res://client/ui/hud/meltdown_hud.gd")
const ImpostorHUDUI = preload("res://client/ui/hud/impostor_hud.gd")
const MeetingScreenUI = preload("res://client/ui/meeting/meeting_screen.gd")

@onready var task_checklist: Control = $TaskChecklist
@onready var recovery_tracker: Control = $RecoveryTracker
@onready var blackout_banner: Control = $BlackoutBanner
@onready var meltdown_hud: Control = $MeltdownHUD
@onready var impostor_hud: Control = $ImpostorHUD
@onready var meeting_screen: Control = $MeetingScreen

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
	print("    [Tab] or [E]   : Toggle Sabotage Action Wheel (Impostor only)")
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

func _connect_to_network_events() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("meeting_started") and not client.meeting_started.is_connected(_on_meeting_started):
				client.meeting_started.connect(_on_meeting_started)
			if client.has_signal("voting_started") and not client.voting_started.is_connected(_on_voting_started):
				client.voting_started.connect(_on_voting_started)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)

func _on_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	_transition_into_meeting(caller_peer_id, discussion_duration)

func _on_voting_started(voting_duration: float) -> void:
	_transition_into_voting(voting_duration)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.MEETING:
		if meeting_screen != null and not meeting_screen.is_meeting_open():
			_transition_into_meeting(0, 30.0)
	elif new_state == NetworkConfig.GameState.VOTING:
		if meeting_screen != null:
			_transition_into_voting(30.0)
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
			print("[HUD TEST] Reset HUD to default preview state")

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
