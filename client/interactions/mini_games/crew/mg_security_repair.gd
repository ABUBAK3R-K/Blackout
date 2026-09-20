class_name MGSecurityRepair
extends MiniGameBase

## Phase 1 Crew Task: Security Repair (Security)
## Configure 4 firewall security interlocks to clear sensor loop alarms.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var target_states: Array[bool] = [true, false, true, true]
var current_states: Array[bool] = [false, false, false, false]
var switch_buttons: Array[Button] = []
var switch_labels: Array[String] = ["CAM FEED CAM-01", "DOOR SENSOR D-03", "OPTICAL ALARM A-02", "BIOMETRIC GATE B-04"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Security Firewall Interlock",
		"Toggle sensor switches to match required security diagnostic parity.",
		Vector2(620, 470),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	var parity_info = Label.new()
	parity_info.text = "REQUIRED PARITY: [CAM: ACTIVE | DOOR: BYPASS | ALARM: ACTIVE | GATE: ACTIVE]"
	parity_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parity_info.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)
	parity_info.add_theme_font_size_override("font_size", 12)
	vbox.add_child(parity_info)

	for i in range(4):
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = switch_labels[i]
		name_lbl.custom_minimum_size = Vector2(240, 36)
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(name_lbl)

		var btn = Button.new()
		btn.text = "STATE: BYPASS (OFF)"
		btn.custom_minimum_size = Vector2(180, 36)
		var sw_idx = i
		btn.pressed.connect(func(): _on_switch_toggled(sw_idx))
		row.add_child(btn)
		switch_buttons.append(btn)

	_evaluate_state()

func _on_switch_toggled(idx: int) -> void:
	if not is_active(): return
	current_states[idx] = not current_states[idx]
	_evaluate_state()

func _evaluate_state() -> void:
	var correct_count = 0
	for i in range(4):
		var active = current_states[i]
		if active:
			switch_buttons[i].text = "STATE: ACTIVE (ON)"
			switch_buttons[i].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
		else:
			switch_buttons[i].text = "STATE: BYPASS (OFF)"
			switch_buttons[i].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)

		if current_states[i] == target_states[i]:
			correct_count += 1

	var p = float(correct_count) / 4.0
	set_progress(p)
	ui_elements["status_label"].text = "PARITY VERIFICATION: %d/4 INTERLOCKS MATCHED" % correct_count

	if correct_count == 4:
		ui_elements["status_label"].text = "SECURITY INTERLOCK VERIFIED. SENSOR LOOPS RESTORED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_states = [false, false, false, false]
	if switch_buttons.size() == 4:
		_evaluate_state()
