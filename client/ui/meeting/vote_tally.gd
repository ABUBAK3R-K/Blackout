class_name VoteTallyUI
extends PanelContainer

## VoteTallyUI — Member 5 (UI/UX Frontend)
## Authoritative Live Vote Tally Display for BLACKOUT.
##
## Displays live voting status and vote counts provided strictly by authoritative server state.
## Features:
## 1. Header with 'VOTE STATUS' and 'X / Y PLAYERS VOTED' or 'NO VOTES CAST' / 'VOTING COMPLETE'.
## 2. Row-based candidate layout showing mini suit badge, name, compact progress bar, count, and status.
## 3. Dedicated Skip Vote row.
## 4. Strict authoritative data contract: Frontend does NOT calculate vote totals, resolve ties,
##    declare winners, or decide ejections.

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")

## Official 8-Player Suit Colors (docs/environment_art_spec.md §7.1)
const PLAYER_PALETTE: Array[Color] = [
	Color(0.898, 0.224, 0.208), # 1. Crimson Red   (#e53935)
	Color(0.118, 0.533, 0.898), # 2. Cobalt Blue   (#1e88e5)
	Color(0.263, 0.627, 0.278), # 3. Emerald Green (#43a047)
	Color(0.992, 0.847, 0.208), # 4. Vivid Yellow  (#fdd835)
	Color(0.984, 0.549, 0.0),   # 5. Safety Orange (#fb8c00)
	Color(0.557, 0.141, 0.667), # 6. Deep Purple   (#8e24aa)
	Color(0.0, 0.675, 0.757),   # 7. Electric Cyan (#00acc1)
	Color(0.925, 0.937, 0.945)  # 8. Arctic White  (#eceff1)
]

## Styling Constants
const COLOR_ACTIVE_GREEN: Color = Color(0.20, 0.85, 0.40, 1.0)
const COLOR_EJECTED_RED: Color = Color(0.85, 0.28, 0.28, 1.0)
const COLOR_BAR_BG: Color = Color(0.10, 0.11, 0.14, 0.9)
const COLOR_BAR_FILL: Color = Color(0.85, 0.22, 0.24, 0.95)
const COLOR_BAR_SKIP: Color = Color(0.95, 0.75, 0.20, 0.90)
const COLOR_COUNT_ZERO: Color = Color(0.45, 0.48, 0.55, 0.65)
const COLOR_COUNT_ACTIVE: Color = Color(0.95, 0.96, 0.98, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.60, 0.64, 0.72, 0.85)

## Node references
@onready var title_label: Label = find_child("TitleLabel", true, false)
@onready var count_status_label: Label = find_child("CountStatusLabel", true, false)
@onready var rows_container: VBoxContainer = find_child("RowsContainer", true, false)
@onready var empty_notice_label: Label = find_child("EmptyNoticeLabel", true, false)
@onready var skip_row_container: Control = find_child("SkipRowContainer", true, false)

## Internal state
var _players_data: Array = []
var _local_peer_id: int = 0
var _voted_peer_ids: Array[int] = []
var _votes_per_target: Dictionary = {}
var _skip_count: int = 0
var _has_explicit_tally_data: bool = false
var _is_voting_complete: bool = false
var _leader_peer_id: int = 0

func _ready() -> void:
	_ensure_node_references()
	_update_tally_display()

func _ensure_node_references() -> void:
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if count_status_label == null:
		count_status_label = find_child("CountStatusLabel", true, false) as Label
	if rows_container == null:
		rows_container = find_child("RowsContainer", true, false) as VBoxContainer
	if empty_notice_label == null:
		empty_notice_label = find_child("EmptyNoticeLabel", true, false) as Label
	if skip_row_container == null:
		skip_row_container = find_child("SkipRowContainer", true, false) as Control

## Updates players cache from authoritative connection list
func set_players(players_array: Array, local_peer_id: int = 0) -> void:
	_players_data.clear()
	_local_peer_id = local_peer_id
	for p in players_array:
		if p is Dictionary:
			_players_data.append(p.duplicate())
		elif p != null and p.has_method("to_dict"):
			_players_data.append(p.to_dict())
	_update_tally_display()

## Authoritative event: Another player has cast their vote
func record_player_voted(voter_peer_id: int) -> void:
	if not _voted_peer_ids.has(voter_peer_id):
		_voted_peer_ids.append(voter_peer_id)
	_update_tally_display()

## Sets explicit authoritative tally breakdown from server (if supplied)
func set_authoritative_tally(votes_per_target: Dictionary, skip_votes: int, total_votes_cast: int = -1, leader_peer_id: int = 0) -> void:
	_has_explicit_tally_data = true
	_votes_per_target = votes_per_target.duplicate()
	_skip_count = skip_votes
	_leader_peer_id = leader_peer_id
	_update_tally_display()

## Transitions the tally into completion state
func set_voting_complete(is_complete: bool = true) -> void:
	_is_voting_complete = is_complete
	_update_tally_display()

## Resets all tally state for a new session
func reset_tally() -> void:
	_voted_peer_ids.clear()
	_votes_per_target.clear()
	_skip_count = 0
	_has_explicit_tally_data = false
	_is_voting_complete = false
	_leader_peer_id = 0
	_update_tally_display()

## Returns the number of eligible voters (active & alive)
func get_eligible_voter_count() -> int:
	var count: int = 0
	for p in _players_data:
		var is_active = not bool(p.get("is_eliminated", false)) and bool(p.get("is_alive", true))
		if is_active:
			count += 1
	return count

## Main render routine
func _update_tally_display() -> void:
	_ensure_node_references()
	if rows_container == null or count_status_label == null:
		return

	var eligible_count: int = get_eligible_voter_count()
	var voted_count: int = _voted_peer_ids.size()

	# 1. Update Header Status
	if _is_voting_complete:
		count_status_label.text = "VOTING COMPLETE"
		count_status_label.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)
	elif voted_count == 0 and not _has_explicit_tally_data:
		count_status_label.text = "NO VOTES CAST"
		count_status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	else:
		if eligible_count > 0:
			count_status_label.text = "%d / %d PLAYERS VOTED" % [voted_count, eligible_count]
		else:
			count_status_label.text = "%d VOTES RECORDED" % voted_count
		count_status_label.add_theme_color_override("font_color", COLOR_ACTIVE_GREEN)

	# 2. Clear previous candidate rows
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()

	var max_scale_votes: int = maxi(1, eligible_count)
	if _has_explicit_tally_data:
		var highest: int = _skip_count
		for count in _votes_per_target.values():
			if int(count) > highest:
				highest = int(count)
		max_scale_votes = maxi(max_scale_votes, highest)

	# 3. Build Player Rows
	for p in _players_data:
		var peer_id: int = int(p.get("peer_id", 0))
		var slot: int = int(p.get("player_slot", 1))
		var is_active: bool = not bool(p.get("is_eliminated", false)) and bool(p.get("is_alive", true))
		var vote_count: int = 0
		var show_count: bool = _has_explicit_tally_data

		if _has_explicit_tally_data:
			vote_count = int(_votes_per_target.get(peer_id, 0))

		var is_leader: bool = (_leader_peer_id > 0 and _leader_peer_id == peer_id)
		var row: Control = _create_player_tally_row(peer_id, slot, is_active, vote_count, max_scale_votes, show_count, is_leader)
		rows_container.add_child(row)

	# 4. Build / Update Skip Vote Row
	_update_skip_row(max_scale_votes)

func _create_player_tally_row(peer_id: int, slot: int, is_active: bool, vote_count: int, max_scale: int, show_count: bool, is_leader: bool) -> Control:
	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# 1. Color Pip / Mini Avatar
	var color_index = clampi(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	var suit_color = PLAYER_PALETTE[color_index] if is_active else PLAYER_PALETTE[color_index].darkened(0.5)
	var pip = _create_color_pip(suit_color, is_active)
	row.add_child(pip)

	# 2. Player Name Label
	var name_lbl = Label.new()
	var you_suffix = " (You)" if peer_id == _local_peer_id and _local_peer_id > 0 else ""
	name_lbl.text = "Player %d%s" % [peer_id if peer_id > 0 else slot, you_suffix]
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.96, 1.0) if is_active else Color(0.50, 0.52, 0.56, 0.65))
	row.add_child(name_lbl)

	# 3. Compact Progress Bar
	var bar_container = Control.new()
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.custom_minimum_size = Vector2(60, 10)
	bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var fill_ratio: float = 0.0
	if show_count and max_scale > 0:
		fill_ratio = clampf(float(vote_count) / float(max_scale), 0.0, 1.0)

	var bar_canvas = Control.new()
	bar_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_canvas.draw.connect(func():
		var w = bar_canvas.size.x
		var h = bar_canvas.size.y
		# Background track
		bar_canvas.draw_rect(Rect2(0, 1, w, h - 2), COLOR_BAR_BG, true)
		bar_canvas.draw_rect(Rect2(0, 1, w, h - 2), Color(0.20, 0.22, 0.26, 0.4), false, 1.0)
		# Fill rect
		if fill_ratio > 0.0:
			var fill_w = max(4.0, w * fill_ratio)
			var fill_col = COLOR_BAR_FILL.lightened(0.15) if is_leader else COLOR_BAR_FILL
			bar_canvas.draw_rect(Rect2(0, 1, fill_w, h - 2), fill_col, true)
	)
	bar_container.add_child(bar_canvas)
	row.add_child(bar_container)

	# 4. Status or Count Label
	var count_lbl = Label.new()
	count_lbl.custom_minimum_size = Vector2(24, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_lbl.add_theme_font_size_override("font_size", 11)

	if not is_active:
		count_lbl.text = "EJECTED"
		count_lbl.add_theme_font_size_override("font_size", 9)
		count_lbl.add_theme_color_override("font_color", COLOR_EJECTED_RED)
	elif show_count:
		count_lbl.text = str(vote_count)
		if vote_count > 0:
			count_lbl.add_theme_color_override("font_color", COLOR_COUNT_ACTIVE)
		else:
			count_lbl.add_theme_color_override("font_color", COLOR_COUNT_ZERO)
	else:
		count_lbl.text = "-"
		count_lbl.add_theme_color_override("font_color", COLOR_COUNT_ZERO)

	row.add_child(count_lbl)
	return row

func _update_skip_row(max_scale: int) -> void:
	if skip_row_container == null:
		return

	# Clear previous skip elements
	for child in skip_row_container.get_children():
		skip_row_container.remove_child(child)
		child.queue_free()

	var row = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# 1. Skip Icon Pip
	var pip = Control.new()
	pip.custom_minimum_size = Vector2(14, 14)
	pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pip_canvas = Control.new()
	pip_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	pip_canvas.draw.connect(func():
		var cx = pip_canvas.size.x * 0.5
		var cy = pip_canvas.size.y * 0.5
		pip_canvas.draw_circle(Vector2(cx, cy), 5.5, Color(0.95, 0.75, 0.20, 0.85))
	)
	pip.add_child(pip_canvas)
	row.add_child(pip)

	# 2. Skip Name Label
	var name_lbl = Label.new()
	name_lbl.text = "Skip Vote"
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.35, 1.0))
	row.add_child(name_lbl)

	# 3. Compact Progress Bar for Skip
	var bar_container = Control.new()
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.custom_minimum_size = Vector2(60, 10)
	bar_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var fill_ratio: float = 0.0
	if _has_explicit_tally_data and max_scale > 0:
		fill_ratio = clampf(float(_skip_count) / float(max_scale), 0.0, 1.0)

	var bar_canvas = Control.new()
	bar_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_canvas.draw.connect(func():
		var w = bar_canvas.size.x
		var h = bar_canvas.size.y
		bar_canvas.draw_rect(Rect2(0, 1, w, h - 2), COLOR_BAR_BG, true)
		bar_canvas.draw_rect(Rect2(0, 1, w, h - 2), Color(0.20, 0.22, 0.26, 0.4), false, 1.0)
		if fill_ratio > 0.0:
			var fill_w = max(4.0, w * fill_ratio)
			bar_canvas.draw_rect(Rect2(0, 1, fill_w, h - 2), COLOR_BAR_SKIP, true)
	)
	bar_container.add_child(bar_canvas)
	row.add_child(bar_container)

	# 4. Skip Count Label
	var count_lbl = Label.new()
	count_lbl.custom_minimum_size = Vector2(24, 0)
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	count_lbl.add_theme_font_size_override("font_size", 11)

	if _has_explicit_tally_data:
		count_lbl.text = str(_skip_count)
		count_lbl.add_theme_color_override("font_color", COLOR_COUNT_ACTIVE if _skip_count > 0 else COLOR_COUNT_ZERO)
	else:
		count_lbl.text = "-"
		count_lbl.add_theme_color_override("font_color", COLOR_COUNT_ZERO)

	row.add_child(count_lbl)
	skip_row_container.add_child(row)

func _create_color_pip(color: Color, is_active: bool) -> Control:
	var root = Control.new()
	root.custom_minimum_size = Vector2(14, 14)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var canvas = Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func():
		var cx = canvas.size.x * 0.5
		var cy = canvas.size.y * 0.5
		canvas.draw_circle(Vector2(cx, cy), 5.5, color)
		if not is_active:
			var x_col = Color(1.0, 0.25, 0.25, 0.95)
			canvas.draw_line(Vector2(cx - 3, cy - 3), Vector2(cx + 3, cy + 3), x_col, 1.5)
			canvas.draw_line(Vector2(cx + 3, cy - 3), Vector2(cx - 3, cy + 3), x_col, 1.5)
	)
	root.add_child(canvas)
	return root
