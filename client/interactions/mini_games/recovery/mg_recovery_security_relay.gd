class_name MGRecoverySecurityRelay
extends MiniGameBase

## Phase 2 Blackout Recovery: Security Relay (Security / Security Room)
## Realig optical encrypted security links to restore perimeter surveillance and door locks.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var aligned_relays: Array[bool] = [false, false, false]
var relay_buttons: Array[Button] = []
var relay_names: Array[String] = ["OPTICAL SENSOR RELAY R-01", "ENCRYPTED KEYSTREAM TRANSCEIVER R-02", "PERIMETER LOCK CONTROLLER R-03"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Security Relay Alignment Terminal",
		"Align optical transceiver nodes to restore security monitoring parity.",
		Vector2(640, 460),
		MiniGameUIHelper.COLOR_BORDER_AMBER
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(3):
		var btn = Button.new()
		btn.text = "[ REALIGN OPTICAL PATH ] " + relay_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var r_idx = i
		btn.pressed.connect(func(): _on_relay_pressed(r_idx))
		vbox.add_child(btn)
		relay_buttons.append(btn)

func _on_relay_pressed(idx: int) -> void:
	if not is_active() or aligned_relays[idx]: return

	aligned_relays[idx] = true
	relay_buttons[idx].disabled = true
	relay_buttons[idx].text = "✔ [LOCKED] " + relay_names[idx]
	relay_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	var count = 0
	for a in aligned_relays:
		if a: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "SECURITY RELAYS: %d/3 NODES ALIGNED" % count

	if count == 3:
		ui_elements["status_label"].text = "SECURITY RELAY RESTORED: SENSOR GRIDS RE-ESTABLISHED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	aligned_relays = [false, false, false]
	for i in range(relay_buttons.size()):
		relay_buttons[i].disabled = false
		relay_buttons[i].text = "[ REALIGN OPTICAL PATH ] " + relay_names[i]
