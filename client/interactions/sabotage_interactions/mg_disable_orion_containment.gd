class_name MGDisableOrionContainment
extends MiniGameBase

## Phase 2 Impostor Sabotage Objective: Disable ORION Containment (Containment Hub)
## Disengage magnetic containment dampening field coils to induce plasma instability.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var disabled_coils: Array[bool] = [false, false, false]
var coil_buttons: Array[Button] = []
var coil_names: Array[String] = ["MAGNETIC FIELD EMITTER COIL-A", "PLASMA TOROID COMPRESSOR COIL-B", "FLUX INVERSION STABILIZER COIL-C"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"[RESTRICTED] Containment Hub Override",
		"De-energize all 3 magnetic containment fields to induce core resonance drift.",
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
		btn.text = "[ DE-ENERGIZE INTERLOCK ] " + coil_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var c_idx = i
		btn.pressed.connect(func(): _on_coil_pressed(c_idx))
		vbox.add_child(btn)
		coil_buttons.append(btn)

func _on_coil_pressed(idx: int) -> void:
	if not is_active() or disabled_coils[idx]: return

	disabled_coils[idx] = true
	coil_buttons[idx].disabled = true
	coil_buttons[idx].text = "✔ [FIELD COLLAPSED] " + coil_names[idx]
	coil_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_RED)

	var count = 0
	for d in disabled_coils:
		if d: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "CONTAINMENT FIELD INTEGRITY: %d/3 COILS CRITICAL" % count

	if count == 3:
		ui_elements["status_label"].text = "CONTAINMENT FIELD OFFLINE: CORE INSTABILITY SURGING."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	disabled_coils = [false, false, false]
	for i in range(coil_buttons.size()):
		coil_buttons[i].disabled = false
		coil_buttons[i].text = "[ DE-ENERGIZE INTERLOCK ] " + coil_names[i]
