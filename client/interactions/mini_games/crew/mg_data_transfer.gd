class_name MGDataTransfer
extends MiniGameBase

## Phase 1 Crew Task: Data Transfer (Comms)
## Establish carrier signal and transmit research telemetry packets to orbital relay.

const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var ui_elements: Dictionary = {}
var is_transferring: bool = false
var transfer_speed: float = 0.35 # Completes in ~3 seconds of active transfer
var transfer_btn: Button = null

func _ready() -> void:
	super._ready()
	_build_ui()

func _build_ui() -> void:
	ui_elements = MiniGameUIHelper.create_modal_layout(
		self,
		"Communications Data Uplink",
		"Initiate encrypted orbital carrier link and transmit encrypted packets.",
		Vector2(620, 440),
		MiniGameUIHelper.COLOR_BORDER_CYAN
	)
	ui_elements["close_button"].pressed.connect(func(): cancel_interaction("closed_by_user"))

	var content_area: MarginContainer = ui_elements["content_area"]
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_area.add_child(vbox)

	var info_lbl = Label.new()
	info_lbl.text = "TARGET: ORBITAL RELAY SAT-04 | BANDWIDTH: 1.2 GB/s"
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_lbl.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_PRIMARY)
	vbox.add_child(info_lbl)

	transfer_btn = Button.new()
	transfer_btn.text = "START DATA UPLINK"
	transfer_btn.custom_minimum_size = Vector2(260, 48)
	transfer_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	transfer_btn.pressed.connect(_on_transfer_pressed)
	vbox.add_child(transfer_btn)

func _process(delta: float) -> void:
	if not is_active() or not is_transferring:
		return

	var next_p = progress + (transfer_speed * delta)
	set_progress(next_p)
	ui_elements["status_label"].text = "TRANSMITTING PACKETS... %.0f KB/s" % (progress * 12400.0)

	if progress >= 1.0:
		is_transferring = false
		transfer_btn.disabled = true
		transfer_btn.text = "UPLINK COMPLETE"
		ui_elements["status_label"].text = "DATA TRANSFER CONFIRMED: 100% TELEMETRY SYNCED."
		complete_interaction()

func _on_transfer_pressed() -> void:
	if not is_active(): return
	is_transferring = true
	transfer_btn.disabled = true
	transfer_btn.text = "TRANSMITTING..."

func _on_progress_changed(new_p: float) -> void:
	if ui_elements.has("progress_bar"):
		ui_elements["progress_bar"].value = new_p
		ui_elements["percent_label"].text = "%d%%" % int(new_p * 100.0)

func _reset_mini_game() -> void:
	is_transferring = false
	if transfer_btn != null:
		transfer_btn.disabled = false
		transfer_btn.text = "START DATA UPLINK"
