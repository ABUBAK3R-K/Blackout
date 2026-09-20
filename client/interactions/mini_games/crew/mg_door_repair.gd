class_name MGDoorRepair
extends MiniGameBase

## Phase 1 Crew Task: Door Repair (Maintenance)
## Re-pressurize 3 pneumatic door seals and release mechanical latch jams.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var valve_pressures: Array[float] = [0.0, 0.0, 0.0]
var valve_buttons: Array[Button] = []
var valve_labels: Array[Label] = []
const TARGET_PRESSURE: float = 100.0

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Pneumatic Bulkhead Seal Repair",
		"Pressurize each pneumatic actuator to 100 PSI to clear bulkhead obstruction.",
		Vector2(620, 460),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(3):
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row)

		var lbl = Label.new()
		lbl.text = "ACTUATOR-%d: 0 PSI" % (i + 1)
		lbl.custom_minimum_size = Vector2(220, 36)
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(lbl)
		valve_labels.append(lbl)

		var btn = Button.new()
		btn.text = "PUMP COMPRESSOR (+25 PSI)"
		btn.custom_minimum_size = Vector2(220, 36)
		var v_idx = i
		btn.pressed.connect(func(): _on_pump_pressed(v_idx))
		row.add_child(btn)
		valve_buttons.append(btn)

func _on_pump_pressed(idx: int) -> void:
	if not is_active(): return

	valve_pressures[idx] += 25.0
	if valve_pressures[idx] >= TARGET_PRESSURE:
		valve_pressures[idx] = TARGET_PRESSURE
		valve_buttons[idx].disabled = true
		valve_buttons[idx].text = "SEAL LOCKED (100 PSI)"
		valve_labels[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	valve_labels[idx].text = "ACTUATOR-%d: %.0f PSI" % [idx + 1, valve_pressures[idx]]

	# Calculate total progress
	var total_p = (valve_pressures[0] + valve_pressures[1] + valve_pressures[2]) / (3.0 * TARGET_PRESSURE)
	set_progress(total_p)
	ui_elements["status_label"].text = "HYDRAULIC MANIFOLD: %.0f%% PRESSURE STABILIZED" % (total_p * 100.0)

	if total_p >= 1.0:
		ui_elements["status_label"].text = "PRESSURE BALANCED: BULKHEAD SEAL SECURED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	valve_pressures = [0.0, 0.0, 0.0]
	for i in range(valve_buttons.size()):
		valve_buttons[i].disabled = false
		valve_buttons[i].text = "PUMP COMPRESSOR (+25 PSI)"
		valve_labels[i].text = "ACTUATOR-%d: 0 PSI" % (i + 1)
		valve_labels[i].remove_theme_color_override("font_color")
