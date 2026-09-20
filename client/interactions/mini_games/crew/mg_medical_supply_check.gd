class_name MGMedicalSupplyCheck
extends MiniGameBase

## Phase 1 Crew Task: Medical Supply Check (MedBay)
## Perform biometric vial verification and cold-storage cataloging on 3 specimen lots.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var verified_lots: Array[bool] = [false, false, false]
var lot_buttons: Array[Button] = []
var lot_names: Array[String] = ["SPECIMEN-09: CRYOPRESERVED SERUM", "BIO-PACK-14: STABILIZER COMPOUND", "CULTURE-22: CELLULAR REAGENT"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"MedBay Cold Storage Catalog",
		"Scan and record barometric seal integrity for each medical specimen lot.",
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
		btn.text = "[ SCAN & SEAL ] " + lot_names[i]
		btn.custom_minimum_size = Vector2(420, 44)
		var lot_idx = i
		btn.pressed.connect(func(): _on_lot_scanned(lot_idx))
		vbox.add_child(btn)
		lot_buttons.append(btn)

func _on_lot_scanned(idx: int) -> void:
	if not is_active() or verified_lots[idx]:
		return

	verified_lots[idx] = true
	lot_buttons[idx].disabled = true
	lot_buttons[idx].text = "✔ " + lot_names[idx] + " [VERIFIED]"
	lot_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	var count = 0
	for v in verified_lots:
		if v: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "LOGGED SPECIMEN: %d/3 LOTS AUDITED" % count

	if count == 3:
		ui_elements["status_label"].text = "AUDIT COMPLETE: ALL SPECIMENS SEALED AND ACCOUNTED FOR."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	verified_lots = [false, false, false]
	for i in range(lot_buttons.size()):
		lot_buttons[i].disabled = false
		lot_buttons[i].text = "[ SCAN & SEAL ] " + lot_names[i]
