class_name MiniGameUIHelper
extends RefCounted

## Utility helper providing uniform sci-fi research facility visual styling
## for BLACKOUT mini-games (Member 4).

const COLOR_BG_DIM: Color = Color(0.02, 0.04, 0.08, 0.85)
const COLOR_PANEL_BG: Color = Color(0.08, 0.11, 0.16, 0.96)
const COLOR_BORDER_CYAN: Color = Color(0.0, 0.85, 0.95, 0.9)
const COLOR_BORDER_AMBER: Color = Color(1.0, 0.75, 0.1, 0.9)
const COLOR_BORDER_RED: Color = Color(0.95, 0.2, 0.2, 0.9)
const COLOR_TEXT_PRIMARY: Color = Color(0.92, 0.96, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.6, 0.7, 0.8)
const COLOR_SUCCESS_GREEN: Color = Color(0.2, 0.9, 0.4)

## Creates the standard modal backdrop and stylized central terminal panel.
static func create_modal_layout(
	parent: Control,
	title_text: String,
	subtitle_text: String,
	panel_size: Vector2 = Vector2(640, 500),
	accent_color: Color = COLOR_BORDER_CYAN
) -> Dictionary:
	# 1. Fullscreen Dimmer Backdrop
	var backdrop = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = COLOR_BG_DIM
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(backdrop)

	# 2. Central Panel Container
	var center = CenterContainer.new()
	center.name = "CenterContainer"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)

	var panel = PanelContainer.new()
	panel.name = "MainPanel"
	panel.custom_minimum_size = panel_size

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL_BG
	panel_style.border_width_bottom = 2
	panel_style.border_width_top = 2
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_color = accent_color
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.content_margin_left = 20
	panel_style.content_margin_right = 20
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	# 3. Inner Vertical Layout
	var vbox = VBoxContainer.new()
	vbox.name = "RootVBox"
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 4. Header Bar (Title + Subtitle + Close Button)
	var header_bar = HBoxContainer.new()
	vbox.add_child(header_bar)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_bar.add_child(title_box)

	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = title_text.to_upper()
	title_label.add_theme_color_override("font_color", accent_color)
	title_label.add_theme_font_size_override("font_size", 18)
	title_box.add_child(title_label)

	var subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = subtitle_text
	subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	subtitle_label.add_theme_font_size_override("font_size", 12)
	title_box.add_child(subtitle_label)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = " [ESC] CLOSE "
	close_btn.custom_minimum_size = Vector2(100, 32)
	header_bar.add_child(close_btn)

	# 5. Content / Puzzle Mount Area
	var content_area = MarginContainer.new()
	content_area.name = "ContentArea"
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(content_area)

	# 6. Footer (Progress Bar + Status feedback)
	var footer_box = VBoxContainer.new()
	footer_box.name = "FooterBox"
	footer_box.add_theme_constant_override("separation", 4)
	vbox.add_child(footer_box)

	var progress_bar = ProgressBar.new()
	progress_bar.name = "ProgressBar"
	progress_bar.min_value = 0.0
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	progress_bar.custom_minimum_size = Vector2(0, 16)
	progress_bar.show_percentage = false
	footer_box.add_child(progress_bar)

	var status_bar = HBoxContainer.new()
	footer_box.add_child(status_bar)

	var status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "STATUS: SYSTEM AWAITING INPUT"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	status_label.add_theme_font_size_override("font_size", 12)
	status_bar.add_child(status_label)

	var percent_label = Label.new()
	percent_label.name = "PercentLabel"
	percent_label.text = "0%"
	percent_label.add_theme_color_override("font_color", accent_color)
	percent_label.add_theme_font_size_override("font_size", 12)
	status_bar.add_child(percent_label)

	return {
		"panel": panel,
		"title_label": title_label,
		"subtitle_label": subtitle_label,
		"close_button": close_btn,
		"content_area": content_area,
		"progress_bar": progress_bar,
		"status_label": status_label,
		"percent_label": percent_label
	}
