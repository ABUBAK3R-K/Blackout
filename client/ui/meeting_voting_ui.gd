class_name MeetingVotingUI
extends Control

## Client-side In-Game Meeting & Voting Screen / Overlay for BLACKOUT.
## Coordinates the discussion phase, live countdown timers, interactive voting roster,
## vote submission with feedback, server-authoritative results display, and player control locking.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")
const PlayerController = preload("res://client/player/player_controller.gd")

signal meeting_opened(caller_peer_id: int, discussion_duration: float)
signal voting_phase_entered(voting_duration: float)
signal local_vote_submitted(target_peer_id: int)
signal meeting_closed()

## Current phase of the active meeting overlay.
var current_phase: MeetingConfig.MeetingPhase = MeetingConfig.MeetingPhase.NONE

## Active countdown timer in seconds.
var current_timer_remaining: float = 0.0

## Caller peer ID for the current meeting session.
var current_caller_peer_id: int = 0

## Local client identity and state.
var local_peer_id: int = 0
var local_slot_id: int = 1
var is_local_eliminated: bool = false
var has_voted_locally: bool = false
var selected_vote_target: int = MeetingConfig.VOTE_SKIP

## Tracked real players: Array of Dictionaries [ { "peer_id": int, "slot_id": int, "name": String, "is_alive": bool } ]
var tracked_roster: Array[Dictionary] = []

## Set of peer IDs that have submitted votes this session: { peer_id (int) -> bool }
var voted_peer_ids: Dictionary = {}

## Set of eliminated peer IDs: { peer_id (int) -> bool }
var eliminated_peer_ids: Dictionary = {}

## Reference to the local PlayerController for input locking.
var local_player: PlayerController = null

## UI Node references
var main_panel: PanelContainer = null
var title_label: Label = null
var subtitle_label: Label = null
var phase_badge: Label = null
var timer_label: Label = null
var timer_progress: ProgressBar = null
var roster_container: GridContainer = null
var skip_button: Button = null
var status_feedback_label: Label = null
var results_panel: PanelContainer = null
var results_title_label: Label = null
var results_detail_label: Label = null
var results_tally_label: Label = null

## Dictionary of player card UI references: { peer_id (int) -> Dictionary }
var player_card_nodes: Dictionary = {}

## Results auto-dismiss timer.
var results_dismiss_timer: float = 0.0
var is_showing_results: bool = false

func _ready() -> void:
	visible = false
	_ensure_ui_structure()
	_auto_discover_player()
	_auto_connect_network_signals()

func _process(delta: float) -> void:
	if not visible:
		return

	# 1. Active discussion/voting countdown timer
	if current_phase == MeetingConfig.MeetingPhase.DISCUSSION or current_phase == MeetingConfig.MeetingPhase.VOTING:
		if current_timer_remaining > 0.0:
			current_timer_remaining = max(0.0, current_timer_remaining - delta)
			_update_timer_display()

	# 2. Results presentation auto-dismiss countdown
	if is_showing_results and results_dismiss_timer > 0.0:
		results_dismiss_timer -= delta
		if results_dismiss_timer <= 0.0:
			is_showing_results = false
			close_meeting()

## Registers the local player controller instance for input management.
func register_local_player(player: PlayerController) -> void:
	local_player = player
	if player != null:
		local_slot_id = player.slot_id

## Automatically discovers the local PlayerController in the scene tree.
func _auto_discover_player() -> void:
	if local_player != null:
		return
	var root = get_tree().current_scene if (is_inside_tree() and get_tree().current_scene != null) else get_parent()
	if root != null:
		var p = root.get_node_or_null("Player")
		if p is PlayerController:
			register_local_player(p)

## Connects to NetworkManager client signals if present in the scene tree.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for meeting lifecycle events.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("meeting_started") and not client_mgr.meeting_started.is_connected(_on_network_meeting_started):
		client_mgr.meeting_started.connect(_on_network_meeting_started)

	if client_mgr.has_signal("voting_started") and not client_mgr.voting_started.is_connected(_on_network_voting_started):
		client_mgr.voting_started.connect(_on_network_voting_started)

	if client_mgr.has_signal("player_voted") and not client_mgr.player_voted.is_connected(_on_network_player_voted):
		client_mgr.player_voted.connect(_on_network_player_voted)

	if client_mgr.has_signal("vote_result_received") and not client_mgr.vote_result_received.is_connected(_on_network_vote_result_received):
		client_mgr.vote_result_received.connect(_on_network_vote_result_received)

	if client_mgr.has_signal("game_state_changed") and not client_mgr.game_state_changed.is_connected(_on_network_game_state_changed):
		client_mgr.game_state_changed.connect(_on_network_game_state_changed)

	if "assigned_peer_id" in client_mgr:
		local_peer_id = client_mgr.assigned_peer_id
	if "assigned_slot" in client_mgr and client_mgr.assigned_slot > 0:
		local_slot_id = client_mgr.assigned_slot

# --- Public API & Lifecycle Methods ---

## Opens the Meeting UI in DISCUSSION phase.
func open_meeting(caller_peer_id: int, discussion_duration: float = MeetingConfig.DEFAULT_DISCUSSION_DURATION_SEC) -> void:
	_ensure_ui_structure()
	current_phase = MeetingConfig.MeetingPhase.DISCUSSION
	current_caller_peer_id = caller_peer_id
	current_timer_remaining = discussion_duration
	has_voted_locally = false
	selected_vote_target = MeetingConfig.VOTE_SKIP
	voted_peer_ids.clear()
	is_showing_results = false
	if results_panel != null:
		results_panel.visible = false

	# 1. Lock player movement and interactions during meeting
	_lock_player_movement(true)

	# 2. Refresh real player roster
	_refresh_roster_data()
	_rebuild_roster_ui()

	# 3. Update header and status text
	if title_label != null:
		title_label.text = "EMERGENCY MEETING"
	if subtitle_label != null:
		if caller_peer_id > 0:
			var caller_name = _get_player_display_name(caller_peer_id)
			subtitle_label.text = "Meeting called by %s" % caller_name
		else:
			subtitle_label.text = "Emergency Session in Progress"

	if phase_badge != null:
		phase_badge.text = "PHASE: DISCUSSION"
		phase_badge.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))

	if skip_button != null:
		skip_button.disabled = true
		skip_button.text = "SKIP VOTE"

	if status_feedback_label != null:
		if is_local_eliminated:
			status_feedback_label.text = "You are ELIMINATED (Spectator Mode)"
			status_feedback_label.set("theme_override_colors/font_color", Color(0.9, 0.35, 0.35, 1.0))
		else:
			status_feedback_label.text = "Discussion phase active. Confer with crew before voting starts."
			status_feedback_label.set("theme_override_colors/font_color", Color(0.75, 0.85, 0.95, 0.9))

	visible = true
	_update_timer_display()
	meeting_opened.emit(caller_peer_id, discussion_duration)
	print("[MeetingVotingUI] Meeting overlay opened (Caller: %d, Discussion: %.1fs)." % [caller_peer_id, discussion_duration])

## Transitions meeting overlay to VOTING phase.
func start_voting(voting_duration: float = MeetingConfig.DEFAULT_VOTING_DURATION_SEC) -> void:
	_ensure_ui_structure()
	current_phase = MeetingConfig.MeetingPhase.VOTING
	current_timer_remaining = voting_duration

	if phase_badge != null:
		phase_badge.text = "PHASE: VOTING"
		phase_badge.set("theme_override_colors/font_color", Color(1.0, 0.8, 0.2, 1.0))

	if status_feedback_label != null:
		if is_local_eliminated:
			status_feedback_label.text = "You are ELIMINATED. You cannot cast a vote."
			status_feedback_label.set("theme_override_colors/font_color", Color(0.9, 0.35, 0.35, 1.0))
		elif has_voted_locally:
			status_feedback_label.text = "Vote already submitted. Awaiting other players."
			status_feedback_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 1.0))
		else:
			status_feedback_label.text = "Cast your vote by selecting a player or choose Skip Vote."
			status_feedback_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.4, 1.0))

	if skip_button != null:
		skip_button.disabled = is_local_eliminated or has_voted_locally

	_update_voting_buttons_state()
	_update_timer_display()
	voting_phase_entered.emit(voting_duration)
	print("[MeetingVotingUI] Voting phase active (Duration: %.1fs)." % voting_duration)

## Records that a specific player submitted their vote.
func record_player_voted(voter_peer_id: int) -> void:
	voted_peer_ids[voter_peer_id] = true

	if voter_peer_id == local_peer_id or (local_peer_id == 0 and voter_peer_id == 1):
		has_voted_locally = true
		_update_voting_buttons_state()
		if skip_button != null:
			skip_button.disabled = true
		if status_feedback_label != null and not is_local_eliminated:
			var target_name = "SKIP" if selected_vote_target == MeetingConfig.VOTE_SKIP else _get_player_display_name(selected_vote_target)
			status_feedback_label.text = "✓ Vote Confirmed: %s" % target_name
			status_feedback_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 1.0))

	_update_player_card_vote_status(voter_peer_id)

## Displays the authoritative vote results overlay.
func show_results(result_data: Dictionary, auto_dismiss_delay: float = 4.0) -> void:
	_ensure_ui_structure()
	current_phase = MeetingConfig.MeetingPhase.RESULTS
	is_showing_results = true
	results_dismiss_timer = auto_dismiss_delay

	var elim_id = int(result_data.get("eliminated_peer_id", 0))
	var was_imp = bool(result_data.get("was_impostor", false))
	var is_tie = bool(result_data.get("is_tie", false))
	var is_skip = bool(result_data.get("is_skip", false))
	var total_votes = int(result_data.get("total_votes_cast", 0))
	var skip_count = int(result_data.get("skip_count", 0))

	if phase_badge != null:
		phase_badge.text = "PHASE: RESULTS"
		phase_badge.set("theme_override_colors/font_color", Color(0.85, 0.4, 1.0, 1.0))

	if timer_label != null:
		timer_label.text = "Concluded"

	if results_panel != null:
		results_panel.visible = true

	if results_title_label != null:
		if elim_id > 0:
			var elim_name = _get_player_display_name(elim_id)
			results_title_label.text = "%s was Ejected." % elim_name
			results_title_label.set("theme_override_colors/font_color", Color(1.0, 0.4, 0.3, 1.0))
		elif is_tie:
			results_title_label.text = "No one was ejected. (Tie)"
			results_title_label.set("theme_override_colors/font_color", Color(0.95, 0.8, 0.3, 1.0))
		elif is_skip:
			results_title_label.text = "No one was ejected. (Skipped)"
			results_title_label.set("theme_override_colors/font_color", Color(0.65, 0.85, 1.0, 1.0))
		else:
			results_title_label.text = "No one was ejected."
			results_title_label.set("theme_override_colors/font_color", Color(0.85, 0.9, 0.95, 1.0))

	if results_detail_label != null:
		if elim_id > 0:
			var elim_name = _get_player_display_name(elim_id)
			if was_imp:
				results_detail_label.text = "%s was the Impostor." % elim_name
				results_detail_label.set("theme_override_colors/font_color", Color(0.25, 0.95, 0.45, 1.0))
			else:
				results_detail_label.text = "%s was NOT the Impostor." % elim_name
				results_detail_label.set("theme_override_colors/font_color", Color(0.95, 0.35, 0.35, 1.0))
		else:
			results_detail_label.text = "Plurality threshold was not reached."
			results_detail_label.set("theme_override_colors/font_color", Color(0.7, 0.75, 0.85, 0.9))

	if results_tally_label != null:
		results_tally_label.text = "Total Votes Cast: %d | Skips: %d" % [total_votes, skip_count]

	# If local player was eliminated, mark state
	if elim_id == local_peer_id and elim_id > 0:
		is_local_eliminated = true
		eliminated_peer_ids[elim_id] = true
		if status_feedback_label != null:
			status_feedback_label.text = "You were eliminated by plurality vote."
			status_feedback_label.set("theme_override_colors/font_color", Color(0.9, 0.3, 0.3, 1.0))
	elif elim_id > 0:
		eliminated_peer_ids[elim_id] = true

	# Update roster card for eliminated player
	_rebuild_roster_ui()

	print("[MeetingVotingUI] Displaying meeting results: Eliminated=%d, WasImp=%s, Tie=%s, Skip=%s." % [
		elim_id, str(was_imp), str(is_tie), str(is_skip)
	])

## Closes and resets the meeting overlay, restoring player movement.
func close_meeting() -> void:
	current_phase = MeetingConfig.MeetingPhase.NONE
	visible = false
	is_showing_results = false
	results_dismiss_timer = 0.0

	if results_panel != null:
		results_panel.visible = false

	# Restore local player movement if alive
	_lock_player_movement(false)
	meeting_closed.emit()
	print("[MeetingVotingUI] Meeting closed. Player controls restored.")

## Submits a vote for target player (or VOTE_SKIP = -1) from the local client.
func cast_vote(target_peer_id: int) -> bool:
	if current_phase != MeetingConfig.MeetingPhase.VOTING:
		push_warning("[MeetingVotingUI] Cannot vote: not in VOTING phase.")
		return false

	if is_local_eliminated:
		push_warning("[MeetingVotingUI] Cannot vote: local player is eliminated.")
		return false

	if has_voted_locally:
		push_warning("[MeetingVotingUI] Cannot vote: already voted this meeting.")
		return false

	# Target must not be eliminated (unless Skip)
	if target_peer_id != MeetingConfig.VOTE_SKIP and eliminated_peer_ids.get(target_peer_id, false):
		push_warning("[MeetingVotingUI] Cannot vote for eliminated target %d." % target_peer_id)
		return false

	selected_vote_target = target_peer_id
	has_voted_locally = true

	# Immediate visual lock
	_update_voting_buttons_state()
	if skip_button != null:
		skip_button.disabled = true

	var target_display = "SKIP" if target_peer_id == MeetingConfig.VOTE_SKIP else _get_player_display_name(target_peer_id)
	if status_feedback_label != null:
		status_feedback_label.text = "Submitting vote for %s..." % target_display
		status_feedback_label.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))

	# Send through existing NetworkManager / ClientNetworkManager
	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and net_mgr.has_method("cast_vote"):
		net_mgr.cast_vote(target_peer_id)
	elif is_inside_tree():
		var client_mgr = get_tree().root.find_child("Client", true, false)
		if client_mgr != null and client_mgr.has_method("request_cast_vote"):
			client_mgr.request_cast_vote(target_peer_id)

	var voter_id = local_peer_id if local_peer_id > 0 else 1
	record_player_voted(voter_id)
	local_vote_submitted.emit(target_peer_id)
	return true

## Sets the real player roster data explicitly (e.g. for testing or direct sync).
func set_player_roster(players: Array) -> void:
	tracked_roster.clear()
	for p in players:
		if p is Dictionary:
			var slot = int(p.get("slot_id", p.get("player_slot", 1)))
			var pid = int(p.get("peer_id", 0))
			var is_alive = bool(p.get("is_alive", not bool(p.get("is_eliminated", false))))
			if not is_alive and pid > 0:
				eliminated_peer_ids[pid] = true
			tracked_roster.append({
				"peer_id": pid,
				"slot_id": slot,
				"name": str(p.get("name", p.get("player_name", "Player %d" % slot))),
				"is_alive": is_alive
			})
	_rebuild_roster_ui()

# --- Internal Helper & UI Construction Methods ---

## Locks or restores the local PlayerController input.
func _lock_player_movement(lock: bool) -> void:
	_auto_discover_player()
	if local_player != null:
		if lock:
			local_player.can_move = false
		else:
			# Only restore movement if player is still alive
			if not is_local_eliminated:
				local_player.can_move = true

func _update_timer_display() -> void:
	if timer_label != null:
		var time_int = int(ceil(current_timer_remaining))
		timer_label.text = "%ds" % time_int
		if time_int <= 5:
			timer_label.set("theme_override_colors/font_color", Color(1.0, 0.3, 0.3, 1.0))
		else:
			timer_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.3, 1.0))

## Discovers real connected players from SpawnManager, ClientNetworkManager, or local player.
func _refresh_roster_data() -> void:
	# If tracked_roster was explicitly set (e.g. via set_player_roster during a test), preserve it
	if not tracked_roster.is_empty():
		return

	# 1. Check ClientNetworkManager lobby_players_data
	var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
	var client_mgr = net_mgr.client if (net_mgr != null and "client" in net_mgr) else null

	if client_mgr != null and not client_mgr.lobby_players_data.is_empty():
		for p_data in client_mgr.lobby_players_data:
			var pid = int(p_data.get("peer_id", 0))
			var slot = int(p_data.get("player_slot", 1))
			var is_alive = not eliminated_peer_ids.get(pid, false)
			tracked_roster.append({
				"peer_id": pid,
				"slot_id": slot,
				"name": "Player %d" % slot,
				"is_alive": is_alive
			})
		return

	# 2. Check SpawnManager active slot assignments
	var spawn_mgr = null
	if is_inside_tree() and get_tree().current_scene != null:
		spawn_mgr = get_tree().current_scene.get_node_or_null("SpawnManager")
	if spawn_mgr == null and get_parent() != null:
		spawn_mgr = get_parent().get_node_or_null("SpawnManager")

	if spawn_mgr != null and not spawn_mgr.peer_to_slot_map.is_empty():
		for pid in spawn_mgr.peer_to_slot_map.keys():
			var slot = int(spawn_mgr.peer_to_slot_map[pid])
			var is_alive = not eliminated_peer_ids.get(pid, false)
			tracked_roster.append({
				"peer_id": pid,
				"slot_id": slot,
				"name": "Player %d" % slot,
				"is_alive": is_alive
			})
		return

	# 3. Fallback: Local player only (standalone / offline)
	_auto_discover_player()
	var fallback_slot = local_player.slot_id if local_player != null else local_slot_id
	var fallback_pid = local_peer_id if local_peer_id > 0 else 1
	tracked_roster.append({
		"peer_id": fallback_pid,
		"slot_id": fallback_slot,
		"name": "Player %d" % fallback_slot,
		"is_alive": not eliminated_peer_ids.get(fallback_pid, false)
	})

## Rebuilds the UI player cards grid for all tracked players.
func _rebuild_roster_ui() -> void:
	if roster_container == null:
		return

	# Clear existing card children
	for child in roster_container.get_children():
		child.queue_free()
	player_card_nodes.clear()

	for player_info in tracked_roster:
		var pid: int = player_info.get("peer_id", 0)
		var slot: int = player_info.get("slot_id", 1)
		var pname: String = player_info.get("name", "Player %d" % slot)
		var is_alive: bool = player_info.get("is_alive", true) and not eliminated_peer_ids.get(pid, false)
		var is_local: bool = (pid == local_peer_id or (local_peer_id == 0 and pid == 1))

		var card = _create_player_card(pid, slot, pname, is_alive, is_local)
		roster_container.add_child(card["root"])
		player_card_nodes[pid] = card

	_update_voting_buttons_state()

## Constructs a single Player Card UI container.
func _create_player_card(pid: int, slot: int, pname: String, is_alive: bool, is_local: bool) -> Dictionary:
	var card_panel = PanelContainer.new()
	card_panel.name = "Card_Player_%d" % pid
	card_panel.custom_minimum_size = Vector2(280, 72)
	card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	if not is_alive:
		style.bg_color = Color(0.08, 0.08, 0.1, 0.75)
		style.border_color = Color(0.5, 0.2, 0.2, 0.6)
	elif is_local:
		style.bg_color = Color(0.09, 0.14, 0.2, 0.92)
		style.border_color = Color(0.3, 0.85, 1.0, 0.85)
	else:
		style.bg_color = Color(0.08, 0.11, 0.16, 0.9)
		style.border_color = Color(0.2, 0.3, 0.42, 0.75)

	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	card_panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	card_panel.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	# Info VBox: [Name (YOU)] / [Status Badge]
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_lbl = Label.new()
	name_lbl.name = "NameLabel"
	var display_str = "%s (YOU)" % pname if is_local else pname
	name_lbl.text = display_str
	name_lbl.add_theme_font_size_override("font_size", 13)
	if not is_alive:
		name_lbl.set("theme_override_colors/font_color", Color(0.6, 0.6, 0.6, 0.7))
	elif is_local:
		name_lbl.set("theme_override_colors/font_color", Color(0.4, 0.9, 1.0, 1.0))
	else:
		name_lbl.set("theme_override_colors/font_color", Color(0.9, 0.93, 0.96, 1.0))
	info_vbox.add_child(name_lbl)

	var status_lbl = Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.add_theme_font_size_override("font_size", 11)
	if not is_alive:
		status_lbl.text = "✖ ELIMINATED"
		status_lbl.set("theme_override_colors/font_color", Color(0.9, 0.3, 0.3, 0.85))
	elif voted_peer_ids.get(pid, false):
		status_lbl.text = "✓ VOTED"
		status_lbl.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 0.9))
	else:
		status_lbl.text = "● ALIVE"
		status_lbl.set("theme_override_colors/font_color", Color(0.4, 0.8, 0.5, 0.85))
	info_vbox.add_child(status_lbl)

	# Vote Action Button
	var vote_btn = Button.new()
	vote_btn.name = "VoteButton"
	vote_btn.text = "VOTE"
	vote_btn.custom_minimum_size = Vector2(75, 32)
	vote_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vote_btn.add_theme_font_size_override("font_size", 12)
	vote_btn.pressed.connect(func(): cast_vote(pid))
	hbox.add_child(vote_btn)

	return {
		"root": card_panel,
		"name_label": name_lbl,
		"status_label": status_lbl,
		"vote_button": vote_btn,
		"is_alive": is_alive,
		"peer_id": pid
	}

## Updates the enabled/disabled state of all vote buttons.
func _update_voting_buttons_state() -> void:
	var can_vote = (current_phase == MeetingConfig.MeetingPhase.VOTING and not is_local_eliminated and not has_voted_locally)

	for pid in player_card_nodes.keys():
		var card = player_card_nodes[pid]
		var btn: Button = card.get("vote_button")
		var is_alive: bool = card.get("is_alive", true) and not eliminated_peer_ids.get(pid, false)

		if btn != null:
			btn.disabled = not (can_vote and is_alive)
			if has_voted_locally and selected_vote_target == pid:
				btn.text = "VOTED"
			else:
				btn.text = "VOTE"

	if skip_button != null:
		skip_button.disabled = not can_vote

## Updates vote badge on a specific player card.
func _update_player_card_vote_status(voter_peer_id: int) -> void:
	if player_card_nodes.has(voter_peer_id):
		var card = player_card_nodes[voter_peer_id]
		var status_lbl: Label = card.get("status_label")
		var is_alive: bool = card.get("is_alive", true) and not eliminated_peer_ids.get(voter_peer_id, false)
		if status_lbl != null and is_alive:
			status_lbl.text = "✓ VOTED"
			status_lbl.set("theme_override_colors/font_color", Color(0.3, 0.9, 0.5, 0.9))

func _get_player_display_name(peer_id: int) -> String:
	for p in tracked_roster:
		if p.get("peer_id", 0) == peer_id:
			return p.get("name", "Player %d" % p.get("slot_id", 1))
	return "Player %d" % peer_id

# --- Network Event Callbacks ---

func _on_network_meeting_started(caller_peer_id: int, discussion_duration: float) -> void:
	open_meeting(caller_peer_id, discussion_duration)

func _on_network_voting_started(voting_duration: float) -> void:
	start_voting(voting_duration)

func _on_network_player_voted(voter_peer_id: int) -> void:
	record_player_voted(voter_peer_id)

func _on_network_vote_result_received(result_data: Dictionary) -> void:
	show_results(result_data)

func _on_network_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	# If match transitions to MELTDOWN, GAME_OVER, or LOBBY and results are done, close meeting
	if new_state != NetworkConfig.GameState.MEETING and new_state != NetworkConfig.GameState.VOTING:
		if not is_showing_results and visible:
			close_meeting()

# --- Programmatic UI Layout Hierarchy ---

func _ensure_ui_structure() -> void:
	if main_panel != null:
		return

	# Anchor to fill entire parent viewport
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.06, 0.78)
	add_child(backdrop)

	# 2. Centered Main Modal Container
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(660, 480)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.12, 0.96)
	panel_style.border_color = Color(0.24, 0.4, 0.58, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	main_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(main_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	main_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(main_vbox)

	# --- HEADER ---
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "EMERGENCY MEETING"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.set("theme_override_colors/font_color", Color(0.95, 0.35, 0.35, 1.0))
	title_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "Investigation Session Active"
	subtitle_label.add_theme_font_size_override("font_size", 12)
	subtitle_label.set("theme_override_colors/font_color", Color(0.7, 0.78, 0.88, 0.85))
	title_vbox.add_child(subtitle_label)

	var timer_vbox = VBoxContainer.new()
	timer_vbox.alignment = BoxContainer.ALIGNMENT_END
	header_hbox.add_child(timer_vbox)

	phase_badge = Label.new()
	phase_badge.name = "PhaseBadge"
	phase_badge.text = "PHASE: DISCUSSION"
	phase_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	phase_badge.add_theme_font_size_override("font_size", 12)
	phase_badge.set("theme_override_colors/font_color", Color(0.3, 0.85, 1.0, 1.0))
	timer_vbox.add_child(phase_badge)

	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.text = "30s"
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.set("theme_override_colors/font_color", Color(1.0, 0.9, 0.3, 1.0))
	timer_vbox.add_child(timer_label)

	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)

	# --- ROSTER GRID ---
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	roster_container = GridContainer.new()
	roster_container.name = "RosterGrid"
	roster_container.columns = 2
	roster_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_container.add_theme_constant_override("h_separation", 10)
	roster_container.add_theme_constant_override("v_separation", 8)
	scroll.add_child(roster_container)

	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)

	# --- FOOTER / ACTION BAR ---
	var footer_hbox = HBoxContainer.new()
	footer_hbox.add_theme_constant_override("separation", 12)
	main_vbox.add_child(footer_hbox)

	status_feedback_label = Label.new()
	status_feedback_label.name = "StatusFeedbackLabel"
	status_feedback_label.text = "Discussion phase active."
	status_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_feedback_label.add_theme_font_size_override("font_size", 12)
	status_feedback_label.set("theme_override_colors/font_color", Color(0.75, 0.85, 0.95, 0.9))
	footer_hbox.add_child(status_feedback_label)

	skip_button = Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = "SKIP VOTE"
	skip_button.custom_minimum_size = Vector2(120, 34)
	skip_button.disabled = true
	skip_button.add_theme_font_size_override("font_size", 12)
	skip_button.pressed.connect(func(): cast_vote(MeetingConfig.VOTE_SKIP))
	footer_hbox.add_child(skip_button)

	# --- RESULTS OVERLAY PANEL ---
	results_panel = PanelContainer.new()
	results_panel.name = "ResultsPanel"
	results_panel.custom_minimum_size = Vector2(500, 200)
	results_panel.visible = false

	var res_style = StyleBoxFlat.new()
	res_style.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	res_style.border_color = Color(0.3, 0.8, 1.0, 0.9)
	res_style.set_border_width_all(2)
	res_style.set_corner_radius_all(8)
	results_panel.add_theme_stylebox_override("panel", res_style)
	center.add_child(results_panel)

	var res_margin = MarginContainer.new()
	res_margin.add_theme_constant_override("margin_left", 24)
	res_margin.add_theme_constant_override("margin_top", 20)
	res_margin.add_theme_constant_override("margin_right", 24)
	res_margin.add_theme_constant_override("margin_bottom", 20)
	results_panel.add_child(res_margin)

	var res_vbox = VBoxContainer.new()
	res_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	res_vbox.add_theme_constant_override("separation", 10)
	res_margin.add_child(res_vbox)

	results_title_label = Label.new()
	results_title_label.name = "ResultsTitleLabel"
	results_title_label.text = "Results"
	results_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_title_label.add_theme_font_size_override("font_size", 22)
	res_vbox.add_child(results_title_label)

	results_detail_label = Label.new()
	results_detail_label.name = "ResultsDetailLabel"
	results_detail_label.text = ""
	results_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_detail_label.add_theme_font_size_override("font_size", 14)
	res_vbox.add_child(results_detail_label)

	var res_sep = HSeparator.new()
	res_vbox.add_child(res_sep)

	results_tally_label = Label.new()
	results_tally_label.name = "ResultsTallyLabel"
	results_tally_label.text = "Total votes: 0"
	results_tally_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	results_tally_label.add_theme_font_size_override("font_size", 12)
	results_tally_label.set("theme_override_colors/font_color", Color(0.65, 0.75, 0.85, 0.85))
	res_vbox.add_child(results_tally_label)
