class_name MGMeltdownRestorePower
extends MiniGameBase

## Phase 4 Meltdown Emergency Task: Restore Power (Reactor Substation)
## Execute black-start ignition sequence to restore core containment power before meltdown.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_step: int = 0
const TOTAL_STEPS: int = 4
var step_buttons: Array[Button] = []
var step_names: Array[String] = [
	"1. DEPLOY BLACK-START AUXILIARY CAPACITORS",
	"2. ENGAGE HIGH-VOLTAGE SUBSTATION BUS TIE",
	"3. SYNCHRONIZE REACTOR GENERATOR FREQUENCY",
	"4. LOCK EMERGENCY CONTAINMENT POWER GRID"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"MELTDOWN EMERGENCY: RESTORE POWER",
		"CRITICAL: Black-start main containment reactor bus before core breaches.",
		Vector2(660, 480),
		MiniGameUIHelper.COLOR_BORDER_RED
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(TOTAL_STEPS):
		var btn = Button.new()
		btn.text = "[ INACTIVE ] " + step_names[i]
		btn.custom_minimum_size = Vector2(480, 44)
		btn.disabled = (i != 0)
		var s_idx = i
		btn.pressed.connect(func(): _on_step_pressed(s_idx))
		vbox.add_child(btn)
		step_buttons.append(btn)

	ui_elements["status_label"].text = "ALARM: CONTAINMENT POWER OFFLINE! BEGIN STEP 1."

func _on_step_pressed(idx: int) -> void:
	if not is_active(): return
	if idx != current_step: return

	step_buttons[idx].disabled = true
	step_buttons[idx].text = "✔ [RESTORED] " + step_names[idx]
	step_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
	current_step += 1

	var p = float(current_step) / float(TOTAL_STEPS)
	set_progress(p)

	if current_step < TOTAL_STEPS:
		step_buttons[current_step].disabled = false
		ui_elements["status_label"].text = "EMERGENCY POWER RESTORATION: STEP %d/%d COMPLETE" % [current_step, TOTAL_STEPS]
	else:
		ui_elements["status_label"].text = "CONTAINMENT POWER ONLINE: SUBSTATION BUS ENERGIZED!"
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_step = 0
	for i in range(step_buttons.size()):
		step_buttons[i].disabled = (i != 0)
		step_buttons[i].text = "[ INACTIVE ] " + step_names[i]
		step_buttons[i].remove_theme_color_override("font_color")
