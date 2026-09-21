class_name MGBackupPower
extends MiniGameBase

## Phase 1 Crew Task: Backup Power (Electrical)
## Sequence 5 auxiliary generator circuit breakers to restore auxiliary reserve battery.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_step: int = 0
const TOTAL_BREAKERS: int = 5
var breaker_buttons: Array[Button] = []

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Auxiliary Battery Breaker Panel",
		"Flip breakers in sequential numerical order [1 through 5] to energize backup grid.",
		Vector2(620, 460),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	for i in range(TOTAL_BREAKERS):
		var btn = Button.new()
		btn.text = "[ TRIPPED ] CIRCUIT BREAKER BRK-%02d" % (i + 1)
		btn.custom_minimum_size = Vector2(400, 40)
		var b_idx = i
		btn.pressed.connect(func(): _on_breaker_pressed(b_idx))
		vbox.add_child(btn)
		breaker_buttons.append(btn)

func _on_breaker_pressed(idx: int) -> void:
	if not is_active(): return

	if idx == current_step:
		breaker_buttons[idx].disabled = true
		breaker_buttons[idx].text = "✔ [ONLINE] CIRCUIT BREAKER BRK-%02d" % (idx + 1)
		breaker_buttons[idx].add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
		current_step += 1

		var p = float(current_step) / float(TOTAL_BREAKERS)
		set_progress(p)
		ui_elements["status_label"].text = "AUX GRID: %d/%d BREAKERS ENERGIZED" % [current_step, TOTAL_BREAKERS]

		if current_step >= TOTAL_BREAKERS:
			ui_elements["status_label"].text = "AUXILIARY RESERVE BATTERIES FULLY ENERGIZED."
			complete_interaction()
	else:
		ui_elements["status_label"].text = "SEQUENCE ERROR: Breakers must be energized in numerical order!"

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_step = 0
	for i in range(breaker_buttons.size()):
		breaker_buttons[i].disabled = false
		breaker_buttons[i].text = "[ TRIPPED ] CIRCUIT BREAKER BRK-%02d" % (i + 1)
