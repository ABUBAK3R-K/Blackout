class_name MGMeltdownStabilizeOrion
extends MiniGameBase

## Phase 4 Meltdown Emergency Task: Stabilize ORION (ORION Core Room)
## Insert and lock all 4 neutron absorbing control rods to halt supercritical core runaway.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_step: int = 0
const TOTAL_RODS: int = 4
var rod_buttons: Array[Button] = []
var rod_names: Array[String] = [
	"1. DRIVE BORON ABSORPTION CONTROL ROD ALPHA",
	"2. DRIVE HAFNIUM ABSORPTION CONTROL ROD BETA",
	"3. DRIVE CADMIUM ABSORPTION CONTROL ROD GAMMA",
	"4. ENGAGE FINAL MAGNETIC SCRAM CLAMP DELTA"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"MELTDOWN EMERGENCY: STABILIZE ORION",
		"CRITICAL: Insert reactor control rods to suppress runaway supercritical fission.",
		Vector2(660, 480),
		MiniGameUIHelper.COLOR_BORDER_RED
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(TOTAL_RODS):
		var btn = Button.new()
		btn.text = "[ DISENGAGED ] " + rod_names[i]
		btn.custom_minimum_size = Vector2(480, 44)
		btn.disabled = (i != 0)
		var r_idx = i
		btn.pressed.connect(func(): _on_rod_pressed(r_idx))
		vbox.add_child(btn)
		rod_buttons.append(btn)

	ui_elements["status_label"].text = "ALARM: CRITICALITY LEVEL 99.8%! INSERT CONTROL ROD 1."

func _on_rod_pressed(idx: int) -> void:
	if not is_active(): return
	if idx != current_step: return

	rod_buttons[idx].disabled = true
	rod_buttons[idx].text = "✔ [INSERTED & LOCKED] " + rod_names[idx]
	rod_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
	current_step += 1

	var p = float(current_step) / float(TOTAL_RODS)
	set_progress(p)

	if current_step < TOTAL_RODS:
		rod_buttons[current_step].disabled = false
		ui_elements["status_label"].text = "CONTROL ROD INSERTION: %d/%d RODS LOCKED" % [current_step, TOTAL_RODS]
	else:
		ui_elements["status_label"].text = "REACTOR SCRAM COMPLETE: ORION CORE STABILIZED!"
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_step = 0
	for i in range(rod_buttons.size()):
		rod_buttons[i].disabled = (i != 0)
		rod_buttons[i].text = "[ DISENGAGED ] " + rod_names[i]
		rod_buttons[i].remove_theme_color_override("font_color")
