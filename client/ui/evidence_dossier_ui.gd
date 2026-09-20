class_name EvidenceDossierUI
extends Control

## Client-side Evidence Dossier / Investigation UI for BLACKOUT (Stage 21).
## Displays synchronized, server-authoritative factual evidence records during
## POST_BLACKOUT_INVESTIGATION and subsequent Meeting/Voting discussion phases.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

const NetworkConfig = preload("res://shared/network_config.gd")
const EvidenceConfig = preload("res://shared/evidence_config.gd")
const EvidenceDefinition = preload("res://shared/evidence_definition.gd")

signal dossier_opened()
signal dossier_closed()
signal filter_changed(filter_name: String)

## State flags
var is_active: bool = false
var is_dossier_open: bool = false
var current_filter: String = "ALL"

## Tracked public evidence records: Array of Dictionaries
var tracked_evidence: Array = []

## UI Node references
var main_panel: PanelContainer = null
var toggle_button: Button = null
var title_label: Label = null
var subtitle_label: Label = null
var count_badge: Label = null
var evidence_list_container: VBoxContainer = null
var empty_state_container: VBoxContainer = null
var filter_buttons: Dictionary = {} # filter_name (String) -> Button

func _ready() -> void:
	visible = false
	is_active = false
	is_dossier_open = false
	_ensure_ui_structure()
	_auto_connect_network_signals()

## Connects to NetworkManager client signals if present in the scene tree.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager signals for investigation lifecycle events.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("investigation_started") and not client_mgr.investigation_started.is_connected(_on_network_investigation_started):
		client_mgr.investigation_started.connect(_on_network_investigation_started)

	if client_mgr.has_signal("investigation_evidence_received") and not client_mgr.investigation_evidence_received.is_connected(_on_network_evidence_received):
		client_mgr.investigation_evidence_received.connect(_on_network_evidence_received)

	if client_mgr.has_signal("game_state_changed") and not client_mgr.game_state_changed.is_connected(_on_network_game_state_changed):
		client_mgr.game_state_changed.connect(_on_network_game_state_changed)

	if "investigation_evidence" in client_mgr and not client_mgr.investigation_evidence.is_empty():
		set_evidence_list(client_mgr.investigation_evidence)

# --- Public API & Lifecycle ---

## Activates the evidence dossier for POST_BLACKOUT_INVESTIGATION.
func activate_investigation(auto_open: bool = true) -> void:
	_ensure_ui_structure()
	is_active = true
	visible = true

	if toggle_button != null:
		toggle_button.visible = true

	if auto_open:
		open_dossier()
	else:
		close_dossier()

	print("[EvidenceDossierUI] Investigation phase active. Dossier ready (%d records)." % tracked_evidence.size())

## Opens the full Dossier list panel.
func open_dossier() -> void:
	_ensure_ui_structure()
	is_dossier_open = true
	if main_panel != null:
		main_panel.visible = true
	_update_ui_display()
	dossier_opened.emit()

## Closes/minimizes the Dossier list panel while maintaining the toggle button.
func close_dossier() -> void:
	is_dossier_open = false
	if main_panel != null:
		main_panel.visible = false
	dossier_closed.emit()

## Toggles open/closed state.
func toggle_dossier() -> void:
	if is_dossier_open:
		close_dossier()
	else:
		open_dossier()

## Sets the evidence list explicitly from authoritative server sync.
func set_evidence_list(evidence_list: Array) -> void:
	tracked_evidence = evidence_list.duplicate(true)
	_update_ui_display()
	print("[EvidenceDossierUI] Synchronized %d factual evidence records." % tracked_evidence.size())

## Sets the active filter category.
func set_filter(filter_name: String) -> void:
	current_filter = filter_name.to_upper()
	_update_filter_buttons()
	_rebuild_evidence_list()
	filter_changed.emit(current_filter)

## Resets and clears the Dossier.
func reset() -> void:
	is_active = false
	is_dossier_open = false
	current_filter = "ALL"
	tracked_evidence.clear()
	visible = false

	if main_panel != null:
		main_panel.visible = false
	if toggle_button != null:
		toggle_button.visible = false

	_clear_evidence_cards()
	print("[EvidenceDossierUI] Evidence Dossier reset.")

# --- Internal UI Construction & Population ---

func _update_ui_display() -> void:
	_ensure_ui_structure()

	# Update toggle button label with count
	if toggle_button != null:
		toggle_button.text = "🗎 EVIDENCE DOSSIER (%d)" % tracked_evidence.size()

	# Update count badge
	if count_badge != null:
		count_badge.text = "%d RECORD%s SYNCHRONIZED" % [
			tracked_evidence.size(),
			"S" if tracked_evidence.size() != 1 else ""
		]

	_update_filter_buttons()
	_rebuild_evidence_list()

func _update_filter_buttons() -> void:
	for f_key in filter_buttons.keys():
		var btn: Button = filter_buttons[f_key]
		if btn != null:
			if f_key == current_filter:
				btn.add_theme_color_override("font_color", Color(0.3, 0.95, 1.0, 1.0))
			else:
				btn.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85, 0.8))

func _rebuild_evidence_list() -> void:
	if evidence_list_container == null or empty_state_container == null:
		return

	_clear_evidence_cards()

	var filtered_list = _get_filtered_evidence()

	if filtered_list.is_empty():
		empty_state_container.visible = true
	else:
		empty_state_container.visible = false
		for ev_data in filtered_list:
			if ev_data is Dictionary:
				var card = _create_evidence_card(ev_data)
				evidence_list_container.add_child(card)

func _clear_evidence_cards() -> void:
	if evidence_list_container != null:
		for child in evidence_list_container.get_children():
			evidence_list_container.remove_child(child)
			child.queue_free()

func _get_filtered_evidence() -> Array:
	if current_filter == "ALL":
		return tracked_evidence

	var result: Array = []
	for ev in tracked_evidence:
		if not (ev is Dictionary):
			continue

		var cat: String = str(ev.get("category", "")).to_lower()
		var ev_type: String = str(ev.get("evidence_type", "")).to_lower()

		match current_filter:
			"SABOTAGE":
				if cat == "sabotage" or cat == "containment" or ev_type.contains("sabotaged") or ev_type.contains("containment"):
					result.append(ev)
			"RECOVERY":
				if cat == "recovery" or ev_type.contains("recovery") or ev_type.contains("restored"):
					result.append(ev)
			"DATA":
				if cat == "espionage" or cat == "data_theft" or cat == "security" or ev_type.contains("files") or ev_type.contains("data") or ev_type.contains("security"):
					result.append(ev)
			_:
				result.append(ev)

	return result

func _create_evidence_card(ev: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.name = "EvidenceCard_%s" % str(ev.get("evidence_id", "item"))
	card.custom_minimum_size = Vector2(480, 80)
	card.mouse_filter = Control.MOUSE_FILTER_PASS

	var severity_str = str(ev.get("severity", "info")).to_lower()
	var sev_color = _get_severity_color(severity_str)

	var card_style = StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.06, 0.1, 0.88)
	card_style.border_color = sev_color * Color(1, 1, 1, 0.65)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(6)
	card.add_theme_stylebox_override("panel", card_style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Row 1: [SEVERITY BADGE] [CATEGORY] ---- [TIMESTAMP]
	var top_hbox = HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(top_hbox)

	var sev_badge = Label.new()
	sev_badge.name = "SeverityBadge"
	sev_badge.text = "[%s]" % severity_str.to_upper()
	sev_badge.add_theme_font_size_override("font_size", 11)
	sev_badge.set("theme_override_colors/font_color", sev_color)
	top_hbox.add_child(sev_badge)

	var category_str = str(ev.get("category", "general")).to_upper()
	var cat_label = Label.new()
	cat_label.name = "CategoryLabel"
	cat_label.text = "•  %s" % category_str
	cat_label.add_theme_font_size_override("font_size", 10)
	cat_label.set("theme_override_colors/font_color", Color(0.65, 0.72, 0.82, 0.75))
	top_hbox.add_child(cat_label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(spacer)

	var raw_time = float(ev.get("timestamp", 0.0))
	var time_label = Label.new()
	time_label.name = "TimestampLabel"
	time_label.text = _format_timestamp(raw_time)
	time_label.add_theme_font_size_override("font_size", 11)
	time_label.set("theme_override_colors/font_color", Color(0.7, 0.8, 0.9, 0.8))
	top_hbox.add_child(time_label)

	# Row 2: Event Name & Location
	var mid_hbox = HBoxContainer.new()
	mid_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mid_hbox)

	var name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.text = str(ev.get("display_name", ev.get("evidence_type", "Unknown Event")))
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.set("theme_override_colors/font_color", Color(0.95, 0.96, 0.98, 1.0))
	mid_hbox.add_child(name_label)

	var loc_raw = str(ev.get("location_id", ev.get("source_system", "")))
	if not loc_raw.is_empty():
		var loc_label = Label.new()
		loc_label.name = "LocationLabel"
		loc_label.text = "📍 %s" % _format_location_name(loc_raw)
		loc_label.add_theme_font_size_override("font_size", 11)
		loc_label.set("theme_override_colors/font_color", Color(0.4, 0.85, 0.95, 0.85))
		mid_hbox.add_child(loc_label)

	# Row 3: Factual Objective Description
	var desc_label = Label.new()
	desc_label.name = "DescriptionLabel"
	desc_label.text = str(ev.get("description", "No additional observation logged."))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.set("theme_override_colors/font_color", Color(0.8, 0.84, 0.9, 0.9))
	vbox.add_child(desc_label)

	return card

func _get_severity_color(sev: String) -> Color:
	match sev.to_lower():
		"critical":
			return Color(1.0, 0.25, 0.25, 1.0) # Red
		"high":
			return Color(1.0, 0.6, 0.2, 1.0)   # Orange
		"medium":
			return Color(0.95, 0.85, 0.3, 1.0) # Yellow
		"info":
			return Color(0.3, 0.85, 1.0, 1.0)  # Cyan
		_:
			return Color(0.7, 0.8, 0.9, 1.0)

func _format_location_name(raw_loc: String) -> String:
	match raw_loc:
		"executive_office":
			return "Executive Office"
		"orion_core":
			return "ORION Core"
		"containment_hub":
			return "Containment Hub"
		"generator_room", "generator":
			return "Generator"
		"security_room", "security":
			return "Security"
		"lab":
			return "Laboratory"
		"station_subsystem":
			return "Facility Subsystem"
		_:
			return raw_loc.replace("_", " ").capitalize()

func _format_timestamp(unix_time: float) -> String:
	if unix_time <= 0.0:
		return "LOG TIME: --:--"
	var time_dict = Time.get_time_dict_from_unix_time(int(unix_time))
	return "LOG %02d:%02d:%02d" % [time_dict.hour, time_dict.minute, time_dict.second]

# --- Network Event Callbacks ---

func _on_network_investigation_started() -> void:
	activate_investigation(true)

func _on_network_evidence_received(evidence_list: Array) -> void:
	set_evidence_list(evidence_list)
	activate_investigation(true)

func _on_network_game_state_changed(new_state: NetworkConfig.GameState) -> void:
	if new_state == NetworkConfig.GameState.POST_BLACKOUT_INVESTIGATION:
		activate_investigation(true)
	elif new_state == NetworkConfig.GameState.MEETING or new_state == NetworkConfig.GameState.VOTING:
		# Keep toggle button available during meeting/voting so players can consult dossier
		if is_active:
			if toggle_button != null:
				toggle_button.visible = true
	elif new_state == NetworkConfig.GameState.MELTDOWN or new_state == NetworkConfig.GameState.GAME_OVER:
		close_dossier()
		if toggle_button != null:
			toggle_button.visible = false
		is_active = false
		visible = false
	elif new_state == NetworkConfig.GameState.LOBBY:
		reset()

# --- Programmatic UI Layout Structure ---

func _ensure_ui_structure() -> void:
	if main_panel != null:
		return

	# Root Control fills viewport but passes mouse events so player can still move
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 1. Floating Toggle Button (Top Right corner under round tracker)
	toggle_button = Button.new()
	toggle_button.name = "DossierToggleButton"
	toggle_button.text = "🗎 EVIDENCE DOSSIER (0)"
	toggle_button.custom_minimum_size = Vector2(190, 32)
	toggle_button.anchors_preset = Control.PRESET_TOP_RIGHT
	toggle_button.anchor_left = 1.0
	toggle_button.anchor_right = 1.0
	toggle_button.offset_left = -210.0
	toggle_button.offset_top = 108.0
	toggle_button.offset_right = -20.0
	toggle_button.offset_bottom = 142.0
	toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	toggle_button.add_theme_font_size_override("font_size", 11)
	toggle_button.pressed.connect(toggle_dossier)
	add_child(toggle_button)

	# 2. Main Dossier Modal Panel (Right Docked overlay)
	main_panel = PanelContainer.new()
	main_panel.name = "MainDossierPanel"
	main_panel.custom_minimum_size = Vector2(520, 460)
	main_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	main_panel.anchor_left = 1.0
	main_panel.anchor_right = 1.0
	main_panel.offset_left = -540.0
	main_panel.offset_top = 148.0
	main_panel.offset_right = -20.0
	main_panel.offset_bottom = 628.0
	main_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.12, 0.96)
	panel_style.border_color = Color(0.25, 0.75, 0.95, 0.85)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	panel_style.shadow_size = 8
	main_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(main_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	main_panel.add_child(margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(main_vbox)

	# --- HEADER ---
	var header_hbox = HBoxContainer.new()
	main_vbox.add_child(header_hbox)

	var title_vbox = VBoxContainer.new()
	title_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_vbox.add_theme_constant_override("separation", 2)
	header_hbox.add_child(title_vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "EVIDENCE DOSSIER"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.set("theme_override_colors/font_color", Color(0.3, 0.9, 1.0, 1.0))
	title_vbox.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.name = "SubtitleLabel"
	subtitle_label.text = "POST-BLACKOUT INVESTIGATION"
	subtitle_label.add_theme_font_size_override("font_size", 10)
	subtitle_label.set("theme_override_colors/font_color", Color(0.7, 0.78, 0.88, 0.8))
	title_vbox.add_child(subtitle_label)

	count_badge = Label.new()
	count_badge.name = "CountBadge"
	count_badge.text = "0 RECORDS SYNCHRONIZED"
	count_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_badge.add_theme_font_size_override("font_size", 10)
	count_badge.set("theme_override_colors/font_color", Color(1.0, 0.85, 0.3, 1.0))
	header_hbox.add_child(count_badge)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(close_dossier)
	header_hbox.add_child(close_btn)

	var sep1 = HSeparator.new()
	main_vbox.add_child(sep1)

	# --- FILTER BAR ---
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(filter_hbox)

	var filters = [
		{"id": "ALL", "name": "ALL"},
		{"id": "SABOTAGE", "name": "SABOTAGE"},
		{"id": "RECOVERY", "name": "RECOVERY"},
		{"id": "DATA", "name": "DATA & ESPIONAGE"}
	]

	for f in filters:
		var btn = Button.new()
		btn.name = "Filter_%s" % f.id
		btn.text = f.name
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 10)
		var f_id = f.id
		btn.pressed.connect(func(): set_filter(f_id))
		filter_hbox.add_child(btn)
		filter_buttons[f.id] = btn

	var sep2 = HSeparator.new()
	main_vbox.add_child(sep2)

	# --- EVIDENCE SCROLL CONTAINER ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)

	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(scroll_vbox)

	evidence_list_container = VBoxContainer.new()
	evidence_list_container.name = "EvidenceList"
	evidence_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	evidence_list_container.add_theme_constant_override("separation", 8)
	scroll_vbox.add_child(evidence_list_container)

	# --- EMPTY STATE ---
	empty_state_container = VBoxContainer.new()
	empty_state_container.name = "EmptyState"
	empty_state_container.alignment = BoxContainer.ALIGNMENT_CENTER
	empty_state_container.custom_minimum_size = Vector2(0, 180)
	empty_state_container.add_theme_constant_override("separation", 6)
	scroll_vbox.add_child(empty_state_container)

	var empty_title = Label.new()
	empty_title.name = "EmptyTitle"
	empty_title.text = "NO EVIDENCE RECORDED"
	empty_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_title.add_theme_font_size_override("font_size", 14)
	empty_title.set("theme_override_colors/font_color", Color(0.65, 0.7, 0.8, 0.85))
	empty_state_container.add_child(empty_title)

	var empty_desc = Label.new()
	empty_desc.name = "EmptyDescription"
	empty_desc.text = "No synchronized evidence has been recorded for this investigation phase."
	empty_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_desc.add_theme_font_size_override("font_size", 11)
	empty_desc.set("theme_override_colors/font_color", Color(0.5, 0.55, 0.65, 0.75))
	empty_state_container.add_child(empty_desc)
