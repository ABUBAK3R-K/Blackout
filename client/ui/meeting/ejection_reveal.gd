class_name EjectionRevealScreen
extends Control

## EjectionRevealScreen — Member 5 (UI/UX Frontend)
## Authoritative Ejection Reveal Screen for BLACKOUT.
##
## Displays the authoritative result after voting concludes:
## 1. Player Ejected: Shows player identity, suit avatar, and role (strictly if authoritative data provides it).
## 2. Vote Tied: Displays 'VOTE TIED' // 'NO ONE EJECTED'.
## 3. Skip Vote: Displays 'SKIPPED' // 'NO ONE EJECTED'.
## 4. Unknown / No Votes: Displays 'NO ONE EJECTED'.
##
## Strict Authoritative Rule:
## - Frontend does NOT calculate outcomes, determine winners, resolve ties, or infer roles.

signal reveal_started()
signal reveal_completed()
signal reveal_dismissed()

const NetworkConfig = preload("res://shared/network_config.gd")
const MeetingConfig = preload("res://shared/meeting_config.gd")

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

## Styling Constants
const COLOR_EJECTED_RED: Color = Color(1.0, 0.28, 0.32, 1.0)
const COLOR_CREW_CYAN: Color = Color(0.0, 0.88, 1.0, 1.0)
const COLOR_SKIP_AMBER: Color = Color(1.0, 0.82, 0.35, 1.0)
const COLOR_TIE_MUTED: Color = Color(0.70, 0.74, 0.82, 1.0)
const COLOR_IMPOSTOR_RED: Color = Color(1.0, 0.15, 0.22, 1.0)

## Node references
@onready var background_darkness: ColorRect = find_child("BackgroundDarkness", true, false)
@onready var modal_card: PanelContainer = find_child("ModalCard", true, false)
@onready var header_protocol_label: Label = find_child("ProtocolLabel", true, false)
@onready var avatar_container: Control = find_child("AvatarContainer", true, false)
@onready var avatar_canvas: Control = find_child("AvatarCanvas", true, false)
@onready var outcome_title_label: Label = find_child("OutcomeTitleLabel", true, false)
@onready var outcome_status_label: Label = find_child("OutcomeStatusLabel", true, false)
@onready var role_badge: PanelContainer = find_child("RoleBadge", true, false)
@onready var role_label: Label = find_child("RoleLabel", true, false)
@onready var footer_notice_label: Label = find_child("FooterNoticeLabel", true, false)

## Internal state
var _is_active: bool = false
var _current_result: Dictionary = {}
var _current_slot: int = 1
var _active_tween: Tween = null
var _drift_time: float = 0.0

func _ready() -> void:
	_ensure_node_references()
	visible = false
	modulate.a = 0.0

func _ensure_node_references() -> void:
	if background_darkness == null:
		background_darkness = find_child("BackgroundDarkness", true, false) as ColorRect
	if modal_card == null:
		modal_card = find_child("ModalCard", true, false) as PanelContainer
	if header_protocol_label == null:
		header_protocol_label = find_child("ProtocolLabel", true, false) as Label
	if avatar_container == null:
		avatar_container = find_child("AvatarContainer", true, false) as Control
	if avatar_canvas == null:
		avatar_canvas = find_child("AvatarCanvas", true, false) as Control
	if outcome_title_label == null:
		outcome_title_label = find_child("OutcomeTitleLabel", true, false) as Label
	if outcome_status_label == null:
		outcome_status_label = find_child("OutcomeStatusLabel", true, false) as Label
	if role_badge == null:
		role_badge = find_child("RoleBadge", true, false) as PanelContainer
	if role_label == null:
		role_label = find_child("RoleLabel", true, false) as Label
	if footer_notice_label == null:
		footer_notice_label = find_child("FooterNoticeLabel", true, false) as Label

func _process(delta: float) -> void:
	if _is_active and avatar_container != null and avatar_container.visible:
		_drift_time += delta * 1.5
		# Gentle subtle sci-fi zero-gravity drift
		var drift_y = sin(_drift_time) * 4.0
		var rot_deg = sin(_drift_time * 0.8) * 1.5
		avatar_container.position.y = drift_y
		avatar_container.rotation_degrees = rot_deg

## Main Public API to trigger the Ejection Reveal sequence from authoritative result data
func play_ejection_reveal(result_data: Dictionary, players_data: Array = []) -> void:
	_ensure_node_references()
	_current_result = result_data.duplicate()
	_is_active = true
	_drift_time = 0.0
	
	var elim_id: int = int(result_data.get("eliminated_peer_id", 0))
	var is_tie: bool = bool(result_data.get("is_tie", false))
	var is_skip: bool = bool(result_data.get("is_skip", false))
	var has_role_info: bool = result_data.has("was_impostor")
	var was_impostor: bool = bool(result_data.get("was_impostor", false))
	
	# Find player slot from authoritative players data
	_current_slot = 1
	var player_name: String = "Player %d" % elim_id
	for p in players_data:
		if int(p.get("peer_id", 0)) == elim_id:
			_current_slot = int(p.get("player_slot", 1))
			player_name = "Player %d" % (elim_id if elim_id > 0 else _current_slot)
			break
			
	# Setup outcome presentation
	if elim_id > 0:
		_setup_ejected_player(player_name, _current_slot, has_role_info, was_impostor)
	elif is_tie:
		_setup_tie_outcome()
	elif is_skip or elim_id == 0:
		_setup_skip_outcome()
	else:
		_setup_neutral_outcome()
		
	_start_reveal_animation()
	reveal_started.emit()

## Ejected Player Outcome Configuration
func _setup_ejected_player(p_name: String, slot: int, has_role: bool, was_impostor: bool) -> void:
	if avatar_container != null:
		avatar_container.visible = true
		_redraw_avatar(slot)
		
	if outcome_title_label != null:
		outcome_title_label.text = p_name.to_upper()
		outcome_title_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0, 1.0))
		
	if outcome_status_label != null:
		outcome_status_label.text = "EJECTED"
		outcome_status_label.add_theme_color_override("font_color", COLOR_EJECTED_RED)
		
	if role_badge != null:
		if has_role:
			role_badge.visible = true
			if role_label != null:
				if was_impostor:
					role_label.text = "%s WAS THE IMPOSTOR" % p_name.to_upper()
					role_label.add_theme_color_override("font_color", COLOR_IMPOSTOR_RED)
					_style_role_badge(Color(0.25, 0.08, 0.10, 0.95), COLOR_IMPOSTOR_RED)
				else:
					role_label.text = "%s WAS NOT THE IMPOSTOR" % p_name.to_upper()
					role_label.add_theme_color_override("font_color", COLOR_CREW_CYAN)
					_style_role_badge(Color(0.06, 0.18, 0.22, 0.95), COLOR_CREW_CYAN)
		else:
			role_badge.visible = false
			
	if footer_notice_label != null:
		footer_notice_label.text = "Facility containment cycle completed. Personnel status updated."

## Tie Outcome Configuration
func _setup_tie_outcome() -> void:
	if avatar_container != null:
		avatar_container.visible = false
		
	if outcome_title_label != null:
		outcome_title_label.text = "VOTE TIED"
		outcome_title_label.add_theme_color_override("font_color", COLOR_TIE_MUTED)
		
	if outcome_status_label != null:
		outcome_status_label.text = "NO ONE EJECTED"
		outcome_status_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
		
	if role_badge != null:
		role_badge.visible = false
		
	if footer_notice_label != null:
		footer_notice_label.text = "Ballot plurality unresolved. Facility security protocols remain active."

## Skip Outcome Configuration
func _setup_skip_outcome() -> void:
	if avatar_container != null:
		avatar_container.visible = false
		
	if outcome_title_label != null:
		outcome_title_label.text = "SKIPPED"
		outcome_title_label.add_theme_color_override("font_color", COLOR_SKIP_AMBER)
		
	if outcome_status_label != null:
		outcome_status_label.text = "NO ONE EJECTED"
		outcome_status_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96, 1.0))
		
	if role_badge != null:
		role_badge.visible = false
		
	if footer_notice_label != null:
		footer_notice_label.text = "Skip plurality acknowledged by authoritative consensus."

## Neutral Outcome Configuration
func _setup_neutral_outcome() -> void:
	if avatar_container != null:
		avatar_container.visible = false
	if outcome_title_label != null:
		outcome_title_label.text = "NO VOTES CAST"
	if outcome_status_label != null:
		outcome_status_label.text = "NO ONE EJECTED"
	if role_badge != null:
		role_badge.visible = false
	if footer_notice_label != null:
		footer_notice_label.text = "Meeting concluded without recorded ejection."

## Styling helper for the Role Badge
func _style_role_badge(bg_col: Color, border_col: Color) -> void:
	if role_badge == null:
		return
	var style = StyleBoxFlat.new()
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.bg_color = bg_col
	style.set_border_width_all(1)
	style.border_color = border_col
	style.set_corner_radius_all(6)
	role_badge.add_theme_stylebox_override("panel", style)

## Smooth Reveal Animation Sequence
func _start_reveal_animation() -> void:
	visible = true
	modulate.a = 0.0
	
	if modal_card != null:
		modal_card.scale = Vector2(0.92, 0.92)
		
	if outcome_status_label != null:
		outcome_status_label.modulate.a = 0.0
		
	if role_badge != null and role_badge.visible:
		role_badge.modulate.a = 0.0
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	
	# Step 1: Fade in full overlay & scale card
	_active_tween.set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.35)
	if modal_card != null:
		_active_tween.tween_property(modal_card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.set_parallel(false)
	
	# Step 2: Settle status label (EJECTED / NO ONE EJECTED)
	if outcome_status_label != null:
		_active_tween.tween_property(outcome_status_label, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	# Step 3: Reveal Role Badge if visible
	if role_badge != null and role_badge.visible:
		_active_tween.tween_property(role_badge, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
	_active_tween.tween_callback(func():
		reveal_completed.emit()
	)

## Dismisses the reveal screen smoothly
func dismiss_reveal(animated: bool = true) -> void:
	_is_active = false
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	if animated:
		_active_tween = create_tween()
		_active_tween.tween_property(self, "modulate:a", 0.0, 0.3)
		_active_tween.tween_callback(func():
			visible = false
			reveal_dismissed.emit()
		)
	else:
		visible = false
		modulate.a = 0.0
		reveal_dismissed.emit()

## Returns whether the ejection reveal is currently active
func is_reveal_active() -> bool:
	return _is_active

## Returns the current authoritative result stored in the reveal screen
func get_current_result() -> Dictionary:
	return _current_result

## 2D Astronaut Drawing
func _redraw_avatar(slot: int) -> void:
	if avatar_canvas == null:
		return
	var color_index = clampi(slot - 1, 0, PLAYER_PALETTE.size() - 1)
	var suit_color = PLAYER_PALETTE[color_index]
	
	if avatar_canvas.is_connected("draw", _on_draw_avatar_canvas):
		avatar_canvas.disconnect("draw", _on_draw_avatar_canvas)
	avatar_canvas.draw.connect(_on_draw_avatar_canvas.bind(suit_color))
	avatar_canvas.queue_redraw()

func _on_draw_avatar_canvas(suit_color: Color) -> void:
	if avatar_canvas == null:
		return
	var w = avatar_canvas.size.x
	var h = avatar_canvas.size.y
	var cx = w * 0.5
	var cy = h * 0.45
	
	# 1. Ground Drop Shadow & Wet Floor Contact
	_draw_ellipse(avatar_canvas, Vector2(cx, cy + 72), 40, 11, Color(0.0, 0.0, 0.0, 0.70))
	_draw_ellipse(avatar_canvas, Vector2(cx, cy + 72), 24, 5, Color(0.0, 0.0, 0.0, 0.90))
	
	# 2. Heavy Industrial Steel-Toe Boots
	var boot_dark = Color(0.08, 0.09, 0.12, 1.0)
	var steel_cap = Color(0.24, 0.28, 0.35, 1.0)
	var l_boot = Rect2(cx - 24, cy + 46, 18, 22)
	var r_boot = Rect2(cx + 6, cy + 46, 18, 22)
	
	_draw_rounded_box(avatar_canvas, l_boot, 4.0, boot_dark, true)
	_draw_rounded_box(avatar_canvas, l_boot, 4.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.0)
	_draw_rounded_box(avatar_canvas, Rect2(cx - 24, cy + 56, 18, 12), 3.0, steel_cap, true)
	avatar_canvas.draw_line(Vector2(cx - 24, cy + 66), Vector2(cx - 6, cy + 66), Color(0.95, 0.75, 0.10, 0.9), 1.8)
	
	_draw_rounded_box(avatar_canvas, r_boot, 4.0, boot_dark, true)
	_draw_rounded_box(avatar_canvas, r_boot, 4.0, Color(0.02, 0.03, 0.05, 1.0), false, 2.0)
	_draw_rounded_box(avatar_canvas, Rect2(cx + 6, cy + 56, 18, 12), 3.0, steel_cap, true)
	avatar_canvas.draw_line(Vector2(cx + 6, cy + 66), Vector2(cx + 24, cy + 66), Color(0.95, 0.75, 0.10, 0.9), 1.8)
	
	# 3. Heavy-Duty Coverall Pants & Kneepads
	var leg_dark = suit_color.darkened(0.30)
	var leg_mid = suit_color.darkened(0.10)
	var l_leg = Rect2(cx - 22, cy + 12, 18, 38)
	var r_leg = Rect2(cx + 4, cy + 12, 18, 38)
	
	_draw_rounded_box(avatar_canvas, l_leg, 5.0, leg_dark, true)
	_draw_rounded_box(avatar_canvas, l_leg, 5.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.2)
	_draw_rounded_box(avatar_canvas, r_leg, 5.0, leg_mid, true)
	_draw_rounded_box(avatar_canvas, r_leg, 5.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.2)
	
	# Ballistic Kneepads
	var kneepad_col = Color(0.12, 0.15, 0.20, 1.0)
	_draw_rounded_box(avatar_canvas, Rect2(cx - 20, cy + 26, 14, 15), 3.0, kneepad_col, true)
	_draw_rounded_box(avatar_canvas, Rect2(cx - 20, cy + 26, 14, 15), 3.0, Color(0.03, 0.04, 0.06, 1.0), false, 1.8)
	_draw_rounded_box(avatar_canvas, Rect2(cx + 6, cy + 26, 14, 15), 3.0, kneepad_col, true)
	_draw_rounded_box(avatar_canvas, Rect2(cx + 6, cy + 26, 14, 15), 3.0, Color(0.03, 0.04, 0.06, 1.0), false, 1.8)
	
	# 4. Arms & Heavy Work Gloves
	var arm_l = Rect2(cx - 36, cy - 28, 14, 40)
	var arm_r = Rect2(cx + 22, cy - 28, 14, 40)
	_draw_rounded_box(avatar_canvas, arm_l, 5.0, suit_color.darkened(0.25), true)
	_draw_rounded_box(avatar_canvas, arm_l, 5.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.2)
	_draw_rounded_box(avatar_canvas, arm_r, 5.0, suit_color.darkened(0.08), true)
	_draw_rounded_box(avatar_canvas, arm_r, 5.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.2)
	
	# Work Gloves
	var glove_col = Color(0.10, 0.13, 0.18, 1.0)
	var glove_l = Rect2(cx - 37, cy + 4, 16, 17)
	var glove_r = Rect2(cx + 21, cy + 4, 16, 17)
	_draw_rounded_box(avatar_canvas, glove_l, 4.0, glove_col, true)
	_draw_rounded_box(avatar_canvas, glove_l, 4.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.8)
	_draw_rounded_box(avatar_canvas, glove_r, 4.0, glove_col, true)
	_draw_rounded_box(avatar_canvas, glove_r, 4.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.8)
	
	# 5. Torso: Heavy Coveralls + Reinforced Utility Vest
	var body_rect = Rect2(cx - 26, cy - 32, 52, 48)
	_draw_rounded_box(avatar_canvas, body_rect, 8.0, suit_color, true)
	_draw_rounded_box(avatar_canvas, body_rect, 8.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	
	# Tactical Charcoal Vest
	var vest_rect = Rect2(cx - 22, cy - 30, 44, 42)
	var vest_col = Color(0.13, 0.16, 0.21, 1.0)
	_draw_rounded_box(avatar_canvas, vest_rect, 5.0, vest_col, true)
	_draw_rounded_box(avatar_canvas, vest_rect, 5.0, Color(0.04, 0.05, 0.07, 1.0), false, 2.0)
	avatar_canvas.draw_line(Vector2(cx, cy - 30), Vector2(cx, cy + 10), Color(0.06, 0.08, 0.10, 1.0), 2.0)
	
	# Hazard Stripe on Right Shoulder Strap
	var stripe_rect = Rect2(cx + 3, cy - 28, 15, 7)
	_draw_rounded_box(avatar_canvas, stripe_rect, 2.0, Color(0.95, 0.75, 0.10, 1.0), true)
	avatar_canvas.draw_line(Vector2(cx + 6, cy - 28), Vector2(cx + 10, cy - 21), Color(0.1, 0.1, 0.1, 1.0), 1.8)
	avatar_canvas.draw_line(Vector2(cx + 11, cy - 28), Vector2(cx + 15, cy - 21), Color(0.1, 0.1, 0.1, 1.0), 1.8)
	
	# Facility ID Badge on Left Chest
	var badge_rect = Rect2(cx - 18, cy - 24, 12, 15)
	_draw_rounded_box(avatar_canvas, badge_rect, 2.0, Color(0.92, 0.94, 0.98, 1.0), true)
	_draw_rounded_box(avatar_canvas, badge_rect, 2.0, Color(0.05, 0.06, 0.08, 1.0), false, 1.0)
	avatar_canvas.draw_rect(Rect2(cx - 16, cy - 22, 5, 7), Color(0.2, 0.25, 0.35, 1.0), true)
	avatar_canvas.draw_line(Vector2(cx - 16, cy - 13), Vector2(cx - 8, cy - 13), Color(0.1, 0.5, 0.9, 1.0), 1.8)
	
	# Pen Radiation Dosimeter on Chest
	var dosimeter_rect = Rect2(cx - 4, cy - 26, 3.5, 12)
	_draw_rounded_box(avatar_canvas, dosimeter_rect, 1.5, Color(0.75, 0.80, 0.85, 1.0), true)
	_draw_rounded_box(avatar_canvas, dosimeter_rect, 1.5, Color(0.05, 0.06, 0.08, 1.0), false, 1.0)
	avatar_canvas.draw_circle(Vector2(cx - 2.2, cy - 23), 1.2, Color(0.2, 0.95, 0.4, 1.0))
	
	# 6. Tactical Belt & Pouches
	var belt_rect = Rect2(cx - 24, cy + 8, 48, 7)
	_draw_rounded_box(avatar_canvas, belt_rect, 2.0, Color(0.08, 0.10, 0.14, 1.0), true)
	_draw_rounded_box(avatar_canvas, belt_rect, 2.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.5)
	_draw_rounded_box(avatar_canvas, Rect2(cx - 4, cy + 7, 8, 9), 2.0, Color(0.55, 0.60, 0.68, 1.0), true)
	
	# Left Tool Pouch & Right Radio
	var pouch_l = Rect2(cx - 30, cy + 5, 9, 14)
	_draw_rounded_box(avatar_canvas, pouch_l, 2.5, Color(0.16, 0.20, 0.26, 1.0), true)
	avatar_canvas.draw_circle(Vector2(cx - 26, cy + 9), 1.2, Color(0.95, 0.80, 0.2, 1.0))
	
	var pouch_r = Rect2(cx + 21, cy + 5, 9, 14)
	_draw_rounded_box(avatar_canvas, pouch_r, 2.5, Color(0.16, 0.20, 0.26, 1.0), true)
	avatar_canvas.draw_line(Vector2(cx + 27, cy + 5), Vector2(cx + 29, cy - 4), Color(0.1, 0.12, 0.15, 1.0), 1.8)
	
	# 7. Head: Industrial Protective Helmet & Comms
	_draw_rounded_box(avatar_canvas, Rect2(cx - 8, cy - 36, 16, 8), 2.5, Color(0.12, 0.15, 0.20, 1.0), true)
	
	var helmet_rect = Rect2(cx - 20, cy - 68, 40, 34)
	var helmet_col = suit_color.lightened(0.10)
	_draw_rounded_box(avatar_canvas, helmet_rect, 15.0, helmet_col, true)
	
	# Crown Ridge
	var ridge_rect = Rect2(cx - 5, cy - 70, 10, 14)
	_draw_rounded_box(avatar_canvas, ridge_rect, 3.0, helmet_col.lightened(0.25), true)
	_draw_rounded_box(avatar_canvas, ridge_rect, 3.0, Color(0.02, 0.03, 0.05, 0.95), false, 1.8)
	_draw_rounded_box(avatar_canvas, helmet_rect, 15.0, Color(0.02, 0.03, 0.05, 0.95), false, 2.5)
	avatar_canvas.draw_line(Vector2(cx - 21, cy - 50), Vector2(cx + 21, cy - 50), Color(0.03, 0.04, 0.06, 1.0), 2.5)
	
	# Mini hazard pip on helmet
	avatar_canvas.draw_circle(Vector2(cx, cy - 59), 2.5, Color(0.95, 0.75, 0.10, 1.0))
	avatar_canvas.draw_circle(Vector2(cx, cy - 59), 1.2, Color(0.1, 0.1, 0.1, 1.0))
	
	# Comm Ear Cups
	var ear_l = Rect2(cx - 24, cy - 56, 5, 14)
	var ear_r = Rect2(cx + 19, cy - 56, 5, 14)
	_draw_rounded_box(avatar_canvas, ear_l, 2.5, Color(0.08, 0.10, 0.14, 1.0), true)
	_draw_rounded_box(avatar_canvas, ear_r, 2.5, Color(0.08, 0.10, 0.14, 1.0), true)
	avatar_canvas.draw_line(Vector2(cx - 22, cy - 47), Vector2(cx - 14, cy - 39), Color(0.1, 0.12, 0.16, 1.0), 1.8)
	
	# 8. Narrow Protective Visor
	var visor_center = Vector2(cx, cy - 47)
	var visor_rx = 15.0
	var visor_ry = 7.0
	_draw_ellipse(avatar_canvas, visor_center, visor_rx + 1.5, visor_ry + 1.5, Color(0.02, 0.03, 0.05, 1.0))
	_draw_ellipse(avatar_canvas, visor_center, visor_rx, visor_ry, Color(0.08, 0.12, 0.18, 1.0))
	_draw_ellipse(avatar_canvas, Vector2(visor_center.x, visor_center.y + 1), visor_rx - 1.5, visor_ry - 1.5, Color(0.12, 0.55, 0.75, 0.75))
	_draw_ellipse(avatar_canvas, Vector2(visor_center.x + 4, visor_center.y - 1.5), 5.0, 1.8, Color(1.0, 1.0, 1.0, 0.80))
	
	# 9. Half-Face Respirator Mask
	var resp_rect = Rect2(cx - 13, cy - 41, 26, 14)
	_draw_rounded_box(avatar_canvas, resp_rect, 5.0, Color(0.16, 0.20, 0.26, 1.0), true)
	_draw_rounded_box(avatar_canvas, resp_rect, 5.0, Color(0.02, 0.03, 0.05, 1.0), false, 1.8)
	
	_draw_ellipse(avatar_canvas, Vector2(cx - 8, cy - 35), 4.2, 4.2, Color(0.25, 0.30, 0.38, 1.0))
	_draw_ellipse(avatar_canvas, Vector2(cx - 8, cy - 35), 4.2, 4.2, Color(0.04, 0.05, 0.07, 1.0), true, 1.0)
	_draw_ellipse(avatar_canvas, Vector2(cx + 8, cy - 35), 4.2, 4.2, Color(0.25, 0.30, 0.38, 1.0))
	_draw_ellipse(avatar_canvas, Vector2(cx + 8, cy - 35), 4.2, 4.2, Color(0.04, 0.05, 0.07, 1.0), true, 1.0)

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
