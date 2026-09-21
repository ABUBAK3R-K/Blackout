class_name MGMeltdownRestoreCooling
extends MiniGameBase

## Phase 4 Meltdown Emergency Task: Restore Cooling (Cryogenic Hub)
## Force-purge thermal locks and activate emergency liquid nitrogen deluge pumps.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_step: int = 0
const TOTAL_STEPS: int = 4
var pump_buttons: Array[Button] = []
var step_names: Array[String] = [
	"1. BLOW CRYO MANIFOLD HIGH-PRESSURE RELIEF POPPET",
	"2. ENGAGE PRIMARY LIQUID NITROGEN FLOOD PUMP",
	"3. PURGE SUPERHEATED STEAM AIRLOCK VAPOR",
	"4. LOCK CRYO INJECTION LOOP TO 100% FLOOD RATE"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"MELTDOWN EMERGENCY: RESTORE COOLING",
		"CRITICAL: Quench runaway thermal core temperature before containment failure.",
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
		btn.pressed.connect(func(): _on_pump_step_pressed(s_idx))
		vbox.add_child(btn)
		pump_buttons.append(btn)

	ui_elements["status_label"].text = "ALARM: CORE TEMPERATURE CRITICAL! COMMENCE NITROGEN DELUGE."

func _on_pump_step_pressed(idx: int) -> void:
	if not is_active(): return
	if idx != current_step: return

	pump_buttons[idx].disabled = true
	pump_buttons[idx].text = "✔ [COOLANT FLOWING] " + step_names[idx]
	pump_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
	current_step += 1

	var p = float(current_step) / float(TOTAL_STEPS)
	set_progress(p)

	if current_step < TOTAL_STEPS:
		pump_buttons[current_step].disabled = false
		ui_elements["status_label"].text = "COOLANT FLOOD: STAGE %d/%d PURGED" % [current_step, TOTAL_STEPS]
	else:
		ui_elements["status_label"].text = "CRYO FLOOD ACTIVE: RUNAWAY THERMAL DRIFT HALTED!"
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_step = 0
	for i in range(pump_buttons.size()):
		pump_buttons[i].disabled = (i != 0)
		pump_buttons[i].text = "[ INACTIVE ] " + step_names[i]
		pump_buttons[i].remove_theme_color_override("font_color")
