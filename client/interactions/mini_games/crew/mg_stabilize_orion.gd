class_name MGStabilizeOrion
extends MiniGameBase

## Phase 1 Crew Task: Stabilize ORION (Orion Core)
## Calibrate 3 harmonic frequency stages to damp core resonance fluctuations.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var current_stage: int = 0
const TOTAL_STAGES: int = 3

var target_ranges: Array[Vector2] = [
	Vector2(40.0, 55.0),
	Vector2(65.0, 78.0),
	Vector2(20.0, 35.0)
]

var slider: HSlider = null
var freq_label: Label = null
var lock_button: Button = null
var stage_label: Label = null

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"ORION Core Harmonic Stabilizer",
		"Align frequency slider to harmonic resonance target zone, then lock phase.",
		Vector2(620, 440),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	stage_label = Label.new()
	stage_label.text = "HARMONIC PHASE: 1 OF 3"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage_label.add_theme_font_size_override("font_size", 16)
	stage_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_PRIMARY)
	vbox.add_child(stage_label)

	freq_label = Label.new()
	freq_label.text = "CURRENT RESONANCE: 50.0 GHz | TARGET: [40.0 - 55.0] GHz"
	freq_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	freq_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)
	vbox.add_child(freq_label)

	slider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.value = 50.0
	slider.custom_minimum_size = Vector2(400, 36)
	slider.value_changed.connect(_on_slider_changed)
	vbox.add_child(slider)

	lock_button = Button.new()
	lock_button.text = "ENGAGE HARMONIC LOCK"
	lock_button.custom_minimum_size = Vector2(240, 44)
	lock_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock_button.pressed.connect(_on_lock_pressed)
	vbox.add_child(lock_button)

	_update_stage_view()

func _on_slider_changed(val: float) -> void:
	if not is_active(): return
	var target = target_ranges[current_stage]
	var in_range = val >= target.x and val <= target.y

	freq_label.text = "CURRENT RESONANCE: %.1f GHz | TARGET: [%.1f - %.1f] GHz" % [val, target.x, target.y]
	if in_range:
		freq_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
		lock_button.disabled = false
		ui_elements["status_label"].text = "STATUS: FREQUENCY ALIGNED. ENGAGE LOCK!"
	else:
		freq_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)
		lock_button.disabled = true
		ui_elements["status_label"].text = "STATUS: ADJUST SLIDER TO ENTER TARGET BAND"

func _on_lock_pressed() -> void:
	if not is_active(): return
	var val = slider.value
	var target = target_ranges[current_stage]
	if val >= target.x and val <= target.y:
		current_stage += 1
		var p = float(current_stage) / float(TOTAL_STAGES)
		set_progress(p)

		if current_stage >= TOTAL_STAGES:
			ui_elements["status_label"].text = "STATUS: ORION CORE DAMPERS LOCKED. STABILIZATION COMPLETE."
			complete_interaction()
		else:
			slider.value = 0.0
			_update_stage_view()

func _update_stage_view() -> void:
	stage_label.text = "HARMONIC PHASE: %d OF %d" % [current_stage + 1, TOTAL_STAGES]
	_on_slider_changed(slider.value)

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	current_stage = 0
	if slider != null:
		slider.value = 50.0
		_update_stage_view()
