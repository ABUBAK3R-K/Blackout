class_name MGRecoveryPowerRouting
extends MiniGameBase

## Phase 2 Blackout Recovery: Power Routing (Electrical / Power Room)
## Reroute high-voltage facility lines across three isolated substation sectors.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var routed_sectors: Array[bool] = [false, false, false]
var sector_buttons: Array[Button] = []
var sector_names: Array[String] = ["FEEDER SECTOR ALPHA (LABS / MEDBAY)", "FEEDER SECTOR BETA (SECURITY / COMM)", "FEEDER SECTOR GAMMA (ORION / ENGINE)"]

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Substation Routing Terminal",
		"Re-energize bypass bus relays across all 3 facility power sectors.",
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
		btn.text = "[ ENGAGE BYPASS RELAY ] " + sector_names[i]
		btn.custom_minimum_size = Vector2(460, 46)
		var s_idx = i
		btn.pressed.connect(func(): _on_sector_pressed(s_idx))
		vbox.add_child(btn)
		sector_buttons.append(btn)

func _on_sector_pressed(idx: int) -> void:
	if not is_active() or routed_sectors[idx]: return

	routed_sectors[idx] = true
	sector_buttons[idx].disabled = true
	sector_buttons[idx].text = "✔ [ROUTED] " + sector_names[idx]
	sector_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)

	var count = 0
	for r in routed_sectors:
		if r: count += 1

	var p = float(count) / 3.0
	set_progress(p)
	ui_elements["status_label"].text = "POWER ROUTING: %d/3 SECTORS RESTORED" % count

	if count == 3:
		ui_elements["status_label"].text = "FACILITY POWER ROUTING ONLINE: SECTOR GRIDS CONNECTED."
		complete_interaction()

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	routed_sectors = [false, false, false]
	for i in range(sector_buttons.size()):
		sector_buttons[i].disabled = false
		sector_buttons[i].text = "[ ENGAGE BYPASS RELAY ] " + sector_names[i]
