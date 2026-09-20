class_name MGCoolantSystem
extends MiniGameBase

## Phase 1 Crew Task: Coolant System (Engineering)
## Regulate cryogenic coolant valve to suppress engineering thermal overload.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var temperature: float = 180.0
const NOMINAL_TEMP: float = 40.0
var temp_label: Label = null
var valve_slider: HSlider = null
var is_venting: bool = false

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Engineering Thermal Exchange",
		"Open coolant regulator valve to purge core manifold heat to < 40°C.",
		Vector2(620, 450),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	temp_label = Label.new()
	temp_label.text = "CORE TEMPERATURE: 180.0°C [THERMAL OVERLOAD]"
	temp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	temp_label.add_theme_font_size_override("font_size", 16)
	temp_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_RED)
	vbox.add_child(temp_label)

	var instructions = Label.new()
	instructions.text = "ADJUST COOLANT PURGE FLOW RATE (0% - 100%)"
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_MUTED)
	vbox.add_child(instructions)

	valve_slider = HSlider.new()
	valve_slider.min_value = 0.0
	valve_slider.max_value = 100.0
	valve_slider.value = 0.0
	valve_slider.custom_minimum_size = Vector2(400, 36)
	vbox.add_child(valve_slider)

	var vent_btn = Button.new()
	vent_btn.text = "ENGAGE CRYOGENIC FLUSH"
	vent_btn.custom_minimum_size = Vector2(240, 44)
	vent_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vent_btn.pressed.connect(func(): _on_flush_step())
	vbox.add_child(vent_btn)

func _process(delta: float) -> void:
	if not is_active(): return
	var flow_rate = valve_slider.value / 100.0 # 0.0 to 1.0
	if flow_rate > 0.1:
		_cool_down(flow_rate * 35.0 * delta)

func _on_flush_step() -> void:
	if not is_active(): return
	valve_slider.value = 100.0
	_cool_down(30.0)

func _cool_down(amount: float) -> void:
	temperature = maxf(NOMINAL_TEMP, temperature - amount)
	var p = 1.0 - ((temperature - NOMINAL_TEMP) / (180.0 - NOMINAL_TEMP))
	set_progress(p)

	temp_label.text = "CORE TEMPERATURE: %.1f°C %s" % [
		temperature,
		"[NOMINAL]" if temperature <= NOMINAL_TEMP else "[COOLING ACTIVE]"
	]

	if temperature <= NOMINAL_TEMP:
		temp_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_SUCCESS_GREEN)
		ui_elements["status_label"].text = "COOLANT STABILIZED: THERMAL DUMP COMPLETE."
		complete_interaction()
	else:
		temp_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_AMBER)
		ui_elements["status_label"].text = "PURGING CRYOGENIC MANIFOLD..."

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	temperature = 180.0
	if valve_slider != null:
		valve_slider.value = 0.0
		temp_label.text = "CORE TEMPERATURE: 180.0°C [THERMAL OVERLOAD]"
		temp_label.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_RED)
