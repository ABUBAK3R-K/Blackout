class_name MGLaboratoryOrg
extends MiniGameBase

## Phase 1 Crew Task: Laboratory Organization (Lab)
## Store 3 hazardous research isotopes into balanced centrifuge containment canisters.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var slotted_isotopes: Array[bool] = [false, false, false]
var slot_buttons: Array[Button] = []
var isotope_names: Array[String] = ["ISOTOPE-07 (GAMMA EMITTER)", "ISOTOPE-12 (ALPHA HEAVY)", "ISOTOPE-19 (NEUTRINO MATRIX)"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Centrifuge Containment Rack",
		"Slot all 3 radioactive isotope canisters into magnetic suspension mounts.",
		Vector2(620, 450),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(3):
		var btn = Button.new()
		btn.text = "[ DEPOSIT INTO RACK ] " + isotope_names[i]
		btn.custom_minimum_size = Vector2(440, 44)
		var iso_idx = i
		btn.pressed.connect(func(): _on_isotope_deposited(iso_idx))
		vbox.add_child(btn)
		slot_buttons.append(btn)

func _on_isotope_deposited(idx: int) -> void:
	if not is_active() or slotted_isotopes[idx]: return

	slotted_isotopes[idx] = true
	slot_buttons[idx].disabled = true
	slot_buttons[idx].text = "✔ " + isotope_names[idx] + " [SECURED IN CENTRIFUGE]"
	slot_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	var count = 0
	for s in slotted_isotopes:
		if s: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "ISOTOPE RACK: %d/3 CONTAINED" % count

	if count == 3:
		ui_elements["status_label"].text = "CENTRIFUGE BALANCED: ALL ISOTOPES SECURED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	slotted_isotopes = [false, false, false]
	for i in range(slot_buttons.size()):
		slot_buttons[i].disabled = false
		slot_buttons[i].text = "[ DEPOSIT INTO RACK ] " + isotope_names[i]
