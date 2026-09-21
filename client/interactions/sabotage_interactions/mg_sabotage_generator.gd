class_name MGSabotageGenerator
extends MiniGameBase

## Phase 2 Impostor Sabotage Objective: Sabotage Generator (Generator Room)
## Sever power lines and install a high-voltage shorting shunt on the emergency generator.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var severed_lines: Array[bool] = [false, false, false]
var cut_buttons: Array[Button] = []
var line_names: Array[String] = [
	"PRIMARY EXCITER COUPLING CABLE",
	"AUXILIARY STATOR CURRENT FEED",
	"VOLTAGE REGULATION FEEDBACK SHUNT"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"[RESTRICTED] Generator Room Sabotage",
		"Sever auxiliary power connections to cripple backup facility electricity.",
		Vector2(640, 460),
		MiniGameUIHelper.COLOR_BORDER_RED
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(3):
		var btn = Button.new()
		btn.text = "[ SEVER CONDUIT ] " + line_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var l_idx = i
		btn.pressed.connect(func(): _on_line_cut_pressed(l_idx))
		vbox.add_child(btn)
		cut_buttons.append(btn)

func _on_line_cut_pressed(idx: int) -> void:
	if not is_active() or severed_lines[idx]: return

	severed_lines[idx] = true
	cut_buttons[idx].disabled = true
	cut_buttons[idx].text = "✔ [SEVERED] " + line_names[idx]
	cut_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_RED)

	var count = 0
	for s in severed_lines:
		if s: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "GENERATOR SABOTAGE: %d/3 CONDUITS SEVERED" % count

	if count == 3:
		ui_elements["status_label"].text = "GENERATOR ALTERNATOR SHORT-CIRCUITED. DAMAGE EVIDENCE CREATED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	severed_lines = [false, false, false]
	for i in range(cut_buttons.size()):
		cut_buttons[i].disabled = false
		cut_buttons[i].text = "[ SEVER CONDUIT ] " + line_names[i]
