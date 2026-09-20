class_name VictoryDefeatScreen
extends Control

## VictoryDefeatScreen — Member 5 (UI/UX Designer & Frontend Programmer)
## Displays the cinematic Victory / Defeat Splash Screen prior to the detailed Result Screen.
##
## Visual & Logical Rules:
## 1. Backgrounds:
##    - CREW WIN: Asterion Facility cleanroom/lab background (media_1789731511640.png).
##    - IMPOSTOR WIN: Damaged/compromised Asterion Facility background (media_1789913230538.jpg).
## 2. Character Display:
##    - CREW WIN: Lineup of all surviving, active (non-ejected) Crew members.
##    - IMPOSTOR WIN: Single prominent Impostor character.
## 3. Perspective-Based Header:
##    - Evaluates whether local player role matches winner role -> "VICTORY" vs "DEFEAT".
## 4. Transitions:
##    - Plays cinematic entrance, waits ~3.5s (or skips on input/click), then emits sequence_completed.

signal sequence_completed(winner_role: int, reason: int, result_data: Dictionary)

const NetworkConfig = preload("res://shared/network_config.gd")
const MeltdownConfig = preload("res://shared/meltdown_config.gd")

## Official Asset Paths
const CREWMATE_BG_PATH: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.user_uploaded/media_1789731511640.png"
const IMPOSTOR_BG_PATH: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.user_uploaded/media_1789913230538.jpg"

## 8-Player Department Colors (Asterion Nuclear Research Facility)
const PLAYER_PALETTE: Array[Color] = [
	Color(0.12, 0.35, 0.75), # 1. Navy Blue   (Engineering)
	Color(0.92, 0.40, 0.08), # 2. Safety Orange(Maintenance)
	Color(0.92, 0.72, 0.05), # 3. Hazard Yellow(Radiation Safety)
	Color(0.38, 0.44, 0.52), # 4. Steel Gray   (Technical Operations)
	Color(0.12, 0.65, 0.32), # 5. Lab Green    (Scientific Personnel)
	Color(0.85, 0.18, 0.22), # 6. Emergency Red(Security / Response)
	Color(0.04, 0.62, 0.72), # 7. Electric Cyan(Diagnostics)
	Color(0.88, 0.90, 0.94)  # 8. Cleanroom White(Reactor Physics)
]

## Color Constants
const COLOR_CREW_VICTORY: Color = Color(0.0, 0.95, 1.0, 1.0)
const COLOR_IMPOSTOR_VICTORY: Color = Color(1.0, 0.18, 0.28, 1.0)
const COLOR_DEFEAT_RED: Color = Color(1.0, 0.28, 0.32, 1.0)

## Node references
@onready var background_image: TextureRect = find_child("BackgroundImage", true, false)
@onready var header_branding: Control = find_child("HeaderBranding", true, false)
@onready var characters_container: Control = find_child("CharactersContainer", true, false)
@onready var typography_layer: Control = find_child("TypographyLayer", true, false)
@onready var outcome_title: Label = find_child("OutcomeTitle", true, false)
@onready var subtitle_label: Label = find_child("SubtitleLabel", true, false)
@onready var reason_badge: PanelContainer = find_child("ReasonBadge", true, false)
@onready var reason_label: Label = find_child("ReasonLabel", true, false)
@onready var footer_layer: Control = find_child("FooterLayer", true, false)
@onready var prompt_label: Label = find_child("PromptLabel", true, false)

## Internal state
var _is_active: bool = false
var _crew_bg_texture: Texture2D = null
var _impostor_bg_texture: Texture2D = null
var _active_tween: Tween = null
var _winner_role: int = NetworkConfig.PlayerRole.CREW
var _reason: int = 0
var _result_data: Dictionary = {}
var _can_skip: bool = false

func _ready() -> void:
	_ensure_node_references()
	_load_background_textures()
	visible = false
	modulate.a = 0.0

func _ensure_node_references() -> void:
	if background_image == null:
		background_image = find_child("BackgroundImage", true, false) as TextureRect
	if header_branding == null:
		header_branding = find_child("HeaderBranding", true, false) as Control
	if characters_container == null:
		characters_container = find_child("CharactersContainer", true, false) as Control
	if typography_layer == null:
		typography_layer = find_child("TypographyLayer", true, false) as Control
	if outcome_title == null:
		outcome_title = find_child("OutcomeTitle", true, false) as Label
	if subtitle_label == null:
		subtitle_label = find_child("SubtitleLabel", true, false) as Label
	if reason_badge == null:
		reason_badge = find_child("ReasonBadge", true, false) as PanelContainer
	if reason_label == null:
		reason_label = find_child("ReasonLabel", true, false) as Label
	if footer_layer == null:
		footer_layer = find_child("FooterLayer", true, false) as Control
	if prompt_label == null:
		prompt_label = find_child("PromptLabel", true, false) as Label

func _load_background_textures() -> void:
	if FileAccess.file_exists(CREWMATE_BG_PATH):
		var img_crew = Image.load_from_file(CREWMATE_BG_PATH)
		if img_crew != null and not img_crew.is_empty():
			_crew_bg_texture = ImageTexture.create_from_image(img_crew)
			
	if FileAccess.file_exists(IMPOSTOR_BG_PATH):
		var img_imp = Image.load_from_file(IMPOSTOR_BG_PATH)
		if img_imp != null and not img_imp.is_empty():
			_impostor_bg_texture = ImageTexture.create_from_image(img_imp)

func _gui_input(event: InputEvent) -> void:
	if not _is_active or not _can_skip:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		_finish_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or not _can_skip:
		return
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		if event is InputEventKey and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE):
			_finish_sequence()

## Main Entry Point to play the cinematic Victory / Defeat sequence
func play_victory_defeat(local_role: int, winner_role: int, reason: int, result_data: Dictionary) -> void:
	_ensure_node_references()
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
	_winner_role = winner_role
	_reason = reason
	_result_data = result_data.duplicate()
	_is_active = true
	_can_skip = false
	
	visible = true
	modulate.a = 1.0
	
	if characters_container != null:
		characters_container.modulate.a = 1.0
		
	var is_local_winner = (local_role == winner_role)
	var is_crew_win = (winner_role == NetworkConfig.PlayerRole.CREW or int(winner_role) == 1)
	
	# 1. Background Setup
	if background_image != null:
		if is_crew_win:
			background_image.texture = _crew_bg_texture
		else:
			background_image.texture = _impostor_bg_texture
			
	# 2. Typography & Header Configuration
	_setup_typography(is_local_winner, is_crew_win, reason, result_data)
	
	# 3. Build Characters (Surviving Crew Lineup vs Solo Impostor)
	_build_characters(is_crew_win, result_data)
	
	# 4. Cinematic Entrance Animation
	_animate_in()

func _setup_typography(is_local_winner: bool, is_crew_win: bool, reason: int, result_data: Dictionary) -> void:
	if outcome_title != null:
		if is_local_winner:
			outcome_title.text = "VICTORY"
			outcome_title.add_theme_color_override("font_color", COLOR_CREW_VICTORY if is_crew_win else COLOR_IMPOSTOR_VICTORY)
			outcome_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
		else:
			outcome_title.text = "DEFEAT"
			outcome_title.add_theme_color_override("font_color", COLOR_DEFEAT_RED)
			outcome_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
			
	if subtitle_label != null:
		if is_crew_win:
			subtitle_label.text = "REACTOR CORE STABILIZED // ASTERION FACILITY SECURED"
			subtitle_label.add_theme_color_override("font_color", Color(0.85, 0.94, 1.0, 0.95))
		else:
			subtitle_label.text = "CONTAINMENT BREACH // CRITICAL FACILITY FAILURE"
			subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.80, 0.82, 0.95))
			
	# Reason Badge Styling
	if reason_badge != null and reason_label != null:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.04, 0.08, 0.12, 0.90) if is_crew_win else Color(0.18, 0.04, 0.06, 0.90)
		style.set_border_width_all(1)
		style.border_color = (COLOR_CREW_VICTORY if is_crew_win else COLOR_IMPOSTOR_VICTORY)
		style.border_color.a = 0.8
		style.set_corner_radius_all(4)
		reason_badge.add_theme_stylebox_override("panel", style)
		
		var reason_text = ""
		match reason:
			MeltdownConfig.GameOverReason.CREW_EMERGENCY_SYSTEMS_COMPLETE:
				reason_text = "ALL MANDATORY EMERGENCY SYSTEMS RESTORED"
			MeltdownConfig.GameOverReason.IMPOSTOR_MELTDOWN_TIMER_EXPIRED:
				reason_text = "MELTDOWN COUNTDOWN EXPIRED // CORE DETONATION"
			_:
				reason_text = result_data.get("reason_name", "AUTHORITATIVE MATCH CONCLUDED")
				
		reason_label.text = reason_text
		reason_label.add_theme_color_override("font_color", COLOR_CREW_VICTORY if is_crew_win else COLOR_IMPOSTOR_VICTORY)

## Builds character nodes in CharactersContainer
func _build_characters(is_crew_win: bool, result_data: Dictionary) -> void:
	if characters_container == null:
		return
		
	for child in characters_container.get_children():
		characters_container.remove_child(child)
		child.queue_free()
		
	var roster: Array = result_data.get("player_roster", [])
	
	if is_crew_win:
		# Display all surviving crew members
		var survivors: Array = []
		for p in roster:
			var role_val = p.get("role", NetworkConfig.PlayerRole.CREW)
			var is_imp = (role_val == NetworkConfig.PlayerRole.IMPOSTOR or int(role_val) == 2 or str(role_val).to_upper() == "IMPOSTOR")
			var is_alive = bool(p.get("is_alive", true))
			var is_eliminated = bool(p.get("is_eliminated", false))
			if not is_imp and is_alive and not is_eliminated:
				survivors.append(p)
				
		# Fallback if roster was not populated
		if survivors.is_empty():
			for s in range(1, 7):
				survivors.append({"player_slot": s, "peer_id": 100 + s})
				
		_layout_survivor_lineup(survivors)
	else:
		# Display single Impostor character
		var imp_data = {}
		for p in roster:
			var role_val = p.get("role", NetworkConfig.PlayerRole.CREW)
			var is_imp = (role_val == NetworkConfig.PlayerRole.IMPOSTOR or int(role_val) == 2 or str(role_val).to_upper() == "IMPOSTOR")
			if is_imp:
				imp_data = p
				break
				
		var imp_slot = int(imp_data.get("player_slot", 7))
		var imp_pid = int(imp_data.get("peer_id", 107))
		_layout_solo_impostor(imp_slot, imp_pid)## Arranges survivor crew members evenly in the center
func _layout_survivor_lineup(survivors: Array) -> void:
	var count = survivors.size()
	var screen_w = 1280.0
	var screen_h = 720.0
	var center_x = screen_w * 0.5
	var floor_y = screen_h * 0.70
	var scale_mult = 1.15
	
	# Determine spacing based on survivor count
	var spacing = clampf(920.0 / float(maxi(count, 1)), 145.0, 175.0)
	var total_w = float(count - 1) * spacing
	var start_x = center_x - (total_w * 0.5)
	
	for i in range(count):
		var p = survivors[i]
		var slot = int(p.get("player_slot", i + 1))
		var pid = int(p.get("peer_id", slot))
		var char_node = _create_technician_node(slot, pid, false, scale_mult)
		
		var char_pos = Vector2(start_x + (float(i) * spacing), floor_y)
		char_node.position = char_pos - Vector2(80.0 * scale_mult, 190.0 * scale_mult)
		characters_container.add_child(char_node)
		
		# Subtle idle offset
		_apply_idle_animation(char_node, float(i) * 0.25)

## Places single Impostor prominently in the center
func _layout_solo_impostor(slot: int, pid: int) -> void:
	var screen_w = 1280.0
	var screen_h = 720.0
	var center_x = screen_w * 0.5
	var floor_y = screen_h * 0.70
	var scale_mult = 1.45
	
	var char_node = _create_technician_node(slot, pid, true, scale_mult)
	char_node.position = Vector2(center_x - (80.0 * scale_mult), floor_y - (190.0 * scale_mult))
	characters_container.add_child(char_node)
	
	_apply_idle_animation(char_node, 0.0)

## Creates full-body stylized Asterion Nuclear Facility technician node
func _create_technician_node(slot: int, pid: int, is_impostor: bool, scale_multiplier: float = 1.0) -> Control:
	var root = Control.new()
	root.name = "Tech_%d" % slot
	root.custom_minimum_size = Vector2(160, 280) * scale_multiplier
	root.size = Vector2(160, 280) * scale_multiplier
	root.pivot_offset = Vector2(80, 190) * scale_multiplier
	
	var color_index = clampi(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	var suit_color = PLAYER_PALETTE[color_index]
	
	var canvas = Control.new()
	canvas.name = "Canvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.custom_minimum_size = root.custom_minimum_size
	canvas.size = root.size
	canvas.draw.connect(func(): _draw_technician_character(canvas, suit_color, is_impostor, slot, scale_multiplier))
	root.add_child(canvas)
	
	# Name / Slot Badge below technician
	var name_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.09, 0.90)
	style.set_border_width_all(1)
	style.border_color = Color(0.25, 0.30, 0.40, 0.85)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	name_panel.add_theme_stylebox_override("panel", style)
	
	var name_lbl = Label.new()
	name_lbl.text = "Player %d" % (pid if pid > 0 else slot)
	name_lbl.add_theme_font_size_override("font_size", int(11 * scale_multiplier))
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98, 1.0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_panel.add_child(name_lbl)
	
	root.add_child(name_panel)
	name_panel.set_position(Vector2((160.0 * scale_multiplier - 84.0) * 0.5, 260.0 * scale_multiplier))
	
	return root

func _apply_idle_animation(node: Control, delay_offset: float) -> void:
	var base_scale = node.scale
	var tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", base_scale * Vector2(1.02, 0.98), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_delay(delay_offset)
	tween.tween_property(node, "scale", base_scale, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

## Procedural Asterion Nuclear Facility Technician drawing
func _draw_technician_character(canvas: Control, base_color: Color, is_impostor: bool, slot: int, scale_mult: float) -> void:
	var w = maxf(canvas.size.x, 160.0 * scale_mult)
	var h = maxf(canvas.size.y, 240.0 * scale_mult)
	var cx = w * 0.5
	var cy = h * 0.44
	
	# 1. Ground Drop Shadow
	_draw_ellipse(canvas, Vector2(cx, cy + 90 * scale_mult), 46 * scale_mult, 13 * scale_mult, Color(0.0, 0.0, 0.0, 0.75))
	_draw_ellipse(canvas, Vector2(cx, cy + 90 * scale_mult), 28 * scale_mult, 6 * scale_mult, Color(0.0, 0.0, 0.0, 0.92))
	
	# Reflection
	var refl_color = base_color
	refl_color.a = 0.18
	_draw_ellipse(canvas, Vector2(cx, cy + 104 * scale_mult), 34 * scale_mult, 10 * scale_mult, refl_color)
	
	# 2. Heavy Boots
	var boot_dark = Color(0.08, 0.09, 0.12, 1.0)
	var steel_cap = Color(0.24, 0.28, 0.35, 1.0)
	var l_boot = Rect2(cx - 28 * scale_mult, cy + 62 * scale_mult, 22 * scale_mult, 26 * scale_mult)
	var r_boot = Rect2(cx + 6 * scale_mult, cy + 62 * scale_mult, 22 * scale_mult, 26 * scale_mult)
	
	_draw_rounded_box(canvas, l_boot, 5.0 * scale_mult, boot_dark, true)
	_draw_rounded_box(canvas, l_boot, 5.0 * scale_mult, Color(0.02, 0.03, 0.05, 1.0), false, 2.5 * scale_mult)
	_draw_rounded_box(canvas, Rect2(cx - 28 * scale_mult, cy + 74 * scale_mult, 22 * scale_mult, 14 * scale_mult), 4.0 * scale_mult, steel_cap, true)
	canvas.draw_line(Vector2(cx - 28 * scale_mult, cy + 86 * scale_mult), Vector2(cx - 6 * scale_mult, cy + 86 * scale_mult), Color(0.95, 0.75, 0.10, 0.9), 2.0 * scale_mult)
	
	_draw_rounded_box(canvas, r_boot, 5.0 * scale_mult, boot_dark, true)
	_draw_rounded_box(canvas, r_boot, 5.0 * scale_mult, Color(0.02, 0.03, 0.05, 1.0), false, 2.5 * scale_mult)
	_draw_rounded_box(canvas, Rect2(cx + 6 * scale_mult, cy + 74 * scale_mult, 22 * scale_mult, 14 * scale_mult), 4.0 * scale_mult, steel_cap, true)
	canvas.draw_line(Vector2(cx + 6 * scale_mult, cy + 86 * scale_mult), Vector2(cx + 28 * scale_mult, cy + 86 * scale_mult), Color(0.95, 0.75, 0.10, 0.9), 2.0 * scale_mult)
	
	# 3. Pants
	var leg_dark = base_color.darkened(0.30)
	var leg_mid = base_color.darkened(0.10)
	var l_leg = Rect2(cx - 26 * scale_mult, cy + 20 * scale_mult, 22 * scale_mult, 46 * scale_mult)
	var r_leg = Rect2(cx + 4 * scale_mult, cy + 20 * scale_mult, 22 * scale_mult, 46 * scale_mult)
	
	_draw_rounded_box(canvas, l_leg, 6.0 * scale_mult, leg_dark, true)
	_draw_rounded_box(canvas, l_leg, 6.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.5 * scale_mult)
	_draw_rounded_box(canvas, r_leg, 6.0 * scale_mult, leg_mid, true)
	_draw_rounded_box(canvas, r_leg, 6.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.5 * scale_mult)
	
	# Kneepads
	var kneepad_col = Color(0.12, 0.15, 0.20, 1.0)
	_draw_rounded_box(canvas, Rect2(cx - 24 * scale_mult, cy + 38 * scale_mult, 18 * scale_mult, 18 * scale_mult), 4.0 * scale_mult, kneepad_col, true)
	_draw_rounded_box(canvas, Rect2(cx - 24 * scale_mult, cy + 38 * scale_mult, 18 * scale_mult, 18 * scale_mult), 4.0 * scale_mult, Color(0.03, 0.04, 0.06, 1.0), false, 2.0 * scale_mult)
	_draw_rounded_box(canvas, Rect2(cx + 6 * scale_mult, cy + 38 * scale_mult, 18 * scale_mult, 18 * scale_mult), 4.0 * scale_mult, kneepad_col, true)
	_draw_rounded_box(canvas, Rect2(cx + 6 * scale_mult, cy + 38 * scale_mult, 18 * scale_mult, 18 * scale_mult), 4.0 * scale_mult, Color(0.03, 0.04, 0.06, 1.0), false, 2.0 * scale_mult)
	
	# 4. Arms & Gloves
	var arm_l = Rect2(cx - 42 * scale_mult, cy - 28 * scale_mult, 16 * scale_mult, 48 * scale_mult)
	var arm_r = Rect2(cx + 26 * scale_mult, cy - 28 * scale_mult, 16 * scale_mult, 48 * scale_mult)
	_draw_rounded_box(canvas, arm_l, 6.0 * scale_mult, base_color.darkened(0.25), true)
	_draw_rounded_box(canvas, arm_l, 6.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.5 * scale_mult)
	_draw_rounded_box(canvas, arm_r, 6.0 * scale_mult, base_color.darkened(0.08), true)
	_draw_rounded_box(canvas, arm_r, 6.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.5 * scale_mult)
	
	# Gloves
	var glove_col = Color(0.10, 0.13, 0.18, 1.0)
	_draw_rounded_box(canvas, Rect2(cx - 43 * scale_mult, cy + 10 * scale_mult, 18 * scale_mult, 20 * scale_mult), 5.0 * scale_mult, glove_col, true)
	_draw_rounded_box(canvas, Rect2(cx - 43 * scale_mult, cy + 10 * scale_mult, 18 * scale_mult, 20 * scale_mult), 5.0 * scale_mult, Color(0.02, 0.03, 0.05, 1.0), false, 2.0 * scale_mult)
	_draw_rounded_box(canvas, Rect2(cx + 25 * scale_mult, cy + 10 * scale_mult, 18 * scale_mult, 20 * scale_mult), 5.0 * scale_mult, glove_col, true)
	_draw_rounded_box(canvas, Rect2(cx + 25 * scale_mult, cy + 10 * scale_mult, 18 * scale_mult, 20 * scale_mult), 5.0 * scale_mult, Color(0.02, 0.03, 0.05, 1.0), false, 2.0 * scale_mult)
	
	# 5. Torso
	var body_rect = Rect2(cx - 30 * scale_mult, cy - 32 * scale_mult, 60 * scale_mult, 56 * scale_mult)
	_draw_rounded_box(canvas, body_rect, 10.0 * scale_mult, base_color, true)
	_draw_rounded_box(canvas, body_rect, 10.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.8 * scale_mult)
	
	# Utility Vest
	var vest_rect = Rect2(cx - 26 * scale_mult, cy - 24 * scale_mult, 52 * scale_mult, 42 * scale_mult)
	var vest_col = Color(0.12, 0.15, 0.20, 1.0)
	_draw_rounded_box(canvas, vest_rect, 6.0 * scale_mult, vest_col, true)
	_draw_rounded_box(canvas, vest_rect, 6.0 * scale_mult, Color(0.03, 0.04, 0.06, 1.0), false, 2.0 * scale_mult)
	
	# Reflective Hazard Stripes
	var stripe_col = Color(0.95, 0.75, 0.10, 1.0)
	canvas.draw_rect(Rect2(cx - 22 * scale_mult, cy - 14 * scale_mult, 10 * scale_mult, 3.5 * scale_mult), stripe_col, true)
	canvas.draw_rect(Rect2(cx + 12 * scale_mult, cy - 14 * scale_mult, 10 * scale_mult, 3.5 * scale_mult), stripe_col, true)
	
	# Dosimeter / Badge
	canvas.draw_rect(Rect2(cx - 22 * scale_mult, cy - 4 * scale_mult, 9 * scale_mult, 11 * scale_mult), Color(0.85, 0.88, 0.92, 1.0), true)
	canvas.draw_circle(Vector2(cx - 17.5 * scale_mult, cy + 1.5 * scale_mult), 2.2 * scale_mult, Color(0.1, 0.85, 0.3, 1.0) if not is_impostor else Color(0.95, 0.15, 0.2, 1.0))
	
	# Heavy Utility Belt
	var belt_rect = Rect2(cx - 28 * scale_mult, cy + 14 * scale_mult, 56 * scale_mult, 10 * scale_mult)
	_draw_rounded_box(canvas, belt_rect, 3.0 * scale_mult, Color(0.06, 0.08, 0.10, 1.0), true)
	_draw_rounded_box(canvas, Rect2(cx - 6 * scale_mult, cy + 13 * scale_mult, 12 * scale_mult, 12 * scale_mult), 2.0 * scale_mult, steel_cap, true)
	
	# 6. Industrial Helmet
	var helmet_rect = Rect2(cx - 26 * scale_mult, cy - 78 * scale_mult, 52 * scale_mult, 48 * scale_mult)
	_draw_rounded_box(canvas, helmet_rect, 20.0 * scale_mult, base_color, true)
	_draw_rounded_box(canvas, helmet_rect, 20.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.98), false, 2.8 * scale_mult)
	
	# Crown Ridge
	var ridge_rect = Rect2(cx - 6 * scale_mult, cy - 82 * scale_mult, 12 * scale_mult, 18 * scale_mult)
	_draw_rounded_box(canvas, ridge_rect, 3.0 * scale_mult, base_color.lightened(0.20), true)
	_draw_rounded_box(canvas, ridge_rect, 3.0 * scale_mult, Color(0.02, 0.03, 0.05, 0.95), false, 2.0 * scale_mult)
	
	# Visor
	var visor_center = Vector2(cx, cy - 56 * scale_mult)
	var visor_rx = 20.0 * scale_mult
	var visor_ry = 11.5 * scale_mult
	var visor_glow = Color(0.0, 0.85, 1.0, 0.95) if not is_impostor else Color(1.0, 0.15, 0.25, 0.95)
	
	_draw_ellipse(canvas, visor_center, visor_rx + 2.5 * scale_mult, visor_ry + 2.5 * scale_mult, Color(0.02, 0.03, 0.05, 1.0))
	_draw_ellipse(canvas, visor_center, visor_rx, visor_ry, Color(0.08, 0.12, 0.18, 1.0))
	_draw_ellipse(canvas, Vector2(visor_center.x, visor_center.y + 1.0 * scale_mult), visor_rx - 2.0 * scale_mult, visor_ry - 2.0 * scale_mult, visor_glow)
	_draw_ellipse(canvas, Vector2(visor_center.x + 5.0 * scale_mult, visor_center.y - 2.5 * scale_mult), 6.0 * scale_mult, 2.5 * scale_mult, Color(1, 1, 1, 0.85))
	
	# Respirator
	var resp_rect = Rect2(cx - 18 * scale_mult, cy - 47 * scale_mult, 36 * scale_mult, 18 * scale_mult)
	_draw_rounded_box(canvas, resp_rect, 6.0 * scale_mult, Color(0.14, 0.18, 0.24, 1.0), true)
	_draw_rounded_box(canvas, resp_rect, 6.0 * scale_mult, Color(0.02, 0.03, 0.05, 1.0), false, 2.0 * scale_mult)
	canvas.draw_circle(Vector2(cx - 9.0 * scale_mult, cy - 38 * scale_mult), 3.5 * scale_mult, Color(0.25, 0.30, 0.38, 1.0))
	canvas.draw_circle(Vector2(cx + 9.0 * scale_mult, cy - 38 * scale_mult), 3.5 * scale_mult, Color(0.25, 0.30, 0.38, 1.0))

func _draw_rounded_box(canvas: Control, rect: Rect2, radius: float, color: Color, filled: bool = true, line_width: float = 2.0) -> void:
	var pts = PackedVector2Array()
	var r = min(radius, min(rect.size.x, rect.size.y) * 0.5)
	var corners = [
		Vector2(rect.position.x + r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.position.y + r),
		Vector2(rect.end.x - r, rect.end.y - r),
		Vector2(rect.position.x + r, rect.end.y - r)
	]
	for i in range(4):
		var center = corners[i]
		var start_angle = float(i) * (PI * 0.5) + PI
		for j in range(6):
			var a = start_angle + (float(j) / 5.0) * (PI * 0.5)
			pts.append(center + Vector2(cos(a) * r, sin(a) * r))
	pts.append(pts[0])
	if filled:
		canvas.draw_colored_polygon(pts, color)
	else:
		canvas.draw_polyline(pts, color, line_width)

func _draw_ellipse(canvas: Control, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts = PackedVector2Array()
	var segments = 24
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	canvas.draw_colored_polygon(pts, color)

## Cinematic Entrance Animation
func _animate_in() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	if typography_layer != null:
		typography_layer.scale = Vector2(0.88, 0.88)
		typography_layer.pivot_offset = Vector2(640, 75)
		
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	# Fade in screen
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Punch typography in
	if typography_layer != null:
		_active_tween.tween_property(typography_layer, "scale", Vector2.ONE, 0.40).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
	# Enable skip after a short delay
	_active_tween.chain().tween_callback(func(): _can_skip = true)
	
	# Auto-advance after 3.5s
	_active_tween.chain().tween_interval(3.5)
	_active_tween.chain().tween_callback(_finish_sequence)

func _finish_sequence() -> void:
	if not _is_active:
		return
	_is_active = false
	_can_skip = false
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
	var fade_tween = create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fade_tween.tween_callback(func():
		visible = false
		sequence_completed.emit(_winner_role, _reason, _result_data)
	)

func is_screen_active() -> bool:
	return _is_active
