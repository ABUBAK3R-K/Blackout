class_name RoleRevealScreen
extends Control

## RoleRevealScreen — Member 5 (UI/UX Frontend)
## Implements the Cinematic Asterion Research Facility Role Reveal sequence for BLACKOUT.
##
## STAGE 1 — COMPLETE BLACK / TITLE:
##           Screen nearly black. Top-left branding + "YOU ARE THE" appears.
##
## STAGE 2 — ROLE REVEAL:
##           "CREWMATE" or "IMPOSTOR" title appears with glowing sci-fi typography.
##           Local player character is revealed (Crewmate on mid-right, Impostor large foreground right).
##
## STAGE 3 — ENVIRONMENT LIGHT-UP / SCENE REVEAL:
##           Facility lights up.
##           • CREWMATE: Blue facility lights up, other 7 characters appear in the room lineup.
##           • IMPOSTOR: Red emergency facility lights up, 7 background characters appear at distant consoles,
##                       while the large local Impostor remains close to the camera on the right.

signal stage_changed(stage_index: int)
signal sequence_completed()

const NetworkConfig = preload("res://shared/network_config.gd")

## Clean environment background assets provided by user
const CREWMATE_BG_PATH: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.user_uploaded/media_1789731511640.png"
const IMPOSTOR_BG_PATH: String = "C:/Users/shahz/.gemini/antigravity-ide/brain/d2d1e402-fa78-4055-a74e-93ff567c9829/.user_uploaded/media_1789731507634.png"

## Official 8-Player Department Colors (Asterion Nuclear Research Facility)
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

## Styling Colors
const COLOR_CREWMATE_CYAN: Color = Color(0.0, 0.90, 1.0, 1.0)
const COLOR_CREWMATE_GLOW: Color = Color(0.0, 0.65, 1.0, 0.75)
const COLOR_IMPOSTOR_RED: Color = Color(1.0, 0.10, 0.21, 1.0)
const COLOR_IMPOSTOR_GLOW: Color = Color(1.0, 0.05, 0.15, 0.85)

## State
var current_stage: int = 0
var assigned_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.CREW
var local_player_slot: int = 1 # 1-indexed (1..8)
var is_playing: bool = false
var auto_advance: bool = true

## Node references
var background_image: TextureRect = null
var ambient_darkness: ColorRect = null
var header_layer: Control = null
var typography_layer: Control = null
var prefix_label: Label = null
var role_label: Label = null
var local_character_container: Control = null
var background_characters_container: Control = null

## Textures
var _crew_bg_texture: Texture2D = null
var _impostor_bg_texture: Texture2D = null

## Nodes
var _local_character_node: Control = null
var _bg_character_nodes: Array[Control] = []
var _active_tween: Tween = null
var _strobe_timer: float = 0.0

func _ready() -> void:
	_resolve_node_references()
	_load_background_textures()
	_build_characters()
	_connect_to_network_if_available()
	_set_initial_hidden_state()
	
	if not _is_in_live_multiplayer():
		call_deferred("play_reveal_sequence", NetworkConfig.PlayerRole.CREW, 1, false)

func _is_in_live_multiplayer() -> bool:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			return net_mgr.client.is_connected_to_server()
	return false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_C:
				print("[TEST HOTKEY] Playing CREWMATE Reveal...")
				play_reveal_sequence(NetworkConfig.PlayerRole.CREW, 1, true)
			KEY_2, KEY_I:
				print("[TEST HOTKEY] Playing IMPOSTOR Reveal...")
				play_reveal_sequence(NetworkConfig.PlayerRole.IMPOSTOR, 1, true)
			KEY_SPACE:
				print("[TEST HOTKEY] Replaying current sequence...")
				play_reveal_sequence(assigned_role, local_player_slot, true)

func _resolve_node_references() -> void:
	background_image = get_node_or_null("BackgroundImage") as TextureRect
	ambient_darkness = get_node_or_null("AmbientDarkness") as ColorRect
	header_layer = get_node_or_null("HeaderBranding") as Control
	typography_layer = get_node_or_null("TypographyLayer") as Control
	if typography_layer != null:
		prefix_label = typography_layer.get_node_or_null("PrefixLabel") as Label
		role_label = typography_layer.get_node_or_null("RoleLabel") as Label
	local_character_container = get_node_or_null("LocalCharacterContainer") as Control
	background_characters_container = get_node_or_null("BackgroundCharactersContainer") as Control

func _load_background_textures() -> void:
	if FileAccess.file_exists(CREWMATE_BG_PATH):
		var img_crew = Image.load_from_file(CREWMATE_BG_PATH)
		if img_crew != null and not img_crew.is_empty():
			_crew_bg_texture = ImageTexture.create_from_image(img_crew)
			
	if FileAccess.file_exists(IMPOSTOR_BG_PATH):
		var img_imp = Image.load_from_file(IMPOSTOR_BG_PATH)
		if img_imp != null and not img_imp.is_empty():
			_impostor_bg_texture = ImageTexture.create_from_image(img_imp)

func _process(delta: float) -> void:
	if current_stage == 1:
		_strobe_timer += delta * 3.0
		var pulse = (sin(_strobe_timer) + 1.0) * 0.5
		if ambient_darkness != null:
			ambient_darkness.color = Color(0, 0, 0, lerp(0.98, 0.94, pulse))

func _connect_to_network_if_available() -> void:
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			var client = net_mgr.client
			if client.has_signal("role_assigned") and not client.role_assigned.is_connected(_on_network_role_assigned):
				client.role_assigned.connect(_on_network_role_assigned)

func _on_network_role_assigned(p_role: int) -> void:
	var slot: int = 1
	if has_node("/root/NetworkManager"):
		var net_mgr = get_node("/root/NetworkManager")
		if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
			slot = net_mgr.client.assigned_slot
	play_reveal_sequence(p_role as NetworkConfig.PlayerRole, slot, true)

## Public API to start the role reveal sequence
func play_reveal_sequence(
	p_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.CREW,
	p_player_slot: int = 1,
	p_auto_finish: bool = true
) -> void:
	_resolve_node_references()
	assigned_role = p_role
	local_player_slot = clamp(p_player_slot, 1, 8)
	auto_advance = p_auto_finish
	is_playing = true
	visible = true
	
	_build_characters()
	_setup_scene_for_role()
	_start_stage_1_blackout()

func _setup_scene_for_role() -> void:
	var is_impostor = (assigned_role == NetworkConfig.PlayerRole.IMPOSTOR)
	
	# Apply corresponding background
	if background_image != null:
		if is_impostor and _impostor_bg_texture != null:
			background_image.texture = _impostor_bg_texture
		elif not is_impostor and _crew_bg_texture != null:
			background_image.texture = _crew_bg_texture
			
	# Configure Typography
	if prefix_label != null:
		prefix_label.text = "YOU ARE THE"
		prefix_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.75, 0.9) if is_impostor else Color(0.7, 0.88, 0.98, 0.9))
		
	if role_label != null:
		role_label.text = "IMPOSTOR" if is_impostor else "CREWMATE"
		role_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_RED if is_impostor else COLOR_CREWMATE_CYAN)
		role_label.add_theme_color_override("font_shadow_color", COLOR_IMPOSTOR_GLOW if is_impostor else COLOR_CREWMATE_GLOW)
		role_label.modulate.a = 0.0
		role_label.position.y = 265.0

func _set_initial_hidden_state() -> void:
	if background_image != null:
		background_image.modulate.a = 1.0
	if ambient_darkness != null:
		ambient_darkness.color = Color(0, 0, 0, 0.98)
	if header_layer != null:
		header_layer.modulate.a = 0.0
	if typography_layer != null:
		typography_layer.modulate.a = 0.0
	if role_label != null:
		role_label.modulate.a = 0.0
		role_label.position.y = 265.0
	if local_character_container != null:
		local_character_container.modulate.a = 0.0
	if background_characters_container != null:
		background_characters_container.modulate.a = 0.0

## -----------------------------------------------------------------------------
## STAGE 1: COMPLETE BLACK / TITLE (0.0s – 0.8s)
## Screen nearly black. Top-left branding + "YOU ARE THE" appears.
## -----------------------------------------------------------------------------
func _start_stage_1_blackout() -> void:
	current_stage = 1
	stage_changed.emit(1)
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	# Dim ambient to near pitch black
	if ambient_darkness != null:
		_active_tween.tween_property(ambient_darkness, "color", Color(0, 0, 0, 0.98), 0.3)
		
	# Fade in Top-Left branding & "YOU ARE THE"
	if header_layer != null:
		_active_tween.tween_property(header_layer, "modulate:a", 1.0, 0.5)
	if typography_layer != null:
		_active_tween.tween_property(typography_layer, "modulate:a", 1.0, 0.5)
	if prefix_label != null:
		prefix_label.modulate.a = 1.0
	if role_label != null:
		role_label.modulate.a = 0.0
		role_label.position.y = 265.0
		
	# Hide characters during stage 1
	if local_character_container != null:
		_active_tween.tween_property(local_character_container, "modulate:a", 0.0, 0.2)
	if background_characters_container != null:
		_active_tween.tween_property(background_characters_container, "modulate:a", 0.0, 0.2)
		
	if auto_advance:
		_active_tween.chain().tween_interval(1.2)
		_active_tween.chain().tween_callback(_start_stage_2_role_reveal)

## -----------------------------------------------------------------------------
## STAGE 2: ROLE REVEAL (Suspenseful, longer focus on role & character)
## "CREWMATE" or "IMPOSTOR" reveals + Local player character prominently shown against DARK background.
## -----------------------------------------------------------------------------
func _start_stage_2_role_reveal() -> void:
	current_stage = 2
	stage_changed.emit(2)
	
	_layout_characters_for_stage_2()
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	# Background MUST stay almost completely dark
	if ambient_darkness != null:
		_active_tween.tween_property(ambient_darkness, "color", Color(0, 0, 0, 0.98), 0.3)
		
	# Fade out UI Header Branding so background wall sign will seamlessly take over later in Stage 3
	if header_layer != null:
		_active_tween.tween_property(header_layer, "modulate:a", 0.0, 0.4)
		
	# Reveal Role Typography with crisp punchy settle (0.4s)
	if role_label != null:
		role_label.modulate.a = 0.0
		role_label.position.y = 280.0
		_active_tween.tween_property(role_label, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(role_label, "position:y", 265.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# Reveal Local Player Character independently against the darkness
	if local_character_container != null:
		_active_tween.tween_property(local_character_container, "modulate:a", 1.0, 0.4)
		
	# Keep other 7 characters completely hidden
	if background_characters_container != null:
		background_characters_container.modulate.a = 0.0
		
	# Reveal background within 0.5 sec of role reveal for both roles
	if auto_advance:
		_active_tween.chain().tween_interval(0.5)
		_active_tween.chain().tween_callback(_start_stage_3_scene_reveal)

## -----------------------------------------------------------------------------
## STAGE 3: ENVIRONMENT LIGHT-UP / SCENE REVEAL (Fast 0.5s dynamic activation)
## Facility lights activate AND other 7 characters appear TOGETHER under 1 second.
## -----------------------------------------------------------------------------
func _start_stage_3_scene_reveal() -> void:
	current_stage = 3
	stage_changed.emit(3)
	
	_layout_characters_for_stage_3()
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	
	# 1. Animate darkness away so background environment lights up (0.5s)
	if ambient_darkness != null:
		_active_tween.tween_property(ambient_darkness, "color", Color(0, 0, 0, 0.0), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# 2. Reveal the other 7 characters at the SAME time (0.5s)
	if background_characters_container != null:
		background_characters_container.visible = true
		_active_tween.tween_property(background_characters_container, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	# 3. Local player remains visible throughout in place
	if local_character_container != null:
		local_character_container.modulate.a = 1.0
		
	# 4. Keep typography clear and visible
	if prefix_label != null:
		prefix_label.modulate.a = 1.0
	if role_label != null:
		role_label.modulate.a = 1.0
		
	if auto_advance:
		_active_tween.chain().tween_interval(2.0)
		_active_tween.chain().tween_callback(_finish_sequence)

func _finish_sequence() -> void:
	is_playing = false
	sequence_completed.emit()

## -----------------------------------------------------------------------------
## 2D Character Construction & Layout
## -----------------------------------------------------------------------------
func _build_characters() -> void:
	if local_character_container != null:
		for child in local_character_container.get_children():
			child.queue_free()
	if background_characters_container != null:
		for child in background_characters_container.get_children():
			child.queue_free()
			
	_bg_character_nodes.clear()
	
	# 1. Build Local Player Character Node
	_local_character_node = _create_astronaut_node(local_player_slot, false)
	if local_character_container != null:
		local_character_container.add_child(_local_character_node)
		
	# 2. Build 7 other characters using all distinct remaining slots
	var other_slots: Array[int] = []
	for s in range(1, 9):
		if s != local_player_slot:
			other_slots.append(s)
			
	for slot in other_slots:
		var node = _create_astronaut_node(slot, false)
		if background_characters_container != null:
			background_characters_container.add_child(node)
		_bg_character_nodes.append(node)

func _get_player_color(slot: int) -> Color:
	var index = clamp(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	return PLAYER_PALETTE[index]

## Creates a stylized 2D Nuclear Research Facility Technician with protective gear, vest, dosimeter, and helmet
func _create_astronaut_node(slot: int, is_facing_back: bool = false) -> Control:
	var root = Control.new()
	root.name = "Technician_%d" % slot
	root.custom_minimum_size = Vector2(160, 220)
	root.size = Vector2(160, 220)
	root.pivot_offset = Vector2(80, 190)
	
	var suit_color = _get_player_color(slot)
	
	var canvas = Control.new()
	canvas.name = "SuitCanvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.draw.connect(func(): _draw_technician(canvas, suit_color, is_facing_back, slot))
	root.add_child(canvas)
	
	return root

func _draw_technician(canvas: Control, base_color: Color, is_facing_back: bool, slot_num: int) -> void:
	var w = canvas.size.x
	var h = canvas.size.y
	var cx = w * 0.5
	var cy = h * 0.44
	
	# 1. Ground Drop Shadow & Floor Contact
	_draw_ellipse(canvas, Vector2(cx, cy + 90), 46, 13, Color(0.0, 0.0, 0.0, 0.70))
	_draw_ellipse(canvas, Vector2(cx, cy + 90), 28, 6, Color(0.0, 0.0, 0.0, 0.90))
	
	# Wet Floor Reflection
	var refl_color = base_color
	refl_color.a = 0.15
	_draw_ellipse(canvas, Vector2(cx, cy + 106), 34, 12, refl_color)
	
	# 2. Heavy Industrial Steel-Toe Boots
	var boot_dark = Color(0.08, 0.09, 0.12, 1.0)
	var steel_cap = Color(0.24, 0.28, 0.35, 1.0)
	var l_boot = Rect2(cx - 28, cy + 62, 22, 26)
	var r_boot = Rect2(cx + 6, cy + 62, 22, 26)
	
	_draw_rounded_box(canvas, l_boot, 5.0, boot_dark, true)
	_draw_rounded_box(canvas, l_boot, 5.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.5)
	_draw_rounded_box(canvas, Rect2(cx - 28, cy + 74, 22, 14), 4.0, steel_cap, true)
	canvas.draw_line(Vector2(cx - 28, cy + 86), Vector2(cx - 6, cy + 86), Color(0.95, 0.75, 0.10, 0.9), 2.0)
	
	_draw_rounded_box(canvas, r_boot, 5.0, boot_dark, true)
	_draw_rounded_box(canvas, r_boot, 5.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.5)
	_draw_rounded_box(canvas, Rect2(cx + 6, cy + 74, 22, 14), 4.0, steel_cap, true)
	canvas.draw_line(Vector2(cx + 6, cy + 86), Vector2(cx + 28, cy + 86), Color(0.95, 0.75, 0.10, 0.9), 2.0)
	
	# 3. Heavy-Duty Coverall Pants & Kneepads
	var leg_dark = base_color.darkened(0.30)
	var leg_mid = base_color.darkened(0.10)
	var l_leg = Rect2(cx - 26, cy + 20, 22, 46)
	var r_leg = Rect2(cx + 4, cy + 20, 22, 46)
	
	_draw_rounded_box(canvas, l_leg, 6.0, leg_dark, true)
	_draw_rounded_box(canvas, l_leg, 6.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	_draw_rounded_box(canvas, r_leg, 6.0, leg_mid, true)
	_draw_rounded_box(canvas, r_leg, 6.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	
	# Ballistic Kneepads
	var kneepad_col = Color(0.12, 0.15, 0.20, 1.0)
	_draw_rounded_box(canvas, Rect2(cx - 24, cy + 38, 18, 18), 4.0, kneepad_col, true)
	_draw_rounded_box(canvas, Rect2(cx - 24, cy + 38, 18, 18), 4.0, Color(0.03, 0.04, 0.06, 1.0), false, 2.0)
	_draw_rounded_box(canvas, Rect2(cx + 6, cy + 38, 18, 18), 4.0, kneepad_col, true)
	_draw_rounded_box(canvas, Rect2(cx + 6, cy + 38, 18, 18), 4.0, Color(0.03, 0.04, 0.06, 1.0), false, 2.0)
	
	# 4. Arms & Heavy Work Gloves
	var arm_l = Rect2(cx - 42, cy - 28, 16, 48)
	var arm_r = Rect2(cx + 26, cy - 28, 16, 48)
	_draw_rounded_box(canvas, arm_l, 6.0, base_color.darkened(0.25), true)
	_draw_rounded_box(canvas, arm_l, 6.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	_draw_rounded_box(canvas, arm_r, 6.0, base_color.darkened(0.08), true)
	_draw_rounded_box(canvas, arm_r, 6.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	
	# Work Gloves
	var glove_col = Color(0.10, 0.13, 0.18, 1.0)
	var glove_l = Rect2(cx - 43, cy + 10, 18, 20)
	var glove_r = Rect2(cx + 25, cy + 10, 18, 20)
	_draw_rounded_box(canvas, glove_l, 5.0, glove_col, true)
	_draw_rounded_box(canvas, glove_l, 5.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.0)
	_draw_rounded_box(canvas, glove_r, 5.0, glove_col, true)
	_draw_rounded_box(canvas, glove_r, 5.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.0)
	
	# 5. Torso: Heavy Coveralls + Reinforced Utility Vest
	var body_rect = Rect2(cx - 30, cy - 32, 60, 56)
	_draw_rounded_box(canvas, body_rect, 10.0, base_color, true)
	_draw_rounded_box(canvas, body_rect, 10.0, Color(0.02, 0.03, 0.05, 0.95), false, 3.0)
	
	# Utility Vest
	var vest_rect = Rect2(cx - 26, cy - 30, 52, 50)
	var vest_col = Color(0.13, 0.16, 0.21, 1.0)
	_draw_rounded_box(canvas, vest_rect, 6.0, vest_col, true)
	_draw_rounded_box(canvas, vest_rect, 6.0, Color(0.04, 0.05, 0.07, 1.0), false, 2.2)
	canvas.draw_line(Vector2(cx, cy - 30), Vector2(cx, cy + 18), Color(0.06, 0.08, 0.10, 1.0), 2.5)
	
	if not is_facing_back:
		# Hazard Stripe on Right Shoulder Strap
		var stripe_rect = Rect2(cx + 4, cy - 28, 18, 8)
		_draw_rounded_box(canvas, stripe_rect, 2.0, Color(0.95, 0.75, 0.10, 1.0), true)
		canvas.draw_line(Vector2(cx + 8, cy - 28), Vector2(cx + 12, cy - 20), Color(0.1, 0.1, 0.1, 1.0), 2.0)
		canvas.draw_line(Vector2(cx + 14, cy - 28), Vector2(cx + 18, cy - 20), Color(0.1, 0.1, 0.1, 1.0), 2.0)
		
		# Facility ID Badge on Left Chest
		var badge_rect = Rect2(cx - 22, cy - 24, 14, 18)
		_draw_rounded_box(canvas, badge_rect, 2.0, Color(0.92, 0.94, 0.98, 1.0), true)
		_draw_rounded_box(canvas, badge_rect, 2.0, Color(0.05, 0.06, 0.08, 1.0), false, 1.2)
		canvas.draw_rect(Rect2(cx - 20, cy - 22, 6, 8), Color(0.2, 0.25, 0.35, 1.0), true)
		canvas.draw_line(Vector2(cx - 20, cy - 11), Vector2(cx - 10, cy - 11), Color(0.1, 0.5, 0.9, 1.0), 2.0)
		
		# Pen Radiation Dosimeter on Chest with glowing indicator
		var dosimeter_rect = Rect2(cx - 5, cy - 26, 4, 14)
		_draw_rounded_box(canvas, dosimeter_rect, 2.0, Color(0.75, 0.80, 0.85, 1.0), true)
		_draw_rounded_box(canvas, dosimeter_rect, 2.0, Color(0.05, 0.06, 0.08, 1.0), false, 1.0)
		canvas.draw_circle(Vector2(cx - 3, cy - 23), 1.5, Color(0.2, 0.95, 0.4, 1.0))
	
	# 6. Tactical Belt & Pouches
	var belt_rect = Rect2(cx - 28, cy + 15, 56, 8)
	_draw_rounded_box(canvas, belt_rect, 2.0, Color(0.08, 0.10, 0.14, 1.0), true)
	_draw_rounded_box(canvas, belt_rect, 2.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.8)
	_draw_rounded_box(canvas, Rect2(cx - 5, cy + 14, 10, 10), 2.0, Color(0.55, 0.60, 0.68, 1.0), true)
	_draw_rounded_box(canvas, Rect2(cx - 5, cy + 14, 10, 10), 2.0, Color(0.05, 0.06, 0.08, 1.0), false, 1.2)
	
	# Left Tool Pouch / Geiger Counter
	var pouch_l = Rect2(cx - 36, cy + 12, 11, 16)
	_draw_rounded_box(canvas, pouch_l, 3.0, Color(0.16, 0.20, 0.26, 1.0), true)
	_draw_rounded_box(canvas, pouch_l, 3.0, Color(0.03, 0.04, 0.06, 1.0), false, 1.5)
	canvas.draw_circle(Vector2(cx - 31, cy + 16), 1.5, Color(0.95, 0.80, 0.2, 1.0))
	
	# Right Emergency Radio
	var pouch_r = Rect2(cx + 25, cy + 12, 11, 16)
	_draw_rounded_box(canvas, pouch_r, 3.0, Color(0.16, 0.20, 0.26, 1.0), true)
	_draw_rounded_box(canvas, pouch_r, 3.0, Color(0.03, 0.04, 0.06, 1.0), false, 1.5)
	canvas.draw_line(Vector2(cx + 33, cy + 12), Vector2(cx + 35, cy + 2), Color(0.1, 0.12, 0.15, 1.0), 2.0)
	
	# 7. Head: Industrial Protective Helmet & Comms
	_draw_rounded_box(canvas, Rect2(cx - 10, cy - 38, 20, 10), 3.0, Color(0.12, 0.15, 0.20, 1.0), true)
	
	var helmet_rect = Rect2(cx - 24, cy - 74, 48, 38)
	var helmet_col = base_color.lightened(0.10)
	_draw_rounded_box(canvas, helmet_rect, 18.0, helmet_col, true)
	
	# Crown Ridge
	var ridge_rect = Rect2(cx - 6, cy - 76, 12, 16)
	_draw_rounded_box(canvas, ridge_rect, 4.0, helmet_col.lightened(0.25), true)
	_draw_rounded_box(canvas, ridge_rect, 4.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.0)
	_draw_rounded_box(canvas, helmet_rect, 18.0, Color(0.02, 0.03, 0.05, 0.95), false, 3.0)
	canvas.draw_line(Vector2(cx - 25, cy - 54), Vector2(cx + 25, cy - 54), Color(0.03, 0.04, 0.06, 1.0), 3.0)
	
	# Mini hazard pip on helmet
	canvas.draw_circle(Vector2(cx, cy - 64), 3.0, Color(0.95, 0.75, 0.10, 1.0))
	canvas.draw_circle(Vector2(cx, cy - 64), 1.5, Color(0.1, 0.1, 0.1, 1.0))
	
	# Comm Ear Cups
	var ear_l = Rect2(cx - 28, cy - 60, 6, 16)
	var ear_r = Rect2(cx + 22, cy - 60, 6, 16)
	_draw_rounded_box(canvas, ear_l, 3.0, Color(0.08, 0.10, 0.14, 1.0), true)
	_draw_rounded_box(canvas, ear_l, 3.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.5)
	_draw_rounded_box(canvas, ear_r, 3.0, Color(0.08, 0.10, 0.14, 1.0), true)
	_draw_rounded_box(canvas, ear_r, 3.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.5)
	canvas.draw_line(Vector2(cx - 26, cy - 50), Vector2(cx - 16, cy - 42), Color(0.1, 0.12, 0.16, 1.0), 2.0)
	canvas.draw_circle(Vector2(cx - 15, cy - 42), 2.0, Color(0.05, 0.06, 0.08, 1.0))
	
	if not is_facing_back:
		# 8. Narrow Protective Visor
		var visor_center = Vector2(cx, cy - 50)
		var visor_rx = 18.0
		var visor_ry = 8.0
		_draw_ellipse(canvas, visor_center, visor_rx + 2, visor_ry + 2, Color(0.02, 0.03, 0.05, 1.0))
		_draw_ellipse(canvas, visor_center, visor_rx, visor_ry, Color(0.08, 0.12, 0.18, 1.0))
		
		# Visor sheen
		var is_impostor = (assigned_role == NetworkConfig.PlayerRole.IMPOSTOR)
		var glass_tone = Color(0.12, 0.55, 0.75, 0.75) if not is_impostor else Color(0.85, 0.15, 0.20, 0.85)
		_draw_ellipse(canvas, Vector2(visor_center.x, visor_center.y + 1), visor_rx - 2, visor_ry - 2, glass_tone)
		_draw_ellipse(canvas, Vector2(visor_center.x + 5, visor_center.y - 2), 6.0, 2.0, Color(1.0, 1.0, 1.0, 0.80))
		
		# 9. Half-Face Respirator Mask with dual particulate filters
		var resp_rect = Rect2(cx - 15, cy - 44, 30, 16)
		_draw_rounded_box(canvas, resp_rect, 6.0, Color(0.16, 0.20, 0.26, 1.0), true)
		_draw_rounded_box(canvas, resp_rect, 6.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.2)
		
		_draw_ellipse(canvas, Vector2(cx - 9, cy - 38), 5.0, 5.0, Color(0.25, 0.30, 0.38, 1.0))
		_draw_ellipse(canvas, Vector2(cx - 9, cy - 38), 5.0, 5.0, Color(0.04, 0.05, 0.07, 1.0), true, 1.2)
		_draw_ellipse(canvas, Vector2(cx + 9, cy - 38), 5.0, 5.0, Color(0.25, 0.30, 0.38, 1.0))
		_draw_ellipse(canvas, Vector2(cx + 9, cy - 38), 5.0, 5.0, Color(0.04, 0.05, 0.07, 1.0), true, 1.2)

## Helper to draw rounded rectangle boxes
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

func _draw_ellipse(canvas: Control, center: Vector2, rx: float, ry: float, color: Color, outline: bool = false, width: float = 2.0) -> void:
	var points = PackedVector2Array()
	var segments = 24
	for i in range(segments):
		var angle = (float(i) / float(segments)) * TAU
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	if outline:
		points.append(points[0])
		canvas.draw_polyline(points, color, width)
	else:
		canvas.draw_colored_polygon(points, color)

## Layout for Stage 2 (Local Player Character Revealed in Dark Scene)
func _layout_characters_for_stage_2() -> void:
	var is_impostor = (assigned_role == NetworkConfig.PlayerRole.IMPOSTOR)
	
	if _local_character_node != null:
		_local_character_node.visible = true
		if is_impostor:
			# Impostor: Looming close-up right in front of camera, legs touching bottom edge of viewport (y=720)
			_local_character_node.position = Vector2(960, 530)
			_local_character_node.scale = Vector2(3.2, 3.2)
		else:
			# Crewmate: Positioned at the CENTER of the composition
			_local_character_node.position = Vector2(560, 390)
			_local_character_node.scale = Vector2(0.92, 0.92)
			
	if background_characters_container != null:
		background_characters_container.visible = false
		background_characters_container.modulate.a = 0.0

## Layout for Stage 3 (Environment Lights Up & Other Characters Revealed)
func _layout_characters_for_stage_3() -> void:
	var is_impostor = (assigned_role == NetworkConfig.PlayerRole.IMPOSTOR)
	
	if is_impostor:
		# IMPOSTOR COMPOSITION:
		# 1. Looming Impostor remains close-up in the right foreground, legs touching bottom edge
		if _local_character_node != null:
			_local_character_node.visible = true
			_local_character_node.position = Vector2(960, 530)
			_local_character_node.scale = Vector2(3.2, 3.2)
			
		# 2. 7 Crew members positioned farther back along the rear wall where the chairs/consoles are
		var impostor_crew_layout = [
			{"pos": Vector2(320, 280), "scale": 0.64}, # Rear-Left
			{"pos": Vector2(430, 275), "scale": 0.62}, # Rear-Mid-Left
			{"pos": Vector2(540, 275), "scale": 0.63}, # Rear-Mid-Right
			{"pos": Vector2(650, 280), "scale": 0.64}, # Rear-Right
			{"pos": Vector2(375, 315), "scale": 0.72}, # Front-Mid-Left
			{"pos": Vector2(485, 315), "scale": 0.72}, # Front-Mid-Center
			{"pos": Vector2(595, 315), "scale": 0.72}  # Front-Mid-Right
		]
		
		if background_characters_container != null:
			for i in range(_bg_character_nodes.size()):
				var node = _bg_character_nodes[i]
				if i < impostor_crew_layout.size():
					node.visible = true
					node.position = impostor_crew_layout[i]["pos"]
					var sc = impostor_crew_layout[i]["scale"]
					node.scale = Vector2(sc, sc)
				else:
					node.visible = false
	else:
		# CREWMATE COMPOSITION (Change 3 & 4):
		# Local Player remains at center focal position without moving
		if _local_character_node != null:
			_local_character_node.visible = true
			_local_character_node.position = Vector2(560, 390)
			_local_character_node.scale = Vector2(0.92, 0.92)
			
		# 7 other characters arranged naturally in depth around the center player:
		# Row 1 (Back): 2 characters
		# Row 2 (Mid): 2 characters (left and right of local player)
		# Row 3 (Front): 2 characters
		# Row 4 (Front-Center Point): 1 character
		var crew_layout = [
			{"pos": Vector2(420, 345), "scale": 0.78}, # Back-Left
			{"pos": Vector2(700, 345), "scale": 0.78}, # Back-Right
			{"pos": Vector2(280, 405), "scale": 0.90}, # Mid-Left
			{"pos": Vector2(840, 405), "scale": 0.90}, # Mid-Right
			{"pos": Vector2(400, 465), "scale": 0.98}, # Front-Left
			{"pos": Vector2(720, 465), "scale": 0.98}, # Front-Right
			{"pos": Vector2(560, 520), "scale": 1.02}  # Front-Center Point
		]
		
		if background_characters_container != null:
			for i in range(_bg_character_nodes.size()):
				var node = _bg_character_nodes[i]
				if i < crew_layout.size():
					node.visible = true
					node.position = crew_layout[i]["pos"]
					var sc = crew_layout[i]["scale"]
					node.scale = Vector2(sc, sc)
				else:
					node.visible = false
