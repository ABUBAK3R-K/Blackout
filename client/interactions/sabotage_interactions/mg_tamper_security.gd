class_name MGTamperSecurity
extends MiniGameBase

## Phase 2 Impostor Sabotage Objective: Tamper With Security (Security Room)
## Corrupt CCTV sensor logs and inject optical noise scramblers into security feeds.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var scrambled_nodes: Array[bool] = [false, false, false]
var tamper_buttons: Array[Button] = []
var node_names: Array[String] = [
	"CORRUPT SURVEILLANCE BUFFER LOGS",
	"INJECT OPTICAL NOISE ON CORRIDOR CAMS",
	"OVERWRITE BIOMETRIC SENSOR TIMESTAMPS"
]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"[RESTRICTED] Security Subsystem Tamper",
		"Scramble surveillance logs to obstruct crew post-blackout investigation.",
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
		btn.text = "[ EXECUTE TAMPER ] " + node_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var t_idx = i
		btn.pressed.connect(func(): _on_tamper_pressed(t_idx))
		vbox.add_child(btn)
		tamper_buttons.append(btn)

func _on_tamper_pressed(idx: int) -> void:
	if not is_active() or scrambled_nodes[idx]: return

	scrambled_nodes[idx] = true
	tamper_buttons[idx].disabled = true
	tamper_buttons[idx].text = "✔ [CORRUPTED] " + node_names[idx]
	tamper_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_RED)

	var count = 0
	for s in scrambled_nodes:
		if s: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "SECURITY TAMPER: %d/3 LOG SYSTEMS SCRAMBLED" % count

	if count == 3:
		ui_elements["status_label"].text = "SURVEILLANCE LOGS SCRAMBLED. INVESTIGATION NOISE GENERATED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	scrambled_nodes = [false, false, false]
	for i in range(tamper_buttons.size()):
		tamper_buttons[i].disabled = false
		tamper_buttons[i].text = "[ EXECUTE TAMPER ] " + node_names[i]
