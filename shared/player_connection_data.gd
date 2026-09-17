class_name PlayerConnectionData
extends RefCounted

## Represents the server-authoritative session data for a connected player.

const NetworkConfig = preload("res://shared/network_config.gd")

var peer_id: int = 0
var player_slot: int = 0  # Unique slot from 1 to 8 assigned by server
var connected_at: float = 0.0
var is_ready: bool = false
var role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE
var is_alive: bool = true
var is_eliminated: bool = false

func _init(p_peer_id: int = 0, p_slot: int = 0, p_is_ready: bool = false, p_role: NetworkConfig.PlayerRole = NetworkConfig.PlayerRole.NONE) -> void:
	peer_id = p_peer_id
	player_slot = p_slot
	connected_at = Time.get_unix_time_from_system()
	is_ready = p_is_ready
	role = p_role
	is_alive = true
	is_eliminated = false

## Public serialization for state synchronization.
## IMPORTANT: Does NOT include 'role' to prevent role leakage to clients.
func to_dict() -> Dictionary:
	return {
		"peer_id": peer_id,
		"player_slot": player_slot,
		"connected_at": connected_at,
		"is_ready": is_ready,
		"is_alive": is_alive,
		"is_eliminated": is_eliminated
	}

static func from_dict(d: Dictionary) -> RefCounted:
	var data = load("res://shared/player_connection_data.gd").new(
		int(d.get("peer_id", 0)),
		int(d.get("player_slot", 0)),
		bool(d.get("is_ready", false))
	)
	data.connected_at = float(d.get("connected_at", 0.0))
	data.is_alive = bool(d.get("is_alive", true))
	data.is_eliminated = bool(d.get("is_eliminated", false))
	return data
