class_name MGRecoveryCooling
extends MiniGameBase

## Phase 2 Blackout Recovery: Cooling (Life Support / Cooling Hub)
## Open emergency cryogenic bypass loops to restore facility coolant pressure.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var purged_valves: Array[bool] = [false, false, false]
var valve_buttons: Array[Button] = []
var valve_names: Array[String] = ["CRYO MANIFOLD VALVE-A", "CRYO MANIFOLD VALVE-B", "EMERGENCY RESERVOIR FLUSH"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Cooling Hub Bypass Station",
		"Depressurize and open 3 emergency cryogenic valves to clear coolant lock.",
		Vector2(640, 460),
		MiniGameUIHelper.COLOR_BORDER_AMBER
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(3):
		var btn = Button.new()
		btn.text = "[ DEPRESSURIZE & OPEN ] " + valve_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var v_idx = i
		btn.pressed.connect(func(): _on_valve_pressed(v_idx))
		vbox.add_child(btn)
		valve_buttons.append(btn)

func _on_valve_pressed(idx: int) -> void:
	if not is_active() or purged_valves[idx]: return

	purged_valves[idx] = true
	valve_buttons[idx].disabled = true
	valve_buttons[idx].text = "✔ [OPEN & FLOWING] " + valve_names[idx]
	valve_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	var count = 0
	for p in purged_valves:
		if p: count += 1

	var p_val = float(count) / 3.0
	set_progress(p_val)
	ui_elements["status_label"].text = "COOLANT VALVES: %d/3 BYPASS CHANNELS OPEN" % count

	if count == 3:
		ui_elements["status_label"].text = "COOLING RESTORED: CRYOGENIC PRESSURE AT NOMINAL OPERATING LEVEL."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	purged_valves = [false, false, false]
	for i in range(valve_buttons.size()):
		valve_buttons[i].disabled = false
		valve_buttons[i].text = "[ DEPRESSURIZE & OPEN ] " + valve_names[i]
