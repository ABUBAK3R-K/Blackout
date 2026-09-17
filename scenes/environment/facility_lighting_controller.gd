class_name FacilityLightingController
extends Node2D

## FacilityLightingController
## Manages facility-wide dynamic 2D lighting states: Normal, Blackout Warning, Blackout Active, and Meltdown.
## Designed by Member 7 (Fatima - 2D Environment & Technical Artist).

enum LightingState {
	NORMAL,
	BLACKOUT_WARNING,
	BLACKOUT_ACTIVE,
	MELTDOWN
}

## Color definitions
const COLOR_NORMAL_AMBIENT: Color = Color(0.85, 0.89, 0.93, 1.0) # Soft clinical daylight
const COLOR_BLACKOUT_AMBIENT: Color = Color(0.04, 0.05, 0.08, 1.0) # Deep oppressive dark navy
const COLOR_MELTDOWN_AMBIENT: Color = Color(0.18, 0.05, 0.05, 1.0) # Tense crimson underglow
const COLOR_SIREN_RED: Color = Color(1.0, 0.1, 0.18, 1.0) # High-visibility warning red

## Current active state
var current_state: LightingState = LightingState.NORMAL

## References to child node groups
@export var canvas_modulate: CanvasModulate
@export var normal_lights_parent: Node2D
@export var emergency_sirens_parent: Node2D

## Animation and transition parameters
var _siren_pulse_timer: float = 0.0
var _siren_pulse_speed: float = 6.0 # Radians per second (~1 Hz)
var _warning_flicker_timer: float = 0.0
var _is_transitioning: bool = false
var _target_ambient: Color = COLOR_NORMAL_AMBIENT
var _ambient_lerp_speed: float = 5.0

## Signal emitted when state changes
signal lighting_state_changed(new_state: LightingState)

func _ready() -> void:
	# Locate or create CanvasModulate if not explicitly assigned
	if not canvas_modulate:
		canvas_modulate = get_node_or_null("CanvasModulate")
		if not canvas_modulate:
			canvas_modulate = CanvasModulate.new()
			canvas_modulate.name = "CanvasModulate"
			add_child(canvas_modulate)
	
	# Set initial baseline
	set_lighting_state(LightingState.NORMAL, true)
	
	# Hook into network client if present in the tree
	_connect_network_signals()

func _process(delta: float) -> void:
	# 1. Smoothly interpolate ambient color if transitioning
	if canvas_modulate and canvas_modulate.color != _target_ambient:
		canvas_modulate.color = canvas_modulate.color.lerp(_target_ambient, delta * _ambient_lerp_speed)
	
	# 2. Animate emergency siren pulses during Blackout and Meltdown
	if current_state == LightingState.BLACKOUT_ACTIVE or current_state == LightingState.MELTDOWN:
		_siren_pulse_timer += delta * _siren_pulse_speed
		var pulse_intensity: float = (sin(_siren_pulse_timer) + 1.0) * 0.5 # 0.0 to 1.0
		_update_siren_energy(lerp(0.2, 1.8, pulse_intensity))
	
	# 3. Warning countdown flicker effect (rapid erratic fluorescent tube drops)
	elif current_state == LightingState.BLACKOUT_WARNING:
		_warning_flicker_timer += delta * 18.0
		var flicker_noise: float = sin(_warning_flicker_timer) * cos(_warning_flicker_timer * 1.7)
		var flicker_on: bool = flicker_noise > -0.2
		_update_normal_lights_energy(1.0 if flicker_on else 0.05)

## Set lighting state with optional immediate snap (skipping interpolation)
func set_lighting_state(new_state: LightingState, immediate: bool = false) -> void:
	current_state = new_state
	
	match current_state:
		LightingState.NORMAL:
			_target_ambient = COLOR_NORMAL_AMBIENT
			_set_normal_lights_visible(true)
			_set_emergency_sirens_visible(false)
			_update_normal_lights_energy(1.0)
			
		LightingState.BLACKOUT_WARNING:
			_target_ambient = COLOR_NORMAL_AMBIENT
			_set_normal_lights_visible(true)
			_set_emergency_sirens_visible(false)
			_warning_flicker_timer = 0.0
			
		LightingState.BLACKOUT_ACTIVE:
			_target_ambient = COLOR_BLACKOUT_AMBIENT
			_set_normal_lights_visible(false)
			_set_emergency_sirens_visible(true)
			_siren_pulse_timer = 0.0
			
		LightingState.MELTDOWN:
			_target_ambient = COLOR_MELTDOWN_AMBIENT
			_set_normal_lights_visible(false)
			_set_emergency_sirens_visible(true)
			_siren_pulse_speed = 9.0 # Faster panic strobe
			
	if immediate and canvas_modulate:
		canvas_modulate.color = _target_ambient
		
	lighting_state_changed.emit(new_state)

func _set_normal_lights_visible(is_visible: bool) -> void:
	if normal_lights_parent:
		normal_lights_parent.visible = is_visible

func _set_emergency_sirens_visible(is_visible: bool) -> void:
	if emergency_sirens_parent:
		emergency_sirens_parent.visible = is_visible

func _update_normal_lights_energy(energy: float) -> void:
	if not normal_lights_parent:
		return
	for child in normal_lights_parent.get_children():
		if child is Light2D:
			child.energy = energy

func _update_siren_energy(energy: float) -> void:
	if not emergency_sirens_parent:
		return
	for child in emergency_sirens_parent.get_children():
		if child is Light2D:
			child.energy = energy

func _connect_network_signals() -> void:
	# Check for ClientNetworkManager autoload or child
	var client_net = get_node_or_null("/root/ClientNetworkManager")
	if client_net:
		if client_net.has_signal("blackout_started"):
			client_net.connect("blackout_started", Callable(self, "_on_blackout_started"))
		if client_net.has_signal("blackout_ended"):
			client_net.connect("blackout_ended", Callable(self, "_on_blackout_ended"))
		if client_net.has_signal("blackout_countdown_started"):
			client_net.connect("blackout_countdown_started", Callable(self, "_on_blackout_countdown_started"))
		if client_net.has_signal("meltdown_started"):
			client_net.connect("meltdown_started", Callable(self, "_on_meltdown_started"))

func _on_blackout_countdown_started(_duration: float) -> void:
	set_lighting_state(LightingState.BLACKOUT_WARNING)

func _on_blackout_started(_duration: float) -> void:
	set_lighting_state(LightingState.BLACKOUT_ACTIVE)

func _on_blackout_ended(_reason: String) -> void:
	set_lighting_state(LightingState.NORMAL)

func _on_meltdown_started(_duration: float) -> void:
	set_lighting_state(LightingState.MELTDOWN)
