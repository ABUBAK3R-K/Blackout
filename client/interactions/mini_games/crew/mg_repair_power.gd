class_name MGRepairPower
extends MiniGameBase

## Phase 1 Crew Task: Repair Power (Electrical)
## Connect 4 matching colored circuit leads between the distribution block and load terminals.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var selected_left_index: int = -1
var connected_wires: Array[bool] = [false, false, false, false]
var wire_colors: Array[Color] = [
	Color(0.95, 0.25, 0.25), # Red
	Color(0.25, 0.6, 0.95),  # Blue
	Color(0.95, 0.85, 0.2),  # Yellow
	Color(0.3, 0.9, 0.35)    # Green
]
var wire_names: Array[String] = ["FEEDER RED", "BUS BLUE", "AUX YELLOW", "GROUND GREEN"]
var right_shuffled_indices: Array[int] = [2, 0, 3, 1]

var left_buttons: Array[Button] = []
var right_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Power Distribution Substation",
		"Match and connect all 4 circuit leads to restore power bus continuity.",
		Vector2(620, 460),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var grid = HBoxContainer.new()
	grid.name = "WireGrid"
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(grid)

	# Left terminals column
	var left_col = VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.add_theme_constant_override("separation", 14)
	grid.add_child(left_col)

	# Center wiring channel graphic
	var center_divider = VBoxContainer.new()
	center_divider.custom_minimum_size = Vector2(100, 0)
	center_divider.alignment = BoxContainer.ALIGNMENT_CENTER
	var channel_lbl = Label.new()
	channel_lbl.text = ">>> [GRID BUS] >>>"
	channel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	channel_lbl.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_MUTED)
	channel_lbl.add_theme_font_size_override("font_size", 11)
	center_divider.add_child(channel_lbl)
	grid.add_child(center_divider)

	# Right terminals column
	var right_col = VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_col.alignment = BoxContainer.ALIGNMENT_CENTER
	right_col.add_theme_constant_override("separation", 14)
	grid.add_child(right_col)

	# Generate left buttons
	for i in range(4):
		var btn = Button.new()
		btn.text = "● " + wire_names[i]
		btn.custom_minimum_size = Vector2(180, 42)
		btn.add_theme_color_override("font_color", wire_colors[i])
		var idx = i
		btn.pressed.connect(func(): _on_left_terminal_pressed(idx))
		left_col.add_child(btn)
		left_buttons.append(btn)

	# Generate right buttons (shuffled)
	for i in range(4):
		var target_color_idx = right_shuffled_indices[i]
		var btn = Button.new()
		btn.text = wire_names[target_color_idx] + " ●"
		btn.custom_minimum_size = Vector2(180, 42)
		btn.add_theme_color_override("font_color", wire_colors[target_color_idx])
		var r_idx = i
		btn.pressed.connect(func(): _on_right_terminal_pressed(r_idx))
		right_col.add_child(btn)
		right_buttons.append(btn)

func _on_left_terminal_pressed(idx: int) -> void:
	if not is_active() or connected_wires[idx]:
		return
	selected_left_index = idx
	ui_elements["status_label"].text = "SELECTED: %s. Click matching terminal on right." % wire_names[idx]
	_highlight_selection()

func _on_right_terminal_pressed(r_idx: int) -> void:
	if not is_active() or selected_left_index == -1:
		return

	var target_color_idx = right_shuffled_indices[r_idx]
	if selected_left_index == target_color_idx:
		# Correct match!
		connected_wires[selected_left_index] = true
		left_buttons[selected_left_index].disabled = true
		left_buttons[selected_left_index].text = "✔ " + wire_names[selected_left_index] + " [CONNECTED]"
		right_buttons[r_idx].disabled = true
		right_buttons[r_idx].text = "[CONNECTED] " + wire_names[target_color_idx] + " ✔"

		selected_left_index = -1
		_highlight_selection()

		# Recalculate progress
		var count = 0
		for c in connected_wires:
			if c: count += 1
		var p = float(count) / 4.0
		set_progress(p)
		ui_elements["status_label"].text = "CIRCUIT CLOSED: %d/4 LEADS CONNECTED" % count

		if count == 4:
			ui_elements["status_label"].text = "ALL CIRCUITS CLOSED. POWER BUS RESTORED."
			complete_interaction()
	else:
		# Mismatch
		ui_elements["status_label"].text = "CONNECTION ERROR: POLARITY MISMATCH! Try again."
		selected_left_index = -1
		_highlight_selection()

func _highlight_selection() -> void:
	for i in range(left_buttons.size()):
		if not connected_wires[i]:
			if i == selected_left_index:
				left_buttons[i].text = "> " + wire_names[i] + " <"
			else:
				left_buttons[i].text = "● " + wire_names[i]

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	selected_left_index = -1
	connected_wires = [false, false, false, false]
	for i in range(left_buttons.size()):
		left_buttons[i].disabled = false
		left_buttons[i].text = "● " + wire_names[i]
	for i in range(right_buttons.size()):
		var target_color_idx = right_shuffled_indices[i]
		right_buttons[i].disabled = false
		right_buttons[i].text = wire_names[target_color_idx] + " ●"
