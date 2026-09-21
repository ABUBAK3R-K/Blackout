class_name EmergencyMeetingAlert
extends Control

## EmergencyMeetingAlert — Member 5 (UI/UX Frontend)
## Full-width cinematic sci-fi emergency meeting transition alert for BLACKOUT.
##
## Faithfully inspired by the reference design:
## - Full horizontal sci-fi banner with dark translucent red/black body
## - Glowing neon red rails with stepped cybernetic circuit traces
## - Four banks of diagonal hazard caution stripes (\\\\\\ \\\\\\)
## - Prominent glowing warning triangle with exclamation mark
## - High-impact glowing "EMERGENCY MEETING" typography and tracked subtitle with divider lines

signal alert_finished()

## Visual Design Constants
const COLOR_EMERGENCY_RED: Color = Color(1.0, 0.20, 0.24, 0.98)       # Alert neon red (#FF333D)
const COLOR_EMERGENCY_GLOW: Color = Color(1.0, 0.08, 0.12, 0.85)      # Deep crimson glow
const COLOR_TEXT_MUTED: Color = Color(0.88, 0.88, 0.92, 0.95)         # Crisp subtext
const ALERT_DISPLAY_DURATION: float = 1.3                              # Seconds before auto-fadeout (total animation < 2.0s)

## Node references
@onready var banner_canvas: Control = $BannerCanvas
@onready var content_container: VBoxContainer = $ContentContainer
@onready var title_label: Label = $ContentContainer/TitleLabel
@onready var subtitle_row: HBoxContainer = $ContentContainer/SubtitleRow
@onready var subtitle_label: Label = $ContentContainer/SubtitleRow/SubtitleLabel
@onready var left_line: ColorRect = $ContentContainer/SubtitleRow/LeftLine
@onready var right_line: ColorRect = $ContentContainer/SubtitleRow/RightLine

## Internal state
var _is_active: bool = false
var _pulse_timer: float = 0.0
var _active_tween: Tween = null
var _pulse_tween: Tween = null

func _ready() -> void:
	_ensure_node_references()
	if banner_canvas != null and not banner_canvas.draw.is_connected(_draw_banner):
		banner_canvas.draw.connect(func(): _draw_banner(banner_canvas))
	visible = false
	modulate.a = 0.0

func _ensure_node_references() -> void:
	if banner_canvas == null and has_node("BannerCanvas"):
		banner_canvas = get_node("BannerCanvas")
	if content_container == null and has_node("ContentContainer"):
		content_container = get_node("ContentContainer")
	if title_label == null and has_node("ContentContainer/TitleLabel"):
		title_label = get_node("ContentContainer/TitleLabel")
	if subtitle_row == null and has_node("ContentContainer/SubtitleRow"):
		subtitle_row = get_node("ContentContainer/SubtitleRow")
	if subtitle_label == null and has_node("ContentContainer/SubtitleRow/SubtitleLabel"):
		subtitle_label = get_node("ContentContainer/SubtitleRow/SubtitleLabel")
	if left_line == null and has_node("ContentContainer/SubtitleRow/LeftLine"):
		left_line = get_node("ContentContainer/SubtitleRow/LeftLine")
	if right_line == null and has_node("ContentContainer/SubtitleRow/RightLine"):
		right_line = get_node("ContentContainer/SubtitleRow/RightLine")

func _process(delta: float) -> void:
	if _is_active:
		_pulse_timer += delta
		if banner_canvas != null:
			banner_canvas.queue_redraw()

## Triggers the Emergency Meeting alert animation
func trigger_alert(caller_peer_id: int = 0, custom_message: String = "") -> void:
	_ensure_node_references()
	_is_active = true
	_pulse_timer = 0.0
	
	# Configure context message from authoritative information
	if not custom_message.is_empty():
		subtitle_label.text = custom_message.to_upper()
	elif caller_peer_id > 0:
		subtitle_label.text = "CALLED BY PLAYER %d" % caller_peer_id
	else:
		subtitle_label.text = "MEETING STARTED"
		
	_play_entrance_animation()

## Plays entrance animation with smooth scale/punch and auto-dismiss
func _play_entrance_animation() -> void:
	visible = true
	scale = Vector2(1.0, 0.88)
	pivot_offset = size * 0.5 if size != Vector2.ZERO else Vector2(640, 360)
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 1.0, 0.18).from(0.0)
	_active_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Schedule auto-dismiss after display duration (total duration < 2.0s)
	var main_tree = get_tree() if is_inside_tree() else Engine.get_main_loop() as SceneTree
	if main_tree != null:
		var timer = main_tree.create_timer(ALERT_DISPLAY_DURATION)
		timer.timeout.connect(func():
			if _is_active:
				dismiss_alert(false)
		)

## Dismisses the alert with smooth fadeout
func dismiss_alert(immediate: bool = false) -> void:
	_is_active = false
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
		
	if immediate:
		visible = false
		modulate.a = 0.0
		alert_finished.emit()
		return
		
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween().set_parallel(true)
	_active_tween.tween_property(self, "modulate:a", 0.0, 0.22)
	_active_tween.tween_property(self, "scale", Vector2(1.0, 0.94), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_active_tween.chain().tween_callback(func():
		visible = false
		alert_finished.emit()
	)

func is_alert_active() -> bool:
	return _is_active

## -----------------------------------------------------------------------------
## Custom Sci-Fi Canvas Drawing (Matching Reference Image)
## -----------------------------------------------------------------------------
func _draw_banner(canvas: Control) -> void:
	var w: float = canvas.size.x
	var h: float = canvas.size.y
	if w <= 10.0 or h <= 10.0:
		return
		
	var cy: float = h * 0.5
	var half_banner_h: float = 105.0
	var y1: float = cy - half_banner_h
	var y2: float = cy + half_banner_h
	var cx: float = w * 0.5
	
	# Pulse brightness factor (alive breathing neon glow)
	var pulse: float = 0.88 + 0.12 * sin(_pulse_timer * 4.5)
	
	# 1. Main Banner Backdrop Polygon (Dark Reddish-Black Translucent Panel)
	var bg_points = PackedVector2Array([
		Vector2(0, y1),
		Vector2(w, y1),
		Vector2(w, y2),
		Vector2(0, y2)
	])
	canvas.draw_colored_polygon(bg_points, Color(0.04, 0.012, 0.015, 0.92))
	
	# Center glowing gradient strip
	var glow_strip = PackedVector2Array([
		Vector2(0, cy - 48),
		Vector2(w, cy - 48),
		Vector2(w, cy + 48),
		Vector2(0, cy + 48)
	])
	canvas.draw_colored_polygon(glow_strip, Color(0.65, 0.05, 0.08, 0.14 * pulse))
	
	# 2. Glowing Neon Rails (Top and Bottom) with Stepped Circuit Accents
	var rail_glow_broad = Color(1.0, 0.08, 0.12, 0.25 * pulse)
	var rail_glow_mid = Color(1.0, 0.15, 0.20, 0.60 * pulse)
	var rail_core = Color(1.0, 0.45, 0.48, pulse)
	
	# --- Top Rail ---
	canvas.draw_line(Vector2(0, y1), Vector2(w, y1), rail_glow_broad, 9.0)
	canvas.draw_line(Vector2(0, y1), Vector2(w, y1), rail_glow_mid, 4.5)
	canvas.draw_line(Vector2(0, y1), Vector2(w, y1), rail_core, 2.5)
	
	# Left stepped circuit trace (top)
	var left_top_circuit = PackedVector2Array([
		Vector2(160, y1),
		Vector2(140, y1 + 10),
		Vector2(50, y1 + 10),
		Vector2(30, y1 + 20),
		Vector2(0, y1 + 20)
	])
	canvas.draw_polyline(left_top_circuit, rail_glow_mid, 3.5)
	canvas.draw_polyline(left_top_circuit, rail_core, 1.5)
	
	# Right stepped circuit trace (top)
	var right_top_circuit = PackedVector2Array([
		Vector2(w - 160, y1),
		Vector2(w - 140, y1 + 10),
		Vector2(w - 50, y1 + 10),
		Vector2(w - 30, y1 + 20),
		Vector2(w, y1 + 20)
	])
	canvas.draw_polyline(right_top_circuit, rail_glow_mid, 3.5)
	canvas.draw_polyline(right_top_circuit, rail_core, 1.5)
	
	# --- Bottom Rail ---
	canvas.draw_line(Vector2(0, y2), Vector2(w, y2), rail_glow_broad, 9.0)
	canvas.draw_line(Vector2(0, y2), Vector2(w, y2), rail_glow_mid, 4.5)
	canvas.draw_line(Vector2(0, y2), Vector2(w, y2), rail_core, 2.5)
	
	# Left stepped circuit trace (bottom)
	var left_bottom_circuit = PackedVector2Array([
		Vector2(160, y2),
		Vector2(140, y2 - 10),
		Vector2(50, y2 - 10),
		Vector2(30, y2 - 20),
		Vector2(0, y2 - 20)
	])
	canvas.draw_polyline(left_bottom_circuit, rail_glow_mid, 3.5)
	canvas.draw_polyline(left_bottom_circuit, rail_core, 1.5)
	
	# Right stepped circuit trace (bottom)
	var right_bottom_circuit = PackedVector2Array([
		Vector2(w - 160, y2),
		Vector2(w - 140, y2 - 10),
		Vector2(w - 50, y2 - 10),
		Vector2(w - 30, y2 - 20),
		Vector2(w, y2 - 20)
	])
	canvas.draw_polyline(right_bottom_circuit, rail_glow_mid, 3.5)
	canvas.draw_polyline(right_bottom_circuit, rail_core, 1.5)
	
	# 3. Four Banks of Diagonal Hazard Caution Stripes (\\\\\\ \\\\\\)
	# Matching reference angle: top-right to bottom-left tilt
	var stripe_col = Color(0.96, 0.18, 0.22, 0.82 * pulse)
	var stripe_dx: float = -14.0 # Angled \ (dx < 0)
	var stripe_h: float = 20.0
	var stripe_spacing: float = 16.0
	var stripe_w: float = 4.0
	
	# Bank 1: Top-Left (from x=180 to x=480)
	var bx: float = 180.0
	while bx <= 480.0 and bx < cx - 180.0:
		canvas.draw_line(Vector2(bx, y1 + 10), Vector2(bx + stripe_dx, y1 + 10 + stripe_h), stripe_col, stripe_w)
		bx += stripe_spacing
		
	# Bank 2: Top-Right (from x=w-480 to x=w-180)
	bx = max(cx + 180.0, w - 480.0)
	while bx <= w - 180.0:
		canvas.draw_line(Vector2(bx, y1 + 10), Vector2(bx + stripe_dx, y1 + 10 + stripe_h), stripe_col, stripe_w)
		bx += stripe_spacing
		
	# Bank 3: Bottom-Left (from x=180 to x=480)
	bx = 180.0
	while bx <= 480.0 and bx < cx - 180.0:
		canvas.draw_line(Vector2(bx, y2 - 10 - stripe_h), Vector2(bx + stripe_dx, y2 - 10), stripe_col, stripe_w)
		bx += stripe_spacing
		
	# Bank 4: Bottom-Right (from x=w-480 to x=w-180)
	bx = max(cx + 180.0, w - 480.0)
	while bx <= w - 180.0:
		canvas.draw_line(Vector2(bx, y2 - 10 - stripe_h), Vector2(bx + stripe_dx, y2 - 10), stripe_col, stripe_w)
		bx += stripe_spacing
		
	# 4. Central Glowing Warning Triangle with Exclamation Point
	# Positioned on top of the banner, overlapping the top rail
	var tri_top = Vector2(cx, y1 - 32)
	var tri_left = Vector2(cx - 36, y1 + 28)
	var tri_right = Vector2(cx + 36, y1 + 28)
	var tri_points = PackedVector2Array([tri_top, tri_right, tri_left, tri_top])
	
	# Triangle solid dark backdrop
	canvas.draw_colored_polygon(PackedVector2Array([tri_top, tri_right, tri_left]), Color(0.05, 0.012, 0.015, 0.98))
	
	# Triangle outer broad glow
	canvas.draw_polyline(tri_points, Color(1.0, 0.08, 0.12, 0.45 * pulse), 9.0)
	# Triangle mid glow
	canvas.draw_polyline(tri_points, Color(1.0, 0.22, 0.25, 0.85 * pulse), 5.0)
	# Triangle crisp neon outline
	canvas.draw_polyline(tri_points, Color(1.0, 0.55, 0.58, pulse), 2.8)
	
	# Exclamation Mark inside Triangle
	var mark_top_y = y1 - 10
	var mark_bot_y = y1 + 10
	var mark_dot_y = y1 + 19
	
	# Exclamation bar glow + core
	canvas.draw_line(Vector2(cx, mark_top_y), Vector2(cx, mark_bot_y), Color(1.0, 0.10, 0.15, 0.80 * pulse), 7.0)
	canvas.draw_line(Vector2(cx, mark_top_y), Vector2(cx, mark_bot_y), Color(1.0, 0.95, 0.95, 1.0), 3.8)
	
	# Exclamation dot glow + core
	canvas.draw_circle(Vector2(cx, mark_dot_y), 4.5, Color(1.0, 0.10, 0.15, 0.80 * pulse))
	canvas.draw_circle(Vector2(cx, mark_dot_y), 2.4, Color(1.0, 0.95, 0.95, 1.0))
