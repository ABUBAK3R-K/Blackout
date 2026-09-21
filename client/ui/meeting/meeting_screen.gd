class_name MeetingScreen
extends Control

## MeetingScreen — Member 5 (UI/UX Frontend)
## Main Meeting & Voting UI for BLACKOUT.
##
## Activated when authoritative game state enters MEETING or VOTING.
## Features:
## 1. Cinematic Emergency Alert entrance sequence (< 2s).
## 2. Discussion Assembly UI with live personnel grid and comms chat.
## 3. Authoritative Voting Phase UI with selectable player cards, dedicated Skip Vote,
##    target preview, and vote confirmation with submitted state.

signal chat_message_sent(text: String)
signal vote_confirmed(target_peer_id: int)

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const EmergencyMeetingAlertUI = preload("res://client/ui/meeting/emergency_meeting_alert.gd")
const VoteTallyUI = preload("res://client/ui/meeting/vote_tally.gd")

## Official 8-Player Department Colors (Asterion Nuclear Research Facility)
const PLAYER_PALETTE: Array[Color] = [
	Color(0.12, 0.35, 0.75), # 1. Navy Blue   (Engineering)
	Color(0.92, 0.40, 0.08), # 2. Safety Orange(Maintenance)
	Color(0.92, 0.72, 0.05), # 3. Hazard Yellow(Radiation Safety)
	Color(0.38, 0.44, 0.52), # 4. Steel Gray   (Technical Operations)
	Color(0.12, 0.65, 0.32), # 5. Lab Green    (Scientific Personnel)
	Color(0.85, 0.18, 0.22), # 6. Emergency Red(Security / Response)
	Color(0.04, 0.62, 0.72), # 7. Electric Cyan(Diagnostics)
	Color(0.88, 0.90, 0.94)  # 8. Cleanroom White(Reactor Physics)
]

## Styling constants
const COLOR_ACTIVE_GREEN: Color = Color(0.20, 0.85, 0.40, 1.0)        # Active / Done Green (#33D966)
const COLOR_EJECTED_RED: Color = Color(0.85, 0.28, 0.28, 1.0)         # Ejected status (#D94747)
const COLOR_SELECTED_BORDER: Color = Color(1.0, 0.35, 0.35, 0.95)     # Vote target active crimson
const COLOR_SELECTED_BG: Color = Color(0.18, 0.11, 0.13, 0.98)        # Vote target selected fill
const COLOR_CARD_ACTIVE_BG: Color = Color(0.10, 0.11, 0.13, 0.95)     # Active card background
const COLOR_CARD_EJECTED_BG: Color = Color(0.07, 0.075, 0.09, 0.65)   # Ejected card background
const COLOR_TIMER_NORMAL: Color = Color(1.0, 0.32, 0.32, 1.0)         # Coral red timer
const COLOR_TIMER_CRITICAL: Color = Color(1.0, 0.15, 0.15, 1.0)       # Flashing critical red

## Sentinel for no selection
const SELECTION_NONE: int = -999

## Node references
@onready var background_overlay: ColorRect = $BackgroundOverlay
@onready var discussion_container: Control = $DiscussionContainer
@onready var header_panel: PanelContainer = $DiscussionContainer/HeaderPanel
@onready var caller_info_label: Label = $DiscussionContainer/HeaderPanel/HBoxContainer/LeftInfo/CallerInfoLabel
@onready var phase_label: Label = $DiscussionContainer/HeaderPanel/HBoxContainer/RightTimer/PhaseLabel
@onready var timer_label: Label = $DiscussionContainer/HeaderPanel/HBoxContainer/RightTimer/TimerRow/TimerLabel

@onready var players_grid: Control = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/PlayersScroll/PlayersGrid
@onready var players_count_label: Label = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/HeaderRow/CountLabel

@onready var voting_controls: VBoxContainer = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/VotingControls
@onready var skip_vote_button: Button = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/VotingControls/SkipVoteButton
@onready var selected_target_label: Label = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/VotingControls/VoteActionBar/SelectedLabel
@onready var confirm_vote_button: Button = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/VotingControls/VoteActionBar/ConfirmVoteButton
@onready var voted_badge: PanelContainer = $DiscussionContainer/MainSplit/LeftSection/VBoxContainer/VotingControls/VoteActionBar/VotedBadge

@onready var chat_messages_container: VBoxContainer = $DiscussionContainer/MainSplit/RightSection/VBoxContainer/ChatScroll/MessagesContainer
@onready var chat_scroll: ScrollContainer = $DiscussionContainer/MainSplit/RightSection/VBoxContainer/ChatScroll
@onready var chat_input: LineEdit = $DiscussionContainer/MainSplit/RightSection/VBoxContainer/InputRow/InputContainer/ChatInput
@onready var char_count_label: Label = $DiscussionContainer/MainSplit/RightSection/VBoxContainer/InputRow/InputContainer/CharCountLabel
@onready var send_button: Button = $DiscussionContainer/MainSplit/RightSection/VBoxContainer/InputRow/SendButton

@onready var status_panel: PanelContainer = $DiscussionContainer/StatusPanel
@onready var status_header_label: Label = $DiscussionContainer/StatusPanel/HBoxContainer/StatusHeader
@onready var status_label: Label = $DiscussionContainer/StatusPanel/HBoxContainer/StatusLabel
@onready var emergency_alert: EmergencyMeetingAlertUI = $EmergencyMeetingAlert
@onready var vote_tally: VoteTallyUI = find_child("VoteTally", true, false) as VoteTallyUI

## Internal state
var _is_meeting_active: bool = false
var _current_phase: MeetingConfig.MeetingPhase = MeetingConfig.MeetingPhase.DISCUSSION
var _caller_peer_id: int = 0
var _remaining_phase_time: float = 0.0
var _is_connected_to_network: bool = false
var _players_data: Array = []
var _local_peer_id: int = 0
var _is_local_eliminated: bool = false

## Voting selection & submission state
var _selected_target_id: int = SELECTION_NONE
var _has_local_voted: bool = false
var _voted_peer_ids: Array[int] = []

var _fade_tween: Tween = null
var _discussion_fade_tween: Tween = null

func _ready() -> void:
	_ensure_node_references()
	_connect_to_network_events()
	
	if send_button != null:
		send_button.pressed.connect(_on_send_pressed)
	if chat_input != null:
		chat_input.text_submitted.connect(_on_chat_submitted)
		chat_input.text_changed.connect(_on_chat_text_changed)
	if skip_vote_button != null:
		skip_vote_button.pressed.connect(_on_skip_vote_clicked)
	if confirm_vote_button != null:
		confirm_vote_button.pressed.connect(_on_confirm_vote_pressed)
	if emergency_alert != null and not emergency_alert.alert_finished.is_connected(_on_emergency_alert_finished):
		emergency_alert.alert_finished.connect(_on_emergency_alert_finished)
	
	visible = false
	modulate.a = 0.0
	if discussion_container != null:
		discussion_container.visible = false
		discussion_container.modulate.a = 0.0

func _ensure_node_references() -> void:
	if background_overlay == null and has_node("BackgroundOverlay"):
		background_overlay = get_node("BackgroundOverlay")
	if discussion_container == null and has_node("DiscussionContainer"):
		discussion_container = get_node("DiscussionContainer")
		
	if header_panel == null:
		header_panel = find_child("HeaderPanel", true, false) as PanelContainer
	if caller_info_label == null:
		caller_info_label = find_child("CallerInfoLabel", true, false) as Label
	if phase_label == null:
		phase_label = find_child("PhaseLabel", true, false) as Label
	if timer_label == null:
		timer_label = find_child("TimerLabel", true, false) as Label
	if players_grid == null:
		players_grid = find_child("PlayersGrid", true, false) as Control
	if players_count_label == null:
		players_count_label = find_child("CountLabel", true, false) as Label
		
	if voting_controls == null:
		voting_controls = find_child("VotingControls", true, false) as VBoxContainer
	if skip_vote_button == null:
		skip_vote_button = find_child("SkipVoteButton", true, false) as Button
	if selected_target_label == null:
		selected_target_label = find_child("SelectedLabel", true, false) as Label
	if confirm_vote_button == null:
		confirm_vote_button = find_child("ConfirmVoteButton", true, false) as Button
	if voted_badge == null:
		voted_badge = find_child("VotedBadge", true, false) as PanelContainer
		
	if chat_messages_container == null:
		chat_messages_container = find_child("MessagesContainer", true, false) as VBoxContainer
	if chat_scroll == null:
		chat_scroll = find_child("ChatScroll", true, false) as ScrollContainer
	if chat_input == null:
		chat_input = find_child("ChatInput", true, false) as LineEdit
	if char_count_label == null:
		char_count_label = find_child("CharCountLabel", true, false) as Label
	if send_button == null:
		send_button = find_child("SendButton", true, false) as Button
	if status_panel == null:
		status_panel = find_child("StatusPanel", true, false) as PanelContainer
	if status_header_label == null:
		status_header_label = find_child("StatusHeader", true, false) as Label
	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label
	if emergency_alert == null and has_node("EmergencyMeetingAlert"):
		emergency_alert = get_node("EmergencyMeetingAlert")
	if emergency_alert != null and not emergency_alert.alert_finished.is_connected(_on_emergency_alert_finished):
		emergency_alert.alert_finished.connect(_on_emergency_alert_finished)
	if vote_tally == null:
		vote_tally = find_child("VoteTally", true, false) as VoteTallyUI

func _process(delta: float) -> void:
	if _is_meeting_active:
		if _remaining_phase_time > 0.0:
			_remaining_phase_time = max(0.0, _remaining_phase_time - delta)
			_update_timer_display()
		elif _remaining_phase_time <= 0.0:
			_remaining_phase_time = 0.0
			_update_timer_display()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_connected_to_server() and event is InputEventKey and event.pressed:
		# Hotkeys for offline testing
		if event.keycode == KEY_V:
			if _current_phase == MeetingConfig.MeetingPhase.DISCUSSION:
				start_voting_phase(MeetingConfig.DEFAULT_VOTING_DURATION_SEC)
			else:
				start_meeting(_caller_peer_id, MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC)
		elif event.keycode == KEY_S and _current_phase == MeetingConfig.MeetingPhase.VOTING:
			_on_skip_vote_clicked()
		elif event.keycode == KEY_C and _current_phase == MeetingConfig.MeetingPhase.VOTING:
			_on_confirm_vote_pressed()
		elif event.keycode == KEY_P and _current_phase == MeetingConfig.MeetingPhase.VOTING:
			_simulate_peer_vote()
		elif event.keycode == KEY_T:
			if vote_tally != null and vote_tally.visible:
				vote_tally.hide_tally()
			else:
				show_results_overlay({
					"votes_per_target": {102: 2, 104: 1},
					"skip_count": 1,
					"total_votes_cast": 4
				})

func _is_connected_to_server() -> bool:
	if is_inside_tree() and has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			return net_mgr.client.is_connected_to_server()
	return false

func _connect_to_network_events() -> void:
	if is_inside_tree() and has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("meeting_started") and not client.meeting_started.is_connected(_on_meeting_started):
				client.meeting_started.connect(_on_meeting_started)
			if client.has_signal("voting_started") and not client.voting_started.is_connected(_on_voting_started):
				client.voting_started.connect(_on_voting_started)
			if client.has_signal("player_voted") and not client.player_voted.is_connected(_on_player_voted):
				client.player_voted.connect(_on_player_voted)
			if client.has_signal("game_state_changed") and not client.game_state_changed.is_connected(_on_game_state_changed):
				client.game_state_changed.connect(_on_game_state_changed)
			if client.has_signal("lobby_synced") and not client.lobby_synced.is_connected(_on_lobby_synced):
				client.lobby_synced.connect(_on_lobby_synced)
			if client.has_signal("vote_result_received") and not client.vote_result_received.is_connected(_on_vote_result_received):
				client.vote_result_received.connect(_on_vote_result_received)
			_is_connected_to_network = true
			
			if _is_connected_to_server():
				_local_peer_id = client.assigned_peer_id
				_is_local_eliminated = client.is_eliminated
				_has_local_voted = client.has_voted_this_round
				if client.is_meeting_active:
					set_players(client.lobby_players_data)
					if client.current_meeting_phase == MeetingConfig.MeetingPhase.VOTING:
						start_voting_phase(client.voting_remaining_duration)
					else:
						start_meeting(client.meeting_caller_id, client.discussion_remaining_duration)

func _on_meeting_started(caller_id: int, discussion_duration: float) -> void:
	if is_inside_tree() and has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			set_players(net_mgr.client.lobby_players_data)
			_local_peer_id = net_mgr.client.assigned_peer_id
			_is_local_eliminated = net_mgr.client.is_eliminated
	start_meeting(caller_id, discussion_duration)

func _on_voting_started(voting_duration: float) -> void:
	start_voting_phase(voting_duration)

func _on_player_voted(voter_peer_id: int) -> void:
	if not _voted_peer_ids.has(voter_peer_id):
		_voted_peer_ids.append(voter_peer_id)
		
	if voter_peer_id == _local_peer_id:
		_has_local_voted = true
		_update_voting_action_bar()
		
	if vote_tally != null:
		vote_tally.record_player_voted(voter_peer_id)
		
	_rebuild_players_grid()
	_update_footer_status()

func _on_lobby_synced(_state: int, _player_count: int, _ready_count: int, players_info: Array) -> void:
	set_players(players_info)

func _on_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.MEETING:
		if not _is_meeting_active:
			start_meeting(0, MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC)
	elif new_state == NetworkConfig.GameState.VOTING:
		if not _is_meeting_active or _current_phase != MeetingConfig.MeetingPhase.VOTING:
			start_voting_phase(MeetingConfig.DEFAULT_VOTING_DURATION_SEC)
	elif new_state != NetworkConfig.GameState.VOTING:
		if _is_meeting_active:
			end_meeting(true)

func _on_vote_result_received(result: Dictionary) -> void:
	show_results_overlay(result)

## Public API to start the emergency meeting sequence (Discussion Phase)
func start_meeting(caller_peer_id: int, discussion_duration: float) -> void:
	_ensure_node_references()
	_is_meeting_active = true
	_current_phase = MeetingConfig.MeetingPhase.DISCUSSION
	_caller_peer_id = caller_peer_id
	_remaining_phase_time = max(0.0, discussion_duration)
	_selected_target_id = SELECTION_NONE
	_has_local_voted = false
	_voted_peer_ids.clear()
	
	if _players_data.is_empty():
		_populate_offline_preview_players()
		
	if vote_tally != null:
		vote_tally.visible = false
		vote_tally.reset_tally()
		vote_tally.set_players(_players_data, _local_peer_id)
		
	_rebuild_players_grid()
	_update_header_info()
	_update_timer_display()
	_update_phase_ui()
	
	visible = true
	modulate.a = 1.0
	
	# Discussion assembly UI hidden while Alert banner plays
	if discussion_container != null:
		discussion_container.visible = false
		discussion_container.modulate.a = 0.0
		
	if background_overlay != null:
		background_overlay.modulate.a = 0.6
	
	# Trigger Emergency Meeting Alert entrance notification
	if emergency_alert != null:
		emergency_alert.trigger_alert(caller_peer_id)
	else:
		_reveal_discussion_ui()

## Public API to transition into authoritative Voting Phase
func start_voting_phase(voting_duration: float) -> void:
	_ensure_node_references()
	_is_meeting_active = true
	_current_phase = MeetingConfig.MeetingPhase.VOTING
	_remaining_phase_time = max(0.0, voting_duration)
	_selected_target_id = SELECTION_NONE
	
	if _players_data.is_empty():
		_populate_offline_preview_players()
		
	if vote_tally != null:
		vote_tally.visible = false
		vote_tally.set_players(_players_data, _local_peer_id)
		
	_update_header_info()
	_update_timer_display()
	_update_phase_ui()
	_rebuild_players_grid()
	_update_voting_action_bar()
	_update_footer_status()
	
	visible = true
	modulate.a = 1.0
	if discussion_container != null:
		discussion_container.visible = true
		discussion_container.modulate.a = 1.0

## Callback when the Emergency Meeting Alert finishes
func _on_emergency_alert_finished() -> void:
	if _is_meeting_active:
		_reveal_discussion_ui()

## Smoothly reveals the Main Discussion / Voting UI
func _reveal_discussion_ui() -> void:
	_ensure_node_references()
	if discussion_container == null:
		return
		
	discussion_container.visible = true
	if _discussion_fade_tween and _discussion_fade_tween.is_valid():
		_discussion_fade_tween.kill()
		
	_discussion_fade_tween = create_tween().set_parallel(true)
	if background_overlay != null:
		_discussion_fade_tween.tween_property(background_overlay, "modulate:a", 1.0, 0.35)
	_discussion_fade_tween.tween_property(discussion_container, "modulate:a", 1.0, 0.35).from(0.0)

## Public API to dismiss/hide the meeting screen
func end_meeting(animated: bool = true) -> void:
	_is_meeting_active = false
	_remaining_phase_time = 0.0
	_selected_target_id = SELECTION_NONE
	
	if emergency_alert != null:
		emergency_alert.dismiss_alert(true)
		
	if _discussion_fade_tween and _discussion_fade_tween.is_valid():
		_discussion_fade_tween.kill()
		
	if animated:
		if _fade_tween and _fade_tween.is_valid():
			_fade_tween.kill()
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		_fade_tween.tween_callback(func():
			visible = false
			if discussion_container != null:
				discussion_container.visible = false
				discussion_container.modulate.a = 0.0
		)
	else:
		visible = false
		modulate.a = 0.0
		if discussion_container != null:
			discussion_container.visible = false
			discussion_container.modulate.a = 0.0

## Updates authoritative players list
func set_players(players_array: Array) -> void:
	_players_data.clear()
	for p in players_array:
		if p is Dictionary:
			_players_data.append(p.duplicate())
		elif p != null and p.has_method("to_dict"):
			_players_data.append(p.to_dict())
	if vote_tally != null:
		vote_tally.set_players(_players_data, _local_peer_id)
	_rebuild_players_grid()

## Updates phase header, timer mode, and voting controls visibility
func _update_phase_ui() -> void:
	_ensure_node_references()
	if phase_label != null:
		if _current_phase == MeetingConfig.MeetingPhase.VOTING:
			phase_label.text = "VOTING PHASE"
			phase_label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)
		else:
			phase_label.text = "DISCUSSION PHASE"
			phase_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 0.85))
			
	if voting_controls != null:
		voting_controls.visible = (_current_phase == MeetingConfig.MeetingPhase.VOTING)
		
	if vote_tally != null and _current_phase != MeetingConfig.MeetingPhase.RESULTS:
		vote_tally.visible = false

## Rebuilds the player cards list
func _rebuild_players_grid() -> void:
	_ensure_node_references()
	if players_grid == null:
		return
		
	for child in players_grid.get_children():
		players_grid.remove_child(child)
		child.queue_free()
		
	var active_count: int = 0
	var total_count: int = _players_data.size()
	var voted_count: int = _voted_peer_ids.size()
	
	for p in _players_data:
		var peer_id = int(p.get("peer_id", 0))
		var slot = int(p.get("player_slot", 1))
		var is_active = not bool(p.get("is_eliminated", false)) and bool(p.get("is_alive", true))
		var has_voted = _voted_peer_ids.has(peer_id)
		var is_selected = (_selected_target_id == peer_id)
		
		if is_active:
			active_count += 1
			
		var card = _create_player_card(peer_id, slot, is_active, has_voted, is_selected)
		players_grid.add_child(card)
		
	if players_count_label != null:
		if _current_phase == MeetingConfig.MeetingPhase.VOTING:
			players_count_label.text = "%d / %d VOTED" % [voted_count, active_count]
		else:
			players_count_label.text = "%d / %d ACTIVE" % [active_count, total_count]
			
	_update_skip_button_style()

## Creates a polished player card (with voting selection in Voting Phase)
func _create_player_card(peer_id: int, slot: int, is_active: bool, has_voted: bool, is_selected: bool) -> Control:
	var is_voting_mode = (_current_phase == MeetingConfig.MeetingPhase.VOTING)
	var can_vote_for = is_voting_mode and is_active and not _has_local_voted and not _is_local_eliminated
	
	var card: Control
	if can_vote_for:
		card = Button.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(func(): _on_player_card_clicked(peer_id))
	else:
		card = PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		
	card.custom_minimum_size = Vector2(0, 56)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Styling
	var style_normal = StyleBoxFlat.new()
	style_normal.content_margin_left = 12.0
	style_normal.content_margin_right = 16.0
	style_normal.content_margin_top = 8.0
	style_normal.content_margin_bottom = 8.0
	style_normal.set_corner_radius_all(6)
	
	if is_selected:
		style_normal.bg_color = COLOR_SELECTED_BG
		style_normal.set_border_width_all(2)
		style_normal.border_color = COLOR_SELECTED_BORDER
		style_normal.shadow_color = Color(1, 0.28, 0.3, 0.35)
		style_normal.shadow_size = 4
	elif is_active:
		style_normal.bg_color = COLOR_CARD_ACTIVE_BG
		style_normal.set_border_width_all(1)
		style_normal.border_color = Color(0.22, 0.25, 0.30, 0.45)
	else:
		style_normal.bg_color = COLOR_CARD_EJECTED_BG
		style_normal.set_border_width_all(1)
		style_normal.border_color = Color(0.18, 0.19, 0.22, 0.25)
		
	if card is Button:
		card.add_theme_stylebox_override("normal", style_normal)
		var style_hover = style_normal.duplicate()
		style_hover.border_color = Color(1.0, 0.55, 0.55, 0.85) if is_selected else Color(0.45, 0.50, 0.60, 0.85)
		card.add_theme_stylebox_override("hover", style_hover)
		card.add_theme_stylebox_override("pressed", style_normal)
	else:
		(card as PanelContainer).add_theme_stylebox_override("panel", style_normal)
		
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	# 1. Stylized Astronaut Avatar Placeholder (2D Drawing with Suit Color & Visor)
	var avatar = _create_astronaut_avatar(slot, is_active)
	avatar.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(avatar)
	
	# 2. Player Details (Name + Status Subtitle)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var name_lbl = Label.new()
	var you_suffix = " (You)" if peer_id == _local_peer_id and _local_peer_id > 0 else ""
	name_lbl.text = "Player %d%s" % [peer_id if peer_id > 0 else slot, you_suffix]
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98, 1.0) if is_active else Color(0.50, 0.52, 0.56, 0.70))
	vbox.add_child(name_lbl)
	
	var status_lbl = Label.new()
	if is_selected:
		status_lbl.text = "★ VOTE TARGET"
		status_lbl.add_theme_color_override("font_color", COLOR_SELECTED_BORDER)
	elif not is_active:
		status_lbl.text = "• Ejected"
		status_lbl.add_theme_color_override("font_color", COLOR_EJECTED_RED)
	elif has_voted:
		status_lbl.text = "✓ Voted"
		status_lbl.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
	else:
		status_lbl.text = "• Active"
		status_lbl.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
	status_lbl.add_theme_font_size_override("font_size", 11)
	vbox.add_child(status_lbl)
	
	hbox.add_child(vbox)
	
	# 3. Slot badge or Voted Check badge on right
	if is_voting_mode and has_voted:
		var voted_icon = Label.new()
		voted_icon.text = "✓"
		voted_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		voted_icon.add_theme_font_size_override("font_size", 16)
		voted_icon.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
		hbox.add_child(voted_icon)
	else:
		var slot_lbl = Label.new()
		slot_lbl.text = "P%d" % slot
		slot_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot_lbl.add_theme_font_size_override("font_size", 13)
		slot_lbl.add_theme_color_override("font_color", Color(0.45, 0.48, 0.55, 0.70) if is_active else Color(0.35, 0.38, 0.42, 0.50))
		hbox.add_child(slot_lbl)
		
	card.add_child(hbox)
	return card

## Checks whether a target peer is an active, non-eliminated player
func _is_target_active(peer_id: int) -> bool:
	for p in _players_data:
		if int(p.get("peer_id", 0)) == peer_id:
			return not bool(p.get("is_eliminated", false)) and bool(p.get("is_alive", true))
	return false

## Handles player card click selection
func _on_player_card_clicked(peer_id: int) -> void:
	if _current_phase != MeetingConfig.MeetingPhase.VOTING or _has_local_voted or _is_local_eliminated:
		return
		
	# Authoritative rule: Cannot vote for eliminated/dead players
	if not _is_target_active(peer_id):
		return
		
	if _selected_target_id == peer_id:
		_selected_target_id = SELECTION_NONE
	else:
		_selected_target_id = peer_id
		
	_rebuild_players_grid()
	_update_voting_action_bar()

## Handles skip vote click selection
func _on_skip_vote_clicked() -> void:
	if _current_phase != MeetingConfig.MeetingPhase.VOTING or _has_local_voted or _is_local_eliminated:
		return
		
	if _selected_target_id == MeetingConfig.VOTE_SKIP:
		_selected_target_id = SELECTION_NONE
	else:
		_selected_target_id = MeetingConfig.VOTE_SKIP
		
	_rebuild_players_grid()
	_update_voting_action_bar()

## Updates Skip Vote button visual state
func _update_skip_button_style() -> void:
	if skip_vote_button == null:
		return
		
	var is_skip_selected = (_selected_target_id == MeetingConfig.VOTE_SKIP)
	var is_disabled = _has_local_voted or _is_local_eliminated
	
	skip_vote_button.disabled = is_disabled
	
	if is_skip_selected:
		var style_sel = StyleBoxFlat.new()
		style_sel.content_margin_left = 14.0
		style_sel.content_margin_right = 14.0
		style_sel.content_margin_top = 8.0
		style_sel.content_margin_bottom = 8.0
		style_sel.bg_color = COLOR_SELECTED_BG
		style_sel.set_border_width_all(2)
		style_sel.border_color = COLOR_SELECTED_BORDER
		style_sel.set_corner_radius_all(6)
		skip_vote_button.add_theme_stylebox_override("normal", style_sel)
		skip_vote_button.text = "★  SKIP VOTE (SELECTED)"
	else:
		var style_norm = StyleBoxFlat.new()
		style_norm.content_margin_left = 14.0
		style_norm.content_margin_right = 14.0
		style_norm.content_margin_top = 8.0
		style_norm.content_margin_bottom = 8.0
		style_norm.bg_color = Color(0.09, 0.095, 0.11, 0.95)
		style_norm.set_border_width_all(1)
		style_norm.border_color = Color(0.3, 0.33, 0.4, 0.55)
		style_norm.set_corner_radius_all(6)
		skip_vote_button.add_theme_stylebox_override("normal", style_norm)
		skip_vote_button.text = "⏭  SKIP VOTE"

## Updates target label, confirmation button, and submitted badge
func _update_voting_action_bar() -> void:
	_ensure_node_references()
	if selected_target_label == null or confirm_vote_button == null:
		return
		
	if _has_local_voted:
		selected_target_label.text = "VOTE RECORDED"
		selected_target_label.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
		confirm_vote_button.visible = false
		if voted_badge != null:
			voted_badge.visible = true
	elif _is_local_eliminated:
		selected_target_label.text = "ELIMINATED - CANNOT VOTE"
		selected_target_label.add_theme_color_override("font_color", COLOR_EJECTED_RED)
		confirm_vote_button.visible = true
		confirm_vote_button.disabled = true
		if voted_badge != null:
			voted_badge.visible = false
	else:
		if voted_badge != null:
			voted_badge.visible = false
		confirm_vote_button.visible = true
		
		if _selected_target_id == SELECTION_NONE:
			selected_target_label.text = "TARGET: NONE"
			selected_target_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75, 0.85))
			confirm_vote_button.disabled = true
		elif _selected_target_id == MeetingConfig.VOTE_SKIP:
			selected_target_label.text = "TARGET: SKIP VOTE"
			selected_target_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40, 1.0))
			confirm_vote_button.disabled = false
		else:
			selected_target_label.text = "TARGET: PLAYER %d" % _selected_target_id
			selected_target_label.add_theme_color_override("font_color", COLOR_SELECTED_BORDER)
			confirm_vote_button.disabled = false

## Submits vote via authoritative NetworkManager client
func _on_confirm_vote_pressed() -> void:
	if _selected_target_id == SELECTION_NONE or _has_local_voted or _is_local_eliminated:
		return
		
	var target_to_cast = _selected_target_id
	var target_name = "SKIP" if target_to_cast == MeetingConfig.VOTE_SKIP else "Player %d" % target_to_cast
	print("[MEETING UI] Confirming and submitting vote for: %s" % target_name)
	
	if is_inside_tree() and has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			net_mgr.client.request_cast_vote(target_to_cast)
			
	# Update local state immediately
	_has_local_voted = true
	if _local_peer_id > 0:
		if not _voted_peer_ids.has(_local_peer_id):
			_voted_peer_ids.append(_local_peer_id)
		if vote_tally != null:
			vote_tally.record_player_voted(_local_peer_id)
		
	vote_confirmed.emit(target_to_cast)
	_rebuild_players_grid()
	_update_voting_action_bar()
	_update_footer_status()

## Updates footer text based on current phase and vote status
func _update_footer_status() -> void:
	_ensure_node_references()
	if status_header_label == null or status_label == null:
		return
		
	if _current_phase == MeetingConfig.MeetingPhase.VOTING:
		if _has_local_voted:
			status_header_label.text = "VOTE RECORDED"
			status_label.text = "Your vote has been submitted. Awaiting remaining crew members to complete voting."
		elif _is_local_eliminated:
			status_header_label.text = "SPECTATING"
			status_label.text = "You are eliminated. You may observe comms and voting progress."
		else:
			status_header_label.text = "VOTING IN PROGRESS"
			status_label.text = "Select a facility personnel card or choose Skip Vote, then press Confirm Vote."
	else:
		status_header_label.text = "DISCUSSION IN PROGRESS"
		status_label.text = "Exchange intelligence with active crew members. Voting phase will commence shortly."

## Creates a 2D Nuclear Facility Technician mini avatar badge
func _create_astronaut_avatar(slot: int, is_active: bool) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(40, 40)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var color_index = clampi(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	var suit_color = PLAYER_PALETTE[color_index]
	if not is_active:
		suit_color = suit_color.darkened(0.55)
		
	var canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func(): _draw_avatar_canvas(canvas, suit_color, is_active))
	root.add_child(canvas)
	
	return root

func _draw_avatar_canvas(canvas: Control, base_color: Color, is_active: bool) -> void:
	var w = canvas.size.x
	var h = canvas.size.y
	var cx = w * 0.5
	var cy = h * 0.5
	
	# Background containment badge
	canvas.draw_circle(Vector2(cx, cy), 19.0, Color(0.05, 0.055, 0.065, 0.95))
	canvas.draw_arc(Vector2(cx, cy), 19.0, 0, TAU, 24, Color(0.20, 0.22, 0.26, 0.6), 1.0)
	
	# Mini Tactical Vest Collar Snippet
	var collar_rect = Rect2(cx - 13, cy + 5, 26, 11)
	_draw_rounded_box(canvas, collar_rect, 3.0, Color(0.12, 0.15, 0.20, 1.0), true)
	if is_active:
		# Hazard stripe & Dosimeter pip
		canvas.draw_rect(Rect2(cx + 4, cy + 7, 7, 3), Color(0.95, 0.75, 0.10, 1.0), true)
		canvas.draw_circle(Vector2(cx - 7, cy + 9), 1.2, Color(0.2, 0.95, 0.4, 1.0))
	
	# Industrial Protective Helmet
	var helmet_rect = Rect2(cx - 12, cy - 15, 24, 20)
	var helmet_col = base_color if is_active else base_color.darkened(0.3)
	_draw_rounded_box(canvas, helmet_rect, 9.0, helmet_col, true)
	
	# Helmet Crown Ridge
	var ridge_rect = Rect2(cx - 3, cy - 16, 6, 8)
	_draw_rounded_box(canvas, ridge_rect, 2.0, helmet_col.lightened(0.2), true)
	_draw_rounded_box(canvas, helmet_rect, 9.0, Color(0.02, 0.03, 0.05, 0.95), false, 1.5)
	
	# Comm headset side tabs
	canvas.draw_rect(Rect2(cx - 14, cy - 8, 3, 8), Color(0.08, 0.10, 0.14, 1.0), true)
	canvas.draw_rect(Rect2(cx + 11, cy - 8, 3, 8), Color(0.08, 0.10, 0.14, 1.0), true)
	
	# Narrow Protective Face Shield / Visor
	var visor_center = Vector2(cx, cy - 5)
	var visor_rx = 9.0
	var visor_ry = 4.5
	var visor_col = Color(0.15, 0.65, 0.85, 0.95) if is_active else Color(0.20, 0.35, 0.45, 0.65)
	_draw_ellipse(canvas, visor_center, visor_rx + 1.0, visor_ry + 1.0, Color(0.02, 0.03, 0.05, 0.95))
	_draw_ellipse(canvas, visor_center, visor_rx, visor_ry, Color(0.08, 0.12, 0.18, 1.0))
	_draw_ellipse(canvas, Vector2(visor_center.x, visor_center.y + 0.5), visor_rx - 1.0, visor_ry - 1.0, visor_col)
	
	if is_active:
		_draw_ellipse(canvas, Vector2(visor_center.x + 2.5, visor_center.y - 1.0), 3.0, 1.2, Color(1, 1, 1, 0.85))
		
	# Half-Respirator Filter Unit
	var resp_rect = Rect2(cx - 8, cy - 1, 16, 8)
	_draw_rounded_box(canvas, resp_rect, 3.0, Color(0.16, 0.20, 0.26, 1.0), true)
	_draw_rounded_box(canvas, resp_rect, 3.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.0)
	
	# Twin Mini Filter Pips
	canvas.draw_circle(Vector2(cx - 4.5, cy + 3), 2.0, Color(0.25, 0.30, 0.38, 1.0))
	canvas.draw_circle(Vector2(cx + 4.5, cy + 3), 2.0, Color(0.25, 0.30, 0.38, 1.0))
	
	if not is_active:
		# Red Ejection Cross over Avatar
		var x_col = Color(1.0, 0.25, 0.25, 0.95)
		canvas.draw_line(Vector2(cx - 10, cy - 10), Vector2(cx + 10, cy + 10), x_col, 2.5)
		canvas.draw_line(Vector2(cx + 10, cy - 10), Vector2(cx - 10, cy + 10), x_col, 2.5)

func _draw_rounded_box(canvas: Control, rect: Rect2, radius: float, color: Color, filled: bool = true, line_width: float = 2.0) -> void:
	var pts = PackedVector2Array()
	var r = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var corners = [
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r)
	]
	for i in range(4):
		var center = corners[i]
		var start_angle = float(i) * (PI * 0.5) + PI
		for j in range(6):
			var a = start_angle + (float(j) / 5.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	pts.append(pts[0])
	if filled:
		canvas.draw_colored_polygon(pts, color)
	else:
		canvas.draw_polyline(pts, color, line_width)

func _draw_ellipse(canvas: Control, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts = PackedVector2Array()
	var segments = 20
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(pts, color)

## Chat Handlers
func _on_send_pressed() -> void:
	_submit_chat_input()

func _on_chat_submitted(_text: String) -> void:
	_submit_chat_input()

func _on_chat_text_changed(new_text: String) -> void:
	if char_count_label != null:
		char_count_label.text = "%d/200" % new_text.length()

func _submit_chat_input() -> void:
	_ensure_node_references()
	if chat_input == null:
		return
	var text = chat_input.text.strip_edges()
	if text.is_empty():
		return
		
	var sender_name = "Player %d (You)" % (_local_peer_id if _local_peer_id > 0 else 1)
	add_chat_message(sender_name, text, Color(1.0, 0.32, 0.35, 1.0))
	chat_message_sent.emit(text)
	chat_input.text = ""
	if char_count_label != null:
		char_count_label.text = "0/200"

## Adds a message block matching the concept image (Sender + Timestamp on top, Message below)
func add_chat_message(sender_name: String, message: String, sender_color: Color = Color(1.0, 0.32, 0.35, 1.0), timestamp: String = "") -> void:
	_ensure_node_references()
	if chat_messages_container == null:
		return
		
	if timestamp.is_empty():
		var dt = Time.get_time_dict_from_system()
		var hour = dt.get("hour", 8)
		var minute = dt.get("minute", 0)
		var ampm = "AM" if hour < 12 else "PM"
		var disp_hour = hour % 12
		if disp_hour == 0:
			disp_hour = 12
		timestamp = "%d:%02d %s" % [disp_hour, minute, ampm]
		
	var msg_block = VBoxContainer.new()
	msg_block.add_theme_constant_override("separation", 2)
	msg_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Top Row: Sender Name + Timestamp
	var top_row = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var sender_lbl = Label.new()
	sender_lbl.text = sender_name
	sender_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sender_lbl.add_theme_font_size_override("font_size", 12)
	sender_lbl.add_theme_color_override("font_color", sender_color)
	top_row.add_child(sender_lbl)
	
	var time_lbl = Label.new()
	time_lbl.text = timestamp
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", Color(0.50, 0.54, 0.60, 0.70))
	top_row.add_child(time_lbl)
	msg_block.add_child(top_row)
	
	# Message Text
	var msg_lbl = Label.new()
	msg_lbl.text = message
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_lbl.add_theme_font_size_override("font_size", 12)
	msg_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 0.95))
	msg_block.add_child(msg_lbl)
	
	chat_messages_container.add_child(msg_block)
	
	# Scroll to bottom
	call_deferred("_scroll_chat_to_bottom")

func _scroll_chat_to_bottom() -> void:
	if chat_scroll != null:
		chat_scroll.scroll_vertical = int(chat_scroll.get_v_scroll_bar().max_value)

## Updates remaining phase time
func set_phase_time(seconds: float) -> void:
	_remaining_phase_time = max(0.0, seconds)
	_update_timer_display()

## Returns whether the meeting screen is active
func is_meeting_open() -> bool:
	return _is_meeting_active

## Returns the current meeting phase
func get_current_phase() -> MeetingConfig.MeetingPhase:
	return _current_phase

## Returns the currently selected vote target
func get_selected_target() -> int:
	return _selected_target_id

## Returns whether the local player has voted
func has_local_voted() -> bool:
	return _has_local_voted

## Returns the EmergencyMeetingAlert instance
func get_emergency_alert() -> EmergencyMeetingAlertUI:
	return emergency_alert

## Returns the VoteTallyUI instance
func get_vote_tally() -> VoteTallyUI:
	return vote_tally

## Shows the authoritative Vote Results / Tally modal overlay on top of the meeting screen
func show_results_overlay(result_data: Dictionary = {}) -> void:
	_ensure_node_references()
	_current_phase = MeetingConfig.MeetingPhase.RESULTS
	if vote_tally != null:
		if not result_data.is_empty():
			vote_tally.set_authoritative_tally(
				result_data.get("votes_per_target", {}),
				int(result_data.get("skip_count", 0)),
				int(result_data.get("total_votes_cast", 0))
			)
		vote_tally.set_voting_complete(true)
		vote_tally.reveal_tally()

## Sets authoritative vote tally breakdown on the VoteTallyUI
func set_authoritative_tally(votes_per_target: Dictionary, skip_votes: int, total_votes_cast: int = -1, leader_peer_id: int = 0) -> void:
	if vote_tally != null:
		vote_tally.set_authoritative_tally(votes_per_target, skip_votes, total_votes_cast, leader_peer_id)

## Formats float seconds into 'MM:SS' string format
static func format_time(seconds: float) -> String:
	if is_nan(seconds) or seconds < 0.0:
		return "00:00"
	var total_sec: int = int(ceil(max(0.0, seconds)))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]

func _update_header_info() -> void:
	if caller_info_label != null:
		if _caller_peer_id > 0:
			caller_info_label.text = "Initiator: Player %d (Emergency Button)" % _caller_peer_id
		else:
			caller_info_label.text = "Initiator: Emergency System Trigger"

func _update_timer_display() -> void:
	if timer_label == null:
		return
		
	timer_label.text = format_time(_remaining_phase_time)
	
	if _remaining_phase_time <= 10.0 and _remaining_phase_time > 0.0:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_CRITICAL)
	elif _remaining_phase_time <= 0.0:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_CRITICAL)
	else:
		timer_label.add_theme_color_override("font_color", COLOR_TIMER_NORMAL)

## Standalone preview helpers
func _populate_offline_preview_players() -> void:
	_local_peer_id = 1
	_players_data = [
		{"peer_id": 1, "player_slot": 1, "is_alive": true, "is_eliminated": false},
		{"peer_id": 2, "player_slot": 2, "is_alive": true, "is_eliminated": false},
		{"peer_id": 3, "player_slot": 3, "is_alive": true, "is_eliminated": false},
		{"peer_id": 4, "player_slot": 4, "is_alive": false, "is_eliminated": true}
	]

func _populate_offline_preview() -> void:
	_populate_offline_preview_players()
	start_meeting(2, 134.0)
	add_chat_message("Player 2", "I was fixing power in Generator.", Color(0.12, 0.53, 0.90), "8:14 PM")
	add_chat_message("Player 4", "Confirmed, I saw Player 2 there.", Color(0.99, 0.85, 0.21), "8:14 PM")
	add_chat_message("Player 1 (You)", "Let's review the evidence carefully.", Color(1.0, 0.32, 0.35), "8:15 PM")

func _simulate_peer_vote() -> void:
	for p in _players_data:
		var pid = int(p.get("peer_id", 0))
		var is_act = not bool(p.get("is_eliminated", false)) and bool(p.get("is_alive", true))
		if is_act and not _voted_peer_ids.has(pid):
			_on_player_voted(pid)
			return

func _toggle_offline_meeting() -> void:
	if _is_meeting_active:
		end_meeting(true)
	else:
		_populate_offline_preview()
