class_name PlayerController
extends CharacterBody2D

const NetworkConfig = preload("res://shared/network_config.gd")
const RoleManager = preload("res://shared/role_manager.gd")
const SabotageManager = preload("res://shared/sabotage_manager.gd")
const GameCamera = preload("res://client/camera/game_camera.gd")
const FootstepAudio = preload("res://client/player/footstep_audio.gd")
const InteractableTrigger = preload("res://client/environment/interactable_trigger.gd")


## 2D Top-Down Player Controller for BLACKOUT.
## Handles responsive local player movement, input normalization, collision physics,
## camera management, proximity object interaction (E key), vision lighting (FR-12),
## and remote puppet position interpolation for smooth multiplayer synchronization.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

@export_group("Movement Settings")
## Base movement speed in pixels per second.
@export var move_speed: float = 250.0
## Interpolation smoothing speed for remote puppet players.
@export var interpolation_speed: float = 16.0

@export_group("Player Identity")
## Assigned player slot (1 to 8).
@export var slot_id: int = 1
## Display name for the player.
@export var player_name: String = "Player 1"
## Flag indicating if this instance is controlled by the local client.
@export var is_local_player: bool = true
## Flag to enable or disable player input/movement (e.g. during meetings or menus).
@export var can_move: bool = true
## Authoritative assigned role for this player (CREW or IMPOSTOR).
@export var role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE

signal role_changed(new_role: NetworkConfig.PlayerRole)
signal sabotage_triggered(sabotage_type: int)

@export_group("Flashlight / Vision Settings")

## Enable directional flashlight cone.
@export var enable_flashlight: bool = true
## Range in pixels for the directional flashlight cone (~450–550px).
@export var flashlight_range: float = 488.0
## Cone angle in degrees (~60–75°).
@export var flashlight_angle_deg: float = 65.0

@onready var visual: Node2D = get_node_or_null("Visual")
@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D")
@onready var camera: GameCamera = get_node_or_null("Camera2D")
@onready var vision_light: PointLight2D = get_node_or_null("VisionLight")
@onready var flashlight_pivot: Node2D = get_node_or_null("FlashlightPivot")
@onready var directional_light: PointLight2D = get_node_or_null("FlashlightPivot/DirectionalLight")
@onready var direction_indicator: Polygon2D = get_node_or_null("Visual/DirectionIndicator")
@onready var footstep_audio: FootstepAudio = get_node_or_null("FootstepAudio")

## Flag indicating if flashlight is toggled on by the player.
var is_flashlight_toggled_on: bool = true

## Current normalized input direction vector.
var input_vector: Vector2 = Vector2.ZERO
## Last non-zero movement direction for facing orientation.
var facing_direction: Vector2 = Vector2.DOWN

## Remote player synchronization targets
var target_position: Vector2 = Vector2.ZERO
var target_velocity: Vector2 = Vector2.ZERO
var target_facing: Vector2 = Vector2.DOWN

## Tracked nearby interactable triggers within proximity range.
var nearby_interactables: Array = []
## Primary active interactable trigger closest to the player.
var current_interactable: InteractableTrigger = null

func _ready() -> void:
	target_position = global_position
	_init_flashlight_texture()
	update_display_label()
	_update_camera_and_light_state()
	_update_facing_visual()

func _unhandled_input(event: InputEvent) -> void:
	if not is_local_player:
		return

	# Handle 'F' key debug toggle for flashlight (development helper)
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_F:
			toggle_flashlight()

	if not can_move:
		return

	# Handle 'E' key interaction
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			try_interact()

	# Handle 'Q' key Impostor Sabotage action
	# Strictly allows only the local player with the IMPOSTOR role to initiate sabotage.
	# Crew pressing Q does nothing.
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_Q:
			if is_impostor():
				try_trigger_sabotage(SabotageManager.SabotageType.POWER_BLACKOUT)


func _physics_process(delta: float) -> void:
	# --- LOCAL PLAYER MOVEMENT EXECUTION ---
	if is_local_player:
		if not can_move:
			velocity = Vector2.ZERO
			return

		# 1. Collect and normalize local input
		input_vector = _get_input_vector()

		# 2. Track facing direction if moving
		if input_vector != Vector2.ZERO:
			facing_direction = input_vector
			_update_facing_visual()

		# 3. Calculate velocity from input
		velocity = calculate_movement_velocity(input_vector)

		# 4. Execute movement with collision resolution
		move_and_slide()
		return

	# --- REMOTE PLAYER PUPPET INTERPOLATION ---
	_process_remote_interpolation(delta)

## Smoothly interpolates remote player position towards authoritative network target.
func _process_remote_interpolation(delta: float) -> void:
	if target_position == Vector2.INF or target_position == Vector2.ZERO:
		velocity = Vector2.ZERO
		return

	var dist_to_target: float = global_position.distance_to(target_position)

	# If distance is excessively large (e.g. initial spawn or teleport), snap instantly
	if dist_to_target > 350.0:
		global_position = target_position
	elif dist_to_target > 0.5:
		global_position = global_position.lerp(target_position, delta * interpolation_speed)
	else:
		global_position = target_position

	velocity = target_velocity
	if target_facing != Vector2.ZERO:
		facing_direction = target_facing
		_update_facing_visual()

## Updates the authoritative target coordinates received from the network.
func update_remote_state(new_pos: Vector2, new_vel: Vector2, new_facing: Vector2) -> void:
	# If unpositioned or large teleport jump, snap instantly
	if global_position == Vector2.ZERO or global_position.distance_to(new_pos) > 350.0:
		global_position = new_pos

	target_position = new_pos
	target_velocity = new_vel
	target_facing = new_facing
	if new_facing != Vector2.ZERO:
		facing_direction = new_facing
		_update_facing_visual()

## Collects 2D directional input from WASD and Arrow keys.
## Returns a normalized Vector2 so diagonal movement does not exceed base speed.
func _get_input_vector() -> Vector2:
	var dir := Vector2.ZERO

	# Horizontal input (WASD + Arrow Keys)
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1.0

	# Vertical input (WASD + Arrow Keys)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0

	# Normalize vector so diagonal movement is not sqrt(2) times faster
	if dir.length_squared() > 0.0:
		dir = dir.normalized()

	return dir

## Calculates velocity vector based on normalized input direction and move speed.
func calculate_movement_velocity(direction: Vector2) -> Vector2:
	return direction * move_speed

## Attempts to interact with the nearest active interactable trigger.
func try_interact() -> bool:
	if current_interactable != null and current_interactable.is_interactive:
		return current_interactable.interact(self)
	return false

## Registers an interactable trigger when entering its proximity radius.
func register_nearby_interactable(trigger: InteractableTrigger) -> void:
	if trigger == null:
		return
	if not nearby_interactables.has(trigger):
		nearby_interactables.append(trigger)
	current_interactable = trigger

## Unregisters an interactable trigger when leaving its proximity radius.
func unregister_nearby_interactable(trigger: InteractableTrigger) -> void:
	nearby_interactables.erase(trigger)
	if current_interactable == trigger:
		current_interactable = nearby_interactables.back() if not nearby_interactables.is_empty() else null

## Updates the name/slot label displayed above the player character.
func update_display_label() -> void:
	if name_label == null:
		name_label = get_node_or_null("NameLabel")
	if name_label != null:
		var display_text = player_name
		if is_local_player:
			if not display_text.ends_with("(YOU)"):
				display_text = "%s (YOU)" % display_text
			name_label.set("theme_override_colors/font_color", Color(0.35, 0.85, 1.0, 1.0))
		else:
			if display_text.ends_with(" (YOU)"):
				display_text = display_text.trim_suffix(" (YOU)")
			name_label.set("theme_override_colors/font_color", Color(0.9, 0.93, 0.97, 0.95))
		name_label.text = display_text

## Updates the visual orientation to match the player's facing direction.
func _update_facing_visual() -> void:
	if visual == null:
		visual = get_node_or_null("Visual")
	if flashlight_pivot == null:
		flashlight_pivot = get_node_or_null("FlashlightPivot")
	if directional_light == null:
		directional_light = get_node_or_null("FlashlightPivot/DirectionalLight")

	if facing_direction.length_squared() > 0.001:
		var target_rot = facing_direction.angle() - (PI / 2.0)
		if visual != null:
			visual.rotation = target_rot
		if flashlight_pivot != null:
			flashlight_pivot.rotation = target_rot
		elif directional_light != null:
			directional_light.rotation = target_rot

## Updates the camera and vision light active states based on local player flag.
func _update_camera_and_light_state() -> void:
	if camera == null:
		camera = get_node_or_null("Camera2D")
	if vision_light == null:
		vision_light = get_node_or_null("VisionLight")
	if directional_light == null:
		directional_light = get_node_or_null("FlashlightPivot/DirectionalLight")

	if camera != null:
		camera.enabled = is_local_player

	# Remote puppet players must never emit local vision or flashlight lighting
	if not is_local_player:
		if vision_light != null:
			vision_light.enabled = false
		if directional_light != null:
			directional_light.enabled = false

## Initializes the directional flashlight cone texture if available.
func _init_flashlight_texture() -> void:
	if directional_light != null and enable_flashlight:
		var tex = create_flashlight_cone_texture(256, 256, flashlight_angle_deg)
		if tex != null:
			directional_light.texture = tex

## Toggles the local player's flashlight on/off (Development/Debug helper).
func toggle_flashlight() -> bool:
	if not is_local_player or directional_light == null:
		return false
	is_flashlight_toggled_on = not is_flashlight_toggled_on
	directional_light.enabled = is_flashlight_toggled_on
	print("[PlayerController] Flashlight toggled: %s." % ["ON" if is_flashlight_toggled_on else "OFF"])
	return is_flashlight_toggled_on

## Sets the active state of the directional flashlight.
func set_flashlight_active(active: bool) -> void:
	is_flashlight_toggled_on = active
	if directional_light != null and is_local_player:
		directional_light.enabled = active

## Returns true if the directional flashlight is currently active.
func is_flashlight_active() -> bool:
	return directional_light != null and directional_light.enabled

## Generates a soft-feathered 2D flashlight vision cone texture.
static func create_flashlight_cone_texture(width: int = 256, height: int = 256, cone_angle_deg: float = 65.0) -> ImageTexture:
	var img = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var half_angle_rad: float = deg_to_rad(cone_angle_deg * 0.5)
	var origin_x: float = width * 0.5
	var origin_y: float = 8.0

	for y in range(height):
		for x in range(width):
			var dx = float(x) - origin_x
			var dy = float(y) - origin_y

			if dy <= 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var dist = sqrt(dx * dx + dy * dy)
			var max_dist = float(height) - origin_y
			if dist > max_dist:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var angle = abs(atan2(dx, dy))
			if angle > half_angle_rad:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			# Angular falloff (soft feathered cone edges)
			var angle_ratio = angle / half_angle_rad
			var angular_falloff = cos(angle_ratio * PI * 0.5)
			angular_falloff = angular_falloff * angular_falloff

			# Radial falloff (smooth quadratic falloff over distance)
			var radial_ratio = dist / max_dist
			var radial_falloff = (1.0 - radial_ratio) * (1.0 - radial_ratio)

			# Central core beam boost
			var core_boost = (1.0 - angle_ratio * angle_ratio) * 0.3

			var alpha = clampf((angular_falloff * radial_falloff) + (core_boost * radial_falloff), 0.0, 1.0)
			var color = Color(0.92, 0.96, 1.0, alpha)
			img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

## Triggers a screen shake on the local camera.
func trigger_screen_shake(intensity: float = 10.0, duration: float = 0.4) -> void:
	if camera == null:
		camera = get_node_or_null("Camera2D")
	if camera != null and is_local_player:
		camera.trigger_shake(intensity, duration)

## Configures player slot and display label.
func setup_player(p_slot_id: int, p_name: String, p_is_local: bool = true) -> void:
	slot_id = p_slot_id
	player_name = p_name
	is_local_player = p_is_local
	update_display_label()
	_update_camera_and_light_state()
	_update_facing_visual()

## Sets the authoritative role for this player and emits role_changed.
func set_role(new_role: NetworkConfig.PlayerRole) -> void:
	if role == new_role:
		return
	role = new_role
	print("[PlayerController] Player %d (%s) role set to: %s." % [slot_id, player_name, get_role_name()])
	role_changed.emit(role)

## Returns the current role enum for this player.
func get_role() -> NetworkConfig.PlayerRole:
	return role

## Returns true if this player has the IMPOSTOR role.
func is_impostor() -> bool:
	return RoleManager.is_impostor(role)

## Returns true if this player has the CREW role.
func is_crew() -> bool:
	return RoleManager.is_crew(role)

## Returns the uppercase string name of this player's role.
func get_role_name() -> String:
	return RoleManager.get_role_display_name(role)

## Attempts to trigger a sabotage action if this player is the local Impostor.
func try_trigger_sabotage(sabotage_type: int = SabotageManager.SabotageType.POWER_BLACKOUT) -> bool:
	if not is_local_player:
		return false
	if not is_impostor():
		return false

	print("[PlayerController] Local Impostor triggering sabotage request (%s)..." % SabotageManager.get_sabotage_name(sabotage_type as SabotageManager.SabotageType))
	sabotage_triggered.emit(sabotage_type)

	var net_mgr = null
	if is_inside_tree():
		net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and net_mgr.has_method("request_sabotage"):
		net_mgr.request_sabotage(sabotage_type)
	return true

