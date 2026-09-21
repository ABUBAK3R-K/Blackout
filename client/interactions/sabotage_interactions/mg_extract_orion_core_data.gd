class_name MGExtractOrionCoreData
extends MiniGameBase

## Phase 2 Impostor Sabotage Objective: Extract ORION Core Data (ORION Core)
## Siphon classified core containment metrics and injection telemetry.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_step: int = 0
const TOTAL_STEPS: int = 3
var siphon_buttons: Array[Button] = []
var step_names: Array[String] = [
	"1. INJECT MEMORY SIPHON WORM INTO TERMINAL",
	"2. EXTRACT ORION ANOMALY EQUATIONS (32.4 TB)",
	"3. SPOOF CRC CHECKSUM TO COVER TRACE"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"[RESTRICTED] ORION Core Data Siphon",
		"Exfiltrate core diagnostic logs into encrypted portable memory drive.",
		Vector2(640, 460),
		MiniGameUIHelper.COLOR_BORDER_RED
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(TOTAL_STEPS):
		var btn = Button.new()
		btn.text = "[ READY ] " + step_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		btn.disabled = (i != 0)
		var s_idx = i
		btn.pressed.connect(func(): _on_siphon_step_pressed(s_idx))
		vbox.add_child(btn)
		siphon_buttons.append(btn)

	ui_elements["status_label"].text = "STATUS: TERMINAL ACCESS GRANTED. INITIATE SIPHON."

func _on_siphon_step_pressed(idx: int) -> void:
	if not is_active(): return
	if idx != current_step: return

	siphon_buttons[idx].disabled = true
	siphon_buttons[idx].text = "✔ [SIPHONED] " + step_names[idx]
	siphon_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
	current_step += 1

	var p = float(current_step) / float(TOTAL_STEPS)
	set_progress(p)

	if current_step < TOTAL_STEPS:
		siphon_buttons[current_step].disabled = false
		ui_elements["status_label"].text = "STATUS: TRANSFERRING SECTOR DATA (%d/%d)..." % [current_step, TOTAL_STEPS]
	else:
		ui_elements["status_label"].text = "DATA SIPHON COMPLETE: CORE EQUATIONS COPIED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_step = 0
	for i in range(siphon_buttons.size()):
		siphon_buttons[i].disabled = (i != 0)
		siphon_buttons[i].text = "[ READY ] " + step_names[i]
		siphon_buttons[i].remove_theme_color_override("font_color")
