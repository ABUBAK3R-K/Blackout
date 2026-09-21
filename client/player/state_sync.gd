class_name StateSync
extends Node

const PlayerController = preload("res://client/player/player_controller.gd")

## 2D Multiplayer Position Synchronization & Remote Interpolation Manager for BLACKOUT.
## Handles periodic client state transmission (~20 Hz) for local players,
## smooth state interpolation (lerp) for remote player puppets, and network packet dispatch.
## Designed by Member 3 (Lead Client & Gameplay Programmer).

signal local_state_dispatched(pos: Vector2, vel: Vector2, facing: Vector2)
signal remote_state_applied(peer_id: int, pos: Vector2, vel: Vector2)

## Network state update frequency (20 Hz = 20 packets per second).
const SYNC_RATE_HZ: float = 20.0
const SYNC_INTERVAL_SEC: float = 1.0 / SYNC_RATE_HZ

## Threshold distance in pixels to trigger instant snap instead of interpolation (e.g. on respawn).
const SNAP_DISTANCE_THRESHOLD: float = 350.0

@export_group("Synchronization Settings")
## Reference to the local PlayerController.
@export var local_player: PlayerController = null
## Interpolation convergence speed factor for remote puppets.
@export var interpolation_speed: float = 16.0

var sync_timer: float = 0.0
var last_dispatched_position: Vector2 = Vector2.INF
var last_dispatched_velocity: Vector2 = Vector2.INF

func _ready() -> void:
	_auto_connect_network_signals()

func _physics_process(delta: float) -> void:
	# 1. Process local player network state transmission
	if local_player != null and local_player.is_local_player and local_player.can_move:
		sync_timer += delta
		if sync_timer >= SYNC_INTERVAL_SEC:
			sync_timer = 0.0
			_dispatch_local_player_state()

## Registers the local player controller for position tracking.
func register_local_player(player: PlayerController) -> void:
	local_player = player
	last_dispatched_position = Vector2.INF
	last_dispatched_velocity = Vector2.INF

## Automatically connects to NetworkManager / ClientNetworkManager signals.
func _auto_connect_network_signals() -> void:
	if not is_inside_tree():
		return

	var net_mgr = get_node_or_null("/root/NetworkManager")
	if net_mgr != null and "client" in net_mgr and net_mgr.client != null:
		bind_client_network_manager(net_mgr.client)

## Binds to ClientNetworkManager remote position updates.
func bind_client_network_manager(client_mgr: Node) -> void:
	if client_mgr == null:
		return

	if client_mgr.has_signal("remote_player_position_updated") and not client_mgr.remote_player_position_updated.is_connected(_on_remote_position_received):
		client_mgr.remote_player_position_updated.connect(_on_remote_position_received)

## Collects local player coordinates and dispatches via NetworkManager autoload.
func _dispatch_local_player_state() -> void:
	if local_player == null:
		return

	var current_pos: Vector2 = local_player.global_position
	var current_vel: Vector2 = local_player.velocity
	var current_facing: Vector2 = local_player.facing_direction

	# Only send if position/velocity changed or at least once every second as heartbeat
	var moved: bool = current_pos != last_dispatched_position or current_vel != last_dispatched_velocity
	if moved:
		last_dispatched_position = current_pos
		last_dispatched_velocity = current_vel

		var net_mgr = get_node_or_null("/root/NetworkManager") if is_inside_tree() else null
		if net_mgr != null and net_mgr.has_method("send_player_position"):
			net_mgr.send_player_position(current_pos, current_vel, current_facing)

		local_state_dispatched.emit(current_pos, current_vel, current_facing)

## Receives remote player coordinates and updates the corresponding remote player instance.
func _on_remote_position_received(peer_id: int, pos: Vector2, vel: Vector2, facing: Vector2) -> void:
	var spawn_mgr = get_parent().get_node_or_null("SpawnManager") if is_inside_tree() and get_parent() != null else null
	if spawn_mgr == null and is_inside_tree():
		spawn_mgr = get_node_or_null("/root/Main/SpawnManager")

	if spawn_mgr != null and "tracked_players" in spawn_mgr:
		var remote_player = spawn_mgr.tracked_players.get(peer_id, null) as PlayerController
		if remote_player != null and is_instance_valid(remote_player):
			apply_remote_state_to_player(remote_player, pos, vel, facing)
			remote_state_applied.emit(peer_id, pos, vel)

## Applies authoritative target coordinates to a remote player puppet with smooth interpolation.
func apply_remote_state_to_player(player: PlayerController, pos: Vector2, vel: Vector2, facing: Vector2) -> void:
	if player == null or player.is_local_player:
		return

	if player.has_method("update_remote_state"):
		player.update_remote_state(pos, vel, facing)
	else:
		# Fallback direct lerp/snap
		if player.global_position.distance_to(pos) > SNAP_DISTANCE_THRESHOLD:
			player.global_position = pos
		else:
			player.global_position = player.global_position.lerp(pos, 0.5)
		player.velocity = vel
		player.facing_direction = facing
