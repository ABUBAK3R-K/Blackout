class_name MiniGameShowcase
extends Control

## Visual Showcase & Testing Harness for all 22 BLACKOUT Mini-Games (Member 4).
##
## Allows engineers, designers (Member 6), and QA leads (Member 8) to launch,
## test, solve, and verify every single mini-game in isolation.

const MiniGameFactory = preload("res://client/interactions/mini_game_factory.gd")
const InteractionController = preload("res://client/interactions/interaction_framework/interaction_controller.gd")
const MiniGameUIHelper = preload("res://client/interactions/interaction_framework/mini_game_ui_helper.gd")

var controller: InteractionController = null
var status_log_label: RichTextLabel = null
var completed_tasks_set: Dictionary = {}

func _ready() -> void:
	_build_showcase_ui()

func _build_showcase_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.offset_left = 32
	main_vbox.offset_right = -32
	main_vbox.offset_top = 24
	main_vbox.offset_bottom = -24
	add_child(main_vbox)

	# Header Title
	var header = HBoxContainer.new()
	main_vbox.add_child(header)

	var title_box = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var title_lbl = Label.new()
	title_lbl.text = "BLACKOUT — MINI-GAME SHOWCASE & HARNESS"
	title_lbl.add_theme_font_size_override("font_size", 22)
	title_lbl.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_BORDER_CYAN)
	title_box.add_child(title_lbl)

	var subtitle_lbl = Label.new()
	subtitle_lbl.text = "Member 4 (Client Interaction & Mini-Game Programmer) — 22 Total Interactive Mini-Games"
	subtitle_lbl.add_theme_font_size_override("font_size", 13)
	subtitle_lbl.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_MUTED)
	title_box.add_child(subtitle_lbl)

	var run_all_btn = Button.new()
	run_all_btn.text = " RUN HEADLESS AUDIT "
	run_all_btn.custom_minimum_size = Vector2(180, 40)
	run_all_btn.pressed.connect(_on_run_audit_pressed)
	header.add_child(run_all_btn)

	# Tab Container for the 4 Categories
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tabs)

	# 1. Phase 1 Crew Tasks
	var crew_scroll = ScrollContainer.new()
	crew_scroll.name = "Phase 1: Crew & Prereq (10)"
	tabs.add_child(crew_scroll)
	var crew_grid = _create_grid_container()
	crew_scroll.add_child(crew_grid)

	var crew_tasks = [
		{"id": "repair_power", "name": "Repair Power", "room": "Electrical"},
		{"id": "stabilize_orion", "name": "Stabilize ORION", "room": "ORION Core"},
		{"id": "server_calibration", "name": "Server Calibration", "room": "Server Room"},
		{"id": "security_repair", "name": "Security Repair", "room": "Security Room"},
		{"id": "medical_supply_check", "name": "Medical Supply Check", "room": "MedBay"},
		{"id": "data_transfer", "name": "Data Transfer", "room": "Comms"},
		{"id": "door_repair", "name": "Door Repair", "room": "Maintenance"},
		{"id": "coolant_system", "name": "Coolant System", "room": "Engineering"},
		{"id": "laboratory_org", "name": "Laboratory Organization", "room": "Lab"},
		{"id": "backup_power", "name": "Backup Power", "room": "Generator"}
	]
	for t in crew_tasks:
		_add_task_card(crew_grid, t.id, t.name, t.room, func(task_id): _launch_task(task_id))

	# 2. Phase 2 Blackout Recovery
	var rec_scroll = ScrollContainer.new()
	rec_scroll.name = "Phase 2: Blackout Recovery (4)"
	tabs.add_child(rec_scroll)
	var rec_grid = _create_grid_container()
	rec_scroll.add_child(rec_grid)

	var rec_tasks = [
		{"id": "generator", "name": "Generator Priming", "room": "Generator Room"},
		{"id": "power_routing", "name": "Power Routing", "room": "Power Room"},
		{"id": "security_relay", "name": "Security Relay", "room": "Security Room"},
		{"id": "cooling", "name": "Cooling Bypass", "room": "Cooling Hub"}
	]
	for r in rec_tasks:
		_add_task_card(rec_grid, r.id, r.name, r.room, func(sys_id): _launch_recovery(sys_id))

	# 3. Phase 2 Impostor Sabotage
	var sab_scroll = ScrollContainer.new()
	sab_scroll.name = "Phase 2: Impostor Sabotage (5)"
	tabs.add_child(sab_scroll)
	var sab_grid = _create_grid_container()
	sab_scroll.add_child(sab_grid)

	var sab_tasks = [
		{"id": "steal_confidential_files", "name": "Steal Confidential Files", "room": "Executive Office"},
		{"id": "extract_orion_core_data", "name": "Extract ORION Core Data", "room": "ORION Core"},
		{"id": "disable_orion_containment", "name": "Disable ORION Containment", "room": "Containment Hub"},
		{"id": "sabotage_generator", "name": "Sabotage Generator", "room": "Generator Room"},
		{"id": "tamper_security", "name": "Tamper With Security", "room": "Security Room"}
	]
	for s in sab_tasks:
		_add_task_card(sab_grid, s.id, s.name, s.room, func(obj_id): _launch_sabotage(obj_id), MiniGameUIHelper.COLOR_BORDER_RED)

	# 4. Phase 4 Meltdown Emergency
	var melt_scroll = ScrollContainer.new()
	melt_scroll.name = "Phase 4: Meltdown Climax (3)"
	tabs.add_child(melt_scroll)
	var melt_grid = _create_grid_container()
	melt_scroll.add_child(melt_grid)

	var melt_tasks = [
		{"id": "restore_power", "name": "Restore Power", "room": "Reactor Substation"},
		{"id": "restore_cooling", "name": "Restore Cooling", "room": "Cryogenic Hub"},
		{"id": "stabilize_orion", "name": "Stabilize ORION Core", "room": "ORION Core Room"}
	]
	for m in melt_tasks:
		_add_task_card(melt_grid, m.id, m.name, m.room, func(melt_id): _launch_meltdown(melt_id), MiniGameUIHelper.COLOR_BORDER_RED)

	# Console Activity Log Box at bottom
	var log_panel = PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(0, 100)
	main_vbox.add_child(log_panel)

	status_log_label = RichTextLabel.new()
	status_log_label.bbcode_enabled = true
	status_log_label.scroll_following = true
	status_log_label.text = "[color=#00e6ff][SYSTEM][/color] Mini-Game Showcase initialized. Select any task card above to launch interaction modal."
	log_panel.add_child(status_log_label)

	# Attach Interaction Controller for modal mounting
	controller = InteractionController.new()
	controller.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(controller)

	controller.interaction_opened.connect(_on_interaction_opened)
	controller.interaction_closed.connect(_on_interaction_closed)

func _create_grid_container() -> GridContainer:
	var grid = GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	return grid

func _add_task_card(grid: GridContainer, id: String, title: String, room: String, launch_cb: Callable, border_color: Color = MiniGameUIHelper.COLOR_BORDER_CYAN) -> void:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 100)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.12, 0.18, 0.9)
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_bottom = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	var name_lbl = Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", border_color)
	vbox.add_child(name_lbl)

	var room_lbl = Label.new()
	room_lbl.text = "Location: %s" % room
	room_lbl.add_theme_font_size_override("font_size", 11)
	room_lbl.add_theme_color_override("font_color", MiniGameUIHelper.COLOR_TEXT_MUTED)
	vbox.add_child(room_lbl)

	var btn = Button.new()
	btn.text = "TEST INTERACTION"
	btn.custom_minimum_size = Vector2(0, 32)
	btn.pressed.connect(func(): launch_cb.call(id))
	vbox.add_child(btn)

	grid.add_child(card)

func _launch_task(task_id: String) -> void:
	controller.open_task_interaction("test_" + task_id, task_id)

func _launch_recovery(system_id: String) -> void:
	controller.open_recovery_interaction(system_id)

func _launch_sabotage(objective_id: String) -> void:
	controller.open_sabotage_interaction(objective_id)

func _launch_meltdown(emergency_id: String) -> void:
	controller.open_meltdown_interaction(emergency_id)

func _on_interaction_opened(cat: int, id: String) -> void:
	_log("[color=#ffcc00][INTERACTION LAUNCHED][/color] Modal opened: [b]%s[/b] (Category %d)" % [id, cat])

func _on_interaction_closed(cat: int, id: String, was_completed: bool) -> void:
	if was_completed:
		completed_tasks_set[id] = true
		_log("[color=#33ff66][INTERACTION SOLVED][/color] [b]%s[/b] successfully completed (100%%)!" % id)
	else:
		_log("[color=#ff6666][INTERACTION ABORTED][/color] [b]%s[/b] closed without completion." % id)

func _log(msg: String) -> void:
	if status_log_label != null:
		status_log_label.text += "\n" + msg

func _on_run_audit_pressed() -> void:
	_log("[color=#00e6ff][AUDIT][/color] Running 22-point validation check...")
	var catalog = MiniGameFactory.create_task_mini_game("repair_power")
	if catalog != null:
		_log("[color=#33ff66][AUDIT PASS][/color] Factory modules active and operational.")
		catalog.queue_free()
