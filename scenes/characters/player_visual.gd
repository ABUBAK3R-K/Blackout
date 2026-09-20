class_name PlayerVisual
extends Node2D

## PlayerVisual
## Standardized 2D Character Visual & Animation Controller for 8-player suits and ghost state.
## Member 7 (Fatima - 2D Environment & Technical Artist).

enum Direction {
	DOWN = 0,
	UP = 1,
	RIGHT = 2,
	LEFT = 3
}

const COLOR_PALETTES: Array[String] = [
	"red",
	"blue",
	"green",
	"yellow",
	"orange",
	"purple",
	"cyan",
	"white"
]

const COLOR_HEX_VALUES: Array[Color] = [
	Color("#e53935"), # Red
	Color("#1e88e5"), # Blue
	Color("#43a047"), # Green
	Color("#fdd835"), # Yellow
	Color("#fb8c00"), # Orange
	Color("#8e24aa"), # Purple
	Color("#00acc1"), # Cyan
	Color("#eceff1")  # White
]

const DIR_NAMES: Dictionary = {
	Direction.DOWN: "down",
	Direction.UP: "up",
	Direction.RIGHT: "right",
	Direction.LEFT: "left"
}

@export var player_color_id: int = 0
@export var player_color_name: String = "red"
@export var current_direction: Direction = Direction.DOWN
@export var current_animation: String = "idle"
@export var is_ghost: bool = false
@export var is_moving: bool = false

## Visual Components
@export var sprite: Sprite2D
@export var animation_player: AnimationPlayer
@export var flashlight_anchor: Marker2D

## Textures Cache
var _textures: Dictionary = {}
var _anim_timer: float = 0.0
var _anim_frame: int = 0

## Signals
signal animation_state_changed(anim_name: String, direction_name: String)
signal color_changed(color_id: int, color_name: String)

func _ready() -> void:
	z_index = 1
	y_sort_enabled = true
	
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
	if not animation_player:
		animation_player = get_node_or_null("AnimationPlayer")
	if not flashlight_anchor:
		flashlight_anchor = get_node_or_null("FlashlightAnchor")
		
	_preload_textures()
	set_color(player_color_id)
	_update_frame()

func _preload_textures() -> void:
	for cname in COLOR_PALETTES:
		var path = "res://assets/sprites/characters/char_%s.png" % cname
		if ResourceLoader.exists(path):
			_textures[cname] = load(path)
			
	var ghost_path = "res://assets/sprites/characters/char_ghost.png"
	if ResourceLoader.exists(ghost_path):
		_textures["ghost"] = load(ghost_path)

func set_color(color_idx: int) -> void:
	player_color_id = clampi(color_idx, 0, COLOR_PALETTES.size() - 1)
	player_color_name = COLOR_PALETTES[player_color_id]
	_apply_texture()
	color_changed.emit(player_color_id, player_color_name)

func set_color_name(cname: String) -> void:
	var idx = COLOR_PALETTES.find(cname.to_lower())
	if idx != -1:
		set_color(idx)

func get_color_name() -> String:
	return player_color_name

func get_color_hex() -> Color:
	return COLOR_HEX_VALUES[player_color_id]

func _apply_texture() -> void:
	if not sprite:
		return
		
	var tex_key = "ghost" if is_ghost else player_color_name
	if _textures.has(tex_key):
		sprite.texture = _textures[tex_key]
	elif _textures.has("red"):
		sprite.texture = _textures["red"]
		
	# Setup 8x6 atlas regions
	sprite.hframes = 8
	sprite.vframes = 6
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.6) if is_ghost else Color(1.0, 1.0, 1.0, 1.0)

func set_motion(velocity: Vector2, facing_dir: Vector2 = Vector2.ZERO) -> void:
	var moving = velocity.length_squared() > 1.0
	is_moving = moving
	
	var dir_vec = facing_dir if facing_dir != Vector2.ZERO else velocity
	if dir_vec != Vector2.ZERO:
		if abs(dir_vec.x) > abs(dir_vec.y):
			current_direction = Direction.RIGHT if dir_vec.x > 0 else Direction.LEFT
		else:
			current_direction = Direction.DOWN if dir_vec.y > 0 else Direction.UP
			
	var target_anim = "walk" if moving else "idle"
	if is_ghost:
		target_anim = "ghost"
		
	if target_anim != current_animation:
		current_animation = target_anim
		_anim_frame = 0
		_anim_timer = 0.0
		animation_state_changed.emit(current_animation, DIR_NAMES[current_direction])
		
	_update_frame()
	_update_flashlight_angle()

func play_interact() -> void:
	current_animation = "interact"
	_anim_frame = 0
	_anim_timer = 0.0
	_update_frame()
	animation_state_changed.emit("interact", DIR_NAMES[current_direction])

func play_sabotage() -> void:
	current_animation = "sabotage"
	_anim_frame = 0
	_anim_timer = 0.0
	_update_frame()
	animation_state_changed.emit("sabotage", DIR_NAMES[current_direction])

func set_ghost_mode(active: bool) -> void:
	is_ghost = active
	_apply_texture()
	current_animation = "ghost" if active else "idle"
	_update_frame()

func _process(delta: float) -> void:
	_anim_timer += delta
	var fps = 8.0 if current_animation == "walk" else 2.0
	if _anim_timer >= (1.0 / fps):
		_anim_timer = 0.0
		var max_frames = 4 if current_animation == "walk" else 2
		_anim_frame = (_anim_frame + 1) % max_frames
		_update_frame()

func _update_frame() -> void:
	if not sprite:
		return
		
	var frame_index = 0
	var d = int(current_direction)
	
	match current_animation:
		"idle":
			# Row 0: frames (d * 2 + frame)
			frame_index = (d * 2) + (_anim_frame % 2)
		"walk":
			if d == 0: # Down
				frame_index = 8 + (_anim_frame % 4)
			elif d == 1: # Up
				frame_index = 12 + (_anim_frame % 4)
			elif d == 2: # Right
				frame_index = 16 + (_anim_frame % 4)
			elif d == 3: # Left
				frame_index = 20 + (_anim_frame % 4)
		"interact":
			# Row 3: frames 24 + (d * 2 + frame)
			frame_index = 24 + (d * 2) + (_anim_frame % 2)
		"sabotage":
			# Row 4: frames 32 + (d * 2 + frame)
			frame_index = 32 + (d * 2) + (_anim_frame % 2)
		"ghost":
			# Row 5: frames 40 + (d * 2 + frame)
			frame_index = 40 + (d * 2) + (_anim_frame % 2)
			
	sprite.frame = frame_index

func _update_flashlight_angle() -> void:
	if not flashlight_anchor:
		return
	match current_direction:
		Direction.DOWN:
			flashlight_anchor.rotation_degrees = 90.0
		Direction.UP:
			flashlight_anchor.rotation_degrees = -90.0
		Direction.RIGHT:
			flashlight_anchor.rotation_degrees = 0.0
		Direction.LEFT:
			flashlight_anchor.rotation_degrees = 180.0

func attach_flashlight(flashlight_node: Node2D) -> void:
	if flashlight_anchor and flashlight_node:
		flashlight_node.get_parent()?.remove_child(flashlight_node)
		flashlight_anchor.add_child(flashlight_node)
