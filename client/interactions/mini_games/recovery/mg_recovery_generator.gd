class_name MGRecoveryGenerator
extends MiniGameBase

## Phase 2 Blackout Recovery: Generator (Power / Generator Room)
## Prime fuel lines, charge flywheel capacitors, and fire the main generator starter.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_phase: int = 0
const TOTAL_PHASES: int = 3
var action_buttons: Array[Button] = []
var phase_labels: Array[String] = [
	"1. PRIME EMERGENCY DIESEL FUEL INJECTORS",
	"2. CHARGE MAGNETIC FLYWHEEL CAPACITORS",
	"3. ENGAGE HIGH-TORQUE TURBINE STARTER"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Emergency Generator Recovery Station",
		"Complete 3-step ignition protocol to restore auxiliary facility generator.",
		Vector2(640, 460),
		MiniGameUIHelper.COLOR_BORDER_AMBER
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(TOTAL_PHASES):
		var btn = Button.new()
		btn.text = "[ INACTIVE ] " + phase_labels[i]
		btn.custom_minimum_size = Vector2(460, 46)
		btn.disabled = (i != 0)
		var p_idx = i
		btn.pressed.connect(func(): _on_phase_pressed(p_idx))
		vbox.add_child(btn)
		action_buttons.append(btn)

	ui_elements["status_label"].text = "STATUS: AWAITING FUEL PRIMING (STEP 1)"

func _on_phase_pressed(idx: int) -> void:
	if not is_active(): return
	if idx != current_phase: return

	action_buttons[idx].disabled = true
	action_buttons[idx].text = "✔ [COMPLETED] " + phase_labels[idx]
	action_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
	current_phase += 1

	var p = float(current_phase) / float(TOTAL_PHASES)
	set_progress(p)

	if current_phase < TOTAL_PHASES:
		action_buttons[current_phase].disabled = false
		ui_elements["status_label"].text = "STATUS: STEP %d COMPLETE. ADVANCE TO NEXT STEP." % current_phase
	else:
		ui_elements["status_label"].text = "GENERATOR REIGNITED: AUXILIARY POWER RESTORED TO LOCAL GRID."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_phase = 0
	for i in range(action_buttons.size()):
		action_buttons[i].disabled = (i != 0)
		action_buttons[i].text = "[ INACTIVE ] " + phase_labels[i]
		action_buttons[i].remove_theme_color_override("font_color")
