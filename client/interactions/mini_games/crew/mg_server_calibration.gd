class_name MGServerCalibration
extends MiniGameBase

## Phase 1 Crew Task: Server Calibration (Tech)
## Re-calibrate mainframe compute blocks by inputting the memory address sequence.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var target_sequence: Array[int] = [1, 3, 0, 2] # 4-node sequence
var player_sequence: Array[int] = []
var node_buttons: Array[Button] = []
var node_names: Array[String] = ["NODE-ALPHA", "NODE-BETA", "NODE-GAMMA", "NODE-DELTA"]
var prompt_label: Label = null

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Mainframe Server Calibration",
		"Input memory routing sequence in order to re-synchronize server clusters.",
		Vector2(620, 460),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	prompt_label = Label.new()
	prompt_label.text = "REQUIRED SEQUENCE: [ BETA -> DELTA -> ALPHA -> GAMMA ]"
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)
	prompt_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(prompt_label)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	vbox.add_child(grid)

	for i in range(4):
		var btn = Button.new()
		btn.text = "[ %d ] %s" % [i + 1, node_names[i]]
		btn.custom_minimum_size = Vector2(180, 56)
		var node_idx = i
		btn.pressed.connect(func(): _on_node_pressed(node_idx))
		grid.add_child(btn)
		node_buttons.append(btn)

func _on_node_pressed(node_idx: int) -> void:
	if not is_active(): return

	var expected_idx = target_sequence[player_sequence.size()]
	if node_idx == expected_idx:
		player_sequence.append(node_idx)
		var p = float(player_sequence.size()) / float(target_sequence.size())
		set_progress(p)
		ui_elements["status_label"].text = "STATUS: NODE ACKNOWLEDGED (%d/%d)" % [player_sequence.size(), target_sequence.size()]

		if player_sequence.size() == target_sequence.size():
			ui_elements["status_label"].text = "STATUS: SERVER CLUSTER SYNCHRONIZED!"
			complete_interaction()
	else:
		# Sequence broken - reset sequence
		player_sequence.clear()
		set_progress(0.0)
		ui_elements["status_label"].text = "CALIBRATION FAULT! Sequence interrupted. Start from beginning."

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	player_sequence.clear()
